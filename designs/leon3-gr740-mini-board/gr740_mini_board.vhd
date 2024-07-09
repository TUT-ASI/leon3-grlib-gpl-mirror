------------------------------------------------------------------------------
--  LEON3 Demonstration design
--  Copyright (C) 2022 Cobham Gaisler
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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

--library lifcl;
--use lifcl.all;
library gaisler;
use gaisler.memctrl.all;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.jtag.all;
use gaisler.spi.all;
use gaisler.subsys.all;
use gaisler.pci.all;
use gaisler.spacewire.all;
--use gaisler.ethernet_mac.all;
use gaisler.net.all;

use gaisler.hssl.all;

library esa;
--use esa.memoryctrl.all;
use esa.pcicomp.all;
--use work.config.all;

--pragma translate_off
use gaisler.sim.all;
library nexus_sim;
use nexus_sim.all;
--pragma translate_on
use work.config.all;

entity gr740_mini_board is
  generic (
    fabtech          : integer := CFG_FABTECH;
    memtech          : integer := CFG_MEMTECH;
    padtech          : integer := CFG_PADTECH;
    clktech          : integer := CFG_CLKTECH;
    ncpu             : integer := CFG_NCPU;
    disas            : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart          : integer := CFG_DUART;   -- Print UART on console
    pclow            : integer := CFG_PCLOW;
    simulation       : boolean := false;
    ramfile          : string  := "ram.srec"
    );
  port (
    -- Clock input used in this design, note that there are more clocks available, see schematics
    clk_in_33mhz     : in    std_ulogic;
    clk_in_125mhz    : in    std_ulogic;
    -- Enable-signals for SerDes reference clocks
    en_sdq0_refclk   : out   std_logic; -- Enables SDQ1 external oscillator. active high 3.3V
    en_sdq1_refclk   : out   std_logic; -- Enables SDQ0 external oscillator. active high 3.3V.
    -- Reset input
    gsrn             : in    std_ulogic;
    -- GPIO
    gpio             : inout std_logic_vector(4 downto 0);
    -- LEDs
    led              : out   std_logic_vector(3 downto 0);
    -- SPI memory
    spi_mclk         : out   std_logic;
    dq0_mosi         : inout std_logic;
    dq1_miso         : inout std_logic;
    csspin           : out   std_logic;
    dq2              : inout std_logic;
    dq3              : inout std_logic;
    -- UART
    rxduart          : in    std_logic;
    txduart          : out   std_logic;
    -- PCI
    pci_ad           : inout std_logic_vector(31 downto 0);
    pci_cbe          : inout std_logic_vector(3 downto 0);
    pci_par 	       : inout std_ulogic;
    pci_frame        : inout std_ulogic;
    pci_trdy 	       : inout std_ulogic;
    pci_irdy 	       : inout std_ulogic;
    pci_stop 	       : inout std_ulogic;
    pci_devsel       : inout std_ulogic;
    pci_perr 	       : inout std_ulogic;
    pci_serr         : inout std_ulogic;  -- open drain output
    pci_req 	       : inout std_ulogic;  -- tristate pad but never read
    pci_gnt          : in    std_ulogic;
    pci_int          : inout std_logic_vector(0 downto 0);
    pci_idsel_config : out   std_ulogic;
    pci_host_config  : out   std_ulogic;
    pci_66_config	   : out   std_ulogic;
    -- PCI arbiter
    pci_arb_req      : in    std_logic_vector(0 to 1);
    pci_arb_gnt      : out   std_logic_vector(0 to 1);
    -- Ethernet
    eth_gtxclk       : out   std_logic;
    eth_mdio         : inout std_logic;
    eth_txclk        : in    std_ulogic;
    eth_rxclk        : in    std_ulogic;
    eth_rxd          : in    std_logic_vector(7 downto 0);
    eth_rxdv         : in    std_ulogic;
    eth_rxer         : in    std_ulogic;
    eth_col          : in    std_ulogic;
    eth_crs          : in    std_ulogic;
    eth_mdint        : in    std_ulogic;
    eth_txd          : out   std_logic_vector(7 downto 0);
    eth_txen         : out   std_ulogic;
    eth_txer         : out   std_ulogic;
    eth_mdc          : out   std_ulogic;
    eth0_mdc	       : in    std_ulogic;
    eth0_mdint	     : in    std_ulogic;
   	eth0_mdio	       : in    std_ulogic;
    -- SpaceWire
    spw_din_p        : in    std_logic_vector(1 to CFG_SPW_SPWPORTS);
    spw_sin_p        : in    std_logic_vector(1 to CFG_SPW_SPWPORTS);
    spw_dout_p       : out   std_logic_vector(1 to CFG_SPW_SPWPORTS);
    spw_sout_p       : out   std_logic_vector(1 to CFG_SPW_SPWPORTS);

    -- Built-in JTAG interface
    -- No location constraint is necessary on these pins, though it is
    -- recommended for clarity. However, a clock constraint must be applied to
    -- tck. Note that if the Reveal debug inserter is to be used then these
    -- ports must be commented out and the AHBJTAG instantiation removed.
    tck              : in std_logic;
    tms              : in std_logic;
    tdi              : in std_logic;
    tdo              : out std_logic
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

  -- AMBA bus signals
  signal apbi  : apb_slv_in_type;
  signal apbo  : apb_slv_out_vector := (others => apb_none);
  signal ahbsi : ahb_slv_in_type;
  signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi : ahb_mst_in_type;
  signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);
  signal ahbmo_dma : ahb_mst_out_type;

  signal cgi : clkgen_in_type;
  signal cgo : clkgen_out_type;

  signal spmi : spimctrl_in_type;
  signal spmo : spimctrl_out_type;
  signal spim_rst : std_ulogic;

  signal aramo : ahbram_out_type;

  -- AHBSTAT
  signal stati : ahbstat_in_type;

  signal u1i, dui : uart_in_type;
  signal u1o, duo : uart_out_type;

  signal irqi : irq_in_vector(0 to 0);
  signal irqo : irq_out_vector(0 to 0);

  signal sysi : leon_dsu_stat_base_in_type;
  signal syso : leon_dsu_stat_base_out_type;
  signal perf : l3stat_in_type;

  --signal dsui : dsu_in_type;
  signal dsuo : dsu_out_type;
  signal ndsuact : std_ulogic;

  signal gpti : gptimer_in_type;

  signal clkm, rstn, clk100  : std_ulogic;
  signal rstraw              : std_logic;
  signal lock                : std_logic;

  -- GRGPIO signals
  signal gpio0i  : gpio_in_type;
  signal gpio0o  : gpio_out_type;

  -- PCI
  signal pcii : pci_in_type;
  signal pcio : pci_out_type;
  signal pci_lock : std_logic;
  signal pciclk         : std_ulogic;
  signal pci_host : std_logic;
  signal pci_66                       : std_logic           := '0'; -- dummy signal
  signal pci_dirq                     : std_logic_vector(3 downto 0);
  signal pci_rst : std_logic;
  signal pci_idsel : std_logic;
  -- Dummy signals to prevent conflicting drivers when target/master/dma is disabled
  -- This is necessary because grpci2 drives its output ports with ahbm_none when
  -- disabled. And because we use dynamic master numbering.
  signal pci_tahbmo : ahb_mst_out_type; -- PCI target AHB master
  signal pci_dahbmo : ahb_mst_out_type; -- PCI DMA AHB master
  signal pci_ahbso  : ahb_slv_out_type; -- PCI initiator(master) AHB slave
  -- Note: The PCI initiator/master is controlled by an AHB slave interface
  --       The PCI target/slave controls an AHB master interface
  --       The PCI DMA interface uses a separate AHB master, but the same PCI initiator
  -- The APB interface is always enabled.
  -- PCI arbiter
  signal pci_arb_req_n, pci_arb_gnt_n   : std_logic_vector(0 to 1);

   -- SpaceWire Router
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

  -- HSSL signals
  -- grhssl uses a single-entry vector parameter...
  signal ahbmi_vct   : ahb_mst_in_vector_type(0 downto 0);
  -- HSSL
  signal hssl_clk    : std_ulogic_vector(0 to CFG_HSSL_NUM-1);
  signal hssl_rstn   : std_ulogic_vector(0 to CFG_HSSL_NUM-1);
  signal hssli       : grhssl_in_type_vector(0 to CFG_HSSL_NUM-1);
  signal hsslo       : grhssl_out_type_vector(0 to CFG_HSSL_NUM-1);

  type hssl_cnt_vector is array (natural range <>) of std_logic_vector(9 downto 0);
  signal hssl_cnt, hssl_cnt_in : hssl_cnt_vector(0 to CFG_HSSL_NUM-1);

  type extvc_in_vct_type  is array (natural range <>) of extvc_in_arr_type;
  type extvc_out_vct_type is array (natural range <>) of extvc_out_arr_type;
  type extbc_in_vct_type  is array (natural range <>) of extbc_in_type;
  type extbc_out_vct_type is array (natural range <>) of extbc_out_type;
  signal hssl_extvci  : extvc_in_vct_type(CFG_GRHSSL_VC-1 downto 0);
  signal hssl_extvco  : extvc_out_vct_type(CFG_GRHSSL_VC-1 downto 0);
  signal hssl_extbci  : extbc_in_vct_type(CFG_GRHSSL_VC-1 downto 0);
  signal hssl_extbco  : extbc_out_vct_type(CFG_GRHSSL_VC-1 downto 0);
  signal spfispwbi    : spfi_spwdata_br_in_arr_type(CFG_GRHSSL_VC-1 downto 0);
  signal spfispwbo    : spfi_spwdata_br_out_arr_type(CFG_GRHSSL_VC-1 downto 0);
  signal bctcbi       : spfi_spwtc_br_in_arr_type(1 downto 0);
  signal bctcbo       : spfi_spwtc_br_out_arr_type(1 downto 0);

  -- Ethernet
  signal ethi : eth_in_type;
  signal etho : eth_out_type;
  signal egtx_clk : std_ulogic;

  -- SpaceWire TX CLK frequency in KHz
  constant SPW_CLKFREQ : integer := 200000;
  constant SPW_CLKDIV10 : std_logic_vector(7 downto 0) := conv_std_logic_vector(SPW_CLKFREQ/10000 - 1, 8);


  function to_int(value : boolean) return integer is
  begin
    if value then
      return 1;
    else
      return 0;
    end if;
  end function;


  -- AMBA Bus indexes
  -- Masters
  constant hmidx_ahbuart    : integer := CFG_NCPU - 1 + CFG_AHB_UART;
  constant hmidx_ahbjtag    : integer := hmidx_ahbuart + CFG_AHB_JTAG;
  constant hmidx_greth      : integer := hmidx_ahbjtag + CFG_GRETH;
  constant hmidx_grpci2     : integer := hmidx_greth + CFG_GRPCI2_TARGET;
  constant hdmidx_grpci2    : integer := hmidx_grpci2 + CFG_GRPCI2_DMA;
  constant hmidx_spwrtr     : integer := hdmidx_grpci2 + CFG_SPW_EN;
  constant hmidx_grhssl     : integer := hmidx_spwrtr + CFG_SPW_EN*(CFG_SPW_AMBAPORTS -1) + CFG_HSSL_EN;
  constant maxahbm          : integer := hmidx_grhssl +  CFG_HSSL_EN*(CFG_HSSL_NUM-1) + 1; -- total number of ahbm, latest hmidx + 1


  -- Slaves
  constant hsidx_dsu        : integer := CFG_NCPU - 1;
  constant hsidx_apbctrl    : integer := hsidx_dsu + 1; -- missing an enable constant for apbctrl
  constant hsidx_spimctrl   : integer := hsidx_apbctrl + CFG_SPIMCTRL;
  constant hsidx_ahbram_sim : integer := hsidx_spimctrl + 1*to_int(simulation);  
  constant hsidx_ahbram     : integer := hsidx_ahbram_sim + CFG_AHBRAMEN;
  constant hsidx_ftahbram   : integer := hsidx_ahbram + CFG_FTAHBRAM_EN;
  constant hsidx_grpci2     : integer := hsidx_ftahbram + CFG_GRPCI2_MASTER;
  constant hsidx_ahbrep     : integer := hsidx_grpci2
                                        --pragma translate_off
                                          + 1
                                        --pragma translate_on
                                        ;
  constant hsidx_spwrtr     : integer := hsidx_ahbrep + CFG_SPW_EN;
  constant hsidx_grhssl     : integer := hsidx_spwrtr + CFG_HSSL_EN;
  constant maxahbs          : integer := hsidx_grhssl + CFG_HSSL_EN*(CFG_HSSL_NUM-1) + 1;  -- total number of ahbs, latest hsidx + 1

  constant pidx_custom      : integer := 14;

  constant pidx_stat        : integer :=  CFG_NCPU - 1;
  constant pidx_apbuart     : integer :=  pidx_stat + CFG_UART1_ENABLE;
  constant pidx_ahbuart     : integer :=  pidx_apbuart + CFG_AHB_UART;
  constant pidx_gptimer     : integer :=  pidx_ahbuart + CFG_GPT_ENABLE;
  constant pidx_ftahbram    : integer :=  pidx_gptimer + CFG_FTAHBRAM_EN;
  constant pidx_grgpio      : integer :=  pidx_ftahbram + CFG_GRGPIO_EN;
  constant pidx_ahbstat     : integer :=  pidx_grgpio + CFG_AHBSTAT;
  constant pidx_irqmp       : integer :=  pidx_ahbstat + CFG_IRQ3_ENABLE;
  constant pidx_greth       : integer :=  pidx_irqmp + CFG_GRETH;
  constant pidx_grpci2      : integer :=  pidx_greth + to_int((CFG_GRPCI2_MASTER + CFG_GRPCI2_TARGET + CFG_GRPCI2_DMA) /= 0);
  constant pidx_pciarb      : integer :=  pidx_grpci2 + CFG_PCI_ARB;
  constant pidx_spwrtr      : integer := pidx_pciarb + CFG_SPW_EN;

  constant paddr_base       : integer :=  16#001#;  -- start position for addres allocation
  constant paddr_256byte    : integer :=  16#001#;  -- constant for 256 byte
  constant paddr_1kbyte     : integer :=  16#004#;  -- constant for 1k byte

  -- As per convention in leon designs:
  -- memctrl(ahb/apb bridge)->000, apbuart->100, irqmp->200, gptimer->300
  -- we don't use CFG_ flags as these indexes are "fixed" (as per convention)
  constant paddr_apbuart    : integer :=  paddr_base; -- requiers 256byte
  constant paddr_irqmp      : integer :=  paddr_apbuart + paddr_256byte; -- requiers 256byte
  constant paddr_gptimer    : integer :=  paddr_irqmp + paddr_256byte; -- requiers 256byte
  constant paddr_ahbuart    : integer :=  paddr_gptimer + paddr_256byte; -- requiers 256byte
  constant paddr_grgpio     : integer :=  paddr_ahbuart + CFG_AHB_UART*paddr_256byte; --requiers 256byte
  constant paddr_ahbstat    : integer :=  paddr_grgpio + CFG_GRGPIO_EN*paddr_256byte;-- requiers 256byte
  constant paddr_ftahbram   : integer :=  paddr_ahbstat + CFG_AHBSTAT*paddr_256byte;-- requiers 256byte
  constant paddr_spwrtr     : integer :=  paddr_ftahbram + CFG_FTAHBRAM_EN*paddr_256byte ; -- requiers 256byte
  constant paddr_grpci2     : integer :=  paddr_spwrtr + paddr_256byte*CFG_SPW_EN*CFG_SPW_AMBAPORTS; -- requiers 256byte
  constant paddr_pciarb     : integer :=  paddr_grpci2 + to_int((CFG_GRPCI2_MASTER + CFG_GRPCI2_TARGET + CFG_GRPCI2_DMA) /= 0)*paddr_256byte; -- requiers 256byte
  constant paddr_greth      : integer :=  paddr_pciarb + CFG_PCI_ARB*paddr_256byte; -- requiers 256byte
  constant paddr_stat       : integer :=  (paddr_greth/paddr_1kbyte + 1)*paddr_1kbyte ; -- requiers 1kbyte, need to go to the next 400 slot

  constant paddr_custom : integer := 16#100#;

  attribute keep                     : boolean;
  attribute keep of lock             : signal is true;
  attribute keep of clkm             : signal is true;
  attribute keep of egtx_clk         : signal is true;

  constant clock_mult : integer := 10;      -- Clock multiplier
  constant clock_div  : integer := 20;      -- Clock divider
  constant CPU_FREQ   : integer := 50000;  -- CPU freq in KHz

  type cnt16_vector is array (natural range <>) of std_logic_vector(15 downto 0);
  type cnt6_vector is array (natural range <>) of std_logic_vector(5 downto 0);

  --type apbdbg_reg_type is record
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
      lock_o   : out std_logic
      );
  end component;

begin

----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------

  vcc <= '1';
  gnd <= '0';

  pci_rst <= rstn;
  pciclk <= clk_in_33mhz;

  cgi.pllctrl <= "00";
  cgi.pllrst <= rstraw;

  rst0 : gaisler.misc.rstgen generic map (acthigh => 0)
    port map (gsrn, clkm, lock, rstn, rstraw);
  lock <= cgo.clklock;

  --this instance is needed to provide the general reset in a lattice
  --simulation environment
  GSR_INST: GSR
    port map (GSR_N => gsrn,
              CLK => clkm);

  clkgen_ip : pll_125i_50o
    port map(
      clki_i   => clk_in_125mhz,
      rstn_i   => gsrn,
      clkop_o  => clkm,
      clkos_o  => clk100,
      clkos2_o => open,
      lock_o   => cgo.clklock);

  ----------------------------------------------------------------------
  ---  AHB CONTROLLER  -------------------------------------------------
  ----------------------------------------------------------------------

  ahb0 : ahbctrl
    generic map (ioen => 1, nahbm => maxahbm , nahbs => maxahbs, fpnpen => CFG_FPNPEN, devid => GAISLER_GR740MINI)
    port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);

  -----------------------------------------------------------------------
  ---  AHBSTAT  ---------------------------------------------------------
  -----------------------------------------------------------------------

  ahbs : if CFG_AHBSTAT = 1 generate -- AHB status register
    ahbstat0 : ahbstat
      generic map (pindex => pidx_ahbstat, paddr  => paddr_ahbstat,
                  pirq => 11, nftslv => CFG_AHBSTATN)
      port map (rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(pidx_ahbstat));
  end generate;

  ----------------------------------------------------------------------
  ---  LEON3 processor  ------------------------------------------------
  ----------------------------------------------------------------------

  leon_en : if CFG_NCPU /=0 generate
    leon : leon_dsu_stat_base
      generic map (
        leon => CFG_LEON,
        ncpu => ncpu,
        fabtech     => fabtech,
        memtech     => memtech,
        memtechmod  => CFG_LEON_MEMTECH,
        nwindows    => CFG_NWIN,
        dsu         => CFG_DSU,
        fpu         => CFG_FPU,
        v8          => CFG_V8,
        cp          => 0,
        mac         => CFG_MAC,
        pclow       => pclow,
        notag       => 0,
        nwp         => CFG_NWP,
        icen        => CFG_ICEN,
        irepl       => CFG_IREPL,
        isets       => CFG_ISETS,
        ilinesize   => CFG_ILINE,
        isetsize    => CFG_ISETSZ,
        isetlock    => CFG_ILOCK,
        dcen        => CFG_DCEN,
        drepl       => CFG_DREPL,
        dsets       => CFG_DSETS,
        dlinesize   => CFG_DLINE,
        dsetsize    => CFG_DSETSZ,
        dsetlock    => CFG_DLOCK,
        dsnoop      => CFG_DSNOOP,
        ilram       => CFG_ILRAMEN,
        ilramsize   => CFG_ILRAMSZ,
        ilramstart  => CFG_ILRAMADDR,
        dlram       => CFG_DLRAMEN,
        dlramsize   => CFG_DLRAMSZ,
        dlramstart  => CFG_DLRAMADDR,
        mmuen       => CFG_MMUEN,
        itlbnum     => CFG_ITLBNUM,
        dtlbnum     => CFG_DTLBNUM,
        tlb_type    => CFG_TLB_TYPE,
        tlb_rep     => CFG_TLB_REP,
        lddel       => CFG_LDDEL,
        disas       => disas,
        tbuf        => CFG_ITBSZ,
        pwd         => CFG_PWD,
        svt         => CFG_SVT,
        rstaddr     => CFG_RSTADDR,
        smp         => ncpu-1,
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
        dsu_hindex  => hsidx_dsu,
        dsu_haddr   => 16#D00#,
        dsu_hmask   => 16#F00#,
        atbsz       => CFG_ATBSZ,
        stat        => CFG_STAT_ENABLE,
        stat_pindex => pidx_stat,
        stat_paddr  => paddr_stat,
        stat_pmask  => 16#ffc#,
        stat_ncnt   => CFG_STAT_CNT,
        stat_nmax   => CFG_STAT_NMAX)
      port map (
        rstn       => rstn,
        ahbclk     => clkm,
        cpuclk     => clkm,
        hclken     => vcc,
        leon_ahbmi => ahbmi,
        leon_ahbmo => ahbmo(CFG_NCPU-1 downto 0),
        leon_ahbsi => ahbsi,
        leon_ahbso => ahbso,
        irqi       => irqi,
        irqo       => irqo,
        stat_apbi  => apbi,
        stat_apbo  => apbo(pidx_stat),
        stat_ahbsi => ahbsi,
        stati      => perf,
        dsu_ahbsi  => ahbsi,
        dsu_ahbso  => ahbso(hsidx_dsu),
        dsu_tahbmi => ahbmi,
        dsu_tahbsi => ahbsi,
        sysi       => sysi,
        syso       => syso);

      sysi.dsu_enable <= '1';
      sysi.dsu_break  <= '0';
      led(0) <= syso.proc_errorn;
      led(1) <= syso.dsu_active;

  end generate;

  ----------------------------------------------------------------------
  ---  Debug UART  -----------------------------------------------------
  ----------------------------------------------------------------------

  -- If jtag debug link is active, then the uart is not instantiated
  dcomgen0 : if CFG_AHB_UART = 1 and CFG_AHB_JTAG = 0 generate
    dcom0: ahbuart              -- Debug UART
      generic map (hindex => hmidx_ahbuart, pindex => pidx_ahbuart, paddr => paddr_ahbuart)
      port map (rstn, clkm, dui, duo, apbi, apbo(pidx_ahbuart), ahbmi, ahbmo(hmidx_ahbuart));

    dui.rxd    <= rxduart;
    dui.ctsn   <= '0';
    dui.extclk <= '0';
    txduart    <= duo.txd;
  end generate;

  nodcom0 : if CFG_AHB_UART = 0 generate
    duo.txd <= '0'; duo.rtsn <= '1';
  end generate;


  -- Debug JTAG
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
      generic map (hindex => hsidx_spimctrl, hirq => 10, faddr => 0, fmask => 16#ff0#, --16 MByte
                   ioaddr => 16#400#, iomask => 16#fff#,
                  spliten => CFG_SPLIT,
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


  -- On-chip RAM (volatile memory)
  ocram : if CFG_FTAHBRAM_EN = 0 and CFG_AHBRAMEN = 1 and simulation = false generate
    ahbram0 : ahbram
      generic map (hindex => hsidx_ahbram, haddr => CFG_AHBRADDR, tech => CFG_MEMTECH,
                   kbytes => CFG_AHBRSZ, pipe => CFG_AHBRPIPE)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbram));
  end generate;

  ftocram : if CFG_FTAHBRAM_EN = 1 and simulation = false generate
    ftahbram0 : ftahbram
      generic map (
        hindex    => hsidx_ftahbram, haddr => CFG_FTAHBRAM_ADDR,
        tech      => CFG_MEMTECH, kbytes    => CFG_FTAHBRAM_SZ,
        pindex    => pidx_ftahbram,  paddr => paddr_ftahbram,
        edacen    => CFG_FTAHBRAM_EDAC, autoscrub => CFG_FTAHBRAM_SCRU,
        errcnten  => CFG_FTAHBRAM_ECNT, cntbits   => CFG_FTAHBRAM_EBIT,
        ahbpipe   => CFG_FTAHBRAM_PIPE)
      port map (
        rst   => rstn,
        clk   => clkm,
        ahbsi => ahbsi,
        ahbso => ahbso(hsidx_ftahbram),
        apbi  => apbi,
        apbo  => apbo(pidx_ftahbram),
        aramo => aramo);
  end generate;

  ---------------------------------------------------------------------
  ---   PCI   ---------------------------------------------------------
  ---------------------------------------------------------------------

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

  pci_66_config    <= '0'; -- 33 MHz operation

  pci_gen : if (CFG_GRPCI2_MASTER + CFG_GRPCI2_TARGET + CFG_GRPCI2_DMA)  /= 0  generate
    pci0 : grpci2
      generic map (
        memtech => memtech,
        oepol => OEPOL,
        hmindex => hmidx_grpci2,
        hdmindex => hdmidx_grpci2,
        hsindex => hsidx_grpci2,
        haddr => 16#c00#,
        hmask => 16#f00#, --256Mbyte
        ioaddr => 16#000#,
        pindex => pidx_grpci2,
        paddr => paddr_grpci2,
        irq => 0,
        irqmode => 0,
        master => CFG_GRPCI2_MASTER,
        target => CFG_GRPCI2_TARGET,
        dma => CFG_GRPCI2_DMA,
        tracebuffer => CFG_GRPCI2_TRACE,
        vendorid => CFG_GRPCI2_VID,
        deviceid => CFG_GRPCI2_DID,
        classcode => CFG_GRPCI2_CLASS,
        revisionid => CFG_GRPCI2_RID,
        cap_pointer => CFG_GRPCI2_CAP,
        ext_cap_pointer => CFG_GRPCI2_NCAP,
        iobase => CFG_AHBIO,
        extcfg => CFG_GRPCI2_EXTCFG,
        bar0 => CFG_GRPCI2_BAR0,
        bar0_map => 16#400000#, -- AHBRAM base address
        bar1 => CFG_GRPCI2_BAR1,
        bar1_map => 16#800000#, -- APB register area base address
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
        nsync => 2,
        hostrst => 2,
        multifunc => 0,
        bypass => CFG_GRPCI2_BYPASS)
      port map (
        rst => rstn,
        clk => clkm,
        pciclk => pciclk,
        dirq => pci_dirq,
        pcii => pcii, pcio => pcio,
        apbi => apbi, apbo => apbo(pidx_grpci2),
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

  end generate;

 pcipads0 : pcipads
    generic map (
		  padtech => padtech,
		  noreset => 1, -- internally generated reset (not a pad)
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

	pcia0 : if CFG_PCI_ARB = 1 generate -- PCI arbiter
    pciarb0 : pciarb
      generic map (pindex => pidx_pciarb, paddr => paddr_pciarb,
                  apb_en => CFG_PCI_ARBAPB, nb_agents => CFG_PCI_ARB_NGNT )
      port map ( clk => pciclk, rst_n => pcii.rst,
           req_n => pci_arb_req_n, frame_n => pcii.frame,
           gnt_n => pci_arb_gnt_n, pclk => clkm,
           prst_n => rstn, apbi => apbi, apbo => apbo(pidx_pciarb));

      pgnt_pad : outpadv generic map (tech => padtech, width => 2)
        port map (pci_arb_gnt, pci_arb_gnt_n);
      preq_pad : inpadv generic map (tech => padtech, width => 2)
        port map (pci_arb_req, pci_arb_req_n);

  end generate;

  -----------------------------------------------------------------------
  ---  SPACWWIRE ROUTER -------------------------------------------------
  -----------------------------------------------------------------------

  -- SpaceWire Transmitter clock should be clocked at 100 MHz
  spw_txclk  <= (others => clkm);
  spw_txclkn <= (others => '0');

  -- rxclkin and nrxclki are unused
  spw_rxclkin <= '0';

   no_spw : if CFG_SPW_EN = 0 generate

      spwloop : for i in 1 to CFG_SPW_SPWPORTS generate

          spwr_txd_pad : outpad generic map (padtech)
            port map (spw_dout_p(i), gnd);

          spwr_txs_pad : outpad generic map (padtech)
            port map (spw_sout_p(i), gnd);

      end generate spwloop;

   end generate;

  spwrtr : if CFG_SPW_EN /= 0 generate

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
          rxclko    => spw_rxclko(i)    -- Receiver Clock Output
          );

    end generate phy_loop;

    -- SpaceWire router
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
        fifoen        => 1,             -- Enable FIFO interfaces
        spwports      => CFG_SPW_SPWPORTS,
        ambaports     => CFG_SPW_AMBAPORTS,  -- Number of AMBA ports
        fifoports     => CFG_SPW_FIFOPORTS,  -- Number of FIFO ports
        arbitration   => CFG_SPW_ARBITRATION,
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
        pirq          => 3,             -- Starting IRQ
        ahbslven      => 1,
        cfghindex     => hsidx_spwrtr,
        cfghaddr      => 16#C40#,
        cfghmask      => 16#FC0#,
        timerbits     => CFG_SPW_TIMERBITS,
        pnp           => CFG_SPW_PNP,
        autoscrub     => CFG_SPW_AUTOSCRUB,
        sim           => 0,             -- Simulation mode, not used
        dualport      => 0,
        charcntbits   => 0,             -- Character counters disabled
        pktcntbits    => 0,             -- Packet counters disabled
        prescalermin  => 250,     -- Minimum value for writes to reload reg
        spacewired    => 1,
        interruptdist => 2,
        apbctrl       => 0,
        rmapmaxsize   => 4,
        gpolbits      => 0,
        gpopbits      => 0,
        gpibits       => 0,
        customport    => 0,
        codecclkgate  => 0,
        inputtest     => 0,
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
        apbi       => apbi,
        apbo       => spwr_apbo,
        ahbsi      => ahbsi,
        ahbso      => ahbso(hsidx_spwrtr),
        ri         => spwri,
        ro         => spwro
        );

    spwr_ahbmi <= (others => ahbmi);

    ahbspw : for i in 0 to CFG_SPW_AMBAPORTS-1 generate
      ahbmo(hmidx_spwrtr+i) <= spwr_ahbmo(i);
      apbo(pidx_spwrtr+i)   <= spwr_apbo(i);
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

  end generate spwrtr;

  -- SpaceWire Pads

  spwrtr_pads : if CFG_SPW_EN = 1 and CFG_SPW_LOOP_BACK = 0 and CFG_SPW_PADS = 1 generate

    loop_pads : for i in 0 to CFG_SPW_SPWPORTS-1 generate

            -- SpaceWire Pads
       -- Outputs
       spw_txd_pad : outpad generic map (padtech, lvds, x33v)
         port map (spw_dout_p(i + 1), do(2*i));

       spw_txs_pad : outpad generic map (padtech, lvds, x33v)
         port map (spw_sout_p(i + 1), so(2*i));

       -- Inputs
      spwr_rxd_pad : inpad generic map (tech => padtech)
         port map (spw_din_p(i + 1), dtmp(i));

       spwr_rxs_pad : inpad generic map (tech => padtech)
         port map (spw_sin_p(i + 1), stmp(i));

    end generate loop_pads;

  end generate spwrtr_pads;

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

        -- spacefibre codec
        spfi_i : grspfi_ahb
          generic map (
            tech               => memtech,
            hmindex            => hmidx_grhssl+i,
            hsindex            => hsidx_grhssl+i,
            haddr              => 16#800# + i*16#010#,
            hmask              => 16#ff0#,
            hirq               => 5 + i,
            use_8b10b          => 1,
            use_sep_txclk      => 0,
            sel_16_20_bit_mode => 0,
            ticks_2us          => 125,
            tx_skip_freq       => 5000,
            prbs_init1         => 1,
            depth_rbuf_data    => 8,
            depth_rbuf_fct     => 4,
            depth_rbuf_bc      => 4,
            num_vc             => CFG_GRHSSL_VC,
            fct_multiplier     => 1,
            depth_vc_rx_buf    => 10,
            depth_vc_tx_buf    => 10,
            remote_fct_cnt_max => 9,
            width_bw_credit    => 20,
            min_bw_credit      => 52428,
            idle_time_limit    => 62500,
            num_dmach          => 1,
            num_txdesc         => 256,
            num_rxdesc         => 512,
            depth_dma_fifo     => 32,
            depth_bc_fifo      => 4,
            use_async_rxrst    => 1,
            rmap               => CFG_GRHSSL_RMAP,
            numextvc           => 1,
            numextbc           => 1,
            nodeaddr           => 254)
          port map (
            clk        => clkm,
            rstn       => rstn,
            spfi_clk   => hssl_clk(i),
            spfi_rstn  => hssl_rstn(i),
            spfi_txclk => '0', -- unused (40-bit serdes interface)
            -- ahb interface
            ahbmi      => ahbmi_vct,
            ahbmo      => ahbmo(hmidx_grhssl+i downto hmidx_grhssl+i),
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

      -- SpaceFibre to SpaceWire bridges
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
          bo        => spfispwbo(i)
          );

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
          bo        => bctcbo(i)
          );

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

    nospfi_gen : for i in CFG_HSSL_NUM to 3 generate
      serdes_clkconf_in.cnt(i) <= X"5555";
	  serdes_clkconf_in.hssl_cnt(i) <= (others => '0');
    end generate;


    ahbmi_vct(0) <= ahbmi;

    -- The only point of the SerDes wrapper is to make the top level a
    -- bit less verbose. Due to non-consecutive channels being used, it
    -- requires four near identical component declarations and instantiations
    -- to attach to four channels.
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
        rstn => serdes_clkconf_out.rstin, --gsrn,

        -- Enable-signals for external reference clocks
        --en_sdq0_refclk => en_sdq0_refclk,
        --en_sdq1_refclk => en_sdq1_refclk,

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

    -- Enable signals for external oscillators.
    -- NOTE: In rev A-6, one of the oscillators is always enabled due to
    -- an oversight in the BOM.
    en_sdq1_refclk <= serdes_clkconf_out.en_sdq1_refclk;
    en_sdq0_refclk <= serdes_clkconf_out.en_sdq0_refclk;

    gpreg0 : grgprbank
        generic map (
          pindex => pidx_custom,
          paddr => paddr_custom,
          pmask => 16#fff#,
          regbits => 16,
          nregs => 5,
          extrst => 1,
          rdataen => 1)
        port map (
          rst => rstn,
          clk => clkm,
          apbi => apbi,
          apbo => apbo(pidx_custom),
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

  eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC
    e0 : grethm
	    generic map(
	      hindex => hmidx_greth,
        pindex => pidx_greth,
	      paddr  => paddr_greth,
	      pirq   => 12, --GRETH_PIRQ
	      memtech => memtech,
	      --mdcscaler => CPU_FREQ/1000,
        mdcscaler => 25,
	      rmii => 0, -- PHY do not support rmii mode.
	      enable_mdio => 1,
	      fifosize => CFG_ETH_FIFO,
        nsync => 2,
	      edcl => CFG_DSU_ETH,
	      edclbufsz => CFG_ETH_BUF,
	      phyrstadr => 2,
        macaddrh => CFG_ETH_ENM,
	      macaddrl => CFG_ETH_ENL,
	      enable_mdint => 1,
	      oepol => OEPOL ,
        ipaddrh => CFG_ETH_IPM,
	      ipaddrl => CFG_ETH_IPL,
        giga => CFG_GRETH1G,
	      multicast => 0,
	      ramdebug => 0,
	      gmiimode => 0)
	    port map(
	      rst   => rstn,
	      clk   => clkm,
	      ahbmi => ahbmi,
	      ahbmo => ahbmo(hmidx_greth),
	      apbi  => apbi,
	      apbo  => apbo(pidx_greth),
	      ethi  => ethi,
	      etho  => etho);

    emdc_pad : outpad generic map (tech => padtech)
      port map (eth_mdc, etho.mdc);
    emdio_pad : iopad generic map (tech => padtech)
	    port map (eth_mdio, etho.mdio_o, etho.mdio_oe, ethi.mdio_i);
    emdint_pad : inpad generic map (tech => padtech)
      port map (eth_mdint, ethi.mdint);
    erxd_pad : inpadv generic map (tech => padtech, width => 8)
      port map (eth_rxd, ethi.rxd(7 downto 0));
    erxdv_pad : inpad generic map (tech => padtech)
      port map (eth_rxdv, ethi.rx_dv);
    erxer_pad : inpad generic map (tech => padtech)
      port map (eth_rxer, ethi.rx_er);
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

    ethi.rx_clk <= eth_rxclk;
	  ethi.tx_clk <= eth_txclk;
	  ethi.gtx_clk <= clk_in_125mhz;
	  eth_gtxclk <= clk_in_125mhz;

  end generate;

  ----------------------------------------------------------------------
  ---  APB Bridge and various periherals -------------------------------
  ----------------------------------------------------------------------

    apb0 : apbctrl       -- APB Bridge
      generic map (hindex => hsidx_apbctrl, haddr => 16#800#)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_apbctrl), apbi, apbo);

  uart1_gen : if CFG_UART1_ENABLE = 1 generate
    uart1 : apbuart      -- UART 1
      generic map (pindex   => pidx_apbuart, paddr => paddr_apbuart, pirq => 2, console => dbguart)
      port map (rstn, clkm, apbi, apbo(pidx_apbuart), u1i, u1o);
    u1i.rxd    <= rxduart;
    u1i.ctsn   <= '0';
    u1i.extclk <= '0';

    txduartpad: if CFG_AHB_UART = 0 or CFG_AHB_JTAG = 1 generate
      txduart    <= u1o.txd;
    end generate;
  end generate;

  irqmp_gen : if CFG_IRQ3_ENABLE = 1 generate
    irqctrl0 : irqmp     -- Interrupt controller
      generic map (pindex => pidx_irqmp, paddr => paddr_irqmp, ncpu => 1)
      port map (rstn, clkm, apbi, apbo(pidx_irqmp), irqo, irqi);
  end generate;

  gptimer_gen : if CFG_GPT_ENABLE = 1 generate
    timer0 : gptimer     -- Time Unit
      generic map (pindex => pidx_gptimer, paddr => paddr_gptimer, pirq => 8,
                 sepirq => 1, ntimers => 2)
      port map (rstn, clkm, apbi, apbo(pidx_gptimer), gpti, open);
    gpti <= gpti_dhalt_drive('0');
  end generate;

  gpio0 : if CFG_GRGPIO_EN = 1 generate
  -- 0-1 LED14 LED15
  -- 6-2 GPIO[0..4]
  grgpio0: grgpio       -- GPIO
    generic map(
      pindex    => pidx_grgpio, paddr => paddr_grgpio,
      nbits     => CFG_GRGPIO_WIDTH,
      imask     => CFG_GRGPIO_IMASK,
      pirq      => 4,
      irqgen    => 1,
      iflagreg  => 1)
    port map(rstn, clkm, apbi, apbo(pidx_grgpio), gpio0i, gpio0o);

  gpio_leds_pad : outpadv generic map (tech => padtech, width => 2)
    port map (led(3 downto 2), gpio0o.dout(1 downto 0));
   gpio_gpio_pads : iopadvv generic map (tech => padtech, width => 5)
     port map (gpio, gpio0o.dout(6 downto 2), gpio0o.oen(6 downto 2), gpio0i.din(6 downto 2));
  end generate;

  ----------------------------------------------------------------------
  ------------------ AHBRAM for simulation purposes --------------------
  ----------------------------------------------------------------------

  ahbsim_gen: if simulation = true generate
   -- pragma translate_off
    sim_ahbram : ahbram_sim
      generic map (
        hindex        => hsidx_ahbram_sim,
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
        ahbso   => ahbso(hsidx_ahbram_sim));
  -- pragma translate_on
  end generate ahbsim_gen;

  -----------------------------------------------------------------------
  --  Test report module, only used for simulation ----------------------
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
      msg1 => "LEON3 Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel => 1 );
  -- pragma translate_on

end rtl;
