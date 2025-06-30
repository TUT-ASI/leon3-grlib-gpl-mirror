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
-- Entity:      cpucorenv
-- File:        coucorenv.vhd
-- Author:      Nils Wessman, Cobham Gaisler AB
-- Description: Top-level NOEL-V components without bus interface
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
use techmap.netcomp.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
use grlib.riscv.all;
library gaisler;
use gaisler.l5nv_shared.all;
use gaisler.busif5_types.all;
use gaisler.noelvtypes.all;
use gaisler.noelv.all;
use gaisler.noelv_cpu_cfg.all;
use gaisler.noelvint.all;
use gaisler.utilnv.all;

entity cpucorenvbc is
  generic (
    fabtech             : integer;
    memtech             : integer;
    cached              : integer;
    wbmask              : integer;
    busw                : integer;
    iphysbits           : integer;
    dphysbits           : integer;
    cmemconf            : integer;
    rfconf              : integer;
    fpuconf             : integer;
    tcmconf             : integer;
    mulconf             : integer;
    intcconf            : integer;
    cfg                 : integer;
    disas               : integer;
    scantest            : integer;
    cgen                : integer;
    asyncif             : integer
    );
  port (
    clk         : in  std_ulogic;           -- CPU clock
    gclk        : in  std_ulogic;           -- Gated CPU clock
    rstn        : in  std_ulogic;
    bifi        : out busif_in_type5;
    bifo        : in  busif_out_type5;
    ahbpnp      : in  ahb_slv_out_vector;
    --snish       : in  snoopram_in_type5;
    --snosh       : out snoopram_out_type5;
    crami       : out cram_in_type5;
    cramo       : in  cram_out_type5;
    irqi        : in  nv_irq_in_type;       -- IRQ in
    irqo        : out nv_irq_out_type;      -- IRQ out
    dbgi        : in  nv_debug_in_type;     -- Debug in
    dbgo        : out nv_debug_out_type;    -- Debug out
    tpo         : out nv_full_trace_type;   -- Combined trace output
    cnt         : out nv_counter_out_type;  -- Perf event Out Port
    pwrd        : out std_ulogic;           -- Activate power down mode
    endian      : in  std_ulogic;
    testen      : in  std_ulogic;
    testrst     : in  std_ulogic;
    testin      : in  std_logic_vector(NTESTINBITS-1 downto 0)
    );
end;

architecture rtl of cpucorenvbc is

  constant ASYNC_RESET : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant MEMTECH_MOD : integer := memtech mod 65536;

  constant WRT          : integer := 1;	-- enable write-through RAM

  constant AIA_EN   : integer := conv_integer(conv_std_logic((AIA_SUPPORT * intcconf) /= 0));

  constant cfg_s : cfg_setup_type := cfg_map(cfg);
  constant cfg_c : nv_cpu_cfg_type := cfg_mask(
                                        ci => cfg_a(cfg_s.typ),
                                        cs => cfg_s,
                                        AIA     => AIA_EN,
                                        SMRNMI  => SMRNMI_SUPPORT,
                                        DBLTRP  => DBLTRP_SUPPORT,
                                        ZICFISS => ZICFISS_SUPPORT,
                                        ZICFILP => ZICFILP_SUPPORT,
                                        RV64    => boolean'pos(XLEN = 64),
                                        RDV     => RDV_SUPPORT
                                      ); 

  constant rfreadhold          : integer range 0  to 1         := 0;  -- Register File Read Hold
  constant illegalTval0        : integer range 0  to 1         := 0;  -- Zero TVAL on illegal instruction
  
  constant iphys_bits  : integer := gaisler.utilnv.minimum(iphysbits, gaisler.mmucacheconfig.pa_msb(cfg_c.riscv_mmu)+1);
  constant dphys_bits  : integer := gaisler.utilnv.minimum(dphysbits, gaisler.mmucacheconfig.pa_msb(cfg_c.riscv_mmu)+1);

  constant dtcmen    : integer := b2i((tcmconf mod 32) /= 0);
  constant dtcmabits : integer := (1 - dtcmen) + (tcmconf mod 32);
  constant dtcmfrac  : integer := ((tcmconf/32) mod 8);
  constant itcmen    : integer := b2i(((tcmconf / 256) mod 32) /= 0);
  constant itcmabits : integer := (1 - itcmen) + ((tcmconf / 256) mod 32);
  constant itcmfrac  : integer := ((tcmconf/(256*32)) mod 8);

  -- *waysize  is in kByte, thus add 10 (1k = 2^10).
  -- *linesize is in words, thus add 2 (4 = 2^2).
  -- Low bit is (sometimes) valid mark, thus add 1.

  constant iidxwidth    : integer := (log2(cfg_c.iwaysize) + 10) - (log2(cfg_c.ilinesize) + 2);
  --constant itagwidth    : integer := physaddr - (log2(cfg_c.iwaysize) + 10) + 1;
  constant itagwidth    : integer := iphys_bits - (log2(cfg_c.iwaysize) + 10) + 1;

  constant didxwidth    : integer := (log2(cfg_c.dwaysize) + 10) - (log2(cfg_c.dlinesize) + 2);
  --constant dtagwidth    : integer := physaddr - (log2(cfg_c.dwaysize) + 10) + 1;
  constant dtagwidth    : integer := dphys_bits - (log2(cfg_c.dwaysize) + 10) + 1;

  constant cdataw       : integer := 64;

  constant dtagconf     : integer := cmemconf mod 4;
  constant dusebw       : integer := (cmemconf / 4) mod 2;
  constant mulconf_int  : integer := mulconf mod 4;
  constant mulconf_fpu  : integer := (mulconf / 16) mod 4;
  constant mularch      : integer := (mulconf / 256) mod 4;

  -- No support for Zfa/Zfh/Zfhmin on nanoFPUnv
  constant actual_zfa     : integer := cond(fpuconf = 1, cfg_c.ext_zfa, 0);
  constant actual_zfh     : integer := cond(fpuconf = 1, cfg_c.ext_zfh, 0);
  constant actual_zfhmin  : integer := cond(fpuconf = 1, cfg_c.ext_zfhmin, 0);
  constant actual_zfbfmin : integer := cond(fpuconf = 1, cfg_c.ext_zfbfmin, 0);


  function gen_capability return std_logic_vector is
    variable cap : std_logic_vector(9 downto 0) := (others => '0');
  begin
    cap(9 downto 7) := u2vec(NOELV_TRACE_VERSION, 3);
    cap(6 downto 3) := u2vec(NOELV_VERSION, 4);
    return cap;
  end;

  constant capability   : std_logic_vector(9 downto 0) := gen_capability;

  -- Ensures riscv_mmu is OK.
  -- Sv32 if and only if XLEN is 32, else Sv39 unless explicitly Sv48.
  function constrain_riscv_mmu return integer is
  begin
    if XLEN = 32 then
      return gaisler.mmucacheconfig.sv32;
    end if;
    if cfg_c.riscv_mmu = gaisler.mmucacheconfig.sv48 then
      return cfg_c.riscv_mmu;
    end if;

    return gaisler.mmucacheconfig.sv39;
  end;

  constant actual_riscv_mmu : integer := constrain_riscv_mmu;

  constant actual_mmuen : integer := cfg_c.mode_s * cfg_c.mmuen;

  constant physaddr : integer := gaisler.utilnv.minimum(iphysbits, dphysbits);

  -- Returns how many bits are needed to represent an address (virtual or "physical").
  -- Not quite the same as in MMU/cache, since there it needs to deal with
  -- an actual address (which may be larger than XLEN) after translation.
  -- In the pipeline, the length is limited to max XLEN bits.
  function max_addr_bits return integer is
    constant pa : std_logic_vector := gaisler.mmucacheconfig.pa(actual_riscv_mmu);
    constant va : std_logic_vector := gaisler.mmucacheconfig.va(actual_riscv_mmu);
    constant ga : std_logic_vector := gaisler.mmucacheconfig.ga(actual_riscv_mmu);
  begin
    if cfg_c.ext_h = 0 then
      if cfg_c.mode_s = 0 then
        return gaisler.utilnv.minimum(XLEN, physaddr);
      else
        return gaisler.utilnv.maximum(va'length, gaisler.utilnv.minimum(physaddr, pa'length));
      end if;
    else
      return gaisler.utilnv.minimum(XLEN, ga'length);
    end if;
  end;

  constant addr_bits    : integer := max_addr_bits;
  constant pcaddr_bits  : integer := cond(addr_bits = XLEN, addr_bits, addr_bits + 2);


  -- OR interrupts with IMSIC external interrupts
  function eip_or(aia : nv_irq_in_type; old : nv_irq_in_type) return nv_irq_in_type is
    variable eip : nv_irq_in_type;
  begin
    eip.mtip        := aia.mtip  or old.mtip;
    eip.msip        := aia.msip  or old.msip;
    eip.ssip        := aia.ssip  or old.ssip;
    eip.meip        := aia.meip  or old.meip;
    eip.seip        := aia.seip  or old.seip;
    eip.ueip        := aia.ueip  or old.ueip;
    eip.heip        := aia.heip  or old.heip;
    eip.stime       := aia.stime or old.stime;
    eip.hgeip       := aia.hgeip;
    eip.imsic       := aia.imsic;
    eip.aplic_meip  := aia.aplic_meip;
    eip.aplic_seip  := aia.aplic_seip;
    eip.nmirq       := aia.nmirq or old.nmirq;
    return eip;
  end function;

  -- PMA
  --   RAM: all                                  1111 1111 1111
  --   ROM: busw?   burst cache   XRvalid        .000 1100 1011
  --   I/O: busw? amo   WRvalid                  .010 0000 0111


  -- Word 0: High type   00        01  10  11
  -- Word 1: Low       unallocated I/O RAM ROM
  -- Word 2: Cacheable (if RAM/ROM)
  -- Word 3: Wide bus
  constant pma_data_mask : word64_arr(0 to PMAENTRIES-1) := (
--    -- 0x00000000-0x7fffffff RAM cacheable wide
--    -- 0x80000000-0xbfffffff ROM cacheable wide
--    -- 0xc0000000-0xcfffffff ROM cacheable
--    -- 0xd0000000-0xffffffff unallocated
--    uext(std_logic_vector'(x"1fff"), 64),      -- High type
--    uext(std_logic_vector'(x"1f00"), 64),      -- Low
--    uext(std_logic_vector'(x"1fff"), 64),      -- Cacheable
--    uext(std_logic_vector'(x"00ff"), 64)       -- Wide bus

    -- Hypervisor tests etc
    -- 0x00000000-0x7fffffff RAM cacheable wide
    -- 0x80000000-0x8fffffff RAM uncacheable wide (Breker mailbox)
    -- 0x90000000-0x9fffffff I/O
    -- 0xa0000000-0xafffffff I/O (IMSIC@0xa00)
    -- 0xb0000000-0xbfffffff I/O
    -- 0xc0000000-0xcfffffff ROM wide cacheable
    -- 0xd0000000-0xdfffffff I/O
    -- 0xe0000000-0xefffffff I/O wide (ACLINT@0xe)
    -- 0xf0000000-0xffffffff I/O (UART@0xff9 and APLIC@0xfc0)
    uext(std_logic_vector'(x"11ff"), 64),      -- High type
    uext(std_logic_vector'(x"fe00"), 64),      -- Low
    uext(std_logic_vector'(x"10ff"), 64),      -- Cacheable
    uext(std_logic_vector'(x"51ff"), 64),      -- Wide bus (as in various config_local)
--    uext(std_logic_vector'(x"100f"), 64),      -- High type
--    uext(std_logic_vector'(x"ff08"), 64),      -- Low
--    uext(std_logic_vector'(x"100f"), 64),      -- Cacheable
--    uext(std_logic_vector'(x"51ff"), 64),      -- Wide bus (as in various config_local)
    others => zerow64
  );

  signal pma_addr : word64_arr(0 to PMAENTRIES - 1);
  signal pma_data : word64_arr(0 to PMAENTRIES - 1);

  -- Misc
  signal holdn          : std_ulogic;
  signal rst            : std_ulogic;
  signal rstx           : std_ulogic;

  -- Register File
  signal rfi            : iregfile_in_type;
  signal rfo            : iregfile_out_type;
  signal rff            : fregfile_in_type;

  -- BHT
  signal bhti           : nv_bht_in_type;
  signal bhto           : nv_bht_out_type;

  -- BTB
  signal btbi           : nv_btb_in_type;
  signal btbo           : nv_btb_out_type;

  -- Interrupts
  signal imsici         : imsic_in_type;
  signal imsico         : imsic_out_type;
  signal aia_eip        : nv_irq_in_type;
  signal ored_irq       : nv_irq_in_type;
  signal iu_irqo        : nv_irq_out_type;
  signal imsic_ack      : std_ulogic;

  -- RAS
  signal rasi           : nv_ras_in_type;
  signal raso           : nv_ras_out_type;

  -- Cache Controller
  --signal crami          : cram_in_type5;
  --signal cramo          : cram_out_type5;
  --signal sni            : snoopram_in_type5;
  --signal sno            : snoopram_out_type5;
  --signal snodp,snosp    : snoopram_out_type5;
  --signal bifi           : busif_in_type5;
  --signal bifo           : busif_out_type5;

  -- Trace Buffer
  signal tbi            : nv_trace_in_type;
  signal tbo            : nv_trace_out_type;


  -- Cache Signals
  signal ici          : nv_icache_in_type;
  signal ico          : nv_icache_out_type;
  signal dci          : nv_dcache_in_type;
  signal dco          : nv_dcache_out_type;

  signal csr_mmu      : nv_csr_out_type;    -- CSR values for MMU
  signal mmu_csr      : nv_csr_in_type;    -- CSR values for MMU

  -- Mul/Div Unit
  signal muli         : mul_in_type;
  signal mulo         : mul_out_type;
  signal divi         : div_in_type;
  signal divo         : div_out_type;

  signal c_perf       : std_logic_vector(31 downto 0);
  signal iu_cnt       : nv_counter_out_type;


  -- FPU
  signal fpi            : fpu5_in_type;
  signal fpia           : fpu5_in_async_type;
  signal fpo            : fpu5_out_type;
  signal fpoa           : fpu5_out_async_type;
  signal fpc_mosi       : l5_intreg_mosi_type;
  signal fpc_miso       : l5_intreg_miso_type;
  signal c2c_mosi       : l5_intreg_mosi_type;
  signal c2c_miso       : l5_intreg_miso_type;

  signal fs1_data       : std_logic_vector(cfg_c.fpulen - 1 downto 0);
  signal fs2_data       : std_logic_vector(cfg_c.fpulen - 1 downto 0);
  signal fs3_data       : std_logic_vector(cfg_c.fpulen - 1 downto 0);


  signal rff_fd         : std_logic_vector(cfg_c.fpulen - 1 downto 0);
  signal rff_rs1        : reg_t;
  signal rff_rs2        : reg_t;
  signal rff_rs3        : reg_t;
  signal rff_ren        : std_logic_vector(1 to 3);
--  signal rff_rd         : reg_t;
  signal rff_wen        : std_ulogic;

  signal rff_rdummy     : std_logic_vector(cfg_c.fpulen - 1 downto 0);

  signal fs1_word64     : word64;
  signal fs2_word64     : word64;
  signal fs3_word64     : word64;


  signal etrace         : nv_etrace_type;

  attribute sync_set_reset : string;
  attribute sync_set_reset of rst : signal is "true";

  signal itracei : itrace_in_type;
  signal itraceo : itrace_out_type;


begin

  -- Signal Assignments -----------------------------------------------------
  holdn                 <= ico.hold and dco.hold;

  tpo <= (
    eto     => etrace
  );

  -- PMA via masks
  pma_addr <= (others => (others => '0'));
  pma_data <= pma_data_mask;


  itrace : entity work.itracenv
    generic map (
      fabtech       => fabtech,
      memtech       => memtech,
      single_issue  => cfg_c.single_issue,
      dmen          => cfg_c.dmen,
      tbuf          => cfg_c.tbuf,
      disas         => disas,
      scantest      => scantest
    )
    port map (
      clk        => gclk,
      rstn       => rstx,
      itracei    => itracei,
      itraceo    => itraceo,
      fpo        => fpo,
      testen     => testen,
      testrst    => testrst
    );






  tbi.addr   <= itraceo.taddr;
  tbi.data   <= itraceo.idata;
  tbi.enable <= itraceo.enable;
  tbi.write  <= itraceo.write;

  -- Pipeline ---------------------------------------------------------------
  iu0 : iunv
    generic map (
      fabtech       => fabtech,
      memtech       => memtech,
      -- Core
      physaddr      => physaddr,
      addr_bits     => addr_bits,
      rstaddr       => cfg_c.rstaddr,
      perf_cnts     => cfg_c.perf_cnts,
      perf_evts     => cfg_c.perf_evts,
      perf_bits     => cfg_c.perf_bits,
      illegalTval0  => illegalTval0,
      no_muladd     => cfg_c.no_muladd,
      single_issue  => cfg_c.single_issue,
      -- Caches
      iways         => cfg_c.iways,
      dways         => cfg_c.dways,
      dlinesize     => cfg_c.dlinesize,
      itcmen        => itcmen,
      dtcmen        => dtcmen,
      -- MMU
      mmuen         => actual_mmuen,
      riscv_mmu     => actual_riscv_mmu,
      pmp_no_tor    => cfg_c.pmp_no_tor,
      pmp_entries   => cfg_c.pmp_entries,
      pmp_g         => cfg_c.pmp_g,
      pma_entries   => cfg_c.pma_entries,
      pma_masked    => cfg_c.pma_masked,
      asidlen       => cfg_c.asidlen,
      vmidlen       => cfg_c.vmidlen,
      -- Interrupts
      imsic         => cfg_c.imsic,
      -- RNMI
      rnmi_iaddr    => cfg_c.rnmi_iaddr,
      rnmi_xaddr    => cfg_c.rnmi_xaddr,
      -- Extensions
      ext_noelv     => cfg_c.ext_noelv,
      ext_noelvalu  => cfg_c.ext_noelvalu,
      ext_m         => cfg_c.ext_m,
      ext_a         => cfg_c.ext_a,
      ext_c         => cfg_c.ext_c,
      ext_h         => cfg_c.ext_h,
      ext_zcb       => cfg_c.ext_zcb,
      ext_zba       => cfg_c.ext_zba,
      ext_zbb       => cfg_c.ext_zbb,
      ext_zbc       => cfg_c.ext_zbc,
      ext_zbs       => cfg_c.ext_zbs,
      ext_zbkb      => cfg_c.ext_zbkb,
      ext_zbkc      => cfg_c.ext_zbkc,
      ext_zbkx      => cfg_c.ext_zbkx,
      ext_sscofpmf  => cfg_c.ext_sscofpmf,
      ext_shlcofideleg  => cfg_c.ext_shlcofideleg,
      ext_smcdeleg  => cfg_c.ext_smcdeleg,
      ext_sstc      => cfg_c.ext_sstc,
      ext_smaia     => cfg_c.ext_smaia,
      ext_ssaia     => cfg_c.ext_ssaia,
      ext_smstateen => cfg_c.ext_smstateen,
      ext_smrnmi    => cfg_c.ext_smrnmi,
      ext_ssdbltrp  => cfg_c.ext_ssdbltrp,
      ext_smdbltrp  => cfg_c.ext_smdbltrp,
      ext_smepmp    => cfg_c.ext_smepmp,
      ext_zicbom    => cfg_c.ext_zicbom,
      ext_zicond    => cfg_c.ext_zicond,
      ext_zimop     => cfg_c.ext_zimop,
      ext_zcmop     => cfg_c.ext_zcmop,
      ext_svadu     => cfg_c.ext_svadu,
      ext_zicfiss   => cfg_c.ext_zicfiss,
      ext_zicfilp   => cfg_c.ext_zicfilp,
      ext_svinval   => cfg_c.ext_svinval,
      ext_zfa       => actual_zfa,
      ext_zfh       => actual_zfh,
      ext_zfhmin    => actual_zfhmin,
      ext_zfbfmin   => actual_zfbfmin,
      mode_s        => cfg_c.mode_s,
      mode_u        => cfg_c.mode_u,
      dmen          => cfg_c.dmen,
      fpulen        => cfg_c.fpulen,
      fpuconf       => fpuconf,
      trigger       => cfg_c.trigger,
      -- Advanced Features
      late_branch   => cfg_c.late_branch,
      late_alu      => cfg_c.late_alu,
      ras           => cfg_c.ras,
      -- Misc
      pbaddr        => cfg_c.pbaddr,
      tbuf          => cfg_c.tbuf,
      scantest      => scantest,
      endian        => 1 -- endian
      )
    port map (
      clk           => gclk,
      rstn          => rstx,
      holdn         => holdn,
      ici           => ici,
      ico           => ico,
      bhti          => bhti,
      bhto          => bhto,
      btbi          => btbi,
      btbo          => btbo,
      rasi          => rasi,
      raso          => raso,
      dci           => dci,
      dco           => dco,
      rfi           => rfi,
      rfo           => rfo,
      imsici        => imsici,
      imsico        => imsico,
      irqi          => ored_irq,
      irqo          => iu_irqo,
      dbgi          => dbgi,
      dbgo          => dbgo,
      muli          => muli,
      mulo          => mulo,
      divi          => divi,
      divo          => divo,
      fpui          => fpi,
      fpuia         => fpia,
      fpuo          => fpo,
      fpuoa         => fpoa,
      cnt           => iu_cnt,
      itracei       => itracei,
      itraceo       => itraceo,
      pma_addr      => pma_addr,
      pma_data      => pma_data,
      csr_mmu       => csr_mmu,
      mmu_csr       => mmu_csr,
      cap           => capability,
      perf          => c_perf,
      tbo           => tbo,
      eto           => etrace,
      sclk          => clk,
      pwrd          => pwrd,
      testen        => testen,
      testrst       => testrst
      );

  -- Mul/Div Unit -----------------------------------------------------------
  mgen : if cfg_c.ext_m = 1 generate
    mul0 : mul64
      generic map (
        fabtech     => fabtech,
        arch        => mularch,
        split       => mulconf_int,
        scantest    => scantest
        )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        ctrl        => muli.ctrl,
        op1         => muli.op1,
        op2         => muli.op2,
        nready      => mulo.nready,
        mresult     => mulo.result,
        testen      => testen,
        testrst     => testrst
        );

    mulo.icc <= (others => '0');

    div0 : div64
      generic map (
        fabtech     => fabtech,
        scantest    => scantest,
        hiperf      => cfg_c.div_hiperf,
        small       => cfg_c.div_small
        )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        divi        => divi,
        divo        => divo,
        testen      => testen,
        testrst     => testrst
        );
  end generate; -- mgen

  nomgen : if cfg_c.ext_m = 0 generate
    divo  <= div_out_none;
    mulo  <= mul_out_none;
  end generate;


  -- Cache Controller -----------------------------------------------------------
  cc0: cctrl5nv
    generic map (
      iways      => cfg_c.iways,
      ilinesize  => cfg_c.ilinesize,
      iwaysize   => cfg_c.iwaysize,
      dways      => cfg_c.dways,
      dlinesize  => cfg_c.dlinesize,
      dwaysize   => cfg_c.dwaysize,
      dtagconf   => dtagconf,
      dusebw     => dusebw,
      itcmen     => itcmen,
      itcmabits  => itcmabits,
      itcmfrac   => itcmfrac,
      dtcmen     => dtcmen,
      dtcmabits  => dtcmabits,
      dtcmfrac   => dtcmfrac,
      itlbnum    => cfg_c.itlbnum,
      dtlbnum    => cfg_c.dtlbnum,
      -- RISCV
      htlbnum       => cfg_c.htlbnum,
      mmuen         => actual_mmuen,
      riscv_mmu     => actual_riscv_mmu,
      pmp_no_tor    => cfg_c.pmp_no_tor,
      pmp_entries   => cfg_c.pmp_entries,
      pmp_g         => cfg_c.pmp_g,
      pma_entries   => cfg_c.pma_entries,
      pma_masked    => cfg_c.pma_masked,
      asidlen       => cfg_c.asidlen,
      vmidlen       => cfg_c.vmidlen,
      ext_noelv     => cfg_c.ext_noelv,
      ext_a         => cfg_c.ext_a,
      ext_h         => cfg_c.ext_h,
      ext_smepmp    => cfg_c.ext_smepmp,
      ext_zicbom    => cfg_c.ext_zicbom,
      ext_svpbmt    => cfg_c.ext_svpbmt,
      ext_svnapot   => cfg_c.ext_svnapot,
      ext_zicfiss   => cfg_c.ext_zicfiss,
      tlb_pmp       => cfg_c.tlb_pmp,
      --
      cached     => cached,
      wbmask     => wbmask,
      busw       => busw,
      cdataw     => cdataw,
      tlbrepl    => cfg_c.tlbrepl,
      addrbits   => addr_bits,
      iphysbits  => iphys_bits,
      dphysbits  => dphys_bits
      )
    port map (
      rst      => rstx,
      clk      => gclk,
      ici      => ici,
      ico      => ico,
      dci      => dci,
      dco      => dco,
      ahbso    => ahbpnp,
      endian   => endian,
      crami    => crami,
      cramo    => cramo,
      bifi     => bifi,
      bifo     => bifo,
      sclk     => clk,
      fpc_mosi => fpc_mosi,
      fpc_miso => fpc_miso,
      c2c_mosi => c2c_mosi,
      c2c_miso => c2c_miso,
      csro     => csr_mmu,
      csri     => mmu_csr,
      --
      freeze   => dbgi.freeze,
      bootword => zerow,
      smpflush => zerow(1 downto 0),
      perf => c_perf
      );

  -- Unused
  fpc_miso       <= l5_intreg_miso_none;
  c2c_miso       <= l5_intreg_miso_none;

  cnt.icnt       <= iu_cnt.icnt;
  cnt.icmiss     <= c_perf(0);
  cnt.itlbmiss   <= c_perf(1);
  cnt.dcmiss     <= c_perf(2);
  cnt.dtlbmiss   <= c_perf(3);
  cnt.bpmiss     <= iu_cnt.bpmiss;
  cnt.hold       <= iu_cnt.hold;
  cnt.hold_issue <= iu_cnt.hold_issue;
  cnt.branch     <= iu_cnt.branch;

  -- Branch History Table ---------------------------------------------------
  bht0 : bhtnv
    generic map (
      tech              => memtech,
      nentries          => cfg_c.bhtentries,
      hlength           => cfg_c.bhtlength,
      predictor         => cfg_c.predictor,
      ext_c             => cfg_c.ext_c,
      dissue            => 1 - cfg_c.single_issue,
      testen            => scantest
      )
    port map (
      clk               => gclk,
      rstn              => rstx,
      bhti              => bhti,
      bhto              => bhto,
      holdn             => holdn,
      testin            => testin
    );

  -- Branch Target Buffer ----------------------------------------------------
  btb0 : btbdmnv
    generic map (
      nentries          => cfg_c.btbentries,
      pcbits            => pcaddr_bits,
      dissue            => 1 - cfg_c.single_issue
      )
    port map (
      clk               => gclk,
      rstn              => rstx,
      btbi              => btbi,
      btbo              => btbo
    );

  -- Return Address Stack ----------------------------------------------------
  rasgen : if cfg_c.ras >= 1 generate
    ras0 : rasnv
      generic map (
        depth             => 8,
        pcbits            => pcaddr_bits
      )
      port map (
        clk               => gclk,
        rstn              => rstx,
        rasi              => rasi,
        raso              => raso
      );
  end generate;

  -- IU Register File ----------------------------------------------------------
  ramrf : if (rfconf mod 16) = 0 generate
    rf0 : regfile64sramnv
      generic map (
        tech            => memtech,
        dissue          => 1 - cfg_c.single_issue,
        testen          => scantest
        )
      port map (
        clk             => gclk,
        rstn            => rstx,
        rdhold          => rfi.rdhold,
        waddr1          => rfi.waddr1,
        wdata1          => rfi.wdata1,
        we1             => rfi.wen1,
        waddr2          => rfi.waddr2,
        wdata2          => rfi.wdata2,
        we2             => rfi.wen2,
        raddr1          => rfi.raddr1,
        re1             => rfi.ren1,
        rdata1          => rfo.data1,
        raddr2          => rfi.raddr2,
        re2             => rfi.ren2,
        rdata2          => rfo.data2,
        raddr3          => rfi.raddr3,
        re3             => rfi.ren3,
        rdata3          => rfo.data3,
        raddr4          => rfi.raddr4,
        re4             => rfi.ren4,
        rdata4          => rfo.data4,
        testin          => testin
        );
  end generate;

  dffrf : if (rfconf mod 16) = 1 generate
  begin
    rf0 : regfile64dffnv
      generic map (
        tech            => memtech,
        wrfst           => WRT
        )
      port map (
        clk             => gclk,
        rstn            => rstx,
        rdhold          => rfi.rdhold,
        waddr1          => rfi.waddr1,
        wdata1          => rfi.wdata1,
        we1             => rfi.wen1,
        waddr2          => rfi.waddr2,
        wdata2          => rfi.wdata2,
        we2             => rfi.wen2,
        raddr1          => rfi.raddr1,
        re1             => rfi.ren1,
        rdata1          => rfo.data1,
        raddr2          => rfi.raddr2,
        re2             => rfi.ren2,
        rdata2          => rfo.data2,
        raddr3          => rfi.raddr3,
        re3             => rfi.ren3,
        rdata3          => rfo.data3,
        raddr4          => rfi.raddr4,
        re4             => rfi.ren4,
        rdata4          => rfo.data4
        );

  end generate;

  -- FPU Register File ----------------------------------------------------------
  fpu_regs : if cfg_c.fpulen /= 0 generate
   ramrff : if (rfconf mod 16) = 0 generate
    rf1 : regfile64sramnv
      generic map (
        tech            => memtech,
        reg0write       => 1,
        testen          => scantest
        )
      port map (
        clk             => gclk,
        rstn            => rstx,
        rdhold          => '0',
        waddr1          => fpo.rd,
        wdata1          => rff_fd,
        we1             => rff_wen,
        waddr2          => fpo.rd,      -- Dummy
        wdata2          => rff_fd,      -- Dummy
        we2             => '0',
        raddr1          => rff_rs1,
        re1             => rff_ren(1),
        rdata1          => fs1_data,
        raddr2          => rff_rs2,
        re2             => rff_ren(2),
        rdata2          => fs2_data,
        raddr3          => rff_rs3,
        re3             => rff_ren(3),
        rdata3          => fs3_data,
        raddr4          => rff_rs3,     -- Dummy
        re4             => '0',
        rdata4          => rff_rdummy,  -- Dummy
        testin          => testin
        );
   end generate;

   dffrff : if (rfconf mod 16) = 1 generate
    rf1 : regfile64dffnv
      generic map (
        tech            => memtech,
        wrfst           => WRT,
        reg0write       => 1,
        -- GHDL+Verilator circular logic fix,
        -- together with appropriate FPU changes.
        forward       => 0
        )
      port map (
        clk             => gclk,
        rstn            => rstx,
        rdhold          => '0',
        waddr1          => fpo.rd,
        wdata1          => rff_fd,
        we1             => rff_wen,
        waddr2          => fpo.rd,      -- Dummy
        wdata2          => rff_fd,      -- Dummy
        we2             => '0',
        raddr1          => rff_rs1,
        re1             => rff_ren(1),
        rdata1          => fs1_data,
        raddr2          => rff_rs2,
        re2             => rff_ren(2),
        rdata2          => fs2_data,
        raddr3          => rff_rs3,
        re3             => rff_ren(3),
        rdata3          => fs3_data,
        raddr4          => rff_rs3,     -- Dummy
        re4             => '0',
        rdata4          => rff_rdummy   -- Dummy
        );

    end generate;
  end generate;


  -- IMSIC interrupt register files --------------------------------------------
  imsic_int_files_gen : if cfg_c.imsic /= 0 generate
    imsic_files0 : imsic_int_files
     generic map (
       GEILEN            => GEILEN,
       S_EN              => cfg_c.mode_s,
       H_EN              => cfg_c.ext_h,
       plic              => 1,
       mnidentities      => cfg_c.mnintid,
       snidentities      => cfg_c.snintid,
       gnidentities      => cfg_c.gnintid
       )
     port map (
       rst               => rstn,
       clk               => clk,
       irqi              => irqi.imsic,
       acko              => imsic_ack,
       plic_meip         => irqi.aplic_meip,
       plic_seip         => irqi.aplic_seip,
       imsici            => imsici,
       imsico            => imsico,
       eip               => aia_eip
       );
  end generate;
  no_imsic_gen : if cfg_c.imsic = 0 generate
    imsico         <= imsic_out_none;
    aia_eip        <= nv_irq_in_none;
  end generate;
  ored_irq <= eip_or(aia_eip, irqi); -- Differenciate between the two

  drive_imsic_ack : process (imsic_ack, iu_irqo)
  begin
    irqo <= iu_irqo;
    if cfg_c.imsic /= 0 then
      irqo.imsic_ack <= imsic_ack;
    else
      irqo.imsic_ack <= '0';
    end if;
  end process;
  -- L1 Caches -----------------------------------------------------------------

  --cmem1 : cachemem5
  --  generic map (
  --    tech      => MEMTECH_MOD,
  --    iways     => iways,
  --    ilinesize => ilinesize,
  --    iidxwidth => iidxwidth,
  --    itagwidth => itagwidth,
  --    itcmen    => itcmen,
  --    itcmabits => itcmabits,
  --    itcmfrac  => itcmfrac,
  --    dways     => dways,
  --    dlinesize => dlinesize,
  --    didxwidth => didxwidth,
  --    dtagwidth => dtagwidth,
  --    dtagconf  => dtagconf + dtagconffudge,
  --    mbmode    => 1,
  --    dusebw    => dusebw,
  --    dtcmen    => dtcmen,
  --    dtcmabits => dtcmabits,
  --    dtcmfrac  => dtcmfrac,
  --    testen    => scantest
  --    )
  --  port map (
  --    rstn   => rstn,
  --    clk    => gclk,
  --    sclk   => clk,
  --    crami  => crami,
  --    cramo  => cramo,
  --    sni    => snish,
  --    sno    => snosh,
  --    testin => testin
  --    );

  -- Instruction Buffer -----------------------------------------------------
  tbmem_gen : if (cfg_c.tbuf /= 0) generate
    tbmem0 : tbufmemnv
      generic map (
        tech    => MEMTECH_MOD,
        tbuf    => cfg_c.tbuf,
        dwidth  => cdataw,
        testen  => scantest,
        proc    => 1
      )
      port map (
        clk      => gclk,
        trace_in => tbi,
        trace_out=> tbo,
        testin   => testin
      );
  end generate;

  notbmem_gen : if (cfg_c.tbuf = 0) generate
    tbo       <= nv_trace_out_type_none;
  end generate;

  -- FPU Unit ---------------------------------------------------------------
  nofpu_gen : if (cfg_c.fpulen = 0) generate
    fpo         <= fpu5_out_none;
  end generate;

  sp_fpu: if cfg_c.fpulen = 32 generate
    fs1_word64 <= (not zerow) & fs1_data;
    fs2_word64 <= (not zerow) & fs2_data;
    fs3_word64 <= (not zerow) & fs3_data;
  end generate;

  dp_fpu: if cfg_c.fpulen = 64 generate
    fs1_word64 <= fs1_data;
    fs2_word64 <= fs2_data;
    fs3_word64 <= fs3_data;
  end generate;

  fpu_gen : if cfg_c.fpulen /= 0 and fpuconf = 0 generate
    nano : nanofpunv
      generic map (
        fpulen    => cfg_c.fpulen,
        no_muladd => cfg_c.no_muladd
      )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        fpi         => fpi,
        fpia        => fpia,
        fpo         => fpo,
        fpoa        => fpoa,
        rs1         => rff_rs1,
        rs2         => rff_rs2,
        rs3         => rff_rs3,
        ren         => rff_ren,
        s1          => fs1_word64,
        s2          => fs2_word64,
        s3          => fs3_word64
      );

    rff_fd        <= fpo.data(rff_fd'range);
    rff_wen       <= fpo.wen
                     ;
  end generate;

  pfpu_gen : if cfg_c.fpulen /= 0 and fpuconf = 1 generate
    piped : pipefpunv
      generic map (
        fpulen      => cfg_c.fpulen,
        ext_zfa     => cfg_c.ext_zfa,
        ext_zfh     => cfg_c.ext_zfh,
        ext_zfhmin  => cfg_c.ext_zfhmin,
        ext_zfbfmin => cfg_c.ext_zfbfmin,
        mulconf     => mulconf_fpu
      )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        fpi         => fpi,
        fpia        => fpia,
        fpo         => fpo,
        fpoa        => fpoa,
        rs1         => rff_rs1,
        rs2         => rff_rs2,
        rs3         => rff_rs3,
        ren         => rff_ren,
        s1          => fs1_word64,
        s2          => fs2_word64,
        s3          => fs3_word64
      );

    rff_fd   <= fpo.data(rff_fd'range);
    rff_wen  <= fpo.wen
                ;
  end generate;


  -- 1-clock reset delay
  rstreg : process(clk)
  begin
    if rising_edge(clk) then
      rst <= rstn and (not dbgi.reset);
    end if;
  end process;

  rstx <= rst and rstn when ASYNC_RESET else rst;


-- pragma translate_off
  assert endian = '1'
    report "NOEL-V: Only little endian is supported"
    severity warning;
  --assert ( ((endian /= 0) = (ahbi.endian  /= '0') or ahbi.endian  = 'U') and
  --         ((endian /= 0) = (ahbsi.endian /= '0') or ahbsi.endian = 'U') )
  --  report "NOEL-V: Mismatch between endianness generic and AHB bus endianness signal"
  --  severity warning;
-- pragma translate_on

  assert not(cfg_c.ext_zfa = 1 and fpuconf = 0) report "Zfa will be deactivated due to nanofpu being selected" severity warning;
  assert not(cfg_c.ext_zfh = 1 and fpuconf = 0) report "Zfh will be deactivated due to nanofpu being selected" severity warning;

end;
