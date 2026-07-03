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
-- Entity:      axi4mux
-- File:        axi4mux.vhd
-- Author:      Martin Caous George - Frontgrade Gaisler AB
-- Description: AXI demultiplexer
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.axi.all;

entity axi4demux is
  generic (
    nmanports   : integer;
    maxtrans    : integer;
    awidth      : integer;
    dwidth      : integer;
    idwidth     : integer;
    axuserwidth : integer;
    wuserwidth  : integer;
    buserwidth  : integer;
    ruserwidth  : integer
  );
  port (
    aclk            : in  std_ulogic;
    aresetn         : in  std_ulogic;

    -- Subordinates
    s_axi_awsel     : in  std_logic_vector(log2x(nmanports)-1 downto 0);
    s_axi_awid      : in  std_logic_vector(idwidth-1 downto 0);
    s_axi_awaddr    : in  std_logic_vector(awidth-1 downto 0);
    s_axi_awlen     : in  std_logic_vector(8-1 downto 0);
    s_axi_awsize    : in  std_logic_vector(3-1 downto 0);
    s_axi_awburst   : in  std_logic_vector(2-1 downto 0);
    s_axi_awlock    : in  std_logic;
    s_axi_awcache   : in  std_logic_vector(4-1 downto 0);
    s_axi_awprot    : in  std_logic_vector(3-1 downto 0);
    s_axi_awqos     : in  std_logic_vector(4-1 downto 0);
    s_axi_awregion  : in  std_logic_vector(4-1 downto 0);
    s_axi_awuser    : in  std_logic_vector(axuserwidth-1 downto 0);
    s_axi_awvalid   : in  std_logic;
    s_axi_awready   : out std_logic;

    s_axi_wdata     : in  std_logic_vector(dwidth-1 downto 0);
    s_axi_wstrb     : in  std_logic_vector(dwidth/8-1 downto 0);
    s_axi_wlast     : in  std_logic;
    s_axi_wuser     : in  std_logic_vector(wuserwidth-1 downto 0);
    s_axi_wvalid    : in  std_logic;
    s_axi_wready    : out std_logic;

    s_axi_bid       : out std_logic_vector(idwidth-1 downto 0);
    s_axi_bresp     : out std_logic_vector(2-1 downto 0);
    s_axi_buser     : out std_logic_vector(buserwidth-1 downto 0);
    s_axi_bvalid    : out std_logic;
    s_axi_bready    : in  std_logic;

    s_axi_arsel     : in  std_logic_vector(log2x(nmanports)-1 downto 0);
    s_axi_arid      : in  std_logic_vector(idwidth-1 downto 0);
    s_axi_araddr    : in  std_logic_vector(awidth-1 downto 0);
    s_axi_arlen     : in  std_logic_vector(8-1 downto 0);
    s_axi_arsize    : in  std_logic_vector(3-1 downto 0);
    s_axi_arburst   : in  std_logic_vector(2-1 downto 0);
    s_axi_arlock    : in  std_logic;
    s_axi_arcache   : in  std_logic_vector(4-1 downto 0);
    s_axi_arprot    : in  std_logic_vector(3-1 downto 0);
    s_axi_arqos     : in  std_logic_vector(4-1 downto 0);
    s_axi_arregion  : in  std_logic_vector(4-1 downto 0);
    s_axi_aruser    : in  std_logic_vector(axuserwidth-1 downto 0);
    s_axi_arvalid   : in  std_logic;
    s_axi_arready   : out std_logic;

    s_axi_rid       : out std_logic_vector(idwidth-1 downto 0);
    s_axi_rdata     : out std_logic_vector(dwidth-1 downto 0);
    s_axi_rresp     : out std_logic_vector(2-1 downto 0);
    s_axi_rlast     : out std_logic;
    s_axi_ruser     : out std_logic_vector(buserwidth-1 downto 0);
    s_axi_rvalid    : out std_logic;
    s_axi_rready    : in  std_logic;

    -- Managers
    m_axi_awid      : out std_logic_vector(nmanports*idwidth-1 downto 0);
    m_axi_awaddr    : out std_logic_vector(nmanports*awidth-1 downto 0);
    m_axi_awlen     : out std_logic_vector(nmanports*8-1 downto 0);
    m_axi_awsize    : out std_logic_vector(nmanports*3-1 downto 0);
    m_axi_awburst   : out std_logic_vector(nmanports*2-1 downto 0);
    m_axi_awlock    : out std_logic_vector(nmanports-1 downto 0);
    m_axi_awcache   : out std_logic_vector(nmanports*4-1 downto 0);
    m_axi_awprot    : out std_logic_vector(nmanports*3-1 downto 0);
    m_axi_awqos     : out std_logic_vector(nmanports*4-1 downto 0);
    m_axi_awregion  : out std_logic_vector(nmanports*4-1 downto 0);
    m_axi_awuser    : out std_logic_vector(nmanports*axuserwidth-1 downto 0);
    m_axi_awvalid   : out std_logic_vector(nmanports-1 downto 0);
    m_axi_awready   : in  std_logic_vector(nmanports-1 downto 0);

    m_axi_wdata     : out std_logic_vector(nmanports*dwidth-1 downto 0);
    m_axi_wstrb     : out std_logic_vector(nmanports*dwidth/8-1 downto 0);
    m_axi_wlast     : out std_logic_vector(nmanports-1 downto 0);
    m_axi_wuser     : out std_logic_vector(nmanports*wuserwidth-1 downto 0);
    m_axi_wvalid    : out std_logic_vector(nmanports-1 downto 0);
    m_axi_wready    : in  std_logic_vector(nmanports-1 downto 0);

    m_axi_bid       : in  std_logic_vector(nmanports*idwidth-1 downto 0);
    m_axi_bresp     : in  std_logic_vector(nmanports*2-1 downto 0);
    m_axi_buser     : in  std_logic_vector(nmanports*buserwidth-1 downto 0);
    m_axi_bvalid    : in  std_logic_vector(nmanports-1 downto 0);
    m_axi_bready    : out std_logic_vector(nmanports-1 downto 0);

    m_axi_arid      : out std_logic_vector(nmanports*idwidth-1 downto 0);
    m_axi_araddr    : out std_logic_vector(nmanports*awidth-1 downto 0);
    m_axi_arlen     : out std_logic_vector(nmanports*8-1 downto 0);
    m_axi_arsize    : out std_logic_vector(nmanports*3-1 downto 0);
    m_axi_arburst   : out std_logic_vector(nmanports*2-1 downto 0);
    m_axi_arlock    : out std_logic_vector(nmanports-1 downto 0);
    m_axi_arcache   : out std_logic_vector(nmanports*4-1 downto 0);
    m_axi_arprot    : out std_logic_vector(nmanports*3-1 downto 0);
    m_axi_arqos     : out std_logic_vector(nmanports*4-1 downto 0);
    m_axi_arregion  : out std_logic_vector(nmanports*4-1 downto 0);
    m_axi_aruser    : out std_logic_vector(nmanports*axuserwidth-1 downto 0);
    m_axi_arvalid   : out std_logic_vector(nmanports-1 downto 0);
    m_axi_arready   : in  std_logic_vector(nmanports-1 downto 0);

    m_axi_rid       : in  std_logic_vector(nmanports*idwidth-1 downto 0);
    m_axi_rdata     : in  std_logic_vector(nmanports*dwidth-1 downto 0);
    m_axi_rresp     : in  std_logic_vector(nmanports*2-1 downto 0);
    m_axi_rlast     : in  std_logic_vector(nmanports-1 downto 0);
    m_axi_ruser     : in  std_logic_vector(nmanports*ruserwidth-1 downto 0);
    m_axi_rvalid    : in  std_logic_vector(nmanports-1 downto 0);
    m_axi_rready    : out std_logic_vector(nmanports-1 downto 0)
  );
end entity;

architecture rtl of axi4demux is

  constant ASYNC_RST  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant RESET_ALL  : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

  constant nidcnt : integer := 2**idwidth;
  constant cw     : integer := log2x(maxtrans)+1;
  constant selw   : integer := log2x(nmanports);
  constant bwidth : integer := idwidth + 2 + buserwidth;
  constant rwidth : integer := idwidth + dwidth + 2 + 1 + ruserwidth;

  function cond(expr : boolean; a, b : std_logic) return std_logic is
  begin
    if expr then return a; else return b; end if;
  end function;

  function cond(expr : boolean; a, b : std_logic_vector) return std_logic_vector is
  begin
    if expr then return a; else return b; end if;
  end function;

  function drive_manager(v : std_logic) return std_logic_vector is
    variable m : std_logic_vector(nmanports-1 downto 0);
  begin
    m := (others => v);
    return m;
  end function;

  function drive_manager(v : std_logic_vector) return std_logic_vector is
    variable m : std_logic_vector(nmanports*v'length-1 downto 0);
  begin
    for i in 0 to nmanports-1 loop
      m((i+1)*v'length-1 downto i*v'length) := v;
    end loop;
    return m;
  end function;

  function b_pack_array(bid, bresp, buser : std_logic_vector) return std_logic_vector is
    variable b : std_logic_vector(nmanports*bwidth-1 downto 0);
  begin
    for i in 0 to nmanports-1 loop
      b((i+1)*bwidth-1 downto i*bwidth) := bid((i+1)*idwidth-1 downto i*idwidth) &
                                           bresp((i+1)*2-1 downto i*2) &
                                           buser((i+1)*buserwidth-1 downto i*buserwidth);
    end loop;
    return b;
  end function;

  function r_pack_array(rid, rdata, rresp, rlast, ruser : std_logic_vector) return std_logic_vector is
    variable r : std_logic_vector(nmanports*rwidth-1 downto 0);
  begin
    for i in 0 to nmanports-1 loop
      r((i+1)*rwidth-1 downto i*rwidth) := rid((i+1)*idwidth-1 downto i*idwidth) &
                                           rdata((i+1)*dwidth-1 downto i*dwidth) &
                                           rresp((i+1)*2-1 downto i*2) &
                                           rlast((i+1)-1 downto i) &
                                           ruser((i+1)*ruserwidth-1 downto i*ruserwidth);
    end loop;
    return r;
  end function;


  signal s_axi_awsel_i    : std_logic_vector(log2x(nmanports)-1 downto 0);
  signal s_axi_awid_i     : std_logic_vector(idwidth-1 downto 0);
  signal s_axi_awaddr_i   : std_logic_vector(awidth-1 downto 0);
  signal s_axi_awlen_i    : std_logic_vector(8-1 downto 0);
  signal s_axi_awsize_i   : std_logic_vector(3-1 downto 0);
  signal s_axi_awburst_i  : std_logic_vector(2-1 downto 0);
  signal s_axi_awlock_i   : std_logic;
  signal s_axi_awcache_i  : std_logic_vector(4-1 downto 0);
  signal s_axi_awprot_i   : std_logic_vector(3-1 downto 0);
  signal s_axi_awqos_i    : std_logic_vector(4-1 downto 0);
  signal s_axi_awregion_i : std_logic_vector(4-1 downto 0);
  signal s_axi_awuser_i   : std_logic_vector(axuserwidth-1 downto 0);
  signal s_axi_awvalid_i  : std_logic;
  signal s_axi_awready_i  : std_logic;
  signal s_axi_wdata_i    : std_logic_vector(dwidth-1 downto 0);
  signal s_axi_wstrb_i    : std_logic_vector(dwidth/8-1 downto 0);
  signal s_axi_wlast_i    : std_logic;
  signal s_axi_wuser_i    : std_logic_vector(wuserwidth-1 downto 0);
  signal s_axi_wvalid_i   : std_logic;
  signal s_axi_wready_i   : std_logic;
  signal s_axi_bid_i      : std_logic_vector(idwidth-1 downto 0);
  signal s_axi_bresp_i    : std_logic_vector(2-1 downto 0);
  signal s_axi_buser_i    : std_logic_vector(buserwidth-1 downto 0);
  signal s_axi_bvalid_i   : std_logic;
  signal s_axi_bready_i   : std_logic;
  signal s_axi_arsel_i    : std_logic_vector(log2x(nmanports)-1 downto 0);
  signal s_axi_arid_i     : std_logic_vector(idwidth-1 downto 0);
  signal s_axi_araddr_i   : std_logic_vector(awidth-1 downto 0);
  signal s_axi_arlen_i    : std_logic_vector(8-1 downto 0);
  signal s_axi_arsize_i   : std_logic_vector(3-1 downto 0);
  signal s_axi_arburst_i  : std_logic_vector(2-1 downto 0);
  signal s_axi_arlock_i   : std_logic;
  signal s_axi_arcache_i  : std_logic_vector(4-1 downto 0);
  signal s_axi_arprot_i   : std_logic_vector(3-1 downto 0);
  signal s_axi_arqos_i    : std_logic_vector(4-1 downto 0);
  signal s_axi_arregion_i : std_logic_vector(4-1 downto 0);
  signal s_axi_aruser_i   : std_logic_vector(axuserwidth-1 downto 0);
  signal s_axi_arvalid_i  : std_logic;
  signal s_axi_arready_i  : std_logic;
  signal s_axi_rid_i      : std_logic_vector(idwidth-1 downto 0);
  signal s_axi_rdata_i    : std_logic_vector(dwidth-1 downto 0);
  signal s_axi_rresp_i    : std_logic_vector(2-1 downto 0);
  signal s_axi_rlast_i    : std_logic;
  signal s_axi_ruser_i    : std_logic_vector(buserwidth-1 downto 0);
  signal s_axi_rvalid_i   : std_logic;
  signal s_axi_rready_i   : std_logic;

  signal bpacked_array    : std_logic_vector(nmanports*bwidth-1 downto 0);
  signal rpacked_array    : std_logic_vector(nmanports*rwidth-1 downto 0);

  signal bpacked          : std_logic_vector(bwidth-1 downto 0);
  signal rpacked          : std_logic_vector(rwidth-1 downto 0);

  type axidparam_type is record
    sel   : std_logic_vector(selw-1 downto 0);
    count : unsigned(cw-1 downto 0);
    empty : std_logic;
  end record;
  type axidparam_array_type is array(0 to nidcnt-1) of axidparam_type;

  constant axidparam_reset : axidparam_type := (
    sel   => (others => '0'),
    count => (others => '0'),
    empty => '1'
  );

  type reg_type is record
    awidparam     : axidparam_array_type;
    wcount        : unsigned(cw-1 downto 0);
    wselect       : std_logic_vector(selw-1 downto 0);
    wselect_valid : std_logic;
    aridparam     : axidparam_array_type;
  end record;

  constant RST : reg_type := (
    awidparam     => (others => axidparam_reset),
    wcount        => (others => '0'),
    wselect       => (others => '0'),
    wselect_valid => '0',
    aridparam     => (others => axidparam_reset)
  );

  signal r, rin : reg_type;

begin

  axi_slice : axi4_register_slice
    generic map (
      awidth      => awidth,
      dwidth      => dwidth,
      idwidth     => idwidth,
      axuserwidth => axuserwidth,
      wuserwidth  => wuserwidth,
      buserwidth  => buserwidth,
      ruserwidth  => ruserwidth,
      awdirection => 0,
      wdirection  => 0,
      bdirection  => 1,
      ardirection => 0,
      rdirection  => 1
    )
    port map (
      aclk            => aclk,
      aresetn         => aresetn,

      s_axi_awid      => s_axi_awid,
      s_axi_awaddr    => s_axi_awaddr,
      s_axi_awlen     => s_axi_awlen,
      s_axi_awsize    => s_axi_awsize,
      s_axi_awburst   => s_axi_awburst,
      s_axi_awlock    => s_axi_awlock,
      s_axi_awcache   => s_axi_awcache,
      s_axi_awprot    => s_axi_awprot,
      s_axi_awqos     => s_axi_awqos,
      s_axi_awregion  => s_axi_awregion,
      s_axi_awuser    => s_axi_awuser,
      s_axi_awvalid   => s_axi_awvalid,
      s_axi_awready   => s_axi_awready,
      s_axi_wdata     => s_axi_wdata,
      s_axi_wstrb     => s_axi_wstrb,
      s_axi_wlast     => s_axi_wlast,
      s_axi_wuser     => s_axi_wuser,
      s_axi_wvalid    => s_axi_wvalid,
      s_axi_wready    => s_axi_wready,
      s_axi_bid       => s_axi_bid,
      s_axi_bresp     => s_axi_bresp,
      s_axi_buser     => s_axi_buser,
      s_axi_bvalid    => s_axi_bvalid,
      s_axi_bready    => s_axi_bready,
      s_axi_arid      => s_axi_arid,
      s_axi_araddr    => s_axi_araddr,
      s_axi_arlen     => s_axi_arlen,
      s_axi_arsize    => s_axi_arsize,
      s_axi_arburst   => s_axi_arburst,
      s_axi_arlock    => s_axi_arlock,
      s_axi_arcache   => s_axi_arcache,
      s_axi_arprot    => s_axi_arprot,
      s_axi_arqos     => s_axi_arqos,
      s_axi_arregion  => s_axi_arregion,
      s_axi_aruser    => s_axi_aruser,
      s_axi_arvalid   => s_axi_arvalid,
      s_axi_arready   => s_axi_arready,
      s_axi_rid       => s_axi_rid,
      s_axi_rdata     => s_axi_rdata,
      s_axi_rresp     => s_axi_rresp,
      s_axi_rlast     => s_axi_rlast,
      s_axi_ruser     => s_axi_ruser,
      s_axi_rvalid    => s_axi_rvalid,
      s_axi_rready    => s_axi_rready,
      m_axi_awid      => s_axi_awid_i,
      m_axi_awaddr    => s_axi_awaddr_i,
      m_axi_awlen     => s_axi_awlen_i,
      m_axi_awsize    => s_axi_awsize_i,
      m_axi_awburst   => s_axi_awburst_i,
      m_axi_awlock    => s_axi_awlock_i,
      m_axi_awcache   => s_axi_awcache_i,
      m_axi_awprot    => s_axi_awprot_i,
      m_axi_awqos     => s_axi_awqos_i,
      m_axi_awregion  => s_axi_awregion_i,
      m_axi_awuser    => s_axi_awuser_i,
      m_axi_awvalid   => s_axi_awvalid_i,
      m_axi_awready   => s_axi_awready_i,
      m_axi_wdata     => s_axi_wdata_i,
      m_axi_wstrb     => s_axi_wstrb_i,
      m_axi_wlast     => s_axi_wlast_i,
      m_axi_wuser     => s_axi_wuser_i,
      m_axi_wvalid    => s_axi_wvalid_i,
      m_axi_wready    => s_axi_wready_i,
      m_axi_bid       => s_axi_bid_i,
      m_axi_bresp     => s_axi_bresp_i,
      m_axi_buser     => s_axi_buser_i,
      m_axi_bvalid    => s_axi_bvalid_i,
      m_axi_bready    => s_axi_bready_i,
      m_axi_arid      => s_axi_arid_i,
      m_axi_araddr    => s_axi_araddr_i,
      m_axi_arlen     => s_axi_arlen_i,
      m_axi_arsize    => s_axi_arsize_i,
      m_axi_arburst   => s_axi_arburst_i,
      m_axi_arlock    => s_axi_arlock_i,
      m_axi_arcache   => s_axi_arcache_i,
      m_axi_arprot    => s_axi_arprot_i,
      m_axi_arqos     => s_axi_arqos_i,
      m_axi_arregion  => s_axi_arregion_i,
      m_axi_aruser    => s_axi_aruser_i,
      m_axi_arvalid   => s_axi_arvalid_i,
      m_axi_arready   => s_axi_arready_i,
      m_axi_rid       => s_axi_rid_i,
      m_axi_rdata     => s_axi_rdata_i,
      m_axi_rresp     => s_axi_rresp_i,
      m_axi_rlast     => s_axi_rlast_i,
      m_axi_ruser     => s_axi_ruser_i,
      m_axi_rvalid    => s_axi_rvalid_i,
      m_axi_rready    => s_axi_rready_i
    );

  awsel_slice : register_slice
    generic map (
      dwidth    => selw,
      bypass    => 0
    )
    port map (
      clk       => aclk,
      rstn      => aresetn,

      s_xdata   => s_axi_awsel,
      s_xvalid  => s_axi_awvalid,
      s_xready  => open,

      m_xdata   => s_axi_awsel_i,
      m_xvalid  => open,
      m_xready  => s_axi_awready_i
    );

  arsel_slice : register_slice
    generic map (
      dwidth    => selw,
      bypass    => 0
    )
    port map (
      clk       => aclk,
      rstn      => aresetn,

      s_xdata   => s_axi_arsel,
      s_xvalid  => s_axi_arvalid,
      s_xready  => open,

      m_xdata   => s_axi_arsel_i,
      m_xvalid  => open,
      m_xready  => s_axi_arready_i
    );

  p_comb : process(r, aresetn,
                   s_axi_awsel_i, s_axi_awid_i, s_axi_awvalid_i, m_axi_awready,
                   s_axi_wlast_i, s_axi_wvalid_i, m_axi_wready,
                   s_axi_arsel_i, s_axi_arid_i, s_axi_arvalid_i, m_axi_arready,
                   s_axi_bid_i, s_axi_bvalid_i, s_axi_bready_i,
                   s_axi_rid_i, s_axi_rlast_i, s_axi_rvalid_i, s_axi_rready_i)
    procedure pr_idcounters(
      axsel   : in  std_logic_vector(selw-1 downto 0);
      push_id : in  std_logic_vector(idwidth-1 downto 0);
      push    : in  std_logic;
      pop_id  : in  std_logic_vector(idwidth-1 downto 0);
      pop     : in  std_logic;
      param_i : in  axidparam_array_type;
      param_o : out axidparam_array_type
    ) is
      variable vpush  : std_logic;
      variable vpop   : std_logic;
      variable vparam : axidparam_array_type;
    begin
      param_o := param_i;
      for i in 0 to nidcnt-1 loop
        vpush := cond(i = unsigned(push_id), push, '0');
        vpop  := cond(i = unsigned(pop_id), pop, '0');
        if vpush = '1' and param_i(i).empty = '1' then
          param_o(i).sel := axsel;
        end if;
        if vpush = '1' and vpop = '0' then
          param_o(i).count := param_i(i).count + 1;
          param_o(i).empty := '0';
        elsif vpush = '0' and vpop = '1' then
          if param_i(i).empty = '0' then
            param_o(i).count := param_i(i).count - 1;
            if param_i(i).count = 1 then
              param_o(i).empty := '1';
            end if;
          end if;
        end if;
      end loop;
    end procedure;

    procedure pr_idsel(
      axid  : in  std_logic_vector(idwidth-1 downto 0);
      axsel : in  std_logic_vector(selw-1 downto 0);
      param : in  axidparam_array_type;
      match : out std_logic
    ) is
    begin
      match := '0';
      for i in 0 to nidcnt-1 loop
        if unsigned(axid) = i then
          if (axsel = param(i).sel and param(i).count(cw-1) = '0') or param(i).empty = '1' then
            -- ID is a match and counter is not full, or the counter is empty (unused)
            match := '1';
          end if;
        end if;
      end loop;
    end procedure;

    variable v          : reg_type;
    variable awvalid    : std_logic;
    variable awenable   : std_logic;
    variable awready    : std_logic;
    variable awmatch    : std_logic;
    variable awpush     : std_logic;
    variable wselect    : std_logic_vector(selw-1 downto 0);
    variable wfull      : std_logic;
    variable wvalid     : std_logic;
    variable wenable    : std_logic;
    variable wready     : std_logic;
    variable arvalid    : std_logic;
    variable arready    : std_logic;
    variable arenable   : std_logic;
    variable arpush     : std_logic;
    variable wpop       : std_logic;
    variable bpop       : std_logic;
    variable rpop       : std_logic;
  begin
    v := r;

    -- Any AW ID may only have in flight transfers to a single port at the time to
    -- maintain AXI ordering. Check if current ID matches the current selection or if
    -- its counter is empty.
    pr_idsel(s_axi_awid_i, s_axi_awsel_i, r.awidparam, awmatch);

    -- Enable AW if ID had a match and the write channel is idle or using the same select
    awenable := '0';
    if (r.wselect_valid = '0' or r.wselect = s_axi_awsel_i) and awmatch = '1' then
      awenable := '1';
    end if;

    awvalid := s_axi_awvalid_i and awenable;
    awready := '0';
    for i in 0 to nmanports-1 loop
      if i = unsigned(s_axi_awsel_i) then
        awready := m_axi_awready(i);
      end if;
    end loop;

    if awvalid = '1' then
      -- Update W select register if AW is valid and enabled
      v.wselect := s_axi_awsel_i;
    end if;
    -- Push in flight counters
    awpush := awvalid and awready;

    -- Enable W on AW transfer or if the current W select is valid
    wenable := awpush or r.wselect_valid;
    wvalid  := s_axi_wvalid_i and wenable;
    wselect := cond(r.wselect_valid = '1', r.wselect, s_axi_awsel_i);
    wready  := '0';
    for i in 0 to nmanports-1 loop
      if i = unsigned(wselect) then
        wready := m_axi_wready(i);
      end if;
    end loop;

    wpop := wvalid and wready and s_axi_wlast_i;
    -- Count up W counter on AW transfer, count down on completed W transfer
    if awpush = '1' and wpop = '0' then
      v.wcount        := r.wcount + 1;
      v.wselect_valid := '1';
    elsif awpush = '0' and wpop = '1' then
      v.wcount := r.wcount - 1;
      if r.wcount = 1 then
        v.wselect_valid := '0';
      end if;
    end if;

    -- Pop in flight write transfer on write response
    bpop := s_axi_bvalid_i and s_axi_bready_i;

    -- In flight transfer counters per ID for write transfers
    pr_idcounters(s_axi_awsel_i, s_axi_awid_i, awpush, s_axi_bid_i, bpop, r.awidparam, v.awidparam);

    -- Any AR ID may only have in flight transfers to a single port at the time to
    -- maintain AXI ordering. Check if current ID matches the current selection or if
    -- its counter is empty.
    pr_idsel(s_axi_arid_i, s_axi_arsel_i, r.aridparam, arenable);

    -- AR is enabled if ID had a match
    arvalid := s_axi_arvalid_i and arenable;
    arready := '0';
    for i in 0 to nmanports-1 loop
      if i = unsigned(s_axi_arsel_i) then
        arready := m_axi_arready(i);
      end if;
    end loop;
    -- Push to in flight counters on transfer
    arpush := arvalid and arready;

    -- Pop from in flight counters on last read response
    rpop := s_axi_rvalid_i and s_axi_rready_i and s_axi_rlast_i;

    -- In flight transfer counters per ID for read transfers
    pr_idcounters(s_axi_arsel_i, s_axi_arid_i, arpush, s_axi_rid_i, rpop, r.aridparam, v.aridparam);

    if not ASYNC_RST and aresetn = '0' then
      v := RST;
    end if;

    rin <= v;

    -- Demux AW
    m_axi_awvalid <= (others => '0');
    for i in 0 to nmanports-1 loop
      if i = unsigned(s_axi_awsel_i) then
        m_axi_awvalid(i) <= awvalid;
      end if;
    end loop;
    s_axi_awready_i <= awready and awenable;

    -- Demux W
    m_axi_wvalid <= (others => '0');
    for i in 0 to nmanports-1 loop
      if i = unsigned(wselect) then
        m_axi_wvalid(i) <= wvalid;
      end if;
    end loop;
    s_axi_wready_i <= wready and wenable;

    -- Demux AR
    m_axi_arvalid <= (others => '0');
    for i in 0 to nmanports-1 loop
      if i = unsigned(s_axi_arsel_i) then
        m_axi_arvalid(i) <= arvalid;
      end if;
    end loop;
    s_axi_arready_i <= arready and arenable;

  end process;

  m_axi_awid      <= drive_manager(s_axi_awid_i);
  m_axi_awaddr    <= drive_manager(s_axi_awaddr_i);
  m_axi_awlen     <= drive_manager(s_axi_awlen_i);
  m_axi_awsize    <= drive_manager(s_axi_awsize_i);
  m_axi_awburst   <= drive_manager(s_axi_awburst_i);
  m_axi_awlock    <= drive_manager(s_axi_awlock_i);
  m_axi_awcache   <= drive_manager(s_axi_awcache_i);
  m_axi_awprot    <= drive_manager(s_axi_awprot_i);
  m_axi_awqos     <= drive_manager(s_axi_awqos_i);
  m_axi_awregion  <= drive_manager(s_axi_awregion_i);
  drive_awuser : if axuserwidth > 0 generate
    m_axi_awuser    <= drive_manager(s_axi_awuser_i);
  end generate;

  m_axi_wdata     <= drive_manager(s_axi_wdata_i);
  m_axi_wstrb     <= drive_manager(s_axi_wstrb_i);
  m_axi_wlast     <= drive_manager(s_axi_wlast_i);
  drive_wuser : if wuserwidth > 0 generate
    m_axi_wuser     <= drive_manager(s_axi_wuser_i);
  end generate;

  m_axi_arid      <= drive_manager(s_axi_arid_i);
  m_axi_araddr    <= drive_manager(s_axi_araddr_i);
  m_axi_arlen     <= drive_manager(s_axi_arlen_i);
  m_axi_arsize    <= drive_manager(s_axi_arsize_i);
  m_axi_arburst   <= drive_manager(s_axi_arburst_i);
  m_axi_arlock    <= drive_manager(s_axi_arlock_i);
  m_axi_arcache   <= drive_manager(s_axi_arcache_i);
  m_axi_arprot    <= drive_manager(s_axi_arprot_i);
  m_axi_arqos     <= drive_manager(s_axi_arqos_i);
  m_axi_arregion  <= drive_manager(s_axi_arregion_i);
  drive_aruser : if axuserwidth > 0 generate
    m_axi_aruser    <= drive_manager(s_axi_aruser_i);
  end generate;

  p_reg : process(aclk, aresetn)
  begin
    if ASYNC_RST and aresetn = '0' then
      r <= RST;
    elsif rising_edge(aclk) then
      r <= rin;
    end if;
  end process;

  bpacked_array <= b_pack_array(m_axi_bid, m_axi_bresp, m_axi_buser);
  barbiter : arbiter_tree
    generic map (
      nreq      => nmanports,
      dwidth    => bwidth,
      arb_prio  => 2,
      arb_lock  => 1
    )
    port map (
      clk   => aclk,
      rstn  => aresetn,
      sdata => bpacked_array,
      sreq  => m_axi_bvalid,
      sgnt  => m_axi_bready,
      msel  => open,
      mdata => bpacked,
      mreq  => s_axi_bvalid_i,
      mgnt  => s_axi_bready_i
    );
  b_unpack(bpacked, s_axi_bid_i, s_axi_bresp_i, s_axi_buser_i);

  rpacked_array <= r_pack_array(m_axi_rid, m_axi_rdata, m_axi_rresp, m_axi_rlast, m_axi_ruser);
  rarbiter : arbiter_tree
    generic map (
      nreq      => nmanports,
      dwidth    => rwidth,
      arb_prio  => 2,
      arb_lock  => 1
    )
    port map (
      clk   => aclk,
      rstn  => aresetn,
      sdata => rpacked_array,
      sreq  => m_axi_rvalid,
      sgnt  => m_axi_rready,
      msel  => open,
      mdata => rpacked,
      mreq  => s_axi_rvalid_i,
      mgnt  => s_axi_rready_i
    );
  r_unpack(rpacked, s_axi_rid_i, s_axi_rdata_i, s_axi_rresp_i, s_axi_rlast_i, s_axi_ruser_i);

end architecture;