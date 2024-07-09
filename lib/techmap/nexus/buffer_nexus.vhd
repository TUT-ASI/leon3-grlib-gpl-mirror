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
-- Entity:      clkbuf_nexus
-- File:        buffer_nexus.vhd
-- Author:      Gaisler Research
-- Description: Lattice Nexus-family buffer
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

-- pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on


entity clkbuf_nexus is
  port(
    i   :  in  std_ulogic;
    o   :  out std_ulogic);
end entity;

architecture rtl of clkbuf_nexus is
  component BUF
    port(
      A : in std_logic;
      Z : out std_logic);
  end component;

begin
  nexus_buf: BUF
    port map(
      A => i,
      Z => o);
end architecture;
