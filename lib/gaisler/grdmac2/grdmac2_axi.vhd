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
-----------------------------------------------------------------------------   
-- Entity:      grdmac2_axi
-- File:        grdmac2_axi.vhd
-- Author:      Krishna K R - Cobham Gaisler AB
-- Description: GRDMAC2 top level entity.
------------------------------------------------------------------------------ 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.generic_bm_pkg.all;
library gaisler;
use gaisler.grdmac2_pkg.all;
use gaisler.axi.all;
library techmap;
use techmap.gencomp.all;


-----------------------------------------------------------------------------
-- Top level entity for GRDMAC2.
-- This is a wrapper which integrates GRDMAC2 core to the
-- AXI master - generic bus master bridge
-----------------------------------------------------------------------------

entity grdmac2_axi is
  generic (
    tech             : integer range 0 to NTECH     := inferred;  -- Target technology
    -- APB configuration  
    pindex           : integer                      := 0;  -- APB configuartion slave index
    paddr            : integer                      := 0;  -- APB configuartion slave address
    pmask            : integer                      := 16#FF8#;  -- APB configuartion slave mask
    pirq             : integer range 0 to NAHBIRQ-1 := 0;  -- APB configuartion slave irq
    -- Bus master configuration
    dbits            : integer range 32 to 128      := 32;  -- Data width of BM and FIFO    
    en_bm1           : integer                      := 0;  -- Enable Bus master interface index1
    max_burst_length : integer range 2 to 256       := 256;  -- BM backend burst length in words. Total burst of 'Max_size'bytes, is split in to bursts of 'max_burst_length' bytes by the BMIF
    -- Buffer configuration
    ft               : integer range 0 to 5         := 0;  -- enable EDAC on RAMs (GRLIB-FT only, passed on to syncram_2pft)
                                   -- Valid values of 'ft' : 0 to 5 for dbits =32 (ft=5 is target technology specific); 0 to 4 for dbits = 64 and 128
    abits            : integer range 0 to 10        := 4;  -- FIFO address bits (actual fifo depth = 2**abits)
    -- M2B/B2M configuration
    en_timer         : integer                      := 0;  -- Enable timeout mechanism
    lendian_en       : integer                      := 0;  -- Endianness
    en_acc           : integer range 0 to 4         := 0
    );
  port (
    rstn    : in  std_ulogic;           -- Reset
    clk     : in  std_ulogic;           -- Clock
    -- APB interface signals
    apbi    : in  apb_slv_in_type;      -- APB slave input
    apbo    : out apb_slv_out_type;     -- APB slave output
    -- AXI interface signals
    aximi0  : in  axi_somi_type;        -- AXI master 0 input
    aximo0  : out axi4_mosi_type;       -- AXI master 0 output
    aximi1  : in  axi_somi_type;        -- AXI master 1 input
    aximo1  : out axi4_mosi_type;       -- AXI master 1 output
    -- System interrupt
    trigger : in  std_logic_vector(63 downto 0)            -- Input trigger

  );
end entity grdmac2_axi;

------------------------------------------------------------------------------
-- Architecture of grdmac2
------------------------------------------------------------------------------

architecture rtl of grdmac2_axi is
  -----------------------------------------------------------------------------
  -- Constant declaration
  -----------------------------------------------------------------------------
  attribute sync_set_reset         : string;
  attribute sync_set_reset of rstn : signal is "true";

  -- Reset configuration

  constant ASYNC_RST : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  -- Plug and Play Information (AHB master interface)

  constant hconfig : ahb_config_type := (
    0      => ahb_device_reg (VENDOR_GAISLER, GAISLER_GRDMAC2, 0, REVISION, 0),
    others => zero32);

  -- Bus master interface burst chop mask
  constant burst_chop_mask : integer := (max_burst_length*(log_2(AHBDW)-1));

  constant axi4_aw_mosi_none : axi4_aw_mosi_type := ((others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'), '0', (others => '0'), (others => '0'), '0', (others => '0'));
  constant axi4_w_mosi_none  : axi4_w_mosi_type  := ((others => '0'), (others => '0'), '0', '0');
  constant axi_b_mosi_none   : axi_b_mosi_type   := (ready   => '0');
  constant axi4_ar_mosi_none : axi4_ar_mosi_type := ((others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'), '0', (others => '0'), (others => '0'), '0', (others => '0'));
  constant axi_r_mosi_none   : axi_r_mosi_type   := (ready   => '0');
  constant axi4mo_none       : axi4_mosi_type    := (axi4_aw_mosi_none, axi4_w_mosi_none, axi_b_mosi_none, axi4_ar_mosi_none, axi_r_mosi_none);

  -----------------------------------------------------------------------------
  -- Records and types
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Signal declaration
  -----------------------------------------------------------------------------
  signal bm0_in           : bm_in_type;
  signal bm0_out          : bm_out_type;
  signal bm1_in           : bm_in_type;
  signal bm1_out          : bm_out_type;
  signal bm0_endian       : std_logic;
  signal bm1_endian       : std_logic;
  signal bm0_rd_data      : std_logic_vector(dbits-1 downto 0);
  signal bm1_rd_data      : std_logic_vector(dbits-1 downto 0);
  signal bm0_wr_data      : std_logic_vector(dbits-1 downto 0);
  signal bm1_wr_data      : std_logic_vector(dbits-1 downto 0);
  signal bm0_wr_data_temp : std_logic_vector(dbits-1 downto 0);
  signal bm1_wr_data_temp : std_logic_vector(dbits-1 downto 0);
  -----------------------------------------------------------------------------
  -- Function/procedure declaration
  -----------------------------------------------------------------------------
  
begin  -- rtl

  -----------------
  -- Assignments --
  -----------------
  bm1_dis : if en_bm1 = 0 generate
    aximo1  <= axi4mo_none;
    bm1_out <= BM_OUT_RST;
  end generate;

  bm1_en : if en_bm1 = 1 generate
    -- LE data manipulation
    bm1_out.rd_data(127 downto 128-dbits) <= bl_wrd_swap(bm1_rd_data, bm1_endian, dbits);
    bm1_wr_data_temp                      <= bm1_in.wr_data(127 downto 128-dbits);
    bm1_wr_data                           <= bl_wrd_swap(bm1_wr_data_temp, bm1_endian, dbits);
  end generate;

  -- LE data manipulation
  bm0_out.rd_data(127 downto 128-dbits) <= bl_wrd_swap(bm0_rd_data, bm0_endian, dbits);
  bm0_wr_data_temp                      <= bm0_in.wr_data(127 downto 128-dbits);
  bm0_wr_data                           <= bl_wrd_swap(bm0_wr_data_temp, bm0_endian, dbits);

  -----------------------------------------------------------------------------
  -- Component instantiation
  -----------------------------------------------------------------------------

  -- grdmac2 core
  core : grdmac2
    generic map (
      tech     => tech,
      pindex   => pindex,
      paddr    => paddr,
      pmask    => pmask,
      pirq     => pirq,
      dbits    => dbits,
      en_bm1   => en_bm1,
      ft       => ft,
      abits    => abits,
      en_timer => en_timer,
      en_acc   => en_acc
      )
    port map (
      rstn       => rstn,
      clk        => clk,
      apbi       => apbi,
      apbo       => apbo,
      bm0_in     => bm0_in,
      bm1_in     => bm1_in,
      bm0_out    => bm0_out,
      bm1_out    => bm1_out,
      bm0_endian => bm0_endian,
      bm1_endian => bm1_endian,
      trigger    => trigger
      );


  -- BM0
  bm0 : generic_bm_axi
    generic map (
      async_reset      => ASYNC_RST,
      bm_dw            => dbits,
      be_dw            => AHBDW,
      be_rd_pipe       => 0,
      max_size         => 1024,
      max_burst_length => max_burst_length,
      burst_chop_mask  => burst_chop_mask,
      bm_info_print    => 1,
      lendian_en       => lendian_en,
      axi_bm_id_width  => AXI_ID_WIDTH)
    port map (
      clk              => clk,
      rstn             => rstn,
      --AXI4 signals--
      --write address channel
      axi_aw_id        => aximo0.aw.id,
      axi_aw_addr      => aximo0.aw.addr,
      axi_aw_len       => aximo0.aw.len,
      axi_aw_size      => aximo0.aw.size,
      axi_aw_burst     => aximo0.aw.burst,
      axi_aw_lock      => aximo0.aw.lock,
      axi_aw_cache     => aximo0.aw.cache,
      axi_aw_prot      => aximo0.aw.prot,
      axi_aw_valid     => aximo0.aw.valid,
      axi_aw_qos       => aximo0.aw.qos,
      axi_aw_ready     => aximi0.aw.ready,
      --write data channel
      axi_w_data       => aximo0.w.data,
      axi_w_strb       => aximo0.w.strb,
      axi_w_last       => aximo0.w.last,
      axi_w_valid      => aximo0.w.valid,
      axi_w_ready      => aximi0.w.ready,
      --write response channel
      axi_b_ready      => aximo0.b.ready,
      axi_b_id         => aximi0.b.id,
      axi_b_resp       => aximi0.b.resp,
      axi_b_valid      => aximi0.b.valid,
      --read address channel
      axi_ar_id        => aximo0.ar.id,
      axi_ar_addr      => aximo0.ar.addr,
      axi_ar_len       => aximo0.ar.len,
      axi_ar_size      => aximo0.ar.size,
      axi_ar_burst     => aximo0.ar.burst,
      axi_ar_lock      => aximo0.ar.lock,
      axi_ar_cache     => aximo0.ar.cache,
      axi_ar_prot      => aximo0.ar.prot,
      axi_ar_valid     => aximo0.ar.valid,
      axi_ar_qos       => aximo0.ar.qos,
      axi_ar_ready     => aximi0.ar.ready,
      --read data channel
      axi_r_ready      => aximo0.r.ready,
      axi_r_id         => aximi0.r.id,
      axi_r_data       => aximi0.r.data,
      axi_r_resp       => aximi0.r.resp,
      axi_r_last       => aximi0.r.last,
      axi_r_valid      => aximi0.r.valid,
      --Bus master domain signals
      --Read Channel
      bmrd_addr        => bm0_in.rd_addr,
      bmrd_size        => bm0_in.rd_size,
      bmrd_req         => bm0_in.rd_req,
      bmrd_req_granted => bm0_out.rd_req_grant,
      bmrd_data        => bm0_rd_data,
      bmrd_valid       => bm0_out.rd_valid,
      bmrd_done        => bm0_out.rd_done,
      bmrd_error       => bm0_out.rd_err,
      bmwr_addr        => bm0_in.wr_addr,
      bmwr_size        => bm0_in.wr_size,
      bmwr_req         => bm0_in.wr_req,
      bmwr_req_granted => bm0_out.wr_req_grant,
      bmwr_data        => bm0_wr_data,
      bmwr_full        => bm0_out.wr_full,
      bmwr_done        => bm0_out.wr_done,
      bmwr_error       => bm0_out.wr_err,
      --Endianess Output
      endian_out       => bm0_endian   --0->BE, 1->LE
      --Exclusive access
      );

  -- BM1
  bm1_gen : if en_bm1 /= 0 generate
    bm1 : generic_bm_axi
      generic map (
        async_reset      => ASYNC_RST,
        bm_dw            => dbits,
        be_dw            => AHBDW,
        be_rd_pipe       => 0,
        max_size         => 1024,
        max_burst_length => max_burst_length,
        burst_chop_mask  => burst_chop_mask,
        bm_info_print    => 1,
        lendian_en       => lendian_en,
        axi_bm_id_width  => AXI_ID_WIDTH)
      port map (
        clk              => clk,
        rstn             => rstn,
        --AXI4 signals--
        --write address channel
        axi_aw_id        => aximo1.aw.id,
        axi_aw_addr      => aximo1.aw.addr,
        axi_aw_len       => aximo1.aw.len,
        axi_aw_size      => aximo1.aw.size,
        axi_aw_burst     => aximo1.aw.burst,
        axi_aw_lock      => aximo1.aw.lock,
        axi_aw_cache     => aximo1.aw.cache,
        axi_aw_prot      => aximo1.aw.prot,
        axi_aw_valid     => aximo1.aw.valid,
        axi_aw_qos       => aximo1.aw.qos,
        axi_aw_ready     => aximi1.aw.ready,
        --write data channel
        axi_w_data       => aximo1.w.data,
        axi_w_strb       => aximo1.w.strb,
        axi_w_last       => aximo1.w.last,
        axi_w_valid      => aximo1.w.valid,
        axi_w_ready      => aximi1.w.ready,
        --write response channel
        axi_b_ready      => aximo1.b.ready,
        axi_b_id         => aximi1.b.id,
        axi_b_resp       => aximi1.b.resp,
        axi_b_valid      => aximi1.b.valid,
        --read address channel
        axi_ar_id        => aximo1.ar.id,
        axi_ar_addr      => aximo1.ar.addr,
        axi_ar_len       => aximo1.ar.len,
        axi_ar_size      => aximo1.ar.size,
        axi_ar_burst     => aximo1.ar.burst,
        axi_ar_lock      => aximo1.ar.lock,
        axi_ar_cache     => aximo1.ar.cache,
        axi_ar_prot      => aximo1.ar.prot,
        axi_ar_valid     => aximo1.ar.valid,
        axi_ar_qos       => aximo1.ar.qos,
        axi_ar_ready     => aximi1.ar.ready,
        --read data channel
        axi_r_ready      => aximo1.r.ready,
        axi_r_id         => aximi1.r.id,
        axi_r_data       => aximi1.r.data,
        axi_r_resp       => aximi1.r.resp,
        axi_r_last       => aximi1.r.last,
        axi_r_valid      => aximi1.r.valid,
        --Bus master domain signals
        --Read Channel
        bmrd_addr        => bm1_in.rd_addr,
        bmrd_size        => bm1_in.rd_size,
        bmrd_req         => bm1_in.rd_req,
        bmrd_req_granted => bm1_out.rd_req_grant,
        bmrd_data        => bm1_rd_data,
        bmrd_valid       => bm1_out.rd_valid,
        bmrd_done        => bm1_out.rd_done,
        bmrd_error       => bm1_out.rd_err,
        bmwr_addr        => bm1_in.wr_addr,
        bmwr_size        => bm1_in.wr_size,
        bmwr_req         => bm1_in.wr_req,
        bmwr_req_granted => bm1_out.wr_req_grant,
        bmwr_data        => bm1_wr_data,
        bmwr_full        => bm1_out.wr_full,
        bmwr_done        => bm1_out.wr_done,
        bmwr_error       => bm1_out.wr_err,
        --Endianess Output
        endian_out       => bm1_endian  --0->BE, 1->LE
        --Exclusive access
        );
  end generate;


-- pragma translate_off
  tb : process
  begin
    wait for 1 ns;
    assert endian_check(bm0_endian, bm1_endian, en_bm1)
      report "grdmac2: Both busmaster interfaces must have same endianness!"
      severity error;
  end process tb;
-- pragma translate_on
  
end architecture rtl;



