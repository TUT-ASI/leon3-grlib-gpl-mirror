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
-- Entity:      busif5rdb
-- File:        bufis5rdb.vhd
-- Author:      Magnus Hjorth, Frontgrade Gaisler
-- Description: Data buffer register stage for bus interface
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.busif5_types.all;

entity busif5rdb is
  generic (
    linesize : integer;
    wdwidth  : integer;
    nports   : integer
    );
  port (
    clk  : in  std_ulogic;
    clr  : in  std_ulogic;
    ubuf : in  busif_rdbufu_array_type(0 to nports-1);
    rbuf : out busif_rdbufr_type5
    );
end;

architecture rtl of busif5rdb is

  signal r,nr: busif_rdbufr_type5;

begin
  rbuf <= r;

  comb: process(r,ubuf,clr)
    variable v: busif_rdbufr_type5;
  begin
    v := r;
    for p in 0 to nports-1 loop
      for x in 15 downto 0 loop
        if r.bufe(x)='1' then
          if ubuf(p).errclr(0)='1' then
            v.buf(32*x+31 downto 32*x) := (others => '0');
          elsif ubuf(p).errclr(1)='1' then
            v.buf(32*x+31 downto 32*x) := (others => '1');
          end if;
          v.bufv(x) := '1';
        end if;
        if ubuf(p).bufw(x)='1' then
          v.buf(32*x+31 downto 32*x) := ubuf(p).bufwd( ((32*x) mod wdwidth)+31 downto ((32*x) mod wdwidth) );
          v.bufv(x) := '1';
        end if;
        if ubuf(p).sete(x)='1' then
          v.bufe(x) := '1';
          v.err := '1';
        end if;
      end loop;
      if ubuf(p).setdone='1' then
        v.done := '1';
        v.started := '1';
      end if;
      if ubuf(p).setstarted='1' then
        v.started := '1';
      end if;
    end loop;
    if clr='1' then
      v.bufv := (others => '0');
      v.bufe := (others => '0');
      v.started := '0';
      v.done := '0';
      v.err := '0';
    end if;
    -- Constant registers
    if linesize < 16 then
      v.buf(511 downto 256) := (others => '0');
      v.bufe(15 downto 8) := (others => '0');
      v.bufv(15 downto 8) := (others => '0');
    end if;
    if linesize < 8 then
      v.buf(255 downto 128) := (others => '0');
      v.bufe(7 downto 4) := (others => '0');
      v.bufv(7 downto 4) := (others => '0');
    end if;
    nr <= v;
  end process;

  regs: process(clk)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
  end process;

end;
