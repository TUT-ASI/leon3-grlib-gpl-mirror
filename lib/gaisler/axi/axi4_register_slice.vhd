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
-- Entity:      axi4_register_slice
-- File:        axi4_register_slice.vhd
-- Author:      Martin Caous George - Frontgrade Gaisler AB
-- Description: AXI4 register slice
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
use grlib.amba.all;
library gaisler;
use gaisler.axi.all;

entity axi4_register_slice is
  generic (
    awidth      : integer;
    dwidth      : integer;
    idwidth     : integer;
    axuserwidth : integer;
    wuserwidth  : integer;
    buserwidth  : integer;
    ruserwidth  : integer;
    awdirection : integer range 0 to 1 := 0;
    wdirection  : integer range 0 to 1 := 0;
    bdirection  : integer range 0 to 1 := 0;
    ardirection : integer range 0 to 1 := 0;
    rdirection  : integer range 0 to 1 := 0;
    awbypass    : integer range 0 to 1 := 0;
    wbypass     : integer range 0 to 1 := 0;
    bbypass     : integer range 0 to 1 := 0;
    arbypass    : integer range 0 to 1 := 0;
    rbypass     : integer range 0 to 1 := 0
  );
  port (
    aclk            : in  std_ulogic;
    aresetn         : in  std_ulogic;

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

    m_axi_awid      : out std_logic_vector(idwidth-1 downto 0);
    m_axi_awaddr    : out std_logic_vector(awidth-1 downto 0);
    m_axi_awlen     : out std_logic_vector(8-1 downto 0);
    m_axi_awsize    : out std_logic_vector(3-1 downto 0);
    m_axi_awburst   : out std_logic_vector(2-1 downto 0);
    m_axi_awlock    : out std_logic;
    m_axi_awcache   : out std_logic_vector(4-1 downto 0);
    m_axi_awprot    : out std_logic_vector(3-1 downto 0);
    m_axi_awqos     : out std_logic_vector(4-1 downto 0);
    m_axi_awregion  : out std_logic_vector(4-1 downto 0);
    m_axi_awuser    : out std_logic_vector(axuserwidth-1 downto 0);
    m_axi_awvalid   : out std_logic;
    m_axi_awready   : in  std_logic;

    m_axi_wdata     : out std_logic_vector(dwidth-1 downto 0);
    m_axi_wstrb     : out std_logic_vector(dwidth/8-1 downto 0);
    m_axi_wlast     : out std_logic;
    m_axi_wuser     : out std_logic_vector(wuserwidth-1 downto 0);
    m_axi_wvalid    : out std_logic;
    m_axi_wready    : in  std_logic;

    m_axi_bid       : in  std_logic_vector(idwidth-1 downto 0);
    m_axi_bresp     : in  std_logic_vector(2-1 downto 0);
    m_axi_buser     : in  std_logic_vector(buserwidth-1 downto 0);
    m_axi_bvalid    : in  std_logic;
    m_axi_bready    : out std_logic;

    m_axi_arid      : out std_logic_vector(idwidth-1 downto 0);
    m_axi_araddr    : out std_logic_vector(awidth-1 downto 0);
    m_axi_arlen     : out std_logic_vector(8-1 downto 0);
    m_axi_arsize    : out std_logic_vector(3-1 downto 0);
    m_axi_arburst   : out std_logic_vector(2-1 downto 0);
    m_axi_arlock    : out std_logic;
    m_axi_arcache   : out std_logic_vector(4-1 downto 0);
    m_axi_arprot    : out std_logic_vector(3-1 downto 0);
    m_axi_arqos     : out std_logic_vector(4-1 downto 0);
    m_axi_arregion  : out std_logic_vector(4-1 downto 0);
    m_axi_aruser    : out std_logic_vector(axuserwidth-1 downto 0);
    m_axi_arvalid   : out std_logic;
    m_axi_arready   : in  std_logic;

    m_axi_rid       : in  std_logic_vector(idwidth-1 downto 0);
    m_axi_rdata     : in  std_logic_vector(dwidth-1 downto 0);
    m_axi_rresp     : in  std_logic_vector(2-1 downto 0);
    m_axi_rlast     : in  std_logic;
    m_axi_ruser     : in  std_logic_vector(ruserwidth-1 downto 0);
    m_axi_rvalid    : in  std_logic;
    m_axi_rready    : out std_logic
  );
end;

architecture rtl of axi4_register_slice is

  constant axwidth  : integer := idwidth + awidth + 8 + 3 + 2 + 1 + 4 + 3 + 4 + 4 + axuserwidth;
  constant wwidth   : integer := dwidth + dwidth/8 + 1 + wuserwidth;
  constant bwidth   : integer := idwidth + 2 + buserwidth;
  constant rwidth   : integer := idwidth + dwidth + 2 + 1 + ruserwidth;

  signal s_axi_aw   : std_logic_vector(axwidth-1 downto 0);
  signal m_axi_aw   : std_logic_vector(axwidth-1 downto 0);
  signal s_axi_w    : std_logic_vector(wwidth-1 downto 0);
  signal m_axi_w    : std_logic_vector(wwidth-1 downto 0);
  signal s_axi_b    : std_logic_vector(bwidth-1 downto 0);
  signal m_axi_b    : std_logic_vector(bwidth-1 downto 0);
  signal s_axi_ar   : std_logic_vector(axwidth-1 downto 0);
  signal m_axi_ar   : std_logic_vector(axwidth-1 downto 0);
  signal s_axi_r    : std_logic_vector(rwidth-1 downto 0);
  signal m_axi_r    : std_logic_vector(rwidth-1 downto 0);

begin

  -- AW

  s_axi_aw  <= ax_pack(s_axi_awid,
                       s_axi_awaddr,
                       s_axi_awlen,
                       s_axi_awsize,
                       s_axi_awburst,
                       s_axi_awlock,
                       s_axi_awcache,
                       s_axi_awprot,
                       s_axi_awqos,
                       s_axi_awregion,
                       s_axi_awuser);

  aw_slice : register_slice
  generic map (
    dwidth    => axwidth,
    direction => awdirection,
    bypass    => awbypass
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => s_axi_aw,
    s_xvalid  => s_axi_awvalid,
    s_xready  => s_axi_awready,

    m_xdata   => m_axi_aw,
    m_xvalid  => m_axi_awvalid,
    m_xready  => m_axi_awready
  );

  ax_unpack(
    m_axi_aw,
    m_axi_awid,
    m_axi_awaddr,
    m_axi_awlen,
    m_axi_awsize,
    m_axi_awburst,
    m_axi_awlock,
    m_axi_awcache,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awregion,
    m_axi_awuser
  );

  -- W

  s_axi_w <= w_pack(s_axi_wdata,
                    s_axi_wstrb,
                    s_axi_wlast,
                    s_axi_wuser);

  w_slice : register_slice
  generic map (
    dwidth    => wwidth,
    direction => wdirection,
    bypass    => wbypass
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => s_axi_w,
    s_xvalid  => s_axi_wvalid,
    s_xready  => s_axi_wready,

    m_xdata   => m_axi_w,
    m_xvalid  => m_axi_wvalid,
    m_xready  => m_axi_wready
  );

  w_unpack(
    m_axi_w,
    m_axi_wdata,
    m_axi_wstrb,
    m_axi_wlast,
    m_axi_wuser
  );

  -- B

  m_axi_b <= b_pack(m_axi_bid,
                    m_axi_bresp,
                    m_axi_buser);

  b_slice : register_slice
  generic map (
    dwidth    => bwidth,
    direction => bdirection,
    bypass    => bbypass
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => m_axi_b,
    s_xvalid  => m_axi_bvalid,
    s_xready  => m_axi_bready,

    m_xdata   => s_axi_b,
    m_xvalid  => s_axi_bvalid,
    m_xready  => s_axi_bready
  );

  b_unpack(
    s_axi_b,
    s_axi_bid,
    s_axi_bresp,
    s_axi_buser
  );

  -- AR

  s_axi_ar  <= ax_pack(s_axi_arid,
                       s_axi_araddr,
                       s_axi_arlen,
                       s_axi_arsize,
                       s_axi_arburst,
                       s_axi_arlock,
                       s_axi_arcache,
                       s_axi_arprot,
                       s_axi_arqos,
                       s_axi_arregion,
                       s_axi_aruser);

  ar_slice : register_slice
  generic map (
    dwidth    => axwidth,
    direction => ardirection,
    bypass    => arbypass
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => s_axi_ar,
    s_xvalid  => s_axi_arvalid,
    s_xready  => s_axi_arready,

    m_xdata   => m_axi_ar,
    m_xvalid  => m_axi_arvalid,
    m_xready  => m_axi_arready
  );

  ax_unpack(
    m_axi_ar,
    m_axi_arid,
    m_axi_araddr,
    m_axi_arlen,
    m_axi_arsize,
    m_axi_arburst,
    m_axi_arlock,
    m_axi_arcache,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arregion,
    m_axi_aruser
  );

  -- R

  m_axi_r <= r_pack(m_axi_rid,
                    m_axi_rdata,
                    m_axi_rresp,
                    m_axi_rlast,
                    m_axi_ruser);

  r_slice : register_slice
  generic map (
    dwidth    => rwidth,
    direction => rdirection,
    bypass    => rbypass
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => m_axi_r,
    s_xvalid  => m_axi_rvalid,
    s_xready  => m_axi_rready,

    m_xdata   => s_axi_r,
    m_xvalid  => s_axi_rvalid,
    m_xready  => s_axi_rready
  );

  r_unpack(
    s_axi_r,
    s_axi_rid,
    s_axi_rdata,
    s_axi_rresp,
    s_axi_rlast,
    s_axi_ruser
  );

end;