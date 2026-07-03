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
-- Entity:      axi4mux_wrapper
-- File:        axi4mux_wrapper.vhd
-- Author:      Martin Caous George - Frontgrade Gaisler AB
-- Description: AXI multiplexer AMBA AXI4 type wrapper
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

entity axi4mux_wrapper is
  generic (
    memtech       : integer;
    nsubports     : integer;
    maxtrans      : integer;
    idwidth_used  : integer range 0 to AXI_ID_WIDTH;
    awidth        : integer range 12 to 64 := 32;
    dwidth        : integer range 8 to AXIDW := AXIDW
  );
  port (
    aclk        : in  std_ulogic;
    aresetn     : in  std_ulogic;

    -- Subordinates
    axisi       : in  axi4_mosi_vector_type(0 to nsubports-1);
    axixsi      : in  extaxi_mosi_vector_type(0 to nsubports-1) := (others => extaxi_mosi_none);
    axiso       : out axi_somi_vector_type(0 to nsubports-1);
    axixso      : out extaxi_miso_vector_type(0 to nsubports-1);

    -- Manager
    aximo       : out axi4_mosi_type;
    axixmo      : out extaxi_mosi_type;
    aximi       : in  axi_somi_type;
    axixmi      : in  extaxi_miso_type := extaxi_miso_none
  );
end;

architecture rtl of axi4mux_wrapper is

  constant idwidth : integer := idwidth_used + log2(nsubports);

      -- Subordinates
  signal s_axi_awid     : std_logic_vector(nsubports*idwidth_used-1 downto 0);
  signal s_axi_awaddr   : std_logic_vector(nsubports*awidth-1 downto 0);
  signal s_axi_awlen    : std_logic_vector(nsubports*8-1 downto 0);
  signal s_axi_awsize   : std_logic_vector(nsubports*3-1 downto 0);
  signal s_axi_awburst  : std_logic_vector(nsubports*2-1 downto 0);
  signal s_axi_awlock   : std_logic_vector(nsubports-1 downto 0);
  signal s_axi_awcache  : std_logic_vector(nsubports*4-1 downto 0);
  signal s_axi_awprot   : std_logic_vector(nsubports*3-1 downto 0);
  signal s_axi_awqos    : std_logic_vector(nsubports*4-1 downto 0);
  signal s_axi_awvalid  : std_logic_vector(nsubports-1 downto 0);
  signal s_axi_awready  : std_logic_vector(nsubports-1 downto 0);

  signal s_axi_wdata    : std_logic_vector(nsubports*dwidth-1 downto 0);
  signal s_axi_wstrb    : std_logic_vector(nsubports*dwidth/8-1 downto 0);
  signal s_axi_wlast    : std_logic_vector(nsubports-1 downto 0);
  signal s_axi_wvalid   : std_logic_vector(nsubports-1 downto 0);
  signal s_axi_wready   : std_logic_vector(nsubports-1 downto 0);

  signal s_axi_bid      : std_logic_vector(nsubports*idwidth_used-1 downto 0);
  signal s_axi_bresp    : std_logic_vector(nsubports*2-1 downto 0);
  signal s_axi_bvalid   : std_logic_vector(nsubports-1 downto 0);
  signal s_axi_bready   : std_logic_vector(nsubports-1 downto 0);

  signal s_axi_arid     : std_logic_vector(nsubports*idwidth_used-1 downto 0);
  signal s_axi_araddr   : std_logic_vector(nsubports*awidth-1 downto 0);
  signal s_axi_arlen    : std_logic_vector(nsubports*8-1 downto 0);
  signal s_axi_arsize   : std_logic_vector(nsubports*3-1 downto 0);
  signal s_axi_arburst  : std_logic_vector(nsubports*2-1 downto 0);
  signal s_axi_arlock   : std_logic_vector(nsubports-1 downto 0);
  signal s_axi_arcache  : std_logic_vector(nsubports*4-1 downto 0);
  signal s_axi_arprot   : std_logic_vector(nsubports*3-1 downto 0);
  signal s_axi_arqos    : std_logic_vector(nsubports*4-1 downto 0);
  signal s_axi_arvalid  : std_logic_vector(nsubports-1 downto 0);
  signal s_axi_arready  : std_logic_vector(nsubports-1 downto 0);

  signal s_axi_rid      : std_logic_vector(nsubports*idwidth_used-1 downto 0);
  signal s_axi_rdata    : std_logic_vector(nsubports*dwidth-1 downto 0);
  signal s_axi_rresp    : std_logic_vector(nsubports*2-1 downto 0);
  signal s_axi_rlast    : std_logic_vector(nsubports-1 downto 0);
  signal s_axi_rvalid   : std_logic_vector(nsubports-1 downto 0);
  signal s_axi_rready   : std_logic_vector(nsubports-1 downto 0);

  signal m_axi_awid     : std_logic_vector(idwidth-1 downto 0);
  signal m_axi_awaddr   : std_logic_vector(awidth-1 downto 0);
  signal m_axi_bid      : std_logic_vector(idwidth-1 downto 0);
  signal m_axi_arid     : std_logic_vector(idwidth-1 downto 0);
  signal m_axi_araddr   : std_logic_vector(awidth-1 downto 0);
  signal m_axi_rid      : std_logic_vector(idwidth-1 downto 0);

begin

  assert idwidth <= AXI_ID_WIDTH
    report "axi4mux: AXI ID does not fit into record type id field, using extended id field" severity note;
  assert idwidth <= 2*AXI_ID_WIDTH
    report "axi4mux: AXI ID does not fit into record type id field and extended id field" severity failure;

  gen_amba_to_slv : for i in 0 to nsubports-1 generate
    gen_awaddr : if awidth <= 32 generate
      s_axi_awaddr((i+1)*awidth-1 downto i*awidth) <= axisi(i).aw.addr(awidth-1 downto 0);
    end generate;
    gen_awaddr_hi : if awidth > 32 generate
      s_axi_awaddr((i+1)*awidth-1 downto i*awidth) <= axixsi(i).aw.addr(awidth-32-1 downto 0) & axisi(i).aw.addr;
    end generate;
    s_axi_awlen((i+1)*8-1 downto i*8)             <= axisi(i).aw.len;
    s_axi_awsize((i+1)*3-1 downto i*3)            <= axisi(i).aw.size;
    s_axi_awburst((i+1)*2-1 downto i*2)           <= axisi(i).aw.burst;
    s_axi_awlock(i)                               <= axisi(i).aw.lock;
    s_axi_awcache((i+1)*4-1 downto i*4)           <= axisi(i).aw.cache;
    s_axi_awprot((i+1)*3-1 downto i*3)            <= axisi(i).aw.prot;
    s_axi_awqos((i+1)*4-1 downto i*4)             <= axisi(i).aw.qos;
    s_axi_awvalid(i)                              <= axisi(i).aw.valid;
    axiso(i).aw.ready                             <= s_axi_awready(i);

    s_axi_wdata((i+1)*dwidth-1 downto i*dwidth)     <= axisi(i).w.data(dwidth-1 downto 0);
    s_axi_wstrb((i+1)*dwidth/8-1 downto i*dwidth/8) <= axisi(i).w.strb(dwidth/8-1 downto 0);
    s_axi_wlast(i)                                <= axisi(i).w.last;
    s_axi_wvalid(i)                               <= axisi(i).w.valid;
    axiso(i).w.ready                              <= s_axi_wready(i);

    axiso(i).b.resp                               <= s_axi_bresp((i+1)*2-1 downto i*2);
    axiso(i).b.valid                              <= s_axi_bvalid(i);
    s_axi_bready(i)                               <= axisi(i).b.ready;

    gen_araddr : if awidth <= 32 generate
      s_axi_araddr((i+1)*awidth-1 downto i*awidth) <= axisi(i).ar.addr(awidth-1 downto 0);
    end generate;
    gen_araddr_hi : if awidth > 32 generate
      s_axi_araddr((i+1)*awidth-1 downto i*awidth) <= axixsi(i).ar.addr(awidth-32-1 downto 0) & axisi(i).ar.addr;
    end generate;
    s_axi_arlen((i+1)*8-1 downto i*8)             <= axisi(i).ar.len;
    s_axi_arsize((i+1)*3-1 downto i*3)            <= axisi(i).ar.size;
    s_axi_arburst((i+1)*2-1 downto i*2)           <= axisi(i).ar.burst;
    s_axi_arlock(i)                               <= axisi(i).ar.lock;
    s_axi_arcache((i+1)*4-1 downto i*4)           <= axisi(i).ar.cache;
    s_axi_arprot((i+1)*3-1 downto i*3)            <= axisi(i).ar.prot;
    s_axi_arqos((i+1)*4-1 downto i*4)             <= axisi(i).ar.qos;
    s_axi_arvalid(i)                              <= axisi(i).ar.valid;
    axiso(i).ar.ready                             <= s_axi_arready(i);

    axiso(i).r.data(dwidth-1 downto 0)            <= s_axi_rdata((i+1)*dwidth-1 downto i*dwidth);
    axiso(i).r.resp                               <= s_axi_rresp((i+1)*2-1 downto i*2);
    axiso(i).r.last                               <= s_axi_rlast(i);
    axiso(i).r.valid                              <= s_axi_rvalid(i);
    s_axi_rready(i)                               <= axisi(i).r.ready;

    gen_id : for j in 0 to 2*AXI_ID_WIDTH-1 generate
      idused : if j < idwidth_used generate
        -- Propagate valid IDs
        s_axi_awid(i*idwidth_used+j)  <= axisi(i).aw.id(j) when j < AXI_ID_WIDTH else axixsi(i).aw.id(j-AXI_ID_WIDTH);
        s_axi_arid(i*idwidth_used+j)  <= axisi(i).ar.id(j) when j < AXI_ID_WIDTH else axixsi(i).ar.id(j-AXI_ID_WIDTH);
        idrec : if j < AXI_ID_WIDTH generate
          axiso(i).b.id(j) <= s_axi_bid(i*idwidth_used+j);
          axiso(i).r.id(j) <= s_axi_rid(i*idwidth_used+j);
        end generate;
        idext : if j >= AXI_ID_WIDTH generate
          axixso(i).b.id(j-AXI_ID_WIDTH) <= s_axi_bid(i*idwidth_used+j);
          axixso(i).r.id(j-AXI_ID_WIDTH) <= s_axi_rid(i*idwidth_used+j);
        end generate;
      end generate;
      idnull : if j >= idwidth_used generate
        -- Set unused IDs to zero
        idrec : if j < AXI_ID_WIDTH generate
          axiso(i).b.id(j) <= '0';
          axiso(i).r.id(j) <= '0';
        end generate;
        idext : if j >= AXI_ID_WIDTH generate
          axixso(i).b.id(j-AXI_ID_WIDTH) <= '0';
          axixso(i).r.id(j-AXI_ID_WIDTH) <= '0';
        end generate;
      end generate;
    end generate;
  end generate;

  mux : axi4mux
    generic map (
      memtech     => memtech,
      nsubports   => nsubports,
      maxtrans    => maxtrans,
      awidth      => awidth,
      dwidth      => dwidth,
      idwidth     => idwidth_used,
      axuserwidth => 1,
      wuserwidth  => 1,
      buserwidth  => 1,
      ruserwidth  => 1
    )
    port map (
      aclk            => aclk,
      aresetn         => aresetn,

      -- Subordinates
      s_axi_awid      => s_axi_awid,
      s_axi_awaddr    => s_axi_awaddr,
      s_axi_awlen     => s_axi_awlen,
      s_axi_awsize    => s_axi_awsize,
      s_axi_awburst   => s_axi_awburst,
      s_axi_awlock    => s_axi_awlock,
      s_axi_awcache   => s_axi_awcache,
      s_axi_awprot    => s_axi_awprot,
      s_axi_awqos     => s_axi_awqos,
      s_axi_awregion  => (others => '0'),
      s_axi_awuser    => (others => '0'),
      s_axi_awvalid   => s_axi_awvalid,
      s_axi_awready   => s_axi_awready,

      s_axi_wdata     => s_axi_wdata,
      s_axi_wstrb     => s_axi_wstrb,
      s_axi_wlast     => s_axi_wlast,
      s_axi_wuser     => (others => '0'),
      s_axi_wvalid    => s_axi_wvalid,
      s_axi_wready    => s_axi_wready,

      s_axi_bid       => s_axi_bid,
      s_axi_bresp     => s_axi_bresp,
      s_axi_buser     => open,
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
      s_axi_arregion  => (others => '0'),
      s_axi_aruser    => (others => '0'),
      s_axi_arvalid   => s_axi_arvalid,
      s_axi_arready   => s_axi_arready,

      s_axi_rid       => s_axi_rid,
      s_axi_rdata     => s_axi_rdata,
      s_axi_rresp     => s_axi_rresp,
      s_axi_rlast     => s_axi_rlast,
      s_axi_ruser     => open,
      s_axi_rvalid    => s_axi_rvalid,
      s_axi_rready    => s_axi_rready,

      -- Manager
      m_axi_awid      => m_axi_awid,
      m_axi_awaddr    => m_axi_awaddr,
      m_axi_awlen     => aximo.aw.len,
      m_axi_awsize    => aximo.aw.size,
      m_axi_awburst   => aximo.aw.burst,
      m_axi_awlock    => aximo.aw.lock,
      m_axi_awcache   => aximo.aw.cache,
      m_axi_awprot    => aximo.aw.prot,
      m_axi_awqos     => aximo.aw.qos,
      m_axi_awregion  => open,
      m_axi_awuser    => open,
      m_axi_awvalid   => aximo.aw.valid,
      m_axi_awready   => aximi.aw.ready,

      m_axi_wdata     => aximo.w.data(dwidth-1 downto 0),
      m_axi_wstrb     => aximo.w.strb,
      m_axi_wlast     => aximo.w.last,
      m_axi_wuser     => open,
      m_axi_wvalid    => aximo.w.valid,
      m_axi_wready    => aximi.w.ready,

      m_axi_bid       => m_axi_bid,
      m_axi_bresp     => aximi.b.resp,
      m_axi_buser     => (others => '0'),
      m_axi_bvalid    => aximi.b.valid,
      m_axi_bready    => aximo.b.ready,

      m_axi_arid      => m_axi_arid,
      m_axi_araddr    => m_axi_araddr,
      m_axi_arlen     => aximo.ar.len,
      m_axi_arsize    => aximo.ar.size,
      m_axi_arburst   => aximo.ar.burst,
      m_axi_arlock    => aximo.ar.lock,
      m_axi_arcache   => aximo.ar.cache,
      m_axi_arprot    => aximo.ar.prot,
      m_axi_arqos     => aximo.ar.qos,
      m_axi_arregion  => open,
      m_axi_aruser    => open,
      m_axi_arvalid   => aximo.ar.valid,
      m_axi_arready   => aximi.ar.ready,

      m_axi_rid       => m_axi_rid,
      m_axi_rdata     => aximi.r.data(dwidth-1 downto 0),
      m_axi_rresp     => aximi.r.resp,
      m_axi_rlast     => aximi.r.last,
      m_axi_ruser     => (others => '0'),
      m_axi_rvalid    => aximi.r.valid,
      m_axi_rready    => aximo.r.ready
    );

  gen_unused_axid : if log2(nsubports) + idwidth_used < AXI_ID_WIDTH generate
    aximo.aw.id(AXI_ID_WIDTH-1 downto log2(nsubports)+idwidth_used) <= (others => '0');
    aximo.ar.id(AXI_ID_WIDTH-1 downto log2(nsubports)+idwidth_used) <= (others => '0');
  end generate;

  addr_id_ext : process(m_axi_awid, m_axi_awaddr, m_axi_arid, m_axi_araddr, aximi, axixmi)
  begin
    aximo.aw.id   <= (others => '0');
    aximo.aw.addr <= (others => '0');
    aximo.ar.id   <= (others => '0');
    aximo.ar.addr <= (others => '0');
    axixmo <= extaxi_mosi_none;

    if awidth <= 32 then
      aximo.aw.addr <= m_axi_awaddr(awidth-1 downto 0);
      aximo.ar.addr <= m_axi_araddr(awidth-1 downto 0);
    else
      aximo.aw.addr <= m_axi_awaddr(31 downto 0);
      aximo.ar.addr <= m_axi_araddr(31 downto 0);
      axixmo.aw.addr <= m_axi_awaddr(awidth-1 downto 32);
      axixmo.ar.addr <= m_axi_araddr(awidth-1 downto 32);
    end if;

    if idwidth <= AXI_ID_WIDTH then
      aximo.aw.id(idwidth-1 downto 0) <= m_axi_awid;
      aximo.ar.id(idwidth-1 downto 0) <= m_axi_arid;
      m_axi_bid <= aximi.b.id(idwidth-1 downto 0);
      m_axi_rid <= aximi.r.id(idwidth-1 downto 0);
    else
      aximo.aw.id <= m_axi_awid(AXI_ID_WIDTH-1 downto 0);
      aximo.ar.id <= m_axi_arid(AXI_ID_WIDTH-1 downto 0);

      axixmo.aw.id(idwidth-AXI_ID_WIDTH-1 downto 0) <= m_axi_awid(idwidth-1 downto AXI_ID_WIDTH);
      axixmo.ar.id(idwidth-AXI_ID_WIDTH-1 downto 0) <= m_axi_arid(idwidth-1 downto AXI_ID_WIDTH);

      m_axi_bid <= axixmi.b.id(idwidth-AXI_ID_WIDTH-1 downto 0) & aximi.b.id;
      m_axi_rid <= axixmi.r.id(idwidth-AXI_ID_WIDTH-1 downto 0) & aximi.r.id;
    end if;
  end process;

end;