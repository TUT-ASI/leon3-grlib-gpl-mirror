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
-- Entity:      noelvsys
-- File:        noelvsys.vhd
-- Author:      Nils Wessman, Cobham Gaisler
-- Description: NOEL-V processor system (CPUs,FPUs,DM,CLINT,PLIC,UART,AMBA)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.config.all;
use grlib.config_types.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.noelv.all;
use gaisler.plic.all;

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
    rfconf   : integer;
    fpuconf  : integer;
    disas    : integer;
    ahbtrace : integer;
    cfg      : integer;
    devid    : integer;
    nodbus   : integer;
    scantest : integer
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
    cnt      : out nv_counter_out_vector(ncpu-1 downto 0);
    -- DFT support
    testen  : in  std_ulogic := '0';
    testrst : in  std_ulogic := '1';
    scanen  : in  std_ulogic := '0';
    testoen : in  std_ulogic := '1';
    testsig : in  std_logic_vector(1+GRLIB_CONFIG_ARRAY(grlib_techmap_testin_extra) downto 0) := (others => '0')
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

  -- AHB master index
  --constant CPU_HMINDEX    : integer := 0..ncpu-1
  constant AHBB_HMINDEX   : integer := ncpu+nextmst;
  -- AHB slave index
  constant APBC_HINDEX    : integer := nextslv;
  constant CLINT_HINDEX   : integer := nextslv+1;
  constant PLIC_HINDEX    : integer := nextslv+2;
  constant DUMMY_HINDEX   : integer := nextslv+3;
  -- AHB slave address
  constant AHBC_IOADDR    : integer := 16#FFF#; --16#FFE# + nodbus;
  constant PLIC_HADDR     : integer := 16#F80#;
  constant PLIC_HMASK     : integer := 16#FC0#;
  constant CLINT_HADDR    : integer := 16#E00#;
  constant CLINT_HMASK    : integer := 16#FFF#;
  constant DM_HADDR       : integer := 16#FE0#;
  constant DM_HMASK       : integer := 16#FF0#;
  constant AHBT_IOADDR    : integer := 16#000#;
  constant AHBT_IOMASK    : integer := 16#E00#;
  constant APBC_HADDR     : integer := 16#FC0#;
  constant APBC_HMASK     : integer := 16#FFF#;
  constant DUMMY_HADDR    : integer := 16#FFE#;
  -- APB slave index
  constant GPTIME_PINDEX  : integer := nextapb+0;
  constant APBUART_PINDEX : integer := nextapb+1;
  -- APB slave address
  constant GPTIME_PADDR   : integer := 16#000#;
  constant GPTIME_PMASK   : integer := 16#FFF#;
  constant APBUART_PADDR  : integer := 16#010#;
  constant APBUART_PMASK  : integer := 16#FFF#;
  -- Debug bus
  constant DM_DM_HINDEX   : integer := 0+(nodbus*(nextslv+1+2+1));
  constant APBC_DM_HINDEX : integer := 1;
  constant AHBB_DM_HINDEX : integer := 2;
  constant AHBT_DM_HINDEX : integer := 3+(nodbus*(nextslv+1+2+1));
  --
  constant AHBC_DM_IOADDR : integer := 16#FFE#; --16#FFF#;
  constant AHBB_DM_HADDR0 : integer := 16#000#;
  constant AHBB_DM_HMASK0 : integer := 16#800#;
  constant AHBB_DM_HADDR1 : integer := 16#800#;
  constant AHBB_DM_HMASK1 : integer := 16#C00#;
  constant AHBB_DM_HADDR2 : integer := 16#C00#;
  constant AHBB_DM_HMASK2 : integer := 16#E00#;
  constant AHBB_DM_HADDR3 : integer := 16#E00#;
  constant AHBB_DM_HMASK3 : integer := 16#E00#;

  -- IRQ
  constant APBUART_PIRQ   : integer := 1;
  constant GPTIME_PIRQ    : integer := 2; -- , 3
  --constant GPTIME_PIRQ2   : integer := 3;

begin

  ----------------------------------------------------------------------------
  -- AMBA bus fabric
  ----------------------------------------------------------------------------
  ac0: ahbctrl
    generic map (
      devid    => devid,
      ioaddr   => AHBC_IOADDR,
      rrobin   => 1,
      split    => 1,
      nahbm    => ncpu+nextmst+1+(nodbus*(ndbgmst-1)),
      nahbs    => nextslv+1+2+1+(nodbus*4),
      fpnpen   => 1,
      shadow   => 1,
      ahbtrace => ahbtrace,
      ahbendian => 1
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
    cpuso(cpuso'high downto nextslv+1+2+1) <= (others => ahbs_none);
  end generate;
  dbgslv_to_cpu : if nodbus /= 0 generate
    cpuso(nextslv+1+2+1+4-1 downto nextslv+1+2+1) <= dbgso(3 downto 0);
    cpuso(cpuso'high downto nextslv+1+2+1+4) <= (others => ahbs_none);
    dbgsi <= cpusi;
    dbgso(2) <= ahbs_none;
  end generate;

  dual_apb_gen : if nodbus = 0 generate
    ap0: apbctrldp
      generic map (
        hindex0 => APBC_HINDEX,
        haddr0  => APBC_HADDR,
        hmask0  => APBC_HMASK,
        hindex1 => APBC_DM_HINDEX,
        haddr1  => APBC_HADDR,
        hmask1  => APBC_HMASK,
        nslaves => nextapb+2
        )
      port map (
        rst  => rstn,
        clk  => clk,
        ahb0i => cpusi,
        ahb0o => cpuso(APBC_HINDEX),
        ahb1i => dbgsi,
        ahb1o => dbgso(APBC_DM_HINDEX),
        apbi => cpuapbi,
        apbo => cpuapbo
        );
  end generate;
  no_dual_apb_gen : if nodbus /= 0 generate
    ap0: apbctrl
      generic map (
        hindex => nextslv,
        haddr  => APBC_HADDR,
        hmask  => APBC_HMASK,
        nslaves => nextapb+2
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
  cpuapbo(nextapb+2 to cpuapbo'high) <= (others => apb_none);

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
        rfconf   => rfconf,
        fpuconf  => fpuconf,
        disas    => disas,
        pbaddr   => 16#90000#,
        cfg      => cfg,
        scantest => scantest)
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
        cnt   => cnt(c)
      );
  end generate;
  cpu0errn <= not dbgo(0).error;

  ----------------------------------------------------------------------------
  -- Debug and tracing module
  ----------------------------------------------------------------------------
  dm0 : rvdm -- NOEL-V Debug Support Unit
    generic map(
      hindex          => DM_DM_HINDEX,
      haddr           => DM_HADDR,
      hmask           => DM_HMASK,
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
      ahbso           => dbgso(0),-- This is handled separately for nodbus = 1
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
      hindex  => AHBT_DM_HINDEX,
      ioaddr  => AHBT_IOADDR,
      iomask  => AHBT_IOMASK,
      tech    => memtech,
      irq     => 0,
      kbytes  => 2,
      bwidth  => AHBDW,
      ahbfilt => 2,
      ntrace  => 2,
      exttimer => 1,
      exten    => 0,
      scantest => scantest)
    port map(
      rst     => rstn,
      clk     => clk,
      ahbsi   => dbgsi,
      ahbso   => dbgso(3),    -- This is handled separately for nodbus = 1
      timer   => dbgo(0).mcycle(30 downto 0),
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
        ioaddr   => AHBC_DM_IOADDR,
        rrobin   => 1,
        split    => 1,
        nahbm    => ndbgmst,
        nahbs    => 4,
        fpnpen   => 1,
        shadow   => 1,
        ahbtrace => ahbtrace,
        ahbendian => 1
        )
      port map (
        rst  => rstn,
        clk  => clk,
        msti => dbgahbmi,
        msto => dbgahbmo,
        slvi => dbgsi,
        slvo => dbgso,
        testen  => testen,
        testrst => testrst,
        scanen  => scanen,
        testoen => testoen,
        testsig => testsig
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
        hsindex     => AHBB_DM_HINDEX,
        hmindex     => AHBB_HMINDEX,
        slv         => 1,
        dir         => 1,
        ffact       => 1,
        pfen        => 1,
        wburst      => 4,
        iburst      => 4,
        rburst      => 4,
        irqsync     => 0,
        bar0        => ahb2ahb_membar(AHBB_DM_HADDR0, '1', '1', AHBB_DM_HMASK0),
        bar1        => ahb2ahb_membar(AHBB_DM_HADDR1, '0', '0', AHBB_DM_HMASK1),
        bar2        => ahb2ahb_membar(AHBB_DM_HADDR2, '1', '1', AHBB_DM_HMASK2),
        bar3        => ahb2ahb_membar(AHBB_DM_HADDR3, '0', '0', AHBB_DM_HMASK3),
        sbus        => 1,
        mbus        => 0,
        ioarea      => AHBC_IOADDR,
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
        ahbso       => dbgso(AHBB_DM_HINDEX),
        ahbmi       => cpumi,
        ahbmo       => cpumo(AHBB_HMINDEX),
        ahbso2      => cpuso,
        lcki        => nolock,
        lcko        => open,
        ifctrl      => noifctrl);
  end generate;

  ----------------------------------------------------------------------------
  -- Dummy PnP
  ----------------------------------------------------------------------------
  dummypnp_gen : if nodbus = 0 generate
    dummypnp : dummy_pnp
      generic map (
        hindex  => DUMMY_HINDEX,
        ioarea  => DUMMY_HADDR,
        devid   => devid)
      port map (
      ahbsi    => cpusi,
      ahbso    => cpuso(DUMMY_HINDEX));
  end generate;
  nodummypnp_gen : if nodbus /= 0 generate
      cpuso(DUMMY_HINDEX) <= ahbs_none;
  end generate;
  ----------------------------------------------------------------------------
  -- Standard UART
  ----------------------------------------------------------------------------
  uart0: apbuart
    generic map (
      pindex => APBUART_PINDEX,
      paddr => APBUART_PADDR,
      pmask => APBUART_PMASK,
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
      apbi => cpuapbi(APBUART_PINDEX),
      apbo => cpuapbo(APBUART_PINDEX),
      uarti => uarti,
      uarto => xuarto
      );
  uarto <= xuarto;

--pragma translate_off
--pragma translate_on

  ----------------------------------------------------------------------------
  -- Timer
  ----------------------------------------------------------------------------
  gpt0: gptimer
    generic map (
      pindex  => GPTIME_PINDEX,
      paddr   => GPTIME_PADDR,
      pmask   => GPTIME_PMASK,
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
      apbi => cpuapbi(GPTIME_PINDEX),
      apbo => cpuapbo(GPTIME_PINDEX),
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
      hindex    => CLINT_HINDEX,
      haddr     => CLINT_HADDR,
      hmask     => CLINT_HMASK,
      ncpu      => ncpu
      )
    port map (
      rst       => rstn,
      clk       => clk,
      rtc       => rtc,
      ahbi      => cpusi,
      ahbo      => cpuso(CLINT_HINDEX),
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
      hindex            => PLIC_HINDEX,
      haddr             => PLIC_HADDR,
      hmask             => PLIC_HMASK,
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
      ahbo              => cpuso(PLIC_HINDEX),
      irqo              => eip
      );


end;
