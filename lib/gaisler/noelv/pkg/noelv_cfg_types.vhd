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
-- Entity:      noelv_cfg_types
-- File:        noelv_cfg_types.vhd
-- Author:      Nils Wessman Cobham Gaisler AB
-- Description: NOEL-V custom CPU configuration
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library gaisler;

package noelv_cfg_types is

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
    ext_smcntrpmf : integer;
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
    ext_smpmpmt   : integer;
    ext_svnapot   : integer;
    imsic         : integer;
    neiid         : integer;
    ext_capability  : integer;
    ext_diagnostics : integer;
    ext_hwassert  : integer;
    ext_noelv     : integer;
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
    pma_readout   : integer;
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
    rdv     : integer;
  end record;

end;

package body noelv_cfg_types is
end;

