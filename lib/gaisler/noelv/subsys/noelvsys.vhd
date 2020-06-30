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
-- Author:      Nils Wessman, Cobham Gaisler
-- Description: NOEL-V processor system (CPUs,FPUs,DM,CLINT,PLIC,UART,AMBA)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.noelvint.all;
use gaisler.noelv.all;
use gaisler.plic.all;
use gaisler.riscv.all;

entity noelvsys is
  generic (
    fabtech  : integer;
    memtech  : integer;
    mularch  : integer;
    ncpu     : integer;
    nextmst  : integer;
    nextslv  : integer;
    nextapb  : integer;
    ndbgmst  : integer;
    cached   : integer;
    wbmask   : integer;
    busw     : integer;
    cmemconf : integer;
    fpuconf  : integer;
    disas    : integer;
    ahbtrace : integer;
    cfg      : integer;
    devid    : integer;
    version  : integer;
    revision : integer;
    nodbus   : integer
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
    apbi     : out apb_slv_in_vector;
    apbo     : in  apb_slv_out_vector;
    -- Bootstrap signals
    dsuen    : in  std_ulogic;
    dsubreak : in  std_ulogic;
    cpu0errn : out std_ulogic;
    -- UART connection
    uarti    : in  uart_in_type;
    uarto    : out uart_out_type;
    -- Perf counter
    cnt      : out nv_counter_out_vector(ncpu-1 downto 0)
    );
end;

architecture hier of noelvsys is

  signal cpumi   : ahb_mst_in_type;
  signal cpumo   : ahb_mst_out_vector;
  signal cpusi   : ahb_slv_in_type;
  signal cpuso   : ahb_slv_out_vector;
  signal irqi    : nv_irq_in_vector(0 to ncpu-1);
  signal irqo    : nv_irq_out_vector(0 to ncpu-1);
  signal dbgi    : nv_debug_in_vector(0 to ncpu-1);
  signal dbgo    : nv_debug_out_vector(0 to ncpu-1);
  signal fpui    : grfpu5_in_vector(0 to ncpu-1);
  signal fpuo    : grfpu5_out_vector(0 to ncpu-1);
  signal cpuapbi : apb_slv_in_vector;
  signal cpuapbo : apb_slv_out_vector;
  signal gpti    : gptimer_in_type;
  signal gpto    : gptimer_out_type;
  signal tstop   : std_ulogic;
  signal xuarto  : uart_out_type;
  -- No bridge config
  signal spapbi  : apb_slv_in_type;
  signal dbgmo_x : ahb_mst_out_vector_type(ndbgmst-1 downto 0);
  -- Debug bus
  signal dbgahbmi: ahb_mst_in_type;
  signal dbgahbmo: ahb_mst_out_vector;
  signal dbgsi   : ahb_slv_in_type;
  signal dbgso   : ahb_slv_out_vector;
  -- PLIC => CLINT
  signal eip    : std_logic_vector(ncpu*4-1 downto 0);
  -- Real Time Clock
  signal rtc    : std_ulogic := '0';
  -- Trace buffer
  signal trace_ahbsiv     : ahb_slv_in_vector_type(0 to 1);
  signal trace_ahbmiv     : ahb_mst_in_vector_type(0 to 1);

  signal dsui           : nv_dm_in_type;
  signal dsuo           : nv_dm_out_type;
  signal nolock         : ahb2ahb_ctrl_type;
  signal noifctrl       : ahb2ahb_ifctrl_type;

  constant scantest : integer := 0;
begin

  ----------------------------------------------------------------------------
  -- AMBA bus fabric
  ----------------------------------------------------------------------------
  ac0: ahbctrl
    generic map (
      devid    => devid,
      ioaddr   => 16#FFE# + nodbus,
      rrobin   => 1,
      split    => 1,
      nahbm    => ncpu+nextmst+1+(nodbus*(ndbgmst-1)),
      nahbs    => nextslv+1+2+(nodbus*4),
      fpnpen   => 1,
      shadow   => 1,
      ahbtrace => ahbtrace
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
  dbgmst_to_dbg : if nodbus = 0 generate
    cpumo(cpumo'high downto ncpu+nextmst+1) <= (others => ahbm_none);
  end generate;
  dbgmst_to_cpu : if nodbus /= 0 generate
    cpumo(ncpu+nextmst+ndbgmst-1 downto ncpu+nextmst) <= dbgmo_x(ndbgmst-1 downto 0);
    cpumo(cpumo'high downto ncpu+nextmst+ndbgmst) <= (others => ahbm_none);
    patch_dbg_index : process(dbgmo, cpumi)
    begin
      for i in dbgmo'range loop
        dbgmo_x(i) <= dbgmo(i);
        dbgmo_x(i).hindex <= ncpu+nextmst+i;
      end loop;
      for i in dbgmi'range loop
        dbgmi(i) <= cpumi;
        dbgmi(i).hgrant(i) <= cpumi.hgrant(ncpu+nextmst+i);
      end loop;
    end process;
  end generate;

  ahbsi <= cpusi;
  cpuso(nextslv-1 downto 0) <= ahbso;
  dbgslv_to_dbg : if nodbus = 0 generate
    cpuso(cpuso'high downto nextslv+1+2) <= (others => ahbs_none);
  end generate;
  dbgslv_to_cpu : if nodbus /= 0 generate
    cpuso(nextslv+1+2+4-1 downto nextslv+1+2) <= dbgso(3 downto 0);
    cpuso(cpuso'high downto nextslv+1+2+4) <= (others => ahbs_none);
    dbgsi <= cpusi;
    dbgso(2) <= ahbs_none;
  end generate;

  dual_apb_gen : if nodbus = 0 generate
    ap0: apbctrldp
      generic map (
        hindex0 => nextslv,
        haddr0  => 16#800#,
        hmask0  => 16#fff#,
        hindex1 => 1,
        haddr1  => 16#800#,
        hmask1  => 16#fff#,
        nslaves => nextapb+3
        )
      port map (
        rst  => rstn,
        clk  => clk,
        ahb0i => cpusi,
        ahb0o => cpuso(nextslv),
        ahb1i => dbgsi,
        ahb1o => dbgso(1),
        apbi => cpuapbi,
        apbo => cpuapbo
        );
  end generate;
  no_dual_apb_gen : if nodbus /= 0 generate
    ap0: apbctrl
      generic map (
        hindex => nextslv,
        haddr  => 16#800#,
        hmask  => 16#fff#,
        nslaves => nextapb+3
        )
      port map (
        rst  => rstn,
        clk  => clk,
        ahbi => cpusi,
        ahbo => cpuso(nextslv),
        apbi => spapbi,
        apbo => cpuapbo
        );
        cpuapbi  <= (others => spapbi);
        dbgso(1) <= ahbs_none;
  end generate;

  apbi(0 to nextapb-1) <= cpuapbi(0 to nextapb-1);
  cpuapbo(0 to nextapb-1) <= apbo(0 to nextapb-1);
  cpuapbo(nextapb+3 to cpuapbo'high) <= (others => apb_none);

  ----------------------------------------------------------------------------
  -- Processor(s)
  ----------------------------------------------------------------------------
  cpuloop: for c in 0 to ncpu-1 generate
    core: noelvcpu
      generic map (
        hindex   => c,
        fabtech  => fabtech,
        memtech  => memtech,
        mularch  => mularch,
        cached   => cached,
        wbmask   => wbmask,
        busw     => busw,
        cmemconf => cmemconf,
        fpuconf  => fpuconf,
        disas    => disas,
        pbaddr   => 16#90000#,
        cfg      => cfg)
      port map (
        clk   => clk,
        rstn  => rstn,
        ahbi  => cpumi,
        ahbo  => cpumo(c),
        ahbsi => cpusi,
        ahbso => cpuso,
        irqi  => irqi(c),
        irqo  => irqo(c),
        dbgi  => dbgi(c),
        dbgo  => dbgo(c),
        fpuo  => fpuo(c),
        fpui  => fpui(c),
        cnt   => cnt(c)
      );
  end generate;
  cpu0errn <= not dbgo(0).error;

  ----------------------------------------------------------------------------
  -- Debug and tracing module
  ----------------------------------------------------------------------------
  dm0 : rvdm -- NOEL-V Debug Support Unit
    generic map(
      hindex          => 0+(nodbus*(nextslv+1+2)),
      haddr           => 16#900#,
      hmask           => 16#F00#,
      nharts          => ncpu,
      tbits           => 30,
      tech            => memtech,
      kbytes          => 2
      )
    port map(
      rst             => rstn,
      clk             => clk,
      ahbmi           => cpumi,
      ahbsi           => dbgsi,
      ahbso           => dbgso(0),
      dbgi            => dbgo,
      dbgo            => dbgi,
      dsui            => dsui,
      dsuo            => dsuo
      );
--dbgso(0) <= ahbs_none;
--cpumo(0) <= ahbm_none;

  dsui.enable <= dsuen;
  dsui.break  <= dsubreak;

  ahbtrace0: ahbtrace_mmb
    generic map (
      hindex  => 3+(nodbus*(nextslv+1+2)),
      ioaddr  => 16#000#,
      iomask  => 16#E00#,
      tech    => memtech,
      irq     => 0,
      kbytes  => 2,
      bwidth  => 128,
      ahbfilt => 2,
      ntrace  => 2,
      exttimer => 0,
      exten    => 0)
    port map(
      rst     => rstn,
      clk     => clk,
      ahbsi   => dbgsi,
      ahbso   => dbgso(3),
      tahbmiv => trace_ahbmiv,
      tahbsiv => trace_ahbsiv
    );

  -- Bus select for ahb trace
  -- 0 : Processor bus
  -- 1 : Debug bus
  traceconn: process(cpumi, dbgahbmi, cpusi, dbgsi)
    variable ahbsiv  : ahb_slv_in_vector_type(0 to 3);
    variable ahbmiv  : ahb_mst_in_vector_type(0 to 3);
  begin
    ahbmiv(0) := cpumi;     ahbsiv(0) := cpusi;
    ahbmiv(1) := dbgahbmi;  ahbsiv(1) := dbgsi;
    trace_ahbmiv <= ahbmiv(0 to 1);
    trace_ahbsiv <= ahbsiv(0 to 1);
  end process;

  dbgbus_gen : if nodbus = 0 generate
    -- AHB controller for debug bus
    ac1: ahbctrl
      generic map (
        devid    => devid,
        ioaddr   => 16#FFF#,
        rrobin   => 1,
        split    => 1,
        nahbm    => ndbgmst,
        nahbs    => 4,
        fpnpen   => 1,
        shadow   => 1,
        ahbtrace => ahbtrace
        )
      port map (
        rst  => rstn,
        clk  => clk,
        msti => dbgahbmi,
        msto => dbgahbmo,
        slvi => dbgsi,
        slvo => dbgso
        );

    dbgso(dbgso'high downto 4) <= (others => ahbs_none);
    dbgahbmo(ndbgmst-1 downto 0) <= dbgmo(ndbgmst-1 downto 0);
    dbgahbmo(dbgahbmo'high downto ndbgmst) <= (others => ahbm_none);
    dbgmi(ndbgmst-1 downto 0) <= (others => dbgahbmi);

    -- AHB/AHB bridge from debug => CPU bus

    nolock <= ahb2ahb_ctrl_none;
    noifctrl <= ahb2ahb_ifctrl_none;

    debug_bridge: ahb2ahb
      generic map (
        memtech     => inferred,
        hsindex     => 2,
        hmindex     => ncpu+nextmst,
        slv         => 1,
        dir         => 1,
        ffact       => 1,
        pfen        => 1,
        wburst      => 4,
        iburst      => 4,
        rburst      => 4,
        irqsync     => 0,
        bar0        => ahb2ahb_membar(16#000#, '1', '1', 16#800#),
        bar1        => ahb2ahb_membar(16#800#, '0', '0', 16#F00#),
        bar2        => ahb2ahb_membar(16#E00#, '0', '0', 16#E00#),
        bar3        => 0,
        sbus        => 1,
        mbus        => 0,
        ioarea      => 16#FFE#,
        ibrsten     => 0,
        lckdac      => 0,
        slvmaccsz   => 32,
        mstmaccsz   => 32,
        rdcomb      => 0,
        wrcomb      => 0,
        combmask    => 0,
        allbrst     => 0,
        ifctrlen    => 0,
        fcfs        => 0,
        fcfsmtech   => 0,
        scantest    => scantest,
        split       => 1)
      port map (
        rstn        => rstn,
        hclkm       => clk,
        hclks       => clk,
        ahbsi       => dbgsi,
        ahbso       => dbgso(2),
        ahbmi       => cpumi,
        ahbmo       => cpumo(ncpu+nextmst),
        ahbso2      => cpuso,
        lcki        => nolock,
        lcko        => open,
        ifctrl      => noifctrl);
  end generate;

  ----------------------------------------------------------------------------
  -- Standard UART
  ----------------------------------------------------------------------------
  uart0: apbuart
    generic map (
      pindex => nextapb,
      paddr => 16#001#,
      pmask => 16#fff#,
      console => 1,
      pirq => 1,
      parity => 1,
      flow => 1,
      fifosize => 8,
      abits => 8,
      sbits => 12
      )
    port map (
      rst => rstn,
      clk => clk,
      apbi => cpuapbi(nextapb),
      apbo => cpuapbo(nextapb),
      uarti => uarti,
      uarto => xuarto
      );
  uarto <= xuarto;

--pragma translate_off
--pragma translate_on

  ----------------------------------------------------------------------------
  -- Version
  ----------------------------------------------------------------------------
  grver0 : grversion
    generic map(
      pindex      => nextapb+1,
      paddr       => 16#002#,
      pmask       => 16#FFF#,
      versionnr   => version,
      revisionnr  => revision)
    port map(
      rstn  => rstn,
      clk   => clk,
      apbi  => cpuapbi(nextapb+1),
      apbo  => cpuapbo(nextapb+1));

  ----------------------------------------------------------------------------
  -- Timer
  ----------------------------------------------------------------------------
  gpt0: gptimer
    generic map (
      pindex  => nextapb+2,
      paddr   => 16#003#,
      pmask   => 16#fff#,
      pirq    => 2,
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
      apbi => cpuapbi(nextapb+2),
      apbo => cpuapbo(nextapb+2),
      gpti => gpti,
      gpto => gpto
      );

  gpti <= (
    dhalt =>  dbgo(0).stoptime,
    extclk => '0',
    wdogen => '0',
    latchv => (others => '0'),
    latchd => (others => '0')
    );

  ----------------------------------------------------------------------------
  -- Interrupt controller
  ----------------------------------------------------------------------------

  -- CLINT -----------------------------------------------------------
  clint0 : clint_ahb
    generic map (
      hindex    => nextslv+1,
      haddr     => 16#E01#,
      hmask     => 16#FFF#,
      ncpu      => ncpu
      )
    port map (
      rst       => rstn,
      clk       => clk,
      rtc       => rtc,
      ahbi      => cpusi,
      ahbo      => cpuso(nextslv+1),
      halt      => dbgo(0).stoptime,
      irqi      => eip,
      irqo      => irqi
      );

  rtc0 : process(clk)
  begin
    if rising_edge(clk) then
      rtc <= not rtc;
      if rstn = '0' then
        rtc <= '0';
      end if;
    end if;
  end process;

  -- GRPLIC -----------------------------------------------------------
  grplic0 : grplic_ahb
    generic map (
      hindex            => nextslv+2,
      haddr             => 16#840#,
      hmask             => 16#FC0#,
      nsources          => NAHBIRQ,
      ncpu              => ncpu,
      priorities        => 8,
      pendingbuff       => 8,
      irqtype           => 0,
      thrshld           => 1
      )
    port map (
      rst               => rstn,
      clk               => clk,
      ahbi              => cpusi,
      ahbo              => cpuso(nextslv+2),
      irqo              => eip
      );


end;
