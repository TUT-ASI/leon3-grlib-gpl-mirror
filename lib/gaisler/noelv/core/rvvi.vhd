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
-- Package:     rvvi
-- File:        rvvi.vhd
-- Description: Internal package for RVVI interface for NOEL-V
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
--use grlib.stdlib.all;
use grlib.stdlib.tost;
use grlib.stdlib.tost_bits;
use grlib.stdlib.print;
use grlib.stdlib.log2;
use grlib.riscv.all;
-- pragma translate_off
use grlib.riscv_disas.all;
-- pragma translate_on


library gaisler;
use gaisler.noelv.all;
use gaisler.noelvtypes.all;
use gaisler.utilnv.all;
--use gaisler.nvsupport.all;
use gaisler.nvsupport.csr_reg_type;
use gaisler.nvsupport.CSRRES;
use gaisler.nvsupport.rvc_expander;
use gaisler.nvsupport.is_fpu_rd;
use gaisler.nvsupport.is_fpu_modify;
use gaisler.nvsupport.rd_gen;
use gaisler.nvsupport.to_mstatus;
use gaisler.nvsupport.to_mstatush;
use gaisler.nvsupport.to_hstatus;
use gaisler.nvsupport.to_sstatus;
use gaisler.nvsupport.to_vsstatus;
use gaisler.nvsupport.to_envcfg;
use gaisler.nvsupport.to_mseccfg;
use gaisler.nvsupport.to_hvictl;
use gaisler.nvsupport.to_hpmevent;
use gaisler.nvsupport.to_hpmeventh;
use gaisler.nvsupport.CSR_SIE_MASK;
use gaisler.nvsupport.CSR_SIP_MASK;
use gaisler.nvsupport.selector2wordx;
use gaisler.nvsupport.pmpcfg;
use gaisler.noelvint.fpu5_out_type;
use gaisler.noelvint.fpu5_out_none;
use gaisler.noelvint.fpu5_out_async_type;
use gaisler.noelvint.fpu5_out_async_none;
use gaisler.noelvint.trace_info;
use gaisler.noelvint.trace_info_none;

package rvvi is
end;


