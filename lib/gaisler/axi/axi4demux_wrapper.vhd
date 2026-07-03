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
-- Entity:      axi4demux_wrapper
-- File:        axi4demux_wrapper.vhd
-- Author:      Martin Caous George - Frontgrade Gaisler AB
-- Description: AXI demultiplexer AMBA AXI4 type wrapper
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
library techmap;
use techmap.gencomp.all;

entity axi4demux_wrapper is
  generic (
    nmanports   : integer;
    maxtrans    : integer;
    idwidth     : integer range 0 to 2*AXI_ID_WIDTH;
    awidth      : integer range 12 to 64 := 32;
    dwidth      : integer range 8 to AXIDW := AXIDW
  );
  port (
    aclk        : in  std_ulogic;
    aresetn     : in  std_ulogic;

    -- Subordinates
    s_axi_awsel : in  std_logic_vector(log2x(nmanports)-1 downto 0);
    s_axi_arsel : in  std_logic_vector(log2x(nmanports)-1 downto 0);
    axisi       : in  axi4_mosi_type;
    axixsi      : in  extaxi_mosi_type := extaxi_mosi_none;
    axiso       : out axi_somi_type;
    axixso      : out extaxi_miso_type;

    -- Manager
    aximo       : out axi4_mosi_vector_type(0 to nmanports-1);
    axixmo      : out extaxi_mosi_vector_type(0 to nmanports-1);
    aximi       : in  axi_somi_vector_type(0 to nmanports-1);
    axixmi      : in  extaxi_miso_vector_type(0 to nmanports-1) := (others => extaxi_miso_none)
  );
end;

architecture rtl of axi4demux_wrapper is

  -- Managers
  signal m_axi_awid     : std_logic_vector(nmanports*idwidth-1 downto 0);
  signal m_axi_awaddr   : std_logic_vector(nmanports*awidth-1 downto 0);
  signal m_axi_awlen    : std_logic_vector(nmanports*8-1 downto 0);
  signal m_axi_awsize   : std_logic_vector(nmanports*3-1 downto 0);
  signal m_axi_awburst  : std_logic_vector(nmanports*2-1 downto 0);
  signal m_axi_awlock   : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_awcache  : std_logic_vector(nmanports*4-1 downto 0);
  signal m_axi_awprot   : std_logic_vector(nmanports*3-1 downto 0);
  signal m_axi_awqos    : std_logic_vector(nmanports*4-1 downto 0);
  signal m_axi_awvalid  : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_awready  : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_wdata    : std_logic_vector(nmanports*dwidth-1 downto 0);
  signal m_axi_wstrb    : std_logic_vector(nmanports*dwidth/8-1 downto 0);
  signal m_axi_wlast    : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_wvalid   : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_wready   : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_bid      : std_logic_vector(nmanports*idwidth-1 downto 0);
  signal m_axi_bresp    : std_logic_vector(nmanports*2-1 downto 0);
  signal m_axi_bvalid   : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_bready   : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_arid     : std_logic_vector(nmanports*idwidth-1 downto 0);
  signal m_axi_araddr   : std_logic_vector(nmanports*awidth-1 downto 0);
  signal m_axi_arlen    : std_logic_vector(nmanports*8-1 downto 0);
  signal m_axi_arsize   : std_logic_vector(nmanports*3-1 downto 0);
  signal m_axi_arburst  : std_logic_vector(nmanports*2-1 downto 0);
  signal m_axi_arlock   : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_arcache  : std_logic_vector(nmanports*4-1 downto 0);
  signal m_axi_arprot   : std_logic_vector(nmanports*3-1 downto 0);
  signal m_axi_arqos    : std_logic_vector(nmanports*4-1 downto 0);
  signal m_axi_arvalid  : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_arready  : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_rid      : std_logic_vector(nmanports*idwidth-1 downto 0);
  signal m_axi_rdata    : std_logic_vector(nmanports*dwidth-1 downto 0);
  signal m_axi_rresp    : std_logic_vector(nmanports*2-1 downto 0);
  signal m_axi_rlast    : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_rvalid   : std_logic_vector(nmanports-1 downto 0);
  signal m_axi_rready   : std_logic_vector(nmanports-1 downto 0);

  signal s_axi_awid     : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
  signal s_axi_awaddr   : std_logic_vector(63 downto 0);
  signal s_axi_bid      : std_logic_vector(idwidth-1 downto 0);
  signal s_axi_arid     : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
  signal s_axi_araddr   : std_logic_vector(63 downto 0);
  signal s_axi_rid      : std_logic_vector(idwidth-1 downto 0);

begin

  assert idwidth <= AXI_ID_WIDTH
    report "axi4mux: AXI ID does not fit into record type id field, using extended id field" severity note;

  s_axi_awid    <= axixsi.aw.id & axisi.aw.id;
  s_axi_awaddr  <= axixsi.aw.addr & axisi.aw.addr;
  s_axi_arid    <= axixsi.ar.id & axisi.ar.id;
  s_axi_araddr  <= axixsi.ar.addr & axisi.ar.addr;

  resp_id_proc : process(s_axi_bid, s_axi_rid)
    variable bid    : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
    variable rid    : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
  begin
    bid                     := (others => '0');
    bid(idwidth-1 downto 0) := s_axi_bid;
    axiso.b.id              <= bid(AXI_ID_WIDTH-1 downto 0);
    axixso.b.id             <= bid(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH);

    rid                     := (others => '0');
    rid(idwidth-1 downto 0) := s_axi_rid;
    axiso.r.id              <= rid(AXI_ID_WIDTH-1 downto 0);
    axixso.r.id             <= rid(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH);
  end process;

  demux : axi4demux
    generic map (
      nmanports   => nmanports,
      maxtrans    => maxtrans,
      awidth      => awidth,
      dwidth      => dwidth,
      idwidth     => idwidth,
      axuserwidth => 1,
      wuserwidth  => 1,
      buserwidth  => 1,
      ruserwidth  => 1
    )
    port map (
      aclk            => aclk,
      aresetn         => aresetn,

      -- Subordinates
      s_axi_awsel     => s_axi_awsel,
      s_axi_awid      => s_axi_awid(idwidth-1 downto 0),
      s_axi_awaddr    => s_axi_awaddr(awidth-1 downto 0),
      s_axi_awlen     => axisi.aw.len,
      s_axi_awsize    => axisi.aw.size,
      s_axi_awburst   => axisi.aw.burst,
      s_axi_awlock    => axisi.aw.lock,
      s_axi_awcache   => axisi.aw.cache,
      s_axi_awprot    => axisi.aw.prot,
      s_axi_awqos     => axisi.aw.qos,
      s_axi_awregion  => (others => '0'),
      s_axi_awuser    => (others => '0'),
      s_axi_awvalid   => axisi.aw.valid,
      s_axi_awready   => axiso.aw.ready,
      s_axi_wdata     => axisi.w.data(dwidth-1 downto 0),
      s_axi_wstrb     => axisi.w.strb(dwidth/8-1 downto 0),
      s_axi_wlast     => axisi.w.last,
      s_axi_wuser     => (others => '0'),
      s_axi_wvalid    => axisi.w.valid,
      s_axi_wready    => axiso.w.ready,
      s_axi_bid       => s_axi_bid,
      s_axi_bresp     => axiso.b.resp,
      s_axi_buser     => open,
      s_axi_bvalid    => axiso.b.valid,
      s_axi_bready    => axisi.b.ready,
      s_axi_arid      => s_axi_arid(idwidth-1 downto 0),
      s_axi_araddr    => s_axi_araddr(awidth-1 downto 0),
      s_axi_arlen     => axisi.ar.len,
      s_axi_arsize    => axisi.ar.size,
      s_axi_arburst   => axisi.ar.burst,
      s_axi_arlock    => axisi.ar.lock,
      s_axi_arcache   => axisi.ar.cache,
      s_axi_arprot    => axisi.ar.prot,
      s_axi_arqos     => axisi.ar.qos,
      s_axi_arregion  => (others => '0'),
      s_axi_aruser    => (others => '0'),
      s_axi_arvalid   => axisi.ar.valid,
      s_axi_arready   => axiso.ar.ready,
      s_axi_rid       => s_axi_rid,
      s_axi_rdata     => axiso.r.data(dwidth-1 downto 0),
      s_axi_rresp     => axiso.r.resp,
      s_axi_rlast     => axiso.r.last,
      s_axi_ruser     => open,
      s_axi_rvalid    => axiso.r.valid,
      s_axi_rready    => axisi.r.ready,

      -- Manager
      s_axi_arsel     => s_axi_arsel,
      m_axi_awid      => m_axi_awid,
      m_axi_awaddr    => m_axi_awaddr,
      m_axi_awlen     => m_axi_awlen,
      m_axi_awsize    => m_axi_awsize,
      m_axi_awburst   => m_axi_awburst,
      m_axi_awlock    => m_axi_awlock,
      m_axi_awcache   => m_axi_awcache,
      m_axi_awprot    => m_axi_awprot,
      m_axi_awqos     => m_axi_awqos,
      m_axi_awregion  => open,
      m_axi_awuser    => open,
      m_axi_awvalid   => m_axi_awvalid,
      m_axi_awready   => m_axi_awready,
      m_axi_wdata     => m_axi_wdata,
      m_axi_wstrb     => m_axi_wstrb,
      m_axi_wlast     => m_axi_wlast,
      m_axi_wuser     => open,
      m_axi_wvalid    => m_axi_wvalid,
      m_axi_wready    => m_axi_wready,
      m_axi_bid       => m_axi_bid,
      m_axi_bresp     => m_axi_bresp,
      m_axi_buser     => (others => '0'),
      m_axi_bvalid    => m_axi_bvalid,
      m_axi_bready    => m_axi_bready,
      m_axi_arid      => m_axi_arid,
      m_axi_araddr    => m_axi_araddr,
      m_axi_arlen     => m_axi_arlen,
      m_axi_arsize    => m_axi_arsize,
      m_axi_arburst   => m_axi_arburst,
      m_axi_arlock    => m_axi_arlock,
      m_axi_arcache   => m_axi_arcache,
      m_axi_arprot    => m_axi_arprot,
      m_axi_arqos     => m_axi_arqos,
      m_axi_arregion  => open,
      m_axi_aruser    => open,
      m_axi_arvalid   => m_axi_arvalid,
      m_axi_arready   => m_axi_arready,
      m_axi_rid       => m_axi_rid,
      m_axi_rdata     => m_axi_rdata,
      m_axi_rresp     => m_axi_rresp,
      m_axi_rlast     => m_axi_rlast,
      m_axi_ruser     => (others => '0'),
      m_axi_rvalid    => m_axi_rvalid,
      m_axi_rready    => m_axi_rready
    );

    gen_manager : for i in 0 to nmanports-1 generate
      p_m_aw : process(m_axi_awid, m_axi_awaddr)
        variable awid   : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
        variable awaddr : std_logic_vector(63 downto 0);
      begin
        awid                      := (others => '0');
        awid(idwidth-1 downto 0)  := m_axi_awid((i+1)*idwidth-1 downto i*idwidth);
        aximo(i).aw.id            <= awid(AXI_ID_WIDTH-1 downto 0);
        axixmo(i).aw.id           <= awid(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH);
        awaddr                    := (others => '0');
        awaddr(awidth-1 downto 0) := m_axi_awaddr((i+1)*awidth-1 downto i*awidth);
        aximo(i).aw.addr          <= awaddr(31 downto 0);
        axixmo(i).aw.addr         <= awaddr(63 downto 32);
      end process;
      aximo(i).aw.len   <= m_axi_awlen((i+1)*8-1 downto i*8);
      aximo(i).aw.size  <= m_axi_awsize((i+1)*3-1 downto i*3);
      aximo(i).aw.burst <= m_axi_awburst((i+1)*2-1 downto i*2);
      aximo(i).aw.lock  <= m_axi_awlock(i);
      aximo(i).aw.cache <= m_axi_awcache((i+1)*4-1 downto i*4);
      aximo(i).aw.prot  <= m_axi_awprot((i+1)*3-1 downto i*3);
      aximo(i).aw.qos   <= m_axi_awqos((i+1)*4-1 downto i*4);
      aximo(i).aw.valid <= m_axi_awvalid(i);

      aximo(i).w.data(dwidth-1 downto 0)    <= m_axi_wdata((i+1)*dwidth-1 downto i*dwidth);
      aximo(i).w.strb(dwidth/8-1 downto 0)  <= m_axi_wstrb((i+1)*dwidth/8-1 downto i*dwidth/8);
      aximo(i).w.last                       <= m_axi_wlast(i);
      aximo(i).w.valid                      <= m_axi_wvalid(i);

      aximo(i).b.ready  <= m_axi_bready(i);

      p_m_ar : process(m_axi_arid, m_axi_araddr)
        variable arid   : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
        variable araddr : std_logic_vector(63 downto 0);
      begin
        arid                      := (others => '0');
        arid(idwidth-1 downto 0)  := m_axi_arid((i+1)*idwidth-1 downto i*idwidth);
        aximo(i).ar.id            <= arid(AXI_ID_WIDTH-1 downto 0);
        axixmo(i).ar.id           <= arid(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH);
        araddr                    := (others => '0');
        araddr(awidth-1 downto 0) := m_axi_araddr((i+1)*awidth-1 downto i*awidth);
        aximo(i).ar.addr          <= araddr(31 downto 0);
        axixmo(i).ar.addr         <= araddr(63 downto 32);
      end process;
      aximo(i).ar.len   <= m_axi_arlen((i+1)*8-1 downto i*8);
      aximo(i).ar.size  <= m_axi_arsize((i+1)*3-1 downto i*3);
      aximo(i).ar.burst <= m_axi_arburst((i+1)*2-1 downto i*2);
      aximo(i).ar.lock  <= m_axi_arlock(i);
      aximo(i).ar.cache <= m_axi_arcache((i+1)*4-1 downto i*4);
      aximo(i).ar.prot  <= m_axi_arprot((i+1)*3-1 downto i*3);
      aximo(i).ar.qos   <= m_axi_arqos((i+1)*4-1 downto i*4);
      aximo(i).ar.valid <= m_axi_arvalid(i);

      aximo(i).r.ready  <= m_axi_rready(i);

      m_axi_awready(i)  <= aximi(i).aw.ready;

      m_axi_wready(i)   <= aximi(i).w.ready;

      m_axi_bid((i+1)*idwidth-1 downto i*idwidth) <= std_logic_vector(resize(unsigned(axixmi(i).b.id) & unsigned(aximi(i).b.id), idwidth));
      m_axi_bresp((i+1)*2-1 downto i*2)           <= aximi(i).b.resp;
      m_axi_bvalid(i)                             <= aximi(i).b.valid;

      m_axi_arready(i) <= aximi(i).ar.ready;

      m_axi_rid((i+1)*idwidth-1 downto i*idwidth) <= std_logic_vector(resize(unsigned(axixmi(i).r.id) & unsigned(aximi(i).r.id), idwidth));
      m_axi_rdata((i+1)*dwidth-1 downto i*dwidth) <= aximi(i).r.data(dwidth-1 downto 0);
      m_axi_rresp((i+1)*2-1 downto i*2)           <= aximi(i).r.resp;
      m_axi_rlast(i)                              <= aximi(i).r.last;
      m_axi_rvalid(i)                             <= aximi(i).r.valid;
    end generate;

end;