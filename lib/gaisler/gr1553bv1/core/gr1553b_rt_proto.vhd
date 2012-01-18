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
-- Entity:      gr1553b_rt_proto
-- File:        gr1553b_rt_proto.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B Remote Terminal protocol manager state machine
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gr1553b_core.all;
library grlib;
use grlib.stdlib.all;

entity gr1553b_rt_proto is
  generic (
    syncrst: integer range 0 to 2
    );
  
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
  attribute sync_set_reset of rst : signal is "true";
end;

architecture rtl of gr1553b_rt_proto is
  
  type rt_state is (IDLE, GOTINVRECV, GOTCMD, WAITRECV, WAITOTHERSTATUS, WAITRECVDATA, WAITVALID, WAITVALID2, SENDSTATUS, WAITTXSTATUS, SENDDATA);

  -- Allow a minimum of 1 us and maximum of 2 us slack between continuous words (+nominal end-parity
  -- to end-firstbit of 4 us)
  constant begin_thres: integer := 5;
  constant slack_thres: integer := 1;
  
  -- The standards response req is 4-12 us midbit to midsync => 2-10 us bus dead time.
  -- However, to verify the word count we need to check for an unexpected data sync
  -- This needs at least 4 us of waiting.
  constant status_delay_min: integer := begin_thres;
  constant status_delay_max: integer := 9;
  
  -- Notice II adds RT-to-RT requirement for the receiving RT that first data word
  -- should be verified to arrive in less than 54-60 us after the receive command word
  -- measured mid-parity to mid-sync.
  --
  -- Translated to end of RX command word to end of TX status word -> 52-58 us
  -- Because we allow 1-2 us of slack on the data word, this becomes 52-56 us
  -- Translated to end of first bit of TX status word (when rxstarted goes
  -- high) -> 36-40 -> use 39 as threshold
  --
  -- When the timeout for rxstarted is reached,
  -- timer1=19 and timer2=1
  constant otherstatus_to1: integer := 19;  -- 39 mod 20
  constant otherstatus_to2: integer := 1;
  
  type rtpr_regs is record
    st: rt_state;
    cmd: std_logic_vector(15 downto 0);
    cmdbus: std_logic;
    other_addr: std_logic_vector(4 downto 0);
    waitdata_wc: std_logic_vector(4 downto 0);
    msgerr: std_logic;
    bcrec: std_logic;
    timer2: integer range 0 to 1;
    timer1: integer range 0 to 19;
    lastcmd_flag: std_logic;
    laststat_flag: std_logic;
    validcmdA,validcmdB: std_logic;
  end record;

  constant r_rst: rtpr_regs := (IDLE,x"0000",'0',"00000","00000",'0','0',0,0,'0','0','0','0');
  
  signal r,nr: rtpr_regs;
  
begin

  comb: process(rst,ins,fromll,r,us_tick)
    variable v: rtpr_regs;
    variable o: gr1553b_rt_proto_out;
    variable cin: gr1553b_codec_in;
    variable vus_restart: std_logic;
    variable vus_clear: std_logic;
    
    variable rxw_addr,rxw_samc,rxw_wcmc,cmd_addr,cmd_samc,cmd_wcmc: std_logic_vector(4 downto 0);
    variable rxw_tr,rxw_instr,cmd_tr,cmd_bc: std_logic;
    variable rxword_is_valid_cmd: boolean;
    variable rxword_is_illegal_bc_cmd: boolean;
    variable rxword_is_check: boolean;
    
    variable validcmd: std_logic;

    variable cmd_is_illegal_mc: boolean;
    
  begin
    -- Init vars
    v := r;

    v.validcmdA := '0';
    v.validcmdB := '0';
    
    cmd_addr := r.cmd(15 downto 11);
    cmd_tr := r.cmd(10);
    cmd_samc := r.cmd(9 downto 5);
    cmd_wcmc := r.cmd(4 downto 0);
    if cmd_addr="11111" then cmd_bc:='1'; else cmd_bc:='0'; end if;    
    
    o := (request => (t => NOREQ, subaddr => cmd_samc, wc_mode => cmd_wcmc,
                      bc => cmd_bc, cmdbus => r.cmdbus),
          result => PROGRESS,
          datain_read => '0', dataout_write => '0', data_out => fromll.rxword.data,
          validcmdA => r.validcmdA, validcmdB => r.validcmdB, txdone => fromll.lbdone, status_next => '0');

    cin := (bussel => r.cmdbus, anybus => '1',
            txstart => '0', txdata => (t => DATA, data => ins.data_in),
            txabort => '0');
    
    validcmd := '0';
    vus_restart := '0';
    vus_clear := '0';

    -- Comb. logic used by FSM
    rxw_addr := fromll.rxword.data(15 downto 11);
    rxw_tr := fromll.rxword.data(10);
    rxw_samc := fromll.rxword.data(9 downto 5);
    rxw_wcmc := fromll.rxword.data(4 downto 0);

    rxword_is_illegal_bc_cmd := false;
    if fromll.rxword.t=DATA then
      rxword_is_valid_cmd := false;
    elsif rxw_addr /= ins.my_addr and (rxw_addr /= "11111" or ins.allow_broadcast='0') then
      rxword_is_valid_cmd := false;
    elsif (rxw_addr="11111" and ins.allow_broadcast='1' and rxw_tr='1' and
           ((rxw_samc/="00000" and rxw_samc/="11111") or rxw_wcmc(4)='1' or rxw_wcmc="00010")) then
      
      -- Transmit data command with broadcast address or
      -- Mode command with transmit data word and broadcast address or
      -- Broadcast transmit status word

      -- These satisfy the requirements for a valid command, however they are
      -- not allowed. Therefore, they have to be illegal
      
      rxword_is_valid_cmd := true;
      rxword_is_illegal_bc_cmd := true;
      
    -- elsif ((rxw_samc="00000" or rxw_samc="11111") and not modecode_valid(rxw_wcmc,rxw_tr)) then
      -- Mode command with reserved mode code
      --
      -- There are two kinds of reserved mode codes:
      -- 
      -- Mode codes and T/R combinations that are not listed in the original MIL-STD-1553B
      -- (called Undefined and marked as Reserved* in AS15531 Table 1):
      --   Mode codes < 16 with TR bit=0
      --   Mode codes with opposite T/R bit to which they are defined
      -- Unused mode code values (listed as Reserved in both MIL-STD-1553 and AS15531)

      -- These satisfy the requirements for a valid command, however they are
      -- not allowed. Therefore, they have to be illegal
      
      -- rxword_is_valid_cmd := true;
      
    else
      rxword_is_valid_cmd := true;
    end if;

    -- Check if rxword is send status or send last command mode code.
    rxword_is_check := false;
    if rxw_addr = ins.my_addr and (rxw_samc="00000" or rxw_samc="11111") and rxw_tr='1' and (rxw_wcmc="00010" or rxw_wcmc="10010") then
      rxword_is_check := true;
    end if;

    cmd_is_illegal_mc := false;
    if (cmd_samc="00000" or cmd_samc="11111") and not modecode_valid(cmd_wcmc,cmd_tr) and
      r.lastcmd_flag='0' then
      cmd_is_illegal_mc := true;
    end if;
    
    
    ---------------------------------------------------------------------------
    -- State machine transitions

    if r.st=IDLE or r.st=GOTINVRECV then
      if r.st=IDLE then vus_clear := '1'; end if;
      
      if ins.enable='0' or (fromll.rxstarted='0' and r.timer1=begin_thres) then
        v.st:=IDLE;
      end if;
      
      if ins.enable='1' and fromll.rxdone='1' then
        if rxword_is_illegal_bc_cmd then
          v.bcrec := '1'; 
          v.msgerr := '1';
          v.cmd := fromll.rxword.data;
          v.st := IDLE;
        elsif rxword_is_valid_cmd and
          (r.st=IDLE or fromll.rxbus/=r.cmdbus or rxw_tr='0' or (rxw_samc/="00000" and rxw_samc/="11111")) then
          v.st := GOTCMD;
        elsif r.st=IDLE and fromll.rxword.t=CMD_STAT and rxw_tr='0' then
          v.st := GOTINVRECV;
          v.cmdbus := fromll.rxbus;
        else
          if rxword_is_valid_cmd then
            v.msgerr := '1';
            v.cmd := fromll.rxword.data;
            if rxw_addr="11111" then v.bcrec:='1'; else v.bcrec:='0'; end if;
          end if;
          v.st := IDLE;
        end if;
      end if;
    end if;

    if r.st=GOTCMD then cin.txabort := '1'; end if;
        
    if r.st=GOTCMD and fromll.rxdone='1' and fromll.rxword.t=CMD_STAT and rxword_is_valid_cmd then
      v.st := GOTCMD;
      o.result := SUPERSEDED;
      
    elsif r.st=GOTCMD then

      v.waitdata_wc := cmd_wcmc;

      if r.lastcmd_flag='1' or r.laststat_flag='1' then
        -- Wait for the minimum response time
        v.st := WAITVALID;
        
      elsif cmd_samc /= "00000" and cmd_samc /= "11111" and cmd_tr='0' then
        -- Receive command, wait for next data or status word
        -- 
        v.st := WAITRECV;
      elsif (cmd_samc="00000" or cmd_samc="11111") and cmd_wcmc(4)='1' then
        -- Mode command with one data byte, wait for the data byte        
        v.st := WAITRECVDATA;
        v.waitdata_wc := "00001";
        if cmd_tr='1' then v.st:=WAITVALID; end if;
      else
        -- Wait for upper layer to accept the command 
        v.st := WAITVALID;
      end if;
    end if;
    
    if r.st=WAITRECV then

      if fromll.rxdone='1' and fromll.rxword.t=DATA and fromll.rxbus=r.cmdbus then
        -- First data word of BC->RT transfer
        if ins.dataout_ready='1' then
          o.dataout_write := '1';
          v.st := WAITRECVDATA;
          if cmd_wcmc = "00000" then
            v.waitdata_wc := "11111";
          else
            v.waitdata_wc := std_logic_vector(unsigned(cmd_wcmc) - 1);
          end if;
          if cmd_wcmc="00001" then
            v.st := WAITVALID;
          else
            v.st := WAITRECVDATA;
          end if;
        else
          -- We have data to write but the layer above is not ready.
          --
          -- The system should be designed so this can not happen, so
          -- this is a worst-case fallback.  The BC will not get a
          -- status word, so it notices that something's gone
          -- wrong. If we're doing a broadcast receive, the broadcast
          -- command received bit will not be set.
          o.result := TIMEOUT;
          v.st := IDLE;
        end if;
        
      elsif fromll.rxdone='1' and rxw_tr='1' and rxw_addr/="11111" and fromll.rxbus=r.cmdbus and
        (rxw_samc /= "00000" and rxw_samc /= "11111") then
        -- Second command word of RT->RT command
        -- There are four (valid) cases:
        --   1. Non-broadcast, we're receiving
        --     First word is a receive word with our address which makes us
        --     reach this state.
        --     At this point, there is a transmit word for another RT.
        --     We make sure it's word count matches, and goto WAITOTHERSTATUS
        --   2. Non-broadcast, we're transmitting
        --     First word is a receive word with another address, so it gets ignored
        --     The second word is treated the same way as an RT->CTRL transmit
        --     Thus, we never reach this state
        --   3. Broadcast, we're receiving
        --     First word is a receive word with broadcast addr, we reach this
        --     state.
        --     At this point, there is a transmit word for another RT. 
        --     Handle this the same way as case 1. Only difference is
        --     we don't send out the status word when reaching the SENDSTATUS
        --     state.
        --   4. Broadcast, we're transmitting
        --     First word is a receive word with broadcast addr, we reach this
        --     state.
        --     At this point, there is a transmit word with our addr.
        --     Treat this command word as a superceding command 
        
        if rxw_wcmc /= cmd_wcmc then
          -- Word count mismatch
          o.result := BUSERROR;
          v.st := IDLE;
          v.msgerr := '1';
        elsif rxw_addr=ins.my_addr then
          -- Case 4 above
          o.result := SUPERSEDED;
          v.st := WAITVALID;
          v.bcrec := '0';
          v.cmd := fromll.rxword.data;          
        else
          -- Case 1 or 3
          v.st := WAITOTHERSTATUS;
          v.other_addr := rxw_addr;
          
        end if;

      elsif fromll.rxdone='1' and fromll.rxbus=r.cmdbus and rxw_tr='1' then
        -- Transmit mode command in RT-to-RT message format
        o.result := BUSERROR;
        v.st := IDLE;
        v.msgerr := '1';

        
      elsif fromll.rxdone='1' and rxword_is_valid_cmd then
          -- Superseding valid command on either bus
          o.result := SUPERSEDED;
          v.st := GOTCMD;
          
      elsif fromll.rxdone='1' and fromll.rxbus=r.cmdbus then
        -- Invalid command om same bus - fail
        o.result := BUSERROR;
        v.st := IDLE;
        v.msgerr := '1';
        
      elsif fromll.rxstarted='0' and r.timer1 = begin_thres then

        -- Discontinuous message - fail
        o.result := BUSERROR;
        v.st := IDLE;
        v.msgerr := '1';

      end if;
      
    end if;

    if r.st=WAITOTHERSTATUS then      
      -- Check instrumentation bit data(9) and message error bit data(10)
      if fromll.rxdone='1' and fromll.rxword.t = CMD_STAT and rxw_addr=r.other_addr and
        fromll.rxword.data(10)='0' and fromll.rxword.data(9)='0' and
        fromll.rxbus=r.cmdbus and r.msgerr='0' then 
        v.st := WAITRECVDATA;
        v.waitdata_wc := cmd_wcmc;
        vus_restart := '1';
      elsif fromll.rxdone='1' and rxword_is_valid_cmd then
        o.result := SUPERSEDED;
        v.st := GOTCMD;
      elsif fromll.rxdone='1' and fromll.rxbus=r.cmdbus then
        o.result := BUSERROR;
        v.st := IDLE;
        v.msgerr := '1';

      elsif fromll.rxstarted='0' and r.timer2=otherstatus_to2 and r.timer1=otherstatus_to1 then
        o.result := BUSERROR;
        v.st := IDLE;
        v.msgerr := '1';                
      end if;
      
    end if;
    
    if r.st=WAITRECVDATA then
      
      if fromll.rxdone='1' and fromll.rxword.t = DATA and fromll.rxbus=r.cmdbus then

        if cmd_is_illegal_mc then
          v.st := WAITVALID;
        elsif ins.dataout_ready='1' then
          o.dataout_write := '1';
          if r.waitdata_wc="00000" then
            v.waitdata_wc := "11111";
          elsif r.waitdata_wc/="00001" then
            v.waitdata_wc := std_logic_vector(unsigned(r.waitdata_wc)-1);
          else
            v.st := WAITVALID;
          end if;
        else          
          o.result := TIMEOUT;
          v.st := IDLE;
        end if;
          
      elsif fromll.rxdone='1' and rxword_is_valid_cmd then
        -- Superseding valid command
        o.result := SUPERSEDED;
        v.st := GOTCMD;
        
      elsif fromll.rxdone='1' and fromll.rxbus=r.cmdbus then
        -- Invalid command word        
        o.result := BUSERROR;
        v.st := IDLE;
        v.msgerr := '1';
        
        
      elsif fromll.rxstarted='0' and r.timer1=begin_thres then

        o.result := BUSERROR;
        v.st := IDLE;
        v.msgerr := '1';
        
      end if;
    end if;

    if r.st=WAITVALID then
      -- Priority:
      -- 1. Superseding command
      if fromll.rxdone='1' and rxword_is_valid_cmd then
        o.result := SUPERSEDED;
        v.st := GOTCMD;
      -- 2. Bus error: unexpected data word received
      -- rxdone is also checked to ignore data words from other bus
      elsif fromll.rxdone='0' and fromll.rxstarted='1' then
        o.result := BUSERROR;
        v.msgerr := '1';
        v.st := IDLE;
      -- 3. Minimum timer value passed (to ensure no unexp data word)
      elsif r.timer1 = status_delay_min then
        v.st := WAITVALID2;
      end if;
    end if;

    if r.st=WAITVALID2 then
      -- Priority:
      -- 1. Superseding command
      if fromll.rxdone='1' and rxword_is_valid_cmd then
        o.result := SUPERSEDED;
        v.st := GOTCMD;
      -- 2. Bus error: unexpected data word received
      elsif fromll.rxdone='0' and fromll.rxstarted='1' then
        o.result := BUSERROR;
        v.msgerr := '1';
        v.st := IDLE;
      -- 3. Minimum timer value passed (to ensure no unexp data word)
      -- 4. Last command / Last status word /  BCMC handling
      elsif (r.lastcmd_flag='1' or r.laststat_flag='1' or cmd_is_illegal_mc) then
        v.st := SENDSTATUS;
        if cmd_is_illegal_mc then v.msgerr:='1'; end if;
      elsif cmd_addr="11111" and (cmd_samc="00000" or cmd_samc="11111") and cmd_wcmc(4)='0' then
        -- Broadcast mode command without data
        -- This is a special case because the RT control layer has no way to
        -- refuse this broadcast
        if ins.req_resp=REQILLEGAL then
          v.msgerr := '1';
          v.st := IDLE;
          -- We re-use the message error sent error code in this special case
          o.result := MSGERRSENT;
        elsif ins.req_resp=REQOK then
          o.result := SUCCESS;
          v.st := IDLE;
        end if;
      -- 5. Ordinary command, response received
      elsif ins.req_resp /= UNKNOWN then
        v.st := SENDSTATUS;
        o.status_next := '1';
        if ins.req_resp=REQILLEGAL then
          v.msgerr := '1';
        end if;
      -- 6. Timeout
      elsif r.timer1 = status_delay_max then
        o.result := TIMEOUT;
        v.st := IDLE;
      end if;
    end if;

    if r.st=SENDSTATUS or r.st=WAITTXSTATUS then
      cin.txdata.t := CMD_STAT;
      cin.txdata.data := ins.my_addr & r.msgerr & '0' & ins.statusbits(4) & "000" & r.bcrec & ins.statusbits(3 downto 0);
      -- Mask out Dynamic Bus Control acceptance unless we are
      -- responding to a DBC mode code. Mask out the busy bit if we are
      -- responding to a reset remote terminal command
      if r.lastcmd_flag='1' or r.laststat_flag='1' or (cmd_samc/="00000" and cmd_samc/="11111") then
        -- Not mode code
        cin.txdata.data(1) := '0';
      else
        -- Mode code
        if cmd_wcmc/="00000" then
          cin.txdata.data(1) := '0';    --DBCA
        end if;        
        if cmd_wcmc="01000" then
          cin.txdata.data(3) := '0';    --Busy
        end if;
      end if;
    end if;

    if r.st=SENDSTATUS then
      vus_clear := '1';
      if fromll.rxdone='1' and rxword_is_valid_cmd then
        o.result := SUPERSEDED;
        v.st := GOTCMD;
      elsif cmd_addr="11111" and not (r.lastcmd_flag='1' or r.laststat_flag='1') then
        o.result := SUCCESS;
        v.st := IDLE;
      elsif fromll.txready='1' then
        cin.txstart := '1';
        v.st := WAITTXSTATUS;
      end if;
    end if;

    if r.st=WAITTXSTATUS then
      vus_clear := '1';
      if fromll.rxdone='1' and rxword_is_valid_cmd then
        o.result := SUPERSEDED;
        v.st := GOTCMD;
        cin.txabort := '1';
      elsif r.laststat_flag='1' then
        if fromll.txread_data='1' then
          o.result := SUCCESS;
          v.st := IDLE;
        end if;
      elsif r.lastcmd_flag='1' then
        cin.txstart := '1';
        if fromll.txread_data='1' then
          v.st := SENDDATA;
        end if;
      elsif r.msgerr='1' or cin.txdata.data(3)='1' then          
        -- If we're flagging an error or busy bit, we don't send the data.
        if fromll.txread_data='1' then
          o.result := MSGERRSENT;
          v.st := IDLE;
        end if;
      elsif (cmd_samc="00000" or cmd_samc="11111") and cmd_wcmc(4)='1' and cmd_tr='1' then
        -- Mode command with one data word transmit
        cin.txstart := ins.datain_valid;
        if fromll.txread_data='1' then
          v.st := SENDDATA;
        end if;
      elsif cmd_samc/="00000" and cmd_samc/="11111" and cmd_tr='1' then
        -- Transmit command
        cin.txstart := ins.datain_valid;
        if fromll.txread_data='1' then
          v.st := SENDDATA;
        end if;
      else
        if fromll.txread_data='1' then
          o.result := SUCCESS;
          v.st := IDLE;
        end if;
      end if;

    end if;
    
    if r.st=SENDDATA then
      vus_clear := '1';
      if r.lastcmd_flag='1' then
        cin.txstart := '1';
        cin.txdata := (t=>DATA, data=>r.cmd);
      else
        cin.txstart := ins.datain_valid;
      end if;

      if fromll.txready='1' then
        if r.lastcmd_flag='1' then
          -- None
        elsif ins.datain_valid='0' then
          o.result := TIMEOUT;
          v.st := IDLE;
        end if;          
      end if;
      
      if fromll.txread_data='1' then
        if r.lastcmd_flag='1' then
          v.st := IDLE;
        else
          o.datain_read := '1';
          if r.waitdata_wc="00001" then
            o.result := SUCCESS;
            v.st := IDLE;
          elsif r.waitdata_wc="00000" then
            v.waitdata_wc := "11111";
          else
            v.waitdata_wc := std_logic_vector(unsigned(r.waitdata_wc) - 1);
          end if;
        end if;
      end if;
      
      if fromll.rxdone='1' and rxword_is_valid_cmd then
        o.result := SUPERSEDED;
        v.st := GOTCMD;
        cin.txabort := '1';
        cin.txstart := '0';
      end if;
      
    end if;
    
    if v.st=GOTCMD then
      validcmd := '1';
      vus_restart := '1';
      v.cmdbus := fromll.rxbus;
      v.laststat_flag := '0';
      v.lastcmd_flag := '0';
      
      if not rxword_is_check then
        v.cmd := fromll.rxword.data;
        v.msgerr := '0';
        if rxw_addr="11111" then
          v.bcrec := '1';
        else
          v.bcrec := '0';
        end if;
        
      elsif rxw_wcmc(4) = '1' then
        v.lastcmd_flag := '1';
        
      else
        
        -- The only words excluded from the transmit last command mode code are
        -- invalid commands and the transmit last command mode code itself
        -- NOT the transmit status word command.
        -- Thus, a transmit status word followed by transmit last command
        -- should return the transmit status word mode code
        v.cmd := fromll.rxword.data;
        
        v.laststat_flag := '1';
      end if;
    end if;

    if v.st=WAITVALID and r.st/=WAITVALID then vus_restart:='1'; end if;
    
    if validcmd='1' then
      if v.cmdbus='1' then
        v.validcmdB := '1';
      else
        v.validcmdA := '1';
      end if;
    end if;
    
    if vus_restart='1' or vus_clear='1' then
      v.timer1 := 0;
      v.timer2 := 0;
    else      
      if us_tick='1' then
        if r.timer1 = 19 then
          v.timer1 := 0;
          if r.timer2 = 1 then
            v.timer2 := 0;
          else
            v.timer2 := r.timer2+1;
          end if;
        else
          v.timer1 := r.timer1+1;
        end if;
      end if;
    end if;  
    
    ---------------------------------------------------------------------------

    if r.st=IDLE or r.st=GOTINVRECV or r.lastcmd_flag='1' or r.laststat_flag='1' or cmd_is_illegal_mc or
      o.result=SUPERSEDED then
      o.request.t := NOREQ;
    elsif cmd_samc /= "00000" and cmd_samc /= "11111" then
      if cmd_tr='1' then
        o.request.t := XMIT;
      else
        o.request.t := RECV;
      end if;
    elsif cmd_wcmc(4)='0' then
      o.request.t := MODECMD;
    elsif cmd_tr='1' then
      o.request.t := MODECMD_XMIT;
    else
      o.request.t := MODECMD_RECV;      
    end if;
    
    if fromll.lberror='1' then
      v.st := IDLE;
      o.result := LBERROR;
    end if;

    if r.st = IDLE and ins.enable='0' then
      v.msgerr := '0';
      v.bcrec := '0';
      v.cmd := (others => '0');
    end if;
      
    if rst='0' and syncrst/=0 then
      v.st := IDLE;
      v.msgerr := '0';
      v.bcrec := '0';
      v.cmd := (others=>'0');
      if syncrst > 1 then
        v := r_rst;
      end if;
    end if;
    
    -- Assign signals
    nr <= v;
    outs <= o;
    toll <= cin;
    us_restart <= vus_restart;
    us_clear <= vus_clear;
    
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
