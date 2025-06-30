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
-- Entity:      noelvtypes
-- File:        noelvtypes.vhd
-- Author:      Johan Klockars, Cobham Gaisler AB
-- Description: Generic NOEL-V types and constants.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library gaisler;
use gaisler.noelv.XLEN;
use gaisler.l5nv_shared.all;
use gaisler.noelv.CAUSELEN;
use gaisler.utilnv.all;

package noelvtypes is

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------

  constant NOELV_VERSION       : integer := 2;
  constant NOELV_TRACE_VERSION : integer := 2;

  constant MAX_TRIGGER_NUM : integer := 5;   -- For nvsupport
  constant PMPENTRIES      : integer := 16;  -- For noelvint
  constant PMAENTRIES      : integer := 16;  -- For noelvint
  constant MAXWAYS         : integer := 4;   -- For noelvint and cctrl

  -----------------------------------------------------------------------------
  -- Internal Constants (not for use outside)
  -----------------------------------------------------------------------------

  constant TRACE_WIDTH : integer := 512
-- pragma translate_off
                                    + 2 * (64 + 16) + 2 * 1
-- pragma translate_on
                                    ;


  constant PMPADDRBITS : integer := 54;

  -----------------------------------------------------------------------------
  -- Types
  -----------------------------------------------------------------------------

  subtype cache_index is std_logic_vector(IDXMAX - 1 downto 0);
  subtype cache_tag   is std_logic_vector(TAGMAX - 1 downto 0);
  subtype trace_data  is std_logic_vector(TRACE_WIDTH - 1 downto 0);
  subtype trace_sel   is std_logic_vector(TRACE_WIDTH / 32 - 1 downto 0);

  -- One bit extra length to deal with < condition on high NAPOT limits,
  -- and another one because it is allowed to have all 1's in the CSR and
  -- an implicit 0 above that.
  -- Use "downto 2", since the bottom two address bits are implicit "00".
  subtype pmpaddr_type       is std_logic_vector(PMPADDRBITS + 2 downto 2);

  constant pmpaddrzero : pmpaddr_type := (others => '0');

  subtype integer64 is integer range 0 to 63;
  subtype integer32 is integer range 0 to 31;
  subtype integer16 is integer range 0 to 15;
  subtype integer4  is integer range 0 to 3;
  subtype integer2  is integer range 0 to 1;

  subtype word64 is std_logic_vector(63 downto 0);
  subtype word32 is std_logic_vector(31 downto 0);
  subtype word16 is std_logic_vector(15 downto 0);
  subtype word8  is std_logic_vector( 7 downto 0);
  subtype word5  is std_logic_vector( 4 downto 0);
  subtype word4  is std_logic_vector( 3 downto 0);
  subtype word3  is std_logic_vector( 2 downto 0);
  subtype word2  is std_logic_vector( 1 downto 0);
  subtype wordx  is std_logic_vector(XLEN - 1 downto 0);
  subtype wordx1 is std_logic_vector(XLEN downto 0);
  subtype word   is word32;

  constant zerow16 : word16 := (others => '0');
  constant zerow64 : word64 := (others => '0');
  constant zerox   : wordx  := (others => '0');
  constant zerow   : word   := (others => '0');

  type word64_arr is array (integer range <>) of word64;
  type word16_arr is array (integer range <>) of word16;
  type word8_arr  is array (integer range <>) of word8;
  type word_arr   is array (integer range <>) of word;
  type wordx_arr  is array (integer range <>) of wordx;

  constant word64_arr_empty : word64_arr(0 to 1) := (others => zerow64);

  type     x_type is (x_first,
                      x_single_issue, x_late_alu, x_late_branch, x_muladd,
                      x_fpu_debug, x_dtcm, x_itcm,
                      x_rv64, x_mode_u, x_mode_s,
                      x_noelv, x_noelvalu,
                      x_m, x_f, x_d, x_q, x_n,
                      x_a, x_c, x_h, x_sscofpmf,
                      x_zba, x_zbb, x_zbc, x_zbs,
                      x_zbkb, x_zbkc, x_zbkx,
                      x_zcb,
                      x_time, x_sdtrig, x_sstc, x_imsic,
                      x_smepmp, x_smaia, x_ssaia,
                      x_smstateen, x_smrnmi,
                      x_ssdbltrp, x_smdbltrp,
                      x_smcsrind, x_sscsrind,
                      x_svadu,
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

  subtype int_cause_type is natural range 0 to (2 ** CAUSELEN) - 1;
  type    cause_type  is record
    irq  : std_logic;
    code : int_cause_type;
  end record;

  constant cause_res : cause_type := (irq => '0', code => 0);

  function to_cause(code : int_cause_type; irq : boolean := false) return cause_type;
  function int2mask(n : int_cause_type)   return wordx;
  function cause2int(cause : cause_type)  return integer;
  function cause2mask(cause : cause_type) return wordx;
  function cause_bit(bits : std_logic_vector; cause : cause_type) return std_logic;
  function is_irq(cause : cause_type) return boolean;
  function u2cause(cause : unsigned; irq : std_ulogic) return cause_type;
  function cause2wordx(cause : cause_type) return wordx;
  function wordx2cause(v : wordx) return cause_type;
  function cause2vec(cause : cause_type; vec_in : std_logic_vector) return std_logic_vector;


  type xc_type is record
    xc_v : boolean;
    xc   : boolean;
  end record;

  constant XC_ILLEGAL    : xc_type := xc_type'(xc => true, xc_v => false);
  constant XC_VIRT       : xc_type := xc_type'(xc => true, xc_v => true);
  constant XC_NONE       : xc_type := xc_type'(xc => false, xc_v => false);


end;

package body noelvtypes is
  function to_cause(code : int_cause_type; irq : boolean := false) return cause_type is
    variable irqv : std_logic;
  begin
    if irq then irqv := '1'; else irqv := '0'; end if;
    return cause_type'(irq => irqv, code => code);
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

  function cause_bit(bits : std_logic_vector; cause : cause_type) return std_logic is
  begin
    return bits(cause.code);
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

  function wordx2cause(v : wordx) return cause_type is
    -- Non-constant
    variable cause : cause_type;
  begin
    -- Integers are 32 bits in VHDL, we can't use the full 64-bit range
    -- Not a prblem for cause though.
    cause.code := u2i(v(CAUSELEN-1 downto 0));
    cause.irq  := get_hi(v);

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
