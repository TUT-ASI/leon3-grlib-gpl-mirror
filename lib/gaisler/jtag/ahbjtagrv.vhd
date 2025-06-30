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
-------------------------------------------------------------------------------------
-- Entity:      ahbjtagrv
-- File:        ahbjtagrv.vhd
-- Author:      Nils Wessman, Sergio Garcia Esteban - Frontgrade Gaisler
-- Description: JTAG communication link with AHB master interface with support for:
--              - GRMON DTM (dtm_sel=0)
--              - RISCV DTM (dtm_sel=1)
--              - both (dtm_sel=2)
--
-- Note: dtm_sel=2 is only available for inferred_tap (tech=0), so if you need
-- having both DTMs with Xilinx FPGA TAP, you can instantiate in your design ahbjtag
-- and ahbjtagrv with dtm_sel=1 and tapopt=1
--------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.libjtagcom.all;
use gaisler.jtag.all;

entity ahbjtagrv is
  generic (
    tech      : integer range 0 to NTECH := 0;
    dtm_sel   : integer range 0 to 2 := 1;      -- select GRMON(0), RISCV(1), or both(2)
    tapopt    : integer range 0 to 1 := 0;      -- xilinx_tap offset
    hindex_gr : integer := 0;                   -- AHB-Debug Index for GRMON DTM
    hindex_rv : integer := 0;                   -- AHB-Debug Index for RISCV DTM
    nsync     : integer range 1 to 2 := 1;
    idcode    : integer range 0 to 255 := 9;    -- inferred_tap idcode command code
    manf      : integer range 0 to 2047 := 804;
    part      : integer range 0 to 65535 := 0;
    ver       : integer range 0 to 15 := 0;
    ainst_gr  : integer range 0 to 255 := 2;    -- inferred_tap GRMON instr1 command code
    dinst_gr  : integer range 0 to 255 := 3;    -- inferred_tap GRMON instr2 command code
    ainst_rv  : integer range 0 to 255 := 16;   -- inferred_tap RISCV instr1 command code
    dinst_rv  : integer range 0 to 255 := 17;   -- inferred_tap RISCV instr2 command code
    scantest  : integer := 0;
    oepol     : integer := 1;
    tcknen    : integer := 0;
    versel    : integer range 0 to 1 := 1);
  port (
    rst         : in  std_ulogic;
    clk         : in  std_ulogic;
    tck         : in  std_ulogic;         -- external TCK signal for inferred_tap
    tms         : in  std_ulogic;         -- external TMS signal for inferred_tap
    tdi         : in  std_ulogic;         -- external TDI signal for inferred_tap
    tdo         : out std_ulogic;         -- external TDO signal for inferred_tap
    ahbi_gr     : in  ahb_mst_in_type;    -- AHB-Debug interface for GRMON DTM
    ahbo_gr     : out ahb_mst_out_type;   -- AHB-Debug interface for GRMON DTM
    ahbi_rv     : in  ahb_mst_in_type;    -- AHB-Debug interface for RISCV DTM
    ahbo_rv     : out ahb_mst_out_type;   -- AHB-Debug interface for RISCV DTM
    tapo_tck    : out std_ulogic;
    tapo_tdi    : out std_ulogic;
    tapo_inst   : out std_logic_vector(7 downto 0);
    tapo_rst    : out std_ulogic;
    tapo_capt   : out std_ulogic;
    tapo_shft   : out std_ulogic;
    tapo_upd    : out std_ulogic;
    tapi_tdo    : in std_ulogic;
    trst        : in std_ulogic := '1';
    tdoen       : out std_ulogic;
    tckn        : in std_ulogic := '0';
    tapo_tckn   : out std_ulogic;
    tapo_ninst  : out std_logic_vector(7 downto 0);
    tapo_iupd   : out std_ulogic
    );
end;      

architecture struct of ahbjtagrv is

-- Use old jtagcom that only supports AHB clock up to 1/3 of JTAG clock
-- Must be used for certain techs where we don't have full access to TCK
-- Can also be forced by setting versel generic to 0
constant USEOLDCOM : integer := 1 - (1-tap_tck_gated(tech))*(versel);

-- Set REREAD to 1 to include support for re-read operation when host reads
-- out data register before jtagcom has completed the current AMBA access and
-- returned to state 'shft'.
constant REREAD : integer := 1;
constant REVISION : integer := 2 - (2-REREAD)*USEOLDCOM;

-- Xilinx TAP auto-select JTAG commands are previously configured and work 
-- differently from inferred_tap, which receives all commands and then commands
-- have to be selected by DTM
constant TAPSEL   : integer := has_tapsel(tech);

-- Signals
signal dmai_gr : ahb_dma_in_type;
signal dmao_gr : ahb_dma_out_type;
signal dmai_rv : ahb_dma_in_type;
signal dmao_rv : ahb_dma_out_type;
signal ltapi    : tap_in_type;
signal ltapi_gr : tap_in_type;
signal ltapi_rv : tap_in_type;
signal ltapo    : tap_out_type;
signal lltck, lltckn, ltck, ltckn: std_ulogic;
signal lupd: std_ulogic;
signal ctrst: std_ulogic;
signal crr, combrst: std_ulogic;

begin


  -- AHB Master Interface for GRMON DTM
  gen_ahbmst0 : if (dtm_sel = 0) or (dtm_sel = 2) generate
    ahbmst0 : ahbmst 
      generic map (
        hindex  => hindex_gr,
        venid   => VENDOR_GAISLER,
        devid   => GAISLER_AHBJTAG,
        version => REVISION
      )
      port map (
        rst, clk, dmai_gr, dmao_gr, ahbi_gr, ahbo_gr
      );
  end generate gen_ahbmst0;

  -- AHB Master Interface for RISCV DTM
  gen_ahbmst1 : if (dtm_sel = 1) or (dtm_sel = 2) generate
    ahbmst1 : ahbmst 
      generic map (
        hindex  => hindex_rv,
        venid   => VENDOR_GAISLER,
        devid   => GAISLER_AHBJTAG,
        version => REVISION
      )
      port map (
        rst, clk, dmai_rv, dmao_rv, ahbi_rv, ahbo_rv
      );
  end generate gen_ahbmst1;

  -- TAP 
  tap0 : tap generic map (tech => tech, irlen => 6, idcode => idcode, 
	manf => manf, part => part, ver => ver, scantest => scantest, oepol => oepol,
        tcknen => tcknen, techarg => tapopt)
    port map (trst, tck, tms, tdi, tdo, lltck, ltapo.tdi, ltapo.inst, ltapo.reset, ltapo.capt,
              ltapo.shift, lupd, ltapo.asel, ltapo.dsel, ltapi.en, ltapi.tdo, tapi_tdo,
              tapo_ninst, tapo_iupd, lltckn,
	      ahbi_gr.testen, ahbi_gr.testrst, ahbi_gr.testoen, tdoen, tckn);

  ltapo.tck <= ltck;
  tapo_tckn <= ltckn;

  -- TCK buffer for FPGA
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

  -- Quirk for Xilinx TAP - upd changes on falling TCK edge and
  -- the flow doesn't maintain synchrony with user falling TCK edge logic.
  gupdff : if     (USEOLDCOM=0 and is_unisim(tech)/=0) generate
    updff: grdff port map (ltck, lupd, ltapo.upd);
  end generate;
  noupdff: if not (USEOLDCOM=0 and is_unisim(tech)/=0) generate
    ltapo.upd <= lupd;
  end generate;
  
  -- Old GRMON DTM
  oldcom: if ( dtm_sel = 0 or dtm_sel = 2 ) and USEOLDCOM /= 0 generate
    jtagcom0 : jtagcom generic map (isel => TAPSEL, nsync => nsync, ainst => ainst_gr, dinst => dinst_gr, reread => REREAD)
      port map (rst, clk, ltapo, ltapi_gr, dmao_gr, dmai_gr, ltck, ctrst);
  end generate;

  -- New GRMON DTM
  newcom: if ( dtm_sel = 0 or dtm_sel = 2 ) and USEOLDCOM = 0 generate
    jtagcom0 : jtagcom2 generic map (gatetech => tech, isel => TAPSEL, ainst => ainst_gr, dinst => dinst_gr)
      port map (rst, clk, ltapo, ltapi_gr, dmao_gr, dmai_gr, ltck, ltckn, ctrst);
  end generate;

  -- RISCV DTM
  rvcom: if ( dtm_sel = 1 or dtm_sel = 2 ) generate
    jtagcom1 : jtagcomrv generic map (gatetech => tech, isel => TAPSEL, ainst => ainst_rv, dinst => dinst_rv)
      port map (rst, clk, ltapo, ltapi_rv, dmao_rv, dmai_rv, ltck, ltckn, ctrst);
  end generate;

  -- Select between DTM signals for TAP input
  ltapi.en  <=  ltapi_gr.en or ltapi_rv.en;
  ltapi.tdo <= ltapi_gr.tdo when ltapi_gr.en = '1' else
                ltapi_rv.tdo  when ltapi_rv.en  = '1' else
                '0';

  tapo_tck <= ltck; tapo_tdi <= ltapo.tdi; tapo_inst <= ltapo.inst;
  tapo_rst <= ltapo.reset; tapo_capt <= ltapo.capt; tapo_shft <= ltapo.shift; 
  tapo_upd <= ltapo.upd;
  
  -- Async reset for tck-domain FFs in jtagcom. 
  -- In FPGA configs use AMBA reset as real TRST may not be available.
  -- For ASIC:s we combine AMBA and JTAG TRST using synchr flip-flop
  ctrst <= ahbi_gr.testrst when scantest/=0 and ahbi_gr.testen='1' else
           rst when is_fpga(tech)/=0 else
           combrst;

  combrstgen: if is_fpga(tech)=0 generate
    crr <= ahbi_gr.testrst when scantest/=0 and ahbi_gr.testen='1' else
           (trst and rst);
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
    generic map ("ahbjtagrv AHB Debug JTAG rev " & tost(REVISION));
-- pragma translate_on

end;

