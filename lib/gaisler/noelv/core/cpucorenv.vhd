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
-- Description: Top-level NOEL-V components
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

entity cpucorenv is
  generic (
    hindex              : integer;
    fabtech             : integer;
    memtech             : integer;
    cached              : integer;
    wbmask              : integer;
    busw                : integer;
    physaddr            : integer;
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
    ahbi        : in  ahb_mst_in_type;
    ahbo        : out ahb_mst_out_type;
    ahbsi       : in  ahb_slv_in_type;
    ahbso       : in  ahb_slv_out_vector;
    irqi        : in  nv_irq_in_type;       -- IRQ in
    irqo        : out nv_irq_out_type;      -- IRQ out
    dbgi        : in  nv_debug_in_type;     -- debug in
    dbgo        : out nv_debug_out_type;    -- debug out
    tpo         : out nv_full_trace_type;   -- Combined trace output
    cnt         : out nv_counter_out_type;  -- Perf event Out Port
    pwrd        : out std_ulogic            -- Activate power down mode
    );
end;

architecture rtl of cpucorenv is
  constant MEMTECH_MOD  : integer := memtech mod 65536;
  constant dtagconf     : integer := cmemconf mod 4;
  constant dtcmen       : integer := b2i((tcmconf mod 32) /= 0);
  constant itcmen       : integer := b2i(((tcmconf / 256) mod 32) /= 0);

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

  constant iphysbits : integer := physaddr;
  constant dphysbits : integer := physaddr;
  constant dphys_bits  : integer := gaisler.utilnv.minimum(dphysbits, gaisler.mmucacheconfig.pa_msb(cfg_c.riscv_mmu)+1);
  constant didxwidth    : integer := (log2(cfg_c.dwaysize) + 10) - (log2(cfg_c.dlinesize) + 2);
  constant dtagwidth    : integer := dphys_bits - (log2(cfg_c.dwaysize) + 10) + 1;

  signal sni          : snoopram_in_type5;
  signal sno          : snoopram_out_type5;
  signal snosh, snosp : snoopram_out_type5;
  signal bifi         : busif_in_type5;
  signal bifo         : busif_out_type5;

begin

  c0 : entity work.cpucorenvb
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
      cgen                => cgen,
      asyncif             => asyncif,
      scantest            => scantest
    )
    port map(
      clk         => clk,
      gclk        => gclk,
      rstn        => rstn,
      snish       => sni,
      snosh       => snosh,
      bifi        => bifi,
      bifo        => bifo,
      ahbpnp      => ahbso,
      irqi        => irqi,
      irqo        => irqo,
      dbgi        => dbgi,
      dbgo        => dbgo,
      tpo         => tpo,
      cnt         => cnt,
      pwrd        => pwrd,
      endian      => ahbsi.endian,
      testen      => ahbsi.testen,
      testrst     => ahbsi.testrst,
      testin      => ahbsi.testin
    );

  bif0: busif5
    generic map (
      hindex     => hindex,
      device     => GAISLER_RV64GC,
      version    => NOELV_VERSION,
      ilinesize  => cfg_c.ilinesize,
      dways      => cfg_c.dways,
      dlinesize  => cfg_c.dlinesize,
      dwaysize   => cfg_c.dwaysize,
      wbmask     => wbmask,
      busw       => busw
      )
    port map (
      clk      => clk,
      rstn     => rstn,
      ahbi     => ahbi,
      ahbo     => ahbo,
      ahbsi    => ahbsi,
      bifi     => bifi,
      bifo     => bifo,
      sni      => sni,
      sno      => sno
      );

  smem1 : snoopmem5
    generic map (
      tech      => MEMTECH_MOD,
      dways     => cfg_c.dways,
      didxwidth => didxwidth,
      dtagwidth => dtagwidth,
      dtagconf  => dtagconf,
      testen    => scantest
      )
    port map (
      rstn   => rstn,
      sclk   => clk,
      sni    => sni,
      sno    => snosp,
      testin => ahbi.testin
      );

  sno   <= snosh when dtagconf=1 else snosp;
  --snish <= sni;

end;
