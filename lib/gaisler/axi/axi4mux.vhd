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
-- Description: AXI multiplexer
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
library techmap;
use techmap.gencomp.all;

entity axi4mux is
  generic (
    memtech     : integer;
    nsubports   : integer;
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
    s_axi_awid      : in  std_logic_vector(nsubports*idwidth-1 downto 0);
    s_axi_awaddr    : in  std_logic_vector(nsubports*awidth-1 downto 0);
    s_axi_awlen     : in  std_logic_vector(nsubports*8-1 downto 0);
    s_axi_awsize    : in  std_logic_vector(nsubports*3-1 downto 0);
    s_axi_awburst   : in  std_logic_vector(nsubports*2-1 downto 0);
    s_axi_awlock    : in  std_logic_vector(nsubports-1 downto 0);
    s_axi_awcache   : in  std_logic_vector(nsubports*4-1 downto 0);
    s_axi_awprot    : in  std_logic_vector(nsubports*3-1 downto 0);
    s_axi_awqos     : in  std_logic_vector(nsubports*4-1 downto 0);
    s_axi_awregion  : in  std_logic_vector(nsubports*4-1 downto 0);
    s_axi_awuser    : in  std_logic_vector(nsubports*axuserwidth-1 downto 0);
    s_axi_awvalid   : in  std_logic_vector(nsubports-1 downto 0);
    s_axi_awready   : out std_logic_vector(nsubports-1 downto 0);

    s_axi_wdata     : in  std_logic_vector(nsubports*dwidth-1 downto 0);
    s_axi_wstrb     : in  std_logic_vector(nsubports*dwidth/8-1 downto 0);
    s_axi_wlast     : in  std_logic_vector(nsubports-1 downto 0);
    s_axi_wuser     : in  std_logic_vector(nsubports*wuserwidth-1 downto 0);
    s_axi_wvalid    : in  std_logic_vector(nsubports-1 downto 0);
    s_axi_wready    : out std_logic_vector(nsubports-1 downto 0);

    s_axi_bid       : out std_logic_vector(nsubports*idwidth-1 downto 0);
    s_axi_bresp     : out std_logic_vector(nsubports*2-1 downto 0);
    s_axi_buser     : out std_logic_vector(nsubports*buserwidth-1 downto 0);
    s_axi_bvalid    : out std_logic_vector(nsubports-1 downto 0);
    s_axi_bready    : in  std_logic_vector(nsubports-1 downto 0);

    s_axi_arid      : in  std_logic_vector(nsubports*idwidth-1 downto 0);
    s_axi_araddr    : in  std_logic_vector(nsubports*awidth-1 downto 0);
    s_axi_arlen     : in  std_logic_vector(nsubports*8-1 downto 0);
    s_axi_arsize    : in  std_logic_vector(nsubports*3-1 downto 0);
    s_axi_arburst   : in  std_logic_vector(nsubports*2-1 downto 0);
    s_axi_arlock    : in  std_logic_vector(nsubports-1 downto 0);
    s_axi_arcache   : in  std_logic_vector(nsubports*4-1 downto 0);
    s_axi_arprot    : in  std_logic_vector(nsubports*3-1 downto 0);
    s_axi_arqos     : in  std_logic_vector(nsubports*4-1 downto 0);
    s_axi_arregion  : in  std_logic_vector(nsubports*4-1 downto 0);
    s_axi_aruser    : in  std_logic_vector(nsubports*axuserwidth-1 downto 0);
    s_axi_arvalid   : in  std_logic_vector(nsubports-1 downto 0);
    s_axi_arready   : out std_logic_vector(nsubports-1 downto 0);

    s_axi_rid       : out std_logic_vector(nsubports*idwidth-1 downto 0);
    s_axi_rdata     : out std_logic_vector(nsubports*dwidth-1 downto 0);
    s_axi_rresp     : out std_logic_vector(nsubports*2-1 downto 0);
    s_axi_rlast     : out std_logic_vector(nsubports-1 downto 0);
    s_axi_ruser     : out std_logic_vector(nsubports*buserwidth-1 downto 0);
    s_axi_rvalid    : out std_logic_vector(nsubports-1 downto 0);
    s_axi_rready    : in  std_logic_vector(nsubports-1 downto 0);

    -- Manager
    m_axi_awid      : out std_logic_vector(log2(nsubports)+idwidth-1 downto 0);
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

    m_axi_bid       : in  std_logic_vector(log2(nsubports)+idwidth-1 downto 0);
    m_axi_bresp     : in  std_logic_vector(2-1 downto 0);
    m_axi_buser     : in  std_logic_vector(buserwidth-1 downto 0);
    m_axi_bvalid    : in  std_logic;
    m_axi_bready    : out std_logic;

    m_axi_arid      : out std_logic_vector(log2(nsubports)+idwidth-1 downto 0);
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

    m_axi_rid       : in  std_logic_vector(log2(nsubports)+idwidth-1 downto 0);
    m_axi_rdata     : in  std_logic_vector(dwidth-1 downto 0);
    m_axi_rresp     : in  std_logic_vector(2-1 downto 0);
    m_axi_rlast     : in  std_logic;
    m_axi_ruser     : in  std_logic_vector(ruserwidth-1 downto 0);
    m_axi_rvalid    : in  std_logic;
    m_axi_rready    : out std_logic
  );
end;

architecture rtl of axi4mux is

  constant ASYNC_RST  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant RESET_ALL  : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

  constant selwidth   : integer := log2x(nsubports);
  constant midwidth   : integer := selwidth+idwidth;
  subtype selrange is integer range midwidth-1 downto idwidth;

  constant axwidth    : integer := idwidth + awidth + 8 + 3 + 2 + 1 + 4 + 3 + 4 + 4 + axuserwidth;
  constant wwidth     : integer := dwidth + dwidth/8 + 1 + wuserwidth;

  subtype s_ax_type is std_logic_vector(nsubports*axwidth-1 downto 0);
  subtype s_w_type is std_logic_vector(nsubports*wwidth-1 downto 0);
  subtype m_ax_type is std_logic_vector(axwidth-1 downto 0);

  signal s_aw : s_ax_type;
  signal s_ar : s_ax_type;
  signal m_aw : m_ax_type;
  signal m_ar : m_ax_type;

  signal awsel            : std_logic_vector(selwidth-1 downto 0);
  signal awvalid, awready : std_ulogic;
  signal wfull, wempty    : std_ulogic;
  signal wpush, wpop      : std_ulogic;
  signal wsel             : std_logic_vector(selwidth-1 downto 0);
  signal wseli            : integer;

begin

  gen_subordinate : for i in 0 to nsubports-1 generate
    s_aw((i+1)*axwidth-1 downto i*axwidth)              <= s_axi_awid((i+1)*idwidth-1 downto i*idwidth) &
                                                           s_axi_awaddr((i+1)*awidth-1 downto i*awidth) &
                                                           s_axi_awlen((i+1)*8-1 downto i*8) &
                                                           s_axi_awsize((i+1)*3-1 downto i*3) &
                                                           s_axi_awburst((i+1)*2-1 downto i*2) &
                                                           s_axi_awlock(i) &
                                                           s_axi_awcache((i+1)*4-1 downto i*4) &
                                                           s_axi_awprot((i+1)*3-1 downto i*3) &
                                                           s_axi_awqos((i+1)*4-1 downto i*4) &
                                                           s_axi_awregion((i+1)*4-1 downto i*4) &
                                                           s_axi_awuser((i+1)*axuserwidth-1 downto i*axuserwidth);
    s_axi_bid((i+1)*idwidth-1 downto i*idwidth)         <= m_axi_bid(idwidth-1 downto 0);
    s_axi_bresp((i+1)*2-1 downto i*2)                   <= m_axi_bresp;
    s_axi_buser((i+1)*buserwidth-1 downto i*buserwidth) <= m_axi_buser;
    s_ar((i+1)*axwidth-1 downto i*axwidth)              <= s_axi_arid((i+1)*idwidth-1 downto i*idwidth) &
                                                           s_axi_araddr((i+1)*awidth-1 downto i*awidth) &
                                                           s_axi_arlen((i+1)*8-1 downto i*8) &
                                                           s_axi_arsize((i+1)*3-1 downto i*3) &
                                                           s_axi_arburst((i+1)*2-1 downto i*2) &
                                                           s_axi_arlock(i) &
                                                           s_axi_arcache((i+1)*4-1 downto i*4) &
                                                           s_axi_arprot((i+1)*3-1 downto i*3) &
                                                           s_axi_arqos((i+1)*4-1 downto i*4) &
                                                           s_axi_arregion((i+1)*4-1 downto i*4) &
                                                           s_axi_aruser((i+1)*axuserwidth-1 downto i*axuserwidth);
    s_axi_rid((i+1)*idwidth-1 downto i*idwidth)         <= m_axi_rid(idwidth-1 downto 0);
    s_axi_rdata((i+1)*dwidth-1 downto i*dwidth)         <= m_axi_rdata;
    s_axi_rresp((i+1)*2-1 downto i*2)                   <= m_axi_rresp;
    s_axi_rlast(i)                                      <= m_axi_rlast;
    s_axi_ruser((i+1)*buserwidth-1 downto i*buserwidth) <= m_axi_ruser;
  end generate;

  awarbiter : arbiter_tree
    generic map (
      nreq      => nsubports,
      dwidth    => axwidth,
      arb_prio  => 2,
      arb_lock  => 1
    )
    port map (
      clk   => aclk,
      rstn  => aresetn,
      sdata => s_aw,
      sreq  => s_axi_awvalid,
      sgnt  => s_axi_awready,
      msel  => awsel,
      mdata => m_aw,
      mreq  => awvalid,
      mgnt  => awready
    );
  m_axi_awid(selrange) <= awsel;
  ax_unpack(m_aw, m_axi_awid(idwidth-1 downto 0), m_axi_awaddr, m_axi_awlen, m_axi_awsize, m_axi_awburst, m_axi_awlock, m_axi_awcache, m_axi_awprot, m_axi_awqos, m_axi_awregion, m_axi_awuser);

  m_axi_awvalid <= awvalid and not wfull;
  awready       <= m_axi_awready and not wfull;

  wpush <= awvalid and awready;

  wselfifo : syncfifo_2p
    generic map(
      tech  => memtech,
      abits => log2x(maxtrans),
      dbits => selwidth, -- Response + last + data
      sepclk => 0, -- Not separate clocks
      afullwl => 0, -- Almost full
      aemptyrl => 0, -- No need to consider almost empty.
      fwft => 1, -- first word fall-through
      piperead => 1, -- output pipeline stage
      ft => 0, -- fault tolerance?
      custombits => memtest_vlen,
      rdhold => 1 -- Don't hold read value after pop.
      -- scantest => scantest,
      -- arstr => 0, -- synchronous reset
      -- arstw => 0 -- synchronous reset
    )
    port map(
      rclk    => aclk,
      rrstn   => aresetn,
      wrstn   => aresetn,
      renable => wpop,
      rfull   => open,
      rempty  => wempty,
      aempty  => open,
      rusedw  => open,
      dataout => wsel,
      wclk    => aclk,
      write   => wpush,
      wfull   => open,
      afull   => wfull,
      wempty  => open,
      wusedw  => open,
      datain  => awsel,
      dynsync => '0',
      error    => open
    );

  wmux : process(wsel, wempty, m_axi_wready, s_axi_wdata, s_axi_wstrb, s_axi_wlast, s_axi_wuser, s_axi_wvalid)
  begin
    s_axi_wready  <= (others => '0');

    m_axi_wdata   <= (others => '0');
    m_axi_wstrb   <= (others => '0');
    m_axi_wlast   <= '0';
    m_axi_wuser   <= (others => '0');
    m_axi_wvalid  <= '0';

    wpop          <= '0';
    for i in 0 to nsubports-1 loop
      if i = unsigned(wsel) then
        m_axi_wdata     <= s_axi_wdata((i+1)*dwidth-1 downto i*dwidth);
        m_axi_wstrb     <= s_axi_wstrb((i+1)*dwidth/8-1 downto i*dwidth/8);
        m_axi_wlast     <= s_axi_wlast(i);
        m_axi_wuser     <= s_axi_wuser((i+1)*wuserwidth-1 downto i*wuserwidth);
        m_axi_wvalid    <= s_axi_wvalid(i) and not wempty;

        s_axi_wready(i) <= m_axi_wready and not wempty;

        wpop            <= s_axi_wvalid(i) and m_axi_wready and s_axi_wlast(i) and not wempty;
      end if;
    end loop;
  end process;

  bdemux : process(s_axi_bready, m_axi_bvalid, m_axi_bid)
  begin
    s_axi_bvalid <= (others => '0');
    m_axi_bready <= '0';
    for i in 0 to nsubports-1 loop
      if i = unsigned(m_axi_bid(selrange)) then
        s_axi_bvalid(i) <= m_axi_bvalid;
        m_axi_bready    <= s_axi_bready(i);
      end if;
    end loop;
  end process;

  ararbiter : arbiter_tree
    generic map (
      nreq      => nsubports,
      dwidth    => axwidth,
      arb_prio  => 2,
      arb_lock  => 1
    )
    port map (
      clk   => aclk,
      rstn  => aresetn,
      sdata => s_ar,
      sreq  => s_axi_arvalid,
      sgnt  => s_axi_arready,
      msel  => m_axi_arid(selrange),
      mdata => m_ar,
      mreq  => m_axi_arvalid,
      mgnt  => m_axi_arready
    );
  ax_unpack(m_ar, m_axi_arid(idwidth-1 downto 0), m_axi_araddr, m_axi_arlen, m_axi_arsize, m_axi_arburst, m_axi_arlock, m_axi_arcache, m_axi_arprot, m_axi_arqos, m_axi_arregion, m_axi_aruser);

  rdemux : process(s_axi_rready, m_axi_rvalid, m_axi_rid)
  begin
    s_axi_rvalid <= (others => '0');
    m_axi_rready <= '0';
    for i in 0 to nsubports-1 loop
      if i = unsigned(m_axi_rid(selrange)) then
        s_axi_rvalid(i) <= m_axi_rvalid;
        m_axi_rready    <= s_axi_rready(i);
      end if;
    end loop;
  end process;

end;