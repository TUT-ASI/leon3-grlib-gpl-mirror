-----------------------------------------------------------------------------
--  LEON Demonstration design test bench
--  Copyright (C) 2013 Gaisler Research
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
signal Rst             : std_logic := '0';

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

signal phy_gtxclk      : std_logic := '0';
signal phy_txer        : std_ulogic;
signal phy_txd         : std_logic_vector(7 downto 0);
signal phy_txctl_txen  : std_ulogic;
signal phy_txclk       : std_ulogic;
signal phy_rxer        : std_ulogic;
signal phy_rxd         : std_logic_vector(7 downto 0);
signal phy_rxctl_rxdv  : std_ulogic;
signal phy_rxclk       : std_ulogic;
signal phy_reset       : std_ulogic;
signal phy_mdio        : std_logic;
signal phy_mdc         : std_ulogic;
signal phy_crs         : std_ulogic;
signal phy_col         : std_ulogic;
signal phy_int         : std_ulogic;
signal phy_rxdl        : std_logic_vector(7 downto 0);
signal phy_txdl        : std_logic_vector(7 downto 0);

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

signal switch          : std_logic_vector(3 downto 0);    -- I/O port
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



begin

  -- clock and reset
  clk200p <= not clk200p after 2.5 ns;
  clk200n <= not clk200n after 2.5 ns;
  clkethp <= not clkethp after 4 ns;
  clkethn <= not clkethp after 4 ns;

  rst <= not dsurst;
  rxd1 <= 'H'; ctsn1 <= '0';
  rxd2 <= 'H'; ctsn2 <= '0';
  button <= "0000";
  switch(2 downto 0) <= "000";

  cpu : entity work.leon5mp
      generic map (
       fabtech              => fabtech,
       memtech              => memtech,
       padtech              => padtech,
       clktech              => clktech,
       disas                => disas,
       SIM_BYPASS_INIT_CAL  => SIM_BYPASS_INIT_CAL,
       SIMULATION           => SIMULATION,
       USE_MIG_INTERFACE_MODEL => USE_MIG_INTERFACE_MODEL
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
       gtrefclk_p      => clkethp,
       gtrefclk_n      => clkethn,
       phy_gtxclk      => phy_gtxclk,
       --phy_txer        => phy_txer,
       phy_txd         => phy_txd(3 downto 0),
       phy_txctl_txen  => phy_txctl_txen,
       --phy_txclk       => phy_txclk,
       --phy_rxer        => phy_rxer,
       phy_rxd         => phy_rxd(3 downto 0)'delayed(2 ns),
       phy_rxctl_rxdv  => phy_rxctl_rxdv'delayed(2 ns),
       phy_rxclk       => phy_rxclk,
       phy_reset       => phy_reset,
       phy_mdio        => phy_mdio,
       phy_mdc         => phy_mdc,
       phy_int         => phy_int
      );

  prom0 : for i in 0 to 1 generate
      sr0 : sram generic map (index => i+4, abits => 22, fname => promfile)
        port map (address(21 downto 0), data(15-i*8 downto 8-i*8), romsn,
                  writen, oen);
  end generate;

  -- Memory Models instantiations
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

  phy0 : if (CFG_GRETH = 1) generate

   phy_mdio <= 'H';
   phy_int <= '0';
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
             base1000_x_fd => 1,
             base1000_x_hd => 1,
             base1000_t_fd => 1,
             base1000_t_hd => 1,
             rmii          => 0,
             rgmii         => 1
    )
    port map(phy_reset, phy_mdio, OPEN, phy_rxclk,
             phy_rxd, phy_rxctl_rxdv, OPEN, OPEN, OPEN,
             phy_txd, phy_txctl_txen, '0', 
             phy_mdc, 
             phy_gtxclk,phy_gtxclk);

  end generate;

   iuerr : process
   begin
     wait for 210 us; -- This is for proper DDR3 behaviour durign init phase not needed durin simulation
     wait on led(3);  -- DDR3 Memory Init ready
     wait for 5000 ns;
     if to_x01(errorn) = '1' then wait on errorn; end if;
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
    switch(3) <= '0';
    wait for 2500 ns;
    wait for 210 us; -- This is for proper DDR3 behaviour durign init phase not needed durin simulation
    dsurst <= '1';
    switch(3) <= '1';
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

