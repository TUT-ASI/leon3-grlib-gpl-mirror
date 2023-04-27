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
-- Entity: 	delay_wire2, delay_wire2_bus
-- File:	delay_wire2.vhd
-- Author:	Magnus Hjorth, Frontgrade Gaisler
-- Description: Bidir delay wire model with collision detection and
--              error injction support
------------------------------------------------------------------------------

-- Collisions are handled with a two phase approach: First both sides are
-- driven with X to ensure the collision is seen, secondly the connection is broken
-- for enough time to allow the a and b signals to settle back to the undriven
-- values.

library ieee;
use ieee.std_logic_1164.all;

entity delay_wire2 is
  generic(
    dab  : time;
    dba  : time;
    pull : integer range 0 to 2
  );
  port(
    a  : inout std_logic;
    b  : inout std_logic;
    eiab : in std_ulogic;
    eiba : in std_ulogic;
    col: out std_ulogic
  );
end delay_wire2;

architecture rtl of delay_wire2 is

  signal a_tfr, a_tfr_dly: std_ulogic := 'Z';
  signal b_tfr, b_tfr_dly: std_ulogic := 'Z';

  signal a_dir, b_dir: boolean := false;

  signal colstate: integer range 0 to 2 := 0;

  constant idlevalv: std_logic_vector(0 to 2) := "ZHL";
  constant idleval: std_ulogic := idlevalv(pull);

begin

  a_tfr <= a       when colstate=0 and eiab='0' and (a_dir) else
           (not a) when colstate=0              and (a_dir) else
           'X'     when colstate=1 else
           idleval;
  b_tfr <= b       when colstate=0 and eiba='0' and (b_dir) else
           (not b) when colstate=0              and (b_dir) else
           'X'     when colstate=1 else
           idleval;

  a_tfr_dly <= transport a_tfr after dab;
  b_tfr_dly <= transport b_tfr after dba;

  a <= b_tfr_dly;
  b <= a_tfr_dly;

  a_dir <= false when a=idleval else
           true when pull=0 and (a='1' or a='0' or a='H' or a='L') and (b_tfr_dly = 'Z') else
           true when (a='1' or a='0') and (b_tfr_dly='H' or b_tfr_dly='L' or b_tfr_dly='W' or b_tfr_dly='Z');
  b_dir <= false when b=idleval else
           true when pull=0 and (b='1' or b='0' or b='H' or b='L') and (a_tfr_dly = 'Z') else
           true when (b='1' or b='0') and (a_tfr_dly='H' or a_tfr_dly='L' or a_tfr_dly='W' or a_tfr_dly='Z');

  col <= '1' when colstate/=0 else '0';

  colproc: process
  begin
    colstate <= 0;
    wait until
      (b='X' and (a_tfr_dly='1' or a_tfr_dly='0')) or
      (b='W' and (a_tfr_dly='H' or a_tfr_dly='L')) or
      (a='X' and (b_tfr_dly='1' or b_tfr_dly='0')) or
      (a='W' and (b_tfr_dly='H' or b_tfr_dly='L')) or
      (a_dir and b_dir);
    -- Collision detected, first force drive X on both sides
    colstate <= 1;
    wait for dab+dba;
    -- Then break the connection and drive Z to allow the collision condition to go away
    colstate <= 2;
    wait for dab+dba;
    if a='X' or b='X' or a='W' or b='W' then
      wait until not (a='X' or b='X' or a='W' or b='W');
    end if;
    -- Then loop back to normal usage
  end process;

end;

library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.sim.all;

entity delay_wire2_bus is
  generic(
    width: integer;
    dab  : time;
    dba  : time;
    pull : integer range 0 to 2
  );
  port(
    a  : inout std_logic_vector(width-1 downto 0);
    b  : inout std_logic_vector(width-1 downto 0);
    eiab : in std_logic_vector(width-1 downto 0);
    eiba : in std_logic_vector(width-1 downto 0);
    col: out std_logic_vector(width-1 downto 0)
  );
end delay_wire2_bus;

architecture rtl of delay_wire2_bus is
begin

  dwl: for x in 0 to width-1 generate
    w: delay_wire2
      generic map (
        dab => dab,
        dba => dba,
        pull => pull
        )
      port map (
        a => a(x),
        b => b(x),
        eiab => eiab(x),
        eiba => eiba(x),
        col => col(x)
        );
  end generate;

end;
