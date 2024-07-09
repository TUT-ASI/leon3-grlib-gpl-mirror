------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
-- Entity: 	btbnv
-- File:	btbnv.vhd
-- Author:	Andrea Merlo, Cobham Gaisler AB
-- Description:	Branch Target Buffer
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.log2ext;
library gaisler;
use gaisler.noelvint.nv_btb_in_type;
use gaisler.noelvint.nv_btb_out_type;
use gaisler.utilnv.u2i;
use gaisler.utilnv.u2vec;

entity btbnv is
  generic (
    nentries    : integer range 8  to 128;   -- Number of Entries
    nsets       : integer range 1  to 8;     -- Associativity
    pcbits      : integer range 32 to 56;
    ext_c       : integer range 0  to 1      -- C Base Extension Set
    );
  port (
    clk         : in  std_ulogic;
    rstn        : in  std_ulogic;
    btbi        : in  nv_btb_in_type;
    btbo        : out nv_btb_out_type
    );
end btbnv;

architecture rtl of btbnv is

  ----------------------------------------------------------------------------
  -- Functions
  ----------------------------------------------------------------------------

  ----------------------------------------------------------------------------
  -- Constants
  ----------------------------------------------------------------------------

  constant OFFSET       : integer := 3 - ext_c * 1 + log2ext(NSETS);
  constant NLINES       : integer := NENTRIES / NSETS;  -- Lines per Set
  constant INDEXBITS    : integer := log2ext(NLINES) + OFFSET;
  constant BTBTAG_HIGH  : integer := PCBITS - 1;
  constant BTBTAG_LOW   : integer := INDEXBITS;

  --constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant RESET_ALL    : boolean := true;

  ----------------------------------------------------------------------------
  -- Types
  ----------------------------------------------------------------------------

  subtype data is std_logic_vector(PCBITS-1 downto 0);
  type btbdata is array (0 to NENTRIES-1) of data;
  subtype tag is std_logic_vector(BTBTAG_HIGH - BTBTAG_LOW + 1 + log2ext(NSETS) downto 0);
  type btbtag is array (0 to NENTRIES-1) of tag;
  type bdata is array (0 to NSETS-1) of data;
  type btag is array (0 to NSETS-1) of tag;
  type blru is array (0 to NLINES-1) of std_logic_vector(NSETS-2 downto 0);

  type reg_type is record
    valid       : std_logic_vector(NENTRIES-1 downto 0);
    datatable   : btbdata;
    tagtable    : btbtag;
    tree        : blru;
    update      : std_ulogic;
    windex      : std_logic_vector(INDEXBITS-1 downto OFFSET);
    wtag        : tag;
    wdata       : data;
  end record;

  constant RES  : reg_type := (
    valid       => (others => '0'),
    datatable   => (others => (others => '0')),
    tagtable    => (others => (others => '0')),
    tree        => (others => (others => '0')),
    update      => '0',
    windex      => (others => '0'),
    wtag        => (others => '0'),
    wdata       => (others => '0')
    );

  signal r, rin : reg_type;

begin  -- rtl

  comb : process(r, btbi, rstn)
    variable v          : reg_type;
    variable rindex     : std_logic_vector(INDEXBITS-1 downto OFFSET);
    variable rtag       : tag;
    variable hit        : std_ulogic;
    variable align      : std_ulogic;
    variable target     : std_logic_vector(btbo.rdata'length - 1 downto 0);
    variable valid      : std_logic_vector(NSETS-1 downto 0);
    variable data       : bdata;
    variable tag        : btag;
    variable tagcheck   : std_logic_vector(NSETS-1 downto 0);
    variable wline      : std_logic_vector(log2ext(NSETS)-1 downto 0);
    variable rline      : std_logic_vector(log2ext(NSETS)-1 downto 0);
    variable wtree      : std_logic_vector(NSETS-2 downto 0);
    variable way        : integer range 0 to NSETS-1;
  begin

    v := r;

    -- Save btbi.raddr(2) and check in tag check

    -- Pseudo-LRU Policy (4-way example)

   --           are all 4 lines valid?
   --                /       \
   --              yes        no, use an invalid line
   --               |
   --               |
   --               |
   --          bit_0 == 0?            state | replace      ref to | next state
   --           /       \             ------+--------      -------+-----------
   --          y         n             00x  |  line_0      line_0 |    11_
   --         /           \            01x  |  line_1      line_1 |    10_
   --  bit_1 == 0?    bit_2 == 0?      1x0  |  line_2      line_2 |    0_1
   --    /    \          /    \        1x1  |  line_3      line_3 |    0_0
   --   y      n        y      n
   --  /        \      /        \        ('x' means       ('_' means unchanged)
   --line_0  line_1  line_2  line_3      don't care)


    -- Sample input signals
    rindex              := btbi.raddr(INDEXBITS-1 downto OFFSET);
    rtag                := btbi.raddr(BTBTAG_HIGH downto BTBTAG_LOW) & btbi.raddr(OFFSET-1 downto OFFSET-1-log2ext(NSETS));

    -- Sample BTB Update Signals
    if btbi.wen = '1' then
      v.update          := '1';
      v.windex          := btbi.waddr(INDEXBITS-1 downto OFFSET);
      v.wtag            := btbi.waddr(BTBTAG_HIGH downto BTBTAG_LOW) & btbi.waddr(OFFSET-1 downto OFFSET-1-log2ext(NSETS));
      v.wdata           := btbi.wdata(PCBITS-1 downto 0);
    end if;

    -- Search the tree in order to know the set to replace
    wtree               := r.tree(u2i(r.windex));
    wline               := (others => '0');
    if r.update = '1' then
      case NSETS is

        when 1 =>
          null;

        when 2 =>
          wline                        := not(wtree);
          v.tree(u2i(r.windex))        := wline;

        when 4 =>
          if wtree(0) = '0' then
            if wtree(1) = '0' then
              wline                    := u2vec(0, wline);
              v.tree(u2i(r.windex))(0) := '1';
              v.tree(u2i(r.windex))(1) := '1';
            else
              wline                    := u2vec(1, wline);
              v.tree(u2i(r.windex))(0) := '1';
              v.tree(u2i(r.windex))(1) := '0';
            end if;
          else
            if wtree(2) = '0' then
              wline                    := u2vec(2, wline);
              v.tree(u2i(r.windex))(0) := '0';
              v.tree(u2i(r.windex))(2) := '1';
            else
              wline                    := u2vec(3, wline);
              v.tree(u2i(r.windex))(0) := '0';
              v.tree(u2i(r.windex))(2) := '0';
            end if;
          end if;
          way                          := u2i(wline);

        when others =>
          null;

      end case; -- NSETS
    end if;

    if r.update = '1' then
      v.valid(u2i(r.windex & wline))     := '1';
      v.tagtable(u2i(r.windex & wline))  := r.wtag;
      v.datatable(u2i(r.windex & wline)) := r.wdata;
      v.update                           := '0';
    end if;

    -- Generate comparators
    rline               := (others => '0');
    for i in 0 to NSETS-1 loop
      if NSETS > 1 then
        rline           := u2vec(i, rline);
      end if;
      valid(i)          := r.valid(u2i(rindex & rline));
      data(i)           := r.datatable(u2i(rindex & rline));
      tag(i)            := r.tagtable(u2i(rindex & rline));
    end loop;

    -- Generate Output Signals
    hit             := '0';
    align           := '0';
    target          := (others => '0');
    way             := 0;
    for i in 0 to NSETS-1 loop
      -- Check for TAG
      tagcheck(i)   := '0';
      --if ((tag(i)(rtag'high downto 1) = rtag(rtag'high downto 1) and NSETS /= 1 and (tag(i)(0) = rtag(0) or (rtag(0) = '0' and tag(i)(0) = '1'))) or
      if (tag(i)(BTBTAG_HIGH - BTBTAG_LOW + 1 downto 1) = rtag(BTBTAG_HIGH - BTBTAG_LOW + 1 downto 1) and (tag(i)(0) = rtag(0) or (rtag(0) = '0' and tag(i)(0) = '1'))) then
      --if (rtag(0) = '1' and tag(i) = rtag) or (rtag(0) = '0' and tag(i)(BTBTAG_HIGH - BTBTAG_LOW + 1 downto 1) = rtag(BTBTAG_HIGH - BTBTAG_LOW + 1 downto 1) and tag(i)(0) = '1') then
        tagcheck(i) := '1';
      end if;
      if tagcheck(i) = '1' and valid(i) = '1' and hit = '0' then
        hit                       := '1';
        target(PCBITS-1 downto 0) := data(i);
        way                       := i;
        align                     := tag(i)(0);
      end if;
    end loop;

    -- Update Pseudo-LRU Tree
    if hit = '1' then
      case NSETS is

        when 1 =>
          null;

        when 2 =>
          v.tree(u2i(rindex))        := u2vec(way, v.tree(0));

        when 4 =>
          case way is
            when 0 =>
              v.tree(u2i(rindex))(0) := '1';
              v.tree(u2i(rindex))(1) := '1';
            when 1 =>
              v.tree(u2i(rindex))(0) := '1';
              v.tree(u2i(rindex))(1) := '0';
            when 2 =>
              v.tree(u2i(rindex))(0) := '0';
              v.tree(u2i(rindex))(2) := '1';
            when 3 =>
              v.tree(u2i(rindex))(0) := '0';
              v.tree(u2i(rindex))(2) := '0';
            when others =>
              null;
          end case; -- i

        when others =>
          null;

      end case; -- NSETS
    end if;

    if NSETS = 1 then
      v.tree    := (others => (others => '0'));
    end if;

    -- Output Signals
    btbo.hit    <= hit;
    btbo.rdata  <= target;
    btbo.ralign <= align;

    -- Flush BTB
    if btbi.flush = '1' then
      for i in 0 to NENTRIES-1 loop
        v.valid(i)              := '0';
      end loop;
    end if;

    -- Reset
    if not(RESET_ALL) and rstn = '0' then
      v         := RES;
    end if;

    rin         <= v;

    -- Asserts
    assert (NSETS = 1 or NSETS = 2 or NSETS = 4) report "Error, NSETS sleceted is not supported" severity failure;

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
