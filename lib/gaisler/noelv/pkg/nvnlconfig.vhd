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
-- Package:     nvnlconfig
-- File:        nvnlconfig.vhd
-- Description: Configuration used for NOELVADV netlist wrapper entities
------------------------------------------------------------------------------
-- The wrapper checks that the passed in configuration matches this package
-- when instantiating the netlist level, the netlist level then uses these
-- constants as generics passed down into the real block. If the generics
-- do not match, the netlist is not used and the standard VHDL module is
-- instantiated directly instead with the generics passed through.

library techmap;
use techmap.gencomp.all;                -- For tech constants

package nvnlconfig is

  -- Configuration used for cpucore netlist wrapper
  -- matches this when instantiating the netlist.
  constant cpucorenvb_strn_cgen    : integer := 2;
  constant cpucorenvb_strn_asyncif : integer := 1;
  constant cpucorenvb_strn_scantest: integer := 0;

  constant cpucorenvb_strn_fabtech       : integer := rhs28; --inferred;
  constant cpucorenvb_strn_memtech       : integer := rhs28; --inferred;
  constant cpucorenvb_strn_cached        : integer := 16#10FF#;
  constant cpucorenvb_strn_wbmask        : integer := 16#50FF#;
  constant cpucorenvb_strn_busw          : integer := 64;
  constant cpucorenvb_strn_sbaddrw       : integer := 36;
  constant cpucorenvb_strn_sbusw         : integer := 128;
  constant cpucorenvb_strn_nstripes      : integer := 4;
  constant cpucorenvb_strn_iphysbits     : integer := 36;
  constant cpucorenvb_strn_dphysbits     : integer := 37;
  constant cpucorenvb_strn_cmemconf      : integer := 34;
  constant cpucorenvb_strn_rfconf        : integer := 1;
  constant cpucorenvb_strn_fpuconf       : integer := 1;
  constant cpucorenvb_strn_tcmconf       : integer := 0;
  constant cpucorenvb_strn_mulconf       : integer := 3*256 + 0*16 +0;
  constant cpucorenvb_strn_intcconf      : integer := 2;
  constant cpucorenvb_strn_disas         : integer := 0;
  constant cpucorenvb_strn_cfg           : integer := 0;

  -- -- Additional configuration for leon5adv
  -- constant leon5advnl_ncpu : integer := 4;
  -- constant leon5advnl_ilinesize : integer := 8;
  -- constant leon5advnl_dlinesize : integer := 8;

  -- -- Additional configuration for dbgmod5adv_cpu
  -- constant dbgmod5advnl_itentr : integer := 1024;

  -- -- Additional configuration for interconnect
  -- constant leon5advnl_cwbmask  : integer := 0;
  -- constant leon5advnl_cbusw    : integer := 32;
  -- constant leon5advnl_dphysbits : integer := 37;

  -- -- Additional configuration for cluster
  -- constant leon5advnl_statcfg : integer := 0;

end package;

