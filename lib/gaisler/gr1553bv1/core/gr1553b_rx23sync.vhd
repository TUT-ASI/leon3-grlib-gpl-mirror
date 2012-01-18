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
-- Entity:      gr1553b_rx23sync
-- File:        gr1553b_rx23sync.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: Clock domain transition between rx2 (bit detector) and rx3
--              (deserializer)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.gr1553b_core.all;

entity gr1553b_rx23sync is
  generic (
    syncrst: integer range 0 to 2
    );
  port (
    deser_clk: in std_logic;
    deser_rst: in std_logic;
    deser_bito: out gr1553b_rx2_out;
    deser_fb: in gr1553b_rx2_fb;
    bit_clk: in std_logic;
    bit_rst: in std_logic;
    bit_bito: in gr1553b_rx2_out;
    bit_fb: out gr1553b_rx2_fb
    );
end;

architecture rtl of gr1553b_rx23sync is

  type deser_reg_type is record
    last_syncp_tog: std_logic;
    last_syncn_tog: std_logic;
    last_datap_tog: std_logic;
    last_datan_tog: std_logic;
    fb: gr1553b_rx2_fb;
  end record;

  type deser_to_bit is record
    fb: gr1553b_rx2_fb;
  end record;

  type bit_reg_type is record
    syncp_tog: std_logic;
    syncn_tog: std_logic;
    datap_tog: std_logic;
    datan_tog: std_logic;
    idle1,idle2: std_logic;
  end record;

  type bit_to_deser is record
    syncp_tog: std_logic;
    syncn_tog: std_logic;
    datap_tog: std_logic;
    datan_tog: std_logic;
    idle: std_logic;
    act: std_logic;
  end record;

  constant des_r_rst: deser_reg_type := ('0','0','0','0',gr1553b_rx2_fb_none);
  constant d2b_rst: deser_to_bit := (fb => gr1553b_rx2_fb_none);
  constant bit_r_rst: bit_reg_type := ('0','0','0','0','1','1');
  constant b2d_rst: bit_to_deser := ('0','0','0','0','1','0');
  
  signal deser_r, deser_nr: deser_reg_type;
  signal deser_d2b, d2b_sync1, bit_d2b: deser_to_bit;
  signal bit_r, bit_nr: bit_reg_type;
  signal bit_b2d, b2d_sync1, deser_b2d: bit_to_deser;
  
begin

  descomb: process(deser_rst,deser_r,deser_fb,deser_b2d)
    variable v: deser_reg_type;
    variable vd2b: deser_to_bit;
    variable vo: gr1553b_rx2_out;
  begin
    v := deser_r;
    v.fb := deser_fb;
    vd2b := (fb => deser_r.fb);
    vo := (got_sync => '0', got_data => '0', dataval => '0', idle => '0', act => deser_b2d.act);

    v.last_syncp_tog := deser_b2d.syncp_tog;
    v.last_syncn_tog := deser_b2d.syncn_tog;
    v.last_datap_tog := deser_b2d.datap_tog;
    v.last_datan_tog := deser_b2d.datan_tog;

    vo.got_sync := ( (deser_r.last_syncp_tog xor deser_b2d.syncp_tog) or
                     (deser_r.last_syncn_tog xor deser_b2d.syncn_tog) );
    vo.got_data := ( (deser_r.last_datap_tog xor deser_b2d.datap_tog) or
                     (deser_r.last_datan_tog xor deser_b2d.datan_tog) );
    vo.dataval :=  ( (deser_r.last_syncp_tog xor deser_b2d.syncp_tog) or
                     (deser_r.last_datap_tog xor deser_b2d.datap_tog) );
    
    vo.idle := deser_b2d.idle and not (vo.got_sync or vo.got_data);
    
    if deser_rst='0' and syncrst/=0 then
      v := des_r_rst;
    end if;
    
    deser_nr <= v;
    deser_d2b <= vd2b;
    deser_bito <= vo;
  end process;
  
  bitcomb: process(bit_rst,bit_r,bit_d2b,bit_bito)
    variable v: bit_reg_type;
    variable vb2d: bit_to_deser;    
  begin
    v := bit_r;
    vb2d := (syncp_tog => bit_r.syncp_tog, syncn_tog => bit_r.syncn_tog,
             datap_tog => bit_r.datap_tog, datan_tog => bit_r.datan_tog,
             idle => bit_r.idle2, act => bit_bito.act);

    if bit_bito.got_sync='1' then
      if bit_bito.dataval='1' then
        v.syncp_tog := not bit_r.syncp_tog;
      else
        v.syncn_tog := not bit_r.syncn_tog;
      end if;
    end if;

    if bit_bito.got_data='1' then
      if bit_bito.dataval='1' then
        v.datap_tog := not bit_r.datap_tog;
      else
        v.datan_tog := not bit_r.datan_tog;
      end if;
    end if;
    
    v.idle1 := bit_bito.idle;
    v.idle2 := bit_r.idle1 and bit_bito.idle;

    if bit_rst='0' and syncrst/=0 then
      v.datap_tog := '0';
      v.datan_tog := '0';
      v.syncp_tog := '0';
      v.syncn_tog := '0';
    end if;
    
    bit_nr <= v;
    bit_b2d <= vb2d;
    bit_fb <= bit_d2b.fb;
  end process;
  
  desregs: process(deser_clk,deser_rst)
  begin
    if rising_edge(deser_clk) then
      deser_r <= deser_nr;
      b2d_sync1 <= bit_b2d;
      deser_b2d <= b2d_sync1;
    end if;
    if deser_rst='0' and syncrst=0 then
      deser_r <= des_r_rst;
      b2d_sync1 <= b2d_rst;
      deser_b2d <= b2d_rst;
    end if;
  end process;

  bitregs: process(bit_clk,bit_rst)
  begin
    if rising_edge(bit_clk) then
      bit_r <= bit_nr;
      d2b_sync1 <= deser_d2b;
      bit_d2b <= d2b_sync1;
    end if;
    if bit_rst='0' and syncrst=0 then
      bit_r <= bit_r_rst;
      d2b_sync1 <= d2b_rst;
      bit_d2b <= d2b_rst;
    end if;
  end process;
  
end;
