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
-- Entity:      axi4nullslv
-- File:        axi4nullslv.vhd
-- Author:      Martin Caous George - Frontgrade Gaisler
-- Description: AXI4 slave returning dummy data and ignoring writes
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.config.all;
use grlib.config_types.all;
library gaisler;
use gaisler.axi.all;

entity axi4nullslv is
  generic (
    idwidth   : integer := AXI_ID_WIDTH;
    dwidth    : integer := AXIDW
  );
  port (
    aclk    : in  std_ulogic;
    aresetn : in  std_ulogic;
    axisi   : in  axi4_mosi_type;
    axixsi  : in  extaxi_mosi_type := extaxi_mosi_none;
    axiso   : out axi_somi_type;
    axixso  : out extaxi_miso_type;
    xresp   : in  std_logic_vector(1 downto 0) := XRESP_OKAY;
    rdata   : in  std_logic_vector(dwidth-1 downto 0) := (others => '0')
  );
end;

architecture rtl of axi4nullslv is

  constant ASYNC_RST  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  constant awwidth : integer := idwidth;
  constant arwidth : integer := idwidth + 8;

  type axinullslv_regs is record
    wready  : std_ulogic;
    bid     : std_logic_vector(log2x(2**idwidth)-1 downto 0);
    bvalid  : std_ulogic;
    arlen   : std_logic_vector(7 downto 0);
    rid     : std_logic_vector(log2x(2**idwidth)-1 downto 0);
    rlast   : std_ulogic;
    rvalid  : std_ulogic;
  end record;

  constant axinullslv_regs_reset : axinullslv_regs := (
    wready  => '1',
    bid     => (others => '0'),
    bvalid  => '0',
    arlen   => (others => '0'),
    rid     => (others => '0'),
    rlast   => '0',
    rvalid  => '0'
  );

  signal r,nr: axinullslv_regs;

  signal awsi     : std_logic_vector(log2x(2**awwidth)-1 downto 0);
  signal arsi     : std_logic_vector(arwidth-1 downto 0);

  signal aw       : std_logic_vector(log2x(2**awwidth)-1 downto 0);
  signal awvalid  : std_ulogic;
  signal awready  : std_ulogic;
  signal wlast    : std_ulogic;
  signal wvalid   : std_ulogic;
  signal wready   : std_ulogic;
  signal ar       : std_logic_vector(arwidth-1 downto 0);
  signal arvalid  : std_ulogic;
  signal arready  : std_ulogic;

begin

  -- AW
  awproc : process(axisi, axixsi)
    variable id : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
  begin
    id := axixsi.aw.id & axisi.aw.id;
    awsi <= (others => '0');
    if idwidth > 0 then
      awsi(idwidth-1 downto 0) <= id(idwidth-1 downto 0);
    end if;
  end process;

  aw_slice : register_slice
  generic map (
    dwidth    => log2x(2**awwidth),
    direction => 0,
    bypass    => 0
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => awsi,
    s_xvalid  => axisi.aw.valid,
    s_xready  => axiso.aw.ready,

    m_xdata   => aw,
    m_xvalid  => awvalid,
    m_xready  => awready
  );

  w_slice : register_slice
  generic map (
    dwidth    => 1,
    direction => 0,
    bypass    => 0
  )
  port map (
    clk         => aclk,
    rstn        => aresetn,

    s_xdata(0)  => axisi.w.last,
    s_xvalid    => axisi.w.valid,
    s_xready    => axiso.w.ready,

    m_xdata(0)  => wlast,
    m_xvalid    => wvalid,
    m_xready    => wready
  );

  -- AR
  arproc : process(axisi, axixsi)
    variable id : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
  begin
    id := axixsi.ar.id & axisi.ar.id;
    arsi <= (others => '0');
    arsi(7 downto 0) <= axisi.ar.len;
    if idwidth > 0 then
      arsi(8+idwidth-1 downto 8) <= id(idwidth-1 downto 0);
    end if;
  end process;

  ar_slice : register_slice
  generic map (
    dwidth    => arwidth,
    direction => 0,
    bypass    => 0
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => arsi,
    s_xvalid  => axisi.ar.valid,
    s_xready  => axiso.ar.ready,

    m_xdata   => ar,
    m_xvalid  => arvalid,
    m_xready  => arready
  );

  comb: process(aresetn,axisi,aw,wlast,ar,r,xresp,rdata,awvalid,wvalid,arvalid)
    variable v        : axinullslv_regs;
    variable bid      : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
    variable rid      : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
    variable vawready : std_logic;
    variable vwready  : std_logic;
    variable varready : std_logic;
  begin
    v := r;

    vawready  := wvalid and not r.wready and (not r.bvalid or axisi.b.ready);
    vwready   := (awvalid and not r.wready and (not r.bvalid or axisi.b.ready)) or r.wready;
    varready  := not r.rvalid or (axisi.r.ready and r.rlast);

    if axisi.b.ready='1' and r.bvalid='1' then
      v.bvalid  := '0';
    end if;
    if awvalid='1' and vawready='1' then
      v.wready := '1';
      if idwidth > 0 then
        v.bid := aw;
      end if;
    end if;
    if wvalid='1' and vwready='1' and wlast='1' then
      v.wready := '0';
      v.bvalid := '1';
    end if;
    if axisi.r.ready='1' and r.rvalid='1' then
      v.arlen := std_logic_vector(unsigned(r.arlen)-1);
      if r.rlast='1' then
        v.rvalid := '0';
      end if;
    end if;
    if arvalid='1' and varready='1' then
      v.rvalid := '1';
      v.arlen  := ar(7 downto 0);
      if idwidth > 0 then
        v.rid := ar(8+idwidth-1 downto 8);
      end if;
    end if;

    v.rlast := '0';
    if v.arlen=x"00" then
      v.rlast:='1';
    end if;

    if not ASYNC_RST and aresetn='0' then
      v.wready  := '0';
      v.bvalid  := '0';
      v.rlast   := '0';
      v.rvalid  := '0';
    end if;

    nr <= v;

    bid := (others => '0');
    rid := (others => '0');
    if idwidth > 0 then
      bid(idwidth-1 downto 0) := r.bid;
      rid(idwidth-1 downto 0) := r.rid;
    end if;
    axiso.b <= (id => bid(AXI_ID_WIDTH-1 downto 0), resp => xresp, valid => r.bvalid);
    axiso.r <= (id => rid(AXI_ID_WIDTH-1 downto 0), data => (others => '0'), resp => xresp, last => r.rlast, valid => r.rvalid);
    axixso <= (
      b   => (id => bid(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH)),
      r   => (id => rid(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH))
    );
    axiso.r.data(dwidth-1 downto 0) <= rdata;

    awready <= vawready;
    wready  <= vwready;
    arready <= varready;
  end process;

  regs: process(aclk, aresetn)
  begin
    if ASYNC_RST and aresetn='0' then
      r.wready  <= '0';
      r.bvalid  <= '0';
      r.rlast   <= '0';
      r.rvalid  <= '0';
    elsif rising_edge(aclk) then
      r <= nr;
    end if;
  end process;

end;
