------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
-- Entity: 	sramtestmod
-- File:	sramtestmod.vhd
-- Author:      Nils Johan Wessman, Cobham Gaisler
-- Contact:     support@gaisler.com
-- Description:	Test report module
--
-- See also the gaiser.sim.ahbrep module for a module connected via AHB for
-- for use internally on SoC.
--
-- This module supports a 8-, 16-, or 32-bit interface as selected via the 
-- 'width' generic. 
--
--  0x00 : sets and prints vendor id from data[31:24] and
--         device id from data[23:12]
--  0x04 : asserts error number data[15:0]
--  0x08 : calls subtest data[7:0]
--  0x10 : prints *** GRLIB system test starting ***
--  0x14 : prints Test passed / errors detected
--  0x18 : prints Checkpoint data[15:0] with time stamp
--
------------------------------------------------------------------------------

-- pragma translate_off

library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.sim.all;
library grlib;
use grlib.stdlib.all;
use grlib.stdio.all;
use grlib.devices.all;

use std.textio.all;

entity sramtestmod is
  generic (
    halt        : integer := 0;
    width       : integer := 32);
  port (
    resetn      : in  std_ulogic;
    address     : in std_logic_vector(21 downto 0);
    data        : inout std_logic_vector(width-1 downto 0);
    csn         : in std_ulogic;
    writen      : in std_ulogic; 		
    state       : out std_logic_vector(1 downto 0);
    testdev     : out std_logic_vector(19 downto 0);
    subtest     : out std_logic_vector(7 downto 0)
 );

end;

architecture sim of sramtestmod is
subtype msgtype is string(1 to 40);
constant ntests : integer := 2;
type msgarr is array (0 to ntests) of msgtype;
constant msg : msgarr := (
    "*** Starting GRLIB system test ***      ", -- 0
    "Test completed OK, halting simulation   ", -- 1
    "Test FAILED                             "  -- 2
);

--signal ior, iow, : std_ulogic; 
signal wen : std_ulogic;
signal addr : std_logic_vector(21 downto 0);
signal ldata : std_logic_vector(width-1 downto 0);
signal ldata32 : std_logic_vector(31 downto 0);
signal ldone : std_logic;

begin
  wen <= csn or writen;

  data <= (others => 'Z');

  addr <= to_X01(address) after 1 ns;
  ldata <= to_X01(data) after 1 ns;

  latch_bus : process(wen, resetn)
  begin
    if rising_edge(wen) then
      if width = 32 then
        ldata32(31 downto 0) <= ldata(31 downto 0);
        ldone <= '1', '0' after 1 ps;
      elsif width = 16 then
        if addr(1) = '0' then
          ldata32(31 downto 16) <= ldata(15 downto 0);
        else
          ldata32(15 downto 0) <= ldata(15 downto 0);
          ldone <= '1', '0' after 1 ps;
        end if;
      elsif width = 8 then
        case addr(1 downto 0) is
          when "11" => 
            ldata32(7 downto 0) <= ldata(7 downto 0);
            ldone <= '1', '0' after 1 ps;
          when "10" => 
            ldata32(15 downto 8) <= ldata(7 downto 0);
          when "01" => 
            ldata32(23 downto 16) <= ldata(7 downto 0);
          when others => 
            ldata32(31 downto 24) <= ldata(7 downto 0);
        end case;
      end if;
    end if;
    if resetn = '0' then
      ldone <= '0';
    end if;
  end process;


  log_rep : process(ldone)
  variable errno, errcnt, lsubtest, vendorid, deviceid : integer;
  variable lstate: std_logic_vector(1 downto 0) := "00";
  begin
    if falling_edge(ldone) then
      if addr(21 downto 5) = zero32(21 downto 5) then
        case addr(7 downto 2) is
        when "000000" =>
          vendorid := conv_integer(ldata32(31 downto 24));
          deviceid := conv_integer(ldata32(23 downto 12));
          print(iptable(vendorid).device_table(deviceid));
          testdev <= conv_std_logic_vector(vendorid*256+deviceid,20);
        when "000001" =>
          errno := conv_integer(ldata32(15 downto 0));
          if (halt = 0) then
            assert false
            report "test failed, error (" & tost(errno) & ")"
            severity failure;
          else
            assert false
            report "test failed, error (" & tost(errno) & ")"
            severity warning;
          end if;
          lstate := "11";
        when "000010" =>
          lsubtest := conv_integer(ldata32(7 downto 0));
          call_subtest(vendorid, deviceid, lsubtest);
          subtest <= conv_std_logic_vector(lsubtest,8);
        when "000100" =>
          print ("");
          print ("**** GRLIB system test starting ****");
          errcnt := 0;
          if lstate="00" then lstate := "01"; end if;
        when "000101" =>
          if errcnt = 0 then
            print ("Test passed, halting with IU error mode");
            if lstate="01" then lstate := "10"; end if;
          elsif errcnt = 1 then
            print ("1 error detected, halting with IU error mode");
          else
            print (tost(errcnt) & " errors detected, halting with IU error mode");
          end if;
          print ("");
        when "000110" =>
          grlib.testlib.print("Checkpoint " & tost(conv_integer(ldata32(15 downto 0))));
        when "000111" =>
          vendorid := 0; deviceid := 0;
          print ("Basic memory test");
        when others =>
        end case;
      end if;
    end if;
    state <= lstate;
  end process;
end;

-- pragma translate_on

