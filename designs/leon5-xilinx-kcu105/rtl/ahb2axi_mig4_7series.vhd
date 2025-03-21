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
-------------------------------------------------------------------------------
-- Entity:      ahb2axi_mig4_7series
-- File:        ahb2axi_mig4_7series.vhd
-- Author:      Johan Klockars - Cobham Gaisler AB
--
--  Interface to convert AHB-2.0 to AXI4 interface of Xilinx Virtex-7 MIG
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.misc.all;
use gaisler.axi.all;


entity ahb2axi_mig4_7series is
  generic (
    pipelined               : boolean := false;   -- Pipeline stage before AXI CDC?
    hindex                  : integer := 0;
    haddr                   : integer := 0;
    hmask                   : integer := 16#f00#;
    pindex                  : integer := 0;
    paddr                   : integer := 0;
    pmask                   : integer := 16#fff#
  );
  port (
    calib_done          : out   std_logic;
    sys_clk_p           : in    std_logic;
    sys_clk_n           : in    std_logic;
    ddr4_addr           : out   std_logic_vector(13 downto 0);
    ddr4_we_n           : out   std_logic;
    ddr4_cas_n          : out   std_logic;
    ddr4_ras_n          : out   std_logic;
    ddr4_ba             : out   std_logic_vector(1 downto 0);
    ddr4_cke            : out   std_logic_vector(0 downto 0);
    ddr4_cs_n           : out   std_logic_vector(0 downto 0);
    ddr4_dm_n           : inout std_logic_vector(7 downto 0);
    ddr4_dq             : inout std_logic_vector(63 downto 0);
    ddr4_dqs_c          : inout std_logic_vector(7 downto 0);
    ddr4_dqs_t          : inout std_logic_vector(7 downto 0);
    ddr4_odt            : out   std_logic_vector(0 downto 0);
    ddr4_bg             : out   std_logic_vector(0 downto 0);
    ddr4_reset_n        : out   std_logic;
    ddr4_act_n          : out   std_logic;
    ddr4_ck_c           : out   std_logic_vector(0 downto 0);
    ddr4_ck_t           : out   std_logic_vector(0 downto 0);
    ddr4_ui_clk         : out   std_logic;
    ddr4_ui_clk_sync_rst: out   std_logic;
    rst_n_syn           : in    std_logic;
    rst_n_async         : in    std_logic;

    ahbso               : out   ahb_slv_out_type;
    ahbsi               : in    ahb_slv_in_type;
    apbi                : in    apb_slv_in_type;
    apbo                : out   apb_slv_out_type;
    clk_amba            : in    std_logic;

    -- Misc
    ddr4_ui_clkout1     : out   std_logic;
    clk_ref_i           : in    std_logic
  );
end ;


architecture rtl of ahb2axi_mig4_7series is

  constant zero : std_logic_vector(31 downto 0) := (others => '0');

  constant pconfig : apb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
    1 => apb_iobar(paddr, pmask));

  signal aximi        : axi_somi_type;
  signal aximo        : axi4_mosi_type;
  signal axi_cdc_so   : axi_somi_type;
  signal axi_cdc_si   : axi4_mosi_type;

  signal ahbsi_bridge : ahb_slv_in_type;
  signal ahbso_bridge : ahb_slv_out_type;

  --temporary signals to convert AXI3 to AXI4
  signal s_axi_rdata_buffer : std_logic_vector(AHBDW - 1 downto 0);
  signal s_axi_wdata_buffer : std_logic_vector(AHBDW - 1 downto 0);
  signal s_axi_awlen : std_logic_vector(7 downto 0);
  signal s_axi_arlen : std_logic_vector(7 downto 0);
  signal s_axi_awqos : std_logic_vector(3 downto 0);
  signal s_axi_arqos : std_logic_vector(3 downto 0);


  signal mmcm_locked : std_logic;

  
  signal mig_addr       : std_logic_vector(16 downto 0);

  signal aximo_aw_lock  : std_logic_vector(0 downto 0);
  signal aximo_ar_lock  : std_logic_vector(0 downto 0);

  -- Clock and Reset
  signal rst_async      : std_ulogic;
  signal fpga_clk       : std_ulogic;
  signal ddr4_clk       : std_ulogic;
  signal ddr4_rstn      : std_ulogic;
  signal ddr4_rst       : std_ulogic;

  -- DDR4 Signals
  signal ddr4_aclk      : std_logic;
  signal ddr4_aresetn   : std_logic;
  signal ddr4_awid      : std_logic_vector(3 downto 0);
  signal ddr4_awaddr    : std_logic_vector(31 downto 0);
  signal ddr4_awlen     : std_logic_vector(7 downto 0);
  signal ddr4_awsize    : std_logic_vector(2 downto 0);
  signal ddr4_awburst   : std_logic_vector(1 downto 0);
  signal ddr4_awlock    : std_logic_vector(0 downto 0);
  signal ddr4_awcache   : std_logic_vector(3 downto 0);
  signal ddr4_awprot    : std_logic_vector(2 downto 0);
  signal ddr4_awqos     : std_logic_vector(3 downto 0);
  signal ddr4_awvalid   : std_logic;
  signal ddr4_awready   : std_logic;
  signal ddr4_wdata     : std_logic_vector(AHBDW-1 downto 0);
  signal ddr4_wstrb     : std_logic_vector(AHBDW/8-1 downto 0);
  signal ddr4_wlast     : std_logic;
  signal ddr4_wvalid    : std_logic;
  signal ddr4_wready    : std_logic;
  signal ddr4_bid       : std_logic_vector(3 downto 0);
  signal ddr4_bresp     : std_logic_vector(1 downto 0);
  signal ddr4_bvalid    : std_logic;
  signal ddr4_bready    : std_logic;
  signal ddr4_arid      : std_logic_vector(3 downto 0);
  signal ddr4_araddr    : std_logic_vector(31 downto 0);
  signal ddr4_arlen     : std_logic_vector(7 downto 0);
  signal ddr4_arsize    : std_logic_vector(2 downto 0);
  signal ddr4_arburst   : std_logic_vector(1 downto 0);
  signal ddr4_arlock    : std_logic_vector(0 downto 0);
  signal ddr4_arcache   : std_logic_vector(3 downto 0);
  signal ddr4_arprot    : std_logic_vector(2 downto 0);
  signal ddr4_arqos     : std_logic_vector(3 downto 0);
  signal ddr4_arvalid   : std_logic;
  signal ddr4_arready   : std_logic;
  signal ddr4_rid       : std_logic_vector(3 downto 0);
  signal ddr4_rdata     : std_logic_vector(AHBDW-1 downto 0);
  signal ddr4_rresp     : std_logic_vector(1 downto 0);
  signal ddr4_rlast     : std_logic;
  signal ddr4_rvalid    : std_logic;
  signal ddr4_rready    : std_logic;

  COMPONENT mig
    PORT (
      c0_init_calib_complete : OUT STD_LOGIC;
      dbg_clk : OUT STD_LOGIC;
      c0_sys_clk_p : IN STD_LOGIC;
      c0_sys_clk_n : IN STD_LOGIC;
      dbg_rd_data_cmp : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      dbg_expected_data : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      dbg_cal_seq : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      dbg_cal_seq_cnt : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      dbg_cal_seq_rd_cnt : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      dbg_rd_valid : OUT STD_LOGIC;
      dbg_cmp_byte : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      dbg_rd_data : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      dbg_cplx_config : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      dbg_cplx_status : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      dbg_io_address : OUT STD_LOGIC_VECTOR(27 DOWNTO 0);
      dbg_pllGate : OUT STD_LOGIC;
      dbg_phy2clb_fixdly_rdy_low : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      dbg_phy2clb_fixdly_rdy_upp : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      dbg_phy2clb_phy_rdy_low : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      dbg_phy2clb_phy_rdy_upp : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      cal_r0_status : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      cal_post_status : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
      dbg_bus : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
      c0_ddr4_adr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      c0_ddr4_ba : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      c0_ddr4_cke : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_cs_n : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_dm_dbi_n : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      c0_ddr4_dq : INOUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      c0_ddr4_dqs_c : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      c0_ddr4_dqs_t : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      c0_ddr4_odt : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_bg : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_reset_n : OUT STD_LOGIC;
      c0_ddr4_act_n : OUT STD_LOGIC;
      c0_ddr4_ck_c : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_ck_t : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_ui_clk : OUT STD_LOGIC;
      c0_ddr4_ui_clk_sync_rst : OUT STD_LOGIC;
      c0_ddr4_aresetn : IN STD_LOGIC;
      c0_ddr4_s_axi_awid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_awaddr : IN STD_LOGIC_VECTOR(30 DOWNTO 0);
      c0_ddr4_s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      c0_ddr4_s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      c0_ddr4_s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      c0_ddr4_s_axi_awlock : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      c0_ddr4_s_axi_awqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_awvalid : IN STD_LOGIC;
      c0_ddr4_s_axi_awready : OUT STD_LOGIC;
      c0_ddr4_s_axi_wdata : IN STD_LOGIC_VECTOR(AHBDW-1 DOWNTO 0);
      c0_ddr4_s_axi_wstrb : IN STD_LOGIC_VECTOR(AHBDW/8-1 DOWNTO 0);
      c0_ddr4_s_axi_wlast : IN STD_LOGIC;
      c0_ddr4_s_axi_wvalid : IN STD_LOGIC;
      c0_ddr4_s_axi_wready : OUT STD_LOGIC;
      c0_ddr4_s_axi_bready : IN STD_LOGIC;
      c0_ddr4_s_axi_bid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      c0_ddr4_s_axi_bvalid : OUT STD_LOGIC;
      c0_ddr4_s_axi_arid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_araddr : IN STD_LOGIC_VECTOR(30 DOWNTO 0);
      c0_ddr4_s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      c0_ddr4_s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      c0_ddr4_s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      c0_ddr4_s_axi_arlock : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      c0_ddr4_s_axi_arqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_arvalid : IN STD_LOGIC;
      c0_ddr4_s_axi_arready : OUT STD_LOGIC;
      c0_ddr4_s_axi_rready : IN STD_LOGIC;
      c0_ddr4_s_axi_rlast : OUT STD_LOGIC;
      c0_ddr4_s_axi_rvalid : OUT STD_LOGIC;
      c0_ddr4_s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      c0_ddr4_s_axi_rid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_rdata : OUT STD_LOGIC_VECTOR(AHBDW-1 DOWNTO 0);
      addn_ui_clkout1 : OUT STD_LOGIC;
      sys_rst : IN STD_LOGIC
      );
  END COMPONENT;
  
  COMPONENT mig_cdc
    PORT (
      s_axi_aclk : IN STD_LOGIC;
      s_axi_aresetn : IN STD_LOGIC;
      s_axi_awid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_awaddr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      s_axi_awlock : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      s_axi_awregion : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_awqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_awvalid : IN STD_LOGIC;
      s_axi_awready : OUT STD_LOGIC;
      s_axi_wdata : IN STD_LOGIC_VECTOR(AHBDW-1 DOWNTO 0);
      s_axi_wstrb : IN STD_LOGIC_VECTOR(AHBDW/8-1 DOWNTO 0);
      s_axi_wlast : IN STD_LOGIC;
      s_axi_wvalid : IN STD_LOGIC;
      s_axi_wready : OUT STD_LOGIC;
      s_axi_bid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      s_axi_bvalid : OUT STD_LOGIC;
      s_axi_bready : IN STD_LOGIC;
      s_axi_arid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_araddr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      s_axi_arlock : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      s_axi_arregion : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_arqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_arvalid : IN STD_LOGIC;
      s_axi_arready : OUT STD_LOGIC;
      s_axi_rid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_rdata : OUT STD_LOGIC_VECTOR(AHBDW-1 DOWNTO 0);
      s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      s_axi_rlast : OUT STD_LOGIC;
      s_axi_rvalid : OUT STD_LOGIC;
      s_axi_rready : IN STD_LOGIC;
      m_axi_aclk : IN STD_LOGIC;
      m_axi_aresetn : IN STD_LOGIC;
      m_axi_awid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_awaddr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      m_axi_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axi_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_awlock : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      m_axi_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_awregion : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_awvalid : OUT STD_LOGIC;
      m_axi_awready : IN STD_LOGIC;
      m_axi_wdata : OUT STD_LOGIC_VECTOR(AHBDW-1 DOWNTO 0);
      m_axi_wstrb : OUT STD_LOGIC_VECTOR(AHBDW/8-1 DOWNTO 0);
      m_axi_wlast : OUT STD_LOGIC;
      m_axi_wvalid : OUT STD_LOGIC;
      m_axi_wready : IN STD_LOGIC;
      m_axi_bid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_bvalid : IN STD_LOGIC;
      m_axi_bready : OUT STD_LOGIC;
      m_axi_arid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_araddr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      m_axi_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axi_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_arlock : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      m_axi_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_arregion : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_arvalid : OUT STD_LOGIC;
      m_axi_arready : IN STD_LOGIC;
      m_axi_rid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_rdata : IN STD_LOGIC_VECTOR(AHBDW-1 DOWNTO 0);
      m_axi_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_rlast : IN STD_LOGIC;
      m_axi_rvalid : IN STD_LOGIC;
      m_axi_rready : OUT STD_LOGIC
      );
  END COMPONENT;

 component axi_pipe
    port (
      --**********************************************
      -- SLAVE INTERFACE
      --**********************************************
      --**************** Write Address Channel Signals ****************
      s_axi_awid       : in  std_logic_vector(3 downto 0);
      s_axi_awaddr     : in  std_logic_vector(31 downto 0);
      s_axi_awlen      : in  std_logic_vector(7 downto 0);
      s_axi_awsize     : in  std_logic_vector(2 downto 0);
      s_axi_awburst    : in  std_logic_vector(1 downto 0);
      s_axi_awlock     : in  std_logic_vector(0 downto 0);
      s_axi_awcache    : in  std_logic_vector(3 downto 0);
      s_axi_awprot     : in  std_logic_vector(2 downto 0);
      s_axi_awregion   : in  std_logic_vector(3 downto 0);
      s_axi_awqos      : in  std_logic_vector(3 downto 0);
      s_axi_awvalid    : in  std_logic;
      s_axi_awready    : out std_logic;
      --**************** Write Data Channel Signals ****************
      s_axi_wdata      : in  std_logic_vector(AHBDW-1 downto 0);
      s_axi_wstrb      : in  std_logic_vector(AHBDW/8-1 DOWNTO 0);
      s_axi_wlast      : in  std_logic;
      s_axi_wvalid     : in  std_logic;
      s_axi_wready     : out std_logic;
      --**************** Write Response Channel Signals ****************
      s_axi_bid        : out std_logic_vector(3 downto 0);
      s_axi_bresp      : out std_logic_vector(1 downto 0);
      s_axi_bvalid     : out std_logic;
      s_axi_bready     : in  std_logic;
      --**************** Read Address Channel Signals ****************
      s_axi_arid       : in  std_logic_vector(3 downto 0);
      s_axi_araddr     : in  std_logic_vector(31 downto 0);
      s_axi_arlen      : in  std_logic_vector(7 downto 0);
      s_axi_arsize     : in  std_logic_vector(2 downto 0);
      s_axi_arburst    : in  std_logic_vector(1 downto 0);
      s_axi_arlock     : in  std_logic_vector(0 downto 0);
      s_axi_arcache    : in  std_logic_vector(3 downto 0);
      s_axi_arprot     : in  std_logic_vector(2 downto 0);
      s_axi_arregion   : in  std_logic_vector(3 downto 0);
      s_axi_arqos      : in  std_logic_vector(3 downto 0);
      s_axi_arvalid    : in  std_logic;
      s_axi_arready    : out std_logic;
      --**************** Read Data Channel Signals ****************
      s_axi_rid        : out std_logic_vector(3 downto 0);
      s_axi_rdata      : out std_logic_vector(AHBDW-1 downto 0);
      s_axi_rresp      : out std_logic_vector(1 downto 0);
      s_axi_rlast      : out std_logic;
      s_axi_rvalid     : out std_logic;
      s_axi_rready     : in  std_logic;

      --**********************************************
      -- MASTER INTERFACE
      --**********************************************
      --**************** Write Address Channel Signals ****************
      m_axi_awid       : out std_logic_vector(3 downto 0);
      m_axi_awaddr     : out std_logic_vector(31 downto 0);
      m_axi_awlen      : out std_logic_vector(7 downto 0);
      m_axi_awsize     : out std_logic_vector(2 downto 0);
      m_axi_awburst    : out std_logic_vector(1 downto 0);
      m_axi_awlock     : out std_logic_vector(0 downto 0);
      m_axi_awcache    : out std_logic_vector(3 downto 0);
      m_axi_awprot     : out std_logic_vector(2 downto 0);
      m_axi_awregion   : out std_logic_vector(3 downto 0);
      m_axi_awqos      : out std_logic_vector(3 downto 0);
      m_axi_awvalid    : out std_logic;
      m_axi_awready    : in  std_logic;
      --**************** Write Data Channel Signals ****************
      m_axi_wdata      : out std_logic_vector(AHBDW-1 downto 0);
      m_axi_wstrb      : out std_logic_vector(AHBDW/8-1  downto 0);
      m_axi_wlast      : out std_logic;
      m_axi_wvalid     : out std_logic;
      m_axi_wready     : in  std_logic;
      --**************** Write Response Channel Signals ****************
      m_axi_bid        : in  std_logic_vector(3 downto 0);
      m_axi_bresp      : in  std_logic_vector(1 downto 0);
      m_axi_bvalid     : in  std_logic;
      m_axi_bready     : out std_logic;
      --**************** Read Address Channel Signals ****************
      m_axi_arid       : out std_logic_vector(3 downto 0);
      m_axi_araddr     : out std_logic_vector(31 downto 0);
      m_axi_arlen      : out std_logic_vector(7 downto 0);
      m_axi_arsize     : out std_logic_vector(2 downto 0);
      m_axi_arburst    : out std_logic_vector(1 downto 0);
      m_axi_arlock     : out std_logic_vector(0 downto 0);
      m_axi_arcache    : out std_logic_vector(3 downto 0);
      m_axi_arprot     : out std_logic_vector(2 downto 0);
      m_axi_arregion   : out std_logic_vector(3 downto 0);
      m_axi_arqos      : out std_logic_vector(3 downto 0);
      m_axi_arvalid    : out std_logic;
      m_axi_arready    : in  std_logic;
      --**************** Read Data Channel Signals ****************
      m_axi_rid        : in  std_logic_vector(3 downto 0);
      m_axi_rdata      : in  std_logic_vector(AHBDW-1 downto 0);
      m_axi_rresp      : in  std_logic_vector(1 downto 0);
      m_axi_rlast      : in  std_logic;
      m_axi_rvalid     : in  std_logic;
      m_axi_rready     : out std_logic;

      --**************** System Signals ****************
      aclk             : in  std_logic;
      aresetn          : in  std_logic
    );
  end component;

begin

  apbo.pindex  <= pindex;
  apbo.pconfig <= pconfig;
  apbo.pirq    <= (others => '0');
  apbo.prdata  <= (others => '0');

  ahbsi_bridge.hsel   <= ahbsi.hsel;
  ahbsi_bridge.haddr  <= ahbsi.haddr;
  ahbsi_bridge.hwrite <= ahbsi.hwrite;
  ahbsi_bridge.htrans <= ahbsi.htrans;
  ahbsi_bridge.hsize  <= ahbsi.hsize;
  ahbsi_bridge.hburst <= ahbsi.hburst;
  ahbsi_bridge.hprot  <= ahbsi.hprot;
  ahbsi_bridge.hready <= ahbsi.hready;
  ahbsi_bridge.hwdata <= ahbsi.hwdata;
  

  ahbso.hconfig <= ahbso_bridge.hconfig;
  ahbso.hirq    <= (others => '0');
  ahbso.hindex  <= hindex;
  ahbso.hsplit  <= (others => '0');
  ahbso.hready  <= ahbso_bridge.hready;
  ahbso.hresp   <= ahbso_bridge.hresp;
  ahbso.hrdata  <= ahbso_bridge.hrdata;
  
  bridge: ahb2axi4b
    generic map (
      hindex => hindex,
      aximid => 0,
      wbuffer_num => 8,
      rprefetch_num => 8,
      endianness_mode => 0,
      narrow_acc_mode => 0,
      vendor  => VENDOR_GAISLER,
      device  => GAISLER_MIG_7SERIES,
      bar0    => ahb2ahb_membar(haddr, '1', '1', hmask)
    )
    port map (
      rstn  => rst_n_syn,
      clk   => clk_amba,
      ahbsi => ahbsi_bridge,
      ahbso => ahbso_bridge,
      aximi => aximi,
      aximo => aximo
    );

  ddr4_addr     <= mig_addr(13 downto 0);
  ddr4_we_n     <= mig_addr(14);
  ddr4_cas_n    <= mig_addr(15);
  ddr4_ras_n    <= mig_addr(16);

  aximo_aw_lock(0)      <= axi_cdc_si.aw.lock;
  aximo_ar_lock(0)      <= axi_cdc_si.ar.lock;

  rst_async     <= not(rst_n_async);


  -- No AXI4 register slice (not pipelined).
  without_pipe : if not pipelined generate
    axi_cdc_si <= aximo;
    aximi      <= axi_cdc_so;
  end generate;

  -- AXI4 register slice (1 cycle pipeline).
  with_pipe : if pipelined generate
    MCB_REG : axi_pipe
      port map (
        --**********************************************
        -- SLAVE INTERFACE
        --**********************************************
        --**************** Write Address Channel Signals ****************
        s_axi_awid       => aximo.aw.id,   
        s_axi_awaddr     => aximo.aw.addr, 
        s_axi_awlen      => aximo.aw.len,  
        s_axi_awsize     => aximo.aw.size, 
        s_axi_awburst    => aximo.aw.burst,
        s_axi_awlock     => zero(0 downto 0),           
        s_axi_awcache    => aximo.aw.cache,
        s_axi_awprot     => zero(2 downto 0),         
        s_axi_awregion   => zero(3 downto 0),        
        s_axi_awqos      => zero(3 downto 0),        
        s_axi_awvalid    => aximo.aw.valid,
        s_axi_awready    => aximi.aw.ready,
        --**************** Write Data Channel Signals ****************
        s_axi_wdata      => aximo.w.data, 
        s_axi_wstrb      => aximo.w.strb, 
        s_axi_wlast      => aximo.w.last, 
        s_axi_wvalid     => aximo.w.valid,
        s_axi_wready     => aximi.w.ready,
        --**************** Write Response Channel Signals ****************
        s_axi_bid        => aximi.b.id,   
        s_axi_bresp      => aximi.b.resp, 
        s_axi_bvalid     => aximi.b.valid,
        s_axi_bready     => aximo.b.ready,
        --**************** Read Address Channel Signals ****************
        s_axi_arid       => aximo.ar.id,   
        s_axi_araddr     => aximo.ar.addr, 
        s_axi_arlen      => aximo.ar.len,  
        s_axi_arsize     => aximo.ar.size, 
        s_axi_arburst    => aximo.ar.burst,
        s_axi_arlock     => zero(0 downto 0),          
        s_axi_arcache    => aximo.ar.cache,
        s_axi_arprot     => zero(2 downto 0),
        s_axi_arregion   => zero(3 downto 0),
        s_axi_arqos      => zero(3 downto 0),
        s_axi_arvalid    => aximo.ar.valid,
        s_axi_arready    => aximi.ar.ready,
        --**************** Read Data Channel Signals ****************
        s_axi_rid        => aximi.r.id,   
        s_axi_rdata      => aximi.r.data, 
        s_axi_rresp      => aximi.r.resp, 
        s_axi_rlast      => aximi.r.last, 
        s_axi_rvalid     => aximi.r.valid,
        s_axi_rready     => aximo.r.ready,
  
        --**********************************************
        -- DUT MASTER INTERFACE
        --**********************************************
        --**************** Write Address Channel Signals ****************
        m_axi_awid       => axi_cdc_si.aw.id,   
        m_axi_awaddr     => axi_cdc_si.aw.addr, 
        m_axi_awlen      => axi_cdc_si.aw.len,  
        m_axi_awsize     => axi_cdc_si.aw.size, 
        m_axi_awburst    => axi_cdc_si.aw.burst,
        m_axi_awlock     => open,           
        m_axi_awcache    => axi_cdc_si.aw.cache,
        m_axi_awprot     => open,         
        m_axi_awregion   => open,        
        m_axi_awqos      => open,        
        m_axi_awvalid    => axi_cdc_si.aw.valid,
        m_axi_awready    => axi_cdc_so.aw.ready,
        --**************** Write Data Channel Signals ****************
        m_axi_wdata      => axi_cdc_si.w.data, 
        m_axi_wstrb      => axi_cdc_si.w.strb, 
        m_axi_wlast      => axi_cdc_si.w.last, 
        m_axi_wvalid     => axi_cdc_si.w.valid,
        m_axi_wready     => axi_cdc_so.w.ready,
        --**************** Write Response Channel Signals ****************
        m_axi_bid        => axi_cdc_so.b.id,   
        m_axi_bresp      => axi_cdc_so.b.resp, 
        m_axi_bvalid     => axi_cdc_so.b.valid,
        m_axi_bready     => axi_cdc_si.b.ready,
        --**************** Read Address Channel Signals ****************
        m_axi_arid       => axi_cdc_si.ar.id,   
        m_axi_araddr     => axi_cdc_si.ar.addr, 
        m_axi_arlen      => axi_cdc_si.ar.len,  
        m_axi_arsize     => axi_cdc_si.ar.size, 
        m_axi_arburst    => axi_cdc_si.ar.burst,
        m_axi_arlock     => open,           
        m_axi_arcache    => axi_cdc_si.ar.cache,
        m_axi_arprot     => open,         
        m_axi_arregion   => open,        
        m_axi_arqos      => open,        
        m_axi_arvalid    => axi_cdc_si.ar.valid,
        m_axi_arready    => axi_cdc_so.ar.ready,
        --**************** Read Data Channel Signals ****************
        m_axi_rid        => axi_cdc_so.r.id,   
        m_axi_rdata      => axi_cdc_so.r.data, 
        m_axi_rresp      => axi_cdc_so.r.resp, 
        m_axi_rlast      => axi_cdc_so.r.last, 
        m_axi_rvalid     => axi_cdc_so.r.valid,
        m_axi_rready     => axi_cdc_si.r.ready,
  
        --**************** System Signals ****************
        aclk             => fpga_clk,
        aresetn          => rst_n_syn
      );
  end generate;


  -- MIG Clock Domain Crossing
  -- awlock, awprot, awregion and awqos have been tied to
  -- gnd as provided in the MIG example design

  -- MIG CDC has been clocked by the fpga logic clock on
  -- slave side (100 MHz), and by the DDR4 controller clock on
  -- the master side (300 MHz)
  
  MCB_CDC : mig_cdc
    PORT MAP (
      s_axi_aclk        => fpga_clk,
      s_axi_aresetn     => rst_n_syn,
      s_axi_awid        => axi_cdc_si.aw.id,
      s_axi_awaddr      => axi_cdc_si.aw.addr,
      s_axi_awlen       => axi_cdc_si.aw.len,
      s_axi_awsize      => axi_cdc_si.aw.size,
      s_axi_awburst     => axi_cdc_si.aw.burst,
      s_axi_awlock      => "0",
      s_axi_awcache     => axi_cdc_si.aw.cache,
      s_axi_awprot      => "000",
      s_axi_awregion    => "0000",
      s_axi_awqos       => "0000",
      s_axi_awvalid     => axi_cdc_si.aw.valid,
      s_axi_awready     => axi_cdc_so.aw.ready,
      s_axi_wdata       => axi_cdc_si.w.data,
      s_axi_wstrb       => axi_cdc_si.w.strb,
      s_axi_wlast       => axi_cdc_si.w.last,
      s_axi_wvalid      => axi_cdc_si.w.valid,
      s_axi_wready      => axi_cdc_so.w.ready,
      s_axi_bid         => axi_cdc_so.b.id,
      s_axi_bresp       => axi_cdc_so.b.resp,
      s_axi_bvalid      => axi_cdc_so.b.valid,
      s_axi_bready      => axi_cdc_si.b.ready,
      s_axi_arid        => axi_cdc_si.ar.id,
      s_axi_araddr      => axi_cdc_si.ar.addr,
      s_axi_arlen       => axi_cdc_si.ar.len,
      s_axi_arsize      => axi_cdc_si.ar.size,
      s_axi_arburst     => axi_cdc_si.ar.burst,
      s_axi_arlock      => "0",
      s_axi_arcache     => axi_cdc_si.ar.cache,
      s_axi_arprot      => "000",
      s_axi_arregion    => "0000",
      s_axi_arqos       => "0000",
      s_axi_arvalid     => axi_cdc_si.ar.valid,
      s_axi_arready     => axi_cdc_so.ar.ready,
      s_axi_rid         => axi_cdc_so.r.id,
      s_axi_rdata       => axi_cdc_so.r.data,
      s_axi_rresp       => axi_cdc_so.r.resp,
      s_axi_rlast       => axi_cdc_so.r.last,
      s_axi_rvalid      => axi_cdc_so.r.valid,
      s_axi_rready      => axi_cdc_si.r.ready,
      m_axi_aclk        => ddr4_clk,
      m_axi_aresetn     => ddr4_rstn,
      m_axi_awid        => ddr4_awid,
      m_axi_awaddr      => ddr4_awaddr,
      m_axi_awlen       => ddr4_awlen,
      m_axi_awsize      => ddr4_awsize,
      m_axi_awburst     => ddr4_awburst,
      m_axi_awlock      => ddr4_awlock,
      m_axi_awcache     => ddr4_awcache,
      m_axi_awprot      => ddr4_awprot,
      m_axi_awregion    => open,
      m_axi_awqos       => ddr4_awqos,
      m_axi_awvalid     => ddr4_awvalid,
      m_axi_awready     => ddr4_awready,
      m_axi_wdata       => ddr4_wdata,
      m_axi_wstrb       => ddr4_wstrb,
      m_axi_wlast       => ddr4_wlast,
      m_axi_wvalid      => ddr4_wvalid,
      m_axi_wready      => ddr4_wready,
      m_axi_bid         => ddr4_bid,
      m_axi_bresp       => ddr4_bresp,
      m_axi_bvalid      => ddr4_bvalid,
      m_axi_bready      => ddr4_bready,
      m_axi_arid        => ddr4_arid,
      m_axi_araddr      => ddr4_araddr,
      m_axi_arlen       => ddr4_arlen,
      m_axi_arsize      => ddr4_arsize,
      m_axi_arburst     => ddr4_arburst,
      m_axi_arlock      => ddr4_arlock,
      m_axi_arcache     => ddr4_arcache,
      m_axi_arprot      => ddr4_arprot,
      m_axi_arregion    => open,
      m_axi_arqos       => ddr4_arqos,
      m_axi_arvalid     => ddr4_arvalid,
      m_axi_arready     => ddr4_arready,
      m_axi_rid         => ddr4_rid,
      m_axi_rdata       => ddr4_rdata,
      m_axi_rresp       => ddr4_rresp,
      m_axi_rlast       => ddr4_rlast,
      m_axi_rvalid      => ddr4_rvalid,
      m_axi_rready      => ddr4_rready
    );  
  
  MCB_inst : mig
    PORT MAP (
      c0_init_calib_complete    => calib_done,
      dbg_clk                   => open, 
      c0_sys_clk_p              => sys_clk_p,
      c0_sys_clk_n              => sys_clk_n,
      dbg_rd_data_cmp           => open,
      dbg_expected_data         => open,
      dbg_cal_seq               => open,
      dbg_cal_seq_cnt           => open,
      dbg_cal_seq_rd_cnt        => open,
      dbg_rd_valid              => open,
      dbg_cmp_byte              => open,
      dbg_rd_data               => open,
      dbg_cplx_config           => open,
      dbg_cplx_status           => open,
      dbg_io_address            => open,
      dbg_pllGate               => open,
      dbg_phy2clb_fixdly_rdy_low => open,
      dbg_phy2clb_fixdly_rdy_upp => open,
      dbg_phy2clb_phy_rdy_low   => open,
      dbg_phy2clb_phy_rdy_upp   => open,
      cal_r0_status             => open,
      cal_post_status           => open,
      dbg_bus                   => open, 
      c0_ddr4_adr               => mig_addr,
      c0_ddr4_ba                => ddr4_ba,
      c0_ddr4_cke               => ddr4_cke,
      c0_ddr4_cs_n              => ddr4_cs_n,
      c0_ddr4_dm_dbi_n          => ddr4_dm_n,
      c0_ddr4_dq                => ddr4_dq,
      c0_ddr4_dqs_c             => ddr4_dqs_c,
      c0_ddr4_dqs_t             => ddr4_dqs_t,
      c0_ddr4_odt               => ddr4_odt,
      c0_ddr4_bg                => ddr4_bg,
      c0_ddr4_reset_n           => ddr4_reset_n,
      c0_ddr4_act_n             => ddr4_act_n,
      c0_ddr4_ck_c              => ddr4_ck_c,
      c0_ddr4_ck_t              => ddr4_ck_t,
      c0_ddr4_ui_clk            => ddr4_clk,
      c0_ddr4_ui_clk_sync_rst   => ddr4_rst,
      c0_ddr4_aresetn           => ddr4_rstn,
      c0_ddr4_s_axi_awid        => ddr4_awid,
      c0_ddr4_s_axi_awaddr      => ddr4_awaddr(30 downto 0),
      c0_ddr4_s_axi_awlen       => ddr4_awlen,
      c0_ddr4_s_axi_awsize      => ddr4_awsize,
      c0_ddr4_s_axi_awburst     => ddr4_awburst,
      c0_ddr4_s_axi_awlock      => ddr4_awlock,
      c0_ddr4_s_axi_awcache     => ddr4_awcache,
      c0_ddr4_s_axi_awprot      => ddr4_awprot,
      c0_ddr4_s_axi_awqos       => ddr4_awqos,
      c0_ddr4_s_axi_awvalid     => ddr4_awvalid,
      c0_ddr4_s_axi_awready     => ddr4_awready,
      c0_ddr4_s_axi_wdata       => ddr4_wdata,
      c0_ddr4_s_axi_wstrb       => ddr4_wstrb,
      c0_ddr4_s_axi_wlast       => ddr4_wlast,
      c0_ddr4_s_axi_wvalid      => ddr4_wvalid,
      c0_ddr4_s_axi_wready      => ddr4_wready,
      c0_ddr4_s_axi_bready      => ddr4_bready,
      c0_ddr4_s_axi_bid         => ddr4_bid,
      c0_ddr4_s_axi_bresp       => ddr4_bresp,
      c0_ddr4_s_axi_bvalid      => ddr4_bvalid,
      c0_ddr4_s_axi_arid        => ddr4_arid,
      c0_ddr4_s_axi_araddr      => ddr4_araddr(30 downto 0),
      c0_ddr4_s_axi_arlen       => ddr4_arlen,
      c0_ddr4_s_axi_arsize      => ddr4_arsize,
      c0_ddr4_s_axi_arburst     => ddr4_arburst,
      c0_ddr4_s_axi_arlock      => ddr4_arlock,
      c0_ddr4_s_axi_arcache     => ddr4_arcache,
      c0_ddr4_s_axi_arprot      => ddr4_arprot,
      c0_ddr4_s_axi_arqos       => ddr4_arqos,
      c0_ddr4_s_axi_arvalid     => ddr4_arvalid,
      c0_ddr4_s_axi_arready     => ddr4_arready,
      c0_ddr4_s_axi_rready      => ddr4_rready,
      c0_ddr4_s_axi_rlast       => ddr4_rlast,
      c0_ddr4_s_axi_rvalid      => ddr4_rvalid,
      c0_ddr4_s_axi_rresp       => ddr4_rresp,
      c0_ddr4_s_axi_rid         => ddr4_rid,
      c0_ddr4_s_axi_rdata       => ddr4_rdata,
      addn_ui_clkout1           => fpga_clk,
      sys_rst                   => rst_async
    );

  ddr4_ui_clkout1       <= fpga_clk;
  ddr4_ui_clk           <= ddr4_clk;
  ddr4_ui_clk_sync_rst  <= ddr4_rst;
  ddr4_rstn             <= not(ddr4_rst);

end;
