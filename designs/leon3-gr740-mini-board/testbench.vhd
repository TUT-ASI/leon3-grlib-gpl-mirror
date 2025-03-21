-----------------------------------------------------------------------------
--  LEON3 Demonstration design test bench
--  Copyright (C) 2022 Cobham Gaisler
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
library techmap;
use techmap.gencomp.all;
--use work.debug.all;

use work.config.all;

entity testbench is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    clktech   : integer := CFG_CLKTECH;
    ncpu      : integer := CFG_NCPU;
    disas     : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart   : integer := 0; --fixme CFG_DUART;        -- Print UART on console
    pclow     : integer := CFG_PCLOW;
    clkperiod : integer := 20           -- system clock period
    );
end;

architecture behav of testbench is
  constant promfile  : string  := "prom.srec";      -- rom contents
  constant ct       : integer := clkperiod/2;

  signal error           : std_logic;
  -- Clocks
  signal clk_in_33mhz    : std_logic := '0';
  signal clk_in_125mhz   : std_logic := '0';
  -- reset
  signal gsrn            : std_logic := '0';
  -- LEDs
  signal led             : std_logic_vector(3 downto 0);
  -- GPIO
  signal gpio            : std_logic_vector(4 downto 0);
  -- SPI memory
  signal spi_mclk        : std_logic;
  signal dq0_mosi        : std_logic;
  signal dq1_miso        : std_logic;
  signal csspin          : std_logic;
  signal dq2             : std_logic;
  signal dq3             : std_logic;
  -- UART
  signal rxduart         : std_logic;
  signal txduart         : std_logic;
  -- Ethernet
  signal eth_int_n       : std_ulogic;
  signal eth_mdc         : std_ulogic;
  signal eth_mdio        : std_logic;
  signal eth_rst_n       : std_ulogic;
  signal eth_rxd         : std_logic_vector(7 downto 0);
  signal eth_rx_ctl      : std_logic;
  signal eth_rx_clk      : std_logic;
  signal eth_txd         : std_logic_vector(7 downto 0);
  signal eth_tx_ctl      : std_logic;
  signal eth_tx_clk      : std_logic;
  signal phy_rxer        : std_ulogic;
  signal phy_txer        : std_ulogic;
  signal phy_txclk       : std_ulogic;
  signal phy_crs         : std_ulogic;
  signal phy_col         : std_ulogic;
  -- SpaceWire
  signal spw_io_gnd : std_logic_vector(1 to CFG_SPW_SPWPORTS);
  -- PCI arbiter
  signal pci_arb_req, pci_arb_gnt : std_logic_vector(0 to 1);

begin
  -- clock and reset
  clk_in_33mhz  <= not clk_in_33mhz after 15.15 ns;
  clk_in_125mhz  <= not clk_in_125mhz after 4 ns;
  gsrn        <= '0', '1' after ct * 20 ns;

  rxduart     <= 'H';
  pci_arb_req <= "HH";

  d3 : entity work.gr740_mini_board
    generic map (fabtech => fabtech,
                 memtech => memtech,
                 padtech => padtech,
                 clktech => clktech,
                 dbguart => 0,
                 simulation => true)
    port map (
      -- clk
      clk_in_125mhz  => clk_in_125mhz,
      clk_in_33mhz   => clk_in_33mhz,
      -- reset
      gsrn     => gsrn,
      -- LEDs
      led      => led,
      -- SPI memory
      spi_mclk => spi_mclk,
      dq0_mosi => dq0_mosi,
      dq1_miso => dq1_miso,
      csspin   => csspin,
      dq2      => dq2,
      dq3      => dq3,
      -- UART
      rxduart  => rxduart,
      txduart  => txduart,
      -- PCI
      pci_gnt     => '0',
      pci_idsel_config   => open,
      pci_ad 	 => open,
      pci_cbe 	=> open,
      pci_frame   => open,
      pci_irdy 	=> open,
      pci_trdy 	=> open,
      pci_devsel  => open,
      pci_stop 	=> open,
      pci_perr 	=> open,
      pci_par 	=> open,
      pci_req 	=> open, -- tristate pad but never read
      pci_serr    => open,  -- open drain output
      pci_host_config   	=> open,
      pci_66_config	 => open ,
      pci_int	 => open,
      pci_arb_req => pci_arb_req,
      pci_arb_gnt => open,
      gpio            => open,
      -- Ethernet
      eth_gtxclk   => open,
      eth_mdio     => open,
      eth_txclk    => '0',
      eth_rxclk    => '0',
      eth_rxd     => (others => '0'),
      eth_rxdv     => '0',
      eth_rxer     => '0',
      eth_col      => '0',
      eth_crs      => '0',
      eth_mdint    => '0',
      eth_txd      => open,
      eth_txen   => open,
      eth_txer       => open,
      eth_mdc        => open,
      eth0_mdc      => '0',
      eth0_mdint      => '0',
      eth0_mdio      => '0',
      -- SpaceWire router
      spw_din_p => spw_io_gnd,
      spw_sin_p => spw_io_gnd,
      spw_dout_p => open,
      spw_sout_p => open,
      -- JTAG
      tck      => 'H',
      tms      => 'H',
      tdi      => 'H',
      tdo      => open,
      -- SpaceFibre
      SDQ0_REFCLKP => '0',
      SDQ0_REFCLKN => '0',
      SD0_RXDP => '0',
      SD0_RXDN => '0',
      SD_EXT0_REFCLKP => '0',
      SD_EXT0_REFCLKN => '0',
      SD2_RXDP => '0',
      SD2_RXDN => '0',
      SD6_RXDP => '0',
      SD6_RXDN => '0',
      SD7_RXDP => '0',
      SD7_RXDN => '0',
      SDQ1_REFCLKP => '0',
      SDQ1_REFCLKN => '0',
      SD_EXT1_REFCLKP => '0',
      SD_EXT1_REFCLKN => '0'
      );

  s0 : spi_flash
    generic map (ftype => 4, debug => 0, fname => promfile,
                 readcmd => CFG_SPIMCTRL_READCMD,
                 dummybyte => CFG_SPIMCTRL_DUMMYBYTE,
                 dualoutput => CFG_SPIMCTRL_DUALOUTPUT)
    port map (spi_mclk, dq0_mosi, dq1_miso, csspin);

  error <= led(0);

  iuerr : process
  begin
    wait for 5 us;
    if to_x01(error) = '0' then wait on error; end if;
    assert (to_X01(error) = '0')
      report "*** IU in error mode, simulation halted ***"
      severity failure;
  end process;

end;
