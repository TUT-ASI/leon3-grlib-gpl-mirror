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
-- Entity:      noelv_cpu_cfg
-- File:        noelv_cpu_cfg.vhd
-- Author:      Nils Wessman Cobham Gaisler AB
-- Description: NOEL-V custom CPU configuration
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library gaisler;

package noelv_cpu_cfg is

  -- CPU configurations type
  type nv_cpu_cfg_type is record
    single_issue  : integer;  -- Not used, set directly via cfg
    ext_m         : integer;
    ext_a         : integer;
    ext_c         : integer;
    ext_h         : integer;
    ext_zcb       : integer;
    ext_zba       : integer;
    ext_zbb       : integer;
    ext_zbc       : integer;
    ext_zbs       : integer;
    ext_zbkb      : integer;
    ext_zbkc      : integer;
    ext_zbkx      : integer;
    ext_sscofpmf  : integer;
    ext_shlcofideleg : integer;
    ext_smcdeleg  : integer;
    ext_sstc      : integer;
    ext_smaia     : integer;
    ext_ssaia     : integer;
    ext_smstateen : integer;
    ext_smrnmi    : integer;
    ext_ssdbltrp  : integer;
    ext_smdbltrp  : integer;
    ext_smepmp    : integer;
    ext_svadu     : integer;
    ext_svpbmt    : integer;
    ext_svnapot   : integer;
    imsic         : integer;
    mnintid       : integer;
    snintid       : integer;
    gnintid       : integer;
    rnmi_iaddr    : integer;
    rnmi_xaddr    : integer;
    ext_noelv     : integer;
    ext_noelvalu  : integer;
    ext_zicbom    : integer;
    ext_zicond    : integer;
    ext_zimop     : integer;
    ext_zcmop     : integer;
    ext_zicfiss   : integer;
    ext_zicfilp   : integer;
    ext_svinval   : integer;
    ext_zfa       : integer;
    ext_zfh       : integer;
    ext_zfhmin    : integer;
    ext_zfbfmin   : integer;
    mode_s        : integer;
    mode_u        : integer;
    fpulen        : integer;
    pmp_no_tor    : integer;
    pmp_entries   : integer;
    pmp_g         : integer;
    pma_entries   : integer;
    pma_masked    : integer;
    asidlen       : integer;
    vmidlen       : integer;
    perf_cnts     : integer;
    perf_evts     : integer;
    perf_bits     : integer;
    tbuf          : integer;
    trigger       : integer;
    icen          : integer;
    iways         : integer;
    iwaysize      : integer;
    ilinesize     : integer;
    dcen          : integer;
    dways         : integer;
    dwaysize      : integer;
    dlinesize     : integer;
    mmuen         : integer;
    itlbnum       : integer;
    dtlbnum       : integer;
    htlbnum       : integer;
    tlbrepl       : integer range 1  to 4;
    riscv_mmu     : integer range 0  to 3;
    tlb_pmp       : integer range 0  to 1;  -- Do PMP via TLB
    div_hiperf    : integer;
    div_small     : integer;
    no_muladd     : integer range 0  to 1;  -- 1 - multiply-add not supported
    late_branch   : integer;
    late_alu      : integer;
    ras           : integer;
    bhtentries    : integer;
    bhtlength     : integer;
    predictor     : integer;
    btbentries    : integer;
    btbsets       : integer;
    dmen          : integer;
    pbaddr        : integer;
    rstaddr       : integer; -- reset vector (MSB)
  end record;

  type cfg_type is array (natural range <>) of nv_cpu_cfg_type;
  type cfg_setup_type is record
    typ     : integer;
    fpu     : integer;
    sissue  : integer;
  end record;


  constant cfg_custom0 : nv_cpu_cfg_type := (
    single_issue  => 0,
    ext_m         => 1,
    ext_a         => 1,
    ext_c         => 0,
    ext_h         => 1,
    ext_zcb       => 1,
    ext_zba       => 1,
    ext_zbb       => 1,
    ext_zbc       => 1,
    ext_zbs       => 1,
    ext_zbkb      => 1,
    ext_zbkc      => 1,
    ext_zbkx      => 1,
    ext_sscofpmf  => 1,
    ext_shlcofideleg => 1,
    ext_smcdeleg  => 1,
    ext_sstc      => 1,
    ext_smaia     => 1,
    ext_ssaia     => 1,
    ext_smstateen => 1,
    ext_smrnmi    => 1,
    ext_ssdbltrp  => 1,
    ext_smdbltrp  => 1,
    ext_smepmp    => 1,
    ext_svadu     => 1,
    ext_svpbmt    => 1,
    ext_svnapot   => 1,
    imsic         => 1,
    mnintid       => 63,
    snintid       => 63,
    gnintid       => 63,
    rnmi_iaddr    => 16#30010#,
    rnmi_xaddr    => 16#30011#,
    ext_noelv     => 1,
    ext_noelvalu  => 1,
    ext_zicbom    => 1,
    ext_zicond    => 1,
    ext_zimop     => 1,
    ext_zcmop     => 1,
    ext_zicfiss   => 0,
    ext_zicfilp   => 0,
    ext_svinval   => 1,
    ext_zfa       => 1,
    ext_zfh       => 1,
    ext_zfhmin    => 1,
    ext_zfbfmin   => 0,
    mode_s        => 1,
    mode_u        => 1,
    fpulen        => 64,
    pmp_no_tor    => 0,
    pmp_entries   => 8,
    pmp_g         => 10,
    pma_entries   => 8,
    pma_masked    => 0,
    asidlen       => 0,
    vmidlen       => 0,
    perf_cnts     => 16,
    perf_evts     => 32,
    perf_bits     => 32,
    tbuf          => 4,
    trigger       => 32*0 + 16*1 + 2,
    icen          => 1,
    iways         => 4,
    iwaysize      => 4,
    ilinesize     => 8,
    dcen          => 1,
    dways         => 4,
    dwaysize      => 4,
    dlinesize     => 8,
    mmuen         => 1,
    itlbnum       => 8,
    dtlbnum       => 8,
    htlbnum       => 8,
    tlbrepl       => 1,
    riscv_mmu     => 2,
    tlb_pmp       => 0,
    div_hiperf    => 1,
    div_small     => 0,
    no_muladd     => 0,
    late_branch   => 1,
    late_alu      => 1,
    ras           => 2,
    bhtentries    => 128,
    bhtlength     => 5,
    predictor     => 2,
    btbentries    => 16,
    btbsets       => 2,
    dmen          => 1,
    pbaddr        => 16#90000#,
    rstaddr       => 16#C0000#
  );

  constant cfg_none : nv_cpu_cfg_type := (
    single_issue  => 0,
    ext_m         => 0,
    ext_a         => 0,
    ext_c         => 0,
    ext_h         => 0,
    ext_zcb       => 0,
    ext_zba       => 0,
    ext_zbb       => 0,
    ext_zbc       => 0,
    ext_zbs       => 0,
    ext_zbkb      => 0,
    ext_zbkc      => 0,
    ext_zbkx      => 0,
    ext_sscofpmf  => 0,
    ext_shlcofideleg => 0,
    ext_smcdeleg  => 0,
    ext_sstc      => 0,
    ext_smaia     => 0,
    ext_ssaia     => 0,
    ext_smstateen => 0,
    ext_smrnmi    => 0,
    ext_ssdbltrp  => 0,
    ext_smdbltrp  => 0,
    ext_smepmp    => 0,
    ext_svadu     => 0,
    ext_svpbmt    => 0,
    ext_svnapot   => 0,
    imsic         => 0,
    mnintid       => 63,
    snintid       => 63,
    gnintid       => 63,
    rnmi_iaddr    => 0,
    rnmi_xaddr    => 0,
    ext_noelv     => 0,
    ext_noelvalu  => 0,
    ext_zicbom    => 0,
    ext_zicond    => 0,
    ext_zimop     => 0,
    ext_zcmop     => 0,
    ext_zicfiss   => 0,
    ext_zicfilp   => 0,
    ext_svinval   => 0,
    ext_zfa       => 0,
    ext_zfh       => 0,
    ext_zfhmin    => 0,
    ext_zfbfmin   => 0,
    mode_s        => 0,
    mode_u        => 0,
    fpulen        => 0,
    pmp_no_tor    => 0,
    pmp_entries   => 0,
    pmp_g         => 0,
    pma_entries   => 0,
    pma_masked    => 0,
    asidlen       => 0,
    vmidlen       => 0,
    perf_cnts     => 0,
    perf_evts     => 0,
    perf_bits     => 0,
    tbuf          => 0,
    trigger       => 0,
    icen          => 0,
    iways         => 4,
    iwaysize      => 4,
    ilinesize     => 8,
    dcen          => 0,
    dways         => 4,
    dwaysize      => 4,
    dlinesize     => 8,
    mmuen         => 0,
    itlbnum       => 2,
    dtlbnum       => 2,
    htlbnum       => 1,
    tlbrepl       => 1,
    riscv_mmu     => 2,
    tlb_pmp       => 0,
    div_hiperf    => 0,
    div_small     => 0,
    no_muladd     => 0,
    late_branch   => 0,
    late_alu      => 0,
    ras           => 0,
    bhtentries    => 32,
    bhtlength     => 2,
    predictor     => 0,
    btbentries    => 8,
    btbsets       => 1,
    dmen          => 0,
    pbaddr        => 0,
    rstaddr       => 0
  );



  constant cfg_a : cfg_type(0 to 7) := (
    -- HP
    0 => (
      single_issue  => 0, -- Not Used
      ext_m         => 1,
      ext_a         => 1,
      ext_c         => 1,
      ext_h         => 1,
      ext_zcb       => 1,
      ext_zba       => 1,
      ext_zbb       => 1,
      ext_zbc       => 1,
      ext_zbs       => 1,
      ext_zbkb      => 1,
      ext_zbkc      => 1,
      ext_zbkx      => 1,
      ext_sscofpmf  => 1,
      ext_shlcofideleg => 1,
      ext_smcdeleg  => 1,
      ext_sstc      => 1,
      ext_smaia     => 1,
      ext_ssaia     => 1,
      ext_smstateen => 1,
      ext_smrnmi    => 1,
      ext_ssdbltrp  => 1,
      ext_smdbltrp  => 1,
      ext_smepmp    => 1,
      ext_svadu     => 1,
      ext_svpbmt    => 1,
      ext_svnapot   => 1,
      imsic         => 1,
      mnintid       => 63,
      snintid       => 63,
      gnintid       => 63,
      rnmi_iaddr    => 16#30010#,
      rnmi_xaddr    => 16#30011#,
      ext_noelv     => 1,
      ext_noelvalu  => 1,
      ext_zicbom    => 1,
      ext_zicond    => 1,
      ext_zimop     => 1,
      ext_zcmop     => 1,
      ext_zicfiss   => 1,
      ext_zicfilp   => 1,
      ext_svinval   => 1,
      ext_zfa       => 1,
      ext_zfh       => 1,
      ext_zfhmin    => 1,
      ext_zfbfmin   => 1,
      mode_s        => 1,
      mode_u        => 1,
      fpulen        => 64,
      pmp_no_tor    => 0,
      pmp_entries   => 8,
      pmp_g         => 10,
      pma_entries   => 8,
      pma_masked    => 1,
      asidlen       => 8,
      vmidlen       => 4,
      perf_cnts     => 16,
      perf_evts     => 128,
      perf_bits     => 32,
      tbuf          => 4,
      trigger       => 32*2 + 16*1 + 2,
      icen          => 1,
      iways         => 4,
      iwaysize      => 4,
      ilinesize     => 8,
      dcen          => 1,
      dways         => 4,
      dwaysize      => 4,
      dlinesize     => 8,
      mmuen         => 1,
      itlbnum       => 16,
      dtlbnum       => 16,
      htlbnum       => 16,
      tlbrepl       => 1,
--      riscv_mmu     => 2,
      riscv_mmu     => 3,
      tlb_pmp       => 0,
      div_hiperf    => 1,
      div_small     => 0,
      no_muladd     => 0,
      late_branch   => 1,
      late_alu      => 1,
      ras           => 2,
      bhtentries    => 128,
--      bhtentries    => 512,
      bhtlength     => 5,
--      bhtlength     => 8,
      predictor     => 2,
      btbentries    => 16,
--      btbentries    => 128,
      btbsets       => 2,
--      btbsets       => 4),
      dmen          => 1,
      pbaddr        => 16#90000#,
      rstaddr       => 16#C0000#
    ),

    -- GP
    1 => (
      single_issue  => 0, -- Not Used
      ext_m         => 1,
      ext_a         => 1,
      ext_c         => 1,
      ext_h         => 1,
      ext_zcb       => 1,
      ext_zba       => 1,
      ext_zbb       => 1,
      ext_zbc       => 1,
      ext_zbs       => 1,
      ext_zbkb      => 1,
      ext_zbkc      => 1,
      ext_zbkx      => 1,
      ext_sscofpmf  => 1,
      ext_shlcofideleg => 1,
      ext_smcdeleg  => 1,
      ext_sstc      => 1,
      ext_smaia     => 1,
      ext_ssaia     => 1,
      ext_smstateen => 1,
      ext_smrnmi    => 1,
      ext_ssdbltrp  => 1,
      ext_smdbltrp  => 1,
      ext_smepmp    => 1,
      ext_svadu     => 1,
      ext_svpbmt    => 1,
      ext_svnapot   => 1,
      imsic         => 1,
      mnintid       => 63,
      snintid       => 63,
      gnintid       => 63,
      rnmi_iaddr    => 16#30010#,
      rnmi_xaddr    => 16#30011#,
      ext_noelv     => 1,
      ext_noelvalu  => 1,
      ext_zicbom    => 1,
      ext_zicond    => 1,
      ext_zimop     => 1,
      ext_zcmop     => 1,
      ext_zicfiss   => 1,
      ext_zicfilp   => 1,
      ext_svinval   => 1,
      ext_zfa       => 1,
      ext_zfh       => 1,
      ext_zfhmin    => 1,
      ext_zfbfmin   => 1,
      mode_s        => 1,
      mode_u        => 1,
      fpulen        => 64,
      pmp_no_tor    => 0,
      pmp_entries   => 8,
      pmp_g         => 10,
      pma_entries   => 8,
      pma_masked    => 1,
      asidlen       => 8,
      vmidlen       => 4,
      perf_cnts     => 16,
      perf_evts     => 128,
      perf_bits     => 32,
      tbuf          => 4,
      trigger       => 32*2 + 16*1 + 2,
      icen          => 1,
      iways         => 4,
      iwaysize      => 4,
      ilinesize     => 8,
      dcen          => 1,
      dways         => 4,
      dwaysize      => 4,
      dlinesize     => 8,
      mmuen         => 1,
      itlbnum       => 16,
      dtlbnum       => 16,
      htlbnum       => 16,
      tlbrepl       => 1,
      riscv_mmu     => 2,
      tlb_pmp       => 0,
      div_hiperf    => 1,
      div_small     => 0,
      no_muladd     => 0,
      late_branch   => 1,
      late_alu      => 1,
      ras           => 2,
      bhtentries    => 128,
      bhtlength     => 5,
      predictor     => 2,
      btbentries    => 16,
      btbsets       => 2,
      dmen          => 1,
      pbaddr        => 16#90000#,
      rstaddr       => 16#C0000#
    ),
    -- GP-lite
    2 => (
      single_issue  => 0, -- Not Used
      ext_m         => 1,
      ext_a         => 1,
      ext_c         => 1,
      ext_h         => 0,
      ext_zcb       => 1,
      ext_zba       => 1,
      ext_zbb       => 1,
      ext_zbc       => 0,
      ext_zbs       => 1,
      ext_zbkb      => 0,
      ext_zbkc      => 0,
      ext_zbkx      => 0,
      ext_sscofpmf  => 1,
      ext_shlcofideleg => 0,
      ext_smcdeleg  => 0,
      ext_sstc      => 2,
      ext_smaia     => 0,
      ext_ssaia     => 0,
      ext_smstateen => 1,
      ext_smrnmi    => 1,
      ext_ssdbltrp  => 1,
      ext_smdbltrp  => 1,
      ext_smepmp    => 1,
      ext_svadu     => 1,
      ext_svpbmt    => 1,
      ext_svnapot   => 1,
      imsic         => 0,
      mnintid       => 63,
      snintid       => 63,
      gnintid       => 63,
      rnmi_iaddr    => 16#30010#,
      rnmi_xaddr    => 16#30011#,
      ext_noelv     => 1,
      ext_noelvalu  => 1,
      ext_zicbom    => 1,
      ext_zicond    => 1,
      ext_zimop     => 1,
      ext_zcmop     => 1,
      ext_zicfiss   => 1,
      ext_zicfilp   => 1,
      ext_svinval   => 1,
      ext_zfa       => 1,
      ext_zfh       => 1,
      ext_zfhmin    => 1,
      ext_zfbfmin   => 1,
      mode_s        => 1,
      mode_u        => 1,
      fpulen        => 64,
      pmp_no_tor    => 0,
      pmp_entries   => 0,
      pmp_g         => 10,
      pma_entries   => 8,
      pma_masked    => 1,
      asidlen       => 0,
      vmidlen       => 0,
      perf_cnts     => 3,
      perf_evts     => 16,
      perf_bits     => 32,
      tbuf          => 4,
      trigger       => 32*0 + 16*0 + 2,
      icen          => 1,
      iways         => 4,
      iwaysize      => 4,
      ilinesize     => 8,
      dcen          => 1,
      dways         => 4,
      dwaysize      => 4,
      dlinesize     => 8,
      mmuen         => 1,
      itlbnum       => 8,
      dtlbnum       => 8,
      htlbnum       => 8,
      tlbrepl       => 1,
      riscv_mmu     => 2,
      tlb_pmp       => 0,
      div_hiperf    => 1,
      div_small     => 0,
      no_muladd     => 0,
      late_branch   => 1,
      late_alu      => 1,
      ras           => 0,
      bhtentries    => 64,
      bhtlength     => 5,
      predictor     => 2,
      btbentries    => 16,
      btbsets       => 2,
      dmen          => 1,
      pbaddr        => 16#90000#,
      rstaddr       => 16#C0000#
    ),
    -- MIN
    3 => (
      single_issue  => 1,
      ext_m         => 1,
      ext_a         => 1,
      ext_c         => 1,
      ext_h         => 0,
      ext_zcb       => 1,
      ext_zba       => 1,
      ext_zbb       => 0,
      ext_zbc       => 0,
      ext_zbs       => 1,
      ext_zbkb      => 0,
      ext_zbkc      => 0,
      ext_zbkx      => 0,
      ext_sscofpmf  => 0,
      ext_shlcofideleg => 0,
      ext_smcdeleg  => 0,
      ext_sstc      => 0,
      ext_smaia     => 0,
      ext_ssaia     => 0,
      ext_smstateen => 0,
      ext_smrnmi    => 0,
      ext_ssdbltrp  => 0,
      ext_smdbltrp  => 0,
      ext_smepmp    => 1,
      ext_svadu     => 0,
      ext_svpbmt    => 0,
      ext_svnapot   => 0,
      imsic         => 0,
      mnintid       => 63,
      snintid       => 63,
      gnintid       => 63,
      rnmi_iaddr    => 16#30010#,
      rnmi_xaddr    => 16#30011#,
      ext_noelv     => 1,
      ext_noelvalu  => 0,
      ext_zicbom    => 0,
      ext_zicond    => 1,
      ext_zimop     => 1,
      ext_zcmop     => 1,
      ext_zicfiss   => 0,
      ext_zicfilp   => 0,
      ext_svinval   => 0,
      ext_zfa       => 1,
      ext_zfh       => 0,
      ext_zfhmin    => 1,
      ext_zfbfmin   => 1,
      mode_s        => 0,
      mode_u        => 1,
      fpulen        => 32,
      pmp_no_tor    => 0,
      pmp_entries   => 8,
      pmp_g         => 10,
      pma_entries   => 0,
      pma_masked    => 0,
      asidlen       => 0,
      vmidlen       => 0,
      perf_cnts     => 8,
      perf_evts     => 16,
      perf_bits     => 32,
      tbuf          => 4,
      trigger       => 32*0 + 16*1 + 2,
      icen          => 1,
      iways         => 4,
      iwaysize      => 4,
      ilinesize     => 8,
      dcen          => 1,
      dways         => 4,
      dwaysize      => 4,
      dlinesize     => 8,
      mmuen         => 0,
      itlbnum       => 2,
      dtlbnum       => 2,
      htlbnum       => 1,
      tlbrepl       => 1,
      riscv_mmu     => 2,
      tlb_pmp       => 0,
      div_hiperf    => 0,
      div_small     => 1,
      no_muladd     => 0,
      late_branch   => 1,
      late_alu      => 1,
      ras           => 0,
      bhtentries    => 64,
      bhtlength     => 5,
      predictor     => 2,
      btbentries    => 16,
      btbsets       => 2,
      dmen          => 1,
      pbaddr        => 16#90000#,
      rstaddr       => 16#C0000#
    ),
    -- MIN-lite
    4 => (
      single_issue  => 1,
      ext_m         => 1,
      ext_a         => 1,
      ext_c         => 1,
      ext_h         => 0,
      ext_zcb       => 1,
      ext_zba       => 0,
      ext_zbb       => 0,
      ext_zbc       => 0,
      ext_zbs       => 0,
      ext_zbkb      => 0,
      ext_zbkc      => 0,
      ext_zbkx      => 0,
      ext_sscofpmf  => 0,
      ext_shlcofideleg => 0,
      ext_smcdeleg  => 0,
      ext_sstc      => 0,
      ext_smaia     => 0,
      ext_ssaia     => 0,
      ext_smstateen => 0,
      ext_smrnmi    => 0,
      ext_ssdbltrp  => 0,
      ext_smdbltrp  => 0,
      ext_smepmp    => 0,
      ext_svadu     => 0,
      ext_svpbmt    => 0,
      ext_svnapot   => 0,
      imsic         => 0,
      mnintid       => 63,
      snintid       => 63,
      gnintid       => 63,
      rnmi_iaddr    => 16#30010#,
      rnmi_xaddr    => 16#30011#,
      ext_noelv     => 1,
      ext_noelvalu  => 0,
      ext_zicbom    => 0,
      ext_zicond    => 0,
      ext_zimop     => 1,
      ext_zcmop     => 1,
      ext_zicfiss   => 0,
      ext_zicfilp   => 0,
      ext_svinval   => 0,
      ext_zfa       => 0,
      ext_zfh       => 0,
      ext_zfhmin    => 0,
      ext_zfbfmin   => 0,
      mode_s        => 0,
      mode_u        => 1,
      fpulen        => 0,
      pmp_no_tor    => 0,
      pmp_entries   => 0,
      pmp_g         => 10,
      pma_entries   => 0,
      pma_masked    => 0,
      asidlen       => 0,
      vmidlen       => 0,
      perf_cnts     => 3,
      perf_evts     => 16,
      perf_bits     => 32,
      tbuf          => 4,
      trigger       => 32*0 + 16*0 + 2,
      icen          => 1,
      iways         => 4,
      iwaysize      => 4,
      ilinesize     => 8,
      dcen          => 1,
      dways         => 4,
      dwaysize      => 4,
      dlinesize     => 8,
      mmuen         => 0,
      itlbnum       => 2,
      dtlbnum       => 2,
      htlbnum       => 1,
      tlbrepl       => 1,
      riscv_mmu     => 2,
      tlb_pmp       => 0,
      div_hiperf    => 0,
      div_small     => 1,
      no_muladd     => 0,
      late_branch   => 0,
      late_alu      => 0,
      ras           => 0,
      bhtentries    => 64,
      bhtlength     => 5,
      predictor     => 2,
      btbentries    => 16,
      btbsets       => 2,
      dmen          => 1,
      pbaddr        => 16#90000#,
      rstaddr       => 16#C0000#
    ),
    5 => cfg_custom0,
    others => cfg_none
    );

  function cfg_map (cfg : integer) return cfg_setup_type;
  function cfg_mask (ci       : nv_cpu_cfg_type;
                     cs       : cfg_setup_type;
                     AIA      : integer;
                     SMRNMI   : integer;
                     DBLTRP   : integer;
                     ZICFISS  : integer;
                     ZICFILP  : integer;
                     RV64     : integer;
                     RDV  : integer) return nv_cpu_cfg_type;
end;

package body noelv_cpu_cfg is
  function cfg_map (cfg : integer) return cfg_setup_type is
    variable cfg_res    : cfg_setup_type := (0, 1, 0);
    variable cfg_typ    : integer := (cfg / 256)  mod 16;
    variable cfg_lite   : integer := (cfg / 128)  mod 2;
    variable cfg_fpu    : integer := (cfg / 2)    mod 2;
    variable cfg_sissue : integer :=  cfg         mod 2;
    variable cfg_valid  : boolean := false;
  begin
    if cfg_typ /= 0 then
      cfg_res.fpu     := (1 - cfg_fpu);
      cfg_res.sissue  := cfg_sissue;
      case cfg_typ is
        when 4 => -- HP
          cfg_res.typ := 0;
          if (cfg_lite + cfg_fpu + cfg_sissue) = 0 then
            cfg_valid := true;
          end if;
        when 3 => -- GP/GP-lite
          cfg_res.typ := 1;
          if cfg_lite = 1 then
            cfg_res.typ := 2;
          end if;
          if (cfg_fpu) = 0 then
            cfg_valid := true;
          end if;
        when 2 => -- MIN/MIN-lite
          cfg_res.typ := 3;
          if cfg_lite = 1 then
            cfg_res.typ := 4;
            if (cfg_fpu*cfg_sissue) = 1 then
              cfg_valid := true;
            end if;
          else
            if (cfg_sissue) = 1 then
              cfg_valid := true;
            end if;
          end if;
        when 15 => -- Custom
          cfg_res.typ := 5;
          cfg_res.fpu := 1;
          cfg_res.sissue  := cfg_custom0.single_issue;
          cfg_valid := true;
        when others => -- Default to HP
          cfg_res.typ := 0;
      end case;
    else -- Old configurations
      cfg_valid := true;
      case cfg is
        when 0 => -- HP
          cfg_res.typ := 0;
          cfg_res.fpu := 1;
          cfg_res.sissue := 0;
        when 1 => -- GP dual-issue
          cfg_res.typ := 1;
          cfg_res.fpu := 1;
          cfg_res.sissue := 0;
        when 2 => -- GP single-issue
          cfg_res.typ := 1;
          cfg_res.fpu := 1;
          cfg_res.sissue := 1;
        when 3 => -- MIN with FPU
          cfg_res.typ := 3;
          cfg_res.fpu := 1;
          cfg_res.sissue := 1;
        when 4 => -- MIN without FPU
          cfg_res.typ := 3;
          cfg_res.fpu := 0;
          cfg_res.sissue := 1;
        when 5 => -- Closes to MIN-lite
          cfg_res.typ := 4;
          cfg_res.fpu := 0;
          cfg_res.sissue := 1;
        when 6 => -- GP-lite
          cfg_res.typ := 2;
          cfg_res.fpu := 1;
          cfg_res.sissue := 0;
        when others => -- Default to HP
          cfg_res.typ := 0;
          cfg_res.fpu := 1;
          cfg_res.sissue := 0;
          cfg_valid := false;
      end case;
    end if;
-- pragma translate_off
    case cfg_res.typ is
      when 0 =>
        assert false report "NV-HP configuration" severity note;
      when 1 =>
        assert false report "NV-GP configuration" severity note;
      when 2 =>
        assert false report "NV-GP-lite configuration" severity note;
      when 3 =>
        assert false report "NV-MIN configuration" severity note;
      when 4 =>
        assert false report "NV-MIN-lite configuration" severity note;
      when 5 =>
        assert false report "Custom0 configuration" severity note;
      when others =>
    end case;
    if cfg_res.fpu = 1 then
      assert false report "NOELV FPU enabled" severity note;
    else
      assert false report "NOELV FPU disabled" severity note;
    end if;
    if cfg_res.sissue = 1 then
      assert false report "NOELV single-issue" severity note;
    else
      assert false report "NOELV dual-issue" severity note;
    end if;
    assert cfg_valid report "Un-supported NOELV configuration" severity warning;
-- pragma translate_on
    return cfg_res;
  end function;

  function cfg_mask (ci       : nv_cpu_cfg_type;
                     cs       : cfg_setup_type;
                     AIA      : integer;
                     SMRNMI   : integer;
                     DBLTRP   : integer;
                     ZICFISS  : integer;
                     ZICFILP  : integer;
                     RV64     : integer;
                     RDV  : integer) return nv_cpu_cfg_type is
    variable co : nv_cpu_cfg_type := ci;
  begin
    co.single_issue     := cs.sissue;
    co.fpulen           := co.fpulen * cs.fpu;

    co.ext_h            := co.ext_h * RV64 * RDV;
    co.ext_sscofpmf     := co.ext_sscofpmf * RDV;
    co.ext_shlcofideleg := co.ext_shlcofideleg * RV64 * RDV;
    co.ext_sstc         := co.ext_sstc * RDV;
    co.ext_smaia        := co.ext_smaia * AIA * RDV;
    co.ext_ssaia        := co.ext_ssaia * AIA * RDV;
    co.ext_smstateen    := co.ext_smstateen * RDV;
    co.ext_smrnmi       := co.ext_smrnmi * SMRNMI * RDV;
    co.ext_ssdbltrp     := co.ext_ssdbltrp * DBLTRP * RDV;
    co.ext_smdbltrp     := co.ext_smdbltrp * DBLTRP * RDV;
    co.imsic            := co.imsic * AIA * RDV;
    co.ext_zicbom       := co.ext_zicbom * RDV;
    co.ext_zicond       := co.ext_zicond * RDV;
    co.ext_zimop        := co.ext_zimop * RDV;
    co.ext_zcmop        := co.ext_zcmop * RDV;
    co.ext_zicfiss      := co.ext_zicfiss * ZICFISS * RDV;
    co.ext_zicfilp      := co.ext_zicfilp * ZICFILP * RDV;
    co.ext_svinval      := co.ext_svinval * RDV;
    co.vmidlen          := co.vmidlen * RV64 * RDV;
    co.ext_noelvalu     := co.ext_noelvalu * RDV;

    return co;
  end function;
end;
