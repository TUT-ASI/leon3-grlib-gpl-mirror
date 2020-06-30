-----------------------------------------------------------------------------
--  LEON3/LEON4 Xilinx KC705 Demonstration design
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
use gaisler.spi.all;
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

library esa;
use esa.memoryctrl.all;

use work.config.all;

entity leon5mp is
  generic (
    fabtech             : integer := CFG_FABTECH;
    memtech             : integer := CFG_MEMTECH;
    padtech             : integer := CFG_PADTECH;
    clktech             : integer := CFG_CLKTECH;
    disas               : integer := CFG_DISAS;   -- Enable disassembly to console
    ahbtrace            : integer := CFG_AHBTRACE;
    SIM_BYPASS_INIT_CAL : string := "OFF";
    SIMULATION          : string := "FALSE";
    USE_MIG_INTERFACE_MODEL : boolean := false
  );
  port (
    reset           : in    std_ulogic;
    clk200p         : in    std_ulogic;  -- 200 MHz clock
    clk200n         : in    std_ulogic;  -- 200 MHz clock
    address         : out   std_logic_vector(25 downto 0);
    data            : inout std_logic_vector(15 downto 0);
    oen             : out   std_ulogic;
    writen          : out   std_ulogic;
    romsn           : out   std_logic;
    adv             : out   std_logic;
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
    led             : out   std_logic_vector(6 downto 0);
    iic_scl         : inout std_ulogic;
    iic_sda         : inout std_ulogic;
    gtrefclk_p      : in    std_logic;
    gtrefclk_n      : in    std_logic;
    phy_gtxclk      : out   std_logic;
    phy_txd         : out   std_logic_vector(3 downto 0);
    phy_txctl_txen  : out   std_ulogic;
    phy_rxd         : in    std_logic_vector(3 downto 0);
    phy_rxctl_rxdv  : in    std_ulogic;
    phy_rxclk       : in    std_ulogic;
    phy_reset       : out   std_ulogic;
    phy_mdio        : inout std_logic;
    phy_mdc         : out   std_ulogic;
    phy_int         : in    std_ulogic
   );
end;

architecture rtl of leon5mp is

component ahb2axi_mig_7series 
  generic(
    hindex                  : integer := 0;
    haddr                   : integer := 0;
    hmask                   : integer := 16#f00#;
    pindex                  : integer := 0;
    paddr                   : integer := 0;
    pmask                   : integer := 16#fff#
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
end component;

component axi_mig_7series is
  generic(
    hindex                  : integer := 0;
    haddr                   : integer := 0;
    hmask                   : integer := 16#f00#;
    pindex                  : integer := 0;
    paddr                   : integer := 0;
    pmask                   : integer := 16#fff#
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
    aximi             : out   axi_somi_type;
    aximo             : in    axi_mosi_type;
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


--constant maxahbm : integer := CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+CFG_GRETH;
constant maxahbm : integer := 16;
constant maxahbs : integer := 16;
constant maxapbs : integer := CFG_IRQ3_ENABLE+CFG_GPT_ENABLE+CFG_GRGPIO_ENABLE+CFG_AHBSTAT+CFG_AHBSTAT;

signal vcc, gnd   : std_logic;
signal memi  : memory_in_type;
signal memo  : memory_out_type;
signal wpo   : wprot_out_type;
               
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

signal clk125_pad : std_logic;
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
signal  clk125_nobuf_0, clk125_nobuf_90, clk125_0, clk125_90 : std_logic; 
signal  clk25_nobuf_0 , clk25_0  : std_logic; 
signal  clk25_nobuf_90 , clk25_90  : std_logic; 

signal aximi : axi_somi_type;
signal aximo : axi_mosi_type;

signal dsuen, cpu0errn, dsubreak : std_ulogic;

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
constant hdidx_free    : integer := hdidx_greth   + CFG_GRETH;
constant l5sys_ndbgmst : integer := max(hdidx_free, 1);

constant hsidx_mctrl   : integer := 0;
constant hsidx_l2c     : integer := hsidx_mctrl  + CFG_MCTRL_LEON2;
constant hsidx_mig     : integer := hsidx_l2c    + CFG_L2_EN;
constant hsidx_ahbram  : integer := hsidx_mig    + CFG_MIG_7SERIES;
constant hsidx_ahbrom  : integer := hsidx_ahbram + CFG_AHBRAMEN;
constant hsidx_ahbrep  : integer := hsidx_ahbrom + CFG_AHBROMEN;
constant hsidx_free    : integer := hsidx_ahbrep
--pragma translate_off
                                    + 1
--pragma translate_on
                                    ;
constant l5sys_nextslv : integer := max(hsidx_free, 1);

constant pidx_ahbuart  : integer := 0;
constant pidx_mctrl    : integer := pidx_ahbuart + CFG_AHB_UART;
constant pidx_mig      : integer := pidx_mctrl   + CFG_MCTRL_LEON2;
constant pidx_greth    : integer := pidx_mig     + 1;
constant pidx_rgmii    : integer := pidx_greth   + CFG_GRETH;
constant pidx_ahbstat  : integer := pidx_rgmii   + CFG_GRETH;
constant pidx_i2cmst   : integer := pidx_ahbstat + CFG_AHBSTAT;
constant pidx_free     : integer := pidx_i2cmst  + CFG_I2C_ENABLE;
constant l5sys_nextapb : integer := pidx_free;

signal ahbmi: ahb_mst_in_type;
signal ahbmo: ahb_mst_out_vector_type(CFG_NCPU+l5sys_nextmst-1 downto CFG_NCPU);
signal ahbsi: ahb_slv_in_type;
signal ahbso: ahb_slv_out_vector_type(l5sys_nextslv-1 downto 0);
signal dbgmi: ahb_mst_in_vector_type(l5sys_ndbgmst-1 downto 0);
signal dbgmo: ahb_mst_out_vector_type(l5sys_ndbgmst-1 downto 0);

signal greth_dbgmi: ahb_mst_in_type;
signal greth_dbgmo: ahb_mst_out_type;

signal apbi  : apb_slv_in_type;
signal apbo  : apb_slv_out_vector := (others => apb_none);

signal mig_ahbsi : ahb_slv_in_type;                            
signal mig_ahbso : ahb_slv_out_type;

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
  generic map (acthigh => 1, syncin => 0)
  port map (rst, clkm, lock, rstn, rstraw);
  lock <= calib_done and clk125_lock_0 when CFG_MIG_7SERIES = 1 else cgo.clklock;

  rst1 : rstgen         -- reset generator
  generic map (acthigh => 1)
  port map (rst, clkm, '1', migrstn, open);

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
      cached   => CFG_DFIXED,
      wbmask   => CFG_BWMASK,
      busw     => CFG_AHBW,
      fpuconf  => CFG_FPUTYPE,
      disas    => disas,
      ahbtrace => ahbtrace
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

  led1_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
    port map (led(1), cpu0errn);

  dsui_break_pad   : inpad  generic map (level => cmos, voltage => x25v, tech => padtech)
    port map (button(0), dsubreak);
  
  dsuact_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
    port map (led(0), dsuen);
  
  
  -- Debug UART
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map (hindex => hdidx_ahbuart, pindex => pidx_ahbuart, paddr => 7)
      port map (rstn, clkm, dui, duo, apbi, apbo(pidx_ahbuart), dbgmi(hdidx_ahbuart), dbgmo(hdidx_ahbuart));
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

  -----------------------------------------------------------------------------
  -- JTAG debug link
  -----------------------------------------------------------------------------
  ahbjtaggen0 :if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => hdidx_ahbjtag)
      port map(rstn, clkm, tck, tms, tdi, tdo, dbgmi(hdidx_ahbjtag), dbgmo(hdidx_ahbjtag),
               open, open, open, open, open, open, open, gnd);
  end generate;

----------------------------------------------------------------------
---  Memory controllers ----------------------------------------------
----------------------------------------------------------------------

  memi.writen <= '1'; memi.wrn <= "1111"; memi.bwidth <= "01";
  memi.brdyn <= '0'; memi.bexcn <= '1';

  mctrl_gen : if CFG_MCTRL_LEON2 /= 0 and CFG_SPIMCTRL = 0 generate
    mctrl0 : mctrl generic map (hindex => hsidx_mctrl, pindex => pidx_mctrl,
     paddr => 0, srbanks => 2, ram8 => CFG_MCTRL_RAM8BIT,
     ram16 => CFG_MCTRL_RAM16BIT, sden => CFG_MCTRL_SDEN,
     invclk => CFG_CLK_NOFB, sepbus => CFG_MCTRL_SEPBUS,
     pageburst => CFG_MCTRL_PAGE, rammask => 0, iomask => 0)
    port map (rstn, clkm, memi, memo, ahbsi, ahbso(hsidx_mctrl), apbi, apbo(pidx_mctrl), wpo, open);

    addr_pad : outpadv generic map (width => 26, tech => padtech, level => cmos, voltage => x25v)
     port map (address(25 downto 0), memo.address(26 downto 1));
    roms_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v)
     port map (romsn, memo.romsn(0));
    oen_pad  : outpad generic map (tech => padtech, level => cmos, voltage => x25v)
     port map (oen, memo.oen);
    adv_pad  : outpad generic map (tech => padtech, level => cmos, voltage => x25v)
     port map (adv, '0');
    wri_pad  : outpad generic map (tech => padtech, level => cmos, voltage => x25v)
     port map (writen, memo.writen);
    data_pad : iopadvv generic map (tech => padtech, width => 16, level => cmos, voltage => x25v)
        port map (data(15 downto 0), memo.data(31 downto 16),
     memo.vbdrive(31 downto 16), memi.data(31 downto 16));
  end generate;

----------------------------------------------------------------------
---  SPI Memory Controller--------------------------------------------
----------------------------------------------------------------------

  spimc: if CFG_SPIMCTRL = 1 and CFG_MCTRL_LEON2 = 0 generate
    spimctrl0 : spimctrl        -- SPI Memory Controller
      generic map (hindex => hsidx_mctrl, hirq => 1, faddr => 16#100#, fmask => 16#ff8#,
                   ioaddr => 16#002#, iomask => 16#fff#,
                   spliten => CFG_SPLIT, oepol  => 0,
                   sdcard => CFG_SPIMCTRL_SDCARD,
                   readcmd => CFG_SPIMCTRL_READCMD,
                   dummybyte => CFG_SPIMCTRL_DUMMYBYTE,
                   dualoutput => CFG_SPIMCTRL_DUALOUTPUT,
                   scaler => CFG_SPIMCTRL_SCALER,
                   altscaler => CFG_SPIMCTRL_ASCALER,
                   pwrupcnt => CFG_SPIMCTRL_PWRUPCNT)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_mctrl), spmi, spmo);   


    miso_pad : inpad generic map (tech => padtech)
      port map (data(1), spmi.miso);
    mosi_pad : outpad generic map (tech => padtech)
      port map (data(0), spmo.mosi);
    slvsel0_pad : odpad generic map (tech => padtech)
      port map (romsn, spmo.csn);  
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

----------------------------------------------------------------------
---  Memory controllers ----------------------------------------------
----------------------------------------------------------------------

  nomctrl : if CFG_MCTRL_LEON2 = 0 and CFG_SPIMCTRL = 0 generate
    roms_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v)
     port map (romsn, vcc);
  end generate;

  mctrl_error_gen : if CFG_MCTRL_LEON2 /= 0 and CFG_SPIMCTRL = 1 generate
     x : process
     begin
       assert false
       report  "Xilins KC705 Ref design do not support Quad SPI Flash Memory and Linear BPI flash memory at the same time"
       severity failure;
       wait;
     end process;
  end generate;

  -----------------------------------------------------------------------------
  -- L2 cache, optionally covering DDR3 SDRAM memory controller
  -----------------------------------------------------------------------------
  l2cen : if CFG_L2_EN /= 0 generate
    l2cblock : block
      signal l2c_stato : std_logic_vector(10 downto 0);
    begin
      l2c0 : l2c_axi_be generic map (
        hslvidx => hsidx_l2c, axiid => 0, cen => CFG_L2_PEN, 
        haddr => 16#400#, hmask => 16#c00#, ioaddr => 16#FF0#, 
        cached => CFG_L2_MAP, repl => CFG_L2_RAN, ways => CFG_L2_WAYS, 
        linesize => CFG_L2_LSZ, waysize => CFG_L2_SIZE,
        memtech => memtech, sbus => 0, mbus => 0, arch => CFG_L2_SHARE,
        ft => CFG_L2_EDAC, stat => 2)
        port map(rst => rstn, clk => clkm, ahbsi => ahbsi, ahbso => ahbso(hsidx_l2c),
                 aximi => aximi, aximo => aximo,
                 sto => l2c_stato);

      ddrc: axi_mig_7series generic map (
        hindex => 9, haddr => 16#400#, hmask => 16#F00#,
        pindex => 4, paddr => 4)
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
          aximi           => aximi,
          aximo           => aximo,
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
    ahbso(hsidx_mig) <= mig_ahbso;
    mig_ahbsi <= ahbsi;
    perf <= l3stat_in_none;
  end generate;
  
  ----------------------------------------------------------------------
  ---  DDR3 memory controller ------------------------------------------
  ----------------------------------------------------------------------
  mig_gen : if (CFG_MIG_7SERIES = 1) and CFG_L2_EN = 0  generate
    gen_mig : if (USE_MIG_INTERFACE_MODEL /= true) generate
      ddrc : ahb2axi_mig_7series generic map(
        hindex => hsidx_mig*(1-CFG_L2_EN), haddr => 16#400#, hmask => 16#C00#,
        pindex => pidx_mig, paddr => 4)
        port map(
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
          apbo            => apbo(pidx_mig),
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
          hindex   => hsidx_mig*(1-CFG_L2_EN),
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
    
--pragma translate_off
    -- LOC for DDR3 i/f not included when MIG is disabled.
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
--pragma translate_on
    calib_done <= '1';
  end generate no_mig_gen;

  led2_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
     port map (led(2), calib_done);
  led3_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
     port map (led(3), lock);

-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

  edcl0 : if (CFG_GRETH=1 and CFG_DSU_ETH=1) generate
    greth_dbgmi <= dbgmi(hdidx_greth);
    dbgmo(hdidx_greth) <= greth_dbgmo;
  end generate;
  noedcl0 : if not (CFG_GRETH=1 and CFG_DSU_ETH=1) generate
    greth_dbgmi <= ahbm_in_none;
  end generate;

  eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC
    e1 : grethm_mb
      generic map(
        hindex => hmidx_greth, ehindex => hdidx_greth,
        pindex => pidx_greth, paddr => 16#C00#, pmask => 16#C00#, pirq => 3, memtech => memtech,
        mdcscaler => CPU_FREQ/1000, rmii => 0, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
        nsync => 2, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF, phyrstadr => 7,
        macaddrh => CFG_ETH_ENM, macaddrl => CFG_ETH_ENL, enable_mdint => 1,
        ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_ETH_IPL,
        giga => CFG_GRETH1G, ramdebug => 0, gmiimode => 0,
        edclsepahb => 1)
      port map(
        rst   => rstn,
        clk   => clkm,
        ahbmi => ahbmi,
        ahbmo => ahbmo(hmidx_greth),
        ahbmi2 => greth_dbgmi,
        ahbmo2 => greth_dbgmo,
        apbi  => apbi,
        apbo  => apbo(pidx_greth),
        ethi  => ethi,
        etho  => etho);

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
    rgmii0 : rgmii_kc705 
      generic map (
       pindex => pidx_rgmii, paddr => 16#010#, pmask => 16#ff0#, tech => fabtech,
       gmii => CFG_GRETH1G,edclsepahb => 1, abits => 8, pirq => 11, base10_x => 0)
      port map (rstn, ethi, etho, rgmiii, rgmiio, clkm, rstn, apbi, apbo(pidx_rgmii),
                debug_rgmii_phy_tx(0), debug_rgmii_phy_rx(0)); 
    
  
      egtxc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v, slew => 1) 
        port map (phy_gtxclk, rgmiio.tx_clk);

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

      eint_pad : inpad generic map (tech => padtech, level => cmos, voltage => x25v) 
        port map (phy_int, rgmiii.mdint);
      erst_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v) 
        port map (phy_reset, rstraw);

    -- Generate 125MHz, 50MHz and 25Mhz Clock transmit clock
    -- 100*20/8*2  -> 125 MHz
    -- 100*20/40*2 -> 25  Mhz
    -- 100*20/4*2  -> 250 Mhz
    int_rst_0 <= not rstraw;   
    PLLE2_ADV0 : PLLE2_ADV
    generic map (
       BANDWIDTH          => "OPTIMIZED",  -- OPTIMIZED, HIGH, LOW
       CLKFBOUT_MULT      => 20,   -- Multiply value for all CLKOUT, (2-64)
       CLKFBOUT_PHASE     => 0.0, -- Phase offset in degrees of CLKFB, (-360.000-360.000).
       -- CLKIN_PERIOD: Input clock period in nS to ps resolution (i.e. 33.333 is 30 MHz).
       CLKIN1_PERIOD      => 10.0,
       CLKIN2_PERIOD      => 0.0,
       -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT (1-128)
       CLKOUT0_DIVIDE     => 8,
       CLKOUT1_DIVIDE     => 8,
       CLKOUT2_DIVIDE     => 20,
       CLKOUT3_DIVIDE     => 40,
       CLKOUT4_DIVIDE     => 40,
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
       CLKOUT1_PHASE      => 90.0,
       CLKOUT2_PHASE      => 0.0,
       CLKOUT3_PHASE      => 0.0,
       CLKOUT4_PHASE      => 90.0,
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
       CLKOUT1           => clk125_nobuf_90,
       CLKOUT2           => OPEN,
       CLKOUT3           => clk25_nobuf_0,
       CLKOUT4           => clk25_nobuf_90,
       CLKOUT5           => io_ref_nobuf_0,
       -- DRP Ports: 16-bit (each) output: Dynamic reconfigration ports
       DO                => OPEN,
       DRDY              => OPEN,
       -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
       CLKFBOUT          => PLLE2_ADV0_CLKFB_0,
       -- Status Ports: 1-bit (each) output: PLL status ports
       LOCKED            => clk125_lock_0,
       -- Clock Inputs: 1-bit (each) input: Clock inputs
       CLKIN1            => clkm,
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
   
        bufgclk1250  : BUFG port map (I => clk125_nobuf_0 , O => clk125_0 );    
        bufgclk12590 : BUFG port map (I => clk125_nobuf_90, O => clk125_90);    
        bufgclk250   : BUFG port map (I => clk25_nobuf_0  , O => clk25_0  );    
        bufgclk2500  : BUFG port map (I => clk25_nobuf_90 , O => clk25_90 );    
        bufgclkIO0   : BUFG port map (I => io_ref_nobuf_0 , O => io_ref_0 );    

        rgmiii.gtx_clk    <= clk125_0;   
        rgmiii.tx_clk_100 <= '0';
        rgmiii.tx_clk_90  <= clk125_90;
        rgmiii.tx_clk_50  <= clk25_90;
        rgmiii.tx_clk_25  <= clk25_0;   
        rgmiii.rmii_clk   <= '0';

    end generate;


----------------------------------------------------------------------
---  I2C Controller --------------------------------------------------
----------------------------------------------------------------------

   i2cm: if CFG_I2C_ENABLE = 1 generate  -- I2C master
    i2c0 : i2cmst generic map (pindex => pidx_i2cmst, paddr => 9, pmask => 16#FFF#, pirq => 4, filter => 9)
      port map (rstn, clkm, apbi, apbo(pidx_i2cmst), i2ci, i2co);

    i2c_scl_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v)
      port map (iic_scl, i2co.scl, i2co.scloen, i2ci.scl);

    i2c_sda_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v)
      port map (iic_sda, i2co.sda, i2co.sdaoen, i2ci.sda);
  end generate i2cm;

-----------------------------------------------------------------------
---  AHBSTAT  ---------------------------------------------------------
-----------------------------------------------------------------------

  ahbs : if CFG_AHBSTAT = 1 generate   -- AHB status register
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat generic map (pindex => pidx_ahbstat, paddr => 15, pirq => 7,
   nftslv => CFG_AHBSTATN)
      port map (rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(pidx_ahbstat));
  end generate;

-----------------------------------------------------------------------
---  AHB ROM ----------------------------------------------------------
-----------------------------------------------------------------------

  bpromgen : if CFG_AHBROMEN /= 0 generate
    brom : entity work.ahbrom
      generic map (hindex => hsidx_ahbrom, haddr => CFG_AHBRODDR, pipe => CFG_AHBROPIP)
      port map ( rstn, clkm, ahbsi, ahbso(hsidx_ahbrom));
  end generate;

-----------------------------------------------------------------------
---  AHB RAM ----------------------------------------------------------
-----------------------------------------------------------------------

  ocram : if CFG_AHBRAMEN = 1 generate
    ahbram0 : ahbram generic map (hindex => hsidx_ahbram, haddr => CFG_AHBRADDR,
   tech => CFG_MEMTECH, kbytes => CFG_AHBRSZ, pipe => CFG_AHBRPIPE)
    port map ( rstn, clkm, ahbsi, ahbso(hsidx_ahbram));
  end generate;

-----------------------------------------------------------------------
---  Test report module  ----------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  test0 : ahbrep generic map (hindex => hsidx_ahbrep, haddr => 16#200#)
    port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbrep));
  -- pragma translate_on


 -----------------------------------------------------------------------
 ---  Boot message  ----------------------------------------------------
 -----------------------------------------------------------------------

 -- pragma translate_off
   x : report_design
   generic map (
    msg1 => "LEON/GRLIB Xilinx KC705 Demonstration design",
    fabtech => tech_table(fabtech), memtech => tech_table(memtech),
    mdel => 1
   );
 -- pragma translate_on
 end;

