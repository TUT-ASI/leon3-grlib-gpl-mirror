------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-- Entity: 	ras5
-- File:	ras5.vhd
-- Author:	Andrea Merlo, Cobham Gaisler AB
-- Description:	Return Address Stack
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.stdlib.all;
use grlib.config_types.all;
use grlib.config.all;

library gaisler;
use gaisler.noelv.XLEN;
use gaisler.noelvint.all;

entity rasnv is
  generic (
    depth       : integer range 0  to 8;   -- Stack Depth
    pchigh      : integer range 32 to 56   -- PC High Bit
    );
  port (
    clk         : in  std_ulogic;
    rstn        : in  std_ulogic;
    rasi        : in  nv_ras_in_type;
    raso        : out nv_ras_out_type
    );
end rasnv;

architecture rtl of rasnv is

  ----------------------------------------------------------------------------
  -- Functions
  ----------------------------------------------------------------------------

  ----------------------------------------------------------------------------
  -- Constants
  ----------------------------------------------------------------------------

  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

  ----------------------------------------------------------------------------
  -- Types
  ----------------------------------------------------------------------------

  subtype ra is std_logic_vector(PCHIGH-1 downto 0);
  type ras is array (0 to DEPTH-1) of ra;

  type reg_type is record
    stack       : ras;
    valid       : std_logic_vector(DEPTH-1 downto 0);
  end record;

  constant RES  : reg_type := (
    stack       => (others => (others => '0')),
    valid       => (others => '0')
    );

  signal r, rin : reg_type;

begin  -- rtl

  comb : process(r, rasi, rstn)
    variable v          : reg_type;
    variable valid      : std_ulogic;
    variable target     : std_logic_vector(XLEN-1 downto 0);

  begin

    v := r;

    -- Pop value from top of the stack
    if rasi.pop = '1' and rasi.push = '0' then
      v.valid(DEPTH-1)  := '0';
      for i in 0 to DEPTH-2 loop
        v.valid(i)      := r.valid(i+1);
        v.stack(i)      := r.stack(i+1);
      end loop;
    -- Push new value into the stack
    elsif rasi.push = '1' and rasi.pop = '0' then
      v.valid(0)        := '1';
      v.stack(0)        := rasi.wdata(PCHIGH-1 downto 0);
      for i in 1 to DEPTH-1 loop
        v.valid(i)      := r.valid(i-1);
        v.stack(i)      := r.stack(i-1);
      end loop;
    elsif rasi.pop = '1' and rasi.push = '1' then
    -- First pop, then push
    -- Swap data only for top of the stack
      v.stack(0)        := rasi.wdata(PCHIGH-1 downto 0);
    end if;

    -- Generate Output Signals
    target                      := (others => '0');
    target(PCHIGH-1 downto 0)   := r.stack(0);
    valid                       := r.valid(0);

    -- Output Signals
    raso.hit    <= valid;
    raso.rdata  <= target;

    -- Flush Stack
    if rasi.flush = '1' then
      for i in 0 to DEPTH-1 loop
        v.valid(i)      := '0';
      end loop;
    end if;

    -- Reset
    if not(RESET_ALL) and rstn = '0' then
      v         := RES;
    end if;

    rin         <= v;

  end process;

  seq : process(clk, rstn)
  begin
    if rising_edge(clk) then
      if RESET_ALL and rstn = '0' then
        r <= RES;
      else
        r <= rin;
      end if;
    end if;

  end process;

end rtl;
