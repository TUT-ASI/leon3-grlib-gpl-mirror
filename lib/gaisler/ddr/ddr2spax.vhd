------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2010, Aeroflex Gaisler
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
-----------------------------------------------------------------------------
-- Entity:      ddr2spax
-- File:        ddr2spax.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: DDR2 memory controller with asynch AHB interface
--              Based on ddr2sp(16/32/64)a, generalized and expanded
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;
library gaisler;
use gaisler.memctrl.all;

entity ddr2spax is
   generic (
      memtech    : integer := 0;
      hindex     : integer := 0;
      haddr      : integer := 0;
      hmask      : integer := 16#f00#;
      ioaddr     : integer := 16#000#;
      iomask     : integer := 16#fff#;
      ddrbits    : integer := 32;
      burstlen   : integer := 8;
      MHz        : integer := 100;
      TRFC       : integer := 130;
      col        : integer := 9;
      Mbyte      : integer := 8;
      fastahb    : integer := 0;
      pwron      : integer := 0;
      oepol      : integer := 0;
      readdly    : integer := 1;
      odten      : integer := 0;
      octen      : integer := 0;
      -- dqsgating  : integer := 0;
      nosync     : integer := 0;
      dqsgating  : integer := 0;
      eightbanks : integer range 0 to 1 := 0; -- Set to 1 if 8 banks instead of 4
      dqsse      : integer range 0 to 1 := 0;  -- single ended DQS
      ddr_syncrst: integer range 0 to 1 := 0;
      ahbbits    : integer := ahbdw
   );
   port (
      rst     : in  std_ulogic;
      clk_ddr : in  std_ulogic;
      clk_ahb : in  std_ulogic;
      ahbsi   : in  ahb_slv_in_type;
      ahbso   : out ahb_slv_out_type;
      sdi     : in  sdctrl_in_type;
      sdo     : out sdctrl_out_type
   );  
end ddr2spax;

architecture rtl of ddr2spax is

  constant REVISION  : integer := 0;

  constant ramwt: integer := 0;
  
  constant l2blen: integer := log2(burstlen*32);
  constant l2ddrw: integer := log2(ddrbits*2);
  constant l2ahbw: integer := log2(ahbbits);

  -- Write buffer dimensions
  -- Write buffer is addressable down to 32-bit level on write (AHB) side.
  constant wbuf_rabits: integer := 1+l2blen-l2ddrw; -- log2((burstlen*32)/(2*ddrbits));
  constant wbuf_rdbits: integer := 2*ddrbits;
  constant wbuf_wabits: integer := 1+l2blen-5; --  log2(burstlen);
  constant wbuf_wdbits: integer := ahbbits;
  -- Read buffer dimensions
  constant rbuf_rabits: integer := l2blen-l2ahbw; -- log2(burstlen*32/ahbbits);
  constant rbuf_rdbits: integer := ahbbits;
  constant rbuf_wabits: integer := l2blen-l2ddrw; -- log2((burstlen*32)/(2*ddrbits));
  constant rbuf_wdbits: integer := 2*ddrbits;

  signal request   : ddr_request_type;
  signal start_tog : std_logic;
  signal done_tog  : std_logic;

  signal wbwaddr: std_logic_vector(wbuf_wabits-1 downto 0);
  signal wbwdata: std_logic_vector(wbuf_wdbits-1 downto 0);
  signal wbraddr: std_logic_vector(wbuf_rabits-1 downto 0);
  signal wbrdata: std_logic_vector(wbuf_rdbits-1 downto 0);
  signal rbwaddr: std_logic_vector(rbuf_wabits-1 downto 0);
  signal rbwdata: std_logic_vector(rbuf_wdbits-1 downto 0);
  signal rbraddr: std_logic_vector(rbuf_rabits-1 downto 0);
  signal rbrdata: std_logic_vector(rbuf_rdbits-1 downto 0);
  signal wbwrite,wbwritebig,rbwrite: std_logic;

  signal vcc: std_ulogic;
  
begin
  
  vcc <= '1';
  
  ahbc : ddr2spax_ahb
    generic map (hindex => hindex, haddr => haddr, hmask => hmask, ioaddr => ioaddr, iomask => iomask,
                 nosync => nosync, burstlen => burstlen, ahbbits => ahbbits)
    port map (rst, clk_ahb, ahbsi, ahbso, request, start_tog, done_tog,
              wbwaddr, wbwdata, wbwrite, wbwritebig, rbraddr, rbrdata);
  
  ddrc : ddr2spax_ddr
    generic map (ddrbits => ddrbits,
                 pwron => pwron, MHz => MHz, TRFC => TRFC, col => col, Mbyte => Mbyte,
                 fastahb => fastahb, readdly => readdly, odten => odten, octen => octen, dqsgating => dqsgating,
                 nosync => nosync, eightbanks => eightbanks, dqsse => dqsse, burstlen => burstlen)
    port map (rst, clk_ddr, request, start_tog, done_tog, sdi, sdo,
              wbraddr, wbrdata, rbwaddr, rbwdata, rbwrite);
  
  wbuf: ddr2buf
    generic map (tech => memtech, wabits => wbuf_wabits, wdbits => wbuf_wdbits,
                 rabits => wbuf_rabits, rdbits => wbuf_rdbits,
                 sepclk => 1, wrfst => ramwt)
    port map ( rclk => clk_ddr, renable => vcc, raddress => wbraddr,
               dataout => wbrdata, wclk => clk_ahb, write => wbwrite,
               writebig => wbwritebig, waddress => wbwaddr, datain => wbwdata);
  
  rbuf: ddr2buf
    generic map (tech => memtech, wabits => rbuf_wabits, wdbits => rbuf_wdbits,
                 rabits => rbuf_rabits, rdbits => rbuf_rdbits,
                 sepclk => 1, wrfst => ramwt)
    port map ( rclk => clk_ahb, renable => vcc, raddress => rbraddr,
               dataout => rbrdata,
               wclk => clk_ddr, write => rbwrite,
               writebig => '0', waddress => rbwaddr, datain => rbwdata);
  
-- pragma translate_off
   bootmsg : report_version
   generic map (
      msg1 => "ddr2spa: DDR2 controller rev " &
              tost(REVISION) & ", " & tost(ddrbits) & " bit width, " & tost(Mbyte) & " Mbyte, " & tost(MHz) &
              " MHz DDR clock");
-- pragma translate_on
  
end;
