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
-- Entity:      gr1553b_tx1
-- File:        gr1553b_tx1.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B transmitter stage 1, serialization and parity gen.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.gr1553b_core.all;

entity gr1553b_tx1 is
  generic (
    syncrst: integer range 0 to 2
    );
  
  port(
    clk: in std_logic;
    rst: in std_logic;

    -- The type and data are read when start='1' and ready='1'
    seri: in gr1553b_tx1_in;
    sero: out gr1553b_tx1_out;
    biti: out gr1553b_tx2_in;
    bito: in gr1553b_tx2_out
  );
end;

architecture rtl of gr1553b_tx1 is
  
  type tx_msgstate_t is (IDLE, MSYNC, MDATA, MPARITY);

  type tx_regs_t is record
    msgstate: tx_msgstate_t;
    pos: integer range 0 to 15;
    accumxor: std_logic;
    data: gr1553b_word;
    rbiti: gr1553b_tx2_in;
  end record;

  constant r_rst: tx_regs_t := (msgstate => IDLE, pos => 0, accumxor => '0', data => gr1553b_word_default,
                                rbiti => ('0','0','0'));
  
  signal r,nr: tx_regs_t;
  
begin

  comb: process(rst,seri,bito,r)
  variable v: tx_regs_t;
  variable vsero: gr1553b_tx1_out;

  variable lastcycle: std_logic;
  begin
    -- Init vars    
    v := r;
    vsero := (ready => '0', read_data => '0');
    v.rbiti := ('0','0','0');
    lastcycle := '0';

    if r.msgstate /= IDLE and bito.xread='1' then
      
      if r.pos = 0 then
        v.pos := 15;
      else
        v.pos := r.pos-1;
      end if;
      
      if r.msgstate=MSYNC then
        v.msgstate := MDATA;
        vsero.read_data := '1';
        v.pos := 15;
      elsif r.pos=0 and r.msgstate=MDATA then
        v.msgstate := MPARITY;
      elsif r.msgstate=MPARITY then
        v.msgstate := IDLE;
        lastcycle := '1';
      end if;
      
      if r.msgstate=MDATA then
        v.data.data := r.data.data(14 downto 0) & '0';
        v.accumxor := r.accumxor xor r.data.data(15);
      end if;
        
    end if;

    -- Ready and start logic
    if r.msgstate=IDLE or lastcycle='1' then
      vsero.ready := '1';
    end if;    
    if seri.start='1' and vsero.ready='1' then
      v.data.t := seri.word.t;
      v.data.data := seri.word.data;
      v.msgstate := MSYNC;
      v.accumxor := '0';
    end if;
        
    -- Reset
    if (rst='0' and syncrst/=0) or seri.abort='1' then
      v.msgstate := IDLE;
      vsero.ready := '0';
    end if;
    
    -- Comb outputs from state moved into regs
    if v.msgstate /= IDLE then
      v.rbiti.dv := '1';
    end if;

    if v.msgstate=MSYNC then
      v.rbiti.sync := '1';
      if v.data.t=CMD_STAT then
        v.rbiti.data := '1';
      else
        v.rbiti.data := '0';
      end if;
    end if;

    if v.msgstate=MDATA then
      if bito.xread='1' then
        v.rbiti.data := r.data.data(14);
      else
        v.rbiti.data := r.data.data(15);
      end if;
    end if;

    if v.msgstate=MPARITY then
      v.rbiti.data := not v.accumxor;  -- Odd parity
    end if;

    if (rst='0' and syncrst/=0) then
      v.data.data(14) := '0';
    end if;
    
    -- Assign signals
    nr <= v;
    sero <= vsero;
    biti <= r.rbiti;
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
