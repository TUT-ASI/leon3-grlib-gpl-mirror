------------------------------------------------------------------------------
--  LEON3 Demonstration design test bench
--  Copyright (C) 2004 Jiri Gaisler, Gaisler Research
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015, Cobham Gaisler
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
library techmap;
use techmap.gencomp.all;
library micron;
use micron.components.all;
use work.debug.all;

use work.config.all;	-- configuration

entity testbench is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    ncpu      : integer := CFG_NCPU;
    disas     : integer := CFG_DISAS;	-- Enable disassembly to console
    dbguart   : integer := CFG_DUART;	-- Print UART on console
    pclow     : integer := CFG_PCLOW;

    clkperiod : integer := 20;		-- system clock period
    romdepth  : integer := 25;          -- rom address depth
    sramwidth  : integer := 32;         -- ram data width (8/16/32)
    sramdepth  : integer := 20;         -- ram address depth
    srambanks  : integer := 2           -- number of ram banks
  );
end; 

architecture behav of testbench is

constant promfile  : string := "prom.srec";  -- rom contents
constant sramfile  : string := "ram.srec";  -- ram contents
constant sdramfile : string := "ram.srec"; -- sdram contents

component leon3mp is
  generic (
    fabtech : integer := CFG_FABTECH;
    memtech : integer := CFG_MEMTECH;
    padtech : integer := CFG_PADTECH;
    disas   : integer := CFG_DISAS;     -- Enable disassembly to console
    dbguart : integer := CFG_DUART;     -- Print UART on console
    pclow   : integer := CFG_PCLOW
    );
  port (

--      --DDR3--
      DDR3_A		:	out	std_logic_vector(14 downto 0);
      DDR3_BA		:	out	std_logic_vector(2 downto 0);
      DDR3_CAS_n	:	out	std_logic;
      DDR3_CKE	:	out	std_logic; 
      DDR_CK_n	:	out	std_logic;
      DDR3_CK_p	:	out	std_logic;
      DDR3_CS_n	:	out	std_logic;
      DDR3_DM		:	out	std_logic_vector(3 downto 0);
      DDR3_DQ		:	inout	std_logic_vector(31 downto 0);
      DDR3_DQS_n	:	inout	std_logic_vector(3 downto 0);
      DDR3_DQS_p	:	inout	std_logic_vector(3 downto 0);
      DDR3_ODT	:	out	std_logic; 
      DDR3_RAS_n	:	out	std_logic;
      DDR3_RESET_n	:	out	std_logic;
      DDR3_RZQ	:	in	std_logic;
      DDR3_WE_n	:	out	std_logic;
--
--      --FAN CONTROL--
--      FAN_CTRL	:	out	std_logic;
--
--
--      --HPS--
      HPS_CONV_USB_n		:	inout	std_logic; --input              HPS_CONV_USB_n,
      HPS_DDR3_A		:	out	std_logic_vector(14 downto 0); --output      [14:0] HPS_DDR3_A,
      HPS_DDR3_BA		:	out	std_logic_vector(2 downto 0); --output      [2:0]  HPS_DDR3_BA,
      HPS_DDR3_CAS_n		:	out	std_logic; --output             HPS_DDR3_CAS_n,
      HPS_DDR3_CKE		:	out	std_logic; --output             HPS_DDR3_CKE,
      HPS_DDR3_CK_n		:	out	std_logic; --output             HPS_DDR3_CK_n,
      HPS_DDR3_CK_p		:	out	std_logic; --output             HPS_DDR3_CK_p,
      HPS_DDR3_CS_n		:	out	std_logic; --output             HPS_DDR3_CS_n,
      HPS_DDR3_DM		:	out	std_logic_vector(3 downto 0); --output      [3:0]  HPS_DDR3_DM,
      HPS_DDR3_DQ		:	inout	std_logic_vector(31 downto 0); --inout       [31:0] HPS_DDR3_DQ,
      HPS_DDR3_DQS_n		:	inout	std_logic_vector(3 downto 0); --inout       [3:0]  HPS_DDR3_DQS_n,
      HPS_DDR3_DQS_p		:	inout	std_logic_vector(3 downto 0); --inout       [3:0]  HPS_DDR3_DQS_p,
      HPS_DDR3_ODT		:	out	std_logic; --output             HPS_DDR3_ODT,
      HPS_DDR3_RAS_n		:	out	std_logic; --output             HPS_DDR3_RAS_n,
      HPS_DDR3_RESET_n	:	out	std_logic; --output             HPS_DDR3_RESET_n,
      HPS_DDR3_RZQ		:	in	std_logic; --input              HPS_DDR3_RZQ,
      HPS_DDR3_WE_n		:	out	std_logic; --output             HPS_DDR3_WE_n,
      HPS_ENET_GTX_CLK	:	out	std_logic; --output             HPS_ENET_GTX_CLK,
      HPS_ENET_INT_n		:	inout	std_logic; --inout              HPS_ENET_INT_n,
      HPS_ENET_MDC		:	out	std_logic; --output             HPS_ENET_MDC,
      HPS_ENET_MDIO		:	inout	std_logic; --inout              HPS_ENET_MDIO,
      HPS_ENET_RX_CLK		:	in	std_logic; --input              HPS_ENET_RX_CLK,
      HPS_ENET_RX_DATA	:	in	std_logic_vector(3 downto 0); --input       [3:0]  HPS_ENET_RX_DATA,
      HPS_ENET_RX_DV		:	in	std_logic; --input              HPS_ENET_RX_DV,
      HPS_ENET_TX_DATA	:	out	std_logic_vector(3 downto 0); --output      [3:0]  HPS_ENET_TX_DATA,
      HPS_ENET_TX_EN		:	out	std_logic; --output             HPS_ENET_TX_EN,
      HPS_FLASH_DATA		:	inout	std_logic_vector(3 downto 0); --inout       [3:0]  HPS_FLASH_DATA,
      HPS_FLASH_DCLK		:	out	std_logic; --output             HPS_FLASH_DCLK,
      HPS_FLASH_NCSO		:	out	std_logic; --output             HPS_FLASH_NCSO,
      HPS_GSENSOR_INT		:	inout	std_logic; --inout              HPS_GSENSOR_INT,
      HPS_I2C_CLK		:	inout	std_logic; --inout              HPS_I2C_CLK,
      HPS_I2C_SDA		:	inout	std_logic; --inout              HPS_I2C_SDA,
--      HPS_KEY			:	inout	std_logic_vector(3 downto 0); --inout       [3:0]  HPS_KEY,
      HPS_LCM_BK		:	inout	std_logic; --inout              HPS_LCM_BK,
      HPS_LCM_D_C		:	inout	std_logic; --output             HPS_LCM_D_C,
      HPS_LCM_RST_N		:	inout	std_logic; --output             HPS_LCM_RST_N,
      HPS_LCM_SPIM_CLK	:	out	std_logic; --input              HPS_LCM_SPIM_CLK,
      HPS_LCM_SPIM_MOSI	:	out	std_logic; --output             HPS_LCM_SPIM_MOSI,
      HPS_LCM_SPIM_SS		:	out	std_logic; --output             HPS_LCM_SPIM_SS,
      HPS_LCM_SPIM_MISO : in    std_logic;
      HPS_LED			:	inout	std_logic_vector(3 downto 0); --output      [3:0]  HPS_LED,
      HPS_LTC_GPIO		:	inout	std_logic; --inout              HPS_LTC_GPIO,
      HPS_SD_CLK		:	out	std_logic; --output             HPS_SD_CLK,
      HPS_SD_CMD		:	inout	std_logic; --inout              HPS_SD_CMD,
      HPS_SD_DATA		:	inout	std_logic_vector(3 downto 0); --inout       [3:0]  HPS_SD_DATA,
      HPS_SPIM_CLK		:	out	std_logic; --output             HPS_SPIM_CLK,
      HPS_SPIM_MISO		:	in	std_logic; --input              HPS_SPIM_MISO,
      HPS_SPIM_MOSI		:	out	std_logic; --output             HPS_SPIM_MOSI,
      HPS_SPIM_SS		:	out	std_logic; --output             HPS_SPIM_SS,
--     HPS_SW			:	in	std_logic_vector(3 downto 0); --input       [3:0]  HPS_SW,
      HPS_UART_RX		:	in	std_logic; --input              HPS_UART_RX,
      HPS_UART_TX		:	out	std_logic; --output             HPS_UART_TX,
      HPS_USB_CLKOUT		:	in	std_logic; --input              HPS_USB_CLKOUT,
      HPS_USB_DATA		:	inout	std_logic_vector(7 downto 0); --inout       [7:0]  HPS_USB_DATA,
      HPS_USB_DIR		:	in	std_logic; --input              HPS_USB_DIR,
      HPS_USB_NXT		:	in	std_logic; --input              HPS_USB_NXT,
      HPS_USB_STP		:	out	std_logic; --output             HPS_USB_STP,
--
--      --Audio--
--      AUD_ADCDAT		:	in	std_logic; --input              AUD_ADCDAT,
--      AUD_ADCLRCK		:	inout	std_logic; --inout              AUD_ADCLRCK,
--      AUD_BCLK		:	inout	std_logic; --inout              AUD_BCLK,
--      AUD_DACDAT		:	out	std_logic; --output             AUD_DACDAT,
--      AUD_DACLRCK		:	inout	std_logic; --inout              AUD_DACLRCK,
--      AUD_I2C_SCLK		:	out	std_logic; --output             AUD_I2C_SCLK,
--      AUD_I2C_SDAT		:	inout	std_logic; --inout              AUD_I2C_SDAT,
--      AUD_MUTE		:	out	std_logic; --output             AUD_MUTE,
--      AUD_XCK			:	out	std_logic; --output             AUD_XCK,
--
--      --HSMC--
--      HSMC_CLKIN_n		:	in		std_logic_vector(2 downto 1); --input       [2:1]  HSMC_CLKIN_n,
--      HSMC_CLKIN_p		:	in		std_logic_vector(2 downto 1); --input       [2:1]  HSMC_CLKIN_p,
--      HSMC_CLKOUT_n		:	out	std_logic_vector(2 downto 1); --output      [2:1]  HSMC_CLKOUT_n,
--      HSMC_CLKOUT_p		:	out	std_logic_vector(2 downto 1); --output      [2:1]  HSMC_CLKOUT_p,
--      HSMC_CLK_IN0		:	out	std_logic; --output             HSMC_CLK_IN0,
--      HSMC_CLK_OUT0		:	out	std_logic; --output             HSMC_CLK_OUT0,
--      HSMC_D			:	inout	std_logic_vector(3 downto 0); --inout       [3:0]  HSMC_D,
--      HSMC_GXB_RX_p		:	in		std_logic_vector(7 downto 0); --input       [7:0]  HSMC_GXB_RX_p,
--      HSMC_GXB_TX_p		:	out	std_logic_vector(7 downto 0); --output      [7:0]  HSMC_GXB_TX_p,
--      HSMC_REF_CLK_p		:	in		std_logic; --input              HSMC_REF_CLK_p,
--      HSMC_RX_n		:	inout	std_logic_vector(16 downto 0); --inout       [16:0] HSMC_RX_n,
--      HSMC_RX_p		:	inout	std_logic_vector(16 downto 0); --inout       [16:0] HSMC_RX_p,
--      HSMC_SCL		:	out	std_logic; --output             HSMC_SCL,
--      HSMC_SDA		:	inout	std_logic; --inout              HSMC_SDA,
--      HSMC_TX_n		:	inout	std_logic_vector(16 downto 0); --inout       [16:0] HSMC_TX_n,
--      HSMC_TX_p		:	inout	std_logic_vector(16 downto 0); --inout       [16:0] HSMC_TX_p,
--
--      --IRDA--
--      IRDA_RXD		:	in	std_logic; --input              IRDA_RXD,
--
--      --PCIE--
--      PCIE_PERST_n		:	in	std_logic; --input              PCIE_PERST_n,
--      PCIE_WAKE_n		:	out	std_logic; --output             PCIE_WAKE_n,
--
--      --SI5338--
--      SI5338_SCL		:	in	std_logic; --inout              SI5338_SCL,
--      SI5338_SDA		:	in	std_logic; --inout              SI5338_SDA,
--
--      --TEMP--
--      TEMP_CS_n		:	out	std_logic; --output             TEMP_CS_n,
--      TEMP_DIN		:	out	std_logic; --output             TEMP_DIN,
--      TEMP_DOUT		:	in	std_logic; --input              TEMP_DOUT,
--      TEMP_SCLK		:	out	std_logic; --output             TEMP_SCLK,
--
--      --USB--
--      USB_B2_CLK		:	in	std_logic; --input              USB_B2_CLK,
--      USB_B2_DATA		:	inout	std_logic_vector(7 downto 0); --inout       [7:0]  USB_B2_DATA,
--      USB_EMPTY		:	out	std_logic; --output             USB_EMPTY,
--      USB_FULL		:	out	std_logic; --output             USB_FULL,
--      USB_OE_n		:	in	std_logic; --input              USB_OE_n,
--      USB_RD_n		:	in	std_logic; --input              USB_RD_n,
--      USB_RESET_n		:	in	std_logic; --input              USB_RESET_n,
--      USB_SCL			:	inout	std_logic; --inout              USB_SCL,
--      USB_SDA			:	inout	std_logic; --inout              USB_SDA,
--      USB_WR_n		:	in	std_logic; --input              USB_WR_n,
--
--      --VGA--
--      VGA_B			    :	out	std_logic_vector(7 downto 0); --output      [7:0]  VGA_B,
--      VGA_BLANK_n		:	out	std_logic; --output             VGA_BLANK_n,
--      VGA_CLK			  :	out	std_logic; --output             VGA_CLK,
--      VGA_G			    :	out	std_logic_vector(7 downto 0); --output      [7:0]  VGA_G,
--      VGA_HS			  :	out	std_logic; --output             VGA_HS,
--      VGA_R			    :	out	std_logic_vector(7 downto 0); --output      [7:0]  VGA_R,
--      VGA_SYNC_n		:	out	std_logic; --output             VGA_SYNC_n,
--      VGA_VS			  :	out	std_logic; --output             VGA_VS
		
		--OSC (CLOCKS)--
      OSC_50_B3B		:	in	std_logic; --input              OSC_50_B3B,
      OSC_50_B4A		:	in	std_logic; --input              OSC_50_B4A,
      OSC_50_B5B		:	in	std_logic; --input              OSC_50_B5B,
      OSC_50_B8A		:	in	std_logic; --input              OSC_50_B8A,
		
      --RESET--
      RESET_n			:	in	std_logic; --input              RESET_n,
		
      --KEY (PUSHBUTTONS)--
      KEY			:	in	std_logic_vector(3 downto 0); --input       [3:0]  KEY,

      --LED--
      LED			:	out	std_logic_vector(3 downto 0); --output      [3:0]  LED,
		
		--SW (SWITCHES)--
      SW			:	in	std_logic_vector(3 downto 0) --input       [3:0]  SW,
    );
end component;

signal clk50, clkout: std_ulogic := '0';
signal rst: std_ulogic;
signal user_led: std_logic_vector(3 downto 0);

signal address  : std_logic_vector(26 downto 1);
signal data     : std_logic_vector(15 downto 0);

signal ramsn    : std_ulogic;
signal ramoen   : std_ulogic;
signal rwen     : std_ulogic;
signal mben     : std_logic_vector(3 downto 0);
--signal rwenx    : std_logic_vector(3 downto 0);
signal romsn    : std_logic;
signal iosn     : std_ulogic;
signal oen      : std_ulogic;
--signal read     : std_ulogic;
signal writen   : std_ulogic;
signal brdyn    : std_ulogic;
signal bexcn    : std_ulogic;
signal wdog     : std_ulogic;
signal dsuen, dsutx, dsurx, dsubren, dsuact : std_ulogic;
signal dsurst   : std_ulogic;
signal test     : std_ulogic;
signal error    : std_logic;
signal gpio	: std_logic_vector(7 downto 0);
signal GND      : std_ulogic := '0';
signal VCC      : std_ulogic := '1';
signal NC       : std_ulogic := 'Z';
signal clk2     : std_ulogic := '1';
    
signal plllock    : std_ulogic;       
signal txd1, rxd1 : std_ulogic;
  

constant lresp : boolean := false;

begin

-- clock and reset

  clk50 <= not clk50 after 20 ns;

  rst <= dsurst;
  dsubren <= '1'; rxd1 <= '1';

  d3 : leon3mp
    generic map ( fabtech, memtech, padtech, disas, dbguart, pclow )
    port map (

      DDR3_A        => open,
      DDR3_BA       => open,
      DDR3_CAS_n    => open,
      DDR3_CKE      => open,
      DDR_CK_n      => open,
      DDR3_CK_p     => open,
      DDR3_CS_n     => open,
      DDR3_DM       => open,
      DDR3_DQ       => open,
      DDR3_DQS_n    => open,
      DDR3_DQS_p    => open,
      DDR3_ODT      => open,
      DDR3_RAS_n    => open,
      DDR3_RESET_n  => open,
      DDR3_RZQ      => '0',
      DDR3_WE_n     => open,

      HPS_CONV_USB_n      => open,
      HPS_DDR3_A          => open,
      HPS_DDR3_BA         => open,
      HPS_DDR3_CAS_n      => open,
      HPS_DDR3_CKE        => open,
      HPS_DDR3_CK_n       => open,
      HPS_DDR3_CK_p       => open,
      HPS_DDR3_CS_n       => open,
      HPS_DDR3_DM         => open,
      HPS_DDR3_DQ         => open,
      HPS_DDR3_DQS_n      => open,
      HPS_DDR3_DQS_p      => open,
      HPS_DDR3_ODT        => open,
      HPS_DDR3_RAS_n      => open,
      HPS_DDR3_RESET_n    => open,
      HPS_DDR3_RZQ        => '0',
      HPS_DDR3_WE_n       => open,
      HPS_ENET_GTX_CLK    => open,
      HPS_ENET_INT_n      => open,
      HPS_ENET_MDC        => open,
      HPS_ENET_MDIO       => open,
      HPS_ENET_RX_CLK     => '0',
      HPS_ENET_RX_DATA    => (others => '0'),
      HPS_ENET_RX_DV      => '0',
      HPS_ENET_TX_DATA    => open,
      HPS_ENET_TX_EN      => open,
      HPS_FLASH_DATA      => open,
      HPS_FLASH_DCLK      => open,
      HPS_FLASH_NCSO      => open,
      HPS_GSENSOR_INT     => open,
      HPS_I2C_CLK         => open,
      HPS_I2C_SDA         => open,
      HPS_LCM_BK          => open,
      HPS_LCM_D_C         => open,
      HPS_LCM_RST_N       => open,
      HPS_LCM_SPIM_CLK    => open,
      HPS_LCM_SPIM_MOSI   => open,
      HPS_LCM_SPIM_SS     => open,
      HPS_LCM_SPIM_MISO   => '0',
      HPS_LED             => open,
      HPS_LTC_GPIO        => open,
      HPS_SD_CLK          => open,
      HPS_SD_CMD          => open,
      HPS_SD_DATA         => open,
      HPS_SPIM_CLK        => open,
      HPS_SPIM_MISO       => '0',
      HPS_SPIM_MOSI       => open,
      HPS_SPIM_SS         => open,
      HPS_UART_RX         => '0',
      HPS_UART_TX         => open,
      HPS_USB_CLKOUT      => '0',
      HPS_USB_DATA        => open,
      HPS_USB_DIR         => '0',
      HPS_USB_NXT         => '0',
      HPS_USB_STP         => open,

      OSC_50_B3B => clk50,
      OSC_50_B4A => clk50,
      OSC_50_B5B => clk50,
      OSC_50_B8A => clk50,
      
      --RESET--
      RESET_n => rst,
		
      --KEY (PUSHBUTTONS)--
      KEY => "0000",

      --LED--
      LED => user_led,
		
	--SW (SWITCHES)--
      SW => "1111"
    );

  -- 16 bit prom
  prom0 : sram16 generic map (index => 4, abits => romdepth, fname => promfile)
	port map (address(romdepth downto 1), data, 
		  romsn, romsn, romsn, rwen, oen);

  data <= buskeep(data), (others => 'H') after 250 ns;

  error <= user_led(3);

   iuerr : process
   begin
     wait for 2500 ns;
     if to_x01(error) = '1' then wait on error; end if;
     assert (to_x01(error) = '1') 
       report "*** IU in error mode, simulation halted ***"
         severity failure ;
   end process;

  test0 :  grtestmod generic map (width => 16)
    port map ( rst, clk50, error, address(21 downto 2), data,
    	       iosn, oen, writen, brdyn);

  dsucom : process
    procedure dsucfg(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
    variable w32 : std_logic_vector(31 downto 0);
    variable c8  : std_logic_vector(7 downto 0);
    constant txp : time := 160 * 1 ns;
    begin
    dsutx <= '1';
    dsurst <= '0';
    wait for 500 ns;
    dsurst <= '1';
    wait;
    wait for 5000 ns;
    txc(dsutx, 16#55#, txp);		-- sync uart

--    txc(dsutx, 16#c0#, txp);
--    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#00#, txp);
--    txa(dsutx, 16#00#, 16#00#, 16#02#, 16#ae#, txp);
--    txc(dsutx, 16#c0#, txp);
--    txa(dsutx, 16#91#, 16#00#, 16#00#, 16#00#, txp);
--    txa(dsutx, 16#00#, 16#00#, 16#06#, 16#ae#, txp);
--    txc(dsutx, 16#c0#, txp);
--    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#24#, txp);
--    txa(dsutx, 16#00#, 16#00#, 16#06#, 16#03#, txp);
--    txc(dsutx, 16#c0#, txp);
--    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#20#, txp);
--    txa(dsutx, 16#00#, 16#00#, 16#06#, 16#fc#, txp);

    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#00#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#2f#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#91#, 16#00#, 16#00#, 16#00#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#6f#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#11#, 16#00#, 16#00#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#00#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#40#, 16#00#, 16#04#, txp);
    txa(dsutx, 16#00#, 16#02#, 16#20#, 16#01#, txp);
    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#20#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#02#, txp);

    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#90#, 16#00#, 16#00#, 16#20#, txp);
    txa(dsutx, 16#00#, 16#00#, 16#00#, 16#0f#, txp);

    txc(dsutx, 16#c0#, txp);
    txa(dsutx, 16#40#, 16#00#, 16#43#, 16#10#, txp);
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

    dsucfg(dsutx, dsurx);

    wait;
  end process;
end ;

