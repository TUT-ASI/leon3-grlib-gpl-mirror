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
-- entity: 	simuart
-- File:	simuart.vhd
-- Author:	Marko Isomaki - Gaisler Research
-- Description:	Sim-model UART for APBUart testbench
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.uart.all;
library grlib;
use grlib.stdlib.print;
use grlib.stdlib.xorv;
use work.apbuart_testpackage.all;

entity simuart is
  port(
    dbgi  : in  uart_dbg_in_type;
    dbgo  : out uart_dbg_out_type;
    uarti : in  uart_in_type;
    uarto : out uart_out_type);
end entity simuart;

architecture behavioral of simuart is
  type uart_fifo_type is array (0 to 1023) of std_logic_vector(7 downto 0);
  type tx_state_type is (startbit, data, parity, stopbit, breakend);
  signal rxchar     : std_logic_vector(7 downto 0);
  signal parerr     : std_ulogic;
  signal wrfifo     : std_ulogic;
  signal wrack      : std_ulogic;
  signal rdfifo     : std_ulogic;
  signal rdack      : std_ulogic;
  signal txchar     : std_logic_vector(7 downto 0);
  signal dav        : std_ulogic;
  signal txtick     : std_ulogic;
  signal txtickack  : std_ulogic;
begin
  rxfifo_p : process is
    variable cnt     : integer := 0;
    variable wpnt    : integer := 0;
    variable rpnt    : integer := 0;
    variable rxfifo  : uart_fifo_type;
    variable vparerr : std_logic_vector(0 to 1023);
  begin
    dbgo.rxfifoerr <= '0'; dbgo.rdack <= '0'; wrack <= '0';
    loop
      if rising_edge(dbgi.rdfifo) then
        if cnt > 0 then
          dbgo.rdack <= '1'; dbgo.rxchar <= rxfifo(rpnt);
          dbgo.parerr <= vparerr(rpnt);
        end if;
      end if;
      if falling_edge(dbgi.rdfifo) then
        dbgo.rdack <= '0'; cnt := cnt - 1;
        rpnt := rpnt + 1;
      end if;
      if rising_edge(wrfifo) then
        if cnt < 1024 then
          rxfifo(wpnt)  := rxchar;
          vparerr(wpnt) := parerr;
          cnt := cnt + 1; wpnt := wpnt + 1;
          wrack <= '1';
        else
          print("Error: Fifo full");
          dbgo.rxfifoerr <= '1';
        end if;
      end if;
      if falling_edge(wrfifo) then
        wrack <= '0';
      end if;
      wait on wrfifo, dbgi.rdfifo;
    end loop;  
  end process;

  receiver_p : process is
    variable char    : std_logic_vector(7 downto 0);
    variable parity  : std_ulogic;
    variable vparerr : std_ulogic;
  begin
    dbgo.stopbiterr <= '0'; wrfifo <= '0'; dbgo.gotchar <= '0';
    while dbgi.rxen /= '1' loop
      wait on dbgi.rxen;
    end loop;
    wait until uarti.rxd = '0';
    wait for (500000000/dbgi.baudrate)*1 ns;
    parity := '0';
    for i in 0 to 7 loop
      wait for (1000000000/dbgi.baudrate)*1 ns;
      char(i) := uarti.rxd;
      parity  := parity xor uarti.rxd;
    end loop;
    rxchar <= char;
    if dbgi.paren = '1' then
      wait for (1000000000/dbgi.baudrate)*1 ns;
      parity := parity xor uarti.rxd;
      if (dbgi.parsel = '1') and (parity = '0') then
        vparerr := '1';
      elsif (dbgi.parsel = '0') and (parity = '1') then
        vparerr := '1';
      else
        vparerr := '0';
      end if;
    end if;
    wait for (1000000000/dbgi.baudrate)*1 ns;
    if uarti.rxd /= '1' then
      dbgo.stopbiterr <= '1';
    end if;
    dbgo.gotchar <= '1';
    wrfifo <= '1'; rxchar <= char; parerr <= vparerr;
    wait until wrack <= '1';
    wrfifo <= '0';
    wait until wrack <= '0';
    wait for (500000000/dbgi.baudrate)*1 ns;
    dbgo.gotchar <= '0';
  end process;

  txfifo_p : process is
    variable cnt     : integer := 0;
    variable wpnt    : integer := 0;
    variable rpnt    : integer := 0;
    variable txfifo  : uart_fifo_type;
  begin
    dbgo.wrack <= '0'; rdack <= '0'; dav <= '0';
    loop
      if rising_edge(rdfifo) then
        if cnt > 0 then
          rdack <= '1'; txchar <= txfifo(rpnt);
        end if;
      end if;
      if falling_edge(rdfifo) then
        rdack <= '0'; cnt := cnt - 1;
        rpnt := rpnt + 1;
      end if;
      if rising_edge(dbgi.wrfifo) then
        if cnt < 1024 then
          txfifo(wpnt) := dbgi.txchar;
          cnt := cnt + 1; wpnt := wpnt + 1;
          dbgo.wrack <= '1';
        else
          print("Error: Fifo full");
          dbgo.txfifoerr <= '1';
        end if;
      end if;
      if falling_edge(dbgi.wrfifo) then
        dbgo.wrack <= '0';
      end if;
      if cnt /= 0 then
        dav <= '1';
      else
        dav <= '0';
      end if;
      wait on rdfifo, dbgi.wrfifo;
    end loop;  
  end process;

  txtick_p : process is
  begin
    txtick <= '0';
    loop
      wait for (1000000000/dbgi.baudrate)*1 ns;
      txtick <= '1';
      wait until txtickack = '1';
      txtick <= '0';
      wait until txtickack = '0';
    end loop;
  end process;

  transmitter_p : process is
    variable nxtchar : std_logic_vector(7 downto 0);
    variable gotchar : boolean;
    variable state   : tx_state_type;
    variable cnt     : integer;
    variable break   : boolean;
  begin
    rdfifo <= '0'; gotchar := false; uarto.txd <= '1';
    state := startbit; dbgo.txdone <= '0'; break := false;
    dbgo.breakack <= '0';
    loop
      if rising_edge(dbgi.sndbreak) then
        dbgo.breakack <= '1';
      end if;
      if falling_edge(dbgi.sndbreak) then
        dbgo.breakack <= '0'; break := true;
        gotchar := true;
      end if;
      if (dav = '1') and not gotchar and (dbgi.sndbreak = '0') then
        rdfifo <= '1';
      end if;
      if rising_edge(rdack) then
        nxtchar := txchar;
        rdfifo <= '0';
        gotchar := true;
      end if;
      if gotchar then
        if rising_edge(txtick) then
          case state is
            when startbit =>
              uarto.txd <= '0'; dbgo.txdone <= '0';
              state := data; cnt := 0;
            when data =>
              if break then
                uarto.txd <= '0';
              else
                uarto.txd <= nxtchar(cnt);
              end if;
              if cnt = 7 then
                if dbgi.paren = '1' then
                  state := parity;
                else
                  state := stopbit;
                end if;
              else
                cnt := cnt + 1;
              end if;
            when parity =>
              if break then
                uarto.txd <= '0';
              else
                if dbgi.parsel = '0' then --even parity
                  uarto.txd <= xorv(nxtchar);
                else --odd parity
                  uarto.txd <= not xorv(nxtchar);
                end if;
              end if;
              state := stopbit;
            when stopbit =>
              if break then
                uarto.txd <= '0';
                state := breakend;
              else
                uarto.txd <= '1';
                state := startbit;
                gotchar := false;
                dbgo.txdone <= '1';
              end if;
            when breakend =>
              state := startbit;
              uarto.txd <= '1';
              gotchar := false;
              dbgo.txdone <= '1';
              break := false;
            when others =>
              null;
          end case;
        end if;
      end if;
      if rising_edge(txtick) then
        txtickack <= '1';
      end if;
      if falling_edge(txtick) then
        txtickack <= '0';
      end if;
      wait on rdack, dav, txtick, dbgi.sndbreak;
    end loop;
  end process;
end architecture;
