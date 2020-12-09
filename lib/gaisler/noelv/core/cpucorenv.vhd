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
use gaisler.noelvint.all;

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
    clk2x               : integer                       := 0;
    ahbpipe             : integer                       := 0;
    -- Caches
    icen                : integer range 0  to 1         := 0;  -- I$ Cache Enable
    irepl               : integer range 0  to 2         := 2;
    isets               : integer range 1  to 4         := 1;  -- I$ Sets/Ways
    ilinesize           : integer range 4  to 8         := 4;  -- I$ Cache Line Size (words)
    isetsize            : integer range 1  to 256       := 1;  -- I$ Cache Way Size (KiB)
    dcen                : integer range 0  to 1         := 0;  -- D$ Cache Enable
    drepl               : integer range 0  to 2         := 2;
    dsets               : integer range 1  to 4         := 1;  -- D$ Sets/Ways
    dlinesize           : integer range 4  to 8         := 4;  -- D$ Cache Line Size (words)
    dsetsize            : integer range 1  to 256       := 1;  -- D$ Cache Way Size (KiB)
    dsnoop              : integer range 0  to 6         := 0;  -- Enable Data Cache Snooping
    ilram               : integer range 0  to 1         := 0;
    ilramsize           : integer range 1  to 512       := 1;
    ilramstart          : integer range 0  to 255       := 16#8e#;
    dlram               : integer range 0  to 1         := 0;
    dlramsize           : integer range 1  to 512       := 1;
    dlramstart          : integer range 0  to 255       := 16#8f#;
    -- BHT
    bhtentries          : integer range 32 to 1024      := 256;-- BHT Number of Entries
    bhtlength           : integer range 2  to 10        := 5;  -- History Length
    predictor           : integer range 0  to 2         := 0;  -- Predictor
    -- BTB
    btbentries          : integer range 8  to 128       := 32; -- BTB Number of Entries
    btbsets             : integer range 1  to 8         := 1;  -- BTB Sets/Ways
    -- MMU
    mmuen               : integer range 0  to 2         := 0;  -- Enable MMU
    mmupgsz             : integer                       := 0;
    itlbnum             : integer range 2  to 64        := 8;
    dtlbnum             : integer range 2  to 64        := 8;
    tlb_type            : integer range 0  to 3         := 1;
    tlb_rep             : integer range 0  to 1         := 0;
    tlbforepl           : integer range 1  to 4         := 1;
    riscv_mmu           : integer range 0  to 3         := 1;
    pmp_no_tor          : integer range 0  to 1         := 0;  -- Disable PMP TOR
    pmp_entries         : integer range 0  to 16        := 16; -- Implemented PMP registers
    pmp_g               : integer range 0  to 10        := 0;  -- PMP grain is 2^(pmp_g + 2) bytes
    -- Extensions
    ext_m               : integer range 0  to 1         := 1;  -- M Base Extension Set
    ext_a               : integer range 0  to 1         := 0;  -- A Base Extension Set
    ext_c               : integer range 0  to 1         := 0;  -- C Base Extension Set
    ext_h               : integer range 0  to 1         := 0;  -- H Extension
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
    perf_cnts           : integer range 0  to 31        := 16; -- Number of performance counters
    perf_evts           : integer range 0  to 255       := 16; -- Number of performance events
    illegalTval0        : integer range 0  to 1         := 0;  -- Zero TVAL on illegal instruction
    no_muladd           : integer range 0  to 1         := 0;  -- 1 - multiply-add not supported
    single_issue        : integer range 0  to 1         := 0;  -- 1 - only one pipeline
    mularch             : integer                       := 0;  -- multiplier architecture
    div_hiperf          : integer                       := 0;
    div_small           : integer                       := 0;
    hw_fpu              : integer range 0  to 1         := 1;  -- 1 - use hw gpu
    rfreadhold          : integer range 0  to 1         := 0;  -- Register File Read Hold
    ft                  : integer                       := 0;  -- FT option
    scantest            : integer                       := 0;  -- scantest support
    endian              : integer
    );
  port (
    ahbclk      : in  std_ulogic; -- bus clock
    cpuclk      : in  std_ulogic; -- cpu clock
    gcpuclk     : in  std_ulogic; -- gated cpu clock
    fpuclk      : in  std_ulogic; -- gated fpu clock
    hclken      : in  std_ulogic; -- bus clock enable qualifier
    rstn        : in  std_ulogic;
    ahbi        : in  ahb_mst_in_type;
    ahbo        : out ahb_mst_out_type;
    ahbsi       : in  ahb_slv_in_type;
    ahbso       : in  ahb_slv_out_vector;
    irqi        : in  nv_irq_in_type;     -- irq in
    irqo        : out nv_irq_out_type;    -- irq out
    dbgi        : in  nv_debug_in_type;   -- debug in
    dbgo        : out nv_debug_out_type;  -- debug out
    cnt         : out nv_counter_out_type -- Perf event Out Port
    );
end;

architecture rtl of cpucorenv is

  constant ASYNC_RESET : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant MEMTECH_MOD : integer := memtech mod 65536;

  constant IRFBITS      : integer := 5;
  constant IREGNUM      : integer := 2 ** IRFBITS;
  constant WRT          : integer := 1;	-- enable write-through RAM

  constant iways        : integer := isets;
  constant iwaysize     : integer := isetsize;
  constant dways        : integer := dsets;
  constant dwaysize     : integer := dsetsize;

  constant iidxwidth    : integer := (log2(iwaysize) + 10) - (log2(ilinesize) + 2);
  constant itagwidth    : integer := physaddr - (log2(iwaysize) + 10) + 1;

  constant didxwidth    : integer := (log2(dwaysize) + 10) - (log2(dlinesize) + 2);
  constant dtagconf     : integer := cmemconf mod 4;
  constant dusebw       : integer := (cmemconf / 4) mod 2;
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

  signal csr_mmu      : csrtype;    -- CSR values for MMU

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
  signal rff_rd         : std_logic_vector(4 downto 0);
  signal rff_wen        : std_ulogic;

  signal fs1_word64     : word64;
  signal fs2_word64     : word64;
  signal fs3_word64     : word64;

  signal mtesti_none    : std_logic_vector(memtest_vlen-1 downto 0);


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
      pcbits        => pcbits,
      rstaddr       => rstaddr,
      disas         => disas,
      perf_cnts     => perf_cnts,
      perf_evts     => perf_evts,
      illegalTval0  => illegalTval0,
      no_muladd     => no_muladd,
      single_issue  => single_issue,
      -- Caches
      isets         => isets,
      dsets         => dsets,
      -- MMU
      mmuen         => mmuen,
      riscv_mmu     => actual_riscv_mmu,
      pmp_no_tor    => pmp_no_tor,
      pmp_entries   => pmp_entries,
      pmp_g         => pmp_g,
      pmp_msb       => physaddr - 1,
      -- Extensions
      ext_m         => ext_m,
      ext_a         => ext_a,
      ext_c         => ext_c,
      ext_h         => ext_h,
      mode_s        => mode_s,
      mode_u        => mode_u,
      dmen          => dmen,
      fpulen        => fpulen,
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
      clk           => gcpuclk,
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
      perf          => c_perf,
      tbo           => tbo,
      tbi           => tbi,
      sclk          => cpuclk,
      testen        => ahbsi.testen,
      testrst       => ahbsi.testrst
      );

  -- Mul/Div Unit -----------------------------------------------------------
  mgen : if ext_m = 1 generate
    mul0 : mul64
      generic map (
        fabtech     => fabtech,
        arch        => mularch,
        scantest    => scantest
        )
      port map (
        clk         => gcpuclk,
        rstn        => rstx,
        holdn       => holdn,
        muli        => muli,
        mulo        => mulo,
        testen      => ahbsi.testen,
        testrst     => ahbsi.testrst
        );
    div0 : div64
      generic map (
        fabtech     => fabtech,
        scantest    => scantest,
        hiperf      => div_hiperf,
        small       => div_small
        )
      port map (
        clk         => gcpuclk,
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
      isets         => isets,
      ilinesize     => ilinesize,
      isetsize      => isetsize,
      dsets         => dsets,
      dlinesize     => dlinesize,
      dsetsize      => dsetsize,
      dtagconf      => dtagconf,
      dusebw        => dusebw,
      -- MMU
      itlbnum       => itlbnum,
      dtlbnum       => dtlbnum,
      riscv_mmu     => actual_riscv_mmu,
      pmp_no_tor    => pmp_no_tor,
      pmp_entries   => pmp_entries,
      pmp_g         => pmp_g,
      ext_a         => ext_a,
      -- Misc
      cached        => cached,
      wbmask        => wbmask,
      busw          => busw,
      cdataw        => cdataw,
      icrepl        => tlbforepl,
      dcrepl        => tlbforepl,
      endian        => endian
      )
    port map (
      rst           => rstx,
      clk           => gcpuclk,
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
      csr           => csr_mmu,
      fpc_mosi      => fpc_mosi,
      fpc_miso      => fpc_miso,
      c2c_mosi      => c2c_mosi,
      c2c_miso      => c2c_miso,
      fpuholdn      => fpo.holdn,
      perf          => c_perf,
      hclk          => ahbclk,
      sclk          => cpuclk,
      hclken        => hclken
      );


  cnt.icnt     <= iu_cnt.icnt;
  cnt.icmiss   <= c_perf(0);
  cnt.itlbmiss <= c_perf(1);
  cnt.dcmiss   <= c_perf(2);
  cnt.dtlbmiss <= c_perf(3);

  -- Branch History Table ---------------------------------------------------
  bht0 : bhtnv
    generic map (
      tech              => memtech,
      nentries          => bhtentries,
      hlength           => bhtlength,
      predictor         => predictor,
      dualbranch        => 1,
      ext_c             => ext_c,
      testen            => scantest
      )
    port map (
      clk               => gcpuclk,
      rstn              => rstx,
      bhti              => bhti,
      bhto              => bhto,
      holdn             => holdn,
      testin            => ahbi.testin
    );

  -- Branch Target Buffer ----------------------------------------------------
  btb0 : btbnv
    generic map (
      nentries          => btbentries,
      nsets             => btbsets,
      pcbits            => pcbits,
      ext_c             => ext_c
      )
    port map (
      clk               => gcpuclk,
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
      clk               => gcpuclk,
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
        wrfst           => WRT,
        numregs         => IREGNUM,
        testen          => scantest,
        rfreadhold      => rfreadhold
        )
      port map (
        clk             => gcpuclk,
        rstn            => rstx,
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
        clk             => gcpuclk,
        rstn            => rstx,
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
        wrfst           => WRT,
        numregs         => 32,
        reg0write       => 1,
        testen          => scantest,
        rfreadhold      => rfreadhold
        )
      port map (
        clk             => gcpuclk,
        rstn            => rstx,
        waddr1          => rff_rd,
        wdata1          => rff_fd,
        we1             => rff_wen,
        waddr2          => rff_rd,      -- Dummy
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
        clk             => gcpuclk,
        rstn            => rstx,
        waddr1          => rff_rd,
        wdata1          => rff_fd,
        we1             => rff_wen,
        waddr2          => rff_rd,      -- Dummy
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
      dways     => dways,
      dlinesize => dlinesize,
      didxwidth => didxwidth,
      dtagwidth => dtagwidth,
      dtagconf  => dtagconf,
      dusebw    => dusebw,
      testen    => scantest
      )
    port map (
      rstn   => rstx,
      clk    => gcpuclk,
      sclk   => cpuclk,
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
        clk      => gcpuclk,
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
        clk         => fpuclk,
        rstn        => rstn,
        holdn       => holdn,
        e_inst      => fpi.inst,
        e_valid     => fpi.e_valid,
        e_nullify   => fpi.e_nullify,
        csrfrm      => fpi.csrfrm,
        s1          => fs1_word64,
        s2          => fs2_word64,
        s3          => fs3_word64,
        issue_id    => open,
        fpu_holdn   => fpo.holdn,
        ready_flop  => fpo.ready,
        commit      => fpi.commit,
        commitid    => "00000",
        lddata      => fpi.lddata,
        unissue     => fpi.flush,
        unissue_sid => "00000",
        rs1         => rff_rs1,
        rs2         => rff_rs2,
        rs3         => rff_rs3,
        ren         => rff_ren,
        rd          => rff_rd,
        wen         => rff_wen,
        flags_wen   => fpo.flags_wen,
        stdata      => fpo.data,
        flags       => fpo.flags
      );

    rff_fd   <= fpo.data(rff_fd'range);
  end generate;


  -- 1-clock reset delay
  rstreg : process(cpuclk)
  begin
    if rising_edge(cpuclk) then
      rst <= rstn and (not dbgi.reset);
    end if;
  end process;

  rstx <= rst and rstn when ASYNC_RESET else rst;

-- pragma translate_off
  assert endian = 1
    report "NOEL-V: Only little endian is supported"
    severity warning;
  assert ( ((endian/=0) = (ahbi.endian/='0') or ahbi.endian='U') and
           ((endian/=0) = (ahbsi.endian/='0') or ahbsi.endian='U') )
    report "NOEL-V: Mismatch between endianness generic and AHB bus endianness signal"
    severity warning;
-- pragma translate_on

end;
