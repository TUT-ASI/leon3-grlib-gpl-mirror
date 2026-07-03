------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
use gaisler.dmnvint.all;
use gaisler.l5nv_shared.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.stdlib.all;

entity itbufmemnv is
  generic (
    tech   : integer;
    entry  : integer;
    testen : integer
    );
  port (
    clk : in std_ulogic;
    d_i : in itracebuf_in_type5;
    d_o : out itracebuf_out_type5;
    testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
    );
end;

architecture rtl of itbufmemnv is

constant ADDRBITS : integer := log2ext(entry)-1;

signal data0 : std_logic_vector(255 downto 0);
signal data1 : std_logic_vector(255 downto 0);

begin

  meml0 : for i in 0 to 3 generate  -- Lane 0 memories
    ram0 : syncram generic map (tech => tech, abits => addrbits, dbits => 64, testen => testen, custombits => memtest_vlen)
      port map ( clk, d_i.addr0(addrbits-1 downto 0), d_i.data0(((i*64)+63) downto (i*64)),
                 data0(((i*64)+63) downto (i*64)), d_i.enable(0) , d_i.write(0), testin
                 );
  end generate;

  meml1 : for i in 0 to 3 generate  -- Lane 1 memories
    ram0 : syncram generic map (tech => tech, abits => addrbits, dbits => 64, testen => testen, custombits => memtest_vlen)
      port map ( clk, d_i.addr1(addrbits-1 downto 0), d_i.data1(((i*64)+63) downto (i*64)),
                 data1((i*64)+63 downto i*64), d_i.enable(1) , d_i.write(1), testin
                 );
  end generate;

  d_o.data <= data1&data0;

end;


