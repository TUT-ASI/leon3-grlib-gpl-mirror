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
-- Entity:      pbuf
-- File:        pbuf.vhd
-- Author:      Nils Wessman, Cobham Gaisler AB
-- Description: NOEL-V Program buffer
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.noelvint.all;

entity progbuf is
  generic (
    size : integer range 0 to 16
  );
  port (
    clk   : in  std_ulogic;
    rstn  : in  std_ulogic;
    pbi   : in  nv_progbuf_in_type;
    pbo   : out nv_progbuf_out_type
  );
end;

architecture rtl of progbuf is
  type progbuf_type is array (0 to size/2-1) of word64;
  signal r, rin : progbuf_type;
begin
  comb : process(r, pbi)
    variable v          : progbuf_type;
    variable idx, eidx  : integer;
  begin
    v := r;

    idx   := to_integer(unsigned(pbi.addr(pbi.addr'high downto 1)));
    eidx  := to_integer(unsigned(pbi.eaddr(pbi.eaddr'high downto 1)));

    if (idx < size/2) and (size /= 0) then
      if pbi.addr(0) = '0' then
        pbo.data <= r(idx)(31 downto 0);
        if pbi.write = '1' then
          v(idx)(31 downto  0) := pbi.data;
        end if;
      else
        pbo.data <= r(idx)(63 downto 32);
        if pbi.write = '1' then
          v(idx)(63 downto 32) := pbi.data;
        end if;
      end if;
    else
      -- EBREAK
      pbo.data <= x"00100073";
    end if;

    if (size /= 0) and (eidx < size/2) then
      pbo.edata <= r(eidx);
    else
      -- EBREAK
      pbo.edata <= x"0010007300100073";
    end if;

    rin <= v;
  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if rstn = '0' then
        -- EBREAK
        r <= (others => x"0010007300100073");
      end if;
    end if;
  end process;
end;
