------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
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
-- Entity:        syncfifo_2p
-- File:          syncfifo_2p.vhd
-- Author:        Andrea Gianarro - Aeroflex Gaisler AB
-- Description:   Syncronous 2-port fifo with tech selection
------------------------------------------------------------------------------

library ieee;
library techmap;
use ieee.std_logic_1164.all;
use techmap.gencomp.all;
use work.allmem.all;
library grlib;
use grlib.config.all;
use grlib.config_types.all;
use grlib.stdlib.all;

entity syncfifo_2p is
  generic (
    tech  : integer := 0;
    abits : integer := 6;
    dbits : integer := 8
	);
  port (
    rclk    : in std_logic;
    renable : in std_logic;
    rfull   : out std_logic;
    rempty  : out std_logic;
    rusedw  : out std_logic_vector(abits-1 downto 0);
    dataout : out std_logic_vector(dbits-1 downto 0);
    wclk    : in std_logic;
    write   : in std_logic;
    wfull   : out std_logic;
    wempty  : out std_logic;
    wusedw  : out std_logic_vector(abits-1 downto 0);
    datain  : in std_logic_vector(dbits-1 downto 0)
  );
end;

architecture rtl of syncfifo_2p is
begin

  -- TO BE IMPLEMENTED
--  inf : if tech = inferred generate
--    x0 : generic_syncfifo_2p generic map (abits, dbits)
--         port map (rclk, renable, rfull, rempty, rusedw, dataout, wclk,
--           write, wfull, wempty, wusedw, datain);
--  end generate;

  alt : if (tech = altera) or (tech = stratix1) or (tech = stratix2) or
	(tech = stratix3) or (tech = stratix4) generate
    x0 : altera_fifo_dp generic map (tech, abits, dbits)
      port map (rclk, renable, rfull, rempty, rusedw, dataout, wclk,
        write, wfull, wempty, wusedw, datain);
  end generate;

-- pragma translate_off
  nofifo : if has_2pfifo(tech) = 0 generate
    x : process
    begin
      assert false report "syncfifo_2p: technology " & tech_table(tech) &
	" not supported"
      severity failure;
      wait;
    end process;
  end generate;
  dmsg : if GRLIB_CONFIG_ARRAY(grlib_debug_level) >= 2 generate
    x : process
    begin
      assert false report "syncfifo_2p: " & tost(2**abits) & "x" & tost(dbits) &
       " (" & tech_table(tech) & ")"
      severity note;
      wait;
    end process;
  end generate;
-- pragma translate_on

end;

