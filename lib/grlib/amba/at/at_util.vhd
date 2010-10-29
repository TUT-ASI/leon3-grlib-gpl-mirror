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
-------------------------------------------------------------------------------
-- Package:     at_util
-- File:        at_util.vhd
-- Author:      Marko Isomaki, Aeroflex Gaisler
-- Description: AMBA test framework misc procedures
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.testlib.all;
use grlib.stdlib.tost;
use grlib.stdlib."+";
use grlib.at_pkg.all;
use grlib.at_ahb_mst_pkg.all;
use grlib.at_ahb_slv_pkg.all;

package at_util is
  ----------------------------------------------------------------------------
  -- Compare memory contents with octet_vector
  ----------------------------------------------------------------------------
  procedure comparemem(
    constant address:  in    std_logic_vector(31 downto 0);
    constant size:     in    integer;
    constant data:     in    octet_vector;
    constant screen:   in    boolean;
    variable tp:       inout boolean;
    signal   atmi:     out   at_ahb_mst_in_type;
    signal   atmo:     in    at_ahb_mst_out_type);

  procedure comparemem(
    constant address:  in    std_logic_vector(31 downto 0);
    constant size:     in    integer;
    constant data:     in    octet_vector;
    constant screen:   in    boolean;
    constant bank:     in    integer;
    variable tp:       inout boolean;
    signal   dbgi:     out   at_slv_dbg_in_type;
    signal   dbgo:     in    at_slv_dbg_out_type);

  ----------------------------------------------------------------------------
  -- Fill memory with octet_vector or file contents
  ----------------------------------------------------------------------------
  procedure fillmemory(
    constant filename:      in   string := "";
    constant size:          in   integer := 0;
    constant address:       in   std_logic_vector(31 downto 0);
    constant screen:        in   boolean := false;
    signal   clk:           in   std_ulogic;
    signal   atmi:          out  at_ahb_mst_in_type;
    signal   atmo:          in   at_ahb_mst_out_type);

  procedure fillmemory(
    constant octets:        in   octet_vector;
    constant size:          in   integer;
    constant address:       in   std_logic_vector(31 downto 0);
    constant screen:        in   boolean := false;
    signal   clk:           in   std_ulogic;
    signal   atmi:          out  at_ahb_mst_in_type;
    signal   atmo:          in   at_ahb_mst_out_type);

  procedure fillmemory(
    constant filename:      in   string := "";
    constant size:          in   integer;
    constant address:       in   std_logic_vector(31 downto 0);
    constant screen:        in   boolean := false;
    constant bank:          in   integer := 0;
    signal   dbgi:          out  at_slv_dbg_in_type;
    signal   dbgo:          in   at_slv_dbg_out_type);
 
  procedure fillmemory(
    constant octets:        in   octet_vector;
    constant size:          in   integer;
    constant address:       in   std_logic_vector(31 downto 0);
    constant screen:        in   boolean := false;
    constant bank:          in   integer := 0;
    signal   dbgi:          out  at_slv_dbg_in_type;
    signal   dbgo:          in   at_slv_dbg_out_type);

  ----------------------------------------------------------------------------
  -- Load octet_vector with contents from memory
  ----------------------------------------------------------------------------
  procedure loadmemory(
    variable octets:        out  octet_vector;
    constant size:          in   integer;
    constant address:       in   std_logic_vector(31 downto 0);
    constant screen:        in   boolean := false;
    constant bank:          in   integer := 0;
    signal   dbgi:          out  at_slv_dbg_in_type;
    signal   dbgo:          in   at_slv_dbg_out_type);
  
end package at_util;

package body at_util is
  procedure comparemem(
    constant address:  in    std_logic_vector(31 downto 0);
    constant size:     in    integer;
    constant data:     in    octet_vector;
    constant screen:   in    boolean;
    variable tp:       inout boolean;
    signal   atmi:     out   at_ahb_mst_in_type;
    signal   atmo:     in    at_ahb_mst_out_type) is
    variable count:          integer := 0;
    variable temp:           std_logic_vector(31 downto 0);
    variable failed:         boolean := true;
    variable equal:          boolean := true;
    variable addr:           std_logic_vector(31 downto 0);
  begin
    if size /= 0 then
      addr := address(31 downto 2) & "00"; 
      if address(1 downto 0) /= "00" then
        case address(1 downto 0) is
          when "01" =>
            at_read_32(addr, 0, false, "0011", true, screen, temp, atmi, atmo);
            case size is
              when 1 =>
                 equal := compare(data(0), temp(23 downto 16));
                 count := count + 1;
              when 2 =>
                 equal := compare(data(0), temp(23 downto 16)) and
                          compare(data(1), temp(15 downto 8));
                 count := count + 2;
              when others =>
                 equal := compare(data(0), temp(23 downto 16)) and
                          compare(data(1), temp(15 downto 8))  and
                          compare(data(2), temp(7 downto 0));
                 count := count + 3;
            end case;
            if not equal then
              print("address: " & tost(addr));
            end if;
          when "10" =>
            at_read_32(addr, 0, false, "0011", true, screen, temp, atmi, atmo);
            case size is
              when 1 =>
                 equal := compare(data(0), temp(15 downto 8));
                 count := count + 1;
              when others =>
                 equal := compare(data(0), temp(15 downto 8)) and
                          compare(data(1), temp(7 downto 0));
                 count := count + 2;
            end case;
            if not equal then
              print("address: " & tost(addr));
            end if;
          when "11" =>
            at_read_32(addr, 0, false, "0011", true, screen, temp, atmi, atmo);
            equal := compare(data(0), temp(7 downto 0));
            count := count + 1;
            if not equal then
              print("address: " & tost(addr));
            end if;
          when others =>
            null;
        end case;
        addr := addr + 4;
      end if;
      while count < size loop
        at_read_32(addr, 0, false, "0011", true, screen, temp, atmi, atmo);
        for i in 0 to 3 loop
          if count < size then
            equal := equal and compare(temp(31-i*8 downto 24-i*8), data(count));
            if not compare(temp(31-i*8 downto 24-i*8), data(count)) then
              print("data: " & tost(temp(31-i*8 downto 24-i*8)) & "expected: " & tost(data(count)));
              print("address: " & tost(addr));
            end if;
          end if;
          count := count + 1;
        end loop;
        addr := addr + 4;
      end loop;
      if not equal then
        print("compare error");
        tp := false; 
      end if;
    else
      print("size is zero. no compare done");
    end if;
  end procedure;

  procedure comparemem(
    constant address:  in    std_logic_vector(31 downto 0);
    constant size:     in    integer;
    constant data:     in    octet_vector;
    constant screen:   in    boolean;
    constant bank:     in    integer;
    variable tp:       inout boolean;
    signal   dbgi:     out   at_slv_dbg_in_type;
    signal   dbgo:     in    at_slv_dbg_out_type) is
    variable caddr:          std_logic_vector(31 downto 0);
    variable cnt:            integer;
    variable i:              integer;
    variable tmp:            std_logic_vector(31 downto 0);
    variable tmpv:           octet_vector(data'range);
  begin
    if size /= 0 then
      caddr := address; cnt := size; i := data'low;
      while cnt > 0 loop
        case caddr(1 downto 0) is
          when "00" =>
            if cnt >= 4 then    --word access
              ahbslv_read (caddr, tmp(31 downto 0), bank, dbgi, dbgo);
              tmpv(i) :=   tmp(31 downto 24);
              tmpv(i+1) := tmp(23 downto 16);
              tmpv(i+2) := tmp(15 downto 8);
              tmpv(i+3) := tmp(7 downto 0);
              cnt := cnt - 4; i := i + 4; caddr := caddr + 4;
            elsif cnt >= 2 then --halfword access
              ahbslv_read (caddr, tmp(15 downto 0), bank, dbgi, dbgo);
              tmpv(i) := tmp(15 downto 8);
              tmpv(i+1) := tmp(7 downto 0);
              cnt := cnt - 2; i := i + 2; caddr := caddr + 2;
            else                --byte access
              ahbslv_read (caddr, tmp(7 downto 0), bank, dbgi, dbgo);
              tmpv(i) := tmp(7 downto 0);
              cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
            end if;
          when "01" =>
            ahbslv_read (caddr, tmp(7 downto 0), bank, dbgi, dbgo);
            tmpv(i) := tmp(7 downto 0);
            cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
          when "10" =>
            if cnt >= 2 then --halfword access
              ahbslv_read (caddr, tmp(15 downto 0), bank, dbgi, dbgo);
              tmpv(i) := tmp(15 downto 8);
              tmpv(i+1) := tmp(7 downto 0);
              cnt := cnt - 2; i := i + 2; caddr := caddr + 2;
            else                --byte access
              ahbslv_read (caddr, tmp(7 downto 0), bank, dbgi, dbgo);
              tmpv(i) := tmp(7 downto 0);
              cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
            end if;
          when "11" =>
            ahbslv_read (caddr, tmp(7 downto 0), bank, dbgi, dbgo);
            tmpv(i) := tmp(7 downto 0);
            cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
          when others =>
            null;
        end case;
      end loop;
      if data'ascending then
        compare(tmpv(data'low to data'low+size-1), data(data'low to data'low+size-1), tp);
      else
        compare(tmpv(data'low+size-1 downto data'low), data(data'low+size-1 downto data'low), tp);
      end if;
    else
      print("size is zero. no compare done");
    end if;
  end procedure;
  
  procedure fillmemory(
    constant octets:        in   octet_vector;
    constant size:          in   integer;
    constant address:       in   std_logic_vector(31 downto 0);
    constant screen:        in   boolean := false;
    signal   clk:           in   std_ulogic;
    signal   atmi:          out  at_ahb_mst_in_type;
    signal   atmo:          in   at_ahb_mst_out_type) is
    variable data:               data_vector(0 to (size-1)/4);
    variable addr:               std_logic_vector(31 downto 0);
    variable failed:             boolean := false;
    variable tp:                 boolean;
  begin
    data := conv_data_vector(octets(0 to size-1));
    addr := address;
    for i in 0 to data'length-1 loop
      at_write_32(addr, data(i), 0, false, "0011", true, screen, atmi, atmo);
      addr := addr + 4;
    end loop;
  end fillmemory;
  
  procedure fillmemory(
    constant filename:      in   string := "";
    constant size:          in   integer := 0;
    constant address:       in   std_logic_vector(31 downto 0);
    constant screen:        in   boolean := false;
    signal   clk:           in   std_ulogic;
    signal   atmi:          out  at_ahb_mst_in_type;
    signal   atmo:          in   at_ahb_mst_out_type) is
    variable data:               data_vector(0 to (size-1)/4);
    variable addr:               std_logic_vector(31 downto 0);
    variable tp:                 boolean := false;
  begin
    readfile(filename, size, data);
    addr := address;
    for i in 0 to data'length-1 loop
      at_write_32(addr, data(i), 0, false, "0011", true, screen, atmi, atmo);
      addr := addr + 4;
    end loop;
  end fillmemory;

  procedure fillmemory(
    constant filename:      in   string := ""; 
    constant size:          in   integer;
    constant address:       in   std_logic_vector(31 downto 0);
    constant screen:        in   boolean := false;
    constant bank:          in   integer := 0; 
    signal   dbgi:          out  at_slv_dbg_in_type;
    signal   dbgo:          in   at_slv_dbg_out_type) is
    variable caddr:              std_logic_vector(31 downto 0);
    variable cnt:                integer;
    variable i:                  integer;
    variable data:               octet_vector(0 to size-1);
    variable tmp:                std_logic_vector(31 downto 0);
  begin
    readfile(filename, size, data);
    caddr := address; cnt := size; i := data'low;
    while cnt > 0 loop
      case caddr(1 downto 0) is
        when "00" =>
          if cnt >= 4 then    --word access
            tmp := data(i) & data(i+1) & data(i+2) & data(i+3);
            ahbslv_write (caddr, tmp, bank, dbgi, dbgo);
            cnt := cnt - 4; i := i + 4; caddr := caddr + 4;
          elsif cnt >= 2 then --halfword access
            tmp(15 downto 0) := data(i) & data(i+1);
            ahbslv_write (caddr, tmp(15 downto 0), bank, dbgi, dbgo);
            cnt := cnt - 2; i := i + 2; caddr := caddr + 2;
          else                --byte access
            tmp(7 downto 0) := data(i);
            ahbslv_write (caddr, tmp(7 downto 0), bank, dbgi, dbgo);
            cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
          end if;
        when "01" =>
          tmp(7 downto 0) := data(i);
          ahbslv_write (caddr, tmp(7 downto 0), bank, dbgi, dbgo);
          cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
        when "10" =>
          if cnt >= 2 then --halfword access
            tmp(15 downto 0) := data(i) & data(i+1);
            ahbslv_write (caddr, tmp(15 downto 0), bank, dbgi, dbgo);
            cnt := cnt - 2; i := i + 2; caddr := caddr + 2;
          else                --byte access
            tmp(7 downto 0) := data(i);
            ahbslv_write (caddr, tmp(7 downto 0), bank, dbgi, dbgo);
            cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
          end if;
        when "11" =>
          tmp(7 downto 0) := data(i);
          ahbslv_write (caddr, tmp(7 downto 0), bank, dbgi, dbgo);
          cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
        when others =>
          null;
      end case;
    end loop;
  end fillmemory;
  
  procedure fillmemory(
    constant octets:        in   octet_vector;
    constant size:          in   integer;
    constant address:       in   std_logic_vector(31 downto 0);
    constant screen:        in   boolean := false;
    constant bank:          in   integer := 0; 
    signal   dbgi:          out  at_slv_dbg_in_type;
    signal   dbgo:          in   at_slv_dbg_out_type) is
    variable caddr:              std_logic_vector(31 downto 0);
    variable cnt:                integer;
    variable i:                  integer;
    variable data:               std_logic_vector(31 downto 0);
  begin
    caddr := address; cnt := size;  i := octets'low;
    while cnt > 0 loop
      case caddr(1 downto 0) is
        when "00" =>
          if cnt >= 4 then    --word access
            data := octets(i) & octets(i+1) & octets(i+2) & octets(i+3);
            ahbslv_write (caddr, data, bank, dbgi, dbgo);
            cnt := cnt - 4; i := i + 4; caddr := caddr + 4;
          elsif cnt >= 2 then --halfword access
            data(15 downto 0) := octets(i) & octets(i+1);
            ahbslv_write (caddr, data(15 downto 0), bank, dbgi, dbgo);
            cnt := cnt - 2; i := i + 2; caddr := caddr + 2;
          else                --byte access
            data(7 downto 0) := octets(i);
            ahbslv_write (caddr, data(7 downto 0), bank, dbgi, dbgo);
            cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
          end if;
        when "01" =>
          data(7 downto 0) := octets(i);
          ahbslv_write (caddr, data(7 downto 0), bank, dbgi, dbgo);
          cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
        when "10" =>
          if cnt >= 2 then --halfword access
            data(15 downto 0) := octets(i) & octets(i+1);
            ahbslv_write (caddr, data(15 downto 0), bank, dbgi, dbgo);
            cnt := cnt - 2; i := i + 2; caddr := caddr + 2;
          else                --byte access
            data(7 downto 0) := octets(i);
            ahbslv_write (caddr, data(7 downto 0), bank, dbgi, dbgo);
            cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
          end if;
        when "11" =>
          data(7 downto 0) := octets(i);
          ahbslv_write (caddr, data(7 downto 0), bank, dbgi, dbgo);
          cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
        when others =>
          null;
      end case;
    end loop;
  end fillmemory;

  procedure loadmemory(
    variable octets:        out  octet_vector;
    constant size:          in   integer;
    constant address:       in   std_logic_vector(31 downto 0);
    constant screen:        in   boolean := false;
    constant bank:          in   integer := 0;
    signal   dbgi:          out  at_slv_dbg_in_type;
    signal   dbgo:          in   at_slv_dbg_out_type) is
    variable caddr:              std_logic_vector(31 downto 0);
    variable cnt:                integer;
    variable i:                  integer;
    variable data:               std_logic_vector(31 downto 0);
  begin
    caddr := address; cnt := size;  i := octets'low;
    while cnt > 0 loop
      case caddr(1 downto 0) is
        when "00" =>
          if cnt >= 4 then    --word access
            ahbslv_read (caddr, data, bank, dbgi, dbgo);
            for j in 0 to 3 loop
              octets(i+j) := data(31-8*j downto 24-8*j);
            end loop;
            cnt := cnt - 4; i := i + 4; caddr := caddr + 4;
          elsif cnt >= 2 then --halfword access
            ahbslv_read (caddr, data(15 downto 0), bank, dbgi, dbgo);
            for j in 0 to 1 loop
              octets(i+j) := data(15-8*j downto 8-8*j);
            end loop;
            cnt := cnt - 2; i := i + 2; caddr := caddr + 2;
          else                --byte access
            ahbslv_read (caddr, data(7 downto 0), bank, dbgi, dbgo);
            octets(i) := data(7 downto 0);
            cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
          end if;
        when "01" =>
          ahbslv_read (caddr, data(7 downto 0), bank, dbgi, dbgo);
          octets(i) := data(7 downto 0); 
          cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
        when "10" =>
          if cnt >= 2 then --halfword access
            ahbslv_read (caddr, data(15 downto 0), bank, dbgi, dbgo);
            for j in 0 to 1 loop
              octets(i+j) := data(15-8*j downto 8-8*j);
            end loop;
            cnt := cnt - 2; i := i + 2; caddr := caddr + 2;
          else                --byte access
            ahbslv_read (caddr, data(7 downto 0), bank, dbgi, dbgo);
            octets(i) := data(7 downto 0);
            cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
          end if;
        when "11" =>
          ahbslv_read (caddr, data(7 downto 0), bank, dbgi, dbgo);
          octets(i) := data(7 downto 0);
          cnt := cnt - 1; i := i + 1; caddr := caddr + 1;
        when others =>
          null;
      end case;
    end loop;
  end procedure;
end package body at_util;

