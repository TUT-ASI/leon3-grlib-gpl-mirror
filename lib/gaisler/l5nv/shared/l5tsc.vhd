------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
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
-- Entity:      l5tscgen, l5tscsink
-- File:        l5tsc.vhd
-- Author:      Magnus Hjorth, Frontgrade Gaisler
-- Description: Cycle timer generation and distribution using a combination
--              of synchronous pipelined interface to manage the lsb:s, and
--              an asynchronous interface for transferring the higher bits
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.stdlib.all;
library gaisler;
use gaisler.l5nv_shared.all;

entity l5tscgen is
  generic (
    tech     : integer;
    nsync    : integer;
    nsinks   : integer;
    npipe    : integer;
    asyncset : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    ctrl     : in  l5_tsc_ctrl_type;
    tssetack : out std_ulogic;
    tsc      : out l5_tsc_async_vector(0 to nsinks-1)
    );
end;

architecture rtl of l5tscgen is

  type l5tscgen_state_type is (s_stopped, s_running);


  subtype loupd_type is std_logic_vector(1 downto 0);
  type loupd_array is array(natural range <>) of loupd_type;

  subtype l5tscgen_fastpipe_type is loupd_array(0 to npipe-1);
  type l5tscgen_fastpipe_array is array(0 to nsinks-1) of l5tscgen_fastpipe_type;

  type l5tscgen_regs is record
    state   : l5tscgen_state_type;
    timer   : std_logic_vector(62 downto 0);
    tloout  : std_logic_vector(7 downto 0);
    strobeh : std_ulogic;
    strobel : std_ulogic;
    -- Next one-cycle update
    tinc    : loupd_type;
    -- Fast pipeline
    fpipe   : l5tscgen_fastpipe_array;
    -- Sync with ctrl
    setack  : std_ulogic;
  end record;

  type l5tscgen_ctrl_regs is record
    set    :   std_ulogic;
    setval :   std_logic_vector(62 downto 0);
  end record;

  signal r, nr: l5tscgen_regs;
  signal rc, nrc: l5tscgen_ctrl_regs;

  signal setsync: std_ulogic;
  signal freezesync: std_ulogic;
  signal nsetval, setvalg: std_logic_vector(62 downto 0);

begin

  sreggen: if asyncset/=0 generate
    srsetsync: syncreg
      generic map (tech => tech, stages => nsync)
      port map (clk => clk, d => ctrl.set, q => setsync);
    srfreeze: syncreg
      generic map (tech => tech, stages => nsync)
      port map (clk => clk, d => ctrl.freeze, q => freezesync);

    nsetval <= not ctrl.setval;
    ggloop: for x in 62 downto 0 generate
      n: grnand2
        generic map (tech => tech)
        port map (
          i0 => nsetval(x),
          i1 => setsync,
          q =>  setvalg(x)
          );
    end generate;

    tssetack <= r.setack;
  end generate;

  sregbp: if asyncset=0 generate
    setsync <= ctrl.set;
    freezesync <= ctrl.freeze;
    setvalg <= ctrl.setval;
    nsetval <= (others => '0');
    -- Drive tssetack to constant 0 in this config to catch
    -- mis-configuration (if outside configured to expect ack
    -- handshake but we are not)
    tssetack <= '0';
  end generate;

  comb: process(rstn,r,
                setsync,freezesync,setvalg)
    variable v: l5tscgen_regs;
    variable otsc: l5_tsc_async_vector(0 to nsinks-1);
    variable vfinc: std_logic_vector(1 downto 0);
  begin
    v := r;
    for x in 0 to nsinks-1 loop
      otsc(x) := (
        loupd   => r.fpipe(x)(npipe-1),
        incval  => "000",
        tschi   => r.timer(62 downto 8),
        tsclo   => r.tloout,
        strobeh => r.strobeh,
        strobel => r.strobel
        );
    end loop;
    -- Fast tick pipeline logic
    vfinc := r.tinc;
    for x in 0 to nsinks-1 loop
      for p in npipe-1 downto 0 loop
        if p>0 then
          v.fpipe(x)(p) := r.fpipe(x)((p-1) mod npipe);
        end if;
      end loop;
      v.fpipe(x)(0) := vfinc;
    end loop;
    v.tinc := "00";
    case r.state is
      when s_stopped =>
        -- In stopped state, the low bits of the timer are stored in tloout
        -- and r.timer(7:0) is used as a delay counter
        if freezesync='0' then
          -- We increment the timer to create some delay before starting,
          --   during this delay we raise the strobes to initialize the
          --   sinks.
          v.timer := add(r.timer, 1);
          if r.timer(7 downto 0)="11111110" then
            v.timer(7 downto 0) := r.tloout;
            v.state := s_running;
          end if;
        else
          v.timer(7 downto 0) := "00000000";
        end if;
      when s_running =>
        if freezesync='0' then
          v.timer := add(r.timer, 1);
          v.tinc(0) := '1';
          if r.timer(7)='1' and v.timer(7)='0' then v.tinc(1) := '1'; end if;
        else
          v.state := s_stopped;
          v.tloout := r.timer(7 downto 0);
          v.timer(7 downto 0) := "00000000";
        end if;
    end case;
    -- Raise strobe for high bits when timer[7:6]=10 or timer[7:6]=01, in middle
    -- of lsb cycle
    v.strobeh := '0';
    v.strobel := '0';
    if r.timer(7 downto 6)="10" or r.timer(7 downto 6)="01" then
      v.strobeh := '1';
      if r.state=s_stopped then
        v.strobel := '1';
      end if;
    end if;
    -- We accept set request while the timer[7:6] is 00 as we're then not in
    -- the middle of transmitting the high bits. Because timer[7:0] is
    -- held at zero in stopped state, the same logic also means we can write
    -- the timer while stopped
    if setsync='0' then
      v.setack := '0';
    end if;
    if setsync='1' and (asyncset=0 or (r.setack='0' and r.timer(7 downto 6)="00")) then
      v.setack := '1';
      v.timer(62 downto 8) := setvalg(62 downto 8);
      if r.state=s_stopped then
        -- We allow also setting the low bits in stopped state but not while
        -- running as it might clash with the LSB:s wrapping
        v.tloout := setvalg(7 downto 0);
      end if;
    end if;
    if rstn='0' then
      v.state := s_stopped;
      v.timer := (others => '0');
      v.tloout := (others => '0');
      v.setack := '0';
    end if;
    nr <= v;
    tsc <= otsc;
  end process;

  regs: process(clk)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
  end process;

end;





library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.stdlib.all;
library gaisler;
use gaisler.l5nv_shared.all;

entity l5tscsink is
  generic (
    tech   : integer;
    nsync  : integer;
    tbits  : integer
    );
  port (
    clk    : in std_ulogic;
    rstn   : in std_ulogic;
    tsc    : in l5_tsc_async_type;
    timer  : out std_logic_vector(tbits-1 downto 0)
    );
end;

architecture rtl of l5tscsink is

  type l5tscsink_regs is record
    loupipe: std_logic_vector(1 downto 0);
    incpipe: std_logic_vector(2 downto 0);
    tlo: std_logic_vector(7 downto 0);
    thi: std_logic_vector(tbits-1 downto 8);
  end record;

  signal r,nr: l5tscsink_regs;

  signal strobesync: std_logic_vector(1 downto 0);
  signal ntschi, tschiq: std_logic_vector(tbits-1 downto 8);
  signal ntsclo, tscloq: std_logic_vector(7 downto 0);

begin

  srsh: syncreg
    generic map (tech => tech, stages  => nsync)
    port map (clk => clk, d => tsc.strobeh, q => strobesync(1));
  srsl: syncreg
    generic map (tech => tech, stages  => nsync)
    port map (clk => clk, d => tsc.strobel, q => strobesync(0));

  ntschi <= not tsc.tschi(tbits-1 downto 8);
  ntsclo <= not tsc.tsclo;
  gglooph: for x in tbits-1 downto 8 generate
    n: grnand2
      generic map (tech => tech)
      port map (i0 => ntschi(x), i1 => strobesync(1), q => tschiq(x));
  end generate;
  ggloopl: for x in 7 downto 0 generate
    n: grnand2
      generic map (tech => tech)
      port map (i0 => ntsclo(x), i1 => strobesync(0), q => tscloq(x));
  end generate;

  comb: process(rstn,tsc,r,strobesync,tschiq,tscloq)
    variable v: l5tscsink_regs;
    variable oggen: std_ulogic;
    variable oinc: std_ulogic;
  begin
    v := r;
    v.loupipe := tsc.loupd;
    v.incpipe := tsc.incval;
    if r.loupipe(1)='1' then
      v.tlo := (others => '0');
      v.tlo(2 downto 0) := r.incpipe;
    elsif r.loupipe(0)='1' then
      v.tlo := std_logic_vector(unsigned(v.tlo)+unsigned(r.incpipe)+1);
    end if;
    if r.loupipe="11" then
      v.thi := add(r.thi, 1);
    end if;
    if strobesync(1)='1' then
      v.thi := tschiq;
    end if;
    if strobesync(0)='1' then
      v.tlo := tscloq;
    end if;
    if rstn='0' then
      v.tlo := (others => '0');
      v.thi := (others => '0');
    end if;
    nr <= v;
    timer <= r.thi & r.tlo;
  end process;

  regs: process(clk)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
  end process;
end;
