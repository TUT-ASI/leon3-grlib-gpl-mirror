-----------------------------------------------------------------------------
--  LEON3 Xilinx KCU105 Demonstration design
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
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib, techmap;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
use techmap.gencomp.all;
use techmap.allclkgen.all;

library gaisler;
use gaisler.memctrl.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.spi.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.i2c.all;
use gaisler.l2cache.all;
use gaisler.subsys.all;
use gaisler.axi.all;
use gaisler.spacewire.all;
use gaisler.leon3.all;
-- pragma translate_off
use gaisler.sim.all;

library unisim;
use unisim.all;
-- pragma translate_on

library testgrouppolito;
use testgrouppolito.dprc_pkg.all;

use work.config.all;

entity leon3mp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart                 : integer := CFG_DUART;   -- Print UART on console
    pclow                   : integer := CFG_PCLOW;
    migmodel                : boolean := false;
    autonegotiation         : integer := 1
  );
  port (
    -- Clock and Reset
    reset       : in    std_ulogic;
    clk300p     : in    std_ulogic;  -- 300 MHz clock
    clk300n     : in    std_ulogic;  -- 300 MHz clock
    -- Switches
    switch      : in    std_logic_vector(3 downto 0);
    -- LEDs
    led         : out   std_logic_vector(7 downto 0);
    -- GPIOs
    gpio        : inout std_logic_vector(15 downto 0);
    -- I2C
    iic_scl     : inout std_ulogic;
    iic_sda     : inout std_ulogic;
    iic_mreset  : in    std_ulogic;  -- I2C Mux Reset
    -- Ethernet
    gtrefclk_n  : in    std_logic;
    gtrefclk_p  : in    std_logic;
    txp         : out   std_logic;
    txn         : out   std_logic;
    rxp         : in    std_logic;
    rxn         : in    std_logic;
    emdio       : inout std_logic;
    emdc        : out   std_ulogic;
    eint        : in    std_ulogic;
    erst        : out   std_ulogic;
    -- UART
    dsurx       : in    std_ulogic;
    dsutx       : out   std_ulogic;
    dsuctsn     : in    std_ulogic;
    dsurtsn     : out   std_ulogic;
    -- Push Buttons (Active High)
    button      : in    std_logic_vector(4 downto 0);
    -- SpaceWire, signals to Star-Dundee FMC-SPW/SpFi Board
    spw_dout_p  : out   std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    spw_dout_n  : out   std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    spw_sout_p  : out   std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    spw_sout_n  : out   std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    spw_din_p   : in    std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    spw_din_n   : in    std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    spw_sin_p   : in    std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    spw_sin_n   : in    std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    -- DDR4 (MIG)
    ddr4_dq     : inout std_logic_vector(63 downto 0);
    ddr4_dqs_c  : inout std_logic_vector(7 downto 0); -- Data Strobe
    ddr4_dqs_t  : inout std_logic_vector(7 downto 0); -- Data Strobe
    ddr4_addr   : out   std_logic_vector(13 downto 0);-- Address
    ddr4_ras_n  : out   std_ulogic;
    ddr4_cas_n  : out   std_ulogic;
    ddr4_we_n   : out   std_ulogic;
    ddr4_ba     : out   std_logic_vector(1 downto 0); -- Device bank address per group
    ddr4_bg     : out   std_logic_vector(0 downto 0); -- Device bank group address
    ddr4_dm_n   : inout std_logic_vector(7 downto 0); -- Data Mask
    ddr4_ck_c   : out   std_logic_vector(0 downto 0); -- Clock Negative Edge
    ddr4_ck_t   : out   std_logic_vector(0 downto 0); -- Clock Positive Edge
    ddr4_cke    : out   std_logic_vector(0 downto 0); -- Clock Enable
    ddr4_act_n  : out   std_ulogic;                   -- Command Input
    ddr4_alert_n: in    std_ulogic;                   -- Alert Output
    ddr4_odt    : out   std_logic_vector(0 downto 0); -- On-die Termination
    ddr4_par    : out   std_ulogic;                   -- Parity for cmd and addr
    ddr4_ten    : out   std_ulogic;                   -- Connectivity Test Mode
    ddr4_cs_n   : out   std_logic_vector(0 downto 0); -- Chip Select
    ddr4_reset_n: out   std_ulogic                    -- Asynchronous Reset
  );
end;


architecture rtl of leon3mp is

  component axi_mig4_7series
    generic (
      pipelined : boolean := false;
      mem_bits  : integer := 30
    );
    port (
      calib_done          : out   std_logic;
      sys_clk_p           : in    std_logic;
      sys_clk_n           : in    std_logic;
      ddr4_addr           : out   std_logic_vector(13 downto 0);
      ddr4_we_n           : out   std_logic;
      ddr4_cas_n          : out   std_logic;
      ddr4_ras_n          : out   std_logic;
      ddr4_ba             : out   std_logic_vector(1 downto 0);
      ddr4_cke            : out   std_logic_vector(0 downto 0);
      ddr4_cs_n           : out   std_logic_vector(0 downto 0);
      ddr4_dm_n           : inout std_logic_vector(7 downto 0);
      ddr4_dq             : inout std_logic_vector(63 downto 0);
      ddr4_dqs_c          : inout std_logic_vector(7 downto 0);
      ddr4_dqs_t          : inout std_logic_vector(7 downto 0);
      ddr4_odt            : out   std_logic_vector(0 downto 0);
      ddr4_bg             : out   std_logic_vector(0 downto 0);
      ddr4_reset_n        : out   std_logic;
      ddr4_act_n          : out   std_logic;
      ddr4_ck_c           : out   std_logic_vector(0 downto 0);
      ddr4_ck_t           : out   std_logic_vector(0 downto 0);
      ddr4_ui_clk         : out   std_logic;
      ddr4_ui_clk_sync_rst: out   std_logic;
      rst_n_syn           : in    std_logic;
      rst_n_async         : in    std_logic;
      aximi               : out   axi_somi_type;
      aximo               : in    axi_mosi_type;
      -- Misc
      ddr4_ui_clkout1     : out   std_logic;
      clk_ref_i           : in    std_logic
    );
  end component;

  component sgmii_kcu105
    generic (
      pindex          : integer := 0;
      paddr           : integer := 0;
      pmask           : integer := 16#fff#;
      abits           : integer := 8;
      autonegotiation : integer := 1;
      pirq            : integer := 0;
      debugmem        : integer := 0;
      tech            : integer := 0;
      simulation      : integer := 0
    );
    port(
      sgmiii    : in  eth_sgmii_in_type;
      sgmiio    : out eth_sgmii_out_type;
      gmiii     : out eth_in_type;
      gmiio     : in  eth_out_type;
      reset     : in  std_logic;
      clkout0o  : out std_logic;
      clkout1o  : out std_logic;
      clkout2o  : out std_logic;
      apb_clk   : in  std_logic;
      apb_rstn  : in  std_logic;
      apbi      : in  apb_slv_in_type;
      apbo      : out apb_slv_out_type
    );
  end component;

  component IBUFDS
    generic (
      DQS_BIAS          : string := "FALSE";
      IOSTANDARD        : string := "DEFAULT"
      );
    port (
      O         : out std_ulogic;
      I         : in  std_ulogic;
      IB        : in  std_ulogic
    );
  end component;

  component ahb2axi_mig4_7series
    generic (
      pipelined               : boolean := false;
      hindex                  : integer := 0;
      haddr                   : integer := 0;
      hmask                   : integer := 16#f00#;
      pindex                  : integer := 0;
      paddr                   : integer := 0;
      pmask                   : integer := 16#fff#
    );
    port (
      calib_done          : out   std_logic;
      sys_clk_p           : in    std_logic;
      sys_clk_n           : in    std_logic;
      ddr4_addr           : out   std_logic_vector(13 downto 0);
      ddr4_we_n           : out   std_logic;
      ddr4_cas_n          : out   std_logic;
      ddr4_ras_n          : out   std_logic;
      ddr4_ba             : out   std_logic_vector(1 downto 0);
      ddr4_cke            : out   std_logic_vector(0 downto 0);
      ddr4_cs_n           : out   std_logic_vector(0 downto 0);
      ddr4_dm_n           : inout std_logic_vector(7 downto 0);
      ddr4_dq             : inout std_logic_vector(63 downto 0);
      ddr4_dqs_c          : inout std_logic_vector(7 downto 0);
      ddr4_dqs_t          : inout std_logic_vector(7 downto 0);
      ddr4_odt            : out   std_logic_vector(0 downto 0);
      ddr4_bg             : out   std_logic_vector(0 downto 0);
      ddr4_reset_n        : out   std_logic;
      ddr4_act_n          : out   std_logic;
      ddr4_ck_c           : out   std_logic_vector(0 downto 0);
      ddr4_ck_t           : out   std_logic_vector(0 downto 0);
      ddr4_ui_clk         : out   std_logic;
      ddr4_ui_clk_sync_rst: out   std_logic;
      rst_n_syn           : in    std_logic;
      rst_n_async         : in    std_logic;

      ahbso               : out   ahb_slv_out_type;
      ahbsi               : in    ahb_slv_in_type;
      apbi                : in    apb_slv_in_type;
      apbo                : out   apb_slv_out_type;
      clk_amba            : in    std_logic;

      -- Misc
      ddr4_ui_clkout1     : out   std_logic;
      clk_ref_i           : in    std_logic
    );
  end component;

  component ddr_dummy
    port (
      ddr_dq           : inout std_logic_vector(63 downto 0);
      ddr_dqs          : inout std_logic_vector(7 downto 0);
      ddr_dqs_n        : inout std_logic_vector(7 downto 0);
      ddr_addr         : out   std_logic_vector(13 downto 0);
      ddr_ba           : out   std_logic_vector(2 downto 0);
      ddr_ras_n        : out   std_logic;
      ddr_cas_n        : out   std_logic;
      ddr_we_n         : out   std_logic;
      ddr_reset_n      : out   std_logic;
      ddr_ck_p         : out   std_logic_vector(0 downto 0);
      ddr_ck_n         : out   std_logic_vector(0 downto 0);
      ddr_cke          : out   std_logic_vector(0 downto 0);
      ddr_cs_n         : out   std_logic_vector(0 downto 0);
      ddr_dm           : out   std_logic_vector(7 downto 0);
      ddr_odt          : out   std_logic_vector(0 downto 0)
    );
  end component;

  -----------------------------------------------------
  -- Constants ----------------------------------------
  -----------------------------------------------------

  constant maxahbm      : integer := 16;
  constant maxahbs      : integer := 16;

  constant OEPOL        : integer := padoen_polarity(padtech);

  constant BOARD_FREQ   : integer := 300000; -- input frequency in KHz
  constant CPU_FREQ     : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV; -- cpu frequency in KHz

  constant USE_MIG_INTERFACE_MODEL : boolean := migmodel;

  constant ramfile      : string := "ram.srec"; -- ram contents

  -----------------------------------------------------
  -- Signals ------------------------------------------
  -----------------------------------------------------

  signal irqi : irq_in_vector(0 to CFG_NCPU - 1);
  signal irqo : irq_out_vector(0 to CFG_NCPU - 1);

  signal sysi : leon_dsu_stat_base_in_type;
  signal syso : leon_dsu_stat_base_out_type;

  signal perf : l3stat_in_type;

  signal ndsuact : std_ulogic;

  -- Misc
  signal vcc            : std_ulogic;
  signal gnd            : std_ulogic;
  signal stati          : ahbstat_in_type;
  signal dsu_sel        : std_ulogic;

  -- Memory
  signal mem_aximi      : axi_somi_type;
  signal mem_aximo      : axi_mosi_type;

  signal migrstn        : std_ulogic;
  signal calib_done     : std_ulogic;

  -- Memory AHB Signals
  signal mem_ahbmi      : ahb_mst_in_type;
  signal mem_ahbmo      : ahb_mst_out_type;
  signal mem_ahbsi      : ahb_slv_in_type;
  signal mem_ahbso      : ahb_slv_out_type;

  -- APB
  signal apbi           : apb_slv_in_type;
  signal apbo           : apb_slv_out_vector := (others => apb_none);

  -- AHB
  signal ahbsi          : ahb_slv_in_type;
  signal ahbso          : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi          : ahb_mst_in_type;
  signal ahbmo          : ahb_mst_out_vector := (others => ahbm_none);
  signal mig_ahbsi      : ahb_slv_in_type;
  signal mig_ahbso      : ahb_slv_out_type;

  -- Clocks and Reset
  signal clkm           : std_ulogic := '0';
  signal rstn           : std_ulogic;
  signal rstraw         : std_ulogic;
  signal cgi            : clkgen_in_type;
  signal cgo            : clkgen_out_type;

  attribute keep     : boolean;
  attribute keep of clkm : signal is true;

  signal lock           : std_ulogic;
  signal lclk           : std_ulogic;
  signal rst            : std_ulogic;
  signal clkref         : std_ulogic;

  -- Ethernet
  signal gmiii          : eth_in_type;
  signal gmiio          : eth_out_type;
  signal sgmiii         : eth_sgmii_in_type;
  signal sgmiio         : eth_sgmii_out_type;

  signal sgmiirst       : std_ulogic;
  signal ethernet_phy_int : std_ulogic;

  signal rxd1           : std_ulogic;
  signal txd1           : std_ulogic;

  signal ethi           : eth_in_type;
  signal etho           : eth_out_type;
  signal egtx_clk       : std_ulogic;
  signal negtx_clk      : std_ulogic;

  signal clkout0o       : std_ulogic;
  signal clkout1o       : std_ulogic;
  signal clkout2o       : std_ulogic;

  signal e1_debug_rx    : std_logic_vector(63 downto 0);
  signal e1_debug_tx    : std_logic_vector(63 downto 0);
  signal e1_debug_gtx   : std_logic_vector(63 downto 0);

  -- I2C
  signal i2ci           : i2c_in_type;
  signal i2co           : i2c_out_type;

  -- APB UART
  signal u1i            : uart_in_type;
  signal u1o            : uart_out_type;

  -- AHB UART
  signal dui            : uart_in_type;
  signal duo            : uart_out_type;

  signal dsurx_int      : std_ulogic;
  signal dsutx_int      : std_ulogic;
  signal dsuctsn_int    : std_ulogic;
  signal dsurtsn_int    : std_ulogic;
  signal monitor_tx_int : std_logic;
  signal monitor_rx_int : std_logic;

  -- Timers
  signal gpti           : gptimer_in_type;
  signal gpto           : gptimer_out_type;

  -- GPIOs
  signal gpioi          : gpio_in_type;
  signal gpioi1         : gpio_in_type;
  signal gpioo          : gpio_out_type;
  signal gpioo1         : gpio_out_type;

  -- JTAG
  signal tck            : std_ulogic;
  signal tckn           : std_ulogic;
  signal tms            : std_ulogic;
  signal tdi            : std_ulogic;
  signal tdo            : std_ulogic;

  -- SPI
  signal spii           : spi_in_type;
  signal spio           : spi_out_type;
  signal slvsel         : std_logic_vector(CFG_SPICTRL_SLVS - 1 downto 0);

  -- SpaceWire
  signal spwi           : grspw_in_type_vector(0 to CFG_SPW_NUM - 1);
  signal spwo           : grspw_out_type_vector(0 to CFG_SPW_NUM - 1);
  signal spw_rxclk0     : std_logic_vector(0 to CFG_SPW_NUM - 1);
  signal spw_rxclk1     : std_logic_vector(0 to CFG_SPW_NUM - 1);
  signal dtmp           : std_logic_vector(0 to CFG_SPW_PORTS * CFG_SPW_NUM - 1);
  signal stmp           : std_logic_vector(0 to CFG_SPW_PORTS * CFG_SPW_NUM - 1);
  signal spw_rxclkiv    : std_logic_vector(0 to CFG_SPW_PORTS * CFG_SPW_NUM - 1);
  signal spw_rxclkin    : std_ulogic;
  signal spw_txclk      : std_ulogic;

  constant mig_hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
    4 => ahb_membar(16#400#, '1', '1', 16#C00#),
    others => zero32);

begin

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------

  vcc         <= '1';
  gnd         <= '0';
  cgi.pllctrl <= "00";
  cgi.pllrst  <= rstraw;

  -- Clocks
  clk_gen : if (CFG_MIG_7SERIES = 0) generate
    clk_pad_ds : clkpad_ds generic map (
      tech      => padtech,
      level     => sstl12_dci,
      voltage   => x12v)
      port map (clk300p, clk300n, lclk);
    clkgen0 : clkgen        -- clock generator
      generic map (clktech, CFG_CLKMUL, CFG_CLKDIV, CFG_MCTRL_SDEN,
                   CFG_CLK_NOFB, 0, 0, 0, BOARD_FREQ)
      port map (lclk, lclk, clkm, open, open, open, open, cgi, cgo, open, open, open);
  end generate;

  reset_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (reset, rst);

  rst0 : rstgen        -- reset generator
    generic map (acthigh => 1, syncin => 0)
    port map (rst, clkm, lock, rstn, rstraw);
  lock <= calib_done when CFG_MIG_7SERIES = 1 else cgo.clklock;

  rst1 : rstgen         -- reset generator
    generic map (acthigh => 1)
    port map (rst, clkm, lock, migrstn, open);

  ----------------------------------------------------------------------
  ---  LEDs and BUTTONs ------------------------------------------------
  ----------------------------------------------------------------------

  dsuact_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(0), ndsuact);
  ndsuact <= not syso.dsu_active;
  
  led1_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(1), syso.proc_error);

  dsusel_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(5), dsu_sel);
  
  led6_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(6), calib_done);
  
  led7_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(7), lock);

  dsui_break_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (button(4), sysi.dsu_break);

  --Other leds and buttons used for GPIOs

  ----------------------------------------------------------------------
  ---  AHB CONTROLLER --------------------------------------------------
  ----------------------------------------------------------------------

  ahb0 : ahbctrl  -- AHB arbiter/multiplexer
    generic map (defmast => CFG_DEFMST, split => CFG_SPLIT,
                 rrobin  => CFG_RROBIN, ioaddr => CFG_AHBIO, fpnpen => CFG_FPNPEN,
                 nahbm   => maxahbm, nahbs => maxahbs, devid => XILINX_KC705)
    port map (
      rst  => rstn,
      clk  => clkm,
      msti => ahbmi,
      msto => ahbmo,  -- Incoming accesses
      slvi => ahbsi,  -- Outgoing accesses
      slvo => ahbso
    );

  ----------------------------------------------------------------------
  ---  LEON processor and DSU -----------------------------------------
  ----------------------------------------------------------------------

  leon : leon_dsu_stat_base
    generic map (
      leon        => CFG_LEON,     ncpu        => CFG_NCPU,
      fabtech     => fabtech,      memtech     => memtech,      memtechmod  => CFG_LEON_MEMTECH,
      nwindows    => CFG_NWIN,
      dsu         => CFG_DSU,
      fpu         => CFG_FPU,
      v8          => CFG_V8,
      cp          => 0,
      mac         => CFG_MAC,
      pclow       => pclow,
      notag       => 0,
      nwp         => CFG_NWP,
      icen        => CFG_ICEN,      irepl       => CFG_IREPL,      isets       => CFG_ISETS,
      ilinesize   => CFG_ILINE,     isetsize    => CFG_ISETSZ,     isetlock    => CFG_ILOCK,
      dcen        => CFG_DCEN,      drepl       => CFG_DREPL,      dsets       => CFG_DSETS,
      dlinesize   => CFG_DLINE,     dsetsize    => CFG_DSETSZ,     dsetlock    => CFG_DLOCK,
      dsnoop      => CFG_DSNOOP,
      ilram       => CFG_ILRAMEN,   ilramsize   => CFG_ILRAMSZ,    ilramstart  => CFG_ILRAMADDR,
      dlram       => CFG_DLRAMEN,   dlramsize   => CFG_DLRAMSZ,    dlramstart  => CFG_DLRAMADDR,
      mmuen       => CFG_MMUEN,
      itlbnum     => CFG_ITLBNUM,   dtlbnum     => CFG_DTLBNUM,
      tlb_type    => CFG_TLB_TYPE,  tlb_rep     => CFG_TLB_REP,
      lddel       => CFG_LDDEL,
      disas       => disas,
      tbuf        => CFG_ITBSZ,
      pwd         => CFG_PWD,
      svt         => CFG_SVT,
      rstaddr     => CFG_RSTADDR,
      smp         => CFG_NCPU-1,
      cached      => CFG_DFIXED,
      wbmask      => CFG_BWMASK,
      busw        => CFG_CACHEBW,
      netlist     => CFG_LEON_NETLIST,
      ft          => CFG_LEONFT_EN,
      npasi       => CFG_NP_ASI,
      pwrpsr      => CFG_WRPSR,
      rex         => CFG_REX,
      altwin      => CFG_ALTWIN,
      mmupgsz     => CFG_MMU_PAGE,
      grfpush     => CFG_GRFPUSH,
      dsu_hindex  => 2,
      dsu_haddr   => 16#D00#,
      dsu_hmask   => 16#F00#,
      atbsz       => CFG_ATBSZ,
      stat        => CFG_STAT_ENABLE,
      stat_pindex => 8,
      stat_paddr  => 16#100#,       stat_pmask  => 16#ffc#,
      stat_ncnt   => CFG_STAT_CNT,  stat_nmax   => CFG_STAT_NMAX
    )
    port map (
      rstn       => rstn,
      ahbclk     => clkm,
      cpuclk     => clkm,
      hclken     => vcc,
      leon_ahbmi => ahbmi,
      leon_ahbmo => ahbmo(CFG_NCPU - 1 downto 0),

      leon_ahbsi => ahbsi,
      leon_ahbso => ahbso,
      irqi       => irqi,
      irqo       => irqo,
      stat_apbi  => apbi,
      stat_apbo  => apbo(8),
      stat_ahbsi => ahbsi,
      stati      => perf,

      dsu_ahbsi  => ahbsi,
      dsu_ahbso  => ahbso(2),
      dsu_tahbmi => ahbmi,
      dsu_tahbsi => ahbsi,
      sysi       => sysi,
      syso       => syso
    );

  sysi.dsu_enable <= '1';

  -----------------------------------------------------------------------------
  -- Debug UART ---------------------------------------------------------------
  -----------------------------------------------------------------------------

  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map (hindex => CFG_NCPU + CFG_AHB_JTAG, pindex => 7, paddr => 7)
      port map (rstn, clkm, dui, duo, apbi, apbo(7), ahbmi, ahbmo(CFG_NCPU + CFG_AHB_JTAG));
    dui.extclk <= '0';
  end generate;

  nouah : if CFG_AHB_UART = 0 generate
    apbo(7)    <= apb_none;
    duo.txd    <= '0';
    duo.rtsn   <= '0';
    dui.extclk <= '0';
  end generate;

  sw4_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x12v)
    port map (switch(3), dsu_sel);

  dsutx_int     <= duo.txd     when dsu_sel = '1' else u1o.txd;
  dui.rxd       <= dsurx_int   when dsu_sel = '1' else '1';
  dsurtsn_int   <= duo.rtsn    when dsu_sel = '1' else u1o.rtsn;
  dui.ctsn      <= dsuctsn_int when dsu_sel = '1' else '1';
  u1i.rxd       <= dsurx_int   when dsu_sel = '0' else '1';
  u1i.ctsn      <= dsuctsn_int when dsu_sel = '0' else '1';

  dsurx_pad   : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech) port map (dsurx, dsurx_int);
  dsutx_pad   : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech) port map (dsutx, dsutx_int);
  dsuctsn_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech) port map (dsuctsn, dsuctsn_int);
  dsurtsn_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech) port map (dsurtsn, dsurtsn_int);

  -----------------------------------------------------------------------------
  -- JTAG debug link ----------------------------------------------------------
  -----------------------------------------------------------------------------

  ahbjtaggen0 : if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag
      generic map (tech => fabtech, hindex => CFG_NCPU)
      port map (rstn, clkm, tck, tms, tdi, tdo, ahbmi, ahbmo(CFG_NCPU),
                open, open, open, open, open, open, open, gnd);
  end generate;

  nojtag : if CFG_AHB_JTAG = 0 generate
    ahbmo(CFG_NCPU) <= ahbm_none;
  end generate;

  -----------------------------------------------------------------------------
  -- L2 cache, optionally covering DDR4 SDRAM memory controller
  -----------------------------------------------------------------------------
  l2cen : if CFG_L2_EN /= 0 generate
    l2cblock : block
      signal mem_ahbsi : ahb_slv_in_type;
      signal mem_ahbso : ahb_slv_out_vector := (others => ahbs_none);
      signal mem_ahbmi : ahb_mst_in_type;
      signal mem_ahbmo : ahb_mst_out_vector := (others => ahbm_none);
      signal l2c_stato : std_logic_vector(10 downto 0);
    begin
      nol2caxi : if CFG_L2_AXI = 0 generate
        l2c0 : l2c generic map (
          hslvidx   => 4,
          hmstidx   => 0,
          cen       => CFG_L2_PEN,
          haddr     => 16#400#, hmask => 16#c00#, ioaddr => 16#FF0#,
          cached    => CFG_L2_MAP,
          repl      => CFG_L2_RAN,
          ways      => CFG_L2_WAYS,
          linesize  => CFG_L2_LSZ,
          waysize   => CFG_L2_SIZE,
          memtech   => memtech,
          bbuswidth => AHBDW,
          bioaddr   => 16#FFE#,
          biomask   => 16#fff#,
          sbus      => 0,
          mbus      => 1,
          arch      => CFG_L2_SHARE,
          ft        => CFG_L2_EDAC)
          port map (rst    => rstn,
                    clk    => clkm,
                    ahbsi  => ahbsi,
                    ahbso  => ahbso(4),
                    ahbmi  => mem_ahbmi,
                    ahbmo  => mem_ahbmo(0),
                    ahbsov => mem_ahbso,
                    sto => l2c_stato);

        memahb0 : ahbctrl -- AHB arbiter/multiplexer
          generic map (defmast => CFG_DEFMST, split => CFG_SPLIT,
                       rrobin => CFG_RROBIN, ioaddr => 16#FFE#,
                       ioen => 1, nahbm => 1, nahbs => 1)
          port map (rstn, clkm, mem_ahbmi, mem_ahbmo, mem_ahbsi, mem_ahbso);

        mem_ahbso(0) <= mig_ahbso;
        mig_ahbsi    <= mem_ahbsi;
      end generate;

      l2caxi : if CFG_L2_AXI /= 0 generate
        l2c0 : l2c_axi_be generic map (
          hslvidx  => 5,
          axiid    => 0,
          cen      => CFG_L2_PEN,
          haddr    => 16#400#,
          hmask    => 16#c00#,
          ioaddr   => 16#FF0#,
          cached   => CFG_L2_MAP,
          repl     => CFG_L2_RAN,
          ways     => CFG_L2_WAYS,
          linesize => CFG_L2_LSZ,
          waysize  => CFG_L2_SIZE,
          memtech  => memtech,
          sbus     => 0,
          mbus     => 0,
          arch     => CFG_L2_SHARE,
          ft       => CFG_L2_EDAC,
          stat     => 2)
          port map (rst   => rstn,
                    clk   => clkm,
                    ahbsi => ahbsi,
                    ahbso => ahbso(5),
                    aximi => mem_aximi,
                    aximo => mem_aximo,
                    sto   => l2c_stato);
      end generate;

      perf.event(15 downto 7)   <= (others => '0');
      perf.esource(15 downto 7) <= (others => (others => '0'));
      perf.event(6)  <= l2c_stato(10);  -- Data uncorrectable error
      perf.event(5)  <= l2c_stato(9);   -- Data correctable error
      perf.event(4)  <= l2c_stato(8);   -- Tag uncorrectable error
      perf.event(3)  <= l2c_stato(7);   -- Tag correctable error
      perf.event(2)  <= l2c_stato(2);   -- Bus access
      perf.event(1)  <= l2c_stato(1);   -- Miss
      perf.event(0)  <= l2c_stato(0);   -- Hit
      perf.esource(6 downto 3) <= (others => (others => '0'));
      perf.esource(2 downto 0) <= (others => l2c_stato(6 downto 3));
      perf.req       <= (others => '0');
      perf.sel       <= (others => '0');
      perf.latcnt    <= '0';
      --perf.timer     <= dbgi(0).timer(31 downto 0);
    end block l2cblock;
  end generate l2cen;
  
  nol2c : if CFG_L2_EN = 0 generate
    ahbso(4)  <= mig_ahbso;
    mig_ahbsi <= ahbsi;
    perf      <= l3stat_in_none;
  end generate;


  -----------------------------------------------------------------------------
  -- DDR4 Memory Controller (MIG) ---------------------------------------------
  -----------------------------------------------------------------------------

  mig_gen : if (CFG_MIG_7SERIES = 1) generate
    gen_mig : if (USE_MIG_INTERFACE_MODEL /= true) generate
      gen_ahb2mig : if (CFG_L2_EN = 0 or CFG_L2_AXI = 0) generate
        ddrc : ahb2axi_mig4_7series generic map (
          hindex => 4 * (1 - CFG_L2_EN), haddr => 16#400#, hmask => 16#F00#,
          pindex => 4, paddr => 4
          )
          port map (
            calib_done      => calib_done,
            sys_clk_p       => clk300p,
            sys_clk_n       => clk300n,
            ddr4_addr       => ddr4_addr,
            ddr4_we_n       => ddr4_we_n,
            ddr4_cas_n      => ddr4_cas_n,
            ddr4_ras_n      => ddr4_ras_n,
            ddr4_ba         => ddr4_ba,
            ddr4_cke        => ddr4_cke,
            ddr4_cs_n       => ddr4_cs_n,
            ddr4_dm_n       => ddr4_dm_n,
            ddr4_dq         => ddr4_dq,
            ddr4_dqs_c      => ddr4_dqs_c,
            ddr4_dqs_t      => ddr4_dqs_t,
            ddr4_odt        => ddr4_odt,
            ddr4_bg         => ddr4_bg,
            ddr4_reset_n    => ddr4_reset_n,
            ddr4_act_n      => ddr4_act_n,
            ddr4_ck_c       => ddr4_ck_c,
            ddr4_ck_t       => ddr4_ck_t,
            ddr4_ui_clk     => open,
            ddr4_ui_clk_sync_rst => open,
            rst_n_syn       => migrstn,
            rst_n_async     => rstraw,
            ahbsi           => mig_ahbsi,
            ahbso           => mig_ahbso,
            apbi            => apbi,
            apbo            => apbo(4),
            clk_amba        => clkm,
            -- Misc
            ddr4_ui_clkout1 => clkm,
            clk_ref_i       => clkref
          );
      end generate gen_ahb2mig;


      gen_axi_mig: if (CFG_L2_EN /= 0 and CFG_L2_AXI /= 0) generate
        ddrc:axi_mig4_7series generic map (
          mem_bits  => 30
        )
        port map (
          calib_done      => calib_done,
          sys_clk_p       => clk300p,
          sys_clk_n       => clk300n,
          ddr4_addr       => ddr4_addr,
          ddr4_we_n       => ddr4_we_n,
          ddr4_cas_n      => ddr4_cas_n,
          ddr4_ras_n      => ddr4_ras_n,
          ddr4_ba         => ddr4_ba,
          ddr4_cke        => ddr4_cke,
          ddr4_cs_n       => ddr4_cs_n,
          ddr4_dm_n       => ddr4_dm_n,
          ddr4_dq         => ddr4_dq,
          ddr4_dqs_c      => ddr4_dqs_c,
          ddr4_dqs_t      => ddr4_dqs_t,
          ddr4_odt        => ddr4_odt,
          ddr4_bg         => ddr4_bg,
          ddr4_reset_n    => ddr4_reset_n,
          ddr4_act_n      => ddr4_act_n,
          ddr4_ck_c       => ddr4_ck_c,
          ddr4_ck_t       => ddr4_ck_t,
          ddr4_ui_clk     => open,
          ddr4_ui_clk_sync_rst => open,
          rst_n_syn       => migrstn,
          rst_n_async     => rstraw,
          aximi           => mem_aximi,
          aximo           => mem_aximo,
          -- Misc
          ddr4_ui_clkout1 => clkm,
          clk_ref_i       => clkref
        );

        -----------------------------------------------------------------------
        ---  Fake MIG PNP -----------------------------------------------------
        -----------------------------------------------------------------------      
        ahbso(4).hindex  <= 4;
        ahbso(4).hconfig <= mig_hconfig;
        ahbso(4).hready  <= '1';
        ahbso(4).hresp   <= "00";
        ahbso(4).hirq    <= (others => '0');
        ahbso(4).hrdata  <= (others => '0');
        -- No APB interface on mig
        apbo(4)    <= apb_none;
        
      end generate gen_axi_mig;
    end generate gen_mig;

    gen_mig_model : if (USE_MIG_INTERFACE_MODEL = true) generate
      -- pragma translate_off
      mig_ahbram : ahbram_sim
        generic map (
          hindex        => 4 * (1 - CFG_L2_EN),
          haddr         => 16#400#,
          hmask         => 16#f00#,
          tech          => 0,
          kbytes        => 1024,
          pipe          => 0,
          maccsz        => AHBDW,
          fname         => ramfile
        )
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => mig_ahbsi,
          ahbso   => mig_ahbso
        );

      -- Tie-Off DDR4 Signals
      ddr4_addr       <= (others => '0');
      ddr4_we_n       <= '0';
      ddr4_cas_n      <= '0';
      ddr4_ras_n      <= '0';
      ddr4_ba         <= (others => '0');
      ddr4_cke        <= (others => '0');
      ddr4_cs_n       <= (others => '0');
      ddr4_dm_n       <= (others => 'Z');
      ddr4_dq         <= (others => 'Z');
      ddr4_dqs_c      <= (others => 'Z');
      ddr4_dqs_t      <= (others => 'Z');
      ddr4_odt        <= (others => '0');
      ddr4_bg         <= (others => '0');
      ddr4_reset_n    <= '1';
      ddr4_act_n      <= '1';
      ddr4_ck_c       <= (others => '0');
      ddr4_ck_t       <= (others => '0');

      calib_done <= '1';

      clkm <= not clkm after 5.0 ns;
    -- pragma translate_on
    end generate gen_mig_model;

    lclk                <= '0';

  end generate mig_gen;

  no_mig_gen : if (CFG_MIG_7SERIES = 0) generate

    ahbram1 : ahbram
      generic map (hindex => 4 * (1 - CFG_L2_EN), haddr => 16#400#,
                   tech => CFG_MEMTECH, kbytes => 1024)
      port map (rstn, clkm, mem_ahbsi, mem_ahbso);

    -- Tie-Off DDR4 Signals
    ddr4_addr       <= (others => '0');
    ddr4_we_n       <= '0';
    ddr4_cas_n      <= '0';
    ddr4_ras_n      <= '0';
    ddr4_ba         <= (others => '0');
    ddr4_cke        <= (others => '0');
    ddr4_cs_n       <= (others => '0');
    ddr4_dm_n       <= (others => 'Z');
    ddr4_dq         <= (others => 'Z');
    ddr4_dqs_c      <= (others => 'Z');
    ddr4_dqs_t      <= (others => 'Z');
    ddr4_odt        <= (others => '0');
    ddr4_bg         <= (others => '0');
    ddr4_reset_n    <= '1';
    ddr4_act_n      <= '1';

    ddr4_ck_outpad : outpad_ds
      generic map (tech => padtech, level => sstl12_dci, voltage => x12v, slew => 1)
      port map (ddr4_ck_t(0), ddr4_ck_c(0), gnd, gnd);

    calib_done <= '1';
    
  end generate no_mig_gen;

  -- For designs that have PAR connected from the FPGA to a component, SODIMM, or UDIMM,
  -- the PAR output of the FPGA should be driven low using an SSTL12 driver to ensure it
  -- is held low at the memory.

  -- Tie-Off Unused DDR4 Signals
  ddr4_par      <= gnd;
  ddr4_ten      <= gnd;
  clkref        <= gnd;

  ----------------------------------------------------------------------
  --- ETHERNET ---------------------------------------------------------
  ----------------------------------------------------------------------

  -- Gaisler ethernet MAC
  eth0 : if CFG_GRETH = 1 generate
    e0 : grethm
      generic map (
        hindex => CFG_NCPU + CFG_AHB_UART + CFG_AHB_JTAG,
        pindex => 14, paddr => 16#C00#, pmask => 16#C00#, pirq => 5, memtech => memtech,
        mdcscaler => CPU_FREQ / 1000, rmii => 0, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
        nsync => 2, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF, phyrstadr => 7,
        macaddrh => CFG_ETH_ENM, macaddrl => CFG_ETH_ENL, enable_mdint => 1,
        ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_ETH_IPL,
        giga => CFG_GRETH1G, ramdebug => 0, gmiimode => 1
      )
      port map (rst => rstn, clk => clkm, ahbmi => ahbmi,
                ahbmo => ahbmo(CFG_NCPU + CFG_AHB_UART + CFG_AHB_JTAG),
                apbi => apbi, apbo => apbo(14), ethi => gmiii, etho => gmiio,
                debug_rx => e1_debug_rx, debug_tx => e1_debug_tx, debug_gtx => e1_debug_gtx
      );

    sgmiirst <= not rstraw;

    sgmii0 : sgmii_kcu105
      generic map (
        pindex          => 12,
        paddr           => 16#010#,
        pmask           => 16#ff0#,
        abits           => 8,
        autonegotiation => autonegotiation,
        pirq            => 11,
        debugmem        => 1,
        tech            => fabtech
      )
      port map (
        sgmiii   => sgmiii,
        sgmiio   => sgmiio,
        gmiii    => gmiii,
        gmiio    => gmiio,
        reset    => sgmiirst,
        clkout0o => clkout0o,
        clkout1o => clkout1o,
        clkout2o => clkout2o,
        apb_clk  => clkm,
        apb_rstn => rstn,
        apbi     => apbi,
        apbo     => apbo(12)
      );

    emdio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (emdio, sgmiio.mdio_o, sgmiio.mdio_oe, sgmiii.mdio_i);

    emdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (emdc, sgmiio.mdc);

    eint_pad : inpad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (eint, sgmiii.mdint);

    erst_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (erst, sgmiio.reset);

    sgmiii.clkp <= gtrefclk_p;
    sgmiii.clkn <= gtrefclk_n;
    txp         <= sgmiio.txp;
    txn         <= sgmiio.txn;
    sgmiii.rxp  <= rxp;
    sgmiii.rxn  <= rxn;

  end generate;

  noeth0 : if CFG_GRETH = 0 generate

    tx_outpad : outpad_ds
      generic map (padtech, hstl_i_18, x18v)
      port map (txp, txn, gnd, gnd);

    emdio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (emdio, gnd, gnd, open);

    emdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (emdc, gnd);

    erst_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (erst, gnd);

  end generate;

  ----------------------------------------------------------------------
  --- APB Bridge and various periherals --------------------------------
  ----------------------------------------------------------------------

  -- AHB/APB bridge
  apb0 : apbctrl
    generic map (hindex => 1, haddr => CFG_APBADDR, nslaves => 16, debug => 2)
    port map (rstn, clkm, ahbsi, ahbso(1), apbi, apbo);

  irqctrl : if CFG_IRQ3_ENABLE /= 0 generate
    irqctrl0 : irqmp         -- interrupt controller
    generic map (pindex => 2, paddr => 2, ncpu => CFG_NCPU)
    port map (rstn, clkm, apbi, apbo(2), irqo, irqi);
  end generate;
  irq3 : if CFG_IRQ3_ENABLE = 0 generate
    x : for i in 0 to CFG_NCPU - 1 generate
      irqi(i).irl <= "0000";
    end generate;
    apbo(2) <= apb_none;
  end generate;

  gpt : if CFG_GPT_ENABLE /= 0 generate
    -- Timer Unit
    timer0 : gptimer
      generic map (pindex  => 3, paddr => 3, pirq => CFG_GPT_IRQ,
                   sepirq  => CFG_GPT_SEPIRQ, sbits => CFG_GPT_SW, ntimers => CFG_GPT_NTIM,
                   nbits   => CFG_GPT_TW, wdog => CFG_GPT_WDOGEN*CFG_GPT_WDOG)
      port map (rstn, clkm, apbi, apbo(3), gpti, gpto);
    gpti <= gpti_dhalt_drive('0');
  end generate;

  nogpt : if CFG_GPT_ENABLE = 0 generate
    apbo(3) <= apb_none;
  end generate;

  -- GPIO units
  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate

    pio_pads : for i in 0 to 9 generate
      gpio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x12v, strength => 8)
        port map (gpio(i), gpioo1.dout(i), gpioo1.oen(i), gpioi1.din(i));
    end generate;

    grgpio_hd : grgpio
      generic map (pindex => 11, paddr => 11, imask => CFG_GRGPIO_IMASK, nbits => 8)
      port map (rst   => rstn, clk => clkm, apbi => apbi, apbo => apbo(11),
                gpioi => gpioi1, gpioo => gpioo1);

    -- Tie-off alternative output enable signals
    gpioi1.sig_en       <= (others => '0');
    gpioi1.sig_in       <= (others => '0');

    grgpio_ledsw : grgpio
      generic map (pindex => 10, paddr => 10, imask => CFG_GRGPIO_IMASK, nbits => 8)
      port map (rst   => rstn, clk => clkm, apbi => apbi, apbo => apbo(10),
                gpioi => gpioi, gpioo => gpioo);

    -- Tie-off alternative output enable signals
    gpioi.sig_en        <= (others => '0');
    gpioi.sig_in        <= (others => '0');

    gpled_pads : for i in 2 to 4 generate --0,1 and 5,6,7 are used
      gpled_pad : outpad
        generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (led(i), gpioo.dout(i));
    end generate gpled_pads;

    gpsw_pads : for i in 0 to 2 generate
      gpsw_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (switch(i), gpioi.din(i));
    end generate gpsw_pads;
    gpioi.din(3) <= dsu_sel;

    gppb_pads : for i in 4 to 7 generate
      gppb_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (button(i - 4), gpioi.din(i));
    end generate gppb_pads;

  end generate;

  -- APB UART 1
  ua1 : if CFG_UART1_ENABLE /= 0 generate
    uart1 : apbuart
      generic map (pindex   => 1, paddr => 1, pirq => 2, console => dbguart,
                   fifosize => CFG_UART1_FIFO)
      port map (rstn, clkm, apbi, apbo(1), u1i, u1o);
    u1i.extclk  <= '0';
  end generate;

  noua0 : if CFG_UART1_ENABLE = 0 generate
    apbo(1) <= apb_none;
  end generate;

  -- I2C Master
  i2cm: if CFG_I2C_ENABLE = 1 generate
    i2c0 : i2cmst generic map (pindex => 9, paddr => 9, pmask => 16#FFF#, pirq => 10, filter => 9)
      port map (rstn, clkm, apbi, apbo(9), i2ci, i2co);

    i2c_scl_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (iic_scl, i2co.scl, i2co.scloen, i2ci.scl);

    i2c_sda_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (iic_sda, i2co.sda, i2co.sdaoen, i2ci.sda);

  end generate i2cm;

--
  -----------------------------------------------------------------------
  ---  SpaceWire --------------------------------------------------------
  -----------------------------------------------------------------------

  -- SpaceWire is provided via the STAR-Dundee FMC board
  -- Mapping is accordingly to the following table
  --
  -- SpaceWire FMC Port Pins | FMC HPC Pin | FPGA Pin | SpaceWire Signal
  -- --------------------------------------------------------------------------------
  --        SpW_A1_P         |     D8      |    G9    |   spw_din_p(1)
  --        SpW_A1_N         |     D9      |    F9    |   spw_din_n(1)
  --        SpW_A2_P         |     C22     |    E22   |   spw_sin_p(1)
  --        SpW_A2_N         |     C23     |    E23   |   spw_sin_n(1)
  --        SpW_A3_P         |     G6      |    H11   |   spw_din_p(2)
  --        SpW_A3_N         |     G7      |    G11   |   spw_din_n(2)
  --        SpW_A4_P         |     D20     |    D24   |   spw_sin_p(2)
  --        SpW_A4_N         |     D21     |    C24   |   spw_sin_n(2)

  --        SpW1_Dout_P      |     D14     |    J9    |   spw_dout_p(1)
  --        SpW1_Dout_N      |     D15     |    H9    |   spw_dout_n(1)
  --        SpW1_Sout_P      |     C18     |    B10   |   spw_sout_p(1)
  --        SpW1_Sout_N      |     C19     |    A10   |   spw_sout_n(1)
  --        SpW2_Dout_P      |     C14     |    L8    |   spw_dout_p(2)
  --        SpW2_Dout_N      |     C15     |    K8    |   spw_dout_n(2)
  --        SpW2_Sout_P      |     D17     |    D9    |   spw_sout_p(2)
  --        SpW2_Sout_N      |     D18     |    C9    |   spw_sout_n(2)

  -- rxclkin and nrxclki are unused
  spw_rxclkin           <= '0';

  -- SpaceWire Transmitter clock should be clocked at 100 MHz
  spw_txclk             <= clkm;

  no_spw : if CFG_SPW_EN = 0 generate

    spwloop : for i in 0 to CFG_SPW_NUM - 1 generate

      spwports : for j in 1 to CFG_SPW_PORTS generate

        spwr_txd_pad : outpad_ds generic map (padtech, lvds, x33v)
          port map (spw_dout_p(i * CFG_SPW_PORTS + j),
                    spw_dout_n(i * CFG_SPW_PORTS + j),
                    gnd, gnd);

        spwr_txs_pad : outpad_ds generic map (padtech, lvds, x33v)
          port map (spw_sout_p(i * CFG_SPW_PORTS + j),
                    spw_sout_n(i * CFG_SPW_PORTS + j),
                    gnd, gnd);

        end generate spwports;

      end generate spwloop;

  end generate;

  spw : if CFG_SPW_EN /= 0 generate

    spwloop : for i in 0 to CFG_SPW_NUM - 1 generate

      -- For self-clock implementations we reuse the strobe input, otherwise we
      -- sample with the txclk
      spw_rxclkiv(i) <= stmp(i) when (CFG_SPW_INPUT < 2 or CFG_SPW_INPUT > 4) else spw_txclk;

      -- GRSPW2 PHY
      spw2_input : if CFG_SPW_GRSPW = 2 generate

        spw_phy0 : grspw2_phy
          generic map (
            scantest     => 0,
            tech         => fabtech,
            input_type   => CFG_SPW_INPUT,
            rxclkbuftype => 1
          )
          port map (
            rstn      => rstn,
            rxclki    => spw_rxclkiv(i),                -- Receiver Clock Input
            rxclkin   => spw_rxclkin,
            nrxclki   => spw_rxclkin,
            di        => dtmp(i),       -- SpaceWire Data Input (from Pads)
            si        => stmp(i),       -- SpaceWire Strobe Input (from Pads)
            do        => spwi(i).d(1 downto 0),         -- Recovered Data
            dov       => spwi(i).dv(1 downto 0),        -- Data Valid
            dconnect  => spwi(i).dconnect(1 downto 0),  -- Disconnect
            dconnect2 => spwi(i).dconnect2(1 downto 0),
            dconnect3 => spwi(i).dconnect3(1 downto 0),
            rxclko    => spw_rxclk0(i)  -- Receiver Clock Output
            );

        spwi(i).nd <= (others => '0');  -- Only used in GRSPW

      end generate spw2_input;

      -- Single Port PHY
      singleportphy : if CFG_SPW_PORTS = 1 generate

        spwi(i).d(3 downto 2)           <= "00";  -- For second port
        spwi(i).dv(3 downto 2)          <= "00";  -- For second port
        spwi(i).dconnect(3 downto 2)    <= "00";  -- For second port
        spwi(i).dconnect2(3 downto 2)   <= "00";  -- For second port
        spwi(i).dconnect3(3 downto 2)   <= "00";  -- For second port
        spwi(i).s(1 downto 0)           <= "00";  -- Only used in PHY

      end generate singleportphy;

      -- Dual Port PHY
      dualportphy : if CFG_SPW_PORTS = 2 generate

        spw_rxclkiv(i*2+1) <= stmp(i*2+1) when (CFG_SPW_INPUT < 2 or CFG_SPW_INPUT > 4) else spw_txclk;

        spw_phy1 : grspw2_phy
          generic map (
            scantest     => 0,
            tech         => fabtech,
            input_type   => CFG_SPW_INPUT,
            rxclkbuftype => 1)
          port map (
            rstn      => rstn,
            rxclki    => spw_rxclkiv(i * 2 + 1),
            rxclkin   => spw_rxclkin,
            nrxclki   => spw_rxclkin,
            di        => dtmp(i * 2 + 1),
            si        => stmp(i * 2 + 1),
            do        => spwi(i).d(3 downto 2),
            dov       => spwi(i).dv(3 downto 2),
            dconnect  => spwi(i).dconnect(3 downto 2),
            dconnect2 => spwi(i).dconnect2(3 downto 2),
            dconnect3 => spwi(i).dconnect3(3 downto 2),
            rxclko    => spw_rxclk1(i)
            );

      end generate dualportphy;

      -- GRSPW Codec
      sw0 : grspwm
        generic map (
          tech           => fabtech,
          hindex         => CFG_NCPU + CFG_AHB_UART + CFG_AHB_JTAG + CFG_GRETH + i,
          pindex         => 5 + i,
          paddr          => 5 + i,
          pirq           => 5 + i,
          sysfreq        => CPU_FREQ,
          nsync          => 1,
          rmap           => CFG_SPW_RMAP,
          rmapcrc        => CFG_SPW_RMAPCRC,
          fifosize1      => CFG_SPW_AHBFIFO,
          fifosize2      => CFG_SPW_RXFIFO,
          rxclkbuftype   => 1,
          memtech        => memtech,
          rmapbufs       => CFG_SPW_RMAPBUF,
          ft             => CFG_SPW_FT,
          ports          => CFG_SPW_PORTS,
          dmachan        => CFG_SPW_DMACHAN,
          netlist        => CFG_SPW_NETLIST,
          spwcore        => CFG_SPW_GRSPW,
          input_type     => CFG_SPW_INPUT,
          output_type    => CFG_SPW_OUTPUT,
          rxtx_sameclk   => CFG_SPW_RTSAME,
          rxunaligned    => CFG_SPW_RXUNAL,
          internalrstgen => 1)
        port map (
          rst        => rstn,
          clk        => clkm,
          rxasyncrst => gnd,
          rxsyncrst0 => gnd,
          rxclk0     => spw_rxclk0(i),  -- Receiver Clock for Port 0
          rxsyncrst1 => gnd,
          rxclk1     => spw_rxclk1(i),  -- Receiver Clock for Port 1
          txsyncrst  => gnd,
          txclk      => spw_txclk,      -- Transmitter default run-state clock
          txclkn     => spw_txclk,  -- Transmitter inverted default run-state clock
          ahbmi      => ahbmi,
          ahbmo      => ahbmo(CFG_NCPU + CFG_AHB_UART + CFG_AHB_JTAG + CFG_GRETH + i),
          apbi       => apbi,
          apbo       => apbo(5+i),
          swni       => spwi(i),        -- SpaceWire Input
          swno       => spwo(i)         -- SpaceWire Output
          );

      spwi(i).tickin       <= '0';
      spwi(i).rmapen       <= '0';
      spwi(i).clkdiv10     <= conv_std_logic_vector(CPU_FREQ / 10000 - 1, 8);
      spwi(i).dcrstval     <= (others => '0');
      spwi(i).timerrstval  <= (others => '0');
      spwi(i).pnpusn       <= (others => '0');
      spwi(i).pnpuprodid   <= (others => '0');
      spwi(i).pnpuvendid   <= (others => '0');
      spwi(i).pnpen        <= '0';
      spwi(i).irqtxdefault <= (others => '0');
      spwi(i).intcreload   <= (others => '0');
      spwi(i).intiareload  <= (others => '0');
      spwi(i).intpreload   <= (others => '0');
      spwi(i).rmapnodeaddr <= (others => '0');
      spwi(i).timein       <= (others => '0');
      spwi(i).tickinraw    <= '0';

      -- SpaceWire Pads

      spw_txd_pad : outpad_ds generic map (padtech, lvds, x33v)
        port map (spw_dout_p(i * CFG_SPW_PORTS + 1),
                  spw_dout_n(i * CFG_SPW_PORTS + 1),
                  spwo(i).d(0), gnd);

      spw_txs_pad : outpad_ds generic map (padtech, lvds, x33v)
        port map (spw_sout_p(i * CFG_SPW_PORTS + 1),
                  spw_sout_n(i * CFG_SPW_PORTS + 1),
                  spwo(i).s(0), gnd);

      spwr_rxd_pad : IBUFDS generic map (DQS_BIAS => "FALSE", IOSTANDARD => "LVDS")
        port map (
          o  => dtmp(i*CFG_SPW_PORTS),
          i  => spw_din_p(i*CFG_SPW_PORTS+1),
          ib => spw_din_n(i*CFG_SPW_PORTS+1)
          );

      spwr_rxs_pad : IBUFDS generic map (DQS_BIAS => "FALSE", IOSTANDARD => "LVDS")
        port map (
          o  => stmp(i*CFG_SPW_PORTS),
          i  => spw_sin_p(i*CFG_SPW_PORTS+1),
          ib => spw_sin_n(i*CFG_SPW_PORTS+1)
          );

      dualport : if CFG_SPW_PORTS = 2 generate

        spwr_txd_pad : outpad_ds generic map (padtech, lvds, x33v)
          port map (spw_dout_p(i * CFG_SPW_PORTS + 2),
                    spw_dout_n(i * CFG_SPW_PORTS + 2),
                    spwo(i).d(1), gnd);

        spwr_txs_pad : outpad_ds generic map (padtech, lvds, x33v)
          port map (spw_sout_p(i * CFG_SPW_PORTS + 2),
                    spw_sout_n(i * CFG_SPW_PORTS + 2),
                    spwo(i).s(1), gnd);

        spwr_rxd_pad : IBUFDS generic map (DQS_BIAS => "FALSE", IOSTANDARD => "LVDS")
          port map (
            o  => dtmp(i * CFG_SPW_PORTS + 1),
            i  => spw_din_p(i * CFG_SPW_PORTS + 2),
            ib => spw_din_n(i * CFG_SPW_PORTS + 2)
            );

        spwr_rxs_pad : IBUFDS generic map (DQS_BIAS => "FALSE", IOSTANDARD => "LVDS")
          port map (
            o  => stmp(i * CFG_SPW_PORTS + 1),
            i  => spw_sin_p(i * CFG_SPW_PORTS + 2),
            ib => spw_sin_n(i * CFG_SPW_PORTS + 2)
            );

      end generate dualport;

    end generate spwloop;

  end generate spw;

  -----------------------------------------------------------------------
  ---  AHB Status Register ----------------------------------------------
  -----------------------------------------------------------------------

  ahbs : if CFG_AHBSTAT = 1 generate
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat
      generic map (pindex => 15, paddr => 15, pirq => 7,
                   nftslv => CFG_AHBSTATN)
      port map(rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(15));
  end generate;

  -----------------------------------------------------------------------
  ---  AHB RAM ----------------------------------------------------------
  -----------------------------------------------------------------------

  ocram : if CFG_AHBRAMEN = 1 generate
    ahbram0 : ahbram
      generic map (hindex => 6, haddr => CFG_AHBRADDR, tech => CFG_MEMTECH,
                   kbytes => CFG_AHBRSZ, pipe => CFG_AHBRPIPE)
      port map (rstn, clkm, ahbsi, ahbso(6));
  end generate;


-----------------------------------------------------------------------
---  AHB ROM ----------------------------------------------------------
-----------------------------------------------------------------------

  bpromgen : if CFG_AHBROMEN /= 0 generate
    brom : entity work.ahbrom
      generic map (hindex => 7, haddr => CFG_AHBRODDR, pipe => CFG_AHBROPIP)
      port map (rstn, clkm, ahbsi, ahbso(7));
  end generate;


-----------------------------------------------------------------------
---  DYNAMIC PARTIAL RECONFIGURATION  ---------------------------------
-----------------------------------------------------------------------
  prc : if CFG_PRC = 1 generate
    p1 : dprc generic map (hindex => CFG_NCPU + CFG_AHB_UART + CFG_AHB_JTAG + CFG_GRETH,
                           pindex => 5, paddr => 5, cfg_clkmul => 4, cfg_clkdiv => 8,
                           raw_freq => BOARD_FREQ, clk_sel => 0, edac_en => CFG_EDAC_EN,
                           pirq => 6, technology => CFG_FABTECH, crc_en => CFG_CRC_EN,
                           words_block => CFG_WORDS_BLOCK, fifo_dcm_inst => CFG_DCM_FIFO, fifo_depth => CFG_DPR_FIFO)
       port map (rstn => rstn, clkm => clkm, clkraw => clkm, clk100 => '0',
                 ahbmi => ahbmi, ahbmo => ahbmo(CFG_NCPU + CFG_AHB_UART + CFG_AHB_JTAG + CFG_GRETH),
                 apbi => apbi, apbo => apbo(5), rm_reset => open);
  end generate;


  -----------------------------------------------------------------------
  ---  Test report module  ----------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  test0 : ahbrep
    generic map (hindex => 3, haddr => 16#200#)
    port map (rstn, clkm, ahbsi, ahbso(3));
  -- pragma translate_on

  -----------------------------------------------------------------------
  ---  Boot message  ----------------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  x : report_design
    generic map (
      msg1    => "LEON3/GRLIB Xilinx KCU105 Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
    );
-- pragma translate_on
 end;
