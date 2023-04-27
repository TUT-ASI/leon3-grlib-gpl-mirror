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
-- Entity:      nanofpu
-- File:        nanofpu.vhd
-- Author:      Magnus Hjorth, Cobham Gaisler
-- Description: Minimal bare bones FPC and FPU for LEON5
------------------------------------------------------------------------------

-- This is a minimal non-pipelined IEEE754 compliant implementation
-- of an FPC and FPU using the GRFPC5 interface in order to always provide
-- hardware FPU operations on LEON5.
--
-- The FPC implements deferred floating-point traps with a DFQ length of 1.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use grlib.sparc.all;
use grlib.config.all;
use grlib.config_types.all;

entity nanofpu is
  port (
    clk           : in std_ulogic;
    rstn          : in std_ulogic;
    -- Pipeline interface
    --   Issue interface
    ready_flop    : out std_ulogic;
    ready_ld      : out std_logic_vector(0 to 35);
    ready_st      : out std_logic_vector(0 to 35);
    trapon_flop   : out std_ulogic;
    trapon_ldst   : out std_ulogic;
    trapon_stdfq  : out std_ulogic;
    issue_cmd     : in std_logic_vector(2 downto 0);
    issue_ldstreg : in std_logic_vector(5 downto 0);
    issue_ldstdp  : in std_ulogic;
    issue_op3_0   : in std_ulogic;
    issue_flop    : in std_logic_vector(8 downto 0);
    issue_rd      : in std_logic_vector(4 downto 0);
    issue_rs1     : in std_logic_vector(4 downto 0);
    issue_rs2     : in std_logic_vector(4 downto 0);
    issue_dfqdata : in std_logic_vector(63 downto 0);
    issue_id      : out std_logic_vector(4 downto 0);
    --   Commit interface
    commit        : in std_ulogic;
    commitid      : in std_logic_vector(4 downto 0);
    lddata        : in std_logic_vector(63 downto 0);
    --   Store data interface
    stdata        : out std_logic_vector(63 downto 0);
    --   Mispredict/trap interface
    unissue       : in std_ulogic;
    unissue_sid   : in std_logic_vector(4 downto 0);
    --   Special store handling (for side effects)
    spstore_pend  : in std_ulogic;
    spstore_done  : in std_ulogic;
    --   Floating-point condition codes
    fccready      : out std_ulogic;
    fcc           : out std_logic_vector(1 downto 0);
    fpcidle       : out std_ulogic;
    -- Control/Debug interface
    mosi_accen    : in  std_ulogic;
    mosi_addr     : in  std_logic_vector(5 downto 0);
    mosi_accwr    : in  std_ulogic;
    mosi_wrdata   : in  std_logic_vector(31 downto 0);
    miso_accrdy   : out std_ulogic;
    miso_rddata   : out std_logic_vector(31 downto 0);
    -- Legacy debug
    dbgfsr        : out std_logic_vector(31 downto 0)  -- FSR value
    );
end;

architecture rtl of nanofpu is

  constant FPUVER : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(5,3));

  type nanofpu_state is (nf_idle, nf_load, nf_flop1, nf_fitos2,
                         nf_fitos3, nf_fstoi2, nf_fstoi3, nf_fstoi4,
                         nf_mov2, nf_addsub2, nf_addsub3, nf_add4,
                         nf_add5, nf_sub4, nf_sub5, nf_addsub6,
                         nf_addsub7, nf_mul2, nf_mul3, nf_mul4,
                         nf_mul5, nf_mul6, nf_mul7, nf_div2,
                         nf_div3, nf_div4, nf_div5, nf_div6,
                         nf_sqrt2,
                         nf_sqrt3, nf_sqrt4, nf_sqrt5, nf_sqrt6,
                         nf_sqrt7, nf_sqrt8, nf_sqrt9, nf_sqrt10,
                         nf_sqrt11, nf_round, nf_repack, nf_opdone,
                         nf_fcmp2, nf_pendexc, nf_dfq1, nf_dfq2,
                         nf_dbgacc1);

  type nanofpu_regfile is array(0 to 15) of std_logic_vector(63 downto 0);

  -- Operand can be in different "states":
  --   invalid - Values are undefined
  --   pack1   - exponent is bounded within valid range, leading one at bit 54
  --               except for denormal numbers, mantissa valid also for zero/inf
  --             (output of the unpack function)
  --   pack2   - same as norm1 but mant part undefined (assumed==0) for
  --             zero/inf classes
  --             (valid input to pack function)
  --   norm    - leading 1 shifted to bit 54 also for denormal numbers,
  --             exp may be outside valid range
  --             cls ignored, assumed non-zero normal number
  --   norm2   - leading 1 in unknown position
  --             mantissa may also be all-0 if zero
  --             cls ignored (assumed 00 or 01 depending on mant)
  type nanofpu_operand is record
    -- number class 00=normal, 01=zero, 10=nan 11=inf
    cls: std_logic_vector(1 downto 0);
    sgn: std_ulogic;
    exp: signed(12 downto 0);
    -- Normally implicit 1 at bit 54
    --  53:2 mantissa bits    53:31 for SP
    --   1:0 guard bits for rounding
    mant: std_logic_vector(55 downto 0);
  end record;
  constant nanofpu_operand_none: nanofpu_operand :=
    ("00",'0',(others => '0'),(others => '0'));

  subtype op_action is std_logic_vector(2 downto 0);
  constant OPACT_NONE   : op_action := "000";  -- no action
  constant OPACT_UNPACK : op_action := "001";  -- unpack from rs1/rs2
  constant OPACT_ROUND  : op_action := "010";  -- Round (op2 only)
  constant OPACT_RSV2   : op_action := "011";
  constant OPACT_SHFTN  : op_action := "100";  -- shift exp by amount in op*normadj
  constant OPACT_SHFTA  : op_action := "101";  -- shift exp by amount in expadj
  constant OPACT_SHFTNS   : op_action := "110";
  constant OPACT_SHFTAS : op_action := "111";  -- shift exp by amount in expadj, place guard at bit 29

  constant EXC_NX       : integer := 0;
  constant EXC_DZ       : integer := 1;
  constant EXC_UF       : integer := 2;
  constant EXC_OF       : integer := 3;
  constant EXC_NV       : integer := 4;

  constant defnan_dp    : std_logic_vector(63 downto 0) := x"7fffe00000000000";
  constant defnan_sp    : std_logic_vector(63 downto 0) := x"7fff00007fff0000";

  type nanofpu_regs is record
    -- state
    s           : nanofpu_state;
    readyflop   : std_ulogic;
    readyldst   : std_ulogic;
    fccready    : std_ulogic;
    trapstdfq   : std_ulogic;
    trapflop    : std_ulogic;
    trapldst    : std_ulogic;
    stfsr       : std_ulogic;
    -- register file
    rf          : nanofpu_regfile;
    -- fsr fields
    fpurndmode  : std_logic_vector(1 downto 0);
    cexc        : std_logic_vector(4 downto 0);
    aexc        : std_logic_vector(4 downto 0);
    tem         : std_logic_vector(4 downto 0);
    fsr_nonstd  : std_ulogic;
    fsr_ftt     : std_logic_vector(2 downto 0);
    fcc         : std_logic_vector(1 downto 0);
    -- current operation
    dfqdata     : std_logic_vector(63 downto 0);
    rs1         : std_logic_vector(4 downto 0);
    rs2         : std_logic_vector(4 downto 0);
    rd          : std_logic_vector(4 downto 0);
    res         : std_logic_vector(63 downto 0);
    exc         : std_logic_vector(4 downto 0);
    rdspec      : std_ulogic;
    rddp        : std_ulogic;
    flop        : std_logic_vector(8 downto 0);
    committed   : std_ulogic;
    op1         : nanofpu_operand;
    op2         : nanofpu_operand;
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
    -- divider registers
    divfirst    : std_ulogic;
    divrem1     : unsigned(28 downto 0);
    divrem2     : unsigned(28 downto 0);
    divcmp1     : std_ulogic;
    divcmp11    : std_ulogic;
    divcmp2     : std_ulogic;
    divremz     : std_ulogic;
    -- issue id for debug purposes
    -- issueid: std_logic_vector(4 downto 0);
    miso_accrdy : std_ulogic;
  end record;

  constant RRES: nanofpu_regs := (
    s           => nf_idle,
    readyflop   => '0',
    readyldst   => '0',
    fccready    => '0',
    trapstdfq   => '0',
    trapflop    => '0',
    trapldst    => '0',
    stfsr       => '0',
    rf          => (others => (others => '0')),
    fpurndmode  => "00",
    cexc        => "00000",
    aexc        => "00000",
    tem         => "00000",
    fsr_nonstd  => '0',
    fsr_ftt     => "000",
    fcc         => "00",
    dfqdata     => (others => '0'),
    rs1         => "00000",
    rs2         => "00000",
    rd          => "00000",
    res         => (others => '0'),
    exc         => "00000",
    rdspec      => '0',
    rddp        => '0',
    flop        => (others => '0'),
    committed   => '0',
    op1         => nanofpu_operand_none,
    op2         => nanofpu_operand_none,
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
    divremz     => '0',
    miso_accrdy => '0'
    );

  signal r,nr: nanofpu_regs;

begin

  comb: process(r,rstn,
                issue_cmd,issue_ldstreg,issue_ldstdp,issue_op3_0,issue_flop,
                issue_rd,issue_rs1,issue_rs2,issue_dfqdata,
                commit,commitid,lddata,unissue,unissue_sid,spstore_pend,spstore_done,
                mosi_accen,mosi_addr,mosi_accwr,mosi_wrdata)
    variable v: nanofpu_regs;
    variable ostdata: std_logic_vector(63 downto 0);
    variable vrs1, vrs2: std_logic_vector(63 downto 0);
    variable vrs1sp, vrs2sp, vrs2int: std_ulogic;
    variable vtmpadd: unsigned(28 downto 0);
    variable vtmpexp: signed(12 downto 0);
    variable vadj: signed(6 downto 0);
    variable vgrd: std_ulogic;
    variable vrndbits: std_logic_vector(2 downto 0);
    variable vrndup: std_ulogic;
    variable vswap: std_ulogic;
    variable vop: nanofpu_operand;

    function gen_fsr(r: nanofpu_regs) return std_logic_vector is
      variable fsr: std_logic_vector(31 downto 0);
    begin
      fsr := (others => '0');
      fsr(31 downto 30) := r.fpurndmode;
      fsr(27 downto 23) := r.tem;
      fsr(22) := r.fsr_nonstd;
      fsr(19 downto 17) := FPUVER;
      fsr(16 downto 14) := r.fsr_ftt;
      fsr(13) := not r.trapstdfq; -- qne
      fsr(11 downto 10) := r.fcc;
      fsr(9 downto 5) := r.aexc;
      fsr(4 downto 0) := r.cexc(4 downto 0);
      return fsr;
    end gen_fsr;

    procedure set_fsr(w: std_logic_vector(31 downto 0)) is
    begin
      v.fpurndmode := w(31 downto 30);
      v.tem := w(27 downto 23);
      v.fsr_nonstd := w(22);
      -- v.fsr_ftt := w(16 downto 14);
      v.fcc := w(11 downto 10);
      v.aexc := w(9 downto 5);
      v.cexc := w(4 downto 0);
    end set_fsr;

    function decode_rs1_sp(flop: std_logic_vector(8 downto 0)) return std_ulogic is
    begin
      return not flop(1);
    end decode_rs1_sp;

    function decode_rs2_sp(flop: std_logic_vector(8 downto 0)) return std_ulogic is
    begin
      return not flop(1);
    end decode_rs2_sp;

    function decode_rs2_int(flop: std_logic_vector(8 downto 0)) return std_ulogic is
    begin
      if flop(1 downto 0)="00" then return '1'; else return '0'; end if;
    end decode_rs2_int;

    function decode_rd_sp(flop: std_logic_vector(8 downto 0)) return std_ulogic is
    begin
      if (flop(7)='1' and flop(3)='0') or (flop(7)='0' and flop(1)='0' and flop(6 downto 5)/="11") then
        return '1';
      end if;
      return '0';
    end decode_rd_sp;

    function find_normadj(op: nanofpu_operand; limdp: std_ulogic; limsp: std_ulogic;
                          mkeven: std_ulogic) return signed is
      variable r:  signed(6 downto 0);
      variable adjtmp: signed(12 downto 0);
      variable maxadj: signed(6 downto 0);
    begin
      maxadj := "0111111";
      if limdp='1' then
        adjtmp := op.exp+1022;
        if adjtmp(12 downto 6)="0000000" or adjtmp(12 downto 6)="1111111" then
          maxadj := adjtmp(6 downto 0);
        end if;
      end if;
      if limsp='1' then
        adjtmp := op.exp+126;
        if adjtmp(12 downto 6)="0000000" or adjtmp(12 downto 6)="1111111" then
          maxadj := adjtmp(6 downto 0);
        end if;
      end if;
      r := "0000000";
      for x in 2 to 55 loop
        if op.mant(x)='1' then
          r := to_signed(54-x, 7);
        end if;
      end loop;
      if mkeven='1' then
        if (r(0) xor op.exp(0))='1' then
          r := r+1;
        end if;
      elsif r > maxadj then r:=maxadj; end if;
      return r;
    end find_normadj;

    function unpack(opu: std_logic_vector(63 downto 0); sp: std_ulogic; int: std_ulogic) return nanofpu_operand is
      variable r: nanofpu_operand;
    begin
      r := (cls => "00", sgn => opu(63), exp => "0000000000000", mant => "01" & opu(51 downto 0) & "00");
      if int='1' then
        r.exp := to_signed(31, 13);
        if r.sgn='1' then
          r.mant(54 downto 23) := std_logic_vector(unsigned('0' & not(opu(62 downto 32)))+1);
        else
          r.mant(54 downto 23) := '0' & opu(62 downto 32);
        end if;
        if opu(63 downto 32)=x"00000000" then r.cls(0) := '1'; end if;
      elsif sp='1' then
        r.exp := signed(sub(std_logic_vector'("00000" & opu(62 downto 55)),127));
        r.mant(53 downto 31) := opu(54 downto 32);
        if opu(62 downto 55)="00000000" then
          r.exp := to_signed(-126,13);
          r.mant(54) := '0';
        end if;
        if opu(62 downto 55)="11111111" then
          r.cls(1) := '1';
          r.mant(54) := '0';
        end if;
        if opu(54 downto 32)="00000000000000000000000" and r.mant(54)='0' then
          r.cls(0) := '1';
        end if;
      else
        r.exp := signed(sub(std_logic_vector'("00" & opu(62 downto 52)),1023));
        if opu(62 downto 52)="00000000000" then
          r.exp := to_signed(-1022,13);
          r.mant(54) := '0';
        end if;
        if opu(62 downto 52)="11111111111" then
          r.cls(1) := '1';
          r.mant(54) := '0';
        end if;
        if opu(51 downto 0)="0000000000000000000000000000000000000000000000000000" and r.mant(54)='0' then
          r.cls(0) := '1';
        end if;
      end if;
      return r;
    end unpack;

    function pack(op: nanofpu_operand; sp: std_ulogic) return std_logic_vector is
      variable r: std_logic_vector(63 downto 0);
    begin
      r := (others => '0');
      r(63) := op.sgn;
      r(51 downto 0) := op.mant(53 downto 2);
      if sp='0' then
        assert (op.exp > -1023 and op.exp < 1024) or op.cls/="00";
        r(62 downto 52) := std_logic_vector(op.exp(10 downto 0)+1023);
        if op.exp=-1022 then
          r(52):=op.mant(54);
        end if;
        if op.cls(1)='1' then
          r(62 downto 52) := "11111111111";
        elsif op.cls="01" then
          r(62 downto 52) := "00000000000";
        end if;
        if op.cls(0)='1' then
          r(51 downto 0) := "0000000000000000000000000000000000000000000000000000";
        end if;
      else
        assert (op.exp > -127 and op.exp < 128) or op.cls/="00";
        r(62 downto 55) := std_logic_vector(op.exp(7 downto 0)+127);
        if op.exp=-126 then
          r(55) := op.mant(54);
        end if;
        if op.cls(1)='1' then
          r(62 downto 55) := "11111111";
        elsif op.cls="01" then
          r(62 downto 55) := "00000000";
        end if;
        r(54 downto 32) := op.mant(53 downto 31);
        if op.cls(0)='1' then
          r(54 downto 32) := "00000000000000000000000";
        end if;
        r(31 downto 0) := r(63 downto 32);
      end if;
      return r;
    end pack;

    function is_signan(op: nanofpu_operand) return std_ulogic is
    begin
      if op.cls="10" and op.mant(53)='0' then return '1'; else return '0'; end if;
    end is_signan;

  begin
    v := r;
    -- STDATA data path
    ostdata := (others => '0');
    if notx(r.rd) then
      ostdata := r.rf(to_integer(unsigned(r.rd(4 downto 1))));
    else
      setx(ostdata);
    end if;
    if r.rddp='0' then
      if r.rd(0)='0' then
        ostdata(31 downto 0) := ostdata(63 downto 32);
      else
        ostdata(63 downto 32) := ostdata(31 downto 0);
      end if;
    end if;
    if r.rdspec='1' then
      if r.rd(1)='0' then
        ostdata := gen_fsr(r) & gen_fsr(r);
      else
        ostdata := r.dfqdata;
      end if;
    end if;
    -- RS1/RS2 data path
    vrs1 := (others => '0');
    vrs2 := (others => '0');
    if notx(r.rs1) then
      vrs1 := r.rf(to_integer(unsigned(r.rs1(4 downto 1))));
    else
      setx(vrs1);
    end if;
    if notx(r.rs2) then
      vrs2 := r.rf(to_integer(unsigned(r.rs2(4 downto 1))));
    else
      setx(vrs2);
    end if;
    vrs1sp := decode_rs1_sp(r.flop);
    vrs2sp := decode_rs2_sp(r.flop);
    vrs2int := decode_rs2_int(r.flop);
    if vrs1sp='1' then
      if r.rs1(0)='1' then
        vrs1(63 downto 32) := vrs1(31 downto 0);
      end if;
      vrs1(31 downto 0) := (others => '0');
    end if;
    if vrs2sp='1' then
      if r.rs2(0)='1' then
        vrs2(63 downto 32) := vrs2(31 downto 0);
      end if;
      vrs2(31 downto 0) := (others => '0');
    end if;
    -- Compare resource on RS1/RS2
    v.comphl := '0';
    v.comphe := '0';
    v.compll := '0';
    v.comple := '0';
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
    -- Re-normalization logic for r.op1.mant, r.op2.mant
    case r.op1action is
      when OPACT_UNPACK =>
        v.op1 := unpack(vrs1, vrs1sp, '0');
      when OPACT_SHFTN | OPACT_SHFTA | OPACT_SHFTAS | OPACT_SHFTNS =>
        case r.op1action is
          when OPACT_SHFTN | OPACT_SHFTNS =>
            vadj := r.op1normadj;
          when others =>
            vadj := r.expadj1(6 downto 0);
            if r.expadj1(12)='1' and r.expadj1(12 downto 6) /= "1111111" then
              vadj := "1000000";
            end if;
        end case;
        -- Shift mantissa left, decrease exponent
        for x in 1 to 52 loop
          if vadj=to_signed(x,7) then
            v.op1.mant(55 downto x) := r.op1.mant(55-x downto 0);
            v.op1.mant(x-1 downto 0) := (others => r.op1.mant(0));
          end if;
        end loop;
        -- Shift mantissa right, increase exponent
        for x in 1 to 54 loop
          if vadj=to_signed(-x,7) then
            v.op1.mant(55 downto 56-x) := (others => '0');
            v.op1.mant(55-x downto 1) := r.op1.mant(55 downto 1+x);
            vgrd := '0';
            for q in 0 to x loop
              vgrd := vgrd or r.op1.mant(q);
            end loop;
            v.op1.mant(0) := vgrd;
          end if;
        end loop;
        if vadj < -54 then
          v.op1.mant(55 downto 1) := (others => '0');
          vgrd := '0';
          for q in 0 to 55 loop
            vgrd := vgrd or r.op1.mant(q);
          end loop;
          v.op1.mant(0) := vgrd;
        end if;
        if r.op1action=OPACT_SHFTAS or r.op1action=OPACT_SHFTNS then
          vgrd := '0';
          for q in 0 to 29 loop
            vgrd := vgrd or v.op1.mant(q);
          end loop;
          v.op1.mant(29) := vgrd;
        end if;
        v.op1.exp := r.op1.exp - vadj;
      when others   => null;
    end case;
    case r.op2action is
      when OPACT_UNPACK =>
        v.op2 := unpack(vrs2, vrs2sp, vrs2int);
      when OPACT_SHFTN | OPACT_SHFTA | OPACT_SHFTAS | OPACT_SHFTNS =>
        case r.op2action is
          when OPACT_SHFTN | OPACT_SHFTNS =>
            vadj := r.op2normadj;
          when others =>
            vadj := r.expadj2(6 downto 0);
            if r.expadj2(12)='1' and r.expadj2(12 downto 6) /= "1111111" then
              vadj := "1000000";
            end if;
        end case;
        -- Shift mantissa left, decrease exponent
        for x in 1 to 52 loop
          if vadj=to_signed(x,7) then
            v.op2.mant(55 downto x) := r.op2.mant(55-x downto 0);
            v.op2.mant(x-1 downto 0) := (others => r.op1.mant(0));
          end if;
        end loop;
        -- Shift mantissa right, increase exponent
        for x in 1 to 54 loop
          if vadj=to_signed(-x,7) then
            v.op2.mant(55 downto 56-x) := (others => '0');
            v.op2.mant(55-x downto 1) := r.op2.mant(55 downto 1+x);
            vgrd := '0';
            for q in 0 to x loop
              vgrd := vgrd or r.op2.mant(q);
            end loop;
            v.op2.mant(0) := vgrd;
          end if;
        end loop;
        if vadj < -54 then
          v.op2.mant(55 downto 1) := (others => '0');
          vgrd := '0';
          for q in 0 to 55 loop
            vgrd := vgrd or r.op2.mant(q);
          end loop;
          v.op2.mant(0) := vgrd;
        end if;
        if r.op2action=OPACT_SHFTAS or r.op2action=OPACT_SHFTNS then
          vgrd := '0';
          for q in 0 to 29 loop
            vgrd := vgrd or v.op2.mant(q);
          end loop;
          v.op2.mant(29) := vgrd;
        end if;
        v.op2.exp := r.op2.exp - vadj;
      when OPACT_ROUND | OPACT_RSV2 =>
        assert r.op2action /= OPACT_RSV2;
        assert r.op2.mant(55 downto 54)="01" or r.op2.cls="01" or ((r.op2.exp<=-126 or r.op2.exp>126) and r.rddp='0') or r.op2.exp<=-1022 or r.op2.exp>1022;
        vrndbits := r.op2.mant(2 downto 0);
        if r.rddp='0' then
          vrndbits := r.op2.mant(31 downto 29);
          for x in 28 downto 0 loop
            vrndbits(0) := vrndbits(0) or r.op2.mant(x);
          end loop;
        end if;
        vrndup := '0';
        case r.fpurndmode is
          when "00"   =>                -- round to nearest
            if vrndbits(1)='1' and (vrndbits(0)='1' or vrndbits(2)='1') then vrndup:='1'; end if;
          when "01"   =>                -- round to zero
            vrndup := '0';
          when "10"   =>                -- round to +inf
            vrndup := not r.op2.sgn and (vrndbits(1) or vrndbits(0));
          when others =>                -- round to -inf
            vrndup := r.op2.sgn and (vrndbits(1) or vrndbits(0));
        end case;
        if vrndup='1' then
          if r.rddp='1' then
            v.op2.mant(53 downto 2) := std_logic_vector(unsigned(r.op2.mant(53 downto 2))+1);
            if r.op2.mant(53 downto 2)="1111111111111111111111111111111111111111111111111111" then
              v.op2.mant(54) := '1';
              if r.op2.mant(54)='1' then
                v.op2.exp := r.op2.exp+1;
              end if;
            end if;
          else
            v.op2.mant(53 downto 31) := std_logic_vector(unsigned(r.op2.mant(53 downto 31))+1);
            if r.op2.mant(53 downto 31)="11111111111111111111111" then
              v.op2.mant(54) := '1';
              if r.op2.mant(54)='1' then
                v.op2.exp := r.op2.exp+1;
              end if;
            end if;
          end if;
        end if;
        -- Inexact
        if vrndbits(1 downto 0) /= "00" then
          v.exc(EXC_NX) := '1';
        end if;
        -- Underflow
        if r.op2.mant(54)='0' and (r.tem(EXC_UF)='1' or v.exc(EXC_NX)='1') then
          v.exc(EXC_UF) := '1';
        end if;
        if (r.rddp='0' and r.op2.exp < -126) or r.op2.exp < -1022 then
          v.exc(EXC_UF) := '1';
          v.exc(EXC_NX) := '1';
          v.op2.cls := "01";
        end if;
        -- Overflow
        if v.op2.exp > 1023 or (r.rddp='0' and v.op2.exp > 127) then
          v.exc(EXC_OF) := '1';
          if r.tem(EXC_OF)='0' then v.exc(EXC_NX):='1'; end if;
          -- Set the operand to infinity, this is not right for all rounding modes
          --   those cases gets patched up in nf_pack state
          v.op2.cls := "11";
        end if;
      when others   => null;
    end case;
    v.op1normadj := find_normadj(r.op1, r.nalimdp, r.nalimsp, r.naeven);
    v.op2normadj := find_normadj(r.op2, r.nalimdp, r.nalimsp, r.naeven);
    -- Multiplier/accumulator pipeline
    if r.accen='1' then
      if r.accshft='1' then
        -- Shift down 14 bits
        v.acclo(13 downto 1) := r.acclo(27 downto 15);
        vgrd := '0';
        for x in 0 to 14 loop
          vgrd := vgrd or r.acclo(x);
        end loop;
        v.acclo(0) := vgrd;
        v.acclo(27 downto 14) := r.acc(13 downto 0);
        v.acc(17 downto 0) := r.acc(31 downto 14);
        v.acc(31 downto 18) := (others => '0');
      end if;
      v.acc := v.acc + r.mulo;
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
    vop := r.op2;
    if r.mulsel2='1' then vop:= r.op1; end if;
    case r.mulctr2 is
      when "00"   => v.muli2 := unsigned'("00") & unsigned(vop.mant(12 downto 1)) & unsigned'("00");
      when "01"   => v.muli2 := unsigned'("00") & unsigned(vop.mant(26 downto 13));
      when "10"   => v.muli2 := unsigned'("00") & unsigned(vop.mant(40 downto 27));
      when others => v.muli2 := unsigned'("00") & unsigned(vop.mant(54 downto 41));
    end case;
    if r.mulsel2='1' and std_logic_vector(r.mulctr1) /= std_logic_vector(r.mulctr2) then
      v.muli2 := v.muli2(14 downto 0) & '0';
    end if;
    -- FPC flow control
    if commit='1' then
      v.committed := '1';
    end if;
    if r.stfsr='1' and spstore_done='1' then
      v.fsr_ftt := "000";
    end if;
    if issue_cmd(2 downto 1)="11" then
      v.fsr_ftt := "100";               -- sequence error
    end if;

    if spstore_pend='0' then
      v.stfsr := '0';
    end if;
    if issue_cmd="010" and issue_ldstreg(5)='1' and issue_ldstreg(1)='0' then
      v.stfsr := '1';
    end if;
    v.fccready := '1';

    -- Main command FSM
    v.op1action := OPACT_NONE;
    v.op2action := OPACT_NONE;
    v.nalimdp := '0';
    v.nalimsp := '0';
    v.naeven := '0';
    v.accen := r.mulen;
    v.accshft := r.shftpl;
    v.mulen := '0';
    v.shftpl := r.shftpl2;
    v.shftpl2 := '0';
    v.mulsel2 := '0';
    v.miso_accrdy := '0';
    case r.s is
      when nf_idle =>
        v.dfqdata := issue_dfqdata;
        v.rs1 := issue_rs1;
        v.rs2 := issue_rs2;
        v.rd := issue_rd;
        v.rdspec := issue_ldstreg(5);
        v.rddp := issue_ldstdp;
        v.flop := issue_flop;
        v.committed := '0';
        v.exc := (others => '0');
        v.op1action := OPACT_UNPACK;
        v.op2action := OPACT_UNPACK;
        v.acc := (others => '0');
        v.acclo := (others => '0');
        v.res := (others => '0');
        case issue_cmd is
          when "000" =>
            if mosi_accen='1' and r.miso_accrdy='0' then
              v.s := nf_dbgacc1;
              v.rd := mosi_addr(4 downto 0);
              v.rdspec := mosi_addr(5);
              v.rddp := '0';
            end if;
          when "001" =>
            if issue_op3_0='1' then
              v.s := nf_flop1;
              v.fccready := '0';
            else
              v.s := nf_flop1;
            end if;
            -- v.issueid := std_logic_vector(unsigned(r.issueid)+1);
          when "010" =>
            v.rd := issue_ldstreg(4 downto 0);
          when "011" =>
            v.s := nf_load;
            v.rd := issue_ldstreg(4 downto 0);
            -- v.issueid := std_logic_vector(unsigned(r.issueid)+1);
          when others =>
            null;
        end case;

      when nf_load =>
        if commit='1' then
          if r.rdspec='1' then
            set_fsr(lddata(31 downto 0));
            v.s := nf_idle;
          else
            v.s := nf_opdone;
            v.res := lddata;
          end if;
        end if;

      when nf_flop1 =>
        -- Unpack operands
        v.rddp := not decode_rd_sp(r.flop);
        case r.flop is
          when FCMPS | FCMPD | FCMPES | FCMPED =>
            v.s := nf_fcmp2;
          when FITOS | FITOD =>
            v.s := nf_fitos2;
          when FDTOS =>
            v.s := nf_fitos2;
            v.nalimsp := '1';
          when FSTOD =>
            v.s := nf_fitos2;
          when FSTOI | FDTOI =>
            v.s := nf_fstoi2;
          when FMOVS | FABSS | FNEGS =>
            v.s := nf_mov2;
          when FADDS | FSUBS | FADDD | FSUBD =>
            v.s := nf_addsub2;
          when FMULS | FMULD | FSMULD =>
            v.s := nf_mul2;
          when FDIVS | FDIVD =>
            v.s := nf_div2;
          when FSQRTS | FSQRTD =>
            v.s := nf_sqrt2;
            v.naeven := '1';
          when others =>
            v.s := nf_pendexc;
            v.fsr_ftt := "011";         -- unimplemented_fpop
        end case;

      when nf_fitos2 =>
        -- Figure out the amount to shift up the exponent
        -- calculated by op2normadj
        if r.op2.cls="00" then
          v.s := nf_fitos3;
          v.op2action := OPACT_SHFTN;
          if r.rddp='0' then
            v.op2action := OPACT_SHFTNS;
          end if;
        elsif is_signan(r.op2)='1' then
          if r.rddp='1' then
            v.res := defnan_dp;
          else
            v.res := defnan_sp;
          end if;
          v.exc(EXC_NV) := '1';
          v.s := nf_opdone;
        else
          v.s := nf_repack;
        end if;

      when nf_fitos3 =>
        -- Shift up the value (op2action=SHFTN)
        v.s := nf_repack;
        -- Go through nf_round to get over/underflow check for FDTOS
        -- Also do this for FITOS to get inexact exception check
        if (r.flop=FDTOS or r.flop=FITOS) and r.op2.cls="00" then
          v.s := nf_round;
          v.op2action := OPACT_ROUND;
        end if;

      when nf_fstoi2 =>
        if r.op2.cls="10" then v.exc(EXC_NV):='1'; end if;
        if r.op2.cls(1)='1' or r.op2.exp>30 then
          if r.op2.sgn='1' then
            v.res := x"8000000080000000";
          else
            v.res := x"7fffffff7fffffff";
          end if;
          v.s := nf_opdone;
          if not (r.op2.cls="00" and r.op2.exp=31 and r.op2.sgn='1' and r.op2.mant(53 downto 23)="0000000000000000000000000000000") then
            v.exc(EXC_NV) := '1';
          end if;
        elsif r.op2.cls="01" then
          v.res := (others => '0');
          v.s := nf_opdone;
        else
          -- Calculate the amount to shift up to get an exponent of 2^52
          --   this will place the number in the mantissa bits 33:2
          v.expadj2 := r.op2.exp - 52;
          v.op2action := OPACT_SHFTA;
          v.s := nf_fstoi3;
        end if;

      when nf_fstoi3 =>
        -- Performing shift
        v.s := nf_fstoi4;

      when nf_fstoi4 =>
        -- Extract result from mantissa bits
        if r.op2.sgn='1' then
          v.res(63 downto 32) := std_logic_vector(-signed(r.op2.mant(33 downto 2)));
        else
          v.res(63 downto 32) := '0' & r.op2.mant(32 downto 2);
        end if;
        v.res(31 downto 0) := v.res(63 downto 32);
        if r.op2.mant(1 downto 0)/="00" then
          v.exc(EXC_NX) := '1';
        end if;
        v.s := nf_opdone;

      when nf_mov2 =>
        if r.flop=FABSS then
          v.op2.sgn := '0';
        end if;
        if r.flop=FNEGS then
          v.op2.sgn := not r.op2.sgn;
        end if;
        v.s := nf_repack;

      when nf_addsub2 =>
        vswap := '0';
        -- Special cases for zero/NaN/inf
        if is_signan(r.op2)='1' or is_signan(r.op1)='1' then
          -- Signaling NaN in rs1/rs2
          v.s := nf_opdone;
          v.exc(EXC_NV) := '1';
          if r.rddp='1' then
            v.res := defnan_dp;
          else
            v.res := defnan_sp;
          end if;
        elsif r.op2.cls="10" then
          -- Quiet NaN in rs2
          v.s := nf_repack;
        elsif r.op1.cls="10" then
          -- Quiet NaN in rs1
          v.s := nf_repack;
          vswap := '1';
        elsif r.op1.cls="11" and r.op2.cls="11" and (r.flop(2) xor r.op1.sgn xor r.op2.sgn)='1' then
          -- 1) inf-inf=NaN
          if r.rddp='1' then
            v.res := defnan_dp;
          else
            v.res := defnan_sp;
          end if;
          v.s := nf_opdone;
          v.exc(EXC_NV) := '1';
        elsif r.op2.cls="11" then
          -- inf in rs2
          v.s := nf_repack;
          if r.flop(2)='1' then v.op2.sgn := not r.op2.sgn; end if;
        elsif r.op1.cls="11" then
          -- inf in rs1
          v.s := nf_repack;
          vswap := '1';
        elsif r.comphe='1' and r.comple='1' and (r.flop(2) xor r.op1.sgn xor r.op2.sgn)='1' then
          -- Sum to zero
          v.s := nf_opdone;
          v.res := (others => '0');
          if r.fpurndmode="11" then
            v.res(63) := '1';
          end if;
        elsif r.op2.cls="01" then
          -- zero in op2
          v.s := nf_repack;
          vswap := '1';
        elsif r.op1.cls="01" then
          -- zero in op1
          v.s := nf_repack;
          if r.flop(2)='1' then v.op2.sgn := not r.op2.sgn; end if;
        else
          -- Make sure the bigger argument in terms of magnitude is in rs2,
          -- swap if that is not the case.
          -- If we swap and subtract then we need to flip the signs
          -- We also negate the signs for subtraction because the FPU
          --   calculates rs2-rs1 instead of rs1-rs2 as expected
          if r.comphl='1' or (r.comphe='1' and r.compll='1') then
            -- No swap needed abs(rs2)>abs(rs1)
            -- Flip signs if doing subtract
            if r.flop(2)='1' then
              v.op1.sgn := not r.op1.sgn;
              v.op2.sgn := not r.op2.sgn;
            end if;
            v.expadj1 := r.op1.exp-r.op2.exp;
          else
            -- Swap needed
            vswap := '1';
            -- 2 times sign flip cancel out
            v.expadj1 := r.op2.exp-r.op1.exp;
          end if;
          v.s := nf_addsub3;
          v.op1action := OPACT_SHFTA;
          v.expadj2 := (others => '0');
          v.op2action := OPACT_SHFTA;
          if r.rddp='0' then
            v.op1action := OPACT_SHFTAS;
            v.op2action := OPACT_SHFTAS;
          end if;
          -- If it's will use the subtract operation then we shift up both args by 1
          --   this is to ensure there are enough guard digits
          if (r.flop(2) xor r.op1.sgn xor r.op2.sgn)='1' then
            v.expadj1 := v.expadj1+1;
            v.expadj2 := v.expadj2+1;
          end if;
        end if;
        if vswap='1' then
          v.op2 := r.op1;
          v.op1 := r.op2;
        end if;

      when nf_addsub3 =>
        -- Shift down the mantissa of the smaller arg in r.op1
        --   handled by op1action
        -- Decide whether to use "real" add or sub
        -- Sign of rs1 is ignored after this
        -- Skip ahead if single precision
        v.carry := '0';
        if (r.flop(2) xor r.op1.sgn xor r.op2.sgn)='1' then
          v.s := nf_sub4;
          if r.flop=FADDS or r.flop=FSUBS then
            v.s := nf_sub5;
          end if;
        else
          v.s := nf_add4;
          if r.flop=FADDS or r.flop=FSUBS then
            v.s := nf_add5;
          end if;
        end if;

      when nf_add4 =>
        -- Add lower bits
        vtmpadd := unsigned('0' & r.op2.mant(27 downto 0)) + unsigned('0' & r.op1.mant(27 downto 0));
        v.op2.mant(27 downto 0) := std_logic_vector(vtmpadd(27 downto 0));
        v.carry := vtmpadd(28);
        v.s := nf_add5;

      when nf_add5 =>
        -- Add higher bits
        vtmpadd := (unsigned'("00") & unsigned(r.op2.mant(54 downto 28))) + (unsigned'("00") & unsigned(r.op1.mant(54 downto 28)));
        if r.carry='1' then
          vtmpadd := vtmpadd+1;
        end if;
        v.op2.mant(55 downto 28) := std_logic_vector(vtmpadd(27 downto 0));
        v.s := nf_addsub6;
        if r.rddp='1' then v.nalimdp:='1'; else v.nalimsp:='1'; end if;

      when nf_sub4 =>
        -- Sub lower bits
        vtmpadd := unsigned('0' & r.op2.mant(27 downto 0)) - unsigned('0' & r.op1.mant(27 downto 0));
        v.op2.mant(27 downto 0) := std_logic_vector(vtmpadd(27 downto 0));
        v.carry := vtmpadd(28);
        v.s := nf_sub5;

      when nf_sub5 =>
        -- Sub higher bits
        vtmpadd := unsigned('0' & r.op2.mant(55 downto 28)) - unsigned('0' & r.op1.mant(55 downto 28));
        if r.carry='1' then
          vtmpadd := vtmpadd-1;
        end if;
        v.op2.mant(55 downto 28) := std_logic_vector(vtmpadd(27 downto 0));
        v.s := nf_addsub6;
        if r.rddp='1' then v.nalimdp:='1'; else v.nalimsp:='1'; end if;

      when nf_addsub6 =>
        -- Scan for implicit 1 (r.op2normadj) handled in shared resource
        -- TODO: In case of denormal result, stay at lower exponent limit
        v.op2action := OPACT_SHFTN;
        v.s := nf_addsub7;

      when nf_addsub7 =>
        -- Adjust so that the implicit 1 is at the expected position
        v.op2action := OPACT_ROUND;
        v.s := nf_round;

      when nf_mul2 =>
        if ( is_signan(r.op2)='1' or is_signan(r.op1)='1' or
             (r.op1.cls="11" and r.op2.cls="01") or (r.op1.cls="01" and r.op2.cls="11") ) then
          -- Signaling NaN in rs1/rs2
          -- inf * zero
          v.s := nf_opdone;
          v.exc(EXC_NV) := '1';
          if r.rddp='1' then
            v.res := defnan_dp;
          else
            v.res := defnan_sp;
          end if;
        elsif r.op2.cls="10" then
          -- Quiet NaN in rs2
          v.s := nf_repack;
        elsif r.op1.cls="10" then
          -- Quiet NaN in rs1
          v.s := nf_repack;
          v.op2 := r.op1;
        elsif r.op2.cls/="00" then
          -- 0 or inf in rs2
          v.s := nf_repack;
          v.op2.sgn := r.op1.sgn xor r.op2.sgn;
        elsif r.op1.cls/="00" then
          -- 0 or inf in rs1
          v.s := nf_repack;
          v.op2 := r.op1;
          v.op2.sgn := r.op1.sgn xor r.op2.sgn;
        else
          -- On next cycle re-normalize number in case of denormal input
          v.op1action := OPACT_SHFTN;
          v.op2action := OPACT_SHFTN;
          v.s := nf_mul3;
          v.op2.sgn := r.op1.sgn xor r.op2.sgn;
        end if;

      when nf_mul3 =>
        -- normalization done in this stage
        v.s := nf_mul4;
        v.shftpl := '0';
        -- If sources are single prec we can skip ahead in the sequence
        v.mulctrlim := "00";
        if r.flop=FMULS or r.flop=FSMULD then
          v.mulctrlim := "10";
        end if;
        v.mulctr1 := v.mulctrlim;
        v.mulctr2 := v.mulctrlim;

      when nf_mul4 =>
        -- run multiplier pipeline
        v.mulctr1 := r.mulctr1-1;
        v.mulctr2 := r.mulctr2+1;
        v.mulen := '1';
        v.shftpl2 := '0';
        if r.mulctr1=r.mulctrlim or r.mulctr2="11" then
          if r.mulctr2="11" then
            v.mulctr1 := "11";
            v.mulctr2 := r.mulctr1+1;
          else
            v.mulctr1 := r.mulctr2+1;
            v.mulctr2 := r.mulctrlim;
          end if;
          v.shftpl2 := '1';
          if r.mulctr1="11" then
            v.s := nf_mul5;
            v.shftpl2 := '0';
          end if;
        end if;

      when nf_mul5 =>
        -- finish multiplier pipeline
        v.mulen := '0';
        v.shftpl2 := '0';
        if r.accen='0' then
          -- Copy result into op2
          -- Leading one could be in either bit 27 or 26 of accumulator
          assert r.acc(29 downto 28)="00";
          v.op2.mant(55 downto 28) :=  std_logic_vector(r.acc(27 downto 0));
          v.op2.mant(27 downto 0) := std_logic_vector(r.acclo);
          -- Adjust exponent
          v.op2.exp := r.op2.exp + r.op1.exp;
          v.s := nf_mul6;
          if r.rddp='1' then
            v.nalimdp := '1';
          else
            v.nalimsp := '1';
          end if;
        end if;

      when nf_mul6 =>
        -- Computing amount of normalization
        -- Do shift in next state
        v.op2action := OPACT_SHFTN;
        v.s := nf_mul7;

      when nf_mul7 =>
        -- Re-normalizing
        -- Do rounding in next state
        v.op2action := OPACT_ROUND;
        v.s := nf_round;

      when nf_div2 =>
        -- unpacking
        if ( is_signan(r.op2)='1' or is_signan(r.op1)='1' or
             (r.op1.cls="11" and r.op2.cls="11") or (r.op1.cls="01" and r.op2.cls="01") ) then
          -- Signaling NaN in rs1/rs2
          -- or inf/inf, 0/0
          v.s := nf_opdone;
          v.exc(EXC_NV) := '1';
          if r.rddp='1' then
            v.res := defnan_dp;
          else
            v.res := defnan_sp;
          end if;
        elsif r.op2.cls="10" then
          -- Quiet NaN in rs2
          v.s := nf_repack;
        elsif r.op1.cls="10" then
          -- Quiet NaN in rs1
          v.s := nf_repack;
          v.op2 := r.op1;
        elsif r.op2.cls/="00" then
          -- 0 or inf in rs2
          v.s := nf_repack;
          v.op2.sgn := r.op1.sgn xor r.op2.sgn;
          v.op2.cls(1) := not r.op2.cls(1);  -- 0 <-> inf
        elsif r.op1.cls/="00" then
          -- 0 or inf in rs1
          v.s := nf_repack;
          v.op2 := r.op1;
          v.op2.sgn := r.op1.sgn xor r.op2.sgn;
        else
          -- On next cycle re-normalize number in case of denormal input
          v.op1action := OPACT_SHFTN;
          v.op2action := OPACT_SHFTN;
          v.s := nf_div3;
          v.op2.sgn := r.op1.sgn xor r.op2.sgn;
        end if;
        if r.op2.cls="01" and r.op1.cls="00" then v.exc(EXC_DZ):='1'; end if;

      when nf_div3 =>
        -- re-normalizing
        v.s := nf_div4;
        v.divfirst := '1';
        v.divremz := '0';

      when nf_div4 =>
        -- Run division using basic radix-2 algorithm
        -- subtract divisor from remainder
        vtmpadd := unsigned('0' & r.op1.mant(27 downto 0)) - unsigned('0' & r.op2.mant(27 downto 0));
        v.divrem2 := vtmpadd;
        v.divcmp2 := '0';
        if vtmpadd=(vtmpadd'range => '0') then v.divcmp2:='1'; end if;
        vtmpadd := unsigned('0' & r.op1.mant(55 downto 28)) - unsigned('0' & r.op2.mant(55 downto 28));
        v.divrem1 := vtmpadd;
        v.divcmp1 := '0';
        if vtmpadd=(vtmpadd'range => '0') then v.divcmp1:='1'; end if;
        v.s := nf_div5;
        if r.divfirst='1' then
          v.op2.exp := r.op1.exp - r.op2.exp;
        end if;

      when nf_div5 =>
        -- get one bit of quotient, update remainder
        v.res(53 downto 1) := r.res(52 downto 0);
        v.res(0) := '0';
        if r.divrem1(28)='0' and (r.divcmp1='0' or r.divrem2(28)='0') then
          assert r.divrem1(28 downto 27)="00" or (r.divrem1(27)='1' and r.divrem1(26 downto 0)=(26 downto 0 => '0'));
          v.res(0) := '1';
          if r.divrem2(28)='1' then
            v.op1.mant(55 downto 29) := std_logic_vector(r.divrem1(26 downto 0)-1);
          else
            v.op1.mant(55 downto 29) := std_logic_vector(r.divrem1(26 downto 0));
          end if;
          v.op1.mant(28 downto 1) := std_logic_vector(r.divrem2(27 downto 0));
          v.op1.mant(0) := '0';
          vtmpadd := unsigned('0' & r.divrem1(26 downto 0) & '0') - unsigned ('0' & r.op2.mant(55 downto 28));
        else
          assert r.op1.mant(55)='0';
          v.op1.mant := r.op1.mant(54 downto 0) & '0';
          if r.divfirst='1' then
            v.op2.exp := r.op2.exp - 1;
          end if;
          vtmpadd := unsigned(r.op1.mant(55 downto 28) & '0') - unsigned ('0' & r.op2.mant(55 downto 28));
        end if;
        v.s := nf_div4;
        v.divfirst := '0';
        if r.divcmp1='1' and r.divcmp2='1' then
          v.divremz := '1';
        end if;
        -- In single precision case, we calculate the new remainder instantly
        -- above and stay in nf_div5 case
        v.divrem1 := vtmpadd;
        v.divcmp1 := '0';
        if vtmpadd=(vtmpadd'range => '0') then v.divcmp1:='1'; end if;
        if r.rddp='0' then v.s:=nf_div5; end if;

        if r.res(52)='1' or (r.rddp='0' and r.res(23)='1') then
          v.s := nf_round;
          v.op2action := OPACT_ROUND;
          if r.rddp='0' then
            v.op2.mant(55 downto 31) := "01" & r.res(22 downto 0);
            v.op2.mant(30) := v.res(0);
            v.op2.mant(29 downto 1) := (others => '0');
            v.expadj2 := r.op2.exp+126;
            if r.op2.exp < -126 then
              v.s := nf_div6;
              v.op2action := OPACT_SHFTA;
            end if;
          else
            v.op2.mant(55 downto 2) := "01" & r.res(51 downto 0);
            v.op2.mant(1) := v.res(0);
            v.expadj2 := r.op2.exp+1022;
            if r.op2.exp < -1022 then
              v.s := nf_div6;
              v.op2action := OPACT_SHFTA;
            end if;
          end if;
          if v.divremz='1' then
            v.op2.mant(0) := '0';
          else
            v.op2.mant(0) := '1';
          end if;
        end if;

      when nf_div6 =>
        -- de-normalizing result
        v.s := nf_round;
        v.op2action := OPACT_ROUND;

      when nf_sqrt2 =>
        -- calculating adjustment for normalization
        v.op2action := OPACT_SHFTN;
        v.s := nf_sqrt3;
        -- Start multiplier pipeline to get first 2 bits
        v.muli1 := (others => '0');
        v.muli1(1 downto 0) := "11";
        v.muli2 := v.muli1;
        -- Special cases
        if is_signan(r.op2)='1' or (r.op2.sgn='1' and (r.op2.cls="00" or r.op2.cls="11")) then
          if r.rddp='1' then
            v.res := defnan_dp;
          else
            v.res := defnan_sp;
          end if;
          v.exc(EXC_NV) := '1';
          v.s := nf_opdone;
        elsif r.op2.cls /= "00" then
          v.s := nf_repack;
        end if;

      when nf_sqrt3 =>
        -- shifting mantissa
        v.s := nf_sqrt4;
        -- Continue multiplier pipeline
        v.muli1 := r.muli1;
        v.muli1(1 downto 0) := "10";
        v.muli2 := v.muli1;
        -- Init op1.mant here just to avoid triggering the check in nf_sqrt7 too early
        v.op1.mant(55 downto 42) := std_logic_vector(r.muli1(13 downto 0));

      when nf_sqrt4 =>
        -- move top 32 bits of mantissa over to accumulator
        v.res(31 downto 0) := r.op2.mant(55 downto 24);
        -- adjust exponent
        v.op2.exp := r.op2.exp(12) & r.op2.exp(12 downto 1);
        -- check for bits "11"
        if r.mulo(3 downto 0) <= unsigned(r.op2.mant(55 downto 52)) then
          v.muli1 := r.muli1(13 downto 2) & "1111";
          v.res := v.res(59 downto 0) & "0011";
          v.s := nf_sqrt7;
        else
          v.muli1 := r.muli1;
          v.muli1(1 downto 0) := "01";
          v.s := nf_sqrt5;
        end if;
        v.muli2 := v.muli1;

      when nf_sqrt5 =>
        -- check for bits "10"
        v.muli1 := r.muli1;
        if r.mulo <= unsigned(r.res(59 downto 28)) then
          v.muli1 := r.muli1(13 downto 2) & "1011";
          v.res := r.res(59 downto 0) & "0010";
          v.s := nf_sqrt7;
        else
          v.s := nf_sqrt6;
        end if;
        v.muli2 := v.muli1;

      when nf_sqrt6 =>
        -- check for bits "01" or "00"
        v.muli1 := r.muli1(13 downto 2) & "0011";
        v.res := r.res(59 downto 0) & "0000";
        if r.mulo <= unsigned(r.res(59 downto 28)) then
          v.muli1(2) := '1';
          v.res(0) := '1';
        end if;
        v.muli2 := v.muli1;
        v.s := nf_sqrt7;

      when nf_sqrt7 =>
        -- Continue multiplier pipeline
        v.muli1 := r.muli1;
        v.muli1(1 downto 0) := "10";
        v.muli2 := v.muli1;
        v.s := nf_sqrt8;
        if r.op1.mant(55 downto 54) /= "00" then
          v.op1.mant(40 downto 39) := std_logic_vector(r.muli1(3 downto 2));
          v.s := nf_sqrt9;
          v.op1.mant(38) := '1';
          v.sqrtctr := to_unsigned(38,6);
          v.res(38) := '1';
          v.res(37 downto 0) := (others => '0');
          v.mulctrlim := "10";
          v.mulctr2 := v.mulctrlim;
          v.mulctr1 := v.mulctrlim;
        end if;
        v.mulsel2 := '1';

      when nf_sqrt8 =>
        v.op1.mant(54 downto 39) := std_logic_vector(r.muli1(15 downto 0));
        v.op1.mant(38 downto 0) := (others => '0');
        -- continue multiplier pipeline
        v.muli1 := r.muli1;
        v.muli1(1 downto 0) := "01";
        v.muli2 := r.muli1;
        -- check for bits "11"
        if r.mulo <= unsigned(r.res(59 downto 28)) then
          v.muli1 := r.muli1(13 downto 2) & "1111";
          v.res := r.res(59 downto 0) & "0011";
          v.s := nf_sqrt7;
        else
          v.s := nf_sqrt5;
        end if;
        v.muli2 := v.muli1;

      when nf_sqrt9 =>
        -- Slower algorithm to find lower bits by testing one by one
        v.mulen := '1';
        -- run multiplier pipeline
        v.mulctr1 := r.mulctr1-1;
        v.mulctr2 := r.mulctr2+1;
        v.mulen := '1';
        v.shftpl2 := '0';
        if r.mulctr1="00" and r.mulctr2="00" then
          v.mulctr1 := "01";
          v.mulctr2 := "00";
          v.shftpl2 := '1';
        elsif r.mulctr1="01" and r.mulctr2="00" then
          v.mulctr1 := "10";
          v.mulctr2 := "00";
          v.shftpl2 := '1';
        elsif r.mulctr1="01" and r.mulctr2="01" then
          if r.mulctrlim="00" then
            v.mulctr1 := "11";
            v.mulctr2 := "00";
          else
            v.mulctr1 := "10";
            v.mulctr2 := "01";
          end if;
          v.shftpl2 := '1';
        elsif r.mulctr1="10" and r.mulctr2="01" then
          v.mulctr1 := "11";
          v.mulctr2 := "01";
          v.shftpl2 := '1';
        elsif r.mulctr1="10" and r.mulctr2="10" then
          v.mulctr1 := "11";
          v.mulctr2 := "10";
          v.shftpl2 := '1';
        elsif r.mulctr1="11" and r.mulctr2="10" then
          v.mulctr1 := "11";
          v.mulctr2 := "11";
          v.shftpl2 := '1';
        elsif r.mulctr1="11" and r.mulctr2="11" then
          v.mulctr1 := "11";
          v.mulctr2 := "11";
          v.s := nf_sqrt10;
        end if;
        v.mulsel2 := '1';

      when nf_sqrt10 =>
        -- finish multiplier pipeline (mirror of nf_mul5)
        v.mulen := '0';
        v.shftpl2 := '0';
        if r.accen='0' then
          assert r.acc(29 downto 28)="00";
          -- Subtract input from mul result
          vtmpadd := unsigned('0' & r.acclo) - unsigned('0' & r.op2.mant(27 downto 0));
          v.divrem2 := vtmpadd;
          v.divcmp2 := '0';
          if vtmpadd=(vtmpadd'range => '0') then v.divcmp2:='1'; end if;
          vtmpadd := unsigned('0' & r.acc(27 downto 0)) - unsigned('0' & r.op2.mant(55 downto 28));
          v.divrem1 := vtmpadd;
          v.divcmp1 := '0';
          if vtmpadd=(vtmpadd'range => '0') then v.divcmp1:='1'; end if;
          v.s := nf_sqrt11;
        end if;
        v.mulsel2 := '1';

      when nf_sqrt11 =>
        v.acc := (others => '0');
        v.acclo := (others => '0');
        v.res(38 downto 0) := '0' & r.res(38 downto 1);
        if r.divcmp1='1' and r.divcmp2='1' then
          -- Exact match!
          v.op2.mant := r.op1.mant;
          v.s := nf_round;
          v.op2action := OPACT_ROUND;
        elsif r.res(0)='1' or (r.rddp='0' and r.res(29)='1') then
          -- Remainder below mantissa > 0
          v.op2.mant := r.op1.mant;
          v.op2.mant(0) := '1';
          v.s := nf_round;
          v.op2action := OPACT_ROUND;
        else
          if r.divrem1(28)='0' and (r.divcmp1='0' or r.divrem2(28)='0') then
            -- Mul result > input - tested bit should be 0
            v.op1.mant(38 downto 0) := r.op1.mant(38 downto 0) and not r.res(38 downto 0);
          end if;
          v.op1.mant(38 downto 0) := v.op1.mant(38 downto 0) or v.res(38 downto 0);
          v.op1.mant(0) := '0';
          if r.rddp='0' then v.op1.mant(29) := '0'; end if;
          v.sqrtctr := r.sqrtctr-1;
          v.s := nf_sqrt9;
          if r.sqrtctr > 27 then
            v.mulctrlim := "10";
          elsif r.sqrtctr > 13 then
            v.mulctrlim := "01";
          else
            v.mulctrlim := "00";
          end if;
          v.mulctr1 := v.mulctrlim;
          v.mulctr2 := v.mulctrlim;
          v.mulsel2 := '1';
        end if;

      when nf_round =>
        v.s := nf_repack;

      when nf_repack =>
        -- Repack
        if r.exc(EXC_OF)='1' and (r.fpurndmode="01" or
                                  (r.fpurndmode="10" and r.op2.sgn='1') or
                                  (r.fpurndmode="11" and r.op2.sgn='0')) then
          -- Fixup for overflow in certain cases required to generate maximum
          -- representable value
          if r.rddp='1' then
            v.res := r.op2.sgn & "11111111110" & "1111111111111111111111111111111111111111111111111111";
          else
            v.res(63 downto 32) := r.op2.sgn & "11111110" & "11111111111111111111111";
            v.res(31 downto 0) := v.res(63 downto 32);
          end if;
        else
          v.res := pack(r.op2, not r.rddp);
          if r.exc(EXC_UF)='1' and r.op2.cls="01" and
            ( (r.fpurndmode="10" and r.op2.sgn='0') or (r.fpurndmode="11" and r.op2.sgn='1') ) then
            v.res(0) := '1';
            if r.rddp='0' then
              v.res(32) := '1';
            end if;
          end if;
          -- denormalized results always trigger underflow if set in tem
          -- we do it here rather than in the round stage to handle cases where
          -- rounding is bypassed such as (denorm + zero)
          if r.op2.cls="00" and r.op2.mant(54)='0' and r.tem(EXC_UF)='1' then
            v.exc(EXC_UF) := '1';
          end if;
          -- FMOVS/FDIVS/FNEGS do not produce UF exceptions on denormals
          if r.flop=FMOVS or r.flop=FNEGS or r.flop=FABSS then
            v.exc(EXC_UF) := '0';
          end if;
        end if;
        v.s := nf_opdone;

      when nf_opdone =>
        if commit='1' or r.committed='1' then
          if (r.exc and r.tem) /= "00000" then
            v.cexc := r.exc and r.tem;
            if v.cexc(3 downto 1)/="000" then v.cexc(0):='0'; end if;
            v.fsr_ftt := "001";         -- ieee_754_exception
            v.s := nf_pendexc;
          else
            v.cexc := r.exc;
            v.aexc := r.aexc or r.exc;
            if r.rddp='1' or r.rd(0)='0' then
              v.rf(to_integer(unsigned(r.rd(4 downto 1))))(63 downto 32) :=
                r.res(63 downto 32);
            end if;
            if r.rddp='1' or r.rd(0)='1' then
              v.rf(to_integer(unsigned(r.rd(4 downto 1))))(31 downto 0) :=
                r.res(31 downto 0);
            end if;
            v.s := nf_idle;
          end if;
        end if;

      when nf_fcmp2 =>
        if commit='1' or r.committed='1' then
          v.s := nf_idle;
          v.cexc := (others => '0');
          if ( is_signan(r.op1)='1' or is_signan(r.op2)='1' or
               (r.flop(2)='1' and (r.op1.cls="10" or r.op2.cls="10")) ) then
            v.cexc(EXC_NV) := '1';
            if r.tem(EXC_NV)='1' then
              v.s := nf_pendexc;
              v.fsr_ftt := "001";
            else
              v.aexc(EXC_NV) := '1';
              v.fcc := "11";
            end if;
          elsif r.op1.cls="10" or r.op2.cls="10" then
            v.fcc := "11";
          elsif r.op1.cls="01" and r.op2.cls="01" then
            v.fcc := "00";
          elsif r.op1.sgn /= r.op2.sgn then
            v.fcc := "10" xor (r.op1.sgn & r.op1.sgn);
          elsif r.comphl='1' then
            v.fcc := "01" xor (r.op1.sgn & r.op1.sgn);
          elsif r.comphe='0' then
            v.fcc := "10" xor (r.op1.sgn & r.op1.sgn);
          elsif r.compll='1' then
            v.fcc := "01" xor (r.op1.sgn & r.op1.sgn);
          elsif r.comple='0' then
            v.fcc := "10" xor (r.op1.sgn & r.op1.sgn);
          else
            v.fcc := "00";
          end if;
        end if;

      when nf_pendexc =>
        if issue_cmd(2 downto 1)="10" then
          v.s := nf_dfq1;
        end if;
        if issue_cmd="000" and mosi_accen='1' and r.miso_accrdy='0' then
          v.s := nf_dbgacc1;
          v.rd := mosi_addr(4 downto 0);
          v.rdspec := mosi_addr(5);
          v.rddp := '0';
        end if;

      when nf_dfq1 =>
        v.rd := issue_ldstreg(4 downto 0);
        v.rdspec := issue_ldstreg(5);
        if issue_cmd(2 downto 1)="10" then
          v.fsr_ftt := "100";           -- sequence error
        end if;
        if issue_cmd="010" and issue_ldstreg(5)='1' and issue_ldstreg(1)='1' then
          v.s := nf_dfq2;
        end if;
        if issue_cmd="000" and mosi_accen='1' and r.miso_accrdy='0' then
          v.s := nf_dbgacc1;
          v.rd := mosi_addr(4 downto 0);
          v.rdspec := mosi_addr(5);
          v.rddp := '0';
        end if;

      when nf_dfq2 =>
        if spstore_done='1' then
          v.s := nf_idle;
        elsif spstore_pend='0' then
          v.s := nf_dfq1;
        end if;

      when nf_dbgacc1 =>
        v.miso_accrdy := '1';
        if mosi_addr(0)='0' then
          v.res(31 downto 0) := ostdata(63 downto 32);
        else
          v.res(31 downto 0) := ostdata(31 downto 0);
        end if;
        if mosi_addr(5)='0' and mosi_accwr='1' then
          if mosi_addr(0)='0' then
            v.rf(to_integer(unsigned(mosi_addr(4 downto 1))))(63 downto 32) := mosi_wrdata;
          else
            v.rf(to_integer(unsigned(mosi_addr(4 downto 1))))(31 downto 0) := mosi_wrdata;
          end if;
        end if;
        if mosi_addr(5)='1' and mosi_addr(4 downto 2)/="000" then v.res(31 downto 0) := (others => '0'); end if;
        if mosi_addr="100100" then      -- FPU config reg
          v.res(31 downto 29) := FPUVER;
          v.res(7 downto 0) := "01010101";
        end if;
        if mosi_addr="100101" then
          v.res(4 downto 2) := r.fsr_ftt;
          v.res(1) := not r.trapstdfq;
          v.res(0) := r.trapflop;
          if mosi_accwr='1' then
            v.fsr_ftt := mosi_wrdata(4 downto 2);
            if mosi_wrdata(0)='1' then
              v.trapflop := '1';
            end if;
            if mosi_wrdata(1)='1' then
              v.trapstdfq := '0';
              v.trapflop := '1';
            end if;
            if mosi_wrdata(6)='1' then
              v.trapstdfq := '1';
              v.trapflop := '0';
            end if;
          end if;
        end if;
        if mosi_addr="100110" then
          if mosi_accwr='1' then
            v.dfqdata(63 downto 32) := mosi_wrdata;
          end if;
        end if;
        if mosi_addr="100111" then
          if mosi_accwr='1' then
            v.dfqdata(31 downto 0) := mosi_wrdata;
          end if;
        end if;
        if v.trapstdfq='0' then
          v.s := nf_dfq1;
        elsif v.trapflop='1' then
          v.s := nf_pendexc;
        else
          v.s := nf_idle;
        end if;
    end case;
    -- Generate flow control flags
    v.readyflop := '0';
    if (v.s=nf_idle and v.stfsr='0') then
      v.readyflop := '1';
    end if;
    v.readyldst := '0';
    if (v.s=nf_idle and v.stfsr='0') or (v.s=nf_dfq1 and v.stfsr='0') then
      v.readyldst := '1';
    end if;
    if v.s=nf_fcmp2 then
      v.fccready := '0';
    end if;
    v.trapstdfq := '1';
    if v.s=nf_dfq1 then
      v.trapstdfq := '0';
    end if;
    v.trapflop := '0';
    if v.s=nf_pendexc or v.s=nf_dfq1 then
      v.trapflop := '1';
    end if;
    v.trapldst := '0';
    if v.s=nf_pendexc then
      v.trapldst := '1';
    end if;
    if v.s = nf_dbgacc1 then
      v.trapflop := r.trapflop;
      v.trapstdfq := r.trapstdfq;
    end if;
    if unissue='1' then
      v.s := nf_idle;
    end if;

    if ( GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 and
         GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all)=0 ) then
      if rstn='0' then
        v.s          := RRES.s;
        v.fpurndmode := RRES.fpurndmode;
        v.fsr_nonstd := RRES.fsr_nonstd;
        v.fsr_ftt    := RRES.fsr_ftt;
        v.fcc        := RRES.fcc;
        v.cexc       := RRES.cexc;
        v.aexc       := RRES.aexc;
        v.tem        := RRES.tem;
      end if;
    end if;

    -- Signal assignments
    nr <= v;

    ready_flop   <= r.readyflop;
    ready_ld     <= (others => r.readyldst);
    ready_st     <= (others => r.readyldst);
    trapon_flop  <= r.trapflop;
    trapon_ldst  <= r.trapldst;
    trapon_stdfq <= r.trapstdfq;
    issue_id     <= "00000";
    stdata       <= ostdata;
    fccready     <= r.fccready;
    fcc          <= r.fcc;
    fpcidle      <= r.readyflop;
    miso_accrdy  <= r.miso_accrdy;
    miso_rddata  <= r.res(31 downto 0);
    dbgfsr       <= gen_fsr(r);
  end process;

  srstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 generate
    regs: process(clk)
    begin
      if rising_edge(clk) then
        r <= nr;
        if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rstn='0' then
          r <= RRES;
        end if;
      end if;
    end process;
  end generate srstregs;

  arstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)/=0 generate
    regs: process(clk,rstn)
    begin
      if rstn='0' then
        r <= RRES;
      elsif rising_edge(clk) then
        r <= nr;
      end if;
    end process;
  end generate arstregs;


--pragma translate_off
  chkp: process(clk)
  begin
    if rising_edge(clk) then
      assert not (rstn='1' and commit/='0' and (r.committed='1' or r.s = nf_idle))
        report "Unnecessary commit! rstn=" & tost(rstn) & " commit=" & tost(commit) & " r.committed=" & tost(r.committed) & " r.s=" & nanofpu_state'image(r.s)
        severity error;
      assert not (rstn='1' and unissue/='0' and (r.committed='1' or r.s = nf_idle)) report "Unnecessary unissue!" severity error;
    end if;
  end process;
--pragma translate_on

end;
