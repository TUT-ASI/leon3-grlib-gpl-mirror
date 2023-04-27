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
-- Entity:      imsic
-- File:        imsic.vhd
-- Author:      Francisco Bas, Cobham Gaisler AB
-- Description: imsic types and components
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;

library gaisler;
use gaisler.noelv.imsic_in_vector;   
use gaisler.noelv.imsic_out_vector;   
use gaisler.noelv.nv_irq_in_vector;   
use gaisler.noelv.XLEN;

package imsic is

  -- According to the AIA specs
  constant MAX_HARTS : integer  := 16384;
  constant MAX_VHARTS : integer := XLEN-1; 

  -- The number of sources in a interrupt file must be a multiple of 64 -1: from 63 to 2047 
  type nidentities_vector is array (natural range <>) of integer range 0 to 2047; 

  -- Component declarations -----------------------------------------------
  component interrupt_file 
    generic (
      sources     : integer range 0 to 2047   := 2047; -- It must be a multiple of 64 -1: from 63 to 2047 
      plic        : integer range 0 to 1      := 1     -- Set to 1 if there is a PLIC/APLIC in the system
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      -- AHB interface
      ahbw        : in  std_ulogic;
      seteipnum   : in  std_logic_vector(31 downto 0);
      -- Interface with CSRs
      ireg_w      : in  std_ulogic;
      iselect     : in  std_logic_vector(XLEN-1 downto 0);
      iregi       : in  std_logic_vector(XLEN-1 downto 0);
      irego       : out std_logic_vector(XLEN-1 downto 0);
      topei_w     : in  std_ulogic;
      topei       : out std_logic_vector(XLEN-1 downto 0);
      plic_eip    : in  std_ulogic;
      eipo        : out std_ulogic
      );
  end component;

  component grimsic_ahb 
    generic (
      hindex      : integer range 0 to NAHBSLV-1  := 0;
      haddr       : integer range 0 to 16#FFF#    := 0;
      ncpu        : integer range 0 to MAX_HARTS  := 4;
      GEILEN      : integer range 0 to MAX_VHARTS := 4;
      groups      : integer                       := 0;
      S_EN        : integer range 0 to 1          := 1;
      H_EN        : integer range 0 to 1          := 0;
      plic        : integer range 0 to 1          := 1; 
      mnidentities_vector : nidentities_vector ; 
      snidentities_vector : nidentities_vector ; 
      gnidentities_vector : nidentities_vector 
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      ahbi        : in  ahb_slv_in_type;
      ahbo        : out ahb_slv_out_type;
      plic_meip   : in  std_logic_vector(ncpu-1 downto 0);
      plic_seip   : in  std_logic_vector(ncpu-1 downto 0);
      imsici      : in  imsic_in_vector(ncpu-1 downto 0);
      imsico      : out imsic_out_vector(ncpu-1 downto 0);
      eip         : out nv_irq_in_vector(0 to ncpu-1)
      );
  end component;

end;