
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
-- Package:     noelvint
-- File:        noelvint.vhd
-- Description: Internal components and types for NOEL-V
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.amba.all;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.log2;
library gaisler;
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

package noelvint is

  constant PMPENTRIES           : integer := 16;
  constant PMPADDRBITS          : integer := 54;
  constant MAX_TRIGGER_NUM      : integer := 4;

  subtype cause_type is std_logic_vector(5 downto 0);

  subtype word8  is std_logic_vector( 7 downto 0);
  subtype word16 is std_logic_vector(15 downto 0);
  subtype word64 is std_logic_vector(63 downto 0);
  subtype word   is std_logic_vector(31 downto 0);
  subtype wordx  is std_logic_vector(XLEN - 1 downto 0);

  constant zerow16      : word16 := (others => '0');
  constant zerow64      : word64 := (others => '0');
  constant zerox        : wordx  := (others => '0');
  constant zerow        : word   := (others => '0');

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------
  constant NOELV_VERSION        : integer := 2;
  constant NOELV_TRACE_VERSION  : integer := 1;

  constant TRACE_WIDTH  : integer := 512
-- pragma translate_off
                                     + 2 * (64 + 16)
-- pragma translate_on
                                     ;
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

  constant MAXWAYS : integer := 8;
  constant TAGMAX  : integer := 32;
  constant IDXMAX  : integer := 16;

  constant MAX_PREDICTOR_BITS  : integer := 2;

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

  type nv_csr_out_type is record
    satp        : wordx;
    vsatp       : wordx;
    hgatp       : wordx;
    mmu_adfault : std_ulogic;   -- Take page fault on access/modify.
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

  type trace_type is record
    ctrl         : word;
  end record;

  constant trace_rst : trace_type := (
    ctrl         => zerow
  );


  -----------------------------------------------------------------------------
  -- Types
  -----------------------------------------------------------------------------

  subtype reg_t is std_logic_vector(4 downto 0);

  -- FPU ------------------------------------------------------------------

  subtype fpu_id is std_logic_vector(4 downto 0);

  type fpu5_in_type is record
    inst        : word;
    e_valid     : std_ulogic;
    issue_id    : fpu_id;
    csrfrm      : std_logic_vector(2 downto 0);
    flush       : std_logic_vector(1 to 4);               -- Pipeline Flush
    e_nullify   : std_ulogic;
    commit      : std_ulogic;
    commit_id   : fpu_id;
    unissue     : std_ulogic;
    unissue_id  : fpu_id;
    data_id     : fpu_id;
    data_valid  : std_ulogic;
    data        : word64;
    mode        : std_logic_vector(2 downto 0);           -- Pass along for logging
    ctrl        : std_logic_vector(8 downto 0);           -- Debug control
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
    data        : word64;
    data2int    : word64;
    rd          : reg_t;
    wen         : std_ulogic;
    flags       : std_logic_vector(4 downto 0);
    flags_wen   : std_ulogic; 
    flags2int   : std_logic_vector(4 downto 0);
    ready       : std_ulogic;
    holdn       : std_ulogic;
    mode        : std_logic_vector(2 downto 0);
    wb_id       : fpu_id;
    idle        : std_ulogic;
    now2int     : std_ulogic;
    id2int      : fpu_id;
    events      : word64;
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
    raddr1      : reg_t;
    raddr2      : reg_t;
    raddr3      : reg_t;
    raddr4      : reg_t;
    ren1        : std_ulogic;
    ren2        : std_ulogic;
    ren3        : std_ulogic;
    ren4        : std_ulogic;
    rdhold      : std_ulogic;
    waddr1      : reg_t;
    waddr2      : reg_t;
    wdata1      : wordx;
    wdata2      : wordx;
    wen1        : std_ulogic;
    wen2        : std_ulogic;
  end record;

  type fregfile_in_type is record
    raddr1      : reg_t;
    raddr2      : reg_t;
    raddr3      : reg_t;
    ren         : std_logic_vector(1 to 3);
    waddr1      : reg_t;
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
  type nv_cdatatype is array (0 to MAXWAYS - 1) of word64;


  subtype addr_type is word64;

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
    edata            : word64;
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
    cbo              : std_logic_vector(2 downto 0);
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

  type cram_tags is array(0 to 7) of std_logic_vector(TAGMAX - 1 downto 0);

  type nv_cram_in_type is record
    iindex      : std_logic_vector(IDXMAX-1 downto 0);
    itagen      : std_logic_vector(0 to 7);
    itagwrite   : std_ulogic;
    itagdin     : cram_tags;
    idataoffs   : std_logic_vector(1 downto 0);
    idataen     : std_logic_vector(0 to 7);
    idatawrite  : std_logic_vector(1 downto 0);
    idatadin    : word64;
    ifulladdr   : std_logic_vector(31 downto 0);
    itcmen      : std_ulogic;
    itcmwrite   : std_logic_vector(1 downto 0);
    itcmdin     : word64;
    -- Cache read port
    dtagcindex  : std_logic_vector(IDXMAX-1 downto 0);
    dtagcen     : std_logic_vector(0 to 7);
    -- Cache update and snoop hit port
    dtaguindex  : std_logic_vector(IDXMAX-1 downto 0);
    dtaguwrite  : std_logic_vector(0 to 7);
    dtagudin    : cram_tags;
    -- Combined read/update port (without snoop hit)
    dtagcuindex : std_logic_vector(IDXMAX-1 downto 0);
    dtagcuen    : std_logic_vector(0 to 7);
    dtagcuwrite : std_ulogic;
    -- Snoop tag read and write
    dtagsindex  : std_logic_vector(IDXMAX-1 downto 0);
    dtagsen     : std_logic_vector(0 to 7);
    dtagswrite  : std_ulogic;
    dtagsdin    : cram_tags;
    -- DCache data
    ddataindex  : std_logic_vector(IDXMAX-1 downto 0);
    ddataoffs   : std_logic_vector(1 downto 0);
    ddataen     : std_logic_vector(0 to 7);
    ddatawrite  : word8;
    ddatadin    : nv_cdatatype;
    ddatafulladdr : std_logic_vector(31 downto 0);
    dtcmen      : std_ulogic;
    dtcmdin     : word64;
    dtcmwrite   : word8;
  end record;

  type nv_cram_out_type is record
    itagdout  : cram_tags;
    idatadout : nv_cdatatype;
    itcmdout  : word64;
    dtagcdout : cram_tags;
    dtagsdout : cram_tags;
    ddatadout : nv_cdatatype;
    dtcmdout  : word64;
  end record;

  -- Instruction Trace ----------------------------------------------------
  subtype trace_addr is std_logic_vector(11 downto 0);
  type nv_trace_in_type is record
    addr             : trace_addr;
    data             : std_logic_vector(TRACE_WIDTH-1 downto 0);
    enable           : std_ulogic;
    write            : std_logic_vector(TRACE_SEL-1 downto 0);
  end record;

  type nv_trace_out_type is record
    data             : std_logic_vector(TRACE_WIDTH-1 downto 0);
  end record;

  type nv_trace_2p_in_type is record
    renable          : std_ulogic;
    raddr            : trace_addr;
    write            : std_logic_vector(TRACE_SEL-1 downto 0);
    waddr            : trace_addr;
    data             : std_logic_vector(TRACE_WIDTH-1 downto 0);
  end record;

  type nv_trace_2p_out_type is record
    data             : std_logic_vector(TRACE_WIDTH-1 downto 0);
  end record;

  type trace_lane is record
    valid      : std_ulogic;
    exception  : std_ulogic;
    compressed : std_ulogic;
    int_res    : std_ulogic;
    csr_write  : std_ulogic;
    pc         : wordx;
    inst       : word;
    cinst      : word16;
    result     : word64;   -- TVAL on exception, also store value
    xdata      : wordx;
  end record;

  constant trace_lane_none : trace_lane := (
    valid      => '0',
    exception  => '0',
    compressed => '0',
    int_res    => '0',
    csr_write  => '0',
    pc         => zerox,
    inst       => zerow,
    cinst      => zerow16,
    result     => zerow64,
    xdata      => zerox
  );

  type trace_lanes is array (integer range <>) of trace_lane;

  type trace_fpu is record
    available : std_ulogic;
    id        : fpu_id;
    rd        : reg_t;
    result    : word64;
  end record;

  constant trace_fpu_none : trace_fpu := (
    available => '0',
    id        => (others => '0'),
    rd        => (others => '0'),
    result    => zerow64
  );

  type trace_info is record
    timestamp : word;
    swap      : std_ulogic;
    lanes     : trace_lanes(0 to 1);
    prv       : std_logic_vector(1 downto 0);
    v         : std_ulogic;
    cause     : cause_type;  -- Top bit is IRQ
  end record;

  constant trace_info_none : trace_info := (
    timestamp => zerow,
    swap      => '0',
    lanes     => (others => trace_lane_none),
    prv       => "00",
    v         => '0',
    cause     => (others => '0')
  );
    
  type itrace_in_type is record
    holdn       : std_ulogic;
    rstate      : std_logic_vector(1 downto 0);
    is_amo      : boolean;
    is_ld       : boolean;
    is_st       : boolean;
--    logging     : std_ulogic;
    dm_tbufaddr : trace_addr;
    dm_trace    : std_ulogic;
--    trace_index : std_logic_vector(3 downto 0);
--    trace_wdata : wordx;
--    trace_w     : std_ulogic;
    trace       : trace_type;
    tpbuf_en    : std_ulogic;
    info        : trace_info;
  end record;

  constant itrace_in_none : itrace_in_type := (
    holdn       => '1',
    rstate      => "00",
    is_amo      => false,
    is_ld       => false,
    is_st       => false,
    dm_tbufaddr => (others => '0'),
    dm_trace    => '0',
    trace       => trace_rst,
    tpbuf_en    => '0',
--    idata       => (others => '0'),
    info        => trace_info_none
  );

  type itrace_out_type is record
    tcnt       : trace_addr;
    taddr      : trace_addr;
    idata      : std_logic_vector(TRACE_WIDTH - 1 downto 0);
    write      : std_logic_vector(TRACE_SEL-1 downto 0);
    enable     : std_ulogic;
  end record;

  constant itrace_out_none : itrace_out_type := (
    tcnt   => (others => '0'),
    taddr  => (others => '0'),
    idata  => (others => '0'),
    write  => (others => '0'),
    enable => '0'
  );

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
    phistory     : word64;
    ren          : std_ulogic;
    flush        : std_ulogic;
    iustall      : std_ulogic;
  end record;

  type nv_bht_out_type is record
    taken       : std_logic_vector(3 downto 0);
    bhistory    : std_logic_vector(4 downto 0);
    phistory    : word64;
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

  component itracenv is
    generic (
      hindex       : integer range 0 to 15;
      fabtech      : integer range 0 to NTECH;
      memtech      : integer range 0 to NTECH;
      single_issue : integer range 0 to 1;
      dmen         : integer range 0 to 1;
      tbuf         : integer;
      disas        : integer;
      scantest     : integer;
      pipeline     : integer range 0 to 3
    );
    port (
      clk     : in  std_ulogic;
      rstn    : in  std_ulogic;
      itracei : in  itrace_in_type;
      itraceo : out itrace_out_type;
      fpo     : in  fpu5_out_type;
      tbi     : out nv_trace_in_type;
      testen  : in  std_ulogic;
      testrst : in  std_ulogic
    );
  end component;

  component iunv
    generic (
      hindex       : integer range 0  to 15;       -- Hart index
      fabtech      : integer range 0  to NTECH;    -- fabtech
      memtech      : integer range 0  to NTECH;    -- memtech
      -- Core
      physaddr     : integer range 32 to 56;       -- Physical Addressing
      addr_bits    : integer range 32 to 56;       -- Max bits required for an address
      rstaddr      : integer;                      -- Reset vector (MSB)
      perf_cnts    : integer range 0  to 29;       -- Number of performance counters
      perf_evts    : integer range 0  to 255;      -- Number of performance events
      perf_bits    : integer range 0  to 64;       -- Bits of performance counting
      illegalTval0 : integer range 0  to 1;        -- Zero TVAL on illegal instruction
      no_muladd    : integer range 0  to 1;        -- 1 - multiply-add not supported
      single_issue : integer range 0  to 1;        -- 1 - only one pipeline
      -- Caches
      iways        : integer range 1  to 8;        -- I$ Ways
      dways        : integer range 1  to 8;        -- D$ Ways
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
      ext_sstc     : integer range 0  to 2;        -- Sctc Extension (2 : only time csr impl.)  
      ext_zicbom   : integer range 0  to 1;        -- Zicbom Extension
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
      itracei        : out itrace_in_type;
      itraceo        : in  itrace_out_type; 
      csr_mmu        : out nv_csr_out_type;         -- CSR values for MMU
      mmu_csr        : in  nv_csr_in_type;          -- CSR values for MMU
      perf           : in  std_logic_vector(31 downto 0);
      cap            : in  std_logic_vector(9  downto 0);
      tbo            : in  nv_trace_out_type;    -- Trace Unit Out Port
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
      reg0write   : integer := 0;
      dissue      : integer := 1;
      testen      : integer
      );
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      rdhold   : in  std_ulogic;
      waddr1   : in  reg_t;
      wdata1   : in  std_logic_vector;
      we1      : in  std_ulogic;
      waddr2   : in  reg_t;
      wdata2   : in  std_logic_vector;
      we2      : in  std_ulogic;
      raddr1   : in  reg_t;
      re1      : in  std_ulogic;
      rdata1   : out std_logic_vector;
      raddr2   : in  reg_t;
      re2      : in  std_ulogic;
      rdata2   : out std_logic_vector;
      raddr3   : in  reg_t;
      re3      : in  std_ulogic;
      rdata3   : out std_logic_vector;
      raddr4   : in  reg_t;
      re4      : in  std_ulogic;
      rdata4   : out std_logic_vector;
      testin   : in  std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
      );
  end component;

  component regfile64dffnv is
    generic (
      tech        : integer;
      wrfst       : integer;
      reg0write   : integer := 0
      );
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      rdhold   : in  std_ulogic;
      waddr1   : in  reg_t;
      wdata1   : in  std_logic_vector;
      we1      : in  std_ulogic;
      waddr2   : in  reg_t;
      wdata2   : in  std_logic_vector;
      we2      : in  std_ulogic;
      raddr1   : in  reg_t;
      re1      : in  std_ulogic;
      rdata1   : out std_logic_vector;
      raddr2   : in  reg_t;
      re2      : in  std_ulogic;
      rdata2   : out std_logic_vector;
      raddr3   : in  reg_t;
      re3      : in  std_ulogic;
      rdata3   : out std_logic_vector;
      raddr4   : in  reg_t;
      re4      : in  std_ulogic;
      rdata4   : out std_logic_vector
      );
  end component;

  component cachememnv is
    generic (
      tech      : integer range 0 to   NTECH;
      iways     : integer range 1 to   8;
      ilinesize : integer range 4 to   8;
      iidxwidth : integer range 1 to  10;
      itagwidth : integer range 1 to  32;
      itcmen    : integer range 0 to   1;
      itcmabits : integer range 1 to  20;
      dways     : integer range 1 to   8;
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
      iways      : integer range 1 to   8;   -- I$ ways
      ilinesize  : integer range 4 to   8;   --    cache line size (32 bit words)
      iwaysize   : integer range 1 to 256;   --    way size (KiB)
      dways      : integer range 1 to   8;   -- D$ ways
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
      ext_zicbom : integer range 0 to   1;   -- Support for Zicbom extension
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
      issue_id    : in  fpu_id;
      csrfrm      : in  std_logic_vector(2 downto 0);
      mode_in     : in  std_logic_vector(2 downto 0);
      s1          : in  word64;
      s2          : in  word64;
      s3          : in  word64;
      fpu_holdn   : out std_ulogic;
      ready_flop  : out std_ulogic;
      commit      : in  std_ulogic;
      commit_id   : in  fpu_id;
      lddata_id   : in  fpu_id;
      lddata_now  : in  std_ulogic;
      lddata      : in  word64;
      unissue     : in  std_ulogic;
      unissue_id  : in  fpu_id;
      rs1         : out reg_t;
      rs2         : out reg_t;
      rs3         : out reg_t;
      ren         : out std_logic_vector(1 to 3);
      rd          : out reg_t;
      wen         : out std_ulogic;
      stdata      : out word64;
      flags_wen   : out std_ulogic;
      flags       : out std_logic_vector(4 downto 0);
      now2int     : out std_ulogic;
      id2int      : out fpu_id;
      stdata2int  : out word64;
      flags2int   : out std_logic_vector(4 downto 0);
      wb_mode     : out std_logic_vector(2 downto 0);
      wb_id       : out fpu_id;
      idle        : out std_ulogic;
      events      : out word64
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
      issue_id    : in  fpu_id;
      csrfrm      : in  std_logic_vector(2 downto 0);
      mode_in     : in  std_logic_vector(2 downto 0);
      s1          : in  word64;
      s2          : in  word64;
      s3          : in  word64;
      fpu_holdn   : out std_ulogic;
      ready_flop  : out std_ulogic;
      commit      : in  std_ulogic;
      commit_id   : in  fpu_id;
      lddata_id   : in  fpu_id;
      lddata_now  : in  std_ulogic;
      lddata      : in  word64;
      unissue     : in  std_ulogic;
      unissue_id  : in  fpu_id;
      rs1         : out reg_t;
      rs2         : out reg_t;
      rs3         : out reg_t;
      ren         : out std_logic_vector(1 to 3);
      rd          : out reg_t;
      wen         : out std_ulogic;
      stdata      : out word64;
      flags_wen   : out std_ulogic;
      flags       : out std_logic_vector(4 downto 0);
      now2int     : out std_ulogic;
      id2int      : out fpu_id;
      stdata2int  : out word64;
      flags2int   : out std_logic_vector(4 downto 0);
      wb_mode     : out std_logic_vector(2 downto 0);
      wb_id       : out fpu_id;
      idle        : out std_ulogic;
      events      : out word64;
      ctrl        : in  std_logic_vector(8 downto 0) := "000000000"
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
      cycle         : in  word64;
      instret       : in  word64;
      dual          : in  word64;
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

end package;

package body noelvint is

  -----------------------------------------------------------------------------
  -- Functions Definitions
  -----------------------------------------------------------------------------



end package body;
