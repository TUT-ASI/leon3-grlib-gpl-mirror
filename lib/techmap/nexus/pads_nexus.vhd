
--=====================================================================
-- Copyright 2022 Cobham Gaisler AB
--=====================================================================
-- The code is provided "as is", there is no warranty that
-- the code is correct or suitable for any purpose,
-- neither implicit nor explicit.
--
--=====================================================================
-- Title:      Pads Generator
--
-- IP-Core:    pads_nexus.vhd
--
-- Purpose:    Generates IN-OUT PADS using Lattice Nexus primitives
--
-- Author:     Cobham Gaisler AB
--=====================================================================
-- Change Log
--
--=====================================================================

--================================--
------------ INOUTPAD -------------
--================================--
Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on

entity nexus_iopad is
  port (pad   : inout std_ulogic; --From/To external
        i, en : in std_ulogic;    --From internal design
        o     : out std_ulogic);  --To internal design
end;
architecture rtl of nexus_iopad is
  component BB is
    port(
      T : in std_logic;
      I : in std_logic;
      O : out std_logic;
      B : inout std_logic
      );
  end component;
begin

  BB_0 : BB
    port map (
      I => i,
      O => o,
      T => en,
      B => pad
      );
end;


--================================--
-------------- INPAD ---------------
--================================--
Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on

entity nexus_inpad is
  port (pad : in std_ulogic;   --From external
        o   : out std_ulogic); --To internal design
end;
architecture rtl of nexus_inpad is
  component IB is
    port(
      I : in std_logic;
      O : out std_logic
      );
  end component;
begin

  IB_0 : IB
    port map (
      I => pad,
      O => o
      );
end;


--================================--
-------------- OUTPAD --------------
--================================--
Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on

entity nexus_outpad is
  port (i   : in std_ulogic;   --From internal design
        pad : out std_ulogic); --To external
end;
architecture rtl of nexus_outpad is
  component OB is
    port(
      I : in std_logic;
      O : out std_logic
      );
  end component;
begin

  OB_0 : OB
    port map (
      I => i,
      O => pad
      );
end;


--================================--
-------------- TOUTPAD -------------
--================================--
Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on

entity nexus_toutpad is
  port ( pad : out std_ulogic; --To external
         i   : in std_ulogic;  --From internal design
         en  : in std_ulogic); -- Tri-state control
end;
architecture rtl of nexus_toutpad is
  component OBZ is -- Output Buffer with Tri-state
    port(
      I : in std_logic;
	  T : in std_logic;
      O : out std_logic
      );
  end component;
begin

  OBZ_0 : OBZ
    port map (
      I => i,
      O => pad,
	  T => en
      );
end;
