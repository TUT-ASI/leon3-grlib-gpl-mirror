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
-- Package:     cpucore5int
-- File:        cpucore5int.vhd
-- Description: Internal components and types for LEON5 CPU core and debug
--              module.
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
use gaisler.leon5int.all;

package cpucore5int is

  constant LEON5_VERSION : integer := 0;

  ----------------------------------------------------------------------------
  -- Types
  ----------------------------------------------------------------------------

  type fpc5_in_type is record
    issue_cmd     : std_logic_vector(2 downto 0);
    issue_ldstreg : std_logic_vector(5 downto 0);
    issue_ldstdp  : std_ulogic;
    issue_op3_0   : std_ulogic;
    issue_flop    : std_logic_vector(8 downto 0);
    issue_rd      : std_logic_vector(4 downto 0);
    issue_rs1     : std_logic_vector(4 downto 0);
    issue_rs2     : std_logic_vector(4 downto 0);
    issue_dfqdata : std_logic_vector(63 downto 0);
    commit        : std_ulogic;
    commitid      : std_logic_vector(4 downto 0);
    lddata        : std_logic_vector(63 downto 0);
    unissue       : std_ulogic;
    unissue_sid   : std_logic_vector(4 downto 0);
    spstore_pend  : std_ulogic;
    spstore_done  : std_ulogic;
    mosi          : l5_intreg_mosi_type;
  end record;

  type fpc5_out_type is record
    ready_flop   : std_ulogic;
    ready_ld     : std_logic_vector(0 to 35);
    ready_st     : std_logic_vector(0 to 35);
    trapon_flop  : std_ulogic;
    trapon_ldst  : std_ulogic;
    trapon_stdfq : std_ulogic;
    issue_id     : std_logic_vector(4 downto 0);
    stdata       : std_logic_vector(63 downto 0);
    fccready     : std_ulogic;
    fcc          : std_logic_vector(1 downto 0);
    fpcidle      : std_ulogic;
    dbgfsr       : std_logic_vector(31 downto 0);  -- FSR value
    miso         : l5_intreg_miso_type;
  end record;

  constant fpc5_out_none : fpc5_out_type := (
    ready_flop => '0',
    ready_ld => (others=>'0'),
    ready_st => (others=>'0'),
    trapon_flop => '0',
    trapon_ldst => '0',
    trapon_stdfq => '0',
    issue_id => (others=>'0'),
    stdata => (others=>'0'),
    fccready => '0',
    fcc => "00",
    fpcidle => '0',
    dbgfsr => (others=>'0'),
    miso => l5_intreg_miso_none
    );

  type fpc5_in_vector is array(natural range <>) of fpc5_in_type;
  type fpc5_out_vector is array(natural range <>) of fpc5_out_type;

  type fpu_regfile_in_type is record
    raddr1 : std_logic_vector(4 downto 1);
    ren1   : std_logic_vector(1 downto 0);
    raddr2 : std_logic_vector(4 downto 1);
    ren2   : std_logic_vector(1 downto 0);
    raddr3 : std_logic_vector(4 downto 1);
    ren3   : std_logic_vector(1 downto 0);
    waddr  : std_logic_vector(4 downto 1);
    wen    : std_logic_vector(1 downto 0);
    wdata  : std_logic_vector(63 downto 0);
  end record;

  type fpu_regfile_out_type is record
    rdata1 : std_logic_vector(63 downto 0);
    rdata2 : std_logic_vector(63 downto 0);
    rdata3 : std_logic_vector(63 downto 0);
  end record;
  
  ----------------------------------------------------------------------------
  -- Internal parts inside single core block
  ----------------------------------------------------------------------------
  constant TAG_HIGH     : integer := 31;
  constant CTAG_LRRPOS  : integer := 9;
  constant CTAG_LOCKPOS : integer := 8;
  constant MAXSETS      : integer := 4;

  type cdatatype5 is array (0 to 3) of std_logic_vector(63 downto 0);
  type cdatatype5s is array (0 to 3) of std_logic_vector(31 downto 0);

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

  type icache_in_type5 is record
    rpc              : std_logic_vector(31 downto 0); -- raw address (npc)
    fpc              : std_logic_vector(31 downto 0); -- latched address (fpc)
    dpc              : std_logic_vector(31 downto 0); -- latched address (dpc)
    rbranch          : std_ulogic; -- Instruction branch
    fbranch          : std_ulogic; -- Instruction branch
    inull            : std_ulogic; -- instruction nullify
    su               : std_ulogic; -- super-user
    flush            : std_ulogic; -- flush icache
    fline            : std_logic_vector(31 downto 3); -- flush line offset
    pnull            : std_ulogic;
    nobpmiss         : std_ulogic; -- Predicted instruction, block hold
    iustall          : std_ulogic;
    parkreq          : std_ulogic; -- Cache controller park request
  end record;

  type icache_out_type5 is record
    data             : cdatatype5;
    way              : std_logic_vector(1 downto 0);
    mexc             : std_ulogic;
    mexcdata         : std_logic_vector(7 downto 0);
    hold             : std_ulogic;
    flush            : std_ulogic; -- flush in progress
    mds              : std_ulogic; -- memory data strobe
    cfg              : std_logic_vector(31 downto 0);
    bpmiss           : std_ulogic;
    eocl             : std_ulogic;
    ics_btb          : std_logic_vector(1 downto 0);
    btb_flush        : std_logic;
    ctxswitch        : std_ulogic;
    parked           : std_ulogic;
  end record;

  type dcache_in_type5 is record
    asi              : std_logic_vector(7 downto 0);
    maddress         : std_logic_vector(31 downto 0);
    easi            : std_logic_vector(7 downto 0);
    eaddress         : std_logic_vector(31 downto 0);
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
    intack           : std_ulogic;
    eread            : std_ulogic;
    mmucacheclr      : std_ulogic;
    trapack          : std_ulogic;
    trapacktt        : std_logic_vector(7 downto 0);
    trapackpc        : std_logic_vector(31 downto 0);
    trapackidata     : std_logic_vector(7 downto 0);
    bar              : std_logic_vector(2 downto 0);
    iudiag_miso      : l5_intreg_miso_type;
  end record;

  type dcache_out_type5 is record
    data             : cdatatype5;
    way              : std_logic_vector(1 downto 0);
    mexc             : std_ulogic;
    hold             : std_ulogic;
    mds              : std_ulogic;
    dtrapet1         : std_ulogic;
    dtrapet0         : std_ulogic;
    dtraptt          : std_logic_vector(5 downto 0);
    cache            : std_ulogic;
    wbhold           : std_ulogic; -- write buffer hold
    iudiag_mosi      : l5_intreg_mosi_type;
    iuctrl           : iu_control_reg_type;
  end record;

  type iregfile_in_type5 is record
    raddr1      : std_logic_vector(9 downto 0); -- read address 1
    raddr2      : std_logic_vector(9 downto 0); -- read address 2
    raddr3      : std_logic_vector(9 downto 0); -- read address 3
    raddr4      : std_logic_vector(9 downto 0); -- read address 4
    waddr1      : std_logic_vector(9 downto 0); -- write address
    waddr2      : std_logic_vector(9 downto 0); -- write address
    wdata1      : std_logic_vector(63 downto 0); -- write data
    wdata2      : std_logic_vector(63 downto 0); -- write data
    rdhold      : std_logic;
    re1         : std_logic_vector(1 downto 0);-- read 1 enable
    re2         : std_logic_vector(1 downto 0);-- read 2 enable
    re3         : std_logic_vector(1 downto 0);-- read 2 enable
    re4         : std_logic_vector(1 downto 0);-- read 2 enable
    rgz1        : std_logic;            --port1 g0 read
    rgz2        : std_logic;            --port2 g0 read
    rgz3        : std_logic;            --port3 g0 read
    rgz4        : std_logic;            --port4 g0 read
    we1         : std_logic_vector(1 downto 0);         -- write enable
    we2         : std_logic_vector(1 downto 0);
  end record;

  type iregfile_out_type5 is record
    rdata1      : std_logic_vector(63 downto 0); -- read data 1
    rdata2      : std_logic_vector(63 downto 0); -- read data 2
    rdata3      : std_logic_vector(63 downto 0); -- read data 3
    rdata4      : std_logic_vector(63 downto 0); -- read data 2
  end record;

  type tracebuf_in_type5 is record
    addr             : std_logic_vector(11 downto 0);
    data             : std_logic_vector(255 downto 0);
    enable           : std_logic;
    write            : std_logic_vector(7 downto 0);
  end record;

  type tracebuf_out_type5 is record
    data             : std_logic_vector(255 downto 0);
  end record;

  type itracebuf_in_type5 is record
    addr0            : std_logic_vector(11 downto 0);
    addr1            : std_logic_vector(11 downto 0);
    data0            : std_logic_vector(191 downto 0);
    data1            : std_logic_vector(191 downto 0);
    enable           : std_logic_vector(1 downto 0);
    write            : std_logic_vector(1 downto 0);
  end record;

  type itracebuf_out_type5 is record
    data            : std_logic_vector(383 downto 0);
  end record;

  type tracebuf_2p_in_type5 is record
    renable          : std_logic;
    raddr            : std_logic_vector(11 downto 0);
    write            : std_logic_vector(7 downto 0);
    waddr            : std_logic_vector(11 downto 0);
    data             : std_logic_vector(255 downto 0);
  end record;

  type tracebuf_2p_out_type5 is record
    data             : std_logic_vector(255 downto 0);
  end record;

  constant tracebuf_out_type5_none : tracebuf_out_type5 :=
    (data => (others => '0'));

  constant tracebuf_in_type5_none : tracebuf_in_type5 := (
    addr    => (others => '0'),
    data    => (others => '0'),
    enable  => '0',
    write   => (others => '0')
    );

  constant tracebuf_2p_out_type5_none : tracebuf_2p_out_type5 :=
    (data => (others => '0'));

  constant tracebuf_2p_in_type5_none : tracebuf_2p_in_type5 := (
    renable => '0',
    raddr   => (others => '0'),
    write   => (others => '0'),
    waddr   => (others => '0'),
    data    => (others => '0')
    );

  -----------------------------------------------------------------------------
  -- Internal parts inside debug module block
  -----------------------------------------------------------------------------
  component tbufmem5 is
    generic (
      tech   : integer;
      tbuf   : integer; -- trace buf size in kB (0 - no trace buffer)
      dwidth : integer; -- AHB data width
      proc   : integer;
      testen : integer
      );
    port (
      clk : in std_ulogic;
      di  : in tracebuf_in_type5;
      do  : out tracebuf_out_type5;
      testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
      );
  end component;

  -----------------------------------------------------------------------------
  -- ITRACE buffer
  -----------------------------------------------------------------------------
  component itbufmem5 is
    generic (
      tech   : integer;
      entry  : integer;
      testen : integer
      );
    port (
      clk : in std_ulogic;
      di  : in itracebuf_in_type5;
      do  : out itracebuf_out_type5;
      testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
      );
  end component;

  constant TAGMAX: integer := 32;
  constant IDXMAX: integer := 16;

  type cram_tags is array(0 to 3) of std_logic_vector(TAGMAX-1 downto 0);

  type cram_in_type5 is record
    iindex     : std_logic_vector(IDXMAX-1 downto 0);
    itagen     : std_logic_vector(0 to 3);
    itagwrite  : std_ulogic;
    itagdin    : cram_tags;
    idataoffs  : std_logic_vector(1 downto 0);
    idataen    : std_logic_vector(0 to 3);
    idatawrite : std_logic_vector(1 downto 0);
    idatadin   : std_logic_vector(63 downto 0);
    ifulladdr  : std_logic_vector(31 downto 0);
    itcmen     : std_ulogic;
    itcmwrite  : std_logic_vector(1 downto 0);
    itcmdin    : std_logic_vector(63 downto 0);
    -- Cache read port
    dtagcindex : std_logic_vector(IDXMAX-1 downto 0);
    dtagcen    : std_logic_vector(0 to 3);
    -- Cache update and snoop hit port
    dtaguindex : std_logic_vector(IDXMAX-1 downto 0);
    dtaguwrite : std_logic_vector(0 to 3);
    dtagudin   : cram_tags;
    -- Combined read/update port (without snoop hit)
    dtagcuindex: std_logic_vector(IDXMAX-1 downto 0);
    dtagcuen   : std_logic_vector(0 to 3);
    dtagcuwrite: std_ulogic;
    -- Snoop tag read and write
    dtagsindex : std_logic_vector(IDXMAX-1 downto 0);
    dtagsen    : std_logic_vector(0 to 3);
    dtagswrite : std_ulogic;
    dtagsdin   : cram_tags;
    -- DCache data
    ddataindex : std_logic_vector(IDXMAX-1 downto 0);
    ddataoffs  : std_logic_vector(1 downto 0);
    ddataen    : std_logic_vector(0 to 3);
    ddatawrite : std_logic_vector(7 downto 0);
    ddatadin   : cdatatype5;
    ddatafulladdr : std_logic_vector(31 downto 0);
    dtcmen     : std_ulogic;
    dtcmdin    : std_logic_vector(63 downto 0);
    dtcmwrite : std_logic_vector(7 downto 0);
  end record;

  type cram_out_type5 is record
    itagdout: cram_tags;
    idatadout: cdatatype5;
    itcmdout: std_logic_vector(63 downto 0);
    dtagcdout: cram_tags;
    dtagsdout: cram_tags;
    ddatadout: cdatatype5;
    dtcmdout: std_logic_vector(63 downto 0);
  end record;

  constant MAX_PREDICTOR_BITS  : integer := 2;
  constant XLEN                 : integer := 64;

  type l5_bht_in_type is record
    raddr_comb   : std_logic_vector(XLEN-1 downto 0);
    rindex_bhist : std_logic_vector(XLEN-1 downto 0);
    waddr        : std_logic_vector(XLEN-1 downto 0);
    iustall      : std_logic;
    wen          : std_logic;
    taken        : std_logic;
    flush        : std_logic;
    ren          : std_logic;
    bhistory     : std_logic_vector(4 downto 0);
    phistory     : std_logic_vector(31 downto 0);
    btb_taken    : std_logic;
  end record;

  type l5_bht_out_type is record
    rdata       : std_logic_vector(1 downto 0);
    taken       : std_logic;
    btb_taken   : std_logic;
    bhistory    : std_logic_vector(4 downto 0);
    phistory    : std_logic_vector(31 downto 0);
  end record;

  constant l5_bht_out_none : l5_bht_out_type := (
    rdata       => (others => '0'),
    taken       => '0',
    btb_taken   => '0',
    bhistory    => (others=>'0'),
    phistory    => (others=>'0')
  );

  -- Branch Target Buffer -----------------------------------------------------
  type l5_btb_in_type is record
    raddr       : std_logic_vector(XLEN-1 downto 0);
    waddr       : std_logic_vector(XLEN-1 downto 0);
    wen         : std_ulogic;
    wdata       : std_logic_vector(XLEN-1 downto 0);
    flush       : std_ulogic;
  end record;

  type l5_btb_out_type is record
    rdata       : std_logic_vector(XLEN-1 downto 0);
    ralign      : std_ulogic;
    hit         : std_ulogic;
  end record;

  constant l5_btb_out_none : l5_btb_out_type := (
    rdata       => (others => '0'),
    ralign      => '0',
    hit         => '0'
  );

  type l5_btb_diag_in_type is record
    addr     : std_logic_vector(31 downto 0);
    en       : std_logic;
    wren     : std_logic;
    wrdata   : std_logic_vector(31 downto 0);
  end record;

  type l5_btb_diag_out_type is record
    rdata : std_logic_vector(31 downto 0);
  end record;

  constant l5_btb_diag_in_none : l5_btb_diag_in_type := (
    addr => (others => '0'),
    en => '0',
    wren => '0',
    wrdata => (others => '0')
    );

  constant l5_btb_diag_out_none : l5_btb_diag_out_type := (
    rdata => (others => '0')
    );

  component iu5 is
    generic (
      nwin        : integer range 2 to 32;
      iways       : integer range 1 to 4;
      dways       : integer range 1 to 4;
      mulimpl     : integer range 0 to 63;
      cp          : integer range 0 to 1;
      nwp         : integer range 0 to 4;
      pclow       : integer range 0 to 2;
      index       : integer range 0 to 15;
      disas       : integer range 0 to 2;
      rstaddr     : integer                              ;  -- reset vector MSB address
      fabtech     : integer range 0 to NTECH     ;
      scantest    : integer                      ;
      memtech     : integer range 0 to NTECH;
      rfconf      : integer;
      cgen        : integer range 0 to 1
      );
    port (
      clk         : in  std_logic;
      uclk        : in  std_ulogic;
      rstn        : in  std_logic;
      holdn       : in  std_logic;
      ici         : out icache_in_type5;
      ico         : in  icache_out_type5;
      dci         : out dcache_in_type5;
      dco         : in  dcache_out_type5;
      rfi         : out iregfile_in_type5;
      rfo         : in  iregfile_out_type5;
      irqi        : in  l5_irq_in_type;
      irqo        : out l5_irq_out_type;
      dbgi        : in  l5_debug_in_type;
      dbgo        : out l5_debug_out_type;
      muli        : out mul32_in_type;
      mulo        : in  mul32_out_type;
      divi        : out div32_in_type;
      divo        : in  div32_out_type;
      fpu5o       : in  fpc5_out_type;
      fpu5i       : out fpc5_in_type;
      tpo         : out trace_port_out_type;
      tco         : in  trace_control_out_type; 
      fpc_retire  : in  std_logic;
      fpc_rfwen   : in  std_logic_vector(1 downto 0);
      fpc_rfwdata : in  std_logic_vector(63 downto 0);
      fpc_retid   : in  std_logic_vector(4 downto 0);
      testen      : in  std_logic;
      testrst     : in  std_logic;
      testin      : in std_logic_vector(TESTIN_WIDTH-1 downto 0);
      perf        : out std_logic_vector(63 downto 0)
      );
  end component;

  component cctrl5 is
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
      dtcmen    : integer range 0 to 1;
      dtcmabits : integer range 1 to 20;
      itlbnum   : integer range 2 to 64;
      dtlbnum   : integer range 2 to 64;
      cached    : integer;
      wbmask    : integer;
      busw      : integer;
      cdataw    : integer;
      tlbrepl    : integer
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
  end component;

  component cachemem5 is
    generic (
      tech      : integer range 0 to NTECH;
      iways     : integer range 1 to 4;
      ilinesize : integer range 4 to 8;
      iidxwidth : integer range 1 to 10;
      itagwidth : integer range 1 to 32;
      itcmen    : integer range 0 to 1;
      itcmabits : integer range 1 to 20;
      dways     : integer range 1 to 4;
      dlinesize : integer range 4 to 8;
      didxwidth : integer range 1 to 10;
      dtagwidth : integer range 1 to 32;
      dtagconf  : integer range 0 to 2;
      dusebw    : integer range 0 to 1;
      dtcmen    : integer range 0 to 1;
      dtcmabits : integer range 1 to 20;
      testen    : integer range 0 to 1
      );
    port (
      rstn  : in  std_ulogic;
      clk   : in  std_ulogic;
      sclk  : in  std_ulogic;
      crami : in  cram_in_type5;
      cramo : out cram_out_type5;
      testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
      );
  end component;

  component regfile5_ram is
    generic (
      tech    : integer;
      abits   : integer;
      dbits   : integer;
      wrfst   : integer;
      numregs : integer;
      g0addr  : integer;
      rfconf  : integer;
      testen  : integer
      );
    port (
      clk      : in  std_logic;
      rstn     : in  std_logic;
      rdhold   : in  std_logic;
      waddr1   : in  std_logic_vector((abits -1) downto 0);
      wdata1   : in  std_logic_vector((dbits -1) downto 0);
      we1      : in  std_logic_vector(1 downto 0);
      waddr2   : in  std_logic_vector((abits -1) downto 0);
      wdata2   : in  std_logic_vector((dbits -1) downto 0);
      we2      : in  std_logic_vector(1 downto 0);
      raddr1   : in  std_logic_vector((abits -1) downto 0);
      re1      : in  std_logic_vector(1 downto 0);
      rgz1     : in  std_logic;
      rdata1   : out std_logic_vector((dbits -1) downto 0);
      raddr2   : in  std_logic_vector((abits -1) downto 0);
      re2      : in  std_logic_vector(1 downto 0);
      rgz2     : in  std_logic;
      rdata2   : out std_logic_vector((dbits -1) downto 0);
      raddr3   : in  std_logic_vector((abits -1) downto 0);
      re3      : in  std_logic_vector(1 downto 0);
      rgz3     : in  std_logic;
      rdata3   : out std_logic_vector((dbits -1) downto 0);
      raddr4   : in  std_logic_vector((abits -1) downto 0);
      re4      : in  std_logic_vector(1 downto 0);
      rgz4     : in  std_logic;
      rdata4   : out std_logic_vector((dbits -1) downto 0);
      testin   : in  std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
      );
  end component;

  component regfile5_dff 
    generic (
      abits   : integer;
      dbits   : integer;
      wrfst   : integer;
      numregs : integer;
      g0addr  : integer;
      rfconf  : integer
      );
    port (
      clk    : in  std_logic;
      rstn   : in  std_logic;
      rdhold : in  std_logic;
      waddr1 : in  std_logic_vector((abits -1) downto 0);
      wdata1 : in  std_logic_vector((dbits -1) downto 0);
      we1    : in  std_logic_vector(1 downto 0);
      waddr2 : in  std_logic_vector((abits -1) downto 0);
      wdata2 : in  std_logic_vector((dbits -1) downto 0);
      we2    : in  std_logic_vector(1 downto 0);
      raddr1 : in  std_logic_vector((abits -1) downto 0);
      re1    : in  std_logic_vector(1 downto 0);
      rdata1 : out std_logic_vector((dbits -1) downto 0);
      raddr2 : in  std_logic_vector((abits -1) downto 0);
      re2    : in  std_logic_vector(1 downto 0);
      rdata2 : out std_logic_vector((dbits -1) downto 0);
      raddr3 : in  std_logic_vector((abits -1) downto 0);
      re3    : in  std_logic_vector(1 downto 0);
      rdata3 : out std_logic_vector((dbits -1) downto 0);
      raddr4 : in  std_logic_vector((abits -1) downto 0);
      re4    : in  std_logic_vector(1 downto 0);
      rdata4 : out std_logic_vector((dbits -1) downto 0)
      );
  end component;

  component regfile_fpu is
    port (
      clk       : in  std_logic;
      rstn      : in  std_logic;
      rf_raddr1 : in  std_logic_vector(4 downto 1);
      rf_ren1   : in  std_logic_vector(1 downto 0);
      rf_rdata1 : out std_logic_vector(63 downto 0);
      rf_raddr2 : in  std_logic_vector(4 downto 1);
      rf_ren2   : in  std_logic_vector(1 downto 0);
      rf_rdata2 : out std_logic_vector(63 downto 0);
      rf_raddr3 : in  std_logic_vector(4 downto 1);
      rf_ren3   : in  std_logic_vector(1 downto 0);
      rf_rdata3 : out std_logic_vector(63 downto 0);
      rf_waddr  : in  std_logic_vector(4 downto 1);
      rf_wen    : in  std_logic_vector(1 downto 0);
      rf_wdata  : in  std_logic_vector(63 downto 0)
      );
  end component;

  component bht_pap is
    generic (
      tech        : integer;
      nentries    : integer range 32 to 1024      ;       -- Number of Entries
      hlength     : integer range 2  to 10        ;       -- History Length
      testen      : integer
      );
    port (
      clk         : in  std_logic;
      rstn        : in  std_logic;
      holdn       : in  std_logic;
      bhti        : in  l5_bht_in_type;
      bhto        : out l5_bht_out_type;
      diag_in     : in  l5_btb_diag_in_type;
      diag_out    : out  l5_btb_diag_out_type;
      testin      : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
      );
  end component;

  component btb is
    generic (
      nentries : integer range 8 to 128  -- Number of Entries
      );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      btb_flush   : in  std_logic;
      btb_wen     : in  std_logic;
      btb_instpc  : in  std_logic_vector(31 downto 0);
      btb_indata  : in  std_logic_vector(31 downto 0);
      btb_pcread  : in  std_logic_vector(31 downto 0);
      btb_hit     : out std_logic;
      btb_outdata : out std_logic_vector(31 downto 0);
      diag_in     : in  l5_btb_diag_in_type;
      diag_out    : out l5_btb_diag_out_type
      );
  end component;

  -----------------------------------------------------------------------------
  -- Misc utilities
  -----------------------------------------------------------------------------


--pragma translate_off
  component inst_text is
    port (
      inst : in std_logic_vector(31 downto 0));
  end component;

--pragma translate_on

end package;


package body cpucore5int is




end package body;
