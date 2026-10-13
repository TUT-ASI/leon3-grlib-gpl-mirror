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
use gaisler.l5nv_shared.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.stdlib.all;

entity itbufmem5nv is
  generic (
    tech   : integer;
    entry  : integer;
    arch   : integer;
    testen : integer
    );
  port (
    clk   : in std_ulogic;
    d_i   : in itracebuf_in_type5;
    d_o   : out itracebuf_out_type5;
    sparc_mode : in std_ulogic;
    testin: in std_logic_vector(TESTIN_WIDTH-1 downto 0)
    );
end;

architecture rtl of itbufmem5nv is

constant ADDRBITS : integer := log2ext(entry)-1;

constant SPARC        : integer := 0;
constant RISCV        : integer := 1;
constant SPARC_RISCV  : integer := 2;

signal data0_h, data0_l : std_logic_vector(255 downto 0);
signal data1_h, data1_l : std_logic_vector(255 downto 0);
signal d_i_data0_h, d_i_data0_l : std_logic_vector(255 downto 0);
signal d_i_data1_h, d_i_data1_l : std_logic_vector(255 downto 0);
signal d_i_enable_h, d_i_enable_l : std_logic_vector(1 downto 0);
signal d_i_write_h, d_i_write_l : std_logic_vector(1 downto 0);
signal addr0hr, addr1hr: std_ulogic;

begin

  mux_input : process(d_i, sparc_mode)
  begin
    -- if arch = RISCV or (arch = SPARC_RISCV and sparc_mode = '0') then
    d_i_enable_h <= d_i.enable;
    d_i_write_h  <= d_i.write;
    d_i_enable_l <= d_i.enable;
    d_i_write_l  <= d_i.write;

    d_i_data0_h <= d_i.data0(255 downto 64) & d_i.data0(255 downto 192);
    d_i_data0_l <= d_i.data0;

    d_i_data1_h <= d_i.data1(255 downto 64) & d_i.data1(255 downto 192);
    d_i_data1_l <= d_i.data1;
    -- end if;
    if arch = SPARC or (arch = SPARC_RISCV and sparc_mode = '1') then
      d_i_enable_h(0) <= d_i.enable(0) and d_i.addr0(addrbits-1);
      d_i_enable_h(1) <= d_i.enable(1) and d_i.addr1(addrbits-1);
      d_i_write_h(0)  <= d_i.write(0)  and d_i.addr0(addrbits-1);
      d_i_write_h(1)  <= d_i.write(1)  and d_i.addr1(addrbits-1);

      d_i_enable_l(0) <= d_i.enable(0) and not d_i.addr0(addrbits-1);
      d_i_enable_l(1) <= d_i.enable(1) and not d_i.addr1(addrbits-1);
      d_i_write_l(0)  <= d_i.write(0)  and not d_i.addr0(addrbits-1);
      d_i_write_l(1)  <= d_i.write(1)  and not d_i.addr1(addrbits-1);

      d_i_data0_h <= d_i.data0;
      d_i_data0_l <= d_i.data0;

      d_i_data1_h <= d_i.data1;
      d_i_data1_l <= d_i.data1;
    end if;

  end process;

  meml0_h : for i in 0 to 2 generate  -- Lane 0 memories
    ram0 : syncram generic map (tech => tech, abits => addrbits-1, dbits => 64, testen => testen, custombits => memtest_vlen)
      port map ( clk, d_i.addr0(addrbits-1-1 downto 0), d_i_data0_h(((i*64)+63) downto (i*64)),
                 data0_h(((i*64)+63) downto (i*64)), d_i_enable_h(0) , d_i_write_h(0), testin
                 );
  end generate;

  meml1_h : for i in 0 to 2 generate  -- Lane 1 memories
    ram0 : syncram generic map (tech => tech, abits => addrbits-1, dbits => 64, testen => testen, custombits => memtest_vlen)
      port map ( clk, d_i.addr1(addrbits-1-1 downto 0), d_i_data1_h(((i*64)+63) downto (i*64)),
                 data1_h((i*64)+63 downto i*64), d_i_enable_h(1) , d_i_write_h(1), testin
                 );
  end generate;

  meml0_l : for i in 0 to 2 generate  -- Lane 0 memories
    ram0 : syncram generic map (tech => tech, abits => addrbits-1, dbits => 64, testen => testen, custombits => memtest_vlen)
      port map ( clk, d_i.addr0(addrbits-1-1 downto 0), d_i_data0_l(((i*64)+63) downto (i*64)),
                 data0_l(((i*64)+63) downto (i*64)), d_i_enable_l(0) , d_i_write_l(0), testin
                 );
  end generate;

  meml1_l : for i in 0 to 2 generate  -- Lane 1 memories
    ram0 : syncram generic map (tech => tech, abits => addrbits-1, dbits => 64, testen => testen, custombits => memtest_vlen)
      port map ( clk, d_i.addr1(addrbits-1-1 downto 0), d_i_data1_l(((i*64)+63) downto (i*64)),
                 data1_l((i*64)+63 downto i*64), d_i_enable_l(1) , d_i_write_l(1), testin
                 );
  end generate;

  mux_output : process(d_i.addr1, d_i.addr0, data1_h, data1_l, data0_h, data0_l, sparc_mode, addr1hr, addr0hr)
  begin
    -- if arch = RISCV or (arch = SPARC_RISCV and sparc_mode = '0') then
    d_o.data <= (data1_h(63 downto 0) & data1_l(191 downto 0)) & (data0_h(63 downto 0) & data0_l(191 downto 0));
    -- end if;
    if arch = SPARC or (arch = SPARC_RISCV and sparc_mode = '1') then
--      if d_i.addr1(addrbits-1) = '1' then
      if addr1hr = '1' then
        d_o.data(383 downto 192) <= data1_h(191 downto 0);
      else
        d_o.data(383 downto 192) <= data1_l(191 downto 0);
      end if;

--      if d_i.addr0(addrbits-1) = '1' then
      if addr0hr = '1' then
        d_o.data(191 downto 0) <= data0_h(191 downto 0);
      else
        d_o.data(191 downto 0) <= data0_l(191 downto 0);
      end if;
      d_o.data(511 downto 384) <= (others => '0');
    end if;
  end process;

  ahreg: process(clk)
  begin
    if rising_edge(clk) then
      if d_i.enable(0)='1' then
        addr0hr <= d_i.addr0(addrbits-1);
      end if;
      if d_i.enable(1)='1' then
        addr1hr <= d_i.addr1(addrbits-1);
      end if;
    end if;
  end process;

end;
  

