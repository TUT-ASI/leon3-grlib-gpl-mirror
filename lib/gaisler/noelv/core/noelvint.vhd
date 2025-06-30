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
use grlib.riscv.reg_t;
library gaisler;
use gaisler.l5nv_shared.all;
use gaisler.busif5_types.all;
use gaisler.noelvtypes.all;
use gaisler.noelv.all;

package noelvint is

  type pmpcfg_vec_type  is array (0 to PMPENTRIES - 1) of word8;
  type pmpaddr_vec_type is array (0 to PMPENTRIES - 1) of pmpaddr_type;
  type pmaaddr_vec_type is array (0 to PMAENTRIES - 1) of pmpaddr_type;

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


  type atp_type is record
    mmu    : integer range 0 to 3;
    ppn    : std_logic_vector(43 downto 0);
    id     : word16;
    normal : boolean;  -- Bare if neither of these
    small  : boolean;  -- Sv39(x4) under Sv48(x4)
  end record;

  constant atp_none : atp_type := (0, (others => '0'), (others => '0'), false, false);

  type nv_csr_out_type is record
    hartid        : std_logic_vector(HARTIDLEN-1 downto 0);
    satp          : atp_type;
    vsatp         : atp_type;
    hgatp         : atp_type;
    m_adue        : std_ulogic; -- Hardware handling of accessed/modified bits in sPT/hPT (svadu).
    vs_adue       : std_ulogic; -- Hardware handling of accessed/modified bits in vsPT (svadu).
    h_ade         : std_ulogic; -- Exception for accessed/modified bits in hPT (custom).
    pma_fault_02  : std_ulogic; -- PMA fault for all address between 0 and 2G.
    pma_fault_46  : std_ulogic; -- PMA fault for all address between 4G and 6G.
    mmu_sptfault  : std_ulogic; -- Take page fault on any sPT walk.
    mmu_hptfault  : std_ulogic; -- Take page fault on any hPT walk.
    mmu_oldfence  : std_ulogic; -- Use old sfence/hfence mechanism.
    pmpcfg        : pmpcfg_vec_type;
    precalc       : pmp_precalc_vec(0 to PMPENTRIES - 1);
    pma_precalc   : pmp_precalc_vec(0 to PMAENTRIES - 1);
    pma_data      : word64_arr(0 to PMAENTRIES - 1);
    mmwp          : std_ulogic;
    mml           : std_ulogic;
    menvcfg_sse   : std_ulogic;
    henvcfg_sse   : std_ulogic;
    cctrl         : csr_out_cctrl_type;
  end record;

  constant nv_csr_out_type_none : nv_csr_out_type := (
    hartid        => (others => '0'),
    satp          => atp_none,
    vsatp         => atp_none,
    hgatp         => atp_none,
    m_adue        => '0',
    vs_adue       => '0',
    h_ade         => '0',
    pma_fault_02  => '0',
    pma_fault_46  => '0',
    mmu_sptfault  => '0',
    mmu_hptfault  => '0',
    mmu_oldfence  => '0',
    pmpcfg        => (others => (others => '0')),
    precalc       => (others => pmp_precalc_none),
    pma_precalc   => (others => pmp_precalc_none),
    pma_data      => (others => zerow64),
    mmwp          => '0',
    mml           => '0',
    menvcfg_sse   => '0',
    henvcfg_sse   => '0',
    cctrl        => csr_out_cctrl_rst
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

  -- FPU ------------------------------------------------------------------

  type fpu5_in_type is record
    inst        : word;                          -- Issue interface
    e_valid     : std_ulogic;
    issue_id    : fpu_id;
    csrfrm      : std_logic_vector(2 downto 0);
--    e_nullify   : std_ulogic;
    mode        : std_logic_vector(2 downto 0);  --   Pass along for logging
    commit      : std_ulogic;                    -- Commit/unissue interface
    commit_id   : fpu_id;
    data_id     : fpu_id;
    data_valid  : std_ulogic;
--    data        : word64;
    unissue     : std_ulogic;
    unissue_id  : fpu_id;
    flush       : std_logic_vector(1 to 4);      --   Pipeline Flush
    ctrl        : std_logic_vector(8 downto 0);  -- Debug control
  end record;

  constant fpu5_in_none : fpu5_in_type := (
    inst        => (others => '0'),
    e_valid     => '0',
    issue_id    => (others => '0'),
    csrfrm      => (others => '0'),
--    e_nullify   => '0',
    mode        => (others => '0'),
    commit      => '0',
    commit_id   => (others => '0'),
    data_id     => (others => '0'),
    data_valid  => '0',
--    data        => (others => '0'),
    unissue     => '0',
    unissue_id  => (others => '0'),
    flush       => (others => '0'),
    ctrl        => (others => '0')
    );

  type fpu5_in_async_type is record
    e_nullify   : std_ulogic;
    data        : word64;
  end record;

  constant fpu5_in_async_none : fpu5_in_async_type := (
    e_nullify     => '0',
    data        => (others => '0')
  );

  type fpu5_out_type is record
    rd          : reg_t;
    wen         : std_ulogic;
    data        : word64;                        -- Result interface
    flags_wen   : std_ulogic;
    flags       : flags_t;
    mode        : std_logic_vector(2 downto 0);
    wb_id       : fpu_id;
    events      : word64;
  end record;

  constant fpu5_out_none : fpu5_out_type := (
    rd          => (others => '0'),
    wen         => '0',
    data        => (others => '0'),
    flags_wen   => '0',
    flags       => (others => '0'),
    mode        => (others => '0'),
    wb_id       => (others => '0'),
    events      => (others => '0')
    );

  type fpu5_out_async_type is record
    holdn       : std_ulogic;                    -- Issue interface
    ready       : std_ulogic;
    idle        : std_ulogic;
    now2int     : std_ulogic;                    -- Result to IU
    id2int      : fpu_id;                        --  These are muxed after the clock,
    data2int    : word64;                        --  to save a cycle when the IU
    flags2int   : flags_t;                       --  is waiting on data from FPU.
  end record;

  constant fpu5_out_async_none : fpu5_out_async_type := (
    holdn       => '1',
    ready       => '1',
    idle        => '1',
    now2int     => '0',
    id2int      => (others => '0'),
    data2int    => (others => '0'),
    flags2int   => (others => '0')
    );


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
    vms              : std_logic_vector(2 downto 0);  -- [Virtualization mode, machine mode, supervisor mode]
  end record;

  type nv_icache_out_type is record
    --data        : nv_cdatatype;
    data        : cdatatype5;
    way         : std_logic_vector(log2(MAXWAYS) - 1 downto 0);
    mexc        : std_ulogic;
    mexcdata    : std_logic_vector(7 downto 0);
    exctype     : std_ulogic;
    exchyper    : std_ulogic;
    addrhyper   : addr_type;
    typehyper   : std_logic_vector(1 downto 0);  -- 00 OK, 01 data RW, 10 PT R, 11 - PT W
    hold        : std_ulogic;
    flush       : std_ulogic;                    -- flush in progress
    mds         : std_ulogic;                    -- memory data strobe
    cfg         : std_logic_vector(31 downto 0);
    bpmiss      : std_ulogic;
    eocl        : std_ulogic;
    badtag      : std_ulogic;
    ics_btb     : std_logic_vector(1 downto 0);
    btb_flush   : std_logic;
    ctxswitch   : std_ulogic;
    parked      : std_ulogic;
  end record;

  constant nv_icache_out_none : nv_icache_out_type := (
    (others => (others => '0')), (others => '0'), '0',
    (others => '0'), '0', '0', (others => '0'),
    (others => '0'), '0', '0', '0',
    (others => '0'), '0', '0', '0',
    (others => '0'), '0', '0', '0'
    );
    

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
    atomic           : std_ulogic;
    cas              : std_ulogic;
    casdata          : std_logic_vector(31 downto 0);
    --
    flush            : std_ulogic;
    dsuen            : std_ulogic;
    msu              : std_ulogic;                   -- memory stage supervisor
    esu              : std_ulogic;                   -- execution stage supervisor
    vms              : std_logic_vector(2 downto 0); -- [Virtualization mode, machine mode, supervisor mode]
    sum              : std_ulogic;                   -- Allow S to access U memory (except for execution).
    mxr              : std_ulogic;                   -- Make X-only pages readable (S MMU). PMP not affected!
    vmxr             : std_ulogic;                   -- Make X-only pages readable (VS MMU). PMP not affected!
    hx               : std_ulogic;                   -- Hypervisor HLVX load instruction. Execute permission needed
    ss               : std_ulogic;                   -- Shadow stack access
    intack           : std_ulogic;
    eread            : std_ulogic;
    mmucacheclr      : std_ulogic;
    trapack          : std_ulogic;
    trapacktt        : std_logic_vector(7 downto 0);
    trapackpc        : std_logic_vector(31 downto 0);
    trapackidata     : std_logic_vector(7 downto 0);
    --
    amo              : std_logic_vector(5 downto 0);
    cbo              : std_logic_vector(2 downto 0);
    bar              : std_logic_vector(2 downto 0);
    --iudiag_miso      : nv_intreg_miso_type;
    iudiag_miso      : l5_intreg_miso_type;
  end record;

  constant nv_dcache_in_none : nv_dcache_in_type := (
    x"00", (others => '0'), x"00", (others => '0'), zerow64, "00",
    '0', '0', '0', '0', '0', '0', '0', '0',
    '0', '0', (others => '0'),
    '0', '0', '0', '0',  
    "000", '0', '0', '0', '0',
    '0',
    '0', '0', '0',
    '0', x"00", (others => '0'), x"00",
    "000000", "000", "000", l5_intreg_miso_none
  );

  type iu_control_reg_type is record
    fpspec       : std_ulogic;
    dlatealu     : std_ulogic;
    single_issue : std_ulogic;
    dbtb         : std_ulogic;
    dlatewicc    : std_ulogic;
    dlatearith   : std_ulogic;
    fbtb         : std_ulogic;
    fbp          : std_ulogic;
    staticbp     : std_ulogic;
    staticd      : std_ulogic;
  end record;

  constant iu_control_reg_default: iu_control_reg_type := (
    fpspec       => '1',
    dlatealu     => '0',
    single_issue => '0',
    dbtb         => '0',
    dlatewicc    => '0',
    dlatearith   => '0',
    fbtb         => '0',
    fbp          => '0',
    staticbp     => '0',
    staticd      => '1'
    );
    --

  type nv_dcache_out_type is record
    data        : cdatatype5;
    way         : std_logic_vector(log2(MAXWAYS) - 1 downto 0);
    mexc        : std_ulogic;
    exctype     : std_ulogic;
    exchyper    : std_ulogic;
    addrhyper   : addr_type;
    typehyper   : std_logic_vector(1 downto 0);  -- 00 OK, 01 data RW, 10 PT R, 11 - PT W
    hold        : std_ulogic;
    mds         : std_ulogic;
    dtrapet1    : std_ulogic;
    dtrapet0    : std_ulogic;
    dtraptt     : std_logic_vector(5 downto 0);
    --
    werr        : std_ulogic;
    cache       : std_ulogic;
    wbhold      : std_ulogic;                   -- write buffer hold
    badtag      : std_ulogic;
    iudiag_mosi : l5_intreg_mosi_type;
    iuctrl      : iu_control_reg_type;
    --
  end record;

  constant nv_dcache_out_none : nv_dcache_out_type := (
    (others => (others => '0')), (others => '0'), '0', '0', '0',
    (others => '0'), "00", '0', '0',
    '0', '0', (others => '0'),
    '0', '0', '0', '0',
    l5_intreg_mosi_none, iu_control_reg_default
    );


  type nv_cram_in_type is record
    iindex      : cache_index;
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
    dtagcindex  : cache_index;
    dtagcen     : std_logic_vector(0 to 7);
    -- Cache update and snoop hit port
    dtaguindex  : cache_index;
    dtaguwrite  : std_logic_vector(0 to 7);
    dtagudin    : cram_tags;
    -- Combined read/update port (without snoop hit)
    dtagcuindex : cache_index;
    dtagcuen    : std_logic_vector(0 to 7);
    dtagcuwrite : std_ulogic;
    -- Snoop tag read and write
    dtagsindex  : cache_index;
    dtagsen     : std_logic_vector(0 to 7);
    dtagswrite  : std_ulogic;
    dtagsdin    : cram_tags;
    -- DCache data
    ddataindex  : cache_index;
    ddataoffs   : std_logic_vector(1 downto 0);
    ddataen     : std_logic_vector(0 to 7);
    ddatawrite  : word8;
    ddatadin    : cdatatype5;
    ddatafulladdr : std_logic_vector(31 downto 0);
    dtcmen      : std_ulogic;
    dtcmdin     : word64;
    dtcmwrite   : word8;
  end record;

  constant nv_cram_in_none : nv_cram_in_type := (
    iindex      => (others => '0'),
    itagen      => (others => '0'),
    itagwrite   => '0',
    itagdin     => (others => (others => '0')),
    idataoffs   => (others => '0'),
    idataen     => (others => '0'),
    idatawrite  => (others => '0'),
    idatadin    => zerow64,
    ifulladdr   => zerow,
    itcmen      => '0',
    itcmwrite   => (others => '0'),
    itcmdin     => zerow64,
    -- Cache read port
    dtagcindex  => (others => '0'),
    dtagcen     => (others => '0'),
    -- Cache update and snoop hit port
    dtaguindex  => (others => '0'),
    dtaguwrite  => (others => '0'),
    dtagudin    => (others => (others => '0')),
    -- Combined read/update port (without snoop hit)
    dtagcuindex => (others => '0'),
    dtagcuen    => (others => '0'),
    dtagcuwrite => '0',
    -- Snoop tag read and write
    dtagsindex  => (others => '0'),
    dtagsen     => (others => '0'),
    dtagswrite  => '0',
    dtagsdin    => (others => (others => '0')),
    -- DCache data
    ddataindex  => (others => '0'),
    ddataoffs   => (others => '0'),
    ddataen     => (others => '0'),
    ddatawrite  => (others => '0'),
    ddatadin    => (others => zerow64),
    ddatafulladdr => zerow,
    dtcmen      => '0',
    dtcmdin     => zerow64,
    dtcmwrite   => (others => '0')
  );

  type nv_cram_out_type is record
    itagdout  : cram_tags;
    idatadout : cdatatype5;
    itcmdout  : word64;
    dtagcdout : cram_tags;
    dtagsdout : cram_tags;
    ddatadout : cdatatype5;
    dtcmdout  : word64;
  end record;

  -- Instruction Trace ----------------------------------------------------
  subtype trace_addr is std_logic_vector(11 downto 0);
  type nv_trace_in_type is record
    addr             : trace_addr;
    data             : trace_data;
    enable           : std_ulogic;
    write            : trace_sel;
  end record;

  type nv_trace_out_type is record
    data             : trace_data;
  end record;


  type trace_lane is record
    valid      : std_ulogic;
    exception  : std_ulogic;
    compressed : std_ulogic;
    int_res    : std_ulogic;
    csr_write  : std_ulogic;
    memory     : std_ulogic;
    cfi        : std_ulogic;
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
    memory     => '0',
    cfi        => '0',
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
    cause     : cause_type;
  end record;

  constant trace_info_none : trace_info := (
    timestamp => zerow,
    swap      => '0',
    lanes     => (others => trace_lane_none),
    prv       => "00",
    v         => '0',
    cause     => cause_res
  );

  type itrace_in_type is record
    hartid      : std_logic_vector(HARTIDLEN-1 downto 0);
    holdn       : std_ulogic;
    rstate      : std_logic_vector(1 downto 0);
    is_amo      : boolean;
    is_ld       : boolean;
    is_st       : boolean;
    dm_tbufaddr : trace_addr;
    dm_trace    : std_ulogic;
    trace       : trace_type;
    tpbuf_en    : std_ulogic;
    info        : trace_info;

  end record;

  constant itrace_in_none : itrace_in_type := (
    hartid      => (others => '0'),
    holdn       => '1',
    rstate      => "00",
    is_amo      => false,
    is_ld       => false,
    is_st       => false,
    dm_tbufaddr => (others => '0'),
    dm_trace    => '0',
    trace       => trace_rst,
    tpbuf_en    => '0',
    info        => trace_info_none
  );

  type itrace_out_type is record
    tcnt       : trace_addr;
    taddr      : trace_addr;
    idata      : trace_data;
    write      : trace_sel;
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




  -- IMSIC Interrupt Files ------------------------------------------------
  type imsic_in_type is record
    mtopei_w  : std_ulogic;                              -- Machine top external interrupt write
    stopei_w  : std_ulogic;                              -- Supervisor top external interrupt write
    vstopei_w : std_ulogic;                              -- Virtual Supervisor top external interrupt write

    miselect  : std_logic_vector(XLEN-1 downto 0);       -- Machine indirect register select value
    siselect  : std_logic_vector(XLEN-1 downto 0);       -- Supervisor indirect register select value
    vsiselect : std_logic_vector(XLEN-1 downto 0);       -- Virtual Supervisor indirect register select value

    mireg     : std_logic_vector(XLEN-1 downto 0);       -- Machine indirect register alias value
    sireg     : std_logic_vector(XLEN-1 downto 0);       -- Supervisor indirect register alias value
    vsireg    : std_logic_vector(XLEN-1 downto 0);       -- Virtual Supervisor indirect register alias value

    mireg_w   : std_ulogic;                              -- Machine indirect register alias write
    sireg_w   : std_ulogic;                              -- Supervisor indirect register alias write
    vsireg_w  : std_ulogic;                              -- Virtual Supervisor indirect register alias write
    vgein     : std_logic_vector(5 downto 0);            -- Current HSTATUS.VGEIN CSR value
  end record;

  type imsic_out_type is record
    mtopei   : std_logic_vector(XLEN-1 downto 0);        -- Machine top external interrupt register value
    stopei   : std_logic_vector(XLEN-1 downto 0);        -- Supervisor top external interrupt register value
    vstopei  : std_logic_vector(XLEN-1 downto 0);        -- Virtual top external interrupt register value

    mireg    : std_logic_vector(XLEN-1 downto 0);        -- Machine indirect register alias value
    sireg    : std_logic_vector(XLEN-1 downto 0);        -- Supervisor indirect register alias value
    vsireg   : std_logic_vector(XLEN-1 downto 0);        -- Virtual indirect register alias value
  end record;


  constant imsic_in_none : imsic_in_type := (
    mtopei_w  => '0',
    stopei_w  => '0',
    vstopei_w => '0',

    miselect  => (others => '0'),
    siselect  => (others => '0'),
    vsiselect => (others => '0'),

    mireg     => (others => '0'),
    sireg     => (others => '0'),
    vsireg    => (others => '0'),

    mireg_w   => '0',
    sireg_w   => '0',
    vsireg_w  => '0',
    vgein     => (others => '0')
    );

  constant imsic_out_none : imsic_out_type := (
    mtopei   => (others => '0'),
    stopei   => (others => '0'),
    vstopei  => (others => '0'),

    mireg    => (others => '0'),
    sireg    => (others => '0'),
    vsireg   => (others => '0')
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

  -----------------------------------------------------------------------------
  -- Components
  -----------------------------------------------------------------------------

  component itracenv is
    generic (
      fabtech      : integer range 0 to NTECH;
      memtech      : integer range 0 to NTECH;
      single_issue : integer range 0 to 1;
      dmen         : integer range 0 to 1;
      tbuf         : integer;
      disas        : integer;
      scantest     : integer
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
      fabtech          : integer range 0  to NTECH;    -- fabtech
      memtech          : integer range 0  to NTECH;    -- memtech
      -- Core
      physaddr         : integer range 32 to 56;       -- Physical Addressing
      addr_bits        : integer range 32 to 64;       -- Max bits required for an address
      rstaddr          : integer;                      -- Reset vector (MSB)
      perf_cnts        : integer range 0  to 29;       -- Number of performance counters
      perf_evts        : integer range 0  to 255;      -- Number of performance events
      perf_bits        : integer range 0  to 64;       -- Bits of performance counting
      illegalTval0     : integer range 0  to 1;        -- Zero TVAL on illegal instruction
      no_muladd        : integer range 0  to 1;        -- 1 - multiply-add not supported
      single_issue     : integer range 0  to 1;        -- 1 - only one pipeline
      -- Caches
      iways            : integer range 1  to 8;        -- I$ Ways
      dways            : integer range 1  to 8;        -- D$ Ways
      dlinesize        : integer range 4  to 8;        -- D$ Cache Line Size (words)
      itcmen           : integer range 0  to 1;        -- Instruction TCM
      dtcmen           : integer range 0  to 1;        -- Data TCM
      -- MMU
      mmuen            : integer range 0  to 2;        -- >0 - MMU enable
      riscv_mmu        : integer range 0  to 3;        -- sparc / sv32 / sv39 /s48
      pmp_no_tor       : integer range 0  to 1;        -- Disable PMP TOR (not with TLB PMP)
      pmp_entries      : integer range 0  to 16;       -- Implemented PMP registers
      pmp_g            : integer range 0  to 10;       -- PMP grain is 2^(pmp_g + 2) bytes
      pma_entries      : integer range 0  to 16;       -- Implemented PMA entries
--      pma_addr         : word64_arr             := word64_arr_empty; -- PMA addresses
     -- pma_data         : word64_arr             := word64_arr_empty; -- PMA configuration
      pma_masked       : integer range 0  to 1;        -- PMA done using masks
      asidlen          : integer range 0  to 16;       -- Max 9 for Sv32
      vmidlen          : integer range 0  to 14;       -- Max 7 for Sv32
      -- Interrupts
      imsic            : integer range 0  to 1;        -- IMSIC implemented
      -- RNMI
      rnmi_iaddr       : integer;                      -- RNMI interrupt trap handler address
      rnmi_xaddr       : integer;                      -- RNMI exception trap handler address
      -- Extensions
      ext_noelv        : integer range 0  to 1;        -- NOEL-V Extensions
      ext_noelvalu     : integer range 0  to 1;        -- NOEL-V ALU Extensions
      ext_m            : integer range 0  to 1;        -- M Base Extension Set
      ext_a            : integer range 0  to 1;        -- A Base Extension Set
      ext_c            : integer range 0  to 1;        -- C Base Extension Set
      ext_h            : integer range 0  to 1;        -- H Extension
      ext_zcb          : integer range 0  to 1;        -- Zcb Extension
      ext_zba          : integer range 0  to 1;        -- Zba Extension
      ext_zbb          : integer range 0  to 1;        -- Zbb Extension
      ext_zbc          : integer range 0  to 1;        -- Zbc Extension
      ext_zbs          : integer range 0  to 1;        -- Zbs Extension
      ext_zbkb         : integer range 0  to 1;        -- Zbkb Extension
      ext_zbkc         : integer range 0  to 1;        -- Zbkc Extension
      ext_zbkx         : integer range 0  to 1;        -- Zbkx Extension
      ext_sscofpmf     : integer range 0  to 1;        -- Sscofpmf Extension
      ext_shlcofideleg : integer range 0  to 1;     -- Shlcofideleg Extension
      ext_smcdeleg     : integer range 0  to 1;        -- Smcdleg Extension
      ext_sstc         : integer range 0  to 2;        -- Sctc Extension (2 : only time csr impl.)
      ext_smaia        : integer range 0  to 1;        -- Smaia Extension
      ext_ssaia        : integer range 0  to 1;        -- Ssaia Extension
      ext_smstateen    : integer range 0  to 1;        -- Smstateen Extension
      ext_smrnmi       : integer range 0  to 1;        -- Smrnmi Extension
      ext_ssdbltrp     : integer range 0  to 1;        -- Ssdbltrp Extension
      ext_smdbltrp     : integer range 0  to 1;        -- Smdbltrp Extension
      ext_smepmp       : integer range 0  to 1;        -- Smepmp Extension
      ext_svadu        : integer range 0  to 1;        -- Svadu Extension
      ext_zicbom       : integer range 0  to 1;        -- Zicbom Extension
      ext_zicond       : integer range 0  to 1;        -- Zicond Extension
      ext_zimop        : integer range 0  to 1;        -- Zimop Extension
      ext_zcmop        : integer range 0  to 1;        -- Zcmop Extension
      ext_zicfiss      : integer range 0  to 1;        -- Zicfiss Extension
      ext_zicfilp      : integer range 0  to 1;        -- Zicfilp Extension
      ext_svinval      : integer range 0  to 1;        -- Svinval Extension
      ext_zfa          : integer range 0  to 1;        -- Zfa Extension
      ext_zfh          : integer range 0  to 1;        -- Zfh Extension
      ext_zfhmin       : integer range 0  to 1;        -- Zfhmin Extension
      ext_zfbfmin      : integer range 0  to 1;        -- Zfbfmin Extension
      mode_s           : integer range 0  to 1;        -- Supervisor Mode Support
      mode_u           : integer range 0  to 1;        -- User Mode Support
      dmen             : integer range 0  to 1;        -- Using RISC-V Debug Module
      fpulen           : integer range 0  to 128;      -- Floating-point precision
      fpuconf          : integer range 0  to 1;        -- 0 = nanoFPUnv, 1 = GRFPUnv
      trigger          : integer range 0  to 4096;
      -- Advanced Features
      late_branch      : integer range 0  to 1;        -- Late Branch Support
      late_alu         : integer range 0  to 1;        -- Late ALUs Support
      ras              : integer range 0  to 2;        -- Return Address Stack (1 - test, 2 - enable)
      -- Misc
      pbaddr           : integer;                      -- Program buffer exe address
      tbuf             : integer;                      -- Trace buffer size in kB
      scantest         : integer;                      -- Scantest support
      rfreadhold       : integer range 0  to 1 := 0;   -- Register File Read Hold
--    dsuen_delay      : integer range 0  to 1 := 1;   -- Delay dbgi.dsuen (no UNOPTFLAT with Verilator)
--      show_misa_x       : integer range 0  to 1 := 1;   -- Extensions visible in MISA X
--      allow_x_ctrl      : integer range 0  to 1 := 1;   -- Allow X to be turned off
--      fpu_debug         : integer range 0  to 1 := 0;   -- FCSR bits for controlling the FPU
--      fpu_lane          : integer range 0  to 1 := 0;   -- Lane where (non-memory) FPU instructions go
      endian           : integer range 0  to 1 := GRLIB_CONFIG_ARRAY(grlib_little_endian)
      );
    port (
      clk            : in  std_ulogic;           -- Clock
      rstn           : in  std_ulogic;           -- Active low reset
      holdn          : in  std_ulogic;           -- Active low hold signal
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
      imsici         : out imsic_in_type;        -- IMSIC In Port
      imsico         : in  imsic_out_type;       -- IMSIC Out Port
      irqi           : in  nv_irq_in_type;       -- Irq In Port
      irqo           : out nv_irq_out_type;      -- Irq Out Port
      dbgi           : in  nv_debug_in_type;     -- Debug In Port
      dbgo           : out nv_debug_out_type;    -- Debug Out Port
      muli           : out mul_in_type;          -- Mul Unit In Port
      mulo           : in  mul_out_type;         -- Mul Unit Out Port
      divi           : out div_in_type;          -- Div Unit In Port
      divo           : in  div_out_type;         -- Div Unit Out Port
      fpui           : out fpu5_in_type;         -- FPU Unit In Port
      fpuia          : out fpu5_in_async_type;   -- FPU Unit In Port
      fpuo           : in  fpu5_out_type;        -- FPU Unit Out Port
      fpuoa          : in  fpu5_out_async_type;  -- FPU Unit Out Port
      cnt            : out nv_counter_out_type;  -- Perf event Out Port
      itracei        : out itrace_in_type;       -- Trace information
      itraceo        : in  itrace_out_type;      -- Trace control
      pma_addr       : in  word64_arr(0 to PMAENTRIES - 1); -- PMA addresses
      pma_data       : in  word64_arr(0 to PMAENTRIES - 1); -- PMA configuration
      csr_mmu        : out nv_csr_out_type;      -- CSR values for MMU
      mmu_csr        : in  nv_csr_in_type;       -- CSR values for MMU
      perf           : in  std_logic_vector(31 downto 0);  -- Performance data
      cap            : in  std_logic_vector(9  downto 0);  -- Trace capability
      tbo            : in  nv_trace_out_type;    -- Trace Unit Out Port
      eto            : out nv_etrace_type;       -- E-trace output
      sclk           : in  std_ulogic;           -- [Currently unused]
      pwrd           : out std_ulogic;           -- Activate power down mode
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
      trace_in  : in  nv_trace_in_type;
      trace_out : out nv_trace_out_type;
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
      reg0write   : integer := 0;
      forward     : integer := 1  -- Turn on internal forwarding
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


  component cctrl5nv is
    generic (
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
      -- RISCV
      htlbnum    : integer range 1 to  64;   -- # hypervisor TLB entries
      mmuen      : integer range 0 to   1;
      riscv_mmu  : integer range 0 to   3;
      pmp_no_tor : integer range 0 to   1;   -- Disable PMP TOR (not with TLB PMP)
      pmp_entries: integer range 0 to  16;   -- Implemented PMP registers
      pmp_g      : integer range 0 to  10;   -- PMP grain is 2^(pmp_g + 2) bytes
      pma_entries: integer range 0 to  16;   -- Implemented PMA entries
      pma_masked : integer range 0 to   1;   -- PMA done using masks
      asidlen    : integer range 0 to  16;   -- Max 9 for Sv32
      vmidlen    : integer range 0 to  14;   -- Max 7 for Sv32
      ext_noelv  : integer range 0 to   1;   -- NOEL-V Extensions
      ext_a      : integer range 0 to   1;   -- Support for Atomic operations
      ext_h      : integer range 0 to   1;   -- Support for Hypervisor, needs tlb_pmp if any PMP.
      ext_smepmp : integer range 0 to   1;   -- Support for Smepmp extension
      ext_zicbom : integer range 0 to   1;   -- Support for Zicbom extension
      ext_svpbmt : integer range 0 to   1;   -- Support for Svpbmt Extension
      ext_svnapot : integer range 0 to  1;   -- Support for Svnapot Extension
      ext_zicfiss : integer range 0 to  1;   -- Zicfiss Extension
      tlb_pmp    : integer range 0 to   1;   -- Do PMP via TLB
      --
      cached    : integer;
      wbmask    : integer;
      busw      : integer;
      cdataw    : integer;
      tlbrepl   : integer;
      addrbits  : integer := 32;
      iphysbits : integer := 32;
      dphysbits : integer := 32
    );
    port (
      rst      : in  std_ulogic;
      clk      : in  std_ulogic;
      ici      : in  nv_icache_in_type;
      ico      : out nv_icache_out_type;
      dci      : in  nv_dcache_in_type;
      dco      : out nv_dcache_out_type;
      ahbso    : in  ahb_slv_out_vector;  -- For PnP cacheability info
      endian   : in  std_ulogic := '0';
      crami    : out cram_in_type5;
      cramo    : in  cram_out_type5;
      bifi     : out busif_in_type5;
      bifo     : in  busif_out_type5;
      sclk     : in  std_ulogic;
      fpc_mosi : out l5_intreg_mosi_type;
      fpc_miso : in  l5_intreg_miso_type;
      c2c_mosi : out l5_intreg_mosi_type;
      c2c_miso : in  l5_intreg_miso_type;
      csro       : in  nv_csr_out_type := nv_csr_out_type_none;
      csri       : out nv_csr_in_type  := nv_csr_in_type_none;
      --
      freeze   : in  std_ulogic;
      bootword : in  std_logic_vector(31 downto 0);
      smpflush : in  std_logic_vector(1 downto 0);
      perf     : out std_logic_vector(31 downto 0)
      );
  end component;

  component imsic_int_files
    generic (
      GEILEN       : integer                   := 0;
      S_EN         : integer range 0 to 1      := 0;
      H_EN         : integer range 0 to 1      := 0;
      plic         : integer range 0 to 1      := 0;
      mnidentities : integer range 63 to 2047  := 63; 
      snidentities : integer range 63 to 2047  := 63; 
      gnidentities : integer range 63 to 2047  := 63
      );
    port (
      rst        : in  std_ulogic;
      clk        : in  std_ulogic;
      irqi       : in  imsic_irq_type;
      acko       : out std_ulogic;
      plic_meip  : in  std_ulogic;
      plic_seip  : in  std_ulogic;
      imsici     : in  imsic_in_type;
      imsico     : out imsic_out_type;
      eip        : out nv_irq_in_type
      );
  end component;

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
      pcbits      : integer range 32 to 56        := 32;
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
      pcbits      : integer range 32 to 56        := 32
      );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      rasi        : in  nv_ras_in_type;
      raso        : out nv_ras_out_type
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
      fpi         : in  fpu5_in_type;
      fpia        : in  fpu5_in_async_type;
      fpo         : out fpu5_out_type;
      fpoa        : out fpu5_out_async_type;
      rs1         : out reg_t;
      rs2         : out reg_t;
      rs3         : out reg_t;
      ren         : out std_logic_vector(1 to 3);
      s1          : in  word64;
      s2          : in  word64;
      s3          : in  word64
      );
  end component;

  component pipefpunv is
    generic (
      fpulen      : integer range 0 to 128;
      ext_zfa     : integer range 0 to 1;
      ext_zfh     : integer range 0 to 1;
      ext_zfhmin  : integer range 0 to 1;
      ext_zfbfmin : integer range 0 to 1;
      mulconf     : integer range 0 to 1
    );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      holdn       : in  std_ulogic;
      fpi         : in  fpu5_in_type;
      fpia        : in  fpu5_in_async_type;
      fpo         : out fpu5_out_type;
      fpoa        : out fpu5_out_async_type;
      rs1         : out reg_t;
      rs2         : out reg_t;
      rs3         : out reg_t;
      ren         : out std_logic_vector(1 to 3);
      s1          : in  word64;
      s2          : in  word64;
      s3          : in  word64
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
      memen         : in  std_ulogic;                       -- Memory access
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
