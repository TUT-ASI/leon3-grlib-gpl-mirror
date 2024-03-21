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

package noelvtypes is

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------

  constant NOELV_VERSION       : integer := 2;
  constant NOELV_TRACE_VERSION : integer := 2;

  constant MAX_TRIGGER_NUM : integer := 5;   -- For nvsupport
  constant PMPENTRIES      : integer := 16;  -- For noelvint
  constant MAXWAYS         : integer := 8;   -- For noelvint and cctrl

  -----------------------------------------------------------------------------
  -- Internal Constants (not for use outside)
  -----------------------------------------------------------------------------

  constant TRACE_WIDTH : integer := 512
-- pragma translate_off
                                    + 2 * (64 + 16)
-- pragma translate_on
                                    ;

  constant IDXMAX      : integer := 16;
  constant TAGMAX      : integer := 32;  -- For noelvint

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
  subtype pmpaddr_type       is std_logic_vector(PMPADDRBITS + 1 downto 0);

  constant pmpaddrzero : pmpaddr_type := (others => '0');

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

  type     x_type is (x_first,
                      x_single_issue, x_late_alu, x_late_branch, x_muladd,
                      x_fpu_debug, x_dtcm, x_itcm,
                      x_rv64, x_mode_u, x_mode_s,
                      x_noelv, x_noelvalu,
                      x_m, x_f, x_d,
                      x_a, x_c, x_h, x_sscofpmf,
                      x_zba, x_zbb, x_zbc, x_zbs,
                      x_zbkb, x_zbkc, x_zbkx,
                      x_zcb,
                      x_time, x_sstc, x_imsic,
                      x_smepmp, x_smaia, x_ssaia,
                      x_smstateen, x_smrnmi,
                      x_smcsrind, x_sscsrind,
                      x_zicbom, x_zicond, x_zimop, x_zcmop,
                      x_svinval,
                      x_zfa, x_zfh, x_zfhmin, x_zfbfmin,
                      x_last);
  subtype  extension_type is std_logic_vector(x_type'pos(x_first) + 1 to x_type'pos(x_last) - 1);
  constant extension_none  : extension_type := (others => '0');
  constant extension_all   : extension_type := (others => '1');

  subtype  flags_t is std_logic_vector(4 downto 0);

  subtype fpu_id is std_logic_vector(4 downto 0);

  subtype cause_type     is std_logic_vector(5 downto 0);  -- Top bit is IRQ
  subtype int_cause_type is std_logic_vector(cause_type'high - 1 downto 0);

end;

package body noelvtypes is
end;
