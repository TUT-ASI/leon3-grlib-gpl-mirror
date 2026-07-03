------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
-- Entity:      noelvtypes
-- File:        noelvtypes.vhd
-- Author:      Johan Klockars, Cobham Gaisler AB
-- Description: Generic NOEL-V types and constants.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.l5nv_shared.all;
use gaisler.noelv.NMCAUSELEN;
use gaisler.utilnv.all;

package noelvtypes is

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------

  constant NOELV_VERSION       : integer := 3;
  constant NOELV_VER_MAJOR     : integer range 0 to 15  := 3;
  constant NOELV_VER_MINOR     : integer range 0 to 255 := 0;
  constant NOELV_TRACE_VERSION : integer := 3;

  constant MAX_TRIGGER_NUM : integer := 64;   -- For nvsupport
  constant MAXWAYS         : integer := 4;   -- For noelvint and cctrl

  -- IDs for cctrl5nv perf events
  constant CCTRL_ICACHE_MISS          : integer :=  0;
  constant CCTRL_DCACHE_MISS          : integer :=  1;
  constant CCTRL_ITLB_MISS            : integer :=  2;
  constant CCTRL_DTLB_MISS            : integer :=  3;
  constant CCTRL_HTLB_MISS            : integer :=  4;
  constant CCTRL_DCACHE_FLUSH         : integer :=  5;
  constant CCTRL_DCACHE_ACCESS        : integer :=  6;
  constant CCTRL_DCACHE_LOAD          : integer :=  7;
  constant CCTRL_DCACHE_STORE         : integer :=  8;
  constant CCTRL_DCACHE_LOAD_HIT      : integer :=  9;
  constant CCTRL_DCACHE_STORE_HIT     : integer := 10;
  constant CCTRL_STBUF_FULL           : integer := 11;
  constant CCTRL_ICACHE_STREAM        : integer := 12;
  constant CCTRL_DTLB_ENTRY_FLUSH     : integer := 13;
  constant CCTRL_ITLB_ENTRY_FLUSH     : integer := 14;
  constant CCTRL_HTLB_ENTRY_FLUSH     : integer := 15;
  constant CCTRL_DTLB_ENTRY_REPLACE   : integer := 16;
  constant CCTRL_ITLB_ENTRY_REPLACE   : integer := 17;
  constant CCTRL_HTLB_ENTRY_REPLACE   : integer := 18;
  constant CCTRL_WRITE_COMBINE        : integer := 19;
  constant CCTRL_CACHE_SCRUBBED       : integer := 20;
  constant CCTRL_PTWALK               : integer := 21;
  constant CCTRL_HPTWALK              : integer := 22;
  constant CCTRL_TLB_ENTRY_FLUSHES    : integer := 23;
  constant CCTRL_CACHED_UNCACHED      : integer := 24;
  constant CCTRL_AMO_UNCACHED         : integer := 25;
  constant CCTRL_AMO_CACHED           : integer := 26;
  constant CCTRL_DATA_UNCACHED        : integer := 27;
  constant CCTRL_DFETCH_UNCACHED      : integer := 28;
  constant CCTRL_DFETCH_CACHED        : integer := 29;
  constant CCTRL_IFETCH_UNCACHED      : integer := 30;
  constant CCTRL_IFETCH_CACHED        : integer := 31;
  constant CCTRL_WRITE_SLOW           : integer := 32;
  constant CCTRL_WRITE_FAST           : integer := 33;
  constant CCTRL_LAST                 : integer := CCTRL_WRITE_FAST;

  subtype perf_type is std_logic_vector(CCTRL_LAST downto 0);

  -----------------------------------------------------------------------------
  -- Internal Constants (not for use outside)
  -----------------------------------------------------------------------------

-- pragma translate_off
  constant TRACE_SIM_WIDTH : integer := 2 * (64 + 16) + 2 * 1;
-- pragma translate_on


  constant PMPADDRBITS : integer := 54;

  -----------------------------------------------------------------------------
  -- Types
  -----------------------------------------------------------------------------

  subtype cache_index is std_logic_vector(IDXMAX - 1 downto 0);
  subtype cache_tag   is std_logic_vector(TAGMAX - 1 downto 0);
  subtype trace_data  is std_logic_vector(TRACE_WIDTH - 1 downto 0);
  subtype trace_sel   is std_logic_vector(TRACE_WIDTH / 32 - 1 downto 0);
-- pragma translate_off
  subtype trace_data_sim is std_logic_vector(TRACE_SIM_WIDTH - 1 downto 0);
-- pragma translate_on

  -- One bit extra length to deal with < condition on high NAPOT limits,
  -- and another one because it is allowed to have all 1's in the CSR and
  -- an implicit 0 above that.
  -- Use "downto 2", since the bottom two address bits are implicit "00".
  subtype pmpaddr_type       is std_logic_vector(PMPADDRBITS + 2 downto 2);

  constant pmpaddrzero : pmpaddr_type := (others => '0');

  type     x_type is (x_first,
                      x_pwrdown_mode,
                      x_single_issue, x_late_alu, x_late_branch, x_ras, x_pma,
                      x_fpu_muladd, x_fpu_div, x_fpu_sqrt,
                      x_fpu_pipe, x_fpu_pair_fmem, x_fpu_pair_int, x_fpu_pair_fpu,
                      x_div_hiperf, x_div_small,
                      x_mmu, x_maskpma, x_rpma,
                      x_fpu_debug, x_dtcm, x_itcm,
                      x_rv64, x_mode_u, x_mode_s,
                      x_capability, x_hwassert, x_diagnostics,
                      x_noelv,
                      x_m, x_f, x_d, x_q,
                      x_a, x_c, x_h, x_sscofpmf, x_smcntrpmf,
                      x_zba, x_zbb, x_zbc, x_zbs,
                      x_zbkb, x_zbkc, x_zbkx,
                      x_zcb,
                      x_time, x_sdtrig, x_sstc, x_imsic,
                      x_smepmp, x_svpbmt, x_smpmpmt, x_svnapot,
                      x_svrsw60t59b,
                      x_walk_pmp, x_walk_fault, x_walk_sw, x_tlb_valid_r,
                      x_enable_g, x_pmp_mmuu_test, x_pma_mmuu_test,
                      x_smaia, x_ssaia,
                      x_smstateen, x_smrnmi,
                      x_ssdbltrp, x_smdbltrp,
                      x_smcsrind, x_sscsrind,
                      x_svadu, x_tlb_pmp, x_sv48,
                      x_zicbom, x_zicboz, x_zicond, x_zimop, x_zcmop,
                      x_zicfiss, x_zicfilp, x_shlcofideleg, x_smcdeleg,
                      x_svinval,
                      x_zfa, x_zfh, x_zfhmin, x_zfbfmin,
                      x_last);
  subtype  extension_type is std_logic_vector(x_type'pos(x_first) + 1 to x_type'pos(x_last) - 1);
  constant extension_none  : extension_type := (others => '0');
  constant extension_all   : extension_type := (others => '1');

  subtype  flags_t is std_logic_vector(4 downto 0);

  subtype fpu_id is std_logic_vector(4 downto 0);

  -- For faults, 5 bits are needed (without hypervisor, RAS, double trap etc - 4 bits).
  -- For interrupts, 4 bits used to be enough, but with RAS 6 are needed.
  --  Also, AIA requires 6 bits for its equivalent .iid field.
  -- NMIs could require 7 bits

  subtype int_cause_type is natural range 0 to (2 ** CAUSELEN) - 1;
  type    cause_type  is record
    irq  : std_logic;
    code : int_cause_type;
  end record;

  subtype int_mncause_type is natural range 0 to (2 ** NMCAUSELEN) -1;
  type    mncause_type  is record
    irq  : std_logic;
    code : int_mncause_type;
  end record;

  constant cause_res   : cause_type   := (irq => '0', code => 0);
  constant mncause_res : mncause_type := (irq => '0', code => 0);

  function to_cause(code : int_cause_type; irq : boolean := false) return cause_type;
  function to_mncause(code : int_mncause_type; irq : boolean := false) return mncause_type;
  function int2mask(n : int_cause_type)   return wordx;
  function cause2int(cause : cause_type)  return integer;
  function cause2mask(cause : cause_type) return wordx;
  function cause_bit(bits : std_logic_vector; cause : cause_type) return std_logic;
  function is_irq(cause : cause_type) return boolean;
  function u2cause(cause : unsigned; irq : std_ulogic) return cause_type;
  function cause2wordx(cause : cause_type) return wordx;
  function mncause2wordx(cause : mncause_type) return wordx;
  function wordx2cause(v : wordx) return cause_type;
  function wordx2mncause(v : wordx; cause_mask : wordx) return mncause_type;
  function cause2vec(cause : cause_type; vec_in : std_logic_vector) return std_logic_vector;


  type xc_type is record
    xc_v : boolean;
    xc   : boolean;
  end record;

  constant XC_ILLEGAL    : xc_type := xc_type'(xc => true, xc_v => false);
  constant XC_VIRT       : xc_type := xc_type'(xc => true, xc_v => true);
  constant XC_NONE       : xc_type := xc_type'(xc => false, xc_v => false);

  constant cause_none                   : cause_type;

end;

package body noelvtypes is
  function to_cause(code : int_cause_type; irq : boolean := false) return cause_type is
    variable irqv : std_logic;
  begin
    if irq then irqv := '1'; else irqv := '0'; end if;
    return cause_type'(irq => irqv, code => code);
  end;

  function to_mncause(code : int_mncause_type; irq : boolean := false) return mncause_type is
    variable irqv : std_logic;
  begin
    if irq then irqv := '1'; else irqv := '0'; end if;
    return mncause_type'(irq => irqv, code => code);
  end;

  function int2mask(n : int_cause_type) return wordx is
    -- Non-constant
    variable v : wordx := zerox;
  begin
    v(n) := '1';

    return v;
  end;

  function cause2mask(cause : cause_type) return wordx is
  begin
    return int2mask(cause.code);
  end;

  function cause2int(cause : cause_type) return integer is
  begin
    return cause.code;
  end;

  -- empty cause
  constant cause_none : cause_type :=  to_cause(48);

  function cause_bit(bits : std_logic_vector; cause : cause_type) return std_logic is
  begin
    if cause = cause_none then
      return '0';
    else
      return bits(cause.code);
    end if;
  end;

  function is_irq(cause : cause_type) return boolean is
  begin
    return cause.irq = '1';
  end;

  function u2cause(cause : unsigned; irq : std_ulogic) return cause_type is
  begin
    return cause_type'(irq => irq, code => u2i(cause));
  end;

  function cause2wordx(cause : cause_type) return wordx is
    -- Non-constant
    variable v : wordx := zerox;
  begin
    v(CAUSELEN - 1 downto 0) := u2vec(cause.code, CAUSELEN);
    v(v'high)                  := cause.irq;

    return v;
  end;

  function mncause2wordx(cause : mncause_type) return wordx is
    -- Non-constant
    variable v : wordx := zerox;
  begin
    v(NMCAUSELEN - 1 downto 0) := u2vec(cause.code, NMCAUSELEN);
    v(v'high)                  := cause.irq;

    return v;
  end;

  function wordx2cause(v : wordx) return cause_type is
    -- Non-constant
    variable cause : cause_type;
  begin
    -- Integers are 32 bits in VHDL, we can't use the full 64-bit range
    -- Not a problem for cause though.
    cause.code := u2i(v(CAUSELEN-1 downto 0));
    cause.irq  := get_hi(v);

    return cause;
  end;

  function wordx2mncause(v : wordx; cause_mask : wordx) return mncause_type is
    -- Non-constant
    variable cause     : mncause_type := mncause_res;
    variable irq       : std_ulogic;
    variable cause_vec : wordx      := (others => '0');
  begin
    -- mncause is a WARL CSR
    irq  := get_hi(v);
    if irq = '0' then
      if unsigned(v(v'length-2 downto 0)) <= to_unsigned(63, XLEN-1) then
        cause_vec(u2i(v(CAUSELEN-1 downto 0))) := '1';
        cause_vec := cause_vec and cause_mask;
        if cause_vec /= zerox then
          cause.code := u2i(v(CAUSELEN-1 downto 0));
          cause.irq  := irq;
        end if;
      end if;
    else
      cause.code := u2i(v(NMCAUSELEN-1 downto 0));
      cause.irq  := irq;
    end if;

    return cause;
  end;

  function cause2vec(cause : cause_type; vec_in : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable vec : std_logic_vector(vec_in'length - 1 downto 0) := vec_in;
  begin
    vec(0) := '0';
    -- vec(cause'high + 1 downto 2) := cause(cause'high - 1 downto 0);
    vec(CAUSELEN + 1 downto 2) := u2slv(cause.code, CAUSELEN);

    return vec;
  end;

end;
