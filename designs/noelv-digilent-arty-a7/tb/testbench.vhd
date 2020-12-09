-----------------------------------------------------------------------------
--  LEON3 Demonstration design test bench
--  Copyright (C) 2016 Cobham Gaisler
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2018, Cobham Gaisler
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
library gaisler;
use gaisler.sim.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.stdlib.all;
use grlib.stdio.all;
use grlib.amba.all;
use grlib.testlib.gen_rand_int;
use grlib.testlib.data_vector128;
use work.debug.all;

use work.config.all;

entity testbench is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    clktech   : integer := CFG_CLKTECH;
    disas     : integer := CFG_DISAS;   -- Enable disassembly to console
    USE_MIG_INTERFACE_MODEL : boolean := true;
    clkperiod : integer := 10           -- system clock period
    );
end;

architecture behav of testbench is
  constant promfile  : string  := "prom.srec";      -- rom contents
  constant sdramfile : string  := "ram.srec";       -- sdram contents

  constant ct       : integer := clkperiod/2;

  -- MIG Simulation parameters
  constant SIM_BYPASS_INIT_CAL : string := "FAST";
          -- # = "OFF" -  Complete memory init &
          --               calibration sequence
          -- # = "SKIP" - Not supported
          -- # = "FAST" - Complete memory init & use
          --              abbreviated calib sequence

  constant SIMULATION          : string := "TRUE";
          -- Should be TRUE during design simulations and
          -- FALSE during implementations

  signal CLK100MHZ          : std_ulogic := '0';
  -- LEDs
  signal led                : std_logic_vector(3 downto 0);
  -- Buttons
  signal btn                : std_logic_vector(3 downto 0);
  signal cpu_resetn         : std_ulogic;
  -- Switches
  signal sw                 : std_logic_vector(3 downto 0);    
  -- USB-RS232 interface
  signal uart_tx_in         : std_logic;
  signal uart_rx_out        : std_logic;
  -- DDR3
  signal ddr3_dq            : std_logic_vector(15 downto 0);
  signal ddr3_dqs_p         : std_logic_vector(1 downto 0);
  signal ddr3_dqs_n         : std_logic_vector(1 downto 0);
  signal ddr3_addr          : std_logic_vector(14 downto 0);
  signal ddr3_ba            : std_logic_vector(2 downto 0);
  signal ddr3_ras_n         : std_logic;
  signal ddr3_cas_n         : std_logic;
  signal ddr3_we_n          : std_logic;
  signal ddr3_reset_n       : std_logic;
  signal ddr3_ck_p          : std_logic_vector(0 downto 0);
  signal ddr3_ck_n          : std_logic_vector(0 downto 0);
  signal ddr3_cke           : std_logic_vector(0 downto 0);
  signal ddr3_dm            : std_logic_vector(1 downto 0);
  signal ddr3_odt           : std_logic_vector(0 downto 0);
  -- Fan PWM
  signal fan_pwm            : std_ulogic;    
  -- SPI
  signal qspi_cs            : std_logic;
  signal qspi_dq            : std_logic_vector(3 downto 0);
  signal scl                : std_ulogic;

  signal gnd                : std_ulogic;

  signal eref_clk   : std_ulogic;
  signal etx_clk    : std_ulogic;
  signal erx_clk    : std_ulogic;
  signal erxdt      : std_logic_vector(3 downto 0);
  signal erx_dv     : std_ulogic;
  signal erx_er     : std_ulogic;
  signal erx_col    : std_ulogic;
  signal erx_crs    : std_ulogic;
  signal etxdt      : std_logic_vector(3 downto 0);
  signal etx_en     : std_ulogic;
  signal etx_er     : std_ulogic;
  signal emdc       : std_ulogic;
  signal emdio      : std_logic;
  signal erstn      : std_logic;

  
begin

  gnd <= '0';

  -- clock and reset
  CLK100MHZ     <= not CLK100MHZ after ct * 1 ns;
  -- reset
  btn(0)        <= '1', '0' after 100 ns;
  -- dsui.break
  btn(1)        <= '0';
  -- dsui.enable
  sw(0)         <= '1';

  d3 : entity work.noelvmp
    generic map (fabtech, memtech, padtech, clktech, disas)
    port map (
      CLK100MHZ => CLK100MHZ, led => led,
      btn => btn,
      sw => sw,
      uart_txd_in => '1',
      uart_rxd_out => open,
      eth_col         => erx_col,
      eth_crs         => erx_crs,
      eth_mdc         => emdc,
      eth_mdio        => emdio,
      eth_ref_clk     => eref_clk,
      eth_rstn        => erstn,
      eth_rx_clk      => erx_clk,
      eth_rx_dv       => erx_dv,
      eth_rxd         => erxdt,
      eth_rxerr       => erx_er,
      eth_tx_clk      => etx_clk,
      eth_tx_en       => etx_en,
      eth_txd         => etxdt
     );

  iuerr : process
  begin
    wait for 10 us;
    assert (to_X01(led(3)) = '0')
      report "*** IU in error mode, simulation halted ***"
      severity failure;  
  end process;

end;


