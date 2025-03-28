-----------------------------------------------------------------------------
--  LEON Demonstration design test bench
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
library gaisler;
use gaisler.libdcom.all;
use gaisler.sim.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;
use work.debug.all;

use work.config.all;

entity testbench is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    clktech   : integer := CFG_CLKTECH;
    disas     : integer := CFG_DISAS;      -- Enable disassembly to console
    dbguart   : integer := CFG_DUART;      -- Print UART on console
    pclow     : integer := CFG_PCLOW;
    USE_MIG_INTERFACE_MODEL : boolean := false

  );
end;

architecture behav of testbench is

-- DDR3 Simulation parameters
constant SIM_BYPASS_INIT_CAL : string := "FAST";
          -- # = "OFF" -  Complete memory init &
          --               calibration sequence
          -- # = "SKIP" - Not supported
          -- # = "FAST" - Complete memory init & use
          --              abbreviated calib sequence

constant SIMULATION          : string := "TRUE";
          -- Should be TRUE during design simulations and
          -- FALSE during implementations


constant promfile      : string := "prom.srec";  -- rom contents
constant ramfile       : string := "ram.srec";  -- ram contents

signal clk             : std_logic := '0';
signal rst             : std_logic := '0';

signal address         : std_logic_vector(25 downto 0);
signal data            : std_logic_vector(15 downto 0);
signal button          : std_logic_vector(3 downto 0) := "0000";
signal genio           : std_logic_vector(59 downto 0);
signal romsn           : std_logic;
signal oen             : std_ulogic;
signal writen          : std_ulogic;
signal adv             : std_logic;

signal GND             : std_ulogic := '0';
signal VCC             : std_ulogic := '1';
signal NC              : std_ulogic := 'Z';

signal txd1  , rxd1  , dsurx   : std_logic;
signal txd2  , rxd2  , dsutx   : std_logic;
signal ctsn1 , rtsn1 , dsuctsn : std_ulogic;
signal ctsn2 , rtsn2 , dsurtsn : std_ulogic;

signal phy_mii_data    : std_logic;
signal phy_tx_clk      : std_ulogic;
signal phy_rx_clk      : std_ulogic;
signal phy_rx_data     : std_logic_vector(7 downto 0);
signal phy_dv          : std_ulogic;
signal phy_rx_er       : std_ulogic;
signal phy_col         : std_ulogic;
signal phy_crs         : std_ulogic;
signal phy_tx_data     : std_logic_vector(7 downto 0);
signal phy_tx_en       : std_ulogic;
signal phy_tx_er       : std_ulogic;
signal phy_mii_clk     : std_ulogic;
signal phy_rst_n       : std_ulogic;
signal phy_gtx_clk     : std_ulogic;
signal phy_mii_int_n   : std_ulogic;

signal clk27           : std_ulogic := '0';
signal clk200p         : std_ulogic := '0';
signal clk200n         : std_ulogic := '1';
signal clk33           : std_ulogic := '0';
signal clkethp         : std_ulogic := '0';
signal clkethn         : std_ulogic := '1';
signal txp1             : std_logic;
signal txn             : std_logic;
signal rxp             : std_logic := '1';
signal rxn             : std_logic := '0';


signal iic_scl         : std_ulogic;
signal iic_sda         : std_ulogic;
signal ddc_scl         : std_ulogic;
signal ddc_sda         : std_ulogic;
signal dvi_iic_scl     : std_logic;
signal dvi_iic_sda     : std_logic;

signal tft_lcd_data    : std_logic_vector(11 downto 0);
signal tft_lcd_clk_p   : std_ulogic;
signal tft_lcd_clk_n   : std_ulogic;
signal tft_lcd_hsync   : std_ulogic;
signal tft_lcd_vsync   : std_ulogic;
signal tft_lcd_de      : std_ulogic;
signal tft_lcd_reset_b : std_ulogic;

-- DDR3 memory
signal ddr3_dq         : std_logic_vector(63 downto 0);
signal ddr3_dqs_p      : std_logic_vector(7 downto 0);
signal ddr3_dqs_n      : std_logic_vector(7 downto 0);
signal ddr3_addr       : std_logic_vector(13 downto 0);
signal ddr3_ba         : std_logic_vector(2 downto 0);
signal ddr3_ras_n      : std_logic;
signal ddr3_cas_n      : std_logic;
signal ddr3_we_n       : std_logic;
signal ddr3_reset_n    : std_logic;
signal ddr3_ck_p       : std_logic_vector(0 downto 0);
signal ddr3_ck_n       : std_logic_vector(0 downto 0);
signal ddr3_cke        : std_logic_vector(0 downto 0);
signal ddr3_cs_n       : std_logic_vector(0 downto 0);
signal ddr3_dm         : std_logic_vector(7 downto 0);
signal ddr3_odt        : std_logic_vector(0 downto 0);

-- SPI flash
signal spi_sel_n       : std_ulogic;
signal spi_clk         : std_ulogic;
signal spi_mosi        : std_ulogic;

signal dsurst          : std_ulogic;
signal errorn          : std_logic;

signal switch          : std_logic_vector(4 downto 0);    -- I/O port
signal led             : std_logic_vector(6 downto 0);    -- I/O port
constant lresp         : boolean := false;

signal tdqs_n : std_logic;

signal gmii_tx_clk     : std_logic;
signal gmii_rx_clk     : std_logic;
signal gmii_txd        : std_logic_vector(7 downto 0);
signal gmii_tx_en      : std_logic;
signal gmii_tx_er      : std_logic;
signal gmii_rxd        : std_logic_vector(7 downto 0);
signal gmii_rx_dv      : std_logic;
signal gmii_rx_er      : std_logic;

signal configuration_finished : boolean;
signal speed_is_10_100        : std_logic;
signal speed_is_100           : std_logic;

signal usb_clkout      : std_logic := '0';
signal usb_d           : std_logic_vector(7 downto 0);
signal usb_resetn      : std_ulogic;
signal usb_nxt         : std_ulogic;
signal usb_stp         : std_ulogic;
signal usb_dir         : std_ulogic;

-- GRUSB_DCL test signals
signal ddelay          : std_ulogic := '0';
signal dstart          : std_ulogic := '0';
signal drw             : std_ulogic;
signal daddr           : std_logic_vector(31 downto 0);
signal dlen            : std_logic_vector(14 downto 0);
signal ddi             : grusb_dcl_debug_data;
signal ddone           : std_ulogic;
signal ddo             : grusb_dcl_debug_data;

signal phy_mdio        : std_logic;
signal phy_mdc         : std_ulogic;

signal txp_eth, txn_eth : std_logic;
 
signal clk125 : std_logic;

signal    reset_port_0           :     std_logic;
signal    reset_port_1           :     std_logic;
signal    reset_port_2           :     std_logic;
signal    reset_port_3           :     std_logic;

signal    rgmii_port_0_rxc       :     std_logic;
signal    rgmii_port_0_rx_ctl    :     std_logic;
signal    rgmii_port_0_rd        :     std_logic_vector(3 downto 0);
signal    rgmii_port_0_txc       :     std_logic;
signal    rgmii_port_0_tx_ctl    :     std_logic;
signal    rgmii_port_0_td        :     std_logic_vector(3 downto 0);
signal    rgmii_port_1_rxc       :     std_logic;
signal    rgmii_port_1_rx_ctl    :     std_logic;
signal    rgmii_port_1_rd        :     std_logic_vector(3 downto 0);
signal    rgmii_port_1_txc       :     std_logic;
signal    rgmii_port_1_tx_ctl    :     std_logic;
signal    rgmii_port_1_td        :     std_logic_vector(3 downto 0);
signal    rgmii_port_2_rxc       :     std_logic;
signal    rgmii_port_2_rx_ctl    :     std_logic;
signal    rgmii_port_2_rd        :     std_logic_vector(3 downto 0);
signal    rgmii_port_2_txc       :     std_logic;
signal    rgmii_port_2_tx_ctl    :     std_logic;
signal    rgmii_port_2_td        :     std_logic_vector(3 downto 0);
signal    rgmii_port_3_rxc       :     std_logic;
signal    rgmii_port_3_rx_ctl    :     std_logic;
signal    rgmii_port_3_rd        :     std_logic_vector(3 downto 0);
signal    rgmii_port_3_txc       :     std_logic;
signal    rgmii_port_3_tx_ctl    :     std_logic;
signal    rgmii_port_3_td        :     std_logic_vector(3 downto 0);
    --
signal    mdio_io_port_0_mdio_io :     std_logic;
signal    mdio_io_port_0_mdc     :     std_logic;
signal    mdio_io_port_1_mdio_io :     std_logic;
signal    mdio_io_port_1_mdc     :     std_logic;
signal    mdio_io_port_2_mdio_io :     std_logic;
signal    mdio_io_port_2_mdc     :     std_logic;
signal    mdio_io_port_3_mdio_io :     std_logic;
signal    mdio_io_port_3_mdc     :     std_logic;

signal    rgmii_port_0_rd8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_0_td8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_1_rd8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_1_td8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_2_rd8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_2_td8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_3_rd8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_3_td8       :     std_logic_vector(7 downto 0);

signal    reset_port_4           :     std_logic;
signal    reset_port_5           :     std_logic;
signal    reset_port_6           :     std_logic;
signal    reset_port_7           :     std_logic;

signal    rgmii_port_4_rxc       :     std_logic;
signal    rgmii_port_4_rx_ctl    :     std_logic;
signal    rgmii_port_4_rd        :     std_logic_vector(3 downto 0);
signal    rgmii_port_4_txc       :     std_logic;
signal    rgmii_port_4_tx_ctl    :     std_logic;
signal    rgmii_port_4_td        :     std_logic_vector(3 downto 0);
signal    rgmii_port_5_rxc       :     std_logic;
signal    rgmii_port_5_rx_ctl    :     std_logic;
signal    rgmii_port_5_rd        :     std_logic_vector(3 downto 0);
signal    rgmii_port_5_txc       :     std_logic;
signal    rgmii_port_5_tx_ctl    :     std_logic;
signal    rgmii_port_5_td        :     std_logic_vector(3 downto 0);
signal    rgmii_port_6_rxc       :     std_logic;
signal    rgmii_port_6_rx_ctl    :     std_logic;
signal    rgmii_port_6_rd        :     std_logic_vector(3 downto 0);
signal    rgmii_port_6_txc       :     std_logic;
signal    rgmii_port_6_tx_ctl    :     std_logic;
signal    rgmii_port_6_td        :     std_logic_vector(3 downto 0);
signal    rgmii_port_7_rxc       :     std_logic;
signal    rgmii_port_7_rx_ctl    :     std_logic;
signal    rgmii_port_7_rd        :     std_logic_vector(3 downto 0);
signal    rgmii_port_7_txc       :     std_logic;
signal    rgmii_port_7_tx_ctl    :     std_logic;
signal    rgmii_port_7_td        :     std_logic_vector(3 downto 0);
    --
signal    mdio_io_port_4_mdio_io :     std_logic;
signal    mdio_io_port_4_mdc     :     std_logic;
signal    mdio_io_port_5_mdio_io :     std_logic;
signal    mdio_io_port_5_mdc     :     std_logic;
signal    mdio_io_port_6_mdio_io :     std_logic;
signal    mdio_io_port_6_mdc     :     std_logic;
signal    mdio_io_port_7_mdio_io :     std_logic;
signal    mdio_io_port_7_mdc     :     std_logic;

signal    rgmii_port_4_rd8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_4_td8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_5_rd8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_5_td8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_6_rd8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_6_td8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_7_rd8       :     std_logic_vector(7 downto 0);
signal    rgmii_port_7_td8       :     std_logic_vector(7 downto 0);

begin

  -- clock and reset
  clk200p <= not clk200p after 2.5 ns;
  clk200n <= not clk200n after 2.5 ns;
  clkethp <= not clkethp after 4 ns;
  clkethn <= not clkethn after 4 ns;

  rst <= not dsurst;
  rxd1 <= 'H'; ctsn1 <= '0';
  rxd2 <= 'H'; ctsn2 <= '0';
  button <= "0000";
  switch(3 downto 0) <= "0000";

  cpu : entity work.leon3mp
      generic map (
       fabtech              => fabtech,
       memtech              => memtech,
       padtech              => padtech,
       clktech              => clktech,
       disas                => disas,
       dbguart              => dbguart,
       pclow                => pclow,
       SIM_BYPASS_INIT_CAL  => SIM_BYPASS_INIT_CAL,
       SIMULATION           => SIMULATION,
       USE_MIG_INTERFACE_MODEL => USE_MIG_INTERFACE_MODEL,
       autonegotiation      => 0
   )
      port map (
       reset           => rst,
       clk200p         => clk200p,
       clk200n         => clk200n,
       address         => address,
       data            => data,
       oen             => oen,
       writen          => writen,
       romsn           => romsn,
       adv             => adv,
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
       dsurx           => dsurx,
       dsutx           => dsutx,
       dsuctsn         => dsuctsn,
       dsurtsn         => dsurtsn,
       button          => button,
       switch          => switch,
       led             => led,
       iic_scl         => iic_scl,
       iic_sda         => iic_sda,
       usb_refclk_opt  => '0',
       usb_clkout      => usb_clkout,
       usb_d           => usb_d,
       usb_nxt         => usb_nxt,
       usb_stp         => usb_stp,
       usb_dir         => usb_dir,
       usb_resetn      => usb_resetn,
       gtrefclk_p      => clkethp,
       gtrefclk_n      => clkethn,
       txp             => txp_eth,
       txn             => txn_eth,
       rxp             => txp_eth,
       rxn             => txn_eth,
       emdio           => phy_mdio,
       emdc            => phy_mdc,
       eint            => '0',
       erst            => OPEN,
       -- FMC Ports
       --
       ref_clk_clk_p          => clkethp,
       ref_clk_clk_n          => clkethn,
       ref_clk_oe             => OPEN,
       ref_clk_fsel           => OPEN,
       --
       reset_port_0           => reset_port_0,
       reset_port_1           => reset_port_1,
       reset_port_2           => reset_port_2,
       reset_port_3           => reset_port_3,
       --
       rgmii_port_0_rxc       => rgmii_port_0_rxc'delayed(3 ns),
       rgmii_port_0_rx_ctl    => rgmii_port_0_rx_ctl,
       rgmii_port_0_rd        => rgmii_port_0_rd,
       rgmii_port_0_txc       => rgmii_port_0_txc,
       rgmii_port_0_tx_ctl    => rgmii_port_0_tx_ctl,
       rgmii_port_0_td        => rgmii_port_0_td,
       rgmii_port_1_rxc       => rgmii_port_1_rxc'delayed(3 ns),
       rgmii_port_1_rx_ctl    => rgmii_port_1_rx_ctl,
       rgmii_port_1_rd        => rgmii_port_1_rd,
       rgmii_port_1_txc       => rgmii_port_1_txc,
       rgmii_port_1_tx_ctl    => rgmii_port_1_tx_ctl,
       rgmii_port_1_td        => rgmii_port_1_td,
       rgmii_port_2_rxc       => rgmii_port_2_rxc'delayed(3 ns),
       rgmii_port_2_rx_ctl    => rgmii_port_2_rx_ctl,
       rgmii_port_2_rd        => rgmii_port_2_rd,
       rgmii_port_2_txc       => rgmii_port_2_txc,
       rgmii_port_2_tx_ctl    => rgmii_port_2_tx_ctl,
       rgmii_port_2_td        => rgmii_port_2_td,
       rgmii_port_3_rxc       => rgmii_port_3_rxc'delayed(3 ns),
       rgmii_port_3_rx_ctl    => rgmii_port_3_rx_ctl,
       rgmii_port_3_rd        => rgmii_port_3_rd,
       rgmii_port_3_txc       => rgmii_port_3_txc,
       rgmii_port_3_tx_ctl    => rgmii_port_3_tx_ctl,
       rgmii_port_3_td        => rgmii_port_3_td,
       --
       mdio_io_port_0_mdio_io => mdio_io_port_0_mdio_io,
       mdio_io_port_0_mdc     => mdio_io_port_0_mdc,
       mdio_io_port_1_mdio_io => mdio_io_port_1_mdio_io,
       mdio_io_port_1_mdc     => mdio_io_port_1_mdc,
       mdio_io_port_2_mdio_io => mdio_io_port_2_mdio_io,
       mdio_io_port_2_mdc     => mdio_io_port_2_mdc,
       mdio_io_port_3_mdio_io => mdio_io_port_3_mdio_io,
       mdio_io_port_3_mdc     => mdio_io_port_3_mdc,
       --
       reset_port_4           => reset_port_4,
       reset_port_5           => reset_port_5,
       reset_port_6           => reset_port_6,
       reset_port_7           => reset_port_7,
       --
       rgmii_port_4_rxc       => rgmii_port_4_rxc'delayed(3 ns),
       rgmii_port_4_rx_ctl    => rgmii_port_4_rx_ctl,
       rgmii_port_4_rd        => rgmii_port_4_rd,
       rgmii_port_4_txc       => rgmii_port_4_txc,
       rgmii_port_4_tx_ctl    => rgmii_port_4_tx_ctl,
       rgmii_port_4_td        => rgmii_port_4_td,
       rgmii_port_5_rxc       => rgmii_port_5_rxc'delayed(3 ns),
       rgmii_port_5_rx_ctl    => rgmii_port_5_rx_ctl,
       rgmii_port_5_rd        => rgmii_port_5_rd,
       rgmii_port_5_txc       => rgmii_port_5_txc,
       rgmii_port_5_tx_ctl    => rgmii_port_5_tx_ctl,
       rgmii_port_5_td        => rgmii_port_5_td,
       rgmii_port_6_rxc       => rgmii_port_6_rxc'delayed(3 ns),
       rgmii_port_6_rx_ctl    => rgmii_port_6_rx_ctl,
       rgmii_port_6_rd        => rgmii_port_6_rd,
       rgmii_port_6_txc       => rgmii_port_6_txc,
       rgmii_port_6_tx_ctl    => rgmii_port_6_tx_ctl,
       rgmii_port_6_td        => rgmii_port_6_td,
       rgmii_port_7_rxc       => rgmii_port_7_rxc'delayed(3 ns),
       rgmii_port_7_rx_ctl    => rgmii_port_7_rx_ctl,
       rgmii_port_7_rd        => rgmii_port_7_rd,
       rgmii_port_7_txc       => rgmii_port_7_txc,
       rgmii_port_7_tx_ctl    => rgmii_port_7_tx_ctl,
       rgmii_port_7_td        => rgmii_port_7_td,
       --
       mdio_io_port_4_mdio_io => mdio_io_port_4_mdio_io,
       mdio_io_port_4_mdc     => mdio_io_port_4_mdc,
       mdio_io_port_5_mdio_io => mdio_io_port_5_mdio_io,
       mdio_io_port_5_mdc     => mdio_io_port_5_mdc,
       mdio_io_port_6_mdio_io => mdio_io_port_6_mdio_io,
       mdio_io_port_6_mdc     => mdio_io_port_6_mdc,
       mdio_io_port_7_mdio_io => mdio_io_port_7_mdio_io,
       mdio_io_port_7_mdc     => mdio_io_port_7_mdc,
       --
       -- End of FMC Ports
       can_txd         => OPEN,
       can_rxd         => "0",
       spi_data_out    => '0',
       spi_data_in     => OPEN,
       spi_data_cs_b   => OPEN,
       spi_clk         => OPEN
      );

  phy0 : if (CFG_GRETH = 1) generate
   -- Simulation model for SGMII PHY MDIO interface 
   phy_mdio <= 'H';
   p0: phy
    generic map (
             address       => 7,
             extended_regs => 1,
             aneg          => 1,
             base100_t4    => 1,
             base100_x_fd  => 1,
             base100_x_hd  => 1,
             fd_10         => 1,
             hd_10         => 1,
             base100_t2_fd => 1,
             base100_t2_hd => 1,
             base1000_x_fd => CFG_GRETH1G,
             base1000_x_hd => CFG_GRETH1G,
             base1000_t_fd => CFG_GRETH1G,
             base1000_t_hd => CFG_GRETH1G,
             rmii          => 0,
             rgmii         => 1
    )
    port map(dsurst, phy_mdio, OPEN , OPEN , OPEN ,
             OPEN , OPEN , OPEN , OPEN , "00000000",
             '0', '0', phy_mdc, clkethp); 

  end generate;
  
  fmc_phy0 : if (CFG_GRETH_FMC = 1) generate
   -- FMC PHY0 Running at 25MHz
   rgmii_port_0_rd  <= rgmii_port_0_rd8(3 downto 0);
   rgmii_port_0_td8 <= rgmii_port_0_td & rgmii_port_0_td;
   mdio_io_port_0_mdio_io <= 'H';
   fmc_p0: phy
    generic map (
             address       => 0,
             extended_regs => 1,
             aneg          => 1,
             base100_t4    => 1,
             base100_x_fd  => 1,
             base100_x_hd  => 1,
             fd_10         => 1,
             hd_10         => 1,
             base100_t2_fd => 1,
             base100_t2_hd => 1,
             base1000_x_fd => 0,
             base1000_x_hd => 0,
             base1000_t_fd => 0,
             base1000_t_hd => 0,
             rmii          => 0,
             rgmii         => 1
    )
    port map(reset_port_0, mdio_io_port_0_mdio_io, OPEN, rgmii_port_0_rxc, 
             rgmii_port_0_rd8, rgmii_port_0_rx_ctl, OPEN, OPEN, OPEN,
             rgmii_port_0_td8, rgmii_port_0_tx_ctl, '0',
             mdio_io_port_0_mdc,
             rgmii_port_0_txc, clkethp); 

    -- FMC PHY1 Running at 125MHz
   rgmii_port_1_rd  <= rgmii_port_1_rd8(3 downto 0);
   rgmii_port_1_td8 <= rgmii_port_1_td & rgmii_port_1_td;
   mdio_io_port_1_mdio_io <= 'H';
   fmc_p1: phy
    generic map (
             address       => 0,
             extended_regs => 1,
             aneg          => 1,
             base100_t4    => 1,
             base100_x_fd  => 1,
             base100_x_hd  => 1,
             fd_10         => 1,
             hd_10         => 1,
             base100_t2_fd => 1,
             base100_t2_hd => 1,
             base1000_x_fd => CFG_GRETH1G,
             base1000_x_hd => CFG_GRETH1G,
             base1000_t_fd => CFG_GRETH1G,
             base1000_t_hd => CFG_GRETH1G,
             rmii          => 0,
             rgmii         => 1
    )
    port map(reset_port_1, mdio_io_port_1_mdio_io, OPEN, rgmii_port_1_rxc, 
             rgmii_port_1_rd8, rgmii_port_1_rx_ctl, OPEN, OPEN, OPEN,
             rgmii_port_1_td8, rgmii_port_1_tx_ctl, '0',
             mdio_io_port_1_mdc,
             rgmii_port_1_txc, clkethp);
             
    -- FMC PHY2 Running at  25MHz
    rgmii_port_2_rd  <= rgmii_port_2_rd8(3 downto 0);
    rgmii_port_2_td8 <= rgmii_port_2_td & rgmii_port_2_td;
    mdio_io_port_2_mdio_io <= 'H';
    fmc_p2: phy
    generic map (
             address       => 0,
             extended_regs => 1,
             aneg          => 1,
             base100_t4    => 1,
             base100_x_fd  => 1,
             base100_x_hd  => 1,
             fd_10         => 1,
             hd_10         => 1,
             base100_t2_fd => 1,
             base100_t2_hd => 1,
             base1000_x_fd => 0,
             base1000_x_hd => 0,
             base1000_t_fd => 0,
             base1000_t_hd => 0,
             rmii          => 0,
             rgmii         => 1
    )
    port map(reset_port_2, mdio_io_port_2_mdio_io, OPEN, rgmii_port_2_rxc, 
             rgmii_port_2_rd8, rgmii_port_2_rx_ctl, OPEN, OPEN, OPEN,
             rgmii_port_2_td8, rgmii_port_2_tx_ctl, '0',
             mdio_io_port_2_mdc,
             rgmii_port_2_txc, clkethp);
             
    -- FMC PHY3 Running at 2.5MHz
    rgmii_port_3_rd  <= rgmii_port_3_rd8(3 downto 0);
    rgmii_port_3_td8 <= rgmii_port_3_td & rgmii_port_3_td;
    mdio_io_port_3_mdio_io <= 'H';
    fmc_p3: phy
    generic map (
             address       => 0,
             extended_regs => 1,
             aneg          => 1,
             base100_t4    => 0,
             base100_x_fd  => 0,
             base100_x_hd  => 0,
             fd_10         => 1,
             hd_10         => 1,
             base100_t2_fd => 0,
             base100_t2_hd => 0,
             base1000_x_fd => 0,
             base1000_x_hd => 0,
             base1000_t_fd => 0,
             base1000_t_hd => 0,
             rmii          => 0,
             rgmii         => 1
    )
    port map(reset_port_3, mdio_io_port_3_mdio_io, OPEN, rgmii_port_3_rxc, 
             rgmii_port_3_rd8, rgmii_port_3_rx_ctl, OPEN, OPEN, OPEN,
             rgmii_port_3_td8, rgmii_port_3_tx_ctl, '0',
             mdio_io_port_3_mdc,
             rgmii_port_3_txc, clkethp);    
  
   -- FMC PHY4 Running at 125MHz
   rgmii_port_4_rd  <= rgmii_port_4_rd8(3 downto 0);
   rgmii_port_4_td8 <= rgmii_port_4_td & rgmii_port_4_td;
   mdio_io_port_4_mdio_io <= 'H';
   fmc_p4: phy
    generic map (
             address       => 0,
             extended_regs => 1,
             aneg          => 1,
             base100_t4    => 1,
             base100_x_fd  => 1,
             base100_x_hd  => 1,
             fd_10         => 1,
             hd_10         => 1,
             base100_t2_fd => 1,
             base100_t2_hd => 1,
             base1000_x_fd => CFG_GRETH1G,
             base1000_x_hd => CFG_GRETH1G,
             base1000_t_fd => CFG_GRETH1G,
             base1000_t_hd => CFG_GRETH1G,
             rmii          => 0,
             rgmii         => 1
    )
    port map(reset_port_4, mdio_io_port_4_mdio_io, OPEN, rgmii_port_4_rxc, 
             rgmii_port_4_rd8, rgmii_port_4_rx_ctl, OPEN, OPEN, OPEN,
             rgmii_port_4_td8, rgmii_port_4_tx_ctl, '0',
             mdio_io_port_4_mdc,
             rgmii_port_4_txc, clkethp);

  -- FMC PHY5 Running at 125MHz
   rgmii_port_5_rd  <= rgmii_port_5_rd8(3 downto 0);
   rgmii_port_5_td8 <= rgmii_port_5_td & rgmii_port_5_td;
   mdio_io_port_5_mdio_io <= 'H';
   fmc_p5: phy
    generic map (
             address       => 0,
             extended_regs => 1,
             aneg          => 1,
             base100_t4    => 1,
             base100_x_fd  => 1,
             base100_x_hd  => 1,
             fd_10         => 1,
             hd_10         => 1,
             base100_t2_fd => 1,
             base100_t2_hd => 1,
             base1000_x_fd => CFG_GRETH1G,
             base1000_x_hd => CFG_GRETH1G,
             base1000_t_fd => CFG_GRETH1G,
             base1000_t_hd => CFG_GRETH1G,
             rmii          => 0,
             rgmii         => 1
    )
    port map(reset_port_5, mdio_io_port_5_mdio_io, OPEN, rgmii_port_5_rxc, 
             rgmii_port_5_rd8, rgmii_port_5_rx_ctl, OPEN, OPEN, OPEN,
             rgmii_port_5_td8, rgmii_port_5_tx_ctl, '0',
             mdio_io_port_5_mdc,
             rgmii_port_5_txc, clkethp);
             
    -- FMC PHY6 Running at 125MHz
    rgmii_port_6_rd  <= rgmii_port_6_rd8(3 downto 0);
    rgmii_port_6_td8 <= rgmii_port_6_td & rgmii_port_6_td;
    mdio_io_port_6_mdio_io <= 'H';
    fmc_p6: phy
     generic map (
              address       => 0,
              extended_regs => 1,
              aneg          => 1,
              base100_t4    => 1,
              base100_x_fd  => 1,
              base100_x_hd  => 1,
              fd_10         => 1,
              hd_10         => 1,
              base100_t2_fd => 1,
              base100_t2_hd => 1,
              base1000_x_fd => CFG_GRETH1G,
              base1000_x_hd => CFG_GRETH1G,
              base1000_t_fd => CFG_GRETH1G,
              base1000_t_hd => CFG_GRETH1G,
              rmii          => 0,
              rgmii         => 1
     )
     port map(reset_port_6, mdio_io_port_6_mdio_io, OPEN, rgmii_port_6_rxc, 
              rgmii_port_6_rd8, rgmii_port_6_rx_ctl, OPEN, OPEN, OPEN,
              rgmii_port_6_td8, rgmii_port_6_tx_ctl, '0',
              mdio_io_port_6_mdc,
              rgmii_port_6_txc, clkethp); 

    -- FMC PHY7 Running at 125MHz
    rgmii_port_7_rd  <= rgmii_port_7_rd8(3 downto 0);
    rgmii_port_7_td8 <= rgmii_port_7_td & rgmii_port_7_td;
    mdio_io_port_7_mdio_io <= 'H';
    fmc_p7: phy
     generic map (
              address       => 0,
              extended_regs => 1,
              aneg          => 1,
              base100_t4    => 1,
              base100_x_fd  => 1,
              base100_x_hd  => 1,
              fd_10         => 1,
              hd_10         => 1,
              base100_t2_fd => 1,
              base100_t2_hd => 1,
              base1000_x_fd => CFG_GRETH1G,
              base1000_x_hd => CFG_GRETH1G,
              base1000_t_fd => CFG_GRETH1G,
              base1000_t_hd => CFG_GRETH1G,
              rmii          => 0,
              rgmii         => 1
     )
     port map(reset_port_7, mdio_io_port_7_mdio_io, OPEN, rgmii_port_7_rxc, 
              rgmii_port_7_rd8, rgmii_port_7_rx_ctl, OPEN, OPEN, OPEN,
              rgmii_port_7_td8, rgmii_port_7_tx_ctl, '0',
              mdio_io_port_7_mdc,
              rgmii_port_7_txc, clkethp);
  end generate;

  prom0 : for i in 0 to 1 generate
      sr0 : sram generic map (index => i+4, abits => 26, fname => promfile)
        port map (address(25 downto 0), data(15-i*8 downto 8-i*8), romsn,
                  writen, oen);
  end generate;

  -- Memory model instantiation
  gen_mem_model : if (USE_MIG_INTERFACE_MODEL /= true) generate
   ddr3mem : if (CFG_MIG_7SERIES = 1) generate
     u1 : ddr3ram
       generic map (
         width     => 64,
         abits     => 14,
         colbits   => 10,
         rowbits   => 10,
         implbanks => 1,
         fname     => ramfile,
         lddelay   => (0 ns),
         ldguard   => 1,
         speedbin  => 9, --DDR3-1600K
         density   => 3,
         pagesize  => 1,
         changeendian => 8)
       port map (
          ck     => ddr3_ck_p(0),
          ckn    => ddr3_ck_n(0),
          cke    => ddr3_cke(0),
          csn    => ddr3_cs_n(0),
          odt    => ddr3_odt(0),
          rasn   => ddr3_ras_n,
          casn   => ddr3_cas_n,
          wen    => ddr3_we_n,
          dm     => ddr3_dm,
          ba     => ddr3_ba,
          a      => ddr3_addr,
          resetn => ddr3_reset_n,
          dq     => ddr3_dq,
          dqs    => ddr3_dqs_p,
          dqsn   => ddr3_dqs_n,
          doload => led(3)
          );
   end generate ddr3mem;
  end generate gen_mem_model;

  mig_mem_model : if (USE_MIG_INTERFACE_MODEL = true) generate
    ddr3_dq    <= (others => 'Z');
    ddr3_dqs_p <= (others => 'Z');
    ddr3_dqs_n <= (others => 'Z');
  end generate mig_mem_model;

  errorn <= led(1);
  errorn <= 'H'; -- ERROR pull-up

  usbtr: if (CFG_GRUSBHC = 1) generate
    u0: ulpi
      port map (usb_clkout, usb_d, usb_nxt, usb_stp, usb_dir, usb_resetn);
  end generate usbtr;

  usbdevsim: if (CFG_GRUSBDC = 1) generate
    u0: grusbdcsim
      generic map (functm => 0, keepclk => 1)
      port map (usb_resetn, usb_clkout, usb_d, usb_nxt, usb_stp, usb_dir);
  end generate usbdevsim;

  usb_dclsim: if (CFG_GRUSB_DCL = 1) generate
    u0: grusb_dclsim
      generic map (functm => 0, keepclk => 1)
      port map (usb_resetn, usb_clkout, usb_d, usb_nxt, usb_stp, usb_dir,
                ddelay, dstart, drw, daddr, dlen, ddi, ddone, ddo);

    usb_dcl_proc : process
    begin
      wait for 10 ns;
      Print("GRUSB_DCL test started");

      wait until rising_edge(ddone);

      -- Write 128 bytes to memory
      daddr <= X"40000000";
      dlen  <= conv_std_logic_vector(32,15);
      for i in 0 to 127 loop
        ddi(i) <= conv_std_logic_vector(i+8,8);
      end loop;  -- i
      grusb_dcl_write(usb_clkout, drw, dstart, ddone);

      -- Read back written data
      grusb_dcl_read(usb_clkout, drw, dstart, ddone);

      -- Compare data
      for i in 0 to 127 loop
        if ddo(i) /= ddi(i) then
          Print("ERROR: Data mismatch using GRUSB_DCL");
        end if;
      end loop;

      Print("GRUSB_DCL test finished");

      wait;
    end process;
  end generate usb_dclsim;

   iuerr : process
   begin
     -- This is for proper DDR3 behaviour durign init phase not needed durin simulation
     wait for 210 us; 
     if (USE_MIG_INTERFACE_MODEL /= true) then
       wait on led(3);  -- DDR3 Memory Init ready
     end if;
     wait for 5000 ns;
     -- Wait for Ethernet to start if simulated
     if (CFG_GRETH_FMC = 1) then
       wait for 500 us;
     end if;
     -- Wait for error or end of simulation
     if to_x01(errorn) = '1' then 
       wait on errorn;
     end if;
     assert (to_x01(errorn) = '1')
       report "*** IU in error mode, simulation halted ***"
          severity failure ; -- this should be a failure
   end process;

  data <= buskeep(data) after 5 ns;

  dsucom : process
    procedure dsucfg(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
    variable w32 : std_logic_vector(31 downto 0);
    variable c8  : std_logic_vector(7 downto 0);
    constant txp : time := 320 * 1 ns;
    begin
    dsutx <= '1';
    dsurst <= '0';
    switch(4) <= '0';
    wait for 2500 ns;
    if (USE_MIG_INTERFACE_MODEL /= true) then
       wait for 210 us; -- This is for proper DDR3 behaviour durign init phase not needed durin simulation
    end if;
    dsurst <= '1';
    switch(4) <= '1';
    if (USE_MIG_INTERFACE_MODEL /= true) then
       wait on led(3);  -- Wait for DDR3 Memory Init ready
    end if;
    report "Start DSU transfer";
    wait for 5000 ns;
    txc(dsutx, 16#55#, txp);      -- sync uart

    -- Reads from memory and DSU register to mimic GRMON during simulation
    l1 : loop
     txc(dsutx, 16#80#, txp);
     txa(dsutx, 16#40#, 16#00#, 16#00#, 16#04#, txp);
     rxi(dsurx, w32, txp, lresp);
     --report "DSU read memory " & tost(w32);
     txc(dsutx, 16#80#, txp);
     txa(dsutx, 16#90#, 16#00#, 16#00#, 16#20#, txp);
     rxi(dsurx, w32, txp, lresp);
     --report "DSU Break and Single Step register" & tost(w32);
    end loop l1;

    wait;

    -- ** This is only kept for reference --

    -- do test read and writes to DDR3 to check status
    -- Write
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#40#, 16#00#, 16#00#, 16#00#, txp);
    txa(dsutx, 16#01#, 16#23#, 16#45#, 16#67#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#40#, 16#00#, 16#00#, 16#04#, txp);
    txa(dsutx, 16#89#, 16#AB#, 16#CD#, 16#EF#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#40#, 16#00#, 16#00#, 16#08#, txp);
    txa(dsutx, 16#08#, 16#19#, 16#2A#, 16#3B#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#40#, 16#00#, 16#00#, 16#0C#, txp);
    txa(dsutx, 16#4C#, 16#5D#, 16#6E#, 16#7F#, txp);
    txc(dsutx, 16#80#, txp);
    txa(dsutx, 16#40#, 16#00#, 16#00#, 16#00#, txp);
    rxi(dsurx, w32, txp, lresp);
    txc(dsutx, 16#80#, txp);
    txa(dsutx, 16#40#, 16#00#, 16#00#, 16#04#, txp);
    rxi(dsurx, w32, txp, lresp);
    report "* Read " & tost(w32);
    txc(dsutx, 16#a0#, txp);
    txa(dsutx, 16#40#, 16#00#, 16#00#, 16#08#, txp);
    rxi(dsurx, w32, txp, lresp);
    txc(dsutx, 16#a0#, txp);
    txa(dsutx, 16#40#, 16#00#, 16#00#, 16#0C#, txp);
    rxi(dsurx, w32, txp, lresp);
    wait;

    -- Register 0x90000000 (DSU Control Register)
    -- Data 0x0000202e (b0010 0000 0010 1110)
    -- [0] - Trace Enable
    -- [1] - Break On Error
    -- [2] - Break on IU watchpoint
    -- [3] - Break on s/w break points
    --
    -- [4] - (Break on trap)
    -- [5] - Break on error traps
    -- [6] - Debug mode (Read mode only)
    -- [7] - DSUEN (read mode)
    --
    -- [8] - DSUBRE (read mode)
    -- [9] - Processor mode error (clears error)
    -- [10] - processor halt (returns 1 if processor halted)
    -- [11] - power down mode (return 1 if processor in power down mode)
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#00#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#80#, 16#02#, txp);
    wait;
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#00#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#20#, 16#2e#, txp);

    wait for 25000 ns;
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#20#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#01#, txp);

    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#40#, 16#00#, 16#24#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#0D#, txp);

    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#70#, 16#11#, 16#78#, txp);
    txa(dsutx, 16#91#, 16#00#, 16#00#, 16#0D#, txp);

    txa(dsutx, 16#90#, 16#40#, 16#00#, 16#44#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#20#, 16#00#, txp);

    txc(dsutx, 16#80#, txp);
    txa(dsutx, 16#90#, 16#40#, 16#00#, 16#44#, txp);

    wait;

   end;

   begin
    dsuctsn <= '0';
    dsucfg(dsutx, dsurx);
    wait;
  end process;
end ;

