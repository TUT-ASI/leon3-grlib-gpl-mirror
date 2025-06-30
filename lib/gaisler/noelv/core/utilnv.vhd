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
-- Entity:      utilnv
-- File:        utilnv.vhd
-- Author:      Johan Klockars, Cobham Gaisler AB
-- Description: Miscellaneous utility functions.
--              Not everything here can be synthesised!
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.tost;
use grlib.stdlib.print;
use grlib.stdlib.notx;

package utilnv is
  function tost(v : unsigned) return string;
  function tost(v : signed) return string;
  function tost(v : bit_vector) return string;

  procedure log(enabled : boolean; comment : string);

  function no_x(v        : std_logic_vector;
                all_zero : boolean := false) return std_logic_vector;
  function no_x(v        : signed;
                all_zero : boolean := false) return signed;
  function no_x(v        : unsigned;
                all_zero : boolean := false) return unsigned;

  function cond(c : boolean;
                t : std_ulogic;
                f : std_ulogic) return std_ulogic;
  function cond(c : boolean;
                t : std_logic_vector;
                f : std_logic_vector) return std_logic_vector;
  function cond(c : boolean;
                t : integer;
                f : integer) return integer;
  function is_set(v : integer) return boolean;

  function all_0(data : std_logic_vector) return boolean;
  function all_1(data : std_logic_vector) return boolean;
  function all_0(data : signed) return boolean;
  function all_1(data : signed) return boolean;
  function all_0(data : unsigned) return boolean;
  function all_1(data : unsigned) return boolean;
  function all_0(data : std_logic_vector) return std_logic;
  function all_1(data : std_logic_vector) return std_logic;
  function single_1(data : std_logic_vector) return boolean;
  function to_bit(v : boolean) return std_ulogic;
  function to_bit(v : integer) return std_ulogic;

  function get_ones(bits : integer) return std_logic_vector;
  function get_ones(template : std_logic_vector) return std_logic_vector;
  function get_zeros(bits : integer) return std_logic_vector;
  function get_zeros(template : std_logic_vector) return std_logic_vector;

  procedure set(dest : inout std_logic_vector; start : integer;
                data : std_logic_vector);
  procedure set(dest : inout std_logic_vector; start : integer;
                d    : std_logic);
  procedure set_hi(dest : inout std_logic_vector;
                   data : std_logic_vector);
  procedure set_hi(dest : inout std_logic_vector;
                   d    : std_logic);
  procedure set_lo(dest : inout std_logic_vector;
                   data : std_logic_vector);
  function set(src  : std_logic_vector; start : integer;
               data : std_logic_vector) return std_logic_vector;
  function set(data : std_logic_vector; n : integer) return std_logic_vector;
  function get(data  : std_logic_vector;
               start : integer; bits : integer) return std_logic_vector;
  function get(data  : std_logic_vector;
               start : integer; template : std_logic_vector) return std_logic_vector;
  function get(data  : unsigned;
               start : integer; bits : integer) return unsigned;
  function get(data  : signed;
               start : integer; bits : integer) return signed;
  function get_hi(data : std_logic_vector;
                  bits : integer) return std_logic_vector;
  function get_hi(data : std_logic_vector) return std_logic;
  function get_hi(data : signed) return std_logic;
  function get_hi(data : unsigned) return std_logic;
  function get_lo(data : std_logic_vector;
                  bits : integer) return std_logic_vector;
  function get_lo(data : unsigned;
                  bits : integer) return unsigned;
  function get_lo(data : signed;
                  bits : integer) return signed;
  function get_right(data_in : std_logic_vector;
                     bits    : integer) return std_logic_vector;
  function get_right(data_in  : std_logic_vector;
                     template : std_logic_vector) return std_logic_vector;
  function get_left(data_in : std_logic_vector;
                    bits    : integer) return std_logic_vector;
  function get_left(data_in  : std_logic_vector;
                    template : std_logic_vector) return std_logic_vector;
  function lo_h(v : std_logic_vector) return std_logic_vector;
  function hi_h(v : std_logic_vector) return std_logic_vector;
  procedure uadd_range(src : std_logic_vector; addend : integer; dst : out std_logic_vector);
  function uadd(src : std_logic_vector; addend_in : integer) return std_logic_vector;
  function uadd(src : std_logic_vector; addend : std_logic_vector) return std_logic_vector;
  function uadd(src : std_logic_vector; addend : std_logic_vector) return unsigned;
  function uaddx(src : std_logic_vector; addend_in : integer) return std_logic_vector;
  function uaddx(src : std_logic_vector; addend : std_logic_vector) return std_logic_vector;
  function uaddx(src : std_logic_vector; addend : std_logic_vector) return unsigned;
  function uaddx(src : unsigned; addend : unsigned) return unsigned;
  function usub(src : std_logic_vector; subtrahend_in : integer) return std_logic_vector;
  function usub(src : std_logic_vector; subtrahend : std_logic_vector) return std_logic_vector;
  function usub(src : std_logic_vector; subtrahend : std_logic_vector) return unsigned;
  function usubx(src : std_logic_vector; subtrahend : std_logic_vector) return std_logic_vector;
  function usubx(src : std_logic_vector; subtrahend : std_logic_vector) return unsigned;
  function usubx(src : unsigned; subtrahend : std_logic_vector) return unsigned;
  function u2slv(data : integer; bits : integer) return std_logic_vector;
  function u2vec(data : integer; bits : integer) return unsigned;
  function u2vec(data : integer; bits : integer) return std_logic_vector;
  function u2vec(data : integer; template : unsigned) return unsigned;
  function u2vec(data : integer; template : std_logic_vector) return std_logic_vector;
  function u2vec(data : boolean; bits : integer) return std_logic_vector;
  function u2vec(data : boolean; template : std_logic_vector) return std_logic_vector;
  function s2vec(data : integer; bits : integer) return signed;
  function s2vec(data : integer; bits : integer) return std_logic_vector;
  function s2vec(data : integer; template : signed) return signed;
  function s2vec(data : integer; template : std_logic_vector) return std_logic_vector;
  function notx(data : unsigned) return boolean;
  function notx(data : signed) return boolean;
  function u2i(data : std_logic_vector) return integer;
  function u2i(data : bit_vector) return integer;
  function u2i(data : unsigned) return integer;
  function u2i(data : std_logic) return integer;
  function u2i(data : boolean) return integer;
  function s2i(data : std_logic_vector) return integer;
  function s2i(data : signed) return integer;
  function s2i(data : std_logic) return integer;
  function b2i(data : boolean) return integer;
  function sext(v : std_logic_vector; template : std_logic_vector) return std_logic_vector;
  function sext(v : std_logic_vector; length : integer) return std_logic_vector;
  function sext(v : signed; template : std_logic_vector) return std_logic_vector;
  function sext(v : signed; length : integer) return std_logic_vector;
  function uext(v : std_logic_vector; template : std_logic_vector) return std_logic_vector;
  function uext(v : std_logic_vector; length : integer) return std_logic_vector;
  function uext(v : unsigned; template : std_logic_vector) return std_logic_vector;
  function uext(v : unsigned; length : integer) return std_logic_vector;
  function uext(v : unsigned; template : unsigned) return unsigned;
  function uext(v : unsigned; length : integer) return unsigned;
  function repl2w64(v : std_logic_vector) return std_logic_vector;
  function minimum(x : integer; y: integer) return integer;
  function maximum(x : integer; y: integer) return integer;
  function make_0to(v : std_logic_vector) return std_logic_vector;
  function make_downto0(v : std_logic_vector) return std_logic_vector;
  function make_same(v        : std_logic_vector;
                     template : std_logic_vector) return std_logic_vector;
  function fit0ext(s_in : std_logic_vector; d_in : std_logic_vector) return std_logic_vector;
  function fit0ext(s_in : std_logic_vector; length : integer) return std_logic_vector;
  function fit0ext(s_in : unsigned; d_in : std_logic_vector) return std_logic_vector;

end;

package body utilnv is

  function cond(c : boolean;
                t : std_ulogic;
                f : std_ulogic) return std_ulogic is
  begin
    if c then
      return t;
    else
      return f;
    end if;
  end;

  function cond(c : boolean;
                t : std_logic_vector;
                f : std_logic_vector) return std_logic_vector is
  begin
    if c then
      return t;
    else
      return f;
    end if;
  end;

  function cond(c : boolean;
                t : integer;
                f : integer) return integer is
  begin
    if c then
      return t;
    else
      return f;
    end if;
  end;

  function is_set(v : integer) return boolean is
  begin
    return v /= 0;
  end;

  function tost(v : unsigned) return string is
  begin
-- pragma translate_off
    return tost(std_logic_vector(v));
-- pragma translate_on
    return "";
  end;

  function tost(v : signed) return string is
  begin
-- pragma translate_off
    return tost(std_logic_vector(v));
-- pragma translate_on
    return "";
  end;

  function tost(v : bit_vector) return string is
  begin
-- pragma translate_off
    return tost(to_stdlogicvector(v));
-- pragma translate_on
    return "";
  end;

  procedure log(enabled : boolean; comment : string) is
  begin
-- pragma translate_off
    if enabled then
      print(comment);
    end if;
-- pragma translate_on
  end;

  function no_x(v        : std_logic_vector;
                all_zero : boolean := false) return std_logic_vector is
    -- Non-constant
    variable r : std_logic_vector(v'range) := v;
  begin
-- pragma translate_off
    if is_x(v) then
      if all_zero then
        r := (others => '0');
      else
        for i in r'range loop
          if r(i) /= '0' and r(i) /= '1' then
            r(i) := '0';
          end if;
        end loop;
      end if;
    end if;
-- pragma translate_on

    return r;
  end;

  function no_x(v        : signed;
                all_zero : boolean := false) return signed is
  begin
    return signed(no_x(std_logic_vector(v), all_zero));
  end;

  function no_x(v        : unsigned;
                all_zero : boolean := false) return unsigned is
  begin
    return unsigned(no_x(std_logic_vector(v), all_zero));
  end;

  function all_1(data : std_logic_vector) return boolean is
  begin
    return data = (data'length - 1 downto 0 => '1');
  end;

  function all_0(data : std_logic_vector) return boolean is
  begin
    return data = (data'length - 1 downto 0 => '0');
  end;

  function all_0(data : signed) return boolean is
  begin
    return all_0(std_logic_vector(data));
  end;

  function all_1(data : signed) return boolean is
  begin
    return all_1(std_logic_vector(data));
  end;

  function all_0(data : unsigned) return boolean is
  begin
    return all_0(std_logic_vector(data));
  end;

  function all_1(data : unsigned) return boolean is
  begin
    return all_1(std_logic_vector(data));
  end;

  function all_0(data : std_logic_vector) return std_logic is
  begin
    return to_bit(all_0(data));
  end;

  function all_1(data : std_logic_vector) return std_logic is
  begin
    return to_bit(all_1(data));
  end;

  function single_1(data : std_logic_vector) return boolean is
  begin
    return all_0(data and uadd(data, -1)) and not all_0(data);
  end;

  function to_bit(v : boolean) return std_ulogic is
  begin
    if v then
      return '1';
    else
      return '0';
    end if;
  end;

  function to_bit(v : integer) return std_ulogic is
  begin
    if v = 0 then
      return '0';
    end if;

    return '1';
  end;

  function repl2w64(v : std_logic_vector) return std_logic_vector is
    constant v_v : std_logic_vector(v'length * 2 - 1 downto 0) := v & v;
  begin
    if v'length = 64 then
      return v;
    end if;

    return v_v(63 downto 0);
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
    assert data'length <= 31 report "Data too large for integer" severity failure;
    if notx(data) then
      return to_integer(unsigned(data));
    else
      return 0;
    end if;
  end;

  function u2i(data : bit_vector) return integer is
  begin
    assert data'length <= 31 report "Data too large for integer" severity failure;
    return to_integer(unsigned(to_stdlogicvector(data)));
  end;

  function u2i(data : std_logic) return integer is
    variable v : std_logic_vector(0 downto 0) := (others => data);
  begin
    return u2i(v);
  end;

  function u2i(data : boolean) return integer is
    variable v : std_ulogic := to_bit(data);
  begin
    return u2i(v);
  end;

  function u2i(data : unsigned) return integer is
  begin
    return u2i(std_logic_vector(data));
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

  function s2i(data : std_logic) return integer is
    variable v : std_logic_vector(0 downto 0) := (others => data);
  begin
    return s2i(v);
  end;

  function s2i(data : signed) return integer is
  begin
    if notx(data) then
      return to_integer(data);
    else
      return 0;
    end if;
  end;

  function b2i(data : boolean) return integer is
  begin
    return u2i(to_bit(data));
  end;

  -- Sign-extend
  function sext(v : std_logic_vector; length : integer) return std_logic_vector is
    variable v_normal : std_logic_vector(v'length - 1 downto 0) := v;
    -- Non-constant
    variable ext      : std_logic_vector(length - 1 downto 0) := (others => '0');
  begin
    assert v'length <= length report "Value larger than given length" severity failure;
    if v_normal'length > 0 then
      ext := (others => v_normal(v_normal'high));
      ext(v_normal'range) := v;
    end if;

    return ext;
  end;

  function sext(v : signed; length : integer) return std_logic_vector is
  begin
    return sext(std_logic_vector(v), length);
  end;

  function sext(v : std_logic_vector; template : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable ext : std_logic_vector(template'range);
  begin
    ext := sext(v, template'length);

    return ext;
  end;

  function sext(v : signed; template : std_logic_vector) return std_logic_vector is
  begin
    return sext(std_logic_vector(v), template);
  end;


  -- Zero-extend
  function uext(v : std_logic_vector; length : integer) return std_logic_vector is
    variable v_normal : std_logic_vector(v'length - 1 downto 0) := v;
    -- Non-constant
    variable ext      : std_logic_vector(length - 1 downto 0)   := (others => '0');
  begin
    assert v'length <= length report "Value larger than given length" severity failure;
    ext(v_normal'range) := v;

    return ext;
  end;

  function uext(v : unsigned; length : integer) return std_logic_vector is
  begin
    return uext(std_logic_vector(v), length);
  end;

  function uext(v : unsigned; length : integer) return unsigned is
  begin
    return unsigned(uext(std_logic_vector(v), length));
  end;

  function uext(v : std_logic_vector; template : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable ext : std_logic_vector(template'range);
  begin
    ext := uext(v, template'length);

    return ext;
  end;

  function uext(v : unsigned; template : std_logic_vector) return std_logic_vector is
  begin
    return uext(std_logic_vector(v), template);
  end;

  function uext(v : unsigned; template : unsigned) return unsigned is
  begin
    return unsigned(uext(std_logic_vector(v), std_logic_vector(template)));
  end;

  -- Return data interpreted as unsigned, as bits of std_logic_vector.
  function u2slv(data : integer; bits : integer) return std_logic_vector is
    -- Non-constant
    variable v : std_logic_vector(bits - 1 downto 0);
  begin
    v := std_logic_vector(to_unsigned(data, bits));

    return v;
  end;

  -- Return data interpreted as unsigned, as bits of unsigned.
  function u2vec(data : integer; bits : integer) return unsigned is
    -- To avoid DC complaints about truncation when converting from
    -- integer to a smaller type, first do a "safe" conversion.
    variable xlen : integer                     := maximum(32, bits);
    variable u    : unsigned(xlen - 1 downto 0) := to_unsigned(data, xlen);
    -- Non-constant
    variable v    : unsigned(bits - 1 downto 0);
  begin
    v := u(v'range);

    return v;
  end;

  function u2vec(data : integer; template : unsigned) return unsigned is
  begin
    return u2vec(data, template'length);
  end;

  -- Return data interpreted as unsigned, as bits of std_logic_vector.
  function u2vec(data : integer; bits : integer) return std_logic_vector is
    variable u : unsigned(bits - 1 downto 0) := u2vec(data, bits);
  begin
    return std_logic_vector(u);
  end;

  function u2vec(data : integer; template : std_logic_vector) return std_logic_vector is
  begin
    return u2vec(data, template'length);
  end;

  function u2vec(data : boolean; bits : integer) return std_logic_vector is
  begin
    return u2vec(u2i(data), bits);
  end;

  function u2vec(data : boolean; template : std_logic_vector) return std_logic_vector is
  begin
    return u2vec(data, template'length);
  end;

  function s2vec(data : integer; bits : integer) return signed is
    -- To avoid DC complaints about truncation when converting from
    -- integer to a smaller type, first do a "safe" conversion.
    variable xlen : integer                   := maximum(32, bits);
    variable s    : signed(xlen - 1 downto 0) := to_signed(data, xlen);
    -- Non-constant
    variable v    : signed(bits - 1 downto 0);
  begin
    v := s(v'range);

    return v;
  end;

  function s2vec(data : integer; template : signed) return signed is
  begin
    return s2vec(data, template'length);
  end;

  -- Return data interpreted as signed, as bits of std_logic_vector.
  function s2vec(data : integer; bits : integer) return std_logic_vector is
    variable s : signed(bits - 1 downto 0) := s2vec(data, bits);
  begin
    return std_logic_vector(s);
  end;

  function s2vec(data : integer; template : std_logic_vector) return std_logic_vector is
  begin
    return s2vec(data, template'length);
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

  function uadd(src : std_logic_vector; addend_in : integer) return std_logic_vector is
    -- To avoid GHDL complaints about truncation when converting from
    -- integer to a smaller type, first do a "safe" conversion.
    variable xlen   : integer                   := maximum(32, src'length);
    variable s      : signed(xlen - 1 downto 0) := to_signed(addend_in, xlen);
    variable addend : signed(src'range)         := s(src'length - 1 downto 0);
    -- Non-constant
    variable dst    : signed(src'range)         := signed(src);
  begin
    dst := dst + addend;

    return std_logic_vector(dst);
  end;

  function uadd(src : std_logic_vector; addend : std_logic_vector) return unsigned is
    -- Non-constant
    variable dst : unsigned(src'length - 1 downto 0);
  begin
    dst := unsigned(src) + unsigned(addend);

    return dst;
  end;

  function uadd(src : std_logic_vector; addend : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable dst : unsigned(src'range) := uadd(src, addend);
  begin
    return std_logic_vector(dst);
  end;

  function uaddx(src : std_logic_vector; addend_in : integer) return std_logic_vector is
    variable addend : signed(src'length downto 0) := to_signed(addend_in, src'length + 1);
    -- Non-constant
    variable dst    : signed(src'length downto 0) := signed('0' & src);
  begin
    dst := dst + addend;

    return std_logic_vector(dst);
  end;

  function uaddx(src : std_logic_vector; addend : std_logic_vector) return unsigned is
    -- Non-constant
    variable dst : unsigned(src'length downto 0);
  begin
    dst := unsigned('0' & src) + unsigned('0' & addend);

    return dst;
  end;

  function uaddx(src : unsigned; addend : unsigned) return unsigned is
    -- Non-constant
    variable dst : unsigned(src'length downto 0);
  begin
    dst := ('0' & src) + ('0' & addend);

    return dst;
  end;

  function uaddx(src : std_logic_vector; addend : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable dst : unsigned(src'length downto 0) := uaddx(src, addend);
  begin
    return std_logic_vector(dst);
  end;

  function usub(src : std_logic_vector; subtrahend_in : integer) return std_logic_vector is
    variable subtrahend : signed(src'range) := to_signed(subtrahend_in, src'length);
    -- Non-constant
    variable dst        : signed(src'range) := signed(src);
  begin
    dst := dst - subtrahend;

    return std_logic_vector(dst);
  end;

  function usub(src : std_logic_vector; subtrahend : std_logic_vector) return unsigned is
    -- Non-constant
    variable dst : unsigned(src'range);
  begin
    dst := unsigned(src) - unsigned(subtrahend);

    return dst;
  end;

  function usub(src : std_logic_vector; subtrahend : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable dst : unsigned(src'range) := usub(src, subtrahend);
  begin
    return std_logic_vector(dst);
  end;

  function usubx(src : std_logic_vector; subtrahend : std_logic_vector) return unsigned is
    -- Non-constant
    variable dst : unsigned(src'length downto 0);
  begin
    dst := unsigned('0' & src) - unsigned('0' & subtrahend);

    return dst;
  end;

  function usubx(src : unsigned; subtrahend : std_logic_vector) return unsigned is
    -- Non-constant
    variable dst : unsigned(src'length downto 0) := usubx(std_logic_vector(src), subtrahend);
  begin
    return dst;
  end;

  function usubx(src : std_logic_vector; subtrahend : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable dst : unsigned(src'length downto 0) := usubx(src, subtrahend);
  begin
    return std_logic_vector(dst);
  end;

  function get_slv(d : std_ulogic; template : std_logic_vector) return std_logic_vector is
    variable v : std_logic_vector(template'range) := (others => d);
  begin
    return v;
  end;

  function get_slv(d : std_ulogic; bits : integer) return std_logic_vector is
    variable v : std_logic_vector(bits - 1 downto 0) := (others => d);
  begin
    return v;
  end;

  function get_zeros(template : std_logic_vector) return std_logic_vector is
  begin
    return get_slv('0', template);
  end;

  function get_zeros(bits : integer) return std_logic_vector is
  begin
    return get_slv('0', bits);
  end;

  function get_ones(template : std_logic_vector) return std_logic_vector is
  begin
    return get_slv('1', template);
  end;

  function get_ones(bits : integer) return std_logic_vector is
  begin
    return get_slv('1', bits);
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

  function get(data  : std_logic_vector;
               start : integer; template : std_logic_vector) return std_logic_vector is
  begin
    return get(data, start, template'length);
  end;

  function get(data  : unsigned;
               start : integer; bits : integer) return unsigned is
  begin
    return unsigned(get(std_logic_vector(data), start, bits));
  end;

  function get(data  : signed;
               start : integer; bits : integer) return signed is
  begin
    return signed(get(std_logic_vector(data), start, bits));
  end;

  -- Return high bits from data.
  function get_hi(data : std_logic_vector;
                  bits : integer) return std_logic_vector is
  begin
    if bits >= 0 then
      return get(data, data'high - bits + 1, bits);
    else
      return get(data, data'low - bits, data'length + bits);
    end if;
  end;

  -- Return high bit from data.
  function get_hi(data : std_logic_vector) return std_logic is
  begin
    return data(data'high);
  end;

  function get_hi(data : signed) return std_logic is
  begin
    return get_hi(std_logic_vector(data));
  end;

  function get_hi(data : unsigned) return std_logic is
  begin
    return get_hi(std_logic_vector(data));
  end;

  -- Return low bits from data.
  function get_lo(data : std_logic_vector;
                  bits : integer) return std_logic_vector is
  begin
    if bits >= 0 then
      return get(data, data'low, bits);
    else
      return get(data, data'low, data'length + bits);
    end if;
  end;

  function get_lo(data : unsigned;
                  bits : integer) return unsigned is
  begin
    return unsigned(get_lo(std_logic_vector(data), bits));
  end;

  function get_lo(data : signed;
                  bits : integer) return signed is
  begin
    return signed(get_lo(std_logic_vector(data), bits));
  end;

  -- Same as get_lo(), except for "normalized" vector direction (n downto 0).
  function get_right(data_in : std_logic_vector;
                     bits    : integer) return std_logic_vector is
    variable data : std_logic_vector(data_in'length - 1 downto 0) := data_in;
  begin
    return get_lo(data, bits);
  end;

  function get_right(data_in  : std_logic_vector;
                     template : std_logic_vector) return std_logic_vector is
    variable data : std_logic_vector(data_in'length - 1 downto 0) := data_in;
  begin
    return get_lo(data, template'length);
  end;

  -- Same as get_hi(), except for "normalized" vector direction (n downto 0).
  function get_left(data_in : std_logic_vector;
                    bits    : integer) return std_logic_vector is
    variable data : std_logic_vector(data_in'length - 1 downto 0) := data_in;
  begin
    return get_hi(data, bits);
  end;

  function get_left(data_in  : std_logic_vector;
                    template : std_logic_vector) return std_logic_vector is
    variable data : std_logic_vector(data_in'length - 1 downto 0) := data_in;
  begin
    return get_hi(data, template'length);
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

  function set(src  : std_logic_vector; start : integer;
               data : std_logic_vector) return std_logic_vector is
    constant bits : integer := data'length;
    -- Non-constant
    variable dest : std_logic_vector(src'length - 1 downto 0) := src;
  begin
    dest(start + bits - 1 downto start) := data;

    return dest;
  end;

  function set(data : std_logic_vector; n : integer) return std_logic_vector is
    -- Non-constant
    variable res : std_logic_vector(data'range) := data;
  begin
    res(n) := '1';

    return res;
  end;

  -- Sets high data in dest.
  procedure set_hi(dest : inout std_logic_vector;
                   data : std_logic_vector) is
    constant bits : integer := data'length;
  begin
    set(dest, dest'high - bits + 1, data);
  end;

  procedure set_hi(dest : inout std_logic_vector;
                   d    : std_logic) is
    variable data : std_logic_vector(0 downto 0) := (others => d);
  begin
    set_hi(dest, data);
  end;

  -- Sets low data in dest.
  procedure set_lo(dest : inout std_logic_vector;
                   data : std_logic_vector) is
    constant bits : integer := data'length;
  begin
    set(dest, dest'low, data);
  end;

  -- Return lower half of input.
  function lo_h(v : std_logic_vector) return std_logic_vector is
    variable v_normal : std_logic_vector(v'length - 1 downto 0) := v;
  begin
-- pragma translate_off
    assert v'length mod 2 = 0
      report "lo_h only works for items with even number of bits (" & tost(v'length) & ")"
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
      report "hi_h only works for items with even number of bits (" & tost(v'length) & ")"
      severity failure;
-- pragma translate_on
    return v_normal(v'length - 1 downto v'length / 2);
  end;

  function make_0to(v : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable r : std_logic_vector(0 to v'length - 1);
  begin
    for i in v'range loop
      r(i) := v(i);
    end loop;

    return r;
  end;

  function make_downto0(v : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable r : std_logic_vector(v'length - 1 downto 0);
  begin
    for i in v'range loop
      r(i) := v(i);
    end loop;

    return r;
  end;

  function make_same(v        : std_logic_vector;
                     template : std_logic_vector) return std_logic_vector is
  begin
    if template'ascending then
      return make_0to(v);
    else
      return make_downto0(v);
    end if;
  end;

  -- Cut down or zero extend source to fit destination
  function fit0ext(s_in : std_logic_vector; d_in : std_logic_vector) return std_logic_vector is
    variable s : std_logic_vector(s_in'length - 1 downto 0) := s_in;
    variable d : std_logic_vector(d_in'length - 1 downto 0) := d_in;
    -- Non-constant
    variable r : std_logic_vector(d'range)                  := (others => '0');
  begin
    if d'length > s'length then
      r(s'range) := s;
    else
      r          := s(r'range);
    end if;

    return r;
  end;

  function fit0ext(s_in : std_logic_vector; length : integer) return std_logic_vector is
    variable d : std_logic_vector(length - 1 downto 0) := (others => '0');
  begin
    return fit0ext(s_in, d);
  end;

  function fit0ext(s_in : unsigned; d_in : std_logic_vector) return std_logic_vector is
  begin
    return fit0ext(std_logic_vector(s_in), d_in);
  end;

end;
