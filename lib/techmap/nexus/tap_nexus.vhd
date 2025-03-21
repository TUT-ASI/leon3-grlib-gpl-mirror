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
-- Entity:      tap_nexus
-- File:        tap_nexus.vhd
-- Author:      Henrik Gingsjo - Frontgrade Gaisler
-- Description: Wrapper for Lattice/Nexus built-in TAP controller
--
-- This TAP wrapper is expected to be compatible with the LFCPNX, LFD2NX,
-- LFMXO5, and LIFCL device families. It is not compatible wit the LAV-AT
-- family since that uses the slightly different JTAGA primitive. It is also
-- not compatible with the iCE40UP family since that family has no built-in
-- JTAG interface.
--
-- Global configuration constants in techmap.gencomp for tech=nexus:
--   has_tap: 1
--   has_tapsel: 1
--   tap_registered: 1
--   tap_tck_gated: 0
--
-- Some information about interfacing the built-in JTAG TAP from user logic can
-- be found in technical note FPGA-TN-02099 from Lattice:
--   FPGA-TN-02099-2.3 "sysCONFIG user Guide for Nexus Platform"
--   Section 6.4.4 "JTAG ispTracy/Reveal Support"
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on

entity nexus_tap is
  port (
    tck         : in std_ulogic;
    tms         : in std_ulogic;
    tdi         : in std_ulogic;
    tdo         : out std_ulogic;
    tapo_tck    : out std_ulogic;
    tapo_tdi    : out std_ulogic;
    tapo_rst    : out std_ulogic;
    tapo_capt   : out std_ulogic;
    tapo_shft   : out std_ulogic;
    tapo_upd    : out std_ulogic;
    tapo_xsel1  : out std_ulogic;
    tapo_xsel2  : out std_ulogic;
    tapi_tdo1   : in std_ulogic;
    tapi_tdo2   : in std_ulogic;
    tdoen       : out std_ulogic
    );
end entity;

architecture rtl of nexus_tap is


  component JTAG
    generic (
      MCER1EXIST : String := "NEXIST";
      MCER2EXIST : String := "NEXIST");
    port (
      JTDO1   : in  std_logic := 'X'; -- TDO for ER1 (sampled on falling edge of JTCK)
      JTDO2   : in  std_logic := 'X'; -- TDO for ER2 (sampled on falling edge of JTCK)
      SMCLK   : in  std_logic := 'X'; -- (unknown)
      TCK     : in  std_logic := 'X'; -- external pin (apply clock-constraint)
      TDI     : in  std_logic := 'X'; -- external pin (connect to top-level port)
      TMS     : in  std_logic := 'X'; -- external pin (connect to top-level port)
      JCE1    : out std_logic := 'X'; -- 1 when shifting ER1 (IR=0x32)
      JCE2    : out std_logic := 'X'; -- 1 when shifting ER2 (IR=0x38)
      JRSTN   : out std_logic := 'X'; -- 0 when in the Test-Logic-Reset state
      JRTI1   : out std_logic := 'X'; -- 1 when in Run-Test/Idle and ER1 selected
      JRTI2   : out std_logic := 'X'; -- 1 when in Run-Test/Idle and ER2 selected
      JSHIFT  : out std_logic := 'X'; -- 1 when in the Shift-DR state
      JTDI    : out std_logic := 'X'; -- internal version of TDI
      JUPDATE : out std_logic := 'X'; -- 1 when in the Update-DR state
      JTCK    : out std_logic := 'X'; -- internal version of TCK
      TDO_OEN : out std_logic := 'X'; -- TDO output-enable (active-low) (only for sim?)
      TDO     : out std_logic := 'X');-- external pin (connect to top-level port)
  end component;

  -- The Radiant software knows how to perform timing analysis for the JTAG
  -- primitive and this can be seen in the post-synthesis (and later) timing
  -- analysis reports made by Radiant. But when Synplify is used for synthesis
  -- it sees this component as a black box without knowing any timing
  -- relationships of its pins and will infer a clock on JTCK/tapo_tck and will
  -- not compute any timing paths for JTDI/JTDO/etc. But we can provide this
  -- information to Synplify with attributes. A token delay/setup time of 0.0ns
  -- is used everywhere. External pins TDI, TDO, TDO_OEN and TMS are left
  -- without constraints. 
  attribute syn_black_box : boolean;
  attribute syn_black_box of JTAG : component is true;
  -- Propagation delay. TCK->JTCK is the only combinatorial path.
  attribute syn_tpd1 : string;
  attribute syn_tpd1 of JTAG : component is "TCK->JTCK=0.0";
  -- Setup time for inputs. JTDO1/2 are sampled on the falling edge of JTCK.
  attribute syn_tsu1 : string;
  attribute syn_tsu1 of JTAG : component is "JTDO1,JTDO2->!JTCK=0.0";
  -- Clock-to-out delay. All (internal) outputs change on rising edges of JTCK.
  attribute syn_tco1 : string;
  attribute syn_tco1 of JTAG : component is "JTCK->JUPDATE,JTDI,JSHIFT,JRTI1,JRTI2,JRSTN,JCE1,JCE2=0.0";
  
  -- The JCE1/2 outputs are only asserted in the Capture-DR and Shift-DR
  -- states, but not in Exit-DR or Update-DR which as required by jtagcom.
  -- Instead we store their values in a register that gets cleared when we
  -- leave the Update-DR state.
  type reg_type is record
    xsel1 : std_ulogic;
    xsel2 : std_ulogic;
  end record;

  signal ltck, ltrstn : std_logic;
  signal lce1, lce2 : std_logic;
  signal lupd : std_logic;

  signal r, nr : reg_type;
begin

  u0 : JTAG
    generic map (
      MCER1EXIST  => "EXIST",
      MCER2EXIST  => "EXIST")
    port map (
      JTDO1   => tapi_tdo1,
      JTDO2   => tapi_tdo2,
      SMCLK   => '0', -- Arbitrary placeholder value.
      TCK     => tck,
      TDI     => tdi,
      TMS     => tms,
      JCE1    => lce1,
      JCE2    => lce2,
      JRSTN   => ltrstn,
      JRTI1   => open, -- We have no use for knowing we are in the
      JRTI2   => open, -- Tun-Test-Idle state.
      JSHIFT  => tapo_shft,
      JTDI    => tapo_tdi,
      JUPDATE => lupd,
      JTCK    => ltck,
      TDO_OEN => tdoen,
      TDO     => tdo);

  -- tapo_rst is active-high
  tapo_rst <= not ltrstn;
  tapo_tck <= ltck;
  tapo_upd <= lupd;

  -- Combined xsel based on immediate xsel and the previous value
  tapo_xsel1 <= lce1 or r.xsel1;
  tapo_xsel2 <= lce2 or r.xsel2;
  -- Clear xsel on the next TCK cycle after we reach the Update-DR state (also
  -- cleared in the Test-Logic-Reset state).
  nr.xsel1 <= (lce1 or r.xsel1) and not lupd;
  nr.xsel2 <= (lce2 or r.xsel2) and not lupd;

  -- The Capture-DR state lasts for exactly one TCK cycle after JCE1/2 toggles
  -- from 0 to 1.
  tapo_capt <= (lce1 or lce2) and not (r.xsel1 or r.xsel2);

  tckreg : process(ltck, ltrstn)
  begin
    if rising_edge(ltck) then
      r <= nr;
    end if;
    if ltrstn = '0' then
      r.xsel1 <= '0';
      r.xsel2 <= '0';
    end if;
  end process;

end architecture;
