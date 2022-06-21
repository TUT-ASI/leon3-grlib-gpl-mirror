
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
-- Package:     noelvint
-- File:        noelvint.vhd
-- Description: Internal components and types for NOEL-V
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.riscv.all;
use grlib.stdlib.all;
use grlib.config_types.all;
use grlib.config.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.arith.all;
use gaisler.noelv.XLEN;
use gaisler.noelv.nv_irq_in_type;
use gaisler.noelv.nv_irq_out_type;
use gaisler.noelv.nv_dm_in_type;
use gaisler.noelv.nv_dm_out_type;
use gaisler.noelv.nv_debug_in_type;
use gaisler.noelv.nv_debug_out_type;
use gaisler.noelv.nv_debug_in_vector;
use gaisler.noelv.nv_debug_out_vector;
use gaisler.noelv.nv_counter_out_type;
use gaisler.noelv.nv_etrace_out_type;
use gaisler.utilnv.get_hi;
use gaisler.utilnv.all_0;

package noelvint is

  subtype word8  is std_logic_vector( 7 downto 0);
  subtype word16 is std_logic_vector(15 downto 0);
  subtype word64 is std_logic_vector(63 downto 0);
  subtype word   is std_logic_vector(31 downto 0);
  subtype wordx  is std_logic_vector(XLEN - 1 downto 0);

  type wordx_arr is array (integer range <>) of wordx;

  constant zerow16      : word16 := (others => '0');
  constant zerow64      : word64 := (others => '0');
  constant onesw64      : word64 := (others => '1');
  constant zerox        : wordx  := (others => '0');
  constant zerow        : word   := (others => '0');

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------
  constant NOELV_VERSION        : integer := 1;

  constant HWPERFMONITORS       : integer := 29;
  constant PMPENTRIES           : integer := 16;
  constant PMPADDRBITS          : integer := 54;
  constant MAX_TRIGGER_NUM      : integer := 4;

  constant TRACE_WIDTH  : integer := 512;
  constant TRACE_SEL    : integer := TRACE_WIDTH / 32;

  constant IDBITS3 : integer := 39;    -- Sv39

  constant CTAG_LRRPOS  : integer := 9;
  constant CTAG_LOCKPOS : integer := 8;

  constant REPL_SOFT    : integer := 0;
  constant REPL_RAND    : integer := 1;

  constant RND     : std_logic_vector(1 downto 0) := "11";
  constant LRR     : std_logic_vector(1 downto 0) := "10";
  constant LRU     : std_logic_vector(1 downto 0) := "01";
  constant DIR     : std_logic_vector(1 downto 0) := "00";

  constant MAXWAYS : integer := 4;
  constant TAGMAX  : integer := 32;
  constant IDXMAX  : integer := 16;

  constant MAX_PREDICTOR_BITS  : integer := 2;

  -- 3-way set permutations
  -- s012 => set 0 - least recently used
  --         set 2 - most recently used
  constant s012 : std_logic_vector(2 downto 0) := "000";
  constant s021 : std_logic_vector(2 downto 0) := "001";
  constant s102 : std_logic_vector(2 downto 0) := "010";
  constant s120 : std_logic_vector(2 downto 0) := "011";
  constant s201 : std_logic_vector(2 downto 0) := "100";
  constant s210 : std_logic_vector(2 downto 0) := "101";


  -- 4-way set permutations
  -- s0123 => set 0 - least recently used
  --          set 3 - most recently used
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
  type lru_3way_table_type        is array (0 to 7) of lru_3way_table_vector_type;

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
  type lru_4way_table_type        is array(0 to 31) of lru_4way_table_vector_type;

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
  type lru3_repl_table_type        is array(0 to 7) of lru3_repl_table_single_type;

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
  type lru4_repl_table_type        is array(0 to 31) of lru4_repl_table_single_type;

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

  -- Exception Codes
  subtype cause_type is std_logic_vector(5 downto 0);

  constant XC_INST_ADDR_MISALIGNED      : cause_type;
  constant XC_INST_ACCESS_FAULT         : cause_type;
  constant XC_INST_ILLEGAL_INST         : cause_type;
  constant XC_INST_BREAKPOINT           : cause_type;
  constant XC_INST_LOAD_ADDR_MISALIGNED : cause_type;
  constant XC_INST_LOAD_ACCESS_FAULT    : cause_type;
  constant XC_INST_STORE_ADDR_MISALIGNED: cause_type;
  constant XC_INST_STORE_ACCESS_FAULT   : cause_type;
  constant XC_INST_ENV_CALL_UMODE       : cause_type;
  constant XC_INST_ENV_CALL_SMODE       : cause_type;
  constant XC_INST_ENV_CALL_VSMODE      : cause_type;
  constant XC_INST_ENV_CALL_MMODE       : cause_type;
  constant XC_INST_INST_PAGE_FAULT      : cause_type;
  constant XC_INST_LOAD_PAGE_FAULT      : cause_type;
  constant XC_INST_STORE_PAGE_FAULT     : cause_type;
  constant XC_INST_INST_G_PAGE_FAULT    : cause_type;
  constant XC_INST_LOAD_G_PAGE_FAULT    : cause_type;
  constant XC_INST_VIRTUAL_INST         : cause_type;
  constant XC_INST_STORE_G_PAGE_FAULT   : cause_type;
  constant XC_INST_RFFT                 : cause_type;

  -- Interrupt Codes
  constant IRQ_U_SOFTWARE               : cause_type;
  constant IRQ_S_SOFTWARE               : cause_type;
  constant IRQ_VS_SOFTWARE              : cause_type;
  constant IRQ_M_SOFTWARE               : cause_type;
  constant IRQ_U_TIMER                  : cause_type;
  constant IRQ_S_TIMER                  : cause_type;
  constant IRQ_VS_TIMER                 : cause_type;
  constant IRQ_M_TIMER                  : cause_type;
  constant IRQ_U_EXTERNAL               : cause_type;
  constant IRQ_S_EXTERNAL               : cause_type;
  constant IRQ_VS_EXTERNAL              : cause_type;
  constant IRQ_M_EXTERNAL               : cause_type;
  constant IRQ_SG_EXTERNAL              : cause_type;
  constant IRQ_LCOF                     : cause_type;

  -- Reset Codes
  constant RST_HARD_ALL                 : cause_type;
  constant RST_ASYNC                    : cause_type;

  constant CSR_VENDORID                 : wordx := zerox(zerox'high downto 12) & x"324"; -- Gaisler JEDEC ID (0xA4, bank 7)
  constant CSR_ARCHID                   : wordx := (others => '0');
  constant CSR_IMPID                    : wordx := (others => '0');
  constant RST_VEC                      : wordx;
  constant CSR_MEDELEG_MASK             : wordx;
  constant CSR_MIDELEG_MASK             : wordx;
  constant CSR_MIE_MASK                 : wordx;
  constant CSR_MIP_MASK                 : wordx;
  constant CSR_HEDELEG_MASK             : wordx;
  constant CSR_HIDELEG_MASK             : wordx;
  constant CSR_HIE_MASK                 : wordx;
  constant CSR_HIP_MASK                 : wordx;

  constant TINST_LOAD_MASK              : word := "00000000000000000111111111111111";
  constant TINST_H_MASK                 : word := "11111111111100000111111111111111";
  constant TINST_STORE_MASK             : word := "00000001111100000111000001111111";
  constant TINST_AMO_MASK               : word := "11111111111100000111111111111111";

  function tinst_vs_pt_read return word;
  function tinst_vs_pt_write return word;

  -- Hardware Performance Monitors
  constant CSR_HPM_ICACHE_MISS          :  integer := 1;
  constant CSR_HPM_DCACHE_MISS          :  integer := 2;
  constant CSR_HPM_ITLB_MISS            :  integer := 3;
  constant CSR_HPM_DTLB_MISS            :  integer := 4;
  constant CSR_HPM_HOLD                 :  integer := 5;
  constant CSR_HPM_DUAL_ISSUE           :  integer := 6;
  constant CSR_HPM_BRANCH_MISS          :  integer := 7;
  constant CSR_HPM_HOLD_ISSUE           :  integer := 8;
  constant CSR_HPM_BRANCH               :  integer := 9;
  constant CSR_HPM_LOAD_DEP             :  integer := 10;
  constant CSR_HPM_STORE_B2B            :  integer := 11;
  constant CSR_HPM_JALR                 :  integer := 12;
  constant CSR_HPM_JAL                  :  integer := 13;
  constant CSR_HPM_DCACHE_FLUSH         :  integer := 14;
  constant CSR_HPM_SINGLE_ISSUE         :  integer := 15;

  constant CSR_HPM_FPU_LOW              :  integer := 16;

  -- PMP Configuration Codes
  constant PMP_OFF                      : std_logic_vector(1 downto 0) := "00";
  constant PMP_TOR                      : std_logic_vector(1 downto 0) := "01";
  constant PMP_NA4                      : std_logic_vector(1 downto 0) := "10";
  constant PMP_NAPOT                    : std_logic_vector(1 downto 0) := "11";

  -- PMP Access Type
  constant PMP_ACCESS_X : std_logic_vector(1 downto 0) := "00"; -- Execute
  constant PMP_ACCESS_R : std_logic_vector(1 downto 0) := "01"; -- Read
  constant PMP_ACCESS_W : std_logic_vector(1 downto 0) := "11"; -- Write


  -- CSR Type -----------------------------------------------------------------
  type csr_status_type is record
    mbe         : std_ulogic;
    sbe         : std_ulogic;
    sxl         : std_logic_vector(1 downto 0);
    uxl         : std_logic_vector(1 downto 0);
    tsr         : std_ulogic;
    tw          : std_ulogic;
    tvm         : std_ulogic;
    mxr         : std_ulogic;
    sum         : std_ulogic;
    mprv        : std_ulogic;
    xs          : std_logic_vector(1 downto 0);
    fs          : std_logic_vector(1 downto 0);
    mpp         : std_logic_vector(1 downto 0);
    spp         : std_ulogic;
    mpie        : std_ulogic;
    ube         : std_ulogic;
    spie        : std_ulogic;
    upie        : std_ulogic;
    mie         : std_ulogic;
    sie         : std_ulogic;
    uie         : std_ulogic;
    -- Added by Hypervisor extension
    mpv         : std_ulogic;
    gva         : std_ulogic;
  end record;

  constant csr_status_rst : csr_status_type := (
    mbe         => '0',
    sbe         => '0',
    sxl         => "10",
    uxl         => "10",
    tsr         => '0',
    tw          => '0',
    tvm         => '0',
    mxr         => '0',
    sum         => '0',
    mprv        => '0',
    xs          => "00",
    fs          => "00",
    mpp         => "00",
    spp         => '0',
    mpie        => '0',
    ube         => '0',
    spie        => '0',
    upie        => '0',
    mie         => '0',
    sie         => '0',
    uie         => '0',
    mpv         => '0',
    gva         => '0'
    );

  type csr_hstatus_type is record
    vsxl        : std_logic_vector(1 downto 0);
    vtsr        : std_ulogic;
    vtw         : std_ulogic;
    vtvm        : std_ulogic;
    vgein       : std_logic_vector(5 downto 0);
    hu          : std_ulogic;
    spvp        : std_ulogic;
    spv         : std_ulogic;
    gva         : std_ulogic;
    vsbe        : std_ulogic;
  end record;

  constant csr_hstatus_rst : csr_hstatus_type := (
    vsxl        => "10",
    vtsr        => '0',
    vtw         => '0',
    vtvm        => '0',
    vgein       => "000000",
    hu          => '0',
    spvp        => '0',
    spv         => '0',
    gva         => '0',
    vsbe        => '0'
    );

  type csr_tdata_vector is array (0 to MAX_TRIGGER_NUM-1) of wordx;
  type csr_tinfo_vector is array (0 to MAX_TRIGGER_NUM-1) of word16;
  type csr_tcsr_type is record
    tselect     : std_logic_vector(log2(MAX_TRIGGER_NUM)-1 downto 0);
    tdata1      : csr_tdata_vector;
    tdata2      : csr_tdata_vector;
    tdata3      : csr_tdata_vector;
    tinfo       : csr_tinfo_vector;
    tcontrol    : word8;
    mcontext    : word64;
    scontext    : word64;
  end record;

  constant csr_tcsr_rst : csr_tcsr_type := (
    tselect     => (others => '0'),
    tdata1      => (others => (others => '0')),
    tdata2      => (others => (others => '0')),
    tdata3      => (others => (others => '0')),
    tinfo       => (others => (2 => '1', others => '0')),
    tcontrol    => (others => '0'),
    mcontext    => (others => '0'),
    scontext    => (others => '0')
    );

  type csr_dcsr_type is record
    xdebugver   : std_logic_vector(3 downto 0);
    ebreakm     : std_ulogic;
    ebreaks     : std_ulogic;
    ebreaku     : std_ulogic;
    ebreakvs    : std_ulogic;
    ebreakvu    : std_ulogic;
    stepie      : std_ulogic;
    stopcount   : std_ulogic;
    stoptime    : std_ulogic;
    cause       : std_logic_vector(2 downto 0);
    mprven      : std_ulogic;
    nmip        : std_ulogic;
    step        : std_ulogic;
    prv         : std_logic_vector(1 downto 0);
    v           : std_ulogic;
  end record;

  constant csr_dcsr_rst : csr_dcsr_type := (
    xdebugver   => "0100",
    ebreakm     => '0',
    ebreaks     => '0',
    ebreaku     => '0',
    ebreakvs    => '0',
    ebreakvu    => '0',
    stepie      => '0',
    stopcount   => '0',
    stoptime    => '0',
    cause       => "000",
    mprven      => '0',
    nmip        => '0',
    step        => '0',
    prv         => "11",
    v           => '0'
    );

  type csr_dfeaturesen_type is record
    tpbuf_en    : std_ulogic;                   -- Include program buffer execution in trace/sim-disas
    tmode_dis   : std_logic_vector(4 downto 0); -- Mask trace for different privilege modes [VU,VS,S,U,M]
    nostream    : std_ulogic;   -- Do not make use of stream buffer for instruction fetch
    mmu_adfault : std_ulogic;   -- Take page fault on access/modify.
    pte_nocache : std_ulogic;   -- Use bit 8 in PTE (one of RSW) as "uncachable".
    -- Dual Issue Capabilities
    dual_dis    : std_ulogic;
    -- Branch Prediction
    btb_dis     : std_ulogic;
    jprd_dis    : std_ulogic;
    staticbp    : std_ulogic;
    staticdir   : std_ulogic;
    -- Return Address Stack
    ras_dis     : std_ulogic;
    -- Performance Features
    lbranch_dis : std_ulogic;
    lalu_dis    : std_ulogic;
    b2bst_dis   : std_ulogic;
  end record;

  constant csr_dfeaturesen_rst : csr_dfeaturesen_type := (
    tpbuf_en    => '0',
    tmode_dis   => "00000",
    nostream    => '0',
    mmu_adfault => '0',
    pte_nocache => '0',
    dual_dis    => '0',
    btb_dis     => '0',
    jprd_dis    => '0',
    staticbp    => '0',
    staticdir   => '0',
    ras_dis     => '0',
    lbranch_dis => '0',
    lalu_dis    => '0',
    b2bst_dis   => '0'
    );
  
  type csr_out_cctrl_type is record
    itcmwipe  : std_ulogic;
    dtcmwipe  : std_ulogic;
    dsnoop    : std_ulogic;
    iflush    : std_ulogic; 
    dflush    : std_ulogic; 
    dcs       : std_logic_vector(1 downto 0);
    ics       : std_logic_vector(1 downto 0);
  end record;
  constant csr_out_cctrl_rst : csr_out_cctrl_type := (
    itcmwipe  => '0',
    dtcmwipe  => '0',
    dsnoop    => '0',
    iflush    => '0',
    dflush    => '0',
    dcs       => "00",
    ics       => "00"
  );

  type csr_in_cctrl_type is record
    dflushpend  : std_ulogic;
    iflushpend  : std_ulogic;
    itcmwipe    : std_ulogic;
    dtcmwipe    : std_ulogic;
  end record;
  constant csr_in_cctrl_rst : csr_in_cctrl_type := (
    iflushpend  => '0',
    dflushpend  => '0',
    itcmwipe    => '0',
    dtcmwipe    => '0'
  );

  -- 0-2 of hpmcounter_type and hpmevent_vec are not used!
  type hpmcounter_type is array (0 to HWPERFMONITORS + 3 - 1) of word64;
  type hpmevent_type is record
    overflow : std_ulogic;
    minh     : std_ulogic;
    sinh     : std_ulogic;
    uinh     : std_ulogic;
    vsinh    : std_ulogic;
    vuinh    : std_ulogic;
    event    : word8;
  end record;

  constant hpmevent_none : hpmevent_type := ('0', '0', '0', '0', '0', '0', (others => '0'));

  type hpmevent_vec is array (0 to HWPERFMONITORS + 3 - 1) of hpmevent_type;

  subtype pmpcfg_access_type is std_logic_vector(1 downto 0);
  -- One bit extra length to deal with < condition on high NAPOT limits,
  -- and another one because it is allowed to have all 1's in the CSR and
  -- an implicit 0 above that.
  subtype pmpaddr_type       is std_logic_vector(PMPADDRBITS + 1 downto 0);
  type    pmpaddr_vec_type   is array (0 to PMPENTRIES - 1) of pmpaddr_type;

  constant pmpaddrzero : pmpaddr_type := (others => '0');

  type pmp_precalc_type is record
    valid : std_ulogic;
    low   : pmpaddr_type;
    high  : pmpaddr_type;
  end record;

  constant pmp_precalc_none : pmp_precalc_type := (
    valid => '0',
    low   => pmpaddrzero,
    high  => pmpaddrzero
  );

  type pmp_precalc_vec is array (integer range <>) of pmp_precalc_type;

  constant PMPPRECALCRES : pmp_precalc_vec(0 to PMPENTRIES - 1) := (others => pmp_precalc_none);

  type nv_csr_out_type is record
    satp        : wordx;
    vsatp       : wordx;
    hgatp       : wordx;
    mmu_adfault : std_ulogic;   -- Take page fault on access/modify.
    pte_nocache : std_ulogic;   -- Use bit 8 in PTE (one of RSW) as "uncachable".
    pmpcfg0     : word64;
    pmpcfg2     : word64;
    precalc     : pmp_precalc_vec(0 to PMPENTRIES - 1);
    cctrl       : csr_out_cctrl_type;
  end record;
  constant nv_csr_out_type_none : nv_csr_out_type := (
    satp        => (others => '0'),
    vsatp       => (others => '0'),
    hgatp       => (others => '0'),
    mmu_adfault => '0',
    pte_nocache => '0',
    pmpcfg0     => (others => '0'),
    pmpcfg2     => (others => '0'),
    precalc     => PMPPRECALCRES,
    cctrl       => csr_out_cctrl_rst
  );
  type nv_csr_in_type is record
    cctrl       : csr_in_cctrl_type;
    cconfig     : word64;
  end record;
  constant nv_csr_in_type_none : nv_csr_in_type := (
    cctrl       => csr_in_cctrl_rst,
    cconfig     => (others => '0')
  );

  type csr_reg_type is record
    -- Machine ISA (needs to be configured before use!)
    misa        : wordx;
    -- Privileged Level (not addressable as a CSR register)
    prv         : std_logic_vector(1 downto 0);
    -- Virtualization mode
    v           : std_ulogic;
    -- User Floating-Point CSRs
    fctrl       : std_logic_vector(15 downto 8);  -- qqq Non-standard!
    frm         : std_logic_vector(7 downto 5);
    fflags      : std_logic_vector(4 downto 0);
    -- Hypervisor
    hstatus     : csr_hstatus_type;
    hedeleg     : wordx;
    hideleg     : wordx;
    hvip        : wordx;
    hip         : wordx;
    hie         : wordx;
    hgeip       : wordx;
    hgeie       : wordx;
    hcounteren  : word;
    htimedelta  : word64;
    htval       : wordx;
    htinst      : wordx;
    hgatp       : wordx;
    -- Virtual Supervisor
    vsstatus    : csr_status_type;
    vstvec      : wordx;
    vsscratch   : wordx;
    vsepc       : wordx;
    vscause     : wordx;
    vstval      : wordx;
    vsatp       : wordx;
    -- Supervisor Trap Setup
    stvec       : wordx;
    scounteren  : word;
    -- Supervisor Trap Handling
    sscratch    : wordx;
    sepc        : wordx;
    scause      : wordx;
    stval       : wordx;
    -- Supervisor Protection and Translation
    satp        : wordx;
    -- Machine Trap Setup
    mstatus     : csr_status_type;
    medeleg     : wordx;
    mideleg     : wordx;
    mie         : wordx;
    mtvec       : wordx;
    mcounteren  : word;
    -- Machine Trap Handling
    mscratch    : wordx;
    mepc        : wordx;
    mcause      : wordx;
    mtval       : wordx;
    mip         : wordx;
    -- Machine Trap Handling added by Hypervisor extension
    mtval2      : wordx;
    mtinst      : wordx;
    -- Machine Protection and Translation
    pmpcfg0     : word64;
    pmpcfg2     : word64;
    pmpaddr     : pmpaddr_vec_type;
    pmp_precalc : pmp_precalc_vec(0 to PMPENTRIES - 1);
    -- Machine Counter/Timers
    mcycle      : word64;
    mtime       : word64;
    minstret    : word64;
    -- Debug/Trace Registers
    tcsr        : csr_tcsr_type;
    -- Core Debug Registers
    dcsr        : csr_dcsr_type;
    dpc         : wordx;
    dscratch0   : wordx;
    dscratch1   : wordx;
    -- Hardware Performance Monitors
    hpmcounter  : hpmcounter_type;
    hpmevent    : hpmevent_vec;
    mcountinhibit:word;
    -- Custom Read/Write Registers
    dfeaturesen : csr_dfeaturesen_type;
    cctrl       : csr_out_cctrl_type;
  end record;

  constant CSRRES : csr_reg_type := (
    misa        => zerox,
    prv         => PRIV_LVL_M,
    v           => '0',
    fctrl       => (others => '0'),
    frm         => (others => '0'),
    fflags      => (others => '0'),
    hstatus     => csr_hstatus_rst,
    hedeleg     => zerox,
    hideleg     => zerox,
    hvip        => zerox,
    hip         => zerox,
    hie         => zerox,
    hgeip       => zerox,
    hgeie       => zerox,
    hcounteren  => zerow,
    htimedelta  => zerow64,
    htval       => zerox,
    htinst      => zerox,
    hgatp       => zerox,
    vsstatus    => csr_status_rst,
    vstvec      => zerox,
    vsscratch   => zerox,
    vsepc       => zerox,
    vscause     => zerox,
    vstval      => zerox,
    vsatp       => zerox,
    stvec       => zerox,
    scounteren  => zerow,
    sscratch    => zerox,
    sepc        => zerox,
    scause      => zerox,
    stval       => zerox,
    satp        => zerox,
    mstatus     => csr_status_rst,
    medeleg     => zerox,
    mideleg     => zerox,
    mie         => zerox,
    mtvec       => zerox,
    mcounteren  => zerow,
    mscratch    => zerox,
    mepc        => zerox,
    mcause      => zerox,
    mtval       => zerox,
    mip         => zerox,
    mtval2      => zerox,
    mtinst      => zerox,
    pmpcfg0     => zerow64,
    pmpcfg2     => zerow64,
    pmpaddr     => (others => pmpaddrzero),
    pmp_precalc => PMPPRECALCRES,
    mcycle      => zerow64,
    mtime       => zerow64,
    minstret    => zerow64,
    tcsr        => csr_tcsr_rst,
    dcsr        => csr_dcsr_rst,
    dpc         => zerox,
    dscratch0   => zerox,
    dscratch1   => zerox,
    hpmcounter  => (others => zerow64),
    hpmevent    => (others => hpmevent_none),
    mcountinhibit=>zerow,
    dfeaturesen => csr_dfeaturesen_rst,
    cctrl       => csr_out_cctrl_rst
    );

  -----------------------------------------------------------------------------
  -- Types
  -----------------------------------------------------------------------------

  -- FPU ------------------------------------------------------------------

  type fpu5_in_type is record
    inst        : word;
    e_valid     : std_ulogic;
    issue_id    : std_logic_vector(4 downto 0);
    csrfrm      : std_logic_vector(2 downto 0);
    flush       : std_logic_vector(1 to 4);               -- Pipeline Flush
    e_nullify   : std_ulogic;
    commit      : std_ulogic;
    commit_id   : std_logic_vector(4 downto 0);
    unissue     : std_ulogic;
    unissue_id  : std_logic_vector(4 downto 0);
    data_id     : std_logic_vector(4 downto 0);
    data_valid  : std_ulogic;
    data        : std_logic_vector(63 downto 0);
    mode        : std_logic_vector(2 downto 0);           -- Pass along for logging
    ctrl        : std_logic_vector(7 downto 0);           -- Debug control
  end record;

  constant fpu5_in_none : fpu5_in_type := (
    inst        => (others => '0'),
    e_valid     => '0',
    issue_id    => (others => '0'),
    csrfrm      => (others => '0'),
    flush       => (others => '0'),
    e_nullify   => '0',
    commit      => '0',
    commit_id   => (others => '0'),
    unissue     => '0',
    unissue_id  => (others => '0'),
    data_id     => (others => '0'),
    data_valid  => '0',
    data        => (others => '0'),
    mode        => (others => '0'),
    ctrl        => (others => '0')
    );

  type fpu5_out_type is record
    data        : std_logic_vector(63 downto 0);
    data2int    : std_logic_vector(63 downto 0);
    rd          : std_logic_vector(4 downto 0);
    wen         : std_ulogic;
    flags       : std_logic_vector(4 downto 0);
    flags_wen   : std_ulogic;
    flags2int   : std_logic_vector(4 downto 0);
    ready       : std_ulogic;
    holdn       : std_ulogic;
    mode        : std_logic_vector(2 downto 0);
    wb_id       : std_logic_vector(4 downto 0);
    idle        : std_ulogic;
    now2int     : std_ulogic;
    id2int      : std_logic_vector(4 downto 0);
    events      : std_logic_vector(63 downto 0);
  end record;

  constant fpu5_out_none : fpu5_out_type := (
    data        => (others => '0'),
    data2int    => (others => '0'),
    rd          => (others => '0'),
    wen         => '0',
    flags       => (others => '0'),
    flags_wen   => '0',
    flags2int   => (others => '0'),
    ready       => '1',
    holdn       => '1',
    mode        => (others => '0'),
    wb_id       => (others => '0'),
    idle        => '1',
    now2int     => '0',
    id2int      => (others => '0'),
    events      => (others => '0')
    );

  type fpu5_out_vector_type is array (integer range 0 to 7) of fpu5_out_type;
  type fpu5_in_vector_type  is array (integer range 0 to 7) of fpu5_in_type;

  -- Register File --------------------------------------------------------
  type iregfile_in_type is record
    raddr1      : std_logic_vector(4 downto 0);
    raddr2      : std_logic_vector(4 downto 0);
    raddr3      : std_logic_vector(4 downto 0);
    raddr4      : std_logic_vector(4 downto 0);
    ren1        : std_ulogic;
    ren2        : std_ulogic;
    ren3        : std_ulogic;
    ren4        : std_ulogic;
    rdhold      : std_ulogic;
    waddr1      : std_logic_vector(4 downto 0);
    waddr2      : std_logic_vector(4 downto 0);
    wdata1      : wordx;
    wdata2      : wordx;
    wen1        : std_ulogic;
    wen2        : std_ulogic;
  end record;

  type fregfile_in_type is record
    raddr1      : std_logic_vector(4 downto 0);
    raddr2      : std_logic_vector(4 downto 0);
    raddr3      : std_logic_vector(4 downto 0);
    ren         : std_logic_vector(1 to 3);
    waddr1      : std_logic_vector(4 downto 0);
    wen         : std_ulogic;
  end record;

  type iregfile_out_type is record
    data1       : wordx;
    data2       : wordx;
    data3       : wordx;
    data4       : wordx;
  end record;

  -- Debug stuff --------------------------------------------------------------
  type nv_intreg_mosi_type is record
    accen  : std_ulogic;
    addr   : std_logic_vector(21 downto 0);
    accwr  : std_ulogic;
    wrdata : word;
  end record;

  type nv_intreg_miso_type is record
    accrdy : std_ulogic;
    rddata : word;
  end record;

  constant nv_intreg_mosi_none: nv_intreg_mosi_type := ('0', (others => '0'), '0', (others => '0'));
  constant nv_intreg_miso_none: nv_intreg_miso_type := ('1', (others => '0'));

  -- Caches ---------------------------------------------------------------
  subtype cword3 is std_logic_vector(IDBITS3 - 1 downto 0);
  type nv_cdatatype is array (0 to MAXWAYS - 1) of std_logic_vector(63 downto 0);


  subtype addr_type is std_logic_vector(63 downto 0);

  type nv_icache_in_type is record
    rpc              : addr_type;                     -- raw address (npc)
    fpc              : addr_type;                     -- latched address (fpc)
    dpc              : addr_type;                     -- latched address (dpc)
    nostream         : std_ulogic;                    -- Force no stream buffer use
    rbranch          : std_ulogic;                    -- Instruction branch
    fbranch          : std_ulogic;                    -- Instruction branch
    inull            : std_ulogic;                    -- instruction nullify
    su               : std_ulogic;                    -- super-user
    flush            : std_ulogic;                    -- flush icache
    fline            : std_logic_vector(31 downto 3); -- flush line offset
    pnull            : std_ulogic;
    nobpmiss         : std_ulogic;                    -- Predicted instruction, block hold
    iustall          : std_ulogic;
    parkreq          : std_ulogic;                    -- Cache controller park request
    vms              : std_logic_vector(2 downto 0); -- [Virtualization mode, machine mode, supervisor mode]
  end record;

  type nv_icache_out_type is record
    data        : nv_cdatatype;
    way         : std_logic_vector(log2(MAXWAYS) - 1 downto 0);
    mexc        : std_ulogic;
    exctype     : std_ulogic;
    exchyper    : std_ulogic;
    addrhyper   : addr_type;
    typehyper   : std_logic_vector(1 downto 0);
    hold        : std_ulogic;
    flush       : std_ulogic;                    -- flush in progress
    mds         : std_ulogic;                    -- memory data strobe
    cfg         : std_logic_vector(31 downto 0);
    bpmiss      : std_ulogic;
    eocl        : std_ulogic;
    badtag      : std_ulogic;
    ics_btb     : std_logic_vector(1 downto 0);
    btb_flush   : std_logic;
    parked      : std_ulogic;
  end record;

  type nv_dcache_in_type is record
    asi              : word8;
    maddress         : addr_type;
    easi             : word8;
    eaddress         : addr_type;
    edata            : std_logic_vector(63 downto 0);
    size             : std_logic_vector(1 downto 0);
    enaddr           : std_ulogic;
    eenaddr          : std_ulogic;
    nullify          : std_ulogic;
    lock             : std_ulogic;
    read             : std_ulogic;
    write            : std_ulogic;
    specread         : std_ulogic;
    specreadannul    : std_ulogic;
    flush            : std_ulogic;
    dsuen            : std_ulogic;
    msu              : std_ulogic;                   -- memory stage supervisor
    esu              : std_ulogic;                   -- execution stage supervisor
    vms              : std_logic_vector(2 downto 0); -- [Virtualization mode, machine mode, supervisor mode]
    sum              : std_ulogic;                   -- Allow S to access U memory (except for execution).
    mxr              : std_ulogic;                   -- Make X-only pages readable (S MMU). PMP not affected!
    vmxr             : std_ulogic;                   -- Make X-only pages readable (VS MMU). PMP not affected!
    hx               : std_ulogic;                   -- Hypervisor HLVX load instruction. Execute permission needed
    intack           : std_ulogic;
    eread            : std_ulogic;
    mmucacheclr      : std_ulogic;
    amo              : std_logic_vector(5 downto 0);
    iudiag_miso      : nv_intreg_miso_type;
  end record;

  type nv_dcache_out_type is record
    data        : nv_cdatatype;
    way         : std_logic_vector(log2(MAXWAYS) - 1 downto 0);
    mexc        : std_ulogic;
    exctype     : std_ulogic;
    exchyper    : std_ulogic;
    addrhyper   : addr_type;
    typehyper   : std_logic_vector(1 downto 0);
    hold        : std_ulogic;
    mds         : std_ulogic;
    werr        : std_ulogic;
    cache       : std_ulogic;
    wbhold      : std_ulogic;                   -- write buffer hold
    badtag      : std_ulogic;
    iudiag_mosi : nv_intreg_mosi_type;
  end record;

  type lru_bits_type is array(1 to 4) of integer;
  constant lru_table : lru_bits_type          := (1, 1, 3, 5);

  type cram_tags is array(0 to 3) of std_logic_vector(TAGMAX - 1 downto 0);

  type nv_cram_in_type is record
    iindex      : std_logic_vector(IDXMAX-1 downto 0);
    itagen      : std_logic_vector(0 to 3);
    itagwrite   : std_ulogic;
    itagdin     : cram_tags;
    idataoffs   : std_logic_vector(1 downto 0);
    idataen     : std_logic_vector(0 to 3);
    idatawrite  : std_logic_vector(1 downto 0);
    idatadin    : std_logic_vector(63 downto 0);
    ifulladdr   : std_logic_vector(31 downto 0);
    itcmen      : std_ulogic;
    itcmwrite   : std_logic_vector(1 downto 0);
    itcmdin     : std_logic_vector(63 downto 0);
    -- Cache read port
    dtagcindex  : std_logic_vector(IDXMAX-1 downto 0);
    dtagcen     : std_logic_vector(0 to 3);
    -- Cache update and snoop hit port
    dtaguindex  : std_logic_vector(IDXMAX-1 downto 0);
    dtaguwrite  : std_logic_vector(0 to 3);
    dtagudin    : cram_tags;
    -- Combined read/update port (without snoop hit)
    dtagcuindex : std_logic_vector(IDXMAX-1 downto 0);
    dtagcuen    : std_logic_vector(0 to 3);
    dtagcuwrite : std_ulogic;
    -- Snoop tag read and write
    dtagsindex  : std_logic_vector(IDXMAX-1 downto 0);
    dtagsen     : std_logic_vector(0 to 3);
    dtagswrite  : std_ulogic;
    dtagsdin    : cram_tags;
    -- DCache data
    ddataindex  : std_logic_vector(IDXMAX-1 downto 0);
    ddataoffs   : std_logic_vector(1 downto 0);
    ddataen     : std_logic_vector(0 to 3);
    ddatawrite  : word8;
    ddatadin    : nv_cdatatype;
    ddatafulladdr : std_logic_vector(31 downto 0);
    dtcmen      : std_ulogic;
    dtcmdin     : std_logic_vector(63 downto 0);
    dtcmwrite   : word8;
  end record;

  type nv_cram_out_type is record
    itagdout  : cram_tags;
    idatadout : nv_cdatatype;
    itcmdout  : std_logic_vector(63 downto 0);
    dtagcdout : cram_tags;
    dtagsdout : cram_tags;
    ddatadout : nv_cdatatype;
    dtcmdout  : std_logic_vector(63 downto 0);
  end record;

  -- Instruction Trace ----------------------------------------------------
  type nv_trace_in_type is record
    addr             : std_logic_vector(11 downto 0);
    data             : std_logic_vector(TRACE_WIDTH-1 downto 0);
    enable           : std_logic;
    write            : std_logic_vector(TRACE_SEL-1 downto 0);
  end record;

  type nv_trace_out_type is record
    data             : std_logic_vector(TRACE_WIDTH-1 downto 0);
  end record;

  type nv_trace_2p_in_type is record
    renable          : std_logic;
    raddr            : std_logic_vector(11 downto 0);
    write            : std_logic_vector(TRACE_SEL-1 downto 0);
    waddr            : std_logic_vector(11 downto 0);
    data             : std_logic_vector(TRACE_WIDTH-1 downto 0);
  end record;

  type nv_trace_2p_out_type is record
    data             : std_logic_vector(TRACE_WIDTH-1 downto 0);
  end record;

  constant nv_trace_out_type_none : nv_trace_out_type := (
    data => (others => '0')
    );

  constant nv_trace_in_type_none : nv_trace_in_type := (
    addr    => (others => '0'),
    data    => (others => '0'),
    enable  => '0',
    write   => (others => '0')
    );

  constant nv_trace_2p_out_type_none : nv_trace_2p_out_type := (
    data => (others => '0'));

  constant nv_trace_2p_in_type_none : nv_trace_2p_in_type := (
    renable => '0',
    raddr   => (others => '0'),
    write   => (others => '0'),
    waddr   => (others => '0'),
    data    => (others => '0')
    );

  -- MUL/DIV --------------------------------------------------------------
  type mul_in_type is record
    ctrl        : std_logic_vector(2 downto 0);
    op1         : wordx;
    op2         : wordx;
    flush       : std_ulogic;
    mac         : std_ulogic;
    acc         : std_ulogic;
  end record;

  type mul_out_type is record
    nready      : std_ulogic;
    result      : wordx;
    icc         : word8;
  end record;

  type div_in_type is record
    ctrl        : std_logic_vector(2 downto 0);
    op1         : wordx; -- op1 (divident)
    op2         : wordx; -- op2 (divisor)
    flush       : std_ulogic;
  end record;

  type div_out_type is record
    nready      : std_ulogic;
    result      : wordx;
    icc         : word8;
  end record;

  constant div_in_none          : div_in_type := (
    ctrl        => (others => '0'),
    op1         => (others => '0'),
    op2         => (others => '0'),
    flush       => '0'
    );

  constant div_out_none         : div_out_type := (
    nready      => '1',
    icc         => (others => '0'),
    result      => (others => '0')
    );

  constant mul_in_none          : mul_in_type := (
    ctrl        => (others => '0'),
    op1         => (others => '0'),
    op2         => (others => '0'),
    flush       => '0',
    mac         => '0',
    acc         => '0'
    );

  constant mul_out_none         : mul_out_type := (
    nready      => '1',
    icc         => (others => '0'),
    result      => (others => '0')
    );

  -- Return Address Stack -----------------------------------------------------
  type nv_ras_in_type is record
    push        : std_ulogic;
    pop         : std_ulogic;
    wdata       : wordx;
    flush       : std_ulogic;
  end record;

  type nv_ras_out_type is record
    rdata       : wordx;
    hit         : std_ulogic;
  end record;

  constant nv_ras_out_none : nv_ras_out_type := (
    rdata       => (others => '0'),
    hit         => '0'
  );

  constant nv_ras_in_none : nv_ras_in_type := (
    push        => '0',
    pop         => '0',
    wdata       => zerox,
    flush       => '0'
  );

  -- Branch Target Buffer -----------------------------------------------------
  type nv_btb_in_type is record
    raddr       : wordx;
    waddr       : wordx;
    wen         : std_ulogic;
    wdata       : wordx;
    flush       : std_ulogic;
  end record;

  type nv_btb_out_type is record
    rdata       : wordx;
    ralign      : std_ulogic;
    hit         : std_ulogic;
    lpc         : std_logic_vector(1 downto 0);
  end record;

  constant nv_btb_out_none : nv_btb_out_type := (
    rdata       => (others => '0'),
    ralign      => '0',
    hit         => '0',
    lpc         => "00"
  );

  -- Branch History Table -----------------------------------------------------
  type nv_bht_in_type is record
    waddr        : wordx;
    wen          : std_ulogic;
    wdata        : std_logic_vector(MAX_PREDICTOR_BITS-1 downto 0);
    taken        : std_ulogic;
    raddr_comb   : wordx;
    rindex_bhist : wordx;
    bhistory     : std_logic_vector(4 downto 0);
    phistory     : std_logic_vector(63 downto 0);
    ren          : std_ulogic;
    flush        : std_ulogic;
    iustall      : std_ulogic;
  end record;

  type nv_bht_out_type is record
    taken       : std_logic_vector(3 downto 0);
    bhistory    : std_logic_vector(4 downto 0);
    phistory    : std_logic_vector(63 downto 0);
  end record;

  constant nv_bht_out_none : nv_bht_out_type := (
    taken       => (others => '0'),
    bhistory    => (others => '0'),
    phistory    => (others => '0')
  );

  -- Program buffer --------------------------------------------------------------
  type nv_progbuf_in_type is record
    addr      : std_logic_vector(4 downto 0);
    eaddr     : std_logic_vector(4 downto 0);
    write     : std_logic;
    data      : word;
  end record;
  constant nv_progbuf_in_none : nv_progbuf_in_type := (
    addr      => (others => '0'),
    eaddr     => (others => '0'),
    write     => '0',
    data      => (others => '0')
  );

  type nv_progbuf_out_type is record
    edata      : word64;
    data       : word;
  end record;
  constant nv_progbuf_out_none : nv_progbuf_out_type := (
    edata     => (others => '0'),
    data      => (others => '0')
  );

  type nv_progbuf_in_vector  is array (natural range <>) of nv_progbuf_in_type;
  type nv_progbuf_out_vector is array (natural range <>) of nv_progbuf_out_type;


  -----------------------------------------------------------------------------
  -- Components
  -----------------------------------------------------------------------------

  component iunv
    generic (
      hindex       : integer range 0  to 15;       -- Hart index
      fabtech      : integer range 0  to NTECH;    -- fabtech
      memtech      : integer range 0  to NTECH;    -- memtech
      -- Core
      physaddr     : integer range 32 to 56;       -- Physical Addressing
      pcbits       : integer range 32 to 56;       -- Max bits required for PC
      rstaddr      : integer;                      -- Reset vector (MSB)
      disas        : integer;                      -- Disassembly to console
      perf_cnts    : integer range 0  to 29;       -- Number of performance counters
      perf_evts    : integer range 0  to 255;      -- Number of performance events
      perf_bits    : integer range 0  to 64;       -- Bits of performance counting
      illegalTval0 : integer range 0  to 1;        -- Zero TVAL on illegal instruction
      no_muladd    : integer range 0  to 1;        -- 1 - multiply-add not supported
      single_issue : integer range 0  to 1;        -- 1 - only one pipeline
      -- Caches
      iways        : integer range 1  to 4;        -- I$ Ways
      dways        : integer range 1  to 4;        -- D$ Ways
      itcmen       : integer range 0  to 1;        -- Instruction TCM
      dtcmen       : integer range 0  to 1;        -- Data TCM
      -- MMU
      mmuen        : integer range 0  to 2;        -- >0 - MMU enable
      riscv_mmu    : integer range 0  to 3;
      pmp_no_tor   : integer range 0  to 1;        -- Disable PMP TOR
      pmp_entries  : integer range 0  to 16;       -- Implemented PMP registers
      pmp_g        : integer range 0  to 10;       -- PMP grain is 2^(pmp_g + 2) bytes
      -- Extensions
      ext_m        : integer range 0  to 1;        -- M Base Extension Set
      ext_a        : integer range 0  to 1;        -- A Base Extension Set
      ext_c        : integer range 0  to 1;        -- C Base Extension Set
      ext_h        : integer range 0  to 1;        -- H Extension
      ext_zba      : integer range 0  to 1;        -- Zba Extension
      ext_zbb      : integer range 0  to 1;        -- Zbb Extension
      ext_zbc      : integer range 0  to 1;        -- Zbc Extension
      ext_zbs      : integer range 0  to 1;        -- Zbs Extension
      ext_zbkb     : integer range 0  to 1;        -- Zbkb Extension
      ext_zbkc     : integer range 0  to 1;        -- Zbkc Extension
      ext_zbkx     : integer range 0  to 1;        -- Zbkx Extension
      ext_sscofpmf : integer range 0  to 1;        -- Sscofpmf Extension
      mode_s       : integer range 0  to 1;        -- Supervisor Mode Support
      mode_u       : integer range 0  to 1;        -- User Mode Support
      dmen         : integer range 0  to 1;        -- Using RISC-V Debug Module
      fpulen       : integer range 0  to 128;      -- Floating-point precision
      fpuconf      : integer range 0  to 1;        -- 0 = nanoFPUnv, 1 = GRFPUnv
      trigger      : integer;
      -- Advanced Features
      late_branch  : integer range 0  to 1;        -- Late Branch Support
      late_alu     : integer range 0  to 1;        -- Late ALUs Support
      -- Misc
      pbaddr       : integer;                      -- Program buffer exe address
      tbuf         : integer;                      -- Trace buffer size in kB
      scantest     : integer;                      -- Scantest support
      rfreadhold   : integer range 0  to 1 := 0;   -- Register File Read Hold
      endian       : integer               := GRLIB_CONFIG_ARRAY(grlib_little_endian)
      );
    port (
      clk            : in  std_ulogic;           -- clk
      rstn           : in  std_ulogic;           -- active low reset
      holdn          : in  std_ulogic;           -- active low hold signal
      ici            : out nv_icache_in_type;    -- I$ In Port
      ico            : in  nv_icache_out_type;   -- I$ Out Port
      bhti           : out nv_bht_in_type;       -- BHT In Port
      bhto           : in  nv_bht_out_type;      -- BHT Out Port
      btbi           : out nv_btb_in_type;       -- BTB In Port
      btbo           : in  nv_btb_out_type;      -- BTB Out Port
      rasi           : out nv_ras_in_type;       -- RAS In Port
      raso           : in  nv_ras_out_type;      -- RAS Out Port
      dci            : out nv_dcache_in_type;    -- D$ In Port
      dco            : in  nv_dcache_out_type;   -- D$ Out Port
      rfi            : out iregfile_in_type;     -- Regfile In Port
      rfo            : in  iregfile_out_type;    -- Regfile Out Port
      irqi           : in  nv_irq_in_type;       -- Irq In Port
      irqo           : out nv_irq_out_type;      -- Irq Out Port
      dbgi           : in  nv_debug_in_type;     -- Debug In Port
      dbgo           : out nv_debug_out_type;    -- Debug Out Port
      muli           : out mul_in_type;          -- Mul Unit In Port
      mulo           : in  mul_out_type;         -- Mul Unit Out Port
      divi           : out div_in_type;          -- Div Unit In Port
      divo           : in  div_out_type;         -- Div Unit Out Port
      fpui           : out fpu5_in_type;         -- FPU Unit In Port
      fpuo           : in  fpu5_out_type;        -- FPU Unit Out Port
      cnt            : out nv_counter_out_type;  -- Perf counters
      csr_mmu        : out nv_csr_out_type;         -- CSR values for MMU
      mmu_csr        : in  nv_csr_in_type;          -- CSR values for MMU
      perf           : in  std_logic_vector(31 downto 0);
      cap            : in  std_logic_vector(6  downto 0);
      tbo            : in  nv_trace_out_type;    -- Trace Unit Out Port
      tbi            : out nv_trace_in_type;     -- Trace Unit In Port
      eto            : out nv_etrace_out_type;
      sclk           : in  std_ulogic;
      testen         : in  std_ulogic;
      testrst        : in  std_ulogic
      );
  end component;

  component tbufmemnv
    generic (
      tech      : integer;
      tbuf      : integer;   -- Trace buf size in kB (0 - no trace buffer)
      dwidth    : integer;   -- AHB data width
      proc      : integer;
      testen    : integer
      );
    port (
      clk       : in  std_ulogic;
      di        : in  nv_trace_in_type;
      do        : out nv_trace_out_type;
      testin    : in  std_logic_vector(TESTIN_WIDTH-1 downto 0)
      );
  end component;

  component regfile64sramnv
    generic (
      tech        : integer;
      abits       : integer;
      dbits       : integer;
      numregs     : integer;
      reg0write   : integer := 0;
      dissue      : integer := 1;
      testen      : integer
      );
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      rdhold   : in  std_ulogic;
      waddr1   : in  std_logic_vector((abits -1) downto 0);
      wdata1   : in  std_logic_vector((dbits -1) downto 0);
      we1      : in  std_ulogic;
      waddr2   : in  std_logic_vector((abits -1) downto 0);
      wdata2   : in  std_logic_vector((dbits -1) downto 0);
      we2      : in  std_ulogic;
      raddr1   : in  std_logic_vector((abits -1) downto 0);
      re1      : in  std_ulogic;
      rdata1   : out std_logic_vector((dbits -1) downto 0);
      raddr2   : in  std_logic_vector((abits -1) downto 0);
      re2      : in  std_ulogic;
      rdata2   : out std_logic_vector((dbits -1) downto 0);
      raddr3   : in  std_logic_vector((abits -1) downto 0);
      re3      : in  std_ulogic;
      rdata3   : out std_logic_vector((dbits -1) downto 0);
      raddr4   : in  std_logic_vector((abits -1) downto 0);
      re4      : in  std_ulogic;
      rdata4   : out std_logic_vector((dbits -1) downto 0);
      testin   : in  std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
      );
  end component;

  component regfile64dffnv is
    generic (
      tech        : integer;
      abits       : integer;
      dbits       : integer;
      wrfst       : integer;
      numregs     : integer;
      reg0write   : integer := 0
      );
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      rdhold   : in  std_ulogic;
      waddr1   : in  std_logic_vector((abits -1) downto 0);
      wdata1   : in  std_logic_vector((dbits -1) downto 0);
      we1      : in  std_ulogic;
      waddr2   : in  std_logic_vector((abits -1) downto 0);
      wdata2   : in  std_logic_vector((dbits -1) downto 0);
      we2      : in  std_ulogic;
      raddr1   : in  std_logic_vector((abits -1) downto 0);
      re1      : in  std_ulogic;
      rdata1   : out std_logic_vector((dbits -1) downto 0);
      raddr2   : in  std_logic_vector((abits -1) downto 0);
      re2      : in  std_ulogic;
      rdata2   : out std_logic_vector((dbits -1) downto 0);
      raddr3   : in  std_logic_vector((abits -1) downto 0);
      re3      : in  std_ulogic;
      rdata3   : out std_logic_vector((dbits -1) downto 0);
      raddr4   : in  std_logic_vector((abits -1) downto 0);
      re4      : in  std_ulogic;
      rdata4   : out std_logic_vector((dbits -1) downto 0)
      );
  end component;

  component cachememnv is
    generic (
      tech      : integer range 0 to   NTECH;
      iways     : integer range 1 to   4;
      ilinesize : integer range 4 to   8;
      iidxwidth : integer range 1 to  10;
      itagwidth : integer range 1 to  32;
      itcmen    : integer range 0 to   1;
      itcmabits : integer range 1 to  20;
      dways     : integer range 1 to   4;
      dlinesize : integer range 4 to   8;
      didxwidth : integer range 1 to  10;
      dtagwidth : integer range 1 to  32;
      dtagconf  : integer range 0 to   2;
      dusebw    : integer range 0 to   1;
      dtcmen    : integer range 0 to   1;
      dtcmabits : integer range 1 to  20;
      testen    : integer range 0 to   1
      );
    port (
      rstn   : in  std_ulogic;
      clk    : in  std_ulogic;
      sclk   : in  std_ulogic;
      crami  : in  nv_cram_in_type;
      cramo  : out nv_cram_out_type;
      testin : in  std_logic_vector(TESTIN_WIDTH - 1 downto 0)
      );
  end component;

  component cctrlnv is
    generic (
      hindex     : integer;
      -- Core
      physaddr   : integer range 32 to 56;   -- Physical Addressing
      -- Caches
      iways      : integer range 1 to   4;   -- I$ ways
      ilinesize  : integer range 4 to   8;   --    cache line size (32 bit words)
      iwaysize   : integer range 1 to 256;   --    way size (KiB)
      dways      : integer range 1 to   4;   -- D$ ways
      dlinesize  : integer range 4 to   8;   --    cache line size (32 bit words)
      dwaysize   : integer range 1 to 256;   --    way size (KiB)
      dtagconf   : integer range 0 to   2;
      dusebw     : integer range 0 to   1;
      itcmen     : integer range 0 to   1;
      itcmabits  : integer range 1 to  20;
      dtcmen     : integer range 0 to   1;
      dtcmabits  : integer range 1 to  20;
      -- MMU
      itlbnum    : integer range 2 to  64;   -- # instruction  TLB entries
      dtlbnum    : integer range 2 to  64;   -- # data TLB entries
      htlbnum    : integer range 1 to  64;   -- # hypervisor TLB entries
      riscv_mmu  : integer range 0 to   3;
      pmp_no_tor : integer range 0 to   1;   -- Disable PMP TOR
      pmp_entries: integer range 0 to  16;   -- Implemented PMP registers
      pmp_g      : integer range 0 to  10;   -- PMP grain is 2^(pmp_g + 2) bytes
      asidlen    : integer range 0 to  16;   -- Max 9 for Sv32
      vmidlen    : integer range 0 to  14;   -- Max 7 for Sv32
      ext_a      : integer range 0 to   1;   -- Support for Atomic operations
      ext_h      : integer range 0 to   1;   -- Support for Hypervisor, needs tlb_pmp if any PMP.
      tlb_pmp    : integer range 0 to   1;   -- Do PMP via TLB
      -- Misc
      cached     : integer;                  -- Mask indexed by 4 MSB of address regarding cacheability when no TLB used
      wbmask     : integer;                  -- ?
      busw       : integer;                  -- AHB bus width in bits
      cdataw     : integer;                  -- Cache memory width in bits
      icrepl     : integer;                  -- Address replication for TLB lookup
      dcrepl     : integer;
      hrepl      : integer;
      mmuen      : integer range 0 to   1;
      endian     : integer := GRLIB_CONFIG_ARRAY(grlib_little_endian)
    );
    port (
      rst        : in  std_ulogic;
      clk        : in  std_ulogic;
      ici        : in  nv_icache_in_type;
      ico        : out nv_icache_out_type;
      dci        : in  nv_dcache_in_type;
      dco        : out nv_dcache_out_type;
      ahbi       : in  ahb_mst_in_type;
      ahbo       : out ahb_mst_out_type;
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : in  ahb_slv_out_vector;
      crami      : out nv_cram_in_type;
      cramo      : in  nv_cram_out_type;
      sclk       : in  std_ulogic;
      csro       : in  nv_csr_out_type := nv_csr_out_type_none;
      csri       : out nv_csr_in_type := nv_csr_in_type_none;
      fpc_mosi   : out nv_intreg_mosi_type;
      fpc_miso   : in  nv_intreg_miso_type;
      c2c_mosi   : out nv_intreg_mosi_type;
      c2c_miso   : in  nv_intreg_miso_type;
      freeze     : in  std_ulogic;
      bootword   : in  std_logic_vector(31 downto 0);
      smpflush   : in  std_logic_vector(1 downto 0);
      perf       : out std_logic_vector(31 downto 0)
      );
  end component cctrlnv;

  component mul64 is
    generic (
      fabtech  : integer range 0 to NTECH := 0;
      arch     : integer := 0;
      split    : integer := 1;
      scantest : integer := 0
    );
    port (
      clk     : in  std_ulogic;
      rstn    : in  std_ulogic;
      holdn   : in  std_ulogic;
      ctrl    : in  std_logic_vector(2 downto 0);
      op1     : in  std_logic_vector;
      op2     : in  std_logic_vector;
      nready  : out std_ulogic;
      mresult : out std_logic_vector;
      testen  : in  std_ulogic := '0';
      testrst : in  std_ulogic := '1'
    );
  end component mul64;

  component div64
    generic (
      fabtech   : integer range 0 to NTECH := 0;
      scantest  : integer := 0;
      hiperf    : integer := 0;
      small     : integer := 0;
      in_pipe   : integer := 1
      );
    port (
      clk       : in  std_ulogic;
      rstn      : in  std_ulogic;
      holdn     : in  std_ulogic;
      divi      : in  div_in_type;
      divo      : out div_out_type;
      testen    : in  std_ulogic := '0';
      testrst   : in  std_ulogic := '1'
      );
  end component;

  component bhtnv is
    generic (
      tech        : integer                       := 0;
      nentries    : integer range 32 to 1024      := 256;       -- Number of Entries
      hlength     : integer range 2  to 10        := 5;         -- History Length
      predictor   : integer range 0  to 2         := 0;         -- Predictor
      ext_c       : integer range 0  to 1         := 1;         -- C Base Extension Set
      dissue      : integer range 0 to  1         := 1;          -- Dual issue
      testen      : integer                       := 0
      );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      holdn       : in  std_ulogic;
      bhti        : in  nv_bht_in_type;
      bhto        : out nv_bht_out_type;
      testin       : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
      );
  end component;

  component btbnv is
    generic (
      nentries    : integer range 8  to 128       := 32;        -- Number of Entries
      nsets       : integer range 1  to 8         := 1;         -- Associativity
      pcbits      : integer range 32 to 48        := 32;
      ext_c       : integer range 0  to 1         := 0          -- C Base Extension Set
      );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      btbi        : in  nv_btb_in_type;
      btbo        : out nv_btb_out_type
      );
  end component;

  component btbdmnv is
    generic (
      nentries : integer range 1 to 32;  -- Number of Entries
      pcbits   : integer range 32 to 56;
      dissue   : integer range 0 to 1
      );
    port (
      clk  : in  std_ulogic;
      rstn : in  std_ulogic;
      btbi : in  nv_btb_in_type;
      btbo : out nv_btb_out_type
      );
  end component;

  component rasnv is
    generic (
      depth       : integer range 0  to 8         := 4;
      pcbits      : integer range 32 to 48        := 32
      );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      rasi        : in  nv_ras_in_type;
      raso        : out nv_ras_out_type
      );
  end component;

  component progbuf
    generic (
      size : integer range 0 to 16
    );
    port (
      clk   : in  std_ulogic;
      rstn  : in  std_ulogic;
      pbi   : in  nv_progbuf_in_type;
      pbo   : out nv_progbuf_out_type
    );
  end component;


  component nanofpunv is
    generic (
      fpulen    : integer range 0 to 128;
      no_muladd : integer range 0 to 1
    );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      holdn       : in  std_ulogic;
      e_inst      : in  word;
      e_valid     : in  std_ulogic;
      e_nullify   : in  std_ulogic;
      issue_id    : in  std_logic_vector(4 downto 0);
      csrfrm      : in  std_logic_vector(2 downto 0);
      mode_in     : in  std_logic_vector(2 downto 0);
      s1          : in  std_logic_vector(63 downto 0);
      s2          : in  std_logic_vector(63 downto 0);
      s3          : in  std_logic_vector(63 downto 0);
      fpu_holdn   : out std_ulogic;
      ready_flop  : out std_ulogic;
      commit      : in  std_ulogic;
      commit_id   : in  std_logic_vector(4 downto 0);
      lddata_id   : in  std_logic_vector(4 downto 0);
      lddata_now  : in  std_ulogic;
      lddata      : in  std_logic_vector(63 downto 0);
      unissue     : in  std_ulogic;
      unissue_id  : in  std_logic_vector(4 downto 0);
      rs1         : out std_logic_vector(4 downto 0);
      rs2         : out std_logic_vector(4 downto 0);
      rs3         : out std_logic_vector(4 downto 0);
      ren         : out std_logic_vector(1 to 3);
      rd          : out std_logic_vector(4 downto 0);
      wen         : out std_ulogic;
      stdata      : out std_logic_vector(63 downto 0);
      flags_wen   : out std_ulogic;
      flags       : out std_logic_vector(4 downto 0);
      now2int     : out std_ulogic;
      id2int      : out std_logic_vector(4 downto 0);
      stdata2int  : out std_logic_vector(63 downto 0);
      flags2int   : out std_logic_vector(4 downto 0);
      wb_mode     : out std_logic_vector(2 downto 0);
      wb_id       : out std_logic_vector(4 downto 0);
      idle        : out std_ulogic;
      events      : out std_logic_vector(63 downto 0)
      );
  end component;

  component pfpunv is
    generic (
      fpulen    : integer range 0 to 128;
      mulconf   : integer range 0 to 1
    );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      holdn       : in  std_ulogic;
      e_inst      : in  word;
      e_valid     : in  std_ulogic;
      e_nullify   : in  std_ulogic;
      issue_id    : in  std_logic_vector(4 downto 0);
      csrfrm      : in  std_logic_vector(2 downto 0);
      mode_in     : in  std_logic_vector(2 downto 0);
      s1          : in  std_logic_vector(63 downto 0);
      s2          : in  std_logic_vector(63 downto 0);
      s3          : in  std_logic_vector(63 downto 0);
      fpu_holdn   : out std_ulogic;
      ready_flop  : out std_ulogic;
      commit      : in  std_ulogic;
      commit_id   : in  std_logic_vector(4 downto 0);
      lddata_id   : in  std_logic_vector(4 downto 0);
      lddata_now  : in  std_ulogic;
      lddata      : in  std_logic_vector(63 downto 0);
      unissue     : in  std_ulogic;
      unissue_id  : in  std_logic_vector(4 downto 0);
      rs1         : out std_logic_vector(4 downto 0);
      rs2         : out std_logic_vector(4 downto 0);
      rs3         : out std_logic_vector(4 downto 0);
      ren         : out std_logic_vector(1 to 3);
      rd          : out std_logic_vector(4 downto 0);
      wen         : out std_ulogic;
      flags_wen   : out std_ulogic;
      stdata      : out std_logic_vector(63 downto 0);
      flags       : out std_logic_vector(4 downto 0);
      now2int     : out std_ulogic;
      stdata2int  : out std_logic_vector(63 downto 0);
      flags2int   : out std_logic_vector(4 downto 0);
      wb_mode     : out std_logic_vector(2 downto 0);
      wb_id       : out std_logic_vector(4 downto 0);
      idle        : out std_ulogic
    );
  end component;

  component pipefpunv is
    generic (
      fpulen    : integer range 0 to 128;
      mulconf   : integer range 0 to 1
    );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      holdn       : in  std_ulogic;
      e_inst      : in  word;
      e_valid     : in  std_ulogic;
      e_nullify   : in  std_ulogic;
      issue_id    : in  std_logic_vector(4 downto 0);
      csrfrm      : in  std_logic_vector(2 downto 0);
      mode_in     : in  std_logic_vector(2 downto 0);
      s1          : in  std_logic_vector(63 downto 0);
      s2          : in  std_logic_vector(63 downto 0);
      s3          : in  std_logic_vector(63 downto 0);
      fpu_holdn   : out std_ulogic;
      ready_flop  : out std_ulogic;
      commit      : in  std_ulogic;
      commit_id   : in  std_logic_vector(4 downto 0);
      lddata_id   : in  std_logic_vector(4 downto 0);
      lddata_now  : in  std_ulogic;
      lddata      : in  std_logic_vector(63 downto 0);
      unissue     : in  std_ulogic;
      unissue_id  : in  std_logic_vector(4 downto 0);
      rs1         : out std_logic_vector(4 downto 0);
      rs2         : out std_logic_vector(4 downto 0);
      rs3         : out std_logic_vector(4 downto 0);
      ren         : out std_logic_vector(1 to 3);
      rd          : out std_logic_vector(4 downto 0);
      wen         : out std_ulogic;
      stdata      : out std_logic_vector(63 downto 0);
      flags_wen   : out std_ulogic;
      flags       : out std_logic_vector(4 downto 0);
      now2int     : out std_ulogic;
      id2int      : out std_logic_vector(4 downto 0);
      stdata2int  : out std_logic_vector(63 downto 0);
      flags2int   : out std_logic_vector(4 downto 0);
      wb_mode     : out std_logic_vector(2 downto 0);
      wb_id       : out std_logic_vector(4 downto 0);
      idle        : out std_ulogic;
      events      : out std_logic_vector(63 downto 0);
      ctrl        : in  std_logic_vector(7 downto 0) := x"00"
    );
  end component;

  component cpu_disas
    port (
      clk           : in  std_ulogic;
      rstn          : in  std_ulogic;
      dummy         : out std_ulogic;
      index         : in  std_logic_vector(3 downto 0);     -- Hart Index
      way           : in  std_logic_vector(2 downto 0);     -- Way Index
      ivalid        : in  std_ulogic;                       -- Valid Instruction
      inst          : in  std_logic_vector(31 downto 0);    -- Instruction
      cinst         : in  std_logic_vector(15 downto 0);    -- Compressed Instruction
      comp          : in  std_ulogic;                       -- Compressed Flag
      pc            : in  std_logic_vector;                 -- PC
      wregen        : in  std_ulogic;                       -- Regfile Write Enable
      wregdata      : in  std_logic_vector;                 -- Regfile Write Data
      wcsren        : in  std_ulogic;                       -- CSR Write Enable
      wcsrdata      : in  std_logic_vector;                 -- CSR Write Data
      prv           : in  std_logic_vector(1 downto 0);     -- Privileged Level
      trap          : in  std_ulogic;                       -- Exception
      trap_taken    : in  std_ulogic;
      cause         : in  std_logic_vector;                 -- Exception Cause
      tval          : in  std_logic_vector;                 -- Exception Value
      cycle         : in  std_logic_vector(63 downto 0);
      instret       : in  std_logic_vector(63 downto 0);
      dual          : in  std_logic_vector(63 downto 0);
      disas         : in  std_ulogic);                      -- Disassembly Enabled
  end component;

  component rvdmx
    generic (
      hindex      : integer range 0  to 15        := 0;   -- bus index
      haddr       : integer                       := 16#900#;
      hmask       : integer                       := 16#f00#;
      nharts      : integer                       := 1;   -- number of harts
      tbits       : integer                       := 30;  -- timer bits (instruction trace time tag)
      tech        : integer                       := DEFMEMTECH;
      kbytes      : integer                       := 0;   -- Size of trace buffer memory in KiB
      -- Debug Module
      datacount   : integer range 0  to 12        := 4;   -- Number of data registers
      nscratch    : integer                       := 2;   -- Number of scratch registers
      unavailtimeout:integer range 0  to 1024     := 64;  -- Clock cycles timeout
      progbufsize : integer range 0  to 16        := 8;   -- Program Buffer Size
      scantest    : integer                       := 0
      );
    port (
      rst    : in  std_ulogic;
      hclk   : in  std_ulogic;
      cpuclk : in  std_ulogic;
      fcpuclk: in  std_ulogic;
      ahbmi  : in  ahb_mst_in_type;
      ahbsi  : in  ahb_slv_in_type;
      ahbso  : out ahb_slv_out_type;
      tahbsi : in  ahb_slv_in_type;
      dbgi   : in  nv_debug_out_vector(0 to NHARTS-1);
      dbgo   : out nv_debug_in_vector(0 to NHARTS-1);
      dsui   : in  nv_dm_in_type;
      dsuo   : out nv_dm_out_type;
      hclken : in  std_ulogic
      );
  end component;


  component inst_text is
    port (
      inst : in std_logic_vector(31 downto 0));
  end component;

  -----------------------------------------------------------------------------
  -- Functions Declarations
  -----------------------------------------------------------------------------

  function cause_bit(bits : std_logic_vector; cause : cause_type) return std_logic;
  function is_irq(cause : cause_type) return boolean;
  function cause2wordx(cause : cause_type) return wordx;
  function cause2vec(cause : cause_type; vec_in : std_logic_vector) return std_logic_vector;

  function to_floating(fpulen : integer;  set : integer) return integer;

  function amo_math_op(
    op1_in  : std_logic_vector;
    op2_in  : std_logic_vector;
    ctrl_in : std_logic_vector(3 downto 0)) return std_logic_vector;


  function mmuen_set(mmuen : integer) return integer;

  -- Constants and Mask
  function extend_wordx(v : std_logic_vector) return wordx;
  function satp_mask(id : integer; physaddr : integer) return wordx;
  function medeleg_mask(h_en : boolean) return wordx;
  function to_mideleg(
    wcsr         : wordx;
    mode_s       : integer;
    h_en         : boolean;
    ext_n        : integer;
    ext_sscofpmf : integer) return wordx;
  function mip_mask(mode_s : integer; h_en : boolean;
                    ext_n  : integer; ext_sscofpmf : integer) return wordx;
  function mie_mask(mode_s : integer; h_en : boolean;
                    ext_n  : integer; ext_sscofpmf : integer) return wordx;

  function to_hstatus(status : csr_hstatus_type) return wordx;
  function to_hstatus(wdata : wordx) return csr_hstatus_type;

  function to_vsstatus(status : csr_status_type) return wordx;
  function to_vsstatus(wdata : wordx) return csr_status_type;

  function to_mstatus(status : csr_status_type) return wordx;
  function to_mstatus(wdata : wordx; mstatus_in : csr_status_type) return csr_status_type;

  function to_mstatush(status : csr_status_type) return wordx;
  function to_mstatush(wdata : wordx; mstatus_in : csr_status_type) return csr_status_type;

  function to_sstatus(status : csr_status_type) return wordx;
  function to_sstatus(wdata : wordx; mstatus : csr_status_type) return csr_status_type;

  function to_ustatus(status : csr_status_type) return wordx;
  function to_ustatus(wdata : wordx; mstatus : csr_status_type) return csr_status_type;


  function to_capabilityh(fpuconf : std_logic_vector(1 downto 0); cconfig : word64) return word;
  function to_capability(fpuconf : std_logic_vector(1 downto 0); cconfig : word64) return wordx;

  function to_hpmevent(wdata : wordx; hpmevent_in : hpmevent_type) return hpmevent_type;
  function to_hpmeventh(wdata : wordx; hpmevent_in : hpmevent_type) return hpmevent_type;

  function to_hpmevent(hpmevent : hpmevent_type) return wordx;
  function to_hpmeventh(hpmevent : hpmevent_type) return wordx;

  procedure pmp_precalc(pmpaddr     : in  pmpaddr_vec_type;
                        pmpcfg0     : in  word64;
                        pmpcfg2     : in  word64;
                        precalc     : out pmp_precalc_vec;
                        pmp_entries : integer;
                        pmp_no_tor  : integer;
                        pmp_g       : integer;
                        msb         : integer := 31
                       );

  procedure pmp_unit(prv_in             : in  std_logic_vector(PRIV_LVL_M'range);
                     precalc            : in  pmp_precalc_vec;
                     pmpcfg0_in         : in  word64;
                     pmpcfg2_in         : in  word64;
                     mprv_in            : in  std_ulogic;
                     mpp_in             : in  std_logic_vector(PRIV_LVL_M'range);
                     addr_in            : in  std_logic_vector;
                     access_in          : in  std_logic_vector(PMP_ACCESS_X'range);
                     valid_in           : in  std_ulogic;
                     xc_out             : out std_ulogic;
                     entries            : in  integer := 16;
                     no_tor             : in  integer := 1;
                     pmp_g              : in  integer range 1 to 32 := 1;
                     msb                : in  integer := 31
                    );

  procedure pmp_mmuu(precalc            : in  pmp_precalc_vec;
                     pmpcfg0_in         : in  word64;
                     pmpcfg2_in         : in  word64;
                     addr_low           : in  std_logic_vector;
                     addr_mask          : in  std_logic_vector;
                     valid              : in  std_ulogic;
                     hit_out            : out std_logic_vector;
                     fit_out            : out std_logic_vector;
                     l_out              : out std_logic_vector;
                     r_out              : out std_logic_vector;
                     w_out              : out std_logic_vector;
                     x_out              : out std_logic_vector;
                     no_tor             : in  integer := 1;
                     msb                : in  integer := 31
                    );

end package;

package body noelvint is
  function hpmevent(event : integer) return hpmevent_type is
  begin
    return to_hpmevent(conv_std_logic_vector(event, XLEN), hpmevent_none);
  end;


  -----------------------------------------------------------------------------
  -- Functions Definitions
  -----------------------------------------------------------------------------

  function to_cause(code : integer; irq : boolean := false) return cause_type is
    -- Non-constant
    variable v : cause_type := conv_std_logic_vector(code, cause_type'length);
  begin
    if irq then
      v(v'high) := '1';
    end if;

    return v;
  end;

  function cause_bit(bits : std_logic_vector; cause : cause_type) return std_logic is
    variable n : integer := to_integer(unsigned(cause(cause'high - 1 downto 0)));
  begin
    return bits(n);
  end;

  function is_irq(cause : cause_type) return boolean is
  begin
    return get_hi(cause) = '1';
  end;

  function cause2wordx(cause : cause_type) return wordx is
    -- Non-constant
    variable v : wordx := zerox;
  begin
    v(cause'high - 1 downto 0) := cause(cause'high - 1 downto 0);
    v(v'high)                  := cause(cause'high);

    return v;
  end;

  function cause2vec(cause : cause_type; vec_in : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable vec : std_logic_vector(vec_in'length - 1 downto 0) := vec_in;
  begin
    vec(0) := '0';
    vec(cause'high + 1 downto 2) := cause(cause'high - 1 downto 0);

    return vec;
  end;

  constant XC_INST_ADDR_MISALIGNED      : cause_type := to_cause(0);
  constant XC_INST_ACCESS_FAULT         : cause_type := to_cause(1);
  constant XC_INST_ILLEGAL_INST         : cause_type := to_cause(2);
  constant XC_INST_BREAKPOINT           : cause_type := to_cause(3);
  constant XC_INST_LOAD_ADDR_MISALIGNED : cause_type := to_cause(4);
  constant XC_INST_LOAD_ACCESS_FAULT    : cause_type := to_cause(5);
  constant XC_INST_STORE_ADDR_MISALIGNED: cause_type := to_cause(6);
  constant XC_INST_STORE_ACCESS_FAULT   : cause_type := to_cause(7);
  constant XC_INST_ENV_CALL_UMODE       : cause_type := to_cause(8);
  constant XC_INST_ENV_CALL_SMODE       : cause_type := to_cause(9);
  constant XC_INST_ENV_CALL_VSMODE      : cause_type := to_cause(10);
  constant XC_INST_ENV_CALL_MMODE       : cause_type := to_cause(11);
  constant XC_INST_INST_PAGE_FAULT      : cause_type := to_cause(12);
  constant XC_INST_LOAD_PAGE_FAULT      : cause_type := to_cause(13);
  constant XC_INST_STORE_PAGE_FAULT     : cause_type := to_cause(15);
  constant XC_INST_INST_G_PAGE_FAULT    : cause_type := to_cause(20);
  constant XC_INST_LOAD_G_PAGE_FAULT    : cause_type := to_cause(21);
  constant XC_INST_VIRTUAL_INST         : cause_type := to_cause(22);
  constant XC_INST_STORE_G_PAGE_FAULT   : cause_type := to_cause(23);
  constant XC_INST_RFFT                 : cause_type := to_cause(31);

  -- Interrupt Codes
  constant IRQ_U_SOFTWARE               : cause_type := to_cause(0, true);
  constant IRQ_S_SOFTWARE               : cause_type := to_cause(1, true);
  constant IRQ_VS_SOFTWARE              : cause_type := to_cause(2, true);
  constant IRQ_M_SOFTWARE               : cause_type := to_cause(3, true);
  constant IRQ_U_TIMER                  : cause_type := to_cause(4, true);
  constant IRQ_S_TIMER                  : cause_type := to_cause(5, true);
  constant IRQ_VS_TIMER                 : cause_type := to_cause(6, true);
  constant IRQ_M_TIMER                  : cause_type := to_cause(7, true);
  constant IRQ_U_EXTERNAL               : cause_type := to_cause(8, true);
  constant IRQ_S_EXTERNAL               : cause_type := to_cause(9, true);
  constant IRQ_VS_EXTERNAL              : cause_type := to_cause(10, true);
  constant IRQ_M_EXTERNAL               : cause_type := to_cause(11, true);
  constant IRQ_SG_EXTERNAL              : cause_type := to_cause(12, true);
  constant IRQ_LCOF                     : cause_type := to_cause(13, true);

  -- Reset Codes
  constant RST_HARD_ALL                 : cause_type := to_cause(0);
  constant RST_ASYNC                    : cause_type := to_cause(1);


  function to_floating(fpulen : integer; set : integer) return integer is
    -- Non-constant
    variable ret : integer := 0;
  begin
    -- FPU length implies lower ones too.
    if fpulen >= set then
      ret := 1;
    end if;

    return ret;
  end;

  -- Math operation
  -- ctrl_in(3)   -> size
  -- ctrl_in(2)   -> ADD,LOGIC/MINMAX
  -- ctrl_in(1)   -> MINMAX/MINMAXU
  -- ctrl_in(0)   -> MIN/MAX
  function amo_math_op(
    op1_in  : std_logic_vector;
    op2_in  : std_logic_vector;
    ctrl_in : std_logic_vector(3 downto 0)) return std_logic_vector is
    -- Non-constant
    subtype  op_t   is std_logic_vector(op1_in'length downto 0);
    subtype  res_t  is std_logic_vector(op1_in'length - 1 downto 0);
    variable op1     : op_t := ((not ctrl_in(1)) and op1_in(op1_in'left)) & op1_in;
    variable op2     : op_t := ((not ctrl_in(1)) and op2_in(op2_in'left)) & op2_in;
    variable add_res : res_t;
    variable less    : std_ulogic;
    variable pad     : std_logic_vector(31 downto 0);
    variable res     : res_t;
  begin
    -- Compute Results
    add_res   := std_logic_vector(signed(op1_in) + signed(op2_in));
    if signed(op1) < signed(op2) then
      less    := '1';
    else
      less    := '0';
    end if;

    if ctrl_in(2) = '0' then
      case ctrl_in(1 downto 0) is
        when "00" =>
          res := add_res;
        when "01" =>
          res := op1_in xor op2_in;
        when "10" =>
          res := op1_in or op2_in;
        when "11" =>
          res := op1_in and op2_in;
        when others =>
      end case;
    else
      if (less xor ctrl_in(0)) = '1' then
        res   := op1_in;
      else
        res   := op2_in;
      end if;
    end if;

    pad := (others => res(31));
    if ctrl_in(3) = '0' then
      res(res'high downto res'length - pad'length) := pad;
    end if;

    return res;
  end;

  function mmuen_set(mmuen : integer) return integer is
    -- Non-constant
    variable ret : integer := 0;
  begin
    if mmuen > 0 then
      ret := 1;
    end if;

    return ret;
  end;



  function extend_wordx(v : std_logic_vector) return wordx is
     -- Non-constant
    variable result : wordx := (others => v(v'left));
  begin
    result(v'length - 1 downto 0) := v;

    return result;
  end;

  function satp_mask(id : integer; physaddr : integer) return wordx is
    -- Non-constant
    variable id_mask_64   : std_logic_vector(15 downto 0) := (others => '0');
    variable id_mask_32   : std_logic_vector( 8 downto 0) := (others => '0');
    variable addr_mask_64 : std_logic_vector(43 downto 0) := (others => '0');
    variable addr_mask_32 : std_logic_vector(21 downto 0) := (others => '0');
    variable result       : word64 := zerow64;
  begin
    if XLEN = 64 then
      if id /= 0 then
        id_mask_64(id - 1 downto 0)            := (others => '1');
      end if;
      addr_mask_64(physaddr - 1 - 12 downto 0) := (others => '1');
      result                                   := "1111" & id_mask_64 & addr_mask_64;
    else
      if id /= 0 then
        id_mask_32(id - 1 downto 0)            := (others => '1');
      end if;
      addr_mask_32(physaddr - 1 - 12 downto 0) := (others => '1');
      result(word'range)                       := "1" & id_mask_32 & addr_mask_32;
    end if;

    return result(wordx'range);
  end;

  constant RST_VEC          : wordx := extend_wordx(x"00010040");

  
  constant CSR_MEDELEG_MASK : wordx := extend_wordx(x"0000b3ff");
  constant CSR_MIDELEG_MASK : wordx := extend_wordx(x"00000222"); -- Interrupts to be delegated to S-mode
  constant CSR_MIE_MASK     : wordx := extend_wordx(x"00000888"); -- Valid bits
  constant CSR_MIP_MASK     : wordx := extend_wordx(x"00000000"); -- Writable bits

  constant CSR_HEDELEG_MASK : wordx := extend_wordx(x"0000b5ff");
  constant CSR_HIDELEG_MASK : wordx := extend_wordx(x"00000444"); -- Interrupts to be delegated to VS-mode
  constant CSR_HIE_MASK     : wordx := extend_wordx(x"00001444"); -- Valid bits
  constant CSR_HIP_MASK     : wordx := extend_wordx(x"00000004"); -- Writable bits

  constant CSR_SIDELEG_MASK : wordx := extend_wordx(x"00000111"); -- Interrupts to be delegated to U-mode
  constant CSR_SIE_MASK     : wordx := extend_wordx(x"00000222"); -- Valid bits
  constant CSR_SIP_MASK     : wordx := extend_wordx(x"00000222"); -- Writable bits

  constant CSR_UIE_MASK     : wordx := extend_wordx(x"00000111"); -- Valid bits
  constant CSR_UIP_MASK     : wordx := extend_wordx(x"00000001"); -- Writable bits
--  constant CSR_UIP_MASK     : wordx := extend_wordx(x"00000111"); -- Writable bits (maybe extra bit)

  -- These two only occurs together with mtval2/htval!
  function tinst_vs_pt_read return word is
  begin
    if XLEN = 64 then
      return x"00003000";
    end if;

    return x"00002000";
  end;

  function tinst_vs_pt_write return word is
  begin
    if XLEN = 64 then
      return x"00003020";
    end if;

    return x"00002020";
  end;

  -- Return mask for mie
  function medeleg_mask(h_en : boolean) return wordx is
    -- Non-constant
    variable mask    : wordx := CSR_MEDELEG_MASK;
  begin
    if h_en then
      mask(10) := '1';
      mask(20) := '1';
      mask(21) := '1';
      mask(22) := '1';
      mask(23) := '1';
    end if;

    return mask;
  end;

  -- Return masked mideleg value
  function to_mideleg(
    wcsr         : wordx;
    mode_s       : integer;
    h_en         : boolean;
    ext_n        : integer;
    ext_sscofpmf : integer) return wordx is
    -- Non-constant
    variable mideleg : wordx := zerox;
    variable mask    : wordx := zerox;
  begin
    if ext_sscofpmf /= 0 then
      mask(13) := '1';
    end if;
    if mode_s /= 0 then
      mask := mask or CSR_MIDELEG_MASK;
    end if;
    if ext_n /= 0 then
      mask := mask or CSR_SIDELEG_MASK;
    end if;

    mideleg := wcsr and mask;

    -- VS-level interrupts are always delegeted to HS-mode
    if h_en then
      mideleg(12) := '1';
      mideleg(10) := '1';
      mideleg(6)  := '1';
      mideleg(2)  := '1';
    end if;

    return mideleg;
  end;

  -- Return mask for mip
  function mip_mask(mode_s : integer; h_en : boolean;
                    ext_n : integer; ext_sscofpmf : integer) return wordx is
    -- Non-constant
    variable mask : wordx := CSR_MIP_MASK;
  begin
    if ext_sscofpmf /= 0 then
      mask(13) := '1';
    end if;
    if mode_s /= 0 then
      mask := mask or CSR_SIP_MASK;
    end if;
    if ext_n /= 0 then
      mask := mask or CSR_UIP_MASK;
    end if;
    if h_en then
      mask := mask or CSR_HIP_MASK;
    end if;

    return mask;
  end;

  -- Return mask for mie
  function mie_mask(mode_s : integer; h_en : boolean;
                    ext_n : integer;  ext_sscofpmf : integer) return wordx is
    -- Non-constant
    variable mask : wordx := CSR_MIE_MASK;
  begin
    if ext_sscofpmf /= 0 then
      mask(13) := '1';
    end if;
    if mode_s /= 0 then
      mask := mask or CSR_SIE_MASK;
    end if;
    if ext_n /= 0 then
      mask := mask or CSR_UIE_MASK;
    end if;
    if h_en then
      mask := mask or CSR_HIE_MASK;
    end if;

    return mask;
  end;

  -- Return hstatus as a XLEN bit data from the record type
  function to_hstatus(status : csr_hstatus_type) return wordx is
    -- Non-constant
    variable hstatus : word64 := zerow64;
  begin
    hstatus(33 downto 32)     := status.vsxl;
    hstatus(22 downto 20)     := status.vtsr & status.vtw & status.vtvm;
    hstatus(17 downto 12)     := status.vgein;
    hstatus( 9 downto  6)     := status.hu & status.spvp & status.spv & status.gva;
    hstatus(           5)     := status.vsbe;

    return hstatus(wordx'range);
  end;

  -- Return mstatus as a record type from an XLEN bit data
  function to_hstatus(wdata : wordx) return csr_hstatus_type is
    -- Non-constant
    variable hstatus : csr_hstatus_type;
  begin
    hstatus.vsxl  := "10";
    hstatus.vtsr  := wdata(22);
    hstatus.vtw   := wdata(21);
    hstatus.vtvm  := wdata(20);
    --hstatus.vgein := wdata(14 downto 13);
    hstatus.vgein := (others => '0');
    hstatus.hu    := wdata(9);
    hstatus.spvp  := wdata(8);
    hstatus.spv   := wdata(7);
    hstatus.gva   := wdata(6);
    --hstatus.vsbe  := wdata(5);
    hstatus.vsbe  := '0';

    return hstatus;
  end;

  -- Return vsstatus as a XLEN bit data from the record type
  function to_vsstatus(status : csr_status_type) return wordx is
    -- Non-constant
    variable vsstatus : word64 := zerow64;
  begin
    vsstatus(XLEN-1)         := (status.fs(1) and status.fs(0)) or (status.xs(1) and status.xs(0));
    if XLEN = 64 then
      vsstatus(33 downto 32) := status.uxl;
    end if;
    vsstatus(19 downto 18)   := status.mxr & status.sum;
    vsstatus(16 downto 13)   := "00" & status.fs;
    vsstatus(           8)   := status.spp;
    vsstatus(6 downto   5)   := '0' & status.spie;
    vsstatus(           1)   := status.sie;

    return vsstatus(wordx'range);
  end;

  -- Return vsstatus as a record type from an XLEN bit data
  function to_vsstatus(wdata : wordx) return csr_status_type is
    -- Non-constant
    variable vsstatus : csr_status_type;
  begin

    vsstatus.uxl  := "10";
    vsstatus.mxr  := wdata(19);
    vsstatus.sum  := wdata(18);
    vsstatus.xs   := "00";
    vsstatus.fs   := wdata(14 downto 13);
    vsstatus.spp  := wdata(8);
    vsstatus.ube  := '0';
    vsstatus.spie := wdata(5);
    vsstatus.sie  := wdata(1);

    return vsstatus;
  end;

  -- Return mstatus as an XLEN bit data from the record type
  function to_mstatus(status : csr_status_type) return wordx is
    -- Non-constant
    variable mstatus : word64 := zerow64;
  begin
    -- List of Hardwired Fields
    -- * SXL    -> 10 (The SXL field of mstatus determines XLEN for HS-mode)
    -- * UXL    -> 10 (The UXL field of the HS-level sstatus determines XLEN for both VS-mode and U-mode)
    -- * XS     -> 00 (User Extensions Missing)
    -- * MBE    -> 0
    -- * SBE    -> 0
    -- * UBE    -> 0

    mstatus(XLEN-1)         := (status.fs(1) and status.fs(0)) or (status.xs(1) and status.xs(0));
    if XLEN = 64 then
      mstatus(39 downto 38) := status.mpv & status.gva;
      mstatus(35 downto 32) := status.sxl & status.uxl;
    end if;
    mstatus(22 downto 20)   := status.tsr & status.tw & status.tvm;
    mstatus(19 downto 17)   := status.mxr & status.sum & status.mprv;
    mstatus(16 downto 11)   := "00" & status.fs & status.mpp;
    mstatus(8 downto 7)     := status.spp & status.mpie;
    mstatus(5 downto 3)     := status.spie & status.upie  & status.mie;
    mstatus(1 downto 0)     := status.sie & status.uie;

    return mstatus(wordx'range);
  end;

  -- Return mstatus as a record type from an XLEN bit data
  function to_mstatus(wdata : wordx; mstatus_in : csr_status_type) return csr_status_type is
    -- Non-constant
    variable mstatus : csr_status_type := mstatus_in;
  begin

    if XLEN = 64 then
      mstatus.mpv  := wdata(39*(XLEN/64));
      mstatus.gva  := wdata(38*(XLEN/64));
    end if;
    mstatus.mbe  := '0';
    mstatus.sbe  := '0';
    mstatus.sxl  := "10";
    mstatus.uxl  := "10";
    mstatus.tsr  := wdata(22);
    mstatus.tw   := wdata(21);
    mstatus.tvm  := wdata(20);
    mstatus.mxr  := wdata(19);
    mstatus.sum  := wdata(18);
    mstatus.mprv := wdata(17);
    mstatus.xs   := "00";
    mstatus.fs   := wdata(14 downto 13);
    mstatus.mpp  := wdata(12 downto 11);
    mstatus.spp  := wdata(8);
    mstatus.mpie := wdata(7);
    mstatus.ube  := '0';
    mstatus.spie := wdata(5);
    mstatus.upie := wdata(4);
    mstatus.mie  := wdata(3);
    mstatus.sie  := wdata(1);
    mstatus.uie  := wdata(0);

    return mstatus;
  end;

  -- Return mstatush as an XLEN bit data from the record type
  function to_mstatush(status : csr_status_type) return wordx is
    -- Non-constant
    variable mstatus : word64 := zerow64;
  begin
    mstatus(7 downto 6) := status.mpv & status.gva;

    return mstatus(wordx'range);
  end;

  -- Return mstatush as a record type from an XLEN bit data
  function to_mstatush(wdata : wordx; mstatus_in : csr_status_type) return csr_status_type is
    -- Non-constant
    variable mstatus : csr_status_type := mstatus_in;
  begin

    mstatus.mpv  := wdata(7);
    mstatus.gva  := wdata(6);

    return mstatus;
  end;

  -- Return sstatus as an XLEN bit data from the record type
  function to_sstatus(status : csr_status_type) return wordx is
    -- Non-constant
    variable sstatus : word64 := zerow64;
  begin
    sstatus(XLEN-1)         := (status.fs(1) and status.fs(0)) or (status.xs(1) and status.xs(0));
    if XLEN = 64 then
      sstatus(33 downto 32) := status.uxl;
    end if;
    sstatus(19 downto 18)   := status.mxr & status.sum;
    sstatus(16 downto 13)   := "00" & status.fs;
    sstatus(8)              := status.spp;
    sstatus(5 downto 4)     := status.spie & status.upie;
    sstatus(1 downto 0)     := status.sie & status.uie;

    return sstatus(wordx'range);
  end;

  -- Return sstatus as a record type from an XLEN bit data
  function to_sstatus(wdata : wordx; mstatus : csr_status_type) return csr_status_type is
    -- Non-constant
    variable sstatus : csr_status_type;
  begin

    -- Keep the values for the mstatus fields
    sstatus      := mstatus;

    sstatus.uxl  := "10";
    sstatus.mxr  := wdata(19);
    sstatus.sum  := wdata(18);
    sstatus.xs   := "00";
    sstatus.fs   := wdata(14 downto 13);
    sstatus.spp  := wdata(8);
    sstatus.spie := wdata(5);
    sstatus.upie := wdata(4);
    sstatus.sie  := wdata(1);
    sstatus.uie  := wdata(0);

    return sstatus;
  end;

  -- Return ustatus as an XLEN bit data from the record type
  function to_ustatus(status : csr_status_type) return wordx is
    -- Non-constant
    variable ustatus : wordx;
  begin
    ustatus := (others => '0');

    ustatus(4)            := status.upie;
    ustatus(0)            := status.uie;

    return ustatus;
  end;

  -- Return ustatus as a record type from an XLEN bit data
  function to_ustatus(wdata : wordx; mstatus : csr_status_type) return csr_status_type is
    -- Non-constant
    variable ustatus    : csr_status_type;
  begin

    -- Keep the values for the mstatus fields
    ustatus             := mstatus;

    ustatus.upie        := wdata(4);
    ustatus.uie         := wdata(0);

    return ustatus;
  end;
  
  
  function to_capabilityh(fpuconf : std_logic_vector(1 downto 0); cconfig : word64) return word is
    variable data : word := zerow;
  begin
    data := cconfig(cconfig'high downto cconfig'length/2);
    data(13 downto 12) := fpuconf;
    return data;
  end;
  function to_capability(fpuconf : std_logic_vector(1 downto 0); cconfig : word64) return wordx is
    variable data : word64 := zerow64;
  begin
    data := cconfig;
    if XLEN = 64 then
      data(data'high downto data'length/2) := to_capabilityh(fpuconf, cconfig);
    end if;
    return data(wordx'range);
  end;

  -- Return hpmevent as a record type from an XLEN bit data
  function to_hpmevent(wdata : wordx; hpmevent_in : hpmevent_type) return hpmevent_type is
    -- Non-constant
    variable hpmevent : hpmevent_type := hpmevent_in;
  begin
    if XLEN = 64 then
      hpmevent.overflow := wdata(63);
      hpmevent.minh     := wdata(62);
      hpmevent.sinh     := wdata(61);
      hpmevent.uinh     := wdata(60);
      hpmevent.vsinh    := wdata(59);
      hpmevent.vuinh    := wdata(58);
    end if;
    hpmevent.event      := wdata(hpmevent.event'range);

    return hpmevent;
  end;

  -- Return hpmeventh as a record type from an XLEN bit data
  function to_hpmeventh(wdata : wordx; hpmevent_in : hpmevent_type) return hpmevent_type is
    -- Non-constant
    variable hpmevent : hpmevent_type := hpmevent_in;
  begin
    hpmevent.overflow := wdata(63 - 32);
    hpmevent.minh     := wdata(62 - 32);
    hpmevent.sinh     := wdata(61 - 32);
    hpmevent.uinh     := wdata(60 - 32);
    hpmevent.vsinh    := wdata(59 - 32);
    hpmevent.vuinh    := wdata(58 - 32);

    return hpmevent;
  end;

  -- Return hpmevent as an XLEN bit data from the record type
  function to_hpmevent(hpmevent : hpmevent_type) return wordx is
    -- Non-constant
    variable rdata : word64 := zerow64;
  begin
    rdata(63) := hpmevent.overflow;
    rdata(62) := hpmevent.minh;
    rdata(61) := hpmevent.sinh;
    rdata(60) := hpmevent.uinh;
    rdata(59) := hpmevent.vsinh;
    rdata(58) := hpmevent.vuinh;
    rdata(hpmevent.event'range) := hpmevent.event;

    return rdata(wordx'range);
  end;

  -- Return hpmeventh as an XLEN bit data from the record type
  function to_hpmeventh(hpmevent : hpmevent_type) return wordx is
    -- Non-constant
    variable rdata : word64 := zerow64;
  begin
    rdata(63 - 32) := hpmevent.overflow;
    rdata(62 - 32) := hpmevent.minh;
    rdata(61 - 32) := hpmevent.sinh;
    rdata(60 - 32) := hpmevent.uinh;
    rdata(59 - 32) := hpmevent.vsinh;
    rdata(58 - 32) := hpmevent.vuinh;

    return rdata(wordx'range);
  end;


  -- Incoming pmpaddr has at least two zeros at the top.
  procedure pmp_precalc(pmpaddr     : in  pmpaddr_type;
                        pmpaddr_m1  : in  pmpaddr_type;
                        a           : pmpcfg_access_type;
                        precalc     : out pmp_precalc_type;
                        pmp_no_tor  : integer;
                        pmp_g       : integer;
                        msb         : integer := 31
                       ) is
    -- Non-constant
    variable mask  : std_logic_vector(precalc.low'high + 2 downto 0);
    variable valid : std_ulogic := '1';
    variable low   : pmpaddr_type;
    variable high  : pmpaddr_type;
  begin
    -- At startup there may be X's.
    assert is_x(pmpaddr) or get_hi(pmpaddr, 2) = "00"
      report "Bad pmpaddr for precalc"
      severity failure;
    if a = PMP_OFF or (pmp_no_tor = 1 and a = PMP_TOR) then
      valid := '0';
    end if;
    -- Concatenate PMP type for mask creation. It contains a zero for
    -- TOR/NA4 and thus the used mask will then equal the input.
    -- For NAPOT it is 11, and thus the addition will propagate up to
    -- the marker zero. Which will be set and everything below cleared.
    -- and thus will work in the mask calculation.
    mask                         := pmpaddr & a;
    -- Make sure pmp_g aligns the mask properly. Low bits should not matter!
    mask(pmp_g - 2 + 2 downto 2) := (others => '1');
    mask                         := mask + 1;
    -- Keep the bits above the marker zero.
    low                          := pmpaddr and mask(mask'high downto 2);
    if pmp_no_tor = 1 then
      -- No actual TOR support, so provide mask (high bits set) instead.
      high                       := not (pmpaddr xor mask(mask'high downto 2));
      -- Make sure pmp_g clears the mask properly. Low bits should not matter!
      high(pmp_g - 2 downto 0)   := (others => '0');
    else
      if a = PMP_TOR then
        low                      := pmpaddr_m1;
        low(pmp_g - 1 downto 0)  := (others => '0');
        high                     := pmpaddr;
        high(pmp_g - 1 downto 0) := (others => '0');
      else
        -- "Fill in" the zero marker to get the high address.
        high                     := pmpaddr or mask(mask'high downto 2);
        -- Compensate so that we can use the same comparator.
        high                     := high + 1;
        -- Set max address plus 1 if bits of high set above our msb.
        if not all_0(high(high'high downto msb + 1 - 2)) then
          high                   := (others => '0');
          high(msb + 1 - 2)      := '1';
        end if;
      end if;
    end if;

    if valid = '1' then
--      report "Precalc " & tost(pmpaddr) & " " & tost(mask) & " " & tost(low) & " high " & tost(high);
    end if;
    precalc.valid := valid;
    precalc.low   := low;
    precalc.high  := high;
  end;

  procedure pmp_precalc(pmpaddr     : in  pmpaddr_vec_type;
                        pmpcfg0     : in  word64;
                        pmpcfg2     : in  word64;
                        precalc     : out pmp_precalc_vec;
                        pmp_entries : integer;
                        pmp_no_tor  : integer;
                        pmp_g       : integer;
                        msb         : integer := 31
                       ) is
    function pmpcfg(cfg0 : word64; cfg2 : word64; n : integer range 0 to 15) return std_logic_vector is
      -- Non-constant
      variable cfg : word8;
    begin
      if n < 8 then
        cfg := cfg0(n * 8 + 7 downto n * 8);
      else
        cfg := cfg2((n - 8) * 8 + 7 downto (n - 8) * 8);
      end if;

      return cfg;
    end;

    -- Non-constant
    variable a          : pmpcfg_access_type;
    variable pmpaddr_m1 : pmpaddr_type;
  begin
    for i in 0 to pmp_entries - 1 loop
      a := pmpcfg(pmpcfg0, pmpcfg2, i)(4 downto 3);

      -- Bottom address for PMP_TOR.
      pmpaddr_m1   := pmpaddrzero;
      if i /= 0 then
        pmpaddr_m1 := pmpaddr(i - 1);
      end if;

      pmp_precalc(pmpaddr(i), pmpaddr_m1, a,
                  precalc(i), pmp_no_tor, pmp_g, msb);
    end loop;
  end;

  -- Note that this does not support pmp_g = 0!
  procedure pmp_unit(prv_in     : in  std_logic_vector(PRIV_LVL_M'range);
                     precalc    : in  pmp_precalc_vec;
                     pmpcfg0_in : in  word64;
                     pmpcfg2_in : in  word64;
                     mprv_in    : in  std_ulogic;
                     mpp_in     : in  std_logic_vector(PRIV_LVL_M'range);
                     addr_in    : in  std_logic_vector;
                     access_in  : in  std_logic_vector(PMP_ACCESS_X'range);
                     valid_in   : in  std_ulogic;
                     xc_out     : out std_ulogic;
                     entries    : in  integer := 16;
                     no_tor     : in  integer := 1;
                     pmp_g      : in  integer range 1 to 32 := 1;
                     msb        : in  integer := 31
                    ) is
    subtype  pmp_vec_type      is std_logic_vector(entries - 1 downto 0);
    type     pmpcfg_access_vec is array (0 to entries - 1) of pmpcfg_access_type;
    variable zero_entry  : pmp_vec_type       := (others => '0');
    variable lowhi_msb   : integer            := msb - 55 + precalc(0).low'high;
    -- Non-constant
    variable xc          : std_ulogic         := '0';
    variable cfg         : word8;
    variable l           : pmp_vec_type;
    variable a           : pmpcfg_access_vec;
    variable x           : pmp_vec_type;
    variable w           : pmp_vec_type;
    variable r           : pmp_vec_type;
    variable enable      : pmp_vec_type       := (others => '1');
    variable hit         : pmp_vec_type       := (others => '0');
    variable hit_prio    : pmp_vec_type;
    variable fail        : pmp_vec_type       := (others => '0');
    variable prv         : std_logic_vector(1 downto 0);
    variable align       : integer            := pmp_g - 1;
  begin
    prv := prv_in;
    if prv_in = PRIV_LVL_M and mprv_in = '1' and
       access_in /= PMP_ACCESS_X then
      prv := mpp_in;
    end if;


    -- The A field in a PMP entry's configuration register encodes
    -- the address-matching mode of the associated PMP address register.
    -- When A=0, this PMP entry is disabled and matches no addresses.
    -- Two other address-matching modes are supported: naturally aligned
    -- power-of-2 regions (NAPOT), including the special case of naturally
    -- aligned four-byte regions (NA4); and the top boundary of an arbitrary
    -- range (TOR). These modes support four-byte granularity.

    -- Resolve address in pmpaddr CSRs registers and provide memory region
    -- boundaries.

    for i in 0 to entries - 1 loop

      -- Generate larwx signals.
      if i < 8 then
        cfg := pmpcfg0_in(i * 8 + 7 downto i * 8);
      else
        cfg := pmpcfg2_in((i - 8) * 8 + 7 downto (i - 8) * 8);
      end if;
      l(i) := cfg(7);
      a(i) := cfg(4 downto 3);
      x(i) := cfg(2);
      w(i) := cfg(1);
      r(i) := cfg(0);

      enable(i) := precalc(i).valid;

      -- Only fail if not machine mode access, or for locked entries.
      if prv /= PRIV_LVL_M or l(i) = '1' then
        if access_in = PMP_ACCESS_X then
          fail(i) := not x(i);
        elsif access_in = PMP_ACCESS_R then
          fail(i) := not r(i);
        elsif access_in = PMP_ACCESS_W then
          fail(i) := not w(i);
        else  -- Unknown access - cannot happen!
          fail(i) := '1';
        end if;
      end if;

      if no_tor = 1 then
        -- With no TOR, mask is in pmphigh.
        if (('0' & addr_in(msb downto 3 + align)) and precalc(i).high(lowhi_msb downto 1 + align)) =
           precalc(i).low(lowhi_msb downto 1 + align) then
          hit(i) := enable(i);
        end if;
      else
        -- This deals with the requirement to fail on reverse and null ranges,
        -- since it is then impossible to be >= low and < high.
        if unsigned('0' & addr_in(msb downto 3 + align)) >= unsigned(precalc(i).low(lowhi_msb downto 1 + align)) and
           unsigned('0' & addr_in(msb downto 3 + align)) < unsigned(precalc(i).high(lowhi_msb downto 1 + align)) then
          hit(i)  := enable(i);
        end if;
      end if;


    end loop;

    -- Keep only the lowest numbered hit, since that is
    -- defined as the highest priority PMP.
    hit_prio := hit and std_logic_vector(-signed(hit));


    -- If no PMP entry matches an M-mode access, the access succeeds.
    -- If no PMP entry matches an S-mode or U-mode access, but at least
    -- one PMP entry is implemented, the access fails.
    --
    -- If at least one PMP entry is implemented, but all PMP entries'
    -- A fields are set to OFF, then all S-mode and U-mode memory accesses will fail.

    -- Failed at highest priority PMP hit entry?
    if (hit_prio and fail) /= zero_entry then
      xc   := '1';
    end if;
    -- No hit means failure in non-machine mode, if there are implemented entries.
    if prv /= PRIV_LVL_M then
      if hit_prio = zero_entry and entries /= 0 then
        xc := '1';
      end if;
    end if;


    xc_out      := xc and valid_in;
  end;

  -- Specialized for MMU use.
  -- Alignment fixed to 4 kByte.
  procedure pmp_mmuu(precalc_low  : in  std_logic_vector;
                     precalc_high : in  std_logic_vector;
                     addr_low     : in  std_logic_vector;
                     addr_mask    : in  std_logic_vector;
                     hit          : out std_logic;
                     fit          : out std_logic;
                     no_tor       : in  integer := 1
                    ) is
  begin
    hit := '0';
    fit := '0';
    if no_tor = 1 then
      -- With no TOR, mask is in pmphigh.
      -- Area can fit if its mask (page size) is not "larger" than that for the PMP.
      -- PMP area larger or equal?
      if all_0(precalc_high and ('0' & not addr_mask)) then
        fit := '1';
        -- We need to check if MMU start (or, equivalently, end) is inside PMP area.
        if precalc_low = (('0' & addr_low) and precalc_high) then
          hit := '1';
        end if;
      -- MMU area is larger
      else
        -- We need to check if either PMP start (or, equivalently, end) is inside MMU area.
        if ('0' & addr_low) = (precalc_low and ('0' & addr_mask)) then
          hit := '1';
        end if;
      end if;
    else
      -- MMU block vs PMP block
      --   MMU block low >= PMP block low
      if unsigned(addr_low) >= unsigned(precalc_low) then
        -- and MMU block low <= PMP block high
        -- This deals with the requirement to fail on reverse and null ranges,
        -- since it is then impossible to be >= low and < high.
        if unsigned('0' & addr_low) < unsigned(precalc_high) then
          -- MMU block starts inside PMP block, so hit!
          hit := '1';
        end if;
        -- and MMU block high <= PMP block high
        if unsigned('0' & (addr_low or not addr_mask)) < unsigned(precalc_high) then
          -- MMU block lies entirely within PMP block, so fit!
          fit := '1';
        end if;
      else  -- MMU block low < PMP block low
        --     and MMU block high >= PMP block low
        if unsigned(addr_low or not addr_mask) >= unsigned(precalc_low) then
          -- MMU block overlaps at least low part of PMP block, so hit!
          hit := '1';
        end if;
      end if;
    end if;
  end;

  -- Specialized for MMU use.
  -- Alignment fixed to 4 kByte.
  procedure pmp_mmuu(precalc    : in  pmp_precalc_vec;
                     pmpcfg0_in : in  word64;
                     pmpcfg2_in : in  word64;
                     addr_low   : in  std_logic_vector;
                     addr_mask  : in  std_logic_vector;
                     valid      : in  std_ulogic;
                     hit_out    : out std_logic_vector;
                     fit_out    : out std_logic_vector;
                     l_out      : out std_logic_vector;
                     r_out      : out std_logic_vector;
                     w_out      : out std_logic_vector;
                     x_out      : out std_logic_vector;
                     no_tor     : in  integer := 1;
                     msb        : in  integer := 31
                    ) is
    -- pmp_g > 1  hit is really hit<2 ** (pmp_g + 2)>
    variable pmp_g       : integer            := 10;  -- 4 kByte (minimum page size)
    variable align       : integer            := pmp_g - 1;
    -- Non-constant
    subtype  pmp_vec_type      is std_logic_vector(precalc'length - 1 downto 0);
    type     pmpcfg_access_vec is array (precalc'range) of pmpcfg_access_type;
    variable lowhi_msb   : integer            := msb - 55 + precalc(precalc'low).low'high;
    -- Non-constant
    variable cfg         : word8;
    variable l           : pmp_vec_type;
    variable a           : pmpcfg_access_vec;
    variable x           : pmp_vec_type;
    variable w           : pmp_vec_type;
    variable r           : pmp_vec_type;
    variable enable      : pmp_vec_type       := (others => '1');
    variable hit         : pmp_vec_type       := (others => '0');
    variable fit         : pmp_vec_type       := (others => '0');
    variable hit_prio    : pmp_vec_type;
  begin

    -- The A field in a PMP entry's configuration register encodes
    -- the address-matching mode of the associated PMP address register.
    -- When A=0, this PMP entry is disabled and matches no addresses.
    -- Two other address-matching modes are supported: naturally aligned
    -- power-of-2 regions (NAPOT); and the top boundary of an arbitrary range (TOR).

    -- Resolve address in pmpaddr CSRs registers and provide memory region
    -- boundaries.

    for i in precalc'range loop

      -- Generate larwx signals.
      if i < 8 then
        cfg := pmpcfg0_in(i * 8 + 7 downto i * 8);
      else
        cfg := pmpcfg2_in((i - 8) * 8 + 7 downto (i - 8) * 8);
      end if;
      l(i) := cfg(7);
      a(i) := cfg(4 downto 3);
      x(i) := cfg(2);
      w(i) := cfg(1);
      r(i) := cfg(0);

      enable(i) := precalc(i).valid;

      pmp_mmuu(precalc(i).low(lowhi_msb downto 1 + align), precalc(i).high(lowhi_msb downto 1 + align),
               addr_low(msb downto 3 + align), addr_mask(msb downto 3 + align),
               hit(i), fit(i), no_tor);


    end loop;

    hit := hit and enable;

    hit_out            := (hit_out'range => '0');
    hit_out(hit'range) := hit;
    fit_out            := (fit_out'range => '0');
    fit_out(fit'range) := fit;
    l_out              := (l_out'range   => '0');
    l_out(l'range)     := l;
    r_out              := (r_out'range   => '0');
    r_out(r'range)     := r;
    w_out              := (w_out'range   => '0');
    w_out(w'range)     := w;
    x_out              := (x_out'range   => '0');
    x_out(x'range)     := x;

  end;

end package body;
