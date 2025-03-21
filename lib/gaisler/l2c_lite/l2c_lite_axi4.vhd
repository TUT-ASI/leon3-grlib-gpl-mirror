------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library gaisler;
use gaisler.l2c_lite.all;
use gaisler.axi.all;

library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.generic_bm_pkg.all;

library techmap;
use techmap.gencomp.all;

entity l2c_lite_axi4 is
  generic (
    tech     : integer := 0;
    hmindex  : integer := 0;
    hsindex  : integer := 0;
    ways     : integer := 2;
    waysize  : integer := 64;
    linesize : integer := 32;
    repl     : integer := 0;
    haddr    : integer := 16#000#;
    hmask    : integer := 16#000#;
    bioaddr  : integer := 16#000#;
    biomask  : integer := 16#000#;
    ioaddr   : integer := 16#000#;
    cached   : integer := 16#FFFF#;
    be_dw    : integer := 32);
  port (
    rstn : in std_ulogic;
    clk  : in std_ulogic;

    ---- CACHE FRONTEND ----
    ahbsi : in ahb_slv_in_type;
    ahbso : out ahb_slv_out_type;

    ---- CACHE BACKEND ----
    aximi : in axi_somi_type;
    aximo : out axi4_mosi_type

  );

end entity l2c_lite_axi4;

architecture rtl of l2c_lite_axi4 is

  signal bmrd_req_granted : std_logic;
  signal bmrd_data        : std_logic_vector(bm_dw - 1 downto 0);
  signal bmrd_valid       : std_logic;
  signal bmrd_done        : std_logic;
  signal bmrd_error       : std_logic;
  signal bmwr_full        : std_logic;
  signal bmwr_done        : std_logic;
  signal bmwr_error       : std_logic;
  signal bmwr_req_granted : std_logic;
  signal bmrd_addr        : std_logic_vector(addr_width - 1 downto 0);
  signal bmrd_size        : std_logic_vector(log2ext(max_size) - 1 downto 0);
  signal bmrd_req         : std_logic;
  signal bmwr_addr        : std_logic_vector(addr_width - 1 downto 0);
  signal bmwr_size        : std_logic_vector(log2ext(max_size) - 1 downto 0);
  signal bmwr_req         : std_logic;
  signal bmwr_data        : std_logic_vector(bm_dw - 1 downto 0);

  signal endian_out : std_ulogic;
  signal excl_err   : std_logic_vector(1 downto 0);
  signal excl_done  : std_ulogic;

begin

  ctrl : l2c_lite_core
  generic map(
    tech     => tech,
    hsindex  => hsindex,
    haddr    => haddr,
    hmask    => hmask,
    ioaddr   => ioaddr,
    bioaddr  => bioaddr,
    biomask  => biomask,
    waysize  => waysize,
    ways     => ways,
    linesize => linesize,
    repl     => repl,
    cached   => cached,
    bm_dw_l  => bm_dw,
    addr_width  => addr_width)
  port map(
    rstn             => rstn,
    clk              => clk,
    ahbsi            => ahbsi,
    ahbso            => ahbso,
    bmrd_addr        => bmrd_addr,
    bmrd_size        => bmrd_size,
    bmrd_req         => bmrd_req,
    bmrd_req_granted => bmrd_req_granted,
    bmrd_data        => bmrd_data,
    bmrd_valid       => bmrd_valid,
    bmrd_done        => bmrd_done,
    bmrd_error       => bmrd_error,
    bmwr_addr        => bmwr_addr,
    bmwr_size        => bmwr_size,
    bmwr_req         => bmwr_req,
    bmwr_req_granted => bmwr_req_granted,
    bmwr_data        => bmwr_data,
    bmwr_full        => bmwr_full,
    bmwr_done        => bmwr_done,
    bmwr_error       => bmwr_error);

  generic_bus_master : generic_bm_axi
  generic map(
    async_reset      => async_reset,
    bm_dw            => bm_dw,
    be_dw            => be_dw,
    be_rd_pipe       => be_rd_pipe,
    unalign_load_opt => unalign_load_opt,
    addr_width       => addr_width,
    max_size         => max_size,
    max_burst_length => 256,
    burst_chop_mask  => 4096,
    bm_info_print    => 0,
    lendian_en       => 0,
    axi_bm_id_width  => 4)

  port map(
    clk  => clk,
    rstn => rstn,
    -- BACKEND

    --write address channel
    axi_aw_id    => aximo.aw.id,
    axi_aw_addr  => aximo.aw.addr,
    axi_aw_len   => aximo.aw.len,
    axi_aw_size  => aximo.aw.size,
    axi_aw_burst => aximo.aw.burst,
    axi_aw_lock  => aximo.aw.lock,
    axi_aw_cache => aximo.aw.cache,
    axi_aw_prot  => aximo.aw.prot,
    axi_aw_valid => aximo.aw.valid,
    axi_aw_qos   => aximo.aw.qos,
    axi_aw_ready => aximi.aw.ready,
    --write data channel
    axi_w_data  => aximo.w.data,
    axi_w_strb  => aximo.w.strb,
    axi_w_last  => aximo.w.last,
    axi_w_valid => aximo.w.valid,
    axi_w_ready => aximi.w.ready,
    --write response channel
    axi_b_ready => aximo.b.ready,
    axi_b_id    => aximi.b.id,
    axi_b_resp  => aximi.b.resp,
    axi_b_valid => aximi.b.valid,
    --read address channel
    axi_ar_id    => aximo.ar.id,
    axi_ar_addr  => aximo.ar.addr,
    axi_ar_len   => aximo.ar.len,
    axi_ar_size  => aximo.ar.size,
    axi_ar_burst => aximo.ar.burst,
    axi_ar_lock  => aximo.ar.lock,
    axi_ar_cache => aximo.ar.cache,
    axi_ar_prot  => aximo.ar.prot,
    axi_ar_valid => aximo.ar.valid,
    axi_ar_qos   => aximo.ar.qos,
    axi_ar_ready => aximi.ar.ready,
    --read data channel
    axi_r_ready => aximo.r.ready,
    axi_r_id    => aximi.r.id,
    axi_r_data  => aximi.r.data,
    axi_r_resp  => aximi.r.resp,
    axi_r_last  => aximi.r.last,
    axi_r_valid => aximi.r.valid,
    --FRONTEND
    bmrd_addr        => bmrd_addr,
    bmrd_size        => bmrd_size,
    bmrd_req         => bmrd_req,
    bmrd_req_granted => bmrd_req_granted,
    bmrd_data        => bmrd_data,
    bmrd_valid       => bmrd_valid,
    bmrd_done        => bmrd_done,
    bmrd_error       => bmrd_error,

    bmwr_addr        => bmwr_addr,
    bmwr_size        => bmwr_size,
    bmwr_req         => bmwr_req,
    bmwr_req_granted => bmwr_req_granted,
    bmwr_data        => bmwr_data,
    bmwr_full        => bmwr_full,
    bmwr_done        => bmwr_done,
    bmwr_error       => bmwr_error,

    --Endianess Output
    endian_out => endian_out

  );

  assert not ((ways mod 2 /= 0) and (repl = 1))
  report "L2 Cache configuration error: pLRU replacement policy requires ways to be power of 2."
    severity failure;

end architecture rtl;
