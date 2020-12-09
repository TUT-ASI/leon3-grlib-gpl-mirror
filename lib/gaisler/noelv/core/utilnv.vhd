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
-- Entity:      utilnv
-- File:        utilnv.vhd
-- Author:      Johan Klockars, Cobham Gaisler AB
-- Description: Miscellaneous utility functions.
--              Not everything here can be synthesised!
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
use ieee.numeric_std.all;
use grlib.riscv.all;
library gaisler;
use gaisler.noelvint.all;

package utilnv is

  constant fpulen : integer := 64;  -- qqq

  -- Misc

  constant C_NORMAL : std_logic_vector(1 downto 0) := "00";
  constant C_ZERO   : std_logic_vector(1 downto 0) := "01";
  constant C_NAN    : std_logic_vector(1 downto 0) := "10";
  constant C_INF    : std_logic_vector(1 downto 0) := "11";

  type float is record
-- pragma translate_off
    v        : real;
-- pragma translate_on
    w        : word64;
    class    : std_logic_vector(1 downto 0);  -- See C_ above.
    snan     : boolean;  -- Signalling NaN if C_NAN
    neg      : boolean;
    exp      : signed(12 downto 0);
    -- Normally implicit 1 at bit 54
    --  53:2 mantissa bits    53:31 for SP
    --   1:0 guard bits for rounding
    mant     : std_logic_vector(55 downto 0);
  end record;

  constant float_none : float := (
-- pragma translate_off
    0.0,
-- pragma translate_on
    (others => '0'), C_NORMAL, false, false,
    (others => '0'), (others => '0'));

  function is_signan(op : float) return boolean;
  function is_inf(op : float) return boolean;
  function is_nan(op : float) return boolean;
  function is_zero(op : float) return boolean;
  function is_normal(op : float) return boolean;

  function to_float(data : std_logic_vector; fmt : std_logic_vector) return float;
  function to_float_ext(data : std_logic_vector) return float;
-- pragma translate_off
  function tost(f : float) return string;
  function tost(v : unsigned) return string;
-- pragma translate_on
  function to_reg(num : std_logic_vector) return string;

  function truncate(v : real) return integer;
  function log2(v : real) return integer;
-- pragma translate_off
  function from_real(f_in : real; fmt : std_logic_vector) return std_logic_vector;
  function from_real_ext(f : real; fmt : std_logic_vector) return std_logic_vector;
  function from_float(v : float; fmt : std_logic_vector) return std_logic_vector;
-- pragma translate_on
  function r2u(f_in : real; bits : integer) return unsigned;
  function s2r(data : std_logic_vector) return real;
  function u2r(data : std_logic_vector) return real;

  function has_decimals(f_in : real) return std_ulogic;

  function inf_mul(a : float; b : float) return float;
  function inf_neg(a : float) return float;
  function mul_illegal(a : float; b : float) return boolean;
  function add_illegal(a : float; b : float) return boolean;

  procedure log(enabled : boolean; comment : string);
  function all_0(data : std_logic_vector) return boolean;
  function all_1(data : std_logic_vector) return boolean;
  function all_0(data : signed) return boolean;
  function all_1(data : signed) return boolean;
  function all_0(data : unsigned) return boolean;
  function all_1(data : unsigned) return boolean;
  function to_bit(v : boolean) return std_ulogic;
  function to_bit(v : integer) return std_ulogic;

  procedure set(dest : inout std_logic_vector; start : integer;
                data : std_logic_vector);
  procedure set(dest : inout std_logic_vector; start : integer;
                d    : std_logic);
  function get(data  : std_logic_vector;
               start : integer; bits : integer) return std_logic_vector;
  function lo_h(v : std_logic_vector) return std_logic_vector;
  function hi_h(v : std_logic_vector) return std_logic_vector;
  procedure uadd_range(src : std_logic_vector; addend : integer; dst : out std_logic_vector);
  function u2slv(data : integer; bits : integer) return std_logic_vector;
  function notx(data : unsigned) return boolean;
  function notx(data : signed) return boolean;
  function u2i(data : std_logic_vector) return integer;
  function u2i(data : unsigned) return integer;
  function s2i(data : std_logic_vector) return integer;
  function s2i(data : signed) return integer;
  function minimum(x : integer; y: integer) return integer;
  function maximum(x : integer; y: integer) return integer;

  function NaN(fmt : std_logic_vector) return std_logic_vector;
  function Inf(fmt : std_logic_vector) return std_logic_vector;

end;

package body utilnv is

    function is_normal(op : float) return boolean is
    begin
      return op.class = C_NORMAL;
    end;

    function is_zero(op : float) return boolean is
    begin
      return op.class = C_ZERO;
    end;

    function is_nan(op : float) return boolean is
    begin
      return op.class = C_NAN;
    end;

    function is_inf(op : float) return boolean is
    begin
      return op.class = C_INF;
    end;

    -- Signalling NaN?
    function is_signan(op : float) return boolean is
    begin
--      return is_nan(op) and op.mant(53) = '0';
      return is_nan(op) and op.snan;
    end;

  -- Binary (IEEE754) to float conversion
  -- Does not provide infinity, NaN and such in real component.
  function to_float(data : std_logic_vector; fmt : std_logic_vector) return float is
    -- Non-constant
    variable bits       : integer;
    variable frac_bits  : integer := 23;  -- Assume single precision
    variable exp_bits   : integer := 8;
    variable exp_max    : integer;
    variable exp        : integer;
    variable frac       : integer;
    variable sign       : real;
    variable f          : real;
    variable r          : float   := float_none;
  begin
    r.w          := data;
-- pragma translate_off
    r.v          := 12345.6789;  -- Dummy
-- pragma translate_on
    if fpulen = 64 and fmt = "01" then
      frac_bits  := 52;
      exp_bits   := 11;
    -- Improper NaN boxing of 32 bit float?
    elsif fpulen = 64 and data'length = 64 and not all_1(data(63 downto 32)) then
      r.class    := C_NAN;
      r.w        := (others => '1');
      r.w(frac_bits - 2 downto 0) := (others => '0');
      r.w(exp_bits + frac_bits)   := '0';
      return r;
    end if;

    bits    := 1 + exp_bits + frac_bits;
    exp_max := 2 ** exp_bits - 1;

    sign    := 1.0;
    if data(frac_bits + exp_bits) = '1' then
      sign  := -1.0;
      r.neg := true;
    end if;

    exp     := u2i(data(bits - 2 downto bits - exp_bits - 1));

    --  Exponent all 1 - infinity (frac 0) or NaN
    if exp = exp_max then
      if all_0(data(frac_bits - 1 downto 0)) then
        r.class  := C_INF;
        return r;
      else
        r.class  := C_NAN;
        if data(frac_bits - 1) = '0' then   -- Signalling NaN?
          r.snan := true;
        end if;
        return r;
      end if;
    end if;

    frac        := u2i(data(frac_bits - 1 downto frac_bits - 23));
    if frac = 0 then
      r.class   := C_ZERO;
    end if;
    f           := real(frac) / 2.0 ** 23;
    if frac_bits > 23 then
      frac      := u2i(data(frac_bits - 23 - 1 downto 0));
      if frac /= 0 then
        r.class := C_NORMAL;
      end if;
      f         := f + real(frac) / 2.0 ** frac_bits;
    end if;

    -- Exponent all 0 - subnormal
    if exp = 0 then
      f       := f * 2.0 ** (1 - (exp_max - 1) / 2);
    else
      r.class := C_NORMAL;
      f       := (1.0 + f) * 2.0 ** (exp - (exp_max - 1) / 2);
    end if;

    f := sign * f;

-- pragma translate_off
    r.v := f;
-- pragma translate_on

    return r;
  end;

  -- Remove NaN boxing and create float from binary (IEEE754)
  function to_float_ext(data : std_logic_vector) return float is
    -- Non-constant
    variable res : word64;
  begin
    if all_1(data(63 downto 32)) then
      return to_float(data, "00");
    else
      return to_float(data, "01");
    end if;
  end;

-- pragma translate_off
  function tost(f : float) return string is
  begin
    if is_inf(f) then
      if f.neg then
        return "-inf";
      else
        return "inf";
      end if;
    end if;
    if is_signan(f) then
      return "sNaN";
    end if;
    if is_nan(f) then
      return "qNaN";
    end if;
    if is_zero(f) then
      if f.neg then
        return "-0";
      else
        return "0";
      end if;
    end if;

    return tost(f.v);
  end;

  function tost(v : unsigned) return string is
  begin
    return tost(std_logic_vector(v));
  end;
-- pragma translate_on

  -- Return GPR name from register number (e.g. x1 -> ra).
  function to_reg(num : std_logic_vector) return string is
    constant n : integer := u2i(num);
  begin
    -- pragma translate_off
    case n is
    when 0 => return "zero";
    when 1 => return "ra";
    when 2 => return "sp";
    when 3 => return "gp";
    when 4 => return "tp";
    when 5 | 6 | 7 =>
              return "t" & tost(n - 5);
    when 8 => return "fp";  -- s0
    when 9 => return "s1";
    when 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 =>
              return "a" & tost(n - 10);
    when 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 =>
              return "s" & tost(n - 18 + 2);
    when 28 | 29 | 30 | 31 =>
              return "t" & tost(n - 28 + 3);
    when others =>
              return "error";
    end case;
    -- pragma translate_on
    return "";
  end;

  function truncate(v : real) return integer is
  begin
    return integer(ieee.math_real.trunc(v));
  end;

  function log2(v : real) return integer is
    variable t : integer;
  begin
    t   := truncate(ieee.math_real.log2(v));
    if 2.0 ** t > v then
      t := t - 1;
    end if;
    if 2.0 ** (t + 1) <= v then
      t := t + 1;
    end if;

    return t;
  end;

-- pragma translate_off
  -- Real to binary (IEEE754) conversion
  -- Does not deal with infinity, NaN and such.
  function from_real(f_in : real; fmt : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable f         : real    := f_in;
    variable bits      : integer;
    variable frac_bits : integer := 23;  -- Assume single precision
    variable exp_bits  : integer := 8;
    variable exp_max   : integer;
    variable mant_max  : real;
    variable exp       : integer;
    variable frac      : integer;
    variable sign      : std_ulogic;
    variable data      : word64;
  begin
    if fpulen = 64 and fmt = "01" then
      frac_bits  := 52;
      exp_bits   := 11;
    end if;

    bits     := 1 + exp_bits + frac_bits;
    exp_max  := 2 ** exp_bits - 1;
    mant_max := 2.0 ** (frac_bits + 1) - 1.0;

    sign     := '0';
    if f < 0.0 then
      f      := -f;
      sign   := '1';
    end if;

    data(bits - 1) := sign;

    -- Too large to represent?
    if f > mant_max * 2.0 ** ((exp_max - 1) / 2 - frac_bits) then
      data(bits - 2 downto frac_bits) := (others => '1');
      data(frac_bits - 1 downto 0)    := (others => '0');
      return data(bits - 1 downto 0);
    elsif f = 0.0 then
      data(bits - 2 downto 0)         := (others => '0');
      return data(bits - 1 downto 0);
    -- Too small to represent, even as subnormal?
    elsif f < 2.0 ** (-((exp_max - 1) / 2 + frac_bits)) then
      data(bits - 2 downto 0)         := (others => '0');
      return data(bits - 1 downto 0);
    end if;

    exp   := log2(f);
    -- Subnormal?
    if exp < 1 - (exp_max - 1) / 2 then
      data(bits - 2 downto frac_bits) := (others => '0');
      exp := 1 - (exp_max - 1) / 2;
      f   := f / 2.0 ** exp;
    else
      data(bits - 2 downto frac_bits) := std_logic_vector(to_unsigned(exp + (exp_max - 1) / 2, exp_bits));
      f   := f / 2.0 ** exp - 1.0;
    end if;

    frac := truncate(f * 2.0 ** 23);
    data(frac_bits - 1 downto frac_bits - 23) := std_logic_vector(to_unsigned(frac, 23));
    f    := f - real(frac) / 2.0 ** 23;
    if frac_bits > 23 then
      frac := truncate(f * 2.0 ** frac_bits);
      data(frac_bits - 23 - 1 downto 0) := std_logic_vector(to_unsigned(frac, frac_bits - 23));
    else
      f := f * 2.0 ** 23;
      if f > 0.5 then
        data(bits - 1 downto 0) := std_logic_vector(unsigned(data(bits - 1 downto 0)) + 1);
      end if;
    end if;

    return data(bits - 1 downto 0);
  end;

  -- Real to binary (IEEE754) conversion with NaN boxing for single precision
  function from_real_ext(f : real; fmt : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable bits : integer := 32;  -- Assume single precision
    variable res  : word64;
  begin
    if fpulen = 64 and fmt = "01" then
      bits := 64;
    end if;

    res                    := (others => '1');
    res(bits - 1 downto 0) := from_real(f, fmt);

    return res;
  end;

  -- Float to binary (IEEE754) conversion
  -- (only used for double <-> single precision.)
  function from_float(v : float; fmt : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable bits : integer    := 32;  -- Assume single precision
    variable snan : word64     := x"ffffffff7f800001";  -- Correct signalling NaN?
    variable frac : integer;
    variable data : word64     := x"ffffffff00000000";
    variable sign : std_ulogic := '0';
  begin
    if fpulen = 64 and fmt = "01" then
      bits := 64;
      snan := x"7ff0000000000001";
      data := (others => '0');
    end if;

    if v.neg then
      sign := '1';
    end if;

    if is_inf(v) then
      data           := Inf(fmt);
      data(bits - 1) := sign;
      return data;
    elsif is_signan(v) then
      return snan;
    elsif is_nan(v) then
      return NaN(fmt);
    elsif is_zero(v) then
      data(bits - 1) := sign;
      return data;
    end if;

    return from_real_ext(v.v, fmt);
  end;
-- pragma translate_on

  -- Real to unsigned conversion
  function r2u(f_in : real; bits : integer) return unsigned is
    -- Non-constant
    variable f    : real                        := ieee.math_real.trunc(f_in);
    variable fd2  : real;
    variable data : unsigned(bits - 1 downto 0) := (others => '0');
  begin
    assert f >= 0.0 report "Bad r2u - negative" severity failure;
    convert : for i in 0 to bits - 1 loop
      fd2       := ieee.math_real.trunc(f / 2.0);
      if fd2 * 2.0 /= f then
        data(i) := '1';
        if fd2 = 0.0 then
          f     := fd2;
          exit convert;
        end if;
      end if;
      f         := fd2;
    end loop;

    assert f = 0.0 report "Bad r2u - large" severity failure;

    return data;
  end;

  -- Signed to real conversion
  function s2r(data : std_logic_vector) return real is
    variable res : real;
    variable fx  : word64;
  begin
    if data'length = 32 then
      if data(31) = '0' then
        res := real(u2i(data(30 downto 0)));
      else
        res := -real(u2i(not data(31 downto 0)) + 1);
      end if;
    else
      fx  := data;
      if data(63) = '1' then
        fx  := std_logic_vector(unsigned(not data) + 1);
      end if;
      res := real(u2i(fx(30 downto 0)));
      res := res + real(u2i(fx(61 downto 31))) * 2.0 ** 31;
      res := res + real(u2i(fx(63 downto 62))) * 2.0 ** 62;
      if data(63) = '1' then
        res := -res;
      end if;
    end if;

    return res;
  end;

  -- Unsigned to real conversion
  function u2r(data : std_logic_vector) return real is
    variable res : real;
  begin
    res := real(u2i(data(30 downto 0)));
    if data'length = 32 then
      if data(31) = '1' then
        res := res + 2.0 ** 31;
      end if;
    else
      res := res + real(u2i(data(61 downto 31))) * 2.0 ** 31;
      res := res + real(u2i(data(63 downto 62))) * 2.0 ** 62;
    end if;

    return res;
  end;

  function has_decimals(f_in : real) return std_ulogic is
    -- Non-constant
    variable f : real := ieee.math_real.trunc(f_in);
  begin
    if f /= f_in then
      return '1';
    end if;

    return '0';
  end;

    -- Helper functions to simplify illegality checks
  function inf_mul(a : float; b : float) return float is
    variable v : float := a;
  begin
    if is_inf(b) then
      v.class := C_INF;
    end if;
    v.neg := a.neg xor b.neg;
    return v;
  end;

  function inf_neg(a : float) return float is
    variable v : float := a;
  begin
    v.neg := not v.neg;
    return v;
  end;

  function mul_illegal(a : float; b : float) return boolean is
  begin
    return (is_inf(a) or is_inf(b)) and (is_zero(a) or is_zero(b));
  end;

  function add_illegal(a : float; b : float) return boolean is
  begin
    return (is_inf(a) and is_inf(b)) and not a.neg = b.neg;
  end;

  procedure log(enabled : boolean; comment : string) is
  begin
-- pragma translate_off
    if enabled then
      print(comment);
    end if;
-- pragma translate_on
  end procedure;

  function all_1(data : std_logic_vector) return boolean is
  begin
    return data = onesw64(data'length - 1 downto 0);
  end;

  function all_0(data : std_logic_vector) return boolean is
  begin
    return data = zerow64(data'length - 1 downto 0);
  end;

  function all_0(data : signed) return boolean is
  begin
    return all_0(std_logic_vector(data));
  end all_0;

  function all_1(data : signed) return boolean is
  begin
    return all_1(std_logic_vector(data));
  end all_1;

  function all_0(data : unsigned) return boolean is
  begin
    return all_0(std_logic_vector(data));
  end all_0;

  function all_1(data : unsigned) return boolean is
  begin
    return all_1(std_logic_vector(data));
  end all_1;

  function to_bit(v : boolean) return std_ulogic is
  begin
    if v then
      return '1';
    else
      return '0';
    end if;
  end to_bit;

  function to_bit(v : integer) return std_ulogic is
  begin
    if v = 0 then
      return '0';
    end if;

    return '1';
  end;

  function maximum(x : integer; y: integer) return integer is
  begin
    if x > y then
      return x;
    else
      return y;
    end if;
  end;

  function minimum(x : integer; y: integer) return integer is
  begin
    if x < y then
      return x;
    else
      return y;
    end if;
  end;

  function notx(data : unsigned) return boolean is
  begin
    return notx(std_logic_vector(data));
  end;

  function notx(data : signed) return boolean is
  begin
    return notx(std_logic_vector(data));
  end;

  -- Return data interpreted as unsigned, as an integer.
  function u2i(data : std_logic_vector) return integer is
  begin
    if notx(data) then
      return to_integer(unsigned(data));
    else
      return 0;
    end if;
  end;

  function u2i(data : unsigned) return integer is
  begin
    if notx(data) then
      return to_integer(data);
    else
      return 0;
    end if;
  end;

  -- Return data interpreted as signed, as an integer.
  function s2i(data : std_logic_vector) return integer is
  begin
    if notx(data) then
      return to_integer(signed(data));
    else
      return 0;
    end if;
  end;

  function s2i(data : signed) return integer is
  begin
    if notx(data) then
      return to_integer(data);
    else
      return 0;
    end if;
  end;

  -- Return data interpreted as unsigned, as bits of std_logic_vector.
  function u2slv(data : integer; bits : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(data, bits));
  end;

  procedure uadd_range(src : std_logic_vector; addend : integer; dst : out std_logic_vector) is
  begin
    -- Unsigned addition is only allowed with a natural number,
    -- so turn into subtraction when needed.
    -- The Vivado error message with only the + line is:
    -- ERROR: [Synth 8-97] array index -1 out of range [.../cctrlnv.vhd:164]
    if addend >= 0 then
      dst := std_logic_vector(unsigned(src(dst'range)) + addend);
    else
      dst := std_logic_vector(unsigned(src(dst'range)) - (-addend));
    end if;
  end;

  -- Return bits from start in data, away from bit 0.
  function get(data  : std_logic_vector;
               start : integer; bits : integer) return std_logic_vector is
  begin
    if data'ascending then
      return data(start to start + bits - 1);
    else
      return data(start + bits - 1 downto start);
    end if;
  end;

  -- Sets data in dest from start, away from bit 0.
  procedure set(dest : inout std_logic_vector; start : integer;
                data : std_logic_vector) is
    constant bits : integer := data'length;
  begin
    if dest'ascending then
      dest(start to start + bits - 1) := data;
    else
      dest(start + bits - 1 downto start) := data;
    end if;
  end;

  procedure set(dest : inout std_logic_vector; start : integer;
                d    : std_logic) is
    variable data : std_logic_vector(0 downto 0) := (others => d);
  begin
    set(dest, start, data);
  end;

  -- Return lower half of input.
  function lo_h(v : std_logic_vector) return std_logic_vector is
    variable v_normal : std_logic_vector(v'length - 1 downto 0) := v;
  begin
-- pragma translate_off
    assert v'length mod 2 = 0
      report "lo_h only works for items with even number of bits"
      severity failure;
-- pragma translate_on
    return v_normal(v'length / 2 - 1 downto 0);
  end;

  -- Return higher half of input.
  function hi_h(v : std_logic_vector) return std_logic_vector is
    variable v_normal : std_logic_vector(v'length - 1 downto 0) := v;
  begin
-- pragma translate_off
    assert v'length mod 2 = 0
      report "lo_h only works for items with even number of bits"
      severity failure;
-- pragma translate_on
    return v_normal(v'length - 1 downto v'length / 2);
  end;

  -- This is the canonical NaN.
  function NaN(fmt : std_logic_vector) return std_logic_vector is
  begin
    if fmt = "01" then
      return x"7ff8000000000000";
    else
      return x"ffffffff7fc00000";
    end if;
  end;

  -- Infinity (positive)
  function Inf(fmt : std_logic_vector) return std_logic_vector is
  begin
    if fmt = "01" then
      return x"7ff0000000000000";
    else
      return x"ffffffff7f800000";
    end if;
  end;
end;
