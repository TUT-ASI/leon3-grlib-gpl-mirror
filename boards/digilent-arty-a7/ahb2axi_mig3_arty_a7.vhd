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
-------------------------------------------------------------------------------
-- Entity:      ahb2axi_mig3_arty_a7
-- File:        ahb2axi_mig3_arty_a7.vhd

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


entity ahb2axi_mig3_arty_a7 is
  generic(
    hindex                  : integer := 0;
    haddr                   : integer := 0;
    hmask                   : integer := 16#f00#;
    pindex                  : integer := 0;
    paddr                   : integer := 0;
    pmask                   : integer := 16#fff#;
    ahbendian               : integer := AHBENDIAN
  );
  port(
    ddr3_dq           : inout std_logic_vector(15 downto 0);
    ddr3_dqs_p        : inout std_logic_vector(1 downto 0);
    ddr3_dqs_n        : inout std_logic_vector(1 downto 0);
    ddr3_addr         : out   std_logic_vector(13 downto 0);
    ddr3_ba           : out   std_logic_vector(2 downto 0);
    ddr3_ras_n        : out   std_logic;
    ddr3_cas_n        : out   std_logic;
    ddr3_we_n         : out   std_logic;
    ddr3_reset_n      : out   std_logic;
    ddr3_ck_p         : out   std_logic_vector(0 downto 0);
    ddr3_ck_n         : out   std_logic_vector(0 downto 0);
    ddr3_cke          : out   std_logic_vector(0 downto 0);
    ddr3_cs_n         : out   std_logic_vector(0 downto 0);
    ddr3_dm           : out   std_logic_vector(1 downto 0);
    ddr3_odt          : out   std_logic_vector(0 downto 0);
    ahbso             : out   ahb_slv_out_type;
    ahbsi             : in    ahb_slv_in_type;
    apbi              : in    apb_slv_in_type;
    apbo              : out   apb_slv_out_type;
    calib_done        : out   std_logic;
    rst_n_syn         : in    std_logic;
    amba_rstn         : in    std_logic;
    clk_amba          : in    std_logic;
    sys_clk_i         : in    std_logic;
    clk_ref_i         : in    std_logic;
    ui_clk            : out   std_logic;
    ui_clk_sync_rst   : out   std_logic
   );
end ;


architecture rtl of ahb2axi_mig3_arty_a7 is
 
   component mig is
   port (
    ddr3_dq              : inout std_logic_vector(15 downto 0);--
    ddr3_addr            : out   std_logic_vector(13 downto 0);--
    ddr3_ba              : out   std_logic_vector(2 downto 0);--
    ddr3_ras_n           : out   std_logic;--
    ddr3_cas_n           : out   std_logic;--
    ddr3_we_n            : out   std_logic;--
    ddr3_reset_n         : out   std_logic;--
    ddr3_dqs_n           : inout std_logic_vector(1 downto 0);--
    ddr3_dqs_p           : inout std_logic_vector(1 downto 0);--
    ddr3_ck_p            : out   std_logic_vector(0 downto 0);--
    ddr3_ck_n            : out   std_logic_vector(0 downto 0);--
    ddr3_cke             : out   std_logic_vector(0 downto 0);--
    ddr3_cs_n            : out   std_logic_vector(0 downto 0);--
    ddr3_dm              : out   std_logic_vector(1 downto 0);--
    ddr3_odt             : out   std_logic_vector(0 downto 0);--
    sys_clk_i            : in    std_logic;--
    clk_ref_i            : in    std_logic;--
    -- Slave Interface Write Address Ports
    aresetn              : in std_logic;
    s_axi_awid           : in std_logic_vector(3 downto 0);
    s_axi_awaddr         : in std_logic_vector(27 downto 0);
    s_axi_awlen          : in std_logic_vector(7 downto 0);
    s_axi_awsize         : in std_logic_vector(2 downto 0);
    s_axi_awburst        : in std_logic_vector(1 downto 0);
    s_axi_awlock         : in std_logic_vector(0 downto 0);
    s_axi_awcache        : in std_logic_vector(3 downto 0);
    s_axi_awprot         : in std_logic_vector(2 downto 0);
    s_axi_awqos          : in std_logic_vector(3 downto 0);
    s_axi_awvalid        : in    std_logic;
    s_axi_awready        : out   std_logic;
    --Slave Interface Write Data Ports
    s_axi_wdata          : in std_logic_vector(AHBDW-1 downto 0);
    s_axi_wstrb          : in std_logic_vector((AHBDW/8)-1 downto 0);
    s_axi_wlast          : in std_logic;
    s_axi_wvalid         : in std_logic;
    s_axi_wready         : out std_logic;
    -- Slave Interface Write Response Ports
    s_axi_bready         : in std_logic;
    s_axi_bid            : out std_logic_vector(3 downto 0);
    s_axi_bresp          : out std_logic_vector(1 downto 0);
    s_axi_bvalid         : out std_logic;
    -- Slave Interface Read Address Ports
    s_axi_arid           : in std_logic_vector(3 downto 0);
    s_axi_araddr         : in std_logic_vector(27 downto 0);
    s_axi_arlen          : in std_logic_vector(7 downto 0);
    s_axi_arsize         : in std_logic_vector(2 downto 0);
    s_axi_arburst        : in std_logic_vector(1 downto 0);
    s_axi_arlock         : in std_logic_vector(0 downto 0);
    s_axi_arcache        : in std_logic_vector(3 downto 0);
    s_axi_arprot         : in std_logic_vector(2 downto 0);
    s_axi_arqos          : in std_logic_vector(3 downto 0);
    s_axi_arvalid        : in std_logic;
    s_axi_arready        : out std_logic;
    -- Slave Interface Read Data Ports
    s_axi_rready         : in std_logic;
    s_axi_rid            : out std_logic_vector(3 downto 0);
    s_axi_rdata          : out std_logic_vector(AHBDW-1 downto 0);
    s_axi_rresp          : out std_logic_vector(1 downto 0);
    s_axi_rlast          : out std_logic;
    s_axi_rvalid         : out std_logic;
    app_sr_req           : in    std_logic;--
    app_ref_req          : in    std_logic;--
    app_zq_req           : in    std_logic;--
    app_sr_active        : out   std_logic;--
    app_ref_ack          : out   std_logic;--
    app_zq_ack           : out   std_logic;--
    ui_clk               : out   std_logic;--
    ui_clk_sync_rst      : out   std_logic;--
    mmcm_locked          : out   std_logic;  
    init_calib_complete  : out   std_logic;--
    sys_rst              : in    std_logic--
    );
 end component mig;


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
      s_axi_wstrb : IN STD_LOGIC_VECTOR((AHBDW/8)-1 DOWNTO 0);
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
      m_axi_wstrb : OUT STD_LOGIC_VECTOR((AHBDW/8)-1 DOWNTO 0);
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

   constant pconfig : apb_config_type := (
     0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
     1 => apb_iobar(paddr, pmask));

   signal aximi : axi_somi_type;
   signal aximo : axi4_mosi_type;
   signal ahbsi_bridge : ahb_slv_in_type;
   signal ahbso_bridge : ahb_slv_out_type;

   signal mmcm_locked : std_logic;

   signal s_axi_awlock : std_logic_vector (0 downto 0);
   signal s_axi_arlock : std_logic_vector (0 downto 0);

   signal ddr3_awid      : std_logic_vector(3 downto 0);
   signal ddr3_awaddr    : std_logic_vector(31 downto 0);
   signal ddr3_awlen     : std_logic_vector(7 downto 0);
   signal ddr3_awsize    : std_logic_vector(2 downto 0);
   signal ddr3_awburst   : std_logic_vector(1 downto 0);
   signal ddr3_awlock    : std_logic_vector(0 downto 0);
   signal ddr3_awcache   : std_logic_vector(3 downto 0);
   signal ddr3_awprot    : std_logic_vector(2 downto 0);
   signal ddr3_awqos     : std_logic_vector(3 downto 0);
   signal ddr3_awvalid   : std_logic;
   signal ddr3_awready   : std_logic;
   signal ddr3_wdata     : std_logic_vector(AHBDW-1 downto 0);
   signal ddr3_wstrb     : std_logic_vector((AHBDW/8)-1 downto 0);
   signal ddr3_wlast     : std_logic;
   signal ddr3_wvalid    : std_logic;
   signal ddr3_wready    : std_logic;
   signal ddr3_bid       : std_logic_vector(3 downto 0);
   signal ddr3_bresp     : std_logic_vector(1 downto 0);
   signal ddr3_bvalid    : std_logic;
   signal ddr3_bready    : std_logic;
   signal ddr3_arid      : std_logic_vector(3 downto 0);
   signal ddr3_araddr    : std_logic_vector(31 downto 0);
   signal ddr3_arlen     : std_logic_vector(7 downto 0);
   signal ddr3_arsize    : std_logic_vector(2 downto 0);
   signal ddr3_arburst   : std_logic_vector(1 downto 0);
   signal ddr3_arlock    : std_logic_vector(0 downto 0);
   signal ddr3_arcache   : std_logic_vector(3 downto 0);
   signal ddr3_arprot    : std_logic_vector(2 downto 0);
   signal ddr3_arqos     : std_logic_vector(3 downto 0);
   signal ddr3_arvalid   : std_logic;
   signal ddr3_arready   : std_logic;
   signal ddr3_rid       : std_logic_vector(3 downto 0);
   signal ddr3_rdata     : std_logic_vector(AHBDW-1 downto 0);
   signal ddr3_rresp     : std_logic_vector(1 downto 0);
   signal ddr3_rlast     : std_logic;
   signal ddr3_rvalid    : std_logic;
   signal ddr3_rready    : std_logic;
   signal ddr3_axi_clk   : std_logic;
   signal ddr3_axi_rstn  : std_logic;

begin

  apbo.pindex  <= pindex;
  apbo.pconfig <= pconfig;
  apbo.pirq    <= (others => '0');
  apbo.prdata  <= (others => '0');

  ahbsi_bridge.hsel <= ahbsi.hsel;
  ahbsi_bridge.haddr <= ahbsi.haddr;
  ahbsi_bridge.hwrite <= ahbsi.hwrite;
  ahbsi_bridge.htrans <= ahbsi.htrans;
  ahbsi_bridge.hsize <= ahbsi.hsize;
  ahbsi_bridge.hburst <= ahbsi.hburst;
  ahbsi_bridge.hprot <= ahbsi.hprot;
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
      ahb_endianness  => ahbendian,
      endianness_mode => 0,
      narrow_acc_mode => 0,
      vendor  => VENDOR_GAISLER,
      device  => GAISLER_MIG_7SERIES,
      bar0    => ahb2ahb_membar(haddr, '1', '1', hmask)
      )
    port map (
      rstn  => amba_rstn,
      clk   => clk_amba,
      ahbsi => ahbsi_bridge,
      ahbso => ahbso_bridge,
      aximi => aximi,
      aximo => aximo);

  s_axi_awlock(0) <= aximo.aw.lock;
  s_axi_arlock(0) <= aximo.ar.lock;

  MCB_CDC : mig_cdc
    PORT MAP (
      s_axi_aclk        => clk_amba,
      s_axi_aresetn     => amba_rstn,
      s_axi_awid        => aximo.aw.id,
      s_axi_awaddr      => aximo.aw.addr,
      s_axi_awlen       => aximo.aw.len,
      s_axi_awsize      => aximo.aw.size,
      s_axi_awburst     => aximo.aw.burst,
      s_axi_awlock      => s_axi_awlock,
      s_axi_awcache     => aximo.aw.cache,
      s_axi_awprot      => aximo.aw.prot,
      s_axi_awregion    => "0000",
      s_axi_awqos       => aximo.aw.qos,
      s_axi_awvalid     => aximo.aw.valid,
      s_axi_awready     => aximi.aw.ready,
      s_axi_wdata       => aximo.w.data,
      s_axi_wstrb       => aximo.w.strb,
      s_axi_wlast       => aximo.w.last,
      s_axi_wvalid      => aximo.w.valid,
      s_axi_wready      => aximi.w.ready,
      s_axi_bid         => aximi.b.id,
      s_axi_bresp       => aximi.b.resp,
      s_axi_bvalid      => aximi.b.valid,
      s_axi_bready      => aximo.b.ready,
      s_axi_arid        => aximo.ar.id,
      s_axi_araddr      => aximo.ar.addr,
      s_axi_arlen       => aximo.ar.len,
      s_axi_arsize      => aximo.ar.size,
      s_axi_arburst     => aximo.ar.burst,
      s_axi_arlock      => s_axi_arlock,
      s_axi_arcache     => aximo.ar.cache,
      s_axi_arprot      => aximo.ar.prot,
      s_axi_arregion    => "0000",
      s_axi_arqos       => aximo.ar.qos,
      s_axi_arvalid     => aximo.ar.valid,
      s_axi_arready     => aximi.ar.ready,
      s_axi_rid         => aximi.r.id,
      s_axi_rdata       => aximi.r.data,
      s_axi_rresp       => aximi.r.resp,
      s_axi_rlast       => aximi.r.last,
      s_axi_rvalid      => aximi.r.valid,
      s_axi_rready      => aximo.r.ready,
      m_axi_aclk        => ddr3_axi_clk,
      m_axi_aresetn     => amba_rstn,
      m_axi_awid        => ddr3_awid,
      m_axi_awaddr      => ddr3_awaddr,
      m_axi_awlen       => ddr3_awlen,
      m_axi_awsize      => ddr3_awsize,
      m_axi_awburst     => ddr3_awburst,
      m_axi_awlock      => ddr3_awlock,
      m_axi_awcache     => ddr3_awcache,
      m_axi_awprot      => ddr3_awprot,
      m_axi_awregion    => open,
      m_axi_awqos       => ddr3_awqos,
      m_axi_awvalid     => ddr3_awvalid,
      m_axi_awready     => ddr3_awready,
      m_axi_wdata       => ddr3_wdata,
      m_axi_wstrb       => ddr3_wstrb,
      m_axi_wlast       => ddr3_wlast,
      m_axi_wvalid      => ddr3_wvalid,
      m_axi_wready      => ddr3_wready,
      m_axi_bid         => ddr3_bid,
      m_axi_bresp       => ddr3_bresp,
      m_axi_bvalid      => ddr3_bvalid,
      m_axi_bready      => ddr3_bready,
      m_axi_arid        => ddr3_arid,
      m_axi_araddr      => ddr3_araddr,
      m_axi_arlen       => ddr3_arlen,
      m_axi_arsize      => ddr3_arsize,
      m_axi_arburst     => ddr3_arburst,
      m_axi_arlock      => ddr3_arlock,
      m_axi_arcache     => ddr3_arcache,
      m_axi_arprot      => ddr3_arprot,
      m_axi_arregion    => open,
      m_axi_arqos       => ddr3_arqos,
      m_axi_arvalid     => ddr3_arvalid,
      m_axi_arready     => ddr3_arready,
      m_axi_rid         => ddr3_rid,
      m_axi_rdata       => ddr3_rdata,
      m_axi_rresp       => ddr3_rresp,
      m_axi_rlast       => ddr3_rlast,
      m_axi_rvalid      => ddr3_rvalid,
      m_axi_rready      => ddr3_rready
      );  
  
  MCB_inst : mig
    port map (
      ddr3_dq              => ddr3_dq,
      ddr3_dqs_p           => ddr3_dqs_p,
      ddr3_dqs_n           => ddr3_dqs_n,
      ddr3_addr            => ddr3_addr,
      ddr3_ba              => ddr3_ba,
      ddr3_ras_n           => ddr3_ras_n,
      ddr3_cas_n           => ddr3_cas_n,
      ddr3_we_n            => ddr3_we_n,
      ddr3_reset_n         => ddr3_reset_n,
      ddr3_ck_p            => ddr3_ck_p,
      ddr3_ck_n            => ddr3_ck_n,
      ddr3_cke             => ddr3_cke,
      ddr3_cs_n            => ddr3_cs_n,
      ddr3_dm              => ddr3_dm,
      ddr3_odt             => ddr3_odt,
      
      sys_clk_i            => sys_clk_i,
      clk_ref_i            => clk_ref_i,
      aresetn              => amba_rstn,
      
      s_axi_awid        => ddr3_awid,
      s_axi_awaddr      => ddr3_awaddr(27 downto 0),
      s_axi_awlen       => ddr3_awlen,
      s_axi_awsize      => ddr3_awsize,
      s_axi_awburst     => ddr3_awburst,
      s_axi_awlock      => ddr3_awlock,
      s_axi_awcache     => ddr3_awcache,
      s_axi_awprot      => ddr3_awprot,
      s_axi_awqos       => ddr3_awqos,
      s_axi_awvalid     => ddr3_awvalid,
      s_axi_awready     => ddr3_awready,
      s_axi_wdata       => ddr3_wdata,
      s_axi_wstrb       => ddr3_wstrb,
      s_axi_wlast       => ddr3_wlast,
      s_axi_wvalid      => ddr3_wvalid,
      s_axi_wready      => ddr3_wready,
      s_axi_bready      => ddr3_bready,
      s_axi_bid         => ddr3_bid,
      s_axi_bresp       => ddr3_bresp,
      s_axi_bvalid      => ddr3_bvalid,
      s_axi_arid        => ddr3_arid,
      s_axi_araddr      => ddr3_araddr(27 downto 0),
      s_axi_arlen       => ddr3_arlen,
      s_axi_arsize      => ddr3_arsize,
      s_axi_arburst     => ddr3_arburst,
      s_axi_arlock      => ddr3_arlock,
      s_axi_arcache     => ddr3_arcache,
      s_axi_arprot      => ddr3_arprot,
      s_axi_arqos       => ddr3_arqos,
      s_axi_arvalid     => ddr3_arvalid,
      s_axi_arready     => ddr3_arready,
      s_axi_rready      => ddr3_rready,
      s_axi_rlast       => ddr3_rlast,
      s_axi_rvalid      => ddr3_rvalid,
      s_axi_rresp       => ddr3_rresp,
      s_axi_rid         => ddr3_rid,
      s_axi_rdata       => ddr3_rdata,
      
      app_sr_req           => '0',
      app_ref_req          => '0',
      app_zq_req           => '0',
      app_sr_active        => open,
      app_ref_ack          => open,
      app_zq_ack           => open,
      
      ui_clk               => ddr3_axi_clk,
      ui_clk_sync_rst      => ddr3_axi_rstn,
      mmcm_locked          => mmcm_locked,
      init_calib_complete  => calib_done,
      sys_rst              => rst_n_syn
      );
  

end;
