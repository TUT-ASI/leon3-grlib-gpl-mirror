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
--------------------------------------------------------------------------------
-- LEON5 Xilinx KCU105 Design Testbench
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library gaisler;
use gaisler.libdcom.all;
use gaisler.sim.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;
library work;
use work.debug.all;
use work.config.all;

entity testbench is
  generic(
    fabtech : integer := CFG_FABTECH;
    memtech : integer := CFG_MEMTECH;
    padtech : integer := CFG_PADTECH;
    disas   : integer := CFG_DISAS;      -- Enable disassembly to console
    clkperiod : integer := 8           -- oscillator clock period - 125MHz
    );
end;

architecture behav of testbench is

  -----------------------------------------------------
  -- Constant -----------------------------------------
  -----------------------------------------------------

  constant promfile     : string := "prom.srec"; -- rom contents
  constant ct           : integer := clkperiod/2;

  -----------------------------------------------------
  -- Signals ------------------------------------------
  -----------------------------------------------------

  signal clk_in         : std_logic := '0';
  signal system_rst     : std_ulogic;

  signal gnd            : std_ulogic := '0';
  signal vcc            : std_ulogic := '1';
  signal nc             : std_ulogic := 'Z';

  signal clk300p        : std_ulogic := '0';
  signal clk300n        : std_ulogic := '1';
  signal clk125p        : std_ulogic := '0';
  signal clk125n        : std_ulogic := '1';

  signal txd1           : std_ulogic;
  signal rxd1           : std_ulogic;
  signal ctsn1          : std_ulogic;
  signal rtsn1          : std_ulogic;

  signal switch         : std_logic_vector(3 downto 0);
  signal gpio           : std_logic_vector(15 downto 0);
  signal led            : std_logic_vector(7 downto 0);
  signal button         : std_logic_vector(4 downto 0);

  -- DSU UART
  signal dsutx          : std_ulogic;
  signal dsurx          : std_ulogic;
  signal dsuctsn        : std_ulogic;
  signal dsurtsn        : std_ulogic;

  -- Testbench Related Signals
  signal dsurst         : std_ulogic;
  signal errorn         : std_logic;

begin

  -----------------------------------------------------
  -- Clocks and Reset ---------------------------------
  -----------------------------------------------------

  clk_in        <= not clk_in after ct * 1 ns;
  system_rst    <= '1', '0' after 200 ns;

  -----------------------------------------------------
  -- Misc ---------------------------------------------
  -----------------------------------------------------

  errorn                <= 'H'; -- ERROR pull-up
  errorn <= led(5);
  switch(2 downto 0)    <= (others => '0');
  button                <= (others => '0');
  gpio                  <= (others => 'Z');

  dsurx <= 'H'; dsuctsn <= 'H';

  -----------------------------------------------------
  -- Top ----------------------------------------------
  -----------------------------------------------------

  cpu : entity work.leon5mp
    generic map (
      fabtech              => fabtech,
      memtech              => memtech,
      padtech              => padtech,
      disas                => disas,
      ahbtrace             => CFG_AHBTRACE,
      simulation           => true,
      autonegotiation      => 0
    )
    port map(
      reset             => system_rst,
      clk_in            => clk_in,
      switch            => switch,
      led               => led,
      gpio              => gpio,
      dsurx             => dsurx,
      dsutx             => dsutx,
      dsuctsn           => dsuctsn,
      dsurtsn           => dsurtsn,
      button            => button
    );

  -----------------------------------------------------
  -- Process ------------------------------------------
  -----------------------------------------------------

  iuerr : process
  begin
    wait for 500000 ns;
    if to_x01(errorn) = '1' then
      wait on errorn;
    end if;
    assert (to_x01(errorn) = '1')
      report "*** IU in error mode, simulation halted ***"
      severity failure;			-- this should be a failure
  end process;

  -- dsucom : process

  --  procedure dsucfg(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
  --    variable w32   : std_logic_vector(31 downto 0);
  --    variable w64   : std_logic_vector(63 downto 0);
  --    variable c8    : std_logic_vector(7 downto 0);

  --    constant txp   : time := 160 * 1 ns;
  --    constant lresp : boolean := false;

  --  begin

  --    Print("dsucom process starts here");
  --    -- add here if needed....

  --  end;

  -- begin
  --  dsuctsn <= '0';
  --  dsucfg(dsutx, dsurx);
  --  wait;
  -- end process;

end;
