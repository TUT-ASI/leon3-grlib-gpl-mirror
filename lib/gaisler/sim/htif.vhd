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
-------------------------------------------------------------------------------
-- Entity:      htif
-- File:        htif.vhd
-- Author:      Jonathan Jonsson, Frontgrade Gaisler AB
-- Description: Simulation RISC-V HTIF module
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library gaisler;
use gaisler.sim.all;

library grlib;
use grlib.stdlib.all;

-- Entity for the RISC-V HTIF simulation interface
entity htif_sim is
    generic (
      dbg           : boolean := false;
      dev_cmd_width : integer := 8;
      data_width    : integer := 64;
      addr_width    : integer := 32;
      tohost_addr   : std_logic_vector(63 downto 0);
      fromhost_addr : std_logic_vector(63 downto 0)
    );
    port (
      clk   : in std_logic;
      addr  : in std_logic_vector(addr_width - 1 downto 0);
      data  : in std_logic_vector(data_width - 1 downto 0);
      size  : in std_logic_vector(2 downto 0);
      valid : in std_logic;
      rw    : in std_logic;
      id    : in std_logic_vector(3 downto 0)
    );
  end htif_sim;



architecture rtl of htif_sim is
  subtype arg_type     is unsigned(data_width - 1    downto 0);
  subtype dev_cmd_type is unsigned(dev_cmd_width - 1 downto 0);
  subtype addr_type    is unsigned(addr_width - 1    downto 0);

  -- Constants for device and command codes
  constant DEVICE_SYSCALL      : dev_cmd_type := "00000000"; -- Device 0
  constant COMMAND_SYSCALL     : dev_cmd_type := "00000000"; -- Command 0 for syscall device
  constant DEVICE_CHAR         : dev_cmd_type := "00000001"; -- Device 1
  constant COMMAND_WRITE_CHAR  : dev_cmd_type := "00000001"; -- Write character command


  function is_tohost(addr : addr_type; valid : std_logic; rw : std_logic) return boolean is
  begin
    return addr = unsigned(tohost_addr(addr'range)) and valid = '1' and rw = '1';
  end function;

  -- Place holder for function which has direct access to simulated memory
  function read_mem(addr : unsigned(63 downto 0); size : integer) return unsigned is
    variable ret : unsigned(size - 1 downto 0) := (others => '1');
  begin
    report "Place holder for read_mem" severity note;
    -- return read(addr, size);
    return ret;
  end function read_mem;

  function tost(v : unsigned) return string is
  begin
-- pragma translate_off
    return tost(std_logic_vector(v));
-- pragma translate_on
    return "";
  end;

  procedure log_debug(str : string) is
  begin
    if (dbg) then
      print("HTIF DBG: " & str);
    end if;
  end procedure;

begin
  -- pragma translate_off
  process(clk)
    variable htif_req     : unsigned(data_width - 1 downto 0);
    variable exit_code    : unsigned(47 downto 1);
    variable has_ptr      : boolean      := false;
    variable device       : dev_cmd_type := (others => '0');
    variable command      : dev_cmd_type := (others => '0');
    variable is_exit_code : boolean;   -- Bit 1 of syscall data to distinguish sys_exit
    variable char_output  : character; -- Single character output
    -- SYSCALL related
    variable which     : unsigned(63 downto 0);
    variable magic_mem : arg_type;
    variable arg0      : arg_type;
    variable arg1      : arg_type;
    variable arg2      : arg_type;
    -- For SYS_WRITE
    constant BUFSIZE   : integer              := 257;
    variable text_buf  : string(1 to BUFSIZE) := (others => NUL);
    variable i         : integer range 1 to BUFSIZE := 1;
    variable len       : integer := 0;
    variable newline   : boolean := false;
    variable buf       : unsigned(arg1'range); -- pointer to buffer position

    -- MISC
    variable conts     : string(1 to 9);

    -- SYSCALL codes
    constant SYS_WRITE : unsigned(63 downto 0) := to_unsigned(64, 64);

  begin
    if valid = '1' and rising_edge(clk) then
      log_debug("mem_trace addr = " & tost(addr) & " data = " & tost(data));
    end if;
    if rising_edge(clk) and is_tohost(addr_type(addr), valid, rw) then
      assert (unsigned(size) = "011") report "HTIF currently only supports 64-bit writes" severity warning;
      -- Decode device, command, and subfunction
      htif_req     := unsigned(data);
      device       := htif_req(63 downto 56);
      command      := htif_req(55 downto 48);
      is_exit_code := htif_req(0) = '1';

      log_debug("htif_req " & tost(htif_req) & " device = " & tost(device) & " cmd = " & tost(command));

      -- Handle syscall device (device 0, command 0)
      if (device = DEVICE_SYSCALL) and (command = COMMAND_SYSCALL) then
        if is_exit_code then
          exit_code := unsigned(htif_req(47 downto 1));  -- Exit code in bits 47:1
          assert false report "Exit code: " & tost(exit_code) severity failure;
        else -- syscall
          magic_mem := htif_req;
          which     := read_mem(magic_mem, 64);
          arg0      := read_mem(magic_mem + 8, 64);
          arg1      := read_mem(magic_mem + 16, 64);
          arg2      := read_mem(magic_mem + 24, 64);
          log_debug("GOT SYSCALL: which = " & tost(which));
          if which = SYS_WRITE then
            -- GRLIB_INTERNAL_BEGIN
            -- I need some way to access memory through a backdoor to be able to implement syscalls.
            -- GRLIB_INTERNAL_END
            assert false report "Not yet supported or tested" severity failure;
            buf     := arg1;
            len     := to_integer(unsigned(arg2));
            newline := false;
            while (len /= 0) loop
              i := 1; -- reset index
              while (i <= len and (i <= BUFSIZE)) loop
                text_buf(i) := character'val(to_integer(unsigned(read_mem(buf, 8))));
                buf := buf + 1; -- Pointer arithmetic
                if not newline then
                  newline := text_buf(i) = LF or text_buf(i) = CR;
                end if;

                i := i + 1;
                len := len - 1;
              end loop;
              text_buf(i) := NUL;
            end loop;
          else
            report "Unsupported  SYSCALL " & tost(which) severity warning;
          end if;
        end if;

      -- Handle character device (device 1)
      elsif (device = DEVICE_CHAR) then
        conts := "         ";
        if command = COMMAND_WRITE_CHAR then
          -- 8 LSBs contains the char written
          char_output := character'val(to_integer(htif_req(7 downto 0)));
          newline     := char_output = LF or char_output = CR;
          log_debug("Output Character: " & char_output & "; i = " & tost(i));

          -- Give some indication that a line wasn't finished, due to buffer size
          if i = BUFSIZE - 1 and not newline then
            conts := " (conts) ";
            log_debug("Setting conts: " & conts);
          end if;

          -- Buffer full, dump it, don't add CR/LF to text_buf since print adds newline on its own.
          if i = BUFSIZE - 1 or newline then
            -- null terminate the line, i already incremented and one position left for nul
            text_buf(i) := NUL;
            -- print the buffer and restore counter
            print("htif: " & text_buf(1 to i) & conts);
            i := 1;
          else
            log_debug("Added character '" & char_output & "' to pos(" & tost(i) & ")");
            text_buf(i) := char_output;
            i := i + 1;
          end if;
        else
          report "Can't handle blocking HTIF input request" severity warning;
        end if;
      end if;
    end if;
  end process;
  -- pragma translate_on
end rtl;
