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
-- Entity:      noelv
-- File:        noelv.vhd
-- Author:      Andrea Merlo, Nils Wessman Cobham Gaisler AB
-- Description: NOEL-V types and components
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.ceil;

library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.log2x;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.uart.all;
use gaisler.noelv_cfg.all;

package noelv is

  constant XLEN                 : integer := NV_XLEN;
  constant FLEN                 : integer := 64;  -- Unused
  constant CAUSELEN             : integer := 6;
  constant DBITS                : integer := 16;  -- Use in one place

  constant GEILEN               : integer := 16;
  constant HARTIDLEN            : integer := 4;

  constant AIA_SUPPORT          : integer := 1;   -- 0 = AIA support is disabled in GRLIB
  constant ZICFISS_SUPPORT      : integer := 1;   -- 0 = ZICFISS support is disabled in GRLIB
  constant ZICFILP_SUPPORT      : integer := 1;   -- 0 = ZICFILP support is disabled in GRLIB
  constant SMRNMI_SUPPORT       : integer := 1;   -- 0 = SMRNMI support is disabled in GRLIB
  constant DBLTRP_SUPPORT       : integer := 1;   -- 0 = Double trap extensions support is disabled in GRLIB
  constant RDV_SUPPORT : integer := 1; -- 0 = disable extensions not supported in RISCV-DV

  constant NNMIRQ               : integer := 6;   -- Number of Resumable Non-Maskable Interrupts

  -- Types --------------------------------------------------------------------



  -- IMSIC --------------------------------------------------------------------
  constant MAX_HARTS : integer  := 16384;
  constant MAX_VHARTS : integer := XLEN-1;

  -- The number of sources in a interrupt file must be a multiple of 64 -1: from 63 to 2047
  type nidentities_vector is array (natural range <>) of integer range 0 to 2047;

  -- This type is used as an interface to comunicate interrupts from IMSIC AHB slave
  -- to CPU interrupt files.
  type imsic_irq_type is record
    -- 11 is the maximum number of bits for 2047 interrupt identities
    -- but not all of them are used.
    int_id       : std_logic_vector(10 downto 0);                  -- Interrupt identity
    supervisor   : std_logic;                                      -- Supervisor interrupt
    guest        : std_logic_vector(log2x(GEILEN+1)-1 downto 0);   -- Guest interrupt file
    data_rdy     : std_logic;
  end record;

  type imsic_irq_vector is array (natural range <>) of imsic_irq_type;

  constant imsic_irq_none : imsic_irq_type := (
    int_id       => (others => '0'),
    supervisor   => '0',
    guest        => (others => '0'),
    data_rdy     => '0'
  );



  subtype nv_nmirq_in_type is std_logic_vector(NNMIRQ-1 downto 0);

  -- Interrupt Bus ------------------------------------------------------------
  type nv_irq_in_type is record
    mtip        : std_ulogic; -- Machine Timer Interrupt
    msip        : std_ulogic; -- Machine Software Interrupt
    ssip        : std_ulogic; -- Supervisor Software Interrupt
    meip        : std_ulogic; -- Machine External Interrupt
    seip        : std_ulogic; -- Supervisor External Interrupt
    ueip        : std_ulogic; -- User External Interrupt
    heip        : std_ulogic; -- Reserved
    hgeip       : std_logic_vector(GEILEN downto 1); -- Hypervisor Guest External Interrupt
    stime       : std_logic_vector(63 downto 0);
    -- AIA signals
    imsic       : imsic_irq_type;       -- IMSIC interrupt signals
    aplic_meip  : std_ulogic;           -- Machine External Interrupt form APLIC 
    aplic_seip  : std_ulogic;           -- Supervisor External Interrupt form APLIC
    -- RNMI
    nmirq       : nv_nmirq_in_type;     -- Resumable Non-Maskable interrutps
  end record;

  type nv_irq_out_type is record
    imsic_ack   : std_ulogic;
    irqack      : std_ulogic;
  end record;

  type nv_irq_in_vector is array (natural range <>) of nv_irq_in_type;
  type nv_irq_out_vector is array (natural range <>) of nv_irq_out_type;

  constant nv_irq_in_none : nv_irq_in_type := (
    mtip       => '0',
    msip       => '0',
    ssip       => '0',
    meip       => '0',
    seip       => '0',
    ueip       => '0',
    heip       => '0',
    hgeip      => (others => '0'),
    stime      => (others => '0'),
    imsic      => imsic_irq_none,
    aplic_meip => '0',
    aplic_seip => '0',
    nmirq      => (others => '0')
    );


  -- Stats --------------------------------------------------------------------
  type nv_cstat_type is record
    cmiss       : std_ulogic; -- Cache Miss
    tmiss       : std_ulogic; -- TLB Miss
    chold       : std_ulogic; -- Cache Hold
    mhold       : std_ulogic; -- Cache MMU Hold
  end record;

  constant nv_cstat_none        : nv_cstat_type := (
    cmiss       => '0',
    tmiss       => '0',
    chold       => '0',
    mhold       => '0'
    );

  -- Perf Counters ---------------------------------------------------------------

  type nv_counter_out_type is record
    icnt     : std_logic_vector(1 downto 0);
    icmiss   : std_logic;
    itlbmiss : std_logic;
    dcmiss   : std_logic;
    dtlbmiss : std_logic;
    bpmiss   : std_logic;
    hold     : std_logic;
    --single_issue  : std_logic;
    --dual_issue    : std_logic;
    hold_issue    : std_logic;
    branch        : std_logic;
    --load_dep      : std_logic;
    --store_b2b     : std_logic;
    --jalr          : std_logic;
    --jal           : std_logic;
    --dcache_flush  : std_logic;
  end record;

  type nv_counter_out_vector is array (natural range <>) of nv_counter_out_type;

  -- Debug --------------------------------------------------------------------
  type nv_debug_in_type is record
    hartid      : std_logic_vector(HARTIDLEN-1 downto 0);
    dsuen       : std_ulogic;                           -- DSU Enable
    halt        : std_ulogic;                           -- Halt Request
    haltgroup   : std_ulogic;                           -- Halt Group Request
    resume      : std_ulogic;                           -- Resume Request
    reset       : std_ulogic;                           -- Reset Request
    haltonrst   : std_ulogic;                           -- Halt-on-reset Request
    freeze      : std_ulogic;                           -- Hold CPU
    denable     : std_ulogic;                           -- Diagnostic Enable
    dcmd        : std_logic_vector(1 downto 0);         -- Diagnostic Operation
    dwrite      : std_ulogic;                           -- Diagnostic Read/Write
    dsize       : std_logic_vector(2 downto 0);         -- Diagnostic Size Access
    daddr       : std_logic_vector(DBITS-1 downto 0);   -- Diagnostic Address
    ddata       : std_logic_vector(63 downto 0);        -- Diagnostic Data
    pbdata      : std_logic_vector(63 downto 0);
  end record;
  constant nv_debug_in_none : nv_debug_in_type := (
    hartid      => (others => '0'),
    dsuen       => '0',
    halt        => '0',
    haltgroup   => '0',
    resume      => '0',
    reset       => '0',
    haltonrst   => '0',
    freeze      => '0',
    denable     => '0',
    dcmd        => (others => '0'),
    dwrite      => '0',
    dsize       => (others => '0'),
    daddr       => (others => '0'),
    ddata       => (others => '0'),
    pbdata      => (others => '0'));

  type nv_debug_out_type is record
    dsu         : std_ulogic;                           -- DSU Enable
    error       : std_ulogic;                           -- Error signal
    halted      : std_ulogic;                           -- Halted Signal
    running     : std_ulogic;                           -- Running Signal
    --resumeack   : std_ulogic;                           -- Resume Ack Signal
    havereset   : std_ulogic;                           -- Have Reset Signal
    dvalid      : std_ulogic;                           -- Diagnostic Valid
    ddata       : std_logic_vector(63 downto 0);        -- Diagnostic Data
    derr        : std_ulogic;
    dexec_done  : std_ulogic;
    stoptime    : std_ulogic;
    pbaddr      : std_logic_vector(4 downto 0);
    istat       : nv_cstat_type;
    dstat       : nv_cstat_type;
    mcycle      : std_logic_vector(63 downto 0);
    cap         : std_logic_vector(9 downto 0);
  end record;

  constant nv_debug_out_none    : nv_debug_out_type := (
    dsu         => '0',
    error       => '0',
    halted      => '0',
    running     => '0',
    --resumeack   => '0',
    havereset   => '0',
    dvalid      => '0',
    ddata       => (others => '0'),
    derr        => '0',
    dexec_done  => '0',
    stoptime    => '0',
    pbaddr      => (others => '0'),
    istat       => nv_cstat_none,
    dstat       => nv_cstat_none,
    mcycle      => (others => '0'),
    cap         => (others => '0')
    );

  type nv_debug_in_vector  is array (natural range <>) of nv_debug_in_type;
  type nv_debug_out_vector is array (natural range <>) of nv_debug_out_type;

  subtype trace_d_type is std_logic_vector(1023 downto 0);
  type trace_d_vector is array (natural range<>) of trace_d_type;

  constant trace_d_none : trace_d_type := (others => '0');



  -- Hart-Encoder Interface
  type nv_etrace_type is record
    -- Mandatory signals
    itype     : std_logic_vector(3 downto 0);
    cause     : std_logic_vector(CAUSELEN-1 downto 0);
    tval      : std_logic_vector(XLEN-1 downto 0);
    priv      : std_logic_vector(2 downto 0);
    iaddr     : std_logic_vector(XLEN-1 downto 0);
    -- Optional signals
    ctext     : std_logic_vector(XLEN-1 downto 0);
    tetime    : std_logic_vector(XLEN-1 downto 0);
    ctype     : std_logic_vector(1 downto 0);
    sijump    : std_logic_vector(0 downto 0);
    -- Block Retire
    iretire   : std_logic_vector(2 downto 0);
    ilastsize : std_logic_vector(0 downto 0);
  end record;

  constant nv_etrace_none : nv_etrace_type := (
    itype     => (others => '0'),
    cause     => (others => '0'),
    tval      => (others => '0'),
    priv      => (others => '0'),
    iaddr     => (others => '0'),
    ctext     => (others => '0'),
    tetime    => (others => '0'),
    ctype     => (others => '0'),
    sijump    => (others => '0'),
    iretire   => (others => '0'),
    ilastsize => (others => '0')
  );

  type nv_etrace_vector is array (natural range <>) of nv_etrace_type;

  -- E-trace sink Interfaces
  type nv_etrace_sink_in_type is record
    full  : std_logic;
  end record;
  constant nv_etrace_sink_in_none : nv_etrace_sink_in_type := (
    full  => '0'
  );
  type nv_etrace_sink_in_vector is array (natural range <>) of nv_etrace_sink_in_type;
  type nv_etrace_sink_out_type is record
    en    : std_logic;
    data  : std_logic_vector(255 downto 0);
    size  : std_logic_vector(5 downto 0);
  end record;
  constant nv_etrace_sink_out_none : nv_etrace_sink_out_type := (
    en    => '0',
    data  => (others => '0'),
    size  => (others => '0')
  );
  type nv_etrace_sink_out_vector is array (natural range <>) of nv_etrace_sink_out_type;



  type nv_full_trace_type is record
    eto     : nv_etrace_type;
  end record;

  constant nv_full_trace_none : nv_full_trace_type := (
    eto     => nv_etrace_none
  );

  type nv_full_trace_vector is array (integer range <>) of nv_full_trace_type;

  type nv_dm_in_type is record
    enable      : std_ulogic;
    break       : std_ulogic;
  end record;

  constant nv_dm_in_none : nv_dm_in_type := (
    enable      => '0',
    break       => '0'
    );

  type nv_dm_out_type is record
    dmactive    : std_ulogic;
    ndmreset    : std_ulogic;
    pwd         : std_logic_vector(15 downto 0);
  end record;

  constant nv_dm_out_none : nv_dm_out_type := (
    dmactive    => '0',
    ndmreset    => '0',
    pwd         => (others => '0')
    );

  -- Components ------------------------------------------------------------
  component cpucorenv
    generic (
    hindex              : integer;
    fabtech             : integer range 0  to NTECH     := DEFFABTECH;
    memtech             : integer                       := DEFMEMTECH;
    cached              : integer                       := 0;
    wbmask              : integer                       := 0;
    busw                : integer                       := 64;
    physaddr            : integer range 32 to 56        := 32; -- Physical Addressing
    cmemconf            : integer                       := 0;
    rfconf              : integer                       := 0;
    fpuconf             : integer                       := 0;
    tcmconf             : integer                       := 0;
    mulconf             : integer                       := 0;
    intcconf            : integer                       := 0;
    cfg                 : integer                       := 0;
    disas               : integer                       := 0;  -- Disassembly to console
    scantest            : integer                       := 0;  -- scantest support
    cgen                : integer                       := 0;
    asyncif             : integer                       := 0
      );
    port (
      clk         : in  std_ulogic;          -- Clock
      gclk        : in  std_ulogic;          -- Gated clock
      rstn        : in  std_ulogic;
      ahbi        : in  ahb_mst_in_type;
      ahbo        : out ahb_mst_out_type;
      ahbsi       : in  ahb_slv_in_type;
      ahbso       : in  ahb_slv_out_vector;
      irqi        : in  nv_irq_in_type;      -- IRQ in
      irqo        : out nv_irq_out_type;     -- IRQ out
      dbgi        : in  nv_debug_in_type;    -- Debug in
      dbgo        : out nv_debug_out_type;   -- Debug out
      tpo         : out nv_full_trace_type;  -- Combined trace output
      cnt         : out nv_counter_out_type;
      pwrd        : out std_ulogic           -- Activate power down mode
      );
  end component;

  component noelvcpu is
    generic (
      hindex   : integer;
      fabtech  : integer;
      memtech  : integer;
      cached   : integer;
      wbmask   : integer;
      busw     : integer;
      physaddr : integer range 32 to 56 := 32;  -- Physical Addressing
      cmemconf : integer;
      rfconf   : integer;
      fpuconf  : integer;
      tcmconf  : integer;
      mulconf  : integer;
      intcconf : integer;
      mnintid  : integer;
      snintid  : integer;
      gnintid  : integer;
      disas    : integer;
      pbaddr   : integer;
      cfg      : integer;
      scantest : integer;
      cgen     : integer := 0;
      asyncif  : integer := 0
      );
    port (
      clk    : in  std_ulogic;
      gclk   : in  std_ulogic;
      rstn   : in  std_ulogic;
      ahbi   : in  ahb_mst_in_type;
      ahbo   : out ahb_mst_out_type;
      ahbsi  : in  ahb_slv_in_type;
      ahbso  : in  ahb_slv_out_vector;
      irqi   : in  nv_irq_in_type;
      irqo   : out nv_irq_out_type;
      dbgi   : in  nv_debug_in_type;
      dbgo   : out nv_debug_out_type;
      tpo    : out nv_full_trace_type;
      cnt    : out nv_counter_out_type;
      pwrd   : out std_ulogic
      );
  end component;

  component noelvsys is
    generic (
      fabtech  : integer;
      memtech  : integer;
      ncpu     : integer;
      nextmst  : integer;
      nextslv  : integer;
      nextapb  : integer;
      ndbgmst  : integer;
      nintdom  : integer := 4;
      neiid    : integer := 63;
      cached   : integer;
      wbmask   : integer;
      busw     : integer;
      cmemconf : integer;
      rfconf   : integer := 0;
      fpuconf  : integer;
      tcmconf  : integer := 0;
      mulconf  : integer := 0;
      intcconf : integer := 0;
      disas    : integer;
      ahbtrace : integer;
      cfg      : integer := 0;
      devid    : integer := 0;
      nodbus   : integer := 0;
      trace    : integer := 0;
      scantest : integer := 0
      );
    port (
      clk      : in  std_ulogic;
      gclk     : in  std_logic_vector(ncpu-1 downto 0);
      rstn     : in  std_ulogic;
      -- Power down mode
      pwrd     : out std_logic_vector(ncpu-1 downto 0);
      -- AHB bus interface for other masters (DMA units)
      ahbmi    : out ahb_mst_in_type;
      ahbmo    : in  ahb_mst_out_vector_type(ncpu+nextmst-1 downto ncpu);
      -- AHB bus interface for slaves (memory controllers, etc)
      ahbsi    : out ahb_slv_in_type;
      ahbso    : in  ahb_slv_out_vector_type(nextslv-1 downto 0);
      -- AHB master interface for debug links
      dbgmi    : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
      dbgmo    : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
      -- APB interface for external APB slaves
      apbi     : out apb_slv_in_type;
      apbo     : in  apb_slv_out_vector;
      -- Bootstrap signals
      dsuen    : in  std_ulogic;
      dsubreak : in  std_ulogic;
      cpu0errn : out std_ulogic;
      -- UART connection
      uarti    : in  uart_in_type;
      uarto    : out uart_out_type;
      -- Perf counter
      cnt      : out nv_counter_out_vector(ncpu-1 downto 0);
      -- E-trace sink interface
      etso     : out nv_etrace_sink_out_vector(ncpu-1 downto 0);
      etsi     : in  nv_etrace_sink_in_vector(ncpu-1 downto 0) := (others => nv_etrace_sink_in_none);
      -- DFT support
      testen  : in  std_ulogic := '0';
      testrst : in  std_ulogic := '1';
      scanen  : in  std_ulogic := '0';
      testoen : in  std_ulogic := '1';
      testsig : in  std_logic_vector(1+GRLIB_CONFIG_ARRAY(grlib_techmap_testin_extra) downto 0) := (others => '0')
      );
  end component;


  component dmnv is
    generic (
      fabtech   : integer;
      memtech   : integer;
      ncpu      : integer;
      ndbgmst   : integer;
      -- Conventional bus
      cbmidx    : integer;
      -- PnP
      dmhaddr   : integer;
      dmhmask   : integer;
      pnpaddrhi : integer;
      pnpaddrlo : integer;
      dmslvidx  : integer;
      dmmstidx  : integer;
      -- trace
      tbits     : integer;
      --
      scantest  : integer;
      -- Pipelining
      plmdata   : integer
      );
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      -- Debug-link interface
      dbgmi    : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
      dbgmo    : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
      -- Conventional AHB bus interface
      cbmi    : in  ahb_mst_in_type;
      cbmo    : out ahb_mst_out_type;
      cbsi    : in  ahb_slv_in_type;
      --
      dbgi   : in  nv_debug_out_vector(0 to ncpu-1);
      dbgo   : out nv_debug_in_vector(0 to ncpu-1);
      dsui   : in  nv_dm_in_type;
      dsuo   : out nv_dm_out_type
      );
  end component;

  component rvdm
    generic (
      hindex      : integer range 0  to 15        := 0;   -- bus index
      haddr       : integer                       := 16#900#;
      hmask       : integer                       := 16#f00#;
      nharts      : integer                       := 1;   -- number of harts
      tbits       : integer                       := 30;  -- timer bits (instruction trace time tag)
      tech        : integer                       := DEFMEMTECH;
      kbytes      : integer                       := 0;   -- Size of trace buffer memory in KiB
      --bwidth      : integer                       := 64;  -- Traced AHB bus width
      --ahbpf       : integer                       := 0;
      --ahbwp       : integer                       := 2;
      scantest    : integer                       := 0
      );
    port (
      rst    : in  std_ulogic;
      clk    : in  std_ulogic;
      ahbmi  : in  ahb_mst_in_type;
      ahbsi  : in  ahb_slv_in_type;
      ahbso  : out ahb_slv_out_type;
      dbgi   : in  nv_debug_out_vector(0 to NHARTS-1);
      dbgo   : out nv_debug_in_vector(0 to NHARTS-1);
      dsui   : in  nv_dm_in_type;
      dsuo   : out nv_dm_out_type
      );
  end component;

  component clint is
    generic (
      pindex      : integer range 0 to NAPBSLV-1  := 0;
      paddr       : integer range 0 to 16#FFF#    := 0;
      pmask       : integer range 0 to 16#FFF#    := 16#FFF#;
      ncpu        : integer range 0 to 4096       := 4
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      rtc         : in  std_ulogic;
      apbi        : in  apb_slv_in_type;
      apbo        : out apb_slv_out_type;
      halt        : in  std_ulogic;
      irqi        : in  std_logic_vector(ncpu*4-1 downto 0);
      irqo        : out nv_irq_in_vector(0 to ncpu-1)
      );
  end component;

  component clint_ahb is
    generic (
      hindex      : integer range 0 to NAPBSLV-1  := 0;
      haddr       : integer range 0 to 16#FFF#    := 0;
      hmask       : integer range 0 to 16#FFF#    := 16#FFF#;
      ncpu        : integer range 0 to 4096       := 4
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      rtc         : in  std_ulogic;
      ahbi        : in  ahb_slv_in_type;
      ahbo        : out ahb_slv_out_type;
      halt        : in  std_ulogic;
      irqi        : in  std_logic_vector(ncpu*4-1 downto 0);
      irqo        : out nv_irq_in_vector(0 to ncpu-1)
      );
  end component;

  component imsic_ahb
    generic (
      hindex          : integer range 0 to NAHBSLV-1  := 0;
      haddr           : integer range 0 to 16#FFF#    := 0;
      ncpu            : integer range 0 to MAX_HARTS  := 0;
      GEILEN          : integer                       := 0;
      groups          : integer                       := 0;
      S_EN            : integer range 0 to 1          := 0;
      H_EN            : integer range 0 to 1          := 0;
      mnidentities_vector : nidentities_vector;
      snidentities_vector : nidentities_vector;
      gnidentities_vector : nidentities_vector
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      ahbi        : in  ahb_slv_in_type;
      ahbo        : out ahb_slv_out_type;
      irq_ack     : in  std_logic_vector(0 to ncpu-1);
      irqo        : out imsic_irq_vector(0 to ncpu-1)
      );
  end component;

  component aclint_ahb is
    generic (
      hindex  : integer range 0 to NAPBSLV-1  := 0;
      haddr   : integer range 0 to 16#FFF#    := 0;
      hmask   : integer range 0 to 16#FFF#    := 16#FFF#;
      hirq1   : integer range 0 to NAHBSLV-1  := 0;
      hirq2   : integer range 0 to NAHBSLV-1  := 0;
      ncpu    : integer range 0 to 4096       := 4;
      -- ACLINT devices
      mswi    : integer range 0 to 1          := 1;
      mtimer  : integer range 0 to 1          := 1;
      sswi    : integer range 0 to 1          := 1;
      -- Watchdog
      watchdog    : integer range 0 to 1      := 1;
      wdtickbit   : integer range 0 to 63     := 4
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      rtc         : in  std_ulogic;
      ahbi        : in  ahb_slv_in_type;
      ahbo        : out ahb_slv_out_type;
      halt        : in  std_ulogic;
      irqi        : in  nv_irq_in_vector(0 to ncpu-1);
      irqo        : out nv_irq_in_vector(0 to ncpu-1)
      );
  end component;

  component dummy_pnp is
    generic (
      hindex  : integer;
      ioarea  : integer;
      devid   : integer
    );
    port (
      ahbsi    : in  ahb_slv_in_type;
      ahbso    : out ahb_slv_out_type);
  end component;

  component etracenv is
    generic (
      ext_c   : integer;
      ncpu    : integer;
      -- Encoder APB
      pindex  : integer;
      paddr   : integer;
      pmask   : integer;
      pirq    : integer
    );
    port (
      rstn    : in  std_ulogic;
      clk     : in  std_ulogic;
      -- Encoder APB interface
      apbi    : in  apb_slv_in_type;
      apbo    : out apb_slv_out_type;
      -- Encoder-Hart interface
      eto     : in  nv_etrace_vector(ncpu-1 downto 0);
      -- Encoder to sink interface
      etso    : out nv_etrace_sink_out_vector(ncpu-1 downto 0);
      etsi    : in  nv_etrace_sink_in_vector(ncpu-1 downto 0)
    );
  end component;
end;

