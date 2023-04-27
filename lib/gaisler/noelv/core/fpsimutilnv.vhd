
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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
-- Entity:      fpsimutilnv
-- File:        fpsimutilnv.vhd
-- Author:      Johan Klockars, Cobham Gaisler
-- Description: Simulation support stuff for the different NOEL-V FPU:s,
--              broken out from fputilnv.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.riscv.all;
use grlib.stdlib.tost;
use grlib.stdlib.notx;
use grlib.riscv.reg_t;
library gaisler;
--use gaisler.fputilnv.all;
use gaisler.fputilnv.fpuop_t;
use gaisler.fputilnv.float;
use gaisler.fputilnv.is_inf;
use gaisler.fputilnv.is_signan;
use gaisler.fputilnv.is_nan;
use gaisler.fputilnv.is_zero;
use gaisler.fputilnv.Inf;
use gaisler.fputilnv.NaN;
--use gaisler.noelvint.reg_t;
use gaisler.utilnv.u2vec;
use gaisler.utilnv.u2i;
use gaisler.utilnv.s2i;
use gaisler.utilnv.tost;
use gaisler.utilnv.all_0;
use gaisler.utilnv.all_1;
use gaisler.nvsupport.word64;
use gaisler.nvsupport.word;
use gaisler.nvsupport.zerow;


package fpsimutilnv is
-- pragma translate_off

  constant fpulen : integer := 64;  -- qqq Should not be here!

  function tost(op : fpuop_t) return string;
  function tost(f : float) return string;

  function truncate(v : real) return integer;
  function log2(v : real) return integer;
  function r2u(f_in : real; bits : integer) return unsigned;
  function s2r(data : std_logic_vector) return real;
  function u2r(data : std_logic_vector) return real;

  function has_decimals(f_in : real) return std_ulogic;

  function from_real(f_in : real; fmt : std_logic_vector) return std_logic_vector;
  function from_real_ext(f : real; fmt : std_logic_vector) return std_logic_vector;
  function from_float(v : float; fmt : std_logic_vector) return std_logic_vector;

-- pragma translate_on
end;

package body fpsimutilnv is
--pragma translate_off

function tost(op : fpuop_t) return string is
  begin
    case op is
    when FPU_UNKNOWN => return "unknown";
    when FPU_ADD     => return "add";
    when FPU_SUB     => return "sub";
    when FPU_MIN     => return "min";
    when FPU_SGN     => return "sgn";
    when FPU_CVT_S_D => return "cvt.s.d";
    when FPU_MUL     => return "mul";
    when FPU_STORE   => return "store";
    when FPU_CVT_W_S => return "cvt.w.s";
    when FPU_MV_X_W  => return "mv.x.w";
    when FPU_CMP     => return "cmp";
    when FPU_LOAD    => return "load";
    when FPU_CVT_S_W => return "cvt.s.w";
    when FPU_MV_W_X  => return "mv.w.x";
    when FPU_MADD    => return "madd";
    when FPU_MSUB    => return "msub";
    when FPU_NMSUB   => return "nmsub";
    when FPU_NMADD   => return "nmadd";
    when FPU_DIV     => return "div";
    when FPU_SQRT    => return "sqrt";
    end case;
  end;

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

  function truncate(v : real) return integer is
  begin
    return integer(ieee.math_real.trunc(v));
  end;

  function log2(v : real) return integer is
    -- Non-constant
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
    -- Non-constant
    variable res : real;
    variable fx  : word64;
  begin
    if data'length = 32 then
      if data(31) = '0' then
        res := real(u2i(data(30 downto 0)));
      else
        res := -real(u2i(not data(31 downto 0)) + 1);
      end if;
    elsif data'length = 64 then
      fx(data'range)  := data;
      if data(63) = '1' then
        fx  := std_logic_vector(unsigned(not data) + 1);
      end if;
      res := real(u2i(fx(30 downto 0)));
      res := res + real(u2i(fx(61 downto 31))) * 2.0 ** 31;
      res := res + real(u2i(fx(63 downto 62))) * 2.0 ** 62;
      if data(63) = '1' then
        res := -res;
      end if;
    else
      assert false report "Bad data size!" severity failure;
    end if;

    return res;
  end;

  -- Unsigned to real conversion
  function u2r(data : std_logic_vector) return real is
    -- Non-constant
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
    variable snan : word64     := x"ffffffff7f800001";  -- Correct signaling NaN?
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


--pragma translate_on
end;
