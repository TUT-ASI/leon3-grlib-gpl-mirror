------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
-- Entity:      noelv_pma_cfg
-- File:        noelv_pma_cfg.vhd
-- Author:      Nils Wessman Cobham Gaisler AB
-- Description: NOEL-V PMA configuration
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.noelv.all;

package noelv_pma_cfg is
  
  -- Word 0: High type   00        01  10  11
  -- Word 1: Low       unallocated I/O RAM ROM
  -- Word 2: Cacheable (if RAM/ROM)
  -- Word 3: Wide bus
  constant pma_data_mask : word64_arr(0 to PMAENTRIES-1) := (
    -- 0x00000000-0x7fffffff RAM   cacheable wide 
    -- 0x80000000-0x9fffffff ROM   cacheable      
    -- 0xa0000000-0xafffffff I/O  uncacheable     
    -- 0xb0000000-0xbfffffff I/O uncacheable wide 
    -- 0xc0000000-0xcfffffff ROM   cacheable      
    -- 0xd0000000-0xffffffff I/O uncacheable      
    x"00000000000013ff",      -- High type
    x"000000000000ff00",      -- Low
    x"00000000000013ff",      -- Cacheable
    x"00000000000008ff",      -- Wide bus (as in various config_local)
    others => zerow64
  );



end;

package body noelv_pma_cfg is
end;
