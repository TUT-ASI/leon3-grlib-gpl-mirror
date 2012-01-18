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
-- Entity:      gr1553b_apb
-- File:        gr1553b_apb.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B APB user interface
--              Also contains glue logic for the auxin/out signals and IRQ,
--              plus manages the time tag counters for RT/BM
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.notx;
use work.gr1553b_core.all;

entity gr1553b_apb is
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
    schemtime_en: boolean := false;
    wakeup_en: boolean := false;
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
    rtaddr: in std_logic_vector(4 downto 0);
    rtaddrpar: in std_logic;
    rt_sync: out std_logic;
    rt_busreset: out std_logic;
    
    rtts_tick: in std_logic;
    rtts_restart: out std_logic;
    rtts_clear: out std_logic;

    badreg: out std_logic;
    xirqvec: out std_logic_vector(7 downto 0);
    
    rt_run: out std_logic;
    bc_run: out std_logic;
    bm_run: out std_logic
    );
end;

architecture rtl of gr1553b_apb is

  type apbiface_regs is record
    irq_enable_bc: std_logic_vector(2 downto 0);
    irq_enable_rt: std_logic_vector(2 downto 0);
    irq_enable_bm: std_logic_vector(1 downto 0);
    bc_timed_irq: std_logic;
    bc_dmaerror: std_logic;
    bc_wakeup_time: std_logic_vector(23 downto 0);
    bc_wakeup_enable: std_logic;
    bc_syncreg: std_logic_vector(0 to 2);
    bc_check_broadcast: std_logic;
    in_rtaddr_reg: std_logic_vector(4 downto 0);
    in_rtpar_reg: std_logic;
    rt_enable_reg: std_logic;
    rt_addr: std_logic_vector(4 downto 0);
    rt_addr_par_ok: std_logic;
    rt_addr_checked: std_logic_vector(1 downto 0);
    rt_statusbits: std_logic_vector(4 downto 0);
    rt_timetag_res: unsigned(15 downto 0);
    rt_timetag_value: unsigned(15 downto 0);
    rt_timetag_ctr: unsigned(15 downto 0);
    rt_vector_word: std_logic_vector(15 downto 0);
    rt_BIT_word: std_logic_vector(15 downto 0);
    rt_set_tf: std_logic;
    rt_syncsig_enable: std_logic;
    rt_syncdatasig_enable: std_logic;
    rt_sync: std_logic;
    rt_busreset_enable: std_logic;
    rt_busreset: std_logic;
    bm_timetag_res: unsigned(7 downto 0);
    bm_timetag_value: unsigned(23 downto 0);
    bm_timetag_ctr: unsigned(7 downto 0);
    bm_enable: std_logic;
    bm_log_errors: std_logic;
    bm_log_stray_data: std_logic;
    bm_log_reserved_mcs: std_logic;
    bm_timer_overflow: std_logic;
    bm_syncstart: std_logic;
    bm_wrapstop: std_logic;
    pirq: std_logic;
    badreg: std_logic;
    xirqv: std_logic_vector(7 downto 0);
  end record;
  
  constant pconfig: apb_config_type := (
    0 => ahb_device_reg ( venid, devid, cfgver, version, pirq ),
    1 => apb_iobar(paddr, pmask));

  constant r_rst: apbiface_regs :=
    (irq_enable_bc => "000",irq_enable_rt => "000",irq_enable_bm => "00",
     bc_timed_irq => '0',bc_dmaerror => '0',bc_wakeup_time => (others => '0'),
     bc_syncreg => "000",bc_check_broadcast => '0',rt_enable_reg => '0',
     rt_addr => (others => '1'),rt_addr_par_ok => '0',rt_addr_checked => "00",rt_statusbits => (others => '0'),
     rt_timetag_res => (others => '0'),rt_timetag_value => (others => '0'),
     rt_vector_word => (others=>'0'),rt_bit_word => (others=>'0'),rt_set_tf => '0',
     rt_syncsig_enable => '1',rt_syncdatasig_enable => '1',rt_busreset_enable => '1',
     bc_wakeup_enable => '0',rt_timetag_ctr => (others => '0'),bm_timetag_res => (others => '0'),
     bm_timetag_value => (others => '0'),bm_timetag_ctr => (others => '0'),
     bm_enable => '0',bm_log_errors => '0',bm_log_stray_data => '0',bm_log_reserved_mcs => '0',
     bm_timer_overflow => '0', bm_syncstart => '0', bm_wrapstop => '0',
     pirq => '0', badreg => '0',
     in_rtaddr_reg => "11111", in_rtpar_reg => '1', rt_sync => '0', rt_busreset => '0',
     xirqv => (others => '0')
     );
  
  signal r,nr: apbiface_regs;
  
begin

  apbso.pindex <= pindex;
  apbso.pconfig <= pconfig;
  
  comb: process(rst,apbsi,bcct_outs,rtct_outs,bmct_outs,r,rtts_tick,bc_extsync,rtaddr,rtaddrpar)
    variable rddata: std_logic_vector(31 downto 0);
    variable wrdata: std_logic_vector(31 downto 0);
    variable vpirq: std_logic_vector(NAHBIRQ-1 downto 0);
    variable virq: std_logic;
    variable do_write,bc_write,rt_write,bm_write,do_read: boolean;
    variable irqack: std_logic_vector(6 downto 0);
    variable vnr: apbiface_regs;
    variable vbcct_in: gr1553b_bc_control_in;
    variable vrtct_in: gr1553b_rt_control_in;
    variable vbmct_in: gr1553b_bm_in;
    variable vbc_run,vrt_run: std_logic;
    variable vus_restart,vus_clear,bm_timerreg_set: std_logic;
    variable bc_outbuf_pos_before: std_logic;
    variable extsync_edge: std_logic;
  begin
    vpirq := (others=>'0');
    rddata := (others=>'0');
    wrdata := apbsi.pwdata;
    irqack := (others=>'0');
    virq := '0';
    do_write := false;
    bc_write := false;
    rt_write := false;
    do_read := false;
    vnr := r;
    vnr.xirqv := (others => '0');
    vbc_run := '0';
    vrt_run := '0';
    vus_restart := '0';
    vus_clear := '0';
    bm_timerreg_set := '0';
    bc_outbuf_pos_before := '0';
    vbcct_in := (
      sched_start => '0', sched_stop => '0', sched_pause => '0',
      sched_trig => '0', sched_trig_clear => '0',
      async_start => '0', async_stop => '0', 
      user_input => apbsi.pwdata,
      set_schem_addr => '0', set_async_addr => '0', user_irq_ack => '0', set_logbuf_pos => '0',
      set_rt_busmask => '0', fast_broadcast => not r.bc_check_broadcast);
    vrtct_in := (
      rt_enable => '0', rt_stop => '0', rt_addr => r.rt_addr, allow_bc => '1',
      statusbits => r.rt_statusbits,
      timer_value => std_logic_vector(r.rt_timetag_value),
      dmaerror_ack => '0', irqack => '0', descerror_ack => '0',
      user_input => apbsi.pwdata,
      vector_word => r.rt_vector_word, bit_word => r.rt_bit_word,
      set_modecode_mask => '0',
      set_subaddr_table_base => '0',
      set_log_mask => '0', set_log_cur_addr => '0');
    vbmct_in := (
      enable => r.bm_enable, timeval => std_logic_vector(r.bm_timetag_value),
      log_errors => r.bm_log_errors, log_stray_data => r.bm_log_stray_data, log_reserved_mcs => r.bm_log_reserved_mcs,
      set_outbuf_start => '0', set_outbuf_end => '0', set_outbuf_pos => '0', set_rtaddr_filter => '0',
      set_subaddr_filter => '0', set_modecode_filter => '0', user_input => apbsi.pwdata, dmaerror_ack => '0');
    vnr.badreg := '0';
    
    vnr.rt_sync := (rtct_outs.bussync_nodata and r.rt_syncsig_enable) or (rtct_outs.bussync_data and r.rt_syncdatasig_enable);

    vnr.rt_busreset := rtct_outs.busreset and r.rt_busreset_enable;
    
    -- Resync / edge detect BC sync pulse
    vnr.bc_syncreg := r.bc_syncreg(1 to 2) & bc_extsync;
    if r.bc_syncreg(0 to 1)="01" then
      extsync_edge := '1';
    else
      extsync_edge := '0';
    end if;
    
    if r.rt_enable_reg = '1' then
      vrt_run := '1';
      vrtct_in.rt_enable := '1';
    end if;
    if bcct_outs.sched_state /= "000" or bcct_outs.async_state /= "000" then
      vbc_run := '1';
      vrtct_in.rt_stop := '1';
    end if;

    if apbsi.penable='1' and apbsi.psel(pindex)='1' then
      if apbsi.pwrite='1' then
        do_write := true;
      else
        do_read := true;
      end if;
    end if;
    bc_write := do_write and bc_enable=1;
    rt_write := do_write and rt_enable=1;
    bm_write := do_write and bm_enable=1;
    
    -- APB address decode
    case apbsi.paddr(7 downto 6) is

      -- Common regs
      when "00" =>
        case apbsi.paddr(5 downto 2) is
          when "0000" =>                -- IRQ status (read)/ack (write)
            rddata(0) := bcct_outs.user_irq;
            rddata(1) := r.bc_dmaerror;
            rddata(2) := r.bc_timed_irq;
            rddata(8) := rtct_outs.gotirq;
            rddata(9) := rtct_outs.dmaerror;
            rddata(10) := rtct_outs.descerror;
            rddata(16) := bmct_outs.dmaerror;
            rddata(17) := r.bm_timer_overflow;
            if do_write then
              vbcct_in.user_irq_ack := wrdata(0);
              if wrdata(1)='1' then vnr.bc_dmaerror:='0'; end if;
              if wrdata(2)='1' then vnr.bc_timed_irq:='0'; end if;
              vrtct_in.irqack := wrdata(8);
              vrtct_in.dmaerror_ack := wrdata(9);
              vrtct_in.descerror_ack := wrdata(10);
              vbmct_in.dmaerror_ack:=wrdata(16);
              if wrdata(17)='1' then vnr.bm_timer_overflow:='0'; end if;
            end if;

          when "0001" =>                -- IRQ enable reg
            rddata(2 downto 0) := r.irq_enable_bc;
            rddata(10 downto 8) := r.irq_enable_rt;
            rddata(17 downto 16) := r.irq_enable_bm;

            if not wakeup_en then rddata(2):='0'; end if;
            
            if do_write then
              if bc_enable=1 then
                vnr.irq_enable_bc := wrdata(2 downto 0);
              end if;
              if rt_enable=1 then
                vnr.irq_enable_rt := wrdata(10 downto 8);
              end if;
              if bm_enable=1 then
                vnr.irq_enable_bm := wrdata(17 downto 16);
              end if;
            end if;

          when "0100" =>  -- Hardware config reg.
            if core_modified then rddata(31) := '1'; end if;
            if extrakeyen=1 then rddata(11):='1'; end if;
            rddata(10 downto 9) := std_logic_vector(to_unsigned(endianness,2));
            if codec_clk_freq_mhz /= 20 or sameclk=1 then
              rddata(7 downto 0) := std_logic_vector(to_unsigned(codec_clk_freq_mhz,8));
              rddata(8 downto 8) := std_logic_vector(to_unsigned(sameclk,1));
            end if;
            if do_write then vnr.badreg:='1'; end if;
            
          when others =>
            if do_read or do_write then vnr.badreg := '1'; end if;
            
        end case;

      -- BC regs
      when "01" =>
        if bc_enable=1 then
          case apbsi.paddr(5 downto 2) is
            when "0000" =>                -- BC status (RO) + Config(RW)
              rddata(31) := '1';
              if schemtime_en then rddata(30):='1'; end if;
              if wakeup_en then rddata(29):='1'; end if;
              if rtbusmask_en then rddata(28):='1'; end if;
              rddata(15 downto 0) := 
                bcct_outs.async_next_pos(8 downto 4) & bcct_outs.async_state &
                bcct_outs.sched_next_pos(8 downto 4) & bcct_outs.sched_state;
              
              rddata(16) := r.bc_check_broadcast;
              if bc_write then
                vnr.bc_check_broadcast := wrdata(16);
              end if;
                
              
            when "0001" =>                -- BC action (WO)
              if bc_write and wrdata(31 downto 16)=x"1552" then 
                vbcct_in.sched_start := wrdata(0);
                vbcct_in.sched_pause := wrdata(1);
                vbcct_in.sched_stop := wrdata(2);
                vbcct_in.sched_trig := wrdata(3);
                vbcct_in.sched_trig_clear := wrdata(4);
                vbcct_in.async_start := wrdata(8);
                vbcct_in.async_stop := wrdata(9);
              elsif bc_write or do_read then
                vnr.badreg := '1';
              end if;

            when "0010" =>              -- BC transfer list next ptr
              rddata := bcct_outs.sched_next_pos;
              if bc_write then vbcct_in.set_schem_addr:='1'; end if;

            when "1010" =>              -- BC transfer current slot
              rddata := bcct_outs.sched_current_pos;
              if bc_write then vnr.badreg:='1'; end if;

            when "0011" =>              -- BC transfer list next ptr
              rddata := bcct_outs.async_next_pos;
              if bc_write then vbcct_in.set_async_addr:='1'; end if;

            when "1011" =>              -- BC transfer current slot
              rddata := bcct_outs.async_current_pos;
              if bc_write then vnr.badreg:='1'; end if;
        
            when "0100" =>                -- BC timer (RO)
              if schemtime_en then
                rddata := "00000000" & bcct_outs.schem_time;
              end if;
              if bc_write then vnr.badreg := '1'; end if;                               
              
            when "0101" =>                -- BC wakeup time
              if wakeup_en then 
                rddata := r.bc_wakeup_enable & "0000000" & r.bc_wakeup_time;
                if bc_write then
                  vnr.bc_wakeup_enable:=wrdata(31);
                  vnr.bc_wakeup_time:=wrdata(23 downto 0);
                end if;
              end if;
        
            when "0110" =>                -- BC IRQ pointer ring pos              
              rddata := bcct_outs.user_irq_addr;
              if bc_write then vbcct_in.set_logbuf_pos := '1'; end if;

            when "0111" =>                -- BC RT bus mask
              rddata := bcct_outs.rt_busmask;
              if bc_write then vbcct_in.set_rt_busmask:='1'; end if;
              
            when others =>
              if do_read or do_write then
                vnr.badreg := '1';
              end if;
              
          end case;
        else
          if (do_read and apbsi.paddr(5 downto 2)/="0000") or do_write then
            vnr.badreg := '1';
          end if;
        end if;
        
      -- RT regs
      when "10" =>
        if rt_enable=1 then
          case apbsi.paddr(5 downto 2) is

            when "0000" =>                -- RT status (RO)
              rddata(31) := '1';
              rddata(3 downto 0) := 
                rtct_outs.active & rtct_outs.shutdownA & rtct_outs.shutdownB & vrt_run;
              if rt_write then vnr.badreg:='1'; end if;
              
            when "0001" =>                -- RT config
              rddata(15) := r.rt_syncsig_enable;
              rddata(14) := r.rt_syncdatasig_enable;
              rddata(13) := r.rt_busreset_enable;
              rddata(6) := r.rt_addr_par_ok;
              rddata(5 downto 1) := r.rt_addr;
              rddata(0) := r.rt_enable_reg;
              if rt_write then
                if wrdata(31 downto 16) = x"1553" then
                  vnr.rt_addr_par_ok := '0';
                  vnr.rt_addr := wrdata(5 downto 1);
                end if;
                if extrakeyen=0 or wrdata(23 downto 16) = x"53" then
                  vnr.rt_enable_reg := wrdata(0);
                  vnr.rt_syncsig_enable := wrdata(15);
                  vnr.rt_syncdatasig_enable := wrdata(14);
                  vnr.rt_busreset_enable := wrdata(13);
                else
                  vnr.badreg := '1';
                end if;
              end if;
              
            when "0010" =>                -- RT bus status bits
              rddata(4 downto 0) := r.rt_statusbits;
              rddata(8) := r.rt_set_tf;
              if rt_write then
                vnr.rt_statusbits:=wrdata(4 downto 0);
                vnr.rt_set_tf := wrdata(8);
              end if;
              
            when "0011" =>                -- RT bit/vector word
              rddata(31 downto 16) := r.rt_bit_word;
              rddata(15 downto 0) := r.rt_vector_word;
              if rt_write then
                vnr.rt_bit_word := wrdata(31 downto 16);
                vnr.rt_vector_word := wrdata(15 downto 0);
              end if;
              
            when "0100" =>                  -- RT sync register
              rddata := rtct_outs.bussync_time & rtct_outs.bussync_word;
              if rt_write then
                vnr.badreg := '1';
              end if;
              
            when "0101" =>                -- RT subaddress table base
              rddata := rtct_outs.subaddr_table_base;
              if rt_write then vrtct_in.set_subaddr_table_base:='1'; end if;
              
            when "0110" =>                -- RT modecode control reg 
              rddata(29 downto 0) := rtct_outs.modecode_mask;
              if rt_write then vrtct_in.set_modecode_mask:='1'; end if;
              
            when "1001" =>                -- RT time tag register
              rddata := std_logic_vector(r.rt_timetag_res) &
                        std_logic_vector(r.rt_timetag_value);
              if rt_write then
                vnr.rt_timetag_res := unsigned(wrdata(31 downto 16));
                vnr.rt_timetag_value := unsigned(wrdata(15 downto 0));
                vus_restart := '1';
              end if;
              
            when "1011" =>                  -- RT event log mask
              rddata := rtct_outs.log_mask;
              if rt_write then vrtct_in.set_log_mask:='1'; end if;
              
            when "1100" =>                  -- RT event log pos.
              rddata := rtct_outs.log_cur_addr;
              if rt_write then vrtct_in.set_log_cur_addr:='1'; end if;
              
            when "1101" =>                  -- RT event log IRQ pos.
              rddata := rtct_outs.irq_log_addr;
              if rt_write then vnr.badreg:='1'; end if;
              
            when others =>
              if do_read or do_write then
                vnr.badreg := '1';
              end if;
              
          end case;
        else
          if (do_read and apbsi.paddr(5 downto 2)/="0000") or do_write then
            vnr.badreg := '1';
          end if;
        end if;
        
      -- BM regs
      when "11" =>
        if bm_enable=1 then
          case apbsi.paddr(5 downto 2) is
            
            when "0000" =>                  -- BM status
              if bm_enable=1 then
                rddata(31) := '1';
                if extrakeyen=1 then
                  rddata(30) := '1';
                end if;
              end if;
              if bm_write then vnr.badreg:='1'; end if;
              
            when "0001" =>                  -- BM config
              rddata(5 downto 0) := r.bm_wrapstop & r.bm_syncstart & r.bm_log_reserved_mcs &
                                    r.bm_log_stray_data & r.bm_log_errors & r.bm_enable;
              if bm_write and (extrakeyen=0 or wrdata(31 downto 16)=x"1543") then
                vnr.bm_wrapstop := wrdata(5);
                vnr.bm_syncstart := wrdata(4);
                if bm_filters /= 0 then
                  vnr.bm_log_reserved_mcs := wrdata(3);
                  vnr.bm_log_stray_data := wrdata(2);
                end if;
                vnr.bm_log_errors := wrdata(1);
                vnr.bm_enable := wrdata(0);
              elsif bm_write then
                vnr.badreg:='1';
              end if;
              
            when "0010" =>                  -- BM address filter
              rddata := bmct_outs.rtaddr_filter;
              if bm_write then vbmct_in.set_rtaddr_filter:='1'; end if;
              
            when "0011" =>                  -- BM subaddr filter
              rddata := bmct_outs.subaddr_filter;
              if bm_write then vbmct_in.set_subaddr_filter:='1'; end if;        
              
            when "0100" =>                  -- BM modecode filter
              rddata := bmct_outs.modecode_filter;
              if bm_write then vbmct_in.set_modecode_filter:='1'; end if;
              
            when "0101" =>                  -- BM output buffer start
              rddata := bmct_outs.outbuf_start;
              if bm_write then vbmct_in.set_outbuf_start:='1'; end if;        
              
            when "0110" =>                  -- BM output buffer end
              rddata := bmct_outs.outbuf_end;
              if bm_write then vbmct_in.set_outbuf_end:='1'; end if;
              
            when "0111" =>                  -- BM output buffer pos
              rddata := bmct_outs.outbuf_pos;
              if bm_write then vbmct_in.set_outbuf_pos:='1'; end if;
              
            when "1000" =>                  -- BM time tag register
              rddata := std_logic_vector(r.bm_timetag_res) &
                        std_logic_vector(r.bm_timetag_value);
              if bm_write then
                vnr.bm_timetag_res := unsigned(wrdata(31 downto 24));
                vnr.bm_timetag_value := unsigned(wrdata(23 downto 0));
                bm_timerreg_set := '1';
                if rt_enable=0 then vus_restart:='1'; end if;
              end if;
              
            when others =>
              if do_read or do_write then
                vnr.badreg := '1';
              end if;
              
          end case;
        else
          if (do_read and apbsi.paddr(5 downto 2)/="0000") or do_write then
            vnr.badreg := '1';
          end if;
        end if;
      when others =>
        if do_read or do_write then
          vnr.badreg := '1';
        end if;
    end case;
    
    if r.rt_enable_reg='1' and notx(std_logic_vector(r.rt_timetag_ctr)) then 
      if vus_restart='1' or (rtts_tick='1' and r.rt_timetag_ctr = r.rt_timetag_res) then
        vnr.rt_timetag_ctr := (others => '0');
      elsif rtts_tick='1' then
        vnr.rt_timetag_ctr := r.rt_timetag_ctr + 1;
      end if;
      
      if vus_restart='0' and rtts_tick='1' and r.rt_timetag_ctr = r.rt_timetag_res then
        vnr.rt_timetag_value := r.rt_timetag_value + 1;
      end if;
    end if;
    
    if notx(std_logic_vector(r.bm_timetag_ctr)) then
      if bm_timerreg_set='1' or (rtts_tick='1' and r.bm_timetag_ctr = r.bm_timetag_res) then
        vnr.bm_timetag_ctr := (others => '0');
      elsif rtts_tick='1' and r.bm_enable='1' then
        vnr.bm_timetag_ctr := r.bm_timetag_ctr + 1;
        
      end if;
      
      if r.bm_enable='1' and bm_timerreg_set='0' and rtts_tick='1' and r.bm_timetag_ctr=r.bm_timetag_res then
        vnr.bm_timetag_value := r.bm_timetag_value+1;
        if std_logic_vector(vnr.bm_timetag_value)=x"000000" and r.bm_timer_overflow='0' then
          vnr.bm_timer_overflow := '1';
          if r.irq_enable_bm(1)='1' then virq := '1'; vnr.xirqv(7):='1'; end if;
        end if;
      end if;
    end if;

    if r.rt_enable_reg='0' and r.bm_enable='0' then
      vus_clear := '1';
      vnr.rt_timetag_ctr := (others => '0');
    end if;
    
    if bc_enable=1 then
      if r.bc_wakeup_time = bcct_outs.schem_time and r.bc_wakeup_enable='1' then
        if r.bc_timed_irq='0' then
          if r.irq_enable_bc(2)='1' then virq := '1'; vnr.xirqv(2):='1'; end if;
          vnr.bc_timed_irq := '1';
        end if;
      end if;           
    end if;
    
    if bcct_outs.user_irq_next='1' and bcct_outs.user_irq='0' then
      if r.irq_enable_bc(0)='1' then virq := '1'; vnr.xirqv(0):='1'; end if;
    end if;
    if bcct_outs.dmaerror_next='1' and r.bc_dmaerror='0' then
      vnr.bc_dmaerror := '1';
      if r.irq_enable_bc(1)='1' then virq := '1'; vnr.xirqv(1):='1'; end if;
    end if;
    if rtct_outs.gotirq_next='1' and rtct_outs.gotirq='0' then
      if r.irq_enable_rt(0)='1' then virq := '1'; vnr.xirqv(3):='1'; end if;
    end if;
    if rtct_outs.dmaerror_next='1' and rtct_outs.dmaerror='0' then
      if r.irq_enable_rt(1)='1' then virq := '1'; vnr.xirqv(4):='1'; end if;
      if r.rt_set_tf='1' then vnr.rt_statusbits(0):='1'; end if;
    end if;
    if rtct_outs.descerror_next='1' and rtct_outs.descerror='0' then
      if r.irq_enable_rt(2)='1' then virq := '1'; vnr.xirqv(5):='1'; end if;
      if r.rt_set_tf='1' then vnr.rt_statusbits(0):='1'; end if;
    end if;
    if bmct_outs.dmaerror_next='1' and bmct_outs.dmaerror='0' then
      if r.irq_enable_bm(0)='1' then virq := '1'; vnr.xirqv(6):='1'; end if;
    end if;

    if rtct_outs.busreset='1' then
      vnr.rt_statusbits(0) := '0';
      vnr.rt_statusbits(4) := '0';
    end if;

    vnr.rt_addr_checked(0) := '1';
    if r.rt_addr_checked="01" then
      if (r.in_rtaddr_reg(4) xor r.in_rtaddr_reg(3) xor r.in_rtaddr_reg(2) xor
          r.in_rtaddr_reg(1) xor r.in_rtaddr_reg(0) xor r.in_rtpar_reg)='1' then
        vnr.rt_addr := r.in_rtaddr_reg;
        vnr.rt_addr_par_ok := '1';
      end if;
      vnr.rt_addr_checked(1) := '1';
    end if;

    if r.bm_syncstart='1' and extsync_edge='1' then
      vnr.bm_enable := '1';
    end if;
    if r.bm_wrapstop='1' and bmct_outs.wrapping='1' then
      vnr.bm_enable := '0';
      vnr.bm_syncstart := '0';
    end if;
    
    if rst='0' and syncrst/=0 then
      vnr := r_rst;
      -- Don't reset bc_syncreg
      vnr.bc_syncreg := r.bc_syncreg(1 to 2) & bc_extsync;
    end if;

    vnr.in_rtaddr_reg := rtaddr;
    vnr.in_rtpar_reg := rtaddrpar;

    vbcct_in.sched_trig := vbcct_in.sched_trig or extsync_edge;

    vnr.pirq := virq;
    vpirq(pirq) := r.pirq;
    
    apbso.prdata <= rddata;
    apbso.pirq <= vpirq;    
    nr <= vnr;
    bcct_in <= vbcct_in;
    rtct_in <= vrtct_in;
    bmct_in <= vbmct_in;
    rt_run <= vrt_run;
    bc_run <= vbc_run;
    bm_run <= r.bm_enable;
    rtts_restart <= vus_restart;
    rtts_clear <= vus_clear;
    rt_sync <= r.rt_sync;
    rt_busreset <= r.rt_busreset;
    badreg <= r.badreg;
    xirqvec <= r.xirqv;
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
