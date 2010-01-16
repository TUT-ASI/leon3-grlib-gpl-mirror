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
-------------------------------------------------------------------------------
-- Package:     at_ahs
-- File:        at_ahbs.vhd
-- Author:      Jan Andersson, Aeroflex Gaisler
-- Description: AMBA Test Framework - AHB slave for use in designs. Wraps
--              at_ahb_slv and does not propagate debug port. 
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.at_pkg.all;
use grlib.stdio.all;
use grlib.stdlib.all;
use grlib.testlib.all;

entity at_ahbs is
  
  generic (
    hindex        : integer := 0;       -- Slave index
    
    bank0addr     : integer := 0;
    bank0mask     : integer := 0;
    bank0type     : integer := 0;       -- 0: memory area 1: I/O area
    bank0cache    : integer := 0;       -- Cachable
    bank0prefetch : integer := 0;       -- Prefetchable
    bank0ws       : integer := 0;       -- Waitstates
    bank0rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
    bank0dataload : integer := 0;       -- Load data from file
    bank0datafile : string  := "none";  -- Initial data for bank
    
    bank1addr     : integer := 0;
    bank1mask     : integer := 0;
    bank1type     : integer := 0;       -- 0: memory area 1: I/O area
    bank1cache    : integer := 0;       -- Cachable
    bank1prefetch : integer := 0;       -- Prefetchable
    bank1ws       : integer := 0;       -- Waitstates
    bank1rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
    bank1dataload : integer := 0;       -- Load data from file
    bank1datafile : string  := "none";  -- Initial data for bank

    bank2addr     : integer := 0;
    bank2mask     : integer := 0;
    bank2type     : integer := 0;       -- 0: memory area 1: I/O area
    bank2cache    : integer := 0;       -- Cachable
    bank2prefetch : integer := 0;       -- Prefetchable
    bank2ws       : integer := 0;       -- Waitstates
    bank2rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
    bank2dataload : integer := 0;       -- Load data from file
    bank2datafile : string  := "none";  -- Initial data for bank

    bank3addr     : integer := 0;
    bank3mask     : integer := 0;
    bank3type     : integer := 0;       -- 0: memory area 1: I/O area
    bank3cache    : integer := 0;       -- Cachable
    bank3prefetch : integer := 0;       -- Prefetchable
    bank3ws       : integer := 0;       -- Waitstates
    bank3rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
    bank3dataload : integer := 0;       -- Load data from file
    bank3datafile : string  := "none"   -- Initial data for bank
    );
  port (
    rstn  : in  std_ulogic;
    clk   : in  std_ulogic;
    ahbsi : in  ahb_slv_in_type;
    ahbso : out ahb_slv_out_type
  );

end at_ahbs;

architecture sim of at_ahbs is

  signal dbgi  : at_slv_dbg_in_type;
  signal dbgo  : at_slv_dbg_out_type;

begin  -- sim
  
  ahbs : at_ahb_slv
    generic map (
      hindex        => hindex,
      bank0addr     => bank0addr,
      bank0mask     => bank0mask,
      bank0type     => bank0type,
      bank0cache    => bank0cache,
      bank0prefetch => bank0prefetch,
      bank0ws       => bank0ws,
      bank0rws      => bank0rws,
      bank0dataload => bank0dataload,
      bank0datafile => bank0datafile,
      bank1addr     => bank1addr,
      bank1mask     => bank1mask,
      bank1type     => bank1type,
      bank1cache    => bank1cache,
      bank1prefetch => bank1prefetch,
      bank1ws       => bank1ws,
      bank1rws      => bank1rws,
      bank1dataload => bank1dataload,
      bank1datafile => bank1datafile,
      bank2addr     => bank2addr,
      bank2mask     => bank2mask,
      bank2type     => bank2type,
      bank2cache    => bank2cache,
      bank2prefetch => bank2prefetch,
      bank2ws       => bank2ws,
      bank2rws      => bank2rws,
      bank2dataload => bank2dataload,
      bank2datafile => bank2datafile,
      bank3addr     => bank3addr,
      bank3mask     => bank3mask,
      bank3type     => bank3type,
      bank3cache    => bank3cache,
      bank3prefetch => bank3prefetch,
      bank3ws       => bank3ws,
      bank3rws      => bank3rws,
      bank3dataload => bank3dataload,
      bank3datafile => bank3datafile
      )
    port map (rstn => rstn, clk => clk, ahbsi => ahbsi, ahbso => ahbso,
              dbgi => dbgi, dbgo => dbgo);
  
end sim;
