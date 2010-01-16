------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2010, Aeroflex Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
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
-- Entity: 	ddr_proasic3
-- File:	ddr_proasic3.vhd
-- Author:	Jonas Ekergarn - Aeroflex Gaisler
-- Description:	DDR input and output registers
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
-- pragma translate_off
library proasic3;
use proasic3.ddr_out;
-- pragma translate_on

entity apa3_oddr_reg is
  port(
    Q : out std_ulogic;
    C1 : in std_ulogic;
    C2 : in std_ulogic;
    CE : in std_ulogic;
    D1 : in std_ulogic;
    D2 : in std_ulogic;
    R : in std_ulogic;
    S : in std_ulogic);
end entity;

architecture rtl of apa3_oddr_reg is
  component ddr_out
    port(clr, clk, dr, df : in std_ulogic;
         q : out std_ulogic);
  end component;
begin
  ddr_out0 : ddr_out
    port map(clr => R, clk => C1, dr => D1, df => D2, q => Q);
end architecture;

library ieee;
use ieee.std_logic_1164.all;
-- pragma translate_off
library proasic3;
use proasic3.ddr_reg;
-- pragma translate_on

entity apa3_iddr_reg is
  port(
    Q1 : out std_ulogic;
    Q2 : out std_ulogic;
    C1 : in std_ulogic;
    C2 : in std_ulogic;
    CE : in std_ulogic;
    D  : in std_ulogic;
    R  : in std_ulogic;
    S  : in std_ulogic);
end entity;

architecture rtl of apa3_iddr_reg is
  component ddr_reg
    port(clr, clk, d: in std_ulogic;
         qf, qr: out std_ulogic);
  end component;
begin
  ddr_in0 : ddr_reg
    port map(clr => R, clk => C1, d => D, qf => Q2, qr => Q1);
end architecture;
