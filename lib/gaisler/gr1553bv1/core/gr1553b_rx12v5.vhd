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
-- Entity:      gr1553b_rx12v4
-- File:        gr1553b_rx12v4.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B stage 1/2, detector - 5th version, FSM-based
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
library gaisler;
use gaisler.gr1553b_pkg.all;
use gaisler.gr1553b_core.all;

entity gr1553b_rx12v5 is
  generic (
    synclength: integer := 2;
    syncrst: integer range 0 to 2
    );
  port (
    clk: in std_logic;
    rst: in std_logic;

    rxin_p: in std_logic;
    rxin_n: in std_logic;

    outs: out gr1553b_rx2_out;
    fb:   in  gr1553b_rx2_fb;
    reinit: in std_logic
    );
end;

architecture rtl of gr1553b_rx12v5 is

  constant clk_freq_mhz: integer := 20;
  constant half_bittime: integer := clk_freq_mhz / 2;
  constant sync_width_min1: integer := 20;
  constant sync_width_mid2: integer := 35;
  constant sync_width_max2: integer := 48;

  type rx1_state is (IDLE,SYNC1,GAP,SYNC2,RBIT,GBLOCK);
  
  type rx1_regs is record
    sync_p,sync_n:     std_logic_vector(synclength-1 downto 0);
    last_type:         std_logic;
    last_val:          std_logic;    
    
    s:                 rx1_state;
    ctr:               std_logic_vector(6 downto 0);
    ctrp20:            std_logic;
    ctrp35:            std_logic;
    bitphase:          std_logic_vector(4 downto 0);
    tail:              std_logic;
    
    seenbitp:          std_logic;
    seenbitpfull:      std_logic;
    seenbitnfull:      std_logic;
    seenbitn:          std_logic;
    
    dataval:           std_logic;
    act:               std_logic;
    resync:            std_logic;
  end record;

  signal r,nr: rx1_regs;
  
  constant r_rst: rx1_regs := (    
    sync_p => (others => '0'), sync_n => (others => '0'),
    last_type => '0', last_val => '0',
    s => IDLE, ctr => (others => '0'), ctrp20 => '0', ctrp35 => '0',
    bitphase => "00000", tail => '0',
    seenbitp => '0', seenbitpfull => '0', seenbitnfull => '0', seenbitn => '0',
    dataval => '0', act => '0', resync => '0');

  
begin

  comb: process(rst,rxin_p,rxin_n,r,fb)
    variable v: rx1_regs;
    variable o: gr1553b_rx2_out;
    variable new_bit_p,new_bit_n: std_logic;
    variable new_type,new_val: std_logic;

    variable clear_ctr: std_logic;
    
  begin
    v := r;
    o := (got_sync => '0', got_data => '0', dataval => r.dataval,
          idle => '1', act => r.act);
    
    ---------------------------------------------------------------------------
    -- 2-stage sync inputs
    
    v.sync_p := r.sync_p((synclength-2) downto 0) & rxin_p;
    v.sync_n := r.sync_n((synclength-2) downto 0) & rxin_n;
    new_bit_p := r.sync_p((synclength-1));
    new_bit_n := r.sync_n((synclength-1));

    new_type := new_bit_p xor new_bit_n;
    new_val := new_bit_p and not new_bit_n;
    v.last_type := new_type;
    v.last_val := new_val;

    ---------------------------------------------------------------------------
    -- FSM
    
    clear_ctr := '0';

    v.ctr := std_logic_vector(unsigned(r.ctr)+1);
    if r.ctr(4)='1' and r.ctr(1 downto 0)="11" then
      v.ctrp20:='1';
    end if;
    if r.ctr(5)='1' and r.ctr(1)='1' then
      v.ctrp35:='1';
    end if;
    
    case r.s is
      
      when IDLE =>
        if r.act='0' then clear_ctr := '1'; end if;
        if r.ctrp20='1' then v.act:='0'; v.resync:='0'; end if;
        v.dataval := new_bit_p;
        v.bitphase := "00000";
        v.seenbitp := '0';
        v.seenbitpfull := '0';
        v.seenbitn := '1';
        v.seenbitnfull := '0';
        if new_type /= '0' then
          v.s := SYNC1;
          v.act := '1';
          clear_ctr := '1';
        else
          v.tail := '0';
        end if;

        
      when SYNC1 =>
        if (r.last_type='0' and new_type='0') or (new_type='1' and new_val/=r.dataval) then
          clear_ctr := '1';
          if (r.ctr(6 downto 2)="00000" or r.tail='1' or r.resync='1') and r.ctrp20='0' then
            v.s := IDLE;
            v.tail := '0';
          elsif r.ctrp20='0' then 
            v.s := GBLOCK;
            v.resync := '1';
          elsif new_type='0' then
            v.s := GAP;
          else
            v.s := SYNC2;
          end if;
        end if;

        
      when GAP =>
        if new_type='1' and new_val /= r.dataval then
          clear_ctr := '1';
          v.s := SYNC2;
        end if;
        if new_type='1' and new_val=r.dataval and r.last_type='1' then
          v.s := IDLE;
          v.tail := '0';
        end if;
        if r.ctrp20='1' then
          v.s := IDLE;
          v.tail := '0';
        end if;

        
      when SYNC2 =>
        if r.ctrp20='1' and r.ctr(0)='1' then
          v.bitphase := std_logic_vector(unsigned(r.bitphase)+1);
        end if;
        if r.ctrp35='0' and (r.ctr(5)='1' and r.ctr(1)='1') then
          v.bitphase := "01100";
        end if;
        
        if (new_type='1' and new_val=r.dataval) then
          if r.ctrp20='0' or (r.ctr(5)='0' and r.ctr(3)='0') then
            v.s := IDLE;
            v.tail := '0';
          else
            v.s := RBIT;
            o.got_sync := '1';
            o.idle := '0';
            clear_ctr := '1';
            v.dataval := not r.dataval;
            if r.ctrp35='1' then
              v.seenbitpfull := '1';
              v.tail := '0';
            end if;
            v.seenbitp := '1';
            v.seenbitn := '1';
          end if;
        end if;
        if r.ctr(5 downto 4)="11" then
          v.s := IDLE;
          v.tail := '0';
        end if;

        
      when RBIT =>
        o.idle := '0';
        if r.tail='0' and (new_type='0' or new_val=r.dataval) then clear_ctr:='1'; end if;
        v.bitphase := std_logic_vector(unsigned(r.bitphase)+1);
        if (r.seenbitn='0' or (r.seenbitpfull='0' and new_val=r.dataval)) and new_type='1' then
          v.seenbitp := r.seenbitn;
          v.seenbitpfull := r.seenbitnfull;
          v.seenbitn := '1';
          v.dataval := not new_val;
        end if;
        if r.seenbitnfull='0' and r.last_type='1' and new_type='1' and new_bit_p/=r.dataval then
          v.seenbitnfull := '1';
        end if;
        if r.bitphase(3 downto 0)="1001" then
          -- Remove shifted in data before rel ideal zero crossing
          v.seenbitp := '0';
          v.seenbitpfull := '0';
          -- Avoid case where we flip dataval the same cycle
          v.dataval := r.dataval;
        end if;
        if r.bitphase(4 downto 0)="10011" then
          -- Prevent further shifting some samples after zero crossing
          if r.seenbitp='1' then
            v.seenbitpfull := '1';
          else
            v.seenbitnfull := '1';            
          end if;
        end if;
        if r.tail='0' and r.ctr(4)='1' then
          v.s := IDLE;
          clear_ctr := '1';
          v.resync := '1';
        end if;        
        if r.bitphase(4)='1' and r.bitphase(2 downto 0)="111" then
          v.bitphase := "00100";
          v.tail := '0';
          if r.seenbitp='1' and r.seenbitn='1' then
            o.got_data := '1';
            clear_ctr := '1';
            if fb.syncblock='1' then
              v.s := IDLE;
              v.resync := '0';
            end if;
          elsif r.tail='1' then
            v.s := SYNC2;
            v.bitphase := "00000";
          else            
            v.s := IDLE;
            clear_ctr := '1';
            v.resync := '1';
          end if;
          if fb.gapblock='1' then
            v.s := GBLOCK;
            clear_ctr := '1';
            v.resync := '0';
          end if;
          v.seenbitp := '0';
          v.seenbitn := new_type;
          v.seenbitpfull := '0';
          v.seenbitnfull := '0';
          v.dataval := not new_val;
        end if;

        
      when GBLOCK =>
        v.tail := new_type;
        if r.ctr(5)='1' and r.ctr(2 downto 1)="11" then
          v.s := IDLE;
          clear_ctr := '1';
        end if;
        
    end case;

    if reinit='1' then
      v.s := IDLE;
      clear_ctr := '1';
      v.resync := '1';
      v.tail := '1';
    end if;
    
    if clear_ctr='1' then
      v.ctr:=(others => '0');
      v.ctrp20:='0';
      v.ctrp35:='0';
    end if;
    
    if syncrst/=0 and rst='0' then
      v.s := IDLE;
      v.bitphase := "00000";
      v.seenbitp := '0';
      v.seenbitpfull := '0';
      v.seenbitn := '1';
      v.seenbitnfull := '0';
      v.tail := '0';
      v.act := '0';
      v.resync := '0';
    end if;
    
    nr <= v;
    outs <= o;
  end process;

  regs: process(clk,rst)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
    if syncrst=0 and rst='0' then
      r <= r_rst;
    end if;
  end process;
  
end;
