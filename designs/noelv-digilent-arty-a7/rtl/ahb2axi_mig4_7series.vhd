------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
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

--
--  Interface to convert AHB-2.0 to AXI4 interface of Xilinx Artix-7 MIG
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
    --pipelined               : boolean := false;   -- Pipeline stage before AXI CDC?
    hindex                  : integer := 0;
    haddr                   : integer := 0;
    hmask                   : integer := 16#f00#;
    pindex                  : integer := 0;
    paddr                   : integer := 0;
    pmask                   : integer := 16#fff#
  );
  port (
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
    ddr3_dm           : out   std_logic_vector(1 downto 0);
    ddr3_odt          : out   std_logic_vector(0 downto 0);
    ddr3_cs_n         : out   std_logic_vector(0 downto 0);
    ahbso             : out   ahb_slv_out_type;
    ahbsi             : in    ahb_slv_in_type;
    apbi              : in    apb_slv_in_type;
    apbo              : out   apb_slv_out_type;
    calib_done        : out   std_logic;
    rst_n_syn         : in    std_logic;
    rst_n_async       : in    std_logic;
    clk_amba          : in    std_logic;
    sys_clk_i         : in    std_logic;
    clk_ref_i         : in    std_logic;
    ui_clk            : out   std_logic;
    ui_clk_sync_rst   : out   std_logic
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
  signal ddr3_clk       : std_ulogic;
  signal ddr3_rstn      : std_ulogic;
  signal ddr3_rst       : std_ulogic;

  -- DDR3 Signals
  signal ddr3_aclk      : std_logic;
  signal ddr3_aresetn   : std_logic;
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
  signal ddr3_wdata     : std_logic_vector(AXIDW-1 downto 0);
  signal ddr3_wstrb     : std_logic_vector(AXIDW/8-1 downto 0);
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
  signal ddr3_rdata     : std_logic_vector(AXIDW-1 downto 0);
  signal ddr3_rresp     : std_logic_vector(1 downto 0);
  signal ddr3_rlast     : std_logic;
  signal ddr3_rvalid    : std_logic;
  signal ddr3_rready    : std_logic;

  COMPONENT mig
    PORT (
      ddr3_dq : inout STD_LOGIC_VECTOR ( 15 downto 0 );
      ddr3_dqs_n : inout STD_LOGIC_VECTOR ( 1 downto 0 );
      ddr3_dqs_p : inout STD_LOGIC_VECTOR ( 1 downto 0 );
      ddr3_addr : out STD_LOGIC_VECTOR ( 13 downto 0 );
      ddr3_ba : out STD_LOGIC_VECTOR ( 2 downto 0 );
      ddr3_ras_n : out STD_LOGIC;
      ddr3_cas_n : out STD_LOGIC;
      ddr3_we_n : out STD_LOGIC;
      ddr3_reset_n : out STD_LOGIC;
      ddr3_ck_p : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr3_ck_n : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr3_cke : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr3_cs_n : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr3_dm : out STD_LOGIC_VECTOR ( 1 downto 0 );
      ddr3_odt : out STD_LOGIC_VECTOR ( 0 to 0 );
      sys_clk_i : in STD_LOGIC;
      clk_ref_i : in STD_LOGIC;
      ui_clk : out STD_LOGIC;
      ui_clk_sync_rst : out STD_LOGIC;
      mmcm_locked : out STD_LOGIC;
      aresetn : in STD_LOGIC;
      app_sr_req : in STD_LOGIC;
      app_ref_req : in STD_LOGIC;
      app_zq_req : in STD_LOGIC;
      app_sr_active : out STD_LOGIC;
      app_ref_ack : out STD_LOGIC;
      app_zq_ack : out STD_LOGIC;
      s_axi_awid : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_awaddr : in STD_LOGIC_VECTOR ( 27 downto 0 );
      s_axi_awlen : in STD_LOGIC_VECTOR ( 7 downto 0 );
      s_axi_awsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_awburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_awlock : in STD_LOGIC_VECTOR ( 0 to 0 );
      s_axi_awcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_awqos : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_awvalid : in STD_LOGIC;
      s_axi_awready : out STD_LOGIC;
      s_axi_wdata : in STD_LOGIC_VECTOR ( 127 downto 0 );
      s_axi_wstrb : in STD_LOGIC_VECTOR ( 15 downto 0 );
      s_axi_wlast : in STD_LOGIC;
      s_axi_wvalid : in STD_LOGIC;
      s_axi_wready : out STD_LOGIC;
      s_axi_bready : in STD_LOGIC;
      s_axi_bid : out STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_bvalid : out STD_LOGIC;
      s_axi_arid : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_araddr : in STD_LOGIC_VECTOR ( 27 downto 0 );
      s_axi_arlen : in STD_LOGIC_VECTOR ( 7 downto 0 );
      s_axi_arsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_arburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_arlock : in STD_LOGIC_VECTOR ( 0 to 0 );
      s_axi_arcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_arqos : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_arvalid : in STD_LOGIC;
      s_axi_arready : out STD_LOGIC;
      s_axi_rready : in STD_LOGIC;
      s_axi_rid : out STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_rdata : out STD_LOGIC_VECTOR ( 127 downto 0 );
      s_axi_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_rlast : out STD_LOGIC;
      s_axi_rvalid : out STD_LOGIC;
      init_calib_complete : out STD_LOGIC;
      device_temp : out STD_LOGIC_VECTOR ( 11 downto 0 );
      sys_rst : in STD_LOGIC
      );
  END COMPONENT;
 

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
      clk   => clk_amba,--fixme
      ahbsi => ahbsi_bridge,
      ahbso => ahbso_bridge,
      aximi => aximi,
      aximo => aximo
    );

  --ddr4_addr     <= mig_addr(13 downto 0);
  --ddr4_we_n     <= mig_addr(14);
  --ddr4_cas_n    <= mig_addr(15);
  --ddr4_ras_n    <= mig_addr(16);

  aximo_aw_lock(0)      <= axi_cdc_si.aw.lock;
  aximo_ar_lock(0)      <= axi_cdc_si.ar.lock;

  rst_async     <= not(rst_n_async);


  -- No AXI4 register slice (not pipelined).
  --without_pipe : if not pipelined generate
    axi_cdc_si <= aximo;
    aximi      <= axi_cdc_so;
  --end generate;

  
  MCB_inst : mig
    PORT MAP (
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
      ui_clk               => ui_clk,
      ui_clk_sync_rst      => ui_clk_sync_rst,
      
      mmcm_locked          => open, --fixme?
      aresetn               => rst_n_async,
      app_sr_req           => '0',
      app_ref_req          => '0',
      app_zq_req           => '0',
      app_sr_active        => open,
      app_ref_ack          => open,
      app_zq_ack           => open,      
      s_axi_awid        => axi_cdc_si.aw.id,
      s_axi_awaddr      => axi_cdc_si.aw.addr(27 downto 0),
      s_axi_awlen       => axi_cdc_si.aw.len,
      s_axi_awsize      => axi_cdc_si.aw.size,
      s_axi_awburst     => axi_cdc_si.aw.burst,
      s_axi_awlock      => "0",
      s_axi_awcache     => axi_cdc_si.aw.cache,
      s_axi_awprot      => "000",
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
      s_axi_araddr      => axi_cdc_si.ar.addr (27 downto 0),
      s_axi_arlen       => axi_cdc_si.ar.len,
      s_axi_arsize      => axi_cdc_si.ar.size,
      s_axi_arburst     => axi_cdc_si.ar.burst,
      s_axi_arlock      => "0",
      s_axi_arcache     => axi_cdc_si.ar.cache,
      s_axi_arprot      => "000",
      s_axi_arqos       => "0000",
      s_axi_arvalid     => axi_cdc_si.ar.valid,
      s_axi_arready     => axi_cdc_so.ar.ready,
      s_axi_rready      => axi_cdc_si.r.ready,
      s_axi_rid         => axi_cdc_so.r.id,
      s_axi_rdata       => axi_cdc_so.r.data,
      s_axi_rresp       => axi_cdc_so.r.resp,
      s_axi_rlast       => axi_cdc_so.r.last,
      s_axi_rvalid      => axi_cdc_so.r.valid,
      init_calib_complete => calib_done,
      device_temp       => open, --output fixme
      sys_rst           => rst_n_async --rst_n_syn

    );  

end;
