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
use work.debug.all;

use work.config.all;

entity testbench is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    ncpu      : integer := CFG_NCPU;
    disas     : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart   : integer := 0; --fixme CFG_DUART;        -- Print UART on console
    pclow     : integer := CFG_PCLOW;
    clkperiod : integer := 8           -- oscillator clock period - 125MHz
    );
end;

architecture behav of testbench is
  constant promfile  : string  := "prom.srec";      -- rom contents
  constant ramfile   : string := "ram.srec"; -- ram contents

  constant ct       : integer := clkperiod/2;

  signal clk_in     : std_logic := '0';
  signal gsrn       : std_logic := '0';

  signal led        : std_logic_vector(7 downto 0);
  signal pmod1      : std_logic_vector(7 downto 0);
  signal pmod2      : std_logic_vector(7 downto 0);

  signal spi_mclk   : std_logic;
  signal dq0_mosi   : std_logic;
  signal dq1_miso   : std_logic;
  signal csspin     : std_logic;
  signal dq2        : std_logic;
  signal dq3        : std_logic;

  signal rxduart : std_logic;
  signal txduart : std_logic;

  signal error   : std_logic;

  signal spw_io_gnd : std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);

begin
  -- clock and reset
  clk_in      <= not clk_in after ct * 1 ns;
  gsrn        <= '0', '1' after ct * 20 ns;

  rxduart     <= 'H';

  spw_io_gnd <= (others => '0');

  d3 : entity work.leon3mp
    generic map (fabtech => fabtech,
                 memtech => memtech,
                 padtech => padtech,
                 dbguart => 0,
                 simulation => true,
                 ramfile => ramfile)
    port map (
      clk_in   => clk_in,
      gsrn     => gsrn,
      led      => led,
      pmod1    => pmod1,
      pmod2    => pmod2,
      spi_mclk => spi_mclk,
      dq0_mosi => dq0_mosi,
      dq1_miso => dq1_miso,
      csspin   => csspin,
      dq2      => dq2,
      dq3      => dq3,
      rxduart  => rxduart,
      txduart  => txduart,
      gbtclk0_p => 'H',
      gbtclk0_n => 'H',
      hssl_rxp  => (others => 'H'),
      hssl_rxn  => (others => 'H'),
      hssl_txp  => open,
      hssl_txn  => open,
      spw_din_p => spw_io_gnd,
      spw_sin_p => spw_io_gnd,
      spw_dout_p => open,
      spw_sout_p => open,
      canfd_tx   => open,
      canfd_rx   => '0',
      canfd_en   => open,
      can_tx     => open,
      can_rx     => '0',
      can_en     => open,
      tck      => 'H',
      tms      => 'H',
      tdi      => 'H',
      tdo      => open
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
