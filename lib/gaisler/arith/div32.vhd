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
-----------------------------------------------------------------------------
-- Entity: 	div32
-- File:	div32.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Description:	This unit implemets a divide unit to execute 64-bit by 32-bit
--		division. The divider leaves no remainder.
--		Overflow detection is performed according to the
--		SPARC V8 manual, method B (page 116)
--		Division is made using the non-restoring algorithm,
--		and takes 36 clocks. The operands must be stable during
--		the calculations. The result is available one clock after
--		the ready signal is asserted.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.arith.all;

entity div32 is
generic (scantest  : integer := 0);
port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    holdn   : in  std_ulogic;
    divi    : in  div32_in_type;
    divo    : out div32_out_type;
    testen  : in  std_ulogic := '0';
    testrst : in  std_ulogic := '1'
);
end;

architecture rtl of div32 is

type div_regtype is record
  x      : std_logic_vector(64 downto 0);
  state  : std_logic_vector(2 downto 0);
  ovfs   : std_logic_vector(1 downto 0);
  op1z   : std_logic;
  zero   : std_logic;
  zero2  : std_logic;
  qcorr  : std_logic;
  zcorr  : std_logic;
  qzero  : std_logic;
  qmsb   : std_logic;
  ovf    : std_logic;
  neg    : std_logic;
  cnt    : std_logic_vector(4 downto 0);
end record;

constant RESET_ALL : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
constant ASYNC_RESET : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
constant RRES : div_regtype := (
  x      => (others => '0'),
  state  => (others => '0'),
  ovfs   => "00",
  op1z   => '0',
  zero   => '0',
  zero2  => '0',
  qcorr  => '0',
  zcorr  => '0',
  qzero  => '0',
  qmsb   => '0',
  ovf    => '0',
  neg    => '0',
  cnt    => (others => '0'));


signal arst   : std_ulogic;
signal r, rin : div_regtype;
signal addin1, addin2, addout: std_logic_vector(32 downto 0);
signal addsub : std_logic;

begin

  -----------------------------------------------------------------------------
  --overflow detection
  --Y[31:0]&op1[31:0] / op2[31:0]
  -----------------------------------------------------------------------------
  --Unsigned division
  --A = y[31:0], B = op2[31:0]
  --if A >= B then overflow
  --if A-B is positive then there is overflow
  -----------------------------------------------------------------------------
  --Signed Division
  -----------------------------------------------------------------------------
  --A = y[31:0]&op1[31] B = op2[31]&op2[31:0]
  --
  --if (A->+) && (B->+) then
  --  if A >= B then overflow 
  --  if A-B is positive then there is overflow
  -- *no extra action
  -----------------------------------------------------------------------------
  --if (A->-) && (B->+) then
  -- if A > B then overflow 
  -- if A+B is negative then there is overflow but remove
  -- overflow if result is 0 since absolute negative range is lower
  -- and act according to method B since we check for negative
  -- no action is needed to remove on 0
  -- **no extra action
  -----------------------------------------------------------------------------
  --if (A->+) && (B->-) then
  -- if A >= B then overflow
  -- if A+B is positive then there is overflow but remove
  -- overflow if result is 0 and op2[30:0] is equal to zero
  -- this will complie with method B
  -- *extra action
  -----------------------------------------------------------------------------
  --if (A->-) && (B->-) then
  -- if A > B then overflow
  -- if A-B is negative then there is no overflow but add
  -- overflow if result is 0 and op2[30:0] is equal to zero
  -- sice the result will be positive and absolute positive range
  -- is less compared to absolve negative range
  -----------------------------------------------------------------------------


  
  arst <= testrst when (ASYNC_RESET and scantest/=0 and testen/='0') else
          rst when ASYNC_RESET else
          '1';

  divcomb : process (r, rst, divi, addout)
  variable v : div_regtype;
  variable vready, vnready : std_logic;
  variable vaddin1, vaddin2 : std_logic_vector(32 downto 0);
  variable vaddsub, ymsb : std_logic;
  constant zero33: std_logic_vector(32 downto 0) := "000000000000000000000000000000000";
  constant zero31: std_logic_vector(30 downto 0) := "0000000000000000000000000000000";
  begin

    vready := '0'; vnready := '0'; v := r;
    if addout = zero33 then
      v.zero := '1';
    else
      v.zero := '0';
    end if;

    v.op1z := '0';
    if divi.op1(30 downto 0) = zero31 then
      v.op1z := '1';
    end if;
        
    vaddin1 := r.x(63 downto 31); vaddin2 := divi.op2; 
    vaddsub := not (divi.op2(32) xor r.x(64));
    v.zero2 := r.zero;

    case r.state is
    when "000" =>
      v.cnt := "00000";
      if (divi.start = '1') then 
	v.x(64) := divi.y(32); v.state := "001";
      end if;
    when "001" =>
      v.x := divi.y & divi.op1(31 downto 0);
      v.neg := divi.op2(32) xor divi.y(32);
      if divi.signed = '1' then
        vaddin1 := divi.y(31 downto 0) & divi.op1(31);
        v.ovf := not (addout(32) xor divi.y(32));
      else
        vaddin1 := divi.y; vaddsub := '1';
        v.ovf := not addout(32);
      end if;
      v.state := "010";
      
      v.ovfs := "00";
      if divi.y(31) = '0' and divi.op2(31) = '1' then
        v.ovfs := "01";
      end if;
      if divi.y(31) = '1' and divi.op2(31) = '1' then
        v.ovfs := "10";
      end if;      
    when "010" =>
      if divi.signed = '1' then
        if r.ovfs = "01" then
          if r.zero = '1' and r.op1z = '1' then
            v.ovf := '0';
          end if;
        end if;
        if r.ovfs = "10" then
          if r.zero = '1' and r.op1z = '1' then
            v.ovf := '1';
          end if;
        end if;
      end if;
              
    --  if ((divi.signed and r.neg and r.zero) = '1') and (divi.op1 = zero33) then v.ovf := '0'; end if;
      v.qmsb := vaddsub; v.qzero := '1';
      v.x(64 downto 32) := addout;
      v.x(31 downto 0) := r.x(30 downto 0) & vaddsub;
      v.state := "011"; v.zcorr := v.zero;
      v.cnt := r.cnt + 1;
    when "011" =>
      v.qzero := r.qzero and (vaddsub xor r.qmsb);
      v.zcorr := r.zcorr or v.zero;
      v.x(64 downto 32) := addout;
      v.x(31 downto 0) := r.x(30 downto 0) & vaddsub;
      if (r.cnt = "11111") then v.state := "100"; vnready := '1';
      else v.cnt := r.cnt + 1; end if;
      v.qcorr := v.x(64) xor divi.y(32);
    when "100" =>
      vaddin1 := r.x(64 downto 32);
      v.state := "101";
    when others =>
      vaddin1 := ((not r.x(31)) & r.x(30 downto 0) & '1');
      vaddin2 := (others => '0'); vaddin2(0) := '1';
      vaddsub := (not r.neg);-- or (r.zcorr and not r.qcorr); 
      if ((r.qcorr = '1')  or (r.zero = '1')) and (r.zero2 = '0') then 
        if (r.zero = '1') and ((r.qcorr = '0') and (r.zcorr = '1')) then 
	   vaddsub := r.neg; v.qzero := '0';
	end if;
        v.x(64 downto 32) := addout; 
      else
        v.x(64 downto 32) := vaddin1; v.qzero := '0';
      end if;
      if (r.ovf = '1') then
	v.qzero := '0';
        v.x(63 downto 32) := (others => '1');
        if divi.signed = '1' then
          if r.neg = '1' then v.x(62 downto 32) := (others => '0');
	  else v.x(63) := '0'; end if;
	end if;
      end if;
      vready := '1';
      v.state := "000";
    end case;

    divo.icc <= r.x(63) & r.qzero & r.ovf & '0';
    if (divi.flush = '1') then v.state := "000"; end if;
    if (not ASYNC_RESET) and (not RESET_ALL) and (rst = '0') then 
      v.state := RRES.state; v.cnt := RRES.cnt;
    end if;
    rin <= v;
    divo.ready <= vready; divo.nready <= vnready;
    divo.result(31 downto 0) <= r.x(63 downto 32);
    addin1 <= vaddin1; addin2 <= vaddin2; addsub <= vaddsub;

  end process;

  divadd : process(addin1, addin2, addsub)
  variable b : std_logic_vector(32 downto 0);
  begin
    if addsub = '1' then b := not addin2; else b := addin2; end if;
    addout <= addin1 + b + addsub;
  end process;

  syncrregs : if not ASYNC_RESET generate
    reg : process(clk)
    begin 
      if rising_edge(clk) then 
        if (holdn = '1') then r <= rin; end if;
        if (rst = '0') then
          if RESET_ALL then
            r <= RRES;
          else
            r.state <= RRES.state; r.cnt <= RRES.cnt;
          end if;
        end if;
      end if;
    end process;
  end generate syncrregs;
  asyncrregs : if ASYNC_RESET generate
    reg : process(clk, arst)
    begin
      if (arst = '0') then
        r <= RRES;
      elsif rising_edge(clk) then 
        if (holdn = '1') then r <= rin; end if;
      end if;
    end process;
  end generate asyncrregs;

end; 

