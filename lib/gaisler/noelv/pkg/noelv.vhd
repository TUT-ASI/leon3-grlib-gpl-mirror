------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.uart.all;
use gaisler.noelv_cfg.all;

package noelv is

  constant XLEN                 : integer := NV_XLEN;
  constant FLEN                 : integer := 64;  -- Unused
  constant CAUSELEN             : integer := 5;
  constant DBITS                : integer := 16;  -- Use in one place

  constant GEILEN               : integer := 16;

  constant AIA_SUPPORT          : integer := 0;   -- 0 = AIA support is disabled in GRLIB
  constant SMRNMI_SUPPORT       : integer := 0;   -- 0 = SMRNMI support is disabled in GRLIB
  constant DBLTRP_SUPPORT       : integer := 0;   -- 0 = Double trap extensions support is disabled in GRLIB
  -- Types --------------------------------------------------------------------


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
  end record;

  type nv_irq_out_type is record
    irqack      : std_ulogic;
  end record;

  type nv_irq_in_vector is array (natural range <>) of nv_irq_in_type;
  type nv_irq_out_vector is array (natural range <>) of nv_irq_out_type;

  constant nv_irq_in_none : nv_irq_in_type := (
    mtip        => '0',
    msip        => '0',
    ssip        => '0',
    meip        => '0',
    seip        => '0',
    ueip        => '0',
    heip        => '0',
    hgeip       => (others => '0'),
    stime       => (others => '0')
    );

  subtype nv_nirq_in_type is std_logic_vector(5 downto 0);
  type nv_nirq_in_vector is array (natural range <>) of nv_nirq_in_type;

  -- Message signaled interrupt controler --------------------------------------
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

  type imsic_in_vector is array (natural range <>) of imsic_in_type;
  type imsic_out_vector is array (natural range <>) of imsic_out_type;

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

  type trace_d_vector is array (natural range<>) of std_logic_vector(1023 downto 0);

  -- Hart-Encoder Interface
  type nv_etrace_out_type is record
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

  constant nv_etrace_out_none : nv_etrace_out_type := (
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
  
  type nv_etrace_out_vector is array (natural range <>) of nv_etrace_out_type;
  
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

  -- CPU configurations type
  type nv_cpu_cfg_type is record
    single_issue  : integer;
    ext_m         : integer;
    ext_a         : integer;
    ext_c         : integer;
    ext_h         : integer;
    ext_zcb       : integer;
    ext_zba       : integer;
    ext_zbb       : integer;
    ext_zbc       : integer;
    ext_zbs       : integer;
    ext_zbkb      : integer;
    ext_zbkc      : integer;
    ext_zbkx      : integer;
    ext_sscofpmf  : integer;
    ext_sstc      : integer;
    ext_smaia     : integer;
    ext_ssaia     : integer;
    ext_smstateen : integer;
    ext_smrnmi    : integer;
    ext_ssdbltrp  : integer;
    ext_smdbltrp  : integer;
    ext_sddbltrp  : integer;
    ext_smepmp    : integer;
    imsic         : integer;
    ext_zicbom    : integer;
    ext_zicond    : integer;
    ext_zimop     : integer;
    ext_zcmop     : integer;
    ext_svinval   : integer;
    ext_zfa       : integer;
    ext_zfh       : integer;
    ext_zfhmin    : integer;
    ext_zfbfmin   : integer;
    mode_s        : integer;
    mode_u        : integer;
    fpulen        : integer;
    pmp_no_tor    : integer;
    pmp_entries   : integer;
    pmp_g         : integer;
    asidlen       : integer;
    vmidlen       : integer;
    perf_cnts     : integer;
    perf_evts     : integer;
    perf_bits     : integer;
    tbuf          : integer;
    trigger       : integer;
    icen          : integer;
    iways         : integer;
    iwaysize      : integer;
    ilinesize     : integer;
    dcen          : integer;
    dways         : integer;
    dwaysize      : integer;
    dlinesize     : integer;
    mmuen         : integer;
    itlbnum       : integer;
    dtlbnum       : integer;
    htlbnum       : integer;
    div_hiperf    : integer;
    div_small     : integer;
    late_branch   : integer;
    late_alu      : integer;
    ras           : integer;
    bhtentries    : integer;
    bhtlength     : integer;
    predictor     : integer;
    btbentries    : integer;
    btbsets       : integer;
  end record;





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
      tcmconf           : integer                       := 0;
      mulconf           : integer                       := 0;
      -- Caches
      icen              : integer range 0  to 1         := 0;  -- I$ Cache Enable
      iways             : integer range 1  to 8         := 1;  -- I$ Ways
      ilinesize         : integer range 4  to 8         := 4;  -- I$ Cache Line Size (words)
      iwaysize          : integer range 1  to 256       := 1;  -- I$ Cache Way Size (KiB)
      dcen              : integer range 0  to 1         := 0;  -- D$ Cache Enable
      dways             : integer range 1  to 8         := 1;  -- D$ Ways
      dlinesize         : integer range 4  to 8         := 4;  -- D$ Cache Line Size (words)
      dwaysize          : integer range 1  to 256       := 1;  -- D$ Cache Way Size (KiB)
      -- BHT
      bhtentries        : integer range 32 to 1024      := 256;-- BHT Number of Entries
      bhtlength         : integer range 2  to 10        := 5;  -- History Length
      predictor         : integer range 0  to 2         := 0;  -- Predictor
      -- BTB
      btbentries        : integer range 8  to 128       := 32; -- BTB Number of Entries
      btbsets           : integer range 1  to 8         := 1;  -- BTB Sets/Ways
      -- MMU
      mmuen             : integer range 0  to 2         := 0;  -- Enable MMU
      itlbnum           : integer range 2  to 64        := 8;
      dtlbnum           : integer range 2  to 64        := 8;
      htlbnum           : integer range 1  to 64        := 8;
      tlbforepl         : integer range 1  to 4         := 1;
      riscv_mmu         : integer range 0  to 3         := 1;
      tlb_pmp           : integer range 0  to 1         := 1;  -- Do PMP via TLB
      pmp_no_tor        : integer range 0  to 1         := 0;  -- Disable PMP TOR
      pmp_entries       : integer range 0  to 16        := 16; -- Implemented PMP registers
      pmp_g             : integer range 0  to 10        := 0;  -- PMP grain is 2^(pmp_g + 2) bytes
      asidlen           : integer range 0 to  16        := 0;  -- Max 9 for Sv32
      vmidlen           : integer range 0 to  14        := 0;  -- Max 7 for Sv32
      -- Interrupts
      imsic             : integer range 0  to 1         := 0;  -- IMSIC implemented
      -- RNMI
      rnmi_iaddr          : integer                     := 16#00100#; -- RNMI interrupt trap handler address
      rnmi_xaddr          : integer                     := 16#00101#; -- RNMI exception trap handler address
      -- Extensions
      ext_noelv         : integer range 0  to 1         := 1;  -- NOEL-V Extensions
      ext_noelvalu      : integer range 0  to 1         := 1;  -- NOEL-V ALU Extensions
      ext_m             : integer range 0  to 1         := 1;  -- M Base Extension Set
      ext_a             : integer range 0  to 1         := 0;  -- A Base Extension Set
      ext_c             : integer range 0  to 1         := 0;  -- C Base Extension Set
      ext_h             : integer range 0  to 1         := 0;  -- H Extension
      ext_zcb           : integer range 0  to 1         := 0;  -- Zcb Extension
      ext_zba           : integer range 0  to 1         := 0;  -- Zba Extension
      ext_zbb           : integer range 0  to 1         := 0;  -- Zbb Extension
      ext_zbc           : integer range 0  to 1         := 0;  -- Zbc Extension
      ext_zbs           : integer range 0  to 1         := 0;  -- Zbs Extension
      ext_zbkb          : integer range 0  to 1         := 0;  -- Zbkb Extension
      ext_zbkc          : integer range 0  to 1         := 0;  -- Zbkc Extension
      ext_zbkx          : integer range 0  to 1         := 0;  -- Zbkx Extension
      ext_sscofpmf      : integer range 0  to 1         := 0;  -- Sscofpmf Extension
      ext_sstc          : integer range 0  to 2         := 0;  -- Sctc Extension (2 : only time csr impl.)  
      ext_smaia         : integer range 0  to 1         := 0;  -- Smaia Extension
      ext_ssaia         : integer range 0  to 1         := 0;  -- Ssaia Extension 
      ext_smstateen     : integer range 0  to 1         := 0;  -- Sstateeen Extension 
      ext_smrnmi        : integer range 0  to 1         := 0;  -- Smrnmi Extension 
      ext_ssdbltrp      : integer range 0  to 1         := 0;  -- Ssdbltrp Extension
      ext_smdbltrp      : integer range 0  to 1         := 0;  -- Smdbltrp Extension
      ext_sddbltrp      : integer range 0  to 1         := 0;  -- Sddbltrp Extension
      ext_smepmp        : integer range 0  to 1         := 0;  -- Smepmp Extension
      ext_zicbom        : integer range 0  to 1         := 0;  -- Zicbom Extension
      ext_zicond        : integer range 0  to 1         := 0;  -- Zicond Extension
      ext_zimop         : integer range 0  to 1         := 0;  -- Zimop Extension
      ext_zcmop         : integer range 0  to 1         := 0;  -- Zcmop Extension
      ext_svinval       : integer range 0  to 1         := 0;  -- Svinval Extension
      ext_zfa           : integer range 0  to 1         := 0;  -- Zfa Extension
      ext_zfh           : integer range 0  to 1         := 0;  -- Zfh Extension
      ext_zfhmin        : integer range 0  to 1         := 0;  -- Zfhmin Extension
      ext_zfbfmin       : integer range 0  to 1         := 0;  -- Zfbfmin Extension
      mode_s            : integer range 0  to 1         := 0;  -- Supervisor Mode Support
      mode_u            : integer range 0  to 1         := 0;  -- User Mode Support
      fpulen            : integer range 0  to 128       := 0;  -- Floating-point precision
      trigger           : integer                       := 0;
      -- Advanced Features
      late_branch       : integer range 0  to 1         := 0;  -- Late Branch Support
      late_alu          : integer range 0  to 1         := 0;  -- Late ALUs Support
      ras               : integer range 0  to 2         := 0;  -- Return Address Stack (1 - test, 2 - enable)
      -- Core
      physaddr          : integer range 32 to 56        := 32; -- Physical Addressing
      rstaddr           : integer                       := 16#00000#; -- reset vector (MSB)
      disas             : integer                       := 0;  -- Disassembly to console
      perf_cnts         : integer range 0  to 29        := 16; -- Number of performance counters
      perf_evts         : integer range 0  to 255       := 16; -- Number of performance events
      perf_bits         : integer range 0  to 64        := 64; -- Bits of performance counting
      illegalTval0      : integer range 0  to 1         := 0;  -- Zero TVAL on illegal instruction
      no_muladd         : integer range 0  to 1         := 0;  -- 1 - multiply-add not supported
      single_issue      : integer range 0  to 1         := 0;  -- 1 - only one pipeline
      mularch           : integer                       := 0;  -- multiplier architecture
      div_hiperf        : integer                       := 0;
      div_small         : integer                       := 0;
      hw_fpu            : integer range 0  to 3         := 1;  -- 1 - use hw fpu
      rfreadhold        : integer range 0  to 1         := 0;  -- Register File Read Hold
      scantest          : integer                       := 0;  -- scantest support
      endian            : integer                       := GRLIB_CONFIG_ARRAY(grlib_little_endian)
      );
    port (
      clk         : in  std_ulogic; -- clock
      gclk        : in  std_ulogic; -- gated clock
      rstn        : in  std_ulogic;
      ahbi        : in  ahb_mst_in_type;
      ahbo        : out ahb_mst_out_type;
      ahbsi       : in  ahb_slv_in_type;
      ahbso       : in  ahb_slv_out_vector;
      imsici      : out imsic_in_type;    -- IMSIC In Port
      imsico      : in  imsic_out_type;   -- IMSIC Out Port
      irqi        : in  nv_irq_in_type;   -- irq in
      irqo        : out nv_irq_out_type;  -- irq out
      nirqi       : in  nv_nirq_in_type;  -- RNM irq in
      dbgi        : in  nv_debug_in_type; -- debug in
      dbgo        : out nv_debug_out_type;-- debug out
      eto         : out nv_etrace_out_type;
      cnt         : out nv_counter_out_type;
      pwrd        : out std_ulogic           -- Activate power down mode 
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
      tcmconf  : integer;
      mulconf  : integer;
      disas    : integer;
      pbaddr   : integer;
      cfg      : integer;
      scantest : integer
      );
    port (
      clk    : in  std_ulogic;
      gclk   : in  std_ulogic;
      rstn   : in  std_ulogic;
      ahbi   : in  ahb_mst_in_type;
      ahbo   : out ahb_mst_out_type;
      ahbsi  : in  ahb_slv_in_type;
      ahbso  : in  ahb_slv_out_vector;
      imsici : out imsic_in_type;       
      imsico : in  imsic_out_type;     
      irqi   : in  nv_irq_in_type;
      irqo   : out nv_irq_out_type;
      nirqi  : in  nv_nirq_in_type;
      dbgi   : in  nv_debug_in_type;
      dbgo   : out nv_debug_out_type;
      eto    : out nv_etrace_out_type;
      cnt    : out nv_counter_out_type;
      pwrd   : out std_ulogic        
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
      eto     : in  nv_etrace_out_vector(ncpu-1 downto 0);
      -- Encoder to sink interface
      etso    : out nv_etrace_sink_out_vector(ncpu-1 downto 0);
      etsi    : in  nv_etrace_sink_in_vector(ncpu-1 downto 0)
    );
  end component;
end;

