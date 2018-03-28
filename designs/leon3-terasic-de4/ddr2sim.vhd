------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
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

use std.textio.all;
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.all;
use grlib.stdio.all;

entity ddr2ctrl is
  port (
    pll_ref_clk        : in    std_logic                      := '0';             --      pll_ref_clk.clk
    global_reset_n     : in    std_logic                      := '0';             --     global_reset.reset_n
    soft_reset_n       : in    std_logic                      := '0';             --       soft_reset.reset_n
    afi_clk            : out   std_logic;                                         --          afi_clk.clk
    afi_half_clk       : out   std_logic;                                         --     afi_half_clk.clk
    afi_reset_n        : out   std_logic;                                         --        afi_reset.reset_n
    afi_reset_export_n : out   std_logic;                                         -- afi_reset_export.reset_n
    mem_a              : out   std_logic_vector(13 downto 0);                     --           memory.mem_a
    mem_ba             : out   std_logic_vector(2 downto 0);                      --                 .mem_ba
    mem_ck             : out   std_logic_vector(1 downto 0);                      --                 .mem_ck
    mem_ck_n           : out   std_logic_vector(1 downto 0);                      --                 .mem_ck_n
    mem_cke            : out   std_logic_vector(0 downto 0);                      --                 .mem_cke
    mem_cs_n           : out   std_logic_vector(0 downto 0);                      --                 .mem_cs_n
    mem_dm             : out   std_logic_vector(7 downto 0);                      --                 .mem_dm
    mem_ras_n          : out   std_logic_vector(0 downto 0);                      --                 .mem_ras_n
    mem_cas_n          : out   std_logic_vector(0 downto 0);                      --                 .mem_cas_n
    mem_we_n           : out   std_logic_vector(0 downto 0);                      --                 .mem_we_n
    mem_dq             : inout std_logic_vector(63 downto 0)  := (others => '0'); --                 .mem_dq
    mem_dqs            : inout std_logic_vector(7 downto 0)   := (others => '0'); --                 .mem_dqs
    mem_dqs_n          : inout std_logic_vector(7 downto 0)   := (others => '0'); --                 .mem_dqs_n
    mem_odt            : out   std_logic_vector(0 downto 0);                      --                 .mem_odt
    avl_ready          : out   std_logic;                                         --              avl.waitrequest_n
    avl_burstbegin     : in    std_logic                      := '0';             --                 .beginbursttransfer
    avl_addr           : in    std_logic_vector(24 downto 0)  := (others => '0'); --                 .address
    avl_rdata_valid    : out   std_logic;                                         --                 .readdatavalid
    avl_rdata          : out   std_logic_vector(255 downto 0);                    --                 .readdata
    avl_wdata          : in    std_logic_vector(255 downto 0) := (others => '0'); --                 .writedata
    avl_be             : in    std_logic_vector(31 downto 0)  := (others => '0'); --                 .byteenable
    avl_read_req       : in    std_logic                      := '0';             --                 .read
    avl_write_req      : in    std_logic                      := '0';             --                 .write
    avl_size           : in    std_logic_vector(3 downto 0)   := (others => '0'); --                 .burstcount
    local_init_done    : out   std_logic;                                         --           status.local_init_done
    local_cal_success  : out   std_logic;                                         --                 .local_cal_success
    local_cal_fail     : out   std_logic;                                         --                 .local_cal_fail
    oct_rdn            : in    std_logic                      := '0';             --              oct.rdn
    oct_rup            : in    std_logic                      := '0'              --                 .rup
  );
end ddr2ctrl;

architecture sim of ddr2ctrl is

  signal lafi_clk, lafi_rst_n: std_ulogic;
  signal lafi_half_clk: std_ulogic;
  
begin

  afi_clk <= lafi_clk;
  afi_half_clk <= lafi_half_clk;
  afi_reset_n <= lafi_rst_n;
  
  mem_a <= (others => '0');
  mem_ba <= (others => '0');
  mem_ck <= (others => '0');
  mem_ck_n <= (others => '1');
  mem_cke <= (others => '0');
  mem_cs_n <= (others => '1');
  mem_dm <= (others => '0');
  mem_ras_n <= (others => '1');
  mem_cas_n <= (others => '1');
  mem_we_n <= (others => '1');
  mem_dq <= (others => 'Z');
  mem_dqs <= (others => 'Z');
  mem_dqs_n <= (others => 'Z');
  mem_odt <= (others => '0');

  avl_ready <= '1';
  local_init_done <= '1';
  local_cal_success <= '1';
  local_cal_fail <= '0';

  -- 200 MHz clock
  clkproc: process
  begin
    lafi_clk <= '0';
    lafi_half_clk <= '0';
    loop
      wait for 2.5 ns;
      lafi_clk <= not lafi_clk;
      if lafi_clk='0' then
        lafi_half_clk <= not lafi_half_clk;
      end if;
    end loop;
  end process;

  rstproc: process
  begin
    lafi_rst_n <= '0';
    wait for 10 ns;
    loop
      if global_reset_n='0' then
        lafi_rst_n <= '0';
        wait until global_reset_n/='0';
        wait until rising_edge(lafi_clk);
      end if;
      lafi_rst_n <= '1';
      wait until global_reset_n='0';
    end loop;
  end process;

  avlproc: process
    subtype BYTE is std_logic_vector(7 downto 0);
    type MEM is array(0 to ((2**20)-1)) of BYTE;
    variable MEMA: MEM;

    procedure load_srec is
      file TCF : text open read_mode is "ram.srec";
      variable L1: line;
      variable CH: character;
      variable ai: integer;
      variable rectype: std_logic_vector(3 downto 0);
      variable recaddr: std_logic_vector(31 downto 0);
      variable reclen: std_logic_vector(7 downto 0);
      variable recdata: std_logic_vector(0 to 16*8-1);
      variable len: integer;
    begin
      L1:= new string'("");     --'
      while not endfile(TCF) loop
        readline(TCF,L1);
        if (L1'length /= 0) then        --'
          while (not (L1'length=0)) and (L1(L1'left) = ' ') loop
            std.textio.read(L1,CH);
          end loop;
          if L1'length > 0 then --'
            read(L1, ch);
            if (ch = 'S') or (ch = 's') then
              hread(L1, rectype);
              hread(L1, reclen);
              len := conv_integer(reclen)-1;
              recaddr := (others => '0');
              case rectype is
                when "0001" =>
                  hread(L1, recaddr(15 downto 0));
                  len := len-2;
                when "0010" =>
                  hread(L1, recaddr(23 downto 0));
                  len := len-3;
                when "0011" =>
                  hread(L1, recaddr);
                  len := len-4;
                when others => next;
              end case;
              hread(L1, recdata(0 to 8*len-1));
              recaddr(31 downto 20) := (others => '0');
              ai := conv_integer(recaddr);
              -- print("Setting " & tost(len) & "bytes at " & tost(recaddr));
              for i in 0 to len-1 loop
                MEMA(ai+i) := recdata((i*8) to (i*8+7));
              end loop;
            end if;
          end if;
        end if;
      end loop;
    end load_srec;

    constant avldbits: integer := 256;
    variable outqueue: std_logic_vector(0 to 4*avldbits-1) := (others => 'X');
    variable outqueue_valid: std_logic_vector(0 to 3) := (others => '0');
    variable ai,p: integer;
    variable wbleft: integer := 0;
  begin
    load_srec;
    loop
      wait until rising_edge(lafi_clk);
      avl_rdata_valid <= outqueue_valid(0);
      avl_rdata <= outqueue(0 to avldbits-1);
      outqueue(0 to 3*avldbits-1) := outqueue(avldbits to 4*avldbits-1);
      outqueue(3*avldbits to 4*avldbits-1) := (others => 'X');
      outqueue_valid := outqueue_valid(1 to 3) & '0';
      if avl_burstbegin='1' then wbleft:=0; end if;
      if lafi_rst_n='0' then
        outqueue_valid := (others => '0');
      elsif avl_read_req='1' then
        ai := conv_integer(avl_addr(16 downto 0));
        p := 0;
        while outqueue_valid(p)='1' loop p:=p+1; end loop;
        for x in 0 to conv_integer(avl_size)-1 loop
          for y in 0 to avldbits/8-1 loop
            outqueue((p+x)*avldbits+y*8 to (p+x)*avldbits+y*8+7) := MEMA((ai+x)*avldbits/8+y);
          end loop;
          outqueue_valid(p+x) := '1';
        end loop;
      elsif avl_write_req='1' then
        if wbleft=0 then
          wbleft := conv_integer(avl_size);
          ai := conv_integer(avl_addr(16 downto 0));
        end if;
        for y in 0 to avldbits/8-1 loop
          if avl_be(avldbits/8-1-y)='1' then
            MEMA(ai*avldbits/8+y) := avl_wdata(avldbits-8*y-1 downto avldbits-8*y-8);
          end if;
        end loop;
        wbleft := wbleft-1;
        ai := ai+1;
      end if;
    end loop;
  end process;
end;
