------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2013, Aeroflex Gaisler
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
--  LEON3 Demonstration design
--  Copyright (C) 2013 Aeroflex Gaisler
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
library grlib, techmap;
use grlib.amba.all;
use grlib.stdlib.all;
use techmap.gencomp.all;
library gaisler;
use gaisler.memctrl.all;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.spi.all;
use gaisler.can.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.ddrpkg.all;
-- pragma translate_off
use gaisler.sim.all;
-- pragma translate_on

library esa;
use esa.memoryctrl.all;
use work.config.all;

entity leon3mp is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    clktech   : integer := CFG_CLKTECH;
    disas     : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart   : integer := CFG_DUART;   -- Print UART on console
    pclow     : integer := CFG_PCLOW
  );
  port (
    -- clocks
    OSC_50_BANK2  : in std_logic;
    OSC_50_BANK3  : in std_logic;
    OSC_50_BANK4  : in std_logic;
    OSC_50_BANK5  : in std_logic;
    OSC_50_BANK6  : in std_logic;
    OSC_50_BANK7  : in std_logic;
    PLL_CLKIN_p   : in std_logic;
    SMA_CLKIN_p   : in std_logic;
--  SMA_GXBCLK_p  : in std_logic;
    GCLKIN        : in std_logic;
    GCLKOUT_FPGA  : out std_logic;
    SMA_CLKOUT_p  : out std_logic;

    -- cpu reset
    CPU_RESET_n   : in std_ulogic;

    -- max i/o
    MAX_CONF_D    : inout std_logic_vector(3 downto 0);
    MAX_I2C_SCLK  : out std_logic;
    MAX_I2C_SDAT  : inout std_logic;

    -- LEDs
    LED           : out std_logic_vector(7 downto 0);

    -- buttons
    BUTTON        : in std_logic_vector(3 downto 0);
        
    -- switches
    SW            : in std_logic_vector(3 downto 0);

    -- slide switches
    SLIDE_SW      : in std_logic_vector(3 downto 0);

    -- temperature
    TEMP_SMCLK    : out std_logic;
    TEMP_SMDAT    : inout std_logic;
    TEMP_INT_n    : in std_logic;

    -- current
    CSENSE_ADC_FO : out std_logic;
    CSENSE_SCK    : inout std_logic;
    CSENSE_SDI    : out std_logic;
    CSENSE_SDO    : in std_logic;
    CSENSE_CS_n   : out std_logic_vector(1 downto 0);
        
    -- fan
    FAN_CTRL      : out std_logic;

    -- eeprom
    EEP_SCL       : out std_logic;
    EEP_SDA       : inout std_logic;

    -- sdcard
    SD_CLK        : out std_logic;
    SD_CMD        : inout std_logic;
    SD_DAT        : inout std_logic_vector(3 downto 0);
    SD_WP_n       : in std_logic;

    -- Ethernet interfaces
    ETH_INT_n     : in std_logic_vector(3 downto 0);
    ETH_MDC       : out std_logic_vector(3 downto 0);
    ETH_MDIO      : inout std_logic_vector(3 downto 0);
    ETH_RST_n     : out std_ulogic;
    ETH_RX_p      : in std_logic_vector(3 downto 0);
    ETH_TX_p      : out std_logic_vector(3 downto 0);

    -- PCIe interfaces
--    PCIE_PREST_n  : in std_ulogic;
--    PCIE_REFCLK_p : in std_ulogic;
--    PCIE_RX_p     : in std_logic_vector(7 downto 0);
--    PCIE_SMBCLK   : in std_logic;
--    PCIE_SMBDAT   : inout std_logic;
--    PCIE_TX_p     : out std_logic_vector(7 downto 0);
--    PCIE_WAKE_n   : out std_logic;

    -- Flash and SRAM, shared signals
    FSM_A         : out std_logic_vector(25 downto 1);
    FSM_D         : inout std_logic_vector(15 downto 0);

    -- Flash control
    FLASH_ADV_n   : out std_ulogic;
    FLASH_CE_n    : out std_ulogic;
    FLASH_CLK     : out std_ulogic;
    FLASH_OE_n    : out std_ulogic;
    FLASH_RESET_n : out std_ulogic;
    FLASH_RYBY_n  : in std_ulogic;
    FLASH_WE_n    : out std_ulogic;

    -- SSRAM control
    SSRAM_ADV     : out std_ulogic;
    SSRAM_BWA_n   : out std_ulogic;
    SSRAM_BWB_n   : out std_ulogic;
    SSRAM_CE_n    : out std_ulogic;
    SSRAM_CKE_n   : out std_ulogic;
    SSRAM_CLK     : out std_ulogic;
    SSRAM_OE_n    : out std_ulogic;
    SSRAM_WE_n    : out std_ulogic;

    -- USB OTG
--    OTG_A         : out std_logic_vector(17 downto 1);
--    OTG_CS_n      : out std_ulogic;
--    OTG_D         : inout std_logic_vector(31 downto 0);
--    OTG_DC_DACK   : out std_ulogic;
--    OTG_DC_DREQ   : in std_ulogic;
--    OTG_DC_IRQ    : in std_ulogic;
--    OTG_HC_DACK   : out std_ulogic;
--    OTG_HC_DREQ   : in std_ulogic;
--    OTG_HC_IRQ    : in std_ulogic;
--    OTG_OE_n      : out std_ulogic;
--    OTG_RESET_n   : out std_ulogic;
--    OTG_WE_n      : out std_ulogic;

    -- SATA
--    SATA_REFCLK_p    : in  std_logic;
--    SATA_HOST_RX_p   : in  std_logic_vector(1 downto 0);
--    SATA_HOST_TX_p   : out std_logic_vector(1 downto 0);
--    SATA_DEVICE_RX_p : in  std_logic_vector(1 downto 0);
--    SATA_DEVICE_TX_p : out std_logic_vector(1 downto 0);


    -- DDR2 SODIMM
    M1_DDR2_addr  : out std_logic_vector(15 downto 0);
    M1_DDR2_ba    : out std_logic_vector(2 downto 0);
    M1_DDR2_cas_n : out std_logic;
    M1_DDR2_cke   : out std_logic_vector(1 downto 0);
    M1_DDR2_clk   : out std_logic_vector(1 downto 0);
    M1_DDR2_clk_n : out std_logic_vector(1 downto 0);
    M1_DDR2_cs_n  : out std_logic_vector(1 downto 0);
    M1_DDR2_dm    : out std_logic_vector(7 downto 0);
    M1_DDR2_dq    : inout std_logic_vector(63 downto 0);
    M1_DDR2_dqs   : inout std_logic_vector(7 downto 0);
    M1_DDR2_dqsn  : inout std_logic_vector(7 downto 0);
    M1_DDR2_odt   : out std_logic_vector(1 downto 0);
    M1_DDR2_ras_n : out std_logic;
--    M1_DDR2_SA    :  out std_logic_vector(1 downto 0);
--    M1_DDR2_SCL   : out std_logic;
--    M1_DDR2_SDA   : inout std_logic;
    M1_DDR2_we_n  : out std_logic;

    M1_DDR2_oct_rdn     : in  std_logic;
    M1_DDR2_oct_rup     : in  std_logic;

    -- DDR2 SODIMM
--    M2_DDR2_addr  : out std_logic_vector(15 downto 0);
--    M2_DDR2_ba    : out std_logic_vector(2 downto 0);
--    M2_DDR2_cas_n : out std_logic;
--    M2_DDR2_cke   : out std_logic_vector(1 downto 0);
--    M2_DDR2_clk   : out std_logic_vector(1 downto 0);
--    M2_DDR2_clk_n : out std_logic_vector(1 downto 0);
--    M2_DDR2_cs_n  : out std_logic_vector(1 downto 0);
--    M2_DDR2_dm    : out std_logic_vector(7 downto 0);
--    M2_DDR2_dq    : inout std_logic_vector(63 downto 0);
--    M2_DDR2_dqs   : inout std_logic_vector(7 downto 0);
--    M2_DDR2_dqsn  : inout std_logic_vector(7 downto 0);
--    M2_DDR2_odt   : out std_logic_vector(1 downto 0);
--    M2_DDR2_ras_n : out std_logic;
--    M2_DDR2_SA    : out std_logic_vector(1 downto 0);
--    M2_DDR2_SCL   : out std_logic;
--    M2_DDR2_SDA   : inout std_logic;
--    M2_DDR2_we_n  : out std_logic;

    -- GPIO
    GPIO0_D       : inout std_logic_vector(35 downto 0);
    GPIO1_D       : inout std_logic_vector(35 downto 0);
        
    -- Ext I/O
--    EXT_IO        : inout std_logic;
        
    -- HSMC A
--    HSMA_CLKIN_n1 : in std_logic;
--    HSMA_CLKIN_n2 : in std_logic;
--    HSMA_CLKIN_p1 : in std_logic;
--    HSMA_CLKIN_p2 : in std_logic;
--    HSMA_CLKIN0   : in std_logic;
--    HSMA_CLKOUT_n2 : out std_logic;
--    HSMA_CLKOUT_p2 : out std_logic;
--    HSMA_D        : inout std_logic_vector(3 downto 0);
--    HSMA_GXB_RX_p : in std_logic_vector(3 downto 0);
--    HSMA_GXB_TX_p : out std_logic_vector(3 downto 0);
--    HSMA_OUT_n1   : inout std_logic;
--    HSMA_OUT_p1   : inout std_logic;
--    HSMA_OUT0     : inout std_logic;
--    HSMA_REFCLK_p : in std_logic;
--    HSMA_RX_n     : inout std_logic_vector(16 downto 0);
--    HSMA_RX_p     : inout std_logic_vector(16 downto 0);
--    HSMA_TX_n     : inout std_logic_vector(16 downto 0);
--    HSMA_TX_p     : inout std_logic_vector(16 downto 0);
        
    -- HSMC_B
--    HSMB_CLKIN_n1 : in std_logic;
--    HSMB_CLKIN_n2 : in std_logic;
--    HSMB_CLKIN_p1 : in std_logic;
--    HSMB_CLKIN_p2 : in std_logic;
--    HSMB_CLKIN0   : in std_logic;
--    HSMB_CLKOUT_n2 : out std_logic;
--    HSMB_CLKOUT_p2 : out std_logic;
--    HSMB_D        : inout std_logic_vector(3 downto 0);
--    HSMB_GXB_RX_p : in std_logic_vector(3 downto 0);
--    HSMB_GXB_TX_p : out std_logic_vector(3 downto 0);
--    HSMB_OUT_n1   : inout std_logic;
--    HSMB_OUT_p1   : inout std_logic;
--    HSMB_OUT0     : inout std_logic;
--    HSMB_REFCLK_p : in std_logic;
--    HSMB_RX_n     : inout std_logic_vector(16 downto 0);
--    HSMB_RX_p     : inout std_logic_vector(16 downto 0);
--    HSMB_TX_n     : inout std_logic_vector(16 downto 0);
--    HSMB_TX_p     : inout std_logic_vector(16 downto 0);
    
    -- HSMC i2c
--    HSMC_SCL      : out std_logic;
--    HSMC_SDA      : inout std_logic;

    -- Display
--    SEG0_D        : out std_logic_vector(6 downto 0);
--    SEG1_D        : out std_logic_vector(6 downto 0);
--    SEG0_DP       : out std_ulogic;
--    SEG1_DP       : out std_ulogic;
    
    -- UART
    UART_CTS      : out std_ulogic;
    UART_RTS      : in std_ulogic;
    UART_RXD      : in std_ulogic;
    UART_TXD      : out std_ulogic
    );
end;

architecture rtl of leon3mp is

  component sgmii2gmii is
    port (
      ref_clk        : in  std_logic                     := '0';             --  pcs_ref_clk_clock_connection.clk
      clk            : in  std_logic                     := '0';             -- control_port_clock_connection.clk
      reset          : in  std_logic                     := '0';             --              reset_connection.reset
      address        : in  std_logic_vector(4 downto 0)  := (others => '0'); --                  control_port.address
      readdata       : out std_logic_vector(15 downto 0);                    --                              .readdata
      read           : in  std_logic                     := '0';             --                              .read
      writedata      : in  std_logic_vector(15 downto 0) := (others => '0'); --                              .writedata
      write          : in  std_logic                     := '0';             --                              .write
      waitrequest    : out std_logic;                                        --                              .waitrequest
      tx_clk         : out std_logic;                                        -- pcs_transmit_clock_connection.clk
      rx_clk         : out std_logic;                                        --  pcs_receive_clock_connection.clk
      reset_tx_clk   : in  std_logic                     := '0';             -- pcs_transmit_reset_connection.reset
      reset_rx_clk   : in  std_logic                     := '0';             --  pcs_receive_reset_connection.reset
      gmii_rx_dv     : out std_logic;                                        --               gmii_connection.gmii_rx_dv
      gmii_rx_d      : out std_logic_vector(7 downto 0);                     --                              .gmii_rx_d
      gmii_rx_err    : out std_logic;                                        --                              .gmii_rx_err
      gmii_tx_en     : in  std_logic                     := '0';             --                              .gmii_tx_en
      gmii_tx_d      : in  std_logic_vector(7 downto 0)  := (others => '0'); --                              .gmii_tx_d
      gmii_tx_err    : in  std_logic                     := '0';             --                              .gmii_tx_err
      tx_clkena      : out std_logic;                                        --       clock_enable_connection.tx_clkena
      rx_clkena      : out std_logic;                                        --                              .rx_clkena
      mii_rx_dv      : out std_logic;                                        --                mii_connection.mii_rx_dv
      mii_rx_d       : out std_logic_vector(3 downto 0);                     --                              .mii_rx_d
      mii_rx_err     : out std_logic;                                        --                              .mii_rx_err
      mii_tx_en      : in  std_logic                     := '0';             --                              .mii_tx_en
      mii_tx_d       : in  std_logic_vector(3 downto 0)  := (others => '0'); --                              .mii_tx_d
      mii_tx_err     : in  std_logic                     := '0';             --                              .mii_tx_err
      mii_col        : out std_logic;                                        --                              .mii_col
      mii_crs        : out std_logic;                                        --                              .mii_crs
      set_10         : out std_logic;                                        --       sgmii_status_connection.set_10
      set_1000       : out std_logic;                                        --                              .set_1000
      set_100        : out std_logic;                                        --                              .set_100
      hd_ena         : out std_logic;                                        --                              .hd_ena
      led_crs        : out std_logic;                                        --         status_led_connection.crs
      led_link       : out std_logic;                                        --                              .link
      led_col        : out std_logic;                                        --                              .col
      led_an         : out std_logic;                                        --                              .an
      led_char_err   : out std_logic;                                        --                              .char_err
      led_disp_err   : out std_logic;                                        --                              .disp_err
      rx_recovclkout : out std_logic;                                        --     serdes_control_connection.export
      txp            : out std_logic;                                        --             serial_connection.txp
      rxp            : in  std_logic                     := '0'              --                              .rxp
    );
  end component sgmii2gmii;

  component pll_125 is
    port(
      inclk0  : in std_logic  := '0';
      c0      : out std_logic
    );
  end component;

  constant blength : integer := 12;
  constant fifodepth : integer := 8;

  signal vcc, gnd   : std_logic_vector(4 downto 0);

  signal memi  : memory_in_type;
  signal memo  : memory_out_type;
  signal wpo   : wprot_out_type;
  signal del_addr : std_logic_vector(25 downto 1);
  signal del_ce, del_we: std_logic;
  signal del_bwa_n, del_bwb_n: std_logic_vector(1 downto 0);

  signal apbi  : apb_slv_in_type;
  signal apbo  : apb_slv_out_vector := (others => apb_none);
  signal ahbsi : ahb_slv_in_type;
  signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi : ahb_mst_in_type;
  signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);

  signal clkm, rstn, rstraw : std_logic;
  signal cgi  : clkgen_in_type;
  signal cgo  : clkgen_out_type;
  signal u1i, dui  : uart_in_type;
  signal u1o, duo  : uart_out_type;

  signal irqi : irq_in_vector(0 to CFG_NCPU-1);
  signal irqo : irq_out_vector(0 to CFG_NCPU-1);

  signal dbgi : l3_debug_in_vector(0 to CFG_NCPU-1);
  signal dbgo : l3_debug_out_vector(0 to CFG_NCPU-1);

  signal dsui : dsu_in_type;
  signal dsuo : dsu_out_type; 

  signal spii, spislvi : spi_in_type;
  signal spio, spislvo : spi_out_type;
  signal slvsel : std_logic_vector(CFG_SPICTRL_SLVS-1 downto 0);

  signal stati : ahbstat_in_type;

  signal gpti : gptimer_in_type;
  signal gpto : gptimer_out_type;

  signal gpioi : gpio_in_type;
  signal gpioo : gpio_out_type;

  signal dsubren : std_logic;

  signal tck, tms, tdi, tdo : std_logic;

  signal fpi : grfpu_in_vector_type;
  signal fpo : grfpu_out_vector_type;

  signal gmiii1, gmiii2 : eth_in_type;
  signal gmiio1, gmiio2 : eth_out_type;

  signal sgmiii1, sgmiii2 :  eth_sgmii_in_type; 
  signal sgmiio1, sgmiio2 :  eth_sgmii_out_type;

  signal eth_tx_pad, eth_rx_pad : std_logic_vector(3 downto 0) ;

  signal reset1_tx_clk, reset1_rx_clk, reset2_tx_clk, reset2_rx_clk, ref_clk, ctrl_rst: std_logic;

  signal led_crs1, led_link1, led_col1, led_an1, led_char_err1, led_disp_err1 : std_logic;
  signal led_crs2, led_link2, led_col2, led_an2, led_char_err2, led_disp_err2 : std_logic;

  constant BOARD_FREQ : integer := 100000;        -- Board frequency in KHz
  constant CPU_FREQ : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;  -- cpu frequency in KHz
  constant IOAEN : integer := 0;
  constant OEPOL : integer := padoen_polarity(padtech);

  attribute syn_keep : boolean;
  attribute syn_preserve : boolean;
  attribute keep : boolean;

  signal ddr_clkv   : std_logic_vector(2 downto 0);
  signal ddr_clkbv  : std_logic_vector(2 downto 0);
  signal ddr_ckev   : std_logic_vector(1 downto 0);
  signal ddr_csbv   : std_logic_vector(1 downto 0);
  signal ddr_clk_fb           : std_ulogic;
  signal clkm125              : std_logic;
  signal clklock, lock, clkml : std_logic;
begin

----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------
  
  vcc <= (others => '1');
  gnd <= (others => '0');

  cgi.pllctrl <= "00"; cgi.pllrst <= rstraw;

  clklock <= cgo.clklock and lock;
  clkgen0 : clkgen                      -- clock generator using toplevel generic 'freq'
    generic map (tech    => CFG_CLKTECH, clk_mul => CFG_CLKMUL,
                 clk_div => CFG_CLKDIV, sdramen => 0,
                 noclkfb => CFG_CLK_NOFB, freq => BOARD_FREQ)
    port map (clkin => PLL_CLKIN_p, pciclkin => gnd(0), clk => clkm, clkn => open,
              clk2x => open, sdclk => open, pciclk => open,
              cgi   => cgi, cgo => cgo);
  
  -- clk125_pad : clkpad generic map (tech => padtech) port map (clk125, lclk125);
  -- clkm125 <= clk125;

  rst0 : rstgen                 -- reset generator
    port map (CPU_RESET_n, clkm, clklock, rstn, rstraw);

----------------------------------------------------------------------
---  AHB CONTROLLER --------------------------------------------------
----------------------------------------------------------------------

  ahb0 : ahbctrl                -- AHB arbiter/multiplexer
    generic map (defmast => CFG_DEFMST, split => CFG_SPLIT, 
                 rrobin => CFG_RROBIN, ioaddr => CFG_AHBIO, ioen => IOAEN,
                 nahbm => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+CFG_GRETH,
                 nahbs => 8)
    port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);

----------------------------------------------------------------------
---  LEON3 processor and DSU -----------------------------------------
----------------------------------------------------------------------

  cpu : for i in 0 to CFG_NCPU-1 generate
    nosh : if CFG_GRFPUSH = 0 generate    
      u0 : leon3s               -- LEON3 processor      
        generic map (i, fabtech, memtech, CFG_NWIN, CFG_DSU, CFG_FPU*(1-CFG_GRFPUSH), CFG_V8, 
                     0, CFG_MAC, pclow, CFG_NOTAG, CFG_NWP, CFG_ICEN, CFG_IREPL, CFG_ISETS, CFG_ILINE, 
                     CFG_ISETSZ, CFG_ILOCK, CFG_DCEN, CFG_DREPL, CFG_DSETS, CFG_DLINE, CFG_DSETSZ,
                     CFG_DLOCK, CFG_DSNOOP, CFG_ILRAMEN, CFG_ILRAMSZ, CFG_ILRAMADDR, CFG_DLRAMEN,
                     CFG_DLRAMSZ, CFG_DLRAMADDR, CFG_MMUEN, CFG_ITLBNUM, CFG_DTLBNUM, CFG_TLB_TYPE, CFG_TLB_REP, 
                     CFG_LDDEL, disas, CFG_ITBSZ, CFG_PWD, CFG_SVT, CFG_RSTADDR, CFG_NCPU-1,
                     0, 0, CFG_MMU_PAGE)
        port map (clkm, rstn, ahbmi, ahbmo(i), ahbsi, ahbso, 
                  irqi(i), irqo(i), dbgi(i), dbgo(i));
    end generate;
  end generate;

  sh : if CFG_GRFPUSH = 1 generate
    cpu : for i in 0 to CFG_NCPU-1 generate
      u0 : leon3sh              -- LEON3 processor      
        generic map (i, fabtech, memtech, CFG_NWIN, CFG_DSU, CFG_FPU, CFG_V8, 
                     0, CFG_MAC, pclow, CFG_NOTAG, CFG_NWP, CFG_ICEN, CFG_IREPL, CFG_ISETS, CFG_ILINE, 
                     CFG_ISETSZ, CFG_ILOCK, CFG_DCEN, CFG_DREPL, CFG_DSETS, CFG_DLINE, CFG_DSETSZ,
                     CFG_DLOCK, CFG_DSNOOP, CFG_ILRAMEN, CFG_ILRAMSZ, CFG_ILRAMADDR, CFG_DLRAMEN,
                     CFG_DLRAMSZ, CFG_DLRAMADDR, CFG_MMUEN, CFG_ITLBNUM, CFG_DTLBNUM, CFG_TLB_TYPE, CFG_TLB_REP, 
                     CFG_LDDEL, disas, CFG_ITBSZ, CFG_PWD, CFG_SVT, CFG_RSTADDR, CFG_NCPU-1,
                     0, 0, CFG_MMU_PAGE)
        port map (clkm, rstn, ahbmi, ahbmo(i), ahbsi, ahbso, 
                  irqi(i), irqo(i), dbgi(i), dbgo(i), fpi(i), fpo(i));
    end generate;

    grfpush0 : grfpushwx generic map ((CFG_FPU-1), CFG_NCPU, fabtech)
      port map (clkm, rstn, fpi, fpo);
    
  end generate;

  errorn_pad : odpad generic map (tech => padtech) port map (LED(0), dbgo(0).error);
  
  dsugen : if CFG_DSU = 1 generate
    dsu0 : dsu3                 -- LEON3 Debug Support Unit
      generic map (hindex => 2, haddr => 16#900#, hmask => 16#F00#, 
                   ncpu => CFG_NCPU, tbits => 30, tech => memtech, irq => 0, kbytes => CFG_ATBSZ)
      port map (rstn, clkm, ahbmi, ahbsi, ahbso(2), dbgo, dbgi, dsui, dsuo);
    dsui.enable <= '1'; 
    dsubre_pad : inpad generic map (tech => padtech) port map (BUTTON(0), dsubren);
    dsui.break <= not dsubren; 
    dsuact_pad : outpad generic map (tech => padtech) port map (LED(1), dsuo.active);
  end generate;
  nodsu : if CFG_DSU = 0 generate 
    ahbso(2) <= ahbs_none; dsuo.tstop <= '0'; dsuo.active <= '0';
  end generate;
  
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0: ahbuart		-- Debug UART
      generic map (hindex => CFG_NCPU, pindex => 7, paddr => 7)
      port map (rstn, clkm, dui, duo, apbi, apbo(7), ahbmi, ahbmo(CFG_NCPU));
    dui.rxd <= uart_rxd when slide_sw(0) = '0' else '1';
  end generate;
--  nouah : if CFG_AHB_UART = 0 generate apbo(7) <= apb_none; end generate;
  
  ahbjtaggen0 :if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => CFG_NCPU+CFG_AHB_UART)
      port map(rstn, clkm, tck, tms, tdi, tdo, ahbmi, ahbmo(CFG_NCPU+CFG_AHB_UART),
               open, open, open, open, open, open, open, gnd(0));
  end generate;
  
----------------------------------------------------------------------
---  Memory controllers ----------------------------------------------
----------------------------------------------------------------------
  data_pad : iopadvv generic map (tech => padtech, width => 16, oepol => OEPOL)
    port map (FSM_D, memo.data(31 downto 16), memo.vbdrive(31 downto 16), memi.data(31 downto 16));
  
  FSM_A <= memo.address(25 downto 1);
  FLASH_CLK <= clkm;
  FLASH_RESET_n <= rstn;
  FLASH_CE_n <= memo.romsn(0);
  FLASH_OE_n <= memo.oen;
  FLASH_WE_n <= memo.writen;
  FLASH_ADV_n <= '0';

  memi.brdyn <= '1';
  memi.bexcn <= '1';
  memi.writen <= '1';
  memi.wrn <= (others => '1');
  memi.bwidth <= "01";
  memi.sd <= (others => '0');
  memi.cb <= (others => '0');
  memi.scb <= (others => '0');
  memi.edac <= '0';

  mctrl0 : if CFG_MCTRL_LEON2 = 1 generate
    mctrl0 : mctrl generic map (hindex => 0, pindex => 0,
      romaddr => 16#000#, rommask => 16#fc0#,
      ioaddr => 0, iomask => 0,
      ramaddr => 0, rammask => 0,
      ram8 => CFG_MCTRL_RAM8BIT, 
      ram16 => CFG_MCTRL_RAM16BIT,
      sden => CFG_MCTRL_SDEN, 
      invclk => CFG_MCTRL_INVCLK,
      sepbus => CFG_MCTRL_SEPBUS)
    port map (rstn, clkm, memi, memo, ahbsi, ahbso(0), apbi, apbo(0), wpo, open);
  end generate;

  nomctrl0: if CFG_MCTRL_LEON2 = 0 generate
    ahbso(0) <= ahbs_none;
    apbo(0) <= apb_none;
    memo <= memory_out_none;
  end generate;

  ddr2if0: entity work.ddr2if
    generic map(
      hindex    => 3,
      haddr     => 16#400#,
      hmask     => 16#C00#,
      burstlen  => 32
    )
    port map (
      pll_ref_clk     => OSC_50_BANK4,
      global_reset_n  => CPU_RESET_n,
      mem_a           => M1_DDR2_addr(13 downto 0),
      mem_ba          => M1_DDR2_ba,
      mem_ck          => M1_DDR2_clk,
      mem_ck_n        => M1_DDR2_clk_n,
      mem_cke         => M1_DDR2_cke(0),
      mem_cs_n        => M1_DDR2_cs_n(0),
      mem_dm          => M1_DDR2_dm,
      mem_ras_n       => M1_DDR2_ras_n,
      mem_cas_n       => M1_DDR2_cas_n,
      mem_we_n        => M1_DDR2_we_n,
      mem_dq          => M1_DDR2_dq,
      mem_dqs         => M1_DDR2_dqs,
      mem_dqs_n       => M1_DDR2_dqsn,
      mem_odt         => M1_DDR2_odt(0),
      ahb_clk         => clkm,
      ahb_rst         => rstn,
      ahbsi           => ahbsi,
      ahbso           => ahbso(3),
      oct_rdn         => M1_DDR2_oct_rdn,
      oct_rup         => M1_DDR2_oct_rup
    );

  lock <= '1';
----------------------------------------------------------------------
---  APB Bridge and various periherals -------------------------------
----------------------------------------------------------------------

  apb0 : apbctrl                                -- AHB/APB bridge
    generic map (hindex => 1, haddr => CFG_APBADDR)
    port map (rstn, clkm, ahbsi, ahbso(1), apbi, apbo );

  ua1 : if CFG_UART1_ENABLE /= 0 generate
    uart1 : apbuart                     -- UART 1
      generic map (pindex => 1, paddr => 1,  pirq => 2, console => dbguart,
                   fifosize => CFG_UART1_FIFO)
      port map (rstn, clkm, apbi, apbo(1), u1i, u1o);
    u1i.rxd <= '1' when slide_sw(0) = '0' else uart_rxd;
    u1i.ctsn <= uart_rts; u1i.extclk <= '0'; 
  end generate;
  uart_txd <= u1o.txd when slide_sw(0) = '1' else duo.txd;
  uart_cts <= u1o.rtsn;
  noua0 : if CFG_UART1_ENABLE = 0 generate apbo(1) <= apb_none; end generate;

  irqctrl : if CFG_IRQ3_ENABLE /= 0 generate
    irqctrl0 : irqmp                    -- interrupt controller
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
    timer0 : gptimer                    -- timer unit
      generic map (pindex => 3, paddr => 3, pirq => CFG_GPT_IRQ, 
                   sepirq => CFG_GPT_SEPIRQ, sbits => CFG_GPT_SW, ntimers => CFG_GPT_NTIM, 
                   nbits => CFG_GPT_TW)
      port map (rstn, clkm, apbi, apbo(3), gpti, open);
    gpti.dhalt <= dsuo.tstop; gpti.extclk <= '0';
  end generate;
  notim : if CFG_GPT_ENABLE = 0 generate apbo(3) <= apb_none; end generate;

  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate     -- GR GPIO unit
    grgpio0: grgpio
      generic map( pindex => 9, paddr => 9, imask => CFG_GRGPIO_IMASK, 
                   nbits => CFG_GRGPIO_WIDTH)
      port map( rstn, clkm, apbi, apbo(9), gpioi, gpioo);

    pio_pads : for i in 0 to CFG_GRGPIO_WIDTH-1 generate
      pio_pad : iopad generic map (tech => padtech)
        port map (GPIO0_D(i), gpioo.dout(i), gpioo.oen(i), gpioi.din(i));
    end generate;
  end generate;

  spic: if CFG_SPICTRL_ENABLE = 1 generate  -- SPI controller
    spi1 : spictrl
      generic map (pindex => 10, paddr  => 10, pmask  => 16#fff#, pirq => 10,
                   fdepth => CFG_SPICTRL_FIFO, slvselen => CFG_SPICTRL_SLVREG,
                   slvselsz => CFG_SPICTRL_SLVS, odmode => 0, netlist => 0,
                   syncram => CFG_SPICTRL_SYNCRAM, ft => CFG_SPICTRL_FT)
      port map (rstn, clkm, apbi, apbo(10), spii, spio, slvsel);
    spii.spisel <= '1';                 -- Master only
    miso_pad : inpad generic map (tech => padtech)
      port map (CSENSE_SDO, spii.miso);
    mosi_pad : outpad generic map (tech => padtech)
      port map (CSENSE_SDI, spio.mosi);
    sck_pad  : outpad generic map (tech => padtech)
      port map (CSENSE_SCK, spio.sck);
    slvsel_pad : outpad generic map (tech => padtech)
      port map (CSENSE_CS_n(0), slvsel(0));
    slvseladc_pad : outpad generic map (tech => padtech)
      port map (CSENSE_ADC_FO, slvsel(1));
  end generate spic;
  
  ahbs : if CFG_AHBSTAT = 1 generate    -- AHB status register
    stati.cerror(0) <= memo.ce;
    ahbstat0 : ahbstat
      generic map (pindex => 15, paddr => 15, pirq => 1,
                   nftslv => CFG_AHBSTATN)
      port map (rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(15));
  end generate;
  nop2 : if CFG_AHBSTAT = 0 generate apbo(15) <= apb_none; end generate;

-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

  eth1 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC

    pll0: entity work.pll_125
      port map (OSC_50_BANK3, ref_clk);

    rst1 : rstgen                 -- reset generator
      generic map (acthigh => 1)
      port map (CPU_RESET_n, clkm, '1', ctrl_rst, open);

    rst10 : rstgen                 -- reset generator
      generic map (acthigh => 1)
      port map (CPU_RESET_n, gmiii1.tx_clk, '1', reset1_tx_clk, open);

    rst11 : rstgen                 -- reset generator
      generic map (acthigh => 1)
      port map (CPU_RESET_n, gmiii1.rx_clk, '1', reset1_rx_clk, open);

    bridge1: sgmii2gmii
      port map(
        ref_clk         => ref_clk,                         -- in      pcs_ref_clk_clock_connection.clk
        clk             => clkm,                            -- in     control_port_clock_connection.clk
        reset           => ctrl_rst,                        -- in                  reset_connection.reset
        address         => zero32(4 downto 0),              -- in                      control_port.address
        readdata        => open,                            -- out                                 .readdata
        read            => '0',                             -- in                                  .read
        writedata       => zero32(15 downto 0),             -- in                                  .writedata
        write           => '0',                             -- in                                  .write
        waitrequest     => open,                            -- out                                 .waitrequest
        tx_clk          => gmiii1.tx_clk,                   -- out    pcs_transmit_clock_connection.clk
        rx_clk          => gmiii1.rx_clk,                   -- out     pcs_receive_clock_connection.clk
        reset_tx_clk    => reset1_tx_clk,                   -- in     pcs_transmit_reset_connection.reset
        reset_rx_clk    => reset1_rx_clk,                   -- in      pcs_receive_reset_connection.reset
        gmii_rx_dv      => gmiii1.rx_dv,                    -- out                  gmii_connection.gmii_rx_dv
        gmii_rx_d       => gmiii1.rxd,                      -- out                                 .gmii_rx_d
        gmii_rx_err     => gmiii1.rx_er,                    -- out                                 .gmii_rx_err
        gmii_tx_en      => gmiio1.tx_en,                    -- in                                  .gmii_tx_en
        gmii_tx_d       => gmiio1.txd,                      -- in                                  .gmii_tx_d
        gmii_tx_err     => gmiio1.tx_er,                    -- in                                  .gmii_tx_err
        tx_clkena       => open,                            -- out          clock_enable_connection.tx_clkena
        rx_clkena       => open,                            -- out                                 .rx_clkena
        mii_rx_dv       => open,                            -- out                   mii_connection.mii_rx_dv
        mii_rx_d        => open,                            -- out                                 .mii_rx_d
        mii_rx_err      => open,                            -- out                                 .mii_rx_err
        mii_tx_en       => '0',                             -- in                                  .mii_tx_en
        mii_tx_d        => zero32(3 downto 0),              -- in                                  .mii_tx_d
        mii_tx_err      => '0',                             -- in                                  .mii_tx_err
        mii_col         => open,                            -- out                                 .mii_col
        mii_crs         => open,                            -- out                                 .mii_crs
        set_10          => open,                            -- out          sgmii_status_connection.set_10
        set_1000        => open,                            -- out                                 .set_1000
        set_100         => open,                            -- out                                 .set_100
        hd_ena          => open,                            -- out                                 .hd_ena
        led_crs         => led_crs1,                         -- out            status_led_connection.crs
        led_link        => led_link1,                        -- out                                 .link
        led_col         => open,                            -- out                                 .col
        led_an          => open,                            -- out                                 .an
        led_char_err    => open,                            -- out                                 .char_err
        led_disp_err    => open,                            -- out                                 .disp_err
        rx_recovclkout  => open,                            -- out        serdes_control_connection.export
        txp             => ETH_TX_p(0),                     -- out                serial_connection.txp
        rxp             => ETH_RX_p(0)                      -- in                                  .rxp
      );

    led2_pad : outpad generic map (tech => padtech) port map (LED(2), led_crs1);
    led3_pad : outpad generic map (tech => padtech) port map (LED(3), led_link1);
    --led4_pad : outpad generic map (tech => padtech) port map (LED(4), led_col);
    --led5_pad : outpad generic map (tech => padtech) port map (LED(5), led_an);
    --led6_pad : outpad generic map (tech => padtech) port map (LED(6), led_char_err);
    --led7_pad : outpad generic map (tech => padtech) port map (LED(7), led_disp_err);

    e1 : grethm
      generic map(
        hindex      => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG,
        pindex      => 11,
        paddr       => 11,
        pirq        => 6,
        memtech     => stratix3,
        mdcscaler   => CPU_FREQ/1000,
        enable_mdio => 1,
        fifosize    => CFG_ETH_FIFO,
        nsync       => 2,
        edcl        => CFG_DSU_ETH,
        edclbufsz   => CFG_ETH_BUF,
        macaddrh    => CFG_ETH_ENM,
        macaddrl    => CFG_ETH_ENL,
        phyrstadr   => 0,
        ipaddrh     => CFG_ETH_IPM,
        ipaddrl     => CFG_ETH_IPL,
        giga        => CFG_GRETH1G
      )
      port map(
        rst   => rstn,
        clk   => clkm,
        ahbmi => ahbmi,
        ahbmo => ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG),
        apbi  => apbi,
        apbo  => apbo(11),
        ethi  => gmiii1,
        etho  => gmiio1
      );

    -- MDIO interface setup
    emdio_pad1 : iopad generic map (tech => padtech)
      port map (ETH_MDIO(0), gmiio1.mdio_o, gmiio1.mdio_oe, gmiii1.mdio_i);

    emdc_pad1 : outpad generic map (tech => padtech)
      port map (ETH_MDC(0), gmiio1.mdc);

    eint_pad1 : inpad generic map (tech => padtech)
      port map (ETH_INT_n(0), gmiii1.mdint);

    erst_pad1 : outpad generic map (tech => padtech)
      port map (ETH_RST_n, gmiio1.reset);

    gmiii1.edclsepahb <= '0';
    gmiii1.edcldisable <= '0';
    gmiii1.phyrstaddr <= (others => '0');
    gmiii1.edcladdr <= (others => '0');

    gmiii1.gtx_clk <= ref_clk;
    gmiii1.rmii_clk <= '0';
    gmiii1.rx_col <= '0';
    gmiii1.rx_crs <= '0';

  end generate;

  noeth1 : if CFG_GRETH = 0 generate
    gmiio1 <= eth_out_none;
  end generate;

  eth2: if CFG_GRETH2 = 1 generate -- Gaisler ethernet MAC

    rst20 : rstgen                 -- reset generator
      generic map (acthigh => 1)
      port map (CPU_RESET_n, gmiii2.tx_clk, '1', reset2_tx_clk, open);

    rst21 : rstgen                 -- reset generator
      generic map (acthigh => 1)
      port map (CPU_RESET_n, gmiii2.rx_clk, '1', reset2_rx_clk, open);

    bridge2: sgmii2gmii
      port map(
        ref_clk         => ref_clk,                         -- in      pcs_ref_clk_clock_connection.clk
        clk             => clkm,                            -- in     control_port_clock_connection.clk
        reset           => ctrl_rst,                        -- in                  reset_connection.reset
        address         => zero32(4 downto 0),              -- in                      control_port.address
        readdata        => open,                            -- out                                 .readdata
        read            => '0',                             -- in                                  .read
        writedata       => zero32(15 downto 0),             -- in                                  .writedata
        write           => '0',                             -- in                                  .write
        waitrequest     => open,                            -- out                                 .waitrequest
        tx_clk          => gmiii2.tx_clk,                   -- out    pcs_transmit_clock_connection.clk
        rx_clk          => gmiii2.rx_clk,                   -- out     pcs_receive_clock_connection.clk
        reset_tx_clk    => reset2_tx_clk,                   -- in     pcs_transmit_reset_connection.reset
        reset_rx_clk    => reset2_rx_clk,                   -- in      pcs_receive_reset_connection.reset
        gmii_rx_dv      => gmiii2.rx_dv,                    -- out                  gmii_connection.gmii_rx_dv
        gmii_rx_d       => gmiii2.rxd,                      -- out                                 .gmii_rx_d
        gmii_rx_err     => gmiii2.rx_er,                    -- out                                 .gmii_rx_err
        gmii_tx_en      => gmiio2.tx_en,                    -- in                                  .gmii_tx_en
        gmii_tx_d       => gmiio2.txd,                      -- in                                  .gmii_tx_d
        gmii_tx_err     => gmiio2.tx_er,                    -- in                                  .gmii_tx_err
        tx_clkena       => open,                            -- out          clock_enable_connection.tx_clkena
        rx_clkena       => open,                            -- out                                 .rx_clkena
        mii_rx_dv       => open,                            -- out                   mii_connection.mii_rx_dv
        mii_rx_d        => open,                            -- out                                 .mii_rx_d
        mii_rx_err      => open,                            -- out                                 .mii_rx_err
        mii_tx_en       => '0',                             -- in                                  .mii_tx_en
        mii_tx_d        => zero32(3 downto 0),              -- in                                  .mii_tx_d
        mii_tx_err      => '0',                             -- in                                  .mii_tx_err
        mii_col         => open,                            -- out                                 .mii_col
        mii_crs         => open,                            -- out                                 .mii_crs
        set_10          => open,                            -- out          sgmii_status_connection.set_10
        set_1000        => open,                            -- out                                 .set_1000
        set_100         => open,                            -- out                                 .set_100
        hd_ena          => open,                            -- out                                 .hd_ena
        led_crs         => led_crs2,                        -- out            status_led_connection.crs
        led_link        => led_link2,                       -- out                                 .link
        led_col         => open,                            -- out                                 .col
        led_an          => open,                            -- out                                 .an
        led_char_err    => open,                            -- out                                 .char_err
        led_disp_err    => open,                            -- out                                 .disp_err
        rx_recovclkout  => open,                            -- out        serdes_control_connection.export
        txp             => ETH_TX_p(1),                     -- out                serial_connection.txp
        rxp             => ETH_RX_p(1)                      -- in                                  .rxp
      );

    led4_pad : outpad generic map (tech => padtech) port map (LED(4), led_crs2);
    led5_pad : outpad generic map (tech => padtech) port map (LED(5), led_link2);

    e2 : grethm
      generic map(
        hindex      => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+CFG_GRETH,
        pindex      => 12,
        paddr       => 12,
        pirq        => 7,
        memtech     => stratix3,
        mdcscaler   => CPU_FREQ/1000,
        enable_mdio => 1,
        fifosize    => CFG_ETH2_FIFO,
        nsync       => 2,
        edcl        => CFG_DSU_ETH,
        edclbufsz   => CFG_ETH_BUF,
        macaddrh    => CFG_ETH_ENM,
        macaddrl    => CFG_ETH_ENL,
        phyrstadr   => 0,
        ipaddrh     => CFG_ETH_IPM,
        ipaddrl     => CFG_ETH_IPL,
        giga        => CFG_GRETH21G
      )
      port map(
        rst   => rstn,
        clk   => clkm,
        ahbmi => ahbmi,
        ahbmo => ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+CFG_GRETH),
        apbi  => apbi,
        apbo  => apbo(12),
        ethi  => gmiii2,
        etho  => gmiio2
      );

      -- MDIO interface setup
      emdio_pad2 : iopad generic map (tech => padtech)
        port map (ETH_MDIO(1), gmiio2.mdio_o, gmiio2.mdio_oe, gmiii2.mdio_i);

      emdc_pad2 : outpad generic map (tech => padtech)
        port map (ETH_MDC(1), gmiio2.mdc);

      eint_pad2 : inpad generic map (tech => padtech)
        port map (ETH_INT_n(1), gmiii2.mdint);

      --gmiio2.reset <= ; -- not connected, using gmiio1.reset
      gmiii2.edclsepahb <= '0';
      gmiii2.edcldisable <= '0';
      gmiii2.phyrstaddr <= "00001";
      gmiii2.edcladdr <= (others => '0');

      gmiii2.gtx_clk <= ref_clk;
      gmiii2.rmii_clk <= '0';
      gmiii2.rx_col <= '0';
      gmiii2.rx_crs <= '0';

    end generate;

  noeth2 : if CFG_GRETH2 = 0 generate
    gmiio2 <= eth_out_none;
  end generate;

-----------------------------------------------------------------------
---  AHB RAM ----------------------------------------------------------
-----------------------------------------------------------------------

--  ocram : if CFG_AHBRAMEN = 1 generate 
--    ahbram0 : ftahbram generic map (hindex => 7, haddr => CFG_AHBRADDR, 
--      tech => CFG_MEMTECH, kbytes => CFG_AHBRSZ, pindex => 6,
--      paddr => 6, edacen => CFG_AHBRAEDAC, autoscrub => CFG_AHBRASCRU,
--      errcnten => CFG_AHBRAECNT, cntbits => CFG_AHBRAEBIT)
--    port map ( rstn, clkm, ahbsi, ahbso(7), apbi, apbo(6), open);
--  end generate;
--
--  nram : if CFG_AHBRAMEN = 0 generate ahbso(7) <= ahbs_none; end generate;

-----------------------------------------------------------------------
---  Drive unused bus elements  ---------------------------------------
-----------------------------------------------------------------------

nam : for i in (CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+CFG_GRETH+CFG_GRETH2) to NAHBMST-1 generate
  ahbmo(i) <= ahbm_none;
end generate;
-- nap0 : for i in 11 to NAPBSLV-1 generate apbo(i) <= apb_none; end generate;
-- apbo(6) <= apb_none;

--ahbmo(ahbmo'high downto nahbm) <= (others => ahbm_none);
ahbso(ahbso'high downto 5) <= (others => ahbs_none);
--apbo(napbs to apbo'high) <= (others => apb_none);

-----------------------------------------------------------------------
---  Test report module  ----------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off

  test0 : ahbrep generic map (hindex => 4, haddr => 16#200#)
    port map (rstn, clkm, ahbsi, ahbso(4));

-- pragma translate_on
-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
    generic map (
      msg1 => "LEON3 TerASIC DE4 Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel => 1
      );
-- pragma translate_on
end;
