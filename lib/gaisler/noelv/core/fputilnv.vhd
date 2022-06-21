------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity:      fputilnv
-- File:        fputilnv.vhd
-- Author:      Magnus Hjorth and Johan Klockars, Cobham Gaisler
-- Description: Support stuff for the different NOEL-V FPU:s,
--              broken out from earlier version of nanoFPUnv.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use grlib.config.all;
use grlib.config_types.all;
use grlib.riscv.all;
library gaisler;
use gaisler.utilnv.all;

package fputilnv is

  constant fpulen : integer := 64;  -- qqq Should not be here!

  subtype word8  is std_logic_vector( 7 downto 0);
--  subtype word16 is std_logic_vector(15 downto 0);
  subtype word64 is std_logic_vector(63 downto 0);
  subtype word   is std_logic_vector(31 downto 0);
--  subtype wordx  is std_logic_vector(XLEN - 1 downto 0);

  subtype regno_t   is std_logic_vector(4 downto 0);
  type    regno_arr is array (integer range <>) of regno_t;

--  constant zerow16      : word16 := (others => '0');
  constant zerow64      : word64 := (others => '0');
--  constant onesw64      : word64 := (others => '1');
--  constant zerox        : wordx  := (others => '0');
--  constant zerow        : word   := (others => '0');

  subtype  rm_t       is std_logic_vector(2 downto 0);
  constant R_NEAREST   : rm_t := "000";  -- RNE Nearest, ties to even
  constant R_ZERO      : rm_t := "001";  -- RTZ Towards zero
  constant R_MINUS_INF : rm_t := "010";  -- RDN Down, towards negative infinity
  constant R_PLUS_INF  : rm_t := "011";  -- RUP Up, towards positive infinity
  constant R_RMM       : rm_t := "100";  -- Nearest, ties to max magnitude
  -- The rest are illegal, except that in an instruction "111" (DYN)
  -- means that rouding mode should be fetched from CSR register.

  -- Floating point flags
  constant EXC_NX : integer := 0;  -- Inexact
  constant EXC_UF : integer := 1;  -- Underflow
  constant EXC_OF : integer := 2;  -- Overflow
  constant EXC_DZ : integer := 3;  -- Divide by zero
  constant EXC_NV : integer := 4;  -- Invalid


  constant C_NORMAL : std_logic_vector(1 downto 0) := "00";
  constant C_ZERO   : std_logic_vector(1 downto 0) := "01";
  constant C_NAN    : std_logic_vector(1 downto 0) := "10";
  constant C_INF    : std_logic_vector(1 downto 0) := "11";

  type fpuop_t is (FPU_UNKNOWN,
                   FPU_ADD, FPU_SUB, FPU_MIN, FPU_SGN, FPU_CVT_S_D,
                   FPU_MUL,
                   FPU_STORE, FPU_CVT_W_S, FPU_MV_X_W, FPU_CMP,
                   FPU_LOAD, FPU_CVT_S_W,  FPU_MV_W_X,
                   FPU_MADD, FPU_MSUB, FPU_NMSUB, FPU_NMADD,
                   FPU_DIV, FPU_SQRT);

  type float is record
-- pragma translate_off
    v        : real;
-- pragma translate_on
    w        : word64;
    class    : std_logic_vector(1 downto 0);  -- See C_ above.
    snan     : boolean;  -- Signaling NaN if C_NAN
    neg      : boolean;
    exp      : signed(12 downto 0);
    -- Normally implicit 1 at bit 54
    --  53:2 mantissa bits    53:31 for SP
    --   1:0 guard bits for rounding
    mant     : std_logic_vector(55 downto 0);
  end record;

  type float_arr is array (integer range <>) of float;

  constant float_none : float := (
-- pragma translate_off
    0.0,
-- pragma translate_on
    (others => '0'), C_NORMAL, false, false,
    (others => '0'), (others => '0'));
  constant float_one : float := (
-- pragma translate_off
    1.0,
-- pragma translate_on
    x"ffffffff3f800000", C_NORMAL, false, false,  -- single precision 1.0
    (others => '0'), (54 => '1', others => '0'));

  subtype fpu_id is std_logic_vector(4 downto 0);

  type fpunv_op is record
    valid : std_ulogic;
    op    : fpuop_t;  -- std_logic_vector(4 downto 0);  -- FPU operation
    opx   : std_logic_vector(2 downto 0);  --   extension
    rm    : rm_t;                          -- Rounding mode
    sp    : std_ulogic;                    -- Single precision
    rd    : regno_t;
    rs    : regno_arr(1 to 3);
    ren   : std_logic_vector(1 to 3);
  end record;

  type fpuevent_t is (
    FPEVT_HOLD         ,  --  Hold issue
    FPEVT_AWAIT_FORWARD,  --  Await muladd pipe forwarding
    FPEVT_AWAIT_RD     ,  --  Await Rd clash resolve
    FPEVT_AWAIT_FREE   ,  --  Await divsqrt pipe free
    FPEVT_AWAIT_RS     ,  --  Await Rs results
    FPEVT_ISSUE        ,  --  Issue operation
    FPEVT_COMMIT       ,  --  Commit operation
    FPEVT_MULADD_PIPE  ,  --  Finish muladd pipeline
    FPEVT_DIVSQRT_UNIT ,  --  Finish divsqrt unit
    FPEVT_PICK_RD      ,  --  Pick Rs from current Rd
    FPEVT_RD_UNISSUE   ,  --  Unissue instruction with Rd
    FPEVT_UNISSUE_2ND  ,  --  Unissue in second stage
    FPEVT_UNISSUE_1ST  ,  --  Unissue in first stage
    FPEVT_UNISSUE_QUEUE,  --  Unissue in queue
    FPEVT_UNISSUE_RD   ,  --  Unissue due to Rd cancel
    FPEVT_EARLY_DATA   ,  --  Early data from IU
    FPEVT_LOAD         ,  --  load
    FPEVT_STORE        ,  --  store
    FPEVT_DIV          ,  --  div
    FPEVT_SQRT         ,  --  sqrt
    FPEVT_MADD         ,  --  madd / msub / nmsub / nmadd
    FPEVT_MUL          ,  --  mul
    FPEVT_ADD          ,  --  add / sub
    FPEVT_MINMAX       ,  --  min / max
    FPEVT_SGN          ,  --  sgn
    FPEVT_EQ           ,  --  eq
    FPEVT_CMP          ,  --  lt le
    FPEVT_CLASS        ,  --  class
    FPEVT_S2D          ,  --  s->d
    FPEVT_D2S          ,  --  d->s
    FPEVT_I2F          ,  --  i->f
    FPEVT_F2I          ,  --  f->i
    FPEVT_X2F          ,  --  x->f
    FPEVT_F2X          ,  --  f->x
    FPEVT_UNKNOWN      ,  --  Should never happen!
    FPEVT_EVENTS          -- Only for fpevt_t type!
  );

  subtype fpevt_t is std_logic_vector(1 to fpuevent_t'pos(FPEVT_EVENTS));
  function fpu_event(evt : fpuevent_t) return integer;
  procedure fpu_event(events : inout fpevt_t; evt : fpuevent_t);

  function is_signan(op : float) return boolean;
  function is_inf(op : float) return boolean;
  function is_nan(op : float) return boolean;
  function is_zero(op : float) return boolean;
  function is_one(op : float) return boolean;
  function is_normal(op : float) return boolean;
  function is_neg(op : float) return boolean;

  function to_float(data : std_logic_vector; fmt : std_logic_vector) return float;
  function to_float_ext(data : std_logic_vector) return float;

  function tost(op : fpuop_t) return string;

-- pragma translate_off
  function tost(f : float) return string;
  function fpreg2st(v : std_logic_vector) return string;
  procedure show_float(text : string; reg : std_logic_vector; v : std_logic_vector);
-- pragma translate_on

  function truncate(v : real) return integer;
  function log2(v : real) return integer;
  function r2u(f_in : real; bits : integer) return unsigned;
  function s2r(data : std_logic_vector) return real;
  function u2r(data : std_logic_vector) return real;

  function has_decimals(f_in : real) return std_ulogic;

  function inf_mul(a : float; b : float) return float;
  function inf_neg(a : float) return float;
  function mul_illegal(a : float; b : float) return boolean;
  function add_illegal(a : float; b : float) return boolean;

  function NaN(fmt : std_logic_vector) return std_logic_vector;
  function NaN(dp : boolean) return std_logic_vector;
  function Inf(fmt : std_logic_vector) return std_logic_vector;
  function Inf(dp : boolean) return std_logic_vector;

-- pragma translate_off
  function from_real(f_in : real; fmt : std_logic_vector) return std_logic_vector;
  function from_real_ext(f : real; fmt : std_logic_vector) return std_logic_vector;
  function from_float(v : float; fmt : std_logic_vector) return std_logic_vector;
-- pragma translate_on

  procedure fpu_gen(inst        : in  word;
                    csr_frm     : in  rm_t;
                    valid_in    : in  std_ulogic;
                    op_out      : out fpunv_op);
  function fs1_gen(inst : word) return std_ulogic;
  function fs2_gen(inst : word) return std_ulogic;
  function fs3_gen(inst : word) return std_ulogic;

  function is_add(op : fpuop_t) return boolean;
  function is_mul(op : fpuop_t) return boolean;
  function is_fromint(op : fpuop_t) return boolean;
  function fd_gen(op : fpuop_t) return boolean;

  function is_fpu(inst : word) return boolean;
  function is_fpu_mem(inst : word) return boolean;
  function is_fpu_from_int(inst : word) return boolean;
  function is_fpu_rd(inst : word) return boolean;
  function is_fpu_modify(inst : word) return boolean;

  function find_normadj(op     : float;
                        limdp  : boolean; limsp : boolean;
                        mkeven : boolean) return signed;
  function unpack(opu : word64; dp  : boolean) return float;
  function pack(op : float; dp : boolean) return std_logic_vector;
  procedure adjust_new(mant_in    : std_logic_vector(55 downto 0);
                       vadj       : signed(6 downto 0);
                       manthi_out : out std_logic_vector(65 downto 56);
                       mant_out   : out std_logic_vector(55 downto 0);
                       mant0b_out : out std_logic_vector(0 to 1));
  procedure adjust_new(mant_in    : std_logic_vector(55 downto 0);
                       vadj       : signed(6 downto 0);
                       mant_out   : out std_logic_vector(55 downto 0);
                       mant0b_out : out std_logic_vector(0 to 1));
  procedure roundup(op2 : float; dp : boolean; rm : rm_t;
                    rndup_out : out boolean; rndbits_out : out std_logic_vector(2 downto 0));

end;

package body fputilnv is

  function fpu_event(evt : fpuevent_t) return integer is
  begin
    return fpuevent_t'pos(evt) + 1;
  end;

  procedure fpu_event(events : inout fpevt_t; evt : fpuevent_t) is
  begin
    events(fpu_event(evt)) := '1';
  end;

  function is_normal(op : float) return boolean is
  begin
    return op.class = C_NORMAL;
  end;

  function is_neg(op : float) return boolean is
  begin
    return op.neg;
  end;

  function is_zero(op : float) return boolean is
  begin
    return op.class = C_ZERO;
  end;

  function is_one(op : float) return boolean is
  begin
    return is_normal(op) and not is_neg(op) and s2i(op.exp) = 0 and
           op.mant(op.mant'high downto op.mant'high - 1) = "01" and
           u2i(op.mant(op.mant'high - 1 downto 0)) = 0;
  end;

  function is_nan(op : float) return boolean is
  begin
    return op.class = C_NAN;
  end;

  function is_inf(op : float) return boolean is
  begin
    return op.class = C_INF;
  end;

  -- Signaling NaN?
  function is_signan(op : float) return boolean is
  begin
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
-- pragma translate_off
    variable f          : real;
-- pragma translate_on
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

-- pragma translate_off
    sign    := 1.0;
-- pragma translate_on
    if data(frac_bits + exp_bits) = '1' then
-- pragma translate_off
      sign  := -1.0;
-- pragma translate_on
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
        if data(frac_bits - 1) = '0' then   -- Signaling NaN?
          r.snan := true;
        end if;
        return r;
      end if;
    end if;

    frac        := u2i(data(frac_bits - 1 downto frac_bits - 23));
    if frac = 0 then
      r.class   := C_ZERO;
    end if;
-- pragma translate_off
    f           := real(frac) / 2.0 ** 23;
-- pragma translate_on
    if frac_bits > 23 then
      frac      := u2i(data(frac_bits - 23 - 1 downto 0));
      if frac /= 0 then
        r.class := C_NORMAL;
      end if;
-- pragma translate_off
      f         := f + real(frac) / 2.0 ** frac_bits;
-- pragma translate_on
    end if;

    -- Exponent all 0 - subnormal
    if exp = 0 then
-- pragma translate_off
      f       := f * 2.0 ** (1 - (exp_max - 1) / 2);
-- pragma translate_on
      r.exp   := to_signed(-(exp_max - 1) / 2, r.exp'length);
      r.mant  := (others => '0');
      r.mant(53 downto 53 - frac_bits + 1) := data(frac_bits - 1 downto 0);
      if notx(r.mant) and not all_0(r.mant) then
        loop
          if r.mant(54) = '1' then
            exit;
          end if;
          r.exp  := r.exp - 1;
          r.mant := r.mant(r.mant'high - 1 downto 0) & '0';
        end loop;
      end if;
    else
      r.class := C_NORMAL;
-- pragma translate_off
      -- ModelSim does not like assigmnents outside -1e308 and 1e308,
      -- but a real can actually be there...
      if (1.0 + f) * 2.0 ** (exp - (exp_max - 1) / 2) > 1.0e308 then
        f := 1.0e308;
      elsif (1.0 + f) * 2.0 ** (exp - (exp_max - 1) / 2) < -1.0e308 then
        f := -1.0e308;
      else
        f       := (1.0 + f) * 2.0 ** (exp - (exp_max - 1) / 2);
      end if;
-- pragma translate_on
      r.exp   := to_signed(u2i(data(frac_bits + exp_bits - 1 downto frac_bits)) -
                           (exp_max - 1) / 2, r.exp'length);
      r.mant  := (others => '0');
      r.mant(54) := '1';
      r.mant(53 downto 53 - frac_bits + 1) := data(frac_bits - 1 downto 0);
    end if;

-- pragma translate_off
    f := sign * f;

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

  function fpreg2st(v : std_logic_vector) return string is
    variable reg : regno_t;
  begin
    reg := v;
    case reg(4 downto 0) is
      when FPU_FT0      => return("ft0");
      when FPU_FT1      => return("ft1");
      when FPU_FT2      => return("ft2");
      when FPU_FT3      => return("ft3");
      when FPU_FT4      => return("ft4");
      when FPU_FT5      => return("ft5");
      when FPU_FT6      => return("ft6");
      when FPU_FT7      => return("ft7");
      when FPU_FS0      => return("fs0");
      when FPU_FS1      => return("fs1");
      when FPU_FA0      => return("fa0");
      when FPU_FA1      => return("fa1");
      when FPU_FA2      => return("fa2");
      when FPU_FA3      => return("fa3");
      when FPU_FA4      => return("fa4");
      when FPU_FA5      => return("fa5");
      when FPU_FA6      => return("fa6");
      when FPU_FA7      => return("fa7");
      when FPU_FS2      => return("fs2");
      when FPU_FS3      => return("fs3");
      when FPU_FS4      => return("fs4");
      when FPU_FS5      => return("fs5");
      when FPU_FS6      => return("fs6");
      when FPU_FS7      => return("fs7");
      when FPU_FS8      => return("fs8");
      when FPU_FS9      => return("fs9");
      when FPU_FS10     => return("fs10");
      when FPU_FS11     => return("fs11");
      when FPU_FT8      => return("ft8");
      when FPU_FT9      => return("ft9");
      when FPU_FT10     => return("ft10");
      when FPU_FT11     => return("ft11");
      when others       => return("XXXX");
    end case;
  end;

  procedure show_float(text : string; reg : std_logic_vector; v : std_logic_vector) is
  variable f : float := to_float_ext(v);
  begin
    case f.class is
      when C_NORMAL =>
        if f.v > 1.0e307 then
          report text & " " & tost(reg) & " " & tost(v) & " > 1.0e307";
        elsif f.v < -1.0e307 then
          report text & " " & tost(reg) & " " & tost(v) & " < -1.0e307";
        else
          report text & " " & tost(reg) & " " & tost(v) & " " & tost(f.v);
        end if;
      when others   =>
        report text & " " & tost(reg) & " " & tost(v);
    end case;
  end;
-- pragma translate_on


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
    elsif data'length = 64 then
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
    else
      assert false report "Bad data size!" severity failure;
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

  -- This is the canonical NaN.
  function NaN(fmt : std_logic_vector) return std_logic_vector is
  begin
    if fmt = "01" then
      return x"7ff8000000000000";
    else
      return x"ffffffff7fc00000";
    end if;
  end;

  function NaN(dp : boolean) return std_logic_vector is
  begin
    return NaN("0" & to_bit(dp));
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

  function Inf(dp : boolean) return std_logic_vector is
  begin
    return Inf("0" & to_bit(dp));
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
-- pragma translate_on

  -- FPU Signals Generation

  -- Partial decode of FPU operation
  function fpuop(inst : word) return fpuop_t is
    variable opcode : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
    -- Non-constant
    variable op     : std_logic_vector(4 downto 0);
  begin
    case opcode is
      when OP_FP       =>
        case funct5 is
        when R_FADD     => return FPU_ADD;
        when R_FSUB     => return FPU_SUB;
        when R_FMINMAX  => return FPU_MIN;
        when R_FSGN     => return FPU_SGN;
        when R_FCVT_S_D => return FPU_CVT_S_D;
        when R_FMUL     => return FPU_MUL;
        when R_FCVT_W_S => return FPU_CVT_W_S;
        when R_FMV_X_W  => return FPU_MV_X_W;
        when R_FCMP     => return FPU_CMP;
        when R_FCVT_S_W => return FPU_CVT_S_W;
        when R_FMV_W_X  => return FPU_MV_W_X;
        when R_FDIV     => return FPU_DIV;
        when R_FSQRT    => return FPU_SQRT;
        when others     => return FPU_UNKNOWN;
        end case;
      when OP_LOAD_FP   => return FPU_LOAD;
      when OP_STORE_FP  => return FPU_STORE;
      when OP_FMADD     => return FPU_MADD;
      when OP_FMSUB     => return FPU_MSUB;
      when OP_FNMADD    => return FPU_NMADD;
      when OP_FNMSUB    => return FPU_NMSUB;
      when others       => return FPU_UNKNOWN;
    end case;
  end;

  procedure fpu_gen(inst        : in  word;
                    csr_frm     : in  rm_t;
                    valid_in    : in  std_ulogic;
                    op_out      : out fpunv_op) is
    subtype word2  is std_logic_vector(1 downto 0);
    subtype word3  is std_logic_vector(2 downto 0);
    variable RFBITS : integer := 5;
    subtype rfatype is std_logic_vector(RFBITS-1 downto 0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable fmt    : word2       := inst(26 downto 25);
    variable rs1    : rfatype     := inst(19 downto 15);
    variable rs2    : rfatype     := inst(24 downto 20);
    variable rs3    : rfatype     := inst(31 downto 27);
    variable rd     : rfatype     := inst(11 downto  7);
    -- Non-constant
    variable op     : fpuop_t     := fpuop(inst);
    variable valid  : std_ulogic  := valid_in and to_bit(op /= FPU_UNKNOWN);
    variable rm     : rm_t        := funct3;
    variable sp     : boolean     := fmt = "00";      -- single precision
    variable ren    : std_logic_vector(1 to 3);
  begin
    if op = FPU_STORE or op = FPU_LOAD then
      sp := funct3 = "010";  -- 32 bit memory access?
    end if;

    -- CSR controlled rounding?
    if funct3 = "111" then
      rm := csr_frm;
    end if;

    ren(1) := fs1_gen(inst);
    ren(2) := fs2_gen(inst);
    ren(3) := fs3_gen(inst);

    op_out := (valid, op, funct3, rm, to_bit(sp), rd, (rs1, rs2, rs3), ren);
  end;

  -- Fs1 register validity check
  -- Returns '1' if the instruction has a valid FPU fs1 field.
  function fs1_gen(inst : word) return std_ulogic is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
    -- Non-constant
    variable vreg   : std_ulogic  := '1';
  begin
    case op is
      when OP_FMADD  | OP_FMSUB |
           OP_FNMSUB | OP_FNMADD =>
      when OP_FP =>
        case funct5 is
          when R_FCVT_S_W |
               R_FMV_W_X         => vreg := '0';
          when others            =>
        end case;
      when others                => vreg := '0';
    end case;

    return vreg;
  end;

  -- Fs2 register validity check
  -- Returns '1' if the instruction has a valid FPU fs2 field.
  function fs2_gen(inst : word) return std_ulogic is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
    -- Non-constant
    variable vreg   : std_ulogic  := '1';
  begin
    case op is
      when OP_STORE_FP |
           OP_FMADD    | OP_FMSUB |
           OP_FNMSUB   | OP_FNMADD =>
      when OP_FP =>
        case funct5 is
          when R_FCVT_S_W | R_FMV_W_X |
               R_FCVT_W_S | R_FMV_X_W |  -- Latter includes R_FCLASS
               R_FCVT_S_D |              -- Includes R_FCVT_D_S
               R_FSQRT             => vreg := '0';
          when others              =>
        end case;
      when others                  => vreg := '0';
    end case;

    return vreg;
  end;

  -- Fs3 register validity check
  -- Returns '1' if the instruction has a valid FPU fs3 field.
  function fs3_gen(inst : word) return std_ulogic is
    variable op   : opcode_type := inst(6 downto 0);
    -- Non-constant
    variable vreg : std_ulogic  := '1';
  begin
    case op is
      when OP_FMADD  | OP_FMSUB |
           OP_FNMSUB | OP_FNMADD =>
      when others                => vreg := '0';
    end case;

    return vreg;
  end;

  function is_add(op : fpuop_t) return boolean is
  begin
    return op = FPU_ADD or op = FPU_SUB or
           op = FPU_MADD or op = FPU_MSUB or op = FPU_NMADD or op = FPU_NMSUB;
  end;

  function is_mul(op : fpuop_t) return boolean is
  begin
    return op = FPU_MUL or
           op = FPU_MADD or op = FPU_MSUB or op = FPU_NMADD or op = FPU_NMSUB;
  end;

  -- Returns true if the instruction is int->float (no FPU source register).
  function is_fromint(op : fpuop_t) return boolean is
  begin
    return op = FPU_LOAD or op = FPU_MV_W_X or op = FPU_CVT_S_W;
  end;

  -- Fd register validity check
  -- Returns true if the instruction has a valid FPU fd field.
  function fd_gen(op : fpuop_t) return boolean is
  begin
    return op /= FPU_UNKNOWN and
           op /= FPU_CMP     and op /= FPU_STORE   and
           op /= FPU_MV_X_W  and op /= FPU_CVT_W_S;
  end;

  -- FPU instruction that does not touch memory?
  function is_fpu(inst : word) return boolean is
    variable op : fpuop_t := fpuop(inst);
  begin
    return op /= FPU_UNKNOWN and op /= FPU_LOAD and op /= FPU_STORE;
  end;

  -- FPU instruction that touches memory?
  function is_fpu_mem(inst : word) return boolean is
    variable op : fpuop_t := fpuop(inst);
  begin
    return op = FPU_LOAD or op = FPU_STORE;
  end;

  -- FPU instruction with data from integer pipeline?
  function is_fpu_from_int(inst : word) return boolean is
    variable op : fpuop_t := fpuop(inst);
  begin
    return is_fromint(op);
  end;

  -- FPU instruction with FPU destination register?
  function is_fpu_rd(inst : word) return boolean is
    variable op : fpuop_t := fpuop(inst);
  begin
    return fd_gen(op);
  end;

  -- FPU instruction can modify FPU state (including flags)?
  function is_fpu_modify(inst : word) return boolean is
    variable op : fpuop_t := fpuop(inst);
  begin
    return op /= FPU_UNKNOWN and op /= FPU_STORE and op /= FPU_MV_X_W;
  end;

  -- Find shift amount for normalization.
  function find_normadj(op     : float;
                        limdp  : boolean; limsp : boolean;
                        mkeven : boolean) return signed is
    -- Non-constant
    variable r      : signed(6 downto 0)  := "0000000";
    variable maxadj : signed(6 downto 0)  := "0111111";   -- 63
    variable adjtmp : signed(12 downto 0);
  begin
    if limdp then
      -- Limit to -1023 rather than -1022 here, since we need to be
      -- able to deal with the underflow flag properly when rounding
      -- goes from denormal to normal.
      -- See for example
      -- www.jhauser.us/arithmetic/SoftFloat-3/doc/SoftFloat-FAQ.html
      -- regarding tininess after rounding.
      adjtmp   := op.exp + 1023;
      -- -64 to 63?
      if all_0(adjtmp(12 downto 6)) or all_1(adjtmp(12 downto 6)) then
        maxadj := adjtmp(6 downto 0);
      end if;
    end if;
    if limsp then
      -- Limit to -127 rather than -126 here. See above.
      adjtmp   := op.exp + 127;
      -- -64 to 63?
      if all_0(adjtmp(12 downto 6)) or all_1(adjtmp(12 downto 6)) then
        maxadj := adjtmp(6 downto 0);
      end if;
    end if;

    -- Look for top '1', r will be -1 to 52.
    for x in 2 to 55 loop
      if op.mant(x) = '1' then
        r := to_signed(54 - x, 7);
      end if;
    end loop;

    -- Square root needs even exponent after adjustment.
    if mkeven then
      if (r(0) xor op.exp(0)) = '1' then
        r := r + 1;
      end if;
    elsif r > maxadj then
      r   := maxadj;
    end if;

    return r;
  end;


  -- Convert single/double precision floating point value to internal format.
  function unpack(opu : word64; dp  : boolean) return float is
    variable r : float := float_none;
-- pragma translate_off
    variable f : float := to_float_ext(opu);
-- pragma translate_on
  begin
    r.w            := opu;
    if not dp then
      r.neg        := opu(31) = '1';
      r.exp        := signed(sub(std_logic_vector'("00000" & opu(30 downto 23)), 127));
      r.mant       := "01" & opu(22 downto 0) & zerow64(30 downto 0);
      if all_0(opu(30 downto 23)) then                       -- Denormal?
        r.exp      := to_signed(-126, 13);
        r.mant(54) := '0';
      end if;
      if all_1(opu(30 downto 23)) then                       -- Special?
        r.class(1) := '1';
        r.mant(54) := '0';
        r.snan     := opu(22) = '0';                         -- Assume NaN
      end if;
      if all_0(opu(22 downto 0)) and r.mant(54) = '0' then   -- Inf or zero?
        r.class(0) := '1';
        r.snan     := false;                                 -- Assumption above was wrong
      end if;
      -- Check NaN-boxing (previously swapped to bottom)
      if not all_1(opu(63 downto 32)) then
        r.class    := C_NAN;
        r.snan     := false;
      end if;
    else
      r.neg        := opu(63) = '1';
      r.mant       := "01" & opu(51 downto 0) & "00";
      r.exp        := signed(sub(std_logic_vector'("00" & opu(62 downto 52)), 1023));
      if all_0(opu(62 downto 52)) then                       -- Denormal?
        r.exp      := to_signed(-1022, 13);
        r.mant(54) := '0';
      end if;
      if all_1(opu(62 downto 52)) then                       -- Special?
        r.class(1) := '1';
        r.mant(54) := '0';
        r.snan     := opu(51) = '0';                         -- Assume NaN
      end if;
      if all_0(opu(51 downto 0)) and r.mant(54) = '0' then   -- Inf or zero?
        r.class(0) := '1';
        r.snan     := false;                                 -- Assumption above was wrong
      end if;
    end if;

-- pragma translate_off
    if notx(opu) then
--      assert is_inf(r)    = is_inf(f)    report "Diff Inf"    severity failure;
--      assert is_nan(r)    = is_nan(f)    report "Diff NaN"    severity failure;
--      assert is_signan(r) = is_signan(f) report "Diff sigNaN" severity failure;
--      assert is_zero(r)   = is_zero(f)   report "Diff zero"   severity failure;
--      assert is_normal(r) = is_normal(f) report "Diff normal" severity failure;
--      assert is_neg(r)    = is_neg(f)    report "Diff neg"    severity failure;
    end if;
    r.v := f.v;
-- pragma translate_on

    return r;
  end;

  -- Convert internal format to IEEE754 single/double precision value.
  function pack(op : float; dp : boolean) return std_logic_vector is
    variable r : word64;
  begin
    r                   := (others => '0');
    r(63)               := to_bit(op.neg);
    r(51 downto 0)      := op.mant(53 downto 2);
    if dp then
      assert (op.exp > -1023 and op.exp < 1024) or not is_normal(op);
      r(62 downto 52)   := std_logic_vector(op.exp(10 downto 0) + 1023);
      if op.exp = -1022 then
        r(52)           := op.mant(54);
      end if;
      if is_nan(op) or is_inf(op) then
        r(62 downto 52) := (others => '1');
      elsif is_zero(op) then
        r(62 downto 52) := (others => '0');
      end if;
      if is_zero(op) or is_nan(op) or is_inf(op) then
        r(51 downto 0)  := (others => '0');
      end if;
      if is_nan(op) and not is_signan(op) then
        r(51)           := '1';
      end if;
      if is_nan(op) then
        r(63)           := '0';
      end if;
    else
      assert (op.exp > -127 and op.exp < 128) or not is_normal(op);
      r(62 downto 55)   := std_logic_vector(op.exp(7 downto 0) + 127);
      if op.exp = -126 then
        r(55)           := op.mant(54);
      end if;
      if is_nan(op) or is_inf(op) then
        r(62 downto 55) := (others => '1');
      elsif is_zero(op) then
        r(62 downto 55) := (others => '0');
      end if;
      r(54 downto 32)   := op.mant(53 downto 31);
      if is_zero(op) or is_nan(op) or is_inf(op) then
        r(54 downto 32) := (others => '0');
      end if;
      if is_nan(op) and not is_signan(op) then
        r(54)           := '1';
      end if;
      if is_nan(op) then
        r(63)           := '0';
      end if;
      r(31 downto 0)    := r(63 downto 32);
      r(63 downto 32)   := (others => '1');   -- NaN-boxing
    end if;

    return r;
  end;


  -- Shift mantissa
  procedure adjust_new(mant_in    : std_logic_vector(55 downto 0);
                       vadj       : signed(6 downto 0);
                       manthi_out : out std_logic_vector(65 downto 56);
                       mant_out   : out std_logic_vector(55 downto 0);
                       mant0b_out : out std_logic_vector(0 to 1)) is
    variable mant0 : std_logic_vector(55 downto 0) := (others => '0');
    variable xhi   : std_logic_vector( 9 downto 0) := (others => '0');
    variable xant  : std_logic_vector(55 downto 0) := mant_in;
    variable xadj  : signed(6 downto 0)            := vadj;
    variable neg   : boolean                       := get_hi(vadj) = '1';
    variable low1  : boolean                       := false;
  begin
    if get_hi(vadj) = '0' then
      mant0b_out := "00";
      if all_0(vadj) then
        mant0b_out := xant(0) & '0';
      end if;
      xant       := mant_in;
      if vadj(5) = '1' then
        xant := xant(xant'high - 32 downto 0) & mant0(31 downto 0);
      end if;
      if vadj(4) = '1' then
        xant := xant(xant'high - 16 downto 0) & mant0(15 downto 0);
      end if;
      if vadj(3) = '1' then
        xhi  := xhi(xhi'high - 8 downto 0) & xant(xant'high downto xant'high - 7);
        xant := xant(xant'high - 8 downto 0) & mant0(7 downto 0);
      end if;
      if vadj(2) = '1' then
        xhi  := xhi(xhi'high - 4 downto 0) & xant(xant'high downto xant'high - 3);
        xant := xant(xant'high - 4 downto 0) & mant0(3 downto 0);
      end if;
      if vadj(1) = '1' then
        xhi  := xhi(xhi'high - 2 downto 0) & xant(xant'high downto xant'high - 1);
        xant := xant(xant'high - 2 downto 0) & mant0(1 downto 0);
      end if;
      if vadj(0) = '1' then
        xhi  := xhi(xhi'high - 1 downto 0) & xant(xant'high);
        xant := xant(xant'high - 1 downto 0) & mant0(0);
      end if;
    else
      xant      := (others => '0');
      mant0b_out := "00";
      if vadj < -55 then
        -- Too large down shift results in 0 (except for bottom rounding bit).
        if not all_0(mant_in) then
          mant0b_out := "01";
          xant(0)    := '1';
        end if;
      else
        xant := mant_in;
        xadj := -vadj;
        if xadj(5) = '1' then
          low1 := low1 or not all_0(xant(31 downto 0));
          xant := x"00000000" & xant(xant'high downto 32);
        end if;
        if xadj(4) = '1' then
          low1 := low1 or not all_0(xant(15 downto 0));
          xant := x"0000" & xant(xant'high downto 16);
        end if;
        if xadj(3) = '1' then
          low1 := low1 or not all_0(xant(7 downto 0));
          xant := x"00" & xant(xant'high downto 8);
        end if;
        if xadj(2) = '1' then
          low1 := low1 or not all_0(xant(3 downto 0));
          xant := x"0" & xant(xant'high downto 4);
        end if;
        if xadj(1) = '1' then
          low1 := low1 or not all_0(xant(1 downto 0));
          xant := "00" & xant(xant'high downto 2);
        end if;
        if xadj(0) = '1' then
          low1 := low1 or not all_0(xant(0 downto 0));
          xant := "0" & xant(xant'high downto 1);
        end if;
        mant0b_out := xant(0) & to_bit(low1);
        -- Note any out-shifted bits at the low end.
        if low1 then
          xant(0) := '1';
        end if;
      end if;
    end if;

    mant_out   := xant;
    manthi_out := xhi;
  end;

  procedure adjust_new(mant_in    : std_logic_vector(55 downto 0);
                       vadj       : signed(6 downto 0);
                       mant_out   : out std_logic_vector(55 downto 0);
                       mant0b_out : out std_logic_vector(0 to 1)) is
    -- Non-constant
    variable dummy : std_logic_vector(9 downto 0);
  begin
    adjust_new(mant_in, vadj, dummy, mant_out, mant0b_out);
  end;


  procedure roundup(op2 : float; dp : boolean; rm : rm_t;
                    rndup_out : out boolean; rndbits_out : out std_logic_vector(2 downto 0)) is
    variable rndbits : std_logic_vector(2 downto 0) := op2.mant(2 downto 0);
    variable rndup   : boolean                      := false;
  begin
    if not dp then
      rndbits      := op2.mant(31 downto 29);
      for x in 28 downto 0 loop
        rndbits(0) := rndbits(0) or op2.mant(x);
      end loop;
    end if;

    case rm is
      when R_NEAREST =>
        rndup := (rndbits(1) and (rndbits(0) or rndbits(2))) = '1';
      when R_ZERO =>
      when R_PLUS_INF =>
        rndup   := not op2.neg and (rndbits(1) or rndbits(0)) = '1';
      when R_MINUS_INF =>
        rndup   := op2.neg and (rndbits(1) or rndbits(0)) = '1';
      when others =>  -- R_RMM - to nearest, ties away from zero
        rndup   := rndbits(1) = '1';
    end case;

    rndup_out   := rndup;
    rndbits_out := rndbits;
  end;

end;
