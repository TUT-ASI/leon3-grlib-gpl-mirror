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
-- Entity:      gr1553b_rx2
-- File:        gr1553b_rx2.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B receiver stage 2, bit recovery
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.gr1553b_core.all;

entity gr1553b_rx2 is

  generic (
    -- Frequency of clk in MHz
    -- Clock must be even multiple of 2 MHz
    clk_freq_mhz: integer;
    syncrst: integer range 0 to 2
    );
  port (
    clk: in std_logic;
    rst: in std_logic;

    -- From receiver stage 1
    s1o: in gr1553b_rx1_out;    
    -- Outputs
    bito: out gr1553b_rx2_out;
    -- Feedback from following stage
    fb: in gr1553b_rx2_fb
    );
end;

architecture rtl of gr1553b_rx2 is

  constant bit_time: integer := clk_freq_mhz;

  type rx2_regs is record
    has_sync: std_logic;
    syncblock: std_logic_vector(4 downto 0);
    act: std_logic;
    tcount: integer range 0 to bit_time-1;
  end record;

  constant r_rst: rx2_regs := ('0',"00000",'0',0);
    
  signal r,nr: rx2_regs;
  
begin

  comb: process(rst,s1o,r,fb)
    variable v: rx2_regs;
    variable vgot_sync: std_logic;
    variable vgot_data: std_logic;
    variable vdataval: std_logic;
    variable vidle: std_logic;
    variable vo: gr1553b_rx2_out;
  begin    
    v := r;
    vgot_sync := '0';
    vgot_data := '0';
    vdataval := s1o.bit_det_p;
    vidle := not r.has_sync;
    
    if r.tcount=bit_time-1 then
      v.tcount := 0;
    else
      v.tcount := r.tcount+1;
    end if;
    
    if r.has_sync='0' then      
      if s1o.bit_det_p='1' or s1o.bit_det_n='1' then
        v.act := '1';
        if r.syncblock(4)='0' then v.tcount := 0; end if;
      elsif r.tcount=bit_time-1 then
        v.act := '0';
      end if;
      if r.tcount=bit_time-1 then
        v.syncblock := r.syncblock(3 downto 0) & "0";
      end if;      
      if (s1o.cmd_sync_det='1' or s1o.data_sync_det='1') and r.syncblock(4)='0' then
        vgot_sync := '1';
        vdataval := s1o.cmd_sync_det;
        v.has_sync := '1';
        v.act := '1';
        v.tcount := 0;
      end if;
    end if;

    if r.has_sync='1' then
      if r.tcount=bit_time-1 then
        if (s1o.bit_det_p='1' or s1o.bit_det_n='1') then
          vgot_data := '1';
          vdataval := s1o.bit_det_p;
          if r.syncblock(4)='1' then
            v.has_sync := '0';
          end if;
        else
          v.has_sync := '0';
        end if;
      end if;
    end if;

    if fb.syncblock='1' then
      v.syncblock := "11000";
    end if;
    if fb.gapblock='1' then
      v.syncblock := "11111";
    end if;

    -- Prevent counter spinning when idle.
    if (r.has_sync='0' and r.act='0' and r.syncblock(4)='0') then
      v.tcount := 0;
    end if;
    
    if rst='0' and syncrst/=0 then
      v.has_sync := r_rst.has_sync;
      v.act := r_rst.act;
      v.syncblock := r_rst.syncblock;
    end if;
    vo := (vgot_sync,vgot_data,vdataval,vidle,r.act);
    
    nr <= v;
    bito <= vo;
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
