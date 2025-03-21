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
-- Entity:      nexus_iddr_reg
-- File:        ddr_nexus.vhd
-- Author:      Gaisler Research
-- Description: Lattice Nexus-family DDR input register
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

-- pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on


entity nexus_iddrx1_reg is
  port(
    Q0 : out std_ulogic;
    Q1 : out std_ulogic;
    C : in std_ulogic;
    CE : in std_ulogic;
    D : in std_ulogic;
    R : in std_ulogic
    );
end entity;

architecture rtl of nexus_iddrx1_reg is

  signal clk   : std_ulogic;
  signal preQ1 : std_ulogic;

  component IDDRX1
    generic (
      GSR : String := "DISABLED");
    port(
      D : in std_logic;
      SCLK : in std_logic;
      RST : in std_logic;
      Q0 : out std_logic;
      Q1 : out std_logic);
  end component;

begin

  clk <= C when (CE = '1') else '0';

  nexus_iddrx1: IDDRX1
    port map(
      D => D,
      SCLK => clk,
      RST => R,
      Q0 => Q0,
      Q1 => preQ1);

  -- to align the Q1 data to the next clock positive edge
  alignreg : process (C, preQ1, R)
  begin
    if R='1' then --asynchronous reset, active high
      Q1 <= '0';
    elsif C'event and C='1' then --Clock event - posedge
      Q1 <= preQ1;
    end if;
  end process;
end architecture;
