-----------------------------------------------------------------------------
--  LEON3 Demonstration design test bench
--  Copyright (C) 2004 Jiri Gaisler, Gaisler Research
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
library micron;
use micron.components.all;
use work.debug.all;

use work.config.all;

entity testbench is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    clktech   : integer := CFG_CLKTECH;
    disas     : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart   : integer := CFG_DUART;   -- Print UART on console
    pclow     : integer := CFG_PCLOW;
    clkperiod : integer := 37            -- system clock period
    );
end;

architecture behav of testbench is
  constant promfile  : string  := "prom.srec";        -- rom contents
  constant sdramfile : string  := "ram.srec";       -- sdram contents

  constant lresp    : boolean := false;
  constant ct       : integer := clkperiod/2;

  signal clk        : std_logic := '0';
  signal clk200p    : std_logic := '1';
  signal clk200n    : std_logic := '0';
  signal rst        : std_logic := '0';
  signal rstn1      : std_logic;
  signal rstn2      : std_logic;
  signal error      : std_logic;

  -- PROM flash
  signal address    : std_logic_vector(23 downto 0);
  signal data       : std_logic_vector(31 downto 0);
  signal romsn      : std_logic;
  signal oen        : std_ulogic;
  signal writen     : std_ulogic;
  signal iosn       : std_ulogic;

  -- DDR2 memory
  signal ddr_clk    : std_logic;
  signal ddr_clkb   : std_logic;
  signal ddr_clk_fb : std_logic;
  signal ddr_cke    : std_logic;
  signal ddr_csb    : std_logic := '0';
  signal ddr_we     : std_ulogic;                       -- write enable
  signal ddr_ras    : std_ulogic;                       -- ras
  signal ddr_cas    : std_ulogic;                       -- cas
  signal ddr_dm     : std_logic_vector(1 downto 0);     -- dm
  signal ddr_dqs    : std_logic_vector(1 downto 0);     -- dqs
  signal ddr_dqsn   : std_logic_vector(1 downto 0);     -- dqsn
  signal ddr_ad     : std_logic_vector(12 downto 0);    -- address
  signal ddr_ba     : std_logic_vector(2 downto 0);     -- bank address
  signal ddr_dq     : std_logic_vector(15 downto 0);    -- data
  signal ddr_dq2    : std_logic_vector(15 downto 0);    -- data
  signal ddr_odt    : std_logic;
  signal ddr_rzq    : std_logic;
  signal ddr_zio    : std_logic;
  
  -- Debug support unit
  signal dsubre     : std_ulogic;

  -- AHB Uart
  signal dsurx      : std_ulogic;
  signal dsutx      : std_ulogic;

  -- APB Uart
  signal urxd       : std_ulogic;
  signal utxd       : std_ulogic;

  -- Ethernet signals
  signal etx_clk    : std_ulogic;
  signal erx_clk    : std_ulogic;
  signal erxdt      : std_logic_vector(7 downto 0);
  signal erx_dv     : std_ulogic;
  signal erx_er     : std_ulogic;
  signal erx_col    : std_ulogic;
  signal erx_crs    : std_ulogic;
  signal etxdt      : std_logic_vector(7 downto 0);
  signal etx_en     : std_ulogic;
  signal etx_er     : std_ulogic;
  signal emdc       : std_ulogic;
  signal emdio      : std_logic;

  -- SVGA signals
  signal vid_hsync  : std_ulogic;
  signal vid_vsync  : std_ulogic;
  signal vid_r      : std_logic_vector(3 downto 0);
  signal vid_g      : std_logic_vector(3 downto 0);
  signal vid_b      : std_logic_vector(3 downto 0);

  -- Select signal for SPI flash
  signal spi_sel_n  : std_logic;
  signal spi_clk    : std_logic;
  signal spi_mosi   : std_logic;

  -- Output signals for LEDs
  signal led       : std_logic_vector(2 downto 0);

  signal brdyn     : std_ulogic;
begin
  -- clock and reset
  clk        <= not clk after ct * 1 ns;
  clk200p    <= not clk200p after 2.5 ns;
  clk200n    <= not clk200n after 2.5 ns;
  rst        <= '1', '0' after 100 ns;
  dsubre     <= '0';
  urxd       <= 'H';
  spi_sel_n  <= 'H';
  spi_clk    <= 'L';
  
  d3 : entity work.leon3mp
    generic map (fabtech, memtech, padtech, clktech, disas, dbguart, pclow)
    port map (
      reset     => rst,
      reset_o1  => rstn1,
      reset_o2  => rstn2,
      clk27     => clk,
      clk200_p  => clk200p,
      clk200_n  => clk200n,
      errorn    => error,

      -- PROM
      address   => address(23 downto 0),
      data      => data(31 downto 24),
      romsn     => romsn,
      oen       => oen,
      writen    => writen,
      iosn      => iosn,
      testdata  => data(23 downto 0),

      -- DDR2
      ddr_clk        => ddr_clk,
      ddr_clkb       => ddr_clkb,
      ddr_cke        => ddr_cke,
      ddr_we         => ddr_we,
      ddr_ras        => ddr_ras,
      ddr_cas        => ddr_cas,
      ddr_dm         => ddr_dm,
      ddr_dqs        => ddr_dqs,
      ddr_dqsn       => ddr_dqsn,
      ddr_ad         => ddr_ad,
      ddr_ba         => ddr_ba,
      ddr_dq         => ddr_dq,
      ddr_odt        => ddr_odt,
      ddr_rzq        => ddr_rzq,
      ddr_zio        => ddr_zio,
      
      -- Debug Unit
      dsubre    => dsubre,

      -- AHB Uart
      dsutx     => dsutx,
      dsurx     => dsurx,

      -- PHY
      etx_clk   => etx_clk,
      erx_clk   => erx_clk,
      erxd      => erxdt(7 downto 0),
      erx_dv    => erx_dv,
      erx_er    => erx_er,
      erx_col   => erx_col,
      erx_crs   => erx_crs,
      etxd      => etxdt(7 downto 0),
      etx_en    => etx_en,
      etx_er    => etx_er,
      emdc      => emdc,
      emdio     => emdio,

      -- SPI flash select
--      spi_sel_n => spi_sel_n,
--      spi_clk   => spi_clk,
--      spi_mosi  => spi_mosi,

      -- Output signals for LEDs
      led       => led
      );


  migddr2mem : if (CFG_MIG_DDR2 = 1) generate 
    ddr2mem0: ddr2ram
      generic map (width => 16, abits => 13, babits => 3,
                   colbits => 10, rowbits => 13, implbanks => 1,
                   fname => sdramfile, lddelay => (220 us),
                   speedbin => 1)
      port map (ck => ddr_clk, ckn => ddr_clkb, cke => ddr_cke, csn => ddr_csb,
                odt => ddr_odt, rasn => ddr_ras, casn => ddr_cas, wen => ddr_we,
                dm => ddr_dm, ba => ddr_ba, a => ddr_ad,
                dq => ddr_dq, dqs => ddr_dqs, dqsn => ddr_dqsn);
  end generate;
  ddr2mem : if (CFG_DDR2SP /= 0) generate 
    ddr2mem0: ddr2ram
      generic map (width => 16, abits => 13, babits => 3,
                   colbits => 10, rowbits => 13, implbanks => 1,
                   fname => sdramfile, lddelay => (0 us),
                   speedbin => 1)
      port map (ck => ddr_clk, ckn => ddr_clkb, cke => ddr_cke, csn => ddr_csb,
                odt => ddr_odt, rasn => ddr_ras, casn => ddr_cas, wen => ddr_we,
                dm => ddr_dm, ba => ddr_ba, a => ddr_ad,
                dq => ddr_dq2, dqs => ddr_dqs, dqsn => ddr_dqsn);
    ddr2delay0 : delay_wire 
      generic map(data_width => ddr_dq'length, delay_atob => 0.0, delay_btoa => 9.0)
      port map(a => ddr_dq, b => ddr_dq2);
  end generate;

  prom0 : sram
    generic map (index => 6, abits => 24, fname => promfile)
    port map (address(23 downto 0), data(31 downto 24), romsn, writen, oen);

  phy0 : if (CFG_GRETH = 1) generate
    emdio <= 'H';
    p0: phy
      generic map (address => 1)
      port map(rstn1, emdio, etx_clk, erx_clk, erxdt, erx_dv, erx_er,
               erx_col, erx_crs, etxdt, etx_en, etx_er, emdc, '0');
  end generate;

  spimem0: if CFG_SPIMCTRL = 1 generate
    s0 : spi_flash generic map (ftype => 4, debug => 0, fname => promfile,
                                readcmd => CFG_SPIMCTRL_READCMD,
                                dummybyte => CFG_SPIMCTRL_DUMMYBYTE,
                                dualoutput => 0)  -- Dual output is not supported in this design
      port map (spi_clk, spi_mosi, data(24), spi_sel_n);
  end generate spimem0;

  error <= 'H';                         -- ERROR pull-up

  iuerr : process
  begin
    wait for 5 us;
    assert (to_X01(error) = '1')
      report "*** IU in error mode, simulation halted ***"
      severity failure;
  end process;

  test0 : grtestmod
    port map ( rst, clk, error, address(21 downto 2), data, iosn, oen, writen, brdyn);

  data <= buskeep(data) after 5 ns;

  dsucom : process
    procedure dsucfg(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32 : std_logic_vector(31 downto 0);
      variable c8  : std_logic_vector(7 downto 0);
      constant txp : time := 160 * 1 ns;
    begin
      dsutx  <= '1';
      wait;
      wait for 5000 ns;
      txc(dsutx, 16#55#, txp);          -- sync uart
      txc(dsutx, 16#a0#, txp);
      txa(dsutx, 16#40#, 16#00#, 16#00#, 16#00#, txp);
      rxi(dsurx, w32, txp, lresp);

-- txc(dsutx, 16#c0#, txp);
-- txa(dsutx, 16#90#, 16#00#, 16#00#, 16#00#, txp);
-- txa(dsutx, 16#00#, 16#00#, 16#00#, 16#ef#, txp);
--
-- txc(dsutx, 16#c0#, txp);
-- txa(dsutx, 16#90#, 16#00#, 16#00#, 16#20#, txp);
-- txa(dsutx, 16#00#, 16#00#, 16#ff#, 16#ff#, txp);
--
-- txc(dsutx, 16#c0#, txp);
-- txa(dsutx, 16#90#, 16#40#, 16#00#, 16#48#, txp);
-- txa(dsutx, 16#00#, 16#00#, 16#00#, 16#12#, txp);
--
-- txc(dsutx, 16#c0#, txp);
-- txa(dsutx, 16#90#, 16#40#, 16#00#, 16#60#, txp);
-- txa(dsutx, 16#00#, 16#00#, 16#12#, 16#10#, txp);
--
-- txc(dsutx, 16#80#, txp);
-- txa(dsutx, 16#90#, 16#00#, 16#00#, 16#00#, txp);
-- rxi(dsurx, w32, txp, lresp);
    end;
  begin
    dsucfg(dsutx, dsurx);
    wait;
  end process;
end;


