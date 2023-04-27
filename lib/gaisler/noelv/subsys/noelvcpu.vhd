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
-- Entity:      noelv
-- File:        noelv.vhd
-- Author:      Nils Wessman, Cobham Gaisler
-- Description: NOEL-V single processor core
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.noelv_cpu_cfg.all;

entity noelvcpu is
  generic (
    hindex   : integer;
    fabtech  : integer;
    memtech  : integer;
    mularch  : integer;
    cached   : integer;
    wbmask   : integer;
    busw     : integer;
    cmemconf : integer;
    rfconf   : integer;
    fpuconf  : integer;
    tcmconf  : integer;
    mulconf  : integer;
    disas    : integer;
    pbaddr   : integer;
    cfg      : integer;
    scantest : integer
    );
  port (
    clk    : in  std_ulogic;
    rstn   : in  std_ulogic;
    ahbi   : in  ahb_mst_in_type;
    ahbo   : out ahb_mst_out_type;
    imsici : out imsic_in_type;
    imsico : in  imsic_out_type;
    ahbsi  : in  ahb_slv_in_type;
    ahbso  : in  ahb_slv_out_vector;
    irqi   : in  nv_irq_in_type;
    irqo   : out nv_irq_out_type;
    nirqi  : in  nv_nirq_in_type;  
    dbgi   : in  nv_debug_in_type;
    dbgo   : out nv_debug_out_type;
    eto    : out nv_etrace_out_type;
    cnt    : out nv_counter_out_type

    );
end;

architecture hier of noelvcpu is


  signal vcc            : std_logic;
  signal gnd            : std_logic;

  type cfg_setup_type is record
    typ     : integer;
    fpu     : integer;
    sissue  : integer;
  end record;

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
        when 16 => -- Custom
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

  constant c : cfg_setup_type := cfg_map(cfg);

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
    ext_sstc      => 0,
    ext_smaia     => 0,
    ext_ssaia     => 0,
    ext_smstateen => 0,
    ext_smepmp    => 0,
    imsic         => 0,
    ext_zicbom    => 0,
    ext_zicond    => 0,
    ext_zimops    => 0,
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
    div_hiperf    => 0,
    div_small     => 0,
    late_branch   => 0,
    late_alu      => 0,
    bhtentries    => 32,
    bhtlength     => 2,
    predictor     => 0,
    btbentries    => 8,
    btbsets       => 1);

  type cfg_type is array (natural range <>) of nv_cpu_cfg_type;

  constant cfg_c : cfg_type(0 to 7) := (
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
      ext_sstc      => 1,
      ext_smaia     => 1*AIA_SUPPORT,
      ext_ssaia     => 1*AIA_SUPPORT,
      ext_smstateen => 1,
      ext_smepmp    => 1,
      imsic         => 1*AIA_SUPPORT,
      ext_zicbom    => 1,
      ext_zicond    => 1,
      ext_zimops    => 1,
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
      asidlen       => 8,
      vmidlen       => 4,
      perf_cnts     => 16,
      perf_evts     => 128,
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
      itlbnum       => 16,
      dtlbnum       => 16,
      htlbnum       => 16,
      div_hiperf    => 1,
      div_small     => 0,
      late_branch   => 1,
      late_alu      => 1,
      bhtentries    => 128,
--      bhtentries    => 512,
      bhtlength     => 5,
--      bhtlength     => 8,
      predictor     => 2,
      btbentries    => 16,
--      btbentries    => 128,
      btbsets       => 2),
--      btbsets       => 4),
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
      ext_sstc      => 1,
      ext_smaia     => 1*AIA_SUPPORT,
      ext_ssaia     => 1*AIA_SUPPORT,
      ext_smstateen => 1,
      ext_smepmp    => 1,
      imsic         => 1*AIA_SUPPORT,
      ext_zicbom    => 1,
      ext_zicond    => 1,
      ext_zimops    => 1,
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
      asidlen       => 8,
      vmidlen       => 4,
      perf_cnts     => 16,
      perf_evts     => 128,
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
      itlbnum       => 16,
      dtlbnum       => 16,
      htlbnum       => 16,
      div_hiperf    => 1,
      div_small     => 0,
      late_branch   => 1,
      late_alu      => 1,
      bhtentries    => 128,
      bhtlength     => 5,
      predictor     => 2,
      btbentries    => 16,
      btbsets       => 2),
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
      ext_sstc      => 2,
      ext_smaia     => 0,
      ext_ssaia     => 0,
      ext_smstateen => 0,
      ext_smepmp    => 1,
      imsic         => 0,
      ext_zicbom    => 1,
      ext_zicond    => 1,
      ext_zimops    => 1,
      ext_zfa       => 1,
      ext_zfh       => 1,
      ext_zfhmin    => 1,
      ext_zfbfmin   => 0,
      mode_s        => 1,
      mode_u        => 1,
      fpulen        => 64,
      pmp_no_tor    => 0,
      pmp_entries   => 0,
      pmp_g         => 10,
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
      div_hiperf    => 1,
      div_small     => 0,
      late_branch   => 1,
      late_alu      => 1,
      bhtentries    => 64,
      bhtlength     => 5,
      predictor     => 2,
      btbentries    => 16,
      btbsets       => 2),
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
      ext_sscofpmf  => 1,
      ext_sstc      => 0,
      ext_smaia     => 0,
      ext_ssaia     => 0,
      ext_smstateen => 0,
      ext_smepmp    => 1,
      imsic         => 0,
      ext_zicbom    => 0,
      ext_zicond    => 0,
      ext_zimops    => 1,
      ext_zfa       => 1,
      ext_zfh       => 0,
      ext_zfhmin    => 1,
      ext_zfbfmin   => 0,
      mode_s        => 0,
      mode_u        => 1,
      fpulen        => 64,
      pmp_no_tor    => 0,
      pmp_entries   => 8,
      pmp_g         => 10,
      asidlen       => 0,
      vmidlen       => 0,
      perf_cnts     => 8,
      perf_evts     => 16,
      perf_bits     => 32,
      tbuf          => 4,
      trigger       => 32*0 + 16*1 + 2,
      icen          => 1,
      iways         => 2,
      iwaysize      => 4,
      ilinesize     => 8,
      dcen          => 1,
      dways         => 2,
      dwaysize      => 4,
      dlinesize     => 8,
      mmuen         => 0,
      itlbnum       => 2,
      dtlbnum       => 2,
      htlbnum       => 1,
      div_hiperf    => 0,
      div_small     => 1,
      late_branch   => 1,
      late_alu      => 1,
      bhtentries    => 64,
      bhtlength     => 5,
      predictor     => 2,
      btbentries    => 16,
      btbsets       => 2),
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
      ext_sstc      => 0,
      ext_smaia     => 0,
      ext_ssaia     => 0,
      ext_smstateen => 0,
      ext_smepmp    => 1,
      imsic         => 0,
      ext_zicbom    => 0,
      ext_zicond    => 0,
      ext_zimops    => 1,
      ext_zfa       => 0,
      ext_zfh       => 0,
      ext_zfhmin    => 0,
      ext_zfbfmin   => 0,
      mode_s        => 0,
      mode_u        => 1,
      fpulen        => 0,
      pmp_no_tor    => 0,
      pmp_entries   => 8,
      pmp_g         => 10,
      asidlen       => 0,
      vmidlen       => 0,
      perf_cnts     => 3,
      perf_evts     => 16,
      perf_bits     => 32,
      tbuf          => 4,
      trigger       => 32*0 + 16*0 + 2,
      icen          => 1,
      iways         => 2,
      iwaysize      => 4,
      ilinesize     => 8,
      dcen          => 1,
      dways         => 2,
      dwaysize      => 4,
      dlinesize     => 8,
      mmuen         => 0,
      itlbnum       => 2,
      dtlbnum       => 2,
      htlbnum       => 1,
      div_hiperf    => 0,
      div_small     => 1,
      late_branch   => 0,
      late_alu      => 0,
      bhtentries    => 64,
      bhtlength     => 5,
      predictor     => 2,
      btbentries    => 16,
      btbsets       => 2),
    5 => cfg_custom0,
    others => cfg_none
    );

begin
  vcc <= '1'; gnd <= '0';

  u0 : cpucorenv -- NOEL-V Core
    generic map (
      hindex          => hindex,
      fabtech         => fabtech,
      memtech         => memtech,
      -- BHT
      bhtentries      => cfg_c(c.typ).bhtentries,
      bhtlength       => cfg_c(c.typ).bhtlength,
      predictor       => cfg_c(c.typ).predictor,
      -- BTB
      btbentries      => cfg_c(c.typ).btbentries,
      btbsets         => cfg_c(c.typ).btbsets,
      -- Caches
      icen            => cfg_c(c.typ).icen,
      iways           => cfg_c(c.typ).iways,
      ilinesize       => cfg_c(c.typ).ilinesize,
      iwaysize        => cfg_c(c.typ).iwaysize,
      dcen            => cfg_c(c.typ).dcen,
      dways           => cfg_c(c.typ).dways,
      dlinesize       => cfg_c(c.typ).dlinesize,
      dwaysize        => cfg_c(c.typ).dwaysize,
      -- MMU
      mmuen           => cfg_c(c.typ).mmuen,
      itlbnum         => cfg_c(c.typ).itlbnum,
      dtlbnum         => cfg_c(c.typ).dtlbnum,
      htlbnum         => cfg_c(c.typ).htlbnum,
      tlbforepl       => 4,
      riscv_mmu       => 2,
      pmp_no_tor      => cfg_c(c.typ).pmp_no_tor,
      pmp_entries     => cfg_c(c.typ).pmp_entries,
      pmp_g           => cfg_c(c.typ).pmp_g,
      asidlen         => cfg_c(c.typ).asidlen,
      vmidlen         => cfg_c(c.typ).vmidlen,
      -- Interrupts
      imsic           => cfg_c(c.typ).imsic,
      -- Extensions
      ext_noelv       => 1,
      ext_m           => cfg_c(c.typ).ext_m,
      ext_a           => cfg_c(c.typ).ext_a,
      ext_c           => cfg_c(c.typ).ext_c,
      ext_h           => cfg_c(c.typ).ext_h,
      ext_zcb         => cfg_c(c.typ).ext_zcb,
      ext_zba         => cfg_c(c.typ).ext_zba,
      ext_zbb         => cfg_c(c.typ).ext_zbb,
      ext_zbc         => cfg_c(c.typ).ext_zbc,
      ext_zbs         => cfg_c(c.typ).ext_zbs,
      ext_zbkb        => cfg_c(c.typ).ext_zbkb,
      ext_zbkc        => cfg_c(c.typ).ext_zbkc,
      ext_zbkx        => cfg_c(c.typ).ext_zbkx,
      ext_sscofpmf    => cfg_c(c.typ).ext_sscofpmf,
      ext_sstc        => cfg_c(c.typ).ext_sstc,
      ext_smaia       => cfg_c(c.typ).ext_smaia,
      ext_ssaia       => cfg_c(c.typ).ext_ssaia,
      ext_smstateen   => cfg_c(c.typ).ext_smstateen,
      ext_smepmp      => cfg_c(c.typ).ext_smepmp,
      ext_zicbom      => cfg_c(c.typ).ext_zicbom,
      ext_zicond      => cfg_c(c.typ).ext_zicond,
      ext_zimops      => cfg_c(c.typ).ext_zimops,
      ext_zfa         => cfg_c(c.typ).ext_zfa,
      ext_zfh         => cfg_c(c.typ).ext_zfh,
      ext_zfhmin      => cfg_c(c.typ).ext_zfhmin,
      ext_zfbfmin     => cfg_c(c.typ).ext_zfbfmin,
      mode_s          => cfg_c(c.typ).mode_s,
      mode_u          => cfg_c(c.typ).mode_u,
      fpulen          => cfg_c(c.typ).fpulen * c.fpu,
      trigger         => cfg_c(c.typ).trigger,
      -- Advanced Features
      late_branch     => cfg_c(c.typ).late_branch,
      late_alu        => cfg_c(c.typ).late_alu,
      -- Core
      cached          => cached,
      wbmask          => wbmask,
      busw            => busw,
      cmemconf        => cmemconf,
      rfconf          => rfconf,
--      rfconf          => 1,  -- qqq Use this for DC
      tcmconf         => tcmconf,
      mulconf         => mulconf,
      tbuf            => cfg_c(c.typ).tbuf,
      physaddr        => 32,
      rstaddr         => 16#C0000#,
      -- Misc
      dmen            => 1,
      pbaddr          => pbaddr,
      disas           => disas,
      perf_cnts       => cfg_c(c.typ).perf_cnts,
      perf_evts       => cfg_c(c.typ).perf_evts,
      perf_bits       => cfg_c(c.typ).perf_bits,
      illegalTval0    => 0,
      no_muladd       => 0,
      single_issue    => c.sissue,
      mularch         => mularch,
      div_hiperf      => cfg_c(c.typ).div_hiperf,
      div_small       => cfg_c(c.typ).div_small,
      hw_fpu          => 1 + 2 * fpuconf,
      scantest        => scantest,
      endian          => 1  -- Only Little-endian is supported
      )
    port map (
      clk             => clk,
      gclk            => clk,
      rstn            => rstn,
      ahbi            => ahbi,
      ahbo            => ahbo,
      ahbsi           => ahbsi,
      ahbso           => ahbso,
      imsici          => imsici,
      imsico          => imsico,
      irqi            => irqi,
      irqo            => irqo,
      nirqi           => nirqi,
      dbgi            => dbgi,
      dbgo            => dbgo,
      eto             => eto,
      cnt             => cnt
      );
end;
