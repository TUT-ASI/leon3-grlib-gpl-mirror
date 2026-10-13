------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
-- Entity:      dmnv_reg_step, dmnv_reg_step_async
-- File:        dmnv_reg_step.vhd
-- Author:      Magnus Hjorth
-- Description: Converter between full and divided clock for internal debug
--              module register interface
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.l5nv_shared.all;

entity dmnv_reg_step is
  port (
    sclk: in std_ulogic;
    srstn: in std_ulogic;
    sri : in dev_reg_in_type;
    sro : out dev_reg_out_type;
    rclk: in std_ulogic;
    rrstn: in std_ulogic;
    rri : out dev_reg_in_type;
    rro : in dev_reg_out_type
    );
end;

architecture rtl of dmnv_reg_step is

  type dmnv_reg_step_sregs is record
    ro : dev_reg_out_type;
    rdyack : std_ulogic;
  end record;

  type dmnv_reg_step_rregs is record
    ri : dev_reg_in_type;
    reqallow: std_ulogic;
    rdyflag: std_ulogic;
    rdhold: std_logic_vector(31 downto 0);
  end record;

  signal sr, nsr: dmnv_reg_step_sregs;
  signal rr, nrr: dmnv_reg_step_rregs;

begin
  sro <= sr.ro;
  rri <= rr.ri;

  comb: process(srstn, rrstn, sr, rr, sri, rro)
    variable vs: dmnv_reg_step_sregs;
    variable vr: dmnv_reg_step_rregs;
  begin
    vs := sr;
    vr := rr;

    vs.rdyack := rr.rdyflag;
    vs.ro.rdy := '0';
    if rr.rdyflag='1' and sr.rdyack='0' then
      vs.ro.rdy := '1';
      vs.ro.data := rr.rdhold;
    end if;

    if rro.rdy='1' then
      vr.rdyflag := '1';
      vr.rdhold := rro.data;
    end if;
    if sr.rdyack='1' then
      vr.rdyflag := '0';
    end if;
    vr.ri := sri;
    vr.reqallow := '1';
    if vr.rdyflag='1' or sr.rdyack='1' then
      vr.ri.sel := (others => '0');
    end if;

    nsr <= vs;
    nrr <= vr;
  end process;

  sregs: process(sclk)
  begin
    if rising_edge(sclk) then
      sr <= nsr;
    end if;
  end process;

  rregs: process(rclk)
  begin
    if rising_edge(rclk) then
      rr <= nrr;
    end if;
  end process;
end;

------------------------------------------------------------------------------
-- Async version, based on l5regcdc
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.l5nv_shared.all;

entity dmnv_reg_step_async is
  generic (
    tech    : integer;
    nsyncms : integer;
    nsyncsm : integer
    );
  port (
    sclk   : in  std_ulogic;
    srstn  : in  std_ulogic;
    sri    : in  dev_reg_in_type;
    sro    : out dev_reg_out_type;
    rclk   : in  std_ulogic;
    rrstn  : in  std_ulogic;
    rri    : out dev_reg_in_type;
    rro    : in  dev_reg_out_type;
    tsten  : in  std_ulogic
    );
end;

architecture rtl of dmnv_reg_step_async is

  type l5regcdc_sregs is record
    req: std_ulogic;
    ackprev: std_ulogic;
    accrdy: std_ulogic;
  end record;

  type l5regcdc_rregs is record
    ack: std_ulogic;
    reqprev: std_ulogic;
    rddata: std_logic_vector(31 downto 0);
  end record;

  signal reqsync: std_ulogic;
  signal srbusen: std_ulogic;
  signal srbusin, srbusout: std_logic_vector((4+32+REGW+1)-1 downto 0);

  signal acksync: std_ulogic;
  signal rsbusout: std_logic_vector(31 downto 0);

  signal sr, nsr: l5regcdc_sregs;
  signal rr, nrr: l5regcdc_rregs;

begin

  rregsr: syncreg
    generic map (
      tech   => tech,
      stages => nsyncms
      )
    port map (
      clk => rclk,
      d   => sr.req,
      q   => reqsync
      );

  srbusin(32+32+1+3 downto 32+32+1) <= sri.sel ;
  srbusin(32+32)                    <= sri.wr  ;
  srbusin(32+31 downto 32)          <= sri.addr;
  srbusin(31 downto 0)              <= sri.data;
  cdcbms: cdcbus
    generic map (
      tech  => tech,
      width => srbusin'length
      )
    port map (
      busin  => srbusin,
      clk    => rclk,
      enable => srbusen,
      busout => srbusout,
      tsten  => tsten
      );

  rregsm: syncreg
    generic map (
      tech => tech,
      stages => nsyncsm
      )
    port map (
      clk => sclk,
      d => rr.ack,
      q => acksync
      );

  cdcbsm: cdcbus
    generic map (
      tech  => tech,
      width => 32
      )
    port map (
      busin  => rr.rddata,
      clk    => sclk,
      enable => acksync,
      busout => rsbusout,
      tsten  => tsten
      );

  scomb: process(srstn,sr,sri,acksync,rsbusout)
    variable sv: l5regcdc_sregs;
  begin
    sv := sr;
    sv.ackprev := acksync;
    sv.accrdy := '0';
    if acksync='1' then
      sv.req := '0';
      if sr.req='1' then
        sv.accrdy := '1';
      end if;
    elsif sri.sel/="0000" and acksync='0' then
      sv.req := '1';
    end if;
    if srstn='0' then
      sv.req := '0';
    end if;
    nsr <= sv;
    sro <= (
      rdy  => sr.accrdy,
      data => rsbusout,
      sbstart  => '0',
      sbwdata  => (others => '0'),
      sbwr     => '0',
      sbaccess => (others => '0'),
      sbaddr   => (others => '0')
      );
  end process;

  rcomb: process(rrstn,rr,rro,reqsync,srbusout)
    variable rv: l5regcdc_rregs;
    variable vsel: std_logic_vector(3 downto 0);
  begin
    rv := rr;
    rv.reqprev := reqsync;
    if reqsync='0' then
      rv.ack := '0';
    elsif rr.reqprev='1' and rro.rdy='1' and rr.ack='0' then
      rv.ack := '1';
      rv.rddata := rro.data;
    end if;
    if rrstn='0' then
      rv.ack := '0';
    end if;
    nrr <= rv;
    srbusen <= reqsync and not rr.reqprev;
    vsel := "0000";
    if rr.reqprev='1' and rr.ack='0' then
      vsel := srbusout(32+32+1+3 downto 32+32+1);
    end if;
    rri.sel  <= vsel;
    rri.wr   <= srbusout(32+32);
    rri.addr <= srbusout(32+31 downto 32);
    rri.data <= srbusout(31 downto 0);
  end process;

  sregs: process(sclk)
  begin
    if rising_edge(sclk) then
      sr <= nsr;
    end if;
  end process;

  rregs: process(rclk)
  begin
    if rising_edge(rclk) then
      rr <= nrr;
    end if;
  end process;

  rri.testen <= sri.testen;
  rri.testrst <= sri.testrst;
end;


------------------------------------------------------------------------------
-- Async version for SBA signals
------------------------------------------------------------------------------

-- The dmnv_reg_step_sba_async is an asynchronous bridge designed to transfer multi-bit
-- command and response vectors across two unrelated clock domains CLK_fast and
-- $CLK_slow. It uses a closed-loop toggle handshake to ensure that data is never
-- sampled while it is transitioning.

-- Both sbstart and sbsinish are pulses that last 1 cycle. Data and control signals
-- remain stable until a new transaction is issued for DM output signals. However,
-- response control and data signal will remain stable only for 1 cycle, the same cycle
-- that sbnish is asserted.

-- 1.- sbstart is asserted in the DM starting a new trasaction
-- 2.- a signal is toggled and synchronized from the fast to the slow domain
--     with a multi-stage FF synchronizer.
-- 3.- When the signal reaches the slow domain, the busenable signal is set and
--     the control and data signals are stored in the slow domain. sbstart singal
--     is kept asserted during one cycle in the slow domain. The rest of the signals
--     remain constant.
-- Same mechanism apply on the other direction, from slow clock domain to fast clock
-- domain. The only difference is that this time we need to register the data and control
-- signals because the response signals only last one cycle.

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.l5nv_shared.all;

entity dmnv_reg_step_sba_async is
  generic (
    tech    : integer;
    nsyncms : integer;
    nsyncsm : integer
    );
  port (
    -- CPU domain (Fast clock)
    rclk   : in  std_ulogic;
    rrstn  : in  std_ulogic;
    rro    : in  dev_reg_out_type;
    rri    : out dev_reg_in_type;
    -- AUX domain (Slow clock)
    sclk   : in  std_ulogic;
    srstn  : in  std_ulogic;
    sro    : out dev_reg_out_type;
    sri    : in  dev_reg_in_type;
    tsten  : in  std_ulogic
    );
end;

architecture rtl of dmnv_reg_step_sba_async is

  type l5regcdc_sregs is record
    reqsynctog : std_ulogic;
    acktog     : std_ulogic;
    sbstart    : std_ulogic;
    srbusen    : std_ulogic;
    busin      : std_logic_vector(33 downto 0);
    sro        : std_logic_vector(99 downto 0);
  end record;

  type l5regcdc_rregs is record
    acksynctog : std_ulogic;
    sbwr       : std_ulogic;
    reqtog     : std_ulogic;
    sbfinish   : std_ulogic;
    rrbusen    : std_ulogic;
    rri        : std_logic_vector(33 downto 0);
  end record;

  signal rrbusen: std_ulogic;
  signal rrbusin, srbusout : std_logic_vector(99 downto 0);
  signal reqsynctog :  std_ulogic;

  signal srbusen : std_ulogic;
  signal rrbusout : std_logic_vector(33 downto 0);
  signal acksynctog :  std_ulogic;

  signal sr, nsr: l5regcdc_sregs;
  signal rr, nrr: l5regcdc_rregs;

begin

  rregsr: syncreg
    generic map (
      tech   => tech,
      stages => nsyncms
      )
    port map (
      clk => sclk,
      d   => rr.reqtog,
      q   => reqsynctog
      );

  rrbusin(99)                <= rr.sbwr ;
  rrbusin(3+95 downto 96)    <= rro.sbaccess;
  rrbusin(32+63 downto 64)   <= rro.sbwdata;
  rrbusin(63 downto 0)       <= rro.sbaddr;
  cdcbms: cdcbus
    generic map (
      tech  => tech,
      width => rrbusin'length
      )
    port map (
      busin  => rrbusin,
      clk    => sclk,
      enable => srbusen,
      busout => srbusout,
      tsten  => tsten
      );

  rregsm: syncreg
    generic map (
      tech => tech,
      stages => nsyncsm
      )
    port map (
      clk => rclk,
      d => sr.acktog,
      q => acksynctog
      );

  cdcbsm: cdcbus
    generic map (
      tech  => tech,
      width => sr.busin'length
      )
    port map (
      busin  => sr.busin,
      clk    => rclk,
      enable => rrbusen,
      busout => rrbusout,
      tsten  => tsten
      );



  rcomb: process(rr, rro, acksynctog, rrstn, rrbusout, rrbusen)
    variable rv: l5regcdc_rregs;
  begin
    rv := rr;
    -- from rro to sro
    -- data is stable and sbstart last only 1 cycle
    if rro.sbstart = '1' then
      -- Toggle synch signal to start a new transaction
      rv.reqtog := not rr.reqtog;
      -- We need to register sbwr since it only lasts 1 cycle
      rv.sbwr   := rro.sbwr;
    end if;

    -- From sri to rri
    rrbusen <= '0';
    rv.acksynctog := acksynctog;
    if (rr.acksynctog xor acksynctog) = '1' then
      -- Transaction finished
      -- We need to register the response
      rrbusen <= '1';
    end if;
    rv.rrbusen := rrbusen;
    rv.sbfinish  := rr.rrbusen;
    if rr.rrbusen = '1' then
      rv.rri := rrbusout;
    end if;
    if rrstn='0' then
      rv.acksynctog := '0';
      rv.sbwr       := '0';
      rv.reqtog     := '0';
      rv.sbfinish   := '0';
      rv.rrbusen    := '0';
    end if;
    nrr <= rv;
  end process;

  scomb: process(sr, sri, reqsynctog, srstn, srbusout, srbusen)
    variable sv: l5regcdc_sregs;
  begin
    sv := sr;
    -- from rro to sro
    srbusen <= '0';
    sv.reqsynctog := reqsynctog;
    if (sr.reqsynctog xor reqsynctog) = '1' then
      -- New transaction strated
      -- We need to register the data
      srbusen <= '1';
    end if;
    sv.srbusen := srbusen;
    sv.sbstart := sr.srbusen;
    if sr.srbusen = '1' then
      sv.sro := srbusout;
    end if;

    -- From sri to rri
    -- sbfinish last only 1 cycle, we need to register the data
    if sri.sbfinish = '1' then
      -- Toggle synch signal to start a new transaction
      sv.acktog := not sr.acktog;
      sv.busin(33)          := sri.sbdvalid;
      sv.busin(32)          := sri.sberror;
      sv.busin(31 downto 0) := sri.sbrdata;
    end if;
    if srstn='0' then
      sv.reqsynctog := '0';
      sv.acktog     := '0';
      sv.sbstart    := '0';
      sv.srbusen    := '0';
    end if;
    nsr <= sv;
  end process;

  rri.sbdvalid <= rr.rri(33);
  rri.sberror  <= rr.rri(32);
  rri.sbrdata  <= rr.rri(31 downto 0);
  rri.sbfinish <= rr.sbfinish;

  sro.sbwr     <= sr.sro(99);
  sro.sbaccess <= sr.sro(3+95 downto 96);
  sro.sbwdata  <= sr.sro(32+63 downto 64);
  sro.sbaddr   <= sr.sro(63 downto 0);
  sro.sbstart  <= sr.sbstart;


  sregs: process(sclk)
  begin
    if rising_edge(sclk) then
      sr <= nsr;
    end if;
  end process;

  rregs: process(rclk)
  begin
    if rising_edge(rclk) then
      rr <= nrr;
    end if;
  end process;

end;
