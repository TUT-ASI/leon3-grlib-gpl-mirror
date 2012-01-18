------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
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
-- Package:     gr1553b_core
-- File:        gr1553b_core.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B internal components, types and functions.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.ahb_mst_in_type;
use grlib.amba.ahb_mst_out_type;
use grlib.amba.apb_slv_in_type;
use grlib.amba.apb_slv_out_type;
library gaisler;
use gaisler.gr1553b_pkg.all;

package gr1553b_core is

  constant gr1553b_version: integer := 0;
  constant gr1553b_cfgver: integer := 0;
  
  type gr1553b_word_type is (CMD_STAT, DATA);
  function wt_to_sl(wt: gr1553b_word_type) return std_logic;
  function sl_to_wt(sl: std_logic) return gr1553b_word_type;
  
  type gr1553b_word is record
    t: gr1553b_word_type;
    data: std_logic_vector(15 downto 0);
  end record;

  constant gr1553b_word_default: gr1553b_word :=
    (t => CMD_STAT, data => (others => '0'));
  
  function int_divide_round(i1,i2: integer) return integer;
  function mc_to_muxidx(code: std_logic_vector; bc: std_logic)
    return std_logic_vector;
  function mcmask_to_muxin(mask: std_logic_vector; bm: boolean; res: std_logic)
    return std_logic_vector;
  function modecode_valid(mc: std_logic_vector(4 downto 0); tr: std_logic)
    return boolean;

  -----------------------------------------------------------------------------
  -- DMA interface
  -----------------------------------------------------------------------------

  type gr1553b_dma2_in_bc is record
    -- Commands
    writestat: std_logic;
    writeirq: std_logic;
    getcmd: std_logic;
    -- State
    active: std_logic;
    desc_addr: std_logic_vector(31 downto 4);
    nextdesc_addr: std_logic_vector(31 downto 4);
    laststatus: std_logic_vector(31 downto 0);
    irqbuf_pos: std_logic_vector(31 downto 2);
    -- Data buffer handling
    data_reset: std_logic;
    need_data: std_logic;
    pull_data: std_logic;
    pushing_data: std_logic;
    push_data: std_logic;
    push_done: std_logic;
  end record;

  constant gr1553b_dma2_in_bc_zero: gr1553b_dma2_in_bc :=
    ('0','0','0','0',(others=>'0'),(others=>'0'),(others=>'0'),(others=>'0'),'0','0','0','0','0','0');
  
  type gr1553b_dma2_in_rt is record
    -- Commands
    read_satbl: std_logic;
    write_res: std_logic;
    write_log: std_logic;
    -- State
    tx_transfer: std_logic;
    tfr_legal: std_logic;
    autowrap: std_logic;
    do_log: std_logic;
    statusword: std_logic_vector(31 downto 0);
    satbl_addr: std_logic_vector(31 downto 4);
    logaddr: std_logic_vector(31 downto 2);
    logentry: std_logic_vector(31 downto 0);
    -- Data buffer handling
    data_reset: std_logic;
    need_data: std_logic;
    pull_data: std_logic;
    pushing_data: std_logic;
    push_data: std_logic;
    push_done: std_logic;
  end record;

  constant gr1553b_dma2_in_rt_zero: gr1553b_dma2_in_rt :=
    ('0','0','0','0','0','0','0',(others=>'0'),(others=>'0'),(others=>'0'),(others=>'0'),'0','0','0','0','0','0');

  type gr1553b_dma2_in_bm is record
    -- Commands
    write_data: std_logic;
    -- State
    ringbuf_addr: std_logic_vector(31 downto 3);
    logdata: std_logic_vector(63 downto 0);
  end record;

  constant gr1553b_dma2_in_bm_zero: gr1553b_dma2_in_bm :=
    ('0',(others=>'0'),(others=>'0'));
  
  type gr1553b_dma2_in is record
    bc: gr1553b_dma2_in_bc;
    rt: gr1553b_dma2_in_rt;
    bm: gr1553b_dma2_in_bm;
    pushdata: std_logic_vector(15 downto 0);
  end record;

  type gr1553b_dma2_out is record
    ready: std_logic;    
    bc_write_done: std_logic;
    bc_writeirq_done: std_logic;
    bc_desc0_valid: std_logic;
    bc_desc0_temp: std_logic_vector(31 downto 0);
    bc_desc1: std_logic_vector(31 downto 0);
    rt_satw0_valid: std_logic;    
    rt_satw0_temp: std_logic_vector(31 downto 0);
    rt_descw0_valid: std_logic;
    rt_descw0_temp: std_logic_vector(31 downto 0);
    rt_descptr_valid: std_logic;
    rt_break: std_logic;
    bm_progress: std_logic;    
    desc_dmaerror: std_logic;
    buf_dmaerror: std_logic;
    bufaddr_valid: std_logic;
    can_push: std_logic;
    can_pull: std_logic;
    pulldata: std_logic_vector(15 downto 0);
  end record;
  
  component gr1553b_dma2 is
    generic (
      hindex: integer;
      syncrst: integer range 0 to 2;
      endian: integer range 0 to 1;
      ahbreqreg: integer range 0 to 1
      );
    port (
      clk: in std_logic;
      rst: in std_logic;
      ahbmi: in ahb_mst_in_type;
      ahbmo: out ahb_mst_out_type;
      ins: in gr1553b_dma2_in;
      outs: out gr1553b_dma2_out
      );    
  end component;
  
  -----------------------------------------------------------------------------
  -- Codec
  -----------------------------------------------------------------------------
  
  type gr1553b_codec_in is record
    bussel: std_logic;
    anybus: std_logic;
    txstart: std_logic;
    txdata: gr1553b_word;
    txabort: std_logic;
  end record;

  constant gr1553b_codec_in_zero: gr1553b_codec_in := (
    bussel => '0', anybus => '0', txstart => '0',
    txdata => (t => CMD_STAT, data => (others=>'0')),
    txabort => '0');
  
  type gr1553b_codec_out is record
    txready: std_logic;
    txread_data: std_logic;
    lbdone: std_logic;
    lberror: std_logic;
    rxstarted: std_logic;
    rxerror: std_logic;
    rxdone: std_logic;
    rxword: gr1553b_word;
    rxbus: std_logic;
    rxact: std_logic;
  end record;

  constant gr1553b_codec_out_zero: gr1553b_codec_out := (
    txready => '1',
    txread_data => '0',
    lbdone => '0',
    lberror => '0',
    rxstarted => '0',
    rxerror => '0',
    rxdone => '1',
    rxword => gr1553b_word_default,
    rxbus => '0',
    rxact => '0');
  
  type gr1553b_bm_tap is record
    started_A: std_logic;
    datavalid_A: std_logic;
    lostsync_A: std_logic;
    badparity_A: std_logic;
    word_A: gr1553b_word;
    started_B: std_logic;
    datavalid_B: std_logic;
    lostsync_B: std_logic;
    badparity_B: std_logic;
    word_B: gr1553b_word;
  end record;
  
  component gr1553b_codec is
  generic(
    codec_clk_freq_mhz: integer;
    sameclk: integer range 0 to 1 := 1;
    rx_synclength: integer := 2;
    syncrst: integer range 0 to 2
  );
  port(
    clk: in std_logic;
    rst: in std_logic;
    ins: in gr1553b_codec_in;
    outs: out gr1553b_codec_out;
    bmtap: out gr1553b_bm_tap;    
    shutdownA: in std_logic;
    shutdownB: in std_logic;
    codec_clk: in std_logic;
    codec_rst: in std_logic;
    busA_tx_pos: out std_logic;
    busA_tx_neg: out std_logic;
    busA_rx_pos: in std_logic;
    busA_rx_neg: in std_logic;
    busB_tx_pos: out std_logic;
    busB_tx_neg: out std_logic;
    busB_rx_pos: in std_logic;
    busB_rx_neg: in std_logic
    );
  end component;

  -----------------------------------------------------------------------------
  -- Codec sub-parts
  -----------------------------------------------------------------------------
  
  type gr1553b_tx1_in is record
    abort: std_logic;
    start: std_logic;
    word: gr1553b_word;    
  end record;

  type gr1553b_tx1_out is record
    ready: std_logic;
    read_data: std_logic;
  end record;

  type gr1553b_tx2_in is record
    dv: std_logic;
    sync: std_logic;
    data: std_logic;
  end record;

  type gr1553b_tx2_out is record
    xread: std_logic;
    done: std_logic;
    -- Not forwarded by gr1553b_tx12sync
    -- Indicates that we're on the last half-us of the current bit    
    lasthus: std_logic;
    -- Indicates transmission is starting (done goes from 1->0)
    txstarting: std_logic;
  end record;
  
  component gr1553b_tx1 is
    generic (syncrst: integer range 0 to 2);
    port(
      clk: in std_logic;
      rst: in std_logic;
      seri: in gr1553b_tx1_in;
      sero: out gr1553b_tx1_out;
      biti: out gr1553b_tx2_in;
      bito: in gr1553b_tx2_out
      );
  end component;
  
  component gr1553b_tx2 is  
  generic (
    clk_freq_mhz: integer;
    txreg: boolean;
    syncrst: integer range 0 to 2
    );  
  port(
    clk: in std_logic;
    rst: in std_logic;
    biti: in gr1553b_tx2_in;
    bito: out gr1553b_tx2_out;
    txout_pos: out std_logic;
    txout_neg: out std_logic
    );
  end component;

  component gr1553b_tx12sync is
    generic (
      syncrst: integer range 0 to 2
      );
    port (
      ser_clk: in std_logic;
      ser_rst: in std_logic;
      ser_biti: in gr1553b_tx2_in;
      ser_bito: out gr1553b_tx2_out;
      out_clk: in std_logic;
      out_rst: in std_logic;
      out_bito: in gr1553b_tx2_out;
      out_biti: out gr1553b_tx2_in
      );
  end component;

  type gr1553b_rx2_out is record
    got_sync: std_logic;
    got_data: std_logic;
    dataval: std_logic;
    idle: std_logic;
    act: std_logic;
  end record;

  type gr1553b_rx2_fb is record
    syncblock: std_logic;
    gapblock: std_logic;
  end record;
  constant gr1553b_rx2_fb_none: gr1553b_rx2_fb := ('0','0');
  
  type gr1553b_rx3_out is record
    word: gr1553b_word;
    datavalid: std_logic;
    lostsync: std_logic;
    badparity: std_logic;
    started: std_logic;
  end record;
  
  component gr1553b_rx12v5 is
    generic (
      synclength: integer := 2;
      syncrst: integer range 0 to 2
      );
    port (
      clk: in std_logic;
      rst: in std_logic;
      
      rxin_p: in std_logic;
      rxin_n: in std_logic;
      
      outs: out gr1553b_rx2_out;
      fb:   in  gr1553b_rx2_fb;
      reinit: in std_logic
      );
  end component;
  
  component gr1553b_rx3 is
    generic (syncrst: integer range 0 to 2);
    port (
      clk: in std_logic;
      rst: in std_logic;
      abort: in std_logic;
      bito: in gr1553b_rx2_out;
      s3o: out gr1553b_rx3_out;
      s2fb: out gr1553b_rx2_fb
      );
  end component;

  component gr1553b_rx23sync is
    generic (syncrst: integer range 0 to 2);
    port (
      deser_clk: in std_logic;
      deser_rst: in std_logic;      
      deser_bito: out gr1553b_rx2_out;
      deser_fb: in gr1553b_rx2_fb;      
      bit_clk: in std_logic;
      bit_rst: in std_logic;
      bit_bito: in gr1553b_rx2_out;
      bit_fb: out gr1553b_rx2_fb      
      );
  end component;

  component gr1553b_loopback is
    generic (syncrst: integer range 0 to 2);
    port (
      clk: in std_logic;
      rst: in std_logic;
      rxo: in gr1553b_rx2_out;
      txi: in gr1553b_tx1_in;
      txo: in gr1553b_tx1_out;
      lberror: out std_logic;
      lbdone: out std_logic;
      lbread_data: out std_logic;
      lbdata_valid: out std_logic;
      gapblock: out std_logic
      );
  end component;

  -----------------------------------------------------------------------------
  -- Bus controller components
  -----------------------------------------------------------------------------

  -- Different parts of transfer descriptor
  -- Descriptor word #0
  constant D0_COND: integer := 31;
  constant D0_WAITTRIG_b: integer := 30;
  constant D0_NOASYNC_b: integer := 29;
  constant D0_INTONERR_b: integer := 28;
  constant D0_INTAFTER_b: integer := 27;  
  constant D0_PAUSEONERR_b: integer := 26;
  constant D0_PAUSEAFTER_b: integer := 25;
  constant D0_RETMODE_MSb: integer := 24;
  constant D0_RETMODE_LSb: integer := 23;
  constant D0_RETCOUNT_MSb: integer := 22;
  constant D0_RETCOUNT_LSb: integer := 20;
  constant D0_RETSTORE_b: integer := 19;
  constant D0_XGAP_b: integer := 18;
  constant D0_TIMEOFFS_MSb: integer := 15;
  constant D0_TIMEOFFS_LSb: integer := 0;
  -- Descriptor word #1
  constant D1_DUMMY_b: integer := 31;
  constant D1_BUS_b: integer := 30;
  constant D1_EXTRATIME_MSb: integer := 29;
  constant D1_EXTRATIME_LSb: integer := 26;
  constant D1_RTADDR2_MSb: integer := 25;
  constant D1_RTADDR2_LSb: integer := 21;
  constant D1_SAMC2_MSb: integer := 20;
  constant D1_SAMC2_LSb: integer := 16;
  constant D1_RTADDR1_MSb: integer := 15;
  constant D1_RTADDR1_LSb: integer := 11;
  constant D1_TR_b: integer := 10;
  constant D1_SAMC1_MSb: integer := 9;
  constant D1_SAMC1_LSb: integer := 5;
  constant D1_WCMC_MSb: integer := 4;
  constant D1_WCMC_LSb: integer := 0;
  
  constant RETMODE_SAME: std_logic_vector := "00";
  constant RETMODE_ALT: std_logic_vector := "01";
  constant RETMODE_ALL_ALL: std_logic_vector := "10";
  
  -- "TX" and "RX" refer to the remote terminal side (as in the standard).
  type gr1553b_transfer_type is
    (TFR_INVALID, CTRL2RT, RT2CTRL, RT2RT, MODECMD, MODECMD_TX,
     MODECMD_RX, CTRL2RT_BC, RT2RT_BC, MODECMD_BC, MODECMD_RX_BC);

--  type gr1553b_transfer_status is
--    (SUCCESS, TIMEOUT, TIMEOUT2, RTERROR, BUSERR, BADCMD, DMAERR, LBFAIL);

  constant TFR_SUCCESS: std_logic_vector := "000";
  constant TFR_TIMEOUT: std_logic_vector := "001";
  constant TFR_TIMEOUT2: std_logic_vector := "010";
  constant TFR_RTERROR: std_logic_vector := "011";
  constant TFR_BUSERR: std_logic_vector := "100";
  constant TFR_BADCMD: std_logic_vector := "101";
  constant TFR_DMAERR: std_logic_vector := "110";
  constant TFR_LBFAIL: std_logic_vector := "111";  
  subtype gr1553b_transfer_status is std_logic_vector(2 downto 0);
  
  type gr1553b_transfer_config is record
    dummy: std_logic;
    rtaddr1: std_logic_vector(4 downto 0);
    samc1: std_logic_vector(4 downto 0);
    rtaddr2: std_logic_vector(4 downto 0);
    samc2: std_logic_vector(4 downto 0);
    wc_mode: std_logic_vector(4 downto 0);
    tr: std_logic;
    bussel: std_logic;
    extratime: std_logic_vector(3 downto 0);
    extragap_en: std_logic;
  end record;

  constant gr1553b_transfer_config_zero: gr1553b_transfer_config := (
    dummy => '0', rtaddr1 => "00000", samc1 => "00000", rtaddr2 => "00000",
    samc2 => "00000", wc_mode => "00000", tr => '0',
    bussel => '0', extratime => "0000", extragap_en => '0' );

  function classify_transfer(tc: gr1553b_transfer_config)
    return gr1553b_transfer_type;
  
  type gr1553b_bc_proto_out is record
    ready: std_logic;
    tfrdone: std_logic;
    status: gr1553b_transfer_status;
    stword1: std_logic_vector(7 downto 0);
    stword2: std_logic_vector(7 downto 0);
    datain_read: std_logic;
    datain_req: std_logic;    
    dataout_write: std_logic;
    dataout_done: std_logic;
    data_out: std_logic_vector(15 downto 0);
    validcmdA: std_logic;
    validcmdB: std_logic;
  end record;

  constant gr1553b_bc_proto_out_zero: gr1553b_bc_proto_out := (
    ready => '0', tfrdone => '0', status => TFR_SUCCESS,
    stword1 => "00000000", stword2 => "00000000",
    datain_read => '0', datain_req => '0',
    dataout_write => '0', dataout_done => '0', data_out => (others => '0'),
    validcmdA => '0', validcmdB => '0'
    );
  
  type gr1553b_bc_proto_in is record
    tfrstart: std_logic;
    tfrconfig: gr1553b_transfer_config;
    fast_broadcast: std_logic;
    datain_valid: std_logic;
    data_in: std_logic_vector(15 downto 0);
    data_error: std_logic;
  end record;

  constant gr1553b_bc_proto_in_zero: gr1553b_bc_proto_in := (
    tfrstart => '0', tfrconfig => gr1553b_transfer_config_zero,
    datain_valid => '0', data_in => (others => '0'), data_error => '0', fast_broadcast => '0');
  
  component gr1553b_bc_proto is
    generic (syncrst: integer range 0 to 2);
    port(
      clk: in std_logic;
      rst: in std_logic;
      ins: in gr1553b_bc_proto_in;
      outs: out gr1553b_bc_proto_out;
      us_restart: out std_logic;
      us_clear: out std_logic;
      us_tick: in std_logic;
      toll: out gr1553b_codec_in;
      fromll: in gr1553b_codec_out
      );
  end component;  

  type gr1553b_bc_control_in is record
    sched_start: std_logic;
    sched_stop: std_logic;
    sched_pause: std_logic;
    sched_trig: std_logic;
    sched_trig_clear: std_logic;
    async_start: std_logic;
    async_stop: std_logic;
    user_input: std_logic_vector(31 downto 0);
    set_schem_addr: std_logic;
    set_async_addr: std_logic;
    set_logbuf_pos: std_logic;
    set_rt_busmask: std_logic;
    user_irq_ack: std_logic;
    fast_broadcast: std_logic;
  end record;

  constant sched_state_stopped: std_logic_vector := "000";
  constant sched_state_running: std_logic_vector := "001";
  constant sched_state_waitslot: std_logic_vector := "010";
  constant sched_state_paused: std_logic_vector := "011";
  constant sched_state_waittrig: std_logic_vector := "100";
  
  type gr1553b_bc_control_out is record
    sched_state: std_logic_vector(2 downto 0);
    async_state: std_logic_vector(2 downto 0);
    sched_current_pos: std_logic_vector(31 downto 0);
    async_current_pos: std_logic_vector(31 downto 0);
    sched_next_pos: std_logic_vector(31 downto 0);
    async_next_pos: std_logic_vector(31 downto 0);
    rt_busmask: std_logic_vector(31 downto 0);
    
    schem_time: std_logic_vector(23 downto 0);
    user_irq: std_logic;
    user_irq_next: std_logic;
    user_irq_addr:  std_logic_vector(31 downto 0);
    dmaerror_next: std_logic;
    validcmdA, validcmdB: std_logic;
  end record;
  
  component gr1553b_bc_control is
    generic (
      cond_en: boolean := true;
      rtmask_en: boolean := false;
      syncrst: integer range 0 to 2
      );
    port(
      clk: in std_logic;
      rst: in std_logic;    
      ins: in gr1553b_bc_control_in;
      outs: out gr1553b_bc_control_out;    
      dmai: out gr1553b_dma2_in_bc;
      dmao: in gr1553b_dma2_out;
      us_restart: out std_logic;
      us_clear: out std_logic;
      us_tick: in std_logic;
      proti: out gr1553b_bc_proto_in;
      proto: in gr1553b_bc_proto_out
      );
  end component;

  -----------------------------------------------------------------------------
  -- Remote terminal components
  -----------------------------------------------------------------------------
  
  type gr1553b_rt_request_type is
    (NOREQ, RECV, XMIT, MODECMD, MODECMD_RECV, MODECMD_XMIT);
  type gr1553b_rt_request_result is
    (PROGRESS, SUCCESS, TIMEOUT, BUSERROR, SUPERSEDED, MSGERRSENT, LBERROR);
  type gr1553b_rt_request_response is (UNKNOWN, REQOK, REQILLEGAL);
  
  type gr1553b_rt_request is record
    t: gr1553b_rt_request_type;
    subaddr: std_logic_vector(4 downto 0);
    wc_mode: std_logic_vector(4 downto 0);
    bc: std_logic;
    cmdbus: std_logic;
  end record;

  constant gr1553b_rt_request_zero: gr1553b_rt_request := (
    t => NOREQ, subaddr => "00000", wc_mode => "00000", bc => '0', cmdbus => '0'
    );
  
  type gr1553b_rt_proto_in is record
    enable: std_logic;
    my_addr: std_logic_vector(4 downto 0);
    allow_broadcast: std_logic;
    req_resp: gr1553b_rt_request_response;
    statusbits: std_logic_vector(4 downto 0);
    datain_valid: std_logic;
    dataout_ready: std_logic;
    data_in: std_logic_vector(15 downto 0);    
  end record;

  constant gr1553b_rt_proto_in_zero: gr1553b_rt_proto_in := (
    enable => '0', my_addr => "00000", allow_broadcast => '0',
    req_resp => UNKNOWN, statusbits => "00000", datain_valid => '0',
    dataout_ready => '0', data_in => (others => '0')
    );

  type gr1553b_rt_proto_out is record
    request: gr1553b_rt_request;
    result: gr1553b_rt_request_result;
    datain_read: std_logic;
    dataout_write: std_logic;
    data_out: std_logic_vector(15 downto 0);
    validcmdA, validcmdB: std_logic;
    txdone: std_logic;
    status_next: std_logic;
  end record;

  constant gr1553b_rt_proto_out_zero: gr1553b_rt_proto_out := (
    request => gr1553b_rt_request_zero, result => PROGRESS,
    datain_read => '0', dataout_write => '0',
    data_out => (others => '0'), validcmdA => '0', validcmdB => '0',
    txdone => '0', status_next => '0'
    );
  
  component gr1553b_rt_proto is
    generic (syncrst: integer range 0 to 2);
    port(
      clk: in std_logic;
      rst: in std_logic;
      ins: in gr1553b_rt_proto_in;
      outs: out gr1553b_rt_proto_out;
      us_restart: out std_logic;
      us_clear: out std_logic;
      us_tick: in std_logic;
      toll: out gr1553b_codec_in;
      fromll: in gr1553b_codec_out
    );    
  end component;

  type gr1553b_rt_control_in is record
    rt_enable: std_logic;
    rt_stop: std_logic;
    rt_addr: std_logic_vector(4 downto 0);
    allow_bc: std_logic;
    statusbits: std_logic_vector(4 downto 0);
    vector_word: std_logic_vector(15 downto 0);
    BIT_word: std_logic_vector(15 downto 0);    
    timer_value: std_logic_vector(15 downto 0);
    dmaerror_ack: std_logic;
    descerror_ack: std_logic;
    irqack: std_logic;    
    user_input: std_logic_vector(31 downto 0);
    set_modecode_mask: std_logic;
    set_subaddr_table_base: std_logic;
    set_log_mask: std_logic;
    set_log_cur_addr: std_logic;
  end record;

  type gr1553b_rt_control_out is record
    dmaerror: std_logic;
    dmaerror_next: std_logic;
    descerror: std_logic;
    descerror_next: std_logic;
    gotirq: std_logic;
    gotirq_next: std_logic;
    irq_log_addr: std_logic_vector(31 downto 0);
    bussync_nodata: std_logic;
    bussync_data: std_logic;
    bussync_word: std_logic_vector(15 downto 0);
    bussync_time: std_logic_vector(15 downto 0);
    busreset: std_logic;
    shutdownA: std_logic;
    shutdownB: std_logic;
    validcmdA: std_logic;
    validcmdB: std_logic;
    active: std_logic;
    subaddr_table_base: std_logic_vector(31 downto 0);
    modecode_mask: std_logic_vector(29 downto 0);
    log_mask: std_logic_vector(31 downto 0);
    log_cur_addr: std_logic_vector(31 downto 0);
  end record;

  component gr1553b_rt_control is
    generic (
      syncrst: integer range 0 to 2
      );
    port(
      clk: in std_logic;
      rst: in std_logic;      
      ins: in gr1553b_rt_control_in;
      outs: out gr1553b_rt_control_out;      
      dmai: out gr1553b_dma2_in_rt;
      dmao: in gr1553b_dma2_out;      
      proti: out gr1553b_rt_proto_in;
      proto: in gr1553b_rt_proto_out
      );
  end component;

  -----------------------------------------------------------------------------
  -- Bus monitor
  -----------------------------------------------------------------------------
  
  type gr1553b_bm_in is record
    enable: std_logic;
    timeval: std_logic_vector(23 downto 0);
    dmaerror_ack: std_logic;
    log_errors: std_logic;
    log_stray_data: std_logic;
    log_reserved_mcs: std_logic;
    set_outbuf_start: std_logic;
    set_outbuf_end: std_logic;
    set_outbuf_pos: std_logic;
    set_rtaddr_filter: std_logic;
    set_subaddr_filter: std_logic;
    set_modecode_filter: std_logic;
    user_input: std_logic_vector(31 downto 0);
  end record;

  type gr1553b_bm_out is record
    dmaerror_next: std_logic;
    dmaerror: std_logic;
    outbuf_start: std_logic_vector(31 downto 0);
    outbuf_end: std_logic_vector(31 downto 0);
    outbuf_pos: std_logic_vector(31 downto 0);
    rtaddr_filter: std_logic_vector(31 downto 0);
    subaddr_filter: std_logic_vector(31 downto 0);
    modecode_filter: std_logic_vector(31 downto 0);
    wrapping: std_logic;
  end record;

  component gr1553b_bm is
    generic (
      filters: integer range 0 to 1;
      syncrst: integer range 0 to 2
      );
    port (
      clk: in std_logic;
      rst: in std_logic;
      ins: in gr1553b_bm_in;
      outs: out gr1553b_bm_out;    
      busdata: in gr1553b_bm_tap;    
      dmai: out gr1553b_dma2_in_bm;
      dmao: in gr1553b_dma2_out
      );
  end component;

  -----------------------------------------------------------------------------
  -- APB interface
  -----------------------------------------------------------------------------
  
  component gr1553b_apb is
    generic (
      pindex : integer := 0;
      paddr: integer := 0;
      pmask : integer := 16#fff#;
      pirq : integer := 0;
      venid: integer;
      devid: integer;
      cfgver: integer;
      version: integer;      
      rt_enable: integer range 0 to 1;
      bc_enable: integer range 0 to 1;
      bm_enable: integer range 0 to 1;
      codec_clk_freq_mhz: integer;
      sameclk: integer range 0 to 1;
      schemtime_en: boolean;
      wakeup_en: boolean;
      rtbusmask_en: boolean;
      extrakeyen: integer range 0 to 1;
      endianness: integer;
      bm_filters: integer;
      core_modified: boolean;
      syncrst: integer range 0 to 2
      );
    port (
      clk: in std_logic;
      rst: in std_logic;    
      apbsi: in apb_slv_in_type;
      apbso: out apb_slv_out_type;
      bcct_outs: in gr1553b_bc_control_out;
      rtct_outs: in gr1553b_rt_control_out;
      bmct_outs: in gr1553b_bm_out;
      bcct_in: out gr1553b_bc_control_in;
      rtct_in: out gr1553b_rt_control_in;
      bmct_in: out gr1553b_bm_in;
      bc_extsync: in std_logic;
      rtts_tick: in std_logic;
      rtts_restart: out std_logic;
      rtts_clear: out std_logic;
      rtaddr: in std_logic_vector(4 downto 0);
      rtaddrpar: in std_logic;
      rt_sync: out std_logic;
      rt_busreset: out std_logic;
      badreg: out std_logic;
      xirqvec: out std_logic_vector(7 downto 0);
      rt_run: out std_logic;
      bc_run: out std_logic;
      bm_run: out std_logic
      );    
  end component;
    
  -----------------------------------------------------------------------------
  -- MHz tick and failsafe timer in codec clock domain
  
  component gr1553b_mhztick is
    generic(
      timeclk_freq_mhz: integer;
      sameclk: integer range 0 to 1;
      syncrst: integer range 0 to 2
      );
    port(
      clk: in std_logic;
      rst: in std_logic;
      restart: in std_logic;
      clear: in std_logic;
      tick: out std_logic;
      timeclk: in std_logic;
      timerst: in std_logic
      );
  end component;

  component gr1553b_fstimer is
    generic (
      tx_clk_freq_mhz: integer;
      sameclk: integer range 0 to 1;
      syncrst: integer range 0 to 2
      );
    port (
      tx_clk: in std_logic;
      tx_rst: in std_logic;    
      txP: in std_logic;
      txN: in std_logic;
      timeout: out std_logic;
      validcmd_clk: in std_logic;
      validcmd_rst: in std_logic;
      validcmd: in std_logic
      );
  end component;
  
end;

package body gr1553b_core is
  
  function int_divide_round(i1,i2: integer) return integer is
  begin
    return (i1*2+i2)/(i2*2);
  end;

  function classify_transfer(tc: gr1553b_transfer_config) return gr1553b_transfer_type is
    variable bc1,mc1,bc2,mc2: boolean;
    variable wcm_nodata_nobc,wcm_nodata,wcm_tx_nobc,wcm_rx: boolean;
  begin
    
    bc1 := (tc.rtaddr1 = "11111");    
    mc1 := (tc.samc1="00000" or tc.samc1="11111");
    bc2 := (tc.rtaddr2 = "11111");
    mc2 := (tc.samc2="00000" or tc.samc2="11111");
    wcm_nodata_nobc := tc.wc_mode="00000" or tc.wc_mode="00010";
    wcm_nodata := tc.wc_mode(4)='0' and (tc.wc_mode(3)='0' or tc.wc_mode(2 downto 0)="000");
    wcm_tx_nobc := tc.wc_mode="10000" or tc.wc_mode="10010" or tc.wc_mode="10011";
    wcm_rx := tc.wc_mode="10001" or tc.wc_mode="10100" or tc.wc_mode="10101";

    if mc1 then
      -- Mode commands
      if bc1 then
        -- Broadcast mode commands
        if wcm_nodata then
          if tc.tr='1' and not wcm_nodata_nobc then return MODECMD_BC; end if;
        elsif wcm_tx_nobc then
          return TFR_INVALID;
        elsif wcm_rx then
          if tc.tr='0' then return MODECMD_RX_BC; end if;
        end if;
      else
        -- Non-broadcast mode commands
        if wcm_nodata then
          if tc.tr='1' then return MODECMD; end if;
        elsif wcm_tx_nobc then
          if tc.tr='1' then return MODECMD_TX; end if;
        elsif wcm_rx then
          if tc.tr='0' then return MODECMD_RX; end if;
        end if;
      end if;
      
    else      
      -- Data transfers
      if not mc2 then
        -- RT-to-RT data transfer
        if bc1 then
          if tc.tr='0' and not bc2 then return RT2RT_BC; end if;
        else
          if tc.tr='0' and not bc2 then return RT2RT; end if;
        end if;
      else
        -- BC<=>RT(s) transfer
        if bc1 then
          if tc.tr='0' then return CTRL2RT_BC; end if;
        else
          if tc.tr='0' then
            return CTRL2RT;
          else
            return RT2CTRL;
          end if;
        end if;
      end if;
    end if;
    
    return TFR_INVALID;
  end;

  function modecode_valid(mc: std_logic_vector(4 downto 0); tr: std_logic) return boolean is
    variable nodata,tx,rx: boolean;
  begin
    nodata := mc(4)='0'and (mc(3)='0' or mc(2 downto 0)="000");
    tx := mc="10000" or mc="10010" or mc="10011";
    rx := mc="10001" or mc="10100" or mc="10101";
    return (nodata and tr='1') or (tx and tr='1') or (rx and tr='0');
  end;

  -- Combine the 5 mode code bits and the bc bit into a 5-bit address
  -- Because transmit status word "00010" is filtered out by the protocol
  -- layer and all mode codes where bit 3 is '1' are banned except "01000",
  -- we can or bit 3 and 1 and still identify all valid mode codes.   
  function mc_to_muxidx(code: std_logic_vector; bc: std_logic) return std_logic_vector is    
  begin    
    return code(4) & code(2) & (code(1) or code(3)) & code(0) & bc;
  end;

  -- Corresponding fcn to convert mode code mask to mux input
  -- bm: Bus monitor mode
  -- forb: Value for invalid/reserved codes
  function mcmask_to_muxin(mask: std_logic_vector; bm: boolean; res: std_logic) return std_logic_vector is
    variable r: std_logic_vector(31 downto 0);
  begin
    r := (others => 'X');
    r(31 downto 28) := res & res & res & res; -- Reserved mode codes
    if bm then
      r(27) := mask(18); -- Override selected transmitter shutdown broadcast    
      r(26) := mask(17); -- Override selected transmitter shutdown
      r(25) := mask(18); -- Sel. transmitter shutdown broadcast
      r(24) := mask(17); -- Sel. transmitter shutdown      
    else
      r(27) := '0';      -- Override selected transmitter shutdown broadcast    
      r(26) := '0';      -- Override selected transmitter shutdown
      r(25) := '0';      -- Sel. transmitter shutdown broadcast
      r(24) := '0';      -- Sel. transmitter shutdown
    end if;
    r(23) := res;        -- Forbidden (Transmit BIT word broadcast)
    r(22) := mask(7);    -- Transmit BIT word
    r(21) := res;        -- Forbidden (Transmit last cmd broadcast)
    if bm then
      r(20) := mask(16); -- Transmit last cmd
    else
      r(20) := '0';      -- Handled by proto layer (Transmit last cmd)
    end if;
    r(19) := mask(3);    -- Sync with data word broadcast
    r(18) := mask(2);    -- Sync with data word
    r(17) := res;        -- Forbidden (transmit vector word broadcast)
    r(16) := mask(6);    -- Transmit vector word
    r(15) := mask(12);   -- Override inhibit terminal flag broadcast
    r(14) := mask(11);   -- Override inhibit terminal flag
    r(13) := mask(12);   -- Inhibit terminal flag broadcast
    r(12) := mask(11);   -- Inhibit terminal flag
    r(11) := mask(5);    -- Override transmitter shutdown broadcast
    r(10) := mask(4);    -- Override transmitter shutdown
    r(9) := mask(5);     -- Transmitter shutdown broadcast
    r(8) := mask(4);     -- Transmitter shutdown
    r(7) := mask(10);    -- Initiate self test broadcast
    r(6) := mask(9);     -- Initiate self test
    r(5) := mask(14);    -- Reset remote terminal broadcast
    r(4) := mask(13);    -- Reset remote terminal
    r(3) := mask(1);     -- Synchronize broadcast
    r(2) := mask(0);     -- Synchronize
    r(1) := res;         -- Forbidden (Dynamic bus control broadcast)
    r(0) := mask(8);     -- Dynamic bus control
    return r;
  end mcmask_to_muxin;

  function wt_to_sl(wt: gr1553b_word_type) return std_logic is
  begin
    if wt=CMD_STAT then return '1'; else return '0'; end if;
  end wt_to_sl;
  
  function sl_to_wt(sl: std_logic) return gr1553b_word_type is
  begin
    if sl='1' then return CMD_STAT; else return DATA; end if;
  end sl_to_wt;
  
end;
