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
-- Entity:      nanofpunv
-- File:        nanofpunv.vhd
-- Author:      Magnus Hjorth and Johan Klockars, Cobham Gaisler
-- Description: Minimal bare bones FPC and FPU for NOEL-V,
--              based on the one for LEON5.
------------------------------------------------------------------------------

-- This is a minimal non-pipelined IEEE754 (qqq to be -2008) compliant implementation
-- of an FPC and FPU for providing hardware FPU operations on NOEL-V.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
--use grlib.sparc.all;
use grlib.config.all;
use grlib.config_types.all;
library gaisler;
use gaisler.utilnv.all;
use grlib.riscv.all;
use gaisler.noelv.all;

entity nanofpunv is
  generic (
    -- Extensions
    fpulen    : integer range 0  to 128 := 0;  -- Floating-point precision
    -- Core
    no_muladd : integer range 0  to 1   := 0   -- 1 - multiply-add not supported
  );
  port (
    clk           : in  std_ulogic;
    rstn          : in  std_ulogic;
    -- Pipeline interface
    --   Issue interface
    holdn         : in  std_ulogic;
    issue_cmd     : in  std_ulogic;
    issue_op      : in  fpunv_op;
    s1            : in  word64;
    s2            : in  word64;
    s3            : in  word64;   -- For muladd
    issue_id      : out std_logic_vector(4 downto 0);
    fpu_holdn     : out std_ulogic;
    ready_flop    : out std_ulogic;
    --   Commit interface
    commit        : in  std_ulogic;
    commitid      : in  std_logic_vector(4 downto 0);
    lddata        : in  word64;
    --   Mispredict/trap interface
    unissue       : in  std_ulogic;
    unissue_sid   : in  std_logic_vector(4 downto 0);
    --   Result data interface
    rs1           : out std_logic_vector(4 downto 0);
    rs2           : out std_logic_vector(4 downto 0);
    rs3           : out std_logic_vector(4 downto 0);
    rd            : out std_logic_vector(4 downto 0);
    wen           : out std_ulogic;
    flags_wen     : out std_ulogic;
    stdata        : out word64;
    flags         : out std_logic_vector(4 downto 0)
  );
end;

architecture rtl of nanofpunv is

  constant FPUVER : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(5, 3));

  type nanofpu_state is (nf_idle, nf_flop0, nf_flop1,
                         nf_load2, nf_fromint, nf_store2, nf_muladd2, nf_mvxw2, nf_min2,
                         nf_sd2, nf_fitos2, nf_fitos3, nf_fstoi2, nf_fstoi3, nf_fstoi4,
                         nf_sgn2, nf_addsub2, nf_addsub3, nf_add4, nf_add5,
                         nf_sub4, nf_sub5, nf_addsub6, nf_addsub7,
                         nf_mul2, nf_mul3, nf_mul4, nf_mul5, nf_mul6, nf_mul7,
                         nf_div2, nf_div3, nf_div4, nf_div5, nf_div6,
                         nf_sqrt2, nf_sqrt3, nf_sqrt4, nf_sqrt5, nf_sqrt6,
                         nf_sqrt7, nf_sqrt8, nf_sqrt9, nf_sqrt10, nf_sqrt11,
                         nf_round, nf_repack, nf_opdone, nf_rdwrite, nf_rdwrite2, nf_cmp2, nf_finish);

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

  type op_action is (OPACT_NONE, OPACT_UNPACK, OPACT_ROUND, OPACT_RSV2, OPACT_SHFTN, OPACT_SHFTA, OPACT_SHFTNS, OPACT_SHFTAS);

  constant R_NEAREST   : std_logic_vector(2 downto 0) := "000";  -- RNE Nearest, ties to even
  constant R_ZERO      : std_logic_vector(2 downto 0) := "001";  -- RTZ Towards zero
  constant R_MINUS_INF : std_logic_vector(2 downto 0) := "010";  -- RDN Down, towards negative infinity
  constant R_PLUS_INF  : std_logic_vector(2 downto 0) := "011";  -- RUP Up, towards positive infinity
  constant R_RMM       : std_logic_vector(2 downto 0) := "011";  -- Nearest, ties to max magnitude
  -- The reset are illegal, except that in an instruction "111" (DYN) means that
  -- rouding mode should be fetched from CSR register.

  constant EXC_NX : integer := 0;
  constant EXC_DZ : integer := 1;
  constant EXC_UF : integer := 2;
  constant EXC_OF : integer := 3;
  constant EXC_NV : integer := 4;

  constant defnan_dp : word64 := x"7ff8000000000000";
  constant defnan_sp : word64 := x"ffffffff7fc00000";

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
    res         : word64;
    exc         : std_logic_vector( 4 downto 0);
    rddp        : std_ulogic;
    flop        : std_logic_vector(4 downto 0);
    rmb         : std_logic_vector(2 downto 0);
    rs1         : std_logic_vector(4 downto 0);
    rs2         : std_logic_vector(4 downto 0);
    rs3         : std_logic_vector(4 downto 0);
    rd          : std_logic_vector(4 downto 0);
    wen         : std_ulogic;
    flags_wen   : std_ulogic;
    committed   : std_ulogic;
    op1         : float;
    op2         : float;
    op3         : float;
    op1action   : op_action;
    op2action   : op_action;
    op1normadj  : signed(6 downto 0);
    op2normadj  : signed(6 downto 0);
    nalimdp     : std_ulogic;
    nalimsp     : std_ulogic;
    naeven      : std_ulogic;
    expadj1     : signed(12 downto 0);
    expadj2     : signed(12 downto 0);
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
    acclo       : unsigned(27 downto 0);
    -- Divider registers
    divfirst    : std_ulogic;
    divrem1     : unsigned(28 downto 0);
    divrem2     : unsigned(28 downto 0);
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
    res         => (others => '0'),
    exc         => "00000",
    rddp        => '0',
    flop        => (others => '0'),
    rmb         => (others => '0'),
    rs1         => "00000",
    rs2         => "00000",
    rs3         => "00000",
    rd          => "00000",
    wen         => '0',
    flags_wen   => '0',
    committed   => '0',
    op1         => float_none,
    op2         => float_none,
    op3         => float_none,
    op1action   => OPACT_NONE,
    op2action   => OPACT_NONE,
    op1normadj  => (others => '0'),
    op2normadj  => (others => '0'),
    nalimdp     => '0',
    nalimsp     => '0',
    naeven      => '0',
    expadj1     => (others => '0'),
    expadj2     => (others => '0'),
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
    divfirst    => '0',
    divrem1     => (others => '0'),
    divrem2     => (others => '0'),
    divcmp1     => '0',
    divcmp11    => '0',
    divcmp2     => '0',
    divremz     => '0'
  );

  signal issue_int     : std_ulogic;

  signal r, rin : nanofpu_regs;

begin

  issue_int  <= '0';

  comb : process(r, rstn, holdn,
                 issue_cmd, issue_op,
                 issue_int,
                 s1, s2, s3,
                 commit, commitid, lddata, unissue, unissue_sid)
    variable v        : nanofpu_regs;
    variable vrs1     : word64;
    variable vrs2     : word64;
    variable vrs3     : word64;
    variable vtmpadd  : unsigned(28 downto 0);
    variable vtmpexp  : signed(12 downto 0);
    variable vadj     : signed(6 downto 0);
    variable vgrd     : std_ulogic;
    variable vrndbits : std_logic_vector(2 downto 0);
    variable vrndup   : std_ulogic;
    variable vswap    : std_ulogic;
    variable vop      : float;
    variable inf_1x2  : float;
    variable defnan   : word64;
    variable fcc      : std_logic_vector(1 downto 0);
    variable use_fs2  : boolean;
    variable n        : integer range 0 to 7;
    variable sign     : std_ulogic;

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
      r.mant    := "00" & opu(63 downto 52) & zerov(41 downto 0);
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
        r.mant       := "01" & opu(22 downto 0) & zerov(30 downto 0);
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

    function adjust(mant_in : std_logic_vector(55 downto 0);
                    vadj    : signed(6 downto 0)) return std_logic_vector is
      variable mant : std_logic_vector(55 downto 0) := mant_in;
    begin
      -- Shift mantissa left, decrease exponent.
      for x in 1 to 52 loop
        if vadj = to_signed(x, 7) then
          mant              := (others => mant_in(0));
          mant(55 downto x) := mant_in(55 - x downto 0);
        end if;
      end loop;

      -- Shift mantissa right, increase exponent.
      for x in 1 to 54 loop
        if vadj = to_signed(-x, 7) then
          mant                  := (others => '0');
          mant(55 - x downto 1) := mant_in(55 downto 1 + x);
          if not all_0(mant_in(x downto 0)) then
            mant(0)             := '1';
          end if;
        end if;
      end loop;

      -- Too large down shift results in 0 (except for bottom rounding bit).
      if vadj < -54 then
        mant      := (others => '0');
        if not all_0(mant_in) then
          mant(0) := '1';
        end if;
      end if;

      return mant;
    end adjust;

  begin
    v := r;

    if r.rddp = '1' then
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
      vrs3(63 downto 32) := r.s3(31 downto 0);
      vrs3(31 downto 0)  := r.s3(63 downto 32);
    else
      vrs1               := r.s1;
      vrs2               := r.s2;
      vrs3               := r.s3;
    end if;

    if not notx(r.s1) then
      setx(vrs1);
    end if;
    if not notx(r.s2) then
      setx(vrs2);
    end if;
    if not notx(r.s3) then
      setx(vrs3);
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

    -- Unpacking and re-normalization logic for r.op1.mant, r.op2.mant.
    -- Also rounding for r.op2.mant.
    case r.op1action is
      when OPACT_UNPACK =>
        v.op1 := unpack(r.s1, not r.rddp);

      when OPACT_SHFTN | OPACT_SHFTA | OPACT_SHFTAS | OPACT_SHFTNS =>
        case r.op1action is
          when OPACT_SHFTN | OPACT_SHFTNS =>
            vadj   := r.op1normadj;
          when others =>
            vadj   := r.expadj1(6 downto 0);
            -- Lower than -64? Then use -64!
            if r.expadj1(12) = '1' and not all_1(r.expadj1(12 downto 6)) then
              vadj := "1000000";
            end if;
        end case;

        v.op1.mant := adjust(r.op1.mant, vadj);
        v.op1.exp  := r.op1.exp - vadj;

        -- Single precision?
        if r.op1action = OPACT_SHFTAS or r.op1action = OPACT_SHFTNS then
          vgrd           := '0';
          for q in 0 to 29 loop
            vgrd         := vgrd or v.op1.mant(q);
          end loop;
          v.op1.mant(29) := vgrd;
        end if;

      when others => null;
    end case;

    case r.op2action is
      when OPACT_UNPACK =>
        v.op2 := unpack(r.s2, not r.rddp);

      when OPACT_SHFTN | OPACT_SHFTA | OPACT_SHFTAS | OPACT_SHFTNS =>
        case r.op2action is
          when OPACT_SHFTN | OPACT_SHFTNS =>
            vadj   := r.op2normadj;
          when others =>
            vadj   := r.expadj2(6 downto 0);
            -- Lower than -64? Then use -64!
            if r.expadj2(12) = '1' and not all_1(r.expadj2(12 downto 6)) then
              vadj := "1000000";
            end if;
        end case;

        v.op2.mant := adjust(r.op2.mant, vadj);
        v.op2.exp  := r.op2.exp - vadj;

        -- Single precision?
        if r.op2action = OPACT_SHFTAS or r.op2action = OPACT_SHFTNS then
          vgrd           := '0';
          for q in 0 to 29 loop
            vgrd         := vgrd or v.op2.mant(q);
          end loop;
          v.op2.mant(29) := vgrd;
        end if;

      when OPACT_ROUND | OPACT_RSV2 =>
        assert r.op2action /= OPACT_RSV2;
        assert r.op2.mant(55 downto 54) = "01" or is_zero(r.op2)         or
               ((r.op2.exp <= -126 or r.op2.exp > 126) and r.rddp = '0') or
               r.op2.exp <= -1022 or r.op2.exp > 1022;
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
          when others =>                -- R_MINUS_INF
            vrndup   := to_bit(r.op2.neg) and (vrndbits(1) or vrndbits(0));
        end case;

        if vrndup = '1' then
          if r.rddp = '1' then
            v.op2.mant(53 downto 2)  := std_logic_vector(unsigned(r.op2.mant(53 downto 2)) + 1);
            if all_1(r.op2.mant(53 downto 2)) then
              v.op2.mant(54)         := '1';
              if r.op2.mant(54) = '1' then
                v.op2.exp            := r.op2.exp + 1;
              end if;
            end if;
          else
            v.op2.mant(53 downto 31) := std_logic_vector(unsigned(r.op2.mant(53 downto 31)) + 1);
            if all_1(r.op2.mant(53 downto 31)) then
              v.op2.mant(54)         := '1';
              if r.op2.mant(54) = '1' then
                v.op2.exp            := r.op2.exp + 1;
              end if;
            end if;
          end if;
        end if;

        -- Inexact
        if vrndbits(1 downto 0) /= "00" then
          v.exc(EXC_NX) := '1';
        end if;

        -- Underflow
        if v.op2.mant(54) = '0' and v.exc(EXC_NX) = '1' then
          v.exc(EXC_UF) := '1';
        end if;

        -- Underflow to zero
        if (r.rddp = '0' and r.op2.exp < -126) or r.op2.exp < -1022 then
          v.exc(EXC_UF) := '1';
          v.exc(EXC_NX) := '1';
          v.op2.class   := C_ZERO;
        end if;

        -- Overflow
        if v.op2.exp > 1023 or (r.rddp = '0' and v.op2.exp > 127) then
          v.exc(EXC_OF) := '1';
          v.exc(EXC_NX) := '1';
          -- Set the operand to infinity, this is not right for all rounding modes.
          --   Those cases gets patched up in nf_pack state.
          v.op2.class   := C_INF;
        end if;

      when others => null;
    end case;

    v.op1normadj := find_normadj(r.op1, r.nalimdp, r.nalimsp, r.naeven);
    v.op2normadj := find_normadj(r.op2, r.nalimdp, r.nalimsp, r.naeven);

    -- Multiplier/accumulator pipeline
    -- Dealing with 14 bits at a time.
    if r.accen = '1' then
      if r.accshft = '1' then
        -- Shift down 14 bits
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
    v.op1action := OPACT_NONE;
    v.op2action := OPACT_NONE;
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

    case r.s is
      when nf_idle =>
        v.rd          := issue_op.rd;
        v.rm          := issue_op.rm;
        v.rmb         := issue_op.opx;
        v.rs1         := issue_op.rs1;
        v.rs2         := issue_op.rs2;
        v.rs3         := issue_op.rs3;
        v.rddp        := not issue_op.sp;
        v.flop        := issue_op.op;
        v.committed   := '0';
        v.exc         := (others => '0');
        v.acc         := (others => '0');
        v.acclo       := (others => '0');
        v.exc         := (others => '0');
        v.fpu_holdn   := '1';
        v.readyflop   := '1';
        if issue_cmd = '1' and holdn = '1' then
          v.committed := commit;
          v.op1action := OPACT_UNPACK;
          v.op2action := OPACT_UNPACK;
          if issue_op.op = S_LOAD or issue_op.op = R_FMV_W_X then
            v.s       := nf_load2;
          elsif issue_op.op = R_FCVT_S_W then
            v.s       := nf_fromint;
          else
            v.s       := nf_flop0;
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

      when nf_flop0 =>
        v.op3                 := unpack(r.s3, not r.rddp);
        v.res                 := r.s1;  -- For fmv.x.w and fs*
        if r.rddp = '0' and r.flop /= R_FSGN and r.flop /= R_FMIN then
          v.res(63 downto 32) := (others => r.s1(31));
        end if;
        v.s                   := nf_flop1;

      when nf_flop1 =>
        -- Unpack operands
        case r.flop is
          when S_STORE =>
            v.res                 := r.op2.w;
            if r.rddp = '0' then
              v.res(63 downto 32) := r.op2.w(31 downto 0);
            end if;
            v.s         := nf_store2;
          when S_FMADD | S_FMSUB | S_FNMSUB | S_FNMADD =>
            v.s         := nf_muladd2;
          when R_FCMP =>
            v.s         := nf_cmp2;
          when R_FMV_X_W =>
            v.s         := nf_mvxw2;
          when R_FCVT_S_D =>        -- Also D_S
            -- Swap around for result!
            v.rddp      := not r.rddp;
            if v.rddp = '0' then
              v.nalimsp := '1';
            end if;
            v.op2       := r.op1;
            v.s         := nf_sd2;
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
            v.s         := nf_sqrt2;
            v.naeven    := '1';
          when others =>
            v.s         := nf_idle;
        end case;

      when nf_load2 =>
        v.readyflop             := '0';
        if commit = '1' and holdn = '1' then
          v.res                 := lddata;
          if r.rddp = '0' then
            v.res(63 downto 32) := (others => '1');  -- NaN-boxing
          end if;
          v.s                   := nf_opdone;
        end if;

      -- S/D_W/WU/L/LU
      when nf_fromint =>
        v.readyflop := '0';
        if commit = '1' and holdn = '1' then
          v.op2.w   := lddata;
          sign      := '0';
          case r.rs2(1 downto 0) is
            when "00" =>  -- _W
              sign  := lddata(31);
              v.op2.w(63 downto 32) := (others => sign);
            when "01" =>  -- _WU
              v.op2.w(63 downto 32) := (others => '0');
            when "10" =>  -- _L
              sign  := lddata(63);
            when others =>  -- 11 _LU
              null;
          end case;
          if sign = '1' then
            v.op2.w := std_logic_vector(unsigned(not v.op2.w) + 1);
          end if;
          -- Take care of top bits with an add later if needed.
          v.op1     := int2ernalh(v.op2.w, sign = '1');
          v.op2     := int2ernal(v.op2.w, sign = '1');
          v.s       := nf_fitos2;
        end if;

      when nf_fitos2 =>
        if is_zero(r.op2) and is_zero(r.op1) then
          v.s           := nf_repack;
        else
          -- Figure out the amount to shift up the exponent
          -- calculated by op1/2normadj.
          v.s           := nf_fitos3;
          if is_normal(r.op2) then
            v.op2action   := OPACT_SHFTN;
            if r.rddp = '0' then
              v.op2action := OPACT_SHFTNS;
            end if;
          end if;
          if is_normal(r.op1) then
            v.op1action   := OPACT_SHFTN;
            if r.rddp = '0' then
              v.op1action := OPACT_SHFTNS;
            end if;
          end if;
        end if;

      when nf_sd2 =>
        -- Figure out the amount to shift up the exponent
        -- calculated by op2normadj.
        if is_normal(r.op2) then
          v.s           := nf_fitos3;
          v.op2action   := OPACT_SHFTN;
          if r.rddp = '0' then
            v.op2action := OPACT_SHFTNS;
          end if;
        elsif is_signan(r.op2) then
          v.res         := defnan;
          v.exc(EXC_NV) := '1';
          v.s           := nf_opdone;
        else
          v.s           := nf_repack;
        end if;

      when nf_fitos3 =>
        -- Shift up the value (op2action = SHFTN)
        v.s           := nf_repack;
        -- Go through nf_round to get over/underflow check for fcvt.s.d.
        -- Also do this for FITOS to get inexact exception check.
        -- Note that fcvt.d.s and fcvt.d.w[u] are always exact and thus do not require rounding.
        if is_normal(r.op2) and
           not ((v.rddp = '1' and r.flop = R_FCVT_S_D) or
                (v.rddp = '1' and r.flop = R_FCVT_S_W and (r.rs2 = R_FCVT_W or r.rs2 = R_FCVT_WU))) then
          v.s         := nf_round;
          v.op2action := OPACT_ROUND;
        end if;
        -- In case of integer to floating point coversions,
        -- check for any high bits that need to be added.
        if r.flop = R_FCVT_S_W and not is_zero(r.op1) then
          v.flop      := R_FADD;
          v.comphl     := '0';  -- v.op1 _is_ higher
          v.comphe     := '0';
          v.compll     := '0';
          v.comple     := '0';
          v.s         := nf_addsub2;
        end if;

      when nf_fstoi2 =>
        if is_nan(r.op2) then
          v.exc(EXC_NV)   :='1';
        end if;
        if is_nan(r.op2) or is_inf(r.op2) or
           (r.rs2(1 downto 0) = "00" and r.op2.exp > 30) or
           (r.rs2(1 downto 0) = "01" and r.op2.exp > 31) or
           (r.rs2(1 downto 0) = "10" and r.op2.exp > 62) or
           (r.rs2(1 downto 0) = "11" and r.op2.exp > 63) then
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
                v.res       := x"8000000000000000";
              else
                v.res       := x"ffffffff80000000";
              end if;
            end if;
          end if;
          if not (is_normal(r.op2) and r.op2.exp = 31 and r.op2.neg and
                  all_0(r.op2.mant(53 downto 23))) then
            v.exc(EXC_NV) := '1';
            v.s           := nf_finish;
          else
            v.fpu_holdn   := '1';
            v.s           := nf_idle;
          end if;
        elsif is_zero(r.op2) then
          v.res           := (others => '0');
          v.fpu_holdn     := '1';
          v.s             := nf_idle;
        elsif r.op2.neg and r.op2.exp >= 0 and r.rs2(0) = '1' then   -- _WU or _LU
          v.exc(EXC_NV)   := '1';
          v.res           := zerov;
          v.s             := nf_finish;
        else
          -- Calculate the amount to shift up to get an exponent of 2^52.
          --   This will place the number in the mantissa bits 53:2.
          v.expadj2       := r.op2.exp - 52;
          v.op2action     := OPACT_SHFTA;
          -- Calculate the amount to shift up to get an exponent of 2^64.
          --   This will place the high bits in the mantissa bits 53:42.
          v.expadj1       := r.op1.exp - 64;
          v.op1action     := OPACT_SHFTA;
          v.s             := nf_fstoi3;
        end if;

      when nf_fstoi3 =>
        -- Performing shift
        v.s := nf_fstoi4;

      when nf_fstoi4 =>
        -- Extract result from mantissa bits
        if r.op2.neg then
          if r.rs2(1) = '0' then
            v.res(31 downto 0)  := std_logic_vector(-signed(r.op2.mant(33 downto 2)));
          else
            v.res(51 downto 0)  := r.op2.mant(53 downto 2);
            v.res(63 downto 52) := r.op1.mant(53 downto 42);
            v.res               := std_logic_vector(-signed(v.res));
          end if;
        else
          if r.rs2(1) = '0' then
            v.res(31 downto 0)  := '0' & r.op2.mant(32 downto 2);
            if r.rs2(0) = '1' then   -- _WU or _LU
              v.res(31)         := r.op2.mant(33);
            end if;
            v.res(63 downto 32) := (others => '0');
          else
            v.res(51 downto 0)  := r.op2.mant(53 downto 2);
            v.res(63 downto 52) := r.op1.mant(53 downto 42);
          end if;
        end if;
        if r.rs2(1) = '0' then
          v.res(63 downto 32)   := (others => v.res(31));
        end if;
        v.s                   := nf_idle;
        if r.op2.mant(1 downto 0) /= "00" then
          v.exc(EXC_NX)       := '1';
          v.s                 := nf_finish;
        end if;
        v.fpu_holdn           := '1';

      when nf_sgn2 =>
        if r.rddp = '0' then
          sign := r.op2.w(31);
          -- Cannot use is_nan here since only bad NaN-boxing is relevant.
          if not all_1(r.op1.w(63 downto 32)) then
            v.res := defnan;
          end if;
          if not all_1(r.op2.w(63 downto 32)) then --r.op2.w = x"0000000080000000" then
            sign := '0';
          end if;
          case r.rmb is
            when R_FSGNJ  => v.res(31) := sign; -- and not to_bit(all_0(r.op2.w(30 downto 0)));
            when R_FSGNJN => v.res(31) := not sign;  -- R_FSGNJX below
            when others   => v.res(31) := v.res(31) xor sign;
          end case;
        else
          case r.rmb is
            when R_FSGNJ  => v.res(63) := r.op2.w(63);
            when R_FSGNJN => v.res(63) := not r.op2.w(63);  -- R_FSGNJX below
            when others   => v.res(63) := r.res(63) xor r.op2.w(63);
          end case;
        end if;
        v.s := nf_opdone;

      when nf_addsub2 =>
        vswap := '0';
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
          vswap := '1';
        elsif r.comphe = '1' and r.comple = '1' and
              (r.flop = R_FSUB xor r.op1.neg xor r.op2.neg) then
          -- Sum to zero
          v.s           := nf_opdone;
          v.res         := (others => '0');
          if r.rm = R_MINUS_INF then
            v.res(63)   := '1';
          end if;
          if r.rddp = '0' then
            v.res(63 downto 32) := (others => '1');  -- NaN-boxing
            if r.rm = R_MINUS_INF then
              v.res(31) := '1';
            end if;
          end if;
        elsif is_zero(r.op2) then
          v.s           := nf_repack;
          vswap         := '1';
        elsif is_zero(r.op1) then
          v.s           := nf_repack;
          if r.flop = R_FSUB then
            v.op2.neg  := not r.op2.neg;
          end if;
        else
          -- Make sure the bigger argument in terms of magnitude is in rs2,
          -- swap if that is not the case.
          -- If we swap and subtract then we need to flip the signs.
          -- We also negate the signs for subtraction because the FPU
          --   calculates rs2-rs1 instead of rs1-rs2 as expected.
          if r.comphl = '1' or (r.comphe = '1' and r.compll = '1') then
            -- No swap needed abs(rs2) > abs(rs1)
            -- Flip signs if doing subtract
            if r.flop = R_FSUB then
              v.op1.neg := not r.op1.neg;
              v.op2.neg := not r.op2.neg;
            end if;
            v.expadj1    := r.op1.exp - r.op2.exp;
          else
            -- Swap needed
            vswap        := '1';
            -- 2 times sign flip cancel out
            v.expadj1    := r.op2.exp - r.op1.exp;
          end if;
          v.s            := nf_addsub3;
          v.op1action    := OPACT_SHFTA;
          -- op2 will be shifted by 0 or 1 (see below)
          v.expadj2      := (others => '0');
          v.op2action    := OPACT_SHFTA;
          if r.rddp = '0' then
            v.op1action  := OPACT_SHFTAS;
            v.op2action  := OPACT_SHFTAS;
          end if;
          -- If it will use the subtract operation then we shift up both args by 1.
          --   This is to ensure there are enough guard digits.
          if r.flop = R_FSUB xor r.op1.neg xor r.op2.neg then
            v.expadj1    := v.expadj1 + 1;
            v.expadj2    := v.expadj2 + 1;
          end if;
        end if;
        if vswap = '1' then
          v.op2          := r.op1;
          v.op1          := r.op2;
        end if;

      when nf_addsub3 =>
        -- Shift down the mantissa of the smaller arg in r.op1.
        --   Handled by op1action.
        -- Decide whether to use "real" add or sub
        -- Sign of rs1 is ignored after this.
        -- Skip ahead if single precision.
        v.carry := '0';
        if r.flop = R_FSUB xor r.op1.neg xor r.op2.neg then
          v.s   := nf_sub4;
          if r.rddp = '0' then
            v.s := nf_sub5;
          end if;
        else
          v.s   := nf_add4;
          if r.rddp = '0' then
            v.s := nf_add5;
          end if;
        end if;

      when nf_add4 =>
        -- Add lower bits
        vtmpadd                 := unsigned('0' & r.op2.mant(27 downto 0)) +
                                   unsigned('0' & r.op1.mant(27 downto 0));
        v.op2.mant(27 downto 0) := std_logic_vector(vtmpadd(27 downto 0));
        v.carry                 := vtmpadd(28);
        v.s                     := nf_add5;

      when nf_add5 =>
        -- Add higher bits
        vtmpadd                  := (unsigned'("00") & unsigned(r.op2.mant(54 downto 28))) +
                                    (unsigned'("00") & unsigned(r.op1.mant(54 downto 28)));
        if r.carry = '1' then
          vtmpadd                := vtmpadd + 1;
        end if;
        v.op2.mant(55 downto 28) := std_logic_vector(vtmpadd(27 downto 0));
        v.s                      := nf_addsub6;
        if r.rddp = '1' then
          v.nalimdp              := '1';
        else
          v.nalimsp              := '1';
        end if;

      when nf_sub4 =>
        -- Sub lower bits
        vtmpadd                 := unsigned('0' & r.op2.mant(27 downto 0)) -
                                   unsigned('0' & r.op1.mant(27 downto 0));
        v.op2.mant(27 downto 0) := std_logic_vector(vtmpadd(27 downto 0));
        v.carry                 := vtmpadd(28);
        v.s                     := nf_sub5;

      when nf_sub5 =>
        -- Sub higher bits
        vtmpadd                  := unsigned('0' & r.op2.mant(55 downto 28)) -
                                    unsigned('0' & r.op1.mant(55 downto 28));
        if r.carry = '1' then
          vtmpadd                := vtmpadd - 1;
        end if;
        v.op2.mant(55 downto 28) := std_logic_vector(vtmpadd(27 downto 0));
        v.s                      := nf_addsub6;
        if r.rddp = '1' then
          v.nalimdp              := '1';
        else
          v.nalimsp              := '1';
        end if;

      when nf_addsub6 =>
        -- Scan for implicit 1 (r.op2normadj) handled in shared resource.
        v.op2action := OPACT_SHFTN;
        v.s         := nf_addsub7;

      when nf_addsub7 =>
        -- Adjust so that the implicit 1 is at the expected position.
        v.op2action := OPACT_ROUND;
        v.s         := nf_round;

      when nf_muladd2 =>
        inf_1x2          := inf_mul(r.op1, r.op2);
        if is_nan(r.op1) or is_nan(r.op2) or is_nan(r.op3) then
          v.res          := defnan;
          v.s            := nf_opdone;
        elsif mul_illegal(r.op1, r.op2)                                                          or
              ((r.flop = S_FMADD or r.flop = S_FNMADD) and add_illegal(inf_1x2, r.op3))          or
              ((r.flop = S_FMSUB or r.flop = S_FNMSUB) and add_illegal(inf_1x2, inf_neg(r.op3))) then
          v.exc(EXC_NV)  := '1';
          v.res          := defnan;
          v.s            := nf_opdone;
        elsif is_inf(r.op1) or is_inf(r.op2) or is_inf(r.op3) then
          v.op2.class    := C_INF;
          v.op2.neg      := false;
          if is_inf(r.op1) or is_inf(r.op2) then
            v.op2.neg    := inf_1x2.neg;
          elsif is_inf(r.op3) and
                (((r.flop = S_FMADD or r.flop = S_FNMADD) and r.op3.neg) or
                 ((r.flop = S_FMSUB or r.flop = S_FNMSUB) and not r.op3.neg)) then
              v.op2.neg  := true;
            end if;
            -- These are the opposites of S_FMADD/SUB
            if r.flop = S_FNMADD or r.flop = S_FNMSUB then
              v.op2.neg  := not v.op2.neg;
            end if;
            v.s          := nf_repack;
        elsif is_zero(r.op1) or is_zero(r.op2) then   -- No multiply?
          v.op2          := r.op3;
          -- Take care of negation
          if r.flop = S_FNMADD or r.flop = S_FNMSUB then
            v.op2.neg    := not v.op2.neg;
          end if;
          v.s            := nf_repack;
        else
          -- On next cycle, re-normalize number in case of denormal input.
          v.op1action    := OPACT_SHFTN;
          v.op2action    := OPACT_SHFTN;
          v.op2.neg      := r.op1.neg xor r.op2.neg;
          -- Take care of negation
          if r.flop = S_FNMADD or r.flop = S_FNMSUB then
            v.op2.neg    := not v.op2.neg;
          end if;
          if r.flop = S_FNMADD or r.flop = S_FMSUB then
            v.op3.neg    := not r.op3.neg;
          end if;
          v.flop         := S_FMADD;
          -- If no add, handle as mul.
          if is_zero(r.op3) then
            v.flop       := R_FMUL;
          end if;
          v.s            := nf_mul3;
        end if;

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
          v.op1action   := OPACT_SHFTN;
          v.op2action   := OPACT_SHFTN;
          v.s           := nf_mul3;
          v.op2.neg     := r.op1.neg xor r.op2.neg;
        end if;

      when nf_mul3 =>
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
          if r.rddp = '1' then
            v.nalimdp              := '1';
          else
            v.nalimsp              := '1';
          end if;
        end if;

      when nf_mul6 =>
        -- Computing amount of normalization
        -- Do shift in next state
        v.op2action := OPACT_SHFTN;
        v.s         := nf_mul7;

      when nf_mul7 =>
        -- Re-normalizing
        -- Do rounding in next state
        v.op2action := OPACT_ROUND;
        -- In case there was a muladd
        v.op1       := r.op3;
        v.s         := nf_round;

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
          v.op1action    := OPACT_SHFTN;
          v.op2action    := OPACT_SHFTN;
          v.s            := nf_div3;
          v.op2.neg      := r.op1.neg xor r.op2.neg;
        end if;
        if is_zero(r.op2) and is_normal(r.op1) then
          v.exc(EXC_DZ)  :='1';
        end if;

      when nf_div3 =>
        -- Re-normalizing
        v.s        := nf_div4;
        v.divfirst := '1';
        v.divremz  := '0';

      when nf_div4 =>
        -- Run division using basic radix-2 algorithm.
        -- Subtract divisor from remainder.
        vtmpadd     := unsigned('0' & r.op1.mant(27 downto 0)) -
                       unsigned('0' & r.op2.mant(27 downto 0));
        v.divrem2   := vtmpadd;
        v.divcmp2   := '0';
        if vtmpadd = (vtmpadd'range => '0') then
          v.divcmp2 := '1';
        end if;
        vtmpadd     := unsigned('0' & r.op1.mant(55 downto 28)) -
                       unsigned('0' & r.op2.mant(55 downto 28));
        v.divrem1   := vtmpadd;
        v.divcmp1   := '0';
        if vtmpadd = (vtmpadd'range => '0') then
          v.divcmp1 := '1';
        end if;
        v.s         := nf_div5;
        if r.divfirst = '1' then
          v.op2.exp := r.op1.exp - r.op2.exp;
        end if;

      when nf_div5 =>
        -- Get one bit of quotient, update remainder
        v.res(53 downto 1)           := r.res(52 downto 0);
        v.res(0)                     := '0';
        if r.divrem1(28) = '0' and (r.divcmp1 = '0' or r.divrem2(28) = '0') then
          assert r.divrem1(28 downto 27) = "00" or
                 (r.divrem1(27) = '1' and r.divrem1(26 downto 0) = (26 downto 0 => '0'));
          v.res(0)                   := '1';
          if r.divrem2(28) = '1' then
            v.op1.mant(55 downto 29) := std_logic_vector(r.divrem1(26 downto 0) - 1);
          else
            v.op1.mant(55 downto 29) := std_logic_vector(r.divrem1(26 downto 0));
          end if;
          v.op1.mant(28 downto 1)    := std_logic_vector(r.divrem2(27 downto 0));
          v.op1.mant(0)              := '0';
          vtmpadd                    := unsigned('0' & r.divrem1(26 downto 0) & '0') -
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
        v.divrem1   := vtmpadd;
        v.divcmp1   := '0';
        if vtmpadd = (vtmpadd'range => '0') then
          v.divcmp1 := '1';
        end if;
        if r.rddp = '0' then
          v.s       := nf_div5;
        end if;

        if r.res(52) = '1' or (r.rddp = '0' and r.res(23) = '1') then
          v.s                        := nf_round;
          v.op2action                := OPACT_ROUND;
          if r.rddp = '0' then
            v.op2.mant(55 downto 31) := "01" & r.res(22 downto 0);
            v.op2.mant(30)           := v.res(0);
            v.op2.mant(29 downto 1)  := (others => '0');
            v.expadj2                := r.op2.exp + 126;
            if r.op2.exp < -126 then
              v.s                    := nf_div6;
              v.op2action            := OPACT_SHFTA;
            end if;
          else
            v.op2.mant(55 downto 2)  := "01" & r.res(51 downto 0);
            v.op2.mant(1)            := v.res(0);
            v.expadj2                := r.op2.exp + 1022;
            if r.op2.exp < -1022 then
              v.s                    := nf_div6;
              v.op2action            := OPACT_SHFTA;
            end if;
          end if;
          if v.divremz = '1' then
            v.op2.mant(0)            := '0';
          else
            v.op2.mant(0)            := '1';
          end if;
        end if;

      when nf_div6 =>
        -- De-normalizing result
        v.s         := nf_round;
        v.op2action := OPACT_ROUND;

      when nf_sqrt2 =>
        -- Calculating adjustment for normalization
        v.op2action         := OPACT_SHFTN;
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
        -- Finish multiplier pipeline (mirror of nf_mul5)
        v.mulen       := '0';
        v.shftpl2     := '0';
        if r.accen = '0' then
          assert r.acc(29 downto 28) = "00";
          -- Subtract input from mul result
          vtmpadd     := unsigned('0' & r.acclo) -
                         unsigned('0' & r.op2.mant(27 downto 0));
          v.divrem2   := vtmpadd;
          -- Exact match for low bits?
          v.divcmp2   := '0';
          if vtmpadd = (vtmpadd'range => '0') then
            v.divcmp2 := '1';
          end if;
          vtmpadd     := unsigned('0' & r.acc(27 downto 0)) -
                         unsigned('0' & r.op2.mant(55 downto 28));
          v.divrem1   := vtmpadd;
          -- Exact match for high bits?
          v.divcmp1   := '0';
          if vtmpadd = (vtmpadd'range => '0') then
            v.divcmp1 := '1';
          end if;
          v.s         := nf_sqrt11;
        end if;
        v.mulsel2     := '1';

      when nf_sqrt11 =>
        v.acc              := (others => '0');
        v.acclo            := (others => '0');
        v.res(38 downto 0) := '0' & r.res(38 downto 1);
        if r.divcmp1 = '1' and r.divcmp2 = '1' then
          -- Exact match!
          v.op2.mant       := r.op1.mant;
          v.s              := nf_round;
          v.op2action      := OPACT_ROUND;
        elsif r.res(0) = '1' or (r.rddp = '0' and r.res(29) = '1') then
          -- Remainder below mantissa > 0
          v.op2.mant       := r.op1.mant;
          v.op2.mant(0)    := '1';
          v.s              := nf_round;
          v.op2action      := OPACT_ROUND;
        else
          if r.divrem1(28) = '0' and (r.divcmp1 = '0' or r.divrem2(28) = '0') then
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
        v.s      := nf_repack;
        -- Muladd needs to go do more work
        if r.flop = S_FMADD then
          v.flop := R_FADD;
          v.s    := nf_addsub2;
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
          if is_normal(r.op2) and r.op2.mant(54) = '0' then
            v.exc(EXC_UF)  := '1';
          end if;
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
        -- v.res already contains the incoming vrs1 value.
        if is_nan(r.op1) and is_nan(r.op2) then
          v.res          := defnan;
        elsif is_nan(r.op1) then
          v.res          := r.op2.w;
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
            v.res        := r.op2.w;
          end if;
        end if;
        v.s              := nf_opdone;

      when nf_store2 =>
        v.fpu_holdn := '1';
        v.s         := nf_idle;

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
          -- v.res already contains the incoming vrs1 value.
          if r.rddp = '0' then
            -- Extend sign bit when moving 32 bit float.
            v.res(63 downto 32) := (others => r.res(31));
          end if;
        end if;
        v.s              := nf_finish;

      when nf_finish =>
        v.fpu_holdn := '1';
        v.flags_wen := '1';
        v.s         := nf_idle;

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
    end case;

    -- Generate flow control flags
    v.readyflop   := '0';
    if v.s = nf_idle then --or v.s = nf_rdwrite2 then
      v.readyflop := '1';
    end if;

    if unissue = '1' then
      v.s := nf_idle;
    end if;

    if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)    = 0 and
       GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 0 then
      if rstn = '0' then
        v.s := RRES.s;
      end if;
    end if;

    if v.s = nf_idle or v.s = nf_rdwrite or v.s = nf_rdwrite2 or v.s = nf_finish then
      v.op1action := OPACT_UNPACK;
      v.op2action := OPACT_UNPACK;
    end if;

    v.s1 := s1;
    v.s2 := s2;
    v.s3 := s3;
    if holdn = '0' or v.s /= nf_idle then
      v.s1 := r.s1;
      v.s2 := r.s2;
      v.s3 := r.s3;
    end if;

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
  end process;

  srstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 0 generate
    regs : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rstn = '0' then
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
