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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library gaisler;
use gaisler.l2c_lite.all;

library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.generic_bm_pkg.all;

library techmap;
use techmap.gencomp.all;

entity l2c_lite_ahb is
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
		ahbmi : in ahb_mst_in_type;
		ahbmo : out ahb_mst_out_type

	);

end entity l2c_lite_ahb;

architecture rtl of l2c_lite_ahb is

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

        signal ahbmi_bm : ahb_bmst_in_type;
        signal ahbmo_bm : ahb_bmst_out_type;

        signal endian_out : std_ulogic;
        signal excl_err   : std_logic_vector(1 downto 0);
        signal excl_done  : std_ulogic;

begin

        ahbmi_bm.hgrant <= ahbmi.hgrant(hmindex);
        ahbmi_bm.hready <= ahbmi.hready;
        ahbmi_bm.hresp  <= ahbmi.hresp;
        ahbmi_bm.endian <= ahbmi.endian;

        ahbmo.hbusreq <= ahbmo_bm.hbusreq;
        ahbmo.hlock   <= ahbmo_bm.hlock;
        ahbmo.htrans  <= ahbmo_bm.htrans;
        ahbmo.haddr   <= ahbmo_bm.haddr;
        ahbmo.hwrite  <= ahbmo_bm.hwrite;
        ahbmo.hsize   <= ahbmo_bm.hsize;
        ahbmo.hburst  <= ahbmo_bm.hburst;
        ahbmo.hprot   <= ahbmo_bm.hprot;

        ahbmo.hindex  <= hmindex;
        ahbmo.hirq    <= (others => '0');
        ahbmo.hconfig <= (others => (others => '0'));

        ctrl : l2c_lite_core
        generic map(
                tech     => tech,
                hsindex  => hsindex,
                haddr    => haddr,
                hmask    => hmask,
                ioaddr   => ioaddr,
                waysize  => waysize,
                linesize => linesize,
                cached   => cached,
                repl     => repl,
                ways     => ways,
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
                bmwr_error       => bmwr_error
                );

	generic_bus_master : generic_bm_ahb
	generic map(
		async_reset      => async_reset,
		bm_dw            => bm_dw,
		be_dw            => be_dw,
		be_rd_pipe       => be_rd_pipe,
		unalign_load_opt => unalign_load_opt,
		addr_width       => addr_width,
		max_size         => max_size,
		max_burst_length => 256,
		burst_chop_mask  => 1024,
		excl_enabled     => false,
		bm_info_print    => 0,
		hindex           => hmindex,
		venid            => 0,
		devid            => 0,
		version          => 0)

	port map(
		clk  => clk,
		rstn => rstn,
		-- BACKEND
		ahbmi => ahbmi_bm,
		ahbmo => ahbmo_bm,

		hrdata => ahbmi.hrdata,
		hwdata => ahbmo.hwdata,

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
		endian_out => endian_out,
		--Exclusive access
		excl_en      => '0',
		excl_nowrite => '0',
		excl_done    => excl_done,
		excl_err     => excl_err
	);
	assert not ((ways mod 2 /= 0) and (waysize = 1))
	report "L2 Cache configuration error: pLRU replacement policy requires ways to be power of 2."
		severity failure;

end architecture rtl;
