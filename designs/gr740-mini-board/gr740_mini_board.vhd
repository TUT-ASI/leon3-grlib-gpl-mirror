------------------------------------------------------------------------------
--  LEON3 Demonstration design
--  Copyright (C) 2022 Cobham Gaisler
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
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;
use techmap.allclkgen.all;
library gaisler;
use gaisler.memctrl.all;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.jtag.all;
use gaisler.spi.all;
use gaisler.i2c.all;
use gaisler.subsys.all;
use gaisler.pci.all;
use gaisler.spacewire.all;
use gaisler.nandfctrl2_pkg.all;
use gaisler.net.all;
use gaisler.hssl.all;
use gaisler.grlsedc_pkg.all;
use gaisler.grdmac2_pkg.all;
library esa;
use esa.memoryctrl.all;
use esa.pcicomp.all;

--pragma translate_off
use gaisler.sim.all;
library nexus_sim;
use nexus_sim.all;
--pragma translate_on
use work.config.all;

entity gr740_mini_board is
  generic (
    fabtech           : integer := CFG_FABTECH;
    memtech           : integer := CFG_MEMTECH;
    padtech           : integer := CFG_PADTECH;
    ncpu              : integer := CFG_NCPU;
    disas             : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart           : integer := CFG_DUART;   -- Print UART on console
    pclow             : integer := CFG_PCLOW;
    simulation        : boolean := CFG_SIMULATION;
    ramfile           : string  := "ram.srec");
  port (
    fpga_pci_clk      : in    std_ulogic;
    clk_in_125mhz     : in    std_ulogic;
    -- Enable-signals for SerDes reference clocks
    en_sdq0_refclk    : out   std_logic; -- Enables SDQ1 external oscillator. active high 3.3V
    en_sdq1_refclk    : out   std_logic; -- Enables SDQ0 external oscillator. active high 3.3V.
    -- Reset input
    gsrn              : in    std_ulogic;
    -- SPI memory
    spi_mclk          : out   std_logic;
    dq0_mosi          : inout std_logic;
    dq1_miso          : inout std_logic;
    csspin            : out   std_logic;
    dq2               : inout std_logic;
    dq3               : inout std_logic;
    -- UART
    debug_uart_rx     : in std_logic;
    debug_uart_tx     : out std_logic;
    -- PCI
    pci_ad            : inout std_logic_vector(31 downto 0);
    pci_cbe           : inout std_logic_vector(3 downto 0);
    pci_par           : inout std_ulogic;
    pci_frame         : inout std_ulogic;
    pci_trdy          : inout std_ulogic;
    pci_irdy          : inout std_ulogic;
    pci_stop          : inout std_ulogic;
    pci_devsel        : inout std_ulogic;
    pci_perr          : inout std_ulogic;
    pci_serr          : inout std_ulogic;  -- open drain output
    pci_int           : inout std_logic_vector(0 downto 0);
    pci_idsel_config  : out std_ulogic;
    pci_host_config   : out std_ulogic;
    pci_66_config	    : out std_ulogic;
    -- PCI arbiter 
    pci_arb_req       : in std_logic_vector(0 to 1);
    pci_arb_gnt       : out std_logic_vector(0 to 1);
    -- DDR3 memory
    ddr3_dq           : inout std_logic_vector(7 downto 0);
    ddr3_dqs          : inout std_logic_vector(0 downto 0);
    ddr3_dm           : out   std_logic_vector(0 downto 0);
    ddr3_addr         : out   std_logic_vector(15 downto 0);
    ddr3_ba           : out   std_logic_vector(2 downto 0);
    ddr3_cke          : out   std_logic_vector(0 downto 0);
    ddr3_ck           : out   std_logic_vector(0 downto 0);
    ddr3_csn          : out   std_logic_vector(0 downto 0);
    ddr3_odt          : out   std_logic_vector(0 downto 0);
    ddr3_casn         : out   std_logic;
    ddr3_rasn         : out   std_logic;
    ddr3_wen          : out   std_logic;
    ddr3_resetn       : out   std_logic;
    -- Ethernet
    eth_mdio          : inout std_logic;
    eth_mdc           : out std_ulogic;
    eth_gtxclk        : out   std_logic;
    eth_txclk         : in    std_ulogic;
    eth_rxclk         : in    std_ulogic;
    eth_rxd           : in    std_logic_vector(7 downto 0);
    eth_rxdv          : in    std_ulogic;
    eth_rxer          : in    std_ulogic;
    eth_col           : in    std_ulogic;
    eth_crs           : in    std_ulogic;
    eth_txd           : out   std_logic_vector(7 downto 0);
    eth_txen          : out   std_ulogic;
    eth_txer          : out   std_ulogic;
    eth0_mdc	        : in    std_ulogic;
    eth0_mdint        : in    std_ulogic;
   	eth0_mdio	        : in    std_ulogic;
   -- SpaceWire GR740   
    spw_din_gr740_4   : in    std_logic;
    spw_sin_gr740_4   : in    std_logic;
    spw_dout_gr740_4  : out   std_logic;
    spw_sout_gr740_4  : out   std_logic;
    spw_din_gr740_5   : in    std_logic;
    spw_sin_gr740_5   : in    std_logic;
    spw_dout_gr740_5  : out   std_logic;
    spw_sout_gr740_5  : out   std_logic;
    spw_din_gr740_6   : in    std_logic;
    spw_sin_gr740_6   : in    std_logic;
    spw_dout_gr740_6  : out   std_logic;
    spw_sout_gr740_6  : out   std_logic; 
    spw_din_gr740_7   : in    std_logic;
    spw_sin_gr740_7   : in    std_logic;
    spw_dout_gr740_7  : out   std_logic;
    spw_sout_gr740_7  : out   std_logic; 
    -- SpaceWire Mezzanine
    spw_din_mez_1     : in    std_logic;
    spw_sin_mez_1     : in    std_logic;
    spw_dout_mez_1    : out   std_logic;
    spw_sout_mez_1    : out   std_logic;  
    spw_din_mez_2     : in    std_logic;
    spw_sin_mez_2     : in    std_logic;
    spw_dout_mez_2    : out   std_logic;
    spw_sout_mez_2    : out   std_logic;
    spw_din_mez_3     : in    std_logic;
    spw_sin_mez_3     : in    std_logic;
    spw_dout_mez_3    : out   std_logic;
    spw_sout_mez_3    : out   std_logic;  
    spw_din_mez_4     : in    std_logic;
    spw_sin_mez_4     : in    std_logic;
    spw_dout_mez_4    : out   std_logic;
    spw_sout_mez_4    : out   std_logic;           
    -- GPIO 
    fpga_led          : inout std_logic_vector(3 downto 0);
    gr740_gpio2       : inout std_logic_vector(4 downto 0);   
    -- I2C FMC
    i2c_sda_fmc       : inout std_logic;
    i2c_scl_fmc       : out   std_logic;
    -- nandflash 
    Ale_0             : out   std_logic;
    Ale_1             : out   std_logic;
    Ce0_0_n           : out   std_logic;
    Ce1_0_n           : out   std_logic;
    Ce0_1_n           : out   std_logic;
    Ce1_1_n           : out   std_logic;
    Cle_0             : out   std_logic;
    Cle_1             : out   std_logic;
    Dq_Io_0           : inout std_logic_vector(7 downto 0);
    Dq_Io_1           : inout std_logic_vector(7 downto 0);
    Dqs_t_0           : inout std_logic;
    Dqs_t_1           : inout std_logic;   
    Wr_Re_0_n         : out   std_logic;
    Wr_Re_1_n         : out   std_logic;
    Clk_We_0_n        : out   std_logic;
    Clk_We_1_n        : out   std_logic;
    Wp_0_n            : out   std_logic;
    Wp_1_n            : out   std_logic;
    Rb0_0_n           : in    std_logic;
    Rb1_0_n           : in    std_logic;
    Rb0_1_n           : in    std_logic;
    Rb1_1_n           : in    std_logic;
    -- Built-in JTAG interface
    -- No location constraint is necessary on these pins, though it is
    -- recommended for clarity. However, a clock constraint must be applied to
    -- tck. Note that if the Reveal debug inserter is to be used then these
    -- ports must be commented out and the AHBJTAG instantiation removed.
    tck               : in    std_logic;
    tms               : in    std_logic;
    tdi               : in    std_logic;
    tdo               : out   std_logic
    -- Signals for SerDes simulation. Not needed for synthesis since
    -- location constraints are specified during SerDes IP configuration.
    --pragma translate_off
    ;
    -- Quad-local reference clock
    SDQ0_REFCLKP     : in    std_logic; -- connects to SDQ1_REFCLK on board.
    SDQ0_REFCLKN     : in    std_logic; -- HCSL, 156.25MHz. Enabled by en_sdq0
    -- channel 0
    SD0_TXDP         : out   std_logic; -- FMC_FPGA.SD.DP3_C2M_P/N
    SD0_TXDN         : out   std_logic;
    SD0_RXDP         : in    std_logic; -- FMC_FPGA.SD.DP3_M2C_P/N
    SD0_RXDN         : in    std_logic;
    -- channel 2
    SD2_TXDP         : out   std_logic; -- FMC_FPGA.SD.DP1_C2M_P/N
    SD2_TXDN         : out   std_logic;
    SD2_RXDP         : in    std_logic; -- FMC_FPGA.SD.DP1_M2C_P/N
    SD2_RXDN         : in    std_logic;
    -- channels 1 and 3 not used on this board
    -- Distributable reference clock from quad 0
    SD_EXT0_REFCLKP  : in    std_logic; -- FMC_FPGA_SD.GBTCLK1_M2C_P/N
    SD_EXT0_REFCLKN  : in    std_logic; -- driven by FMC
    -- Quad-local reference clock
    SDQ1_REFCLKP     : in    std_logic; -- connects to SDQ0_REFCLK on board.
    SDQ1_REFCLKN     : in    std_logic; -- HCSL, 100.00Hz. Enabled by en_sdq1
    -- channel 6
    SD6_TXDP         : out   std_logic; -- FMC_FPGA.SD.DP2_C2M_P/N
    SD6_TXDN         : out   std_logic;
    SD6_RXDP         : in    std_logic; -- FMC_FPGA.SD.DP2_M2C_P/N
    SD6_RXDN         : in    std_logic;
    -- channel 7
    SD7_TXDP         : out   std_logic; -- FMC_FPGA.SD.DP0_C2M_P/N
    SD7_TXDN         : out   std_logic;
    SD7_RXDP         : in    std_logic; -- FMC_FPGA.SD.DP0_M2C_P/N
    SD7_RXDN         : in    std_logic;
    -- channels 1 and 3 not used on this board
    -- Distributable reference clock from quad 0
    SD_EXT1_REFCLKP  : in    std_logic; -- FMC_FPGA_SD.GBTCLK1_M2C_P/N
    SD_EXT1_REFCLKN  : in    std_logic -- driven by FMC
    --pragma translate_on
    );
end entity gr740_mini_board;


architecture rtl of gr740_mini_board is

  signal vcc : std_logic;
  signal gnd : std_logic;
  constant OEPOL        : integer := padoen_polarity(padtech);
  signal trigger : std_logic_vector(63 downto 0);
  -- AMBA bus signals
  signal apbi_0   : apb_slv_in_type;
  signal apbo_0   : apb_slv_out_vector  := (others => apb_none);
  signal apbi_1 : apb_slv_in_type;
  signal apbo_1 : apb_slv_out_vector  := (others => apb_none);
  signal ahbsi  : ahb_slv_in_type;
  signal ahbso  : ahb_slv_out_vector  := (others => ahbs_none);
  signal ahbmi  : ahb_mst_in_type;
  signal ahbmo  : ahb_mst_out_vector  := (others => ahbm_none);
  signal bus_ddr_ahbsi : ahb_slv_in_type;
  signal bus_ddr_ahbso : ahb_slv_out_vector := (others => ahbs_none);
  signal bus_ddr_ahbmi : ahb_mst_in_type;
  signal bus_ddr_ahbmo : ahb_mst_out_vector := (others => ahbm_none);
  signal ahbmi_hssl   : ahb_mst_in_vector_type(hmidx_grhssl+CFG_HSSL_NUM*CFG_GRHSSL_DMA downto hmidx_grhssl);
  signal ahbmo_hssl   : ahb_mst_out_vector_type (hmidx_grhssl+CFG_HSSL_NUM*CFG_GRHSSL_DMA downto hmidx_grhssl);

  -- signals 
  signal cgi : clkgen_in_type;
  signal cgo : clkgen_out_type;
  signal aramo : ahbram_out_type;
  signal stati : ahbstat_in_type;
  signal dui, u1i : uart_in_type;
  signal duo, u1o : uart_out_type;
  signal irqi : irq_in_vector(0 to 0);
  signal irqo : irq_out_vector(0 to 0);
  signal gpti : gptimer_in_type;
  signal clkm, rstn, clk200, clk100 : std_ulogic;
  signal spmi : spimctrl_in_type;
  signal spmo : spimctrl_out_type;
  signal spim_rst : std_ulogic;
  signal i2ci : i2c_in_vector_type(0 to 0);
  signal i2co : i2c_out_vector_type(0 to 0);
  signal rstraw              : std_logic;
  signal lock                : std_logic;
  signal ddr_lock            : std_logic;
  signal gpio0i  : gpio_in_type;
  signal gpio0o  : gpio_out_type;
  -- Spacewire router
  signal spwr_ahbmi  : spw_ahb_mst_in_vector(0 to CFG_SPW_AMBAPORTS-1);
  signal spwr_ahbmo  : spw_ahb_mst_out_vector(0 to CFG_SPW_AMBAPORTS-1);
  signal spwr_apbo   : spw_apb_slv_out_vector(0 to CFG_SPW_AMBAPORTS-1);
  signal spwri       : grspw_router_in_type;
  signal spwro       : grspw_router_out_type;
  signal spw_rxclki  : std_logic_vector(CFG_SPW_SPWPORTS-1 downto 0);
  signal spw_rxclkin : std_ulogic;
  signal spw_txclk   : std_logic_vector(CFG_SPW_SPWPORTS-1 downto 0);
  signal spw_txclkn  : std_logic_vector(CFG_SPW_SPWPORTS-1 downto 0);
  signal spw_rxclko  : std_logic_vector(CFG_SPW_SPWPORTS-1 downto 0);
  signal dtmp        : std_logic_vector(CFG_SPW_SPWPORTS-1 downto 0);
  signal stmp        : std_logic_vector(CFG_SPW_SPWPORTS-1 downto 0);
  signal di          : std_logic_vector(CFG_SPW_SPWPORTS*2-1 downto 0);
  signal dvi         : std_logic_vector(CFG_SPW_SPWPORTS*2-1 downto 0);
  signal dconnect    : std_logic_vector(CFG_SPW_SPWPORTS*2-1 downto 0);
  signal dconnect2   : std_logic_vector(CFG_SPW_SPWPORTS*2-1 downto 0);
  signal dconnect3   : std_logic_vector(CFG_SPW_SPWPORTS*2-1 downto 0);
  signal do          : std_logic_vector(CFG_SPW_SPWPORTS*2-1 downto 0);
  signal so          : std_logic_vector(CFG_SPW_SPWPORTS*2-1 downto 0);
  -- SpaceWire TX CLK frequency in KHz
  constant SPW_CLKFREQ : integer := 200000;
  constant SPW_CLKDIV10 : std_logic_vector(7 downto 0) := conv_std_logic_vector(SPW_CLKFREQ/10000 - 1, 8);
  -- spacefibre
  signal hssl_clk        : std_ulogic_vector(0 to CFG_HSSL_NUM-1);
  signal hssl_rstn       : std_ulogic_vector(0 to CFG_HSSL_NUM-1);
  signal hssli           : grhssl_in_type_vector(0 to CFG_HSSL_NUM-1);
  signal hsslo           : grhssl_out_type_vector(0 to CFG_HSSL_NUM-1);
  type hssl_cnt_vector is array (natural range <>) of std_logic_vector(9 downto 0);
  signal hssl_cnt, hssl_cnt_in : hssl_cnt_vector(0 to CFG_HSSL_NUM-1);
  type extvc_in_vct_type  is array (natural range <>) of extvc_in_arr_type;
  type extvc_out_vct_type is array (natural range <>) of extvc_out_arr_type;
  type extbc_in_vct_type  is array (natural range <>) of extbc_in_type;
  type extbc_out_vct_type is array (natural range <>) of extbc_out_type;
  signal hssl_extvci  : extvc_in_vct_type(CFG_HSSL_NUM-1 downto 0);
  signal hssl_extvco  : extvc_out_vct_type(CFG_HSSL_NUM-1 downto 0);
  signal hssl_extbci  : extbc_in_vct_type(CFG_HSSL_NUM-1 downto 0);
  signal hssl_extbco  : extbc_out_vct_type(CFG_HSSL_NUM-1 downto 0);
  signal spfispwbi    : spfi_spwdata_br_in_arr_type(CFG_HSSL_NUM-1 downto 0);
  signal spfispwbo    : spfi_spwdata_br_out_arr_type(CFG_HSSL_NUM-1 downto 0);
  signal bctcbi       : spfi_spwtc_br_in_arr_type(1 downto 0);
  signal bctcbo       : spfi_spwtc_br_out_arr_type(1 downto 0);
  -- PCI 
  signal pcii        : pci_in_type;
  signal pcio        : pci_out_type;
  signal pci_lock    : std_logic;
  signal pciclk      : std_ulogic;
  signal pci_host    : std_logic;
  signal pci_66      : std_logic           := '1'; -- dummy signal
  signal pci_dirq    : std_logic_vector(3 downto 0);
  signal pci_rst     : std_logic;
  signal pci_idsel   : std_logic;
  signal pci_req     : std_logic;
  signal pci_gnt     : std_logic;
  -- Dummy signals to prevent conflicting drivers when target/master/dma is disabled
  -- This is necessary because grpci2 drives its output ports with ahbm_none when
  -- disabled. And because we use dynamic master numbering.
  signal pci_tahbmo  : ahb_mst_out_type; -- PCI target AHB master
  signal pci_dahbmo  : ahb_mst_out_type; -- PCI DMA AHB master
  signal pci_ahbso   : ahb_slv_out_type; -- PCI initiator(master) AHB slave
  -- Note: The PCI initiator/master is controlled by an AHB slave interface
  --       The PCI target/slave controls an AHB master interface
  --       The PCI DMA interface uses a separate AHB master, but the same PCI initiator
  -- The APB interface is always enabled.
  -- PCI arbiter
  signal pci_arb_req_n, pci_arb_gnt_n   : std_logic_vector(0 to 1);
  -- ethernet
  signal ethi1 : eth_in_type;
  signal etho1 : eth_out_type;
  signal mdio_clk, mdio_i, mdio_o, mdio_oe  :  std_ulogic; 
  -- Nandflash
  signal nf2_to_phy_in : nf2_to_phy_out_type;
  signal nf2_to_phy_out : nf2_to_phy_in_type;
  signal phyi : from_nandf_pads_type;
  signal phyo : to_nandf_pads_type;
  -- DDR3 MC
  constant addr_w : integer := 30;
  constant core_data_w : integer := 64;
  constant device_data_w : integer := 8;
  constant data_mask_w : integer := core_data_w/8;

  signal mem_rst_n        : std_logic;
  signal init_start       : std_logic;
  signal cmd              : std_logic_vector(3 downto 0);
  signal addr             : std_logic_vector(addr_w - 1  downto 0);
  signal cmd_burst_cnt    : std_logic_vector(4 downto 0);
  signal cmd_valid        : std_logic;
  signal write_data       : std_logic_vector(core_data_w - 1 downto 0);
  signal data_mask        : std_logic_vector(data_mask_w - 1 downto 0);
  signal cmd_rdy          : std_logic;
  signal datain_rdy       : std_logic;
  signal init_done_core   : std_logic;
  signal rt_err           : std_logic;
  signal wl_err           : std_logic;
  signal read_data        : std_logic_vector(core_data_w - 1 downto 0);
  signal read_data_valid  : std_logic;
  signal sclk             : std_logic;
  signal clocking_good    : std_logic;

  attribute keep                     : boolean;
  attribute keep of lock             : signal is true;
  attribute keep of clkm             : signal is true;

  type cnt16_vector is array (natural range <>) of std_logic_vector(15 downto 0);
  type cnt6_vector is array (natural range <>) of std_logic_vector(5 downto 0);

  type serdes_clkconf_in_type is record
    cnt : cnt16_vector(0 to 3);
    hssl_cnt : cnt6_vector(0 to 3);
  end record;

  type serdes_clkconf_out_type is record
    rstin : std_logic;
    en_sdq1_refclk  : std_logic;
    sdq1_use_refmux : std_logic;
    sdq1_extsel  : std_logic;
    en_sdq0_refclk  : std_logic;
    sdq0_use_refmux : std_logic;
    sdq0_extsel  : std_logic;
  end record;

  signal serdes_clkconf_out : serdes_clkconf_out_type;
  signal serdes_clkconf_in, serdes_clkconf_inn : serdes_clkconf_in_type;
  signal gpreg_in, gpreg_res, gpreg_out : std_logic_vector(5*16-1 downto 0);

  component GSR
    GENERIC (
      SYNCMODE : String := "ASYNC");
    PORT(
      GSR_N : IN std_logic;
      CLK : IN std_logic);
  end component;

  component pll_125i_50o is
    port(
      clki_i   : in  std_logic;
      rstn_i   : in  std_logic;
      clkop_o  : out std_logic;
      clkos_o  : out std_logic;
      clkos2_o : out std_logic;
      lock_o   : out std_logic);
  end component;
  
  component DIFFCLKIO is
   generic (
     TERM_RD   : string := "ENABLED";
     WEAK_BIAS : string := "DISABLED");
   port (
     CLKIN0_P : in  std_logic;
     CLKIN0_N : in  std_logic;
     CLKIN1_P : in  std_logic;
     CLKIN1_N : in  std_logic;
     CLKOUT0  : out std_logic;
     CLKOUT1  : out std_logic);
  end component;

  component lattice_ddr3c is
    port(
      clk_i: in std_logic;
      rst_n_i: in std_logic;
      mem_rst_n_i: in std_logic;
      init_start_i: in std_logic;
      cmd_i: in std_logic_vector(3 downto 0);
      addr_i: in std_logic_vector(29 downto 0);
      cmd_burst_cnt_i: in std_logic_vector(4 downto 0);
      cmd_valid_i: in std_logic;
      write_data_i: in std_logic_vector(63 downto 0);
      data_mask_i: in std_logic_vector(7 downto 0);
      cmd_rdy_o: out std_logic;
      datain_rdy_o: out std_logic;
      init_done_o: out std_logic;
      rt_err_o: out std_logic;
      wl_err_o: out std_logic;
      read_data_o: out std_logic_vector(63 downto 0);
      read_data_valid_o: out std_logic;
      sclk_o: out std_logic;
      clocking_good_o: out std_logic;
      em_ddr_data_io: inout std_logic_vector(7 downto 0);
      em_ddr_reset_n_o: out std_logic;
      em_ddr_dqs_io: inout std_logic_vector(0 to 0);
      em_ddr_dm_o: out std_logic_vector(0 to 0);
      em_ddr_clk_o: out std_logic_vector(0 to 0);
      em_ddr_cke_o: out std_logic_vector(0 to 0);
      em_ddr_ras_n_o: out std_logic;
      em_ddr_cas_n_o: out std_logic;
      em_ddr_we_n_o: out std_logic;
      em_ddr_cs_n_o: out std_logic_vector(0 to 0);
      em_ddr_odt_o: out std_logic_vector(0 to 0);
      em_ddr_addr_o: out std_logic_vector(15 downto 0);
      em_ddr_ba_o: out std_logic_vector(2 downto 0));
  end component;

  component ahb2lattice_ddr3_mc is
    generic (
      hindex : integer := 0;
      haddr  : integer := 16#400#;
      hmask  : integer := 16#c00#;
      addr_w : integer := addr_w;
      core_data_w : integer := 64);
    --  device_data_w : integer := 8);
    port(
      rstn : in std_logic;
      ahbsi : in  ahb_slv_in_type;
      ahbso : out ahb_slv_out_type;
      -- signals to ddr3_mc
      mem_rst_n_o : out std_logic;
      init_start_o : out std_logic;
      cmd_o : out std_logic_vector(3 downto 0);
      addr_o : out std_logic_vector(addr_w - 1 downto 0);
      cmd_burst_cnt_o : out std_logic_vector(4 downto 0);
      cmd_valid_o : out std_logic;
      write_data_o : out std_logic_vector(core_data_w - 1 downto 0);
      data_mask_o : out std_logic_vector(core_data_w/8 - 1 downto 0);
      -- signals from ddr3_mc
      cmd_rdy_i         : in std_logic;
      datain_rdy_i      : in std_logic;
      init_done_i       : in std_logic;
      rt_err_i          : in std_logic;
      wl_err_i          : in std_logic;
      read_data_i       : in std_logic_vector(core_data_w - 1 downto 0);
      read_data_valid_i : in std_logic;
      sclk_i            : in std_logic;
      clocking_good_i   : in std_logic;
      -- Debug signals
      init_done : out std_logic;
      init_err  : out std_logic);
  end component;
  
begin

----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------

  vcc <= '1';
  gnd <= '0';

  pci_rst <= rstn;
  pciclk <= fpga_pci_clk;

  rst0 : gaisler.misc.rstgen generic map (acthigh => 0)
    port map (gsrn, clkm, lock, rstn, rstraw);
  lock <= cgo.clklock;

  --this instance is needed to provide the general reset in a lattice simulation environment
  GSR_INST: GSR
    port map (GSR_N => gsrn, CLK => clkm);

 clkgen_ip_0 : pll_125i_50o
   port map(
     clki_i   => clk_in_125mhz,
     rstn_i   => gsrn,
     clkop_o  => clkm,     
     clkos_o  => clk100,  
     clkos2_o => clk200,
     lock_o   => cgo.clklock);

  ----------------------------------------------------------------------
  ---  AHB CONTROLLER  -------------------------------------------------
  ----------------------------------------------------------------------

  ahb0 : ahbctrl
    generic map (ioen => 1, nahbm => maxahbm , nahbs => maxahbs, ioaddr => CFG_AHBIO, split => CFG_SPLIT, 
      fpnpen => CFG_FPNPEN, devid => GAISLER_GR740MINI, ahbtrace => CFG_AHB_DTRACE)
    port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);
 

  ahbctl_clock : if CFG_DDR3 + CFG_EN_BM1 /= 0 generate -- AHB status register
    ahb_int : ahbctrl                -- AHB arbiter/multiplexer
      generic map (defmast => 0, split => 0,
                 rrobin => 1, ioaddr => CFG_AHBCTL_DDR3_AHBIO, ioen => 0,
                 nahbm => (1*CFG_EN_BM1 + 1), nahbs => 1, fpnpen => 1)
      port map (rstn, sclk, bus_ddr_ahbmi, bus_ddr_ahbmo, bus_ddr_ahbsi, bus_ddr_ahbso);

    -- ahb2ahb bridge used for handling different clocks
    ahb2ahb0: ahb2ahb
      generic map ( memtech  => nexus,
        hsindex     => hsidx_ahb2,
        hmindex     => 0,  
        dir         => 1,
        ffact       => 2,
        slv         => 1,
        pfen        => 1,
        wburst      => 2,--BURSTLEN,
        iburst      => 4,--CFG_ILINE,
        rburst      => 4,--BURSTLEN,
        irqsync     => 0,
        bar0        => ahb2ahb_membar(CFG_DDR3_ADDR, '1', '1', 16#E00#),
        bar1        => ahb2ahb_membar(CFG_AHBCTL_DDR3_AHBIO, '0', '0', 16#FFF#),
        sbus        => 0,
        mbus        => 1,
        ioarea      => CFG_AHBCTL_DDR3_AHBIO,
        ibrsten     => 0,
        lckdac      => 2,
        slvmaccsz   => 32,
        mstmaccsz   => 32,
        rdcomb      => 0,
        wrcomb      => 0,
        combmask    => 0,
        allbrst     => 0,
        ifctrlen    => 0,
        fcfs        => 0, -- FCFS requires SPLIT support
        fcfsmtech   => 0,
        scantest    => 0,
        split       => 0,
        pipe        => 128)
    port map (rstn, sclk, clkm, ahbsi, ahbso(hsidx_ahb2), bus_ddr_ahbmi,
      bus_ddr_ahbmo(0), bus_ddr_ahbso, ahb2ahb_ctrl_none, open, ahb2ahb_ifctrl_none);
  end generate; 
  ----------------------------------------------------------------------
  ---  DMA CONTROLLER --------------------------------------------------
  ----------------------------------------------------------------------

    dmactrl : if CFG_DMACTRL = 1 generate -- AHB status register
      u2 : grdmac2_ahb
        generic map (tech => nexus, pindex => pidx_dmactrl, 
                     paddr => paddr_dmactrl,pmask => 16#FFE#, pirq => 0, dbits => 32, en_bm1 => CFG_EN_BM1, 
                     hindex0 => hmidx_dmactrl, hindex1 => 1*CFG_DMACTRL, max_burst_length  => 4,
                     ft => 0, abits => 4, en_timer => 1)
        port map (rstn, clkm, apbi_0, apbo_0(pidx_dmactrl), ahbmi, ahbmo(hmidx_dmactrl), 
        bus_ddr_ahbmi, bus_ddr_ahbmo(1*CFG_DMACTRL), trigger(63 downto 0));
    end generate;

  -----------------------------------------------------------------------
  ---  AHBSTAT  ---------------------------------------------------------
  -----------------------------------------------------------------------

  ahbs : if CFG_AHBSTAT = 1 generate -- AHB status register
    ahbstat0 : ahbstat
      generic map (pindex => pidx_ahbstat, paddr  => paddr_ahbstat,
                  pirq => AHBSTAT_PIRQ, nftslv => CFG_AHBSTATN, ver => 1)
      port map (rstn, clkm, ahbmi, ahbsi, stati, apbi_0, apbo_0(pidx_ahbstat));
  end generate;

  ----------------------------------------------------------------------
  ---  Debug UART  -----------------------------------------------------
  ----------------------------------------------------------------------

  dcomgen0 : if CFG_AHB_UART = 1 generate
    dcom0: ahbuart             
      generic map (hindex => hmidx_ahbuart, pindex => pidx_ahbuart, paddr => paddr_ahbuart)
      port map (rstn, clkm, dui, duo, apbi_0, apbo_0(pidx_ahbuart), ahbmi, ahbmo(hmidx_ahbuart));
      dui.rxd    <= debug_uart_rx;
      dui.ctsn   <= '0';
      dui.extclk <= '0';
      debug_uart_tx    <= duo.txd;
  end generate;

  nodcom0 : if CFG_AHB_UART = 0 generate
    duo.txd <= '0'; duo.rtsn <= '1';
  end generate;

  ----------------------------------------------------------------------
  ---  Debug JTAG ------------------------------------------------------
  ----------------------------------------------------------------------
  
  dcomgen1 : if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => hmidx_ahbjtag)
      port map(rstn, clkm, tck, tms, tdi, tdo, ahbmi, ahbmo(hmidx_ahbjtag),
               open, open, open, open, open, open, open, gnd);
  end generate;
  
  ----------------------------------------------------------------------
  ---  Memory controllers ----------------------------------------------
  ----------------------------------------------------------------------

  -- SPI memory controller (boot memory)
  spi_gen: if CFG_SPIMCTRL = 1 generate
    spimctrl0 : spimctrl
      generic map (hindex => hsidx_spimctrl, hirq => SPIM_PIRQ, faddr => CFG_SPIM_ADDR, fmask => 16#fc0#, --16 MByte
                   ioaddr => CFG_SPIM_IOADDR, iomask => 16#fff#, spliten => CFG_SPLIT,
                  sdcard => CFG_SPIMCTRL_SDCARD, readcmd => CFG_SPIMCTRL_READCMD,
                  dummybyte => CFG_SPIMCTRL_DUMMYBYTE,
                  dualoutput => CFG_SPIMCTRL_DUALOUTPUT, scaler => CFG_SPIMCTRL_SCALER,
                  altscaler => CFG_SPIMCTRL_ASCALER, reconf => 1)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_spimctrl), spmi, spmo);

    spi_mosi_pad0 : iopad generic map (tech => padtech)
      port map (dq0_mosi, spmo.mosi, spmo.mosioen, spmi.mosi);
    spi_miso_pad0 : iopad generic map (tech => padtech)
      port map (dq1_miso, spmo.miso, spmo.misooen, spmi.miso);
    spi_slvsel0_pad0 : outpad generic map (tech => padtech)
      port map (csspin, spmo.csn);
    spi_clk_pad0 : outpad generic map (tech => padtech)
      port map (spi_mclk, spmo.sck);
    --for quad-mode
    spi_dq2_pad0: iopad generic map (tech => padtech)
      port map (dq2, spmo.io2, spmo.iooen, spmi.io2);
    spi_dq3_pad0: iopad generic map (tech => padtech)
      port map (dq3, spmo.io3, spmo.iooen, spmi.io3);
    spmi.cd <= '0';
  end generate;

  ddr3_gen : if CFG_DDR3 = 1 generate
    ahb2ddr: ahb2lattice_ddr3_mc
      generic map (
        hindex => 0, 
        haddr  => CFG_DDR3_ADDR, 
        hmask  => 16#E00#, 
        addr_w => addr_w,
        core_data_w => core_data_w)--,
      --  device_data_w => device_data_w)
      port map (
        rstn   => rstn,
        ahbsi  => bus_ddr_ahbsi,
        ahbso  => bus_ddr_ahbso(0),
        -- signals to ddr3_mc
        mem_rst_n_o => mem_rst_n,
        init_start_o => init_start,
        cmd_o => cmd,
        addr_o => addr,
        cmd_burst_cnt_o => cmd_burst_cnt,
        cmd_valid_o => cmd_valid,
        write_data_o =>  write_data,
        data_mask_o => data_mask,
        -- signals from ddr3_mc
        cmd_rdy_i         => cmd_rdy,
        datain_rdy_i      => datain_rdy,
        init_done_i       => init_done_core,
        rt_err_i          => rt_err,
        wl_err_i          => wl_err,
        read_data_i       => read_data,
        read_data_valid_i => read_data_valid,
        sclk_i            => sclk,
        clocking_good_i   => clocking_good,
        -- Debug signals
        init_done => open,
        init_err  => open);

    -- Generated DDR3 memory controller. IP from Lattice.
    -- Can be programmed into hardware with an evaluation license, but will
    -- only run for 2-4 hours (enforced using encrypted bitstream commands an
    -- a hardware timer inside the FPGA).

    ddr3c : lattice_ddr3c
      port map(
        -- Inputs from core
        clk_i             => clk100,
        rst_n_i           => gsrn,-- GSRN
        mem_rst_n_i       => mem_rst_n,
        init_start_i      => init_start,
        cmd_i             => cmd,
        addr_i            => addr,
        cmd_burst_cnt_i   => cmd_burst_cnt,
        cmd_valid_i       => cmd_valid,
        write_data_i      => write_data,
        data_mask_i       => data_mask,
        -- Outputs to core
        cmd_rdy_o         => cmd_rdy,
        datain_rdy_o      => datain_rdy,
        init_done_o       => init_done_core,
        rt_err_o          => rt_err,
        wl_err_o          => wl_err,
        read_data_o       => read_data,
        read_data_valid_o => read_data_valid,
        sclk_o            => sclk,
        clocking_good_o   => clocking_good,
        -- Signals to PCB
        em_ddr_data_io    => ddr3_dq,
        em_ddr_reset_n_o  => ddr3_resetn,
        em_ddr_dqs_io     => ddr3_dqs,
        em_ddr_dm_o       => ddr3_dm,
        em_ddr_clk_o      => ddr3_ck,
        em_ddr_cke_o      => ddr3_cke,
        em_ddr_ras_n_o    => ddr3_rasn,
        em_ddr_cas_n_o    => ddr3_casn,
        em_ddr_we_n_o     => ddr3_wen,
        em_ddr_cs_n_o     => ddr3_csn,
        em_ddr_odt_o      => ddr3_odt,
        em_ddr_addr_o     => ddr3_addr,
        em_ddr_ba_o       => ddr3_ba);
  end generate;
       
  -- NAND Flash memory controller 
  nandfctrl0 : if CFG_NANDFCTRL2_EN = 1 generate 
    nand0 : nandfctrl2 generic map(
      hindex => hmidx_nandfctrl2,
      pindex => pidx_nandfctrl2,
      paddr => paddr_nandfctrl2,
      pirq => NAND_PIRQ,
      nrofce => 4, -- CoS Nandflash setting
      nrofch => 2, -- CoS Nandflash setting
      nrofrb => 4, -- CoS Nandflash setting
      mem0_data => 16384,
      mem0_spare => 2208,
      mem0_ecc_sel => 0,
      ecc0_gfsize => 14,
      ecc0_chunk => 1024,
      ecc0_cap => 40,
      ecc1_cap => 0,
      ft => 1)
    port map(
      rstn => rstn,
      clk_sys => clkm,
      core_rstn => rstn, 
      clk_core => clkm,
      apbi => apbi_0,
      apbo => apbo_0(pidx_nandfctrl2),
      ahbmi => ahbmi,
      ahbmo => ahbmo(hmidx_nandfctrl2),
      phyi => nf2_to_phy_in,
      phyo => nf2_to_phy_out);

      -- NANDFCTRL2_PHY
    nand_phy : nandfctrl2_sdr_phy_generic generic map (
      nrofce => 4,
      nrofch => 2,
      nrofrb => 4,
      NROFSEFI => 1, 
      SCANTEST => 0, 
      SYNC_STAGES => 2)
    port map(
      rstn_core => rstn,
      clk_core => clkm,
      nf2i => nf2_to_phy_out,
      nf2o => nf2_to_phy_in,
      nandfi => phyi,
      nandfo => phyo);

     nandf_ce0_0 : outpad generic map (tech => padtech)
       port map (Ce0_0_n, phyo.ce_n (0) );
     nandf_ce0_1 : outpad generic map (tech => padtech)
       port map (Ce0_1_n, phyo.ce_n (1));
     nandf_ce1_0 : outpad generic map (tech => padtech)
       port map (Ce1_0_n, phyo.ce_n (2));
     nandf_ce1_1 : outpad generic map (tech => padtech)
       port map (Ce1_1_n, phyo.ce_n (3));
     nandf_rb0_0 : inpad generic map (tech => padtech)
       port map (Rb0_0_n, phyi.rb_n (0) );
     nandf_rb1_0 : inpad generic map (tech => padtech)
       port map (Rb0_1_n, phyi.rb_n (1) );
     nandf_rb0_1 : inpad generic map (tech => padtech)
       port map (Rb1_0_n, phyi.rb_n (2) );
     nandf_rb1_1 : inpad generic map (tech => padtech)
       port map (Rb1_1_n, phyi.rb_n (3) );
     nandf_d_0 : iopadv generic map (tech => padtech, width => 8)
       port map (Dq_Io_0, phyo.dq (0), phyo.dq_oe (0), phyi.dq (0)); 
     nandf_dqs_0_iopad : iopad generic map (tech => padtech)
       port map (Dqs_t_0, phyo.dqs(0), phyo.dqs_oe(0), phyi.dqs(0));
     nandf_dqs_1_iopad : iopad generic map (tech => padtech)
       port map (Dqs_t_1, phyo.dqs(1), phyo.dqs_oe(1), phyi.dqs(1));
     nandf_we_0 : outpad generic map (tech => padtech)
       port map (Clk_We_0_n, phyo.we_n (0) );
     nandf_re_0 : outpad generic map (tech => padtech)
       port map (Wr_Re_0_n, phyo.re_n (0));
     nandf_cle_0 : outpad generic map (tech => padtech)
       port map (Cle_0, phyo.cle (0));
     nandf_ale_0 : outpad generic map (tech => padtech)
       port map (Ale_0, phyo.ale (0));
     nandf_wp_0 : outpad generic map (tech => padtech)
       port map (Wp_0_n, phyo.wp_n (0));
     nandf_d_1 : iopadv generic map (tech => padtech, width => 8)
       port map (Dq_Io_1, phyo.dq (1), phyo.dq_oe (1), phyi.dq (1));
     nandf_we_1 : outpad generic map (tech => padtech)
       port map (Clk_We_1_n, phyo.we_n (1) );
     nandf_re_1 : outpad generic map (tech => padtech)
       port map (Wr_Re_1_n, phyo.re_n (1) );
     nandf_cle_1 : outpad generic map (tech => padtech)
       port map (Cle_1, phyo.cle (1) );
     nandf_ale_1 : outpad generic map (tech => padtech)
       port map (Ale_1, phyo.ale (1) );
     nandf_wp_1 : outpad generic map (tech => padtech)
       port map (Wp_1_n, phyo.wp_n (1));
  end generate; 

  -- On-chip RAM (volatile memory)
  ocram : if CFG_FTAHBRAM_EN = 0 and CFG_AHBRAMEN = 1 and simulation = false generate
    ahbram0 : ahbram
      generic map (hindex => hsidx_ahbram, haddr => CFG_OC_RAM_ADDR, tech => CFG_MEMTECH,
                   kbytes => CFG_AHBRSZ, pipe => CFG_AHBRPIPE)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbram));
  end generate;

  ftocram : if CFG_FTAHBRAM_EN = 1 and simulation = false generate
    ftahbram0 : ftahbram
      generic map (
        hindex    => hsidx_ftahbram, haddr => CFG_OC_RAM_ADDR,
        tech      => CFG_MEMTECH, 
        kbytes    => CFG_FTAHBRAM_SZ,
        pindex    => pidx_ftahbram,  paddr => paddr_ftahbram,
        edacen    => CFG_FTAHBRAM_EDAC, autoscrub => CFG_FTAHBRAM_SCRU,
        errcnten  => CFG_FTAHBRAM_ECNT, cntbits   => CFG_FTAHBRAM_EBIT,
        ahbpipe   => CFG_FTAHBRAM_PIPE)
      port map (
        rst   => rstn,
        clk   => clkm,
        ahbsi => ahbsi,
        ahbso => ahbso(hsidx_ftahbram),
        apbi  => apbi_0,
        apbo  => apbo_0(pidx_ftahbram),
        aramo => aramo); 
  end generate;

  -- GRCSCRUB instantiation
  grcscrubgen : if CFG_GRCSCRUB = 1 generate
    grcscrub0 : grlsedc
      generic map (
        pindex   => pidx_grcscrub,
        paddr    => paddr_grcscrub,
        pmask    => 16#fff#)
      port map (
        clk       => clkm,
        rstn      => rstn,
        ext_rstn  => rstn,
        apbi      => apbi_0,
        apbo      => apbo_0(pidx_grcscrub)); 
  end generate;

  ---------------------------------------------------------------------
  ---   PCI   ---------------------------------------------------------
  ---------------------------------------------------------------------

  pci_66_config    <= '1'; -- 0 33 MHz operation, 1 66MHz  
  pci_dirq(3 downto 1) <= (others => '0');
  pci_dirq(0) <= orv(irqi(0).irl);

  pci_gen : if (CFG_GRPCI2_MASTER + CFG_GRPCI2_TARGET + CFG_GRPCI2_DMA)  /= 0  generate
    -- Sets configuration depending on which device that is host
    pci_gr740host : if CFG_FGPA_HOST = 0 generate -- GR740 is PCI host
      pci_host_config  <= '0';
      pci_idsel_config <= '0';
      pci_idsel <= pcii.ad(16);
    end generate;

    pci_fpgahost : if CFG_FGPA_HOST  /= 0 generate -- FPGA is PCI host
      pci_host_config  <= '1';
      pci_idsel_config <= pcii.ad(16);
      pci_idsel <= '0';
    end generate;

    pci0 : grpci2
      generic map (
        memtech => memtech,
        oepol => OEPOL,
        hmindex => hmidx_grpci2,
        hdmindex => hdmidx_grpci2,
        hsindex => hsidx_grpci2,
        haddr => CFG_GRPCI2_HADDR,
        hmask => 16#e00#, --512 Mbyte 
        ioaddr => CFG_GRPCI2_IOADDR,
        pindex => pidx_grpci2,
        paddr => paddr_grpci2,
        irq => PCI2_PIRQ, -- Interrupt line used by the core.
        irqmode => CFG_PCI2_IRQMODE,
        master => CFG_GRPCI2_MASTER,
        target => CFG_GRPCI2_TARGET,
        dma => CFG_GRPCI2_DMA,
        tracebuffer => CFG_GRPCI2_TRACE,
        vendorid => CFG_GRPCI2_VID,
        deviceid => CFG_GRPCI2_DID,
        classcode => CFG_GRPCI2_CLASS,
        cap_pointer => CFG_GRPCI2_CAP,
        ext_cap_pointer => CFG_GRPCI2_NCAP,
        iobase => CFG_AHBIO,
        extcfg => CFG_GRPCI2_EXTCFG,
        bar0 => CFG_GRPCI2_BAR0,
        bar0_map => CFG_PCI_BAR0_ADDR,
        bar1 => CFG_GRPCI2_BAR1,
        bar1_map => CFG_PCI_BAR1_ADDR, 
        bar2 => CFG_GRPCI2_BAR2,
        bar3 => CFG_GRPCI2_BAR3,
        bar4 => CFG_GRPCI2_BAR4,
        bar5 => CFG_GRPCI2_BAR5,
        fifo_depth => CFG_GRPCI2_FDEPTH,
        fifo_count => CFG_GRPCI2_FCOUNT,
        conv_endian => CFG_GRPCI2_ENDIAN,
        deviceirq => CFG_GRPCI2_DEVINT,
        deviceirqmask => CFG_GRPCI2_DEVINTMSK,
        hostirq => CFG_GRPCI2_HOSTINT,
        hostirqmask => CFG_GRPCI2_HOSTINTMSK,
        nsync => CFG_GRPCI2_NSYNC,
        hostrst => CFG_GRPCI2_HOSTTST,
        bypass => CFG_GRPCI2_BYPASS,
        FT => CFG_PCI2_FT)
      port map (
        rst => rstn,
        clk => clkm,
        pciclk => pciclk,
        dirq => pci_dirq, 
        pcii => pcii, pcio => pcio,
        apbi => apbi_0, apbo => apbo_0(pidx_grpci2),
        ahbsi => ahbsi, ahbso => pci_ahbso,
        ahbmi => ahbmi, ahbmo => pci_tahbmo,
        ahbdmi => ahbmi, ahbdmo => pci_dahbmo);
       -- There are additional ports
       -- When target/master/dma is disabled, the output signals for the corresponding
       -- AHB output port is driven to ahbm_none or ahbs_none by the GRPCI2. This
       -- is incompatible with the dynamic index generation used in this design so
       -- we have to use the pci_*ahb*o as intermediaries to avoid multiple drivers.

      pci_target_map : if CFG_GRPCI2_TARGET /= 0 generate
        ahbmo(hmidx_grpci2) <= pci_tahbmo;
      end generate;

      pci_master_map : if CFG_GRPCI2_MASTER /= 0 generate
        ahbso(hsidx_grpci2) <= pci_ahbso;
      end generate;

      pci_dma_map : if CFG_GRPCI2_DMA /= 0 generate
        ahbmo(hdmidx_grpci2) <= pci_dahbmo;
      end generate;
      
   pcipads0 : pcipads
     generic map (
		   padtech => padtech,
		   noreset => 1,   -- internally generated reset (not a pad)
		   oepol => OEPOL,
		   host => CFG_FGPA_HOST*2, -- 0: never host, 1: connect IO pad, 2: always host
		   int => 0,
		   no66 => 1, -- 0:  io pad, 1: force 33MHz 
		   onchipreqgnt => 1, -- 0: instantiate IO pads for gnt/req
		   drivereset => 0, -- unused because noreset=1
		   constidsel => 1, --  no IO pad for IDSEL
		   level => pci33, -- 3.3V levels
		   voltage => x33v,
		   nolock => 1, -- no pad for LOCK
		   singleint => 1)
     port map (
       pci_rst, pci_gnt, pci_idsel, pci_lock, pci_ad, pci_cbe,
       pci_frame, pci_irdy, pci_trdy, pci_devsel, pci_stop, pci_perr,
       pci_par, pci_req, pci_serr, pci_host, pci_66, pcii, pcio, pci_int);
  end generate;

	pcia0 : if CFG_PCI_ARB = 1 generate -- PCI arbiter
    pciarb0 : pciarb
      generic map (pindex => pidx_pciarb, paddr => paddr_pciarb,
                  apb_en => CFG_PCI_ARBAPB, nb_agents => CFG_PCI_ARB_NGNT )
      port map ( clk => pciclk, rst_n => pcii.rst,
           req_n => pci_arb_req_n, frame_n => pcii.frame,
           gnt_n => pci_arb_gnt_n, pclk => clkm,
           prst_n => rstn, apbi => apbi_0, apbo => apbo_0(pidx_pciarb));

      pgnt_pad : outpadv generic map (tech => padtech, width => 2)
        port map (pci_arb_gnt, pci_arb_gnt_n);
      preq_pad : inpadv generic map (tech => padtech, width => 2)
        port map (pci_arb_req, pci_arb_req_n);
  end generate;

  ----------------------------------------------------------------------
  --- SpaceWire Router -------------------------------------------------
  ----------------------------------------------------------------------

  spwrtr : if CFG_SPW_EN /= 0 generate

    -- SpaceWire Transmitter clock should be clocked at 100 MHz
    spw_txclk  <= (others => clk100);
    spw_txclkn <= (others => '0');

    -- rxclkin and nrxclki are unused
    spw_rxclkin <= '0';

    phy_loop : for i in 0 to CFG_SPW_SPWPORTS - 1 generate
      -- For self-clock implementations we reuse the strobe input, otherwise we
      -- sample with the txclk
      spw_rxclki(i) <= stmp(i) when CFG_SPW_INPUT_TYPE /= 3 else spw_txclk(i);

      -- GRSPW2 PHY
      spw_phy0 : grspw2_phy
        generic map (
          scantest     => 0,
          tech         => fabtech,
          input_type   => CFG_SPW_INPUT_TYPE,
          rxclkbuftype => 1)
        port map (
          rstn      => rstn,
          rxclki    => spw_rxclki(i),   -- Receiver Clock Input
          rxclkin   => spw_rxclkin,
          nrxclki   => spw_rxclkin,
          di        => dtmp(i),         -- SpaceWire Data Input (from Pads)
          si        => stmp(i),         -- SpaceWire Strobe Input (from Pads)
          do        => di(2*i+1 downto 2*i),        -- Recovered Data
          dov       => dvi(2*i+1 downto 2*i),       -- Data Valid
          dconnect  => dconnect(2*i+1 downto 2*i),  -- Disconnect
          dconnect2 => dconnect2(2*i+1 downto 2*i),
          dconnect3 => dconnect3(2*i+1 downto 2*i),
          rxclko    => spw_rxclko(i));    -- Receiver Clock Output
    end generate phy_loop;

    router0 : grspwrouterm
      generic map (
        input_type    => CFG_SPW_INPUT_TYPE,
        output_type   => CFG_SPW_OUTPUT_TYPE,
        rxtx_sameclk  => CFG_SPW_RXTX_SAMECLK,
        fifosize      => CFG_SPW_FIFOSIZE,
        tech          => CFG_SPW_TECH,
        scantest      => 0,
        techfifo      => CFG_SPW_TECHFIFO,
        ft            => CFG_SPW_FT,
        spwen         => 1,             -- Enable spacewire ports
        ambaen        => 1,             -- Enable AMBA interfaces
        fifoen        => CFG_SPW_SPFI_BR_EN,             -- Enable FIFO interfaces
        spwports      => CFG_SPW_SPWPORTS,
        ambaports     => CFG_SPW_AMBAPORTS,  -- Number of AMBA ports
        fifoports     => CFG_SPW_FIFOPORTS,  -- Number of FIFO ports
        rmap          => CFG_SPW_RMAP,
        rmapcrc       => CFG_SPW_RMAPCRC,
        fifosize2     => CFG_SPW_FIFOSIZE2,
        almostsize    => 1,             -- Only used for FIFO ports
        rxunaligned   => CFG_SPW_RXUNALIGNED,
        rmapbufs      => CFG_SPW_RMAPBUFS,
        dmachan       => CFG_SPW_DMACHAN,
        hindex        => hmidx_spwrtr,  -- Starting index
        pindex        => pidx_spwrtr,   -- Starting index
        paddr         => paddr_spwrtr,       -- Starting base address
        pmask         => 16#FFF#,
        pirq          => SPWRTR_PIRQ,             -- Starting IRQ
        ahbslven      => 1,
        cfghindex     => hsidx_spwrtr,
        cfghaddr      => 16#C40#,
        cfghmask      => 16#FC0#,
        timerbits     => CFG_SPW_TIMERBITS,
        pnp           => CFG_SPW_PNP,
        autoscrub     => CFG_SPW_AUTOSCRUB,
        sim           => 0,             -- Simulation mode, not used
        dualport      => 0,
        spacewired    => 1,
        interruptdist => 2,
        spwpnpvendid  => 3,
        spwpnpprodid  => 16#060#,
        porttimerbits => CFG_SPW_TIMERBITS,
        irqtimerbits  => CFG_SPW_TIMERBITS,
        auxtimeen     => 1,
        num_txdesc    => 64,
        num_rxdesc    => 128,
        auxasync      => 0)
      port map(
        rst        => rstn,
        clk        => clkm,
        rst_codec  => (others => '0'),  -- Resets generated internally
        clk_codec  => (others => '0'),  -- Clockgate generated internally
        rxasyncrst => (others => '0'),  -- Resets generated internally
        rxsyncrst  => (others => '0'),  -- Resets generated internally
        rxclk      => spw_rxclko,
        txsyncrst  => (others => '0'),  -- Resets generated internally
        txclk      => spw_txclk,  -- Only the element 0 will be used (spw_clkl)
        txclkn     => spw_txclkn,  -- Only the element 0 will be used (spw_clkln)
        testen     => '0',
        testrst    => '0',
        scanen     => '0',
        testoen    => '0',
        di         => di,
        dvi        => dvi,
        dconnect   => dconnect,
        dconnect2  => dconnect2,
        dconnect3  => dconnect3,
        do         => do,
        so         => so,
        ahbmi      => spwr_ahbmi,
        ahbmo      => spwr_ahbmo,
        apbi       => apbi_1,
        apbo       => spwr_apbo,
        ahbsi      => ahbsi,
        ahbso      => ahbso(hsidx_spwrtr),
        ri         => spwri,
        ro         => spwro);

    spwr_ahbmi <= (others => ahbmi);

    ahbspw : for i in 0 to CFG_SPW_AMBAPORTS-1 generate
      ahbmo(hmidx_spwrtr+i) <= spwr_ahbmo(i);
      apbo_1(pidx_spwrtr+i)   <= spwr_apbo(i);
    end generate;

    -- grspwrouter is configured at implementation time by the VHDL generic
    -- settings above, some configuration is also made via signals
    -- RMAP is always enabled after reset
    spwri.rmapen                 <= (others => '1');
    -- Initialization divisor value for the SpaceWire links
    spwri.idivisor               <= SPW_CLKDIV10;
    -- Drive FIFO interface signals
    spwri.txwrite(30 downto 2)   <= (others => '0');
    spwri.txchar(2 to 30)        <= (others => (others => '0'));
    spwri.rxread(30 downto 2)    <= (others => '0');
    spwri.tickin(0)              <= '0';
    spwri.tickin(30 downto 3)    <= (others => '0');
    spwri.timein(0)              <= (others => '0');
    spwri.timein(3 to 30)        <= (others => (others => '0'));
    -- Prescaler default reload value, needs to
    -- be initialized by external entity:
    spwri.reload                 <= (others => '1');
    -- Individual time default reload value
    spwri.reloadn                <= (others => '1');
    spwri.timeren                <= '1';
    -- Enable time-code functionality:
    spwri.timecodeen             <= '1';
    -- Lock configuration port accesses from all ports except port 1
    spwri.cfglock                <= '0';
    -- Reset value for selfaddren register bit
    spwri.selfaddren             <= '1';
    -- Reset value for the linkstarteq register bit
    spwri.linkstartreq           <= (others => '0');
    -- Resetvalue for the autodconnect register bit
    spwri.autodconnect           <= (others => '0');
    -- Instance ID
    spwri.instanceid(7 downto 2) <= conv_std_logic_vector(CFG_SPWINSTID, 6);
    spwri.instanceid(1)          <= '0';
    spwri.instanceid(0)          <= '0';
    spwri.enbridge               <= (others => '0');
    spwri.enexttime              <= (others => '0');
    spwri.auxtickin              <= '0';
    spwri.auxtimeinen            <= '0';
    spwri.auxtimein              <= (others => '0');
    spwri.irqtimeoutreload       <= (others => '1');
    spwri.ahbso                  <= ahbs_none;
    spwri.interruptcodeen        <= '0';
    spwri.pnpen                  <= '0';
    spwri.timecodefilt           <= '0';
    spwri.interruptfwd           <= '0';
    spwri.spillifnrdy            <= (others => '0');
    spwri.timecoderegen          <= '1';
    spwri.gpi                    <= (others => '0');
    spwri.staticrouteen          <= '1';
    spwri.spwclklock             <= '1';
    spwri.irqgenreload           <= (others => '0');
    spwri.interruptmode          <= '0';
    -- input timing testing
    spwri.testd                  <= (others => '0');
    spwri.tests                  <= (others => '0');
    spwri.testinput              <= '0';
   
    spacewirerouter_pads : entity work.spacewirerouter_pads
      generic map (
        padtech => padtech, 
        CFG_SPW_EN_GR740_4 => CFG_SPW_EN_GR740_4,
        CFG_SPW_EN_GR740_5 => CFG_SPW_EN_GR740_5,
        CFG_SPW_EN_GR740_6 => CFG_SPW_EN_GR740_6,
        CFG_SPW_EN_GR740_7 => CFG_SPW_EN_GR740_7,
        CFG_SPW_EN_MEZ_1 => CFG_SPW_EN_MEZ_1, 
        CFG_SPW_EN_MEZ_2 => CFG_SPW_EN_MEZ_2,
        CFG_SPW_EN_MEZ_3 => CFG_SPW_EN_MEZ_3,
        CFG_SPW_EN_MEZ_4 => CFG_SPW_EN_MEZ_4)
      port map (
        do => do, 
        so => so, 
        dtmp => dtmp, 
        stmp => stmp,
        spw_din_gr740_4 => spw_din_gr740_4,
        spw_sin_gr740_4 => spw_sin_gr740_4,
        spw_dout_gr740_4 => spw_dout_gr740_4,
        spw_sout_gr740_4 => spw_sout_gr740_4,
        spw_din_gr740_5 => spw_din_gr740_5,
        spw_sin_gr740_5 => spw_sin_gr740_5,
        spw_dout_gr740_5 => spw_dout_gr740_5,
        spw_sout_gr740_5 => spw_sout_gr740_5,        
        spw_din_gr740_6 => spw_din_gr740_6,
        spw_sin_gr740_6 => spw_sin_gr740_6,
        spw_dout_gr740_6 => spw_dout_gr740_6,
        spw_sout_gr740_6 => spw_sout_gr740_6,
        spw_din_gr740_7 => spw_din_gr740_7,
        spw_sin_gr740_7 => spw_sin_gr740_7,
        spw_dout_gr740_7 => spw_dout_gr740_7,
        spw_sout_gr740_7 => spw_sout_gr740_7,
        spw_din_mez_1 => spw_din_mez_1,  
        spw_sin_mez_1 => spw_sin_mez_1,
        spw_dout_mez_1 => spw_dout_mez_1, 
        spw_sout_mez_1  => spw_sout_mez_1, 
        spw_din_mez_2 => spw_din_mez_2, 
        spw_sin_mez_2 => spw_sin_mez_2,
        spw_dout_mez_2 => spw_dout_mez_2,
        spw_sout_mez_2 => spw_sout_mez_2, 
        spw_din_mez_3 => spw_din_mez_3, 
        spw_sin_mez_3 => spw_sin_mez_3, 
        spw_dout_mez_3 => spw_dout_mez_3, 
        spw_sout_mez_3 => spw_sout_mez_3,   
        spw_din_mez_4 => spw_din_mez_4, 
        spw_sin_mez_4 => spw_sin_mez_4, 
        spw_dout_mez_4 => spw_dout_mez_4,
        spw_sout_mez_4 => spw_sout_mez_4);
  end generate spwrtr;

  -----------------------------------------------------------------------
  ---  SPACE FIBRE ------------------------------------------------------
  -----------------------------------------------------------------------

  hssl0 : if cfg_hssl_en /= 0 generate
    spfi_gen : for i in 0 to CFG_HSSL_NUM-1 generate

        -- Monitor frequency of HSSL clocks by means of counters. This is useful
        -- because the GR740-MINI board contains no less than 4 dynamically
        -- configurable clock sources that can be selected independently for
        -- the two quads 8at runtime via registers).
        hssl_cnt_comb : process(hssl_cnt(i)) is
        begin
          if hssl_cnt(i) /= "1111111111" then
            hssl_cnt_in(i) <= hssl_cnt(i) + 1;
          else
            hssl_cnt_in(i) <= "0000000000";
          end if;
        end process;

        hssl_cnt_reg : process(hssl_clk(i)) is
        begin
          if rising_edge(hssl_clk(i)) then
            hssl_cnt(i) <= hssl_cnt_in(i);
          end if;
        end process;

        gpreg_cnt_comb : process(rstn, hssl_cnt(i)(9), serdes_clkconf_in) is
          variable v : serdes_clkconf_in_type;
        begin
          v := serdes_clkconf_in;
          -- meta-stability filter
          v.hssl_cnt(i) := hssl_cnt(i)(9) & serdes_clkconf_in.hssl_cnt(i)(5 downto 1);
          -- check for 0->1 transitions of the most significant counter bit
          -- in the other clock domain. Increment our slow counter when we
          -- find one.
          if (serdes_clkconf_in.hssl_cnt(i)(0) = '1') and (serdes_clkconf_in.hssl_cnt(i)(1) = '0') then
            v.cnt(i) := serdes_clkconf_in.cnt(i) + 1;
          end if;
          if rstn = '0' then
            v.cnt(i) := (others => '0');
          end if;
          serdes_clkconf_inn <= v;
        end process;

        gpreg_cnt_reg : process(clkm) is
        begin
          if rising_edge(clkm) then
            serdes_clkconf_in.cnt(i) <= serdes_clkconf_inn.cnt(i);
			      serdes_clkconf_in.hssl_cnt(i) <= serdes_clkconf_inn.hssl_cnt(i);
          end if;
        end process;

        spfi_i : grspfi_ahb
        generic map (
          tech               => memtech,
          hmindex            => hmidx_grhssl+i*CFG_GRHSSL_DMA,
          hsindex            => hsidx_grhssl+i,
          haddr              => CFG_SPFI_IOADDR + i*16#010#,
          hmask              => 16#ff0#,
          hirq               => SPFI_PIRQ + i,
          use_8b10b          => 1,
          use_sep_txclk      => 0,
          sel_16_20_bit_mode => 0,
          ticks_2us          => 125,
          tx_skip_freq       => 5000,
          prbs_init1         => 1,
          depth_rbuf_data    => 8,
          depth_rbuf_fct     => 4,
          depth_rbuf_bc      => 8,
          num_vc             => CFG_GRHSSL_VC,
          fct_multiplier     => 1,
          depth_vc_rx_buf    => 9,
          depth_vc_tx_buf    => 9,
          remote_fct_cnt_max => 9,
          width_bw_credit    => 20,
          min_bw_credit      => 52428,
          idle_time_limit    => 62500,
          num_dmach          => CFG_GRHSSL_DMA,
          num_txdesc         => 256,
          num_rxdesc         => 512,
          depth_dma_fifo     => 32,
          depth_bc_fifo      => 4,
          ft_core_vc         => CFG_GRSPFI_FT_VC,
          ft_core_rt1        => CFG_GRSPFI_FT_RT1,
          ft_core_rt2        => CFG_GRSPFI_FT_RT2,
          ft_core_if         => CFG_GRSPFI_FT_IF,
          ft_dma_data        => CFG_GRSPFI_FT_DATA,
          ft_dma_bc          => CFG_GRSPFI_FT_BC,
          use_async_rxrst    => 1,
          rmap               => CFG_GRHSSL_RMAP, 
          numextvc           => 1,
          numextbc           => 1)
        port map (
          clk        => clkm,
          rstn       => hssl_rstn(i), 
          spfi_clk   => hssl_clk(i),
          spfi_rstn  => hssl_rstn(i), 
          spfi_txclk => '0', -- unused (40-bit serdes interface)
          -- ahb interface
          ahbmi      => ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA+CFG_GRHSSL_DMA-1 downto hmidx_grhssl+i*CFG_GRHSSL_DMA),
          ahbmo      => ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA+CFG_GRHSSL_DMA-1 downto hmidx_grhssl+i*CFG_GRHSSL_DMA), 
          ahbsi      => ahbsi,
          ahbso      => ahbso(hsidx_grhssl+i),
          -- serdes interface
          spfii      => hssli(i),
          spfio      => hsslo(i),
          -- External VC/BC interface
          extvci     => hssl_extvci(i),
          extvco     => hssl_extvco(i),
          extbci     => hssl_extbci(i),
          extbco     => hssl_extbco(i));          
  
          spfi_dma_1 : if CFG_GRHSSL_DMA = 1 generate
            ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA) <= ahbmi;
            ahbmo(hmidx_grhssl+i*CFG_GRHSSL_DMA) <= ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA);
          end generate;
      
          spfi_dma_2 : if CFG_GRHSSL_DMA = 2 generate
            ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA) <= ahbmi;
            ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 1) <= ahbmi;
            ahbmo(hmidx_grhssl+i*CFG_GRHSSL_DMA) <= ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA);
            ahbmo(hmidx_grhssl+i*CFG_GRHSSL_DMA + 1) <= ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 1);
          end generate;

          spfi_dma_3 : if CFG_GRHSSL_DMA = 3 generate
            ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA) <= ahbmi;
            ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 1) <= ahbmi;
            ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 2) <= ahbmi;
            ahbmo(hmidx_grhssl+i*CFG_GRHSSL_DMA) <= ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA);
            ahbmo(hmidx_grhssl+i*CFG_GRHSSL_DMA + 1) <= ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 1);
            ahbmo(hmidx_grhssl+i*CFG_GRHSSL_DMA + 2) <= ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 2);
          end generate;

          spfi_dma_4 : if CFG_GRHSSL_DMA = 4 generate
            ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA) <= ahbmi;
            ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 1) <= ahbmi;
            ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 2) <= ahbmi;
            ahbmi_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 3) <= ahbmi;  
            ahbmo(hmidx_grhssl+i*CFG_GRHSSL_DMA) <= ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA);
            ahbmo(hmidx_grhssl+i*CFG_GRHSSL_DMA + 1) <= ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 1);
            ahbmo(hmidx_grhssl+i*CFG_GRHSSL_DMA + 2) <= ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 2);
            ahbmo(hmidx_grhssl+i*CFG_GRHSSL_DMA + 3) <= ahbmo_hssl(hmidx_grhssl+i*CFG_GRHSSL_DMA + 3);
          end generate;

      end generate spfi_gen;
      
      no_hssl0 : if cfg_hssl_en = 0 generate
        nospfi_gen : for i in CFG_HSSL_NUM to 3 generate
          serdes_clkconf_in.cnt(i) <= X"5555";
	        serdes_clkconf_in.hssl_cnt(i) <= (others => '0');
        end generate;
      end generate;

    serdes_wrapper0 : entity work.serdes_wrapper
      generic map (
        -- See config.vhd for the meaning of these parameters
        EN_SD0 => CFG_HSSL_EN_SD0,
        EN_SD2 => CFG_HSSL_EN_SD2,               
        EN_SD6 => CFG_HSSL_EN_SD6,
        EN_SD7 => CFG_HSSL_EN_SD7,
        SDQ0_REFCLK => CFG_HSSL_SDQ0_REFCLK,
        SDQ1_REFCLK => CFG_HSSL_SDQ1_REFCLK)
      port map (
        -- 100-300 MHz clock to drive calibration logic.
        -- And reset for the SerDes blocks
        clk => clk_in_125mhz,
        rstn => serdes_clkconf_out.rstin, 
        sdq1_use_refmux => serdes_clkconf_out.sdq1_use_refmux,
        sdq1_extsel     => serdes_clkconf_out.sdq1_extsel,
        sdq0_use_refmux => serdes_clkconf_out.sdq0_use_refmux,
        sdq0_extsel     => serdes_clkconf_out.sdq0_extsel,
        -- Clock and (synchronous) reset output from SerDes
        hssl_clk => hssl_clk,
        hssl_rstn => hssl_rstn,
        -- SpaceFibre to SerDes interface
        hssli => hssli,
        hsslo => hsslo
        --pragma translate_off
        ,
        SDQ0_REFCLKP => SDQ0_REFCLKP,
        SDQ0_REFCLKN => SDQ0_REFCLKN,
        SD0_TXDP => SD0_TXDP,
        SD0_TXDN => SD0_TXDN,
        SD0_RXDP => SD0_RXDP,
        SD0_RXDN => SD0_RXDN,
        SD2_TXDP => SD2_TXDP,
        SD2_TXDN => SD2_TXDN,
        SD2_RXDP => SD2_RXDP,
        SD2_RXDN => SD2_RXDN,
        SD_EXT0_REFCLKP => SD_EXT0_REFCLKP,
        SD_EXT0_REFCLKN => SD_EXT0_REFCLKN,
        SDQ1_REFCLKP => SDQ1_REFCLKP,
        SDQ1_REFCLKN => SDQ1_REFCLKN,
        SD6_TXDP => SD6_TXDP,
        SD6_TXDN => SD6_TXDN,
        SD6_RXDP => SD6_RXDP,
        SD6_RXDN => SD6_RXDN,
        SD7_TXDP => SD7_TXDP,
        SD7_TXDN => SD7_TXDN,
        SD7_RXDP => SD7_RXDP,
        SD7_RXDN => SD7_RXDN,
        SD_EXT1_REFCLKP => SD_EXT1_REFCLKP,
        SD_EXT1_REFCLKN => SD_EXT1_REFCLKN
        --pragma translate_on
        );

        en_sdq1_refclk <= serdes_clkconf_out.en_sdq1_refclk;
        en_sdq0_refclk <= serdes_clkconf_out.en_sdq0_refclk;

    gpreg0 : grgprbank
        generic map (
          pindex => pidx_gp_register,
          paddr => paddr_gp_register,
          pmask => 16#fff#,
          regbits => 16,
          nregs => 5,
          extrst => 1,
          rdataen => 1)
        port map (
          rst => rstn,
          clk => clkm,
          apbi => apbi_0,
          apbo => apbo_0(pidx_gp_register),
          rego => gpreg_out,
          resval => gpreg_res,
          rdata => gpreg_in);

    gpreg_in(16*0+15 downto 16*0+0) <= serdes_clkconf_in.cnt(0); -- reg 0
    gpreg_in(16*1+15 downto 16*1+0) <= serdes_clkconf_in.cnt(1); -- reg 1
    gpreg_in(16*2+15 downto 16*2+0) <= serdes_clkconf_in.cnt(2); -- reg 2
    gpreg_in(16*3+15 downto 16*3+0) <= serdes_clkconf_in.cnt(3); -- reg 3
    gpreg_in(16*4+15 downto 16*4+0) <= serdes_clkconf_out.rstin & "000" & -- 15:12
                                          "0000" & -- 13:8
                                          serdes_clkconf_out.en_sdq1_refclk & "0" & serdes_clkconf_out.sdq1_use_refmux & serdes_clkconf_out.sdq1_extsel & -- 7:4
                                          serdes_clkconf_out.en_sdq0_refclk & "0" & serdes_clkconf_out.sdq0_use_refmux & serdes_clkconf_out.sdq0_extsel;  -- 3:0

    serdes_clkconf_out.rstin           <= gpreg_out(16*4 +15);
    serdes_clkconf_out.en_sdq1_refclk  <= gpreg_out(16*4 + 7);
    serdes_clkconf_out.sdq1_use_refmux <= gpreg_out(16*4 + 5);
    serdes_clkconf_out.sdq1_extsel     <= gpreg_out(16*4 + 4);
    serdes_clkconf_out.en_sdq0_refclk  <= gpreg_out(16*4 + 3);
    serdes_clkconf_out.sdq0_use_refmux <= gpreg_out(16*4 + 1);
    serdes_clkconf_out.sdq0_extsel     <= gpreg_out(16*4 + 0);

    gpreg_res <= (others => '0');
  end generate hssl0; 

  -----------------------------------------------------------------------
  ---  SPACEWIRE - SPACEFIBRE BRIDGE ------------------------------------
  -----------------------------------------------------------------------      

  spwrt12r : if CFG_SPW_SPFI_BR_EN /= 0 generate 
    spfi_gen : for i in 0 to CFG_HSSL_NUM-1 generate 

      databr : grspfi_spwdatabr
        generic map (
          tech => memtech,
          ft   => 0)
        port map (
          clk       => clkm,
          rstn      => rstn,
          spfi_clk  => hssl_clk(i),
          spfi_rstn => hssl_rstn(i),
          bi        => spfispwbi(i),
          bo        => spfispwbo(i));

      spfispwbi(i).spfi         <= hssl_extvco(i)(0);
      spfispwbi(i).spw_txfull   <= spwro.txfull(i);
      spfispwbi(i).spw_txafull  <= spwro.txafull(i);
      spfispwbi(i).spw_rxchar   <= spwro.rxchar(i);
      spfispwbi(i).spw_rxcharav <= spwro.rxcharav(i);
      spfispwbi(i).spw_rxaempty <= spwro.rxaempty(i);

      hssl_extvci(i)(0) <= spfispwbo(i).spfi;
      spwri.txchar(i)   <= spfispwbo(i).spw_txchar;
      spwri.txwrite(i)  <= spfispwbo(i).spw_txwrite;
      spwri.rxread(i)   <= spfispwbo(i).spw_rxread;

      hssl_extvci(i)(1 to 31) <= (others => extvc_none);

      bcbr : grspfi_spwtcbr
        generic map (
          tech => memtech,
          ft   => 0)
        port map (
          clk       => clkm,
          rstn      => rstn,
          spfi_clk  => hssl_clk(i),
          spfi_rstn => hssl_rstn(i),
          bi        => bctcbi(i),
          bo        => bctcbo(i));

      bctcbi(i).spfi        <= hssl_extbco(i);
      bctcbi(i).spw_tickout <= spwro.tickout(i+1);
      bctcbi(i).spw_timeout <= spwro.timeout(i+1);
      bctcbi(i).map_bctype  <= X"01";  -- Time codes are assigned Broadcast Type 0x01
      bctcbi(i).map_bcmask  <= X"00";  -- All bits in the BC type are compared
      bctcbi(i).map_bcsel   <= "000";  -- Time codes mapped to the MSB of the BC data

      hssl_extbci(i)    <= bctcbo(i).spfi;
      spwri.tickin(i+1) <= bctcbo(i).spw_tickin;
      spwri.timein(i+1) <= bctcbo(i).spw_timein;
    end generate;
  end generate;

  -----------------------------------------------------------------------
  ---  ETHERNET ---------------------------------------------------------
  -----------------------------------------------------------------------
  
  -- Connect unused signal to high Z.
  eth0_mdc_pad : inpad generic map (tech => padtech)
    port map (eth0_mdc, open);

  eth0_mdio_pad : inpad generic map (tech => padtech)
	  port map (eth0_mdio, open);

  eth0_mdint_pad : inpad generic map (tech => padtech)
    port map (eth0_mdint, open);

  ethernet1 : if CFG_GRETH = 1 generate 
    eth : grethm
	    generic map(
	      hindex => hmidx_greth,
        pindex => pidx_greth,
	      paddr  => paddr_greth,
	      pirq   => GRETH_PIRQ,
	      memtech => memtech, 
	      enable_mdio => CFG_ETH_MDIO, 
	      fifosize => CFG_ETH_FIFO,
	      edcl => CFG_DSU_ETH,
	      edclbufsz => CFG_ETH_BUF,
        burstlength => CFG_ETH_BURSTLEN,
        macaddrh => CFG_ETH_ENM,
	      macaddrl => CFG_ETH_ENL,
	      oepol => OEPOL,
        ipaddrh => CFG_ETH_IPM,
	      ipaddrl => CFG_ETH_IPL,
        phyrstadr => CFG_ETH_PHY_ADD,
        giga => CFG_GRETH1G,
		    gmiimode => 0,
        ft => CFG_ETH_FT,
        external_mdio_ctrl => 1)
	    port map(
	      rst   => rstn,
	      clk   => clkm,
	      ahbmi => ahbmi,
	      ahbmo => ahbmo(hmidx_greth),
	      apbi  => apbi_0,
	      apbo  => apbo_0(pidx_greth),
	      ethi  => ethi1,
	      etho  => etho1);

      erxd_pad : inpadv generic map (tech => padtech, width => 8)
        port map (eth_rxd, ethi1.rxd(7 downto 0));
      erxdv_pad : inpad generic map (tech => padtech)
        port map (eth_rxdv, ethi1.rx_dv);
      erxer_pad : inpad generic map (tech => padtech)
        port map (eth_rxer, ethi1.rx_er);
      etxd_pad : outpadv generic map (tech => padtech, width => 8)
        port map (eth_txd, etho1.txd(7 downto 0));
      etxen_pad : outpad generic map (tech => padtech)
        port map ( eth_txen, etho1.tx_en);
      etxer_pad : outpad generic map (tech => padtech)
        port map (eth_txer, etho1.tx_er);
      erxco_pad : inpad generic map (tech => padtech)
        port map (eth_col, ethi1.rx_col);
      erxcr_pad : inpad generic map (tech => padtech)
        port map (eth_crs, ethi1.rx_crs);
  
      ethi1.rx_clk <= eth_rxclk;
      ethi1.tx_clk <= eth_txclk;
      ethi1.gtx_clk <= clk_in_125mhz;
      eth_gtxclk <= clk_in_125mhz;

      ethi1.tx_dv <= '1';

      mdio_internal : if CFG_ETH_MDIO = 1 generate
        emdc_pad : outpad generic map (tech => padtech)
          port map (eth_mdc, etho1.mdc);
        emdio_pad : iopad generic map (tech => padtech)
	        port map (eth_mdio, etho1.mdio_o, etho1.mdio_oe, ethi1.mdio_i);
      end generate; 

      mdio_external : if CFG_ETH_MDIO = 0 generate  -- when set to 0 the MDIO controller built in greth will be used 
        mdio_ctrl : mdio_controller
        generic map(
          pindex => pidx_mdio,
          paddr  => paddr_mdio,
          pirq   => MDIO_PIRQ,
          mdio_clk_divisor => 24,
          mdio_input_delay => 15,
          oe_polarity => '0', 
          phy_init_mask => X"00000000")
        port map(
          clk   => clkm,
          rstn   => rstn,
          mdio_clk => mdio_clk,
          mdio_i => mdio_i,
          mdio_o => mdio_o,
          mdio_oe => mdio_oe,
          mdio_irq => '0', -- not used in design
          perform_startup_init => '0', 
          apbi  => apbi_0,
          apbo  => apbo_0(pidx_mdio));

        emdc_pad : outpad generic map (tech => padtech)
          port map (eth_mdc, mdio_clk);
        emdio_pad : iopad generic map (tech => padtech)
          port map (eth_mdio, mdio_o, mdio_oe, mdio_i); 

        end generate;
        

  end generate;

  ----------------------------------------------------------------------
  ---  APB Bridge and various periherals -------------------------------
  ----------------------------------------------------------------------

  apb0 : apbctrl       -- APB Bridge
    generic map (hindex => hsidx_apbctrl_0, haddr => CFG_APBADDR_0)
    port map (rstn, clkm, ahbsi, ahbso(hsidx_apbctrl_0), apbi_0, apbo_0);

  apb_spwrtr : if CFG_SPW_EN = 1 generate
    apb1 : apbctrl     -- APB Bridge
      generic map (hindex => hsidx_apbctrl_1, haddr => CFG_APBADDR_1)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_apbctrl_1), apbi_1, apbo_1);
  end generate;   

  irqmp_gen : if CFG_IRQ3_ENABLE = 1 generate
    irqctrl0 : irqmp   -- Interrupt controller
      generic map (pindex => pidx_irqmp, paddr => paddr_irqmp, ncpu => 1, eirq => 15)
      port map (rstn, clkm, apbi_0, apbo_0(pidx_irqmp), irqo, irqi);
  end generate;
  
  irqo(0).irl <= "0000";

  uart1gen: if CFG_UART_1_ENABLE = 1 and CFG_AHB_UART = 0 generate 
    uart1 : apbuart    -- UART 1 (Shared same pinput as debug UART)
      generic map (pindex   => pidx_apbuart, paddr => paddr_apbuart, pirq => APBUART1_PIRQ, console => dbguart)
      port map (rstn, clkm, apbi_0, apbo_0(pidx_apbuart), u1i, u1o);
        u1i.rxd    <= debug_uart_rx;
        u1i.ctsn   <= '0';
        u1i.extclk <= '0';    
        txduartpad: if CFG_AHB_UART = 0  generate
          debug_uart_tx    <= u1o.txd;
        end generate;
  end generate;

  gpio : if CFG_GRGPIO_EN = 1 generate
    grgpio1: grgpio       
      generic map(
        pindex    => pidx_grgpio, paddr => paddr_grgpio,
        nbits     => CFG_GRGPIO_WIDTH,
        imask     => CFG_GRGPIO_IMASK,
        pirq      => GPIO_PIRQ,
        irqgen    => CFG_GRGPIO_IRQGEN,
        iflagreg  => 1)
      port map(rstn, clkm, apbi_0, apbo_0(pidx_grgpio), gpio0i, gpio0o);

    gpio_led_pad : iopadvv generic map (tech => padtech, width => 4)
      port map (fpga_led, gpio0o.dout(3 downto 0), gpio0o.oen(3 downto 0), gpio0i.din(3 downto 0));
    gpio_gr740_pad : iopadvv generic map (tech => padtech, width => 5)
      port map (gr740_gpio2, gpio0o.dout(8 downto 4), gpio0o.oen(8 downto 4), gpio0i.din(8 downto 4));
  end generate;

  gptimer_gen : if CFG_GPT_ENABLE = 1 generate
    timer0 : gptimer     -- Time Unit
      generic map (pindex => pidx_gptimer, paddr => paddr_gptimer, pirq => GPT_PIRQ,
                 sepirq => 1, ntimers => 2)
      port map (rstn, clkm, apbi_0, apbo_0(pidx_gptimer), gpti, open);
    gpti <= gpti_dhalt_drive('0');
  end generate;

  i2c_gen_1 : if CFG_I2C_FMC = 1 generate -- I2C FMC
    i2c1 : i2cmst
      generic map (pindex => pidx_i2c, paddr => paddr_i2c, pmask => 16#FFF#, pirq => I2C1_PIRQ)
      port map (rstn, clkm, apbi_0, apbo_0(pidx_i2c), i2ci(0), i2co(0));
    i2ci(0).scl <= i2co(0).scloen;
    i2c_scl_pad : outpad generic map (tech => padtech)
      port map (i2c_scl_fmc, i2co(0).scloen);
    i2c_sda_pad : iopad generic map (tech => padtech)
      port map (i2c_sda_fmc, i2co(0).sda, i2co(0).sdaoen, i2ci(0).sda);
  end generate; 

  ----------------------------------------------------------------------
  ------------------ AHBRAM for simulation purposes --------------------
  ----------------------------------------------------------------------

  ahbsim_gen: if simulation = true generate
   -- pragma translate_off
    sim_ahbram : ahbram_sim
      generic map (
        hindex        => hsidx_ahbram,
        haddr         => 16#400#,
        hmask         => 16#C00#,
        tech          => 0,
        kbytes        => 1024,
        pipe          => 0,
        maccsz        => AHBDW,
       fname         => ramfile)
      port map(
        rst     => rstn,
        clk     => clkm,
        ahbsi   => ahbsi,
        ahbso   => ahbso(hsidx_ahbram));
  -- pragma translate_on
  end generate ahbsim_gen;

  -----------------------------------------------------------------------
  --  Test report module, only used for simulation ----------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  test0 : ahbrep
    generic map (hindex => hsidx_ahbrep, haddr => CFG_SIM_TEST_REPORT)
    port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbrep));
  -- pragma translate_on

  -----------------------------------------------------------------------
  ---  Boot message  ----------------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  x : report_design
    generic map (
      msg1 => "LEON3 Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel => 1 );
  -- pragma translate_on

end rtl;
