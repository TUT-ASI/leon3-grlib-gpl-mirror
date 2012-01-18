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
-- Entity:      gr1553b_loopback
-- File:        gr1553b_loopback.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B loopback checker.
------------------------------------------------------------------------------
-- This is a version of the deserializer (rx3), modified to perform
-- loopback checking. Received bits are compared one by one to the
-- sent 1553 word.
--
-- The idea is to run this in parallel with the deserializer on the
-- currently transmitting bus.  The two will generate a data valid signal
-- the exact same cycle, so echoed words can be filtered out by
-- xor:ing (or and-not:ing) the datavalid signals. 
--
-- In order to support continuous transmission without keeping track
-- of more than one word, the loopback checker needs to extend the
-- period where input data is valid. The user must keep the input data
-- valid until lbread_data is high which happens after txo.read_data
-- has gone high.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.gr1553b_core.all;

entity gr1553b_loopback is
  generic (syncrst: integer range 0 to 2);
  
  port (
    clk: in std_logic;
    rst: in std_logic;

    -- From bit recovery
    rxo: in gr1553b_rx2_out;

    -- Transmitter interface
    txi: in gr1553b_tx1_in;
    txo: in gr1553b_tx1_out;
    
    -- Outputs
    lberror: out std_logic;
    lbdone: out std_logic;
    lbread_data: out std_logic;
    lbdata_valid: out std_logic;
    gapblock: out std_logic
    );
end;

architecture rtl of gr1553b_loopback is
  
  type lb_state_t is (IDLE, WAITSYNC, WAITDATA, WAITPARITY, BADDATA);

  type rx_loopback_regs is record
    state: lb_state_t;
    dtype: gr1553b_word_type;
    dreg: std_logic_vector(15 downto 0);
    dcount: integer range 0 to 15;
    accumxor: std_logic;
    got_txstart: std_logic;
    got_readdata: std_logic;
    lberror: std_logic;
  end record;

  constant r_rst: rx_loopback_regs := (IDLE,CMD_STAT,x"0000",0,'0','0','0','0');
  
  signal r,nr: rx_loopback_regs;
  
begin

  comb: process(rst,r,rxo,txi,txo)
    variable v: rx_loopback_regs;
    variable vdatavalid: std_logic;
    variable vstarted: std_logic;
    variable vlbread_data: std_logic;
    variable vgapblock: std_logic;
  begin
    -- Init vars
    v := r;
    vdatavalid := '0';
    vstarted := '1';
    vlbread_data := '0';
    vgapblock := '0';

    if r.got_readdata='1' and r.got_txstart='0' then
      vlbread_data := '1';
      v.got_readdata := '0';
    end if;
    if txi.start='1' and txo.ready='1' then
      v.got_txstart := '1';
    end if;
    if txo.read_data='1' then
      v.got_readdata := '1';
    end if;
    if r.lberror='1' then
      v.lberror := '0';
    end if;
    
    case r.state is

      when IDLE =>
        vstarted := '0';

        if r.got_txstart='1' and r.lberror='0' then
          v.state := WAITSYNC;
          v.dtype := txi.word.t;
          v.dreg := txi.word.data;
          v.got_txstart := '0';
        end if;

      when WAITSYNC =>
        if txo.ready='1' then
          v.state := IDLE;
          v.lberror := '1';
        elsif rxo.got_sync='1' then
          if rxo.dataval='1' xnor r.dtype=CMD_STAT then
            v.state := WAITDATA;
            v.dcount := 0;
            v.accumxor := '0';            
          else
            v.state := BADDATA;
            v.dcount := 0;
          end if;
        end if;

      when WAITDATA =>
        if rxo.idle='1' then 
          if r.dcount=0 then
            v.state := WAITSYNC;
          else
            v.state := IDLE;
            v.lberror := '1';
          end if;
        elsif rxo.got_data='1' then 
          v.dreg := r.dreg(14 downto 0) & rxo.dataval;
          v.accumxor := r.accumxor xor rxo.dataval;
          if r.dcount=15 then
            v.state := WAITPARITY;
            v.dcount := 0;
          else
            v.dcount := r.dcount+1;            
          end if;
          if rxo.dataval /= r.dreg(15) then
            v.state := IDLE;
            v.lberror := '1';
          end if;
        end if;

      when WAITPARITY =>
        if txi.start='0' and r.got_txstart='0' then
          vgapblock := '1';
        end if;        
        if rxo.idle='1' then
          v.lberror := '1';
          v.state := IDLE;
        elsif rxo.got_data='1' then
          v.state := IDLE;
          if (rxo.dataval xor r.accumxor) = '1' then
            vdatavalid := '1';
          else
            v.lberror := '1';
          end if;
        end if;

      when BADDATA =>
        if rxo.idle='1' then
          v.state := WAITSYNC;
        elsif rxo.got_data='1' then
          v.state := IDLE;
          v.lberror := '1';
        end if;

    end case;

    if txi.abort='1' then
      v.state := IDLE;
      v.got_txstart := '0';
      v.got_readdata := '0';
    end if;
    
    if rst='0' and syncrst/=0 then
      v.state := IDLE;
      v.got_txstart := '0';
      v.got_readdata := '0';
      v.lberror := '0';
      v.dcount := 0;
      v.accumxor := '0';
      v.dreg(15) := '0';
    end if;

    -- Assign outputs
    nr <= v;

    lbdone <= not vstarted;
    lberror <= r.lberror;
    lbdata_valid <= vdatavalid;
    lbread_data <= vlbread_data;
    gapblock <= vgapblock;
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
