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
-- Entity:      arbiter_tree
-- File:        arbiter_tree.vhd
-- Author:      Martin Caous George, Frontgrade Gaisler
-- Description: A combinatorial arbiter tree with several priority settings.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.axi.all;

entity arbiter_tree is
  generic (
    nreq      : integer;
    dwidth    : integer;
    arb_prio  : integer range 0 to 2; -- 0 -> sprio, 1 -> Rotate prio, 2 -> Round robin
    arb_lock  : integer range 0 to 1  -- 0 -> Make arbiter decision on grant
                                      -- 1 -> Make arbiter decision on first valid request
  );
  port (
    clk     : in  std_ulogic;
    rstn    : in  std_ulogic;
    -- Subordinate
    sprio   : in  std_logic_vector(log2x(nreq)-1 downto 0) := (others => '0');
    sdata   : in  std_logic_vector(nreq*dwidth-1 downto 0);
    sreq    : in  std_logic_vector(nreq-1 downto 0);
    sgnt    : out std_logic_vector(nreq-1 downto 0);
    -- Manager
    msel    : out std_logic_vector(log2x(nreq)-1 downto 0);
    mdata   : out std_logic_vector(dwidth-1 downto 0);
    mreq    : out std_ulogic;
    mgnt    : in  std_ulogic
  );
end;

architecture rtl of arbiter_tree is

  constant ASYNC_RST : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  function cond(expr : boolean; a, b : std_ulogic) return std_ulogic is
  begin
    if expr then return a; else return b; end if;
  end function;

  function cond(expr : boolean; a, b : std_logic_vector) return std_logic_vector is
  begin
    if expr then return a; else return b; end if;
  end function;

  constant lvls : integer := log2x(nreq);

  type reg_type is record
    req_lock  : std_logic_vector(nreq-1 downto 0);
    prio      : std_logic_vector(log2x(nreq)-1 downto 0);
  end record;

  constant RST : reg_type := (
    req_lock  => (others => '1'),
    prio      => (others => '0')
  );

  type branch_type is record
    req   : std_ulogic;
    gnt   : std_ulogic;
    sel   : std_ulogic;
    data  : std_logic_vector(dwidth-1 downto 0);
    idx   : std_logic_vector(log2x(nreq)-1 downto 0);
  end record;
  type tree_type is array(0 to 2**lvls-2) of branch_type;

  type data_array is array(0 to nreq-1) of std_logic_vector(dwidth-1 downto 0);

  signal r, rin : reg_type;

begin

  p_comb : process(r, rstn, sprio, sdata, sreq, mgnt)
    variable v        : reg_type;
    variable curr     : integer;
    variable prev     : integer;
    variable idxhi    : integer;
    variable tree     : tree_type;
    variable prio     : std_logic_vector(lvls-1 downto 0);
    variable data     : data_array;
    variable req      : std_logic_vector(nreq-1 downto 0);
    variable gnt      : std_logic_vector(nreq-1 downto 0);
    variable mask_lo  : std_logic_vector(nreq-1 downto 0);
    variable mask_hi  : std_logic_vector(nreq-1 downto 0);
    variable prio_lo  : std_logic_vector(lvls-1 downto 0);
    variable prio_hi  : std_logic_vector(lvls-1 downto 0);
  begin
    v := r;

    for i in 0 to nreq-1 loop
      data(i) := sdata((i+1)*dwidth-1 downto i*dwidth);
    end loop;

    req := sreq;
    if arb_lock /= 0 then
      req := sreq and r.req_lock;
    end if;

    prio := sprio;
    if arb_prio /= 0 then
      prio := r.prio;
    end if;

    -- Loop top to bottom (requests)
    for i in lvls-1 downto 0 loop
      for j in 2**i-1 downto 0 loop
        curr  := 2**i-1+j;        -- Current branch
        prev  := 2**(i+1)+2*j-1;  -- Previous branch
        idxhi := lvls-i-1;        -- Index high bit for the current level
        if i = lvls-1 then
          -- Top level
          if 2*j < nreq-1 then
            tree(curr).req  := req(2*j+1) or req(2*j);
            tree(curr).sel  := not req(2*j) or (req(2*j+1) and prio(idxhi));
            tree(curr).data := cond(tree(curr).sel = '1', data(2*j+1), data(2*j));
          elsif 2*j = nreq-1 then
            tree(curr).req  := req(2*j);
            tree(curr).sel  := '0';
            tree(curr).data := data(2*j);
          else
            tree(curr).req  := '0';
            tree(curr).sel  := '0';
            tree(curr).data := (others => '0');
          end if;
          tree(curr).idx(idxhi) := tree(curr).sel;
        else
          tree(curr).req  := tree(prev).req or tree(prev+1).req;
          tree(curr).sel  := not tree(prev).req or (tree(prev+1).req and prio(idxhi));
          tree(curr).data := cond(tree(curr).sel = '1', tree(prev+1).data, tree(prev).data);
          if tree(curr).sel = '1' then
            tree(curr).idx(idxhi downto 0) := '1' & tree(prev+1).idx(idxhi-1 downto 0);
          else
            tree(curr).idx(idxhi downto 0) := '0' & tree(prev).idx(idxhi-1 downto 0);
          end if;
        end if;
      end loop;
    end loop;

    -- Loop bottom to top (grants)
    tree(0).gnt := mgnt;
    for i in 0 to lvls-1 loop
      for j in 0 to 2**i-1 loop
        curr  := 2**i-1+j;        -- Current branch
        prev  := 2**(i+1)+2*j-1;  -- Previous branch
        if i = lvls-1 then
          -- Top level
          if 2*j < nreq-1 then
            gnt(2*j)    := tree(curr).gnt and not tree(curr).sel;
            gnt(2*j+1)  := tree(curr).gnt and tree(curr).sel;
          elsif 2*j = nreq-1 then
            gnt(2*j)    := tree(curr).gnt;
          end if;
        else
          tree(prev).gnt    := tree(curr).gnt and not tree(curr).sel;
          tree(prev+1).gnt  := tree(curr).gnt and tree(curr).sel;
        end if;
      end loop;
    end loop;

    if arb_lock /= 0 then
      if tree(0).req = '1' and mgnt = '1' then
        -- Request granted, release lock
        v.req_lock := (others => '1');
      elsif tree(0).req = '1' then
        -- Lock request on first valid request
        v.req_lock := req;
      end if;
    end if;

    if arb_prio /= 0 then
      if tree(0).req = '1' and mgnt = '1' then
      -- Update priority on granted request
        case arb_prio is
        when 1 =>
          -- Rotating priority
          v.prio := std_logic_vector(unsigned(r.prio)+1);
          if 2**log2(nreq) /= nreq and unsigned(r.prio) = nreq-1 then
            v.prio := (others => '0');
          end if;
        when 2 =>
          -- Round robin priority
          mask_lo := (others => '0');
          mask_hi := (others => '0');
          for i in 0 to nreq-1 loop
            mask_lo(i) := cond(i <= unsigned(r.prio), req(i), '0');
            mask_hi(i) := cond(i > unsigned(r.prio), req(i), '0');
          end loop;
          prio_lo := ctz(mask_lo);
          prio_hi := ctz(mask_hi);
          v.prio  := cond(any_set(mask_hi) = '0', prio_lo, prio_hi);
        when others =>
        end case;
      end if;
    end if;

    if not ASYNC_RST and rstn = '0' then
      v := RST;
    end if;

    rin <= v;

    -- Assign outputs
    sgnt  <= gnt;
    msel  <= tree(0).idx;
    mreq  <= tree(0).req;
    mdata <= tree(0).data;
  end process;

  p_reg : process(clk, rstn)
  begin
    if ASYNC_RST and rstn = '0' then
      r <= RST;
    elsif rising_edge(clk) then
      r <= rin;
    end if;
  end process;

end;