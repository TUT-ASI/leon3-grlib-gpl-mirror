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
-- Entity:      cpucorenvb
-- File:        coucorenvb.vhd
-- Author:      Nils Wessman, Cobham Gaisler AB
-- Description: Top-level NOEL-V wrapper without bus interface and with cachemem
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

entity cpucorenvb is
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
    snish       : in  snoopram_in_type5;
    snosh       : out snoopram_out_type5;
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

architecture rtl of cpucorenvb is
  constant MEMTECH_MOD  : integer := memtech mod 65536;
  constant dtagconf     : integer := cmemconf mod 4;
  constant dusebw       : integer := (cmemconf / 4) mod 2;

  constant dtcmen    : integer := b2i((tcmconf mod 32) /= 0);
  constant dtcmabits : integer := (1 - dtcmen) + (tcmconf mod 32);
  constant dtcmfrac  : integer := ((tcmconf/32) mod 8);
  constant itcmen    : integer := b2i(((tcmconf / 256) mod 32) /= 0);
  constant itcmabits : integer := (1 - itcmen) + ((tcmconf / 256) mod 32);
  constant itcmfrac  : integer := ((tcmconf/(256*32)) mod 8);

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
  constant iphys_bits  : integer := gaisler.utilnv.minimum(iphysbits, gaisler.mmucacheconfig.pa_msb(cfg_c.riscv_mmu)+1);
  constant dphys_bits  : integer := gaisler.utilnv.minimum(dphysbits, gaisler.mmucacheconfig.pa_msb(cfg_c.riscv_mmu)+1);
  constant iidxwidth    : integer := (log2(cfg_c.iwaysize) + 10) - (log2(cfg_c.ilinesize) + 2);
  constant itagwidth    : integer := iphys_bits - (log2(cfg_c.iwaysize) + 10) + 1;
  constant didxwidth    : integer := (log2(cfg_c.dwaysize) + 10) - (log2(cfg_c.dlinesize) + 2);
  constant dtagwidth    : integer := dphys_bits - (log2(cfg_c.dwaysize) + 10) + 1;

  signal crami       : cram_in_type5;
  signal cramo       : cram_out_type5;
begin
  c0 : entity work.cpucorenvbc
    generic map(
      fabtech             => fabtech,
      memtech             => memtech,
      cached              => cached,
      wbmask              => wbmask,
      busw                => busw,
      iphysbits           => iphysbits,
      dphysbits           => dphysbits,
      cmemconf            => cmemconf,
      rfconf              => rfconf,
      fpuconf             => fpuconf,
      tcmconf             => tcmconf,
      mulconf             => mulconf,
      intcconf            => intcconf,
      cfg                 => cfg,
      disas               => disas,
      scantest            => scantest,
      cgen                => cgen,
      asyncif             => asyncif
    )
    port map(
      clk         => clk,
      gclk        => gclk,
      rstn        => rstn,
      bifi        => bifi,
      bifo        => bifo,
      ahbpnp      => ahbpnp,
      crami       => crami,
      cramo       => cramo,
      irqi        => irqi,
      irqo        => irqo,
      dbgi        => dbgi,
      dbgo        => dbgo,
      tpo         => tpo,
      cnt         => cnt,
      pwrd        => pwrd,
      endian      => endian,
      testen      => testen,
      testrst     => testrst,
      testin      => testin
    );

  cmem1 : cachemem5
    generic map (
      tech      => MEMTECH_MOD,
      iways     => cfg_c.iways,
      ilinesize => cfg_c.ilinesize,
      iidxwidth => iidxwidth,
      itagwidth => itagwidth,
      itcmen    => itcmen,
      itcmabits => itcmabits,
      itcmfrac  => itcmfrac,
      dways     => cfg_c.dways,
      dlinesize => cfg_c.dlinesize,
      didxwidth => didxwidth,
      dtagwidth => dtagwidth,
      dtagconf  => dtagconf
                   ,
      mbmode    => 1,
      dusebw    => dusebw,
      dtcmen    => dtcmen,
      dtcmabits => dtcmabits,
      dtcmfrac  => dtcmfrac,
      testen    => scantest
      )
    port map (
      rstn   => rstn,
      clk    => gclk,
      sclk   => clk,
      crami  => crami,
      cramo  => cramo,
      sni    => snish,
      sno    => snosh,
      testin => testin
      );
end;
