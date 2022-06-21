------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity:      cpucorenv
-- File:        coucorenv.vhd
-- Author:      Nils Wessman, Cobham Gaisler AB
-- Description: Top-level NOEL-V components
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use ieee.numeric_std.all;
use grlib.riscv.all;
library techmap;
use techmap.gencomp.all;
use techmap.netcomp.all;
library gaisler;
use gaisler.noelv.XLEN;
use gaisler.noelv.nv_irq_in_type;
use gaisler.noelv.nv_irq_out_type;
use gaisler.noelv.nv_debug_in_type;
use gaisler.noelv.nv_debug_out_type;
use gaisler.noelv.nv_counter_out_type;
use gaisler.noelv.nv_etrace_out_type;
use gaisler.noelvint.all;
use gaisler.utilnv.u2vec;

entity cpucorenv is
  generic (
    hindex              : integer range 0  to 15        := 0;  -- hart index
    fabtech             : integer range 0  to NTECH     := DEFFABTECH;
    memtech             : integer                       := DEFMEMTECH;
    -- Misc
    dmen                : integer range 0  to 1         := 0;
    pbaddr              : integer                       := 16#90000#; -- Program buffer exe address
    tbuf                : integer                       := 0;  -- trace buffer size in kB
    cached              : integer                       := 0;
    wbmask              : integer                       := 0;
    busw                : integer                       := 64;
    cmemconf            : integer                       := 0;
    rfconf              : integer                       := 0;
    tcmconf             : integer                       := 0;
    mulconf             : integer                       := 0;
    -- Caches
    icen                : integer range 0  to 1         := 0;  -- I$ Cache Enable
    iways               : integer range 1  to 4         := 1;  -- I$ Sets/Ways
    ilinesize           : integer range 4  to 8         := 4;  -- I$ Cache Line Size (words)
    iwaysize            : integer range 1  to 256       := 1;  -- I$ Cache Way Size (KiB)
    dcen                : integer range 0  to 1         := 0;  -- D$ Cache Enable
    dways               : integer range 1  to 4         := 1;  -- D$ Sets/Ways
    dlinesize           : integer range 4  to 8         := 4;  -- D$ Cache Line Size (words)
    dwaysize            : integer range 1  to 256       := 1;  -- D$ Cache Way Size (KiB)
    -- BHT
    bhtentries          : integer range 32 to 1024      := 256;-- BHT Number of Entries
    bhtlength           : integer range 2  to 10        := 5;  -- History Length
    predictor           : integer range 0  to 2         := 0;  -- Predictor
    -- BTB
    btbentries          : integer range 8  to 128       := 32; -- BTB Number of Entries
    btbsets             : integer range 1  to 8         := 1;  -- BTB Sets/Ways
    -- MMU
    mmuen               : integer range 0  to 2         := 0;  -- Enable MMU
    itlbnum             : integer range 2  to 64        := 8;
    dtlbnum             : integer range 2  to 64        := 8;
    htlbnum             : integer range 1  to 64        := 8;
    tlbforepl           : integer range 1  to 4         := 1;
    riscv_mmu           : integer range 0  to 3         := 1;
    tlb_pmp             : integer range 0  to 1         := 1;  -- Do PMP via TLB
    pmp_no_tor          : integer range 0  to 1         := 0;  -- Disable PMP TOR
    pmp_entries         : integer range 0  to 16        := 16; -- Implemented PMP registers
    pmp_g               : integer range 0  to 10        := 0;  -- PMP grain is 2^(pmp_g + 2) bytes
    asidlen             : integer range 0 to  16        := 0;  -- Max 9 for Sv32
    vmidlen             : integer range 0 to  14        := 0;  -- Max 7 for Sv32
    -- Extensions
    ext_m               : integer range 0  to 1         := 1;  -- M Base Extension Set
    ext_a               : integer range 0  to 1         := 0;  -- A Base Extension Set
    ext_c               : integer range 0  to 1         := 0;  -- C Base Extension Set
    ext_h               : integer range 0  to 1         := 0;  -- H Extension
    ext_zba             : integer range 0  to 1         := 0;  -- Zba Extension
    ext_zbb             : integer range 0  to 1         := 0;  -- Zbb Extension
    ext_zbc             : integer range 0  to 1         := 0;  -- Zbc Extension
    ext_zbs             : integer range 0  to 1         := 0;  -- Zbs Extension
    ext_zbkb            : integer range 0  to 1         := 0;  -- Zbkb Extension
    ext_zbkc            : integer range 0  to 1         := 0;  -- Zbkc Extension
    ext_zbkx            : integer range 0  to 1         := 0;  -- Zbkx Extension
    ext_sscofpmf        : integer range 0  to 1         := 0;  -- Sscofpmf Extension
    mode_s              : integer range 0  to 1         := 0;  -- Supervisor Mode Support
    mode_u              : integer range 0  to 1         := 0;  -- User Mode Support
    fpulen              : integer range 0  to 128       := 0;  -- Floating-point precision
    trigger             : integer                       := 0;
    -- Advanced Features
    late_branch         : integer range 0  to 1         := 0;  -- Late Branch Support
    late_alu            : integer range 0  to 1         := 0;  -- Late ALUs Support
    -- Core
    physaddr            : integer range 32 to 56        := 32; -- Physical Addressing
    rstaddr             : integer                       := 16#00000#; -- reset vector (MSB)
    disas               : integer                       := 0;  -- Disassembly to console
    perf_cnts           : integer range 0  to 29        := 16; -- Number of performance counters
    perf_evts           : integer range 0  to 255       := 16; -- Number of performance events
    perf_bits           : integer range 0  to 64        := 64; -- Bits of performance counting
    illegalTval0        : integer range 0  to 1         := 0;  -- Zero TVAL on illegal instruction
    no_muladd           : integer range 0  to 1         := 0;  -- 1 - multiply-add not supported
    single_issue        : integer range 0  to 1         := 0;  -- 1 - only one pipeline
    mularch             : integer                       := 0;  -- multiplier architecture
    div_hiperf          : integer                       := 0;
    div_small           : integer                       := 0;
    hw_fpu              : integer range 0  to 3         := 1;  -- 1 - use hw fpu
    rfreadhold          : integer range 0  to 1         := 0;  -- Register File Read Hold
    scantest            : integer                       := 0;  -- scantest support
    endian              : integer
    );
  port (
    clk      : in  std_ulogic; -- cpu clock
    gclk     : in  std_ulogic; -- gated cpu clock
    rstn        : in  std_ulogic;
    ahbi        : in  ahb_mst_in_type;
    ahbo        : out ahb_mst_out_type;
    ahbsi       : in  ahb_slv_in_type;
    ahbso       : in  ahb_slv_out_vector;
    irqi        : in  nv_irq_in_type;     -- irq in
    irqo        : out nv_irq_out_type;    -- irq out
    dbgi        : in  nv_debug_in_type;   -- debug in
    dbgo        : out nv_debug_out_type;  -- debug out
    eto         : out nv_etrace_out_type;
    cnt         : out nv_counter_out_type -- Perf event Out Port
    );
end;

architecture rtl of cpucorenv is

  constant ASYNC_RESET : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant MEMTECH_MOD : integer := memtech mod 65536;

  constant IRFBITS      : integer := 5;
  constant IREGNUM      : integer := 2 ** IRFBITS;
  constant WRT          : integer := 1;	-- enable write-through RAM

  constant dtcmen    : integer := boolean'pos( (tcmconf mod 32) /= 0);
  constant dtcmabits : integer := (1-dtcmen) + (tcmconf mod 32);
  constant itcmen    : integer := boolean'pos( ((tcmconf/256) mod 32) /= 0 );
  constant itcmabits : integer := (1-itcmen) + ((tcmconf/256) mod 32);

  constant iidxwidth    : integer := (log2(iwaysize) + 10) - (log2(ilinesize) + 2);
  constant itagwidth    : integer := physaddr - (log2(iwaysize) + 10) + 1;

  constant didxwidth    : integer := (log2(dwaysize) + 10) - (log2(dlinesize) + 2);
  constant dtagconf     : integer := cmemconf mod 4;
  constant dusebw       : integer := (cmemconf / 4) mod 2;
  constant mulconf_int  : integer := mulconf mod 4;
  constant mulconf_fpu  : integer := (mulconf / 16) mod 4;
  function regen_fpuconf return integer is
  begin
    if hw_fpu = 3 then
      return 1;
    else
      return 0;
    end if;
  end;
  constant fpuconf      : integer := regen_fpuconf;
  function gen_capability return std_logic_vector is
    variable cap : std_logic_vector(6 downto 0) := (others => '0');
  begin
    cap(6 downto 3) := u2vec(NOELV_VERSION,4);
    return cap;
  end;
  constant capability : std_logic_vector(6 downto 0) := gen_capability;
  constant dtagwidth    : integer := physaddr - (log2(dwaysize) + 10) + 1;
  constant cdataw       : integer := 64;

  -- Ensures riscv_mmu is OK.
  -- Sv32 if and only if XLEN is 32, else Sv39 unless explicitly Sv48.
  function constrain_riscv_mmu return integer is
  begin
    if XLEN = 32 then
      return gaisler.mmucacheconfig.sv32;
    end if;
    if riscv_mmu = gaisler.mmucacheconfig.sv48 then
      return riscv_mmu;
    end if;

    return gaisler.mmucacheconfig.sv39;
  end;

  constant actual_riscv_mmu : integer := constrain_riscv_mmu;

  -- Returns how many bits are needed for PC.
  function max_pc_bits return integer is
    constant va : std_logic_vector := gaisler.mmucacheconfig.va(actual_riscv_mmu);
  begin
    if actual_riscv_mmu = gaisler.mmucacheconfig.sv32 or
       va'length > physaddr then
      return va'length;
    end if;

    return physaddr;
  end;

  constant pcbits       : integer := max_pc_bits;

  -- Misc
  signal gnd            : std_ulogic;
  signal vcc            : std_ulogic;
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

  -- RAS
  signal rasi           : nv_ras_in_type;
  signal raso           : nv_ras_out_type;

  -- Cache Controller
  signal crami          : nv_cram_in_type;
  signal cramo          : nv_cram_out_type;

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
  signal fpo            : fpu5_out_type;
  signal fpc_mosi       : nv_intreg_mosi_type;
  signal fpc_miso       : nv_intreg_miso_type;
  signal c2c_mosi       : nv_intreg_mosi_type;
  signal c2c_miso       : nv_intreg_miso_type;

  signal fs1_data       : std_logic_vector(fpulen - 1 downto 0);
  signal fs2_data       : std_logic_vector(fpulen - 1 downto 0);
  signal fs3_data       : std_logic_vector(fpulen - 1 downto 0);


  signal rff_fd         : std_logic_vector(fpulen - 1 downto 0);
  signal rff_rs1        : std_logic_vector(4 downto 0);
  signal rff_rs2        : std_logic_vector(4 downto 0);
  signal rff_rs3        : std_logic_vector(4 downto 0);
  signal rff_ren        : std_logic_vector(1 to 3);
--  signal rff_rd         : std_logic_vector(4 downto 0);
  signal rff_wen        : std_ulogic;

  signal fs1_word64     : word64;
  signal fs2_word64     : word64;
  signal fs3_word64     : word64;


  signal mtesti_none    : std_logic_vector(memtest_vlen - 1 downto 0);

  attribute sync_set_reset : string;
  attribute sync_set_reset of rst : signal is "true";

begin

  -- Signal Assignments -----------------------------------------------------
  gnd                   <= '0';
  vcc                   <= '1';
  holdn                 <= ico.hold and dco.hold;
  mtesti_none           <= (others => '0');

  -- Pipeline ---------------------------------------------------------------
  iu0 : iunv
    generic map (
      hindex        => hindex,
      fabtech       => fabtech,
      memtech       => memtech,
      -- Core
      physaddr      => physaddr,
      pcbits        => pcbits,
      rstaddr       => rstaddr,
      disas         => disas,
      perf_cnts     => perf_cnts,
      perf_evts     => perf_evts,
      perf_bits     => perf_bits,
      illegalTval0  => illegalTval0,
      no_muladd     => no_muladd,
      single_issue  => single_issue,
      -- Caches
      iways         => iways,
      dways         => dways,
      itcmen        => itcmen,
      dtcmen        => dtcmen,
      -- MMU
      mmuen         => mmuen,
      riscv_mmu     => actual_riscv_mmu,
      pmp_no_tor    => pmp_no_tor,
      pmp_entries   => pmp_entries,
      pmp_g         => pmp_g,
      -- Extensions
      ext_m         => ext_m,
      ext_a         => ext_a,
      ext_c         => ext_c,
      ext_h         => ext_h,
      ext_zba       => ext_zba,
      ext_zbb       => ext_zbb,
      ext_zbc       => ext_zbc,
      ext_zbs       => ext_zbs,
      ext_zbkb      => ext_zbkb,
      ext_zbkc      => ext_zbkc,
      ext_zbkx      => ext_zbkx,
      ext_sscofpmf  => ext_sscofpmf,
      mode_s        => mode_s,
      mode_u        => mode_u,
      dmen          => dmen,
      fpulen        => fpulen,
      fpuconf       => fpuconf,
      trigger       => trigger,
      -- Advanced Features
      late_branch   => late_branch,
      late_alu      => late_alu,
      -- Misc
      pbaddr        => pbaddr,
      tbuf          => tbuf,
      scantest      => scantest,
      endian        => endian
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
      irqi          => irqi,
      irqo          => irqo,
      dbgi          => dbgi,
      dbgo          => dbgo,
      muli          => muli,
      mulo          => mulo,
      divi          => divi,
      divo          => divo,
      fpui          => fpi,
      fpuo          => fpo,
      cnt           => iu_cnt,
      csr_mmu       => csr_mmu,
      mmu_csr       => mmu_csr,
      cap           => capability,
      perf          => c_perf,
      tbo           => tbo,
      tbi           => tbi,
      eto           => eto,
      sclk          => clk,
      testen        => ahbsi.testen,
      testrst       => ahbsi.testrst
      );

  -- Mul/Div Unit -----------------------------------------------------------
  mgen : if ext_m = 1 generate
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
        testen      => ahbsi.testen,
        testrst     => ahbsi.testrst
        );

    mulo.icc <= (others => '0');

    div0 : div64
      generic map (
        fabtech     => fabtech,
        scantest    => scantest,
        hiperf      => div_hiperf,
        small       => div_small
        )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        divi        => divi,
        divo        => divo,
        testen      => ahbsi.testen,
        testrst     => ahbsi.testrst
        );
  end generate; -- mgen

  nomgen : if ext_m = 0 generate
    divo  <= div_out_none;
    mulo  <= mul_out_none;
  end generate;

  -- Cache Controller -----------------------------------------------------------
  mmu0 : cctrlnv
    generic map  (
      hindex        => hindex,
      -- Core
      physaddr      => physaddr,
      -- Caches
      iways         => iways,
      ilinesize     => ilinesize,
      iwaysize      => iwaysize,
      dways         => dways,
      dlinesize     => dlinesize,
      dwaysize      => dwaysize,
      dtagconf      => dtagconf,
      dusebw        => dusebw,
      itcmen        => itcmen,
      itcmabits     => itcmabits,
      dtcmen        => dtcmen,
      dtcmabits     => dtcmabits,
      -- MMU
      itlbnum       => itlbnum,
      dtlbnum       => dtlbnum,
      htlbnum       => htlbnum,
      riscv_mmu     => actual_riscv_mmu,
      pmp_no_tor    => pmp_no_tor,
      pmp_entries   => pmp_entries,
      pmp_g         => pmp_g,
      asidlen       => asidlen,
      vmidlen       => vmidlen,
      ext_a         => ext_a,
      ext_h         => ext_h,
      tlb_pmp       => tlb_pmp,
      -- Misc
      cached        => cached,
      wbmask        => wbmask,
      busw          => busw,
      cdataw        => cdataw,
      icrepl        => tlbforepl,
      dcrepl        => tlbforepl,
      hrepl         => tlbforepl,
      mmuen         => mmuen,
      endian        => endian
      )
    port map (
      rst           => rstx,
      clk           => gclk,
      ici           => ici,
      ico           => ico,
      dci           => dci,
      dco           => dco,
      ahbi          => ahbi,
      ahbo          => ahbo,
      ahbsi         => ahbsi,
      ahbso         => ahbso,
      crami         => crami,
      cramo         => cramo,
      sclk          => clk,
      csro          => csr_mmu,
      csri          => mmu_csr,
      fpc_mosi      => fpc_mosi,
      fpc_miso      => fpc_miso,
      c2c_mosi      => c2c_mosi,
      c2c_miso      => c2c_miso,
      freeze        => dbgi.freeze,
      bootword      => zero32,
      smpflush      => zero32(1 downto 0),
      --fpuholdn      => fpo.holdn,
      perf          => c_perf
      );


  cnt.icnt     <= iu_cnt.icnt;
  cnt.icmiss   <= c_perf(0);
  cnt.itlbmiss <= c_perf(1);
  cnt.dcmiss   <= c_perf(2);
  cnt.dtlbmiss <= c_perf(3);
  cnt.bpmiss   <= iu_cnt.bpmiss;

  -- Branch History Table ---------------------------------------------------
  bht0 : bhtnv
    generic map (
      tech              => memtech,
      nentries          => bhtentries,
      hlength           => bhtlength,
      predictor         => predictor,
      ext_c             => ext_c,
      dissue            => 1 - single_issue,
      testen            => scantest
      )
    port map (
      clk               => gclk,
      rstn              => rstx,
      bhti              => bhti,
      bhto              => bhto,
      holdn             => holdn,
      testin            => ahbi.testin
    );

  -- Branch Target Buffer ----------------------------------------------------
  btb0 : btbdmnv
    generic map (
      nentries          => btbentries,
      pcbits            => pcbits,
      dissue            => 1 - single_issue
      )
    port map (
      clk               => gclk,
      rstn              => rstx,
      btbi              => btbi,
      btbo              => btbo
    );

  -- Return Address Stack ----------------------------------------------------
  ras0 : rasnv
    generic map (
      depth             => 8,
      pcbits            => pcbits
      )
    port map (
      clk               => gclk,
      rstn              => rstx,
      rasi              => rasi,
      raso              => raso
    );

  -- IU Register File ----------------------------------------------------------
  ramrf : if (rfconf mod 16) = 0 generate
    rf0 : regfile64sramnv
      generic map (
        tech            => memtech,
        abits           => IRFBITS,
        dbits           => XLEN,
        numregs         => IREGNUM,
        dissue          => 1 - single_issue,
        testen          => scantest
        )
      port map (
        clk             => gclk,
        rstn            => rstx,
        rdhold          => rfi.rdhold,
        waddr1          => rfi.waddr1(IRFBITS-1 downto 0),
        wdata1          => rfi.wdata1,
        we1             => rfi.wen1,
        waddr2          => rfi.waddr2(IRFBITS-1 downto 0),
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
        testin          => ahbi.testin
        );
  end generate;

  dffrf : if rfconf = 1 generate
    rf0 : regfile64dffnv
      generic map (
        tech            => memtech,
        abits           => IRFBITS,
        dbits           => XLEN,
        wrfst           => WRT,
        numregs         => IREGNUM
        )
      port map (
        clk             => gclk,
        rstn            => rstx,
        rdhold          => rfi.rdhold,
        waddr1          => rfi.waddr1(IRFBITS-1 downto 0),
        wdata1          => rfi.wdata1,
        we1             => rfi.wen1,
        waddr2          => rfi.waddr2(IRFBITS-1 downto 0),
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
  fpu_regs : if fpulen /= 0 generate
   ramrff : if (rfconf mod 16) = 0 generate
    rf1 : regfile64sramnv
      generic map (
        tech            => memtech,
        abits           => 5,
        dbits           => fpulen,
        numregs         => 32,
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
        rdata4          => open,
        testin          => ahbi.testin
        );
   end generate;

   dffrff : if rfconf = 1 generate
    rf1 : regfile64dffnv
      generic map (
        tech            => memtech,
        abits           => 5,
        dbits           => fpulen,
        wrfst           => WRT,
        numregs         => 32,
        reg0write       => 1
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
        rdata4          => open
        );
   end generate;

  end generate;

  -- L1 Caches -----------------------------------------------------------------

  cmem1 : cachememnv
    generic map (
      tech      => MEMTECH_MOD,
      iways     => iways,
      ilinesize => ilinesize,
      iidxwidth => iidxwidth,
      itagwidth => itagwidth,
      itcmen    => itcmen,
      itcmabits => itcmabits,
      dways     => dways,
      dlinesize => dlinesize,
      didxwidth => didxwidth,
      dtagwidth => dtagwidth,
      dtagconf  => dtagconf,
      dusebw    => dusebw,
      dtcmen    => dtcmen,
      dtcmabits => dtcmabits,
      testen    => scantest
      )
    port map (
      rstn   => rstx,
      clk    => gclk,
      sclk   => clk,
      crami  => crami,
      cramo  => cramo,
      testin => ahbi.testin
      );

  -- Instruction Buffer -----------------------------------------------------
  tbmem_gen : if (tbuf /= 0) generate
    tbmem0 : tbufmemnv
      generic map (
        tech    => MEMTECH_MOD,
        tbuf    => tbuf,
        dwidth  => cdataw,
        testen  => scantest,
        proc    => 1
      )
      port map (
        clk      => gclk,
        di       => tbi,
        do       => tbo,
        testin   => ahbi.testin
      );
  end generate;

  notbmem_gen : if (tbuf = 0) generate
    tbo       <= nv_trace_out_type_none;
  end generate;

  -- FPU Unit ---------------------------------------------------------------
  nofpu_gen : if (fpulen = 0) generate
    fpo         <= fpu5_out_none;
  end generate;

  sp_fpu: if fpulen = 32 generate
    fs1_word64 <= onesw64(63 downto 32) & fs1_data;
    fs2_word64 <= onesw64(63 downto 32) & fs2_data;
    fs3_word64 <= onesw64(63 downto 32) & fs3_data;
  end generate;

  dp_fpu: if fpulen = 64 generate
    fs1_word64 <= fs1_data;
    fs2_word64 <= fs2_data;
    fs3_word64 <= fs3_data;
  end generate;


  fpu_gen : if fpulen /= 0 and hw_fpu = 1 generate
    nano : nanofpunv
      generic map (
        fpulen    => fpulen,
        no_muladd => no_muladd
      )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        e_inst      => fpi.inst,
        e_valid     => fpi.e_valid,
        e_nullify   => fpi.e_nullify,
        issue_id    => fpi.issue_id,
        csrfrm      => fpi.csrfrm,
        s1          => fs1_word64,
        s2          => fs2_word64,
        s3          => fs3_word64,
        fpu_holdn   => fpo.holdn,
        ready_flop  => fpo.ready,
        commit      => fpi.commit,
        commit_id   => fpi.commit_id,
        lddata_id   => fpi.data_id,
        lddata_now  => fpi.data_valid,
        lddata      => fpi.data,
        unissue     => fpi.unissue,
        unissue_id  => fpi.unissue_id,
        rs1         => rff_rs1,
        rs2         => rff_rs2,
        rs3         => rff_rs3,
        ren         => rff_ren,
        rd          => fpo.rd,
        wen         => fpo.wen,
        stdata      => fpo.data,
        flags_wen   => fpo.flags_wen,
        flags       => fpo.flags,
        now2int     => fpo.now2int,
        id2int      => fpo.id2int,
        stdata2int  => fpo.data2int,
        flags2int   => fpo.flags2int,
        mode_in     => fpi.mode,
        wb_mode     => fpo.mode,
        wb_id       => fpo.wb_id,
        idle        => fpo.idle,
        events      => fpo.events
      );

    rff_fd        <= fpo.data(rff_fd'range);
    rff_wen       <= fpo.wen
                     ;
  end generate;

  pfpu_gen : if fpulen /= 0 and hw_fpu = 3 generate
    piped : pipefpunv
      generic map (
        fpulen    => fpulen,
        mulconf   => mulconf_fpu
      )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        e_inst      => fpi.inst,
        e_valid     => fpi.e_valid,
        e_nullify   => fpi.e_nullify,
        issue_id    => fpi.issue_id,
        csrfrm      => fpi.csrfrm,
        s1          => fs1_word64,
        s2          => fs2_word64,
        s3          => fs3_word64,
        fpu_holdn   => fpo.holdn,
        ready_flop  => fpo.ready,
        commit      => fpi.commit,
        commit_id   => fpi.commit_id,
        lddata_id   => fpi.data_id,
        lddata_now  => fpi.data_valid,
        lddata      => fpi.data,
        unissue     => fpi.unissue,
        unissue_id  => fpi.unissue_id,
        rs1         => rff_rs1,
        rs2         => rff_rs2,
        rs3         => rff_rs3,
        ren         => rff_ren,
        rd          => fpo.rd,
        wen         => fpo.wen,
        stdata      => fpo.data,
        flags_wen   => fpo.flags_wen,
        flags       => fpo.flags,
        now2int     => fpo.now2int,
        id2int      => fpo.id2int,
        stdata2int  => fpo.data2int,
        flags2int   => fpo.flags2int,
        mode_in     => fpi.mode,
        wb_mode     => fpo.mode,
        wb_id       => fpo.wb_id,
        idle        => fpo.idle,
        events      => fpo.events,
        ctrl        => fpi.ctrl
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
  assert endian = 1
    report "NOEL-V: Only little endian is supported"
    severity warning;
  assert ( ((endian /= 0) = (ahbi.endian  /= '0') or ahbi.endian  = 'U') and
           ((endian /= 0) = (ahbsi.endian /= '0') or ahbsi.endian = 'U') )
    report "NOEL-V: Mismatch between endianness generic and AHB bus endianness signal"
    severity warning;
-- pragma translate_on

end;
