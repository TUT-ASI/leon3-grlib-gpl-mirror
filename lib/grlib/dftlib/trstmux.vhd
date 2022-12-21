------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity:      synciotest
-- File:        synciotest.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: Generic test-reset mux block
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

entity trstmux is
  generic (
    scantest : integer
    );
  port (
    arsti    : in  std_ulogic;
    testrst  : in  std_ulogic;
    testen   : in  std_ulogic;
    arsto    : out std_ulogic
    );
end;

architecture rtl of trstmux is
begin

  arsto <= arsti when (scantest=0 or testen='0') else testrst;

end;
