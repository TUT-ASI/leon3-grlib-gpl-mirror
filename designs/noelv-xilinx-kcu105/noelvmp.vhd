------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-- NOELV KCU105 Demonstration Design
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib, techmap;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
use grlib.config.all;
use grlib.config_types.all;
use techmap.gencomp.all;
use techmap.allclkgen.all;

library gaisler;
use gaisler.noelv.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.spi.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.i2c.all;
use gaisler.subsys.all;
use gaisler.axi.all;
use gaisler.plic.all;
use gaisler.riscv.all;
use gaisler.l2cache.all;
use gaisler.noelv.all;
-- pragma translate_off
use gaisler.sim.all;

library unisim;
use unisim.all;
-- pragma translate_on

use work.config.all;

entity noelvmp is
  generic(
    fabtech             : integer := CFG_FABTECH;
    memtech             : integer := CFG_MEMTECH;
    padtech             : integer := CFG_PADTECH;
    clktech             : integer := CFG_CLKTECH;
    disas               : integer := CFG_DISAS;
    migmodel            : boolean := false;
    autonegotiation     : integer := 1
    ); 
  port(
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

architecture rtl of noelvmp is

  component axi_mig4_7series 
    generic(
      mem_bits  : integer := 30
    );
    port(
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
    generic(
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
  
  -----------------------------------------------------
  -- Constants ----------------------------------------
  -----------------------------------------------------

  constant maxahbm      : integer := 16;
  constant maxahbs      : integer := 16;

  constant OEPOL        : integer := padoen_polarity(padtech);

  constant BOARD_FREQ   : integer := 300000; -- input frequency in KHz
  constant CPU_FREQ     : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV; -- cpu frequency in KHz

  constant USE_MIG_INTERFACE_MODEL      : boolean := migmodel;

  constant ramfile      : string := "ram.srec"; -- ram contents
  
  -----------------------------------------------------
  -- Signals ------------------------------------------
  -----------------------------------------------------

  -- Misc
  signal vcc            : std_ulogic;
  signal gnd            : std_ulogic;
  signal stati          : ahbstat_in_type;
  signal dsu_sel        : std_ulogic;

  -- Memory
  signal mem_aximi      : axi_somi_type;
  signal mem_aximo      : axi_mosi_type;
  signal axi3_aximo     : axi3_mosi_type;
  
  signal migrstn        : std_ulogic;
  signal calib_done     : std_ulogic;

  -- Memory AHB Signals
  signal mem_ahbmi      : ahb_mst_in_type;
  signal mem_ahbmo      : ahb_mst_out_type;
  signal mem_ahbsi      : ahb_slv_in_type;
  signal mem_ahbso      : ahb_slv_out_type;
  
  -- APB
  signal apbi           : apb_slv_in_vector;
  signal apbo           : apb_slv_out_vector := (others => apb_none);

  -- AHB
  signal ahbsi          : ahb_slv_in_type;
  signal ahbso          : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi          : ahb_mst_in_type;
  signal ahbmo          : ahb_mst_out_vector := (others => ahbm_none);

  -- NOELV
  signal ext_irqi       : std_logic_vector(15 downto 0);
  signal cpurstn        : std_ulogic;

  -- Clocks and Reset
  signal clkm           : std_ulogic := '0';
  signal rstn           : std_ulogic;
  signal rstraw         : std_ulogic;
  signal clk_300        : std_ulogic;
  signal cgi            : clkgen_in_type;
  signal cgo            : clkgen_out_type;

  signal clklock        : std_ulogic;
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

  -- Timers
  signal gpti           : gptimer_in_type;
  signal gpto           : gptimer_out_type;

  -- GPIOs
  signal gpioi          : gpio_in_type;
  signal gpioo          : gpio_out_type;

  -- JTAG
  signal tck            : std_ulogic;
  signal tckn           : std_ulogic;
  signal tms            : std_ulogic;
  signal tdi            : std_ulogic;
  signal tdo            : std_ulogic;

  -- SPI
  signal spii           : spi_in_type;
  signal spio           : spi_out_type;
  signal slvsel         : std_logic_vector(CFG_SPICTRL_SLVS-1 downto 0);

  -- Irq Bus
  signal irqi           : nv_irq_in_vector(0 to CFG_NCPU-1);
  signal eip            : std_logic_vector(CFG_NCPU*4-1 downto 0);

  -- Debug Bus
  signal dbgi           : nv_debug_in_vector(0 to CFG_NCPU-1);
  signal dbgo           : nv_debug_out_vector(0 to CFG_NCPU-1);
  signal dsui           : nv_dm_in_type;
  signal dsuo           : nv_dm_out_type;

  -- Real Time Clock
  signal rtc            : std_ulogic := '0';

  -- FPU Unit
  signal fpi            : fpu5_in_vector_type;
  signal fpo            : fpu5_out_vector_type;

  -- Trace buffer
  signal trace_ahbsiv     : ahb_slv_in_vector_type(0 to 1);
  signal trace_ahbmiv     : ahb_mst_in_vector_type(0 to 1);

  constant ncpu     : integer := CFG_NCPU;
  constant nextslv  : integer := 3
-- pragma translate_off
  + 1
-- pragma translate_on
  ;
  constant ndbgmst  : integer := 3
  ;
  signal ldsuen     : std_logic;
  signal ldsubreak  : std_logic;
  signal lcpu0errn  : std_logic;
  signal dbgmi      : ahb_mst_in_vector_type(ndbgmst-1 downto 0);
  signal dbgmo      : ahb_mst_out_vector_type(ndbgmst-1 downto 0);

  --constant mig_pconfig : apb_config_type := (
  --  0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
  --  1 => apb_iobar(paddr, pmask));

  constant mig_hindex : integer := 2
-- pragma translate_off
  + 1
-- pragma translate_on
  ;


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

  rst2 : rstgen         -- reset generator (Debug Module)
    generic map (acthigh => 1)
    port map (dsuo.ndmreset, clkm, vcc, cpurstn, open);

  ----------------------------------------------------------------------
  ---  NOEL-V SUBSYSTEM ------------------------------------------------
  ----------------------------------------------------------------------

  noelv0 : noelvsys 
    generic map (
      fabtech   => fabtech,
      memtech   => memtech,
      ncpu      => ncpu,
      nextmst   => 1,--2,
      nextslv   => nextslv,
      nextapb   => 5,
      ndbgmst   => ndbgmst,
      cached    => 0,
      wbmask    => 16#40FF#,
      busw      => 128,
      cmemconf  => 0,
      fpuconf   => 0,
      disas     => disas,
      ahbtrace  => 0,
      cfg       => CFG_CFG,
      devid     => NOELV_XILINX_KCU105,
      version   => 3,
      revision  => 0,
      nodbus    => CFG_NODBUS
      )
    port map(
      clk       => clkm,
      rstn      => rstn,
      -- AHB bus interface for other masters (DMA units)
      ahbmi     => ahbmi,                     -- : out ahb_mst_in_type;
      ahbmo     => ahbmo(ncpu downto ncpu),   -- : in  ahb_mst_out_vector_type(ncpu+nextmst-1 downto ncpu);
      -- AHB bus interface for slaves (memory controllers, etc)
      ahbsi     => ahbsi,                     -- : out ahb_slv_in_type;
      ahbso     => ahbso(nextslv-1 downto 0), -- : in  ahb_slv_out_vector_type(nextslv-1 downto 0);
      -- AHB master interface for debug links
      dbgmi     => dbgmi,                     -- : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
      dbgmo     => dbgmo,                     -- : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
      -- APB interface for external APB slaves
      apbi      => apbi,                      -- : out apb_slv_in_type;
      apbo      => apbo,                      -- : in  apb_slv_out_vector;
      -- Bootstrap signals
      dsuen     => ldsuen,
      dsubreak  => ldsubreak,
      cpu0errn  => lcpu0errn,
      -- UART connection
      uarti     => u1i,
      uarto     => u1o
      );

  --errorn_pad : odpad
  --  generic map (tech => padtech, oepol => OEPOL)
  --  port map (errorn, lcpu0errn);

  --dsuen_pad : inpad
  --  generic map (tech => padtech, level => cmos, voltage => x12v)
  --  port map (switch(2), ldsuen);
  ldsuen <= '1';

  -- Button 2,3,4 are still to be assigned
  dsubre_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (button(4), ldsubreak);

  --ndreset_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(4), dsuo.ndmreset);

  --dmactive_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(5), dsuo.dmactive);

  -----------------------------------------------------------------------------
  -- Debug UART ---------------------------------------------------------------
  -----------------------------------------------------------------------------
  
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map(
        hindex => 0,
        pindex => 1,
        paddr => 14)
      port map(
        rstn,
        clkm,
        dui,
        duo,
        apbi(1),
        apbo(1),
        dbgmi(0),
        dbgmo(0));
    dui.extclk <= '0';
  end generate;

  nouah : if CFG_AHB_UART = 0 generate
    apbo(1)    <= apb_none;
    duo.txd    <= '0';
    duo.rtsn   <= '0';
    dui.extclk <= '0';
  end generate;

  sw4_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x12v)
    port map (switch(3), dsu_sel);

  dsutx_int     <= duo.txd when dsu_sel = '1' else u1o.txd;
  dui.rxd       <= dsurx_int when dsu_sel = '1' else '1';
  dsurtsn_int   <= duo.rtsn when dsu_sel = '1' else u1o.rtsn;  
  dui.ctsn      <= dsuctsn_int when dsu_sel = '1' else '1';
  u1i.rxd       <= dsurx_int when dsu_sel = '0' else '1';
  u1i.ctsn      <= dsuctsn_int when dsu_sel = '0' else '1';
  
  dsurx_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsurx, dsurx_int);
  dsutx_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsutx, dsutx_int);
  dsuctsn_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsuctsn, dsuctsn_int);
  dsurtsn_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsurtsn, dsurtsn_int);

  dsusel_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(4), dsu_sel);

  -----------------------------------------------------------------------------
  -- JTAG debug link ----------------------------------------------------------
  -----------------------------------------------------------------------------
  
  ahbjtaggen0 : if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag
      generic map(tech => fabtech, hindex => 1)
      port map(rstn, clkm, tck, tms, tdi, tdo, dbgmi(1), dbgmo(1),
               open, open, open, open, open, open, open, gnd);
  end generate;


  -----------------------------------------------------------------------------
  -- DDR4 Memory Controller (MIG) ---------------------------------------------
  -----------------------------------------------------------------------------
  -- No APB interface on memory controller  
  apbo(0)    <= apb_none;

  mig_gen : if (CFG_MIG_7SERIES = 1) generate

    gen_ddr4c : if (USE_MIG_INTERFACE_MODEL = false) generate
      gen_l2c : if CFG_L2_EN /= 0 generate
        l2c0 : l2c_axi_be
          generic map (
            hslvidx   => 0,
            axiid     => 0,
            cen       => CFG_L2_PEN,
            haddr     => 16#400#,
            hmask     => 16#c00#,
            ioaddr    => 16#FF0#,
            cached    => CFG_L2_MAP,
            repl      => CFG_L2_RAN,
            ways      => CFG_L2_WAYS, 
            linesize  => CFG_L2_LSZ,
            waysize   => CFG_L2_SIZE,
            memtech   => memtech,
            sbus      => 0,
            mbus      => 0,
            arch      => CFG_L2_SHARE,
            ft        => CFG_L2_EDAC,
            stat      => 2)
          port map(
            rst   => rstn,
            clk   => clkm,
            ahbsi => ahbsi,
            ahbso => ahbso(0),
            aximi => mem_aximi,
            aximo => mem_aximo,
            sto   => open);
      end generate;
      nogen_l2c : if CFG_L2_EN = 0 generate
        bridge: ahb2axi3b
          generic map (
            hindex          => 0,
            aximid          => 0,
            wbuffer_num     => 8,
            rprefetch_num   => 8,
            endianness_mode => 0,
            narrow_acc_mode => 0,
            vendor          => VENDOR_GAISLER,
            device          => GAISLER_MIG_7SERIES,
            bar0            => ahb2ahb_membar(16#400#, '1', '1', 16#c00#)
            )
          port map (
            rstn  => rstn,
            clk   => clkm,
            ahbsi => ahbsi,
            ahbso => ahbso(0),
            aximi => mem_aximi,
            aximo => axi3_aximo);
            
            mem_aximo.aw.id     <= axi3_aximo.aw.id;
            mem_aximo.aw.addr   <= axi3_aximo.aw.addr;
            mem_aximo.aw.len    <= axi3_aximo.aw.len;
            mem_aximo.aw.size   <= axi3_aximo.aw.size;
            mem_aximo.aw.burst  <= axi3_aximo.aw.burst;
            mem_aximo.aw.lock   <= axi3_aximo.aw.lock;
            mem_aximo.aw.cache  <= axi3_aximo.aw.cache;
            mem_aximo.aw.prot   <= axi3_aximo.aw.prot;
            mem_aximo.aw.valid  <= axi3_aximo.aw.valid;
            mem_aximo.w         <= axi3_aximo.w;
            mem_aximo.b         <= axi3_aximo.b;
            mem_aximo.ar.id     <= axi3_aximo.ar.id;
            mem_aximo.ar.addr   <= axi3_aximo.ar.addr;
            mem_aximo.ar.len    <= axi3_aximo.ar.len;
            mem_aximo.ar.size   <= axi3_aximo.ar.size;
            mem_aximo.ar.burst  <= axi3_aximo.ar.burst;
            mem_aximo.ar.lock   <= axi3_aximo.ar.lock;
            mem_aximo.ar.cache  <= axi3_aximo.ar.cache;
            mem_aximo.ar.prot   <= axi3_aximo.ar.prot;
            mem_aximo.ar.valid  <= axi3_aximo.ar.valid;
            mem_aximo.r         <= axi3_aximo.r;
      end generate;

      ddr4c: axi_mig4_7series generic map (
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
    end generate gen_ddr4c;

    gen_mig_model : if (USE_MIG_INTERFACE_MODEL = true) generate
      -- pragma translate_off
      mig_ahbram : ahbram_sim
        generic map (
          hindex   => 0,
          haddr    => 16#400#,
          hmask    => 16#C00#,
          tech     => 0,
          kbytes   => 1000,
          pipe     => 0,
          maccsz   => AHBDW,
          endianness  => GRLIB_CONFIG_ARRAY(grlib_little_endian),
          fname    => ramfile
          )
        port map(
          rst     => rstn,
          clk     => clkm,
          ahbsi   => ahbsi,
          ahbso   => ahbso(0)
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
    
  end generate mig_gen;

  no_mig_gen : if (CFG_MIG_7SERIES = 0) generate  

    ahbram1 : ahbram 
      generic map (
        hindex      => 0,
        haddr       => 16#400#,
        tech        => CFG_MEMTECH,
        kbytes      => 1024,
        endianness  => GRLIB_CONFIG_ARRAY(grlib_little_endian))
      port map (
        rstn,
        clkm,
        ahbsi,
        ahbso(0));

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
      generic map (tech => padtech, level => sstl12_dci, voltage => x12v)
      port map (ddr4_ck_t(0), ddr4_ck_c(0), gnd, gnd);

    calib_done <= '1';

  end generate no_mig_gen;

  led6_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(6), calib_done);
  led7_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(7), lock);

  -- For designs that have PAR connected from the FPGA to a component, SODIMM, or UDIMM,
  -- the PAR output of the FPGA should be driven low using an SSTL12 driver to ensure it
  -- is held low at the memory.

  ddr4_ten      <= gnd;
  ddr4_par      <= gnd;
  clkref        <= gnd;

  -----------------------------------------------------------------------
  ---  AHB ROM ----------------------------------------------------------
  -----------------------------------------------------------------------

  brom : entity work.ahbrom
    generic map (
      hindex  => 1,
      haddr   => 16#000#,
      pipe    => 0)
    port map (
      rst     => rstn,
      clk     => clkm,
      ahbsi   => ahbsi,
      ahbso   => ahbso(1));

  ----------------------------------------------------------------------
  --- APB Bridge and various periherals --------------------------------
  ----------------------------------------------------------------------

  --  AHB Status Register
  ahbs : if CFG_AHBSTAT = 1 generate  
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat
      generic map(pindex  => 2,
                  paddr   => 15,
                  pirq    => 4,
                  nftslv  => CFG_AHBSTATN)
      port map(
        rstn,
        clkm,
        ahbmi,
        ahbsi,
        stati,
        apbi(2),
        apbo(2));
  end generate;

  -- GPIO units
  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate

    grgpio_ledsw : grgpio
      generic map(
        pindex => 3,
        paddr => 4,
        imask => CFG_GRGPIO_IMASK,
        nbits => CFG_GRGPIO_WIDTH)
      port map(
        rst   => rstn,
        clk   => clkm,
        apbi  => apbi(3),
        apbo  => apbo(3),
        gpioi => gpioi,
        gpioo => gpioo);

    -- Tie-off alternative output enable signals
    gpioi.sig_en        <= (others => '0');
    gpioi.sig_in        <= (others => '0');

    gpled_pads : for i in 0 to 3 generate
      gpled_pad : outpad
        generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (led(i), gpioo.dout(i+16));
    end generate gpled_pads;

    gpsw_pads : for i in 0 to 2 generate
      gpsw_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (switch(i), gpioi.din(i));
    end generate gpsw_pads;
    gpioi.din(3) <= dsu_sel;

    gpb_pads : for i in 0 to 3 generate
      gpsw_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (button(i), gpioi.din(i+4));
    end generate gpb_pads;

    pio_pads : for i in 0 to 7 generate
      gpio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x12v, strength => 8)
        port map (gpio(i), gpioo.dout(i+8), gpioo.oen(i+8), gpioi.din(i+8));
    end generate;

  end generate;

  ---- I2C Master
  --i2cm: if CFG_I2C_ENABLE = 1 generate 
  --  i2c0 : i2cmst 
  --    generic map (
  --      pindex  => 6,
  --      paddr   => 7,
  --      pmask   => 16#FFF#,
  --      pirq    => 10,
  --      filter  => 9)
  --    port map (
  --      rstn,
  --      clkm,
  --      apbi(6),
  --      apbo(6),
  --      i2ci,
  --      i2co);

  --  i2c_scl_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
  --    port map (iic_scl, i2co.scl, i2co.scloen, i2ci.scl);

  --  i2c_sda_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
  --    port map (iic_sda, i2co.sda, i2co.sdaoen, i2ci.sda);
  --  
  --end generate i2cm;

  ----------------------------------------------------------------------
  --- ETHERNET ---------------------------------------------------------
  ----------------------------------------------------------------------

  eth0 : if CFG_GRETH = 1 generate
    e0 : grethm_mb
      generic map (
        hindex => ncpu, ehindex => 2,
        pindex => 4, paddr => 5, pmask => 16#FFF#, pirq => 5, memtech => memtech,
        mdcscaler => CPU_FREQ / 1000, rmii => 0, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
        nsync => 2, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF, phyrstadr => 7,
        macaddrh => CFG_ETH_ENM, macaddrl => CFG_ETH_ENL, enable_mdint => 1,
        ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_ETH_IPL,
        giga => CFG_GRETH1G, ramdebug => 0, gmiimode => 1, edclsepahb => 1
      )
      port map (rst => rstn, clk => clkm, 
                ahbmi => ahbmi, ahbmo => ahbmo(ncpu),
                ahbmi2 => dbgmi(2), ahbmo2 => dbgmo(2),
                apbi => apbi(4), apbo => apbo(4), ethi => gmiii, etho => gmiio--,
                --debug_rx => e1_debug_rx, debug_tx => e1_debug_tx, debug_gtx => e1_debug_gtx
      );

    sgmiirst <= not rstraw;

    sgmii0 : sgmii_kcu105
      generic map (
        pindex          => 7,
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
        apbi     => apbi(7),
        apbo     => open --apbo(5)
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

  -----------------------------------------------------------------------
  ---  Fake MIG PNP -----------------------------------------------------
  -----------------------------------------------------------------------

  fake_mig_gen : if CFG_L2_EN /= 0 generate
    ahbso(mig_hindex).hindex  <= mig_hindex;
    ahbso(mig_hindex).hconfig <= mig_hconfig;
    ahbso(mig_hindex).hready  <= '1';
    ahbso(mig_hindex).hresp   <= "00";
    ahbso(mig_hindex).hirq    <= (others => '0');
    ahbso(mig_hindex).hrdata  <= (others => '0');
  end generate;
  no_fake_mig_gen : if CFG_L2_EN = 0 generate
    ahbso(mig_hindex) <= ahbs_none;
  end generate;

  -----------------------------------------------------------------------
  ---  Test report module  ----------------------------------------------
  -----------------------------------------------------------------------

-- pragma translate_off
  test0 : ahbrep
    generic map(
      hindex => 2,
      haddr => 16#200#)
    port map(
      rstn,
      clkm,
      ahbsi,
      ahbso(2));
-- pragma translate_on

  -----------------------------------------------------------------------
  ---  Boot message  ----------------------------------------------------
  -----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
    generic map(
      msg1    => "NOELV/GRLIB KCU105 Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
      );
-- pragma translate_on
end;

