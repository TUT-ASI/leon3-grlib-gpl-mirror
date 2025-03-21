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
-- Package:     dftlib
-- File:        dftlib.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: Package for ASIC design-for-test functionality
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package dftlib is

  ----------------------------------------------------------------------------
  -- Generic block to mux in test reset
  ----------------------------------------------------------------------------
  component trstmux is
    generic (
      scantest : integer
      );
    port (
      arsti    : in  std_ulogic;
      testrst  : in  std_ulogic;
      testen   : in  std_ulogic;
      arsto    : out std_ulogic
      );
  end component;

  -----------------------------------------------------------------------------
  -- Synchronous I/O test module
  -----------------------------------------------------------------------------
  component synciotest is
    generic (
      ninputs : integer;
      noutputs : integer;
      nbidir : integer;
      dirmode : integer := 0
      );
    port (
      clk: in std_ulogic;
      rstn: in std_ulogic;
      datain: in std_logic_vector(ninputs+nbidir-1 downto 0);
      dataout: out std_logic_vector(noutputs+nbidir-1 downto 0);
      tmode: in std_logic_vector(5 downto 0);
      tmodeact: out std_ulogic;
      tmodeoe: out std_ulogic
      );
  end component;

end;

