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
-- Entity:      snoopmem5
-- File:        snoopmem5.vhd
-- Author:      Magnus Hjorth - Cobham Gaisler
-- Description: Memory instantiations for snoop tags
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.l5nv_shared.all;
library techmap;
use techmap.gencomp.all;

entity snoopmem5 is
  generic (
    tech      : integer range 0 to NTECH;
    dways     : integer range 1 to 4;
    didxwidth : integer range 1 to 10;
    dtagwidth : integer range 1 to 32;
    dtagconf  : integer range 0 to 2;
    testen    : integer range 0 to 1
    );
  port (
    rstn  : in  std_ulogic;
    sclk  : in  std_ulogic;
    sni   : in  snoopram_in_type5;
    sno   : out snoopram_out_type5;
    testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
    );
end;


architecture rtl of snoopmem5 is

begin

  dtagconf02: if dtagconf=0 or dtagconf=2 generate
    -- two memories (1x two-port, 1x one-port), valid bits in two-port memory
    -- or
    -- 2 x single-port memory, valid bits in flip flops
    -- Tag read for snooping
    dtagloop: for s in 0 to dways-1 generate
      dtagsmem: syncram
        generic map (
          tech     => tech,
          abits    => didxwidth,
          dbits    => dtagwidth-1,
          testen   => testen,
          pipeline => 0,
          rdhold   => 1,
          gatedwr  => 1,
          custombits => memtest_vlen
          )
        port map (
          clk      => sclk,
          address  => sni.dtagsindex(didxwidth-1 downto 0),
          datain   => sni.dtagsdin(s)(dtagwidth-1 downto 1),
          dataout  => sno.dtagsdout(s)(dtagwidth-1 downto 1),
          enable   => sni.dtagsen(s),
          write    => sni.dtagswrite,
          testin   => testin
          );
      sno.dtagsdout(s)(TAGMAX-1 downto dtagwidth) <= (others => '0');
      sno.dtagsdout(s)(0) <= '1';
    end generate;
  end generate;
  
  dtagconf1: if dtagconf=1 generate
  -- 1 x dual-port memory, valid bits in flip flops
  -- Shared dual-port tag RAM is in cachemem5 block
  end generate;
end;
