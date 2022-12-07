------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity:      rvdm
-- File:        rvdm.vhd
-- Author:      Andrea Merlo, Nils Wessman, Cobham Gaisler AB
-- Description: NOEL-V debug module
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.amba.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.noelvint.all;

entity rvdm is
  generic (
    hindex      : integer range 0  to 15        := 0;   -- bus index
    haddr       : integer                       := 16#900#;
    hmask       : integer                       := 16#f00#;
    nharts      : integer                       := 1;   -- number of harts
    tbits       : integer                       := 30;  -- timer bits (instruction trace time tag)
    tech        : integer                       := DEFMEMTECH;
    kbytes      : integer                       := 0;   -- Size of trace buffer memory in KiB
    --bwidth      : integer                       := 64;  -- Traced AHB bus width
    --ahbpf       : integer                       := 0;
    --ahbwp       : integer                       := 2;
    scantest    : integer                       := 0
    );
  port (
    rst    : in  std_ulogic;
    clk    : in  std_ulogic;
    ahbmi  : in  ahb_mst_in_type;
    ahbsi  : in  ahb_slv_in_type;
    ahbso  : out ahb_slv_out_type;
    dbgi   : in  nv_debug_out_vector(0 to NHARTS-1);
    dbgo   : out nv_debug_in_vector(0 to NHARTS-1);
    dsui   : in  nv_dm_in_type;
    dsuo   : out nv_dm_out_type
    );

end;

architecture rtl of rvdm is

  signal gnd    : std_ulogic;
  signal vcc    : std_ulogic;

begin

  -- Signals ----------------------------------------------------------------

  gnd <= '0';
  vcc <= '1';

  -- Debug Module -----------------------------------------------------------

  x0 : rvdmx
    generic map (
      hindex    => hindex,
      haddr     => haddr,
      hmask     => hmask,
      nharts    => nharts,
      tbits     => tbits,
      tech      => tech,
      kbytes    => kbytes,
      --bwidth    => bwidth,
      --ahbpf     => ahbpf,
      --ahbwp     => ahbwp,
      scantest  => scantest)
    port map (
      rst       => rst,
      hclk      => gnd,
      cpuclk    => clk,
      fcpuclk   => clk,
      ahbmi     => ahbmi,
      ahbsi     => ahbsi,
      ahbso     => ahbso,
      tahbsi    => ahbsi,
      dbgi      => dbgi,
      dbgo      => dbgo,
      dsui      => dsui,
      dsuo      => dsuo,
      hclken    => vcc
      );

end;
