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
-- Entity:      gr1553b_dma2
-- File:        gr1553b_dma2.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B BC/RT/BM AHB DMA State Machine
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.amba.all;
library gaisler;
use gaisler.gr1553b_core.all;

entity gr1553b_dma2 is
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
end;

architecture rtl of gr1553b_dma2 is

  type dma2_state is (IDLE,
                      BCWSTAT,BCWIRQ,BCRDESC0,BCRDESC1,BCRDESC2,BCRDESC3,
                      RTRSAT0,RTRSAT1,RTRSAT2,RTRSAT3,RTRDESC0,RTRDESC1,RTRDESC2,
                      RTWSTAT,RTRNEXT,RTWNEXT,RTWWRAP,RTWLOG,
                      TFRDATA,
                      BMWLOG0, BMWLOG1, BMWLOG2);
  
  type dma2_regs is record
    state: dma2_state;
    
    -- buf 0 usage:
    -- * Connected to mo.hwdata, therefore used in all write states
    -- * temporary holding of BC descriptor word #0
    -- * temporary holding of BC branch addr
    -- * temporary holding of RT SA table word #0 (legalization info, IRQ
    --   settings, etc)
    buf0: std_logic_vector(31 downto 0);
    -- buf 1 usage:
    -- * Hold BC descriptor word #1 during transfer
    -- * Hold RT descriptor address
    buf1: std_logic_vector(31 downto 0);
    -- buf 2 usage
    -- * Hold BC data buffer address during transfer
    -- * Hold RT data buffer address during transfer
    buf2: std_logic_vector(31 downto 0);
    -- buf 3 usage:
    -- * temporary holding of RT descriptor word #0
    -- * Hold payload data for RT/BC transfers
    buf3: std_logic_vector(31 downto 0);

    addr_offs: std_logic_vector(5 downto 1);    
    got32,got16: std_logic;
    
    desc_dmaerror: std_logic;
    buf_dmaerror: std_logic;
    
    
    
    ahb_addr_owner: std_logic;
    ahb_data_owner: std_logic;
    mo_hbusreq: std_logic;
    mo_haddr: std_logic_vector(31 downto 0);
    mo_htrans: std_logic_vector(1 downto 0);
    mo_hburst: std_logic_vector(2 downto 0);
    mo_hwrite: std_logic;
    mo_hsize: std_logic_vector(2 downto 0);
  end record;

  constant r_rst: dma2_regs :=
    (state => IDLE,
     ahb_addr_owner => '0', ahb_data_owner => '0',
     mo_hbusreq => '0', mo_haddr => x"00000000", mo_htrans => HTRANS_IDLE,
     mo_hburst => HBURST_SINGLE, mo_hwrite => '0', mo_hsize => "010",
     buf0 => x"00000000", buf1 => x"00000000", buf2 => x"00000000", buf3 => x"00000000",
     addr_offs => "00000", got32 => '0', got16 => '0',
     desc_dmaerror => '0', buf_dmaerror => '0');
  
  signal r,nr: dma2_regs;

  
  constant hconfig: ahb_config_type := (
    0 => ahb_device_reg(VENDOR_GAISLER, GAISLER_GR1553B, 0, gr1553b_version, gr1553b_cfgver),
    others => zero32);

  signal asserterr: std_logic_vector(9 downto 0);
  
begin

  comb: process(r,ins,ahbmi,rst)
    variable v: dma2_regs;
    variable o: gr1553b_dma2_out;
    variable msto: ahb_mst_out_type;
    variable rdata: std_logic_vector(31 downto 0);
    variable cur_data_addr: std_logic_vector(31 downto 1);
    variable cur_data_addr_high: std_logic_vector(25 downto 0);
    variable burst_state: boolean;
  begin
    v := r;
    v.desc_dmaerror := '0';
    v.buf_dmaerror := '0';
    
    o := (desc_dmaerror => r.desc_dmaerror, buf_dmaerror => r.buf_dmaerror,
          bm_progress => '0', ready => '0',
          bc_write_done => '0', bc_writeirq_done => '0', bc_desc0_valid => '0',
          bc_desc0_temp => r.buf0, bc_desc1 => r.buf1,
          rt_satw0_temp => r.buf0, rt_descw0_temp => r.buf3,
          rt_satw0_valid => '0', rt_descw0_valid => '0', rt_descptr_valid => '0', rt_break => '0',
          pulldata => r.buf3(31 downto 16),
          bufaddr_valid => not r.buf2(0), can_push => not r.got32, can_pull => r.got16);
    msto := (hbusreq => r.mo_hbusreq, hlock => '0', htrans => r.mo_htrans, haddr => r.mo_haddr,
             hwrite => r.mo_hwrite, hsize => r.mo_hsize, hburst => r.mo_hburst, hprot => "0011",
             hwdata => ahbdrivedata(r.buf0), hirq => (others => '0'), hconfig => hconfig, hindex => hindex);
    rdata := ahbreadword(ahbmi.hrdata, r.mo_haddr(4 downto 2));
    asserterr <= (others => '0');

    cur_data_addr := (others => '0');
    if notx(r.buf2) and notx(r.addr_offs) then

      cur_data_addr(5 downto 1) := std_logic_vector(unsigned(r.buf2(5 downto 1)) + unsigned(r.addr_offs));

      cur_data_addr_high := r.buf2(31 downto 6);
      if ((r.buf2(5)='1' or r.addr_offs(5)='1') and cur_data_addr(5)='0') or (r.buf2(5)='1' and r.addr_offs(5)='1') then
        cur_data_addr_high := std_logic_vector(unsigned(cur_data_addr_high)+1);
      end if;
      cur_data_addr(31 downto 6) := cur_data_addr_high;
    end if;
    
    if ahbmi.hready='1' then
      v.ahb_addr_owner := ahbmi.hgrant(hindex);      
      v.ahb_data_owner := r.ahb_addr_owner and (r.mo_htrans(1) or r.mo_htrans(0));
    end if;
    if r.ahb_data_owner='1' and ahbmi.hresp /= HRESP_OKAY then
      v.ahb_addr_owner := '0';
      v.ahb_data_owner := '0';
      v.mo_htrans := HTRANS_IDLE;
    end if;

    burst_state := false;
    
    case r.state is


      when IDLE =>

        o.ready := '1';
        
        v.mo_hbusreq := '0';
        v.mo_htrans := HTRANS_IDLE;
        
        v.mo_hburst := HBURST_SINGLE;
        v.mo_hsize := "010";
        
        if ins.bc.writestat='1' then
          v.mo_hbusreq := '1';
          v.mo_htrans := HTRANS_NONSEQ;          
          v.mo_hwrite := '1';
          v.mo_haddr := ins.bc.desc_addr & "1100";
          v.state := BCWSTAT;
        elsif ins.bc.writeirq='1' then
          v.mo_hbusreq := '1';
          v.mo_htrans := HTRANS_NONSEQ;
          v.mo_hwrite := '1';
          v.mo_haddr := ins.bc.irqbuf_pos & "00";
          v.state := BCWIRQ;
        elsif ins.bc.getcmd='1' then
          v.mo_hbusreq := '1';
          v.mo_htrans := HTRANS_NONSEQ;
          v.mo_hburst := HBURST_INCR;
          v.mo_hwrite := '0';
          v.mo_haddr := ins.bc.nextdesc_addr & "0000";
          v.state := BCRDESC0;
        elsif ins.rt.read_satbl='1' and ins.bc.active='0' then
          v.mo_hbusreq := '1';
          v.mo_htrans := HTRANS_NONSEQ;
          v.mo_hwrite := '0';
          v.mo_hburst := HBURST_INCR;
          v.mo_haddr := ins.rt.satbl_addr & "0000";
          v.state := RTRSAT0;
        elsif ins.rt.write_res='1' and ins.bc.active='0' then
          v.mo_hbusreq := '1';
          v.mo_htrans := HTRANS_NONSEQ;
          v.mo_hwrite := '1';
          v.mo_haddr := r.buf1(31 downto 4) & "0000";
          v.state := RTWSTAT;
        elsif ins.rt.write_log='1' and ins.bc.active='0' then
          v.mo_hbusreq := '1';
          v.mo_htrans := HTRANS_NONSEQ;
          v.mo_hwrite := '1';
          v.mo_haddr := ins.rt.logaddr & "00";
          v.state := RTWLOG;
        elsif (ins.rt.need_data='1' or ins.bc.need_data='1') and r.got16='0' and r.buf2(0)='0' then
          v.mo_hbusreq := '1';
          v.mo_htrans := HTRANS_NONSEQ;
          v.mo_haddr := cur_data_addr(31 downto 2) & "00";
          v.mo_hwrite := '0';
          v.state := TFRDATA;
        elsif (ins.rt.pushing_data='1' or ins.bc.pushing_data='1') and
          (r.got32='1' or (r.got16='1' and cur_data_addr(1)='1') or
           (r.got16='1' and (ins.rt.push_done='1' or ins.bc.push_done='1'))) then
          v.mo_hbusreq := '1';
          v.mo_htrans := HTRANS_NONSEQ;
          v.mo_haddr := cur_data_addr & "0";
          v.mo_hsize := "0" & r.got32 & (not r.got32);
          v.mo_hwrite := '1';
          if r.got32='0' and cur_data_addr(1)='0' then
            v.buf3 := r.buf3(15 downto 0) & r.buf3(15 downto 0); 
          end if;
          v.state := TFRDATA;          
        elsif ins.bm.write_data='1' then
          v.mo_hbusreq := '1';
          v.mo_htrans := HTRANS_NONSEQ;
          v.mo_hburst := HBURST_INCR;
          v.mo_haddr := ins.bm.ringbuf_addr & "000";
          v.mo_hwrite := '1';
          v.state := BMWLOG0;
        end if;

        -----------------------------------------------------------------------
        -- BC descriptor processing states
        -----------------------------------------------------------------------
                
      when BCWSTAT =>
        v.buf0 := ins.bc.laststatus;

        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_htrans := HTRANS_IDLE;
          end if;
          if r.ahb_data_owner='1' then            
            if ins.bc.writeirq='1' then
              v.mo_htrans := HTRANS_NONSEQ;
              v.mo_haddr := ins.bc.irqbuf_pos & "00";
              v.state := BCWIRQ;
            elsif ins.bc.getcmd='1' then
              v.mo_htrans := HTRANS_NONSEQ;
              v.mo_hburst := HBURST_INCR;
              v.mo_hwrite := '0';
              v.mo_haddr := ins.bc.nextdesc_addr & "0000";
              v.state := BCRDESC0;
              o.bc_write_done := '1';
            else
              v.mo_hbusreq := '0';
              v.state := IDLE;
            end if;
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.state := IDLE;
            v.mo_hbusreq := '0';
          end if;
        end if;


        
      when BCWIRQ =>
        v.buf0 := ins.bc.desc_addr & "0000";

        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_htrans := HTRANS_IDLE;
          end if;
          if r.ahb_data_owner='1' then
            o.bc_writeirq_done := '1';
            if ins.bc.getcmd='1' then
              v.mo_hburst := HBURST_INCR;
              v.mo_htrans := HTRANS_NONSEQ;
              v.mo_hwrite := '0';
              v.mo_haddr := ins.bc.nextdesc_addr & "0000";
              o.bc_write_done := '1';
              v.state := BCRDESC0;
            else
              v.mo_hbusreq := '0';
              v.state := IDLE;
            end if;
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.mo_hbusreq := '0';
            v.state := IDLE;
          end if;
        end if;

        
      -- Addr: desc word #0, data: none
      when BCRDESC0 =>
        burst_state := true;
        
        v.buf0 := rdata;

        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_haddr(2) := '1';
            v.mo_htrans := HTRANS_SEQ;
            v.state := BCRDESC1;
          end if;
        end if;

        
      -- Addr: desc word #1, data: desc word #0/none
      when BCRDESC1 =>
        burst_state := true;

        o.bc_desc0_valid := not r.ahb_data_owner;
        
        if ahbmi.hready='1' then
          if r.ahb_data_owner='1' then
            v.buf0 := rdata;
          end if;            
          if r.ahb_addr_owner='1' then
            v.mo_haddr(3 downto 2):="10";
            v.mo_htrans := HTRANS_SEQ;
            v.state := BCRDESC2;
            -- Note: Must use v.descbuf0, comb path from ahbmi.rddata
            if v.buf0(31)='1' then
              -- Keep hbusreq high to allow further BC processing
              -- v.mo_hbusreq := '0';
              v.mo_htrans := HTRANS_IDLE;
            end if;            
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.state := IDLE;
            v.mo_hbusreq := '0';
          elsif ahbmi.hresp/=HRESP_OKAY then
            v.mo_haddr(2):='0';
            v.mo_hbusreq := '1';
            v.state := BCRDESC0;
          end if;
        end if;
        
        

      -- Addr: desc word #2/none(branch), Data: desc word #1/none
      when BCRDESC2 =>
        burst_state := true;

        o.bc_desc0_valid := r.ahb_data_owner;
        
        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then           
            v.mo_hbusreq := '0';
            v.mo_htrans := HTRANS_IDLE;
            v.state := BCRDESC3;
          end if;
          if r.ahb_data_owner='1' then
            v.buf0 := rdata;
            if r.buf0(31)='1' then
              v.state := IDLE;
            else
              v.buf1 := rdata;              
            end if;
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.state := IDLE;
            v.mo_hbusreq := '0';
          elsif ahbmi.hresp/=HRESP_OKAY then
            v.mo_haddr(3 downto 2):="01";
            v.state := BCRDESC1;
            v.mo_hbusreq := '1';
          end if;
        end if;


      -- Addr: None, Data: desc word #2(tfr)
      when BCRDESC3 =>
        burst_state := true;

        if ahbmi.hready='1' then
          v.buf2 := rdata;
          v.state := IDLE;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.mo_hbusreq := '0';
            v.state := IDLE;
          elsif ahbmi.hresp/=HRESP_OKAY then
            v.state := BCRDESC2;
            v.mo_hbusreq := '1';
          end if;
        end if;

        -----------------------------------------------------------------------
        -- RT descriptor processing states
        -----------------------------------------------------------------------

      -- Addr SAT word #0, Data: None
      when RTRSAT0 =>
        burst_state := true;

        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_haddr(2) := '1';
            v.mo_htrans := HTRANS_SEQ;
            v.state := RTRSAT1;            
          end if;
        end if;


        
      -- Addr: SAT word #1, Data: SAT word#0/none
      when RTRSAT1 =>
        burst_state := true;

        o.rt_satw0_valid := not r.ahb_data_owner;
        
        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            if ins.rt.tx_transfer='1' then
              v.mo_htrans := HTRANS_IDLE;
              v.state := RTRSAT3;
            else
              v.mo_haddr(3 downto 2) := "10";
              v.mo_htrans := HTRANS_SEQ;
              v.state := RTRSAT2;              
            end if;
          end if;
          if r.ahb_data_owner='1' then
            v.buf0 := rdata;
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.mo_hbusreq := '0';
            v.state := IDLE;
          elsif ahbmi.hresp/=HRESP_OKAY then
            v.state := RTRSAT0;
            v.mo_haddr(2) := '0';
          end if;
        end if;


        
      -- Addr: SAT word #2, Data: SAT word#1/none
      when RTRSAT2 =>
        burst_state := true;

        o.rt_satw0_valid := '1';
        
        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_htrans := HTRANS_IDLE;
            v.state := RTRSAT3;
          end if;
          if r.ahb_data_owner='1' then
            -- We're only in this state if we're receiving, hence we're not
            -- interested in table word #1
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.mo_hbusreq := '0';
            v.state := IDLE;
          elsif ahbmi.hresp /= HRESP_OKAY then
            v.state := RTRSAT1;
            v.mo_haddr(3 downto 2):="01";
          end if;
        end if;


        
      -- Addr: None, Data: SAT word#1/2
      when RTRSAT3 =>

        o.rt_satw0_valid := '1';
        
        if ahbmi.hready='1' then
          if r.ahb_data_owner='1' then
            v.buf1 := rdata;
          end if;
        end if;

        if r.ahb_data_owner='0' then
          if r.buf1(1 downto 0) /= "11" and ins.rt.tfr_legal='1' then
            v.mo_haddr := r.buf1(31 downto 4) & "0000";
            v.mo_htrans := HTRANS_NONSEQ;
            v.state := RTRDESC0;
            o.rt_descptr_valid := '1';
          else
            v.state := IDLE;
            o.rt_break := '1';
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.mo_hbusreq := '0';
            v.state := IDLE;
          elsif ahbmi.hresp/=HRESP_OKAY then
            -- We can step back to RTRSAT2 even if we came directly from
            -- RTRSAT1 since we're not manipulating haddr
            v.state := RTRSAT2;
            v.mo_hbusreq := '1';
          end if;
        end if;
              
        
      -- Addr: RTDesc #0, Data: None
      when RTRDESC0 =>
        burst_state := true;

        o.rt_satw0_valid := '1';
        o.rt_descptr_valid := '1';
        
        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_haddr(2):='1';
            v.state := RTRDESC1;
            v.mo_htrans := HTRANS_SEQ;
          end if;
        end if;

      -- Addr: RTDesc #1, Data: RTDesc #0
      when RTRDESC1 =>
        burst_state := true;

        o.rt_satw0_valid := '1';
        o.rt_descptr_valid := '1';
        o.rt_descw0_valid := not r.ahb_data_owner;
        
        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_htrans := HTRANS_IDLE;
            v.mo_hbusreq := '0';
            v.state := RTRDESC2;
          end if;
          if r.ahb_data_owner='1' then
            v.buf3 := rdata;
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.mo_hbusreq := '0';
            v.state := IDLE;
          elsif ahbmi.hresp /= HRESP_OKAY then
            v.mo_haddr(2):='0';
            v.state := RTRDESC0;
          end if;
        end if;
        

      when RTRDESC2 =>
        burst_state := true;

        o.rt_satw0_valid := '1';
        o.rt_descptr_valid := '1';
        o.rt_descw0_valid := '1';
        
        if ahbmi.hready='1' then
          v.buf2 := rdata;
          v.state := IDLE;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.state := IDLE;
          elsif ahbmi.hresp /= HRESP_OKAY then
            v.mo_hbusreq := '1';
            v.state := RTRDESC1;
          end if;
        end if;
        
      when RTWSTAT =>
        
        v.buf0 := ins.rt.statusword;

        if ahbmi.hready='1' then          
          if r.ahb_addr_owner='1' then
            v.mo_htrans := HTRANS_IDLE;
          end if;
          if r.ahb_data_owner='1' then
            v.state := RTRNEXT;
            v.mo_haddr(3) := '1';
            v.mo_htrans := HTRANS_NONSEQ;
            v.mo_hwrite := '0';
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.state := IDLE;
            v.mo_hbusreq := '0';
          end if;
        end if;

      when RTRNEXT =>

        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_htrans := HTRANS_IDLE;
          end if;
          if r.ahb_data_owner='1' then
            v.buf0 := rdata;
            v.mo_htrans := HTRANS_NONSEQ;
            if ins.rt.tx_transfer='1' then
              v.mo_haddr := ins.rt.satbl_addr & "0100";
            else
              v.mo_haddr := ins.rt.satbl_addr & "1000";
            end if;
            v.mo_hwrite := '1';
            v.state := RTWNEXT;
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror:= '1';
            v.state:=IDLE;
            v.mo_hbusreq := '0';
          end if;
        end if;

      when RTWNEXT | RTWWRAP =>

        if r.state=RTWWRAP then v.buf0 := r.buf1; end if;
        
        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_htrans := HTRANS_IDLE;
          end if;
          if r.ahb_data_owner='1' then
            if ins.rt.autowrap='1' and r.state=RTWNEXT then
              v.mo_htrans := HTRANS_NONSEQ;
              v.mo_haddr(3 downto 2):="01";              
              v.state := RTWWRAP;
            else
              v.state := IDLE;
              v.mo_hbusreq := '0';
            end if;
          end if;
        end if;
        
        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror:= '1';
            v.state:=IDLE;
            v.mo_hbusreq := '0';
          end if;
        end if;
        
      when RTWLOG =>

        v.buf0 := ins.rt.logentry;

        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_htrans := HTRANS_IDLE;
            v.mo_hbusreq := '0';
          end if;
          if r.ahb_data_owner='1' then
            v.state := IDLE;
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror:= '1';
            v.state:=IDLE;
            v.mo_hbusreq := '0';
          end if;
        end if;        

        -----------------------------------------------------------------------
        -- BC/RT Data transfer
        -----------------------------------------------------------------------

      when TFRDATA =>

        case endian is
          when 0 => v.buf0 := r.buf3;
          when 1 => v.buf0 := r.buf3(15 downto 0) & r.buf3(31 downto 16);
        end case;

        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.mo_htrans := HTRANS_IDLE;
            v.mo_hbusreq := '0';
          end if;
          if r.ahb_data_owner='1' then
            v.state := IDLE;
            case endian is
              when 0 => v.buf3 := rdata;
              when 1 => v.buf3 := rdata(15 downto 0) & rdata(31 downto 16);
            end case;
            if cur_data_addr(1)='1' then
              v.buf3(31 downto 16) := v.buf3(15 downto 0);
            end if;
            if r.mo_hwrite='0' then              
              v.got32 := not cur_data_addr(1);
              v.got16 := '1';
            else
              v.got32 := '0';
              v.got16 := '0';
            end if;
            v.addr_offs(1) := r.buf2(1);
            if r.addr_offs(1)=r.buf2(1) then
              v.addr_offs(5 downto 2) := std_logic_vector(unsigned(r.addr_offs(5 downto 2))+1);
            end if;
          end if;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.buf_dmaerror := '1';
            v.state := IDLE;
            v.mo_hbusreq := '0';
            v.got32 := '0';
            v.got16 := '0';
          end if;
        end if;
                  
        -----------------------------------------------------------------------
        -- BM log write
        -----------------------------------------------------------------------

      when BMWLOG0 =>
        burst_state := true;

        v.buf0 := ins.bm.logdata(63 downto 32);

        o.bm_progress := '1';
        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.state := BMWLOG1;
            v.mo_haddr(2) := '1';
            v.mo_htrans := HTRANS_SEQ;
          end if;
        end if;

      when BMWLOG1 =>
        burst_state := true;
        
        o.bm_progress := '1';
        if ahbmi.hready='1' then
          if r.ahb_addr_owner='1' then
            v.state := BMWLOG2;
            v.mo_htrans := HTRANS_IDLE;
            v.mo_hbusreq := '0';
            v.buf0 := ins.bm.logdata(31 downto 0);
          end if;          
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.state := IDLE;
            v.mo_hbusreq := '0';
          elsif ahbmi.hresp /= HRESP_OKAY then
            v.mo_haddr(2) := '0';
            v.state := BMWLOG0;
          end if;
        end if;

      when BMWLOG2 =>
        burst_state := true;

        o.bm_progress := '1';        
        if ahbmi.hready='1' then
          v.state := IDLE;
        end if;

        if ahbmi.hready='0' and r.ahb_data_owner='1' then
          if ahbmi.hresp=HRESP_ERROR then
            v.desc_dmaerror := '1';
            v.state := IDLE;
            v.mo_hbusreq := '0';
          elsif ahbmi.hresp /= HRESP_OKAY then
            v.mo_hbusreq := '1';
            v.state := BMWLOG1;
          end if;
        end if;
        
    end case;

    if ahbmi.hready='1' and r.state /= IDLE and r.state /= RTRSAT3 and
      r.ahb_addr_owner='0' and (burst_state or r.ahb_data_owner='0') then
      v.mo_htrans := HTRANS_NONSEQ;
      v.mo_hbusreq := '1';
    end if;
    
    if (ins.bc.push_data='1' or ins.rt.push_data='1') and r.buf2(0)='0' then
      v.got32 := r.got16;
      v.got16 := '1';
      v.buf3 := r.buf3(15 downto 0) & ins.pushdata;
    elsif ins.bc.pull_data='1' or ins.rt.pull_data='1' then
      v.buf3 := r.buf3(15 downto 0) & r.buf3(15 downto 0);
      v.got16 := r.got32;
      v.got32 := '0';
    end if;

    -- Invalid data addr
    if r.buf2(0)='1' and ins.rt.need_data='1' then
        v.buf3(31 downto 16) := x"0000";
        v.got16 := '1';
    end if;
    
    if ins.bc.data_reset='1' or ins.rt.data_reset='1' then
      v.addr_offs := (others => '0');
      v.got16 := '0';
      v.got32 := '0';
    end if;        

    -- Optionally bypass register for hbusreq
    if ahbreqreg /= 0 then
      msto.hbusreq := v.mo_hbusreq;
    end if;
      
    if rst='0' and syncrst/=0 then
      v.state := r_rst.state;
      v.mo_htrans := r_rst.mo_htrans;
      v.mo_hbusreq := r_rst.mo_hbusreq;
      -- Not strictly necessary but good for simulation to make all outputs
      -- defined after reset
      v.buf0 := r_rst.buf0;  -- hwdata
      v.mo_haddr := r_rst.mo_haddr;
      v.mo_hsize := r_rst.mo_hsize;
      v.mo_hburst := r_rst.mo_hburst;
      v.mo_hwrite := r_rst.mo_hwrite;
      if syncrst>1 then
        v.buf1(31 downto 30) := "00";
        v.buf1(25 downto 0) := (others => '0');
      end if;
      -- Clear htrans/hbusreq immediately
      msto.htrans := r_rst.mo_htrans;
      msto.hbusreq := r_rst.mo_hbusreq;
    end if;

    nr <= v;
    outs <= o;
    ahbmo <= msto;
  end process;
      
  regs: process(clk,rst)
  begin
    if rising_edge(clk) then
      r <= nr;
      -- pragma translate_off
      for x in asserterr'range loop assert asserterr(x)='0' report "Error #" & tost(x) severity failure; end loop;
      -- pragma translate_on
    end if;
    if rst='0' and syncrst=0 then
      r <= r_rst;
    end if;
  end process;
  
end;
  
