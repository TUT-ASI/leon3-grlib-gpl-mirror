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
-- Pacakge: spi
-- File: spi.vhd
-- Author:  Jiri Gaisler - Gaisler Research
-- Description:  SPI interface package
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;

package spi is

  type spi_in_type is record
    miso    : std_ulogic;
    mosi    : std_ulogic;
    sck     : std_ulogic;
    spisel  : std_ulogic;
    astart  : std_ulogic;
    cstart  : std_ulogic;
    ignore  : std_ulogic;
    io2     : std_ulogic;
    io3     : std_ulogic;
  end record;

  type spi_in_vector is array (natural range <>) of spi_in_type;

  constant spi_in_none : spi_in_type := ('0', '0', '0', '0', '0', '0', '0',
                                         '0', '0');

  -- Configuration register indicies constants
  subtype READCMD_RANGE     is Natural range 7 downto 0;
  subtype DUMMYCYCLES_RANGE is Natural range 11 downto 8;
  constant DSPI_INDEX      : integer := 12;
  constant QSPI_INDEX      : integer := 13;
  constant EXTADDR_INDEX   : integer := 14;
  constant DUMMYBYTE_INDEX : integer := 15;
  constant DUALOUT_INDEX   : integer := 16;
  constant QUADOUT_INDEX   : integer := 17;
  constant DUALIN_INDEX    : integer := 18;
  constant QUADIN_INDEX    : integer := 19;
  constant XIP_INDEX       : integer := 20;
  subtype WRITECMD_RANGE    is Natural range 31 downto 24;
  

  type spi_out_type is record
    miso     : std_ulogic;
    misooen  : std_ulogic;
    mosi     : std_ulogic;
    mosioen  : std_ulogic;
    sck      : std_ulogic;
    sckoen   : std_ulogic;
    enable   : std_ulogic;
    astart   : std_ulogic;
    aready   : std_ulogic;
    io2      : std_ulogic;
    io2oen   : std_ulogic;
    io3      : std_ulogic;
    io3oen   : std_ulogic;
  end record;

  type spi_out_vector is array (natural range <>) of spi_out_type;

  constant spi_out_none : spi_out_type := ('0', '0', '0', '0', '0', '0',
                                           '0', '0', '0', '0', '0', '0',
                                           '0');

  -- SPI master/slave controller
  component spictrl
    generic (
      pindex    : integer := 0;
      paddr     : integer := 0;
      pmask     : integer := 16#fff#;
      pirq      : integer := 0;
      fdepth    : integer range 1 to 7       := 1;
      slvselen  : integer range 0 to 1       := 0;
      slvselsz  : integer range 1 to 32      := 1;
      oepol     : integer range 0 to 1       := 0;
      odmode    : integer range 0 to 1       := 0;
      automode  : integer range 0 to 1       := 0;
      acntbits  : integer range 1 to 32      := 32;
      aslvsel   : integer range 0 to 1       := 0;
      twen      : integer range 0 to 1       := 1;
      maxwlen   : integer range 0 to 15      := 0;
      netlist   : integer                    := 0;
      syncram   : integer range 0 to 1       := 1;
      memtech   : integer                    := 0;
      ft        : integer range 0 to 2       := 0;
      scantest  : integer range 0 to 1       := 0;
      syncrst   : integer range 0 to 1       := 0;
      automask0 : integer                    := 0;
      automask1 : integer                    := 0;
      automask2 : integer                    := 0;
      automask3 : integer                    := 0;
      ignore    : integer range 0 to 1       := 0;
      prot      : integer range 0 to 2       := 0
      );
    port (
      rstn   : in std_ulogic;
      clk    : in std_ulogic;
      apbi   : in apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      spii   : in  spi_in_type;
      spio   : out spi_out_type;
      slvsel : out std_logic_vector((slvselsz-1) downto 0)
    );
  end component;

  -- SPI to AHB bridge

  type spi2ahb_in_type is record
    haddr   : std_logic_vector(31 downto 0);
    hmask   : std_logic_vector(31 downto 0);
    en      : std_ulogic;
  end record;

  type spi2ahb_out_type is record
    dma     : std_ulogic;
    wr      : std_ulogic;
    prot    : std_ulogic;
  end record;

  component spi2ahb
    generic (
      -- AHB Configuration
      hindex     : integer := 0;
      --
      ahbaddrh   : integer := 0;
      ahbaddrl   : integer := 0;
      ahbmaskh   : integer := 0;
      ahbmaskl   : integer := 0;
      --
      oepol      : integer range 0 to 1 := 0;
      --
      filter     : integer range 2 to 512 := 2;
      --
      cpol       : integer range 0 to 1 := 0;
      cpha       : integer range 0 to 1 := 0);
    port (
      rstn   : in  std_ulogic;
      clk    : in  std_ulogic;
      -- AHB master interface
      ahbi   : in  ahb_mst_in_type;
      ahbo   : out ahb_mst_out_type;
      -- SPI signals
      spii   : in  spi_in_type;
      spio   : out spi_out_type
      );
  end component;

  component spi2ahb_apb
    generic (
      -- AHB Configuration
      hindex     : integer := 0;
      --
      ahbaddrh   : integer := 0;
      ahbaddrl   : integer := 0;
      ahbmaskh   : integer := 0;
      ahbmaskl   : integer := 0;
      resen      : integer := 0;
      -- APB configuration
      pindex     : integer := 0;
      paddr      : integer := 0;
      pmask      : integer := 16#fff#;
      pirq       : integer := 0;
      --
      oepol      : integer range 0 to 1 := 0;
      --
      filter     : integer range 2 to 512 := 2;
      --
      cpol       : integer range 0 to 1 := 0;
      cpha       : integer range 0 to 1 := 0);
    port (
      rstn   : in  std_ulogic;
      clk    : in  std_ulogic;
      -- AHB master interface
      ahbi   : in  ahb_mst_in_type;
      ahbo   : out ahb_mst_out_type;
      --
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      -- SPI signals
      spii   : in  spi_in_type;
      spio   : out spi_out_type
      );
  end component;

  component spi2ahbx
    generic (
      hindex   : integer := 0;
      oepol    : integer range 0 to 1 := 0;
      filter   : integer range 2 to 512 := 2;
      cpol     : integer range 0 to 1 := 0;
      cpha     : integer range 0 to 1 := 0);
    port (
      rstn     : in  std_ulogic;
      clk      : in  std_ulogic;
      -- AHB master interface
      ahbi     : in  ahb_mst_in_type;
      ahbo     : out ahb_mst_out_type;
      -- SPI signals
      spii     : in  spi_in_type;
      spio     : out spi_out_type;
      --
      spi2ahbi : in  spi2ahb_in_type;
      spi2ahbo : out spi2ahb_out_type
      );
  end component;

  type spimctrl_in_type is record
    miso        : std_ulogic;
    mosi        : std_ulogic;
    io2         : std_ulogic;
    io3         : std_ulogic;
    cd          : std_ulogic;
    rstaddrm    : std_ulogic;
  end record;
  constant spimctrl_in_none : spimctrl_in_type := (others => '0');

  
  type spimctrl_out_type is record
    mosi        : std_ulogic;
    miso        : std_ulogic;
    io2         : std_ulogic;
    io3         : std_ulogic;
    mosioen     : std_ulogic;
    misooen     : std_ulogic;
    iooen       : std_ulogic;
    sck         : std_ulogic;
    csn         : std_ulogic;
    csn1        : std_ulogic;
    csn2        : std_ulogic;
    csn3        : std_ulogic;
    cdcsnoen    : std_ulogic;
--    errorn      : std_ulogic;
    ready       : std_ulogic;
    initialized : std_ulogic;
  end record;

  constant spimctrl_out_none : spimctrl_out_type :=
    ('0', '0', '1', '1', '0', '1', '0', '0', '1', '1', '1', '1', '1', '0', '0');

  component spimctrl
    generic (
      hindex       : integer := 0;
      hirq         : integer := 0;
      faddr        : integer := 16#000#;
      fmask        : integer := 16#fff#;
      ioaddr       : integer := 16#000#;
      iomask       : integer := 16#fff#;
      spliten      : integer := 0;
      oepol        : integer := 0;
      sdcard       : integer range 0 to 1   := 0;
      readcmd      : integer range 0 to 255 := 16#0B#;
      dummybyte    : integer range 0 to 1   := 1;
      dualoutput   : integer range 0 to 1   := 0;
      scaler       : integer range 1 to 512 := 1;
      altscaler    : integer range 1 to 512 := 1;
      pwrupcnt     : integer := 0;
      maxahbaccsz  : integer range 0 to 256 := AHBDW;
      offset       : integer := 0;
      quadoutput   : integer range 0 to 1   := 0;
      dualinput    : integer range 0 to 1   := 0;
      quadinput    : integer range 0 to 1   := 0;
      dummycycles  : integer range 0 to 15  := 0;
      DSPI         : integer range 0 to 1   := 0;
      QSPI         : integer range 0 to 1   := 0;
      extaddr      : integer range 0 to 2   := 0;
      reconf       : integer range 0 to 1   := 0;
      writecmd     : integer range 0 to 255 := 16#02#;
      allow_writes : integer range 0 to 1   := 0;
      xip_byte     : integer range 0 to 1   := 0;
      xip_polarity : integer range 0 to 1   := 1;
      multiple_csn : integer range 0 to 1   := 0
      );
    port (
      rstn    : in  std_ulogic;
      clk     : in  std_ulogic;
      ahbsi   : in  ahb_slv_in_type;
      ahbso   : out ahb_slv_out_type;
      spii    : in  spimctrl_in_type := spimctrl_in_none;
      spio    : out spimctrl_out_type
    );
  end component;

  -- Constants for (and for using) dynamic_spi_flash
  -- List of read commands
  constant NOPCMD     : std_logic_vector(7 downto 0) := X"00";-- NOP
  constant READSINGLE : std_logic_vector(7 downto 0) := X"03";-- (1,1,1)
  constant READFAST   : std_logic_vector(7 downto 0) := X"0B";-- (y,y,y)
  constant READDUALO  : std_logic_vector(7 downto 0) := X"3B";-- (x,y,2)
  constant READDUALIO : std_logic_vector(7 downto 0) := X"BB";-- (x,2,2)
  constant READQUADO  : std_logic_vector(7 downto 0) := X"6B";-- (x,y,4)
  constant READQUADIO : std_logic_vector(7 downto 0) := X"EB";-- (x,4,4)
  -- (Fake) Commands (goto dual/quad/extended/statusreg etc)
  constant READSTATUSREG  : std_logic_vector(7 downto 0) := X"45";
  constant WRITESTATUSREG : std_logic_vector(7 downto 0) := X"67";
  constant RESETREGSTATUS : std_logic_vector(7 downto 0) := X"CA";
  constant GOTOESPI       : std_logic_vector(7 downto 0) := X"89";
  constant GOTODSPI       : std_logic_vector(7 downto 0) := X"AB";
  constant GOTOQSPI       : std_logic_vector(7 downto 0) := X"CD";
  constant GOTOEXTADDR    : std_logic_vector(7 downto 0) := X"EF";--4-bytes addr
  constant GOTONRMADDR    : std_logic_vector(7 downto 0) := X"23";--3-bytes addr
  -- (Fake) Read command that doesn't overwrite the number of dummy cycles
  constant READWITHOTHERDUMMYCYCLES : std_logic_vector(7 downto 0) := X"01";
  -- (Fake) Commands for setting dummy cycles
  -- the other 4 bits will indicate how many dummy cycles to use
  constant SETDUMMYCYCLES : std_logic_vector(3 downto 0) := X"1";
  -- (Fake) status register default value
  constant DEFAULTSTATUS  : std_logic_vector(7 downto 0) := X"7B";-- int=123


end;

