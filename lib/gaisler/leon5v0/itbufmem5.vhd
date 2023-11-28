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
-- Entity: 	itbufmem
-- File:	itbufmem.vhd
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.leon5.all;
use gaisler.leon5int.all;
use gaisler.cpucore5int.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.stdlib.all;

entity itbufmem5 is
  generic (
    tech   : integer;
    entry  : integer;
    testen : integer
    );
  port (
    clk : in std_ulogic;
    di  : in itracebuf_in_type5;
    do  : out itracebuf_out_type5;
    testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
    );
end;

architecture rtl of itbufmem5 is

constant ADDRBITS : integer := log2(entry)-1;

signal data0 : std_logic_vector(191 downto 0);
signal data1 : std_logic_vector(191 downto 0);

begin

  meml0 : for i in 0 to 2 generate  -- Lane 0 memories
    ram0 : syncram generic map (tech => tech, abits => addrbits, dbits => 64, testen => testen, custombits => memtest_vlen)
      port map ( clk, di.addr0(addrbits-1 downto 0), di.data0(((i*64)+63) downto (i*64)),
                 data0(((i*64)+63) downto (i*64)), di.enable(0) , di.write(0), testin
                 );
  end generate;

  meml1 : for i in 0 to 2 generate  -- Lane 1 memories
    ram0 : syncram generic map (tech => tech, abits => addrbits, dbits => 64, testen => testen, custombits => memtest_vlen)
      port map ( clk, di.addr1(addrbits-1 downto 0), di.data1(((i*64)+63) downto (i*64)),
                 data1((i*64)+63 downto i*64), di.enable(1) , di.write(1), testin
                 );
  end generate;

  do.data <= data1&data0;
  
end;
  

