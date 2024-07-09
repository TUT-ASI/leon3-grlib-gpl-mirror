------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
-- Entity:      grimsic_ahb
-- File:        grimsic_ahb.vhd
-- Author:      Francisco Bas, Cobham Gaisler AB
-- Description: Incoming MSI Controller (IMSIC)
--
--              It includes a RISC-V privilege spec 1.12 (WIP) compatible IMSIC.
--              IMSIC is implemented followin the specs described in the document
--              'RISC-V Advanced Interrupt Architeture (AIA) 0.3.1-draft'
--              IMSIC implements Mesagge Signaled Interrupts (MSI) for every 
--              physical and virtual hart in the system 
--              It implements an AHB AMBA interface to support 32-bit accesses.
--              It includes an interface for the indirecly accessed interrupt-file
--              registers defined at the AIA specs.
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.conv_integer;
use grlib.stdlib.conv_std_logic_vector;
use grlib.stdlib.log2x;

library gaisler;
use gaisler.imsic.all;
use gaisler.noelv.imsic_in_vector;   
use gaisler.noelv.imsic_out_vector;   
use gaisler.noelv.nv_irq_in_vector;   
use gaisler.noelv.XLEN;


entity grimsic_ahb is
  generic (
    hindex          : integer range 0 to NAHBSLV-1  := 0;
    haddr           : integer range 0 to 16#FFF#    := 0;
    ncpu            : integer range 0 to MAX_HARTS  := 5;   -- Number of cpus in the system
    GEILEN          : integer                       := 5;   -- System virtual guest external interrupt number 
    groups          : integer                       := 0;   -- Number of core groups (set to 0 if cores are not grouped)
    S_EN            : integer range 0 to 1          := 1;   -- Set to 1 if supervisor mode is implemented
    H_EN            : integer range 0 to 1          := 1;   -- Set to 1 if hipervisor extension is implemented
    plic            : integer range 0 to 1          := 1;   -- Set to 1 if there is a PLIC/APLIC in the system
    -- The external interrupt identities in a interrupt file must be a multiple of 64 -1: from 63 to 2047 
    -- Each interrupt file can have a different number of external interrupt identities
    mnidentities_vector : nidentities_vector; 
    snidentities_vector : nidentities_vector; 
    gnidentities_vector : nidentities_vector
    );
  port (
    rst         : in  std_ulogic;
    clk         : in  std_ulogic;
    ahbi        : in  ahb_slv_in_type;
    ahbo        : out ahb_slv_out_type;
    plic_meip   : in  std_logic_vector(0 to ncpu-1);
    plic_seip   : in  std_logic_vector(0 to ncpu-1);
    imsici      : in  imsic_in_vector(0 to ncpu-1);
    imsico      : out imsic_out_vector(0 to ncpu-1);
    eip         : out nv_irq_in_vector(0 to ncpu-1)
    );
end;


architecture rtl of grimsic_ahb is

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



  constant CoresPerGroup : integer := calc_CpG(ncpu, groups, G_EN);
  constant ncpubits      : integer := log2x(CoresPerGroup);       -- If cores are not grouped CoresPerGroup = ncpu
  constant vcpubits      : integer := log2x(GEILEN+1);            -- One is added because the group also cotains the supervisor hart
  constant groupbits     : integer := log2x(groups);
  constant total_bits    : integer := S_EN+G_EN*groupbits+H_EN*vcpubits+ncpubits+12;
  -- WARNING: the IMSIC should be align in such a way that being A the base address:
  -- A + total_bits = A | total bits (being | a logical or operator)

  constant hmask : integer range 0 to 16#FFF# := bits2hmask(total_bits);
  constant REVISION : integer := 0;

  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_IMSIC, 0, REVISION, 0),
    4 => ahb_membar(haddr, '0', '0', hmask),
    others => zero32);


  type vs_vector is array (natural range <>) of std_logic_vector(XLEN-1 downto 0);
  type guestIntFile_in_type is record
    vstopei_w : std_logic_vector(GEILEN downto 1);    -- Virtual Supervisor top external interrupt write
    vsiselect : vs_vector(GEILEN downto 1);           -- Virtual Supervisor indirect register select value
    vsireg    : vs_vector(GEILEN downto 1);           -- Virtual Supervisor indirect register alias value
    vsireg_w  : std_logic_vector(GEILEN downto 1);    -- Virtual Supervisor indirect register alias write
  end record;

  type guestIntFile_out_type is record
    vstopei  : vs_vector(GEILEN downto 1);          -- Virtual top external interrupt register value
    vsireg   : vs_vector(GEILEN downto 1);          -- Virtual indirect register alias value
  end record;
  type guestIntFile_in_vector is array (natural range <>) of guestIntFile_in_type; 
  type guestIntFile_out_vector is array (natural range <>) of guestIntFile_out_type; 

  type reg_type is record
    -- Signals to propagate AHB writes to each IMSIC interrupt file
    mahbw       : std_logic_vector(ncpu-1 downto 0);
    sahbw       : std_logic_vector(ncpu-1 downto 0);
    gahbw       : std_logic_vector(ncpu*GEILEN-1 downto 0);
    mseteipnum  : std_logic_vector(31 downto 0);
    sseteipnum  : std_logic_vector(31 downto 0);
    gseteipnum  : std_logic_vector(31 downto 0);
    -- AHB interface
    hsel        : std_logic_vector(1 downto 0);
    hready      : std_logic;
    hwrite      : std_logic;
    hsize       : std_logic_vector(2 downto 0);
    haddr       : std_logic_vector(31 downto 0);
    hresp       : std_logic_vector(1 downto 0);
    hwdata      : std_logic_vector(31 downto 0);
    hrdata      : std_logic_vector(31 downto 0);
  end record;


  constant RES_T : reg_type := (
    mahbw       => (others => '0'),
    sahbw       => (others => '0'),
    gahbw       => (others => '0'),
    mseteipnum  => (others => '0'),
    sseteipnum  => (others => '0'),
    gseteipnum  => (others => '0'),
    hsel        => (others => '0'),
    hready      => '0',
    hwrite      => '0',
    hsize       => (others => '0'),
    haddr       => (others => '0'),
    hresp       => (others => '0'),
    hwdata      => (others => '0'),
    hrdata      => (others => '0')
    );


  -- Add register to improve timing paths. Adds one wait-state on
  -- Read and write accesses.
  constant pipe     : boolean := true;

  signal guest_in  : guestIntFile_in_vector(ncpu-1 downto 0);
  signal guest_out : guestIntFile_out_vector(ncpu-1 downto 0);
  signal r, rin    : reg_type;

begin

  -- One machine interrupt file register per physical hart is 
  -- instantiated
  machine_int_files_gen : for i in 0 to ncpu-1 generate
    machine_file : interrupt_file
    generic map(
      sources     => mnidentities_vector(i),
      plic        => plic
      )
    port map(
      rst         => rst,
      clk         => clk,
      -- AHB writes propagation
      ahbw        => r.mahbw(i),
      seteipnum   => r.mseteipnum,
      -- Indirectly accessed interrupt-file registers interface
      ireg_w      => imsici(i).mireg_w,
      iselect     => imsici(i).miselect,
      iregi       => imsici(i).mireg,
      irego       => imsico(i).mireg,
      topei_w     => imsici(i).mtopei_w, 
      topei       => imsico(i).mtopei,
      plic_eip    => plic_meip(i),
      eipo        => eip(i).meip
      );
  end generate machine_int_files_gen;

  -- One supervisor interrupt file register per physical hart 
  -- is instantiated
  supervisor_int_files: if S_EN = 1 generate
    supervisor_int_files_gen : for i in 0 to ncpu-1 generate
      supervisor_file : interrupt_file
      generic map(
        sources     => snidentities_vector(i),
        plic        => plic
        )
      port map(
        rst         => rst,
        clk         => clk,
        -- AHB writes propagation
        ahbw        => r.sahbw(i),
        seteipnum   => r.sseteipnum,
        -- Indirectly accessed interrupt-file registers interface
        ireg_w      => imsici(i).sireg_w,
        iselect     => imsici(i).siselect,
        iregi       => imsici(i).sireg,
        irego       => imsico(i).sireg,
        topei_w     => imsici(i).stopei_w, 
        topei       => imsico(i).stopei,
        plic_eip    => plic_seip(i),
        eipo        => eip(i).seip
        );
    end generate supervisor_int_files_gen;
  end generate supervisor_int_files;



  -- GEILEN interrupt files are instanciated
  -- Only the guest interrupt file pointed by vgein is used
  vgein_mux : for cpu in 0 to ncpu-1 generate
    vgein_mux2 : for guest in 1 to GEILEN generate
      -- INPUTS
      guest_in(cpu).vsireg_w(guest)  <= imsici(cpu).vsireg_w when unsigned(imsici(cpu).vgein) = guest else
                                        '0'; 
      guest_in(cpu).vsiselect(guest) <= imsici(cpu).vsiselect when unsigned(imsici(cpu).vgein) = guest else
                                        (others => '0'); 
      guest_in(cpu).vsireg(guest)    <= imsici(cpu).vsireg when unsigned(imsici(cpu).vgein) = guest else
                                        (others => '0'); 
      guest_in(cpu).vstopei_w(guest) <= imsici(cpu).vstopei_w when unsigned(imsici(cpu).vgein) = guest else
                                        '0'; 
    end generate vgein_mux2;
    -- OUTPUTS
    imsico(cpu).vsireg  <= guest_out(cpu).vsireg(conv_integer(imsici(cpu).vgein)) when 
                                unsigned(imsici(cpu).vgein) /= 0 and unsigned(imsici(cpu).vgein) <= GEILEN else
                           (others => '0'); 
    imsico(cpu).vstopei <= guest_out(cpu).vstopei(conv_integer(imsici(cpu).vgein)) when 
                                unsigned(imsici(cpu).vgein) /= 0 and unsigned(imsici(cpu).vgein) <= GEILEN else
                           (others => '0'); 
  end generate vgein_mux ;

  guest_int_files: if H_EN = 1 generate
    guest_int_files_h_gen : for i in 0 to ncpu-1 generate
      guest_int_files_g_gen : for j in 1 to GEILEN generate
        guest_file : interrupt_file
        generic map(
          sources     => gnidentities_vector(i*GEILEN+(j-1)),
          plic        => 0 -- Guest interrupt files do not support eidelivery=0x40000000
          )
        port map(
          rst         => rst,
          clk         => clk,
          -- AHB writes propagation
          ahbw        => r.gahbw(i*GEILEN+(j-1)),
          seteipnum   => r.gseteipnum,
          -- Indirectly accessed interrupt-file registers interface
          ireg_w      => guest_in(i).vsireg_w(j),
          iselect     => guest_in(i).vsiselect(j),
          iregi       => guest_in(i).vsireg(j),
          irego       => guest_out(i).vsireg(j),
          topei_w     => guest_in(i).vstopei_w(j), 
          topei       => guest_out(i).vstopei(j),
          plic_eip    => '0',
          eipo        => eip(i).hgeip(j)
          );
      end generate guest_int_files_g_gen;
    end generate guest_int_files_h_gen;
  end generate guest_int_files;

  -- Not implemented outputs
  out_gen : for i in 0 to ncpu-1 generate
    eip(i).ueip    <= '0'; -- not implemented
    eip(i).heip    <= '0'; -- not implemented
    -- These are added elsewhere
    eip(i).mtip    <= '0';
    eip(i).msip    <= '0';
    eip(i).ssip    <= '0';
    eip(i).stime   <= (others => '0');
  end generate out_gen;

  comb : process (r, ahbi)
    variable v               : reg_type;
    variable hrdata          : std_logic_vector(31 downto 0);
    variable rdata           : std_logic_vector(31 downto 0);
    variable hwdata          : std_logic_vector(31 downto 0);
    variable wdata           : std_logic_vector(31 downto 0);
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

    v.hsel    := (others => '0');
    v.hready  := '1';
    v.hresp   := HRESP_OKAY; 

    -- Any legal read address must return zeros
    rdata       := (others => '0'); 


    for i in 0 to ncpu-1 loop
      v.mahbw(i) := '0';
      v.sahbw(i) := '0';
    end loop;

    for i in 0 to GEILEN*ncpu-1 loop
      v.gahbw(i) := '0';
    end loop;

    v.mseteipnum := (others => '0');
    v.sseteipnum := (others => '0');
    v.gseteipnum := (others => '0');


    ---------------------------------------------------
    -- Register Map
    ---------------------------------------------------
    -- Each interrupt file has only two write (reads return zeros) registers
    -- 0x000 seteipnum_le (Little-Endian)
    -- 0x004 seteipnum_be (Big-Endian)
    -- The offset between interrupt files is 4 KiB (one page)
    -- All machine interrupt files are stacked together
    -- Interrupt files for supervisor (S) and guest (G) harts are stacked 
    -- together as follows: S1,G11,G12,...,G1N ; S2,G21,G22,...,G2N
    -- Being the first index the physical hart and the second index
    -- the virtual hart.

    -- The register map changes depending on the number of physical
    -- harts and the GEILEN value. It also changes if
    -- supervisor mode is not implemented.
    
    -- Address space is divided as follows to access the
    -- diferent interrupt file registers: 

    -- It could happen that the cores of the system are divided in different
    -- groups (e.g., 4 clusters of 4 cores). IMSIC can be configured to
    -- group the harts. In such case the memory map is also different


    -- MEMORY MAP WIHTOUT GROUPS:
    -- For machine interrupt-file registers
    -- ('0' | vcpu_bits | ncpu bits | 0x000)   when GEILEN > 0  (vcpubits bits are always zero, they just influence the number of zeros between the '1' and the 'ncpu bits')  
    --             ('0' | ncpu bits | 0x000)   when GEILEN = 0
    -- For supervisor and guest interrupt-file registers
    -- ('1' | ncpu bits | vcpu_bits | 0x000)   when GEILEN > 0
    --             ('1' | ncpu bits | 0x000)   when GEILEN = 0

    -- Being ncpu bits the number of bits needed to address every physical hart
    -- and vcpu_bits the number of bits needed to address every virtual hart plus 
    -- one (because zero is used to address the supervisor hart).
    -- The MSB is used to determine if supervisor/guest or machine file register is selected,
    -- if supervisor mode is not active, that bit is always zero.


    -- MEMORY MAP WIHT GROUPS:
    -- For machine interrupt-file registers
    -- ('0' | group bits |  vcpu_bits | ncpu bits | 0x000)   when GEILEN > 0  (vcpubits bits are always zero, they just indicate the number of zeros between the '1' and the 'ncpu bits')
    --             ('0'  | group bits | ncpu bits | 0x000)   when GEILEN = 0
    -- For supervisor and guest interrupt-file registers
    -- ('1' | group bits |  ncpu bits | vcpu_bits | 0x000)   when GEILEN > 0
    --             ('1'  | group bits | ncpu bits | 0x000)   when GEILEN = 0

    -- Being ncpu bits the number of bits needed to address a core within a group
    -- and vcpubits the number of bits needed to address every virtual hart (being zero the supervisor hart).
    -- The MSB is used to determine if supervisor/guest or machine file register is selected,
    -- if supervisor mode is not active, that bit is not employed.

    ---------------------------------------------------
    -- AHB Interface
    ---------------------------------------------------
    hwdata := ahbi.hwdata(31 downto 0); -- Only 32 bits accesses are allowed

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
      ewdata := wdata;
    else -- big endian
      ewdata := wdata(7 downto 0) & wdata(15 downto 8) & wdata(23 downto 16) & wdata(31 downto 24);
    end if;


    if r.hsel(1) = '1' and (r.haddr(11 downto 0) = x"000" or r.haddr(11 downto 0) = x"004") 
         and r.hwrite = '1' and r.hsize = "010" then -- Transfer size = 32 bits
      if mode_sel = 0 then -- machine mode
        if groups /= 0 then mhart_sel := conv_integer(conv_std_logic_vector(group_sel, groupbits) & conv_std_logic_vector(mhart_sel, ncpubits)); end if; 
        if mhart_sel < ncpu  and unsigned(ewdata) <= mnidentities_vector(mhart_sel) and (H_EN = 0 or unsigned(mgap) = 0 or groups /= 0) then  
          v.mahbw(mhart_sel) := '1';
          v.mseteipnum := ewdata;
        end if;
      elsif mode_sel = 1 and S_EN = 1 then -- supervisor mode
        if groups /= 0 then shart_sel := conv_integer(conv_std_logic_vector(group_sel, groupbits) & conv_std_logic_vector(shart_sel, ncpubits)); end if; 
        if unsigned(ghart_off) = 0 or H_EN = 0 then -- physical supervisor harts
          if shart_sel < ncpu and unsigned(ewdata) <= snidentities_vector(shart_sel) then 
            v.sahbw(shart_sel) := '1';
            v.sseteipnum := ewdata;
          end if;
        else -- (H_EN = 1 and ghart_off > 0) virtual harts
          if shart_sel < ncpu and ghart_sel <= GEILEN and unsigned(ewdata) <= gnidentities_vector(shart_sel*GEILEN+ghart_sel-1) then
            v.gahbw(shart_sel*GEILEN+ghart_sel-1) := '1';
            v.gseteipnum := ewdata;
          end if;
        end if;
      end if;
    end if;

    -- Error response 
    -- Only naturally aligned 32-bit simple reads and writes are supported within an interrupt file’s
    -- memory region. Writes to read-only bytes are ignored. For other forms of accesses (other sizes,
    -- misaligned accesses, or AMOs), an IMSIC implementation should preferably report an access fault
    -- or bus error but must otherwise ignore the access.
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

    rin <= v;

    -- AHB Interface
    ahbo.hready         <= r.hready;
    ahbo.hrdata         <= ahbdrivedata(hrdata);
    ahbo.hresp          <= r.hresp;
    ahbo.hsplit         <= (others => '0');
    ahbo.hirq           <= (others => '0');
    ahbo.hconfig        <= hconfig;
    ahbo.hindex         <= hindex;


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


end rtl;
