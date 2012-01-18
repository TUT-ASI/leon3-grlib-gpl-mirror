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
-- Entity:      gr1553b_rx3
-- File:        gr1553b_rx3.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B receiver stage 3, deserialization and parity checking
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.gr1553b_core.all;

entity gr1553b_rx3 is

  generic (
    syncrst: integer range 0 to 2
    );
  port (
    clk: in std_logic;
    rst: in std_logic;

    -- From user
    abort: in std_logic;
    -- From bit recovery
    bito: in gr1553b_rx2_out;
    -- Outputs
    s3o: out gr1553b_rx3_out;
    s2fb: out gr1553b_rx2_fb
    );
end;

architecture rtl of gr1553b_rx3 is
  
  type rx_state_t is (IDLE, RDATA, RPARITY);

  type rx3_regs is record
    state: rx_state_t;
    dtype: gr1553b_word_type;
    dreg: std_logic_vector(15 downto 0);
    dcount: integer range 0 to 15;
    accumxor: std_logic;    
  end record;

  constant r_rst: rx3_regs := (IDLE,CMD_STAT,(others => '0'),0,'0');
  
  signal r,nr: rx3_regs;
  
begin

  comb: process(rst,r,bito,abort)
    variable v: rx3_regs;
    variable vo: gr1553b_rx3_out;
    variable fb: gr1553b_rx2_fb;
    variable vword: gr1553b_word;
    variable vdatavalid: std_logic;
    variable vlostsync: std_logic;
    variable vbadparity: std_logic;
    variable vstarted: std_logic;  
  begin
    -- Init vars
    v := r;
    vword := (t=>r.dtype, data=>r.dreg);
    vdatavalid := '0';
    vlostsync := '0';
    vbadparity := '0';
    vstarted := '1';
    fb := (syncblock => '0', gapblock => '0');
    
    case r.state is
      
      when IDLE =>
        vstarted := '0';
        if bito.got_sync='1' then
          if bito.dataval='1' then
            v.dtype := CMD_STAT;
          else
            v.dtype := DATA;
          end if;
          v.state := RDATA;
          v.dcount := 0;
          v.accumxor := '0';
        end if;
          
      when RDATA =>
        if bito.idle='1' then
          vlostsync := '1';
          v.state := IDLE;          
        elsif bito.got_data='1' then
          v.dreg := r.dreg(14 downto 0) & bito.dataval;
          v.accumxor := r.accumxor xor bito.dataval;
          if r.dcount=15 then
            v.state := RPARITY;
          else
            v.dcount := r.dcount+1;
          end if;
        end if;
        if r.dcount=0 then vstarted:='0'; vlostsync:='0'; end if;
        
      when RPARITY =>
        fb.syncblock := '1';
        if bito.idle='1' then
          vlostsync := '1';
          v.state := IDLE;
        elsif bito.got_data='1' then
          v.state := IDLE;
          if (bito.dataval xor r.accumxor) = '1' then
            vdatavalid := '1';
          else
            vbadparity := '1';
          end if;
        end if;
        
    end case;

    if abort='1' then
      v.state := IDLE;
    end if;
      
    if rst='0' and syncrst/=0 then
      v.state := r_rst.state;
      v.dcount := 0;
      v.accumxor := '0';
      v.dreg(15) := '0';
    end if;

    -- Assign outputs
    vo := (vword,vdatavalid,vlostsync,vbadparity,vstarted);
    nr <= v;
    s3o <= vo;
    s2fb <= fb;
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
