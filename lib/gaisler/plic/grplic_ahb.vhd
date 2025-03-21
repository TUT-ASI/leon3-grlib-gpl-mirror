------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
-----------------------------------------------------------------------------
-- Entity:      grplic_ahb
-- File:        grplic_ahb.vhd
-- Author:      Andrea Merlo, Nils Wessman, Cobham Gaisler AB
-- Description: RISC-V Platform Interrupt Controller
--
--              It includes a RISC-V privilege spec 1.11 (WIP) compatible
--              Platform Interrupt Controller (PLIC), commit of plic-spec:
--              64480ab9e07fd145a55f0f11abaaa7619a1c98ae
--
--              An interrupt ID of 0 is reserved to mean “no interrupt”.
--              Interrupts ID 1 to ID 32 areattached to the irq lines of the
--              AHB bus. Source 1 in the GRPLIC is assigned to irq(1) of the
--              AHB bus. 
--
--              Implemented with 32-bit AHB slave interface to support 64 MB
--              address range (Threshold/claim/complete has offset 0x200000 -
--              0x3FFFFC)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;

library gaisler;
use gaisler.plic.all;

entity grplic_ahb is
  generic (
    hindex      : integer range 0 to NAHBSLV-1  := 0;
    haddr       : integer range 0 to 16#FFF#    := 0;
    hmask       : integer range 0 to 16#FFC#    := 16#FFC#;
    nsources    : integer range 0 to 32         := NAHBIRQ;
    ncpu        : integer range 0 to MAX_HARTS  := 4;
    priorities  : integer range 0 to 32         := 8;
    pendingbuff : integer range 0 to 32         := 1;
    irqtype     : integer range 0 to 1          := 1;
    thrshld     : integer range 0 to 1          := 1
    );
  port (
    rst         : in  std_ulogic;
    clk         : in  std_ulogic;
    ahbi        : in  ahb_slv_in_type;
    ahbo        : out ahb_slv_out_type;
    irqo        : out std_logic_vector(ncpu*4-1 downto 0)
    );
end;

architecture rtl of grplic_ahb is

  constant REVISION : integer := 0;

  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_GRPLIC, 0, REVISION, 0),
    4 => ahb_membar(haddr, '0', '0', hmask),
    others => zero32);

  -- Add register to improve timing paths. Adds one wait-state on
  -- Read and write accesses.
  constant pipe         : boolean := true;
  -- Register width
  constant regw         : integer := 32;

  constant ntargets     : integer := ncpu*4;  -- 4 running modes
  constant sources      : integer := nsources;  -- ID 0 reserved
  constant prbits       : integer := log2x(priorities);
  constant srcbits      : integer := log2x(sources);
  constant trgbits      : integer := log2x(ntargets);
  constant max_ctx      : std_logic_vector(31 downto 0) := x"00002000" + 16#80#*ntargets;

  -- Relative address for the Priority Threshold register blocks
  constant THR_BIT      : integer := 21;
  
  type priority_in_type is array (0 to sources-1) of std_logic_vector(prbits-1 downto 0);
  type priority_out_type is array (0 to ntargets-1) of std_logic_vector(prbits-1 downto 0);
  type enable_type is array (0 to ntargets-1) of std_logic_vector(sources-1 downto 0);
  type id_type is array (0 to ntargets-1) of std_logic_vector(srcbits-1 downto 0);

  type reg_type is record
    priorities          : priority_in_type;
    ipbits              : std_logic_vector(sources-1 downto 0);
    enable              : enable_type;
    max_id              : id_type;
    claimed             : enable_type;
    threshold           : priority_out_type;
    claim               : std_logic_vector(sources-1 downto 0);
    complete            : std_logic_vector(sources-1 downto 0);
    meip                : std_logic_vector(ntargets-1 downto 0);
    -- AHB
    hsel                : std_logic_vector(1 downto 0);
    hready              : std_logic;
    hwrite              : std_logic;
    hsize               : std_logic_vector(2 downto 0);
    haddr               : std_logic_vector(31 downto 0);
    hresp               : std_logic_vector(1 downto 0);
    hwdata              : std_logic_vector(regw-1 downto 0);
    hrdata              : std_logic_vector(regw-1 downto 0);
  end record;

  constant RES_T : reg_type := (
    priorities          => (others => (others => '0')),
    ipbits              => (others => '0'),
    enable              => (others => (others => '0')),
    threshold           => (others => (others => '0')),
    max_id              => (others => (others => '0')),
    claimed             => (others => (others => '0')),
    claim               => (others => '0'),
    complete            => (others => '0'),
    meip                => (others => '0'),
    -- AHB
    hsel                => (others => '0'),
    hready              => '0',
    hwrite              => '0',
    hsize               => (others => '0'),
    haddr               => (others => '0'),
    hresp               => (others => '0'),
    hwdata              => (others => '0'),
    hrdata              => (others => '0')
    );
  
  signal r, rin         : reg_type;

  -- Gateways signals
  signal complete       : std_logic_vector(sources-1 downto 0);
  signal claim          : std_logic_vector(sources-1 downto 0);
  signal ip             : std_logic_vector(sources-1 downto 0);

  -- Encoders signals
  signal pr_in_array    : priority_in_type;
  signal pr_out_array   : priority_out_type;
  signal enable         : enable_type;
  signal pr_array_unfol : std_logic_vector((prbits*sources)-1 downto 0);

  -- Targets signals
  signal threshold      : priority_out_type;
  signal irqreq         : std_logic_vector(ntargets-1 downto 0);
  signal id             : id_type;

begin

  ---------------------------------------------------
  -- Gateways
  ---------------------------------------------------

  -- ID 0 is reserved, so no gateway is istantiated
  gateways : for i in 1 to sources-1 generate
    gateway : plic_gateway
      generic map (
        pendingbuff     => pendingbuff,
        irqtype         => irqtype
        )
      port map (
        rst             => rst,
        clk             => clk,
        irqi            => ahbi.hirq(i),
        ip              => ip(i),
        complete        => complete(i),
        claim           => claim(i)
        );
  end generate;

  -- Hardwired IP bit of ID 0
  ip(0)         <= '0';

  ---------------------------------------------------
  -- Encoders
  ---------------------------------------------------

  encoders : for i in 0 to ntargets-1 generate
    encoder : plic_encoder
      generic map (
        nsources        => sources,  
        ntargets        => ntargets,
        srcbits         => srcbits,
        prbits          => prbits
        )
      port map (
        ip              => ip,
        pr_in           => pr_array_unfol,
        enable          => enable(i),
        id              => id(i),
        pr_out          => pr_out_array(i)
        );
  end generate;

  -- Unfold pr_in_array and enable
  pr_unfolding : for i in 0 to sources-1 generate
    pr_array_unfol((i+1)*prbits-1 downto i*prbits)      <= pr_in_array(i); 
  end generate;

  ---------------------------------------------------
  -- Targets
  ---------------------------------------------------

  targets : for i in 0 to ntargets-1 generate
    target : plic_target
      generic map (
        prbits          => prbits,
        srcbits         => srcbits
        )
      port map (
        prio            => pr_out_array(i),
        threshold       => threshold(i),
        irqreq          => irqreq(i)
        );
  end generate;

  comb : process (rst, r, ahbi, ip, pr_out_array, id, irqreq)
    variable v          : reg_type;
    variable selhart    : integer range 0 to ntargets-1;
    variable selsrc     : integer range 0 to RISCV_SOURCES-1;
    variable selen      : integer range 0 to ntargets-1;
    variable srcmaxid   : integer range 0 to sources-1;
    variable cmplsource : integer range 0 to 2**srcbits-1;
    variable hrdata     : std_logic_vector(regw-1 downto 0);
    variable rdata      : std_logic_vector(regw-1 downto 0);
    variable hwdata     : std_logic_vector(regw-1 downto 0);
    variable wdata      : std_logic_vector(regw-1 downto 0);
    variable offset     : std_logic_vector(15 downto 14);
  begin

    ---------------------------------------------------
    -- Interrupt Identifiers (IDs)
    ---------------------------------------------------

    -- Global interrupt sources are assigned small unsigned integer identifiers,
    -- beginning at the value 1. An interrupt ID of 0 is reserved to mean “no interrupt”.
    
    -- Interrupt identifiers are also used to break ties when two or more interrupt sources have the
    -- same assigned priority. Smaller values of interrupt ID take precedence over larger values
    -- of interrupt ID.

    -- ip(0)            -> ID 0
    -- ip(1)            -> ID 1
    -- ...
    -- ip(nsources)     -> ID N

    v := r;
    
    v.hsel    := (others => '0');
    v.hready  := '1';
    v.hresp   := HRESP_OKAY; 

    rdata       := (others => '0');
    
    -- Claim and complete signals will be set only for 1 clock cycle
    v.claim     := (others => '0');
    v.complete  := (others => '0');

    ---------------------------------------------------
    -- Update Register
    ---------------------------------------------------

    v.ipbits    := ip;
    v.meip      := irqreq;
    v.max_id    := id;

    ---------------------------------------------------
    -- Register Map
    ---------------------------------------------------

    -- Sources 1 to nsources are implemented
    -- All other sources registers are tied to 0
    
    -- base + 0x000000: Reserved (interrupt source 0 does not exist)
    -- base + 0x000004: Interrupt source 1 priority
    -- base + 0x000008: Interrupt source 2 priority
    -- ...
    -- base + 0x000FFC: Interrupt source 1023 priority
    -- base + 0x001000: Interrupt Pending bit 0-31
    -- base + 0x00107C: Interrupt Pending bit 992-1023

    -- base + 0x002000: Enable bits for sources 0-31 on context 0
    -- base + 0x002004: Enable bits for sources 32-63 on context 0
    -- ...
    -- base + 0x00207F: Enable bits for sources 992-1023 on context 0
    -- base + 0x002080: Enable bits for sources 0-31 on context 1
    -- base + 0x002084: Enable bits for sources 32-63 on context 1
    -- ...
    -- base + 0x0020FF: Enable bits for sources 992-1023 on context 1
    -- base + 0x002100: Enable bits for sources 0-31 on context 2
    -- base + 0x002104: Enable bits for sources 32-63 on context 2
    -- ...
    -- base + 0x00217F: Enable bits for sources 992-1023 on context 2

    -- base + 0x200000: Priority threshold for context 0
    -- base + 0x200004: Claim/complete for context 0
    -- base + 0x200008: Reserved
    -- ...
    -- base + 0x200FFC: Reserved
    -- base + 0x201000: Priority threshold for context 1
    -- base + 0x201004: Claim/complete for context 1

    ---------------------------------------------------
    -- AHB Interface
    ---------------------------------------------------
    -- Interface defined as 32-bit
    --hwdata(63 downto 32) := ahbi.hwdata( 63 mod AHBDW downto 32 mod AHBDW);
    hwdata(31 downto  0) := ahbi.hwdata( 31           downto  0);

    -- Select context for claim/complete register block
    selhart     := to_integer(unsigned(r.haddr(trgbits+11 downto 12)));
    -- Select source for priority register block
    selsrc      := to_integer(unsigned(r.haddr(srcbits+1 downto 2)));
    -- Select context for enable bits register block
    selen       := to_integer(unsigned(r.haddr(trgbits+6 downto 7)));

    -- Source of the MAX ID
    srcmaxid    := to_integer(unsigned(r.max_id(selhart)));

    -- Source of Completion Notification
    cmplsource  := to_integer(unsigned(r.hwdata(srcbits-1 downto 0)));

    -- Slave selected
    if (ahbi.hready and ahbi.hsel(hindex) and ahbi.htrans(1)) = '1' then
      v.hsel(0)  := '1';
      v.haddr    := ahbi.haddr;
      v.hsize    := ahbi.hsize;
      v.hwrite   := ahbi.hwrite;
      -- pipe
      if pipe then
        v.hready   := '0';
      end if;
    end if;

    -- Write data
    if pipe then
      if r.hsel(0) = '1' and r.hwrite = '1' then
        v.hwdata := hwdata;
      end if;
      wdata := r.hwdata;
      v.hsel(1) := r.hsel(0);
    else
      wdata := hwdata;
      v.hwdata := (others => '0');
      v.hsel(1) := v.hsel(0);
    end if;

    -- Read access
    if r.hsel(0) = '1' then
      if r.haddr(THR_BIT) = '0' then
        if r.haddr(THR_BIT-1 downto 13) = zero32(THR_BIT-1 downto 13) then 
          if r.haddr(12) = '0' then -- priority register
            if selsrc <= sources-1 then
              rdata(prbits-1 downto 0)    := r.priorities(selsrc);
            end if;
          else -- pending register
            -- only support 32 sources (including 0)
            if r.haddr(11 downto 2) = zero32(11 downto 2) then 
              rdata(sources-1 downto 0)   := r.ipbits(sources-1 downto 0);
            end if;
          end if;
        else -- enable register
          -- only for suppoted contexts
          if unsigned(r.haddr(THR_BIT-1 downto 7)) < unsigned(max_ctx(THR_BIT-1 downto 7)) then
              -- only support 32 sources (including 0)
              if r.haddr(6 downto 2) = zero32(6 downto 2) then 
                rdata(sources-1 downto 0)     := r.enable(selen)(sources-1 downto 0);
              end if;
            end if;
        end if; -- r.haddr(12)
      else  -- Claim/complete register block
        -- only for suppoted contexts
        if r.haddr(THR_BIT-1 downto trgbits+12) = zero32(THR_BIT-1 downto trgbits+12) then
          -- other offsets are reserved
          if r.haddr(11 downto 3) = zero32(11 downto 3) then
            if r.haddr(2) = '0' then -- threshold register
              if thrshld = 1 then
                rdata(prbits-1 downto 0)          := r.threshold(selhart);
              end if;
            else -- claim/complete register
              rdata(srcbits-1 downto 0)           := r.max_id(selhart); 
              -- Interrupt Claims
              -- Do not allow nested interrupts from the same hart
              if r.claimed(selhart)(srcmaxid) = '0' and r.hwrite = '0' then
                v.claimed(selhart)(srcmaxid)      := '1';
                v.claim(srcmaxid)                 := '1';
              end if;
            end if; -- r.haddr(2)
          end if; -- r.haddr(11 downto 3)
        end if; -- supported contexts
      end if; -- r.haddr(THR_BIT)
      v.hrdata := rdata;
    end if;

    -- Write access
    if r.hsel(1) = '1' and r.hwrite = '1' then
      if r.haddr(THR_BIT) = '0' then 
        if r.haddr(THR_BIT-1 downto 13) = zero32(THR_BIT-1 downto 13) then 
          if r.haddr(12) = '0' then -- priority register
            if selsrc <= sources-1 then
              v.priorities(selsrc)                := wdata(prbits-1 downto 0);
            end if;
          end if;
        else -- enable register
          -- only for suppoted contexts
          if unsigned(r.haddr(THR_BIT-1 downto 7)) < unsigned(max_ctx(THR_BIT-1 downto 7)) then
            -- only support 32 sources (including 0)
            if r.haddr(6 downto 2) = zero32(6 downto 2) then 
              v.enable(selen)(sources-1 downto 0)   := wdata(sources-1 downto 0);
            end if;
          end if;
        end if; -- r.haddr(12)
      else -- Claim/complete register block
        -- only for suppoted contexts
        if r.haddr(THR_BIT-1 downto trgbits+12) = zero32(THR_BIT-1 downto trgbits+12) then
          -- other offsets are reserved
          if r.haddr(11 downto 3) = zero32(11 downto 3) then
            if r.haddr(2) = '0' then -- threshold register
              if thrshld = 1 then
                v.threshold(selhart)              := wdata(prbits-1 downto 0);
              end if;
            else -- claim/complete register
              -- Interrupt Completion
              if r.claimed(selhart)(cmplsource) = '1' then
                v.complete(cmplsource)            := '1';
                v.claimed(selhart)(cmplsource)    := '0';
              end if;
            end if; -- r.haddr(2)
          end if; -- r.haddr(11 downto 3)
        end if; -- supported contexts
      end if; -- r.haddr(THR_BIT)
    end if;

    -- Error response (only support 32-bit accesses)
    if pipe then
      if r.hsel(0) = '1' then
        if r.hsize /= "010" then
          v.hready := '0';
          v.hresp  := HRESP_ERROR;
        end if;
      end if;
    else
      if v.hsel(0) = '1' then
        if v.hsize /= "010" then
          v.hready := '0';
          v.hresp  := HRESP_ERROR;
        end if;
      end if;
    end if;
    -- Second error response cycle
    if r.hready = '0' and r.hresp = HRESP_ERROR then
      v.hresp := HRESP_ERROR;
    end if;

    -- Read data
    if pipe then
      hrdata := r.hrdata;
    else
      hrdata := rdata;
      v.hrdata := (others => '0');
    end if;

    -- Hardwired enable/claimed bits for ID 0
    for i in 0 to ntargets-1 loop
      v.enable(i)(0) := '0';
      v.claimed(i)(0) := '0';
    end loop;
    -- Hardwired priority for source 0
    v.priorities(0) := (others => '0');

    rin <= v;

    -- PLIC Signals
    threshold           <= r.threshold;
    pr_in_array         <= r.priorities;
    complete            <= r.complete;
    claim               <= r.claim;
    enable              <= r.enable;

    -- AHB Interface
    ahbo.hready         <= r.hready;
    ahbo.hrdata         <= ahbdrivedata(hrdata);
    ahbo.hresp          <= r.hresp;
    ahbo.hsplit         <= (others => '0');
    ahbo.hirq           <= (others => '0');
    ahbo.hconfig        <= hconfig;
    ahbo.hindex         <= hindex;

    for i in 0 to ntargets-1 loop
      irqo(i)   <= r.meip(i);
    end loop;
    
  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if rst = '0' then
        r <= RES_T;
      end if;
    end if;
  end process;

end;


