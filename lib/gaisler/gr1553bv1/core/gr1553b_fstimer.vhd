------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
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
-- Entity:      gr1553b_fstimer
-- File:        gr1553b_fstimer.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B 800 us fail-safe timer
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity gr1553b_fstimer is
  generic (
    tx_clk_freq_mhz: integer;
    sameclk: integer range 0 to 1;
    syncrst: integer range 0 to 2
    );
  port (
    -- TX Clock domain
    tx_clk: in std_logic;
    tx_rst: in std_logic;    
    txP: in std_logic;
    txN: in std_logic;
    timeout: out std_logic;
    -- CMD Clock domain
    validcmd_clk: in std_logic;
    validcmd_rst: in std_logic;
    validcmd: in std_logic
    );
end;

architecture rtl of gr1553b_fstimer is

  function lowest_2pot(x: integer) return integer is
    variable i: integer;
  begin
    i := 1;
    while i<x loop i:=i*2; end loop;
    return i;
  end;
    
  constant tocount: integer := 790 * tx_clk_freq_mhz;

  constant tval_max: integer := lowest_2pot(tocount)-1;
  
  type fstimer_regs is record
    txP_s: std_logic_vector(0 to 1);
    txN_s: std_logic_vector(0 to 1);
    timerval: integer range 0 to tval_max;
    timed_out: std_logic;
    vc_ack: std_logic;
  end record;

  constant r_rst: fstimer_regs := ("00","00",0,'0','0');
  
  signal r,nr: fstimer_regs;
  signal vc_assert_sync1,vc_assert_sync2: std_logic;
  signal vc_assert, nvc_assert: std_logic;
  signal vc_ack_sync1,vc_ack_sync2: std_logic;
  
begin

  comb: process(r,tx_rst,txP,txN,vc_assert_sync2)
    variable v: fstimer_regs;
  begin
    v := r;

    v.txP_s := r.txP_s(1 to r.txP_s'high) & txP;
    v.txN_s := r.txN_s(1 to r.txN_s'high) & txN;
    
    if r.txP_s(0)='1' or r.txN_s(0)='1' then
      
      if r.timerval=tocount-1 then
        v.timed_out := '1';
      end if;
      
      if r.timerval=tval_max then
        v.timerval := 0;
      else
        v.timerval := r.timerval+1;
      end if;

    end if;

    v.vc_ack := vc_assert_sync2;
    if vc_assert_sync2='1' then
      v.timed_out := '0';
      v.timerval := 0;
    end if;
          
    if tx_rst='0' and syncrst/=0 then
      v.timerval := 0;
      v.timed_out := '0';
      v.vc_ack := '0';
    end if;

    nr <= v;
    timeout <= r.timed_out;
  end process;

  nsamegen: if sameclk=0 generate
  
    vccomb: process(validcmd_rst,vc_ack_sync2,validcmd,vc_assert)
      variable vassert: std_logic;
    begin
      vassert := vc_assert;
      if vc_ack_sync2='1' then vassert := '0'; end if;
      if validcmd='1' then vassert := '1'; end if;
      if (validcmd_rst='0' and syncrst/=0) then vassert := '0'; end if;
      nvc_assert <= vassert;
    end process;
    
    txregs: process(tx_clk,tx_rst)
    begin
      if rising_edge(tx_clk) then
        r <= nr;
        vc_assert_sync1 <= vc_assert;
        vc_assert_sync2 <= vc_assert_sync1;
      end if;
      if tx_rst='0' and syncrst=0 then
        r <= r_rst;
      end if;
    end process;
    
    vcregs: process(validcmd_clk,validcmd_rst)
    begin
      if rising_edge(validcmd_clk) then
        vc_assert <= nvc_assert;
        vc_ack_sync1 <= r.vc_ack;
        vc_ack_sync2 <= vc_ack_sync1;
      end if;
      if validcmd_rst='0' and syncrst=0 then
        vc_assert <= '0';
        vc_ack_sync1 <= '0';
        vc_ack_sync2 <= '0';
      end if;
    end process;

  end generate;

  samegen: if sameclk=1 generate

    vc_assert <= '0';
    nvc_assert <= '0';
    vc_assert_sync1 <= '0';
    vc_ack_sync1 <= '0';
    vc_ack_sync2 <= '0';
    
    vc_assert_sync2 <= validcmd;
    
    regs: process(tx_clk,tx_rst)
    begin
      if rising_edge(tx_clk) then
        r <= nr;
      end if;
      if tx_rst='0' and syncrst=0 then
        r <= r_rst;
      end if;
    end process;
    
  end generate;
end;
