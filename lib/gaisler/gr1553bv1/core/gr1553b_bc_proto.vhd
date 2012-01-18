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
-- Entity:      gr1553b_bc_proto
-- File:        gr1553b_bc_proto.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B Bus Controller protocol manager state machine
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gr1553b_core.all;
library grlib;
use grlib.stdlib.all;

entity gr1553b_bc_proto is
  generic (
    syncrst: integer range 0 to 2
    );
  
  port(
    clk: in std_logic;
    rst: in std_logic;

    -- Higher layer interface
    ins: in gr1553b_bc_proto_in;
    outs: out gr1553b_bc_proto_out;    

    -- Timer tick
    us_restart: out std_logic;
    us_clear: out std_logic;
    us_tick: in std_logic;
    
    -- Lower layer tx/rx interface
    toll: out gr1553b_codec_in;
    fromll: in gr1553b_codec_out
    );
  attribute sync_set_reset of rst : signal is "true";
end;

architecture rtl of gr1553b_bc_proto is
    
  -- States:
  -- IDLE - start
  -- WTXRDY - wait until transmitter ready
  -- RT1CMD - start sending first comand word
  -- RT2CMD - send 2nd command word (RT2RT only)
  -- TXDATA - send data word
  -- WAITTX - wait for last sent word to leave transmitter
  -- ST1WAITSYNC/DATA - wait for status word from RT1
  -- RXWAITSYNC/DATA - receive data words from RT
  -- ST2WAITSYNC/DATA - wait for status word from RT2 (RT2RT only)
  -- MSGGAP - 4 us mid-par to mid-sync message gap
  -- EXTRAGAP - Extra gap time enabled using the extragap_en bit
  
  type bc_state is (IDLE,WTXRDY,RT1CMD,RT2CMD,TXDATA,WAITTX,ST1WAITSYNC,ST1WAITDATA,RXWAITSYNC,RXDATA,ST2WAITSYNC,ST2WAITDATA,MSGGAP,EXTRAGAP);

  -- The standard states we should wait minimum 14 us from middle of last
  -- data bit to mid of sync pulse. From end of last bit to end of first bit
  -- then becomes 16 us. 
  constant reply_timeout: integer := 15;
  -- Maximum time between end of last bit and end of first bit for "continuous"
  -- data words. This should be 4 us but we permit some gap.
  constant contin_timeout: integer := 5;
  constant discont_phase: integer := 1;
  -- 4 us minimum intermessage gap <=> 2 us bus off time + phase margin
  -- For non-broadcast transfers, we want to check that there are no extra data
  -- words coming after the last status or data word
  constant gap_time_bc: integer := 3;
  constant gap_time_reg: integer := contin_timeout;
  
  -- Extra time timeout unit of 4 us
  constant extra_time_unit: integer := 4;
  
  constant timer_max: integer := reply_timeout;

  type bcproto_regs is record
    st: bc_state;
    tfrtype: gr1553b_transfer_type;
    status: gr1553b_transfer_status;

    -- For receiving continuous data, the timer is used "free-running" to detect
    -- discontinuity. In that mode, it is reset in the transition
    -- ST1WAITSYNC->ST1WAITDATA, i.e. when rxstarted goes high. Discontinuity can
    -- then be detected when rxstarted='0' and timecnt='1'
    --
    -- When used in the "shadow" bus tracking mode, in RXWAITSYNC/DATA it's
    -- relative to the rxdone signal.
    --
    -- The timer is used as a "regular" timer in ST1/2WAITSYNC and MSGGAP and is
    -- reset on transition into these states
    timecnt: integer range 0 to 19;

    wcount: std_logic_vector(4 downto 0);
    stword1,stword2: std_logic_vector(7 downto 0);
    
    timeout_dcount: std_logic_vector(3 downto 0);

    shwsync: std_logic;
    qbus: std_logic;
    dwrap: std_logic;
    
    -- We need to cache this since the control layer may start fetching the
    -- next descriptor while we're waiting
    extragap_en: std_logic;
    
    validcmdA,validcmdB: std_logic;        
  end record;

  constant r_rst: bcproto_regs := (IDLE,TFR_INVALID,TFR_SUCCESS,0,"00000",x"00",x"00",x"0",'0','0','0','0','0','0');
  
  signal r,nr: bcproto_regs;
begin

  comb: process(rst,ins,fromll,r,us_tick)

    variable v: bcproto_regs;
    variable o: gr1553b_bc_proto_out;
    variable ci: gr1553b_codec_in;
    variable vus_restart: std_logic;
    variable vus_clear: std_logic;

    variable addr,exp_addr,sa_mc: std_logic_vector(4 downto 0);
    variable stword: std_logic_vector(7 downto 0);
    variable rto: std_logic;
    variable shadow: std_logic;
    variable timewrap: std_logic;
    variable stsrxdone: std_logic;    
    variable dec_wc: std_logic;
  begin
    -- Init vars
    v := r;
    o := (ready => '0', tfrdone => '0', data_out => fromll.rxword.data, dataout_write => '0', dataout_done => '0',
          datain_read => '0', datain_req => '0', validcmdA => r.validcmdA, validcmdB => r.validcmdB,
          status => r.status, stword1 => r.stword1, stword2 => r.stword2);
    ci := (txdata => (t => DATA, data => ins.data_in), txstart => '0', anybus => '0', txabort => '0',
           bussel => ins.tfrconfig.bussel);
    vus_restart := '0';
    vus_clear := '0';
    rto := '0';
    shadow := '0';    
    timewrap := '0';
    stsrxdone := '0';
    dec_wc := '0';
    v.validcmdA := '0';
    v.validcmdB := '0';
    
    if r.status=TFR_TIMEOUT or r.status=TFR_TIMEOUT2 or r.status=TFR_BUSERR or r.status=TFR_LBFAIL then
      shadow := '1';
      o.tfrdone := '1';
    end if;
    
    -- Comb logic        

    if us_tick='1' then
      
      if r.timecnt=15 then stsrxdone := '1'; end if;
        
      if r.timecnt=19 then
        v.timecnt := 0;
        timewrap := '1';
      elsif (r.st=ST1WAITSYNC or r.st=ST2WAITSYNC or r.st=EXTRAGAP) and
        (r.timeout_dcount /= "0000" and r.timecnt=extra_time_unit-1) then        
        v.timecnt := 0;
        v.timeout_dcount := std_logic_vector(unsigned(r.timeout_dcount) - 1);
      else
        v.timecnt := r.timecnt+1;
      end if;      

      if r.timecnt=reply_timeout then rto:='1'; end if;
      
    end if;

    if r.st=WTXRDY or r.st=RT1CMD or r.st=RT2CMD then
      ci.txdata.t := CMD_STAT;
      if r.st=RT1CMD or r.st=WTXRDY then        
        ci.txdata.data := ins.tfrconfig.rtaddr1 & ins.tfrconfig.tr & ins.tfrconfig.samc1 & ins.tfrconfig.wc_mode;
      else
        ci.txdata.data := ins.tfrconfig.rtaddr2 & '1' & ins.tfrconfig.samc2 & ins.tfrconfig.wc_mode;
      end if;
    end if;
    
    case r.st is

      
      when IDLE => 
        o.ready := '1';
        o.tfrdone := '1';
        v.extragap_en := ins.tfrconfig.extragap_en;
        vus_clear := '1';
        if ins.tfrstart='1' then
          v.stword1 := "00000000";
          v.stword2 := "00000000";
          v.tfrtype := classify_transfer(ins.tfrconfig);
          if v.tfrtype /= TFR_INVALID and ins.tfrconfig.dummy='0' then
            v.validcmdA := not ins.tfrconfig.bussel;
            v.validcmdB := ins.tfrconfig.bussel;
            v.st := WTXRDY;
            v.status := TFR_SUCCESS;
            v.wcount := ins.tfrconfig.wc_mode;
            if v.tfrtype=MODECMD_TX or v.tfrtype=MODECMD_RX or
              v.tfrtype=MODECMD_RX_BC then
              v.wcount := "00001";
            end if;
          else
            v.st := EXTRAGAP;
            if ins.tfrconfig.dummy='1' then
              v.status := TFR_SUCCESS;
            else
              v.status := TFR_BADCMD;
            end if;
          end if;
        end if;

        
      when WTXRDY => 
        vus_clear := '1';
        if fromll.txready='1' then
          ci.txstart := '1';
          v.st := RT1CMD;
        end if;


      when RT1CMD =>
        vus_clear := '1';
        if fromll.lberror='1' or fromll.txready='1' then
          -- Error while sending sync pulse          
          v.st := MSGGAP;
          v.status := TFR_LBFAIL;
          
        elsif fromll.txread_data='1' then
          v.st := RT2CMD;
          -- Skip command word #2 unless RT-to-RT transfer
          if r.tfrtype /= RT2RT and r.tfrtype /= RT2RT_BC then
            v.st := TXDATA;
            -- Skip transmit data words if appropriate
            if r.tfrtype /= CTRL2RT and r.tfrtype /= MODECMD_RX and
              r.tfrtype /= CTRL2RT_BC and r.tfrtype /= MODECMD_RX_BC then
              v.st := WAITTX;
            end if;
            
          end if;      
        end if;


      when RT2CMD => 
        vus_clear := '1';
        ci.txstart := '1';

        if fromll.lberror='1' then
          ci.txstart := '0';
          v.st := MSGGAP;
          v.status := TFR_LBFAIL;
        elsif fromll.txread_data='1' then
          -- Always fall through to WAITTX (the BC never sends data in RT2RT)
          v.st := WAITTX;
        end if;

        
      when TXDATA => 
        vus_clear := '1';
        o.datain_req := '1';
        if ins.datain_valid='1' then
          ci.txstart := '1';
        end if;
        
        if fromll.lberror='1' then
          ci.txstart := '0';
          v.status := TFR_LBFAIL;
          v.st := MSGGAP;
        elsif fromll.txready='1' and ins.datain_valid='0' then
          v.status := TFR_DMAERR;
          v.st := MSGGAP;
        -- elsif fromll.txready='1' then
        --  vtxstart := '1';
        elsif fromll.txread_data='1' then
          o.datain_read := '1';
          v.wcount := std_logic_vector(unsigned(r.wcount)-1);
          if v.wcount="00000" then
            v.st := WAITTX;
          end if;
        end if;  


      when WAITTX =>
        -- Don't start the timer until the command word has passed through loopback
        if fromll.lberror='1' then
          v.status := TFR_LBFAIL;
          v.st := ST1WAITSYNC; -- MSGGAP;
          vus_restart := '1';
        elsif fromll.txready='1' and fromll.lbdone='1' then 
          v.st := ST1WAITSYNC;
          vus_restart := '1';
        end if;

        -- Fall through WAITTX->ST1WAITSYNC->ST1WAITDATA->RXDATA->ST2WAIT->MSGGAP
        if v.st=ST1WAITSYNC and (r.tfrtype=CTRL2RT_BC or r.tfrtype=MODECMD_BC or r.tfrtype=MODECMD_RX_BC) and
          ins.fast_broadcast='1' then
          v.st := MSGGAP;
        end if;


      when ST1WAITSYNC | ST2WAITSYNC =>
        v.shwsync := '0';
        v.dwrap := '0';
        if r.st=ST1WAITSYNC and fromll.lberror='1' then
          v.status := TFR_LBFAIL;          
          -- Following cycle shadow will be '1'
        end if;

        -- Heuristic to distinguish between timeout and bus error.
        -- There are always "unclean" cases where they can't be told apart.
        if us_tick='1' and r.timecnt=reply_timeout-5 then
          if fromll.rxact='0' and shadow='0' then
            v.qbus := '1';
          else
            v.qbus := '0';
          end if;
        end if;
        
        if fromll.rxstarted='1' then
          if (r.tfrtype=CTRL2RT_BC or r.tfrtype=MODECMD_BC or r.tfrtype=MODECMD_RX_BC) or
            (r.st=ST2WAITSYNC and r.tfrtype=RT2RT_BC) then
            v.status := TFR_BUSERR;
          end if;
          v.st:=ST1WAITDATA;
          if r.st=ST2WAITSYNC then v.st:=ST2WAITDATA; end if;
          vus_restart := '1';
          v.shwsync := '1';
          
        elsif rto='1' then

          if shadow='0' then
            v.status := TFR_TIMEOUT;
            if r.st=ST2WAITSYNC then v.status := TFR_TIMEOUT2; end if;
            if r.qbus='0' then v.status:=TFR_BUSERR; end if;
            
            if (r.tfrtype=CTRL2RT_BC or r.tfrtype=MODECMD_BC or r.tfrtype=MODECMD_RX_BC) then
              v.status := TFR_SUCCESS;
            end if;
            if r.st=ST2WAITSYNC and r.tfrtype=RT2RT_BC then
              v.status := TFR_SUCCESS;
            end if;            
          end if;
          
          vus_restart := '1';
          v.st := ST1WAITDATA;
          if r.st=ST2WAITSYNC then v.st := ST2WAITDATA; end if;
          -- If fromll.rxact='1' we keep going, but we will be in shadow mode
          if fromll.rxact='0' and r.qbus='1' then
            v.st := IDLE;
          end if;
        end if;      
        

      when ST1WAITDATA | ST2WAITDATA =>
        if shadow='1' or (r.tfrtype=CTRL2RT_BC or r.tfrtype=MODECMD_BC or r.tfrtype=MODECMD_RX_BC) or
          (r.st=ST2WAITDATA and r.tfrtype=RT2RT_BC) then
          
          if fromll.rxact='0' and r.shwsync='1' then
            v.st := MSGGAP;
          elsif (r.shwsync='1' and stsrxdone='1') or (r.shwsync='0' and (fromll.rxact='0' or timewrap='1')) then
            v.timecnt := 0;
            if r.st=ST1WAITDATA then
              v.st := RXWAITSYNC;
            else
              v.st := MSGGAP;
            end if;
          end if;
          
        elsif fromll.rxdone='1' then
          -- Validate status word
          addr := fromll.rxword.data(15 downto 11);
          exp_addr := ins.tfrconfig.rtaddr1;
          if r.st=ST1WAITDATA and (r.tfrtype=RT2RT or r.tfrtype=RT2RT_BC) then
            exp_addr := ins.tfrconfig.rtaddr2;
          end if;
          if fromll.rxword.t /= CMD_STAT or addr /= exp_addr then
            v.status := TFR_BUSERR;
            -- Go into shadow mode
            -- v.st := MSGGAP;
            -- if r.st=ST2WAITDATA then v.st:=IDLE; end if;
          else
            stword := fromll.rxword.data(10) &
                      (fromll.rxword.data(9) or fromll.rxword.data(7) or fromll.rxword.data(6) or fromll.rxword.data(5) ) &
                      fromll.rxword.data(8) & fromll.rxword.data(4 downto 0);
            if r.st=ST1WAITDATA then
              v.stword1 := stword;
              v.st := RXWAITSYNC;
            else
              v.stword2 := stword;
              v.st := MSGGAP;
            end if;
            
            -- Check instrumentation bit or reserved bits
            if stword(6)='1' then
              -- We don't stop the processing here.
              -- We will probably get another error before the transfer ends, but
              -- set RTERROR response as default
              v.status := TFR_RTERROR;
            end if;
            
            -- Check message error and busy bits
            if fromll.rxword.data(10) = '1' or fromll.rxword.data(3)='1' then
              v.status := TFR_RTERROR;
              -- Normally we could stop processing here. Except, Transmit
              -- Last Command might return a status word with
              -- message error bit set followed by a data word.
            end if;
          end if;
        elsif fromll.rxerror='1' then
          v.status := TFR_BUSERR;
          -- v.st := MSGGAP;
          -- if r.st=ST2WAITDATA then v.st:=IDLE; end if;
        end if;

        -- Fall through for transfers w/o data
        if (v.st=RXWAITSYNC) and r.tfrtype /= RT2CTRL and r.tfrtype /= RT2RT and r.tfrtype /= MODECMD_TX and
          r.tfrtype/= RT2RT_BC then
          v.st := MSGGAP;
        end if;

        
      when RXWAITSYNC =>
        v.dwrap := '0';
        
        if shadow='1' then
          
          if r.timecnt=contin_timeout then
            v.st := RXDATA;
          end if;
          
        elsif fromll.rxstarted='1' then
          v.st:=RXDATA;
        elsif r.timecnt=discont_phase then
          v.status := TFR_BUSERR;
          if fromll.rxact='0' then v.st := MSGGAP; end if;
        end if;
        

      when RXDATA =>
        if r.timecnt=9 and us_tick='1' then v.dwrap:='1'; end if;
        
        -- Need to reset timeout_count here for second status word in RT-to-RT transfers
        v.timeout_dcount := ins.tfrconfig.extratime;
        if shadow='1' then
          
          if fromll.rxact='0' or timewrap='1' then
            dec_wc := '1';
          end if;          
          
        elsif fromll.rxdone='1' and fromll.rxword.t=DATA then
          o.dataout_write := '1';
          v.dwrap := '0';
          dec_wc := '1';
        elsif fromll.rxerror='1' or fromll.rxdone='1' then
          v.status := TFR_BUSERR;
          -- vnst := MSGGAP; Keep going in shadow mode instead
          -- Special case if phrxdone already happened
          if r.dwrap='1' then dec_wc:='1'; end if;
          
        end if;
        
        if dec_wc='1' then
          v.wcount := std_logic_vector(unsigned(r.wcount)-1);
          if v.wcount="00000" then
            v.st := ST2WAITSYNC;
            vus_restart := '1';
            if r.tfrtype /= RT2RT and (ins.fast_broadcast='1' or r.tfrtype /= RT2RT_BC) then
              v.st := MSGGAP;
            end if;
          else
            v.st := RXWAITSYNC;
          end if;        
        end if;
        

      when MSGGAP =>

        if r.tfrtype=RT2CTRL or r.tfrtype=RT2RT or r.tfrtype=MODECMD_TX or r.tfrtype=RT2RT_BC then
          o.dataout_done := '1';
        end if;
      
        if (r.tfrtype=CTRL2RT or r.tfrtype=RT2CTRL or r.tfrtype=RT2RT or r.tfrtype=MODECMD or r.tfrtype=MODECMD_TX or
            r.tfrtype=MODECMD_RX or r.tfrtype=RT2RT_BC) and r.status=TFR_SUCCESS then
          
          if ins.data_error='1' then
            v.status := TFR_DMAERR;
          -- Check for extra word
          elsif fromll.rxstarted='1' then
            v.status := TFR_BUSERR;          
          elsif r.timecnt = gap_time_reg then
            o.tfrdone := '1';
            v.timecnt := 0;
            v.st := EXTRAGAP;
          end if;
          
        else
          
          -- Broadcast command or error
          o.tfrdone := '1';
          if r.timecnt = gap_time_bc then
            v.timecnt := 0;
            v.st := EXTRAGAP;
          end if;
          
        end if;                

      when EXTRAGAP =>
        o.tfrdone := '1';        
        if r.extragap_en='0' or r.timeout_dcount="0000" then
          v.st := IDLE;
        end if;
        
    end case;
    
    if v.st=MSGGAP and r.st /= MSGGAP then
      vus_restart := '1';
    end if;
    
    if vus_restart='1' or vus_clear='1' then
      v.timecnt := 0;
      v.timeout_dcount := ins.tfrconfig.extratime;
    end if;
    
    if rst='0' and syncrst/=0 then
      v.st := r_rst.st;
      v.status := r_rst.status;
      if syncrst > 1 then
        v := r_rst;
      end if;
    end if;

    if (r.st=WTXRDY or r.st=RT1CMD or r.st=RT2CMD) and 
      (r.tfrtype=CTRL2RT or r.tfrtype=MODECMD_RX or r.tfrtype=CTRL2RT_BC or r.tfrtype=MODECMD_RX_BC) then
      o.datain_req := '1';
    end if;

    -- Assign outputs
    nr <= v;
    toll <= ci;
    us_restart <= vus_restart;
    us_clear <= vus_clear;
    outs <= o;    
    
  end process;
    
  regs: process(clk,rst)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
    if rst='0' and syncrst=0 then
      r <= r_rst;
    end if;
  end process;
  
end;
