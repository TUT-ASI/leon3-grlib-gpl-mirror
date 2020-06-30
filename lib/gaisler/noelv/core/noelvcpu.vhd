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
-- Entity:      noelv
-- File:        noelv.vhd
-- Author:      Nils Wessman, Cobham Gaisler
-- Description: NOEL-V single processor core
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.noelvint.all;
use gaisler.noelv.all;
use gaisler.arith.all;

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
    fpuconf  : integer;
    disas    : integer;
    pbaddr   : integer;
    cfg      : integer
    );
  port (
    clk   : in  std_ulogic;
    rstn  : in  std_ulogic;
    ahbi  : in  ahb_mst_in_type;
    ahbo  : out ahb_mst_out_type;
    ahbsi : in  ahb_slv_in_type;
    ahbso : in  ahb_slv_out_vector;
    irqi  : in  nv_irq_in_type;
    irqo  : out nv_irq_out_type;
    dbgi  : in  nv_debug_in_type;
    dbgo  : out nv_debug_out_type;
    fpuo  : in  grfpu5_out_type;
    fpui  : out grfpu5_in_type;
    cnt   : out nv_counter_out_type
    );
end;

architecture hier of noelvcpu is

  constant iways    : integer := 4;
  constant iwaysize : integer := 4;
  constant ilinesize: integer := 8;
  constant dways    : integer := 4;
  constant dwaysize : integer := 4;
  constant dlinesize: integer := 8;
  constant scantest : integer := 0;

  -- FPU Unit
  signal fpi            : fpu5_in_type;
  signal fpo            : fpu5_out_type;

  signal vcc            : std_logic;
  signal gnd            : std_logic;

  type cfg_i_type is record
    ext_m         : integer;
    ext_a         : integer;
    ext_c         : integer;
    ext_h         : integer;
    mode_s        : integer;
    mode_u        : integer;
    fpulen        : integer;
    mmuen         : integer;
    pmp_no_tor    : integer;
    pmp_entries   : integer;
    pmp_g         : integer;
    perf_cnts     : integer;
    perf_evts     : integer;
    itlbnum       : integer;
    dtlbnum       : integer;
    bhtentries    : integer;
    btbentries    : integer;
    predictor     : integer;
  end record;
  type cfg_type is array (natural range <>) of cfg_i_type;

  constant cfg_c : cfg_type(0 to 4) := (
    0 => (
      ext_m         => 1,
      ext_a         => 1,
      ext_c         => 0, -- Should be enabled
      ext_h         => 0, -- Should be enabled
      mode_s        => 1,
      mode_u        => 1,
      fpulen        => 64,
      mmuen         => 1,
      pmp_no_tor    => 0,
      pmp_entries   => 8,
      pmp_g         => 10,
      perf_cnts     => 16,
      perf_evts     => 16,
      itlbnum       => 8,
      dtlbnum       => 8,
      bhtentries    => 128,
      btbentries    => 16,
      predictor     => 2),
    1 => (
      ext_m         => 1,
      ext_a         => 1,
      ext_c         => 0,
      ext_h         => 0,
      mode_s        => 1,
      mode_u        => 1,
      fpulen        => 64,
      mmuen         => 1,
      pmp_no_tor    => 0,
      pmp_entries   => 0,
      pmp_g         => 10,
      perf_cnts     => 16,
      perf_evts     => 16,
      itlbnum       => 8,
      dtlbnum       => 8,
      bhtentries    => 128,
      btbentries    => 16,
      predictor     => 2),
    2 => (
      ext_m         => 1,
      ext_a         => 0,
      ext_c         => 0,
      ext_h         => 0,
      mode_s        => 0,
      mode_u        => 0,
      fpulen        => 0,
      mmuen         => 0,
      pmp_no_tor    => 0,
      pmp_entries   => 0,
      pmp_g         => 0,
      perf_cnts     => 0,
      perf_evts     => 0,
      itlbnum       => 2,
      dtlbnum       => 2,
      bhtentries    => 0,
      btbentries    => 0,
      predictor     => 2),
    3 => (
      ext_m         => 1,
      ext_a         => 1,
      ext_c         => 1,
      ext_h         => 0,
      mode_s        => 1,
      mode_u        => 1,
      fpulen        => 64,
      mmuen         => 1,
      pmp_no_tor    => 0,
      pmp_entries   => 8,
      pmp_g         => 10,
      perf_cnts     => 16,
      perf_evts     => 16,
      itlbnum       => 8,
      dtlbnum       => 8,
      bhtentries    => 128,
      btbentries    => 16,
      predictor     => 2),
    4 => (
      ext_m         => 1,
      ext_a         => 0,
      ext_c         => 0,
      ext_h         => 0,
      mode_s        => 0,
      mode_u        => 0,
      fpulen        => 0,
      mmuen         => 0,
      pmp_no_tor    => 0,
      pmp_entries   => 0,
      pmp_g         => 0,
      perf_cnts     => 0,
      perf_evts     => 0,
      itlbnum       => 2,
      dtlbnum       => 2,
      bhtentries    => 0,
      btbentries    => 0,
      predictor     => 2)
    );

begin
  vcc <= '1'; gnd <= '0';

  u0 : cpucorenv -- NOEL-V Core
    generic map (
      hindex          => hindex,
      fabtech         => fabtech,
      memtech         => memtech,
      -- BHT
      bhtentries      => cfg_c(cfg).bhtentries,--128,
      bhtlength       => 5,
      predictor       => cfg_c(cfg).predictor,--1,
      -- BTB
      btbentries      => cfg_c(cfg).btbentries,--32,
      btbsets         => 2,
      -- Caches
      icen            => 1,
      irepl           => 0,
      isets           => iways,
      ilinesize       => ilinesize,
      isetsize        => iwaysize,
      dcen            => 1,
      drepl           => 0,
      dsets           => dways,
      dlinesize       => dlinesize,
      dsetsize        => dwaysize,
      dsnoop          => 6,
      ilram           => 0,
      ilramsize       => 1,
      ilramstart      => 0,
      dlram           => 0,
      dlramsize       => 1,
      dlramstart      => 0,
      -- MMU
      mmuen           => cfg_c(cfg).mmuen,--1,
      itlbnum         => cfg_c(cfg).itlbnum,--8,
      dtlbnum         => cfg_c(cfg).dtlbnum,--8,
      tlb_type        => 1,
      tlb_rep         => 0,
      riscv_mmu       => 2,
      pmp_no_tor      => cfg_c(cfg).pmp_no_tor,-- 0,
      pmp_entries     => cfg_c(cfg).pmp_entries,--pmp_ent,
      pmp_g           => cfg_c(cfg).pmp_g,--      0,
      -- Extensions
      ext_m           => cfg_c(cfg).ext_m,-- 1,
      ext_a           => cfg_c(cfg).ext_a,--0,
      ext_c           => cfg_c(cfg).ext_c,--   1,
      ext_h           => cfg_c(cfg).ext_h,
      mode_s          => cfg_c(cfg).mode_s,--  1,
      mode_u          => cfg_c(cfg).mode_u,--   1,
      fpulen          => cfg_c(cfg).fpulen,--      0,
      trigger         => 2,
      -- Advanced Features
      late_branch     => 1,
      late_alu        => 1,
      -- Core
      cached          => cached,
      clk2x           => 0,
      wbmask          => wbmask,
      busw            => busw,
      cmemconf        => cmemconf,
      tbuf            => 2,
      physaddr        => 32,
      rstaddr         => 16#00014#,
      -- Misc
      dmen            => 1,
      pbaddr          => pbaddr,
      disas           => disas,
      perf_cnts       => cfg_c(cfg).perf_cnts,
      perf_evts       => cfg_c(cfg).perf_evts,
      illegalTval0    => 0,
      no_muladd       => 1,
      mularch         => mularch,
      scantest        => scantest
      )
    port map (
      ahbclk          => clk,
      cpuclk          => clk,
      gcpuclk         => clk,
      fpuclk          => clk,
      hclken          => vcc,
      rstn            => rstn,
      ahbi            => ahbi,
      ahbo            => ahbo,
      ahbsi           => ahbsi,
      ahbso           => ahbso,
      irqi            => irqi,
      irqo            => irqo,
      dbgi            => dbgi,
      dbgo            => dbgo,
      cnt             => cnt,
      fpui            => fpi,
      fpuo            => fpo
      );

  -- No FPU Unit supported
  fpo  <= fpu5_out_none;
  fpui <= grfpu5_in_none;
end;
