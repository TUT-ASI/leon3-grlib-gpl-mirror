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
-- Entity:      dmnv_ahbs
-- File:        dmnv_ahbs.vhd
-- Author:      Nils Wessman
-- Description: AHB slave inteface for NOEL-V debug module and trace
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.l5nv_shared.all;

entity dmnv_ahbs is
  generic (
    hindex    : integer range 0  to 15  := 0;   -- bus index
    hmindex   : integer range 0  to 15  := 0;   -- master bus index
    haddr     : integer                 := 16#900#;
    hmask     : integer                 := 16#f00#
  );
  port (
    clk     : in  std_ulogic;
    rstn    : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    ahbmi   : in  ahb_mst_in_type;
    ahbmo   : out ahb_mst_out_type;
    -- DM interface
    dmi     : out dev_reg_in_type;
    dmo     : in  dev_reg_out_type := dev_reg_out_none;
    dmi2    : out dev_reg_in_type;
    dmo2    : in  dev_reg_out_type := dev_reg_out_none;
    -- Trace interface
    tri     : out dev_reg_in_type;
    tro     : in  dev_reg_out_type;
    -- LEON5 mode
    l5mode  : in  std_ulogic;
    -- LEON5 itrace buffer
    l5iti   : out dev_reg_in_type;
    l5ito   : in  dev_reg_out_type;
    -- LEON5 iu reg access
    l5iui   : out dev_reg_in_type;
    l5iuo   : in  dev_reg_out_type
  );
end;

architecture rtl of dmnv_ahbs is
  -- Constants --------------------------------------------------------------
  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant AREA_H       : integer := 21;
  constant AREA_L       : integer := 19;
  -- AMBA PnP
  -- RVDM is instantiated both as a Slave and as a Master. For GRMON to work
  -- properly version of Master and Slave have to coincide. If RVDM_VERSION
  -- is modified inside this file, RVDM_VERSION of the Slave must be modified
  -- accordingly.
  constant RVDM_VERSION : integer := 2;
  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_RVDM, 0, RVDM_VERSION, 0),
    4 => ahb_membar(haddr, '0', '0', hmask),
    others => zero32);
  -- in LEON5 mode
  constant DSU5_VERSION : integer := 3;
  constant hconfig_l5 : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_LEON5DSU, 0, DSU5_VERSION, 0),
    4 => ahb_membar(haddr, '0', '0', hmask),
    others => zero32);
  -- Add register to improve timing paths. Adds one wait-state on
  -- Read and write accesses.
  -- Note pipe must be set to true to correctly generate wait states
  -- if dmo/tro.rdy can go low.
  constant pipe         : boolean := true;

  -- Types ------------------------------------------------------------------
  type ahb_reg_type is record
    hsel                : std_logic_vector(1 downto 0);
    hready              : std_logic;
    hwrite              : std_logic;
    hsize               : std_logic_vector(2 downto 0);
    haddr               : std_logic_vector(31 downto 0);
    hresp               : std_logic_vector(1 downto 0);
    hwdata              : std_logic_vector(REGW-1 downto 0);
    hrdata              : std_logic_vector(REGW-1 downto 0);
    hhold               : std_logic_vector(1 downto 0);
  end record;
  constant ahb_reg_none : ahb_reg_type := (
    hsel                => (others => '0'),
    hready              => '0',
    hwrite              => '0',
    hsize               => (others => '0'),
    haddr               => (others => '0'),
    hresp               => (others => '0'),
    hwdata              => (others => '0'),
    hrdata              => (others => '0'),
    hhold               => (others => '0'));

  type reg_type is record
    -- AHB Interface
    ahb       : ahb_reg_type;
    -- System bus access
    dodma     : std_ulogic;
    sbwr      : std_ulogic;
    sbaccess  : std_logic_vector(2 downto 0);
  end record;
  constant RES_T : reg_type := (
    ahb        => ahb_reg_none,
    -- System bus access
    dodma     => '0',
    sbwr      => '0',
    sbaccess  => (others => '0')
    );

  -- Signals ----------------------------------------------------------------
  signal r, rin : reg_type;     
  -- AHB Master control signals
  signal ami : ahb_dma_in_type;
  signal amo : ahb_dma_out_type;


begin

  -- Generic AHB master interface
  ahbmst0 : ahbmst
  generic map (hindex => hmindex, hirq => 0, venid => VENDOR_GAISLER,
               devid => GAISLER_RVDM, version => RVDM_VERSION,
               chprot => 16#3#, incaddr => 0)
  port map (rstn, clk, ami, amo, ahbmi, ahbmo);


  comp : process(r, ahbsi, ahbmi, amo, dmo, dmo2, tro, l5mode, l5ito, l5iuo)
    variable v    : reg_type;
    -- AHB Interface
    variable hready         : std_ulogic;
    variable hrdata         : std_logic_vector(REGW-1 downto 0);
    variable rdata          : std_logic_vector(REGW-1 downto 0);
    variable hwdata         : std_logic_vector(REGW-1 downto 0);
    variable wdata          : std_logic_vector(REGW-1 downto 0);
    variable hasel1         : std_logic_vector(AREA_H downto AREA_L);
    variable hasel2         : std_logic_vector(8 downto 2);
    variable hasel3         : std_logic_vector(4 downto 2);
    -- AHB Master Interface
    variable ahbreq         : std_ulogic;
    --
    variable odmi   : dev_reg_in_type;
    variable odmi2  : dev_reg_in_type;
    variable otri   : dev_reg_in_type;
    variable ol5iti : dev_reg_in_type;
    variable ol5iui : dev_reg_in_type;
  begin
    ---------------------------------------------------------------------------------
    -- Defaults
    ---------------------------------------------------------------------------------
    v := r;

    odmi := dev_reg_in_none;
    odmi2 := dev_reg_in_none;
    otri := dev_reg_in_none;
    ol5iti := dev_reg_in_none;
    ol5iui := dev_reg_in_none;
    ahbreq := '0';
    ---------------------------------------------------------------------------------
    -- AHB Master Interface
    ---------------------------------------------------------------------------------
    if dmo2.sbstart = '1' and r.dodma = '0' then
      v.dodma    := '1';
      v.sbwr     := dmo2.sbwr;
      v.sbaccess := dmo2.sbaccess;
    end if;

    if r.dodma = '1' then
      if amo.active = '1' then
        if amo.ready = '1' then
          if amo.mexc = '1' then
            odmi2.sberror := '1';
          elsif r.sbwr = '0' then
            odmi2.sbdvalid := '1';
            odmi2.sbrdata  := amo.rdata(31 downto 0);
          end if;
          odmi2.sbfinish := '1';
          v.dodma := '0';
        end if;
      else
        ahbreq := '1';
      end if;
    end if;
 
   
    -- An MSI’s 32-bit data is always written in little-endian byte order, 
    -- regardless of the BE field of the domain’s domaincfg register 

    -- Signal assignation to AHB master interface
    ami.address   <= dmo2.sbaddr;
    ami.wdata     <= ahbdrivedata(dmo2.sbwdata);
    ami.start     <= ahbreq;
    ami.burst     <= '0';
    ami.write     <= r.sbwr;
    ami.busy      <= '0';
    ami.irq       <= '0';
    ami.size      <= r.sbaccess; 

    ---------------------------------------------------------------------------------
    -- AHB Slave Interface
    ---------------------------------------------------------------------------------

    v.ahb.hhold(0):= '0';
    v.ahb.hhold(1):= r.ahb.hhold(0);
    v.ahb.hready  := '1';
    v.ahb.hresp   := HRESP_OKAY;
    rdata     := (others => '0');

    -- Interface defined as 32-bit
    --hwdata(63 downto 32) := ahbsi.hwdata( 63 mod AHBDW downto 32 mod AHBDW);
    --hwdata(31 downto  0) := ahbsi.hwdata( 31           downto  0);
    hwdata := ahbreadword(ahbsi.hwdata, r.ahb.haddr(4 downto 2));

    hasel1 := r.ahb.haddr(AREA_H downto AREA_L);
    hasel2 := r.ahb.haddr(8 downto 2);
    hasel3 := r.ahb.haddr(4 downto 2);

    v.ahb.hsel(1) := r.ahb.hsel(0);
    if ahbsi.hready='1' then
      v.ahb.hsel(0) := ahbsi.hsel(hindex) and ahbsi.htrans(1);
    end if;
    -- Slave selected
    if (ahbsi.hready and ahbsi.hsel(hindex) and ahbsi.htrans(1)) = '1' then
      v.ahb.haddr    := ahbsi.haddr;
      v.ahb.hsize    := ahbsi.hsize;
      v.ahb.hwrite   := ahbsi.hwrite;
      -- pipe
      if pipe then
        v.ahb.hready   := '0';
      end if;
    end if;

    -- Write data
    if pipe then
      if r.ahb.hsel(1) = '0' then
        v.ahb.hwdata := hwdata;
      end if;
      wdata := r.ahb.hwdata;
    else
      wdata := hwdata;
      v.ahb.hwdata := (others => '0');
    end if;

    -- (Read access) or (Write access)
    odmi.wr     := r.ahb.hwrite;
    odmi.addr   := r.ahb.haddr;
    odmi.data   := wdata;
    odmi2.wr    := r.ahb.hwrite;
    odmi2.addr  := r.ahb.haddr;
    odmi2.data  := wdata;
    otri.wr     := r.ahb.hwrite;
    otri.addr   := r.ahb.haddr;
    otri.data   := wdata;
    ol5iti.wr   := r.ahb.hwrite;
    ol5iti.addr := r.ahb.haddr;
    ol5iti.data := wdata;
    ol5iui.wr   := r.ahb.hwrite;
    ol5iui.addr := r.ahb.haddr;
    ol5iui.data := wdata;
    if r.ahb.hsel(1)='0' and r.ahb.hsel(0)='1' and r.ahb.hwrite='1' then
      v.ahb.hready := '0';
    end if;
    if (r.ahb.hsel(0) = '1' and r.ahb.hwrite = '0') or (r.ahb.hsel(1) = '1' and r.ahb.hwrite = '1') then
      case hasel1 is

        when "000" =>  -- Debug module and AHB trace registers
          --if (r.ahb.haddr(16) = '0' and l5mode='0') or (r.ahb.haddr(8)='0' and l5mode='1') then
          if (r.ahb.haddr(16) = '0' and l5mode='0') then
            odmi2.sel(0) := '1';
            rdata       := dmo2.data;
            if dmo2.rdy='0' then
              v.ahb.hready := '0';
            else
              v.ahb.hsel := "00";
            end if;
          elsif (r.ahb.haddr(8)='0' and l5mode='1') then
            odmi.sel(0) := '1';
            rdata       := dmo.data;
            if dmo.rdy='0' then
              v.ahb.hready := '0';
            else
              v.ahb.hsel := "00";
            end if;
          elsif l5mode='1' and r.ahb.haddr(7)='1' then
            -- (LEON5) Instruction trace buffer control registers
            ol5iti.sel(0) := '1';
            rdata       := l5ito.data;
            if l5ito.rdy='0' then
              v.ahb.hready := '0';
            else
              v.ahb.hsel := "00";
            end if;
          else
            --trace_reg_access(hasel2, r.ahb.hwrite, wdata, rdata);
            otri.sel(0) := '1';
            rdata       := tro.data;
            if tro.rdy='0' then
              v.ahb.hready := '0';
            else
              v.ahb.hsel := "00";
            end if;
          end if;

        when "001"  =>  -- (LEON5 only) IU tbuf data
          if l5mode='1' then
            ol5iti.sel(1) := '1';
            rdata       := l5ito.data;
            if l5ito.rdy='0' then
              v.ahb.hready := '0';
            else
              v.ahb.hsel := "00";
            end if;
          end if;

        when "010"  =>  -- AHB tbuf
          --trace_data_access(hasel3, r.ahb.hwrite, r.ahb.hhold(0), wdata, rdata);
          otri.sel(1) := '1';
          rdata       := tro.data;
          if tro.rdy='0' then
            v.ahb.hready := '0';
          else
            v.ahb.hsel := "00";
          end if;

        when others => -- (LEON5 only) register access into IU (regfile/cache controller/FPU)
          if l5mode='1' then
            ol5iui.sel(0) := '1';
            rdata       := l5iuo.data;
            if l5iuo.rdy='0' then
              v.ahb.hready := '0';
            else
              v.ahb.hsel := "00";
            end if;
          end if;

      end case;
      if r.ahb.hwrite = '0' then
        v.ahb.hrdata := rdata;
      end if;
    end if;

    -- Error response (only support 32-bit accesses)
    if pipe then
      if r.ahb.hsel(0) = '1' then
        if r.ahb.hsize /= "010" then
          v.ahb.hready := '0';
          v.ahb.hresp  := HRESP_ERROR;
        end if;
      end if;
    else
      if v.ahb.hsel(0) = '1' then
        if v.ahb.hsize /= "010" then
          v.ahb.hready := '0';
          v.ahb.hresp  := HRESP_ERROR;
        end if;
      end if;
    end if;
    -- Second error response cycle
    if r.ahb.hready = '0' and r.ahb.hresp = HRESP_ERROR then
      v.ahb.hresp := HRESP_ERROR;
    end if;

    -- hready
    if pipe then
      hready := r.ahb.hready;
    else
      hready := (r.ahb.hready and not v.ahb.hhold(0));
    end if;

    -- Read data
    if pipe then
      hrdata := r.ahb.hrdata;
    else
      hrdata := rdata;
      if r.ahb.hhold(1) = '1' then
        hrdata := r.ahb.hrdata;
      end if;
    end if;

    ---------------------------------------------------------------------------------
    -- Signals
    ---------------------------------------------------------------------------------
    rin           <= v;
    dmi           <= odmi;    
    dmi2          <= odmi2;    
    tri           <= otri;    
    l5iti         <= ol5iti;
    l5iui         <= ol5iui;

    -- AHB Interface
    ahbso.hready  <= hready;
    ahbso.hrdata  <= ahbdrivedata(hrdata);
    ahbso.hresp   <= r.ahb.hresp;
    ahbso.hsplit  <= (others => '0');
    ahbso.hirq    <= (others => '0');
    if l5mode='0' then
      ahbso.hconfig <= hconfig;
    else
      ahbso.hconfig <= hconfig_l5;
    end if;
    ahbso.hindex  <= hindex;
  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if rstn = '0' then
        r <= RES_T;
      end if;
    end if;
  end process;
end;
