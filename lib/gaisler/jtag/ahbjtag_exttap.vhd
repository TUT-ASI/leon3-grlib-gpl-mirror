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
-----------------------------------------------------------------------------   
-- Entity:      ahbjtag_exttap
-- File:        ahbjtag_exttap.vhd
-- Description: JTAG communication link with AHB master interface with
--              external TAP interface
------------------------------------------------------------------------------  

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.dftlib.trstmux;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.libjtagcom.all;
use gaisler.jtag.all;

entity ahbjtag_exttap is
  generic (
    tech     : integer range 0 to NTECH := 0;
    hindex   : integer                  := 0;
    nsync    : integer range 1 to 2     := 1;
    ainst    : integer range 0 to 255   := 2;
    dinst    : integer range 0 to 255   := 3;
    scantest : integer                  := 0;
    versel   : integer range 0 to 1     := 1);
  port (
    rst       : in  std_ulogic;
    clk       : in  std_ulogic;
    ahbi      : in  ahb_mst_in_type;
    ahbo      : out ahb_mst_out_type;
    tap_tck   : in  std_ulogic;
    tap_tckn  : in  std_ulogic;
    tap_tdi   : in  std_ulogic;
    tap_inst  : in  std_logic_vector(7 downto 0);
    tap_asel  : in  std_ulogic;
    tap_dsel  : in  std_ulogic;
    tap_reset : in  std_ulogic;
    tap_capt  : in  std_ulogic;
    tap_shift : in  std_ulogic;
    tap_upd   : in  std_ulogic;
    tap_en    : out std_ulogic;
    tap_tdo   : out std_ulogic;
    trst      : in  std_ulogic := '1'
    );
end;

architecture struct of ahbjtag_exttap is

-- Use old jtagcom that only supports AHB clock up to 1/3 of JTAG clock
-- Must be used for certain techs where we don't have full access to TCK
-- Can also be forced by setting versel generic to 0
-- Support for registered TAPs not yet added to jtagcom2
constant USEOLDCOM : integer := 1 - (1-tap_tck_gated(tech))*(1-tap_registered(tech))*(versel);

-- Set REREAD to 1 to include support for re-read operation when host reads
-- out data register before jtagcom has completed the current AMBA access and
-- returned to state 'shft'.
constant REREAD : integer := 1;

constant REVISION : integer := 2 - (2-REREAD)*USEOLDCOM;
constant TAPSEL   : integer := has_tapsel(tech);

signal dmai : ahb_dma_in_type;
signal dmao : ahb_dma_out_type;
signal ltapi : tap_in_type;
signal ltapo : tap_out_type;
signal lltck, lltckn, ltck, ltckn: std_ulogic;
signal ctrsti, ctrst: std_ulogic;
signal crri, crr, combrst: std_ulogic;

begin

  ahbmst0 : ahbmst 
    generic map (hindex => hindex, venid => VENDOR_GAISLER,
                 devid => GAISLER_AHBJTAG, version => REVISION)
    port map (rst, clk, dmai, dmao, ahbi, ahbo);

  lltck  <= tap_tck;
  lltckn <= tap_tckn;

  gtckbuf : if (USEOLDCOM=0 and is_fpga(tech)/=0) generate
    tckbuf: techbuf
      generic map (buftype => 2, tech => tech)
      port map (lltck, ltck);
    ltckn <= not ltck;
  end generate;
  notckbuf: if not (USEOLDCOM=0 and is_fpga(tech)/=0) generate
    ltck <= lltck;
    ltckn <= lltckn;
  end generate;

  ltapo.tck   <= ltck;
  ltapo.tdi   <= tap_tdi;
  ltapo.inst  <= tap_inst;
  ltapo.asel  <= tap_asel;
  ltapo.dsel  <= tap_dsel;
  ltapo.reset <= tap_reset;
  ltapo.capt  <= tap_capt;
  ltapo.shift <= tap_shift;
  tap_en      <= ltapi.en;
  tap_tdo     <= ltapi.tdo;

  -- Quirk for Xilinx TAP - upd changes on falling TCK edge and
  -- the flow doesn't maintain synchrony with user falling TCK edge logic.
  gupdff : if     (USEOLDCOM=0 and is_unisim(tech)/=0) generate
    updff: grdff port map (ltck, tap_upd, ltapo.upd);
  end generate;
  noupdff: if not (USEOLDCOM=0 and is_unisim(tech)/=0) generate
    ltapo.upd <= tap_upd;
  end generate;
  
  oldcom: if USEOLDCOM /= 0 generate
    jtagcom0 : jtagcom
      generic map (
        isel => TAPSEL, nsync => nsync, ainst => ainst, dinst => dinst, reread => REREAD,
        tapreg => tap_registered(tech))
      port map (rst, clk, ltapo, ltapi, dmao, dmai, ltck, ctrst);
  end generate;

  newcom: if USEOLDCOM=0 generate
    jtagcom0 : jtagcom2 generic map (gatetech => tech, isel => TAPSEL, ainst => ainst, dinst => dinst)
      port map (rst, clk, ltapo, ltapi, dmao, dmai, ltck, ltckn, ctrst);
  end generate;
  
  -- Async reset for tck-domain FFs in jtagcom. 
  -- In FPGA configs use AMBA reset as real TRST may not be available.
  -- For ASIC:s we combine AMBA and JTAG TRST using synchr flip-flop
  trstmux2: trstmux generic map (scantest) port map (ctrsti,ahbi.testrst,ahbi.testen,ctrst);
  ctrsti <= rst when is_fpga(tech)/=0 else
            combrst;

  combrstgen: if is_fpga(tech)=0 generate
    crri <= (trst and rst);
    trstmux1: trstmux generic map (scantest) port map (crri,ahbi.testrst,ahbi.testen,crr);
    crproc: process(ltck, crr)
    begin
      if rising_edge(ltck) then
        combrst <= '1';
      end if;
      if crr='0' then
        combrst <= '0';
      end if;
    end process;
  end generate;
  combrstngen: if is_fpga(tech)/=0 generate
    crr <= '0'; combrst <= '0';
  end generate;

-- pragma translate_off
    bootmsg : report_version 
    generic map ("ahbjtag_jtag AHB Debug JTAG rev " & tost(REVISION));
-- pragma translate_on

end;
