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
use grlib.riscv.all;
use grlib.stdlib.tost;
use grlib.stdlib.notx;
library gaisler;
use gaisler.noelvtypes.all;
use gaisler.utilnv.u2vec;
use gaisler.utilnv.s2vec;
use gaisler.utilnv.u2i;
use gaisler.utilnv.s2i;
use gaisler.utilnv.usub;
use gaisler.utilnv.uext;
use gaisler.utilnv.tost;
use gaisler.utilnv.all_0;
use gaisler.utilnv.all_1;
use gaisler.utilnv.get_zeros;
use gaisler.utilnv.get_ones;
use gaisler.utilnv.get;
use gaisler.utilnv.get_hi;
use gaisler.utilnv.get_lo;
use gaisler.utilnv.set_hi;
use gaisler.utilnv.set_lo;
use gaisler.utilnv.to_bit;
use gaisler.nvsupport.is_enabled;


package fputilnv is

  constant fpulen : integer := 64;

  -- IEEE single precision:  8, 23
  -- IEEE double precision: 11, 52
  -- IEEE half precision:    5, 10
  -- BFLOAT16:               8,  7

  type     reg_arr is array (integer range <>) of reg_t;

  subtype  rm_t       is word3;
  constant R_NEAREST   : rm_t := "000";  -- RNE Nearest, ties to even
  constant R_ZERO      : rm_t := "001";  -- RTZ Towards zero
  constant R_MINUS_INF : rm_t := "010";  -- RDN Down, towards negative infinity
  constant R_PLUS_INF  : rm_t := "011";  -- RUP Up, towards positive infinity
  constant R_RMM       : rm_t := "100";  -- Nearest, ties to max magnitude
  -- The rest are illegal, except that in an instruction "111" (DYN)
  -- means that rounding mode should be fetched from CSR register.

  -- Floating point flags
  constant EXC_NX : integer := 0;  -- Inexact
  constant EXC_UF : integer := 1;  -- Underflow
  constant EXC_OF : integer := 2;  -- Overflow
  constant EXC_DZ : integer := 3;  -- Divide by zero
  constant EXC_NV : integer := 4;  -- Invalid

  constant C_NORMAL : word2 := "00";
  constant C_ZERO   : word2 := "01";
  constant C_NAN    : word2 := "10";
  constant C_INF    : word2 := "11";

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
    class    : word2;    -- See C_ above.
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

  type fpunv_op is record
    valid : std_ulogic;
    op    : fpuop_t;                   -- FPU operation
    opx   : word3;                     --   extension
    rm    : rm_t;                      -- Rounding mode
    fmt   : word2;                     -- Precision: 00 - single, 01 - double, 10 - half
    rd    : reg_t;
    rs    : reg_arr(1 to 3);
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
    FPEVT_EVENTS          -- Only for fpevt_t type!
  );

  function fpu_illegal(active  : extension_type;
                       inst_in : word;
                       frm     : word3) return boolean;

  subtype fpevt_t is std_logic_vector(0 to fpuevent_t'pos(FPEVT_EVENTS)-1);
  function fpu_event(evt : fpuevent_t) return integer;
  procedure fpu_event(events : inout fpevt_t; evt : fpuevent_t);


  function is_signan(op : float) return boolean;
  function is_inf(op : float) return boolean;
  function is_nan(op : float) return boolean;
  function is_zero(op : float) return boolean;
  function is_one(op : float) return boolean;
  function is_normal(op : float) return boolean;
  function is_neg(op : float) return boolean;

  function inf_mul(a : float; b : float) return float;
  function inf_neg(a : float) return float;
  function mul_illegal(a : float; b : float) return boolean;
  function add_illegal(a : float; b : float) return boolean;

  function NaNbox(v : std_logic_vector) return word64;
  function NaN(fmt : word2; signaling : boolean := false) return word64;
  function NaN(dp : boolean; signaling : boolean := false) return word64;
  function Inf(fmt : word2; negative : boolean := false) return word64;
  function Inf(dp : boolean; negative : boolean := false) return word64;
  function Zero(fmt : word2; negative : boolean := false) return word64;
  function Zero(dp : boolean; negative : boolean := false) return word64;
  function MaxNormal(fmt : word2; negative : boolean := false) return word64;
  function MinDenormal(fmt : word2; negative : boolean := false) return word64;

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

  function find_normadj(op     : float;
                        limdp  : boolean; limsp : boolean;
                        mkeven : boolean) return signed;
  function unpack(opu : std_logic_vector; fmt : word2) return float;
  function unpack(opu : std_logic_vector; dp : boolean) return float;
  function pack(op : float; fmt : word2) return word64;
  function pack(op : float; dp : boolean) return word64;
  procedure adjust_new(mant_in    : std_logic_vector(55 downto 0);
                       vadj       : signed(6 downto 0);
                       manthi_out : out std_logic_vector(65 downto 56);
                       mant_out   : out std_logic_vector(55 downto 0);
                       mant0b_out : out std_logic_vector(0 to 1));
  procedure adjust_new(mant_in    : std_logic_vector(55 downto 0);
                       vadj       : signed(6 downto 0);
                       mant_out   : out std_logic_vector(55 downto 0);
                       mant0b_out : out std_logic_vector(0 to 1));
  function roundup(rm : rm_t; neg : boolean; rndbits : word3) return boolean;
  procedure roundup(op2 : float; ebits : integer; mbits : integer; rm : rm_t;
                    rndup_out : out boolean; rndbits_out : out word3);
  procedure roundup(op2 : float; fmt : word2; rm : rm_t;
                    rndup_out : out boolean; rndbits_out : out word3);
  procedure roundup(op2 : float; dp : boolean; rm : rm_t;
                    rndup_out : out boolean; rndbits_out : out word3);

  function imm_create(active : extension_type;
                      v : word5; fmt : word2) return std_logic_vector;

  function to_float_ext(data : std_logic_vector) return float;
  function to_float(data : std_logic_vector; fmt : word2) return float;
-- pragma translate_off
  function fpreg2st(reg : reg_t) return string;
  function tost_float(v : std_logic_vector) return string;
  procedure show_float(text : string; reg : reg_t; v : std_logic_vector);
-- pragma translate_on
end;

package body fputilnv is

  function fpu_illegal(active  : extension_type;
                       inst_in : word;
                       frm     : word3) return boolean is
    variable is_rv64     : boolean      := is_enabled(active, x_rv64);
    variable is_rv32     : boolean      := not is_rv64;
    variable ext_f       : boolean      := is_enabled(active, x_f);
    variable ext_d       : boolean      := is_enabled(active, x_d);
    variable ext_zfa     : boolean      := is_enabled(active, x_zfa);
    variable ext_zfh     : boolean      := is_enabled(active, x_zfh);
    variable ext_zfhmin  : boolean      := is_enabled(active, x_zfhmin);
    variable ext_zfbfmin : boolean      := is_enabled(active, x_zfbfmin);
    variable no_muladd   : boolean      := not is_enabled(active, x_muladd);
    variable opcode      : opcode_type  := opcode(inst_in);
    variable rfa2        : reg_t        := rs2(inst_in);
    variable funct3      : funct3_type  := funct3(inst_in);
    variable funct7      : funct7_type  := funct7(inst_in);
    variable funct5      : funct5_type  := funct5(inst_in);
    variable fmt         : word2        := inst_in(26 downto 25);
    variable conversion  : word4        := fmt & rfa2(1 downto 0);
    -- Non-constant
    variable illegal     : boolean      := false;
    variable illegal_rm  : boolean      := false;
    variable illegal_fmt : boolean      := false;
  begin
    -- Illegal rounding mode?
    if funct3 = "101" or funct3 = "110" then
      illegal_rm := true;
    end if;
    if funct3 = "111" and
       (frm = "101" or frm = "110" or frm = "111") then
      illegal_rm := true;
    end if;

    case opcode is
      when OP_LOAD_FP | OP_STORE_FP =>
        case funct3 is
          when R_WORD   => illegal := not ext_f;
          when R_DOUBLE => illegal := not ext_d;
          when R_HALF   => illegal := not (ext_f and ext_zfhmin);
          when others   => illegal := true;
        end case;
      when OP_FMADD | OP_FMSUB | OP_FNMSUB | OP_FNMADD =>
        case fmt is
          when "00"   => illegal := not ext_f;
          when "01"   => illegal := not ext_d;
          when "10"   => illegal := not (ext_f and ext_zfh);
          when others => illegal := true;
        end case;
        if no_muladd then
          illegal   := true;
        end if;
        illegal := illegal or illegal_rm;
      when OP_FP =>
        case fmt is
          when "00"   => illegal := not ext_f;
          when "01"   => illegal := not ext_d;
          when "10"   =>  -- Half precision float
            case funct5 is
              when R_FADD     | R_FSUB | R_FMUL | R_FDIV  |
                   R_FMINMAX  | R_FCMP | R_FSGN | R_FSQRT |
                   R_FCVT_W_S | R_FCVT_S_W =>
                illegal := not (ext_f and ext_zfh);
              when R_FMV_X_W  | R_FMV_W_X  |
                   R_FCVT_S_D =>
                illegal := not (ext_f and ext_zfhmin);
              when others =>
                illegal := true;
            end case;
          when others => illegal := true;
        end case;
        case funct5 is
          when R_FADD | R_FSUB | R_FMUL | R_FDIV =>
            illegal := illegal or illegal_rm;
          when R_FSQRT =>
            if rfa2 /= "00000" then
              illegal := true;
            end if;
            illegal := illegal or illegal_rm;
          when R_FSGN =>
            case funct3 is
              when R_FSGNJ | R_FSGNJN | R_FSGNJX => null;
              when others                        => illegal := true;
            end case;
          when R_FMINMAX =>
            case funct3 is
              when R_FMAX  | R_FMIN  => null;
              when R_FMAXM | R_FMINM => illegal := illegal or not ext_zfa;
              when others            => illegal := true;
            end case;
          when R_FCMP =>
            case funct3 is
              when R_FEQ  | R_FLT | R_FLE => null;
              when R_FLTQ | R_FLEQ        => illegal := illegal or not ext_zfa;
              when others                 => illegal := true;
            end case;
          -- Convert to/from integer
          when R_FCVT_W_S | R_FCVT_S_W => -- R_FCVT_L_S, R_FCVT_S_L (and _D_ variants)
            -- FCVTMOD.W.D
            if ext_d and ext_zfa and rfa2 = "01000" and
               funct3 = R_ZERO and fmt = "01" then
              null;
            -- Only four modes available
            elsif rfa2(4 downto 2) /= "000" then
              illegal := true;
            -- No L[U] for RV32.
            elsif is_rv32 and rfa2(1) = '1' then
              illegal := true;
            end if;
            illegal := illegal or illegal_rm;
          -- Mainly moves to/from integer
          when R_FMV_X_W | R_FMV_W_X => -- R_FCLASS (and _D_ variants)
            case funct3 is
              when "000" =>
                -- The move instructions only work for 16/32 bit float on RV32.
                if fmt = "10" then
                  illegal_fmt := not ext_zfhmin;
                end if;
                -- FLI.S/D/H
                if ext_zfa and rfa2 = "00001" and funct5 = R_FMV_W_X then
                  illegal := illegal or illegal_fmt;
                -- FMVH.X.D
                elsif is_rv32 and ext_zfa and rfa2 = "00001" and funct7 = R_FMVH_X_D then
                  null;
                elsif rfa2 /= "00000" then
                  illegal := true;
                else
                  illegal := illegal or illegal_fmt;
                end if;
              -- FCLASS
              when "001" =>
                if rfa2 /= "00000" or (not ext_zfh and fmt = "10") then
                  illegal := true;
                end if;
              when others =>
                illegal := true;
            end case;
          -- Convert between floating point types
          when R_FCVT_S_D =>  -- R_FCVT_D_S
            if ext_zfa and rfa2(4 downto 2) = "001" then
              if rfa2(1) = '1' then
                if ext_zfbfmin then
                  if rfa2(0) = '1' or (fmt /= "00" and fmt /= "10") then
                    illegal := true;
                  end if;
                else
                  illegal := true;
                end if;
              else
                -- FROUND[NX].S/D/H
                -- Encoded as 4/5
                case fmt is
                  when "00"   => null;
                  when "01"   => null;
                  when "10"   => illegal := illegal or not ext_zfhmin;
                  when others => illegal := true;
                end case;
              end if;
            elsif rfa2(4 downto 2) = "000" then
              case conversion is
                when "0001" => null;
                when "0100" => null;
                when "0010" => illegal := illegal or not ext_zfhmin;
                when "1000" => illegal := illegal or not ext_zfhmin;
                when "0110" => illegal := illegal or not (ext_d and ext_zfhmin);
                when "1001" => illegal := illegal or not (ext_d and ext_zfhmin);
                when others => illegal := true;
              end case;
            else
              illegal := true;
            end if;
            illegal := illegal or illegal_rm;
          when others =>
            -- FMVP.D.X
            if ext_zfa and funct7 = R_FMVP_D_X and funct3 = "000" then
              null;
            else
              illegal := true;
            end if;
        end case;
      when others =>
        illegal := true;
    end case;

    return illegal;
  end;

  function fpu_event(evt : fpuevent_t) return integer is
  begin
    return fpuevent_t'pos(evt);
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
           all_0(op.mant(op.mant'high - 1 downto 0));
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

  function NaNbox(v : std_logic_vector) return word64 is
    -- Non-constant
    variable r : word64 := (others => '1');
  begin
    set_lo(r, v);

    return r;
  end;

  function Zero(ebits : integer; mbits : integer;
               negative : boolean := false) return std_logic_vector is
  begin
    return to_bit(negative) & get_zeros(ebits + mbits);
  end;

  function Zero(fmt : word2; negative : boolean := false) return word64 is
  begin
    case fmt is
      when "00"   => return NaNbox(Zero( 8, 23, negative));
      when "01"   => return NaNbox(Zero(11, 52, negative));
      when "10"   => return NaNbox(Zero( 5, 10, negative));
      when others => return NaNbox(Zero( 8,  7, negative));  -- BFLOAT16
    end case;
  end;

  function Zero(dp : boolean; negative : boolean := false) return word64 is
  begin
    return Zero("0" & to_bit(dp), negative);
  end;

  -- Infinity
  function Inf(ebits : integer; mbits : integer;
               negative : boolean := false) return std_logic_vector is
  begin
    return to_bit(negative) & get_ones(ebits) & get_zeros(mbits);
  end;

  function Inf(fmt : word2; negative : boolean := false) return word64 is
  begin
    case fmt is  -- BFLOAT16
      when "00"   => return NaNbox(Inf( 8, 23, negative));
      when "01"   => return NaNbox(Inf(11, 52, negative));
      when "10"   => return NaNbox(Inf( 5, 10, negative));
      when others => return NaNbox(Inf( 8,  7, negative));  -- BFLOAT16
    end case;
  end;

  function Inf(dp : boolean; negative : boolean := false) return word64 is
  begin
    return Inf("0" & to_bit(dp), negative);
  end;

  -- Maximum normal
  function MaxNormal(ebits : integer; mbits : integer;
                     negative : boolean := false) return std_logic_vector is
  begin
    return to_bit(negative) & get_ones(ebits - 1) & '0' & get_ones(mbits);
  end;

  function MaxNormal(fmt : word2; negative : boolean := false) return word64 is
  begin
    case fmt is
      when "00"   => return NaNbox(MaxNormal( 8, 23, negative));
      when "01"   => return NaNbox(MaxNormal(11, 52, negative));
      when "10"   => return NaNbox(MaxNormal( 5, 10, negative));
      when others => return NaNbox(MaxNormal( 8,  7, negative));  -- BFLOAT16
    end case;
  end;

  function MaxNormal(dp : boolean; negative : boolean := false) return word64 is
  begin
    return MaxNormal("0" & to_bit(dp), negative);
  end;

  -- Minimum denormal
  function MinDenormal(ebits : integer; mbits : integer;
               negative : boolean := false) return std_logic_vector is
  begin
    return to_bit(negative) & get_zeros(ebits) & get_zeros(mbits - 1) & '1';
  end;

  function MinDenormal(fmt : word2; negative : boolean := false) return word64 is
  begin
    case fmt is
      when "00"   => return NaNbox(MinDenormal( 8, 23, negative));
      when "01"   => return NaNbox(MinDenormal(11, 52, negative));
      when "10"   => return NaNbox(MinDenormal( 5, 10, negative));
      when others => return NaNbox(MinDenormal( 8,  7, negative));  -- BFLOAT16
    end case;
  end;

  function MinDenormal(dp : boolean; negative : boolean := false) return word64 is
  begin
    return MinDenormal("0" & to_bit(dp), negative);
  end;

  -- This is the canonical NaN.
  function NaN(ebits : integer; mbits : integer;
               signaling : boolean := false) return std_logic_vector is
    -- Non-constant
    variable v : std_logic_vector(1 + ebits + mbits - 1 downto 0) := Inf(ebits, mbits);
  begin
    if signaling then
      -- Signaling, so set LSB of mantissa
      v(0)         := '1';
    else
      -- Quiet, so set MSB of mantissa
      v(mbits - 1) := '1';
    end if;

    return v;
  end;

  function NaN(fmt : word2; signaling : boolean := false) return word64 is
  begin
    case fmt is
      when "00"   => return NaNbox(NaN( 8, 23, signaling));
      when "01"   => return NaNbox(NaN(11, 52, signaling));
      when "10"   => return NaNbox(NaN( 5, 10, signaling));
      when others => return NaNbox(NaN( 8,  7, signaling));  -- BFLOAT16
    end case;
  end;

  function NaN(dp : boolean; signaling : boolean := false) return word64 is
  begin
    return NaN("0" & to_bit(dp), signaling);
  end;

  -- FPU Signals Generation

  -- Partial decode of FPU operation
  function fpuop(inst : word) return fpuop_t is
    variable opcode : opcode_type := opcode(inst);
    variable funct5 : funct5_type := funct5(inst);
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
    variable funct3   : funct3_type := inst(14 downto 12);
    variable fmt      : word2       := inst(26 downto 25);
    variable rs1      : reg_t       := rs1(inst);
    variable rs2      : reg_t       := rs2(inst);
    variable rs3      : reg_t       := rs3(inst);
    variable rd       : reg_t       := rd(inst);
    -- Non-constant
    variable op       : fpuop_t     := fpuop(inst);
    variable valid    : std_ulogic  := valid_in and to_bit(op /= FPU_UNKNOWN);
    variable rm       : rm_t        := funct3;
    variable ren      : std_logic_vector(1 to 3);
  begin
    if op = FPU_STORE or op = FPU_LOAD then
      case funct3 is
        when "010"  => fmt := "00";  -- 32 bit memory access?
        when "011"  => fmt := "01";  -- 64
        when others => fmt := "10";  -- 16
      end case;
    end if;

    -- CSR controlled rounding?
    if funct3 = "111" then
      rm := csr_frm;
    end if;

    ren(1) := fs1_gen(inst);
    ren(2) := fs2_gen(inst);
    ren(3) := fs3_gen(inst);

    op_out := (valid, op, funct3, rm, fmt, rd, (rs1, rs2, rs3), ren);
  end;

  -- Fs1 register validity check
  -- Returns '1' if the instruction has a valid FPU fs1 field.
  function fs1_gen(inst : word) return std_ulogic is
    variable op     : opcode_type := opcode(inst);
    variable funct5 : funct5_type := funct5(inst);
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
    variable op     : opcode_type := opcode(inst);
    variable funct5 : funct5_type := funct5(inst);
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
    variable op   : opcode_type := opcode(inst);
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


  -- Convert NaN-boxed generic floating point value to internal format.
  function unpack(opu_in : std_logic_vector; ebits : integer; mbits : integer) return float is
    variable opu  : std_logic_vector(opu_in'length - 1 downto 0) := opu_in;
    variable bias : integer                              := 2 ** (ebits - 1) - 1;
    variable bits : integer                              := 1 + ebits + mbits;
    -- Non-constant
    variable r    : float;  -- GHDL synth does not like assigment here!
-- pragma translate_off
    variable f    : float                                := to_float_ext(opu);
-- pragma translate_on
    variable exp  : std_logic_vector(ebits - 1 downto 0) := get(opu, mbits, ebits);
    variable mant : std_logic_vector(mbits - 1 downto 0) := get_lo(opu, mbits);
  begin
    r            := float_none;  -- GHDL synth does not like assignment above for this!
    r.w          := opu;
    r.neg        := opu(ebits + mbits) = '1';
    r.exp        := signed(usub(uext(exp, r.exp'length), bias));
    set_hi(r.mant, "01" & mant);
    if all_0(exp) then                          -- Denormal?
      r.exp      := s2vec(-(bias - 1), r.exp);
      r.mant(54) := '0';
    end if;
    if all_1(exp) then                          -- Special?
      r.class(1) := '1';
      r.mant(54) := '0';
      r.snan     := opu(mbits - 1) = '0';       -- Assume signaling NaN
    end if;
    if all_0(mant) and r.mant(54) = '0' then    -- Inf or zero?
      r.class(0) := '1';
      r.snan     := false;                      -- Assumption above was wrong
    end if;
    -- Check NaN-boxing (previously swapped to bottom)
    if bits < opu'length and not all_1(opu(opu'high downto bits)) then
      r.class    := C_NAN;
      r.snan     := false;
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

  -- Convert single/double precision floating point value to internal format.
  function unpack(opu : std_logic_vector; fmt : word2) return float is
  begin
    case fmt is
    when "00"   => return unpack(opu,  8, 23);
    when "01"   => return unpack(opu, 11, 52);
    when "10"   => return unpack(opu,  5, 10);
    when others => return unpack(opu,  8,  7);  -- BFLOAT16
    end case;
  end;

  function unpack(opu : std_logic_vector; dp : boolean) return float is
  begin
    return unpack(opu, "0" & to_bit(dp));
  end;

  -- Convert internal format to NaN-boxed generic floating point value.
  function pack(op : float; ebits : integer; mbits : integer) return std_logic_vector is
    variable bias : integer                              := 2 ** (ebits - 1) - 1;
    variable bits : integer                              := 1 + ebits + mbits;
    variable mant : std_logic_vector(mbits - 1 downto 0) := get(op.mant, 53 - mbits + 1, mbits);
    -- Non-constant
    variable exp  : signed(op.exp'range)                 := op.exp;
    variable r    : std_logic_vector(bits - 1 downto 0);
  begin
-- pragma translate_off
    if is_normal(op) and is_x(std_logic_vector(exp)) then
      exp := (others => '0');
    end if;
    assert not is_normal(op) or (exp > -bias and exp <= bias)
      report "Bad pack op " & tost(exp) & " " & tost(is_normal(op))
      severity failure;
-- pragma translate_on
    if is_nan(op) then
      r := NaN(ebits, mbits, is_signan(op));
    elsif is_inf(op) then
      r := Inf(ebits, mbits, op.neg);
    elsif is_zero(op) then
      r := Zero(ebits, mbits, op.neg);
    else
      r := to_bit(op.neg) & std_logic_vector(get_lo(exp, ebits) + bias) & mant;
      -- When exponent is lowest possible for a normal,
      -- the number might actually be denormal.
      -- If it is, the "integer bit" is '0', so copy that to
      -- the LSB of the exponent to make a denormal.
      if exp = -(bias - 1) then
        r(mbits) := op.mant(54);
      end if;
    end if;

    return r;
  end;

  -- Convert internal format to IEEE754 single/double precision value.
  function pack(op : float; fmt : word2) return word64 is
  begin
    case fmt is
    when "00"   => return NaNbox(pack(op,  8, 23));
    when "01"   => return NaNbox(pack(op, 11, 52));
    when "10"   => return NaNbox(pack(op,  5, 10));
    when others => return NaNbox(pack(op,  8,  7));  -- BFLOAT16
    end case;
  end;

  function pack(op : float; dp : boolean) return word64 is
  begin
    return pack(op, "0" & to_bit(dp));
  end;


  -- Shift mantissa
  procedure adjust_new(mant_in    : std_logic_vector(55 downto 0);
                       vadj       : signed(6 downto 0);
                       manthi_out : out std_logic_vector(65 downto 56);
                       mant_out   : out std_logic_vector(55 downto 0);
                       mant0b_out : out std_logic_vector(0 to 1)) is
    variable neg   : boolean                       := get_hi(vadj) = '1';
    -- Non-constant
    variable mant0 : std_logic_vector(55 downto 0) := (others => '0');
    variable xhi   : std_logic_vector( 9 downto 0) := (others => '0');
    variable xant  : std_logic_vector(55 downto 0) := mant_in;
    variable xadj  : signed(6 downto 0)            := vadj;
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


  -- f.mant is in 2.52.2 format (bottom two is guard).
  function rbits(f : float; ebits : integer; mbits : integer) return word3 is
    variable lsb : integer := 52 + 2 - mbits;
    -- Non-constant
    variable rnd : word3 := f.mant(lsb downto lsb - 2);
  begin
    for i in lsb - 3 downto 0 loop
      rnd(0) := rnd(0) or f.mant(i);
    end loop;

    return rnd;
  end;

  function roundup(rm : rm_t; neg : boolean; rndbits : word3) return boolean is
  begin
    case rm is
      when R_NEAREST   => return (rndbits(1) and (rndbits(0) or rndbits(2))) = '1';
      when R_ZERO      => return false;
      when R_PLUS_INF  => return not neg and (rndbits(1) or rndbits(0)) = '1';
      when R_MINUS_INF => return neg and (rndbits(1) or rndbits(0)) = '1';
      -- R_RMM - to nearest, ties away from zero
      when others      => return rndbits(1) = '1';
    end case;
  end;

  procedure roundup(op2 : float; ebits : integer; mbits : integer; rm : rm_t;
                    rndup_out : out boolean; rndbits_out : out word3) is
    -- Non-constant
    variable rndbits : word3 := rbits(op2, ebits, mbits);
  begin
    rndup_out   := roundup(rm, op2.neg, rndbits);
    rndbits_out := rndbits;
  end;

  procedure roundup(op2 : float; fmt : word2; rm : rm_t;
                    rndup_out : out boolean; rndbits_out : out word3) is
  begin
    case fmt is
    when "00"   => roundup(op2,  8, 23, rm, rndup_out, rndbits_out);
    when "01"   => roundup(op2, 11, 52, rm, rndup_out, rndbits_out);
    when "10"   => roundup(op2,  5, 10, rm, rndup_out, rndbits_out);
    when others => roundup(op2,  8,  7, rm, rndup_out, rndbits_out);  -- BFLOAT16
    end case;
  end;

  procedure roundup(op2 : float; dp : boolean; rm : rm_t;
                    rndup_out : out boolean; rndbits_out : out word3) is
  begin
    roundup(op2, "0" & to_bit(dp), rm, rndup_out, rndbits_out);
  end;

  -- Binary (IEEE754) to float conversion
  -- Does not provide infinity, NaN and such in real component.
  function to_float(data : std_logic_vector; ebits : integer; mbits : integer) return float is
    variable bias    : integer := 2 ** (ebits - 1) - 1;
    variable exp_max : integer := 2 ** ebits - 1;
    variable bits    : integer := 1 + ebits + mbits;
    -- Non-constant
    variable exp     : integer;
    variable r       : float   := float_none;
-- pragma translate_off
    variable debug   : boolean := true;
    variable frac    : integer;
    variable f       : real;
-- pragma translate_on
  begin
    assert data'length >= bits report "Data too small" severity failure;
    r.w(data'range) := data;
    -- Improper NaN boxing?
    if data'length > bits and not all_1(data(data'high downto bits)) then
      r.class    := C_NAN;
      r.w        := NaNbox(NaN(ebits, mbits));
      return r;
    end if;

    if data(mbits + ebits) = '1' then
      r.neg := true;
    end if;

    exp     := u2i(get(data, mbits, ebits));

    if all_0(get_lo(data, mbits)) then
      r.class := C_ZERO;
    end if;

    --  Exponent all 1 - infinity (mantissa 0) or NaN
    if exp = exp_max then
-- pragma translate_off
      if debug then
        r.v      := 12345.6789;  -- Dummy
      end if;
-- pragma translate_on
      if r.class = C_ZERO then
        r.class  := C_INF;
        return r;
      else
        r.class  := C_NAN;
        if data(mbits - 1) = '0' then   -- Signaling NaN?
          r.snan := true;
        end if;
        return r;
      end if;
    end if;

    -- Exponent all 0 - subnormal
    if exp = 0 then
      r.exp      := to_signed(-bias, r.exp'length);
      r.mant     := (others => '0');
      set_hi(r.mant, "00" & get_lo(data, mbits));
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
      r.class    := C_NORMAL;
      r.exp      := s2vec(u2i(get(data, mbits, ebits)) - bias, r.exp);
      r.mant     := (others => '0');
      set_hi(r.mant, "01" & get_lo(data, mbits));
    end if;

-- pragma translate_off
    if debug then
      -- Split mantissa into two parts, since an integer
      -- is not large enough for the double precision case.
      if mbits >= 23 then
        frac        := u2i(data(mbits - 1 downto mbits - 23));
        f           := real(frac) / 2.0 ** 23;
      else
        frac        := u2i(data(mbits - 1 downto 0));
        f           := real(frac) / 2.0 ** mbits;
      end if;
      if mbits > 23 then
        frac      := u2i(data(mbits - 23 - 1 downto 0));
        f         := f + real(frac) / 2.0 ** mbits;
      end if;

      if exp = 0 then
        f   := f * 2.0 ** (1 - bias);
      else
        -- ModelSim does not like assigmnents outside -1e308 and 1e308,
        -- but a real can actually be there...
        if (1.0 + f) * 2.0 ** (exp - bias) > 1.0e308 then
          f := 1.0e308;
        elsif (1.0 + f) * 2.0 ** (exp - bias) < -1.0e308 then
          f := -1.0e308;
        else
          f := (1.0 + f) * 2.0 ** (exp - bias);
        end if;
      end if;
      if r.neg then
        f   := -1.0 * f;
      end if;

      r.v   := f;
    end if;
-- pragma translate_on

    return r;
  end;

  function to_float(data : std_logic_vector; fmt : word2) return float is
  begin
    case fmt is
      when "00"   => return to_float(data,  8, 23);
      when "01"   => return to_float(data, 11, 52);
      when "10"   => return to_float(data,  5, 10);
      when others => return to_float(data,  8,  7);  -- BFLOAT16
    end case;
  end;

  -- Remove NaN boxing and create float from binary (IEEE754)
  function to_float_ext(data : std_logic_vector) return float is
  begin
    if data'length = 16 or all_1(data(63 downto 16)) then
      return to_float(data, "10");
    elsif data'length = 32 or (data'length = 64 and all_1(data(63 downto 32))) then
      return to_float(data, "00");
    else
      return to_float(data, "01");
    end if;
  end;

  function imm_mant(v : word5) return std_logic_vector is
    variable n : integer := u2i(v);
  begin
    if n = 31 then
      return "10";
    elsif n < 8 or n > 22 then
      return "00";
    else
      return v(1 downto 0);
    end if;
  end;

  function imm_exp_simple(v : word5) return integer is
    variable n : integer range 0 to 31 := u2i(v);
  begin
    case n is
      when  0 => return 0;
      when  2 => return -16;
      when  3 => return -15;
      when  4 => return -8;
      when  5 => return -7;
      when  6 => return -4;
      when  7 => return -3;
      when  8 |  9 | 10 | 11 => return -2;
      when 12 | 13 | 14 | 15 => return -1;
      when 16 | 17 | 18 | 19 => return 0;
      when 20 | 21 | 22      => return 1;
      when 23 => return 2;
      when 24 => return 3;
      when 25 => return 4;
      when 26 => return 7;
      when 27 => return 8;
      when 28 => return 15;
      when 29 => return 16;
      when others => return 0;
    end case;
  end;

  function imm_create(v : word5;
                      ebits : integer; mbits : integer) return std_logic_vector is
    variable n    : integer    := u2i(v);
    variable e    : integer    := imm_exp_simple(v);
    variable bias : integer    := 2 ** (ebits - 1) - 1;
    -- Non-constant
    variable sign : std_ulogic                           := '0';
    variable exp  : std_logic_vector(ebits - 1 downto 0) := (others => '1');
    variable mant : std_logic_vector(mbits - 1 downto 0) := (others => '0');
  begin
    mant(mant'high downto mant'high - 1) := imm_mant(v);
    case n is
      when 0       => exp    := u2vec(bias, exp); sign := '1';  -- -1
      when 1       => exp    := u2vec(1, exp);                  -- Min normal
      when 30 | 31 =>                                           -- Inf, NaN
      when others  =>
        -- Since formality seems to be a bit confused here,
        -- avoid complications, for now.
        -- Remove the first three parts for formality, but
		-- WARNING that it then is only correct for F/D!
        if e + bias < -mbits then
          exp := (others => '0');
        elsif e + bias < 1 then
          exp := (others => '0');
          mant(mant'high + (e + bias)) := '1';
        elsif e + bias > 2 ** ebits - 1 then
          -- Infinity
        else
          exp := u2vec(e + bias, exp);
        end if;
    end case;

    return sign & exp & mant;
  end;

  function imm_create(active : extension_type;
                      v : word5; fmt : word2) return std_logic_vector is
    variable ext_zfh     : boolean := is_enabled(active, x_zfh);
    variable ext_zfbfmin : boolean := is_enabled(active, x_zfbfmin);
    -- Non-constant
    variable res     : word64  := (others => '1');
  begin
    case fmt is
      when "00"   => set_lo(res, imm_create(v, 8, 23));
      when "01"   => set_lo(res, imm_create(v, 11, 52));
      when "10"   =>
        if ext_zfh then
          set_lo(res, imm_create(v, 5, 10));  -- IEEE half precision
          -- Special handling of a couple of values
          if    u2i(v) = 2 then  -- 2^-16
            res(15 downto 0) := '0' & "00000" & "0100000000";
          elsif u2i(v) = 3 then  -- 2^-15
            res(15 downto 0) := '0' & "00000" & "1000000000";
          elsif u2i(v) = 29 then  -- Infinity since 2^16 is not representable
            res(15 downto 0) := '0' & "11111" & "0000000000";
          end if;
        end if;
      when others =>
        null;
    end case;

    return res;
  end;

-- pragma translate_off
  function fpreg2st(reg : reg_t) return string is
  begin
    case reg is
      when FPU_FT0      => return "ft0";
      when FPU_FT1      => return "ft1";
      when FPU_FT2      => return "ft2";
      when FPU_FT3      => return "ft3";
      when FPU_FT4      => return "ft4";
      when FPU_FT5      => return "ft5";
      when FPU_FT6      => return "ft6";
      when FPU_FT7      => return "ft7";
      when FPU_FS0      => return "fs0";
      when FPU_FS1      => return "fs1";
      when FPU_FA0      => return "fa0";
      when FPU_FA1      => return "fa1";
      when FPU_FA2      => return "fa2";
      when FPU_FA3      => return "fa3";
      when FPU_FA4      => return "fa4";
      when FPU_FA5      => return "fa5";
      when FPU_FA6      => return "fa6";
      when FPU_FA7      => return "fa7";
      when FPU_FS2      => return "fs2";
      when FPU_FS3      => return "fs3";
      when FPU_FS4      => return "fs4";
      when FPU_FS5      => return "fs5";
      when FPU_FS6      => return "fs6";
      when FPU_FS7      => return "fs7";
      when FPU_FS8      => return "fs8";
      when FPU_FS9      => return "fs9";
      when FPU_FS10     => return "fs10";
      when FPU_FS11     => return "fs11";
      when FPU_FT8      => return "ft8";
      when FPU_FT9      => return "ft9";
      when FPU_FT10     => return "ft10";
      when FPU_FT11     => return "ft11";
      when others       => return "XXXX";
    end case;
  end;

  function tost_float(v : std_logic_vector) return string is
    variable f : float := to_float_ext(v);
  begin
    case f.class is
      when C_NORMAL =>
        if f.v > 1.0e307 then
          return ">1.0e307";
        elsif f.v < -1.0e307 then
          return "<-1.0e307";
        else
          return tost(f.v);
        end if;
      when C_ZERO =>
        if f.neg then
          return "-Zero";
        else
          return "+Zero";
        end if;
      when C_NAN =>
        if f.snan then
          return "sNaN";
        else
          return "qNaN";
        end if;
      when C_INF =>
        if f.neg then
          return "-Inf";
        else
          return "+Inf";
        end if;
      when others   =>
        return tost(v);
    end case;
  end;

  procedure show_float(text : string; reg : reg_t; v : std_logic_vector) is
  begin
    report text & " " & tost(reg) & " " & tost(v) & " " & tost_float(v);
  end;

-- pragma translate_on
end;
