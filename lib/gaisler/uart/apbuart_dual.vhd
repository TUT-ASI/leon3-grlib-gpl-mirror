------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
-----------------------------------------------------------------------------
-- Entity:      uart_dual
-- File:        uart_dual.vhd
-- Authors:     Francisco Bas
-- Description: Both apbuart and apbuart16550 are implemented. --FB TODO
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.uart.all;


entity apbuart_dual is
  generic (
    pindex   : integer := 0;
    paddr    : integer := 0;
    pmask    : integer := 16#fff#;
    console  : integer := 0;
    pirq     : integer := 0;
    flow     : integer := 1;
    abits    : integer := 8;
    -- APBUART
    parity   : integer := 1;
    fifosize : integer range 1 to 32 := 1;
    sbits    : integer range 12 to 32 := 12;
    -- 16550 APBUART
    fifomode   : integer := 1;
    sbits16550 : integer range 12 to 16 := 16);
  port (
    rst    : in  std_ulogic;
    clk    : in  std_ulogic;
    apbi   : in  apb_slv_in_type;
    apbo   : out apb_slv_out_type;
    uarti  : in  uart_in_type;
    uarto  : out uart_out_type);
end;

architecture rtl of apbuart_dual is

  constant OFFSET16550    : integer := 16#40#;
  constant ADDR_SEL_BIT   : integer := log2(OFFSET16550);
  constant ADDR_MASK16650 : std_logic_vector(31 downto 0) := conv_std_logic_vector(OFFSET16550-1, 32);

  signal lapbi, lapbi16550   : apb_slv_in_type;
  signal lapbo, lapbo16550   : apb_slv_out_type;
  signal luarti, luarti16550 : uart_in_type;
  signal luarto, luarto16550 : uart_out_type;

begin

  -- When APBUART Transmitter is enabled we select the APBUART
  -- When APBUART Transmitter is disabled we select the APBUART16550
  -- OFFSET 0x00 --> APBUART
  -- OFFSET 0x40 --> APBUART16550
  process(apbi, lapbo, lapbo16550, uarti, luarto, luarto16550) is --TODO check
    variable apbsel  : std_ulogic;
    variable uartsel : std_ulogic;
  begin
    apbsel  := apbi.paddr(ADDR_SEL_BIT);   -- 0 -> APBUART; 1 -> APBUART16550
    uartsel := luarto.txen or luarto.rxen; -- 1 -> APBUART; 0 -> PABUART16550
    -- APBUART inputs
    lapbi              <= apbi;
    lapbi.psel(pindex) <= apbi.psel(pindex) and not apbsel;
    -- APBUART16550 inputs
    lapbi16550               <= apbi;
    lapbi16550.psel(pindex)  <= apbi.psel(pindex) and apbi.paddr(ADDR_SEL_BIT);
    lapbi16550.paddr         <= apbi.paddr and ADDR_MASK16650;
    -- APB Outputs
    if apbsel = '0' then
      apbo <= lapbo;
    else
      apbo <= lapbo16550;
    end if;
    -- PnP Devide ID is APBUART
    apbo.pconfig <= lapbo.pconfig;
    -- UART Muxing
    if uartsel = '1' then
      -- Select APBUART
      uarto            <= luarto;
      luarti           <= uarti;
      apbo.pirq        <= lapbo.pirq;
      -- Tie APBUART16550 inputs
      luarti16550.rxd  <= '1';
      luarti16550.ctsn <= '0';
    else
      -- Select APBUART16550
      uarto            <= luarto16550;
      luarti16550      <= uarti;
      apbo.pirq        <= lapbo16550.pirq;
      -- Tie APBUART inputs
      luarti.rxd       <= '1';
      luarti.ctsn      <= '0';
    end if;
    -- Drive external clock for both UARTs
    luarti.extclk      <= uarti.extclk;
    luarti16550.extclk <= uarti.extclk;
  end process;

  apbuart0: apbuart
    generic map (
      pindex   => pindex,
      paddr    => paddr,
      pmask    => pmask,
      console  => console,
      pirq     => pirq,
      parity   => parity,
      flow     => flow,
      fifosize => fifosize,
      abits    => abits,
      sbits    => sbits,
      dual     => 1
      )
    port map (
      rst   => rst,
      clk   => clk,
      apbi  => lapbi,
      apbo  => lapbo,
      uarti => luarti,
      uarto => luarto
      );

  apbuart16550: apbuart_16550
    generic map (
      pindex   => pindex,
      paddr    => paddr,
      pmask    => pmask,
      console  => console,
      pirq     => pirq,
      flow     => flow,
      fifomode => fifomode,
      abits    => abits,
      sbits    => sbits16550
      )
    port map (
      rst   => rst,
      clk   => clk,
      apbi  => lapbi16550,
      apbo  => lapbo16550,
      uarti => luarti16550,
      uarto => luarto16550
      );

end;