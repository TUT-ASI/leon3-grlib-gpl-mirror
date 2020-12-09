-----------------------------------------------------------------------------
--  NOELV Xilinx VC707 Demonstration design
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
use grlib.config.all;
use grlib.config_types.all;
use techmap.gencomp.all;
use techmap.allclkgen.all;

library gaisler;
use gaisler.noelv.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.i2c.all;
use gaisler.spi.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.grusb.all;
use gaisler.l2cache.all;
use gaisler.subsys.all;
use gaisler.axi.all;
use gaisler.plic.all;
use gaisler.noelv.all;
-- pragma translate_off
use gaisler.sim.all;
library unisim;
use unisim.all;
-- pragma translate_on

use work.config.all;

entity noelvmp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart                 : integer := CFG_DUART;   -- Print UART on console
    pclow                   : integer := CFG_PCLOW;
    SIM_BYPASS_INIT_CAL     : string := "OFF";
    SIMULATION              : string := "FALSE";
    USE_MIG_INTERFACE_MODEL : boolean := false;
    autonegotiation         : integer := 1;
    riscv_mmu           : integer := 2;
    pmp_no_tor          : integer :=  0;  -- Disable PMP TOR
    pmp_entries         : integer :=  8;  -- Implemented PMP registers
    pmp_g               : integer :=  1   -- PMP grain is 2^(pmp_g + 2) bytes
--    pmp_msb             : integer := 31   -- High bit for PMP checks
    
  );
  port (
    reset                  : in    std_ulogic;
    clk200p                : in    std_ulogic;  -- 200 MHz clock
    clk200n                : in    std_ulogic;  -- 200 MHz clock
    address                : out   std_logic_vector(25 downto 0);
    data                   : inout std_logic_vector(15 downto 0);
    oen                    : out   std_ulogic;
    writen                 : out   std_ulogic;
    romsn                  : out   std_logic;
    adv                    : out   std_logic;
    ddr3_dq                : inout std_logic_vector(63 downto 0);
    ddr3_dqs_p             : inout std_logic_vector(7 downto 0);
    ddr3_dqs_n             : inout std_logic_vector(7 downto 0);
    ddr3_addr              : out   std_logic_vector(13 downto 0);
    ddr3_ba                : out   std_logic_vector(2 downto 0);
    ddr3_ras_n             : out   std_logic;
    ddr3_cas_n             : out   std_logic;
    ddr3_we_n              : out   std_logic;
    ddr3_reset_n           : out   std_logic;
    ddr3_ck_p              : out   std_logic_vector(0 downto 0);
    ddr3_ck_n              : out   std_logic_vector(0 downto 0);
    ddr3_cke               : out   std_logic_vector(0 downto 0);
    ddr3_cs_n              : out   std_logic_vector(0 downto 0);
    ddr3_dm                : out   std_logic_vector(7 downto 0);
    ddr3_odt               : out   std_logic_vector(0 downto 0);
    dsurx                  : in    std_ulogic;
    dsutx                  : out   std_ulogic;
    dsuctsn                : in    std_ulogic;
    dsurtsn                : out   std_ulogic;
    button                 : in    std_logic_vector(3 downto 0);
    switch                 : inout std_logic_vector(4 downto 0); 
    led                    : out   std_logic_vector(6 downto 0);
    iic_scl                : inout std_ulogic;
    iic_sda                : inout std_ulogic;
    usb_refclk_opt         : in    std_logic;
    usb_clkout             : in    std_logic;
    usb_d                  : inout std_logic_vector(7 downto 0);
    usb_nxt                : in    std_logic;
    usb_stp                : out   std_logic;
    usb_dir                : in    std_logic;
    usb_resetn             : out   std_ulogic;
    gtrefclk_p             : in    std_logic;
    gtrefclk_n             : in    std_logic;
    txp                    : out   std_logic;
    txn                    : out   std_logic;
    rxp                    : in    std_logic;
    rxn                    : in    std_logic;
    emdio                  : inout std_logic;
    emdc                   : out   std_ulogic;
    eint                   : in    std_ulogic;
    erst                   : out   std_ulogic;
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
    mdio_io_port_3_mdc     : out   std_ulogic;
    --
    reset_port_4           : out   std_ulogic;
    reset_port_5           : out   std_ulogic;
    reset_port_6           : out   std_ulogic;
    reset_port_7           : out   std_ulogic;
    --
    rgmii_port_4_rxc       : in    std_ulogic;
    rgmii_port_4_rx_ctl    : in    std_ulogic;
    rgmii_port_4_rd        : in    std_logic_vector(3 downto 0);
    rgmii_port_4_txc       : out   std_ulogic;
    rgmii_port_4_tx_ctl    : out   std_ulogic;
    rgmii_port_4_td        : out   std_logic_vector(3 downto 0);
    rgmii_port_5_rxc       : in    std_ulogic;
    rgmii_port_5_rx_ctl    : in    std_ulogic;
    rgmii_port_5_rd        : in    std_logic_vector(3 downto 0);
    rgmii_port_5_txc       : out   std_ulogic;
    rgmii_port_5_tx_ctl    : out   std_ulogic;
    rgmii_port_5_td        : out   std_logic_vector(3 downto 0);
    rgmii_port_6_rxc       : in    std_ulogic;
    rgmii_port_6_rx_ctl    : in    std_ulogic;
    rgmii_port_6_rd        : in    std_logic_vector(3 downto 0);
    rgmii_port_6_txc       : out   std_ulogic;
    rgmii_port_6_tx_ctl    : out   std_ulogic;
    rgmii_port_6_td        : out   std_logic_vector(3 downto 0);
    rgmii_port_7_rxc       : in    std_ulogic;
    rgmii_port_7_rx_ctl    : in    std_ulogic;
    rgmii_port_7_rd        : in    std_logic_vector(3 downto 0);
    rgmii_port_7_txc       : out   std_ulogic;
    rgmii_port_7_tx_ctl    : out   std_ulogic;
    rgmii_port_7_td        : out   std_logic_vector(3 downto 0);
    --
    mdio_io_port_4_mdio_io : inout std_logic;
    mdio_io_port_4_mdc     : out   std_ulogic;
    mdio_io_port_5_mdio_io : inout std_logic;
    mdio_io_port_5_mdc     : out   std_ulogic;
    mdio_io_port_6_mdio_io : inout std_logic;
    mdio_io_port_6_mdc     : out   std_ulogic;
    mdio_io_port_7_mdio_io : inout std_logic;
    mdio_io_port_7_mdc     : out   std_ulogic;
    --
    -- End of FMC Ports
    can_txd                : out   std_logic_vector(0 to CFG_CAN_NUM-1);
    can_rxd                : in    std_logic_vector(0 to CFG_CAN_NUM-1);
    spi_data_out           : in    std_logic;
    spi_data_in            : out   std_ulogic;
    spi_data_cs_b          : out   std_ulogic;
    spi_clk                : out   std_ulogic
   );
end;


architecture rtl of noelvmp is

component sgmii_vc707
  generic(
    pindex          : integer := 0;
    paddr           : integer := 0;
    pmask           : integer := 16#fff#;
    abits           : integer := 8;
    autonegotiation : integer := 1;
    pirq            : integer := 0;
    debugmem        : integer := 0;
    tech            : integer := 0
  );
  port(
    sgmiii    :  in  eth_sgmii_in_type; 
    sgmiio    :  out eth_sgmii_out_type;
    gmiii     : out   eth_in_type;
    gmiio     : in    eth_out_type;
    reset     : in    std_logic;                     -- Asynchronous reset for entire core.
    clkout0o  : out   std_logic;
    clkout1o  : out   std_logic;
    clkout2o  : out   std_logic;    
    apb_clk   : in    std_logic;
    apb_rstn  : in    std_logic;
    apbi      : in    apb_slv_in_type;
    apbo      : out   apb_slv_out_type
  );
end component;

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

component IBUFDS
  port (
     O : out std_ulogic;
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

constant CFG_FMC_NB  : integer := 8; -- Select 4 or 8 
constant CFG_FMC     : integer := (CFG_GRETH_FMC * CFG_GRETH * CFG_FMC_NB);
constant CFG_FMC_DBG : integer := 0;

constant ncpu     : integer := 1;
constant nextslv  : integer := 3
-- pragma translate_off
                               + 1
-- pragma translate_on
                               ;
constant ndbgmst  : integer := 3
                               ;

--constant maxahbm : integer := CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+CFG_GRETH+CFG_GRUSBHC+CFG_GRUSBDC+CFG_GRUSB_DCL;
constant maxahbm : integer := 16;
--constant maxahbs : integer := 1+CFG_DSU+CFG_MCTRL_LEON2+CFG_AHBROMEN+CFG_AHBRAMEN+2+CFG_GRUSBDC;
constant maxahbs : integer := 16;
constant maxapbs : integer := CFG_IRQ3_ENABLE+CFG_GPT_ENABLE+CFG_GRGPIO_ENABLE+CFG_AHBSTAT+CFG_AHBSTAT+CFG_GRUSBHC+CFG_GRUSBDC+CFG_PRC;

signal vcc, gnd   : std_logic_vector(31 downto 0);

signal apbi  : apb_slv_in_vector;
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
  
signal aximi : axi_somi_type;
signal aximo : axi4_mosi_type;


signal ui_clk : std_ulogic;
signal clkm : std_ulogic := '0';
signal rstn, urstn, rstraw, sdclkl : std_ulogic;
signal clk_200 : std_ulogic;
signal clk40, clk65 : std_ulogic;
signal locked_final : std_ulogic;

signal cgi, cgi2, cgiu   : clkgen_in_type;
signal cgo, cgo2, cgou   : clkgen_out_type;
signal u1i, u2i, dui : uart_in_type;
signal u1o, u2o, duo : uart_out_type;

type eth_in_type_array  is array (CFG_FMC_NB downto 0) of eth_in_type;
type eth_out_type_array is array (CFG_FMC_NB downto 0) of eth_out_type;

signal rgmiii,rgmiii_buf : eth_in_type_array;
signal rgmiio,rgmiio_buf : eth_out_type_array;

signal gmiii : eth_in_type_array;
signal gmiio : eth_out_type_array;

signal sgmiii :  eth_sgmii_in_type; 
signal sgmiio :  eth_sgmii_out_type;

signal sgmiirst : std_logic;

signal ethernet_phy_int : std_logic;

signal rxd1 : std_logic;
signal txd1 : std_logic;

signal ethi : eth_in_type;
signal etho : eth_out_type;
signal egtx_clk :std_ulogic;
signal negtx_clk :std_ulogic;

signal gpti : gptimer_in_type;
signal gpto : gptimer_out_type;

signal gpioi : gpio_in_type;
signal gpioo : gpio_out_type;

signal clklock, elock, uclk ,ulock : std_ulogic;

signal lock, calib_done, clkml, lclk, rst, ndsuact : std_ulogic;
signal tck, tckn, tms, tdi, tdo : std_ulogic;

signal lcd_datal : std_logic_vector(11 downto 0);
signal lcd_hsyncl, lcd_vsyncl, lcd_del, lcd_reset_bl : std_ulogic;

signal i2ci, dvi_i2ci : i2c_in_type;
signal i2co, dvi_i2co : i2c_out_type;

signal spii : spi_in_type;
signal spio : spi_out_type;
signal slvsel : std_logic_vector(CFG_SPICTRL_SLVS-1 downto 0);

constant BOARD_FREQ : integer := 200000;   -- input frequency in KHz
constant CPU_FREQ : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;  -- cpu frequency in KHz

signal stati : ahbstat_in_type;

signal dsurx_int   : std_logic; 
signal dsutx_int   : std_logic; 
signal dsuctsn_int : std_logic;
signal dsurtsn_int : std_logic;

signal dsu_sel : std_logic;

signal usbi : grusb_in_vector(0 downto 0);
signal usbo : grusb_out_vector(0 downto 0);

signal can_lrx, can_ltx   : std_logic_vector(0 to 7);

signal clkref           : std_logic;

signal migrstn : std_logic;

signal clk125_pad, clk125_lock : std_logic;

signal idelay_reset_cnt : std_logic_vector(3 downto 0);
signal idelayctrl_reset : std_logic;
signal io_ref           : std_logic;
signal rstgtxn          : std_logic;

signal e1_debug_rx,e1_debug_tx,e1_debug_gtx  : std_logic_vector(63 downto 0);
type fmc_debug_type is array (0 to CFG_FMC_NB) of std_logic_vector(63 downto 0);
signal fmc_debug_rx,fmc_debug_tx,fmc_debug_gtx : fmc_debug_type;
signal fmc_debug_rx_con,fmc_debug_tx_con,fmc_debug_gtx_con : fmc_debug_type;

type tx_rgmii_debug_type is array (0 to CFG_FMC_NB) of std_logic_vector(31 downto 0);
signal debug_rgmii_phy_rx,debug_rgmii_phy_tx : tx_rgmii_debug_type;
signal debug_rgmii_phy_rx_con,debug_rgmii_phy_tx_con : tx_rgmii_debug_type;

type cfg_eth_ipl_type is array (0 to CFG_FMC_NB) of integer;
-- Table is based upon VC707 standard Ethernet port has EDCL address 16#0033#
 constant CFG_ETH_IPL_FMC : cfg_eth_ipl_type := (16#0034#, 16#0035#, 16#0036#, 16#0037#, 16#0038#, 16#0039#, 16#003A#, 16#003B#, 16#003C#);

signal clkout0o  :    std_logic;
signal clkout1o  :    std_logic;
signal clkout2o  :    std_logic;    

signal  int_rst : std_logic; 
signal  PLLE2_ADV0_CLKFB : std_logic; 
   
signal  clk125_nobuf, clk125 : std_logic; 
signal  clk25_nobuf , clk25  : std_logic;

attribute keep : boolean;
attribute syn_keep : string;
attribute keep of clkm : signal is true;
attribute keep of uclk : signal is true;

signal ldsuen     : std_logic;
signal ldsubreak  : std_logic;
signal lcpu0errn  : std_logic;
signal dbgmi      : ahb_mst_in_vector_type(ndbgmst-1 downto 0);
signal dbgmo      : ahb_mst_out_vector_type(ndbgmst-1 downto 0);

-- NOELV
signal ext_irqi       : std_logic_vector(15 downto 0);
signal cpurstn        : std_ulogic;

-- Memory
signal mem_aximi      : axi_somi_type;
signal mem_aximo      : axi_mosi_type;

constant mig_hindex : integer := 2
-- pragma translate_off
                                 + 1
-- pragma translate_on
                                 ;

constant mig_hconfig : ahb_config_type := (
  0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
  4 => ahb_membar(16#000#, '1', '1', 16#C00#),
  others => zero32);

begin

----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------

  vcc <= (others => '1'); gnd <= (others => '0');
  cgi.pllctrl <= "00"; cgi.pllrst <= rstraw;

   clk_gen : if (CFG_MIG_7SERIES = 0) generate
     clk_pad_ds : clkpad_ds generic map (tech => padtech, level => sstl, voltage => x15v) port map (clk200p, clk200n, lclk);
     clkgen0 : clkgen        -- clock generator
       generic map (clktech, CFG_CLKMUL, CFG_CLKDIV, CFG_MCTRL_SDEN,
      CFG_CLK_NOFB, 0, 0, 0, BOARD_FREQ)
       port map (lclk, lclk, clkm, open, open, open, open, cgi, cgo, open, open, open);
   end generate;

  reset_pad : inpad generic map (tech => padtech, level => cmos, voltage => x18v) port map (reset, rst);

  rst0 : rstgen         -- reset generator
  generic map (acthigh => 1, syncin => 0)
  port map (rst, clkm, lock, rstn, rstraw);
  lock <= (calib_done and clk125_lock) when CFG_MIG_7SERIES = 1 else cgo.clklock;

  rst1 : rstgen         -- reset generator
  generic map (acthigh => 1)
  port map (rst, clkm, lock, migrstn, open);

  rst2 : rstgen         -- reset generator (USB)
  generic map (acthigh => 1)
  port map (rst, uclk, vcc(0), urstn, open);
  
----------------------------------------------------------------------
---  NOEL-V SUBSYSTEM -----------------------------------------
----------------------------------------------------------------------

    noelv0 : noelvsys 
    generic map (
      fabtech   => fabtech,
      memtech   => memtech,
      ncpu      => ncpu,
      nextmst   => 1,--2,
      nextslv   => nextslv,
      nextapb   => 6,
      ndbgmst   => ndbgmst,
      cached    => 0,
      wbmask    => 16#00FF#,
      busw      => 128,
      cmemconf  => 0,
      fpuconf   => 0,
      disas     => 1,
      ahbtrace  => 0,
      cfg       => 1,
      devid     => 0,
      nodbus    => CFG_NODBGBUS
      )
    port map(
      clk       => clkm, -- : in  std_ulogic;
      rstn      => rstn, -- : in  std_ulogic;
      -- AHB bus interface for other masters (DMA units)
      ahbmi     => ahbmi, -- : out ahb_mst_in_type;
      ahbmo     => ahbmo(ncpu downto ncpu), -- : in  ahb_mst_out_vector_type(ncpu+nextmst-1 downto ncpu);
      -- AHB bus interface for slaves (memory controllers, etc)
      ahbsi     => ahbsi, -- : out ahb_slv_in_type;
      ahbso     => ahbso(nextslv-1 downto 0), -- : in  ahb_slv_out_vector_type(nextslv-1 downto 0);
      -- AHB master interface for debug links
      dbgmi     => dbgmi, -- : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
      dbgmo     => dbgmo, -- : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
      -- APB interface for external APB slaves
      apbi      => apbi, -- : out apb_slv_in_type;
      apbo      => apbo, -- : in  apb_slv_out_vector;
      -- Bootstrap signals
      dsuen     => ldsuen, -- : in  std_ulogic;
      dsubreak  => ldsubreak, -- : in  std_ulogic;
      cpu0errn  => lcpu0errn, -- : out std_ulogic;
      -- UART connection
      uarti     => u1i, -- : in  uart_in_type;
      uarto     => u1o  -- : out uart_out_type
      );

  ldsuen <= '1';

  dsui_break_pad   : inpad  generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (button(3), ldsubreak);
  
  led1_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(1), gnd(1));
--  sysi.dsu_enable <= '1';
  
  dsuact_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(0), gnd(1));
--  ndsuact <= not syso.dsu_active;

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

  sw4_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (switch(4), '0', '1', dsu_sel);

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
               open, open, open, open, open, open, open, gnd(0));
  end generate;

  nojtag : if CFG_AHB_JTAG = 0 generate
    dbgmo(1) <= ahbm_none;
  end generate;


  -----------------------------------------------------------------------------
  -- L2 cache, optionally covering DDR3 SDRAM memory controller
  -----------------------------------------------------------------------------
  aa:if CFG_L2_EN = 1 generate
  l2c0 : l2c_axi_be
    generic map (
      hslvidx   => 0,
      axiid     => 0,
      cen       => CFG_L2_PEN,
      haddr     => 16#000#,
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

  nol2c : if CFG_L2_EN = 0 generate
    ahbso(0) <= mig_ahbso;
    mig_ahbsi <= ahbsi;
    ahbso(mig_hindex) <= ahbs_none;
  end generate;
  
   ----------------------------------------------------------------------
  ---  DDR3 memory controller ------------------------------------------
  ----------------------------------------------------------------------
  mig_gen : if (CFG_MIG_7SERIES = 1) generate
    gen_mig : if (USE_MIG_INTERFACE_MODEL /= true) generate
      cc:if CFG_L2_EN = 1 generate
        ddrc:axi_mig_7series generic map (
          hindex => 0, haddr => 16#000#, hmask => 16#C00#,
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
            aximi           => mem_aximi,
            aximo           => mem_aximo,
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

        ---  Fake MIG PNP -----------------------------------------------------
        -- ahbso(1) <= ahbs_none;
        ahbso(mig_hindex).hindex  <= mig_hindex;
        ahbso(mig_hindex).hconfig <= mig_hconfig;
        ahbso(mig_hindex).hready  <= '1';
        ahbso(mig_hindex).hresp   <= "00";
        ahbso(mig_hindex).hirq    <= (others => '0');
        ahbso(mig_hindex).hrdata  <= (others => '0');  
      end generate cc;

      dd:if CFG_L2_EN=0 generate
        ddrc: ahb2axi_mig_7series generic map (
          hindex => 0, haddr => 16#000#, hmask => 16#C00#,
          pindex => 5, paddr => 16#800#, pmask => 16#FFF#)
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
            apbi            => apbi(5),
            apbo            => apbo(5),
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
      end generate dd;

      clkgenmigref0 : clkgen
        generic map (clktech, 16, 8, 0,CFG_CLK_NOFB, 0, 0, 0, 100000)
        port map (clkm, clkm, clkref, open, open, open, open, cgi, cgo, open, open, open);

    end generate gen_mig;
    
    
    gen_mig_model : if (USE_MIG_INTERFACE_MODEL = true) generate
      -- pragma translate_off
      mig_ahbram : ahbram_sim
        generic map (
          hindex   => 4*(1-CFG_L2_EN),
          haddr    => 16#000#,
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
      generic map (hindex => 4*(1-CFG_L2_EN), haddr => 16#000#, tech => CFG_MEMTECH, kbytes => 128)
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
  
  led2_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
     port map (led(2), calib_done);
  led3_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
     port map (led(3), lock);

-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

    eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC
      e1 : grethm 
       generic map(
        hindex => 2,
        pindex => 4, paddr => 16#840#, pmask => 16#FFF#, pirq => 5, memtech => memtech,
        mdcscaler => CPU_FREQ/1000/2, rmii => 0, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
        nsync => 2, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF, phyrstadr => 7,
        macaddrh => CFG_ETH_ENM, macaddrl => CFG_ETH_ENL, enable_mdint => 1,
        ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_ETH_IPL,
        giga => CFG_GRETH1G, ramdebug => 0, gmiimode => 1)
       port map( rst => rstn, clk => clkm, ahbmi => dbgmi(2),
        ahbmo => dbgmo(2), 
        apbi => apbi(4), apbo => apbo(4), ethi => gmiii(0), etho => gmiio(0),
        debug_rx => e1_debug_rx, debug_tx => e1_debug_tx, debug_gtx => e1_debug_gtx); 

      ---- Debug of RX and TX
      --loganrx0 : logan
      --  generic map (dbits=>64,depth=>2048,trigl=>1,usereg=>1,usequal=>0, pindex => 13, paddr => 16#D00#, memtech => memtech)
      --  port map (rstn, clkm, e1_debug_rx(63), apbi1, apbo1(13), e1_debug_rx(63 downto 0));  
      --
      --logantx0 : logan
      --  generic map (dbits=>64,depth=>2048,trigl=>1,usereg=>1,usequal=>0, pindex => 14, paddr => 16#E00#, memtech => memtech)
      --  port map (rstn, clkm, e1_debug_tx(63), apbi1, apbo1(14), e1_debug_tx(63 downto 0)); 
      --
      --logangtx0 : logan
      --  generic map (dbits=>64,depth=>2048,trigl=>1,usereg=>1,usequal=>0, pindex => 15, paddr => 16#F00#, memtech => memtech)
      --  port map (rstn, clkm, e1_debug_gtx(63), apbi1, apbo1(15), e1_debug_gtx(63 downto 0)); 
      
       sgmiirst <= not rstraw;

       sgmii0 : sgmii_vc707
         generic map(
           pindex          => 7,
           paddr           => 16#850#,
           pmask           => 16#ff0#,
           abits           => 8,
           autonegotiation => autonegotiation,
           pirq            => 6,
           debugmem        => 0,
           tech            => fabtech
         )
         port map(
           sgmiii   => sgmiii,
           sgmiio   => sgmiio,
           gmiii    => gmiii(0),
           gmiio    => gmiio(0),
           reset    => sgmiirst,
           clkout0o => clkout0o,
           clkout1o => clkout1o,
           clkout2o => clkout2o,  
           apb_clk  => clkm,
           apb_rstn => rstn,
           apbi     => apbi(7),
           apbo     => apbo(7)
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

    noeth0 : if CFG_GRETH = 0 generate
    -- TODO: 
    end generate noeth0;

    eth1 : if CFG_GRETH_FMC = 1 generate -- Extended FMC Support
    
      -- Reset Out
      reset_port_0_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_0, rstn);       
      reset_port_1_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_1, rstn);       
      reset_port_2_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_2, rstn);       
      reset_port_3_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_3, rstn);       

      -- Reset Out FMC 4 to 7
      reset_port_4_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_4, rstn);       
      reset_port_5_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_5, rstn);       
      reset_port_6_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_6, rstn);       
      reset_port_7_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_7, rstn);       
      
      -- Clock input and select 
      ref_clk_oe_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (ref_clk_oe, '0');  
      -- Select 125MHz ref clock
      ref_clk_fsel_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (ref_clk_fsel, '0');
      
      -- Input ref clock buffer
      -- Note: Better to use internal 125MHz clock for all variants....
      -- KC705 (2.5V variant)
      --clk125_ref_pad : IBUFGDS generic map (DIFF_TERM => true, IOSTANDARD =>"LVDS")
	    --port map (O => clk125_pad, I => ref_clk_clk_p, IB => ref_clk_clk_n); 
      -- VC707 (1.8V variant)
      clk125_pad <= clkout2o;

      -- Generate 125MHz, 50MHz and 25Mhz Clock transmit clock
     int_rst <= not rstraw;   
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
        CLKOUT0           => clk125_nobuf,
        CLKOUT1           => OPEN,
        CLKOUT2           => OPEN,
        CLKOUT3           => clk25_nobuf,
        CLKOUT4           => OPEN,
        CLKOUT5           => io_ref,
        -- DRP Ports: 16-bit (each) output: Dynamic reconfigration ports
        DO                => OPEN,
        DRDY              => OPEN,
        -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
        CLKFBOUT          => PLLE2_ADV0_CLKFB,
        -- Status Ports: 1-bit (each) output: PLL status ports
        LOCKED            => clk125_lock,
        -- Clock Inputs: 1-bit (each) input: Clock inputs
        CLKIN1            => clk125_pad,
        CLKIN2            => '0',
        -- Con trol Ports: 1-bit (each) input: PLL control ports
        CLKINSEL          => '1',
        PWRDWN            => '0',
        RST               => int_rst, 
        -- DRP Ports: 7-bit (each) input: Dynamic reconfigration ports
        DADDR             => "0000000", 
        DCLK              => '0',
        DEN               => '0',
        DI                => "0000000000000000", 
        DWE               => '0',
        -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
        CLKFBIN           => PLLE2_ADV0_CLKFB
       );     

      bufgclk125  : BUFG port map (I => clk125_nobuf, O => clk125);    
      bufgclk25   : BUFG port map (I => clk25_nobuf , O => clk25 );    
      
      -- Add APB CTRL for GRETH Cores
      apb1 : apbctrl            -- AHB/APB bridge
       generic map (hindex => 5, haddr => 16#A00#, hmask => 16#F00#, nslaves => 16)
       port map (rstn, clkm, ahbsi, ahbso(5), apbi1, apbo1 );
    
      eth1_fmc : for i in 0 to CFG_FMC_NB-1 generate

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
         apbi => apbi1, apbo => apbo1(i), ethi => gmiii(i+1), etho => gmiio(i+1),
         debug_rx => fmc_debug_rx(i), debug_tx => fmc_debug_tx(i), debug_gtx => fmc_debug_gtx(i)
         );       

       rgmii0 : rgmii_series7 
        generic map (
         pindex => i+CFG_FMC, paddr => 16#010#*i+16#010#*(CFG_FMC), pmask => 16#ff0#, tech => fabtech,
         gmii => CFG_GRETH1G, abits => 8, pirq => i+CFG_FMC, base10_x => 0)
        port map (rstn, gmiii(i+1), gmiio(i+1), rgmiii(i), rgmiio(i), clkm, rstn, apbi1, apbo1(i+CFG_FMC),
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
      eth1_fmc_clk : for i in 0 to CFG_FMC_NB-1 generate
        rgmiii(i).gtx_clk    <= clk125;   
        rgmiii(i).tx_clk_100 <= '0';
        rgmiii(i).tx_clk_90  <= '0';
        rgmiii(i).tx_clk_50  <= '0';
        rgmiii(i).tx_clk_25  <= clk25;   
        rgmiii(i).rmii_clk   <= '0';
      end generate eth1_fmc_clk;

      -- RGMII Ports   
      -- Note: Port levels set by XDC file
      rgmiii(0).rx_clk              <= rgmii_port_0_rxc;
      rgmiii_buf(0).rx_dv           <= rgmii_port_0_rx_ctl;
      rgmiii_buf(0).rxd(3 downto 0) <= rgmii_port_0_rd;
      rgmii_port_0_txc              <= rgmiio_buf(0).tx_clk;
      rgmii_port_0_tx_ctl           <= rgmiio(0).tx_en;
      rgmii_port_0_td               <= rgmiio(0).txd(3 downto 0);
      
      rgmiii(1).rx_clk              <= rgmii_port_1_rxc;
      rgmiii_buf(1).rx_dv           <= rgmii_port_1_rx_ctl;
      rgmiii_buf(1).rxd(3 downto 0) <= rgmii_port_1_rd;
      rgmii_port_1_txc              <= rgmiio_buf(1).tx_clk;
      rgmii_port_1_tx_ctl           <= rgmiio(1).tx_en;
      rgmii_port_1_td               <= rgmiio(1).txd(3 downto 0);

      rgmiii(2).rx_clk              <= rgmii_port_2_rxc;
      rgmiii_buf(2).rx_dv           <= rgmii_port_2_rx_ctl;
      rgmiii_buf(2).rxd(3 downto 0) <= rgmii_port_2_rd;
      rgmii_port_2_txc              <= rgmiio_buf(2).tx_clk;
      rgmii_port_2_tx_ctl           <= rgmiio(2).tx_en;
      rgmii_port_2_td               <= rgmiio(2).txd(3 downto 0);

      rgmiii(3).rx_clk              <= rgmii_port_3_rxc;
      rgmiii_buf(3).rx_dv           <= rgmii_port_3_rx_ctl;
      rgmiii_buf(3).rxd(3 downto 0) <= rgmii_port_3_rd;
      rgmii_port_3_txc              <= rgmiio_buf(3).tx_clk;
      rgmii_port_3_tx_ctl           <= rgmiio(3).tx_en;
      rgmii_port_3_td               <= rgmiio(3).txd(3 downto 0);

      rgmiii(4).rx_clk              <= rgmii_port_4_rxc;
      rgmiii_buf(4).rx_dv           <= rgmii_port_4_rx_ctl;
      rgmiii_buf(4).rxd(3 downto 0) <= rgmii_port_4_rd;
      rgmii_port_4_txc              <= rgmiio_buf(4).tx_clk;
      rgmii_port_4_tx_ctl           <= rgmiio(4).tx_en;
      rgmii_port_4_td               <= rgmiio(4).txd(3 downto 0);

      rgmiii(5).rx_clk              <= rgmii_port_5_rxc;
      rgmiii_buf(5).rx_dv           <= rgmii_port_5_rx_ctl;
      rgmiii_buf(5).rxd(3 downto 0) <= rgmii_port_5_rd;
      rgmii_port_5_txc              <= rgmiio_buf(5).tx_clk;
      rgmii_port_5_tx_ctl           <= rgmiio(5).tx_en;
      rgmii_port_5_td               <= rgmiio(5).txd(3 downto 0);

      rgmiii(6).rx_clk              <= rgmii_port_6_rxc;
      rgmiii_buf(6).rx_dv           <= rgmii_port_6_rx_ctl;
      rgmiii_buf(6).rxd(3 downto 0) <= rgmii_port_6_rd;
      rgmii_port_6_txc              <= rgmiio_buf(6).tx_clk;
      rgmii_port_6_tx_ctl           <= rgmiio(6).tx_en;
      rgmii_port_6_td               <= rgmiio(6).txd(3 downto 0);

      rgmiii(7).rx_clk              <= rgmii_port_7_rxc;
      rgmiii_buf(7).rx_dv           <= rgmii_port_7_rx_ctl;
      rgmiii_buf(7).rxd(3 downto 0) <= rgmii_port_7_rd;
      rgmii_port_7_txc              <= rgmiio_buf(7).tx_clk;
      rgmii_port_7_tx_ctl           <= rgmiio(7).tx_en;
      rgmii_port_7_td               <= rgmiio(7).txd(3 downto 0);

      -----------------------------------------------------------------------------
      -- An IDELAYCTRL primitive needs to be instantiated for the Fixed Tap Delay
      -- mode of the IDELAY.
      -- All IDELAYs in Fixed Tap Delay mode and the IDELAYCTRL primitives have
      -- to be LOC'ed in the UCF file.
      -----------------------------------------------------------------------------
      
      -- Generate a synchron delayed reset for Xilinx IO delay
      rstdly : rstgen
       generic map (acthigh => 1)
       port map (rst, io_ref, lock, rstgtxn, OPEN);

      process (io_ref,rstgtxn)
       begin
        if (rstgtxn = '0') then
          idelay_reset_cnt <= (others => '0');
          idelayctrl_reset <= '1';
        elsif rising_edge(io_ref) then
          if (idelay_reset_cnt > "1110") then
             idelay_reset_cnt <= (others => '1');
             idelayctrl_reset <= '0';
          else
             idelay_reset_cnt <= idelay_reset_cnt + 1;
             idelayctrl_reset <= '1';
          end if;
        end if;
      end process;      
      
      dlyctrl0 : IDELAYCTRL port map (
       RDY    => OPEN,
       REFCLK => io_ref,
       RST    => idelayctrl_reset
      );

      -- Insert delay blocks for inputs
      eth1_rgmii_d : for i in 0 to CFG_FMC_NB-1 generate

      rgmiio_buf(i).tx_clk <= rgmiio(i).tx_clk;

       delay_rgmii_rx_ctl0 : IODELAYE1 generic map(
         DELAY_SRC   => "I",
         IDELAY_TYPE => "FIXED",
         IDELAY_VALUE => 20
        )
        port map(
         IDATAIN     => rgmiii_buf(i).rx_dv,
         ODATAIN     => '0',
         DATAOUT     => rgmiii(i).rx_dv,
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
         IDATAIN     => rgmiii_buf(i).rxd(j),
         ODATAIN     => '0',
         DATAOUT     => rgmiii(i).rxd(j),
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
        rgmiii(i).rxd(j+4) <= '0';
       end generate rgmii_rxd;

      end generate eth1_rgmii_d;
       
      -- MDIO IO
      mdio_io_port_0_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
        port map (mdio_io_port_0_mdio_io, rgmiio(0).mdio_o, rgmiio(0).mdio_oe, rgmiii(0).mdio_i);
      mdio_io_port_0_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_0_mdc, rgmiio(0).mdc);

      mdio_io_port_1_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
        port map (mdio_io_port_1_mdio_io, rgmiio(1).mdio_o, rgmiio(1).mdio_oe, rgmiii(1).mdio_i);
      mdio_io_port_1_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_1_mdc, rgmiio(1).mdc);

      mdio_io_port_2_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
        port map (mdio_io_port_2_mdio_io, rgmiio(2).mdio_o, rgmiio(2).mdio_oe, rgmiii(2).mdio_i);
      mdio_io_port_2_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_2_mdc, rgmiio(2).mdc);

      mdio_io_port_3_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
        port map (mdio_io_port_3_mdio_io, rgmiio(3).mdio_o, rgmiio(3).mdio_oe, rgmiii(3).mdio_i);
      mdio_io_port_3_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_3_mdc, rgmiio(3).mdc);       
    
      mdio_io_port_4_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_4_mdio_io, rgmiio(4).mdio_o, rgmiio(4).mdio_oe, rgmiii(4).mdio_i);
      mdio_io_port_4_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_4_mdc, rgmiio(4).mdc);

      mdio_io_port_5_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_5_mdio_io, rgmiio(5).mdio_o, rgmiio(5).mdio_oe, rgmiii(5).mdio_i);
      mdio_io_port_5_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_5_mdc, rgmiio(5).mdc);
       
      mdio_io_port_6_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_6_mdio_io, rgmiio(6).mdio_o, rgmiio(6).mdio_oe, rgmiii(6).mdio_i);
      mdio_io_port_6_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_6_mdc, rgmiio(6).mdc);
    
      mdio_io_port_7_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_7_mdio_io, rgmiio(7).mdio_o, rgmiio(7).mdio_oe, rgmiii(7).mdio_i);
      mdio_io_port_7_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_7_mdc, rgmiio(7).mdc);
   
    end generate eth1;

    noeth1 : if CFG_GRETH_FMC = 0 generate -- Extended FMC Support

      clk125_lock <= '1';

      -- Reset Out
      reset_port_0_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_0, '0');       
      reset_port_1_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_1, '0');       
      reset_port_2_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_2, '0');       
      reset_port_3_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_3, '0');   

      reset_port_4_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_4, '0');       
      reset_port_5_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_5, '0');       
      reset_port_6_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_6, '0');       
      reset_port_7_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (reset_port_7, '0');   

      -- Clock input and select 
      ref_clk_oe_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (ref_clk_oe, '0');  
      -- Select 125MHz ref clock
      ref_clk_fsel_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
      port map (ref_clk_fsel, '0');

      -- MDIO IO
      mdio_io_port_0_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
        port map (mdio_io_port_0_mdio_io, '0','0', rgmiii(0).mdio_i);
      mdio_io_port_0_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_0_mdc, '0');
  
      mdio_io_port_1_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
        port map (mdio_io_port_1_mdio_io, '0', '0', rgmiii(1).mdio_i);
      mdio_io_port_1_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_1_mdc, '0');
  
      mdio_io_port_2_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
        port map (mdio_io_port_2_mdio_io, '0', '0', rgmiii(2).mdio_i);
      mdio_io_port_2_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_2_mdc, '0');
  
      mdio_io_port_3_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
        port map (mdio_io_port_3_mdio_io, '0', '0', rgmiii(3).mdio_i);
      mdio_io_port_3_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_3_mdc, '0');  

      mdio_io_port_4_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_4_mdio_io, '0','0', rgmiii(4).mdio_i);
      mdio_io_port_4_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_4_mdc, '0');

      mdio_io_port_5_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_5_mdio_io, '0','0', rgmiii(5).mdio_i);
      mdio_io_port_5_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_5_mdc, '0');

      mdio_io_port_6_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_6_mdio_io, '0','0', rgmiii(6).mdio_i);
      mdio_io_port_6_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_6_mdc, '0');

      mdio_io_port_7_mdio_io_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_7_mdio_io, '0','0', rgmiii(7).mdio_i);
      mdio_io_port_7_mdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v) 
       port map (mdio_io_port_7_mdc, '0');

      -- RGMII Ports   
      rgmiii(0).rx_clk              <= '0';
      rgmiii_buf(0).rx_dv           <= '0';
      rgmiii_buf(0).rxd(3 downto 0) <= (others => '0');
      rgmii_port_0_txc              <= '0';
      rgmii_port_0_tx_ctl           <= '0';
      rgmii_port_0_td               <= (others => '0');
      
      rgmiii(1).rx_clk              <= '0';
      rgmiii_buf(1).rx_dv           <= '0';
      rgmiii_buf(1).rxd(3 downto 0) <= (others => '0');
      rgmii_port_1_txc              <= '0';
      rgmii_port_1_tx_ctl           <= '0';
      rgmii_port_1_td               <= (others => '0');

      rgmiii(2).rx_clk              <= '0';
      rgmiii_buf(2).rx_dv           <= '0';
      rgmiii_buf(2).rxd(3 downto 0) <= (others => '0');
      rgmii_port_2_txc              <= '0';
      rgmii_port_2_tx_ctl           <= '0';
      rgmii_port_2_td               <= (others => '0');

      rgmiii(3).rx_clk              <= '0';
      rgmiii_buf(3).rx_dv           <= '0';
      rgmiii_buf(3).rxd(3 downto 0) <= (others => '0');
      rgmii_port_3_txc              <= '0';
      rgmii_port_3_tx_ctl           <= '0';
      rgmii_port_3_td               <= (others => '0');
  
      rgmiii(4).rx_clk              <= '0';
      rgmiii_buf(4).rx_dv           <= '0';
      rgmiii_buf(0).rxd(3 downto 0) <= (others => '0');
      rgmii_port_4_txc              <= '0';
      rgmii_port_4_tx_ctl           <= '0';
      rgmii_port_4_td               <= (others => '0');
        
      rgmiii(5).rx_clk              <= '0';
      rgmiii_buf(5).rx_dv           <= '0';
      rgmiii_buf(5).rxd(3 downto 0) <= (others => '0');
      rgmii_port_5_txc              <= '0';
      rgmii_port_5_tx_ctl           <= '0';
      rgmii_port_5_td               <= (others => '0');
        
      rgmiii(6).rx_clk              <= '0';
      rgmiii_buf(6).rx_dv           <= '0';
      rgmiii_buf(6).rxd(3 downto 0) <= (others => '0');
      rgmii_port_6_txc              <= '0';
      rgmii_port_6_tx_ctl           <= '0';
      rgmii_port_6_td               <= (others => '0');
        
      rgmiii(7).rx_clk              <= '0';
      rgmiii_buf(7).rx_dv           <= '0';
      rgmiii_buf(7).rxd(3 downto 0) <= (others => '0');
      rgmii_port_7_txc              <= '0';
      rgmii_port_7_tx_ctl           <= '0';
      rgmii_port_7_td               <= (others => '0');
    end generate noeth1;
    

  usb_resetn_pad : outpad generic map (tech => padtech, slew => 1)
    port map (usb_resetn, '0');
  usb_stp_pad : outpad generic map (tech => padtech, slew => 1)
    port map (usb_stp, '0');

----------------------------------------------------------------------
---  I2C Controller --------------------------------------------------
----------------------------------------------------------------------
  --i2cm: if CFG_I2C_ENABLE = 1 generate  -- I2C master
  i2c_scl_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (iic_scl, i2co.scl, i2co.scloen, i2ci.scl);

  i2c_sda_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (iic_sda, i2co.sda, i2co.sdaoen, i2ci.sda);
  --end generate i2cm;

  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate     -- GPIO unit
    grgpio0: grgpio
    generic map(pindex => 3, paddr => 16#830#, pmask => 16#FFF#,imask => CFG_GRGPIO_IMASK, nbits => 7)
    port map(rst => rstn, clk => clkm, apbi => apbi(3), apbo => apbo(3),
    gpioi => gpioi, gpioo => gpioo);
    
    pio_pads : for i in 0 to 3 generate
        pio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
            port map (switch(i), gpioo.dout(i), gpioo.oen(i), gpioi.din(i));
    end generate;
    
    pio_pads2 : for i in 4 to 5 generate
        pio_pad : inpad generic map (tech => padtech, level => cmos, voltage => x18v)
            port map (button(i-4), gpioi.din(i));
    end generate;
  end generate;

  miso_pad : inpad generic map (level => cmos, voltage => x18v,tech => padtech)
    port map (spi_data_out, spii.miso);
  mosi_pad : outpad generic map (level => cmos, voltage => x18v,tech => padtech)
    port map (spi_data_in, vcc(0));
  sck_pad  : outpad generic map (level => cmos, voltage => x18v,tech => padtech)
    port map (spi_clk, gnd(0));
  slvsel_pad : outpad generic map (level => cmos, voltage => x18v,tech => padtech)
    port map (spi_data_cs_b, vcc(0));
  
  --  AHB Status Register
  ahbs : if CFG_AHBSTAT = 1 generate  
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat
      generic map(pindex  => 2,
                  paddr   => 16#820#,
                  pmask   => 16#FFF#,
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


  -----------------------------------------------------------------------
  ---  AHB ROM ----------------------------------------------------------
  -----------------------------------------------------------------------

  brom : entity work.ahbrom
    generic map (
      hindex  => 1,
      haddr   => 16#C00#,
      hmask   => 16#E00#,
      pipe    => 0)
    port map (
      rst     => rstn,
      clk     => clkm,
      ahbsi   => ahbsi,
      ahbso   => ahbso(1));

	 
-----------------------------------------------------------------------
---  Test report module  ----------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  test0 : ahbrep
    generic map(
      hindex => 2,
      haddr => 16#800#)
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

