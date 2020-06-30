------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
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
-- Entity:      grplic
-- File:        grplic.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
-- Description: RISC-V Platform Interrupt Controller
--
--              It includes a RISC-V privilege spec 1.11 (WIP) compatible
--              Platform Interrupt Controller (PLIC), commit of plic-spec:
--              64480ab9e07fd145a55f0f11abaaa7619a1c98ae
--
--              An interrupt ID of 0 is reserved to mean “no interrupt”.
--              Interrupts ID 1 to ID 32 areattached to the irq lines of the
--              APB bus. Source 1 in the GRPLIC is assigned to irq(0) of the
--              APB bus.
--
--              Addressing difference between a RISC-V spec compliant (due to
--              APB addressing limitations):
--              -> Claim/complete block register starts a THR_BASE instead of
--                 0x200000
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

entity grplic is
  generic (
    pindex      : integer range 0 to NAPBSLV-1  := 0;
    paddr       : integer range 0 to 16#FFF#    := 0;
    pmask       : integer range 0 to 16#FFF#    := 16#FFF#;
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
    apbi        : in  apb_slv_in_type;
    apbo        : out apb_slv_out_type;
    irqo        : out std_logic_vector(ncpu*4-1 downto 0)
    );
end grplic;

architecture rtl of grplic is

  constant REVISION : integer := 0;

  constant pconfig : apb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_GRPLIC, 0, REVISION, 0),
    1 => apb_iobar(paddr, pmask));

  constant ntargets     : integer := ncpu*4;  -- 4 running modes
  constant sources      : integer := nsources + 1;  -- ID 0 reserved
  constant prbits       : integer := log2x(priorities);
  constant srcbits      : integer := log2x(sources);
  constant trgbits      : integer := log2x(ntargets);

  -- Relative address for the Priority Threshold register blocks
  constant THR_BASE     : std_logic_vector(19 downto 0) := x"20000"; -- Instead of #200000#;
  constant THR_BIT      : integer := log2x(to_integer(unsigned(THR_BASE(19 downto 12)))) + 12;
  constant zerow        : std_logic_vector(31 downto 0) := (others => '0');
  
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
    meip                => (others => '0')
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
        irqi            => apbi.pirq(i-1),
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
        priority        => pr_out_array(i),
        threshold       => threshold(i),
        irqreq          => irqreq(i)
        );
  end generate;

  comb : process (rst, r, apbi, ip, pr_out_array, id, irqreq)
    variable v          : reg_type;
    variable selhart    : integer range 0 to ntargets-1;
    variable selsrc     : integer range 0 to RISCV_SOURCES-1;
    variable selen      : integer range 0 to ntargets-1;
    variable srcmaxid   : integer range 0 to sources-1;
    variable cmplsource : integer range 0 to 2**srcbits-1;
    variable rdata      : std_logic_vector(31 downto 0);
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

    -- base + 0x020000: Priority threshold for context 0
    -- base + 0x020004: Claim/complete for context 0
    -- base + 0x020008: Reserved
    -- ...
    -- base + 0x020FFC: Reserved
    -- base + 0x021000: Priority threshold for context 1
    -- base + 0x021004: Claim/complete for context 1

    ---------------------------------------------------
    -- APB Interface
    ---------------------------------------------------

    -- Select context for claim/complete register block
    selhart     := to_integer(unsigned(apbi.paddr(trgbits+11 downto 12)));
    -- Select source for priority register block
    selsrc      := to_integer(unsigned(apbi.paddr(srcbits+1 downto 2))) + 1;
    -- Select context for enable bits register block
    selen       := to_integer(unsigned(apbi.paddr(trgbits+6 downto 7)));


    -- Source of the MAX ID
    srcmaxid    := to_integer(unsigned(r.max_id(selhart)));

    -- Source of Completion Notification
    cmplsource  := 0;

    -- APB Read Access
    if ((apbi.psel(pindex) and apbi.penable and (not apbi.pwrite)) = '1') then
      if apbi.paddr(THR_BIT) = '1' then -- Claim/complete register block

        case apbi.paddr(2) is -- threshold register
          when '0' =>
            if thrshld = 1 then
              rdata(prbits-1 downto 0)          := r.threshold(selhart);
            end if;

          when '1' => -- claim/complete register
            rdata(srcbits-1 downto 0)           := r.max_id(selhart); 
            -- Interrupt Claims
            -- Do not allow nested interrupts from the same hart
            if r.claimed(selhart)(srcmaxid) = '0' then
              v.claimed(selhart)(srcmaxid)      := '1';
              v.claim(srcmaxid)                 := '1';
            end if;
            
          when others =>
        end case; -- apbi.paddr(2)
    
      else
        if apbi.paddr(THR_BIT-1 downto 13) = zerow(THR_BIT-1 downto 13) then 
          if apbi.paddr(12) = '0' then -- priority register
            rdata(prbits-1 downto 0)    := r.priorities(selsrc);
          else -- pending register
            rdata(sources-2 downto 0)   := r.ipbits(sources-1 downto 1);
          end if;
        else -- enable register
          rdata(sources-2 downto 0)     := r.enable(selen)(sources-1 downto 1);
        end if; -- apbi.paddr(12)
      end if; -- apbi.paddr(THR_BIT)
    end if;
        
    -- APB Write Access
    if ((apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1') then
      -- Source of Completion Notification
      cmplsource  := to_integer(unsigned(apbi.pwdata(srcbits-1 downto 0)));
      if apbi.paddr(THR_BIT) = '1' then -- Claim/complete register block

        case apbi.paddr(2) is
          when '0' => -- threshold register
            if thrshld = 1 then
              v.threshold(selhart)              := apbi.pwdata(prbits-1 downto 0);
            end if;
            
          when '1' => -- claim/complete register
            -- Interrupt Completion
            if r.claimed(selhart)(cmplsource) = '1' then
              v.complete(cmplsource)            := '1';
              v.claimed(selhart)(cmplsource)    := '0';
            end if;

          when others =>
        end case; -- apbi.addr(2)
    
      else
        if apbi.paddr(THR_BIT-1 downto 13) = zerow(THR_BIT-1 downto 13) then 
          if apbi.paddr(12) = '0' then -- priority register
            v.priorities(selsrc)                := apbi.pwdata(prbits-1 downto 0);
          end if;
        else -- enable register
          v.enable(selen)(sources-1 downto 1)   := apbi.pwdata(sources-2 downto 0);
        end if; -- apbi.paddr(12)
      end if; -- apbi.paddr(THR_BIT)
    end if;

    -- Hardwired claimed bits for ID 0
    for i in 0 to ntargets-1 loop
      v.claimed(i)(0) := '0';
    end loop;

    rin <= v;

    -- PLIC Signals
    threshold           <= r.threshold;
    pr_in_array         <= r.priorities;
    complete            <= r.complete;
    claim               <= r.claim;
    enable              <= r.enable;

    -- APB Interface
    apbo.prdata         <= rdata;
    apbo.pirq           <= (others => '0');
    apbo.pconfig        <= pconfig;
    apbo.pindex         <= pindex;

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

