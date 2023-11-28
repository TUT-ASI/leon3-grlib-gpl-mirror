------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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
-- Entity:      kanatalog
-- File:        kanatalog.vhd
-- Author:      Francisco Bas, Frontgrade Gaisler AB
-- Description: Kanata log generator for pipeline visualization.
--              This entity generates a log with kanata format that can
--              be open with Konata instruction pipeline visualizer. 
--              The Kanata format consist on several instructions that 
--              instruct the visualizer on how to represent the pipeline.
--              More information in: https://github.com/shioyadan/Konata
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library gaisler;
library grlib;
use grlib.stdlib.all;
use grlib.riscv_disas.all;


entity kanatalog is
end;

