------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-- Entity:      div64
-- File:        div64.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
-- Description: NOEL-V 64-bit Division Unit
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.noelvint.all;

entity div64 is
  generic (
    fabtech   : integer range 0 to NTECH := 0;
    scantest  : integer := 0
    );
  port (
    clk       : in  std_ulogic;
    rstn      : in  std_ulogic;
    holdn     : in  std_ulogic;
    divi      : in  div64_in_type;
    divo      : out div64_out_type;
    testen    : in  std_ulogic := '0';
    testrst   : in  std_ulogic := '1'
    );
end;

architecture rtl of div64 is

  -- Constants ----------------------------------------------------
  --constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant RESET_ALL    : boolean := true;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  constant one64        : std_logic_vector(63 downto 0) := '1' & zerow64(62 downto 0); 
  
  type regtype is record
    -- Wrapper
    ready       : std_ulogic;
    ctrl        : std_logic_vector(2 downto 0);
    result      : std_logic_vector(63 downto 0);
    -- Divider
    dividend    : std_logic_vector(63 downto 0);
    divisor     : std_logic_vector(127 downto 0);
    quotient    : std_logic_vector(63 downto 0);
    quotient_msk: std_logic_vector(63 downto 0);
    running     : std_ulogic;
    signo       : std_ulogic;
  end record;

  constant RES : regtype := (
    -- Wrapper
    ready       => '1',
    ctrl        => (others => '0'),
    result      => (others => '0'),
    -- Divider
    dividend    => (others => '0'),
    divisor     => (others => '0'),
    quotient    => (others => '0'),
    quotient_msk=> (others => '0'),
    running     => '0',
    signo       => '0'    
    );

  -- Signals ----------------------------------------------------
  signal r, rin         : regtype;
  signal arstn          : std_ulogic;

  -- Functions --------------------------------------------------

  -- Generate Shift Value (Find first one)
  function firstone(dividend : std_logic_vector(63 downto 0)) return integer is
    variable index      : integer range 0 to 63;
  begin
    index := 63;
    for i in dividend'length-1 downto 0 loop
      index     := i;
      if dividend(i) = '1' then
        exit;
      end if;                       
    end loop;
    return(index);
  end;
  
begin

  -- Misc
  arstn         <= testrst when (ASYNC_RESET and scantest/=0 and testen/='0') else
                   rstn when ASYNC_RESET else '1';

  comb : process (r, divi)
    variable v                  : regtype;
    variable sign               : std_ulogic;
    variable divisor            : std_logic_vector(127 downto 0);
    variable dividend           : std_logic_vector(127 downto 0);
    variable dividend_comp      : std_logic_vector(127 downto 0);
    variable op1                : std_logic_vector(63 downto 0);
    variable op2                : std_logic_vector(63 downto 0);
    variable result             : std_logic_vector(63 downto 0);
    variable start              : std_ulogic;
    variable dshift             : integer range 0 to 63;
    
  begin

    v := r;

    divisor     := (others => '0');
    v.result    := (others => '0');
    dividend_comp       := (others => '0');
    start       := '0';
    
    -- Latch input signals
    if (not(divi.flush) and r.ready) = '1' then
      v.ctrl    := divi.ctrl;
      start     := '1';
    end if;

    -- Add signed operations
    op1         := divi.op1;
    op2         := divi.op2;
    sign        := not(divi.ctrl(0));
    if divi.ctrl(2) = '1' then -- Check word operation
      if sign = '1' then
        op1(63 downto 32)       := (others => divi.op1(31));
        op2(63 downto 32)       := (others => divi.op2(31));
      else
        op1(63 downto 32)       := (others => '0');
        op2(63 downto 32)       := (others => '0');
      end if;
    end if;

    -- Data Path
    if start = '1' then
      -- Operation Started
      v.running         := '1';
      v.ready           := '0';
      -- Dividend
      v.dividend        := op1;
      if sign = '1' and op1(63) = '1' then
        v.dividend      := not(op1) + 1;
      end if;
      -- Compute the amount to shift in order to speed-up the division
      dshift    := 63;
      if op2 /= zerow64 then
        dshift  := firstone(v.dividend);
      end if;
      -- Divisor
      divisor(127 downto 64)    := (others => '0');
      divisor(63 downto 0)      := op2;
      if sign = '1' and op2(63) = '1' then
        divisor(63 downto 0)    := not(op2) + 1;
      end if;
      v.divisor         := std_logic_vector(shift_left(unsigned(divisor), dshift));
      -- Output Sign
      if ((divi.ctrl(1 downto 0) = "00" and sign = '1' and (op1(63) /= op2(63))) and (op2 /= zerow64)) or (op1(63) = '1' and divi.ctrl(1 downto 0) = "10") then
        v.signo         := '1';
      else
        v.signo         := '0';
      end if;
      -- Quotient
      v.quotient        := (others => '0');
      v.quotient_msk    := zerow64;
      v.quotient_msk(dshift) := '1';
    elsif r.quotient_msk = zerow64 and r.running = '1' then
      -- Finish operation
      v.running         := '0';
      v.ready           := '1';
      -- Clear control signals
      v.signo           := '0';
      if r.ctrl(1) = '0' then -- div op
        if r.signo = '1' then
          v.result      := not(r.quotient) + 1;
        else
          v.result      := r.quotient;
        end if;
      else -- rem op
        if r.signo = '1' then
          v.result      := not(r.dividend) + 1;
        else
          v.result      := r.dividend;
        end if;
      end if;
    else -- Operation is running but not finished yet
      dividend_comp     := zerow64 & r.dividend;
      if (r.divisor <= dividend_comp) then
        dividend        := (zerow64 & r.dividend) - r.divisor;
        v.dividend      := dividend(63 downto 0);
        v.quotient      := r.quotient or r.quotient_msk;
      end if;
      v.divisor         := std_logic_vector(shift_right(unsigned(r.divisor), 1));
      v.quotient_msk    := std_logic_vector(shift_right(unsigned(r.quotient_msk), 1));     
    end if;

    -- Flush operation
    if divi.flush = '1' and r.running = '1' then
      v.running         := '0';
      v.ready           := '1';
    end if;

    -- Select Correct Result
    result              := r.result;
    if r.ctrl(2) = '1' then
      result(63 downto 32)      := (others => r.result(31));
    end if;

    rin                 <= v;
    
    -- Drive Outputs
    divo.result         <= result;
    divo.nready         <= not(v.ready);
    divo.icc            <= (others => '0');

  end process;

  syncrregs : if not ASYNC_RESET generate
    regs : process(clk)
    begin
      if rising_edge(clk) then
        if holdn = '1' then
          r <= rin;
        end if;
        if RESET_ALL and rstn = '0' then
          r <= RES;
        end if;
      end if;
    end process;
  end generate;

  asyncrregs : if ASYNC_RESET generate
    regs : process(clk, arstn)
    begin
      if arstn = '0' then
        r <= RES;
      elsif rising_edge(clk) then
        if holdn = '1' then
          r <= rin;
        end if;
      end if;
    end process;
  end generate;

end;
