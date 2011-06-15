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
-- Entity: 	Various
-- File:	grgates.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Description:	Various gates with tech mapping
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;
use work.allclkgen.all;

entity grmux2 is generic( tech : integer := inferred; imp :  integer := 0);
  port( ip0, ip1, sel : in std_logic; op : out std_ulogic); end;

architecture rtl of grmux2 is

begin

  rhlib : if tech = rhlib18t generate
    x0 : clkmux_rhlib18t port map (i0 => ip0, i1 => ip1, sel => sel, o => op);
  end generate;

  ut13 : if tech = ut130 generate
    x0 : clkmux_ut130hbd port map (i0 => ip0, i1 => ip1, sel => sel, o => op);
  end generate;

  behav : if (tech /= rhlib18t) and (tech /= ut130)  generate
    op <= ip0 when sel = '0' else ip1;
  end generate;

end;
