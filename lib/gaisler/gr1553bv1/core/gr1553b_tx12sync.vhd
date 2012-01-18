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
-- Entity:      gr1553b_tx12sync
-- File:        gr1553b_tx12sync.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: Clock domain transition between tx1 (serializer) and
--              tx2 (encoder)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.gr1553b_core.all;

entity gr1553b_tx12sync is
  generic (
    syncrst: integer range 0 to 2
    );  
  port (
    ser_clk: in std_logic;
    ser_rst: in std_logic;

    ser_biti: in gr1553b_tx2_in;
    ser_bito: out gr1553b_tx2_out;

    out_clk: in std_logic;
    out_rst: in std_logic;

    out_bito: in gr1553b_tx2_out;
    out_biti: out gr1553b_tx2_in    
    );
end;

architecture rtl of gr1553b_tx12sync is

  type ser_regs_type is record
    last_dv: std_logic;
    got_read: std_logic;
  end record;

  type ser_to_out_type is record
    dv, sync, data: std_logic;
    read_ret: std_logic;
  end record;

  type out_regs_type is record
    sending_read: std_logic;
    got_readahead: std_logic;
    ra_sync: std_logic;
    ra_data: std_logic;
    last_dv: std_logic;
  end record;

  type out_to_ser_type is record
    xread: std_logic;
    done: std_logic;
  end record;

  constant ser_regs_rst: ser_regs_type := ('0','0');
  constant s2o_rst: ser_to_out_type := ('0','0','0','0');
  constant out_regs_rst: out_regs_type := ('0','0','0','0','0');
  constant o2s_rst: out_to_ser_type := ('0','1');
  
  signal ser_regs, nser_regs: ser_regs_type;
  signal ser_s2o, s2o_sync1, out_s2o: ser_to_out_type;
  signal out_regs, nout_regs: out_regs_type;
  signal out_o2s, o2s_sync1, ser_o2s: out_to_ser_type;
  
begin

  sercomb: process(ser_rst, ser_biti, ser_regs, ser_o2s)
    variable vs2o: ser_to_out_type;
    variable vr: ser_regs_type;
    variable vout: gr1553b_tx2_out;
  begin
    vs2o := (dv => '0', sync => ser_biti.sync, data => ser_biti.data, read_ret => ser_regs.got_read);
    vout := ('0', '0', '0', '0');       -- note txstarting not forwarded
    vr := ser_regs;
    vout.done := ser_o2s.done and not ser_biti.dv;
    
    -- Delay positive edge of dv one cycle so data/sync lines reaches there first
    vr.last_dv := ser_biti.dv;
    if ser_regs.last_dv='1' and ser_biti.dv='1' then vs2o.dv:='1'; end if;
    -- Handshake read pulse
    vr.got_read := ser_o2s.xread;
    if ser_o2s.xread='1' and ser_regs.got_read='0' then vout.xread:='1'; end if;
    if ser_o2s.xread='1' then vs2o.read_ret:='1'; end if;

    if ser_rst='0' and syncrst/=0 then
      vr.got_read := '0';
    end if;
    
    ser_s2o <= vs2o;
    nser_regs <= vr;
    ser_bito <= vout;
  end process;

  
  outcomb: process(out_rst, out_bito, out_regs, out_s2o)
    variable vo2s: out_to_ser_type;
    variable vr: out_regs_type;
    variable vin: gr1553b_tx2_in;
  begin
    vo2s := (xread => out_regs.sending_read, done => out_bito.done);
    vr := out_regs;
    vin := (dv => out_regs.last_dv, sync => out_s2o.sync, data => out_s2o.data);

    -- Delay dv here too so data/sync lines arrive first
    vr.last_dv := out_s2o.dv;
    -- Handshake read pulse
    if out_bito.xread='1' and out_regs.got_readahead='0' then
      vr.sending_read := '1';
    elsif out_s2o.read_ret='1' then
      vr.sending_read := '0';
    end if;
    -- Handle one bit readahead
    if out_bito.xread='1' and out_regs.got_readahead='1' then
      vr.got_readahead := '0';
    end if;
    if out_regs.got_readahead='1' then
      vin.dv := '1';
      vin.sync := out_regs.ra_sync;
      vin.data := out_regs.ra_data;
    end if;
    if out_regs.got_readahead='0' and out_regs.last_dv='1' and out_regs.sending_read='0'
      and out_bito.xread='0' and out_s2o.read_ret='0' and out_bito.lasthus='1' then
      
      vr.sending_read := '1';
      vr.got_readahead := '1';
      vr.ra_sync := out_s2o.sync;
      vr.ra_data := out_s2o.data;
      
    end if;

    -- Reset
    if out_rst='0' and syncrst/=0 then
      vr.sending_read := '0';
      vr.got_readahead := '0';
    end if;
    
    out_o2s <= vo2s;
    nout_regs <= vr;
    out_biti <= vin;
  end process;

  
  serregproc: process(ser_clk,ser_rst)
  begin
    if rising_edge(ser_clk) then
      o2s_sync1 <= out_o2s;
      ser_o2s <= o2s_sync1;
      ser_regs <= nser_regs;
    end if;
    if ser_rst='0' and syncrst=0 then
      o2s_sync1 <= o2s_rst;
      ser_o2s <= o2s_rst;
      ser_regs <= ser_regs_rst;
    end if;
  end process;
  
  outregproc: process(out_clk,out_rst)
  begin
    if rising_edge(out_clk) then      
      s2o_sync1 <= ser_s2o;
      out_s2o <= s2o_sync1;
      out_regs <= nout_regs;
    end if;
    if out_rst='0' and syncrst=0 then
      s2o_sync1 <= s2o_rst;
      out_s2o <= s2o_rst;
      out_regs <= out_regs_rst;
    end if;
  end process;
  
end;
