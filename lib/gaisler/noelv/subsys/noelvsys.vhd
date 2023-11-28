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
-- Entity:      noelvsys
-- File:        noelvsys.vhd
-- Author:      Nils Wessman, Cobham Gaisler
-- Description: NOEL-V processor system (CPUs,FPUs,DM,ACLINT,IMSIC,APLIC,UART,AMBA)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.amba.all;
use grlib.config.all;
use grlib.config_types.all;
use grlib.devices.all;
use grlib.stdlib.log2x;
-- pragma translate_off
use grlib.stdlib.tost;
use grlib.stdlib.print;
-- pragma translate_on
library gaisler;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.noelv.all;
use gaisler.plic.all;
use gaisler.imsic.all;
use gaisler.aplic.all;
use gaisler.misc.grgpreg;


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
    nintdom  : integer;
    neiid    : integer;
    cached   : integer;
    wbmask   : integer;
    busw     : integer;
    cmemconf : integer;
    rfconf   : integer;
    fpuconf  : integer;
    tcmconf  : integer;
    mulconf  : integer;
    disas    : integer;
    ahbtrace : integer;
    cfg      : integer;
    devid    : integer;
    nodbus   : integer;
    trace    : integer;
    scantest : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    -- AHB bus interface for other masters (DMA units)
    ahbmi    : out ahb_mst_in_type;
    ahbmo    : in  ahb_mst_out_vector_type(ncpu + nextmst - 1 downto ncpu);
    -- AHB bus interface for slaves (memory controllers, etc)
    ahbsi    : out ahb_slv_in_type;
    ahbso    : in  ahb_slv_out_vector_type(nextslv - 1 downto 0);
    -- AHB master interface for debug links
    dbgmi    : out ahb_mst_in_vector_type(ndbgmst - 1 downto 0);
    dbgmo    : in  ahb_mst_out_vector_type(ndbgmst - 1 downto 0);
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
    -- Perf counter
    cnt      : out nv_counter_out_vector(ncpu - 1 downto 0);
    -- E-trace sink interface
    etso     : out nv_etrace_sink_out_vector(ncpu - 1 downto 0);
    etsi     : in  nv_etrace_sink_in_vector(ncpu - 1 downto 0) := (others => nv_etrace_sink_in_none);
    -- DFT support
    testen   : in  std_ulogic := '0';
    testrst  : in  std_ulogic := '1';
    scanen   : in  std_ulogic := '0';
    testoen  : in  std_ulogic := '1';
    testsig  : in  std_logic_vector(1 + GRLIB_CONFIG_ARRAY(grlib_techmap_testin_extra) downto 0) := (others => '0')
    );
end;

architecture hier of noelvsys is

  type trace_d_vector is array (0 to ncpu) of std_logic_vector(1023 downto 0);
  signal vtrace_d : trace_d_vector;
  signal vtrace_v : std_logic_vector(0 to ncpu);
  -- AIA configuration functions -------------------------------------

  function config_interrupts(cfg : integer) return integer is
    variable cfg_typ  : integer;
    variable cfg_lite : integer;
  begin
    cfg_typ  := (cfg / 256)  mod 16; 
    cfg_lite := (cfg / 128)  mod 2; 

    -- If core is configured as HP or GP AIA is enabled
    if cfg_typ /= 0  then
      if not(cfg_typ = 2 or cfg_typ = 16 or 
             (cfg_typ = 3 and cfg_lite = 1)) then
        return 1;
      else
        return 0;
      end if;
    else
      -- Old configuration
      if not(cfg = 3 or cfg = 4 or cfg = 5 or cfg = 6) then
        return 1;
      else
        return 0;
      end if;
    end if;
  end function;
  
  function set_IMSIC_addr(HADDR : integer) return std_logic_vector is
    variable IMSIC_addr : std_logic_vector(31 downto 0);
  begin
    IMSIC_addr := std_logic_vector(to_unsigned(HADDR, 12)) & x"00000";
    return IMSIC_addr;
  end function;


  function calc_sbase(
    base      : std_logic_vector(31 downto 0);
    ncpu      : integer;
    groups    : integer;
    H_EN      : integer range 0 to 1;
    nvcpubits : integer)                         -- guest hart
    return std_logic_vector is
      variable addr      : std_logic_vector(31 downto 0);
      variable ncpubits  : integer; 
      variable groupbits : integer; 
      variable bitnumber : integer; 
  begin 
    if groups = 0 then
      ncpubits  := log2x(ncpu);
      bitnumber := ncpubits + nvcpubits * H_EN + 12; 
    else 
      ncpubits  := log2x(ncpu / groups);
      groupbits := log2x(groups);
      bitnumber := ncpubits + nvcpubits * H_EN + groupbits + 12; 
    end if;
    addr := base;
    addr(bitnumber) := '1';
    return addr;
  end function;

  function calc_ncpubits(
    ncpu      : integer;
    groups    : integer)
    return integer is
  begin 
    -- The number of bits needed to reference the harts
    -- is diferent if cpus are grouped
    if groups = 0 then
      return log2x(ncpu);
    else 
      return log2x(ncpu / groups);
    end if;
  end function;


  constant doms_per_branch : integer := 3;
  constant branches        : integer := 2;
  constant ndoms           : integer := doms_per_branch * branches + 1; 

  type aplic_harts_config_type is array (0 to ndoms - 1) of std_logic_vector(0 to ncpu - 1);

  function set_aplic_dom_harts_config(
    ncpu : integer;
    ndom : integer  
  ) return aplic_harts_config_type is
    variable out_config  : aplic_harts_config_type;
    variable cpu_per_dom : integer := ncpu / ndom;
  begin
    -- Add here possible configuration for different numbers of cores and domains
    if ncpu = 1 and ndom = 7 then
      out_config := (
        0  => "1",
        1  => "1",
        2  => "1",
        3  => "1",
        4  => "0",
        5  => "0",
        6  => "0"
      );
    elsif ncpu = 2 and ndom = 7 then
      out_config := (
        0  => "01",
        1  => "01",
        2  => "01",
        3  => "01",
        4  => "10",
        5  => "10",
        6  => "10"
      );
    else -- Default configuration
      for i in 0 to ndom-1 loop
        out_config(i) := (others => '0');
        for j in 0 to cpu_per_dom-1 loop
          out_config(i)(i * cpu_per_dom + j) := '1';
        end loop;
      end loop;
    end if;
    return out_config;
  end function;

  function config_domain_harts(in_config_arr : aplic_harts_config_type) return preset_active_harts_type is
    variable out_config_arr : preset_active_harts_type := (others => (others => '0'));
  begin
    for i in in_config_arr'range loop 
      out_config_arr(i)(ncpu-1 downto 0) := in_config_arr(i); 
    end loop;
    return out_config_arr;
  end function;

  -- Helper functions to shuffle PnP entries

  function replace_hindex(x : ahb_slv_out_type; hindex : integer) return ahb_slv_out_type is
    variable r : ahb_slv_out_type := x;
  begin
    r.hindex := hindex;

    return r;
  end replace_hindex;

  function replace_pindex(x : apb_slv_out_type; pindex : integer) return apb_slv_out_type is
    variable r : apb_slv_out_type := x;
  begin
    r.pindex := pindex;

    return r;
  end replace_pindex;

  function shift_psel(x: apb_slv_in_type; nshift: integer; nslaves: integer) return apb_slv_in_type is
    variable r : apb_slv_in_type := x;
  begin
    for i in 0 to nslaves-1 loop
      r.psel(i) := x.psel((nslaves + i + nshift) mod nslaves);
    end loop;

    return r;
  end shift_psel;

  function shift_hsel(x: ahb_slv_in_type; nshift: integer; nslaves: integer) return ahb_slv_in_type is
    variable r : ahb_slv_in_type := x;
  begin
    for i in 0 to nslaves-1 loop
      r.hsel(i) := x.hsel((nslaves + i + nshift) mod nslaves);
    end loop;

    return r;
  end shift_hsel;

  ----------------------------------------------------------------

  signal cpumi    : ahb_mst_in_type;
  signal cpumo    : ahb_mst_out_vector;
  signal cpusi    : ahb_slv_in_type;
  signal cpusix   : ahb_slv_in_type;
  signal cpuso    : ahb_slv_out_vector;
  signal irqi     : nv_irq_in_vector(0 to ncpu - 1);
  signal irqo     : nv_irq_out_vector(0 to ncpu - 1);
  signal nirqi    : nv_nirq_in_vector(0 to ncpu - 1);
  signal meip     : std_logic_vector(0 to ncpu - 1);
  signal seip     : std_logic_vector(0 to ncpu - 1);
  signal imsici   : imsic_in_vector(0 to ncpu - 1);
  signal imsico   : imsic_out_vector(0 to ncpu - 1);
  signal dbgi     : nv_debug_in_vector(0 to ncpu - 1);
  signal dbgo     : nv_debug_out_vector(0 to ncpu - 1);
  signal dsui     : nv_dm_in_type;
  signal dsuo     : nv_dm_out_type;
  signal cpuapbi  : apb_slv_in_type;
  signal cpuapbix : apb_slv_in_type;
  signal cpuapbo  : apb_slv_out_vector;
  signal gpti     : gptimer_in_type;
  signal gpto     : gptimer_out_type;
  signal tstop    : std_ulogic;
  signal xuarto   : uart_out_type;
  -- PLIC/IMSIC => CLINT
  signal eip      : nv_irq_in_vector(0 to ncpu - 1);
  signal plic_eip : std_logic_vector(ncpu * 4 - 1 downto 0);
  -- Real Time Clock
  signal rtc      : std_ulogic := '0';
  -- Trace
  signal eto      : nv_etrace_out_vector(ncpu - 1 downto 0);

  signal apbo_uart, apbo_gptime, apbo_etrace, apbo_iommu : apb_slv_out_type;
  signal ahbso_apbctrl : ahb_slv_out_type;

  -- AHB master index
  constant AHBB_HMINDEX   : integer := ncpu + nextmst;
  constant APLIC_HMINDEX  : integer := ncpu + nextmst + 1;
  -- AHB slave index
  constant APBC_HINDEX    : integer := nextslv;
  constant ACLINT_HINDEX  : integer := nextslv + 1;
  constant IMSIC_HINDEX   : integer := nextslv + 2;
  constant PLIC_HINDEX    : integer := nextslv + 3;
  constant APLIC_HSINDEX  : integer := nextslv + 3;
  constant DUMMY_HINDEX   : integer := nextslv + 4;
  constant DM_HINDEX      : integer := nextslv + 5; -- Used for PnP replacement
  -- AHB slave address
  constant AHBC_IOADDR    : integer := 16#FFF#; --16#FFE# + nodbus;
  constant ACLINT_HADDR   : integer := 16#E00#;
  constant ACLINT_HMASK   : integer := 16#FFF#;
  constant IMSIC_HADDR    : integer := 16#A00#;
  constant APLIC_HADDR    : integer := 16#F80#; 
  constant PLIC_HADDR     : integer := 16#F80#; 
  constant PLIC_HMASK     : integer := 16#FC0#;
  constant DM_HADDR       : integer := 16#FE0#;
  constant DM_HMASK       : integer := 16#FF0#;
  constant AHBT_IOADDR    : integer := 16#000#;
  constant AHBT_IOMASK    : integer := 16#E00#;
  constant APBC_HADDR     : integer := 16#FC0#;
  constant APBC_HMASK     : integer := 16#FFF#;
  constant DUMMY_HADDR    : integer := 16#FFE#;
  -- APB slave index
  constant APBUART_PINDEX : integer := nextapb + 0;
  constant GPTIME_PINDEX  : integer := nextapb + 1;
  constant ETRACE_PINDEX  : integer := nextapb + 2;
  -- APB slave address
  constant GPTIME_PADDR   : integer := 16#000#;
  constant GPTIME_PMASK   : integer := 16#FFF#;
  constant APBUART_PADDR  : integer := 16#010#;
  constant APBUART_PMASK  : integer := 16#FFF#;
  constant ETRACE_PADDR   : integer := 16#020#;
  constant ETRACE_PMASK   : integer := 16#FF0#;
  -- IRQ
  constant APBUART_PIRQ   : integer := 1;
  constant GPTIME_PIRQ    : integer := 2; -- , 3
  --constant GPTIME_PIRQ2   : integer := 3;
  constant ETRACE_PIRQ    : integer := 4;
  constant WATCHDOG_HIRQ1 : integer := 1;
  constant WATCHDOG_HIRQ2 : integer := 2;

  -- IMSIC
  constant AIA_en  : integer := config_interrupts(cfg) * AIA_SUPPORT;
  -- If AIA is enabled, then the core configuration includes the
  -- supervisor mode and the hypervisor extnesion
  constant H_EN : integer := AIA_en;
  constant S_EN : integer := AIA_en;

  constant identities_int  : nidentities_vector(0 to ncpu - 1)          := (others => neiid);
  constant gidentities_int : nidentities_vector(0 to ncpu * GEILEN - 1) := (others => neiid);

  -- APLIC
  constant groups   : integer := 0; -- In the future could be part of the system configuration
  constant IMSIC_BADDR : std_logic_vector(31 downto 0) := set_IMSIC_addr(IMSIC_HADDR);

  -- 1 core:
  constant aplic_domains_harts : aplic_harts_config_type := set_aplic_dom_harts_config(ncpu, ndoms);
  
  --
  constant ncpubits    : integer := calc_ncpubits(ncpu, groups);
  constant nvcpubits   : integer := log2x(GEILEN + 1);
  constant groupbits   : integer := log2x(groups);
  --
  constant mbase_PPN : std_logic_vector(31 downto 0)  := IMSIC_BADDR;
  constant sbase_PPN : std_logic_vector(31 downto 0)  := calc_sbase(IMSIC_BADDR, ncpu, groups, H_EN, nvcpubits);
  constant mLHXS     : integer                        := 0;                           -- Machine Low Hart Index Shift = C - 12 (see specs)
  constant sLHXS     : integer                        := nvcpubits * H_EN;            -- Supervisor Low Hart Index Shift = D - 12 (see specs)
  constant HHXS      : integer                        := ncpubits + nvcpubits * H_EN - 12;  -- High Hart Index Shift = E - 24 (see specs)
  constant LHXW      : integer                        := ncpubits;                    -- Low Hart Index Width = k (see specs)
  constant HHXW      : integer                        := groupbits;                   -- High Hart Index Width = j (see specs)

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
      nahbm    => ncpu + nextmst + 2,
      nahbs    => nextslv + 5,
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
  cpumo(ncpu + nextmst - 1 downto ncpu) <= ahbmo;
  cpumo(cpumo'high downto ncpu + nextmst + 1 + 1) <= (others => ahbm_none);

  -- Shift up any external AHB slaves to fit 1 internal one:
  -- apbctrl
  ahbsi    <= shift_hsel(cpusi, 1, nextslv + 1);
  cpusix   <= shift_hsel(cpusi, 1, nextslv + 1);
  cpuso(0) <= replace_hindex(ahbso_apbctrl, 0);
  genrot: for i in 1 to nextslv generate
    cpuso(i) <= replace_hindex(ahbso(i - 1), i);
  end generate;
  -- Clear above 5 internal AHB slaves:
  -- aclint, imsic, (a)plic, dummy
  cpuso(cpuso'high downto nextslv + 5) <= (others => ahbs_none);

  ap0: apbctrl
    generic map (
      hindex  => APBC_HINDEX,
      haddr   => APBC_HADDR,
      hmask   => APBC_HMASK,
      nslaves => nextapb + 3
      )
    port map (
      rst  => rstn,
      clk  => clk,
      ahbi => cpusix,
      ahbo => ahbso_apbctrl,
      apbi => cpuapbi,
      apbo => cpuapbo
      );

  -- Shift up any external APB slaves to fit 3 internal ones:
  -- uart, gptime, etrace
  noextapb: if nextapb = 0 generate
    apbi                    <= cpuapbi;
    cpuapbix                <= cpuapbi;
    cpuapbo(APBUART_PINDEX) <= apbo_uart;
    cpuapbo(GPTIME_PINDEX)  <= apbo_gptime;
    cpuapbo(ETRACE_PINDEX)  <= apbo_etrace;
  end generate;
  doshiftapb: if nextapb > 0 generate
    apbi       <= shift_psel(cpuapbi, 3, nextapb + 3);
    cpuapbix   <= shift_psel(cpuapbi, 3, nextapb + 3);
    cpuapbo(0) <= replace_pindex(apbo_uart, 0);
    cpuapbo(1) <= replace_pindex(apbo_gptime,  1);
    cpuapbo(2) <= replace_pindex(apbo_etrace, 2);
    genrotapb: for i in 3 to nextapb + 2 generate
      cpuapbo(i) <= replace_pindex(apbo(i - 3), i);
    end generate;
  end generate;
  cpuapbo(nextapb + 3 to cpuapbo'high) <= (others => apb_none);

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
        tcmconf  => tcmconf,
        mulconf  => mulconf,
        disas    => disas,
        pbaddr   => 16#90000#,
        cfg      => cfg,
        scantest => scantest
      )
      port map (
        clk    => clk,
        rstn   => rstn,
        ahbi   => cpumi,
        ahbo   => cpumo(c),
        ahbsi  => cpusix,
        ahbso  => cpuso,
        imsici => imsici(c),
        imsico => imsico(c),
        irqi   => irqi(c),
        irqo   => irqo(c),
        nirqi  => nirqi(c),
        dbgi   => dbgi(c),
        dbgo   => dbgo(c),
        eto    => eto(c),
        cnt    => cnt(c)
      );
  end generate;


  cpu0errn <= not dbgo(0).error;

  ----------------------------------------------------------------------------
  -- Debug and tracing module
  ----------------------------------------------------------------------------
  dm0 : dmnv
  generic map(
    fabtech   => fabtech,
    memtech   => memtech,
    ncpu      => ncpu,
    ndbgmst   => ndbgmst,
    -- Conventional bus
    cbmidx    => AHBB_HMINDEX,
    -- PnP
    dmhaddr   => DM_HADDR,
    dmhmask   => DM_HMASK,
    pnpaddrhi => 16#FFF#,
    pnpaddrlo => 16#FFF#,
    dmslvidx  => DM_HINDEX,
    dmmstidx  => AHBB_HMINDEX,
    -- Trace
    tbits     => 30,
    --
    scantest  => 0,
    -- Pipelining
    plmdata   => 0)
  port map(
    clk      => clk,
    rstn     => rstn,
    -- Debug-link interface
    dbgmi    => dbgmi,
    dbgmo    => dbgmo,
    -- Conventional AHB bus interface
    cbmi    => cpumi,
    cbmo    => cpumo(AHBB_HMINDEX),
    cbsi    => cpusix,
    -- 
    dbgi    => dbgo,
    dbgo    => dbgi,
    dsui    => dsui,
    dsuo    => dsuo);

  dsui.enable <= dsuen;
  dsui.break  <= dsubreak;

  etrace : if trace /= 0 generate
    x : etracenv
      generic map(
        ext_c   => 1,
        ncpu    => ncpu,
        pindex  => ETRACE_PINDEX,
        paddr   => ETRACE_PADDR,
        pmask   => ETRACE_PMASK,
        pirq    => ETRACE_PIRQ
      )
      port map(
        rstn    => rstn,
        clk     => clk,
        apbi    => cpuapbix,
        apbo    => apbo_etrace,
        eto     => eto,
        etso    => etso,
        etsi    => etsi
      );
  end generate;
  notrace : if trace = 0 generate
    apbo_etrace <= apb_none;
    etso <= (others => nv_etrace_sink_out_none);
  end generate;

  ----------------------------------------------------------------------------
  -- Dummy PnP
  ----------------------------------------------------------------------------
  dummypnp : dummy_pnp
    generic map (
      hindex  => DUMMY_HINDEX,
      ioarea  => DUMMY_HADDR,
      devid   => devid)
    port map (
    ahbsi    => cpusix,
    ahbso    => cpuso(DUMMY_HINDEX));
  ----------------------------------------------------------------------------
  -- Standard UART
  ----------------------------------------------------------------------------
  uart0: apbuart
    generic map (
      pindex   => APBUART_PINDEX,
      paddr    => APBUART_PADDR,
      pmask    => APBUART_PMASK,
      console  => 1,
      pirq     => 1,
      parity   => 1,
      flow     => 1,
      fifosize => 8,
      abits    => 8,
      sbits    => 12
      )
    port map (
      rst   => rstn,
      clk   => clk,
      apbi  => cpuapbix,
      apbo  => apbo_uart,
      uarti => uarti,
      uarto => xuarto
      );
  uarto <= xuarto;

-- pragma translate_off
-- pragma translate_on

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
      apbi => cpuapbix,
      apbo => apbo_gptime,
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

    -- ACLINT -----------------------------------------------------------
    aclint0 : aclint_ahb
      generic map (
        hindex    => ACLINT_HINDEX,
        haddr     => ACLINT_HADDR,
        hmask     => ACLINT_HMASK,
        hirq1     => WATCHDOG_HIRQ1,
        hirq2     => WATCHDOG_HIRQ2,
        ncpu      => ncpu,
        sswi      => S_EN
        )
      port map (
        rst       => rstn,
        clk       => clk,
        rtc       => rtc,
        ahbi      => cpusix,
        ahbo      => cpuso(ACLINT_HINDEX),
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

  aia_gen : if AIA_en = 1 generate
    -- IMSIC  ---------------------------------------------------------
    imsic0 : grimsic_ahb 
     generic map (
       hindex            => IMSIC_HINDEX,
       haddr             => IMSIC_HADDR,
       ncpu              => ncpu,
       GEILEN            => GEILEN,
       groups            => groups,
       S_EN              => S_EN,
       H_EN              => H_EN,
       plic              => 1,
       mnidentities_vector   => identities_int, 
       snidentities_vector   => identities_int,
       gnidentities_vector   => gidentities_int
       )
     port map (
       rst               => rstn,
       clk               => clk,
       ahbi              => cpusix,
       ahbo              => cpuso(IMSIC_HINDEX),
       plic_meip         => meip,
       plic_seip         => seip,    
       imsici            => imsici,
       imsico            => imsico,
       eip               => eip
       );
        

    -- GRAPLIC ----------------------------------------------------------
    aplic0 : graplic_ahb
      generic map (
        hmindex             => APLIC_HMINDEX,
        hsindex             => APLIC_HSINDEX,
        haddr               => APLIC_HADDR,
        nsources            => NAHBIRQ,
        ncpu                => ncpu,
        branches            => branches,
        doms_per_branch     => doms_per_branch,
        endianness          => 0,
        S_EN                => S_EN,
        H_EN                => H_EN,
        GEILEN              => GEILEN,
        grouped_harts       => 0,
        mmsiaddrcfg_fixed   => 1,
        mbase_PPN           => mbase_PPN,
        sbase_PPN           => sbase_PPN,
        mLHXS               => mLHXS,
        sLHXS               => sLHXS,
        HHXS                => HHXS,
        LHXW                => LHXW,
        HHXW                => HHXW,
        direct_delivery     => 1,
        IPRIOLEN            => 8,
        nEIID               => neiid,
        preset_active_harts => config_domain_harts(aplic_domains_harts)
        )
      port map (
        rstn      => rstn,
        clk       => clk,
        ahbmi     => cpumi,
        ahbmo     => cpumo(APLIC_HMINDEX),
        ahbsi     => cpusix,
        ahbso     => cpuso(APLIC_HSINDEX),
        meip      => meip,
        seip      => seip
        );
  end generate aia_gen;


  old_interrupt_gen : if AIA_en = 0 generate
    -- PLIC -----------------------------------------------------------
    grplic0 : grplic_ahb
      generic map (
        hindex            => PLIC_HINDEX,
        haddr             => PLIC_HADDR,
        hmask             => PLIC_HMASK,
        nsources          => NAHBIRQ,
        ncpu              => ncpu,
        priorities        => 8,
        pendingbuff       => 1,
        irqtype           => 1,
        thrshld           => 1
        )
      port map (
        rst               => rstn,
        clk               => clk,
        ahbi              => cpusix,
        ahbo              => cpuso(PLIC_HINDEX),
        irqo              => plic_eip
        );
        
        -- Tie non implemented AHB outputs
        cpuso(IMSIC_HINDEX)  <= ahbs_none;
        cpumo(APLIC_HMINDEX) <= ahbm_none;

        -- IRQ Interface
        eip_gen : for i in 0 to ncpu-1 generate
          eip(i).meip           <= plic_eip(i * 4);
          eip(i).seip           <= plic_eip(i * 4 + 1);
          eip(i).ueip           <= plic_eip(i * 4 + 2);
          eip(i).heip           <= plic_eip(i * 4 + 3);
          eip(i).hgeip          <= (others => '0'); -- Only with APLIC
        end generate eip_gen;
  end generate old_interrupt_gen;

    nirq_zero : for i in 0 to ncpu-1 generate
      nirqi(i) <= (others => '0');
    end generate nirq_zero;
  

  -----------------------------------------------------------------------------
  -- Simulation report
  -----------------------------------------------------------------------------
-- pragma translate_off
  simrep: process
    function stradj(s: string; w: integer; rjust: boolean) return string is
      variable r: string(1 to w);
    begin
      r := (others => ' ');
      if rjust then
        r(w - s'length + 1 to w) := s;
      else
        r(1 to s'length) := s;
      end if;
      return r;
    end stradj;

    function tostw(i: integer; w: integer; rjust: boolean) return string is
    begin
      return stradj(grlib.stdlib.tost(i), w, rjust);
    end tostw;

    variable vendor : std_logic_vector(7 downto 0);
    variable device : std_logic_vector(11 downto 0);
    variable vendori, devicei : integer;
    variable intext : string(1 to 6);
    variable startaddr, endaddr, scanpos, scanend : std_logic_vector(31 downto 0);
    variable found : boolean;
    variable apbmode : boolean;
  begin
    wait for 10 ns;
    grlib.stdlib.print("noelvsys: NOELV subsystem with " & grlib.stdlib.tost(ncpu) & " cores");
    grlib.stdlib.print("noelvsys: ---------------------------------------------------");
    grlib.stdlib.print("noelvsys:   Debug masters:");
    for x in 0 to ndbgmst-1 loop
      if is_x(dbgmo(x).hconfig(0)) then
        grlib.stdlib.print("noelvsys:     WARNING: Debug master " & grlib.stdlib.tost(x) & " seems undriven, check VHDL");
      end if;
      vendor  := dbgmo(x).hconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device  := dbgmo(x).hconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      grlib.stdlib.print("noelvsys:     " & tostw(x,3,true) & " ext#" & tostw(x,2,false) & " " & 
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    grlib.stdlib.print("noelvsys:   CPU bus masters:");
    for x in 0 to ncpu+1 loop
      if is_x(cpumo(x).hconfig(0)) then
        grlib.stdlib.print("noelvsys:     WARNING: CPU bus master " & grlib.stdlib.tost(x) & " seems undriven, check VHDL");
      end if;
      vendor  := cpumo(x).hconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device  := cpumo(x).hconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      intext  :="int   ";
      grlib.stdlib.print("noelvsys:     " & tostw(x,3,true) & " " & intext & " " &
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    grlib.stdlib.print("noelvsys:   CPU bus slaves:");
    for x in 0 to nextslv+4 loop --
      if is_x(cpuso(x).hconfig(0)) then
        grlib.stdlib.print("noelvsys:     WARNING: CPU bus slave " & grlib.stdlib.tost(x) & " seems undriven, check VHDL");
      end if;
      vendor  := cpuso(x).hconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device  := cpuso(x).hconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
     
      if x > 0 and x < nextslv + 1 then
        intext := "ext#" & tostw(x - 1, 2, false);
      else
        intext := "int   ";
      end if;
      grlib.stdlib.print("noelvsys:     " & tostw(x, 3, true) & " " & intext & " " &
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    grlib.stdlib.print("noelvsys:   APB bus slaves:");
    for x in 0 to nextapb+2 loop
      if is_x(cpuapbo(x).pconfig(0)) then
        grlib.stdlib.print("noelvsys:     WARNING: APB bus slave " & grlib.stdlib.tost(x) & " seems undriven, check VHDL");
      end if;
      vendor  := cpuapbo(x).pconfig(0)(31 downto 24);
      vendori := to_integer(unsigned(vendor));
      device  := cpuapbo(x).pconfig(0)(23 downto 12);
      devicei := to_integer(unsigned(device));
      if x > 2 and x < nextapb + 3 then
        intext := "ext#" & tostw(x - 3, 2, false);
      else
        intext := "int   ";
      end if;
      grlib.stdlib.print("noelvsys:     " & tostw(x, 3, true) & " " & intext & " " &
                         grlib.devices.iptable(vendori).device_table(devicei));
    end loop;
    -- Check index debug signal on external signals (before any internal shuffling)
--    for x in ncpu to ncpu+nextmst-1 loop
--      assert ahbmo(x).hindex=x or (ahbmo(x).hindex=0 and ahbmo(x).hconfig(0)=x"00000000")
--        report "Invalid bus index on ahbmo #" & grlib.stdlib.tost(x)
--        severity warning;
--    end loop;
    for x in 0 to nextslv-1 loop
      assert ahbso(x).hindex = x or (ahbso(x).hindex = 0 and ahbso(x).hconfig(0) = x"00000000")
        report "Invalid bus index on ahbso #" & grlib.stdlib.tost(x)
        severity warning;
    end loop;
    for x in 0 to nextapb-1 loop
      assert apbo(x).pindex = x or (apbo(x).pindex = 0 and apbo(x).pconfig(0) = x"00000000")
        report "Invalid bus index on apbo #" & grlib.stdlib.tost(x)
        severity warning;
    end loop;
    grlib.stdlib.print("noelvsys: ---------------------------------------------------");
    grlib.stdlib.print("noelvsys:   Memory map:");
    scanpos := (others => '0');
    apbmode := false;
    oloop: for i in 1 to 100 loop
      found := false;
      if not apbmode then
        scanend := (others => '1');
        -- PnP area
        startaddr := x"FFFFF000";
        endaddr   := x"FFFFFFFF";
        if startaddr = scanpos then
          grlib.stdlib.print("noelvsys:     " & grlib.stdlib.tost(startaddr) & "-" &
                             grlib.stdlib.tost(endaddr) & " " & "Plug'n'play table");
          found   := true;
          scanend := endaddr;
        elsif not found then
          if unsigned(startaddr) > unsigned(scanpos) and unsigned(startaddr) < unsigned(scanend) then
            scanend := std_logic_vector(unsigned(startaddr) - 1);
          end if;
        end if;
        -- Regular slaves
        for x in 0 to nextslv+4 loop
          vendor  := cpuso(x).hconfig(0)(31 downto 24);
          vendori := to_integer(unsigned(vendor));
          device  := cpuso(x).hconfig(0)(23 downto 12);
          devicei := to_integer(unsigned(device));
          for b in 4 to 7 loop
            if cpuso(x).hconfig(b)(3 downto 0) = "0010" and cpuso(x).hconfig(b)(15 downto 4) /= x"000" then
              startaddr(31 downto 20) := cpuso(x).hconfig(b)(31 downto 20);
              startaddr(19 downto 0)  := (others => '0');
              endaddr(31 downto 20)   := cpuso(x).hconfig(b)(31 downto 20) or not cpuso(x).hconfig(b)(15 downto 4);
              endaddr(19 downto 0)    := (others => '1');
              -- PnP area may shadow
              if unsigned(endaddr) > unsigned'(x"FFFFEFFF") then
                endaddr := x"FFFFEFFF";
              end if;
            elsif cpuso(x).hconfig(b)(3 downto 0) = "0011" and cpuso(x).hconfig(b)(15 downto 4) /= x"000" then
              startaddr(31 downto 20) := x"FFF";
              startaddr(19 downto 8)  := cpuso(x).hconfig(b)(31 downto 20);
              endaddr(31 downto 20)   := x"FFF";
              endaddr(19 downto 8)    := cpuso(x).hconfig(b)(31 downto 20) or not cpuso(x).hconfig(b)(15 downto 4);
              endaddr(7 downto 0)     := (others=>'1');
            else
              next;
            end if;
            if startaddr = scanpos then
              grlib.stdlib.print("noelvsys:     " & grlib.stdlib.tost(startaddr) & "-" &
                                 grlib.stdlib.tost(endaddr) & " " &
                                 grlib.devices.iptable(vendori).device_table(devicei));
              assert not found report "Multiple mappings!";
              found   := true;
              scanend := endaddr;
              if x = 0 then
                apbmode := true;
                next oloop;
              end if;
             
            elsif not found then
              if unsigned(startaddr) > unsigned(scanpos) and unsigned(startaddr) < unsigned(scanend) then
                scanend := std_logic_vector(unsigned(startaddr) - 1);
              end if;
            end if;
            assert not (unsigned(startaddr) < unsigned(scanpos) and unsigned(endaddr) > unsigned(scanpos))
              report "Overlapping memory mappings!";
          end loop;
        end loop;
        if not found then
          grlib.stdlib.print("noelvsys:     " & grlib.stdlib.tost(scanpos) & "-" &
                             grlib.stdlib.tost(scanend) & " Unmapped AHB space");
        end if;
      else
        scanend := scanpos;
        scanend(19 downto 0) := (others => '1');
        for x in 0 to nextapb+2 loop
          vendor  := cpuapbo(x).pconfig(0)(31 downto 24);
          vendori := to_integer(unsigned(vendor));
          device  := cpuapbo(x).pconfig(0)(23 downto 12);
          devicei := to_integer(unsigned(device));
          if cpuapbo(x).pconfig(1)(3 downto 0)="0001" then
            startaddr              := scanpos;
            startaddr(19 downto 8) := cpuapbo(x).pconfig(1)(31 downto 20);
            startaddr(7 downto 0)  := (others => '0');
            endaddr                := startaddr;
            endaddr(19 downto 8)   := cpuapbo(x).pconfig(1)(31 downto 20) or not cpuapbo(x).pconfig(1)(15 downto 4);
            endaddr(7 downto 0)    := (others => '1');
          else
            next;
          end if;
          if startaddr = scanpos then
            grlib.stdlib.print("noelvsys:       " & grlib.stdlib.tost(startaddr) & "-" &
                               grlib.stdlib.tost(endaddr) & " " &
                               grlib.devices.iptable(vendori).device_table(devicei));
            assert not found report "Multiple mappings!";
            found   := true;
            scanend := endaddr;
          elsif not found then
            if unsigned(startaddr) > unsigned(scanpos) and unsigned(startaddr) < unsigned(scanend) then
              scanend := std_logic_vector(unsigned(startaddr) - 1);
            end if;
          end if;
          assert not (unsigned(startaddr) < unsigned(scanpos) and unsigned(endaddr) > unsigned(scanpos))
            report "Overlapping memory mappings!";
        end loop;
        if not found then
          grlib.stdlib.print("noelvsys:       " & grlib.stdlib.tost(scanpos) & "-" &
                             grlib.stdlib.tost(scanend) & " Unmapped APB space");
        end if;
        if scanend(19 downto 0) = x"FFFFF" then
          apbmode := false;
        end if;
      end if;
      exit when scanend = (scanend'range => '1');
      scanpos := std_logic_vector(unsigned(scanend) + 1);
    end loop;
    grlib.stdlib.print("noelvsys: ---------------------------------------------------");
    wait;
  end process;
-- pragma translate_on
end;
