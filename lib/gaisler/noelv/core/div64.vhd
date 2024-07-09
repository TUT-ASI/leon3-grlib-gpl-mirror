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
-- Entity:      div64
-- File:        div64.vhd
-- Author:      Andrea Merlo and Johan Klockars, Cobham Gaisler AB
-- Description: NOEL-V Division Unit
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.tost;
library gaisler;
use gaisler.noelv.all;
use gaisler.noelvint.div_in_type;
use gaisler.noelvint.div_out_type;
use gaisler.utilnv.all_0;
use gaisler.utilnv.to_bit;
use gaisler.utilnv.u2i;
use gaisler.utilnv.get_hi;

entity div64 is
  generic (
    fabtech   : integer range 0 to NTECH := 0;
    scantest  : integer := 0;
    hiperf    : integer := 0;
    small     : integer := 0;
    in_pipe  : integer  := 1
    );
  port (
    clk       : in  std_ulogic;
    rstn      : in  std_ulogic;
    holdn     : in  std_ulogic;
    divi      : in  div_in_type;
    divo      : out div_out_type;
    testen    : in  std_ulogic := '0';
    testrst   : in  std_ulogic := '1'
    );
end;

architecture rtl of div64 is

  constant bits : integer := divi.op1'length;

  -- Constants ----------------------------------------------------
  constant RESET_ALL    : boolean := true;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  subtype divtype is unsigned(bits - 1 downto 0);

  type regtype is record
    -- Wrapper
    ready        : std_ulogic;
    ctrl         : std_logic_vector(2 downto 0);
    result       : divtype;
    -- Divider
    dividend     : divtype;
    divisor      : divtype;
    quotient     : divtype;
    quotient_msk : divtype;
    div_valid    : std_ulogic;
    div_op1      : divtype;
    div_op2      : divtype;
    running      : std_ulogic;
    stopping     : std_ulogic;
    shifting     : std_ulogic;
    signo        : std_ulogic;
    latch_in     : std_ulogic;
    op1          : divtype;
    op2          : divtype;
    sign_in      : std_ulogic;
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
    div_valid   => '0',
    div_op1     => (others => '0'),
    div_op2     => (others => '0'),
    running     => '0',
    stopping    => '0',
    shifting    => '0',
    signo       => '0',
    latch_in    => '0',
    op1         => (others => '0'),
    op2         => (others => '0'),
    sign_in     => '0'
    );

  -- Signals ----------------------------------------------------
  signal r, rin  : regtype;
  signal arstn   : std_ulogic;

  -- Functions --------------------------------------------------


  -- Generate Shift Value (Find first one)
  function firstone(dividend_in : std_logic_vector) return integer is
    variable dividend : std_logic_vector(dividend_in'length - 1 downto 0) := dividend_in;
    variable half     : integer := dividend'length / 2;
  begin
    if half = 1 then
      if dividend(1) = '1' then
        return 1;
      else
        return 0;
      end if;
    else
      if not all_0(dividend(dividend'high downto half)) then
        return half + firstone(dividend(dividend'high downto half));
      else
        return firstone(dividend(half - 1 downto 0));
      end if;
    end if;
  end;


begin

  -- Misc
  arstn <= testrst when (ASYNC_RESET and scantest /= 0 and testen /= '0') else
           rstn    when ASYNC_RESET else '1';

  comb : process (r, divi)
    variable v         : regtype;
    variable sign      : std_ulogic;
    variable divisor   : divtype;
    variable op1       : divtype;
    variable op2       : divtype;
    variable result    : divtype;
    variable start     : std_ulogic;
    variable dshift    : integer range 0 to bits - 1;
    variable dushift   : integer range 0 to bits - 1;
    variable ddshift   : integer range 0 to bits - 1;
    variable neg       : std_ulogic;
    variable divi_ctrl : std_logic_vector(2 downto 0);
    variable divi_op1  : divtype;
    variable divi_op2  : divtype;
  begin
    v := r;

    -- Latch input signals
    start          := '0';
    v.latch_in     := '0';
    if (r.ready and not divi.flush) = '1' then
      v.ctrl       := divi.ctrl;
      if in_pipe /= 0 then
        v.ready    := '0';
        v.latch_in := '1';
        v.op1      := unsigned(divi.op1);
        v.op2      := unsigned(divi.op2);
        v.sign_in  := not divi.ctrl(0);
      else
        start      := '1';
      end if;
    end if;

    if (r.latch_in = '1' and in_pipe /= 0 ) then
      start := '1';
    end if;

    -- Add signed operations
    op1         := unsigned(divi.op1);
    op2         := unsigned(divi.op2);
    sign        := not divi.ctrl(0);
    divi_ctrl   := divi.ctrl;
    divi_op1    := unsigned(divi.op1);
    divi_op2    := unsigned(divi.op2);
    if in_pipe /= 0 then
      op1       := r.op1;
      op2       := r.op2;
      sign      := r.sign_in;
      divi_ctrl := r.ctrl;
      divi_op1  := r.op1;
      divi_op2  := r.op2;
    end if;

    -- This is div/rem[u]w, which does not exist for RV32.
    if bits = 64 and divi_ctrl(2) = '1' then
      if sign = '1' then
        op1(bits - 1 downto bits - 32) := (others => op1(31));
        op2(bits - 1 downto bits - 32) := (others => op2(31));
      else
        op1(bits - 1 downto bits - 32) := (others => '0');
        op2(bits - 1 downto bits - 32) := (others => '0');
      end if;
    end if;

    -- Data Path
    if start = '1' then
      -- Operation Started
      v.running    := '1';
      v.ready      := '0';
      v.latch_in   := '0';
      -- Output Sign
      -- Different signs for div?
      if ((divi_ctrl(1 downto 0) = "00" and
           (op1(bits - 1) /= op2(bits - 1))) and (not all_0(op2))) or
         -- Negative numerator for rem?
         (op1(bits - 1) = '1' and divi_ctrl(1 downto 0) = "10") then
        v.signo    := '1';
      else
        v.signo    := '0';
      end if;
      -- Dividend
      if sign = '1' and op1(bits - 1) = '1' then
        v.dividend := (not op1) + 1;
      else
        v.dividend := op1;
      end if;
      -- Divisor
      neg     := sign and op2(bits - 1);
      divisor := ((op2'range => neg) xor op2) + u2i(neg);
      if small = 1 then
        dshift     := 0;
        v.shifting := '1';
        v.stopping := '0';
        v.divisor  := divisor;
      else
        v.shifting := '0';
        -- Compute the amount to shift in order to speed-up the division
        dushift    := firstone(std_logic_vector(v.dividend));
        ddshift    := firstone(std_logic_vector(divisor));
        if dushift >= ddshift then
          -- Due to the condition above, the subtraction is always in range.
          dshift   := dushift - ddshift;
        else
          dshift   := 0;
        end if;
        if hiperf = 1 then
          -- Need even shift amount for two bits at a time!
          dshift   := (dshift / 2) * 2;
        end if;
        v.divisor  := shift_left(divisor, dshift);
      end if;
      -- Quotient
      v.quotient      := (others => '0');
      v.quotient_msk  := (others => '0');
      v.quotient_msk(dshift) := '1';
      if hiperf = 1 and small = 0 then
        v.div_valid := '0';         -- Assert later if operation finishes.
        v.div_op1   := divi_op1;
        v.div_op2   := divi_op2;
      else
        v.div_valid   := '0';
        v.div_op1     := (others => '0');
        v.div_op2     := (others => '0');
      end if;
      -- Divide by 0?
      if all_0(op2) then
        v.shifting     := '0';
        v.stopping     := '1';
        if divi_ctrl(1) = '0' then    -- div op
          v.signo      := '0';
          if small = 1 then
            v.dividend := (others => '1');
          else
            v.quotient := (others => '1');
          end if;
        else
          if small = 0 then
            v.quotient := v.dividend;
          end if;
        end if;
      end if;

    -- Shift as needed, if small divider.
    elsif small = 1 and r.shifting = '1' then
      if r.divisor <= r.dividend and get_hi(r.divisor) = '0' then
        v.divisor      := shift_left(r.divisor, 1);
        v.quotient_msk := shift_left(r.quotient_msk, 1);
      else
        v.shifting     := '0';
      end if;

    -- Operation is running but not finished yet
    elsif r.running = '1' then
      -- Try 3x divisor
      if    hiperf = 1 and
            ("00" & r.divisor + ('0' & r.divisor & '0')) <= ("00" & r.dividend) then
        v.dividend   := r.dividend - (r.divisor + (r.divisor(r.divisor'high - 1 downto 0) & '0'));
        v.quotient   := r.quotient or r.quotient_msk or r.quotient_msk(r.quotient_msk'high - 1 downto 0) & '0';
      -- Try 2x divisor
      elsif hiperf = 1 and
            (r.divisor & '0') <= ('0' & r.dividend) then
        v.dividend   := r.dividend - (r.divisor(r.divisor'high - 1 downto 0) & '0');
        v.quotient   := r.quotient or r.quotient_msk(r.quotient_msk'high - 1 downto 0) & '0';
      elsif r.divisor <= r.dividend then
        v.dividend   := r.dividend - r.divisor;
        v.quotient   := r.quotient or r.quotient_msk;
      end if;
      -- Stop if we reached the final bit.
      v.stopping     := r.quotient_msk(0);
      -- Stop if dividend was zeroed.
      if small = 0 then
        v.stopping   := v.stopping or to_bit(all_0(r.dividend));
      end if;
      -- If stopping, put final result in the right place.
      if small = 1 then
        if v.stopping = '1' and r.ctrl(1) = '0' then   -- div op
          v.dividend   := v.quotient;
        end if;
      else
        if v.stopping = '1' and r.ctrl(1) = '1' then   -- rem op
          v.quotient   := v.dividend;
        end if;
      end if;
      -- Shift to prepare for next iteration.
      if hiperf = 1 then
        v.divisor      := shift_right(r.divisor,      2);
        v.quotient_msk := shift_right(r.quotient_msk, 2);
      else
        v.divisor      := shift_right(r.divisor,      1);
        v.quotient_msk := shift_right(r.quotient_msk, 1);
      end if;
    end if;

    -- End operation?
    if divi.flush = '1' or r.stopping = '1' then
      v.running       := '0';
      v.shifting      := '0';
      v.ready         := '1';
      v.stopping      := '0';
      v.latch_in      := '0';
      --Possibly negate result
      neg             := r.signo;
      if small = 1 then
        v.result      := ((r.dividend'range => neg) xor r.dividend) + u2i(neg);
      elsif r.stopping = '1' then
        if hiperf = 1 then
          -- Only remember results for actually finished divides.
          v.div_valid := not r.ctrl(1);
        end if;
        v.result      := ((r.quotient'range => neg) xor r.quotient) + u2i(neg);
        -- Keep around for possible reuse with rem after div.
        v.dividend    := r.dividend;
      end if;
    end if;

    -- Select Correct Result
    result              := r.result;
    -- This is div/rem[u]w, which does not exist for RV32.
    if bits = 64 and r.ctrl(2) = '1' then
      result(bits - 1 downto bits - 32) := (others => r.result(31));
    end if;

    rin         <= v;

    -- Drive Outputs
    divo.result <= std_logic_vector(result);
    divo.nready <= not v.ready;
    divo.icc    <= (others => '0');
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
