-----------------------------------------------------------------------------
--  LEON Xilinx AC701 Demonstration design
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
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib, techmap;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use techmap.gencomp.all;
use techmap.allclkgen.all;
library gaisler;
use gaisler.memctrl.all;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.spi.all;
use gaisler.i2c.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.l2cache.all;
use gaisler.subsys.all;
-- pragma translate_off
use gaisler.sim.all;
library unisim;
use unisim.all;
-- pragma translate_on

library esa;
use esa.memoryctrl.all;

use work.config.all;

entity leon3mp is
  generic (
    fabtech             : integer := CFG_FABTECH;
    memtech             : integer := CFG_MEMTECH;
    padtech             : integer := CFG_PADTECH;
    clktech             : integer := CFG_CLKTECH;
    disas               : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart             : integer := CFG_DUART;   -- Print UART on console
    pclow               : integer := CFG_PCLOW;
    SIM_BYPASS_INIT_CAL : string := "OFF";
    SIMULATION          : string := "FALSE";
    USE_MIG_INTERFACE_MODEL : boolean := false
  );
  port (
    reset           : in    std_ulogic;
    clk200p         : in    std_ulogic;  -- 200 MHz clock
    clk200n         : in    std_ulogic;  -- 200 MHz clock
    spi_sel_n       : inout std_ulogic;
--    spi_clk         : out   std_ulogic;
    spi_miso        : in    std_ulogic;
    spi_mosi        : out   std_ulogic;
    ddr3_dq         : inout std_logic_vector(63 downto 0);
    ddr3_dqs_p      : inout std_logic_vector(7 downto 0);
    ddr3_dqs_n      : inout std_logic_vector(7 downto 0);
    ddr3_addr       : out   std_logic_vector(13 downto 0);
    ddr3_ba         : out   std_logic_vector(2 downto 0);
    ddr3_ras_n      : out   std_logic;
    ddr3_cas_n      : out   std_logic;
    ddr3_we_n       : out   std_logic;
    ddr3_reset_n    : out   std_logic;
    ddr3_ck_p       : out   std_logic_vector(0 downto 0);
    ddr3_ck_n       : out   std_logic_vector(0 downto 0);
    ddr3_cke        : out   std_logic_vector(0 downto 0);
    ddr3_cs_n       : out   std_logic_vector(0 downto 0);
    ddr3_dm         : out   std_logic_vector(7 downto 0);
    ddr3_odt        : out   std_logic_vector(0 downto 0);
    dsurx           : in    std_ulogic;
    dsutx           : out   std_ulogic;
    dsuctsn         : in    std_ulogic;
    dsurtsn         : out   std_ulogic;
    button          : in    std_logic_vector(3 downto 0);
    switch          : inout std_logic_vector(3 downto 0);
    led             : out   std_logic_vector(3 downto 0);
    iic_scl         : inout std_ulogic;
    iic_sda         : inout std_ulogic;
    gtrefclk_p      : in    std_logic;
    gtrefclk_n      : in    std_logic;
    phy_txclk       : out   std_logic;
    phy_txd         : out   std_logic_vector(3 downto 0);
    phy_txctl_txen  : out   std_ulogic;
    phy_rxd         : in    std_logic_vector(3 downto 0);
    phy_rxctl_rxdv  : in    std_ulogic;
    phy_rxclk       : in    std_ulogic;
    phy_reset       : out   std_ulogic;
    phy_mdio        : inout std_logic;
    phy_mdc         : out   std_ulogic;
    sfp_clock_mux   : out   std_logic_vector(1 downto 0);
    sdcard_spi_miso : in    std_logic;
    sdcard_spi_mosi : out   std_logic;
    sdcard_spi_cs_b : out   std_logic;
    sdcard_spi_clk  : out   std_logic;
    -- FMC Ports
    --
    ref_clk_clk_p          : in    std_ulogic;
    ref_clk_clk_n          : in    std_ulogic;
    ref_clk_oe             : out   std_ulogic;  -- Enable FMC ref clock output
    ref_clk_fsel           : out   std_ulogic;  -- Slect 125MHz/250MHz ref clock
    --
    reset_port_0           : out   std_ulogic;
    reset_port_1           : out   std_ulogic;
    reset_port_2           : out   std_ulogic;
    reset_port_3           : out   std_ulogic;
    --
    rgmii_port_0_rxc       : in    std_ulogic;
    rgmii_port_0_rx_ctl    : in    std_ulogic;
    rgmii_port_0_rd        : in    std_logic_vector(3 downto 0);
    rgmii_port_0_txc       : out   std_ulogic;
    rgmii_port_0_tx_ctl    : out   std_ulogic;
    rgmii_port_0_td        : out   std_logic_vector(3 downto 0);
    rgmii_port_1_rxc       : in    std_ulogic;
    rgmii_port_1_rx_ctl    : in    std_ulogic;
    rgmii_port_1_rd        : in    std_logic_vector(3 downto 0);
    rgmii_port_1_txc       : out   std_ulogic;
    rgmii_port_1_tx_ctl    : out   std_ulogic;
    rgmii_port_1_td        : out   std_logic_vector(3 downto 0);
    rgmii_port_2_rxc       : in    std_ulogic;
    rgmii_port_2_rx_ctl    : in    std_ulogic;
    rgmii_port_2_rd        : in    std_logic_vector(3 downto 0);
    rgmii_port_2_txc       : out   std_ulogic;
    rgmii_port_2_tx_ctl    : out   std_ulogic;
    rgmii_port_2_td        : out   std_logic_vector(3 downto 0);
    rgmii_port_3_rxc       : in    std_ulogic;
    rgmii_port_3_rx_ctl    : in    std_ulogic;
    rgmii_port_3_rd        : in    std_logic_vector(3 downto 0);
    rgmii_port_3_txc       : out   std_ulogic;
    rgmii_port_3_tx_ctl    : out   std_ulogic;
    rgmii_port_3_td        : out   std_logic_vector(3 downto 0);
    --
    mdio_io_port_0_mdio_io : inout std_logic;
    mdio_io_port_0_mdc     : out   std_ulogic;
    mdio_io_port_1_mdio_io : inout std_logic;
    mdio_io_port_1_mdc     : out   std_ulogic;
    mdio_io_port_2_mdio_io : inout std_logic;
    mdio_io_port_2_mdc     : out   std_ulogic;
    mdio_io_port_3_mdio_io : inout std_logic;
    mdio_io_port_3_mdc     : out   std_ulogic
    --
    -- End of FMC Ports
   );
end;

architecture rtl of leon3mp is

component ahb2mig_7series
  generic(
    hindex     : integer := 0;
    haddr      : integer := 0;
    hmask      : integer := 16#f00#;
    pindex     : integer := 0;
    paddr      : integer := 0;
    pmask      : integer := 16#fff#;
    SIM_BYPASS_INIT_CAL : string := "OFF";
    SIMULATION : string  := "FALSE";
    USE_MIG_INTERFACE_MODEL : boolean := false
  );
  port(
    ddr3_dq           : inout std_logic_vector(63 downto 0);
    ddr3_dqs_p        : inout std_logic_vector(7 downto 0);
    ddr3_dqs_n        : inout std_logic_vector(7 downto 0);
    ddr3_addr         : out   std_logic_vector(13 downto 0);
    ddr3_ba           : out   std_logic_vector(2 downto 0);
    ddr3_ras_n        : out   std_logic;
    ddr3_cas_n        : out   std_logic;
    ddr3_we_n         : out   std_logic;
    ddr3_reset_n      : out   std_logic;
    ddr3_ck_p         : out   std_logic_vector(0 downto 0);
    ddr3_ck_n         : out   std_logic_vector(0 downto 0);
    ddr3_cke          : out   std_logic_vector(0 downto 0);
    ddr3_cs_n         : out   std_logic_vector(0 downto 0);
    ddr3_dm           : out   std_logic_vector(7 downto 0);
    ddr3_odt          : out   std_logic_vector(0 downto 0);
    ahbso             : out   ahb_slv_out_type;
    ahbsi             : in    ahb_slv_in_type;
    apbi              : in    apb_slv_in_type;
    apbo              : out   apb_slv_out_type;
    calib_done        : out   std_logic;
    rst_n_syn         : in    std_logic;
    rst_n_async       : in    std_logic;
    clk_amba          : in    std_logic;
    sys_clk_p         : in    std_logic;
    sys_clk_n         : in    std_logic;
    clk_ref_i         : in    std_logic;
    ui_clk            : out   std_logic;
    ui_clk_sync_rst   : out   std_logic
   );
end component ;

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
end component ;

component IBUFDS_GTE2
  port (
     O : out std_ulogic;
     ODIV2 : out std_ulogic;
     CEB : in std_ulogic;
     I : in std_ulogic;
     IB : in std_ulogic
  );
end component;

component IDELAYCTRL
  port (
     RDY : out std_ulogic;
     REFCLK : in std_ulogic;
     RST : in std_ulogic
  );
end component;

component IODELAYE1
  generic (
     DELAY_SRC : string := "I";
     IDELAY_TYPE : string := "DEFAULT";
     IDELAY_VALUE : integer := 0
  );
  port (
     CNTVALUEOUT : out std_logic_vector(4 downto 0);
     DATAOUT     : out std_ulogic;
     C           : in std_ulogic;
     CE          : in std_ulogic;
     CINVCTRL    : in std_ulogic;
     CLKIN       : in std_ulogic;
     CNTVALUEIN  : in std_logic_vector(4 downto 0);
     DATAIN      : in std_ulogic;
     IDATAIN     : in std_ulogic;
     INC         : in std_ulogic;
     ODATAIN     : in std_ulogic;
     RST         : in std_ulogic;
     T           : in std_ulogic
  );
end component;

----- component STARTUPE2 -----
component STARTUPE2
  generic (
     PROG_USR : string := "FALSE";
     SIM_CCLK_FREQ : real := 0.0
  );
  port (
     CFGCLK : out std_ulogic;
     CFGMCLK : out std_ulogic;
     EOS : out std_ulogic;
     PREQ : out std_ulogic;
     CLK : in std_ulogic;
     GSR : in std_ulogic;
     GTS : in std_ulogic;
     KEYCLEARB : in std_ulogic;
     PACK : in std_ulogic;
     USRCCLKO : in std_ulogic;
     USRCCLKTS : in std_ulogic;
     USRDONEO : in std_ulogic;
     USRDONETS : in std_ulogic
  );
end component;

component BUFG port (O : out std_logic; I : in std_logic); end component;

component IBUFGDS
generic ( CAPACITANCE : string := "DONT_CARE";
DIFF_TERM : boolean := FALSE; IBUF_DELAY_VALUE : string := "0";
IOSTANDARD : string := "DEFAULT");
   port ( O : out std_ulogic; I : in std_ulogic; IB : in std_ulogic);
end component;

component PLLE2_ADV
  generic (
     BANDWIDTH : string := "OPTIMIZED";
     CLKFBOUT_MULT : integer := 5;
     CLKFBOUT_PHASE : real := 0.0;
     CLKIN1_PERIOD : real := 0.0;
     CLKIN2_PERIOD : real := 0.0;
     CLKOUT0_DIVIDE : integer := 1;
     CLKOUT0_DUTY_CYCLE : real := 0.5;
     CLKOUT0_PHASE : real := 0.0;
     CLKOUT1_DIVIDE : integer := 1;
     CLKOUT1_DUTY_CYCLE : real := 0.5;
     CLKOUT1_PHASE : real := 0.0;
     CLKOUT2_DIVIDE : integer := 1;
     CLKOUT2_DUTY_CYCLE : real := 0.5;
     CLKOUT2_PHASE : real := 0.0;
     CLKOUT3_DIVIDE : integer := 1;
     CLKOUT3_DUTY_CYCLE : real := 0.5;
     CLKOUT3_PHASE : real := 0.0;
     CLKOUT4_DIVIDE : integer := 1;
     CLKOUT4_DUTY_CYCLE : real := 0.5;
     CLKOUT4_PHASE : real := 0.0;
     CLKOUT5_DIVIDE : integer := 1;
     CLKOUT5_DUTY_CYCLE : real := 0.5;
     CLKOUT5_PHASE : real := 0.0;
     COMPENSATION : string := "ZHOLD";
     DIVCLK_DIVIDE : integer := 1;
     REF_JITTER1 : real := 0.0;
     REF_JITTER2 : real := 0.0;
     STARTUP_WAIT : string := "FALSE"
  );
  port (
     CLKFBOUT : out std_ulogic := '0';
     CLKOUT0 : out std_ulogic := '0';
     CLKOUT1 : out std_ulogic := '0';
     CLKOUT2 : out std_ulogic := '0';
     CLKOUT3 : out std_ulogic := '0';
     CLKOUT4 : out std_ulogic := '0';
     CLKOUT5 : out std_ulogic := '0';
     DO : out std_logic_vector (15 downto 0);
     DRDY : out std_ulogic := '0';
     LOCKED : out std_ulogic := '0';
     CLKFBIN : in std_ulogic;
     CLKIN1 : in std_ulogic;
     CLKIN2 : in std_ulogic;
     CLKINSEL : in std_ulogic;
     DADDR : in std_logic_vector(6 downto 0);
     DCLK : in std_ulogic;
     DEN : in std_ulogic;
     DI : in std_logic_vector(15 downto 0);
     DWE : in std_ulogic;
     PWRDWN : in std_ulogic;
     RST : in std_ulogic
  );
end component;

constant CFG_FMC     : integer := (CFG_GRETH_FMC * CFG_GRETH * 4);
constant CFG_FMC_DBG : integer := 1;

--constant maxahbm : integer := CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+CFG_GRETH;
constant maxahbm : integer := 16;
constant maxahbs : integer := 16;
constant maxapbs : integer := CFG_IRQ3_ENABLE+CFG_GPT_ENABLE+CFG_GRGPIO_ENABLE+CFG_AHBSTAT+CFG_AHBSTAT;

signal vcc, gnd   : std_logic;
signal memi  : memory_in_type;
signal memo  : memory_out_type;
signal wpo   : wprot_out_type;
signal sdi   : sdctrl_in_type;
signal sdo   : sdram_out_type;
signal sdo2, sdo3 : sdctrl_out_type;
signal spii : spi_in_type;
signal spio : spi_out_type;
signal slvsel : std_logic_vector(CFG_SPICTRL_SLVS-1 downto 0);

signal apbi  : apb_slv_in_type;
signal apbo  : apb_slv_out_vector := (others => apb_none);
signal apbi1 : apb_slv_in_type;
signal apbo1 : apb_slv_out_vector := (others => apb_none);
signal apbi2 : apb_slv_in_type;
signal apbo2 : apb_slv_out_vector := (others => apb_none);
signal ahbsi : ahb_slv_in_type;
signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
signal ahbmi : ahb_mst_in_type;
signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);
signal mig_ahbsi : ahb_slv_in_type;                            
signal mig_ahbso : ahb_slv_out_type;
               
signal sysi : leon_dsu_stat_base_in_type;
signal syso : leon_dsu_stat_base_out_type;

signal perf : l3stat_in_type;

signal ui_clk : std_ulogic;
signal clkm : std_ulogic := '0'; 
signal rstn, rstraw, sdclkl : std_ulogic;
signal clk_200 : std_ulogic;
signal clk40, clk65 : std_ulogic;

signal cgi, cgi2   : clkgen_in_type;
signal cgo, cgo2   : clkgen_out_type;
signal u1i, u2i, dui : uart_in_type;
signal u1o, u2o, duo : uart_out_type;

signal irqi : irq_in_vector(0 to CFG_NCPU-1);
signal irqo : irq_out_vector(0 to CFG_NCPU-1);

signal gmiii : eth_in_type;
signal gmiio : eth_out_type;

signal rgmiii,rgmiii_buf : eth_in_type;
signal rgmiio : eth_out_type;

signal rxd1 : std_logic;
signal txd1 : std_logic;

signal ethi : eth_in_type;
signal etho : eth_out_type;
signal gtx_clk,gtx_clk_nobuf,gtx_clk90 : std_ulogic;
signal rstgtxn : std_logic;
signal rstgtxn_0 : std_logic;

signal gpti : gptimer_in_type;
signal gpto : gptimer_out_type;

signal gpioi : gpio_in_type;
signal gpioo : gpio_out_type;

signal clklock, elock, ulock : std_ulogic;

signal lock, calib_done, clkml, lclk, rst, ndsuact : std_ulogic;
signal tck, tckn, tms, tdi, tdo : std_ulogic;

signal lcd_datal : std_logic_vector(11 downto 0);
signal lcd_hsyncl, lcd_vsyncl, lcd_del, lcd_reset_bl : std_ulogic;

signal i2ci, dvi_i2ci : i2c_in_type;
signal i2co, dvi_i2co : i2c_out_type;

constant BOARD_FREQ : integer := 200000;   -- input frequency in KHz
constant CPU_FREQ : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;  -- cpu frequency in KHz

signal stati : ahbstat_in_type;

signal dsurx_int   : std_logic;
signal dsutx_int   : std_logic;
signal dsuctsn_int : std_logic;
signal dsurtsn_int : std_logic;

signal dsu_sel : std_logic;

signal idelay_reset_cnt : std_logic_vector(3 downto 0);
signal idelayctrl_reset : std_logic;
signal io_ref           : std_logic;
signal io_ref_nobuf     : std_logic;

signal idelay_reset_cnt_0 : std_logic_vector(3 downto 0);
signal idelayctrl_reset_0 : std_logic;
signal io_ref_0           : std_logic;
signal io_ref_nobuf_0     : std_logic;

signal clkref           : std_logic;

signal migrstn : std_logic;

signal spmi : spimctrl_in_type;
signal spmo : spimctrl_out_type;

type eth_in_type_array  is array (4 downto 0) of eth_in_type;
type eth_out_type_array is array (4 downto 0) of eth_out_type;

signal rgmiii_fmc,rgmiii_buf_fmc : eth_in_type_array;
signal rgmiio_fmc,rgmiio_buf_fmc : eth_out_type_array;

signal gmiii_fmc : eth_in_type_array;
signal gmiio_fmc : eth_out_type_array;

signal clk125_pad, clk125_lock : std_logic;
signal clk125_pad_0, clk125_lock_0 : std_logic;

signal e1_debug_rx,e1_debug_tx,e1_debug_gtx  : std_logic_vector(63 downto 0);
type fmc_debug_type is array (0 to 3) of std_logic_vector(63 downto 0);
signal fmc_debug_rx,fmc_debug_tx,fmc_debug_gtx : fmc_debug_type;
signal fmc_debug_rx_con,fmc_debug_tx_con,fmc_debug_gtx_con : fmc_debug_type;

type tx_rgmii_debug_type is array (0 to 3) of std_logic_vector(31 downto 0);
signal debug_rgmii_phy_rx,debug_rgmii_phy_tx : tx_rgmii_debug_type;
signal debug_rgmii_phy_rxi,debug_rgmii_phy_txi : tx_rgmii_debug_type;
signal debug_rgmii_phy_rx_con,debug_rgmii_phy_tx_con : tx_rgmii_debug_type;

type cfg_eth_ipl_type is array (0 to 3) of integer;
-- Table is based upon VC707 standard Ethernet port has EDCL address 16#0033#
 constant CFG_ETH_IPL_FMC : cfg_eth_ipl_type := (16#0034#, 16#0035#, 16#0036#, 16#0037#);
 
 signal clkout0o  :    std_logic;
 signal clkout1o  :    std_logic;
 signal clkout2o  :    std_logic;    
 
 signal  int_rst : std_logic; 
 signal  PLLE2_ADV0_CLKFB : std_logic;  
 signal  clk125_nobuf, clk125 : std_logic; 
 signal  clk25_nobuf , clk25  : std_logic; 
 
 signal  int_rst_0 : std_logic; 
 signal  PLLE2_ADV0_CLKFB_0 : std_logic;  
 signal  clk125_nobuf_0, clk125_0 : std_logic; 
 signal  clk25_nobuf_0 , clk25_0  : std_logic; 

begin

----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------

  vcc <= '1'; gnd <= '0';
  cgi.pllctrl <= "00"; cgi.pllrst <= rstraw;

   clk_gen0 : if (CFG_MIG_7SERIES = 0) generate
     clk_pad_ds : clkpad_ds generic map (tech => padtech, level => sstl, voltage => x15v) port map (clk200p, clk200n, lclk);
     clkgen0 : clkgen        -- clock generator
       generic map (clktech, CFG_CLKMUL, CFG_CLKDIV, CFG_MCTRL_SDEN,CFG_CLK_NOFB, 0, 0, 0, BOARD_FREQ)
       port map (lclk, lclk, clkm, open, open, open, open, cgi, cgo, open, open, open);
   end generate;

  reset_pad : inpad generic map (tech => padtech, level => cmos, voltage => x15v) port map (reset, rst);
  rst0 : rstgen         -- reset generator
  generic map (acthigh => 1, syncin => 1)
  port map (rst, clkm, lock, rstn, rstraw);
  lock <= calib_done and clk125_lock_0 when CFG_MIG_7SERIES = 1 else cgo.clklock;

  rst1 : rstgen         -- reset generator
  generic map (acthigh => 1)
  port map (rst, clkm, '1', migrstn, open);

----------------------------------------------------------------------
---  AHB CONTROLLER --------------------------------------------------
----------------------------------------------------------------------

  ahb0 : ahbctrl       -- AHB arbiter/multiplexer
  generic map (defmast => CFG_DEFMST, split => CFG_SPLIT,
   rrobin => CFG_RROBIN, ioaddr => CFG_AHBIO, fpnpen => CFG_FPNPEN,
     nahbm => maxahbm, nahbs => maxahbs, devid => XILINX_AC701)
  port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);

----------------------------------------------------------------------
---  LEON processor and DSU -----------------------------------------
----------------------------------------------------------------------

  leon : leon_dsu_stat_base
    generic map (
      leon => CFG_LEON, ncpu => CFG_NCPU, fabtech => fabtech, memtech => memtech,
      memtechmod => CFG_LEON_MEMTECH,
      nwindows => CFG_NWIN, dsu => CFG_DSU, fpu => CFG_FPU, v8 => CFG_V8, cp => 0,
      mac => CFG_MAC, pclow => pclow, notag => 0, nwp => CFG_NWP, icen => CFG_ICEN,
      irepl => CFG_IREPL, isets => CFG_ISETS, ilinesize => CFG_ILINE,
      isetsize => CFG_ISETSZ, isetlock => CFG_ILOCK, dcen => CFG_DCEN,
      drepl => CFG_DREPL, dsets => CFG_DSETS, dlinesize => CFG_DLINE,
      dsetsize => CFG_DSETSZ, dsetlock => CFG_DLOCK, dsnoop => CFG_DSNOOP,
      ilram => CFG_ILRAMEN, ilramsize => CFG_ILRAMSZ, ilramstart => CFG_ILRAMADDR,
      dlram => CFG_DLRAMEN, dlramsize => CFG_DLRAMSZ, dlramstart => CFG_DLRAMADDR,
      mmuen => CFG_MMUEN, itlbnum => CFG_ITLBNUM, dtlbnum => CFG_DTLBNUM,
      tlb_type => CFG_TLB_TYPE, tlb_rep => CFG_TLB_REP, lddel => CFG_LDDEL,
      disas => disas, tbuf => CFG_ITBSZ, pwd => CFG_PWD, svt => CFG_SVT,
      rstaddr => CFG_RSTADDR, smp => CFG_NCPU-1, cached => CFG_DFIXED,
      wbmask => CFG_BWMASK, busw => CFG_CACHEBW, netlist => CFG_LEON_NETLIST,
      ft => CFG_LEONFT_EN, npasi => CFG_NP_ASI, pwrpsr => CFG_WRPSR,
      rex => CFG_REX, altwin => CFG_ALTWIN, mmupgsz => CFG_MMU_PAGE,
      grfpush => CFG_GRFPUSH,
      dsu_hindex => 2, dsu_haddr => 16#900#, dsu_hmask => 16#F00#, atbsz => CFG_ATBSZ,
      stat => CFG_STAT_ENABLE, stat_pindex => 13, stat_paddr => 16#100#,
      stat_pmask => 16#ffc#, stat_ncnt => CFG_STAT_CNT, stat_nmax => CFG_STAT_NMAX)
    port map (
      rstn => rstn, ahbclk => clkm, cpuclk => clkm, hclken => vcc,
      leon_ahbmi => ahbmi, leon_ahbmo => ahbmo(CFG_NCPU-1 downto 0),
      leon_ahbsi => ahbsi, leon_ahbso => ahbso,
      irqi => irqi, irqo => irqo,
      stat_apbi => apbi, stat_apbo => apbo(13), stat_ahbsi => ahbsi,
      stati => perf,
      dsu_ahbsi => ahbsi, dsu_ahbso => ahbso(2),
      dsu_tahbmi => ahbmi, dsu_tahbsi => ahbsi,
      sysi => sysi, syso => syso);

  led1_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
    port map (led(1), syso.proc_error);
  sysi.dsu_enable <= '1';
  dsui_break_pad   : inpad  generic map (level => cmos, voltage => x25v, tech => padtech)
    port map (button(0), sysi.dsu_break);
  dsuact_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
    port map (led(0), ndsuact);
  ndsuact <= not syso.dsu_active;
  
  -- Debug UART
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map (hindex => CFG_NCPU, pindex => 7, paddr => 7)
      port map (rstn, clkm, dui, duo, apbi, apbo(7), ahbmi, ahbmo(CFG_NCPU));
    dui.extclk <= '0';
  end generate;

  nouah : if CFG_AHB_UART = 0 generate
     apbo(7) <= apb_none;
     duo.txd <= '0';
     duo.rtsn <= '0';
     dui.extclk <= '0';
  end generate;


  sw4_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v)
      port map (switch(3), '0', '1', dsu_sel);

  dsutx_int   <= duo.txd     when dsu_sel = '1' else u1o.txd;
  dui.rxd     <= dsurx_int   when dsu_sel = '1' else '1';
  u1i.rxd     <= dsurx_int   when dsu_sel = '0' else '1';
  dsurtsn_int <= duo.rtsn    when dsu_sel = '1' else u1o.rtsn;
  dui.ctsn    <= dsuctsn_int when dsu_sel = '1' else '1';
  u1i.ctsn    <= dsuctsn_int when dsu_sel = '0' else '1';

  dsurx_pad   : inpad  generic map (level => cmos, voltage => x25v, tech => padtech) port map (dsurx, dsurx_int);
  dsutx_pad   : outpad generic map (level => cmos, voltage => x25v, tech => padtech) port map (dsutx, dsutx_int);
  dsuctsn_pad : inpad  generic map (level => cmos, voltage => x25v, tech => padtech) port map (dsuctsn, dsuctsn_int);
  dsurtsn_pad : outpad generic map (level => cmos, voltage => x25v, tech => padtech) port map (dsurtsn, dsurtsn_int);


  ahbjtaggen0 :if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => CFG_NCPU+CFG_AHB_UART)
      port map(rstn, clkm, tck, tms, tdi, tdo, ahbmi, ahbmo(CFG_NCPU+CFG_AHB_UART),
               open, open, open, open, open, open, open, gnd);
  end generate;

----------------------------------------------------------------------
---  SPI Memory Controller--------------------------------------------
----------------------------------------------------------------------

  spimc: if CFG_SPIMCTRL = 1 generate
    spimctrl0 : spimctrl        -- SPI Memory Controller
      generic map (hindex => 0, hirq => 1, faddr => 16#100#, fmask => 16#ff8#,
                   ioaddr => 16#002#, iomask => 16#fff#,
                   spliten => CFG_SPLIT, oepol  => 0,
                   sdcard => CFG_SPIMCTRL_SDCARD,
                   readcmd => CFG_SPIMCTRL_READCMD,
                   dummybyte => CFG_SPIMCTRL_DUMMYBYTE,
                   dualoutput => CFG_SPIMCTRL_DUALOUTPUT,
                   scaler => CFG_SPIMCTRL_SCALER,
                   altscaler => CFG_SPIMCTRL_ASCALER,
                   pwrupcnt => CFG_SPIMCTRL_PWRUPCNT)
      port map (rstn, clkm, ahbsi, ahbso(0), spmi, spmo);   


    miso_pad : inpad generic map (tech => padtech)
      port map (spi_miso, spmi.miso);
    mosi_pad : outpad generic map (tech => padtech)
      port map (spi_mosi, spmo.mosi);
    slvsel0_pad : odpad generic map (tech => padtech)
      port map (spi_sel_n, spmo.csn);  
    -- To output SPI clock use Xilinx STARTUPE2 primitive
    --sck_pad  : outpad generic map (tech => padtech)
    --  port map (spi_clk, spmo.sck);    
    STARTUPE2_inst : STARTUPE2
    generic map (
    PROG_USR => "FALSE",      
    SIM_CCLK_FREQ => 10.0     
    )
    port map (
      CFGCLK    => open ,     
      CFGMCLK   => open ,     
      EOS       => open ,     
      PREQ      => open ,     
      CLK       => '0',       
      GSR       => '0',       
      GTS       => '0',       
      KEYCLEARB => '0',       
      PACK      => '0',       
      USRCCLKO  => spmo.sck,  
      USRCCLKTS => '0',       
      USRDONEO  => '1',       
      USRDONETS => '1'        
    );    
    
  end generate;

  nospimc: if CFG_SPIMCTRL = 0 generate
    miso_pad : inpad generic map (tech => padtech)
      port map (spi_miso, spmi.miso);
    mosi_pad : outpad generic map (tech => padtech)
      port map (spi_mosi, '0');
    slvsel0_pad : odpad generic map (tech => padtech)
      port map (spi_sel_n, '1'); 
    --sck_pad  : outpad generic map (tech => padtech)
    --  port map (spi_clk, '0'); 
  end generate;

  -----------------------------------------------------------------------------
  -- L2 cache, optionally covering DDR3 SDRAM memory controller
  -----------------------------------------------------------------------------
  l2cen : if CFG_L2_EN /= 0 generate
    l2cblock : block
      signal mem_ahbsi : ahb_slv_in_type;
      signal mem_ahbso : ahb_slv_out_vector := (others => ahbs_none);
      signal mem_ahbmi : ahb_mst_in_type;
      signal mem_ahbmo : ahb_mst_out_vector := (others => ahbm_none);
      signal l2c_stato : std_logic_vector(10 downto 0);
    begin
      l2c0 : l2c generic map (
        hslvidx => 4, hmstidx => 0, cen => CFG_L2_PEN, 
        haddr => 16#400#, hmask => 16#c00#, ioaddr => 16#FF0#, 
        cached => CFG_L2_MAP, repl => CFG_L2_RAN, ways => CFG_L2_WAYS, 
        linesize => CFG_L2_LSZ, waysize => CFG_L2_SIZE,
        memtech => memtech, bbuswidth => AHBDW,
        bioaddr => 16#FFE#, biomask => 16#fff#, 
        sbus => 0, mbus => 1, arch => CFG_L2_SHARE,
        ft => CFG_L2_EDAC)
        port map(rst => rstn, clk => clkm, ahbsi => ahbsi, ahbso => ahbso(4),
                 ahbmi => mem_ahbmi, ahbmo => mem_ahbmo(0), ahbsov => mem_ahbso,
                 sto => l2c_stato);

      memahb0 : ahbctrl                -- AHB arbiter/multiplexer
        generic map (defmast => CFG_DEFMST, split => CFG_SPLIT, 
                     rrobin => CFG_RROBIN, ioaddr => 16#FFE#,
                     ioen => 1, nahbm => 1, nahbs => 1)
        port map (rstn, clkm, mem_ahbmi, mem_ahbmo, mem_ahbsi, mem_ahbso);

      mem_ahbso(0) <= mig_ahbso;
      mig_ahbsi <= mem_ahbsi;
      
      perf.event(15 downto 7) <= (others => '0');
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
      perf.req <= (others => '0');
      perf.sel <= (others => '0');
      perf.latcnt <= '0';
      --perf.timer  <= dbgi(0).timer(31 downto 0);
    end block l2cblock;
  end generate l2cen;
  nol2c : if CFG_L2_EN = 0 generate
    ahbso(4) <= mig_ahbso;
    mig_ahbsi <= ahbsi;
    perf <= l3stat_in_none;
  end generate;
  
  ----------------------------------------------------------------------
  ---  DDR3 memory controller ------------------------------------------
  ----------------------------------------------------------------------
  mig_gen : if (CFG_MIG_7SERIES = 1) generate
    gen_mig : if (USE_MIG_INTERFACE_MODEL /= true) generate
      ddrc : ahb2mig_7series generic map (
        hindex => 4*(1-CFG_L2_EN), haddr => 16#400#, hmask => 16#C00#,
        pindex => 4, paddr => 4,
        SIM_BYPASS_INIT_CAL => SIM_BYPASS_INIT_CAL,
        SIMULATION => SIMULATION, USE_MIG_INTERFACE_MODEL => USE_MIG_INTERFACE_MODEL)
        port map (
          ddr3_dq         => ddr3_dq,
          ddr3_dqs_p      => ddr3_dqs_p,
          ddr3_dqs_n      => ddr3_dqs_n,
          ddr3_addr       => ddr3_addr,
          ddr3_ba         => ddr3_ba,
          ddr3_ras_n      => ddr3_ras_n,
          ddr3_cas_n      => ddr3_cas_n,
          ddr3_we_n       => ddr3_we_n,
          ddr3_reset_n    => ddr3_reset_n,
          ddr3_ck_p       => ddr3_ck_p,
          ddr3_ck_n       => ddr3_ck_n,
          ddr3_cke        => ddr3_cke,
          ddr3_cs_n       => ddr3_cs_n,
          ddr3_dm         => ddr3_dm,
          ddr3_odt        => ddr3_odt,
          ahbsi           => mig_ahbsi,
          ahbso           => mig_ahbso,
          apbi            => apbi,
          apbo            => apbo(4),
          calib_done      => calib_done,
          rst_n_syn       => migrstn,
          rst_n_async     => rstraw,
          clk_amba        => clkm,
          sys_clk_p       => clk200p,
          sys_clk_n       => clk200n,
          clk_ref_i       => clkref,
          ui_clk          => clkm,
          ui_clk_sync_rst => open
          );
  
      clkgenmigref0 : clkgen
        generic map (clktech, 16, 8, 0,CFG_CLK_NOFB, 0, 0, 0, 100000)
        port map (clkm, clkm, clkref, open, open, open, open, cgi, cgo, open, open, open);
    end generate gen_mig;
    
    gen_mig_model : if (USE_MIG_INTERFACE_MODEL = true) generate
-- pragma translate_off  
      mig_ahbram : ahbram_sim
        generic map (
          hindex   => 4*(1-CFG_L2_EN),
          haddr    => 16#400#,
          hmask    => 16#C00#,
          tech     => 0,
          kbytes   => 1000,
          pipe     => 0,
          maccsz   => AHBDW,
          fname    => "ram.srec"
          )
        port map(
          rst     => rstn,
          clk     => clkm,
          ahbsi   => mig_ahbsi,
          ahbso   => mig_ahbso
          );
  
      ddr3_dq           <= (others => 'Z');
      ddr3_dqs_p        <= (others => 'Z');
      ddr3_dqs_n        <= (others => 'Z');
      ddr3_addr         <= (others => '0');
      ddr3_ba           <= (others => '0');
      ddr3_ras_n        <= '0';
      ddr3_cas_n        <= '0';
      ddr3_we_n         <= '0';
      ddr3_reset_n      <= '1';
      ddr3_ck_p         <= (others => '0');
      ddr3_ck_n         <= (others => '0');
      ddr3_cke          <= (others => '0');
      ddr3_cs_n         <= (others => '0');
      ddr3_dm           <= (others => '0');
      ddr3_odt          <= (others => '0');
      
      calib_done <= '1';
      
      clkm <= not clkm after 5.0 ns;
      -- pragma translate_on
    end generate gen_mig_model;
  end generate;

  no_mig_gen : if (CFG_MIG_7SERIES = 0) generate  
    
    ahbram0 : ahbram 
      generic map (hindex => 4*(1-CFG_L2_EN), haddr => 16#400#, tech => CFG_MEMTECH, kbytes => 128)
      port map ( rstn, clkm, mig_ahbsi, mig_ahbso);
   
    ddrdummy0 : ddr_dummy
      port map (
        ddr_dq      => ddr3_dq,
        ddr_dqs     => ddr3_dqs_p,
        ddr_dqs_n   => ddr3_dqs_n,
        ddr_addr    => ddr3_addr,
        ddr_ba      => ddr3_ba,
        ddr_ras_n   => ddr3_ras_n,
        ddr_cas_n   => ddr3_cas_n,
        ddr_we_n    => ddr3_we_n,
        ddr_reset_n => ddr3_reset_n,
        ddr_ck_p    => ddr3_ck_p,
        ddr_ck_n    => ddr3_ck_n,
        ddr_cke     => ddr3_cke,
        ddr_cs_n    => ddr3_cs_n,
        ddr_dm      => ddr3_dm,
        ddr_odt     => ddr3_odt
        ); 
       
    calib_done <= '1';
  end generate no_mig_gen;

  led2_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
     port map (led(2), calib_done);
  led3_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
     port map (led(3), lock);

-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

    eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC
      e1 : grethm
       generic map(
        hindex => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG,
        pindex => 14, paddr => 16#C00#, pmask => 16#C00#, pirq => 3, memtech => memtech,
        mdcscaler => CPU_FREQ/1000, rmii => 0, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
        nsync => 2, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF, phyrstadr => 7,
        macaddrh => CFG_ETH_ENM, macaddrl => CFG_ETH_ENL, enable_mdint => 1,
        ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_ETH_IPL,
        giga => CFG_GRETH1G, ramdebug => 0, gmiimode => 1)
       port map( rst => rstn, clk => clkm, ahbmi => ahbmi,
        ahbmo => ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG),
        apbi => apbi, apbo => apbo(14), ethi => ethi, etho => etho);

    -----------------------------------------------------------------------------
    -- An IDELAYCTRL primitive needs to be instantiated for the Fixed Tap Delay
    -- mode of the IDELAY.
    -- All IDELAYs in Fixed Tap Delay mode and the IDELAYCTRL primitives have
    -- to be LOC'ed in the UCF file.
    -----------------------------------------------------------------------------
    dlyctrl0 : IDELAYCTRL port map (
       RDY    => OPEN,
       REFCLK => io_ref_0,
       RST    => idelayctrl_reset_0
    );

      delay_rgmii_rx_ctl0 : IODELAYE1 generic map(
         DELAY_SRC   => "I",
         IDELAY_TYPE => "FIXED",
         IDELAY_VALUE => 20
      )
      port map(
         IDATAIN     => rgmiii_buf.rx_dv,
         ODATAIN     => '0',
         DATAOUT     => rgmiii.rx_dv,
         DATAIN      => '0',
         C           => '0',
         T           => '1',
         CE          => '0',
         INC         => '0',
         CINVCTRL    => '0',
         CLKIN       => '0',
         CNTVALUEIN  => "00000",
         CNTVALUEOUT => OPEN,
         RST         => '0'
      );

     rgmii_rxd : for i in 0 to 3 generate
      delay_rgmii_rxd0 : IODELAYE1 generic map(
         DELAY_SRC   => "I",
         IDELAY_TYPE => "FIXED",
         IDELAY_VALUE => 20
      )
      port map(
         IDATAIN     => rgmiii_buf.rxd(i),
         ODATAIN     => '0',
         DATAOUT     => rgmiii.rxd(i),
         DATAIN      => '0',
         C           => '0',
         T           => '1',
         CE          => '0',
         INC         => '0',
         CINVCTRL    => '0',
         CLKIN       => '0',
         CNTVALUEIN  => "00000",
         CNTVALUEOUT => OPEN,
         RST         => '0'
      );
     end generate;

   -- Generate a synchron delayed reset for Xilinx IO delay
   rst1 : rstgen
    generic map (acthigh => 1)
    port map (rst, io_ref_0, lock, rstgtxn_0, OPEN);

   process (io_ref_0,rstgtxn_0)
    begin
     if (rstgtxn_0 = '0') then
       idelay_reset_cnt_0 <= (others => '0');
       idelayctrl_reset_0 <= '1';
     elsif rising_edge(io_ref_0) then
       if (idelay_reset_cnt_0 > "1110") then
          idelay_reset_cnt_0 <= (others => '1');
          idelayctrl_reset_0 <= '0';
       else
          idelay_reset_cnt_0 <= idelay_reset_cnt_0 + 1;
          idelayctrl_reset_0 <= '1';
       end if;
     end if;
   end process;

    -- RGMII Interface
    --rgmii0 : rgmii generic map (pindex => 11, paddr => 16#010#, pmask => 16#ff0#, tech => fabtech,
    --                           gmii => CFG_GRETH1G, debugmem => 0, abits => 8, no_clk_mux => 1,
    --                           pirq => 11, use90degtxclk => 1)
    --  port map (rstn, ethi, etho, rgmiii, rgmiio, clkm, rstn, apbi, apbo(11));

    rgmii0 : rgmii_series7 
      generic map (
       pindex => 11, paddr => 16#010#, pmask => 16#ff0#, tech => fabtech,
       gmii => CFG_GRETH1G, abits => 8, pirq => 11, base10_x => 0)
      port map (rstn, ethi, etho, rgmiii, rgmiio, clkm, rstn, apbi, apbo(11),
                debug_rgmii_phy_txi(0), debug_rgmii_phy_rxi(0)); 

      egtxc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v, slew => 1) 
        port map (phy_txclk, rgmiio.tx_clk);

      erxc_pad : inpad generic map (tech => padtech, level => cmos, voltage => x25v) 
        port map (phy_rxclk, rgmiii.rx_clk);

      erxd_pad : inpadv generic map (tech => padtech, level => cmos, voltage => x25v, width => 4) 
        port map (phy_rxd, rgmiii_buf.rxd(3 downto 0));

      erxdv_pad : inpad generic map (tech => padtech, level => cmos, voltage => x25v) 
        port map (phy_rxctl_rxdv, rgmiii_buf.rx_dv);

      etxd_pad : outpadv generic map (tech => padtech, level => cmos, voltage => x25v, slew => 1, width => 4) 
        port map (phy_txd, rgmiio.txd(3 downto 0));

      etxen_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v, slew => 1) 
        port map (phy_txctl_txen, rgmiio.tx_en);

      emdio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v) 
        port map (phy_mdio, rgmiio.mdio_o, rgmiio.mdio_oe, rgmiii.mdio_i);

      emdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
        port map (phy_mdc, rgmiio.mdc);

      rgmiii.mdint <= '0'; -- No interrupt on Marvell 88E1116R PHY
      erst_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
        port map (phy_reset, rstraw);

       sfp_clock_mux_pad : outpadv generic map (tech => padtech, level => cmos, voltage => x25v, width => 2) 
        port map (sfp_clock_mux, "00");

      ---- GTX Clock
      ----rgmiii.gtx_clk   <= gtx_clk;
      
      -- 125MHz input clock
      ibufds_gtrefclk : IBUFDS_GTE2
      port map (
         I     => gtrefclk_p,
         IB    => gtrefclk_n,
         CEB   => '0',
         O     => gtx_clk_nobuf,
         ODIV2 => open
      );

     --cgi2.pllctrl <= "00"; cgi2.pllrst <= rstraw;     
     --clkgen_gtrefclk : clkgen
     --  generic map (clktech, 8, 8, 0, 0, 0, 0, 0, 125000)
     --  port map (gtx_clk_nobuf, gtx_clk_nobuf, gtx_clk, rgmiii.tx_clk_90, io_ref, open, open, cgi2, cgo2, open, open, open);

    -- Generate 125MHz, 50MHz and 25Mhz Clock transmit clock
    int_rst_0 <= not rstraw;   
    PLLE2_ADV0 : PLLE2_ADV
    generic map (
       BANDWIDTH          => "OPTIMIZED",  -- OPTIMIZED, HIGH, LOW
       CLKFBOUT_MULT      => 16,   -- Multiply value for all CLKOUT, (2-64)
       CLKFBOUT_PHASE     => 0.0, -- Phase offset in degrees of CLKFB, (-360.000-360.000).
       -- CLKIN_PERIOD: Input clock period in nS to ps resolution (i.e. 33.333 is 30 MHz).
       CLKIN1_PERIOD      => 8.0,
       CLKIN2_PERIOD      => 0.0,
       -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT (1-128)
       CLKOUT0_DIVIDE     => 8,
       CLKOUT1_DIVIDE     => 10,
       CLKOUT2_DIVIDE     => 20,
       CLKOUT3_DIVIDE     => 40,
       CLKOUT4_DIVIDE     => 1,
       CLKOUT5_DIVIDE     => 4,
       -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT outputs (0.001-0.999).
       CLKOUT0_DUTY_CYCLE => 0.5,
       CLKOUT1_DUTY_CYCLE => 0.5,
       CLKOUT2_DUTY_CYCLE => 0.5,
       CLKOUT3_DUTY_CYCLE => 0.5,
       CLKOUT4_DUTY_CYCLE => 0.5,
       CLKOUT5_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT5_PHASE: Phase offset for CLKOUT outputs (-360.000-360.000).
       CLKOUT0_PHASE      => 0.0,
       CLKOUT1_PHASE      => 0.0,
       CLKOUT2_PHASE      => 0.0,
       CLKOUT3_PHASE      => 0.0,
       CLKOUT4_PHASE      => 0.0,
       CLKOUT5_PHASE      => 0.0,
       COMPENSATION       => "ZHOLD", -- ZHOLD, BUF_IN, EXTERNAL, INTERNAL
       DIVCLK_DIVIDE      => 2, -- Master division value (1-56)
       -- REF_JITTER: Reference input jitter in UI (0.000-0.999).
       REF_JITTER1        => 0.0,
       REF_JITTER2        => 0.0,
       STARTUP_WAIT       => "TRUE" -- Delay DONE until PLL Locks, ("TRUE"/"FALSE")
      )
    port map (
       -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
       CLKOUT0           => clk125_nobuf_0,
       CLKOUT1           => OPEN,
       CLKOUT2           => OPEN,
       CLKOUT3           => clk25_nobuf_0,
       CLKOUT4           => OPEN,
       CLKOUT5           => io_ref_nobuf_0,
       -- DRP Ports: 16-bit (each) output: Dynamic reconfigration ports
       DO                => OPEN,
       DRDY              => OPEN,
       -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
       CLKFBOUT          => PLLE2_ADV0_CLKFB_0,
       -- Status Ports: 1-bit (each) output: PLL status ports
       LOCKED            => clk125_lock_0,
       -- Clock Inputs: 1-bit (each) input: Clock inputs
       CLKIN1            => gtx_clk_nobuf,
       CLKIN2            => '0',
       -- Con trol Ports: 1-bit (each) input: PLL control ports
       CLKINSEL          => '1',
       PWRDWN            => '0',
       RST               => int_rst_0, 
       -- DRP Ports: 7-bit (each) input: Dynamic reconfigration ports
       DADDR             => "0000000", 
       DCLK              => '0',
       DEN               => '0',
       DI                => "0000000000000000", 
       DWE               => '0',
       -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
       CLKFBIN           => PLLE2_ADV0_CLKFB_0
      );     
   
        bufgclk1250  : BUFG port map (I => clk125_nobuf_0, O => clk125_0);    
        bufgclk250   : BUFG port map (I => clk25_nobuf_0 , O => clk25_0 );    
        bufgclkIO0   : BUFG port map (I => io_ref_nobuf_0 , O => io_ref_0 );    

        rgmiii.gtx_clk    <= clk125_0;   
        rgmiii.tx_clk_100 <= '0';
        rgmiii.tx_clk_90  <= '0';
        rgmiii.tx_clk_50  <= '0';
        rgmiii.tx_clk_25  <= clk25_0;   
        rgmiii.rmii_clk   <= '0';

    end generate;

    noeth0 : if CFG_GRETH = 0 generate
      -- TODO:
    end generate;

    eth1 : if CFG_GRETH_FMC = 1 generate -- Extended FMC Support
    
    -- Reset Out
    reset_port_0_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (reset_port_0, rstn);       
    reset_port_1_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (reset_port_1, rstn);       
    reset_port_2_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (reset_port_2, rstn);       
    reset_port_3_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (reset_port_3, rstn);       
    
    -- Clock input and select 
    ref_clk_oe_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (ref_clk_oe, '0');  
    -- Select 125MHz ref clock
    ref_clk_fsel_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (ref_clk_fsel, '0');
    
    -- Input ref clock buffer
    -- Note: Better to use internal 125MHz clock for all variants....
    -- FOR AC701 re-use clocks from main RGMII GRETH interface
    clk125_pad  <= clk125_0;
    clk125      <= clk125_0;
    clk25       <= clk25_0;
    io_ref      <= io_ref_0;
    clk125_lock <= '1';
    
    -- Add APB CTRL for GRETH Cores
    apb1 : apbctrl            -- AHB/APB bridge
     generic map (hindex => 5, haddr => 16#A00#, hmask => 16#F00#, nslaves => 16)
     port map (rstn, clkm, ahbsi, ahbso(5), apbi1, apbo1 );
  
    eth1_fmc : for i in 0 to 4-1 generate

     e1 : grethm 
      generic map(
       hindex => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+i+1, 
       pindex => i, paddr => 16#010#*i, pmask => 16#FFF#, pirq => i, memtech => memtech,
       mdcscaler => CPU_FREQ/1000, rmii => 0, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
       nsync => 2, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF, phyrstadr => 0,
       macaddrh => CFG_ETH_ENM, macaddrl => CFG_ETH_ENL, enable_mdint => 1,
       ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_ETH_IPL_FMC(i),
       giga => CFG_GRETH1G, ramdebug => 0, gmiimode => 0, rgmiimode => 0)
      port map( rst => rstn, clk => clkm, ahbmi => ahbmi,
       ahbmo => ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+i+1), 
       apbi => apbi1, apbo => apbo1(i), ethi => gmiii_fmc(i+1), etho => gmiio_fmc(i+1),
       debug_rx => fmc_debug_rx(i), debug_tx => fmc_debug_tx(i), debug_gtx => fmc_debug_gtx(i)
       );       

     rgmii0 : rgmii_series7 
      generic map (
       pindex => i+CFG_FMC, paddr => 16#010#*i+16#010#*(CFG_FMC), pmask => 16#ff0#, tech => fabtech,
       gmii => CFG_GRETH1G, abits => 8, pirq => i+CFG_FMC, base10_x => 0)
      port map (rstn, gmiii_fmc(i+1), gmiio_fmc(i+1), rgmiii_fmc(i), rgmiio_fmc(i), clkm, rstn, apbi1, apbo1(i+CFG_FMC),
                debug_rgmii_phy_tx(i), debug_rgmii_phy_rx(i)); 

    end generate eth1_fmc;

    ----------------------------------------------------------------------------------------------------------------------
    -- RGMII FMC Ethernet Debug section
    -- Note 1: See Ethernet core for correct triggers
    -- Note 2: Uncomment to use 
    eth1_fmc_dbg : if CFG_FMC_DBG = 1 generate
      debug_rgmii_phy_rx_con(0) <= '0' & debug_rgmii_phy_rx(0)(30 downto 0);
      phy_rx_logan0 : logan
        generic map (dbits=>32,depth=>2048,trigl=>1,usereg=>0,usequal=>0, pindex => 13, paddr => 16#D00#, memtech => memtech)
        port map (rstn, clkm, debug_rgmii_phy_rx(0)(31), apbi1, apbo1(13), debug_rgmii_phy_rx_con(0));  
      debug_rgmii_phy_tx_con(0) <= '0' & debug_rgmii_phy_tx(0)(30 downto 0);
      phy_tx_logan0 : logan
        generic map (dbits=>32,depth=>2048,trigl=>1,usereg=>0,usequal=>0, pindex => 14, paddr => 16#E00#, memtech => memtech)
        port map (rstn, clkm, debug_rgmii_phy_tx(0)(31), apbi1, apbo1(14), debug_rgmii_phy_tx_con(0)); 
      ---- Debug of RX and TX
      fmc_debug_rx_con(0) <= '0' & fmc_debug_rx(0)(62 downto 0);
      fmc_loganrx0 : logan
        generic map (dbits=>64,depth=>2048,trigl=>1,usereg=>0,usequal=>0, pindex => 10, paddr => 16#A00#, memtech => memtech)
        port map (rstn, clkm, fmc_debug_rx(0)(63), apbi1, apbo1(10), fmc_debug_rx_con(0));  
      fmc_debug_tx_con(0) <= '0' & fmc_debug_tx(0)(62 downto 0);
      fmc_logantx0 : logan
        generic map (dbits=>64,depth=>2048,trigl=>1,usereg=>0,usequal=>0, pindex => 11, paddr => 16#B00#, memtech => memtech)
        port map (rstn, clkm, fmc_debug_tx(0)(63), apbi1, apbo1(11), fmc_debug_tx_con(0)); 
      fmc_debug_gtx_con(0) <= '0' & fmc_debug_gtx(0)(62 downto 0);
      fmc_logangtx0 : logan
        generic map (dbits=>64,depth=>2048,trigl=>1,usereg=>0,usequal=>0, pindex => 12, paddr => 16#C00#, memtech => memtech)
        port map (rstn, clkm, fmc_debug_gtx(0)(63), apbi1, apbo1(12), fmc_debug_gtx_con(0)); 
    end generate eth1_fmc_dbg;

    -- RGMII Ref Clocks
    -- Note: 50Mhz clock used for 10Mb mode only
    eth1_fmc_clk : for i in 0 to 4-1 generate
      rgmiii_fmc(i).gtx_clk    <= clk125;   
      rgmiii_fmc(i).tx_clk_100 <= '0';
      rgmiii_fmc(i).tx_clk_90  <= '0';
      rgmiii_fmc(i).tx_clk_50  <= '0';
      rgmiii_fmc(i).tx_clk_25  <= clk25;   
      rgmiii_fmc(i).rmii_clk   <= '0';
    end generate eth1_fmc_clk;

    -- RGMII Ports   
    -- Note: Port levels set by XDC file
    rgmiii_fmc(0).rx_clk              <= rgmii_port_0_rxc;
    rgmiii_buf_fmc(0).rx_dv           <= rgmii_port_0_rx_ctl;
    rgmiii_buf_fmc(0).rxd(3 downto 0) <= rgmii_port_0_rd;
    rgmii_port_0_txc                  <= rgmiio_buf_fmc(0).tx_clk;
    rgmii_port_0_tx_ctl               <= rgmiio_fmc(0).tx_en;
    rgmii_port_0_td                   <= rgmiio_fmc(0).txd(3 downto 0);
    
    rgmiii_fmc(1).rx_clk              <= rgmii_port_1_rxc;
    rgmiii_buf_fmc(1).rx_dv           <= rgmii_port_1_rx_ctl;
    rgmiii_buf_fmc(1).rxd(3 downto 0) <= rgmii_port_1_rd;
    rgmii_port_1_txc                  <= rgmiio_buf_fmc(1).tx_clk;
    rgmii_port_1_tx_ctl               <= rgmiio_fmc(1).tx_en;
    rgmii_port_1_td                   <= rgmiio_fmc(1).txd(3 downto 0);

    rgmiii_fmc(2).rx_clk              <= rgmii_port_2_rxc;
    rgmiii_buf_fmc(2).rx_dv           <= rgmii_port_2_rx_ctl;
    rgmiii_buf_fmc(2).rxd(3 downto 0) <= rgmii_port_2_rd;
    rgmii_port_2_txc                  <= rgmiio_buf_fmc(2).tx_clk;
    rgmii_port_2_tx_ctl               <= rgmiio_fmc(2).tx_en;
    rgmii_port_2_td                   <= rgmiio_fmc(2).txd(3 downto 0);

    rgmiii_fmc(3).rx_clk              <= rgmii_port_3_rxc;
    rgmiii_buf_fmc(3).rx_dv           <= rgmii_port_3_rx_ctl;
    rgmiii_buf_fmc(3).rxd(3 downto 0) <= rgmii_port_3_rd;
    rgmii_port_3_txc                  <= rgmiio_buf_fmc(3).tx_clk;
    rgmii_port_3_tx_ctl               <= rgmiio_fmc(3).tx_en;
    rgmii_port_3_td                   <= rgmiio_fmc(3).txd(3 downto 0);

    -- Insert delay blocks for inputs
    eth1_rgmii_d : for i in 0 to 4-1 generate

    rgmiio_buf_fmc(i).tx_clk <= rgmiio_fmc(i).tx_clk;

     delay_rgmii_rx_ctl0 : IODELAYE1 generic map(
       DELAY_SRC   => "I",
       IDELAY_TYPE => "FIXED",
       IDELAY_VALUE => 20
      )
      port map(
       IDATAIN     => rgmiii_buf_fmc(i).rx_dv,
       ODATAIN     => '0',
       DATAOUT     => rgmiii_fmc(i).rx_dv,
       DATAIN      => '0',
       C           => '0',
       T           => '1',
       CE          => '0',
       INC         => '0',
       CINVCTRL    => '0',
       CLKIN       => '0',
       CNTVALUEIN  => "00000",
       CNTVALUEOUT => OPEN,
       RST         => '0'
      );

     rgmii_rxd : for j in 0 to 3 generate
      delay_rgmii_rxd0 : IODELAYE1 generic map(
       DELAY_SRC   => "I",
       IDELAY_TYPE => "FIXED",
       IDELAY_VALUE => 20
      )
      port map(
       IDATAIN     => rgmiii_buf_fmc(j).rxd(i),
       ODATAIN     => '0',
       DATAOUT     => rgmiii_fmc(j).rxd(i),
       DATAIN      => '0',
       C           => '0',
       T           => '1',
       CE          => '0',
       INC         => '0',
       CINVCTRL    => '0',
       CLKIN       => '0',
       CNTVALUEIN  => "00000",
       CNTVALUEOUT => OPEN,
       RST         => '0'
      );
      rgmiii_fmc(j).rxd(i+4) <= '0';
     end generate rgmii_rxd;

    end generate eth1_rgmii_d;
     
    -- MDIO IO
    mdio_io_port_0_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v) 
      port map (mdio_io_port_0_mdio_io, rgmiio_fmc(0).mdio_o, rgmiio_fmc(0).mdio_oe, rgmiii_fmc(0).mdio_i);

    mdio_io_port_0_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
     port map (mdio_io_port_0_mdc, rgmiio_fmc(0).mdc);

    mdio_io_port_1_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v) 
      port map (mdio_io_port_1_mdio_io, rgmiio_fmc(1).mdio_o, rgmiio_fmc(1).mdio_oe, rgmiii_fmc(1).mdio_i);
    mdio_io_port_1_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
     port map (mdio_io_port_1_mdc, rgmiio_fmc(1).mdc);

    mdio_io_port_2_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v) 
      port map (mdio_io_port_2_mdio_io, rgmiio_fmc(2).mdio_o, rgmiio_fmc(2).mdio_oe, rgmiii_fmc(2).mdio_i);
    mdio_io_port_2_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
     port map (mdio_io_port_2_mdc, rgmiio_fmc(2).mdc);

    mdio_io_port_3_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v) 
      port map (mdio_io_port_3_mdio_io, rgmiio_fmc(3).mdio_o, rgmiio_fmc(3).mdio_oe, rgmiii_fmc(3).mdio_i);
    mdio_io_port_3_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
     port map (mdio_io_port_3_mdc, rgmiio_fmc(3).mdc);       
     
  end generate eth1;

  noeth1 : if CFG_GRETH_FMC = 0 generate -- Extended FMC Support

    clk125_lock <= '1';

    -- Reset Out
    reset_port_0_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (reset_port_0, '0');       
    reset_port_1_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (reset_port_1, '0');       
    reset_port_2_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (reset_port_2, '0');       
    reset_port_3_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (reset_port_3, '0');   

    -- Clock input and select 
    ref_clk_oe_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (ref_clk_oe, '0');  
    -- Select 125MHz ref clock
    ref_clk_fsel_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
    port map (ref_clk_fsel, '0');

    -- MDIO IO
     mdio_io_port_0_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v) 
       port map (mdio_io_port_0_mdio_io, '0','0', rgmiii_fmc(0).mdio_i);
     mdio_io_port_0_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
      port map (mdio_io_port_0_mdc, '0');

     mdio_io_port_1_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v) 
       port map (mdio_io_port_1_mdio_io, '0', '0', rgmiii_fmc(1).mdio_i);
     mdio_io_port_1_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
      port map (mdio_io_port_1_mdc, '0');

     mdio_io_port_2_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v) 
       port map (mdio_io_port_2_mdio_io, '0', '0', rgmiii_fmc(2).mdio_i);
     mdio_io_port_2_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
      port map (mdio_io_port_2_mdc, '0');

     mdio_io_port_3_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v) 
       port map (mdio_io_port_3_mdio_io, '0', '0', rgmiii_fmc(3).mdio_i);
     mdio_io_port_3_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
      port map (mdio_io_port_3_mdc, '0');  
    
    -- RGMII Ports   
    rgmiii_fmc(0).rx_clk              <= '0';
    rgmiii_buf_fmc(0).rx_dv           <= '0';
    rgmiii_buf_fmc(0).rxd(3 downto 0) <= (others => '0');
    rgmii_port_0_txc                  <= '0';
    rgmii_port_0_tx_ctl               <= '0';
    rgmii_port_0_td                   <= (others => '0');
    
    rgmiii_fmc(1).rx_clk              <= '0';
    rgmiii_buf_fmc(1).rx_dv           <= '0';
    rgmiii_buf_fmc(1).rxd(3 downto 0) <= (others => '0');
    rgmii_port_1_txc                  <= '0';
    rgmii_port_1_tx_ctl               <= '0';
    rgmii_port_1_td                   <= (others => '0');

    rgmiii_fmc(2).rx_clk              <= '0';
    rgmiii_buf_fmc(2).rx_dv           <= '0';
    rgmiii_buf_fmc(2).rxd(3 downto 0) <= (others => '0');
    rgmii_port_2_txc                  <= '0';
    rgmii_port_2_tx_ctl               <= '0';
    rgmii_port_2_td                   <= (others => '0');

    rgmiii_fmc(3).rx_clk              <= '0';
    rgmiii_buf_fmc(3).rx_dv           <= '0';
    rgmiii_buf_fmc(3).rxd(3 downto 0) <= (others => '0');
    rgmii_port_3_txc                  <= '0';
    rgmii_port_3_tx_ctl               <= '0';
    rgmii_port_3_td                   <= (others => '0');
  end generate noeth1;

----------------------------------------------------------------------
---  I2C Controller --------------------------------------------------
----------------------------------------------------------------------

   --i2cm: if CFG_I2C_ENABLE = 1 generate  -- I2C master
    i2c0 : i2cmst generic map (pindex => 9, paddr => 9, pmask => 16#FFF#, pirq => 4, filter => 9)
      port map (rstn, clkm, apbi, apbo(9), i2ci, i2co);

    i2c_scl_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v)
      port map (iic_scl, i2co.scl, i2co.scloen, i2ci.scl);

    i2c_sda_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v)
      port map (iic_sda, i2co.sda, i2co.sdaoen, i2ci.sda);
  --end generate i2cm;

----------------------------------------------------------------------
---  SPI Controller --------------------------------------------------
----------------------------------------------------------------------

  spic: if CFG_SPICTRL_ENABLE = 1 generate  -- SPI controller
    spi1 : spictrl
      generic map (pindex => 12, paddr  => 12, pmask  => 16#fff#, pirq => 12,
                   fdepth => CFG_SPICTRL_FIFO, slvselen => CFG_SPICTRL_SLVREG,
                   slvselsz => CFG_SPICTRL_SLVS, odmode => 0, netlist => 0,
                   syncram => CFG_SPICTRL_SYNCRAM, ft => CFG_SPICTRL_FT)
      port map (rstn, clkm, apbi, apbo(12), spii, spio, slvsel);
    spii.spisel <= '1';                 -- Master only
    miso_pad : inpad generic map (level => cmos, voltage => x18v,tech => padtech)
      port map (sdcard_spi_miso, spii.miso);
    mosi_pad : outpad generic map (level => cmos, voltage => x18v,tech => padtech)
      port map (sdcard_spi_mosi, spio.mosi);
    sck_pad  : outpad generic map (level => cmos, voltage => x18v,tech => padtech)
      port map (sdcard_spi_clk, spio.sck);
    slvsel_pad : outpad generic map (level => cmos, voltage => x18v,tech => padtech)
      port map (sdcard_spi_cs_b, slvsel(0));
  end generate spic;

  nospi: if CFG_SPICTRL_ENABLE = 0 generate
    miso_pad : inpad generic map (level => cmos, voltage => x25v,tech => padtech)
      port map (sdcard_spi_miso, spii.miso);
    mosi_pad : outpad generic map (level => cmos, voltage => x25v,tech => padtech)
      port map (sdcard_spi_mosi, '1');
    sck_pad  : outpad generic map (level => cmos, voltage => x25v,tech => padtech)
      port map (sdcard_spi_clk, '0');
    slvsel_pad : outpad generic map (level => cmos, voltage => x25v,tech => padtech)
      port map (sdcard_spi_cs_b, '1');
  end generate;

----------------------------------------------------------------------
---  APB Bridge and various periherals -------------------------------
----------------------------------------------------------------------

  apb0 : apbctrl            -- AHB/APB bridge
  generic map (hindex => 1, haddr => CFG_APBADDR, nslaves => 16, debug => 2)
  port map (rstn, clkm, ahbsi, ahbso(1), apbi, apbo );

  irqctrl : if CFG_IRQ3_ENABLE /= 0 generate
    irqctrl0 : irqmp         -- interrupt controller
    generic map (pindex => 2, paddr => 2, ncpu => CFG_NCPU)
    port map (rstn, clkm, apbi, apbo(2), irqo, irqi);
  end generate;
  irq3 : if CFG_IRQ3_ENABLE = 0 generate
    x : for i in 0 to CFG_NCPU-1 generate
      irqi(i).irl <= "0000";
    end generate;
    apbo(2) <= apb_none;
  end generate;

  gpt : if CFG_GPT_ENABLE /= 0 generate
    timer0 : gptimer          -- timer unit
    generic map (pindex => 3, paddr => 3, pirq => CFG_GPT_IRQ,
   sepirq => CFG_GPT_SEPIRQ, sbits => CFG_GPT_SW, ntimers => CFG_GPT_NTIM,
   nbits => CFG_GPT_TW, wdog => CFG_GPT_WDOGEN*CFG_GPT_WDOG)
    port map (rstn, clkm, apbi, apbo(3), gpti, gpto);
    gpti <= gpti_dhalt_drive(syso.dsu_tstop);
  end generate;

  nogpt : if CFG_GPT_ENABLE = 0 generate apbo(3) <= apb_none; end generate;

  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate     -- GPIO unit
    grgpio0: grgpio
    generic map(pindex => 10, paddr => 10, imask => CFG_GRGPIO_IMASK, nbits => 7)
    port map(rst => rstn, clk => clkm, apbi => apbi, apbo => apbo(10),
    gpioi => gpioi, gpioo => gpioo);
    pio_pads : for i in 0 to 2 generate
        pio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v)
            port map (switch(i), gpioo.dout(i), gpioo.oen(i), gpioi.din(i));
    end generate;
    pio_pads2 : for i in 3 to 5 generate
        pio_pad : inpad generic map (tech => padtech, level => cmos, voltage => x15v)
            port map (button(i-2), gpioi.din(i));
    end generate;
  end generate;

  ua1 : if CFG_UART1_ENABLE /= 0 generate
    uart1 : apbuart                     -- UART 1
      generic map (pindex   => 1, paddr => 1, pirq => 2, console => dbguart,
         fifosize => CFG_UART1_FIFO)
      port map (rstn, clkm, apbi, apbo(1), u1i, u1o);
      u1i.extclk <= '0';
  end generate;
  noua0 : if CFG_UART1_ENABLE = 0 generate apbo(1) <= apb_none; end generate;

  ahbs : if CFG_AHBSTAT = 1 generate   -- AHB status register
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat generic map (pindex => 15, paddr => 15, pirq => 7,
   nftslv => CFG_AHBSTATN)
      port map (rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(15));
  end generate;

-----------------------------------------------------------------------
---  AHB ROM ----------------------------------------------------------
-----------------------------------------------------------------------

  bpromgen : if CFG_AHBROMEN /= 0 generate
    brom : entity work.ahbrom
      generic map (hindex => 7, haddr => CFG_AHBRODDR, pipe => CFG_AHBROPIP)
      port map ( rstn, clkm, ahbsi, ahbso(7));
  end generate;

-----------------------------------------------------------------------
---  AHB RAM ----------------------------------------------------------
-----------------------------------------------------------------------

  ocram : if CFG_AHBRAMEN = 1 and CFG_GRETH_FMC = 0 generate
    ahbram0 : ahbram generic map (hindex => 5, haddr => CFG_AHBRADDR,
   tech => CFG_MEMTECH, kbytes => CFG_AHBRSZ)
    port map ( rstn, clkm, ahbsi, ahbso(5));
  end generate;

-----------------------------------------------------------------------
---  Test report module  ----------------------------------------------
-----------------------------------------------------------------------

  -- pragma translate_off
  test0 : ahbrep generic map (hindex => 3, haddr => 16#200#)
    port map (rstn, clkm, ahbsi, ahbso(3));
  -- pragma translate_on

 -----------------------------------------------------------------------
 ---  Drive unused bus elements  ---------------------------------------
 -----------------------------------------------------------------------

  nam1 : for i in (CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+CFG_GRETH+CFG_FMC) to NAHBMST-1 generate
    ahbmo(i) <= ahbm_none;
  end generate;

 -----------------------------------------------------------------------
 ---  Boot message  ----------------------------------------------------
 -----------------------------------------------------------------------

 -- pragma translate_off
   x : report_design
   generic map (
    msg1 => "LEON3 Xilinx AC701 Demonstration design",
    fabtech => tech_table(fabtech), memtech => tech_table(memtech),
    mdel => 1
   );
 -- pragma translate_on
 end;

