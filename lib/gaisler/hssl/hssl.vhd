------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
library grlib;
use grlib.amba.all;
library techmap;
use techmap.gencomp.all;

package hssl is

  -------------------------------------------------------------------------------
  -- Constants
  -------------------------------------------------------------------------------

  -- SpaceFibre constants

  constant SPFI_EOP  : std_logic_vector(7 downto 0) := X"FD";
  constant SPFI_EEP  : std_logic_vector(7 downto 0) := X"FE";
  constant SPFI_FILL : std_logic_vector(7 downto 0) := X"FB";

  -- SpaceWire constants

  constant SPW_EOP : std_logic_vector(7 downto 0) := X"02";
  constant SPW_EEP : std_logic_vector(7 downto 0) := X"01";

  -------------------------------------------------------------------------------
  -- Types and records
  -------------------------------------------------------------------------------

  type grhssl_in_type is record
    rx_clk    : std_ulogic;
    rx_data   : std_logic_vector(39 downto 0);
    rx_kflags : std_logic_vector(3 downto 0);
    rx_serror : std_logic_vector(3 downto 0);
    no_signal : std_ulogic;
  end record;

  constant GRHSSL_IN_NULL : grhssl_in_type := (
    rx_clk    => '0',
    rx_data   => (others => '0'),
    rx_kflags => (others => '0'),
    rx_serror => (others => '0'),
    no_signal => '1'
    );

  type grhssl_out_type is record
    tx_data       : std_logic_vector(39 downto 0);
    tx_kflags     : std_logic_vector(3 downto 0);
    tx_en         : std_ulogic;
    rx_en         : std_ulogic;
    inv_pol       : std_ulogic;
    tx_data_dbg   : std_logic_vector(31 downto 0);
    tx_kflags_dbg : std_logic_vector(3 downto 0);
    rx_data_dbg   : std_logic_vector(31 downto 0);
    rx_kflags_dbg : std_logic_vector(3 downto 0);
  end record;

  constant GRHSSL_OUT_NULL : grhssl_out_type := (
    tx_data       => (others => '0'),
    tx_kflags     => (others => '0'),
    tx_en         => '0',
    rx_en         => '0',
    inv_pol       => '0',
    tx_data_dbg   => (others => '0'),
    tx_kflags_dbg => (others => '0'),
    rx_data_dbg   => (others => '0'),
    rx_kflags_dbg => (others => '0')
    );

  type grhssl_in_type_vector is array (natural range <>) of grhssl_in_type;
  type grhssl_out_type_vector is array (natural range <>) of grhssl_out_type;

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
    -- Endianness
    endian       : std_logic;
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

  type grhssl_defcfg_type is record
    rmapen   : std_ulogic;
    nodeaddr : std_logic_vector(7 downto 0);
  end record;

  constant grhssl_defcfg_none : grhssl_defcfg_type := (
    rmapen   => '0',
    nodeaddr => (others => '0')
    );

  type extvc_in_type is record
    tx_data   : std_logic_vector(31 downto 0);
    tx_kflags : std_logic_vector(3 downto 0);
    tx_wen    : std_ulogic;
    rx_ren    : std_ulogic;
  end record;

  type extvc_out_type is record
    tx_full   : std_ulogic;
    rx_data   : std_logic_vector(31 downto 0);
    rx_kflags : std_logic_vector(3 downto 0);
    rx_valid  : std_ulogic;
  end record;

  type extbc_in_type is record
    tx_data    : std_logic_vector(63 downto 0);
    tx_channel : std_logic_vector(7 downto 0);
    tx_btype   : std_logic_vector(7 downto 0);
    tx_delayed : std_ulogic;
    tx_late    : std_ulogic;
    tx_wen     : std_ulogic;
  end record;

  type extbc_out_type is record
    tx_ack     : std_ulogic;
    rx_data    : std_logic_vector(63 downto 0);
    rx_channel : std_logic_vector(7 downto 0);
    rx_btype   : std_logic_vector(7 downto 0);
    rx_valid   : std_ulogic;
    rx_delayed : std_ulogic;
    rx_late    : std_ulogic;
  end record;

  constant extvc_none : extvc_in_type := (
    tx_data   => (others => '0'),
    tx_kflags => (others => '0'),
    tx_wen    => '0',
    rx_ren    => '0'
    );

  constant extbc_none : extbc_in_type := (
    tx_data    => (others => '0'),
    tx_channel => (others => '0'),
    tx_btype   => (others => '0'),
    tx_delayed => '0',
    tx_late    => '0',
    tx_wen     => '0'
    );

  type extvc_in_arr_type is array (0 to 31) of extvc_in_type;
  type extvc_out_arr_type is array (0 to 31) of extvc_out_type;

  type spfi_spwdata_br_in_type is record
    spfi         : extvc_out_type;
    spw_txfull   : std_ulogic;
    spw_txafull  : std_ulogic;
    spw_rxchar   : std_logic_vector(8 downto 0);
    spw_rxcharav : std_ulogic;
    spw_rxaempty : std_ulogic;
  end record;

  type spfi_spwdata_br_out_type is record
    spfi        : extvc_in_type;
    spw_txchar  : std_logic_vector(8 downto 0);
    spw_txwrite : std_ulogic;
    spw_rxread  : std_ulogic;
  end record;

  type spfi_spwdata_br_in_arr_type is array (natural range <>) of spfi_spwdata_br_in_type;
  type spfi_spwdata_br_out_arr_type is array (natural range <>) of spfi_spwdata_br_out_type;

  type spfi_spwtc_br_in_type is record
    spfi        : extbc_out_type;
    spw_tickout : std_ulogic;
    spw_timeout : std_logic_vector(7 downto 0);
    map_bctype  : std_logic_vector(7 downto 0);  -- Broadcast type for time-codes
    map_bcmask  : std_logic_vector(7 downto 0);  -- Broadcast type mask for time-codes
    map_bcsel   : std_logic_vector(2 downto 0);  -- Broadcast byte selector for time-codes
  end record;

  type spfi_spwtc_br_out_type is record
    spfi       : extbc_in_type;
    spw_tickin : std_ulogic;
    spw_timein : std_logic_vector(7 downto 0);
  end record;

  type spfi_spwtc_br_in_arr_type is array (natural range <>) of spfi_spwtc_br_in_type;
  type spfi_spwtc_br_out_arr_type is array (natural range <>) of spfi_spwtc_br_out_type;


  -------------------------------------------------------------------------------
  -- Components
  -------------------------------------------------------------------------------

  component grspfi_codec is
    generic (
      tech               : integer range 0 to NTECH := 0;
      use_8b10b          : integer range 0 to 1     := 1;
      use_sep_txclk      : integer range 0 to 1     := 0;
      sel_16_20_bit_mode : integer range 0 to 1     := 0;
      ticks_2us          : integer range 1 to 8192  := 125;
      tx_skip_freq       : integer range 1 to 8192  := 5000;
      prbs_init1         : integer range 0 to 1     := 1;
      depth_rbuf_data    : integer range 1 to 32    := 8;
      depth_rbuf_fct     : integer range 1 to 32    := 4;
      depth_rbuf_bc      : integer range 1 to 32    := 8;
      num_vc             : integer range 1 to 32    := 4;
      fct_multiplier     : integer range 1 to 8     := 1;
      depth_vc_rx_buf    : integer range 1 to 32    := 10;
      depth_vc_tx_buf    : integer range 1 to 32    := 10;
      remote_fct_cnt_max : integer range 1 to 32    := 9;
      width_bw_credit    : natural                  := 20;
      min_bw_credit      : natural                  := 52428;
      idle_time_limit    : integer range 0 to 65535 := 62500;
      use_async_rxrst    : integer range 0 to 1     := 0;
      ft_vc              : integer range 0 to 5     := 0;
      ft_rt1             : integer range 0 to 5     := 0;
      ft_rt2             : integer range 0 to 5     := 0;
      ft_if              : integer range 0 to 5     := 0;
      scantest           : integer range 0 to 1     := 0);
    port (
      clk                  : in  std_logic;
      tx_clk               : in  std_logic;
      rst                  : in  std_logic;
      -- virtual channel interface
      vc_tx_full           : out std_logic_vector(num_vc-1 downto 0);
      vc_rx_data           : out std_logic_vector(32*num_vc-1 downto 0);
      vc_rx_kflags         : out std_logic_vector(4*num_vc-1 downto 0);
      vc_rx_valid          : out std_logic_vector(num_vc-1 downto 0);
      vc_rx_ren            : in  std_logic_vector(num_vc-1 downto 0);
      vc_tx_data           : in  std_logic_vector(32*num_vc-1 downto 0);
      vc_tx_kflags         : in  std_logic_vector(4*num_vc-1 downto 0);
      vc_tx_wen            : in  std_logic_vector(num_vc-1 downto 0);
      vc_tx_timeslot       : in  std_logic_vector(5 downto 0);
      -- broadcast interface
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
      -- serdes interface
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
      -- configuration registers
      cf_reset             : out std_logic;
      cf_vc_priorities     : in  std_logic_vector(4*num_vc-1 downto 0);
      cf_vc_expected_bw    : in  std_logic_vector(16*num_vc-1 downto 0);
      cf_vc_tslot_vecs     : in  std_logic_vector(64*num_vc-1 downto 0);
      cf_bc_expected_bw    : in  std_logic_vector(15 downto 0);
      cf_data_scr_en       : in  std_logic;
      cf_link_rst          : in  std_logic;
      cf_lane_start        : in  std_logic;
      cf_auto_start        : in  std_logic;
      cf_lane_rst          : in  std_logic;
      cf_loopback          : in  std_logic;
      cf_standby_reason    : in  std_logic_vector(7 downto 0);
      -- status registers
      sr_bw_over_use       : out std_logic_vector(num_vc-1 downto 0);
      sr_bw_under_use      : out std_logic_vector(num_vc-1 downto 0);
      sr_dest_has_credit   : out std_logic_vector(num_vc-1 downto 0);
      sr_input_buf_ov      : out std_logic_vector(num_vc-1 downto 0);
      sr_fct_cnt_ov        : out std_logic_vector(num_vc-1 downto 0);
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
      sr_rx_polarity       : out std_logic;
      -- scan test
      testen               : in  std_logic := '0';
      testrst              : in  std_logic := '0';
      testin               : in  std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
      );
  end component grspfi_codec;

  component grwizl_codec is
    generic (
      tech               : integer range 0 to NTECH := 0;
      use_8b10b          : integer range 0 to 1     := 1;
      use_sep_txclk      : integer range 0 to 1     := 0;
      sel_16_20_bit_mode : integer range 0 to 1     := 0;
      use_async_rxrst    : integer range 0 to 1     := 0;
      depth_tx_buf       : integer range 1 to 32    := 10;
      depth_rx_buf       : integer range 1 to 32    := 10;
      ft_buf             : integer range 0 to 5     := 0;
      ft_if              : integer range 0 to 5     := 0;
      scantest           : integer range 0 to 1     := 0);
    port (
      clk              : in  std_logic;
      tx_clk           : in  std_logic;
      rstn             : in  std_logic;
      -- Register interface
      cfg_tx_en        : in  std_ulogic;
      cfg_rx_en        : in  std_ulogic;
      cfg_loopback     : in  std_ulogic;
      cfg_comma        : in  std_logic_vector(7 downto 0);
      cfg_idle         : in  std_logic_vector(35 downto 0);
      cfg_idle_cnt     : in  std_logic_vector(15 downto 0);
      sts_rxerr_cnt    : out std_logic_vector(7 downto 0);
      sts_rxerr_cnt_of : out std_ulogic;
      sts_rx_overrun   : out std_ulogic;
      -- Host interface
      host_tx_data     : in  std_logic_vector(31 downto 0);
      host_tx_kflags   : in  std_logic_vector(3 downto 0);
      host_tx_wen      : in  std_ulogic;
      host_tx_full     : out std_ulogic;
      host_rx_ren      : in  std_ulogic;
      host_rx_data     : out std_logic_vector(31 downto 0);
      host_rx_kflags   : out std_logic_vector(3 downto 0);
      host_rx_valid    : out std_ulogic;
      -- SerDes interface
      se_tx_data       : out std_logic_vector(39 downto 0);
      se_tx_kflags     : out std_logic_vector(3 downto 0);
      se_tx_en         : out std_logic;
      se_rx_en         : out std_logic;
      se_inv_pol       : out std_logic;
      se_rx_clk        : in  std_logic;
      se_rx_data       : in  std_logic_vector(39 downto 0);
      se_rx_kflags     : in  std_logic_vector(3 downto 0);
      se_rx_serror     : in  std_logic_vector(3 downto 0);
      se_no_signal     : in  std_logic;
      -- Scan test
      testen           : in  std_logic := '0';
      testrst          : in  std_logic := '0';
      testin           : in  std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
      );
  end component grwizl_codec;

  component grhssl is
    generic (
      tech               : integer range 0 to NTECH     := inferred;
      hsindex            : integer                      := 0;
      haddr_spfi         : integer                      := 0;
      hmask_spfi         : integer                      := 16#FF0#;
      haddr_wizl         : integer                      := 0;
      hmask_wizl         : integer                      := 16#FFF#;
      hirq               : integer range 0 to NAHBIRQ-1 := 0;
      use_8b10b          : integer range 0 to 1         := 1;
      use_sep_txclk      : integer range 0 to 1         := 0;
      sel_16_20_bit_mode : integer range 0 to 1         := 0;
      ticks_2us          : integer range 1 to 8192      := 125;
      tx_skip_freq       : integer range 1 to 8192      := 5000;
      prbs_init1         : integer range 0 to 1         := 1;
      depth_rbuf_data    : integer range 1 to 32        := 8;
      depth_rbuf_fct     : integer range 1 to 32        := 4;
      depth_rbuf_bc      : integer range 1 to 32        := 8;
      num_vc             : integer range 1 to 32        := 4;
      fct_multiplier     : integer range 1 to 8         := 1;
      depth_vc_rx_buf    : integer range 1 to 32        := 10;
      depth_vc_tx_buf    : integer range 1 to 32        := 10;
      remote_fct_cnt_max : integer range 1 to 32        := 9;
      width_bw_credit    : natural                      := 20;
      min_bw_credit      : natural                      := 52428;
      idle_time_limit    : integer range 0 to 65535     := 62500;
      num_dmach          : integer range 1 to 8         := 1;
      num_txdesc         : integer range 64 to 512      := 64;
      num_rxdesc         : integer range 128 to 1024    := 128;
      depth_dma_fifo     : integer range 16 to 256      := 32;
      depth_bc_fifo      : integer range 1 to 32        := 4;
      depth_wizl_tx_buf  : integer range 1 to 32        := 10;
      depth_wizl_rx_buf  : integer range 1 to 32        := 10;
      use_async_rxrst    : integer range 0 to 1         := 0;
      ft_core_vc         : integer range 0 to 5         := 0;
      ft_core_rt1        : integer range 0 to 5         := 0;
      ft_core_rt2        : integer range 0 to 5         := 0;
      ft_core_if         : integer range 0 to 5         := 0;
      ft_dma_data        : integer range 0 to 5         := 0;
      ft_dma_bc          : integer range 0 to 5         := 0;
      scantest           : integer range 0 to 1         := 0;
      spfi               : integer range 0 to 1         := 1;
      wizl               : integer range 0 to 1         := 0;
      rmap               : integer range 0 to 1         := 0;
      rmapcrc            : integer range 0 to 1         := 0;
      ccsdscrc           : integer range 0 to 1         := 0;
      nodeaddr           : integer range 0 to 255       := 254;
      destkey            : integer range 0 to 255       := 0;
      numextvc           : integer range 0 to 32        := 0;
      numextbc           : integer range 0 to 1         := 0;
      numextwc           : integer range 0 to 1         := 0);
    port (
      clk        : in  std_ulogic;
      rstn       : in  std_ulogic;
      core_clk   : in  std_ulogic;
      core_rstn  : in  std_ulogic;
      core_txclk : in  std_ulogic;
      -- Generic bus master interface
      bmi        : in  bm_in_vector_type(num_dmach-1 downto 0);
      bmo        : out bm_out_vector_type(num_dmach-1 downto 0);
      -- AHB slave interface
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : out ahb_slv_out_type;
      -- Serdes interface
      hssli      : in  grhssl_in_type;
      hsslo      : out grhssl_out_type;
      -- Default IP configuration
      cfg        : in  grhssl_defcfg_type  := grhssl_defcfg_none;
      -- External VC/BC/WC interface
      extvci     : in  extvc_in_arr_type   := (others => extvc_none);
      extvco     : out extvc_out_arr_type;
      extbci     : in  extbc_in_type       := extbc_none;
      extbco     : out extbc_out_type;
      extwci     : in  extvc_in_type       := extvc_none;
      extwco     : out extvc_out_type
      );
  end component grhssl;

  component grhssl_ahb is
    generic (
      tech               : integer range 0 to NTECH     := inferred;
      hmindex            : integer                      := 0;
      hsindex            : integer                      := 0;
      haddr_spfi         : integer                      := 0;
      hmask_spfi         : integer                      := 16#FF0#;
      haddr_wizl         : integer                      := 0;
      hmask_wizl         : integer                      := 16#FFF#;
      hirq               : integer range 0 to NAHBIRQ-1 := 0;
      use_8b10b          : integer range 0 to 1         := 1;
      use_sep_txclk      : integer range 0 to 1         := 0;
      sel_16_20_bit_mode : integer range 0 to 1         := 0;
      ticks_2us          : integer range 1 to 8192      := 125;
      tx_skip_freq       : integer range 1 to 8192      := 5000;
      prbs_init1         : integer range 0 to 1         := 1;
      depth_rbuf_data    : integer range 1 to 32        := 8;
      depth_rbuf_fct     : integer range 1 to 32        := 4;
      depth_rbuf_bc      : integer range 1 to 32        := 8;
      num_vc             : integer range 1 to 32        := 4;
      fct_multiplier     : integer range 1 to 8         := 1;
      depth_vc_rx_buf    : integer range 1 to 32        := 10;
      depth_vc_tx_buf    : integer range 1 to 32        := 10;
      remote_fct_cnt_max : integer range 1 to 32        := 9;
      width_bw_credit    : natural                      := 20;
      min_bw_credit      : natural                      := 52428;
      idle_time_limit    : integer range 0 to 65535     := 62500;
      num_dmach          : integer range 1 to 8         := 1;
      num_txdesc         : integer range 64 to 512      := 64;
      num_rxdesc         : integer range 128 to 1024    := 128;
      depth_dma_fifo     : integer range 16 to 256      := 32;
      depth_bc_fifo      : integer range 1 to 32        := 4;
      depth_wizl_tx_buf  : integer range 1 to 32        := 10;
      depth_wizl_rx_buf  : integer range 1 to 32        := 10;
      incr_hmindex       : integer range 0 to 1         := 1;
      use_async_rxrst    : integer range 0 to 1         := 0;
      ft_core_vc         : integer range 0 to 5         := 0;
      ft_core_rt1        : integer range 0 to 5         := 0;
      ft_core_rt2        : integer range 0 to 5         := 0;
      ft_core_if         : integer range 0 to 5         := 0;
      ft_dma_data        : integer range 0 to 5         := 0;
      ft_dma_bc          : integer range 0 to 5         := 0;
      scantest           : integer range 0 to 1         := 0;
      ahbbits            : integer                      := AHBDW;
      spfi               : integer range 0 to 1         := 1;
      wizl               : integer range 0 to 1         := 0;
      rmap               : integer range 0 to 1         := 0;
      rmapcrc            : integer range 0 to 1         := 0;
      ccsdscrc           : integer range 0 to 1         := 0;
      nodeaddr           : integer range 0 to 255       := 254;
      destkey            : integer range 0 to 255       := 0;
      numextvc           : integer range 0 to 32        := 0;
      numextbc           : integer range 0 to 1         := 0;
      numextwc           : integer range 0 to 1         := 0);
    port (
      clk        : in  std_ulogic;
      rstn       : in  std_ulogic;
      core_clk   : in  std_ulogic;
      core_rstn  : in  std_ulogic;
      core_txclk : in  std_ulogic;
      -- AHB interface
      ahbmi      : in  ahb_mst_in_vector_type(num_dmach-1 downto 0);
      ahbmo      : out ahb_mst_out_vector_type(num_dmach-1 downto 0);
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : out ahb_slv_out_type;
      -- Serdes interface
      hssli      : in  grhssl_in_type;
      hsslo      : out grhssl_out_type;
      -- Default IP configuration
      cfg        : in  grhssl_defcfg_type  := grhssl_defcfg_none;
      -- External VC/BC/WC interface
      extvci     : in  extvc_in_arr_type   := (others => extvc_none);
      extvco     : out extvc_out_arr_type;
      extbci     : in  extbc_in_type       := extbc_none;
      extbco     : out extbc_out_type;
      extwci     : in  extvc_in_type       := extvc_none;
      extwco     : out extvc_out_type
      );
  end component grhssl_ahb;

  component grhssl_axi is
    generic (
      tech               : integer range 0 to NTECH     := inferred;
      hsindex            : integer                      := 0;
      haddr_spfi         : integer                      := 0;
      hmask_spfi         : integer                      := 16#FF0#;
      haddr_wizl         : integer                      := 0;
      hmask_wizl         : integer                      := 16#FFF#;
      hirq               : integer range 0 to NAHBIRQ-1 := 0;
      use_8b10b          : integer range 0 to 1         := 1;
      use_sep_txclk      : integer range 0 to 1         := 0;
      sel_16_20_bit_mode : integer range 0 to 1         := 0;
      ticks_2us          : integer range 1 to 8192      := 125;
      tx_skip_freq       : integer range 1 to 8192      := 5000;
      prbs_init1         : integer range 0 to 1         := 1;
      depth_rbuf_data    : integer range 1 to 32        := 8;
      depth_rbuf_fct     : integer range 1 to 32        := 4;
      depth_rbuf_bc      : integer range 1 to 32        := 8;
      num_vc             : integer range 1 to 32        := 4;
      fct_multiplier     : integer range 1 to 8         := 1;
      depth_vc_rx_buf    : integer range 1 to 32        := 10;
      depth_vc_tx_buf    : integer range 1 to 32        := 10;
      remote_fct_cnt_max : integer range 1 to 32        := 9;
      width_bw_credit    : natural                      := 20;
      min_bw_credit      : natural                      := 52428;
      idle_time_limit    : integer range 0 to 65535     := 62500;
      num_dmach          : integer range 1 to 8         := 1;
      num_txdesc         : integer range 64 to 512      := 64;
      num_rxdesc         : integer range 128 to 1024    := 128;
      depth_dma_fifo     : integer range 16 to 256      := 32;
      depth_bc_fifo      : integer range 1 to 32        := 4;
      depth_wizl_tx_buf  : integer range 1 to 32        := 10;
      depth_wizl_rx_buf  : integer range 1 to 32        := 10;
      use_async_rxrst    : integer range 0 to 1         := 0;
      ft_core_vc         : integer range 0 to 5         := 0;
      ft_core_rt1        : integer range 0 to 5         := 0;
      ft_core_rt2        : integer range 0 to 5         := 0;
      ft_core_if         : integer range 0 to 5         := 0;
      ft_dma_data        : integer range 0 to 5         := 0;
      ft_dma_bc          : integer range 0 to 5         := 0;
      scantest           : integer range 0 to 1         := 0;
      lendian            : integer range 0 to 1         := 1;
      spfi               : integer range 0 to 1         := 1;
      wizl               : integer range 0 to 1         := 0;
      rmap               : integer range 0 to 1         := 0;
      rmapcrc            : integer range 0 to 1         := 0;
      ccsdscrc           : integer range 0 to 1         := 0;
      nodeaddr           : integer range 0 to 255       := 254;
      destkey            : integer range 0 to 255       := 0;
      numextvc           : integer range 0 to 32        := 0;
      numextbc           : integer range 0 to 1         := 0;
      numextwc           : integer range 0 to 1         := 0);
    port (
      clk        : in  std_ulogic;
      rstn       : in  std_ulogic;
      core_clk   : in  std_ulogic;
      core_rstn  : in  std_ulogic;
      core_txclk : in  std_ulogic;
      -- AXI interface
      aximi      : in  axi_somi_vector_type(num_dmach-1 downto 0);
      aximo      : out axi4_mosi_vector_type(num_dmach-1 downto 0);
      -- AHB interface
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : out ahb_slv_out_type;
      -- Serdes interface
      hssli      : in  grhssl_in_type;
      hsslo      : out grhssl_out_type;
      -- Default IP configuration
      cfg        : in  grhssl_defcfg_type  := grhssl_defcfg_none;
      -- External VC/BC/WC interface
      extvci     : in  extvc_in_arr_type   := (others => extvc_none);
      extvco     : out extvc_out_arr_type;
      extbci     : in  extbc_in_type       := extbc_none;
      extbco     : out extbc_out_type;
      extwci     : in  extvc_in_type       := extvc_none;
      extwco     : out extvc_out_type
      );
  end component grhssl_axi;

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
      ticks_2us          : integer range 1 to 8192      := 125;
      tx_skip_freq       : integer range 1 to 8192      := 5000;
      prbs_init1         : integer range 0 to 1         := 1;
      depth_rbuf_data    : integer range 1 to 32        := 8;
      depth_rbuf_fct     : integer range 1 to 32        := 4;
      depth_rbuf_bc      : integer range 1 to 32        := 8;
      num_vc             : integer range 1 to 32        := 4;
      fct_multiplier     : integer range 1 to 8         := 1;
      depth_vc_rx_buf    : integer range 1 to 32        := 10;
      depth_vc_tx_buf    : integer range 1 to 32        := 10;
      remote_fct_cnt_max : integer range 1 to 32        := 9;
      width_bw_credit    : natural                      := 20;
      min_bw_credit      : natural                      := 52428;
      idle_time_limit    : integer range 0 to 65535     := 62500;
      num_dmach          : integer range 1 to 8         := 1;
      num_txdesc         : integer range 64 to 512      := 64;
      num_rxdesc         : integer range 128 to 1024    := 128;
      depth_dma_fifo     : integer range 16 to 256      := 32;
      depth_bc_fifo      : integer range 1 to 32        := 4;
      incr_hmindex       : integer range 0 to 1         := 1;
      use_async_rxrst    : integer range 0 to 1         := 0;
      ft_core_vc         : integer range 0 to 5         := 0;
      ft_core_rt1        : integer range 0 to 5         := 0;
      ft_core_rt2        : integer range 0 to 5         := 0;
      ft_core_if         : integer range 0 to 5         := 0;
      ft_dma_data        : integer range 0 to 5         := 0;
      ft_dma_bc          : integer range 0 to 5         := 0;
      scantest           : integer range 0 to 1         := 0;
      ahbbits            : integer                      := AHBDW;
      rmap               : integer range 0 to 1         := 0;
      rmapcrc            : integer range 0 to 1         := 0;
      ccsdscrc           : integer range 0 to 1         := 0;
      nodeaddr           : integer range 0 to 255       := 254;
      destkey            : integer range 0 to 255       := 0;
      numextvc           : integer range 0 to 32        := 0;
      numextbc           : integer range 0 to 1         := 0);
    port (
      clk        : in  std_ulogic;
      rstn       : in  std_ulogic;
      spfi_clk   : in  std_ulogic;
      spfi_rstn  : in  std_ulogic;
      spfi_txclk : in  std_ulogic;
      -- AHB interface
      ahbmi      : in  ahb_mst_in_vector_type(num_dmach-1 downto 0);
      ahbmo      : out ahb_mst_out_vector_type(num_dmach-1 downto 0);
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : out ahb_slv_out_type;
      -- Serdes interface
      spfii      : in  grhssl_in_type;
      spfio      : out grhssl_out_type;
      -- Default IP configuration
      cfg        : in  grhssl_defcfg_type  := grhssl_defcfg_none;
      -- External VC/BC interface
      extvci     : in  extvc_in_arr_type   := (others => extvc_none);
      extvco     : out extvc_out_arr_type;
      extbci     : in  extbc_in_type       := extbc_none;
      extbco     : out extbc_out_type
      );
  end component grspfi_ahb;

  component grspfi_axi is
    generic (
      tech               : integer range 0 to NTECH     := inferred;
      hsindex            : integer                      := 0;
      haddr              : integer                      := 0;
      hmask              : integer                      := 16#FF0#;
      hirq               : integer range 0 to NAHBIRQ-1 := 0;
      use_8b10b          : integer range 0 to 1         := 1;
      use_sep_txclk      : integer range 0 to 1         := 0;
      sel_16_20_bit_mode : integer range 0 to 1         := 0;
      ticks_2us          : integer range 1 to 8192      := 125;
      tx_skip_freq       : integer range 1 to 8192      := 5000;
      prbs_init1         : integer range 0 to 1         := 1;
      depth_rbuf_data    : integer range 1 to 32        := 8;
      depth_rbuf_fct     : integer range 1 to 32        := 4;
      depth_rbuf_bc      : integer range 1 to 32        := 8;
      num_vc             : integer range 1 to 32        := 4;
      fct_multiplier     : integer range 1 to 8         := 1;
      depth_vc_rx_buf    : integer range 1 to 32        := 10;
      depth_vc_tx_buf    : integer range 1 to 32        := 10;
      remote_fct_cnt_max : integer range 1 to 32        := 9;
      width_bw_credit    : natural                      := 20;
      min_bw_credit      : natural                      := 52428;
      idle_time_limit    : integer range 0 to 65535     := 62500;
      num_dmach          : integer range 1 to 8         := 1;
      num_txdesc         : integer range 64 to 512      := 64;
      num_rxdesc         : integer range 128 to 1024    := 128;
      depth_dma_fifo     : integer range 16 to 256      := 32;
      depth_bc_fifo      : integer range 1 to 32        := 4;
      use_async_rxrst    : integer range 0 to 1         := 0;
      ft_core_vc         : integer range 0 to 5         := 0;
      ft_core_rt1        : integer range 0 to 5         := 0;
      ft_core_rt2        : integer range 0 to 5         := 0;
      ft_core_if         : integer range 0 to 5         := 0;
      ft_dma_data        : integer range 0 to 5         := 0;
      ft_dma_bc          : integer range 0 to 5         := 0;
      scantest           : integer range 0 to 1         := 0;
      lendian            : integer range 0 to 1         := 1;
      rmap               : integer range 0 to 1         := 0;
      rmapcrc            : integer range 0 to 1         := 0;
      ccsdscrc           : integer range 0 to 1         := 0;
      nodeaddr           : integer range 0 to 255       := 254;
      destkey            : integer range 0 to 255       := 0;
      numextvc           : integer range 0 to 32        := 0;
      numextbc           : integer range 0 to 1         := 0);
    port (
      clk        : in  std_ulogic;
      rstn       : in  std_ulogic;
      spfi_clk   : in  std_ulogic;
      spfi_rstn  : in  std_ulogic;
      spfi_txclk : in  std_ulogic;
      -- AXI interface
      aximi      : in  axi_somi_vector_type(num_dmach-1 downto 0);
      aximo      : out axi4_mosi_vector_type(num_dmach-1 downto 0);
      -- AHB interface
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : out ahb_slv_out_type;
      -- Serdes interface
      spfii      : in  grhssl_in_type;
      spfio      : out grhssl_out_type;
      -- Default IP configuration
      cfg        : in  grhssl_defcfg_type  := grhssl_defcfg_none;
      -- External VC/BC interface
      extvci     : in  extvc_in_arr_type   := (others => extvc_none);
      extvco     : out extvc_out_arr_type;
      extbci     : in  extbc_in_type       := extbc_none;
      extbco     : out extbc_out_type
      );
  end component grspfi_axi;

  component grwizl_ahb is
    generic (
      tech               : integer range 0 to NTECH     := inferred;
      hmindex            : integer                      := 0;
      hsindex            : integer                      := 0;
      haddr              : integer                      := 0;
      hmask              : integer                      := 16#FFF#;
      hirq               : integer range 0 to NAHBIRQ-1 := 0;
      use_8b10b          : integer range 0 to 1         := 1;
      use_sep_txclk      : integer range 0 to 1         := 0;
      sel_16_20_bit_mode : integer range 0 to 1         := 0;
      num_txdesc         : integer range 64 to 512      := 64;
      num_rxdesc         : integer range 128 to 1024    := 128;
      depth_dma_fifo     : integer range 16 to 256      := 32;
      depth_tx_buf       : integer range 1 to 32        := 10;
      depth_rx_buf       : integer range 1 to 32        := 10;
      use_async_rxrst    : integer range 0 to 1         := 0;
      ft_core_buf        : integer range 0 to 5         := 0;
      ft_core_if         : integer range 0 to 5         := 0;
      ft_dma             : integer range 0 to 5         := 0;
      scantest           : integer range 0 to 1         := 0;
      ahbbits            : integer                      := AHBDW;
      numextwc           : integer range 0 to 1         := 0);
    port (
      clk        : in  std_ulogic;
      rstn       : in  std_ulogic;
      wizl_clk   : in  std_ulogic;
      wizl_rstn  : in  std_ulogic;
      wizl_txclk : in  std_ulogic;
      -- AHB interface
      ahbmi      : in  ahb_mst_in_type;
      ahbmo      : out ahb_mst_out_type;
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : out ahb_slv_out_type;
      -- Serdes interface
      wizli      : in  grhssl_in_type;
      wizlo      : out grhssl_out_type;
      -- External WC interface
      extwci     : in  extvc_in_type       := extvc_none;
      extwco     : out extvc_out_type
      );
  end component grwizl_ahb;

  component grwizl_axi is
    generic (
      tech               : integer range 0 to NTECH     := inferred;
      hsindex            : integer                      := 0;
      haddr              : integer                      := 0;
      hmask              : integer                      := 16#FFF#;
      hirq               : integer range 0 to NAHBIRQ-1 := 0;
      use_8b10b          : integer range 0 to 1         := 1;
      use_sep_txclk      : integer range 0 to 1         := 0;
      sel_16_20_bit_mode : integer range 0 to 1         := 0;
      num_txdesc         : integer range 64 to 512      := 64;
      num_rxdesc         : integer range 128 to 1024    := 128;
      depth_dma_fifo     : integer range 16 to 256      := 32;
      depth_tx_buf       : integer range 1 to 32        := 10;
      depth_rx_buf       : integer range 1 to 32        := 10;
      use_async_rxrst    : integer range 0 to 1         := 0;
      ft_core_buf        : integer range 0 to 5         := 0;
      ft_core_if         : integer range 0 to 5         := 0;
      ft_dma             : integer range 0 to 5         := 0;
      scantest           : integer range 0 to 1         := 0;
      lendian            : integer range 0 to 1         := 1;
      numextwc           : integer range 0 to 1         := 0);
    port (
      clk        : in  std_ulogic;
      rstn       : in  std_ulogic;
      wizl_clk   : in  std_ulogic;
      wizl_rstn  : in  std_ulogic;
      wizl_txclk : in  std_ulogic;
      -- AXI interface
      aximi      : in  axi_somi_type;
      aximo      : out axi4_mosi_type;
      -- AHB interface
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : out ahb_slv_out_type;
      -- Serdes interface
      wizli      : in  grhssl_in_type;
      wizlo      : out grhssl_out_type;
      -- External WC interface
      extwci     : in  extvc_in_type       := extvc_none;
      extwco     : out extvc_out_type
      );
  end component grwizl_axi;

  component grspfi_spwdatabr is
    generic (
      tech : integer range 0 to NTECH := inferred;
      ft   : integer range 0 to 5     := 0);
    port (
      -- Clocks and resets
      clk       : in  std_ulogic;
      rstn      : in  std_ulogic;
      spfi_clk  : in  std_ulogic;
      spfi_rstn : in  std_ulogic;
      -- SpFi/SpW bridge interface
      bi        : in  spfi_spwdata_br_in_type;
      bo        : out spfi_spwdata_br_out_type
      );
  end component grspfi_spwdatabr;

  component grspfi_spwtcbr is
    generic (
      tech : integer range 0 to NTECH := inferred;
      ft   : integer range 0 to 5     := 0);
    port (
      -- Clocks and resets
      clk       : in  std_ulogic;
      rstn      : in  std_ulogic;
      spfi_clk  : in  std_ulogic;
      spfi_rstn : in  std_ulogic;
      -- SpFi/SpW Time-code bridge interface
      bi        : in  spfi_spwtc_br_in_type;
      bo        : out spfi_spwtc_br_out_type
      );
  end component grspfi_spwtcbr;

end package;
