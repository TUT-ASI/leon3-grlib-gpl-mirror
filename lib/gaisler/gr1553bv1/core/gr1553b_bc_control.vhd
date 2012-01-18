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
-- Entity:      gr1553b_bc_control
-- File:        gr1553b_bc_control.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B Bus controller command execution state machine
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use work.gr1553b_core.all;

entity gr1553b_bc_control is
  generic (
    cond_en: boolean;
    rtmask_en: boolean;
    syncrst: integer range 0 to 2
    );
  port (
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
  attribute sync_set_reset of rst : signal is "true";
end;

architecture rtl of gr1553b_bc_control is

  -- States in bc_command_state:
  --   SCHEDULE - No command is running, decide what to do and goto NEWCMD or DMASTART
  --   NEWCMD - Transfer is in progress
  --   CMDDONE - Transfer done, go to RETRY/FINISHED
  --   RETRY - Update retry counters, restart transfer and goto NEWCMD
  --   FINISHED - Command finished, start writing back the result and go to DMAWRITEWAIT
  --   MEMERR - DMA buffer error, wait until command is done and go back to SCHEDULE
  --   DMASTART - Wait for DMA to become ready, command descriptor read
  --   DMAWAIT - Wait for descriptor/branch read
  --   DMACOND - Handle conditional/unconditional branch
  --   DMAWRITEWAIT - Wait during result/IRQ DMA write, go to DMAWAIT/SCHEDULE
  
  type bc_command_state is (SCHEDULE,
                            NEWCMD,
                            CMDDONE,RETRY,FINISHED,MEMERR,
                            DMASTART,DMAWAIT,DMACOND,DMAWRITEWAIT);


  
  type cmdfsm_regs is record
    st: bc_command_state;
    bussel: std_logic;

    prim_run: std_logic;
    prim_pause: std_logic;
    prim_cmdaddr: std_logic_vector(31 downto 4);
    prim_nextaddr: std_logic_vector(31 downto 4);
    prim_desc0: std_logic_vector(31 downto 0);
    prim_desc0_valid: std_logic;
    prim_cmd_ready: std_logic;
    prim_laststatus: std_logic_vector(23 downto 0);
    prim_last_excl: std_logic;
    prim_jump: std_logic;
    
    sec_run: std_logic;
    sec_cmdaddr: std_logic_vector(31 downto 4);    
    sec_nextaddr: std_logic_vector(31 downto 4);
    sec_desc0: std_logic_vector(31 downto 0);
    sec_desc0_valid: std_logic;
    sec_cmd_ready: std_logic;
    sec_laststatus: std_logic_vector(23 downto 0);
    sec_last_excl: std_logic;
    sec_jump: std_logic;

    sec_active: std_logic;
    
    retrycount: std_logic_vector(2 downto 0);
    retrycount_total: std_logic_vector(3 downto 0);
    
    otherbus: std_logic;
    prim_slot_time_left: std_logic_vector(20 downto 0);  -- Signed 2:s compl value (us)
    sec_slot_time_left: std_logic_vector(17 downto 0);   -- Unsigned value (us)
    schemtime: std_logic_vector(23 downto 0);

    -- Per-RT bus mask, XOR:ed with bus selection bit
    rt_busmask: std_logic_vector(31 downto 0);
    -- Interrupt received
    got_irq: std_logic;
    -- Position in IRQ pointer ring
    irq_logbuf_pos: std_logic_vector(29 downto 0);

    got_trig: std_logic;
  end record;
  

  constant r_rst: cmdfsm_regs := (SCHEDULE,'0',
                                  '0','0',x"0000000",x"0000000",x"00000000",'0','0',x"000000",'0','0',
                                  '0',x"0000000",x"0000000",x"00000000",'0','0',x"000000",'0','0',
                                  '0',
                                  "000","0000",
                                  '0','0' & x"00000",x"0000" & "00",x"000000",                                  
                                  x"00000000",'0',x"0000000" & "00", '0');
    
  signal r,nr: cmdfsm_regs;

  signal d0: std_logic_vector(31 downto 0);
  signal ls: std_logic_vector(23 downto 0);
  signal sa,ia: std_logic;
  
  function statusbits(ts: gr1553b_transfer_status) return std_logic_vector is
  begin
--    case ts is
--      when SUCCESS => return "000";
--      when TIMEOUT => return "001";
--      when TIMEOUT2 => return "010";
--      when RTERROR => return "011";
--      when BUSERR => return "100";
--      when BADCMD => return "101";
--      when DMAERR => return "110";
--      when others => return "111";
--    end case;
    return std_logic_vector(ts);
  end;

  function zerov(w: integer) return std_logic_vector is
    variable v: std_logic_vector(w-1 downto 0) := (others => '0');
  begin
    return v;
  end;
  
begin

  
  comb: process(ins,dmao,proto,rst,us_tick,r)
    
    variable v: cmdfsm_regs;
    variable o: gr1553b_bc_control_out;
    variable di: gr1553b_dma2_in_bc;
    variable pi: gr1553b_bc_proto_in;

    variable vus_restart,vus_clear: std_logic;
    
    variable prim_slot_time_valz,prim_slot_time_sgn,sec_slot_time_valz: std_logic;
    variable prim_slot_time_lt24: std_logic;
    variable prim_slottime, sec_slottime: std_logic_vector(17 downto 0);

    variable desc0: std_logic_vector(31 downto 0);
    variable desc_retrymode: std_logic_vector(1 downto 0);
    variable desc_retrycount: std_logic_vector(2 downto 0);
    variable desc_storebus: std_logic;

    variable sched_choose_prim, sched_choose_sec: std_logic;

    variable laststatus: std_logic_vector(23 downto 0);

    variable status_cond_met,andmode_cond_met,ormode_cond_met,cond_met: std_logic;

    variable rt_busmask_bit, stbus_bit: std_logic;

    variable irqafter,stopafter: std_logic;
  begin

    v := r;
    vus_restart := '0';
    vus_clear := '0';
    
    desc0 := r.sec_desc0;
    laststatus := r.sec_laststatus;
    if r.sec_active='0' then
      desc0 := r.prim_desc0;
      laststatus := r.prim_laststatus;
    end if;
    
    stopafter := '0';
    irqafter := '0';
    if desc0(25)='1' or (desc0(26)='1' and laststatus(2 downto 0)/="000") or laststatus(2 downto 0)="101" then
      stopafter := '1';
    end if;
    if desc0(27)='1' or (desc0(28)='1' and laststatus(2 downto 0)/="000") or laststatus(2 downto 0)="101" then
      irqafter := '1';
    end if;

    d0 <= desc0;
    ls <= laststatus;
    ia <= irqafter;
    sa <= stopafter;
    
    desc_retrymode := desc0(D0_RETMODE_MSb downto D0_RETMODE_LSb);
    desc_retrycount := desc0(D0_RETCOUNT_MSb downto D0_RETCOUNT_LSb);
    desc_storebus := desc0(D0_RETSTORE_b);
    
    o := (sched_state => "000", async_state => "000",
          sched_current_pos => r.prim_cmdaddr & "0000", async_current_pos => r.sec_cmdaddr & "0000",
          sched_next_pos => r.prim_nextaddr & "0000", async_next_pos => r.sec_nextaddr & "0000",
          rt_busmask => r.rt_busmask,
          schem_time => r.schemtime,
          user_irq => r.got_irq, user_irq_next => '0',
          user_irq_addr => r.irq_logbuf_pos & "00",
          dmaerror_next => '0', validcmdA => proto.validcmdA, validcmdB => proto.validcmdB);
              
    di := (writestat => '0', writeirq => '0', getcmd => '0', 
           active => '0',  desc_addr => r.prim_cmdaddr, nextdesc_addr => r.prim_nextaddr,
           laststatus => x"00" & laststatus,
           irqbuf_pos => r.irq_logbuf_pos,
           data_reset => '0', need_data => '0', pull_data => proto.datain_read, pushing_data => '0',
           push_data => proto.dataout_write,
           push_done => proto.dataout_done);

    if r.sec_active='1' then
      di.desc_addr := r.sec_cmdaddr;
      di.nextdesc_addr := r.sec_nextaddr;
    end if;

      
    pi := (tfrstart => '0',
           tfrconfig => (
             rtaddr1 => dmao.bc_desc1(D1_RTADDR1_MSb downto D1_RTADDR1_LSb),
             samc1 => dmao.bc_desc1(D1_SAMC1_MSb downto D1_SAMC1_LSb),
             rtaddr2 => dmao.bc_desc1(D1_RTADDR2_MSb downto D1_RTADDR2_LSb),
             samc2 => dmao.bc_desc1(D1_SAMC2_MSb downto D1_SAMC2_LSb),
             wc_mode => dmao.bc_desc1(D1_WCMC_MSb downto D1_WCMC_LSb),
             tr => dmao.bc_desc1(D1_TR_b),
             extratime => dmao.bc_desc1(D1_EXTRATIME_MSb downto D1_EXTRATIME_LSb),
             extragap_en => desc0(D0_XGAP_b),
             bussel => r.bussel,
             dummy => dmao.bc_desc1(D1_DUMMY_b)
             ),
           datain_valid => dmao.can_pull, data_in=>dmao.pulldata, data_error => '0',
           fast_broadcast => ins.fast_broadcast );

    -- Timekeeping logic
    prim_slot_time_valz := '0';
    if r.prim_slot_time_left(19 downto 0) = "00000000000000000000" then
      prim_slot_time_valz := '1';
    end if;
    prim_slot_time_sgn := r.prim_slot_time_left(20);

    -- <24 us left of primary slot time
    prim_slot_time_lt24 := '0';
    if prim_slot_time_sgn='1' or
      (r.prim_slot_time_left(19 downto 6)=zerov(14) and r.prim_slot_time_left(5 downto 4)/="11") then
      prim_slot_time_lt24 := '1';
    end if;
    
    sec_slot_time_valz := '0';
    if r.sec_slot_time_left = "000000000000000000" then
      sec_slot_time_valz := '1';
    end if;
    
    if us_tick='1' then
      -- Decrease sched slot time left unless we would underflow (-2^20)
      if not (prim_slot_time_sgn='1' and prim_slot_time_valz='1') then
        v.prim_slot_time_left := std_logic_vector(unsigned(r.prim_slot_time_left) - 1);
      end if;
      if sec_slot_time_valz='0' then
        v.sec_slot_time_left := std_logic_vector(unsigned(r.sec_slot_time_left) - 1);
      end if;
      v.schemtime := std_logic_vector(unsigned(r.schemtime) + 1);
    end if;

    prim_slottime := r.prim_desc0(D0_TIMEOFFS_MSb downto D0_TIMEOFFS_LSb) & "00";
    sec_slottime := r.sec_desc0(D0_TIMEOFFS_MSb downto D0_TIMEOFFS_LSb) & "00";

    -- Conditional branch logic
    status_cond_met := '0';
    andmode_cond_met := '0';
    ormode_cond_met := '0';
    cond_met := '0';
    for s in 0 to 7 loop
      if desc0(s)='1' and unsigned(laststatus(2 downto 0))=to_unsigned(s,3) then
        status_cond_met := '1';
      end if;
    end loop;
    if (laststatus(23 downto 8) or not desc0(23 downto 8))=x"FFFF" and status_cond_met='1' then
      andmode_cond_met := '1';
    end if;
    if (laststatus(23 downto 8) and desc0(23 downto 8))/=x"0000" or status_cond_met='1' then
      ormode_cond_met := '1';
    end if;    
    if cond_en and ((desc0(24)='1' and andmode_cond_met='1') or (desc0(24)='0' and ormode_cond_met='1')) then
      cond_met := '1';      
    end if;
    
    if r.st /= SCHEDULE and r.sec_active='0' then
      o.sched_state := "001";
    elsif r.prim_run='0' then
      o.sched_state := "000";
    elsif r.prim_pause='1' then
      o.sched_state := "011";
    elsif r.prim_desc0_valid='1' and r.prim_desc0(30)='1' and r.got_trig='0' then
      o.sched_state := "100";
    else
      o.sched_state := "010";
    end if;

    if r.st /= SCHEDULE and r.sec_active='1' then
      o.async_state := "001";
    elsif r.sec_run='0' then
      o.async_state := "000";
    else
      o.async_state := "010";
    end if;
    
    if notx(dmao.bc_desc1(D1_RTADDR1_MSb downto D1_RTADDR1_LSb)) then
      rt_busmask_bit := r.rt_busmask(to_integer(unsigned(dmao.bc_desc1(D1_RTADDR1_MSb downto D1_RTADDR1_LSb))));
    end if;
    
    stbus_bit := r.bussel;
    if not (proto.status=TFR_SUCCESS) then
      stbus_bit := not stbus_bit;
    end if;
    
    ---------------------------------------------------------------------------
    -- Scheduler decision logic
    ---------------------------------------------------------------------------

    -- First choose, in order of priority:
    -- 
    -- 1. If the prim schedule is running and there is less than 24 us left
    --    of slack, then proceed with primary
    -- 2. If the sec schedule is enabled but descriptor word #0 hasn't been
    --    fetched, this should be fetched -> proceed with secondary
    -- 3. If the sec and prim schedules are enabled, compare sec DW0 time with
    --    slack and decide
    -- 4. If the prim schedule is enabled but descriptor word #0 hasn't been
    --    loaded, this must be loaded -> proceed with primary
    -- 5. Choose whichever is enabled
    -- 6. None
    --
    -- The primary schedule can then be blocked from proceeding by:
    --   1. the pause control bit is set
    --   2. the extsync descriptor bit is set and sync hasn't arrived.
    --   3. There is slot time remaining from the previous slot
    -- 
    -- The secondary schedule can be blocked by:
    --   1. The primary schedule is running and the last transfer had the exclusive
    --      descriptor bit set
    --   2. Secondary slot time left > 0 and the last secondary transfer had
    --      the exclusive bit set.
    --

    sched_choose_prim := '0';
    sched_choose_sec := '0';
    
    if r.prim_run='1' and r.prim_desc0_valid='1' and prim_slot_time_lt24='1' then
      
      sched_choose_prim := '1';

    elsif r.sec_run='1' and r.sec_desc0_valid='0' then

      sched_choose_sec := '1';

    elsif r.prim_run='1' and r.sec_run='1' and r.prim_last_excl='0' and 
      (prim_slot_time_sgn='0' and
       (r.prim_slot_time_left(19 downto 18)/="00" or
        unsigned(r.prim_slot_time_left(17 downto 0)) > unsigned(sec_slottime))) then

      sched_choose_sec := '1';

    elsif r.prim_run='1' and r.prim_desc0_valid='0' then

      sched_choose_prim := '1';

    elsif r.prim_run='1' then

      sched_choose_prim := '1';

    elsif r.sec_run='1' then

      sched_choose_sec := '1';

    end if;
          
    if r.prim_desc0_valid='1' and r.prim_desc0(30)='1' and r.got_trig='0' then
      sched_choose_prim := '0';
    end if;
    if r.prim_pause='1' then
      sched_choose_prim := '0';
    end if;
    if r.prim_cmd_ready='1' and prim_slot_time_sgn='0' and prim_slot_time_valz='0' and r.prim_desc0(30)='0' then
      sched_choose_prim := '0';
    end if;
    
    if (r.prim_last_excl='1' and r.prim_run='1' and prim_slot_time_sgn='0') or
      (r.sec_last_excl='1' and r.sec_run='1' and sec_slot_time_valz='0') then
      sched_choose_sec := '0';
    end if;

    ---------------------------------------------------------------------------
    -- Command processing FSM
    ---------------------------------------------------------------------------

    if dmao.bc_desc0_valid='1' then
      if r.sec_active='1' then
        v.sec_desc0 := dmao.bc_desc0_temp;
        v.sec_desc0_valid := '1';
      else
        v.prim_desc0 := dmao.bc_desc0_temp;
        v.prim_desc0_valid := '1';
      end if;
    end if;
    
    case r.st is

      when SCHEDULE =>

        if proto.tfrdone='1' then
          v.bussel := dmao.bc_desc1(D1_BUS_b) xor rt_busmask_bit;
        end if;
        
        v.retrycount := "000";
        v.retrycount_total := "0000";
        v.otherbus := '0';

        if r.prim_run='1' or r.sec_run='1' then
          di.data_reset := '1';
        end if;

        if r.prim_run='0' then
          v.schemtime := (others => '0');
          v.prim_slot_time_left := (others => '1');
          v.prim_last_excl := '0';
        end if;
        if r.sec_run='0' then
          v.sec_last_excl := '0';
        end if;

        if r.prim_run='0' and r.sec_run='0' then
          vus_clear := '1';
        end if;

        if r.prim_jump='1' then
          v.prim_desc0_valid := '0';
          v.prim_cmd_ready := '0';
          v.prim_jump := '0';
        end if;
        if r.sec_jump='1' then
          v.sec_desc0_valid := '0';
          v.sec_cmd_ready := '0';
          v.sec_jump := '0';
        end if;
        
        -- The (not us_tick) condition is to avoid updating the slot_time_left
        -- values at the same time they are decreased due to a us tick.
        if not us_tick='1' and v.bussel=r.bussel and r.prim_jump='0' and r.sec_jump='0' then

          -- What do we want to do next?          
          if sched_choose_prim='1' then
            
            v.sec_active := '0';
            if r.prim_cmd_ready='1' then
              if proto.ready='1' then
                v.st := NEWCMD;
                pi.tfrstart := '1';
                v.prim_slot_time_left := std_logic_vector(unsigned(r.prim_slot_time_left) + unsigned("000" & prim_slottime));
                v.prim_cmdaddr := r.prim_nextaddr;
                v.prim_nextaddr := std_logic_vector(unsigned(r.prim_nextaddr)+1);
                if r.got_trig='1' and r.prim_desc0(30)='1' then
                  v.got_trig := '0';
                  v.prim_slot_time_left := "000" & prim_slottime;
                  v.schemtime := (others => '0');
                  vus_restart := '1';
                end if;
                v.prim_last_excl := r.prim_desc0(29);
              end if;
            else
              v.st := DMASTART;
            end if;
            
          elsif sched_choose_sec='1' then

            v.sec_active := '1';
            if r.sec_cmd_ready='1' then
              if proto.ready='1' then
                v.st := NEWCMD;
                pi.tfrstart := '1';
                v.sec_slot_time_left := sec_slottime;
                v.sec_cmdaddr := r.sec_nextaddr;
                v.sec_nextaddr := std_logic_vector(unsigned(r.sec_nextaddr)+1);
                v.sec_last_excl := r.sec_desc0(29);
              end if;
            else
              v.st := DMASTART;
            end if;
            
          end if;
          
        end if;


        

      when NEWCMD =>

        if proto.datain_req='1' then
          di.need_data := '1';
        else
          di.pushing_data := '1';
          
        end if;

        if dmao.buf_dmaerror='1' or (proto.dataout_write='1' and dmao.can_push='0') then
          v.st := MEMERR;
          o.dmaerror_next := '1';
        elsif proto.tfrdone = '1' then
          v.st := CMDDONE;
        end if;


      when MEMERR =>
        -- For reads, just set datain_valid to 0 and let the protocol layer timeout
        -- For writes, use the data_error signal
        pi.data_error := '1';
        if proto.tfrdone='1' then
          v.st := CMDDONE;
        end if;

        
      when CMDDONE => 
        if proto.status /= TFR_SUCCESS and proto.status /= TFR_BADCMD and 
          (r.retrycount /= desc_retrycount or (desc_retrymode/=RETMODE_SAME and r.otherbus='0')) then 

          if proto.ready='1' then
            v.retrycount_total := std_logic_vector(unsigned(r.retrycount_total) + 1);
            if desc_retrymode=RETMODE_ALT then
              v.otherbus := not r.otherbus;
              v.bussel := not r.bussel;
              if r.otherbus='1' then
                v.retrycount := std_logic_vector(unsigned(r.retrycount) + 1);
              end if;
            else
              if r.retrycount = desc_retrycount then
                v.retrycount := (others=>'0');
                v.otherbus := not r.otherbus;
                v.bussel := not r.bussel;
              else
                v.retrycount := std_logic_vector(unsigned(r.retrycount) + 1);        
              end if;
            end if;
            
            v.st := RETRY;
          end if;
          
        else

          v.retrycount := "000";
          v.retrycount_total := "0000";
          v.otherbus := '0';
          
          if desc_storebus='1' and rtmask_en then            
            v.rt_busmask(to_integer(unsigned(dmao.bc_desc1(D1_RTADDR1_MSb downto D1_RTADDR1_LSb)))) := stbus_bit;
          end if;

          if r.sec_active='1' then
            v.sec_laststatus := proto.stword2 & proto.stword1 & r.retrycount_total & "0" & statusbits(proto.status);
            v.sec_desc0_valid := '0';
            v.sec_cmd_ready := '0';
          else
            v.prim_laststatus := proto.stword2 & proto.stword1 & r.retrycount_total & "0" & statusbits(proto.status);
            v.prim_desc0_valid := '0';
            v.prim_cmd_ready := '0';
          end if;
          
          v.st := FINISHED;
        end if;

        
      when RETRY => 
        di.data_reset := '1';

        v.st := NEWCMD;
        pi.tfrstart := '1';


      when FINISHED =>

        if stopafter='1' then
          if r.sec_active='0' then
            v.prim_pause := '1';
          else
            v.sec_run := '0';
          end if;
        end if;
        
        if dmao.ready='1' then
          di.writestat := '1';
          v.st := DMAWRITEWAIT;
        end if;

        
      when DMASTART =>

        di.getcmd:='1';

        if dmao.ready='1' then
          v.st := DMAWAIT;
        end if;


        
      when DMAWAIT =>

        if dmao.desc_dmaerror='1' then

          if r.sec_active='0' then
            v.prim_run := '0';
          else
            v.sec_run := '0';
          end if;
          o.dmaerror_next := '1';
          v.prim_cmd_ready := '0';
          v.sec_cmd_ready := '0';
          v.prim_desc0_valid := '0';
          v.sec_desc0_valid := '0';
          v.st := SCHEDULE;
          
        elsif dmao.bc_desc0_valid='1' and dmao.bc_desc0_temp(31)='1' then
          
          v.st := DMACOND;

        elsif dmao.ready='1' then

          if r.sec_active='0' then
            v.prim_cmd_ready := '1';
            v.sec_cmd_ready := '0';
          else
            v.sec_cmd_ready := '1';
            v.prim_cmd_ready := '0';
          end if;
          v.st := SCHEDULE;
          
        end if;


        
      when DMACOND =>

        if dmao.ready='1' then 
          if r.sec_active='0' then
            
            if r.prim_jump='0' then              
              v.prim_cmdaddr := r.prim_nextaddr;            
              if cond_met='1' and r.prim_desc0(25)='1' then
                v.prim_nextaddr := dmao.bc_desc0_temp(31 downto 4);
              else
                v.prim_nextaddr := std_logic_vector(unsigned(r.prim_nextaddr)+1);
              end if;
              if (not cond_en) or (cond_met='1' and r.prim_desc0(25)='0') then
                v.prim_pause := '1';
              end if;
              if cond_met='1' and r.prim_desc0(26)='1' then
                v.st := DMAWRITEWAIT;
                di.writeirq := '1';
              else
                v.st := SCHEDULE;
              end if;
              v.prim_desc0_valid := '0';
              v.prim_cmd_ready := '0';
            else
              v.st := SCHEDULE;
            end if;
            
          else

            if r.sec_jump='0' then
              v.sec_cmdaddr := r.sec_nextaddr;
              if cond_met='1' and r.sec_desc0(25)='1' then
                v.sec_nextaddr := dmao.bc_desc0_temp(31 downto 4);
              else
                v.sec_nextaddr := std_logic_vector(unsigned(r.sec_nextaddr)+1);
              end if;
              if (not cond_en) or (cond_met='1' and r.sec_desc0(25)='0') then
                v.sec_run := '0';
              end if;
              if cond_met='1' and r.sec_desc0(26)='1' then
                v.st := DMAWRITEWAIT;
                di.writeirq := '1';
              else
                v.st := SCHEDULE;
              end if;
              v.sec_desc0_valid := '0';
              v.sec_cmd_ready := '0';
            else
              v.st := SCHEDULE;
            end if;            
            
          end if;          
        end if;


      when DMAWRITEWAIT =>

        if (r.sec_active='0' and sched_choose_prim='1' and r.prim_jump='0') or
          (r.sec_active='1' and sched_choose_sec='1' and r.sec_jump='0') then
          di.getcmd := '1';
        end if;        
        
        if irqafter='1' and dmao.ready='0' then
          di.writeirq := '1';
        end if;
        
        if dmao.bc_write_done='1' then
          v.st := DMAWAIT;
        elsif dmao.ready='1' then
          v.st := SCHEDULE;
        end if;
        
        
    end case;    


    if ins.sched_start='1' then
      v.prim_run := '1';
      v.prim_pause := '0';
    end if;
    if ins.sched_stop='1' then
      v.prim_run := '0';
    end if;
    if ins.sched_pause='1' then
      v.prim_pause := '1';
    end if;

    if ins.async_start='1' then
      v.sec_run := '1';
    end if;
    if ins.async_stop='1' then
      v.sec_run := '0';
    end if;
    
    if ins.sched_trig='1' then
      v.got_trig := '1';
    elsif ins.sched_trig_clear='1' or r.prim_run='0' then
      v.got_trig := '0';
    end if;

    if dmao.bc_writeirq_done='1' then
      v.got_irq := '1';
      o.user_irq_next := '1';
      v.irq_logbuf_pos(3 downto 0) := std_logic_vector(unsigned(r.irq_logbuf_pos(3 downto 0))+1);      
    end if;

    -- External register access
    if ins.set_schem_addr='1' then
      v.prim_nextaddr := ins.user_input(31 downto 4);
      v.prim_jump := '1';
    end if;
    if ins.set_async_addr='1' then
      v.sec_nextaddr := ins.user_input(31 downto 4);
      v.sec_jump := '1';
    end if;
      
    if ins.set_logbuf_pos='1' then
      v.irq_logbuf_pos := ins.user_input(31 downto 2);
    end if;
    if rtmask_en and ins.set_rt_busmask='1' then
      v.rt_busmask := ins.user_input;
    end if;
    
    if ins.user_irq_ack='1' then
      v.got_irq := '0';
    end if;
      
    if rst='0' and syncrst/=0 then
      v.st := r_rst.st;
      v.got_irq := r_rst.got_irq;
      v.prim_run := r_rst.prim_run;
      v.prim_cmdaddr := r_rst.prim_cmdaddr;
      v.prim_nextaddr := r_rst.prim_nextaddr;
      v.prim_desc0_valid := r_rst.prim_desc0_valid;
      v.prim_cmd_ready := r_rst.prim_cmd_ready;
      v.prim_laststatus := r_rst.prim_laststatus;
      v.prim_jump := r_rst.prim_jump;
      v.sec_run := r_rst.sec_run;
      v.sec_cmdaddr := r_rst.sec_cmdaddr;
      v.sec_nextaddr := r_rst.sec_nextaddr;
      v.sec_desc0_valid := r_rst.sec_desc0_valid;
      v.sec_cmd_ready := r_rst.sec_cmd_ready;
      v.sec_laststatus := r_rst.sec_laststatus;
      v.sec_jump := r_rst.sec_jump;
      v.rt_busmask := r_rst.rt_busmask;
      v.got_irq := r_rst.got_irq;
      v.irq_logbuf_pos := r_rst.irq_logbuf_pos;
      v.got_trig := r_rst.got_trig;
      if syncrst>1 then
        v := r_rst;
      end if;
    end if;

    nr <= v;
    outs <= o;
    dmai <= di;
    proti <= pi;
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
