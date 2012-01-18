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
-- Entity:      gr1553b
-- File:        gr1553b.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B BC/RT/BM core top level
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
use work.gr1553b_pkg.all;
use work.gr1553b_core.all;

entity gr1553b is
  generic(
    -- AHB config
    hindex: integer := 0;
    -- APB config
    pindex : integer := 0;
    paddr: integer := 0;
    pmask : integer := 16#fff#;
    pirq : integer := 0;
    -- 1553B features/options
    bc_enable: integer range 0 to 1 := 1;
    rt_enable: integer range 0 to 1 := 1;
    bm_enable: integer range 0 to 1 := 1;
    bc_timer: integer range 0 to 2 := 1;
    bc_rtbusmask: integer range 0 to 1 := 1;
    extra_regkeys: integer range 0 to 1 := 0;
    syncrst: integer range 0 to 2 := 1;
    ahbendian: integer range 0 to 1 := 0;
    bm_filters: integer range 0 to 1 := 1
    );
  port(
    -- AMBA clock domain signals    
    clk: in std_logic;
    rst: in std_logic;
    ahbmi: in ahb_mst_in_type;
    ahbmo: out ahb_mst_out_type;
    apbsi: in apb_slv_in_type;
    apbso: out apb_slv_out_type;

    auxin: in gr1553b_auxin_type;
    auxout: out gr1553b_auxout_type;
    
    -- Codec clock domain signals
    codec_clk: in std_logic;
    codec_rst: in std_logic;

    txout: out gr1553b_txout_type;
    txout_fb: in gr1553b_txout_type;
    
    -- Asynchronous "1553 domain" signals
    rxin: in gr1553b_rxin_type

    );
  attribute sync_set_reset of rst : signal is "true";
end;

-------------------------------------------------------------------------------
-- Design entity hierarchy:
-- gr1553b
--   +-- gr1553b_apb
--   +-- gr1553b_dma2
--   |
--   +-- gr1553b_bc_control
--   +-- gr1553b_bc_proto
--   +-- gr1553b_rt_control
--   +-- gr1553b_rt_proto
--   +-- gr1553b_bm
--   +-- gr1553b_codec
--   |     +-- gr1553b_rx_*
--   |     +-- gr1553b_tx_*
--   |     +-- gr1553b_loopback
--   |
--   +-- gr1553b_mhztick
--   +-- gr1553b_fstimer
--   
-------------------------------------------------------------------------------

architecture rtl of gr1553b is

  
  -- If some part of the core is modified in some (unspecified) way
  -- which alters functionality, please set this boolean to true. This
  -- will turn on a bit in the HW configuration register so the change
  -- can be detected from software for diagnostics.
  constant core_modified: boolean := false;  

  
  constant sameclk: integer range 0 to 1 := 0;
  constant codec_clk_freq_mhz: integer := 20;
  constant little_endian: boolean := (ahbendian = 1);
  
  constant venid: integer := VENDOR_GAISLER;
  constant devid: integer := GAISLER_GR1553B;
  constant version: integer := gr1553b_version;
  constant cfgver: integer := gr1553b_cfgver;
  
  signal bcct_ins: gr1553b_bc_control_in;
  signal bcct_outs: gr1553b_bc_control_out;
  signal bc_dmai: gr1553b_dma2_in_bc;
  signal bcct_topr: gr1553b_bc_proto_in;
  signal bcct_frompr: gr1553b_bc_proto_out;
  signal bcpr_ustick,bcpr_usrestart,bcpr_usclear: std_logic;
  signal bcct_ustick,bcct_usrestart,bcct_usclear: std_logic;

  signal rtct_ins: gr1553b_rt_control_in;
  signal rtct_outs: gr1553b_rt_control_out;
  signal rt_dmai: gr1553b_dma2_in_rt;
  signal rtct_proti: gr1553b_rt_proto_in;
  signal rtct_proto: gr1553b_rt_proto_out;
  signal rtpr_ustimer_restart,rtpr_ustimer_clear,rtpr_ustimer_tick: std_logic;
  
  signal bmct_ins: gr1553b_bm_in;
  signal bmct_outs: gr1553b_bm_out;
  signal bm_dmai: gr1553b_dma2_in_bm;

  signal dmai: gr1553b_dma2_in;
  signal dmao: gr1553b_dma2_out;

  signal bcpr_toll, rtpr_toll: gr1553b_codec_in;
  signal ll_ins: gr1553b_codec_in;
  signal fromll: gr1553b_codec_out;
  signal ll_bmtap: gr1553b_bm_tap;

  signal rt_run,bc_run,bm_run: std_logic;

  signal rtts_tick, rtts_restart, rtts_clear: std_logic;

  signal busA_timeout, busB_timeout: std_logic;

  signal validcmdA_i, validcmdB_i: std_logic;

  signal rt_bussync, rt_busreset: std_logic;
begin

  auxout.rtsync <= rt_bussync;
  auxout.busreset <= rt_busreset;
  auxout.validcmdA <= validcmdA_i;
  auxout.validcmdB <= validcmdB_i;
  auxout.timedoutA <= busA_timeout;
  auxout.timedoutB <= busB_timeout;
  validcmdA_i <= rtct_outs.validcmdA or bcct_outs.validcmdA;
  validcmdB_i <= rtct_outs.validcmdB or bcct_outs.validcmdB;

  -----------------------------------------------------------------------------
  -- Bus controller components
  
  bc_gen: if bc_enable=1 generate
    
    bcct: gr1553b_bc_control
      generic map (
        cond_en => true,
        rtmask_en => bc_rtbusmask /= 0,
        syncrst => syncrst
        )
      port map(
        clk => clk,
        rst => rst,
        ins => bcct_ins,
        outs => bcct_outs,
        dmai => bc_dmai,
        dmao => dmao,
        us_restart => bcct_usrestart,
        us_clear => bcct_usclear,
        us_tick => bcct_ustick,
        proti => bcct_topr,
        proto => bcct_frompr
        );
    
    bcpr: gr1553b_bc_proto
      generic map (syncrst => syncrst)
      port map (
        clk => clk,
        rst => rst,
        ins => bcct_topr,
        outs => bcct_frompr,
        us_restart => bcpr_usrestart,
        us_clear => bcpr_usclear,
        us_tick => bcpr_ustick,
        toll => bcpr_toll,
        fromll => fromll
        );

    bccttm: gr1553b_mhztick
      generic map (
        timeclk_freq_mhz => codec_clk_freq_mhz,
        sameclk => sameclk,
        syncrst => syncrst
        )
      port map (
        clk => clk,
        rst => rst,
        restart => bcct_usrestart,
        tick => bcct_ustick,
        clear => bcct_usclear,
        timeclk => codec_clk,
        timerst => codec_rst
        );

      bcprtm: gr1553b_mhztick
      generic map (
        timeclk_freq_mhz => codec_clk_freq_mhz,
        sameclk => sameclk,
        syncrst => syncrst
        )
      port map (
        clk => clk,
        rst => rst,
        restart => bcpr_usrestart,
        tick => bcpr_ustick,
        clear => bcpr_usclear,
        timeclk => codec_clk,
        timerst => codec_rst
        );
  end generate;

  bc_ngen: if bc_enable=0 generate
    bcpr_toll <= gr1553b_codec_in_zero;
    bc_dmai <= gr1553b_dma2_in_bc_zero;
    bcct_outs <= (sched_state => "000", async_state => "000", sched_current_pos => (others=>'0'),
                  async_current_pos => (others=>'0'), 
                  schem_time => (others=>'0'), user_irq=>'0', user_irq_addr => (others=>'0'),
                  dmaerror_next=>'0',user_irq_next => '0', validcmdA => '0', validcmdB => '0',
                  sched_next_pos => (others => '0'), async_next_pos => (others => '0'),
                  rt_busmask => (others => '0'));
    bcct_topr <= gr1553b_bc_proto_in_zero;
    bcct_frompr <= gr1553b_bc_proto_out_zero;
    bcpr_ustick <= '0';
    bcpr_usrestart <= '0';
    bcpr_usclear <= '1';
    bcct_ustick <= '0';
    bcct_usrestart <= '0';
    bcct_usclear <= '1';
  end generate;

  -----------------------------------------------------------------------------
  -- Remote terminal components
  
  rt_gen: if rt_enable=1 generate

    rtct: gr1553b_rt_control
      generic map (
        syncrst => syncrst
        )
      port map (
        clk => clk,
        rst => rst,
        ins => rtct_ins,
        outs => rtct_outs,
        dmai => rt_dmai,
        dmao => dmao,
        proti => rtct_proti,
        proto => rtct_proto
        );

    rtpr: gr1553b_rt_proto
      generic map (syncrst => syncrst)
      port map (
        clk => clk,
        rst => rst,
        ins => rtct_proti,
        outs => rtct_proto,
        us_tick => rtpr_ustimer_tick,
        us_restart => rtpr_ustimer_restart,
        us_clear => rtpr_ustimer_clear,
        toll => rtpr_toll,
        fromll => fromll
        );

    rtprtm: gr1553b_mhztick
      generic map (
        timeclk_freq_mhz => codec_clk_freq_mhz,
        sameclk => sameclk,
        syncrst => syncrst
        )
      port map (
        clk => clk,
        rst => rst,
        restart => rtpr_ustimer_restart,
        clear => rtpr_ustimer_clear,
        tick => rtpr_ustimer_tick,
        timeclk => codec_clk,
        timerst => codec_rst
        );

  end generate;

  rt_ngen: if rt_enable=0 generate
    rtpr_toll <= (bussel => '0', anybus => '0', txstart => '0', txdata => (t => CMD_STAT, data => (others=>'0')),
                  txabort => '0');
    rtct_proti <= gr1553b_rt_proto_in_zero;
    rtct_proto <= gr1553b_rt_proto_out_zero;
    rt_dmai <= gr1553b_dma2_in_rt_zero;
    rtct_outs <= (dmaerror => '0', gotirq => '0', 
                  bussync_nodata => '0', bussync_data => '0', bussync_word => (others => '0'), busreset => '0',
                  shutdownA => '0', shutdownB => '0', active => '0', 
                  modecode_mask => (others => '0'),
                  subaddr_table_base => (others=>'0'), irq_log_addr => (others => '0'),
                  log_mask => (others => '0'),
                  log_cur_addr => (others => '0'), 
                  dmaerror_next => '0', gotirq_next => '0', validcmdA => '0', validcmdB => '0',
                  bussync_time => (others => '0'), descerror => '0', descerror_next => '0'
                  );
    rtpr_ustimer_restart <= '0';
    rtpr_ustimer_clear <= '1';
    rtpr_ustimer_tick <= '0';
  end generate;

  -----------------------------------------------------------------------------
  -- Bus monitor components
  
  bm_gen: if bm_enable=1 generate
    bmct: gr1553b_bm
      generic map (
        filters => bm_filters,
        syncrst => syncrst
        )
      port map (
        clk => clk,
        rst => rst,
        ins => bmct_ins,
        outs => bmct_outs,
        busdata => ll_bmtap,
        dmai => bm_dmai,
        dmao => dmao
        );
  end generate;

  bm_ngen: if bm_enable=0 generate
    bm_dmai <= gr1553b_dma2_in_bm_zero;
    bmct_outs <= (dmaerror_next => '0', outbuf_start => (others => '0'),
                  outbuf_end => (others => '0'), outbuf_pos => (others => '0'),
                  rtaddr_filter => (others => '0'), subaddr_filter => (others => '0'),
                  modecode_filter => (others => '0'), dmaerror => '0', wrapping => '0');
  end generate;

  -----------------------------------------------------------------------------
  -- Common components
  
  ll: gr1553b_codec
    generic map(
      codec_clk_freq_mhz => codec_clk_freq_mhz,
      sameclk => sameclk,
      rx_synclength => 2,
      syncrst => syncrst
      )
    port map (
      clk => clk,
      rst => rst,
      ins => ll_ins,
      outs => fromll,
      bmtap => ll_bmtap,
      shutdownA => rtct_outs.shutdownA,
      shutdownB => rtct_outs.shutdownB,
      codec_clk => codec_clk,
      codec_rst => codec_rst,
      busA_tx_pos => txout.busA_txP,
      busA_tx_neg => txout.busA_txN,
      busA_rx_pos => rxin.busA_rxP,
      busA_rx_neg => rxin.busA_rxN,
      busB_tx_pos => txout.busB_txP,
      busB_tx_neg => txout.busB_txN,
      busB_rx_pos => rxin.busB_rxP,
      busB_rx_neg => rxin.busB_rxN
      );

  fstA: gr1553b_fstimer
    generic map (
      tx_clk_freq_mhz => codec_clk_freq_mhz,
      sameclk => sameclk,
      syncrst => syncrst
      )
    port map (
      tx_clk => codec_clk,
      tx_rst => codec_rst,
      txP => txout_fb.busA_txP,
      txN => txout_fb.busA_txN,
      timeout => busA_timeout,
      validcmd_clk => clk,
      validcmd_rst => rst,
      validcmd => validcmdA_i
      );

  fstB: gr1553b_fstimer
    generic map (
      tx_clk_freq_mhz => codec_clk_freq_mhz,
      sameclk => sameclk,
      syncrst => syncrst
      )
    port map (
      tx_clk => codec_clk,
      tx_rst => codec_rst,
      txP => txout_fb.busB_txP,
      txN => txout_fb.busB_txN,
      timeout => busB_timeout,
      validcmd_clk => clk,
      validcmd_rst => rst,
      validcmd => validcmdB_i
      );
      
  dma0: gr1553b_dma2
    generic map (
      hindex => hindex,
      syncrst => syncrst,
      endian => ahbendian,
      ahbreqreg => 0
      )
    port map (
      clk => clk,
      rst => rst,
      ahbmi => ahbmi,
      ahbmo => ahbmo,
      ins => dmai,
      outs => dmao
      );
  
  iface0: gr1553b_apb
    generic map (
      pindex => pindex,
      paddr => paddr,
      pmask => pmask,
      pirq => pirq,
      venid => venid,
      devid => devid,
      version => version,
      cfgver => 0,
      rt_enable => rt_enable,
      bc_enable => bc_enable,
      bm_enable => bm_enable,
      codec_clk_freq_mhz => codec_clk_freq_mhz,
      sameclk => sameclk,
      schemtime_en => bc_timer >= 1,
      wakeup_en => bc_timer >= 2,
      rtbusmask_en => bc_rtbusmask /= 0,
      extrakeyen => extra_regkeys,
      endianness => ahbendian,
      bm_filters => bm_filters,
      core_modified => core_modified,
      syncrst => syncrst
      )
    port map (
      clk => clk,
      rst => rst,
      apbsi => apbsi,
      apbso => apbso,
      bcct_outs => bcct_outs,
      rtct_outs => rtct_outs,      
      bmct_outs => bmct_outs,
      bcct_in => bcct_ins,
      bc_extsync => auxin.extsync,
      rtaddr => auxin.rtaddr,
      rtaddrpar => auxin.rtpar,
      rtct_in => rtct_ins,
      rtts_tick => rtts_tick,
      rtts_restart => rtts_restart,
      rtts_clear => rtts_clear,
      bmct_in => bmct_ins,
      badreg => auxout.badreg,
      xirqvec => auxout.irqvec,
      rt_run => rt_run,
      bc_run => bc_run,
      bm_run => bm_run,
      rt_sync => rt_bussync,
      rt_busreset => rt_busreset
      );

  apbtickgen: if rt_enable=1 or bm_enable=1 generate
    rttstm: gr1553b_mhztick
      generic map (
        timeclk_freq_mhz => codec_clk_freq_mhz,
        sameclk => sameclk,
        syncrst => syncrst
        )
      port map (
        clk => clk,
        rst => rst,
        restart => rtts_restart,
        clear => rtts_clear,
        tick => rtts_tick,
        timeclk => codec_clk,
        timerst => codec_rst
        );
  end generate;
  apbtickngen: if not (rt_enable=1 or bm_enable=1) generate
    rtts_tick <= '0';
    rtts_restart <= '0';
    rtts_clear <= '1';
  end generate;
  
  -----------------------------------------------------------------------------
  -- Glue logic
  
  comb: process(bc_dmai,rt_dmai,bm_dmai,bcpr_toll,rtpr_toll,rt_run,bc_run,rtct_outs,
                busA_timeout,busB_timeout,bm_run,rst)
    variable vdmai: gr1553b_dma2_in;
    variable vllin: gr1553b_codec_in;
    variable vbusA_txen, vbusB_txen, vbusA_rxen, vbusB_rxen: std_logic;
  begin

    -- dma FSM input
    vdmai := (bc => bc_dmai, rt => rt_dmai, bm => bm_dmai, pushdata => fromll.rxword.data);
    dmai <= vdmai;

    -- codec inputs
    vllin := bcpr_toll;
    if rt_run='1' and (bc_run='0' or bc_enable=0) then
      vllin := rtpr_toll;
    end if;
    ll_ins <= vllin;

    -- tx enable outputs    
    vbusA_txen := '1';
    vbusB_txen := '1';
    vbusA_rxen := '1';
    vbusB_rxen := '1';
    
    if bc_run='0' and (rt_run='0' or rtct_outs.shutdownA='1') then
      vbusA_txen := '0';
    end if;
    if bc_run='0' and (rt_run='0' or rtct_outs.shutdownB='1') then
      vbusB_txen := '0';
    end if;
    if bm_run='0' or bm_enable=0 then
      vbusA_rxen := vbusA_txen;
      vbusB_rxen := vbusB_txen;
    end if;    

    -- Avoid enabling the transmitter before sync reset has been clocked in
    if syncrst /= 0 then
      if rst='0' then
        vbusA_txen := '0';
        vbusB_txen := '0';
      end if;
    end if;
    
    txout.busA_txen <= vbusA_txen and not busA_timeout;
    txout.busB_txen <= vbusB_txen and not busB_timeout;
    txout.busA_txin <= not (vbusA_txen and not busA_timeout);
    txout.busB_txin <= not (vbusB_txen and not busB_timeout);
    txout.busA_rxen <= vbusA_rxen;
    txout.busB_rxen <= vbusB_rxen;
  end process;

end;
