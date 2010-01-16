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
-- File:	pads_proasic3.vhd
-- Author:	Jonas Ekergarn - Aeroflex Gaisler
-- Description:	Proasic3 pad wrappers
------------------------------------------------------------------------------

-- pragma translate_off
library proasic3;
use proasic3.clkbuf;
use proasic3.clkbuf_pci;
-- pragma translate_on
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity apa3_clkpad is
  generic (level : integer := 0; voltage : integer := 0);
  port (pad : in std_ulogic; o : out std_ulogic);
end; 
architecture rtl of apa3_clkpad is
  component clkbuf port(pad : in std_ulogic; y : out std_ulogic); end component;
  component clkbuf_pci port(pad : in std_ulogic; y : out std_ulogic); end component;
begin
  pci0 : if level = pci33 generate
    cp : clkbuf_pci port map (pad => pad, y => o);
  end generate;
  gen0 : if level /= pci33 generate
    cp : clkbuf port map (pad => pad, y => o);
  end generate;  
end;

-- pragma translate_off
library proasic3;
use proasic3.clkbuf_lvds;
use proasic3.clkbuf_lvpecl;
-- pragma translate_on
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity apa3_clkpad_ds is
  generic (level : integer := lvds);
  port (padp, padn : in std_ulogic; o : out std_ulogic);
end; 
architecture rtl of apa3_clkpad_ds is
  component clkbuf_lvds port(padp, padn : in std_ulogic; y : out std_ulogic); end component;
  component clkbuf_lvpecl port(padp, padn : in std_ulogic; y : out std_ulogic); end component;
begin
  lvpecl0 : if level = lvpecl generate
    cp : clkbuf_lvpecl port map(padp => padp, padn => padn, y => o);
  end generate;
  lvds0 : if level /= lvpecl generate
    cp : clkbuf_lvds port map(padp => padp, padn => padn, y => o);
  end generate;  
end;

-- pragma translate_off
library proasic3;
use proasic3.inbuf;
use proasic3.inbuf_pci;
-- pragma translate_on
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity apa3_inpad is
  generic (level : integer := 0; voltage : integer := 0;
           filter : integer := 0);
  port (pad : in std_ulogic; o : out std_ulogic);
end; 
architecture rtl of apa3_inpad is
  component inbuf port(pad : in std_ulogic; y : out std_ulogic); end component;
  component inbuf_pci port(pad : in std_ulogic; y : out std_ulogic); end component;
  attribute syn_tpd11 : string;
  attribute syn_tpd11 of inbuf_pci : component is "pad -> y = 2.0";
begin
  pci0 : if level = pci33 generate
    ip : inbuf_pci port map (pad => pad, y => o);
  end generate;
  gen0 : if level /= pci33 generate
    ip : inbuf port map (pad => pad, y => o);
  end generate;
end;

-- pragma translate_off
library proasic3;
use proasic3.inbuf_lvds;
use proasic3.inbuf_lvpecl;
-- pragma translate_on
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity apa3_inpad_ds is
  generic (level : integer := lvds);
  port (padp, padn : in std_ulogic; o : out std_ulogic);
end;
architecture rtl of apa3_inpad_ds is 
  component inbuf_lvds port(padp, padn : in std_ulogic; y : out std_ulogic); end component;
  component inbuf_lvpecl port(padp, padn : in std_ulogic; y : out std_ulogic); end component;
begin
  lvpecl0 : if level = lvpecl generate
    ip: inbuf_lvpecl port map (y => o, padp => padp, padn => padn);
  end generate;
  lvds0 : if level /= lvpecl generate
    ip: inbuf_lvds port map (y => o, padp => padp, padn => padn);
  end generate;
end;

-- pragma translate_off
library proasic3;
use proasic3.bibuf;
use proasic3.bibuf_pci;
-- pragma translate_on
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity apa3_iopad  is
  generic (level : integer := 0; slew : integer := 0;
	   voltage : integer := 0; strength : integer := 0;
           filter : integer := 0);
  port (pad : inout std_ulogic; i, en : in std_ulogic; o : out std_ulogic);
end ;
architecture rtl of apa3_iopad is
  component bibuf port(d, e : in std_ulogic; pad : inout std_ulogic; y : out std_ulogic); end component;
  component bibuf_pci port(d, e : in std_ulogic; pad : inout std_ulogic; y : out std_ulogic); end component;
  attribute syn_tpd12 : string; 
  attribute syn_tpd12 of bibuf_pci : component is "pad -> y = 2.0";
begin
  pci0 : if level = pci33 generate
    iop : bibuf_pci port map (d => i, e => en, pad => pad, y => o);
  end generate;
  gen0 : if level /= pci33 generate
    iop : bibuf port map (d => i, e => en, pad => pad, y => o);
  end generate;
end;

-- pragma translate_off
library proasic3;
use proasic3.bibuf_lvds;
--use proasic3.bibuf_lvpecl;
-- pragma translate_on
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity apa3_iopad_ds  is
  generic (level : integer := lvds);
  port (padp, padn : inout std_ulogic; i, en : in std_ulogic; o : out std_ulogic);
end ;
architecture rtl of apa3_iopad_ds is
  component bibuf_lvds port(d, e : in std_ulogic; padp, padn : inout std_ulogic; y : out std_ulogic); end component;
  component bibuf_lvpecl port(d, e : in std_ulogic; padp, padn : inout std_ulogic; y : out std_ulogic); end component;
begin
--  lvpecl0 : if level = lvpecl generate
    iop : bibuf_lvds port map (d => i, e => en, padp => padp, padn => padn, y => o);
--  end generate;
--  lvds0 : if level /= lvpecl generate
--    iop : bibuf_lvpecl port map (d => i, e => en, padp => padp, padn => padn, y => o);
--  end generate;
end;

-- pragma translate_off
library proasic3;
use proasic3.outbuf;
use proasic3.outbuf_pci;
-- pragma translate_on
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity apa3_outpad  is
  generic (level : integer := 0; slew : integer := 0;
	   voltage : integer := 0; strength : integer := 0);
  port (pad : out std_ulogic; i : in std_ulogic);
end ;
architecture rtl of apa3_outpad is
  component outbuf port(d : in std_ulogic; pad : out std_ulogic); end component;
  component outbuf_pci port(d : in std_ulogic; pad : out std_ulogic); end component;
  attribute syn_tpd13 : string; 
  attribute syn_tpd13 of outbuf_pci : component is "d -> pad = 2.0";
begin
  pci0 : if level = pci33 generate
    op : outbuf_pci port map (d => i, pad => pad);
  end generate;
  gen0 : if level /= pci33 generate
    op : outbuf port map (d => i, pad => pad);
  end generate;
end;

-- pragma translate_off
library proasic3;
use proasic3.outbuf_lvds;
use proasic3.outbuf_lvpecl;
-- pragma translate_on
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity apa3_outpad_ds is
  generic (level : integer := lvds);
  port (padp, padn : out std_ulogic; i : in std_ulogic);
end;
architecture rtl of apa3_outpad_ds is
  component outbuf_lvds port(d : in std_ulogic; padp, padn : out std_ulogic); end component;
  component outbuf_lvpecl port(d : in std_ulogic; padp, padn : out std_ulogic); end component;
begin
  lvpecl0 : if level = lvpecl generate
    op: outbuf_lvpecl port map (d => i, padp => padp, padn => padn);
  end generate;
  lvds0 : if level /= lvpecl generate
    op: outbuf_lvds port map (d => i, padp => padp, padn => padn);
  end generate;
end;

-- pragma translate_off
library proasic3;
use proasic3.tribuff;
use proasic3.tribuff_pci;
-- pragma translate_on
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity apa3_toutpad  is
  generic (level : integer := 0; slew : integer := 0;
	   voltage : integer := 0; strength : integer := 0);
  port (pad : out std_ulogic; i, en : in std_ulogic);
end ;
architecture rtl of apa3_toutpad is
  component tribuff port(d, e : in std_ulogic; pad : out std_ulogic); end component;
  component tribuff_pci port(d, e : in std_ulogic; pad : out std_ulogic); end component;
  attribute syn_tpd14 : string; 
  attribute syn_tpd14 of tribuff_pci : component is "d,e -> pad = 2.0";
begin
  pci0 : if level = pci33 generate
    top : tribuff_pci port map (d => i, e => en, pad => pad);
  end generate;
  gen0 : if level /= pci33 generate
    top : tribuff port map (d => i, e => en, pad => pad);
  end generate;
end;

-- pragma translate_off
library proasic3;
use proasic3.tribuff_lvds;
--use proasic3.tribuff_lvpecl;
-- pragma translate_on
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity apa3_toutpad_ds  is
  generic (level : integer := 0);
  port (padp, padn : out std_ulogic; i, en : in std_ulogic);
end ;
architecture rtl of apa3_toutpad_ds is
  component tribuff_lvds port(d, e : in std_ulogic; padp, padn : out std_ulogic); end component;
--  component tribuff_lvpecl port(d, e : in std_ulogic; padp, padn : out std_ulogic); end component;
begin
--  lvpecl0 : if level = lvpecl generate
--    top : tribuff_lvpecl port map (d => i, e => en, padp => padp, padn => padn);
--  end generate;
--  lvds0 : if level /= lvpecl generate
    top : tribuff_lvds port map (d => i, e => en, padp => padp, padn => padn);
--  end generate;
end;
