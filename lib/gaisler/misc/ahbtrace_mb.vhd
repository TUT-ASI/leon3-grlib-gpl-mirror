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
-- Entity: 	ahbtrace_mb
-- File:	ahbtrace_mb.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Modified:    Jan Andersson - Aeroflex Gaisler
-- Description:	AHB trace unit that can have registers on a separate bus
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.misc.all;

entity ahbtrace_mb is
  generic (
    hindex   : integer := 0;
    ioaddr   : integer := 16#000#;
    iomask   : integer := 16#E00#;
    tech     : integer := DEFMEMTECH; 
    irq      : integer := 0; 
    kbytes   : integer := 1;
    bwidth   : integer := 32;
    ahbfilt  : integer := 0;
    scantest : integer range 0 to 1 := 0;
    exttimer : integer range 0 to 1 := 0;
    exten    : integer range 0 to 1 := 0);
  port (
    rst      : in  std_ulogic;
    clk      : in  std_ulogic;
    ahbsi    : in  ahb_slv_in_type;       -- Register interface
    ahbso    : out ahb_slv_out_type;
    tahbmi   : in  ahb_mst_in_type;       -- Trace
    tahbsi   : in  ahb_slv_in_type;
    trace_en : in  std_logic := '1';
    timer    : in  std_logic_vector(30 downto 0) := (others => '0');
    astat    : out amba_stat_type;
    resen    : in  std_ulogic := '0'
  );
end; 

architecture rtl of ahbtrace_mb is


signal tahbmiv : ahb_mst_in_vector_type(0 to 0); 
signal tahbsiv : ahb_slv_in_vector_type(0 to 0);

begin

  tahbmiv(0) <= tahbmi;
  tahbsiv(0) <= tahbsi;
  
  ahbt0 : ahbtrace_mmb
    generic map (
      hindex   => hindex,
      ioaddr   => ioaddr,
      iomask   => iomask,
      tech     => tech,
      irq      => irq,
      kbytes   => kbytes,
      bwidth   => bwidth,
      ahbfilt  => ahbfilt,
      ntrace   => 1,
      scantest => scantest,
      exttimer => exttimer,
      exten    => exten)
    port map(
      rst      => rst,
      clk      => clk,
      ahbsi    => ahbsi,
      ahbso    => ahbso,
      tahbmiv  => tahbmiv,
      tahbsiv  => tahbsiv,
      trace_en => trace_en,
      timer    => timer,
      astat    => astat,
      resen    => resen);
  
end;

