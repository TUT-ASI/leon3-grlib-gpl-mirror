------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
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
-- Entity:      jtagcom
-- File:        jtagcom.vhd
-- Author:      Nils Wessman - Cobham Gaisler
-- Description: JTAG Debug Interface with AHB master interface
--              Redesigned to work for TCK both slower and faster than AHB
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.config_types.all;
use grlib.config.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.libjtagcom.all;

entity jtagcomrv is
  generic (
    gatetech: integer := 0;
    isel   : integer range 0 to 1 := 0;
    ainst  : integer range 0 to 255 := 2;
    dinst  : integer range 0 to 255 := 3);
  port (
    rst  : in std_ulogic;
    clk  : in std_ulogic;
    tapo : in tap_out_type;
    tapi : out tap_in_type;
    dmao : in  ahb_dma_out_type;
    dmai : out ahb_dma_in_type;
    tckp : in std_ulogic;
    tckn : in std_ulogic;
    trst : in std_ulogic
    );
  attribute sync_set_reset of rst : signal is "true";
end;


architecture rtl of jtagcomrv is

  constant ADDBITS : integer := 10;
  constant NOCMP : boolean := (isel /= 0);

  type tckpreg1_type is record          -- always reset
    stat       : std_logic_vector(1 downto 0);
    dmi10      : std_logic_vector(1 downto 0);
    done_sync  : std_ulogic;
    prun       : std_ulogic;
    inshift    : std_ulogic;
    holdn      : std_ulogic;
  end record;

  type tckpreg2_type is record          -- reset only if reset_all
    dtmcs      : std_logic_vector(31 downto 0);
    dmi        : std_logic_vector(33+7 downto 2);
  end record;

  type tcknreg1_type is record          -- always reset
    run: std_ulogic;
    done_sync1: std_ulogic;
    qual_rdata: std_ulogic;
    write     : std_ulogic;
  end record;

  type tcknreg2_type is record          -- reset only if reset_all
    dummy      : std_logic;
    dmi        : std_logic_vector(33+7 downto 0);
  end record;

  type ahbreg_type is record
    run_sync:  std_logic_vector(2 downto 0);
    qual_dreg: std_ulogic;
    --qual_areg: std_ulogic;
    --areg: std_logic_vector(34 downto 0);
    dreg: std_logic_vector(33+7 downto 0);
    done: std_ulogic;
    dmastart: std_ulogic;
    wdone: std_ulogic;
  end record;

  constant RESET_ALL : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0;
  --constant ARES: ahbreg_type := ((others => '0'),'0','0',(others => '0'),(others => '0'),'0','0','0');
  constant ARES: ahbreg_type := ((others => '0'),'0',(others => '0'),'0','0','0');
  constant TP1RES: tckpreg1_type := ((others => '0'),(others => '0'),'0','0','0','1');
  constant TP2RES: tckpreg2_type := ((others => '0'),(others => '0'));
  constant TN1RES: tcknreg1_type := ('0','0','0','0');
  constant TN2RES: tcknreg2_type := ('0', (others => '0'));

  signal ar, arin : ahbreg_type;
  signal tpr1, tpr1in: tckpreg1_type;
  signal tpr2, tpr2in: tckpreg2_type;
  signal tnr1, tnr1in: tcknreg1_type;
  signal tnr2, tnr2in: tcknreg2_type;

  signal qual_rdata, rdataq: std_logic_vector(33 downto 0);
  signal qual_dreg, dregq: std_logic_vector(33+7 downto 0);
  --signal qual_areg,  aregqin, aregq: std_logic_vector(34 downto 0);

  attribute syn_keep: boolean;
  attribute syn_keep of rdataq : signal is true;
  attribute syn_keep of dregq : signal is true;
  --attribute syn_keep of aregq : signal is true;

  ----
  attribute syn_preserve: boolean;  
  attribute syn_keep of ar : signal is true;
  attribute syn_keep of tnr1 : signal is true;
  attribute syn_keep of tnr2 : signal is true;
  attribute syn_keep of tpr1 : signal is true;
  attribute syn_keep of tpr2 : signal is true;
  attribute syn_keep of arin : signal is true;
  attribute syn_keep of tnr1in : signal is true;
  attribute syn_keep of tnr2in : signal is true;
  attribute syn_preserve of ar : signal is true;
  attribute syn_preserve of tnr1 : signal is true;
  attribute syn_preserve of tnr2 : signal is true;
  attribute syn_preserve of tpr1 : signal is true;
  attribute syn_preserve of tpr2 : signal is true;
  attribute syn_preserve of rdataq : signal is true;
  attribute syn_preserve of dregq : signal is true;
  --attribute syn_preserve of aregq : signal is true;

  ----


begin

  rdqgen: for x in 33 downto 0 generate
    rdq: grnand2 generic map (tech => gatetech) port map (ar.dreg(x), qual_rdata(x), rdataq(x));
  end generate;

  dqgen: for x in 33+7 downto 0 generate
    dq: grnand2 generic map (tech => gatetech) port map (tnr2.dmi(x), qual_dreg(x), dregq(x));
  end generate;

  --aregqin <= tpr2.addr(34 downto ADDBITS) &
  --           tnr2.addrlo(ADDBITS-1 downto 2) &
  --           tpr2.addr(1 downto 0);

  --aqgen: for x in 34 downto 0 generate
  --  aq: grnand2 generic map (tech => gatetech) port map (aregqin(x), qual_areg(x), aregq(x));
  --end generate;

  --comb : process (rst, ar, tapo, dmao, tpr1, tpr2, tnr1, tnr2, aregq, dregq, rdataq)
  comb : process (rst, ar, tapo, dmao, tpr1, tpr2, tnr1, tnr2, dregq, rdataq)
    variable av : ahbreg_type;
    variable tpv1 : tckpreg1_type;
    variable tpv2 : tckpreg2_type;
    variable tnv1 : tcknreg1_type;
    variable tnv2 : tcknreg2_type;
    variable vdmai : ahb_dma_in_type;
    variable asel, dsel : std_ulogic;
    variable vtapi : tap_in_type;
    variable write, nop, stat_rst: std_ulogic;
    --variable write, seq : std_ulogic;
  begin

    av := ar; tpv1 := tpr1; tpv2 := tpr2; tnv1 := tnr1; tnv2 := tnr2;

    ---------------------------------------------------------------------------
    -- TCK side logic
    ---------------------------------------------------------------------------

    if NOCMP then
      asel := tapo.asel; dsel := tapo.dsel;
    else
      if tapo.inst = conv_std_logic_vector(ainst, 8) then asel := '1'; else asel := '0'; end if;
      if tapo.inst = conv_std_logic_vector(dinst, 8) then dsel := '1'; else dsel := '0'; end if;
    end if;
    vtapi.en := asel or dsel;
    vtapi.tdo:=tpr2.dtmcs(0);
    if dsel='1' then
      vtapi.tdo:=tpr1.dmi10(0) and tpr1.holdn;
    end if;
    write     := tpr1.dmi10(1) and not tpr1.dmi10(0); --seq := tpr2.datashft(32);
    nop       := not orv(tpr1.dmi10);
    stat_rst  := tpr2.dtmcs(16);

    -- Sync regs using alternating phases
    tnv1.done_sync1 := ar.done;
    tpv1.done_sync  := tnr1.done_sync1;

    -- Data CDC
    qual_rdata <= (others => tnr1.qual_rdata);
    if tnr1.qual_rdata='1' then
      if tnr1.write = '0' then
        tpv2.dmi(33 downto 2) := (not rdataq(33 downto 2));
      end if;
      tpv1.stat := tpr1.stat or (not rdataq(1 downto 0));
      --tpv1.dmi10 := (not rdataq(1 downto 0));
    end if;

    if tapo.capt='1' then 
      if tnv1.run = '1' then
        tpv1.stat := "11";
      end if;
      tpv2.dtmcs(31 downto 12) := x"0000" & '0' & "000";
      tpv2.dtmcs(11 downto 10) := tpv1.stat; 
      tpv2.dtmcs(9 downto 0) := "000111" & "0001";
      tpv1.dmi10 := tpv1.stat;
    end if;

    -- Track whether we're in the middle of shifting
    if tapo.shift='1' then tpv1.inshift:='1'; end if;
    if tapo.upd='1' then tpv1.inshift:='0'; end if;

    if tapo.shift='1' then
      if asel = '1' then tpv2.dtmcs(31 downto 0) := tapo.tdi & tpr2.dtmcs(31 downto 1); end if;
      if dsel = '1' and tpr1.holdn='1' then
        tpv2.dmi(33+7 downto 2) := tapo.tdi & tpr2.dmi(33+7 downto 3);
        tpv1.dmi10 := tpr2.dmi(2) & tpr1.dmi10(1);
      end if;
    end if;

    if tnr1.run='0' then tpv1.holdn:='1'; end if;
    tpv1.prun := tnr1.run;

    if tpr1.prun='0' then
      tnv1.qual_rdata := '0';
      if tapo.shift='0' and tapo.upd = '1' then
        --if asel='1' then tnv2.addrlo := tpr2.addr(ADDBITS-1 downto 2); end if;
        --if dsel='1' then tnv2.data := tpr2.datashft & tpr1.datashft0; end if;
        --if (asel and not write) = '1' then tpv1.holdn := '0'; tnv1.run := '1'; end if;
        --if (dsel and (write or (not write and seq))) = '1' then
        --  tnv1.run := '1';
        --  if (seq and not write) = '1' then
        --    if tpr1.inshift='1' then
        --      tnv2.addrlo := tnr2.addrlo + 1;
        --    end if;
        --    tpv1.holdn := '0';
        --  end if;
        --end if;

        if asel = '1' and stat_rst = '1' then tpv1.stat := (others => '0'); end if;
        if dsel = '1' and nop = '0' then
          tnv1.run := '1';
          tnv1.write := write;
          tnv2.dmi := tpr2.dmi & tpr1.dmi10;
        end if;
      end if;
    else
      if tpr1.done_sync='1' and (tpv1.inshift='0' or write='1') then
        tnv1.run := '0';
        --if write='0' then
          tnv1.qual_rdata := '1';
        --end if;
        --if (write and tnr2.data(32)) = '1' then
        --  tnv2.addrlo := tnr2.addrlo + 1;
        --end if;
      end if;
    end if;

    if tapo.reset='1' then
      tpv1.inshift := '0';
      tnv1.run := '0';
    end if;

    ---------------------------------------------------------------------------
    -- AHB side logic
    ---------------------------------------------------------------------------

    -- Sync regs and CDC transfer
    av.run_sync := tnr1.run & ar.run_sync(2) & ar.run_sync(1);

    qual_dreg <= (others => ar.qual_dreg);
    if ar.qual_dreg='1' then av.dreg:=not dregq; end if;
    --qual_areg <= (others => ar.qual_areg);
    --if ar.qual_areg='1' then av.areg:=not aregq; end if;

    vdmai.address := x"fe000" & "000" & ar.dreg(33+7 downto 34) & "00";
    vdmai.wdata := ahbdrivedata(ar.dreg(33 downto 2));
    vdmai.start := '0'; vdmai.burst := '0';
    vdmai.write := ar.dreg(1) and not ar.dreg(0);
    vdmai.busy := '0'; vdmai.irq := '0';
    vdmai.size := '0' & "10";

    av.qual_dreg := '0';
    --av.qual_areg := '0';
    vdmai.start := '0';

    if ar.dmastart='1' then
      if dmao.active='1' then
        if dmao.ready='1' then
          av.dreg(33 downto 2) := ahbreadword(dmao.rdata);
          if dmao.mexc = '1' then 
            av.dreg(1 downto 0) := "10";
          else
            av.dreg(1 downto 0) := (others => '0');
          end if;
          if ar.dreg(1) = '0' and ar.dreg(0) = '1' then
            av.done := '1';
          end if;
          av.dmastart := '0';
        end if;
      else
        vdmai.start := '1';
        if ar.dreg(1) = '1' and ar.dreg(0) = '0' and ar.wdone = '0' then
          av.done := '1';
          av.wdone := '1';
        end if;
      end if;
    end if;
    --if ar.qual_areg='1' then
    if ar.qual_dreg='1' then
      av.dmastart := '1';
      av.wdone := '0';
    end if;
    if ar.run_sync(0)='1' and ar.qual_dreg='0' and ar.dmastart='0' and ar.done='0' then
      av.qual_dreg := '1';
      --av.qual_areg := '1';
    end if;
    if ar.run_sync(0)='0' and ar.done='1' then
      av.done := '0';
    end if;


    if (rst = '0') and not RESET_ALL then
      av.qual_dreg := ARES.qual_dreg;
      --av.qual_areg := ARES.qual_areg;
      av.done := ARES.done;
      --av.areg := ARES.areg;
      av.dreg := ARES.dreg;
      av.dmastart := ARES.dmastart;
      av.run_sync := ARES.run_sync;
    end if;

    tpr1in <= tpv1; tpr2in <= tpv2; tnr1in <= tnv1; tnr2in <= tnv2; arin <= av; dmai <= vdmai; tapi <= vtapi;
  end process;



  ahbreg : process(clk)
  begin
    if rising_edge(clk) then
      ar <= arin;
      if (rst = '0') and RESET_ALL then
        ar <= ARES;
      end if;
    end if;
  end process;

  tckp1reg: process(tckp,trst)
  begin
    if rising_edge(tckp) then
      tpr1 <= tpr1in;
    end if;
    if trst='0' then
      tpr1 <= TP1RES;
    end if;
  end process;

  tckp2reg: process(tckp,trst)
  begin
    if rising_edge(tckp) then
      tpr2 <= tpr2in;
    end if;
    if RESET_ALL and trst='0' then
      tpr2 <= TP2RES;
    end if;
  end process;

  tckn1reg: process(tckn,trst)
  begin
    if rising_edge(tckn) then
      tnr1 <= tnr1in;
    end if;
    if trst='0' then
      tnr1 <= TN1RES;
    end if;
  end process;

  tckn2reg: process(tckn,trst)
  begin
    if rising_edge(tckn) then
      tnr2 <= tnr2in;
    end if;
    if RESET_ALL and trst='0' then
      tnr2 <= TN2RES;
    end if;
  end process;

end;

