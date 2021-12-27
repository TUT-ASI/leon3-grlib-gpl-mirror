-----------------------------------------------------------------------------
--  LEON3/LEON4 CPCI-XC7K demonstration design
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
use gaisler.leon4.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.spi.all;
use gaisler.i2c.all;
use gaisler.pci.all;
use gaisler.can.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.l2cache.all;
use gaisler.gr1553b_pkg.all;
use gaisler.subsys.all;
use gaisler.spacewire.all;
-- pragma translate_off
use gaisler.sim.all;
library unisim;
use unisim.all;
-- pragma translate_on
library esa;
use esa.memoryctrl.all;
use esa.pcicomp.all;
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
    SIM_BYPASS_INIT_CAL     : string  := "OFF";
    SIMULATION              : string  := "FALSE";
    USE_MIG_INTERFACE_MODEL : boolean := false
  );
  port (
    resetn          : in    std_ulogic;
    clk             : in    std_ulogic;
    --
    a               : out   std_logic_vector(24 downto 0);
    d               : inout std_logic_vector(7 downto 0);
    oen             : out   std_ulogic;
    writen          : out   std_ulogic;
    csn             : out   std_logic_vector(5 downto 0);
    --
-- pragma translate_off  
    jtag_tck        : in    std_logic; 
    jtag_tms        : in    std_logic;
    jtag_tdi        : in    std_logic;
    jtag_tdo        : out   std_logic;  -- just needed for simulation,
				        -- automatically created by AHBJTAG in
			        	-- synthesis
-- pragma translate_on
    --
    ddr3_dq         : inout std_logic_vector(15 downto 0);
    ddr3_dqs_p      : inout std_logic_vector(1 downto 0);
    ddr3_dqs_n      : inout std_logic_vector(1 downto 0);
    ddr3_addr       : out   std_logic_vector(14 downto 0);
    ddr3_ba         : out   std_logic_vector(2 downto 0);
    ddr3_ras_n      : out   std_logic;
    ddr3_cas_n      : out   std_logic;
    ddr3_we_n       : out   std_logic;
    ddr3_reset_n    : out   std_logic;
    ddr3_ck_p       : out   std_logic_vector(0 downto 0);
    ddr3_ck_n       : out   std_logic_vector(0 downto 0);
    ddr3_cke        : out   std_logic_vector(0 downto 0);
    ddr3_cs_n       : out   std_logic_vector(0 downto 0);
    ddr3_dm         : out   std_logic_vector(1 downto 0);
    ddr3_odt        : out   std_logic_vector(0 downto 0);
    --
    dsurx           : in    std_ulogic;
    dsutx           : out   std_ulogic;
    --
    switch          : inout std_logic_vector(5 downto 0);
    gpio            : inout std_logic_vector(31 downto 0);
-- pragma translate_off
    led             : out   std_logic_vector(6 downto 0);  -- just needed for
							   -- simulation to
							   -- calibrate the
							   -- ddr3 model
-- pragma translate_on
    --
    iic_scl         : inout std_ulogic;
    iic_sda         : inout std_ulogic;
    --
    uart_txd        : out   std_logic_vector(4 downto 0);
    uart_rxd        : in    std_logic_vector(4 downto 0);
    uart_ctsn       : in    std_logic_vector(1 downto 0);
    uart_rtsn       : out   std_logic_vector(1 downto 0);
    --
    cantxa          : out std_logic;
    cantxb          : out std_logic;
    canrxa          : in  std_logic;
    canrxb          : in  std_logic;
    cansela         : out std_logic;
    canselb         : out std_logic;
    
    m0_d            : inout std_logic_vector(3 downto 0);
    m0_sck          : out   std_logic;
    m0_slvsel       : out   std_logic_vector(1 downto 0);
    m1_d            : inout std_logic_vector(3 downto 0);
    m1_sck          : out   std_logic;
    m1_slvsel       : out   std_logic_vector(1 downto 0);
    spi_d           : inout std_logic_vector(3 downto 0);
    spi_cs          : out   std_logic;
    --
    eth_gtxclk      : out   std_logic;
    eth_mdio        : inout std_logic;
    eth_txclk       : in    std_ulogic;
    eth_rxclk       : in    std_ulogic;
    eth_rxd         : in    std_logic_vector(7 downto 0);   
    eth_rxdv        : in    std_ulogic; 
    eth_rxer        : in    std_ulogic; 
    eth_col         : in    std_ulogic;
    eth_crs         : in    std_ulogic;
    eth_mdint       : in    std_ulogic;
    eth_txd         : out   std_logic_vector(7 downto 0);   
    eth_txen        : out   std_ulogic; 
    eth_txer        : out   std_ulogic; 
    eth_mdc         : out   std_ulogic;
    -- SPW
    spwclk          : in  std_ulogic;
    spw_rxd         : in  std_logic_vector(0 to 5);
    spw_rxs         : in  std_logic_vector(0 to 5);
    spw_txd         : out std_logic_vector(0 to 5);
    spw_txs         : out std_logic_vector(0 to 5);
    -- PCI
    pci_rst     : inout std_logic;             
    pci_clk     : in std_logic;
    pci_gnt     : in std_logic;
    pci_idsel   : in std_logic; 
    pci_lock    : inout std_logic;
    pci_ad      : inout std_logic_vector(31 downto 0);
    pci_cbe     : inout std_logic_vector(3 downto 0);
    pci_frame   : inout std_logic;
    pci_irdy    : inout std_logic;
    pci_trdy    : inout std_logic;
    pci_devsel  : inout std_logic;
    pci_stop    : inout std_logic;
    pci_perr    : inout std_logic;
    pci_par     : inout std_logic;    
    pci_req     : inout std_logic;
    pci_serr    : inout std_logic;
    pci_host    : in std_logic;
    pci_int     : inout std_logic_vector(0 downto 0);
    pci_arb_req : in  std_logic_vector(0 to 3);
    pci_arb_gnt : out std_logic_vector(0 to 3);
    -- Mil1553
    m1553clk        : in    std_ulogic;
    m1553rxa        : in    std_ulogic;
    m1553rxb        : in    std_ulogic;
    m1553rxena      : out   std_ulogic;
    m1553rxenb      : out   std_ulogic;
    m1553rxna       : in    std_ulogic;
    m1553rxnb       : in    std_ulogic;
    m1553txa        : out   std_ulogic;
    m1553txb        : out   std_ulogic;
    m1553txinha     : out   std_ulogic;
    m1553txinhb     : out   std_ulogic;
    m1553txna       : out   std_ulogic;
    m1553txnb       : out   std_ulogic
   );
end;


architecture rtl of leon3mp is

  component ahb2mig_7series_cpci_xc7k is
    generic (
      hindex		      : integer;
      haddr		      : integer;
      hmask		      : integer;
      pindex		      : integer;
      paddr		      : integer;
      pmask		      : integer;
      maxwriteburst	      : integer;
      maxreadburst	      : integer;
      SIM_BYPASS_INIT_CAL     : string;
      SIMULATION	      : string;
      USE_MIG_INTERFACE_MODEL : boolean);
    port (
      ddr3_dq	      : inout std_logic_vector(15 downto 0);
      ddr3_dqs_p      : inout std_logic_vector(1 downto 0);
      ddr3_dqs_n      : inout std_logic_vector(1 downto 0);
      ddr3_addr	      : out   std_logic_vector(14 downto 0);
      ddr3_ba	      : out   std_logic_vector(2 downto 0);
      ddr3_ras_n      : out   std_logic;
      ddr3_cas_n      : out   std_logic;
      ddr3_we_n	      : out   std_logic;
      ddr3_reset_n    : out   std_logic;
      ddr3_ck_p	      : out   std_logic_vector(0 downto 0);
      ddr3_ck_n	      : out   std_logic_vector(0 downto 0);
      ddr3_cke	      : out   std_logic_vector(0 downto 0);
      ddr3_dm	      : out   std_logic_vector(1 downto 0);
      ddr3_odt	      : out   std_logic_vector(0 downto 0);
      ddr3_cs_n       : out   std_logic_vector(0 downto 0);
      ahbso	      : out   ahb_slv_out_type;
      ahbsi	      : in    ahb_slv_in_type;
      apbi	      : in    apb_slv_in_type;
      apbo	      : out   apb_slv_out_type;
      calib_done      : out   std_logic;
      rst_n_syn	      : in    std_logic;
      rst_n_async     : in    std_logic;
      clk_amba	      : in    std_logic;
      sys_clk_i	      : in    std_logic;
      clk_ref_i       : in    std_logic;
      ui_clk	      : out   std_logic;
      ui_clk_sync_rst : out   std_logic);
  end component ahb2mig_7series_cpci_xc7k;

component ddr_dummy
  port (
    ddr_dq           : inout std_logic_vector(15 downto 0);
    ddr_dqs          : inout std_logic_vector(1 downto 0);
    ddr_dqs_n        : inout std_logic_vector(1 downto 0);
    ddr_addr         : out   std_logic_vector(14 downto 0);
    ddr_ba           : out   std_logic_vector(2 downto 0);
    ddr_ras_n        : out   std_logic;
    ddr_cas_n        : out   std_logic;
    ddr_we_n         : out   std_logic;
    ddr_reset_n      : out   std_logic;
    ddr_ck_p         : out   std_logic_vector(0 downto 0);
    ddr_ck_n         : out   std_logic_vector(0 downto 0);
    ddr_cke          : out   std_logic_vector(0 downto 0);
    ddr_cs_n         : out   std_logic_vector(0 downto 0);
    ddr_dm           : out   std_logic_vector(1 downto 0);
    ddr_odt          : out   std_logic_vector(0 downto 0)
   );
end component ;

-- pragma translate_off
component ahbram_sim
  generic (
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#fff#;
    tech    : integer := DEFMEMTECH; 
    kbytes  : integer := 1;
    pipe    : integer := 0;
    maccsz  : integer := AHBDW;
    fname   : string  := "ram.dat"
   );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type
  );
end component ;
-- pragma translate_on

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
     DELAY_SRC    : string := "I";
     IDELAY_TYPE  : string := "DEFAULT";
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

component BUFG port (O : out std_logic; I : in std_logic); end component;

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

constant maxahbm : integer := 16;
constant maxahbs : integer := 16;
constant maxapbs : integer := CFG_IRQ3_ENABLE+CFG_GPT_ENABLE+CFG_GRGPIO_ENABLE+CFG_AHBSTAT+CFG_AHBSTAT;

signal vcc, gnd   : std_logic;
signal memi  : memory_in_type;
signal memo  : memory_out_type;
signal wpo   : wprot_out_type;
signal tmp_csn : std_logic_vector(5 downto 0);

signal apb0i,apb1i  : apb_slv_in_type;
signal apb0o,apb1o  : apb_slv_out_vector := (others => apb_none);
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
signal rstn, rst_1, rstraw, sdclkl : std_ulogic;
signal clk_200 : std_ulogic;
signal clk25, clk40, clk65 : std_ulogic;

signal cgi, cgi2            : clkgen_in_type;
signal cgo, cgo_mig, cgo2   : clkgen_out_type;

signal u1i, u2i, dui : uart_in_type;
signal u1o, u2o, duo : uart_out_type;

signal irqi : irq_in_vector(0 to CFG_NCPU-1);
signal irqo : irq_out_vector(0 to CFG_NCPU-1);

signal gmiii : eth_in_type;
signal gmiio : eth_out_type;

signal rgmiii,rgmiii_buf : eth_in_type;
signal rgmiio : eth_out_type;

signal sgmiii :  eth_sgmii_in_type;
signal sgmiio :  eth_sgmii_out_type;

signal sgmiirst : std_logic;

signal ethernet_phy_int : std_logic;

signal rxd1 : std_logic;
signal txd1 : std_logic;

signal ethi : eth_in_type;
signal etho : eth_out_type;
signal gtx_clk,gtx_clk_nobuf,gtx_clk90 : std_ulogic;
signal rstgtxn : std_logic;

signal gpti : gptimer_in_type;
signal gpto : gptimer_out_type;

-- CAN
signal can0i, can1i : can_in_type;
signal can0o, can1o : can_out_type;

signal gpioi0, gpioi1, gpioi2 : gpio_in_type;
signal gpioo0, gpioo1, gpioo2 : gpio_out_type;

signal clklock, elock, ulock : std_ulogic;
signal egtx_clk : std_ulogic;

signal lock, calib_done, clkml, lclk, lclk1, rst, ndsuact : std_ulogic;
signal tck, tckn, tms, tdi, tdo : std_ulogic;

signal dvi_i2ci : i2c_in_type;
signal dvi_i2co : i2c_out_type;

signal i2cmi, i2csi  : i2c_in_type;
signal i2cmo, i2cso  : i2c_out_type;


constant BOARD_FREQ : integer := 50000;   -- input frequency in KHz
constant CPU_FREQ : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;  -- cpu frequency in KHz
constant OEPOL : integer := padoen_polarity(padtech);

signal stati : ahbstat_in_type;

signal dsurx_int   : std_logic;
signal dsutx_int   : std_logic;
signal dsuctsn_int : std_logic;
signal dsurtsn_int : std_logic;

signal dsu_sel : std_logic;

signal idelay_reset_cnt : std_logic_vector(3 downto 0);
signal idelayctrl_reset : std_logic;
signal io_ref           : std_logic;

signal clkref           : std_logic;

signal migrstn : std_logic;

signal pciclk                       : std_logic;
signal pci_lclk                     : std_logic;
signal pcii                         : pci_in_type;
signal pcio                         : pci_out_type;
signal pci_arb_req_n, pci_arb_gnt_n : std_logic_vector(0 to 3);
signal pci_dirq                     : std_logic_vector(3 downto 0);
signal pci_66                       : std_logic           := '0'; -- dummy signal

signal uarti : uart_in_vector_type (4 downto 0);
signal uarto : uart_out_vector_type(4 downto 0);

signal spmi : spimctrl_in_type;
signal spmo : spimctrl_out_type;
signal spmi1 : spimctrl_in_type;
signal spmo1 : spimctrl_out_type;
signal qspmi : spimctrl_in_type;
signal qspmo : spimctrl_out_type;

constant blength : integer := 12;
constant fifodepth : integer := 8;
  
-- MIL-STD-1553B
signal gr1553_clk       : std_ulogic;
signal gr1553_codec_rst : std_ulogic;
signal gr1553_txout     : gr1553b_txout_type;
signal gr1553_rxin      : gr1553b_rxin_type;
signal gr1553_auxin     : gr1553b_auxin_type;
signal gr1553_auxout    : gr1553b_auxout_type;

signal spwi : grspw_in_type_vector(0 to 5);
signal spwo : grspw_out_type_vector(0 to 5);
signal lspwclk   : std_ulogic;
signal spw_rxclk : std_logic_vector(0 to CFG_SPW_NUM-1);
signal dtmp : std_logic_vector(0 to CFG_SPW_NUM-1);
signal stmp : std_logic_vector(0 to CFG_SPW_NUM-1);
signal spw_rxtxclk : std_ulogic;
signal spw_rxclkn  : std_ulogic;




--attribute syn_keep : boolean;
--attribute syn_preserve : boolean;
attribute keep                  : string;

--attribute syn_keep of clkml : signal is true;
attribute keep of clkml : signal is "true";
--attribute syn_preserve of clkml : signal is true;
--attribute syn_keep of clkm : signal is true;
--attribute syn_preserve of clkm : signal is true;
attribute keep of egtx_clk : signal is "true";
--attribute syn_preserve of egtx_clk : signal is true;



-- Bus masters: recursively calculating AHB masters' indexes depending on xconfig

-- CPUs must have the first IDs:
constant JTAG_AHBM_INDEX         : integer := CFG_NCPU;
constant AHBUART_AHBM_INDEX      : integer := JTAG_AHBM_INDEX    + CFG_AHB_JTAG;
constant GRETH_AHBM_INDEX        : integer := AHBUART_AHBM_INDEX + CFG_AHB_UART;
constant PCI_AHBM_INDEX          : integer := GRETH_AHBM_INDEX   + CFG_GRETH;
-- count target and master just as a single AHB master:
constant PCI_DMA_AHBM_INDEX      : integer := PCI_AHBM_INDEX     + CFG_GRPCI2_MASTER+CFG_GRPCI2_TARGET-(CFG_GRPCI2_MASTER*CFG_GRPCI2_TARGET);
-- keep into account also that PCI 1 can be selected instead of PCI2
constant GRCAN0_AHBM_INDEX       : integer := PCI_DMA_AHBM_INDEX + CFG_GRPCI2_DMA + CFG_PCI; 
constant GRCAN1_AHBM_INDEX       : integer := GRCAN0_AHBM_INDEX  + CFG_GRCAN;
constant SPWIRE_AHBM_INDEX       : integer := GRCAN1_AHBM_INDEX  + CFG_GRCAN;
constant SPWIRE_LAST_AHBM_INDEX  : integer := SPWIRE_AHBM_INDEX  + CFG_SPW_NUM-1;
constant GR1553B_AHBM_INDEX      : integer := SPWIRE_AHBM_INDEX  + CFG_SPW_NUM;
constant FIRST_DUMMY_AHBM_INDEX  : integer := GR1553B_AHBM_INDEX + 1;


--                         AHB Bus slaves 
-- +-------------------------+----+-------------------------+
-- | Address range           | ID | Description             |
-- +-------------------------+----+-------------------------+
-- | 0x00000000 - 0x000fffff |  0 | MCTRL (PROM)            |
-- | 0x40000000 - 0x4001ffff |  - | -     (RAM)             |
-- |                         |  1 | AHBROM                  |
-- |                         |  2 |                         |
-- |                         |  3 | Test report module      |(Just in simulation)
-- |                         |  4 | L2 cache                |
-- |                         |  5 |                         |
-- | 0x80000000 - 0x800fffff |  6 | APBCTRL0                |
-- | 0x80100000 - 0x801fffff |  7 | APBCTRL1                |
-- |                         |  8 |                         |
-- |                         |  9 | DSU                     |  
-- |                         | 10 | PCI                     |
-- |                         | 11 |                         |
-- |                         | 12 |                         |
-- |                         | 13 |                         |
-- |                         | 14 |                         |
-- |                         | 15 |                         |
-- +-------------------------+----+-------------------------+

constant MCTRL_AHBS_INDEX           : integer :=  0;
constant AHBROM_AHBS_INDEX          : integer :=  1;
constant AHB2MIG_AHBS_PINDEX        : integer :=  4;
constant AHBREP_AHBS_INDEX          : integer :=  3;
constant L2_AHBS_INDEX              : integer :=  4;

constant APBCTRL0_AHBS_INDEX        : integer :=  6;
constant APBCTRL1_AHBS_INDEX        : integer :=  7;
constant DSU_AHBS_INDEX             : integer :=  9;
constant PCI_AHBS_INDEX             : integer := 10;

constant APBCTRL0_AHBS_ADDR        : integer :=  CFG_APBADDR;
constant APBCTRL1_AHBS_ADDR        : integer :=  CFG_APBADDR+1;

constant APB0_PMASK : integer := 16#ffc#;
constant APB1_PMASK : integer := 16#ffc#;

-- APB0  memory map (offsets from base address 0x80000000):
-- +-------------------+----+----------------+
-- | Offset   | ID | Description             |
-- +-------------------+----+----------------+
-- | 0x00000  |  0 | GRETH                   |
-- | 0x01000  |  1 | APBUART0                |
-- | 0x02000  |  2 | IRQ(A)MP                |
-- | 0x03000  |  3 | GPTIMER                 |      
-- | 0x04000  |  4 | Xilinx MIG DDR3         |
-- | 0x05000  |  5 | GRCAN 0                 |
-- | 0x06000  |  6 | GRCAN 1                 |
-- | 0x07000  |  7 | PCI                     |
-- | 0x08000  |  8 | GPIO0                   |
-- | 0x09000  |  9 | GRPWM   (To be added)   |
-- |          |    |                         |
-- | 0x0b000  | 11 | I2CS0                   |
-- | 0x0c000  | 12 | SPI0                    |
-- | 0x0e000  | 14 | RGMII                   |
-- | 0x0f000  |    |                         |
-- | 0xfff00  | 15 | Configuration area      |
-- +-------------------+----+----------------+


constant MCTRL_PINDEX        : integer := 0;
constant APBUART0_PINDEX     : integer := 1;
constant IRQAMP_PINDEX       : integer := 2;
constant GPTIMER0_PINDEX     : integer := 3; 
constant AHB2MIG_PINDEX      : integer := 4; 
constant GRCAN0_PINDEX       : integer := 5; 
constant GRCAN1_PINDEX       : integer := 6; 
constant AHBUART_PINDEX      : integer := 7;
constant GRGPIO0_PINDEX      : integer := 8;
constant GRGPIO1_PINDEX      : integer := 9;
constant PCI_PINDEX          : integer := 10;
constant I2CSLV_PINDEX       : integer := 11;
constant PCI_DMA_PINDEX      : integer := 12;
constant PCI_ARB_PINDEX      : integer := 14;
constant AHBSTAT_PINDEX      : integer := 15;


constant MCTRL_PADDR        : integer := 16#000#;
constant APBUART0_PADDR     : integer := 16#010#;
constant IRQAMP_PADDR       : integer := 16#020#;
constant GPTIMER0_PADDR     : integer := 16#030#; 
constant AHB2MIG_PADDR      : integer := 16#040#; 
constant GRCAN0_PADDR       : integer := 16#050#; 
constant GRCAN1_PADDR       : integer := 16#060#; 
constant AHBUART_PADDR      : integer := 16#070#;
constant GRGPIO0_PADDR      : integer := 16#080#;
constant GRGPIO1_PADDR      : integer := 16#090#;
constant PCI_PADDR          : integer := 16#0a0#;
constant I2CSLV_PADDR       : integer := 16#0b0#;
constant PCI_DMA_PADDR      : integer := 16#0c0#;
constant SPI1_PADDR         : integer := 16#0d0#;
constant PCI_ARB_PADDR      : integer := 16#0e0#;
constant AHBSTAT_PADDR      : integer := 16#0f0#;

-- APB1 memory map (offsets from base address 0x80100000):
-- +----------+----+---------------------+
-- | Offset   | ID | Description         |
-- +----------+----+---------------------+
-- | 0x00000  |  0 | APBUART1            |
-- | 0x01000  |  1 | APBUART2            |
-- | 0x02000  |  2 | APBUART3            |
-- | 0x03000  |  3 | APBUART4            |
-- | 0x05000  |  4 | GRSPW0              |
-- | 0x06000  |  5 | GRSPW1              |
-- | 0x07000  |  6 | GRSPW2              |
-- | 0x08000  |  7 | GRSPW3              |
-- | 0x09000  |  8 | GRSPW4              |
-- | 0x0a000  |  9 | GRSPW5              |
-- | 0x0b000  | 10 | GR1553B             |
-- | 0x0c000  | 11 |
-- | 0x0d000  | 15 | Configuration area  |
-- +----------+----+---------------------+
--


constant APBUART1_PINDEX    : integer := 0;
constant APBUART2_PINDEX    : integer := 1;
constant APBUART3_PINDEX    : integer := 2;
constant APBUART4_PINDEX    : integer := 3; 
constant SPWIRE0_PINDEX     : integer := 4;
constant SPWIRE1_PINDEX     : integer := 5;
constant SPWIRE2_PINDEX     : integer := 6;
constant SPWIRE3_PINDEX     : integer := 7;
constant SPWIRE4_PINDEX     : integer := 8;
constant SPWIRE5_PINDEX     : integer := 9;
constant SPWIRE6_PINDEX     : integer := 10;
constant GR1553B_PINDEX     : integer := 11;
constant GRETH_PINDEX       : integer := 13;


constant APBUART1_PADDR     : integer := 0;
constant APBUART2_PADDR     : integer := 1;
constant APBUART3_PADDR     : integer := 2; 
constant APBUART4_PADDR     : integer := 3; 
constant SPWIRE0_PADDR      : integer := 16#040#;
constant SPWIRE1_PADDR      : integer := 16#050#;
constant SPWIRE2_PADDR      : integer := 16#060#;
constant SPWIRE3_PADDR      : integer := 16#070#;
constant SPWIRE4_PADDR      : integer := 9;
constant SPWIRE5_PADDR      : integer := 10;
constant GR1553B_PADDR      : integer := 16#0b0#;
constant GRETH_PADDR        : integer := 16#100#;


-- Interrupts (offsets from base address 0x80100000):
-- +-----+-------------------------+
-- |  ID | Description             |
-- +-----+-------------------------+
-- |  0  | GRETH                   |
-- |  1  | APBUART0                |
-- |  2  | APBUART1,2,3,4          |
-- |  3  | AHBSTAT                 |
-- |  4  | GRCAN0                  |
-- |  5  | GRCAN1                  |
-- |  6  | GRSPWIRE0,2,4           |
-- |  7  | GRSPWIRE1,3,5           |
-- |  8  | GPTIMER                 |
-- |  9  | -                       |
-- | 10  | I2CSLV                  |
-- | 11  | GR1553B                 |
-- | 12  | PCI                     |
-- | 13  | GRETH                   |
-- | 14  | -                       |
-- | 15  | -   (non-maskable)      |
-- +-------------------------------+

-- interrupts

constant GRETH_PIRQ        : integer :=  0;
constant APBUART0_PIRQ     : integer :=  1;
constant APBUART1_4_PIRQ   : integer :=  2;
constant AHBSTAT_PIRQ      : integer :=  3;
constant GRCAN0_PIRQ       : integer :=  4; 
constant GRCAN1_PIRQ       : integer :=  5;
constant SPWIRE0_PIRQ      : integer :=  6;
-- other SPWIRE PIRQ assigned as table above during instantiation
constant GPTIMER0_PIRQ     : integer :=  8;
constant I2CSLV_PIRQ       : integer := 10;
constant GR1553B_PIRQ      : integer := 11;
constant PCI_PIRQ          : integer := 12;



begin

----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------

  vcc <= '1';
  gnd <= '0';

  
    clk_pad : clkpad
      generic map (
	tech => padtech)
      port map (
	clk,
	lclk);

    cgi.pllctrl <= "00";
  cgi.pllrst <= rstraw;
    
  clk_nomig_0 : if (CFG_MIG_7SERIES = 0) generate
    clkgen0 : clkgen              -- clock generator
      generic map (
	clktech,
	CFG_CLKMUL*4,
	CFG_CLKDIV*4,
	0,
	0,
	0,
	CFG_PCIDLL,
	CFG_PCISYSCLK,
	BOARD_FREQ)
      port map (
	lclk,
	gnd,
	clkml,
	open,
	open,
	open,
        open,
	cgi,
	cgo);

    clkm <= clkml;
  end generate;

  clk_mig_0 : if (CFG_MIG_7SERIES = 1) generate
    clkgen_mig : clkgen              -- clock generator
      generic map (
	clktech,
	CFG_CLKMUL*4,
	CFG_CLKDIV,
	0,
	0,
	0,
	CFG_PCIDLL,
	CFG_PCISYSCLK,
	BOARD_FREQ)
      port map (
	lclk,
	gnd,
	lclk1,
	open,
	open,
	open,
        open,
	cgi,
	cgo);    
  end generate;

  pciclk <= pci_lclk;
	    
  clkgen1 : clkgen  		-- Ethernet 1G PHY clock generator
    generic map (
      CFG_FABTECH,
      20,
      8,
      0,
      0,
      0,
      0,
      0,
      BOARD_FREQ,
      0)
    port map (
      lclk,
      gnd,
      egtx_clk,
      open,
      open,
      open,
      open,
      cgi2,
      cgo2);
    
  cgi2.pllctrl <= "00"; cgi2.pllrst <= rstraw; --cgi2.pllref <= egtx_clk_fb;
  egtx_clk_pad : outpad generic map (tech => padtech)
    port map (eth_gtxclk, egtx_clk);
     
  clk_pad_ds : clkpad generic map (tech => padtech)
    port map (m1553clk, gr1553_clk);


  pci_clk_pad : clkpad generic map (tech => padtech, level => pci33) 
    port map (pci_clk, pci_lclk);
  
     
  spwclk_pad : clkpad generic map (tech => padtech)
    port map (spwclk, lspwclk);

  reset_pad : inpad generic map (tech => padtech)
    port map (resetn, rst);

  --rst_1 <= not rst;
  
  rst0 : rstgen         -- reset generator
    generic map (
      acthigh => 0,
      syncin  => 1)
    port map (
      rst,
      clkm,
      lock,
      rstn,
      rstraw);
    
  lock <= calib_done when CFG_MIG_7SERIES = 1 else cgo.clklock;

    rst1 : rstgen         -- reset generator
      generic map (
	acthigh => 0)
      port map (
	rst,
	clkm,
	'1',
	migrstn,
	open);

----------------------------------------------------------------------
---  AHB CONTROLLER --------------------------------------------------
----------------------------------------------------------------------

  ahbctrl0 : ahbctrl       -- AHB arbiter/multiplexer
    generic map (
      defmast => CFG_DEFMST,
      split   => CFG_SPLIT,
      rrobin  => CFG_RROBIN,
      ioaddr  => CFG_AHBIO,
      fpnpen  => CFG_FPNPEN,
      nahbm   => maxahbm,
      nahbs   => maxahbs,
      devid   => XILINX_KC705)
    port map (
      rstn,
      clkm,
      ahbmi,
      ahbmo,
      ahbsi,
      ahbso);

----------------------------------------------------------------------
---  LEON processor, DSU and performance counters --------------------
----------------------------------------------------------------------

  leon : leon_dsu_stat_base
    generic map (
      leon => CFG_LEON,
      ncpu => CFG_NCPU,
      fabtech => fabtech,
      memtech => memtech,
      nwindows => CFG_NWIN,
      dsu => CFG_DSU,
      fpu => CFG_FPU,
      v8 => CFG_V8,
      cp => 0,
      mac => CFG_MAC,
      pclow => pclow,
      notag => 0,
      nwp => CFG_NWP,
      icen => CFG_ICEN,
      irepl => CFG_IREPL,
      isets => CFG_ISETS,
      ilinesize => CFG_ILINE,
      isetsize => CFG_ISETSZ,
      isetlock => CFG_ILOCK,
      dcen => CFG_DCEN,
      drepl => CFG_DREPL,
      dsets => CFG_DSETS,
      dlinesize => CFG_DLINE,
      dsetsize => CFG_DSETSZ,
      dsetlock => CFG_DLOCK,
      dsnoop => CFG_DSNOOP,
      ilram => CFG_ILRAMEN,
      ilramsize => CFG_ILRAMSZ,
      ilramstart => CFG_ILRAMADDR,
      dlram => CFG_DLRAMEN,
      dlramsize => CFG_DLRAMSZ,
      dlramstart => CFG_DLRAMADDR,
      mmuen => CFG_MMUEN,
      itlbnum => CFG_ITLBNUM,
      dtlbnum => CFG_DTLBNUM,
      tlb_type => CFG_TLB_TYPE,
      tlb_rep => CFG_TLB_REP,
      lddel => CFG_LDDEL,
      disas => disas,
      tbuf => CFG_ITBSZ,
      pwd => CFG_PWD,
      svt => CFG_SVT,
      rstaddr => CFG_RSTADDR,
      smp => CFG_NCPU-1,
      cached => CFG_DFIXED,
      wbmask => CFG_BWMASK,
      busw => CFG_CACHEBW,
      netlist => CFG_LEON_NETLIST,
      ft => CFG_LEONFT_EN,
      npasi => CFG_NP_ASI,
      pwrpsr => CFG_WRPSR,
      rex => CFG_REX,
      altwin => CFG_ALTWIN,
      mmupgsz => CFG_MMU_PAGE,
      grfpush => CFG_GRFPUSH,
      dsu_hindex => DSU_AHBS_INDEX,
      dsu_haddr => 16#900#,
      dsu_hmask => 16#F00#,
      atbsz => CFG_ATBSZ,
      stat => CFG_STAT_ENABLE,
      stat_pindex => 13,
      stat_paddr => 16#100#,
      stat_pmask => 16#ffc#,
      stat_ncnt => CFG_STAT_CNT,
      stat_nmax => CFG_STAT_NMAX)
    port map (
      rstn => rstn,
      ahbclk => clkm,
      cpuclk => clkm,
      hclken => vcc,
      leon_ahbmi => ahbmi,
      leon_ahbmo => ahbmo(CFG_NCPU-1 downto 0),
      leon_ahbsi => ahbsi,
      leon_ahbso => ahbso,
      irqi => irqi,
      irqo => irqo,
      stat_apbi => apb0i,
      stat_apbo => apb0o(13),
      stat_ahbsi => ahbsi,
      stati => perf,
      dsu_ahbsi => ahbsi,
      dsu_ahbso => ahbso(DSU_AHBS_INDEX),
      dsu_tahbmi => ahbmi,
      dsu_tahbsi => ahbsi,
      sysi => sysi,
      syso => syso);

  
-- pragma translate_off
  led1_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
    port map (led(1), syso.proc_error);
-- pragma translate_on

  sysi.dsu_enable <= '1';
  dsui_break_pad   : inpad  generic map (level => cmos, voltage => x25v, tech => padtech)
    port map (switch(5), sysi.dsu_break);
  --dsuact_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
  --  port map (led(0), ndsuact);
  ndsuact <= not syso.dsu_active;

  -----------------------------------------------------------------------------
  -- Debug UART
  -----------------------------------------------------------------------------
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map (
	hindex =>  AHBUART_AHBM_INDEX,
	pindex =>  AHBUART_PINDEX,
	paddr  =>  AHBUART_PADDR,
	pmask  =>  16#FF0#)
      port map (
	rstn,
	clkm,
	dui,
	duo,
	apb0i,
	apb0o(AHBUART_PINDEX),
	ahbmi,
	ahbmo(AHBUART_AHBM_INDEX));
    dui.extclk <= '0';
  end generate;

  nouah : if CFG_AHB_UART = 0 generate
     apb0o(AHBUART_PINDEX)   <= apb_none;
     duo.txd    <= '0';
     duo.rtsn   <= '0';
     dui.extclk <= '0';
  end generate;

  sw4_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v)
      port map (switch(3), '0', '1', dsu_sel);

  dsutx_int   <= duo.txd;
  dui.rxd     <= dsurx_int;
  u1i.rxd     <= dsurx_int;
  dsurtsn_int <= duo.rtsn;
  dui.ctsn    <= dsuctsn_int;
  u1i.ctsn    <= dsuctsn_int;

  dsurx_pad   : inpad  generic map (level => cmos, voltage => x25v, tech => padtech)
    port map (dsurx, dsurx_int);
  dsutx_pad   : outpad generic map (level => cmos, voltage => x25v, tech => padtech)
    port map (dsutx, dsutx_int);

  -----------------------------------------------------------------------------
  -- JTAG debug link
  -----------------------------------------------------------------------------
-- pragma translate_off
    tck <= jtag_tck;
    tms <= jtag_tms;
    tdi <= jtag_tdi;
    jtag_tdo <= tdo;
-- pragma translate_on

  ahbjtaggen0 :if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag
      generic map(
	tech => fabtech
-- pragma translate_off
    *0
-- pragma translate_on
	, hindex => JTAG_AHBM_INDEX)
      port map(
	rstn,
	clkm,
	tck,
	tms,
	tdi,
	tdo,
	ahbmi,
	ahbmo(JTAG_AHBM_INDEX),
        open,
	open,
	open,
	open,
	open,
	open,
	open,
	gnd);
    
  end generate;

----------------------------------------------------------------------
---  Memory controllers ----------------------------------------------
----------------------------------------------------------------------

  memi.writen <= '1'; memi.wrn <= "1111"; memi.bwidth <= "00";
  memi.brdyn <= '0'; memi.bexcn <= '1';

  mctrl_gen : if CFG_MCTRL_LEON2 /= 0 generate
    mctrl0 : mctrl
      generic map (
	hindex    => MCTRL_AHBS_INDEX,
	pindex    => MCTRL_PINDEX,
        paddr     => MCTRL_PADDR,
	srbanks   => 2,
	ram8      => CFG_MCTRL_RAM8BIT,
        ram16     => CFG_MCTRL_RAM16BIT,
	sden      => CFG_MCTRL_SDEN,
        invclk    => CFG_CLK_NOFB,
	sepbus    => CFG_MCTRL_SEPBUS,
        pageburst => CFG_MCTRL_PAGE,
	rammask   => (16#FFe#)*(1-CFG_MIG_7SERIES),
	rommask   => 16#FF0#,
	iomask    => 0)
      port map (
	rstn,
	clkm,
	memi,
	memo,
	ahbsi,
	ahbso(MCTRL_AHBS_INDEX),
	apb0i,
	apb0o(MCTRL_PINDEX),
	wpo,
	open);

    addr_pad : outpadv generic map (width => 25, tech => padtech, level => cmos, voltage => x33v)
     port map (a(24 downto 0), memo.address(24 downto 0));
    --roms_pad : outpad generic map (tech => padtech, level => cmos, voltage => x33v)
    -- port map (romsn, memo.romsn(0));
    tmp_csn <= "1111" & memo.romsn(0) & memo.ramsn(0);
    csn_pad : outpadv generic map (width => 6, tech => padtech, level => cmos, voltage => x33v)
     port map (csn, tmp_csn);
    oen_pad  : outpad generic map (tech => padtech, level => cmos, voltage => x33v)
     port map (oen, memo.oen);
    --adv_pad  : outpad generic map (tech => padtech, level => cmos, voltage => x33v)
    -- port map (adv, '0');
    wri_pad  : outpad generic map (tech => padtech, level => cmos, voltage => x33v)
     port map (writen, memo.writen);
    data_pad : iopadvv generic map (tech => padtech, width => 8, level => cmos, voltage => x33v)
        port map (d(7 downto 0), memo.data(31 downto 24),
     memo.vbdrive(31 downto 24), memi.data(31 downto 24));
  end generate;

----------------------------------------------------------------------
---  SPI Memory Controller--------------------------------------------
----------------------------------------------------------------------

  spimc: if CFG_SPIMCTRL = 1 generate
    spimctrl0 : spimctrl        -- SPI Memory Controller
      generic map (hindex => 8, hirq => 1, faddr => 16#C00#, fmask => 16#ff8#,
                   ioaddr => 16#002#, iomask => 16#fff#,
                   spliten => CFG_SPLIT, oepol  => OEPOL,
                   sdcard => CFG_SPIMCTRL_SDCARD,
                   readcmd => CFG_SPIMCTRL_READCMD,
                   dummybyte => CFG_SPIMCTRL_DUMMYBYTE,
                   dualoutput => CFG_SPIMCTRL_DUALOUTPUT,
                   scaler => CFG_SPIMCTRL_SCALER,
                   altscaler => CFG_SPIMCTRL_ASCALER,
                   pwrupcnt => CFG_SPIMCTRL_PWRUPCNT)
      port map (rstn, clkm, ahbsi, ahbso(8), spmi, spmo);   


    miso_pad : inpad generic map (tech => padtech)
      port map (m0_d(1), spmi.miso);
    mosi_pad : outpad generic map (tech => padtech)
      port map (m0_d(0), spmo.mosi);
    slvsel0_pad : odpad generic map (tech => padtech)
      port map (m0_slvsel(0), spmo.csn);  
    sck_pad : outpad generic map (tech => padtech)
      port map (m0_sck, spmo.sck);
    
    spimctrl1 : spimctrl        -- SPI Memory Controller
      generic map (hindex => 9, hirq => 1, faddr => 16#D00#, fmask => 16#ff8#,
                   ioaddr => 16#004#, iomask => 16#fff#,
                   spliten => CFG_SPLIT, oepol  => OEPOL,
                   sdcard => CFG_SPIMCTRL_SDCARD,
                   readcmd => CFG_SPIMCTRL_READCMD,
                   dummybyte => CFG_SPIMCTRL_DUMMYBYTE,
                   dualoutput => CFG_SPIMCTRL_DUALOUTPUT,
                   scaler => CFG_SPIMCTRL_SCALER,
                   altscaler => CFG_SPIMCTRL_ASCALER,
                   pwrupcnt => CFG_SPIMCTRL_PWRUPCNT)
      port map (rstn, clkm, ahbsi, ahbso(9), spmi1, spmo1);   


    miso_pad1 : inpad generic map (tech => padtech)
      port map (m1_d(1), spmi1.miso);
    mosi_pad1 : outpad generic map (tech => padtech)
      port map (m1_d(0), spmo1.mosi);
    slvsel0_pad1 : odpad generic map (tech => padtech)
      port map (m1_slvsel(0), spmo1.csn);  
    sck_pad1 : outpad generic map (tech => padtech)
      port map (m1_sck, spmo1.sck);
    
  end generate;

----------------------------------------------------------------------
---  QSPI Memory Controller--------------------------------------------
----------------------------------------------------------------------
  qspimc: if CFG_SPIMCTRL = 1 generate
    spimctrl0 : spimctrl        -- SPI Memory Controller
      generic map (hindex => 10, hirq => 1, faddr => 16#E00#, fmask => 16#ff8#,
                   ioaddr => 16#006#, iomask => 16#fff#,
                   spliten => CFG_SPLIT, oepol  => OEPOL,
                   sdcard => CFG_SPIMCTRL_SDCARD,
                   readcmd => CFG_SPIMCTRL_READCMD,
                   dummybyte => CFG_SPIMCTRL_DUMMYBYTE,
                   dualoutput => CFG_SPIMCTRL_DUALOUTPUT,
                   scaler => CFG_SPIMCTRL_SCALER,
                   altscaler => CFG_SPIMCTRL_ASCALER,
                   pwrupcnt => CFG_SPIMCTRL_PWRUPCNT)
      port map (rstn, clkm, ahbsi, ahbso(10), qspmi, qspmo);   


    miso_pad : inpad generic map (tech => padtech)
      port map (spi_d(1), qspmi.miso);
    mosi_pad : outpad generic map (tech => padtech)
      port map (spi_d(0), qspmo.mosi);
    slvsel0_pad : odpad generic map (tech => padtech)
      port map (spi_cs, qspmo.csn);  
    -- To output SPI clock use Xilinx STARTUPE2 primitive
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
      USRCCLKO  => qspmo.sck,  
      USRCCLKTS => '0',       
      USRDONEO  => '1',       
      USRDONETS => '1'        
    );    
    
  end generate;

----------------------------------------------------------------------
---  Memory controllers ----------------------------------------------
----------------------------------------------------------------------

  nomctrl : if CFG_MCTRL_LEON2 = 0 and CFG_SPIMCTRL = 0 generate
    --roms_pad : outpad generic map (tech => padtech, level => cmos, voltage => x25v)
    -- port map (romsn, vcc); --ahbso(0) <= ahbso_none;
  end generate;

  --mctrl_error_gen : if CFG_MCTRL_LEON2 /= 0 and CFG_SPIMCTRL = 1 generate
  --   x : process
  --   begin
  --     assert false
  --     report  "Xilins KC705 Ref design do not support Quad SPI Flash Memory and Linear BPI flash memory at the same time"
  --     severity failure;
  --     wait;
  --   end process;
  --end generate;

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
      l2c0 : l2c
	generic map (
	  hslvidx   => L2_AHBS_INDEX,
	  hmstidx   => 0,
	  cen       => CFG_L2_PEN,
	  haddr     => 16#300#,
	  hmask     => 16#f00#,
	  ioaddr    => 16#FF0#, 
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
        port map(
	  rst    => rstn,
	  clk    => clkm,
	  ahbsi  => ahbsi,
	  ahbso  => ahbso(L2_AHBS_INDEX),
          ahbmi  => mem_ahbmi,
	  ahbmo  => mem_ahbmo(0),
	  ahbsov => mem_ahbso,
          sto    => l2c_stato);

      memahb0 : ahbctrl                -- AHB arbiter/multiplexer
        generic map (
	  defmast => CFG_DEFMST,
	  split   => CFG_SPLIT, 
          rrobin  => CFG_RROBIN,
	  ioaddr  => 16#FFE#,
          ioen    => 1,
	  nahbm   => 1,
	  nahbs   => 1)
        port map (
	  rstn,
	  clkm,
	  mem_ahbmi,
	  mem_ahbmo,
	  mem_ahbsi,
	  mem_ahbso);

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
    ahbso(L2_AHBS_INDEX) <= mig_ahbso;
    mig_ahbsi <= ahbsi;
    perf <= l3stat_in_none;
  end generate;
  
  ----------------------------------------------------------------------
  ---  DDR3 memory controller ------------------------------------------
  ----------------------------------------------------------------------
  mig_gen : if (CFG_MIG_7SERIES = 1) generate
    gen_mig : if (USE_MIG_INTERFACE_MODEL /= true) generate


      ahb2mig_7series_cpci_xc7k_1: ahb2mig_7series_cpci_xc7k
	generic map (
	  hindex		  => AHB2MIG_AHBS_PINDEX,
	  haddr			  => 16#400#,
          hmask                   => 16#C00#,
	  pindex                  => AHB2MIG_PINDEX,
	  paddr			  => AHB2MIG_PADDR,
	  pmask                   => APB0_PMASK,
          maxwriteburst           => 8,
          maxreadburst            => 8,
	  SIM_BYPASS_INIT_CAL	  => SIM_BYPASS_INIT_CAL,
	  SIMULATION		  => SIMULATION,
	  USE_MIG_INTERFACE_MODEL => USE_MIG_INTERFACE_MODEL)
	port map (
	  ddr3_dq	  => ddr3_dq,
	  ddr3_dqs_p	  => ddr3_dqs_p,
	  ddr3_dqs_n	  => ddr3_dqs_n,
	  ddr3_addr	  => ddr3_addr,
	  ddr3_ba	  => ddr3_ba,
	  ddr3_ras_n	  => ddr3_ras_n,
	  ddr3_cas_n	  => ddr3_cas_n,
	  ddr3_we_n	  => ddr3_we_n,
	  ddr3_reset_n	  => ddr3_reset_n,
	  ddr3_ck_p	  => ddr3_ck_p,
	  ddr3_ck_n	  => ddr3_ck_n,
	  ddr3_cke	  => ddr3_cke,
	  ddr3_dm	  => ddr3_dm,
	  ddr3_odt	  => ddr3_odt,
	  ddr3_cs_n       => ddr3_cs_n,
          ahbsi           => mig_ahbsi,
          ahbso           => mig_ahbso,
          apbi            => apb0i,
          apbo            => apb0o(4),
	  calib_done	  => calib_done,
          rst_n_syn       => migrstn,
          rst_n_async     => rstraw,
	  clk_amba	  => clkm,
	  sys_clk_i	  => lclk1,
          clk_ref_i       => clkref,
	  ui_clk	  => clkm,
	  ui_clk_sync_rst => open);
      
      clkgenmigref0 : clkgen
        generic map (clktech, 16, 8, 0,CFG_CLK_NOFB, 0, 0, 0, 100000)
        port map (clkm, clkm, clkref, open, open, open, open, cgi, cgo_mig, open, open, open);
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
          fname    => "ram.srec")
        port map(
          rst     => rstn,
          clk     => clkm,
          ahbsi   => mig_ahbsi,
          ahbso   => mig_ahbso);
  
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
    --ahbram0 : ahbram 
    --  generic map (hindex => 4*(1-CFG_L2_EN), haddr => 16#400#, tech => CFG_MEMTECH, kbytes => 128)
    --  port map ( rstn, clkm, mig_ahbsi, mig_ahbso);
    mig_ahbso <= ahbs_none;
   
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
-- pragma translate_off
  led2_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
     port map (led(2), calib_done);
  led3_pad : outpad generic map (tech => padtech, level => cmos, voltage => x15v)
     port map (led(3), lock);
-- pragma translate_on
-----------------------------------------------------------------------
---  PCI   ------------------------------------------------------------
-----------------------------------------------------------------------
  pci : if (CFG_GRPCI2_MASTER+CFG_GRPCI2_TARGET) /= 0 or CFG_PCI /= 0 generate

    grpci2x : if (CFG_GRPCI2_MASTER+CFG_GRPCI2_TARGET) /= 0 and (CFG_PCI+CFG_GRPCI2_DMA) = 0 generate
      pci0 : grpci2 
        generic map (
          memtech         => memtech,
          oepol           => OEPOL,
          hmindex         => PCI_AHBM_INDEX,
          hdmindex        => PCI_DMA_AHBM_INDEX,
          hsindex         => PCI_AHBS_INDEX, 
          haddr           => 16#C00#,
          hmask           => 16#E00#,
          ioaddr          => 16#000#,
          pindex          => PCI_PINDEX,
          paddr           => PCI_PADDR,
          irq             => PCI_PIRQ,
          irqmode         => 0,
          master          => CFG_GRPCI2_MASTER,
          target          => CFG_GRPCI2_TARGET,
          dma             => CFG_GRPCI2_DMA,
          tracebuffer     => CFG_GRPCI2_TRACE,
          vendorid        => CFG_GRPCI2_VID,
          deviceid        => CFG_GRPCI2_DID,
          classcode       => CFG_GRPCI2_CLASS,
          revisionid      => CFG_GRPCI2_RID,
          cap_pointer     => CFG_GRPCI2_CAP,
          ext_cap_pointer => CFG_GRPCI2_NCAP,
          iobase          => CFG_AHBIO,
          extcfg          => CFG_GRPCI2_EXTCFG,
          bar0            => CFG_GRPCI2_BAR0,
          bar1            => CFG_GRPCI2_BAR1,
          bar2            => CFG_GRPCI2_BAR2,
          bar3            => CFG_GRPCI2_BAR3,
          bar4            => CFG_GRPCI2_BAR4,
          bar5            => CFG_GRPCI2_BAR5,
          fifo_depth      => CFG_GRPCI2_FDEPTH,
          fifo_count      => CFG_GRPCI2_FCOUNT,
          conv_endian     => CFG_GRPCI2_ENDIAN,
          deviceirq       => CFG_GRPCI2_DEVINT,
          deviceirqmask   => CFG_GRPCI2_DEVINTMSK,
          hostirq         => CFG_GRPCI2_HOSTINT,
          hostirqmask     => CFG_GRPCI2_HOSTINTMSK,
          nsync           => 2,
          hostrst         => 1,
	  multifunc       => 0,  	--1
          bypass          => CFG_GRPCI2_BYPASS,
          debug           => 0,
          tbapben         => 0,
          tbpindex        => 5,
          tbpaddr         => 16#400#,
          tbpmask         => 16#C00#
          )
        port map (
          rstn,
	  clkm,
	  pciclk,
	  pci_dirq,
	  pcii,
	  pcio,
	  apb0i,
	  apb0o(PCI_PINDEX),
	  ahbsi,
	  ahbso(PCI_AHBS_INDEX),
	  ahbmi,
          ahbmo(PCI_AHBM_INDEX),
	  ahbmi, 
          open,
	  open,
	  open,
	  open,
	  open);

    end generate;

    grpci2xd : if (CFG_GRPCI2_MASTER+CFG_GRPCI2_TARGET) /= 0 and CFG_PCI = 0 and
                   CFG_GRPCI2_DMA /= 0 generate
      
      pci0 : grpci2 
        generic map (
          memtech         => memtech,
          oepol           => OEPOL,
          hmindex         => PCI_AHBM_INDEX,
          hdmindex        => PCI_DMA_AHBM_INDEX,
          hsindex         => PCI_AHBS_INDEX, 
          haddr           => 16#C00#,
          hmask           => 16#E00#,
          ioaddr          => 16#000#,
          pindex          => PCI_PINDEX,
          paddr           => PCI_PADDR,
          irq             => PCI_PIRQ,
          irqmode         => 0,
          master          => CFG_GRPCI2_MASTER,
          target          => CFG_GRPCI2_TARGET,
          dma             => CFG_GRPCI2_DMA,
          tracebuffer     => CFG_GRPCI2_TRACE,
          vendorid        => CFG_GRPCI2_VID,
          deviceid        => CFG_GRPCI2_DID,
          classcode       => CFG_GRPCI2_CLASS,
          revisionid      => CFG_GRPCI2_RID,
          cap_pointer     => CFG_GRPCI2_CAP,
          ext_cap_pointer => CFG_GRPCI2_NCAP,
          iobase          => CFG_AHBIO,
          extcfg          => CFG_GRPCI2_EXTCFG,
          bar0            => CFG_GRPCI2_BAR0,
          bar1            => CFG_GRPCI2_BAR1,
          bar2            => CFG_GRPCI2_BAR2,
          bar3            => CFG_GRPCI2_BAR3,
          bar4            => CFG_GRPCI2_BAR4,
          bar5            => CFG_GRPCI2_BAR5,
          fifo_depth      => CFG_GRPCI2_FDEPTH,
          fifo_count      => CFG_GRPCI2_FCOUNT,
          conv_endian     => CFG_GRPCI2_ENDIAN,
          deviceirq       => CFG_GRPCI2_DEVINT,
          deviceirqmask   => CFG_GRPCI2_DEVINTMSK,
          hostirq         => CFG_GRPCI2_HOSTINT,
          hostirqmask     => CFG_GRPCI2_HOSTINTMSK,
          nsync           => 2,
          hostrst         => 1,
          bypass          => CFG_GRPCI2_BYPASS,
          debug           => 0,
          tbapben         => 0,
          tbpindex        => 5,
          tbpaddr         => 16#400#,
          tbpmask         => 16#C00#
          )
        port map (
          rstn,
	  clkm,
	  pciclk,
	  pci_dirq,
	  pcii, pcio,
	  apb0i,
	  apb0o(PCI_PINDEX),
	  ahbsi,
	  ahbso(PCI_AHBS_INDEX),
	  ahbmi,
          ahbmo(PCI_AHBM_INDEX),
	  ahbmi, 
          ahbmo(PCI_DMA_AHBM_INDEX),
          open,
	  open,
	  open,
	  open);

    end generate;

    grpci1x : if (CFG_GRPCI2_MASTER+CFG_GRPCI2_TARGET) = 0 and CFG_PCI /= 0 generate

      pci_gr0 : if CFG_PCI = 1 generate   -- simple target-only
	pci0 : pci_target
	  generic map (
	    hindex    => PCI_AHBM_INDEX,
	    device_id => CFG_PCIDID,
	    vendor_id => CFG_PCIVID)
	  port map (
	    rstn,
	    clkm,
	    pciclk,
	    pcii,
	    pcio,
	    ahbmi,
	    ahbmo(PCI_AHBM_INDEX));
    end generate;

    pci_mtf0 : if CFG_PCI = 2 generate  -- master/target with fifo
      pci0 : pci_mtf
	generic map (
	  memtech   => memtech,
	  hmstndx   => PCI_AHBM_INDEX, 
          fifodepth => log2(CFG_PCIDEPTH),
	  device_id => CFG_PCIDID,
	  vendor_id => CFG_PCIVID,
          hslvndx   => PCI_AHBS_INDEX,
	  pindex    => PCI_PINDEX,
	  paddr     => PCI_PADDR,
	  haddr     => 16#E00#,
          ioaddr    => 16#400#,
	  nsync     => 2,
	  hostrst   => 1)
	port map (
	  rstn,
	  clkm,
	  pciclk,
	  pcii,
	  pcio,
	  apb0i,
	  apb0o(PCI_PINDEX),
	  ahbmi,
	  ahbmo(PCI_AHBM_INDEX),
	  ahbsi,
	  ahbso(PCI_AHBS_INDEX));
      
    end generate;
 
    pci_mtf1 : if CFG_PCI = 3 generate  -- master/target with fifo and DMA
      dma : pcidma
	generic map (
	  memtech => memtech,
	  dmstndx => PCI_DMA_AHBM_INDEX, 
          dapbndx => 5,
	  dapbaddr => 5,
	  blength => blength,
	  mstndx => PCI_AHBM_INDEX,
          fifodepth => log2(fifodepth),
	  device_id => CFG_PCIDID,
	  vendor_id => CFG_PCIVID,
          slvndx => 4,
	  apbndx => 4,
	  apbaddr => 4,
	  haddr => 16#E00#,
	  ioaddr => 16#800#, 
          nsync => 2,
	  hostrst => 1)
	port map (
	  rstn,
	  clkm,
	  pciclk,
	  pcii,
	  pcio,
	  apb0o(PCI_DMA_PINDEX),
	  ahbmo(PCI_DMA_AHBM_INDEX), 
          apb0i,
	  apb0o(PCI_PINDEX),
	  ahbmi,
	  ahbmo(PCI_AHBM_INDEX),
	  ahbsi,
	  ahbso(PCI_AHBS_INDEX));
    end generate;
    end generate;

    pci_trc0 : if CFG_PCITBUFEN /= 0 generate   -- PCI trace buffer
      pt0 : pcitrace generic map (depth => (6 + log2(CFG_PCITBUF/256)), 
        memtech => memtech, pindex  => 13, paddr => 16#100#, pmask => 16#f00#)
        port map ( rstn, clkm, pciclk, pcii, apb0i, apb0o(13));
    end generate;


    

    pcia0 : if CFG_PCI_ARB = 1 generate -- PCI arbiter
      pciarb0 : pciarb
	generic map (
	  pindex => PCI_ARB_PINDEX,
	  paddr  => PCI_ARB_PADDR, 
          apb_en => CFG_PCI_ARBAPB)
	port map (
	  clk     => pciclk,
	  rst_n   => pcii.rst,
          req_n   => pci_arb_req_n,
	  frame_n => pcii.frame,
          gnt_n   => pci_arb_gnt_n,
	  pclk    => clkm, 
          prst_n  => rstn,
	  apbi    => apb0i,
	  apbo    => apb0o(PCI_ARB_PINDEX)
       );

      pgnt_pad : outpadv
	generic map (
	  tech => padtech,
	  width => 4) 
        port map (
	  pci_arb_gnt,
	  pci_arb_gnt_n);
      
      preq_pad : inpadv
	generic map (
	  tech => padtech,
	  width => 4) 
        port map (
	  pci_arb_req,
	  pci_arb_req_n);
    end generate;
    
    pcipads0 : pcipads
      generic map (
	padtech => padtech,
	host => 1,
	oepol => OEPOL,
        noreset => 0,
	drivereset => 0,
	no66 => 1,
	singleint => 1)   -- PCI pads
      port map (
	pci_rst,
	pci_gnt,
	pci_idsel,
	pci_lock,
	pci_ad,
	pci_cbe,
        pci_frame,
	pci_irdy,
	pci_trdy,
	pci_devsel,
	pci_stop,
	pci_perr,
        pci_par,
	pci_req,
	pci_serr,
	pci_host,
	pci_66,
	pcii,
	pcio,
	pci_int);


   --ad_pci_int : iodpad
   -- generic map (
   --	tech => padtech,
   --	level => pci33,
      --	voltage => x33v,
      --	oepol => OEPOL)
      --port map (
      --	pci_int,
      --	pcio.inten,
      --	pcii.int(0));
    

    
  end generate;

 
-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

    eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC
      e0 : grethm
	generic map(
	  hindex => GRETH_AHBM_INDEX,
          pindex => GRETH_PINDEX,
  	  paddr  => GRETH_PADDR,
	  pirq   => GRETH_PIRQ,
	  memtech => memtech,
          mdcscaler => CPU_FREQ/1000,
	  rmii => 0,
	  enable_mdio => 1,
	  fifosize => CFG_ETH_FIFO,
          nsync => 1,
	  edcl => CFG_DSU_ETH,
	  edclbufsz => CFG_ETH_BUF,
	  phyrstadr => 1, 
          macaddrh => CFG_ETH_ENM,
	  macaddrl => CFG_ETH_ENL,
	  enable_mdint => 1,
	  oepol => OEPOL ,
          ipaddrh => CFG_ETH_IPM,
 	  ipaddrl => CFG_ETH_IPL,
          giga => CFG_GRETH1G,
	  ramdebug => 0,
	  gmiimode => 0)
	port map(
	  rst   => rstn,
	  clk   => clkm,
	  ahbmi => ahbmi,
	  ahbmo => ahbmo(GRETH_AHBM_INDEX),
	  apbi  => apb1i,
	  apbo  => apb1o(GRETH_PINDEX),
	  ethi  => ethi,
	  etho  => etho);


      
      emdc_pad : outpad generic map (tech => padtech) 
        port map (eth_mdc, etho.mdc);
      emdio_pad : iopad generic map (tech => padtech, oepol => OEPOL) 
        port map (eth_mdio, etho.mdio_o, etho.mdio_oe, ethi.mdio_i);
      emdint_pad : inpad generic map (tech => padtech) 
        port map (eth_mdint, ethi.mdint);
      
      erxc_pad : clkpad generic map (tech => padtech, arch => 2) 
        port map (eth_rxclk, ethi.rx_clk);

      erxd_pad : inpadv generic map (tech => padtech, width => 8) 
        port map (eth_rxd, ethi.rxd(7 downto 0));
      erxdv_pad : inpad generic map (tech => padtech) 
        port map (eth_rxdv, ethi.rx_dv);
      erxer_pad : inpad generic map (tech => padtech) 
        port map (eth_rxer, ethi.rx_er);
      
      etxc_pad : clkpad generic map (tech => padtech, arch => 2) 
        port map (eth_txclk, ethi.tx_clk);

      etxd_pad : outpadv generic map (tech => padtech, width => 8) 
        port map (eth_txd, etho.txd(7 downto 0));
      etxen_pad : outpad generic map (tech => padtech) 
        port map ( eth_txen, etho.tx_en);
      etxer_pad : outpad generic map (tech => padtech) 
        port map (eth_txer, etho.tx_er);

      erxco_pad : inpad generic map (tech => padtech) 
        port map (eth_col, ethi.rx_col);
      erxcr_pad : inpad generic map (tech => padtech) 
        port map (eth_crs, ethi.rx_crs);

      --erst_pad : outpad generic map (tech => padtech) 
      --  port map (phy_reset, rstn);

      ethi.gtx_clk <= egtx_clk;

    end generate;

    noeth0 : if CFG_GRETH = 0 generate
      -- TODO:
    end generate;




------------------------------------------------------------------------------
-- CAN CONTROLLERS
------------------------------------------------------------------------------
 grcangen : if CFG_GRCAN = 1 generate

    can0 : grcan
      generic map (
        hindex    => GRCAN0_AHBM_INDEX,
        pindex    => GRCAN0_PINDEX,
        paddr     => GRCAN0_PADDR,
        pmask     => 16#FFC#,
        pirq      => GRCAN0_PIRQ,
	singleirq => CFG_GRCANSINGLE)
      port map (
        rstn      => rstn,
        clk       => clkm,
        apbi      => apb0i,
        apbo      => apb0o(GRCAN0_PINDEX),
        ahbi      => ahbmi,
        ahbo      => ahbmo(GRCAN0_AHBM_INDEX),
        cani      => can0i,
        cano      => can0o);
    
    can1 : grcan
      generic map (
        hindex    => GRCAN1_AHBM_INDEX,
        pindex    => GRCAN1_PINDEX,
        paddr     => GRCAN1_PADDR,
        pmask     => 16#FFC#,
        pirq      => GRCAN1_PIRQ,
	singleirq => CFG_GRCANSINGLE)
      port map (
        rstn      => rstn,
        clk       => clkm,
        apbi      => apb0i,
        apbo      => apb0o(GRCAN1_PINDEX),
        ahbi      => ahbmi,
        ahbo      => ahbmo(GRCAN1_AHBM_INDEX),
        cani      => can1i,
        cano      => can1o);

 end generate;
  

   nogrcangen : if CFG_GRCAN = 0 generate
    apb0o(GRCAN0_PINDEX)       <= apb_none;
    apb0o(GRCAN1_PINDEX)       <= apb_none;
    can0o <= (tx => "11", en => "00");
    can1o <= (tx => "11", en => "00");
  end generate; 
   


  
  
----------------------------------------------------------------------
---  APB Bridge and various periherals -------------------------------
----------------------------------------------------------------------

  apb0 : apbctrl            -- AHB/APB bridge
    generic map (
      hindex  => APBCTRL0_AHBS_INDEX,
      haddr   => APBCTRL0_AHBS_ADDR,
      nslaves => 16,
      debug   => 2)
    port map (
      rstn,
      clkm,
      ahbsi,
      ahbso(APBCTRL0_AHBS_INDEX),
      apb0i,
      apb0o );

  apb1 : apbctrl            -- AHB/APB bridge
    generic map (
      hindex  => APBCTRL1_AHBS_INDEX,
      haddr   => APBCTRL1_AHBS_ADDR,
      nslaves => 16,
      debug   => 2)
    port map (
      rstn,
      clkm,
      ahbsi,
      ahbso(APBCTRL1_AHBS_INDEX),
      apb1i,
      apb1o );

  irqctrl : if CFG_IRQ3_ENABLE /= 0 generate
    irqctrl0 : irqmp         -- interrupt controller
      generic map (
	pindex => IRQAMP_PINDEX,
	paddr  => IRQAMP_PADDR,
	pmask  => 16#FF0#,
	ncpu   => CFG_NCPU)
      port map (
	rstn,
	clkm,
	apb0i,
	apb0o(IRQAMP_PINDEX),
	irqo,
	irqi);
  end generate;

  gpt : if CFG_GPT_ENABLE /= 0 generate
    timer0 : gptimer          -- timer unit
      generic map (
	pindex  => GPTIMER0_PINDEX,
	paddr   => GPTIMER0_PADDR,
	pirq    => GPTIMER0_PIRQ,
        pmask   => 16#FF0#,
	sepirq  => CFG_GPT_SEPIRQ,
	sbits   => CFG_GPT_SW,
	ntimers => CFG_GPT_NTIM,
        nbits   => CFG_GPT_TW,
	wdog    => CFG_GPT_WDOGEN*CFG_GPT_WDOG)
      port map (
	rstn,
	clkm,
	apb0i,
	apb0o(GPTIMER0_PINDEX),
	gpti,
	gpto);
	
    gpti <= gpti_dhalt_drive(syso.dsu_tstop);
  end generate;

  nogpt : if CFG_GPT_ENABLE = 0 generate apb0o(3) <= apb_none; end generate;

  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate     -- GPIO unit
    grgpio_switch: grgpio
      generic map(
	pindex => GRGPIO0_PINDEX,
	paddr  => GRGPIO0_PADDR,
	imask  => CFG_GRGPIO_IMASK,
	nbits  => 6)
      port map(
	rst   => rstn,
        clk   => clkm,
        apbi  => apb0i,
        apbo  => apb0o(GRGPIO0_PINDEX),
        gpioi => gpioi0,
        gpioo => gpioo0);
    
    pio_pads0 : for i in 0 to 2 generate
        pio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v)
	  port map (switch(i), gpioo0.dout(i), gpioo0.oen(i), gpioi0.din(i));
    end generate;

    pio_pads1 : for i in 4 to 4 generate
        pio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v)
	  port map (switch(i), gpioo0.dout(i), gpioo0.oen(i), gpioi0.din(i));
    end generate;


      grgpio_led: grgpio
      generic map(
	pindex => GRGPIO1_PINDEX,
	paddr  => GRGPIO1_PADDR,
	imask  => CFG_GRGPIO_IMASK,
	nbits  => 32)
      port map(
	rst   => rstn,
        clk   => clkm,
        apbi  => apb0i,
        apbo  => apb0o(GRGPIO1_PINDEX),
        gpioi => gpioi1,
        gpioo => gpioo1);
    
        pio_pads2 : for i in 0 to 31 generate
        pio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x25v)
	  port map (gpio(i), gpioo1.dout(i), gpioo1.oen(i), gpioi1.din(i));
    end generate;

  end generate;
  

   ua0 : if CFG_UART1_ENABLE /= 0 generate
    uart1 : apbuart                     -- UART 1
      generic map (
	pindex   => APBUART0_PINDEX,
	paddr    => APBUART0_PADDR,
	pirq     => APBUART0_PIRQ,
	console  => dbguart,
        fifosize => CFG_UART1_FIFO)
      port map (
        rst      => rstn,
        clk      => clkm,
        apbi     => apb0i,
        apbo     => apb0o(APBUART0_PINDEX),
        uarti    => uarti(0),
        uarto    => uarto(0));

    rx_pad   : inpad
	generic map (
	  level => cmos,
	  voltage => x25v,
	  tech => padtech)
	port map (
	  uart_rxd(0),
	  uarti(0).rxd);

    tx_pad   : outpad
	generic map (
	  level =>cmos,
	  voltage => x25v,
	  tech => padtech)
	port map (
	  uart_txd(0),
	  uarto(0).txd);

    ctsn_pad : inpad
	generic map (
	  level => cmos,
	  voltage => x25v,
	  tech => padtech)
	port map (
	  uart_ctsn(0),
	  uarti(0).ctsn);

    rtsn_pad : outpad
	generic map (
	  level => cmos,
	  voltage => x25v,
	  tech => padtech)
	port map (
	  uart_rtsn(0),
	  uarto(0).rtsn);
  end generate;

  noua0 : if CFG_UART1_ENABLE = 0 generate
    apb0o(APBUART0_PINDEX) <= apb_none;
  end generate;
  

  ua1_4 : if CFG_UART2_ENABLE /= 0 generate
   u : for i in 1 to 4 generate 
      uart : apbuart                     -- UART 0-4
        generic map (
          pindex   => APBUART1_PINDEX + (i-1),
          paddr    => APBUART1_PADDR + 16#010#*(i-1),
	  pmask    => 16#FF0#,
          console  => dbguart,
          pirq     => APBUART1_4_PIRQ,
          fifosize => CFG_UART2_FIFO)
        port map (
          rst      => rstn,
          clk      => clkm,
          apbi     => apb1i,
          apbo     => apb1o(APBUART1_PINDEX+i-1),
          uarti    => uarti(i),
          uarto    => uarto(i));
      
      rx_pad   : inpad
	generic map (
	  level => cmos,
	  voltage => x25v,
	  tech => padtech)
	port map (
	  uart_rxd(i),
	  uarti(i).rxd);

      tx_pad   : outpad
	generic map (
	  level =>cmos,
	  voltage => x25v,
	  tech => padtech)
	port map (
	  uart_txd(i),
	  uarto(i).txd);
      ctsn_rtsn: if i=1 generate
	ctsn_pad : inpad
	  generic map (
	    level => cmos,
	    voltage => x25v,
	    tech => padtech)
	  port map (
	    uart_ctsn(i),
	    uarti(i).ctsn);
      
        rtsn_pad : outpad
	  generic map (
	    level => cmos,
	    voltage => x25v,
	    tech => padtech)
	  port map (
	    uart_rtsn(i),
	    uarto(i).rtsn);
      end generate ctsn_rtsn;
   end generate;
  end generate;

  noua1_4 : if CFG_UART2_ENABLE = 0 generate
    apb1o(APBUART1_PINDEX) <= apb_none;
    apb1o(APBUART2_PINDEX) <= apb_none;
    apb1o(APBUART3_PINDEX) <= apb_none;
    apb1o(APBUART4_PINDEX) <= apb_none;	     
  end generate;



  i2cs: if CFG_I2C_ENABLE = 1 generate  -- I2C slave
    i2cs0 : i2cslv 
      generic map (
        pindex    => I2CSLV_PINDEX,
        paddr     => I2CSLV_PADDR,
        pmask     => 16#FF0#,
        pirq      => I2CSLV_PIRQ,
        filter    => 9)
      port map (
        rstn    => rstn,
        clk     => clkm,
        apbi    => apb0i,
        apbo    => apb0o(I2CSLV_PINDEX),
        i2ci    => i2csi,
        i2co    => i2cso);

    i2cs_scl_pad : iopad
      generic map (
	tech => padtech,
        level => cmos,
        voltage => x25v)
      port map (
	iic_scl,
        i2cso.scl,
        i2cso.scloen,
        i2csi.scl);

    i2cs_sda_pad : iopad
      generic map (
	tech => padtech,
	level => cmos,
        voltage => x25v)
      port map (
        iic_sda,
        i2cso.sda,
        i2cso.sdaoen,
        i2csi.sda);
    
  end generate;
  
  noi2cs: if CFG_I2C_ENABLE = 0 generate
    i2cso.scloen  <= '1'; i2cso.sdaoen  <= '1';
    i2cso.scl     <= '0'; i2cso.sda     <= '0';
    apb0o(I2CSLV_PINDEX)   <= apb_none;
  end generate;
  
  ahbs : if CFG_AHBSTAT = 1 generate   -- AHB status register
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat
      generic map (
	pindex => AHBSTAT_PINDEX,
	paddr  => AHBSTAT_PADDR,
	pirq   => AHBSTAT_PIRQ,
        nftslv => CFG_AHBSTATN)
      port map (
	rstn,
	clkm,
	ahbmi,
	ahbsi,
	stati,
	apb0i,
	apb0o(AHBSTAT_PINDEX));
  end generate;

-----------------------------------------------------------------------
---  AHB ROM ----------------------------------------------------------
-----------------------------------------------------------------------

  bpromgen : if CFG_AHBROMEN /= 0 generate
    brom : entity work.ahbrom
      generic map (hindex => AHBROM_AHBS_INDEX, haddr => 0, pipe => CFG_AHBROPIP)
      port map ( rstn, clkm, ahbsi, ahbso(AHBROM_AHBS_INDEX));
  end generate;

-----------------------------------------------------------------------
---  AHB RAM ----------------------------------------------------------
-----------------------------------------------------------------------

  ocram : if CFG_AHBRAMEN = 1 generate
    ahbram0 : ahbram generic map (hindex => 5, haddr => CFG_AHBRADDR,
   tech => CFG_MEMTECH, kbytes => CFG_AHBRSZ, pipe => CFG_AHBRPIPE)
    port map ( rstn, clkm, ahbsi, ahbso(5));
  end generate;

-----------------------------------------------------------------------
---  GR1553  ----------------------------------------------------------
-----------------------------------------------------------------------
  mil: if CFG_GR1553B_ENABLE /= 0 generate
    -- Reset generation for 1553 codec
    rgc: rstgen
      port map (rstn, gr1553_clk, '1', gr1553_codec_rst, open);

    gr1553b0 : gr1553b        -- Gaisler 1553 core
      generic map (
        hindex        => GR1553B_AHBM_INDEX,
        pindex        => GR1553B_PINDEX,
        paddr         => GR1553B_PADDR,
        pmask         => 16#FF0#,
        pirq          => GR1553B_PIRQ,
        bc_enable     => 1,
        rt_enable     => 1,
        bm_enable     => 1,
        bc_timer      => 1,
        bc_rtbusmask  => 1,
        extra_regkeys => 0,
        syncrst       => 2,
        ahbendian     => 0,
        bm_filters    => 1,
        codecfreq     => 24,
        codecver      => 0)
      port map (
        clk         => clkm,
        rst         => rstn,
        ahbmi       => ahbmi,
        ahbmo       => ahbmo(GR1553B_AHBM_INDEX),
        apbsi       => apb1i,
        apbso       => apb1o(GR1553B_PINDEX),
        auxin       => gr1553_auxin,
        auxout      => gr1553_auxout,
        codec_clk   => gr1553_clk,
        codec_rst   => gr1553_codec_rst,
        txout       => gr1553_txout,
        txout_fb    => gr1553_txout,
        rxin        => gr1553_rxin);
  end generate;

  nmil: if CFG_GR1553B_ENABLE = 0 generate
    gr1553_codec_rst <= '0';
    gr1553_txout <= (others => '0');
  end generate;
  
    busa_inen_pad : outpad generic map (tech => padtech) 
      port map (m1553rxena, gr1553_txout.busA_rxen);
    busa_inp_pad  : inpad generic map (tech => padtech) 
      port map (m1553rxa, gr1553_rxin.busA_rxP);
    busa_inn_pad  : inpad generic map (tech => padtech) 
      port map (m1553rxna, gr1553_rxin.busA_rxN);
    busa_outin_pad : outpad generic map (tech => padtech) 
      port map (m1553txinha, gr1553_txout.busA_txin);
    busa_outp_pad : outpad generic map (tech => padtech) 
      port map (m1553txa, gr1553_txout.busA_txP);
    busa_outn_pad : outpad generic map (tech => padtech) 
      port map (m1553txna, gr1553_txout.busA_txN);
    busb_inen_pad : outpad generic map (tech => padtech) 
      port map (m1553rxenb, gr1553_txout.busB_rxen);
    busb_inp_pad  : inpad generic map (tech => padtech) 
      port map (m1553rxb, gr1553_rxin.busB_rxP);
    busb_inn_pad  : inpad generic map (tech => padtech) 
      port map (m1553rxnb, gr1553_rxin.busB_rxN);
    busb_outin_pad : outpad generic map (tech => padtech) 
      port map (m1553txinhb, gr1553_txout.busB_txin);
    busb_outp_pad : outpad generic map (tech => padtech) 
      port map (m1553txb, gr1553_txout.busB_txP);
    busb_outn_pad : outpad generic map (tech => padtech) 
      port map (m1553txnb, gr1553_txout.busB_txN);

-----------------------------------------------------------------------
---  SPACEWIRE  -------------------------------------------------------
-----------------------------------------------------------------------
  spw : if CFG_SPW_EN > 0 generate
   spw_rxtxclk <= lspwclk;
   spw_rxclkn <= not spw_rxtxclk;
   
   swloop : for i in 0 to CFG_SPW_NUM-1 generate
     -- GRSPW2 PHY
     spw2_input : if CFG_SPW_GRSPW = 2 generate
       spw_phy0 : grspw2_phy
         generic map(
           scantest     => 0,
           tech         => fabtech,
           input_type   => CFG_SPW_INPUT,
           rxclkbuftype => 1)
         port map(
           rstn       => rstn,
           rxclki     => spw_rxtxclk,
           rxclkin    => spw_rxclkn,
           nrxclki    => spw_rxtxclk,
           di         => dtmp(i),
           si         => stmp(i),
           do         => spwi(i).d(1 downto 0),
           dov        => spwi(i).dv(1 downto 0),
           dconnect   => spwi(i).dconnect(1 downto 0),
           dconnect2  => spwi(i).dconnect2(1 downto 0),
           dconnect3  => spwi(i).dconnect3(1 downto 0),
           rxclko     => spw_rxclk(i));
       spwi(i).nd <= (others => '0');  -- Only used in GRSPW
       spwi(i).dv(3 downto 2) <= "00";  -- For second port
     end generate spw2_input;
     
     -- GRSPW PHY
     spw1_input: if CFG_SPW_GRSPW = 1 generate
       spw_phy0 : grspw_phy
         generic map(
           tech         => fabtech,
           rxclkbuftype => 1,
           scantest     => 0)
         port map(
           rxrst      => spwo(i).rxrst,
           di         => dtmp(i),
           si         => stmp(i),
           rxclko     => spw_rxclk(i),
           do         => spwi(i).d(0),
           ndo        => spwi(i).nd(4 downto 0),
           dconnect   => spwi(i).dconnect(1 downto 0));
       spwi(i).d(1) <= '0';
       spwi(i).dv <= (others => '0');  -- Only used in GRSPW2
       spwi(i).dconnect2(1 downto 0) <= (others => '0');  -- Only used in GRSPW2
       spwi(i).dconnect3(1 downto 0) <= (others => '0');  -- Only used in GRSPW2
       spwi(i).nd(9 downto 5) <= "00000";  -- For second port
     end generate spw1_input;

     spwi(i).d(3 downto 2) <= "00";   -- For second port
     spwi(i).dconnect(3 downto 2)  <= "00";  -- For second port
     spwi(i).dconnect2(3 downto 2) <= "00";  -- For second port
     spwi(i).dconnect3(3 downto 2) <= "00";  -- For second port
     spwi(i).s(1 downto 0) <= "00";  -- Only used in PHY
     
     sw0 : grspwm
       generic map(
	 tech           => fabtech,
	 hindex         => SPWIRE_AHBM_INDEX+i,
	 pindex         => SPWIRE0_PINDEX+i,
	 paddr          => SPWIRE0_PADDR+ 16#010#*i,
	 pmask          => 16#FF0#,
	 pirq           => SPWIRE0_PIRQ + (i mod 2),
	 sysfreq        => BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV,
	 usegen         => 1,
	 nsync          => 1,
	 rmap           => CFG_SPW_RMAP,
	 rmapcrc        => CFG_SPW_RMAPCRC,
	 rmapbufs       => CFG_SPW_RMAPBUF,
	 ports          => 1,
	 dmachan        => CFG_SPW_DMACHAN,
	 memtech        => memtech,
	 fifosize1      => CFG_SPW_AHBFIFO,
	 fifosize2      => CFG_SPW_RXFIFO,
	 rxclkbuftype   => 1,
	 ft             => CFG_SPW_FT,
	 netlist        => CFG_SPW_NETLIST,
	 spwcore        => CFG_SPW_GRSPW,
	 input_type     => CFG_SPW_INPUT,
	 output_type    => CFG_SPW_OUTPUT,
	 rxtx_sameclk   => CFG_SPW_RTSAME,
         internalrstgen => 1)
       port map(
	 rstn,
	 clkm,
         gnd,
         gnd,
	 spw_rxclk(i),
         gnd,
	 spw_rxclk(i),
         gnd,
	 spw_rxtxclk,
	 spw_rxtxclk,
         ahbmi,
	 ahbmo(SPWIRE_AHBM_INDEX+i),
         apb1i,
	 apb1o(SPWIRE0_PINDEX+i),
	 spwi(i),
	 spwo(i));
     
    spwi(i).tickin <= '0'; spwi(i).clkdiv10 <= "00001001"; -- 9 for 100MHZ SDR TX clock
    spwi(i).rmapen <= '1';
   
    spw_rxd_pad : inpad  generic map (tech => padtech) port map (spw_rxd(i), dtmp(i));
    spw_rxs_pad : inpad  generic map (tech => padtech) port map (spw_rxs(i), stmp(i));
    spw_txd_pad : outpad generic map (tech => padtech) port map (spw_txd(i), spwo(i).d(0));
    spw_txs_pad : outpad generic map (tech => padtech) port map (spw_txs(i), spwo(i).s(0));
   end generate;
 end generate;

-----------------------------------------------------------------------
---  Test report module  ----------------------------------------------
-----------------------------------------------------------------------

  -- pragma translate_off
  test0 : ahbrep
    generic map (
      hindex => AHBREP_AHBS_INDEX,
      haddr => 16#200#)
    port map (
      rstn,
      clkm,
      ahbsi,
      ahbso(3));
  -- pragma translate_on
 -----------------------------------------------------------------------
 ---  Drive unused bus elements  ---------------------------------------
 -----------------------------------------------------------------------

--main bus
  nam : for i in (FIRST_DUMMY_AHBM_INDEX) to NAHBMST-1 generate
    ahbmo(i) <= ahbm_none;
  end generate;


 -----------------------------------------------------------------------
 ---  Boot message  ----------------------------------------------------
 -----------------------------------------------------------------------

 -- pragma translate_off
   x : report_design
   generic map (
    msg1 => "LEON/GRLIB GR-CPCI-XCK7 Demonstration design",
    fabtech => tech_table(fabtech), memtech => tech_table(memtech),
    mdel => 1
   );
 -- pragma translate_on
 end;

