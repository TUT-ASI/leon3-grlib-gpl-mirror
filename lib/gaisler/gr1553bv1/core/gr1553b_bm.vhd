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
-- Entity:      gr1553b_bm
-- File:        gr1553b_bm.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B Bus monitor controller
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use work.gr1553b_core.all;

entity gr1553b_bm is
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
  attribute sync_set_reset of rst : signal is "true";
end;

architecture rtl of gr1553b_bm is

  constant logreg_bits: integer := 19;  -- 19+3 bits -> 4 Mbyte 

  type bm_dma_state is (IDLE, WAITSTART, WAITDONE, DMAERROR);
  type bm_word_process_state is (EMPTY,
                                 CHECKADDR,CHECKSA,CHECKMC,WRITECMD,
                                 WAITRECV,WAITRECVBC,
                                 WAITSDS,WAITDS,WAITSD,WAITD,SKIPRECV,SKIPDSD,SKIPD
                                 );
  
  type bm_regs is record
    dst: bm_dma_state;
    wpst: bm_word_process_state;
    wpbus: std_logic;
    wprtaddr: std_logic_vector(4 downto 0);
    wprtaddr2: std_logic_vector(4 downto 0);
    skipping_recv: std_logic;
    wpbc: std_logic;
    outbuf_base: std_logic_vector(28 downto logreg_bits);
    outbuf_start: std_logic_vector(logreg_bits-1 downto 0);
    outbuf_end: std_logic_vector(logreg_bits-1 downto 0);
    outbuf_pos: std_logic_vector(logreg_bits-1 downto 0);
    rtaddr_filter: std_logic_vector(31 downto 0);
    subaddr_filter: std_logic_vector(31 downto 0);
    modecode_filter: std_logic_vector(31 downto 0);
    -- Received valid data words. 
    A_word, B_word: gr1553b_word;
    A_word_valid, B_word_valid: std_logic;
    -- Data to be written to ring buffer
    Adata,Bdata: std_logic_vector(63 downto 0);
    a_dv,b_dv,dmasel: std_logic;
  end record;

  constant r_rst: bm_regs :=
    (IDLE,EMPTY,'0',"00000","00000",'0','0',
     (others => '0'), (others => '0'), (others => '0'), (others => '0'),
     (others => '1'), (others => '1'), (others => '1'),
     gr1553b_word_default, gr1553b_word_default, '0', '0',
     (63=>'1', others=>'0'), (63=>'1', others=>'0'), '0', '0', '0');
  
  signal r,nr: bm_regs;

  -- Shared 32-to-1 mux
  signal muxin: std_logic_vector(31 downto 0);
  signal muxidx: std_logic_vector(4 downto 0);
  signal muxout: std_logic;
  
begin

  infermux: process(muxin,muxidx)
  begin
    if notx(muxidx) then
      muxout <= muxin(to_integer(unsigned(muxidx)));
    else
      muxout <= 'U';
    end if;
  end process;

  comb: process(r,rst,ins,busdata,dmao,muxout)
    variable v: bm_regs;
    variable vout: gr1553b_bm_out;
    variable vdmai: gr1553b_dma2_in_bm;
    variable at,bt,wat,wbt: std_logic;
    variable outbuf_pos_p1: std_logic_vector(logreg_bits-1 downto 0);
    variable wpword,wpotherword: gr1553b_word;
    variable wpword_valid,wpotherword_valid: std_logic;
    variable wpword_status: std_logic;
    variable wp_dv: std_logic;
    variable vmuxin: std_logic_vector(31 downto 0);
    variable vmuxsel: std_logic_vector(4 downto 0);
    variable write_cmdword,kill_cmdword: boolean;
    variable write_other_cmdword, kill_other_cmdword: boolean;
    variable write_cmdword_A: boolean;
    variable write_cmdword_B: boolean;
  begin
    v := r;
    vout := (dmaerror_next => '0', outbuf_start => r.outbuf_base & r.outbuf_start & "000",
             outbuf_end => r.outbuf_base & r.outbuf_end & "111",
             outbuf_pos => r.outbuf_base & r.outbuf_pos & "000", rtaddr_filter => r.rtaddr_filter,
             subaddr_filter => r.subaddr_filter, modecode_filter => r.modecode_filter,
             dmaerror => '0', wrapping => '0');
    vdmai := (write_data => '0', ringbuf_addr => r.outbuf_base & r.outbuf_pos,
              logdata => r.Adata);
    
    vmuxin := r.rtaddr_filter;
    vmuxsel := wpword.data(15 downto 11);
    write_cmdword := false;    
    kill_cmdword := false;
    write_other_cmdword := false;
    kill_other_cmdword := false;
    write_cmdword_A := false;
    write_cmdword_B := false;    
    
    -- Misc. comb logic
    
    if r.outbuf_pos=r.outbuf_end then
      outbuf_pos_p1 := r.outbuf_start;
    else
      outbuf_pos_p1 := std_logic_vector(unsigned(r.outbuf_pos)+1);
    end if;
    
    if busdata.word_A.t=CMD_STAT then at:='1'; else at:='0'; end if;
    if busdata.word_B.t=CMD_STAT then bt:='1'; else bt:='0'; end if;
    if r.A_word.t=CMD_STAT then wat:='1'; else wat:='0'; end if;
    if r.B_word.t=CMD_STAT then wbt:='1'; else wbt:='0'; end if;
    
    if r.wpbus='0' then
      wpword:=r.A_word;
      wpotherword := r.B_word;
      wpword_valid := r.A_word_valid;
      wpotherword_valid := r.B_word_valid;
      wp_dv := r.A_dv;
    else
      wpword:=r.B_word;
      wpotherword := r.A_word;
      wpword_valid := r.B_word_valid;
      wpotherword_valid := r.A_word_valid;
      wp_dv := r.B_dv;
    end if;

    if wpword_valid='1' and wpword.t=CMD_STAT and wpword.data(15 downto 11)=r.wprtaddr and
      wpword.data(9)='0' and wpword.data(7 downto 5)="000" then
      wpword_status := '1';
    else
      wpword_status := '0';
    end if;
    
    -- Check for new words
    if r.A_word_valid='0' and busdata.datavalid_A='1' and ins.enable='1' then
      v.A_word := busdata.word_A;
      v.A_word_valid := '1';
    end if;
    if r.B_word_valid='0' and busdata.datavalid_B='1' and ins.enable='1' then
      v.B_word := busdata.word_B;
      v.B_word_valid := '1';
    end if;

    if filters /= 0 then
    
      -- Word handling state machine
      case r.wpst is
      
        when EMPTY =>
          if r.A_word_valid='1' then
            
            v.wpbus := '0';
            if r.A_word.t=CMD_STAT then
              v.wpst := CHECKADDR;
            elsif ins.log_stray_data='1' then
              write_cmdword_A := true;
            else
              v.A_word_valid := '0';
            end if;
            
          elsif r.B_word_valid='1' then
            
            v.wpbus := '1';
            if r.B_word.t=CMD_STAT then            
              v.wpst := CHECKADDR;
            elsif ins.log_stray_data='1' then
              write_cmdword_B := true;
            else
              v.B_word_valid := '0';
            end if;
            
          end if;
          
        when CHECKADDR =>
          vmuxin := r.rtaddr_filter;
          vmuxsel := wpword.data(15 downto 11);
          v.wprtaddr := wpword.data(15 downto 11);
          v.wprtaddr2 := r.wprtaddr;
          
          if wpword.data(15 downto 11)="11111" then v.wpbc := '1'; else v.wpbc := '0'; end if;
          
          if muxout='1' then
            v.wpst := CHECKSA;
          else
            if wpword.data(15 downto 11)="11111" then
              -- Broadcast transfers only have data words after the command word.
              -- Exception is RT->RT broadcast. However, the following transmit
              -- command in that case will be handled correctly as a separate command.
              v.wpst := SKIPD;
            elsif wpword.data(9 downto 5)/="11111" and wpword.data(9 downto 5)/="00000" and wpword.data(10)='0' then
              -- Receive command
              v.wpst := SKIPRECV;
            else
              -- This covers all other transfer types
              v.wpst := SKIPDSD;
            end if;
            kill_cmdword := true;
          end if;
          
        when CHECKSA =>
          vmuxin := r.subaddr_filter;
          vmuxsel := wpword.data(9 downto 5);
          if muxout='1' then
            if wpword.data(9 downto 5)="11111" or wpword.data(9 downto 5)="00000" then
              v.wpst := CHECKMC;
            else
              v.wpst := WRITECMD;
            end if;
          else
            -- See comments above.
            if wpword.data(15 downto 11)="11111" then
              v.wpst := SKIPD;
            elsif wpword.data(9 downto 5)/="11111" and wpword.data(9 downto 5)/="00000" and wpword.data(10)='0' then
              v.wpst := SKIPRECV;
            else
              v.wpst := SKIPDSD;
            end if;
            kill_cmdword := true;
          end if;
          
        when CHECKMC =>
          vmuxin := mcmask_to_muxin(r.modecode_filter, true, ins.log_reserved_mcs);
          vmuxsel := mc_to_muxidx(wpword.data(4 downto 0), r.wpbc);        
          if (wpword.data(4 downto 0)/="00010" and (wpword.data(3)='0' or wpword.data(4 downto 0)="01000") and muxout='1') or
            (wpword.data(4 downto 0)="00010" and r.modecode_filter(15)='1') or
            (wpword.data(3)='1' and wpword.data(4 downto 0)/="01000" and ins.log_reserved_mcs='1') then
            v.wpst := WRITECMD;
          elsif r.wprtaddr="11111" then
            v.wpst := SKIPD;
            kill_cmdword := true;
          else
            v.wpst := SKIPDSD;
            kill_cmdword := true;
          end if;
          
        when WRITECMD =>
          if wp_dv='0' then
            write_cmdword := true;
            if wpword.data(9 downto 5)="11111" or wpword.data(9 downto 5)="00000" then
              -- Mode code
              if wpword.data(15 downto 11)="11111" then
                -- Mode code broadcast
                v.wpst := WAITD;
              elsif wpword.data(10)='1' then
                -- Mode code transmit
                v.wpst := WAITSD;
              else
                -- Mode code receive
                v.wpst := WAITDS;
              end if;
            elsif wpword.data(10)='0' then
              -- Receive
              if wpword.data(15 downto 11)="11111" then
              v.wpst := WAITRECVBC;
              else
                v.wpst := WAITRECV;
              end if;
            else
              -- Transmit
              if r.skipping_recv='0' then
                v.wpst := WAITSD;
              else
                v.wpst := WAITSDS;
              end if;
            end if;
          end if;
          
        when WAITRECV =>
          if wpword_valid='1' and wp_dv='0' then
            write_cmdword := true;          
            if wpword.t=DATA then
              v.wpst := WAITDS;
            else
              v.wprtaddr := wpword.data(15 downto 11);
              v.wprtaddr2 := r.wprtaddr;
              v.wpst := WAITSDS;
            end if;
          end if;
          
        when WAITRECVBC =>
          if wpword_valid='1' and wp_dv='0' then
            v.wprtaddr := wpword.data(15 downto 11);
            v.wprtaddr2 := r.wprtaddr;
            write_cmdword := true;
            if wpword.t=DATA then
              v.wpst := WAITD;
            else
              v.wpst := WAITSD;
            end if;
          end if;
          
        when WAITSDS =>
          if wpword_valid='1' and wp_dv='0' then
            if wpword_status='1' then
              write_cmdword := true;
              v.wpst := WAITDS;
              v.wprtaddr := r.wprtaddr2;            
            else            
              -- Protocol violation to send data or new command here
              v.wpst := EMPTY;
            end if;
          end if;
          
        when WAITDS =>
          if wpword_valid='1' and wp_dv='0' then
            if wpword.t=DATA then
              write_cmdword := true;
            elsif wpword_status='1' then
              if r.skipping_recv='1' then
                kill_cmdword := true;
                v.skipping_recv := '0';
              else
                write_cmdword := true;
              end if;
              v.wpst := EMPTY;
            else
              v.wpst := EMPTY;
            end if;          
          end if;
          
        when WAITSD =>
          if wpword_valid='1' and wp_dv='0' then
            if wpword.t=DATA then
              -- Protocol violation to send data here
              v.wpst := EMPTY;
            elsif wpword_status='1' then
              write_cmdword := true;
              v.wpst := WAITD;
            else
              v.wpst := EMPTY;
            end if;          
          end if;
          
        when WAITD =>
          if wpword_valid='1' and wp_dv='0' then
            if wpword.t=DATA then
              write_cmdword := true;
            else
              v.wpst := EMPTY;
            end if;
          end if;

        when SKIPRECV =>
          if wpword_valid='1' then
            if wpword.t=CMD_STAT then
              -- Set the skipping_recv flag to remember the status word coming
              -- after the following (transmit) transfer
              v.skipping_recv := '1';
              v.wpst := EMPTY;
            else
              v.skipping_recv := '0';
              kill_cmdword := true;            
              v.wpst := SKIPDSD;
            end if;
          end if;

        when SKIPDSD =>
          if wpword_valid='1' then
            if wpword.t=DATA then
              kill_cmdword := true;
            elsif wpword_status='1' then
              kill_cmdword := true;
              if r.skipping_recv='1' then
                v.wprtaddr := r.wprtaddr2;
              else
                v.wpst := SKIPD;
              end if;
              v.skipping_recv := '0';
            else
              -- Must be new command (addresses don't match)
              v.wpst := EMPTY;
            end if;
          end if;
          
        when SKIPD => 
          if wpword_valid='1' then
            if wpword.t=DATA then
              kill_cmdword := true;
            else
              v.wpst := EMPTY;
            end if;
          end if;
          
      end case;
      
      -- Handle superseding commands
      if r.wpst /= EMPTY and r.wpst /= CHECKADDR and r.wpst /= CHECKSA and r.wpst /= CHECKMC and
        r.wpst /= WRITECMD then
        
        if wpword_valid='0' and wpotherword_valid='1' then
          if wpotherword.t=CMD_STAT then
            v.wpst := CHECKADDR;
            v.wpbus := not v.wpbus;
          elsif ins.log_stray_data='1' then
            write_other_cmdword := true;
          else
            kill_other_cmdword := true;
          end if;
        end if;
        
      end if;

      if ins.enable='0' then
        v.wpst := EMPTY;      
      end if;      

      if write_cmdword then
        if r.wpbus='1' then write_cmdword_B:=true; else write_cmdword_A:=true; end if;
      elsif kill_cmdword then
        if r.wpbus='1' then v.B_word_valid:='0'; else v.A_word_valid:='0'; end if;
      end if;
      if write_other_cmdword then
        if r.wpbus='1' then write_cmdword_A:=true; else write_cmdword_B:=true; end if;
      elsif kill_other_cmdword then
        if r.wpbus='1' then v.A_word_valid:='0'; else v.B_word_valid:='0'; end if;
      end if;    
      
    end if; -- filters /= 0

    if filters=0 then
      if r.A_word_valid='1' then
        write_cmdword_A:=true;
      end if;
      if r.B_word_valid='1' then
        write_cmdword_b:=true;
      end if;
    end if;
    
    -- Handle transferring command word to DMA buffer
    if write_cmdword_A and r.a_dv='0' then
      v.a_dv := '1';
      v.Adata := "10000000" & ins.timeval & "000000000000" & '0' & "00" & wat & r.A_word.data;
      v.A_word_valid := '0';
    end if;
    if write_cmdword_B and r.b_dv='0' then
      v.b_dv := '1';
      v.Bdata := "10000000" & ins.timeval & "000000000000" & '1' & "00" & wbt & r.B_word.data;
      v.B_word_valid := '0';
    end if;
    
    
    -- Check for new error events
    
    if v.a_dv='0' and busdata.started_A='1' and ins.log_errors='1' and ins.enable='1' and
       (busdata.lostsync_A='1' or busdata.badparity_A='1') then
      
      v.Adata := "10000000" & ins.timeval & "000000000000" & '0' & busdata.badparity_A & busdata.lostsync_A &
                 at & busdata.word_A.data;
      v.a_dv := '1';
    end if;
    
    if v.b_dv='0' and busdata.started_B='1' and ins.log_errors='1' and ins.enable='1' and 
      (busdata.lostsync_B='1' or busdata.badparity_B='1') then
      
      v.Bdata := "10000000" & ins.timeval & "000000000000" & '1' & busdata.badparity_B & busdata.lostsync_B &
                 bt & busdata.word_B.data;
      v.b_dv := '1';
    end if;

    -- Handle DMA transfer
    if r.dmasel='1' then vdmai.logdata:=r.Bdata; else vdmai.logdata:=r.Adata; end if;
    
    case r.dst is
      when IDLE =>
        if r.a_dv='1' then
          v.dst := WAITSTART;
          v.dmasel := '0';
        end if;
        if r.b_dv='1' then
          v.dst := WAITSTART;
          v.dmasel := '1';
        end if;

      when WAITSTART =>
        vdmai.write_data := '1';
        if dmao.bm_progress='1' then v.dst:=WAITDONE; end if;

      when WAITDONE =>
        if dmao.desc_dmaerror='1' then
          v.dst := DMAERROR;
          vout.dmaerror_next := '1';
        elsif dmao.bm_progress='0' then
          if r.dmasel='1' then
            v.b_dv := '0';
          else
            v.a_dv := '0';
          end if;
          v.dst := IDLE;
          v.outbuf_pos := outbuf_pos_p1;
          if r.outbuf_pos=r.outbuf_end then
            vout.wrapping := '1';
          end if;
        end if;
          
      when DMAERROR =>
        vout.dmaerror := '1';
        if ins.dmaerror_ack='1' then v.dst := IDLE; end if;
        
    end case;
    
    -- When resetting the BM due to a DMA error, make sure old data goes away
    if r.dst=DMAERROR and ins.enable='0' then
      v.a_dv := '0';
      v.b_dv := '0';
    end if;
            
    -- External register access
    if ins.set_outbuf_start='1' then
      v.outbuf_base := ins.user_input(31 downto logreg_bits+3);
      v.outbuf_start := ins.user_input(logreg_bits+2 downto 3);
    end if;
    if ins.set_outbuf_end='1' then
      v.outbuf_end := ins.user_input(logreg_bits+2 downto 3);
    end if;
    if ins.set_outbuf_pos='1' then
      v.outbuf_pos := ins.user_input(logreg_bits+2 downto 3);
    end if;
    if ins.set_rtaddr_filter='1' then
      v.rtaddr_filter := ins.user_input;
    end if;
    if ins.set_subaddr_filter='1' then
      v.subaddr_filter := ins.user_input;
    end if;
    if ins.set_modecode_filter='1' then
      v.modecode_filter := ins.user_input;
    end if;

    if filters=0 then
      v.rtaddr_filter := r_rst.rtaddr_filter;
      v.subaddr_filter := r_rst.subaddr_filter;
      v.modecode_filter := r_rst.modecode_filter;
    end if;
    
    if rst='0' and syncrst/=0 then
      v.dst := r_rst.dst;
      v.wpst := r_rst.wpst;
      v.a_dv := r_rst.a_dv;
      v.b_dv := r_rst.b_dv;
      v.A_word_valid := r_rst.A_word_valid;
      v.B_word_valid := r_rst.B_word_valid;
      v.rtaddr_filter := r_rst.rtaddr_filter;
      v.subaddr_filter := r_rst.subaddr_filter;
      v.modecode_filter := r_rst.modecode_filter;
      v.outbuf_base := r_rst.outbuf_base;
      v.outbuf_start := r_rst.outbuf_start;
      v.outbuf_end := r_rst.outbuf_end;
      v.outbuf_pos := r_rst.outbuf_pos;
      v.skipping_recv := r_rst.skipping_recv;
      if syncrst > 1 then
        v := r_rst;
      end if;
    end if;
    
    nr <= v;
    outs <= vout;
    dmai <= vdmai;
    muxin <= vmuxin;
    muxidx <= vmuxsel;
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
