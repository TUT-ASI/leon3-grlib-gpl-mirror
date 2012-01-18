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
-- Entity:      combine1553
-- File:        combine1553.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: Glue logic for using two 1553 IP cores behind the same
--              transceiver
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity combine1553 is
  port (
    clk: in std_ulogic;
    txin1,rxen1: in std_ulogic;
    tx1P,tx1N: in std_ulogic;
    rx1P,rx1N: out std_ulogic;
    txin2,rxen2: in std_ulogic;
    tx2P,tx2N: in std_ulogic;
    rx2P,rx2N: out std_ulogic;
    txin,rxen: out std_ulogic;
    txP,txN: out std_ulogic;
    rxP,rxN: in std_ulogic
    );
end;

architecture rtl of combine1553 is

  type milcombine_regs is record
    tx1,tx2: std_logic;
    txP,txN,rxP,rxN: std_logic;
    txin,rxen: std_logic;
    qctr: std_logic_vector(2 downto 0);
  end record;

  signal r,nr: milcombine_regs;
  
begin

  comb: process(r,tx1P,tx1N,tx2P,tx2N,rxP,rxN,txin1,txin2,rxen1,rxen2)
    variable v: milcombine_regs;
    variable vtxP,vtxN,vrx1P,vrx1N,vrx2P,vrx2N,vtxin,vrxen: std_ulogic;
  begin
    -- Init vars
    vtxP := r.txP;
    vtxN := r.txN;
    vrx1P := r.rxP;
    vrx1N := r.rxN;
    vrx2P := r.rxP;
    vrx2N := r.rxN;
    vtxin := r.txin;
    vrxen := r.rxen;
    v := r;
    -- Comb logic
    v.txin := txin1 and txin2;
    v.rxen := rxen1 or rxen2;
    v.txP := (tx1P and not tx1N) or (tx2P and not tx2N) or (txin1 and txin2);
    v.txN := (tx1N and not tx1P) or (tx2N and not tx2P) or (txin1 and txin2);
    v.rxP := rxP;
    v.rxN := rxN;    
    if (r.tx1='1' or r.tx2='1') and r.rxP=r.rxN then      
      v.qctr := std_logic_vector(unsigned(r.qctr)+1);
      if r.qctr="111" then
        v.tx1 := '0';
        v.tx2 := '0';
      end if;
    else
      v.qctr := "000";
    end if;    
    if tx1P /= tx1N then
      v.tx1 := '1';
    end if;    
    if tx2P /= tx2N then
      v.tx2 := '1';
    end if;
    if r.tx1='1' then
      vrx2P := tx1P;
      vrx2N := tx1N;
    end if;
    if r.tx2='1' then
      vrx1P := tx2P;
      vrx1N := tx2N;
    end if;
    vrx1P := vrx1P and rxen1;
    vrx1N := vrx1N and rxen1;
    vrx2P := vrx2P and rxen2;
    vrx2N := vrx2N and rxen2;
    -- Assign outputs
    nr <= v;
    txP <= vtxP;
    txN <= vtxN;
    rx1P <= vrx1P;
    rx1N <= vrx1N;
    rx2P <= vrx2P;
    rx2N <= vrx2N;
    txin <= vtxin;
    rxen <= vrxen;
  end process;
  
  regs: process(clk)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
  end process;
  
end;
