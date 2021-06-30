------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
-- Entity:      leon5sys
-- File:        leon5sys.vhd
-- Author:      Magnus Hjorth, Cobham Gaisler
-- Description: LEON5 processor system (CPUs,FPUs,DSU,IRQC,Timer,UART,AMBA)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.config.all;
use grlib.config_types.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.leon5.all;
use gaisler.leon5int.all;
use gaisler.uart.all;
use gaisler.misc.all;

entity leon5sys is
  generic (
    fabtech  : integer;
    memtech  : integer;
    ncpu     : integer;
    nextmst  : integer;
    nextslv  : integer;
    nextapb  : integer;
    ndbgmst  : integer;
    cached   : integer;
    wbmask   : integer;
    busw     : integer;
    memmap   : integer;
    ahbsplit : integer;
    rfconf   : integer;
    cmemconf : integer;
    fpuconf  : integer;
    tcmconf  : integer;
    perfcfg  : integer;
    mulimpl  : integer;
    statcfg  : integer;
    disas    : integer;
    ahbtrace : integer;
    devid    : integer;
    cgen     : integer;
    scantest : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    -- Clock gating support
    gclk     : in  std_logic_vector(0 to ncpu-1);
    gclken   : out std_logic_vector(0 to ncpu-1);
    -- AHB bus interface for other masters (DMA units)
    ahbmi    : out ahb_mst_in_type;
    ahbmo    : in  ahb_mst_out_vector_type(ncpu+nextmst-1 downto ncpu);
    -- AHB bus interface for slaves (memory controllers, etc)
    ahbsi    : out ahb_slv_in_type;
    ahbso    : in  ahb_slv_out_vector_type(nextslv-1 downto 0);
    ahbpnp   : out ahb_config_array;
    -- AHB master interface for debug links
    dbgmi    : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
    dbgmo    : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
    -- APB interface for external APB slaves
    apbi     : out apb_slv_in_type;
    apbo     : in  apb_slv_out_vector;
    -- Bootstrap signals
    dsuen    : in  std_ulogic;
    dsubreak : in  std_ulogic;
    cpu0errn : out std_ulogic;
    -- UART connection
    uarti    : in  uart_in_type;
    uarto    : out uart_out_type;
    -- DFT signals propagating to ahbctrl
    testen   : in  std_ulogic;
    testrst  : in  std_ulogic;
    scanen   : in  std_ulogic;
    testoen  : in  std_ulogic;
    testsig  : in  std_logic_vector(1+GRLIB_CONFIG_ARRAY(grlib_techmap_testin_extra) downto 0)
    );
end;

architecture hier of leon5sys is

  signal cpurstn : std_logic_vector(0 to ncpu-1);
  signal cpumi   : ahb_mst_in_type;
  signal cpumo   : ahb_mst_out_vector;
  signal cpusi   : ahb_slv_in_type;
  signal cpuso   : ahb_slv_out_vector;
  signal irqi    : l5_irq_in_vector(0 to ncpu-1);
  signal irqo    : l5_irq_out_vector(0 to ncpu-1);
  signal itod    : l5_irq_dbg_vector(0 to ncpu-1);
  signal dtoi    : l5_dbg_irq_vector(0 to ncpu-1);
  signal dbgi    : l5_debug_in_vector(0 to ncpu-1);
  signal dbgo    : l5_debug_out_vector(0 to ncpu-1);
  signal fpui    : grfpu5_in_vector(0 to ncpu-1);
  signal fpuo    : grfpu5_out_vector(0 to ncpu-1);
  signal tpi     : trace_port_in_vector(0 to NCPU-1);
  signal tco     : trace_control_out_vector(0 to NCPU-1);
  signal cpuapbi : apb_slv_in_type;
  signal cpuapbo : apb_slv_out_vector;
  signal gpti    : gptimer_in_type;
  signal gpto    : gptimer_out_type;
  signal tstop   : std_ulogic;
  signal maskerrn: std_logic_vector(0 to NCPU-1);
  signal xuarti  : uart_in_type;
  signal xuarto  : uart_out_type;
  signal perf    : leon5_perf_array;

  signal cpusix: ahb_slv_in_type;
  signal ahbso_apbctrl : ahb_slv_out_type;
  signal cpuapbix: apb_slv_in_type;
  signal apbo_uart, apbo_timer, apbo_irqmp : apb_slv_out_type;

  type memmap_table is array(0 to 1) of integer;
  constant haddr_apbctrl : memmap_table := (16#800#,   16#FF9#);
  constant haddr_dsu     : memmap_table := (16#900#,   16#E00#);
  constant rstaddr_cpu   : memmap_table := (16#00000#, 16#C0000#);
  constant paddr_uart    : memmap_table := (16#001#,   16#000#);
  constant paddr_irqmp   : memmap_table := (16#002#,   16#040#);
  constant paddr_timer   : memmap_table := (16#003#,   16#080#);
  -- set to 1 to put apbctrl first in AHB PnP and shift slaves up by 1
  constant apbctrlfirst  : memmap_table := (1,         1);
  -- set to 1 to put timer/irqmp/uart first in the APB PnP
  constant stdperfirst   : memmap_table := (1,         1);

  type statcfg_table is array(0 to 3) of integer;
  constant l5st_en_tbl   : statcfg_table := (0,        1,          1,         1);
  constant l5swidth      : statcfg_table := (16,      16,         32,        48);

  constant l5st_en : integer := l5st_en_tbl(statcfg);


  -- Helper functions to shuffle PnP entries
  function replace_hindex(x: ahb_slv_out_type; hindex: integer) return ahb_slv_out_type is
    variable r: ahb_slv_out_type;
  begin
    r := x;
    r.hindex := hindex;
    return r;
  end replace_hindex;
  function replace_pindex(x: apb_slv_out_type; pindex: integer) return apb_slv_out_type is
    variable r: apb_slv_out_type;
  begin
    r := x;
    r.pindex := pindex;
    return r;
  end replace_pindex;
  function shift_psel(x: apb_slv_in_type; nshift: integer; nslaves: integer) return apb_slv_in_type is
    variable r: apb_slv_in_type;
  begin
    r := x;
    for i in 0 to nslaves-1 loop
      r.psel(i) := x.psel((nslaves+i+nshift) mod nslaves);
    end loop;
    return r;
  end shift_psel;
  function shift_hsel(x: ahb_slv_in_type; nshift: integer; nslaves: integer) return ahb_slv_in_type is
    variable r: ahb_slv_in_type;
  begin
    r := x;
    for i in 0 to nslaves-1 loop
      r.hsel(i) := x.hsel((nslaves+i+nshift) mod nslaves);
    end loop;
    return r;
  end shift_hsel;

  function l5stat_pipe_func(ncores: integer) return integer is
  begin
    if ncores > 2 then
      return 2;
    else
      return 1;
    end if;
  end;
  constant l5stat_pipe: integer := l5stat_pipe_func(ncpu);

begin

  ----------------------------------------------------------------------------
  -- AMBA bus fabric
  ----------------------------------------------------------------------------
  ac0: ahbctrl
    generic map (
      rrobin    => 1,
      nahbm     => ncpu+nextmst+1,
      nahbs     => nextslv+1+l5st_en,
      ahbtrace  => ahbtrace,
      fpnpen    => 1,
      debug     => 0,
      devid     => devid,
      ahbendian => 0,
      split     => ahbsplit,
      ioen      => 1,
      ioaddr    => 16#FFF#
      )
    port map (
      rst  => rstn,
      clk  => clk,
      msti => cpumi,
      msto => cpumo,
      slvi => cpusi,
      slvo => cpuso,
      testen  => testen,
      testrst => testrst,
      scanen  => scanen,
      testoen => testoen,
      testsig => testsig
      );

  ahbmi <= cpumi;
  cpumo(ncpu+nextmst-1 downto ncpu) <= ahbmo;
  cpumo(cpumo'high downto ncpu+nextmst+1) <= (others => ahbm_none);
  noshift: if apbctrlfirst(memmap)=0 generate
    ahbsi <= cpusi;
    cpusix <= cpusi;
    cpuso(nextslv-1 downto 0) <= ahbso;
    cpuso(nextslv) <= ahbso_apbctrl;
  end generate;
  dorot: if apbctrlfirst(memmap)/=0 generate
    ahbsi <= shift_hsel(cpusi,1,nextslv+1);
    cpusix <= shift_hsel(cpusi,1,nextslv+1);
    cpuso(0) <= replace_hindex(ahbso_apbctrl,0);
    genrot: for i in 1 to nextslv generate
      cpuso(i) <= replace_hindex(ahbso(i-1),i);
    end generate;
  end generate;
  cpuso(cpuso'high downto nextslv+1+l5st_en) <= (others => ahbs_none);

  ap0: apbctrl
    generic map (
      hindex  => nextslv,
      haddr   => haddr_apbctrl(memmap),
      hmask   => 16#fff#,
      nslaves => nextapb+3,
      debug   => 0
      )
    port map (
      rst  => rstn,
      clk  => clk,
      ahbi => cpusix,
      ahbo => ahbso_apbctrl,
      apbi => cpuapbi,
      apbo => cpuapbo
      );

  noshiftapb: if stdperfirst(memmap)=0 and nextapb>0 generate
    apbi <= cpuapbi;
    cpuapbix <= cpuapbi;
    cpuapbo(0 to nextapb-1) <= apbo(0 to nextapb-1);
  end generate;
  doshiftapb: if stdperfirst(memmap)/=0 and nextapb>0 generate
    apbi <= shift_psel(cpuapbi,3,nextapb+3);
    cpuapbix <= shift_psel(cpuapbi,3,nextapb+3);
    cpuapbo(0) <= replace_pindex(apbo_uart,  0);
    cpuapbo(1) <= replace_pindex(apbo_irqmp, 1);
    cpuapbo(2) <= replace_pindex(apbo_timer, 2);
    genrotapb: for i in 3 to nextapb+2 generate
      cpuapbo(i) <= replace_pindex(apbo(i-3),i);
    end generate;
  end generate;
  cpuapbo(nextapb+3 to cpuapbo'high) <= (others => apb_none);

  pnpoutloop: for x in NAHBSLV-1 downto 0 generate
    ahbpnp(x) <= cpuso(x).hconfig;
  end generate;

  ----------------------------------------------------------------------------
  -- Processor(s)
  ----------------------------------------------------------------------------
  cpuloop: for c in 0 to ncpu-1 generate
    nocgcpu: if cgen=0 generate
      core: cpucore5
        generic map (
          hindex   => c,
          fabtech  => fabtech,
          memtech  => memtech,
          cached   => cached,
          wbmask   => wbmask,
          busw     => busw,
          cmemconf => cmemconf,
          rfconf   => rfconf,
          fpuconf  => fpuconf,
          tcmconf  => tcmconf,
          perfcfg  => perfcfg,
          mulimpl  => mulimpl,
          rstaddr  => rstaddr_cpu(memmap),
          disas    => disas,
          scantest => scantest,
          cgen     => cgen
          )
        port map (
          clk   => clk,
          rstn  => cpurstn(c),
          gclk  => clk,
          gclken => open,
          ahbi  => cpumi,
          ahbo  => cpumo(c),
          ahbsi => cpusix,
          ahbso => cpuso,
          irqi  => irqi(c),
          irqo  => irqo(c),
          dbgi  => dbgi(c),
          dbgo  => dbgo(c),
          tpo.tdata   => tpi(c).tdata,
          tco   => tco(c),
          fpuo  => fpuo(c),
          fpui  => fpui(c),
          perf  => perf(c)
          );
      gclken <= (others => '1');
    end generate;
    cgcpu: if cgen/=0 generate
      core: cpucore5
        generic map (
          hindex   => c,
          fabtech  => fabtech,
          memtech  => memtech,
          cached   => cached,
          wbmask   => wbmask,
          busw     => busw,
          cmemconf => cmemconf,
          rfconf   => rfconf,
          fpuconf  => fpuconf,
          tcmconf  => tcmconf,
          perfcfg  => perfcfg,
          mulimpl  => mulimpl,
          rstaddr  => rstaddr_cpu(memmap),
          disas    => disas,
          scantest => scantest,
          cgen     => cgen
          )
        port map (
          clk   => clk,
          rstn  => cpurstn(c),
          gclk  => gclk(c),
          gclken => gclken(c),
          ahbi  => cpumi,
          ahbo  => cpumo(c),
          ahbsi => cpusix,
          ahbso => cpuso,
          irqi  => irqi(c),
          irqo  => irqo(c),
          dbgi  => dbgi(c),
          dbgo  => dbgo(c),
          tpo.tdata   => tpi(c).tdata,
          tco   => tco(c),
          fpuo  => fpuo(c),
          fpui  => fpui(c),
          perf  => perf(c)
          );
    end generate; 
  end generate;
  cpu0errn <= '0' when dbgo(0).cpustate=CPUSTATE_ERRMODE and maskerrn(0)='0' else '1';
  fpuo <= (others => grfpu5_out_none);

  ----------------------------------------------------------------------------
  -- Debug and tracing module
  ----------------------------------------------------------------------------
  dbgmod: dbgmod5
    generic map (
      memtech => memtech,
      ncpu    => ncpu,
      ndbgmst => ndbgmst,
      busw    => busw,
      cpumidx => ncpu+nextmst,
      dsuhaddr => haddr_dsu(memmap),
      dsuhmask => 16#F00#,
      pnpaddrhi => 16#FFF#,
      pnpaddrlo => 16#FF0#,
      dsuslvidx => nextslv+2,
      dsumstidx => ncpu+nextmst+1
      )
    port map (
      clk      => clk,
      rstn     => rstn,
      cpurstn  => cpurstn,
      dbgmi    => dbgmi,
      dbgmo    => dbgmo,
      cpumi    => cpumi,
      cpumo    => cpumo(ncpu+nextmst),
      cpusi    => cpusix,
      dsuen    => dsuen,
      dsubreak => dsubreak,
      dbgi     => dbgi,
      dbgo     => dbgo,
      itod     => itod,
      dtoi     => dtoi,
      tpi      => tpi,
      tco      => tco,
      tstop    => tstop,
      maskerrn => maskerrn,
      uartie   => uarti,
      uartoe   => uarto,
      uartii   => xuarti,
      uartoi   => xuarto
      );

  ----------------------------------------------------------------------------
  -- Standard UART
  ----------------------------------------------------------------------------
  uart0: apbuart
    generic map (
      pindex => nextapb,
      paddr => paddr_uart(memmap),
      pmask => 16#fff#,
      console => 0,
      pirq => 2,
      parity => 1,
      flow => 1,
      fifosize => 8,
      abits => 8,
      sbits => 12
      )
    port map (
      rst => rstn,
      clk => clk,
      apbi => cpuapbix,
      apbo => apbo_uart,
      uarti => xuarti,
      uarto => xuarto
      );

--pragma translate_off
  up0: gaisler.sim.uartprint port map (xuarto.txd);
--pragma translate_on

  ----------------------------------------------------------------------------
  -- Interrupt controller
  ----------------------------------------------------------------------------
  irqmp0: irqmp5
    generic map (
      pindex  => nextapb+1,
      paddr   => paddr_irqmp(memmap),
      pmask   => 16#fff#,
      ncpu    => ncpu,
      eirq    => 12,
      irqmap  => 0,
      bootreg => 1,
      extrun  => 0
      )
    port map (
      rst  => rstn,
      clk  => clk,
      apbi => cpuapbix,
      apbo => apbo_irqmp,
      irqi => irqo,
      irqo => irqi,
      itod => itod,
      dtoi => dtoi
      );

  ----------------------------------------------------------------------------
  -- Timer
  ----------------------------------------------------------------------------
  gpt0: gptimer
    generic map (
      pindex  => nextapb+2,
      paddr   => paddr_timer(memmap),
      pmask   => 16#fff#,
      pirq    => 8,
      sepirq  => 1,
      sbits   => 16,
      ntimers => 2,
      nbits   => 32,
      wdog    => 0,
      ewdogen => 0,
      glatch  => 0,
      gextclk => 0,
      gset    => 0,
      gelatch => 0,
      wdogwin => 0
      )
    port map (
      rst  => rstn,
      clk  => clk,
      apbi => cpuapbix,
      apbo => apbo_timer,
      gpti => gpti,
      gpto => gpto
      );

  gpti <= (
    dhalt =>  tstop,
    extclk => '0',
    wdogen => '0',
    latchv => (others => '0'),
    latchd => (others => '0')
    );

  ----------------------------------------------------------------------------
  -- L5STAT
  ----------------------------------------------------------------------------
  uperfncpu: if ncpu < 8 generate
    uperf: for i in ncpu to 7 generate
      perf(i) <= (others=>'0');
    end generate;
  end generate;

  l5si:if l5st_en /= 0 generate
    l5s: l5stat
      generic map(
        cnt_width => l5swidth(statcfg),
        ncores    => ncpu,
        ninpipe   => l5stat_pipe,
        hindex    => nextslv+1,
        ioaddr     => 16#F80#)
      port map(
        rstn      => rstn,
        clk       => clk,
        perf      => perf,
        ahbsi     => cpusix,
        ahbso     => cpuso(nextslv+1));
  end generate;
      

  ----------------------------------------------------------------------------
  -- Clock gating unit
  ----------------------------------------------------------------------------
  --  TODO - no clock gating implemented at this time.

  -----------------------------------------------------------------------------
  -- Simulation report
  -----------------------------------------------------------------------------
--pragma translate_off
  simrep: process
    function stradj(s: string; w: integer; rjust: boolean) return string is
      variable r: string(1 to w);
    begin
      r := (others => ' ');
      if rjust then
        r(w-s'length+1 to w) := s;
      else
        r(1 to s'length) := s;
      end if;
      return r;
    end stradj;

    function tostw(i: integer; w: integer; rjust: boolean) return string is
    begin
      return stradj(grlib.stdlib.tost(i),w,rjust);
    end tostw;

    variable vendor: std_logic_vector(7 downto 0);
    variable device: std_logic_vector(11 downto 0);
    variable vendori, devicei: integer;
    variable intext: string(1 to 6);
    variable startaddr, endaddr, scanpos, scanend: std_logic_vector(31 downto 0);
    variable found: boolean;
    variable apbmode: boolean;
  begin
    wait for 10 ns;
    grlib.stdlib.print("leon5sys: LEON5 subsystem with " & grlib.stdlib.tost(ncpu) & " cores");
    grlib.stdlib.print("leon5sys: ---------------------------------------------------");
    grlib.stdlib.print("leon5sys:   Debug masters:");
    for x in 0 to ndbgmst-1 loop
      if is_x(dbgmo(x).hconfig(0)) then
        grlib.stdlib.print("leon5sys:     WARNING: Debug master " & grlib.stdlib.tost(x) & " seems undriven, check VHDL");
      end if;
      vendor := dbgmo(x).hconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device := dbgmo(x).hconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      grlib.stdlib.print("leon5sys:     " & tostw(x,3,true) & " ext#" & tostw(x,2,false) & " " & 
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    grlib.stdlib.print("leon5sys:   CPU bus masters:");
    for x in 0 to ncpu+nextmst loop
      if is_x(cpumo(x).hconfig(0)) then
        grlib.stdlib.print("leon5sys:     WARNING: CPU bus master " & grlib.stdlib.tost(x) & " seems undriven, check VHDL");
      end if;
      vendor := cpumo(x).hconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device := cpumo(x).hconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      if x>=ncpu and x<ncpu+nextmst then intext:="ext#" & tostw(x,2,false); else intext:="int   "; end if;
      grlib.stdlib.print("leon5sys:     " & tostw(x,3,true) & " " & intext & " " &
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    grlib.stdlib.print("leon5sys:   CPU bus slaves:");
    for x in 0 to nextslv+l5st_en loop
      if is_x(cpuso(x).hconfig(0)) then
        grlib.stdlib.print("leon5sys:     WARNING: CPU bus slave " & grlib.stdlib.tost(x) & " seems undriven, check VHDL");
      end if;
      vendor := cpuso(x).hconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device := cpuso(x).hconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      if apbctrlfirst(memmap)=0 then
        if x<nextslv then intext:="ext#" & tostw(x,2,false); else intext:="int   "; end if;
      else
        if x>0 and x<nextslv+1 then intext:="ext#" & tostw(x-1,2,false); else intext:="int   "; end if;
      end if;
      grlib.stdlib.print("leon5sys:     " & tostw(x,3,true) & " " & intext & " " &
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    grlib.stdlib.print("leon5sys:   APB bus slaves:");
    for x in 0 to nextapb+2 loop
      if is_x(cpuapbo(x).pconfig(0)) then
        grlib.stdlib.print("leon5sys:     WARNING: APB bus slave " & grlib.stdlib.tost(x) & " seems undriven, check VHDL");
      end if;
      vendor := cpuapbo(x).pconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device := cpuapbo(x).pconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      if stdperfirst(memmap)=0 then
        if x<nextapb then intext:="ext#" & tostw(x,2,false); else intext:="int   "; end if;
      else
        if x>2 and x<nextapb+3 then intext:="ext#" & tostw(x-3,2,false); else intext:="int   "; end if;
      end if;
      grlib.stdlib.print("leon5sys:     " & tostw(x,3,true) & " " & intext & " " &
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    -- Check index debug signal on external signals (before any internal shuffling)
    for x in ncpu to ncpu+nextmst-1 loop
      assert ahbmo(x).hindex=x or (ahbmo(x).hindex=0 and ahbmo(x).hconfig(0)=x"00000000")
        report "Invalid bus index on ahbmo #" & grlib.stdlib.tost(x)
        severity warning;
    end loop;
    for x in 0 to nextslv-1 loop
      assert ahbso(x).hindex=x or (ahbso(x).hindex=0 and ahbso(x).hconfig(0)=x"00000000")
        report "Invalid bus index on ahbso #" & grlib.stdlib.tost(x)
        severity warning;
    end loop;
    for x in 0 to nextapb-1 loop
      assert apbo(x).pindex=x or (apbo(x).pindex=0 and apbo(x).pconfig(0)=x"00000000")
        report "Invalid bus index on apbo #" & grlib.stdlib.tost(x)
        severity warning;
    end loop;
    grlib.stdlib.print("leon5sys: ---------------------------------------------------");
    grlib.stdlib.print("leon5sys:   Memory map:");
    scanpos := (others => '0');
    apbmode := false;
    oloop: for i in 1 to 100 loop
      found := false;
      if not apbmode then
        scanend := (others => '1');
        -- PnP area
        startaddr := x"FFFFF000";
        endaddr := x"FFFFFFFF";
        if startaddr=scanpos then
          grlib.stdlib.print("leon5sys:     " & grlib.stdlib.tost(startaddr) & "-" &
                             grlib.stdlib.tost(endaddr) & " " & "Plug'n'play table");
          found := true;
          scanend := endaddr;
        elsif not found then
          if unsigned(startaddr)>unsigned(scanpos) and unsigned(startaddr)<unsigned(scanend) then
            scanend := std_logic_vector(unsigned(startaddr)-1);
          end if;
        end if;
        -- Regular slaves
        for x in 0 to nextslv+l5st_en loop
          vendor := cpuso(x).hconfig(0)(31 downto 24);
          vendori := to_integer(unsigned(vendor));
          device := cpuso(x).hconfig(0)(23 downto 12);
          devicei := to_integer(unsigned(device));
          for b in 4 to 7 loop
            if cpuso(x).hconfig(b)(3 downto 0)="0010" and cpuso(x).hconfig(b)(15 downto 4)/=x"000" then
              startaddr(31 downto 20) := cpuso(x).hconfig(b)(31 downto 20);
              startaddr(19 downto 0) := (others => '0');
              endaddr(31 downto 20) := cpuso(x).hconfig(b)(31 downto 20) or not cpuso(x).hconfig(b)(15 downto 4);
              endaddr(19 downto 0)  := (others => '1');
              -- PnP area may shadow
              if unsigned(endaddr) > unsigned'(x"FFFFEFFF") then
                endaddr := x"FFFFEFFF";
              end if;
            elsif cpuso(x).hconfig(b)(3 downto 0)="0011" and cpuso(x).hconfig(b)(15 downto 4)/=x"000" then
              startaddr(31 downto 20) := x"FFF";
              startaddr(19 downto 8)  := cpuso(x).hconfig(b)(31 downto 20);
              endaddr(31 downto 20) := x"FFF";
              endaddr(19 downto 8)  := cpuso(x).hconfig(b)(31 downto 20) or not cpuso(x).hconfig(b)(15 downto 4);
              endaddr(7 downto 0)   := (others=>'1');
            else
              next;
            end if;
            if startaddr=scanpos then
              grlib.stdlib.print("leon5sys:     " & grlib.stdlib.tost(startaddr) & "-" &
                                 grlib.stdlib.tost(endaddr) & " " &
                                 grlib.devices.iptable(vendori).device_table(devicei));
              assert not found report "Multiple mappings!";
              found := true;
              scanend := endaddr;
              if apbctrlfirst(memmap)/=0 then
                if x=0 then apbmode:=true; next oloop; end if;
              else
                if x=nextslv then apbmode:=true; next oloop; end if;
              end if;
            elsif not found then
              if unsigned(startaddr)>unsigned(scanpos) and unsigned(startaddr)<unsigned(scanend) then
                scanend := std_logic_vector(unsigned(startaddr)-1);
              end if;
            end if;
            assert not (unsigned(startaddr)<unsigned(scanpos) and unsigned(endaddr)>unsigned(scanpos))
              report "Overlapping memory mappings!";
          end loop;
        end loop;
        if not found then
          grlib.stdlib.print("leon5sys:     " & grlib.stdlib.tost(scanpos) & "-" &
                             grlib.stdlib.tost(scanend) & " Unmapped AHB space");
        end if;
      else
        scanend := scanpos;
        scanend(19 downto 0) := (others => '1');
        for x in 0 to nextapb+2 loop
          vendor := cpuapbo(x).pconfig(0)(31 downto 24);
          vendori := to_integer(unsigned(vendor));
          device := cpuapbo(x).pconfig(0)(23 downto 12);
          devicei := to_integer(unsigned(device));
          if cpuapbo(x).pconfig(1)(3 downto 0)="0001" then
            startaddr := scanpos;
            startaddr(19 downto 8) := cpuapbo(x).pconfig(1)(31 downto 20);
            startaddr(7 downto 0) := (others => '0');
            endaddr := startaddr;
            endaddr(19 downto 8) := cpuapbo(x).pconfig(1)(31 downto 20) or not cpuapbo(x).pconfig(1)(15 downto 4);
            endaddr(7 downto 0)  := (others => '1');
          else
            next;
          end if;
          if startaddr=scanpos then
            grlib.stdlib.print("leon5sys:       " & grlib.stdlib.tost(startaddr) & "-" &
                               grlib.stdlib.tost(endaddr) & " " &
                               grlib.devices.iptable(vendori).device_table(devicei));
            assert not found report "Multiple mappings!";
            found := true;
            scanend := endaddr;
          elsif not found then
            if unsigned(startaddr)>unsigned(scanpos) and unsigned(startaddr)<unsigned(scanend) then
              scanend := std_logic_vector(unsigned(startaddr)-1);
            end if;
          end if;
          assert not (unsigned(startaddr)<unsigned(scanpos) and unsigned(endaddr)>unsigned(scanpos))
            report "Overlapping memory mappings!";
        end loop;
        if not found then
          grlib.stdlib.print("leon5sys:       " & grlib.stdlib.tost(scanpos) & "-" &
                             grlib.stdlib.tost(scanend) & " Unmapped APB space");
        end if;
        if scanend(19 downto 0)=x"FFFFF" then apbmode:=false; end if;
      end if;
      exit when scanend=(scanend'range => '1');
      scanpos := std_logic_vector(unsigned(scanend)+1);
    end loop;
    grlib.stdlib.print("leon5sys: ---------------------------------------------------");
    wait;
  end process;
--pragma translate_on

end;
