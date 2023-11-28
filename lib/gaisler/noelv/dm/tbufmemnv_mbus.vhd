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
-- Entity: 	tbufmem_mbus
-- File:	  tbufmem_mbus.vhd
-- Author:	Nils Wessman
--          Måns Arildsson            
-- Description:	Multi-bus trace buffer memory
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.dmnvint.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.stdlib.all;

entity tbufmemnv_mbus is
  generic (
    tech     : integer := 0;
    tbuf     : integer := 0; -- trace buf size in kB (0 - no trace buffer)
    dwidth   : integer := 64; -- AHB data width
    nbus     : integer := 4;
    proc     : integer := 0;
    testen   : integer := 0
    );
  port (
    clk : in std_ulogic;
    trace_in  : in tracebuf_mbus_in_array;
    trace_out  : out tracebuf_mbus_out_array;
    testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
    );
end;

architecture rtl of tbufmemnv_mbus is

constant addrbits : integer := 6; -- TODO: Calculate the size from kB (DUPLICATE TO dbgmod5adv.vhd)
type enable_type is array (0 to nbus) of std_logic_vector(1 downto 0);
signal enable : enable_type;

begin

  mbus_trace_mem : for b in 0 to nbus generate
    enable(b) <= trace_in(b).enable & trace_in(b).enable;
    mem64 : for i in 0 to 4 generate -- 32x5 syncrams standard to cover 64-bit bus
      ram0 : syncram generic map (tech => tech, abits => addrbits, dbits => 32, testen => testen, custombits => memtest_vlen)
        port map ( clk, trace_in(b).addr(addrbits-1 downto 0), trace_in(b).data(((i*32)+31) downto (i*32)),
                  trace_out(b).data(((i*32)+31) downto (i*32)), trace_in(b).enable, trace_in(b).write(i), testin);
    end generate;

    mem128 : if dwidth > 64 generate -- extra data buffer for 128-bit bus 
      ram0 : syncram64 generic map (tech => tech, abits => addrbits, testen => testen, custombits => memtest_vlen)
      port map ( clk, trace_in(b).addr(addrbits-1 downto 0), trace_in(b).data(223 downto 160),
                trace_out(b).data(223 downto 160), enable(b), trace_in(b).write(6 downto 5), testin);
    end generate;

    nomem128 : if dwidth < 128 and proc = 0 generate -- no extra data buffer for 128-bit bus
      trace_out(b).data((223) downto (160)) <= (others => '0');
    end generate;
  end generate;


  -- mem32 : for i in 0 to 1+proc*2 generate  -- basic 128 buffer
  --   ram0 : syncram64 generic map (tech => tech, abits => addrbits, testen => testen, custombits => memtest_vlen)
  --     port map ( clk, trace_in.addr(addrbits-1 downto 0), trace_in.data(((i*64)+63) downto (i*64)),
  --         trace_out.data(((i*64)+63) downto (i*64)), enable, trace_in.write(i*2+1 downto i*2), testin);
  -- end generate;

  -- mem64 : if dwidth > 32 generate -- extra data buffer for 64-bit bus
  --   ram0 : syncram generic map (tech => tech, abits => addrbits, dbits => 32, testen => testen, custombits => memtest_vlen)
  --     port map ( clk, trace_in.addr(addrbits-1 downto 0), trace_in.data((128+31) downto 128),
  --         trace_out.data((128+31) downto 128), trace_in.enable, trace_in.write(7), testin);
  -- end generate;

  -- mem128 : if dwidth > 64 generate -- extra data buffer for 128-bit bus
  --   ram0 : syncram64 generic map (tech => tech, abits => addrbits, testen => testen, custombits => memtest_vlen)
  --     port map ( clk, trace_in.addr(addrbits-1 downto 0), trace_in.data((128+95) downto (128+32)),
  --         trace_out.data((128+95) downto (128+32)), enable, trace_in.write(6 downto 5), testin);

  -- end generate;

end;
  

