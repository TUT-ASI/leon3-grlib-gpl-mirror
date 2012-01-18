-----------------------------------------------------------------------------
--  LEON3 Demonstration design test bench
--  Copyright (C) 2004 Jiri Gaisler, Gaisler Research
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
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
use gaisler.libdcom.all;
use gaisler.sim.all;
use gaisler.jtagtst.all;
library techmap;
use techmap.gencomp.all;
use work.debug.all;

use work.config.all;

entity testbench is
  generic (
    fabtech   		: integer := CFG_FABTECH;
    memtech   		: integer := CFG_MEMTECH;
    padtech   		: integer := CFG_PADTECH;
    disas     		: integer := CFG_DISAS;   				-- Enable disassembly to console
    dbguart   		: integer := CFG_DUART;   				-- Print UART on console
    pclow     		: integer := CFG_PCLOW;
    clkperiod 		: integer := 10            				-- system clock period (10ns)
    );
end;

architecture behav of testbench is
  constant promfile	: string := "prom.srec";        			-- rom contents
  constant sdramfile	: string := "sdram.srec";       			-- sdram contents

  constant lresp    	: boolean := false;
  constant ct		: integer := clkperiod / 2;

  signal clk		: std_logic := '0';
  signal clk200p	: std_logic := '1';
  signal clk200n	: std_logic := '0';
  signal rst_n		: std_logic := '0';
  signal rstn1		: std_logic;
  signal rstn2		: std_logic;
  signal errorn		: std_logic;

  signal dip_switch	: std_logic_vector(7 downto 0);
  signal seg14_led_out	: std_logic_vector(14 downto 0);

--only for running tests!!!
  signal address	: std_logic_vector(19 downto 0);
  signal data		: std_logic_vector(31 downto 0);
  signal mben		: std_logic_vector(3 downto 0);
  signal ramsn		: std_logic_vector(1 downto 0);
  signal oen		: std_ulogic;
  signal writen		: std_ulogic;

  -- Debug support unit
  signal dsubre     	: std_ulogic;
  signal dsuen		: std_ulogic;

  -- AHB DSU UART
  signal dsurx      	: std_ulogic;
  signal dsutx      	: std_ulogic;
  signal dsurst		: std_ulogic;

  -- APB Console UART1
  signal txd1   	: std_ulogic;
  signal rxd1   	: std_ulogic;
  -- simulation signals
  signal txd2   	: std_ulogic;
  signal rxd2   	: std_ulogic;

  -- Ethernet interface #1 signals
  signal eth_rstn	: std_ulogic;
  signal etx_clk    	: std_ulogic;
  signal erx_clk    	: std_ulogic;
  signal erxdt      	: std_logic_vector(7 downto 0);
  signal erx_dv     	: std_ulogic;
  signal erx_er     	: std_ulogic;
  signal erx_col    	: std_ulogic;
  signal erx_crs    	: std_ulogic;
  signal etxdt      	: std_logic_vector(7 downto 0);
  signal etx_en     	: std_ulogic;
  signal etx_er     	: std_ulogic;
  signal emdc       	: std_ulogic;
  signal emdio      	: std_logic;
  signal egtx_clk   	: std_logic;
  signal eth_clk125    	: std_ulogic := '0';

  -- Output signals for LEDs
  signal led       	: std_logic_vector(7 downto 0);

  signal brdyn     	: std_ulogic;

begin
  -- clock and reset
  clk <= not clk after ct * 1 ns;

  rst_n <= dsurst;
  dsuen <= '1';
  dsubre <= '0';

  clk200p <= not clk200p after 2.5 ns;
  clk200n <= not clk200n after 2.5 ns;

  eth_clk125 <= not eth_clk125 after 4 ns;

  rstn1 <= rst_n;

  -- AHB DSU UART's rx pulled high
  dsurx <= 'H';
  -- APB Console UART1's rx pulled high
  rxd1 <= 'H';

  DUT : entity work.leon3mp generic map (fabtech, memtech, padtech, disas, dbguart, pclow)
			    port map (reset_n		=> rst_n,
				      clk_in		=> clk,
--				      dip_switch	=> dip_switch,
				      errorn		=> errorn,
--only for running tests!!!
				      address		=> address(19 downto 2),
				      data		=> data(31 downto 0),
				      ramsn		=> ramsn,
				      mben		=> mben,
				      oen 		=> oen,
				      writen		=> writen,
				     -- Debug Unit
				      dsubre		=> dsubre,
				     -- DSU AHB UART interface
				      dsutx		=> dsutx,
				      dsurx		=> dsurx,
				     -- Console UART1 interface
				      rxd1		=> rxd1,
				      txd1		=> txd1,
				     -- ETH #1
				      rstn		=> eth_rstn,
				      mdio		=> emdio,
				      mdc		=> emdc,
				      rxc		=> erx_clk,
				      rx_er		=> erx_er,
				      rx_dv		=> erx_dv,
				      rx_d		=> erxdt(7 downto 0),
				      txc		=> etx_clk,
				      tx_en		=> etx_en,
				      tx_er		=> etx_er,
				      tx_d		=> etxdt(7 downto 0),
				      gtxclk		=> egtx_clk,
				      crs		=> erx_crs,
				      col		=> erx_col,
				      clk125		=> eth_clk125,

				      led 		=> led,
				      seg14_led_out	=> seg14_led_out
      );

  address(1 downto 0) <= "00";
  sram0 : for i in 0 to 1 generate
	sr0 : sram16 generic map (index => i * 2, abits => 18, fname => sdramfile)
		     port map (address(19 downto 2), data(31 - i * 16 downto 16 - i * 16), mben(i * 2 + 1), mben(i * 2), ramsn(i), writen, oen);
  end generate;

  phy1 : if (CFG_GRETH = 1) generate
		p0: phy generic map (address => 0)
			port map(rstn		=> eth_rstn,
				 mdio		=> emdio,
				 tx_clk		=> etx_clk,
				 rx_clk		=> erx_clk,
				 rxd		=> erxdt(7 downto 0),
				 rx_dv		=> erx_dv,
				 rx_er		=> erx_er,
				 rx_col		=> erx_col,
				 rx_crs		=> erx_crs,
				 txd		=> etxdt(7 downto 0),
				 tx_en		=> etx_en,
				 tx_er		=> etx_er,
				 mdc		=> emdc,
				 gtx_clk	=> egtx_clk);
  end generate;

  iuerr : process
  begin
    wait for 5000 ns;
    if to_x01(not errorn) = '0' then 
	wait on errorn; 
    end if;
    assert (to_x01(not errorn) = '0') 
       report "*** IU in error mode, simulation halted ***"
         severity failure ;
  end process;

  data <= buskeep(data), (others => 'H') after 250 ns;

  dsucom : process
    procedure dsucfg(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
    variable w32 : std_logic_vector(31 downto 0);
    variable c8  : std_logic_vector(7 downto 0);
    constant txp : time := 320 * 1 ns;
    begin
--    dsutx <= '1';
    dsurst <= '0';
    wait for 2500 ns;
    dsurst <= '1';
    wait;
    wait for 5000 ns;
    txc(dsutx, 16#55#, txp);		-- sync uart

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
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#0a#, 16#aa#, txp);
    txa(dsutx, 16#00#, 16#55#, 16#00#, 16#55#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#0a#, 16#a0#, txp);
    txa(dsutx, 16#01#, 16#02#, 16#09#, 16#33#, txp);

    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#00#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#2e#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#91#, 16#00#, 16#00#, 16#00#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#2e#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#20#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#0f#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#20#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#00#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#80#, 16#00#, 16#02#, 16#10#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#0f#, txp);

    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#91#, 16#40#, 16#00#, 16#24#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#24#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#91#, 16#70#, 16#00#, 16#00#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#03#, txp);

    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#20#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#ff#, 16#ff#, txp);

    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#40#, 16#00#, 16#48#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#12#, txp);

    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#40#, 16#00#, 16#60#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#12#, 16#10#, txp);

    txc(dsutx, 16#80#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#00#, txp);
    rxi(dsurx, w32, txp, lresp);

    txc(dsutx, 16#a0#, txp);
    txa(dsutx, 16#40#, 16#00#, 16#00#, 16#00#, txp);
    rxi(dsurx, w32, txp, lresp);
    end;

  begin
    dsucfg(txd2, rxd2);
    wait;
  end process;

end;

