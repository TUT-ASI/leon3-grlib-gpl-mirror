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
-- Entity:      nanofpunv
-- File:        nanofpunv.vhd
-- Author:      Magnus Hjorth and Johan Klockars, Cobham Gaisler
-- Description: Minimal bare bones FPC and FPU for NOEL-V,
--              based on the one for LEON5.
------------------------------------------------------------------------------

-- This is a small non-pipelined IEEE754-2008 compliant implementation
-- of an FPC and FPU for providing hardware FPU operations on NOEL-V.
-- No support for Zfa or Zfh[min].

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config.all;
use grlib.config_types.all;
use grlib.riscv.all;
use grlib.stdlib.tost;
use grlib.stdlib.tost_bits;
use grlib.stdlib.notx;
use grlib.stdlib.setx;
library gaisler;
use gaisler.noelvtypes.all;
use gaisler.fputilnv.all;
use gaisler.utilnv.log;
use gaisler.utilnv.notx;
use gaisler.utilnv.uadd;
use gaisler.utilnv.usub;
use gaisler.utilnv.uaddx;
use gaisler.utilnv.usubx;
use gaisler.utilnv.s2i;
use gaisler.utilnv.uext;
use gaisler.utilnv.u2vec;
use gaisler.utilnv.all_0;
use gaisler.utilnv.all_1;
use gaisler.utilnv.get_hi;
use gaisler.utilnv.to_bit;
use gaisler.noelvint.fpu5_in_type;
use gaisler.noelvint.fpu5_in_async_type;
use gaisler.noelvint.fpu5_out_type;
use gaisler.noelvint.fpu5_out_async_type;

entity nanofpunv is
  generic (
    -- Extensions
    fpulen    : integer range 0  to 128 := 64;  -- Floating-point precision
    -- Core
    no_muladd : integer range 0  to 1   := 0;   -- 1 - multiply-add not supported
    extmul    : integer range 0  to 1   := 0    -- 1 - multiply done externally
    ; do_addsel : integer := 1
  );
  port (
    clk           : in  std_ulogic;
    rstn          : in  std_ulogic;
    holdn         : in  std_ulogic;

    fpi           : in  fpu5_in_type;
    fpia          : in  fpu5_in_async_type;
    fpo           : out fpu5_out_type;
    fpoa          : out fpu5_out_async_type;


    -- Register file read interface
    rs1           : out reg_t;
    rs2           : out reg_t;
    rs3           : out reg_t;
    ren           : out std_logic_vector(1 to 3);
    s1            : in  word64;   -- All FPU register file data here
    s2            : in  word64;   -- Unused
    s3            : in  word64    -- Unused (for muladd)
  );
end;

architecture rtl of nanofpunv is

  signal e_inst        : word;
  signal e_valid       : std_ulogic;
  signal issue_id      : fpu_id;
  signal csrfrm        : word3;
  signal e_nullify     : std_ulogic;
  signal mode_in       : word3;
  signal commit        : std_ulogic;
  signal commit_id     : fpu_id;
  signal lddata_id     : fpu_id;
  signal lddata_now    : std_ulogic;
  signal lddata        : word64;
  signal unissue       : std_ulogic;
  signal unissue_id    : fpu_id;

  signal fpu_holdn     : std_ulogic;
  signal ready_flop    : std_ulogic;
  signal rd            : reg_t;
  signal wen           : std_ulogic;
  signal stdata        : word64;
  signal flags_wen     : std_ulogic;
  signal flags         : flags_t;
  signal now2int       : std_ulogic;
  signal id2int        : fpu_id;
  signal stdata2int    : word64;
  signal flags2int     : flags_t;
  signal wb_mode       : word3;
  signal wb_id         : fpu_id;
  signal idle          : std_ulogic;
  signal events        : word64;

  constant FPUVER : word3 := u2vec(5, 3);

  type nanofpu_state is (nf_idle, nf_flopr, nf_flop0, nf_flop1,
                         nf_load2, nf_fromint, nf_store2, nf_mvxw2, nf_min2,
                         nf_muladd2, nf_muladd_mid,
                         nf_muladd_xadd,
                         nf_muladd_xadd25, nf_muladd_xadd26, nf_muladd_xadd27,
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
                         nf_opdone, nf_rdwrite, nf_rdwrite2, nf_cmp2, nf_finish, nf_end
                         );

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


  type nanofpu_regs is record
    -- State
    s           : nanofpu_state;
    fpu_holdn   : std_ulogic;
    readyflop   : std_ulogic;


    last_unissued : boolean;
    last_valid    : boolean;

    events      : fpevt_t;
    events_pipe : fpevt_t;

    -- FSR fields
    rm          : rm_t;
    -- Current operation
    id          : fpu_id;
    s1          : word64;
    s2          : word64;
    s3          : word64;
    unpacksel   : integer range 1 to 3;    -- Operation MUX control
    adjustsel   : integer range 1 to 2;
    normadjsel  : integer range 1 to 2;
    addsel      : integer range 1 to 3;
    addneg      : std_ulogic;
    swap        : std_ulogic;              -- Muladd operands need swapping
    inexact     : std_ulogic;              -- Low bits in extended muladd shifted out
    res         : word64;
    exc         : flags_t;
    now2int     : std_ulogic;
    res2int     : word64;
    exc2int     : flags_t;
    rddp        : std_ulogic;              -- Double precision operation
    rddp_real   : std_ulogic;              --   actual in case of internal change
    flop        : fpuop_t;
    rmb         : rm_t;
    rs1         : reg_t;
    rs2         : reg_t;
    rs3         : reg_t;
    ren         : std_logic_vector(1 to 3);
    rd          : reg_t;
    wen         : std_ulogic;
    flags_wen   : std_ulogic;
    committed   : std_ulogic;              -- Operation marked as committed by IU
    mode        : word3;                   -- Pass along for logging
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
    muladd      : std_ulogic;
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
    last_unissued => true,
    last_valid    => false,
    events      => (others => '0'),
    events_pipe => (others => '0'),
    rm          => R_NEAREST,
    id          => (others => '0'),
    s1          => (others => '0'),
    s2          => (others => '0'),
    s3          => (others => '0'),
    unpacksel   => 1,
    adjustsel   => 1,
    normadjsel  => 1,
    addsel      => 1,
    addneg      => '0',
    swap        => '0',
    inexact     => '0',
    res         => (others => '0'),
    exc         => "00000",
    now2int     => '0',
    res2int     => (others => '0'),
    exc2int     => "00000",
    rddp        => '0',
    rddp_real   => '0',
    flop        => FPU_UNKNOWN,
    rmb         => (others => '0'),
    rs1         => "00000",
    rs2         => "00000",
    rs3         => "00000",
    ren         => "000",
    rd          => "00000",
    wen         => '0',
    flags_wen   => '0',
    committed   => '0',
    mode        => (others => '0'),
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
    muladd      => '0',
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


  signal r, rin    : nanofpu_regs;

  -- For external multiplier
  signal multiply  : std_ulogic;
  signal sqrt      : std_ulogic;
  signal mulrddp   : std_ulogic;
  signal mulsrc    : std_logic_vector(55 downto 0);
  signal mulmant   : std_logic_vector(55 downto 0);
  signal mulbottom : std_logic_vector(51 downto 0);
  signal mullo0    : std_logic_vector(0 downto 0);
  signal muldone   : std_ulogic;

  signal mul_dbg   : std_logic_vector(56 * 2 - 2 - 1 downto 2 * 2);

begin

  e_inst     <= fpi.inst;
  e_valid    <= fpi.e_valid;
  issue_id   <= fpi.issue_id;
  csrfrm     <= fpi.csrfrm;
--  e_nullify  <= fpi.e_nullify;
  e_nullify  <= fpia.e_nullify;
  mode_in    <= fpi.mode;
  commit     <= fpi.commit;
  commit_id  <= fpi.commit_id;
  lddata_id  <= fpi.data_id;
  lddata_now <= fpi.data_valid;
--  lddata     <= fpi.data;
  lddata     <= fpia.data;
  unissue    <= fpi.unissue;
  unissue_id <= fpi.unissue_id;

  fpoa.holdn     <= fpu_holdn;
  fpoa.ready     <= ready_flop;
  fpo.rd         <= rd;
  fpo.wen        <= wen;
  fpo.data       <= stdata;
  fpo.flags_wen  <= flags_wen;
  fpo.flags      <= flags;
  fpoa.now2int   <= now2int;
  fpoa.id2int    <= id2int;
  fpoa.data2int  <= stdata2int;
  fpoa.flags2int <= flags2int;
  fpo.mode       <= wb_mode;
  fpo.wb_id      <= wb_id;
  fpoa.idle      <= idle;
  fpo.events     <= events;

  mulfp_gen: if extmul = 1 generate
    mulfp_i: entity gaisler.mulfp
      generic map (
        fpulen => fpulen
      )
      port map (
        clk      => clk,
        rstn     => rstn,
        multiply => multiply,
        sqrt     => '0',
        rddp     => mulrddp,
        src      => mulsrc,
        mant     => mulmant,
        bottom   => mulbottom,
        lo0      => mullo0,
        done     => muldone
      );
  end generate;


  comb : process(r, rstn, holdn,
                 e_inst, e_valid, e_nullify, csrfrm,
                 s1, s2, s3, lddata_id, lddata_now, lddata,
                 issue_id,
                 muldone, mulmant, mulbottom, mullo0,
                 mode_in, commit, commit_id, unissue, unissue_id
                )
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
    variable vrndbits : word3;
    variable vrndup   : boolean;
    variable vop      : float;
    variable inf_1x2  : float;
    variable defnan   : word64;
    variable fcc      : word2;
    variable use_fs2  : boolean;
    variable n        : integer range 0 to 7;
    variable sign     : std_ulogic;
    variable unpackee : word64;
    variable unpacked : float;
    variable normee   : float;
    variable adjustee : float;
    variable adjusted : float;
    variable adjusted_mant0b : std_logic_vector(0 to 1);
    variable rounded  : float;
    variable roundexc : flags_t;
    variable issue_op  : fpunv_op;
    variable issue_cmd : std_ulogic;
    variable roundadd : integer;
    variable roundchk : std_ulogic;
    variable divrem   : boolean;    -- Make use of divrem (r.s1 storage)
    variable divrem1  : unsigned(28 downto 0);
    variable divrem2  : unsigned(28 downto 0);
    variable op2low0  : boolean;
    variable round_from_denormal : boolean;
    variable is_idle  : std_ulogic;
    variable evt      : fpevt_t;
    variable valid    : std_ulogic;
    -- "Notifications" to simplify some logic
    variable to_idle   : boolean;
    variable to_finish : boolean;
    variable to_addsub : boolean;
    

    function tost(x : signed) return string is
    begin
      return tost(std_logic_vector(x));
    end;

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

  begin
    v := r;

    to_idle   := false;
    to_finish := false;
    to_addsub := false;

    evt := (others => '0');

    v.now2int := '0';
--    v.exc2int := (others => '0');


    -- Sometimes reused storage
    divrem  := false;    -- Assume not use
    divrem1 := unsigned(r.s1(28      downto 0));
    divrem2 := unsigned(r.s1(28 + 32 downto 32));

    -- Only a single valid per new issue_id!
    valid := e_valid;
    if r.id = issue_id and r.last_valid then
      valid := '0';
    end if;
    if r.id /= issue_id then
      v.last_valid := false;
    end if;
    fpu_gen(e_inst, csrfrm, valid and not e_nullify, issue_op);
    issue_cmd := issue_op.valid;

    defnan := NaN(r.rddp_real = '1');

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

    unpacked := unpack(unpackee, r.rddp_real = '1');

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

    adjust_new(adjustee.mant, vadj, adjusted.mant, adjusted_mant0b);

    -- Single precision?
    vgrd   := '0';
    for q in 0 to 29 loop
      vgrd := vgrd or adjusted.mant(q);
    end loop;
    if r.opaction = OPACT_SHFTAS or r.opaction = OPACT_SHFTNS then
      adjusted.mant(29)          := vgrd;
      adjusted.mant(28 downto 0) := (others => '0');
    end if;


    rounded  := r.op2;
    if not (notx(rounded.exp) and notx(rounded.mant)) then
      rounded := float_none;
    end if;
    roundexc  := r.exc;


    roundup(r.op2, r.rddp = '1', r.rm, vrndup, vrndbits);

    round_from_denormal := false;
    if vrndup then
      if r.rddp = '1' then
        if r.op2.exp = -1023 then
          if all_1(r.op2.mant(53 downto 2)) then
            -- Was denormal, but rounded up.
            round_from_denormal    := true;
          end if;
        else
          rounded.mant(53 downto 2)  := uadd(r.op2.mant(53 downto 2), 1);
          if all_1(r.op2.mant(53 downto 2)) then
            rounded.mant(54)         := '1';
            if r.op2.mant(54) = '1' then
              rounded.exp            := r.op2.exp + 1;
            end if;
          end if;
        end if;
      else
        if r.op2.exp = -127 then
          if all_1(r.op2.mant(53 downto 31)) then
            -- Was denormal, but rounded up.
            round_from_denormal    := true;
          end if;
        else
          rounded.mant(53 downto 31) := uadd(r.op2.mant(53 downto 31), 1);
          if all_1(r.op2.mant(53 downto 31)) then
            rounded.mant(54)         := '1';
            if r.op2.mant(54) = '1' then
              rounded.exp            := r.op2.exp + 1;
            end if;
          end if;
        end if;
      end if;
    end if;

    -- Further rounding just at the edge of denormal?
    if    (r.rddp = '0' and rounded.exp = -127) or
          (r.rddp = '1' and rounded.exp = -1023) then
      rounded  := r.op2;
      if not (notx(rounded.exp) and notx(rounded.mant)) then
        rounded := float_none;
      end if;
      roundexc  := r.exc;
      rounded.exp(1 downto 0)      := "10";  -- -126 / -1022
      rounded.mant                 := '0' & rounded.mant(rounded.mant'high downto 1);
      if r.rddp = '0' then
        rounded.mant(29)           := vrndbits(1) or vrndbits(0);
      else
        rounded.mant(0)            := vrndbits(1) or vrndbits(0);
      end if;
      roundup(rounded, r.rddp = '1', r.rm, vrndup, vrndbits);
      if vrndup then
        if (r.rddp = '0' and all_1(rounded.mant(53 downto 31))) or
           (r.rddp = '1' and all_1(rounded.mant(53 downto 2))) then
          rounded.mant(53 downto 2) := (others => '0');
          rounded.mant(54)          := '1';
          -- Only set underflow if rounding with unconstrained
          -- exponent would not have rounded to the same.
          if not round_from_denormal then
            roundexc(EXC_UF)        := '1';
          end if;
        else
          if r.rddp = '0' then
            rounded.mant(53 downto 31) := uadd(rounded.mant(53 downto 31), 1);
          else
            rounded.mant(53 downto 2)  := uadd(rounded.mant(53 downto 2), 1);
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
    when 1 => addy := unsigned('0' & r.op2.mant(27 downto 0));
              addx := unsigned('0' & r.op1.mant(27 downto 0));
    when 2 => addy := unsigned'("00") & unsigned(r.op2.mant(54 downto 28));
              addx := unsigned'("00") & unsigned(r.op1.mant(54 downto 28));
    when 3 => addy := unsigned('0' & r.op2.mant(55 downto 28));
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
    v.opnormadj := find_normadj(normee, r.nalimdp = '1', r.nalimsp = '1', r.naeven = '1');

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
      fpu_event(evt, FPEVT_COMMIT);
      v.committed      := '1';
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
        v.rddp        := to_bit(issue_op.fmt /= "00");
        v.flop        := issue_op.op;
        v.mode        := mode_in;
        v.committed   := '0';
        v.exc         := (others => '0');
        v.acc         := (others => '0');
        v.acclo       := (others => '0');
        v.acclo0      := (others => '0');
        v.accbot      := (others => '0');
        v.inexact     := '0';
        v.fpu_holdn   := '1';
        v.muladd      := '0';
        if issue_cmd = '1' and holdn = '1' then
          v.id        := issue_id;
          v.last_unissued := false;
          v.last_valid    := true;
          fpu_event(evt, FPEVT_ISSUE);
          v.committed := commit;
          if issue_op.op = FPU_LOAD or issue_op.op = FPU_MV_W_X then
            v.s       := nf_load2;
          elsif issue_op.op = FPU_STORE then
            v.rs1     := issue_op.rs(2);
            v.ren     := issue_op.ren;
            v.s       := nf_flop0;
          elsif issue_op.op = FPU_CVT_S_W then
            v.rs2     := issue_op.rs(2);  -- Used for instruction disambiguation
            v.s       := nf_fromint;
          else
            v.rs1     := issue_op.rs(1);
            v.rs2     := issue_op.rs(2);
            v.rs3     := issue_op.rs(3);
            v.ren     := issue_op.ren;
            v.s       := nf_flopr;
          end if;
          -- The source is the other size for fcvt.s/d.d/s!
          if issue_op.op = FPU_CVT_S_D then
            v.rddp    := to_bit(issue_op.fmt = "00");
          end if;
          -- Some operations require the integer pipeline to wait on completion.
          if issue_op.op = FPU_STORE  or issue_op.op = FPU_CMP or
             issue_op.op = FPU_MV_X_W or issue_op.op = FPU_CVT_W_S then
            -- Commit will not happen for these!
            v.committed := '1';
            v.fpu_holdn := '0';
          end if;
        else
          -- Staying here!
          to_idle := true;
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
          when FPU_MADD | FPU_MSUB | FPU_NMSUB | FPU_NMADD =>
            v.ren             := "001";
            v.rs1             := r.rs3;
          when others =>
        end case;
        v.unpacksel           := 2;
        v.res2int             := r.s1;  -- For fmv.x.w
        v.res                 := r.s1;  -- For fsgn
        if r.rddp = '0' and r.flop /= FPU_SGN and r.flop /= FPU_MIN then
          v.res(63 downto 32) := (others => r.s1(31));
        end if;
        v.s                   := nf_flop1;

      when nf_flop1 =>
        v.op2           := unpacked;
        v.normadjsel    := 1;
        v.unpacksel     := 3;
        -- Unpack operands
        case r.flop is
          when FPU_STORE =>
            v.res2int             := r.s2;
            if r.rddp = '0' then
              v.res2int(63 downto 32) := r.s2(31 downto 0);
            end if;
            v.s                   := nf_store2;
          when FPU_MADD | FPU_MSUB | FPU_NMSUB | FPU_NMADD =>
            if no_muladd = 0 then
              v.muladd   := '1';
              v.s        := nf_muladd2;
            else
              to_idle    := true;
              v.s        := nf_idle;
            end if;
          when FPU_CMP =>
            v.s          := nf_cmp2;
          when FPU_MV_X_W =>
            v.s          := nf_mvxw2;
          when FPU_CVT_S_D =>        -- Also D_S
            -- Swap around for result!
            v.rddp       := not r.rddp;
            v.rddp_real  := v.rddp;
            if v.rddp = '0' then
              v.nalimsp  := '1';
            end if;
            v.op2        := r.op1;
            v.normadjsel := 2;
            v.s          := nf_sd2;
          when FPU_CVT_W_S =>
            v.op2       := r.op1;
            v.s         := nf_fstoi2;
          when FPU_SGN =>
            v.s         := nf_sgn2;
          when FPU_MIN =>
            v.s         := nf_min2;
          when FPU_ADD | FPU_SUB =>
            v.s         := nf_addsub2;
          when FPU_MUL =>
            v.s         := nf_mul2;
          when FPU_DIV =>
            v.res       := (others => '0');
            v.s         := nf_div2;
          when FPU_SQRT =>
            v.res       := (others => '0');
            v.op2       := r.op1;
            v.normadjsel := 2;
            v.s         := nf_sqrt2;
            v.naeven    := '1';
          when others =>
            to_idle     := true;
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
          v.s2      := r.s2;
          v.s       := nf_fitos2;
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
            v.s2 := uadd(not v.s2, 1);
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
           not ((v.rddp = '1' and r.flop = FPU_CVT_S_D) or
                (v.rddp = '1' and r.flop = FPU_CVT_S_W and (r.rs2 = R_FCVT_W or r.rs2 = R_FCVT_WU))) then
          v.s      := nf_round;
        end if;
        -- In case of integer to floating point conversions,
        -- check for any high bits that need to be added.
        if r.flop = FPU_CVT_S_W and not is_zero(r.op1) then
          v.flop   := FPU_ADD;
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
              v.res2int   := x"ffffffffffffffff";
            else
              if r.rs2(1) = '1' then   -- _L
                v.res2int := x"7fffffffffffffff";
              else
                v.res2int := x"000000007fffffff";
              end if;
            end if;
          else
            if r.rs2(0) = '1' then     -- _WU or _LU
              v.res2int   := x"0000000000000000";
            else
              if r.rs2(1) = '1' then   -- _L
                v.res2int := x"8000000000000000";
              else
                v.res2int := x"ffffffff80000000";
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
              -- No fraction. Integer part greater than maximum negative?
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
          end if;
        elsif is_zero(r.op2) then
          v.res2int       := (others => '0');
          v.s             := nf_end;
        elsif r.op2.neg and r.op2.exp >= 0 and r.rs2(0) = '1' then   -- _WU or _LU
          v.res2int       := zerow64;
          if r.op2.exp >= 0 then
            v.exc(EXC_NV) := '1';
            v.s           := nf_finish;
          else
            v.s           := nf_end;
          end if;
        else
          -- Calculate the amount to shift up to get an exponent of 2^64.
          --   This will place the high bits in the mantissa bits 53:42.
          v.expadj        := r.op1.exp - 64;
          v.opaction      := OPACT_SHFTA;
          v.s             := nf_fstoi25;
          v.adjustsel     := 1;
        end if;
        v.exc2int := v.exc;

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
        v.s         := nf_end;
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
            v.res2int(31 downto 0)   := std_logic_vector(-signed(r.op2.mant(33 downto 2)));
            roundchk                 := v.res2int(31);
            v.res2int(31 downto 0)   := std_logic_vector(signed(v.res2int(31 downto 0)) - roundadd);
            if roundadd = 1 and roundchk = '1' and v.res2int(31) = '0' then
              v.res2int(31 downto 0) := (others => '1');
              v.exc(EXC_NV    )      := '1';
              to_idle                := false;
              to_finish              := true;
              v.s                    := nf_finish;
            end if;
          else
            v.res2int(51 downto 0)   := r.op2.mant(53 downto 2);
            v.res2int(63 downto 52)  := r.op1.mant(53 downto 42);
            v.res2int            := std_logic_vector(-signed(v.res2int));
            roundchk             := v.res2int(63);
            v.res2int            := std_logic_vector(signed(v.res2int) - roundadd);
            if roundadd = 1 and roundchk = '1' and v.res2int(63) = '0' then
              v.res2int          := (others => '1');
              v.exc(EXC_NV)      := '1';
              to_idle            := false;
              to_finish          := true;
              v.s                := nf_finish;
            end if;
          end if;
        else
          -- _W or _WU?
          if r.rs2(1) = '0' then
            v.res2int(31 downto 0) := '0' & r.op2.mant(32 downto 2);
            -- _WU (known not to be _LU from just above)
            if r.rs2(0) = '1' then
              v.res2int(31)        := r.op2.mant(33);
            end if;
            roundchk               := v.res2int(31);
            v.res2int(31 downto 0)   := uadd(v.res2int(31 downto 0),  roundadd);
            -- When modified due to rounding, ensure that we do not
            -- get any overflow.
            if r.rs2(0) = '0' then   -- _W
              if roundadd = 1 and roundchk = '0' and v.res2int(31) = '1' then
                v.res2int(31 downto 0) := x"7fffffff";
                v.exc(EXC_NV)          := '1';
                to_idle                := false;
                to_finish              := true;
                v.s                    := nf_finish;
              end if;
            else                     -- _WU
              if roundadd = 1 and roundchk = '1' and v.res2int(31) = '0' then
                v.res2int(31 downto 0) := x"ffffffff";
                v.exc(EXC_NV)          := '1';
                to_idle                := false;
                to_finish              := true;
                v.s                    := nf_finish;
              end if;
            end if;
            v.res2int(63 downto 32)  := (others => '0');
          else
            v.res2int(51 downto 0)   := r.op2.mant(53 downto 2);
            v.res2int(63 downto 52)  := r.op1.mant(53 downto 42);
            roundchk                 := v.res2int(63);
            v.res2int                := uadd(v.res2int, roundadd);
            if roundadd = 1 and roundchk = '1' and v.res2int(31) = '0' then
              v.res2int              := (others => '1');
            end if;
          end if;
        end if;
        -- _W or _WU?
        if r.rs2(1) = '0' then
          v.res2int(63 downto 32) := (others => v.res2int(31));
        end if;
        -- _WU or _LU and negative actual result?
        if r.rs2(0) = '1' and r.op2.neg and v.res2int(63) = '1' then
          v.res2int           := (others => '0');
          v.exc(EXC_NV)       := '1';
          to_idle             := false;
          to_finish           := true;
          v.s                 := nf_finish;
        elsif v.exc(EXC_NV) = '0' and r.op2.mant(1 downto 0) /= "00" then
          v.exc(EXC_NX)       := '1';
          to_idle             := false;
          to_finish           := true;
          v.s                 := nf_finish;
        end if;
        if to_idle then
          v.now2int := '1';
        end if;
        v.exc2int := v.exc;

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
            when R_FSGNJ  => v.res(31) := sign; -- and not all_0(r.op2.w(30 downto 0));
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
              (r.flop = FPU_SUB xor r.op1.neg xor r.op2.neg) then
          -- inf - inf = NaN
          v.res         := defnan;
          v.s           := nf_opdone;
          v.exc(EXC_NV) := '1';
        elsif is_inf(r.op2) then
          v.s           := nf_repack;
          if r.flop = FPU_SUB then
            v.op2.neg   := not r.op2.neg;
          end if;
        elsif is_inf(r.op1) then
          v.s           := nf_repack;
          v.op2         := r.op1;
        elsif r.comphe = '1' and r.comple = '1' and
              (r.flop = FPU_SUB xor r.op1.neg xor r.op2.neg) then
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
          if r.flop = FPU_SUB then
            v.op2.neg  := not r.op2.neg;
          end if;
        else
          v.addneg      := '0';
          if r.flop = FPU_SUB xor r.op1.neg xor r.op2.neg then
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
        v.rddp      := r.rddp_real;
        -- Keep them different, to allow check in nf_round!
        v.rddp_real := r.rddp;
--        if r.rddp_real = '0' then
--          v.op2.mant(29) := to_bit(not all_0(v.op2.mant(29 downto 0)));
--          v.op2.mant(28 downto 0) := (others => '0');
--        end if;

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
        if extmul = 0 then
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
        else
          v.s := nf_mul5;
        end if;

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
        if extmul = 0 then
          -- Finish multiplier pipeline
          v.mulen                    := '0';
          v.shftpl2                  := '0';
          if r.accen = '0' then
            -- Copy result into op2
            -- Leading one could be in either bit 27 or 26 of accumulator.
            assert r.acc(29 downto 28) = "00";
            v.op2.mant(55 downto 28) := std_logic_vector(r.acc(27 downto 0));
            v.op2.mant(27 downto 0)  := std_logic_vector(r.acclo);
          end if;
        else
          if muldone = '1' then
            v.op2.mant := mulmant;
            v.accbot   := unsigned(mulbottom);
            v.acclo0   := unsigned(mullo0);
          end if;
        end if;
        if (extmul = 0 and r.accen = '0') or
           (extmul = 1 and muldone = '1') then
          -- Adjust exponent
          v.op2.exp                := r.op2.exp + r.op1.exp;
          v.s                      := nf_mul6;
          v.unpacksel              := 3;
          -- Do not limit exponent yet if doing muladd.
          if r.muladd = '0' then
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
        if no_muladd = 0 and r.muladd = '1' then
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
        vtmpadd     := usubx(r.op1.mant(27 downto 0), r.op2.mant(27 downto 0));
        divrem2     := vtmpadd;
        v.divcmp2   := '0';
        if all_0(vtmpadd) then
          v.divcmp2 := '1';
        end if;
        vtmpadd     := usubx(r.op1.mant(55 downto 28), r.op2.mant(55 downto 28));
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
          vtmpadd                    := usubx(divrem1(26 downto 0) & '0', r.op2.mant(55 downto 28));
        else
          assert r.op1.mant(55) = '0';
          v.op1.mant                 := r.op1.mant(54 downto 0) & '0';
          if r.divfirst = '1' then
            v.op2.exp                := r.op2.exp - 1;
          end if;
          vtmpadd                    := usub(r.op1.mant(55 downto 28) & '0', '0' & r.op2.mant(55 downto 28));
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
            v.expadj                 := r.op2.exp + 127;
            if r.op2.exp < -127 then
              v.s                    := nf_div6;
              v.opaction             := OPACT_SHFTA;
              v.adjustsel            := 2;
            end if;
          else
            v.op2.mant(55 downto 2)  := "01" & r.res(51 downto 0);
            v.op2.mant(1)            := v.res(0);
            v.expadj                 := r.op2.exp + 1023;
            if r.op2.exp < -1023 then
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
          vtmpadd     := usubx(r.acclo, r.op2.mant(27 downto 0));
          divrem2     := vtmpadd;
          -- Exact match for low bits?
          v.divcmp2   := '0';
          if all_0(vtmpadd) then
            v.divcmp2 := '1';
          end if;
          vtmpadd     := usubx(r.acc(27 downto 0), r.op2.mant(55 downto 28));
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
         -- Low bits in extended muladd shifted out?
        if r.inexact = '1' then
          v.exc(EXC_NX) := '1';
        end if;
        v.s      := nf_repack;
        -- Too small numbers can be the result of muladd sp as dp.
        if no_muladd = 0 and r.muladd = '1' and r.rddp /= r.rddp_real and
           is_normal(r.op2) and r.op2.exp < -126 then
          -- Do not go another loop here - so mark these equal!
          v.rddp_real := r.rddp;
          -- Restore unrounded value and flags
          v.op2       := r.op2;
          v.exc       := r.exc;
          -- Adjust to denormal
          v.expadj    := r.op2.exp + 127;
          v.adjustsel := 2;
          v.opaction  := OPACT_SHFTAS;
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
          v.res            := pack(r.op2, r.rddp = '1');
          if r.exc(EXC_UF) = '1' and is_zero(r.op2) and
            ((r.rm = R_PLUS_INF  and not r.op2.neg) or
             (r.rm = R_MINUS_INF and r.op2.neg)) then
            v.res(0)       := '1';
          end if;
          -- Some operations do not produce UF exceptions on denormals.
          if r.flop = FPU_SGN then
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
          -- Assume R_FMIN
          if (is_zero(r.op1) and is_zero(r.op2)) or is_inf(r.op1) then
            use_fs2      := not r.op1.neg;
          elsif is_inf(r.op2) then
            use_fs2      := r.op2.neg;
          else
            use_fs2      := fcc /= "01";
          end if;
          -- Conditions are opposite for R_FMAX
          if use_fs2 xor (r.rmb = R_FMAX) then
            v.res        := r.s2;
          end if;
        end if;
        v.s              := nf_opdone;

      when nf_store2 =>
        v.s         := nf_end;

      when nf_cmp2 =>
        -- R_FEQ is a quiet comparison (not NV for non-signalling NaN).
        if (is_signan(r.op1) or is_signan(r.op2) or
            (r.rmb /= R_FEQ and (is_nan(r.op1) or is_nan(r.op2)))) then
          v.exc(EXC_NV)  := '1';
        end if;
        v.res2int        := (others => '0');
        -- Result is always 0 when one input is NaN.
        if not (is_nan(r.op1) or is_nan(r.op2)) then
          -- Check all comparison operations.
          if (r.rmb = R_FEQ and fcc  = "00") or
             (r.rmb = R_FLT and fcc  = "01") or
             (r.rmb = R_FLE and fcc /= "10") then
            v.res2int(0) := '1';
          end if;
        end if;
        v.exc2int        := v.exc;
        v.s              := nf_finish;

      when nf_mvxw2 =>
        -- This is always the rm field in the instruction here.
        if r.rmb = R_CLASS then
          v.res2int          := (others => '0');
          --  Exponent all 1 - infinity (frac 0) or NaN
          if is_nan(r.op1) then
            v.res2int(9)     := to_bit(not is_signan(r.op1));      -- Quiet NaN
            v.res2int(8)     := to_bit(is_signan(r.op1));
          else
            if is_inf(r.op1) then
              n              := 0;
            elsif is_zero(r.op1) then
              n              := 3;
            elsif r.op1.mant(54) = '0' then
              n              := 2;   -- Denormal
            else
              n              := 1;   -- Normal
            end if;
            v.res2int(n)     := to_bit(r.op1.neg);
            v.res2int(7 - n) := not to_bit(r.op1.neg);
          end if;
        elsif r.rmb = "000" then   -- fmv.x.w/d
          -- v.res2int already contains the incoming rs1 value.
          if r.rddp = '0' then
            -- Extend sign bit when moving 32 bit float.
            v.res2int(63 downto 32) := (others => r.res2int(31));
          end if;
        end if;
        v.exc2int        := v.exc;
        v.s              := nf_finish;

      -- When doing integer returns, flags are passed along,
      -- not written via flags_wen.
      -- Make sure we have a cycle with flags but still asserted fpu_holdn.
      when nf_finish =>
        v.exc2int     := r.exc2int;
        v.now2int   := '1';
        v.fpu_holdn := '1';
        to_idle     := true;
        v.s         := nf_idle;

      -- Done, but return to nf_idle before instruction actually
      -- commits runs the risk of mixup with the next instruction.
      when nf_end =>
        v.fpu_holdn := '1';
        v.exc2int   :=  r.exc2int;
        v.now2int := '1';
        to_idle   := true;
        v.s       := nf_idle;

      -- Finish and write back result when committed
      when nf_opdone =>
        if (commit = '1' and holdn = '1') or r.committed = '1' then
          v.wen       := '1';
          v.flags_wen := '1';
          v.s         := nf_rdwrite;
        end if;

      when nf_rdwrite =>
        v.s         := nf_rdwrite2;

      when nf_rdwrite2 =>
        v.fpu_holdn := '1';
        to_idle     := true;
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
        elsif ((r.flop = FPU_MADD or r.flop = FPU_NMADD) and add_illegal(inf_1x2, unpacked))          or
              ((r.flop = FPU_MSUB or r.flop = FPU_NMSUB) and add_illegal(inf_1x2, inf_neg(unpacked))) then
          v.exc(EXC_NV)  := '1';
          v.res          := defnan;
          v.s            := nf_opdone;
        elsif is_inf(r.op1) or is_inf(r.op2) or is_inf(unpacked) then
          v.op2.class    := C_INF;
          v.op2.neg      := false;
          if is_inf(r.op1) or is_inf(r.op2) then
            v.op2.neg    := inf_1x2.neg;
          elsif ((r.flop = FPU_MADD or r.flop = FPU_NMADD) and unpacked.neg)     or
                ((r.flop = FPU_MSUB or r.flop = FPU_NMSUB) and not unpacked.neg) then
            v.op2.neg    := true;
          end if;
          -- These are the opposites of FPU_MADD/SUB
          if r.flop = FPU_NMADD or r.flop = FPU_NMSUB then
            v.op2.neg    := not v.op2.neg;
          end if;
          v.s            := nf_repack;
        elsif is_zero(r.op1) or is_zero(r.op2) then   -- No multiply?
          v.op2          := unpacked;
          if is_zero(unpacked) then
            v.op2.neg    := r.op1.neg xor r.op2.neg;
            if r.flop = FPU_NMADD or r.flop = FPU_NMSUB then
              v.op2.neg  := not v.op2.neg;
            end if;
            if ((r.flop = FPU_MADD  or r.flop = FPU_NMSUB) and v.op2.neg /= unpacked.neg) or
               ((r.flop = FPU_NMADD or r.flop = FPU_MSUB)  and v.op2.neg  = unpacked.neg) then
              v.op2.neg  := r.rm = R_MINUS_INF;
            end if;
          else
            if r.flop = FPU_MSUB or r.flop = FPU_NMADD then
              v.op2.neg  := not v.op2.neg;
            end if;
          end if;
          v.s            := nf_repack;
        else
          -- On next cycle, re-normalize number in case of denormal input.
          v.adjustsel    := 1;
          v.opaction     := OPACT_SHFTN;
          -- Handle all as fmadd
          v.flop         := FPU_MADD;
          -- All negations handled here
          v.op2.neg      := r.op1.neg xor r.op2.neg;
          if r.flop = FPU_NMADD or r.flop = FPU_NMSUB then
            v.op2.neg    := not v.op2.neg;
          end if;
          if r.flop = FPU_NMADD or r.flop = FPU_MSUB then
            v.op3neg     := not unpacked.neg;
          end if;
          -- If no add, handle as mul.
          if is_zero(unpacked) then
            v.flop       := FPU_MUL;
            v.muladd     := '0';
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
        if unsigned(v.op1.mant) < unsigned(r.op2.mant) then
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
        v.flop := FPU_ADD;
        to_addsub := true;
        v.s    := nf_addsub2;
        -- When double precision, special handling is needed if
        -- op2 (multiplication result) is larger and has low bits
        -- Extra work might be needed for double if result of multiply has low bits,
        -- since some of the higher ones may cancel out.
        -- This code must _not_ be used when op2low (ie no extended result),
        -- since the handling of zero result will then fail!
        if r.rddp_real = '1' and not op2low0 then
          -- Addend same or smaller magnitude?
          if v.comphl = '1' or v.comphe = '1' then
            to_addsub := false;
            v.s  := nf_muladd_xadd;
          end if;
          -- Subtract can cancel bits even if exponent is one less.
          if v.op1.neg /= r.op2.neg then
            if v.op1.exp = r.op2.exp - 1 then
              to_addsub := false;
              v.s  := nf_muladd_xadd;
            end if;
            if v.op1.exp = r.op2.exp + 1 then
              to_addsub := false;
              v.s  := nf_muladd_xadd;
            end if;
            to_addsub := false;
            v.s  := nf_muladd_xadd;
          end if;
        end if;
        if to_addsub then
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
        -- Clear low part of op1
        v.s1 := (others => '0');
        -- Make sure the bigger argument in terms of magnitude is in op1.
        -- If we swap and subtract then we need to flip the signs.
        v.expadj      := r.op2.exp - r.op1.exp;
        v.swap      := '0';
        v.inexact   := '0';
        if r.comphl = '1' or (r.comphe = '1' and r.compll = '1') then
          -- Swap needed
          v.swap      := '1';
          v.expadj    := r.op1.exp - r.op2.exp;
          v.op1       := r.op2;
          v.op2       := r.op1;
          -- Flip result sign if doing subtract
          if v.addneg = '1' then
            v.op2.neg := not r.op1.neg;
          end if;
          v.accbot    := (others => '0');
          v.s1(r.accbot'range) := std_logic_vector(r.accbot);
        else
          -- No swap needed abs(op1) > abs(op2)
          -- This means that the lower part of op2 is irrelevant,
          -- since op1 has no extended mantissa, except for the
          -- presence of 1-bits on subtract.
          -- No need to shift low part of op2!
          -- Result is negative if first operand is.
          v.op2.neg   := r.op1.neg;
          if not all_0(r.accbot) then
            v.inexact := '1';
          end if;
        end if;
        v.opaction    := OPACT_SHFTA;
        -- If it will use the subtract operation then we shift up both args by 1.
        --   This is to ensure there are enough guard digits.
        if v.addneg = '1' then
          -- Do the up-shift explicitly here, to avoid issues with bit handling.
          if v.swap = '0' then
            v.op1.exp   := r.op1.exp - 1;
            v.op1.mant  := r.op1.mant(r.op1.mant'high - 1 downto 0) & '0';
            v.op2.exp   := r.op2.exp - 1;
            v.op2.mant  := r.op2.mant(r.op1.mant'high - 1 downto 0) & std_logic(get_hi(r.accbot));
            v.accbot    := r.accbot(r.accbot'high - 1 downto 0) & '0';
          else
            v.op1.exp   := r.op2.exp - 1;
            v.op1.mant  := r.op2.mant(r.op2.mant'high - 1 downto 0) & std_logic(get_hi(r.accbot));
            v.s1(r.accbot'range) := std_logic_vector(r.accbot(r.accbot'high - 1 downto 0) & '0');
            v.op2.exp   := r.op1.exp - 1;
            v.op2.mant  := r.op1.mant(r.op2.mant'high - 1 downto 0) & '0';
          end if;
        end if;
        v.adjustsel   := 2;
        -- When abs(v.expadj) is less than the mantissa length,
        -- this will be a left shit for bits to use in the bottom half,
        -- with a later right (original v.expadj) shift for the top half.
        -- When abs(v.expadj) is larger than the mantissa length,
        -- this is a right shift for bits to use in the bottom half,
        -- and the top half will later be cleared.
        v.expadj := v.expadj + (r.op2.mant'length - 4);
          v.s    := nf_muladd_xadd25;


      when nf_muladd_xadd25 =>
        v.s2         := (others => '0');
        v.s2(adjusted.mant'range) := adjusted.mant;
        -- Copy actual bit over what is now sticky bit.
        v.s2(0)  := adjusted_mant0b(0);
        v.inexact := adjusted_mant0b(1);
        -- The top bit will be in next to last in original.
        v.s2(adjusted.mant'high)  := '0';
        v.expadj     := r.expadj - (r.op2.mant'length - 4);
        v.opaction   := OPACT_SHFTA;
        v.s          := nf_muladd_xadd26;
        v.adjustsel  := 2;

      when nf_muladd_xadd26 =>
        v.op2     := adjusted;
        v.op2.neg := r.op2.neg;
        -- Copy actual bit over what is now sticky bit.
        v.op2.mant(0) := adjusted_mant0b(0);

        -- Temporarily save high bits
        v.s3(v.op2.mant'range) := v.op2.mant;
        -- Take care of low bits
        v.op2.mant := (others => '0');
        v.op2.mant(r.accbot'range) := std_logic_vector(r.accbot);
        v.opaction   := OPACT_SHFTA;
        v.adjustsel := 2;
        v.s   := nf_muladd_xadd27;

      when nf_muladd_xadd27 =>
        -- There is no overlap, so OR bits.
        v.s2(r.accbot'range)      := r.s2(r.accbot'range) or
                                     (adjusted.mant(r.accbot'high downto 1) & adjusted_mant0b(0));
        v.inexact  := r.inexact or adjusted_mant0b(1);
        -- Restore saved high bits
        v.op2.mant := r.s3(v.op2.mant'range);
        v.s        := nf_muladd_xaddsub3;


      when nf_muladd_xaddsub3 =>
        -- Magnitude of result is the large one
        v.op2.exp    := v.op1.exp;
        if r.addneg = '0' then
          xtmpaddx := uaddx(r.s1(r.accbot'range), r.s2(r.accbot'range));
        else
          xtmpaddx := usubx(r.s1(r.accbot'range), r.s2(r.accbot'range));
          if r.inexact = '1' then
            xtmpaddx := xtmpaddx - 1;
          end if;
        end if;
        v.carry              := get_hi(xtmpaddx);
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
          if not all_0(r.s2(r.accbot'high + 2 downto 0)) then
            -- Bring up low bits
            v.op2.mant := "00" & r.s2(r.accbot'high + 2 downto 0);
            v.op2.exp  := r.op2.exp - r.accbot'length;
            v.s2       := (others => '0');
          else
            v.op2.class := C_ZERO;
            v.s := nf_round;
          end if;
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
          v.op2.mant(0) := v.op2.mant(0) or not all_0(r.s2(r.accbot'high + 1 downto 0));
        else
          v.op2.mant(0) := v.op2.mant(0) or not all_0(r.s2(r.accbot'high + 2 downto 0));
        end if;
        -- If we had an add, any out-shifted bits must go into sticky.
        if r.addneg = '0' then
          v.op2.mant(0) := v.op2.mant(0) or r.inexact;
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
        -- If we had an add, any out-shifted bits must go into sticky.
        if r.addneg = '0' then
          v.op2.mant(0) := v.op2.mant(0) or r.inexact;
        end if;
        -- Adjust so that the implicit 1 is at the expected position.
        v.s         := nf_round;

      when others => null;
    end case;
  else
    to_idle := true;
    v.s := nf_idle;
  end if;
    end case;


    if unissue = '1' and holdn = '1' and v.id = unissue_id then
      fpu_event(evt, FPEVT_UNISSUE_1ST);
      to_idle     := true;
      v.s         := nf_idle;
      v.fpu_holdn := '1';
      v.wen       := '0';
      v.flags_wen := '0';
      v.last_unissued := true;
    end if;

    -- Generate flow control flags
    v.readyflop   := '0';
    is_idle       := '0';
    -- Always when going to idle, but less logic.
    if to_idle then
      v.readyflop := '1';
      is_idle     := '1';
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


    v.events_pipe := r.events;
    v.events      := evt;

  -- Signal assignments

    rin          <= v;
    ready_flop   <= v.readyflop;
    fpu_holdn    <= v.fpu_holdn;
    idle         <= is_idle;
    rd           <= r.rd;
    wen          <= r.wen;
    if notx(v.res) then
      stdata     <= v.res;
    else
      stdata     <= r.res;
      for i in stdata'range loop
        if r.res(i) /= '0' and r.res(i) /= '1' then 
          stdata(i) <= '0';
        end if;
      end loop;
    end if;
    flags_wen    <= r.flags_wen;
    flags        <= r.exc;
    now2int      <= v.now2int;
    id2int       <= r.id;
    if notx(r.res2int) then
      stdata2int <= r.res2int;
    else
      stdata2int <= (others => '0');
    end if;
    flags2int    <= r.exc2int;
    wb_mode      <= r.mode;
    wb_id        <= r.id;

    rs1          <= v.rs1;
    rs2          <= v.rs2;
    rs3          <= v.rs3;
    ren          <= (v.ren(1) or v.ren(2) or v.ren(3)) & "00";

    if extmul = 1 then
      mulsrc     <= adjusted.mant;
      multiply   <= to_bit(r.s = nf_mul3);
      mulrddp    <= r.rddp;
    end if;

    events       <= uext(r.events_pipe, events'length);


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
