------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
-- Entity:      nanofpunv
-- File:        nanofpunv.vhd
-- Author:      Magnus Hjorth and Johan Klockars, Cobham Gaisler
-- Description: Minimal bare bones FPC and FPU for NOEL-V,
--              based on the one for LEON5.
------------------------------------------------------------------------------

-- This is a small non-pipelined IEEE754-2008 compliant implementation
-- of an FPC and FPU for providing hardware FPU operations on NOEL-V.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use grlib.config.all;
use grlib.config_types.all;
library gaisler;
use gaisler.utilnv.all;
use grlib.riscv.all;
use gaisler.noelvint.word;
use gaisler.noelvint.word64;
use gaisler.noelvint.zerow64;

entity nanofpunv is
  generic (
    -- Extensions
    fpulen    : integer range 0  to 128 := 0;  -- Floating-point precision
    -- Core
    no_muladd : integer range 0  to 1   := 0   -- 1 - multiply-add not supported
    ; do_addsel : integer := 1
  );
  port (
    clk           : in  std_ulogic;
    rstn          : in  std_ulogic;
    -- Pipeline interface
    --   Issue interface
    holdn         : in  std_ulogic;
    e_inst        : in  word;
    e_valid       : in  std_ulogic;
    e_nullify     : in  std_ulogic;
    csrfrm        : in  std_logic_vector(2 downto 0);
    issue_id      : out std_logic_vector(4 downto 0);
    fpu_holdn     : out std_ulogic;
    ready_flop    : out std_ulogic;
    --   Commit interface
    commit        : in  std_ulogic;
    commitid      : in  std_logic_vector(4 downto 0);
    lddata        : in  word64;
    --   Mispredict/trap interface
    unissue       : in  std_logic_vector(1 to 4);
    unissue_sid   : in  std_logic_vector(4 downto 0);
    -- Register file read interface
    rs1           : out std_logic_vector(4 downto 0);
    rs2           : out std_logic_vector(4 downto 0);
    rs3           : out std_logic_vector(4 downto 0);
    ren           : out std_logic_vector(1 to 3);
    s1            : in  word64;   -- All FPU register file data here
    s2            : in  word64;   -- Unused
    s3            : in  word64;   -- Unused (for muladd)
    -- Result data interface
    rd            : out std_logic_vector(4 downto 0);
    wen           : out std_ulogic;
    flags_wen     : out std_ulogic;
    stdata        : out word64;
    flags         : out std_logic_vector(4 downto 0)
  );
end;

architecture rtl of nanofpunv is

  constant FPUVER : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(5, 3));

  type nanofpu_state is (nf_idle, nf_flopr, nf_flop0, nf_flop1,
                         nf_load2, nf_fromint, nf_store2, nf_mvxw2, nf_min2,
                         nf_muladd2, nf_muladd_mid,
                         nf_muladd_xadd, nf_muladd_xadd25, nf_muladd_xadd26, nf_muladd_xadd27,
                         nf_muladd_xaddsub3, nf_muladd_xaddsub4, nf_muladd_xaddsub5, nf_muladd_xaddsub6,
                         nf_muladd_xaddsub7, nf_muladd_xaddsub8, nf_muladd_xaddsub9,
                         nf_sd2, nf_fitos2, nf_fitos25, nf_fitos3,
                         nf_fstoi2, nf_fstoi25, nf_fstoi3, nf_fstoi4,
                         nf_sgn2, nf_addsub2, nf_addsub25, nf_addsub3,
                         nf_addsub4, nf_addsub5, nf_addsub6, nf_addsub7,
                         nf_mul2, nf_mul25, nf_mul3, nf_mul4, nf_mul5, nf_mul6, nf_mul7,
                         nf_div2, nf_div25, nf_div3, nf_div4, nf_div5, nf_div6,
                         nf_sqrt2, nf_sqrt3, nf_sqrt4, nf_sqrt5, nf_sqrt6,
                         nf_sqrt7, nf_sqrt8, nf_sqrt9, nf_sqrt10, nf_sqrt11,
                         nf_round, nf_round2, nf_repack,
                         nf_opdone, nf_rdwrite, nf_rdwrite2, nf_cmp2, nf_finish, nf_end);

  -- Operand can be in different "states":
  --   invalid - Values are undefined.
  --   pack1   - Exponent is bounded within valid range, leading one at bit 54
  --             except for denormal numbers, mantissa valid also for zero/inf.
  --             (Output of the unpack function.)
  --   pack2   - Same as norm1 but mant part undefined (assumed==0) for
  --             zero/inf classes.
  --             (Valid input to pack function.)
  --   norm    - Leading 1 shifted to bit 54 also for denormal numbers,
  --             exp may be outside valid range,
  --             cls ignored, assumed non-zero normal number.
  --   norm2   - Leading 1 in unknown position,
  --             mantissa may also be all-0 if zero,
  --             cls ignored (assumed 00 or 01 depending on mant).

  -- Shifts
  -- A - shift according to r.expadj (exponen adjust)
  -- N - shift for normalization adjustment
  -- S - single precision
  type op_action is (OPACT_SHFTN, OPACT_SHFTA, OPACT_SHFTNS, OPACT_SHFTAS);

  constant R_NEAREST   : std_logic_vector(2 downto 0) := "000";  -- RNE Nearest, ties to even
  constant R_ZERO      : std_logic_vector(2 downto 0) := "001";  -- RTZ Towards zero
  constant R_MINUS_INF : std_logic_vector(2 downto 0) := "010";  -- RDN Down, towards negative infinity
  constant R_PLUS_INF  : std_logic_vector(2 downto 0) := "011";  -- RUP Up, towards positive infinity
  constant R_RMM       : std_logic_vector(2 downto 0) := "100";  -- Nearest, ties to max magnitude
  -- The rest are illegal, except that in an instruction "111" (DYN)
  -- means that rouding mode should be fetched from CSR register.

  -- Floating point flags
  constant EXC_NX : integer := 0;  -- Inexact
  constant EXC_UF : integer := 1;  -- Underflow
  constant EXC_OF : integer := 2;  -- Overflow
  constant EXC_DZ : integer := 3;  -- Divide by zero
  constant EXC_NV : integer := 4;  -- Invalid

  constant defnan_dp : word64 := x"7ff8000000000000";
  constant defnan_sp : word64 := x"ffffffff7fc00000";

  type fpunv_op is record
    valid : std_ulogic;
    op    : std_logic_vector(4 downto 0);  -- FPU operation
    opx   : std_logic_vector(2 downto 0);  --   extension
    rm    : std_logic_vector(2 downto 0);  -- Rounding mode
    sp    : std_ulogic;                    -- Single precision
    rd    : std_logic_vector(4 downto 0);
    rs1   : std_logic_vector(4 downto 0);
    rs2   : std_logic_vector(4 downto 0);
    rs3   : std_logic_vector(4 downto 0);
    ren   : std_logic_vector(1 to 3);
  end record;

  type nanofpu_regs is record
    -- State
    s           : nanofpu_state;
    fpu_holdn   : std_ulogic;
    readyflop   : std_ulogic;
    -- FSR fields
    rm          : std_logic_vector(2 downto 0);
    -- Current operation
    s1          : word64;
    s2          : word64;
    s3          : word64;
    unpacksel   : integer range 1 to 3;    -- Operation MUX control
    adjustsel   : integer range 1 to 2;
    normadjsel  : integer range 1 to 2;
    addsel      : integer range 1 to 3;
    addneg      : std_ulogic;
    swap        : std_ulogic;              -- Muladd operands need swapping
    res         : word64;
    exc         : std_logic_vector(4 downto 0);
    rddp        : std_ulogic;              -- Double precision operation
    rddp_real   : std_ulogic;              --   actual in case of internal change
    flop        : std_logic_vector(4 downto 0);
    rmb         : std_logic_vector(2 downto 0);
    rs1         : std_logic_vector(4 downto 0);
    rs2         : std_logic_vector(4 downto 0);
    rs3         : std_logic_vector(4 downto 0);
    ren         : std_logic_vector(1 to 3);
    rd          : std_logic_vector(4 downto 0);
    wen         : std_ulogic;
    flags_wen   : std_ulogic;
    committed   : std_ulogic;              -- Operation marked as committed by IU
    op1         : float;
    op2         : float;
    op3neg      : boolean;
    opaction    : op_action;
    vadj        : signed(6 downto 0);
    opnormadj   : signed(6 downto 0);
    nalimdp     : std_ulogic;              -- Adjustment limitation
    nalimsp     : std_ulogic;
    naeven      : std_ulogic;
    expadj      : signed(12 downto 0);
    comphl      : std_ulogic;
    comphe      : std_ulogic;
    compll      : std_ulogic;
    comple      : std_ulogic;
    carry       : std_ulogic;
    mulctr1     : unsigned(1 downto 0);
    mulctr2     : unsigned(1 downto 0);
    mulctrlim   : unsigned(1 downto 0);
    mulsel2     : std_ulogic;
    shftpl      : std_ulogic;
    shftpl2     : std_ulogic;
    sqrtctr     : unsigned(5 downto 0);
    -- 16x16 multiplier/accumulator pipeline
    muli1       : unsigned(15 downto 0);
    muli2       : unsigned(15 downto 0);
    mulo        : unsigned(31 downto 0);
    mulen       : std_ulogic;
    accen       : std_ulogic;
    accshft     : std_ulogic;
    acc         : unsigned(31 downto 0);
    acclo       : unsigned(27 downto 0);   -- Low multiplier bits for muladd
    acclo0      : unsigned(0 downto 0);
    accbot      : unsigned(51 downto 0);
    -- Divider registers
    divfirst    : std_ulogic;
    divcmp1     : std_ulogic;
    divcmp11    : std_ulogic;
    divcmp2     : std_ulogic;
    divremz     : std_ulogic;
  end record;

  constant RRES : nanofpu_regs := (
    s           => nf_idle,
    fpu_holdn   => '1',
    readyflop   => '0',
    rm          => R_NEAREST,
    s1          => (others => '0'),
    s2          => (others => '0'),
    s3          => (others => '0'),
    unpacksel   => 1,
    adjustsel   => 1,
    normadjsel  => 1,
    addsel      => 1,
    addneg      => '0',
    swap        => '0',
    res         => (others => '0'),
    exc         => "00000",
    rddp        => '0',
    rddp_real   => '0',
    flop        => (others => '0'),
    rmb         => (others => '0'),
    rs1         => "00000",
    rs2         => "00000",
    rs3         => "00000",
    ren         => "000",
    rd          => "00000",
    wen         => '0',
    flags_wen   => '0',
    committed   => '0',
    op1         => float_none,
    op2         => float_none,
    op3neg      => false,
    opaction    => OPACT_SHFTN,
    vadj        => (others => '0'),
    opnormadj   => (others => '0'),
    nalimdp     => '0',
    nalimsp     => '0',
    naeven      => '0',
    expadj      => (others => '0'),
    comphl      => '0',
    comphe      => '0',
    compll      => '0',
    comple      => '0',
    carry       => '0',
    mulctr1     => "00",
    mulctr2     => "00",
    mulctrlim   => "00",
    mulsel2     => '0',
    shftpl      => '0',
    shftpl2     => '0',
    sqrtctr     => "000000",
    muli1       => (others => '0'),
    muli2       => (others => '0'),
    mulo        => (others => '0'),
    mulen       => '0',
    accen       => '0',
    accshft     => '0',
    acc         => (others => '0'),
    acclo       => (others => '0'),
    acclo0      => (others => '0'),
    accbot      => (others => '0'),
    divfirst    => '0',
    divcmp1     => '0',
    divcmp11    => '0',
    divcmp2     => '0',
    divremz     => '0'
  );


  signal r, rin : nanofpu_regs;

begin

  comb : process(r, rstn, holdn,
                 e_inst, e_valid, e_nullify, csrfrm,
                 s1, s2, s3, lddata,
                 commit, commitid, unissue, unissue_sid)
    variable v        : nanofpu_regs;
    variable vrs1     : word64;
    variable vrs2     : word64;
    variable addx     : unsigned(28 downto 0);
    variable addy     : unsigned(28 downto 0);
    variable vtmpadd  : unsigned(28 downto 0);
    variable vtmpaddx : unsigned(29 downto 0);
    variable xtmpaddx : unsigned(r.accbot'length downto 0);
    variable vtmpexp  : signed(12 downto 0);
    variable vadj     : signed(6 downto 0);
    variable vgrd     : std_ulogic;
    variable vrndbits : std_logic_vector(2 downto 0);
    variable vrndup   : std_ulogic;
    variable vop      : float;
    variable inf_1x2  : float;
    variable defnan   : word64;
    variable fcc      : std_logic_vector(1 downto 0);
    variable use_fs2  : boolean;
    variable n        : integer range 0 to 7;
    variable sign     : std_ulogic;
    variable unpackee : word64;
    variable unpacked : float;
    variable normee   : float;
    variable adjustee : float;
    variable adjusted : float;
    variable rounded  : float;
    variable roundexc : std_logic_vector(4 downto 0);
    variable issue_op  : fpunv_op;
    variable issue_cmd : std_ulogic;
    variable roundadd : integer;
    variable roundchk : std_ulogic;
    variable divrem   : boolean;    -- Make use of divrem (r.s1 storage)
    variable divrem1  : unsigned(28 downto 0);
    variable divrem2  : unsigned(28 downto 0);
    variable op2low0  : boolean;

    function tost(x : signed) return string is
    begin
      return tost(std_logic_vector(x));
    end;

    -- FPU Signals Generation

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

    -- Partial decode of FPU operation
    procedure fpu_gen(inst_in     : in  std_logic_vector;
                      csr_frm     : in  std_logic_vector;
                      valid_in    : in  std_ulogic;
                      op_out      : out fpunv_op) is
      subtype word2  is std_logic_vector(1 downto 0);
      subtype word3  is std_logic_vector(2 downto 0);
      variable RFBITS : integer := 5;
      subtype rfatype is std_logic_vector(RFBITS-1 downto 0);
      variable opcode : opcode_type := inst_in(6 downto 0);
      variable funct5 : funct5_type := inst_in(31 downto 27);
      variable funct3 : funct3_type := inst_in(14 downto 12);
      variable fmt    : word2       := inst_in(26 downto 25);
      variable rs1    : rfatype     := inst_in(19 downto 15);
      variable rs2    : rfatype     := inst_in(24 downto 20);
      variable rs3    : rfatype     := inst_in(31 downto 27);
      variable rd     : rfatype     := inst_in(11 downto  7);
      -- Non-constant
      variable valid  : std_ulogic  := valid_in;
      variable rm     : word3       := funct3;
      variable sp     : boolean;
      variable op     : std_logic_vector(4 downto 0);
      variable ren    : std_logic_vector(op_out.ren'range);
    begin
      sp := fmt = "00";      -- single precision

      case opcode is
        when OP_FP       => op := funct5;
        when OP_LOAD_FP  => op := S_LOAD;
                            sp := funct3 = "010";  -- 32 bit memory access?
        when OP_STORE_FP => op := S_STORE;
                            sp := funct3 = "010";
        when OP_FMADD  |
             OP_FMSUB  |
             OP_FNMADD |
             OP_FNMSUB   => op := opcode(6 downto 2);
        when others      => op := opcode(6 downto 2);  -- Dummy!
                            valid := '0';
      end case;

      -- CSR controlled rounding?
      if funct3 = "111" then
        rm := csr_frm;
      end if;

      ren(1) := fs1_gen(inst_in);
      ren(2) := fs2_gen(inst_in);
      ren(3) := fs3_gen(inst_in);

      op_out := (valid, op, funct3, rm, to_bit(sp), rd, rs1, rs2, rs3, ren);
    end;

    -- Find shift amount for normalization.
    function find_normadj(op     : float;
                          limdp  : std_ulogic; limsp : std_ulogic;
                          mkeven : std_ulogic) return signed is
      -- Non-constant
      variable r      : signed(6 downto 0)  := "0000000";
      variable maxadj : signed(6 downto 0)  := "0111111";   -- 63
      variable adjtmp : signed(12 downto 0);
    begin
      if limdp = '1' then
        adjtmp   := op.exp + 1022;
        -- -64 to 63?
        if all_0(adjtmp(12 downto 6)) or all_1(adjtmp(12 downto 6)) then
          maxadj := adjtmp(6 downto 0);
        end if;
      end if;
      if limsp = '1' then
        adjtmp   := op.exp + 126;
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
      if mkeven = '1' then
        if (r(0) xor op.exp(0)) = '1' then
          r := r + 1;
        end if;
      elsif r > maxadj then
        r   := maxadj;
      end if;

      return r;
    end find_normadj;

    -- Convert integer value to internal format.
    function int2ernal(opu : word64; neg : boolean) return float is
      variable r : float := float_none;
    begin
      r.w       := opu;
      r.neg     := neg;
      r.exp     := to_signed(52, 13);
      r.mant    := "00" & opu(51 downto 0) & "00";
      if all_0(r.mant(54 downto 0)) then             -- Zero?
        r.class := C_ZERO;
      end if;

      return r;
    end int2ernal;

    -- Convert integer value to internal format - high bits.
    function int2ernalh(opu : word64; neg : boolean) return float is
      variable r : float := float_none;
    begin
      r.w       := opu;
      r.neg     := neg;
      r.exp     := to_signed(64, 13);
      r.mant    := "00" & opu(63 downto 52) & zerow64(41 downto 0);
      if all_0(r.mant(54 downto 0)) then             -- Zero?
        r.class := C_ZERO;
      end if;

      return r;
    end int2ernalh;

    -- Convert single/double precision floating point value to internal format.
    function unpack(opu : word64;
                    sp  : std_ulogic) return float is
      variable r : float := float_none;
    begin
      r.w            := opu;
      if sp = '1' then
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

      return r;
    end unpack;

    -- Convert internal format to IEEE754 single/double precision value.
    function pack(op : float; sp : std_ulogic) return std_logic_vector is
      variable r : word64;
    begin
      r                   := (others => '0');
      r(63)               := to_bit(op.neg);
      r(51 downto 0)      := op.mant(53 downto 2);
      if sp = '0' then
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
    end pack;


    -- Shift mantissa
    function adjust_new(mant_in : std_logic_vector(55 downto 0);
                        vadj    : signed(6 downto 0)) return std_logic_vector is
      variable mant0 : std_logic_vector(55 downto 0) := (others => mant_in(0));
      variable xant  : std_logic_vector(55 downto 0) := mant_in;
      variable xadj  : signed(6 downto 0)            := vadj;
      variable neg   : boolean                       := vadj(vadj'high) = '1';
      variable low1  : boolean                       := false;
    begin
      if vadj(vadj'high) = '0' then
        xant := mant_in;
        if vadj(5) = '1' then
          xant := xant(xant'high - 32 downto 0) & mant0(31 downto 0);
        end if;
        if vadj(4) = '1' then
          xant := xant(xant'high - 16 downto 0) & mant0(15 downto 0);
        end if;
        if vadj(3) = '1' then
          xant := xant(xant'high - 8 downto 0) & mant0(7 downto 0);
        end if;
        if vadj(2) = '1' then
          xant := xant(xant'high - 4 downto 0) & mant0(3 downto 0);
        end if;
        if vadj(1) = '1' then
          xant := xant(xant'high - 2 downto 0) & mant0(1 downto 0);
        end if;
        if vadj(0) = '1' then
          xant := xant(xant'high - 1 downto 0) & mant0(0);
        end if;
      else
        xant      := (others => '0');
        if vadj < -54 then
          -- Too large down shift results in 0 (except for bottom rounding bit).
          if not all_0(mant_in) then
            xant(0) := '1';
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
          -- Note any out-shifted bits at the low end.
          if low1 then
            xant(0) := '1';
          end if;
        end if;
      end if;

      return xant;
    end;


  begin
    v := r;

    -- Sometimes reused storage
    divrem  := false;    -- Assume not use
    divrem1 := unsigned(r.s1(28      downto 0));
    divrem2 := unsigned(r.s1(28 + 32 downto 32));

    fpu_gen(e_inst, csrfrm, e_valid, issue_op);
    issue_cmd := issue_op.valid;

    if r.rddp_real = '1' then
      defnan := defnan_dp;
    else
      defnan := defnan_sp;
    end if;

    -- S1/S2/S3 data path

    -- Swap halves for single precision,
    -- to enable NaN-boxing check.
    if r.rddp = '0' then
      vrs1(63 downto 32) := r.s1(31 downto 0);
      vrs1(31 downto 0)  := r.s1(63 downto 32);
      vrs2(63 downto 32) := r.s2(31 downto 0);
      vrs2(31 downto 0)  := r.s2(63 downto 32);
    else
      vrs1               := r.s1;
      vrs2               := r.s2;
    end if;

    if not notx(r.s1) then
      setx(vrs1);
    end if;
    if not notx(r.s2) then
      setx(vrs2);
    end if;

    -- Flags (like SPARC) for fcmp/fmin
    if (is_zero(r.op1) and is_zero(r.op2)) or     -- +/- 0 equal
       (r.comphe = '1' and r.comple = '1' and
        r.op1.neg = r.op2.neg) then               -- 1 = 2
      fcc   := "00";
    else                                          -- The rest invert on negative
      if r.op1.neg /= r.op2.neg then              --  1 > 2, different sign
        fcc := "10";                              --  Below is same sign
      elsif r.comphl = '1' then                   --   1 < 2, high bits smaller
        fcc := "01";
      elsif r.comphe = '0' then                   --   1 > 2, high bits not equal
        fcc := "10";
      elsif r.compll = '1' then                   --   1 < 2, low bits smaller
        fcc := "01";
      else           -- r.comple = '0'            --   1 > 2, low bits not equal
        fcc := "10";
      end if;
      if r.op1.neg then                           -- Invert if negative
        fcc := not fcc;
      end if;
    end if;

    -- Compare resource on RS1/RS2
    v.comphl     := '0';
    v.comphe     := '0';
    v.compll     := '0';
    v.comple     := '0';
    if notx(vrs1) and notx(vrs2) then
      if unsigned(vrs1(62 downto 32)) < unsigned(vrs2(62 downto 32)) then
        v.comphl := '1';
      end if;
      if unsigned(vrs1(62 downto 32)) = unsigned(vrs2(62 downto 32)) then
        v.comphe := '1';
      end if;
      if unsigned(vrs1(31 downto 0)) < unsigned(vrs2(31 downto 0)) then
        v.compll := '1';
      end if;
      if unsigned(vrs1(31 downto 0)) = unsigned(vrs2(31 downto 0)) then
        v.comple := '1';
      end if;
    else
      setx(v.comphl);
      setx(v.comphe);
      setx(v.compll);
      setx(v.comple);
    end if;

    unpackee   := r.s1;
    if r.unpacksel = 2 then
      unpackee := r.s2;
    elsif no_muladd = 0 and r.unpacksel = 3 then
      unpackee := r.s3;
    end if;

    unpacked := unpack(unpackee, not r.rddp_real);

    case r.adjustsel is
    when 1 => adjustee := r.op1;
    when 2 => adjustee := r.op2;
    end case;

    adjusted := adjustee;

    case r.opaction is
      when OPACT_SHFTN | OPACT_SHFTNS =>
        adjusted.exp  := adjustee.exp - r.opnormadj;
        vadj   := r.opnormadj;
        -- Actually -64? Then use -63!
        if vadj = "1000000" then
          vadj := "1000001";
        end if;
      when others =>
        adjusted.exp  := adjustee.exp - r.expadj;
        vadj   := r.expadj(6 downto 0);
        -- Lower than -64? Then use -63!
        if r.expadj(12) = '1' and not all_1(r.expadj(12 downto 6)) then
          vadj := "1000001";
        end if;
    end case;

    if not notx(vadj) then
      vadj := (others => '0');
    end if;

    adjusted.mant := adjust_new(adjustee.mant, vadj);

    -- Single precision?
    vgrd   := '0';
    for q in 0 to 29 loop
      vgrd := vgrd or adjusted.mant(q);
    end loop;
    if r.opaction = OPACT_SHFTAS or r.opaction = OPACT_SHFTNS then
      adjusted.mant(29) := vgrd;
    end if;


    rounded  := r.op2;
    if not (notx(rounded.exp) and notx(rounded.mant)) then
      rounded := float_none;
    end if;
    roundexc  := r.exc;

    vrndbits        := r.op2.mant(2 downto 0);
    if r.rddp = '0' then
      vrndbits      := r.op2.mant(31 downto 29);
      for x in 28 downto 0 loop
        vrndbits(0) := vrndbits(0) or r.op2.mant(x);
      end loop;
    end if;

    vrndup := '0';
    case r.rm is
      when R_NEAREST =>
        if vrndbits(1) = '1' and (vrndbits(0) = '1' or vrndbits(2) = '1') then
          vrndup := '1';
        end if;
      when R_ZERO =>
        vrndup   := '0';
      when R_PLUS_INF =>
        vrndup   := not to_bit(r.op2.neg) and (vrndbits(1) or vrndbits(0));
      when R_MINUS_INF =>
        vrndup   := to_bit(r.op2.neg) and (vrndbits(1) or vrndbits(0));
      when others =>  -- R_RMM - to nearest, ties away from zero
        vrndup   := vrndbits(1);
    end case;

    if vrndup = '1' then
      if r.rddp = '1' then
        rounded.mant(53 downto 2)  := std_logic_vector(unsigned(r.op2.mant(53 downto 2)) + 1);
        if all_1(r.op2.mant(53 downto 2)) then
          rounded.mant(54)         := '1';
          if r.op2.mant(54) = '1' then
            rounded.exp            := r.op2.exp + 1;
          end if;
        end if;
      else
        rounded.mant(53 downto 31) := std_logic_vector(unsigned(r.op2.mant(53 downto 31)) + 1);
        if all_1(r.op2.mant(53 downto 31)) then
          rounded.mant(54)         := '1';
          if r.op2.mant(54) = '1' then
            rounded.exp            := r.op2.exp + 1;
          end if;
        end if;
      end if;
    end if;

    -- Inexact
    if vrndbits(1 downto 0) /= "00" then
      roundexc(EXC_NX) := '1';
    end if;

    -- Underflow
    if rounded.mant(54) = '0' and roundexc(EXC_NX) = '1' then
      roundexc(EXC_UF) := '1';
    end if;

    -- Underflow to zero
    if (r.rddp = '0' and rounded.exp < -126) or rounded.exp < -1022 then
      roundexc(EXC_UF) := '1';
      roundexc(EXC_NX) := '1';
      rounded.class    := C_ZERO;
    end if;

    -- Overflow
    if rounded.exp > 1023 or (r.rddp = '0' and rounded.exp > 127) then
      roundexc(EXC_OF) := '1';
      roundexc(EXC_NX) := '1';
      -- Set the operand to infinity, this is not right for all rounding modes.
      --   Those cases gets patched up in nf_pack state.
      rounded.class    := C_INF;
    end if;


  if do_addsel /= 0 then
    -- Generic adder
    case r.addsel is
    when 1     => addy := unsigned('0' & r.op2.mant(27 downto 0));
                  addx := unsigned('0' & r.op1.mant(27 downto 0));
    when 2 | 3 => addy := unsigned('0' & r.op2.mant(55 downto 28));
                  addx := unsigned('0' & r.op1.mant(55 downto 28));
    end case;
    if r.addneg = '1' then
      vtmpadd := addx - addy;
      if r.carry = '1' then
        vtmpadd := vtmpadd - 1;
      end if;
    else
      vtmpadd := addx + addy;
      if r.carry = '1' then
        vtmpadd := vtmpadd + 1;
      end if;
    end if;
  end if;

    -- Unpacking and re-normalization logic for r.op1.mant, r.op2.mant.
    -- Also rounding for r.op2.mant.

    case r.normadjsel is
      when 1 => normee := r.op1;
      when 2 => normee := r.op2;
    end case;
    v.opnormadj := find_normadj(normee, r.nalimdp, r.nalimsp, r.naeven);

    -- Multiplier/accumulator pipeline
    -- Dealing with 14 bits at a time.
    if r.accen = '1' then
      if r.accshft = '1' then
        -- Shift down 14 bits
        if no_muladd = 0 then
          v.accbot            := r.acclo(13 downto 1) & r.acclo0 & v.accbot(v.accbot'high downto 14);
          v.acclo0            := r.acclo(14 downto 14);
        end if;
        v.acclo(13 downto 1)  := r.acclo(27 downto 15);
        vgrd                  := '0';
        for x in 0 to 14 loop
          vgrd                := vgrd or r.acclo(x);
        end loop;
        v.acclo(0)            := vgrd;
        v.acclo(27 downto 14) := r.acc(13 downto 0);
        v.acc(17 downto 0)    := r.acc(31 downto 14);
        v.acc(31 downto 18)   := (others => '0');
      end if;
      v.acc                   := v.acc + r.mulo;
    end if;

    if notx(std_logic_vector(r.muli1)) and notx(std_logic_vector(r.muli2)) then
      v.mulo := r.muli1 * r.muli2;
    else
      setx(v.mulo);
    end if;

    case r.mulctr1 is
      when "00"   => v.muli1 := unsigned'("00") & unsigned(r.op1.mant(12 downto 1)) & unsigned'("00");
      when "01"   => v.muli1 := unsigned'("00") & unsigned(r.op1.mant(26 downto 13));
      when "10"   => v.muli1 := unsigned'("00") & unsigned(r.op1.mant(40 downto 27));
      when others => v.muli1 := unsigned'("00") & unsigned(r.op1.mant(54 downto 41));
    end case;
    vop   := r.op2;
    if r.mulsel2 = '1' then
      vop := r.op1;
    end if;
    case r.mulctr2 is
      when "00"   => v.muli2 := unsigned'("00") & unsigned(vop.mant(12 downto 1)) & unsigned'("00");
      when "01"   => v.muli2 := unsigned'("00") & unsigned(vop.mant(26 downto 13));
      when "10"   => v.muli2 := unsigned'("00") & unsigned(vop.mant(40 downto 27));
      when others => v.muli2 := unsigned'("00") & unsigned(vop.mant(54 downto 41));
    end case;
    if r.mulsel2 = '1' and std_logic_vector(r.mulctr1) /= std_logic_vector(r.mulctr2) then
      v.muli2 := v.muli2(14 downto 0) & '0';
    end if;

    -- FPC flow control
    if commit = '1' and holdn = '1' then
      v.committed := '1';
    end if;

    -- Main command FSM
    v.opaction  := OPACT_SHFTN;
    v.nalimdp   := '0';
    v.nalimsp   := '0';
    v.naeven    := '0';
    v.accen     := r.mulen;
    v.accshft   := r.shftpl;
    v.mulen     := '0';
    v.shftpl    := r.shftpl2;
    v.shftpl2   := '0';
    v.mulsel2   := '0';
    v.wen       := '0';
    v.flags_wen := '0';

    v.unpacksel  := 1;
    v.adjustsel  := 1;
    v.normadjsel := 2;
    v.ren        := (others => '0');

    case r.s is
      when nf_idle =>
        v.rd          := issue_op.rd;
        v.rm          := issue_op.rm;
        v.rmb         := issue_op.opx;
        v.rddp        := not issue_op.sp;
        v.flop        := issue_op.op;
        v.committed   := '0';
        v.exc         := (others => '0');
        v.acc         := (others => '0');
        v.acclo       := (others => '0');
        v.acclo0      := (others => '0');
        v.accbot      := (others => '0');
        v.exc         := (others => '0');
        v.fpu_holdn   := '1';
        if issue_cmd = '1' and holdn = '1' then
          v.committed := commit;
          if issue_op.op = S_LOAD or issue_op.op = R_FMV_W_X then
            v.s       := nf_load2;
          elsif issue_op.op = S_STORE then
            v.rs1     := issue_op.rs2;
            v.ren     := issue_op.ren;
            v.s       := nf_flop0;
          elsif issue_op.op = R_FCVT_S_W then
            v.rs2     := issue_op.rs2;  -- Used for instruction disambiguation
            v.s       := nf_fromint;
          else
            v.rs1     := issue_op.rs1;
            v.rs2     := issue_op.rs2;
            v.rs3     := issue_op.rs3;
            v.ren     := issue_op.ren;
            v.s       := nf_flopr;
          end if;
          -- The source is the other size for fcvt.s/d.d/s!
          if issue_op.op = R_FCVT_S_D then
            v.rddp    := issue_op.sp;
          end if;
          -- Some operations require the integer pipeline to wait on completion.
          if issue_op.op = S_STORE   or issue_op.op = R_FCMP or
             issue_op.op = R_FMV_X_W or issue_op.op = R_FCVT_W_S then
            v.fpu_holdn := '0';
          end if;
        end if;
        -- Some operations will temporarily change r.rddp.
        v.rddp_real     := v.rddp;

      when nf_flopr =>
        v.s   := nf_flop0;
        v.ren := r.ren and "010";
        if v.ren(2) = '1' then
          v.rs1 := r.rs2;
        end if;

      when nf_flop0 =>
        v.op1                 := unpacked;
        case r.flop is
          when S_FMADD | S_FMSUB | S_FNMSUB | S_FNMADD =>
            v.ren             := "001";
            v.rs1             := r.rs3;
          when others =>
        end case;
        v.unpacksel           := 2;
        v.res                 := r.s1;  -- For fmv.x.w and fs*
        if r.rddp = '0' and r.flop /= R_FSGN and r.flop /= R_FMIN then
          v.res(63 downto 32) := (others => r.s1(31));
        end if;
        v.s                   := nf_flop1;

      when nf_flop1 =>
        v.op2           := unpacked;
        v.normadjsel    := 1;
        v.unpacksel     := 3;
        -- Unpack operands
        case r.flop is
          when S_STORE =>
            v.res                 := r.s2;
            if r.rddp = '0' then
              v.res(63 downto 32) := r.s2(31 downto 0);
            end if;
            v.s                   := nf_store2;
          when S_FMADD | S_FMSUB | S_FNMSUB | S_FNMADD =>
            if no_muladd = 0 then
              v.s        := nf_muladd2;
            else
              v.s        := nf_idle;
            end if;
          when R_FCMP =>
            v.s          := nf_cmp2;
          when R_FMV_X_W =>
            v.s          := nf_mvxw2;
          when R_FCVT_S_D =>        -- Also D_S
            -- Swap around for result!
            v.rddp       := not r.rddp;
            v.rddp_real  := v.rddp;
            if v.rddp = '0' then
              v.nalimsp  := '1';
            end if;
            v.op2        := r.op1;
            v.normadjsel := 2;
            v.s          := nf_sd2;
          when R_FCVT_W_S =>
            v.op2       := r.op1;
            v.s         := nf_fstoi2;
          when R_FSGN =>
            v.s         := nf_sgn2;
          when R_FMIN =>
            v.s         := nf_min2;
          when R_FADD | R_FSUB =>
            v.s         := nf_addsub2;
          when R_FMUL =>
            v.s         := nf_mul2;
          when R_FDIV =>
            v.res       := (others => '0');
            v.s         := nf_div2;
          when R_FSQRT =>
            v.res       := (others => '0');
            v.op2       := r.op1;
            v.normadjsel := 2;
            v.s         := nf_sqrt2;
            v.naeven    := '1';
          when others =>
            v.s         := nf_idle;
        end case;

      when nf_load2 =>
        -- Remember last valid lddata (exception stage)
        if holdn = '1' then
          v.res                 := lddata;
        end if;
        -- Continue when instruction is committed (write-back stage)
        if commit = '1' and holdn = '1' then
          v.res               := r.res;
          v.s                 := nf_opdone;
          if r.rddp = '0' then
            v.res(63 downto 32) := (others => '1');  -- NaN-boxing
          end if;
        end if;

      -- S/D_W/WU/L/LU
      when nf_fromint =>
        -- Remember last valid lddata (exception stage)
        if holdn = '1' then
          v.s2   := lddata;
        end if;
        -- Continue when instruction is committed (write-back stage)
        if commit = '1' and holdn = '1' then
          v.s2 := r.s2;
          v.s     := nf_fitos2;
          sign      := '0';
          case r.rs2(1 downto 0) is
            when "00" =>  -- _W
              sign  := v.s2(31);
              v.s2(63 downto 32) := (others => sign);
            when "01" =>  -- _WU
              v.s2(63 downto 32) := (others => '0');
            when "10" =>  -- _L
              sign  := v.s2(63);
            when others =>  -- 11 _LU
              null;
          end case;
          if sign = '1' then
            v.s2 := std_logic_vector(unsigned(not v.s2) + 1);
          end if;
          -- Take care of top bits with an add later if needed.
          v.op1     := int2ernalh(v.s2, sign = '1');
          v.op2     := int2ernal(v.s2, sign = '1');
        end if;
        v.normadjsel := 1;

      when nf_fitos2 =>
        if is_zero(r.op2) and is_zero(r.op1) then
          v.s            := nf_repack;
        else
          -- Figure out the amount to shift up the exponent
          -- calculated by op1/2normadj.
          if is_normal(r.op1) then
            v.opaction   := OPACT_SHFTN;
            if r.rddp = '0' then
              v.opaction := OPACT_SHFTNS;
            end if;
          end if;
          v.adjustsel    := 1;
          v.normadjsel   := 2;
          v.s            := nf_fitos25;
        end if;

      when nf_fitos25 =>
        v.op1          := adjusted;
        v.adjustsel    := 2;
        v.s            := nf_fitos3;
        if is_normal(r.op2) then
          v.opaction   := OPACT_SHFTN;
          if r.rddp = '0' then
            v.opaction := OPACT_SHFTNS;
          end if;
        end if;

      when nf_sd2 =>
        -- Figure out the amount to shift up the exponent
        -- calculated by op2normadj.
        if is_normal(r.op2) then
          v.s           := nf_fitos3;
          v.adjustsel   := 2;
          v.opaction    := OPACT_SHFTN;
          if r.rddp = '0' then
            v.opaction  := OPACT_SHFTNS;
          end if;
        elsif is_signan(r.op2) then
          v.res         := defnan;
          v.exc(EXC_NV) := '1';
          v.s           := nf_opdone;
        else
          v.s           := nf_repack;
        end if;

      when nf_fitos3 =>
        v.op2      := adjusted;
        -- Shift up the value (opaction = SHFTN)
        v.s        := nf_repack;
        -- Go through nf_round to get over/underflow check for fcvt.s.d.
        -- Also do this for FITOS to get inexact exception check.
        -- Note that fcvt.d.s and fcvt.d.w[u] are always exact and thus do not require rounding.
        if is_normal(r.op2) and
           not ((v.rddp = '1' and r.flop = R_FCVT_S_D) or
                (v.rddp = '1' and r.flop = R_FCVT_S_W and (r.rs2 = R_FCVT_W or r.rs2 = R_FCVT_WU))) then
          v.s      := nf_round;
        end if;
        -- In case of integer to floating point coversions,
        -- check for any high bits that need to be added.
        if r.flop = R_FCVT_S_W and not is_zero(r.op1) then
          v.flop   := R_FADD;
          v.comphl := '0';  -- v.op1 _is_ higher
          v.comphe := '0';
          v.compll := '0';
          v.comple := '0';
          v.s      := nf_addsub2;
        end if;

      when nf_fstoi2 =>
        if is_nan(r.op2) then
          v.exc(EXC_NV)   :='1';
        end if;
        if is_nan(r.op2) or is_inf(r.op2) or
           (r.rs2(1 downto 0) = "00" and r.op2.exp > 30) or    -- _W
           (r.rs2(1 downto 0) = "01" and r.op2.exp > 31) or    -- _WU
           (r.rs2(1 downto 0) = "10" and r.op2.exp > 62) or    -- _L
           (r.rs2(1 downto 0) = "11" and r.op2.exp > 63) then  -- _LU
          if is_nan(r.op2) or not r.op2.neg then
            if r.rs2(0) = '1' then     -- _WU or _LU
              v.res       := x"ffffffffffffffff";
            else
              if r.rs2(1) = '1' then   -- _L
                v.res     := x"7fffffffffffffff";
              else
                v.res     := x"000000007fffffff";
              end if;
            end if;
          else
            if r.rs2(0) = '1' then     -- _WU or _LU
              v.res       := x"0000000000000000";
            else
              if r.rs2(1) = '1' then   -- _L
                v.res     := x"8000000000000000";
              else
                v.res     := x"ffffffff80000000";
              end if;
            end if;
          end if;

          -- _W or _L and negative? Special handling near max negative.
          if is_normal(r.op2) and r.op2.neg and r.rs2(0) = '0' then
            if r.rs2(1) = '0' then                                 -- _W?
              -- Definitely larger than maximum negative?
              if not (r.op2.exp = 31 and all_0(r.op2.mant(53 downto 23))) then
                v.exc(EXC_NV) := '1';
              -- Integer part is max negative, check fractions.
              elsif r.op2.mant(22) = '1' then                      -- >= 0.5?
                -- Round to nearest and > 0.5, or >= 0.5 and to -Inf (also max magnitude since negative)?
                v.exc(EXC_NV) := to_bit((r.rm = R_NEAREST and not all_0(r.op2.mant(21 downto 2))) or
                                        r.rm = R_MINUS_INF or r.rm = R_RMM);
                v.exc(EXC_NX) := not v.exc(EXC_NV);
              elsif not all_0(r.op2.mant(21 downto 2)) then        -- < 0.5 and /= 0?
                v.exc(EXC_NV) := to_bit(r.rm = R_MINUS_INF);
                v.exc(EXC_NX) := not v.exc(EXC_NV);
              end if;
            else                                                   -- _L
              -- No faction. Integer part greater than maximum negative?
              if not (r.op2.exp = 63 and all_0(r.op2.mant(53 downto 2))) then
                v.exc(EXC_NV) := '1';
              end if;
            end if;
          else
            v.exc(EXC_NV) := '1';
          end if;

          -- Did we set any flags above?
          if v.exc(EXC_NV) = '1' or v.exc(EXC_NX) = '1' then
            v.s           := nf_finish;
          else
            v.s           := nf_end;
            if commit = '1' or r.committed = '1' then
              v.s         := nf_idle;
            end if;
            v.fpu_holdn   := '1';
          end if;
        elsif is_zero(r.op2) then
          v.res           := (others => '0');
          v.fpu_holdn     := '1';
          v.s             := nf_end;
          if commit = '1' or r.committed = '1' then
            v.s           := nf_idle;
          end if;
        elsif r.op2.neg and r.op2.exp >= 0 and r.rs2(0) = '1' then   -- _WU or _LU
          v.res           := zerow64;
          if r.op2.exp >= 0 then
            v.exc(EXC_NV) := '1';
            v.s           := nf_finish;
          else
            v.fpu_holdn   := '1';
            v.s           := nf_end;
            if commit = '1' or r.committed = '1' then
              v.s         := nf_idle;
            end if;
          end if;
        else
          -- Calculate the amount to shift up to get an exponent of 2^64.
          --   This will place the high bits in the mantissa bits 53:42.
          v.expadj        := r.op1.exp - 64;
          v.opaction      := OPACT_SHFTA;
          v.s             := nf_fstoi25;
          v.adjustsel     := 1;
        end if;

      when nf_fstoi25 =>
        v.op1       := adjusted;
        -- Performing shift
        -- Calculate the amount to shift up to get an exponent of 2^52.
        --   This will place the number in the mantissa bits 53:2.
        v.expadj    := r.op2.exp - 52;
        v.opaction  := OPACT_SHFTA;
        v.adjustsel := 2;
        v.s         := nf_fstoi3;

      when nf_fstoi3 =>
        v.op2 := adjusted;
        -- Performing shift
        v.s   := nf_fstoi4;

      when nf_fstoi4 =>
        -- Rounding (table from Wikipedia)
        -- Example value to round to integer +11.5 +12.5 -11.5 -12.5
        -- to nearest, ties to even           +12   +12   -12   -12
        -- to nearest, ties away from zero    +12   +13   -12   -13
        -- toward 0                           +11   +12   -11   -12
        -- toward positive infinity           +12   +13   -11   -12
        -- toward negative infinity           +11   +12   -12   -13
        v.s                   := nf_end;
        if commit = '1' or r.committed = '1' then
          v.s                 := nf_idle;
        end if;
        roundadd := 0;
        case r.rm is
          when R_ZERO =>
          when R_NEAREST =>
            if r.op2.mant(2 downto 0) = "110" or     -- Odd and exact half
              r.op2.mant(1 downto 0) = "11" then     -- Half and a bit more
              roundadd := 1;
            end if;
          when R_MINUS_INF =>
            if r.op2.mant(1 downto 0) /= "00" and r.op2.neg then
              roundadd := 1;
            end if;
          when R_PLUS_INF =>
            if r.op2.mant(1 downto 0) /= "00" and not r.op2.neg then
              roundadd := 1;
            end if;
          when others =>  -- R_RMM - to nearest, ties away from zero
            if r.op2.mant(1 downto 0) = "10" or      -- Exact half
               r.op2.mant(1 downto 0) = "11" then    -- Half and a bit more
              roundadd := 1;
            end if;
        end case;
        -- Extract result from mantissa bits
        if r.op2.neg then
          -- _W or _WU?
          if r.rs2(1) = '0' then
            v.res(31 downto 0)   := std_logic_vector(-signed(r.op2.mant(33 downto 2)));
            roundchk             := v.res(31);
            v.res(31 downto 0)   := std_logic_vector(signed(v.res(31 downto 0)) - roundadd);
            if roundadd = 1 and roundchk = '1' and v.res(31) = '0' then
              v.res(31 downto 0) := (others => '1');
              v.exc(EXC_NV)      := '1';
              v.s                := nf_finish;
            end if;
          else
            v.res(51 downto 0)   := r.op2.mant(53 downto 2);
            v.res(63 downto 52)  := r.op1.mant(53 downto 42);
            v.res                := std_logic_vector(-signed(v.res));
            roundchk             := v.res(63);
            v.res                := std_logic_vector(signed(v.res) - roundadd);
            if roundadd = 1 and roundchk = '1' and v.res(63) = '0' then
              v.res              := (others => '1');
              v.exc(EXC_NV)      := '1';
              v.s                := nf_finish;
            end if;
          end if;
        else
          -- _W or _WU?
          if r.rs2(1) = '0' then
            v.res(31 downto 0)   := '0' & r.op2.mant(32 downto 2);
            -- _WU (known not to be _LU from just above)
            if r.rs2(0) = '1' then
              v.res(31)          := r.op2.mant(33);
            end if;
            roundchk             := v.res(31);
            v.res(31 downto 0)   := v.res(31 downto 0) + roundadd;
            -- When modified due to rounding, ensure that we do not
            -- get any overflow.
            if r.rs2(0) = '0' then   -- _W
              if roundadd = 1 and roundchk = '0' and v.res(31) = '1' then
                v.res(31 downto 0) := x"7fffffff";
                v.exc(EXC_NV)      := '1';
                v.s                := nf_finish;
              end if;
            else                     -- _WU
              if roundadd = 1 and roundchk = '1' and v.res(31) = '0' then
                v.res(31 downto 0) := x"ffffffff";
                v.exc(EXC_NV)      := '1';
                v.s                := nf_finish;
              end if;
            end if;
            v.res(63 downto 32)  := (others => '0');
          else
            v.res(51 downto 0)   := r.op2.mant(53 downto 2);
            v.res(63 downto 52)  := r.op1.mant(53 downto 42);
            roundchk             := v.res(63);
            v.res                := v.res + roundadd;
            if roundadd = 1 and roundchk = '1' and v.res(31) = '0' then
              v.res              := (others => '1');
            end if;
          end if;
        end if;
        -- _W or _WU?
        if r.rs2(1) = '0' then
          v.res(63 downto 32)   := (others => v.res(31));
        end if;
        -- _WU or _LU and negative actual result?
        if r.rs2(0) = '1' and r.op2.neg and v.res(63) = '1' then
          v.res               := (others => '0');
          v.exc(EXC_NV)       := '1';
          v.s                 := nf_finish;
        elsif v.exc(EXC_NV) = '0' and r.op2.mant(1 downto 0) /= "00" then
          v.exc(EXC_NX)       := '1';
          v.s                 := nf_finish;
        end if;
        v.fpu_holdn           := '1';

      when nf_sgn2 =>
        if r.rddp = '0' then
          sign := r.s2(31);
          -- Cannot use is_nan here since only bad NaN-boxing is relevant.
          if not all_1(r.s1(63 downto 32)) then
            v.res := defnan;
          end if;
          if not all_1(r.s2(63 downto 32)) then --r.op2.w = x"0000000080000000" then
            sign := '0';
          end if;
          case r.rmb is
            when R_FSGNJ  => v.res(31) := sign; -- and not to_bit(all_0(r.op2.w(30 downto 0)));
            when R_FSGNJN => v.res(31) := not sign;  -- R_FSGNJX below
            when others   => v.res(31) := v.res(31) xor sign;
          end case;
        else
          case r.rmb is
            when R_FSGNJ  => v.res(63) := r.s2(63);
            when R_FSGNJN => v.res(63) := not r.s2(63);  -- R_FSGNJX below
            when others   => v.res(63) := r.res(63) xor r.s2(63);
          end case;
        end if;
        v.s := nf_opdone;

      when nf_addsub2 =>
        -- Special cases for zero/NaN/inf
        if is_nan(r.op1) or is_nan(r.op2) then
          v.s           := nf_opdone;
          v.exc(EXC_NV) := to_bit(is_signan(r.op2) or is_signan(r.op1));
          v.res         := defnan;
        elsif is_inf(r.op1) and is_inf(r.op2) and
              (r.flop = R_FSUB xor r.op1.neg xor r.op2.neg) then
          -- inf - inf = NaN
          v.res         := defnan;
          v.s           := nf_opdone;
          v.exc(EXC_NV) := '1';
        elsif is_inf(r.op2) then
          v.s           := nf_repack;
          if r.flop = R_FSUB then
            v.op2.neg   := not r.op2.neg;
          end if;
        elsif is_inf(r.op1) then
          v.s           := nf_repack;
          v.op2         := r.op1;
        elsif r.comphe = '1' and r.comple = '1' and
              (r.flop = R_FSUB xor r.op1.neg xor r.op2.neg) then
          -- Sum to zero
          v.s           := nf_opdone;
          v.res         := (others => '0');
          if r.rm = R_MINUS_INF then
            v.res(63)   := '1';
          end if;
          -- Check real rddp, in case of muladd.
          if r.rddp_real = '0' then
            v.res(63 downto 32) := (others => '1');  -- NaN-boxing
            if r.rm = R_MINUS_INF then
              v.res(31) := '1';
            end if;
          end if;
        elsif is_zero(r.op2) then
          v.s           := nf_repack;
          v.op2         := r.op1;
        elsif is_zero(r.op1) then
          v.s           := nf_repack;
          if r.flop = R_FSUB then
            v.op2.neg  := not r.op2.neg;
          end if;
        else
          v.addneg      := '0';
          if r.flop = R_FSUB xor r.op1.neg xor r.op2.neg then
            v.addneg    := '1';
          end if;
          -- Make sure the bigger argument in terms of magnitude is in op2,
          -- swap if that is not the case.
          -- If we swap and subtract then we need to flip the signs.
          -- We also negate the signs for subtraction because the FPU
          --   calculates op2-op1 instead of op1-op2 as expected.
          if r.comphl = '1' or (r.comphe = '1' and r.compll = '1') then
            v.expadj    := r.op1.exp - r.op2.exp;
            -- Swap needed
            v.op1       := r.op2;
            v.op2       := r.op1;
            -- Flip result sign if doing subtract
            if v.addneg = '1' then
              v.op2.neg := not r.op1.neg;
            end if;
          else
            -- No swap needed abs(op1) > abs(op2)
            v.expadj    := r.op2.exp - r.op1.exp;
            -- Result is negative if first operand is.
            v.op2.neg   := r.op1.neg;
          end if;
          -- op1 will be shifted by 0 or 1 (see below)
          v.opaction    := OPACT_SHFTA;
          if r.rddp = '0' then
            v.opaction  := OPACT_SHFTAS;
          end if;
          -- If it will use the subtract operation then we shift up both args by 1.
          --   This is to ensure there are enough guard digits.
          if v.addneg = '1' then
            v.expadj    := v.expadj + 1;
          end if;
          v.s           := nf_addsub25;
          v.adjustsel   := 2;
        end if;

        when nf_addsub25 =>
        v.op2        := adjusted;
        -- op2 will be shifted by 0 or 1 (see below)
        v.expadj     := (others => '0');
        v.opaction   := OPACT_SHFTA;
        if r.rddp = '0' then
          v.opaction := OPACT_SHFTAS;
        end if;
        -- If it will use the subtract operation then we shift up both args by 1.
        --   This is to ensure there are enough guard digits.
        if r.addneg = '1' then
          v.expadj   := v.expadj + 1;
        end if;
        v.s          := nf_addsub3;
        v.adjustsel  := 1;

      when nf_addsub3 =>
        v.op1   := adjusted;
        -- Shift down the mantissa of the smaller arg in r.op1.
        --   Handled by op1action.
      if do_addsel /= 0 then
        -- Decide whether to use "real" add or sub
        -- Sign of rs1 is ignored after this.
        -- Skip ahead if single precision.
        v.carry := '0';
        v.addsel     := 1;
        v.s          := nf_addsub4;
        if r.rddp = '0' then
          v.s      := nf_addsub5;
          if r.addneg = '1' then
            v.addsel := 3;
          else
            v.addsel := 2;
          end if;
        end if;
      else
        v.s          := nf_addsub4;
        if r.rddp = '0' then
          v.s      := nf_addsub5;
        end if;
      end if;

      when nf_addsub4 =>
        if do_addsel = 0 then
          addy := unsigned('0' & r.op2.mant(27 downto 0));
          addx := unsigned('0' & r.op1.mant(27 downto 0));
          if r.addneg = '1' then
            vtmpadd := addx - addy;
          else
            vtmpadd := addx + addy;
          end if;
        end if;
        -- Add/sub lower bits
        v.op2.mant(27 downto 0) := std_logic_vector(vtmpadd(27 downto 0));
        v.carry                 := vtmpadd(28);
        v.s                     := nf_addsub5;
      if do_addsel /= 0 then
        if r.addneg = '1' then
          v.addsel              := 3;
        else
          v.addsel              := 2;
        end if;
      end if;

      when nf_addsub5 =>
        if do_addsel = 0 then
          if r.addneg = '1' then
            addy := unsigned('0' & r.op2.mant(55 downto 28));
            addx := unsigned('0' & r.op1.mant(55 downto 28));
          else
            addy := unsigned'("00") & unsigned(r.op2.mant(54 downto 28));
            addx := unsigned'("00") & unsigned(r.op1.mant(54 downto 28));
          end if;
          if r.addneg = '1' then
            vtmpadd := addx - addy;
            if r.carry = '1' then
              vtmpadd := vtmpadd - 1;
            end if;
          else
            vtmpadd := addx + addy;
            if r.carry = '1' then
              vtmpadd := vtmpadd + 1;
            end if;
          end if;
        end if;
        -- Add/sub higher bits
        v.op2.mant(55 downto 28) := std_logic_vector(vtmpadd(27 downto 0));
        v.s                      := nf_addsub6;
        if r.rddp = '1' then
          v.nalimdp              := '1';
        else
          v.nalimsp              := '1';
        end if;

      when nf_addsub6 =>
        -- Scan for implicit 1 (r.op2normadj) handled in shared resource.
        v.opaction  := OPACT_SHFTN;
        v.adjustsel := 2;
        v.s         := nf_addsub7;

      when nf_addsub7 =>
        v.op2       := adjusted;
        -- Adjust so that the implicit 1 is at the expected position.
        v.s         := nf_round;
        -- Restore actual float type, in case it
        -- was changed to do float muladd.
        v.rddp      := v.rddp_real;

      when nf_mul2 =>
        if is_signan(r.op2) or is_signan(r.op1) or mul_illegal(r.op1, r.op2) then
          v.s           := nf_opdone;
          v.exc(EXC_NV) := '1';
          v.res         := defnan;
        elsif is_nan(r.op1) or is_nan(r.op2) then
          v.s           := nf_opdone;
          v.res         := defnan;
        elsif not is_normal(r.op2) then
          -- 0 or inf in rs2
          v.s           := nf_repack;
          v.op2.neg     := r.op1.neg xor r.op2.neg;
        elsif not is_normal(r.op1) then
          -- 0 or inf in rs1
          v.s           := nf_repack;
          v.op2         := r.op1;
          v.op2.neg     := r.op1.neg xor r.op2.neg;
        else
          -- On next cycle, re-normalize number in case of denormal input.
          v.opaction    := OPACT_SHFTN;
          v.adjustsel   := 1;
          v.s           := nf_mul25;
          v.op2.neg     := r.op1.neg xor r.op2.neg;
        end if;

      when nf_mul25 =>
        v.op1       := adjusted;
        v.opaction  := OPACT_SHFTN;
        v.adjustsel := 2;
        v.s         := nf_mul3;

      when nf_mul3 =>
        v.op2         := adjusted;
        -- Normalization done in this stage
        v.s           := nf_mul4;
        v.shftpl      := '0';
        -- If sources are single precision we can skip ahead in the sequence.
        v.mulctrlim   := "00";
        if r.rddp = '0' then
          v.mulctrlim := "10";
        end if;
        v.mulctr1     := v.mulctrlim;
        v.mulctr2     := v.mulctrlim;

      -- dp lim 0
      --   01 02 103 210 3213 23 3
      --   00 10 120 123 1232 33 4
      -- sp lim 2
      --   213 23 3
      --   232 33 4
      when nf_mul4 =>
        -- Run multiplier pipeline
        v.mulctr1     := r.mulctr1 - 1;
        v.mulctr2     := r.mulctr2 + 1;
        v.mulen       := '1';
        v.shftpl2     := '0';
        if r.mulctr1 = r.mulctrlim or r.mulctr2 = "11" then
          if r.mulctr2 = "11" then
            v.mulctr1 := "11";
            v.mulctr2 := r.mulctr1 + 1;
          else
            v.mulctr1 := r.mulctr2 + 1;
            v.mulctr2 := r.mulctrlim;
          end if;
          v.shftpl2   := '1';
          if r.mulctr1 = "11" then
            v.s       := nf_mul5;
            v.shftpl2 := '0';
          end if;
        end if;

      when nf_mul5 =>
        -- Finish multiplier pipeline
        v.mulen                    := '0';
        v.shftpl2                  := '0';
        if r.accen = '0' then
          -- Copy result into op2
          -- Leading one could be in either bit 27 or 26 of accumulator.
          assert r.acc(29 downto 28) = "00";
          v.op2.mant(55 downto 28) := std_logic_vector(r.acc(27 downto 0));
          v.op2.mant(27 downto 0)  := std_logic_vector(r.acclo);
          -- Adjust exponent
          v.op2.exp                := r.op2.exp + r.op1.exp;
          v.s                      := nf_mul6;
          v.unpacksel              := 3;
          -- Do not limit exponent yet if doing muladd.
          if r.flop /= S_FMADD then
            if r.rddp = '1' then
              v.nalimdp              := '1';
            else
              v.nalimsp              := '1';
            end if;
          end if;
        end if;

      when nf_mul6 =>
        -- Computing amount of normalization
        -- Do shift in next state
        v.opaction   := OPACT_SHFTN;
        v.adjustsel  := 2;
        if no_muladd = 0 then
          -- Prepare op1 (op3) in case there was a muladd
          v.op1        := unpacked;
          v.op1.neg    := r.op3neg;
          v.normadjsel := 1;
        end if;
        v.s          := nf_mul7;
        -- Take care of low bits on down-shift
        if not all_0(v.opnormadj) then
          v.accbot := r.acclo0 & r.accbot(r.accbot'high downto 1);
          v.acclo0 := unsigned(r.op2.mant(1 downto 1));
        end if;

      when nf_mul7 =>
        v.op2       := adjusted;
        -- Re-normalizing
        -- Do rounding in next state
        v.s         := nf_round;
        if no_muladd = 0 and r.flop = S_FMADD then
          v.s         := nf_muladd_mid;
          v.adjustsel := 1;
        end if;

      when nf_div2 =>
        -- Unpacking
        if is_signan(r.op2) or is_signan(r.op1) or
           (is_inf(r.op1)  and is_inf(r.op2))   or
           (is_zero(r.op1) and is_zero(r.op2)) then
          -- Signaling NaN in rs1/rs2 or inf/inf, 0/0
          v.s            := nf_opdone;
          v.exc(EXC_NV)  := '1';
          v.res          := defnan;
        elsif is_nan(r.op1) or is_nan(r.op2) then
          v.s            := nf_opdone;
          v.res          := defnan;
        elsif not is_normal(r.op2) then
          -- 0 or inf in rs2
          v.s            := nf_repack;
          v.op2.neg      := r.op1.neg xor r.op2.neg;
          v.op2.class(1) := not r.op2.class(1);  -- 0 <-> inf
        elsif not is_normal(r.op1) then
          -- 0 or inf in rs1
          v.s            := nf_repack;
          v.op2          := r.op1;
          v.op2.neg      := r.op1.neg xor r.op2.neg;
        else
          -- On next cycle, re-normalize number in case of denormal input.
          v.opaction     := OPACT_SHFTN;
          v.op2.neg      := r.op1.neg xor r.op2.neg;
          v.s            := nf_div25;
          v.adjustsel    := 1;
        end if;
        if is_zero(r.op2) and is_normal(r.op1) then
          v.exc(EXC_DZ)  :='1';
        end if;

      when nf_div25 =>
        v.op1       := adjusted;
        v.opaction  := OPACT_SHFTN;
        v.adjustsel := 2;
        -- Re-normalizing
        v.s         := nf_div3;

      when nf_div3 =>
        v.op2      := adjusted;
        -- Re-normalizing
        v.s        := nf_div4;
        v.divfirst := '1';
        v.divremz  := '0';

      when nf_div4 =>
        divrem      := true;
        -- Run division using basic radix-2 algorithm.
        -- Subtract divisor from remainder.
        vtmpadd     := unsigned('0' & r.op1.mant(27 downto 0)) -
                       unsigned('0' & r.op2.mant(27 downto 0));
        divrem2     := vtmpadd;
        v.divcmp2   := '0';
        if all_0(vtmpadd) then
          v.divcmp2 := '1';
        end if;
        vtmpadd     := unsigned('0' & r.op1.mant(55 downto 28)) -
                       unsigned('0' & r.op2.mant(55 downto 28));
        divrem1     := vtmpadd;
        v.divcmp1   := '0';
        if all_0(vtmpadd) then
          v.divcmp1 := '1';
        end if;
        v.s         := nf_div5;
        if r.divfirst = '1' then
          v.op2.exp := r.op1.exp - r.op2.exp;
        end if;

      when nf_div5 =>
        divrem                       := true;
        -- Get one bit of quotient, update remainder
        v.res(53 downto 1)           := r.res(52 downto 0);
        v.res(0)                     := '0';
        if divrem1(28) = '0' and (r.divcmp1 = '0' or divrem2(28) = '0') then
          assert divrem1(28 downto 27) = "00" or
                 (divrem1(27) = '1' and divrem1(26 downto 0) = (26 downto 0 => '0'));
          v.res(0)                   := '1';
          if divrem2(28) = '1' then
            v.op1.mant(55 downto 29) := std_logic_vector(divrem1(26 downto 0) - 1);
          else
            v.op1.mant(55 downto 29) := std_logic_vector(divrem1(26 downto 0));
          end if;
          v.op1.mant(28 downto 1)    := std_logic_vector(divrem2(27 downto 0));
          v.op1.mant(0)              := '0';
          vtmpadd                    := unsigned('0' & divrem1(26 downto 0) & '0') -
                                        unsigned('0' & r.op2.mant(55 downto 28));
        else
          assert r.op1.mant(55) = '0';
          v.op1.mant                 := r.op1.mant(54 downto 0) & '0';
          if r.divfirst = '1' then
            v.op2.exp                := r.op2.exp - 1;
          end if;
          vtmpadd                    := unsigned(r.op1.mant(55 downto 28) & '0') -
                                        unsigned('0' & r.op2.mant(55 downto 28));
        end if;

        v.s         := nf_div4;
        v.divfirst  := '0';
        if r.divcmp1 = '1' and r.divcmp2 = '1' then
          v.divremz := '1';
        end if;

        -- In single precision case, we calculate the new remainder instantly
        -- above and stay in the nf_div5 case.
        divrem1     := vtmpadd;
        v.divcmp1   := '0';
        if all_0(vtmpadd) then
          v.divcmp1 := '1';
        end if;
        if r.rddp = '0' then
          v.s       := nf_div5;
        end if;

        if r.res(52) = '1' or (r.rddp = '0' and r.res(23) = '1') then
          v.s                        := nf_round;
          if r.rddp = '0' then
            v.op2.mant(55 downto 31) := "01" & r.res(22 downto 0);
            v.op2.mant(30)           := v.res(0);
            v.op2.mant(29 downto 1)  := (others => '0');
            v.expadj                 := r.op2.exp + 126;
            if r.op2.exp < -126 then
              v.s                    := nf_div6;
              v.opaction             := OPACT_SHFTA;
              v.adjustsel            := 2;
            end if;
          else
            v.op2.mant(55 downto 2)  := "01" & r.res(51 downto 0);
            v.op2.mant(1)            := v.res(0);
            v.expadj                 := r.op2.exp + 1022;
            if r.op2.exp < -1022 then
              v.s                    := nf_div6;
              v.opaction             := OPACT_SHFTA;
              v.adjustsel            := 2;
            end if;
          end if;
          if v.divremz = '1' then
            v.op2.mant(0)            := '0';
          else
            v.op2.mant(0)            := '1';
          end if;
        end if;

      when nf_div6 =>
        v.op2 := adjusted;
        -- De-normalizing result
        v.s   := nf_round;

      when nf_sqrt2 =>
        -- Calculating adjustment for normalization
        v.opaction          := OPACT_SHFTN;
        v.adjustsel         := 2;
        v.s                 := nf_sqrt3;
        -- Start multiplier pipeline to get first 2 bits
        v.muli1             := (others => '0');
        v.muli1(1 downto 0) := "11";
        v.muli2             := v.muli1;
        -- Special cases
        if is_signan(r.op2) or
           (r.op2.neg and (is_normal(r.op2) or is_inf(r.op2))) then
          v.res             := defnan;
          v.exc(EXC_NV)     := '1';
          v.s               := nf_opdone;
        elsif not is_normal(r.op2) then
          v.s               := nf_repack;
        end if;

      when nf_sqrt3 =>
        v.op2                    := adjusted;
        -- Shifting mantissa
        v.s                      := nf_sqrt4;
        -- Continue multiplier pipeline
        v.muli1                  := r.muli1;
        v.muli1(1 downto 0)      := "10";
        v.muli2                  := v.muli1;
        -- Init op1.mant here just to avoid triggering the check in nf_sqrt7 too early.
        v.op1.mant(55 downto 42) := std_logic_vector(r.muli1(13 downto 0));

      when nf_sqrt4 =>
        -- Move top 32 bits of mantissa over to accumulator
        v.res(31 downto 0)    := r.op2.mant(55 downto 24);
        -- Adjust exponent
        v.op2.exp             := r.op2.exp(12) & r.op2.exp(12 downto 1);
        -- Check for bits "11"
        if r.mulo(3 downto 0) <= unsigned(r.op2.mant(55 downto 52)) then
          v.muli1             := r.muli1(13 downto 2) & "1111";
          v.res               := v.res(59 downto 0) & "0011";
          v.s                 := nf_sqrt7;
        else
          v.muli1             := r.muli1;
          v.muli1(1 downto 0) := "01";
          v.s                 := nf_sqrt5;
        end if;
        v.muli2               := v.muli1;

      when nf_sqrt5 =>
        -- Check for bits "10"
        v.muli1   := r.muli1;
        if r.mulo <= unsigned(r.res(59 downto 28)) then
          v.muli1 := r.muli1(13 downto 2) & "1011";
          v.res   := r.res(59 downto 0) & "0010";
          v.s     := nf_sqrt7;
        else
          v.s     := nf_sqrt6;
        end if;
        v.muli2   := v.muli1;

      when nf_sqrt6 =>
        -- Check for bits "01" or "00"
        v.muli1      := r.muli1(13 downto 2) & "0011";
        v.res        := r.res(59 downto 0) & "0000";
        if r.mulo <= unsigned(r.res(59 downto 28)) then
          v.muli1(2) := '1';
          v.res(0)   := '1';
        end if;
        v.muli2      := v.muli1;
        v.s          := nf_sqrt7;

      when nf_sqrt7 =>
        -- Continue multiplier pipeline
        v.muli1                    := r.muli1;
        v.muli1(1 downto 0)        := "10";
        v.muli2                    := v.muli1;
        v.s                        := nf_sqrt8;
        if r.op1.mant(55 downto 54) /= "00" then
          v.op1.mant(40 downto 39) := std_logic_vector(r.muli1(3 downto 2));
          v.s                      := nf_sqrt9;
          v.op1.mant(38)           := '1';
          v.sqrtctr                := to_unsigned(38, 6);
          v.res(38)                := '1';
          v.res(37 downto 0)       := (others => '0');
          v.mulctrlim              := "10";
          v.mulctr2                := v.mulctrlim;
          v.mulctr1                := v.mulctrlim;
        end if;
        v.mulsel2                  := '1';

      when nf_sqrt8 =>
        v.op1.mant(54 downto 39) := std_logic_vector(r.muli1(15 downto 0));
        v.op1.mant(38 downto 0)  := (others => '0');
        -- Continue multiplier pipeline
        v.muli1                  := r.muli1;
        v.muli1(1 downto 0)      := "01";
        v.muli2                  := r.muli1;
        -- Check for bits "11"
        if r.mulo <= unsigned(r.res(59 downto 28)) then
          v.muli1                := r.muli1(13 downto 2) & "1111";
          v.res                  := r.res(59 downto 0) & "0011";
          v.s                    := nf_sqrt7;
        else
          v.s                    := nf_sqrt5;
        end if;
        v.muli2                  := v.muli1;

      -- Since we are squaring numbers,
      -- "reverse" multiplications are unnecessary.
      -- Coming from nf_sqrt7    lim 2
      --   23 3 3
      --   22 3 3
      -- Coming from nf_sqrt11
      --   if r.sqrtctr > 27     lim 2
      --     23 3 3
      --     22 3 3
      --   elsif r.sqrtctr > 13  lim 1
      --     12 3 23 3 3
      --     11 1 22 3 3
      --   else                  lim 0
      --    01 2 13 23 23 3 3
      --    00 0 10 11 22 3 3
      when nf_sqrt9 =>
        -- Slower algorithm to find lower bits by testing one by one
        v.mulen       := '1';
        -- Run multiplier pipeline
        v.mulctr1     := r.mulctr1 - 1;
        v.mulctr2     := r.mulctr2 + 1;
        v.mulen       := '1';
        v.shftpl2     := '0';
        if r.mulctr1 = "00" and r.mulctr2 = "00" then
          v.mulctr1   := "01";
          v.mulctr2   := "00";
          v.shftpl2   := '1';
        elsif r.mulctr1 = "01" and r.mulctr2 = "00" then
          v.mulctr1   := "10";
          v.mulctr2   := "00";
          v.shftpl2   := '1';
        elsif r.mulctr1 = "01" and r.mulctr2 = "01" then
          if r.mulctrlim = "00" then
            v.mulctr1 := "11";
            v.mulctr2 := "00";
          else
            v.mulctr1 := "10";
            v.mulctr2 := "01";
          end if;
          v.shftpl2   := '1';
        elsif r.mulctr1 = "10" and r.mulctr2 = "01" then
          v.mulctr1   := "11";
          v.mulctr2   := "01";
          v.shftpl2   := '1';
        elsif r.mulctr1 = "10" and r.mulctr2 = "10" then
          v.mulctr1   := "11";
          v.mulctr2   := "10";
          v.shftpl2   := '1';
        elsif r.mulctr1 = "11" and r.mulctr2 = "10" then
          v.mulctr1   := "11";
          v.mulctr2   := "11";
          v.shftpl2   := '1';
        elsif r.mulctr1 = "11" and r.mulctr2 = "11" then
          v.mulctr1   := "11";
          v.mulctr2   := "11";
          v.s         := nf_sqrt10;
        end if;
        v.mulsel2     := '1';

      when nf_sqrt10 =>
        divrem        := true;
        -- Finish multiplier pipeline (mirror of nf_mul5)
        v.mulen       := '0';
        v.shftpl2     := '0';
        if r.accen = '0' then
          assert r.acc(29 downto 28) = "00";
          -- Subtract input from mul result
          vtmpadd     := unsigned('0' & r.acclo) -
                         unsigned('0' & r.op2.mant(27 downto 0));
          divrem2     := vtmpadd;
          -- Exact match for low bits?
          v.divcmp2   := '0';
          if all_0(vtmpadd) then
            v.divcmp2 := '1';
          end if;
          vtmpadd     := unsigned('0' & r.acc(27 downto 0)) -
                         unsigned('0' & r.op2.mant(55 downto 28));
          divrem1     := vtmpadd;
          -- Exact match for high bits?
          v.divcmp1   := '0';
          if all_0(vtmpadd) then
            v.divcmp1 := '1';
          end if;
          v.s         := nf_sqrt11;
        end if;
        v.mulsel2     := '1';

      when nf_sqrt11 =>
        v.acc              := (others => '0');
        v.acclo            := (others => '0');
        v.acclo0           := (others => '0');
        v.accbot           := (others => '0');
        v.res(38 downto 0) := '0' & r.res(38 downto 1);
        if r.divcmp1 = '1' and r.divcmp2 = '1' then
          -- Exact match!
          v.op2.mant       := r.op1.mant;
          v.s              := nf_round;
        elsif r.res(0) = '1' or (r.rddp = '0' and r.res(29) = '1') then
          -- Remainder below mantissa > 0
          v.op2.mant       := r.op1.mant;
          v.op2.mant(0)    := '1';
          v.s              := nf_round;
        else
          if divrem1(28) = '0' and (r.divcmp1 = '0' or divrem2(28) = '0') then
            -- Mul result > input - tested bit should be 0
            v.op1.mant(38 downto 0) := r.op1.mant(38 downto 0) and not r.res(38 downto 0);
          end if;
          v.op1.mant(38 downto 0)   := v.op1.mant(38 downto 0) or v.res(38 downto 0);
          v.op1.mant(0)             := '0';
          if r.rddp = '0' then
            v.op1.mant(29)          := '0';
          end if;
          v.sqrtctr                 := r.sqrtctr - 1;
          v.s                       := nf_sqrt9;
          if r.sqrtctr > 27 then
            v.mulctrlim := "10";
          elsif r.sqrtctr > 13 then
            v.mulctrlim := "01";
          else
            v.mulctrlim := "00";
          end if;
          v.mulctr1     := v.mulctrlim;
          v.mulctr2     := v.mulctrlim;
          v.mulsel2     := '1';
        end if;

      when nf_round =>
        v.op2    := rounded;
        v.exc    := roundexc;
        v.s      := nf_repack;
        -- Too small numbers can be the result of muladd sp as dp.
        if no_muladd = 0 and r.rddp = '0' and is_normal(r.op2) and r.op2.exp < -126 then
          -- Restore unrounded value and flags
          v.op2       := r.op2;
          v.exc       := r.exc;
          -- Adjust to denormal
          v.expadj    := r.op2.exp + 126;
          v.adjustsel := 2;
          v.opaction  := OPACT_SHFTA;
          v.s         := nf_round2;
        end if;

      when nf_repack =>
        -- Repack
        if r.exc(EXC_OF) = '1' and
           (r.rm = R_ZERO or
            (r.rm = R_PLUS_INF  and r.op2.neg) or
            (r.rm = R_MINUS_INF and not r.op2.neg)) then
          -- Fixup for overflow in certain cases required to generate maximum
          -- representable value.
          v.res            := (others => '1');
          if r.rddp = '1' then
            v.res(63)      := to_bit(r.op2.neg);
            v.res(63 - 11) := '0';
          else
            v.res(31)      := to_bit(r.op2.neg);
            v.res(31 - 8)  := '0';
          end if;
        else
          v.res            := pack(r.op2, not r.rddp);
          if r.exc(EXC_UF) = '1' and is_zero(r.op2) and
            ((r.rm = R_PLUS_INF  and not r.op2.neg) or
             (r.rm = R_MINUS_INF and r.op2.neg)) then
            v.res(0)       := '1';
          end if;
          -- Denormalized results always trigger underflow if set in tem.
          -- We do it here rather than in the round stage to handle cases where
          -- rounding is bypassed such as (denorm + zero).
          -- Some operations do not produce UF exceptions on denormals.
          if r.flop = R_FSGN then
            v.exc(EXC_UF)  := '0';
          end if;
        end if;
        v.s                := nf_opdone;

      when nf_min2 =>
        if is_signan(r.op1) or is_signan(r.op2) then
          v.exc(EXC_NV)  := '1';
        end if;
        -- v.res already contains the incoming rs1 value.
        if is_nan(r.op1) and is_nan(r.op2) then
          v.res          := defnan;
        elsif is_nan(r.op1) then
          v.res          := r.s2;
        elsif not is_nan(r.op2) then
          -- Assume R_MIN
          if (is_zero(r.op1) and is_zero(r.op2)) or is_inf(r.op1) then
            use_fs2      := not r.op1.neg;
          elsif is_inf(r.op2) then
            use_fs2      := r.op2.neg;
          else
            use_fs2      := fcc /= "01";
          end if;
          -- Conditions are opposite for R_MAX
          if use_fs2 xor (r.rmb = R_MAX) then
            v.res        := r.s2;
          end if;
        end if;
        v.s              := nf_opdone;

      when nf_store2 =>
        v.fpu_holdn := '1';
        v.s         := nf_end;
        if commit = '1' or r.committed = '1' then
          v.s       := nf_idle;
        end if;

      when nf_cmp2 =>
        -- R_FEQ is a quiet comparison (not NV for non-signalling NaN).
        if (is_signan(r.op1) or is_signan(r.op2) or
            (r.rmb /= R_FEQ and (is_nan(r.op1) or is_nan(r.op2)))) then
          v.exc(EXC_NV) := '1';
        end if;
        v.res           := (others => '0');
        -- Result is always 0 when one input is NaN.
        if not (is_nan(r.op1) or is_nan(r.op2)) then
          -- Check all comparison operations.
          if (r.rmb = R_FEQ and fcc  = "00") or
             (r.rmb = R_FLT and fcc  = "01") or
             (r.rmb = R_FLE and fcc /= "10") then
            v.res(0)    := '1';
          end if;
        end if;
        v.s             := nf_finish;

      when nf_mvxw2 =>
        -- This is always the rm field in the instruction here.
        if r.rmb = R_CLASS then
          v.res          := (others => '0');
          --  Exponent all 1 - infinity (frac 0) or NaN
          if is_nan(r.op1) then
            v.res(9)     := to_bit(not is_signan(r.op1));      -- Quiet NaN
            v.res(8)     := to_bit(is_signan(r.op1));
          else
            if is_inf(r.op1) then
              n          := 0;
            elsif is_zero(r.op1) then
              n          := 3;
            elsif r.op1.mant(54) = '0' then
              n          := 2;   -- Denormal
            else
              n          := 1;   -- Normal
            end if;
            v.res(n)     := to_bit(r.op1.neg);
            v.res(7 - n) := not to_bit(r.op1.neg);
          end if;
        elsif r.rmb = "000" then   -- fmv.x.w/d
          -- v.res already contains the incoming rs1 value.
          if r.rddp = '0' then
            -- Extend sign bit when moving 32 bit float.
            v.res(63 downto 32) := (others => r.res(31));
          end if;
        end if;
        v.s              := nf_finish;

      when nf_finish =>
        v.fpu_holdn := '1';
        v.flags_wen := '1';
        v.s         := nf_end;
        if commit = '1' or r.committed = '1' then
          v.s       := nf_idle;
        end if;

      -- Done, but return to nf_idle before instruction actually
      -- commits runs the risk of mixup with the next instruction.
      when nf_end =>
        if commit = '1' or r.committed = '1' then
          v.s := nf_idle;
        end if;

      -- Finish and write back result when committed
      when nf_opdone =>
        if commit = '1' or r.committed = '1' then
          v.wen       := '1';
          v.flags_wen := '1';
          v.s         := nf_rdwrite;
        end if;

      when nf_rdwrite =>
        v.s         := nf_rdwrite2;

      when nf_rdwrite2 =>
        v.fpu_holdn := '1';
        v.s         := nf_idle;

      when others =>

  if no_muladd = 0 then
    case r.s is
      when nf_muladd2 =>
        -- "unpacked" here is op3
        v.op3neg         := unpacked.neg;
        inf_1x2          := inf_mul(r.op1, r.op2);
        if is_signan(r.op1) or is_signan(r.op2) or is_signan(unpacked) then
          v.s            := nf_opdone;
          v.exc(EXC_NV)  := '1';
          v.res          := defnan;
        elsif is_nan(r.op1) or is_nan(r.op2) then
          v.res          := defnan;
          v.s            := nf_opdone;
        elsif mul_illegal(r.op1, r.op2) then
          v.exc(EXC_NV)  := '1';
          v.res          := defnan;
          v.s            := nf_opdone;
        elsif is_nan(unpacked) then
          v.res          := defnan;
          v.s            := nf_opdone;
        elsif ((r.flop = S_FMADD or r.flop = S_FNMADD) and add_illegal(inf_1x2, unpacked))          or
              ((r.flop = S_FMSUB or r.flop = S_FNMSUB) and add_illegal(inf_1x2, inf_neg(unpacked))) then
          v.exc(EXC_NV)  := '1';
          v.res          := defnan;
          v.s            := nf_opdone;
        elsif is_inf(r.op1) or is_inf(r.op2) or is_inf(unpacked) then
          v.op2.class    := C_INF;
          v.op2.neg      := false;
          if is_inf(r.op1) or is_inf(r.op2) then
            v.op2.neg    := inf_1x2.neg;
          elsif ((r.flop = S_FMADD or r.flop = S_FNMADD) and unpacked.neg)     or
                ((r.flop = S_FMSUB or r.flop = S_FNMSUB) and not unpacked.neg) then
            v.op2.neg    := true;
          end if;
          -- These are the opposites of S_FMADD/SUB
          if r.flop = S_FNMADD or r.flop = S_FNMSUB then
            v.op2.neg    := not v.op2.neg;
          end if;
          v.s            := nf_repack;
        elsif is_zero(r.op1) or is_zero(r.op2) then   -- No multiply?
          v.op2          := unpacked;
          if is_zero(unpacked) then
            v.op2.neg    := r.op1.neg xor r.op2.neg;
            if r.flop = S_FNMADD or r.flop = S_FNMSUB then
              v.op2.neg  := not v.op2.neg;
            end if;
            if ((r.flop = S_FMADD  or r.flop = S_FNMSUB) and v.op2.neg /= unpacked.neg) or
               ((r.flop = S_FNMADD or r.flop = S_FMSUB)  and v.op2.neg  = unpacked.neg) then
              v.op2.neg  := r.rm = R_MINUS_INF;
            end if;
          else
            if r.flop = S_FMSUB or r.flop = S_FNMADD then
              v.op2.neg  := not v.op2.neg;
            end if;
          end if;
          v.s            := nf_repack;
        else
          -- On next cycle, re-normalize number in case of denormal input.
          v.adjustsel    := 1;
          v.opaction     := OPACT_SHFTN;
          -- Handle all as fmadd
          v.flop         := S_FMADD;
          -- All negations handled here
          v.op2.neg      := r.op1.neg xor r.op2.neg;
          if r.flop = S_FNMADD or r.flop = S_FNMSUB then
            v.op2.neg    := not v.op2.neg;
          end if;
          if r.flop = S_FNMADD or r.flop = S_FMSUB then
            v.op3neg     := not unpacked.neg;
          end if;
          -- If no add, handle as mul.
          if is_zero(unpacked) then
            v.flop       := R_FMUL;
          -- Handle float muladd as if it was double, to deal with precision.
          elsif r.rddp = '0' then
            v.rddp       := '1';
          end if;
          v.s            := nf_mul25;
        end if;

      when nf_muladd_mid =>
        -- No rounding yet on muladd, so no rounding errors.
        v.exc := (others => '0');
        -- In case of muladd sp as dp, get rid of denormalisation.
        v.op1    := adjusted;
        op2low0  := all_0(r.acclo(1) & r.acclo0 & r.accbot);
        -- We need these for addsub2, which may swap op1 and op2.
        v.comphl := '0';    -- Assume abs(op1) > abs(op2)
        v.comphe := '0';
        v.compll := '0';
        v.comple := '0';
        if v.op1.exp < r.op2.exp then
          v.comphl := '1';
        end if;
        if v.op1.mant < r.op2.mant then
          v.compll := '1';
        end if;
        -- Also need to check for equivalence since addsub2 expects it.
        if r.op2.exp = v.op1.exp then
          v.comphe := '1';
        end if;
        if r.op2.mant = v.op1.mant then
          v.comple := '1';
          -- For double precision, also check the lower result bits of multiply.
          if r.rddp_real = '1' and not op2low0 then
            v.comple := '0';
            v.compll := '1';
          end if;
        end if;
        v.flop := R_FADD;
        v.s    := nf_addsub2;
        -- When double precision, special handling is needed if
        -- op2 (multiplication result) is larger and has low bits
        -- op1 same magnitude as op2 and op2 has low bits
        if r.rddp_real = '1' and not op2low0 then
          if v.comphl = '1' or (v.comphe = '1' and v.compll = '1') then
            v.s  := nf_muladd_xadd;
          end if;
          if v.comphe = '1' then --and v.op1.neg /= r.op2.neg then
            v.s  := nf_muladd_xadd;
          end if;
        end if;
        if v.s = nf_addsub2 then
        else
          -- Set actual low bit, since the rest is in r.accbot.
          v.op2.mant(0) := std_logic(r.acclo0(0));
        end if;

      when nf_round2 =>
        v.op2 := adjusted;
        v.s   := nf_round;

      -- Do addition part of double precision muladd (simplified from addsub2)
      when nf_muladd_xadd =>
        -- All special cases have been taken care of earlier.
        v.addneg      := '0';
        if r.op1.neg xor r.op2.neg then
          v.addneg    := '1';
        end if;
        -- Make sure the bigger argument in terms of magnitude is in op1,
        -- swap later if that is not the case.
        -- If we swap and subtract then we need to flip the signs.
        v.expadj      := r.op1.exp - r.op2.exp;
        v.swap      := '0';
        if r.comphl = '1' or (r.comphe = '1' and r.compll = '1') then
          -- Swap needed
          v.swap      := '1';
          -- Flip result sign if doing subtract
          if v.addneg = '1' then
            v.op2.neg := not r.op1.neg;
          end if;
        else
          -- No swap needed abs(op1) > abs(op2)
          -- Result is negative if first operand is.
          v.op2.neg   := r.op1.neg;
        end if;
        v.opaction    := OPACT_SHFTA;
        -- If it will use the subtract operation then we shift up both args by 1.
        --   This is to ensure there are enough guard digits.
        if v.addneg = '1' then
          v.expadj    := v.expadj + 1;
          v.op2.exp   := r.op2.exp - 1;
          v.op2.mant  := r.op2.mant(r.op2.mant'high - 1 downto 0) & std_logic(r.accbot(r.accbot'high));
          v.accbot    := r.accbot(r.accbot'high - 1 downto 0) & '0';
        end if;
        v.adjustsel   := 1;
        -- When abs(v.expadj) is less than the mantissa length,
        -- this will be a left shit for bits to use in the bottom half,
        -- with a later right (original v.expadj) shift for the top half.
        -- When abs(v.expadj) is larger than the mantissa length,
        -- this is a right shift for bits to use in the bottom half,
        -- and the top half will later be cleared.
        v.expadj := v.expadj + (r.op2.mant'length - 2);
        v.s      := nf_muladd_xadd27;
        if v.expadj > -(r.op2.mant'length - 2) then
          v.s    := nf_muladd_xadd25;
        end if;

      when nf_muladd_xadd25 =>
        v.s2         := (others => '0');
        v.s2(adjusted.mant'range) := adjusted.mant;
        -- The top bit will be in next to last in original.
        v.s2(adjusted.mant'high)  := '0';
        v.expadj     := r.expadj - (r.op2.mant'length - 2);
        v.opaction   := OPACT_SHFTA;
        v.s          := nf_muladd_xadd26;
        v.adjustsel  := 1;

      when nf_muladd_xadd26 =>
        v.op1 := adjusted;
        v.s   := nf_muladd_xaddsub3;

      when nf_muladd_xadd27 =>
        v.op1.mant   := (others => '0');
        v.s2         := (others => '0');
        v.s2(adjusted.mant'range) := adjusted.mant;
        v.s          := nf_muladd_xaddsub3;

      when nf_muladd_xaddsub3 =>
        if r.swap = '1' then
          -- Do not copy .neg since that is for the result!
          v.op2.exp  := r.op1.exp;
          v.op2.mant := r.op1.mant;
          v.accbot   := unsigned(r.s2(v.accbot'range));
          v.op1      := r.op2;
          v.s2(r.accbot'range) := std_logic_vector(r.accbot);
        end if;
        -- Magnitude of result is the large one
        v.op2.exp    := v.op1.exp;
        if r.addneg = '0' then
          xtmpaddx := unsigned('0' & v.s2(r.accbot'range)) + (unsigned'("0") & v.accbot);
        else
          xtmpaddx := unsigned('0' & v.s2(r.accbot'range)) - (unsigned'("0") & v.accbot);
        end if;
        v.carry    := xtmpaddx(xtmpaddx'high);
        v.s2                 := (others => '0');
        v.s2(xtmpaddx'range) := std_logic_vector(xtmpaddx);
        v.s2(xtmpaddx'high)  := '0';  -- Clear carry
      if do_addsel /= 0 then
        v.addsel   := 1;
      end if;
      v.s          := nf_muladd_xaddsub4;

      when nf_muladd_xaddsub4 =>
        if do_addsel = 0 then
          addy        := unsigned('0' & r.op2.mant(27 downto 0));
          addx        := unsigned('0' & r.op1.mant(27 downto 0));
          if r.addneg = '1' then
            vtmpadd   := addx - addy;
            if r.carry = '1' then
              vtmpadd := vtmpadd - 1;
            end if;
          else
            vtmpadd   := addx + addy;
            if r.carry = '1' then
              vtmpadd := vtmpadd + 1;
            end if;
          end if;
        end if;
        -- Add/sub of lower bits
        -- Bottom two bits moved down to s2.
        v.op2.mant(27 downto 0) := std_logic_vector(vtmpadd(27 downto 2)) & "00";
        v.s2(r.accbot'high + 2 downto r.accbot'high + 1) := std_logic_vector(vtmpadd(1 downto 0));
        v.carry                 := vtmpadd(28);
        v.s                     := nf_muladd_xaddsub5;
      if do_addsel /= 0 then
        if r.addneg = '1' then
          v.addsel              := 3;
        else
          v.addsel              := 2;
        end if;
      end if;

      when nf_muladd_xaddsub5 =>
        if do_addsel = 0 then
          if r.addneg = '1' then
            addy := unsigned('0' & r.op2.mant(55 downto 28));
            addx := unsigned('0' & r.op1.mant(55 downto 28));
          else
            addy := unsigned'("00") & unsigned(r.op2.mant(54 downto 28));
            addx := unsigned'("00") & unsigned(r.op1.mant(54 downto 28));
          end if;
          if r.addneg = '1' then
            vtmpadd   := addx - addy;
            if r.carry = '1' then
              vtmpadd := vtmpadd - 1;
            end if;
          else
            vtmpadd   := addx + addy;
            if r.carry = '1' then
              vtmpadd := vtmpadd + 1;
            end if;
          end if;
        end if;
        -- Add/sub of higher bits
        v.op2.mant(55 downto 28) := std_logic_vector(vtmpadd(27 downto 0));
        v.s                      := nf_muladd_xaddsub6;
        v.nalimdp                := '1';
        -- No bits set in op2?
        if all_0(v.op2.mant) then
          -- Bring up low bits
          v.op2.mant := "00" & r.s2(r.accbot'high + 2 downto 0);
          v.op2.exp  := r.op2.exp - r.accbot'length;
          v.s2       := (others => '0');
        end if;

      when nf_muladd_xaddsub6 =>
        -- Scan for implicit 1 (r.op2normadj) handled in shared resource.
        v.opaction  := OPACT_SHFTN;
        v.adjustsel := 2;
        v.s         := nf_muladd_xaddsub7;
        -- Shift should bring up some low bits?
        if v.opnormadj > 0 then
          v.s        := nf_muladd_xaddsub8;
          -- For shift in next step
          v.op1.mant := "00" & r.s2(r.accbot'high + 2 downto 0);
          v.expadj   := v.opnormadj - to_signed(r.accbot'length, v.expadj'length);
        end if;

      when nf_muladd_xaddsub7 =>
        v.op2.exp   := adjusted.exp;
        v.op2.mant  := adjusted.mant;
        -- Need to check if this is actually exact.
        if all_0(r.opnormadj) then
          v.op2.mant(1) := r.s2(r.accbot'high + 2);
          v.op2.mant(0) := v.op2.mant(0) or to_bit(not all_0(r.s2(r.accbot'high + 1 downto 0)));
        else
          v.op2.mant(0) := to_bit(not all_0(r.s2(r.accbot'high + 2 downto 0)));
        end if;
        -- Adjust so that the implicit 1 is at the expected position.
        v.s         := nf_round;

      when nf_muladd_xaddsub8 =>
        v.op2.exp   := adjusted.exp;
        v.op2.mant  := adjusted.mant;
        v.opaction  := OPACT_SHFTA;
        v.adjustsel := 1;
        v.s         := nf_muladd_xaddsub9;

      when nf_muladd_xaddsub9 =>
        v.op2.mant  := r.op2.mant or adjusted.mant;
        -- Adjust so that the implicit 1 is at the expected position.
        v.s         := nf_round;

      when others => null;
    end case;
  else
    v.s := nf_idle;
  end if;
    end case;


    if unissue(2 to 4) /= "000" then
      v.s         := nf_idle;
      v.fpu_holdn := '1';
      v.wen       := '0';
      v.flags_wen := '0';
    end if;

    -- Generate flow control flags
    v.readyflop   := '0';
    if v.s = nf_idle then --or v.s = nf_rdwrite2 then
      v.readyflop := '1';
    end if;

    if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)    = 0 and
       GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 0 then
      if rstn = '0' then
        v.s := RRES.s;
      end if;
    end if;

    if r.ren(1) = '1' then
      v.s1 := s1;
    end if;
    if r.ren(2) = '1' then
      v.s2 := s1;
    end if;
    if no_muladd = 0 and r.ren(3) = '1' then
      v.s3 := s1;
    end if;

    -- Reuse storage
    if divrem then
      v.s1(28      downto 0)  := std_logic_vector(divrem1);
      v.s1(28 + 32 downto 32) := std_logic_vector(divrem2);
    end if;

      v.op1.w := (others => '0');
      v.op2.w := (others => '0');

    -- Signal assignments
    rin          <= v;
    ready_flop   <= r.readyflop;
    fpu_holdn    <= v.fpu_holdn;
    issue_id     <= "00000";
    rd           <= r.rd;
    wen          <= r.wen;
    flags_wen    <= r.flags_wen;
    stdata       <= v.res;
    flags        <= r.exc;

    rs1          <= v.rs1;
    rs2          <= v.rs2;
    rs3          <= v.rs3;
    ren          <= (v.ren(1) or v.ren(2) or v.ren(3)) & "00";
  end process;

  srstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 0 generate
    regs : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        --if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rstn = '0' then
        if rstn = '0' then
          r <= RRES;
        end if;
      end if;
    end process;
  end generate srstregs;

  arstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) /= 0 generate
    regs: process(clk, rstn)
    begin
      if rstn = '0' then
        r <= RRES;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;
  end generate arstregs;


end;
