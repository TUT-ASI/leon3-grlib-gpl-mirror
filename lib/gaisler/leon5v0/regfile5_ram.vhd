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
library techmap;
use techmap.gencomp.all;
use techmap.allmem.all;
library gaisler;
use gaisler.leon5int.all;
use gaisler.cpucore5int.all;

entity regfile5_ram is
  generic (
    tech    : integer;
    abits   : integer;
    dbits   : integer;
    wrfst   : integer;
    numregs : integer;
    g0addr  : integer;
    rfconf  : integer;
    testen  : integer
    );
  port (
    clk      : in  std_logic;
    rstn     : in  std_logic;
    rdhold   : in  std_logic;
    waddr1   : in  std_logic_vector((abits -1) downto 0);
    wdata1   : in  std_logic_vector((dbits -1) downto 0);
    we1      : in  std_logic_vector(1 downto 0);
    waddr2   : in  std_logic_vector((abits -1) downto 0);
    wdata2   : in  std_logic_vector((dbits -1) downto 0);
    we2      : in  std_logic_vector(1 downto 0);
    raddr1   : in  std_logic_vector((abits -1) downto 0);
    re1      : in  std_logic_vector(1 downto 0);
    rgz1     : in  std_logic;
    rdata1   : out std_logic_vector((dbits -1) downto 0);
    raddr2   : in  std_logic_vector((abits -1) downto 0);
    re2      : in  std_logic_vector(1 downto 0);
    rgz2     : in  std_logic;
    rdata2   : out std_logic_vector((dbits -1) downto 0);
    raddr3   : in  std_logic_vector((abits -1) downto 0);
    re3      : in  std_logic_vector(1 downto 0);
    rgz3     : in  std_logic;
    rdata3   : out std_logic_vector((dbits -1) downto 0);
    raddr4   : in  std_logic_vector((abits -1) downto 0);
    re4      : in  std_logic_vector(1 downto 0);
    rgz4     : in  std_logic;
    rdata4   : out std_logic_vector((dbits -1) downto 0);
    testin   : in  std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
    );
end regfile5_ram;


architecture rtl of regfile5_ram is


  type lwrite_type is array (0 to 2**abits-1) of std_logic_vector(1 downto 0);

  type reg_type is record
    lwrite : lwrite_type;
    raddr1 : std_logic_vector((abits -1) downto 0);
    raddr2 : std_logic_vector((abits -1) downto 0);
    raddr3 : std_logic_vector((abits -1) downto 0);
    raddr4 : std_logic_vector((abits -1) downto 0);
    waddr1 : std_logic_vector((abits -1) downto 0);
    waddr2 : std_logic_vector((abits -1) downto 0);
    holddata1 : std_logic_vector(dbits-1 downto 0);
    holddata2 : std_logic_vector(dbits-1 downto 0);
    holddata3 : std_logic_vector(dbits-1 downto 0);
    holddata4 : std_logic_vector(dbits-1 downto 0);
    port1_wf : std_logic_vector(1 downto 0);
    port2_wf : std_logic_vector(1 downto 0);
    port3_wf : std_logic_vector(1 downto 0);
    port4_wf : std_logic_vector(1 downto 0);
  end record;

  constant reg_type_reset : reg_type := (
    lwrite => (others=>(others=>'0')),
    raddr1 => (others => '0'),
    raddr2 => (others => '0'),
    raddr3 => (others => '0'),
    raddr4 => (others => '0'),
    waddr1 => (others => '0'),
    waddr2 => (others => '0'),
    holddata1 => (others=>'0'),
    holddata2 => (others=>'0'),
    holddata3 => (others=> '0'),
    holddata4 => (others=> '0'),
    port1_wf => "00",
    port2_wf => "00",
    port3_wf => "00",
    port4_wf => "00"
    );

  signal rdata10, rdata11, rdata12, rdata13 : std_logic_vector(31 downto 0);
  signal rdata20, rdata21, rdata22, rdata23 : std_logic_vector(31 downto 0);
  signal rdata30, rdata31, rdata32, rdata33 : std_logic_vector(31 downto 0);
  signal rdata40, rdata41, rdata42, rdata43 : std_logic_vector(31 downto 0);
 
  signal r, rin : reg_type;

  signal re1_masked, re2_masked, re3_masked, re4_masked : std_logic_vector(1 downto 0);
begin  -- rtl

  --PORT1
  x00 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen,0,1)
    port map (clk, re1_masked(0), raddr1, rdata10(31 downto 0), clk, we1(0), waddr1, wdata1(63 downto 32), testin
              );

  x01 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re1_masked(0), raddr1, rdata11(31 downto 0), clk, we2(0), waddr2, wdata2(63 downto 32), testin
              );

  x02 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re1_masked(1), raddr1, rdata12(31 downto 0), clk, we1(1), waddr1, wdata1(31 downto 0), testin
              );

  x03 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re1_masked(1), raddr1, rdata13(31 downto 0), clk, we2(1), waddr2, wdata2(31 downto 0), testin
              );


  --PORT2
  x10 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re2_masked(0), raddr2, rdata20(31 downto 0), clk, we1(0), waddr1, wdata1(63 downto 32), testin
              );

  x11 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re2_masked(0), raddr2, rdata21(31 downto 0), clk, we2(0), waddr2, wdata2(63 downto 32), testin
              );

  x12 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re2_masked(1), raddr2, rdata22(31 downto 0), clk, we1(1), waddr1, wdata1(31 downto 0), testin
              );

  x13 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re2_masked(1), raddr2, rdata23(31 downto 0), clk, we2(1), waddr2, wdata2(31 downto 0), testin
              );

  --PORT3
  x20 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re3_masked(0), raddr3, rdata30(31 downto 0), clk, we1(0), waddr1, wdata1(63 downto 32), testin
              );

  x21 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re3_masked(0), raddr3, rdata31(31 downto 0), clk, we2(0), waddr2, wdata2(63 downto 32), testin
              );

  x22 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re3_masked(1), raddr3, rdata32(31 downto 0), clk, we1(1), waddr1, wdata1(31 downto 0), testin
              );

  x23 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re3_masked(1), raddr3, rdata33(31 downto 0), clk, we2(1), waddr2, wdata2(31 downto 0), testin
              );

  --PORT4
  x30 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re4_masked(0), raddr4, rdata40(31 downto 0), clk, we1(0), waddr1, wdata1(63 downto 32), testin
              );

  x31 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re4_masked(0), raddr4, rdata41(31 downto 0), clk, we2(0), waddr2, wdata2(63 downto 32), testin
              );

  x32 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re4_masked(1), raddr4, rdata42(31 downto 0), clk, we1(1), waddr1, wdata1(31 downto 0), testin
              );

  x33 : syncram_2p generic map (tech, abits, dbits/2, 0, wrfst, testen, 0, memtest_vlen, 0, 1)
    port map (clk, re4_masked(1), raddr4, rdata43(31 downto 0), clk, we2(1), waddr2, wdata2(31 downto 0), testin
              );

  comb : process(rstn, r, we1, we2, waddr1, waddr2, wdata1, wdata2,
                 raddr1, raddr2, raddr3, raddr4,
                 re1, re2, re3, re4, rdhold,
                 rdata10, rdata11, rdata12, rdata13,
                 rdata20, rdata21, rdata22, rdata23,
                 rdata30, rdata31, rdata32, rdata33,
                 rdata40, rdata41, rdata42, rdata43)
    variable v       : reg_type;
    variable rdata1v : std_logic_vector(dbits-1 downto 0);
    variable rdata2v : std_logic_vector(dbits-1 downto 0);
    variable rdata3v : std_logic_vector(dbits-1 downto 0);
    variable rdata4v : std_logic_vector(dbits-1 downto 0);
    variable forw_rdata1v : std_logic_vector(dbits-1 downto 0);
    variable forw_rdata2v : std_logic_vector(dbits-1 downto 0);
    variable forw_rdata3v : std_logic_vector(dbits-1 downto 0);
    variable forw_rdata4v : std_logic_vector(dbits-1 downto 0);
    variable forw_sel1 : std_logic_vector(1 downto 0);
    variable forw_sel2 : std_logic_vector(1 downto 0);
    variable forw_sel3 : std_logic_vector(1 downto 0);
    variable forw_sel4 : std_logic_vector(1 downto 0);
  begin

    v := r;

    if rdhold = '0' then
      v.port1_wf := "00";
      v.port2_wf := "00";
      v.port3_wf := "00";
      v.port4_wf := "00";
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
      v.lwrite(to_integer(unsigned(waddr1)))(0) := '0';
    end if;

    if we2(0) = '1' then
      v.lwrite(to_integer(unsigned(waddr2)))(0) := '1';
    end if;

    if we1(1) = '1' then
      v.lwrite(to_integer(unsigned(waddr1)))(1) := '0';
    end if;

    if we2(1) = '1' then
      v.lwrite(to_integer(unsigned(waddr2)))(1) := '1';
    end if;

    rdata1v(63 downto 32) := rdata10;
    if notx(r.raddr1) then
      if r.lwrite(to_integer(unsigned(r.raddr1)))(0) = '1' then
        rdata1v(63 downto 32) := rdata11;
      end if;
    else
      setx(rdata1v(63 downto 32));
    end if;

    rdata1v(31 downto 0) := rdata12;
    if notx(r.raddr1) then
      if r.lwrite(to_integer(unsigned(r.raddr1)))(1) = '1' then
        rdata1v(31 downto 0) := rdata13;
      end if;
    else
      setx(rdata1v(31 downto 0));
    end if;

    rdata2v(63 downto 32) := rdata20;
    if notx(r.raddr2) then
      if r.lwrite(to_integer(unsigned(r.raddr2)))(0) = '1' then
        rdata2v(63 downto 32) := rdata21;
      end if;
    else
      setx(rdata2v(63 downto 32));
    end if;

    rdata2v(31 downto 0) := rdata22;
    if notx(r.raddr2) then
      if r.lwrite(to_integer(unsigned(r.raddr2)))(1) = '1' then
        rdata2v(31 downto 0) := rdata23;
      end if;
    else
      setx(rdata2v(31 downto 0));
    end if;

    rdata3v(63 downto 32) := rdata30;
    if notx(r.raddr3) then
      if r.lwrite(to_integer(unsigned(r.raddr3)))(0) = '1' then
        rdata3v(63 downto 32) := rdata31;
      end if;
    else
      setx(rdata3v(63 downto 32));
    end if;

    rdata3v(31 downto 0) := rdata32;
    if notx(r.raddr3) then
      if r.lwrite(to_integer(unsigned(r.raddr3)))(1) = '1' then
        rdata3v(31 downto 0) := rdata33;
      end if;
    else
      setx(rdata3v(31 downto 0));
    end if;

    rdata4v(63 downto 32) := rdata40;
    if notx(r.raddr4) then
      if r.lwrite(to_integer(unsigned(r.raddr4)))(0) = '1' then
        rdata4v(63 downto 32) := rdata41;
      end if;
    else
      setx(rdata4v(63 downto 32));
    end if;

    rdata4v(31 downto 0) := rdata42;
    if notx(r.raddr4) then
      if r.lwrite(to_integer(unsigned(r.raddr4)))(1) = '1' then
        rdata4v(31 downto 0) := rdata43;
      end if;
    else
      setx(rdata4v(31 downto 0));
    end if;

    ---------------------------------------------------------------------------
    --PORT1--
    if we1(0) = '1' and rdhold = '0' then
      if waddr1 = raddr1 then
        v.port1_wf(0) := '1';
        v.holddata1(63 downto 32) := wdata1(63 downto 32);
      end if;
    end if;
    if we1(0) = '1' and rdhold = '1' then
      if waddr1 = r.raddr1 then
        v.port1_wf(0) := '1';
        v.holddata1(63 downto 32) := wdata1(63 downto 32);
      end if;
    end if;
    if we1(1) = '1' and rdhold = '0' then
      if waddr1 = raddr1 then
        v.port1_wf(1) := '1';
        v.holddata1(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;
    if we1(1) = '1' and rdhold = '1' then
      if waddr1 = r.raddr1 then
        v.port1_wf(1) := '1';
        v.holddata1(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;   
    if we2(0) = '1' and rdhold = '0' then
      if waddr2 = raddr1 then
        v.port1_wf(0) := '1';
        v.holddata1(63 downto 32) := wdata2(63 downto 32);
      end if;
    end if;
    if we2(0) = '1' and rdhold = '1' then
      if waddr2 = r.raddr1 then
        v.port1_wf(0) := '1';
        v.holddata1(63 downto 32) := wdata2(63 downto 32);
      end if;
    end if;
    if we2(1) = '1' and rdhold = '0' then
      if waddr2 = raddr1 then
        v.port1_wf(1) := '1';
        v.holddata1(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;
    if we2(1) = '1' and rdhold = '1' then
      if waddr2 = r.raddr1 then
        v.port1_wf(1) := '1';
        v.holddata1(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;
    --PORT2----
    if we1(0) = '1' and rdhold = '0' then
      if waddr1 = raddr2 then
        v.port2_wf(0) := '1';
        v.holddata2(63 downto 32) := wdata1(63 downto 32);
      end if;
    end if;
    if we1(0) = '1' and rdhold = '1' then
      if waddr1 = r.raddr2 then
        v.port2_wf(0) := '1';
        v.holddata2(63 downto 32) := wdata1(63 downto 32);
      end if;
    end if;
    if we1(1) = '1' and rdhold = '0' then
      if waddr1 = raddr2 then
        v.port2_wf(1) := '1';
        v.holddata2(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;
    if we1(1) = '1' and rdhold = '1' then
      if waddr1 = r.raddr2 then
        v.port2_wf(1) := '1';
        v.holddata2(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;   
    if we2(0) = '1' and rdhold = '0' then
      if waddr2 = raddr2 then
        v.port2_wf(0) := '1';
        v.holddata2(63 downto 32) := wdata2(63 downto 32);
      end if;
    end if;
    if we2(0) = '1' and rdhold = '1' then
      if waddr2 = r.raddr2 then
        v.port2_wf(0) := '1';
        v.holddata2(63 downto 32) := wdata2(63 downto 32);
      end if;
    end if;
    if we2(1) = '1' and rdhold = '0' then
      if waddr2 = raddr2 then
        v.port2_wf(1) := '1';
        v.holddata2(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;
    if we2(1) = '1' and rdhold = '1' then
      if waddr2 = r.raddr2 then
        v.port2_wf(1) := '1';
        v.holddata2(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;
    --PORT3----
    if we1(0) = '1' and rdhold = '0' then
      if waddr1 = raddr3 then
        v.port3_wf(0) := '1';
        v.holddata3(63 downto 32) := wdata1(63 downto 32);
      end if;
    end if;
    if we1(0) = '1' and rdhold = '1' then
      if waddr1 = r.raddr3 then
        v.port3_wf(0) := '1';
        v.holddata3(63 downto 32) := wdata1(63 downto 32);
      end if;
    end if;
    if we1(1) = '1' and rdhold = '0' then
      if waddr1 = raddr3 then
        v.port3_wf(1) := '1';
        v.holddata3(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;
    if we1(1) = '1' and rdhold = '1' then
      if waddr1 = r.raddr3 then
        v.port3_wf(1) := '1';
        v.holddata3(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;   
    if we2(0) = '1' and rdhold = '0' then
      if waddr2 = raddr3 then
        v.port3_wf(0) := '1';
        v.holddata3(63 downto 32) := wdata2(63 downto 32);
      end if;
    end if;
    if we2(0) = '1' and rdhold = '1' then
      if waddr2 = r.raddr3 then
        v.port3_wf(0) := '1';
        v.holddata3(63 downto 32) := wdata2(63 downto 32);
      end if;
    end if;
    if we2(1) = '1' and rdhold = '0' then
      if waddr2 = raddr3 then
        v.port3_wf(1) := '1';
        v.holddata3(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;
    if we2(1) = '1' and rdhold = '1' then
      if waddr2 = r.raddr3 then
        v.port3_wf(1) := '1';
        v.holddata3(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;
    --PORT4----
    if we1(0) = '1' and rdhold = '0' then
      if waddr1 = raddr4 then
        v.port4_wf(0) := '1';
        v.holddata4(63 downto 32) := wdata1(63 downto 32);
      end if;
    end if;
    if we1(0) = '1' and rdhold = '1' then
      if waddr1 = r.raddr4 then
        v.port4_wf(0) := '1';
        v.holddata4(63 downto 32) := wdata1(63 downto 32);
      end if;
    end if;
    if we1(1) = '1' and rdhold = '0' then
      if waddr1 = raddr4 then
        v.port4_wf(1) := '1';
        v.holddata4(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;
    if we1(1) = '1' and rdhold = '1' then
      if waddr1 = r.raddr4 then
        v.port4_wf(1) := '1';
        v.holddata4(31 downto 0) := wdata1(31 downto 0);
      end if;
    end if;   
    if we2(0) = '1' and rdhold = '0' then
      if waddr2 = raddr4 then
        v.port4_wf(0) := '1';
        v.holddata4(63 downto 32) := wdata2(63 downto 32);
      end if;
    end if;
    if we2(0) = '1' and rdhold = '1' then
      if waddr2 = r.raddr4 then
        v.port4_wf(0) := '1';
        v.holddata4(63 downto 32) := wdata2(63 downto 32);
      end if;
    end if;
    if we2(1) = '1' and rdhold = '0' then
      if waddr2 = raddr4 then
        v.port4_wf(1) := '1';
        v.holddata4(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;
    if we2(1) = '1' and rdhold = '1' then
      if waddr2 = r.raddr4 then
        v.port4_wf(1) := '1';
        v.holddata4(31 downto 0) := wdata2(31 downto 0);
      end if;
    end if;
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --Forwarding (final multiplexing is done explicitly to reduce
    --critical path on sram output)
    ---------------------------------------------------------------------------
    forw_rdata1v := r.holddata1;
    forw_rdata2v := r.holddata1;
    forw_rdata3v := r.holddata1;
    forw_rdata4v := r.holddata1;
    forw_sel1 := "00";
    forw_sel2 := "00";
    forw_sel3 := "00";
    forw_sel4 := "00";
    if r.port1_wf(0) = '1' then
      forw_rdata1v(63 downto 32) := r.holddata1(63 downto 32);
      forw_sel1(1) := '1';
    end if;
    if r.port1_wf(1) = '1' then
      forw_rdata1v(31 downto 0) := r.holddata1(31 downto 0);
      forw_sel1(0) := '1';
    end if;
    if r.port2_wf(0) = '1' then
      forw_rdata2v(63 downto 32) := r.holddata2(63 downto 32);
      forw_sel2(1) := '1';
    end if;
    if r.port2_wf(1) = '1' then
      forw_rdata2v(31 downto 0) := r.holddata2(31 downto 0);
      forw_sel2(0) := '1';
    end if;
    if r.port3_wf(0) = '1' then
      forw_rdata3v(63 downto 32) := r.holddata3(63 downto 32);
      forw_sel3(1) := '1';
    end if;
    if r.port3_wf(1) = '1' then
      forw_rdata3v(31 downto 0) := r.holddata3(31 downto 0);
      forw_sel3(0) := '1';
    end if;
    if r.port4_wf(0) = '1' then
      forw_rdata4v(63 downto 32) := r.holddata4(63 downto 32);
      forw_sel4(1) := '1';
    end if;
    if r.port4_wf(1) = '1' then
      forw_rdata4v(31 downto 0) := r.holddata4(31 downto 0);
      forw_sel4(0) := '1';
    end if;
    ---------------------------------------------------------------------------    
    if  we1(0) = '1' and r.raddr1 = waddr1 then
      forw_rdata1v(63 downto 32) := wdata1(63 downto 32);
      forw_sel1(1) := '1';
    end if;
    if  we1(1) = '1' and r.raddr1 = waddr1 then
      forw_rdata1v(31 downto 0) := wdata1(31 downto 0);
      forw_sel1(0) := '1';
    end if;
    if  we2(0) = '1' and r.raddr1 = waddr2 then
      forw_rdata1v(63 downto 32) := wdata2(63 downto 32);
      forw_sel1(1) := '1';
    end if;
    if  we2(1) = '1' and r.raddr1 = waddr2 then
      forw_rdata1v(31 downto 0) := wdata2(31 downto 0);
      forw_sel1(0) := '1';
    end if;

    if  we1(0) = '1' and r.raddr2 = waddr1 then
      forw_rdata2v(63 downto 32) := wdata1(63 downto 32);
      forw_sel2(1) := '1';
    end if;
    if  we1(1) = '1' and r.raddr2 = waddr1 then
      forw_rdata2v(31 downto 0) := wdata1(31 downto 0);
      forw_sel2(0) := '1';
    end if;
    if  we2(0) = '1' and r.raddr2 = waddr2 then
      forw_rdata2v(63 downto 32) := wdata2(63 downto 32);
      forw_sel2(1) := '1';
    end if;
    if  we2(1) = '1' and r.raddr2 = waddr2 then
      forw_rdata2v(31 downto 0) := wdata2(31 downto 0);
      forw_sel2(0) := '1';
    end if;

    if  we1(0) = '1' and r.raddr3 = waddr1 then
      forw_rdata3v(63 downto 32) := wdata1(63 downto 32);
      forw_sel3(1) := '1';
    end if;
    if  we1(1) = '1' and r.raddr3 = waddr1 then
      forw_rdata3v(31 downto 0) := wdata1(31 downto 0);
      forw_sel3(0) := '1';
    end if;
    if  we2(0) = '1' and r.raddr3 = waddr2 then
      forw_rdata3v(63 downto 32) := wdata2(63 downto 32);
      forw_sel3(1) := '1';
    end if;
    if  we2(1) = '1' and r.raddr3 = waddr2 then
      forw_rdata3v(31 downto 0) := wdata2(31 downto 0);
      forw_sel3(0) := '1';
    end if;

    if  we1(0) = '1' and r.raddr4 = waddr1 then
      forw_rdata4v(63 downto 32) := wdata1(63 downto 32);
      forw_sel4(1) := '1';
    end if;
    if  we1(1) = '1' and r.raddr4 = waddr1 then
      forw_rdata4v(31 downto 0) := wdata1(31 downto 0);
      forw_sel4(0) := '1';
    end if;
    if  we2(0) = '1' and r.raddr4 = waddr2 then
      forw_rdata4v(63 downto 32) := wdata2(63 downto 32);
      forw_sel4(1) := '1';
    end if;
    if  we2(1) = '1' and r.raddr4 = waddr2 then
      forw_rdata4v(31 downto 0) := wdata2(31 downto 0);
      forw_sel4(0) := '1';
    end if;

    if forw_sel1(0) = '1' then
      rdata1v(31 downto 0) := forw_rdata1v(31 downto 0);
    end if;
    if forw_sel1(1) = '1' then
      rdata1v(63 downto 32) := forw_rdata1v(63 downto 32);
    end if;
    if forw_sel2(0) = '1' then
      rdata2v(31 downto 0) := forw_rdata2v(31 downto 0);
    end if;
    if forw_sel2(1) = '1' then
      rdata2v(63 downto 32) := forw_rdata2v(63 downto 32);
    end if;
    if forw_sel3(0) = '1' then
      rdata3v(31 downto 0) := forw_rdata3v(31 downto 0);
    end if;
    if forw_sel3(1) = '1' then
      rdata3v(63 downto 32) := forw_rdata3v(63 downto 32);
    end if;
    if forw_sel4(0) = '1' then
      rdata4v(31 downto 0) := forw_rdata4v(31 downto 0);
    end if;
    if forw_sel4(1) = '1' then
      rdata4v(63 downto 32) := forw_rdata4v(63 downto 32);
    end if;
        
    
    if rstn = '0' then
      v := reg_type_reset;
    end if;

    rdata1 <= rdata1v;
    rdata2 <= rdata2v;
    rdata3 <= rdata3v;
    rdata4 <= rdata4v;
    
    for i in 0 to 1 loop
      re1_masked(i) <= re1(i) and not(rdhold);
      re2_masked(i) <= re2(i) and not(rdhold);
      re3_masked(i) <= re3(i) and not(rdhold);
      re4_masked(i) <= re4(i) and not(rdhold);
    end loop;
    rin    <= v;

  end process;


  seq : process(clk, rstn)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;

  end process;

end rtl;
