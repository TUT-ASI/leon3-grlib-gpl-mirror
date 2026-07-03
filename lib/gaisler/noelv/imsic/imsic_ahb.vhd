------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
-- Entity:      imsic_ahb
-- File:        imsic_ahb.vhd
-- Author:      Francisco Bas, Frontgrade Gaisler AB
-- Description: Incoming MSI Controller (IMSIC) AHB Slave
--
--              The IMSIC is divided into two distinct parts. The part implemented
--              in this file is an AHB slave designed to receive MSIs (Message
--              Signaled Interrupts) through the bus. The AHB slave includes an
--              interface to each CPU, which is used to communicate interrupts
--              transmitted through the bus.
--
--              On the other side, each CPU implements Interrupt Files. Their
--              purpose is to receive interrupts from the IMSIC AHB slave and
--              forward them to the CPU when they are enabled and pending.
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.conv_integer;
use grlib.stdlib.conv_std_logic_vector;
use grlib.stdlib.log2x;

library gaisler;
use gaisler.noelv.imsic_irq_vector;
use gaisler.noelv.nv_irq_in_vector;
use gaisler.noelv.imsic_irq_none;
use gaisler.noelv.MAX_HARTS;
use gaisler.noelv.nidentities_vector;
use gaisler.noelv.XLEN;


entity imsic_ahb is
  generic (
    hindex          : integer range 0 to NAHBSLV-1  := 0;
    hbaren          : integer range 0 to 1          := 0;  -- When set to 1 imsic is part of an ahb slave with several mem bars
    haddr           : integer range 0 to 16#FFF#    := 0;
    hbar            : integer range 0 to 3          := 0;
    ncpu            : integer range 0 to MAX_HARTS  := 0;   -- Number of cpus in the system
    GEILEN          : integer                       := 0;   -- System virtual guest external interrupt number
    groups          : integer                       := 0;   -- Number of core groups (set to 0 if cores are not grouped)
    S_EN            : integer range 0 to 1          := 0;   -- Set to 1 if supervisor mode is implemented
    H_EN            : integer range 0 to 1          := 0;   -- Set to 1 if hipervisor extension is implemented
    -- The external interrupt identities in a interrupt file must be a multiple of 64 -1: from 63 to 2047
    -- Each interrupt file can have a different number of external interrupt identities
    mnidentities_vector : nidentities_vector;
    snidentities_vector : nidentities_vector;
    gnidentities_vector : nidentities_vector;
    scantest        : integer                       := 0
    );
  port (
    rst         : in  std_ulogic;
    clk         : in  std_ulogic;
    ahbi        : in  ahb_slv_in_type;
    ahbo        : out ahb_slv_out_type;
    -- If no CDC is needed we can hardware this to 1
    irq_ack     : in  std_logic_vector(0 to ncpu-1) := (others => '1');
    irqo        : out imsic_irq_vector(0 to ncpu-1)
    );
end;


architecture rtl of imsic_ahb is
  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  -- Since each interrupt file could have a different number of interrupt
  -- identities we have to calculate the one with the highest number
  function max_nidentities(midentities : nidentities_vector;
                           sidentities : nidentities_vector;
                           gidentities : nidentities_vector) return integer is
    variable max : integer := 0;
  begin
    for i in midentities'range loop
      if midentities(i) > max then
        max := midentities(i);
      end if;
    end loop;
    for i in sidentities'range loop
      if sidentities(i) > max then
        max := sidentities(i);
      end if;
    end loop;
    for i in gidentities'range loop
      if gidentities(i) > max then
        max := gidentities(i);
      end if;
    end loop;
    return max;
  end function;

  constant zero32 : std_logic_vector(31 downto 0) := (others => '0');

  function set_G_EN(
    value : integer)
    return integer is
  begin
    if value = 0 then
      return 0;
    else
      return 1;
    end if;
  end function;

  constant G_EN : integer range 0 to 1 := set_G_EN(groups); -- If groups is different than 0, then G_EN is 1

  -- Returns the proper hmask parameter for a slave address range of
  -- "addr_bits" bits.
  function bits2hmask(addr_bits : integer) return integer is
    variable mask_bits   : integer;
    variable mask : unsigned(11 downto 0);
  begin
    if addr_bits < 21 then
      return 16#FFF#;
    else
      mask_bits := addr_bits - 20;
    end if;

    for i in 0 to 11 loop
      if i < mask_bits then
        mask(i) := '0';
      else
        mask(i) := '1';
      end if;
    end loop;

    return to_integer(mask);
  end function;

  function calc_upperLimit(addr_bits : integer) return integer is
  begin
    if addr_bits < 21 then
      return 20;
    else
      return addr_bits;
    end if;
  end function;

  -- Calculates the number of cores in each group
  function calc_CpG(ncpu : integer; groups : integer; G_EN : integer) return integer is
    variable CoresPerGroup : integer;
  begin
    if G_EN = 0 then
      CoresPerGroup := ncpu;
    else
      CoresPerGroup := ncpu/groups;
    end if;
    return CoresPerGroup;
  end function;



  constant intidbits     : integer := log2x(max_nidentities(mnidentities_vector, snidentities_vector, gnidentities_vector));
  constant CoresPerGroup : integer := calc_CpG(ncpu, groups, G_EN);
  constant ncpubits      : integer := log2x(CoresPerGroup);       -- If cores are not grouped CoresPerGroup = ncpu
  constant vcpubits      : integer := log2x(GEILEN+1);            -- One is added because the group also cotains the supervisor hart
  constant groupbits     : integer := log2x(groups);
  constant total_bits    : integer := S_EN+G_EN*groupbits+H_EN*vcpubits+ncpubits+12;
  -- NOTE: the IMSIC should be align in such a way that being A the base address:
  -- A + total_bits = A | total bits (being | a logical or operator)

  constant hmask : integer range 0 to 16#FFF# := bits2hmask(total_bits);
  constant REVISION : integer := 0;

  -- If hbaren is set to 1 this output will be ignored
  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_IMSIC, 0, REVISION, 0),
    4 => ahb_membar(haddr, '0', '0', hmask),
    others => zero32);


  type reg_type is record
    irqo        : imsic_irq_vector(0 to ncpu-1);
    -- AHB interface
    hsel        : std_ulogic;
    hready      : std_logic;
    hwrite      : std_logic;
    hsize       : std_logic_vector(2 downto 0);
    haddr       : std_logic_vector(31 downto 0);
    hresp       : std_logic_vector(1 downto 0);
    hrdata      : std_logic_vector(31 downto 0);
  end record;


  constant RES_T : reg_type := (
    irqo        => (others => imsic_irq_none),
    hsel        => '0',
    hready      => '0',
    hwrite      => '0',
    hsize       => (others => '0'),
    haddr       => (others => '0'),
    hresp       => (others => '0'),
    hrdata      => (others => '0')
    );


  -- Add register to improve timing paths. Adds one wait-state on
  -- Read and write accesses.
  constant pipe     : boolean := true;

  signal r, rin    : reg_type;
  signal arst           : std_ulogic;

begin
  arst        <= ahbi.testrst when (ASYNC_RESET and scantest/=0 and ahbi.testen/='0') else
                 rst when ASYNC_RESET else '1';

  comb : process (r, ahbi, irq_ack)
    variable v               : reg_type;
    variable hsel            : std_ulogic;
    variable hrdata          : std_logic_vector(31 downto 0);
    variable rdata           : std_logic_vector(31 downto 0);
    variable hwdata          : std_logic_vector(31 downto 0);
    variable ewdata          : std_logic_vector(31 downto 0);
    -- To choose between Machine and Supervisor interrupt files
    variable mode_off        : std_logic_vector(calc_upperLimit(total_bits)-1 downto groupbits*G_EN+ncpubits+H_EN*vcpubits+12);
    variable mode_sel        : integer;
    -- To chose among the different machine interrupt files
    variable mhart_off       : std_logic_vector(ncpubits+12-1 downto 12);
    variable mhart_sel       : integer;
    -- To check (if H_EN = 1 and groups = 0) that the bits between the mode_off bit and the mhart_sel bits
    -- are zero when accessing machine interrupt file
    variable mgap            : std_logic_vector(mode_off'HIGH-1 downto ncpubits+12);
    -- To choose among the different supervisor groups containing the supervisor intterupt files
    -- and all the guest interrupt files associated to that hart
    variable shart_off       : std_logic_vector(ncpubits+H_EN*vcpubits+12-1 downto H_EN*vcpubits+12);
    variable shart_sel       : integer;
    -- To choose the interrupt file among the guest interrupt files, being the first one the supervisor interrupt file
    variable ghart_off       : std_logic_vector(vcpubits+12-1 downto 12);
    variable ghart_sel       : integer;
    -- To determine the group if cores are grouped
    variable group_off       : std_logic_vector(groupbits+H_EN*vcpubits+ncpubits+12-1 downto H_EN*vcpubits+ncpubits+12);
    variable group_sel       : integer;
    -- To choose the endianness
    variable endianness_off  : std_logic_vector(2 downto 2);
  begin

    v := r;


    v.hsel    := '0';
    v.hready  := '1';
    v.hresp   := HRESP_OKAY;

    -- Any legal read address must return zeros
    rdata       := (others => '0');

    -- When ACK signal is received set data_rdy to 0. The IMSIC interrupt files
    -- registers a new data each time the data_rdy signal transitions from 0 to 1.
    -- When CDC is required, the ack signal comes from nvirqcdc. When not, the ack signal
    -- must be hardwire to 1 so each time there is a new interrupt a pulse is sent.
    for i in 0 to ncpu-1 loop
      if irq_ack(i) = '1' then
        v.irqo(i).data_rdy := '0';
      end if;
    end loop;

    ---------------------------------------------------
    -- Register Map
    ---------------------------------------------------

    -- Each interrupt file has only two write registers (reads return zeros)
    -- 0x000 seteipnum_le (Little-Endian)
    -- 0x004 seteipnum_be (Big-Endian)
    -- The offset between interrupt files is 4 KiB (one page)
    -- All machine interrupt files are stacked together:
    -- M0,M1,M2,...,MN  Being  the index the index of the physical hart.
    -- Interrupt files for supervisor (S) and guest (G) harts are stacked
    -- together as follows: S0,G01,G02,...,G0N ; S1,G11,G22,...,G1N
    -- Being the first index the physical hart and the second index
    -- the virtual hart.

    -- The register map changes depending on the number of physical
    -- harts and the GEILEN value. It also changes if
    -- supervisor mode is not implemented.

    -- It could happen that the cores of the system are divided in different
    -- groups (e.g., 4 clusters of 4 cores).
    -- If IMSIC groups are active the layout of the memory map will change.


    -- MEMORY MAP WIHTOUT GROUPS:
    -- For machine interrupt-file registers
    --                 ( cpu_sel | 0x000)   when GEILEN > 0
    --                 ( cpu_sel | 0x000)   when GEILEN = 0
    -- For supervisor and guest interrupt-file registers
    -- ('1' | cpu_sel | vcpu_sel | 0x000)   when GEILEN > 0
    --           ('1' |  cpu_sel | 0x000)   when GEILEN = 0

    -- The MSB is used to determine if supervisor/guest or machine file register is selected,
    -- if supervisor mode is not active, the memory map will contain only the machine
    -- interrupt files.


    -- MEMORY MAP WIHT GROUPS:
    -- For machine interrupt-file registers
    -- ('0' | group_sel |  vcpu_sel | cpu_sel | 0x000)   when GEILEN > 0  (vcpubits bits are always zero in this particular case)
    --             ('0' | group_sel | cpu_sel | 0x000)   when GEILEN = 0
    -- For supervisor and guest interrupt-file registers
    -- ('1' | group_sel |   cpu_sel | vcpu_sel | 0x000)  when GEILEN > 0
    --             ('1' | gropu_sel |  cpu_sel | 0x000)  when GEILEN = 0

    -- The MSB is used to determine if supervisor/guest or machine file register is selected,
    -- if supervisor mode is not active, that bit is not employed.

    -- * cpu_sel field corresponds to the interrupt file physical hart.
    --   The length of he field is ncpu_bits.
    -- * ncpu_bits represents the number of bits needed to address every physical hart.
    --   [ncpu_bits = ceil(log2(ncpu))]; ncpu_bits is 1 for one core.
    -- * vcpu_sel field corresponds to the interrupt file virtual hart. If it is set to
    --   0 the it points to the Supervisor mode interrupt file of the physical hart selected.
    --   The length of the field is vcpu_bits.
    -- * vcpu_bits represent the number of bits needed to address every supervisor and
    --   virutal hart. [vcpu_bits = ceil(log2(GEILEN+1))].
    --   vcpu_bits are zero if GEILEN=0.
    -- * group_sel must be set to the group if harts are grouped.


    -- Example: Supervisor mode enabled, GEILEN=16, 4 cpus and no groups

    -- Machine Interrupt Files:
    -- Machine Interrupt File Hart 0:      0x0000  [0 << 12]
    -- Machine Interrupt File Hart 1:      0x1000  [1 << 12]
    -- Machine Interrupt File Hart 1:      0x2000  [2 << 12]
    -- Machine Interrupt File Hart 1:      0x3000  [3 << 12]

    -- Supervisor Interrupt Files: (OFFSET 0x80000 = 1 << (ncpu_bits + vcpu_bis + 12))
    -- Supervisor Interrupt File Hart 0:   0x80000  [0x80000 + (0 << 17) + (0 << 12)]
    -- Guest (1)  Interrupt File Hart 0:   0x81000  [0x80000 + (0 << 17) + (1 << 12)]
    -- Guest (2)  Interrupt File Hart 0:   0x82000  [0x80000 + (0 << 17) + (2 << 12)]
    -- ...
    -- Guest (16) Interrupt File Hart 0:   0x90000  [0x80000 + (0 << 17) + (16 << 12)]
    -- Supervisor Interrupt File Hart 1:   0xA0000  [0x80000 + (1 << 17) + (0 << 12)]
    -- Guest (1)  Interrupt File Hart 1:   0xA1000  [0x80000 + (1 << 17) + (1 << 12)]
    -- Guest (2)  Interrupt File Hart 1:   0xA2000  [0x80000 + (1 << 17) + (2 << 12)]
    -- ...
    -- Guest (16) Interrupt File Hart 1:   0xB0000  [0x80000 + (1 << 17) + (16 << 12)]
    -- ...
    -- Supervisor Interrupt File Hart 3:   0xE0000  [0x80000 + (3 << 17) + (0 << 12)]
    -- Guest (1)  Interrupt File Hart 3:   0xE1000  [0x80000 + (3 << 17) + (1 << 12)]
    -- Guest (2)  Interrupt File Hart 3:   0xE2000  [0x80000 + (3 << 17) + (2 << 12)]
    -- ...
    -- Guest (16) Interrupt File Hart 3:   0xF0000  [0x80000 + (3 << 17) + (16 << 12)]


    ---------------------------------------------------
    -- AHB Interface
    ---------------------------------------------------
    hwdata := ahbi.hwdata(31 downto 0); -- Only 32 bits accesses are allowed

    -- Slave selected
    -- If it belongs to a AHB slave with several memory bars we need to  check
    -- if the memory bar is selected
    if hbaren = 0 then
      hsel :=  ahbi.hsel(hindex);
    else
      hsel :=  ahbi.hsel(hindex) and ahbi.hmbsel(hbar);
    end if;


    -- When a new transaction starts:
    -- * Control signals are registered and a wait state is inserted
    --   the next cycle.
    -- * The second cycle if there isn't a transaction ongoing to the
    --   targeted interrupt file the transaction finishes.
    -- * If there is a pending transaction the ready signal is ketp
    --   low until the previous transaction has finished. Control
    --   signals are not updated and ahbi.hwrite is kept stable.

    if (ahbi.hready and hsel and ahbi.htrans(1)) = '1' then
      v.hsel   := '1';
      v.haddr  := ahbi.haddr;
      v.hsize  := ahbi.hsize;
      v.hwrite := ahbi.hwrite;
      -- Insert always a wait state to improve timing
      v.hready := '0';
    end if;


    -- Write access
    mode_off  := r.haddr(mode_off'range);
    mhart_off := r.haddr(mhart_off'range);
    mgap      := r.haddr(mgap'range);
    shart_off := r.haddr(shart_off'range);
    ghart_off := r.haddr(ghart_off'range);
    group_off := r.haddr(group_off'range);
    endianness_off := r.haddr(endianness_off'range);

    mode_sel  := conv_integer(mode_off);
    mhart_sel := conv_integer(mhart_off);
    shart_sel := conv_integer(shart_off);
    ghart_sel := conv_integer(ghart_off);
    if (groups /= 0) then
      group_sel := conv_integer(group_off);
    else
      group_sel := 0;
    end if;

    -- Endianness
    if endianness_off = "0" then -- little endian
      ewdata := hwdata;
    else -- big endian
      ewdata := hwdata(7 downto 0) & hwdata(15 downto 8) & hwdata(23 downto 16) & hwdata(31 downto 24);
    end if;


    if r.hsel = '1' and (r.haddr(11 downto 0) = x"000" or r.haddr(11 downto 0) = x"004")
         and r.hwrite = '1' and r.hsize = "010" then -- Transfer size = 32 bits
      if mode_sel = 0 then -- machine mode
        if groups /= 0 then mhart_sel := conv_integer(conv_std_logic_vector(group_sel, groupbits) & conv_std_logic_vector(mhart_sel, ncpubits)); end if;
        if mhart_sel < ncpu  and unsigned(ewdata) <= mnidentities_vector(mhart_sel) and (H_EN = 0 or unsigned(mgap) = 0 or groups /= 0) then
          if r.irqo(mhart_sel).data_rdy = '0' then
            v.irqo(mhart_sel).int_id(intidbits-1 downto 0) := ewdata(intidbits-1 downto 0);
            v.irqo(mhart_sel).supervisor                         := '0';
            v.irqo(mhart_sel).data_rdy                           := '1';
          else
            -- Data is being transfered to the CPU, insert wait state into the bus
            v.hready := '0';
            v.hsel   := '1';
          end if;
        end if;
      elsif mode_sel = 1 and S_EN = 1 then -- supervisor mode
        if groups /= 0 then shart_sel := conv_integer(conv_std_logic_vector(group_sel, groupbits) & conv_std_logic_vector(shart_sel, ncpubits)); end if;
        if unsigned(ghart_off) = 0 or H_EN = 0 then -- physical supervisor harts
          if shart_sel < ncpu and unsigned(ewdata) <= snidentities_vector(shart_sel) then
            if r.irqo(shart_sel).data_rdy = '0' then
              v.irqo(shart_sel).int_id(intidbits-1 downto 0) := ewdata(intidbits-1 downto 0);
              v.irqo(shart_sel).supervisor                         := '1';
              v.irqo(shart_sel).guest                              := (others => '0');
              v.irqo(shart_sel).data_rdy                           := '1';
            else
              -- Data is being transfered to the CPU, insert wait state into the bus
              v.hready := '0';
              v.hsel   := '1';
            end if;
          end if;
        else -- (H_EN = 1 and ghart_off > 0) virtual harts
          if shart_sel < ncpu and ghart_sel <= GEILEN and unsigned(ewdata) <= gnidentities_vector(shart_sel*GEILEN+ghart_sel-1) then
            if r.irqo(shart_sel).data_rdy = '0' then
              v.irqo(shart_sel).int_id(intidbits-1 downto 0) := ewdata(intidbits-1 downto 0);
              v.irqo(shart_sel).supervisor                         := '1';
              v.irqo(shart_sel).guest                              := conv_std_logic_vector(ghart_sel, vcpubits);
              v.irqo(shart_sel).data_rdy                           := '1';
            else
              -- Data is being transfered to the CPU, insert wait state into the bus
              v.hready := '0';
              v.hsel   := '1';
            end if;
          end if;
        end if;
      end if;
    end if;


    -- Error response:
    -- Only naturally aligned 32-bit simple reads and writes are supported within an interrupt file’s
    -- memory region. Writes to read-only bytes are ignored. For other forms of accesses (other sizes,
    -- misaligned accesses, or AMOs), an IMSIC implementation should preferably report an access fault
    -- or bus error but must otherwise ignore the access.
    if v.hsel = '1' then
      if v.hsize /= "010" then
        v.hready := '0';
        v.hresp  := HRESP_ERROR;
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

    rin <= v;

    -- AHB Interface
    ahbo.hready         <= r.hready;
    ahbo.hrdata         <= ahbdrivedata(hrdata);
    ahbo.hresp          <= r.hresp;
    ahbo.hsplit         <= (others => '0');
    ahbo.hirq           <= (others => '0');
    ahbo.hconfig        <= hconfig;
    ahbo.hindex         <= hindex;

    -- Interrupt output
    irqo                <= r.irqo;


  end process;


  syncrregs : if not ASYNC_RESET generate
    regs : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if rst = '0' then
          r <= RES_T;
        end if;
      end if;
    end process;
  end generate;

  asyncrregs : if ASYNC_RESET generate
    regs : process(clk, arst)
    begin
      if arst = '0' then
        r <= RES_T;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;
  end generate;

  -- Check that all the interrupt files have a valid number of EIIDs
  neiid_check: for i in mnidentities_vector'range generate
    assert mnidentities_vector(i) mod 64 = 63
      report "Invalid mnidentities_vector; all valus must be a multiple of 64 minius 1"
      severity failure;
    assert snidentities_vector(i) mod 64 = 63
      report "Invalid mnidentities_vector; all valus must be a multiple of 64 minius 1"
      severity failure;
  end generate neiid_check;
  guest_neiid_check: for i in gnidentities_vector'range generate
    assert gnidentities_vector(i) mod 64 = 63
      report "Invalid mnidentities_vector; all valus must be a multiple of 64 minius 1"
      severity failure;
  end generate guest_neiid_check;

end rtl;
