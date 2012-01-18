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
-- Entity:      gr1553b_codec
-- File:        gr1553b_codec.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B Dual-bus codec with loopback detection
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.gr1553b_core.all;

entity gr1553b_codec is
  generic(    
    codec_clk_freq_mhz: integer;
    sameclk: integer range 0 to 1 := 1;
    rx_synclength: integer := 2;
    regout: boolean := true;
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
end;

architecture rtl of gr1553b_codec is

  signal seri: gr1553b_tx1_in;
  signal sero: gr1553b_tx1_out;
  signal ser_biti, out_biti: gr1553b_tx2_in;
  signal ser_bito, out_bito: gr1553b_tx2_out;

  signal A_bito_codec, A_bito_amba, B_bito_codec, B_bito_amba: gr1553b_rx2_out;
  signal A_fb_codec, A_fb_amba_in, A_fb_amba_out, B_fb_codec, B_fb_amba_in, B_fb_amba_out: gr1553b_rx2_fb;
  signal A_s3o, B_s3o: gr1553b_rx3_out;
  signal A_rxabort, B_rxabort: std_logic;
  
  signal txout_pos,txout_neg: std_logic;
  signal busA_reinit,busB_reinit: std_logic;

  signal lb_bito: gr1553b_rx2_out;
  signal lb_readdata,lb_datavalid,lb_error,lb_done,lb_gapblock: std_logic;

  type ll_regs is record
    txbussel: std_logic;
    txmask: std_logic;
    B_dv_deferred: std_logic;
    B_rxerr_deferred: std_logic;    
  end record;

  constant r_rst: ll_regs := ('0','0','0','0');
  
  -- Regs clocked by codec_clk
  type ll_cc_regs is record
    txAP,txBP,txAN,txBN: std_logic;
    txbus1,txbus2: std_logic;
    txstartA,txstartB: std_logic;
  end record;  

  constant ccr_rst: ll_cc_regs := ('0','0','0','0','0','0','0','0');
  
  signal r,nr: ll_regs;
  signal ccr,nccr: ll_cc_regs;
  signal oreg,noreg: gr1553b_codec_out;  
  
begin

  -----------------------------------------------------------------------------
  -- Transmitter components
  -----------------------------------------------------------------------------
  txsg: if sameclk=0 generate
    txsync0: gr1553b_tx12sync
      generic map (syncrst => syncrst)
      port map(
        ser_clk => clk,
        ser_rst => rst,
        ser_biti => ser_biti,
        ser_bito => ser_bito,
        out_clk => codec_clk,
        out_rst => codec_rst,
        out_biti => out_biti,
        out_bito => out_bito
        );
  end generate;
  txnsg: if sameclk=1 generate
    ser_bito <= out_bito;
    out_biti <= ser_biti;
  end generate;

  tx10: gr1553b_tx1
    generic map (syncrst => syncrst)
    port map(
      clk=>clk, rst=>rst,
      seri => seri,
      sero => sero,
      biti => ser_biti,
      bito => ser_bito
      );
  txout0: gr1553b_tx2
    generic map(clk_freq_mhz => codec_clk_freq_mhz, txreg => false, syncrst => syncrst)
    port map(
      clk=>codec_clk, rst=>codec_rst,
      biti => out_biti,
      bito => out_bito,
      txout_pos=>txout_pos,txout_neg=>txout_neg
      );

  -----------------------------------------------------------------------------
  -- Receiver components
  -----------------------------------------------------------------------------
  rxA12: gr1553b_rx12v5
    generic map (synclength => rx_synclength,
                 syncrst => syncrst)
    port map (clk => codec_clk, rst => codec_rst,
              rxin_p => busA_rx_pos, rxin_n => busA_rx_neg,
              outs => A_bito_codec, fb => A_fb_codec,
              reinit => busA_reinit);

  rxB12: gr1553b_rx12v5
    generic map (synclength => rx_synclength,
                 syncrst => syncrst)
    port map (clk => codec_clk, rst => codec_rst,
              rxin_p => busB_rx_pos, rxin_n => busB_rx_neg,
              outs => B_bito_codec, fb => B_fb_codec,
              reinit => busB_reinit);

  rxA2des: gr1553b_rx3
    generic map (syncrst => syncrst)
    port map(
      clk => clk, rst => rst, abort => A_rxabort,
      bito => A_bito_amba,
      s2fb => A_fb_amba_out,
      s3o => A_s3o
      );
      
  rxB2des: gr1553b_rx3
    generic map (syncrst => syncrst)
    port map(
      clk => clk, rst => rst, abort => B_rxabort,
      bito => B_bito_amba,
      s2fb => B_fb_amba_out,
      s3o => B_s3o
      );
      
  rxsg: if sameclk=0 generate
    rxsyncA: gr1553b_rx23sync
      generic map (syncrst => syncrst)
      port map (
        deser_clk => clk,
        deser_rst => rst,
        deser_bito => A_bito_amba,
        deser_fb => A_fb_amba_in,
        bit_clk => codec_clk,
        bit_rst => codec_rst,
        bit_bito => A_bito_codec,
        bit_fb => A_fb_codec
        );    
    rxsyncB: gr1553b_rx23sync
      generic map (syncrst => syncrst)
      port map (
        deser_clk => clk,
        deser_rst => rst,
        deser_bito => B_bito_amba,
        deser_fb => B_fb_amba_in,
        bit_clk => codec_clk,
        bit_rst => codec_rst,
        bit_bito => B_bito_codec,
        bit_fb => B_fb_codec
        );    
  end generate;
  rxnsg: if sameclk=1 generate
    rxnsgp: process(clk)
    begin
      if rising_edge(clk) then
        A_bito_amba <= A_bito_codec;
        B_bito_amba <= B_bito_codec;
        A_fb_codec <= A_fb_amba_in;
        B_fb_codec <= B_fb_amba_in;
      end if;
    end process;
  end generate;
  
  -----------------------------------------------------------------------------
  -- Loopback checker
  -----------------------------------------------------------------------------
  
  lb0: gr1553b_loopback
    generic map (syncrst => syncrst)
    port map(
      clk=>clk, rst=>rst,
      rxo => lb_bito,
      txi => seri,
      txo => sero,
      lberror => lb_error,
      lbdone => lb_done,
      lbread_data => lb_readdata,
      lbdata_valid => lb_datavalid,
      gapblock => lb_gapblock
      );

  -----------------------------------------------------------------------------
  -- Glue logic
  -----------------------------------------------------------------------------
  
  comb: process(ins,shutdownA,shutdownB,
                sero,
                A_bito_amba,B_bito_amba,A_s3o,B_s3o,A_fb_amba_out,B_fb_amba_out,
                lb_readdata,lb_datavalid,lb_error,lb_done,lb_gapblock,
                r,oreg, rst)
    variable v: ll_regs;
    variable rp,rn: std_logic;
    variable vrxbus,vrxstarted,vrxerror,vrxdone: std_logic;
    variable vrxword: gr1553b_word;
    variable vo,vod: gr1553b_codec_out;
    variable vlb_bito: gr1553b_rx2_out;
    variable vseri: gr1553b_tx1_in;
    variable A_datavalid,B_datavalid: std_logic;
    variable A_rxstarted, B_rxstarted: std_logic;
    variable vrxabort_a,vrxabort_b: std_logic;
    variable Afb,Bfb: gr1553b_rx2_fb;
  begin
    v := r;        
    vo := (
      txready => sero.ready,
      lbdone => lb_done,
      lberror => lb_error,
      rxstarted => '0',
      rxerror => '0',
      rxdone => '0',
      rxbus => '0',
      rxword => gr1553b_word_default,
      txread_data => lb_readdata,
      rxact => '0'
      );
    
    ---------------------------------------------------------------------------
    -- Loopback checker

    A_datavalid := A_s3o.datavalid;
    B_datavalid := B_s3o.datavalid;
    A_rxstarted := A_s3o.started;
    B_rxstarted := B_s3o.started;
    Afb := A_fb_amba_out;
    Bfb := B_fb_amba_out;
 
    if ins.txstart='1' and sero.ready='1' then
      v.txbussel := ins.bussel;
      v.txmask := '0';
    end if;

    if r.txbussel='1' then
      vlb_bito := B_bito_amba;
      if lb_datavalid='1' then B_datavalid := '0'; end if;
      if lb_done='0' then B_rxstarted := '0'; end if;
      Bfb.gapblock := Bfb.gapblock or lb_gapblock;
    else
      vlb_bito := A_bito_amba;
      if lb_datavalid='1' then A_datavalid := '0'; end if;
      if lb_done='0' then A_rxstarted := '0'; end if;
      Afb.gapblock := Afb.gapblock or lb_gapblock;
    end if;

    lb_bito <= vlb_bito;
    A_fb_amba_in <= Afb;
    B_fb_amba_in <= Bfb;
    
    ---------------------------------------------------------------------------
    -- Receiver selection

    -- Choose bus.
    -- If ins.anybus='1' and both receivers have valid data, we pick 
    -- the selected bus. 

    v.B_dv_deferred := '0';
    v.B_rxerr_deferred := '0';
    
    vrxbus := ins.bussel;    
    if shutdownA='1' then
      vrxbus := '1';
    elsif shutdownB='1' then
      vrxbus := '0';
    elsif ins.anybus='1' and A_datavalid='1' then
      vrxbus := '0';
      v.B_dv_deferred := B_datavalid;
      v.B_rxerr_deferred := B_s3o.lostsync or B_s3o.badparity;
    elsif ins.anybus='1' and (B_datavalid='1' or r.B_dv_deferred='1') then
      vrxbus:='1';
    end if;
    
    if vrxbus='1' then
      vrxstarted := B_rxstarted;
      vrxerror := (B_s3o.lostsync or B_s3o.badparity) or r.B_rxerr_deferred;
      vrxdone := B_datavalid or r.B_dv_deferred;
      vrxword := B_s3o.word;
    else
      vrxstarted := A_rxstarted;
      vrxerror := A_s3o.lostsync or A_s3o.badparity;
      vrxdone := A_datavalid;
      vrxword := A_s3o.word;
    end if;

    vo.rxbus := vrxbus;
    vo.rxstarted := vrxstarted;
    vo.rxerror := vrxerror;
    vo.rxdone := vrxdone;
    vo.rxword := vrxword;

    if ins.bussel='1' then vo.rxact:=B_bito_amba.act; else vo.rxact:=A_bito_amba.act; end if;
    
    ---------------------------------------------------------------------------
    -- Transmitter inputs

    vrxabort_a := '0'; vrxabort_b := '0';
    vseri := (abort => '0', start => ins.txstart, word => ins.txdata);
    if lb_error='1' or ins.txabort='1' or (regout and oreg.lberror='1') then
      vseri.abort := '1';
      v.txmask := '1';
    end if;
    if lb_error='1' or (regout and oreg.lberror='1') or (ins.txabort='1' and lb_done='0') then
      vrxabort_a := not r.txbussel;
      vrxabort_b := r.txbussel;
    end if;
    
    seri <= vseri;    
    A_rxabort <= vrxabort_a;
    B_rxabort <= vrxabort_b;

    ---------------------------------------------------------------------------
    -- Drive outputs

    vod := oreg;
    vod.txread_data := lb_readdata;
    vod.txready := sero.ready;
    
    if rst = '0' and syncrst /= 0 then
      v.txbussel := '0';
      v.txmask := '0';
    end if;

    noreg <= vo;
    if regout then      
      outs <= vod;
    else
      outs <= vo;
    end if;

    bmtap <= (started_A => A_s3o.started,
              datavalid_A => A_s3o.datavalid,
              lostsync_A => A_s3o.lostsync,
              badparity_A => A_s3o.badparity,
              word_A => A_s3o.word,
              started_B => B_s3o.started,
              datavalid_B => B_s3o.datavalid,
              lostsync_B => B_s3o.lostsync,
              badparity_B => B_s3o.badparity,
              word_B => B_s3o.word);  

    nr <= v;
  end process;

  cccomb: process(r,txout_pos,txout_neg,ccr,codec_rst,out_bito,shutdownA,shutdownB)
    variable v: ll_cc_regs;
    variable txbus: std_logic;
  begin
    v := ('0','0','0','0','0','0','0','0');
    v.txbus1 := r.txbussel;
    v.txbus2 := ccr.txbus1;
    txbus := ccr.txbus2;
    if sameclk/=0 then txbus:=r.txbussel; end if;
    if txbus='0' then
      v.txAP := txout_pos;
      v.txAN := txout_neg;
      v.txstartA := out_bito.txstarting;
    end if;
    if txbus='1' then
      v.txBP := txout_pos;
      v.txBN := txout_neg;
      v.txstartB := out_bito.txstarting;
    end if;
    -- Gate TX outputs with shutdownA/B and txmask. Gating for shutdown
    -- signals should not be needed unless wehave an internal fault
    -- (the core never transmits on a shutdown bus).
    -- Gating with txmask can happen in case of bus switching or loopback
    -- error, but should not happen in normal operation. 
    if shutdownA='1' or r.txmask='1' then
      v.txAP:='0'; v.txAN:='0';
    end if;
    if shutdownB='1' or r.txmask='1' then
      v.txBP:='0'; v.txBN:='0';
    end if;
    if codec_rst='0' and syncrst/=0 then
      v := ccr_rst;
    end if;
    nccr <= v;
    busA_tx_pos <= ccr.txAP;
    busA_tx_neg <= ccr.txAN;
    busB_tx_pos <= ccr.txBP;
    busB_tx_neg <= ccr.txBN;
    busA_reinit <= ccr.txstartA;
    busB_reinit <= ccr.txstartB;
  end process;
  
  regs: process(clk,rst)
  begin
    if rising_edge(clk) then
      oreg <= noreg;
      r <= nr;
    end if;
    if syncrst=0 and rst='0' then
      oreg <= gr1553b_codec_out_zero;
      r <=  r_rst;
    end if;
  end process;

  ccregs: process(codec_clk,codec_rst)
  begin
    if rising_edge(codec_clk) then
      ccr <= nccr;
    end if;
    if syncrst=0 and codec_rst='0' then
      ccr <= ccr_rst;
    end if;
  end process;
  
end;
