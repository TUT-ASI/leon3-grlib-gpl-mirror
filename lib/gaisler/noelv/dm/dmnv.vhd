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
-- Entity:      dmnv
-- File:        dmnv.vhd
-- Author:      Nils Wessman
-- Description: NOEL-V debug module
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.noelv.XLEN;
use gaisler.noelv.nv_dm_in_type;
use gaisler.noelv.nv_dm_out_type;
use gaisler.noelv.nv_debug_in_vector;
use gaisler.noelv.nv_debug_out_vector;
use gaisler.dmnvint.all;

entity dmnv is
  generic (
    fabtech   : integer;
    memtech   : integer;
    ncpu      : integer;
    ndbgmst   : integer;
    -- Conventional bus
    cbmidx    : integer;
    -- PnP
    dmhaddr   : integer;
    dmhmask   : integer;
    pnpaddrhi : integer;
    pnpaddrlo : integer;
    dmslvidx  : integer;
    dmmstidx  : integer;
    -- trace
    tbits     : integer;
    --
    scantest  : integer;
    -- Pipelining
    plmdata   : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    -- Debug-link interface
    dbgmi    : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
    dbgmo    : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
    -- Conventional AHB bus interface
    cbmi    : in  ahb_mst_in_type;
    cbmo    : out ahb_mst_out_type;
    cbsi    : in  ahb_slv_in_type;
    -- 
    dbgi   : in  nv_debug_out_vector(0 to ncpu-1);
    dbgo   : out nv_debug_in_vector(0 to ncpu-1);
    dsui   : in  nv_dm_in_type;
    dsuo   : out nv_dm_out_type
    );
end;

architecture rtl of dmnv is
  signal dmmi : ahb_mst_in_type;
  signal dmmo : ahb_mst_out_type;
  signal dmsi : ahb_slv_in_type;
  signal dmso : ahb_slv_out_type;

  signal dmi  : dev_reg_in_type;
  signal dmo  : dev_reg_out_type;
  signal tri  : dev_reg_in_type;
  signal tro  : dev_reg_out_type;
begin
  intercnct : entity work.dmnv_ic
    generic map (
      ndmamst   => ndbgmst,
      -- conv bus
      cbmidx    => cbmidx,
      -- PnP
      dmhaddr   => dmhaddr,
      dmhmask   => dmhmask,
      pnpaddrhi => pnpaddrhi,
      pnpaddrlo => pnpaddrlo,
      dmslvidx  => dmslvidx,
      dmmstidx  => dmmstidx
      -- pipelining 
      --, plmdata   => plmdata
    )
    port map(
      clk     => clk,
      rstn    => rstn,
      -- Debug-link interface
      dmami   => dbgmi,
      dmamo   => dbgmo,
      -- Conventional AHB bus interface
      cbmi    => cbmi,
      cbmo    => cbmo,
      cbsi    => cbsi,
      -- Debug-module AHB bus interface
      dmmi    => dmmi,
      dmmo    => dmmo
    );

  con_dm : process(dmso, dmmo)
  begin
    dmmi        <= ahbm_in_none;
    dmmi.hgrant <= (others => '1');
    dmmi.hready <= dmso.hready;
    dmmi.hresp  <= dmso.hresp;
    dmmi.hrdata <= dmso.hrdata;

    dmsi          <= ahbs_in_none;
    dmsi.hsel(dmslvidx) <= dmmo.htrans(1);
    dmsi.haddr    <= dmmo.haddr;
    dmsi.hwrite   <= dmmo.hwrite;
    dmsi.htrans   <= dmmo.htrans;
    dmsi.hsize    <= dmmo.hsize;
    dmsi.hburst   <= dmmo.hburst;
    dmsi.hwdata   <= dmmo.hwdata;
    dmsi.hready   <= dmso.hready;
  end process;

  ahbs_if : entity work.dmnv_ahbs
    generic map(
      hindex    => dmslvidx,
      haddr     => dmhaddr,
      hmask     => dmhmask,
      scantest  => scantest)
    port map(
      clk     => clk,
      rstn    => rstn,
      ahbsi   => dmsi,
      ahbso   => dmso,
      -- DM interface
      dmi     => dmi,
      dmo     => dmo,
      -- Trace interface
      tri     => tri,
      tro     => tro);

  debug_module : entity work.dmnvx
    generic map(
      nharts          => ncpu,
      datacount       => 4,
      nscratch        => 2,
      unavailtimeout  => 64,
      progbufsize     => 8,
      scantest        => scantest
    )
    port map(
      clk    => clk,
      rstn   => rstn,
      dmi    => dmi,
      dmo    => dmo,
      dbgi   => dbgi,
      dbgo   => dbgo,
      dsui   => dsui,
      dsuo   => dsuo 
    );
  
  bus_trace : entity work.dmnv_trace
    generic map(
      fabtech   => fabtech,
      memtech   => memtech,
      kbytes    => 4,
      ahbwp     => 2,
      tbits     => tbits,
      scantest  => scantest)
    port map(
      clk         => clk,
      rstn        => rstn,
      tri         => tri,
      tro         => tro,
      cbmi        => cbmi,
      cbsi        => cbsi,
      timer       => dbgi(0).mcycle(tbits-1 downto 0)
    );
end;
