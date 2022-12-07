------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity:      nvsupport
-- File:        nvsupport.vhd
-- Author:      Johan Klockars, Cobham Gaisler AB
-- Description: NOEL-V type/constants/functions that could be broken out of the pipeline.
--              Not everything here can be synthesized!
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.riscv.all;
use grlib.stdlib.log2;
use grlib.stdlib.tost;
use grlib.stdlib.tost_bits;
use grlib.stdlib.orv;
library gaisler;
use gaisler.noelv.XLEN;
use gaisler.utilnv.to_bit;
use gaisler.utilnv.get;
use gaisler.utilnv.get_hi;
use gaisler.utilnv.b2i;
use gaisler.utilnv.u2i;
use gaisler.utilnv.u2vec;
use gaisler.utilnv.uext;
use gaisler.utilnv.sext;
use gaisler.utilnv.uadd;
use gaisler.utilnv.all_0;
use gaisler.utilnv.all_1;
use gaisler.noelvint.nv_csr_in_type;
use gaisler.noelvint.PMPENTRIES;
use gaisler.noelvint.PMPADDRBITS;
use gaisler.noelvint.MAX_TRIGGER_NUM;
use gaisler.noelvint.PMPPRECALCRES;
use gaisler.noelvint.cause_type;
use gaisler.noelvint.trace_type;
use gaisler.noelvint.trace_rst;
use gaisler.noelvint.pmpaddr_type;
use gaisler.noelvint.pmpaddrzero;
use gaisler.noelvint.pmpaddr_vec_type;
use gaisler.noelvint.pmp_precalc_type;
use gaisler.noelvint.pmp_precalc_vec;
use gaisler.noelvint.csr_out_cctrl_type;
use gaisler.noelvint.csr_out_cctrl_rst;

package nvsupport is

  subtype word64 is std_logic_vector(63 downto 0);
  subtype word16 is std_logic_vector(15 downto 0);
  subtype word8  is std_logic_vector( 7 downto 0);
  subtype word2  is std_logic_vector( 1 downto 0);
  subtype word3  is std_logic_vector( 2 downto 0);
  subtype word   is std_logic_vector(31 downto 0);
  subtype wordx  is std_logic_vector(XLEN - 1 downto 0);
  subtype wordx1 is std_logic_vector(XLEN downto 0);

  constant zerow16 : word16 := (others => '0');
  constant zerow64 : word64 := (others => '0');
  constant zerox   : wordx  := (others => '0');
  constant zerow   : word   := (others => '0');

  type wordx_arr is array (integer range <>) of wordx;

  constant RFBITS     : integer := 5;
  constant FUSELBITS    : integer := 11;

  subtype  rfatype   is std_logic_vector(RFBITS - 1 downto 0);
  subtype  fuseltype is std_logic_vector(FUSELBITS - 1 downto 0);

  type     x_type is (x_first,
                      x_single_issue, x_late_alu, x_late_branch, x_muladd,
                      x_logfilter, x_fpu_debug, x_dtcm, x_itcm,
                      x_rv64, x_mode_u, x_mode_s,
                      x_m, x_f, x_d,
                      x_a, x_c, x_h, x_sscofpmf,
                      x_zba, x_zbb, x_zbc, x_zbs,
                      x_zbkb, x_zbkc, x_zbkx,
                      x_time, x_sstc,
                      x_zicbom,
                      x_last);
  subtype  extension_type is std_logic_vector(x_type'pos(x_first) + 1 to x_type'pos(x_last) - 1);
  constant extension_none  : extension_type := (others => '0');
  constant extension_all   : extension_type := (others => '1');

  function extension(item : x_type) return extension_type;
  function extension(item : x_type; valid : boolean) return extension_type;
  function enable(active : extension_type; item : x_type) return extension_type;
  function disable(active : extension_type; item : x_type) return extension_type;
  function disable(active : extension_type; item1, item2 : x_type) return extension_type;
  function is_enabled(active : extension_type; item : x_type) return boolean;
  function is_enabled(active : extension_type; item : x_type) return integer;

  function rd_gen(inst : word) return std_ulogic;
  function rs1_gen(inst : word) return rfatype;
  function rs2_gen(inst : word) return rfatype;

  function to_reg(num : std_logic_vector) return string;

  type iword_type is record
    lpc : std_logic_vector(1 downto 0);
    d   : word;
    dc  : word16;
    xc  : word3;
    c   : std_ulogic;
  end record;

  constant fetch          : std_logic_vector(0 to 1) := (others => '0');    -- Used as range.
  subtype fetch_pair     is std_logic_vector(fetch'high downto fetch'low);  -- Must be n downto 0!
  type iword_pair_type   is array (fetch'range) of iword_type;

  -- Prediction -----------------------------------------------------------------
  type prediction_type is record
    taken       : std_ulogic;                          -- branch predicted to be taken
--    dir         : std_logic_vector(bhti.wdata'range);  -- bht branch output
    hit         : std_ulogic;                          -- branch has been found in BTB
  end record;

  constant prediction_none : prediction_type := (
    taken       => '0',
--    dir         => (others => '0'),
    hit         => '0'
    );

  type prediction_array_type is array (0 to 3) of prediction_type;

  -- Instruction Queue ------------------------------------------------------
  -- The instruction queue is a single-entry instruction buffer located in the
  -- decode stage.
  type iqueue_type is record
--    pc              : pctype;           -- program counter
    pc              : wordx;            -- program counter
    inst            : iword_type;       -- instruction
    cinst           : word16;           -- compressed instruction
    valid           : std_ulogic;       -- instruction buffer entry is valid
    comp            : std_ulogic;  -- instruction buffer entry is compressed
    xc              : std_ulogic;  -- instruction buffer entry has generated a trap in previous stages
    bjump           : std_ulogic;       -- 1-> branch or jump inst
    bjump_predicted : std_ulogic;       -- 1-> bjump already predicted before buffering
    prediction      : prediction_type;  -- prediction as from the BHT
    comp_ill        : std_ulogic; --compressed instruction is invalid
  end record;

  constant iqueue_none : iqueue_type := (
--qqq    pc              => PC_RESET,
    pc              => zerox,
    inst            => ("00", zerow, (others => '0'), "000", '0'),
    cinst           => zerow16,
    valid           => '0',
    comp            => '0',
    xc              => '0',
    --xc_msb          => '0',
    bjump           => '0',
    bjump_predicted => '0',
    prediction      => prediction_none,
    comp_ill        => '0'
    );

  type lane_select is record
    fpu    : integer range 0 to 1;
    csr    : integer range 0 to 1;
    branch : integer range 0 to 1;
    memory : integer range 0 to 1;
  end record;

  constant HWPERFMONITORS       : integer := 29;

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
    mcontext    : wordx;
    scontext    : wordx;
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
    nostream    : std_ulogic;   -- Do not make use of stream buffer for instruction fetch
    mmu_adfault : std_ulogic;   -- Take page fault on access/modify.
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
    fs_dirty    : std_ulogic;   -- Always mark FPU state as dirty, if FPU is enabled.
    new_irq     : std_ulogic;   -- Use new IRQ implementation.
    dm_trace    : std_ulogic;   -- Force DM only access to trace buffer.
  end record;

  constant csr_dfeaturesen_rst : csr_dfeaturesen_type := (
    tpbuf_en    => '0',
    nostream    => '0',
    mmu_adfault => '0',
    dual_dis    => '0',
    btb_dis     => '0',
    jprd_dis    => '0',
    staticbp    => '0',
    staticdir   => '0',
    ras_dis     => '0',
    lbranch_dis => '0',
    lalu_dis    => '0',
    b2bst_dis   => '0',
    fs_dirty    => '0',
    new_irq     => '0',
    dm_trace    => '0'
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

  type csr_envcfg_type is record
    stce  : std_ulogic;
    pbmte : std_ulogic;
    cbze  : std_ulogic;
    cbcfe : std_ulogic;
    cbie  : std_logic_vector(1 downto 0);
    fiom  : std_ulogic;
  end record;
  constant csr_envcfg_rst : csr_envcfg_type := (
    stce  => '0',
    pbmte => '0',
    cbze  => '0',
    cbcfe => '0',
    cbie  => (others => '0'),
    fiom  => '0');

 type csr_reg_type is record
    -- Machine ISA (needs to be configured before use!)
    misa        : wordx;
    -- Privileged Level (not addressable as a CSR register)
    prv         : std_logic_vector(1 downto 0);
    -- Virtualization mode
    v           : std_ulogic;
    -- User Floating-Point CSRs
    fctrl       : std_logic_vector(16 downto 8);  -- qqq Non-standard!
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
    henvcfg     : csr_envcfg_type;
    -- Virtual Supervisor
    vsstatus    : csr_status_type;
    vstvec      : wordx;
    vsscratch   : wordx;
    vsepc       : wordx;
    vscause     : wordx;
    vstval      : wordx;
    vstimecmp   : word64;
    vsatp       : wordx;
    -- Supervisor Trap Setup
    stvec       : wordx;
    scounteren  : word;
    senvcfg     : csr_envcfg_type;
    -- Supervisor Trap Handling
    sscratch    : wordx;
    sepc        : wordx;
    scause      : wordx;
    stval       : wordx;
    stimecmp    : word64;
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
    menvcfg     : csr_envcfg_type;
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
    mcountinhibit : word;
    -- Custom Read/Write Unprivileged Registers
    trace       : trace_type;
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
    henvcfg     => csr_envcfg_rst,
    vsstatus    => csr_status_rst,
    vstvec      => zerox,
    vsscratch   => zerox,
    vsepc       => zerox,
    vscause     => zerox,
    vstval      => zerox,
    vstimecmp   => zerow64,
    vsatp       => zerox,
    stvec       => zerox,
    scounteren  => zerow,
    senvcfg     => csr_envcfg_rst,
    sscratch    => zerox,
    sepc        => zerox,
    scause      => zerox,
    stval       => zerox,
    stimecmp    => zerow64,
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
    menvcfg     => csr_envcfg_rst,
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
    mcountinhibit => zerow,
    cctrl       => csr_out_cctrl_rst,
    trace       => trace_rst,
    dfeaturesen => csr_dfeaturesen_rst
    );

  -- A set bit marks that the corresponding extention etc can be disabled.
  -- Note that each such bit added will need code changes to actually be useful.
  -- Current things that can be disabled:
  constant c_ctrl      : integer := 2;   -- Compressed instructions extension (C)
  constant h_ctrl      : integer := 7;   -- Hypervisor extension (H)
  constant x_ctrl      : integer := 23;  -- Non-standard extensions (X)
  constant ISA_CONTROL : wordx   := (
    h_ctrl => '1',
    x_ctrl => '1',
    others => '0'
  );

  -- xENVCFG bits
  constant envcfg_sstc : integer := 63; 

  -- Load types
  constant SZBYTE       : word2 := "00";
  constant SZHALF       : word2 := "01";
  constant SZWORD       : word2 := "10";
  constant SZDBL        : word2 := "11";

  -- Functional Units Encoding: one-hot encoding for easier decode.
  constant NONE         : fuseltype := "00000000000";
  constant SOMETHING    : fuseltype := "11111111111";  -- !None
  constant ALU          : fuseltype := "00000000001";  -- ALU
  constant BRANCH       : fuseltype := "00000000010";  -- Branch Unit
  constant JAL          : fuseltype := "00000000100";  -- JAL
  constant JALR         : fuseltype := "00000001000";  -- JALR
  constant FLOW         : fuseltype := "00000001100";  -- Jump (JAL/JALR)
  constant MUL          : fuseltype := "00000010000";  -- Mul/Div
  constant LD           : fuseltype := "00000100000";  -- Load
  constant ST           : fuseltype := "00001000000";  -- Store
  constant AMO          : fuseltype := "00010000000";  -- Atomics
  constant FPU          : fuseltype := "00100000000";  -- From FPU
  constant ALU_SPECIAL  : fuseltype := "01000000000";  -- Only for early ALU in lane 0!
  constant DIAG         : fuseltype := "10000000000";  -- Diagnostic cache load/store
  constant NOT_LATE     : fuseltype := "11111111100";  -- All except ALU and Branch Unit

  -- CSR Operation
  constant CSR_BYPASS   : word2 := "00";
  constant CSR_CLEAR    : word2 := "10";
  constant CSR_SET      : word2 := "11";

  -- Core State ---------------------------------------------------------------
  type core_state is (run, dhalt, dexec);

  function to64(v : std_logic_vector) return word64;
  function to0x(v : std_logic_vector) return wordx;
  function to0x(v : unsigned) return wordx;

  procedure rvc_aligner(active           : in  extension_type;
                        inst_in          : in  iword_pair_type;
                        rvc_pc           : in  std_logic_vector;
                        valid_in         : in  std_ulogic;
                        fpu_en           : in  boolean;
                        inst_out         : out iword_pair_type;
                        comp_ill         : out std_logic_vector(1 downto 0);
                        hold_out         : out std_ulogic;
                        npc_out          : out std_logic_vector;
                        valid_out        : out std_logic_vector;
                        buffer_first_out : out std_logic;  -- buffer first instruction
                        buffer_sec_out   : out std_logic;  -- buffer second instruction
                                                           --  if not issued
                        buffer_third_out : out std_logic;  -- buffer the third instruction
                        buffer_inst      : out iword_type;
                        buff_comp_ill    : out std_logic;
                        unaligned_out    : out std_ulogic);

  procedure rvc_expander(active   : in  extension_type;
                         inst_in  : in  word16;
                         fpu_en   : in  boolean;
                         inst_out : out word;
                         xc_out   : out std_ulogic);

  procedure bjump_gen(active        : in  extension_type;
                      inst_in       : in  iword_pair_type;
                      buffer_in     : in  iqueue_type;
                      prediction    : in  prediction_array_type;
                      dvalid        : in  std_ulogic;
                      dpc_in        : in  std_logic_vector;
                      bjump_buf_out : out std_ulogic;  --bjump is from the buffer
                      bjump_out     : out std_ulogic;  --bjump is taken
                      btb_taken     : out std_ulogic;  --btb was taken
                      btb_taken_buf : out std_ulogic;  --btb was taken for buffer
                      bjump_pos     : out std_logic_vector(3 downto 0);
                      bjump_addr    : out std_logic_vector);   --bjump addr

  procedure buffer_ic(active         : in  extension_type;
                      r_d_buff_valid : in  std_ulogic;
                      valid_in       : in  std_logic_vector;
                      dvalid_in      : in  std_logic_vector;
                      buffer_third   : in  std_ulogic;
                      buffer_sec     : in  std_ulogic;
                      buffer_first   : in  std_ulogic;
                      unaligned      : in  std_ulogic;
                      issue_in       : in  std_logic_vector;
                      hold_pc        : out std_ulogic;
                      buff_valid     : out std_ulogic);

  procedure imm_gen(inst_in   : in  word;
                    valid_out : out std_ulogic;
                    imm_out   : out wordx;
                    bj_imm    : out wordx);

  function csr_category(addr : csratype) return std_logic_vector;

  procedure exception_check(active    : in  extension_type;
                            envcfg    : in  csr_envcfg_type;
                            fpu_en    : in  boolean;
                            alu_ok    : in  boolean;
                            tval_ill0 : in  boolean;
                            inst_in   : in  word;
                            cinst_in  : in  word16;
                            pc_in     : in  std_logic_vector;
                            comp_ill  : in  std_ulogic;
                            misa_in   : in  wordx;
                            prv_in    : in  priv_lvl_type;
                            v_in      : in  std_ulogic;
                            tsr_in    : in  std_ulogic;
                            tw_in     : in  std_ulogic;
                            tvm_in    : in  std_ulogic;
                            vtsr_in   : in  std_ulogic;
                            vtw_in    : in  std_ulogic;
                            vtvm_in   : in  std_ulogic;
                            hu        : in  std_ulogic;
                            xc_out    : out std_ulogic;
                            cause_out : out cause_type;
                            tval_out  : out wordx);

  function for_lane0(active : extension_type; lane : lane_select;
                     inst   : word) return boolean;
  function for_lane1(lane : lane_select;
                     inst   : word) return boolean;

  procedure dual_issue_check(active      : in  extension_type;
                             lane        : in  lane_select;
                             instx_in    : in  iword_pair_type;
                             valid_in    : in  std_logic_vector;
                             lbranch_dis : in  std_ulogic;
                             lalu_dis    : in  std_ulogic;
                             dual_dis    : in  std_ulogic;
                             step_in     : in  std_ulogic;
                             lalu_in     : in  std_logic_vector;
                             mexc        : in  std_ulogic;
                             rd0_in      : in  rfatype;
                             rdv0_in     : in  std_ulogic;
                             rd1_in      : in  rfatype;
                             rdv1_in     : in  std_ulogic;
                             lane0_out   : out std_ulogic;
                             issue_out   : out std_logic_vector);

  procedure dual_issue_swap(active   : in  extension_type;
                            lane     : in  lane_select;
                            inst_in  : in  iword_pair_type;
                            valid_in : in  std_logic_vector;
                            swap_out : out std_ulogic);

  function fusel_gen(active : extension_type;
                     inst   : word) return fuseltype;

  function v_fusel_eq(fusel1 : fuseltype; fusel2 : fuseltype) return boolean;

  function csr_addr(inst : word) return csratype;
  function csr_read_only(inst : std_logic_vector) return boolean;
  function csr_write_only(inst : std_logic_vector) return boolean;

  function is_sfence_vma(inst : std_logic_vector) return boolean;
  function is_hfence_vvma(inst : std_logic_vector) return boolean;
  function is_hfence_gvma(inst : std_logic_vector) return boolean;
  function is_hlv(inst : std_logic_vector) return boolean;
  function is_hsv(inst : std_logic_vector) return boolean;
  function is_hlsv(inst : std_logic_vector) return std_logic;
  function is_fence_i(inst : std_logic_vector) return boolean;
  function is_diag(inst : std_logic_vector) return boolean;
  function is_diag_store(inst : std_logic_vector) return boolean;
  function is_csr(inst : std_logic_vector) return boolean;
  function is_cbo(inst : std_logic_vector) return boolean;

  function is_fpu(inst : word) return boolean;
  function is_fpu_mem(inst : word) return boolean;
  function is_fpu_fsd(inst : word) return boolean;
  function is_fpu_from_int(inst : word) return boolean;
  function is_fpu_rd(inst : word) return boolean;
  function is_fpu_modify(inst : word) return boolean;

  function data_addr_misaligned(addr : std_logic_vector;
                                size : word2) return boolean;
  function inst_addr_misaligned(active : extension_type;
                                pc     : std_logic_vector) return boolean;

  function pmpcfg(pmp_entries : integer range 0 to 16;
                  csr : csr_reg_type; n : natural) return word8;
  function pc_valid(inst : word) return std_ulogic;

--  procedure csr_read(active      : in  extension_type; TRIGGER : integer;
--                     perf_cnts   : in  integer range 0 to 29;
--                     counter_ok  : in  word;
--                     hart        : in  std_logic_vector;
--                     fpuconf     : in  integer range 0 to 1;
--                     pmp_entries : in  integer range 0 to 16;
--                     pmp_g       : in  integer range 0 to 10;
--                     pmp_msb     : in  integer range 15 to 63;
--                     csr_file    : in  csr_reg_type;
--                     csra_in     : in  csratype;
--                     csrv_in     : in  std_ulogic;
--                     rstate_in   : in  core_state;
--                     iu_fflags   : in  std_logic_vector;
--                     mmu_csr     : in  nv_csr_in_type;
--                     data_out    : out wordx;
--                     xc_out      : out std_ulogic;
--                     cause_out   : out cause_type);

  procedure branch_unit(active    : in  extension_type;
                        op1_in    : in  wordx;
                        op2_in    : in  wordx;
                        valid_in  : in  std_ulogic;
                        branch_in : in  std_ulogic;
                        ctrl_in   : in  word3;
                        addr_in   : in  std_logic_vector;
                        npc_in    : in  std_logic_vector;
                        taken_in  : in  std_ulogic;
                        pc_in     : in  std_logic_vector;
                        valid_out : out std_ulogic;
                        mis_out   : out std_ulogic;
                        addr_out  : out std_logic_vector;
                        xc_out    : out std_ulogic;
                        cause_out : out cause_type;
                        tval_out  : out wordx);

  function csralu_gen(inst : word) return word2;
  function csralu_op(op1  : wordx;
                     op2  : wordx;
                     ctrl : word2) return wordx;

  procedure addr_gen(active    : in  extension_type;
                     inst_in   : in  word;
                     fusel_in  : in  fuseltype;
                     valid_in  : in  std_ulogic;
                     op1_in    : in  wordx;
                     op2_in    : in  wordx;
                     address   : out wordx;
                     xc_out    : out std_ulogic;
                     cause_out : out cause_type;
                     tval_out  : out wordx);
  function ld_align64(data   : word64;
                      size   : word2;
                      laddr  : word3;
                      signed : std_ulogic) return word64;

--  function csr_write_xc(active : extension_type; TRIGGER : integer;
--                        csra   : csratype;
--                        rstate : core_state;
--                        csr    : csr_reg_type) return std_logic;
--  function csr_read_addr_xc(active : extension_type; TRIGGER : integer;
--                            csra   : csratype;
--                            misa   : wordx) return std_logic;

  -- Exception Codes

  function cause2int(cause : cause_type) return integer;

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
--  constant IRQ_U_SOFTWARE               : cause_type;
  constant IRQ_S_SOFTWARE               : cause_type;
  constant IRQ_VS_SOFTWARE              : cause_type;
  constant IRQ_M_SOFTWARE               : cause_type;
--  constant IRQ_U_TIMER                  : cause_type;
  constant IRQ_S_TIMER                  : cause_type;
  constant IRQ_VS_TIMER                 : cause_type;
  constant IRQ_M_TIMER                  : cause_type;
--  constant IRQ_U_EXTERNAL               : cause_type;
  constant IRQ_S_EXTERNAL               : cause_type;
  constant IRQ_VS_EXTERNAL              : cause_type;
  constant IRQ_M_EXTERNAL               : cause_type;
  constant IRQ_SG_EXTERNAL              : cause_type;
  constant IRQ_LCOF                     : cause_type;

  -- Reset Codes
  constant RST_HARD_ALL                 : cause_type;
  constant RST_ASYNC                    : cause_type;

  -- Interrupt code priority
  type     cause_arr is array (integer range <>) of cause_type;
  constant cause_prio                   : cause_arr(0 to 15);

  constant CSR_VENDORID                 : wordx := zerox(zerox'high downto 12) & x"324"; -- Gaisler JEDEC ID (0xA4, bank 7)
  constant CSR_ARCHID                   : wordx := (others => '0');
  constant CSR_IMPID                    : wordx := (others => '0');
  constant RST_VEC                      : wordx;
  constant CSR_MEDELEG_MASK             : wordx;
  constant CSR_MIDELEG_MASK             : wordx;
  constant CSR_MIE_MASK                 : wordx;
  constant CSR_MIP_MASK                 : wordx;
  constant CSR_SIE_MASK                 : wordx;
  constant CSR_SIP_MASK                 : wordx;
  constant CSR_HEDELEG_MASK             : wordx;
  constant CSR_HIDELEG_MASK             : wordx;
  constant CSR_HIE_MASK                 : wordx;
  constant CSR_HIP_MASK                 : wordx;

  constant CSR_IRQ_RSV_MASK             : wordx;

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

  subtype pmpcfg_access_type is std_logic_vector(1 downto 0);

  function cause_bit(bits : std_logic_vector; cause : cause_type) return std_logic;
  function is_irq(cause : cause_type) return boolean;
  function cause2wordx(cause : cause_type) return wordx;
  function cause2vec(cause : cause_type; vec_in : std_logic_vector) return std_logic_vector;

  function to_floating(fpulen : integer;  set : integer) return integer;

  -- Definitions for CCTRLNV

  type lru_bits_type is array(1 to 4) of integer;
  constant lru_table : lru_bits_type          := (1, 1, 3, 5);

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

  function extend_wordx(v : std_logic_vector) return wordx;
  function satp_mask(id : integer; physaddr : integer) return wordx;
  function medeleg_mask(h_en : boolean) return wordx;
  function to_mideleg(
    wcsr         : wordx;
    mode_s       : integer;
    h_en         : boolean;
    ext_sscofpmf : integer) return wordx;
  function mip_mask(mode_s : integer; h_en : boolean;
                    ext_sscofpmf : integer;
                    menvcfg_stce : std_ulogic) return wordx;
  function mie_mask(mode_s : integer; h_en : boolean;
                    ext_sscofpmf : integer) return wordx;

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

  function to_envcfg(envcfg : csr_envcfg_type) return wordx;
  function to_envcfg(envcfg : csr_envcfg_type; mask : csr_envcfg_type) return wordx;
  function to_envcfg(wdata  : wordx;
                     envcfg : csr_envcfg_type;
                     mask   : csr_envcfg_type) return csr_envcfg_type;
  function to_envcfgh(envcfg : csr_envcfg_type) return wordx;
  function to_envcfgh(envcfg : csr_envcfg_type; mask : csr_envcfg_type) return wordx;
  function to_envcfgh(wdata   : wordx;
                      envcfg  : csr_envcfg_type;
                      mask    : csr_envcfg_type) return csr_envcfg_type;
  function envcfg_mask(envcfg : csr_envcfg_type; mask : csr_envcfg_type) return csr_envcfg_type;
  function gen_envcfg_mmask(active : extension_type) return csr_envcfg_type;
  function gen_envcfg_smask(active : extension_type) return csr_envcfg_type;



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



  function amo_math_op(
    op1_in  : std_logic_vector;
    op2_in  : std_logic_vector;
    ctrl_in : std_logic_vector(3 downto 0)) return std_logic_vector;

  function mmuen_set(mmuen : integer) return integer;

end;

package body nvsupport is

  function extension(item : x_type) return extension_type is
    -- Non-constant
    variable v : extension_type := extension_none;
  begin
    v(x_type'pos(item)) := '1';

    return v;
  end;

  function extension(item : x_type; valid : boolean) return extension_type is
  begin
    if not valid then
      return extension_none;
    end if;

    return extension(item);
  end;

  function enable(active : extension_type; item : x_type) return extension_type is
  begin
    return active or extension(item);
  end;
    
  function disable(active : extension_type; item : x_type) return extension_type is
  begin
    return active and not extension(item);
  end;
    
  function disable(active : extension_type; item1, item2 : x_type) return extension_type is
  begin
    return active and not (extension(item1) or extension(item2));
  end;
    
  function is_enabled(active : extension_type; item : x_type) return boolean is
  begin
    return active(x_type'pos(item)) = '1';  --jk not all_0(active and extension(item));
  end;

  function is_enabled(active : extension_type; item : x_type) return integer is
  begin
    return b2i(is_enabled(active, item));
  end;

  function to_cause(code : integer; irq : boolean := false) return cause_type is
    -- Non-constant
  variable v : cause_type := u2vec(code, cause_type'length);
  begin
    if irq then
      v(v'high) := '1';
    end if;

    return v;
  end;

  function int2mask(n : integer range 0 to 31) return wordx is
    -- Non-constant
    variable v : wordx := zerox;
  begin
    v(n) := '1';

    return v;
  end;

  function cause2mask(cause : cause_type) return wordx is
    variable n : integer range 0 to 31 := u2i(cause(cause'high - 1 downto 0));
  begin
    return int2mask(n);
  end;

  function cause2int(cause : cause_type) return integer is
    variable n : integer range 0 to 31 := u2i(cause(cause'high - 1 downto 0));
  begin
    return n;
  end;

  function extend_wordx(v : std_logic_vector) return wordx is
     -- Non-constant
    variable result : wordx := (others => v(v'left));
  begin
    result(v'length - 1 downto 0) := v;

    return result;
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
--  constant IRQ_U_SOFTWARE               : cause_type := to_cause(0, true);
  constant IRQ_S_SOFTWARE               : cause_type := to_cause(1, true);
  constant IRQ_VS_SOFTWARE              : cause_type := to_cause(2, true);
  constant IRQ_M_SOFTWARE               : cause_type := to_cause(3, true);
--  constant IRQ_U_TIMER                  : cause_type := to_cause(4, true);
  constant IRQ_S_TIMER                  : cause_type := to_cause(5, true);
  constant IRQ_VS_TIMER                 : cause_type := to_cause(6, true);
  constant IRQ_M_TIMER                  : cause_type := to_cause(7, true);
--  constant IRQ_U_EXTERNAL               : cause_type := to_cause(8, true);
  constant IRQ_S_EXTERNAL               : cause_type := to_cause(9, true);
  constant IRQ_VS_EXTERNAL              : cause_type := to_cause(10, true);
  constant IRQ_M_EXTERNAL               : cause_type := to_cause(11, true);
  constant IRQ_SG_EXTERNAL              : cause_type := to_cause(12, true);
  constant IRQ_LCOF                     : cause_type := to_cause(13, true);
  constant IRQ_UNUSED                   : cause_type := to_cause(31, true);

  -- Reset Codes
  constant RST_HARD_ALL                 : cause_type := to_cause(0);
  constant RST_ASYNC                    : cause_type := to_cause(1);

  -- Interrupts
  constant I_none : wordx := zerox;                        -- No bits set
  constant I_SS   : wordx := cause2mask(IRQ_S_SOFTWARE);   -- 
  constant I_VSS  : wordx := cause2mask(IRQ_VS_SOFTWARE);  -- H
  constant I_MS   : wordx := cause2mask(IRQ_M_SOFTWARE);   -- External register only
  constant I_ST   : wordx := cause2mask(IRQ_S_TIMER);      -- 
  constant I_VST  : wordx := cause2mask(IRQ_VS_TIMER);     -- H
  constant I_MT   : wordx := cause2mask(IRQ_M_TIMER);      -- mtimecmp only
  constant I_SE   : wordx := cause2mask(IRQ_S_EXTERNAL);   -- 
  constant I_VSE  : wordx := cause2mask(IRQ_VS_EXTERNAL);  -- H
  constant I_ME   : wordx := cause2mask(IRQ_M_EXTERNAL);   -- external interrupt only
  constant I_SGE  : wordx := cause2mask(IRQ_SG_EXTERNAL);  -- H
  constant I_LCOF : wordx := cause2mask(IRQ_LCOF);         -- Sscofpmf
  constant I_RSV0 : wordx := int2mask(0);                  -- Reserved - formerly N extension
  constant I_RSV4 : wordx := int2mask(4);                  -- Reserved - formerly N extension
  constant I_RSV8 : wordx := int2mask(8);                  -- Reserved - formerly N extension
  constant I_RSVE : wordx := int2mask(14);                 -- Reserved
  constant I_RSVF : wordx := int2mask(15);                 -- Reserved

  constant CSR_MIE_MASK     : wordx := I_MS or I_MT or I_ME;              -- Valid
  constant CSR_MIP_MASK     : wordx := I_none;                            -- Writable

  constant CSR_HIDELEG_MASK : wordx := I_VSS or I_VST or I_VSE;           -- Delegate to VS
  constant CSR_HIE_MASK     : wordx := I_VSS or I_VST or I_VSE or I_SGE;  -- Valid
  constant CSR_HIP_MASK     : wordx := I_VSS;                             -- Writable

  constant CSR_MIDELEG_MASK : wordx := I_SS or I_ST or I_SE;              -- Delegate to S
  constant CSR_SIE_MASK     : wordx := I_SS or I_ST or I_SE;              -- Valid
  constant CSR_SIP_MASK     : wordx := I_SS or I_ST or I_SE;              -- Writable


  constant CSR_IRQ_RSV_MASK : wordx := I_RSV0 or I_RSV4 or I_RSV8 or I_RSVE or I_RSVF;

  constant RST_VEC          : wordx := extend_wordx(x"00010040");

  constant CSR_MEDELEG_MASK : wordx := extend_wordx(x"0000b3ff");
  constant CSR_HEDELEG_MASK : wordx := extend_wordx(x"0000b5ff");


  -- Return GPR name from register number (e.g. x1 -> ra).
  function to_reg(num : std_logic_vector) return string is
    constant n : integer := u2i(num);
  begin
    -- pragma translate_off
    case n is
    when 0 => return "zero";
    when 1 => return "ra";
    when 2 => return "sp";
    when 3 => return "gp";
    when 4 => return "tp";
    when 5 | 6 | 7 =>
              return "t" & tost(n - 5);
    when 8 => return "fp";  -- s0
    when 9 => return "s1";
    when 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 =>
              return "a" & tost(n - 10);
    when 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 =>
              return "s" & tost(n - 18 + 2);
    when 28 | 29 | 30 | 31 =>
              return "t" & tost(n - 28 + 3);
    when others =>
              return "error";
    end case;
    -- pragma translate_on
    return "";
  end;

  -- Defined as in MISA
  constant rv : std_logic_vector(1 downto 0) := u2vec(log2(XLEN / 32) + 1, 2);

  function is_rv(len : integer; rv : std_logic_vector(1 downto 0)) return boolean is
  begin
    if len /= 32 and len /= 64 and len /= 128 then
      assert false report "Bad XLEN (len)" severity failure;
    end if;

    case rv is
      when "01"   => return len = 32;
      when "10"   => return len = 64;
      when "11"   => return len = 128;
      when others => assert false report "Bad XLEN (rv)" severity failure;
    end case;

    return false;
  end;

  function is_rv32 return boolean is
  begin
    return is_rv(32, rv);
  end;

  function is_rv64 return boolean is
  begin
    return is_rv(64, rv);
  end;

  -- Sign extend to 64 bit word.
  function to64(v : std_logic_vector) return word64 is
  begin
    return sext(v, 64);
  end;

  -- Zero extend to wordx.
  function to0x(v : std_logic_vector) return wordx is
  begin
    return uext(v, XLEN);
  end;

  function to0x(v : unsigned) return wordx is
  begin
    return uext(v, XLEN);
  end;

  -- Branch and jump generation
  procedure bjump_gen(active        : in  extension_type;
                      inst_in       : in  iword_pair_type;
                      buffer_in     : in  iqueue_type;
                      prediction    : in  prediction_array_type;
                      dvalid        : in  std_ulogic;
                      dpc_in        : in  std_logic_vector;
                      bjump_buf_out : out std_ulogic;  --bjump is from the buffer
                      bjump_out     : out std_ulogic;  --bjump is taken
                      btb_taken     : out std_ulogic;  --btb was taken
                      btb_taken_buf : out std_ulogic;  --btb was taken for buffer
                      bjump_pos     : out std_logic_vector(3 downto 0);
                      bjump_addr    : out std_logic_vector) is   --bjump addr
    subtype  pctype         is std_logic_vector(dpc_in'range);
    constant high_part       : std_logic_vector(pctype'high downto 12) := (others => '0');
    variable single_issue    : integer := is_enabled(active, x_single_issue);
    -- Non-constant
    variable pc              : std_logic_vector(high_part'range);
    variable inst_word       : std_logic_vector(63 downto 0);
    variable br_imm0         : wordx;   --buffer immediate
    variable br_imm1         : wordx;   --cinst[15:0]
    variable br_imm2         : wordx;   --cinst[31:16]
    variable br_imm3         : wordx;   --cinst[47:32]
    variable br_imm4         : wordx;   --cinst[63:48]
    variable br_imm5         : wordx;   --inst[31:0]
    variable br_imm6         : wordx;   --inst[47 downto 16]
    variable br_imm7         : wordx;   --inst[63 downto 32]
    variable j_imm0          : wordx;   --buffer immediate
    variable j_imm1          : wordx;   --cinst[15:0]
    variable j_imm2          : wordx;   --cinst[31:16]
    variable j_imm3          : wordx;   --cinst[47:32]
    variable j_imm4          : wordx;   --cinst[63:48]
    variable j_imm5          : wordx;   --inst[31:0]
    variable j_imm6          : wordx;   --inst[47 downto 16]
    variable j_imm7          : wordx;   --inst[63 downto 32]
    variable mux_imm0        : wordx;
    variable mux_imm1        : wordx;
    variable mux_imm2        : wordx;
    variable mux_imm3        : wordx;
    variable mux_imm4        : wordx;
    variable mux_imm5        : wordx;
    variable mux_imm6        : wordx;
    variable mux_imm7        : wordx;
    variable mux_immf        : wordx;
    variable br_imm          : wordx_arr(0 to 7);
    variable j_imm           : wordx_arr(0 to 7);
    variable mux_imm         : wordx_arr(0 to 7);
    variable addlsb0         : std_logic_vector(12 downto 0);
    variable addlsb1         : std_logic_vector(12 downto 0);
    variable addlsb2         : std_logic_vector(12 downto 0);
    variable addlsb3         : std_logic_vector(12 downto 0);
    variable addlsb4         : std_logic_vector(12 downto 0);
    variable addlsb5         : std_logic_vector(12 downto 0);
    variable addlsb6         : std_logic_vector(12 downto 0);
    variable addlsb7         : std_logic_vector(12 downto 0);
    variable addlsbf         : std_logic_vector(12 downto 0);
    variable addlsb0_op1     : std_logic_vector(12 downto 0);
    variable addlsb0_op2     : std_logic_vector(12 downto 0);
    variable addlsb1_op1     : std_logic_vector(12 downto 0);
    variable addlsb1_op2     : std_logic_vector(12 downto 0);
    variable addlsb2_op1     : std_logic_vector(12 downto 0);
    variable addlsb2_op2     : std_logic_vector(12 downto 0);
    variable addlsb3_op1     : std_logic_vector(12 downto 0);
    variable addlsb3_op2     : std_logic_vector(12 downto 0);
    variable addlsb4_op1     : std_logic_vector(12 downto 0);
    variable addlsb4_op2     : std_logic_vector(12 downto 0);
    variable addlsb5_op1     : std_logic_vector(12 downto 0);
    variable addlsb5_op2     : std_logic_vector(12 downto 0);
    variable addlsb6_op1     : std_logic_vector(12 downto 0);
    variable addlsb6_op2     : std_logic_vector(12 downto 0);
    variable addlsb7_op1     : std_logic_vector(12 downto 0);
    variable addlsb7_op2     : std_logic_vector(12 downto 0);
    variable bjump0          : std_logic;
    variable bjump1          : std_logic;
    variable bjump2          : std_logic;
    variable bjump3          : std_logic;
    variable bjump4          : std_logic;
    variable bjump5          : std_logic;
    variable bjump6          : std_logic;
    variable bjump7          : std_logic;
    variable jump0           : std_logic;
    variable jump1           : std_logic;
    variable jump2           : std_logic;
    variable jump3           : std_logic;
    variable jump4           : std_logic;
    variable jump5           : std_logic;
    variable jump6           : std_logic;
    variable jump7           : std_logic;
    variable bj_taken        : std_logic;
    variable addrmsbt        : std_logic_vector(pctype'high downto 11);
    variable btb_hit         : std_logic_vector(3 downto 0);
    variable btaken          : std_logic_vector(3 downto 0);
    variable bjump_buf_out_v : std_logic;
    variable dpc_in_t        : std_logic_vector(2 downto 0);

  begin

    for i in 0 to 3 loop
      btb_hit(i) := prediction(i).hit;
      btaken(i)  := prediction(i).taken;
    end loop;
    bjump_pos     := (others => '0');
    btb_taken     := '0';
    btb_taken_buf := '0';

    inst_word := inst_in(1).d & inst_in(0).d;

    br_imm0              := (others => buffer_in.inst.d(31));
    br_imm0(11 downto 0) := buffer_in.inst.d(7) & buffer_in.inst.d(30 downto 25) & buffer_in.inst.d(11 downto 8) & '0';
    br_imm1              := (others => inst_word(12));
    br_imm1(7 downto 0)  := inst_word( 6 downto  5) & inst_word( 2) & inst_word(11 downto 10) & inst_word( 4 downto  3) & '0';
    br_imm2              := (others => inst_word(28));
    br_imm2(7 downto 0)  := inst_word(22 downto 21) & inst_word(18) & inst_word(27 downto 26) & inst_word(20 downto 19) & '0';
    br_imm3              := (others => inst_word(44));
    br_imm3(7 downto 0)  := inst_word(38 downto 37) & inst_word(34) & inst_word(43 downto 42) & inst_word(36 downto 35) & '0';
    br_imm4              := (others => inst_word(60));
    br_imm4(7 downto 0)  := inst_word(54 downto 53) & inst_word(50) & inst_word(59 downto 58) & inst_word(52 downto 51) & '0';
    br_imm5              := (others => inst_word(31));
    br_imm5(11 downto 0) := inst_word( 7) & inst_word(30 downto 25) & inst_word(11 downto  8) & '0';
    br_imm6              := (others => inst_word(47));
    br_imm6(11 downto 0) := inst_word(23) & inst_word(46 downto 41) & inst_word(27 downto 24) & '0';
    br_imm7              := (others => inst_word(63));
    br_imm7(11 downto 0) := inst_word(39) & inst_word(62 downto 57) & inst_word(43 downto 40) & '0';

    j_imm0              := (others => buffer_in.inst.d(31));
    j_imm0(19 downto 0) := buffer_in.inst.d(19 downto 12) & buffer_in.inst.d(20) & buffer_in.inst.d(30 downto 21) & '0';
    j_imm1              := (others => inst_word(12));
    j_imm1(10 downto 0) := inst_word( 8) & inst_word(10 downto  9) & inst_word( 6) & inst_word( 7) & inst_word( 2) & inst_word(11) & inst_word( 5 downto  3) & '0';
    j_imm2              := (others => inst_word(28));
    j_imm2(10 downto 0) := inst_word(24) & inst_word(26 downto 25) & inst_word(22) & inst_word(23) & inst_word(18) & inst_word(27) & inst_word(21 downto 19) & '0';
    j_imm3              := (others => inst_word(44));
    j_imm3(10 downto 0) := inst_word(40) & inst_word(42 downto 41) & inst_word(38) & inst_word(39) & inst_word(34) & inst_word(43) & inst_word(37 downto 35) & '0';
    j_imm4              := (others => inst_word(60));
    j_imm4(10 downto 0) := inst_word(56) & inst_word(58 downto 57) & inst_word(54) & inst_word(55) & inst_word(50) & inst_word(59) & inst_word(53 downto 51) & '0';
    j_imm5              := (others => inst_word(31));
    j_imm5(19 downto 0) := inst_word(19 downto 12) & inst_word(20) & inst_word(30 downto 21) & '0';
    j_imm6              := (others => inst_word(47));
    j_imm6(19 downto 0) := inst_word(35 downto 28) & inst_word(36) & inst_word(46 downto 37) & '0';
    j_imm7              := (others => inst_word(63));
    j_imm7(19 downto 0) := inst_word(51 downto 44) & inst_word(52) & inst_word(62 downto 53) & '0';

    mux_imm0   := br_imm0;
    if buffer_in.inst.d(2) = '1' then
      mux_imm0 := j_imm0;
    end if;

    mux_imm1   := br_imm1;
    if inst_word(14) = '0' then
      mux_imm1 := j_imm1;
    end if;

    mux_imm2   := br_imm2;
    if inst_word(30) = '0' then
      mux_imm2 := j_imm2;
    end if;

    mux_imm3   := br_imm3;
    if inst_word(46) = '0' then
      mux_imm3 := j_imm3;
    end if;

    mux_imm4   := br_imm4;
    if inst_word(62) = '0' then
      mux_imm4 := j_imm4;
    end if;

    mux_imm5   := br_imm5;
    if inst_word(2) = '1' then
      mux_imm5 := j_imm5;
    end if;

    mux_imm6   := br_imm6;
    if inst_word(18) = '1' then
      mux_imm6 := j_imm6;
    end if;

    mux_imm7   := br_imm7;
    if inst_word(34) = '1' then
      mux_imm7 := j_imm7;
    end if;

    addlsb0_op1   := '0' & buffer_in.pc(11 downto 0);
    addlsb0_op2   := '0' & mux_imm0(11 downto 0);
    addlsb0       := uadd(addlsb0_op1, addlsb0_op2);
    addlsb1_op1   := '0' & dpc_in(11 downto 3) & "000";
    if single_issue /= 0 then
      addlsb1_op1 := '0' & dpc_in(11 downto 2) & "00";
    end if;
    addlsb1_op2   := '0' & mux_imm1(11 downto 0);
    addlsb1       := uadd(addlsb1_op1, addlsb1_op2);
    addlsb2_op1   := '0' & dpc_in(11 downto 3) & "010";
    if single_issue /= 0 then
      addlsb2_op1 := '0' & dpc_in(11 downto 2) & "10";
    end if;
    addlsb2_op2   := '0' & mux_imm2(11 downto 0);
    addlsb2       := uadd(addlsb2_op1, addlsb2_op2);
    addlsb3_op1   := '0' & dpc_in(11 downto 3) & "100";
    addlsb3_op2   := '0' & mux_imm3(11 downto 0);
    addlsb3       := uadd(addlsb3_op1, addlsb3_op2);
    addlsb4_op1   := '0' & dpc_in(11 downto 3) & "110";
    addlsb4_op2   := '0' & mux_imm4(11 downto 0);
    addlsb4       := uadd(addlsb4_op1, addlsb4_op2);
    addlsb5_op1   := '0' & dpc_in(11 downto 3) & "000";
    if single_issue /= 0 then
      addlsb5_op1 := '0' & dpc_in(11 downto 2) & "00";
    end if;
    addlsb5_op2   := '0' & mux_imm5(11 downto 0);
    addlsb5       := uadd(addlsb5_op1, addlsb5_op2);
    addlsb6_op1   := '0' & dpc_in(11 downto 3) & "010";
    addlsb6_op2   := '0' & mux_imm6(11 downto 0);
    addlsb6       := uadd(addlsb6_op1, addlsb6_op2);
    addlsb7_op1   := '0' & dpc_in(11 downto 3) & "100";
    addlsb7_op2   := '0' & mux_imm7(11 downto 0);
    addlsb7       := uadd(addlsb7_op1, addlsb7_op2);

    bjump1 := '0';
    bjump2 := '0';
    bjump3 := '0';
    bjump4 := '0';
    bjump5 := '0';
    bjump6 := '0';
    bjump7 := '0';
    jump0  := '0';
    jump1  := '0';
    jump2  := '0';
    jump3  := '0';
    jump4  := '0';
    jump5  := '0';
    jump6  := '0';
    jump7  := '0';

    -- C op=01 funct3=001 RV32 -> c.jal        jal x1,imm  (ret)
    -- C op=01 funct3=101      -> c.j          jal x0,imm  (jmp)
    -- C op=01 funct3=11x      -> c.beqz/bnez  beq/bne rs1',x0,imm
    if (inst_word(15 downto 13) = "001" and XLEN = 32) or inst_word(15 downto 13) = "101" or
       inst_word(15 downto 13) = "110" or inst_word(15 downto 13) = "111" then
      if inst_word(0) = '1' then
        bjump1 := '1';
      end if;
    end if;

    -- Together with the above - the unconditional C jumps
    if (inst_word(15 downto 13) = "001" and XLEN = 32) or inst_word(15 downto 13) = "101" then
      jump1 := '1';
    end if;

    if (inst_word(31 downto 29) = "001" and XLEN = 32) or inst_word(31 downto 29) = "101" or
       inst_word(31 downto 29) = "110" or inst_word(31 downto 29) = "111" then
      if inst_word(16) = '1' then
        bjump2 := '1';
      end if;
    end if;

    if (inst_word(31 downto 29) = "001" and XLEN = 32) or inst_word(31 downto 29) = "101" then
      jump2 := '1';
    end if;

    if (inst_word(47 downto 45) = "001" and XLEN = 32) or inst_word(47 downto 45) = "101" or
       inst_word(47 downto 45) = "110" or inst_word(47 downto 45) = "111" then
      if inst_word(32) = '1' then
        bjump3 := '1';
      end if;
    end if;

    if (inst_word(47 downto 45) = "001" and XLEN = 32) or inst_word(47 downto 45) = "101" then
      jump3 := '1';
    end if;

    if (inst_word(63 downto 61) = "001" and XLEN = 32) or inst_word(63 downto 61) = "101" or
       inst_word(63 downto 61) = "110" or inst_word(63 downto 61) = "111" then
      if inst_word(48) = '1' then
        bjump4 := '1';
      end if;
    end if;

    if (inst_word(63 downto 61) = "001" and XLEN = 32) or inst_word(63 downto 61) = "101" then
      jump4 := '1';
    end if;

    if inst_word(6 downto 5) = "11" and (inst_word(4 downto 2) = "000" or inst_word(4 downto 2) = "011") then
      bjump5 := '1';
      if inst_word(3) = '1' then
        jump5 := '1';
      end if;
    end if;

    if inst_word(22 downto 21) = "11" and (inst_word(20 downto 18) = "000" or inst_word(20 downto 18) = "011") then
      bjump6 := '1';
      if inst_word(19) = '1' then
        jump6 := '1';
      end if;
    end if;

    if inst_word(38 downto 37) = "11" and (inst_word(36 downto 34) = "000" or inst_word(36 downto 34) = "011") then
      bjump7 := '1';
      if inst_word(35) = '1' then
        jump7 := '1';
      end if;
    end if;


    addlsbf         := addlsb0;
    mux_immf        := mux_imm0;
    bj_taken        := '0';
    bjump_buf_out_v := '0';
    dpc_in_t(2 downto 1) := dpc_in(2 downto 1);
    if single_issue /= 0 then
      dpc_in_t(2)   := '0';
    end if;
    if buffer_in.valid = '1' and buffer_in.prediction.taken = '1' and buffer_in.bjump = '1' and buffer_in.bjump_predicted = '0' then
      -- Buffer always contains the oldest instruction
      addlsbf           := addlsb0;
      mux_immf          := mux_imm0;
      if buffer_in.prediction.hit = '0' then
        bj_taken        := '1';
        bjump_buf_out_v := '1';
      else
        btb_taken       := '1';
        btb_taken_buf   := '1';
      end if;
    elsif dvalid = '1' then
      case dpc_in_t(2 downto 1) is
        when "00" =>
          -- Not Compressed instruction in [31:0]
          if inst_word(1 downto 0) = "11" then
            if bjump5 = '1' and (btaken(0) = '1' or jump5 = '1') then
              addlsbf      := addlsb5;
              mux_immf     := mux_imm5;
              if btb_hit(0) = '0' then
                bj_taken   := '1';
              else
                btb_taken  := '1';
              end if;
              bjump_pos(0) := '1';
            else
              if inst_word(33 downto 32) = "11" then
                -- Not Compressed instruction in [63:32]
                if bjump7 = '1' and (btaken(2) = '1' or jump7 = '1') and single_issue = 0 then
                  addlsbf      := addlsb7;
                  mux_immf     := mux_imm7;
                  if btb_hit(2) = '0' then
                    bj_taken   := '1';
                  else
                    btb_taken  := '1';
                  end if;
                  bjump_pos(2) := '1';
                end if;
              else
                -- Compressed instruction in [47:32]
                if bjump3 = '1' and (btaken(2) = '1' or jump3 = '1') and single_issue = 0 then
                  addlsbf      := addlsb3;
                  mux_immf     := mux_imm3;
                  if btb_hit(2) = '0' then
                    bj_taken   := '1';
                  else
                    btb_taken  := '1';
                  end if;
                  bjump_pos(2) := '1';
                elsif inst_word(49 downto 48) /= "11" then
                  -- Compressed instruction in [63:48]
                  if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') and single_issue = 0 then
                    addlsbf      := addlsb4;
                    mux_immf     := mux_imm4;
                    if btb_hit(3) = '0' then
                      bj_taken   := '1';
                    else
                      btb_taken  := '1';
                    end if;
                    bjump_pos(3) := '1';
                  end if;
                end if;
              end if;  -- inst_word(33 downto 32) = "11" then
            end if;  -- bjump5 = '1' and btb_hit(0) = '0' and btaken(0) = '1'
          else
            -- Compressed instruction in [16:0]
            if bjump1 = '1' and (btaken(0) = '1' or jump1 = '1') then
              addlsbf      := addlsb1;
              mux_immf     := mux_imm1;
              if btb_hit(0) = '0' then
                bj_taken   := '1';
              else
                btb_taken  := '1';
              end if;
              bjump_pos(0) := '1';
            else
              if inst_word(17 downto 16) = "11" then
                -- Not compressed instruction in [47:16]
                if bjump6 = '1' and (btaken(1) = '1' or jump6 = '1') and single_issue = 0 then
                  addlsbf      := addlsb6;
                  mux_immf     := mux_imm6;
                  if btb_hit(1) = '0' then
                    bj_taken   := '1';
                  else
                    btb_taken  := '1';
                  end if;
                  bjump_pos(1) := '1';
                elsif inst_word(49 downto 48) /= "11" then
                  -- Compressed instruction in [63:48]
                  if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') and single_issue = 0 then
                    addlsbf      := addlsb4;
                    mux_immf     := mux_imm4;
                    if btb_hit(3) = '0' then
                      bj_taken   := '1';
                    else
                      btb_taken  := '1';
                    end if;
                    bjump_pos(3) := '1';
                  end if;
                end if;
              else
                -- Compressed instruction in [32:16]
                if bjump2 = '1'and (btaken(1) = '1' or jump2 = '1') and single_issue = 0 then
                  addlsbf      := addlsb2;
                  mux_immf     := mux_imm2;
                  if btb_hit(1) = '0' then
                    bj_taken   := '1';
                  else
                    btb_taken  := '1';
                  end if;
                  bjump_pos(1) := '1';
                else
                  if inst_word(33 downto 32) = "11" then
                    -- Not Compressed instruction in [63:32]
                    if bjump7 = '1' and btaken(2) = '1' and single_issue = 0 then
                      addlsbf      := addlsb7;
                      mux_immf     := mux_imm7;
                      if btb_hit(2) = '0' then
                        bj_taken   := '1';
                      else
                        btb_taken  := '1';
                      end if;
                      bjump_pos(2) := '1';
                    end if;
                  else
                    -- Compressed instruction in [47:32]
                    if bjump3 = '1' and (btaken(2) = '1' or jump3 = '1') and single_issue = 0 then
                      addlsbf      := addlsb3;
                      mux_immf     := mux_imm3;
                      if btb_hit(2) = '0' then
                        bj_taken   := '1';
                      else
                        btb_taken  := '1';
                      end if;
                      bjump_pos(2) := '1';
                    elsif inst_word(49 downto 48) /= "11" then
                      -- Compressed instruction in [63:48]
                      if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') and single_issue = 0 then
                        addlsbf      := addlsb4;
                        mux_immf     := mux_imm4;
                        if btb_hit(3) = '0' then
                          bj_taken   := '1';
                        else
                          btb_taken  := '1';
                        end if;
                        bjump_pos(3) := '1';
                      end if;
                    end if;
                  end if;
                end if;
              end if;  -- inst_word(17 downto 16) = "11" then
            end if;  -- bjump1 = '1' and btb_hit(0) = '0' and btaken(0) = '1'
          end if;  -- inst_word(1 downto 0) = "11" then                     --
        when "01" =>
          if inst_word(17 downto 16) = "11" then
            -- Not compressed instruction in [47:16]
            if bjump6 = '1' and (btaken(1) = '1' or jump6 = '1') and single_issue = 0 then
              addlsbf      := addlsb6;
              mux_immf     := mux_imm6;
              if btb_hit(1) = '0' then
                bj_taken   := '1';
              else
                btb_taken  := '1';
              end if;
              bjump_pos(1) := '1';
            elsif inst_word(49 downto 48) /= "11" then
              -- Compressed instruction in [63:48]
              if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') and single_issue = 0 then
                addlsbf      := addlsb4;
                mux_immf     := mux_imm4;
                if btb_hit(3) = '0' then
                  bj_taken   := '1';
                else
                  btb_taken  := '1';
                end if;
                bjump_pos(3) := '1';
              end if;
            end if;
          else
            -- Compressed instruction in [32:16]
            if bjump2 = '1' and (btaken(1) = '1' or jump2 = '1') then
              addlsbf      := addlsb2;
              mux_immf     := mux_imm2;
              if btb_hit(1) = '0' then
                bj_taken   := '1';
              else
                btb_taken  := '1';
              end if;
              bjump_pos(1) := '1';
            else
              if single_issue = 0 then
                if inst_word(33 downto 32) = "11" then
                  -- Not compressed instruction in [63:32]
                  if bjump7 = '1' and (btaken(2) = '1' or jump7 = '1') and single_issue = 0 then
                    addlsbf      := addlsb7;
                    mux_immf     := mux_imm7;
                    if btb_hit(2) = '0' then
                      bj_taken   := '1';
                    else
                      btb_taken  := '1';
                    end if;
                    bjump_pos(2) := '1';
                  end if;
                else
                  -- Compressed instruction in [47:32]
                  if bjump3 = '1' and (btaken(2) = '1' or jump3 = '1') and single_issue = 0 then
                    addlsbf      := addlsb3;
                    mux_immf     := mux_imm3;
                    if btb_hit(2) = '0' then
                      bj_taken   := '1';
                    else
                      btb_taken  := '1';
                    end if;
                    bjump_pos(2) := '1';
                  elsif inst_word(49 downto 48) /= "11" then
                    -- Compressed instruction in [63:48]
                    if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') and single_issue = 0 then
                      addlsbf      := addlsb4;
                      mux_immf     := mux_imm4;
                      if btb_hit(3) = '0' then
                        bj_taken   := '1';
                      else
                        btb_taken  := '1';
                      end if;
                      bjump_pos(3) := '1';
                    end if;
                  end if;
                end if;
              end if;
            end if;  -- bjump2 = '1' and btb_hit(1) = '0' and btaken(1) = '1' then
          end if;  -- inst_word(17 downto 16) = "11" then
        when "10" =>
          if single_issue = 0 then
            if inst_word(33 downto 32) = "11" then
              -- Not compressed instruction in [63:32]
              if bjump7 = '1' and (btaken(2) = '1' or jump7 = '1') then
                addlsbf      := addlsb7;
                mux_immf     := mux_imm7;
                if btb_hit(2) = '0' then
                  bj_taken   := '1';
                else
                  btb_taken  := '1';
                end if;
                bjump_pos(2) := '1';
              end if;
            else
              -- Comressed instruction in [47:32]
              if bjump3 = '1' and (btaken(2) = '1' or jump3 = '1') then
                addlsbf      := addlsb3;
                mux_immf     := mux_imm3;
                if btb_hit(2) = '0' then
                  bj_taken   := '1';
                else
                  btb_taken  := '1';
                end if;
                bjump_pos(2) := '1';
              elsif inst_word(49 downto 48) /= "11" then
                -- Compressed instruction in [63:48]
                if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') then
                  addlsbf      := addlsb4;
                  mux_immf     := mux_imm4;
                  if btb_hit(3) = '0' then
                    bj_taken   := '1';
                  else
                    btb_taken  := '1';
                  end if;
                  bjump_pos(3) := '1';
                end if;
              end if;
            end if;  -- inst_word(34 downto 33) = "11"
          else
            null;
          end if;  -- single_issue = 0
        when "11" =>
          if single_issue = 0 then
            if inst_word(49 downto 48) /= "11" then
              -- Compressed instruction in [63:48]
              if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') then
                addlsbf      := addlsb4;
                mux_immf     := mux_imm4;
                if btb_hit(3) = '0' then
                  bj_taken   := '1';
                else
                  btb_taken  := '1';
                end if;
                bjump_pos(3) := '1';
              end if;
            end if;
          else
            null;
          end if;  -- single_issue = 0
        when others =>
          null;
      end case;
    end if;

    -- Since the incoming PC values are guaranteed to be "canonical"
    -- (as in OK virtual or physical addresses), any add that would
    -- overflow into higher bits will be visible (and fault on access).
    if bjump_buf_out_v = '1' then
      pc          := buffer_in.pc(high_part'range);
    else
      pc          := dpc_in(high_part'range);
    end if;
    addrmsbt      := uadd(pc & '1', mux_immf(high_part'range) & addlsbf(12));
    bjump_addr    := addrmsbt(high_part'range) & addlsbf(11 downto 0);
    bjump_out     := bj_taken;
    bjump_buf_out := bjump_buf_out_v;
  end;

  procedure rvc_expander(active   : in  extension_type;
                         inst_in  : in  word16;
                         fpu_en   : in  boolean;
                         inst_out : out word;
                         xc_out   : out std_ulogic) is
    variable is_rv64  : boolean  := is_enabled(active, x_rv64);
    variable is_rv32  : boolean  := not is_rv64;
    variable ext_f    : integer  := is_enabled(active, x_f);
    variable ext_d    : integer  := is_enabled(active, x_d);
    -- Evaluate compressed instruction
    variable op     : word2                         := inst_in(1 downto 0);
    variable funct3 : funct3_type                   := inst_in(15 downto 13);
    -- Evaluate imm sign-extension, MSB of imm is always bit 12th.
    variable imm12  : std_logic_vector(11 downto 0) := (others => inst_in(12));
    variable rfa1   : rfatype                       := inst_in(11 downto 7);
    variable rfa2   : rfatype                       := inst_in(6 downto 2);
    variable rd     : rfatype                       := inst_in(11 downto 7);
    variable rfa1c  : rfatype                       := "01" & inst_in(9 downto 7);
    variable rfa2c  : rfatype                       := "01" & inst_in(4 downto 2);
    variable rdc    : rfatype                       := "01" & inst_in(4 downto 2);
    -- Non-constant
    variable inst   : word;
    variable xc     : std_ulogic                    := '0';
  begin

    -- Default to the first below, for no particular reason.
    inst := "00" &                   -- imm[11:10]
            inst_in(10 downto 7) &   -- imm[9:6]
            inst_in(12 downto 11) &  -- imm[5:4]
            inst_in(5) &             -- imm[3]
            inst_in(6) &             -- imm[2]
            "00" &                   -- imm[1:0]
            GPR_SP &                 -- rs1
            I_ADDI &                 -- funct3
            rdc &                    -- rd
            OP_IMM;                  -- addi

    -- Expand instruction
    case op is

      -- C0
      when "00" =>
        case funct3 is

          -- c.addi4spn -> addi rd', x2, imm
          when "000" =>
            inst := "00" &                   -- imm[11:10]
                    inst_in(10 downto 7) &   -- imm[9:6]
                    inst_in(12 downto 11) &  -- imm[5:4]
                    inst_in(5) &             -- imm[3]
                    inst_in(6) &             -- imm[2]
                    "00" &                   -- imm[1:0]
                    GPR_SP &                 -- rs1
                    I_ADDI &                 -- funct3
                    rdc &                    -- rd
                    OP_IMM;                  -- addi
            -- imm = 0 are reserved by the standard.
            if inst_in(12 downto 5) = "00000000" then
              xc := '1';
            end if;

            -- c.fld -> fld rd', imm(rs1')
          when "001" =>
              inst := "0000" &                 -- imm[11:8]
                      inst_in(6 downto 5) &    -- imm[7:6]
                      inst_in(12 downto 10) &  -- imm[5:3]
                      "000" &                  -- imm[2:0]
                      rfa1c &                  -- rs1
                      I_FLD &                  -- funct3
                      rdc &                    -- rd
                      OP_LOAD_FP;              -- fld
            if ext_d = 0 or not fpu_en then
              xc := '1';
            end if;

            -- c.lw -> lw rd', imm(rs1')
          when "010" =>
            inst := "00000" &                -- imm[11:7]
                    inst_in(5) &             -- imm[6]
                    inst_in(12 downto 10) &  -- imm[5:3]
                    inst_in(6) &             -- imm[2]
                    "00" &                   -- imm[1:0]
                    rfa1c &                  -- rs1
                    I_LW &                   -- funct3
                    rdc &                    -- rd
                    OP_LOAD;                 -- addi

            -- c.flw
            -- c.ld
          when "011" =>
            -- c.flw -> flw rd', imm(rs1')
            if is_rv32 and ext_f = 1 then
              inst := "00000" &                -- imm[11:7]
                      inst_in(5) &             -- imm[6]
                      inst_in(12 downto 10) &  -- imm[5:3]
                      inst_in(6) &             -- imm[2]
                      "00" &                   -- imm[1:0]
                      rfa1c &                  -- rs1
                      I_FLW &                  -- funct3
                      rdc &                    -- rd
                      OP_LOAD_FP;              -- flw
              if not fpu_en then
                xc := '1';
              end if;
              -- c.ld -> ld rd', imm(rs1')
            elsif is_rv64 then
              inst := "0000" &                 -- imm[11:8]
                      inst_in(6 downto 5) &    -- imm[7:6]
                      inst_in(12 downto 10) &  -- imm[5:3]
                      "000" &                  -- imm[2:0]
                      rfa1c &                  -- rs1
                      I_LD &                   -- funct3
                      rdc &                    -- rd
                      OP_LOAD;                 -- ld
            else
              xc := '1';
            end if;

            -- c.fsd -> fsd rs2', imm(rs1')
          when "101" =>
            if ext_d = 1 and fpu_en then
              inst := "0000" &                 -- imm[11:8]
                      inst_in(6 downto 5) &    -- imm[7:6]
                      inst_in(12) &            -- imm[5]
                      rfa2c &                  -- rs2
                      rfa1c &                  -- rs1
                      S_FSD &                  -- funct3
                      inst_in(11 downto 10) &  -- imm[4:3]
                      "000" &                  -- imm[2:0]
                      OP_STORE_FP;             -- fsd
            else
              xc := '1';
            end if;

            -- c.sw -> sw rs2', imm(rs1')
          when "110" =>
            inst := "00000" &                -- imm[11:7]
                    inst_in(5) &             -- imm[6]
                    inst_in(12) &            -- imm[5]
                    rfa2c &                  -- rs2
                    rfa1c &                  -- rs1
                    S_SW &                   -- funct3
                    inst_in(11 downto 10) &  -- imm[4:3]
                    inst_in(6) &             -- imm[2]
                    "00" &                   -- imm[1:0]
                    OP_STORE;                -- sw
            -- c.fsw
            -- c.sd
          when "111" =>
            -- c.fsw -> fsw rs2', imm(rs1')
            if is_rv32 and ext_f = 1 then
              inst := "00000" &                -- imm[11:7]
                      inst_in(5) &             -- imm[6]
                      inst_in(12) &            -- imm[5]
                      rfa2c &                  -- rs2
                      rfa1c &                  -- rs1
                      S_FSW &                  -- funct3
                      inst_in(11 downto 10) &  -- imm[4:3]
                      inst_in(6) &             -- imm[2]
                      "00" &                   -- imm[1:0]
                      OP_STORE_FP;             -- sw
              if not fpu_en then
                xc := '1';
              end if;
              -- c.sd -> sd rs2', imm(rs1')
            elsif is_rv64 then
              inst := "0000" &                 -- imm[11:8]
                      inst_in(6 downto 5) &    -- imm[7:6]
                      inst_in(12) &            -- imm[5]
                      rfa2c &                  -- rs2
                      rfa1c &                  -- rs1
                      S_SD &                   -- funct3
                      inst_in(11 downto 10) &  -- imm[4:3]
                      "000" &                  -- imm[2:0]
                      OP_STORE;                -- sw
            else
              xc := '1';
            end if;

            -- 100 -> illegal instruction
          when others =>
            xc := '1';

        end case;  -- funct3

        -- C1
      when "01" =>
        case funct3 is

          -- c.nop -> addi x0, x0, 0
          -- c.addi -> addi rd, rd, imm
          when "000" =>
            inst := imm12(11 downto 6) &   -- imm[11:6]
                    inst_in(12) &          -- imm[5]
                    inst_in(6 downto 2) &  -- imm[4:0]
                    rfa1 &                 -- rs1
                    I_ADDI &               -- funct3
                    rd &                   -- rd
                    OP_IMM;                -- addi
            -- For the c.nop case, imm /= 0 are standard HINTs.
            -- For the c.addi case, imm = 0 are standard HINTs.

            -- c.jal
            -- c.addiw
          when "001" =>
            if is_rv32 then
              -- c.jal -> jal x1, imm
              inst := inst_in(12) &           -- imm[20]
                      inst_in(8) &            -- imm[10]
                      inst_in(10 downto 9) &  -- imm[9:8]
                      inst_in(6) &            -- imm[7]
                      inst_in(7) &            -- imm[6]
                      inst_in(2) &            -- imm[5]
                      inst_in(11) &           -- imm[4]
                      inst_in(5 downto 3) &   -- imm[3:1]
                      inst_in(12) &           -- imm[11]
                      imm12(11 downto 4) &    -- imm[19:12]
                      GPR_RA &                -- rd
                      OP_JAL;                 -- jal
            else
              -- c.addiw -> addiw rd, rd, imm
              inst := imm12(11 downto 6) &    -- imm[11:6]
                      inst_in(12) &           -- imm[5]
                      inst_in(6 downto 2) &   -- imm[4:0]
                      rfa1 &                  -- rs1
                      I_ADDI &                -- funct3
                      rd &                    -- rd
                      OP_IMM_32;              -- addi
              -- rd = x0 are reserved by the standard.
              if rd = "00000" then
                xc := '1';
              end if;
            end if;

            -- c.li -> addi rd, x0, imm
          when "010" =>
            inst := imm12(11 downto 6) &   -- imm[11:6]
                    inst_in(12) &          -- imm[5]
                    inst_in(6 downto 2) &  -- imm[4:0]
                    GPR_X0 &               -- rs1
                    I_ADDI &               -- funct3
                    rd &                   -- rd
                    OP_IMM;                -- addi
            -- rd = x0 are standard HINTs.

            -- c.addi16sp
            -- c.lui
          when "011" =>
            if rd = GPR_SP then
              -- c.addi16sp -> addi x2, x2, imm
              inst := imm12(11 downto 10) &  -- imm[11:10]
                      inst_in(12) &          -- imm[9]
                      inst_in(4 downto 3) &  -- imm[8:7]
                      inst_in(5) &           -- imm[6]
                      inst_in(2) &           -- imm[5]
                      inst_in(6) &           -- imm[4]
                      "0000" &               -- imm[3:0]
                      GPR_SP &               -- rs1
                      I_ADDI &               -- funct3
                      GPR_SP &               -- rd
                      OP_IMM;                -- addi
            else
              -- rd = x0, imm /= 0 are standard HINTs.
              -- c.lui -> lui rd, imm
              inst := imm12 &                -- imm[31:20]
                      imm12(11 downto 10) &  -- imm[19:18]
                      inst_in(12) &          -- imm[17]
                      inst_in(6 downto 2) &  -- imm[16:12]
                      rd &                   -- rd
                      LUI;                   -- lui
            end if;
            -- c.addi16sp and c.lui are reserved with imm = 0.
            if inst_in(12) = '0' and inst_in(6 downto 2) = "00000" then
              xc := '1';
            end if;

            -- ALU
          when "100" =>
            case inst_in(11 downto 10) is

              -- c.srli -> srli rd', rs1', shamt
              -- c.srai -> srai rd', rs1', shamt
              when "00" | "01" =>
                inst := inst_in(11 downto 10) &  -- funct7[6:5]
                        "0000" &                 -- funct7[4:1]
                        inst_in(12) &            -- shamt[5]
                        inst_in(6 downto 2) &    -- shamt[4:0]
                        rfa1c &                  -- rs1
                        I_SRLI &                 -- funct3
                        rfa1c &                  -- rd
                        OP_IMM;                  -- srli/srai
                -- For RV32, the code points with the high bit set
                -- are designated for custom extensions.
                if is_rv32 and inst_in(12) = '1' then
                  xc := '1';
                end if;
                -- shamt = 0 are custom HINTs.

                -- c.andi -> andi rd', rs1', imm
              when "10" =>
                inst := imm12(11 downto 6) &   -- imm[11:6]
                        inst_in(12) &          -- imm[5]
                        inst_in(6 downto 2) &  -- imm[4:0]
                        rfa1c &                -- rs1
                        I_ANDI &               -- funct3
                        rfa1c &                -- rd
                        OP_IMM;                -- andi

                -- misc
              when "11" =>
                case inst_in(6 downto 5) is

                  -- c.sub[w] -> sub[w] rd', rs1', rs2'
                  when "00" =>
                    inst := F7_SUB &    -- funct7
                            rfa2c &     -- rs2
                            rfa1c &     -- rs1
                            R_SUB &     -- funct3
                            rfa1c &     -- rd
                            OP_REG;     -- sub
                    if inst_in(12) = '1' then
                      if is_rv64 then
                        inst(6 downto 0) := OP_32;
                      else
                        xc := '1';
                      end if;
                    end if;

                    -- c.xor -> xor rd', rs1', rs2'
                    -- c.addw -> addw rd', rs1', rs2'
                  when "01" =>
                    inst := F7_BASE &   -- funct7
                            rfa2c &     -- rs2
                            rfa1c &     -- rs1
                            R_XOR &     -- funct3
                            rfa1c &     -- rd
                            OP_REG;     -- sub
                    if inst_in(12) = '1' then
                      if is_rv64 then
                        inst(14 downto 12) := R_ADDW;
                        inst(6 downto 0)   := OP_32;
                      else
                        xc := '1';
                      end if;
                    end if;

                    -- c.or -> or rd', rs1', rs2'
                  when "10" =>
                    inst := F7_BASE &   -- funct7
                            rfa2c &     -- rs2
                            rfa1c &     -- rs1
                            R_OR &      -- funct3
                            rfa1c &     -- rd
                            OP_REG;     -- or
                    if inst_in(12) = '1' then
                      xc := '1';
                    end if;

                    -- c.and -> and rd', rs1', rs2'
                  when "11" =>
                    inst := F7_BASE &   -- funct7
                            rfa2c &     -- rs2
                            rfa1c &     -- rs1
                            R_AND &     -- funct3
                            rfa1c &     -- rd
                            OP_REG;     -- and
                    if inst_in(12) = '1' then
                      xc := '1';
                    end if;

                  when others =>
                    xc := '1';

                end case;  -- inst_in(6 downto 5)

              when others =>
                xc := '1';

            end case;  -- inst_in(11 downto 10)

            -- c.j -> jal x0, imm
          when "101" =>
            inst := inst_in(12) &           -- imm[20]
                    inst_in(8) &            -- imm[10]
                    inst_in(10 downto 9) &  -- imm[9:8]
                    inst_in(6) &            -- imm[7]
                    inst_in(7) &            -- imm[6]
                    inst_in(2) &            -- imm[5]
                    inst_in(11) &           -- imm[4]
                    inst_in(5 downto 3) &   -- imm[3:1]
                    inst_in(12) &           -- imm[11]
                    imm12(11 downto 4) &    -- imm[19:12]
                    GPR_X0 &                -- rd
                    OP_JAL;                 -- jal

            -- c.beqz -> beq rs1', x0, imm
            -- c.bnez -> bne rs1', x0, imm
          when "110" | "111" =>
            inst := inst_in(12) &            -- imm[12]
                    imm12(10 downto 9) &     -- imm[10:9]
                    inst_in(12) &            -- imm[8]
                    inst_in(6 downto 5) &    -- imm[7:6]
                    inst_in(2) &             -- imm[5]
                    GPR_X0 &                 -- rs2
                    rfa1c &                  -- rs1
                    "00" & inst_in(13) &     -- funct3
                    inst_in(11 downto 10) &  -- imm[4:3]
                    inst_in(4 downto 3) &    -- imm[2:1]
                    inst_in(12) &            -- imm[11]
                    OP_BRANCH;               -- branch

          when others =>
            xc := '1';

        end case;  -- inst_in(11 downto 10)

        -- C2
      when "10" =>
        case funct3 is

          -- c.slli -> slli rd, rs1, shamt
          when "000" =>
            inst := "000000" &             -- funct7[6:1]
                    inst_in(12) &          -- shamt[5]
                    inst_in(6 downto 2) &  -- shamt[4:0]
                    rfa1 &                 -- rs1
                    I_SLLI &               -- funct3
                    rd &                   -- rd
                    OP_IMM;                -- slli
            -- For RV32, the code points with the high bit set
            -- are designated for custom extensions.
            if is_rv32 and inst_in(12) = '1' then
              xc := '1';
            end if;
            -- rd = x0 are custom HINTs (except as above).

            -- c.fldsp -> fld rd, imm(x2)
          when "001" =>
            inst := "000" &                -- imm[11:9]
                    inst_in(4 downto 2) &  -- imm[8:6]
                    inst_in(12) &          -- imm[5]
                    inst_in(6 downto 5) &  -- imm[4:3]
                    "000" &                -- imm[2:0]
                    GPR_SP &               -- rs1
                    I_LD &                 -- funct3
                    rd &                   -- rd
                    OP_LOAD_FP;            -- fld
            if ext_d = 0 or not fpu_en then
              xc := '1';
            end if;

            -- c.lwsp -> lw rd, imm(x2)
          when "010" =>
            inst := "0000" &               -- imm[11:8]
                    inst_in(3 downto 2) &  -- imm[7:6]
                    inst_in(12) &          -- imm[5]
                    inst_in(6 downto 4) &  -- imm[4:2]
                    "00" &                 -- imm[1:0]
                    GPR_SP &               -- rs1
                    I_LW &                 -- funct3
                    rd &                   -- rd
                    OP_LOAD;               -- ld
            -- rd = x0 are reserved by the standard.
            if rd = "00000" then
              xc := '1';
            end if;

            -- c.flwsp
            -- c.ldsp
          when "011" =>
            -- c.flwsp -> flw rd, imm(x2)
            if is_rv32 then
              inst := "0000" &               -- imm[11:8]
                      inst_in(3 downto 2) &  -- imm[7:6]
                      inst_in(12) &          -- imm[5]
                      inst_in(6 downto 4) &  -- imm[4:2]
                      "00" &                 -- imm[1:0]
                      GPR_SP &               -- rs1
                      I_FLW &                -- funct3
                      rd &                   -- rd
                      OP_LOAD_FP;            -- flw
              if ext_f = 0 or not fpu_en then
                xc := '1';
              end if;
              -- c.ldsp -> ld rd, imm(x2)
            else
              inst := "000" &                -- imm[11:9]
                      inst_in(4 downto 2) &  -- imm[8:6]
                      inst_in(12) &          -- imm[5]
                      inst_in(6 downto 5) &  -- imm[4:3]
                      "000" &                -- imm[2:0]
                      GPR_SP &               -- rs1
                      I_LD &                 -- funct3
                      rd &                   -- rd
                      OP_LOAD;               -- ld
              -- rd = x0 are reserved by the standard.
              if rd = "00000" then
                xc := '1';
              end if;
            end if;

            -- misc
          when "100" =>

            if inst_in(12) = '0' then
              -- c.jr -> jalr x0, 0(rs1)
              if rfa2 = "00000" then
                inst := imm12 &         -- imm[11:0]
                        rfa1 &          -- rs1
                        I_JALR &        -- funct3
                        GPR_X0 &        -- rd
                        OP_JALR;        -- jalr
                -- rs1 = x0 are reserved by the standard.
                if rfa1 = "00000" then
                  xc := '1';
                end if;
              -- c.mv -> add rd, x0, rs2
              else
                inst := F7_BASE &       -- funct7
                        rfa2 &          -- rs2
                        GPR_X0 &        -- rs1
                        R_ADD &         -- funct3
                        rd &            -- rd
                        OP_REG;         -- add
                -- rd = x0 are standard HINTs.
              end if;

            else

              if rfa2 = "00000" then

                -- c.ebreak -> ebreak
                if rd = "00000" then
                  inst             := (others => '0');
                  inst(20)         := '1';
                  inst(6 downto 0) := OP_SYSTEM;
                  -- c.jalr -> jalr x1, 0(rs1)
                else
                  inst := zerow(11 downto 0) &  -- imm[11:0]
                          rfa1 &                -- rs1
                          I_JALR &              -- funct3
                          GPR_RA &              -- rd
                          OP_JALR;              -- jalr
                end if;  -- rd

                -- c.add -> rd, rs1, rs2
              else
                inst := F7_BASE &       -- funct7
                        rfa2 &          -- rs2
                        rfa1 &          -- rs1
                        R_ADD &         -- funct3
                        rd &            -- rd
                        OP_REG;         -- add
              -- rd = x0 are standard HINTs.
              end if;
            end if;  -- inst_in(12)

            -- c.fsdsp -> fsd rs2, imm(x2)
          when "101" =>
            inst := "000" &                  -- imm[11:9]
                    inst_in(9 downto 7) &    -- imm[8:6]
                    inst_in(12) &            -- imm[5]
                    rfa2 &                   -- rs2
                    GPR_SP &                 -- rs1
                    S_FSD &                  -- funct3
                    inst_in(11 downto 10) &  -- imm[4:3]
                    "000" &                  -- imm[2:0]
                    OP_STORE_FP;             -- fld
            if ext_d = 0 or not fpu_en then
              xc := '1';
            end if;

            -- c.swsp -> sw rs2, imm(x2)
          when "110" =>
            inst := "0000" &                -- imm[11:8]
                    inst_in(8 downto 7) &   -- imm[7:6]
                    inst_in(12) &           -- imm[5]
                    rfa2 &                  -- rs2
                    GPR_SP &                -- rs1
                    S_SW &                  -- funct3
                    inst_in(11 downto 9) &  -- imm[4:2]
                    "00" &                  -- imm[1:0]
                    OP_STORE;               -- sw

            -- c.fswsp
            -- c.sdsp
          when "111" =>
            -- c.fswsp -> fsw rs2, imm(x2)
            if is_rv32 and ext_f = 1 then
              inst := "0000" &                 -- imm[11:8]
                      inst_in(8 downto 7) &    -- imm[7:6]
                      inst_in(12) &            -- imm[5]
                      rfa2 &                   -- rs2
                      GPR_SP &                 -- rs1
                      S_FSW &                  -- funct3
                      inst_in(11 downto 9) &   -- imm[4:2]
                      "00" &                   -- imm[1:0]
                      OP_STORE_FP;             -- fsw
            if not fpu_en then
              xc := '1';
            end if;
              -- c.sdsp -> sd rs2, imm(x2)
            elsif is_rv64 then
              inst := "000" &                  -- imm[11:9]
                      inst_in(9 downto 7) &    -- imm[8:6]
                      inst_in(12) &            -- imm[5]
                      rfa2 &                   -- rs2
                      GPR_SP &                 -- rs1
                      S_SD &                   -- funct3
                      inst_in(11 downto 10) &  -- imm[4:3]
                      "000" &                  -- imm[2:0]
                      OP_STORE;                -- sd
            else
              xc := '1';
            end if;

          when others =>
            xc := '1';

        end case;  -- funct3

      when others =>
        null;

    end case;  -- op

    inst_out := inst;
    xc_out   := xc;
  end;

  -- Align compressed instruction
  procedure rvc_aligner(active           : in  extension_type;
                        inst_in          : in  iword_pair_type;
                        rvc_pc           : in  std_logic_vector;
                        valid_in         : in  std_ulogic;
                        fpu_en           : in  boolean;
                        inst_out         : out iword_pair_type;
                        comp_ill         : out std_logic_vector(1 downto 0);
                        hold_out         : out std_ulogic;
                        npc_out          : out std_logic_vector;
                        valid_out        : out std_logic_vector;
                        buffer_first_out : out std_logic;  -- buffer first instruction
                        buffer_sec_out   : out std_logic;  -- buffer second instruction
                                                           --  if not issued
                        buffer_third_out : out std_logic;  -- buffer the third instruction
                        buffer_inst      : out iword_type;
                        buff_comp_ill    : out std_logic;
                        unaligned_out    : out std_ulogic) is
    variable single_issue : integer    := is_enabled(active, x_single_issue);
    -- Non-constant
    variable inst         : iword_pair_type;
    variable unaligned    : std_ulogic := '0';
    variable hold         : std_ulogic := '0';
    variable npc          : word3      := (others => '0');
    variable valid        : fetch_pair := (others => '0');
    variable buffer_first : std_ulogic;
    variable buffer_sec   : std_ulogic;
    variable buffer_third : std_ulogic;
    variable inst_c0e     : word;
    variable inst_c1e     : word;
    variable inst_c2e     : word;
    variable inst_c3e     : word;
    variable inst_c0xc    : std_ulogic;
    variable inst_c1xc    : std_ulogic;
    variable inst_c2xc    : std_ulogic;
    variable inst_c3xc    : std_ulogic;
    variable rvc_pc_t     : std_logic_vector(2 downto 0);
  begin

    rvc_expander(active,
                 inst_in(0).d(15 downto 0),
                 fpu_en,
                 inst_c0e,
                 inst_c0xc);
    rvc_expander(active,
                 inst_in(0).d(31 downto 16),
                 fpu_en,
                 inst_c1e,
                 inst_c1xc);
    if single_issue = 0 then
      rvc_expander(active,
                   inst_in(1).d(15 downto 0),
                   fpu_en,
                   inst_c2e,
                   inst_c2xc);
      rvc_expander(active,
                   inst_in(1).d(31 downto 16),
                   fpu_en,
                   inst_c3e,
                   inst_c3xc);
    else
      inst_c2e  := (others => '0');
      inst_c3e  := (others => '0');
      inst_c2xc := '0';
      inst_c3xc := '0';
    end if;

    inst(0).lpc   := "00";
    inst(0).d     := inst_in(0).d;
    inst(0).dc    := inst_in(0).d(15 downto 0);
    inst(0).xc    := "000";
    inst(0).c     := '0';
    inst(1).lpc   := "10";
    inst(1).d     := inst_in(1).d;
    inst(1).dc    := inst_in(1).d(15 downto 0);
    inst(1).xc    := "000";
    inst(1).c     := '0';
    comp_ill      := "00";
    buff_comp_ill := '0';

    buffer_inst.d   := (others => '0');
    buffer_inst.lpc := "00";
    buffer_inst.xc  := "000";
    buffer_inst.c   := '0';
    buffer_first    := '0';
    buffer_sec      := '0';
    buffer_third    := '0';

    rvc_pc_t(2 downto 1) := rvc_pc(2 downto 1);
    if single_issue /= 0 then
      rvc_pc_t(2) := '0';
    end if;
    case rvc_pc_t(2 downto 1) is
      -- Decode at 0x00
      when "00" =>
        -- Not Compressed instruction in 0
        if inst_in(0).d(1 downto 0) = "11" then
          inst(0)     := inst_in(0);
          inst(0).lpc := "00";
          valid(0)    := '1';
          if single_issue /= 0 then
            inst(0).lpc := rvc_pc(2) & '0';
          end if;
          -- Not Compressed instruction in 1
          if single_issue = 0 then
            if inst_in(1).d(1 downto 0) = "11" then
              inst(1)     := inst_in(1);
              inst(1).lpc := "10";
              buffer_sec  := '1';
              valid(1)    := '1';
            -- Compressed instruction in 1
            else
              inst(1).d       := inst_c2e;
              inst(1).dc      := inst_in(1).d(15 downto 0);
              inst(1).lpc     := "10";
              valid(1)        := '1';
              inst(1).c       := '1';
              comp_ill(1)     := inst_c2xc;
              -- Generate unaligned flag
              buffer_inst.lpc := "11";
              if inst_in(1).d(17 downto 16) = "11" then
                buffer_third               := '1';
                buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
                unaligned                  := '1';
              else
                -- One more compressed left, buffer it
                buffer_third   := '1';
                buffer_inst.d  := inst_c3e;
                buffer_inst.dc := inst_in(1).d(31 downto 16);
                buffer_inst.c  := '1';
                buff_comp_ill  := inst_c3xc;
              end if;  -- unaligned flag
            end if;  -- instruction in 1
          end if;  -- single_issue = 0
        -- Compressed instruction in 0
        else
          inst(0).d   := inst_c0e;
          inst(0).dc  := inst_in(0).d(15 downto 0);
          inst(0).c   := '1';
          inst(0).lpc := "00";
          comp_ill(0) := inst_c0xc;
          valid(0)    := '1';
          if single_issue /= 0 then
            hold        := '1';
            inst(0).lpc := rvc_pc(2) & '0';
          end if;
          if single_issue = 0 then
            -- Not Compressed instruction in 0 1/2
            if inst_in(0).d(17 downto 16) = "11" then
              inst(1).d       := inst_in(1).d(15 downto 0) & inst_in(0).d(31 downto 16);
              inst(1).lpc     := "01";
              valid(1)        := '1';
              -- Generate unaligned flag
              buffer_inst.lpc := "11";
              if inst_in(1).d(17 downto 16) = "11" then
                buffer_third               := '1';
                buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
                unaligned                  := '1';
              else
                -- One more compressed left, buffer it
                buffer_third   := '1';
                buffer_inst.d  := inst_c3e;
                buffer_inst.dc := inst_in(1).d(31 downto 16);
                buffer_inst.c  := '1';
                buff_comp_ill  := inst_c3xc;
              end if;  -- unaligned flag

            -- Compressed instruction in 0 1/2
            else
              --inst(1).d(15 downto 0) := inst_in(0).d(31 downto 16);
              inst(1).d   := inst_c1e;
              inst(1).dc  := inst_in(0).d(31 downto 16);
              inst(1).c   := '1';
              inst(1).lpc := "01";
              comp_ill(1) := inst_c1xc;
              valid(1)    := '1';
              -- More valid instructions
              if inst_in(1).d(1 downto 0) = "11" then
                --one 32-bit instruction left buffer it
                buffer_third               := '1';
                buffer_inst.d(31 downto 0) := inst_in(1).d(31 downto 0);
                buffer_inst.lpc            := "10";
              else
                -- Two more valid instructions left
                hold := '1';
                npc  := "100";
              end if;
            end if;  -- instruction in 0 1/2
          end if;  -- single_issue = 0
        end if;  -- instruction in 0

      -- Decode at 0x02
      when "01" =>
        -- Not Compressed instruction in 0 1/2
        if inst_in(0).d(17 downto 16) = "11" then
          inst(0).d       := inst_in(1).d(15 downto 0) & inst_in(0).d(31 downto 16);
          inst(0).lpc     := "01";
          valid(0)        := '1';
          -- Generate unaligned flag
          buffer_inst.lpc := "11";
          if single_issue /= 0 then
            -- Unaligned for single issue
            valid(0)      := '0';
            unaligned     := '1';
            buffer_third  := '1';
            buffer_inst.d(15 downto 0) := inst_in(0).d(31 downto 16);
            buffer_inst.lpc := rvc_pc(2) & '1';
            -- Generate instruction lpc in case it is a mexc on lsb of unaligned instruction.
            inst(0).lpc := rvc_pc(2) & '1';
          end if;
          if single_issue = 0 then
            if inst_in(1).d(17 downto 16) = "11" then
              buffer_third               := '1';
              buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
              unaligned                  := '1';
            else
              buffer_sec  := '1';
              inst(1).d   := inst_c3e;
              inst(1).dc  := inst_in(1).d(31 downto 16);
              inst(1).c   := '1';
              inst(1).lpc := "11";
              comp_ill(1) := inst_c3xc;
              valid(1)    := '1';
            end if;  -- unaligned flag
          end if; -- single_issue = 0
        -- Compressed instruction in 0 1/2
        else
          inst(0).d   := inst_c1e;
          inst(0).dc  := inst_in(0).d(31 downto 16);
          inst(0).c   := '1';
          inst(0).lpc := "01";
          comp_ill(0) := inst_c1xc;
          valid(0)    := '1';
          if single_issue /= 0 then
            inst(0).lpc := rvc_pc(2) & '1';
          end if;
          if single_issue = 0 then
            -- Not Compressed instruction in 1
            if inst_in(1).d(1 downto 0) = "11" then
              buffer_sec  := '1';
              inst(1)     := inst_in(1);
              inst(1).lpc := "10";
              valid(1)    := '1';
            -- Compressed instruction in 1
            else
              inst(1).d       := inst_c2e;
              inst(1).dc      := inst_in(1).d(15 downto 0);
              inst(1).c       := '1';
              inst(1).lpc     := "10";
              comp_ill(1)     := inst_c2xc;
              valid(1)        := '1';
              -- Generate unaligned flag
              buffer_inst.lpc := "11";
              if inst_in(1).d(17 downto 16) = "11" then
                buffer_third               := '1';
                buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
                unaligned                  := '1';
              else
                -- Only one compressed inst left buffer it
                buffer_third  := '1';
                --buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
                buffer_inst.d  := inst_c3e;
                buffer_inst.dc := inst_in(1).d(31 downto 16);
                buffer_inst.c  := '1';
                buff_comp_ill  := inst_c3xc;
              end if;  -- unaligned flag
            end if;  -- instruction in 1
          end if;  -- single_issue = 0
        end if;  -- instruction in 0 1/2

      -- Decode at 0x04
      when "10" =>
        if single_issue = 0 then
          -- Not Compressed instruction in 1
          if inst_in(1).d(1 downto 0) = "11" then
            inst(0)                    := inst_in(1);
            inst(0).lpc                := "10";
            valid(0)                   := '1';
            buffer_first               := '1';
            buffer_inst.d(31 downto 0) := inst_in(1).d(31 downto 0);
            buffer_inst.lpc            := "10";
          -- Compressed instruction in 1
          else
            -- Generate unaligned flag
            if inst_in(1).d(17 downto 16) = "11" then
              inst(0).d                  := inst_c2e;
              inst(0).dc                 := inst_in(1).d(15 downto 0);
              inst(0).c                  := '1';
              inst(0).lpc                := "10";
              comp_ill(0)                := inst_c2xc;
              valid(0)                   := '1';
              buffer_third               := '1';
              buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
              unaligned                  := '1';
              buffer_inst.lpc            := "11";
            else
              buffer_sec  := '1';
              inst(0).d   := inst_c2e;
              inst(0).dc  :=  inst_in(1).d(15 downto 0);
              inst(0).c   := '1';
              inst(0).lpc := "10";
              comp_ill(0) := inst_c2xc;
              valid(0)    := '1';
              inst(1).d   := inst_c3e;
              inst(1).dc  := inst_in(1).d(31 downto 16);
              inst(1).c   := '1';
              inst(1).lpc := "11";
              comp_ill(1) := inst_c3xc;
              valid(1)    := '1';
            end if;  -- unaligned flag
          end if;  -- instruction in 1
        else
          null;
        end if; -- single_issue = 0

      -- Decode at 0x06
      when others =>
        if single_issue = 0 then
          -- Generate unaligned flag
          buffer_inst.lpc := "11";
          if inst_in(1).d(17 downto 16) = "11" then
            valid                      := "00";
            buffer_third               := '1';
            buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
            unaligned                  := '1';
          else
            valid(0)       := '1';
            inst(0).c      := '1';
            comp_ill(0)    := inst_c3xc;
            buffer_first   := '1';
            buffer_inst.d  := inst_c3e;
            buffer_inst.dc := inst_in(1).d(31 downto 16);
            buffer_inst.c  := '1';
            buff_comp_ill  := inst_c3xc;
          end if;  -- unaligned flag

          -- Generate instruction information in case it is a memory exception
          -- on lsb part of unaligned inst
          inst(0).d   := inst_c3e;
          inst(0).dc  := inst_in(1).d(31 downto 16);
          inst(0).lpc := "11";
        else
          null;
        end if;  -- single_issue = 0
    end case;  -- pc_in(2 downto 1)

    if valid_in = '0' then
      valid := "00";
    end if;
    if single_issue /= 0 then
      valid(1)     := '0';
      buffer_first := '0';
      buffer_sec   := '0';
    end if;

    -- Output Signals
    inst_out         := inst;
    unaligned_out    := unaligned and valid_in;
    valid_out        := valid;
    hold_out         := hold and valid_in;
    npc_out          := npc;
    buffer_sec_out   := buffer_sec and valid_in;
    buffer_third_out := buffer_third and valid_in;
    buffer_first_out := buffer_first and valid_in;
  end;

  -- PC validity check
  -- Returns '1' if pc has to be used as an operand.
  function pc_valid(inst : word) return std_ulogic is
    variable op  : opcode_type := inst(6 downto 0);
    -- Non-constant
    variable vpc : std_ulogic  := '0';
  begin
    case op is
      when AUIPC | OP_JAL | OP_JALR => vpc := '1';
      when others => null;
    end case;

    return vpc;
  end;

  -- Immediate generation and validity check
  -- Note that ZI-Type (CSRI) are not done here since CSRs have separate handling.
  procedure imm_gen(inst_in   : in  word;
                    valid_out : out std_ulogic;
                    imm_out   : out wordx;
                    bj_imm    : out wordx) is
    variable op     : opcode_type := inst_in(6 downto 0);
    variable funct5 : funct5_type := inst_in(31 downto 27);
    variable funct3 : funct3_type := inst_in(14 downto 12);
    -- Non-constant
    variable vimm   : std_ulogic  := '0';
    variable imm    : wordx       := (others => '0');
    variable i_imm  : wordx       := (others => inst_in(31));
    variable s_imm  : wordx       := (others => inst_in(31));
    variable b_imm  : wordx       := (others => inst_in(31));
    variable u_imm  : wordx       := (others => inst_in(31));
    variable j_imm  : wordx       := (others => inst_in(31));
    variable si_imm : wordx       := (others => '0');
  begin
    -- Instruction Type Immediate --------------------------------------------
    -- I-Type
    i_imm(11 downto 0) := inst_in(31 downto 20);
    -- S-Type
    s_imm(11 downto 0) := inst_in(31 downto 25) & inst_in(11 downto 7);
    -- B-Type
    b_imm(12 downto 0) := inst_in(31) & inst_in(7) & inst_in(30 downto 25) & inst_in(11 downto 8) & '0';
    -- U-Type
    u_imm(31 downto 0) := inst_in(31 downto 12) & zerox(11 downto 0);
    -- J-Type
    j_imm(20 downto 0) := inst_in(31) & inst_in(19 downto 12) & inst_in(20) & inst_in(30 downto 21) & '0';
    -- SI-Type (shift amount)
    si_imm(5 downto 0) := inst_in(25 downto 20);

    case op is
      when LUI | AUIPC =>
        imm   := u_imm;
        vimm  := '1';
      when OP_JAL =>
        imm   := j_imm;
        vimm  := '1';
      when OP_JALR | OP_LOAD | OP_LOAD_FP =>
        imm   := i_imm;
        vimm  := '1';
      when OP_IMM =>
        if funct3 = I_SLLI or funct3 = I_SRLI then -- I_SRAI
          imm := si_imm;
        else
          imm := i_imm;
        end if;
        vimm  := '1';
      when OP_BRANCH =>
        imm   := b_imm;
        vimm  := '1';
      when OP_STORE | OP_STORE_FP =>
        imm   := s_imm;
        vimm  := '1';
      when OP_IMM_32 =>
        if inst_in(12) = '0' then -- I_ADDIW
          imm := i_imm;
        else
          imm := si_imm;
        end if;
        vimm  := '1';

      when others =>
    end case;

    bj_imm := b_imm;
    if inst_in(2) = '1' then
      bj_imm := j_imm;
    end if;

    valid_out := vimm;
    imm_out   := imm;
  end;

  -- There is no need to check for ext_h etc, since
  -- any such instructions would fail at decode.

  function is_csr(inst : std_logic_vector) return boolean is
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
  begin
    return opcode = OP_SYSTEM and funct3(1 downto 0) /= "00";
  end;

  -- Assumes it is already known that inst is a CSR instruction.
  function csr_read_only(inst : std_logic_vector) return boolean is
    variable rfa1   : rfatype     := inst(19 downto 15);
    variable funct3 : funct3_type := inst(14 downto 12);
  begin
    -- CSRR[S/C] and rs1=x0, or CSRR[S/C]I and imm=0, ie read-only?
    return rfa1 = "00000" and
           (funct3 = I_CSRRS  or funct3 = I_CSRRC or
            funct3 = I_CSRRSI or funct3 = I_CSRRCI);
  end;

  -- Assumes it is already known that inst is a CSR instruction.
  function csr_write_only(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable funct3 : funct3_type := inst(14 downto 12);
  begin
    -- CSRRW/CSRRWI and rd=x0, ie write-only?
    return rd = "00000" and (funct3 = I_CSRRW or funct3 = I_CSRRWI);
  end;

  function is_sfence_vma(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return opcode = OP_SYSTEM and funct7 = F7_SFENCE_VMA and
           funct3 = "000"     and rd     = "00000";
  end;

  function is_hfence_vvma(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return opcode = OP_SYSTEM and funct7 = F7_HFENCE_VVMA and
           funct3 = "000"     and rd     = "00000";
  end;

  function is_hfence_gvma(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return opcode = OP_SYSTEM and funct7 = F7_HFENCE_GVMA and
           funct3 = "000"     and rd     = "00000";
  end;

  function is_hlv(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return opcode = OP_SYSTEM and funct3 = "100" and funct7(0) = '0';
  end;

  function is_hsv(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return opcode = OP_SYSTEM and funct3 = "100" and funct7(0) = '1';
  end;

  function is_hlsv(inst : std_logic_vector) return std_logic is
  begin
    return to_bit(is_hlv(inst) or is_hsv(inst));
  end;

  function is_fence_i(inst : std_logic_vector) return boolean is
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
  begin
    return opcode = OP_FENCE and funct3 = I_FENCE_I;
  end;

  function is_diag(inst : std_logic_vector) return boolean is
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return opcode = OP_CUSTOM0 and funct7 = zerow(funct7'range);
  end;

  function is_diag_store(inst : std_logic_vector) return boolean is
    variable funct3 : funct3_type := inst(14 downto 12);
  begin
    return get_hi(funct3) = '1';
  end;

  function is_cbo(inst : std_logic_vector) return boolean is
    variable opcode   : opcode_type := inst( 6 downto  0);
    variable funct3   : funct3_type := inst(14 downto 12);
  begin
    return opcode = OP_FENCE and funct3 = I_CBO;
  end;

  -- These (is_fpu...) functions must be used on the unpacked version
  -- of an instruction, i.e. they can not be used on a compressed
  -- instruction directly.
  -- FPU instruction that does not touch memory?
  function is_fpu(inst : word) return boolean is
    variable opcode : opcode_type := inst(6 downto 0);
  begin
    case opcode is
      when OP_FP     |
           OP_FMADD  |
           OP_FMSUB  |
           OP_FNMADD |
           OP_FNMSUB => return true;
      when others    => return false;
    end case;
  end;

  -- FPU instruction that touches memory?
  function is_fpu_mem(inst : word) return boolean is
    variable opcode : opcode_type := inst(6 downto 0);
  begin
    return opcode = OP_LOAD_FP or opcode = OP_STORE_FP;
  end;

  -- FPU double precision store?
  function is_fpu_fsd(inst : word) return boolean is
    variable opcode : opcode_type := inst(6 downto 0);
    variable funct3 : funct3_type := inst(14 downto 12);
  begin
    return opcode = OP_STORE_FP and funct3 /= "010";
  end;

  -- FPU instruction with data from integer pipeline?
  function is_fpu_from_int(inst : word) return boolean is
    variable opcode : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
  begin
    case opcode is
      when OP_FP =>
        case funct5 is
        when R_FCVT_S_W |
             R_FMV_W_X  => return true;
        when others     => return false;
        end case;
      when OP_LOAD_FP   => return true;
      when others       => return false;
    end case;
  end;

  -- FPU instruction with FPU destination register?
  function is_fpu_rd(inst : word) return boolean is
    variable opcode : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
  begin
    case opcode is
      when OP_FP =>
        case funct5 is
        when R_FADD     |
             R_FSUB     |
             R_FMINMAX  |
             R_FSGN     |
             R_FCVT_S_D |
             R_FMUL     |
             R_FCVT_S_W |
             R_FMV_W_X  |
             R_FDIV     |
             R_FSQRT    => return true;
        when others     => return false;
        end case;
      when OP_LOAD_FP   |
           OP_FMADD     |
           OP_FMSUB     |
           OP_FNMADD    |
           OP_FNMSUB    => return true;
      when others       => return false;
    end case;
  end;

  -- FPU instruction can modify FPU state (including flags)?
  function is_fpu_modify(inst : word) return boolean is
    variable opcode : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
  begin
    case opcode is
      when OP_FP =>
        case funct5 is
        when R_FADD     |
             R_FSUB     |
             R_FMINMAX  |
             R_FSGN     |
             R_FCVT_S_D |
             R_FMUL     |
             R_FCVT_W_S |
             R_FCMP     |
             R_FCVT_S_W |
             R_FMV_W_X  |
             R_FDIV     |
             R_FSQRT    => return true;
        when others     => return false;
        end case;
      when OP_LOAD_FP   |
           OP_FMADD     |
           OP_FMSUB     |
           OP_FNMADD    |
           OP_FNMSUB    => return true;
      when others       => return false;
    end case;
  end;

  -- Rd register validity check
  -- Returns '1' if the instruction has a valid integer rd field.
  function rd_gen(inst : word) return std_ulogic is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
    variable rd     : rfatype     := inst(11 downto 7);
    -- Non-constant
    variable wreg   : std_ulogic  := '1';
  begin
    case op is
      when OP_BRANCH   |
           OP_STORE    |
           OP_STORE_FP | OP_LOAD_FP |
           OP_FMADD    | OP_FMSUB   |
           OP_FNMSUB   | OP_FNMADD   => wreg := '0';
      when OP_FP =>
        case funct5 is
          when R_FCVT_W_S | R_FMV_X_W |  -- Latter includes R_FCLASS
               R_FCMP                =>
            null;  -- These have integer results.
          when others                => wreg := '0';
        end case;

      -- These do not really need to be here, since their
      -- encodings already have rd=0.
      when OP_SYSTEM   =>
        -- Only CSR and hlv/hsv among SYSTEM instructions have rd.
        if not is_csr(inst) and not is_hlv(inst) then
          wreg := '0';
        end if;
      when OP_FENCE => wreg := '0';
      when OP_CUSTOM0 =>
        if not is_diag(inst) or is_diag_store(inst) then
          wreg := '0';
        end if;

      when others =>
    end case;

    if rd = "00000" then
      wreg := '0';
    end if;

    return wreg;
  end;

  -- Rs1 register validity check
  -- Returns the rs1 field in case it is valid and integer, otherwise x0.
  function rs1_gen(inst : word) return rfatype is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct5 : funct5_type := inst(31 downto 27);
    -- Non-constant
    variable rs1    : rfatype     := inst(19 downto 15);
    variable vreg   : std_ulogic  := '1';
  begin
    case op is
      when LUI       | AUIPC    | OP_JAL |
           OP_FMADD  | OP_FMSUB |
           OP_FNMSUB | OP_FNMADD      => vreg := '0';
      when OP_SYSTEM =>
        -- I_CSRRWI, I_CSRRSI, I_CSRRCI
        if is_csr(inst) and funct3(2) = '1' then
          vreg  := '0';
        end if;
        -- Only CSR, sfence.vma, hfence.v/gvma, and hvl/hsv among SYSTEM
        -- instructions have rs1.
        if not is_csr(inst) and not is_sfence_vma(inst) and
           not is_hfence_vvma(inst) and not is_hfence_gvma(inst) and
           not is_hlv(inst) and not is_hsv(inst) then
          vreg  := '0';
        end if;
      when OP_FP     =>
        case funct5 is
          when R_FCVT_S_W | R_FMV_W_X =>
          when others                 => vreg := '0';
        end case;

      when others =>
    end case;

    -- This is used to make sure we do not accidentally
    -- use forwarding when there is not a source register at all.
    -- Relies on destination r0 being marked as invalid (.rdv = '0')!
    if vreg = '0' then
      rs1 := "00000";
    end if;

    return rs1;
  end;

  -- Rs2 register validity check
  -- Returns the rs2 field in case it is valid and integer, otherwise x0.
  function rs2_gen(inst : word) return rfatype is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
    -- Non-constant
    variable rs2    : rfatype     := inst(24 downto 20);
    variable vreg   : std_ulogic  := '1';
  begin
    case op is
      when OP_REG | OP_BRANCH | OP_STORE | OP_32 =>
      when OP_SYSTEM =>
        -- Only sfence.vma, sfence.vma, hfence.v/gvma, and hsv among SYSTEM
        -- instructions have rs2.
        if not is_sfence_vma(inst) and
           not is_hfence_vvma(inst) and not is_hfence_gvma(inst) and
           not is_hsv(inst) then
          vreg                := '0';
        end if;
      when OP_AMO =>
        case funct5 is
          when R_LR   => vreg := '0';
          when others =>
        end case;
      when OP_CUSTOM0 =>
        if not is_diag(inst) then
          vreg := '0';
        end if;
      when others     => vreg := '0';
    end case;

    -- This is used to make sure we do not accidentally
    -- use forwarding when there is not a source register at all.
    -- Relies on destination r0 being marked as invalid (.rdv = '0')!
    if vreg = '0' then
      rs2 := "00000";
    end if;

    return rs2;
  end;

  -- Must the instruction be handled in lane 0?
  function for_lane0(active : extension_type; lane : lane_select;
                     inst   : word) return boolean is
    variable ext_zbc   : integer  := is_enabled(active, x_zbc);
    variable ext_zbkc  : integer  := is_enabled(active, x_zbkc);
    variable ext_h     : integer  := is_enabled(active, x_h);
    variable op     : opcode_type := inst(6 downto 0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    if lane.memory = 0 and
       (op = OP_STORE    or op = OP_LOAD    or
        op = OP_STORE_FP or op = OP_LOAD_FP or
        op = OP_AMO      or op = OP_FENCE) then
      return true;
    end if;

    if lane.memory = 0 and is_sfence_vma(inst) then
      return true;
    end if;

    -- Hypervisor instructions are either fence, load, or store.
    if lane.memory = 0 and ext_h /= 0 and
       (is_hfence_vvma(inst) or is_hfence_gvma(inst) or
        is_hlv(inst) or is_hsv(inst)) then
      return true;
    end if;

    -- Custom diagnostic cache instruction
    if lane.memory = 0 and is_diag(inst) then
      return true;
    end if;

     -- Writes to PMPCFG lock bits, DFEATURESEN or SATP require the pipeline to be flushed.
     -- To simplify PC logic, such CSR writes always issue alone, but
     -- this also ensures that all CSR accesses are in the proper lane
     -- (used to be lane 0 (like fences), but may now be changed).
    if lane.csr = 0 and is_csr(inst) then
      return true;
    end if;

    -- While floating point load/store need to be in lane 0, and are taken
    -- care of above, the other FPU instructions may also be forced here.
    if lane.fpu = 0 and is_fpu(inst) then
      return true;
    end if;

    -- Only one CLMUL machinery - and it is in the early lane0 ALU.
    -- R_CLMULR is not actually valid for ext_zbkc, but that does not matter here.
    if (ext_zbc = 1 or ext_zbkc = 1) and op = OP_REG and funct7 = F7_MINMAXCLMUL and
      (funct3 = R_CLMUL or funct3 = R_CLMULH or funct3 = R_CLMULR) then
      return true;
    end if;

    return false;
  end;

  -- Must the instruction be handled in lane 1?
  function for_lane1(lane : lane_select;
                     inst : word) return boolean is
    variable op : opcode_type := inst(6 downto 0);
  begin
    if lane.branch = 1 and (op = OP_JAL or op = OP_JALR or op = OP_BRANCH) then
      return true;
    end if;

     -- Writes to PMPCFG lock bits, DFEATURESEN or SATP require the pipeline to be flushed.
     -- To simplify PC logic, such CSR writes always issue alone, but
     -- this also ensures that all CSR accesses are in the proper lane
     -- (used to be lane 0 (like fences), but may now be changed).
    if lane.csr = 1 and is_csr(inst) then
      return true;
    end if;

    -- While floating point load/store need to be in lane 0, the other
    -- FPU instructions may be forced here instead.
    if lane.fpu = 1 and is_fpu(inst) then
      return true;
    end if;

    return false;
  end;

  -- Categories of dependent/similar CSRs
  -- Bits  Meaning
  -- 0-3   category number, each category counted as "same" CSR for RaW
  -- 5     do not dual-issue write to CSR
  -- 6     memory access following write to CSR must be delayed
  -- 7     pipeline flush may be required by write to CSR, so hold issue
  -- 8     no FPU instructions under way together with this
  -- 9     no new FPU instructions until this completes
  --
  -- Note that PMPCFG gets "overlapping" things set here. This is mainly to
  -- clarify for any future improvements to the code.
  --
  -- Note that many CSRs that might seem to require various bits set here
  -- do not, since they cannot affect anything in the same CPU privilege mode.
  -- Any changes to such CSRs will require a privilege change to do anything,
  -- and thus there will be a pipeline flush anyway.
  function csr_category(addr : csratype) return std_logic_vector is
    -- Non-constant
    variable category : std_logic_vector(9 downto 0) := (others => '0');
  begin
    -- RaW category dependencies
    case addr is
      -- Writes to any in the numbered category affect all.

      when CSR_MSTATUS | CSR_MSTATUSH | CSR_SSTATUS | CSR_USTATUS =>
        category(3 downto 0) := x"1";
      when CSR_MIE     | CSR_SIE      | CSR_UIE     | CSR_HIE     |
           CSR_MIDELEG | CSR_SIDELEG  | CSR_HIDELEG | -- =>
           CSR_MIP     | CSR_SIP      | CSR_UIP     | CSR_HIP     |
           CSR_HVIP    | CSR_VSIP     =>
        category(3 downto 0) := x"2";
      when CSR_FFLAGS  | CSR_FRM | CSR_FCSR =>
        category(3 downto 0) := x"4";

      -- Writes to the first in the numbered category affect the rest.
      -- But putting them all in a single category should not matter for performance.

      -- If a write to any of these causes a timer to be disabled, it would be strange
      -- if two immediately following reads of that timer give different results.
      -- Changes to these can be handled by holding the pipeline, since it should not
      -- matter if the writes are somewhat slow.
      when CSR_MCOUNTINHIBIT  | CSR_MHPMEVENT3     |
           CSR_MHPMEVENT4     | CSR_MHPMEVENT5     | CSR_MHPMEVENT6     | CSR_MHPMEVENT7     |
           CSR_MHPMEVENT8     | CSR_MHPMEVENT9     | CSR_MHPMEVENT10    | CSR_MHPMEVENT11    |
           CSR_MHPMEVENT12    | CSR_MHPMEVENT13    | CSR_MHPMEVENT14    | CSR_MHPMEVENT15    |
           CSR_MHPMEVENT16    | CSR_MHPMEVENT17    | CSR_MHPMEVENT18    | CSR_MHPMEVENT19    |
           CSR_MHPMEVENT20    | CSR_MHPMEVENT21    | CSR_MHPMEVENT22    | CSR_MHPMEVENT23    |
           CSR_MHPMEVENT24    | CSR_MHPMEVENT25    | CSR_MHPMEVENT26    | CSR_MHPMEVENT27    |
           CSR_MHPMEVENT28    | CSR_MHPMEVENT29    | CSR_MHPMEVENT30    | CSR_MHPMEVENT31    |
           CSR_MHPMEVENT3H    |
           CSR_MHPMEVENT4H    | CSR_MHPMEVENT5H    | CSR_MHPMEVENT6H    | CSR_MHPMEVENT7H    |
           CSR_MHPMEVENT8H    | CSR_MHPMEVENT9H    | CSR_MHPMEVENT10H   | CSR_MHPMEVENT11H   |
           CSR_MHPMEVENT12H   | CSR_MHPMEVENT13H   | CSR_MHPMEVENT14H   | CSR_MHPMEVENT15H   |
           CSR_MHPMEVENT16H   | CSR_MHPMEVENT17H   | CSR_MHPMEVENT18H   | CSR_MHPMEVENT19H   |
           CSR_MHPMEVENT20H   | CSR_MHPMEVENT21H   | CSR_MHPMEVENT22H   | CSR_MHPMEVENT23H   |
           CSR_MHPMEVENT24H   | CSR_MHPMEVENT25H   | CSR_MHPMEVENT26H   | CSR_MHPMEVENT27H   |
           CSR_MHPMEVENT28H   | CSR_MHPMEVENT29H   | CSR_MHPMEVENT30H   | CSR_MHPMEVENT31H   |
      -- Writes to M<x> should be immediately visible in <x>.
      -- The <x> cannot be written at all.
           CSR_MCYCLE         | CSR_MINSTRET       | CSR_MHPMCOUNTER3   |
           CSR_MHPMCOUNTER4   | CSR_MHPMCOUNTER5   | CSR_MHPMCOUNTER6   | CSR_MHPMCOUNTER7   |
           CSR_MHPMCOUNTER8   | CSR_MHPMCOUNTER9   | CSR_MHPMCOUNTER10  | CSR_MHPMCOUNTER11  |
           CSR_MHPMCOUNTER12  | CSR_MHPMCOUNTER13  | CSR_MHPMCOUNTER14  | CSR_MHPMCOUNTER15  |
           CSR_MHPMCOUNTER16  | CSR_MHPMCOUNTER17  | CSR_MHPMCOUNTER18  | CSR_MHPMCOUNTER19  |
           CSR_MHPMCOUNTER20  | CSR_MHPMCOUNTER21  | CSR_MHPMCOUNTER22  | CSR_MHPMCOUNTER23  |
           CSR_MHPMCOUNTER24  | CSR_MHPMCOUNTER25  | CSR_MHPMCOUNTER26  | CSR_MHPMCOUNTER27  |
           CSR_MHPMCOUNTER28  | CSR_MHPMCOUNTER29  | CSR_MHPMCOUNTER30  | CSR_MHPMCOUNTER31  |
           CSR_MCYCLEH        | CSR_MINSTRETH      | CSR_MHPMCOUNTER3H  |
           CSR_MHPMCOUNTER4H  | CSR_MHPMCOUNTER5H  | CSR_MHPMCOUNTER6H  | CSR_MHPMCOUNTER7H  |
           CSR_MHPMCOUNTER8H  | CSR_MHPMCOUNTER9H  | CSR_MHPMCOUNTER10H | CSR_MHPMCOUNTER11H |
           CSR_MHPMCOUNTER12H | CSR_MHPMCOUNTER13H | CSR_MHPMCOUNTER14H | CSR_MHPMCOUNTER15H |
           CSR_MHPMCOUNTER16H | CSR_MHPMCOUNTER17H | CSR_MHPMCOUNTER18H | CSR_MHPMCOUNTER19H |
           CSR_MHPMCOUNTER20H | CSR_MHPMCOUNTER21H | CSR_MHPMCOUNTER22H | CSR_MHPMCOUNTER23H |
           CSR_MHPMCOUNTER24H | CSR_MHPMCOUNTER25H | CSR_MHPMCOUNTER26H | CSR_MHPMCOUNTER27H |
           CSR_MHPMCOUNTER28H | CSR_MHPMCOUNTER29H | CSR_MHPMCOUNTER30H | CSR_MHPMCOUNTER31H |
           -- Affect
           CSR_CYCLE          | CSR_INSTRET        | CSR_HPMCOUNTER3    |
           CSR_HPMCOUNTER4    | CSR_HPMCOUNTER5    | CSR_HPMCOUNTER6    | CSR_HPMCOUNTER7    |
           CSR_HPMCOUNTER8    | CSR_HPMCOUNTER9    | CSR_HPMCOUNTER10   | CSR_HPMCOUNTER11   |
           CSR_HPMCOUNTER12   | CSR_HPMCOUNTER13   | CSR_HPMCOUNTER14   | CSR_HPMCOUNTER15   |
           CSR_HPMCOUNTER16   | CSR_HPMCOUNTER17   | CSR_HPMCOUNTER18   | CSR_HPMCOUNTER19   |
           CSR_HPMCOUNTER20   | CSR_HPMCOUNTER21   | CSR_HPMCOUNTER22   | CSR_HPMCOUNTER23   |
           CSR_HPMCOUNTER24   | CSR_HPMCOUNTER25   | CSR_HPMCOUNTER26   | CSR_HPMCOUNTER27   |
           CSR_HPMCOUNTER28   | CSR_HPMCOUNTER29   | CSR_HPMCOUNTER30   | CSR_HPMCOUNTER31   |
           CSR_CYCLEH         | CSR_INSTRETH       | CSR_HPMCOUNTER3H   |
           CSR_HPMCOUNTER4H   | CSR_HPMCOUNTER5H   | CSR_HPMCOUNTER6H   | CSR_HPMCOUNTER7H   |
           CSR_HPMCOUNTER8H   | CSR_HPMCOUNTER9H   | CSR_HPMCOUNTER10H  | CSR_HPMCOUNTER11H  |
           CSR_HPMCOUNTER12H  | CSR_HPMCOUNTER13H  | CSR_HPMCOUNTER14H  | CSR_HPMCOUNTER15H  |
           CSR_HPMCOUNTER16H  | CSR_HPMCOUNTER17H  | CSR_HPMCOUNTER18H  | CSR_HPMCOUNTER19H  |
           CSR_HPMCOUNTER20H  | CSR_HPMCOUNTER21H  | CSR_HPMCOUNTER22H  | CSR_HPMCOUNTER23H  |
           CSR_HPMCOUNTER24H  | CSR_HPMCOUNTER25H  | CSR_HPMCOUNTER26H  | CSR_HPMCOUNTER27H  |
           CSR_HPMCOUNTER28H  | CSR_HPMCOUNTER29H  | CSR_HPMCOUNTER30H  | CSR_HPMCOUNTER31H =>
        category(3 downto 0) := x"5";


      -- Changes to TSELECT will cause TDATAn to return different things.
      when CSR_TSELECT   |
           -- Affects
           CSR_TDATA1    | CSR_TDATA2    | CSR_TDATA3 | CSR_TINFO =>
        category(3 downto 0) := x"6";

      -- The setting in PMPCFG affects values read from PMPADDR.
      when CSR_PMPCFG0   | CSR_PMPCFG1   | CSR_PMPCFG2   | CSR_PMPCFG3   |
           -- Affect
           CSR_PMPADDR0  | CSR_PMPADDR1  | CSR_PMPADDR2  | CSR_PMPADDR3  |
           CSR_PMPADDR4  | CSR_PMPADDR5  | CSR_PMPADDR6  | CSR_PMPADDR7  |
           CSR_PMPADDR8  | CSR_PMPADDR9  | CSR_PMPADDR10 | CSR_PMPADDR11 |
           CSR_PMPADDR12 | CSR_PMPADDR13 | CSR_PMPADDR14 | CSR_PMPADDR15 =>
        category(3 downto 0) := x"7";

      when others => null;
        -- No category if low nybble is 0.
    end case;

    -- Some CSR writes need to issue alone (see also below).
    case addr is
      -- Changes to interrupt enable must not dual-issue, to prevent interrupt
      -- traps from being taken in a pair with such a CSR write.
      -- VSSTATUS
      --   Should not be included here since writes to it are only done in
      --   modes that are not affected by it!
      when CSR_MSTATUS  | CSR_SSTATUS | CSR_USTATUS | CSR_HSTATUS |
           CSR_MIE      | CSR_SIE     | CSR_UIE     | CSR_HIE     |
           CSR_HGEIE    |
           -- Changing delegation can also enable/disable an interrupt.
           CSR_MIDELEG  | CSR_SIDELEG | CSR_HIDELEG |
           -- A paired instruction faulting would get the wrong exception vector.
           CSR_MTVEC    | CSR_STVEC   | CSR_VSTVEC  | CSR_UTVEC =>
        category(5) := '1';
      when others => null;
    end case;

    -- For some CSR writes, nothing more should leave the issue stage
    -- until the writes are completed.
    -- DCSR would be one such, but can only be used from the DSU.
    case addr is
      -- Changes to these may force pipeline flush since the next instruction
      -- fetch may be required to behave differently.
      -- Writes to PMPCFG lock bits may change execute protection.
      when CSR_PMPCFG0 | CSR_PMPCFG1 | CSR_PMPCFG2 | CSR_PMPCFG3 |
           CSR_SATP    |         -- Changes memory mapping.
           CSR_VSATP   |         -- Changes memory mapping.
           CSR_HGATP   |         -- Changes memory mapping.
           CSR_MISA    |         -- May turn on/off extensions and change MXL.
           CSR_MSTATUS |         -- May turn on/off FPU and extensions.
           CSR_SSTATUS |
           -- VSSTATUS
           --   Should not be included here since writes to it are only done in
           --   modes that are not affected by it!
           -- HSTATUS
           --   Should not be included here since writes to it cannot affect
           --   the immediately following instructions.
           CSR_MENVCFG | CSR_HENVCFG | CSR_SENVCFG |
           CSR_FEATURES | CSR_FEATURESH | CSR_CCTRL | CSR_FT => -- Can do just about anything.
        category(7) := '1';
        -- To simplify PC logic, ensure that CSR writes that may require pipeline flush
        -- always issue alone (and put them always in the same pipe).
        category(5) := '1';
      when others => null;
    end case;

    -- Some CSR writes may not pair if issued in lane 0, since the behaviour
    -- may change for the very next instruction.
    -- Known examples are mret, sret and uret.
    -- Currently those are handled directly in dual_issue_check(), but
    -- perhaps they should be here instead?

    -- Some CSR writes affect following memory accesses.
    -- The following access must be delayed!
    --
    -- In the case of the FS/XS, FPU and/or other extension instructions may
    -- be enabled/disabled. Affects whether the next instruction is illegal!
    case addr is
      -- MSTATUS
      --   MBE     - switch endianness of following load/store
      --   MXR     - affects following load (allow/disable read from executable space)
      --   SUM     - affects following load/store (allow/disable access to user mode pages)
      --   MPRV    - affects following load/store (physical or virtual addressing in M-mode)
      --   FS/XS   - turning off FPU/ext could cause next instruction to fault
      -- SSTATUS
      --   MXR     - affects following load (allow/disable read from executable space)
      --   SUM     - affects following load/store (allow/disable access to user mode pages)
      --   FS/XS   - turning off FPU/ext which could cause next instruction to fault
      -- HSTATUS
      --   VSBE    - switch endianness of following hypervisor load/store
      --   SPVP    - affects privilege level of following hypervisor load/store
      --   HU      - affects following hypervisor load/store (allow/disable such in user mode)
      -- VSSTATUS
      --   Should not be included here since writes to it are only done in
      --   modes that are not affected by it!
      when CSR_MSTATUS   | CSR_MSTATUSH  | CSR_SSTATUS   | CSR_HSTATUS   |
           -- PMPCFG/PMPADDR affect memory protection.
           CSR_PMPCFG0   | CSR_PMPCFG1   | CSR_PMPCFG2   | CSR_PMPCFG3   |
           CSR_PMPADDR0  | CSR_PMPADDR1  | CSR_PMPADDR2  | CSR_PMPADDR3  |
           CSR_PMPADDR4  | CSR_PMPADDR5  | CSR_PMPADDR6  | CSR_PMPADDR7  |
           CSR_PMPADDR8  | CSR_PMPADDR9  | CSR_PMPADDR10 | CSR_PMPADDR11 |
           CSR_PMPADDR12 | CSR_PMPADDR13 | CSR_PMPADDR14 | CSR_PMPADDR15 |
           -- Special case!
           -- MIE/SIE/UIE can disable interrupts and the interrupt code relies on
           -- there being no load/store directly following that.
           CSR_MIE       | CSR_SIE       | CSR_UIE        | CSR_HIE      |
           CSR_HGEIE     |
           -- Changing delegation can also enable/disable an interrupt.
           CSR_MIDELEG | CSR_SIDELEG | CSR_HIDELEG =>
        category(6) := '1';
      when others => null;
    end case;

    -- FPU instructions in the pipeline must complete before the FPU flags
    -- can be read or written. Then the write needs to happen before any other
    -- FPU instructions may complete and modify them.
    -- For now, no FPU instructions are allowed in the pipeline together with
    -- any accesses to the FPU related CSRs.
    case addr is
      when CSR_FFLAGS | CSR_FCSR =>
        category(8) := '1';
      when others => null;
    end case;

    -- Writes to some CSR:s must take effect before a new FPU instruction is allowed.
    -- (FPU rounding mode can be read at any time.)
    case addr is
      when CSR_FFLAGS | CSR_FCSR | CSR_FRM =>
        category(9) := '1';
      when others => null;
    end case;

    return category;
  end;

  function csr_addr(inst : word) return csratype is
    variable addr : csratype := inst(31 downto 20);
  begin
    return addr;
  end;

  -- Dual issue check logic
  -- Check if instructions can be issued in the same clock cycle on both lanes.
  procedure dual_issue_check(active      : in  extension_type;
                             lane        : in  lane_select;
                             instx_in    : in  iword_pair_type;
                             valid_in    : in  std_logic_vector;
                             lbranch_dis : in  std_ulogic;
                             lalu_dis    : in  std_ulogic;
                             dual_dis    : in  std_ulogic;
                             step_in     : in  std_ulogic;
                             lalu_in     : in  std_logic_vector;
                             mexc        : in  std_ulogic;
                             rd0_in      : in  rfatype;
                             rdv0_in     : in  std_ulogic;
                             rd1_in      : in  rfatype;
                             rdv1_in     : in  std_ulogic;
                             lane0_out   : out std_ulogic;
                             issue_out   : out std_logic_vector) is
    variable ext_zbc          : integer  := is_enabled(active, x_zbc);
    variable ext_zbkc         : integer  := is_enabled(active, x_zbkc);
    variable ext_f            : integer  := is_enabled(active, x_f);
    variable ext_h            : integer  := is_enabled(active, x_h);
    variable single_issue     : integer  := is_enabled(active, x_single_issue);
    variable late_alu         : integer  := is_enabled(active, x_late_alu);
    variable late_branch      : integer  := is_enabled(active, x_late_branch);
    variable one              : integer  := 1 - single_issue;
    constant lanes            : std_logic_vector(0 to valid_in'length - 1) := (others => '0');
    subtype  lanes_type      is std_logic_vector(valid_in'range);
    type     word_lanes_type is array (lanes'range) of word;
    type     rfa_lanes_type  is array (lanes'range) of rfatype;
    type     op_lanes_t      is array (lanes'range) of opcode_type;
    type     f3_lanes_t      is array (lanes'range) of funct3_type;
    type     f7_lanes_t      is array (lanes'range) of funct7_type;
    -- Non-constant
    variable inst_in   : word_lanes_type;
    variable conflict  : std_ulogic := '0';
    variable rfa1      : rfa_lanes_type;
    variable rfa2      : rfa_lanes_type;
    variable rd        : rfa_lanes_type;
    variable rs1_valid : lanes_type;
    variable rs2_valid : lanes_type;
    variable rd_valid  : lanes_type;
    variable opcode    : op_lanes_t;
    variable funct3    : f3_lanes_t;
    variable funct7    : f7_lanes_t;
    variable lane0     : std_ulogic := '0';
    variable opcode_0  : opcode_type;  -- These are needed to have
    variable opcode_1  : opcode_type;  --  locally static object
    variable funct7_1  : funct7_type;  --  subtypes for case statements.
  begin
    assert valid_in'left  >= valid_in'right and
           valid_in'left   = lalu_in'left   and
           valid_in'left   = issue_out'left and
           valid_in'length = lalu_in'length
      report "Bad type" severity failure;
    for i in lanes'range loop
      inst_in(i)  := instx_in(i).d;
      opcode(i)   := inst_in(i)(6 downto 0);
      funct3(i)   := inst_in(i)(14 downto 12);
      funct7(i)   := inst_in(i)(31 downto 25);
      rfa1(i)     := rs1_gen(inst_in(i));
      rfa2(i)     := rs2_gen(inst_in(i));
      rd_valid(i) := rd_gen(inst_in(i));
      rd(i)       := inst_in(i)(11 downto 7);
    end loop;

    -- Create locally static objects
    opcode_0 := opcode(0);
    opcode_1 := opcode(one);
    funct7_1 := funct7(one);


    -- If both instructions are valid, inst(0) is always the older instruction,
    -- hence only that one should be issued if a dependency exists between the
    -- pair.
    case opcode_0 is
      when OP_LOAD    | OP_STORE | OP_AMO |
           OP_LOAD_FP | OP_STORE_FP =>
        if for_lane0(active, lane, inst_in(one)) then
          conflict := '1';
        end if;

      -- Custom0 instruction is diagnostic load/store
      when OP_CUSTOM0 =>
        if for_lane0(active, lane, inst_in(one)) then
          conflict := '1';
        end if;

      when OP_JAL | OP_JALR =>
        -- Raise conflict since we will have a control flow change, so the instruction
        -- after the jal/jalr would not be valid anyway.
        conflict := '1';

      when OP_BRANCH =>
        if late_branch /= 0 then
          if not (opcode(1) = OP_REG or opcode(1) = OP_32 or opcode(1) = OP_IMM_32 or opcode(1) = OP_IMM
                  or opcode(1) = LUI) then
            conflict := '1';
          end if;
        end if;

        if late_branch = 0 then
          case opcode_1 is
            when OP_BRANCH =>
              -- Raise conflict since only one branch unit is available.
              conflict := '1';
            when OP_JAL | OP_JALR =>
              -- Raise conflict since they use the same lane.
              conflict := '1';
            when OP_SYSTEM =>
              if lane.csr = 1 and is_csr(inst_in(one)) then
                -- Raise conflict since they use the same lane.
                conflict := '1';
              end if;

            when OP_FP | OP_FMADD | OP_FMSUB | OP_FNMADD | OP_FNMSUB | OP_STORE_FP | OP_LOAD_FP =>
              -- In order for combinatorial branch resolution in execute stage
              -- to not affect FPU, prevent dual issue of FPU with branches.
              conflict := '1';

            when others =>

          end case; -- opcode(1)
        end if;

        if mexc = '1' then
          -- Don't allow dual issue when instruction after branch is exception.
          conflict := '1';
        end if;

      when OP_SYSTEM =>
        if funct3(0) = "000" then
          -- ecall/ebreak/uret/sret/mret
          -- Raise conflict since we will have a control flow change at the
          -- exception stage, so the next istruction will not be valid.
          conflict := '1';
          if inst_in(0)(22 downto 20) = "101" and funct7(0) = F7_WFI then
            -- In case of wfi instruction, do not raise conflict.
            conflict := '0';
          end if;
        end if;
        if is_csr(inst_in(0)) then
          -- For some CSR writes, raise conflict since the execution of the
          -- next instruction may depend on it.
          if not csr_read_only(inst_in(0)) and
             csr_category(csr_addr(inst_in(0)))(5) = '1' then
            conflict := '1';
          end if;
          -- Do not allow CSR writes to FPU flags or rounding mode to
          -- pair with an FPU instruction.
          if is_fpu(inst_in(one)) and
             csr_category(csr_addr(inst_in(0)))(8) = '1' then
            conflict := '1';
          end if;
          -- CSR accesses use the same pipeline as some other things.
          -- (These checks include other CSR accesses.)
          if lane.csr = 0 and for_lane0(active, lane, inst_in(one)) then
            -- Raise conflict since they use the same lane.
            conflict := '1';
          end if;
          if lane.csr = 1 and for_lane1(lane, inst_in(one)) then
            -- Raise conflict since they use the same lane.
            conflict := '1';
          end if;
          if opcode(one) = OP_SYSTEM then
            -- uret/sret/mret depend on UEPC/SEPC/MEPC, so they may not pair
            -- with a write to those in lane 0.
            if funct3(one) = "000" then
              case funct7_1 is
                when F7_MRET =>
                  if csr_addr(inst_in(0)) = CSR_MEPC then
                    conflict := '1';
                  end if;
                when F7_SRET =>
                  if csr_addr(inst_in(0)) = CSR_SEPC then
                    conflict := '1';
                  end if;
                when F7_URET =>
                  if csr_addr(inst_in(0)) = CSR_UEPC then
                    conflict := '1';
                  end if;
                when others =>
              end case;
            end if;
          end if;
        end if;
        if is_sfence_vma(inst_in(0)) then
          -- Raise conflict since next instruction might be wrong!
          conflict := '1';
        end if;
        -- Hypervisor extension
        if ext_h /= 0 then
          -- Hypervisor load/store, which must be in lane 0.
          -- Raise conflict when the other instructions wants to be as well.
          if is_hlv(inst_in(0)) or is_hsv(inst_in(0)) then
            if for_lane0(active, lane, inst_in(one)) then
              conflict := '1';
            end if;
          end if;

          -- Raise conflict since next instruction might be wrong!
          if is_hfence_vvma(inst_in(0)) or is_hfence_gvma(inst_in(0)) then
            if is_hlv(inst_in(one)) or is_hsv(inst_in(one)) then
              conflict := '1';
            end if;
          end if;
        end if;

      when OP_FENCE =>
        -- Raise conflict
        conflict := '1';

      when OP_REG | OP_32 =>
        if funct7(0) = F7_MUL then
          case opcode_1 is
            when OP_REG | OP_32 =>
              if funct7(one) = F7_MUL then
                -- Mul/Div Operation
                -- Raise conflict since we have only one Mul/Div Unit
                conflict := '1';
              end if;

            when others =>
          end case; -- opcode(1)
        end if;

      -- There can be only one.
      when OP_FP     |
           OP_FMADD  | OP_FMSUB  |
           OP_FNMADD | OP_FNMSUB =>
        -- Do not allow CSR accesses to FPU flags to
        -- pair with an FPU instruction.
        if is_csr(inst_in(one)) and csr_category(csr_addr(inst_in(one)))(8) = '1' then
          conflict := '1';
        end if;
        -- FPU operations use the same pipeline as some other things.
        -- (These checks include other FPU operations.)
        if lane.fpu = 0 and for_lane0(active, lane, inst_in(one)) then
          -- Raise conflict since they use the same lane.
          conflict := '1';
        end if;
        if lane.fpu = 1 and for_lane1(lane, inst_in(one)) then
          -- Raise conflict since they use the same lane.
          conflict := '1';
        end if;

      when others =>
    end case; -- opcode(0)

    -- Multi-cycle operations in execute stage do not currently work.
    -- Fortunately, for now that is only divide/remainder and FPU->IU.
    -- This also prevents the problem of division issued together with a branch
    -- because we don't want branch to combinatorially affect ex_hold_pc signal
    -- in execute stage.
    for i in lanes'range loop
      if (opcode(i) = OP_REG or  opcode(i) = OP_32) and
         funct7(i) = F7_MUL and funct3(i)(2) = '1' then   -- DIV[U][W]/REM[U][W]
        conflict := '1';
      end if;
    end loop;
    if ext_f /= 0 then
      for i in lanes'range loop
        -- For now, never pair FPU with anything.
        if is_fpu(inst_in(i)) or is_fpu_mem(inst_in(i)) then
          conflict := '1';
        end if;
      end loop;
    end if;

    if ext_zbc = 1 or ext_zbkc = 1 then
      -- Only one CLMUL machinery.
      -- To avoid complications, always issue on its own.
      -- R_CLMULR is not actually valid for ext_zbkc, but that does not matter here.
      for i in lanes'range loop
        if opcode(i) = OP_REG and funct7(i) = F7_MINMAXCLMUL and
           (funct3(i) = R_CLMUL or funct3(i) = R_CLMULH or funct3(i) = R_CLMULR) then
          conflict := '1';
        end if;
      end loop;
    end if;

    -- This is the same as for pipe 0 above.
    -- Writes to some CSRs require the pipeline to be flushed. To simplify PC logic,
    -- ensure that such CSR writes always issue alone.
    -- There are also other reasons for enforcing single-issue of CSR writes.
    if is_csr(inst_in(one)) and not csr_read_only(inst_in(one)) and
       csr_category(csr_addr(inst_in(one)))(5) = '1' then
      conflict := '1';
    end if;

    -- For CSRs that may cause pipeline flush, ensure that they are available
    -- in lane 0 (even with swap), to make later flush code able to only check
    -- there for new PC.
    -- Such CSR must also execute alone, which is already handled above,
    -- since all category(7) CSRs are also in category(5).
    if lane.csr = 1 then
      for i in lanes'range loop
        if valid_in(i) = '1' and is_csr(inst_in(i)) and
           not csr_read_only(inst_in(i))            and
           csr_category(csr_addr(inst_in(i)))(7) = '1' then
          -- If in lane 0, it will execute since it is first.
          -- Otherwise, it will only execute if there is no valid instruction in lane 0.
          if i = 0 or valid_in(0) = '0' then
            lane0 := '1';
          end if;
        end if;
      end loop;
    end if;

    -- Instruction register dependency:

    -- case # 1
    -- | INSTA x1, 0(x2)  |
    -- | INSTB x4, x1, x3 |
    -- If rd of the first instruction is valid and the other instruction
    -- uses it as a source operand, raise conflict. Do not raise conflict in
    -- scenarios covered by forwarding or late alu.

    -- case # 2
    -- | INSTA x1, 0(x2)  |
    -- | INSTB x1, x4, x3 |
    -- If rd of the first istruction is valid and the other instruction
    -- uses it as a valid destination register, raise conflict. Do not raise
    -- conflict if the second instruction is a STORE/LOAD, since we will forward
    -- the operand to the memory. It could be resolved after the exception stage
    -- as soon as we have the validity of both instruction and we could decide
    -- which value to write.

    if rd_valid(0) = '1' then
      -- case # 1
      if rd(0) = rfa1(one) or rd(0) = rfa2(one) then
        case opcode_1 is
          when OP_LOAD   | OP_LOAD_FP |  -- Load (address)
               OP_SYSTEM |               -- System or CSR
               OP_FENCE  |               -- Fence
               OP_FP     |               -- Floating point operation with integer input
               OP_JALR =>                -- Jump and link register (this is resolved early)
            conflict   := '1';

          -- Store in second lane (only in case of Address Generation)
          when OP_STORE | OP_STORE_FP | OP_AMO =>
            if rd(0) = rfa1(one) then
              conflict := '1';
            end if;

            -- Right now it is assumed that multiplier is always 2 stage
            if (opcode(0) = OP_REG or opcode(0) = OP_32) and funct7(0) = F7_MUL then
              if rd(0) = rfa2(one) then
                conflict := '1';
              end if;
            end if;

          when OP_CUSTOM0 =>
            conflict   := '1';

          -- Branch in second lane (if late branch feature is disabled)
          when OP_BRANCH =>
            if lbranch_dis = '1' or late_branch = 0 then
              conflict := '1';
            end if;

          -- ALU operation in second lane (if late ALU feature is disabled)
          when OP_REG | OP_32 | OP_IMM_32 | OP_IMM | LUI | AUIPC =>
            if lalu_dis = '1' or late_alu = 0 then
              conflict := '1';
            end if;
             -- Instruction in RA has been issued to late ALUs
            if ((rd0_in = rfa1(0) or rd0_in = rfa2(0)) and lalu_in(0) = '1' and rdv0_in = '1') or
               ((rd1_in = rfa1(0) or rd1_in = rfa2(0)) and lalu_in(one) = '1' and rdv1_in = '1') then
              conflict := '1';
            end if;
            -- MUL/DIV in any case
            if (opcode(one) = OP_REG or opcode(one) = OP_32) and funct7(one) = F7_MUL then
              conflict := '1';
            end if;

          when others =>
            -- FMADD, FMSUB, FNMSUB, FNMADD - No integer source
            -- JAL - No source
            -- The rest are not available:
            -- custom-0
            -- 48b
            -- custom-1
            -- 64b
            -- reserved-10101_11
            -- custom-2
            -- 48b
            -- reserved-11010_11
            -- reserved-11101_11
            -- custom-3
            -- >= 80b
            null;
        end case;

        -- Values from CSRs will not be available until in the exception stage,
        -- at the same time as the late ALU, so it is not possible for another
        -- instruction in the same pair to access it.
        if is_csr(inst_in(0)) then
          conflict := '1';
        end if;
      end if;

      -- case # 2
      if rd_valid(one) = '1' and rd(0) = rd(one) then
        -- Generate conflict flag in case of
        -- LOAD and other ALU instruction.
        -- JAL/JALR instruction would be placed in lane1,
        -- thus no conflict arises.
        if opcode(one) = OP_LOAD or opcode(0) = OP_LOAD or
           opcode(one) = OP_AMO  or opcode(0) = OP_AMO  or
           is_hlv(inst_in(one))  or is_hlv(inst_in(0)) then
          conflict := '1';
        end if;
        -- Generate conflict in case one of the
        -- instructions is a CSR.
        if is_csr(inst_in(0)) or is_csr(inst_in(one)) then
          conflict := '1';
        end if;
      end if;
    end if;

    lane0_out := lane0;

    -- If only one instructions is valid, we could issue it without any check.
    issue_out  := valid_in;

    -- If dual issue capability is disabled, raise conflict.
    if dual_dis = '1' then
      conflict := '1';
    end if;

    -- If instruction step, raise conflict.
    if step_in = '1' then
      conflict := '1';
    end if;

    if conflict = '1' and all_1(valid_in) then
      issue_out(one) := '0';
    end if;
  end;

  -- Dual issue swap logic, generate swap flag
  procedure dual_issue_swap(active   : in  extension_type;
                            lane     : in  lane_select;
                            inst_in  : in  iword_pair_type;
                            valid_in : in  std_logic_vector;
                            swap_out : out std_ulogic) is
    -- Non-constant
    variable swap : std_logic := '0';
  begin
    if for_lane1(lane, inst_in(0).d) and valid_in(0) = '1' then
      swap := '1';
    end if;

    if for_lane0(active, lane, inst_in(1).d) and
       (valid_in(0) = '0' or not for_lane0(active, lane, inst_in(0).d)) then
      swap := '1';
    end if;

    swap_out := swap;
  end;

  -- Pad or extend pc to XLEN
  function pc2xlen(pc : std_logic_vector) return wordx is
    -- Non-constant
    variable data : wordx;
  begin
    data           := (others => get_hi(pc));
    data(pc'range) := pc;

    return data;
  end;

  -- Generate instruction address misaligned flag
  function inst_addr_misaligned(active : extension_type;
                                pc     : std_logic_vector) return boolean is
    variable ext_c    : integer := is_enabled(active, x_c);
    -- Non-constant
    variable naligned : boolean := false;
  begin
    -- Unaligned instruction if compressed instructions are supported!
    if ext_c = 0 then
      if pc(1 downto 0) /= "00" then
        naligned := true;
      end if;
    end if;

    return naligned;
  end;

  -- Return whether the two functional units are equivalent.
  -- Or rather that they have at least one bit in common.
  function v_fusel_eq(fusel1 : fuseltype; fusel2 : fuseltype) return boolean is
  begin
    return (fusel1 and fusel2) /= NONE;
  end;

--  -- Jump Unit for JAL and JALR instructions
--  procedure jump_unit(ctrl_in   : in  pipeline_ctrl_type;
--                      imm_in    : in  wordx;
--                      ras_in    : in  nv_ras_out_type;
--                      rf1       : in  wordx;
--                      flush_in  : in  std_ulogic;
--                      jump_out  : out std_ulogic;
--                      mem_jump  : out std_ulogic;
--                      xc_out    : out std_ulogic;
--                      cause_out : out cause_type;
--                      tval_out  : out wordx;
--                      addr_out  : out pctype) is
--    -- Non-constant
--    variable op1         : wordx;
--    variable target      : wordx;
--    variable jump_xc     : std_ulogic;
--    variable memjump_xc  : std_ulogic;
--    variable jump        : std_ulogic := '0';
--    variable mem_jumpt   : std_ulogic;
--    variable tval        : wordx;
--  begin
--    -- Jump in case of:
--    -- * Valid JALR instruction and ras_in.hit = '0' or address mismatch
--
--    -- Operations:
--    -- * JALR   -> rs1 + sign_extend(imm)
--    target       := std_logic_vector(signed(rf1) + signed(imm_in));
--
--    -- Generate Jump Signal
--    if ctrl_in.valid = '1' and v_fusel_eq(ctrl_in.fusel, JALR) and flush_in = '0' then
--        jump     := '1';
--    end if;
--
--
--    mem_jumpt := '0';
--
--    -- Setting the least-significat bit to zero.
--    target(0)    := '0';
--
--    -- Generate Exception Signal due to Address Misaligned.
--    jump_xc := '0';
--    if jump = '1' and inst_addr_misaligned(active, target) then
--      jump_xc    := '1';
--    end if;
--
--    -- Decouple jump and memjump_xc to not affect the critical path.
--    memjump_xc   := '0';
--    if mem_jumpt = '1' and inst_addr_misaligned(active, target) then
--      memjump_xc := '1';
--    end if;
--
--    xc_out       := jump_xc or memjump_xc;
--    cause_out    := XC_INST_ADDR_MISALIGNED;  -- Only valid when xc_out.
--    addr_out     := to_addr(target);
--    tval_out     := target;
--    jump_out     := jump and not jump_xc;
--    mem_jump     := mem_jumpt and not memjump_xc;
--  end;
--
--  -- Resolve Unconditional Jumps
--  procedure ujump_resolve(ctrl_in   : in  pipeline_ctrl_type;
--                          target_in : in  pctype;
--                          next_in   : in  pctype;
--                          taken_in  : in  std_ulogic;
--                          hit_in    : in  std_ulogic;
--                          xc_out    : out std_ulogic;
--                          cause_out : out cause_type;
--                          tval_out  : out wordx;
--                          jump_out  : out std_ulogic;
--                          addr_out  : out pctype) is
--    variable inst   : word       := ctrl_in.inst;
--    -- Non-constant
--    variable target : pctype     := target_in;
--    variable xc     : std_ulogic := '0';
--    variable jump   : std_ulogic := '0';
--    variable mis    : std_ulogic := '0';
--  begin
--    -- Jump here in case of:
--    --        * taken_in = 0 -> We did not get a hit from prediction
--    --        * taken_in = 1 and not JAL -> We get an alias
--
--    -- Generate Misprediction Signal due to wrong instruction.
--    if (taken_in and hit_in and ctrl_in.valid) = '1' and ctrl_in.xc = '0' then
--      if inst(6 downto 0) /= OP_JAL and inst(6 downto 0) /= OP_BRANCH then
--        mis     := '1';
--        target  := next_in;
--      end if;
--    end if;
--
--    -- Generate Jump Signal
--    if ctrl_in.valid = '1' and ctrl_in.xc = '0' and inst(6 downto 0) = OP_JAL and (taken_in and hit_in) = '0' then
--      jump      := '1';
--    end if;
--
--    -- Generate Exception Signal
--    if jump = '1' and inst_addr_misaligned(active, target) then
--      xc        := '1';
--    end if;
--
--    xc_out      := xc;
--    cause_out   := XC_INST_ADDR_MISALIGNED;  -- Only valid when xc_out.
--    tval_out    := pc2xlen(target);
--    addr_out    := target;
--    jump_out    := (jump or mis) and not xc;
--  end;
--
--  -- Resolve Early Branch in Decode Stage.
--  procedure branch_resolve(ctrl_in    : in  pipeline_ctrl_type;
--                           taken_in   : in  std_ulogic;
--                           hit_in     : in  std_ulogic;
--                           imm_in     : in  wordx;
--                           valid_out  : out std_ulogic;
--                           branch_out : out std_ulogic;
--                           taken_out  : out std_ulogic;
--                           hit_out    : out std_ulogic;
--                           xc_out     : out std_ulogic;
--                           cause_out  : out cause_type;
--                           next_out   : out pctype;
--                           addr_out   : out pctype) is
--    -- Non-constant
--    variable valid   : std_ulogic := '0';
--    variable xc      : std_ulogic := '0';
--    variable pc      : wordx;
--    variable target  : wordx;
--    variable nextpc  : pctype;
--    variable brancho : std_ulogic;
--  begin
--    -- Signal to branch in decode stage in case we got a taken from bht
--    -- but the btb does not have the target address where to branch.
--    brancho     := taken_in and not hit_in;
--
--    -- Check if branch
--    if ctrl_in.valid = '1' and ctrl_in.xc = '0' and v_fusel_eq(ctrl_in.fusel, BRANCH) then
--      valid     := '1';
--    end if;
--
--    -- Operations:
--    -- * BRANCH -> pc + sign_extend(imm)
--    pc          := pc2xlen(ctrl_in.pc);
--    target      := std_logic_vector(signed(pc) + signed(imm_in));
--    nextpc      := npc_adder(ctrl_in.pc, ctrl_in.comp);
--
--    -- Generate Exception Signal
--    if valid = '1' and taken_in = '1' and inst_addr_misaligned(active, target) then
--      xc        := '1';
--    end if;
--
--    -- Generate Output
--    addr_out    := to_addr(target);
--    next_out    := nextpc;
--    valid_out   := valid;
--    branch_out  := brancho and valid;
--    -- Taken signal for later stage of the pipeline
--    taken_out   := taken_in and valid;
--    xc_out      := xc;
--    cause_out   := XC_INST_ADDR_MISALIGNED;  -- Only valid when xc_out.
--    hit_out     := hit_in;
--  end;
--
--  procedure branch_misc(lane      : in  lane_select;
--                        ctrl_in   : in  pipeline_ctrl_type;
--                        taken_in  : in  std_ulogic;
--                        hit_in    : in  std_ulogic;
--                        imm_in    : in  wordx_pair_type;
--                        swap      : in  std_logic;
--                        valid_out : out std_ulogic;
--                        taken_out : out std_ulogic;
--                        hit_out   : out std_ulogic;
--                        xc_out    : out std_ulogic;
--                        cause_out : out cause_type;
--                        next_out  : out pctype;
--                        addr_out  : out pctype) is
--    -- Non-constant
--    variable valid  : std_ulogic := '0';
--    variable xc     : std_ulogic := '0';
--    variable pc     : wordx;
--    variable target_l0 : wordx;
--    variable target_l1 : wordx;
--    variable target : wordx;
--    variable nextpc : pctype;
--  begin
--    -- Check if branch
--    if ctrl_in.valid = '1' and ctrl_in.xc = '0' and v_fusel_eq(ctrl_in.fusel, BRANCH) then
--      valid := '1';
--    end if;
--
--    -- Operations:
--    -- * BRANCH -> pc + sign_extend(imm)
--    pc     := pc2xlen(ctrl_in.pc);
--
--    target_l0 := std_logic_vector(signed(pc) + signed(imm_in(0)));
--    target_l1 := std_logic_vector(signed(pc) + signed(imm_in(1)));
--
--    if lane.branch = 0 then
--      target := target_l0;
--      if swap = '1' then
--        target := target_l1;
--      end if;
--    else
--      target := target_l1;
--      if swap = '1' then
--        target := target_l0;
--      end if;
--    end if;
--
--    nextpc := npc_adder(ctrl_in.pc, ctrl_in.comp);
--
--    -- Generate Exception Signal
--    if valid = '1' and taken_in = '1' and inst_addr_misaligned(active, target) then
--      xc := '1';
--    end if;
--
--    -- Generate Output
--    addr_out  := to_addr(target);
--    next_out  := nextpc;
--    valid_out := valid;
--    taken_out := taken_in and valid;
--    xc_out    := xc;
--    cause_out := XC_INST_ADDR_MISALIGNED;  -- Only valid when xc_out.
--    hit_out   := hit_in;
--  end;

  -- Branch Unit
  procedure branch_unit(active    : in  extension_type;
                        op1_in    : in  wordx;
                        op2_in    : in  wordx;
                        valid_in  : in  std_ulogic;
                        branch_in : in  std_ulogic;
                        ctrl_in   : in  word3;
                        addr_in   : in  std_logic_vector;
                        npc_in    : in  std_logic_vector;
                        taken_in  : in  std_ulogic;
                        pc_in     : in  std_logic_vector;
                        valid_out : out std_ulogic;
                        mis_out   : out std_ulogic;
                        addr_out  : out std_logic_vector;
                        xc_out    : out std_ulogic;
                        cause_out : out cause_type;
                        tval_out  : out wordx) is
    subtype pctype is std_logic_vector(addr_in'range);
    -- Non-constant
    variable taken  : std_ulogic := '0';
    variable xc     : std_ulogic := '0';
    variable val    : std_ulogic := '0';
    variable tval   : wordx      := pc2xlen(addr_in);
    variable op1    : wordx1;
    variable op2    : wordx1;
    variable equal  : std_ulogic;
    variable less   : std_ulogic;
    variable target : pctype     := addr_in;
  begin
    -- Signed and unsigned comparison
    op1         := (not ctrl_in(1) and get_hi(op1_in)) & op1_in;
    op2         := (not ctrl_in(1) and get_hi(op2_in)) & op2_in;
    if signed(op1) < signed(op2) then
      less      := '1';
    else
      less      := '0';
    end if;

    if op1 = op2 then
      equal     := '1';
    else
      equal     := '0';
    end if;

    case ctrl_in is
      when B_BEQ          => taken :=     equal;
      when B_BNE          => taken := not equal;
      when B_BLT | B_BLTU => taken :=     less;
      when B_BGE | B_BGEU => taken := not less;
      when others =>
    end case;

    -- Raise valid signal
    if valid_in = '1' and branch_in = '1' then
      val       := '1';
    end if;

    -- Generate Output Branch Signal
    --                        taken
    --                  0       |       1
    --          0     0(xx)         1(addr_in)
    -- dir
    --          1    1(pc+4)          0(xx)

    -- Generate Target Address
    if  val = '1' and taken = '0' and taken_in = '1' then
      target    := npc_in;
    end if;

    -- Raise exception if branch taken and address is misaligned.
    if taken = '1' and val = '1' and inst_addr_misaligned(active, target) then
      xc        := '1';
    end if;

    valid_out   := val;
    mis_out     := taken xor taken_in;
    addr_out    := target;
    xc_out      := xc;
    cause_out   := XC_INST_ADDR_MISALIGNED;  -- Only valid when xc_out.
    tval_out    := tval;
  end;

    -- Instruction Buffer Control Logic
  procedure buffer_ic(active         : in  extension_type;
                      r_d_buff_valid : in  std_ulogic;
                      valid_in       : in  std_logic_vector;
                      dvalid_in      : in  std_logic_vector;
                      buffer_third   : in  std_ulogic;
                      buffer_sec     : in  std_ulogic;
                      buffer_first   : in  std_ulogic;
                      unaligned      : in  std_ulogic;
                      issue_in       : in  std_logic_vector;
                      hold_pc        : out std_ulogic;
                      buff_valid     : out std_ulogic) is
    variable single_issue : integer := is_enabled(active, x_single_issue);
  begin
    buff_valid := '0';
    hold_pc    := '0';

    if buffer_third = '1' then
      -- A third instruction or unaligned instruction
      -- in order to buffer all other instructions must be consumed
      if ((valid_in(0) = '1' and issue_in(0) = '1') or (valid_in(0) = '0')) and
         ((valid_in(1) = '1' and issue_in(1) = '1') or (valid_in(1) = '0')) then
        buff_valid := '1';
      end if;

      if valid_in(1) = '1' and issue_in(1) = '0' then
        hold_pc    := '1';
      end if;

      if r_d_buff_valid = '1' and single_issue = 0  then
        -- If buffer is valid also that means there will be at
        -- least two instructions left to issue, so don't buffer.
        buff_valid       := '0';
        hold_pc          := '1';
        if unaligned = '1' then
          -- If unaligned is asserted there might be less than three instructions.
          if dvalid_in(0) = '0' then
            buff_valid   := '1';
            hold_pc      := '0';
          elsif dvalid_in(0) = '1' and dvalid_in(1) = '0' then
            if issue_in(1) = '1' then
              buff_valid := '1';
              hold_pc    := '0';
            end if;
          end if;
          -- In all other cases buffer needs to be hold so first statement applies.
        end if;
      end if;

    end if;

    if buffer_sec = '1' and issue_in(1) = '0' then
      -- Buffer second instructions, when buffer_sec is asserted second instruction
      -- is always valid.
      buff_valid := '1';
    end if;

    if r_d_buff_valid = '1' and buffer_sec = '1' then
      if issue_in(1) = '0' then
        -- If buffer is also valid that means two instructions will left on
        -- regular queue don't buffer.
        buff_valid := '0';
        hold_pc    := '1';
      else
        buff_valid := '1';
      end if;
    end if;

    if r_d_buff_valid = '1' and buffer_first = '1' then
      if issue_in(1) = '0' then
        buff_valid := '1';
      end if;
    end if;


    if r_d_buff_valid = '1' and buffer_third = '0' and single_issue /= 0 then
      hold_pc := '1';
    end if;

  end;

  -- Hardwire status CSR bits
  function tie_status(active : extension_type;
                      status : csr_status_type; misa : wordx) return csr_status_type is
    variable h_en    : boolean         := misa(h_ctrl) = '1';
    variable ext_f   : integer         := is_enabled(active, x_f);
    variable mode_u  : integer         := is_enabled(active, x_mode_u);
    variable mode_s  : integer         := is_enabled(active, x_mode_s);
    -- Non-constant
    variable mstatus : csr_status_type := status;
  begin
    -- Big-endian not supported
    mstatus.sbe  := '0';
    mstatus.ube  := '0';

    if mode_s = 0 then
      mstatus.sxl  := "00";
      mstatus.spp  := '0';
      mstatus.mxr  := '0';
      mstatus.sum  := '0';
      mstatus.tvm  := '0';
      mstatus.tsr  := '0';
      mstatus.sie  := '0';
      mstatus.spie := '0';
    end if;
    if mode_u = 0 then
      mstatus.uxl  := "00";
      mstatus.mprv := '0';
      mstatus.tw   := '0';
    end if;
    if not h_en then
      mstatus.mpv  := '0';
      mstatus.gva  := '0';
    end if;
    if ext_f = 0 then
      mstatus.fs  := "00";
    end if;

    -- Unsupported privilege mode - default to user-mode.
    if status.mpp = "10" or (mode_s = 0 and status.mpp = "01") or (mode_u = 0 and status.mpp = "00") then
      if mode_u /= 0 then
        mstatus.mpp  := "00";
      else
        mstatus.mpp  := "11";
      end if;
    end if;

    return mstatus;
  end;

  -- Hardwire hpmevent CSR bits
  function tie_hpmevent(active      : extension_type;
                        hpmevent_in : hpmevent_type; misa : wordx) return hpmevent_type is
    variable h_en         : boolean       := misa(h_ctrl) = '1';
    variable ext_sscofpmf : integer       := is_enabled(active, x_sscofpmf);
    variable mode_u       : integer       := is_enabled(active, x_mode_u);
    variable mode_s       : integer       := is_enabled(active, x_mode_s);
    -- Non-constant
    variable hpmevent     : hpmevent_type := hpmevent_in;
  begin
    if ext_sscofpmf = 0 then
      hpmevent.minh := '0';
    end if;
    if ext_sscofpmf = 0 or mode_s = 0 then
      hpmevent.sinh := '0';
    end if;
    if ext_sscofpmf = 0 or mode_u = 0 then
      hpmevent.uinh := '0';
    end if;
    if ext_sscofpmf = 0 or not h_en then
      hpmevent.vsinh := '0';
      hpmevent.vuinh := '0';
    end if;


    return hpmevent;
  end;

  -- Generate data address misaligned flag
  function data_addr_misaligned(addr : std_logic_vector;
                                size : word2) return boolean is
    -- Non-constant
    variable naligned : boolean := false;
  begin
    -- Generate not aligned flag.
    case size is
      when SZHALF =>
        if addr(0) /= '0' then
          naligned := true;
        end if;
      when SZWORD =>
        if addr(1 downto 0) /= "00" then
          naligned := true;
        end if;
      when SZDBL =>
        if addr(2 downto 0) /= "000" then
          naligned := true;
        end if;
      when others => -- byte
    end case;

    return naligned;
  end;

--  -- Generate Next PC with adder, depending on whether compressed or not.
--  function npc_adder(pc   : pctype;
--                     comp : std_ulogic) return pctype is
--    -- Non-constant
--    variable op2 : integer;
--    variable npc : pctype;
--  begin
--    op2   := 4;
--    if comp = '1' then
--      op2 := 2;
--    end if;
--
--    npc   := uadd(pc, op2);
--
--    return to_addr(npc);
--  end;

--  -- Generate default next PC for fetch mux
--  function npc(active : extension_type;
--               r_f_pc : pctype) return pctype is
--    variable single_issue : integer := is_enabled(active, x_single_issue);
--    variable pc2downto1   : word2   := r_f_pc(2 downto 1);
--    -- Non-constant
--    variable npc        : pctype;
--    variable op2        : integer;
--  begin
--    case pc2downto1 is
--      when "10"   =>
--        op2 := 4;
--      when "11"   =>
--        op2 := 2;
--      when "01"   =>
--        op2 := 6;
--      when others =>
--        op2 := 8;
--    end case;
--
--    if single_issue /= 0 then
--      op2 := 4;
--      if pc2downto1(0) = '1' then
--        op2 := 2;
--      end if;
--    end if;
--
--    npc := uadd(r_f_pc, op2);
--
--    return to_addr(npc);
--  end;

  -- Functional unit select
  function fusel_gen(active : extension_type;
                     inst   : word) return fuseltype is
    variable ext_a    : integer     := is_enabled(active, x_a);
    variable ext_f    : integer     := is_enabled(active, x_f);
    variable ext_h    : integer     := is_enabled(active, x_h);
    variable ext_zbc  : integer     := is_enabled(active, x_zbc);
    variable ext_zbkc : integer     := is_enabled(active, x_zbkc);
    variable op       : opcode_type := inst(6 downto 0);
    variable funct3   : funct3_type := inst(14 downto 12);
    variable funct5   : funct5_type := inst(31 downto 27);
    variable funct7   : funct7_type := inst(31 downto 25);
    -- Non-constant
    variable fusel  : fuseltype   := NONE;
  begin
    case op is
      when LUI | AUIPC | OP_IMM | OP_IMM_32 =>
        fusel     := ALU;
      when OP_AMO =>
        if ext_a /= 0 then
          if    funct5 = R_LR then
            fusel := (AMO or LD);
          elsif funct5 = R_SC then
            fusel := (AMO or LD or ST);
          else
            fusel := (AMO or LD or ST);
          end if;
        end if;
      when OP_REG | OP_32 =>
        if funct7 = F7_MUL then
          fusel   := MUL;
        else
          fusel   := ALU;
        end if;
        -- R_CLMULR is not actually valid for ext_zbkc, but that does not matter here.
        if (ext_zbc = 1 or ext_zbkc = 1) and op = OP_REG and funct7 = F7_MINMAXCLMUL and
           (funct3 = R_CLMUL or funct3 = R_CLMULH or funct3 = R_CLMULR) then
          fusel := ALU or ALU_SPECIAL;
        end if;
      when OP_FP =>
        if ext_f /= 0 then
          if funct5 = R_FCMP or funct5 = R_FMV_X_W or funct5 = R_FCVT_W_S then
            fusel := FPU;
          end if;
        end if;
      when OP_STORE | OP_STORE_FP =>
        fusel     := ST;
      when OP_LOAD  | OP_LOAD_FP =>
        fusel     := LD;
      when OP_JAL =>
        fusel     := JAL;
      when OP_JALR =>
        fusel     := JALR;
      when OP_BRANCH =>
        fusel     := BRANCH;
      when OP_SYSTEM =>
        if ext_h /= 0 and funct3 = "100" then
          if funct7(0) = '0' then
            fusel := LD;
          else --if funct7(0) = '1'
            fusel := ST;
          end if;
        elsif funct3 /= "000" then
          fusel   := ALU;
        end if;
      when OP_CUSTOM0 =>
        if funct3(2) = '0' then
          fusel := (DIAG or LD);
        else
          fusel := (DIAG or ST);
        end if;
      when others => null;
    end case;

    return fusel;
  end;

  -- CSRALU record generation
  -- Selects the type of operation and the control bits for that operation.
  function csralu_gen(inst : word) return word2 is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct3 : funct3_type := inst(14 downto 12);
    -- Non-constant
    variable ctrl   : word2       := CSR_BYPASS;
  begin
    -- Assuming the ALU is needed (based on the decoded fusel)
    case op is
      when OP_SYSTEM =>
        case funct3 is
          when I_CSRRS | I_CSRRSI => ctrl := CSR_SET;
          when I_CSRRC | I_CSRRCI => ctrl := CSR_CLEAR;
          when others             => null;             -- I_CSRRW | I_CSRRWI
        end case;
      when others                 => null;
    end case;

    return ctrl;
  end;

  -- CSR operation
  function csralu_op(op1  : wordx;
                     op2  : wordx;
                     ctrl : word2) return wordx is
    -- Non-constant
    variable res : wordx;
  begin
    case ctrl is
      when CSR_SET   => res := op2 or      op1;   -- OR
      when CSR_CLEAR => res := op2 and not op1;   -- ANDN
      when others    => res := op1;               -- BYPASS1
    end case;

    return res;
  end;

  -- Address generation for Load/Store unit.
  procedure addr_gen(active    : in  extension_type;
                     inst_in   : in  word;
                     fusel_in  : in  fuseltype;
                     valid_in  : in  std_ulogic;
                     op1_in    : in  wordx;
                     op2_in    : in  wordx;
                     address   : out wordx;
                     xc_out    : out std_ulogic;
                     cause_out : out cause_type;
                     tval_out  : out wordx) is
    variable ext_a      : integer     := is_enabled(active, x_a);
    variable ext_h      : integer     := is_enabled(active, x_h);
    variable ext_zicbom : integer     := is_enabled(active, x_zicbom);
    variable funct3 : funct3_type := inst_in(14 downto 12);
    variable size   : word2       := funct3(1 downto 0);
    -- Non-constant
    variable xc     : std_ulogic  := '0';
    variable cause  : cause_type  := (others => '0');
    variable add    : wordx1;
  begin
    if (ext_a /= 0 and v_fusel_eq(fusel_in, AMO)) or
       (ext_h /= 0 and
        (is_hlv(inst_in) or is_hsv(inst_in) or
         is_hfence_vvma(inst_in) or is_hfence_gvma(inst_in))) or
       is_sfence_vma(inst_in) or
       v_fusel_eq(fusel_in, DIAG) or
       (ext_zicbom /= 0 and is_cbo(inst_in)) then
      add  := '0' & op1_in;
    else
      add  := std_logic_vector(signed('0' & op1_in) +
                               signed(get_hi(op2_in) & op2_in));
    end if;

    if ext_h /= 0 and (is_hlv(inst_in) or is_hsv(inst_in)) then
      size := inst_in(27 downto 26);
    end if;

    -- Do not check for sfence.vma here, since it does not actually access anything.
    if v_fusel_eq(fusel_in, LD or ST or AMO) and data_addr_misaligned(add, size) then
      xc        := '1';
      cause     := XC_INST_LOAD_ADDR_MISALIGNED;
      if v_fusel_eq(fusel_in, ST) then
        cause   := XC_INST_STORE_ADDR_MISALIGNED;
      end if;
      -- Make misaligned atomics throw access faults so that no emulation
      -- is attempted (allowed according to the RISC-V standard.)
      if ext_a /= 0 and v_fusel_eq(fusel_in, AMO) then
        cause   := XC_INST_STORE_ACCESS_FAULT;
        if inst_in(28) = '1' and inst_in(27) = '0' then     -- LR?
          cause := XC_INST_LOAD_ACCESS_FAULT;
        end if;
      end if;
    end if;

    address   := add(address'range);
    xc_out    := xc and valid_in;
    cause_out := cause;
    tval_out  := add(tval_out'range);
  end;

--  -- Data Cache Gen
--  procedure dcache_gen(inst_in     : in  word;
--                       fusel_in    : in  fuseltype;
--                       valid_in    : in  std_ulogic;
--                       misaligned  : in  std_ulogic;
--                       dfeaturesen : in  csr_dfeaturesen_type;
--                       prv_in      : in  priv_lvl_type;
--                       v_in        : in  std_ulogic;
--                       mprv_in     : in  std_ulogic;
--                       mpv_in      : in  std_ulogic;
--                       mpp_in      : in  priv_lvl_type;
--                       mxr_in      : in  std_ulogic;
--                       sum_in      : in  std_ulogic;
--                       spvp_in     : in  std_ulogic;
--                       vmxr_in     : in  std_ulogic;
--                       vsum_in     : in  std_ulogic;
--                       dci_out     : out dcache_in_type) is
--    variable funct3 : funct3_type    := inst_in(14 downto 12);
--    -- Non-constant
--    variable dci    : dcache_in_type := dcache_in_none;
--  begin
--    -- Drive Cache Signal
--    dci.signed := not funct3(2);
--    dci.size   := funct3(1 downto 0);
--    -- During normal operation, the LEON5 processor accesses instructions
--    -- and data using ASI 0x8 - 0xB, so we do the same.
--    dci.asi  := "00001010";
--
--    dci.mxr   := mxr_in;
--    dci.vmxr  := vmxr_in;
--    dci.vms    := v_in & prv_in;
--    if mprv_in = '1' then -- M-mode is assumed
--      dci.vms  := mpv_in & mpp_in;
--    end if;
--
--    dci.hx     := '0';
--    dci.sum    := '0';
--    if prv_in = PRIV_LVL_S or                       -- HS-mode or VS-mode
--       (mprv_in = '1' and mpp_in = PRIV_LVL_S) then -- M-mode, access as through HS-mode or VS-mode
--      if ext_h /= 0 and (v_in = '1' or (mprv_in and mpv_in) = '1') then
--        dci.sum := vsum_in;
--      else
--        dci.sum := sum_in;
--      end if;
--    end if;
--    if ext_h /= 0 and (is_hlv(inst_in) or is_hsv(inst_in)) then
--      dci.vms         := "10" & spvp_in;
--      dci.sum         := vsum_in;
--      dci.hx          := inst_in(21) and not inst_in(25); -- HLVX
--    end if;
--
--    if valid_in = '1' then
--      if v_fusel_eq(fusel_in, LD or ST) and misaligned = '0' then
--        dci.enaddr      := '1';
--        dci.write       := inst_in(5);
--        dci.read        := not inst_in(5);
--        dci.amo         := (others => '0');
--        if ext_a /= 0 and v_fusel_eq(fusel_in, AMO) then
--          dci.amo := '1' & inst_in(31 downto 27);
--          if inst_in(28) = '1' then   -- LRSC
--            if inst_in(27) = '0' then -- LR
--              dci.write := '0';
--              dci.read  := '1';
--            else                      -- SC
--              dci.write := '1';
--              dci.read  := '0';
--              dci.lock  := '1';
--            end if;
--          else                        -- AMO
--            dci.write   := '1';
--            dci.read    := '1';
--            dci.lock    := '1';
--          end if;
--        end if;
--        if ext_h /= 0 and (is_hlv(inst_in) or is_hsv(inst_in)) then
--          dci.write       := inst_in(25);
--          dci.read        := not inst_in(25);
--          dci.signed      := not inst_in(20);
--          dci.size        := inst_in(27 downto 26);
--        end if;
--        if v_fusel_eq(fusel_in, DIAG) then
--          if is_diag_store(inst_in) then
--            dci.write   := '1';
--            dci.read    := '0';
--            dci.asi     := to_asi_store(inst_in);
--          else
--            dci.write   := '0';
--            dci.read    := '1';
--            dci.asi     := to_asi_load(inst_in);
--          end if;
--        end if;
--      -- We encode a fence_i instruction in an instruction
--      -- that flushes and enables both caches.
----      elsif is_fence_i(inst_in) then
----        dci.asi         := "00000010";
----        dci.write       := '1';
----        dci.enaddr      := '1';
----        dci.size        := "10";
--      -- We encode an sfence.vma instruction in an instruction
--      -- that flushes caches amd TLB.
--      elsif is_sfence_vma(inst_in) then
--        dci.asi         := "00011000";
--        dci.write       := '1';
--        dci.enaddr      := '1';
--        dci.size        := "10";
--      elsif is_hfence_vvma(inst_in) or is_hfence_gvma(inst_in) then
--        dci.asi         := "00011000";
--        dci.write       := '1';
--        dci.enaddr      := '1';
--        dci.size        := "10";
--      end if;
--    end if;
--
--    dci_out := dci;
--  end;

  -- Load aligner for 64-bit word
  function ld_align64(data   : word64;
                      size   : word2;
                      laddr  : word3;
                      signed : std_ulogic) return word64 is
    -- Non-constant
    variable rdata   : word64 := (others => '0');
    variable rdata64 : word64 := data;
  begin
    if true then
      case size is
      when SZBYTE => -- byte read
        case laddr(2 downto 0) is
          when "000"  => rdata(7 downto 0) := data( 7 downto  0);
          when "001"  => rdata(7 downto 0) := data(15 downto  8);
          when "010"  => rdata(7 downto 0) := data(23 downto 16);
          when "011"  => rdata(7 downto 0) := data(31 downto 24);
          when "100"  => rdata(7 downto 0) := data(39 downto 32);
          when "101"  => rdata(7 downto 0) := data(47 downto 40);
          when "110"  => rdata(7 downto 0) := data(55 downto 48);
          when others => rdata(7 downto 0) := data(63 downto 56);
        end case;
        if signed = '1' then rdata(63 downto 8) := (others => rdata(7)); end if;
        rdata64 := rdata;

      when SZHALF => -- half-word read
        case laddr(2 downto 1) is
          when "00"   => rdata(15 downto 0) := data(15 downto  0);
          when "01"   => rdata(15 downto 0) := data(31 downto 16);
          when "10"   => rdata(15 downto 0) := data(47 downto 32);
          when others => rdata(15 downto 0) := data(63 downto 48);
        end case;
        if signed = '1' then rdata(63 downto 16) := (others => rdata(15)); end if;
        rdata64 := rdata;

      when SZWORD => -- single word read
        if laddr(2) = '0' then rdata(31 downto 0) := data(31 downto  0);
        else                   rdata(31 downto 0) := data(63 downto 32);
        end if;
        if signed = '1' then rdata(63 downto 32) := (others => rdata(31)); end if;
        rdata64 := rdata;

      when others => -- double word read
      end case;
    else
      case size is
      when SZBYTE => -- byte read
        case laddr(2 downto 0) is
          when "000"  => rdata(7 downto 0) := data(63 downto 56);
          when "001"  => rdata(7 downto 0) := data(55 downto 48);
          when "010"  => rdata(7 downto 0) := data(47 downto 40);
          when "011"  => rdata(7 downto 0) := data(39 downto 32);
          when "100"  => rdata(7 downto 0) := data(31 downto 24);
          when "101"  => rdata(7 downto 0) := data(23 downto 16);
          when "110"  => rdata(7 downto 0) := data(15 downto  8);
          when others => rdata(7 downto 0) := data( 7 downto  0);
        end case;
        if signed = '1' then rdata(63 downto 8) := (others => rdata(7)); end if;
        rdata64 := rdata;

      when SZHALF => -- half-word read
        case laddr(2 downto 1) is
          when "00"   => rdata(15 downto 0) := data(63 downto 48);
          when "01"   => rdata(15 downto 0) := data(47 downto 32);
          when "10"   => rdata(15 downto 0) := data(31 downto 16);
          when others => rdata(15 downto 0) := data(15 downto  0);
        end case;
        if signed = '1' then rdata(63 downto 16) := (others => rdata(15)); end if;
        rdata64 := rdata;

      when SZWORD => -- single word read
        if laddr(2) = '0' then rdata(31 downto 0) := data(63 downto 32);
        else                   rdata(31 downto 0) := data(31 downto 0);
        end if;
        if signed = '1' then rdata(63 downto 32) := (others => rdata(31)); end if;
        rdata64 := rdata;

      when others => -- double word read
      end case;
    end if;

    return rdata64;
  end;

  -- Check if CSR write address should always cause illegal instruction fault.
  function csr_write_addr_xc(active : extension_type; TRIGGER : integer;
                             csra   : csratype;
                             misa   : wordx) return std_logic is
    variable ext_f        : integer    := is_enabled(active, x_f);
    variable ext_sscofpmf : integer    := is_enabled(active, x_sscofpmf);
    variable ext_sstc     : integer    := is_enabled(active, x_sstc);
    variable mode_s       : integer    := is_enabled(active, x_mode_s);
    variable logfilter    : integer    := is_enabled(active, x_logfilter);
    variable csra_high    : csratype   := csra(csra'high downto 4) & "0000";
    variable csra_low     : integer    := u2i(csra(3 downto 0));
    variable h_en         : boolean    := misa(h_ctrl) = '1';
    -- Non-constant
    variable xc           : std_ulogic := '0';
  begin
    case csra is
      -- User Floating-Point CSRs
      when CSR_FFLAGS | CSR_FRM | CSR_FCSR =>
        if not (ext_f = 1) then
          xc := '1';
        end if;
      -- Hypervisor Trap Setup
      when CSR_HSTATUS        =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HEDELEG        =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HIDELEG        =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HIE            =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HCOUNTEREN     =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HGEIE          =>
        if not h_en then
          xc := '1';
        end if;
      -- Hypervisor Trap Handling
      when CSR_HTVAL          =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HIP            =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HVIP           =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HTINST         =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HGEIP          =>
        if not h_en then
          xc := '1';
        end if;
      -- Hypervisor Protection and Translation
      when CSR_HGATP          =>
        if not h_en then
          xc := '1';
        end if;
      -- Hypervisor Counter/Timer Virtualization Registers
      when CSR_HTIMEDELTA     =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HTIMEDELTAH    =>
        if not h_en or not is_rv32 then
          xc := '1';
        end if;
      -- Virtual Supervisor Registers
      when CSR_VSSTATUS       =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSIE           =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSTVEC         =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSSCRATCH      =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSEPC          =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSCAUSE        =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSTVAL         =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSIP           =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSATP          =>
        if not h_en then
          xc := '1';
        end if;
      -- User Counters/Timers - see below
      when CSR_VSTIMECMP      =>
        if ext_sstc = 0 or not h_en then
          xc := '1';
        end if;
      when CSR_VSTIMECMPH     =>
        if ext_sstc = 0 or h_en then
          xc := '1';
        end if;
      -- Supervisor Trap Setup
      when CSR_SSTATUS        =>
      when CSR_SIE            =>
      when CSR_STVEC          =>
      when CSR_SCOUNTEREN     =>
      when CSR_SCOUNTOVF      =>
        if ext_sscofpmf = 0 or mode_s = 0 then
          xc := '1';
        end if;
      -- Supervisor Trap Handling
      when CSR_SSCRATCH       =>
      when CSR_SEPC           =>
      when CSR_SCAUSE         =>
      when CSR_STVAL          =>
      when CSR_SIP            =>
      -- Supervisor Protection and Translation
      when CSR_SATP           =>
      when CSR_STIMECMP       =>
        if ext_sstc = 0 then
          xc := '1';
        end if;
      when CSR_STIMECMPH      =>
        if ext_sstc = 0 then
          xc := '1';
        end if;
      -- Machine Trap Setup
      when CSR_MSTATUS        =>
      when CSR_MSTATUSH       =>
        if is_rv64 then
          xc := '1';
        end if;
      when CSR_MISA           =>
      when CSR_MEDELEG        =>
        if mode_s = 0
          then
          xc := '1';
        end if;
      when CSR_MIDELEG        =>
        if mode_s = 0
          then
          xc := '1';
        end if;
      when CSR_MIE            =>
      when CSR_MTVEC          =>
      when CSR_MCOUNTEREN     =>
      -- Machine Trap Handling
      when CSR_MSCRATCH       =>
      when CSR_MEPC           =>
      when CSR_MCAUSE         =>
      when CSR_MTVAL          =>
      when CSR_MIP            =>
      when CSR_MTINST         =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_MTVAL2         =>
        if not h_en then
          xc := '1';
        end if;
      -- Machine Protection and Translation
      when CSR_PMPCFG0        =>
      when CSR_PMPCFG1        =>
        if is_rv64 then
          xc := '1';
        end if;
      when CSR_PMPCFG2        =>
      when CSR_PMPCFG3        =>
        if is_rv64 then
          xc := '1';
        end if;
      -- Debug/Trace Registers
      when CSR_TSELECT        =>
        if TRIGGER = 0 then
          xc := '1';
        end if;
      when CSR_TDATA1         =>
        if TRIGGER = 0 then
          xc := '1';
        end if;
      when CSR_TDATA2         =>
        if TRIGGER = 0 then
          xc := '1';
        end if;
      when CSR_TDATA3         =>
        if TRIGGER = 0 then
          xc := '1';
        end if;
      when CSR_TINFO         =>
        xc := '1';
      -- Core Debug Registers
      when CSR_DCSR =>
      when CSR_DPC =>
      when CSR_DSCRATCH0 =>
      when CSR_DSCRATCH1 =>
      -- Custom Read/Write Registers
      when CSR_FEATURES =>
      when CSR_FEATURESH =>
        if is_rv64 then
          xc := '1';
        end if;
      when CSR_CCTRL =>
      when CSR_TCMICTRL =>
        xc := '1';
      when CSR_TCMDCTRL =>
        xc := '1';
      when others =>
        case csra_high is
          -- Machine Counter/Timers
          when CSR_MCYCLE         =>  -- MCYCLE/MINSTRET/HPMCOUNTER3-15
            if csra_low = 1 then      --  There is no CSR_MTIME!
              xc := '1';
            end if;
          when CSR_MCYCLEH        =>
            if is_rv64 or csra_low = 1 then --  There is no CSR_MTIMEH!
              xc := '1';
            end if;
          when CSR_MHPMCOUNTER16  =>  -- HPMCOUNTER16-31
          when CSR_MHPMCOUNTER16H =>  -- HPMCOUNTER16-31H
            if is_rv64 then
              xc := '1';
            end if;
          -- Machine Hardware Performance Monitoring Event Selector
          when CSR_MCOUNTINHIBIT  =>  -- MCOUNTINHIBIT/MHPMEVENT3-15
            if csra_low = 1 or        --  There is nothing at second/third position.
               csra_low = 2 then
              xc := '1';
            end if;
          when CSR_MHPMEVENT16    =>  -- MHPMEVENT16-31
          when CSR_MHPMEVENT0H    =>  -- MHPMEVENT3-15H
            if ext_sscofpmf = 0 or is_rv64 or csra_low < 3 then  --  There is nothing at 0-2.
              xc := '1';
            end if;
          when CSR_MHPMEVENT16H   =>  -- MHPMEVENT16-31H
            if ext_sscofpmf = 0 or is_rv64 then
              xc := '1';
            end if;
          when CSR_PMPADDR0       =>
          when others =>
            xc := '1';
        end case;
    end case;

    return xc;
  end;


  -- Check if CSR write address should cause illegal instruction fault,
  -- depending on circumstances.
  -- Privilege cannot change without exception and thus pipeline flush.
  function csr_write_xc(active : extension_type; TRIGGER : integer;
                        envcfg : csr_envcfg_type;
                        csra   : csratype;
                        rstate : core_state;
                        csr    : csr_reg_type) return std_logic is
    variable ext_f    : integer       := is_enabled(active, x_f);
    variable ext_sstc : integer       := is_enabled(active, x_sstc);
    variable priv_lvl : priv_lvl_type := csr.prv and csra(9 downto 8);
    variable h_en     : boolean       := csr.misa(h_ctrl) = '1';
    -- Non-constant
    variable priv_lvlv: priv_lvl_type := csr.prv and csra(9 downto 8);
    variable xc       : std_ulogic    := csr_write_addr_xc(active, TRIGGER, csra, csr.misa);
  begin
    -- Check for privileged level and read/write accessibility to CSR registers
    -- The standard RISC-V ISA sets aside a 12-bit encoding space (csr[11:0])
    -- for up to 4,096 CSRs. By convention, the upper 4 bits of the CSR address
    -- (csr[11:8]) are used to encode the read and write accessibility of the
    -- CSRs according to privilege level as shown in Table 2.1. The top two
    -- bits (csr[11:10]) indicate whether the register is read/write (00, 01, or 10)
    -- or read-only (11). The next two bits (csr[9:8]) encode the lowest privilege
    -- level that can access the CSR.
    if h_en and csr.v = '0' then
      priv_lvlv := (csr.prv(0) & csr.prv(1)) and csra(9 downto 8);
    end if;

    -- Exception due to lower priviledge or read-only.
    if ((priv_lvl /= csra(9 downto 8) and
         priv_lvlv /= csra(9 downto 8))
        ) or csra(11 downto 10) = "11" then        -- Read-only
      xc   := '1';
    end if;

    -- Exception if access Debug Core CSR or Features Enable not in Debug Mode.
    if rstate = run and
       (
        csra(11 downto 4) = "01111011") then
      xc   := '1';
    end if;

    -- Exception if access SATP in S-mode and TVM set or VS-mode and VTVM.
    if csra = CSR_SATP then
      if csr.v = '0' and csr.prv = PRIV_LVL_S and csr.mstatus.tvm = '1' then
        xc := '1';
      end if;
      if csr.v = '1' and csr.prv = PRIV_LVL_S and csr.hstatus.vtvm = '1' then
        xc := '1';
      end if;
    end if;

    -- Exception if access HGATP in HS-mode and TVM set.
    if h_en then
      if csra = CSR_HGATP and csr.prv = PRIV_LVL_S and csr.mstatus.tvm = '1' then
        xc := '1';
      end if;
    end if;

    -- FPU CSRs not accessible if FPU is not active.
    if not (ext_f = 1) then
      if (csra = CSR_FFLAGS or csra = CSR_FRM or csra = CSR_FCSR) and
         (csr.mstatus.fs = "00" or (csr.v = '1' and csr.vsstatus.fs = "00")) then
        xc := '1';
      end if;
    end if;

    -- SSTC
    if ext_sstc = 1 then 
      if envcfg.stce = '0' then
        if csra = CSR_STIMECMP or csra = CSR_STIMECMPH or 
           csra = CSR_VSTIMECMP or csra = CSR_VSTIMECMPH then
          xc := '1';
        end if;
      else
        if csra = CSR_STIMECMP or csra = CSR_STIMECMPH then
          -- When counteren(time) = 0: exception also on STIMECMP 
          if (csr.v = '0' and csr.prv = PRIV_LVL_S and csr.mcounteren(1) = '0') or
             (csr.v = '1' and csr.prv = PRIV_LVL_S and (csr.mcounteren(1) = '0' or
                                                       csr.hcounteren(1) = '0')) then
            xc := '1';
          end if;
        end if;
      end if;
    end if;

    return xc;
  end;

  -- Check if CSR read address should always cause illegal instruction fault.
  -- No CSRs are write-only, so this slightly modifies the write check above.
  function csr_read_addr_xc(active : extension_type; TRIGGER : integer;
                            csra   : csratype;
                            misa   : wordx) return std_logic is
    variable time_en   : integer := is_enabled(active, x_time);
    -- Non-constant
    variable xc : std_ulogic := '0';
  begin
    case csra is
      -- User Counter/Timers
      when CSR_CYCLE          =>
      when CSR_TIME           =>
        -- The time CSR is a read-only shadow of the memory-mapped mtime register
        -- Implementations can convert reads of the time CSR into loads to the
        -- memory-mapped mtime register, or emulate this functionality in M-mode software.
        if time_en = 0 then
          xc := '1';
        end if;
      when CSR_INSTRET        =>
      -- Machine Information Registers
      when CSR_MVENDORID      =>
      when CSR_MARCHID        =>
      when CSR_MIMPID         =>
      when CSR_MHARTID        =>
      -- User Hardware Performance Monitoring
      when CSR_HPMCOUNTER3  | CSR_HPMCOUNTER4  | CSR_HPMCOUNTER5  |
           CSR_HPMCOUNTER6  | CSR_HPMCOUNTER7  | CSR_HPMCOUNTER8  |
           CSR_HPMCOUNTER9  | CSR_HPMCOUNTER10 | CSR_HPMCOUNTER11 |
           CSR_HPMCOUNTER12 | CSR_HPMCOUNTER13 | CSR_HPMCOUNTER14 |
           CSR_HPMCOUNTER15 | CSR_HPMCOUNTER16 | CSR_HPMCOUNTER17 |
           CSR_HPMCOUNTER18 | CSR_HPMCOUNTER19 | CSR_HPMCOUNTER20 |
           CSR_HPMCOUNTER21 | CSR_HPMCOUNTER22 | CSR_HPMCOUNTER23 |
           CSR_HPMCOUNTER24 | CSR_HPMCOUNTER25 | CSR_HPMCOUNTER26 |
           CSR_HPMCOUNTER27 | CSR_HPMCOUNTER28 | CSR_HPMCOUNTER29 |
           CSR_HPMCOUNTER30 | CSR_HPMCOUNTER31 =>
      when CSR_TINFO =>
        if TRIGGER = 0 then
          xc := '1';
        end if;
      when others             => xc := csr_write_addr_xc(active, TRIGGER, csra, misa);
    end case;

    return xc;
  end;

  -- Exception Check
  -- Exception check unit located in Decode stage.
  -- Searches for illegal instructions, breakpoints and environmental calls.
  procedure exception_check(active    : in  extension_type;
                            envcfg    : in  csr_envcfg_type;
                            fpu_en    : in  boolean;
                            alu_ok    : in  boolean;
                            tval_ill0 : in  boolean;
                            inst_in   : in  word;
                            cinst_in  : in  word16;
                            pc_in     : in  std_logic_vector;
                            comp_ill  : in  std_ulogic;
                            misa_in   : in  wordx;
                            prv_in    : in  priv_lvl_type;
                            v_in      : in  std_ulogic;
                            tsr_in    : in  std_ulogic;
                            tw_in     : in  std_ulogic;
                            tvm_in    : in  std_ulogic;
                            vtsr_in   : in  std_ulogic;
                            vtw_in    : in  std_ulogic;
                            vtvm_in   : in  std_ulogic;
                            hu        : in  std_ulogic;
                            xc_out    : out std_ulogic;
                            cause_out : out cause_type;
                            tval_out  : out wordx) is
    variable ext_a   : integer       := is_enabled(active, x_a);
    variable ext_m   : integer       := is_enabled(active, x_m);
    variable ext_f   : integer       := is_enabled(active, x_f);
    variable ext_d   : integer       := is_enabled(active, x_d);
    variable no_muladd : integer     := 1 - is_enabled(active, x_muladd);
    variable h_en    : boolean       := misa_in(h_ctrl) = '1';
    variable rfa1    : rfatype       := inst_in(19 downto 15);
    variable rfa2    : rfatype       := inst_in(24 downto 20);
    variable rd      : rfatype       := inst_in(11 downto  7);
    variable opcode  : opcode_type   := inst_in( 6 downto  0);
    variable funct3  : funct3_type   := inst_in(14 downto 12);
    variable funct7  : funct7_type   := inst_in(31 downto 25);
    variable funct5  : funct5_type   := inst_in(31 downto 27);
    variable funct12 : funct12_type  := inst_in(31 downto 20);
    variable fmt     : word2         := inst_in(26 downto 25);
    -- Non-constant
    variable xc_v    : std_ulogic    := '0'; -- Virtual instruction exception
    variable hv_valid: std_ulogic    := '0';
    variable illegal : std_ulogic    := '0';
    variable xc      : std_ulogic;
    variable prv     : priv_lvl_type := prv_in;
    variable ecall   : std_ulogic    := '0';
    variable ebreak  : std_ulogic    := '0';
    variable cause   : cause_type;
    variable tval    : wordx;
  begin
    case opcode is
      when LUI | AUIPC | OP_JAL =>
        -- LUI/AUIPC with rd = x0 are standard HINTs.
        null;
      when OP_JALR =>
        case funct3 is
          when I_JALR => null;
          when others => illegal := '1';
        end case;
      when OP_BRANCH =>
        case funct3 is
          when B_BEQ | B_BNE  | B_BLT |
               B_BGE | B_BLTU | B_BGEU => null;
          when others                  => illegal := '1';
        end case;
      when OP_LOAD =>
        case funct3 is
          when I_LB  | I_LH  | I_LW  |
               I_LBU | I_LHU | I_LWU | I_LD => null;
          when others                       => illegal := '1';
        end case;
        if is_rv32 and funct3 = I_LD then
          illegal := '1';
        end if;
      when OP_STORE =>
        case funct3 is
          when S_SB | S_SH | S_SW | S_SD => null;
          when others                    => illegal := '1';
        end case;
        if is_rv32 and funct3 = S_SD then
          illegal := '1';
        end if;

      when OP_IMM | OP_IMM_32 =>
        illegal := not to_bit(alu_ok);
      when OP_REG =>
        if funct7 = F7_MUL then
          if ext_m = 1 then
            case funct3 is
              when R_MUL | R_MULH | R_MULHSU | R_MULHU |
              R_DIV | R_DIVU | R_REM    | R_REMU => null;
            when others => illegal := '1';
          end case;
        else
          illegal := '1';
        end if;
      else
        illegal := not to_bit(alu_ok);
      end if;
    when OP_32 =>
      if funct7 = F7_MUL then
        if ext_m = 1 and is_rv64 then
          case funct3 is
            when R_MULW | R_DIVW | R_DIVUW | R_REMW | R_REMUW => null;
            when others => illegal := '1';
          end case;
        else
          illegal := '1';
        end if;
      else
        illegal := not to_bit(alu_ok);
      end if;
    when OP_FENCE =>
      case funct3 is
        when I_FENCE =>
            --   28   24   20    15  12     7
            -- __fm pred succ __rs1 000 ___rd 0001111
            -- rd  = x0, rs1 /= x0, fm = 0 and (pred = 0 or succ = 0) are standard HINTs.
            -- rd /= x0, rs1  = x0, fm = 0 and (pred = 0 or succ = 0) are standard HINTs.
            -- rd  = x0, rs1  = x0, fm = 0, pred  = 0, succ /= 0 are standard HINTs.
            -- rd  = x0, rs1  = x0, fm = 0, pred /= W, succ  = 0 are standard HINTs.
            -- rd  = x0, rs1  = x0, fm = 0, pred  = W, succ  = 0 is standard HINT (PAUSE).
          if inst_in(19 downto 7) /= zerow(19 downto 7) then
            illegal := '1';
          end if;
        when I_FENCE_I =>
          if inst_in(31 downto 13) /= zerow(31 downto 13) and
          inst_in(12) /= '1' and
          inst_in(11 downto  7) /= zerow(11 downto  7) then
            illegal := '1';
          end if;
        when I_CBO =>
          if inst_in(31 downto 23) /= zerow(31 downto 23) or 
             (inst_in(22) = '1' and (envcfg.cbze = '0' or inst_in(21 downto 20) /= "00") ) or -- cbo.zero
             (inst_in(22) = '0' and
              ((envcfg.cbcfe = '0' and not all_0(inst_in(21 downto 20))) or
               (envcfg.cbie = "00" and all_0(inst_in(21 downto 20))) or
               (inst_in(21 downto 20) = "11"))) or -- cbo.inval/clean/flush
             inst_in(11 downto 7) /= zerow(11 downto 7) then
            illegal := '1';
            if h_en and v_in = '1' then
              xc_v := '1';
            end if;
          end if;
        when others =>
          illegal := '1';
      end case;
      when OP_SYSTEM =>
        if not is_csr(inst_in) then
          -- Any of the non-CSR SYSTEM instructions?
          if funct3 = "000" and rd = "00000" then
            case funct7 is
              when F7_URET => -- ECALL, EBREAK, URET (not supported)
                if rfa1 = "00000" then
                  case inst_in(24 downto 20) is
                    when "00000" => ecall  := '1'; -- ECALL
                    when "00001" => ebreak := '1'; -- EBREAK
                    when others => illegal := '1';
                  end case;
                else
                  illegal := '1';
                end if;
              when F7_SRET => -- SRET, WFI
                if rfa1 = "00000" then
                  case rfa2 is
                    when "00010" => -- SRET
                      -- The TSR (Trap SRET) bit supports intercepting the supervisor exception
                      -- return instruction, SRET. When TSR=1, attempts to execute SRET while
                      -- executing in S-mode will raise an illegal instruction exception.
                      -- When TSR=0, this operation is permitted in S-mode.
                      -- TSR is hard-wired to 0 when S-mode is not supported.
                      if ((not h_en) or v_in = '0') and
                         (prv_in = PRIV_LVL_U or (prv_in = PRIV_LVL_S and tsr_in = '1')) then
                        illegal := '1';
                      end if;
                      -- In VS-mode, attempts to execute SRET when hstatus.VTSR=1, or
                      -- in VU-mode, attempts to execute supervisor instruction SRET,
                      -- will raise a virtual instruction trap.
                      if (h_en and v_in = '1') and ((prv_in = PRIV_LVL_S and vtsr_in = '1') or
                                                    prv_in = PRIV_LVL_U) then
                        illegal := '1';
                        xc_v := '1';
                      end if;
                    when "00101" => -- WFI
                      -- The TW (Timeout Wait) bit supports intercepting the WFI instruction.
                      -- When TW=0, the WFI instruction is permitted in S-mode.
                      -- When TW=1, if WFI is executed in S-mode, and it does not complete
                      -- within an implementation-specific, bounded time limit, the
                      -- WFI instruction causes an illegal instruction trap. The time limit
                      -- may always be 0, in which case WFI always causes an illegal instruction
                      -- trap in S-mode when TW=1. TW is hard-wired to 0 when
                      -- S-mode is not supported.
                      -- WFI is available in all privileged modes, and optionally available to U-mode.
                      if ((not h_en) or v_in = '0') and
                         (prv_in = PRIV_LVL_U or (prv_in = PRIV_LVL_S and tw_in = '1')) then
                        illegal := '1'; -- timeout = 0
                      end if;
                      -- In VS-mode, attempts to execute WFI when hstatus.VTW=1 and mstatus.TW=0, or
                      -- in VU-mode, attempts to execute WFI, will raise a virtual instruction trap.
                      if (h_en and v_in = '1') and ((prv_in = PRIV_LVL_S and vtw_in = '1' and tw_in = '0') or
                                                    prv_in = PRIV_LVL_U) then
                        illegal := '1';
                        xc_v := '1';
                      end if;
                    when others =>
                      illegal := '1';
                  end case;
                else
                  illegal := '1';
                end if;
              when F7_MRET =>
                if rfa1 = "00000" and rfa2 = "00010" then
                  if prv_in = PRIV_LVL_S or prv_in = PRIV_LVL_U then
                    illegal := '1';
                  end if;
                else
                  illegal   := '1';
                end if;
              when F7_SFENCE_VMA =>
                -- The TVM (Trap Virtual Memory) bit supports intercepting supervisor
                -- virtual-memory management operations. When TVM=1, attempts to read
                -- or write the satp CSR, or execute the SFENCE.VMA instruction while
                -- executing in S-mode, will raise an illegal instruction exception.
                -- When TVM=0, these operations are permitted in S-mode.
                -- TVM is hard-wired to 0 when S-mode is not supported.
                if ((not h_en) or v_in = '0') and prv_in = PRIV_LVL_S and tvm_in = '1' then
                  illegal := '1';
                end if;
                -- In VS-mode, attempts to execute an SFENCE instruction when hstatus.VTVM=1, or
                -- in VU-mode, attempts to execute an SFENCE instruction, will raise a virtual
                -- instruction trap.
                 if (h_en and v_in = '1') and ((prv_in = PRIV_LVL_S and vtvm_in = '1') or
                                                prv_in = PRIV_LVL_U) then
                   illegal := '1';
                   xc_v := '1';
                 end if;

                 if(prv_in = PRIV_LVL_U) then
                   illegal := '1';
                   xc_v := '0'; --needed? Probably the default value
                 end if;

              when F7_HFENCE_VVMA =>
                if h_en then
                  if v_in = '1' then
                    illegal := '1';
                    xc_v := '1';
                  end if;
                else
                  illegal := '1';
                end if;
              when F7_HFENCE_GVMA =>
                if h_en then
                  if v_in = '0' then
                    if (prv_in = PRIV_LVL_S and tvm_in = '1') or prv_in = PRIV_LVL_U then
                      illegal := '1';
                    end if;
                  else
                    illegal := '1';
                    xc_v := '1';
                  end if;
                else
                  illegal := '1';
                end if;
              when others =>
                illegal := '1';
            end case;
          elsif funct3 = "100" then
            case funct7 is
              when F7_HLVB =>
                if rfa2 = "00000" or rfa2 = "00001"                   then hv_valid := '1'; end if;
              when F7_HLVH =>
                if rfa2 = "00000" or rfa2 = "00001" or rfa2 = "00011" then hv_valid := '1'; end if;
              when F7_HLVW =>
                if rfa2 = "00000" or rfa2 = "00001" or rfa2 = "00011" then hv_valid := '1'; end if;
              when F7_HLVD =>
                if rfa2 = "00000"                                     then hv_valid := '1'; end if;
              when F7_HSVB | F7_HSVH | F7_HSVW | F7_HSVD =>
                if rd = "00000"                                       then hv_valid := '1'; end if;
              when others =>
                illegal := '1';
            end case;
            if h_en then
              if hv_valid = '1' then
                if v_in = '0' then
                  if prv_in = PRIV_LVL_U and hu = '0' then
                    illegal := '1';
                  end if;
                else
                  illegal := '1';
                  xc_v := '1';
                end if;
              else
                illegal := '1';
              end if;
            else
              illegal := '1';
            end if;
          else
            illegal   := '1';
          end if;
        end if;
      when OP_AMO =>
        if ext_a = 1 then
          if funct3 = R_WORD or funct3 = R_DOUBLE then
            case funct5 is
              when R_LR     | R_SC     | R_AMOSWAP | R_AMOADD |
                   R_AMOXOR | R_AMOAND | R_AMOOR   |
                   R_AMOMIN | R_AMOMAX | R_AMOMINU | R_AMOMAXU => null;
              when others => illegal := '1';
            end case;
          else
            illegal := '1';
          end if;
        else
          illegal   := '1';
        end if;
        if is_rv32 and funct3 = R_DOUBLE then
          illegal := '1';
        end if;
      when OP_LOAD_FP | OP_STORE_FP =>
        case funct3 is
          when R_WORD   => illegal := to_bit(ext_f = 0);
          when R_DOUBLE => illegal := to_bit(ext_d = 0);
          when others   => illegal := '1';
        end case;
        if not fpu_en then
          illegal := '1';
        end if;
      when OP_FMADD | OP_FMSUB | OP_FNMSUB | OP_FNMADD =>
        case fmt is
          when "00"   => illegal := to_bit(ext_f = 0);
          when "01"   => illegal := to_bit(ext_d = 0);
          when others => illegal := '1';
        end case;
        if not fpu_en then
          illegal := '1';
        end if;
        if no_muladd = 1 then
          illegal   := '1';
        end if;
      when OP_FP =>
        case fmt is
          when "00"   => illegal := to_bit(ext_f = 0);
          when "01"   => illegal := to_bit(ext_d = 0);
          when others => illegal := '1';
        end case;
        if not fpu_en then
          illegal := '1';
        end if;
        case funct5 is
          when R_FADD | R_FSUB | R_FMUL | R_FDIV => null;
          when R_FSQRT =>
            if rfa2 /= "00000" then
              illegal := '1';
            end if;
          when R_FSGN =>
            case funct3 is
              when R_FSGNJ | R_FSGNJN | R_FSGNJX => null;
              when others                        => illegal := '1';
            end case;
          when R_FMINMAX =>
            case funct3 is
              when R_FMAX | R_FMIN => null;
              when others        => illegal := '1';
            end case;
          when R_FCMP =>
            case funct3 is
              when R_FEQ | R_FLT | R_FLE => null;
              when others                => illegal := '1';
            end case;
          when R_FCVT_W_S | R_FCVT_S_W => -- R_FCVT_L_S, R_FCVT_S_L (and _D_ variants)
            if not (rfa2(4 downto 2) = "000") then
              illegal := '1';
            end if;
            -- No L[U] for RV32.
            if is_rv32 and rfa2(1) = '1' then
              illegal := '1';
            end if;
          when R_FMV_X_W | R_FMV_W_X => -- R_FCLASS (and _D_ variants)
            if not (rfa2 = "00000" and (funct3 = "000" or funct3 = "001")) then
              illegal := '1';
            end if;
            -- The move instructions only work for 32 bit float on RV32.
            if is_rv32 and fmt /= "00" and funct3 = "000" then
              illegal := '1';
            end if;
          when R_FCVT_S_D =>  -- R_FCVT_D_S
            if (fmt = "00" and rfa2 /= "00001") or
               (fmt = "01" and rfa2 /= "00000") then
              illegal := '1';
            end if;
          when others =>
            illegal := '1';
        end case;
      when OP_CUSTOM0 =>
        case funct7 is
          when F7_BASE => -- Custom diagnostic instructions
            -- rv32: support 32-bit access
            -- rv64: support 32 and 64-bit access
            if (is_rv32 and funct3(1 downto 0) /= "10") or
               (is_rv64 and (funct3(1 downto 0) /= "10" and funct3(1 downto 0) /= "11")) then
              illegal := '1';
            end if;
          when others =>
            illegal := '1';
        end case;
      when others =>
        illegal := '1';
    end case; -- opcode

    -- Exception generation
    xc        := '0';
    if xc_v = '1' then
      cause     := XC_INST_VIRTUAL_INST;
    else
      cause     := XC_INST_ILLEGAL_INST;
    end if;

    tval      := to0x(inst_in);

    if comp_ill = '1' then
      -- Illegal compressed instruction
      tval    := to0x(cinst_in);
      illegal := '1';
    end if;

    if tval_ill0 then
      tval    := zerox;
    end if;

    if illegal = '1' or ecall = '1' or ebreak = '1' then
      xc      := '1';
    end if;

    if ebreak = '1' then
      tval    := pc2xlen(pc_in);
      cause   := XC_INST_BREAKPOINT;
    end if;

    if ecall = '1' then
      tval    := (others => '0');
      case prv is
        when PRIV_LVL_M => cause := XC_INST_ENV_CALL_MMODE;
        when PRIV_LVL_S => cause := XC_INST_ENV_CALL_SMODE;
        when PRIV_LVL_U => cause := XC_INST_ENV_CALL_UMODE;
        when others => null;
      end case;
      -- H-ext: Environment call from VS-mode
      if v_in = '1' and prv = PRIV_LVL_S then
        cause := XC_INST_ENV_CALL_VSMODE;
      end if;
    end if;

    cause_out := cause;
    xc_out    := xc;
    tval_out  := tval;
  end;

  -- Fetch pmpcfg data
  function pmpcfg(pmp_entries : integer range 0 to 16;
                  csr : csr_reg_type; n : natural) return word8 is
    -- Non-constant
    type cfgv_type is array (0 to 15) of word8;
    variable cfgv   : cfgv_type;
    variable cfg    : word8 := (others => '0');
  begin
    for i in 0 to 7 loop
      cfgv(i)     := csr.pmpcfg0(i * 8 + 7 downto i * 8);
      cfgv(i + 8) := csr.pmpcfg2(i * 8 + 7 downto i * 8);
    end loop;

    if n < pmp_entries then
      cfg := cfgv(n);
    end if;

    return cfg;
  end;

  -- CSR Read
  -- CSR read unit located in register access stage.
  -- All read accesses are combinatorial accesses.
  procedure csr_read(active      : in  extension_type; TRIGGER : integer;
                     perf_cnts   : in  integer range 0 to 29;
                     counter_ok  : in  word;
                     hart        : in  std_logic_vector;
                     fpuconf     : in  integer range 0 to 1;
                     pmp_entries : in  integer range 0 to 16;
                     pmp_g       : in  integer range 0 to 10;
                     pmp_msb     : in  integer range 15 to 63;
                     envcfg      : in  csr_envcfg_type;
                     csr_file    : in  csr_reg_type;
                     csra_in     : in  csratype;
                     csrv_in     : in  std_ulogic;
                     rstate_in   : in  core_state;
                     iu_fflags   : in  std_logic_vector;
                     mmu_csr     : in  nv_csr_in_type;
                     data_out    : out wordx;
                     xc_out      : out std_ulogic;
                     cause_out   : out cause_type) is
    variable ext_c     : integer       := is_enabled(active, x_c);
    variable ext_f     : integer       := is_enabled(active, x_f);
    variable ext_sscofpmf : integer    := is_enabled(active, x_sscofpmf);
    variable mode_u    : integer       := is_enabled(active, x_mode_u);
    variable mode_s    : integer       := is_enabled(active, x_mode_s);
    variable fpu_debug : integer       := is_enabled(active, x_fpu_debug);
    variable dtcmen    : integer       := is_enabled(active, x_dtcm);
    variable itcmen    : integer       := is_enabled(active, x_itcm);
    variable logfilter    : integer    := is_enabled(active, x_logfilter);
    variable csra_high : csratype      := csra_in(csra_in'high downto 4) & "0000";
    variable csra_low  : integer       := u2i(csra_in(3 downto 0));
    variable h_en      : boolean       := csr_file.misa(h_ctrl) = '1';
    variable v_mode    : std_ulogic    := csr_file.misa(h_ctrl) and csr_file.v;
    variable vu_mode   : std_ulogic    := v_mode and to_bit(csr_file.prv = "00");
    -- Non-constant
    variable csr       : wordx         := zerox;
    variable xc        : std_ulogic    := '0';
    variable xc_v      : std_ulogic    := '0';
    variable priv_lvl  : priv_lvl_type := (others => '0');
    variable priv_lvlv : priv_lvl_type := (others => '0');
  begin
    if csrv_in = '1' then
      case csra_in is
        -- User Floating-Point CSRs
        when CSR_FFLAGS =>
          if ext_f = 1 and csr_file.mstatus.fs /= "00" and
             (csr_file.v = '0' or csr_file.vsstatus.fs /= "00") then
            csr := to0x(csr_file.fflags);
            csr(csr_file.fflags'range) := csr(csr_file.fflags'range) or iu_fflags;
          else
            xc := '1';
          end if;
        when CSR_FRM =>
          if ext_f = 1 and csr_file.mstatus.fs /= "00" and
             (csr_file.v = '0' or csr_file.vsstatus.fs /= "00") then
            csr := to0x(csr_file.frm);
          else
            xc := '1';
          end if;
        when CSR_FCSR =>
          if ext_f = 1 and csr_file.mstatus.fs /= "00" and
             (csr_file.v = '0' or csr_file.vsstatus.fs /= "00") then
            if fpu_debug /= 0 then
              csr(csr_file.fctrl'range) := csr_file.fctrl;
            end if;
            csr(csr_file.fflags'range)  := csr_file.fflags or iu_fflags;
            csr(csr_file.frm'range)     := csr_file.frm;
          else
            xc := '1';
          end if;
        -- Hypervisor Trap Setup
        when CSR_HSTATUS        =>
          if h_en then
            csr := to_hstatus(csr_file.hstatus);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HEDELEG        =>
          if h_en then
            csr := csr_file.hedeleg and CSR_HEDELEG_MASK;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HIDELEG        =>
          if h_en then
            csr := csr_file.hideleg and CSR_HIDELEG_MASK;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HIE            =>
          if h_en then
            csr := csr_file.mie and CSR_HIE_MASK;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HCOUNTEREN     =>
          if h_en then
            csr := to0x(csr_file.hcounteren);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HGEIE          =>
          if h_en then
            csr := csr_file.hgeie;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        -- Hypervisor Trap Handling
        when CSR_HTVAL          =>
          if h_en then
            csr := csr_file.htval;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HIP            =>
          if h_en then
            csr := csr_file.mip and CSR_HIE_MASK;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HVIP           =>
          if h_en then
            csr     := csr_file.hvip and CSR_HIDELEG_MASK;
            csr(2)  := csr_file.mip(2);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HTINST         =>
          if h_en then
            csr := csr_file.htinst;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HGEIP          =>
          if h_en then
            csr := csr_file.hgeip;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        -- Hypervisor Protection and Translation
        when CSR_HGATP          =>
          if h_en then
            if csr_file.prv = PRIV_LVL_S and csr_file.mstatus.tvm = '1' then
              xc  := '1';
            else
              csr := csr_file.hgatp;
            end if;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HENVCFG        =>
          if h_en then
            csr := to_envcfg(csr_file.henvcfg, csr_file.menvcfg);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HENVCFGH       =>
          if h_en and is_rv32 then
            csr := to_envcfgh(csr_file.henvcfg, csr_file.menvcfg);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        -- Hypervisor Counter/Timer Virtualization Registers
        when CSR_HTIMEDELTA     =>
          if h_en then
            csr := csr_file.htimedelta(wordx'range);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HTIMEDELTAH    =>
          if h_en and is_rv32 then
            csr := to0x(csr_file.htimedelta(63 downto 32));
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        -- Virtual Supervisor Registers
        when CSR_VSSTATUS       =>
          if h_en then
            csr := to_vsstatus(csr_file.vsstatus);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSIE           =>
          if h_en then
            csr(9)  := csr_file.mie(10) and csr_file.hideleg(10);
            csr(5)  := csr_file.mie(6)  and csr_file.hideleg(6);
            csr(1)  := csr_file.mie(2)  and csr_file.hideleg(2);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSTVEC         =>
          if h_en then
            csr := csr_file.vstvec;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSSCRATCH      =>
          if h_en then
            csr := csr_file.vsscratch;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSEPC          =>
          if h_en then
            csr := csr_file.vsepc;
            if ext_c = 1 and ISA_CONTROL(c_ctrl) = '1' and csr_file.misa(c_ctrl) = '0' then
              csr(1) := '0';
            end if;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSCAUSE        =>
          if h_en then
            csr := csr_file.vscause;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSTVAL         =>
          if h_en then
            csr := csr_file.vstval;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSIP           =>
          if h_en then
            csr(9)  := csr_file.mip(10) and csr_file.hideleg(10);
            csr(5)  := csr_file.mip(6)  and csr_file.hideleg(6);
            csr(1)  := csr_file.mip(2)  and csr_file.hideleg(2);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSATP          =>
          if h_en then
            csr := csr_file.vsatp;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        -- User Counters/Timers - see below
        when CSR_VSTIMECMP     =>
          if envcfg.stce = '1' and h_en then 
            csr := csr_file.vstimecmp(wordx'range);
          else
            xc := '1';
          end if;
          if csr_file.menvcfg.stce = '1' then
            xc_v := v_mode; -- virtual instruction exception
          end if;
        when CSR_VSTIMECMPH    =>
          if envcfg.stce = '1' and h_en and is_rv32 then
            csr := to0x(csr_file.vstimecmp(63 downto 32));
          else
            xc := '1';
          end if;
          if csr_file.menvcfg.stce = '1' then
            xc_v := v_mode; -- virtual instruction exception
          end if;
        -- Supervisor Trap Setup
        when CSR_SSTATUS        =>
          if h_en and csr_file.v = '1' then
            csr := to_vsstatus(csr_file.vsstatus);
          else
            csr := to_sstatus(csr_file.mstatus);
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SIE            =>
          if h_en and csr_file.v = '1' then
            csr(9)  := csr_file.mie(10) and csr_file.hideleg(10);
            csr(5)  := csr_file.mie(6)  and csr_file.hideleg(6);
            csr(1)  := csr_file.mie(2)  and csr_file.hideleg(2);
          else
            csr := csr_file.mie and (csr_file.mideleg and not CSR_HIE_MASK);
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_STVEC          =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vstvec;
          else
            csr := csr_file.stvec;
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SCOUNTEREN     =>
          if mode_u = 1 then
            csr := to0x(csr_file.scounteren);
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SENVCFG        =>
          if mode_u = 1 then
            csr := to_envcfg(csr_file.senvcfg, csr_file.menvcfg);
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        -- Supervisor Trap Handling
        when CSR_SEPC           =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vsepc;
          else
            csr := csr_file.sepc;
          end if;
          if ext_c = 1 and ISA_CONTROL(c_ctrl) = '1' and csr_file.misa(c_ctrl) = '0' then
            csr(1) := '0';
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SCAUSE         =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vscause;
          else
            csr := csr_file.scause;
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_STVAL          =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vstval;
          else
            csr := csr_file.stval;
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SIP            =>
          if h_en and csr_file.v = '1' then
            csr(9)  := csr_file.mip(10) and csr_file.hideleg(10);
            csr(5)  := csr_file.mip(6)  and csr_file.hideleg(6);
            csr(1)  := csr_file.mip(2)  and csr_file.hideleg(2);
          else
            csr := csr_file.mip and csr_file.mideleg;
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SSCRATCH       =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vsscratch;
          else
            csr := csr_file.sscratch;
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        -- Supervisor Protection and Translation
        when CSR_SATP           =>
          xc_v := vu_mode; -- virtual instruction exception
          if h_en and csr_file.v = '1' then
            if csr_file.prv = PRIV_LVL_S and csr_file.hstatus.vtvm = '1' then
              xc  := '1';
              xc_v := v_mode; -- virtual instruction exception
            else
              csr := csr_file.vsatp;
            end if;
          else
            if csr_file.prv = PRIV_LVL_S and csr_file.mstatus.tvm = '1' then
              xc  := '1';
            else
              csr := csr_file.satp;
            end if;
          end if;
        when CSR_STIMECMP     =>
          if envcfg.stce = '1' then
            if h_en and csr_file.v = '1' then
              if csr_file.hcounteren(1) = '0' or csr_file.mcounteren(1) = '0' then
                xc := '1';
              else
                csr := csr_file.vstimecmp(wordx'range);
              end if;
            else
              if csr_file.mcounteren(1) = '0' and csr_file.prv = PRIV_LVL_S then
                xc := '1';
              else
                csr := csr_file.stimecmp(wordx'range);
              end if;
            end if;
          else
            xc := '1';
          end if;
          if csr_file.menvcfg.stce = '1' and (csr_file.mcounteren(1) or not envcfg.stce) = '1' then
            xc_v := v_mode; -- virtual instruction exception
          end if;
        when CSR_STIMECMPH    =>
          if envcfg.stce = '1' and is_rv32 then 
            if h_en and csr_file.v = '1' then
              if csr_file.hcounteren(1) = '0' or csr_file.mcounteren(1) = '0' then
                xc := '1';
              else
                csr := to0x(csr_file.vstimecmp(63 downto 32));
              end if;
            else
              if csr_file.mcounteren(1) = '0' and csr_file.prv = PRIV_LVL_S then
                xc := '1';
              else
                csr := to0x(csr_file.stimecmp(63 downto 32));
              end if;
            end if;
          else
            xc := '1';
          end if;
          if csr_file.menvcfg.stce = '1' and (csr_file.mcounteren(1) or not envcfg.stce) = '1' then
            xc_v := v_mode; -- virtual instruction exception
          end if;
        -- Supervisor Count Overflow
        when CSR_SCOUNTOVF      =>
          if ext_sscofpmf = 0 or mode_s = 0 then
            xc         := '1';
          else
            for i in 3 to perf_cnts + 3 - 1 loop
              csr(i) := csr_file.hpmevent(i).overflow;
              if csr_file.mcounteren(i) = '0' then
                csr(i) := '0';
              elsif h_en and csr_file.v = '1' and
                    csr_file.hcounteren(i) = '0' then
                csr(i) := '0';
              end if;
            end loop;
          end if;
        -- Machine Information Registers
        when CSR_MVENDORID      => csr := CSR_VENDORID;
        when CSR_MARCHID        => csr := CSR_ARCHID;
        when CSR_MIMPID         => csr := CSR_IMPID;
        when CSR_MHARTID        => csr := to0x(hart);
        --  Machine Trap Setup
        when CSR_MSTATUS        => csr := to_mstatus(csr_file.mstatus);
        when CSR_MSTATUSH       =>
          if is_rv32 then
            csr := to_mstatush(csr_file.mstatus);
          else
            xc := '1';
          end if;
        when CSR_MISA           => csr := csr_file.misa;
        when CSR_MTVEC          => csr := csr_file.mtvec;
        when CSR_MEDELEG        =>
          if mode_s = 0
            then
            xc := '1';
          else
            csr := csr_file.medeleg;
          end if;
        when CSR_MIDELEG        =>
          if mode_s = 0
            then
            xc := '1';
          else
            csr := csr_file.mideleg;
          end if;
        when CSR_MIE            => csr := csr_file.mie;
        when CSR_MCOUNTEREN     => csr := to0x(csr_file.mcounteren);
        -- Machine Trap Handling
        when CSR_MSCRATCH       => csr := csr_file.mscratch;
        when CSR_MEPC           =>
          csr := csr_file.mepc;
          if ext_c = 1 and ISA_CONTROL(c_ctrl) = '1' and csr_file.misa(c_ctrl) = '0' then
            csr(1) := '0';
          end if;
        when CSR_MCAUSE         => csr := csr_file.mcause;
        when CSR_MTVAL          => csr := csr_file.mtval;
        when CSR_MIP            => csr := csr_file.mip;
        when CSR_MTINST         =>
          if h_en then
            csr := csr_file.mtinst;
          else
            xc := '1';
          end if;
        when CSR_MTVAL2         =>
          if h_en then
            csr := csr_file.mtval2;
          else
            xc := '1';
          end if;
        when CSR_MENVCFG        =>
          if mode_u = 1 then
            csr := to_envcfg(csr_file.menvcfg);
          else
            xc := '1';
          end if;
        when CSR_MENVCFGH       =>
          if mode_u = 1 and is_rv32 then
            csr := to_envcfgh(csr_file.menvcfg);
          else
            xc := '1';
          end if;
        -- Machine Protection and Translation
        when CSR_PMPCFG0        => csr := csr_file.pmpcfg0(wordx'range);
        when CSR_PMPCFG1        =>
          if is_rv32 then
            csr := to0x(csr_file.pmpcfg0(63 downto 32));
          else
            xc := '1';
          end if;
        when CSR_PMPCFG2        => csr := csr_file.pmpcfg2(wordx'range);
        when CSR_PMPCFG3        =>
          if is_rv32 then
            csr := to0x(csr_file.pmpcfg2(63 downto 32));
          else
            xc := '1';
          end if;
        -- Machine|User Counter/Timers
        when CSR_CYCLE |
             CSR_MCYCLE         => csr := csr_file.mcycle(wordx'range);
        when CSR_CYCLEH |
             CSR_MCYCLEH        =>
          if is_rv32 then
            csr := to0x(csr_file.mcycle(63 downto 32));
          else
            xc := '1';
          end if;
        when CSR_TIME           =>
          csr := zerox;
          -- The time CSR is a read-only shadow of the memory-mapped mtime register.
          -- Implementations can convert reads of the time CSR into loads to the
          -- memory-mapped mtime register, or emulate this functionality in M-mode software.
          xc := '1';
        when CSR_TIMEH          =>
          csr := zerox;
          -- See CSR_TIME.
          xc := '1';
        when CSR_INSTRET |
             CSR_MINSTRET       => csr := csr_file.minstret(wordx'range);
        when CSR_INSTRETH |
             CSR_MINSTRETH      =>
          if is_rv32 then
            csr := to0x(csr_file.minstret(63 downto 32));
          else
            xc := '1';
          end if;
        -- Machine Performance Monitoring Counter Selector
        when CSR_MCOUNTINHIBIT  => csr := to0x(csr_file.mcountinhibit);
        -- Debug/Trace Registers
        when CSR_TSELECT        =>
          csr := to0x(csr_file.tcsr.tselect);
          if TRIGGER = 0 then
            xc := '1';
          end if;
        when CSR_TDATA1         =>
          csr := csr_file.tcsr.tdata1(u2i(csr_file.tcsr.tselect));
          if TRIGGER = 0 then
            xc := '1';
          end if;
        when CSR_TDATA2         =>
          csr := csr_file.tcsr.tdata2(u2i(csr_file.tcsr.tselect));
          if TRIGGER = 0 then
            xc := '1';
          end if;
        when CSR_TDATA3         =>
          csr := csr_file.tcsr.tdata3(u2i(csr_file.tcsr.tselect));
          if TRIGGER = 0 then
            xc := '1';
          end if;
        when CSR_TINFO          =>
          csr := to0x(csr_file.tcsr.tinfo(u2i(csr_file.tcsr.tselect)));
          if TRIGGER = 0 then
            xc := '1';
          end if;
        -- Core Debug Registers
        when CSR_DCSR           =>
          csr(31 downto 28)     := csr_file.dcsr.xdebugver;
          if h_en then
            csr(17)             := csr_file.dcsr.ebreakvs;
            csr(16)             := csr_file.dcsr.ebreakvu;
          end if;
          csr(15)               := csr_file.dcsr.ebreakm;
          csr(13)               := csr_file.dcsr.ebreaks;
          csr(12)               := csr_file.dcsr.ebreaku;
          csr(11)               := csr_file.dcsr.stepie;
          csr(10)               := csr_file.dcsr.stopcount;
          csr(9)                := csr_file.dcsr.stoptime;
          csr(8 downto 6)       := csr_file.dcsr.cause;
          if h_en then
            csr(5)                := csr_file.dcsr.v;
          end if;
          csr(4)                := csr_file.dcsr.mprven;
          csr(3)                := csr_file.dcsr.nmip;
          csr(2)                := csr_file.dcsr.step;
          csr(1 downto 0)       := csr_file.dcsr.prv;
        when CSR_DPC            => csr := csr_file.dpc;
        when CSR_DSCRATCH0      => csr := csr_file.dscratch0;
        when CSR_DSCRATCH1      => csr := csr_file.dscratch1;
        when CSR_FEATURES       =>
          csr(31)               := csr_file.dfeaturesen.tpbuf_en;
          -- [25:14] RESERVED
          csr(13)               := csr_file.dfeaturesen.dm_trace;
          csr(12)               := csr_file.dfeaturesen.new_irq;
          csr(11)               := csr_file.dfeaturesen.fs_dirty;
          csr(10)               := csr_file.dfeaturesen.nostream;
          csr(9)                := csr_file.dfeaturesen.staticdir;
          csr(8)                := csr_file.dfeaturesen.staticbp;
          csr(7)                := csr_file.dfeaturesen.mmu_adfault;
          csr(6)                := csr_file.dfeaturesen.b2bst_dis;
          csr(5)                := csr_file.dfeaturesen.lalu_dis;
          csr(4)                := csr_file.dfeaturesen.lbranch_dis;
          csr(3)                := csr_file.dfeaturesen.ras_dis;
          csr(2)                := csr_file.dfeaturesen.jprd_dis;
          csr(1)                := csr_file.dfeaturesen.btb_dis;
          csr(0)                := csr_file.dfeaturesen.dual_dis;
        when CSR_FEATURESH      =>
          if is_rv32 then
          else
            xc := '1';
          end if;
        when CSR_CCTRL          =>
          csr(13)               := mmu_csr.cctrl.iflushpend;
          csr(12)               := mmu_csr.cctrl.dflushpend;
          -- Bit[11] is RESERVED
          if itcmen = 1 then
            csr(10)             := mmu_csr.cctrl.itcmwipe;
          end if;
          if dtcmen = 1 then
            csr(9)              := mmu_csr.cctrl.dtcmwipe;
          end if;
          csr(8)                := csr_file.cctrl.dsnoop;
          csr(7)                := csr_file.cctrl.dflush;
          csr(6)                := csr_file.cctrl.iflush;
          -- Bit[5:4] is RESERVED
          csr(3 downto 2)       := csr_file.cctrl.dcs;
          csr(1 downto 0)       := csr_file.cctrl.ics;
        when CSR_TCMICTRL       =>
          xc := '1';
        when CSR_TCMDCTRL       =>
          xc := '1';
        when CSR_CAPABILITY =>
          csr                   := to_capability(u2vec(fpuconf, 2), mmu_csr.cconfig);
        when CSR_CAPABILITYH =>
          if is_rv32 then
            csr(word'range)     := to_capabilityh(u2vec(fpuconf, 2), mmu_csr.cconfig);
          else
            xc := '1';
          end if;
        when others =>
          case csra_high is
            -- Machine|User Hardware Performance Monitoring
            when CSR_CYCLE |         -- Base for counters.
                 CSR_MCYCLE =>
              if csra_low = 1 then   -- There is no CSR_MTIME!
                xc := '1';
              end if;
              -- CSR_(M)HPMCOUNTER3-15  (0-2 never _ok here!)
              if counter_ok(csra_low) = '1' then
                csr := csr_file.hpmcounter(csra_low)(wordx'range);
              end if;
            when CSR_CYCLEH |         -- Base for counters.
                 CSR_MCYCLEH =>
              if not is_rv32 or csra_low = 1 then   -- There is no CSR_MTIMEH!
                xc := '1';
              end if;
              -- CSR_(M)HPMCOUNTER3-15H  (0-2 never _ok here!)
              if is_rv32 and counter_ok(csra_low) = '1' then
                csr := to0x(csr_file.hpmcounter(csra_low)(63 downto 32));
              end if;
            -- Machine|User Hardware Performance Monitoring (continued)
            when CSR_HPMCOUNTER16 |  -- All the higher counters.
                 CSR_MHPMCOUNTER16 =>
              -- CSR_(M)HPMCOUNTER16-31
              if counter_ok(csra_low + 16) = '1' then
                csr := csr_file.hpmcounter(csra_low + 16)(wordx'range);
              end if;
            when CSR_HPMCOUNTER16H |  -- All the higher counters.
                 CSR_MHPMCOUNTER16H =>
              if not is_rv32 then
                xc := '1';
              end if;
              -- CSR_(M)HPMCOUNTER16-31H
              if is_rv32 and counter_ok(csra_low + 16) = '1' then
                csr := to0x(csr_file.hpmcounter(csra_low + 16)(63 downto 32));
              end if;
            -- According to the RISC-V documentation, the value read back from
            -- CSR_PMPADDR<x> will depend on pmpcfg<x> setting under some circumstances.
            when CSR_PMPADDR0 =>
              if csra_low < pmp_entries then
                csr(pmp_msb - 2 downto 0) := csr_file.pmpaddr(csra_low)(pmp_msb - 2 downto 0);
                if pmpcfg(pmp_entries, csr_file, csra_low)(4) = '1' then  -- NA4/NAPOT
                  csr(pmp_g - 2 downto 0) := (others => '1');
                else                                                      -- OFF/TOR
                  csr(pmp_g - 1 downto 0) := (others => '0');
                end if;
              end if;
            -- Machine Performance Monitoring Counter Selector
            when CSR_MCOUNTINHIBIT =>  -- MCOUNTINHIBIT/MHPMEVENT3-15
              if csra_low = 1 or       --  There is nothing at second/third position.
                 csra_low = 2 then
                xc := '1';
              end if;
              -- CSR_MHPMEVENT3-15  (0-2 never _ok here!)
              if counter_ok(csra_low) = '1' then
                csr := to_hpmevent(csr_file.hpmevent(csra_low));
              end if;
            when CSR_MHPMEVENT16 =>  -- MHPMEVENT16-31
              if counter_ok(csra_low + 16) = '1' then
                csr := to_hpmevent(csr_file.hpmevent(csra_low + 16));
              end if;
            when CSR_MHPMEVENT0H =>  -- MHPMEVENT3-15H
              if not is_rv32 or csra_low < 3 then  --  There is nothing at 0-2.
                xc := '1';
              end if;
              -- CSR_MHPMEVENT3-15  (0-2 never _ok here!)
              if is_rv32 and counter_ok(csra_low) = '1' then
                csr := to_hpmeventh(csr_file.hpmevent(csra_low));
              end if;
            when CSR_MHPMEVENT16H =>  -- MHPMEVENT16-31H
              if not is_rv32 then
                xc := '1';
              end if;
              if is_rv32 and counter_ok(csra_low + 16) = '1' then
                csr := to_hpmeventh(csr_file.hpmevent(csra_low + 16));
              end if;
            when others =>
              xc := '1';
          end case;
      end case;
    end if;

    -- Check for privileged level and read/write accessibility
    -- The standard RISC-V ISA sets aside a 12-bit encoding space (csr[11:0])
    -- for up to 4,096 CSRs. By convention, the upper 4 bits of the CSR address
    -- (csr[11:8]) are used to encode the read and write accessibility of the
    -- CSRs according to privilege level as shown in Table 2.1. The top two
    -- bits (csr[11:10]) indicate whether the register is read/write (00, 01, or 10)
    -- or read-only (11). The next two bits (csr[9:8]) encode the lowest privilege
    -- level that can access the CSR.
    if rstate_in = run and csrv_in = '1' then
      -- Lower Privileged Level
      priv_lvl    := csr_file.prv and csra_in(9 downto 8);
      priv_lvlv   := csr_file.prv and csra_in(9 downto 8);
      if h_en and csr_file.v = '0' then
        priv_lvlv := (csr_file.prv(0) & csr_file.prv(1)) and csra_in(9 downto 8);
      end if;
        if priv_lvl  /= csra_in(9 downto 8) and
           priv_lvlv /= csra_in(9 downto 8) then
          xc      := '1';
        end if;
        -- Debug Module Registers Access
        if csra_in(11 downto 4) = "01111011" then
          xc      := '1';
        end if;
      -- Performance Features
      -- Hardware Performance Features
      -- (CYCLE, TIME, INSTRET, HPMCOUNTERn)
      -- Bit 7 is high for the ...H CSR variants.
      if csra_in(11 downto 8) = x"c" and csra_in(6 downto 5) = "00" then
        if csr_file.mcounteren(u2i(csra_in(4 downto 0))) = '0' then
          if csr_file.prv = PRIV_LVL_S or csr_file.prv = PRIV_LVL_U then
            xc := '1';
          end if;
        elsif h_en and csr_file.v = '1' and
              csr_file.hcounteren(u2i(csra_in(4 downto 0))) = '0' then
          xc   := '1';
          xc_v := '1';
        elsif mode_u = 1 and csr_file.prv = PRIV_LVL_U and
              csr_file.scounteren(u2i(csra_in(4 downto 0))) = '0' then
          xc   := '1';
        end if;
      end if;
    end if;

    -- Mask output if exception occured.
    if xc = '1' then
      csr       := zerox;
    end if;

    data_out    := csr;
    xc_out      := xc;
    if xc_v = '1' then
      cause_out := XC_INST_VIRTUAL_INST;  -- Only valid when xc_out.
    else
      cause_out := XC_INST_ILLEGAL_INST;  -- Only valid when xc_out.
    end if;
  end;


  function cause_bit(bits : std_logic_vector; cause : cause_type) return std_logic is
    variable n : integer := u2i(cause(cause'high - 1 downto 0));
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

  -- Interrupt code priority
  constant cause_prio : cause_arr(0 to 15) := (
    IRQ_M_EXTERNAL,  IRQ_M_SOFTWARE,  IRQ_M_TIMER,
    IRQ_S_EXTERNAL,  IRQ_S_SOFTWARE,  IRQ_S_TIMER,
    IRQ_SG_EXTERNAL,
    IRQ_VS_EXTERNAL, IRQ_VS_SOFTWARE, IRQ_VS_TIMER,
    IRQ_LCOF,
    IRQ_UNUSED, IRQ_UNUSED, IRQ_UNUSED, IRQ_UNUSED, IRQ_UNUSED
  );

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
    ext_sscofpmf : integer) return wordx is
    -- Non-constant
    variable mideleg : wordx := zerox;
    variable mask    : wordx := zerox;
  begin
    if mode_s /= 0 then
      if ext_sscofpmf /= 0 then
        mask(cause2int(IRQ_LCOF)) := '1';
      end if;
      mask := mask or CSR_MIDELEG_MASK;
    end if;

    mideleg := wcsr and mask;

    -- VS-level interrupts are always delegeted to HS-mode
    if h_en then
      mideleg := mideleg or CSR_HIE_MASK;
    end if;

    return mideleg;
  end;

  -- Return mask for mip
  function mip_mask(mode_s : integer; h_en : boolean;
                    ext_sscofpmf : integer;
                    menvcfg_stce : std_ulogic) return wordx is
    -- Non-constant
    variable mask : wordx := CSR_MIP_MASK;
  begin
    if ext_sscofpmf /= 0 then
      mask(cause2int(IRQ_LCOF)) := '1';
    end if;
    if mode_s /= 0 then
      mask := mask or CSR_SIP_MASK;
    end if;
    if h_en then
      mask := mask or CSR_HIP_MASK;
    end if;

    -- When Sstc extension is enabled STIP is read-only
    if menvcfg_stce = '1' then
      mask(5) := '0';
    end if;

    return mask;
  end;

  -- Return mask for mie
  function mie_mask(mode_s : integer; h_en : boolean;
                    ext_sscofpmf : integer) return wordx is
    -- Non-constant
    variable mask : wordx := CSR_MIE_MASK;
  begin
    if ext_sscofpmf /= 0 then
      mask(cause2int(IRQ_LCOF)) := '1';
    end if;
    if mode_s /= 0 then
      mask := mask or CSR_SIE_MASK;
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

    mstatus.mpv := wdata(7);
    mstatus.gva := wdata(6);

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
    variable ustatus : csr_status_type;
  begin

    -- Keep the values for the mstatus fields
    ustatus      := mstatus;

    ustatus.upie := wdata(4);
    ustatus.uie  := wdata(0);

    return ustatus;
  end;

  function envcfg_mask(envcfg : csr_envcfg_type; mask : csr_envcfg_type) return csr_envcfg_type is
    -- Non-constant
    variable xenvcfg : csr_envcfg_type;
  begin
    xenvcfg.stce  := envcfg.stce  and mask.stce;
    xenvcfg.pbmte := envcfg.pbmte and mask.pbmte;
    xenvcfg.cbze  := envcfg.cbze  and mask.cbze;
    xenvcfg.cbcfe := envcfg.cbcfe and mask.cbcfe;
    xenvcfg.cbie  := envcfg.cbie  and (mask.cbie'range => orv(mask.cbie));
    xenvcfg.fiom  := envcfg.fiom  and mask.fiom;
    return xenvcfg;
  end;
  -- Return envcfg as an XLEN bit data from the record type
  function to_envcfg(envcfg : csr_envcfg_type) return wordx is
    -- Non-constant
    variable xenvcfg : word64 := zerow64;
  begin
    xenvcfg(63)         := envcfg.stce;
    xenvcfg(62)         := envcfg.pbmte;
    xenvcfg(7)          := envcfg.cbze;
    xenvcfg(6)          := envcfg.cbcfe;
    xenvcfg(5 downto 4) := envcfg.cbie;
    xenvcfg(0)          := envcfg.fiom;
    return xenvcfg(wordx'range);
  end;
  -- Return envcfg as an XLEN bit data from the record type
  function to_envcfg(envcfg : csr_envcfg_type; mask : csr_envcfg_type) return wordx is
    -- Non-constant
    variable xenvcfg : csr_envcfg_type := envcfg_mask(envcfg, mask);
  begin
    return to_envcfg(xenvcfg);
  end;
  -- Return envcfg as a record type from an XLEN bit data
  function to_envcfg(wdata  : wordx;
                     envcfg : csr_envcfg_type;
                     mask   : csr_envcfg_type) return csr_envcfg_type is
    -- Non-constant
    variable xenvcfg : csr_envcfg_type := envcfg;
  begin
    if XLEN = 64 then
      xenvcfg.stce  := wdata(63*(XLEN/64)) and mask.stce;
      xenvcfg.pbmte := wdata(62*(XLEN/64)) and mask.pbmte;
    end if;
    xenvcfg.cbze  := wdata(7) and mask.cbze;
    xenvcfg.cbcfe := wdata(6) and mask.cbcfe;
    xenvcfg.cbie  := wdata(5 downto 4) and mask.cbie;
    xenvcfg.fiom  := wdata(0) and mask.fiom;
    return xenvcfg;
  end;

  -- Return envcfgh as an XLEN bit data from the record type
  function to_envcfgh(envcfg : csr_envcfg_type) return wordx is
    -- Non-constant
    variable xenvcfgh : word64 := zerow64;
  begin
    xenvcfgh(31 downto 30) := envcfg.stce & envcfg.pbmte;
    return xenvcfgh(wordx'range);
  end;
  -- Return envcfgh as an XLEN bit data from the record type
  function to_envcfgh(envcfg : csr_envcfg_type; mask : csr_envcfg_type) return wordx is
    -- Non-constant
    variable xenvcfg : csr_envcfg_type := envcfg_mask(envcfg, mask);
  begin
    return to_envcfgh(xenvcfg);
  end;
  -- Return envcfgh as a record type from an XLEN bit data
  function to_envcfgh(wdata   : wordx;
                      envcfg  : csr_envcfg_type;
                      mask    : csr_envcfg_type) return csr_envcfg_type is
    -- Non-constant
    variable xenvcfg : csr_envcfg_type := envcfg;
  begin
    xenvcfg.stce  := wdata(31) and mask.stce;
    xenvcfg.pbmte := wdata(30) and mask.pbmte;
    return xenvcfg;
  end;

  function gen_envcfg_mmask(active : extension_type) return csr_envcfg_type is 
    constant sstc   : boolean := is_enabled(active, x_sstc);
    constant pbmte  : boolean := false; --is_enabled(active, x_svpbmt);
    constant zicboz : boolean := false; --is_enabled(active, x_zicboz);
    constant zicbom : boolean := is_enabled(active, x_zicbom);
    constant fiom   : boolean := false; --is_enabled(active, x_fiom);
    -- Non-constant
    variable xenvcfg : csr_envcfg_type := csr_envcfg_rst;
  begin
    xenvcfg.stce  := to_bit(sstc);
    xenvcfg.pbmte := to_bit(pbmte);
    xenvcfg.cbze  := to_bit(zicboz);
    xenvcfg.cbcfe := to_bit(zicbom);
    xenvcfg.cbie  := (others => to_bit(zicbom));
    xenvcfg.fiom  := to_bit(fiom);
    return xenvcfg;
  end;
  function gen_envcfg_smask(active : extension_type) return csr_envcfg_type is 
    constant zicboz : boolean := false; --is_enabled(active, x_zicboz);
    constant zicbom : boolean := is_enabled(active, x_zicbom);
    constant fiom   : boolean := false; --is_enabled(active, x_fiom);
    -- Non-constant
    variable xenvcfg : csr_envcfg_type := csr_envcfg_rst;
  begin
    xenvcfg.cbze  := to_bit(zicboz);
    xenvcfg.cbcfe := to_bit(zicbom);
    xenvcfg.cbie  := (others => to_bit(zicbom));
    xenvcfg.fiom  := to_bit(fiom);
    return xenvcfg;
  end;
  
  
  function to_capabilityh(fpuconf : std_logic_vector(1 downto 0); cconfig : word64) return word is
    variable data : word := zerow;
  begin
    data               := cconfig(cconfig'high downto cconfig'length/2);
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

  function hpmevent(event : integer) return hpmevent_type is
  begin
    return to_hpmevent(u2vec(event, XLEN), hpmevent_none);
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
    mask                         := uadd(mask,  1);
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
        high                     := uadd(high, 1);
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

end;
