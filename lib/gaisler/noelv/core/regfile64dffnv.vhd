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
-- Entity: 	regfile64l5
-- File:	regfile64l5.vhd
-- Author:	Alen Bardizbanyan, Cobham Gaisler
-- Description:	4-read ports and 2-write ports flip-flop regfile
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.notx;
library gaisler;
use gaisler.utilnv.u2i;
use gaisler.noelvint.reg_t;

entity regfile64dffnv is
  generic (
    tech        : integer;
    wrfst       : integer;
    reg0write   : integer := 0
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    rdhold   : in  std_ulogic;
    waddr1   : in  reg_t;
    wdata1   : in  std_logic_vector;
    we1      : in  std_ulogic;
    waddr2   : in  reg_t;
    wdata2   : in  std_logic_vector;
    we2      : in  std_ulogic;
    raddr1   : in  reg_t;
    re1      : in  std_ulogic;
    rdata1   : out std_logic_vector;
    raddr2   : in  reg_t;
    re2      : in  std_ulogic;
    rdata2   : out std_logic_vector;
    raddr3   : in  reg_t;
    re3      : in  std_ulogic;
    rdata3   : out std_logic_vector;
    raddr4   : in  reg_t;
    re4      : in  std_ulogic;
    rdata4   : out std_logic_vector
    );
begin
  assert wdata1'length = wdata2'length and
         rdata1'length = rdata2'length and
         rdata3'length = rdata4'length and
         rdata1'length = rdata3'length and
         wdata1'length = rdata1'length report "Bad register data size" severity failure;
end regfile64dffnv;

architecture rtl of regfile64dffnv is

  subtype data_t is std_logic_vector(wdata1'range);

  type entry_type is array(0 to 2 ** reg_t'length - 1) of data_t;

  type reg_type is record
    entry   : entry_type;
    raddr1  : reg_t;
    raddr2  : reg_t;
    raddr3  : reg_t;
    raddr4  : reg_t;
  end record;

  signal r, rin : reg_type;

begin  -- rtl

  comb : process(r, rstn, waddr1, we1, waddr2, we2, re1, raddr1, re2, raddr2, re3, raddr3, re4, raddr4, wdata1, wdata2, rdhold)
    variable v       : reg_type;
    variable rdata1v : data_t;
    variable rdata2v : data_t;
    variable rdata3v : data_t;
    variable rdata4v : data_t;
  begin

    v := r;

    -- Register Input Address
    if re1 = '1' and rdhold = '0'then
      v.raddr1  := raddr1;
    end if;

    if re2 = '1' and rdhold = '0' then
      v.raddr2  := raddr2;
    end if;

    if re3 = '1' and rdhold = '0' then
      v.raddr3  := raddr3;
    end if;

    if re4 = '1' and rdhold = '0' then
      v.raddr4  := raddr4;
    end if;

    if we1 = '1' then
      v.entry(u2i(waddr1)) := wdata1;
    end if;

    if we2 = '1' then
      v.entry(u2i(waddr2)) := wdata2;
    end if;

    rdata1v := (others => '0');
    rdata2v := (others => '0');
    rdata3v := (others => '0');
    rdata4v := (others => '0');

    if (r.raddr1 /= "00000") or (reg0write /= 0) then
      if notx(r.raddr1) then
        rdata1v := r.entry(u2i(r.raddr1));
      end if;
      
      if (waddr1 = r.raddr1) and we1 = '1' then
        rdata1v := wdata1;
      end if;

      if (waddr2 = r.raddr1) and we2 = '1' then
        rdata1v := wdata2;
      end if;
      
    end if;
    
    if (r.raddr2 /= "00000") or (reg0write /= 0) then
      if notx(r.raddr2) then
        rdata2v := r.entry(u2i(r.raddr2));
      end if;
      
      if (waddr1 = r.raddr2) and we1 = '1' then
        rdata2v := wdata1;
      end if;

      if (waddr2 = r.raddr2) and we2 = '1' then
        rdata2v := wdata2;
      end if;
      
    end if;

    if (r.raddr3 /= "00000") or (reg0write /= 0) then
      if notx(r.raddr3) then
        rdata3v := r.entry(u2i(r.raddr3));
      end if;
      
      if (waddr1 = r.raddr3) and we1 = '1' then
        rdata3v := wdata1;
      end if;

      if (waddr2 = r.raddr3) and we2 = '1' then
        rdata3v := wdata2;
      end if;
      
    end if;
    
    if (r.raddr4 /= "00000") or (reg0write /= 0) then
      if notx(r.raddr4) then
        rdata4v := r.entry(u2i(r.raddr4));
      end if;
      
      if (waddr1 = r.raddr4) and we1 = '1' then
        rdata4v := wdata1;
      end if;

      if (waddr2 = r.raddr4) and we2 = '1' then
        rdata4v := wdata2;
      end if;
      
    end if;
    
    -- Output Signals
    rdata1 <= rdata1v;
    rdata2 <= rdata2v;
    rdata3 <= rdata3v;
    rdata4 <= rdata4v;
    rin    <= v;

  end process;

  seq : process(clk, rstn)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;

  end process;


end rtl;
