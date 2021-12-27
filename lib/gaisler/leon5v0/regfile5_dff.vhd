------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-- Entity:      regfile5_ram
-- File:        regfile5_ram.vhd
-- Author:      Alen Bardizbanyan, Cobham Gaisler
-- Description: Register file for LEON5 built from syncram_2p instances
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;

entity regfile5_dff is
  generic (
    abits   : integer;
    dbits   : integer;
    wrfst   : integer;
    numregs : integer;
    g0addr  : integer;
    rfconf  : integer
    );
  port (
    clk    : in  std_logic;
    rstn   : in  std_logic;
    rdhold : in  std_logic;
    waddr1 : in  std_logic_vector((abits -1) downto 0);
    wdata1 : in  std_logic_vector((dbits -1) downto 0);
    we1    : in  std_logic_vector(1 downto 0);
    waddr2 : in  std_logic_vector((abits -1) downto 0);
    wdata2 : in  std_logic_vector((dbits -1) downto 0);
    we2    : in  std_logic_vector(1 downto 0);
    raddr1 : in  std_logic_vector((abits -1) downto 0);
    re1    : in  std_logic_vector(1 downto 0);
    rdata1 : out std_logic_vector((dbits -1) downto 0);
    raddr2 : in  std_logic_vector((abits -1) downto 0);
    re2    : in  std_logic_vector(1 downto 0);
    rdata2 : out std_logic_vector((dbits -1) downto 0);
    raddr3 : in  std_logic_vector((abits -1) downto 0);
    re3    : in  std_logic_vector(1 downto 0);
    rdata3 : out std_logic_vector((dbits -1) downto 0);
    raddr4 : in  std_logic_vector((abits -1) downto 0);
    re4    : in  std_logic_vector(1 downto 0);
    rdata4 : out std_logic_vector((dbits -1) downto 0)
    );
end regfile5_dff;

architecture rtl of regfile5_dff is

  type entry_type is array(0 to numregs-1) of std_logic_vector(63 downto 0);

  type reg_type is record
    entry  : entry_type;
    raddr1 : std_logic_vector((abits -1) downto 0);
    raddr2 : std_logic_vector((abits -1) downto 0);
    raddr3 : std_logic_vector((abits -1) downto 0);
    raddr4 : std_logic_vector((abits -1) downto 0);
  end record;

  signal r, rin : reg_type;


begin


  comb : process(rdhold, re1, re2, re3, re4, waddr1, waddr2, wdata1, wdata2, raddr1, raddr2, raddr3, raddr4, we1, we2, r)
    variable v                                  : reg_type;
    variable rdata1v, rdata2v, rdata3v, rdata4v : std_logic_vector(63 downto 0);
  begin

    v := r;

    if rdhold = '0' then
      if re1 /= "00" then
        v.raddr1 := raddr1;
      end if;
      if re2 /= "00" then
        v.raddr2 := raddr2;
      end if;
      if re3 /= "00" then
        v.raddr3 := raddr3;
      end if;
      if re4 /= "00" then
        v.raddr4 := raddr4;
      end if;
    end if;

    if we1(0) = '1' then
      v.entry(to_integer(unsigned(waddr1)))(63 downto 32) := wdata1(63 downto 32);
    end if;
    if we1(1) = '1' then
      v.entry(to_integer(unsigned(waddr1)))(31 downto 0) := wdata1(31 downto 0);
    end if;

    if we2(0) = '1' then
      v.entry(to_integer(unsigned(waddr2)))(63 downto 32) := wdata2(63 downto 32);
    end if;
    if we2(1) = '1' then
      v.entry(to_integer(unsigned(waddr2)))(31 downto 0) := wdata2(31 downto 0);
    end if;

    rdata1v := r.entry(to_integer(unsigned(r.raddr1)));
    rdata2v := r.entry(to_integer(unsigned(r.raddr2)));
    rdata3v := r.entry(to_integer(unsigned(r.raddr3)));
    rdata4v := r.entry(to_integer(unsigned(r.raddr4)));

    if waddr1 = r.raddr1 then
      if we1(0) = '1' then
        rdata1v(63 downto 32) := wdata1(63 downto 32);
      end if;
      if we1(1) = '1' then
        rdata1v(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;
    if waddr2 = r.raddr1 then
      if we2(0) = '1' then
        rdata1v(63 downto 32) := wdata2(63 downto 32);
      end if;
      if we2(1) = '1' then
        rdata1v(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;

    if waddr1 = r.raddr2 then
      if we1(0) = '1' then
        rdata2v(63 downto 32) := wdata1(63 downto 32);
      end if;
      if we1(1) = '1' then
        rdata2v(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;
    if waddr2 = r.raddr2 then
      if we2(0) = '1' then
        rdata2v(63 downto 32) := wdata2(63 downto 32);
      end if;
      if we2(1) = '1' then
        rdata2v(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;

    if waddr1 = r.raddr3 then
      if we1(0) = '1' then
        rdata3v(63 downto 32) := wdata1(63 downto 32);
      end if;
      if we1(1) = '1' then
        rdata3v(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;
    if waddr2 = r.raddr3 then
      if we2(0) = '1' then
        rdata3v(63 downto 32) := wdata2(63 downto 32);
      end if;
      if we2(1) = '1' then
        rdata3v(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;

    if waddr1 = r.raddr4 then
      if we1(0) = '1' then
        rdata4v(63 downto 32) := wdata1(63 downto 32);
      end if;
      if we1(1) = '1' then
        rdata4v(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;
    if waddr2 = r.raddr4 then
      if we2(0) = '1' then
        rdata4v(63 downto 32) := wdata2(63 downto 32);
      end if;
      if we2(1) = '1' then
        rdata4v(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;

    if rstn = '0' then
      v.raddr1 := (others=>'0');
      v.raddr2 := (others=>'0');
      v.raddr3 := (others=>'0');
      v.raddr4 := (others=>'0');
    end if;

    rin <= v;

    rdata1 <= rdata1v;
    rdata2 <= rdata2v;
    rdata3 <= rdata3v;
    rdata4 <= rdata4v;
    
  end process;

  seq : process(clk, rstn)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;

  end process;
  

end;
