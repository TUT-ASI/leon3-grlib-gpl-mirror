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
-- Entity: 	inpad
-- File:	inpad.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Description:	input pad with technology wrapper
------------------------------------------------------------------------------

library techmap;
library ieee;
use ieee.std_logic_1164.all;
use techmap.gencomp.all;
use techmap.allpads.all;

entity inpad is
  generic (tech : integer := 0; level : integer := 0;
	voltage : integer := x33v; filter : integer := 0;
	strength : integer := 0);
  port (pad : in std_ulogic; o : out std_ulogic);
end;

architecture rtl of inpad is
begin
  gen0 : if has_pads(tech) = 0 generate
    o <= transport to_X01(pad)
-- pragma translate_off
 	after 1 ns
-- pragma translate_on
	;
  end generate;
  xcv : if (is_unisim(tech) = 1) generate
    x0 : unisim_inpad generic map (level, voltage) port map (pad, o);
  end generate;
  axc : if (tech = axcel) or (tech = axdsp) generate
    x0 : axcel_inpad generic map (level, voltage) port map (pad, o);
  end generate;
  pa3 : if (tech = proasic) or (tech = apa3) generate
    x0 : apa3_inpad generic map (level, voltage, filter) port map (pad, o);
  end generate;
  pa3e : if (tech = apa3e) generate
    x0 : apa3e_inpad generic map (level, voltage, filter) port map (pad, o);
  end generate;
  igl2 : if (tech = igloo2) or (tech = rtg4) generate
    x0 : igloo2_inpad port map (pad, o);
  end generate;
  pf : if (tech = polarfire) generate
    x0 : polarfire_inpad port map (pad, o);
  end generate;
  pa3l : if (tech = apa3l) generate
    x0 : apa3l_inpad generic map (level, voltage, filter) port map (pad, o);
  end generate;
  fus : if (tech = actfus) generate
    x0 : fusion_inpad generic map (level, voltage, filter) port map (pad, o);
  end generate;
  atc : if (tech = atc18s) generate
    x0 : atc18_inpad generic map (level, voltage) port map (pad, o);
  end generate;
  atcrh : if (tech = atc18rha) generate
    x0 : atc18rha_inpad generic map (level, voltage) port map (pad, o);
  end generate;
  um : if (tech = umc) generate
    x0 : umc_inpad generic map (level, voltage, filter) port map (pad, o);
  end generate;
  rhu : if (tech = rhumc) generate
    x0 : rhumc_inpad generic map (level, voltage, filter) port map (pad, o);
  end generate;
  saed : if (tech = saed32) generate
    x0 : saed32_inpad generic map (level, voltage, filter) port map (pad, o);
  end generate;
  rhs : if (tech = rhs65) generate
    x0 : rhs65_inpad generic map (level, voltage, filter) port map (pad, o);
  end generate;
  dar : if (tech = dare) generate
    x0 : dare_inpad generic map (level, voltage, filter) port map (pad, o);
  end generate;
  dar65t : if (tech = dare65t) generate
    x0 : dare65t_inpad generic map (level, voltage, filter) port map (pad,'0', o);
  end generate;
  ihp : if (tech = ihp25) generate
    x0 : ihp25_inpad generic map(level, voltage) port map(pad, o);
  end generate;
  ihprh : if (tech = ihp25rh) generate
    x0 : ihp25rh_inpad generic map(level, voltage) port map(pad, o);
  end generate;
  rh18t : if (tech = rhlib18t) generate
    x0 : rh_lib18t_inpad generic map (voltage, filter) port map(pad, o);
  end generate;
  ut025 : if (tech = ut25) generate
    x0 : ut025crh_inpad generic map (level, voltage, filter) port map(pad, o);
  end generate;
  ut13  : if (tech = ut130) generate
    x0 : ut130hbd_inpad generic map (level, voltage, filter) port map(pad, o);
  end generate;
  pereg : if (tech = peregrine) generate
    x0 : peregrine_inpad generic map (level, voltage, filter, strength) port map(pad, o);
  end generate;
  eas : if (tech = easic90) generate
    x0 : nextreme_inpad generic map (level, voltage) port map (pad, o);
  end generate;
  n2x : if (tech = easic45) generate
    x0 : n2x_inpad generic map (level, voltage) port map (pad, o);
  end generate;
  ut90nhbd : if (tech = ut90) generate
    x0 : ut90nhbd_inpad generic map (level, voltage, filter) port map(pad, o);
  end generate;
  nxus : if (tech = nexus) generate
    x0: nexus_inpad port map (pad, o);
  end generate;
end;

library techmap;
library ieee;
use ieee.std_logic_1164.all;
use techmap.gencomp.all;

entity inpadv is
  generic (tech : integer := 0; level : integer := 0;
	   voltage : integer := 0; width : integer := 1;
           filter : integer := 0; strength : integer := 0);
  port (
    pad : in  std_logic_vector(width-1 downto 0);
    o   : out std_logic_vector(width-1 downto 0));
end;
architecture rtl of inpadv is
begin
  v : for i in width-1 downto 0 generate
    x0 : inpad generic map (tech, level, voltage, filter, strength) port map (pad(i), o(i));
  end generate;
end;

