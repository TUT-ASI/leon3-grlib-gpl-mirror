------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config.all;
use grlib.config_types.all;

library techmap;
use techmap.gencomp.all;

library gaisler;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.axi.all;
use gaisler.plic.all;
use gaisler.l2cache.all;
use gaisler.noelv.all;
use gaisler.hssl.all;

--pragma translate_off
use gaisler.sim.all;
--pragma translate_on

use work.config.all;
use work.config_local.all;
use work.rev.REVISION;
use work.cfgmap.all;

entity noelvmp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;     -- Enable disassembly to console
    SIMULATION              : integer := 0
    -- pragma translate_off 
    + CFG_MIG_7SERIES_MODEL
    ; ramfile               : string  := "ram.srec"
    ; romfile               : string  := "prom.srec"
    -- pragma translate_on
    );
  port (
    -- Clock and Reset
    reset       : in    std_ulogic;
    clk250p     : in    std_ulogic;  -- 250 MHz clock
    clk250n     : in    std_ulogic;  -- 250 MHz clock
    -- Switches
    switch      : in    std_logic_vector(3 downto 0);
    -- LEDs
    led         : out   std_logic_vector(7 downto 0);
    -- GPIOs
    gpio        : inout std_logic_vector(15 downto 0);
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
    -- CANFD
    can0_tx           : out   std_logic;
    can0_rx           : in    std_logic;
    can1_tx           : out   std_logic;
    can1_rx           : in    std_logic;
    -- HSSL 
    gbtclk0_p    : in    std_ulogic;                    -- SerDes clock (MGTREFCLK0)
    gbtclk0_n    : in    std_ulogic;                    -- SerDes clock (MGTREFCLK0)
    gtyrxn_in    : in    std_logic_vector(1 downto 0);  -- SerDes data pin RXN
    gtyrxp_in    : in    std_logic_vector(1 downto 0);  -- SerDes data pin RXP
    gtytxn_out   : out   std_logic_vector(1 downto 0);  -- SerDes data pin TXN
    gtytxp_out   : out   std_logic_vector(1 downto 0);  -- SerDes data pin TXP
    -- SpW
    fp_spw_dout_p     : out std_logic_vector (1 downto 0);
    fp_spw_dout_n     : out std_logic_vector (1 downto 0);
    fp_spw_sout_p     : out std_logic_vector (1 downto 0);
    fp_spw_sout_n     : out std_logic_vector (1 downto 0);
    fp_spw_din_p      : in std_logic_vector (1 downto 0);
    fp_spw_din_n      : in std_logic_vector (1 downto 0);
    fp_spw_sin_p      : in std_logic_vector (1 downto 0);
    fp_spw_sin_n      : in std_logic_vector (1 downto 0);
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
    --ddr4_alert_n: in    std_ulogic;                   -- Alert Output
    ddr4_odt    : out   std_logic_vector(0 downto 0); -- On-die Termination
    ddr4_par    : out   std_ulogic;                   -- Parity for cmd and addr
    ddr4_ten    : out   std_ulogic;                   -- Connectivity Test Mode
    ddr4_cs_n   : out   std_logic_vector(0 downto 0); -- Chip Select
    ddr4_reset_n: out   std_ulogic                    -- Asynchronous Reset
    );
end;

architecture rtl of noelvmp is
  constant OEPOL        : integer := padoen_polarity(padtech);
  constant BOARD_FREQ   : integer := 250000; -- input frequency in KHz
  constant CPU_FREQ     : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV; -- cpu frequency in KHz

  -------------------------------------
  -- Misc
  signal vcc            : std_ulogic;
  signal gnd            : std_ulogic;
  signal stati          : ahbstat_in_type;
  -- Clocks and Reset
  signal clkm           : std_ulogic
  -- pragma translate_off 
  := '0'
  -- pragma translate_on
  ;
  signal rstn           : std_ulogic;
  signal clk_300        : std_ulogic;
  signal cgi            : clkgen_in_type;
  signal cgo            : clkgen_out_type;
  signal clklock        : std_ulogic;
  signal lock           : std_ulogic;
  signal lclk           : std_ulogic;
  signal rst            : std_ulogic;
  signal resetn         : std_ulogic;
  signal clkref         : std_ulogic;
  signal calib_done     : std_ulogic;
  signal migrstn        : std_ulogic;

  -- UART
  signal dsu_sel        : std_ulogic;
  signal uart_rx    : std_logic_vector(0 downto 0);
  signal uart_ctsn  : std_logic_vector(0 downto 0);
  signal uart_tx    : std_logic_vector(0 downto 0);
  signal uart_rtsn  : std_logic_vector(0 downto 0);
  signal duart_rx   : std_ulogic;
  signal duart_tx   : std_ulogic;
  -- GPIO
  signal gpio_i         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  signal gpio_o         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  signal gpio_oe        : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  -- JTAG
  signal tck, tms, tdi, tdo : std_ulogic;
  -- Ethernet
  signal ethi : eth_in_type;
  signal etho : eth_out_type;
  signal eth_apbi       : apb_slv_in_type;
  signal eth_apbo       : apb_slv_out_type := apb_none;
  -- HSSL
  signal hssl_clk     : std_ulogic;
  signal hssl_rstn    : std_ulogic;
  signal hssl_lock    : std_ulogic;
  signal hssl_rx_rstn : std_logic_vector(1 downto 0);
  signal hssli        : grhssl_in_type_vector(1 downto 0);
  signal hsslo        : grhssl_out_type_vector(1 downto 0);
  signal cgi_hssl : clkgen_in_type;
  signal cgo_hssl : clkgen_out_type;

  -- HSSL SerDes
  signal gt_userclk_tx_reset_in    : std_logic_vector(0 downto 0);
  signal gt_userclk_tx_usrclk2_out : std_logic_vector(0 downto 0);
  signal gt_userclk_tx_active_out  : std_logic_vector(0 downto 0);
  signal gt_userclk_rx_reset_in    : std_logic_vector(1 downto 0);
  signal gt_userclk_rx_usrclk2_out : std_logic_vector(1 downto 0);
  signal gt_userclk_rx_active_out  : std_logic_vector(1 downto 0);
  signal gt_buffbypass_rx_reset_in : std_logic_vector(1 downto 0);
  signal gt_reset_clk_freerun_in   : std_logic_vector(0 downto 0);
  signal gt_reset_all_in           : std_logic_vector(0 downto 0);
  signal gt_userdata_tx_in         : std_logic_vector(79 downto 0);
  signal gt_userdata_rx_out        : std_logic_vector(79 downto 0);
  signal gtrefclk00_in             : std_logic_vector(0 downto 0);
  signal gtpowergood_out           : std_logic_vector(1 downto 0);
  signal rxpmaresetdone_out        : std_logic_vector(1 downto 0);
  signal txpmaresetdone_out        : std_logic_vector(1 downto 0);

  -- SpaceWire
  signal spw_txd          : std_logic_vector(CFG_SPWRTR_SPWPORTS-1 downto 0);
  signal spw_txs          : std_logic_vector(CFG_SPWRTR_SPWPORTS-1 downto 0);
  signal spw_rxd          : std_logic_vector(CFG_SPWRTR_SPWPORTS-1 downto 0);
  signal spw_rxs          : std_logic_vector(CFG_SPWRTR_SPWPORTS-1 downto 0);

  -- Memory
  signal mem_aximi      : axi_somi_type;
  signal mem_aximo      : axi_mosi_type;
  signal mem_ahbsi0     : ahb_slv_in_type;
  signal mem_ahbso0     : ahb_slv_out_type;
  signal mem_apbi0      : apb_slv_in_type;
  signal mem_apbo0      : apb_slv_out_type;
  signal rom_ahbsi1     : ahb_slv_in_type;
  signal rom_ahbso1     : ahb_slv_out_type;

  signal uart_rx_int    : std_ulogic; 
  signal uart_tx_int    : std_ulogic; 
  signal uart_ctsn_int  : std_ulogic;
  signal uart_rtsn_int  : std_ulogic;

  signal dmen           : std_logic;
  signal dmbreak        : std_logic;
  signal cpu0errn       : std_logic;

  component sgmii_vcu118
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
      sgmiii   : in  eth_sgmii_in_type;
      sgmiio   : out eth_sgmii_out_type;
      gmiii    : out eth_in_type;
      gmiio    : in  eth_out_type;
      reset    : in  std_logic;
      clkout0o : out std_logic;
      clkout1o : out std_logic;
      clkout2o : out std_logic;
      apb_clk  : in  std_logic;
      apb_rstn : in  std_logic;
      apbi     : in  apb_slv_in_type;
      apbo     : out apb_slv_out_type
      );
  end component;

  component ahb2axi_mig4_7series
    generic (
      pipelined               : boolean := false;
      hindex                  : integer := 0;
      haddr                   : integer := 0;
      hmask                   : integer := 16#f00#      
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
      clk_amba            : in    std_logic;
      ddr4_ui_clkout1     : out   std_logic
    );
  end component;

  component BUFG
    port (
      I : in  std_logic;
      O : out std_logic
      );
  end component;

  component IBUFDS_GTE4
    port (
      CEB   : in  std_logic;
      I     : in  std_logic;
      IB    : in  std_logic;
      O     : out std_logic;
      ODIV2 : out std_logic
      );
  end component;

    component IBUFDS
    generic (
      DQS_BIAS   : string := "FALSE";
      IOSTANDARD : string := "DEFAULT"
      );
    port (
      O  : out std_ulogic;
      I  : in  std_ulogic;
      IB : in  std_ulogic
      );
  end component;

  component OBUFDS
    port(
      I  : in  std_logic;
      O  : out std_logic;
      OB : out std_logic
      );
  end component;

  component hssl_serdes
    port (
      gtwiz_userclk_tx_reset_in          : in  std_logic_vector(0 downto 0);
      gtwiz_userclk_tx_srcclk_out        : out std_logic_vector(0 downto 0);
      gtwiz_userclk_tx_usrclk_out        : out std_logic_vector(0 downto 0);
      gtwiz_userclk_tx_usrclk2_out       : out std_logic_vector(0 downto 0);
      gtwiz_userclk_tx_active_out        : out std_logic_vector(0 downto 0);
      gtwiz_userclk_rx_reset_in          : in  std_logic_vector(1 downto 0);
      gtwiz_userclk_rx_srcclk_out        : out std_logic_vector(1 downto 0);
      gtwiz_userclk_rx_usrclk_out        : out std_logic_vector(1 downto 0);
      gtwiz_userclk_rx_usrclk2_out       : out std_logic_vector(1 downto 0);
      gtwiz_userclk_rx_active_out        : out std_logic_vector(1 downto 0);
      gtwiz_buffbypass_rx_reset_in       : in  std_logic_vector(1 downto 0);
      gtwiz_buffbypass_rx_start_user_in  : in  std_logic_vector(1 downto 0);
      gtwiz_buffbypass_rx_done_out       : out std_logic_vector(1 downto 0);
      gtwiz_buffbypass_rx_error_out      : out std_logic_vector(1 downto 0);
      gtwiz_reset_clk_freerun_in         : in  std_logic_vector(0 downto 0);
      gtwiz_reset_all_in                 : in  std_logic_vector(0 downto 0);
      gtwiz_reset_tx_pll_and_datapath_in : in  std_logic_vector(0 downto 0);
      gtwiz_reset_tx_datapath_in         : in  std_logic_vector(0 downto 0);
      gtwiz_reset_rx_pll_and_datapath_in : in  std_logic_vector(0 downto 0);
      gtwiz_reset_rx_datapath_in         : in  std_logic_vector(0 downto 0);
      gtwiz_reset_rx_cdr_stable_out      : out std_logic_vector(0 downto 0);
      gtwiz_reset_tx_done_out            : out std_logic_vector(0 downto 0);
      gtwiz_reset_rx_done_out            : out std_logic_vector(0 downto 0);
      gtwiz_userdata_tx_in               : in  std_logic_vector(79 downto 0);
      gtwiz_userdata_rx_out              : out std_logic_vector(79 downto 0);
      gtrefclk00_in                      : in  std_logic_vector(0 downto 0);
      qpll0outclk_out                    : out std_logic_vector(0 downto 0);
      qpll0outrefclk_out                 : out std_logic_vector(0 downto 0);
      gtyrxn_in                          : in  std_logic_vector(1 downto 0);
      gtyrxp_in                          : in  std_logic_vector(1 downto 0);
      gtytxn_out                         : out std_logic_vector(1 downto 0);
      gtytxp_out                         : out std_logic_vector(1 downto 0);
      gtpowergood_out                    : out std_logic_vector(1 downto 0);
      rxpmaresetdone_out                 : out std_logic_vector(1 downto 0);
      txpmaresetdone_out                 : out std_logic_vector(1 downto 0)
    );
  end component;

begin

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------
  vcc         <= '1';
  gnd         <= '0';
  cgi.pllctrl <= "00";
  cgi.pllrst  <= resetn;

  -- Clocks
  clk_gen : if (CFG_MIG_7SERIES = 0) or 
               ((CFG_MIG_7SERIES = 1) and (SIMULATION /= 0)) generate
    clk_pad_ds : clkpad_ds generic map (
      tech      => padtech,
      level     => sstl12_dci,
      voltage   => x12v)
      port map (clk250p, clk250n, lclk);
    clkgen0 : clkgen        -- clock generator
      generic map (clktech, CFG_CLKMUL, CFG_CLKDIV, 0,
                   CFG_CLK_NOFB, 0, 0, 0, BOARD_FREQ)
      port map (lclk, lclk, clkm, open, open, open, open, cgi, cgo, open, open, open);
  end generate;

  reset_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (reset, rst);

  resetn <= not rst;

  lock <= calib_done when CFG_MIG_7SERIES = 1 else cgo.clklock;

  rst1 : rstgen         -- reset generator
    generic map (acthigh => 1)
    port map (rst, clkm, lock, migrstn, open);

  ----------------------------------------------------------------------
  ---  NOEL-V SUBSYSTEM ------------------------------------------------
  ----------------------------------------------------------------------

  core0 : entity work.noelvcore
  generic map (
    fabtech     => CFG_FABTECH,
    memtech     => CFG_MEMTECH,
    padtech     => CFG_PADTECH,
    clktech     => CFG_CLKTECH,
    cpu_freq    => CPU_FREQ,
    devid       => NOELV_SOC,
    disas       => disas,
    irqtest     => 1)
  port map (
    -- Clock & reset
    clkm        => clkm, 
    resetn      => resetn,
    lock        => lock,
    rstno       => rstn,
    -- misc
    dmen        => '1',
    dmbreak     => dmbreak,
    dmreset     => open,
    cpu0errn    => open,
    -- GPIO
    gpio_i      => gpio_i,
    gpio_o      => gpio_o,
    gpio_oe     => gpio_oe,
    -- UART
    uart_rx     => uart_rx,
    uart_ctsn   => uart_ctsn,
    uart_tx     => uart_tx,
    uart_rtsn   => uart_rtsn,
    -- Memory controller
    mem_aximi   => mem_aximi,
    mem_aximo   => mem_aximo,
    mem_ahbsi0  => mem_ahbsi0,
    mem_ahbso0  => mem_ahbso0,
    mem_apbi0   => mem_apbi0, 
    mem_apbo0   => mem_apbo0, 
    -- PROM controller
    rom_ahbsi1  => rom_ahbsi1,
    rom_ahbso1  => rom_ahbso1,
    -- Ethernet PHY
    ethi        => ethi,
    etho        => etho,
    eth_apbi    => eth_apbi,
    eth_apbo    => eth_apbo,
    -- CANFD
    can0_tx     => can0_tx,
    can0_rx     => can0_rx,
    can1_tx     => can1_tx,
    can1_rx     => can1_rx,
    -- HSSL
    hssl_clk    => hssl_clk,
    hssl_rstn   => hssl_rstn,
    hssli       => hssli,
    hsslo       => hsslo,
    -- SpW
    spw_txd     => spw_txd,
    spw_txs     => spw_txs,
    spw_rxd     => spw_rxd,
    spw_rxs     => spw_rxs,
    -- Debug UART
    duart_rx    => duart_rx,
    duart_tx    => duart_tx,
    -- Debug JTAG
    tck         => tck,
    tms         => tms,
    tdi         => tdi,
    tdo         => tdo
  );

  --errorn_pad : odpad
  --  generic map (tech => padtech, oepol => OEPOL)
  --  port map (errorn, cpu0errn);

  --dsuen_pad : inpad
  --  generic map (tech => padtech, level => cmos, voltage => x12v)
  --  port map (switch(2), dmen);
  dmen <= '1';

  -- Button 2,3,4 are still to be assigned
  dmbreak_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (button(4), dmbreak);

  --ndreset_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(4), dsuo.ndmreset);

  --dmactive_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(5), dsuo.dmactive);

  -----------------------------------------------------------------------------
  -- Debug UART / UART --------------------------------------------------------
  -----------------------------------------------------------------------------
  sw4_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x12v)
    port map (switch(3), dsu_sel);

  uart_tx_int     <= duart_tx       when dsu_sel = '1' else uart_tx(0);
  uart_rtsn_int   <= '1'            when dsu_sel = '1' else uart_rtsn(0);  
  uart_rx(0)      <= uart_rx_int    when dsu_sel = '0' else '1';
  uart_ctsn(0)    <= uart_ctsn_int  when dsu_sel = '0' else '1';
  duart_rx        <= uart_rx_int    when dsu_sel = '1' else '1';
  
  dsurx_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsurx, uart_rx_int);
  dsutx_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsutx, uart_tx_int);
  dsuctsn_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsuctsn, uart_ctsn_int);
  dsurtsn_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsurtsn, uart_rtsn_int);

  dsusel_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(4), dsu_sel);

  -----------------------------------------------------------------------------
  -- DDR4 Memory Controller (MIG) ---------------------------------------------
  -----------------------------------------------------------------------------
  -- No APB interface on memory controller  
  mem_apbo0    <= apb_none;

  mig_gen : if (CFG_MIG_7SERIES = 1) and (SIMULATION = 0) generate
    ddr4c: ahb2axi_mig4_7series generic map (
      hindex => 0,
      haddr  => 16#000#,
      hmask  => 16#E00#
      )
      port map (
        calib_done      => calib_done,
        sys_clk_p       => clk250p,
        sys_clk_n       => clk250n,
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
        rst_n_async     => resetn,
        ahbsi           => mem_ahbsi0,
        ahbso           => mem_ahbso0,
        clk_amba        => clkm,
        -- Misc
        ddr4_ui_clkout1 => clkm
        );
  end generate mig_gen;

  no_mig_gen : if (CFG_MIG_7SERIES = 0) generate  
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
  
  -- Simulation module
  no_mig_mem_gen : if (CFG_MIG_7SERIES = 0) generate
    axi_mem_gen : if (CFG_L2_AXI = 1) generate
      mem_ahbso0 <= ahbs_none;
    end generate axi_mem_gen;

    ahb_mem_gen : if (CFG_L2_AXI = 0) generate
      ahbram1 : ahbram 
        generic map (
          hindex      => 0,
          haddr       => L2C_HADDR,
          hmask       => L2C_HMASK,
          tech        => CFG_MEMTECH,
          kbytes      => 1024)
        port map (
          rstn,
          clkm,
          mem_ahbsi0,
          mem_ahbso0);
    end generate ahb_mem_gen;
  end generate no_mig_mem_gen;

  -- Simulation module
  -- pragma translate_off
  sim_mem_gen : if (CFG_MIG_7SERIES = 1) and (SIMULATION /= 0) generate
    calib_done  <= '1';

    axi_mem_gen : if (CFG_L2_AXI = 1) generate
      mig_axiram : aximem
        generic map (
          fname   => ramfile,
          axibits => AXIDW,
          rstmode => 0)
        port map (
          clk   => clkm,
          rst   => rstn,
          axisi => mem_aximo,
          axiso => mem_aximi);

      mem_ahbso0 <= ahbs_none;
    end generate axi_mem_gen;

    ahb_mem_gen : if (CFG_L2_AXI = 0) generate
      mig_ahbram : ahbram_sim
        generic map (
          hindex   => 0,
          haddr    => L2C_HADDR,
          hmask    => L2C_HMASK,
          tech     => 0,
          kbytes   => 1024,
          pipe     => 0,
          maccsz   => AHBDW,
          fname    => ramfile)
        port map(
          rst     => rstn,
          clk     => clkm,
          ahbsi   => mem_ahbsi0,
          ahbso   => mem_ahbso0);
    end generate ahb_mem_gen;
  end generate sim_mem_gen;
  -- pragma translate_on

  -----------------------------------------------------------------------
  --  PROM
  -----------------------------------------------------------------------

  prom_gen : if (SIMULATION = 0) generate
    rom32 : if CFG_AHBDW = 32 generate
      brom : entity work.ahbrom
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi1,
          ahbso   => rom_ahbso1);
    end generate;
    rom64 : if CFG_AHBDW = 64 generate
      brom : entity work.ahbrom64
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi1,
          ahbso   => rom_ahbso1);
    end generate;
    rom128 : if CFG_AHBDW = 128 generate
      brom : entity work.ahbrom128
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi1,
          ahbso   => rom_ahbso1);
    end generate;
  end generate prom_gen;

  -- pragma translate_off
  sim_prom_gen : if (SIMULATION /= 0) generate
    mig_ahbram : ahbram_sim
      generic map (
        hindex   => 1,
        haddr    => ROM_HADDR,
        hmask    => ROM_HMASK,
        tech     => 0,
        kbytes   => 1024,
        pipe     => 0,
        maccsz   => AHBDW,
        fname    => romfile)
      port map(
        rst     => rstn,
        clk     => clkm,
        ahbsi   => rom_ahbsi1,
        ahbso   => rom_ahbso1);
  end generate sim_prom_gen;
  -- pragma translate_on

-----------------------------------------------------------------------
-- GPIO                                                                
-----------------------------------------------------------------------
  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate

    gpled_pads : for i in 0 to 3 generate
      gpled_pad : outpad
        generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (led(i), gpio_o(i+16));
    end generate gpled_pads;

    gpsw_pads : for i in 0 to 2 generate
      gpsw_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (switch(i), gpio_i(i));
    end generate gpsw_pads;
    gpio_i(3) <= dsu_sel;

    gpb_pads : for i in 0 to 3 generate
      gpb_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (button(i), gpio_i(i+4));
    end generate gpb_pads;

    pio_pads : for i in 0 to 7 generate
      gpio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x12v, strength => 8)
        port map (gpio(i), gpio_o(i+8), gpio_oe(i+8), gpio_i(i+8));
    end generate;

  end generate;

-----------------------------------------------------------------------
-- ETHERNET PHY
-----------------------------------------------------------------------

  eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC

    eth_block : block
      signal sgmiii         : eth_sgmii_in_type; 
      signal sgmiio         : eth_sgmii_out_type;
      signal sgmiirst       : std_ulogic;
      signal clkout0o       : std_ulogic;
      signal clkout1o       : std_ulogic;
      signal clkout2o       : std_ulogic;
    begin
      sgmiirst <= not resetn;

      -- Reset driven to the SGMII IP is active high
      sgmii0 : sgmii_vcu118
      generic map (
        pindex          => GRETH_PHY_PINDEX,
        paddr           => GRETH_PHY_PADDR,
        pmask           => GRETH_PHY_PMASK,
        abits           => 8,
        autonegotiation => 1,
        pirq            => GRETH_PHY_PIRQ,
        debugmem        => 1,
        tech            => fabtech
      )
      port map (
        sgmiii   => sgmiii,
        sgmiio   => sgmiio,
        gmiii    => ethi,
        gmiio    => etho,
        reset    => sgmiirst,
        clkout0o => open,
        clkout1o => open,
        clkout2o => clkout2o,
        apb_clk  => clkm,
        apb_rstn => rstn,
        apbi     => eth_apbi,
        apbo     => open
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

    end block eth_block;
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
-- HSSL SpaceFiber
-----------------------------------------------------------------------

  hssl0 : if CFG_HSSL_EN /= 0 generate

    -- MGTREFCLK0: SerDes PLL reference clock
    serdes_refclk_ibuf : IBUFDS_GTE4
      port map (
        CEB   => '0',
        I     => gbtclk0_p,
        IB    => gbtclk0_n,
        O     => gtrefclk00_in(0),
        ODIV2 => open
        );

    -- HSSL clock taken from the SerDes TX user clock
    serdes_txclk_buf : BUFG
      port map (
        I => gt_userclk_tx_usrclk2_out(0),
        O => hssl_clk
        );

    -- HSSL reset generator
    rst_hssl : rstgen
      generic map (acthigh => 1)
      port map (rst, hssl_clk, hssl_lock, hssl_rstn, open);

    hssl_lock <= gt_userclk_tx_active_out(0);

    -- The free-running clock is derived from the AMBA clock
    -- The SerDes reset sequence shall not begin until this clock is stable

    clkgen_hssl : clkgen
      generic map (
        tech    => fabtech,
        clk_mul => 10,
        clk_div => 20,
        freq    => 100000)
      port map (
        clkin    => clkm,                        -- 100 MHz
        pciclkin => '0',
        clk      => gt_reset_clk_freerun_in(0),  -- 50 MHz
        clkn     => open,
        clk2x    => open,
        sdclk    => open,
        pciclk   => open,
        cgi      => cgi_hssl,
        cgo      => cgo_hssl
        );

    cgi_hssl.pllctrl <= "00";
    cgi_hssl.pllrst  <= rst;

    -- Deassert the reset when the power of each channel is good and the FPGA is not reset
    gt_reset_all_in(0) <= '0' when rst = '1' and cgo_hssl.clklock = '1' and gtpowergood_out = "11"
                          else '1';

    -- The user clocking helper block should be held in reset until the clock
    -- source of that block is known to be stable
    gt_userclk_tx_reset_in(0) <= not andv(txpmaresetdone_out);
    gt_userclk_rx_reset_in    <= not rxpmaresetdone_out;

    -- Instantiate a reset generator per RX channel to ensure that the RX
    -- bypass helper block is held in reset until the RX clock is active
    gen_hssl_rxrst : for i in 0 to 1 generate
      rst_hssl_rx : rstgen
        generic map (acthigh => 1)
        port map (gt_userclk_rx_active_out(i), gt_userclk_rx_usrclk2_out(i), vcc,
                  hssl_rx_rstn(i), open);
    end generate;

    -- The RX bypass helper block requires an active-high reset
    gt_buffbypass_rx_reset_in <= not hssl_rx_rstn;

    -- SerDes macro
    hssl_serdes0 : hssl_serdes
      port map (
        gtwiz_userclk_tx_reset_in          => gt_userclk_tx_reset_in,
        gtwiz_userclk_tx_srcclk_out        => open,
        gtwiz_userclk_tx_usrclk_out        => open,
        gtwiz_userclk_tx_usrclk2_out       => gt_userclk_tx_usrclk2_out,
        gtwiz_userclk_tx_active_out        => gt_userclk_tx_active_out,
        gtwiz_userclk_rx_reset_in          => gt_userclk_rx_reset_in,
        gtwiz_userclk_rx_srcclk_out        => open,
        gtwiz_userclk_rx_usrclk_out        => open,
        gtwiz_userclk_rx_usrclk2_out       => gt_userclk_rx_usrclk2_out,
        gtwiz_userclk_rx_active_out        => gt_userclk_rx_active_out,
        gtwiz_buffbypass_rx_reset_in       => gt_buffbypass_rx_reset_in,
        gtwiz_buffbypass_rx_start_user_in  => (others => '0'),
        gtwiz_buffbypass_rx_done_out       => open,
        gtwiz_buffbypass_rx_error_out      => open,
        gtwiz_reset_clk_freerun_in         => gt_reset_clk_freerun_in,
        gtwiz_reset_all_in                 => gt_reset_all_in,
        gtwiz_reset_tx_pll_and_datapath_in => (others => '0'),
        gtwiz_reset_tx_datapath_in         => (others => '0'),
        gtwiz_reset_rx_pll_and_datapath_in => (others => '0'),
        gtwiz_reset_rx_datapath_in         => (others => '0'),
        gtwiz_reset_rx_cdr_stable_out      => open,
        gtwiz_reset_tx_done_out            => open,
        gtwiz_reset_rx_done_out            => open,
        gtwiz_userdata_tx_in               => gt_userdata_tx_in,
        gtwiz_userdata_rx_out              => gt_userdata_rx_out,
        gtrefclk00_in                      => gtrefclk00_in,
        qpll0outclk_out                    => open,
        qpll0outrefclk_out                 => open,
        gtyrxn_in                          => gtyrxn_in,
        gtyrxp_in                          => gtyrxp_in,
        gtytxn_out                         => gtytxn_out,
        gtytxp_out                         => gtytxp_out,
        gtpowergood_out                    => gtpowergood_out,
        rxpmaresetdone_out                 => rxpmaresetdone_out,
        txpmaresetdone_out                 => txpmaresetdone_out
        );

      -- HSSL - SerDes mapping

      gt_userdata_tx_in(39 downto 0) <= hsslo(0).tx_data;

      hssli(0).rx_clk    <= gt_userclk_rx_usrclk2_out(0);
      hssli(0).rx_data   <= gt_userdata_rx_out(39 downto 0);
      hssli(0).rx_kflags <= (others => '0');  -- Unused (8b10b encoding in the IP)
      hssli(0).rx_serror <= (others => '0');  -- Unused
      hssli(0).no_signal <= '0';              -- Unused

      gt_userdata_tx_in(79 downto 40) <= hsslo(1).tx_data;

      hssli(1).rx_clk    <= gt_userclk_rx_usrclk2_out(1);
      hssli(1).rx_data   <= gt_userdata_rx_out(79 downto 40);
      hssli(1).rx_kflags <= (others => '0');  -- Unused (8b10b encoding in the IP)
      hssli(1).rx_serror <= (others => '0');  -- Unused
      hssli(1).no_signal <= '0';              -- Unused

  end generate;


-----------------------------------------------------------------------
-- SpaceWire
-----------------------------------------------------------------------

  spwrtr_pads: if CFG_SPWRTR_ENABLE = 1 and CFG_LOCAL_SPWRTR_LOOP_BACK = 0 generate
  
    fp: for i in 0 to 1 generate
      -- SpaceWire Router pads for front panel
      txd_pad : OBUFDS
        port map (O => fp_spw_dout_p(i), OB => fp_spw_dout_n(i), I => spw_txd(i));
      txs_pad : OBUFDS
        port map (O => fp_spw_sout_p(i), OB => fp_spw_sout_n(i), I => spw_txs(i));

      rxd_pad : IBUFDS
        port map (I => fp_spw_din_p(i), IB => fp_spw_din_n(i), O => spw_rxd(i) );
      rxs_pad : IBUFDS
        port map (I => fp_spw_sin_p(i), IB => fp_spw_sin_n(i), O => spw_rxs(i) );      
    end generate fp;  
    
  end generate spwrtr_pads;

  nospwrtr_pads: if CFG_SPWRTR_ENABLE = 0 or CFG_LOCAL_SPWRTR_LOOP_BACK = 1 generate
  
    fp: for i in 0 to 1 generate
      -- SpaceWire Router pads for front panel
      txd_pad : OBUFDS
        port map (O => fp_spw_dout_p(i), OB => fp_spw_dout_n(i), I => gnd);
      txs_pad : OBUFDS
        port map (O => fp_spw_sout_p(i), OB => fp_spw_sout_n(i), I => gnd);
    end generate fp;  
    
  end generate nospwrtr_pads;
-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
    generic map(
      msg1    => "NOELV/GRLIB VCU118 Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
      );
-- pragma translate_on

end rtl;
