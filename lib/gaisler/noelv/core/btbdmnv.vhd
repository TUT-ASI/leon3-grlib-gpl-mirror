------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
-- Entity: 	btbdmnv
-- File:	btbdmnv.vhd
-- Author:	Alen Bardizbanyan, Cobham Gaisler AB
-- Description:	Direct Mapped Branch Target Buffer to handle unaligned and
--              compressed instructions
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.stdlib.all;
use grlib.config_types.all;
use grlib.config.all;

library gaisler;
--use gaisler.noelv.all;
use gaisler.noelvint.nv_btb_in_type;
use gaisler.noelvint.nv_btb_out_type;

entity btbdmnv is
  generic (
    nentries    : integer range 1  to 32;   -- Number of Entries
    pcbits      : integer range 32 to 56;
    dissue      : integer range 0  to 1     -- Dual issue
    );
  port (
    clk         : in  std_ulogic;
    rstn        : in  std_ulogic;
    btbi        : in  nv_btb_in_type;
    btbo        : out nv_btb_out_type
    );
end btbdmnv;

architecture rtl of btbdmnv is

  constant INDEX_LOW  : integer := 2+dissue;
  constant INDEX_HIGH : integer := INDEX_LOW + log2ext(nentries) - 1;                                

  subtype target is std_logic_vector(PCBITS-1 downto 0);
  type btbtarget is array (0 to NENTRIES-1) of target;
  
  subtype tag is std_logic_vector(PCBITS-2-INDEX_HIGH downto 0);
  type btbtag is array (0 to NENTRIES-1) of tag;

  type lpc_a is array (0 to NENTRIES-1) of std_logic_vector(1 downto 0);

  type reg_type is record
    valid   : std_logic_vector(NENTRIES-1 downto 0);
    targets : btbtarget;
    tags    : btbtag;
    lpc     : lpc_a;
  end record;

  function lsb_hit(entry_pc : std_logic_vector(1 downto 0);
                   cur_pc   : std_logic_vector(1 downto 0))
    return std_logic is
    variable hit : std_logic := '0';
  begin
    if entry_pc = "11" then
      hit := '1';
    elsif entry_pc = "10" then
      if cur_pc = "00" or cur_pc = "01" or cur_pc = "10" then
        hit := '1';
      end if;
    elsif entry_pc = "01" then
      if cur_pc = "00" or cur_pc = "01" then
        hit := '1';
      end if;
    elsif cur_pc = "00" then
      hit := '1';
    end if;

    if dissue = 0 then
      hit := '0';
      if entry_pc(0) = '1' then
        hit := '1';
      elsif entry_pc(0) = '0' and cur_pc(0) = '0' then
        hit := '1';
      end if;
    end if;

    return hit;
  end;

  signal r, rin : reg_type;

begin  -- rtl

  comb : process(r, btbi, rstn)
    variable v          : reg_type;
    variable rtag       : tag;
    variable valid      : std_logic;
    variable hit        : std_ulogic;
    variable target     : std_logic_vector(btbo.rdata'length - 1 downto 0);
    variable rindex     : std_logic_vector(log2ext(nentries-1) downto 0);
    variable windex     : std_logic_vector(log2ext(nentries-1) downto 0);
    variable lpc        : std_logic_vector(1 downto 0);
  begin

    v := r;

    rindex := btbi.raddr(INDEX_HIGH downto INDEX_LOW);
    windex := btbi.waddr(INDEX_HIGH downto INDEX_LOW);

    hit := '0';
    target := (others=>'0');

    rtag  := r.tags(to_integer(unsigned(rindex)));
    valid := r.valid(to_integer(unsigned(rindex)));
    lpc   := r.lpc(to_integer(unsigned(rindex)));


    if valid = '1' then
      if rtag = btbi.raddr(PCBITS-1 downto INDEX_HIGH+1) then
        if lsb_hit(lpc,btbi.raddr(2 downto 1)) = '1' then
          hit     := '1';
        end if;
      end if;
    end if;

    if btbi.wen = '1' then
      v.valid(to_integer(unsigned(windex)))   := '1';
      v.tags(to_integer(unsigned(windex)))    := btbi.waddr(PCBITS-1 downto INDEX_HIGH+1);
      v.targets(to_integer(unsigned(windex))) := btbi.wdata(PCBITS-1 downto 0);
      v.lpc(to_integer(unsigned(windex)))     := btbi.waddr(2 downto 1);
    end if;

    -- Flush BTB
    if btbi.flush = '1' then
      v.valid   := (others => '0');
    end if;

    -- Reset
    if rstn = '0' then
      v.valid   := (others => '0');
    end if;

    target(PCBITS-1 downto 0) := r.targets(to_integer(unsigned(rindex)));

    rin         <= v;

    btbo.hit        <= hit;
    btbo.rdata      <= target;
    btbo.lpc        <= lpc;
    btbo.ralign     <= '0';

  end process;

  seq : process(clk, rstn)
  begin
    if rising_edge(clk) then
        r <= rin;
    end if;
  end process;

end rtl;
