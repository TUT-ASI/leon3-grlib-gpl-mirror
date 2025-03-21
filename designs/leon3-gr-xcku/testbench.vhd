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

library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.libdcom.all;
use gaisler.sim.all;
library micron;
use micron.components.all;

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
    clktech : integer := CFG_CLKTECH;
    disas   : integer := CFG_DISAS; -- Enable disassembly to console
    dbguart : integer := CFG_DUART; -- Print UART on console
    pclow   : integer := CFG_PCLOW
  );
end;

architecture behav of testbench is

  constant promfile  : string := "prom.srec"; -- rom contents
  constant ramfile   : string := "ram.srec"; -- ram contents
  constant sdramfile : string := "ram.srec"; -- sdram contents --same as sram contents

  signal clk : std_logic := '0';
  signal Rst : std_logic := '0';

  signal address        : std_logic_vector(21 downto 0);
  signal data           : std_logic_vector(31 downto 0);
  signal button         : std_logic_vector(3 downto 0) := "0000";
  signal genio          : std_logic_vector(59 downto 0);
  signal romsn, ram_csn : std_logic;
  signal ram_oen        : std_ulogic;
  signal ram_wen        : std_logic;  --_vector(3 downto 0);
  signal oen            : std_ulogic;
  signal writen         : std_ulogic;

  signal GND : std_ulogic := '0';
  signal VCC : std_ulogic := '1';
  signal NC  : std_ulogic := 'Z';

  signal txd1, rxd1, dsurx, dsutx : std_logic;

  signal clk200p : std_ulogic := '0';

  signal dsurst : std_ulogic;
  signal errorn : std_logic := '0';

  signal sd_cke  : std_ulogic;        -- clk en
  signal sd_csn  : std_ulogic;        -- chip sel
  signal sd_wen  : std_ulogic;        -- write en
  signal sd_rasn : std_ulogic;        -- row addr stb
  signal sd_casn : std_ulogic;        -- col addr stb
  signal sd_dqm  : std_logic_vector(3 downto 0); -- data i/o mask
  signal sd_clks : std_logic_vector(2 downto 0);
  signal sd_addr : std_logic_vector(12 downto 0);
  signal sd_data : std_logic_vector(31 downto 0);
  signal sd_ba   : std_logic_vector(1 downto 0);

  signal spi_miso : std_ulogic;
  signal spi_mosi : std_ulogic;
  signal spi_sel  : std_logic_vector(2 downto 0);
  signal spi_sck  : std_ulogic;
  

  signal switch  : std_logic_vector(7 downto 0);
  signal gpio    : std_logic_vector(15 downto 0);
  signal led     : std_logic_vector(9 downto 0);
begin
  ---- clock and reset
  clk200p <= not clk200p after 10 ns;
  rst     <= '1', '0' after 50 ns;
  errorn  <= not (led(8));
  errorn  <= 'H';	-- ERROR pull-up
  ---- DSU and APB UART receive
  rxd1  <= 'H';
  dsurx <= 'H';

  cpu : entity work.leon3mp
    generic map(
      fabtech                 => fabtech,
      memtech                 => memtech,
      padtech                 => padtech,
      clktech                 => clktech,
      disas                   => disas,
      dbguart                 => dbguart,
      pclow                   => pclow
    )
    port map(
      reset        => rst,
      CLK_EXT_XTAL => clk200p,
      sr_add       => address,
      sr_data      => data,
      rom_oen      => oen,
      rom_wen      => writen,
      rom_csn      => romsn,
      sr_csn0      => ram_csn,
      sr_oen       => ram_oen,
      sr_wen       => ram_wen,
      sd_add       => sd_addr,
      sd_data      => sd_data,
      sd_ba        => sd_ba,
      sd_csn       => sd_csn,
      sd_casn      => sd_casn,
      sd_rasn      => sd_rasn,
      sd_wen       => sd_wen,
      sd_dqm       => sd_dqm,
      sd_cke       => sd_cke,
      sd_clk       => sd_clks,
      sd_clkfb     => sd_clks,
      dsu_in       => dsurx,
      dsu_out      => dsutx,
      uart_in      => rxd1,
      uart_ou      => txd1,
      spi_miso     => spi_miso, 
      spi_mosi     => spi_mosi,
      spi_sel      => spi_sel,
      spi_sck      => spi_sck, 
      gpio         => gpio,
      switch       => switch,
      led          => led
    );

    -------SDRAM Sim*-----------------
  sd1 : if ((CFG_MCTRL_SDEN = 1) and (CFG_MCTRL_SEPBUS = 1)) generate
    u0 : mt48lc16m16a2
      generic map(index => 0, fname => sdramfile)
      PORT MAP(
        Dq    => sd_data(31 downto 16), Addr => sd_addr(12 downto 0),
        Ba    => sd_ba, Clk => sd_clks(0), Cke => sd_cke,
        Cs_n  => sd_csn, Ras_n => sd_rasn, Cas_n => sd_casn, We_n => sd_wen,
        Dqm   => sd_dqm(3 downto 2));
    u1 : mt48lc16m16a2
      generic map(index => 16, fname => sdramfile)
      PORT MAP(
        Dq    => sd_data(15 downto 0), Addr => sd_addr(12 downto 0),
        Ba    => sd_ba, Clk => sd_clks(0), Cke => sd_cke,
        Cs_n  => sd_csn, Ras_n => sd_rasn, Cas_n => sd_casn, We_n => sd_wen,
        Dqm   => sd_dqm(1 downto 0));

  end generate;

  -------SRAM Sim*-----------------
  sr1 : if (CFG_MCTRL_SDEN = 0) generate
    ram0 : for i in 0 to 3 generate
      sr0 : sram
        generic map(index => i, abits => 22, fname => ramfile)
        port map(address(21 downto 0), data(31 - i*8 downto 24 - i*8), ram_csn,
                 ram_wen, ram_oen);
    end generate;
  end generate;

  -------PROM Sim*-----------------

  prom0 : for i in 0 to 3 generate
    pr0 : sram
      generic map(index => i, abits => 22, fname => promfile)
      port map(address(21 downto 0), data(31 - i*8 downto 24 - i*8), romsn,
               writen, oen);
  end generate;

  iuerr : process
  begin
    wait for 5000 ns;
    if to_x01(errorn) = '1' then
      wait on errorn;
    end if;
    assert (to_x01(errorn) = '1')
      report "*** IU in error mode, simulation halted ***"
      severity failure;			-- this should be a failure
  end process;

end;

