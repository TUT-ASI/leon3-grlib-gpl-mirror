------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
-- Entity:  grpci2_cdc_gate
-- File:    grpci2_cdc_gate.vhd
-- Author:  Nils-Johan Wessman - Aeroflex Gaisler
-- Description: CDC gete 
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library techmap;
use techmap.gencomp.all;

entity grpci2_cdc_gate is
  generic (
    tech  : integer;
    width : integer := 1;
    arch  : integer := 0);
  port (
    i   : in  std_logic;
    en  : in  std_logic;
    o   : out std_logic);
end;

architecture rtl of grpci2_cdc_gate is
begin
  
  arch0 : if arch = 0 generate
    o <= i; 
  end generate;
  
  arch1 : if arch = 1 generate
    n: grand2
      generic map (tech => tech)
      port map (i0 => i, i1 => en, q => o);
  end generate;

  arch2 : if arch = 2 generate
    o <= i and en; 
  end generate;
end;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library techmap;
use techmap.gencomp.all;

entity grpci2_cdc_gatev is
  generic (
    tech  : integer;
    width : integer := 1;
    arch  : integer := 0);
  port (
    i   : in  std_logic_vector(width-1 downto 0);
    en  : in  std_logic;
    o   : out std_logic_vector(width-1 downto 0));
end;

architecture rtl of grpci2_cdc_gatev is
begin
  
  arch0 : if arch = 0 generate
    nloop: for j in width-1 downto 0 generate
      o(j) <= i(j); 
    end generate;
  end generate;
  
  arch1 : if arch = 1 generate
    nloop: for j in width-1 downto 0 generate
      n: grand2
        generic map (tech => tech)
        port map (i0 => i(j), i1 => en, q => o(j));
    end generate;
  end generate;
  
  arch2 : if arch = 2 generate
    nloop: for j in width-1 downto 0 generate
      o(j) <= i(j) and en; 
    end generate;
  end generate;
end;

