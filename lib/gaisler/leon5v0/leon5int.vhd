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
-- Package:     leon5int
-- File:        leon5int.vhd
-- Description: Internal components and types for LEON5SYS
------------------------------------------------------------------------------
-- NOTE: This package is subject to change during LEON5 development, it is
--   not recommended to depend on this package externally.

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.arith.all;
use gaisler.uart.all;
use gaisler.leon5.leon5_bretry_in_type;
use gaisler.leon5.leon5_bretry_out_type;

package leon5int is

  ----------------------------------------------------------------------------
  -- Types
  ----------------------------------------------------------------------------
  type l5_irq_in_type is record
    irl         : std_logic_vector(3 downto 0);
  end record;

  type l5_irq_out_type is record
    intack      : std_ulogic;
    irl         : std_logic_vector(3 downto 0);
    pwd         : std_ulogic;
    fpen        : std_ulogic;
    err         : std_ulogic;
  end record;

  -- legacy for SMP support via IRQ controller
  type l5_irq_dbg_type is record
    resume      : std_ulogic;
    pwdsetaddr  : std_ulogic;
    pwdnewaddr  : std_logic_vector(31 downto 2);
    forceerr    : std_ulogic;
  end record;

  type l5_dbg_irq_type is record
    irqvec      : std_logic_vector(31 downto 0);
  end record;

  type l5_irq_in_vector is array(natural range <>) of l5_irq_in_type;
  type l5_irq_out_vector is array(natural range <>) of l5_irq_out_type;
  type l5_irq_dbg_vector is array(natural range <>) of l5_irq_dbg_type;
  type l5_dbg_irq_vector is array(natural range <>) of l5_dbg_irq_type;

  type l5_intreg_mosi_type is record
    accen: std_ulogic;
    addr: std_logic_vector(21 downto 0);
    accwr: std_ulogic;
    wrdata: std_logic_vector(31 downto 0);
  end record;

  type l5_intreg_miso_type is record
    accrdy: std_ulogic;
    rddata: std_logic_vector(31 downto 0);
  end record;

  constant l5_intreg_mosi_none: l5_intreg_mosi_type := ('0', (others => '0'), '0', (others => '0'));
  constant l5_intreg_miso_none: l5_intreg_miso_type := ('1', (others => '0'));

  type l5_intreg_miso_array is array(natural range <>) of l5_intreg_miso_type;
  type l5_intreg_mosi_array is array(natural range <>) of l5_intreg_mosi_type;

  type trace_port_out_type is record
    tdata : std_logic_vector(383 downto 0);
  end record;

  type trace_port_in_vector is array(natural range <>) of trace_port_out_type;
  
  type trace_control_out_type is record
    trace_upd   : std_logic;
    addr_f      : std_logic_vector(3 downto 0);
    addr_f_p    : std_logic_vector(3 downto 0);
    inst_filter : std_logic_vector(3 downto 0);
  end record;
    
  type trace_control_out_vector is array(natural range <>) of trace_control_out_type;
  
  constant CPUSTATE_STOPPED: std_logic_vector(1 downto 0) := "00";
  constant CPUSTATE_RUNNING: std_logic_vector(1 downto 0) := "01";
  constant CPUSTATE_ERRMODE: std_logic_vector(1 downto 0) := "10";
  constant CPUSTATE_INSLEEP: std_logic_vector(1 downto 0) := "11";

  constant CPUCMD_NONE:      std_logic_vector(2 downto 0) := "000";
  constant CPUCMD_START:     std_logic_vector(2 downto 0) := "001";
  constant CPUCMD_WAKEUP:    std_logic_vector(2 downto 0) := "010";
  constant CPUCMD_BREAK:     std_logic_vector(2 downto 0) := "011";
  constant CPUCMD_FORCESTOP: std_logic_vector(2 downto 0) := "100";
  constant CPUCMD_FORCERUN : std_logic_vector(2 downto 0) := "101";
  constant CPUCMD_FORCEERR : std_logic_vector(2 downto 0) := "110";
  constant CPUCMD_FORCESLP : std_logic_vector(2 downto 0) := "111";

  type leon5_perf_array is array(0 to 7) of std_logic_vector(63 downto 0);

  type l5_debug_in_type is record
    dynid       : std_logic_vector(3 downto 0);
    cmd         : std_logic_vector(2 downto 0);
    freeze      : std_ulogic;
    -- pushpc only allowed in stopped state
    pushpc      : std_ulogic; -- mosi.wrdata -> nPC, nPC -> PC
    pcin        : std_logic_vector(31 downto 2);
    -- debug r/w interface
    mosi        : l5_intreg_mosi_type;
    -- debug break configuration
    btrapa      : std_ulogic; -- break on IU trap
    btrape      : std_ulogic; -- break on IU trap
    bwatch      : std_ulogic; -- break on IU watchpoint
    bsoft       : std_ulogic; -- break on software breakpoint (TA 1)
    -- time stamp timer
    timer       : std_logic_vector(63 downto 0);
    -- cpu-to-cpu interface
    c2c_miso    : l5_intreg_miso_type;
    boot_word   : std_logic_vector(31 downto 0);
    smpflush    : std_logic_vector(1 downto 0);
  end record;

  type l5_debug_out_type is record
    cpustate   : std_logic_vector(1 downto 0);
    miso       : l5_intreg_miso_type;
    idle       : std_ulogic;
    wakeup_req : std_logic;
    c2c_mosi   : l5_intreg_mosi_type;
  end record;

  type l5_debug_in_vector is array (natural range <>) of l5_debug_in_type;
  type l5_debug_out_vector is array (natural range <>) of l5_debug_out_type;

  constant l5_dbgi_none : l5_debug_in_type :=
    ("0000","000",'0','0',(others => '0'),l5_intreg_mosi_none,'0','0','0','0',
     (others => '0'),l5_intreg_miso_none,x"00000000","00");

  constant l5_dbgo_none : l5_debug_out_type :=
    ("00", l5_intreg_miso_none, '0', '0', l5_intreg_mosi_none);

  constant ISSUE_NONE : std_logic_vector(2 downto 0) := "000";
  constant ISSUE_OP   : std_logic_vector(2 downto 0) := "001";
  constant ISSUE_ST   : std_logic_vector(2 downto 0) := "010";
  constant ISSUE_LD   : std_logic_vector(2 downto 0) := "011";
  constant ISSUE_FPE  : std_logic_vector(2 downto 0) := "100";
  constant ISSUE_DFQE : std_logic_vector(2 downto 0) := "110";
  constant ISSUE_RSV1 : std_logic_vector(2 downto 0) := "101";
  constant ISSUE_RSV2 : std_logic_vector(2 downto 0) := "111";

  type grfpu5_in_type is record
    start   : std_logic;
    inmode  : std_logic_vector(1 downto 0);
    outmode : std_logic_vector(1 downto 0);
    flop    : std_logic_vector(8 downto 0);
    op1     : std_logic_vector(63 downto 0);
    op2     : std_logic_vector(63 downto 0);
    opid    : std_logic_vector(7 downto 0);
    flush   : std_logic;
    flushid : std_logic_vector(5 downto 0);
    rndmode : std_logic_vector(1 downto 0);
    req     : std_logic_vector(2 downto 0);
  end record;

  constant grfpu5_in_none : grfpu5_in_type :=
    ('0', "00", "00", (others => '0'), (others => '0'), (others => '0'),
     (others => '0'), '0', (others => '0'), (others => '0'),
     (others => '0'));

  type grfpu5_in_vector is array (natural range <>) of grfpu5_in_type;

  type grfpu5_out_type is record
    res     : std_logic_vector(63 downto 0);
    exc     : std_logic_vector(6 downto 0);
    allow   : std_logic_vector(2 downto 0);
    rdy     : std_logic;
    cc      : std_logic_vector(1 downto 0);
    idout   : std_logic_vector(7 downto 0);
    cmprdy  : std_ulogic;
    cmpidout: std_logic_vector(7 downto 0);
    cmpcc   : std_logic_vector(1 downto 0);
    cmpnv   : std_ulogic;
  end record;

  constant grfpu5_out_none: grfpu5_out_type := (
    (others => '0'), "0000000", "000", '0', "00", "00000000", '0', "00000000", "00", '0'
    );

  type grfpu5_out_vector is array (natural range <>) of grfpu5_out_type;

    ----------------------------------------------------------------------------
  -- Processor core
  ----------------------------------------------------------------------------
  component cpucore5 is
    generic (
      hindex  : integer;
      fabtech : integer;
      memtech : integer;
      cached  : integer;
      wbmask  : integer;
      busw    : integer;
      cmemconf: integer;
      rfconf  : integer;
      fpuconf : integer;
      tcmconf : integer;
      iways   : integer;
      iwaysize: integer;
      dways   : integer;
      dwaysize: integer;
      itlbnum : integer;
      dtlbnum : integer;
      mulimpl : integer;
      rstaddr : integer;
      disas   : integer;
      scantest: integer;
      cgen    : integer
      );
    port (
      clk   : in  std_ulogic;
      rstn  : in  std_ulogic;
      gclk  : in  std_ulogic;
      gclken: out std_ulogic;
      ahbi  : in  ahb_mst_in_type;
      ahbo  : out ahb_mst_out_type;
      ahbsi : in  ahb_slv_in_type;
      ahbso : in  ahb_slv_out_vector;
      irqi  : in  l5_irq_in_type;
      irqo  : out l5_irq_out_type;
      dbgi  : in  l5_debug_in_type;
      dbgo  : out l5_debug_out_type;
      tpo   : out trace_port_out_type;
      tco   : in  trace_control_out_type;
      fpuo  : in  grfpu5_out_type;
      fpui  : out grfpu5_in_type;
      perf  : out std_logic_vector(63 downto 0)
      );
  end component;

  ----------------------------------------------------------------------------
  -- L5STAT
  ----------------------------------------------------------------------------

  component l5stat is
    generic (
      cnt_width : integer range 1 to 64 := 32;
      ncores    : integer range 1 to 8  := 1;
      ninpipe   : integer range 1 to 2  := 1;
      hindex    : integer := 0;
      ioaddr    : integer := 0);
    port (
      rstn      : in  std_ulogic;
      clk       : in  std_ulogic;
      perf      : in  leon5_perf_array;
      ahbsi     : in  ahb_slv_in_type;
      ahbso     : out ahb_slv_out_type
      );
  end component;
  ----------------------------------------------------------------------------
  -- FPU
  ----------------------------------------------------------------------------
  component grfpc5 is
    port (
      clk           : in std_ulogic;
      rstn          : in std_ulogic;
      -- Pipeline interface
      --   Issue interface
      ready_flop    : out std_ulogic;
      ready_ld      : out std_logic_vector(0 to 35);
      ready_st      : out std_logic_vector(0 to 35);
      trapon_flop   : out std_ulogic;
      trapon_ldst   : out std_ulogic;
      trapon_stdfq  : out std_ulogic;
      issue_cmd     : in std_logic_vector(2 downto 0);
      issue_ldstreg : in std_logic_vector(5 downto 0);
      issue_ldstdp  : in std_ulogic;
      issue_op3_0   : in std_ulogic;
      issue_flop    : in std_logic_vector(8 downto 0);
      issue_rd      : in std_logic_vector(4 downto 0);
      issue_rs1     : in std_logic_vector(4 downto 0);
      issue_rs2     : in std_logic_vector(4 downto 0);
      issue_dfqdata : in std_logic_vector(63 downto 0);
      issue_id      : out std_logic_vector(4 downto 0);
      --   Commit interface
      commit        : in std_ulogic;
      commitid      : in std_logic_vector(4 downto 0);
      lddata        : in std_logic_vector(63 downto 0);
      --   Store data interface
      stdata        : out std_logic_vector(63 downto 0);
      --   Mispredict/trap interface
      unissue       : in std_ulogic;
      unissue_sid   : in std_logic_vector(4 downto 0);
      --   Special store handling (for side effects)
      spstore_pend  : in std_ulogic;
      spstore_done  : in std_ulogic;
      --   Floating-point condition codes
      fccready      : out std_ulogic;
      fcc           : out std_logic_vector(1 downto 0);
      --   Idle signal
      fpcidle       : out std_ulogic;
      -- FPU interface
      fpu_start     : out std_logic;
      fpu_inmode    : out std_logic_vector(1 downto 0);
      fpu_outmode   : out std_logic_vector(1 downto 0);
      fpu_flop      : out std_logic_vector(8 downto 0);
      fpu_op1       : out std_logic_vector(63 downto 0);
      fpu_op2       : out std_logic_vector(63 downto 0);
      fpu_opid      : out std_logic_vector(7 downto 0);
      fpu_rndmode   : out std_logic_vector(1 downto 0);
      fpu_res       : in std_logic_vector(63 downto 0);
      fpu_exc       : in std_logic_vector(6 downto 0);
      fpu_allow     : in std_logic_vector(2 downto 0);
      fpu_rdy       : in std_logic;
      fpu_idout     : in std_logic_vector(7 downto 0);
      fpu_cmprdy    : in std_ulogic;
      fpu_cmpidout  : in std_logic_vector(7 downto 0);
      fpu_cmpcc     : in std_logic_vector(1 downto 0);
      fpu_cmpnv     : in std_ulogic;
      -- Regfile interface
      rf_raddr1     : out std_logic_vector(4 downto 1);
      rf_ren1       : out std_logic_vector(1 downto 0);
      rf_rdata1     : in  std_logic_vector(63 downto 0);
      rf_raddr2     : out std_logic_vector(4 downto 1);
      rf_ren2       : out std_logic_vector(1 downto 0);
      rf_rdata2     : in  std_logic_vector(63 downto 0);
      rf_raddr3     : out std_logic_vector(4 downto 1);
      rf_ren3       : out std_logic_vector(1 downto 0);
      rf_rdata3     : in  std_logic_vector(63 downto 0);
      rf_waddr      : out std_logic_vector(4 downto 1);
      rf_wen        : out std_logic_vector(1 downto 0);
      rf_wdata      : out std_logic_vector(63 downto 0);
      -- Control/Debug interface
      mosi_accen    : in  std_ulogic;
      mosi_addr     : in  std_logic_vector(5 downto 0);
      mosi_accwr    : in  std_ulogic;
      mosi_wrdata   : in  std_logic_vector(31 downto 0);
      miso_accrdy   : out std_ulogic;
      miso_rddata   : out std_logic_vector(31 downto 0);
      -- Trace
      retire        : out std_logic;
      retire_id     : out std_logic_vector(4 downto 0);
      -- Legacy debug
      dbgfsr        : out std_logic_vector(31 downto 0)  -- FSR value
      );
  end component;

  component nanofpu is
    port (
      clk           : in std_ulogic;
      rstn          : in std_ulogic;
      -- Pipeline interface
      --   Issue interface
      ready_flop    : out std_ulogic;
      ready_ld      : out std_logic_vector(0 to 35);
      ready_st      : out std_logic_vector(0 to 35);
      trapon_flop   : out std_ulogic;
      trapon_ldst   : out std_ulogic;
      trapon_stdfq  : out std_ulogic;
      issue_cmd     : in std_logic_vector(2 downto 0);
      issue_ldstreg : in std_logic_vector(5 downto 0);
      issue_ldstdp  : in std_ulogic;
      issue_op3_0   : in std_ulogic;
      issue_flop    : in std_logic_vector(8 downto 0);
      issue_rd      : in std_logic_vector(4 downto 0);
      issue_rs1     : in std_logic_vector(4 downto 0);
      issue_rs2     : in std_logic_vector(4 downto 0);
      issue_dfqdata : in std_logic_vector(63 downto 0);
      issue_id      : out std_logic_vector(4 downto 0);
      --   Commit interface
      commit        : in std_ulogic;
      commitid      : in std_logic_vector(4 downto 0);
      lddata        : in std_logic_vector(63 downto 0);
      --   Store data interface
      stdata        : out std_logic_vector(63 downto 0);
      --   Mispredict/trap interface
      unissue       : in std_ulogic;
      unissue_sid   : in std_logic_vector(4 downto 0);
      --   Special store handling (for side effects)
      spstore_pend  : in std_ulogic;
      spstore_done  : in std_ulogic;
      --   Floating-point condition codes
      fccready      : out std_ulogic;
      fcc           : out std_logic_vector(1 downto 0);
      --   Idle signal
      fpcidle       : out std_ulogic;
      -- Control/Debug interface
      mosi_accen    : in  std_ulogic;
      mosi_addr     : in  std_logic_vector(5 downto 0);
      mosi_accwr    : in  std_ulogic;
      mosi_wrdata   : in  std_logic_vector(31 downto 0);
      miso_accrdy   : out std_ulogic;
      miso_rddata   : out std_logic_vector(31 downto 0);
      -- Legacy debug
      dbgfsr        : out std_logic_vector(31 downto 0)  -- FSR value
      );
  end component;

  component grfpu5
  generic (mul : integer range 0 to 3 := 0; tech : integer := 0; scantest : integer := 0);
  port(
    clk     : in std_logic;
    reset   : in std_logic;
    start   : in std_logic;
    inmode  : in std_logic_vector;
    outmode : in std_logic_vector;
    flop    : in std_logic_vector(8 downto 0);
    op1     : in std_logic_vector(63 downto 0);
    op2     : in std_logic_vector(63 downto 0);
    opid    : in std_logic_vector(7 downto 0);
    flush   : in std_logic;
    flushid : in std_logic_vector(5 downto 0);
    rndmode : in std_logic_vector(1 downto 0);
    res     : out std_logic_vector(63 downto 0);
    exc     : out std_logic_vector(6 downto 0);
    allow   : out std_logic_vector(2 downto 0);
    rdy     : out std_logic;
    idout   : out std_logic_vector(7 downto 0);
    cmprdy  : out std_ulogic;
    cmpidout: out std_logic_vector(7 downto 0);
    cmpcc   : out std_logic_vector(1 downto 0);
    cmpnv   : out std_ulogic;
    testen  : in  std_ulogic := '0';
    testrst : in  std_ulogic := '1'
    );
  end component;

  -----------------------------------------------------------------------------
  -- Debug module
  -----------------------------------------------------------------------------
  component dbgmod5 is
    generic (
      fabtech   : integer;
      memtech   : integer;
      ncpu      : integer;
      ndbgmst   : integer;
      busw      : integer;
      cpumidx   : integer;
      dsuhaddr  : integer;
      dsuhmask  : integer;
      pnpaddrhi : integer;
      pnpaddrlo : integer;
      dsuslvidx : integer;
      dsumstidx : integer;
      bretryen  : integer;
      plmdata   : integer;
      atkbytes  : integer;
      itentr    : integer;
      widetime  : integer;
      cmemconf  : integer;
      rfconf    : integer
      );
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      bretclk  : in  std_ulogic;
      bretrstn : in  std_ulogic;
      rstreqn  : out std_ulogic;
      cpurstn  : out std_logic_vector(0 to ncpu-1);
      dbgmi    : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
      dbgmo    : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
      cpumi    : in  ahb_mst_in_type;
      cpumo    : out ahb_mst_out_type;
      cpusi    : in  ahb_slv_in_type;
      dsuen    : in  std_ulogic;
      dsubreak : in  std_ulogic;
      dbgi     : out l5_debug_in_vector(0 to ncpu-1);
      dbgo     : in  l5_debug_out_vector(0 to ncpu-1);
      itod     : in  l5_irq_dbg_vector(0 to ncpu-1);
      dtoi     : out l5_dbg_irq_vector(0 to ncpu-1);
      tpi      : in  trace_port_in_vector(0 to NCPU-1);
      tco      : out trace_control_out_vector(0 to NCPU-1);
      tstop    : out std_ulogic;
      dbgtime  : out std_logic_vector(31 downto 0);
      maskerrn : out std_logic_vector(0 to NCPU-1);
      uartie   : in  uart_in_type;
      uartoe   : out uart_out_type;
      uartii   : out uart_in_type;
      uartoi   : in  uart_out_type;
      sysstat  : in  std_logic_vector(15 downto 0);
      bretin   : in  leon5_bretry_in_type;
      bretout  : out leon5_bretry_out_type
      );
  end component;

  -----------------------------------------------------------------------------
  -- Interrupt controller
  -----------------------------------------------------------------------------
  component irqmp5 is
    generic (
      pindex  : integer := 0;
      paddr   : integer := 0;
      pmask   : integer := 16#fff#;
      ncpu    : integer := 1;
      eirq    : integer := 0;
      irqmap  : integer := 0;
      bootreg : integer := 1;
      extrun  : integer range 0 to 1 := 0
      );
    port (
      rst    : in  std_ulogic;
      clk    : in  std_ulogic;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      irqi   : in  l5_irq_out_vector(0 to ncpu-1);
      irqo   : out l5_irq_in_vector(0 to ncpu-1);
      itod   : out l5_irq_dbg_vector(0 to ncpu-1);
      dtoi   : in  l5_dbg_irq_vector(0 to ncpu-1);
      cpurun : in  std_logic_vector(ncpu-1 downto 0) := (others => '0')
      );
  end component;

end package;

