------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
-- Entity:      noelv
-- File:        noelv.vhd
-- Author:      Andrea Merlo, Nils Wessman Cobham Gaisler AB
-- Description: NOEL-V types and components
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.uart.all;
use gaisler.noelv_cfg.all;
library techmap;
use techmap.gencomp.all;
package noelv is

  constant XLEN                 : integer := NV_XLEN;
  constant FLEN                 : integer := 64;  -- Unused
  constant DBITS                : integer := 16;  -- Use in one place

  -- Types --------------------------------------------------------------------


  -- Interrupt Bus ------------------------------------------------------------
  type nv_irq_in_type is record
    mtip        : std_ulogic; -- Machine Timer Interrupt
    msip        : std_ulogic; -- Machine Software Interrupt
    meip        : std_ulogic; -- Machine External Interrupt
    seip        : std_ulogic; -- Software External Interrupt
    ueip        : std_ulogic; -- User External Interrupt
    heip        : std_ulogic; -- Reserved
  end record;

  type nv_irq_out_type is record
    irqack      : std_ulogic;
  end record;

  type nv_irq_in_vector is array (natural range <>) of nv_irq_in_type;
  type nv_irq_out_vector is array (natural range <>) of nv_irq_out_type;

  constant nv_irq_in_none : nv_irq_in_type := (
    mtip        => '0',
    msip        => '0',
    meip        => '0',
    seip        => '0',
    ueip        => '0',
    heip        => '0'
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
  end record;

  type nv_counter_out_vector is array (natural range <>) of nv_counter_out_type;

  -- Debug --------------------------------------------------------------------
  type nv_debug_in_type is record
    dsuen       : std_ulogic;                           -- DSU Enable
    halt        : std_ulogic;                           -- Halt Request
    resume      : std_ulogic;                           -- Resume Request
    reset       : std_ulogic;                           -- Reset Request
    haltonrst   : std_ulogic;                           -- Halt-on-reset Request
    denable     : std_ulogic;                           -- Diagnostic Enable
    dcmd        : std_logic_vector(1 downto 0);         -- Diagnostic Operation
    dwrite      : std_ulogic;                           -- Diagnostic Read/Write
    dsize       : std_logic_vector(2 downto 0);         -- Diagnostic Size Access
    daddr       : std_logic_vector(DBITS-1 downto 0);   -- Diagnostic Address
    ddata       : std_logic_vector(63 downto 0);        -- Diagnostic Data
    pbdata      : std_logic_vector(63 downto 0);
  end record;

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
    mcycle      => (others => '0')
    );

  type nv_debug_in_vector  is array (natural range <>) of nv_debug_in_type;
  type nv_debug_out_vector is array (natural range <>) of nv_debug_out_type;

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
      hindex            : integer range 0  to 15        := 0;  -- hart index
      fabtech           : integer range 0  to NTECH     := DEFFABTECH;
      memtech           : integer                       := DEFMEMTECH;
      -- Misc
      dmen              : integer range 0  to 1         := 0;
      pbaddr            : integer                       := 16#90000#; -- Program buffer address
      tbuf              : integer                       := 0;  -- trace buffer size in kB
      cached            : integer                       := 0;
      wbmask            : integer                       := 0;
      busw              : integer                       := 64;
      cmemconf          : integer                       := 0;
      rfconf            : integer                       := 0;
      clk2x             : integer                       := 0;
      ahbpipe           : integer                       := 0;
      -- Caches
      icen              : integer range 0  to 1         := 0;  -- I$ Cache Enable
      irepl             : integer range 0  to 2         := 2;
      isets             : integer range 1  to 4         := 1;  -- I$ Sets/Ways
      ilinesize         : integer range 4  to 8         := 4;  -- I$ Cache Line Size (words)
      isetsize          : integer range 1  to 256       := 1;  -- I$ Cache Way Size (KiB)
      dcen              : integer range 0  to 1         := 0;  -- D$ Cache Enable
      drepl             : integer range 0  to 2         := 2;
      dsets             : integer range 1  to 4         := 1;  -- D$ Sets/Ways
      dlinesize         : integer range 4  to 8         := 4;  -- D$ Cache Line Size (words)
      dsetsize          : integer range 1  to 256       := 1;  -- D$ Cache Way Size (KiB)
      dsnoop            : integer range 0  to 6         := 0;  -- Enable Data Cache Snooping
      ilram             : integer range 0  to 1         := 0;
      ilramsize         : integer range 1  to 512       := 1;
      ilramstart        : integer range 0  to 255       := 16#8e#;
      dlram             : integer range 0  to 1         := 0;
      dlramsize         : integer range 1  to 512       := 1;
      dlramstart        : integer range 0  to 255       := 16#8f#;
      -- BHT
      bhtentries        : integer range 32 to 1024      := 256;-- BHT Number of Entries
      bhtlength         : integer range 2  to 10        := 5;  -- History Length
      predictor         : integer range 0  to 2         := 0;  -- Predictor
      -- BTB
      btbentries        : integer range 8  to 128       := 32; -- BTB Number of Entries
      btbsets           : integer range 1  to 8         := 1;  -- BTB Sets/Ways
      -- MMU
      mmuen             : integer range 0  to 2         := 0;  -- Enable MMU
      mmupgsz           : integer                       := 0;
      itlbnum           : integer range 2  to 64        := 8;
      dtlbnum           : integer range 2  to 64        := 8;
      tlb_type          : integer range 0  to 3         := 1;
      tlb_rep           : integer range 0  to 1         := 0;
      tlbforepl         : integer range 1  to 4         := 1;
      riscv_mmu         : integer range 0  to 3         := 1;
      pmp_no_tor        : integer range 0  to 1         := 0;  -- Disable PMP TOR
      pmp_entries       : integer range 0  to 16        := 16; -- Implemented PMP registers
      pmp_g             : integer range 0  to 10        := 0;  -- PMP grain is 2^(pmp_g + 2) bytes
--      pmp_msb           : integer range 15 to 55        := 31; -- High bit for PMP checks
      -- Extensions
      ext_m             : integer range 0  to 1         := 1;  -- M Base Extension Set
      ext_a             : integer range 0  to 1         := 0;  -- A Base Extension Set
      ext_c             : integer range 0  to 1         := 0;  -- C Base Extension Set
      ext_h             : integer range 0  to 1         := 0;  -- H Extension
      mode_s            : integer range 0  to 1         := 0;  -- Supervisor Mode Support
      mode_u            : integer range 0  to 1         := 0;  -- User Mode Support
      fpulen            : integer range 0  to 128       := 0;  -- Floating-point precision
      trigger           : integer                       := 0;
      -- Advanced Features
      late_branch       : integer range 0  to 1         := 0;  -- Late Branch Support
      late_alu          : integer range 0  to 1         := 0;  -- Late ALUs Support
      -- Core
      physaddr          : integer range 32 to 56        := 32; -- Physical Addressing
      rstaddr           : integer                       := 16#00000#; -- reset vector (MSB)
      disas             : integer                       := 0;  -- Disassembly to console
      perf_cnts         : integer range 0  to 31        := 16; -- Number of performance counters
      perf_evts         : integer range 0  to 255       := 16; -- Number of performance events
      illegalTval0      : integer range 0  to 1         := 0;  -- Zero TVAL on illegal instruction
      no_muladd         : integer range 0  to 1         := 0;  -- 1 - multiply-add not supported
      single_issue      : integer range 0  to 1         := 0;  -- 1 - only one pipeline
      mularch           : integer                       := 0;  -- multiplier architecture
      div_hiperf        : integer                       := 0;
      div_small         : integer                       := 0;
      rfreadhold        : integer range 0  to 1         := 0;  -- Register File Read Hold
      ft                : integer                       := 0;  -- FT option
      scantest          : integer                       := 0;  -- scantest support
      endian            : integer                       := GRLIB_CONFIG_ARRAY(grlib_little_endian)
      );
    port (
      ahbclk      : in  std_ulogic; -- bus clock
      cpuclk      : in  std_ulogic; -- cpu clock
      gcpuclk     : in  std_ulogic; -- gated cpu clock
      fpuclk      : in  std_ulogic; -- gated fpu clock
      hclken      : in  std_ulogic; -- bus clock enable qualifier
      rstn        : in  std_ulogic;
      ahbi        : in  ahb_mst_in_type;
      ahbo        : out ahb_mst_out_type;
      ahbsi       : in  ahb_slv_in_type;
      ahbso       : in  ahb_slv_out_vector;
      irqi        : in  nv_irq_in_type;   -- irq in
      irqo        : out nv_irq_out_type;  -- irq out
      dbgi        : in  nv_debug_in_type; -- debug in
      dbgo        : out nv_debug_out_type;-- debug out
      cnt         : out nv_counter_out_type
      );
  end component;
  
  component noelvcpu is
    generic (
      hindex   : integer;
      fabtech  : integer;
      memtech  : integer;
      mularch  : integer :=0 ;
      cached   : integer;
      wbmask   : integer;
      busw     : integer;
      cmemconf : integer;
      rfconf   : integer;
      fpuconf  : integer;
      disas    : integer;
      pbaddr   : integer;
      cfg      : integer;
      scantest : integer
      );
    port (
      clk   : in  std_ulogic;
      rstn  : in  std_ulogic;
      ahbi  : in  ahb_mst_in_type;
      ahbo  : out ahb_mst_out_type;
      ahbsi : in  ahb_slv_in_type;
      ahbso : in  ahb_slv_out_vector;
      irqi  : in  nv_irq_in_type;
      irqo  : out nv_irq_out_type;
      dbgi  : in  nv_debug_in_type;
      dbgo  : out nv_debug_out_type;
      cnt   : out nv_counter_out_type
      );
  end component;

  component noelvsys is
    generic (
      fabtech  : integer;
      memtech  : integer;
      mularch  : integer := 0;
      ncpu     : integer;
      nextmst  : integer;
      nextslv  : integer;
      nextapb  : integer;
      ndbgmst  : integer;
      cached   : integer;
      wbmask   : integer;
      busw     : integer;
      cmemconf : integer;
      rfconf   : integer := 0;
      fpuconf  : integer;
      disas    : integer;
      ahbtrace : integer;
      cfg      : integer := 0;
      devid    : integer := 0;
      nodbus   : integer := 0;
      scantest : integer := 0
      );
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
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
      apbi     : out apb_slv_in_vector;
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
      -- DFT support
      testen  : in  std_ulogic := '0';
      testrst : in  std_ulogic := '1';
      scanen  : in  std_ulogic := '0';
      testoen : in  std_ulogic := '1';
      testsig : in  std_logic_vector(1+GRLIB_CONFIG_ARRAY(grlib_techmap_testin_extra) downto 0) := (others => '0')
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
end;
