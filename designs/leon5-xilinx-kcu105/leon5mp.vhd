-----------------------------------------------------------------------------
--LEON5 Xilinx KCU105 Demonstration design
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
use gaisler.leon3.all;
use gaisler.leon5.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.i2c.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.l2cache.all;
use gaisler.subsys.all;
use gaisler.axi.all;

-- pragma translate_off
use gaisler.sim.all;
library unisim;
use unisim.all;
-- pragma translate_on


use work.config.all;

entity leon5mp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;   -- Enable disassembly to console
    ahbtrace                : integer := CFG_AHBTRACE;
    simulation              : boolean := false;
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


architecture rtl of leon5mp is

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
    generic (
      pindex          : integer := 0;
      paddr           : integer := 0;
      pmask           : integer := 16#fff#;
      abits           : integer := 8;
      autonegotiation : integer := 1;
      pirq            : integer := 0;
      edclsepahb      : integer := 0;
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
  constant ramfile      : string := "ram.srec"; -- ram contents

  constant MEMAHB_IOADDR : integer := 16#FFE#;

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
  signal mem_ahbsi : ahb_slv_in_type;
  signal mem_ahbso : ahb_slv_out_vector := (others => ahbs_none);
  signal mem_ahbmi : ahb_mst_in_type;
  signal mem_ahbmo : ahb_mst_out_vector := (others => ahbm_none);
  signal l2c_stato : std_logic_vector(10 downto 0);
  
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
  signal gpioo          : gpio_out_type;

  -- JTAG
  signal tck            : std_ulogic;
  signal tckn           : std_ulogic;
  signal tms            : std_ulogic;
  signal tdi            : std_ulogic;
  signal tdo            : std_ulogic;

  function max(x,y: integer) return integer is
  begin
    if x>y then return x; else return y; end if;
  end max;
  
  -- Bus indexes
  constant hmidx_cpu     : integer := 0;
  constant hmidx_greth   : integer := hmidx_cpu     + CFG_NCPU;
  constant hmidx_free    : integer := hmidx_greth   + CFG_GRETH;
  constant l5sys_nextmst : integer := max(hmidx_free-CFG_NCPU, 1);

  constant hdidx_ahbuart : integer := 0;
  constant hdidx_ahbjtag : integer := hdidx_ahbuart + CFG_AHB_UART;
  constant hdidx_greth   : integer := hdidx_ahbjtag + CFG_AHB_JTAG;
  constant hdidx_free    : integer := hdidx_greth   + CFG_GRETH*CFG_DSU_ETH;
  constant l5sys_ndbgmst : integer := max(hdidx_free, 1);


  constant hsidx_mig       : integer := 0;
  constant hsidx_fakemig   : integer := hsidx_mig     + CFG_L2_EN*CFG_L2_AXI;
  constant hsidx_l2c       : integer := hsidx_fakemig + CFG_L2_EN;
  constant hsidx_ahbram    : integer := hsidx_l2c     + CFG_AHBRAMEN;
  constant hsidx_ahbrom    : integer := hsidx_ahbram  + 1;
  constant hsidx_ahbrep    : integer := hsidx_ahbrom  + 1;
  constant hsidx_free      : integer := hsidx_ahbrep
--pragma translate_off
                                        + 1
--pragma translate_on
                                        ;
  
  constant l5sys_nextslv : integer := max(hsidx_free, 1);

  constant pidx_ahbuart  : integer := 0;
  constant pidx_mig      : integer := pidx_ahbuart + CFG_AHB_UART;
  constant pidx_greth    : integer := pidx_mig     + 1;
  constant pidx_sgmii    : integer := pidx_greth   + CFG_GRETH;
  constant pidx_i2cmst   : integer := pidx_sgmii   + CFG_GRETH;
  constant pidx_gpio     : integer := pidx_i2cmst  + CFG_I2C_ENABLE;
  constant pidx_ahbstat  : integer := pidx_gpio    + CFG_GRGPIO_ENABLE;  
  constant pidx_free     : integer := pidx_ahbstat + CFG_AHBSTAT;
  constant l5sys_nextapb : integer := pidx_free;

  -- AHB and  APB
  signal ahbmi: ahb_mst_in_type;
  signal ahbmo: ahb_mst_out_vector_type(CFG_NCPU+l5sys_nextmst-1 downto CFG_NCPU);
  signal ahbsi: ahb_slv_in_type;
  signal ahbso: ahb_slv_out_vector_type(l5sys_nextslv-1 downto 0);
  signal dbgmi: ahb_mst_in_vector_type(l5sys_ndbgmst-1 downto 0);
  signal dbgmo: ahb_mst_out_vector_type(l5sys_ndbgmst-1 downto 0);
  signal apbi : apb_slv_in_type;
  signal apbo : apb_slv_out_vector;

  signal mig_ahbsi : ahb_slv_in_type;                            
  signal mig_ahbso : ahb_slv_out_type;
  signal greth_dbgmi: ahb_mst_in_type;
  signal greth_dbgmo: ahb_mst_out_type;
  
  signal dsuen, dsubreak: std_ulogic;
  signal cpu0errn: std_ulogic;

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

  -- Tie-Off Unused DDR4 Signals
  ddr4_par      <= gnd;
  ddr4_ten      <= gnd;
  clkref        <= gnd;

  -- The MIG will also generate the clock.
  -- When it is disabled, use a standard clkgen
  clk_gen : if (CFG_MIG_7SERIES = 0) generate
    clk_pad_ds : clkpad_ds generic map (
      tech      => padtech,
      level     => sstl12_dci,
      voltage   => x12v)
      port map (clk300p, clk300n, lclk);
    clkgen0 : clkgen        -- clock generator
      generic map (clktech, CFG_CLKMUL, CFG_CLKDIV, 0,
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
  -- LEDs
  ----------------------------------------------------------------------
  
  dsusel_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(4), dsu_sel);
  led5_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(5), cpu0errn);
  led6_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(6), calib_done);
  led7_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(7), lock);

  ----------------------------------------------------------------------
  -- LEON5 processor system
  ----------------------------------------------------------------------

  l5sys : leon5sys
    generic map (
      fabtech  => fabtech,
      memtech  => memtech,
      ncpu     => CFG_NCPU,
      nextmst  => l5sys_nextmst,
      nextslv  => l5sys_nextslv,
      nextapb  => l5sys_nextapb,
      ndbgmst  => l5sys_ndbgmst,
      ahbsplit => 1,
      cached   => CFG_DFIXED,
      wbmask   => CFG_BWMASK,
      busw     => CFG_AHBW,
      fpuconf  => CFG_FPUTYPE,
      cmemconf => 0,
      rfconf   => 0,
      disas    => disas,
      ahbtrace => ahbtrace,
      devid    => LEON5_XILINX_KCU105
      )
    port map (
      clk      => clkm,
      rstn     => rstn,
      ahbmi    => ahbmi,
      ahbmo    => ahbmo(CFG_NCPU+l5sys_nextmst-1 downto CFG_NCPU),
      ahbsi    => ahbsi,
      ahbso    => ahbso(l5sys_nextslv-1 downto 0),
      dbgmi    => dbgmi,
      dbgmo    => dbgmo,
      apbi     => apbi,
      apbo     => apbo,
      dsuen    => '1',
      dsubreak => dsubreak,
      cpu0errn => cpu0errn,
      uarti    => u1i,
      uarto    => u1o
      );
  
  nomst: if hmidx_free=CFG_NCPU generate
    ahbmo(CFG_NCPU) <= ahbm_none;
  end generate;
  noslv: if hsidx_free=0 generate
    ahbso(0) <= ahbs_none;
  end generate;


  dsui_break_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (button(4), open);
  dsubreak <= '1'
--pragma translate_off
              and '0'
--pragma translate_on
              ;

  -----------------------------------------------------------------------------
  -- Debug UART ---------------------------------------------------------------
  -----------------------------------------------------------------------------

  -- Debug UART
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map (hindex => hdidx_ahbuart, pindex => pidx_ahbuart, paddr => 0)
      port map (rstn, clkm, dui, duo, apbi, apbo(pidx_ahbuart), dbgmi(hdidx_ahbuart), dbgmo(hdidx_ahbuart));
    dui.extclk <= '0';
  end generate;

  nouah : if CFG_AHB_UART = 0 generate 
    duo.txd <= '0';
    duo.rtsn <= '0';
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

  ahbjtaggen0 :if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => hdidx_ahbjtag)
      port map(rstn, clkm, tck, tms, tdi, tdo, dbgmi(hdidx_ahbjtag), dbgmo(hdidx_ahbjtag),
               open, open, open, open, open, open, open, gnd);
  end generate;

  -----------------------------------------------------------------------------
  -- L2 cache
  -----------------------------------------------------------------------------
  l2c_gen : if (CFG_L2_EN = 1) generate
    
    l2c_axi : if (CFG_L2_AXI = 1) generate
      -- pragma translate_off
      l2_axi_err : process
        begin
          report "*** ERROR: CFG_L2_AXI= 1 is currently only supported for synthesis ***"
            severity failure;
          wait;      
      end process;
      -- pragma translate_on          
    
      l2c0 : l2c_axi_be
        generic map (
          hslvidx   => hsidx_l2c,
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
          ahbso => ahbso(hsidx_l2c),
          aximi => mem_aximi,
          aximo => mem_aximo,
          sto   => open);
      
    end generate l2c_axi;

    l2c_ahb : if (CFG_L2_AXI = 0) generate
      l2c0 : l2c generic map (
        hslvidx   => hsidx_l2c,
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
        bioaddr   => MEMAHB_IOADDR,
        biomask   => 16#fff#,
        sbus      => 0,
        mbus      => 1,
        arch      => CFG_L2_SHARE,
        ft        => CFG_L2_EDAC)
        port map (
          rst    => rstn,
          clk    => clkm,
          ahbsi  => ahbsi,
          ahbso  => ahbso(hsidx_l2c),
          ahbmi  => mem_ahbmi,
          ahbmo  => mem_ahbmo(0),
          ahbsov => mem_ahbso,
          sto => l2c_stato);

      memahb0 : ahbctrl -- AHB arbiter/multiplexer
        generic map (defmast => 0, split => 0,
                     rrobin => 0, ioaddr => MEMAHB_IOADDR,
                     ioen => 1, nahbm => 1, nahbs => 1)
        port map (rstn, clkm, mem_ahbmi, mem_ahbmo, mem_ahbsi, mem_ahbso);

      mig_ahbsi    <= mem_ahbsi;
      mem_ahbso(0) <= mig_ahbso;

    end generate l2c_ahb;

  end generate l2c_gen;

  no_l2 : if (CFG_L2_EN = 0) generate
    mig_ahbsi        <= ahbsi;
    ahbso(hsidx_mig) <= mig_ahbso;
  end generate no_l2;

  -----------------------------------------------------------------------
  ---  Xilinx DDR4 Memory Controller ------------------------------------
  ----------------------------------------------------------------------- 

  mig_gen: if (CFG_MIG_7SERIES = 1) and simulation = false generate
    
    mig_ahb: if (CFG_L2_EN = 0) or (CFG_L2_AXI = 0) generate
      
      ddrc: ahb2axi_mig4_7series generic map (
        hindex => 0, haddr => 16#400#, hmask => 16#F00#,
        pindex => pidx_mig, paddr => 4
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
          apbo            => apbo(pidx_mig),
          clk_amba        => clkm,
          -- Misc
          ddr4_ui_clkout1 => clkm,
          clk_ref_i       => clkref
          );

    end generate mig_ahb;

    mig_axi: if (CFG_L2_EN = 1) and (CFG_L2_AXI = 1) generate

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

      -----------------------------------------------------------------------
      ---  Fake MIG PNP -----------------------------------------------------
      -----------------------------------------------------------------------
      ahbso(hsidx_fakemig).hindex  <= hsidx_fakemig;
      ahbso(hsidx_fakemig).hconfig <= mig_hconfig;
      ahbso(hsidx_fakemig).hready  <= '1';
      ahbso(hsidx_fakemig).hresp   <= "00";
      ahbso(hsidx_fakemig).hirq    <= (others => '0');
      ahbso(hsidx_fakemig).hrdata  <= (others => '0');
      -- No APB interface on mig
      apbo(pidx_mig)    <= apb_none;      
      
    end generate mig_axi;      

  end generate mig_gen;

  simgen: if (CFG_MIG_7SERIES = 1) and (simulation = true) generate
    
    -- pragma translate_off
    -- Generate clkm
    clkm <= not clkm after 5.0 ns;
    -- No APB interface on mig
    apbo(pidx_mig)    <= apb_none;
    
    mig_ahbram : ahbram_sim
      generic map (
        hindex        => hsidx_mig,
        haddr         => 16#400#,
        hmask         => 16#C00#,
        tech          => 0,
        kbytes        => 4096,
        pipe          => 0,
        maccsz        => AHBDW,
        fname         => ramfile
        )
      port map(
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

  -- pragma translate_on
  end generate simgen;
  
  
  -----------------------------------------------------------------------
  ---  AHB RAM ----------------------------------------------------------
  -----------------------------------------------------------------------

  ocram : if CFG_AHBRAMEN = 1 generate
    ahbram0 : ahbram
      generic map (hindex => hsidx_ahbram, haddr => CFG_AHBRADDR, tech => CFG_MEMTECH,
                   kbytes => CFG_AHBRSZ, pipe => CFG_AHBRPIPE)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbram));
  end generate;


-----------------------------------------------------------------------
---  AHB ROM ----------------------------------------------------------
-----------------------------------------------------------------------

  bpromgen : if CFG_AHBROMEN /= 0 or (simulation = true) generate
    brom : entity work.ahbrom128
      generic map (hindex => hsidx_ahbrom, haddr => CFG_AHBRODDR, pipe => CFG_AHBROPIP)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbrom));
  end generate;


  ----------------------------------------------------------------------
  --- ETHERNET ---------------------------------------------------------
  ----------------------------------------------------------------------

  -- Gaisler ethernet MAC
  eth0 : if CFG_GRETH = 1 generate

    e1 : grethm_mb
      generic map(
        hindex => hmidx_greth,
        ehindex => hdidx_greth,
        pindex => pidx_greth,
        paddr => 16#C00#,
        pmask => 16#C00#,
        pirq => 5,
        memtech => memtech,
        mdcscaler => CPU_FREQ/1000,
        rmii => 0,
        enable_mdio => 1,
        fifosize => CFG_ETH_FIFO,
        nsync => 2,
        edcl => CFG_DSU_ETH,
        edclbufsz => CFG_ETH_BUF,
        phyrstadr => 7,
        macaddrh => CFG_ETH_ENM,
        macaddrl => CFG_ETH_ENL,
        enable_mdint => 1,
        ipaddrh => CFG_ETH_IPM,
        ipaddrl => CFG_ETH_IPL,
        giga => CFG_GRETH1G,
        ramdebug => 0,
        gmiimode => 1,
        edclsepahb => 1
        )
      port map(
        rst => rstn,
        clk => clkm,
        ahbmi => ahbmi,
        ahbmo => ahbmo(hmidx_greth),
        ahbmi2 => greth_dbgmi,
        ahbmo2 => greth_dbgmo,
        apbi => apbi,
        apbo => apbo(pidx_greth),
        ethi => gmiii,
        etho => gmiio
       --   debug_rx => e1_debug_rx,
       --   debug_tx => e1_debug_tx,
       --   debug_gtx => e1_debug_gtx
        );
    sgmiirst <= not rstraw;

    sgmii0 : sgmii_kcu105
      generic map(
        pindex          => pidx_sgmii,
        paddr           => 16#010#,
        pmask           => 16#ff0#,
        abits           => 8,
        autonegotiation => autonegotiation,
        pirq            => 11,
        edclsepahb      => 1,
        debugmem        => 1,
        tech            => fabtech
        )
      port map(
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
        apbo     => apbo(pidx_sgmii)
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

  end generate eth0;

  edcl0 : if (CFG_GRETH=1 and CFG_DSU_ETH=1)  generate
    greth_dbgmi <= dbgmi(hdidx_greth);
    dbgmo(hdidx_greth) <= greth_dbgmo;
  end generate;

  noedcl0 : if not (CFG_GRETH=1 and CFG_DSU_ETH=1) generate
    greth_dbgmi <= ahbm_in_none;
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
  --- Various APB periherals --------------------------------
  ----------------------------------------------------------------------

  -- GPIO units
  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate

    grgpio_ledsw : grgpio
      generic map(
        pindex => pidx_gpio,
        paddr => 10,
        imask => CFG_GRGPIO_IMASK,
        nbits => CFG_GRGPIO_WIDTH)
      port map(
        rst   => rstn,
        clk   => clkm,
        apbi  => apbi,
        apbo  => apbo(pidx_gpio),
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

    gpbut_pads : for i in 0 to 3 generate
      gpsw_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (button(i), gpioi.din(i+4));
    end generate gpbut_pads;

    pio_pads : for i in 0 to 7 generate
      gpio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x12v, strength => 8)
        port map (gpio(i), gpioo.dout(i+8), gpioo.oen(i+8), gpioi.din(i+8));
    end generate; 

  end generate;

  -- I2C Master
  i2cm: if CFG_I2C_ENABLE = 1 generate
    i2c0 : i2cmst generic map (pindex => pidx_i2cmst, paddr => 9, pmask => 16#FFF#, pirq => 10, filter => 9)
      port map (rstn, clkm, apbi, apbo(pidx_i2cmst), i2ci, i2co);

    i2c_scl_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (iic_scl, i2co.scl, i2co.scloen, i2ci.scl);

    i2c_sda_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (iic_sda, i2co.sda, i2co.sdaoen, i2ci.sda);

  end generate i2cm;


  -----------------------------------------------------------------------
  ---  AHB Status Register ----------------------------------------------
  -----------------------------------------------------------------------

  ahbs : if CFG_AHBSTAT = 1 generate
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat
      generic map (pindex => pidx_ahbstat, paddr => 15, pirq => 7,
                   nftslv => CFG_AHBSTATN)
      port map(rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(pidx_ahbstat));
  end generate;

  -----------------------------------------------------------------------
  ---  Test report module  ----------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  test0 : ahbrep
    generic map (hindex => hsidx_ahbrep, haddr => 16#200#)
    port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbrep));
  -- pragma translate_on

  -----------------------------------------------------------------------
  ---  Boot message  ----------------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  x : report_design
    generic map (
      msg1    => "LEON5/GRLIB Xilinx KCU105 Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
      );
-- pragma translate_on
end;
