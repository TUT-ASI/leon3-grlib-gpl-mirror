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
-- Entity:  nandpkg
-- File: nandpkg.vhd
-- Author:  Jonas Ekergarn - Aeroflex Gaisler
-- Description: NAND flash memory controller package
------------------------------------------------------------------------------

library ieee, grlib, techmap;
use ieee.std_logic_1164.all;
use grlib.amba.all;
use techmap.gencomp.all;

package nandpkg is

  type nandfctrl_out_type is record
    ce  : std_logic_vector(31 downto 0);
    we  : std_logic_vector(7 downto 0);
    do  : std_logic_vector(63 downto 0);
    doh : std_logic_vector(63 downto 0);
    cle : std_ulogic;
    ale : std_ulogic;
    re  : std_ulogic;
    wp  : std_ulogic;
    oe  : std_ulogic;
    err : std_ulogic;
  end record;
  
  type nandfctrl_in_type is record
    rb  : std_ulogic;
    di  : std_logic_vector(63 downto 0);
    dih : std_logic_vector(63 downto 0);
  end record;
  
  component nandfctrl
    generic (
      hsindex  : integer := 0;
      haddr0   : integer := 16#000#;
      haddr1   : integer := 16#001#;
      hmask0   : integer := 16#FFF#;
      hmask1   : integer := 16#FFF#;
      pindex   : integer := 0;
      pirq     : integer := 0;
      paddr    : integer := 0;
      pmask    : integer := 16#FFF#;
      memtech  : integer := DEFMEMTECH;
      sysfreq  : integer := 50000;
      ntargets : integer range 1 to 32 := 2;
      nlanes   : integer range 1 to 8  := 8;
      pbufsize : integer := 4096;
      sbufsize : integer := 256;
      dwidth16 : integer range 0 to 1 := 0;
      tm1      : integer range 0 to 1 := 0;
      tm2      : integer range 0 to 1 := 0;
      tm3      : integer range 0 to 1 := 0;
      tm4      : integer range 0 to 1 := 0;
      tm5      : integer range 0 to 1 := 0;
      tm5_edoen : integer range 0 to 1 := 0;
      nsync    : integer := 2;
      ft       : integer range 0 to 5 := 0;
      oepol    : integer range 0 to 1 := 0;
      scantest : integer range 0 to 1 := 0;
      edac     : integer := 0;
      cmdorder : integer range 0 to 1 := 0;
      sepbufs  : integer range 0 to 1 := 1;
      progtime : integer range 0 to 1 := 0;
      buf1en   : integer range 0 to 1 := 1);
    port (
      rst    : in  std_ulogic;
      clk    : in  std_ulogic;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      ahbsi  : in  ahb_slv_in_type;
      ahbso  : out ahb_slv_out_type;
      nandfi : in  nandfctrl_in_type;
      nandfo : out nandfctrl_out_type
      );
  end component;

  function target_compability ( targets : in integer ) return integer;
  function ext_target_rhigh ( targets : in integer ) return integer;
  function ext_target_rlow ( targets : in integer ) return integer;
end;

package body nandpkg is


  function target_compability ( targets : in integer )
    return integer is
    variable ret : integer;
  begin

    if targets < 5 then
      ret := targets;
    else
      ret := 4;
    end if;

    return ret;
    
  end;

  function ext_target_rhigh ( targets : in integer )
    return integer is
    variable ret : integer;
  begin

    ret := 0;

    if targets > 4 then
      ret := targets-1;
    end if;

    return ret;
            
  end;

  function ext_target_rlow ( targets : in integer )
    return integer is
    variable ret : integer;
  begin

    ret := 0;

    if targets > 4 then
      ret := 4;
    end if;

    return ret;
    
  end;
  
end package body;


