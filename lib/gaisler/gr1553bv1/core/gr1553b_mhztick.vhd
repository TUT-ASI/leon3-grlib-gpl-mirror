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
-- Entity:      gr1553b_mhztick
-- File:        gr1553b_mhztick.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B MHz tick generator with clock-domain crossing
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity gr1553b_mhztick is
  generic(
    timeclk_freq_mhz: integer;
    sameclk: integer range 0 to 1;
    syncrst: integer range 0 to 2
    );
  port(
    clk: in std_logic;
    rst: in std_logic;

    restart: in std_logic;
    clear: in std_logic;
    tick: out std_logic;

    -- time clock domain signals
    timeclk: in std_logic;
    timerst: in std_logic
    );
end;

architecture rtl of gr1553b_mhztick is
  -- Main timer function signals
  signal timerval, ntimerval: integer range 0 to timeclk_freq_mhz-1;
  signal restart_time,tick_time: std_logic;

  -- Handshaking signals in timer domain (bypassed when sameclk=1)
  signal restart_sync1, restart_sync2, last_restart: std_logic;
  signal clear_sync1, clear_sync2: std_logic;
  signal tick_tog, ntick_tog: std_logic;

  -- User clock domain handshaking signals (bypassed when sameclk=1)
  signal tick_user: std_logic;  
  signal tick_sync1,tick_sync2, last_tick: std_logic;
  signal restart_tog, nrestart_tog, resret_sync1, resret_sync2, resret_sync3: std_logic;
  signal clear_hs: std_logic;

  constant timer_restartval: integer := (1-sameclk)*2;
  
begin

  tick <= tick_user;
  
  -- Timer logic
  comb: process(timerst,timerval,restart_time)
    variable vtick: std_logic;
    variable vntimerval: integer range 0 to timeclk_freq_mhz-1;
  begin
    if timerval=timeclk_freq_mhz-1 then
      vtick := '1';
      vntimerval := 0;
    else
      vtick := '0';
      vntimerval := timerval+1;
    end if;
    if (timerst='0' and syncrst/=0) or restart_time='1' then
      vntimerval := timer_restartval;
    end if;
    tick_time <= vtick;
    ntimerval <= vntimerval;
  end process;

  regs: process(timeclk,timerst)
  begin
    if rising_edge(timeclk) then
      timerval <= ntimerval;
    end if;
    if timerst='0' and syncrst=0 then
      timerval <= timer_restartval;
    end if;
  end process;
  
  -- Resynchronizers and handshaking
  syncgen: if sameclk=0 generate

    timecomb: process(timerst,restart_sync2,tick_time,tick_tog,last_restart)
      variable vrestart_time: std_logic;
      variable vntick_tog: std_logic;
    begin
      vrestart_time := '0';
      if restart_sync2/=last_restart then vrestart_time:='1'; end if;
      vntick_tog := tick_tog xor (tick_time and not vrestart_time);
      if timerst='0' and syncrst/=0 then
        vntick_tog := '0';
      end if;
      restart_time <= vrestart_time;
      ntick_tog <= vntick_tog;
    end process;

    timeregs: process(timeclk,timerst)
    begin
      if rising_edge(timeclk) then
        last_restart <= restart_sync2 xor clear_sync2;
        tick_tog <= ntick_tog;
      end if;
      if timerst='0' and syncrst=0 then
        last_restart <= '1';
        tick_tog <= '0';        
      end if;
    end process;
    
    timesync: process(timeclk,timerst)
    begin
      if rising_edge(timeclk) then        
        restart_sync1 <= restart_tog;
        restart_sync2 <= restart_sync1;
        clear_sync1 <= clear_hs;
        clear_sync2 <= clear_sync1;
      end if;
      if timerst='0' and syncrst=0 then
        restart_sync1 <= '0';
        restart_sync2 <= '0';
        clear_sync1 <= '1';
        clear_sync2 <= '1';
      end if;
    end process;

    usercomb: process(rst,tick_sync2,last_tick,restart,restart_tog,resret_sync3)
      variable vtick_user: std_logic;
      variable vnrestart_tog: std_logic;
    begin
      vtick_user := '0';
      vnrestart_tog := restart_tog;
      if resret_sync3=restart_tog then
        if tick_sync2/=last_tick then vtick_user:='1'; end if;
        if restart='1' then vnrestart_tog:=not restart_tog; end if;
      end if;
      if rst='0' and syncrst/=0 then
        vnrestart_tog := '0';
      end if;
      tick_user <= vtick_user;
      nrestart_tog <= vnrestart_tog;
    end process;

    userregs: process(clk,rst)
    begin
      if rising_edge(clk) then
        last_tick <= tick_sync2;
        restart_tog <= nrestart_tog;
        clear_hs <= clear;
      end if;
      if rst='0' and syncrst=0 then
        last_tick <= '0';
        restart_tog <= '0';
        clear_hs <= '1';
      end if;
    end process;
    
    usersync: process(clk,rst)
    begin
      if rising_edge(clk) then
        tick_sync1 <= tick_tog;
        tick_sync2 <= tick_sync1;
        resret_sync1 <= last_restart;
        resret_sync2 <= resret_sync1;
        resret_sync3 <= resret_sync2;
      end if;
      if rst='0' and syncrst=0 then
        tick_sync1 <= '0';
        tick_sync2 <= '0';
        resret_sync1 <= '1';
        resret_sync2 <= '1';
        resret_sync3 <= '1';
      end if;
    end process;
  end generate;

  nsyncgen: if sameclk=1 generate
    restart_time <= restart or clear;
    tick_user <= tick_time;
  end generate;

end;
