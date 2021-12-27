------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
-- Entity:      uartprint
-- File:        uartprint.vhd
-- Author:      Magnus Hjorth, Aeroflex Gaisler
-- Description: Module to print UART output in simulation
------------------------------------------------------------------------------

--pragma translate_off

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;

entity uartprint is
  port (
    txd: in std_ulogic
    );
end;

architecture sim of uartprint is
begin
  p: process
    type timearr is array(natural range <>) of time;
    constant sregl: integer := 32;
    variable sregd: std_logic_vector(0 to sregl-1);
    variable sregt: timearr(0 to sregl-1);
    variable sregp: integer range 0 to sregl-1 := 0;
    constant lbufl: integer := 79;
    variable lbufd: string(1 to lbufl);
    variable lbufp: integer range 1 to lbufl := 1;
    variable bitper: time;
    variable et: time;
    variable txdv: std_ulogic;
    variable timeout: boolean;
    variable dbits: std_logic_vector(0 to 29);
    variable dbits2: unsigned(7 downto 0);
    variable dbc,l: integer;
    variable nvchar: integer;
    variable bitrate_lock: boolean := false;
    variable bitrate_per: time;

    impure function getminper(stidx: integer; adjmul,adjdiv: integer) return time is
      variable r,dt: time;
    begin
      if bitrate_lock then
        return (bitrate_per * adjmul) / adjdiv;
      else
        r := sregt(stidx+1) - sregt(stidx);
        for x in stidx+1 to sregp-2 loop
          dt := sregt(x+1) - sregt(x);
          if dt < r then r := dt; end if;
        end loop;
        r := (r*adjmul)/adjdiv;
        return r;
      end if;
    end getminper;

    procedure sreg_pop is
    begin
      sregd(0 to sregl-2) := sregd(1 to sregl-1);
      sregt(0 to sregl-2) := sregt(1 to sregl-1);
      sregp := sregp-1;
    end sreg_pop;

  begin
    -- Wait for txd to change
    -- Either with or without the timeout
    txdv := to_X01(txd);
    timeout := false;
    if txdv='1' and sregp>1 then
      -- With timeout for stop bit
      bitper := getminper(0,101,100);
      wait until to_X01(txd) /= txdv for bitper;
      if to_X01(txd) = txdv then timeout:=true; end if;
    else
      -- Without timeout
      wait until to_X01(txd) /= txdv;
    end if;
    txdv := to_X01(txd);
    -- Record transition into shift register
    if not timeout then
      -- If we are about to fill up the shift register with bitrate_lock set, clear
      -- bitrate_lock and try detecting new bitrate
      if sregp+1 >= sregl then
        bitrate_lock := false;
      end if;
      -- Shift register overflow, shift out the oldest entry
      if sregp = sregl then
        sreg_pop;
      end if;
      sregd(sregp) := txdv;
      sregt(sregp) := now;
      sregp := sregp+1;
    end if;
    -- Check if we can see a valid UART character in the shift reg
    for spos in 0 to sregp-2 loop
      bitper := getminper(spos,99,100);
      dbc := 0;
      for p in spos to sregp-2 loop
        l := (sregt(p+1)-sregt(p))/bitper;
        if l<1 then exit; end if;
        if l > 10-(dbc mod 10) then
          l := 10-(dbc mod 10);
        end if;
        if l > 30-dbc then
          l := 30-dbc;
        end if;
        for x in 1 to l loop
          dbits(dbc) := sregd(p);
          dbc := dbc+1;
        end loop;
      end loop;
      if (dbc mod 10)=9 and timeout then
        dbits(dbc) := '1';
        dbc := dbc+1;
      end if;
      nvchar := 0;
      while dbc>=(nvchar+1)*10 and dbits(nvchar*10)='0' and dbits(nvchar*10+9)='1' loop
        nvchar := nvchar+1;
      end loop;
      if nvchar=3 and not bitrate_lock then
        bitrate_per := getminper(spos,1,1);
        bitrate_lock := true;
      end if;
      if bitrate_lock and nvchar>0 then
        et := sregt(spos) + nvchar*10*bitper;
        while sregp > 1 and sregt(1) < et loop
          sreg_pop;
        end loop;
        for c in 0 to nvchar-1 loop
          for x in 0 to 7 loop
            dbits2(x) := dbits(10*c+1+x);
          end loop;
          -- print("UART: Detected character code " & tost(to_integer(unsigned(dbits(10*c+1 to 10*c+8)))) & "/" & tost(to_integer(dbits2)) & " spos:" & tost(spos) & " bitrate: " & tost(integer'(bitper / (1 ns))) & " et: " & tost(integer'(et / (1 ns))));
          dbits2(7) := '0';
          lbufd(lbufp) := character'val(to_integer(dbits2));
          lbufp := lbufp+1;
          if lbufd(lbufp-1)=cr or lbufd(lbufp-1)=lf then
            if lbufp>2 then
              print("UART: " & lbufd(1 to lbufp-2));
            end if;
            lbufp := 1;
          end if;
        end loop;
        exit;
      end if;
    end loop;
  end process;
end;

--pragma translate_on
