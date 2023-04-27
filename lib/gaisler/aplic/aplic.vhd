
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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
-- Entity:      aplic
-- File:        aplic.vhd
-- Author:      Francisco Bas, Cobham Gaisler AB
-- Description: APLIC types and components
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;

package aplic is
  constant MAX_DOMAINS : integer := 32;    
  constant MAX_HARTS   : integer := 512;   -- According to the APLIC specs 16383. However, a maximum of 512 harts 
                                           -- is considered enough and assigning 32 KiB per domain eases the design
  constant MAX_SOURCES : integer := 1023;  -- According to the APLIC specs

  -- Source Mode (SM) constatns
  constant inactive : std_logic_vector(2 downto 0) := "000"; -- 0
  constant detached : std_logic_vector(2 downto 0) := "001"; -- 1
  constant edge1    : std_logic_vector(2 downto 0) := "100"; -- 4
  constant edge0    : std_logic_vector(2 downto 0) := "101"; -- 5
  constant level1   : std_logic_vector(2 downto 0) := "110"; -- 6
  constant level0   : std_logic_vector(2 downto 0) := "111"; -- 7


  ----------------------------------------------------------------------------
  -- Type definition
  ----------------------------------------------------------------------------
  -- These type has the biggest possible indexis. However, not all of them are use
  type preset_active_harts_type is array (0 to MAX_DOMAINS-1) of std_logic_vector(0 to MAX_HARTS-1);

  type domaincfg_type is record
    IE  : std_ulogic;
    DM  : std_ulogic;
    BE  : std_ulogic;
  end record;
  type domaincfg_vector is array (natural range <>) of domaincfg_type;

  type mmsiaddrcfg_type is record
    base_ppn  : std_logic_vector(43 downto 0);
    L         : std_ulogic;
    HHXS      : std_logic_vector(4 downto 0);
    LHXS      : std_logic_vector(2 downto 0);
    HHXW      : std_logic_vector(2 downto 0);
    LHXW      : std_logic_vector(3 downto 0);
  end record;

  type smsiaddrcfg_type is record
    base_ppn  : std_logic_vector(43 downto 0);
    LHXS      : std_logic_vector(2 downto 0);
  end record;


  ----------------------------------------------------------------------------
  -- Component declaration
  ----------------------------------------------------------------------------
  component graplic_ahb 
    generic (
      hmindex             : integer range 0 to NAHBMST-1   := 0;
      hsindex             : integer range 0 to NAHBSLV-1   := 0;
      haddr               : integer range 0 to 16#FFF#     := 0;
      nsources            : integer range 1 to MAX_SOURCES := 1023;
      ncpu                : integer range 0 to MAX_HARTS   := 8;
      ndomains            : integer range 0 to MAX_DOMAINS := 3;
      endianness          : integer range 0 to 2           := 1; 
      S_EN                : integer range 0 to 1           := 1; 
      H_EN                : integer range 0 to 1           := 1; 
      GEILEN              : integer                        := 6; 
      grouped_harts       : integer range 0 to 1           := 0; 
      mmsiaddrcfg_fixed   : integer range 0 to 1           := 1;
      mbase_PPN           : std_logic_vector(31 downto 0)  := x"00000000"; 
      sbase_PPN           : std_logic_vector(31 downto 0)  := x"00000000"; 
      mLHXS               : integer                        := 0; 
      sLHXS               : integer                        := 0; 
      HHXS                : integer                        := 0; 
      LHXW                : integer                        := 0; 
      HHXW                : integer                        := 0; 
      direct_delivery     : integer range 0 to 1           := 0; 
      IPRIOLEN            : integer range 1 to 8           := 8; 
      nEIID               : integer range 1 to 2047        := 2047;
      sdom                : integer                        := 3;
      preset_active_harts : preset_active_harts_type
      );
    port (
      rstn        : in  std_ulogic;
      clk         : in  std_ulogic;
      ahbmi       : in  ahb_mst_in_type;
      ahbmo       : out ahb_mst_out_type;
      ahbsi       : in  ahb_slv_in_type;
      ahbso       : out ahb_slv_out_type;
      meip        : out std_logic_vector(ncpu-1 downto 0);
      seip        : out std_logic_vector(ncpu-1 downto 0)
      );
  end component;
end aplic;

