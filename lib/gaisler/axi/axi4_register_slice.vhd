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
    awidth      : integer range 1 to 64;
    dwidth      : integer;
    idwidth     : integer range 0 to 2**AXI_ID_WIDTH;
    regionwidth : integer range 0 to 4 := 0;
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
    aclk    : in  std_ulogic;
    aresetn : in  std_ulogic;
    -- AXI subordinate port
    axisi   : in  axi4_mosi_type;
    axixsi  : in  extaxi_mosi_type := extaxi_mosi_none;
    axiso   : out axi_somi_type;
    axixso  : out extaxi_miso_type;
    -- AXI manager port
    aximo   : out axi4_mosi_type;
    axixmo  : out extaxi_mosi_type;
    aximi   : in  axi_somi_type;
    axixmi  : in  extaxi_miso_type := extaxi_miso_none
  );
end;

architecture rtl of axi4_register_slice is

  constant axwidth  : integer := idwidth+awidth+8+3+2+1+4+3+4+regionwidth;
  constant wwidth   : integer := dwidth+dwidth/8+1;
  constant bwidth   : integer := idwidth+2;
  constant rwidth   : integer := idwidth+dwidth+2+1;

  signal awsi     : std_logic_vector(axwidth-1 downto 0);
  signal awmo     : std_logic_vector(axwidth-1 downto 0);
  signal awvalid  : std_ulogic;
  signal wsi      : std_logic_vector(wwidth-1 downto 0);
  signal wmo      : std_logic_vector(wwidth-1 downto 0);
  signal wvalid   : std_ulogic;
  signal bso      : std_logic_vector(bwidth-1 downto 0);
  signal bmi      : std_logic_vector(bwidth-1 downto 0);
  signal bvalid   : std_ulogic;
  signal arsi     : std_logic_vector(axwidth-1 downto 0);
  signal armo     : std_logic_vector(axwidth-1 downto 0);
  signal arvalid  : std_ulogic;
  signal rso      : std_logic_vector(rwidth-1 downto 0);
  signal rmi      : std_logic_vector(rwidth-1 downto 0);
  signal rvalid   : std_ulogic;

begin

  -- AW
  awsi <= aw_pack(axisi.aw, axixsi.aw, awidth, idwidth, regionwidth);
  aw_slice : register_slice
  generic map (
    dwidth    => axwidth,
    direction => awdirection,
    bypass    => awbypass
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => awsi,
    s_xvalid  => axisi.aw.valid,
    s_xready  => axiso.aw.ready,

    m_xdata   => awmo,
    m_xvalid  => awvalid,
    m_xready  => aximi.aw.ready
  );
  aw_unpack(idwidth, awidth, regionwidth, awmo, awvalid, aximo.aw, axixmo.aw);

  -- W
  wsi <= w_pack(axisi.w, dwidth);
  w_slice : register_slice
  generic map (
    dwidth    => wwidth,
    direction => wdirection,
    bypass    => wbypass
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => wsi,
    s_xvalid  => axisi.w.valid,
    s_xready  => axiso.w.ready,

    m_xdata   => wmo,
    m_xvalid  => wvalid,
    m_xready  => aximi.w.ready
  );
  w_unpack(dwidth, wmo, wvalid, aximo.w);

  -- B

  bmi <= b_pack(aximi.b, axixmi.b, idwidth);
  b_slice : register_slice
  generic map (
    dwidth    => bwidth,
    direction => bdirection,
    bypass    => bbypass
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => bmi,
    s_xvalid  => aximi.b.valid,
    s_xready  => aximo.b.ready,

    m_xdata   => bso,
    m_xvalid  => bvalid,
    m_xready  => axisi.b.ready
  );
  b_unpack(idwidth, bso, bvalid, axiso.b, axixso.b);

  -- AR


  arsi <= ar_pack(axisi.ar, axixsi.ar, awidth, idwidth, regionwidth);
  ar_slice : register_slice
  generic map (
    dwidth    => axwidth,
    direction => ardirection,
    bypass    => arbypass
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => arsi,
    s_xvalid  => axisi.ar.valid,
    s_xready  => axiso.ar.ready,

    m_xdata   => armo,
    m_xvalid  => arvalid,
    m_xready  => aximi.ar.ready
  );
  ar_unpack(idwidth, awidth, regionwidth, armo, arvalid, aximo.ar, axixmo.ar);

  -- R


  rmi <= r_pack(aximi.r, axixmi.r, idwidth, dwidth);
  r_slice : register_slice
  generic map (
    dwidth    => rwidth,
    direction => rdirection,
    bypass    => rbypass
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => rmi,
    s_xvalid  => aximi.r.valid,
    s_xready  => aximo.r.ready,

    m_xdata   => rso,
    m_xvalid  => rvalid,
    m_xready  => axisi.r.ready
  );
  r_unpack(idwidth, dwidth, rso, rvalid, axiso.r, axixso.r);

end;