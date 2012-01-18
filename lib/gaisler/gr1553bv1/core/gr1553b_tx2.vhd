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
-- Entity:      gr1553b_tx2
-- File:        gr1553b_tx2.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B transmitter stage 2, Manchester II encoding
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.gr1553b_core.all;
library grlib;
use grlib.stdlib.all;

entity gr1553b_tx2 is
  
  generic (
    -- Frequency of clk in MHz
    -- Clock must be even multiple of 2 MHz with accuracy of +/- 100 ppm.
    clk_freq_mhz: integer;
    txreg: boolean;
    syncrst: integer range 0 to 2
  );
  
  port(
    clk: in std_logic;
    rst: in std_logic;

    biti: in gr1553b_tx2_in;
    bito: out gr1553b_tx2_out;
    txout_pos: out std_logic;
    txout_neg: out std_logic
  );
  attribute sync_set_reset of rst : signal is "true";
end;

architecture rtl of gr1553b_tx2 is
  
  constant halfbit_len: integer := clk_freq_mhz/2;
  
  type tx_state_t is record
    secondhalf: boolean;
    timecount: integer range 0 to halfbit_len-1;
    synccount: integer range 0 to 2;
    txout_pos,txout_neg: std_logic;
    txstarting: std_logic;
  end record;

  constant r_rst: tx_state_t := (false, 0, 0, '0', '0', '0');

  -- Registers
  signal state: tx_state_t;  

  -- Combinatorial
  signal nstate: tx_state_t;
  
begin

  comb: process(rst,state,biti)
  variable vnstate: tx_state_t;
  variable vxread: std_logic;
  variable vlasthus: std_logic;
  variable c1,c2,c3: boolean;
  begin
    -- Init vars    
    vnstate := state;
    vnstate.txout_pos := '0';
    vnstate.txout_neg := '0';
    vxread := '0';
    vlasthus := '0';
    
    if biti.dv='1' then
      if biti.data='1' xor state.secondhalf then
        vnstate.txout_pos := '1';
      else
        vnstate.txout_neg := '1';
      end if;

      c1 := false;
      if state.timecount = halfbit_len-1 then
        vnstate.timecount := 0;
        c1 := true;
      else
        vnstate.timecount := state.timecount+1;
      end if;

      c2 := false;
      if c1 then
        if state.synccount = 2 or biti.sync='0' then
          vnstate.synccount := 0;
          c2 := true;
        else
          vnstate.synccount := state.synccount + 1;          
        end if;
      end if;

      c3 := false;
      if c2 then              
        if state.secondhalf then
          vnstate.secondhalf := false;
          c3 := true;
        else
          vnstate.secondhalf := true;
        end if;
      end if;

      if c3 then
        vxread := '1';        
      end if;
    end if;

    if state.secondhalf and (biti.sync='0' or state.synccount = 2) then
      vlasthus := '1';
    end if;

    vnstate.txstarting := biti.dv and not state.txout_pos and not state.txout_neg;
    
    -- Reset
    if (rst='0' and syncrst/=0) or biti.dv='0' then
      vnstate.secondhalf := false;
      vnstate.timecount := 0;
      vnstate.synccount := 0;
      vnstate.txout_pos := '0';
      vnstate.txout_neg := '0';
      vnstate.txstarting := '0';
    end if;
    
    -- Assign signals
    nstate <= vnstate;
    if txreg then
      txout_pos <= state.txout_pos;
      txout_neg <= state.txout_neg;
    else
      txout_pos <= vnstate.txout_pos;
      txout_neg <= vnstate.txout_neg;
    end if;
    bito.xread <= vxread;
    bito.lasthus <= vlasthus;
    bito.done <= not biti.dv;
    bito.txstarting <= state.txstarting;
  end process;
                
  regs: process(clk,rst)
  begin
    if rising_edge(clk) then
      state <= nstate;
    end if;
    if rst='0' and syncrst=0 then
      state <= r_rst;
    end if;
  end process;
  
end;
