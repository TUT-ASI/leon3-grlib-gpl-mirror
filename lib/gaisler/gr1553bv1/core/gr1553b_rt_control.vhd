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
-- Entity:      gr1553b_rt_control
-- File:        gr1553b_rt_control.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B Remote terminal top layer
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use work.gr1553b_core.all;

entity gr1553b_rt_control is
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
  attribute sync_set_reset of rst : signal is "true";
end;

architecture rtl of gr1553b_rt_control is

  constant logreg_bits: integer := 15;  -- 15+2 bits -> 128 Kbyte 
  constant minalign: integer := 0;      -- 2^(0+2) = 4 byte min size
    
  function resultbits(r: gr1553b_rt_request_result) return std_logic_vector is
  begin
    case r is
      when SUCCESS =>    return "000";
      when SUPERSEDED => return "001";
      when TIMEOUT =>    return "010";
      when BUSERROR =>   return "011";
      when MSGERRSENT => return "100";
      when LBERROR =>    return "101";
      when others =>     return "111";
    end case;
  end resultbits;

  -- Compare word count values (where "00000"->32), return true if b >= a
  function comp_wc(a,b: std_logic_vector) return boolean is    
  begin
    if notx(a) and notx(b) then
      if b="00000" then return true; 
      elsif a="00000" then return false; 
      else return unsigned(b) >= unsigned(a);
      end if;
    else
      return false;
    end if;
  end comp_wc;

  -- States (proceeds to following state unless noted otw):
  --
  -- START:            Start state.
  -- IDLE:             Go to MODECMD_ACTION,DMATBLREAD or INVALID on command
  -----------------------------------------------------------------------------
  -- MODECMD_CHECK:    Check 2:nd bit of modecode mask, determines if legal
  -- MODECMD_ACTION:   "Performs" the mode command.
  -- LOGWRITE          Write log entry into log ring buffer
  --                   IRQ if appropriate and goto IDLE.
  -----------------------------------------------------------------------------
  -- DMATBLREAD:       DMA engine fetches SA table entry and descriptor
  -- TRANSFER:         Wait while transfer is in progress
  -- DMATBLWRITE:      DMA engine writes back status, result and log entry
  -----------------------------------------------------------------------------
  -- REQILLEGAL        Flag illegal request. Wait for transfer to finish and
  --                   goto IDLE.
  -- REQTEMPERR        Flag unknown error. Wait for transfer to time out and
  --                   goto IDLE
  -- DMAERROR          Wait for dmaerror_ack, then goto IDLE.
  --
  type rt_control_state is (START, IDLE, 
                            DMATBLREAD, TRANSFER, DMATBLWRITE,
                            MODECMD_CHECK, MODECMD_ACTION,
                            LOGWRITE,
                            REQILLEGAL, REQTEMPERR, DMAERROR);

  constant bd0_descinvalid: integer := 8;
  constant bd0_descdv: integer := 7;
  constant bd0_igndv: integer := 6;
  constant bd0_dotfr: integer := 5;
  constant bd0_maxsize_h: integer := 4;
  constant bd0_maxsize_l: integer := 0;
  
  type rt_control_regs is record
    st: rt_control_state;
    -- User-written registers
    -- Modecode mask, 15 modecodesx2 bits "00"=Illegal, "01"=Legal,
    -- "10"=Legal+log, "11"=Legal+log+IRQ
    modecode_mask_0: std_logic_vector(14 downto 0);
    modecode_mask_1: std_logic_vector(14 downto 0);
    subaddr_table_base: std_logic_vector(22 downto 0);
    -- User-read registers
    syncword: std_logic_vector(15 downto 0);
    sync_timetag: std_logic_vector(15 downto 0);
    -- The currently processed request and corresponding result. These
    -- are copied into registers so we don't have to handle errors or
    -- superseded commands from the protocol layer in every state.
    current_request: gr1553b_rt_request;
    current_request_result: gr1553b_rt_request_result;
    -- Subaddress control word parts    
    do_log, do_irq, autowrap: std_logic;
        
    -- Log buffer
    
    logbuf_base: std_logic_vector(29 downto logreg_bits);
    logbuf_pos: std_logic_vector(logreg_bits-1 downto 0);
    logbuf_mask: std_logic_vector(logreg_bits-1 downto minalign);
    got_irq: std_logic;
    irq_log_addr: std_logic_vector(logreg_bits-1 downto 0);
    descerror: std_logic;
        
    wordcount: std_logic_vector(5 downto 0);
    timetag: std_logic_vector(15 downto 0);   
    shutdownA,shutdownB: std_logic;
    inh_termflag: std_logic;
    pending_busreset: std_logic;
    busreset: std_logic;
    desc_irqen: std_logic;
  end record;

  constant r_rst: rt_control_regs := (
    START, "000000000111111", "000000000000000",
    (others => '0'), x"0000", x"0000", gr1553b_rt_request_zero,
    SUCCESS, '0','0','0', (others => '0'),(others => '0'),(others => '1'),
    '0',(others => '0'),'0',
    (others => '0'),x"0000",'0','0','0','0','0','0');
    
    
  signal r,nr: rt_control_regs;

  -- Shared 32-to-1 mux
  signal muxin: std_logic_vector(31 downto 0);
  signal muxidx: std_logic_vector(4 downto 0);
  signal muxout: std_logic;

  
begin

  infmux: process(muxin,muxidx)
  begin
    if notx(muxidx) then
      muxout <= muxin(to_integer(unsigned(muxidx)));
    else
      muxout <= 'U';
    end if;
  end process;

  comb: process(rst,r,ins,proto,dmao,muxout)
    variable vr: rt_control_regs;
    variable vo: gr1553b_rt_control_out;
    variable vdmai: gr1553b_dma2_in_rt;
    variable vproti: gr1553b_rt_proto_in;
    variable vmuxin: std_logic_vector(31 downto 0);
    variable vmuxidx: std_logic_vector(4 downto 0);
    
    variable typebits: std_logic_vector(1 downto 0);
    variable addrbits: std_logic_vector(4 downto 0);
    variable failbit: std_logic;
    variable new_ctrlword: std_logic_vector(31 downto 0);
    variable logentry: std_logic_vector(31 downto 0);
    variable fullmask: std_logic_vector(29 downto 0);
    variable maxsize: std_logic_vector(4 downto 0);
  begin    
    vr := r;
    vdmai := (read_satbl => '0', write_res => '0', write_log => '0',
              tx_transfer => '0', tfr_legal => '0', autowrap => r.autowrap, do_log => r.do_log,
              statusword => (others => '0'),
              satbl_addr => r.subaddr_table_base & r.current_request.subaddr,
              logaddr => r.logbuf_base & r.logbuf_pos, logentry => (others => '0'),
              data_reset => '0', need_data => '0', pull_data => proto.datain_read, pushing_data => '0',
              push_data => proto.dataout_write, push_done => '0');
    vo := (dmaerror=>'0', dmaerror_next => '0', gotirq=>r.got_irq, gotirq_next => '0',
           irq_log_addr=>r.logbuf_base & r.irq_log_addr & "00",
           descerror => r.descerror, descerror_next => '0',
           bussync_nodata=>'0', bussync_data => '0', bussync_word=>r.syncword, busreset=>r.busreset,
           bussync_time => r.sync_timetag, 
           shutdownA=>r.shutdownA, shutdownB=>r.shutdownB,
           validcmdA => proto.validcmdA, validcmdB => proto.validcmdB,
           active=>'1', 
           subaddr_table_base => r.subaddr_table_base & "000000000",
           modecode_mask=> x"0000000" & "00",
           log_mask => fullmask & "00",
           log_cur_addr => r.logbuf_base & r.logbuf_pos & "00");
    vproti := (enable=>ins.rt_enable, my_addr=>ins.rt_addr, allow_broadcast => ins.allow_bc,
               req_resp => UNKNOWN, statusbits => ins.statusbits,
               datain_valid => dmao.can_pull, data_in => dmao.pulldata,
               dataout_ready => dmao.can_push);
    vmuxidx := mc_to_muxidx(r.current_request.wc_mode, r.current_request.bc);
    vmuxin := mcmask_to_muxin(r.modecode_mask_0,false,'0');
    
    if r.current_request.t=XMIT then
      vdmai.tx_transfer:='1';
      vdmai.tfr_legal := dmao.rt_satw0_temp(7);
      if dmao.rt_satw0_valid='1' then        
        vr.autowrap := dmao.rt_satw0_temp(18);
        vr.do_log := dmao.rt_satw0_temp(6);
        vr.do_irq := dmao.rt_satw0_temp(5);
      end if;
      maxsize := dmao.rt_satw0_temp(4 downto 0);
    else
      vdmai.tx_transfer:='0';
      if r.current_request.bc='1' then
        vdmai.tfr_legal := dmao.rt_satw0_temp(16);
      else
        vdmai.tfr_legal := dmao.rt_satw0_temp(15);
      end if;
      if dmao.rt_satw0_valid='1' then
        vr.autowrap := dmao.rt_satw0_temp(18);
        vr.do_log := dmao.rt_satw0_temp(14);
        vr.do_irq := dmao.rt_satw0_temp(13);
      end if;      
      maxsize := dmao.rt_satw0_temp(12 downto 8);
    end if;

    if dmao.rt_descw0_valid='1' then
      vr.desc_irqen := dmao.rt_descw0_temp(30);
      vr.do_log := vr.do_log or vr.desc_irqen;
      vr.do_irq := vr.do_irq or vr.desc_irqen;
    end if;    
    
    if not comp_wc(r.current_request.wc_mode, maxsize) then
      vdmai.tfr_legal := '0';
    end if;
    
    if r.current_request.t = RECV then        
      typebits := "01";
      addrbits := r.current_request.subaddr;
    elsif r.current_request.t = XMIT then
      typebits := "00";
      addrbits := r.current_request.subaddr;      
    else
      typebits := "10";
      addrbits := r.current_request.wc_mode;
    end if;
    if r.current_request_result=SUCCESS then
      failbit := '0';
    else
      failbit := '1';
    end if;
    
    vdmai.logentry :=
      r.do_irq & typebits & addrbits & r.timetag(13 downto 0) &
      r.current_request.bc & r.wordcount & resultbits(r.current_request_result); 

    vdmai.statusword :=
      "1" & r.desc_irqen & "0000" & r.timetag & r.current_request.bc & r.wordcount &
      resultbits(r.current_request_result);
    
    fullmask := (others => '0');
    fullmask(29 downto logreg_bits) := (others => '1');
    fullmask(logreg_bits-1 downto minalign) := r.logbuf_mask;
    

    for x in 14 downto 0 loop
      vo.modecode_mask(2*x+1) := r.modecode_mask_1(x);
      vo.modecode_mask(2*x) := r.modecode_mask_0(x);
    end loop;
    
    if r.inh_termflag='1' then vproti.statusbits(0):='0'; end if;
    
    

    
    --if r.current_request_result=SUCCESS then new_ctrlword(31):='1'; end if;
    
    -- State machine transitions

    case r.st is

      when START =>
        vo.active := '0';
        vr.current_request_result := PROGRESS;
        vr.current_request := proto.request;
        vr.st := IDLE;
        
      when IDLE =>
        vo.active := '0';
        vr.current_request_result := PROGRESS;
        vr.current_request := proto.request;
        vr.wordcount := (others=>'0');
        vr.timetag := ins.timer_value;
        vr.do_log := '0';
        vr.do_irq := '0';
        case r.current_request.t is
          when NOREQ =>
            null;
          when RECV | XMIT=>
            if dmao.ready='1' then
              vdmai.read_satbl := '1';
              vr.st := DMATBLREAD;
            end if;
          when MODECMD | MODECMD_RECV | MODECMD_XMIT =>
            -- Check the modecmd valid mask reg.
            -- vmuxidx/vmuxin already set above
            -- vmuxidx := mc_to_muxidx(proto.request.wc_mode, proto.request.bc);
            vmuxin := mcmask_to_muxin(r.modecode_mask_1,false,'0');
            vr.do_log := muxout;
            vr.st := MODECMD_CHECK;
        end case;

        -----------------------------------------------------------------------
        -- Data transfer states
        -----------------------------------------------------------------------
        
      when DMATBLREAD =>
        if r.current_request.t=XMIT then
          if dmao.rt_descptr_valid='1' then
            vproti.req_resp := REQOK;
          end if;
        end if;
        
        if dmao.desc_dmaerror='1' then
          vr.st := DMAERROR;
        elsif r.current_request.t=RECV and dmao.rt_descw0_valid='1' and
          dmao.rt_descw0_temp(31)='1' and dmao.rt_satw0_temp(17)='0' then
          -- DV set and IGNDV not set
          vr.st := REQTEMPERR;
        elsif dmao.rt_break='1' then
          if vdmai.tfr_legal='0' then
            vr.st := REQILLEGAL;
          else
            vr.st := REQTEMPERR;
          end if;          
        elsif dmao.ready='1' then
          vr.st := TRANSFER;
        end if;
        
        vdmai.data_reset := '1';

      when TRANSFER =>
        vproti.req_resp := REQOK;
        if r.current_request.t=RECV then
          vdmai.pushing_data := '1';          
        else
          vdmai.need_data := '1';
        end if;

        if proto.dataout_write='1' or proto.datain_read='1' then
          vr.wordcount := std_logic_vector(unsigned(r.wordcount)+1);
        end if;
        
        if dmao.buf_dmaerror='1' then
          vr.st := DMAERROR;          
        elsif r.current_request_result /= PROGRESS and dmao.ready='1' then
          if r.current_request.t=RECV and dmao.can_pull='1' then
            vdmai.push_done := '1';
          else
            vdmai.write_res := '1';
            vr.st := DMATBLWRITE;
          end if;
        end if;

      when DMATBLWRITE =>
        if dmao.desc_dmaerror='1' then
          vr.st := DMAERROR;
        elsif dmao.ready='1' and r.do_log='1' then
          vdmai.write_log := '1';
          vr.st := LOGWRITE;
        elsif dmao.ready='1' then
          vr.st := START;
        end if;

        -----------------------------------------------------------------------
        -- Mode command states
        -----------------------------------------------------------------------
        
      when MODECMD_CHECK =>
        -- vmuxidx := mc_to_muxidx(proto.request.wc_mode, proto.request.bc);
        vmuxin := mcmask_to_muxin(r.modecode_mask_0,false,'0');
        vr.do_irq := muxout;
        if muxout='0' and r.do_log='0' then
          vr.st := REQILLEGAL;
        else
          vr.st := MODECMD_ACTION;
        end if;
                  
      when MODECMD_ACTION =>

        vproti.req_resp := REQOK;
        
        -- Synchronize w/o data word
        if r.current_request.wc_mode="00001" and r.current_request_result=SUCCESS then
          vo.bussync_nodata := '1';
          vr.sync_timetag := r.timetag;
        end if;
        -- Reset remote terminal
        if r.current_request.wc_mode="01000" and r.current_request_result=SUCCESS then
          -- Setting delayed_busreset in later state to avoid glitch because
          -- txready goes from 1->0 in this same cycle
          vr.shutdownA := '0';
          vr.shutdownB := '0';
          vo.validcmdA := '1';
          vo.validcmdB := '1';
          vr.inh_termflag := '0';
          vr.pending_busreset := '1';
        end if;
        -- Transmitter shutdown
        if r.current_request.wc_mode="00100" and r.current_request_result=SUCCESS then
          if r.current_request.cmdbus = '1' then
            vr.shutdownA := '1';
          else
            vr.shutdownB := '1';
          end if;
        end if;
        -- Override transmitter shutdown
        if r.current_request.wc_mode="00101" and r.current_request_result=SUCCESS then
          if r.current_request.cmdbus='1' then
            vr.shutdownA := '0';
          else
            vr.shutdownB := '0';
          end if;
        end if;
        -- We need to change these right before sending sending the status
        -- word but after checking data word count.
        -- Also need to check for result=SUCCESS to handle broadcast case
        -- Inhibit terminal flag
        if r.current_request.wc_mode="00110" and
          ((r.current_request_result=PROGRESS and proto.status_next='1') or r.current_request_result=SUCCESS) then
          vr.inh_termflag := '1';
        end if;
        -- Override inhibit terminal flag
        if r.current_request.wc_mode="00111" and
          ((r.current_request_result=PROGRESS and proto.status_next='1') or r.current_request_result=SUCCESS) then
          vr.inh_termflag := '0';
        end if;
        
        if r.current_request.t=MODECMD_XMIT then
-- pragma translate_off
          assert r.current_request.wc_mode="10000" or r.current_request.wc_mode="10011" report "Invalid command" severity failure;
-- pragma translate_on
          if r.current_request.wc_mode="10000" then
            -- Transmit vector word
            vproti.data_in := ins.vector_word;
            vproti.datain_valid := '1';
          else
            -- Transmit BIT word
            vproti.data_in := ins.bit_word;
            vproti.datain_valid := '1';
          end if;
          if proto.datain_read='1' then
            vr.wordcount := std_logic_vector(unsigned(r.wordcount)+1);
          end if;
          
        elsif r.current_request.t=MODECMD_RECV then
-- pragma translate_off
          assert r.current_request.wc_mode="10001" report "Invalid command passed through check!" severity failure;
-- pragma translate_on
          vproti.dataout_ready := '1';
          if proto.dataout_write='1' then
            vr.wordcount := std_logic_vector(unsigned(r.wordcount)+1);
            if r.current_request.wc_mode="10001" then
              vr.syncword := proto.data_out;
              vr.sync_timetag := r.timetag;
              vo.bussync_data := '1';
            end if;
          end if;

        else
          assert r.current_request.t=MODECMD report "Inconsistent state/request type" severity failure;
          
        end if;

        if r.current_request_result /= PROGRESS then
          if r.do_log='1' then
            vr.st := LOGWRITE;
            vdmai.write_log := '1';
          else
            vr.st := START;
          end if;
        end if;        
        

        -----------------------------------------------------------------------
        -- Common end states
        -----------------------------------------------------------------------
        
      when LOGWRITE =>
        if dmao.desc_dmaerror='1' then
          vr.st := DMAERROR;
        elsif dmao.ready='1' then
          vr.st := START;
          vr.logbuf_pos := (std_logic_vector(unsigned(r.logbuf_pos)+1) and not fullmask(logreg_bits-1 downto 0)) or
                           (r.logbuf_pos and fullmask(logreg_bits-1 downto 0));
          if r.do_irq='1' and r.got_irq='0' then
            vo.gotirq_next := '1';
            vr.got_irq := '1';
            vr.irq_log_addr := r.logbuf_pos;
          end if;          
        end if;

      when REQILLEGAL =>
        vproti.req_resp := REQILLEGAL;
        -- In case of a receive command, set dataout_ready and just ignore the
        -- incoming data.
        vproti.dataout_ready := '1';
        if r.current_request_result /= PROGRESS then
          vr.st := START;
        end if;

        
      when REQTEMPERR =>
        if r.current_request_result /= PROGRESS then
          if r.do_log='1' then
            vr.st := LOGWRITE;
            vdmai.write_log := '1';
          else
            vr.st := START;
          end if;
        end if;
        
        
      when DMAERROR =>
        vo.dmaerror := '1';
        if ins.dmaerror_ack='1' then
          vr.st := START;
        end if;
      
    end case;

    if r.st /= DMAERROR and vr.st = DMAERROR then
      vo.dmaerror_next := '1';
    end if;

    if ((r.st /= REQTEMPERR and vr.st = REQTEMPERR) or
        (r.current_request_result=TIMEOUT and r.descerror='0' and r.st /= REQTEMPERR)) then
      vo.descerror_next := '1';
      vr.descerror := '1';
    end if;
    
    -- Copy result when the current transfer finishes
    if r.st /= START and r.st /= IDLE and r.current_request_result=PROGRESS and proto.result/=PROGRESS then
      vr.current_request_result := proto.result;
    end if;

    -- Make sure we don't respond to the next request while finishing
    -- processing of a finished transfer.
    if r.current_request_result /= PROGRESS then
      vproti.req_resp := UNKNOWN;
      vproti.datain_valid := '0';
    end if;

    if ins.irqack='1' then
      vr.got_irq := '0';
    end if;

    if ins.descerror_ack='1' then
      vr.descerror := '0';
    end if;

    vr.busreset := '0';
    if r.pending_busreset='1' and proto.txdone='1' then
      vr.busreset := '1';
      vr.pending_busreset := '0';
    end if;
    
    -- User register access
    if ins.set_modecode_mask='1' then
      for x in 14 downto 0 loop
        vr.modecode_mask_1(x) := ins.user_input(2*x+1);
        vr.modecode_mask_0(x) := ins.user_input(2*x);
      end loop;
    end if;
    if ins.set_subaddr_table_base='1' then
      vr.subaddr_table_base := ins.user_input(31 downto 9);
    end if;
    if ins.set_log_mask='1' then
      vr.logbuf_mask := ins.user_input(logreg_bits+1 downto minalign+2);
    end if;
    if ins.set_log_cur_addr='1' then
      vr.logbuf_base := ins.user_input(31 downto logreg_bits+2);
      vr.logbuf_pos := ins.user_input(logreg_bits+1 downto 2);
    end if;

    if ins.rt_stop='1' then
      vr.st := START;
    end if;
    
    if rst='0' and syncrst/=0 then
      vr.st := r_rst.st;
      vr.modecode_mask_0 := r_rst.modecode_mask_0;
      vr.modecode_mask_1 := r_rst.modecode_mask_1;
      vr.subaddr_table_base := r_rst.subaddr_table_base;
      vr.syncword := r_rst.syncword;
      vr.sync_timetag := r_rst.sync_timetag;
      vr.shutdownA := r_rst.shutdownA;
      vr.shutdownB := r_rst.shutdownB;
      vr.logbuf_base := r_rst.logbuf_base;
      vr.logbuf_mask := r_rst.logbuf_mask;
      vr.logbuf_pos := r_rst.logbuf_pos;
      vr.got_irq := r_rst.got_irq;
      vr.irq_log_addr := r_rst.irq_log_addr;
      vr.inh_termflag := r_rst.inh_termflag;
      vr.descerror := r_rst.descerror;
      vr.pending_busreset := r_rst.pending_busreset;
      if syncrst > 1 then
        vr := r_rst;
      end if;
    end if;

    nr <= vr;
    outs <= vo;
    dmai <= vdmai;
    proti <= vproti;
    muxin <= vmuxin;
    muxidx <= vmuxidx;
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
