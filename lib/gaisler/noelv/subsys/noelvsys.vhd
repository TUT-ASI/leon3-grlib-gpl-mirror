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
use grlib.stdlib.log2;
use grlib.stdlib.conv_integer;
use grlib.stdlib.conv_std_logic;
use grlib.stdlib.notx;
-- pragma translate_off
use grlib.stdlib.tost;
use grlib.stdlib.print;
-- pragma translate_on
library gaisler;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.noelv.all;
use gaisler.l5nv_shared.all;
use gaisler.plic.all;
use gaisler.aplic.all;
use gaisler.misc.grgpreg;
-- pragma translate_off
use gaisler.sim.htif_sim;
-- pragma translate_on
use gaisler.noelv_cfg_types.all;
use gaisler.noelv_cpu_cfg.all;
use gaisler.utilnv.all;


entity noelvsys is
  generic (
    fabtech  : integer;
    memtech  : integer;
    ncpu     : integer;
    nextmst  : integer;
    nextslv  : integer;
    nextapb  : integer;
    ndbgmst  : integer;
    neiid    : integer;
    cached   : integer;
    wbmask   : integer;
    busw     : integer;
    cmemconf : integer;
    rfconf   : integer;
    fpuconf  : integer;
    tcmconf  : integer;
    mulconf  : integer;
    intcconf : integer;
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
    gclk     : in  std_logic_vector(ncpu-1 downto 0);
    rstn     : in  std_ulogic;
    -- Power down mode
    pwrd     : out std_logic_vector(ncpu-1 downto 0);
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
    stoptime : out std_ulogic;
    cpuerrn  : out std_logic_vector(ncpu - 1 downto 0);
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

   ;
    -- One bit per cpu for now, cause can be 1 until more causes are added
    nirq       : in std_logic_vector(NEXTNMIRQ*ncpu-1 downto 0) := (others => '0')
    );
end;

architecture hier of noelvsys is


  -- AIA configuration functions -------------------------------------

  function no_x(v        : std_logic_vector;
                all_zero : boolean := false) return std_logic_vector is
    -- Non-constant
    variable r : std_logic_vector(v'range) := v;
  begin
-- pragma translate_off
    if is_x(v) then
      if all_zero then
        r := (others => '0');
      else
        for i in r'range loop
          if r(i) /= '0' and r(i) /= '1' then
            r(i) := '0';
          end if;
        end loop;
      end if;
    end if;
-- pragma translate_on

    return r;
  end;
  function no_x(v        : std_ulogic;
                all_zero : boolean := false) return std_ulogic is
    -- Non-constant
    variable r : std_ulogic := v;
  begin
-- pragma translate_off
    if is_x(v) then
      if all_zero then
        r := '0';
      else
        if r /= '0' and r /= '1' then
          r := '0';
        end if;
      end if;
    end if;
-- pragma translate_on

    return r;
  end;
  function config_interrupts(cfg : integer; conf : integer; support : integer) return integer is
    variable cfg_typ  : integer;
    variable cfg_lite : integer;
    variable config   : integer := support * conf;
  begin
    cfg_typ  := (cfg / 256)  mod 16;
    cfg_lite := (cfg / 128)  mod 2;

    -- If core is configured as HP or GP AIA is enabled
    if cfg_typ /= 0  then
      if not(cfg_typ = 2 or cfg_typ = 15 or
             (cfg_typ = 3 and cfg_lite = 1)) then
        return config;
      else
        return 0;
      end if;
    else
      -- Old configuration
      if not(cfg = 3 or cfg = 4 or cfg = 5 or cfg = 6) then
        return config;
      else
        return 0;
      end if;
    end if;
  end function;


  constant doms_per_branch : integer := 2;
  constant branches        : integer := ncpu;
  constant ndoms           : integer := doms_per_branch * branches + 1;

  type aplic_harts_config_type is array (0 to ndoms - 1) of std_logic_vector(0 to ncpu - 1);

  -- This function returns the reset values for the custom APLIC Hart Mask Registers
  -- The reset values set a configuration that most OSes/Hypervisors will expect.
  -- OSes and hypervisors will work even if they are not aware of this configuration registers.
  function set_aplic_dom_harts_config(
    ndom : integer
  ) return aplic_harts_config_type is
    variable out_config  : aplic_harts_config_type;
  begin
    for i in 0 to ndom-1 loop
      out_config(i) := (others => '0');
    end loop;
    -- Root Domain (used by SBI)
    out_config(0) := (others => '1');
    -- M-mode Interrupt Domain
    out_config(1) := (others => '0');
    -- S-mode Interrupt Domain (Used by OS/Hypervisor)
    out_config(2) := (others => '1');
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

  signal cpumi     : ahb_mst_in_type;
  signal cpumo     : ahb_mst_out_vector;
  signal cpusi     : ahb_slv_in_type;
  signal cpusix    : ahb_slv_in_type;
  signal cpuso     : ahb_slv_out_vector;
  signal irqi      : nv_irq_in_vector(0 to ncpu - 1);
  signal irqo      : nv_irq_out_vector(0 to ncpu - 1);
  signal imsic_ack : std_logic_vector(0 to ncpu - 1);
  signal dbgi      : nv_debug_in_vector(0 to ncpu - 1);
  signal dbgo      : nv_debug_out_vector(0 to ncpu - 1);
  signal dsui      : nv_dm_in_type;
  signal dsuo      : nv_dm_out_type;
  signal cpuapbi   : apb_slv_in_type;
  signal cpuapbix  : apb_slv_in_type;
  signal cpuapbo   : apb_slv_out_vector;
  signal gpti      : gptimer_in_type;
  signal gpto      : gptimer_out_type;
  signal lstoptime : std_ulogic;
  signal ltsctrl, tsctrl : l5_tsc_ctrl_type;
  signal tssetack  : std_ulogic;
  signal tsc       : l5_tsc_async_vector(0 to ncpu+1);
  signal timer     : std_logic_vector(62 downto 0);
  signal xuarto    : uart_out_type;

  -- Trace
  signal tpo      : nv_full_trace_vector(0 to ncpu - 1);
  signal eto      : nv_etrace_vector(ncpu - 1 downto 0);

  signal apbo_uart, apbo_gptime, apbo_etrace, apbo_iommu : apb_slv_out_type;
  signal ahbso_apbctrl : ahb_slv_out_type;


  constant DUAL_PLIC : integer := conv_integer(conv_std_logic(AIA_SUPPORT*intcconf >= 2));

  -- AHB master index
  constant RVINTCTRL_HMINDEX : integer := ncpu + nextmst;
  constant AHBB_HMINDEX   : integer := ncpu + nextmst + 1;
  -- AHB slave index
  constant APBC_HINDEX    : integer := nextslv;
  constant RVINTCTRL_HINDEX  : integer := nextslv + 1;
  constant PB_HINDEX      : integer := nextslv + 2; -- Used for PnP replacement
  constant DM_HINDEX      : integer := nextslv + 3; -- Used for PnP replacement
  -- AHB slave address
  constant AHBC_IOADDR    : integer := 16#FFF#; --16#FFE# + nodbus;
  constant ACLINT_HADDR   : integer := 16#B00#;
  constant APLIC_HADDR    : integer := 16#F85#;
  constant IMSIC_HADDR    : integer := 16#F86#;
  constant PLIC_HADDR     : integer := 16#FC0#;
  constant DM_HADDR       : integer := 16#E00#;
  constant DM_HMASK       : integer := 16#FF0#;
  constant AHBT_IOADDR    : integer := 16#000#;
  constant AHBT_IOMASK    : integer := 16#E00#;
  constant APBC_HADDR     : integer := 16#FF9#;
  constant APBC_HMASK     : integer := 16#FFF#;
  constant PB_HADDR       : integer := 16#F84#;
  constant PB_HMASK       : integer := 16#FFF#;
  -- APB slave index
  constant APBUART_PINDEX : integer := nextapb + 0;
  constant GPTIME_PINDEX  : integer := nextapb + 1;
  constant ETRACE_PINDEX  : integer := nextapb + 2;
  -- APB slave address
  constant APBUART_PADDR  : integer := 16#000#;
  constant APBUART_PMASK  : integer := 16#FFF#;
  constant GPTIME_PADDR   : integer := 16#080#;
  constant GPTIME_PMASK   : integer := 16#FFF#;
  constant ETRACE_PADDR   : integer := 16#010#;
  constant ETRACE_PMASK   : integer := 16#FF0#;
  -- IRQ
  constant APBUART_PIRQ   : integer := 1;
  constant GPTIME_PIRQ    : integer := 2; -- , 3
  --constant GPTIME_PIRQ2   : integer := 3;
  constant ETRACE_PIRQ    : integer := 4;
  constant WATCHDOG_HIRQ1 : integer := 1;
  constant WATCHDOG_HIRQ2 : integer := 2;

  -- AIA_en = 0 => Only PLIC; AIA_en = 1 => IMSIC/APLIC; AIA_en = 2 => IMSIC/APLIC/PLIC
  constant AIA_en  : integer := config_interrupts(cfg, intcconf, AIA_SUPPORT);
  -- If AIA is enabled, then the core configuration includes the
  -- supervisor mode and the hypervisor extnesion
  constant cfg_s : cfg_setup_type := cfg_map(cfg);
  constant cfg_c : nv_cpu_cfg_type := cfg_mask(
                                        ci => cfg_a(cfg_s.typ),
                                        cs => cfg_s,
                                        AIA     => AIA_EN,
                                        SMRNMI  => SMRNMI_SUPPORT,
                                        DBLTRP  => DBLTRP_SUPPORT,
                                        ZICFISS => ZICFISS_SUPPORT,
                                        ZICFILP => ZICFILP_SUPPORT,
                                        RV64    => boolean'pos(gaisler.noelv.XLEN = 64)
                                      );
  constant H_EN : integer := cfg_c.ext_h;
  constant S_EN : integer := cfg_c.mode_s;
  constant cfg_neiid : integer := cfg_c.neiid;

  -- APLIC
  constant groups   : integer := 0; -- In the future could be part of the system configuration
  -- 1 core:
  constant aplic_domains_harts : aplic_harts_config_type := set_aplic_dom_harts_config(ndoms);


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
      debug    => 0,
      nahbm    => ncpu + nextmst + 2,
      nahbs    => nextslv + 3,
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
  cpuso(cpuso'high downto nextslv + 3) <= (others => ahbs_none);

  ap0: apbctrl
    generic map (
      hindex  => APBC_HINDEX,
      haddr   => APBC_HADDR,
      hmask   => APBC_HMASK,
      nslaves => nextapb + 3,
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
        cached   => cached,
        wbmask   => wbmask,
        busw     => busw,
        cmemconf => cmemconf,
        rfconf   => rfconf,
        fpuconf  => fpuconf,
        tcmconf  => tcmconf,
        mulconf  => mulconf,
        intcconf => intcconf,
        disas    => disas,
        pbaddr   => 16#90000#,
        cfg      => cfg,
        scantest => scantest
      )
      port map (
        clk    => clk,
        gclk   => gclk(c),
        rstn   => rstn,
        tsc    => tsc(c),
        ahbi   => cpumi,
        ahbo   => cpumo(c),
        ahbsi  => cpusix,
        ahbso  => cpuso,
        irqi   => irqi(c),
        irqo   => irqo(c),
        dbgi   => dbgi(c),
        dbgo   => dbgo(c),
        tpo    => tpo(c),
        cnt    => cnt(c),
        pwrd   => pwrd(c)
      );

  end generate;


  cpu0errn <= not dbgo(0).error;
  err_tstop : process (dbgo)
    variable vstoptime   : std_ulogic;
  begin
    -- While all harts have stoptime=1 and are in Debug Mode,
    -- mtime is allowed to stop incrementing.
    vstoptime  := '1';
    for i in 0 to ncpu-1 loop
      vstoptime   := vstoptime and dbgo(i).stoptime;
      cpuerrn(i)  <= not dbgo(i).error;
    end loop;
    lstoptime <= vstoptime;
  end process;
  stoptime <= lstoptime;


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
    dmslvidx  => 32, --DM_HINDEX,
    dmmstidx  => 32,
    -- Program buffer
    pbslvidx  => PB_HINDEX,
    pbhaddr   => PB_HADDR,
    pbhmask   => PB_HMASK,
    -- Trace
    tbits     => 30,
    itentr    => 64,
    --
    scantest  => 0,
    -- Pipelining
    plmdata   => 0)
  port map(
    clk      => clk,
    rstn     => rstn,
    tsc      => tsc(ncpu+1),
    -- Debug-link interface
    dbgmi    => dbgmi,
    dbgmo    => dbgmo,
    -- Conventional AHB bus interface
    cbmi    => cpumi,
    cbmo    => cpumo(AHBB_HMINDEX),
    cbsi    => cpusix,
    --
    pbsi    => cpusix,
    pbso    => cpuso(PB_HINDEX),
    --
    tpi     => tpo,
    dbgi    => dbgo,
    dbgo    => dbgi,
    dsui    => dsui,
    dsuo    => dsuo);

  dsui.enable <= dsuen;
  dsui.break  <= dsubreak;

  etrace : if trace /= 0 generate
    e : for i in 0 to ncpu - 1 generate
      eto(i) <= tpo(i).eto;
    end generate;

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
  -- Standard UART
  ----------------------------------------------------------------------------
  uart0: apbuart_dual
    generic map (
      pindex     => APBUART_PINDEX,
      paddr      => APBUART_PADDR,
      pmask      => APBUART_PMASK,
      console    => 1,
      pirq       => 1,
      parity     => 1,
      flow       => 1,
      abits      => 8,
      -- APBUART
      fifosize   => 8,
      sbits      => 12,
      -- 16550 APBUART
      fifomode   => 1,
      sbits16550 => 12
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
    dhalt =>  lstoptime,
    extclk => '0',
    wdogen => '0',
    latchv => (others => '0'),
    latchd => (others => '0')
    );

  ----------------------------------------------------------------------------
  -- Time stamp counter generator
  ----------------------------------------------------------------------------
  tscgen0: l5tscgen
    generic map (
      tech     => fabtech,
      nsync    => 2,
      nsinks   => ncpu+2,
      npipe    => 4,
      asyncset => 0
      )
    port map (
      clk       => clk,
      rstn      => rstn,
      ctrl      => tsctrl,
      tssetack  => tssetack,
      tsc       => tsc
      );

  tsctrl.freeze <= lstoptime;
  tsctrl.set    <= ltsctrl.set;
  tsctrl.setval <= ltsctrl.setval;

  ----------------------------------------------------------------------------
  -- ACLINT Time stamp sink
  ----------------------------------------------------------------------------
  esink: l5tscsink
    generic map (
      tech      => fabtech,
      nsync     => 2,
      tbits     => 63
      )
    port map (
      clk       => clk,
      rstn      => rstn,
      tsc       => tsc(ncpu),
      timer     => timer
      );

  ----------------------------------------------------------------------------
  -- Interrupt Controllers
  ----------------------------------------------------------------------------
  nv_intctrl0 : rv_intctrl_ahb
   generic map(
    -- AHB
    hindex           => RVINTCTRL_HINDEX,
    hmindex          => RVINTCTRL_HMINDEX,
    -- GENERAL=>
    ncpu             => ncpu,
    S_EN             => S_EN,
    H_EN             => H_EN,
    GEILEN           => GEILEN,
    nsources         => NAHBIRQ,
    -- ACLINT
    enable_aclint    => 1,
    asyncset         => 0,
    aclint_haddr     => ACLINT_HADDR,
    aclint_ts        => 1,
    hirq1            => WATCHDOG_HIRQ1,
    hirq2            => WATCHDOG_HIRQ2,
    sswi             => S_EN,
    -- IMSIC
    enable_imsic     => AIA_en,
    imsic_haddr      => IMSIC_HADDR,
    groups           => groups,
    neiid            => cfg_neiid,
    -- APLIC
    enable_aplic     => AIA_en,
    aplic_haddr      => APLIC_HADDR,
    branches         => branches,
    doms_per_branch  => doms_per_branch,
    direct_delivery  => 1,
    IPRIOLEN         => 8,
    preset_active_harts => config_domain_harts(aplic_domains_harts),
    -- PLIC
    -- AIA_en=1 -> Disabled; AIA_en=0,2 ->Eenabled
    enable_plic      => (AIA_en+1) mod 2,
    plic_haddr       => PLIC_HADDR,
    priorities       => 8,
    pendingbuff      => 1,
    irqtype          => 2,
    thrshld          => 1
    )
  port map(
    rstn        => rstn,
    clk         => clk,
    -- AHB
    ahbi        => cpusix,
    ahbo        => cpuso(RVINTCTRL_HINDEX),
    ahbmi       => cpumi,
    ahbmo       => cpumo(RVINTCTRL_HMINDEX),
    -- ACLINT
    timer       => timer,
    ack         => tssetack,
    ctrl        => ltsctrl,
    -- IMSIC
    irq_ack     => imsic_ack,
    -- External RNMIs
    rnmi_irq    => nirq,
    -- Combined output
    irqi        => irqi
  );

  imsic_ack_gen : for i in 0 to ncpu-1 generate
    imsic_ack(i) <= '1';
  end generate;




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
    -- Last master in the debug subsystem is always the RISC-V Debug Module
    grlib.stdlib.print("noelvsys:     " & tostw(ndbgmst,3,true) & " ext#" & tostw(ndbgmst,2,false) & " " &
                       grlib.devices.iptable(VENDOR_GAISLER).device_table(GAISLER_RVDM));
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
    for x in 0 to nextslv+2 loop --
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
        for x in 0 to nextslv+2 loop
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
