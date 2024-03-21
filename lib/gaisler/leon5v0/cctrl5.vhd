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
-- Entity:      cctrl5
-- File:        cctrl5.vhd
-- Author:      Magnus Hjorth, Cobham Gaisler
-- Based on:    LEON3/LEON4 cache and MMU by Jiri Gaisler, Edvin Catovic
--              and Konrad Eisele
-- Description: Complete cache controller with MMU for LEON5
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.sparc.all;
use grlib.config.all;
use grlib.config_types.all;
library gaisler;
use gaisler.leon5int.all;
use gaisler.cpucore5int.all;

entity cctrl5 is
  generic (
    hindex    : integer;
    iways     : integer range 1 to 4;
    ilinesize : integer range 4 to 8;
    iwaysize  : integer range 1 to 256;
    dways     : integer range 1 to 4;
    dlinesize : integer range 4 to 8;
    dwaysize  : integer range 1 to 256;
    dtagconf  : integer range 0 to 2;
    dusebw    : integer range 0 to 1;
    itcmen    : integer range 0 to 1;
    itcmabits : integer range 1 to 20;
    itcmfrac  : integer range 0 to 7;
    dtcmen    : integer range 0 to 1;
    dtcmabits : integer range 1 to 20;
    dtcmfrac  : integer range 0 to 7;
    itlbnum   : integer range 2 to 64;
    dtlbnum   : integer range 2 to 64;
    cached    : integer;
    wbmask    : integer;
    busw      : integer;
    cdataw    : integer;
    tlbrepl   : integer
    );
  port (
    rst   : in  std_ulogic;
    clk   : in  std_ulogic;
    ici   : in  icache_in_type5;
    ico   : out icache_out_type5;
    dci   : in  dcache_in_type5;
    dco   : out dcache_out_type5;
    ahbi  : in  ahb_mst_in_type;
    ahbo  : out ahb_mst_out_type;
    ahbsi : in  ahb_slv_in_type;
    ahbso  : in  ahb_slv_out_vector;
    crami : out cram_in_type5;
    cramo : in  cram_out_type5;
    sclk : in std_ulogic;
    fpc_mosi : out l5_intreg_mosi_type;
    fpc_miso : in  l5_intreg_miso_type;
    c2c_mosi : out l5_intreg_mosi_type;
    c2c_miso : in  l5_intreg_miso_type;
    freeze : in std_ulogic;
    bootword : in std_logic_vector(31 downto 0);
    smpflush : in std_logic_vector(1 downto 0);
    perf : out std_logic_vector(31 downto 0)
    );


end;

architecture rtl of cctrl5 is

  function max(x,y: integer) return integer is
  begin
    if x>y then return x; else return y; end if;
  end max;

  function pick(b: boolean; tv,fv: integer) return integer is
  begin
    if b then return tv; else return fv; end if;
  end pick;

  constant LINESZMAX    : integer := max(dlinesize,ilinesize);
  constant BUF_HIGH     : integer := log2(LINESZMAX*4)-1;
  constant DLINE_BITS   : integer := log2(dlinesize);
  constant DOFFSET_BITS : integer := 8 +log2(dwaysize) - DLINE_BITS;
  constant DTAG_HIGH    : integer := TAG_HIGH;
  constant DTAG_LOW     : integer := DOFFSET_BITS + DLINE_BITS + 2;
  constant DOFFSET_HIGH : integer := DTAG_LOW - 1;
  constant DOFFSET_LOW  : integer := DLINE_BITS + 2;
  constant ILINE_BITS   : integer := log2(ilinesize);
  constant IOFFSET_BITS : integer := 8 +log2(iwaysize) - ILINE_BITS;
  constant ITAG_HIGH    : integer := TAG_HIGH;
  constant ITAG_LOW     : integer := IOFFSET_BITS + ILINE_BITS + 2;
  constant IOFFSET_HIGH : integer := ITAG_LOW - 1;
  constant IOFFSET_LOW  : integer := ILINE_BITS + 2;
  constant ILINE_HIGH   : integer := IOFFSET_LOW - 1;
  constant ILINE_LOW    : integer := 3;
  constant DLINE_HIGH   : integer := DOFFSET_LOW - 1;
  constant DLINE_LOW    : integer := 2;  -- for legacy reasons
  constant DLINE_LOW_REAL: integer := log2(cdataw/8);

  constant IMUXDATA     : boolean := false;

  constant IMISSPIPE     : boolean := false;
  constant DMISSPIPE     : boolean := false;

  constant ENDIAN        : boolean := (GRLIB_CONFIG_ARRAY(grlib_little_endian) /= 0);

  constant REPL_SOFT    : integer := 0;
  constant REPL_RAND    : integer := 1;

  constant RND     : std_logic_vector(1 downto 0) := "11";
  constant LRR     : std_logic_vector(1 downto 0) := "10";
  constant LRU     : std_logic_vector(1 downto 0) := "01";
  constant DIR     : std_logic_vector(1 downto 0) := "00";

  -- If either wbmask=0 or busw=32, we have a 32-bit only system
  --  create modified constants xwbmask=0 and xbusw=32 for
  --  this case to make the code consistent.
  constant xwbmask : integer := pick(busw=32 or wbmask=0, 0,  wbmask);
  constant xbusw   : integer := pick(busw=32 or wbmask=0, 32, busw);
  -- "fiddle constant" that is set 1 when xbusw=32 to avoid
  -- some null ranges in the code
  constant nbfid   : integer := pick(busw=32 or wbmask=0, 1, 0);
  -- Bus width to use in the read data logic, this is the same as
  -- xbusw above except in the special case of a wide bus with only
  -- narrow slaves but where AMBA compliant data muxing is enabled in
  -- the config package. For that case, we still need to pick the
  -- right 32-bit slice even though all accesses are 32-bit only.
  constant xdbusw: integer := pick((busw=32 or wbmask=0) and CORE_ACDM=0, 32, busw);

  function get_itags_default return cram_tags is
    variable r: cram_tags;
  begin
    r := (others => (others => '0'));
    for w in 0 to IWAYS-1 loop
      r(w)(ITAG_HIGH-ITAG_LOW+1 downto ITAG_HIGH-ITAG_LOW-6) := x"FF";
      r(w)(ITAG_HIGH-ITAG_LOW-7 downto ITAG_HIGH-ITAG_LOW-8) := std_logic_vector(to_unsigned(w,2));
      r(w)(ITAG_HIGH-ITAG_LOW-9 downto ITAG_HIGH-ITAG_LOW-10) := std_logic_vector(to_unsigned(w,2));
      r(w)(0) := '0';
    end loop;
    return r;
  end get_itags_default;
  constant itags_default: cram_tags := get_itags_default;

  -- 3-way way permutations, per set
  -- s012 => way 0 - least recently used
  --         way 2 - most recently used
  constant s012 : std_logic_vector(2 downto 0) := "000";
  constant s021 : std_logic_vector(2 downto 0) := "001";
  constant s102 : std_logic_vector(2 downto 0) := "010";
  constant s120 : std_logic_vector(2 downto 0) := "011";
  constant s201 : std_logic_vector(2 downto 0) := "100";
  constant s210 : std_logic_vector(2 downto 0) := "101";


  -- 4-way way permutations, per set
  -- s0123 => way 0 - least recently used
  --          way 3 - most recently used
  -- bits assigned so bits 4:3 is LRU and 1:0 is MRU
  -- middle bit is 0 for 01 02 03 12 13 23, 1 for 10 20 30 21 31 32
  constant s0123 : std_logic_vector(4 downto 0) := "00011";
  constant s0132 : std_logic_vector(4 downto 0) := "00010";
  constant s0213 : std_logic_vector(4 downto 0) := "00111";
  constant s0231 : std_logic_vector(4 downto 0) := "00001";
  constant s0312 : std_logic_vector(4 downto 0) := "00110";
  constant s0321 : std_logic_vector(4 downto 0) := "00101";
  constant s1023 : std_logic_vector(4 downto 0) := "01011";
  constant s1032 : std_logic_vector(4 downto 0) := "01010";
  constant s1203 : std_logic_vector(4 downto 0) := "01111";
  constant s1230 : std_logic_vector(4 downto 0) := "01000";
  constant s1302 : std_logic_vector(4 downto 0) := "01110";
  constant s1320 : std_logic_vector(4 downto 0) := "01100";
  constant s2013 : std_logic_vector(4 downto 0) := "10011";
  constant s2031 : std_logic_vector(4 downto 0) := "10001";
  constant s2103 : std_logic_vector(4 downto 0) := "10111";
  constant s2130 : std_logic_vector(4 downto 0) := "10000";
  constant s2301 : std_logic_vector(4 downto 0) := "10101";
  constant s2310 : std_logic_vector(4 downto 0) := "10100";
  constant s3012 : std_logic_vector(4 downto 0) := "11010";
  constant s3021 : std_logic_vector(4 downto 0) := "11001";
  constant s3102 : std_logic_vector(4 downto 0) := "11110";
  constant s3120 : std_logic_vector(4 downto 0) := "11000";
  constant s3201 : std_logic_vector(4 downto 0) := "11101";
  constant s3210 : std_logic_vector(4 downto 0) := "11100";

  type lru_3way_table_vector_type is array(0 to 2) of std_logic_vector(2 downto 0);
  type lru_3way_table_type is array (0 to 7) of lru_3way_table_vector_type;

  constant lru_3way_table : lru_3way_table_type :=
    ( (s120, s021, s012),                   -- s012
      (s210, s021, s012),                   -- s021
      (s120, s021, s102),                   -- s102
      (s120, s201, s102),                   -- s120
      (s210, s201, s012),                   -- s201
      (s210, s201, s102),                   -- s210
      (s210, s201, s102),                   -- dummy
      (s210, s201, s102)                    -- dummy
      );

  type lru_4way_table_vector_type is array(0 to 3) of std_logic_vector(4 downto 0);
  type lru_4way_table_type is array(0 to 31) of lru_4way_table_vector_type;

  constant lru_4way_table : lru_4way_table_type :=
    ( (s2310, s0231, s0312, s0213),       -- "00000" (s0231/reset)
      (s2310, s0231, s0312, s0213),       -- "00001" s0231
      (s1320, s0321, s0132, s0123),       -- "00010" s0132
      (s1230, s0231, s0132, s0123),       -- "00011" s0123
      (s3210, s0321, s0312, s0213),       -- "00100" (s0321)
      (s3210, s0321, s0312, s0213),       -- "00101" s0321
      (s3120, s0321, s0312, s0123),       -- "00110" s0312
      (s2130, s0231, s0132, s0213),       -- "00111" s0213
      (s1230, s2301, s1302, s1203),       -- "01000" s1230
      (s1230, s2301, s1302, s1203),       -- "01001" (s1230)
      (s1320, s0321, s1032, s1023),       -- "01010" s1032
      (s1230, s0231, s1032, s1023),       -- "01011" s1023
      (s1320, s3201, s1302, s1203),       -- "01100" s1320
      (s1320, s3201, s1302, s1203),       -- "01101" (s1320)
      (s1320, s3021, s1302, s1023),       -- "01110" s1302
      (s1230, s2031, s1032, s1203),       -- "01111" s1203
      (s2130, s2301, s1302, s2103),       -- "10000" s2130
      (s2310, s2031, s0312, s2013),       -- "10001" s2031
      (s2130, s2031, s0132, s2013),       -- "10010" (s2013)
      (s2130, s2031, s0132, s2013),       -- "10011" s2013
      (s2310, s2301, s3102, s2103),       -- "10100" s2310
      (s2310, s2301, s3012, s2013),       -- "10101" s2301
      (s2130, s2031, s1032, s2103),       -- "10110" (s2103)
      (s2130, s2031, s1032, s2103),       -- "10111" s2103
      (s3120, s3201, s3102, s1203),       -- "11000" s3120
      (s3210, s3021, s3012, s0213),       -- "11001" s3021
      (s3120, s3021, s3012, s0123),       -- "11010" s3012
      (s3120, s3021, s3012, s0123),       -- "11011" (s3012)
      (s3210, s3201, s3102, s2103),       -- "11100" s3210
      (s3210, s3201, s3012, s2013),       -- "11101" s3201
      (s3120, s3021, s3102, s1023),       -- "11110" s3102
      (s3120, s3021, s3102, s1023)        -- "11111" (s3102)
      );

  type lru3_repl_table_single_type is array(0 to 2) of integer range 0 to 2;
  type lru3_repl_table_type is array(0 to 7) of lru3_repl_table_single_type;

  constant lru3_repl_table : lru3_repl_table_type :=
    ( (0, 1, 2),      -- s012
      (0, 2, 2),      -- s021
      (1, 1, 2),      -- s102
      (1, 1, 2),      -- s120
      (2, 2, 2),      -- s201
      (2, 2, 2),      -- s210
      (2, 2, 2),      -- dummy
      (2, 2, 2)       -- dummy
      );

  type lru4_repl_table_single_type is array(0 to 3) of integer range 0 to 3;
  type lru4_repl_table_type is array(0 to 31) of lru4_repl_table_single_type;

  constant lru4_repl_table : lru4_repl_table_type :=
    ( (0, 2, 2, 3), -- (s0231/reset)
      (0, 2, 2, 3), -- s0231
      (0, 1, 3, 3), -- s0132
      (0, 1, 2, 3), -- s0123
      (0, 3, 3, 3), -- (s0321)
      (0, 3, 3, 3), -- s0321
      (0, 3, 3, 3), -- s0312
      (0, 2, 2, 3), -- s0213
      (1, 1, 2, 3), -- s1230
      (1, 1, 2, 3), -- (s1230)
      (1, 1, 3, 3), -- s1032
      (1, 1, 2, 3), -- s1023
      (1, 1, 3, 3), -- s1320
      (1, 1, 3, 3), -- (s1320)
      (1, 1, 3, 3), -- s1302
      (1, 1, 2, 3), -- s1203
      (2, 2, 2, 3), -- s2130
      (2, 2, 2, 3), -- s2031
      (2, 2, 2, 3), -- (s2013)
      (2, 2, 2, 3), -- s2013
      (2, 2, 2, 3), -- s2310
      (2, 2, 2, 3), -- s2301
      (2, 2, 2, 3), -- (s2103)
      (2, 2, 2, 3), -- s2103
      (3, 3, 3, 3), -- s3120
      (3, 3, 3, 3), -- s3021
      (3, 3, 3, 3), -- s3012
      (3, 3, 3, 3), -- (s3012)
      (3, 3, 3, 3), -- s3210
      (3, 3, 3, 3), -- s3201
      (3, 3, 3, 3), -- s3102
      (3, 3, 3, 3)  -- (s3102)
      );

  type tlbent is record
    valid: std_ulogic;
    ctx: std_logic_vector(7 downto 0);
    mask1: std_ulogic;        -- bits 31:24, '1' for 16MiB or smaller,'0' for 4 GiB
    mask2: std_ulogic;        -- bits 23:18, '1' for 256KiB or smaller, '0' for 512KiB+
    mask3: std_ulogic;        -- bits 17:12, '1' for 4 KiB, '0' for 8KiB+
    vaddr: std_logic_vector(31 downto 12);
    paddr: std_logic_vector(31 downto 12);
    perm: std_logic_vector(3 downto 0);    -- priv write/priv read/user write/user read OK
    busw: std_ulogic;
    cached: std_ulogic;
    modified: std_ulogic;
    acc: std_logic_vector(2 downto 0);  -- To reproduce PTE for probe ASI
  end record;
  type tlbentarr is array(natural range <>) of tlbent;
  constant tlbent_defmap: tlbent := (
    valid => '1', ctx => "00000000", mask1 => '0', mask2 => '0', mask3 => '0',
    vaddr => (others => '0'),
    paddr => (others => '0'),
    perm => "1111",
    busw => '0',
    cached => '0',
    modified => '1',
    acc => "011"
    );
  constant tlbent_empty: tlbent := (
    valid => '0', ctx => "00000000", mask1 => '0', mask2 => '0', mask3 => '0',
    vaddr => (others => '0'),
    paddr => (others => '0'),
    perm => "0000",
    busw => '0',
    cached => '0',
    modified => '0',
    acc => "011"
    );
  constant tlb_def1: tlbentarr(1 to itlbnum-1) := (others => tlbent_empty);
  constant tlb_def: tlbentarr(0 to itlbnum-1) := tlbent_defmap & tlb_def1;

  subtype lruent is std_logic_vector(4 downto 0);
  type lruarr is array(natural range <>) of lruent;

  type stbufent is record
    addr: std_logic_vector(31 downto 0);
    size: std_logic_vector(1 downto 0);
    data: std_logic_vector(63 downto 0);
    snoopmask: std_logic_vector(0 to DWAYS-1);
    -- su status for hprot generation
    su: std_ulogic;
    -- set to 1 for narrow 64-bit write to be converted into burst
    nb64: std_ulogic;
    -- "00" - does not combine with next
    -- "01" - might combine with next
    -- "11" - can be combined with next
    wcomb: std_logic_vector(1 downto 0);
    -- 1: store made before trap, write error should be "lost"
    maskwtrap: std_ulogic;
  end record;
  type stbufarr is array(natural range <>) of stbufent;

  constant stbufent_zero: stbufent := ((others => '0'), (others => '0'), (others => '0'), (others => '0'), '0','0',"11",'0');

  type cctrl5_state is (as_normal, as_flush, as_icfetch,
                        as_dcfetch, as_dcfetch2,
                        as_dcsingle, as_mmuwalk, as_mmuwalk3, as_mmuwalk4,
                        as_wptectag1, as_wptectag2, as_wptectag3,
                        as_store, as_wrcomb1, as_wrcomb2,
                        as_slowwr,
                        as_wrasi, as_wrasi2, as_wrasi3,
                        as_rdasi, as_rdasi2, as_rdasi3, as_rdcdiag, as_rdcdiag2,
                        as_getlock, as_parked, as_mmuprobe2, as_mmuprobe3, as_mmuflush2,
                        as_regflush);

  type cctrltype5 is record
    dfrz    : std_ulogic;                                -- dcache freeze enable
    ifrz    : std_ulogic;                                -- icache freeze enable
    dsnoop  : std_ulogic;                                -- data cache snooping
    dcs     : std_logic_vector(1 downto 0);      -- dcache state
    ics     : std_logic_vector(1 downto 0);      -- icache state
    ics_btb : std_logic_vector(1 downto 0);     -- icache state output to btb
    wcomben : std_ulogic;                       -- automatic write combining enable
    wchinten: std_ulogic;                       -- write combining hint enable
    diaemru : std_ulogic;               -- defer instruction access exception
                                        -- mmu register updates until trap is
                                        -- taken
  end record;

  constant M_CTX_SZ       : integer := 8;
  constant MMCTRL_CTXP_SZ : integer := 30;

  type mmctrl_type1 is record
    e       : std_logic;                                        -- enable
    nf      : std_logic;                                        -- no fault
    pso     : std_logic;                                        -- partial store order
    ctx     : std_logic_vector(M_CTX_SZ-1 downto 0);-- context nr
    ctxp    : std_logic_vector(MMCTRL_CTXP_SZ-1 downto 0);  -- context table pointer
    tlbdis  : std_logic;                            -- tlb disabled
    bar     : std_logic_vector(1 downto 0);         -- preplace barrier
  end record;

  constant mmctrl_type1_none : mmctrl_type1 := ('0', '0', '0', (others => '0'), (others => '0'), '0', (others => '0'));

  --# fault status reg
  type mmctrl_fs_type is record
    ow    : std_logic;
    fav   : std_logic;
    ft    : std_logic_vector(2 downto 0);                 -- fault type
    at_ls : std_logic;                              -- access type, load/store
    at_id : std_logic;                              -- access type, i/dcache
    at_su : std_logic;                              -- access type, su/user
    l     : std_logic_vector(1 downto 0);           -- level
    ebe   : std_logic_vector(7 downto 0);
  end record;

  constant mmctrl_fs_zero : mmctrl_fs_type :=
    ('0', '0', "000", '0', '0', '0', "00", "00000000");

  type regfl_pipe_entry is record
    valid: std_ulogic;
    addr: std_logic_vector(DOFFSET_BITS-1 downto 0);
  end record;
  constant regfl_pipe_entry_zero: regfl_pipe_entry := (
    valid => '0',
    addr => (others => '0')
    );
  type regfl_pipe_array is array (0 to 2) of regfl_pipe_entry;

  type cctrl5_regs is record
    -- config registers
    cctrl: cctrltype5;
    mmctrl1: mmctrl_type1;
    mmfsr: mmctrl_fs_type;
    mmfar: std_logic_vector(31 downto 12);
    regflmask: std_logic_vector(31 downto 4);
    regfladdr: std_logic_vector(31 downto 4);
    iregflush: std_ulogic;
    dregflush: std_ulogic;
    iuctrl: iu_control_reg_type;
    icignerr: std_ulogic;
    dcignerr: std_ulogic;
    dcerrmask: std_ulogic;
    dcerrmaskval: std_ulogic;
    itcmenp: std_ulogic;
    itcmenva: std_ulogic;
    itcmenvc: std_ulogic;
    itcmperm: std_logic_vector(1 downto 0);
    itcmaddr: std_logic_vector(31 downto 16);
    itcmctx: std_logic_vector(7 downto 0);
    dtcmenp: std_ulogic;
    dtcmenva: std_ulogic;
    dtcmenvc: std_ulogic;
    dtcmperm: std_logic_vector(3 downto 0);
    dtcmaddr: std_logic_vector(31 downto 16);
    dtcmctx: std_logic_vector(7 downto 0);
    itcmwipe: std_ulogic;
    dtcmwipe: std_ulogic;
    -- FSM state
    s: cctrl5_state;
    -- control flags
    imisspend: std_ulogic;
    dmisspend: std_ulogic;
    iflushpend: std_ulogic;
    dflushpend: std_ulogic;
    slowwrpend: std_ulogic;
    dbgaccpend: std_ulogic;
    syncbar: std_ulogic;
    holdn: std_ulogic;
    ramreload: std_ulogic;
    fastwr_rdy: std_ulogic;
    stbuffull: std_ulogic;
    flushwrd: std_logic_vector(0 to DWAYS-1);
    flushwri: std_logic_vector(0 to IWAYS-1);
    regflpipe: regfl_pipe_array;
    regfldone: std_ulogic;
    -- AHB output registers
    ahb_hbusreq: std_ulogic;
    ahb_hlock: std_ulogic;
    ahb_htrans: std_logic_vector(1 downto 0);
    ahb_haddr: std_logic_vector(31 downto 0);
    ahb_hwrite: std_ulogic;
    ahb_hsize: std_logic_vector(2 downto 0);
    ahb_hburst: std_logic_vector(2 downto 0);
    ahb_hprot: std_logic_vector(3 downto 0);
    ahb_hwdata: std_logic_vector(xbusw-1 downto 0);
    ahb_snoopmask: std_logic_vector(0 to DWAYS-1);
    ahb_maskwtrap: std_ulogic;
    -- AHB delayed registers
    ahb3_inacc: std_ulogic;
    ahb3_rdbuf: std_logic_vector(LINESZMAX*32-1 downto 0);
    ahb3_error: std_ulogic;
    ahb3_rdbvalid: std_logic_vector(LINESZMAX-1 downto 0);
    ahb3_rdberr: std_logic_vector(LINESZMAX-1 downto 0);
    ahb2_inacc: std_ulogic;
    ahb2_hwrite: std_ulogic;
    ahb2_addrmask: std_logic_vector(LINESZMAX-1 downto 0);
    ahb2_ifetch: std_ulogic;
    ahb2_dacc: std_ulogic;
    ahb2_haddr42: std_logic_vector(4 downto 2);
    ahb2_hburst0: std_ulogic;
    ahb2_hsize10: std_logic_vector(1 downto 0);
    ahb2_maskwtrap: std_ulogic;
    -- AHB grant tracking
    granted: std_ulogic;
    -- Track if we are performing retry (for tag update logic)
    ahb_retrying: std_ulogic;
    -- MMU TLBs
    itlb: tlbentarr(0 to itlbnum-1);
    dtlb: tlbentarr(0 to dtlbnum-1);
    tlbflush: std_ulogic;
    newent: tlbent;
    mmuerr: mmctrl_fs_type;
    curerrclass: std_logic_vector(1 downto 0);
    newerrclass: std_logic_vector(1 downto 0);
    itlbpmru: std_logic_vector(0 to itlbnum-1);
    dtlbpmru: std_logic_vector(0 to dtlbnum-1);
    tlbupdate: std_ulogic;
    -- Tag pipeline registers for special functions (region flush)
    itagpipe: cram_tags;
    dtagpipe: cram_tags;
    untagd: std_logic_vector(2*DWAYS-1 downto 0);
    untagi: std_logic_vector(2*IWAYS-1 downto 0);
    -- IĆache logic registers
    i2pc: std_logic_vector(31 downto 0);
    i2paddr: std_logic_vector(31 downto 0);
    i2paddrv: std_ulogic;
    i2busw: std_ulogic;
    i2paddrc: std_ulogic;
    i2tlbhit: std_ulogic;
    i2tlbclr: std_ulogic;
    i2tlbid: std_logic_vector(log2(itlbnum)-1 downto 0);
    i2ctx: std_logic_vector(7 downto 0);
    i2su: std_ulogic;
    i2bufmatch: std_ulogic;
    i2hitv: std_logic_vector(0 to IWAYS-1);
    i2validv: std_logic_vector(0 to IWAYS-1);
    i2tcmhit: std_ulogic;
    i1ten: std_ulogic;
    i1pc: std_logic_vector(31 downto 0);
    i1pc_repl: std_logic_vector(tlbrepl*32-1 downto 0);
    i1ctx: std_logic_vector(7 downto 0);
    i1su: std_ulogic;
    i1cont: std_ulogic;
    i1rep: std_ulogic;
    i1tcmen: std_ulogic;
    ibpmiss: std_ulogic;
    iramaddr: std_logic_vector(log2(ilinesize*4)-1 downto 3);
    irdbufen: std_ulogic;
    irdbufpaddr: std_logic_vector(31 downto log2(ilinesize*4));
    irdbufvaddr: std_logic_vector(31 downto log2(ilinesize*4));
    irephitv: std_logic_vector(0 to IWAYS-1);
    irepvalidv: std_logic_vector(0 to IWAYS-1);
    irepway: std_logic_vector(1 downto 0);
    ireptcmhit: std_ulogic;
    irepdata: cdatatype5;
    ireptlbhit: std_ulogic;
    ireptlbpaddr: std_logic_vector(31 downto 0);
    ireptlbid: std_logic_vector(log2(itlbnum)-1 downto 0);
    tcmdata: std_logic_vector(31 downto 0);
    itlbprobeid: std_logic_vector(log2(itlbnum)-1 downto 0);
    -- DCache logic registers
    d2vaddr: std_logic_vector(31 downto 0);
    d2paddr: std_logic_vector(31 downto 0);
    d2paddrv: std_ulogic;
    d2tlbhit: std_ulogic;
    d2tlbamatch: std_ulogic;
    d2tlbid: std_logic_vector(log2(dtlbnum)-1 downto 0);
    d2tlbclr: std_ulogic;
    d2data: std_logic_vector(63 downto 0);
    d2write: std_ulogic;
    d2size: std_logic_vector(1 downto 0);
    d2busw: std_ulogic;
    d2tlbmod: std_ulogic;
    d2hitv: std_logic_vector(0 to DWAYS-1);
    d2validv: std_logic_vector(0 to DWAYS-1);
    d2asi: std_logic_vector(7 downto 0);
    d2specialasi: std_ulogic;
    d2forcemiss: std_ulogic;
    d2lock: std_ulogic;
    d2su: std_ulogic;
    d2stbuf: stbufarr(0 to 3);
    d2stbw: std_logic_vector(1 downto 0);
    d2stba: std_logic_vector(1 downto 0);
    d2stbd: std_logic_vector(1 downto 0);
    d2nb64en: std_ulogic;
    d2nb64ctr: std_ulogic;
    d2nb64den: std_ulogic;
    d2nb64dctr: std_ulogic;
    d2stbcont: std_ulogic;
    d2wcctr: std_logic_vector(1 downto 0);
    d2wchold: std_logic_vector(2 downto 0);
    d2specread: std_ulogic;
    d2nocache: std_ulogic;
    d2tcmhit: std_ulogic;
    d1ten: std_ulogic;
    d1chk: std_ulogic;
    d1vaddr: std_logic_vector(31 downto 0);
    d1vaddr_repl: std_logic_vector(tlbrepl*32-1 downto 0);
    d1asi: std_logic_vector(7 downto 0);
    d1su: std_ulogic;
    d1specialasi: std_ulogic;
    d1forcemiss: std_ulogic;
    d1tcmen: std_ulogic;
    dramaddr: std_logic_vector(log2(dlinesize*4)-1 downto log2(cdataw/8));
    dvtagdone: std_ulogic;
    dregval: std_logic_vector(31 downto 0);
    dregval64: std_logic_vector(31 downto 0);
    dregerr: std_ulogic;
    dtlbrecheck: std_ulogic;
    dwchint: std_ulogic;
    -- LRU
    ilru: lruarr(0 to 2**IOFFSET_BITS-1);
    dlru: lruarr(0 to 2**DOFFSET_BITS-1);
    -- Common flush registers
    flushctr: std_logic_vector(DOFFSET_BITS-1 downto 0);
    flushpart: std_logic_vector(1 downto 0);
    dtflushdone: std_ulogic;
    -- MMU table walk registers
    mmusel: std_logic_vector(2 downto 0);
    -- FPC debug interface (ASI 0x20)
    fpc_mosi : l5_intreg_mosi_type;
    -- CPU-to-CPU control interface (ASI 0x22)
    c2c_mosi : l5_intreg_mosi_type;
    -- IU BTB/BHT diagnostic interface (ASI 0x24)
    iudiag_mosi : l5_intreg_mosi_type;
    -- context switch status signal
    ctxswitch : std_ulogic;
    -- debug access state
    fsmidle : std_ulogic;
    dbgacc : std_logic_vector(1 downto 0);
    dbgaccwr : std_ulogic;
    -- pending and lost trap state
    itrappend: std_logic_vector(2 downto 0);  -- 0:AHB error 1:MMU error 2:TCM perm error
    itraplost: std_logic_vector(2 downto 0);  -- 0:AHB error 1:MMU error 2:TCM perm error
    itraptype: std_logic_vector(1 downto 0);  -- Reason for most recent instruction
                                              -- access exception
    wtrappend: std_logic_vector(1 downto 0);  -- 0:AHB error, 1:MMU writeback error
    wtraplost: std_logic_vector(1 downto 0);
    wtraptype: std_ulogic;
    ahbwtrapmode: std_logic_vector(1 downto 0);
    mmuwtrapmode: std_logic_vector(1 downto 0);
    ctrappend: std_logic_vector(3 downto 0);
    ctraptype: std_logic_vector(1 downto 0);
    ctrapacc: std_logic_vector(3 downto 0);
    dtrapet0: std_ulogic;
    dtrapet1: std_ulogic;
    dtraptt: std_logic_vector(5 downto 0);
    perf     : std_logic_vector(31 downto 0);
  end record;

  function cctrl5_regs_res return cctrl5_regs is
    variable v: cctrl5_regs;
  begin
    v := (
      cctrl => (dfrz => '0', ifrz => '0', dsnoop => '0',
                dcs => (others => '0'), ics => (others => '0'),
                ics_btb => (others=>'0'), wcomben => '0', wchinten => '1',
                diaemru => '0'
                ),
      mmctrl1 => mmctrl_type1_none, mmfsr => mmctrl_fs_zero, mmfar => (others => '0'),
      regflmask => (others => '0'), regfladdr => (others => '0'), iregflush => '0', dregflush => '0',
      iuctrl => iu_control_reg_default,
      icignerr => '0', dcignerr => '0', dcerrmask => '0', dcerrmaskval => '0',
      itcmenp => '0', itcmenva => '0', itcmenvc => '0', itcmperm => "00",
      itcmaddr => (others => '0'), itcmctx => (others => '0'),
      dtcmenp => '0', dtcmenva => '0', dtcmenvc => '0', dtcmperm => "0000",
      dtcmaddr => (others => '0'), dtcmctx => (others => '0'), itcmwipe => '0', dtcmwipe => '0',
      s => as_normal, imisspend => '0', dmisspend => '0',
      iflushpend => '1', dflushpend => '1', slowwrpend => '0', dbgaccpend => '0', syncbar => '0',
      holdn => '1',
      ramreload => '0', fastwr_rdy => '1', stbuffull => '0',
      flushwrd => (others => '0'), flushwri => (others => '0'), regflpipe => (others => regfl_pipe_entry_zero),
      regfldone => '0',
      untagd => (others => '0'), untagi => (others => '0'),
      ahb_hbusreq => '0', ahb_hlock => '0', ahb_htrans => "00",
      ahb_haddr => (others => '0'), ahb_hwrite => '0', ahb_hsize => "010",
      ahb_hburst => HBURST_SINGLE, ahb_hprot => "0000", ahb_hwdata => (others => '0'),
      ahb_snoopmask => (others => '0'), ahb_maskwtrap => '0',
      ahb3_inacc => '0', ahb3_rdbuf => (others => '0'), ahb3_error => '0', ahb3_rdbvalid => (others => '0'),
      ahb3_rdberr => (others => '0'),
      ahb2_inacc => '0', ahb2_hwrite => '0', ahb2_addrmask => (others => '0'),
      ahb2_ifetch => '0', ahb2_dacc => '0', ahb2_haddr42 => (others => '0'), ahb2_hburst0 => '0', ahb2_hsize10 => "00",
      ahb2_maskwtrap => '0',
      granted => '0', ahb_retrying => '0',
      itlb => tlb_def, dtlb => tlb_def, tlbflush => '0', newent => tlbent_empty, mmuerr => mmctrl_fs_zero,
      curerrclass => "00", newerrclass => "00",
      itlbpmru => (others => '0'), dtlbpmru => (others => '0'),
      tlbupdate => '0', itagpipe => (others => (others => '0')), dtagpipe => (others => (others => '0')),
      i2pc => (others => '0'), i2paddr => (others => '0'), i2paddrv => '0',
      i2busw => '0', i2paddrc => '0',
      i2tlbhit => '0', i2tlbclr => '0', i2tlbid => (others => '0'),
      i2ctx => (others => '0'), i2su => '0',
      i2bufmatch => '0',
      i2hitv => (others => '0'), i2validv => (others => '0'), i2tcmhit => '0',
      i1ten => '0', i1pc => (others => '0'), i1pc_repl => (others => '0'), i1ctx => (others => '0'), i1su => '0', i1cont => '0', i1rep => '0', i1tcmen => '0',
      ibpmiss => '0', iramaddr => (others => '0'),
      irdbufen => '0', irdbufpaddr => (others => '0'), irdbufvaddr => (others => '0'),
      irephitv => (others => '0'), irepvalidv => (others => '0'),
      irepway => "00", ireptcmhit => '0', irepdata => (others => (others => '0')),  ireptlbhit => '0',
      ireptlbpaddr => (others => '0'), ireptlbid => (others => '0'), tcmdata => (others => '0'),
      itlbprobeid => (others => '0'),
      d2vaddr => (others => '0'), d2paddr => (others => '0'), d2paddrv => '0',
      d2tlbhit => '0', d2tlbamatch => '0', d2tlbid => (others => '0'), d2tlbclr => '0',
      d2data => (others => '0'), d2write => '0', d2busw => '0', d2tlbmod => '0',
      d2hitv => (others => '0'), d2validv => (others => '0'),
      d2size => "00", d2asi => "00000000", d2specialasi => '0', d2forcemiss => '0', d2lock => '0', d2su => '0',
      d2stbuf => (others => stbufent_zero), d2stbw => "00", d2stba => "00", d2stbd => "00",
      d2nb64en => '0', d2nb64ctr => '0', d2nb64den => '0', d2nb64dctr => '0',
      d2stbcont => '0', d2wcctr => "00", d2wchold => "000",
      d2specread => '0', d2nocache => '0', d2tcmhit => '0',
      d1ten => '0', d1chk => '0', d1vaddr => (others => '0'), d1vaddr_repl => (others => '0'),
      d1asi => "00000000", d1su => '0',
      d1specialasi => '0', d1forcemiss => '0', d1tcmen => '0',
      dramaddr => (others => '0'), dvtagdone => '0',
      dregval => (others => '0'), dregval64 => (others => '0'), dregerr => '0', dtlbrecheck => '0',
      ilru => (others => (others => '0')), dlru => (others => (others => '0')),
      flushctr => (others => '0'), flushpart => (others => '0'), dtflushdone => '0',
      dwchint => '0',
      mmusel => (others => '0'), fpc_mosi => l5_intreg_mosi_none, c2c_mosi => l5_intreg_mosi_none,
      iudiag_mosi => l5_intreg_mosi_none,
      ctxswitch => '0',
      fsmidle => '0', dbgacc => "00", dbgaccwr => '0',
      itrappend => "000", itraplost => "000", itraptype => "00",
      wtrappend => "00", wtraplost => "00", wtraptype => '0',
      ahbwtrapmode => "01", mmuwtrapmode => "10",
      ctrappend => "0000", ctraptype => "00", ctrapacc => "0000",
      dtrapet0 => '0', dtrapet1 => '0', dtraptt => "000000"
      , perf => (others => '0')
      );
    return v;
  end cctrl5_regs_res;

  constant RRES: cctrl5_regs := cctrl5_regs_res;

  subtype vbitent is std_logic_vector(0 to dways-1);
  type vbitarr is array(natural range <>) of vbitent;

  type cctrl5_snoop_regs is record
    sgranted: std_ulogic;
    s3hit: std_logic_vector(0 to DWAYS-1);
    s3tag: std_logic_vector(DTAG_HIGH downto DTAG_LOW);
    s3offs: std_logic_vector(DOFFSET_HIGH downto DOFFSET_LOW);
    s3read: std_logic_vector(0 to DWAYS-1);
    s3flush: std_logic_vector(0 to DWAYS-1);
    s3tagmsb: std_logic_vector(2*DWAYS-1 downto 0);
    s2en: std_logic_vector(0 to DWAYS-1);
    s2tag: std_logic_vector(DTAG_HIGH downto DTAG_LOW);
    s2offs: std_logic_vector(DOFFSET_HIGH downto DOFFSET_LOW);
    s2read: std_logic_vector(0 to DWAYS-1);
    s2flush: std_logic_vector(0 to DWAYS-1);
    s2tagmsb: std_logic_vector(2*DWAYS-1 downto 0);
    s2eread: std_ulogic;
    s1en: std_logic_vector(0 to DWAYS-1);
    s1haddr: std_logic_vector(31 downto 0);
    s1read: std_ulogic;
    s1flush: std_logic_vector(0 to DWAYS-1);
    s1tagmsb: std_logic_vector(2*DWAYS-1 downto 0);
    s1hwrite: std_ulogic;
    s1hsize: std_logic_vector(2 downto 0);
    s1hmaster: std_logic_vector(3 downto 0);
    s1htrans0: std_ulogic;
    -- DCache valid bits for dtagconf>0
    validarr: vbitarr(0 to 2**DOFFSET_BITS-1);
    -- AHB error status
    ahberr: std_ulogic;
    ahboerr: std_ulogic;
    ahberrm: std_ulogic;
    ahboerrm: std_ulogic;
    ahberrhaddr: std_logic_vector(31 downto 0);
    ahberrhwrite: std_ulogic;
    ahberrhsize: std_logic_vector(2 downto 0);
    ahberrhmaster: std_logic_vector(3 downto 0);
    errburstfilt: std_ulogic;
    ahberrtype: std_logic_vector(1 downto 0);
    ahberracc: std_logic_vector(4 downto 0);
    -- External (diagnostic) access holding regs
    --  dcache tag write (data from r.dtagpipe except 2 msbs and lsb(valid) from regs)
    dtwrite: std_ulogic;
    dtaccidx: std_logic_vector(DOFFSET_BITS-1 downto 0);
    dtaccways: std_logic_vector(0 to DWAYS-1);
    dtacctagmod: std_ulogic;
    dtacctagmsb: std_logic_vector(2*DWAYS-1 downto 0);
    dtacctaglsb: std_logic_vector(DWAYS-1 downto 0);
    --  snoop tag read / write
    stread: std_ulogic;
    stwrite: std_ulogic;
    staccidx: std_logic_vector(DOFFSET_BITS-1 downto 0);
    stacctag: std_logic_vector(DTAG_HIGH-DTAG_LOW+1 downto 1);
    staccways: std_logic_vector(0 to DWAYS-1);
    strdstarted: std_ulogic;
    strddone: std_ulogic;
    -- Deadlock counter for diag access
    dlctr : std_logic_vector(7 downto 0);
    raisereq: std_ulogic;
  end record;

  constant RSRES: cctrl5_snoop_regs :=
    (sgranted => '0',
     s3hit => (others => '0'),
     s3tag => (others => '0'),
     s3offs => (others => '0'),
     s3read => (others => '0'),
     s3flush => (others => '0'),
     s3tagmsb => (others => '0'),
     s2en => (others => '0'),
     s2tag => (others => '0'),
     s2offs => (others => '0'),
     s2read => (others => '0'),
     s2flush => (others => '0'),
     s2tagmsb => (others => '0'),
     s2eread => '0',
     s1en => (others => '0'),
     s1haddr => (others => '0'),
     s1read => '0',
     s1flush => (others => '0'),
     s1tagmsb => (others => '0'),
     s1hwrite => '0',
     s1hsize => "000",
     s1hmaster => "0000",
     s1htrans0 => '0',
     validarr => (others => (others => '0')),
     ahberr => '0',
     ahboerr => '0',
     ahberrm => '0',
     ahboerrm => '0',
     ahberrhaddr => (others => '0'),
     ahberrhwrite => '0',
     ahberrhsize => "000",
     ahberrhmaster => "0000",
     errburstfilt => '0',
     ahberrtype => "00",
     ahberracc => "00000",
     dtwrite => '0',
     dtaccidx => (others => '0'),
     dtaccways => (others => '0'),
     dtacctagmod => '0',
     dtacctagmsb => (others => '0'),
     dtacctaglsb => (others => '0'),
     stread => '0',
     stwrite => '0',
     staccidx => (others => '0'),
     stacctag => (others => '0'),
     staccways => (others => '0'),
     strdstarted => '0',
     strddone => '0',
     dlctr => (others => '0'),
     raisereq => '0'
     );

  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_LEON5, 0, LEON5_VERSION, 0),
    others => zero32);

  constant zerov: std_logic_vector(31 downto 0) := (others => '0');
  constant onev : std_logic_vector(31 downto 0) := (others => '1');

  signal r,c: cctrl5_regs;
  signal rs,cs: cctrl5_snoop_regs;

  signal dbg: std_logic_vector(12 downto 0);

begin

  comb: process(r,rs,rst,ici,dci,ahbi,ahbsi,ahbso,cramo,fpc_miso,c2c_miso,
                freeze,bootword,smpflush)

    function getvalidmask(haddr: std_logic_vector; hsize: std_logic_vector; le: boolean) return std_logic_vector is
      variable vmask64: std_logic_vector(1 downto 0);
      variable vmask128: std_logic_vector(3 downto 0);
      variable vmask256: std_logic_vector(7 downto 0);
      variable r,rt: std_logic_vector(LINESZMAX-1 downto 0);
    begin
      vmask64 := "11";
      if (hsize(2)='0' and hsize(1 downto 0)/="11") then
        if haddr(2)='0' then
          vmask64(0) := '0';
        else
          vmask64(1) := '0';
        end if;
      end if;
      vmask128 := vmask64 & vmask64;
      if hsize(2)='0' then
        if haddr(3)='0' then
          vmask128(1 downto 0) := "00";
        else
          vmask128(3 downto 2) := "00";
        end if;
      end if;
      vmask256 := vmask128 & vmask128;
      if haddr(4)='0' then
        vmask256(3 downto 0) := "0000";
      else
        vmask256(7 downto 4) := "0000";
      end if;
      case LINESZMAX is
        when 4      => r := vmask128;
        when others => r := vmask256;
      end case;
      -- Handle little endian case by flipping the vector
      if le then
        rt := r;
        for x in r'range loop
          r(LINESZMAX-1-x) := rt(x);
        end loop;
      end if;
      return r;
    end getvalidmask;

    function getdmask(addr: std_logic_vector; size: std_logic_vector; le: boolean) return std_logic_vector is
      variable vaddr: std_logic_vector(addr'length-1 downto 0);
      variable vsize: std_logic_vector(size'length-1 downto 0);
      variable dmask: std_logic_vector(3 downto 0);
    begin
      vaddr := addr; vsize := size;
      dmask := "1111";
      if vsize(1)='0' then
        if vaddr(1)='0' then
          dmask := dmask and "1100";
        else
          dmask := dmask and "0011";
        end if;
      end if;
      if vsize(1 downto 0)="00" then
        if vaddr(0)='0' then
          dmask := dmask and "1010";
        else
          dmask := dmask and "0101";
        end if;
      end if;
      if le then
        dmask := dmask(0) & dmask(1) & dmask(2) & dmask(3);
      end if;
      return dmask;
    end getdmask;

    function getdmask64(addr: std_logic_vector; size: std_logic_vector; le: boolean) return std_logic_vector is
      variable vaddr: std_logic_vector(addr'length-1 downto 0);
      variable vsize: std_logic_vector(size'length-1 downto 0);
      variable dmask: std_logic_vector(7 downto 0);
    begin
      vaddr := addr; vsize := size;
      dmask := "11111111";
      if vsize(1 downto 0)/="11" then
        if vaddr(2)='0' xor le then
          dmask := dmask and "11110000";
        else
          dmask := dmask and "00001111";
        end if;
      end if;
      if vsize(1)='0' then
        if vaddr(1)='0' xor le then
          dmask := dmask and "11001100";
        else
          dmask := dmask and "00110011";
        end if;
      end if;
      if vsize(1 downto 0)="00" then
        if vaddr(0)='0' xor le then
          dmask := dmask and "10101010";
        else
          dmask := dmask and "01010101";
        end if;
      end if;
      return dmask;
    end getdmask64;

    function cache_cfg5(crepl, ways, linesize, waysize, lock, snoop,
                        lram, lramsize, lramstart, mmuen : integer) return std_logic_vector is
      variable cfg : std_logic_vector(31 downto 0);
    begin
      cfg := (others => '0');
      if ways /= 1 then
        cfg(30 downto 28) := conv_std_logic_vector(crepl*2+1, 3);
      end if;
      if snoop /= 0 then cfg(27) := '1'; end if;
      cfg(26 downto 24) := conv_std_logic_vector(ways-1, 3);
      cfg(23 downto 20) := conv_std_logic_vector(log2(waysize), 4);
      cfg(18 downto 16) := conv_std_logic_vector(log2(linesize), 3);
      cfg(3  downto  3) := conv_std_logic_vector(mmuen, 1);
      return(cfg);
    end cache_cfg5;

    -- function to calculate tag msb bits to guarantee that the tags are unique
    -- regarless of the other bits of the tag.
    function uniquemsb(msbin: std_logic_vector; wways: std_logic_vector) return std_logic_vector is
      variable r: std_logic_vector(msbin'length-1 downto 0);
      variable msbused: std_logic_vector(0 to 3);
      variable nmsb: std_logic_vector(1 downto 0);
    begin
      r := (others => '0');
      if notx(msbin) and notx(wways) then
        -- Generate a vector of which 2-bit msb values will remain in use
        msbused := "0000";
        for x in 0 to msbin'length/2-1 loop
          if wways(x)='0' then
            msbused(to_integer(unsigned(msbin(2*x+1 downto 2*x)))) := '1';
          end if;
        end loop;
        -- For all ways that will be replaced, select the lowest free value from the
        -- msbused list, and update the msbused list for the next way
        for x in 0 to msbin'length/2-1 loop
          if wways(x)='1' then
            nmsb := "11";
            for y in 3 downto 0 loop
              if msbused(y)='0' then
                nmsb := std_logic_vector(to_unsigned(y,2));
              end if;
            end loop;
            r(2*x+1 downto 2*x) := nmsb;
            msbused(to_integer(unsigned(nmsb))) := '1';
          end if;
        end loop;
      else
--pragma translate_off
        for x in 0 to msbin'length/2-1 loop
          if wways(x) /= '0' then
            r(2*x+1 downto 2*x) := "XX";
          end if;
        end loop;
--pragma translate_on
        null;
      end if;
      return r;
    end uniquemsb;

    variable v: cctrl5_regs;
    variable vs: cctrl5_snoop_regs;
    variable oico: icache_out_type5;
    variable odco: dcache_out_type5;
    variable oahbo: ahb_mst_out_type;
    variable ocrami: cram_in_type5;
    variable ihit, ivalid, ibufaddrmatch, idblhit: std_ulogic;
    variable ihitv, ivalidv: std_logic_vector(0 to IWAYS-1);
    variable itcmhit: std_ulogic;
    variable iway: std_logic_vector(1 downto 0);
    variable icont: std_ulogic;
    variable ipc: std_logic_vector(31 downto 0);
    variable itlbhit: std_ulogic;
    variable itlbclr: std_ulogic;
    variable itlbamatch: std_ulogic;
    variable itlbpaddr: std_logic_vector(31 downto 0);
    variable itlbperm: std_logic_vector(3 downto 0);
    variable itlbhitv: std_logic_vector(0 to itlbnum-1);
    variable itlbid: std_logic_vector(log2x(itlbnum)-1 downto 0);
    variable itlbmask1,itlbmask2,itlbmask3,itlbbusw,itlbcached,ivbusw: std_ulogic;
    variable ilruent: lruent;
    variable itcmact: std_ulogic;
    variable dctagsv: cram_tags;
    variable dhitv, dvalidv: std_logic_vector(0 to DWAYS-1);
    variable dhit, dvalid, ddblhit: std_ulogic;
    variable dtcmhit: std_ulogic;
    variable dway: std_logic_vector(1 downto 0);
    variable dasi: std_logic_vector(7 downto 0);
    variable dsu: std_ulogic;
    variable dlock: std_ulogic;
    variable dspecialasi, dforcemiss: std_ulogic;
    variable dvaddr: std_logic_vector(31 downto 0);
    variable dtlbhit: std_ulogic;
    variable dtlbclr: std_ulogic;
    variable dtlbamatch: std_ulogic;
    variable dtlbpaddr: std_logic_vector(31 downto 0);
    variable dtlbperm: std_logic_vector(3 downto 0);
    variable dtlbhitv: std_logic_vector(0 to dtlbnum-1);
    variable dtlbid: std_logic_vector(log2x(dtlbnum)-1 downto 0);
    variable dtlbmask1, dtlbmask2, dtlbmask3, dtlbbusw, dvbusw, dtlbcached, dtlbmod: std_logic;
    variable dtlb_write, dtlb_lock: std_ulogic;
    variable dtenall: std_ulogic;
    variable dlruent: lruent;
    variable dtcmact: std_ulogic;
    variable vaddr5: std_logic_vector(4 downto 0);
    variable vaddr3: std_logic_vector(2 downto 0);
    variable fastwr: std_ulogic;
    variable fastwr_nb64: std_ulogic;
    variable fastwr_wcomb: std_ulogic;
    variable wrcomb_valid, wrcomb_nvalid: std_logic_vector(0 to 3);
    variable vstoresu: std_ulogic;
    variable vdiagasi: std_logic_vector(3 downto 0);
    variable d64: std_logic_vector(63 downto 0);
    variable dwriting: std_ulogic;
    variable d32: std_logic_vector(31 downto 0);
    variable rdb32: std_logic_vector(31 downto 0);
    variable rdb32v: std_ulogic;
    variable vneedwb: std_ulogic;
    variable vneedwblock: std_ulogic;
    variable vway: unsigned(1 downto 0);
    variable vhit: std_ulogic;
    variable vtmp2: std_logic_vector(1 downto 0);
    variable vtmp3: std_logic_vector(2 downto 0);
    variable vwdata128: std_logic_vector(127 downto 0);
    variable vwdata64: std_logic_vector(63 downto 0);
    variable vwdata: std_logic_vector(cdataw-1 downto 0);
    variable vwad: std_logic_vector(4 downto 3);
    variable vtmp4i: std_logic_vector(0 to 3);
    variable keepreq: std_ulogic;
    variable voffs: std_logic_vector(DOFFSET_HIGH downto DOFFSET_LOW);
    variable vfoffs: std_logic_vector(DOFFSET_HIGH downto DOFFSET_LOW);
    variable vrflag: std_ulogic;
    variable vstd32: std_logic_vector(31 downto 0);
    variable vstd32set: std_ulogic;
    variable vstd64: std_logic_vector(63 downto 0);
    variable vstd64set: std_ulogic;
    variable vstd128: std_logic_vector(127 downto 0);
    variable vstd128set: std_ulogic;

    variable frdmatch: std_logic_vector(0 to DWAYS-1);
    variable frimatch: std_logic_vector(0 to IWAYS-1);
    variable frmsbd: std_logic_vector(2*DWAYS-1 downto 0);
    variable frmsbi: std_logic_vector(2*IWAYS-1 downto 0);
    variable vbubble0: std_ulogic;
    variable vstall: std_ulogic;

    variable vvalididx: std_logic_vector(DOFFSET_HIGH-DOFFSET_LOW downto 0);
    variable vvalidclr, vvalidset: std_logic_vector(0 to DWAYS-1);
    variable vmaskwtrap: std_logic_vector(1 downto 0);

    function get_ccr(r: cctrl5_regs; rs: cctrl5_snoop_regs) return std_logic_vector is
      variable ccr: std_logic_vector(31 downto 0);
    begin
      ccr := (others => '0');
      ccr(23) := r.cctrl.dsnoop;
      ccr(17) := '1';
      ccr(15 downto 14) := r.iflushpend & r.dflushpend;
      ccr(5 downto 0) :=
        r.cctrl.dfrz & r.cctrl.ifrz & r.cctrl.dcs & r.cctrl.ics;
      return ccr;
    end get_ccr;

    procedure set_ccr(val: std_logic_vector) is
      variable vx: std_logic_vector(31 downto 0);
    begin
      vx := val;
      v.cctrl.dsnoop := vx(23);
      v.dflushpend := v.dflushpend or vx(22);
      v.iflushpend := v.iflushpend or vx(21);
      v.cctrl.dfrz := vx(5);
      v.cctrl.ifrz := vx(4);
      v.cctrl.dcs := vx(3 downto 2);
      v.cctrl.ics := vx(1 downto 0);
      v.cctrl.ics_btb := vx(1 downto 0);
    end set_ccr;

    function ft_acc_resolve(at: std_logic_vector(2 downto 0); acc: std_logic_vector(2 downto 0))
      return std_logic_vector is
      variable r: std_logic_vector(2 downto 0);
      -- From the table in SPARC v8 H.5
      constant v0: std_logic_vector(0 to 7) := "00001011";
      constant v1: std_logic_vector(0 to 7) := "00001000";
      constant v2: std_logic_vector(0 to 7) := "11000111";
      constant v3: std_logic_vector(0 to 7) := "11000100";
      constant v4: std_logic_vector(0 to 7) := "10101111";
      constant v5: std_logic_vector(0 to 7) := "10101010";
      constant v6: std_logic_vector(0 to 7) := "11101111";
      constant v7: std_logic_vector(0 to 7) := "11101110";
    begin
      r := "000";
      if notx(acc) and notx(at) then
        case at is
          when "000"  => r(1) := v0(to_integer(unsigned(acc)));
          when "001"  => r(1) := v1(to_integer(unsigned(acc)));
          when "010"  => r(1) := v2(to_integer(unsigned(acc)));
          when "011"  => r(1) := v3(to_integer(unsigned(acc)));
          when "100"  => r(1) := v4(to_integer(unsigned(acc)));
          when "101"  => r(1) := v5(to_integer(unsigned(acc)));
          when "110"  => r(1) := v6(to_integer(unsigned(acc)));
          when others => r(1) := v7(to_integer(unsigned(acc)));
        end case;
        if r(1)='1' and (acc="110" or acc="111") and not (at="101" or at="111") then
          r(0) := '1';
        end if;
      else
        setx(r);
      end if;
      return r;
    end ft_acc_resolve;

    -- Find first zero in pmru vector, returns index
    -- (returns highest index if all ones)
    function pmru_decode(pmru: std_logic_vector) return std_logic_vector is
      constant nent: integer := pmru'length;
      variable r: std_logic_vector(log2(nent)-1 downto 0);
      variable xpmru: std_logic_vector(0 to 2**log2(nent)-1);
      constant onev: std_logic_vector(0 to 15) := "1111111111111111";
    begin
      xpmru := (others => '0');
      xpmru(0 to nent-1) := pmru;
      xpmru(nent-1) := '0'; -- return highest index if all-ones
      r := (others => '0');
      for q in r'high downto 0 loop
        if xpmru(0 to (2**q-1))=onev(0 to (2**q-1)) then
          r(q) := '1';
          xpmru(0 to (2**q-1)) := xpmru(2**q to 2**(q+1)-1);
        end if;
      end loop;
      return r;
    end pmru_decode;

    function calc_lruent(oent: lruent; hway: unsigned(1 downto 0); nways: integer) return lruent is
      variable nent: lruent;
    begin
      nent := (others => '0');
      case nways is
        when 1 =>
          nent := "00000";
        when 2 =>
          nent(4) := '0';
          nent(3) := not hway(0);
          nent(2 downto 0) := "000";
        when 3 =>
          nent(4 downto 2) := lru_3way_table(to_integer(unsigned(oent(4 downto 2))))(to_integer(hway));
          nent(1 downto 0) := "00";
        when others =>
          nent := lru_4way_table(to_integer(unsigned(oent)))(to_integer(hway));
      end case;
      return nent;
    end calc_lruent;

    function dec4wrap(n: std_logic_vector(1 downto 0); w: integer) return std_logic_vector is
      variable r: std_logic_vector(0 to 3);
    begin
      r := (others => '0');
      for v in 0 to 3 loop
        if n=std_logic_vector(to_unsigned(v,2)) then
          r(v mod w) := '1';
        end if;
      end loop;
      return r;
    end dec4wrap;

    function flushmatch(e: tlbent; vaddr: std_logic_vector; curctx: std_logic_vector) return std_ulogic is
      variable fltp: std_logic_vector(3 downto 0);
      variable r: std_ulogic;
      variable acctype, ctxeq: std_ulogic;
    begin
      r := '0';
      if notx(e.acc) and notx(e.ctx) and notx(e.vaddr) and notx(e.mask3) and notx(e.mask2) and notx(e.mask1) then
        fltp := vaddr(11 downto 8);
        acctype := '0';
        if unsigned(e.acc) > 5 then acctype := '1'; end if;
        ctxeq := '0';
        if e.ctx=curctx then ctxeq := '1'; end if;
        case fltp is
          when "0000" =>
            if (acctype='1' or ctxeq='1') and vaddr(31 downto 12)=e.vaddr(31 downto 12) and e.mask3='1' then
              r := '1';
            end if;
          when "0001" =>
            if (acctype='1' or ctxeq='1') and vaddr(31 downto 18)=e.vaddr(31 downto 18) and e.mask2='1' then
              r := '1';
            end if;
          when "0010" =>
            if (acctype='1' or ctxeq='1') and vaddr(31 downto 24)=e.vaddr(31 downto 24) and e.mask1='1' then
              r := '1';
            end if;
          when "0011" =>
            if acctype='0' and ctxeq='1' then
              r := '1';
            end if;
          when "0100" => r := '1';
          when others => r := '0';
        end case;
      else
        setx(r);
      end if;
      return r;
    end flushmatch;

    function tcmaddr_comp(accaddr: std_logic_vector(31 downto 16); tcmaddr: std_logic_vector(31 downto 16);
                          tcmen: integer; tcmabits: integer) return std_ulogic is
      variable r: std_ulogic;
      variable vmask: std_logic_vector(31 downto 16);
    begin
      vmask := (others => '0');
      for x in 31 downto 16 loop
        if x>(2+tcmabits) then
          vmask(x) := '1';
        end if;
      end loop;
      r := '0';
      if (accaddr and vmask)=(tcmaddr and vmask) and tcmen/=0 then r:='1'; end if;
      return r;
    end tcmaddr_comp;

  begin
    dbg <= (others => '0');
    --------------------------------------------------------------------------
    -- Variable init
    --------------------------------------------------------------------------
    v := r;
    vs := rs;
    oico.data := cramo.idatadout;
    oico.way := "00";
    oico.mexc := '0';
    oico.mexcdata := (others => '0');
    oico.mexcdata(7 downto 6) := r.mmuerr.l;
    oico.mexcdata(5) := r.mmuerr.at_su;
    oico.mexcdata(4 downto 2) := r.mmuerr.ft;
    oico.hold := r.holdn;
    oico.flush := r.flushpart(1);
    oico.mds := '1';
    oico.cfg := (others => '0');
    oico.bpmiss := r.ibpmiss;
    oico.eocl := '0';
    if r.i2pc(2)='1' and r.i2pc(3)='1' and (ilinesize=4 or r.i2pc(4)='1') then
      oico.eocl := '1';
    end if;
    oico.ics_btb := r.cctrl.ics_btb;
    oico.btb_flush := r.flushpart(1);
    oico.parked := '0';
    oico.ctxswitch := r.ctxswitch;
    odco.data := cramo.ddatadout;
    odco.way := "00";
    odco.mexc := '0';
    odco.hold := r.holdn;
    odco.mds := '1';
    odco.dtrapet1 := r.dtrapet1;
    odco.dtrapet0 := r.dtrapet0;
    odco.dtraptt := r.dtraptt;
    odco.cache := '0';
    odco.wbhold := '0';
    odco.iudiag_mosi := r.iudiag_mosi;
    odco.iuctrl := r.iuctrl;
    oahbo.hbusreq := r.ahb_hbusreq or rs.raisereq;
    oahbo.hlock := r.ahb_hlock;
    oahbo.htrans := r.ahb_htrans;
    oahbo.haddr := r.ahb_haddr;
    oahbo.hwrite := r.ahb_hwrite;
    oahbo.hsize := r.ahb_hsize;
    oahbo.hburst := r.ahb_hburst;
    oahbo.hprot := r.ahb_hprot;
    oahbo.hwdata := ahbdrivedata(r.ahb_hwdata);
    oahbo.hirq := (others => '0');
    oahbo.hconfig := hconfig;
    oahbo.hindex := hindex;

    ocrami.iindex := (others => '0');
    ocrami.idataoffs := (others => '0');
    if r.holdn='0' then
      ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.i1pc(IOFFSET_HIGH downto IOFFSET_LOW);
      ocrami.idataoffs(log2(ilinesize)-2 downto 0) := r.i1pc(ILINE_HIGH downto ILINE_LOW);
      ocrami.ifulladdr := r.i1pc;
    else
      ocrami.iindex(IOFFSET_BITS-1 downto 0) := ici.rpc(IOFFSET_HIGH downto IOFFSET_LOW);
      ocrami.idataoffs(log2(ilinesize)-2 downto 0) := ici.rpc(ILINE_HIGH downto ILINE_LOW);
      ocrami.ifulladdr := ici.rpc;
    end if;
    ocrami.ifulladdrw := r.d2vaddr;
    ocrami.itagen := (others => '0');
    ocrami.itagwrite := '0';
    ocrami.itagdin := (others => (others => '0'));
    for s in 0 to IWAYS-1 loop
      ocrami.itagdin(s)(ITAG_HIGH-ITAG_LOW+1 downto 1) := r.irdbufpaddr(ITAG_HIGH downto ITAG_LOW);
      ocrami.itagdin(s)(0) := '1';
    end loop;
    ocrami.idataen := (others => '0');
    ocrami.idatawrite := "00";
    ocrami.idatadin := (others => '0');
    for x in 0 to 3 loop
      if r.iramaddr=std_logic_vector(to_unsigned(x,2)) then
        if (not ENDIAN) then
          ocrami.idatadin := r.ahb3_rdbuf((3-x)*64+63 downto (3-x)*64);
        else
          ocrami.idatadin := r.ahb3_rdbuf(x*64+63 downto x*64);
        end if;
      end if;
    end loop;
    ocrami.itcmen := '0';
    ocrami.dtagcindex := (others => '0');
    if r.holdn='0' then
      ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d1vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
    else
      ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := dci.eaddress(DOFFSET_HIGH downto DOFFSET_LOW);
    end if;
    ocrami.dtagcen := (others => '0');
    ocrami.dtaguindex := (others => '0');
    ocrami.dtaguwrite := (others => '0');
    ocrami.dtagudin := (others => (others => '0'));
    ocrami.dtagcuindex := (others => '0');
    ocrami.dtagcuen := (others => '0');
    ocrami.dtagcuwrite := '0';
    ocrami.dtagsindex := (others => '0');
    ocrami.dtagsen := (others => '0');
    ocrami.dtagswrite := '0';
    ocrami.dtagsdin := (others => (others => '0'));
    ocrami.ddataindex := (others => '0');
    ocrami.ddataoffs := (others => '0');
    if r.holdn='0' or dci.write='1' then
      ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d1vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
      ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d1vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
      ocrami.ddatafulladdr := r.d1vaddr;
    else
      ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := dci.eaddress(DOFFSET_HIGH downto DOFFSET_LOW);
      ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := dci.eaddress(DLINE_HIGH downto DLINE_LOW_REAL);
      ocrami.ddatafulladdr := dci.eaddress;
    end if;
    ocrami.ddatafulladdrw := r.d1vaddr;
    ocrami.ddataen := (others => '0');
    ocrami.ddatawrite := (others => '0');
    ocrami.ddatadin := (others => (others => '0'));
    for w in 0 to DWAYS-1 loop
      ocrami.ddatadin(w) := dci.edata;
    end loop;
    ocrami.dtcmen := '0';
    ocrami.dtcmdin := dci.edata;

    vwad := (others => '0');
    vwad(log2(dlinesize*4)-1 downto log2(cdataw/8)) := r.dramaddr;
    vwdata128 := r.ahb3_rdbuf(4*32-1 downto 0);
    if (vwad(4)='0') xor ENDIAN then
      vwdata128 := r.ahb3_rdbuf(LINESZMAX*32-1 downto LINESZMAX*32-128);
    end if;
    if (vwad(3)='0') xor ENDIAN then
      vwdata64 := vwdata128(127 downto 64);
    else
      vwdata64 := vwdata128(63 downto 0);
    end if;
    if cdataw=64 then
      vwdata := vwdata64;
    else
      vwdata := vwdata128;
    end if;
    if r.s=as_dcfetch then
      for x in 0 to 3 loop
        ocrami.ddatadin(x) := vwdata64;
      end loop;
    end if;
    v.perf := (others=>'0');
    vrflag := '0';


    --------------------------------------------------------------------------
    -- Trap handshake management
    --------------------------------------------------------------------------
    v.mmuerr.fav := '0';
    vmaskwtrap := "00";
    if r.holdn='1' and dci.trapack='1' then
      if dci.trapacktt=x"01" then           -- Instruction access exception
        v.itraptype := dci.trapackidata(1 downto 0);
        case v.itraptype is
          when "00" =>
            v.itrappend(0) := '0';
          when "01" =>
            v.itrappend(1) := '0';
            if r.cctrl.diaemru='1' then
              v.newerrclass := "01";
              v.newent.vaddr := dci.trapackpc(31 downto 12);
              v.mmuerr.fav := '1';
              v.mmuerr.l := dci.trapackidata(7 downto 6);
              v.mmuerr.at_ls := '0';        -- Load/Execute
              v.mmuerr.at_id := '1';        -- Instruction space
              v.mmuerr.at_su := dci.trapackidata(5);
              v.mmuerr.ft := dci.trapackidata(4 downto 2);
            end if;
          when others =>
            v.itrappend(2) := '0';
        end case;
      end if;
      v.itraplost := v.itraplost or v.itrappend;
      v.itrappend := (others => '0');
      -- Write error
      if dci.trapacktt=x"2b" then
        v.wtraptype := r.wtrappend(1);
        if v.wtraptype='0' then
          v.wtrappend(0) := '0';
        else
          v.wtrappend(1) := '0';
        end if;
      end if;
      if r.ahbwtrapmode="01" then
        v.wtraplost(0) := v.wtraplost(0) or v.wtrappend(0);
        v.wtrappend(0) := '0';
        vmaskwtrap(0) := '1';
      end if;
      if r.mmuwtrapmode="01" then
        v.wtraplost(1) := v.wtraplost(1) or v.wtrappend(1);
        v.wtrappend(1) := '0';
        vmaskwtrap(1) := '1';
      end if;
      -- Internal error
      if dci.trapacktt=x"60" then
        v.ctraptype := "00";
        for x in r.ctrappend'range loop
          if r.ctrappend(x)='1' then
            v.ctraptype := std_logic_vector(to_unsigned(x,2));
          end if;
        end loop;
        for x in r.ctrappend'range loop
          if v.ctraptype=std_logic_vector(to_unsigned(x,2)) then
            v.ctrappend(x) := '0';
          end if;
        end loop;
      end if;
    end if;
    if r.ahbwtrapmode="00" then
      vmaskwtrap(0) := '1';
    end if;
    if r.mmuwtrapmode="00" then
      vmaskwtrap(1) := '1';
    end if;

    --------------------------------------------------------------------------
    -- ICache logic
    --------------------------------------------------------------------------

    -- ICache TLB lookup
    itlbhit := '0';
    itlbamatch := '0';
    itlbpaddr := (others => '0');
    itlbperm := "0000";
    itlbhitv := (others => '0');
    itlbclr := '0';
    itlbid := (others => '0');
    itlbmask1 := '0';
    itlbmask2 := '0';
    itlbmask3 := '0';
    itlbbusw := '0';
    itlbcached := '0';
    for x in 0 to itlbnum-1 loop
      ipc := r.i1pc_repl((x mod tlbrepl)*32+31 downto (x mod tlbrepl)*32);
      if ( ( r.itlb(x).valid='1' and r.itlb(x).ctx=r.i1ctx and
             (r.itlb(x).mask1='0' or r.itlb(x).vaddr(31 downto 24)=ipc(31 downto 24)) and
             (r.itlb(x).mask2='0' or r.itlb(x).vaddr(23 downto 18)=ipc(23 downto 18)) and
             (r.itlb(x).mask3='0' or r.itlb(x).vaddr(17 downto 12)=ipc(17 downto 12)) ) or
           (x=0 and r.mmctrl1.e='0') )
      then
        if (r.i1su='1' and r.itlb(x).perm(2)='1') or (r.i1su='0' and r.itlb(x).perm(0)='1') then
          itlbhit := '1';
        else
          if r.i1ten='1' and ici.inull='0' and r.i1rep='0' then
            itlbclr := '1';
          end if;
        end if;
        itlbhitv(x) := '1';
        itlbamatch := '1';
        itlbid := itlbid or std_logic_vector(to_unsigned(x,itlbid'length));
        itlbpaddr(31 downto 12) := itlbpaddr(31 downto 12) or r.itlb(x).paddr;
        itlbmask1 := itlbmask1 or r.itlb(x).mask1;
        itlbmask2 := itlbmask2 or r.itlb(x).mask2;
        itlbmask3 := itlbmask3 or r.itlb(x).mask3;
        itlbbusw  := itlbbusw  or r.itlb(x).busw;
        itlbcached := itlbcached or r.itlb(x).cached;
        if r.itlb(x).mask1='0' or r.mmctrl1.e='0' then
          itlbpaddr(31 downto 24):=itlbpaddr(31 downto 24) or ipc(31 downto 24);
        end if;
        if r.itlb(x).mask2='0' or r.mmctrl1.e='0' then
          itlbpaddr(23 downto 18):=itlbpaddr(23 downto 18) or ipc(23 downto 18);
        end if;
        if r.itlb(x).mask3='0' or r.mmctrl1.e='0' then
          itlbpaddr(17 downto 12):=itlbpaddr(17 downto 12) or ipc(17 downto 12);
        end if;
      end if;
    end loop;
    -- if r.mmctrl1.e='0' then
    itlbpaddr(11 downto 0) := itlbpaddr(11 downto 0) or r.i1pc(11 downto 0);
    -- end if;
    -- Select bus width from TLB unless 4 GiB entry, then decode from virt addr
    ivbusw := dec_wbmask_fixed(r.i1pc(31 downto 2), xwbmask);
    if itlbmask1='0' then
      itlbbusw := itlbbusw or ivbusw;
    end if;
    -- Select cacheability from TLB unless cache is off
    if r.mmctrl1.e='0' then
      itlbcached := ahb_slv_dec_cache(r.i1pc, ahbso, cached);
    end if;

    -- "free running" TLB id register used in probe state
    v.itlbprobeid := itlbid;

    -- Tag compare logic
    -- ihitv := "0000";
    ihitv := (others => '0');
    ihit := '0';
    iway := "00";
    ivalid := '0';
    idblhit := '0';
    for i in IWAYS-1 downto 0 loop
      if ( (cramo.itagdout(i)(ITAG_HIGH-ITAG_LOW+1 downto 1) = itlbpaddr(ITAG_HIGH downto ITAG_LOW)) and
           r.i1ten='1' and itlbhit='1') then
        ihitv(i) := '1';
        if ihit='1' then idblhit := '1'; end if;  -- duplicated itag detected
        ihit := '1';
        iway := iway or std_logic_vector(to_unsigned(i,2));
      end if;
      ivalidv(i) := cramo.itagdout(i)(0);
    end loop;
    ivalid := ivalidv(to_integer(unsigned(iway)));
    -- Note: ihit is AND:ed with ivalid, but ihitv is _not_ AND:ed with ivalidv
    -- If we happen to have a Icache miss to an address matching a tag,
    -- we need r.i2hitv to be set on the way where we had the cache line,
    -- in order to avoid putting the new cache line in another way and getting
    -- two ways with idential tag.
    -- This would be quite unlikely, only if the instruction address matches
    -- one of the default tags after a flush or a tag is invalidated via
    -- diagnostic access and we then match the address that was written.
    --   ihitv := ihitv and ivalidv;
    ihit := ihit and ivalid;

    -- Instruction TCM hit and muxing logic
    itcmhit := '0';
    if itcmen /= 0 then
      if r.i1tcmen='1' and tcmaddr_comp(r.i1pc(31 downto 16),r.itcmaddr,itcmen,itcmabits)='1' then
        itcmhit := '1';
        ihit := '1';
        ihitv := (others => '0');
        iway := "00";
        idblhit := '0';
        oico.data(0) := cramo.itcmdout;
        if r.holdn='1' then
          if (r.itcmperm(0)='0' and r.i1su='0') or (r.itcmperm(1)='0' and r.i1su='1') then
            oico.mexc := '1';
            oico.mexcdata(1 downto 0) := "10";
            v.itrappend(1) := '1';
          end if;
        end if;
      end if;
    end if;

    if r.i1rep='1' then
      ihitv := r.irephitv;
      ivalidv := r.irepvalidv;
      iway := r.irepway;
      ihit := ihitv(to_integer(unsigned(iway)));
      ivalid := ivalidv(to_integer(unsigned(iway)));
      itcmhit := r.ireptcmhit;
      ihit := (ihit and ivalid) or itcmhit;
      idblhit := '0';
      oico.data := r.irepdata;
      itlbhit := r.ireptlbhit;
      itlbpaddr := r.ireptlbpaddr;
      itlbid := r.ireptlbid;
    end if;


    ibufaddrmatch := '0';
    if r.irdbufen='1' then
      ihit := '0';
      idblhit := '0';
      if r.i1pc(31 downto r.irdbufvaddr'low)=r.irdbufvaddr then
        ibufaddrmatch := '1';
        if (not ENDIAN) then
          if r.ahb3_rdbvalid(LINESZMAX-2-2*to_integer(unsigned(r.i1pc(log2(4*ilinesize)-1 downto 3))))='1' then
            ihit := '1';
          end if;
        else
          if r.ahb3_rdbvalid(1+2*to_integer(unsigned(r.i1pc(log2(4*ilinesize)-1 downto 3))))='1' then
            ihit := '1';
          end if;
        end if;
      end if;
    elsif r.i1cont='1' then
      ihitv := r.i2hitv;
      ivalidv := r.i2validv;
      itcmhit := r.i2tcmhit;
      ihit := orv(r.i2hitv) or r.i2tcmhit;
      ivalid := orv(r.i2validv);
      iway := "00";
      idblhit := '0';
      for x in 0 to IWAYS-1 loop
        if ihitv(x)='1' then
          iway := iway or std_logic_vector(to_unsigned(x,2));
        end if;
      end loop;
    end if;

    oico.way := iway;
    if IMUXDATA then
      oico.data(0) := oico.data(to_integer(unsigned(oico.way)));
      oico.way := "00";
    end if;

    if r.imisspend='1' and r.i2tcmhit='0' then
      oico.mds := '0';
    end if;
    if r.irdbufen='1' then
      -- Mux out buffer data
      oico.way := "00";
      for x in 0 to LINESZMAX/2-1 loop
        if (r.imisspend='1' and r.i2pc(BUF_HIGH downto 3)=std_logic_vector(to_unsigned(x,BUF_HIGH-2))) or
          (r.imisspend='0' and r.i1pc(BUF_HIGH downto 3)=std_logic_vector(to_unsigned(x,BUF_HIGH-2))) then
          if (not ENDIAN) then
            oico.data(0) := r.ahb3_rdbuf((LINESZMAX/2-x)*64-1 downto (LINESZMAX/2-x)*64-64);
          else
            oico.data(0) := r.ahb3_rdbuf(x*64+63 downto x*64);
          end if;
        end if;
        -- Allow for streaming from read data buffer
        if ( r.imisspend='1' and r.i2bufmatch='1' and
             r.i2pc(BUF_HIGH downto 3)=std_logic_vector(to_unsigned(x,BUF_HIGH-2))) then
          if (not ENDIAN) then
            if r.ahb3_rdbvalid(LINESZMAX-2*x-1 downto LINESZMAX-2*x-2)="11" then
              v.imisspend := '0';
            end if;
          else
            if r.ahb3_rdbvalid(2*x+1 downto 2*x)="11" then
              v.imisspend := '0';
            end if;
          end if;
        end if;
      end loop;
    end if;

    -- Main hit/miss checking logic (v.imisspend propagates to main FSM)
    -- Stage 2 ITLB update in case of hit
    d32 := r.i2pc;
    if r.s=as_rdasi then
      d32 := r.d2vaddr;
    end if;
    if notx(d32) then
      ilruent := r.ilru(to_integer(unsigned(d32(IOFFSET_HIGH downto IOFFSET_LOW))));
    else
      setx(ilruent);
    end if;
    if r.holdn='1' then
      vway := "00";
      vhit := '0';
      for x in r.i2hitv'range loop
        if r.i2hitv(x)='1' then
          vhit:='1';
          vway:=vway or to_unsigned(x,2);
        end if;
      end loop;
      if vhit='1' then
        v.ilru(to_integer(unsigned(r.i2pc(DOFFSET_HIGH downto DOFFSET_LOW)))) := calc_lruent(ilruent, vway, IWAYS);
      end if;
    end if;
    -- Stage 1 tag check (insn in fetch stage)
    v.i2tlbclr := '0';
    if r.holdn='1' then
      v.ibpmiss := '0';
    end if;
    if r.holdn='1' then
      dbg(0) <= '1';
      v.i2pc := r.i1pc;
      v.i2paddr := itlbpaddr;
      v.i2paddrv := itlbhit;
      v.i2tlbhit := itlbhit;
      v.i2tlbid := itlbid;
      v.i2tlbclr := itlbclr;
      v.i2busw := itlbbusw;
      v.i2paddrc := itlbcached;
      v.i2ctx := r.i1ctx;
      v.i2su := r.i1su;
      v.i2bufmatch := ibufaddrmatch;
      v.i2tcmhit := itcmhit;
      if r.irdbufen='0' then
        v.i2validv := ivalidv;
        v.i2hitv := ihitv;
        v.irdbufvaddr := r.i1pc(31 downto r.irdbufvaddr'low);
        v.irdbufpaddr := v.i2paddr(31 downto r.irdbufpaddr'low);
      end if;
      -- Set icmiss pending bit
      if ici.inull='0' and ihit/='1' then
        if ici.nobpmiss='0' then
          v.imisspend := '1';
        else
          v.ibpmiss := '1';
        end if;
      end if;
      if r.i1rep='0' then
        v.irephitv := ihitv;
        v.irepvalidv := ivalidv;
        v.irepway := iway;
        v.irepdata := cramo.idatadout;
        v.ireptcmhit := itcmhit;
        if itcmhit='1' then
          v.irepdata(0) := cramo.itcmdout;
        end if;
        v.ireptlbhit := itlbhit;
        v.ireptlbpaddr := itlbpaddr;
        v.ireptlbid := itlbid;
      end if;
      if idblhit='1' then
        v.ctrappend(0) := '1';
      end if;
    end if;
    -- Stage 0 drive addresses (insn in pre-fetch stage)
    if r.holdn='1' then
      -- NOTE: Assuming read-hold behavior
      v.i1ten := '0';
    end if;
    if (r.holdn='1' or r.ramreload='1') and r.cctrl.ics(0)='1' then
      ocrami.itagen := "1111";
      ocrami.idataen := "1111";
      v.i1ten := '1';
    end if;
    itcmact := '0';
    if r.itcmenp='1' and r.mmctrl1.e='0' then itcmact := '1'; end if;
    if r.itcmenva='1' and r.mmctrl1.e='1' then itcmact := '1'; end if;
    if r.itcmenvc='1' and r.mmctrl1.e='1' and r.mmctrl1.ctx=r.itcmctx then itcmact:='1'; end if;
    if (r.holdn='1' or r.ramreload='1') then
      v.i1tcmen := '0';
      if itcmact='1' then
        ocrami.itcmen := '1';
        v.i1tcmen := '1';
      end if;
    end if;

    icont := '0';
    if ici.rbranch='0' and ici.fpc(ILINE_HIGH downto ILINE_LOW)/=onev(ILINE_HIGH downto ILINE_LOW) then
      icont := '1';
    end if;
    if r.i1ten='0' and r.i1cont='0' then
      icont := '0';
    end if;
    if r.i1cont='0' and ici.inull='1' then
      icont := '0';
    end if;
    if r.ramreload='1' then
      icont := '0';
      v.i1cont := '0';
    end if;
    if icont='1' and (r.i1ten='1' or r.i1cont='1') then
      ocrami.itagen := "0000";
    end if;
    if icont='1' and r.i1cont='1' then
      ocrami.idataen(0 to IWAYS-1) := ocrami.idataen(0 to IWAYS-1) and r.i2hitv;
    end if;
    if r.cctrl.ics(0)='0' then
      icont := '0';
    end if;
    if r.holdn='1' then
      if ici.iustall = '0' then
        v.i1pc := ici.rpc;
        v.i1su := ici.su;
        v.i1cont := icont;
        v.i1ctx := r.mmctrl1.ctx;
      end if;
      v.i1rep := ici.iustall;
    end if;
    if r.ramreload='1' then
      v.i1rep := '0';
    end if;


    -- select input data for Icache

    --------------------------------------------------------------------------
    -- DCache logic
    --------------------------------------------------------------------------

    dctagsv := cramo.dtagcdout;
    if dtagconf > 0 then
      voffs := r.d1vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
      if r.s=as_regflush then
        voffs := r.regflpipe(2).addr;
      elsif r.s=as_rdcdiag2 then
        voffs := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
      end if;
      for w in 0 to DWAYS-1 loop
        if notx(voffs) then
          dctagsv(w)(0) := rs.validarr(to_integer(unsigned(voffs)))(w);
        else
          setx(dctagsv(w)(0));
        end if;
      end loop;
    end if;

    -- DCache TLB lookup
    dtlbhit := '0';
    dtlbamatch := '0';
    dtlbpaddr := (others => '0');
    dtlbperm := "0000";
    dtlbhitv := (others => '0');
    dtlbid := (others => '0');
    dtlbmask1 := '0';
    dtlbmask2 := '0';
    dtlbmask3 := '0';
    dtlbbusw := '0';
    dtlbcached := '0';
    dtlbmod := '0';
    dtlbclr := '0';
    dtlb_write := dci.write;
    dtlb_lock := dci.lock;
    if r.dtlbrecheck='1' then
      dtlb_write := r.d2write;
      dtlb_lock := r.d2lock;
    end if;
    for x in 0 to dtlbnum-1 loop
      dvaddr := r.d1vaddr_repl((x mod tlbrepl)*32+31 downto (x mod tlbrepl)*32);
      if ( ( r.dtlb(x).valid='1' and r.dtlb(x).ctx=r.mmctrl1.ctx and
           (r.dtlb(x).mask1='0' or r.dtlb(x).vaddr(31 downto 24)=dvaddr(31 downto 24)) and
           (r.dtlb(x).mask2='0' or r.dtlb(x).vaddr(23 downto 18)=dvaddr(23 downto 18)) and
           (r.dtlb(x).mask3='0' or r.dtlb(x).vaddr(17 downto 12)=dvaddr(17 downto 12)) ) or
           (x=0 and r.mmctrl1.e='0') ) then
        if ( (r.d1su='1' and (dtlb_write='1' or  dtlb_lock='1') and r.dtlb(x).perm(3)='1') or
             (r.d1su='1' and (dtlb_write='0' and dtlb_lock='0') and r.dtlb(x).perm(2)='1') or
             (r.d1su='0' and (dtlb_write='1' or  dtlb_lock='1') and r.dtlb(x).perm(1)='1') or
             (r.d1su='0' and (dtlb_write='0' and dtlb_lock='0') and r.dtlb(x).perm(0)='1') ) then
          dtlbhit := '1';
          dtlbhitv(x) := '1';
        else
          if r.d1chk='1' and r.d1specialasi='0' and dci.nullify='0' then
            dtlbclr := '1';
          end if;
        end if;
        dtlbamatch := '1';
        dtlbid := dtlbid or std_logic_vector(to_unsigned(x,dtlbid'length));
        dtlbpaddr(31 downto 12) := dtlbpaddr(31 downto 12) or r.dtlb(x).paddr;
        dtlbmask1 := dtlbmask1 or r.dtlb(x).mask1;
        dtlbmask2 := dtlbmask2 or r.dtlb(x).mask2;
        dtlbmask3 := dtlbmask3 or r.dtlb(x).mask3;
        dtlbbusw  := dtlbbusw  or r.dtlb(x).busw;
        dtlbcached := dtlbcached or r.dtlb(x).cached;
        dtlbmod := dtlbmod or r.dtlb(x).modified;
        if r.dtlb(x).mask1='0' or r.mmctrl1.e='0' then
          dtlbpaddr(31 downto 24):=dtlbpaddr(31 downto 24) or dvaddr(31 downto 24);
        end if;
        if r.dtlb(x).mask2='0' or r.mmctrl1.e='0' then
          dtlbpaddr(23 downto 18):=dtlbpaddr(23 downto 18) or dvaddr(23 downto 18);
        end if;
        if r.dtlb(x).mask3='0' or r.mmctrl1.e='0' then
          dtlbpaddr(17 downto 12):=dtlbpaddr(17 downto 12) or dvaddr(17 downto 12);
        end if;
      end if;
    end loop;
    -- if r.mmctrl1.e='0' then
      dtlbpaddr(11 downto 0) := dtlbpaddr(11 downto 0) or r.d1vaddr(11 downto 0);
    -- end if;
    dvbusw := dec_wbmask_fixed(r.d1vaddr(31 downto 2), xwbmask);
    -- Select bus width from TLB unless 4 GiB entry, then decode from virt addr
    if dtlbmask1='0' then
      dtlbbusw := dtlbbusw or dvbusw;
    end if;
    -- Select cacheability from TLB unless cache is off
    if r.mmctrl1.e='0' then
      dtlbcached := ahb_slv_dec_cache(r.d1vaddr, ahbso, cached);
    end if;
    if r.cctrl.dcs(0)='0' then
      dtlbcached := '0';
    end if;

    -- Tag compare logic
    dhitv := (others => '0');
    dhit := '0';
    dway := "00";
    dvalid := '0';
    dvalidv := (others => '0');
    ddblhit := '0';
    for i in DWAYS-1 downto 0 loop
      if ( (dctagsv(i)(DTAG_HIGH-DTAG_LOW+1 downto 1) = dtlbpaddr(DTAG_HIGH downto DTAG_LOW)) and
           r.d1ten='1' and dtlbhit='1') then
        dhitv(i) := '1';
        if dhit='1' then ddblhit := '1'; end if;  -- duplicated dtag detected
        dhit := '1';
        dway := dway or std_logic_vector(to_unsigned(i,2));
      end if;
      dvalidv(i) := dctagsv(i)(0);
    end loop;
    dvalid := dvalidv(to_integer(unsigned(dway)));
    -- Note: dhit is AND:ed with valid, but dhitv is _not_ AND:ed with validv
    -- If we miss due to valid bit being zero after a snoop hit we want
    -- r.d2hitv to be set to the way where we had the cache line, in order to
    -- avoid putting it in another way and getting two ways with idential tag.
    --   dhitv := dhitv and dvalidv;
    dhit := dhit and dvalid;

    -- Data TCM hit and muxing logic
    dtcmhit := '0';
    if dtcmen /= 0 then
      if r.d1tcmen='1' and tcmaddr_comp(r.d1vaddr(31 downto 16),r.dtcmaddr,dtcmen,dtcmabits)='1' then
        dtcmhit := '1';
        dhit := '1';
        dhitv := (others => '0');
        dway := "00";
        odco.data(0) := cramo.dtcmdout;
        if r.holdn='1' then
          if ( (dci.read='1' and r.d1su='0' and r.dtcmperm(0)='0') or
               (dci.write='1' and r.d1su='0' and r.dtcmperm(1)='0') or
               (dci.read='1' and r.d1su='1' and r.dtcmperm(2)='0') or
               (dci.write='1' and r.d1su='1' and r.dtcmperm(3)='0') ) then
            odco.mexc := '1';
          end if;
        end if;
      end if;
    end if;

    odco.way := dway;

    dasi := r.d1asi;
    dspecialasi := r.d1specialasi;
    dforcemiss := r.d1forcemiss;
    dsu := r.d1su;
    if r.holdn='0' then
      dasi := r.d2asi;
      dspecialasi := r.d2specialasi;
      dforcemiss := r.d2forcemiss;
      dsu := r.d2su;
    end if;

    dlock := dci.lock;
    if r.holdn='0' then dlock := r.d2lock; end if;

    -- Hit/miss checking logic (v.dmisspend,v.dflushpend,fastwr propagates to main FSM)
    -- Stage 2 DTLB update in case of hit
    if notx(r.d2vaddr) then
      dlruent := r.dlru(to_integer(unsigned(r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW))));
    else
      setx(dlruent);
    end if;
    if r.holdn='1' then
      vway := "00";
      vhit := '0';
      for x in r.d2hitv'range loop
        if r.d2hitv(x)='1' then
          vhit:='1';
          vway:=vway or to_unsigned(x,2);
        end if;
      end loop;
      if vhit='1' then
        v.dlru(to_integer(unsigned(r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW)))) := calc_lruent(dlruent,vway,DWAYS);
      end if;
    end if;
    -- Stage 1 tag check
    fastwr := '0';
    fastwr_nb64 := '0';
    fastwr_wcomb := '0';
    dwriting := '0';
    v.d2tlbclr := '0';
    if r.holdn='1' then
      v.d2hitv := (others => '0');
      v.d2tlbhit := '0';
      v.d2tlbamatch := '0';
      v.d2write := '0';
      v.d2tcmhit := '0';
    end if;
    -- Write combining logic
    --   create mask of valid store buffer entries
    wrcomb_valid := "0000";
    if notx(r.d2stbw) and notx(r.d2stbd) then
      for x in 0 to 3 loop
        if r.stbuffull='1' and r.d2stbw=r.d2stbd then
          wrcomb_valid(x) := '1';
        else
          if unsigned(r.d2stbw) > unsigned(r.d2stbd) and unsigned(r.d2stbd) <= x and unsigned(r.d2stbw) > x then
            wrcomb_valid(x) := '1';
          end if;
          if unsigned(r.d2stbw) < unsigned(r.d2stbd) and (unsigned(r.d2stbd) <= x or unsigned(r.d2stbw) > x) then
            wrcomb_valid(x) := '1';
          end if;
        end if;
        -- clear valid for any entries that are already in progress on AHB bus
        if r.s=as_store then
          if r.ahb_htrans(1)='1' and r.d2stba=std_logic_vector(to_unsigned(x,2)) then
            wrcomb_valid(x) := '0';
          end if;
          if r.ahb2_inacc='1' and r.d2stbd=std_logic_vector(to_unsigned(x,2)) then
            wrcomb_valid(x) := '0';
          end if;
        end if;
      end loop;
    else
      setx(wrcomb_valid);
    end if;
    dbg(12 downto 9) <= wrcomb_valid;
    for x in 0 to 3 loop
      wrcomb_nvalid(x) := wrcomb_valid((x+1) mod 4);
      -- avoid checking for write combining across wrapping point when store buffer
      -- is full.
      if r.stbuffull='1' and r.d2stbd=std_logic_vector(to_unsigned((x+1) mod 4, 2)) then
        wrcomb_nvalid(x) := '0';
      end if;
    end loop;
    for x in 0 to 3 loop
      -- Check address write combining
      if wrcomb_valid(x)='1' and wrcomb_nvalid(x)='1' then
        if r.d2stbuf(x).size="11" and r.d2stbuf((x+1) mod 4).size="11" and
          r.d2stbuf(x).addr(31 downto 5)=r.d2stbuf((x+1) mod 4).addr(31 downto 5) and
          r.d2stbuf(x).su=r.d2stbuf((x+1) mod 4).su and
          r.d2stbuf(x).addr(4 downto 3)/="11" and
          add(r.d2stbuf(x).addr(4 downto 3),1)=r.d2stbuf((x+1) mod 4).addr(4 downto 3) and
          r.d2stbuf(x).snoopmask=r.d2stbuf((x+1) mod 4).snoopmask and
          r.d2stbuf(x).maskwtrap=r.d2stbuf((x+1) mod 4).maskwtrap then
          v.d2stbuf(x).wcomb(1) := '1';
        else
          v.d2stbuf(x).wcomb := "00";
        end if;
      end if;
    end loop;
    if r.d1chk='1' and (r.dbgacc(1)='1' or r.holdn='1') then
      v.d2vaddr := r.d1vaddr;
      v.d2data := dci.edata;
      v.d2write := dci.write and not dci.nullify;
      if r.dbgacc(1)='1' then v.d2write := r.dbgaccwr; end if;
      v.d2paddr := dtlbpaddr;
      v.d2paddrv := dtlbhit;
      v.d2tlbhit := dtlbhit;
      v.d2tlbclr := dtlbclr;
      v.d2tlbamatch := dtlbamatch;
      v.d2tlbid := dtlbid;
      v.d2tlbmod := dtlbmod;
      v.d2hitv := dhitv;
      v.d2validv := dvalidv;
      v.d2size := dci.size;
      v.d2busw := dtlbbusw;
      v.d2asi := r.d1asi;
      v.d2lock := dci.lock;
      v.d2su := r.d1su;
      v.d2specialasi := r.d1specialasi;
      v.d2forcemiss := r.d1forcemiss;
      v.d2nocache := not dtlbcached;
      v.d2stbuf(to_integer(unsigned(r.d2stbw))).addr := v.d2paddr;
      v.d2stbuf(to_integer(unsigned(r.d2stbw))).size := v.d2size;
      v.d2stbuf(to_integer(unsigned(r.d2stbw))).data := v.d2data;
      v.d2stbuf(to_integer(unsigned(r.d2stbw))).snoopmask := (others => (not v.d2nocache));
      v.d2stbuf(to_integer(unsigned(r.d2stbw))).su := v.d2su;
      v.d2stbuf(to_integer(unsigned(r.d2stbw))).nb64 := '0';
      v.d2stbuf(to_integer(unsigned(r.d2stbw))).wcomb := "00";
      v.d2stbuf(to_integer(unsigned(r.d2stbw))).maskwtrap := '0';
      if v.d2size="11" and (r.cctrl.wcomben='1' or r.dwchint='1') then
        v.d2stbuf(to_integer(unsigned(r.d2stbw))).wcomb := "01";
      end if;
      if v.d2size="11" and v.d2busw='0' then
        v.d2stbuf(to_integer(unsigned(r.d2stbw))).nb64 := '1';
      end if;
      v.d2specread := dci.specread;
      if r.dbgacc(1)='1' then v.d2specread := '0'; end if;
      v.d2tcmhit := dtcmhit;
      -- Set dcmiss pending bit for load cache miss
      if (dci.nullify='0' or r.dbgacc(1)='1') and not (dhit='1' and dforcemiss='0' and dspecialasi='0' and dci.lock='0') and (dci.read='1' or (r.dbgacc(1)='1' and r.dbgaccwr='0')) then
        v.dmisspend := '1';
      end if;
      -- Cache update for writes
      --   generate ocrami.ddatawrite independently of dci.nullify to avoid
      --     nullify -> ddatawrite -> ddatain path via data loopback
      if ((dci.nullify='0' and dci.write='1') or r.dbgaccwr='1') and r.d1ten='1' and r.d1specialasi='0' then
        ocrami.ddataen(0 to DWAYS-1) := dhitv;
        -- moved to separate if-statement below:
        --   dwriting := '1';
        --   ocrami.ddatawrite := getdmask64(r.d1vaddr,dci.size,ENDIAN);
      end if;
      if dci.nullify='0' and r.d1tcmen='1' and dci.write='1' and r.d1specialasi='0' then
        ocrami.dtcmen := dtcmhit;
      end if;
      if (r.d1ten='1' or r.d1tcmen='1') and (dci.write='1' or r.dbgaccwr='1') and r.d1specialasi='0' then
        dwriting := '1';
        ocrami.ddatawrite := getdmask64(r.d1vaddr,dci.size,ENDIAN);
      end if;
      -- Store buffer update for writes
      if dci.nullify='0' and dci.write='1' and dtcmhit='0' then
        dbg(1) <= '1';
        if v.d2paddrv='1' and v.d2tlbmod='1' and r.fastwr_rdy='1' and
          dspecialasi='0' and dci.lock='0' then
          -- Fast write path (TLB hit, written set in PTE, wide bus, store buffer
          -- idle, and standard ASIs)
          fastwr := '1';
          if v.d2busw='0' and v.d2size="11" then
            fastwr_nb64 := '1';
          end if;
          if v.d2size="11" and (r.cctrl.wcomben='1' or r.dwchint='1') then
            fastwr_wcomb := '1';
          end if;
        else
          -- Slow write path (TLB miss, written not set in PTE, narrow bus, store buffer
          -- busy, or special ASI)
          dbg(2) <= '1';
          v.slowwrpend := '1';
        end if;
      end if;
      if ddblhit='1' then
        v.ctrappend(1) := '1';
      end if;
    end if;

    -- Stage 0 address to tag ram
    dtenall := ((r.holdn and dci.eenaddr) or (r.ramreload and r.d1chk));
    if dtenall='1' and r.cctrl.dcs(0)='1' then
      ocrami.dtagcen := (others => '1');
      if dwriting = '0' then
        ocrami.ddataen := (others => '1');
      end if;
    end if;
    dtcmact := '0';
    if r.dtcmenp='1' and r.mmctrl1.e='0' then dtcmact := '1'; end if;
    if r.dtcmenva='1' and r.mmctrl1.e='1' then dtcmact := '1'; end if;
    if r.dtcmenvc='1' and r.mmctrl1.e='1' and r.mmctrl1.ctx=r.dtcmctx then dtcmact:='1'; end if;
    if dtenall='1' and dtcmact='1' and dwriting='0' then
      ocrami.dtcmen := '1';
    end if;

    -- force re-read in case of snoop hit to ensure updated valid bits propagate
    if dtagconf=0 then ocrami.dtagcen(0 to DWAYS-1) := ocrami.dtagcen(0 to DWAYS-1) or rs.s3hit; end if;
    if r.holdn='1' then
      v.d1ten := dci.eenaddr and r.cctrl.dcs(0);
      v.d1tcmen := dci.eenaddr and dtcmact;
      v.d1chk := dci.eenaddr;
      v.d1vaddr := dci.eaddress;
      v.d1asi := dci.easi;
      v.d1su := v.d1asi(0);
      v.d1forcemiss := '0';
      v.d1specialasi := '0';
      if v.d1asi(7 downto 1)="0000000" then
        v.d1forcemiss := '1';
        v.d1su:='1';
      elsif v.d1asi(4 downto 0)/=ASI_UDATA and v.d1asi(4 downto 0)/=ASI_SDATA then
        v.d1specialasi := '1';
      end if;
    end if;

    -- Flushing from IU
    if r.holdn='1' and dci.flush='1' then
      v.iflushpend := '1';
      v.dflushpend := '1';
    end if;


    --------------------------------------------------------------------------
    -- DCache AHB snooping and Dtag write port pipeline
    --------------------------------------------------------------------------
    -- grant status with ungated clock for the snooping
    if ahbi.hready='1' then
      vs.sgranted := ahbi.hgrant(hindex);
    end if;

    -- Stage 4 virtual tag update commit (inside SRAM)
    -- Stage 3 virtual tag update to RAM
    ocrami.dtaguindex(DOFFSET_BITS-1 downto 0) := rs.s3offs;
    ocrami.dtaguwrite(0 to DWAYS-1) := rs.s3hit or rs.s3read;
    for i in DWAYS-1 downto 0 loop
      ocrami.dtagudin(i)(DTAG_HIGH-DTAG_LOW+1 downto 0) := rs.s3tag & rs.s3read(i);
      ocrami.dtagudin(i)(DTAG_HIGH-DTAG_LOW+1 downto DTAG_HIGH-DTAG_LOW) := rs.s3tagmsb(2*i+1 downto 2*i);
    end loop;
    vvalidset := rs.s3read;
    vvalidclr := rs.s3hit;
    vvalididx := rs.s3offs;
    vs.dlctr := (others => '0');
    vs.raisereq := '0';
    -- Setup address and data inputs for diag access if no snoop tag update
    if rs.s3hit=(rs.s3hit'range=>'0') and rs.s3read=(rs.s3read'range=>'0') then
      vvalididx := rs.dtaccidx;
    end if;
    if (dtagconf/=0 or rs.s3hit=(rs.s3hit'range=>'0')) and rs.s3read=(rs.s3read'range=>'0') and
      rs.s3flush=(rs.s3flush'range=>'0') then
      ocrami.dtaguindex(DOFFSET_BITS-1 downto 0) := rs.dtaccidx;
      for i in 0 to DWAYS-1 loop
        ocrami.dtagudin(i)(DTAG_HIGH-DTAG_LOW+1 downto 0) := r.dtagpipe(i)(DTAG_HIGH-DTAG_LOW+1 downto 0);
        if rs.dtacctagmod='1' then
          ocrami.dtagudin(i)(DTAG_HIGH-DTAG_LOW+1 downto DTAG_HIGH-DTAG_LOW) := rs.dtacctagmsb(2*i+1 downto 2*i);
          ocrami.dtagudin(i)(0) := rs.dtacctaglsb(i);
        end if;
      end loop;
    end if;
    -- Inject diagnostic tag writes during idle cycles
    if rs.dtwrite='1' then
      if rs.dlctr /= (rs.dlctr'range => '1') then
        vs.dlctr := std_logic_vector(unsigned(rs.dlctr)+1);
      end if;
      if ( rs.s3hit=(rs.s3hit'range=>'0') and rs.s3read=(rs.s3read'range=>'0') and
           rs.s3flush=(rs.s3flush'range=>'0') ) then
        vs.dtwrite := '0';
        ocrami.dtaguwrite(0 to DWAYS-1) := rs.dtaccways;
        for w in 0 to DWAYS-1 loop
          if rs.dtaccways(w)='1' then
            if ocrami.dtagudin(w)(0)='0' then
              vvalidclr(w) := '1';
            else
              vvalidset(w) := '1';
            end if;
          end if;
        end loop;
      elsif rs.dlctr=(rs.dlctr'range=>'1') then
        vs.raisereq := '1';
      end if;
    end if;
    if notx(vvalididx) then
      vs.validarr(to_integer(unsigned(vvalididx))) :=
        (vs.validarr(to_integer(unsigned(vvalididx))) and (not vvalidclr)) or vvalidset;
    else
      if vvalidclr /= (vvalidclr'range => '0') or vvalidset /= (vvalidset'range => '0') then
        for x in vs.validarr'range loop setx(vs.validarr(x)); end loop;
      end if;
    end if;
    -- Stage 2 snoop tag compare
    vs.s3hit := (others => '0');
    for i in DWAYS-1 downto 0 loop
      if rs.s2en(i)='1' then
        if cramo.dtagsdout(i)(DTAG_HIGH-DTAG_LOW+1 downto 1)=rs.s2tag then
          vs.s3hit(i) := '1';
        end if;
      end if;
    end loop;
    vs.s3hit := vs.s3hit or rs.s2flush;
    vs.s3read := (others => '0');
    vs.s3tag := rs.s2tag;
    vs.s3read := rs.s2read;
    vs.s3offs := rs.s2offs;
    vs.s3tagmsb := rs.s2tagmsb;
    vs.s3flush := rs.s2flush;
    -- collect data for external read
    vs.strddone := '0';
    if rs.s2eread='1' then
      vs.strddone := '1';
      for w in 0 to DWAYS-1 loop
        if rs.staccways(w)='1' then
          vs.stacctag := cramo.dtagsdout(w)(DTAG_HIGH-DTAG_LOW+1 downto 1);
        end if;
      end loop;
    end if;
    -- Stage 1
    --  send address to snoop to snoop tag RAM
    --  or send address and data to update snoop tag
    ocrami.dtagsindex(DOFFSET_BITS-1 downto 0) := rs.s1haddr(DOFFSET_HIGH downto DOFFSET_LOW);
    ocrami.dtagsen(0 to DWAYS-1) := rs.s1en;
    if rs.s1read='1' then
      ocrami.dtagswrite := '1';
      ocrami.dtagsen(0 to DWAYS-1) := r.d2hitv;
    end if;
    for w in 0 to DWAYS-1 loop
      ocrami.dtagsdin(w)(DTAG_HIGH-DTAG_LOW+1 downto 1) := rs.s1haddr(DTAG_HIGH downto DTAG_LOW);
      ocrami.dtagsdin(w)(DTAG_HIGH-DTAG_LOW+1 downto DTAG_HIGH-DTAG_LOW) := rs.s1tagmsb(2*w+1 downto 2*w);
    end loop;
    vs.s2en := rs.s1en and not rs.s1flush;
    vs.s2tag := rs.s1haddr(DTAG_HIGH downto DTAG_LOW);
    vs.s2offs := rs.s1haddr(DOFFSET_HIGH downto DOFFSET_LOW);
    vs.s2read := (others => '0');
    if rs.s1read='1' then
      vs.s2read := r.d2hitv;
    end if;
    vs.s2read := vs.s2read and not rs.s1flush;
    vs.s2flush := rs.s1flush;
    vs.s2tagmsb := rs.s1tagmsb;
    if rs.s1flush /= (rs.s1flush'range => '0') then
      ocrami.dtagsen(0 to DWAYS-1) := rs.s1flush;
      vs.s2read := (others => '0');
    end if;
    vs.s2eread := '0';
    if rs.s1en=(rs.s1en'range=>'0') and rs.s1read='0' and rs.s1flush=(rs.s1flush'range => '0') then
      ocrami.dtagsindex(DOFFSET_BITS-1 downto 0) := rs.staccidx;
      for w in 0 to DWAYS-1 loop
        ocrami.dtagsdin(w)(DTAG_HIGH-DTAG_LOW+1 downto 1) := rs.stacctag;
      end loop;
      vs.s2offs := rs.staccidx;
      vs.s2tag := rs.stacctag;
      for w in 0 to DWAYS-1 loop
        vs.s2tagmsb(2*w+1 downto 2*w) := rs.stacctag(DTAG_HIGH-DTAG_LOW+1 downto DTAG_HIGH-DTAG_LOW);
      end loop;
    end if;
    if rs.stwrite='1' or rs.stread='1' then
      if rs.dlctr /= (rs.dlctr'range => '1') and rs.s1flush=(rs.s1flush'range=>'0') then
        vs.dlctr := std_logic_vector(unsigned(rs.dlctr)+1);
      end if;
      -- mux in diagnostic tag access if RAM is available this cycle
      if rs.s1en=(rs.s1en'range=>'0') and rs.s1read='0' and rs.s1flush=(rs.s1flush'range => '0') then
        if rs.stwrite='1' then
          vs.stwrite :=  '0';
          ocrami.dtagsen(0 to DWAYS-1) := rs.staccways;
          ocrami.dtagswrite := '1';
          ocrami.dtagsindex(DOFFSET_BITS-1 downto 0) := rs.staccidx;
        elsif rs.stread='1' and rs.strdstarted='0' then
          vs.s2eread := '1';
          ocrami.dtagsen(0 to DWAYS-1) := rs.staccways;
          vs.strdstarted := '1';
          ocrami.dtagsen := (others => '1');
          ocrami.dtagswrite := '0';
        end if;
      elsif rs.dlctr=(rs.dlctr'range => '1') then
        vs.raisereq := '1';
      end if;
    end if;
    if rs.strdstarted='1' and rs.strddone='1' then
      vs.stread := '0';
      vs.strdstarted := '0';
    end if;
    -- AMBA error register handling
    if ahbsi.hready='1' then
      if rs.s1htrans0='0' then
        vs.errburstfilt := '0';
      end if;
      if ahbi.hresp="01" then
        vs.errburstfilt := '1';
        if rs.s1htrans0='0' or rs.errburstfilt='0' then
          if r.ahb2_inacc='1' then
            vs.ahberr := '1';
            if rs.ahberr='1' then
              vs.ahberrm := '1';
            end if;
            if r.ahb2_ifetch='1' then
              vs.ahberracc(0) := '1';
            end if;
            if r.ahb2_dacc='1' and r.ahb2_hwrite='0' then
              vs.ahberracc(1) := '1';
            end if;
            if r.ahb2_dacc='1' and r.ahb2_hwrite='1' then
              vs.ahberracc(2) := '1';
            end if;
            if r.ahb2_ifetch='0' and r.ahb2_dacc='0' and r.ahb_hwrite='0' then
              vs.ahberracc(3) := '1';
            end if;
            if r.ahb2_ifetch='0' and r.ahb2_dacc='0' and r.ahb_hwrite='1' then
              vs.ahberracc(4) := '1';
            end if;
          else
            vs.ahboerr := '1';
            if rs.ahboerr='1' then
              vs.ahboerrm := '1';
            end if;
          end if;
        end if;
      end if;
    end if;
    if rs.ahberr='0' then
      if r.ahb2_ifetch='1' then
        vs.ahberrtype := "00";
      elsif r.ahb2_dacc='1' then
        vs.ahberrtype := "01";
      else
        vs.ahberrtype := "10";
      end if;
    end if;
    if (vs.ahberr='1' and rs.ahberr='0') or (rs.ahberr='0' and rs.ahboerr='0') then
      vs.ahberrhaddr := rs.s1haddr;
      vs.ahberrhwrite := rs.s1hwrite;
      vs.ahberrhsize := rs.s1hsize;
      vs.ahberrhmaster := rs.s1hmaster;
    end if;
    -- Stage 0 get address from AHB bus
    vs.s1en := (others => '0');
    vs.s1read := '0';
    vs.s1flush := (others => '0');
    if ahbsi.hready='1' then
      vs.s1haddr := ahbsi.haddr;
      vs.s1hwrite := ahbsi.hwrite;
      vs.s1hsize := ahbsi.hsize;
      vs.s1hmaster := ahbsi.hmaster;
      vs.s1htrans0 := ahbsi.htrans(0);
    end if;
    if ahbsi.hready='1' and ahbsi.htrans(1)='1' and ahbsi.hwrite='1' and r.cctrl.dsnoop='1' then
      if rs.sgranted='0' then
        vs.s1en := (others => '1');
      else
        vs.s1en := not r.ahb_snoopmask;
      end if;
    elsif ahbsi.hready='1' and ahbsi.htrans="10" and ahbsi.hwrite='0' and rs.sgranted='1' then
      -- Note in first cycle of dcfetch we do not know which set will be used
      if r.s=as_dcfetch and r.ahb_retrying='0' then
        vs.s1read := '1';
      end if;
    end if;
    for x in 0 to DWAYS-1 loop
      vs.s1tagmsb(2*x+1 downto 2*x) := vs.s1haddr(DTAG_HIGH downto DTAG_HIGH-1);
    end loop;

    --------------------------------------------------------------------------
    -- MMU TLB update logic
    --------------------------------------------------------------------------
    -- TLB update
    if r.i2tlbclr='1' then
      v.itlb(to_integer(unsigned(r.i2tlbid))).valid := '0';
    end if;
    if r.d2tlbclr='1' then
      v.dtlb(to_integer(unsigned(r.d2tlbid))).valid := '0';
    end if;
    if r.tlbupdate='1' then
      if r.mmusel(0)='0' and r.i2tlbhit='1' then
        v.itlb(to_integer(unsigned(r.i2tlbid))) := r.newent;
      end if;
      if r.mmusel(0)='1' and r.d2tlbhit='1' then
        v.dtlb(to_integer(unsigned(r.d2tlbid))) := r.newent;
      end if;
    end if;
    v.tlbupdate := '0';

    -- Set default 1:1 mapping if MMU disabled
    if r.mmctrl1.e='0' then
      v.dtlb(0) := tlbent_defmap;
      v.itlb(0) := tlbent_defmap;
    end if;
    -- Clear valid bits on flush or TLB disable
    if r.tlbflush='1' or r.mmctrl1.e='0' then
      for x in 0 to dtlbnum-1 loop
        v.dtlb(x).valid := '0';
      end loop;
      for x in 0 to itlbnum-1 loop
        v.itlb(x).valid := '0';
      end loop;
    end if;
    v.tlbflush := '0';

    -- Generate decoded accesses permissions for each TLB entry
    for x in 0 to dtlbnum-1 loop
      vtmp3 := ft_acc_resolve("000", v.dtlb(x).acc);
      v.dtlb(x).perm(0) := not vtmp3(1);
      vtmp3 := ft_acc_resolve("100", v.dtlb(x).acc);
      v.dtlb(x).perm(1) := not vtmp3(1);
      vtmp3 := ft_acc_resolve("001", v.dtlb(x).acc);
      v.dtlb(x).perm(2) := not vtmp3(1);
      vtmp3 := ft_acc_resolve("101", v.dtlb(x).acc);
      v.dtlb(x).perm(3) := not vtmp3(1);
    end loop;
    for x in 0 to itlbnum-1 loop
      vtmp3 := ft_acc_resolve("010", v.itlb(x).acc);
      v.itlb(x).perm(0) := not vtmp3(1);
      v.itlb(x).perm(1) := '0';
      vtmp3 := ft_acc_resolve("011", v.itlb(x).acc);
      v.itlb(x).perm(2) := not vtmp3(1);
      v.itlb(x).perm(3) := '0';
    end loop;

    -- Set pseudo-MRU bit for touched entry
    if r.d2tlbhit='1' and r.holdn='1' and r.d2specialasi='0' then
      v.dtlbpmru(to_integer(unsigned(r.d2tlbid))) := '1';
    end if;
    if r.i2tlbhit='1' and r.holdn='1' then
      v.itlbpmru(to_integer(unsigned(r.i2tlbid))) := '1';
    end if;
    -- Reset pseudo-MRU once all bits set
    --   single-cycle window where all are set need to be handled
    if r.dtlbpmru=(r.dtlbpmru'range => '1') then
      v.dtlbpmru := (others => '0');
    end if;
    if r.itlbpmru=(r.itlbpmru'range => '1') then
      v.itlbpmru := (others => '0');
    end if;
    -- Clear pseudo-MRU bits for TLB entries that are not valid
    --  (using v.valid to avoid single-cycle window)
    for x in 0 to dtlbnum-1 loop
      if v.dtlb(x).valid='0' then v.dtlbpmru(x) := '0'; end if;
    end loop;
    for x in 0 to itlbnum-1 loop
      if v.itlb(x).valid='0' then v.itlbpmru(x) := '0'; end if;
    end loop;

    -- MMU fault status register handling
    if r.mmuerr.fav='1' then
      if r.mmfsr.fav='0' or unsigned(r.newerrclass) > unsigned(r.curerrclass) then
        v.mmfsr := r.mmuerr;
        v.mmfar := r.newent.vaddr;
        v.curerrclass := r.newerrclass;
      elsif r.mmfsr.fav='1' and r.newerrclass=r.curerrclass then
        -- overwrite with the new error and set overwrite flag
        v.mmfsr := r.mmuerr;
        v.mmfar := r.newent.vaddr;
        v.mmfsr.ow := '1';
      end if;
    end if;
    v.mmuerr.ow := '0';
    v.mmuerr.ebe := (others => '0');



    ---------------------------------------------------------------------------
    -- Region flush
    ---------------------------------------------------------------------------

    v.regflpipe(0 to r.regflpipe'high-1) := r.regflpipe(1 to r.regflpipe'high);
    v.regflpipe(r.regflpipe'high).valid := '0';
    v.regflpipe(r.regflpipe'high).addr := r.flushctr;

    -- Stage 4: Write back commit
    --   inside SRAMs
    -- Stage 3: Command write back in case of match
    --  handled in FSM
    -- Stage 2: Compare with region flush mask
    v.regflpipe(0) := r.regflpipe(1);
    frdmatch := (others => '0');
    for x in 0 to DWAYS-1 loop
      if ( (r.dtagpipe(x)(DTAG_HIGH-DTAG_LOW+1 downto 1) and r.regflmask(DTAG_HIGH downto DTAG_LOW))
           = r.regfladdr(DTAG_HIGH downto DTAG_LOW) ) then
        frdmatch(x) := '1';
      end if;
    end loop;
    v.flushwrd := frdmatch;
    frimatch := (others => '0');
    for x in 0 to IWAYS-1 loop
      if ( (r.itagpipe(x)(ITAG_HIGH-ITAG_LOW+1 downto 1) and r.regflmask(ITAG_HIGH downto ITAG_LOW))
           = r.regfladdr(ITAG_HIGH downto ITAG_LOW) ) then
        frimatch(x) := '1';
      end if;
    end loop;
    v.flushwri := frimatch;
    -- compute unique msb:s for the tags we are replacing to avoid duplicate tags
    for x in 0 to DWAYS-1 loop
      frmsbd(2*x+1 downto 2*x) := r.dtagpipe(x)(DTAG_HIGH-DTAG_LOW+1 downto DTAG_HIGH-DTAG_LOW);
    end loop;
    v.untagd := uniquemsb(frmsbd, frdmatch);
    for x in 0 to IWAYS-1 loop
      frmsbi(2*x+1 downto 2*x) := r.itagpipe(x)(ITAG_HIGH-ITAG_LOW+1 downto ITAG_HIGH-ITAG_LOW);
    end loop;
    v.untagi := uniquemsb(frmsbi, frimatch);

    -- Stage 1: Capture tags
    v.regflpipe(1) := r.regflpipe(2);
    v.dtagpipe := dctagsv;
    v.itagpipe := cramo.itagdout;

    -- Stage 0: Read from tag RAMs, done in main FSM


    --------------------------------------------------------------------------
    -- AHB access state machine
    --------------------------------------------------------------------------
    if ahbi.hready='1' then
      -- this captures granted with the gated CPU clock. powerdown state ensures
      -- this is synced up when starting up the clock again before any AHB
      -- accesses are done.
      v.granted := ahbi.hgrant(hindex);
    end if;
    -- Flag set by FSM to indicate next cycles access is not the last so hbusreq
    -- should be kept high
    keepreq := '0';

    -- use read buffer also for write combining
    if r.s=as_wrcomb1 then
      for x in 0 to 3 loop
        if r.d2stbuf(to_integer(unsigned(r.d2stba))).addr(4 downto 3)=std_logic_vector(to_unsigned(x,2)) then
          if (not ENDIAN) then
            v.ahb3_rdbuf((3-x)*64+63 downto (3-x)*64) := r.d2stbuf(to_integer(unsigned(r.d2stba))).data;
          else
            v.ahb3_rdbuf(x*64+63 downto x*64) := r.d2stbuf(to_integer(unsigned(r.d2stba))).data;
          end if;
        end if;
      end loop;
    end if;

    if r.dcerrmask='1' or r.ahb2_ifetch='1' then
      for x in LINESZMAX-1 downto 0 loop
        if r.ahb3_rdberr(x)='1' then
          v.ahb3_rdbuf((x+1)*32-1 downto x*32) := (others => (r.dcerrmaskval and not r.ahb2_ifetch));
        end if;
      end loop;
    end if;
    -- Read data buffer pipeline, advance with AHB hready
    if ahbi.hready='1' then
      dbg(3) <= '1';
      v.ahb3_inacc := r.ahb2_inacc;
      if r.ahb2_inacc='1' and r.ahb2_hwrite='0' then
        dbg(4) <= '1';
        if ahbi.hresp="01" then
          v.ahb3_error := '1';
        end if;
        for x in LINESZMAX-1 downto 0 loop
          if r.ahb2_addrmask(x)='1' then
            v.ahb3_rdbuf((x+1)*32-1 downto x*32) := ahbi.hrdata((((x+1)*32-1) mod xdbusw) downto ((x*32) mod xdbusw));
          end if;
        end loop;
        if ahbi.hresp(1)='0' then
          dbg(5) <= '1';
          v.ahb3_rdbvalid := v.ahb3_rdbvalid or r.ahb2_addrmask;
        end if;
      end if;
      if r.ahb2_inacc='1' and r.ahb2_hwrite='1' then
        if ahbi.hresp="01" then
          if r.ahb2_dacc='1' then
            if r.ahb2_maskwtrap='0' and vmaskwtrap(0)='0' then
              v.wtrappend(0) := '1';
            else
              v.wtraplost(0) := '1';
            end if;
          else
            if r.ahb2_maskwtrap='0' and vmaskwtrap(1)='0' then
              v.wtrappend(1) := '1';
            else
              v.wtraplost(1) := '1';
            end if;
          end if;
        end if;
      end if;
      if r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
        v.ahb_retrying := '1';
      else
        v.ahb_retrying := '0';
      end if;
      v.ahb2_inacc := r.granted and r.ahb_htrans(1);
      v.ahb2_hwrite := r.ahb_hwrite;
      v.ahb2_addrmask := getvalidmask(r.ahb_haddr(4 downto 2), r.ahb_hsize, ENDIAN);
      v.ahb2_ifetch := '0';
      if r.s=as_icfetch then v.ahb2_ifetch:='1'; end if;
      v.ahb2_dacc := '0';
      if v.s=as_store or v.s=as_dcfetch or v.s=as_dcsingle then
        v.ahb2_dacc := '1';
      end if;
      v.ahb2_haddr42 := r.ahb_haddr(4 downto 2);
      v.ahb2_hburst0 := r.ahb_hburst(0);
      v.ahb2_hsize10 := r.ahb_hsize(1 downto 0);
      v.ahb2_maskwtrap := r.ahb_maskwtrap;
    end if;
    v.ahb3_rdbvalid := v.ahb3_rdbvalid or r.ahb3_rdberr;
    -- set rdberr during first cycle of response to get another cycle to clear
    -- ahb3_rdbuf if needed (to simplify logic both cycles of error response)
    -- we also clear ahb2_addrmask during the first cycle of the response to
    -- allow the assignment of hrdata to ahb3_rdbuf to be muxed in last without
    -- any extra masking logic needed afterwards
    if ahbi.hready='0' and ahbi.hresp="01" and (r.dcerrmask='1' or r.ahb2_ifetch='1') then
      v.ahb2_addrmask := (others => '0');
    end if;
    if ahbi.hresp="01" and r.ahb2_inacc='1' and r.ahb2_hwrite='0' then
      v.ahb3_rdberr := v.ahb3_rdberr or r.ahb2_addrmask;
    end if;

    -- Read data from 32/64 bit single reads
    rdb32 := (others => '0');
    rdb32v := '0';
    -- rdb64 := (others => '0');
    for x in r.ahb3_rdbvalid'range loop
      if r.ahb3_rdbvalid(x)='1' then
        rdb32v := '1';
        -- rdb64v := '1';
        rdb32 := rdb32 or r.ahb3_rdbuf(x*32+31 downto x*32);
--        rdb64(((x*32+31) mod 64) downto ((x*32) mod 64)) :=
--          rdb64(((x*32+31) mod 64) downto ((x*32) mod 64)) or r.ahb3_rdbuf(x*32+1 downto x*32);
      end if;
    end loop;

    -- Speculative load handling
    if r.dmisspend='1' and r.d2specread='1' then
      if dci.specreadannul='1' then
        v.dmisspend := '0';
      else
        v.d2specread := '0';
      end if;
    end if;

    -- memory barrier
    if dci.bar(1 downto 0) /= "00" and r.holdn='1' then
      -- for now the store/load barrier is implemented as a full synchronizing
      -- barrier for simplicity. This case may be optimized later.
      v.syncbar := '1';
    end if;
    -- write combining hint
    if dci.bar(2)/='0' and r.holdn='1' then
      v.dwchint := '1';
    end if;
    if r.holdn='1' and dci.trapack='1' then
      -- drop write hint on trap
      v.dwchint := '0';
    end if;
    if r.cctrl.wchinten='0' then
      v.dwchint := '0';
    end if;

    v.newent.valid := '1';
    v.dtlbrecheck := '0';
    v.fpc_mosi.accen := '0';
    v.fpc_mosi.accwr := '0';
    v.fpc_mosi.addr(v.fpc_mosi.addr'high downto 1) := r.d2vaddr(v.fpc_mosi.addr'high+2 downto 3);
    v.c2c_mosi.accen := '0';
    v.c2c_mosi.accwr := '0';
    v.c2c_mosi.addr(v.fpc_mosi.addr'high downto 1) := r.d2vaddr(v.fpc_mosi.addr'high+2 downto 3);
    v.iudiag_mosi.accen := '0';
    v.iudiag_mosi.accwr := '0';
    v.iudiag_mosi.addr(v.fpc_mosi.addr'high downto 1) := r.d2vaddr(v.fpc_mosi.addr'high+2 downto 3);
    v.ctxswitch := '0';
    vstd32 := (others => '0');
    vstd32set := '0';
    vstd64 := (others => '0');
    vstd64set := '0';
    vstd128 := (others => '0');
    vstd128set := '0';
    vstoresu := v.d2su;
    v.fsmidle := '0';
    case r.s is
      when as_normal =>
        v.ramreload := '0';
        v.ahb_htrans := "00";
        v.ahb_hwrite := '0';
        v.ahb_hburst := HBURST_INCR;
        v.ahb_snoopmask := (others => '0');
        v.ahb_maskwtrap := '0';
        if v.d2nocache='0' then
          v.ahb_snoopmask := (others => '1');
        end if;
        v.ahb3_error := '0';
        v.ahb3_rdbvalid := (others => '0');
        v.ahb3_rdberr := (others => '0');
        v.mmusel := "000";
        v.flushctr := (others => '0');
        v.flushpart := v.iflushpend & v.dflushpend;
        v.dtflushdone := '0';
        v.regfldone := '0';
        v.iramaddr := (others => '0');
        v.irdbufen := '0';
        v.dramaddr := (others => '0');
        v.dvtagdone := '0';
        v.dregerr := '0';
        v.newent.mask1 := '0';
        v.newent.mask2 := '0';
        v.newent.mask3 := '0';
        v.d2stbw := "00";
        v.d2stba := "00";
        v.d2stbd := "00";
        v.d2nb64en := '0';
        v.d2nb64ctr := '0';
        v.d2stbcont := '0';
        v.d2wchold := "000";
        v.stbuffull := '0';
        if r.ahb_hlock='1' and dlock='0' then
          v.ahb_hlock := '0';
        elsif fastwr='1' then
          v.ahb_htrans := "10";
          v.ahb_hburst := HBURST_SINGLE;
          v.ahb_haddr := v.d2paddr;
          v.ahb_hsize := "0" & v.d2size;
          v.ahb_hwrite := '1';
          v.d2stbw := std_logic_vector(unsigned(r.d2stbw)+1);
          v.s := as_store;
          if fastwr_nb64='1' then
            v.ahb_hburst := HBURST_INCR;
            v.ahb_hsize := "010";
            v.d2nb64en := '1';
            keepreq := '1';
          end if;
          if fastwr_wcomb='1' then
            v.ahb_htrans := "00";
          end if;
        elsif ( ((not IMISSPIPE) and v.iflushpend='1') or (IMISSPIPE and r.iflushpend='1') or
                ((not DMISSPIPE) and v.dflushpend='1') or (DMISSPIPE and r.dflushpend='1') ) then
          if r.iregflush='1' or r.dregflush='1' then
            v.s := as_regflush;
            v.flushpart := r.iregflush & r.dregflush;
            v.flushctr := r.regfladdr(DOFFSET_HIGH downto DOFFSET_LOW) and
                          r.regflmask(DOFFSET_HIGH downto DOFFSET_LOW);
          else
            v.s := as_flush;
          end if;
          v.perf(4) := '1';
        elsif ((not IMISSPIPE) and v.imisspend='1') or (IMISSPIPE and r.imisspend='1') then
          v.ahb_haddr := v.i2paddr;
          v.ahb_haddr(log2(ilinesize*4)-1 downto 0) := (others => '0');
          v.ahb_hsize := std_logic_vector(to_unsigned(log2(xbusw/8),3));
          v.mmusel := "000";
          if v.i2busw='0' then
            v.ahb_hsize := "010";
          end if;
          if v.i2paddrv='1' then
            v.ahb_htrans := "10";
            v.s := as_icfetch;
            keepreq := '1';
            v.perf(0) := '1';
          else
            v.s := as_mmuwalk;
            v.ahb_haddr := r.mmctrl1.ctxp(25 downto 4) & v.i2ctx & "00";
            v.ahb_htrans := "10";
            v.ahb_hsize := "010";
            v.ahb_hburst := HBURST_SINGLE;
            v.perf(1) := '1';
          end if;
        elsif (((not DMISSPIPE) and v.dmisspend='1') or (DMISSPIPE and r.dmisspend='1')) and v.d2specread='0' then
          v.ahb_haddr := v.d2paddr;
          v.ahb_hsize := "000";
          v.mmusel := "001";
          if v.d2lock /= r.ahb_hlock then
            v.s := as_getlock;
            v.ahb_hlock := not r.ahb_hlock;
            if r.ahb_hlock='0' then
              v.granted := '0';
            end if;
          elsif v.d2paddrv='1' and dspecialasi='0' then
            if v.d2busw='1' then
              v.ahb_hsize := std_logic_vector(to_unsigned(log2(xbusw/8),3));
              v.ahb_haddr(log2(xbusw/8)-1 downto 0) := (others => '0');
            else
              v.ahb_hsize := "010";
              v.ahb_haddr(1 downto 0) := "00";
            end if;
            if v.d2nocache='0' then
              v.ahb_htrans := "10";
              v.s := as_dcfetch;
              keepreq := '1';
              v.ahb_haddr(log2(dlinesize*4)-1 downto 0) := (others => '0');
              v.perf(2) := '1';
            else
              v.ahb_htrans := "10";
              v.ahb_hbusreq := '1';
              v.ahb_hburst := HBURST_SINGLE;
              v.s := as_dcsingle;
            end if;
          elsif dspecialasi='0' then
            v.s := as_mmuwalk;
            v.ahb_haddr := r.mmctrl1.ctxp(25 downto 4) & r.mmctrl1.ctx & "00";
            v.ahb_htrans := "10";
            v.ahb_hsize := "010";
            v.ahb_hburst := HBURST_SINGLE;
            v.perf(3) := '1';
          else
            v.s := as_rdasi;
          end if;
        elsif v.slowwrpend='1' then
          v.s := as_slowwr;
        elsif v.syncbar='1' then
          v.syncbar := '0';
          if r.d1chk='1' then v.ramreload := '1'; end if;
        else
          v.fsmidle := '1';
          if ici.parkreq='1' then
            v.s := as_parked;
          end if;
        end if;

      when as_flush =>
        if r.flushpart(1)='1' then
          v.ilru := (others => (others => '0'));
          v.i1cont := '0';
        end if;
        if r.flushpart(0)='1' then
          v.dlru := (others => (others => '0'));
        end if;
        v.flushctr := std_logic_vector(unsigned(r.flushctr)+1);
        if r.flushpart(1)='1' and v.flushctr=(v.flushctr'range => '0') then
          v.flushpart(1) := '0';
          v.iflushpend := '0';
        end if;
        if r.flushpart(0)='1' and v.flushctr=(v.flushctr'range => '0') then
          v.dtflushdone := '1';
        end if;
        if r.flushpart(0)='1' and r.dtflushdone='1' and rs.s3flush(0)='0' then
          v.flushpart(0) := '0';
          v.dflushpend := '0';
        end if;
        if v.flushpart="00" then
          v.ramreload := '1';
          v.s := as_normal;
        end if;
        ocrami.iindex := (others => '0');
        ocrami.iindex(IOFFSET_BITS-1 downto 0) :=
          r.flushctr(r.flushctr'high downto r.flushctr'high-IOFFSET_BITS+1);
        ocrami.idataoffs := (others => '0');
        ocrami.itagdin := itags_default;
        if r.flushpart(1)='1' then
          ocrami.itagen := "1111";
          ocrami.itagwrite := '1';
        end if;
        if r.flushpart(0)='1' and r.dtflushdone='0' then
          vs.s1haddr(DTAG_HIGH downto DTAG_LOW) := (others => '0');
          vs.s1haddr(DTAG_HIGH downto DTAG_HIGH-7) := x"F3";
          for x in 0 to DWAYS-1 loop
            vs.s1tagmsb(2*x+1 downto 2*x) := std_logic_vector(to_unsigned(x,2));
          end loop;
          vs.s1haddr(DOFFSET_HIGH downto DOFFSET_LOW) := r.flushctr(DOFFSET_HIGH-DOFFSET_LOW downto 0);
          vs.s1read := '1';
          vs.s1flush := (others => '1');
        end if;

      when as_icfetch =>
        v.i1ten := '0';
        if r.i2hitv=(r.i2hitv'range=>'0') and r.cctrl.ics="11" and r.irdbufen='0' then
          -- Select way to replace
          for x in 1 to IWAYS-1 loop
            if r.i2validv(x)='0' and r.i2validv(0 to x-1)=onev(x-1 downto 0) then
              v.i2hitv(x) := '1';
            end if;
          end loop;
          if r.i2validv(0)='0' then
            v.i2hitv(0) := '1';
          end if;
          if r.i2validv=(r.i2validv'range=>'1') then
            vtmp4i := dec4wrap(ilruent(4 downto 3), IWAYS);
            v.i2hitv := v.i2hitv or vtmp4i(0 to IWAYS-1);
          end if;
        end if;
        v.irdbufen := '1';
        if r.irdbufen='0' then
          v.irdbufvaddr := r.i2pc(31 downto r.irdbufvaddr'low);
          v.irdbufpaddr := r.i2paddr(31 downto r.irdbufpaddr'low);
          v.i2bufmatch := '1';
        end if;
        if ahbi.hresp(1)='1' and r.ahb2_inacc='1' then
          v.ahb_htrans := "00";
        end if;
        if ahbi.hready='1' then
          -- Advance haddr/htrans
          if r.granted='1' and (ahbi.hresp(1)='0' or r.ahb2_inacc='0') and r.ahb_htrans(1)='1' then
            -- Move haddr forward
            -- Note we can not look at r.i2busw here as it may get updated while streaming
            --   therefore we look directly at ahb_hsize instead
            if r.ahb_hsize(1 downto 0)="10" or xbusw=32 then
              v.ahb_haddr(log2(LINESZMAX*4)-1 downto 2) :=
                std_logic_vector(unsigned(r.ahb_haddr(log2(LINESZMAX*4)-1 downto 2))+1);
            else
              v.ahb_haddr(log2(LINESZMAX*4)-1 downto log2(xbusw/8)) :=
                std_logic_vector(unsigned(r.ahb_haddr(log2(LINESZMAX*4)-1 downto log2(xbusw/8)))+1);
            end if;
            v.ahb_htrans := "11";
            if (r.ahb_haddr(log2(ilinesize*4)-1 downto log2(xbusw/8))=
                onev(log2(ilinesize*4)-1 downto log2(xbusw/8))) and
              (xbusw=32 or r.ahb_hsize(1 downto 0)/="10" or r.ahb_haddr(log2(xbusw/8)-1+nbfid downto 2)=onev(log2(xbusw/8)-1+nbfid downto 2)) then
              v.ahb_htrans := "00";
            end if;
          elsif r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
            -- Move haddr backward for retry/split
            if r.ahb_hsize(1 downto 0)="10" or xbusw=32 then
              v.ahb_haddr(log2(LINESZMAX*4)-1 downto 2) :=
                std_logic_vector(unsigned(r.ahb_haddr(log2(LINESZMAX*4)-1 downto 2))-1);
            else
              v.ahb_haddr(log2(LINESZMAX*4)-1 downto log2(xbusw/8)) :=
                std_logic_vector(unsigned(r.ahb_haddr(log2(LINESZMAX*4)-1 downto log2(xbusw/8)))-1);
            end if;
            v.ahb_htrans := "10";
          end if;
        end if;
        keepreq := '1';
        if (v.ahb_haddr(log2(ilinesize*4)-1 downto log2(busw/8))=
            onev(log2(ilinesize*4)-1 downto log2(busw/8))) and
          (xbusw=32 or r.ahb_hsize(1 downto 0)/="10" or v.ahb_haddr(log2(xbusw/8)-1+nbfid downto 2)=onev(log2(xbusw/8)-1+nbfid downto 2))then
          keepreq := '0';
        end if;
        -- write read data buffer into I$ data RAM
        ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.irdbufvaddr(IOFFSET_HIGH downto IOFFSET_LOW);
        ocrami.idataoffs(log2(ilinesize)-2 downto 0) := r.iramaddr;
        if r.cctrl.ics(0)='1' and r.irdbufen='1' then
          ocrami.itagen(0 to IWAYS-1) := r.i2hitv;
          ocrami.itagwrite := '1';
          ocrami.idataen(0 to IWAYS-1) := r.i2hitv;
          ocrami.idatawrite := "11";
        end if;
        if ( ((not ENDIAN) and r.ahb3_rdbvalid(LINESZMAX-1-to_integer(unsigned(r.iramaddr & onev(3))))='1') or
             ((ENDIAN) and r.ahb3_rdbvalid(to_integer(unsigned(r.iramaddr & onev(3))))='1') ) then
          if r.iramaddr /= (r.iramaddr'range => '1') then
            v.iramaddr := std_logic_vector(unsigned(r.iramaddr)+1);
          end if;
          if r.iramaddr=(r.iramaddr'range => '1') and not (r.cctrl.ics(0)='0' and ici.parkreq='0' and (r.holdn='1' or (r.imisspend='1' and r.i2bufmatch='1'))) then
            v.irdbufen := '0';
            v.ramreload := '1';
            -- Update irdbufvaddr/paddr since used in icfetch2 stage
            if r.imisspend='1' then
              v.irdbufvaddr := r.i2pc(31 downto r.irdbufvaddr'low);
              v.irdbufpaddr := r.i2paddr(31 downto r.irdbufpaddr'low);
              v.iramaddr := r.i2pc(r.iramaddr'high downto r.iramaddr'low);
            else
              v.irdbufvaddr := r.i1pc(31 downto r.irdbufvaddr'low);
              v.irdbufpaddr := itlbpaddr(31 downto r.irdbufpaddr'low);
              v.iramaddr := r.i1pc(r.iramaddr'high downto r.iramaddr'low);
            end if;
            if v.imisspend='1' and v.i2paddrv='1' then
              v.s := as_wptectag1;
            else
              v.s := as_normal;
            end if;
          end if;
        end if;
        oico.mexc := r.ahb3_error and not r.icignerr;
        if r.ahb3_error='1' and r.icignerr='0' then
          v.iflushpend := '1';
          v.itrappend(0) := '1';
        end if;
        ocrami.itcmen := '0';

      when as_dcfetch =>
        if r.d2hitv=(r.d2hitv'range => '0') and r.cctrl.dcs="11" and r.d2nocache='0' then
          -- Select way to replace
          for x in 1 to DWAYS-1 loop
            if r.d2validv(x)='0' and r.d2validv(0 to x-1)=onev(x-1 downto 0) then
              v.d2hitv(x) := '1';
            end if;
          end loop;
          if r.d2validv(0)='0' then
            v.d2hitv(0) := '1';
          end if;
          if r.d2validv=(r.d2validv'range => '1') then
            vtmp4i := dec4wrap(dlruent(4 downto 3), DWAYS);
            v.d2hitv := v.d2hitv or vtmp4i(0 to DWAYS-1);
          end if;
        end if;
        if rs.s2read /= (rs.s2read'range => '0') then
          v.dvtagdone := '1';
        end if;
        if ahbi.hresp(1)='1' and r.ahb2_inacc='1' then
          v.ahb_htrans := "00";
        end if;
        if ahbi.hready='1' then
          -- Advance haddr/htrans
          if r.granted='1' and (ahbi.hresp(1)='0' or r.ahb2_inacc='0') and r.ahb_htrans(1)='1' then
            -- Move haddr forward
            v.ahb_htrans := "11";
            if r.d2busw='1' then
              v.ahb_haddr(log2(LINESZMAX*4)-1 downto log2(xbusw/8)) :=
                std_logic_vector(unsigned(r.ahb_haddr(log2(LINESZMAX*4)-1 downto log2(xbusw/8)))+1);
              if r.ahb_haddr(log2(dlinesize*4)-1 downto log2(xbusw/8))=
                onev(log2(dlinesize*4)-1 downto log2(xbusw/8)) then
                v.ahb_htrans := "00";
              end if;
            else
              v.ahb_haddr(log2(LINESZMAX*4)-1 downto 2) :=
                std_logic_vector(unsigned(r.ahb_haddr(log2(LINESZMAX*4)-1 downto 2))+1);
              if r.ahb_haddr(log2(dlinesize*4)-1 downto 2)=
                onev(log2(dlinesize*4)-1 downto 2) then
                v.ahb_htrans := "00";
              end if;
            end if;
          elsif r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
            -- Move haddr backward for retry/split
            if r.d2busw='1' then
              v.ahb_haddr(log2(LINESZMAX*4)-1 downto log2(xbusw/8)) :=
                std_logic_vector(unsigned(r.ahb_haddr(log2(LINESZMAX*4)-1 downto log2(xbusw/8)))-1);
            else
              v.ahb_haddr(log2(LINESZMAX*4)-1 downto 2) :=
                std_logic_vector(unsigned(r.ahb_haddr(log2(LINESZMAX*4)-1 downto 2))-1);
            end if;
            v.ahb_htrans := "10";
          end if;
        end if;
        keepreq := '1';
        if v.ahb_haddr(log2(dlinesize*4)-1 downto log2(xbusw/8))=
          onev(log2(dlinesize*4)-1 downto log2(xbusw/8)) and
          (r.d2busw='1' or v.ahb_haddr(log2(xbusw/8)-1+nbfid downto 2)=onev(log2(xbusw/8)-1+nbfid downto 2)) then
          keepreq := '0';
        end if;

        -- write read data buffer into D$ data RAM
        -- note virtual and physical tag write managed by snoop pipeline above
        -- data managed here
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.dramaddr;
        if ((not ENDIAN) and r.ahb3_rdbvalid(LINESZMAX-1-to_integer(unsigned(std_logic_vector'(r.dramaddr & onev(log2(cdataw/8)-1 downto 2)))))='1') or
          ((ENDIAN) and r.ahb3_rdbvalid(to_integer(unsigned(std_logic_vector'(r.dramaddr & onev(log2(cdataw/8)-1 downto 2)))))='1')
        then
          ocrami.ddataen := (others => '0');
          if r.cctrl.dcs(0)='1' then
            ocrami.ddataen(0 to DWAYS-1) := r.d2hitv;
            ocrami.ddatawrite := (others => '1');
          end if;
          v.dramaddr := std_logic_vector(unsigned(r.dramaddr)+1);
          if r.dramaddr=(r.dramaddr'range => '1') then
            if r.dvtagdone='0' then
              v.s := as_dcfetch2;
            else
              v.dmisspend := '0';
              v.s := as_normal;
            end if;
            if r.d1ten='1' then
              v.ramreload := '1';
            end if;
          end if;
        end if;
        odco.mexc := r.ahb3_error and not r.dcignerr;
        if r.ahb3_error='1' and r.dcignerr='0' then
          v.dflushpend := '1';
        end if;
        odco.way := "00";
        for x in 0 to LINESZMAX/2-1 loop
          if r.d2vaddr(BUF_HIGH downto 3)=std_logic_vector(to_unsigned(x,BUF_HIGH-2)) then
            if (not ENDIAN) then
              odco.data(0) := r.ahb3_rdbuf((LINESZMAX-2*x)*32-1 downto (LINESZMAX-2*x-2)*32);
            else
              odco.data(0) := r.ahb3_rdbuf(x*64+63 downto x*64);
            end if;
          end if;
        end loop;
        odco.mds := '0';


      when as_dcfetch2 =>
        if rs.s2read /= (rs.s2read'range => '0') then
          v.dvtagdone := '1';
        end if;
        if r.dvtagdone='1' or r.d2hitv=(r.d2hitv'range=>'0') then
          v.s := as_normal;
          v.dmisspend := '0';
          if r.d1ten='1' then
            v.ramreload := '1';
          end if;
        end if;

      when as_dcsingle =>
        if ahbi.hready='1' then
          if r.granted='1' and (ahbi.hresp(1)='0' or r.ahb2_inacc='0') and r.ahb_htrans(1)='1' then
            v.ahb_htrans := "00";
          elsif r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
            v.ahb_htrans := "10";
          elsif r.ahb2_inacc='1' and r.d2busw='0' and r.d2size="11" and r.ahb_haddr(2)='0' then
            v.ahb_haddr(2) := '1';
            v.ahb_htrans := "10";
          end if;
        end if;

        if r.ahb3_inacc='1' and r.ahb_htrans(1)='0' then
          v.dmisspend := '0';
          v.s := as_normal;
          if r.d1ten='1' then
            v.ramreload := '1';
          end if;
        end if;
        for x in 0 to LINESZMAX/2-1 loop
          if r.d2vaddr(BUF_HIGH downto 3)=std_logic_vector(to_unsigned(x,BUF_HIGH-2)) then
            if (not ENDIAN) then
              odco.data(0) := r.ahb3_rdbuf((LINESZMAX-2*x)*32-1 downto (LINESZMAX-2*x-2)*32);
            else
              odco.data(0) := r.ahb3_rdbuf(x*64+63 downto x*64);
            end if;
          end if;
        end loop;
        odco.way := "00";
        odco.mds := '0';

        odco.mexc := r.ahb3_error and not r.dcignerr;

      when as_mmuwalk =>
        v.ahb_hburst := HBURST_SINGLE;
        -- Ensure PTE writes get snooped
        if r.mmusel(2)='0' then
          v.ahb_snoopmask := (others => '0');
        end if;
        -- Complete current AHB access
        if r.ahb_htrans="00" and r.ahb2_inacc='0' then
          null;
        elsif ahbi.hready='1' and r.ahb2_inacc='1' and ahbi.hresp(1)='0' then
          null;
        elsif ahbi.hready='0' and r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
          v.ahb_htrans := "00";
        elsif ahbi.hready='1' and r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
          v.ahb_htrans := "10";
        elsif ahbi.hready='1' and r.granted='1' then
          v.ahb_htrans := "00";
        end if;
        -- New entry and new error (if error occurs)
        if r.mmusel(0)='0' then
          v.newent.ctx := r.i2ctx;
          v.newent.vaddr := r.i2pc(31 downto 12);
          v.newent.modified := '0';
          v.newerrclass := "01";
          v.mmuerr.at_ls := '0';        -- Load/Execute
          v.mmuerr.at_id := '1';        -- Instruction space
          v.mmuerr.at_su := r.i2su;
        else
          v.newent.ctx := r.mmctrl1.ctx;
          v.newent.vaddr := r.d2vaddr(31 downto 12);
          v.newent.modified := r.mmusel(1);
          v.newerrclass := "10";
          v.mmuerr.at_ls := r.mmusel(1);
          v.mmuerr.at_id := '0';
          v.mmuerr.at_su := r.d2su;
          -- Treat atomic access as store to avoid store phase of atomic
          -- causing mmu fault
          if r.d2lock='1' then
            v.newent.modified := '1';
            v.mmuerr.at_ls := '1';
          end if;
        end if;
        if r.newent.mask1='0' then
          v.mmuerr.l := "00";
        elsif r.newent.mask2='0' then
          v.mmuerr.l := "01";
        elsif r.newent.mask3='0' then
          v.mmuerr.l := "10";
        else
          v.mmuerr.l := "11";
        end if;
        v.newent.paddr(31 downto 12) := rdb32(27 downto 8);
        v.newent.cached := rdb32(7);
        v.newent.busw := dec_wbmask_fixed(v.newent.paddr(31 downto 12) & "0000000000", xwbmask);
        if rdb32v='1' then
          v.newent.modified := v.newent.modified or rdb32(6);
        end if;
        -- Prepare hwdata for writing back PTE with R/M bits set
        -- Check if write-back is needed
        vstd32 := rdb32;
        vstd32set := '1';
        if r.newent.modified='1' then
          vstd32(6) := '1';
        end if;
        vstd32(5) := '1';         -- referenced bit
        vneedwb := '0';
        vneedwblock := '0';
        if vstd32(6 downto 5) /= rdb32(6 downto 5) then
          vneedwb := '1';
          if vstd32(6) = '0' then
            vneedwblock := '1';
          end if;
        end if;
        v.newent.acc := rdb32(4 downto 2);
        v.dregval := rdb32;
        if rdb32v='1' then
          v.ahb3_rdbvalid := (others => '0');
          -- Depending on level/type -
          --   update haddr to go down to next level
          --   write back "accessed" bit
          --   update TLB and register of access causing miss
          if r.ahb3_error='1' then
            -- AHB error fetching entry
            v.s := as_mmuwalk3;
            v.newerrclass := "11";
            v.mmuerr.ft := "100";       -- Translation error
            v.mmuerr.fav := '1';
          elsif rdb32(1 downto 0)="10" then
            -- Page table entry
            v.mmuerr.ft := ft_acc_resolve(r.mmuerr.at_ls & r.mmuerr.at_id & r.mmuerr.at_su, rdb32(4 downto 2));
            if r.mmusel(2)='1' then
              v.s := as_rdasi2;
            elsif v.mmuerr.ft(1) /= '0' then
              v.s := as_mmuwalk3;
              v.mmuerr.fav := '1';
            elsif vneedwb='1' then
              v.ahb_hwrite := '1';
              if vneedwblock='1' and r.ahb_hlock='0' then
                v.s := as_mmuwalk4;
                v.ahb_hlock := '1';
                v.ahb_htrans := "00";
                v.ahb_hwrite := '0';
                v.granted := '0';
              else
                v.ahb_htrans := "10";
                v.s := as_wptectag1;
                v.tlbupdate := '1';
              end if;
            else
              v.tlbupdate := '1';
              -- Re-read tags and check for a potential hit
              if r.mmusel(0)='0' and r.imisspend='1' then
                v.s := as_wptectag1;
              elsif r.mmusel(0)='1' and (r.dmisspend='1' or r.slowwrpend='1') then
                v.s := as_wptectag1;
              else
                v.s := as_normal;
              end if;
            end if;
          elsif rdb32(1 downto 0)="01" and r.newent.mask3='0' then
            -- Page table descriptor
            v.newent.mask3 := r.newent.mask2;
            v.newent.mask2 := r.newent.mask1;
            v.newent.mask1 := '1';
            v.ahb_haddr := rdb32(27 downto 4) & "00000000";
            if r.newent.mask1='0' then
              v.ahb_haddr(9 downto 2) := v.ahb_haddr(9 downto 2) or r.newent.vaddr(31 downto 24);
            end if;
            if r.newent.mask1='1' and r.newent.mask2='0' then
              v.ahb_haddr(7 downto 2) := v.ahb_haddr(7 downto 2) or r.newent.vaddr(23 downto 18);
            end if;
            if r.newent.mask1='1' and r.newent.mask2='1' then
              v.ahb_haddr(7 downto 2) := v.ahb_haddr(7 downto 2) or r.newent.vaddr(17 downto 12);
            end if;
            v.ahb_htrans := "10";
            if r.mmusel(2)='1' then
              v.d2vaddr(9 downto 8) := std_logic_vector(unsigned(r.d2vaddr(9 downto 8)) + 1);
              if r.d2vaddr(9 downto 8)="11" then
                v.ahb_htrans := "00";
                v.s := as_rdasi2;
              end if;
            end if;
          else
            -- Invalid/reserved or too many levels of PTDs
            v.s := as_mmuwalk3;
            if rdb32(1 downto 0)="00" then
              v.mmuerr.ft := "001";     -- Invalid address error
            else
              v.mmuerr.ft := "100";     -- Translation error
            end if;
            v.mmuerr.fav := '1';
          end if;
        end if;
        -- If DIAEMRU is set, we do not set FAV here for instruction
        -- MMU miss, we handle that in the trap ack so that we only
        -- update the FSR/FAR if the trapping instruction is actually
        -- executed
        if r.cctrl.diaemru='1' and r.mmusel="000" then
          v.mmuerr.fav := '0';
        end if;
        if r.mmusel(0)='0' then
          v.i2paddr := v.newent.paddr & r.i2pc(11 downto 0);
          if r.newent.mask1='0' then
            v.i2paddr(31 downto 24) := v.i2paddr(31 downto 24) or r.i2pc(31 downto 24);
          end if;
          if r.newent.mask2='0' then
            v.i2paddr(23 downto 18) := v.i2paddr(23 downto 18) or r.i2pc(23 downto 18);
          end if;
          if r.newent.mask3='0' then
            v.i2paddr(17 downto 12) := v.i2paddr(17 downto 12) or r.i2pc(17 downto 12);
          end if;
          v.i2paddrv := '1';
          v.i2busw := v.newent.busw;
          v.i2paddrc := v.newent.cached;
        else
          v.d2paddr := v.newent.paddr & r.d2vaddr(11 downto 0);
          if r.newent.mask1='0' then
            v.d2paddr(31 downto 24) := v.d2paddr(31 downto 24) or r.d2vaddr(31 downto 24);
          end if;
          if r.newent.mask2='0' then
            v.d2paddr(23 downto 18) := v.d2paddr(23 downto 18) or r.d2vaddr(23 downto 18);
          end if;
          if r.newent.mask3='0' then
            v.d2paddr(17 downto 12) := v.d2paddr(17 downto 12) or r.d2vaddr(17 downto 12);
          end if;
          v.d2paddrv := '1';
          v.d2busw := v.newent.busw;
          v.d2nocache := not v.newent.cached;
          v.d2tlbmod := v.newent.modified;
        end if;
        -- Select which TLB entry to replace
        if r.mmusel(0)='0' then
          if r.i2tlbhit='0' and r.mmctrl1.tlbdis='0' then
            v.i2tlbhit := '1';
            v.i2tlbid := pmru_decode(r.itlbpmru);
          end if;
        else
          if r.d2tlbhit='0' and r.mmctrl1.tlbdis='0' and r.mmusel(2)='0' then
            v.d2tlbhit := '1';
            v.d2tlbid := pmru_decode(r.dtlbpmru);
          end if;
        end if;
        -- setup for as_wptectag1 state in case of recheck
        v.irdbufvaddr := r.i2pc(31 downto r.irdbufvaddr'low);
        v.irdbufpaddr := r.i2paddr(31 downto r.irdbufpaddr'low);
        v.iramaddr := r.i2pc(r.iramaddr'high downto r.iramaddr'low);

      when as_mmuwalk3 =>
        if r.mmusel(2)='0' then
          if r.mmusel(0)='0' then
            oico.mds := '0';
            if r.mmctrl1.nf='0' then
              oico.mexc := '1';
              v.itrappend(2) := '1';
            end if;
            v.imisspend := '0';
          else
            odco.mds := '0';
            if r.mmctrl1.nf='0' then
              odco.mexc := '1';
            end if;
            if r.mmusel(1)='1' then
              v.slowwrpend := '0';
            else
              v.dmisspend := '0';
            end if;
          end if;
          v.ramreload := '1';
          v.s := as_normal;
        else
          v.s := as_rdasi2;
        end if;
        v.dregval := (others => '0');
        oico.mexcdata(1 downto 0) := "01";

      when as_mmuwalk4 =>
        if r.ahb3_error='1' then
          -- AHB error fetching entry
          v.s := as_mmuwalk3;
          v.newerrclass := "11";
          v.mmuerr.ft := "100";       -- Translation error
          if r.mmusel /= "000" then
            v.mmuerr.fav := '1';
          end if;
        elsif rdb32v='1' then
          vstd32 := r.ahb_hwdata(31 downto 0);
          vstd32set := '1';
          vstd32(6 downto 5) := vstd32(6 downto 5) or rdb32(6 downto 5);
          v.s := as_wptectag1;
          v.ahb_htrans := "10";
          v.ahb_hwrite := '1';
          v.newent.modified := v.newent.modified or rdb32(6);
          v.tlbupdate := '1';
        elsif r.ahb2_inacc='1' then
          if ahbi.hresp(1)='1' then
            v.ahb_htrans := "00";
            if ahbi.hready='1' then
              v.ahb_htrans := "10";
            end if;
          end if;
        elsif r.ahb_htrans(1)='1' then
          if ahbi.hready='1' then
            v.ahb_htrans := "00";
          end if;
        else
          if r.granted='1' then
            v.ahb_htrans := "10";
          end if;
        end if;

      when as_wptectag1 =>
        -- Write PTE and recheck tags stage 1
        v.s := as_wptectag2;
        -- Continue PTE writeback
        -- Note r.ahb2_inacc is always 0 in this state, branches kept for
        -- symmetry with as_wptectag2/3 stages
        if r.ahb_htrans="00" and r.ahb2_inacc='0' then
          null;
        elsif ahbi.hready='1' and r.ahb2_inacc='1' and ahbi.hresp(1)='0' then
          null;
        elsif ahbi.hready='0' and r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
          v.ahb_htrans := "00";
        elsif ahbi.hready='1' and r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
          v.ahb_htrans := "10";
        elsif ahbi.hready='1' and r.granted='1' then
          v.ahb_htrans := "00";
        end if;
        -- Drive Icache tag/data addresses
        ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.irdbufvaddr(IOFFSET_HIGH downto IOFFSET_LOW);
        ocrami.idataoffs(log2(ilinesize)-2 downto 0) := r.iramaddr;
        ocrami.ifulladdr := r.i2pc;
        v.i1cont := '0';
        -- To avoid complicating the tag comparison logic we swap i1pc and i2pc
        -- and then swap back in icfetch3
        v.i2pc := r.i1pc;
        v.i1pc := r.i2pc;
        v.i2su := r.i1su;
        v.i1su := r.i2su;
        v.i2ctx := r.i1ctx;
        v.i1ctx := r.i2ctx;
        if r.cctrl.ics(0)='1' and r.imisspend='1' then
          ocrami.itagen := "1111";
          ocrami.idataen := "1111";
          v.i1ten := '1';
        end if;
        v.i1rep := '0';
        -- Drive Dcache tag/data addresses
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ddatafulladdr := r.d2vaddr;
        -- temporarily swap d1 and d2 virt addresses for tag comparison in next state
        v.d1vaddr := r.d2vaddr;
        v.d2vaddr := r.d1vaddr;
        v.d1su := r.d2su;
        v.d2su := r.d1su;
        v.dtlbrecheck := '1';           -- to swap dci.write/dci.lock
        v.d1ten := '0';
        if r.cctrl.dcs(0)='1' and r.mmusel(0)='1' and (r.dmisspend='1' or r.slowwrpend='1') then
          ocrami.dtagcen := (others => '1');
          ocrami.ddataen := (others => '1');
          v.d1ten := '1';
        end if;

      when as_wptectag2 =>
        -- Write PTE and recheck tags stage 2 - tag check
        v.s := as_wptectag3;
        -- Continue PTE writeback
        if r.ahb_htrans="00" and r.ahb2_inacc='0' then
          v.s := as_normal;
        elsif ahbi.hready='1' and r.ahb2_inacc='1' and ahbi.hresp(1)='0' then
          -- Done!
          v.s := as_normal;
          if ahbi.hresp(0)='1' then
            v.wtrappend(1) := '1';
          end if;
        elsif ahbi.hready='0' and r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
          v.ahb_htrans := "00";
        elsif ahbi.hready='1' and r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
          v.ahb_htrans := "10";
        elsif ahbi.hready='1' and r.granted='1' then
          v.ahb_htrans := "00";
        end if;
        -- Check Icache tags
        if r.imisspend='1' then
          oico.mds := '0';
        end if;
        -- Swap back to get i1pc
        v.i2pc := r.i1pc;
        v.i1pc := r.i2pc;
        v.i2pc := r.i1pc;
        v.i1pc := r.i2pc;
        v.i2su := r.i1su;
        v.i1su := r.i2su;
        v.i2ctx := r.i1ctx;
        v.i1ctx := r.i2ctx;
        v.i1ten := '0';
        v.i2validv := ivalidv;
        v.i2hitv := ihitv;
        if ihit='1' then
          v.imisspend := '0';
        end if;
        -- Check Dcache tags
        if r.dmisspend='1' and r.d2tcmhit='0' then
          odco.mds := '0';
        end if;
        v.d1vaddr := r.d2vaddr;
        v.d2vaddr := r.d1vaddr;
        v.d1su := r.d2su;
        v.d2su := r.d1su;
        if r.d1ten='1' then
          v.d2hitv := dhitv;
          v.d2validv := dvalidv;
        end if;
        ocrami.ddataen := (others => '0');
        ocrami.dtcmen := '0';
        if dhit='1' then
          if r.d2nocache='0' and r.d2specialasi='0' and r.d2forcemiss='0' and r.d2lock='0' then
            v.dmisspend := '0';
          end if;
          if r.d2tcmhit='1' then
            v.dmisspend := '0';
          end if;
        end if;
        if r.d2write='1' and r.d2specialasi='0' then
          ocrami.ddataen(0 to DWAYS-1) := dhitv;
          ocrami.dtcmen := r.d2tcmhit;
        end if;
        ocrami.ddatawrite := getdmask64(r.d1vaddr,r.d2size,ENDIAN);
        ocrami.ddatadin := (others => r.d2data);
        v.d1ten := r.d1chk and r.cctrl.dcs(0);
        v.d1tcmen := r.d1chk and dtcmact;
        v.ramreload := '1';

      when as_wptectag3 =>
        -- Write PTE and recheck tags stage 3 - finish writeback
        if r.ahb_htrans="00" and r.ahb2_inacc='0' then
          v.s := as_normal;
        elsif ahbi.hready='1' and r.ahb2_inacc='1' and ahbi.hresp(1)='0' then
          -- Done!
          v.s := as_normal;
          if ahbi.hresp(0)='1' then
            -- PTE writeback error
            v.wtrappend(1) := '1';
          end if;
        elsif ahbi.hready='0' and r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
          v.ahb_htrans := "00";
        elsif ahbi.hready='1' and r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
          v.ahb_htrans := "10";
        elsif ahbi.hready='1' and r.granted='1' then
          v.ahb_htrans := "00";
        end if;

      when as_store =>
        v.ramreload := '0';
        if r.granted='0' then
          v.d2stbcont := '0';
        end if;
        vrflag := '0';
        if r.ahb2_inacc='1' and ahbi.hresp(1)='1' and ahbi.hready='0' then
          vrflag := '1';
          v.ahb_htrans := "00";
          if r.d2nb64ctr='1' then
            v.d2nb64ctr := '0';
          else
            v.d2stba := std_logic_vector(unsigned(r.d2stba)-1);
          end if;
          v.d2stbcont := '0';
        else
          if ahbi.hready='1' and r.granted='1' then
            if r.ahb_htrans(1)='1' then
              if r.d2nb64ctr='0' and r.d2nb64en='1' then
                v.d2nb64ctr := '1';
                v.d2stbcont := '1';
              else
                v.d2nb64ctr := '0';
                v.d2stba := std_logic_vector(unsigned(r.d2stba)+1);
                v.d2stbcont := '0';
              end if;
            end if;
          end if;
          if ahbi.hready='1' then
            v.d2stbd := r.d2stba;
            v.d2nb64den := r.d2nb64en;
            v.d2nb64dctr := r.d2nb64ctr;
          end if;
          v.ahb_htrans := "00";
          if v.d2stba /= r.d2stbw or r.stbuffull='1' then
              v.ahb_htrans := "1" & v.d2stbcont;
          end if;
        end if;

        v.ahb_hwrite := '1';
        v.ahb_haddr := r.d2stbuf(to_integer(unsigned(v.d2stba))).addr;
        v.ahb_hsize := '0' & r.d2stbuf(to_integer(unsigned(v.d2stba))).size;
        v.ahb_snoopmask := r.d2stbuf(to_integer(unsigned(v.d2stba))).snoopmask;
        v.ahb_maskwtrap := r.d2stbuf(to_integer(unsigned(v.d2stba))).maskwtrap;
        vstd64 := r.d2stbuf(to_integer(unsigned(v.d2stbd))).data;
        vstd64set := '1';
        if v.d2nb64dctr='0' then
          vstd32 := r.d2stbuf(to_integer(unsigned(v.d2stbd))).data(63 downto 32);
        else
          vstd32 := r.d2stbuf(to_integer(unsigned(v.d2stbd))).data(31 downto 0);
        end if;
        if v.d2nb64den='1' or xbusw < 64 then
          vstd32set := '1'; -- overrides vstd64set
        end if;
        v.ahb_hburst := HBURST_SINGLE;
        if r.d2stbuf(to_integer(unsigned(v.d2stba))).nb64='1' then
          v.ahb_hburst := HBURST_INCR;
        end if;
        v.d2nb64en := r.d2stbuf(to_integer(unsigned(v.d2stba))).nb64;
        if v.d2nb64en='1' and vrflag='1' and r.d2nb64ctr='0' then v.d2nb64ctr:='1'; end if;
        if v.d2nb64ctr='1' then v.ahb_haddr(2):='1'; end if;
        if v.d2nb64en='1' then
          v.ahb_hsize(0) := '0';
        end if;
        -- su forwarded to hprot below
        vstoresu := r.d2stbuf(to_integer(unsigned(v.d2stba))).su;

        v.d2wcctr := "11";
        v.d2wchold := "000";
        if vrflag='1' then
          -- Don't activate write combining during retry since the original
          -- non-combined access has already been seen on the AHB bus
          null;
        elsif r.ahb_htrans(1)='1' and r.granted='1' and ahbi.hready='0' then
          -- Don't activate write combining for write that has already been
          -- "shown" in address phase on the AHB bus
          null;
        elsif v.d2stbcont='1' then
          -- Don't activate write combining mid-burst
          null;
        elsif r.d2stbuf(to_integer(unsigned(v.d2stba))).wcomb="11" then
          -- Activate write combining as soon as any ongoing accesses have finished
          -- we may fall into this branch by accident when there is nothing in
          -- the store buffer but htrans is 00 anyway in that case.
          v.ahb_htrans := "00";
          if r.ahb_htrans(1)='1' or (r.ahb2_inacc='1' and ahbi.hready='0') then
            -- Wait for current access to complete
            null;
          elsif (v.d2stba /= r.d2stbw or r.stbuffull='1') then
            v.s := as_wrcomb1;
          end if;
        elsif r.d2stbuf(to_integer(unsigned(v.d2stba))).wcomb(0)='1' and not (r.holdn='0' and r.stbuffull='0' and r.ramreload='0') and r.d2wchold/="111" then
          -- Wait for additional writes to resolve write combining decision
          v.ahb_htrans := "00";
          if r.d2wchold /= "111" then
            v.d2wchold := std_logic_vector(unsigned(r.d2wchold)+1);
          end if;
        end if;

        if (v.d2stba /= std_logic_vector(unsigned(r.d2stbw)-1) or (v.d2nb64en='1' and v.d2nb64ctr='0')) or r.stbuffull='1' or fastwr='1' then
          keepreq := '1';
        end if;
        if v.d2nb64en='1' and v.d2nb64ctr='1' then
          keepreq := '0';
        end if;

        if r.d2stbd /= r.d2stbw then
          v.stbuffull := '0';
        end if;

        if fastwr='1' then
          v.d2stbw := std_logic_vector(unsigned(r.d2stbw)+1);
          if v.d2stbw=r.d2stbd then
            v.stbuffull := '1';
          end if;
          if v.d2stba=r.d2stbw then
            v.ahb_htrans := "10";
            v.ahb_hburst := HBURST_SINGLE;
            v.ahb_haddr := v.d2paddr;
            v.ahb_hsize := "0" & v.d2size;
            v.ahb_snoopmask := (others => (not v.d2nocache));
            v.ahb_maskwtrap := '0';
            vstoresu := r.d1su;
            v.d2nb64en := '0';
            if fastwr_nb64='1' then
              v.ahb_hburst := HBURST_INCR;
              v.ahb_hsize := "010";
              v.d2nb64en := '1';
              keepreq := '1';
            end if;
            if fastwr_wcomb='1' then
              v.ahb_htrans := "00";
            end if;
          end if;
        end if;

        if fastwr='0' and r.stbuffull='0' and r.d2stbd=r.d2stbw then
          v.s := as_normal;
          v.d2stbw := "00";
          v.d2stba := "00";
          v.d2stbd := "00";
          v.dwchint := '0';
        end if;

      when as_wrcomb1 =>
        v.d2stbcont := '0';
        vrflag := '0';
        v.ahb_htrans := "00";
        if (r.d2stba /= r.d2stbw or r.stbuffull='1') and r.d2stbuf(to_integer(unsigned(r.d2stba))).wcomb="11" then
          v.d2stba := std_logic_vector(unsigned(r.d2stba)+1);
          v.d2wcctr := std_logic_vector(unsigned(r.d2wcctr)+1);
          v.d2nb64ctr := '0';
          v.d2wchold := (others => '0');
        else
          if r.d2wchold /= "111" then
            v.d2wchold := std_logic_vector(unsigned(r.d2wchold)+1);
          end if;
          if r.ahb2_inacc='0' and (r.d2stbuf(to_integer(unsigned(r.d2stba))).wcomb(0)='0' or (r.holdn='0' and r.stbuffull='0')) then
            v.ahb_htrans := "10";
            v.s := as_wrcomb2;
            v.d2stba := std_logic_vector(unsigned(r.d2stba)+1);
            v.d2wcctr := std_logic_vector(unsigned(r.d2wcctr)+1);
          end if;
        end if;

        v.ahb_hwrite := '1';
        v.ahb_hsize := '0' & r.d2stbuf(to_integer(unsigned(v.d2stba))).size;
        if xbusw>32 and r.d2nb64en='0' then
          if r.d2wcctr="11" or r.ahb_haddr(3)='1' or xbusw<128 then
            v.ahb_hsize := "011";
          else
            v.ahb_hsize := "100";
          end if;
          if (xbusw<128 and r.d2wcctr/="11") or (r.ahb_haddr(3)='0' and r.d2wcctr="10") then
            v.ahb_hburst := HBURST_INCR;
            keepreq := '1';
          else
            v.ahb_hburst := HBURST_SINGLE;
          end if;
        else
          v.ahb_hsize := "010";
          v.ahb_hburst := HBURST_INCR;
          keepreq := '1';
        end if;


        v.d2stbd := r.d2stba;
        if r.d2stbd /= r.d2stbw then
          v.stbuffull := '0';
        end if;

        if fastwr='1' then
          v.d2stbw := std_logic_vector(unsigned(r.d2stbw)+1);
          if v.d2stbw=r.d2stbd then
            v.stbuffull := '1';
          end if;
        end if;

      when as_wrcomb2 =>
        if r.ahb2_inacc='1' and ahbi.hresp(1)='1' then
          if ahbi.hready='0' then
            v.ahb_htrans := "00";
            if r.ahb_htrans(1)='1' then
              if xbusw>64 and r.ahb2_hsize10(1)='0' then  -- hsize=100
                v.d2wcctr := std_logic_vector(unsigned(r.d2wcctr)+2);
              elsif xbusw>32 and r.ahb2_hsize10(1 downto 0)="11" then  -- hsize=011
                v.d2wcctr := std_logic_vector(unsigned(r.d2wcctr)+1);
              elsif r.ahb2_haddr42(2)='1' then  -- hsize=010
                v.d2wcctr := std_logic_vector(unsigned(r.d2wcctr)+1);
              end if;
            end if;
          else
            v.ahb_htrans := "10";
          end if;
          v.ahb_haddr(4 downto 2) := r.ahb2_haddr42;
          v.ahb_hsize(2) := not r.ahb2_hsize10(1);
          v.ahb_hsize(1 downto 0) := r.ahb2_hsize10;
          if r.ahb2_hburst0='1' then
            v.ahb_hburst := HBURST_INCR;
            keepreq := '1';
          else
            v.ahb_hburst := HBURST_SINGLE;
          end if;
        elsif ahbi.hready='1' and r.granted='1' and r.ahb_htrans(1)='1' then
          if xbusw>64 and r.ahb_hsize(2)='1' then
            v.ahb_haddr(4) := not r.ahb_haddr(4);
            if unsigned(r.d2wcctr) > 1 then
              v.d2wcctr := std_logic_vector(unsigned(r.d2wcctr))-2;
            else
              v.d2wcctr := (others => '0');
            end if;
            v.ahb_htrans := "11";
            if unsigned(r.d2wcctr)=2 then
              v.ahb_htrans := "10";
              v.ahb_hsize := "011";
            end if;
          elsif xbusw>32 and r.ahb_hsize(1 downto 0)="11" then
            v.ahb_haddr(4 downto 3) := std_logic_vector(unsigned(r.ahb_haddr(4 downto 3))+1);
            if unsigned(r.d2wcctr) > 0 then
              v.d2wcctr := std_logic_vector(unsigned(r.d2wcctr))-1;
            end if;
            v.ahb_htrans := "11";
            if r.ahb_hburst(0)='0' then
              -- Special case - 128-bit bus, two 64-bit stores not aligned on
              --                  128-bit boundary
              v.ahb_htrans(0) := '0';
            end if;
            if xbusw>64 and unsigned(r.d2wcctr)>1 and r.ahb_haddr(3)='1' then
              -- Special case - 128-bit bus, four 64-bit stores not aligned on
              --                  128-bit boundary, switch from first 64-bit
              --                  store to 128-bit store for middle bit
              v.ahb_htrans := "10";
              v.ahb_hsize := "100";
            end if;
          else
            v.ahb_haddr(4 downto 2) := std_logic_vector(unsigned(r.ahb_haddr(4 downto 2))+1);
            if r.ahb_haddr(2)='1' and unsigned(r.d2wcctr) > 0 then
              v.d2wcctr := std_logic_vector(unsigned(r.d2wcctr))-1;
            end if;
            v.ahb_htrans := "11";
          end if;
          if (  r.d2wcctr=(r.d2wcctr'range => '0') and
                (  r.ahb_haddr(2)='1' or
                   (xbusw>64 and r.ahb_hsize(2)='1') or
                   (xbusw>32 and r.ahb_hsize(1 downto 0)="11") ) ) then
            v.ahb_htrans := "00";
          end if;
          if xbusw>64 and r.d2wcctr(r.d2wcctr'high downto 1)=(r.d2wcctr'high downto 1 => '0') and
            r.ahb_hsize(2)='1' then
            v.ahb_htrans := "00";
          end if;
          if ( (     (xbusw>64 and v.ahb_hsize(2)='1') and unsigned(v.d2wcctr)>1) or
               ( not (xbusw>64 and v.ahb_hsize(2)='1') and unsigned(v.d2wcctr)>0) or
               (v.ahb_hsize(1 downto 0)="10" and v.ahb_haddr(2)='0')              ) then
            keepreq := '1';
          end if;
        elsif ahbi.hready='1' and r.granted='0' then
          v.ahb_htrans(0) := '0';
        end if;
        if ahbi.hready='1' then
          if r.ahb_haddr(4)='0' xor ENDIAN then
            vstd128 := r.ahb3_rdbuf(LINESZMAX*32-1 downto LINESZMAX*32-128);
          else
            vstd128 := r.ahb3_rdbuf(127 downto 0);
          end if;
          for x in 0 to 3 loop
            if x=0 or r.ahb_haddr(4 downto 3)=std_logic_vector(to_unsigned(x,2)) then
              if (not ENDIAN) then
                vstd64 := r.ahb3_rdbuf((3-x)*64+63 downto (3-x)*64);
              else
                vstd64 := r.ahb3_rdbuf(x*64+63 downto x*64);
              end if;
              if r.ahb_haddr(2)='0' xor ENDIAN then
                vstd32 := vstd64(63 downto 32);
              else
                vstd32 := vstd64(31 downto 0);
              end if;
            end if;
          end loop;
          vstd128set := '1';
          if xbusw < 128 or r.ahb_hsize(2)='0' then
            vstd64set := '1';
          end if;
          if xbusw < 64 or r.ahb_hsize(1 downto 0)="10" then
            vstd32set := '1';
          end if;
        end if;

        v.d2wchold := "000";
        if r.ahb_htrans="00" and ahbi.hresp(1)='0' and v.ahb2_inacc='0' then
          if r.d2stbw=r.d2stbd and r.stbuffull='0' and fastwr='0' then
            v.s := as_normal;
            v.dwchint := '0';
          else
            v.s := as_store;
          end if;
        end if;

        if fastwr='1' then
          v.d2stbw := std_logic_vector(unsigned(r.d2stbw)+1);
          if v.d2stbw=r.d2stbd then
            v.stbuffull := '1';
          end if;
        end if;

      when as_slowwr =>
        -- Translate addr
        -- MMU permission check
        -- Check written flag
        -- Write burst on narrow bus
        -- Perform write
        v.mmusel := "011";
        -- Set up store buffer entry for single/double store cases
        v.d2stbuf(0).addr := r.d2paddr;
        v.d2stbuf(0).size := r.d2size;
        v.d2stbuf(0).data := r.d2data;
        v.d2stbuf(0).snoopmask := (others => (not r.d2nocache));
        v.d2stbuf(0).su := r.d2su;
        v.d2stbuf(0).nb64 := '0';
        v.d2stbuf(0).wcomb := "00";
        v.d2stbuf(0).maskwtrap := '0';
        if v.d2size="11" and (r.cctrl.wcomben='1' or r.dwchint='1') then
          v.d2stbuf(0).wcomb := "01";
        end if;
        if r.d2size="11" and r.d2busw='0' then
          v.d2stbuf(0).nb64 := '1';
        end if;
        if dspecialasi='1' then
          v.s := as_wrasi;
        elsif r.d2paddrv='0' or r.d2tlbmod='0' then
          v.s := as_mmuwalk;
          v.ahb_haddr := r.mmctrl1.ctxp(25 downto 4) & r.mmctrl1.ctx & "00";
          v.ahb_htrans := "10";
          v.ahb_hsize := "010";
          v.ahb_hburst := HBURST_SINGLE;
        else
          v.ahb_haddr := r.d2paddr;
          if r.d2size="11" and r.d2busw='0' then
            v.ahb_hsize := "010";
            v.ahb_hburst := HBURST_INCR;
            v.d2nb64en := '1';
            keepreq := '1';
          else
            v.ahb_hsize := "0" & r.d2size;
            v.ahb_hburst := HBURST_SINGLE;
            v.d2nb64en := '0';
          end if;
          v.ahb_htrans := "10";
          v.ahb_hwrite := '1';
          v.d2stbw := "01";
          v.s := as_store;
          v.slowwrpend := '0';
          if r.d1ten='1' then
            v.ramreload := '1';
          end if;
          if r.d2size="11" and (r.cctrl.wcomben='1' or r.dwchint='1') then
            v.ahb_htrans := "00";
          end if;
        end if;

      when as_wrasi =>
        v.s := as_wrasi2;
        -- For next state in case of ASI 0xC-0xF
        v.flushctr := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        vtmp4i := dec4wrap(r.d2vaddr(DOFFSET_HIGH+2 downto DOFFSET_HIGH+1), DWAYS);
        v.d2hitv := vtmp4i(0 to DWAYS-1);
        vtmp4i := dec4wrap(r.d2vaddr(DOFFSET_HIGH+2 downto DOFFSET_HIGH+1), IWAYS);
        v.i2hitv := vtmp4i(0 to IWAYS-1);
        for x in 0 to LINESZMAX/2-1 loop
          v.ahb3_rdbuf(x*64+63 downto x*64) := r.d2data;
        end loop;
        v.dregval64 := r.d2data(63 downto 32);
        v.dregval   := r.d2data(31 downto 0);
        v.ramreload := '1';
        d32 := r.d2data(63 downto 32);
        if r.d2vaddr(2)='1' xor ENDIAN then
          d32 := r.d2data(31 downto 0);
        end if;
        for w in 0 to DWAYS-1 loop
          v.dtagpipe(w)(DTAG_HIGH-DTAG_LOW+1 downto 1) := d32(DTAG_HIGH downto DTAG_LOW);
          v.dtagpipe(w)(0) := d32(0);
        end loop;

        case r.d2asi is
          when "00000010" =>            -- 0x02 System control registers
            vaddr5 := r.d2vaddr(6 downto 2);
            case vaddr5 is
              when "00000" =>     -- Cache control register
                set_ccr(r.d2data(63 downto 32));
              when "00010" =>     -- ICache configuration register
                null;
              when "00011" =>     -- DCache configuration register
                null;
              when "00100" =>     -- LEON5 configuration register
                v.cctrl.diaemru       := r.d2data(32+13);
                v.cctrl.wchinten      := r.d2data(32+12);
                v.cctrl.wcomben       := r.d2data(32+11);
                v.iuctrl.staticd      := r.d2data(32+10);
                --bit9 is reserved
                v.iuctrl.staticbp     := r.d2data(32+8);
                v.iuctrl.fbp          := r.d2data(32+7);
                v.iuctrl.fbtb         := r.d2data(32+6);
                v.iuctrl.dlatearith   := r.d2data(32+5);
                v.iuctrl.dlatewicc    := r.d2data(32+4);
                v.iuctrl.dbtb         := r.d2data(32+3);
                v.iuctrl.single_issue := r.d2data(32+2);
                v.iuctrl.dlatealu     := r.d2data(32+1);
                v.iuctrl.fpspec       := r.d2data(32+0);

              when "00110" =>    -- LEON5 region flush mask register
                v.regflmask := r.d2data(32+31 downto 32+4);

              when "00111" =>    -- LEON5 region flush register
                v.regfladdr := r.d2data(31 downto 4);
                v.iregflush := r.d2data(1);
                v.dregflush := r.d2data(0);
                v.iflushpend := v.iflushpend or v.iregflush;
                v.dflushpend := v.dflushpend or v.dregflush;

              when "01000" =>            -- AHB error register
                v.mmuwtrapmode := r.d2data(32+31 downto 32+30);
                v.ahbwtrapmode := r.d2data(32+29 downto 32+28);
                v.icignerr     := r.d2data(32+27);
                v.dcerrmaskval := r.d2data(32+26);
                v.dcerrmask    := r.d2data(32+25);
                v.dcignerr     := r.d2data(32+24);
                vs.ahberracc := vs.ahberracc and not r.d2data(32+20 downto 32+16);
                if r.d2data(32+3)='1' then vs.ahboerrm := '0'; end if;
                if r.d2data(32+2)='1' then vs.ahberrm := '0'; end if;
                if r.d2data(32+1)='1' then vs.ahboerr := '0'; end if;
                if r.d2data(32+0)='1' then vs.ahberr := '0'; end if;

              when "01011" =>           -- Trap register
                v.ctrapacc  := v.ctrapacc  and not r.d2data(25 downto 22);
                v.ctrappend := v.ctrappend and not r.d2data(21 downto 18);
                v.ctraptype := v.ctraptype and not r.d2data(17 downto 16);
                v.wtraplost := v.wtraplost and not r.d2data(12 downto 11);
                v.wtrappend := v.wtrappend and not r.d2data(10 downto 9);
                v.wtraptype := v.wtraptype and not r.d2data(8);
                v.itraplost := v.itraplost and not r.d2data(7 downto 5);
                v.itrappend := v.itrappend and not r.d2data(4 downto 2);
                v.itraptype := v.itraptype and not r.d2data(1 downto 0);

              when "10000" => -- TCM configuration register
                if itcmen=0 and dtcmen=0 then
                  v.dregerr := '1';
                else
                  if r.itcmwipe='0' and r.dtcmwipe='0' then
                    if itcmen /= 0 then
                      v.itcmwipe := r.d2data(32+31);
                    end if;
                    if dtcmen /= 0 then
                      v.dtcmwipe := r.d2data(32+15);
                    end if;
                  end if;
                  v.tcmdata := (others => '0');
                end if;

              when "10010" => -- Instruction TCM control register
                if itcmen=0 and dtcmen=0 then
                  v.dregerr := '1';
                end if;
                if itcmen /=0 then
                  v.itcmaddr := r.d2data(32+31 downto 32+16);
                  v.itcmctx := r.d2data(32+15 downto 32+8);
                  v.itcmperm := r.d2data(32+4 downto 32+3);
                  v.itcmenva := r.d2data(32+2);
                  v.itcmenvc := r.d2data(32+1);
                  v.itcmenp := r.d2data(32+0);
                end if;

              when "10011" =>   -- Data TCM control register
                if itcmen=0 and dtcmen=0 then
                  v.dregerr := '1';
                end if;
                if dtcmen /= 0 then
                  v.dtcmaddr := r.d2data(31 downto 16);
                  v.dtcmctx := r.d2data(15 downto 8);
                  v.dtcmperm := r.d2data(6 downto 3);
                  v.dtcmenva := r.d2data(2);
                  v.dtcmenvc := r.d2data(1);
                  v.dtcmenp := r.d2data(0);
                end if;

              when others =>    -- Unimplemented
                v.dregerr := '1';
            end case;

            -- when "00000011" =>            -- 0x03 Cache+TLB flush
            -- merged with ASI 0x18

            -- when "00000100" =>            -- 0x04 MMU registers
            -- merged with ASI 0x19

          when "00001100" =>            -- 0x0C ICache tags
            null;

          when "00001101" =>            -- 0x0D ICache data
            null;

          when "00001110" =>            -- 0x0E DCache tags
            if vs.dtwrite='0' then
              vs.dtwrite := '1';
              vs.dtaccidx := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
              vs.dtaccways := (others => '0');
              vs.dtaccways(to_integer(unsigned(r.d2vaddr(DOFFSET_HIGH+2 downto DOFFSET_HIGH+1)))) := '1';
              vs.dtacctagmod := '0';
            else
              v.s := r.s;
            end if;

          when "00001111" =>            -- 0x0F DCache data
            null;

          when "00010000" | "00010011" =>            -- 0x10 ICache+Dcache flush
            v.flushpart := "11";
            v.dflushpend := '1';
            v.iflushpend := '1';
            v.flushctr := (others => '0');
            v.slowwrpend := '0';
            v.s := as_flush;
            v.perf(4) := '1';

          when "00010001" =>            -- 0x11 DCache flush
            v.dflushpend := '1';
            v.flushpart(0) := '1';
            v.flushctr := (others => '0');
            v.slowwrpend := '0';
            v.s := as_flush;
            v.perf(4) := '1';

            --when "00010011" =>            -- 0x13 ICache+Dcache flush
            -- merged with ASI 0x10

          when "00011000" | "00000011" =>            -- 0x18 Cache+TLB flush
            v.tlbflush := '1';
            v.flushpart := "11";
            v.dflushpend := '1';
            v.iflushpend := '1';
            v.flushctr := (others => '0');
            v.slowwrpend := '0';
            v.s := as_flush;
            v.perf(4) := '1';

          when "00011001" | "00000100" =>            -- 0x19 MMU registers
            vaddr3 := r.d2vaddr(10 downto 8);
            case vaddr3 is
              when "000" =>  -- 0x000 MMU control register
                v.mmctrl1.tlbdis := r.d2data(32+15);
                v.mmctrl1.nf := r.d2data(32+1);
                v.mmctrl1.e := r.d2data(32+0);
              when "001" =>  -- 0x100 Context pointer register
                v.mmctrl1.ctxp := r.d2data(32+31 downto 32+2);
              when "010" =>  -- 0x200 Context register
                v.mmctrl1.ctx := r.d2data(32+7 downto 32+0);
                v.ctxswitch := '1';
--              when "011" =>  -- 0x300 Fault status register
--              when "100" =>  -- 0x400 Fault address register
              when others =>
                v.dregerr := '1';
            end case;

          when "00011011" =>               -- 0x1B MMU flush/probe
            v.s := as_mmuflush2;
            -- Swap addresses for TLB check
            --  use r.dregval is used as temp holding register for i1pc
            v.i1pc := r.d2vaddr;
            v.dregval := r.i1pc;
            v.i1ctx := r.mmctrl1.ctx;
            v.dregval64(7 downto 0) := r.i1ctx;
            v.d1vaddr := r.d2vaddr;
            v.d2vaddr := r.d1vaddr;

          when "00011100" =>            -- 0x1C MMU/Cache bypass
            -- Update registers and jump back to normal to handle in standard
            -- path
            v.d2paddr := r.d2vaddr;
            v.d2paddrv := '1';
            v.d2tlbmod := '1';
            v.d2busw := dec_wbmask_fixed(r.d2vaddr(31 downto 2), xwbmask);
            v.d2asi := "000" & ASI_SDATA;
            v.d2specialasi := '0';
            v.d2forcemiss := '1';
            v.d2nocache := '1';
            v.d2su := '1';
            v.d2hitv := (others => '0');
            v.s := as_normal;

          when "00011110" =>            -- 0x1E snoop tags
            if vs.stwrite='0' and vs.stread='0' then
              vs.stwrite := '1';
              vs.staccidx := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
              vs.staccways := (others => '0');
              vs.staccways(to_integer(unsigned(r.d2vaddr(DOFFSET_HIGH+2 downto DOFFSET_HIGH+1)))) := '1';
              vs.stacctag := r.d2data(32+DTAG_HIGH downto 32+DTAG_LOW);
            else
              v.s := r.s;
            end if;

          when "00100000" =>            -- 0x20  FPC control/debug
            v.s := as_wrasi;
            v.fpc_mosi.accen := '1';
            v.fpc_mosi.accwr := '1';
            if r.fpc_mosi.accen='0' then
              v.fpc_mosi.addr(0) := r.d2vaddr(2);
            elsif r.fpc_mosi.accen='1' and fpc_miso.accrdy='1' and r.d2size="11" then
              v.fpc_mosi.addr(0) := '1';
            end if;
            if v.fpc_mosi.addr(0)='0' xor ENDIAN then
              v.fpc_mosi.wrdata := r.d2data(63 downto 32);
            else
              v.fpc_mosi.wrdata := r.d2data(31 downto 0);
            end if;
            if r.fpc_mosi.accen='1' and fpc_miso.accrdy='1' then
              v.dregval64 := r.dregval;
              v.dregval := fpc_miso.rddata;
              if r.d2size /= "11" or r.fpc_mosi.addr(0)='1' then
                v.s := as_wrasi3;
                v.fpc_mosi.accen := '0';
              end if;
            end if;

          when "00100001" =>            -- 0x21 CPC (coprocessor) control/debug
            v.dregerr := '1';

          when "00100010" =>            -- 0x22  CPU-to-CPU interface
            v.s := as_wrasi;
            v.c2c_mosi.accen := '1';
            v.c2c_mosi.accwr := '1';
            if r.c2c_mosi.accen='0' then
              v.c2c_mosi.addr(0) := r.d2vaddr(2);
            elsif r.c2c_mosi.accen='1' and c2c_miso.accrdy='1' and r.d2size="11" then
              v.c2c_mosi.addr(0) := '1';
            end if;
            if v.c2c_mosi.addr(0)='0' xor ENDIAN then
              v.c2c_mosi.wrdata := r.d2data(63 downto 32);
            else
              v.c2c_mosi.wrdata := r.d2data(31 downto 0);
            end if;
            if r.c2c_mosi.accen='1' and c2c_miso.accrdy='1' then
              v.dregval64 := r.dregval;
              v.dregval := c2c_miso.rddata;
              if r.d2size /= "11" or r.c2c_mosi.addr(0)='1' then
                v.s := as_wrasi3;
                v.c2c_mosi.accen := '0';
              end if;
            end if;

          when "00100011" =>            -- 0x23 TLB diagnostic access
            -- d2vaddr(9) -- I / D
            -- d2vaddr(8) -- PMRU state
            -- d2vaddr(7 downto 3) -- entry
            if r.d2vaddr(9)='0' then
              v.newent := r.dtlb(to_integer(unsigned(r.d2vaddr(2+log2x(dtlbnum) downto 3))));
            else
              v.newent := r.itlb(to_integer(unsigned(r.d2vaddr(2+log2x(itlbnum) downto 3))));
            end if;
            if r.d2vaddr(8)='0' then
              if r.d2vaddr(2)='0' or r.d2size="11" then
                v.newent.vaddr := r.d2data(32+31 downto 32+12);
                v.newent.ctx := r.d2data(32+11 downto 32+4);
                v.newent.mask1 := r.d2data(32+3);
                v.newent.mask2 := r.d2data(32+2);
                v.newent.mask3 := r.d2data(32+1);
                v.newent.valid := r.d2data(32+0);
              end if;
              if r.d2vaddr(2)='1' or r.d2size="11" then
                v.newent.paddr := r.d2data(31 downto 12);
                v.newent.acc := r.d2data(5 downto 3);
                v.newent.busw := r.d2data(2);
                v.newent.cached := r.d2data(1);
                v.newent.modified := r.d2data(0);
              end if;
              v.tlbupdate := '1';
              v.i2tlbid := r.d2vaddr(2+log2x(itlbnum) downto 3);
              v.d2tlbid := r.d2vaddr(2+log2x(dtlbnum) downto 3);
              v.mmusel(0) := not r.d2vaddr(9);
              v.i2tlbhit := r.d2vaddr(9);
              v.d2tlbhit := not r.d2vaddr(9);
            else
              if r.d2vaddr(9)='0' then
                for x in 0 to dtlbnum-1 loop
                  v.dtlbpmru(x) := r.d2data(32+x);
                end loop;
              else
                for x in 0 to itlbnum-1 loop
                  v.itlbpmru(x) := r.d2data(32+x);
                end loop;
              end if;
            end if;
            v.s := as_wrasi2;

          when "00100100" =>            -- 0x24 BTB/BHT diagnostic access
            v.s := as_wrasi;
            v.iudiag_mosi.accen := '1';
            v.iudiag_mosi.accwr := '1';
            if r.iudiag_mosi.accen='0' then
              v.iudiag_mosi.addr(0) := r.d2vaddr(2);
            elsif r.iudiag_mosi.accen='1' and dci.iudiag_miso.accrdy='1' and r.d2size="11" then
              v.iudiag_mosi.addr(0) := '1';
            end if;
            if v.iudiag_mosi.addr(0)='0' xor ENDIAN then
              v.iudiag_mosi.wrdata := r.d2data(63 downto 32);
            else
              v.iudiag_mosi.wrdata := r.d2data(31 downto 0);
            end if;
            if r.iudiag_mosi.accen='1' and dci.iudiag_miso.accrdy='1' then
              v.dregval64 := r.dregval;
              v.dregval := dci.iudiag_miso.rddata;
              if r.d2size /= "11" or r.iudiag_mosi.addr(0)='1' then
                v.s := as_wrasi3;
                v.iudiag_mosi.accen := '0';
              end if;
            end if;

          when "00100101" =>         -- 0x25 Cache LRU diagnostic interface
            if r.d2vaddr(31)='1' then
              v.ilru(to_integer(unsigned(r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW)))) :=
                r.d2data(32+4 downto 32+0);
            else
              v.dlru(to_integer(unsigned(r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW)))) :=
                r.d2data(32+4 downto 32+0);
            end if;

          when "00100110" =>            -- 0x26 Instruction TCM access
            v.s := as_wrasi2;

          when "00100111" =>            -- 0x27 Data TCM access
            v.s := as_wrasi2;

          when others =>
            v.dregerr := '1';
        end case;

        if v.s=as_wrasi2 or v.s=as_rdcdiag then
          v.irdbufvaddr := r.d2vaddr(31 downto r.irdbufvaddr'low);
          v.iramaddr := r.d2vaddr(r.iramaddr'high downto r.iramaddr'low);
        end if;

      when as_wrasi2 =>
        v.s := as_wrasi3;
        v.ramreload := r.ramreload;
        ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.irdbufvaddr(IOFFSET_HIGH downto IOFFSET_LOW);
        ocrami.idataoffs(log2(ilinesize)-2 downto 0) := r.iramaddr;
        if r.d2vaddr(2)='1' then
          for w in 0 to IWAYS-1 loop
            ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW+1 downto 1) := r.dregval(ITAG_HIGH downto ITAG_LOW);
            ocrami.itagdin(w)(0) := r.dregval(0);
          end loop;
        else
          for w in 0 to IWAYS-1 loop
            ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW+1 downto 1) := r.dregval64(ITAG_HIGH downto ITAG_LOW);
            ocrami.itagdin(w)(0) := r.dregval64(0);
          end loop;
        end if;
        ocrami.idatadin := r.dregval64 & r.dregval;
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        if rs.s3hit=(rs.s3hit'range => '0') then
          ocrami.dtaguindex(DOFFSET_BITS-1 downto 0) :=
            r.flushctr(r.flushctr'high downto r.flushctr'high-DOFFSET_BITS+1);
          if r.d2vaddr(2)='1' then
            for w in 0 to DWAYS-1 loop
              ocrami.dtagudin(w)(ITAG_HIGH-ITAG_LOW+1 downto 1) := r.dregval(ITAG_HIGH downto ITAG_LOW);
              ocrami.dtagudin(w)(0) := r.dregval(0);
            end loop;
          else
            for w in 0 to DWAYS-1 loop
              ocrami.dtagudin(w)(ITAG_HIGH-ITAG_LOW+1 downto 1) := r.dregval64(ITAG_HIGH downto ITAG_LOW);
              ocrami.dtagudin(w)(0) := r.dregval64(0);
            end loop;
          end if;
        end if;
        if rs.s1en=(rs.s1en'range => '0') then
          ocrami.dtagsindex(DOFFSET_BITS-1 downto 0) :=
            r.flushctr(r.flushctr'high downto r.flushctr'high-DOFFSET_BITS+1);
        end if;
        ocrami.ifulladdr := r.d2vaddr;
        ocrami.ifulladdrw := r.d2vaddr;
        ocrami.ddatafulladdr := r.d2vaddr;
        ocrami.ddatafulladdrw := r.d2vaddr;
        v.dtagpipe := r.dtagpipe;
        -- Make sure cache data RAMs are masked by default if tcm is written
        -- and vice versa. Otherwise we can trigger an unwanted write if the
        -- ramreload flag is set on this cycle since they share the same
        -- idatawrite/ddatawrite mask
        if itcmen /= 0 then
          ocrami.idataen := (others => '0');
          ocrami.itcmen := '0';
        end if;
        if dtcmen /= 0 then
          ocrami.ddataen := (others => '0');
          ocrami.dtcmen := '0';
        end if;
        case r.d2asi is
          when "00001100" =>            -- 0x0C ICache tags
            ocrami.itagen(0 to IWAYS-1) := r.i2hitv;
            ocrami.itagwrite := '1';
          when "00001101" =>            -- 0x0D ICache data
            ocrami.idataen(0 to IWAYS-1) := r.i2hitv;
            ocrami.idatawrite := "00";
            if (r.d2vaddr(2)='0' xor ENDIAN) or r.d2size="11" then
              ocrami.idatawrite(1) := '1';
            end if;
            if (r.d2vaddr(2)='1' xor ENDIAN) or r.d2size="11" then
              ocrami.idatawrite(0) := '1';
            end if;
          when "00001110" =>            -- 0x0E DCache tags
            -- wait for write to complete in snoop tag pipeline
            if rs.dtwrite='1' then
              v.s := r.s;
            end if;
          when "00001111" =>            -- 0x0F DCache data
            ocrami.ddataen(0 to DWAYS-1) := r.d2hitv;
            if (r.d2vaddr(2)='0' xor ENDIAN) or r.d2size="11" then
              ocrami.ddatawrite(7 downto 4) := "1111";
            end if;
            if (r.d2vaddr(2)='1' xor ENDIAN) or r.d2size="11" then
              ocrami.ddatawrite(3 downto 0) := "1111";
            end if;
          when "00011110" =>            -- 0x1E snoop tags
            -- wait for write to complete in snoop tag pipeline
            if rs.stwrite='1' then
              v.s := r.s;
            end if;
          when "00100110" =>            -- 0x26 Instruction TCM
            ocrami.itcmen := '1';
            ocrami.idatawrite := "00";
            if (r.d2vaddr(2)='0' xor ENDIAN) or r.d2size="11" then
              ocrami.idatawrite(1) := '1';
            end if;
            if (r.d2vaddr(2)='1' xor ENDIAN) or r.d2size="11" then
              ocrami.idatawrite(0) := '1';
            end if;
          when "00100111" =>            -- 0x27 Data TCM
            ocrami.dtcmen := '1';
            if (r.d2vaddr(2)='0' xor ENDIAN) or r.d2size="11" then
              ocrami.ddatawrite(7 downto 4) := "1111";
            end if;
            if (r.d2vaddr(2)='1' xor ENDIAN) or r.d2size="11" then
              ocrami.ddatawrite(3 downto 0) := "1111";
            end if;
          when others =>
            null;
        end case;

        v.ahb3_error := r.dregerr;

      when as_wrasi3 =>
        v.ramreload := r.ramreload;
        odco.mds := '0';
        odco.mexc := r.ahb3_error;
        v.slowwrpend := '0';
        v.s := as_normal;

      when as_rdasi =>
        v.dregval := (others => '0');
        case r.d2asi is
          when "00000010" =>            -- 0x02 System control registers
            vaddr5 := r.d2vaddr(6 downto 2);
            case vaddr5 is
              when "00000" =>     -- Cache control register
                v.dregval := get_ccr(r,rs);
              when "00010" =>     -- ICache configuration register
                v.dregval := cache_cfg5(0, iways, ilinesize, iwaysize, 0,
                                        0, 0, 0, 0, 1);
              when "00011" =>     -- DCache configuration register
                v.dregval := cache_cfg5(0, dways, dlinesize, dwaysize, 0,
                                        6, 0, 0, 0, 1);
              when "00100" =>     -- LEON5 configuration register
                v.dregval(31 downto 30) := std_logic_vector(to_unsigned(dtagconf,2));
                if itcmen /= 0 then
                  v.dregval(28) := '1';
                end if;
                if dtcmen /= 0 then
                  v.dregval(27) := '1';
                end if;
                v.dregval(26) := '0';   -- GRLIB AHB bus implementation
                v.dregval(25 downto 23) := "001";  -- Revision 1
                v.dregval(13) := r.cctrl.diaemru;
                v.dregval(12) := r.cctrl.wchinten;
                v.dregval(11) := r.cctrl.wcomben;
                v.dregval(10) := r.iuctrl.staticd;
                v.dregval(8)  := r.iuctrl.staticbp;
                v.dregval(7)  := r.iuctrl.fbp;
                v.dregval(6)  := r.iuctrl.fbtb;
                v.dregval(5)  := r.iuctrl.dlatearith;
                v.dregval(4)  := r.iuctrl.dlatewicc;
                v.dregval(3)  := r.iuctrl.dbtb;
                v.dregval(2)  := r.iuctrl.single_issue;
                v.dregval(1)  := r.iuctrl.dlatealu;
                v.dregval(0)  := r.iuctrl.fpspec;

              when "00110" =>    -- LEON5 region flush mask register
                v.dregval(31 downto 4) := r.regflmask;

              when "00111" =>    -- LEON5 region flush register
                v.dregval(31 downto 4) := r.regfladdr;
                v.dregval(1) := r.iregflush;
                v.dregval(0) := r.dregflush;

              when "01000" =>    -- AHB error register
                v.dregval := (others => '0');
                v.dregval(31 downto 30) := r.mmuwtrapmode;
                v.dregval(29 downto 28) := r.ahbwtrapmode;
                v.dregval(27) := r.icignerr;
                v.dregval(26) := r.dcerrmaskval;
                v.dregval(25) := r.dcerrmask;
                v.dregval(24) := r.dcignerr;
                v.dregval(20 downto 16) := rs.ahberracc;
                v.dregval(15) := rs.ahberrhwrite;
                v.dregval(14 downto 11) := rs.ahberrhmaster;
                v.dregval(10 downto 8) := rs.ahberrhsize;
                v.dregval(5 downto 4) := rs.ahberrtype;
                v.dregval(3) := rs.ahboerrm;
                v.dregval(2) := rs.ahberrm;
                v.dregval(1) := rs.ahboerr;
                v.dregval(0) := rs.ahberr;

              when "01001" =>    -- AHB error address register
                v.dregval := rs.ahberrhaddr;

              when "01010" =>    -- AHB stripe configuration register
                -- This register is not implemented in standard AHB version
                -- of LEON5 (LEON5 config reg bit 26 is 0)
                v.dregerr := '1';

              when "01011" =>    -- Trap register
                v.dregval := (others => '0');
                v.dregval(25 downto 22) := r.ctrapacc;
                v.dregval(21 downto 18) := r.ctrappend;
                v.dregval(17 downto 16) := r.ctraptype;
                v.dregval(12 downto 11) := r.wtraplost;
                v.dregval(10 downto 9)  := r.wtrappend;
                v.dregval(8)            := r.wtraptype;
                v.dregval(7 downto 5)   := r.itraplost;
                v.dregval(4 downto 2)   := r.itrappend;
                v.dregval(1 downto 0)   := r.itraptype;

              when "01111" =>    -- Boot word
                v.dregval := bootword;

              when "10000" =>   -- TCM configuration register
                if itcmen=0 and dtcmen=0 then
                  v.dregerr := '1';
                else
                  if itcmen /= 0 then
                    v.dregval(31) := r.itcmwipe;
                    v.dregval(23 downto 21) := std_logic_vector(to_unsigned(itcmfrac,3));
                    v.dregval(20 downto 16) := std_logic_vector(to_unsigned(itcmabits+3,5));
                  end if;
                  if dtcmen /= 0 then
                    v.dregval(15) := r.dtcmwipe;
                    v.dregval(7 downto 5) := std_logic_vector(to_unsigned(dtcmfrac,3));
                    v.dregval(4 downto 0) := std_logic_vector(to_unsigned(dtcmabits+3,5));
                  end if;
                end if;

              when "10010" => -- Instruction TCM control register
                if itcmen=0 and dtcmen=0 then
                  v.dregerr := '1';
                end if;
                if itcmen /=0 then
                  v.dregval(31 downto 16) := r.itcmaddr;
                  v.dregval(15 downto 8) := r.itcmctx;
                  v.dregval(4 downto 3) := r.itcmperm;
                  v.dregval(2) := r.itcmenva;
                  v.dregval(1) := r.itcmenvc;
                  v.dregval(0) := r.itcmenp;
                end if;

              when "10011" =>   -- Data TCM control register
                if itcmen=0 and dtcmen=0 then
                  v.dregerr := '1';
                end if;
                if dtcmen /= 0 then
                  v.dregval(31 downto 16) := r.dtcmaddr;
                  v.dregval(15 downto 8) := r.dtcmctx;
                  v.dregval(6 downto 3) := r.dtcmperm;
                  v.dregval(2) := r.dtcmenva;
                  v.dregval(1) := r.dtcmenvc;
                  v.dregval(0) := r.dtcmenp;
                end if;

              when others =>    -- Unimplemented
                v.dregerr := '1';
            end case;
            v.s := as_rdasi2;

          when "00001100" =>            -- 0x0C ICache tags
            v.s := as_rdcdiag;

          when "00001101" =>            -- 0x0D ICache data
            v.s := as_rdcdiag;

          when "00001110" =>            -- 0x0E DCache tags
            v.s := as_rdcdiag;

          when "00001111" =>            -- 0x0F DCache data
            v.s := as_rdcdiag;

          when "00011001" =>            -- 0x19 MMU registers
            vaddr3 := r.d2vaddr(10 downto 8);
            case vaddr3 is
              when "000" =>  -- 0x000 MMU control register
                v.dregval(31 downto 28) := "0000";  -- impl
                v.dregval(27 downto 24) := "0001";  -- ver
                v.dregval(23 downto 21) := std_logic_vector(to_unsigned(log2(itlbnum),3));
                v.dregval(20 downto 18) := std_logic_vector(to_unsigned(log2(dtlbnum),3));
                v.dregval(17 downto 16) := std_logic_vector(to_unsigned(0,2));
                v.dregval(15) := r.mmctrl1.tlbdis;
                v.dregval(14) := '1';   -- Sep tlb
                v.dregval(1) := r.mmctrl1.nf;
                v.dregval(0) := r.mmctrl1.e;
              when "001" =>  -- 0x100 Context pointer register
                v.dregval(31 downto 2) := r.mmctrl1.ctxp;
              when "010" =>  -- 0x200 Context register
                v.dregval(7 downto 0) := r.mmctrl1.ctx;
              when "011" =>  -- 0x300 Fault status register
                v.dregval(17 downto 10) := r.mmfsr.ebe;
                v.dregval(9 downto 8) := r.mmfsr.l;
                v.dregval(7 downto 5) := r.mmfsr.at_ls & r.mmfsr.at_id & r.mmfsr.at_su;
                v.dregval(4 downto 2) := r.mmfsr.ft;
                v.dregval(1) := r.mmfsr.fav;
                v.dregval(0) := r.mmfsr.ow;
                -- Self-clearing on read but not if read through DSU
                if dci.dsuen='0' then
                  v.mmfsr.ft := "000";
                  v.mmfsr.fav := '0';
                  v.mmfsr.ow := '0';
                end if;
              when "100" =>  -- 0x400 Fault address register
                v.dregval(31 downto 12) := r.mmfar;
              when others =>
                v.dregerr := '1';
            end case;
            v.s := as_rdasi2;

          when "00011011" =>            -- 0x1B MMU flush/probe
            if r.d2vaddr(11)='1' or (r.d2vaddr(10)='1' and r.d2vaddr(9 downto 8)/="00") then
              -- Undefined probe type -- return 0
              v.dregval := (others => '0');
              v.s := as_rdasi2;
            elsif r.d2vaddr(10)='1' then
              -- Return data from DTLB if address matched and "entire" mode
              if r.d2tlbamatch='1' then
                v.dregval(31 downto 28) := "0000";
                v.dregval(27 downto 8) := r.dtlb(to_integer(unsigned(r.d2tlbid))).paddr;
                v.dregval(7) := r.dtlb(to_integer(unsigned(r.d2tlbid))).cached;
                v.dregval(6) := r.dtlb(to_integer(unsigned(r.d2tlbid))).modified;
                v.dregval(5) := '1';    -- referenced
                v.dregval(4 downto 2) := r.dtlb(to_integer(unsigned(r.d2tlbid))).acc;
                v.dregval(1 downto 0) := "10";  -- PTE
                v.s := as_rdasi2;
              else
                -- Try reading from ITLB
                v.s := as_mmuprobe2;
                v.i1pc := r.d2vaddr;
                v.d2vaddr := r.i1pc;
              end if;
            else
              -- Fall back to MMU walk
              v.s := as_mmuwalk;
              v.mmusel := "101";
              v.ahb_haddr := r.mmctrl1.ctxp(25 downto 4) & r.mmctrl1.ctx & "00";
              v.ahb_htrans := "10";
              v.ahb_hsize := "010";
            end if;

          when "00011100" =>            -- 0x1C MMU/Cache bypass
            -- Update registers and jump back to normal to handle in standard
            -- path
            v.d2paddr := r.d2vaddr;
            v.d2paddrv := '1';
            v.d2busw := dec_wbmask_fixed(r.d2vaddr(31 downto 2), xwbmask);
            v.d2asi := "000" & ASI_SDATA;
            v.d2specialasi := '0';
            v.d2su := '1';
            v.d2hitv := (others => '0');
            v.d2nocache := '1';
            v.s := as_normal;

          when "00011110" =>            -- 0x1E  Snoop tags
            v.s := as_rdcdiag;

          when "00100000" =>            -- 0x20  FPC control/debug
            v.dregval := r.dregval;
            v.fpc_mosi.accen := '1';
            v.fpc_mosi.accwr := '0';
            if r.fpc_mosi.accen='0' then
              v.fpc_mosi.addr(0) := r.d2vaddr(2);
            elsif r.fpc_mosi.accen='1' and fpc_miso.accrdy='1' and r.d2size="11" then
              v.fpc_mosi.addr(0) := '1';
            end if;
            if r.fpc_mosi.accen='1' and fpc_miso.accrdy='1' then
              if (not ENDIAN) then
                v.dregval64 := r.dregval;
                v.dregval := fpc_miso.rddata;
              else
                v.dregval := r.dregval64;
                v.dregval64 := fpc_miso.rddata;
              end if;
              if r.d2size /= "11" or r.fpc_mosi.addr(0)='1' then
                v.s := as_rdasi2;
                v.fpc_mosi.accen := '0';
              end if;
            end if;

          when "00100001" =>            -- 0x21  CPC (co-processor) control/debug
            v.dregerr := '1';
            v.s := as_rdasi2;

          when "00100010" =>            -- 0x22 CPU-to-CPU interface
            v.dregval := r.dregval;
            v.c2c_mosi.accen := '1';
            v.c2c_mosi.accwr := '0';
            if r.c2c_mosi.accen='0' then
              v.c2c_mosi.addr(0) := r.d2vaddr(2);
            elsif r.c2c_mosi.accen='1' and c2c_miso.accrdy='1' and r.d2size="11" then
              v.c2c_mosi.addr(0) := '1';
            end if;
            if r.c2c_mosi.accen='1' and c2c_miso.accrdy='1' then
              if (not ENDIAN) then
                v.dregval64 := r.dregval;
                v.dregval := c2c_miso.rddata;
              else
                v.dregval := r.dregval64;
                v.dregval64 := c2c_miso.rddata;
              end if;
              if r.d2size /= "11" or r.c2c_mosi.addr(0)='1' then
                v.s := as_rdasi2;
                v.c2c_mosi.accen := '0';
              end if;
            end if;

          when "00100011" =>            -- 0x23 TLB diagnostic access
            -- d2vaddr(9) -- I / D
            -- d2vaddr(8) -- PMRU state
            -- d2vaddr(7 downto 3) -- entry
            if r.d2vaddr(9)='0' then
              v.newent := r.dtlb(to_integer(unsigned(r.d2vaddr(2+log2x(dtlbnum) downto 3))));
            else
              v.newent := r.itlb(to_integer(unsigned(r.d2vaddr(2+log2x(itlbnum) downto 3))));
            end if;
            if r.d2vaddr(8)='0' then
              if r.d2vaddr(2)='0' then
                v.dregval(31 downto 12) := v.newent.vaddr;
                v.dregval(11 downto 4) := v.newent.ctx;
                v.dregval(3) := v.newent.mask1;
                v.dregval(2) := v.newent.mask2;
                v.dregval(1) := v.newent.mask3;
                v.dregval(0) := v.newent.valid;
              else
                v.dregval(31 downto 12) := v.newent.paddr;
                v.dregval(5 downto 3) := v.newent.acc;
                v.dregval(2) := v.newent.busw;
                v.dregval(1) := v.newent.cached;
                v.dregval(0) := v.newent.modified;
              end if;
            else
              if r.d2vaddr(9)='0' then
                for x in 0 to dtlbnum-1 loop
                  v.dregval(x) := r.dtlbpmru(x);
                end loop;
              else
                for x in 0 to itlbnum-1 loop
                  v.dregval(x) := r.itlbpmru(x);
                end loop;
              end if;
            end if;
            v.s := as_rdasi2;

          when "00100100" =>            -- 0x24 IU BTB/BHT diagnostic interface
            v.dregval := r.dregval;
            v.iudiag_mosi.accen := '1';
            v.iudiag_mosi.accwr := '0';
            if r.iudiag_mosi.accen='0' then
              v.iudiag_mosi.addr(0) := r.d2vaddr(2);
            elsif r.iudiag_mosi.accen='1' and dci.iudiag_miso.accrdy='1' and r.d2size="11" then
              v.iudiag_mosi.addr(0) := '1';
            end if;
            if r.iudiag_mosi.accen='1' and dci.iudiag_miso.accrdy='1' then
              if (not ENDIAN) then
                v.dregval64 := r.dregval;
                v.dregval := dci.iudiag_miso.rddata;
              else
                v.dregval := r.dregval64;
                v.dregval64 := dci.iudiag_miso.rddata;
              end if;
              if r.d2size /= "11" or r.iudiag_mosi.addr(0)='1' then
                v.s := as_rdasi2;
                v.iudiag_mosi.accen := '0';
              end if;
            end if;

          when "00100101" =>         -- 0x25 Cache LRU diagnostic interface
            if r.d2vaddr(31)='1' then
              v.dregval(4 downto 0) := ilruent;
            else
              v.dregval(4 downto 0) := dlruent;
            end if;
            v.s := as_rdasi2;

          when "00100110" =>            -- 0x26 Instruction TCM access
            if itcmen=0 then
              v.dregerr := '1';
              v.s := as_rdasi2;
            else
              v.s := as_rdcdiag;
            end if;

          when "00100111" =>            -- 0x27 Data TCM access
            if dtcmen=0 then
              v.dregerr := '1';
              v.s := as_rdasi2;
            else
              v.s := as_rdcdiag;
            end if;

          when others =>                -- Unimplemented ASI
            v.dregerr := '1';
            v.s := as_rdasi2;
        end case;
        if v.s=as_rdcdiag then
          -- Set irdbufaddr/iramaddr regs for Icache diag accesses
          v.irdbufvaddr := r.d2vaddr(31 downto r.irdbufvaddr'low);
          v.iramaddr := r.d2vaddr(r.iramaddr'high downto r.iramaddr'low);
        end if;

      when as_rdasi2 =>
        if r.d2size="11" then
          v.ahb3_rdbuf(LINESZMAX*32-1 downto LINESZMAX*32-64) := r.dregval64 & r.dregval;
        else
          v.ahb3_rdbuf(LINESZMAX*32-1 downto LINESZMAX*32-64) := r.dregval & r.dregval;
        end if;
        v.ahb3_error := r.dregerr;
        v.s := as_rdasi3;

      when as_rdasi3 =>
        odco.data(0) := r.ahb3_rdbuf(LINESZMAX*32-1 downto LINESZMAX*32-64);
        odco.way := "00";
        odco.mds := '0';
        odco.mexc := r.ahb3_error;
        v.dmisspend := '0';
        v.s := as_normal;

      when as_rdcdiag =>
        ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.irdbufvaddr(IOFFSET_HIGH downto IOFFSET_LOW);
        ocrami.idataoffs(log2(ilinesize)-2 downto 0) := r.iramaddr;
        ocrami.ifulladdr := r.d2vaddr;
        ocrami.itagen := "1111";
        ocrami.idataen := "1111";
        ocrami.itcmen := '1';
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ddatafulladdr := r.d2vaddr;
        ocrami.ddatafulladdrw := r.d2vaddr;
        ocrami.dtagcen := (others => '1');
        ocrami.ddataen := (others => '1');
        ocrami.dtcmen := '1';
        v.s := as_rdcdiag2;
        if r.d2asi="00011110" then
          if vs.stread='0' and vs.stwrite='0' then
            vs.stread := '1';
            vs.staccidx := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
            vs.staccways := (others => '0');
            vs.staccways(to_integer(unsigned(r.d2vaddr(DTAG_LOW+1 downto DTAG_LOW)))) := '1';
          else
            v.s := as_rdcdiag;
          end if;
        end if;

      when as_rdcdiag2 =>
        v.s := as_rdasi2;
        vdiagasi := r.d2asi(5) & r.d2asi(4) & r.d2asi(1 downto 0);
        case vdiagasi is
          when "0000" | "0100" | "1000" | "1100" =>                  -- 0x0C ICache tags
            d32 := cramo.itagdout(to_integer(unsigned(r.d2vaddr(ITAG_LOW+1 downto ITAG_LOW))));
            v.dregval := (others => '0');
            v.dregval(ITAG_HIGH downto ITAG_LOW) := d32(ITAG_HIGH-ITAG_LOW+1 downto 1);
            v.dregval(7 downto 0) := (others => d32(0));
          when "0001" | "0101" | "1001" | "1101" =>                  -- 0x0D ICache data
            d64 := cramo.idatadout(to_integer(unsigned(r.d2vaddr(ITAG_LOW+1 downto ITAG_LOW))));
            if r.d2vaddr(2)='0' then
              if r.d2write='0' then
                v.dregval := d64(63 downto 32);
              else
                v.dregval := d64(31 downto 0);
              end if;
            else
              if r.d2write='0' then
                v.dregval := d64(31 downto 0);
              else
                v.dregval64 := d64(63 downto 32);
              end if;
            end if;
          when "0010" =>                  -- 0x0E DCache tags
            d32 := dctagsv(to_integer(unsigned(r.d2vaddr(DTAG_LOW+1 downto DTAG_LOW))));
            v.dregval := (others => '0');
            v.dregval(DTAG_HIGH downto DTAG_LOW) := d32(DTAG_HIGH-DTAG_LOW+1 downto 1);
            v.dregval(7 downto 0) := (others => d32(0));
          when "0110" | "1110"            =>  -- 0x1E snoop tags
            d32 := dctagsv(to_integer(unsigned(r.d2vaddr(DTAG_LOW+1 downto DTAG_LOW))));
            v.dregval := (others => '0');
            v.dregval(DTAG_HIGH downto DTAG_LOW) := d32(DTAG_HIGH-DTAG_LOW+1 downto 1);
            v.dregval(7 downto 0) := (others => d32(0));
            if rs.strddone='1' then
              v.dregval := (others => '0');
              v.dregval(DTAG_HIGH downto DTAG_LOW) := rs.stacctag;
            else
              v.s := r.s;
            end if;
          when "1010" =>                -- 0x26 ITCM
            d64 := cramo.itcmdout;
            if r.d2vaddr(2)='0' then
              v.dregval := d64(63 downto 32);
            else
              v.dregval := d64(31 downto 0);
            end if;
          when "1011" =>                -- 0x27 DTCM
            d64 := cramo.dtcmdout;
            if r.d2vaddr(2)='0' then
              v.dregval := d64(63 downto 32);
            else
              v.dregval := d64(31 downto 0);
            end if;
          when others =>                -- 0x0F DCache data
            d64 := cramo.ddatadout(to_integer(unsigned(r.d2vaddr(DTAG_LOW+1 downto DTAG_LOW))));
            if r.d2vaddr(2)='0' then
              v.dregval := d64(63 downto 32);
            else
              v.dregval := d64(31 downto 0);
            end if;
        end case;
        -- must set ramreload here since we have done a Itag read from another addr
        v.ramreload := '1';

      when as_getlock =>
        if r.granted='1' then
          v.s := as_normal;
        end if;

      when as_parked =>
        oico.parked := '1';
        -- Check on hready to ensure r.granted status is up to date in case we were
        --   clock gated while parked.
        if ici.parkreq='0' and ahbi.hready='1' then
          v.s := as_normal;
        end if;

      when as_mmuprobe2 =>
        -- Swap back addresses
        v.i1pc := r.d2vaddr;
        v.d2vaddr := r.i1pc;
        -- Check if ITLB hit
        if itlbamatch='1' then
          v.s := as_mmuprobe3;
        else
          -- Fall back to MMU walk
          v.s := as_mmuwalk;
          v.mmusel := "101";
          v.ahb_haddr := r.mmctrl1.ctxp(25 downto 4) & r.mmctrl1.ctx & "00";
          v.ahb_htrans := "10";
          v.ahb_hsize := "010";
        end if;

      when as_mmuprobe3 =>
        v.dregval(31 downto 28) := "0000";
        v.dregval(27 downto 8) := r.itlb(to_integer(unsigned(r.itlbprobeid))).paddr;
        v.dregval(7) := r.itlb(to_integer(unsigned(r.itlbprobeid))).cached;
        v.dregval(6) := r.itlb(to_integer(unsigned(r.itlbprobeid))).modified;
        v.dregval(5) := '1';    -- referenced
        v.dregval(4 downto 2) := r.itlb(to_integer(unsigned(r.itlbprobeid))).acc;
        v.dregval(1 downto 0) := "10";  -- PTE
        v.s := as_rdasi2;

      when as_mmuflush2 =>
        -- Note use same registers for address/context as in regular TLB lookup
        -- should equality checks inside flushmatch function to be merged with
        -- regular TLB.
        for e in 0 to itlbnum-1 loop
          ipc := r.i1pc_repl((e mod tlbrepl)*32+31 downto (e mod tlbrepl)*32);
          if flushmatch(r.itlb(e), ipc, r.i1ctx) = '1' then
            v.itlb(e).valid := '0';
          end if;
        end loop;
        for e in 0 to dtlbnum-1 loop
          if flushmatch(r.dtlb(e), r.d1vaddr, r.mmctrl1.ctx) = '1' then
            v.dtlb(e).valid := '0';
          end if;
        end loop;
        v.s := as_normal;
        -- Swap back addresses to restore correct state
        --  use r.dregval is used as temp holding register for i1pc
        v.i1pc := r.dregval;
        v.i1ctx := r.dregval64(7 downto 0);
        v.d1vaddr := r.d2vaddr;
        v.d2vaddr := r.d1vaddr;
        v.ramreload := '1';
        v.slowwrpend := '0';

      when as_regflush =>
        ocrami.iindex := (others => '0');
        ocrami.iindex(IOFFSET_BITS-1 downto 0) :=
          r.flushctr(r.flushctr'high downto r.flushctr'high-IOFFSET_BITS+1);
        ocrami.idataoffs := (others => '0');
        for w in 0 to IWAYS-1 loop
          -- ocrami.itagdin(w) := (others => '0');
          ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW+1 downto ITAG_HIGH-ITAG_LOW-6) := x"FF";
          ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW-7 downto ITAG_HIGH-ITAG_LOW-8) := std_logic_vector(to_unsigned(w,2));
          ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW-9 downto ITAG_HIGH-ITAG_LOW-10) := std_logic_vector(to_unsigned(w,2));
          ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW+1 downto ITAG_HIGH-ITAG_LOW) := r.untagi(2*w+1 downto 2*w);
          ocrami.itagdin(w)(0) := '0';
        end loop;
        ocrami.dtagcindex := (others => '0');
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) :=
          r.flushctr(r.flushctr'high downto r.flushctr'high-DOFFSET_BITS+1);

        -- Stage 3: Write back to itag/dtag
        vbubble0 := '0';
        vstall := '0';
        if r.regflpipe(0).valid='1' then
          if r.flushwri /= (r.flushwri'range => '0') then
            ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.regflpipe(0).addr(IOFFSET_BITS-1 downto 0);
            ocrami.itagen(0 to IWAYS-1) := r.flushwri;
            ocrami.itagwrite := '1';
            vbubble0 := '1';
          end if;
          if dtagconf /= 0 then
            for w in 0 to DWAYS-1 loop
              if r.flushwrd(w)='1' then
                vs.validarr(to_integer(unsigned(r.regflpipe(0).addr)))(w) := '0';
              end if;
            end loop;
          else
            if vs.dtwrite='0' then
              vs.dtaccidx := r.regflpipe(0).addr(DOFFSET_BITS-1 downto 0);
              vs.dtacctagmsb := r.untagd;
              vs.dtacctaglsb := (others => '0');
            end  if;
            if r.flushwrd /= (r.flushwrd'range => '0') then
              if vs.dtwrite='0' then
                vs.dtwrite := '1';
                vs.dtaccways := r.flushwrd;
                vs.dtacctagmod := '1';
              else
                vstall := '1';
              end if;
            end if;
          end if;
        end if;
        if vstall='1' then
          v.regflpipe := r.regflpipe;
        end if;
        -- Stage 2: Compare with region flush mask
        -- Most is handled in region flush section above FSM, just handle stall
        -- here
        if vstall='1' then
          v.untagi := r.untagi;
          v.untagd := r.untagd;
          v.flushwrd := r.flushwrd;
          v.flushwri := r.flushwri;
        end if;
        -- Stage 1: Capture tags or itag/dtag write ongoing
        -- Most is handled in region flush section above FSM, just handle stall
        -- here
        if vstall='1' then
          v.dtagpipe := r.dtagpipe;
          v.itagpipe := r.itagpipe;
        end if;
        -- Stage 0: Command Read from tag RAMs
        if r.regfldone='0' and vbubble0='0' and vstall='0' then
          if r.flushpart(1)='1' then
            ocrami.itagen := (others => '1');
            ocrami.itagwrite := '0';
          end if;
          if r.flushpart(0)='1' then
            ocrami.dtagcen := (others => '1');
          end if;
          v.regflpipe(r.regflpipe'high).valid := '1';
          -- Advance counter, skip addrs guaranteed not to match
          --   set fixed bits to 1 before incrementing
          --   after incrementing, force fixed bits back to determined value
          vfoffs := r.flushctr;
          vfoffs := vfoffs or r.regflmask(DOFFSET_HIGH downto DOFFSET_LOW);
          vfoffs := std_logic_vector(unsigned(vfoffs)+1);
          if vfoffs=(vfoffs'range => '0') then
            v.regfldone := '1';
          end if;
          vfoffs := vfoffs and not r.regflmask(DOFFSET_HIGH downto DOFFSET_LOW);
          vfoffs := vfoffs or (r.regflmask(DOFFSET_HIGH downto DOFFSET_LOW) and
                               r.regfladdr(DOFFSET_HIGH downto DOFFSET_LOW));
          v.flushctr := vfoffs;
        end if;

        if r.regfldone='1' then
          vhit := '0';
          for x in 0 to r.regflpipe'high loop
            if r.regflpipe(x).valid='1' then vhit := '1'; end if;
          end loop;
          if vhit='0' then
            v.ramreload := '1';
            v.s := as_normal;
            if r.flushpart(1)='1' then v.iflushpend:='0'; v.iregflush:='0'; end if;
            if r.flushpart(0)='1' then v.dflushpend:='0'; v.dregflush:='0'; end if;
          end if;
        end if;


    end case;

    if vstd32set='1' then
      if xbusw < 64 then
        v.ahb_hwdata := vstd32;
      else
        vstd64set := '1';
        vstd64 := vstd32 & vstd32;
      end if;
    end if;
    if xbusw > 32 and vstd64set='1' then
      if xbusw < 128 then
        v.ahb_hwdata := vstd64;
      else
        vstd128set := '1';
        vstd128 := vstd64 & vstd64;
      end if;
    end if;
    if xbusw > 64 and vstd128set='1' then
      v.ahb_hwdata := vstd128;
    end if;

    if v.itcmwipe='1' or v.dtcmwipe='1' then
      v.itcmenp := '0';
      v.itcmenva := '0';
      v.itcmenvc := '0';
      v.dtcmenp := '0';
      v.dtcmenva := '0';
      v.dtcmenvc := '0';
    end if;

    -- SMP broadcast flush
    if smpflush(1)='1' then
      v.iflushpend := '1';
    end if;
    if smpflush(0)='1' then
      v.tlbflush := '1';
    end if;


    -- Debug link access
    -- Stage 4 : tag recheck d1 -> d2, set dmisspend (if read miss) / slowwrpend
    if r.dbgacc(1)='1' then
      if r.dbgaccwr='1' then
        v.slowwrpend := '1';
      end if;
    end if;
    -- Stage 3 : ram reload in progress
    v.dbgacc(1) := r.dbgacc(0);
    if r.dbgacc(0)='1' then
      v.ramreload := '0';
      if r.dbgacc(1)='0' then
        v.d1chk := '1';
      end if;
    end if;
    -- Stage 2 : capture virtual address and set ramreload
    if r.dbgaccpend='1' and r.fsmidle='1' then
      v.dbgacc(0) := '1';
      v.d1vaddr := dci.maddress;
      if r.dbgacc(0)='0' then
        v.ramreload := '1';
      end if;
    end if;
    -- Stage 1 : capture read/write command
    if dci.dsuen='1' and dci.enaddr='1' and r.holdn='1' then
      if dci.read='1' then
        v.dbgaccpend := '1';
      end if;
      if dci.write='1' then
        v.dbgaccpend := '1';
        v.dbgaccwr := '1';
      end if;
    end if;
    if r.dbgacc(1)='1' or dci.dsuen='0' then
      v.dbgacc := (others => '0');
      v.dbgaccpend := '0';
      v.dbgaccwr := '0';
    end if;

    v.holdn := '1';
    if ( v.imisspend='1' or v.dmisspend='1' or v.slowwrpend='1' or
         v.iflushpend='1' or v.dflushpend='1' or v.ramreload='1' or
         v.stbuffull='1' or v.syncbar='1' or v.dbgaccpend='1' or freeze='1') then
      v.holdn := '0';
    end if;

    v.fastwr_rdy := '0';
    if (v.s=as_normal or v.s=as_store or v.s=as_wrcomb1 or v.s=as_wrcomb2) and v.ahb_hlock='0' then
      v.fastwr_rdy := '1';
    end if;

    -- Bus request handling
    v.ahb_hbusreq := '0';
    if (v.ahb_htrans(1)='1' or r.s=as_getlock or v.s=as_mmuwalk4) and (v.granted='0' or v.ahb_hlock='1' or keepreq='1') then
      v.ahb_hbusreq := '1';
    end if;

    -- hprot generation
    v.ahb_hprot := "1101";
    if v.s=as_icfetch then
      v.ahb_hprot := "11" & v.i2su & '0';
    elsif v.s=as_store or v.s=as_wrcomb1 or v.s=as_wrcomb2 then
      v.ahb_hprot := "11" & vstoresu & '1';
    elsif v.s=as_dcfetch or v.s=as_dcsingle then
      v.ahb_hprot := "11" & v.d2su & '1';
    end if;

    -- Data loopback if no bw support
    ocrami.ddataloop := (others => '0');
    if dusebw=0 then
      ocrami.ddataloop := not ocrami.ddatawrite;
      if ocrami.ddatawrite(7 downto 4) /= "0000" then
        ocrami.ddatawrite(7 downto 4) := "1111";
      end if;
      if ocrami.ddatawrite(3 downto 0) /= "0000" then
        ocrami.ddatawrite(3 downto 0) := "1111";
      end if;
    end if;

    -- Combined read/update port for Dtag RAM
    ocrami.dtagcuindex := ocrami.dtagcindex;
    ocrami.dtagcuen := ocrami.dtagcen;
    ocrami.dtagcuwrite := '0';
    if rs.s3read /= (rs.s3read'range => '0') or rs.s3flush /= (rs.s3flush'range => '0') then
      ocrami.dtagcuindex(DOFFSET_BITS-1 downto 0) := rs.s3offs;
      ocrami.dtagcuen(0 to DWAYS-1) := rs.s3read or rs.s3flush;
      ocrami.dtagcuwrite := '1';
    elsif rs.dtwrite='1' then
      ocrami.dtagcuindex(DOFFSET_BITS-1 downto 0) := rs.dtaccidx;
      ocrami.dtagcuen(0 to DWAYS-1) := rs.dtaccways;
      ocrami.dtagcuwrite := '1';
    end if;

    -- TCM wiping support
    ocrami.dtcmwrite := ocrami.ddatawrite;
    if r.dtcmwipe='1' then
      ocrami.dtcmen := '1';
      ocrami.dtcmwrite := "11111111";
      ocrami.dtcmdin := (others => '0');
      ocrami.ddatafulladdr := r.tcmdata;
      ocrami.ddatafulladdrw := r.tcmdata;
    end if;
    ocrami.itcmwrite := ocrami.idatawrite;
    ocrami.itcmdin := ocrami.idatadin;
    if r.itcmwipe='1' then
      ocrami.itcmen := '1';
      ocrami.itcmwrite := "11";
      ocrami.itcmdin := (others => '1');
      ocrami.ifulladdr := r.tcmdata;
      ocrami.ifulladdrw := r.tcmdata;
    end if;
    if r.dtcmwipe='1' or r.itcmwipe='1' then
      v.tcmdata(31 downto 3) := std_logic_vector(unsigned(r.tcmdata(31 downto 3))+1);
      v.tcmdata(2 downto 0) := "000";
      for x in 31 downto 3 loop
        if (itcmen=0 or x>(2+itcmabits)) and (dtcmen=0 or x>(2+dtcmabits)) then
          v.tcmdata(x) := '0';
        end if;
      end loop;
      if v.tcmdata=(v.tcmdata'range => '0') then
        v.dtcmwipe := '0';
        v.itcmwipe := '0';
      end if;
    end if;

    -- Mask write error after taking trap
    if vmaskwtrap(0)='1' then
      for x in r.d2stbuf'range loop
        v.d2stbuf(x).maskwtrap := '1';
      end loop;
      if v.s=as_store or v.s=as_wrcomb2 then
        v.ahb_maskwtrap := '1';
        v.ahb2_maskwtrap := '1';
      end if;
    end if;

    v.dtraptt := TT_DSEX;
    v.dtrapet1 := '0';
    v.dtrapet0 := '0';
    if v.ctrappend /= "0000" then
      v.dtrapet1 := '1';
      v.dtrapet0 := '1';
      v.dtraptt := "110000";
    elsif v.wtrappend /= "00" then
      v.dtrapet1 := '1';
      v.dtrapet0 := '0';
      if (v.wtrappend(0)='1' and r.ahbwtrapmode(0)='1') or (v.wtrappend(1)='1' and r.mmuwtrapmode(0)='1') then
        v.dtrapet0 := '1';
      end if;
    end if;

    v.ctrapacc := v.ctrapacc or v.ctrappend;

    --------------------------------------------------------------------------
    -- Reset
    --------------------------------------------------------------------------

    if ( GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 and
         GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all)=0 ) then
      if rst='0' then
        v.ahb_hlock      := RRES.ahb_hlock;
        v.cctrl.dcs      := RRES.cctrl.dcs;
        v.cctrl.ics      := RRES.cctrl.ics;
        v.cctrl.ics_btb  := RRES.cctrl.ics_btb;
        v.cctrl.dsnoop   := RRES.cctrl.dsnoop;
        v.cctrl.wcomben  := RRES.cctrl.wcomben;
        v.cctrl.wchinten := RRES.cctrl.wchinten;
        v.cctrl.diaemru  := RRES.cctrl.diaemru;
        v.iuctrl         := RRES.iuctrl;
        v.icignerr       := RRES.icignerr;
        v.dcignerr       := RRES.dcignerr;
        v.dcerrmask      := RRES.dcerrmask;
        v.dcerrmaskval   := RRES.dcerrmaskval;
        v.itcmenp        := RRES.itcmenp;
        v.itcmenva       := RRES.itcmenva;
        v.itcmenvc       := RRES.itcmenvc;
        v.itcmperm       := RRES.itcmperm;
        v.itcmaddr       := RRES.itcmaddr;
        v.itcmctx        := RRES.itcmctx;
        v.dtcmenp        := RRES.dtcmenp;
        v.dtcmenva       := RRES.dtcmenva;
        v.dtcmenvc       := RRES.dtcmenvc;
        v.dtcmperm       := RRES.dtcmperm;
        v.dtcmaddr       := RRES.dtcmaddr;
        v.dtcmctx        := RRES.dtcmctx;
        v.itcmwipe       := RRES.itcmwipe;
        v.dtcmwipe       := RRES.dtcmwipe;
        v.regflmask      := RRES.regflmask;
        v.regfladdr      := RRES.regfladdr;
        v.iregflush      := RRES.iregflush;
        v.dregflush      := RRES.dregflush;
        v.mmctrl1.e      := RRES.mmctrl1.e;
        v.mmctrl1.nf     := RRES.mmctrl1.nf;
        v.mmctrl1.ctx    := RRES.mmctrl1.ctx;
        v.mmctrl1.tlbdis := RRES.mmctrl1.tlbdis;
        v.mmctrl1.pso    := RRES.mmctrl1.pso;
        v.mmctrl1.bar    := RRES.mmctrl1.bar;
        v.mmfsr.fav      := RRES.mmfsr.fav;
        v.s              := RRES.s;
        v.imisspend      := RRES.imisspend;
        v.dmisspend      := RRES.dmisspend;
        v.iflushpend     := RRES.iflushpend;
        v.dflushpend     := RRES.dflushpend;
        v.slowwrpend     := RRES.slowwrpend;
        v.syncbar        := RRES.syncbar;
        v.irdbufen       := RRES.irdbufen;
        v.holdn          := RRES.holdn;
        v.ahb_hbusreq    := RRES.ahb_hbusreq;
        v.ahb_hlock      := RRES.ahb_hlock;
        v.ahb_htrans     := RRES.ahb_htrans;
        v.granted        := RRES.granted;
        v.i2paddrv       := RRES.i2paddrv;
        v.i1ten          := RRES.i1ten;
        v.i1cont         := RRES.i1cont;
        v.i1rep          := RRES.i1rep;
        v.ibpmiss        := RRES.ibpmiss;
        v.d1ten          := RRES.d1ten;
        v.dwchint        := RRES.dwchint;
        v.itrappend      := RRES.itrappend;
        v.itraplost      := RRES.itraplost;
        v.wtrappend      := RRES.wtrappend;
        v.wtraplost      := RRES.wtraplost;
        v.ahbwtrapmode   := RRES.ahbwtrapmode;
        v.mmuwtrapmode   := RRES.mmuwtrapmode;
        v.ctrappend      := RRES.ctrappend;
        vs.sgranted      := RSRES.sgranted;
        if dtagconf=0 then
          vs.validarr    := RSRES.validarr;
        end if;
        vs.dtwrite       := RSRES.dtwrite;
        vs.stread        := RSRES.stread;
        vs.stwrite       := RSRES.stwrite;
        vs.strdstarted   := RSRES.strdstarted;
        vs.strddone      := RSRES.strddone;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Replication
    ---------------------------------------------------------------------------
    for x in 0 to tlbrepl-1 loop
      v.i1pc_repl(x*32+31 downto x*32) := v.i1pc;
    end loop;
    for x in 0 to tlbrepl-1 loop
      v.d1vaddr_repl(x*32+31 downto x*32) := v.d1vaddr;
    end loop;

    ---------------------------------------------------------------------------
    -- Constant registers
    ---------------------------------------------------------------------------
    case dways is
      when 1 =>
        for w in r.dlru'range loop v.dlru(w) := (others => '0'); end loop;
      when 2 =>
        for w in r.dlru'range loop
          v.dlru(w)(4) := '0';
          v.dlru(w)(2 downto 0) := "000";
        end loop;
      when 3 =>
        for w in r.dlru'range loop
          v.dlru(w)(1 downto 0) := "00";
        end loop;
      when 4 => null;
    end case;
    case iways is
      when 1 =>
        for w in r.ilru'range loop v.ilru(w) := (others => '0'); end loop;
      when 2 =>
        for w in r.ilru'range loop
          v.ilru(w)(4) := '0';
          v.ilru(w)(2 downto 0) := "000";
        end loop;
      when 3 =>
        for w in r.ilru'range loop
          v.ilru(w)(1 downto 0) := "00";
        end loop;
      when 4 => null;
    end case;
    for x in 31 downto 16 loop
      if (x <= 2+itcmabits) or itcmen=0 then
        v.itcmaddr(x) := '0';
      end if;
      if (x <= 2+dtcmabits) or dtcmen=0 then
        v.dtcmaddr(x) := '0';
      end if;
    end loop;

    -- If wbmask is zero we force all bus-width related registers to zero
    if xwbmask=0 then
      for x in 0 to itlbnum-1 loop
        v.itlb(x).busw := '0';
      end loop;
      for x in 0 to dtlbnum-1 loop
        v.dtlb(x).busw := '0';
      end loop;
      v.newent.busw := '0';
      v.i2busw := '0';
      v.d2busw := '0';
    end if;
    --------------------------------------------------------------------------
    -- Assign signals
    --------------------------------------------------------------------------
    c <= v;
    cs <= vs;
    ico <= oico;
    dco <= odco;
    ahbo <= oahbo;
    crami <= ocrami;
    fpc_mosi <= r.fpc_mosi;
    c2c_mosi <= r.c2c_mosi;
    perf <= r.perf;
  end process;

  srstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 generate
    regs: process(clk)
    begin
      if rising_edge(clk) then
        r <= c;
        if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rst='0' then
          r <= RRES;
        end if;
      end if;
    end process;

    sregs: process(sclk)
    begin
      if rising_edge(sclk) then
        rs <= cs;
        if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rst='0' then
          rs <= RSRES;
        end if;
      end if;
    end process;
  end generate srstregs;

  arstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)/=0 generate
    regs: process(clk,rst)
    begin
      if rst='0' then
        r <= RRES;
      elsif rising_edge(clk) then
        r <= c;
      end if;
    end process;

    sregs: process(sclk,rst)
    begin
      if rst='0' then
        rs <= RSRES;
      elsif rising_edge(sclk) then
        rs <= cs;
      end if;
    end process;
  end generate arstregs;

--pragma translate_off
  ahbxchk: process(clk)
  begin
    if rising_edge(clk) then
      if r.ahb2_inacc='1' and r.ahb2_hwrite='0' and ahbi.hready='1' and ahbi.hresp="00" then
        for x in LINESZMAX-1 downto 0 loop
          assert
            not (r.ahb2_addrmask(x)='1' and is_x(ahbi.hrdata((((x+1)*32-1) mod xbusw) downto ((x*32) mod xbusw))))
            report "Reading in X over AHB bus into CPU"
            severity warning;
        end loop;
      end if;
    end if;
  end process;
--pragma translate_on

end;
