------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
library techmap;
use techmap.gencomp.all;

package spacefibre is

  -------------------------------------------------------------------------------
  -- Types and records
  -------------------------------------------------------------------------------

  type grspfi_in_type is record
    se_rx_clk    : std_ulogic;
    se_rx_data   : std_logic_vector(39 downto 0);
    se_rx_kflags : std_logic_vector(3 downto 0);
    se_rx_serror : std_logic_vector(3 downto 0);
    se_no_signal : std_ulogic;
  end record;

  type grspfi_out_type is record
    se_tx_data       : std_logic_vector(39 downto 0);
    se_tx_kflags     : std_logic_vector(3 downto 0);
    se_tx_en         : std_ulogic;
    se_rx_en         : std_ulogic;
    se_inv_pol       : std_ulogic;
    se_tx_data_dbg   : std_logic_vector(31 downto 0);
    se_tx_kflags_dbg : std_logic_vector(3 downto 0);
    se_rx_data_dbg   : std_logic_vector(31 downto 0);
    se_rx_kflags_dbg : std_logic_vector(3 downto 0);
  end record;

  type grspfi_in_type_vector is array (natural range <>) of grspfi_in_type;
  type grspfi_out_type_vector is array (natural range <>) of grspfi_out_type;

  type bm_in_type is record
    -- Read channel
    rd_data      : std_logic_vector(127 downto 0);
    rd_req_grant : std_logic;
    rd_valid     : std_logic;
    rd_done      : std_logic;
    rd_err       : std_logic;
    -- Write channel
    wr_req_grant : std_logic;
    wr_full      : std_logic;
    wr_done      : std_logic;
    wr_err       : std_logic;
  end record;

  type bm_out_type is record
    -- Read channel
    rd_addr : std_logic_vector(31 downto 0);
    rd_size : std_logic_vector(9 downto 0);
    rd_req  : std_logic;
    -- Write channel
    wr_addr : std_logic_vector(31 downto 0);
    wr_size : std_logic_vector(9 downto 0);
    wr_req  : std_logic;
    wr_data : std_logic_vector(127 downto 0);
  end record;

  type bm_in_vector_type is array (natural range <>) of bm_in_type;
  type bm_out_vector_type is array (natural range <>) of bm_out_type;

  -------------------------------------------------------------------------------
  -- Components
  -------------------------------------------------------------------------------

  component grspfi_codec is
    generic (
      g_tech               : integer;
      g_use_8b10b          : integer range 0 to 1;
      g_use_sep_txclk      : integer range 0 to 1;
      g_16_20_bit_mode     : integer range 0 to 1;
      g_ticks_2us          : natural range 1 to 2**13;
      g_tx_skip_freq       : natural range 1 to 2**13;
      g_prbs_init1         : integer range 0 to 1;
      g_depth_rbuf_data    : natural range 1 to 32;
      g_depth_rbuf_fct     : natural range 1 to 32;
      g_depth_rbuf_bc      : natural range 1 to 32;
      g_no_vc              : integer range 1 to 32;
      g_fct_multiplier     : integer range 1 to 8;
      g_depth_vc_rx_buf    : natural range 1 to 32;
      g_depth_vc_tx_buf    : natural range 1 to 32;
      g_remote_fct_cnt_max : natural range 1 to 32;
      g_width_bw_credit    : natural;
      g_min_bw_credit      : natural;
      g_idle_time_limit    : natural range 0 to 2**16-1);
    port (
      clk                  : in  std_logic;
      tx_clk               : in  std_logic;
      rst                  : in  std_logic;
      vc_tx_full           : out std_logic_vector(g_no_vc-1 downto 0);
      vc_rx_data           : out std_logic_vector(32*g_no_vc-1 downto 0);
      vc_rx_kflags         : out std_logic_vector(4*g_no_vc-1 downto 0);
      vc_rx_valid          : out std_logic_vector(g_no_vc-1 downto 0);
      vc_rx_ren            : in  std_logic_vector(g_no_vc-1 downto 0);
      vc_tx_data           : in  std_logic_vector(32*g_no_vc-1 downto 0);
      vc_tx_kflags         : in  std_logic_vector(4*g_no_vc-1 downto 0);
      vc_tx_wen            : in  std_logic_vector(g_no_vc-1 downto 0);
      vc_tx_timeslot       : in  std_logic_vector(5 downto 0);
      bc_rx_data           : out std_logic_vector(63 downto 0);
      bc_rx_channel        : out std_logic_vector(7 downto 0);
      bc_rx_btype          : out std_logic_vector(7 downto 0);
      bc_rx_valid          : out std_logic;
      bc_rx_late           : out std_logic;
      bc_rx_delayed        : out std_logic;
      bc_tx_ack            : out std_logic;
      bc_tx_data           : in  std_logic_vector(63 downto 0);
      bc_tx_channel        : in  std_logic_vector(7 downto 0);
      bc_tx_btype          : in  std_logic_vector(7 downto 0);
      bc_tx_delayed        : in  std_logic;
      bc_tx_late           : in  std_logic;
      bc_tx_wen            : in  std_logic;
      se_tx_data           : out std_logic_vector(39 downto 0);
      se_tx_kflags         : out std_logic_vector(3 downto 0);
      se_tx_en             : out std_logic;
      se_rx_en             : out std_logic;
      se_inv_pol           : out std_logic;
      se_rx_clk            : in  std_logic;
      se_rx_data           : in  std_logic_vector(39 downto 0);
      se_rx_kflags         : in  std_logic_vector(3 downto 0);
      se_rx_serror         : in  std_logic_vector(3 downto 0);
      se_no_signal         : in  std_logic;
      se_tx_data_dbg       : out std_logic_vector(31 downto 0);
      se_tx_kflags_dbg     : out std_logic_vector(3 downto 0);
      se_rx_data_dbg       : out std_logic_vector(31 downto 0);
      se_rx_kflags_dbg     : out std_logic_vector(3 downto 0);
      cf_reset             : out std_logic;
      cf_vc_priorities     : in  std_logic_vector(4*g_no_vc-1 downto 0);
      cf_vc_expected_bw    : in  std_logic_vector(16*g_no_vc-1 downto 0);
      cf_vc_tslot_vecs     : in  std_logic_vector(64*g_no_vc-1 downto 0);
      cf_bc_expected_bw    : in  std_logic_vector(15 downto 0);
      cf_data_scr_en       : in  std_logic;
      cf_link_rst          : in  std_logic;
      cf_lane_start        : in  std_logic;
      cf_auto_start        : in  std_logic;
      cf_lane_rst          : in  std_logic;
      cf_loopback          : in  std_logic;
      cf_standby_reason    : in  std_logic_vector(7 downto 0);
      sr_bw_over_use       : out std_logic_vector(g_no_vc-1 downto 0);
      sr_bw_under_use      : out std_logic_vector(g_no_vc-1 downto 0);
      sr_dest_has_credit   : out std_logic_vector(g_no_vc-1 downto 0);
      sr_input_buf_ov      : out std_logic_vector(g_no_vc-1 downto 0);
      sr_fct_cnt_ov        : out std_logic_vector(g_no_vc-1 downto 0);
      sr_crc16_err         : out std_logic;
      sr_frame_err         : out std_logic;
      sr_crc8_err          : out std_logic;
      sr_seq_err           : out std_logic;
      sr_rbuf_empty        : out std_logic;
      sr_retry_cnt         : out std_logic_vector(3 downto 0);
      sr_too_many_err      : out std_logic;
      sr_protocol_err      : out std_logic;
      sr_far_end_lrst      : out std_logic;
      sr_lane_state        : out std_logic_vector(3 downto 0);
      sr_rxerr_count       : out std_logic_vector(7 downto 0);
      sr_rxerr_count_of    : out std_logic;
      sr_far_end_standby   : out std_logic;
      sr_timeout           : out std_logic;
      sr_far_end_los       : out std_logic;
      sr_far_end_los_cause : out std_logic_vector(1 downto 0);
      sr_far_end_cap       : out std_logic_vector(3 downto 0);
      sr_rx_polarity       : out std_logic);
  end component grspfi_codec;

  component grspfi is
    generic (
      tech               : integer range 0 to NTECH     := inferred;
      hsindex            : integer                      := 0;
      haddr              : integer                      := 0;
      hmask              : integer                      := 16#FF0#;
      hirq               : integer range 0 to NAHBIRQ-1 := 0;
      use_8b10b          : integer range 0 to 1         := 1;
      use_sep_txclk      : integer range 0 to 1         := 0;
      sel_16_20_bit_mode : integer range 0 to 1         := 0;
      ticks_2us          : natural range 1 to 2**13     := 125;
      tx_skip_freq       : natural range 1 to 2**13     := 5000;
      prbs_init1         : integer range 0 to 1         := 1;
      depth_rbuf_data    : natural range 1 to 32        := 8;
      depth_rbuf_fct     : natural range 1 to 32        := 4;
      depth_rbuf_bc      : natural range 1 to 32        := 8;
      num_vc             : integer range 1 to 32        := 4;
      fct_multiplier     : integer range 1 to 8         := 1;
      depth_vc_rx_buf    : natural range 1 to 32        := 10;
      depth_vc_tx_buf    : natural range 1 to 32        := 10;
      remote_fct_cnt_max : natural range 1 to 32        := 9;
      width_bw_credit    : natural                      := 20;
      min_bw_credit      : natural                      := 52428;
      idle_time_limit    : natural range 0 to 2**16-1   := 62500;
      num_dmach          : integer range 1 to 32        := 1;
      num_txdesc         : integer range 64 to 512      := 64;
      num_rxdesc         : integer range 128 to 1024    := 128;
      depth_dma_fifo     : integer range 16 to 256      := 32;
      depth_bc_fifo      : integer range 1 to 32        := 4);
    port (
      clk        : in  std_ulogic;
      rstn       : in  std_ulogic;
      spfi_clk   : in  std_ulogic;
      spfi_rstn  : in  std_ulogic;
      spfi_txclk : in  std_ulogic;
      bmi        : in  bm_in_vector_type(num_dmach-1 downto 0);
      bmo        : out bm_out_vector_type(num_dmach-1 downto 0);
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : out ahb_slv_out_type;
      spfii      : in  grspfi_in_type;
      spfio      : out grspfi_out_type);
  end component;

  component grspfi_ahb is
    generic (
      tech               : integer range 0 to NTECH     := inferred;
      hmindex            : integer                      := 0;
      hsindex            : integer                      := 0;
      haddr              : integer                      := 0;
      hmask              : integer                      := 16#FF0#;
      hirq               : integer range 0 to NAHBIRQ-1 := 0;
      use_8b10b          : integer range 0 to 1         := 1;
      use_sep_txclk      : integer range 0 to 1         := 0;
      sel_16_20_bit_mode : integer range 0 to 1         := 0;
      ticks_2us          : natural range 1 to 2**13     := 125;
      tx_skip_freq       : natural range 1 to 2**13     := 5000;
      prbs_init1         : integer range 0 to 1         := 1;
      depth_rbuf_data    : natural range 1 to 32        := 8;
      depth_rbuf_fct     : natural range 1 to 32        := 4;
      depth_rbuf_bc      : natural range 1 to 32        := 8;
      num_vc             : integer range 1 to 32        := 4;
      fct_multiplier     : integer range 1 to 8         := 1;
      depth_vc_rx_buf    : natural range 1 to 32        := 10;
      depth_vc_tx_buf    : natural range 1 to 32        := 10;
      remote_fct_cnt_max : natural range 1 to 32        := 9;
      width_bw_credit    : natural                      := 20;
      min_bw_credit      : natural                      := 52428;
      idle_time_limit    : natural range 0 to 2**16-1   := 62500;
      num_dmach          : integer range 1 to 32        := 1;
      num_txdesc         : integer range 64 to 512      := 64;
      num_rxdesc         : integer range 128 to 1024    := 128;
      depth_dma_fifo     : integer range 16 to 256      := 32;
      depth_bc_fifo      : integer range 1 to 32        := 4);
    port (
      clk        : in  std_ulogic;
      rstn       : in  std_ulogic;
      spfi_clk   : in  std_ulogic;
      spfi_rstn  : in  std_ulogic;
      spfi_txclk : in  std_ulogic;
      ahbmi      : in  ahb_mst_in_type;
      ahbmo      : out ahb_mst_out_vector_type(num_dmach-1 downto 0);
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : out ahb_slv_out_type;
      spfii      : in  grspfi_in_type;
      spfio      : out grspfi_out_type);
  end component;

end package;
