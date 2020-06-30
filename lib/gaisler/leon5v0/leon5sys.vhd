------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.leon5.all;
use gaisler.leon5int.all;
use gaisler.uart.all;
use gaisler.misc.all;

entity leon5sys is
  generic (
    fabtech : integer;
    memtech : integer;
    ncpu    : integer;
    nextmst : integer;
    nextslv : integer;
    nextapb : integer;
    ndbgmst : integer;
    cached  : integer;
    wbmask  : integer;
    busw    : integer;
    memmap  : integer;
    rfconf  : integer;
    cmemconf: integer;
    fpuconf : integer;
    mulimpl : integer;
    disas   : integer;
    ahbtrace: integer;
    devid   : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    -- AHB bus interface for other masters (DMA units)
    ahbmi    : out ahb_mst_in_type;
    ahbmo    : in  ahb_mst_out_vector_type(ncpu+nextmst-1 downto ncpu);
    -- AHB bus interface for slaves (memory controllers, etc)
    ahbsi    : out ahb_slv_in_type;
    ahbso    : in  ahb_slv_out_vector_type(nextslv-1 downto 0);
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
    uarto    : out uart_out_type
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
  signal cpuapbi : apb_slv_in_type;
  signal cpuapbo : apb_slv_out_vector;
  signal gpti    : gptimer_in_type;
  signal gpto    : gptimer_out_type;
  signal tstop   : std_ulogic;
  signal maskerrn: std_logic_vector(0 to NCPU-1);
  signal xuarti  : uart_in_type;
  signal xuarto  : uart_out_type;

  type memmap_table is array(0 to 1) of integer;
  constant haddr_apbctrl : memmap_table := (16#800#,   16#FF9#);
  constant haddr_dsu     : memmap_table := (16#900#,   16#E00#);
  constant rstaddr_cpu   : memmap_table := (16#00000#, 16#C0000#);
  constant paddr_uart    : memmap_table := (16#001#,   16#000#);
  constant paddr_irqmp   : memmap_table := (16#002#,   16#040#);
  constant paddr_timer   : memmap_table := (16#003#,   16#080#);

begin

  ----------------------------------------------------------------------------
  -- AMBA bus fabric
  ----------------------------------------------------------------------------
  ac0: ahbctrl
    generic map (
      rrobin   => 1,
      nahbm    => ncpu+nextmst+1,
      nahbs    => nextslv+1,
      ahbtrace => ahbtrace,
      fpnpen   => 1,
      debug    => 0,
      devid    => devid
      )
    port map (
      rst  => rstn,
      clk  => clk,
      msti => cpumi,
      msto => cpumo,
      slvi => cpusi,
      slvo => cpuso
      );

  ahbmi <= cpumi;
  cpumo(ncpu+nextmst-1 downto ncpu) <= ahbmo;
  cpumo(cpumo'high downto ncpu+nextmst+1) <= (others => ahbm_none);
  ahbsi <= cpusi;
  cpuso(nextslv-1 downto 0) <= ahbso;
  cpuso(cpuso'high downto nextslv+1) <= (others => ahbs_none);

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
      ahbi => cpusi,
      ahbo => cpuso(nextslv),
      apbi => cpuapbi,
      apbo => cpuapbo
      );

  apbi <= cpuapbi;
  cpuapbo(0 to nextapb-1) <= apbo(0 to nextapb-1);
  cpuapbo(nextapb+3 to cpuapbo'high) <= (others => apb_none);

  ----------------------------------------------------------------------------
  -- Processor(s)
  ----------------------------------------------------------------------------
  cpuloop: for c in 0 to ncpu-1 generate
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
        mulimpl  => mulimpl,
        rstaddr  => rstaddr_cpu(memmap),
        disas    => disas
        )
      port map (
        clk   => clk,
        rstn  => cpurstn(c),
        ahbi  => cpumi,
        ahbo  => cpumo(c),
        ahbsi => cpusi,
        ahbso => cpuso,
        irqi  => irqi(c),
        irqo  => irqo(c),
        dbgi  => dbgi(c),
        dbgo  => dbgo(c),
        tpo.tdata   => tpi(c).tdata,
        fpuo  => fpuo(c),
        fpui  => fpui(c)
      );
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
      dsuslvidx => nextslv+1,
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
      cpusi    => cpusi,
      dsuen    => dsuen,
      dsubreak => dsubreak,
      dbgi     => dbgi,
      dbgo     => dbgo,
      itod     => itod,
      dtoi     => dtoi,
      tpi      => tpi,
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
      apbi => cpuapbi,
      apbo => cpuapbo(nextapb),
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
      apbi => cpuapbi,
      apbo => cpuapbo(nextapb+1),
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
      apbi => cpuapbi,
      apbo => cpuapbo(nextapb+2),
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
    variable intext: string(1 to 3);
    variable startaddr, endaddr, scanpos, scanend: std_logic_vector(31 downto 0);
    variable found: boolean;
    variable apbmode: boolean;
  begin
    wait for 10 ns;
    grlib.stdlib.print("leon5sys: LEON5 subsystem with " & grlib.stdlib.tost(ncpu) & " cores");
    grlib.stdlib.print("leon5sys: ---------------------------------------------------");
    grlib.stdlib.print("leon5sys:   Debug masters:");
    for x in 0 to ndbgmst-1 loop
      vendor := dbgmo(x).hconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device := dbgmo(x).hconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      grlib.stdlib.print("leon5sys:     " & tostw(x,3,true) & " ext " &
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    grlib.stdlib.print("leon5sys:   CPU bus masters:");
    for x in 0 to ncpu+nextmst loop
      vendor := cpumo(x).hconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device := cpumo(x).hconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      if x>=ncpu and x<ncpu+nextmst then intext:="ext"; else intext:="int"; end if;
      grlib.stdlib.print("leon5sys:     " & tostw(x,3,true) & " " & intext & " " &
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    grlib.stdlib.print("leon5sys:   CPU bus slaves:");
    for x in 0 to nextslv loop
      vendor := cpuso(x).hconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device := cpuso(x).hconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      if x<nextslv then intext:="ext"; else intext:="int"; end if;
      grlib.stdlib.print("leon5sys:     " & tostw(x,3,true) & " " & intext & " " &
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    grlib.stdlib.print("leon5sys:   APB bus slaves:");
    for x in 0 to nextapb+2 loop
      vendor := cpuapbo(x).pconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device := cpuapbo(x).pconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      if x<nextapb then intext:="ext"; else intext:="int"; end if;
      grlib.stdlib.print("leon5sys:     " & tostw(x,3,true) & " " & intext & " " &
                         grlib.devices.iptable(vendori).device_table(devicei));
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
        for x in 0 to nextslv loop
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
              if x=nextslv then apbmode:=true; next oloop; end if;
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
