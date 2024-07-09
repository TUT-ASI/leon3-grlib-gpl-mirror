------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
use gaisler.noelv.nv_cpu_cfg_type;

package noelv_cpu_cfg is

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
    ext_sstc      => 1,
    ext_smaia     => 1,
    ext_ssaia     => 1,
    ext_smstateen => 1,
    ext_smrnmi    => 1,
    ext_ssdbltrp  => 1,
    ext_smdbltrp  => 1,
    ext_sddbltrp  => 1,
    ext_smepmp    => 1,
    imsic         => 1,
    ext_zicbom    => 1,
    ext_zicond    => 1,
    ext_zimop     => 1,
    ext_zcmop     => 1,
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
    div_hiperf    => 1,
    div_small     => 0,
    late_branch   => 1,
    late_alu      => 1,
    ras           => 2,
    bhtentries    => 128,
    bhtlength     => 5,
    predictor     => 2,
    btbentries    => 16,
    btbsets       => 2);

end;

