------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity: 	tbufmem
-- File:	tbufmem.vhd
-- Author:	Jiri Gaisler - Gaisler Research
--              Andrea Merlo, Cobham Gaisler AB
-- Description:	512-bit trace buffer memory (CPU/AHB)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.noelvint.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.stdlib.all;

entity tbufmemnv is
  generic (
    tech        : integer := 0;
    tbuf        : integer := 0;  -- trace buf size in kB (0 - no trace buffer)
    dwidth      : integer := 64; -- AHB data width
    proc        : integer := 0;
    testen      : integer := 0
    );
  port (
    clk         : in  std_ulogic;
    di          : in  nv_trace_in_type;
    do          : out nv_trace_out_type;
    testin      : in  std_logic_vector(TESTIN_WIDTH-1 downto 0)
    );


end;

architecture rtl of tbufmemnv is

  -- Functions --------------------------------------------------------------
  function getnrams return integer is
    variable v: integer;
  begin
    v := 2;
    if dwidth > 32 then v:=v+1; end if;
    if dwidth > 64 then v:=v+1; end if;
    return v;
  end getnrams;

  -- Constants --------------------------------------------------------------
  --constant ADDRBITS     : integer := 10 - 10*(tbuf/16#10000#) + log2(tbuf mod 16#10000#) - 4 - proc;
  --constant ADDRBITS     : integer := 10 + log2(tbuf) - 4 - proc;
  constant ADDRBITS     : integer := 4 + log2(tbuf);
  constant nrams        : integer := getnrams;
  constant TRACE_CELLS  : integer := 7;
  
  -- Types ------------------------------------------------------------------
  
  -- Signals ----------------------------------------------------------------
  signal enable         : std_logic_vector(1 downto 0);

begin

  enable <= di.enable & di.enable;

 -- Syncrams ----------------------------------------------------------------
 mem64 : for i in 0 to TRACE_CELLS-1 generate -- build the 512-bit trace buffer
  ram0 : syncram64
    generic map (
      tech      => tech,
      abits     => addrbits,
      testen    => testen,
      custombits=> memtest_vlen
      )
    port map (
      clk       => clk,
      address   => di.addr(addrbits-1 downto 0),
      datain    => di.data((i*64)+63 downto i*64),
      dataout   => do.data((i*64)+63 downto i*64),
      enable    => enable,
      write     => di.write(i*2+1 downto i*2),
      testin    => testin
    );
  end generate;
  do.data(do.data'high downto 64*TRACE_CELLS) <= (others => '0');
  
  -- Drive test signals
  
end;
  

