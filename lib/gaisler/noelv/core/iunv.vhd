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
---------------------------------------------------------------------------------
-- Entity:      iunv
-- File:        iunv.vhd
-- Author:      Andrea Merlo Cobham Gaisler AB
--              Alen Bardizbanyan Cobham Gaisler AB
--              Johan Klockars Cobham Gaisler AB
--              Nils Wessman Cobham Gaisler AB
-- Description: NOEL-V 7-stage integer pipeline
---------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.riscv.all;
use grlib.stdlib.tost;
use grlib.stdlib.tost_bits;
use grlib.stdlib.log2;
use grlib.stdlib.log2x;
use grlib.stdlib."-";
use grlib.stdlib.notx;
library gaisler;
use gaisler.noelvtypes.all;
use gaisler.utilnv.all;
use gaisler.nvsupport.all;
use gaisler.noelv.XLEN;
use gaisler.noelv.GEILEN;
use gaisler.noelv.CAUSELEN;
use gaisler.noelv.nv_irq_in_type;
use gaisler.noelv.nv_irq_out_type;
use gaisler.noelv.nv_nmirq_in_type;
use gaisler.noelv.nv_debug_in_type;
use gaisler.noelv.nv_debug_out_type;
use gaisler.noelv.nv_debug_out_none;
use gaisler.noelv.nv_counter_out_type;
use gaisler.noelv.nv_etrace_type;
use gaisler.noelv.nv_etrace_none;
use gaisler.mmucacheconfig.from_atp;
use gaisler.mmucacheconfig.to_satp;
use gaisler.mmucacheconfig.to_vsatp;
use gaisler.mmucacheconfig.to_hgatp;
use gaisler.mmucacheconfig.has_pt;
use gaisler.fputilnv.fpevt_t;
use gaisler.fputilnv.fpuevent_t;
use gaisler.fputilnv.fpu_event;
use gaisler.fputilnv.fpu_illegal;
use gaisler.fputilnv.imm_create;
use gaisler.alunv.alu_ctrl;
use gaisler.alunv.alu_ctrl_none;
use gaisler.alunv.alu_gen;
use gaisler.alunv.alu_illegal;
use gaisler.alunv.alu_execute;
use gaisler.alunv.reverse;
use gaisler.alunv.clz;
use gaisler.alunv.pop;
use gaisler.noelvint.nv_icache_in_type;
use gaisler.noelvint.nv_icache_out_type;
use gaisler.noelvint.nv_bht_in_type;
use gaisler.noelvint.nv_bht_out_type;
use gaisler.noelvint.nv_btb_in_type;
use gaisler.noelvint.nv_btb_out_type;
use gaisler.noelvint.nv_ras_in_type;
use gaisler.noelvint.nv_ras_in_none;
use gaisler.noelvint.nv_ras_out_type;
use gaisler.noelvint.nv_ras_out_none;
use gaisler.noelvint.nv_dcache_in_type;
use gaisler.noelvint.nv_dcache_in_none;
use gaisler.noelvint.nv_dcache_out_type;
use gaisler.noelvint.iregfile_in_type;
use gaisler.noelvint.iregfile_out_type;
use gaisler.noelvint.mul_in_type;
use gaisler.noelvint.mul_in_none;
use gaisler.noelvint.mul_out_type;
use gaisler.noelvint.div_in_type;
use gaisler.noelvint.div_in_none;
use gaisler.noelvint.div_out_type;
use gaisler.noelvint.imsic_in_type;
use gaisler.noelvint.imsic_in_none;
use gaisler.noelvint.imsic_out_type;
use gaisler.noelvint.fpu5_in_type;
use gaisler.noelvint.fpu5_in_none;
use gaisler.noelvint.fpu5_in_async_type;
use gaisler.noelvint.fpu5_in_async_none;
use gaisler.noelvint.fpu5_out_type;
use gaisler.noelvint.fpu5_out_none;
use gaisler.noelvint.fpu5_out_async_type;
use gaisler.noelvint.fpu5_out_async_none;
use gaisler.noelvint.itrace_in_type;
use gaisler.noelvint.itrace_out_type;
use gaisler.noelvint.nv_csr_in_type;
use gaisler.noelvint.nv_csr_out_type;
use gaisler.noelvint.nv_csr_out_type_none;
use gaisler.noelvint.nv_trace_out_type;
use gaisler.noelvint.trace_info;
use gaisler.noelvint.trace_info_none;
use gaisler.noelvint.trace_rst;
use gaisler.noelvint.pmpcfg_vec_type;
use gaisler.noelvint.pmp_precalc_none;
use gaisler.noelvint.pmp_precalc_vec;
use gaisler.noelvint.atp_type;
use gaisler.noelvint.atp_none;



entity iunv is
  generic (
    fabtech           : integer range 0  to NTECH;    -- fabtech
    memtech           : integer range 0  to NTECH;    -- memtech
    -- Core
    physaddr          : integer range 32 to 56;       -- Physical Addressing
    addr_bits         : integer range 32 to 64;       -- Max bits required for an address
    rstaddr           : integer;                      -- Reset vector (MSB)
    perf_cnts         : integer range 0  to 29;       -- Number of performance counters
    perf_evts         : integer range 0  to 255;      -- Number of performance events
    perf_bits         : integer range 0  to 64;       -- Bits of performance counting
    illegalTval0      : integer range 0  to 1;        -- Zero TVAL on illegal instruction
    no_muladd         : integer range 0  to 1;        -- 1 - multiply-add not supported
    single_issue      : integer range 0  to 1;        -- 1 - only one pipeline
    -- Caches
    iways             : integer range 1  to 8;        -- I$ Ways
    dways             : integer range 1  to 8;        -- D$ Ways
    dlinesize         : integer range 4  to 8;        -- D$ Cache Line Size (words)
    itcmen            : integer range 0  to 1;        -- Instruction TCM
    dtcmen            : integer range 0  to 1;        -- Data TCM
    -- MMU
    mmuen             : integer range 0  to 1;        -- 0 - MMU disable
    riscv_mmu         : integer range 0  to 3;        -- sparc / sv32 / sv39 /s48
    pmp_no_tor        : integer range 0  to 1;        -- Disable PMP TOR (not with TLB PMP)
    pmp_entries       : integer range 0  to 16;       -- Implemented PMP registers
    pmp_g             : integer range 0  to 10;       -- PMP grain is 2^(pmp_g + 2) bytes
    pma_entries       : integer range 0  to 16;       -- Implemented PMA entries
    pma_masked        : integer range 0  to  1;       -- PMA done using masks
    asidlen           : integer range 0  to 16;       -- Max 9 for Sv32
    vmidlen           : integer range 0  to 14;       -- Max 7 for Sv32
    -- Interrupts
    imsic             : integer range 0  to  1;       -- IMSIC implemented
    -- RNMI
    rnmi_iaddr        : integer;                      -- RNMI interrupt trap handler address
    rnmi_xaddr        : integer;                      -- RNMI exception trap handler address
    -- Extensions
    ext_noelv         : integer range 0  to 1;        -- NOEL-V Extensions
    ext_noelvalu      : integer range 0  to 1;        -- NOEL-V ALU Extensions
    ext_m             : integer range 0  to 1;        -- M Base Extension Set
    ext_a             : integer range 0  to 1;        -- A Base Extension Set
    ext_c             : integer range 0  to 1;        -- C Base Extension Set
    ext_h             : integer range 0  to 1;        -- H-Extension
    ext_zcb           : integer range 0  to 1;        -- Zcb Extension
    ext_zba           : integer range 0  to 1;        -- Zba Extension
    ext_zbb           : integer range 0  to 1;        -- Zbb Extension
    ext_zbc           : integer range 0  to 1;        -- Zbc Extension
    ext_zbs           : integer range 0  to 1;        -- Zbs Extension
    ext_zbkb          : integer range 0  to 1;        -- Zbkb Extension
    ext_zbkc          : integer range 0  to 1;        -- Zbkc Extension
    ext_zbkx          : integer range 0  to 1;        -- Zbkx Extension
    ext_sscofpmf      : integer range 0  to 1;        -- Sscofpmf Extension
    ext_smcdeleg      : integer range 0  to 1;        -- Smcdeleg Extension
    ext_shlcofideleg  : integer range 0  to 1;        -- Shlocfideleg Extension
    ext_sstc          : integer range 0  to 2;        -- Sctc Extension (2 : only time csr impl.)
    ext_smaia         : integer range 0  to 1;        -- Smaia Extension
    ext_ssaia         : integer range 0  to 1;        -- Ssaia Extension
    ext_smstateen     : integer range 0  to 1;        -- Sstateen Extension
    ext_smrnmi        : integer range 0  to 1;        -- Smrnmi Extension
    ext_ssdbltrp      : integer range 0  to 1;        -- Ssdbltrp Extension
    ext_smdbltrp      : integer range 0  to 1;        -- Smdbltrp Extension
    ext_smepmp        : integer range 0  to 1;        -- Smepmp Extension
    ext_svadu         : integer range 0  to 1;        -- Svadu Extension
    ext_zicbom        : integer range 0  to 1;        -- Zicbom Extension
    ext_zicond        : integer range 0  to 1;        -- Zicond Extension
    ext_zimop         : integer range 0  to 1;        -- Zimop Extension
    ext_zcmop         : integer range 0  to 1;        -- Zcmop Extension
    ext_zicfiss       : integer range 0  to 1;        -- Zicfiss Extension
    ext_zicfilp       : integer range 0  to 1;        -- Zicfilp Extension
    ext_svinval       : integer range 0  to 1;        -- Svinval Extension
    ext_zfa           : integer range 0  to 1;        -- Zfa Extension
    ext_zfh           : integer range 0  to 1;        -- Zfh Extension
    ext_zfhmin        : integer range 0  to 1;        -- Zfhmin Extension
    ext_zfbfmin       : integer range 0  to 1;        -- Zfbfmin Extension
    mode_s            : integer range 0  to 1;        -- Supervisor Mode Support
    mode_u            : integer range 0  to 1;        -- User Mode Support
    dmen              : integer range 0  to 1;        -- Using RISC-V Debug Module
    fpulen            : integer range 0  to 128;      -- Floating-point precision
    fpuconf           : integer range 0  to 1;        -- 0 = nanoFPUnv, 1 = GRFPUnv
    trigger           : integer range 0  to 4096;
    -- Advanced Features
    late_branch       : integer range 0  to 1;        -- Late Branch Support
    late_alu          : integer range 0  to 1;        -- Late ALUs Support
    ras               : integer range 0  to 2;        -- Return Address Stack (1 - test, 2 - enable)
    -- Misc
    pbaddr            : integer;                      -- Program buffer exe address
    tbuf              : integer;                      -- Trace buffer size in kB
    scantest          : integer;                      -- Scantest support
    rfreadhold        : integer range 0  to 1;        -- Register File Read Hold
    dsuen_delay       : integer range 0  to 1 := 1;   -- Delay dbgi.dsuen (no UNOPTFLAT with Verilator)
    show_misa_x       : integer range 0  to 1 := 1;   -- Extensions visible in MISA X
    allow_x_ctrl      : integer range 0  to 1 := 1;   -- Allow X to be turned off
    fpu_debug         : integer range 0  to 1 := 0;   -- FCSR bits for controlling the FPU
    fpu_lane          : integer range 0  to 1 := 0;   -- Lane where (non-memory) FPU instructions go
    endian            : integer range 0  to 1         -- 1 - little endian
    );
  port (
    clk            : in  std_ulogic;           -- Clock
    rstn           : in  std_ulogic;           -- Active low reset
    holdn          : in  std_ulogic;           -- Active low hold signal
    ici            : out nv_icache_in_type;    -- I$ In Port
    ico            : in  nv_icache_out_type;   -- I$ Out Port
    bhti           : out nv_bht_in_type;       -- BHT In Port
    bhto           : in  nv_bht_out_type;      -- BHT Out Port
    btbi           : out nv_btb_in_type;       -- BTB In Port
    btbo           : in  nv_btb_out_type;      -- BTB Out Port
    rasi           : out nv_ras_in_type;       -- RAS In Port
    raso           : in  nv_ras_out_type;      -- RAS Out Port
    dci            : out nv_dcache_in_type;    -- D$ In Port
    dco            : in  nv_dcache_out_type;   -- D$ Out Port
    rfi            : out iregfile_in_type;     -- Regfile In Port
    rfo            : in  iregfile_out_type;    -- Regfile Out Port
    imsici         : out imsic_in_type;        -- IMSIC In Port
    imsico         : in  imsic_out_type;       -- IMSIC Out Port
    irqi           : in  nv_irq_in_type;       -- Irq In Port
    irqo           : out nv_irq_out_type;      -- Irq Out Port
    dbgi           : in  nv_debug_in_type;     -- Debug In Port
    dbgo           : out nv_debug_out_type;    -- Debug Out Port
    muli           : out mul_in_type;          -- Mul Unit In Port
    mulo           : in  mul_out_type;         -- Mul Unit Out Port
    divi           : out div_in_type;          -- Div Unit In Port
    divo           : in  div_out_type;         -- Div Unit Out Port
    fpui           : out fpu5_in_type;         -- FPU Unit In Port
    fpuia          : out fpu5_in_async_type;   -- FPU Unit In Port
    fpuo           : in  fpu5_out_type;        -- FPU Unit Out Port
    fpuoa          : in  fpu5_out_async_type;  -- FPU Unit Out Port
    cnt            : out nv_counter_out_type;  -- Perf event Out Port
    itracei        : out itrace_in_type;       -- Trace information
    itraceo        : in  itrace_out_type;      -- Trace control
    pma_addr       : in  word64_arr(0 to PMAENTRIES - 1);  -- PMA addresses
    pma_data       : in  word64_arr(0 to PMAENTRIES - 1);  -- PMA configuration
    csr_mmu        : out nv_csr_out_type;      -- CSR values for MMU
    mmu_csr        : in  nv_csr_in_type;       -- CSR values for MMU
    perf           : in  std_logic_vector(31 downto 0);  -- Performance data
    cap            : in  std_logic_vector(9 downto 0);   -- Trace capability
    tbo            : in  nv_trace_out_type;    -- Trace Unit Out Port
    eto            : out nv_etrace_type;       -- E-trace output
    sclk           : in  std_ulogic;           -- [Currently unused]
    pwrd           : out std_ulogic;           -- Activate power down mode
    testen         : in  std_ulogic;
    testrst        : in  std_ulogic
    );
begin
  assert pma_data'length = pma_addr'length report "PMA configuration error" severity failure;
end;

architecture rtl of iunv is

  -- Regarding instructions swapping lanes vs forwarding
  --
  -- It would complicate things if swap had to be checked
  -- while looking for where to forward from.
  --
  -- Instructions that need to be swapped in the lanes are:
  -- 0 -> 1
  --   JAL, JALR, BRANCH
  --   CSRs, if csr_lane = 1
  --   FPU (except load/store), if fpu_lane = 1
  -- 1 -> 0
  --   load/store integer/FPU
  --   amo, fence, sfence.vma
  --   CSRs, if csr_lane = 0
  --   FPU, if fpu_lane = 0
  --
  -- Some of the above do not have IU destinations,
  -- so for forwarding only the following are relevant:
  -- 0 -> 1
  --   JAL, JALR
  --   CSRs, if csr_lane = 1
  --   FPU with IU result, if fpu_lane = 1
  -- 1 -> 0
  --   load integer, amo
  --   CSRs, if csr_lane = 0
  --   FPU with IU result, if fpu_lane = 0
  --
  -- Currently, FPU instructions are not paired with anything
  -- (although it should be possible to do pairing for those that
  -- do not give IU results - for the IU result ones the issue is
  -- with multi-cycle EX not working),
  -- so for forwarding we are (currently) left with:
  -- (When FPU pairing is allowed, it must be ensured that FPU->IU
  --  instructions do not pair and swap with anything that has
  --  the same destination register!)
  -- 0 -> 1
  --   JAL, JALR
  --   CSRs, if csr_lane = 1
  -- 1 -> 0
  --   load integer, amo
  --   CSRs, if csr_lane = 0
  --
  -- JAL/JALR will not pair when first due to control flow change,
  -- so there will never be a swap with them paired.
  -- (If such pairing is allowed, it must be ensured that the
  --  there are not the same destination registers!)
  -- To ensure that load integer and amo destinations do not cause
  -- issues when the same as for a paired other instruction, this
  -- specific case is disallowed by dual_issue_check().
  -- So, we end up with forwarding issues for:
  -- 0 -> 1
  --   CSRs, if csr_lane = 1
  -- 1 -> 0
  --   CSRs, if csr_lane = 0
  --
  -- To avoid any issue with the CSR forwarding, dual_issue_check()
  -- ensures that CSR instructions never pair with other instructions
  -- that have the same destination.

  -- Notes
  -- - Certain tools do not like the use of "constant" as simply a non-modifiable
  --   local declaration in a procedure/function (although that is standards compliant).
  --     For now, always use "variable", but put the actually variable ones
  --     after a "-- Non-constant" marker to ease future cleanup.

  -- Lane where memory operations are handled (must be 0!)
  constant memory_lane : integer := 0;
  -- Lane where CSR operations are handled (must be 0, due to CFI with mem & CSR!)
  constant csr_lane    : integer := 0;
  -- Lane where branches are handled (0 not allowed when dual-issue!)
  constant branch_lane : integer := 1 - single_issue;
  -- Lane 1 (the one that does not exist when not dual-issue!)
  -- No uses of this will be relevant without dual-issue.
  constant one         : integer := 1 - single_issue;

  -- Defined as in MISA
  constant rv : word2 := u2vec(log2(XLEN / 32) + 1, 2);

  function is_rv(len : integer; rv : word2) return boolean is
  begin
    if len /= 32 and len /= 64 and len /= 128 then
      assert false report "Bad XLEN (len)" severity failure;
    end if;

    case rv is
      when "01"   => return len = 32;
      when "10"   => return len = 64;
      when "11"   => return len = 128;
      when others => assert false report "Bad XLEN (rv)" severity failure;
    end case;

    return false;
  end;

  function is_rv32 return boolean is
  begin
    return is_rv(32, rv);
  end;

  function is_rv64 return boolean is
  begin
    return is_rv(64, rv);
  end;

  -- TIME CSR is implemented
  constant time_en : boolean := ext_sstc /= 0;

  -- Extension Set Constants
  constant ext_f        : integer := to_floating(fpulen, 32);
  constant ext_d        : integer := to_floating(fpulen, 64);
  constant ext_q        : integer := to_floating(fpulen, 128);
  constant ext_n        : integer := 0;  -- User mode interrupt extention does not currently exist

  constant pmaen        : boolean := pma_entries /= 0;

  -- Disable general indirect CSR access, for now, unless needed.
  -- Smcsrind Extension
  constant ext_smcsrind : integer range 0 to 1 :=
    u2i(ext_smcdeleg /= 0 or imsic /= 0
    );
  -- Sscsrind Extension
  constant ext_sscsrind : integer range 0 to 1 :=
    u2i(ext_smcsrind /= 0 and mode_s /= 0);

  -- Keep track of active extensions, to enable functions/procedures
  -- in packages to get hold of that information.
  constant active_extensions : extension_type :=
    extension(x_single_issue, is_set(single_issue))  or
    extension(x_late_alu,     is_set(late_alu))      or
    extension(x_late_branch,  is_set(late_branch))   or
    extension(x_muladd,       not is_set(no_muladd)) or
    extension(x_fpu_debug,    is_set(fpu_debug))     or
    extension(x_dtcm,         is_set(dtcmen))        or
    extension(x_itcm,         is_set(itcmen))        or
    extension(x_rv64,         is_rv64)               or
    extension(x_mode_u,       is_set(mode_u))        or
    extension(x_mode_s,       is_set(mode_s))        or
    extension(x_noelv,        is_set(ext_noelv))     or
    extension(x_noelvalu,     is_set(ext_noelvalu))  or
    extension(x_m,            is_set(ext_m))         or
    extension(x_f,            is_set(ext_f))         or
    extension(x_d,            is_set(ext_d))         or
    extension(x_q,            is_set(ext_q))         or
    extension(x_n,            is_set(ext_n))         or
    extension(x_a,            is_set(ext_a))         or
    extension(x_c,            is_set(ext_c))         or
    extension(x_zcb,          is_set(ext_zcb))       or
    extension(x_h,            is_set(ext_h))         or
    extension(x_sscofpmf,     is_set(ext_sscofpmf))  or
    extension(x_sstc,         (ext_sstc = 1))        or
    extension(x_imsic,        is_set(imsic))         or
    extension(x_smaia,        is_set(ext_smaia))     or
    extension(x_ssaia,        is_set(ext_ssaia))     or
    extension(x_smstateen,    is_set(ext_smstateen)) or
    extension(x_smrnmi,       is_set(ext_smrnmi))    or
    extension(x_ssdbltrp,     is_set(ext_ssdbltrp))  or
    extension(x_smdbltrp,     is_set(ext_smdbltrp))  or
    extension(x_smepmp,       is_set(ext_smepmp))    or
    extension(x_smcsrind,     is_set(ext_smcsrind))  or  -- + ext_smaia)) or
    extension(x_sscsrind,     is_set(ext_sscsrind))  or  -- + ext_ssaia)) or
    extension(x_svadu,        is_set(ext_svadu))     or
    extension(x_zicbom,       is_set(ext_zicbom))    or
    extension(x_zicboz,       false)                 or
    extension(x_zicond,       is_set(ext_zicond))    or
    extension(x_zimop,        is_set(ext_zimop))     or
    extension(x_zcmop,        is_set(ext_zcmop))     or
    extension(x_zicfiss,      is_set(ext_zicfiss))   or
    extension(x_zicfilp,      is_set(ext_zicfilp))   or
    extension(x_shlcofideleg, is_set(ext_shlcofideleg))  or
    extension(x_smcdeleg,     is_set(ext_smcdeleg))  or
    -- extension(x_ssccfg,       is_set(ext_ssccfg))  or
    extension(x_svinval,      is_set(ext_svinval))   or
    extension(x_zfa,          is_set(ext_zfa))       or
    extension(x_zfh,          is_set(ext_zfh))       or
    extension(x_zfhmin,       is_set(ext_zfhmin + ext_zfh)) or
    extension(x_zfbfmin,      is_set(ext_zfbfmin))   or
    extension(x_time,         is_set(ext_sstc))      or
    extension(x_sdtrig,       is_set(trigger))       or
    extension(x_zba,          is_set(ext_zba))       or
    extension(x_zbb,          is_set(ext_zbb))       or
    extension(x_zbc,          is_set(ext_zbc))       or
    extension(x_zbs,          is_set(ext_zbs))       or
    extension(x_zbkb,         is_set(ext_zbkb))      or
    extension(x_zbkc,         is_set(ext_zbkc))      or
    extension(x_zbkx,         is_set(ext_zbkx));

  -- Supported xENVCFG extensions
  constant active_menvcfg : csr_menvcfg_const_type := gen_envcfg_const_mmask(active_extensions);
  constant active_henvcfg : csr_henvcfg_const_type := gen_envcfg_const_hmask(active_menvcfg);
  constant active_senvcfg : csr_senvcfg_const_type := gen_envcfg_const_smask(active_menvcfg);

  constant lane : lane_select := (
    fpu    => fpu_lane,
    csr    => csr_lane,
    branch => branch_lane,
    memory => memory_lane
  );

  -------------------------------------------------------------------------------
  -- Constant Declarations
  -------------------------------------------------------------------------------

  constant va         : std_logic_vector := gaisler.mmucacheconfig.va(riscv_mmu);
  constant pa         : std_logic_vector := gaisler.mmucacheconfig.pa(riscv_mmu);
  constant pmp_msb    : integer          := physaddr - 1;    -- High bit for PMP checks

  -- Implementation Constants
--  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1
--                                     and GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 0;
  constant RESET_ALL    : boolean := true;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant ENDIAN_B     : boolean := (endian /= 0);

  -- Use old implementation of rd, rs equal check.
  constant OLD_RD_VS_RS  : boolean := false; --(fabtech = virtex4);
  constant NO_PREFORWARD : boolean := false; --(fabtech = virtex4);

  -- Pipeline Constants
  constant lanes        : std_logic_vector(0 to 1 - single_issue) := (others => '0');  -- Used as range.

  -- Cache Constants
  constant DWAYMSB      : integer := log2x(dways) - 1;
  constant IWAYMSB      : integer := log2x(iways) - 1;
  constant DYNRST       : boolean := (rstaddr = 16#FFFFF#);

  -- Trace Buffer Constants
  constant TBUFBITS     : integer := 4 + log2(tbuf);

  -- Power down constants
  constant PWRDEN       : boolean := false;


  constant non_standard : std_logic := to_bit(ext_noelv + ext_noelvalu);
  -- ISA Constants
  constant B_EXT         : std_logic := to_bit(ext_zba) and to_bit(ext_zbb) and to_bit(ext_zbs);

  constant ISA_EXTENSION : std_logic_vector(25 downto 0) :=
    '0'                 &     -- Z Reserved
    '0'                 &     -- Y Reserved
    non_standard        &     -- X Non-standard
    '0'                 &     -- W Reserved
    '0'                 &     -- V
    to_bit(mode_u)      &     -- U User mode
    '0'                 &     -- T
    to_bit(mode_s)      &     -- S Supervisor mode
    '0'                 &     -- R Reserved
    to_bit(ext_q)       &     -- Q
    '0'                 &     -- P
    '0'                 &     -- O Reserved
    '0'                 &     -- N
    to_bit(ext_m)       &     -- M
    '0'                 &     -- L
    '0'                 &     -- K Reserved
    '0'                 &     -- J
    '1'                 &     -- I RV32/64I base ISA
    to_bit(ext_h)       &     -- H Hypervisor extension
    '0'                 &     -- G
    to_bit(ext_f)       &     -- F
    '0'                 &     -- E
    to_bit(ext_d)       &     -- D
    to_bit(ext_c)       &     -- C
    B_EXT               &     -- B
    to_bit(ext_a);            -- A

  -- A set bit marks that the corresponding extension etc can be disabled.
  -- Note that each such bit added will need code changes to actually be useful.
  -- Current things that can be disabled:
  constant c_ctrl      : integer := 2;   -- Compressed instructions extension (C)
  constant h_ctrl      : integer := 7;   -- Hypervisor extension (H)
  constant x_ctrl      : integer := 23;  -- Non-standard extensions (X)
  constant ISA_CONTROL : wordx   := (
    h_ctrl => '1',
    x_ctrl => to_bit(allow_x_ctrl),
    others => '0'
  );
  constant ISA_DEFAULT : word    := "000000" & ISA_EXTENSION;
  constant misa_ctrl   : boolean := true;  -- MISA changes allowed?

  function counter_mask(counters : integer range 0 to 29) return word is
    -- Non-constant
    variable mask : word := zerow;
  begin
    mask(counters + 3 - 1 downto 3) := (others => '1');

    return mask;
  end;

  constant counter_ok  : word := counter_mask(perf_cnts);

  function create_misa return wordx is
    -- Non-constant
    variable misa : wordx := zerox;
  begin
    misa(misa'high downto misa'high - 1) := rv;
    misa(ISA_EXTENSION'range)            := ISA_DEFAULT(ISA_EXTENSION'range);

    return misa;
  end;

  function mask_misa(misa : wordx; misa_w : wordx) return wordx is
    -- Non-constant
    variable misa_w_masked : wordx := misa_w;
    variable result        : wordx;
  begin
    if not misa_ctrl then
      return misa;
    end if;

    -- Don't allow setting extensions that are not actually enabled!
    misa_w_masked(ISA_EXTENSION'range) := misa_w(ISA_EXTENSION'range) and ISA_EXTENSION;

    -- It cannot be allowed to set higher XLEN than what is available!
    -- (Actually allowing XLEN changes is a different matter.)
    case XLEN is
    when 32 =>
      misa_w_masked(misa'high downto misa'high - 1) := "01";
    when 64 =>
      if misa_w(misa'high downto misa'high - 1) = "11" or
         misa_w(misa'high downto misa'high - 1) = "00" then
        misa_w_masked(misa'high downto misa'high - 1) := "10";
      end if;
    when others =>  -- 128
      if misa_w(misa'high downto misa'high - 1) = "00" then
        misa_w_masked(misa'high downto misa'high - 1) := "11";
      end if;
    end case;

    result := (misa and (not ISA_CONTROL)) or (misa_w_masked and ISA_CONTROL);

    return result;
  end;

  -- Smstateen
  constant CSR_MSTATEEN0_MASK : csr_mstateen0_type := gen_mstateen0_mask(active_extensions);


  -- Debug Constants
  function create_dprogbuf return wordx is
    -- Non-constant
    variable addr : wordx := zerox;
  begin
    addr(31 downto 12) := u2vec(pbaddr, 20);

    return addr;
  end;

  constant DPROGBUF : wordx := create_dprogbuf;


  -- Trigger constants
  constant TRIGGER_MC_NUM : integer range 0 to 16 := (trigger mod 16);        -- MCONTROL
  constant TRIGGER_IC_NUM : integer range 0 to 1  := ((trigger / 16) mod 2);  -- ICOUNT
  constant TRIGGER_IE_NUM : integer range 0 to 2  := ((trigger / 32) mod 3);  -- I/E TRIGGER
  constant TRIGGER_NUM    : integer range 0 to 19 := TRIGGER_MC_NUM + TRIGGER_IC_NUM + TRIGGER_IE_NUM;
  constant MCONTROL6_LOWBITS      : integer range 6 to 64 := 28; -- Number of bits compared in execute stage
  constant MCONTROL_COMPATIBILITY : integer range 0 to 1  := 1;  -- Enables legacy MCONTROL trigger type



  -------------------------------------------------------------------------------
  -- Type Declarations
  -------------------------------------------------------------------------------


  -- Pipeline

  -- The maximum bits that are required to hold an address (physical or virtual).
  -- May be two bits longer than the actual address, since we need to keep track of
  -- whether higher bits are the same or not (not same - bad address).
  subtype addr_type is std_logic_vector(cond(addr_bits = XLEN, addr_bits - 1, addr_bits + 1) downto 0);

  function to_addr(addr_in : std_logic_vector) return addr_type is
  begin
    return to_addr(addr_in, addr_type'length);
  end;

  -- This is the maximum number of bits that need to be stored for PC,
  -- but calculations need full 64 bits (or at least check for bad address).
  subtype pctype              is addr_type;

  subtype lanes_range         is integer range lanes'range;
  subtype lanes_type          is std_logic_vector(lanes'high downto lanes'low);  -- Must be n downto 0!

  -- Lanes types
  -- These would be nicer with just (lanes'range),
  -- but for some reason Vivado XSIM 2018.1 is then likely to crash.
  subtype word_lanes_type     is word_arr(lanes'low to lanes'high);
  subtype wordx_lanes_type    is wordx_arr(lanes'low to lanes'high);
  subtype word16_lanes_type   is word16_arr(lanes'low to lanes'high);
  type    pc_lanes_type       is array (lanes'low to lanes'high) of pctype;
  type    rfa_lanes_type      is array (lanes'low to lanes'high) of reg_t;
  type    word2_lanes_type    is array (lanes'low to lanes'high) of word2;
  type    word3_lanes_type    is array (lanes'low to lanes'high) of word3;
  type    fusel_lanes_type    is array (lanes'low to lanes'high) of fuseltype;
  type    rs_lanes_type       is array (lanes'low to lanes'high) of std_logic_vector(1 to 2);
  type    mux_lanes_type      is array (lanes'low to lanes'high) of word3;
  type    cause_lanes_type    is array (lanes'low to lanes'high) of cause_type;
  type    alu_ctrl_lanes_type is array (lanes'low to lanes'high) of alu_ctrl;


  -- These are for the two fetched instructions, not lanes!
  constant fetch             : std_logic_vector(0 to 1) := (others => '0');    -- Used as range.
  subtype fetch_pair        is std_logic_vector(fetch'high downto fetch'low);  -- Must be n downto 0!
  -- These would be nicer with just (fetch'range),
  -- but for some reason Vivado XSIM 2018.1 is then likely to crash.
  subtype iword_pair_type   is iword_tuple_type(fetch'low to fetch'high);
  subtype wordx_pair_type   is wordx_arr(fetch'low to fetch'high);
  subtype word16_fetch_type is word16_arr(fetch'low to fetch'high);
  type    pc_fetch_type     is array (fetch'range) of pctype;
  type    rfa_fetch_type    is array (fetch'range) of reg_t;
  type    fusel_fetch_type  is array (fetch'range) of fuseltype;
  type    cause_fetch_type  is array (fetch'range) of cause_type;

  -- Caches
  subtype icdtype           is word64_arr(0 to iways - 1);
  subtype dcdtype           is word64_arr(0 to dways - 1);

  -- PC
  constant PC_ZERO           : pctype    := (others => '0');
  constant PC_RESET          : pctype    := PC_ZERO(PC_ZERO'high downto 32) &
                                            u2vec(rstaddr, 20) & PC_ZERO(11 downto 0);

  constant PC_RNMI_ITRAP     : pctype    := PC_ZERO(PC_ZERO'high downto 32) &
                                            u2vec(rnmi_iaddr, 20) & PC_ZERO(11 downto 0);
  constant PC_RNMI_XTRAP     : pctype    := PC_ZERO(PC_ZERO'high downto 32) &
                                            u2vec(rnmi_xaddr, 20) & PC_ZERO(11 downto 0);

  -- Triggers
  -- Function to avoid defining types with a negative index when
  -- the number of implemented triggers is zero
  function trig_index(trigger_num : integer) return integer is
  begin
    if trigger_num = 0 then
      return 0;
    else
      return trigger_num - 1;
    end if;
  end;

  subtype trighit_type    is std_logic_vector(trig_index(TRIGGER_MC_NUM + TRIGGER_IC_NUM) downto 0);
  subtype mc6hit_type     is std_logic_vector(trig_index(TRIGGER_MC_NUM) downto 0);
  subtype contexthit_type is std_logic_vector(trig_index(TRIGGER_NUM) downto 0);
  type trighit_vector     is array (lanes'high downto lanes'low) of trighit_type;
  type trig_action_type   is array (lanes'high downto lanes'low) of std_logic_vector(1 downto 0);
  type trig_priority_type is array (lanes'high downto lanes'low) of std_logic_vector(1 downto 0);

  type trig_exception_type is record
    xc            : std_ulogic;
    xcs           : lanes_type;
    cause         : cause_type;
    flush         : word2;
    action0       : std_ulogic;
    trig_flushall : std_ulogic;
    xc_lane       : std_ulogic;
    valid         : std_ulogic;
    ie_trig_taken : lanes_type;
    trig_taken    : std_ulogic;
    mc6tval       : wordx;
    pc            : pctype;
  end record;

  constant trig_exception_none : trig_exception_type := (
    xc            => '0',
    xcs           => (others => '0'),
    cause         => cause_res,
    flush         => "00",
    action0       => '0',
    trig_flushall => '0',
    xc_lane       => '0',
    valid         => '0',
    ie_trig_taken => (others => '0'),
    trig_taken    => '0',
    mc6tval       => (others => '0'),
    pc            => PC_ZERO
  );

  -- Hardware Performance Monitor Counters
  subtype hpm_events_type        is std_logic_vector(0 to HWPERFMONITORS+3-1);
  type    hpm_events_vector_type is array (0 to 1) of hpm_events_type;

  -- Stages
  type stage_type is (a, e, m, x, wb, pwb0, pwb1);

  -- Branch Type ----------------------------------------------------------------
  type branch_type is record
    valid       : std_ulogic;                          -- instruction is a branch instruction
    addr        : pctype;                              -- target address where to branch
    naddr       : pctype;                              -- address of the next instruction
    taken       : std_ulogic;                          -- branch has been taken
    hit         : std_ulogic;                          -- branch target address has been found in the BTB
    mpred       : std_ulogic;                          -- branch mispredicted
  end record;

  type branch_pair_type is array (lanes'range) of branch_type;

  constant branch_none : branch_type := (
    valid       => '0',
    addr        => PC_ZERO,
    naddr       => PC_ZERO,
    taken       => '0',
    hit         => '0',
    mpred       => '0'
    );

  -- Forwarding type --------------------------------------------------------
  type rd_src_type is array (stage_type'pos(a) to stage_type'pos(wb)) of lanes_type;
  type rd_vs_rs_type is record
    rfa1        : rd_src_type;
    rfa2        : rd_src_type;
  end record;

  constant rd_vs_rs_none : rd_vs_rs_type := ((others => (others => '0')),
                                             (others => (others => '0')));

  subtype rs_type is integer range 1 to 2;
  type rfa_tuple is record
    rs          : rs_type;
    stage       : stage_type;
    lane        : lanes_range;
  end record;
  type rfa_duo is array (1 to 2) of rfa_tuple;

  -- Pipeline Control -----------------------------------------------------------
  type pipeline_ctrl_type is record
    pc          : pctype;                       -- program counter
    inst        : word;                         -- instruction
    cinst       : word16;                       -- compressed instruction
    valid       : std_ulogic;                   -- instruction is valid
    actual      : std_ulogic;                   -- instruction has been valid once
    flushed     : std_ulogic;                   -- instruction has been flushed
    comp        : std_ulogic;                   -- instruction is compressed
    branch      : branch_type;                  -- branch record
    rdv         : std_ulogic;                   -- destination register is valid
    rd_vs_rs    : rd_vs_rs_type;                -- pre-checked forwarding
    csrv        : std_ulogic;                   -- instruction is a CSR one
    csrdo       : std_ulogic;                   -- read only CSR
    xc          : std_ulogic;                   -- exception/trap
    mexc        : std_ulogic;                   -- inst memory excp
    cause       : cause_type;                   -- exception/trap cause
    tval        : wordx;                        -- exception/trap value
    fusel       : fuseltype;                    -- assigned functional unit
    fpu         : fpu_id;                       -- FPU issue ID
    fpu_flush   : std_ulogic;                   -- FPU instruction has been flushed
  end record;

  constant pipeline_ctrl_none   : pipeline_ctrl_type := (
    pc          => PC_RESET,
    inst        => zerow,
    cinst       => zerow16,
    valid       => '0',
    actual      => '0',
    flushed     => '0',
    comp        => '0',
    branch      => branch_none,
    rdv         => '0',
    rd_vs_rs    => rd_vs_rs_none,
    csrv        => '0',
    csrdo       => '0',
    xc          => '0',
    mexc        => '0',
    cause       => cause_res,
    tval        => zerox,
    fusel       => NONE,
    fpu         => (others => '0'),
    fpu_flush   => '0'
    );

  -- Note that this does not contain a valid flag.
  -- That needs to be fetched from .ctrl(csr_lane).valid,
  -- since pipeline flush etc depends on it.
  type csr_type is record
    r        : std_ulogic;
    w        : std_ulogic;
    addr     : csratype;
    raw_cat  : raw_category_t;      -- RaW category to handle RaW CSR dependencies
    waw_cat  : waw_category_t;      -- WaW category to handle WaW CSR dependencies
    hold_cat : hold_category_t;     -- Some CSR accesses need to insert a bubble after RA
    ctrl     : word2;
    imsic    : word3;         -- CSR read from IMSIC
    v        : wordx;         -- Value read from CSR register
  end record;

  constant csr_none : csr_type := (
    r        => '0',
    w        => '0',
    addr     => (others => '0'),
    raw_cat  => (others => '0'),
    waw_cat  => (others => '0'),
    hold_cat => (others => '0'),
    ctrl     => (others => '0'),
    imsic    => (others => '0'),
    v        => (others => '0')
  );

  type pipeline_ctrl_lanes_type is array (lanes'range) of pipeline_ctrl_type;

  -- PC Gen <-> Fetch Stage --------------------------------------------------
  type fetch_reg_type is record
    pc          : pctype;                             -- pc to be fetched
    valid       : std_ulogic;                         -- valid fetch request
    btb_hit     : std_ulogic;                         -- For hpm counters
    ras_hit     : std_ulogic;                         -- For hpm counters
  end record;
  constant fetch_reg_rst : fetch_reg_type := (
    pc      => PC_RESET,
    valid   => '0',
    btb_hit => '0',
    ras_hit => '0'
  );

  -- Fetch Stage <-> Decode Stage --------------------------------------------
  type decode_reg_type is record
    pc         : pctype;                             -- fetched program counter as from fetch stage
    inst       : icdtype;                            -- instructions
    buff       : iqueue_type;                        -- single-entry instruction buffer
    valid      : std_ulogic;                         -- instructions are valid
    xc         : std_ulogic;                         -- exception/trap from previous stages
    cause      : cause_type;                         -- exception/trap cause from previous stages
    tval       : wordx;                              -- exception/trap value from previous stages
    way        : std_logic_vector(IWAYMSB downto 0); -- cache way where instructions are located
    mexc       : std_ulogic;                         -- error in cache access
    was_xc     : std_ulogic;                         -- error just before
    exctype    : std_ulogic;                         -- error type in cache access
    exchyper   : std_ulogic;                         -- Hypervisor exception in cache access
    tval2      : wordx;                              -- Hypervisor exception info from cache
    tval2type  : word2;                              -- Hypervisor exception info from cache
    prediction : prediction_array_type;              -- BHT record
    hit        : std_ulogic;                         -- fetched pc hit BTB
    bjump_pre  : std_logic_vector(1 to 7);
    jump_pre   : std_logic_vector(1 to 7);
    unaligned  : std_ulogic;                         -- unaligned compressed instruction flag due to previous fetched pair
  end record;
  constant decode_reg_rst : decode_reg_type := (
    pc         => PC_RESET,
    inst       => (others => (others => '0')),
    buff       => iqueue_none,
    valid      => '0',
    xc         => '0',
    cause      => RST_HARD_ALL,
    tval       => zerox,
    way        => (others => '0'),
    mexc       => '0',
    was_xc     => '0',
    exctype    => '0',
    exchyper   => '0',
    tval2      => zerox,
    tval2type  => "00",
    prediction => (others => prediction_none),
    hit        => '0',
    bjump_pre  => (others => '0'),
    jump_pre   => (others => '0'),
    unaligned  => '0'
--    v.d.uninst => ("00", (others => '0'), "000")
  );

  -- Decode Stage <-> Register Access Stage -----------------------------------
  type regacc_reg_type is record
    ctrl        : pipeline_ctrl_lanes_type;  -- pipeline control record
    csr         : csr_type;                  -- CSR information
    rfa1        : rfa_lanes_type;            -- register file record for op1
    rfa2        : rfa_lanes_type;            -- register file record for op2
    immv        : lanes_type;                -- immediate as a valid operand flags
    imm         : wordx_lanes_type;          -- immediate operands
    pcv         : lanes_type;                -- program counter as a valid operand flags
    swap        : std_ulogic;                -- instructions are swapped in lanes
    raso        : nv_ras_out_type;           -- RAS record
    rasi        : nv_ras_in_type;            -- speculative RAS record
    csrw_eq     : word4;                     -- related to csr write hold checks
    lalu_pre    : lanes_type;                -- prechecked lalu
  end record;
  constant regacc_reg_rst : regacc_reg_type := (
    ctrl     => (others => pipeline_ctrl_none),
    csr      => csr_none,
    rfa1     => (others => (others => '0')),
    rfa2     => (others => (others => '0')),
    immv     => (others => '0'),
    imm      => (others => zerox),
    pcv      => (others => '0'),
    swap     => '0',
    raso     => nv_ras_out_none,
    rasi     => nv_ras_in_none,
    csrw_eq  => (others => '0'),
    lalu_pre => (others => '0')
  );


  -- ALU Inputs --------------------------------------------------------------
  type alu_type is record
    op1         : wordx;                   -- operand 1
    op2         : wordx;                   -- operand 2
    valid       : std_ulogic;              -- enable signal
    ctrl        : alu_ctrl;                -- ALU control
    lalu        : std_ulogic;              -- instruction makes use of lalu
  end record;
  constant alu_none : alu_type := (
    op1   => zerox,
    op2   => zerox,
    valid => '0',
    ctrl  => alu_ctrl_none,
    lalu  => '0'
  );

  type alu_pair_type is array (lanes'range) of alu_type;

  -- CSR Operation
  constant CSR_BYPASS   : word2 := "00";
  constant CSR_CLEAR    : word2 := "10";
  constant CSR_SET      : word2 := "11";

  -- Register Access Stage <-> Execute Stage ----------------------------------
  type execute_reg_type is record
    ctrl        : pipeline_ctrl_lanes_type;  -- Pipeline control record
    csr         : csr_type;                  -- CSR information
    rfa1        : rfa_lanes_type;            -- Register file record for op1
    rfa2        : rfa_lanes_type;            -- Register file record for op2
    alu         : alu_pair_type;             -- ALUs record
    stdata      : wordx;                     -- Data to be stored for ST instructions
    accesshold  : std_logic_vector(0 to 1);  -- Memory access hold due to CSR access
    exechold    : std_logic_vector(0 to 2);  -- Execution hold due to pipeline flushing instruction
    hpmchold    : std_logic_vector(0 to 5);  -- Execution hold due to read from a hpmcounter CSR
    conthit     : contexthit_type;           -- Trigger context hit
    fpu_valid   : std_ulogic;                -- Synchronous FPU valid
    fpuhold     : std_logic_vector(0 to 5);  -- Execution hold due to FPU instruction.
    tracehold   : std_logic_vector(0 to 5);  -- Execution hold due to not delaying tracing.
    fpu_wait    : std_ulogic;                -- FPU instruction will return result in EX.
    was_held    : std_ulogic;                -- Bubble was inserted after EX
    swap        : std_ulogic;                -- Instructions are swapped
    jimm        : wordx;                     -- Imm Value for Jump Unit
    jop1        : wordx;                     -- Op1 Value for Jump Unit
    jumpforw    : rs_lanes_type;             -- Jump forwarded flags
    aluforw     : rs_lanes_type;             -- ALUs forwarded flags
    alupreforw1 : mux_lanes_type;            -- ALUs preforward information
    alupreforw2 : mux_lanes_type;            -- ALUs preforward information
    stforw      : lanes_type;                -- Store unit forwarded flags
    lbranch     : std_ulogic;                -- Instructions makes use of late branch unit
    spec_ld     : std_ulogic;                -- Speculative load operation flag
    is_wfi      : std_ulogic;                -- Instruction is WFI and it is valid
    raso        : nv_ras_out_type;           -- RAS record
    rasi        : nv_ras_in_type;            -- Speculative RAS record
    bar         : std_logic_vector(2 downto 0);
  end record;
  constant execute_reg_rst : execute_reg_type := (
    ctrl        => (others => pipeline_ctrl_none),
    csr         => csr_none,
    rfa1        => (others => (others => '0')),
    rfa2        => (others => (others => '0')),
    alu         => (others => alu_none),
    stdata      => zerox,
    accesshold  => (others => '0'),
    exechold    => (others => '0'),
    hpmchold    => (others => '0'),
    conthit     => (others => '0'),
    fpu_valid   => '0',
    fpuhold     => (others => '0'),
    tracehold   => (others => '0'),
    fpu_wait    => '0',
    was_held    => '0',
    swap        => '0',
    jimm        => zerox,
    jop1        => zerox,
    jumpforw    => (others => (others => '0')),
    aluforw     => (others => (others => '0')),
    alupreforw1 => (others => (others => '0')),
    alupreforw2 => (others => (others => '0')),
    stforw      => (others => '0'),
    lbranch     => '0',
    spec_ld     => '0',
    is_wfi      => '0',
    raso        => nv_ras_out_none,
    rasi        => nv_ras_in_none,
    bar         => (others => '0')
  );

  -- Data Cache Inputs --------------------------------------------------------
  type dcache_in_type is record
    signed      : std_ulogic;  -- Used in IUNV to sign extend read data
    enaddr      : std_ulogic;
    read        : std_ulogic;
    write       : std_ulogic;
    lock        : std_ulogic;
    dsuen       : std_ulogic;
    size        : word2;
    asi         : word8;
    amo         : std_logic_vector(5 downto 0);
    cbo         : word3;
    vms         : word3;       -- 1xx - V, x00 - U, x01 - S, x11 - M (also x1x - rs2=x0, xx1 - rs1=x0)
    sum         : std_ulogic;
    mxr         : std_ulogic;
    vmxr        : std_ulogic;
    hx          : std_ulogic;
    ss          : std_ulogic;
  end record;
  constant dcache_in_none : dcache_in_type := (
    signed => '0',
    enaddr => '0',
    read   => '0',
    write  => '0',
    lock   => '0',
    dsuen  => '0',
    size   => (others => '0'),
    asi    => (others => '0'),
    amo    => (others => '0'),
    cbo    => (others => '0'),
    vms    => (others => '0'),
    sum    => '0',
    mxr    => '0',
    vmxr   => '0',
    hx     => '0',
    ss     => '0'
    );

  -- Load types
  constant SZBYTE : word2 := "00";
  constant SZHALF : word2 := "01";
  constant SZWORD : word2 := "10";
  constant SZDBL  : word2 := "11";


  subtype tselect_int is integer range 0 to TRIGGER_NUM - 1;

  function tselect(r : csr_tcsr_type) return tselect_int is
    variable idx : integer := u2i(r.tselect);
  begin
    assert idx >= 0 and idx <= tselect_int'high;

    return idx;
  end;

  type trig_typ_vector_type  is array (0 to trig_index(TRIGGER_NUM)) of std_logic_vector(11 downto 0);
  constant dummy_csr : csr_reg_type := CSRRES;
  subtype trig_info_vector_type is word16_arr(0 to 2 ** dummy_csr.tcsr.tselect'length - 1);
  function set_trig_typ_vector(mc : integer;
                               ic : integer;
                               ie : integer) return trig_typ_vector_type is
    -- Non-constant
    variable typ : trig_typ_vector_type := (others => (others => '0'));
  begin
    if TRIGGER_NUM /= 0 then
      for i in 0 to (mc + ic + ie) - 1 loop
        if i < mc then
          typ(i) := x"27e";
        elsif (ic /= 0) and i < (mc + ic) then
          typ(i) := x"300";
        elsif (ie /= 0) and i = (mc + ic) then
          typ(i) := x"400";
        else
          typ(i) := x"500";
        end if;
      end loop;
    end if;

    return typ;
  end;
  constant trig_typ_vector : trig_typ_vector_type := set_trig_typ_vector(
                                                       TRIGGER_MC_NUM,
                                                       TRIGGER_IC_NUM,
                                                       TRIGGER_IE_NUM);
  function set_trig_info_vector(mc : integer;
                                ic : integer;
                                ie : integer) return trig_info_vector_type is
    -- Non-constant
    variable info : trig_info_vector_type := (others => (others => '0'));
  begin
    if TRIGGER_NUM /= 0 then
      for i in 0 to (mc + ic + ie) - 1 loop
        if i < mc then
          if MCONTROL_COMPATIBILITY = 1 then
            info(i) := x"0040" or x"0004";
          else
            info(i) := x"0040";
          end if;
        elsif (ic /= 0) and i < (mc + ic) then
          info(i) := x"0008";
        elsif (ie /= 0) and i = (mc + ic) then
          info(i) := x"0030";
        else
          info(i) := x"0030";
        end if;
      end loop;
    end if;

    return info;
  end;
  constant trig_info_vector : trig_info_vector_type := set_trig_info_vector(
                                                         TRIGGER_MC_NUM,
                                                         TRIGGER_IC_NUM,
                                                         TRIGGER_IE_NUM);


  function trigger_action(tdata : wordx) return wordx is
    variable typ    : word4 := tdata(tdata'high downto tdata'high - 3);
    -- Non-constant
    variable action : wordx;
  begin
    action  := (others => '0');
    case typ is
      when "0000" | "0001" | "1111"  =>
      when "0010" | "0110" =>  -- MCONTROL / MCONTROL6
        action(u2i(tdata(15 downto 12))) := '1';
      when others =>           -- ICOUNT / ITRIGGER / ETRIGGER
        action(u2i(tdata(5 downto 0)))   := '1';
    end case;

    return action;
  end;



  -- Pipeline trigger type
  type trig_type is record
    valid    : lanes_type;
    nullify  : lanes_type;
    pending  : std_logic;
    action   : word2;
    priority : word2;
    lanepri  : std_logic;
    hit      : trighit_type;
    mc6tval  : wordx;
    lowhit   : mc6hit_type;
  end record;
  constant trig_none : trig_type := ((others => '0'), (others => '0'), '0', (others => '0'),
                                     (others => '0'), '0', (others => '0'), (others => '0'), (others => '0'));

  -- IE triggers are handled differently
  -- They are checked in the exception stage and flush is done in the exception unit
  type ie_trig_type is record
    pend_hit : std_logic_vector(trig_index(TRIGGER_IE_NUM) downto 0);
    hit      : std_logic_vector(trig_index(TRIGGER_IE_NUM) downto 0);
    action   : word2;
    pending  : std_ulogic;
  end record;
  constant ie_trig_none : ie_trig_type := (
    pend_hit => (others => '0'),
    hit      => (others => '0'),
    action   => "00",
    pending  => '0'
  );


  -------------------------------------------------------------------------------

  -- Execute Stage <-> Memory Stage -------------------------------------------
  type memory_reg_type is record
    ctrl        : pipeline_ctrl_lanes_type;     -- Pipeline control record
    csr         : csr_type;                     -- CSR information
    rfa1        : rfa_lanes_type;               -- Register file record for op1
    rfa2        : rfa_lanes_type;               -- Register file record for op2
    result      : wordx_lanes_type;             -- ALUs result
    fpuflags    : word5;                        -- FPU flags
    dci         : dcache_in_type;               -- Data cache input record
    stdata      : wordx;                        -- Data to store for ST instructions
    stforw      : lanes_type;                   -- Store unit forwarded flags
    fpdata      : word64;                       -- Float data to store
    swap        : std_ulogic;                   -- Instrutions are swapped
    address     : addr_type;                    -- Address pre-computation for DCache
    address_full: wordx;                        -- Address pre-computation for DCache
    lbranch     : std_ulogic;                   -- Late branch flag
    alu         : alu_pair_type;                -- Late ALUs record
    spec_ld     : std_ulogic;                   -- Speculative load operation flag
    lpad        : std_ulogic;                   -- CFI landing pad (not necessarily LPAD instruction)
    lpad_fail   : std_ulogic;                   -- CFI landing pad failed to match
    rasi        : nv_ras_in_type;               -- Speculative RAS record
    trig        : trig_type;                    -- Trigger on instruction
    wpnull      : std_ulogic;                   -- Prevents mcontrol6 watchpoint from matching
    is_wfi      : std_ulogic;                   -- Instruction is WFI and it is valid
  end record;
  constant memory_reg_rst : memory_reg_type := (
    ctrl         => (others => pipeline_ctrl_none),
    csr          => csr_none,
    rfa1         => (others => (others => '0')),
    rfa2         => (others => (others => '0')),
    result       => (others => zerox),
    fpuflags     => (others => '0'),
    dci          => dcache_in_none,
    stdata       => zerox,
    stforw       => (others => '0'),
    fpdata       => zerow64,
    swap         => '0',
    address      => (others => '0'),
    address_full => (others => '0'),
    lbranch      => '0',
    alu          => (others => alu_none),
    spec_ld      => '0',
    lpad         => '0',
    lpad_fail    => '0',
    rasi         => nv_ras_in_none,
    trig         => trig_none,
    wpnull       => '0',
    is_wfi       => '0'
  );

  -- Memory Stage <-> Exception Stage -----------------------------------------
  type exception_reg_type is record
    ctrl           : pipeline_ctrl_lanes_type;     -- Pipeline control record
    csr            : csr_type;                     -- CSR information
    rfa1           : rfa_lanes_type;               -- Register file record for op1
    rfa2           : rfa_lanes_type;               -- Register file record for op2
    result         : wordx_lanes_type;             -- ALUs result
    fpuflags       : word5;                        -- FPU flags
    address        : addr_type;                    -- Computed address for Data cache
    address_full   : wordx;                        -- Computed address for Data cache
    dci            : dcache_in_type;               -- Data Cache record
    rdata          : word64;                      -- Data from Load unit
    wdata          : word64;                      -- Data to Store unit
    way            : std_logic_vector(DWAYMSB downto 0);
    mexc           : std_ulogic;                   -- Exception flag from Data cache
    exctype        : std_ulogic;                   -- Exception type from Data cache
    exchyper       : std_ulogic;                   -- Hypervisor exception from cache
    tval2          : wordx;                        -- Hypervisor exception info from cache
    tval2type      : word2;                        -- Hypervisor exception info from cache
    wcsr           : wordx;                        -- Load/store address for trace
    csrw           : lanes_type;                   -- CSR write enable
    csrpipeflush   : std_ulogic;                   -- CSR address requires pipeflush
    csraddrflush   : std_ulogic;                   -- CSR address requires addrflush
    ret            : word2;                        -- Privileged level to return
    nret           : std_ulogic;                   -- Return from an RNMI
    swap           : std_ulogic;                   -- Instrutions are swapped
    alupreforw1    : mux_lanes_type;               -- ALUs preforward information
    alupreforw2    : mux_lanes_type;               -- ALUs preforward information
    lbranch        : std_ulogic;                   -- Late branch flag
    alu            : alu_pair_type;                -- Late ALUs record
    spec_ld        : std_ulogic;                   -- Speculative load operation flag
    popchkpreforw  : word2;                        -- CFI SSPOPCHK preforward information
    lpad           : std_ulogic;                   -- CFI landing pad (not necessarily LPAD instruction)
    lpad_fail      : std_ulogic;                   -- CFI landing pad failed to match
    rstate         : core_state;                   -- Core state
    rasi           : nv_ras_in_type;               -- Speculative RAS record
    trig           : trig_type;                    -- Trigger on instruction
    ie_trig        : ie_trig_type;                 -- Interrupt/Exception trigger
    trigxc         : trig_exception_type;          -- Registered exception values from triggers
    crit_err       : std_ulogic;                   -- This bit is set when entering in critical error state
    int            : lanes_type;                   -- Interrupt on instruction
    irqcause       : cause_type;                   -- Interrupt cause
    aia_vti        : std_ulogic;                   -- Virtual interrupt generated through hvictl when vti=1
    nmirqpend       : std_ulogic;                   -- RNMI interrupt pending
    fpu_imm        : word64;                       -- Immediate FPU value
    data_valid_fpu : std_ulogic;                   -- Data to FPU valid
    fsd_hi         : word;                         -- High half of fsd data
    wfimode        : std_ulogic;                   -- Execution is halt until an interrupt is recieved
    wfi_irqpend    : std_ulogic;                   -- Signals a pending interrupt when WFI is executed
    pwrdmode       : std_ulogic;                   -- Core is in power down mode until an interrupt is recieved
    is_wfi         : std_ulogic;                   -- Valid WFI instruction comming from memory stage
    wfi_pc         : pctype;                       -- PC pointing to the instruction after WFI
  end record;
  constant exception_reg_rst : exception_reg_type := (
    ctrl           => (others => pipeline_ctrl_none),
    csr            => csr_none,
    rfa1           => (others => (others => '0')),
    rfa2           => (others => (others => '0')),
    result         => (others => zerox),
    fpuflags       => (others => '0'),
    address        => (others => '0'),
    address_full   => (others => '0'),
    dci            => dcache_in_none,
    rdata          => zerow64,
    wdata          => zerow64,
    way            => (others => '0'),
    mexc           => '0',
    exctype        => '0',
    exchyper       => '0',
    tval2          => zerox,
    tval2type      => "00",
    wcsr           => zerox,
    csrw           => (others => '0'),
    csrpipeflush   => '0',
    csraddrflush   => '0',
    ret            => (others => '0'),
    nret           => '0',
    swap           => '0',
    alupreforw1    => (others => (others => '0')),
    alupreforw2    => (others => (others => '0')),
    lbranch        => '0',
    alu            => (others => alu_none),
    spec_ld        => '0',
    popchkpreforw  => (others => '0'),
    lpad           => '0',
    lpad_fail      => '0',
    rstate         => run,
    rasi           => nv_ras_in_none,
    trig           => trig_none,
    ie_trig        => ie_trig_none,
    trigxc         => trig_exception_none,
    crit_err       => '0',
    int            => (others => '0'),
    irqcause       => cause_res,
    aia_vti        => '0',
    nmirqpend      => '0',
    fpu_imm        => (others => '0'),
    data_valid_fpu => '0',
    fsd_hi         => (others => '0'),
    wfimode        => '0',
    wfi_irqpend    => '0',
    pwrdmode       => '0',
    is_wfi         => '0',
    wfi_pc         => (others => '0')
  );

  -- Exception Stage <-> Write Back Stage -------------------------------------
  type writeback_reg_type is record
    ctrl          : pipeline_ctrl_lanes_type;       -- Pipeline control record
    csr           : csr_type;                       -- CSR information
    wdata         : wordx_lanes_type;               -- Write-back data to register file
    wcsr          : wordx_lanes_type;               -- Write-back data to CSR etc for trace
    fpuflags      : word5;                          -- FPU flags
    lalu          : lanes_type;                     -- Late ALUs flag
    flushall      : std_ulogic;                     -- Flushall instructions flag
    csr_pipeflush : std_ulogic;                     -- Pipeline flush due to CSR instructions flag
    csr_addrflush : std_ulogic;                     -- Address flush due to CSR instructions flag
    fence_flush   : std_ulogic;                     -- Flush due to fence instructions flag
    swap          : std_ulogic;                     -- Instrutions are swapped
    rstate        : core_state;                     -- Core state (for logging)
    xc_taken      : std_ulogic;                     -- Exception Taken Flag (for logging)
    xc_taken_cause: cause_type;                     -- Exception Cause (for logging)
    xc_taken_tval : wordx;                          -- Exception Value (for logging)
    nextpc0       : pctype;                         -- Stored following pc for fence
    rasi          : nv_ras_in_type;                 -- Speculative RAS record
    prv           : priv_lvl_type;                  -- Only used for instruction trace printout
    v             : std_ulogic;                     -- Only used for instruction trace printout
    bht_bhistory  : word5;                          -- BHT bhistory input
    bht_phistory  : word64;                         -- BHT phistory input
    ret           : std_logic;                      -- xRet instruction
    trap_taken    : lanes_type;                     -- Used for debug printing
    trace_trig    : lanes_type;                     -- Prevents the intructions that fires a trigger from being invalidated in the trace
    icnt          : word2;                          -- instruction count event
    unalg_pc      : pctype;                         -- Unaligned PC to write for BTB/BHT
    upd_counter   : hpm_events_vector_type;         -- Updated HPM Counter flag
    commit_fpu    : std_ulogic;                     -- FPU instruction commit
    fsd_hi        : word;                           -- High half of fsd data
  end record;
  constant writeback_reg_rst : writeback_reg_type := (
    ctrl           => (others => pipeline_ctrl_none),
    csr            => csr_none,
    wdata          => (others => zerox),
    wcsr           => (others => zerox),
    fpuflags       => (others => '0'),
    lalu           => (others => '0'),
    flushall       => '0',
    csr_pipeflush  => '0',
    csr_addrflush  => '0',
    fence_flush    => '0',
    swap           => '0',
    rstate         => run,
    xc_taken       => '0',
    xc_taken_cause => cause_res,
    xc_taken_tval  => zerox,
    nextpc0        => PC_ZERO,
    rasi           => nv_ras_in_none,
    prv            => (others => '0'),
    v              => '0',
    bht_bhistory   => (others => '0'),
    bht_phistory   => (others => '0'),
    ret            => '0',
    trap_taken     => (others => '0'),
    trace_trig     => (others => '0'),
    icnt           => (others => '0'),
    unalg_pc       => PC_ZERO,
    upd_counter    => (others => (others => '0')),
    commit_fpu     => '0',
    fsd_hi         => (others => '0')
  );

  -- Exception Stage <-> Write Back Stage -------------------------------------
  type postwriteback_reg_type is record
    ctrl          : pipeline_ctrl_lanes_type;       -- Pipeline control record
    csr           : csr_type;                       -- CSR information
  end record;
  constant postwriteback_reg_rst : postwriteback_reg_type := (
    ctrl           => (others => pipeline_ctrl_none),
    csr            => csr_none
  );

  -- Debug-Module reegister ---------------------------------------------------
  type debugmodule_reg_type is record
    cmdexec     : word2;                                     -- Command on going
    write       : std_ulogic;                                -- Command write
    size        : word3;                                     -- Command size
    cmd         : word2;                                     -- Command
    addr        : word16;                                    -- Command addr
    havereset   : word4;                                     -- Have been reset
    tbufaddr    : std_logic_vector(TBUFBITS - 1 downto 0);   -- Trace buffer readout address
    csr_xc      : std_ulogic;                                -- Reading a CSR rose an exception
  end record;
  constant debugmodule_reg_rst : debugmodule_reg_type := (
    cmdexec   => (others => '0'),
    write     => '0',
    size      => (others => '0'),
    cmd       => (others => '0'),
    addr      => (others => '0'),
    havereset => (others => '1'),
    tbufaddr  => (others => '0'),
    csr_xc    => '0'
  );


  -- All Stages ---------------------------------------------------------------
  type registers is record
    f       : fetch_reg_type;
    d       : decode_reg_type;
    a       : regacc_reg_type;
    e       : execute_reg_type;
    m       : memory_reg_type;
    x       : exception_reg_type;
    wb      : writeback_reg_type;
    pwb0    : postwriteback_reg_type;
    pwb1    : postwriteback_reg_type;
    csr     : csr_reg_type;
    mmu     : nv_csr_out_type;  -- Pipelined on the way to MMU/cache controller
    dm      : debugmodule_reg_type;
    evt     : evt_type;
    cevt    : std_logic_vector(0 to perf_cnts + 3 - 1);  -- 0-2 not used
    evtirq  : std_logic_vector(0 to perf_cnts + 3 - 1);  -- 0-2 not used
    fpo     : fpu5_out_type;    -- FPU output, for logging
    fpflush : word5;
    dbgi_dsuen : std_ulogic;    -- Delayed dbgi.dsuen
  end record;
  constant registers_rst : registers := (
    f          => fetch_reg_rst,
    d          => decode_reg_rst,
    a          => regacc_reg_rst,
    e          => execute_reg_rst,
    m          => memory_reg_rst,
    x          => exception_reg_rst,
    wb         => writeback_reg_rst,
    pwb0       => postwriteback_reg_rst,
    pwb1       => postwriteback_reg_rst,
    csr        => CSRRES,
    mmu        => nv_csr_out_type_none,
    dm         => debugmodule_reg_rst,
    evt        => evt_none_type,
    cevt       => (others => '0'),
    evtirq     => (others => '0'),
    fpo        => fpu5_out_none,
    fpflush    => (others => '0'),
    dbgi_dsuen => '0'
  );

  ----------------------------------------------------------------------------
  -- Reset Functions and Constants
  ----------------------------------------------------------------------------

  function registers_rst_modified return registers is
    -- Non-constant
    variable v : registers := registers_rst;
  begin
    -- Special setup for triggers
    for i in trig_typ_vector'range loop
      v.csr.tcsr.tdata1(i)(XLEN - 1 downto XLEN - 12) := trig_typ_vector(i);
      v.csr.tcsr.tinfo(i)                             := trig_info_vector(i);
    end loop;
    if TRIGGER_IC_NUM /= 0 then
      for i in TRIGGER_MC_NUM to TRIGGER_MC_NUM + TRIGGER_IC_NUM - 1 loop
        v.csr.tcsr.tdata1(i)(10)                      := '1';  -- icount
      end loop;
    end if;

    return v;
  end;


  constant RRES : registers := registers_rst_modified;

  function pma_arr_create(data_arr : word64_arr) return word64_arr is
    variable pma_normal : word64_arr(0 to data_arr'length - 1) := data_arr;
    variable entries    : integer := minimum(pma_entries, data_arr'length);
    -- Non-constant
    variable arr : word64_arr(0 to PMAENTRIES - 1) := (others => zerow64);
  begin
    for i in 0 to entries - 1 loop
      arr(i) := pma_normal(i);
    end loop;

    return arr;
  end;

  function pma_data_arr_create(data_arr : word64_arr) return word64_arr is
    -- Non-constant
    variable arr : word64_arr(data_arr'range);
  begin
    for i in data_arr'range loop
      arr(i) := pma_sanitize(data_arr(i), is_rv64);
    end loop;

    return pma_arr_create(arr);
  end;


  ----------------------------------------------------------------------------
  -- Signal Declarations
  ----------------------------------------------------------------------------

  signal r, rin         : registers;
  signal arst           : std_ulogic;

  -- Hart index
  signal hart           : word4;




  ----------------------------------------------------------------------------
  -- Function & Procedures Declarations
  ----------------------------------------------------------------------------


  -- Fetch control record from specific stage.
  function ctrl(r : registers; stage : stage_type) return pipeline_ctrl_lanes_type is
  begin
    case stage is
    when a  => return r.a.ctrl;
    when e  => return r.e.ctrl;
    when m  => return r.m.ctrl;
    when x  => return r.x.ctrl;
    when wb => return r.wb.ctrl;
    when pwb0 => return r.pwb0.ctrl;
    when pwb1 => return r.pwb1.ctrl;
    end case;
  end;

  -- Fetch csr record from specific stage.
  function csr(r : registers; stage : stage_type) return csr_type is
  begin
    case stage is
    when a  => return r.a.csr;
    when e  => return r.e.csr;
    when m  => return r.m.csr;
    when x  => return r.x.csr;
    when wb => return r.wb.csr;
    when pwb0 => return r.pwb0.csr;
    when pwb1 => return r.pwb1.csr;
    end case;
  end;

  -- Fetch op1 record from specific stage.
  -- Note that this returns 0 for instructions without rs1.
  function rs1(r : registers; stage : stage_type) return rfa_lanes_type is
  begin
    case stage is
    when a      => return r.a.rfa1;
    when e      => return r.e.rfa1;
    when m      => return r.m.rfa1;
    when x      => return r.x.rfa1;
    when others => assert false report "Bad stage" severity failure;
    end case;

    -- Will never get here!
    return (others => (others => '0'));
  end;

  -- Fetch op2 record from specific stage.
  -- Note that this returns 0 for instructions without rs2.
  function rs2(r : registers; stage : stage_type) return rfa_lanes_type is
  begin
    case stage is
    when a      => return r.a.rfa2;
    when e      => return r.e.rfa2;
    when m      => return r.m.rfa2;
    when x      => return r.x.rfa2;
    when others => assert false report "Bad stage" severity failure;
    end case;

    -- Will never get here!
    return (others => (others => '0'));
  end;

  function ctrl(r : registers; stage : stage_type; lane : lanes_range) return pipeline_ctrl_type is
  begin
    return ctrl(r, stage)(lane);
  end;

  -- Fetch rd from specified stage and lane.
  -- Note that this returns the rd position bits, whether rd exists or not.
  -- Normally should be used together with .rdv check.
  function rd(r : registers; stage : stage_type; lane : lanes_range) return reg_t is
    -- Non-constant
    variable inst : word32;
  begin
    if    stage = a then
      inst := r.a.ctrl(lane).inst;
    elsif stage = e then
      inst := r.e.ctrl(lane).inst;
    elsif stage = m then
      inst := r.m.ctrl(lane).inst;
    elsif stage = x then
      inst := r.x.ctrl(lane).inst;
    else
      inst := r.wb.ctrl(lane).inst;
    end if;

    return rd(inst);
  end;


  -- Fetch functional unit from specific stage and lane, then check if
  -- equivalent to fusel.
  function v_fusel_eq(r     : registers; stage : stage_type; lane : lanes_range;
                      fusel : fuseltype) return boolean is
    -- Non-constant
    variable c_valid : std_logic;
    variable c_fusel : fuseltype;
    variable ret     : boolean;
  begin
    ret := false;
    if    stage = a then
      c_valid := r.a.ctrl(lane).valid;
      c_fusel := r.a.ctrl(lane).fusel;
    elsif stage = e then
      c_valid := r.e.ctrl(lane).valid;
      c_fusel := r.e.ctrl(lane).fusel;
    elsif stage = m then
      c_valid := r.m.ctrl(lane).valid;
      c_fusel := r.m.ctrl(lane).fusel;
    elsif stage = x then
      c_valid := r.x.ctrl(lane).valid;
      c_fusel := r.x.ctrl(lane).fusel;
    else
      c_valid := r.wb.ctrl(lane).valid;
      c_fusel := r.wb.ctrl(lane).fusel;
    end if;

    if c_valid = '1' then
      if (c_fusel and fusel) /= NONE then
        ret := true;
      end if;
    end if;

    return ret;
  end;


  function v_rd_eq_only(r   : registers; stage : stage_type; lane : lanes_range;
                        rfa : rfa_tuple) return boolean is
    variable c       : pipeline_ctrl_type := ctrl(r, rfa.stage, rfa.lane);
    variable vs      : rd_vs_rs_type      := c.rd_vs_rs;
    variable display : boolean            := false; -- rfa.stage = e;
    -- Non-constant
    variable old_eq  : boolean;
    variable new_eq  : boolean;
    variable rsn     : rs_type            := 1;
    variable rsp     : rfa_lanes_type     := rs1(r, rfa.stage);
    variable rdn     : rd_src_type        := vs.rfa1;
  begin
    if rfa.rs = 2 then
      rsp       := rs2(r, rfa.stage);
      rdn       := vs.rfa2;
      rsn       := 2;
    end if;

    old_eq      := rd(r, stage, lane) = rsp(rfa.lane);
    new_eq      := rdn(stage_type'pos(stage))(lane) = '1';

    if OLD_RD_VS_RS then
      return old_eq;
    end if;

    assert old_eq = new_eq report "Forwarding difference" severity failure;


    return new_eq;
  end;


  -- Is rd valid and the same as given rs?
  function v_rd_eq(r  : registers; stage : stage_type; lane : lanes_range;
                   rs : reg_t) return boolean is
    -- Non-constant
    variable c_valid : std_logic;
    variable c_rdv   : std_logic;
    variable c_rd    : reg_t;
  begin
    if    stage = a then
      c_valid := r.a.ctrl(lane).valid;
      c_rdv   := r.a.ctrl(lane).rdv;
      c_rd    := rd(r.a.ctrl(lane).inst);
    elsif stage = e then
      c_valid := r.e.ctrl(lane).valid;
      c_rdv   := r.e.ctrl(lane).rdv;
      c_rd    := rd(r.e.ctrl(lane).inst);
    elsif stage = m then
      c_valid := r.m.ctrl(lane).valid;
      c_rdv   := r.m.ctrl(lane).rdv;
      c_rd    := rd(r.m.ctrl(lane).inst);
    elsif stage = x then
      c_valid := r.x.ctrl(lane).valid;
      c_rdv   := r.x.ctrl(lane).rdv;
      c_rd    := rd(r.x.ctrl(lane).inst);
    else
      c_valid := r.wb.ctrl(lane).valid;
      c_rdv   := r.wb.ctrl(lane).rdv;
      c_rd    := rd(r.wb.ctrl(lane).inst);
    end if;

    return c_valid = '1' and c_rdv = '1' and c_rd = rs;
  end;



  function v_rd_eq(r   : registers; stage : stage_type; lane : lanes_range;
                   rfa : rfa_tuple) return boolean is
    -- Non-constant
    variable c_valid : std_logic;
    variable c_rdv   : std_logic;
    variable c_vs    : rd_vs_rs_type;
    variable rdn     : rd_src_type;
    variable rdn_e   : std_logic;
  begin
    if    rfa.stage = a then
      c_vs := r.a.ctrl(rfa.lane).rd_vs_rs;
    elsif rfa.stage = e then
      c_vs := r.e.ctrl(rfa.lane).rd_vs_rs;
    elsif rfa.stage = m then
      c_vs := r.m.ctrl(rfa.lane).rd_vs_rs;
    elsif rfa.stage = x then
      c_vs := r.x.ctrl(rfa.lane).rd_vs_rs;
    else
      c_vs := r.wb.ctrl(rfa.lane).rd_vs_rs;
    end if;
    rdn    := c_vs.rfa1;
    if rfa.rs = 2 then
      rdn  := c_vs.rfa2;
    end if;

    if    stage = a then
      c_valid := r.a.ctrl(lane).valid;
      c_rdv   := r.a.ctrl(lane).rdv;
      rdn_e   := rdn(0)(lane);
    elsif stage = e then
      c_valid := r.e.ctrl(lane).valid;
      c_rdv   := r.e.ctrl(lane).rdv;
      rdn_e   := rdn(1)(lane);
    elsif stage = m then
      c_valid := r.m.ctrl(lane).valid;
      c_rdv   := r.m.ctrl(lane).rdv;
      rdn_e   := rdn(2)(lane);
    elsif stage = x then
      c_valid := r.x.ctrl(lane).valid;
      c_rdv   := r.x.ctrl(lane).rdv;
      rdn_e   := rdn(3)(lane);
    else
      c_valid := r.wb.ctrl(lane).valid;
      c_rdv   := r.wb.ctrl(lane).rdv;
      rdn_e   := rdn(4)(lane);
    end if;

    return c_valid = '1' and c_rdv = '1' and rdn_e = '1';
  end;

  function tost_rfa(r : registers; rfa : rfa_tuple) return string is
    -- Non-constant
    variable rsp : rfa_lanes_type := rs1(r, rfa.stage);
  begin
    if rfa.rs = 2 then
      rsp := rs2(r, rfa.stage);
    end if;

    return to_reg(rsp(rfa.lane));
  end;

  function tost_rd(r : registers; stage : stage_type; lane : lanes_range) return string is
  begin
    return to_reg(rd(r, stage, lane));
  end;


  -- Is rd valid and the same as given rs?
  -- (Using special rdv value.)
  function v_rd_eq_xrdv(r   : registers; stage : stage_type; lane : lanes_range;
                        rdv : std_logic; rs    : reg_t) return boolean is
    -- Non-constant
    variable c_valid : std_logic;
    variable c_rd    : reg_t;
  begin
    if    stage = a then
      c_valid := r.a.ctrl(lane).valid;
      c_rd    := rd(r.a.ctrl(lane).inst);
    elsif stage = e then
      c_valid := r.e.ctrl(lane).valid;
      c_rd    := rd(r.e.ctrl(lane).inst);
    elsif stage = m then
      c_valid := r.m.ctrl(lane).valid;
      c_rd    := rd(r.m.ctrl(lane).inst);
    elsif stage = x then
      c_valid := r.x.ctrl(lane).valid;
      c_rd    := rd(r.x.ctrl(lane).inst);
    else
      c_valid := r.wb.ctrl(lane).valid;
      c_rd    := rd(r.wb.ctrl(lane).inst);
    end if;

    return c_valid = '1' and rdv = '1' and c_rd = rs;
  end;


  function v_rd_eq_xrdv(r   : registers; stage : stage_type; lane : lanes_range;
                        rdv : std_logic; rfa   : rfa_tuple) return boolean is
    -- Non-constant
    variable c_valid : std_logic;
    variable c_vs    : rd_vs_rs_type;
    variable rdn     : rd_src_type;
    variable rdn_e   : std_logic;
  begin
    if    rfa.stage = a then
      c_vs := r.a.ctrl(rfa.lane).rd_vs_rs;
    elsif rfa.stage = e then
      c_vs := r.e.ctrl(rfa.lane).rd_vs_rs;
    elsif rfa.stage = m then
      c_vs := r.m.ctrl(rfa.lane).rd_vs_rs;
    elsif rfa.stage = x then
      c_vs := r.x.ctrl(rfa.lane).rd_vs_rs;
    else
      c_vs := r.wb.ctrl(rfa.lane).rd_vs_rs;
    end if;
    rdn    := c_vs.rfa1;
    if rfa.rs = 2 then
      rdn  := c_vs.rfa2;
    end if;

    if    stage = a then
      c_valid := r.a.ctrl(lane).valid;
      rdn_e   := rdn(0)(lane);
    elsif stage = e then
      c_valid := r.e.ctrl(lane).valid;
      rdn_e   := rdn(1)(lane);
    elsif stage = m then
      c_valid := r.m.ctrl(lane).valid;
      rdn_e   := rdn(2)(lane);
    elsif stage = x then
      c_valid := r.x.ctrl(lane).valid;
      rdn_e   := rdn(3)(lane);
    else
      c_valid := r.wb.ctrl(lane).valid;
      rdn_e   := rdn(4)(lane);
    end if;

    return c_valid = '1' and rdv = '1' and rdn_e = '1';
  end;


  -- Is rd valid and the same as given rs?
  -- (Using special valid value.)
  function v_rd_eq_xvalid(r     : registers; stage : stage_type; lane : lanes_range;
                          valid : std_logic; rs    : reg_t) return boolean is
    -- Non-constant
    variable c_rdv : std_logic;
    variable c_rd  : reg_t;
  begin
    if    stage = a then
      c_rdv := r.a.ctrl(lane).rdv;
      c_rd  := rd(r.a.ctrl(lane).inst);
    elsif stage = e then
      c_rdv := r.e.ctrl(lane).rdv;
      c_rd  := rd(r.e.ctrl(lane).inst);
    elsif stage = m then
      c_rdv := r.m.ctrl(lane).rdv;
      c_rd  := rd(r.m.ctrl(lane).inst);
    elsif stage = x then
      c_rdv := r.x.ctrl(lane).rdv;
      c_rd  := rd(r.x.ctrl(lane).inst);
    else
      c_rdv := r.wb.ctrl(lane).rdv;
      c_rd  := rd(r.wb.ctrl(lane).inst);
    end if;

    return valid = '1' and c_rdv = '1' and c_rd = rs;
  end;



  function v_rd_eq_xvalid(r     : registers; stage : stage_type; lane : lanes_range;
                          valid : std_logic; rfa   : rfa_tuple) return boolean is
    -- Non-constant
    variable c_rdv : std_logic;
    variable c_vs  : rd_vs_rs_type;
    variable rdn   : rd_src_type;
    variable rdn_e : std_logic;
  begin
    if    rfa.stage = a then
      c_vs := r.a.ctrl(rfa.lane).rd_vs_rs;
    elsif rfa.stage = e then
      c_vs := r.e.ctrl(rfa.lane).rd_vs_rs;
    elsif rfa.stage = m then
      c_vs := r.m.ctrl(rfa.lane).rd_vs_rs;
    elsif rfa.stage = x then
      c_vs := r.x.ctrl(rfa.lane).rd_vs_rs;
    else
      c_vs := r.wb.ctrl(rfa.lane).rd_vs_rs;
    end if;
    rdn    := c_vs.rfa1;
    if rfa.rs = 2 then
      rdn  := c_vs.rfa2;
    end if;

    if    stage = a then
      c_rdv := r.a.ctrl(lane).rdv;
      rdn_e := rdn(0)(lane);
    elsif stage = e then
      c_rdv := r.e.ctrl(lane).rdv;
      rdn_e := rdn(1)(lane);
    elsif stage = m then
      c_rdv := r.m.ctrl(lane).rdv;
      rdn_e := rdn(2)(lane);
    elsif stage = x then
      c_rdv := r.x.ctrl(lane).rdv;
      rdn_e := rdn(3)(lane);
    else
      c_rdv := r.wb.ctrl(lane).rdv;
      rdn_e := rdn(4)(lane);
    end if;

    return valid = '1' and c_rdv = '1' and rdn_e = '1';
  end;

  function csr_addr(r : registers; stage : stage_type) return csratype is
    variable csr : csr_type := csr(r, stage);
  begin
    return csr.addr;
  end;

  function csr_access_addr(r : registers; stage : stage_type) return csratype is
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return csr_access_addr(c.inst);
  end;

  function is_csr_access(r : registers; stage : stage_type) return boolean is
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return is_csr_access(c.inst);
  end;

  function csr_eq(r : registers; stage1 : stage_type; stage2 : stage_type) return boolean is
  begin
    return csr_addr(r, stage1) = csr_addr(r, stage2);
  end;

  function csr_raw_category_eq(r : registers; stage1 : stage_type; stage2 : stage_type) return boolean is
    variable csr1 : csr_type := csr(r, stage1);
    variable csr2 : csr_type := csr(r, stage2);
    variable cat1 : raw_category_t := csr1.raw_cat;
    variable cat2 : raw_category_t := csr2.raw_cat;
  begin
    return (cat1 and cat2) /= (cat1'range => '0');
  end;

  function csr_waw_category_eq(r : registers; stage1 : stage_type; stage2 : stage_type) return boolean is
    variable csr1 : csr_type := csr(r, stage1);
    variable csr2 : csr_type := csr(r, stage2);
    variable cat1 : waw_category_t := csr1.waw_cat;
    variable cat2 : waw_category_t := csr2.waw_cat;
  begin
    return (cat1 and cat2) /= (cat1'range => '0');
  end;

  -- Is instruction a CSR access and actually valid?
  function csr_ok(r : registers; stage : stage_type) return boolean is
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return c.csrv = '1' and c.valid = '1';
  end;

  function to_asi(func : word4) return word8 is
    variable asi : word8;
  begin
    case func is
      when x"0" => asi := x"0C";  -- I$ tags (ITAG)
      when x"1" => asi := x"0D";  -- I$ data (IDATA)
      when x"2" => asi := x"0E";  -- D$ tags (DTAG)
      when x"3" => asi := x"0F";  -- D$ data (DDATA)
      when x"6" => asi := x"1E";  -- Snoop tags (MMUSNOOP_DIAG)
      when x"7" => asi := x"23";  -- TLB diagnostic access
      when x"9" => asi := x"25";  -- Cache LRU diagnostic interface
      when x"C" => asi := x"2E";  -- NOEL-V - PMP test and status bits
      when x"D" => asi := x"2F";  -- NOEL-V - extra data for RV32
      when others => asi := x"00";  -- I$ tags (no specific reason - will not happen)
    end case;

    return asi;
  end;

  function to_asi_load(inst : std_logic_vector) return word8 is
    variable func : word4 := inst(23 downto 20);
  begin
    return to_asi(func);
  end;

  function to_asi_store(inst : std_logic_vector) return word8 is
    variable func : word4 := inst(10 downto 7);
  begin
    return to_asi(func);
  end;


  -- Is instruction for the FPU and actually valid?
  function is_valid_fpu(r : registers; stage : stage_type) return boolean is
    -- Non-constant
    variable c_valid : std_logic;
    variable c_inst  : word;
  begin
    if    stage = a then
      c_valid := r.a.ctrl(fpu_lane).valid and not r.a.ctrl(fpu_lane).xc;
      c_inst  := r.a.ctrl(fpu_lane).inst;
    elsif stage = e then
      c_valid := r.e.ctrl(fpu_lane).valid and not r.e.ctrl(fpu_lane).xc;
      c_inst  := r.e.ctrl(fpu_lane).inst;
    elsif stage = m then
      c_valid := r.m.ctrl(fpu_lane).valid and not r.m.ctrl(fpu_lane).xc;
      c_inst  := r.m.ctrl(fpu_lane).inst;
    elsif stage = x then
      c_valid := r.x.ctrl(fpu_lane).valid and not r.x.ctrl(fpu_lane).xc;
      c_inst  := r.x.ctrl(fpu_lane).inst;
    else
      c_valid := r.wb.ctrl(fpu_lane).valid and not r.wb.ctrl(fpu_lane).xc;
      c_inst  := r.wb.ctrl(fpu_lane).inst;
    end if;

    return c_valid = '1' and (is_fpu(c_inst) or is_fpu_mem(c_inst));
  end;

  -- Assumes it is already known that inst is a CSR instruction.
  function csr_read_only(r : registers; stage : stage_type) return boolean is
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return csr_read_only(active_extensions, c.inst);
  end;

  function csr_access_read(r : registers; stage : stage_type) return boolean is
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return csr_access_read(c.inst);
  end;

  function csr_access_read_only(r : registers; stage : stage_type) return boolean is
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return csr_access_read_only(c.inst);
  end;

  -- Assumes it is already known that inst is a CSR instruction.
  function csr_write_only(r : registers; stage : stage_type) return boolean is
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return csr_write_only(active_extensions, c.inst);
  end;

  -- Assumes it is already known that inst is a CSR instruction.
  function csr_immediate(r : registers; stage : stage_type) return boolean is
    variable c      : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
    variable funct3 : funct3_type        := funct3(c.inst);
  begin
    -- Since CSR instruction is assumed, the following is equivalent to
    -- funct3 = I_CSRRWI or funct3 = I_CSRRSI or funct3 = I_CSRRCI
    return get_hi(funct3) = '1';
  end;


  function check_forwarding(r : registers; stage : stage_type; dst_lane : lanes_range) return rd_vs_rs_type is
    variable rfa1       : rfa_lanes_type := rs1(r, stage);
    variable rfa2       : rfa_lanes_type := rs2(r, stage);
    variable display    : boolean        := false; -- stage = e;
    -- Non-constant
    variable c          : pipeline_ctrl_type;
    variable forwarding : rd_vs_rs_type  := rd_vs_rs_none;
    variable forwarded1 : boolean        := false;
    variable forwarded2 : boolean        := false;
    variable a_valid    : std_logic      := '0';
    variable e_valid    : std_logic      := '0';
    variable m_valid    : std_logic      := '0';
    variable x_valid    : std_logic      := '0';
    variable wb_valid   : std_logic      := '1';
  begin

    if stage = a then
      a_valid := '1';
      e_valid := '1';
      m_valid := '1';
      x_valid := '1';
    end if;

    if stage = e then
      e_valid := '1';
      m_valid := '1';
      x_valid := '1';
    end if;

    if stage = m then
      m_valid := '1';
      x_valid := '1';
    end if;

    if stage = x then
      x_valid := '1';
    end if;

    for i in lanes'range loop
      if r.a.ctrl(i).valid = '1' and r.a.ctrl(i).rdv = '1' and a_valid = '1' then
        if rd(r.a.ctrl(i).inst) =  rfa1(dst_lane) then
          forwarding.rfa1(stage_type'pos(a))(i) := '1';
        end if;
        if rd(r.a.ctrl(i).inst) =  rfa2(dst_lane) then
          forwarding.rfa2(stage_type'pos(a))(i) := '1';
        end if;
      end if;

      if r.e.ctrl(i).valid = '1' and r.e.ctrl(i).rdv = '1' and e_valid = '1' then
        if rd(r.e.ctrl(i).inst) =  rfa1(dst_lane) then
          forwarding.rfa1(stage_type'pos(e))(i) := '1';
        end if;
        if rd(r.e.ctrl(i).inst) =  rfa2(dst_lane) then
          forwarding.rfa2(stage_type'pos(e))(i) := '1';
        end if;
      end if;

      if r.m.ctrl(i).valid = '1' and r.m.ctrl(i).rdv = '1' and m_valid = '1' then
        if rd(r.m.ctrl(i).inst) =  rfa1(dst_lane) then
          forwarding.rfa1(stage_type'pos(m))(i) := '1';
        end if;
        if rd(r.m.ctrl(i).inst) =  rfa2(dst_lane) then
          forwarding.rfa2(stage_type'pos(m))(i) := '1';
        end if;
      end if;

      if r.x.ctrl(i).valid = '1' and r.x.ctrl(i).rdv = '1' and x_valid = '1' then
        if rd(r.x.ctrl(i).inst) =  rfa1(dst_lane) then
          forwarding.rfa1(stage_type'pos(x))(i) := '1';
        end if;
        if rd(r.x.ctrl(i).inst) =  rfa2(dst_lane) then
          forwarding.rfa2(stage_type'pos(x))(i) := '1';
        end if;
      end if;

      if r.wb.ctrl(i).valid = '1' and r.wb.ctrl(i).rdv = '1' and wb_valid = '1' then
        if rd(r.wb.ctrl(i).inst) =  rfa1(dst_lane) then
          forwarding.rfa1(stage_type'pos(wb))(i) := '1';
        end if;
        if rd(r.wb.ctrl(i).inst) =  rfa2(dst_lane) then
          forwarding.rfa2(stage_type'pos(wb))(i) := '1';
        end if;
      end if;

    end loop;

    return forwarding;
  end;


  function rfa(rs : rs_type; stage: stage_type; lane : lanes_range) return rfa_tuple is
    variable tuple : rfa_tuple := (rs, stage, lane);
  begin
    return tuple;
  end;

  -- Hardwire hpmevent CSR bits
  function tie_hpmevent(hpmevent_in : hpmevent_type; misa : wordx) return hpmevent_type is
    variable h_en     : boolean       := misa(h_ctrl) = '1';
    -- Non-constant
    variable hpmevent : hpmevent_type := hpmevent_in;
  begin
    if ext_sscofpmf = 0 then
      hpmevent.minh := '0';
    end if;
    if ext_sscofpmf = 0 or mode_s = 0 then
      hpmevent.sinh := '0';
    end if;
    if ext_sscofpmf = 0 or mode_u = 0 then
      hpmevent.uinh := '0';
    end if;
    if ext_sscofpmf = 0 or not h_en then
      hpmevent.vsinh := '0';
      hpmevent.vuinh := '0';
    end if;


    return hpmevent;
  end;

  -- Hardwire mseccfg CSR bits
  function tie_mseccfg(seccfg_in : csr_seccfg_type) return csr_seccfg_type is
    -- Non-constant
    variable seccfg : csr_seccfg_type := seccfg_in;
  begin
    if ext_smepmp = 0 then
      seccfg.mml   := '0';
      seccfg.mmwp  := '0';
    end if;
    if ext_smepmp = 0
       then
      seccfg.rlb   := '0';
    end if;
    if ext_zicfilp = 0 then
      seccfg.mlpe  := '0';
    end if;

    return seccfg;
  end;

  -- Generate default next PC for fetch mux
  function npc(r_f_pc : pctype) return pctype is
    variable pc2downto1 : word2 := r_f_pc(2 downto 1);
    -- Non-constant
    variable npc        : pctype;
    variable op2        : integer;
  begin
    case pc2downto1 is
      when "10"   =>
        op2 := 4;
      when "11"   =>
        op2 := 2;
      when "01"   =>
        op2 := 6;
      when others =>
        op2 := 8;
    end case;

    if single_issue /= 0 then
      op2 := 4;
      if pc2downto1(0) = '1' then
        op2 := 2;
      end if;
    end if;

    npc := uadd(r_f_pc, op2);

    return to_addr(npc);
  end;

  -- Precheck of late ALU issues in order to reduce
  -- critical path on decode stage.
  -- Note that this is directly releated to some stuff in instruction_control()!
  procedure late_alu_precheck(r        : in  registers;
                              cfi_en   : in  cfi_t;
                              instx_in : in  iword_pair_type;
                              valid_in : in  fetch_pair;
                              lalu_exe : in  fetch_pair;
                              lalu_pre : out fetch_pair
                              ) is
    -- Non-constant
    variable inst_in  : word_lanes_type;
    variable rfa1     : rfa_lanes_type;
    variable rfa2     : rfa_lanes_type;
    variable fusel    : fusel_fetch_type;
    variable rd       : rfa_lanes_type;
    variable rd_valid : lanes_type;
  begin
    lalu_pre := (others => '0');

    for i in lanes'range loop
      inst_in(i)  := instx_in(i).d;
      fusel(i)    := fusel_gen(active_extensions, instx_in(i).d);
      rfa1(i)     := rs1_gen(active_extensions,
                             cfi_en,
                             inst_in(i));
      rfa2(i)     := rs2_gen(active_extensions,
                             cfi_en,
                             inst_in(i));
      rd_valid(i) := rd_gen(active_extensions,
                            cfi_en,
                            inst_in(i));
      rd(i)       := get_rd(inst_in(i));
    end loop;

    -- Late if dependency between paired instructions?
    if single_issue = 0 then
      if v_fusel_eq(fusel(0), ALU or LD or MUL or FPU
      ) and valid_in(0) = '1' then
        if rd_valid(0) = '1' then
          if rd(0) = rfa1(one) or rd(0) = rfa2(one) then
            lalu_pre(1) := '1';
          end if;
        end if;
      end if;
    end if;

    -- Late if dependency on LD in RA stage?
    if v_fusel_eq(r, a, 0, LD) then
      for i in lanes'range loop
        if v_fusel_eq(fusel(i), ALU) then
          if v_rd_eq(r, a, 0, rfa1(i)) or
             v_rd_eq(r, a, 0, rfa2(i)) then
            lalu_pre(i) := '1';
          end if;
        end if;
      end loop;
    end if;

    -- Late if dependency on MUL in RA stage?
    for i in lanes'range loop
      if v_fusel_eq(r, a, i, MUL) then
        for j in lanes'range loop
          if v_fusel_eq(fusel(j), ALU) then
            if v_rd_eq(r, a, i, rfa1(j)) or
               v_rd_eq(r, a, i, rfa2(j)) then
              lalu_pre(j) := '1';
            end if;
          end if;
        end loop;
      end if;
    end loop;


    -- Late if dependency on late instruction in RA and this is for ALU.
    for i in lanes'range loop
      if lalu_exe(i) = '1' and r.a.ctrl(i).valid = '1' then
        for j in lanes'range loop
          if v_fusel_eq(fusel(j), ALU) then
            if v_rd_eq(r, a, i, rfa1(j)) or
               v_rd_eq(r, a, i, rfa2(j)) then
              lalu_pre(j) := '1';
            end if;
          end if;
        end loop;
      end if;
    end loop;
  end;

  -- Generate instruction trace data
  function itrace_gen(timestamp : in  word64;
                      r_wb      : in  writeback_reg_type) return trace_info is
    variable ctrl       : pipeline_ctrl_lanes_type := r_wb.ctrl;       -- Pipeline control record
    variable v          : std_ulogic               := r_wb.v;          -- Current Virtualization mode
    variable xc_cause   : cause_type               := r_wb.xc_taken_cause;  -- Exception Cause
    variable wcsr       : wordx_lanes_type         := r_wb.wcsr;       -- Write back data to CSR etc
    variable trap_taken : lanes_type               := r_wb.trap_taken;
    variable results    : wordx_lanes_type         := r_wb.wdata;      -- Write back data to RF
    variable fsd_hi     : word                     := r_wb.fsd_hi;     -- High half of fsd data (RV32)
    -- Non-constant
    variable info    : trace_info := trace_info_none;
  begin
    -- Common signals are traced once only
    info.v         := v;                           -- Virtualization mode
    info.prv       := r_wb.prv;                    -- Privileged
    info.cause     := xc_cause;                    -- Exception Cause
    info.timestamp := timestamp(31 downto 0);      -- Timer Value
    info.swap      := r_wb.swap;

    for i in lanes'range loop
      -- Codification:
      -- valid  exception
      --   0        0     - no instruction
      --   0        1     - valid instruction
      --   1        0     - instruction with exception
      --   1        1     - instruction at breakpoint
      info.lanes(i).valid        := ctrl(i).valid or r_wb.trace_trig(i);
      info.lanes(i).exception    := (r_wb.xc_taken and ctrl(i).xc and trap_taken(i)) or r_wb.trace_trig(i);  -- Exception Flag
      info.lanes(i).pc  := to64(pc2xlen(ctrl(i).pc))(info.lanes(0).pc'range);
      -- When there is an FPU register destination, keep track of commit ID.
      -- Makes it possible to match with FPU write-back.
      if info.lanes(i).exception = '1' then
        info.lanes(i).result := uext(r_wb.xc_taken_tval, 64);  -- Exception Value
      elsif ext_f = 1 and i = fpu_lane and is_fpu_rd(ctrl(i).inst) then
        info.lanes(i).result := uext(ctrl(i).fpu, 64);         -- FPU commit ID
      else
        info.lanes(i).result := uext(results(i), 64);          -- Result
      end if;

      -- Pass high word of fsd write, if necessary.
      if ext_d = 1 and i = fpu_lane and XLEN = 32 and
         ctrl(i).valid = '1' and is_fpu_fsd(ctrl(i).inst) then
        set_hi(info.lanes(i).result, fsd_hi);
      end if;

      -- Instruction
      info.lanes(i).inst       := ctrl(i).inst;
      info.lanes(i).cinst      := ctrl(i).cinst;
      info.lanes(i).compressed := ctrl(i).comp;

      if ctrl(i).valid = '1' then
        info.lanes(i).int_res   := ctrl(i).rdv;
      end if;

      -- Load/store address, CSR data, branch destination
      info.lanes(i).xdata := wcsr(i);

    end loop;

    -- Only in memory lane
    if ctrl(memory_lane).valid = '1' then
      info.lanes(memory_lane).memory := to_bit(v_fusel_eq(ctrl(memory_lane).fusel, LD or ST) or is_cbo(ctrl(memory_lane).inst));
      info.lanes(memory_lane).cfi    := to_bit(v_fusel_eq(ctrl(memory_lane).fusel, CFI));
    end if;

    -- Only in csr lane lane
    if ctrl(csr_lane).valid = '1' then
      info.lanes(csr_lane).csr_write := ctrl(csr_lane).csrv;
    end if;

    return info;
  end;

  -- Generate E-trace interface signal
  procedure etrace_gen(holdn : in  std_ulogic;
                       r_wb  : in  writeback_reg_type;
                       r_x   : in  exception_reg_type;
                       r_csr : in  csr_reg_type;
                       eto   : out nv_etrace_type) is
    -- Non-constant
    variable et   : nv_etrace_type := nv_etrace_none;
    variable last : lanes_range    := 0;
  begin
    -- Last instruction
    if r_wb.swap = '0' then
      if single_issue = 0 and (r_wb.ctrl(one).valid or r_wb.ctrl(one).xc) = '1' and
        r_wb.ctrl(0).xc = '0' then
        last := one;
      end if;
    else
      if single_issue = 0 and (r_wb.ctrl(one).xc or not r_wb.ctrl(0).valid) = '1' then
        last := one;
      end if;
    end if;

    -- Instruction type
    if r_wb.ctrl(last).valid = '1' then
      -- xRET
      if r_wb.ret = '1' then
        et.itype := x"3";
      end if;
      -- branch
      if r_wb.ctrl(last).branch.valid = '1' then
        if r_wb.ctrl(last).branch.taken = '1' then
          et.itype := x"5";
        else
          et.itype := x"4";
        end if;
      end if;
      -- Jump
      if v_fusel_eq(r_wb.ctrl(last).fusel, JALR) then
        et.itype := x"6";
      end if;
    elsif r_wb.ctrl(last).xc = '1' and holdn = '1' then
      if r_wb.ctrl(last).cause.irq = '1' then -- Interrupt
        et.itype := x"2";
      else                                          -- Exception
        et.itype := x"1";
      end if;
    end if;

    et.cause := u2vec(r_wb.ctrl(last).cause.code, et.cause);
    et.tval  := r_wb.ctrl(last).tval;

    -- Privilege level for current retired instruction
    et.priv := '0' & r_wb.prv;
    if ext_h /= 0 and r_wb.v = '1' then
      if r_wb.prv = PRIV_LVL_U then
        et.priv := "101";
      else
        et.priv := "110";
      end if;
    end if;
    if r_x.rstate /= run then
      et.priv := "100";
    end if;

    et.iaddr        := pc2xlen(r_wb.ctrl(last).pc);
    et.ilastsize(0) := not r_wb.ctrl(last).comp;

    -- Number of instruction retired (in 16-bits)
    if holdn = '1' then
      if single_issue = 0 and (r_wb.ctrl(0).valid and r_wb.ctrl(one).valid) = '1' then
        if (r_wb.ctrl(0).comp and r_wb.ctrl(one).comp) = '1' then     -- 2 x 16
          et.iretire := "010";
        elsif (r_wb.ctrl(0).comp or r_wb.ctrl(one).comp) = '1' then   -- 1 x 16 + 1 x 32
          et.iretire := "011";
        else                                                          -- 2 x 32
          et.iretire := "100";
        end if;
      elsif (r_wb.ctrl(0).valid or r_wb.ctrl(one).valid) = '1' then
        if (r_wb.ctrl(0).valid and r_wb.ctrl(0).comp) = '1' or
           (r_wb.ctrl(one).valid and r_wb.ctrl(one).comp) = '1' then  -- 1 x 16
          et.iretire := "001";
        else                                                          -- 1 x 32
          et.iretire := "010";
        end if;
      end if;
    end if;

    ---- Optional signals
    et.ctext  := (others => '0');
    et.tetime := (others => '0');
    et.ctype  := (others => '0');
    et.sijump := (others => '0');

    eto := et;
  end;

  -- CSR Read
  -- CSR read unit located in register access stage.
  -- All read accesses are combinatorial accesses.
  procedure csr_read(csr_file    : in  csr_reg_type;
                     csra_in     : in  csratype;
                     iu_fflags   : in  word5;
                     mmu_csr     : in  nv_csr_in_type;
                     s_time      : in  word64;
                     s_vtime     : in  word64;
                     imsic_out   : out word3;
                     data_out    : out wordx) is
    variable csra_high : csratype      := csra_in(csra_in'high downto 4) & "0000";
    variable csra_low  : integer16     := u2i(csra_in(3 downto 0));
    variable csra_32   : integer32     := u2i(csra_in(4 downto 0));
    variable h_en      : boolean       := csr_file.misa(h_ctrl) = '1';
    variable v_mode    : std_ulogic    := csr_file.misa(h_ctrl) and csr_file.v;
    variable siselect  : integer       := u2i(csr_file.siselect.sel);
    -- Non-constant
    variable csr       : wordx         := zerox;
    variable imsic_csr : word3         := "000";
    -- State Enable extnesion (Smstateen)
    variable mstateen0_masked  : csr_mstateen0_type := csr_file.mstateen0 and CSR_MSTATEEN0_MASK;
    variable hstateen0_masked  : csr_hstateen0_type := csr_file.hstateen0 and mstateen0_masked;
    variable sstateen0_masked  : csr_sstateen0_type := csr_file.sstateen0 and hstateen0_masked;

  begin
    assert (not (csr_file.prv = PRIV_LVL_M and v_mode = '1')) report "Invalid V mode" severity failure;
    -- Zicfiss CSR accessibility (CSR_SSP)
    case csra_in is
      -- User Floating-Point CSRs
      when CSR_FFLAGS =>
        csr := to0x(csr_file.fflags);
        csr(csr_file.fflags'range) := csr(csr_file.fflags'range) or iu_fflags;
      when CSR_FRM =>
        csr := to0x(csr_file.frm);
      when CSR_FCSR =>
        csr(csr_file.fflags'range)  := csr_file.fflags or iu_fflags;
        csr(csr_file.frm'range)     := csr_file.frm;
      -- Hypervisor Trap Setup
      when CSR_HSTATUS        => csr := to_hstatus(csr_file.hstatus);
      when CSR_HEDELEG        => csr := csr_file.hedeleg and CSR_HEDELEG_MASK;
      when CSR_HIDELEG        => csr := csr_file.hideleg and hideleg_mask(ext_shlcofideleg);
      when CSR_HIE            => csr := csr_file.mie and CSR_HIE_MASK;
      when CSR_HCOUNTEREN     => csr := to0x(csr_file.hcounteren);
      when CSR_HGEIE          => csr := csr_file.hgeie;
      -- Hypervisor Trap Handling
      when CSR_HTVAL          => csr := csr_file.htval;
      when CSR_HIP            => csr := csr_file.mip and CSR_HIE_MASK;
      when CSR_HVIP           =>
        csr     := csr_file.hvip;
        csr(IRQ_VS_SOFTWARE)  := csr_file.mip(IRQ_VS_SOFTWARE);
        -- Smcdeleg and AIA adds support for virtualizing lcof IRQs
        if not(ext_smaia = 1 and ext_sscofpmf = 1 and ext_smcdeleg = 1 and h_en) then
          csr(IRQ_LCOF) := '0';
        end if;
      when CSR_HTINST         => csr := csr_file.htinst;
      when CSR_HGEIP          => csr := csr_file.hgeip;
      -- Hypervisor AIA registers
      when CSR_HVIEN          => csr := csr_file.hvien;
      when CSR_HVICTL         => csr := to_hvictl(csr_file.hvictl);
      -- Read-only zero
      when CSR_HVIPRIO1 | CSR_HVIPRIO2 => csr := (others => '0');
      -- Hypervisor AIA registers (RV32)
      when CSR_HIDELEGH       =>
      when CSR_HVIENH         =>
      when CSR_HVIPH          =>
      -- Hypervisor Sstateen extension CSRs
      when CSR_HSTATEEN0 => csr := to_hstateen0(hstateen0_masked);
      when CSR_HSTATEEN1 => csr(wordx'high) := csr_file.mstateen1.stateen and csr_file.hstateen1.stateen;
      when CSR_HSTATEEN2 => csr(wordx'high) := csr_file.mstateen2.stateen and csr_file.hstateen2.stateen;
      when CSR_HSTATEEN3 => csr(wordx'high) := csr_file.mstateen3.stateen and csr_file.hstateen3.stateen;
      when CSR_HSTATEEN0H => csr := to_hstateen0h(hstateen0_masked);
      when CSR_HSTATEEN1H => csr(31) := csr_file.mstateen1.stateen and csr_file.hstateen1.stateen;
      when CSR_HSTATEEN2H => csr(31) := csr_file.mstateen2.stateen and csr_file.hstateen2.stateen;
      when CSR_HSTATEEN3H => csr(31) := csr_file.mstateen3.stateen and csr_file.hstateen3.stateen;
      when CSR_HVIPRIO1H      =>
      when CSR_HVIPRIO2H      =>
      -- Hypervisor Protection and Translation
      when CSR_HGATP          =>
        csr := from_atp(riscv_mmu, csr_file.hgatp);
      when CSR_HENVCFG        =>
        csr := to_envcfg(calc_henvcfg_read_val(active_henvcfg, csr_file));
        -- if csr_file.menvcfg.sse = '0' then
        --   csr(3) := '0';
        -- end if;
      when CSR_HENVCFGH       =>
        -- csr := to_envcfgh(csr_file.henvcfg, csr_file.menvcfg);
        csr := to_envcfgh(calc_henvcfg_read_val(active_henvcfg, csr_file));
      -- Hypervisor Counter/Timer Virtualization Registers
      when CSR_HTIMEDELTA     => csr := csr_file.htimedelta(wordx'range);
      when CSR_HTIMEDELTAH    => csr := to0x(hi_h(csr_file.htimedelta));
      -- Virtual Supervisor Registers
      when CSR_VSSTATUS       =>
        csr := to_vsstatus(csr_file.vsstatus, csr_file.menvcfg.dte and csr_file.henvcfg.dte,
                            csr_file.henvcfg.sse and csr_file.menvcfg.sse,
                            to_bit(ext_zicfilp)
                            );
      when CSR_VSIE           =>
        csr(IRQ_S_EXTERNAL)  := csr_file.mie(IRQ_VS_EXTERNAL) and csr_file.hideleg(IRQ_VS_EXTERNAL);
        csr(IRQ_S_TIMER)     := csr_file.mie(IRQ_VS_TIMER)    and csr_file.hideleg(IRQ_VS_TIMER);
        csr(IRQ_S_SOFTWARE)  := csr_file.mie(IRQ_VS_SOFTWARE) and csr_file.hideleg(IRQ_VS_SOFTWARE);
        if ext_shlcofideleg = 1 and ext_sscofpmf = 1 then
          csr(IRQ_LCOF)      := csr_file.mie(IRQ_LCOF)        and
                                csr_file.hideleg(IRQ_LCOF) and csr_file.mideleg(IRQ_LCOF);
        end if;
        -- So far only LCOF (13) bit in hvien is writable.
        -- This is the behavior for all interrupts above 13 if more are implemented in the future.
        if ext_ssaia = 1 then
          for i in 13 to XLEN-1 loop
            if csr_file.hideleg(i) = '0' and
               (csr_file.hvien(i) and hvien_mask(ext_sscofpmf, ext_smcdeleg)(i)) = '1' then
              csr(i) := csr_file.vsie(i);
            end if;
          end loop;
        end if;

      when CSR_VSTVEC         => csr := csr_file.vstvec;
      when CSR_VSSCRATCH      => csr := csr_file.vsscratch;
      when CSR_VSISELECT      => csr := selector2wordx(csr_file.vsiselect);
      when CSR_VSIREG         =>
        -- VSIREG CSR is read from IMSIC in X stage
        imsic_csr := "011";
      when CSR_VSIREG2 | CSR_VSIREG3 | CSR_VSIREG4 | CSR_VSIREG5 | CSR_VSIREG6 =>
        -- Currently no custom/standard registers defined.
      when CSR_VSTOPEI        =>
        -- VSTOPEI CSR is read in X stage from IMSIC
        imsic_csr := "110";
      when CSR_VSTOPI         => csr := csr_file.vstopi;
      when CSR_VSEPC          =>
        csr := csr_file.vsepc;
        if ext_c = 1 and ISA_CONTROL(c_ctrl) = '1' and csr_file.misa(c_ctrl) = '0' then
          csr(1) := '0';
        end if;
      when CSR_VSCAUSE        => csr := cause2wordx(csr_file.vscause);
      when CSR_VSTVAL         => csr := csr_file.vstval;
      when CSR_VSIP           =>
        csr(IRQ_S_EXTERNAL) := csr_file.mip(IRQ_VS_EXTERNAL) and csr_file.hideleg(IRQ_VS_EXTERNAL);
        csr(IRQ_S_TIMER)    := csr_file.mip(IRQ_VS_TIMER)    and csr_file.hideleg(IRQ_VS_TIMER);
        csr(IRQ_S_SOFTWARE) := csr_file.mip(IRQ_VS_SOFTWARE) and csr_file.hideleg(IRQ_VS_SOFTWARE);
        if ext_shlcofideleg = 1 then
          csr(IRQ_LCOF)       := csr_file.mip(IRQ_LCOF) and csr_file.mideleg(IRQ_LCOF) and csr_file.hideleg(IRQ_LCOF);
        end if;
        -- So far only LCOF (13) bit in hvien is writable.
        -- This is the behavior for all interrupts above 13 if more are implemented in the future.
        for i in 13 to XLEN-1 loop
          if csr_file.hideleg(i) = '0' and
             (csr_file.hvien(i) and hvien_mask(ext_sscofpmf, ext_smcdeleg)(i)) = '1' then
            csr(i) := csr_file.hvip(i);
          end if;
        end loop;

      when CSR_VSATP          => csr := from_atp(riscv_mmu, csr_file.vsatp);
      -- User Counters/Timers - see below
      when CSR_VSTIMECMP     => csr := csr_file.vstimecmp(wordx'range);

      when CSR_VSTIMECMPH    => csr := to0x(hi_h(csr_file.vstimecmp));
      -- Supervisor Trap Setup
      when CSR_SSTATUS        =>
        if csr_file.v = '1' then
          csr := to_vsstatus(csr_file.vsstatus, csr_file.menvcfg.dte and csr_file.henvcfg.dte,
                             csr_file.henvcfg.sse and csr_file.menvcfg.sse,
                             to_bit(ext_zicfilp)
                            );
        else
          csr := to_sstatus(csr_file.mstatus,
                            csr_file.menvcfg.sse,
                            to_bit(ext_zicfilp),
                            csr_file.menvcfg.dte
                           );
        end if;
      when CSR_SIE            =>
        if csr_file.v = '1' then
          csr(IRQ_S_EXTERNAL)  := csr_file.mie(IRQ_VS_EXTERNAL) and csr_file.hideleg(IRQ_VS_EXTERNAL);
          csr(IRQ_S_TIMER)     := csr_file.mie(IRQ_VS_TIMER)    and csr_file.hideleg(IRQ_VS_TIMER);
          csr(IRQ_S_SOFTWARE)  := csr_file.mie(IRQ_VS_SOFTWARE) and csr_file.hideleg(IRQ_VS_SOFTWARE);
          if ext_shlcofideleg = 1 and ext_sscofpmf = 1 then
            csr(IRQ_LCOF)      := csr_file.mie(IRQ_LCOF)        and
                                  csr_file.hideleg(IRQ_LCOF) and csr_file.mideleg(IRQ_LCOF);
          end if;
          -- So far only LCOF (13) bit in hvien is writable.
          -- This is the behavior for all interrupts above 13 if more are implemented in the future.
          if ext_ssaia = 1 then
            for i in 13 to XLEN-1 loop
              if csr_file.hideleg(i) = '0' and
                 (csr_file.hvien(i) and hvien_mask(ext_sscofpmf, ext_smcdeleg)(i)) = '1' then
                csr(i) := csr_file.vsie(i);
              end if;
            end loop;
          end if;
        else
          csr := csr_file.mie and (csr_file.mideleg and not CSR_HIE_MASK);
          if ext_smaia = 1 then
            for i in 0 to XLEN-1 loop
              if csr_file.mideleg(i) = '0' and csr_file.mvien(i) = '1' then
                csr(i)    :=  csr_file.sie(i);
              end if;
            end loop;
          end if;
        end if;
      when CSR_SIEH           =>
      when CSR_STVEC          =>
        if csr_file.v = '1' then
          csr := csr_file.vstvec;
        else
          csr := csr_file.stvec;
        end if;
      when CSR_SCOUNTEREN     => csr := to0x(csr_file.scounteren);
      when CSR_SENVCFG        => csr := to_envcfg(calc_senvcfg_read_val(active_henvcfg, active_senvcfg, csr_file));
      when CSR_SCOUNTINHIBIT =>
        assert (not (ext_smcdeleg = 0 and csr_file.menvcfg.cde = '1'))
          report "menvcfg.cde can't be one when smcdeleg is not implemented" severity failure;
        -- For counters delegated to S-mode, the associated mcountinhibit bits can be accessed via scountinhibit.
        csr := to0x(csr_file.mcountinhibit and csr_file.mcounteren);

      -- Supervisor Trap Handling
      when CSR_SEPC           =>
        if csr_file.v = '1' then
          csr := csr_file.vsepc;
        else
          csr := csr_file.sepc;
        end if;
        if ext_c = 1 and ISA_CONTROL(c_ctrl) = '1' and csr_file.misa(c_ctrl) = '0' then
          csr(1) := '0';
        end if;
      when CSR_SCAUSE         =>
        if csr_file.v = '1' then
          csr := cause2wordx(csr_file.vscause);
        else
          csr := cause2wordx(csr_file.scause);
        end if;
      when CSR_STVAL          =>
        if csr_file.v = '1' then
          csr := csr_file.vstval;
        else
          csr := csr_file.stval;
        end if;
      when CSR_SIP            =>
        if csr_file.v = '1' then
          csr(IRQ_S_EXTERNAL)  := csr_file.mip(IRQ_VS_EXTERNAL) and csr_file.hideleg(IRQ_VS_EXTERNAL);
          csr(IRQ_S_TIMER)     := csr_file.mip(IRQ_VS_TIMER)    and csr_file.hideleg(IRQ_VS_TIMER);
          csr(IRQ_S_SOFTWARE)  := csr_file.mip(IRQ_VS_SOFTWARE) and csr_file.hideleg(IRQ_VS_SOFTWARE);
          if ext_shlcofideleg = 1 then
            csr(IRQ_LCOF)  :=
              csr_file.mip(IRQ_LCOF) and csr_file.hideleg(IRQ_LCOF) and csr_file.mideleg(IRQ_LCOF);
          end if;
          -- So far only LCOF (13) bit in hvien is writable.
          -- This is the behavior for all interrupts above 13 if more are implemented in the future.
          for i in 13 to XLEN-1 loop
            if csr_file.hideleg(i) = '0' and
               (csr_file.hvien(i) and hvien_mask(ext_sscofpmf, ext_smcdeleg)(i)) = '1' then
              csr(i) := csr_file.hvip(i);
            end if;
          end loop;
        else
          csr := csr_file.mip and csr_file.mideleg and sip_sie_mask(ext_sscofpmf = 1);
          if ext_smaia = 1 then
            for i in 0 to XLEN-1 loop
              if csr_file.mideleg(i) = '0' and
                 (csr_file.mvien(i) and mvien_mask(ext_sscofpmf, ext_smcdeleg)(i)) = '1' then
                csr(i) := csr_file.mvip(i);
              end if;
            end loop;
          end if;
        end if;
      when CSR_SIPH           =>
      when CSR_SSCRATCH       =>
        if csr_file.v = '1' then
          csr := csr_file.vsscratch;
        else
          csr := csr_file.sscratch;
        end if;
      when CSR_SISELECT       =>
        if csr_file.v = '1' then
          csr := selector2wordx(csr_file.vsiselect);
        else
          csr := selector2wordx(csr_file.siselect);
        end if;
      when CSR_SIREG | CSR_SIREG2 | CSR_SIREG3 | CSR_SIREG4 | CSR_SIREG5 | CSR_SIREG6 =>
        if csr_file.v = '1' then
          if is_imsic(csr_file.vsiselect) and imsic = 1 and csra_in = CSR_SIREG then
            -- VSIREG CSR is read from IMSIC in X stage
            imsic_csr := "011";
          elsif is_smcdeleg(csr_file.vsiselect) then
            -- This path doesn't exist, VS/VU always traps
          end if;
        else
          if is_imsic(csr_file.siselect) and imsic = 1 and csra_in = CSR_SIREG then
            -- SIREG CSR is read from IMSIC in X stage
            imsic_csr := "010";
          elsif is_smcdeleg(csr_file.siselect) then
            csr := smcdeleg_indirect_read(csr_file, csra_in);
          end if;
        end if;
        -- Currently no custom/standard registers defined.
      when CSR_STOPEI         =>
        if csr_file.v = '1' then
            -- VSTOPEI CSR is read in X stage from IMSIC
            imsic_csr := "110";
        else
            -- STOPEI CSR is read in X stage from IMSIC
            imsic_csr := "101";
        end if;
      when CSR_STOPI          =>
        if csr_file.v = '1' then
          csr := csr_file.vstopi;
        else
          csr := csr_file.stopi;
        end if;
      -- Supervisor Sstateen extension CSRs
      when CSR_SSTATEEN0 =>
        csr := to_sstateen0(sstateen0_masked);
      when CSR_SSTATEEN1 | CSR_SSTATEEN2 | CSR_SSTATEEN3 =>
      -- Supervisor Protection and Translation
      when CSR_SATP           =>
        if csr_file.v = '1' then
          csr := from_atp(riscv_mmu, csr_file.vsatp);
        else
          csr := from_atp(riscv_mmu, csr_file.satp);
        end if;
      when CSR_STIMECMP     =>
        if csr_file.v = '1' then
          csr := csr_file.vstimecmp(wordx'range);
        else
          csr := csr_file.stimecmp(wordx'range);
        end if;

      when CSR_STIMECMPH    =>
        if csr_file.v = '1' then
          csr := to0x(hi_h(csr_file.vstimecmp));
        else
          csr := to0x(hi_h(csr_file.stimecmp));
        end if;
      -- Supervisor Count Overflow
      when CSR_SCOUNTOVF      =>
        for i in 3 to perf_cnts + 3 - 1 loop
          csr(i) := csr_file.hpmevent(i).overflow;
          if csr_file.mcounteren(i) = '0' then
            csr(i) := '0';
          elsif h_en and csr_file.v = '1' and
                csr_file.hcounteren(i) = '0' then
            csr(i) := '0';
          end if;
        end loop;
      -- Machine Information Registers
      when CSR_MVENDORID      => csr := CSR_VENDORID;
      when CSR_MARCHID        => csr := CSR_ARCHID;
      when CSR_MIMPID         => csr := CSR_IMPID;
      when CSR_MHARTID        => csr := to0x(hart);
      when CSR_MCONFIGPTR     => csr := zerox;
      --  Machine Trap Setup
      when CSR_MSTATUS        => csr := to_mstatus(csr_file.mstatus);
      when CSR_MSTATUSH       => csr := to_mstatush(csr_file.mstatus);
      when CSR_MISA           => csr := csr_file.misa;
        -- Should NOEL-V extension availability not be visible?
        -- (Useful for simulation comparisons.)
        if show_misa_x = 0 then
          csr(x_ctrl) := '0';
        end if;
      when CSR_MTVEC          => csr := csr_file.mtvec;
      when CSR_MEDELEG        => csr := csr_file.medeleg;
      when CSR_MIDELEG        => csr := csr_file.mideleg(wordx'range);
      when CSR_MIDELEGH       =>
      when CSR_MIE            => csr := csr_file.mie(wordx'range);
      when CSR_MIEH           =>
      when CSR_MCOUNTEREN     => csr := to0x(csr_file.mcounteren);
      -- Machine Trap Handling
      when CSR_MSCRATCH       => csr := csr_file.mscratch;
      when CSR_MEPC           =>
        csr := csr_file.mepc;
        if ext_c = 1 and ISA_CONTROL(c_ctrl) = '1' and csr_file.misa(c_ctrl) = '0' then
          csr(1) := '0';
        end if;
      when CSR_MCAUSE         => csr := cause2wordx(csr_file.mcause);
      when CSR_MTVAL          => csr := csr_file.mtval;
      when CSR_MIP            => csr := csr_file.mip;
      when CSR_MIPH           =>
      when CSR_MNSCRATCH      => csr := csr_file.mnscratch;
      when CSR_MNEPC          => csr := csr_file.mnepc;
      when CSR_MNCAUSE        => csr := cause2wordx(csr_file.mncause);
      when CSR_MNSTATUS       => csr := to_mnstatus(csr_file.mnstatus);
      when CSR_MISELECT       => csr := selector2wordx(csr_file.miselect);
      when CSR_MIREG          =>
        if not is_custom(csr_file.miselect) then
          -- IPRIO array from machine level not implemented (major priorities have always default order)
          if csr_file.miselect.sel(7 downto 4) = x"3" or imsic = 0 then
            csr := (others => '0');
          else
            -- MIREG CSR is read from IMSIC in X stage
            imsic_csr := "001";
          end if;
        else
        end if;
      when CSR_MIREG2 =>
        -- Currently no standard/custom registers except custom PMA defined
        if ext_smcsrind = 0 then
        end if;
      when CSR_MIREG3 | CSR_MIREG4 | CSR_MIREG5 | CSR_MIREG6 =>
        -- Currently no standard/custom registers defined
      when CSR_MTOPEI         =>
        -- MTOPEI CSR is read in X stage from IMSIC
        imsic_csr := "100";
      when CSR_MTOPI          => 
        csr := csr_file.mtopi;
      when CSR_MVIEN          => csr := csr_file.mvien;
      when CSR_MVIENH         =>
      when CSR_MVIP           => csr := to_mvip(csr_file.mip, csr_file.mvip, csr_file.mvien,
                                                ext_sstc, csr_file.menvcfg.stce);
      when CSR_MVIPH          =>
      when CSR_MSTATEEN0 => csr := to_mstateen0(mstateen0_masked);
      -- No masking needed on mstateen[1-3] since they only have the stateen bit
      -- which is always active. If the extension is disabled we will trap on the access
      -- and this is don't care.
      when CSR_MSTATEEN1 => csr(wordx'high) := csr_file.mstateen1.stateen;
      when CSR_MSTATEEN2 => csr(wordx'high) := csr_file.mstateen2.stateen;
      when CSR_MSTATEEN3 => csr(wordx'high) := csr_file.mstateen3.stateen;
      when CSR_MSTATEEN0H => csr := to_mstateen0h(mstateen0_masked);
      when CSR_MSTATEEN1H => csr(31) := csr_file.mstateen1.stateen;
      when CSR_MSTATEEN2H => csr(31) := csr_file.mstateen2.stateen;
      when CSR_MSTATEEN3H => csr(31) := csr_file.mstateen3.stateen;
      when CSR_MTINST         => csr := csr_file.mtinst;
      when CSR_MTVAL2         => csr := csr_file.mtval2;
      when CSR_MENVCFG        => csr := to_envcfg(csr_file.menvcfg);
      when CSR_MENVCFGH       => csr := to_envcfgh(csr_file.menvcfg);
      when CSR_MSECCFG        => csr := to_mseccfg(csr_file.mseccfg)(wordx'range);
      when CSR_MSECCFGH       => csr := to0x(hi_h(to_mseccfg(csr_file.mseccfg)));
      -- Machine Protection and Translation
      when CSR_PMPCFG0        =>
        if is_rv64 then
          csr := pmpcfg(csr_file.pmpcfg, 0, 7);
        else
          csr := pmpcfg(csr_file.pmpcfg, 0, 3);
        end if;
      when CSR_PMPCFG1        =>
        csr := pmpcfg(csr_file.pmpcfg, 4, 7);
      when CSR_PMPCFG2        =>
        if is_rv64 then
          csr := pmpcfg(csr_file.pmpcfg, 8, 15);
        else
          csr := pmpcfg(csr_file.pmpcfg, 8, 11);
        end if;
      when CSR_PMPCFG3        =>
        csr := pmpcfg(csr_file.pmpcfg, 12, 15);
      -- Machine|User Counter/Timers
      when CSR_CYCLE |
            CSR_MCYCLE         => csr := csr_file.mcycle(wordx'range);
      when CSR_CYCLEH |
            CSR_MCYCLEH        => csr := to0x(hi_h(csr_file.mcycle));
      when CSR_TIME           =>
        -- The time CSR is a read-only shadow of the memory-mapped mtime register.
        -- Implementations can convert reads of the time CSR into loads to the
        -- memory-mapped mtime register, or emulate this functionality in M-mode software.
        if csr_file.v = '1' then
          csr := s_vtime(wordx'range);
        else
          csr := s_time(wordx'range);
        end if;
      when CSR_TIMEH          =>
        if csr_file.v = '1' then
          csr := to0x(hi_h(s_vtime));
        else
          csr := to0x(hi_h(s_time));
        end if;
      when CSR_INSTRET |
            CSR_MINSTRET       => csr := csr_file.minstret(wordx'range);
      when CSR_INSTRETH |
            CSR_MINSTRETH      => csr := to0x(hi_h(csr_file.minstret));
      -- Machine Performance Monitoring Counter Selector
      when CSR_MCOUNTINHIBIT  => csr := to0x(csr_file.mcountinhibit);
      -- Debug/Trace Registers
      when CSR_TSELECT        => csr := to0x(csr_file.tcsr.tselect);
      when CSR_TDATA1         => csr := csr_file.tcsr.tdata1(u2i(csr_file.tcsr.tselect));
      when CSR_TDATA2         => csr := csr_file.tcsr.tdata2(u2i(csr_file.tcsr.tselect));
      when CSR_TDATA3         => csr := csr_file.tcsr.tdata3(u2i(csr_file.tcsr.tselect));
      when CSR_TINFO          =>
        csr := to0x(csr_file.tcsr.tinfo(u2i(csr_file.tcsr.tselect)));
        csr(24) := '1'; -- TRIGGER VERSION 1.0
      when CSR_HCONTEXT       => csr := to0x(csr_file.tcsr.mhcontext);
      when CSR_MCONTEXT       => csr := to0x(csr_file.tcsr.mhcontext);
      when CSR_SCONTEXT       =>
        if is_rv64 then
          csr := to0x(csr_file.tcsr.scontext);
        else
          csr := to0x(csr_file.tcsr.scontext(15 downto 0));
        end if;
      --when CSR_MSCONTEXT      =>
      -- Core Debug Registers
      when CSR_DCSR           =>
        csr(31 downto 28)     := csr_file.dcsr.xdebugver;
        if ext_smdbltrp = 1 then
          csr(26 downto 24)   := csr_file.dcsr.extcause;
          csr(19)             := csr_file.dcsr.cetrig;
        end if;
        csr(18)               := csr_file.dcsr.pelp;
        if h_en then
          csr(17)             := csr_file.dcsr.ebreakvs;
          csr(16)             := csr_file.dcsr.ebreakvu;
        end if;
        csr(15)               := csr_file.dcsr.ebreakm;
        csr(13)               := csr_file.dcsr.ebreaks;
        csr(12)               := csr_file.dcsr.ebreaku;
        csr(11)               := csr_file.dcsr.stepie;
        csr(10)               := csr_file.dcsr.stopcount;
        csr(9)                := csr_file.dcsr.stoptime;
        csr(8 downto 6)       := csr_file.dcsr.cause;
        if h_en then
          csr(5)              := csr_file.dcsr.v;
        end if;
        csr(4)                := csr_file.dcsr.mprven;
        csr(3)                := csr_file.dcsr.nmip;
        csr(2)                := csr_file.dcsr.step;
        csr(1 downto 0)       := csr_file.dcsr.prv;
      when CSR_DPC            => csr := csr_file.dpc;
      when CSR_DSCRATCH0      => csr := csr_file.dscratch0;
      when CSR_DSCRATCH1      => csr := csr_file.dscratch1;
      -- Custom Registers
      when CSR_FEATURES       =>
        if ext_noelv = 1 then
          csr(31)             := csr_file.dfeaturesen.tpbuf_en;
          csr(30 downto 26)   := csr_file.trace.ctrl(12 downto 8);
          -- [25:21] RESERVED
          csr(21)             := csr_file.dfeaturesen.pma_fault_46;
          csr(20)             := csr_file.dfeaturesen.pma_fault_02;
          csr(19)             := csr_file.dfeaturesen.hpmc_mode;
          csr(18)             := csr_file.dfeaturesen.diag_s;
          csr(17)             := csr_file.dfeaturesen.x0;
          csr(16)             := csr_file.dfeaturesen.mmu_oldfence;
          csr(15)             := csr_file.dfeaturesen.mmu_hptfault;
          csr(14)             := csr_file.dfeaturesen.mmu_sptfault;
          csr(13)             := csr_file.dfeaturesen.dm_trace;
          csr(11)             := csr_file.dfeaturesen.fs_dirty;
          csr(10)             := csr_file.dfeaturesen.nostream;
          csr(9)              := csr_file.dfeaturesen.staticdir;
          csr(8)              := csr_file.dfeaturesen.staticbp;
          csr(7)              := csr_file.dfeaturesen.h_ade;
          csr(6)              := csr_file.dfeaturesen.b2bst_dis;
          csr(5)              := csr_file.dfeaturesen.lalu_dis;
          csr(4)              := csr_file.dfeaturesen.lbranch_dis;
          csr(3)              := csr_file.dfeaturesen.ras_dis;
          csr(2)              := csr_file.dfeaturesen.jprd_dis;
          csr(1)              := csr_file.dfeaturesen.btb_dis;
          csr(0)              := csr_file.dfeaturesen.dual_dis;
        end if;
      when CSR_FEATURESH      =>
      when CSR_CCTRL          =>
        if ext_noelv = 1 then
          csr(13)             := mmu_csr.cctrl.iflushpend;
          csr(12)             := mmu_csr.cctrl.dflushpend;
          -- Bit[11] is RESERVED
          if itcmen = 1 then
            csr(10)           := mmu_csr.cctrl.itcmwipe;
          end if;
          if dtcmen = 1 then
            csr(9)            := mmu_csr.cctrl.dtcmwipe;
          end if;
          csr(8)              := csr_file.cctrl.dsnoop;
          csr(7)              := csr_file.cctrl.dflush;
          csr(6)              := csr_file.cctrl.iflush;
          -- Bit[5:4] is RESERVED
          csr(3 downto 2)     := csr_file.cctrl.dcs;
          csr(1 downto 0)     := csr_file.cctrl.ics;
        end if;
      when CSR_TCMICTRL       =>
      when CSR_TCMDCTRL       =>
      when CSR_SSP =>
        csr := csr_file.ssp;
      when CSR_CAPABILITY =>
        if ext_noelv = 1 then
          csr                 := to_capability(u2vec(fpuconf, 2), mmu_csr.cconfig);
        end if;
      when CSR_CAPABILITYH =>
        if is_rv32 and ext_noelv = 1 then
          csr(word'range)     := to_capabilityh(u2vec(fpuconf, 2), mmu_csr.cconfig);
        end if;
      when others =>
        case csra_high is
          -- Machine|User Hardware Performance Monitoring
          when CSR_CYCLE |         -- Base for counters.
                CSR_MCYCLE =>
            -- CSR_(M)HPMCOUNTER3-15  (0-2 never _ok here!)
            if counter_ok(csra_low) = '1' then
              csr := csr_file.hpmcounter(csra_low)(wordx'range);
            end if;
          when CSR_CYCLEH |         -- Base for counters.
                CSR_MCYCLEH =>
            -- CSR_(M)HPMCOUNTER3-15H  (0-2 never _ok here!)
            if is_rv32 and counter_ok(csra_low) = '1' then
              csr := to0x(hi_h(csr_file.hpmcounter(csra_low)));
            end if;
          -- Machine|User Hardware Performance Monitoring (continued)
          when CSR_HPMCOUNTER16 |  -- All the higher counters.
                CSR_MHPMCOUNTER16 =>
            -- CSR_(M)HPMCOUNTER16-31
            if counter_ok(csra_low + 16) = '1' then
              csr := csr_file.hpmcounter(csra_low + 16)(wordx'range);
            end if;
          when CSR_HPMCOUNTER16H |  -- All the higher counters.
                CSR_MHPMCOUNTER16H =>
            -- CSR_(M)HPMCOUNTER16-31H
            if is_rv32 and counter_ok(csra_low + 16) = '1' then
              csr := to0x(hi_h(csr_file.hpmcounter(csra_low + 16)));
            end if;
          -- According to the RISC-V documentation, the value read back from
          -- CSR_PMPADDR<x> will depend on pmpcfg<x> setting under some circumstances.
          when CSR_PMPADDR0 =>
            if csra_low < pmp_entries then
              csr(pmp_msb - 2 downto 0) := get_lo(csr_file.pmpaddr(csra_low), pmp_msb - 2 + 1);
              if pmpcfg(pmp_entries, csr_file.pmpcfg, csra_low, 4) = '1' then  -- NA4/NAPOT
                csr(pmp_g - 2 downto 0) := (others => '1');
              else                                                             -- OFF/TOR
                csr(pmp_g - 1 downto 0) := (others => '0');
              end if;
            end if;
          -- Machine Performance Monitoring Counter Selector
          when CSR_MCOUNTINHIBIT =>  -- MCOUNTINHIBIT/MHPMEVENT3-15
            -- CSR_MHPMEVENT3-15  (0-2 never _ok here!)
            if counter_ok(csra_low) = '1' then
              csr := to_hpmevent(csr_file.hpmevent(csra_low));
            end if;
          when CSR_MHPMEVENT16 =>  -- MHPMEVENT16-31
            if counter_ok(csra_low + 16) = '1' then
              csr := to_hpmevent(csr_file.hpmevent(csra_low + 16));
            end if;
          when CSR_MHPMEVENT0H =>  -- MHPMEVENT3-15H
            -- CSR_MHPMEVENT3-15  (0-2 never _ok here!)
            if is_rv32 and counter_ok(csra_low) = '1' then
              csr := to_hpmeventh(csr_file.hpmevent(csra_low));
            end if;
          when CSR_MHPMEVENT16H =>  -- MHPMEVENT16-31H
            if is_rv32 and counter_ok(csra_low + 16) = '1' then
              csr := to_hpmeventh(csr_file.hpmevent(csra_low + 16));
            end if;
          when others =>
            csr := zerox;
        end case;
    end case;

    imsic_out     := imsic_csr;
    data_out      := csr;
  end;

  -- Forwarding unit for load/store unit
  procedure ex_stdata_forwarding(r        : in  registers;
                                 data_out : out wordx) is
    variable rfa2 : rfa_tuple := rfa(2, e, 0);
    -- Non-constant
    variable data : wordx     := r.e.stdata;
  begin
    -- Forwarding paths due to late ALUs
    -- lane | stage | instr
    --   0  |   wb  | addi x1, x0, 1
    --   1  |   wb  | add x3, x1, x2
    -- ...
    --   0  |   e   | sw x3, 0(x2)
    -- Do not forward in case we have forwarded from previous stages
    -- lane | stage | instr
    --   0  |   wb  | addi x1, x0, 1
    --   1  |   wb  | add x3, x1, x2
    -- ...
    --   0  |   m   | addi x3, x2, 1
    --   1  |   m   | ...
    --   0  |   e   | jal x3

    if r.e.stforw(0) = '0' then
      if late_alu = 1 then
        if    single_issue = 0 and
              r.wb.lalu(one) = '1' and v_rd_eq(r, wb, one, rfa2) then
          data := r.wb.wdata(one);
        elsif r.wb.lalu(0) = '1' and v_rd_eq(r, wb, 0, rfa2) then
          data := r.wb.wdata(0);
        end if;
      else
        -- CSR is late.
        if    r.wb.lalu(csr_lane) = '1' and v_rd_eq(r, wb, csr_lane, rfa2) then
          data := r.wb.wdata(csr_lane);
        end if;
      end if;
    end if;

    data_out   := data;
  end;

  -- Forwarding unit for the ALU located in execute stage
  procedure ex_alu_preforward(r       : in  registers;
                              same    : in stage_type;  -- For experimentation
                              late    : in stage_type;  --    -    "   -
                              lane    : in  lanes_range;
                              forw_in : in  std_logic_vector(1 to 2);
                              op1_out : out std_logic_vector;
                              op2_out : out std_logic_vector) is
    variable rfa1  : rfa_tuple := rfa(1, same, lane);
    variable rfa2  : rfa_tuple := rfa(2, same, lane);
    -- Non-constant
    variable op1   : word3     := "000";
    variable op2   : word3     := "000";
  begin

    -- Op1
    -- lane | stage | instr
    --   0  |   x   | ld x1, 0(x2)
    --   1  |   x   | ...
    -- ...
    --   0  |   e   | addi x2, x1, 3
    if forw_in(1) = '0' then
      if    single_issue = 0 and
            v_rd_eq(r, late, one, rfa1) and v_fusel_eq(r, late, one, MUL or FPU ) then
        op1   := "001";
      elsif v_rd_eq(r, late, 0, rfa1) then
        if    v_fusel_eq(r, late, 0, LD) then
          op1 := "010";
        elsif v_fusel_eq(r, late, 0, MUL or FPU ) then
          op1 := "011";
        end if;
      -- Forwarding paths due to late ALUs
      -- lane | stage | instr
      --   0  |   wb  | ld x1, 0(x2)
      --   1  |   wb  | add x2, x1, x4
      -- ...
      --   0  |   e   | addi x3, x2, 3
      end if;
    end if;

    -- Op2
    -- Do not forward for Store operation
    if not v_fusel_eq(r, same, lane, ST) and forw_in(2) = '0' then
      if    single_issue = 0 and
            v_rd_eq(r, late, one, rfa2) and v_fusel_eq(r, late, one, MUL or FPU ) then
        op2   := "001";
      elsif v_rd_eq(r, late, 0, rfa2) then
        if    v_fusel_eq(r, late, 0, LD) then
          op2 := "010";
        elsif v_fusel_eq(r, late, 0, MUL or FPU ) then
          op2 := "011";
        end if;
      -- Forwarding paths due to late ALUs
      end if;
    end if;


    op1_out := op1(op1_out'range);
    op2_out := op2(op2_out'range);
  end;

  -- Forwarding unit for the ALU located in execute stage
  procedure ex_alu_forwarding(r       : in  registers;
                              lane    : in  lanes_range;
                              forw_in : in  std_logic_vector(1 to 2);
                              op1_out : out wordx;
                              op2_out : out wordx) is
    variable rfa1     : rfa_tuple := rfa(1, e, lane);
    variable rfa2     : rfa_tuple := rfa(2, e, lane);
    -- Non-constant
    variable forw_op1 : word2     := r.e.alupreforw1(lane)(1 downto 0);
    variable forw_op2 : word2     := r.e.alupreforw2(lane)(1 downto 0);
    variable op1      : wordx     := r.e.alu(lane).op1;
    variable op2      : wordx     := r.e.alu(lane).op2;
  begin
    -- Revert back to old code (to synthesize with Synplify)
    if NO_PREFORWARD then
      ex_alu_preforward(r, e, x, lane, r.e.aluforw(lane), forw_op1, forw_op2);
    end if;

    -- Op1
    -- lane | stage | instr
    --   0  |   x   | ld x1, 0(x2)
    --   1  |   x   | ...
    -- ...
    --   0  |   e   | addi x2, x1, 3

    case forw_op1 is
    when "01"   => op1 := r.x.result(one);
    when "10"   => op1 := r.x.rdata(wordx'range);
    when "11"   => op1 := r.x.result(0);
    when others =>
    end case;

    -- Op2
    -- Do not forward for Store operation.


    case forw_op2 is
    when "01"   => op2 := r.x.result(one);
    when "10"   => op2 := r.x.rdata(wordx'range);
    when "11"   => op2 := r.x.result(0);
    when others =>
    end case;

    op1_out := op1;
    op2_out := op2;
  end;

  -- Forwarding unit for jump
  procedure ex_jump_forwarding(r       : in  registers;
                               lane    : in  lanes_range;
                               op1_out : out wordx) is
    variable rfa1     : rfa_tuple                := rfa(1, e, lane);
    variable forw_in  : std_logic_vector(1 to 2) := r.e.jumpforw(branch_lane);
    -- Non-constant
    variable forw_op1 : word2                    := r.e.alupreforw1(lane)(1 downto 0);
    variable forw_op2 : word2;   -- Dummy
    variable op1      : wordx                    := r.e.jop1;
  begin
    -- Revert back to old code (to synthesize with Synplify)
    if NO_PREFORWARD then
      ex_alu_preforward(r, e, x, lane, r.e.aluforw(branch_lane), forw_op1, forw_op2);
    end if;

    -- Op1
    -- Forward from exception stage, where mul/div and ld operation get results.
    -- lane | stage | instr
    --   0  |   x   | ld x1, 0(x2)
    --   1  |   x   | ...
    -- ...
    --   0  |   e   | jal x1

    case forw_op1 is
    when "01"   => op1 := r.x.result(one);
    when "10"   => op1 := r.x.rdata(wordx'range);
    when "11"   => op1 := r.x.result(0);
    when others =>
    end case;

    op1_out := op1;
  end;

  -- Forwarding unit for late ALUs located in exception stage
  procedure xc_alu_preforward(r       : in  registers;
                              same    : in stage_type;  -- For experimentation
                              late    : in stage_type;  --    -    "   -
                              lane    : in  lanes_range;
                              op1_out : out std_logic_vector;
                              op2_out : out std_logic_vector) is
    variable rfa1  : rfa_tuple   := rfa(1, same, lane);
    variable rfa2  : rfa_tuple   := rfa(2, same, lane);
    -- Non-constant
    variable op1   : word3       := "000";
    variable op2   : word3       := "000";
    variable swap  : std_ulogic;
    variable nlane : lanes_range := 0;
    variable slane : std_ulogic  := '0';
  begin
    if same = x then
      swap := r.x.swap;
    elsif same = m then
      swap := r.m.swap;
    else
      assert false severity failure;
    end if;

    -- Late forward from Load or Mul/Div operations in the other lane

    if single_issue = 0 then
      -- nlane: integer representing the other lane
      -- slane: bit representing this lane
      nlane   := 1;
      slane   := '0';
      if lane = 1 then
        nlane := 0;
        slane := '1';
      end if;
    end if;


    -- Op1 Forwarding Signals
    -- Do not forward from same instructions.
    -- Do not forward ahead of time.

    -- Get value from load:
    -- lane | stage | instr
    --   0  |   x   | ld x1, 0(x2)
    --   1  |   x   | addi x2, x1, 3
    -- Load is only first if the pair is not swapped.
    if    single_issue = 0                     and
          v_rd_eq(r, same, memory_lane, rfa1)  and
          v_fusel_eq(r, same, memory_lane, LD) and
          swap = '0' then
      op1       := "001";
    -- Get value from execute ALU:
    -- lane | stage | instr
    --   0  |   x   | add x1, x2, x0
    --   1  |   x   | addi x2, x1, 3
    elsif single_issue = 0                                        and
          v_rd_eq(r, same, nlane, rfa1)                           and
          v_fusel_eq(r, same, nlane, MUL or ALU or FPU
          ) and
          (slane xor swap) = '1' then
      op1       := "010";
    -- Get value from late ALU:
    -- lane | stage | instr
    --   0  |   wb  | ld x1, 0(x2)
    --   1  |   wb  | addi x2, x1, 3
    --   0  |   x   | add x1, x2, x0
    --   1  |   x   | ...
    elsif single_issue = 0 and
          v_rd_eq(r, late, one, rfa1) then
      op1       := "011";
    elsif v_rd_eq(r, late, 0, rfa1) then
      op1       := "100";
    end if;

    -- Op2 Forwarding Signals
    if    single_issue = 0                     and
          v_rd_eq(r, same, memory_lane, rfa2)  and
          v_fusel_eq(r, same, memory_lane, LD) and
          swap = '0' then
      op2       := "001";
    elsif single_issue = 0                                        and
          v_rd_eq(r, same, nlane, rfa2)                           and
          v_fusel_eq(r, same, nlane, MUL or ALU or FPU
          ) and
          (slane xor swap) = '1' then
      op2       := "010";
    elsif single_issue = 0 and
          v_rd_eq(r, late, one, rfa2) then
      op2       := "011";
    elsif v_rd_eq(r, late, 0, rfa2) then
      op2       := "100";
    end if;


    op1_out := op1(op1_out'range);
    op2_out := op2(op2_out'range);
  end;

  procedure xc_alu_forwarding(r       : in  registers;
                              lane    : in  lanes_range;
                              op1_out : out wordx;
                              op2_out : out wordx) is
    variable rfa1     : rfa_tuple   := rfa(1, x, lane);
    variable rfa2     : rfa_tuple   := rfa(2, x, lane);
    -- Non-constant
    variable forw_op1 : word3       := r.x.alupreforw1(lane);
    variable forw_op2 : word3       := r.x.alupreforw2(lane);
    variable op1      : wordx       := r.x.alu(lane).op1;
    variable op2      : wordx       := r.x.alu(lane).op2;
    variable nlane    : lanes_range := 0;
    variable slane    : std_ulogic  := '0';
  begin
    -- Revert back to old code (to synthesize with Synplify).
    if NO_PREFORWARD then
      xc_alu_preforward(r, x, wb, lane, forw_op1, forw_op2);
    end if;

    -- Late forward from Load or Mul/Div operations in the other lane
    -- bit 1 -> forward from that stage
    -- bit 0 -> which lane to forward

    if single_issue = 0 then
      -- nlane: integer representing the other lane
      -- slane: bit representing this lane
      nlane   := 1;
      slane   := '0';
      if lane = 1 then
        nlane := 0;
        slane := '1';
      end if;
    end if;

    -- Op1 Forwarding Signals
    -- Do not forward from same instructions.
    -- Do not forward ahead of time.
    -- Get value from load:
    -- lane | stage | instr
    --   0  |   x   | ld x1, 0(x2)
    --   1  |   x   | addi x2, x1, 3
    -- Get value from execute ALU:
    -- lane | stage | instr
    --   0  |   x   | add x1, x2, x0
    --   1  |   x   | addi x2, x1, 3
    -- Get value from late ALU:
    -- lane | stage | instr
    --   0  |   wb  | ld x1, 0(x2)
    --   1  |   wb  | addi x2, x1, 3
    --   0  |   x   | add x1, x2, x0
    --   1  |   x   | ...

    -- Op1 First Stage Mux
    case forw_op1 is
    when "001"  => op1 := r.x.rdata(wordx'range);
    when "010"  => op1 := r.x.result(nlane);
    when "011"  => op1 := r.wb.wdata(one);
    when "100"  => op1 := r.wb.wdata(0);
    when others =>
    end case;

    -- Op2 First Stage Mux
    case forw_op2 is
    when "001"  => op2 := r.x.rdata(wordx'range);
    when "010"  => op2 := r.x.result(nlane);
    when "011"  => op2 := r.wb.wdata(one);
    when "100"  => op2 := r.wb.wdata(0);
    when others =>
    end case;

    op1_out := op1;
    op2_out := op2;
  end;

  -- Forwarding unit for late ALUs located in exception stage
  procedure xc_popchk_preforward(r       : in  registers;
                                 same    : in stage_type;  -- For experimentation
                                 late    : in stage_type;  --    -    "   -
                                 op1_out : out std_logic_vector) is
    variable rfa1 : rfa_tuple := rfa(1, same, 0);
    -- Non-constant
    variable op1  : word2     := "00";
  begin
    -- Get value from late ALU:
    -- lane | stage | instr
    --   0  |   wb  | ld x1, 0(sp)
    --   1  |   wb  | addi x2, x1, 8
    --   0  |   x   | sspopchk x1
    if    single_issue = 0 and
          v_rd_eq(r, late, one, rfa1) then
      op1       := "01";
    elsif v_rd_eq(r, late, 0, rfa1) then
      op1       := "10";
    end if;

    op1_out := op1(op1_out'range);
  end;

  -- Since SSPOPCHK is timing critical this is cut down as far as possible.
  -- SSPOPCHK is guaranteed to not be dependent on a swapped instruction.
  procedure xc_popchk_forwarding(r         : in  registers;
                                 equal_out : out std_logic) is
    variable rfa1     : rfa_tuple   := rfa(1, x, memory_lane);
    variable sslink   : wordx       := r.x.rdata(wordx'range);
    -- Non-constant
    variable forw_op  : word2       := r.x.popchkpreforw;
    variable eq_x_alu : boolean     := r.x.alu(memory_lane).op1 = sslink;
    variable eq_wb_0  : boolean     := r.wb.wdata(0)            = sslink;
    variable eq_wb_1  : boolean     := r.wb.wdata(one)          = sslink;
    variable equal    : boolean;
  begin
    -- Revert back to old code (to synthesize with Synplify).
    if NO_PREFORWARD then
      xc_popchk_preforward(r, x, wb, forw_op);
    end if;


    case forw_op is
    when "01"   => equal := eq_wb_1;
    when "10"   => equal := eq_wb_0;
    when others => equal := eq_x_alu;
    end case;

    equal_out := to_bit(equal);
  end;

  -- Limited version of xc_alu_preforwarding
  -- Used when only CSRs do calculations in exception stage.
  procedure xc_csr_preforward(r       : in  registers;
                              lane    : in  lanes_range;
                              op1_out : out std_logic_vector) is
    variable rfa1  : rfa_tuple   := rfa(1, x, lane);
    variable swap  : std_ulogic  := r.x.swap;
    -- Non-constant
    variable op1   : word3       := "000";
    variable nlane : lanes_range := 0;
    variable slane : std_ulogic  := '0';
  begin
    -- Late forward from Load or Mul/Div operations in the other lane

    if single_issue = 0 then
      -- nlane: integer representing the other lane
      -- slane: bit representing this lane
      nlane   := 1;
      slane   := '0';
      if lane = 1 then
        nlane := 0;
        slane := '1';
      end if;
    end if;


    -- Op1 Forwarding Signals
    -- Do not forward from same instructions.
    -- Do not forward ahead of time.

    -- Get value from load:
    -- lane | stage | instr
    --   0  |   x   | ld x1, 0(x2)
    --   1  |   x   | addi x2, x1, 3
    -- Load is only first if the pair is not swapped.
    if    single_issue = 0                  and
          v_rd_eq(r, x, memory_lane, rfa1)  and
          v_fusel_eq(r, x, memory_lane, LD) and
          swap = '0' then
      op1       := "001";
    -- Get value from execute ALU:
    -- lane | stage | instr
    --   0  |   x   | add x1, x2, x0
    --   1  |   x   | addi x2, x1, 3
    elsif single_issue = 0                                     and
          v_rd_eq(r, x, nlane, rfa1)                           and
          v_fusel_eq(r, x, nlane, MUL or ALU or FPU
          ) and
          (slane xor swap) = '1' then
      op1       := "010";
    -- Get value from late ALU:
    -- lane | stage | instr
    --   0  |   wb  | ld x1, 0(x2)
    --   1  |   wb  | addi x2, x1, 3
    --   0  |   x   | add x1, x2, x0
    --   1  |   x   | ...
    elsif single_issue = 0 and
          v_rd_eq(r, wb, one, rfa1) then
      op1       := "011";
    elsif v_rd_eq(r, wb, 0, rfa1) then
      op1       := "100";
    end if;


    op1_out := op1(op1_out'range);
  end;

  -- Limited version of xc_alu_forwarding
  -- Used when only CSRs do calculations in exception stage.
  procedure xc_csr_forwarding(r       : in  registers;
                              lane    : in  lanes_range;
                              op1_out : out wordx) is
    variable rfa1     : rfa_tuple   := rfa(1, x, lane);
    -- Non-constant
    variable forw_op1 : word3       := r.x.alupreforw1(lane);
    variable op1      : wordx       := r.x.alu(lane).op1;
    variable nlane    : lanes_range := 0;
    variable slane    : std_ulogic  := '0';
  begin
    -- Revert back to old code (to synthesize with Synplify).
    if NO_PREFORWARD then
      xc_csr_preforward(r, lane, forw_op1);
    end if;

    -- Late forward from Load or Mul/Div operations in the other lane
    -- bit 1 -> forward from that stage
    -- bit 0 -> which lane to forward

    if single_issue = 0 then
      -- nlane: integer representing the other lane
      -- slane: bit representing this lane
      nlane   := 1;
      slane   := '0';
      if lane = 1 then
        nlane := 0;
        slane := '1';
      end if;
    end if;

    -- Op1 Forwarding Signals
    -- Do not forward from same instructions.
    -- Do not forward ahead of time.
    -- Get value from load:
    -- lane | stage | instr
    --   0  |   x   | ld x1, 0(x2)
    --   1  |   x   | addi x2, x1, 3
    -- Get value from execute ALU:
    -- lane | stage | instr
    --   0  |   x   | add x1, x2, x0
    --   1  |   x   | addi x2, x1, 3
    -- Get value from late ALU:
    -- lane | stage | instr
    --   0  |   wb  | ld x1, 0(x2)
    --   1  |   wb  | addi x2, x1, 3
    --   0  |   x   | add x1, x2, x0
    --   1  |   x   | ...

    -- Op1 First Stage Mux
    case forw_op1 is
    when "001"  => op1 := r.x.rdata(wordx'range);
    when "010"  => op1 := r.x.result(nlane);
    when "011"  => op1 := r.wb.wdata(one);
    when "100"  => op1 := r.wb.wdata(0);
    when others =>
    end case;

    op1_out := op1;
  end;

  -- ALUs Forwarding Unit
  procedure a_alu_forwarding(r           : in  registers;
                             lane        : in  lanes_range;
                             ex_data_in  : in  wordx_lanes_type;
                             ex0_rdv_in  : in  std_ulogic;
                             ex1_rdv_in  : in  std_ulogic;
                             xc_data_in  : in  wordx_lanes_type;
                             mul_data_in : in  wordx_lanes_type;
                             rf1_in      : in  wordx;
                             rf2_in      : in  wordx;
                             forw_out    : out std_logic_vector;
                             op1_out     : out wordx;
                             op2_out     : out wordx) is
    variable rfa1           : rfa_tuple := rfa(1, a, lane);
    variable rfa2           : rfa_tuple := rfa(2, a, lane);
    variable rfa            : rfa_duo   := (1 => rfa1, 2 => rfa2);
    variable ex_rdv         : word2     := (1 => ex1_rdv_in, 0 => ex0_rdv_in);
    -- This would be nicer with just (rfa'range),
    -- but for some reason Vivado XSIM 2018.1 is then likely to crash.
    subtype  op_data_t     is wordx_arr(rfa'low to rfa'high);
    variable rf_in          : op_data_t := (1 => rf1_in, 2 => rf2_in);
    -- Non-constant
    type     reg_fwd_t     is array (rfa'range) of std_logic_vector(0 to 7);
    variable fwd            : reg_fwd_t := ((others => '0'), (others => '0'));
    variable data           : wordx_arr(0 to 7)           := (others => (others => '0'));
    variable mux_data       : op_data_t;
    variable output_data    : op_data_t;
    variable stage1         : std_logic_vector(rfa'range) := (others => '0');
    variable fwd_hi_mask    : boolean;
  begin
    -- Create priority ordered list of forwarding possibilities.
    for op in rfa'range loop
      fwd_hi_mask          := false;
      for i in lanes'range loop
        fwd(op)(1 - i)     := to_bit(v_rd_eq_xrdv(r, e,  i, ex_rdv(i), rfa(op)));
        -- Special handling due to no direct load forwarding.
        if i /= memory_lane then
          fwd(op)(3 - i)   := to_bit(v_rd_eq(r, m, i, rfa(op)));
        elsif v_rd_eq(r, m, memory_lane, rfa(op)) then
          -- No lower priority forwarding even if none from here!
          fwd_hi_mask      := true;
          -- Do not forward directly from cache access.
          -- Handled by forwarding in next cycle instead.
          fwd(op)(3 - i)   := not to_bit(v_fusel_eq(r, m, memory_lane, LD));
        end if;
        fwd(op)(5 - i)     := to_bit(v_rd_eq(r, x, i, rfa(op)));
        fwd(op)(7 - i)     := to_bit(v_rd_eq(r, wb, i, rfa(op)));
      end loop;
      if fwd_hi_mask then
        fwd(op)(4 to 7)  := "0000";
      end if;
    end loop;

    -- Create mux list in the same order as above.
    for i in lanes'range loop
      data(1 - i)     := ex_data_in(i);       -- Execute stage
      if v_fusel_eq(r, m, i, MUL) then        -- Memory stage
        data(3 - i)   := mul_data_in(i);
      else
        data(3 - i)   := r.m.result(i);
      end if;
      if i = memory_lane and                  -- Exception stage
         v_fusel_eq(r, x, memory_lane, LD) then
        data(5 - i)   := r.x.rdata(wordx'range);
      else
        if r.x.alu(i).lalu = '1' then
          data(5 - i) := xc_data_in(i);
        else
          data(5 - i) := r.x.result(i);
        end if;
      end if;
      data(7 - i)     := r.wb.wdata(i);       -- Write-back
    end loop;

    -- First stage mux
    for op in rfa'range loop
      if    op = 1 and
            r.a.pcv(lane) = '1' then
        mux_data(op)    := pc2xlen(r.a.ctrl(lane).pc);
        stage1(op)      := '1';
--        debuglog("a" & tost(op));
      elsif op = 2 and      -- True even with zimm, but do not forward imm generated from Branch.
            r.a.immv(lane) = '1' and opcode(r.a.ctrl(lane).inst) /= OP_BRANCH then
        mux_data(op)     := r.a.imm(lane);
        stage1(op)       := '1';
--        debuglog("b" & tost(op));
      elsif fwd(op)(0 to 1) = "00" then       -- Not execute stage forwarding?
        for i in 2 to 7 loop                  --  Check the rest in priority order!
          if fwd(op)(i) = '1' then
            mux_data(op) := data(i);
            stage1(op)   := '1';
--            debuglog("c" & tost(op) & tost(i));
            exit;
          end if;
        end loop;
      end if;
    end loop;

    -- Second stage mux
    for op in rfa'range loop
      if stage1(op) = '1' then
        output_data(op)    := mux_data(op);
--        debuglog("p" & tost(op));
      elsif fwd(op)(0) = '1' then
        output_data(op)    := data(0);
--        debuglog("q" & tost(op));
      elsif fwd(op)(1) = '1' then
        output_data(op)    := data(1);
--        debuglog("r" & tost(op));
      else
        output_data(op)    := rf_in(op);
--        debuglog("s" & tost(op));
      end if;
    end loop;


    op1_out       := output_data(1);
    op2_out       := output_data(2);
    forw_out(1)   := not all_0(fwd(1));
    forw_out(2)   := not all_0(fwd(2));

  end;

  -- Jump Unit Forwarding
  -- Checks for and does forwarding that is known when in the register file access stage.
  -- Since the instruction has been issued, it is known that the proper value is
  -- available somewhere. It is only a matter of finding the most recent destination.
  --
  -- forw_out - 1 if forwarding is completed, 0 - means work is yet to be done.
  procedure a_jump_forwarding(r           : in  registers;
                              lane        : in  lanes_range;
                              ex_data_in  : in  wordx_lanes_type;
                              ex0_rdv_in  : in  std_ulogic;
                              ex1_rdv_in  : in  std_ulogic;
                              xc_data_in  : in  wordx_lanes_type;
                              mul_data_in : in  wordx_lanes_type;
                              rf1_in      : in  wordx;
                              forw_out    : out std_logic_vector;
                              op1_out     : out wordx) is
    variable rfa1           : rfa_tuple := rfa(1, a, lane);
    -- Non-constant
    variable op1            : wordx;
    variable mux_output_op1 : wordx;
    variable wb_forw_op1    : word2     := "00";
    variable xc_forw_op1    : word2     := "00";
    variable mem_forw_op1   : word2     := "00";
    variable ex_forw_op1    : word2     := "00";
  begin
    -- Compute mux forwarding signals
    -- bit(1) indicates forwarding should happen from that stage
    -- bit(0) indicates from which lane the data should be forwarded

    -- Op1
    if    single_issue = 0 and
          v_rd_eq_xrdv(r, e,  one, ex1_rdv_in, rfa1) then
      ex_forw_op1       := "11";
    elsif v_rd_eq_xrdv(r, e,  0, ex0_rdv_in, rfa1) then
      ex_forw_op1       := "10";
    elsif single_issue = 0 and
          v_rd_eq(r, m,  one, rfa1) then
      mem_forw_op1      := "11";
    elsif v_rd_eq(r, m,  0, rfa1) then
      -- Do not forward directly from cache access.
      -- Handled by forwarding in next cycle instead.
      if not v_fusel_eq(r, m, memory_lane, LD) then
        mem_forw_op1    := "10";
      end if;
    elsif single_issue = 0 and
          v_rd_eq(r, x,  one, rfa1) then
      xc_forw_op1       := "11";
    elsif v_rd_eq(r, x,  0, rfa1) then
      xc_forw_op1       := "10";
    elsif single_issue = 0 and
          v_rd_eq(r, wb, one, rfa1) then
      wb_forw_op1       := "11";
    elsif v_rd_eq(r, wb, 0, rfa1) then
      wb_forw_op1       := "10";
    end if;

    -- First Stage Mux for Op1
    if xc_forw_op1 = "10" then
      if v_fusel_eq(r, x, 0, LD) then
        mux_output_op1  := r.x.rdata(wordx'range);
      else
        if r.x.alu(0).lalu = '1' then
          mux_output_op1:= xc_data_in(0);
        else
          mux_output_op1:= r.x.result(0);
        end if;
      end if;
    elsif single_issue = 0 and
          xc_forw_op1 = "11" then
      if r.x.alu(one).lalu = '1' then
        mux_output_op1  := xc_data_in(one);
      else
        mux_output_op1  := r.x.result(one);
      end if;
    elsif mem_forw_op1 = "10" then
      if v_fusel_eq(r, m, 0, MUL) then
        mux_output_op1  := mul_data_in(0);
      else
        mux_output_op1  := r.m.result(0);
      end if;
    elsif single_issue = 0 and
          mem_forw_op1 = "11" then
      if v_fusel_eq(r, m, one, MUL) then
        mux_output_op1  := mul_data_in(one);
      else
        mux_output_op1  := r.m.result(one);
      end if;
    elsif wb_forw_op1 = "10" then
      mux_output_op1    := r.wb.wdata(0);
    elsif single_issue = 0 and
          wb_forw_op1 = "11" then
      mux_output_op1    := r.wb.wdata(one);
    end if;

    -- Second Stage Mux for Op1
    if xc_forw_op1(1) = '1' or mem_forw_op1(1) = '1' or wb_forw_op1(1) = '1' then
      op1               := mux_output_op1;
    elsif ex_forw_op1 = "11" then
      op1               := ex_data_in(one);
    elsif ex_forw_op1 = "10" then
      op1               := ex_data_in(0);
    else
      op1               := rf1_in;
    end if;

    op1_out             := op1;
    -- Was any forwarding done to op1?
    forw_out(1)         := ex_forw_op1(1) or mem_forw_op1(1) or xc_forw_op1(1) or wb_forw_op1(1);
    forw_out(2)         := '0';  -- Unused, but needs a value.
  end;

  -- Data Cache Gen
  procedure dcache_gen(inst_in     : in  word;
                       fusel_in    : in  fuseltype;
                       valid_in    : in  std_ulogic;
                       misaligned  : in  std_ulogic;
                       dfeaturesen : in  csr_dfeaturesen_type;
                       prv_in      : in  priv_lvl_type;
                       v_in        : in  std_ulogic;
                       mprv_in     : in  std_ulogic;
                       mpv_in      : in  std_ulogic;
                       mpp_in      : in  priv_lvl_type;
                       mxr_in      : in  std_ulogic;
                       sum_in      : in  std_ulogic;
                       spvp_in     : in  std_ulogic;
                       vmxr_in     : in  std_ulogic;
                       vsum_in     : in  std_ulogic;
                       wpnull_out  : out std_ulogic;
                       dci_out     : out dcache_in_type) is
    variable funct3 : funct3_type    := funct3(inst_in);
    -- Non-constant
    variable x0_rs1 : std_ulogic;
    variable x0_rs2 : std_ulogic;
    variable wpnull : std_ulogic := '0';
    variable dci    : dcache_in_type := dcache_in_none;
  begin
    x0_rs1 := all_0(rs1(inst_in));  -- Vivado XSIM 2018.1 does not like these
    x0_rs2 := all_0(rs2(inst_in));  -- in the variable declaration above, for some reason.

    -- Drive Cache Signal
    dci.signed  := not funct3(2);   -- Used in IUNV to sign extend read data
    dci.size    := funct3(1 downto 0);
    -- During normal operation, the LEON5 processor accesses instructions
    -- and data using ASI 0x8 - 0xB, so we do the same.
    dci.asi     := x"0A";

    dci.mxr     := mxr_in;
    dci.vmxr    := vmxr_in;
    dci.vms     := v_in & prv_in;
    if mprv_in = '1' then -- M-mode is assumed
      dci.vms   := mpv_in & mpp_in;
    end if;

    dci.hx      := '0';
    dci.sum     := '0';
    if prv_in = PRIV_LVL_S or                       -- HS-mode or VS-mode
       (mprv_in = '1' and mpp_in = PRIV_LVL_S) then -- M-mode, access as through HS-mode or VS-mode
      if ext_h /= 0 and (v_in = '1' or (mprv_in and mpv_in) = '1') then
        dci.sum := vsum_in;
      else
        dci.sum := sum_in;
      end if;
    end if;
    if ext_h /= 0 and is_hlsv(inst_in) then
      dci.vms   := "10" & spvp_in;
      dci.sum   := vsum_in;
      dci.hx    := to_bit(is_hlvx(inst_in));
    end if;

    if valid_in = '1' then
      if v_fusel_eq(fusel_in, LD or ST) and misaligned = '0' then
        dci.enaddr      := '1';
        dci.write       := to_bit(v_fusel_eq(fusel_in, ST));
        dci.read        := to_bit(v_fusel_eq(fusel_in, LD));
        dci.amo         := (others => '0');
        if ext_a /= 0 and v_fusel_eq(fusel_in, AMO) then
          dci.amo       := '1' & inst_in(31 downto 27);
          if ext_zicfiss = 1 and v_fusel_eq(fusel_in, CFI) then
            dci.amo     := '1' & R_AMOSWAP;
          end if;
          if inst_in(28) = '1' then   -- LRSC
            if inst_in(27) = '0' then -- LR
            else                      -- SC
              -- The fusel code for SC has both LD and SD set, so clear read here!
              -- The reason is that SC returns a value from cctrl, even though
              -- it did not actually read that value from memory.
              dci.read  := '0';
              dci.lock  := '1';
            end if;
          else                        -- AMO
            dci.lock    := '1';
          end if;
        end if;
        if ext_zicfiss = 1 and v_fusel_eq(fusel_in, CFI) then
          dci.ss        := '1';
          if not v_fusel_eq(fusel_in, AMO) then
            dci.size    := cond(XLEN = 64, "11", "10");
          end if;
        end if;
        if ext_h /= 0 and is_hlsv(inst_in) then
          dci.signed      := not inst_in(20);
          dci.size        := inst_in(27 downto 26);
        end if;
        if ext_noelv /= 0 and v_fusel_eq(fusel_in, DIAG) then
          if is_diag_store(inst_in) then
            dci.asi     := to_asi_store(inst_in);
          else
            dci.asi     := to_asi_load(inst_in);
          end if;
        end if;
      -- We encode a fence_i instruction in an instruction
      -- that flushes and enables both caches.
--      elsif is_fence_i(inst_in) then
--        dci.asi         := x"02";
--        dci.write       := '1';
--        dci.enaddr      := '1';
--        dci.size        := "10";
      -- We encode an sfence.vma instruction in an instruction that flushes the
      -- (v)sITLB and (v)sDTLB entries matching address and ASID, if requested,
      -- and always current VMID if vs.
      elsif is_sfence_vma(active_extensions, inst_in) then
        dci.asi         := x"1B";
        dci.vms(0)      := x0_rs1;
        dci.vms(1)      := x0_rs2 or to_bit(asidlen = 0);
        dci.vms(2)      := v_in;
        -- While the standard is not entirely clear, IMHO, it seems to
        -- want sfence.vma from machine mode to only touch (H)S TLBs (not VS).
        -- An option could have been to have it look at mstatus.mpv.
        if prv_in = PRIV_LVL_M then
          dci.vms(2)    := '0';    -- Not mpv_in, apparently.
        end if;
        dci.write       := '1';
        dci.enaddr      := '1';
        dci.size        := "00";   -- sfence.vma
        wpnull          := '1';    -- Watchpoint should not match in this case
      -- We encode an hfence.vvma instruction in an instruction that flushes the
      -- vsITLB and vsDTLB entries matching address and ASID, if requested,
      -- and always current VMID.
      elsif ext_h = 1 and is_hfence_vvma(active_extensions, inst_in) then
        dci.asi         := x"1B";
        dci.vms(0)      := x0_rs1;
        dci.vms(1)      := x0_rs2 or to_bit(asidlen = 0);
        dci.vms(2)      := '1';
        dci.write       := '1';
        dci.enaddr      := '1';
        dci.size        := "01";   -- hfence.vvma
        wpnull          := '1';    -- Watchpoint should not match in this case
      -- We encode an hfence.gvma instruction in an instruction that flushes the
      -- hTLB entries matching address and VMID, if reqeusted, and also the
      -- vsITLB and vsDTLB entries matching the VMID, if requested (no address check
      -- possible since the ITLB and DTLB contain only direct mappings to physical addresses).
      elsif ext_h = 1 and is_hfence_gvma(active_extensions, inst_in) then
        dci.asi         := x"1B";
        dci.vms(0)      := x0_rs1;
        dci.vms(1)      := x0_rs2 or to_bit(vmidlen = 0);
        dci.vms(2)      := '1';
        dci.write       := '1';
        dci.enaddr      := '1';
        dci.size        := "10";   -- hfence.gvma
        wpnull          := '1';    -- Watchpoint should not match in this case
      elsif ext_zicbom = 1 and is_cbo(inst_in) and inst_in(20) = '0' then -- Clean = NOP, inval/flush = inval
        dci.cbo         := "100";
        dci.write       := '0';
        dci.read        := '1';
        dci.enaddr      := '1';
        dci.size        := "10";
      end if;
    end if;

    wpnull_out := wpnull;
    dci_out    := dci;
  end;

  -- Data Cache Memmory Barrier Gen
  procedure mem_bar_gen(inst_in  : in  word;
                        fusel_in : in  fuseltype;
                        valid_in : in  std_ulogic;
                        bar_out  : out std_logic_vector(2 downto 0)) is
    -- Non-constant
    variable bar : std_logic_vector(2 downto 0) := "000";
  begin
    if valid_in = '1' then
      if v_fusel_eq(fusel_in, LD or ST) then
        if ext_a /= 0 and v_fusel_eq(fusel_in, AMO) then
          bar := '0' & inst_in(26 downto 25);
        end if;
      elsif is_fence(inst_in) then -- fence instruction
        bar   := "011";
      end if;
    end if;

    bar_out := bar;
  end;

  -- Load aligner
  function ld_align_fast(data   : dcdtype;
                         way    : std_logic_vector(DWAYMSB downto 0);
                         size   : word2;
                         laddr  : word3;
                         signed : std_ulogic) return word64 is
    constant original : boolean := true;
    -- Non-constant
    variable rdata    : dcdtype;
    variable data64   : word64 := data(u2i(way));
  begin
    if original then
      -- Extract data separately for each way, before selecting one.
      -- Could improve timing if the way is known late.
      for i in 0 to dways - 1 loop
        rdata(i) := ld_align64(data(i), size, laddr, signed);
      end loop;
      return rdata(u2i(way));
    else
      -- Extract data after selecing way.
      -- Could improve timing due to smaller implementation.
      return ld_align64(data64, size, laddr, signed);
    end if;
  end;

  -- Generate data to store
  procedure stdata_unit(r        : in  registers;
                        data_out : out word64) is
    variable inst      : word        := r.m.ctrl(memory_lane).inst;
    variable op        : opcode_type := opcode(inst);
    variable rfa2      : reg_t       := rs2(inst);
    -- Hypervisor store instruction
    variable hsv       : boolean     := (ext_h /= 0) and is_hsv(inst);
    -- Non-constant
    variable data      : word64      := to64(r.m.stdata);
    variable mvalid    : std_ulogic  := '1';
    variable mdata     : wordx;
  begin
    -- Opt for a 2 stage mux

    -- Forwarding Logic
    -- A LOAD, which could cause a lane swap, is guaranteed by dual_issue_check()
    -- to not be paired with anything that has the same destination.
    if    v_fusel_eq(r, x, 0, LD)  and v_rd_eq(r, x, 0, rfa2) then
      mdata     := r.x.rdata(wordx'range);
    elsif single_issue = 0 and
          v_fusel_eq(r, x, one, MUL or FPU) and v_rd_eq(r, x, one, rfa2) then
      mdata     := r.x.result(one);
    elsif v_fusel_eq(r, x, 0, MUL or FPU) and v_rd_eq(r, x, 0, rfa2) and
          (single_issue = 1 or not v_rd_eq(r, x, one, rfa2)) then
      mdata     := r.x.result(0);
    -- Forward from late ALUs or late Results
    elsif single_issue = 0 and
          (r.wb.lalu(one) = '1' or v_fusel_eq(r, wb, one, MUL or FPU)) and
          v_rd_eq(r, wb, one, rfa2) and r.m.stforw(0) = '0' then
      mdata     := r.wb.wdata(one);
    elsif (r.wb.lalu(0) = '1' or v_fusel_eq(r, wb, 0, MUL or LD or FPU)) and
          v_rd_eq(r, wb, 0, rfa2) and r.m.stforw(0) = '0' then
      mdata     := r.wb.wdata(0);
    else
      mvalid    := '0';
      mdata     := zerox;
    end if;

    -- Forward from (non-late) ALU in same stage (swapped)
    if single_issue = 0 and
       v_fusel_eq(r, m, one, ALU
       ) and v_rd_eq(r, m, one, rfa2) and r.m.swap = '1' then
      data      := to64(r.m.result(one));
    -- Forward from something above?
    elsif mvalid = '1' then
      data      := to64(mdata);
    end if;

    if op = OP_STORE_FP then
      data      := r.m.fpdata;
    end if;

    -- Replicate word/halfword/byte
    -- If xxIDs are <= 8 bits, it is fine to do this for TLB fences as well,
    -- but otherwise not since r.m.dci.size is used to mark type of such fence.
    if (asidlen <= 8 and (ext_h = 0 or vmidlen <= 8)) or
       not is_tlb_fence(active_extensions, inst) then
      case r.m.dci.size is
      when SZWORD =>
        data(63 downto 32) := data(31 downto 0);
      when SZHALF =>
        data(63 downto 48) := data(15 downto 0);
        data(47 downto 32) := data(15 downto 0);
        data(31 downto 16) := data(15 downto 0);
      when SZBYTE =>
        data(63 downto 56) := data(7 downto 0);
        data(55 downto 48) := data(7 downto 0);
        data(47 downto 40) := data(7 downto 0);
        data(39 downto 32) := data(7 downto 0);
        data(31 downto 24) := data(7 downto 0);
        data(23 downto 16) := data(7 downto 0);
        data(15 downto 8)  := data(7 downto 0);
      when others =>
        null;
      end case;
    end if;

--    if is_fence_i(r.m.ctrl(0).inst) then
--      data(31 downto 0)  := x"0081000f";
--      data(63 downto 32) := x"0081000f";
--    end if;

    -- Hold data in case of holdn from cache
    if holdn = '0' then
      data   := r.x.wdata;
    end if;

    data_out := data;
  end;


  -- Memory Stage Exception Handling
  procedure me_exceptions(ctrl_in            : in  pipeline_ctrl_lanes_type;
                          ret_out            : out word2;
                          nret_out           : out std_ulogic;
                          xc_out             : out lanes_type;
                          cause_out          : out cause_lanes_type;
                          tval_out           : out wordx_lanes_type) is
    -- Non-constant
    variable xc    : lanes_type;
    variable cause : cause_lanes_type;
    variable tval  : wordx_lanes_type;
    variable ret   : word2 := (others => '0');
    variable nret  : std_ulogic := '0';
  begin
    for i in lanes'range loop
      xc(i)          := ctrl_in(i).xc;
      cause(i)       := ctrl_in(i).cause;
      tval(i)        := ctrl_in(i).tval;
    end loop;


    -- Evaluate Trap-Return Instructions
    for i in lanes'range loop
      if ctrl_in(i).xc = '0' and ctrl_in(i).valid = '1' then
        if is_xret(ctrl_in(i).inst) then
          if    funct7(ctrl_in(i).inst) = F7_SRET then
            xc(i)    := '1';
            cause(i) := check_cause_update(XC_INST_ENV_CALL_SMODE, cause(i));
            tval(i)  := zerox;
            ret      := "01";
          elsif funct7(ctrl_in(i).inst) = F7_MRET then
            xc(i)    := '1';
            cause(i) := check_cause_update(XC_INST_ENV_CALL_MMODE, cause(i));
            tval(i)  := zerox;
            ret      := "11";
          elsif ext_smrnmi = 1 and funct7(ctrl_in(i).inst) = F7_MNRET then
            xc(i)    := '1';
            cause(i) := check_cause_update(XC_INST_ENV_CALL_MMODE, cause(i));
            tval(i)  := zerox;
            ret      := "11";
            nret     := '1';
          end if;
        end if;
      end if;
    end loop;

    -- Drive outputs
    xc_out           := xc;
    cause_out        := cause;
    tval_out         := tval;
    ret_out          := ret;
    nret_out         := nret;
  end;

  -- Nullify for DCache
  -- Must nullify when
  -- - A branch was found in EXC to be mispredicted (r.wb...)
  --    Requires a following load to have been marked as speculative!
  --     That is, result from cache if possible, but no AHB started.
  --    There can be no following write!
  -- -
  procedure null_dcache_gen(xc_flush_in : in  std_ulogic;
                            me_xc_in    : in  lanes_type;
                            mem_branch  : in  std_ulogic;
                            valid_in    : in  lanes_type;
                            swap_in     : in  std_ulogic;
                            nullify_out : out std_ulogic) is
    -- Non-constant
    variable nullify : std_ulogic := '0';
  begin
    if xc_flush_in = '1'                         or       -- flush from xc
       mem_branch = '1'                          or       -- mem branch mispredict
       (me_xc_in(0) = '1' and valid_in(0) = '1') or       -- xc in LD/ST op
       (single_issue = 0 and                              -- xc in previous instruction
        swap_in = '1' and valid_in(one) = '1' and me_xc_in(one) = '1') then
      nullify   := '1';
    end if;

    nullify_out := nullify;
  end;

  -- Generate data to the Regfile
  procedure wbdata_gen(lane     : in  integer range lanes'range;
                       fusel_in : in  fuseltype;
                       alu_in   : in  std_ulogic;
                       lalu_in  : in  std_ulogic;
                       res_in   : in  wordx;
                       csrv_in  : in  std_ulogic;
                       cres_in  : in  wordx;
                       lres_in  : in  wordx;
                       ldata_in : in  word64;
                       data_out : out wordx) is
    -- Non-constant
    variable data : wordx := res_in;
  begin
    -- No need to mux these for any other lane.
    if lane = memory_lane then
      -- Select data from Load operation
      if v_fusel_eq(fusel_in, LD or AMO) then
        data    := ldata_in(wordx'range);
      end if;
    end if;
    if lane = csr_lane then
      -- CSR read values are available in cres.
      if csrv_in = '1'
         -- Not for SSPUSH / SSPOP
         and not (v_fusel_eq(fusel_in, CFI) and v_fusel_eq(fusel_in, LD or ST))
         then
        data    := cres_in;
      end if;
    end if;

    -- Drive data from Late ALUs
    if late_alu = 1 then
      if (alu_in and lalu_in) = '1' then
        if csrv_in = '0' then
          data  := lres_in;
        end if;
      end if;
    end if;

    data_out    := data;
  end;

  -- Interrupt/Exception triggers
  function trigger_itrigger_match(tdata1 : wordx;
                                  tdata2 : wordx;
                                  nmirq  : std_ulogic;
                                  cause  : cause_type) return std_logic is
    variable match : std_ulogic := '0';
  begin
    if nmirq = '1' then
      match := tdata1(10);
    else
      match := tdata2(cause.code);
    end if;
    return match;
  end;

  function trigger_etrigger_match(tdata2 : wordx;
                                  cause  : cause_type) return std_logic is
  begin
    return tdata2(cause.code);
  end;


  -- Trigger extra (Textra) match check
  function trigger_textra_match(tdata3    : wordx;
                                mhcontext : csr_mhcontext_type;
                                scontext  : csr_scontext_type;
                                hgatp     : atp_type;
                                satp      : atp_type;
                                vsatp     : atp_type;
                                vmode     : std_logic) return std_logic is
    variable X64       : integer := b2i(XLEN = 64);
    -- Non-constant
    -- tdata3
    variable mhvalue   : std_logic_vector(12 downto 0);
    variable mhselect  : std_logic_vector(2 downto 0);
    variable sbytemask : std_logic_vector(4 downto 0);
    variable sselect   : std_logic_vector(1 downto 0) := tdata3(1 downto 0);
    variable svalue    : std_logic_vector(33 downto 0);
    -- sgatp
    variable ASID      : std_logic_vector(15 downto 0);
    -- match
    variable mhmatch   : std_logic := '0';
    variable smatch    : std_logic := '0';
  begin

    if XLEN = 64 then
      mhvalue(12 * X64 downto 0)  := tdata3(63 * X64 downto 51 * X64);
      mhselect(2 * X64 downto 0)  := tdata3(50 * X64 downto 48 * X64);
      case mhselect(1 downto 0) is
        when "00" =>
          if mhselect(2) = '0' or mhvalue = mhcontext(12 downto 0) then
            mhmatch := '1';
          end if;
        when "01" =>
          if (mhvalue & mhselect(2)) = mhcontext then
            mhmatch := '1';
          end if;
        when "10" =>
          if get_right(mhvalue & mhselect(2), vmidlen) = get_right(hgatp.id, vmidlen) and
             all_0(get_left(mhvalue & mhselect(2), -vmidlen)) then
            mhmatch := '1';
          end if;
        when others =>
      end case;

      sbytemask(4 * X64 downto 0) := tdata3(40 * X64 downto 36 * X64);
      svalue(33 * X64 downto 0)   := tdata3(35 * X64 downto 2 * X64);
      case sselect is
        when "00" =>
          smatch := '1';
        when "01" =>
          smatch := '1';
          for i in 0 to 3 loop
            if sbytemask(i) = '0' and
               svalue((i + 1) * 8 - 1 downto i * 8) /= scontext((i + 1) * 8 - 1 downto i * 8) then
              smatch := '0';
            end if;
          end loop;
        when "10" =>
          if vmode = '1' then
            ASID := vsatp.id;
          else
            ASID := satp.id;
          end if;
          if ASID = svalue(15 downto 0) then
            smatch := '1';
          end if;
        when others =>
      end case;
    else
      mhvalue(5 downto 0)  := tdata3(31 downto 26);
      mhselect := tdata3(25 downto 23);
      case mhselect(1 downto 0) is
        when "00" =>
          if mhselect(2) = '0' or mhvalue(5 downto 0) = mhcontext(5 downto 0) then
            mhmatch := '1';
          end if;
        when "01" =>
          if (mhvalue(5 downto 0) & mhselect(2)) = mhcontext(6 downto 0) then
            mhmatch := '1';
          end if;
        when "10" =>
          if get_right(mhvalue(5 downto 0) & mhselect(2), vmidlen) = get_right(hgatp.id, vmidlen) and
             all_0(get_left(mhvalue & mhselect(2), -vmidlen)) then
            mhmatch := '1';
          end if;
        when others =>
      end case;

      sbytemask(1 downto 0) := tdata3(19 downto 18);
      svalue(15 downto 0)   := tdata3(17 downto 2);
      case sselect is
        when "00" =>
          smatch := '1';
        when "01" =>
          smatch := '1';
          for i in 0 to 1 loop
            if sbytemask(i) = '0' and
               svalue((i + 1) * 8 - 1 downto i * 8) /= scontext((i + 1) * 8 - 1 downto i * 8) then
              smatch := '0';
            end if;
          end loop;
        when "10" =>
          if vmode = '1' then
            ASID := vsatp.id;
          else
            ASID := satp.id;
          end if;
          if ASID = uext(svalue(8 downto 0), ASID) then
            smatch := '1';
          end if;
        when others =>
      end case;
    end if;

    return mhmatch and smatch;
  end;

  function trigger_valid(prv   : priv_lvl_type;
                         v     : std_logic;
                         tdata : wordx) return std_logic is
    variable typ       : word4    := tdata(tdata'high downto tdata'high - 3);
    variable prvi      : integer4 := u2i(prv);
    variable vi        : integer2 := u2i(v);
    -- Non-constant
    variable valid : std_logic;
  begin
    valid     := '0';
    case typ is
      when "0000" | "1111" =>
        valid := '0';
      when "0001" =>
        valid := '0';
      when "0010" =>           -- MCONTROL
        valid := tdata(3 + prvi);
      when "0110" =>           -- MCONTROL6
        if v = '0' then
          valid := tdata(3 + prvi);
        else
          valid := tdata(23 + prvi);
        end if;
      when "0011" =>           -- ICOUNT
        if v = '0' then
          valid := tdata(6 + prvi);
        else
          valid := tdata(25 + prvi);
        end if;
      when "0100" | "0101" =>  -- ITRIGGER or ETRIGGER
        if v = '0' then
          valid := tdata(6 + prvi);
        else
          valid := tdata(11 + prvi);
        end if;
      when others =>
        valid := '0';
    end case;

    return valid;
  end;

  -- It should not be possible for triggers to fire in the same mode that
  -- the resulting exception will be handled in. In that case mepc and mcause
  -- would be overwritten.
  function trigger_reentrancy(csr       : csr_reg_type;
                              tdata1_ic : wordx) return boolean is
    variable valid : boolean := false;
  begin
    if not ((csr.prv = PRIV_LVL_M and csr.mstatus.mie = '0') or
            (csr.prv = PRIV_LVL_S and csr.mstatus.sie = '0' and csr.v = '0' and csr.medeleg(3) = '1') or
            (csr.prv = PRIV_LVL_S and (csr.v and csr.medeleg(3) and csr.hedeleg(3)) = '1' and csr.vsstatus.sie = '0')) then
      valid := true;
    end if;
    return valid;
  end;

  -- Exception Management
  procedure exception_unit(r              : in  registers;
                           cfi_en         : in  cfi_t;
                           popchk_eq      : in  std_ulogic;
                           lpad           : in  std_ulogic;
                           lpad_fail      : in  std_ulogic;
                           fence_in       : in  std_ulogic;
                           swap_in        : in  std_ulogic;
                           fetch_v_in     : in  std_ulogic;
                           access_v_in    : in  std_ulogic;
                           int_in         : in  lanes_type;
                           ie_trig_in     : in  ie_trig_type;
                           trigxc_in      : in  trig_exception_type;
                           lbnull_in      : in  std_ulogic;
                           xcs_out        : out lanes_type;
                           causes_out     : out cause_lanes_type;
                           tvals_out      : out wordx_lanes_type;
                           ret_out        : out word2;
                           nret_out       : out std_ulogic;
                           xc_out         : out std_ulogic;
                           xc_lane_out    : out std_ulogic;
                           irq_taken      : out word2;
                           nmirq_taken    : out std_ulogic;
                           cause_out      : out cause_type;
                           tval_out       : out wordx;
                           tval2_out      : out wordx;
                           gva_out        : out std_ulogic;
                           flush_out      : out lanes_type;
                           pc_out         : out pctype;
                           inst_out       : out word;
                           elp_out        : out std_ulogic;
                           ie_trig_out    : out ie_trig_type;
                           ie_trig_taken  : out lanes_type;
                           xc_bt_out      : out std_ulogic;
                           xc_bt_cause    : out cause_type;
                           trigxc_out     : out trig_exception_type;
                           trig_flushall  : out std_ulogic;
                           ebreak_action0 : out std_ulogic;
                           trig_taken     : out std_ulogic;
                           clr_trig       : out std_ulogic) is
    -- Non-constant
    variable xc        : std_ulogic   := '0';
    variable cause     : cause_type   := cause_none;
    variable xcs       : lanes_type;
    variable causes    : cause_lanes_type;
    variable tvals     : wordx_lanes_type;
    variable pc        : pctype       := PC_ZERO;
    variable inst      : word         := (others => '0');
    variable gva       : std_ulogic   := '0';
    variable tval      : wordx        := zerox;
    variable tval2     : wordx        := zerox;
    variable ret       : word2        := r.x.ret;
    variable nret      : std_ulogic   := r.x.nret;
    variable flush     : word2        := "00";
    variable xc_lane   : std_ulogic   := '0';
    variable nmirq     : std_ulogic   := '0';
    variable cfi_xc    : boolean;
    variable elp       : std_ulogic   := r.csr.elp;
    variable lp_lane   : lanes_range;
    variable action0   : std_ulogic   := '0';
    variable action    : wordx;
    variable tdata1    : wordx;
    variable tdata2    : wordx;
    variable tdata3    : wordx;
    variable ie_trig   : ie_trig_type := ie_trig_in;
    variable m_swap    : std_ulogic   := r.m.swap;
  begin
    irq_taken   := "00";
    trig_taken  := '0';
    ie_trig_taken := (others => '0');
    clr_trig      := '0';

    -- Check exception from previous stages
    for i in lanes'range loop
      xcs(i)    := r.x.ctrl(i).xc;
      causes(i) := r.x.ctrl(i).cause;
      tvals(i)  := r.x.ctrl(i).tval;
    end loop;


    -- Fetch page/access fault cannot have been reported yet.
    -- Check forward CFI failure to find expected landing pad
    if ext_zicfilp = 1 and lpad_fail = '1' then
      lp_lane         := u2i(r.x.swap);
      xcs(lp_lane)    := '1';
      tvals(lp_lane)  := u2vec(2, tvals(0));  -- Landing pad fault code
      causes(lp_lane) := check_cause_update(XC_INST_SOFTWARE_CHECK, causes(lp_lane), tvals(lp_lane));
    end if;

    -- Insert load/store page/access fault
    if xcs(memory_lane) = '0' and r.x.mexc = '1' then
      xcs(memory_lane)        := '1';
      if r.x.exctype = '1' then
        causes(memory_lane)   := check_cause_update(XC_INST_LOAD_ACCESS_FAULT, causes(memory_lane));
      elsif r.x.exchyper = '1' then
        causes(memory_lane)   := check_cause_update(XC_INST_LOAD_G_PAGE_FAULT, causes(memory_lane));
      else
        causes(memory_lane)   := check_cause_update(XC_INST_LOAD_PAGE_FAULT, causes(memory_lane));
      end if;
      if v_fusel_eq(r, x, memory_lane, ST) or
         -- Shadow stack instructions always throw store/AMO faults!
         (v_fusel_eq(r, x, memory_lane, CFI) and v_fusel_eq(r, x, memory_lane, LD or ST)) or
         (ext_zicbom = 1 and is_cbo(r.x.ctrl(memory_lane).inst)) then
        if r.x.exctype = '1' then
          causes(memory_lane) := check_cause_update(XC_INST_STORE_ACCESS_FAULT, causes(memory_lane));
        elsif r.x.exchyper = '1' then
          causes(memory_lane) := check_cause_update(XC_INST_STORE_G_PAGE_FAULT, causes(memory_lane));
        else
          causes(memory_lane) := check_cause_update(XC_INST_STORE_PAGE_FAULT, causes(memory_lane));
        end if;
      end if;
      tvals(memory_lane)      := r.x.address_full;
    end if;

    -- Check backward CFI failure on return address comparison
    if ext_zicfiss = 1 and cfi_en.ss then
      -- SSPOPCHK
      if r.x.ctrl(memory_lane).valid = '1' and xcs(memory_lane) = '0' and
         v_fusel_eq(r.x.ctrl(memory_lane).fusel, CFI)                 and
         v_fusel_eq(r.x.ctrl(memory_lane).fusel, LD)                  and
         not v_fusel_eq(r.x.ctrl(memory_lane).fusel, AMO) then

        -- Unless we split SSPOPCHK in decode (or similar), we need to check
        -- the equivalence between the link register read from the normal
        -- and from the shadow stack - right now.
        -- Likely to cause timing issues, unfortunately.
        if popchk_eq /= '1' then
          xcs(memory_lane)    := '1';
          tvals(memory_lane)  := u2vec(3, tvals(0));  -- Shadow stack fault code
          causes(memory_lane) := check_cause_update(XC_INST_SOFTWARE_CHECK, causes(memory_lane), tvals(memory_lane));
        end if;
      end if;
    end if;



    -- Check if we have to raise an exception due to previous stages.
    -- First instruction should be in the upper arm, but in case of a
    -- swap it is in the second arm.


    -- Select exception
    -- (Will only be raised if not flushed by fence in write back stage.)
    xc := (xcs(0)   and r.x.ctrl(0).valid) or
          (xcs(one) and r.x.ctrl(one).valid);

    -- Exception in instruction fetch order
    xc_lane     := '0';
    if single_issue = 0 then
      if swap_in = '0' then
        -- No exception in first instruction (lane 0)?
        xc_lane := not (xcs(0) and r.x.ctrl(0).valid);
      else
        -- Exception in first instruction (lane 1)?
        xc_lane := xcs(one) and r.x.ctrl(one).valid;
      end if;
    end if;

    if xc = '1' then
      pc           := r.x.ctrl(u2i(xc_lane)).pc;
      inst         := r.x.ctrl(u2i(xc_lane)).inst;
      inst(1)      := not r.x.ctrl(u2i(xc_lane)).comp;
      cause        := causes(u2i(xc_lane));
      tval         := tvals(u2i(xc_lane));
    end if;

    -- Flush line with exception, and the next if there is one.
    -- Copy of the code further down. Would not be needed, except
    -- for the mask flushing that follows here.
    if xc = '1' then
      if swap_in = '0' then
        -- Not swapped: 1st - flush both lanes, 2nd - flush lane 1 only
        flush := "1" & not xc_lane;
      else
        -- Swapped: 1st - flush both lanes, 2nd - flush lane 0 only
        flush := xc_lane & "1";
      end if;
    end if;

    -- Mask flush on:
    --
    -- control and system instructions such as mret, sret, ...
    for i in lanes'range loop
      if is_xret(r.x.ctrl(i).inst) and
         (r.x.ctrl(i).cause = XC_INST_ENV_CALL_SMODE or
          r.x.ctrl(i).cause = XC_INST_ENV_CALL_MMODE) then
        flush(i) := '0';
        xcs(i)   := '0';
      end if;
    end loop;


    -- Raise exception if interrupts, in instruction order.
    -- Interrupt overrides other exceptions here.
    -- All interrupt related checks are done in memory stage;
    -- hence no extra check needed in this stage.
    -- int_in(n) can only be set if corresponding instruction is valid.
    -- If the interrupt becomes pending when executing a WFI instruction
    -- wait for the next instruction to rise the interrupt.
    if (int_in(0) or int_in(one)) = '1' and is_irq(r.x.irqcause) then
      xc      := '1';
      causes  := (others => r.x.irqcause);
      cause   := r.x.irqcause;

      -- Needed to overwrite exception set above!
      xc_lane := '0';
      tvals   := (others => (others => '0'));
      tval    := (others => '0');
      inst    := (others => '0');

      if single_issue = 0 then
        if swap_in = '0' then
          -- No interrupt in first instruction (lane 0)?
          xc_lane := not int_in(0);
        else
          -- Interrupt in first instruction (lane 1)?
          xc_lane := int_in(one);
        end if;
      end if;

      xcs(u2i(xc_lane))       := '1';
      pc                      := r.x.ctrl(u2i(xc_lane)).pc;
      irq_taken(u2i(xc_lane)) := '1';
      nmirq                   := r.x.nmirqpend;

      -- Flush line with exception, and the next if there is one.
      if xc = '1' then
        if swap_in = '0' then
          -- Not swapped: 1st - flush both lanes, 2nd - flush lane 1 only
          flush := "1" & not xc_lane;
        else
          -- Swapped: 1st - flush both lanes, 2nd - flush lane 0 only
          flush := xc_lane & "1";
        end if;
      end if;
    -- Hypervisor handling for gva/tval2/inst output
    -- This only checks "cause" for things that are not interrupt related,
    -- and thus can not depend on assignment to "cause" in if-clause above.
    elsif ext_h /= 0 then
      -- Check for guest virtual addresses
      if    cause = XC_INST_BREAKPOINT or
            cause = XC_INST_ADDR_MISALIGNED then
        gva   := fetch_v_in;
      elsif cause = XC_INST_LOAD_ADDR_MISALIGNED or
            cause = XC_INST_STORE_ADDR_MISALIGNED then
        gva   := access_v_in;
      elsif cause = XC_INST_INST_G_PAGE_FAULT then
        gva   := fetch_v_in;
        tval2 := r.d.tval2;
        if r.d.tval2type = "01" then
          -- The value from MMU/cache controller has no knowledge of
          -- exactly what part of the word the faulting instruction
          -- was in, so copy from virtual address.
          tval2(11 - 2 downto 0) := tval(11 downto 2);
        end if;
      elsif cause = XC_INST_LOAD_G_PAGE_FAULT or
            cause = XC_INST_STORE_G_PAGE_FAULT then
        gva   := access_v_in;
        tval2 := r.x.tval2;
        if r.x.tval2type = "01" then
          -- The value from MMU/cache controller has no knowledge of
          -- exactly what part of the word the faulting instruction
          -- was in, so copy from virtual address.
          tval2(11 - 2 downto 0) := tval(11 downto 2);
        end if;
      elsif cause = XC_INST_INST_PAGE_FAULT or
            cause = XC_INST_ACCESS_FAULT then
        gva   := fetch_v_in;
      elsif cause = XC_INST_LOAD_PAGE_FAULT   or
            cause = XC_INST_STORE_PAGE_FAULT  or
            cause = XC_INST_LOAD_ACCESS_FAULT or
            cause = XC_INST_STORE_ACCESS_FAULT then
        gva   := access_v_in;
      end if;

      -- mtinst / htinst
      -- Since there is no support for misaligned addresses,
      -- only masking of the offending instruction is needed.
      -- Unless the error was with the PT read/update itself,
      -- which will instead use special instructions.
      --
      -- _If_ misaligned accesses were supported, the following
      -- should be true on access faults during them:
      -- If faulting at the start of the read, nothing special needs
      -- to be done since it is the same as any other access fault.
      -- If faulting on a subsequent part of the access, it could be
      -- interesting to the handler to know how far into the access
      -- things got before the fault - assuming that it needs to do the
      -- final part of the access itself (restarting the instruction
      -- could be an option if accessing idempotent memory).
      -- Examples, faulting on the page starting at 0x1000 - LD at address
      -- 0x0fff - m/htinst offset 1 (0x1000-0x0fff)
      -- 0x0ffc - m/htinst offset 4 (0x1000-0x0ffc)
      -- 0x0ff9 - m/htinst offset 7 (0x1000-0x0ff9)
      -- Note that this does _not_ have anything to do with actual
      -- misaligned memory faults. For such it is already clear where the
      -- access was supposed to go, and a handler (faking support for
      -- misaligned accesses) would just split the access into parts -
      -- passing subsequent faults to the system "above" with appropriate
      -- m/htinst settings.

      -- Load error?
      if    cause = XC_INST_LOAD_G_PAGE_FAULT or
            cause = XC_INST_LOAD_PAGE_FAULT   or
            cause = XC_INST_LOAD_ADDR_MISALIGNED or
            cause = XC_INST_LOAD_ACCESS_FAULT then
        if is_hlv(inst) then
          inst := inst and TINST_H_MASK;
        else
          inst := inst and TINST_LOAD_MASK;
        end if;
      -- Store error?
      elsif cause = XC_INST_STORE_G_PAGE_FAULT or
            cause = XC_INST_STORE_PAGE_FAULT   or
            cause = XC_INST_STORE_ADDR_MISALIGNED or
            cause = XC_INST_STORE_ACCESS_FAULT then
        if is_hsv(inst) then
          inst := inst and TINST_H_MASK;
        elsif opcode(inst) = OP_AMO then
          inst := inst and TINST_AMO_MASK;
        else
          inst := inst and TINST_STORE_MASK;
        end if;
      else
        inst   := (others => '0');
      end if;

      -- Error due to L2 PT while reading L1 page table?
      if (cause = XC_INST_INST_G_PAGE_FAULT and r.d.tval2type /= "01") then
        if r.d.tval2type = "11" then
          inst := tinst_vs_pt_write;
        else
          inst := tinst_vs_pt_read;
        end if;
      elsif ((cause = XC_INST_LOAD_G_PAGE_FAULT or
              cause = XC_INST_STORE_G_PAGE_FAULT) and r.x.tval2type /= "01") then
        if r.x.tval2type = "11" then
          inst := tinst_vs_pt_write;
        else
          inst := tinst_vs_pt_read;
        end if;
      end if;
    end if;

    -- For sspush/sspopchk/c.sspush/c.sspop instructions there are no transformations defined;
    if  is_sspush(  extension_all, cfi_t'(true, true), r.x.ctrl(u2i(xc_lane)).inst) or
        is_sspopchk(extension_all, cfi_t'(true, true), r.x.ctrl(u2i(xc_lane)).inst) then
      inst := (others => '0');
    end if;


    -- IETRIGGER:
    -- When an interrupt or exception trigger fires, the action is taken just
    -- before the first instruction of the trap.
    -- For both, interrupt and exception triggers, if the trigger is active for
    -- the current priviledge mode and the context, it is evaluated if any
    -- instruction in any lane has risen an interrupt or an exception.
    -- If that is the case, the trigger is set to pending meaning that in the
    -- next valid instruction the action has to be performed.
    if TRIGGER_IE_NUM /= 0 then
      for i in TRIGGER_IE_NUM - 1 downto 0 loop

        tdata1  := r.csr.tcsr.tdata1(i + TRIGGER_MC_NUM + TRIGGER_IC_NUM);
        tdata2  := r.csr.tcsr.tdata2(i + TRIGGER_MC_NUM + TRIGGER_IC_NUM);

        -- If the trigger is active for the current mode, check the trigger
        if r.x.rstate = run and xc = '1' and ret = "00" and fence_in = '0' and
           not all_0(xcs) and ie_trig_in.pending = '0' then
          if trigger_valid(r.csr.prv, access_v_in, tdata1) = '1' and
             r.e.conthit(i + TRIGGER_MC_NUM + TRIGGER_IC_NUM) = '1' then

            if is_irq(r.x.irqcause) then
              if u2i(get_hi(tdata1, 4)) = 4 then
                ie_trig.pend_hit(i)  := trigger_itrigger_match(tdata1, tdata2, nmirq, cause);
                ie_trig.pending      := trigger_itrigger_match(tdata1, tdata2, nmirq, cause);
              end if;
            else
              if u2i(get_hi(tdata1, 4)) = 5 then
                ie_trig.pend_hit(i)  := trigger_etrigger_match(tdata2, cause);
                ie_trig.pending      := trigger_etrigger_match(tdata2, cause);
              end if;
            end if;

            if ie_trig.pend_hit(i) = '1' then
              action         := trigger_action(tdata1);
              ie_trig.action := ie_trig.action or action(ie_trig.action'range);
            end if;

          end if;
        end if;
      end loop;
    end if;


    -- The following two variables improve the timing for two situations:
    -- 1.- When there is an ebreak exception, the debug module can be configured
    -- to enter into the debug mode flushing all the stages. To evaluate if there
    -- is an ebreak exception, the debug module needs xc and cause variables. However,
    -- instead of feeding the debug module with xc and cause that depend on the
    -- trigger evaluation, we can use the value of the xc and cause variables at this
    -- point, improving the timing.
    -- 2.- When a exception is raised (xc=1) all the previous stages must be flushed, the
    -- xc variable depends on the triggers. However, if at this point an exception is
    -- raised we can flush the pipeline since if a trigger with an action 0 or 1 fired
    -- we will have to flush the pipeline anyway.
    xc_bt_out   := xc and not fence_in;  -- xc before triggers
    xc_bt_cause := cause;                -- xc cause before triggers
    trig_flushall := '0';


    -- TRIGGER ACTIONS AND PRIORITIES
    -- The only two exceptions that have more priority than "mcontrol6 load/store
    -- address before" trigger are INSTRUCTION PAGE FAULT and INSTRUCTION ACCESS BREAKPOINT.
    -- However, it is impossible that the "mcontrol6 load/store address before" trigger
    -- matches if any of those exceptions take place (because it is impossible for a trigger
    -- to fire if the instructon couldn't be loaded from memory).
    -- However, a trigger and exception can take place in different lanes at the same time.
    -- The exception will have priority only if is executed in the instruction that comes
    -- before the instruction that makes the trigger match.
    -- This condition orv(r.x.trig.valid) /= '0' and u2i(r.x.trig.hit) = 0 is satisfied
    -- when the cause to enter debug mode is the DCSR field being equal to 1.
    if (r.x.ctrl(0).valid or r.x.ctrl(one).valid) = '1' then
      if fence_in = '0' and lbnull_in = '0' and trigxc_in.valid = '1' and
         (single_issue = 1 or
          (r.x.ie_trig.pending = '1' or r.x.trig.lanepri = '1' or
           (xc = '0' or xcs(u2i(swap_in)) = '0')) or
          (not all_0(r.x.trig.valid) and all_0(r.x.trig.hit))) then
        xc            := trigxc_in.xc;
        xcs           := trigxc_in.xcs;
        cause         := trigxc_in.cause;
        flush         := trigxc_in.flush;
        action0       := trigxc_in.action0;
        trig_flushall := trigxc_in.trig_flushall; -- Flush following instructions
        xc_lane       := trigxc_in.xc_lane;
        ie_trig_taken := trigxc_in.ie_trig_taken;
        trig_taken    := trigxc_in.trig_taken;
        pc            := trigxc_in.pc;
        trigxc_out    := trig_exception_none;
        -- After firing any trigger, clear interrupt/exception trigger.
        ie_trig := ie_trig_none;


        -- If native trig taken, set to zero.
        if action0 = '1' then
          if r.x.trig.priority /= "00" then
            -- If the trigger that fired is a native MCONTROL6 then set tval
            -- to the faulting virtual address.
            tval       := trigxc_in.mc6tval;
          else
            tval       := zerox;
          end if;
          tval2      := zerox;
          nmirq      := '0';
          nret       := '0';
          ret        := "00";
          inst       := (others => '0');
        end if;

      else
        clr_trig := '1';
      end if;
    end if;


    -- Stop expecting landing pad for any instruction executing in run state.
    if ext_zicfilp = 1 and r.x.lpad = '1' and (r.x.ctrl(0).valid = '1' or r.x.ctrl(one).valid = '1') and
       not (xc = '1' and is_irq(cause)) then
      elp := '0';
    end if;

    -- If indirect call/jump in run state, expect landing pad as next instruction.
    if ext_zicfilp = 1 and r.x.rstate = run and r.x.ctrl(branch_lane).valid = '1' and
       xc = '0' and fence_in = '0' and
       v_fusel_eq(r, x, branch_lane, JALR) and v_fusel_eq(r, x, branch_lane, CFI) then
      elp := '1';
    end if;

    -- Output exceptions pair (no interrupts infos here)
    xcs_out        := xcs;
    causes_out     := causes;
    tvals_out      := tvals;

    -- Output taken exception
    xc_out         := xc and not fence_in;
    xc_lane_out    := xc_lane;
    cause_out      := cause;
    tval_out       := tval;
    tval2_out      := tval2;
    gva_out        := gva;
    pc_out         := pc;
    inst_out       := inst;
    nmirq_taken    := nmirq;
    ret_out        := ret;
    nret_out       := nret;
    elp_out        := elp;
    ie_trig_out    := ie_trig;
    ebreak_action0 := action0;
    for i in lanes'range loop
      flush_out(i) := flush(i) and not fence_in;
    end loop;
  end;



  function trigger_set_hit(tdata : wordx) return wordx is
    variable typ  : word4 := tdata(tdata'high downto tdata'high - 3);
    -- Non-constant
    variable data : wordx := tdata;
  begin
    case typ is
      when "0000" | "1111" =>
      when "0001" =>
      when "0010" =>           -- MCONTROL
        data(20)       := '1';
      when "0011" =>           -- ICOUNT
        data(24)       := '1';
      when "0100" | "0101" =>  -- ITRIGGER or ETRIGGER
        data(XLEN - 6) := '1';
      when "0110" =>           -- MCONTROL6
        data(22) := '1';
      when others =>
    end case;

    return data;
  end;

  procedure trigger_update(csr_in          : in  csr_reg_type;
                           r_csr           : in  csr_reg_type;
                           ic_tdata1       : in  wordx;
                           ic_tdata3       : in  wordx;
                           v_wb_ctrl       : in  pipeline_ctrl_lanes_type;
                           trig_in         : in  trig_type;
                           ie_trig_in      : in  ie_trig_type;
                           trig_flushall   : in  std_ulogic;
                           csr_out         : out csr_reg_type) is
    variable tdata1_ic_in : wordx        := csr_in.tcsr.tdata1(TRIGGER_MC_NUM);
    variable r_tdata1_ic  : wordx        := r_csr.tcsr.tdata1(TRIGGER_MC_NUM);
    variable action1_ic   : std_logic    := r_tdata1_ic(0);
    -- Non-constant
    variable csr            : csr_reg_type := csr_in;
    variable ic_context_hit : std_logic;
  begin
    if TRIGGER /= 0 then
      -- Trigger hit
      if not all_0(trig_in.valid) then
        for i in trig_in.hit'range loop
          if trig_in.hit(i) = '1' then
            csr.tcsr.tdata1(i) := trigger_set_hit(csr_in.tcsr.tdata1(i));
          end if;
        end loop;
        -- Clear icount trigger pending bit
        csr.tcsr.tdata1(TRIGGER_MC_NUM)(8) := '0';
      end if;

      if TRIGGER_IE_NUM /= 0 then
        -- i/e trigger hit
        if not all_0(ie_trig_in.hit) then
          for i in ie_trig_in.hit'range loop
            if ie_trig_in.hit(i) = '1' then
              csr.tcsr.tdata1(i + trig_in.hit'length) := trigger_set_hit(csr_in.tcsr.tdata1(i + trig_in.hit'length));
            end if;
          end loop;
        end if;
      end if;

      -- trigger icount
      if TRIGGER_IC_NUM /= 0 then
        -- The icount counter is decremented either when a trap is taken or when a instruction
        -- is executed, both when the trigger is active current priviledge mode.
        -- When tdata1 of the ICOUNT trigger is modified, we need to avoid substracting 1 to icount.
        -- Trigger_reentracy checks that it does not match when there is risk of overwritting the mepc CSR in case of firing
        if trigger_valid(r_csr.prv, r_csr.v, r_tdata1_ic) = '1' then
          if ic_tdata1(23 downto 10) = csr.tcsr.tdata1(TRIGGER_MC_NUM)(23 downto 10) and
             (trigger_reentrancy(r_csr, ic_tdata1) or action1_ic = '1') then
            if single_issue = 0 and
               ((v_wb_ctrl(0).valid or v_wb_ctrl(0).xc) and (v_wb_ctrl(one).valid or v_wb_ctrl(one).xc)) = '1' then
              uadd_range(r_tdata1_ic, -2, csr.tcsr.tdata1(TRIGGER_MC_NUM)(23 downto 10));
            elsif (single_issue = 0 and (v_wb_ctrl(0).valid or v_wb_ctrl(0).xc or v_wb_ctrl(one).valid or v_wb_ctrl(one).xc) = '1') or
                  (single_issue = 1 and (v_wb_ctrl(0).valid or v_wb_ctrl(0).xc) = '1') then
              uadd_range(r_tdata1_ic, -1, csr.tcsr.tdata1(TRIGGER_MC_NUM)(23 downto 10));
            end if;
            if (csr.tcsr.tdata1(TRIGGER_MC_NUM)(23) and not r_tdata1_ic(23)) = '1' then
              csr.tcsr.tdata1(TRIGGER_MC_NUM)(23 downto 10) := zerow(23 downto 10);
            end if;
          end if;

          if u2i(csr.tcsr.tdata1(TRIGGER_MC_NUM)(23 downto 10)) = 0 and r_tdata1_ic(11 downto 10) /= "00"
             and trig_flushall = '0' then
            -- If count reaches 0 without triggering (e.g. a trap is taken and the count decreases
            -- from 1 to 0) the pending bit is set to 1 and the icount trigger will fire the next
            -- valid instruction
            csr.tcsr.tdata1(TRIGGER_MC_NUM)(8) := '1';
          end if;
        end if;
      end if;
    end if;

    csr_out := csr;
  end;

  -- Exception flow
  procedure exception_flow(pc_in          : in  pctype;
                           nmirq_in       : in  std_ulogic;
                           xc_inout       : inout  std_ulogic;
                           cause_inout    : inout  cause_type;
                           aia_vti        : in  std_ulogic;
                           tval_in        : in  wordx;
                           tval2_in       : in  wordx;
                           tinst_in       : in  word;
                           gva_in         : in  std_ulogic;
                           ret_in         : in  word2;
                           nret_in        : in  std_ulogic;
                           csr_in         : in  csr_reg_type;
                           rcsr_in        : in  csr_reg_type;
                           rstate_in      : in  core_state;
                           ebreak_action0 : in  std_ulogic;
                           crit_err_out   : out std_ulogic;
                           csr_out        : out csr_reg_type;
                           tvec_out    : out pctype) is
    -- Non-constant
    variable csr       : csr_reg_type  := csr_in;
    variable prv_lvl   : priv_lvl_type := csr_in.prv;
    variable prv_v     : std_ulogic    := csr_in.v;
    variable trap_prv  : priv_lvl_type := PRIV_LVL_M; -- By default trap to Machine Mode
    variable tvec      : pctype;
    variable mask_xc   : std_ulogic    := '0';
    variable h_en      : boolean       := rcsr_in.misa(h_ctrl) = '1';
    variable trap_v    : std_ulogic    := '0';
    variable xc_in     : std_ulogic    := xc_inout;
    variable xc_out    : std_ulogic    := xc_inout;
    variable cause_in  : cause_type    := cause_inout;
    variable cause_v   : cause_type    := cause_in;
    variable cause_out : cause_type    := cause_in;
    variable elp       : std_ulogic    := '0';
    variable nmirq     : std_ulogic    := nmirq_in; -- Pending resumable non-maskable interrupt
    variable sdbltrp   : std_ulogic    := '0';     -- Supervisor double trap flag
    variable mdbltrp   : std_ulogic    := '0';     -- Machine double trap flag
    variable crit_err  : std_ulogic    := '0';     -- Critical error state

  begin

    -- Check the privileged mode where to trap.
    if ((    is_irq(cause_in) and (cause_bit(rcsr_in.mideleg, cause_in) = '1' or cause_bit(rcsr_in.mvien, cause_in) = '1' or (aia_vti = '1'))) or
        (not is_irq(cause_in) and cause_bit(rcsr_in.medeleg, cause_in) = '1')) and
       nmirq = '0' then  -- If it is an RNMI, always trap to M.
      -- Delegated from M.
      if (rcsr_in.prv = PRIV_LVL_S or rcsr_in.prv = PRIV_LVL_U) then
        -- In S/HS/VS/U.
        trap_prv       := PRIV_LVL_S;
        if h_en and rcsr_in.v = '1' then -- Hypervisor extension
          -- In VS/VU,
          if (    is_irq(cause_in) and (cause_bit(rcsr_in.hideleg, cause_in) or cause_bit(rcsr_in.hvien, cause_in) or aia_vti) = '1') or
             (not is_irq(cause_in) and cause_bit(rcsr_in.hedeleg, cause_in) = '1') then
            -- Delegated from HS.
            trap_v := '1';
            if is_irq(cause_in) then
              -- Interrupt - translate.
              if cause_in.code = IRQ_VS_EXTERNAL then
                -- When delegated to VS-mode: transformed into supervisor external interrupt
                cause_v := CAUSE_IRQ_S_EXTERNAL;
              elsif cause_in.code = IRQ_VS_SOFTWARE then
                -- When delegated to VS-mode: transformed into supervisor software interrupt
                cause_v := CAUSE_IRQ_S_SOFTWARE;
              elsif cause_in.code = IRQ_VS_TIMER then
                -- When delegated to VS-mode: transformed into supervisor timer interrupt
                cause_v := CAUSE_IRQ_S_TIMER;
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;

    if xc_in = '1' then
      if ext_ssdbltrp = 1 then
        if trap_prv = PRIV_LVL_S then
          if trap_v = '0' then
            if csr_in.menvcfg.dte = '1' then
              if csr_in.mstatus.sdt = '1' then
                trap_prv           := PRIV_LVL_M;
                sdbltrp            := '1';
                cause_out          := check_cause_update(XC_INST_DOUBLE_TRAP, cause_out);
              else
                csr.mstatus.sdt    := '1';
              end if;
            end if;
          else
            if csr_in.menvcfg.dte = '1' then
              if (csr_in.menvcfg.dte and csr_in.henvcfg.dte) = '1' then
                if csr_in.vsstatus.sdt = '1' then
                  trap_prv         := PRIV_LVL_M;
                  trap_v           := '0';
                  sdbltrp          := '1';
                  cause_out        := check_cause_update(XC_INST_DOUBLE_TRAP, cause_out);
                else
                  csr.vsstatus.sdt := '1';
                end if;
              end if;
            end if;
          end if;
        end if;
      end if;
      if ext_smdbltrp = 1 then
        if trap_prv = PRIV_LVL_M and nmirq = '0' and ret_in = "00"  then
          if csr_in.mstatus.mdt = '1' then
             --(ext_smrnmi = 1 and csr.mnstatus.nmie = '0' and rcsr_in.prv = PRIV_LVL_M ) then
            if ext_smrnmi = 1 and csr.mnstatus.nmie = '1' then
              -- Generate RNMI exception
              nmirq         := '1';
              mdbltrp       := '1';
            else
              -- Enter critical error state if the exception is valid
              crit_err      := '1';
              xc_out        := '0';
            end if;
          else
            csr.mstatus.mdt := '1';
          end if;
        end if;
      end if;
    end if;

    -- xRET needs to be handled separately from the others,
    -- and interrupts should have priority.
    -- (Note that there can never be a long chain of xRET, since they are defined
    --  to clear mstatus.xPP and thus such an attempt would cause an illegal
    --  instruction exception.)
    -- Other synchronous exception have priority over xRET (see me_exceptions()).
    if ret_in = "00" or is_irq(cause_in) then
      -- To support nested traps, each privilege mode x has a two-level stack of
      -- interrupt-enable bits and privilege modes. xPIE holds the value of the
      -- interrupt-enable bit active prior to the trap, and xPP holds the previous
      -- privilege mode. The xPP fields can only hold privilege modes up to x,
      -- so MPP is two bits wide, SPP is one bit wide, and UPP is implicitly zero.
      -- When a trap is taken from privilege mode y into privilege mode x, xPIE is
      -- set to the value of xIE; xIE is set to 0; and xPP is set to y.
      if trap_v = '1' then -- trapping to VS Mode
        csr.vsstatus.spie  := csr_in.vsstatus.sie;
        csr.vsstatus.sie   := '0';
        csr.vsstatus.spp   := prv_lvl(0);
        csr.vsstatus.spelp := rcsr_in.elp;
        csr.vscause        := cause_v;
        csr.vsepc          := pc2xlen(pc_in);
        csr.vstval         := tval_in;
      elsif trap_prv = PRIV_LVL_S then        -- Trapping to S/HS Mode
        csr.mstatus.spie   := csr_in.mstatus.sie;
        csr.mstatus.sie    := '0';
        csr.mstatus.spp    := prv_lvl(0);
        csr.mstatus.spelp  := rcsr_in.elp;
        -- H-ext
        csr.hstatus.spv    := csr_in.v;
        csr.hstatus.gva    := gva_in;
        if rcsr_in.v = '1' then
          csr.hstatus.spvp := prv_lvl(0);
        end if;
          csr.scause       := cause_in;
          csr.sepc         := pc2xlen(pc_in);
          csr.stval        := tval_in;
          -- H-ext
          csr.htval        := tval2_in;
          csr.htinst       := to0x(tinst_in);

      else                                    -- Trapping to Machine Mode
        if nmirq = '0' or ext_smrnmi = 0 then  --  Non-RNMI taken
          csr.mstatus.mpie  := csr_in.mstatus.mie;
          csr.mstatus.mie   := '0';
          csr.mstatus.mpp   := csr_in.prv;
          csr.mstatus.mpelp := rcsr_in.elp;
          -- H-ext
          if csr_in.prv = PRIV_LVL_M then
            csr.mstatus.mpv := '0';
          else
            csr.mstatus.mpv := csr_in.v;
          end if;
          csr.mstatus.gva   := gva_in;
          if sdbltrp = '0' then
            -- Normal trap
            csr.mcause      := cause_in;
            csr.mtval2      := tval2_in;
          elsif ext_ssdbltrp = 1 then
            -- Double trap
            csr.mcause      := XC_INST_DOUBLE_TRAP;
            csr.mtval2      := to0x(cause2wordx(cause_in));
          end if;
          csr.mepc          := pc2xlen(pc_in);
          csr.mtval         := tval_in;
          csr.mtinst        := to0x(tinst_in);
        else                                  --  Resumable Non-Maskable Interrupt taken
          csr.mnstatus.nmie   := '0';
          csr.mnstatus.mnpp   := csr_in.prv;
          -- H-ext
          if csr_in.prv = PRIV_LVL_M then
            csr.mnstatus.mnpv := '0';
          else
            csr.mnstatus.mnpv := csr_in.v;
          end if;
          csr.mnstatus.mnpelp := rcsr_in.elp;
          csr.mncause         := cause_in;
          csr.mnepc           := pc2xlen(pc_in);
        end if;
      end if;

      -- Set privilege mode
      prv_lvl := trap_prv;
      prv_v   := trap_v;

    else

      -- The MRET, SRET, or URET instructions are used to return from traps in M-mode, S-mode,
      -- or U-mode respectively. When executing an xRET instruction, supposing xPP holds the
      -- value y, xIE is set to xPIE; the privilege mode is changed to y; xPIE is set to 1;
      -- and xPP is set to U (or M if user mode is not supported).
      -- Since priv-spec v1.12, mret/sret clears mprv when leaving machine mode.
      if ret_in = "11" then       -- mret
        if nret_in = '0' then
          csr.mstatus.mie     := csr_in.mstatus.mpie;
          if ext_zicfilp = 1 then
            elp               := csr_in.mstatus.mpelp;
            csr.mstatus.mpelp := '0';
          end if;
          prv_lvl             := csr_in.mstatus.mpp;
          -- H-ext
          prv_v               := csr_in.mstatus.mpv;
          if prv_lvl = PRIV_LVL_M then
            prv_v             := '0';
          end if;
          if prv_lvl /= PRIV_LVL_M then
            csr.mstatus.mprv  := '0';
          end if;
          csr.mstatus.mpie    := '1';
          csr.mstatus.mpp     := PRIV_LVL_U;
          if mode_u = 0 then
            csr.mstatus.mpp   := PRIV_LVL_M;
          end if;
          -- H-ext
--        if prv_lvl /= PRIV_LVL_M then
            csr.mstatus.mpv   := '0';
--        end if;
          -- M-double-trap
          if ext_smdbltrp = 1 then
            csr.mstatus.mdt   := '0';
          end if;
          -- Depending on the mode we are coming back we
          -- need to clear sdt
          if ext_ssdbltrp = 1 then
            if prv_v = '1' or prv_lvl = PRIV_LVL_U then
              csr.mstatus.sdt := '0';
            end if;
            if prv_v = '1' and prv_lvl = PRIV_LVL_U then
              csr.vsstatus.sdt := '0';
            end if;
          end if;
        else  -- mnret from a Resumable Non-Maskable Interrupt
          csr.mnstatus.nmie     := '1';
          if ext_zicfilp = 1 then
            elp                 := csr_in.mnstatus.mnpelp;
            csr.mnstatus.mnpelp := '0';
          end if;
          prv_lvl               := csr_in.mnstatus.mnpp;
          -- M-double-trap
          if ext_smdbltrp = 1 and prv_lvl /= PRIV_LVL_M then
            csr.mstatus.mdt     := '0';
          end if;
          -- H-ext
          prv_v                 := csr_in.mnstatus.mnpv;
          if prv_lvl = PRIV_LVL_M then
            prv_v               := '0';
          end if;
          if prv_lvl /= PRIV_LVL_M then
            csr.mstatus.mprv    := '0';
          end if;
          csr.mnstatus.mnpp     := PRIV_LVL_U;
          if mode_u = 0 then
            csr.mnstatus.mnpp   := PRIV_LVL_M;
          end if;
          -- H-ext
          csr.mnstatus.mnpv     := '0';
        end if;
      elsif ret_in = "01" then    -- sret
        if rcsr_in.v = '1' then   -- VS Mode
          csr.vsstatus.sie     := csr_in.vsstatus.spie;
          if ext_zicfilp = 1 then
            elp                := csr_in.vsstatus.spelp;
            csr.vsstatus.spelp := '0';
          end if;
          prv_lvl              := '0' & csr_in.vsstatus.spp;
          prv_v                := '1';
          csr.vsstatus.spie    := '1';
          csr.vsstatus.spp     := PRIV_LVL_U(0);
          if mode_u = 0 then
            csr.vsstatus.spp   := PRIV_LVL_M(0);
          end if;
          -- S-double-trap
          if ext_ssdbltrp = 1 then
            csr.vsstatus.sdt   := '0';
          end if;
        else                      -- S/HS Mode
          csr.mstatus.sie     := csr_in.mstatus.spie;
          if ext_zicfilp = 1 then
            elp               := csr_in.mstatus.spelp;
            csr.mstatus.spelp := '0';
          end if;
          prv_lvl             := '0' & csr_in.mstatus.spp;
          -- H-ext
          prv_v               := csr_in.hstatus.spv;
          if prv_lvl /= PRIV_LVL_M then
            csr.mstatus.mprv  := '0';
          end if;
          csr.mstatus.spie    := '1';
          csr.mstatus.spp     := PRIV_LVL_U(0);
          if mode_u = 0 then
            csr.mstatus.spp   := PRIV_LVL_M(0);
          end if;
          -- H-ext
          csr.hstatus.spv     := '0';
          -- M-double-trap and S-double-trap
          if rcsr_in.prv = PRIV_LVL_M then
            csr.mstatus.mdt   := '0';
            if prv_v = '1' or prv_lvl = PRIV_LVL_U then
              csr.mstatus.sdt := '0';
            end if;
          else -- Executed in S mode
            csr.mstatus.sdt   := '0';
          end if;
          -- Both if it is executed in M or S mode
          if prv_v = '1' and prv_lvl = PRIV_LVL_U then
            csr.vsstatus.sdt  := '0';
          end if;
        end if;
      end if;
      if ext_zicfilp = 1 then
        csr.elp       := '0';
        case prv_lvl is
        when PRIV_LVL_M =>
          if csr_in.mseccfg.mlpe = '1' then
            csr.elp   := elp;
          end if;
        when PRIV_LVL_S =>
          if prv_v = '1' then
            if csr_in.henvcfg.lpe = '1' then
              csr.elp := elp;
            end if;
          else
            if csr_in.menvcfg.lpe = '1' then
              csr.elp := elp;
            end if;
          end if;
        when others =>
          if mode_s = 1 then
            if csr_in.senvcfg.lpe = '1' then
              csr.elp := elp;
            end if;
          else
            if csr_in.menvcfg.lpe = '1' then
              csr.elp := elp;
            end if;
          end if;
        end case;
      end if;
    end if;

    -- Generate Return PC for Trap/Return Instructions.
    -- Trap/Exceptions
    tvec     := to_addr(rcsr_in.mtvec);
    tvec(0)  := '0';
    if rcsr_in.mtvec(0) = '1' and is_irq(cause_in) then
      tvec   := cause2vec(cause_in, tvec);
    end if;

    -- If there is RNMI pending, trap to the RNMI interrupt trap handler
    if nmirq = '1' then
      tvec   := PC_RNMI_ITRAP;
      -- If there is a machine double trap, trap to the RNMI exception trap handler
      if ext_smdbltrp = 1 and mdbltrp = '1' then
        tvec := PC_RNMI_XTRAP;
      end if;
    end if;

    -- If smdbltrp extension is implemented the behavior for this case changes:
    -- if the Smrnmi extension is implemented and mnstatus.NMIE is 0, the hart enters a
    -- critical-error state without updating any architectural state including the pc.
    if ext_smdbltrp = 0 then
      -- If the hart encounters an exception while executing in M-mode with the mnstatus.NMIE bit clear,
      -- program counter is set to the RNMI exception trap handler address
      -- if nmie = 0, interrupts never reach here so no need of differenciating between interrupts and exceptions
      if rcsr_in.mnstatus.nmie = '0' and rcsr_in.prv = PRIV_LVL_M and ext_smrnmi = 1 then
        tvec := PC_RNMI_XTRAP;
      end if;
    end if;

    if trap_prv = PRIV_LVL_S then
      tvec     := to_addr(rcsr_in.stvec);
      if rcsr_in.stvec(0) = '1' and is_irq(cause_in) then
        tvec   := cause2vec(cause_in, tvec);
      end if;
      if trap_v = '1' then -- VS Mode (H extension)
        tvec   := to_addr(rcsr_in.vstvec);
        if rcsr_in.vstvec(0) = '1' and is_irq(cause_in) then
          tvec := cause2vec(cause_v, tvec);
        end if;
      end if;
    end if;

    -- Return Instructions
    if ret_in = "11" then
      if nret_in = '0' then  -- MRET
        tvec    := to_addr(rcsr_in.mepc);
      else -- MNRET
        tvec    := to_addr(rcsr_in.mnepc);
      end if;
    elsif ret_in = "01" then
      tvec      := to_addr(rcsr_in.sepc);
      if rcsr_in.v = '1' then
        tvec    := to_addr(rcsr_in.vsepc);
      end if;
    end if;
    if ret_in = "11" or ret_in = "01" then
      if ext_c = 1 and ISA_CONTROL(c_ctrl) = '1' and csr.misa(c_ctrl) = '0' then
        tvec(1) := '0';
      end if;
    end if;

    -- Update privileged level
    csr.prv   := prv_lvl;
    csr.v     := prv_v;

    -- Outputs
    tvec_out  := tvec;

    if (rstate_in /= run) or
       ((rstate_in = run) and (cause_in = XC_INST_BREAKPOINT) and (ebreak_action0 = '0') and
        ((csr_in.v = '0' and csr_in.prv = PRIV_LVL_M and csr_in.dcsr.ebreakm  = '1') or
         (csr_in.v = '0' and csr_in.prv = PRIV_LVL_S and csr_in.dcsr.ebreaks  = '1') or
         (csr_in.v = '0' and csr_in.prv = PRIV_LVL_U and csr_in.dcsr.ebreaku  = '1') or
         (csr_in.v = '1' and csr_in.prv = PRIV_LVL_S and csr_in.dcsr.ebreakvs = '1') or
         (csr_in.v = '1' and csr_in.prv = PRIV_LVL_U and csr_in.dcsr.ebreakvu = '1'))) then
      mask_xc := '1';
    end if;


    csr_out := csr_in;
    crit_err_out := '0';

    -- If we receive a valid exception, we have to update some CSR registers.
    if xc_in = '1' and mask_xc = '0' then
      if crit_err = '0' then
        -- Restore SSP on exception!
        csr.ssp := rcsr_in.ssp;

        csr_out := csr;
      else --crit_err='1'
        crit_err_out := '1';
      end if;
      cause_inout := cause_out;
    end if;
    xc_inout := xc_out;

  end;

  -- CSR Write
  procedure csr_write(csra_in          : in  csratype;
                      rstate_in        : in  core_state;
                      csr_file         : in  csr_reg_type;
                      csr_special      : in  word2;
                      wcsr_in          : in  wordx;
                      csrv_in          : in  std_ulogic;
                      pc_in            : in  pctype;
                      xc_in            : in  std_ulogic;
                      dm_xc_in         : in  std_ulogic;
                      int_in           : in  lanes_type;
                      csrpipeflush_in  : in  std_ulogic;
                      csraddrflush_in  : in  std_ulogic;
                      pipeflush_out    : out std_ulogic;
                      addrflush_out    : out std_ulogic;
                      upd_mcycle_out   : out std_ulogic;
                      upd_minstret_out : out std_ulogic;
                      upd_counter_out  : out std_logic_vector;

                      imsici_out       : out imsic_in_type;
                      csr_out          : out csr_reg_type
                      ) is

    -- Locked or unimplemented PMP?
    function pmp_locked(csr : csr_reg_type; n : integer) return std_logic is
    begin
      if n >= pmp_entries then
        return '1';
      end if;

      if (ext_smepmp = 1
         ) and csr.mseccfg.rlb = '1' then
        return '0';
      end if;

      return pmpcfg(pmp_entries, csr.pmpcfg, n, 7);
    end;

    procedure pmpcfg_write(csr_in    : in    csr_reg_type;
                           first_in  : in    integer; last_in : in integer; wcsr_in : in wordx;
                           pmpcfg_io : inout pmpcfg_vec_type; flush_out : out std_ulogic) is
      --  Non-constant
      variable pmpcfg     : pmpcfg_vec_type := pmpcfg_io;
      variable flush      : std_ulogic      := '0';
      variable pmpcfg_b   : word8;
      variable pmpcfg_old : word8;
    begin
      -- Should flush pipeline if (at least new) lock bit is set, since that
      -- should "take" immediately and might invalidate instruction fetches.
      for i in first_in to last_in loop
        if pmp_locked(csr_in, i) = '0' then
          pmpcfg_old     := pmpcfg_io(i);
          pmpcfg_b       := get(wcsr_in, (i - first_in) * 8, 8);
          -- Clear bit 6 & 5 since these are unused and WARL.
          pmpcfg(i)      := pmpcfg_b(7) & "00" & pmpcfg_b(4 downto 0);
          -- W without R is reserved, unless in Machine Mode Lockdown!
          if csr_in.mseccfg.mml = '0' and pmpcfg_b(1 downto 0) = "10" then
            pmpcfg(i)(1) := '0';
          end if;
          -- No new rules with X permission may be added with .L if in
          -- Machine Mode Lockdown, unless also Rule Locking Bypass.
          if csr_in.mseccfg.mml = '1' and pmpcfg_b(7) = '1' and csr_in.mseccfg.rlb = '0' then
            if (pmpcfg_b(2) = '1' and get_lo(pmpcfg_b, 2) /= "11") or           -- RWX is R-only
               (pmpcfg_b(2) = '0' and pmpcfg_b(1) = '1' and pmpcfg_b(0) = '0') then  -- -W- is X
              pmpcfg(i)  := pmpcfg_old;
            end if;
          end if;
          if pmp_g > 0 then
            -- NA4 not possible!
            if pmpcfg_b(4 downto 3) = "10" then
              -- Revert to NAPOT since this is what spike does.
              pmpcfg(i)(4 downto 3) := "11";
            end if;
          end if;
          if pmp_no_tor = 1 then
            -- TOR not possible!
            if pmpcfg_b(4 downto 3) = "01" then
              pmpcfg(i)(3) := '0';      -- Clear to OFF
            end if;
          end if;
          -- Always flush if lock bit x->1 or 1->0, since either
          -- can affect the behaviour of the very next instruction.
          flush := flush or pmpcfg_b(7) or (not pmpcfg_b(7) and pmpcfg_old(7));
        end if;
      end loop;

      pmpcfg_io := pmpcfg;
      flush_out := flush;
    end;

    procedure tdata_write(tcsr_in   : in  csr_tcsr_type;
                          reg       : in  integer;
                          rstate_in : in  core_state;
                          h_en      : in  boolean;
                          wcsr_in   : in  wordx;
                          tcsr_out  : out csr_tcsr_type) is
      variable sel      : tselect_int := tselect(tcsr_in);
      variable typ      : word4       := get_hi(tcsr_in.tdata1(sel), 4);
      variable typ_in   : integer16   := u2i(get_hi(wcsr_in, 4));
      variable maskmax6 : integer range 1 to addr_bits - 1 := addr_bits - 1;
      -- Non-constant
      variable mcwcsr : wordx         := wcsr_in;
      variable valid  : std_logic     := '0';
      variable tcsr   : csr_tcsr_type := tcsr_in;

      function tdata1_mcontrol(rstate : core_state; wcsr : wordx; maskmax : integer) return std_logic_vector is
        -- Non-constant
        variable tdata1 : std_logic_vector(XLEN - 6 downto 0) := (others => '0');
      begin
        tdata1(XLEN - 6 downto XLEN - 11) := s2vec(maskmax, 6);       -- maskmax
        tdata1(20)  := wcsr(20);              -- hit
        -- select is hardware to 0 when execute is 0
        tdata1(19)  := wcsr(19) and wcsr(2);  -- select
        -- timing field is hardwire to 0

        -- action
        tdata1(15 downto 12) := "000" & (wcsr(12) and to_bit((wcsr(XLEN - 5) = '1') and
                                                             rstate /= run));
        -- match
        tdata1(10 downto 7) := wcsr(10 downto 7);
        tdata1(6)   := wcsr(6);        -- m
        if mode_s = 1 then
          tdata1(4) := wcsr(4);        -- s
        end if;
        if mode_u = 1 then
          tdata1(3) := wcsr(3);        -- u
        end if;
        tdata1(2)   := wcsr(2);        -- execute
        tdata1(1)   := wcsr(1);        -- store
        tdata1(0)   := wcsr(0);        -- load

        return tdata1;
      end;

      function tdata1_mcontrol6(rstate : core_state; wcsr : wordx; h_en : boolean) return std_logic_vector is
        -- Non-constant
        variable tdata1 : std_logic_vector(XLEN - 6 downto 0) := (others => '0');
      begin
        tdata1(25)  := wcsr(25);        -- hit1
        if h_en then
          tdata1(24)  := wcsr(24);      -- vs
          tdata1(23)  := wcsr(23);      -- vu
        end if;
        tdata1(22)  := wcsr(22);        -- hit0

        -- select is hardware to 0 when execute is 0
        tdata1(21)  := wcsr(21) and wcsr(2);        -- select

        -- size
        if wcsr(2) = '1' then -- (execute = 1)
          if tdata1(17 downto 16) /= "01" then
            tdata1(17 downto 16) := wcsr(17 downto 16); -- support for 16 an 32 bit instructions
          end if;
        elsif u2i(wcsr(18 downto 16)) /= 6 and
              u2i(wcsr(18 downto 16)) /= 4 and
              not (XLEN = 32 and u2i(wcsr(18 downto 16)) = 5) then
          tdata1(18 downto 16) := wcsr(18 downto 16);
        end if;

        -- action
        tdata1(15 downto 12) := "000" & (wcsr(12) and to_bit((wcsr(XLEN - 5) = '1') and
                                                             rstate /= run));

        tdata1(11)  := wcsr(11);       -- chain


        tdata1(10 downto 7) := wcsr(10 downto 7);   -- match
        tdata1(6)   := wcsr(6);        -- m
        if mode_s = 1 then
          tdata1(4) := wcsr(4);        -- s
        end if;
        if mode_u = 1 then
          tdata1(3) := wcsr(3);        -- u
        end if;
        tdata1(2)   := wcsr(2);        -- execute
        tdata1(1)   := wcsr(1);        -- store
        tdata1(0)   := wcsr(0);        -- load

        return tdata1;
      end;


      function tdata2_mcontrol6(wcsr : wordx; tdata1 : wordx; maskmax6 : integer) return wordx is
        variable tdata2 : wordx   := wcsr;
        variable match  : integer := u2i(tdata1(9 downto 7));
      begin
        if match = 1 then -- match=napot/not napot
          if tdata2(maskmax6 - 1 downto 0) = (maskmax6 - 1 downto 0 => '1') then
            tdata2(maskmax6 - 1) := '0';
          end if;
        end if;

        return tdata2;
      end;

      function tdata1_icount(rstate : core_state; wcsr : wordx; h_en : boolean) return std_logic_vector is
        -- Non-constant
        variable tdata1 : std_logic_vector(XLEN - 6 downto 0) := (others => '0');
      begin
        if h_en then
          tdata1(26)         := wcsr(26);             -- vs
          tdata1(25)         := wcsr(25);             -- vu
        end if;
        tdata1(24)           := wcsr(24);             -- hit
        tdata1(23 downto 10) := wcsr(23 downto 10);   -- count
        tdata1(9)            := wcsr(9);              -- m
        tdata1(8)            := wcsr(8);              -- pending
        if mode_s = 1 then
          tdata1(7)          := wcsr(7);              -- s
        end if;
        if mode_u = 1 then
          tdata1(6)          := wcsr(6);              -- u
        end if;
        -- action
        tdata1(5 downto 0) := "00000" & (wcsr(0) and to_bit((wcsr(XLEN - 5) = '1') and
                                                            rstate /= run));
        return tdata1;
      end;

      function tdata1_ietrigger(rstate : core_state; wcsr : wordx; e : std_logic; h_en : boolean) return std_logic_vector is
        -- Non-constant
        variable tdata1 : std_logic_vector(XLEN - 6 downto 0) := (others => '0');
      begin
        tdata1(XLEN - 6)   := wcsr(XLEN - 6);  -- hit
        if h_en then
          tdata1(12)       := wcsr(12);        -- vs
          tdata1(11)       := wcsr(11);        -- vu
        end if;
        if ext_smrnmi = 1 then
          tdata1(10)       := e and wcsr(10);  -- nmi
        end if;
        tdata1(9)          := wcsr(9);         -- m
        if mode_s = 1 then
          tdata1(7)        := wcsr(7);         -- s
        end if;
        if mode_u = 1 then
          tdata1(6)        := wcsr(6);         -- u
        end if;
        -- action
        tdata1(5 downto 0) := "00000" & (wcsr(0) and to_bit((wcsr(XLEN - 5) = '1') and
                                                            rstate /= run));
        return tdata1;
      end;


      function textra_write(h_en : boolean; wcsr : wordx) return std_logic_vector is
        variable X64    : integer := b2i(XLEN = 64);
        -- Non-constant
        variable tdata3 : wordx   := (others => '0');
      begin

        if XLEN >= 64 then
          tdata3(63 * X64 downto 51 * X64) := wcsr(63 * X64 downto 51 * X64);    -- mhvalue
          if not h_en then
            tdata3(50 * X64) := wcsr(50 * X64);                                  -- mhselect
          elsif wcsr(49 * X64 downto 48 * X64) /= "11" then
            tdata3(50 * X64 downto 48 * X64) := wcsr(50 * X64 downto 48 * X64);  -- mhselect
          end if;
          if mode_s = 1 then
            tdata3(40 * X64 downto 0) := wcsr(40 * X64 downto 0);                -- sbytemask, svalue, sselect
            if wcsr(1 downto 0) = "11" then
              tdata3(1 downto 0) := "00";                                        -- sselect
            end if;
          end if;
        else
          tdata3(31 downto 26) := wcsr(31 downto 26);    -- mhvalue
          if not h_en then
            tdata3(25) := wcsr(25);                      -- mhselect
          elsif wcsr(24 downto 23) /= "11" then
            tdata3(25 downto 23) := wcsr(25 downto 23);  -- mhselect
          end if;
          if mode_s = 1 then
            tdata3(19 downto 0) := wcsr(19 downto 0);    -- sbytemask, svalue, sselect
            if wcsr(1 downto 0) = "11" then
              tdata3(1 downto 0) := "00";                -- sselect
            end if;
          end if;
        end if;
        return tdata3;
      end;

    begin
      if TRIGGER /= 0 then
        valid := trig_info_vector(sel)(typ_in);
        case reg is
          when 1 =>
            if tcsr_in.tdata1(sel)(XLEN - 5) = '0' or rstate_in /= run then
              if rstate_in /= run then
                tcsr.tdata1(sel)(XLEN - 5)                 := wcsr_in(XLEN - 5);
              end if;
              if valid = '1' then  -- New trigger supported
                tcsr.tdata1(sel)(XLEN - 1 downto XLEN - 4) := get_hi(wcsr_in, 4);
                case typ_in is
                  when 2 =>     -- MCONTROL
                    tcsr.tdata1(sel)(XLEN - 6 downto 0) := tdata1_mcontrol(rstate_in, wcsr_in, maskmax6);
                  when 3 =>     -- ICOUNT
                    tcsr.tdata1(sel)(XLEN - 6 downto 0) := tdata1_icount(rstate_in, wcsr_in, h_en);
                  when 4 =>     -- ITRIGGER
                    tcsr.tdata1(sel)(XLEN - 6 downto 0) := tdata1_ietrigger(rstate_in, wcsr_in, '0', h_en);
                  when 5 =>     -- ETRIGGER
                    tcsr.tdata1(sel)(XLEN - 6 downto 0) := tdata1_ietrigger(rstate_in, wcsr_in, '1', h_en);
                  when 6 =>     -- MCONTROL6
                    -- Because chain affects the next trigger, hardware must zero it in writes to mcontrol6 that set
                    -- dmode to 0 if the next trigger has dmode of 1. In addition hardware should ignore writes to
                    -- mcontrol6 that set dmode to 1 if the previous trigger has both dmode of 0 and chain of 1.
                    if sel /= TRIGGER_MC_NUM - 1 then
                      if (not wcsr_in(XLEN - 5) and tcsr_in.tdata1(sel + 1)(XLEN - 5)) = '1' then
                        mcwcsr(11) := '0';
                      end if;
                    end if;
                    if sel /= 0 then
                      if (not tcsr_in.tdata1(sel - 1)(XLEN - 5) and tcsr_in.tdata1(sel - 1)(11)) = '1' then
                        mcwcsr := tcsr_in.tdata1(sel);
                      end if;
                    end if;
                    tcsr.tdata1(sel)(XLEN - 6 downto 0) := tdata1_mcontrol6(rstate_in, mcwcsr, h_en);
                  when others =>
                end case;
              else
                tcsr.tdata1(sel)(XLEN - 1 downto XLEN - 4) := x"f";
              end if;
            end if;
          when 2 =>
            if tcsr_in.tdata1(sel)(XLEN - 5) = '0' or rstate_in /= run then
              if    typ = x"2" then      -- MCONTROL
                tcsr.tdata2(sel) := wcsr_in;
              elsif typ = x"4" then      -- ITRIGGER
                tcsr.tdata2(sel) := wcsr_in and mie_mask(mode_s = 1, h_en, ext_sscofpmf = 1);
              elsif typ = x"5" then      -- ETRIGGER
                tcsr.tdata2(sel) := wcsr_in and etrigger_mask(h_en);
              elsif typ = x"6" then      -- MCONTROL6
                tcsr.tdata2(sel) := tdata2_mcontrol6(wcsr_in, tcsr_in.tdata1(sel), maskmax6);
              elsif typ = x"f" then      -- DISABLED
                tcsr.tdata2(sel) := wcsr_in;
              end if;
            end if;
          when 3 =>
            -- All llegal types can write the same TDATA3 bits
            if tcsr_in.tdata1(sel)(XLEN - 5) = '0' or rstate_in /= run then
              tcsr.tdata3(sel) := textra_write(h_en, wcsr_in);
            end if;
          when others =>
        end case;
      end if;
      tcsr_out := tcsr;


    end;

    function tselect_write(w : std_logic_vector) return std_logic_vector is
      -- Non-constant
      variable tsel : std_logic_vector(dummy_csr.tcsr.tselect'range);
    begin
      tsel := w(tsel'range);
      if u2i(tsel) >= TRIGGER_NUM then
        tsel := (others => '0');
      end if;

      return tsel;
    end;

    -- Was FPU turned on/off?
    function toggled_fpu(status : csr_status_type; wcsr : wordx) return boolean is
      variable new_fs : word2 := to_mstatus(wcsr, csr_status_rst, to_bit(ext_smdbltrp), csr_file.menvcfg.dte).fs;
    begin
      if not (ext_f = 1) then
        return false;
      end if;
      -- Off to on, or vice versa?
      if (status.fs  = "00" and new_fs /= "00") or
         (status.fs /= "00" and new_fs  = "00") then
        return true;
      end if;

      return false;
    end;

    function toggled_custom(status : csr_status_type; wcsr : wordx) return boolean is
      variable new_xc : word2 := to_mstatus(wcsr, csr_status_rst, to_bit(ext_smdbltrp), csr_file.menvcfg.dte).xs;
    begin
      if not (ext_noelv = 1) then
        return false;
      end if;
      -- Off to on, or vice versa?
      if (status.xs  = "00" and new_xc /= "00") or
         (status.xs /= "00" and new_xc  = "00") then
        return true;
      end if;

      return false;
    end;

    variable csra_high    : csratype      := get_hi(csra_in, csra_in'length - 4) & x"0";
    variable csra_low     : csratype      := x"00" & get_lo(csra_in, 4);
    variable csra_ilo     : integer16     := u2i(csra_in(3 downto 0));
    variable h_en         : boolean       := csr_file.misa(h_ctrl) = '1';
    -- Non-constant
    variable dm_xc        : std_ulogic   := dm_xc_in;
    variable writen       : std_ulogic   := csrv_in;
    variable csra         : csratype     := csra_in;
    variable csr          : csr_reg_type := csr_file;
    variable vimsici      : imsic_in_type := imsic_in_none;
    variable mstatus      : csr_status_type;
    variable hpmevent     : hpmevent_type;
    variable mseccfg      : csr_seccfg_type;
    variable mtvec        : wordx;
    variable pipeflush    : std_ulogic   := '0';
    variable addrflush    : std_ulogic   := '0';
    variable mode         : integer;
    variable upd_mcycle   : std_ulogic   := '0';
    variable upd_minstret : std_ulogic   := '0';
    variable upd_counter  : std_logic_vector(csr_file.hpmcounter'range) := (others => '0');

  begin
    -- Pre-calculation should be fine.
    -- Can only be set in machine mode. For instruction fetch it is
    -- then either not used, or it will not be used until locked.
    -- The lock write must flush the pipeline.
    -- When MPRV/MPP is being used to force load/store as S/U mode,
    -- changes to those (and indeed PMPADDR/PMPCFG) must be in effect
    -- before a following load/store. When the MMU is enabled, changes
    -- to PMPADDR/PMPCFG may require an sfence.vma to be visible. But
    -- even then, changes to MPRV/MPP must take effect "immediately".

    pmp_precalc(csr_file.pmpaddr, csr_file.pmpcfg,
                csr.pmp_precalc,
                pmp_entries, pmp_no_tor, pmp_g, physaddr - 1);

    -- Pre-calculating FPU enabled state should be fine.
    -- Any changes to it will have forced a pipeline flush in the previous cycle.
    csr.fpu_enabled := not (csr_file.mstatus.fs = "00" or
                           (csr_file.v = '1' and csr_file.vsstatus.fs = "00"));

    -- Pre-calculating should be fine for
    -- CFI configuration and
    -- envcfg. Any changes will have forced a pipeline flush in the previous cycle.
    csr.envcfg          := active_menvcfg;
    csr.cfi_en.ss       := false;  -- CFI Shadow Stack not available in M mode
    csr.cfi_en.lp       := csr_file.mseccfg.mlpe = '1';
    if csr_file.v = '1' then
      if csr_file.prv = PRIV_LVL_S then
        csr.envcfg      := calc_henvcfg_read_val(active_henvcfg, csr_file);
        csr.cfi_en.ss   := csr_file.henvcfg.sse = '1';
        csr.cfi_en.lp   := csr_file.henvcfg.lpe = '1';
      elsif csr_file.prv = PRIV_LVL_U then
        csr.envcfg      := calc_senvcfg_read_val(active_henvcfg, active_senvcfg, csr_file);
        csr.cfi_en.ss   := csr_file.senvcfg.sse = '1';
        csr.cfi_en.lp   := csr_file.senvcfg.lpe = '1';
      end if;
    else
      if csr_file.prv = PRIV_LVL_S then
        csr.envcfg      := csr_file.menvcfg;
        csr.cfi_en.ss   := csr_file.menvcfg.sse = '1';
        csr.cfi_en.lp   := csr_file.menvcfg.lpe = '1';
      elsif csr_file.prv = PRIV_LVL_U then
        csr.envcfg      := calc_senvcfg_read_val(active_henvcfg, active_senvcfg, csr_file);
        csr.cfi_en.ss   := csr_file.senvcfg.sse = '1';
        if mode_s = 1 then
          csr.cfi_en.lp := csr_file.senvcfg.lpe = '1';
        else
          csr.cfi_en.lp := csr_file.menvcfg.lpe = '1';
        end if;
      end if;
    end if;

    -- Flush should be single cycle
    csr.cctrl.iflush   := '0';
    csr.cctrl.dflush   := '0';
    csr.cctrl.itcmwipe := '0';
    csr.cctrl.dtcmwipe := '0';



    -- Check if there are any pending IRQs, if there is an IRQ pending then we can't
    -- allow a CSR write since that could change the interrupt behavior.
    if writen = '1' and ((xc_in = '0' and rstate_in = run) or (dm_xc = '0' and rstate_in /= run)) and
       all_0(int_in) then
      pipeflush := csrpipeflush_in;
      addrflush := csraddrflush_in;

      case csra is
        when CSR_FFLAGS =>
          csr.fflags        := wcsr_in(csr.fflags'length - 1 downto 0);
          csr.mstatus.fs    := "11";
          if csr_file.v = '1' then
            csr.vsstatus.fs := "11";
          end if;

        when CSR_FRM =>
          csr.frm           := wcsr_in(csr.frm'length - 1 downto 0);
          csr.mstatus.fs    := "11";
          if csr_file.v = '1' then
            csr.vsstatus.fs := "11";
          end if;

        when CSR_FCSR =>
          if fpu_debug /= 0 then
            csr.fctrl       := wcsr_in(csr.fctrl'range);
          end if;
          csr.fflags        := wcsr_in(csr.fflags'range);
          csr.frm           := wcsr_in(csr.frm'range);
          csr.mstatus.fs    := "11";
          if csr_file.v = '1' then
            csr.vsstatus.fs := "11";
          end if;

        -- Hypervisor Trap Setup
        when CSR_HSTATUS =>
          csr.hstatus       := to_hstatus(wcsr_in);

        when CSR_HEDELEG =>
          csr.hedeleg       := wcsr_in and CSR_HEDELEG_MASK;

        when CSR_HIDELEG =>
          csr.hideleg       := wcsr_in and hideleg_mask(ext_shlcofideleg);

        when CSR_HIE =>
          csr.mie           := (csr_file.mie and not CSR_HIE_MASK) or
                               (wcsr_in and CSR_HIE_MASK);

        when CSR_HCOUNTEREN =>
          csr.hcounteren(HWPERFMONITORS + 2 downto 0) := wcsr_in(HWPERFMONITORS + 2 downto 0);

        when CSR_HGEIE =>
          csr.hgeie(GEILEN downto 1)              := wcsr_in(GEILEN downto 1);
          -- Hypervisor Trap Handling

        when CSR_HTVAL =>
          csr.htval         := wcsr_in;

        when CSR_HIP =>
          -- Only hip(2) VSSIP is writable
          -- mip(2) is aliased in hip(2) and hvip(2)
          csr.mip(IRQ_VS_SOFTWARE)        := wcsr_in(IRQ_VS_SOFTWARE);

        when CSR_HVIP =>
          -- mip(2) is aliased in hip(2) and hvip(2)
          csr.hvip(IRQ_VS_EXTERNAL)    := wcsr_in(IRQ_VS_EXTERNAL);
          csr.hvip(IRQ_VS_TIMER)       := wcsr_in(IRQ_VS_TIMER);
          csr.mip(IRQ_VS_SOFTWARE)     := wcsr_in(IRQ_VS_SOFTWARE);
          -- Bits 13 to 63 of hvip are activated trhough hvien
          csr.hvip(XLEN-1 downto 13)   := wcsr_in(XLEN-1 downto 13) and
                                          hvien_mask(ext_sscofpmf, ext_smcdeleg)(XLEN-1 downto 13);

        when CSR_HTINST =>
          csr.htinst        := wcsr_in;

        when CSR_HGEIP =>
          -- Read only

        when CSR_HSTATEEN0 =>
          csr.hstateen0            := stateen_wpri_write(wcsr_in, csr_file.hstateen0, csr_file.mstateen0, false);

        when CSR_HSTATEEN1 =>
          if is_rv64 then
            csr.hstateen1.stateen := stateen_wpri_write(wcsr_in(wordx'length - 1), csr_file.hstateen1.stateen, csr_file.mstateen1.stateen);
          end if;

        when CSR_HSTATEEN2 =>
          if is_rv64 then
            csr.hstateen2.stateen := stateen_wpri_write(wcsr_in(wordx'length - 1), csr_file.hstateen2.stateen, csr_file.mstateen2.stateen);
          end if;

        when CSR_HSTATEEN3 =>
          if is_rv64 then
            csr.hstateen3.stateen := stateen_wpri_write(wcsr_in(wordx'length - 1), csr_file.hstateen3.stateen, csr_file.mstateen3.stateen);
          end if;

        when CSR_HSTATEEN0H =>
          csr.hstateen0            := stateen_wpri_write(wcsr_in, csr_file.hstateen0, csr_file.mstateen0, true);

        when CSR_HSTATEEN1H =>
          csr.hstateen1.stateen := stateen_wpri_write(wcsr_in(31), csr_file.hstateen1.stateen, csr_file.mstateen1.stateen);

        when CSR_HSTATEEN2H =>
          csr.hstateen2.stateen := stateen_wpri_write(wcsr_in(31), csr_file.hstateen2.stateen, csr_file.mstateen2.stateen);

        when CSR_HSTATEEN3H =>
          csr.hstateen3.stateen := stateen_wpri_write(wcsr_in(31), csr_file.hstateen3.stateen, csr_file.mstateen3.stateen);

        -- Hypervisor AIA registers
        when CSR_HVIEN =>
          csr.hvien         := wcsr_in and hvien_mask(ext_sscofpmf, ext_smcdeleg);
        when CSR_HVICTL =>
          csr.hvictl        := to_hvictl(wcsr_in);
        -- Minimal implementation allow these CSRs to be
        -- read-only zero.
        when CSR_HVIPRIO1 =>
        when CSR_HVIPRIO2 =>

        -- Hypervisor AIA registers (RV32)
        -- These CSRs are not writable since there are not
        -- interrupts implemented above 31.
        when CSR_HIDELEGH  =>
        when CSR_HVIENH    =>
        when CSR_HVIPH     =>
        when CSR_HVIPRIO1H =>
        when CSR_HVIPRIO2H =>

        -- Hypervisor Protection and Translation
        when CSR_HGATP =>
          csr.hgatp := to_hgatp(csr_file.hgatp, wcsr_in, XLEN, vmidlen, physaddr, riscv_mmu);

        -- Hypervisor Counter/Timer Virtualization Registers

        when CSR_HENVCFG =>
          csr.henvcfg       := calc_henvcfg_write_val(wcsr_in, active_henvcfg, csr_file);

        when CSR_HENVCFGH =>
          if is_rv32 then
            -- Re-use lower half and only update the upper bits.
            csr.henvcfg       := calc_henvcfg_write_val(wcsr_in, active_henvcfg, csr_file);
          end if;

        when CSR_HTIMEDELTA =>
          csr.htimedelta(wordx'range)    := wcsr_in;

        when CSR_HTIMEDELTAH =>
          if is_rv32 then
            csr.htimedelta(63 downto 32) := wcsr_in(word'range);
          end if;

        -- Virtual Supervisor Registers
        when CSR_VSSTATUS =>
          -- Not written in virtualized mode, so cannot affect
          -- legality of FPU instructions without explicit mode change.
          -- Thus no need for pipeline flush.
          csr.vsstatus      := to_vsstatus(wcsr_in,
                                           csr_file.vsstatus,
                                           csr_file.henvcfg.dte and csr_file.menvcfg.dte,
                                           csr_file.henvcfg.sse and csr_file.menvcfg.sse,
                                           to_bit(ext_zicfilp)
                                         );

        when CSR_VSIE =>
          csr.mie(IRQ_VS_EXTERNAL) := (csr_file.mie(IRQ_VS_EXTERNAL) and not csr_file.hideleg(IRQ_VS_EXTERNAL)) or
                               (wcsr_in(IRQ_S_EXTERNAL) and csr_file.hideleg(IRQ_VS_EXTERNAL));
          csr.mie(IRQ_VS_TIMER)    := (csr_file.mie(IRQ_VS_TIMER) and not csr_file.hideleg(IRQ_VS_TIMER)) or
                               (wcsr_in(IRQ_S_TIMER) and csr_file.hideleg(IRQ_VS_TIMER));
          csr.mie(IRQ_VS_SOFTWARE) := (csr_file.mie(IRQ_VS_SOFTWARE) and not csr_file.hideleg(IRQ_VS_SOFTWARE)) or
                               (wcsr_in(IRQ_S_SOFTWARE) and csr_file.hideleg(IRQ_VS_SOFTWARE));
          if ext_shlcofideleg = 1 and ext_sscofpmf = 1 and
             (csr_file.hideleg(IRQ_LCOF) and csr_file.mideleg(IRQ_LCOF)) = '1' then
            csr.mie(IRQ_LCOF)  := wcsr_in(IRQ_LCOF);
          end if;
          -- So far only LCOF (13) bit in hvien is writable.
          -- This is the behavior for all interrupts above 13 if
          -- more are implemented in the future.
          if ext_ssaia = 1 then
            for i in 13 to XLEN-1 loop
              if csr_file.hideleg(i) = '0' and
                 (csr_file.hvien(i) and hvien_mask(ext_sscofpmf, ext_smcdeleg)(i)) = '1' then
                csr.vsie(i) := wcsr_in(i);
              end if;
            end loop;
          end if;

        when CSR_VSTVEC =>
          csr.vstvec        := wcsr_in(csr.vstvec'high downto 2) & '0' & wcsr_in(0);
          if wcsr_in(0) = '1' then
            csr.vstvec      := wcsr_in(csr.vstvec'high downto 8) & "0000000" & wcsr_in(0);
          end if;

        when CSR_VSSCRATCH =>
          csr.vsscratch     := wcsr_in;

        when CSR_VSEPC =>
          csr.vsepc         := wcsr_in(csr.vsepc'high downto 1) & '0';
          if ext_c = 0 then
            csr.vsepc(1)    := '0';
          end if;

        when CSR_VSCAUSE =>
          csr.vscause       := wordx2cause(wcsr_in);

        when CSR_VSTVAL =>
          csr.vstval        := wcsr_in;

        when CSR_VSIP =>
          csr.mip(IRQ_VS_SOFTWARE)        := (csr_file.hvip(IRQ_VS_SOFTWARE) and
                                              not csr_file.hideleg(IRQ_VS_SOFTWARE)) or
                               (wcsr_in(IRQ_S_SOFTWARE) and csr_file.hideleg(IRQ_VS_SOFTWARE));
          if ext_shlcofideleg = 1 and (csr_file.hideleg(IRQ_LCOF) and csr_file.mideleg(IRQ_LCOF)) = '1' then
            csr.mip(IRQ_LCOF)  := wcsr_in(IRQ_LCOF);
          end if;
          -- So far only LCOF (13) bit in hvien is writable.
          -- This is the behavior for all interrupts above 13 if
          -- more are implemented in the future.
          for i in 13 to XLEN-1 loop
            if csr_file.hideleg(i) = '0' and
               (csr_file.hvien(i) and hvien_mask(ext_sscofpmf, ext_smcdeleg)(i)) = '1' then
              csr.hvip(i) := wcsr_in(i);
            end if;
          end loop;

        when CSR_VSISELECT =>
          csr.vsiselect     := wordx2selector(wcsr_in);

        when CSR_VSIREG =>
          if is_imsic(csr_file.vsiselect) then
            vimsici.vsireg_w  := '1';
            vimsici.vsireg    := wcsr_in;
          elsif is_smcdeleg(csr_file.vsiselect) then
            assert xc_in = '1' report "Reading smcdeleg VSIREG should always trap" severity failure;
          end if;

        when CSR_VSTOPEI =>
          vimsici.vstopei_w := '1';

        when CSR_VSATP =>
          csr.vsatp := to_vsatp(csr_file.vsatp, wcsr_in, csr_file.hgatp, false, XLEN, asidlen, physaddr, riscv_mmu);

        -- User Counters/Timers - see below

        -- Supervisor Trap Setup
        when CSR_VSTIMECMP =>
          csr.vstimecmp(wordx'range)    := wcsr_in;

        when CSR_VSTIMECMPH =>
          if is_rv32 then
            csr.vstimecmp(63 downto 32) := wcsr_in(word'range);
          end if;

        when CSR_SSTATUS =>
          if h_en and csr_file.v = '1' then
            if toggled_fpu(csr_file.vsstatus, wcsr_in) or toggled_custom(csr_file.vsstatus, wcsr_in) then
              pipeflush := '1';
            end if;
            csr.vsstatus    := to_vsstatus(wcsr_in,
                                           csr_file.vsstatus,
                                           csr_file.henvcfg.dte and csr_file.menvcfg.dte,
                                           csr_file.henvcfg.sse and csr_file.menvcfg.sse,
                                           to_bit(ext_zicfilp)
                                          );
          else
            if toggled_fpu(csr_file.mstatus, wcsr_in) or toggled_custom(csr_file.mstatus, wcsr_in) then
              pipeflush := '1';
            end if;
            mstatus         := to_sstatus(wcsr_in, csr_file.mstatus,
                                          csr_file.menvcfg.dte and to_bit(ext_ssdbltrp),
                                          csr_file.menvcfg.sse,
                                          to_bit(ext_zicfilp)
                                         );
            csr.mstatus := tie_status(active_extensions, mstatus, csr_file.misa);
          end if;


        when CSR_SIE =>
          -- mie(10) is aliased in hie(10) and vsie(9)
          -- mie(6)  is aliased in hie(6)  and vsie(5)
          -- mie(2)  is aliased in hie(2)  and vsie(1)
          if h_en and csr_file.v = '1' then
            if csr_file.hvictl.vti = '0' or (ext_smaia = 0 and ext_ssaia = 0) then
              csr.mie(IRQ_VS_EXTERNAL) := (csr_file.mie(IRQ_VS_EXTERNAL) and not csr_file.hideleg(IRQ_VS_EXTERNAL)) or
                                  (wcsr_in(IRQ_S_EXTERNAL) and csr_file.hideleg(IRQ_VS_EXTERNAL));
              csr.mie(IRQ_VS_TIMER)    := (csr_file.mie(IRQ_VS_TIMER) and not csr_file.hideleg(IRQ_VS_TIMER)) or
                                  (wcsr_in(IRQ_S_TIMER) and csr_file.hideleg(IRQ_VS_TIMER));
              csr.mie(IRQ_VS_SOFTWARE) := (csr_file.mie(IRQ_VS_SOFTWARE) and not csr_file.hideleg(IRQ_VS_SOFTWARE)) or
                                  (wcsr_in(IRQ_S_SOFTWARE) and csr_file.hideleg(IRQ_VS_SOFTWARE));
              if ext_shlcofideleg = 1 and ext_sscofpmf = 1 then
                if (csr_file.hideleg(IRQ_LCOF) and csr_file.mideleg(IRQ_LCOF)) = '1' then
                  csr.mie(IRQ_LCOF)  := wcsr_in(IRQ_LCOF);
                end if;
              end if;
              -- So far only LCOF (13) bit in hvien is writable.
              -- This is the behavior for all interrupts above 13 if
              -- more are implemented in the future.
              if ext_ssaia = 1 then
                for i in 13 to XLEN-1 loop
                  if csr_file.hideleg(i) = '0' and
                     (csr_file.hvien(i) and hvien_mask(ext_sscofpmf, ext_smcdeleg)(i)) = '1' then
                    csr.vsie(i) := wcsr_in(i);
                  end if;
                end loop;
              end if;

            else
              -- If tries to access SIE from VS-mode (VSIE) when VTI=1 raise
              -- a virtual instruction exception
            end if;
          else
            if ext_smaia = 1 then
              for i in 0 to XLEN-1 loop
                if csr_file.mideleg(i) = '0' and csr_file.mvien(i) = '1' then
                  csr.sie(i)    :=  wcsr_in(i);
                else
                  csr.mie(i)      := (csr_file.mie(i) and (not csr_file.mideleg(i) or CSR_HIE_MASK(i))) or
                                     (wcsr_in(i) and (csr_file.mideleg(i) and not CSR_HIE_MASK(i)));
                end if;
              end loop;
            else
              csr.mie         := (csr_file.mie and (not csr_file.mideleg or CSR_HIE_MASK)) or
                                 (wcsr_in and (csr_file.mideleg and not CSR_HIE_MASK));
            end if;
            end if;

        when CSR_STVEC =>
          if h_en and csr_file.v = '1' then
            csr.vstvec      := wcsr_in(csr.vstvec'high downto 2) & '0' & wcsr_in(0);
            if wcsr_in(0) = '1' then
              csr.vstvec    := wcsr_in(csr.vstvec'high downto 8) & "0000000" & wcsr_in(0);
            end if;
          else
            csr.stvec       := wcsr_in(csr.stvec'high downto 2) & '0' & wcsr_in(0);
            if wcsr_in(0) = '1' then
              csr.stvec     := wcsr_in(csr.stvec'high downto 8) & "0000000" & wcsr_in(0);
            end if;
          end if;

        when CSR_SSTATEEN0 =>
          csr.sstateen0 := stateen_wpri_write(wcsr_in,
                                              csr_file.sstateen0,
                                              csr_file.hstateen0 and csr_file.mstateen0,
                                              false);

        -- TODO: add other STATEEN registers

        when CSR_SISELECT =>
          if h_en and csr_file.v = '1' then
            csr.vsiselect   := wordx2selector(wcsr_in);
          else
            csr.siselect    := wordx2selector(wcsr_in);
          end if;

        when CSR_SIREG | CSR_SIREG2 | CSR_SIREG3 | CSR_SIREG4 | CSR_SIREG5 | CSR_SIREG6 =>
          if h_en and csr_file.v = '1' then
            if is_imsic(csr_file.vsiselect) and imsic = 1 and csra = CSR_SIREG then
              vimsici.vsireg_w := '1';
              vimsici.vsireg   := wcsr_in;
            elsif is_smcdeleg(csr_file.vsiselect) then
              assert xc_in = '1' report "VS/VU mode smcdeleg write should always trap" severity failure;
              -- smcdeleg_indirect_write(csra, wcsr_in, csr, upd_mcycle, upd_minstret, upd_counter);
            end if;
          else
            -- IPRIO array from supervisor level not implemented (major priorities have always default order)
            if is_imsic(csr_file.siselect) and imsic = 1 and csra = CSR_SIREG then
              vimsici.sireg_w  := '1';
              vimsici.sireg    := wcsr_in;
            elsif is_smcdeleg(csr_file.siselect) then
              smcdeleg_indirect_write(csra, wcsr_in, csr, upd_mcycle, upd_minstret, upd_counter);
            end if;
          end if;

        when CSR_STOPEI =>
          if h_en and csr_file.v = '1' then
            vimsici.vstopei_w  := '1';
          else
            vimsici.stopei_w   := '1';
          end if;

        when CSR_SCOUNTEREN =>
          if mode_u = 1 then
            csr.scounteren(HWPERFMONITORS + 2 downto 0) := wcsr_in(HWPERFMONITORS + 2 downto 0);
          end if;

        when CSR_SENVCFG =>
          if mode_u = 1 then
            csr.senvcfg     := calc_senvcfg_write_val(wcsr_in, active_henvcfg, active_senvcfg, csr_file);
          end if;
        when CSR_SCOUNTINHIBIT =>
          csr.mcountinhibit := to_scountinhibit(csr_file.mcountinhibit, csr_file.mcounteren, wcsr_in);
        -- Supervisor Trap Handling
        when CSR_SSCRATCH =>
          if h_en and csr_file.v = '1' then
            csr.vsscratch   := wcsr_in;
          else
            csr.sscratch    := wcsr_in;
          end if;

        when CSR_SEPC =>
          if h_en and csr_file.v = '1' then
            csr.vsepc       := wcsr_in(csr.sepc'high downto 1) & '0';
            if ext_c = 0 then
              csr.vsepc(1)  := '0';
            end if;
          else
            csr.sepc        := wcsr_in(csr.sepc'high downto 1) & '0';
            if ext_c = 0 then
              csr.sepc(1)   := '0';
            end if;
          end if;

        when CSR_SCAUSE =>
          if h_en and csr_file.v = '1' then
            csr.vscause     := wordx2cause(wcsr_in);
          else
            csr.scause      := wordx2cause(wcsr_in);
          end if;

        when CSR_STVAL =>
          if h_en and csr_file.v = '1' then
            csr.vstval      := wcsr_in;
          else
            csr.stval       := wcsr_in;
          end if;

        when CSR_SIP =>
          if h_en and csr_file.v = '1' then
            -- hideleg(2) always 1 when hypervisor extension is enabled
            -- mip(2) is aliased in hip(2), hvip(2) and vsip(1)
            if csr_file.hideleg(IRQ_VS_SOFTWARE) = '1' then
              csr.mip(IRQ_VS_SOFTWARE)    := wcsr_in(IRQ_S_SOFTWARE);
            end if;
            if ext_shlcofideleg = 1 and (csr_file.hideleg(IRQ_LCOF) and csr_file.mideleg(IRQ_LCOF)) = '1' then
              csr.mip(IRQ_LCOF)  := wcsr_in(IRQ_LCOF);
            end if;
            -- So far only LCOF (13) bit in hvien is writable.
            -- This is the behavior for all interrupts above 13 if
            -- more are implemented in the future.
            for i in 13 to XLEN-1 loop
              if csr_file.hideleg(i) = '0' and
                 (csr_file.hvien(i) and hvien_mask(ext_sscofpmf, ext_smcdeleg)(i)) = '1' then
                csr.hvip(i) := wcsr_in(i);
              end if;
            end loop;
          else
            if csr_file.mideleg(IRQ_S_SOFTWARE) = '1' then -- Only visible in SIP when delegated
              csr.mip(IRQ_S_SOFTWARE)    := wcsr_in(IRQ_S_SOFTWARE);   -- Others RO
            elsif ext_smaia = 1 and csr_file.mvien(IRQ_S_SOFTWARE) = '1' then
              csr.mvip(IRQ_S_SOFTWARE)   :=  wcsr_in(IRQ_S_SOFTWARE);
            end if;
            if ext_sscofpmf = 1 and csr_file.mideleg(IRQ_LCOF) = '1' then
              csr.mip(IRQ_LCOF)     := wcsr_in(IRQ_LCOF);
            end if;
            -- All interrupts above 12 behave in the same way in mvip. However so far only
            -- LCOF is defined in that range. In the future new interrupts can be added to
            -- mvien_mask.
            if ext_smaia = 1 then
              for i in 13 to XLEN-1 loop
                if csr_file.mideleg(i) = '0' and
                   (csr_file.mvien(i) and mvien_mask(ext_sscofpmf, ext_smcdeleg)(i)) = '1' then
                  csr.mvip(i) := wcsr_in(i);
                end if;
              end loop;
            end if;
          end if;

        -- Supervisor Protection and Translation
        when CSR_SATP =>
          -- Assume value is OK
          if h_en and csr_file.v = '1' then
            csr.vsatp := to_vsatp(csr_file.vsatp, wcsr_in, csr_file.hgatp, true, XLEN, asidlen, physaddr, riscv_mmu);
          else
            csr.satp := to_satp(csr_file.satp, wcsr_in, XLEN, asidlen, physaddr, riscv_mmu);
          end if;

        when CSR_STIMECMP =>
          if h_en and csr_file.v = '1' then
            csr.vstimecmp(wordx'range)    := wcsr_in;
          else
            csr.stimecmp(wordx'range)     := wcsr_in;
          end if;

        when CSR_STIMECMPH =>
          if is_rv32 then
            if h_en and csr_file.v = '1' then
              csr.vstimecmp(63 downto 32)    := wcsr_in(word'range);
            else
              csr.stimecmp(63 downto 32)     := wcsr_in(word'range);
            end if;
          end if;

        -- Machine Trap Setup
        when CSR_MSTATUS =>
          if toggled_fpu(csr_file.mstatus, wcsr_in) or toggled_custom(csr_file.mstatus, wcsr_in) then
            pipeflush := '1';
          end if;
          mstatus           := to_mstatus(wcsr_in, csr_file.mstatus, to_bit(ext_smdbltrp), to_bit(ext_ssdbltrp));
          csr.mstatus       := tie_status(active_extensions, mstatus, csr_file.misa);

        when CSR_MSTATUSH =>
          if is_rv32 then
            mstatus         := to_mstatush(wcsr_in, csr_file.mstatus, h_en, to_bit(ext_smdbltrp));
            csr.mstatus     := tie_status(active_extensions, mstatus, csr_file.misa);
          end if;

        when CSR_MISA =>
          if misa_ctrl then
            -- If changing C extension support is possible,
            -- do not allow turning it off on an unaligned PC.
            -- Specification says that MISA write must then be ignored.
            if ISA_CONTROL(c_ctrl) = '0' or csr_file.misa(c_ctrl) = '0' or
               wcsr_in(c_ctrl) = '1' or pc_in(1 downto 0) = "00" then
              csr.misa      := mask_misa(csr_file.misa, wcsr_in);
            end if;
            -- If MISA is changed, a pipeline flush is required.
            if csr.misa /= csr_file.misa then
              pipeflush     := '1';
            end if;
          end if;

        when CSR_MEDELEG =>
          csr.medeleg       := wcsr_in and medeleg_mask(h_en);

        when CSR_MIDELEG =>
          csr.mideleg       := to_mideleg(wcsr_in, mode_s = 1, h_en,
                                          ext_sscofpmf = 1);

        when CSR_MIDELEGH =>

        when CSR_MIE =>
          csr.mie           := wcsr_in and mie_mask(mode_s = 1, h_en, ext_sscofpmf = 1);

        when CSR_MIEH =>

        when CSR_MTVEC =>
          mtvec             := wcsr_in(mtvec'high downto 2) & '0' & wcsr_in(0);
          if wcsr_in(0) = '1' then
            mtvec           := wcsr_in(mtvec'high downto 8) & "0000000" & wcsr_in(0);
          end if;
          csr.mtvec         := mtvec;

        when CSR_MCOUNTEREN =>
          csr.mcounteren(HWPERFMONITORS + 2 downto 0) := wcsr_in(HWPERFMONITORS + 2 downto 0);

        -- Machine Trap Handling
        when CSR_MSCRATCH =>
          csr.mscratch      := wcsr_in;

        when CSR_MEPC =>
          csr.mepc          := wcsr_in(csr.mepc'high downto 1) & '0';
          if ext_c = 0 then
            csr.mepc(1)     := '0';
          end if;

        when CSR_MNSCRATCH =>
          csr.mnscratch     := wcsr_in;

        when CSR_MNEPC =>
          csr.mnepc         := wcsr_in(csr.mnepc'high downto 1) & '0';
          if ext_c = 0 then
            csr.mnepc(1)    := '0';
          end if;

        when CSR_MNCAUSE =>
          csr.mncause       := wordx2cause(wcsr_in);

        when CSR_MNSTATUS =>
          csr.mnstatus      := to_mnstatus(wcsr_in, csr.mnstatus, active_extensions, csr_file.misa);

        when CSR_MSTATEEN0 =>
          csr.mstateen0     := CSR_MSTATEEN0_MASK and to_mstateen0(wcsr_in, csr.mstateen0);

        when CSR_MSTATEEN1 =>
          if is_rv64 then
            csr.mstateen1.stateen  := wcsr_in(wordx'length - 1);
          end if;

        when CSR_MSTATEEN2 =>
          if is_rv64 then
            csr.mstateen2.stateen  := wcsr_in(wordx'length - 1);
          end if;

        when CSR_MSTATEEN3 =>
          if is_rv64 then
            csr.mstateen3.stateen  := wcsr_in(wordx'length - 1);
          end if;

        when CSR_MSTATEEN0H =>
          csr.mstateen0            := CSR_MSTATEEN0_MASK and to_mstateen0h(wcsr_in, csr.mstateen0);

        when CSR_MSTATEEN1H =>
          csr.mstateen1.stateen    := wcsr_in(31);

        when CSR_MSTATEEN2H =>
          csr.mstateen2.stateen    := wcsr_in(31);

        when CSR_MSTATEEN3H =>
          csr.mstateen3.stateen    := wcsr_in(31);


        when CSR_MISELECT =>
          csr.miselect      := wordx2selector(wcsr_in);

        when CSR_MIREG =>
          if not is_custom(csr_file.miselect) then
            -- IPRIO array from machine level not implemented (major priorities have always default order)
            if is_imsic(csr.miselect) and imsic = 1 then
              vimsici.mireg_w    := '1';
              vimsici.mireg      := wcsr_in;
            end if;
          else
            if ext_smcsrind = 1 then
            end if;
          end if;

      when CSR_MIREG2 =>
        if ext_smcsrind = 1 then -- Otherwise xc is always set to 1 before
          if not is_custom(csr.miselect) then
            -- Currently no standard registers defined
          else
          end if;
        end if;

        when CSR_MTOPEI =>
          vimsici.mtopei_w     := '1';

        when CSR_MVIEN =>
          csr.mvien         := wcsr_in and mvien_mask(ext_sscofpmf, ext_smcdeleg);
        when CSR_MVIENH =>
        when CSR_MVIP =>
          -- When bit 1 of mvien is zero, bit 1 of mvip is an alias of the
          -- same bit (SSIP) of mip. But when bit 1 of mvien is one, bit 1
          -- of mvip is a separate writable bit independent of mip.SSIP.
          if csr_file.mvien(1) = '1' then
            csr.mvip(1)     := wcsr_in(1);
          else
            csr.mip(1)      := wcsr_in(1);
          end if;
          -- Bit 5 of mvip is an alias of the same bit (STIP) in mip when
          -- that bit is writable in mip. When STIP is not writable in
          -- mip(such as when menvcfg.STCE = 1), bit 5 of mvip is read-only zero.
          if not(ext_sstc = 1 and csr_file.menvcfg.stce = '1') then
            csr.mip(5)      := wcsr_in(5);
          end if;
          -- When bit 9 of mvien is zero, bit 9 of mvip is an alias of the
          -- software-writable bit 9 of mip (SEIP). But when bit 9 of mvien
          -- is one, bit 9 of mvip is a writable bit independent of mip.SEIP.
          if csr_file.mvien(9) = '1' then
            csr.mvip(9)     := wcsr_in(9);
          else
            csr.mip(9)      := wcsr_in(9);
          end if;

          -- So far only LCOF interrupt is defined in interrupts from 13 to 63. To add new interrupt
          -- inside this range, mvien_mask has to be modified
          csr.mvip(XLEN-1 downto 13) := wcsr_in(XLEN-1 downto 13) and
                                        mvien_mask(ext_sscofpmf, ext_smcdeleg)(XLEN-1 downto 13);



        when CSR_MVIPH =>
        when CSR_MCAUSE =>
          csr.mcause        := wordx2cause(wcsr_in);

        when CSR_MTVAL =>
          csr.mtval         := wcsr_in;

        when CSR_MIP =>
          csr.mip           := wcsr_in and mip_mask(mode_s = 1, h_en,
                                                    ext_sscofpmf = 1,
                                                    csr_file.menvcfg.stce);

        when CSR_MIPH =>

        when CSR_MTINST =>
          csr.mtinst       := wcsr_in;

        when CSR_MTVAL2 =>
          csr.mtval2        := wcsr_in;
        -- Machine Configuration

        when CSR_MENVCFG =>
          csr.menvcfg       := to_envcfg(wcsr_in, csr_file.menvcfg, active_menvcfg);

        when CSR_MENVCFGH =>
          if is_rv32 then
            csr.menvcfg     := to_envcfgh(wcsr_in, csr_file.menvcfg, active_menvcfg);
          end if;

        when CSR_MSECCFG =>
          if ext_smepmp = 1
             or ext_zicfilp = 1
             then
            mseccfg         := to_mseccfg(wcsr_in, csr_file.mseccfg);
            csr.mseccfg     := tie_mseccfg(mseccfg);
          end if;

        when CSR_MSECCFGH =>
          if is_rv32 and (
             ext_zicfilp = 1 or
             ext_smepmp = 1) then
            mseccfg         := to_mseccfgh(wcsr_in, csr_file.mseccfg);
            csr.mseccfg     := tie_mseccfg(mseccfg);
          end if;

        -- Machine Protection and Translation
        when CSR_PMPCFG0 =>
          if pmp_entries /= 0 then
            if is_rv64 then
              pmpcfg_write(csr_file, 0, 7, wcsr_in, csr.pmpcfg, pipeflush);
            else
              -- Less data in writes to PMPCFG0/2.
              pmpcfg_write(csr_file, 0, 3, wcsr_in, csr.pmpcfg, pipeflush);
            end if;
          end if;

        when CSR_PMPCFG1 =>
          if pmp_entries /= 0 and is_rv32 then
            pmpcfg_write(csr_file, 4, 7, wcsr_in, csr.pmpcfg, pipeflush);
          end if;

        when CSR_PMPCFG2 =>
          if pmp_entries /= 0 then
            if is_rv64 then
              pmpcfg_write(csr_file, 8, 15, wcsr_in, csr.pmpcfg, pipeflush);
            else
              pmpcfg_write(csr_file, 8, 11, wcsr_in, csr.pmpcfg, pipeflush);
            end if;
          end if;

        when CSR_PMPCFG3 =>
          if pmp_entries /= 0 and is_rv32 then
            pmpcfg_write(csr_file, 12, 15, wcsr_in, csr.pmpcfg, pipeflush);
          end if;

        -- Machine Counter/Timers
        when CSR_MCYCLE =>
          csr.mcycle(wordx'range)      := wcsr_in;
          upd_mcycle                   := '1';

        when CSR_MCYCLEH =>
          if is_rv32 then
            csr.mcycle(63 downto 32)   := wcsr_in(word'range);
            upd_mcycle                 := '1';
          end if;

        when CSR_MINSTRET =>
          csr.minstret(wordx'range)    := wcsr_in;
          upd_minstret                 := '1';

        when CSR_MINSTRETH =>
          if is_rv32 then
            csr.minstret(63 downto 32) := wcsr_in(word'range);
            upd_minstret               := '1';
          end if;

        -- Machine Hardware Performance Monitoring Event Selector
        when CSR_MCOUNTINHIBIT =>
          csr.mcountinhibit(0)                      := wcsr_in(0);
          csr.mcountinhibit(31 downto 2)            := wcsr_in(31 downto 2);
        -- Debug/Trace Registers

        when CSR_TSELECT =>
          csr.tcsr.tselect := tselect_write(wcsr_in);

        when CSR_TDATA1 =>
          tdata_write(csr_file.tcsr, 1, rstate_in, h_en, wcsr_in, csr.tcsr);

        when CSR_TDATA2 =>
          tdata_write(csr_file.tcsr, 2, rstate_in, h_en, wcsr_in, csr.tcsr);

        when CSR_TDATA3 =>
          tdata_write(csr_file.tcsr, 3, rstate_in, h_en, wcsr_in, csr.tcsr);
        when CSR_HCONTEXT       =>
          csr.tcsr.mhcontext                       := to_mhcontext(wcsr_in, h_en);
        when CSR_MCONTEXT       =>
          csr.tcsr.mhcontext                       := to_mhcontext(wcsr_in, h_en);
        when CSR_SCONTEXT       =>
          csr.tcsr.scontext                        := to_scontext(wcsr_in);
        -- Core Debug Registers

        when CSR_DCSR =>
          if rstate_in /= run then
            if ext_smdbltrp = 1 then
              csr.dcsr.cetrig                       := wcsr_in(19);
            end if;
            if ext_zicfilp = 1 then
              csr.dcsr.pelp                         := wcsr_in(18);
            end if;
            if h_en then
              csr.dcsr.ebreakvs                     := wcsr_in(17);
              csr.dcsr.ebreakvu                     := wcsr_in(16);
            end if;
            csr.dcsr.ebreakm                        := wcsr_in(15);
            csr.dcsr.ebreaks                        := wcsr_in(13);
            csr.dcsr.ebreaku                        := wcsr_in(12);
            csr.dcsr.stepie                         := wcsr_in(11);
            csr.dcsr.stopcount                      := wcsr_in(10);
            csr.dcsr.stoptime                       := wcsr_in(9);
            if h_en then
              csr.dcsr.v                            := wcsr_in(5);
            end if;
            csr.dcsr.step                           := wcsr_in(2);
            if wcsr_in(1 downto 0) /= "10" then
              csr.dcsr.prv                          := wcsr_in(1 downto 0);
            end if;
          end if;

        when CSR_DPC =>
          if rstate_in /= run then
            csr.dpc                                 := wcsr_in;
          end if;

        when CSR_DSCRATCH0 =>
          if rstate_in /= run then
            csr.dscratch0                           := wcsr_in;
          end if;

        when CSR_DSCRATCH1 =>
          if rstate_in /= run then
            csr.dscratch1                           := wcsr_in;
          end if;

        -- Custom Read/Write Registers
        when CSR_FEATURES =>
          if ext_noelv = 1 then
            csr.dfeaturesen.tpbuf_en                := wcsr_in(31);
            csr.trace.ctrl(12 downto 8)             := wcsr_in(30 downto 26);
            -- [25:21] RESERVED
            csr.dfeaturesen.pma_fault_46            := wcsr_in(21);
            csr.dfeaturesen.pma_fault_02            := wcsr_in(20);
            csr.dfeaturesen.hpmc_mode               := wcsr_in(19);
            csr.dfeaturesen.diag_s                  := wcsr_in(18);
            csr.dfeaturesen.x0                      := wcsr_in(17);
            csr.dfeaturesen.mmu_oldfence            := wcsr_in(16);
            csr.dfeaturesen.mmu_hptfault            := wcsr_in(15);
            csr.dfeaturesen.mmu_sptfault            := wcsr_in(14);
            csr.dfeaturesen.dm_trace                := wcsr_in(13);
            csr.dfeaturesen.fs_dirty                := wcsr_in(11);
            csr.dfeaturesen.nostream                := wcsr_in(10);
            csr.dfeaturesen.staticdir               := wcsr_in(9);
            csr.dfeaturesen.staticbp                := wcsr_in(8);
            csr.dfeaturesen.h_ade                   := wcsr_in(7);
            csr.dfeaturesen.b2bst_dis               := wcsr_in(6);
            csr.dfeaturesen.lalu_dis                := wcsr_in(5);
            csr.dfeaturesen.lbranch_dis             := wcsr_in(4);
            csr.dfeaturesen.ras_dis                 := wcsr_in(3);
            csr.dfeaturesen.jprd_dis                := wcsr_in(2);
            csr.dfeaturesen.btb_dis                 := wcsr_in(1);
            csr.dfeaturesen.dual_dis                := wcsr_in(0);
          end if;

        when CSR_FEATURESH =>
          if is_rv32 and ext_noelv = 1 then
          end if;

        when CSR_CCTRL =>
          if ext_noelv = 1 then
            -- Bit[11] is RESERVED
            if itcmen = 1 then
              csr.cctrl.itcmwipe                    := wcsr_in(10);
            end if;
            if dtcmen = 1 then
              csr.cctrl.dtcmwipe                    := wcsr_in(9);
            end if;
            csr.cctrl.dsnoop                        := wcsr_in(8);
            csr.cctrl.dflush                        := wcsr_in(7);
            csr.cctrl.iflush                        := wcsr_in(6);
            -- Bit[5:4] is RESERVED
            csr.cctrl.dcs                           := wcsr_in(3 downto 2);
            csr.cctrl.ics                           := wcsr_in(1 downto 0);
          end if;

        when CSR_TCMICTRL =>
          if ext_noelv = 1 then
          end if;

        when CSR_TCMDCTRL =>
          if ext_noelv = 1 then
          end if;

        when CSR_SSP =>
          if ext_zicfiss = 1 then
            if is_rv64 then
              case csr_special is
                when "10"   => csr.ssp := uadd(csr_file.ssp, 8);
                when "11"   => csr.ssp := uadd(csr_file.ssp, -8);
--                when "01"   => -- Update disabled due to access fault
                when others => csr.ssp := wcsr_in(csr.ssp'high downto 3) & "000";
              end case;
            else
              case csr_special is
                when "10"   => csr.ssp := uadd(csr_file.ssp, 4);
                when "11"   => csr.ssp := uadd(csr_file.ssp, -4);
--                when "01"   => -- Update disabled due to access fault
                when others => csr.ssp := wcsr_in(csr.ssp'high downto 2) & "00";
              end case;
            end if;
          end if;



        when others =>
          case csra_high is
            -- Machine Hardware Performance Monitoring

            when CSR_MCYCLE =>         -- Base for counters.
              -- CSR_(M)HPMCOUNTER3-15  (0-2 never _ok here!)
              if counter_ok(csra_ilo) = '1' then
                csr.hpmcounter(csra_ilo)(wordx'range) := wcsr_in;
                upd_counter(csra_ilo)                 := '1';
              end if;
            when CSR_MCYCLEH =>        -- Base for counters.
              -- CSR_(M)HPMCOUNTER3-15H  (0-2 never _ok here!)
              if is_rv32 and counter_ok(csra_ilo) = '1' then
                csr.hpmcounter(csra_ilo)(63 downto 32) := wcsr_in(word'range);
                upd_counter(csra_ilo)                  := '1';
              end if;
            -- Machine Hardware Performance Monitoring (continued)
            when CSR_MHPMCOUNTER16 =>  -- All the higher counters.
              -- CSR_(M)HPMCOUNTER16-31
              if counter_ok(csra_ilo + 16) = '1' then
                csr.hpmcounter(csra_ilo + 16)(wordx'range) := wcsr_in;
                upd_counter(csra_ilo + 16)                 := '1';
              end if;
            when CSR_MHPMCOUNTER16H => -- All the higher counters.
              -- CSR_(M)HPMCOUNTER16-31H
              if is_rv32 and counter_ok(csra_ilo + 16) = '1' then
                csr.hpmcounter(csra_ilo + 16)(63 downto 32) := wcsr_in(word'range);
                upd_counter(csra_ilo + 16)                  := '1';
              end if;
            -- Machine Hardware Performance Monitoring Event Selector
            when CSR_MCOUNTINHIBIT =>  -- MCOUNTINHIBIT/MHPMEVENT3-15
              -- CSR_MHPMEVENT3-31  (0-2 never _ok here!)
              if counter_ok(csra_ilo) = '1' then
                hpmevent               := to_hpmevent(wcsr_in, csr_file.hpmevent(csra_ilo));
                csr.hpmevent(csra_ilo) := tie_hpmevent(hpmevent, csr_file.misa);
              end if;
            when CSR_MHPMEVENT16 =>    -- MHPMEVENT16-31
              if counter_ok(csra_ilo + 16) = '1' then
                hpmevent                    := to_hpmevent(wcsr_in, csr_file.hpmevent(csra_ilo + 16));
                csr.hpmevent(csra_ilo + 16) := tie_hpmevent(hpmevent, csr_file.misa);
              end if;
            when CSR_MHPMEVENT0H =>  -- MHPMEVENT3-15H
              -- CSR_MHPMEVENT3-31H  (0-2 never _ok here!)
              if is_rv32 and counter_ok(csra_ilo) = '1' then
                hpmevent               := to_hpmeventh(wcsr_in, csr_file.hpmevent(csra_ilo));
                csr.hpmevent(csra_ilo) := tie_hpmevent(hpmevent, csr_file.misa);
              end if;
            when CSR_MHPMEVENT16H =>    -- MHPMEVENT16-31H
              if is_rv32 and counter_ok(csra_ilo + 16) = '1' then
                hpmevent                    := to_hpmeventh(wcsr_in, csr_file.hpmevent(csra_ilo + 16));
                csr.hpmevent(csra_ilo + 16) := tie_hpmevent(hpmevent, csr_file.misa);
              end if;
            when CSR_PMPADDR0 =>
              if pmp_entries /= 0 and
                 pmp_locked(csr, csra_ilo) = '0' and             -- Not locked?
                 (csra_ilo = 15 or
                  not (pmp_locked(csr, csra_ilo + 1) = '1' and   -- Neither is next TOR and locked?
                       pmpcfg(pmp_entries, csr.pmpcfg, csra_ilo + 1, 3, 2) = "01")) then
                csr.pmpaddr(csra_ilo) := (others => '0');
                set_lo(csr.pmpaddr(csra_ilo), wcsr_in(pmp_msb - 2 downto 0));
              end if;
            when others =>
              null;
          end case;
      end case;
    end if;




    pipeflush_out     := pipeflush;
    addrflush_out     := addrflush;
    csr_out           := csr;
    imsici_out        := vimsici;
    upd_mcycle_out    := upd_mcycle;
    upd_minstret_out  := upd_minstret;
    upd_counter_out   := upd_counter;
  end;

  -- Instruction Control Unit
  -- Note that both v_fusel_eq(r, stage, lane, fusel) and v_rd_eq(r, stage, lane, rs)
  -- verify that the instruction in that stage and lane is actually valid.
  procedure instruction_control(r           : in    registers;
                                fpu_ready   : in    std_ulogic;
                                fpu_idle    : in    std_ulogic;
                                lddp        : out   std_ulogic;
                                sdb2b       : out   std_ulogic;
                                lbrancho    : out   std_ulogic;
                                laluo       : out   fetch_pair;
                                spec_ldo    : out   std_ulogic;
                                accesshold  : inout std_logic_vector;
                                hpmchold    : inout std_logic_vector;
                                exechold    : inout std_logic_vector;
                                fpuhold     : inout std_logic_vector;
                                tracehold   : inout std_logic_vector;
                                holdi       : out   std_ulogic) is

    -- Non-constant
    variable hold          : std_ulogic    := '0';
    variable hvec          : word16        := (others => '0');  -- Only for debug
    variable lbranch       : std_ulogic    := '0';
    variable lbranchdp     : std_ulogic    := '0';
    variable lcsr          : fetch_pair    := (others => '0');
    variable lalu          : fetch_pair    := (others => '0');
    variable laludp        : std_ulogic    := '0';  -- Lane 1 is dependent on lane 0 (no swap)
    variable extrahold_out : std_ulogic    := '0';
  begin
    lddp     := '0';
    sdb2b    := '0';
    spec_ldo := '0';

    ---------------------------------------------------------------------------
    -- Late Branch Flag Generation
    ---------------------------------------------------------------------------

    -- Late Branch due to load dependency
    --      0           1
    -- A    *           BRANCH <- Rn
    -- EX   LD -> Rn    *
    if v_fusel_eq(r, e, memory_lane, LD) then
      if v_fusel_eq(r, a, branch_lane, BRANCH) then
        if v_rd_eq(r, e, memory_lane, r.a.rfa1(branch_lane)) or
           v_rd_eq(r, e, memory_lane, r.a.rfa2(branch_lane)) then
          lbranch     := '1';
        end if;
      end if;
    end if;

    -- Late Branch due to late ALUs
    --      0                     1
    -- A    *                     BRANCH <- Rn
    -- EX   any -> Rn (late)  or  any -> Rn (late)
    -- This now needs to be checked due to late CSR!
    if late_alu = 1 then
      if v_fusel_eq(r, a, branch_lane, BRANCH) then
        for i in lanes'range loop
          -- LALU in execution stage
          if r.e.alu(i).lalu = '1' then
            if v_rd_eq(r, e, i, r.a.rfa1(branch_lane)) or
               v_rd_eq(r, e, i, r.a.rfa2(branch_lane)) then
              lbranch := '1';
            end if;
          end if;
        end loop;
      end if;
    else
      -- lalu here is guaranteed to be due to CSR.
      if v_fusel_eq(r, a, branch_lane, BRANCH) then
        -- LALU in execution stage
        if r.e.alu(csr_lane).lalu = '1' then
          if v_rd_eq(r, e, csr_lane, r.a.rfa1(branch_lane)) or
             v_rd_eq(r, e, csr_lane, r.a.rfa2(branch_lane)) then
            lbranch   := '1';
          end if;
        end if;
      end if;
    end if;

    -- Late Branch due to lane dependency
    --      0                  1
    -- A    ALU,MUL,LD         BRANCH <- Rn   (no swap)
    -- If there is a swap it is not actually a dependency.
    if v_fusel_eq(r, a, 0, ALU or MUL or LD or FPU
    ) then
      if v_fusel_eq(r, a, branch_lane, BRANCH) and r.a.swap = '0' then
        if v_rd_eq(r, a, 0, r.a.rfa1(branch_lane)) or
           v_rd_eq(r, a, 0, r.a.rfa2(branch_lane)) then
          lbranch     := '1';
          lbranchdp   := '1';
        end if;
      end if;
    end if;


    ---------------------------------------------------------------------------
    -- Late ALUs Flag Generation
    ---------------------------------------------------------------------------

    -- Note that these are directly releated to the stuff in late_alu_precheck()!

    -- This is an implicit "late ALU"!
    if csr_ok(r, a) then
      lcsr(csr_lane) := '1';
    end if;

    -- Lane 0: LD/ALU
    -- Lane 1: ALU
    --      0                  1
    -- A    ALU,LD,MUL -> Rn   ALU <- Rn   (no swap)
    -- If there is a swap it is not actually a dependency.
    if v_fusel_eq(r, a, 0, ALU or LD or MUL or FPU
    )  then
      if single_issue = 0 and
         v_fusel_eq(r, a, one, ALU) and r.a.ctrl(one).rdv = '1' and r.a.swap = '0' then
        if v_rd_eq(r, a, 0, r.a.rfa1(one)) or
           v_rd_eq(r, a, 0, r.a.rfa2(one)) then
          lalu(one)   := '1';
          laludp      := '1';
        end if;
      end if;
    end if;

    -- Lane 0: ALU | LD
    -- Lane 1: ALU
    --      0                  1
    -- A    ALU <- Rn  or      ALU <- Rn
    -- EX   LD -> Rn           *
    if v_fusel_eq(r, e, 0, LD) then
      for i in lanes'range loop
        if v_fusel_eq(r, a, i, ALU) then
          if v_rd_eq(r, e, 0, r.a.rfa1(i)) or
             v_rd_eq(r, e, 0, r.a.rfa2(i)) then
            lalu(i)   := '1';
          end if;
        end if;
      end loop;
    end if;

    -- Lane 0: ALU | MUL
    -- Lane 1: ALU
    --      0                  1
    -- A    ALU <- Rn  or      ALU <- Rn   (unless non-dependent lane is MUL)
    -- EX   MUL -> Rn  or      MUL -> Rn
    for j in lanes'range loop
      if v_fusel_eq(r, e, j, MUL) then
        for i in lanes'range loop
          if v_fusel_eq(r, a, i, ALU) and not v_fusel_eq(r, a, lanes'high - i, MUL) then
            if v_rd_eq(r, e, j, r.a.rfa1(i)) or
               v_rd_eq(r, e, j, r.a.rfa2(i)) then
              lalu(i) := '1';
            end if;
          end if;
        end loop;
      end if;
    end loop;

    -- In case previous instructions use late ALUs, drive this one to them as well
    --      0                     1
    -- A    ALU <- Rn         or  ALU <- Rn
    -- EX   any -> Rn (late)  or  any -> Rn (late)
    for j in lanes'range loop
      if r.e.alu(j).lalu = '1' then
        for i in lanes'range loop
          if v_rd_eq(r, e, j, r.a.rfa1(i)) or
             v_rd_eq(r, e, j, r.a.rfa2(i)) then
            if r.a.ctrl(i).valid = '1' and v_fusel_eq(r, a, i, ALU) then
              lalu(i) := '1';
            end if;
          end if;
        end loop;
      end if;
    end loop;

    -- Some ALU instructions can never be handled in the late ALUs!
    -- Besides the "special ALUs" this includes LPAD (Zicfilp).
    for j in lanes'range loop
      if lalu(j) = '1' then
        if v_fusel_eq(r, a, j, ALU_SPECIAL)
           or (v_fusel_eq(r.x.ctrl(j).fusel, CFI) and v_fusel_eq(r.x.ctrl(j).fusel, ALU))
           then
          hold    := '1';
          lalu(j) := '0';
        end if;
      end if;
    end loop;

    ---------------------------------------------------------------------------
    -- Late ALUs Dependency, stall FETCH/DECODE/REGISTER ACCESS/EXECUTE
    ---------------------------------------------------------------------------

    -- A stage internal dependency cannot be handled if lane 0 must use late ALU.
    if single_issue = 0 and
       (((laludp = '1' or lbranchdp = '1') and lalu(0) = '1') or
        -- Late branch and store, hold and drive branch to execute branch unit
        -- Note that this is with swap, so the store is really after the branch,
        -- and thus cannot be allowed to happen (which it would if late branch).
        (v_fusel_eq(r, a, memory_lane, ST) and lbranch = '1' and r.a.swap = '1') or
        -- Attempted late ALU in lane 1 and its destination equals store (lane 0)
        -- source, with swap so the store is really after the ALU. Thus, the
        -- calculated value should be stored (which it cannot if late ALU).
        -- lalu(one) = '1' implies that the instruction at A(1) must be valid.
        (v_fusel_eq(r, a, memory_lane, ST) and lalu(one) = '1' and rd(r, a, 1) = r.a.rfa2(memory_lane) and r.a.swap = '1') or
        -- CSR (which is late) is not an issue in lane 0 (since same lane as store).
        (v_fusel_eq(r, a, memory_lane, ST) and lcsr(1) = '1' and rd(r, a, 1) = r.a.rfa2(memory_lane) and r.a.swap = '1')) then
      hold    := '1';
      hvec(0) := '1';
      -- Divert to early alu in case the other want to address it
      lalu(0) := '0';  -- This is for the first case.
      lbranch := '0';  -- This is for the second case.
      lddp    := '1';
    end if;

    -- If instructions that cannot be late depend on late ALU results, stall the pipeline.
    --      0                     1
    -- A    non-late <- Rn    or  non-late <- Rn
    -- EX   any -> Rn (late)  or  any -> Rn (late)
    if late_alu = 1 then
      for j in lanes'range loop
        if r.e.alu(j).lalu = '1' then
          for i in lanes'range loop
            if (v_rd_eq(r, e, j, r.a.rfa1(i)) or
                v_rd_eq(r, e, j, r.a.rfa2(i))) and
              -- If there is no late branch unit, that must also cause stall.
               ((late_branch = 0 and v_fusel_eq(r, a, i, BRANCH)) or
                v_fusel_eq(r, a, i, NOT_LATE)) then
              hold    := '1';
              hvec(1) := '1';
              lddp    := '1';
            end if;
          end loop;
        end if;
      end loop;
    else
      -- Without late_alu there's still CSR handled in the exception stage.
      if r.e.alu(csr_lane).lalu = '1' then
        for i in lanes'range loop
          if (v_rd_eq(r, e, csr_lane, r.a.rfa1(i)) or
              v_rd_eq(r, e, csr_lane, r.a.rfa2(i))) and
              -- If there is a late branch unit, that need not cause stall.
              not (late_branch = 1 and v_fusel_eq(r, a, i, BRANCH)) then
            hold      := '1';
            hvec(1)   := '1';
            lddp      := '1';
          end if;
        end loop;
      end if;
    end if;

    -- Check if there are any dependencies between MEM and RA stages,
    -- If there is a dependency on a late operation in the memory stage,
    -- the pipeline must be held so that it can reach the exception stage
    -- and be calculated.
    -- There is no need to wait in the case of a store, since that value
    -- is not needed until one cycle later.
    if late_alu = 1 then
      for j in lanes'range loop
        if r.m.alu(j).lalu = '1' then
          for i in lanes'range loop
            if r.a.ctrl(i).valid = '1' then
              if (v_rd_eq(r, m, j, r.a.rfa1(i))) or (v_rd_eq(r, m, j, r.a.rfa2(i)) and
                not v_fusel_eq(r, a, i, ST)) then
                hold    := '1';
                hvec(2) := '1';
                lddp    := '1';
              end if;
            end if;
          end loop;
        end if;
      end loop;
    else
      -- Without late_alu there's still CSR handled in the exception stage.
      if r.m.alu(csr_lane).lalu = '1' then
        for i in lanes'range loop
          if r.a.ctrl(i).valid = '1' then
            if (v_rd_eq(r, m, csr_lane, r.a.rfa1(i))) or (v_rd_eq(r, m, csr_lane, r.a.rfa2(i)) and
              not v_fusel_eq(r, a, i, ST)) then
              hold      := '1';
              hvec(2)   := '1';
              lddp      := '1';
            end if;
          end if;
        end loop;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Load Data Dependency, stall FETCH/DECODE/REGISTER ACCESS/EXECUTE
    ---------------------------------------------------------------------------
    -- The cases with LD in EX followed by BRANCH or ALU in RA have already
    -- set lbranch and lalu above. This is for other instructions.
    -- Without late ALU or Branch Unit, things are taken care of later.
    -- LD followed by ST is not a problem since ST does not need data until later.
    -- All other cases require a hold here.
    if v_fusel_eq(r, e, memory_lane, LD) then
      for i in lanes'range loop
        if r.a.ctrl(i).valid = '1' then
          if not v_fusel_eq(r, a, i, BRANCH or ALU) then
            if v_rd_eq(r, e, memory_lane, r.a.rfa1(i)) then
              hold    := '1';
              hvec(3) := '1';
              lddp    := '1';
            end if;
            if v_rd_eq(r, e, memory_lane, r.a.rfa2(i)) then
              if not (i = 0 and v_fusel_eq(r, a, memory_lane, ST)) then
                hold    := '1';
                hvec(3) := '1';
                lddp    := '1';
              end if;
            end if;
          end if;
        end if;
      end loop;
    end if;

    ---------------------------------------------------------------------------
    -- Hold Issue stage if we have inst | mul/div with register dependency
    ---------------------------------------------------------------------------

    -- MUL in EX followed by a dependent instruction in RA.
    -- The cases with MUL in EX followed by ALU in RA have already set lalu above
    -- (unless MUL in non-dependent lane, see above). This is for other instructions.
    -- MUL followed by ST is not a problem since ST does not need data until later.
    for j in lanes'range loop
      -- Check dependency for instruction in execute stage
      if v_fusel_eq(r, e, j, MUL) then
        for i in lanes'range loop
          if r.a.ctrl(i).valid = '1' then
            if (v_rd_eq(r, e, j, r.a.rfa1(i)) or
                (v_rd_eq(r, e, j, r.a.rfa2(i)) and not v_fusel_eq(r, a, i, ST))) and
               not (v_fusel_eq(r, a, i, ALU) and not v_fusel_eq(r, a, lanes'high - i, MUL)) then
              hold    := '1';
              hvec(4) := '1';
            end if;
          end if;
        end loop;
      end if;
    end loop;

    ---------------------------------------------------------------------------
    -- Deal with CSR writes that have dependencies.
    ---------------------------------------------------------------------------

    if csr_ok(r, a) then
      -- Hold Issue stage if:
      -- There is already a CSR instruction in the pipeline that writes the
      -- same register.
      -- Upon a CSR read, there is already a CSR instruction in the pipeline
      -- that writes one in the same RaW category. (Read after Write dependency)
      -- Upon a CSR write, there is already a CSR instruction in the pipeline
      -- that writes one in the same WaW category. (Write after Write dependency)
      -- Some CSR dependencies need to be extended by one/two extra cycle even
      -- if the instruction has already left WB stage.
      -- For instance: reading MTOPI after writing MTOPEI 
      -- Writing MTOPEI clears the IMSIC interrupt but there are 2 cycles of
      -- latency. When MIP.MEIP bit is set to 0 another extra cycle is needed
      -- to update MTOPI.
      if csr_ok(r, pwb1) and (r.pwb1.ctrl(csr_lane).csrdo = '0') and
         (csr_raw_category_eq(r, a, pwb1) or csr_waw_category_eq(r, a, pwb1)) and
         csr(r, pwb1).hold_cat(8) = '1' then
        hold    := '1';
      end if;
      if csr_ok(r, pwb0) and (r.pwb0.ctrl(csr_lane).csrdo = '0') and
         ((not csr_write_only(r, a) and csr_raw_category_eq(r, a, pwb0)) or
          (not csr_read_only(r, a)  and csr_waw_category_eq(r, a, pwb0))) and
         csr(r, pwb0).hold_cat(8) = '1' then
        hold    := '1';
      end if;
      if csr_ok(r, wb) and (r.wb.ctrl(csr_lane).csrdo = '0') and
         (r.a.csrw_eq(3) = '1' or
          (not csr_write_only(r, a) and csr_raw_category_eq(r, a, wb)) or
          (not csr_read_only(r, a)  and csr_waw_category_eq(r, a, wb))) then
        hold    := '1';
        hvec(5) := '1';
      end if;
      if csr_ok(r, x) and (r.x.ctrl(csr_lane).csrdo = '0') and
         (r.a.csrw_eq(2) = '1' or
          (not csr_write_only(r, a) and csr_raw_category_eq(r, a, x)) or
          (not csr_read_only(r, a)  and csr_waw_category_eq(r, a, x))) then
        hold    := '1';
        hvec(5) := '1';
      end if;
      if csr_ok(r, m) and (r.m.ctrl(csr_lane).csrdo = '0') and
         (r.a.csrw_eq(1) = '1' or
          (not csr_write_only(r, a) and csr_raw_category_eq(r, a, m)) or
          (not csr_read_only(r, a)  and csr_waw_category_eq(r, a, m))) then
        hold    := '1';
        hvec(5) := '1';
      end if;
      if csr_ok(r, e) and (r.e.ctrl(csr_lane).csrdo = '0') and
         (r.a.csrw_eq(0) = '1' or
          (not csr_write_only(r, a) and csr_raw_category_eq(r, a, e)) or
          (not csr_read_only(r, a)  and csr_waw_category_eq(r, a, e))) then
        hold    := '1';
        hvec(5) := '1';
      end if;
    end if;


    ---------------------------------------------------------------------------
    -- Hold Issue if there is in RA stage a CSR operatio that modifies any 
    -- performance counter. When a performance counter is read/write
    -- we should wait until all the instructions update the counter before
    -- peforming the read/write of the CSR.
    -- It is important to be aware that from the event being recordid until
    -- updating the hpmcounter there is 3 cycles of latency. We need to 
    -- take into account this for the hold times.
    -- This is also important because an instruction executing before a 
    -- hpmcounter write could increment the value of the CSR after storing
    -- the new value.
    ---------------------------------------------------------------------------
    if hpmchold(hpmchold'right) = '1' then
      if hpmchold(hpmchold'right - 1) = '1' then
        hold    := '1';
        hvec(6) := '1';
      end if;
      hpmchold := '0' & hpmchold(0 to hpmchold'right - 1);
    elsif csr_ok(r, a) then
      if csr(r, a).hold_cat(6) = '1' then
        hpmchold := (hpmchold'range => '1');
        hold     := '1';
      elsif csr(r, a).hold_cat(7) = '1' then
        if hpmc_ind_hold_check(r.csr.v, r.csr, r.csr.dfeaturesen.hpmc_mode) then
          hpmchold := (hpmchold'range => '1');
          hold     := '1';
        end if;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Hold Issue stage if last few pairs contained a CSR instruction that wrote
    -- to mstatus/sstatus/mie/sie/pmpcfg/pmpaddr and there is now a memory access.
    -- This is to ensure that relevant state is set before the access is done.
    -- This does not cover the case of execution protection for machine mode
    -- being enabled, so that requires a flush later.
    ---------------------------------------------------------------------------
    accesshold   := '0' & accesshold(0 to accesshold'right - 1);
    if csr_ok(r, e) and not csr_access_read_only(r, e) and csr(r, e).hold_cat(1) = '1' then
      accesshold := (accesshold'range => '1');
    end if;
    if accesshold(accesshold'right) = '1' and
       v_fusel_eq(r, a, memory_lane, LD or ST) then
      hold    := '1';
      hvec(7) := '1';
    end if;

    ---------------------------------------------------------------------------
    -- Hold issue if there is a valid instruction in access stage and there
    -- is a CSR write instruction to interrupt related registers in execute.
    -- This way interrupt does not need to be checked in two different stages
    ---------------------------------------------------------------------------
    if csr_ok(r, e) and not csr_access_read_only(r, e) and csr(r, e).hold_cat(5) = '1' and
       (r.a.ctrl(0).valid = '1' or r.a.ctrl(one).valid = '1') then
      -- CSR is going to write an interrupt related register.
      hold    := '1';
      hvec(9) := '1';
    end if;

    ---------------------------------------------------------------------------
    -- Hold Issue stage after instructions that can force pipeline flush:
    --   fence.i, sfence.vma, write to pmpcfg (lock bits enable X protection),
    --   hfence.vvma, hfence.gvma
    --   write to satp (pageing may be turned on/off)
    -- For the fences, the point is that a following instruction may be reliant
    -- on TLB updates to work as intended.
    ---------------------------------------------------------------------------
    exechold := '0' & exechold(0 to exechold'right - 1);
    if csr_ok(r, e) and not csr_access_read_only(r, e) and csr(r, e).hold_cat(2) = '1' then
      exechold   := (exechold'range => '1');
    end if;
    if r.e.ctrl(memory_lane).valid = '1' then
      if is_fence_i(r.e.ctrl(memory_lane).inst) or
         is_tlb_fence(active_extensions, r.e.ctrl(memory_lane).inst) then
        exechold := (exechold'range => '1');
      end if;
    end if;
    if exechold(exechold'right) = '1' then
      hold      := '1';
      hvec(10)  := '1';
    end if;

    ---------------------------------------------------------------------------
    -- Hold Issue stage for floating point instructions when the FPU is busy,
    -- for certain CSR instructions that need the FPU to be idle,
    -- and when there are FPU vs CSR dependencies.
    ---------------------------------------------------------------------------
    if ext_f = 1 then
      fpuhold := '0' & fpuhold(0 to fpuhold'right - 1);
      -- Some CSR accesses need to wait for the FPU to be completely idle.
      if csr_ok(r, a) and csr(r, a).hold_cat(3) = '1' then
        if fpu_idle = '0' then
          hold  := '1';
        end if;
        -- FPU instructions that return integer results pass along their flags
        -- in the IU, for write in WB at the same time as a following CSR write
        -- would be taking place in XC. Must not happen!
        -- Can as well look for any normal FPU instruction (memory don't touch flags),
        -- since anything else will not have completed, anyway (and a cycle of
        -- latency would not have mattered in any case).
        if is_fpu(r.e.ctrl(fpu_lane).inst) then
          hold  := '1';
        end if;
      end if;
      -- Some CSR writes must take effect before the next FPU operation that
      -- can be affected (or can affect the CSR) is allowed.
      if csr_ok(r, a) and csr(r, a).hold_cat(4) = '1' and not csr_access_read_only(r, a) then
        fpuhold := (fpuhold'range => '1');
      end if;
      -- All FPU operations must wait if the FPU is not ready.
      if fpu_ready = '0' and
         ((r.a.ctrl(fpu_lane).valid    = '1' and is_fpu(r.a.ctrl(fpu_lane).inst)) or
          (r.a.ctrl(memory_lane).valid = '1' and is_fpu_mem(r.a.ctrl(memory_lane).inst))) then
        hold      := '1';
        hvec(14)  := '1';
      -- FPU operations that can be affected by CSR:s (or can affect them) must wait
      -- for any writes to them to take effect.
      -- FPU load/store are the main exempt things.
      elsif fpuhold(fpuhold'right) = '1' and
            (r.a.ctrl(fpu_lane).valid = '1' and is_fpu(r.a.ctrl(fpu_lane).inst)) then
        hold      := '1';
      end if;
    end if;

    -- To not delay the trace more than necessary on fence instruction flush the remaining
    -- instructions in the pipe.
    if tracehold(tracehold'right) = '1' then
      if tracehold(tracehold'right - 1) = '1' then
        hold    := '1';
      end if;
      tracehold := '0' & tracehold(0 to tracehold'right - 1);
    elsif is_fence_i(r.a.ctrl(memory_lane).inst) or is_fence(r.a.ctrl(memory_lane).inst) or
       is_tlb_fence(active_extensions, r.a.ctrl(memory_lane).inst) then
      tracehold := (tracehold'range => '1');
      hold     := '1';
    end if;


    ---------------------------------------------------------------------------
    -- Hold Issue stage if an FPU store uses an address from a register that
    -- is still a destination somewhere in the pipeline.
    -- Since the FPU store will currently stop in EX, the address might
    -- otherwise leave the pipeline before it can be used!
    -- Do the same for loads, since the load address might also leave the pipeline
    -- under certain cicumstances when the load stalls in EX (due to "full" FPU).
    -- Also do it for _all_ FPU instructions that take integer register inputs,
    -- for the same reason as the loads.
    ---------------------------------------------------------------------------
    if ext_f = 1 then
      if (r.a.ctrl(memory_lane).valid = '1' and is_fpu_mem(r.a.ctrl(memory_lane).inst)) or
         (r.a.ctrl(fpu_lane).valid = '1' and is_fpu_from_int(r.a.ctrl(fpu_lane).inst)) then
        for i in lanes'range loop
          if v_rd_eq(r, e,  i, r.a.rfa1(fpu_lane)) or
             v_rd_eq(r, m,  i, r.a.rfa1(fpu_lane)) or
             v_rd_eq(r, x,  i, r.a.rfa1(fpu_lane)) or
             v_rd_eq(r, wb, i, r.a.rfa1(fpu_lane)) then
            hold     := '1';
            hvec(15) := '1';
          end if;
        end loop;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Some back-to-back Store operations are still not supported by the Data Cache
    ---------------------------------------------------------------------------

    if v_fusel_eq(r, e, memory_lane, ST) then
      -- Allow b2b stores if word or double word access
      if (v_fusel_eq(r, a, memory_lane, ST) and
           -- Is either store smaller than 32 bit?
           -- ST  inst: size < 32 when inst(13) = 0
           -- HSV inst: size < 32 when inst(27) = 0
           -- CFI stores all always 32 or 64 bits!
          ((((not is_hsv(r.a.ctrl(memory_lane).inst) and
              not v_fusel_eq(r, a, memory_lane, CFI) and
              r.a.ctrl(memory_lane).inst(13) = '0') or
             (    is_hsv(r.a.ctrl(memory_lane).inst) and r.a.ctrl(memory_lane).inst(27) = '0')) or
            ((not is_hsv(r.e.ctrl(memory_lane).inst) and
              not v_fusel_eq(r, e, memory_lane, CFI) and
              r.e.ctrl(memory_lane).inst(13) = '0') or
             (    is_hsv(r.e.ctrl(memory_lane).inst) and r.e.ctrl(memory_lane).inst(27) = '0'))
           ) or
           r.csr.dfeaturesen.b2bst_dis = '1')) or
         -- Load directly following store is also not allowed.
         v_fusel_eq(r, a, memory_lane, LD) then
        hold     := '1';
        hvec(11) := '1';
        sdb2b    := '1';
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Store & AMO Late Branch dependency
    ---------------------------------------------------------------------------
    -- A store & AMO operation that is directly after a late branch will not have enough
    -- time for nullify signals, hence it has to be at least 2 cycles behind a late branch.
    if late_branch /= 0 then
      if v_fusel_eq(r, a, memory_lane, ST) or v_fusel_eq(r, a, memory_lane, AMO) then
        if v_fusel_eq(r, e, branch_lane, BRANCH) then
          if r.e.lbranch = '1' then
            hold := '1';
          end if;
        end if;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- TLB fences Late Branch dependency
    ---------------------------------------------------------------------------
    -- A TLB fence that is directly after a late branch will not have enough
    -- time for nullify signals, hence it has to be at least 2 cycles behind a late branch.
    if mode_s = 1 and late_branch /= 0 then
      if v_fusel_eq(r, e, branch_lane, BRANCH) then
        if r.e.lbranch = '1' then
          if is_tlb_fence(active_extensions, r.a.ctrl(memory_lane).inst) then
            hold := '1';
          end if;
        end if;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Speculative load
    ---------------------------------------------------------------------------
    -- A load operation that is directly after a late branch needs to be speculative
    -- in order to be nullified in exception stage.
     if late_branch /= 0 then
      if v_fusel_eq(r, a, memory_lane, LD) and not v_fusel_eq(r, a, memory_lane, AMO) then
        if v_fusel_eq(r, e, branch_lane, BRANCH) then
          if r.e.lbranch = '1' then
            spec_ldo := '1';
          end if;
        end if;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Load/Store CBO dependency
    ---------------------------------------------------------------------------
    -- A load/store operation needs to be at least 2 cycles behind CBO operations
    if ext_zicbom /= 0 then
      if is_cbo(r.e.ctrl(memory_lane).inst) then
        if v_fusel_eq(r, a, memory_lane, ST) or v_fusel_eq(r, a, memory_lane, LD) then
          hold := '1';
        end if;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Disable advanced features
    ---------------------------------------------------------------------------

    if (r.csr.dfeaturesen.lbranch_dis = '1' or late_branch = 0) and lbranch = '1' then
      hold      := '1';
      hvec(12)  := '1';
    end if;

    if (r.csr.dfeaturesen.lalu_dis = '1' or late_alu = 0) and not all_0(lalu) then
      hold      := '1';
      hvec(13)  := '1';
    end if;

    -- Mask late branch and late ALUs flag if features disabled
    if late_alu = 0 then
      lalu      := (others => '0');
    end if;
    if late_branch = 0 then
      lbranch   := '0';
    end if;


    holdi       := hold;
    lbrancho    := lbranch and not r.csr.dfeaturesen.lbranch_dis;
    laluo       := lcsr or (lalu and (lalu'range => not r.csr.dfeaturesen.lalu_dis));
  end;

  -- Multiplication Unit Signals Generation
  procedure mul_gen(l0_inst_in  : in  word;
                    l1_inst_in  : in  word;
                    l0_fusel_in : in  fuseltype;
                    l1_fusel_in : in  fuseltype;
                    l0_valid_in : in  std_ulogic;
                    l1_valid_in : in  std_ulogic;
                    l0_op1_in   : in  wordx;
                    l0_op2_in   : in  wordx;
                    l1_op1_in   : in  wordx;
                    l1_op2_in   : in  wordx;
                    nready_in   : in  std_ulogic;
                    hold_out    : out std_ulogic;
                    valid_out   : out std_ulogic;
                    op_out      : out std_ulogic;
                    ctrl_out    : out word3;
                    op1_out     : out wordx;
                    op2_out     : out wordx) is
    -- Non-constant
    variable valid : std_ulogic := '0';
    variable hold  : std_ulogic := '0';
    variable op    : std_ulogic := l0_inst_in(14);
    variable ctrl  : word3      := l0_inst_in(3) & l0_inst_in(13 downto 12);
    variable op1   : wordx      := l0_op1_in;
    variable op2   : wordx      := l0_op2_in;
  begin
    -- op encodes mul or div operations
    -- * 0   -> mul
    -- * 1   -> div

    -- We encode the multiplication operations as follow:
    -- * 000 -> mul
    -- * 001 -> mulh
    -- * 010 -> mulhsu
    -- * 011 -> mulhu
    -- * 100 -> mulw

    -- We encode the division operations as follow:
    -- * 000 -> div
    -- * 001 -> divu
    -- * 010 -> rem
    -- * 011 -> remu
    -- * 100 -> divw
    -- * 101 -> divuw
    -- * 110 -> remw
    -- * 111 -> remuw

    if ext_m = 1 then
      if    l0_valid_in = '1' and v_fusel_eq(l0_fusel_in, MUL) then
        valid   := '1';
      elsif single_issue = 0 and
            l1_valid_in = '1' and v_fusel_eq(l1_fusel_in, MUL) then
        op      := l1_inst_in(14);
        valid   := '1';
        op1     := l1_op1_in;
        op2     := l1_op2_in;
        ctrl    := l1_inst_in(3) & l1_inst_in(13 downto 12);
      end if;
    end if;

    -- Hold PC if divo.nready is high.
    if nready_in = '1' and valid = '1' and op = '1' and ext_m = 1 then
      hold      := '1';
    end if;

    valid_out   := valid;
    op_out      := op;
    ctrl_out    := ctrl;
    op1_out     := op1;
    op2_out     := op2;
    hold_out    := hold;
  end;


  -- FPU Signals Generation
  procedure fpu_gen(inst_in     : in  word;
                    valid_in    : in  std_ulogic;
                    nready_in   : in  std_ulogic;
                    hold_in     : in  std_ulogic;
                    hold_out    : out std_ulogic) is
    -- Non-constant
    variable hold   : std_ulogic  := '0';
  begin
    if ext_f = 1 then
      if valid_in = '1' and (is_fpu(inst_in) or is_fpu_mem(inst_in)) then
        -- Hold PC if fpuo.nready is asserted.
        if nready_in = '0' then
          hold  := '1';
        end if;
      end if;
    end if;

    assert (hold_in and hold) = '0' report "Double hold" severity failure;

    hold_out := hold or hold_in;
  end;

  -- Generate Result from Mul Unit
  procedure mul_res(mul_in      : in  mul_out_type;
                    div_in      : in  div_out_type;
                    fpu_in      : in  fpu5_out_type;
                    l_inst      : in  word_lanes_type;
                    l_valid     : in  lanes_type;
                    l_fusel     : in  fusel_lanes_type;
                    results_in  : in  wordx_lanes_type;
                    results_out : out wordx_lanes_type) is
    -- Non-constant
    variable mulres   : wordx            := mul_in.result;
    variable results  : wordx_lanes_type := results_in;
    variable mresults : wordx_lanes_type;
  begin
    for i in lanes'range loop
      if l_inst(i)(14) = '0' then
        mresults(i) := mulres;
      else
        mresults(i) := div_in.result(wordx'range);
      end if;

      if v_fusel_eq(l_fusel(i), MUL) then
        results(i)  := mresults(i);
      end if;
    end loop;


    results_out     := results;
  end;



  -- Generate rs2 operand for Store operation
  procedure a_stdata_forwarding(r            : in  registers;
                                lane         : in  lanes_range;
                                ex0_valid_in : in  std_ulogic;
                                ex1_valid_in : in  std_ulogic;
                                ex_result    : in  wordx_lanes_type;
                                ra_op2       : in  wordx;
                                forw_out     : out lanes_type;
                                stdata_out   : out wordx) is
    -- Non-constant
    variable stdata         : wordx      := (others => '0');
    variable mux_output_op2 : wordx;
    variable rfa2           : rfa_tuple  := rfa(2, a, lane);
    variable wb_forw_op2    : word2 := (others => '0');
    variable xc_forw_op2    : word2 := (others => '0');
    variable mem_forw_op2   : word2 := (others => '0');
    variable ex_forw_op2    : word2 := (others => '0');
  begin
    if r.a.rfa2(lane) /= "00000" then
      stdata            := ra_op2;
    end if;

    -- Op2
    if    single_issue = 0 and
          v_rd_eq_xvalid(r, e, one, ex1_valid_in, rfa2) then
      ex_forw_op2       := "11";
    elsif v_rd_eq_xvalid(r, e, 0, ex0_valid_in, rfa2) then
      ex_forw_op2       := "10";
    elsif single_issue = 0 and
          v_rd_eq(r, m,  one, rfa2) then
      -- Do not forward directly from late ALU.
      if r.m.alu(one).lalu = '0' then
        -- Do not forward directly from MUL.
        -- Handled by forwarding in a later cycle instead.
        if not v_fusel_eq(r, m, one, MUL or FPU ) then
          mem_forw_op2  := "11";
        end if;
      end if;
    elsif v_rd_eq(r, m,  0, rfa2) then
      -- Do not forward directly from late ALU.
      if r.m.alu(0).lalu = '0' then
        -- Do not forward directly from cache access or MUL.
        -- Handled by forwarding in a later cycle instead.
        if not v_fusel_eq(r, m, 0, LD or MUL or FPU ) then
          mem_forw_op2  := "10";
        end if;
      end if;
    elsif single_issue = 0 and
          v_rd_eq(r, x,  one, rfa2) then
      -- Do not forward directly from late ALU.
      -- Handled by forwarding in next cycle instead.
      if r.x.alu(one).lalu = '0' then
        xc_forw_op2     := "11";
      end if;
    elsif v_rd_eq(r, x,  0, rfa2) then
      -- Do not forward directly from late ALU.
      -- Handled by forwarding in next cycle instead.
      if r.x.alu(0).lalu = '0' then
        xc_forw_op2     := "10";
      end if;
    elsif single_issue = 0 and
          v_rd_eq(r, wb, one, rfa2) then
      wb_forw_op2       := "11";
    elsif v_rd_eq(r, wb, 0, rfa2) then
      wb_forw_op2       := "10";
    else
    end if;

    -- First Stage Mux for Op2
    if xc_forw_op2 = "10" then
      -- Forward data from load result if LD operation.
      if v_fusel_eq(r, x, memory_lane, LD) then
        mux_output_op2  := r.x.rdata(wordx'range);
      else
        mux_output_op2  := r.x.result(0);
      end if;
    elsif single_issue = 0 and
          xc_forw_op2 = "11" then
      mux_output_op2    := r.x.result(one);
    elsif mem_forw_op2 = "10" then
      mux_output_op2    := r.m.result(0);
    elsif single_issue = 0 and
          mem_forw_op2 = "11" then
      mux_output_op2    := r.m.result(one);
    elsif wb_forw_op2 = "10" then
      mux_output_op2    := r.wb.wdata(0);
    elsif single_issue = 0 and
          wb_forw_op2 = "11" then
      mux_output_op2    := r.wb.wdata(one);
    else
    end if;

    -- Second Stage Mux for Op2
    if    (xc_forw_op2(1) or mem_forw_op2(1) or wb_forw_op2(1)) = '1' then
      stdata            := mux_output_op2;
    elsif single_issue = 0 and
          ex_forw_op2 = "11" then
      stdata            := ex_result(one);
    elsif ex_forw_op2 = "10" then
      stdata            := ex_result(0);
    else
    end if;

    stdata_out  := stdata;
    forw_out(0) := ex_forw_op2(1) or mem_forw_op2(1) or xc_forw_op2(1) or wb_forw_op2(1);
    if single_issue = 0 then
      forw_out(one) := '0';
    end if;

  end;

  -- Gen Next PC for fence
  procedure gen_next(pc1_in  : in  pctype;
                     pc0_in  : in  pctype;
                     comp_in : in  std_ulogic;
                     pc_out  : out pctype) is
    -- Non-constant
    variable pc : pctype;
  begin
    pc     := npc_adder(pc0_in, comp_in);

    pc_out := pc;
  end;

  -- Check for upcoming fence flush.
  function fence_flush_check(r : registers) return std_logic is
    -- Non-constant
    variable flush : std_ulogic := '0';
  begin
    if r.x.ctrl(memory_lane).valid = '1' then
      -- The only thing that should cause a flush is instruction fence.
      if is_fence_i(r.x.ctrl(memory_lane).inst) then
        flush   := '1';
      end if;
    end if;

    return flush;
  end;

  -- Fence Unit
  procedure fence_unit(r         : in  registers;
                       pc_out    : out pctype;
                       flush_out : out std_ulogic) is
    variable pc    : pctype     := r.wb.nextpc0;
    -- Non-constant
    variable flush : std_ulogic := '0';
  begin
    -- In case of fence_flush, ensure that the instruction is still valid!
    -- It might have been invalidated due to a mispredicted branch (swap).
    if r.wb.flushall = '0' and r.wb.fence_flush = '1' and r.wb.ctrl(memory_lane).valid = '1' then
      flush   := '1';
    end if;

    flush_out := flush;
    pc_out    := pc;
  end;

  -- BHT Update Procedure
  procedure bht_update(ctrl_in  : in  pipeline_ctrl_type;
                       unalg_pc : in  pctype;
                       csren_in : in  csr_dfeaturesen_type;
                       bht_out  : out nv_bht_in_type) is
    variable fusel_in : fuseltype  := ctrl_in.fusel;
    variable valid_in : std_ulogic := ctrl_in.valid;
    variable pc_in    : pctype     := ctrl_in.pc;
    variable comp_in  : std_ulogic := ctrl_in.comp;
    -- Non-constant
    variable bht      : nv_bht_in_type;
    variable waddr    : pctype := pc_in;
  begin
    -- Write next address in case of a branch which wraps
    -- a word boundary.
    if ext_c = 1 then
      if comp_in = '0' then
        if (single_issue  = 0 and pc_in(2 downto 1) = "11") or
           (single_issue /= 0 and pc_in(1) = '1') then
          waddr   := unalg_pc;
        end if;
      end if;
    end if;

    -- Update BHT with branch or unconditional jump address.
    bht.waddr   := pc2xlen(waddr);

    bht_out     := bht;
  end;

  -- BTB Update Procedure
  procedure btb_update(ctrl_in    : in  pipeline_ctrl_type;
                       unalg_pc   : in  pctype;
                       csren_in   : in  csr_dfeaturesen_type;
                       wb_fence_i : in  std_ulogic;
                       rstate     : in  core_state;
                       btb_out    : out nv_btb_in_type) is
    variable fusel_in : fuseltype  := ctrl_in.fusel;
    variable valid_in : std_ulogic := ctrl_in.valid;
    variable xc_in    : std_ulogic := ctrl_in.xc;
    variable pc_in    : pctype     := ctrl_in.pc;
    variable comp_in  : std_ulogic := ctrl_in.comp;
    -- Non-constant
    variable waddr    : pctype := pc_in;
    variable btb      : nv_btb_in_type;
  begin
    -- Write next address in case of a branch which wraps
    -- a word boundary.
    if ext_c = 1 then
      if comp_in = '0' then
        if (single_issue = 0 and pc_in(2 downto 1) = "11") or
          (single_issue /= 0 and pc_in(1) = '1') then
          waddr := unalg_pc;
        end if;
      end if;
    end if;

    -- Update BTB with branch or unconditional jump address
    btb.waddr := pc2xlen(waddr);
    btb.wen   := valid_in and ctrl_in.branch.valid and ctrl_in.branch.taken and not ctrl_in.branch.hit and not xc_in;
    btb.wdata := to0x(ctrl_in.branch.addr);
    btb.flush := wb_fence_i;

    if valid_in = '1' and v_fusel_eq(fusel_in, JAL) and csren_in.jprd_dis = '0' then
      -- Target address is included in ctrl_in.branch.addr
      btb.wen := not ctrl_in.branch.hit;
    end if;

    if rstate /= run then
      btb.wen := '0';
    end if;

    if btb.wen = '1' then
      null;
    end if;

    btb_out   := btb;
  end;

  function lpad_fail(cfi_en : cfi_t;
                     pc     : pctype;
                     op1    : wordx;
                     op2    : wordx;
                     inst   : word) return std_ulogic is
  begin
    if not is_lpad(active_extensions, cfi_en, inst) then
      return '1';
    -- LPAD instruction must be 4-byte aligned.
    elsif not all_0(get_lo(pc, 2)) then
      return '1';
    elsif all_0(get(op2, 12, 20)) then
      return '0';
    elsif get(op1, 12, 20) = get(op2, 12, 20) then
      return '0';
    else
      return '1';
    end if;
  end;


  function trigger_mcontrol_mask(maskmax : integer;
                                 data    : std_logic_vector) return std_logic_vector is
    -- Non-constant
    variable tmp  : std_logic_vector(data'range);
    variable tbit : std_logic;
  begin
    tbit := '0';
    for i in 0 to data'high loop
      if i < maskmax then
        tbit := tbit or (not data(i));
      else
        tbit := '1';
      end if;
      tmp(i) := tbit;

    end loop;

    return tmp(tmp'high - 1 downto 0) & '0';
  end;


  function trigger_mcontrol6_exec_match(tdata1 : wordx;
                                        tdata2 : wordx;
                                        value  : wordx) return std_logic is
    variable match  : word4 := tdata1(10 downto 7);
    -- Non-constant
    variable hit       : std_logic;
    variable mask      : wordx;
    variable size      : std_logic_vector(2 downto 0) := tdata1(18 downto 16);
    --variable value32   : word  := value(31 downto 0);
    --variable tdata2_32 : word  := tdata2(31 downto 0);
  begin
    hit     := '0';

    --if size = "010" then
    --  value32(31 downto 16)   := (others => '0');
    --  tdata2_32(31 downto 16) := (others => '0');
    --end if;

    -- [3] = 1 : invert match
    case match(2 downto 0) is
      when "000" =>         -- value = tdata2
        hit := match(3) xor to_bit(tdata2 = value);
      when "001" =>         -- value(high:high-M) = tdata2(high:high-M)
        mask := trigger_mcontrol_mask(63, tdata2);
        hit := match(3) xor to_bit((tdata2 and mask) =
                                   (value and mask));
      when "010" | "011" => -- value >= tdata2, value < tdata2
        hit := not match(0) xor to_bit(unsigned(value) < unsigned(tdata2));
      when "100" =>
        hit := match(3) xor to_bit(tdata2((tdata2'length / 2) - 1 downto 0) =
                                   (value((tdata2'length / 2) - 1 downto 0) and
                                    tdata2(tdata2'high downto tdata2'length / 2)));
      when "101" =>
        hit := match(3) xor to_bit(tdata2((tdata2'length / 2) - 1 downto 0) =
                                   (value(tdata2'high downto tdata2'length / 2) and
                                    tdata2(tdata2'high downto tdata2'length / 2)));
      when others =>
        hit := '0';
    end case;
      if hit = '1' then
        null;
      end if;

    return hit;
  end;



  function trigger_mcontrol6_addr_match_high(tdata1  : wordx;
                                             tdata2  : wordx;
                                             value   : wordx;
                                             lowhit  : std_logic;
                                             lowbits : integer) return std_logic is
    variable match  : word4 := tdata1(10 downto 7);
    -- Non-constant
    variable hit    : std_logic;
    variable mask   : wordx;
  begin
    hit     := '0';

    -- [3] = 1 : invert match
    case match(2 downto 0) is
      when "000" =>         -- value = tdata2
        hit :=  match(3) xor (lowhit and to_bit(tdata2(addr_bits - 1 downto lowbits) = value(addr_bits - 1 downto lowbits)));
      when "001" =>         -- value(high:high-M) = tdata2(high:high-M)
        mask := trigger_mcontrol_mask(63, tdata2);
        hit := match(3) xor
               (lowhit and to_bit((tdata2(addr_bits - 1 downto lowbits) and mask(addr_bits - 1 downto lowbits)) =
                                   (value(addr_bits - 1 downto lowbits) and mask(addr_bits - 1 downto lowbits))));
      when "010" | "011" => -- value >= tdata2, value < tdata2
        if tdata2(addr_bits - 1 downto lowbits) = value(addr_bits - 1 downto lowbits) then
          hit := not match(0) xor lowhit;
        else
          hit := not match(0) xor to_bit(unsigned(value(addr_bits - 1 downto lowbits)) < unsigned(tdata2(addr_bits - 1 downto lowbits)));
        end if;
      when "100" => -- low mask
        if lowbits < tdata2'length/2 then
          hit := match(3) xor
                 (to_bit(tdata2((tdata2'length / 2) - 1 downto lowbits) =
                  (value((tdata2'length / 2) - 1 downto lowbits) and tdata2(tdata2'high downto lowbits + (tdata2'length / 2))))
                 and lowhit);
        else
          hit := match(3) xor lowhit;
        end if;
      when "101" => -- high mask
        if addr_bits > tdata2'length / 2 + lowbits and lowbits < tdata2'length / 2 then
          hit := match(3) xor
                 (to_bit(tdata2((tdata2'length / 2) - 1 downto lowbits) =
                  (value(addr_bits - 1 downto tdata2'length / 2 + lowbits) and tdata2(addr_bits - 1 downto tdata2'length / 2 + lowbits)))
                 and lowhit);
        elsif addr_bits > tdata2'length/2 then
          hit := match(3) xor lowhit;
        end if;
      when others =>
        hit := '0';
    end case;

    return hit;
  end;



  function trigger_mcontrol6_match_low(tdata1  : wordx;
                                       tdata2  : wordx;
                                       value   : wordx;
                                       mask    : wordx;
                                       lowbits : integer) return std_logic is
    variable match     : word4 := tdata1(10 downto 7);
    -- Non-constant
    variable xtdata2   : wordx := tdata2;
    variable xvalue    : wordx := value;
    variable hit       : std_logic;
    variable size      : word3 := tdata1(18 downto 16);
    variable size_mask : wordx := (others => '0');
  begin
    hit := '0';


    -- [3] = 1 : invert match
    case match(2 downto 0) is
      when "000" =>         -- value = tdata2
        hit := to_bit(xtdata2(lowbits - 1 downto 0) = xvalue(lowbits - 1 downto 0));
      when "001" =>         -- value(high:high-M) = tdata2(high:high-M)
        hit := to_bit((xtdata2(lowbits - 1 downto 0) and mask(lowbits - 1 downto 0)) =
                                   (xvalue(lowbits - 1 downto 0) and mask(lowbits - 1 downto 0)));
      when "010" | "011" => -- value >= tdata2, value < tdata2
        hit := to_bit(unsigned(xvalue(lowbits - 1 downto 0)) < unsigned(xtdata2(lowbits - 1 downto 0)));
      when "100" =>
        if lowbits < tdata2'length / 2 then
          hit := to_bit(xtdata2(lowbits - 1 downto 0) =
                        (xvalue(lowbits - 1 downto 0) and xtdata2(lowbits + (xtdata2'length / 2) - 1 downto xtdata2'length / 2)));
        else
          hit := to_bit(xtdata2((tdata2'length / 2) - 1 downto 0) =
                        (xvalue((tdata2'length / 2) - 1 downto 0) and xtdata2(xtdata2'length - 1 downto xtdata2'length / 2)));
        end if;
      when "101" =>
        if addr_bits > tdata2'length / 2 + lowbits and lowbits < tdata2'length / 2 then
          hit := to_bit(tdata2(lowbits - 1 downto 0) =
                        (value(lowbits + (tdata2'length / 2) - 1 downto tdata2'length / 2) and
                         tdata2(lowbits + (tdata2'length / 2) - 1 downto tdata2'length / 2)));
        elsif addr_bits > tdata2'length / 2 then
          hit := to_bit(tdata2(addr_bits - (tdata2'length / 2) - 1 downto 0) =
                        (value(addr_bits - 1 downto tdata2'length / 2) and
                         tdata2(addr_bits - 1 downto tdata2'length / 2)));
        end if;
      when others =>
        hit := '0';
    end case;

    return hit;
  end;



  subtype hit_vec_type is std_logic_vector(lanes_type'high + 2 downto lanes_type'low);
  function trigger_mcontrol6(lowhit  : std_logic;
                             tdata1  : wordx;
                             tdata2  : wordx;
                             m_ctrl  : pipeline_ctrl_lanes_type;
                             avalid  : std_logic;
                             addr    : addr_type;
                             size    : word2;
                             awrite  : std_logic;
                             aread   : std_logic;
                             wdata   : word64;
                             lowbits : integer) return hit_vec_type is
    variable tdata2v   : wordx             := tdata2;
    variable selectv   : std_logic         := tdata1(21);
    variable sizev     : word3             := tdata1(18 downto 16);
    variable exec      : std_logic         := tdata1(2);
    variable store     : std_logic         := tdata1(1);
    variable load      : std_logic         := tdata1(0);
    -- Non-constant
    variable sizev1     : word3;
    variable hit        : lanes_type       := (others => '0');
    variable ehit       : lanes_type       := (others => '0');
    variable ahit       : std_logic        := '0';
    variable valid      : std_logic        := '0';
    variable value      : wordx_lanes_type := (others => (others => '0'));
    --variable valid_size : std_logic        := '0';
    variable vdata_size : std_logic        := '0';
    variable vinst_size : std_logic        := '0';
    variable pri        : word2;
    variable ret        : hit_vec_type;
  begin
    -- Fields in the old MCONTROL type are arranged differently
    if MCONTROL_COMPATIBILITY = 1 then
      if get_hi(tdata1, 4) = x"2" then
        selectv   := tdata1(19);
        sizev     := tdata1(22 downto 21) & tdata1(17);
      end if;
    end if;

    if exec = '1' then
      for i in m_ctrl'range loop
        if (sizev = "010" and m_ctrl(i).comp = '0') or
           (sizev = "011" and m_ctrl(i).comp = '1') then
          vinst_size := '0';
        else
          vinst_size := '1';
        end if;
        if selectv = '0' then
          value(i) := to64(m_ctrl(i).pc)(wordx'range);
          pri := "01";
        else
          if m_ctrl(i).comp = '0' then
            value(i)(m_ctrl(i).inst'range) := m_ctrl(i).inst;
            -- Check only 32 LSB if size is 32 bits
            if XLEN = 64 and sizev = "011" then
              tdata2v(XLEN - 1 downto XLEN / 2)  := (others => '0');
              value(i)(XLEN - 1 downto XLEN / 2) := (others => '0');
            end if;
          else
            value(i)(m_ctrl(i).inst'range) := zerow16 & m_ctrl(i).cinst;
            -- Check only 16 LSB if size is 16 bits
            if sizev = "010" then
              tdata2v(XLEN - 1 downto 16)  := (others => '0');
              value(i)(XLEN - 1 downto 16) := (others => '0');
            end if;
          end if;
          pri := "10";
        end if;
        ehit(i)    := trigger_mcontrol6_exec_match(tdata1, tdata2v, value(i)) and vinst_size;
      end loop;
    else
      if lowhit = '1' then
        null;
      end if;
      -- When exec='1' only legal possible value for selectv is '0'
      valid      := avalid and ((load and aread) or (store and awrite));-- or
                                --to_bit(v_fusel_eq(m_ctrl(memory_lane).fusel, AMO) and m_ctrl(memory_lane).inst(31 downto 27) /= "00010"));
      value(0)   := to64(addr)(wordx'range);
      -- Check size
      sizev1 := sizev - 1;
      if sizev1(2) = '0' then
        vdata_size := to_bit(sizev1(1 downto 0) = size);
      else
        vdata_size := sizev1(0) or to_bit(size = "11");
      end if;
      -- If instruction is a CBO, trigger must work differently.
      if ext_zicbom = 1 and is_cbo(m_ctrl(memory_lane).inst) and m_ctrl(memory_lane).inst(20) = '0' then -- inval/flush instructions
        vdata_size := to_bit(sizev = "000");
        valid      := store and avalid;
      end if;
      ahit       := trigger_mcontrol6_addr_match_high(tdata1, tdata2, value(0), lowhit, lowbits) and vdata_size;
      pri := "11";
    end if;

    for i in hit'range loop
      hit(i)       := (m_ctrl(i).valid and ehit(i));
      if i = 0 then
        hit(i)     := hit(i) or (valid and ahit);
      end if;
    end loop;

    ret := (pri & hit);

    return ret;
  end;


  -- It gets the tval value for native mcontrol 6 triggers
  -- tval value is the accessed address for load/store matches
  -- and the PC for execute matches
  function trig_mc6_tval(tdata1  : wordx;
                         m_ctrl  : pipeline_ctrl_lanes_type;
                         addr    : addr_type) return wordx_lanes_type is
    variable exec      : std_logic         := tdata1(2);
    -- Non-constant
    variable value      : wordx_lanes_type := (others => (others => '0'));
  begin
    if exec = '1' then
      for i in m_ctrl'range loop
        value(i) := to64(m_ctrl(i).pc)(wordx'range);
      end loop;
    else
      value(0)   := to64(addr)(wordx'range);
    end if;

    return value;
  end;



  -- Compare the first bits
  function trigger_mcontrol6_addr_low(tdata1  : wordx;
                                      tdata2  : wordx;
                                      addr    : addr_type;
                                      inst    : word;
                                      size    : word2;
                                      lowbits : integer) return std_logic is
    variable selectv   : std_logic        := tdata1(21);
    variable exec      : std_logic        := tdata1(2);
    variable mask      : wordx            := trigger_mcontrol_mask(63, tdata2);
    -- Non-constant
    variable hit      : std_logic        := '0';
    --variable value    : wordx_lanes_type := (others => (others => '0'));
    variable xtdata2  : wordx            := tdata2;
    variable xvalue   : wordx            := to64(addr)(wordx'range);
  begin
    -- This case statement fulfills a recommendation from the spec to fire a trigger
    -- for unaligned addresses. However, that is not mandatory and could
    -- increase a critical path. If needed, it can be removed and the code
    -- will still be compliant with the spec.
    case size is
      when "01"  =>  -- 16 bit access
        xtdata2(0)          := '0';
        xvalue(0)           := '0';
      when "10"  =>  -- 32 bit access
        xtdata2(1 downto 0) := "00";
        xvalue(1 downto 0)  := "00";
      when "11"  =>   -- 64 bit access
        xtdata2(2 downto 0) := "000";
        xvalue(2 downto 0)  := "000";
      when others =>
    end case;

    -- The behavior is different for CBO operations
    if ext_zicbom = 1 and is_cbo(inst) and inst(20) = '0' then -- inval/flush instructions
      -- Any address value within the cache block will match
      xtdata2(log2(dlinesize) + 1 downto 0) := (others => '0');
      xvalue(log2(dlinesize) + 1 downto 0)  := (others => '0');
    end if;

    if selectv = '0' and exec = '0' then
      --value(0)   := to64(addr)(wordx'range);
      hit        := trigger_mcontrol6_match_low(tdata1, xtdata2, xvalue, mask, lowbits);
    end if;

    return hit;
  end;


  function trigger_icount(tdata1 : wordx;
                          e_swap : std_logic;
                          e_ctrl : pipeline_ctrl_lanes_type;
                          m_ctrl : pipeline_ctrl_lanes_type;
                          x_ctrl : pipeline_ctrl_lanes_type) return hit_vec_type is
    variable cnt_hi   : std_logic_vector(13 downto 3) := tdata1(23 downto 13);
    variable cnt_low  : word3                         := tdata1(12 downto 10);
    variable pending  : std_logic                     := tdata1(8);
    -- Non-constant
    variable hit      : lanes_type                    := (others => '0');
    variable instv    : word4                         := (others => '0');
    variable insts    : integer range 0 to 4          := 0;
    variable valid    : std_logic                     := '0';
    variable del      : std_logic                     := '0';
    variable ret      : hit_vec_type;
    variable cnt      : word4;
  begin
    -- Somewhat strange implementation of valid instruction count.
    -- Done this way to make Formality understand that there is
    -- no possibility for insts to go outside of its 0-4 range.

    -- When the tdata1 CSR of the icount trigger is modified a bubble
    -- is inserted to make sure that cnt_low - insts is never a negative
    -- value, even if the count is set to 1. Also, the instruction that writes
    -- the tdata1 CSR is issued alone (only that instruction in both lanes).

    instv(0)   := x_ctrl(0).valid;
    instv(1)   := m_ctrl(0).valid;
    if single_issue = 0 then
      instv(2) := x_ctrl(one).valid;
      instv(3) := m_ctrl(one).valid;
    end if;
    if all_1(instv) then
      insts := 4;
    else
      insts := u2i(pop(instv)(1 downto 0));
    end if;

    cnt := std_logic_vector(signed('0' & cnt_low) - insts);

    if cnt_hi = (cnt_hi'range => '0') then
      if cnt_low /= (cnt_low'range => '0') or pending = '1' then
        if cnt = x"0" then
          if e_swap = '0' then
            if e_ctrl(0).valid = '1' then
              hit(0)   := '1';
            elsif single_issue = 0 and
                  e_ctrl(one).valid = '1' then
              hit(one) := '1';
            end if;
          else
            if single_issue = 0 and
               e_ctrl(one).valid = '1' then
              hit(one) := '1';
            elsif e_ctrl(0).valid = '1' then
              hit(0)   := '1';
            end if;
          end if;
        elsif cnt = x"1" and single_issue = 0 then
          if (e_ctrl(0).valid and e_ctrl(one).valid) = '1' then
            if e_swap = '0' then
              hit(one) := '1';
            else
              hit(0)   := '1';
            end if;
          end if;
        end if;
      end if;
    end if;

    ret := ("00" & hit);

    return ret;
  end;


  -- Trigger Module
  procedure trigger_module(r              : in  registers;
                           csr_file       : in  csr_reg_type;
                           trig_in        : in  trig_type;
                           ie_trig_in     : in  ie_trig_type;
                           conthit_in     : in  contexthit_type;
                           tcsr           : in  csr_tcsr_type;
                           prv            : in  priv_lvl_type;
                           v_mode         : in  std_logic;
                           step           : in  std_logic;
                           haltreq        : in  std_logic;
                           x_rstate       : in  core_state;
                           clr_pen        : in  std_logic;
                           x_ctrl         : in  pipeline_ctrl_lanes_type;
                           m_swap         : in  std_logic;
                           m_ctrl         : in  pipeline_ctrl_lanes_type;
                           e_swap         : in  std_logic;
                           e_ctrl         : in  pipeline_ctrl_lanes_type;
                           avalid         : in  std_logic;
                           addr           : in  addr_type;
                           size           : in  word2;
                           awrite         : in  std_logic;
                           aread          : in  std_logic;
                           wdata          : in  word64;
                           conthit_out    : out contexthit_type;
                           m_trig         : out trig_type;
                           clr_ie_trig    : out std_logic;
                           ie_trig_hit    : out std_logic;
                           trigxc_out     : out trig_exception_type;
                           mc6nullify     : out std_logic;
                           mc6bypass      : out std_logic;
                           me_bypass_trig : out trig_type) is
    -- Non-constant
    variable valid     : std_logic;
    variable trig      : trig_type           := trig_none;
    variable hit       : hit_vec_type        := (others => '0');
    variable hitv      : hit_vec_type        := (others => '0');
    variable thit      : lanes_type          := (others => '0');
    variable mc6hit    : lanes_type          := (others => '0');
    variable ichit     : lanes_type          := (others => '0');
    variable tdata1    : wordx;
    variable tdata2    : wordx;
    variable tdata3    : wordx;
    variable action1   : std_logic;
    variable hitvec    : trighit_vector      := (others => (others => '0'));
    variable swap      : std_logic           := e_swap;
    variable mc6action : trig_action_type    := (others => (others => '0'));
    variable icaction  : trig_action_type    := (others => (others => '0'));
    variable action    : wordx;
    variable taction   : trig_action_type;
    variable intpri    : word2;
    variable finpri    : trig_priority_type  := (others => (others => '1'));
    variable tpri      : trig_priority_type;
    variable chainhit  : lanes_type          := (others => '1');
    variable bypass    : std_logic           := '0';
    variable v_x_trig  : trig_type;
    variable trigxc    : trig_exception_type := trig_exception_none;
    variable mc6_tval, mc6_tval_temp  : wordx_lanes_type := (others => (others => '0'));
  begin
    mc6nullify := '0';

    if TRIGGER_NUM /= 0 then
      -- Check trigger context
      -- Context check is pipelined to improve timing
      for i in 0 to TRIGGER_NUM - 1 loop
        tdata3  := tcsr.tdata3(i);
        conthit_out(i) := trigger_textra_match(tdata3    => tdata3,
                                               mhcontext => tcsr.mhcontext,
                                               scontext  => tcsr.scontext,
                                               hgatp     => csr_file.hgatp,
                                               satp      => csr_file.satp,
                                               vsatp     => csr_file.vsatp,
                                               vmode     => csr_file.v);
      end loop;

      -- Check if mcontrol6 or instruction count triggers hit
      for i in 0 to TRIGGER_MC_NUM + TRIGGER_IC_NUM - 1 loop

        tdata1  := tcsr.tdata1(i);
        tdata2  := tcsr.tdata2(i);

        -- Active common for all trigger types
        -- in : m,s,u,vs,vu
        -- Check if trigger is enabled for the current privilege
        -- mode and virtualization mode
        if x_rstate = run then
          valid := trigger_valid(prv, v_mode, tdata1);
        else
          valid := '0';
        end if;

        -- MCONTROL6:
        -- When execute field is set to 0 to set a watchpoint, the address of the
        -- load and store operations has to be compared with the value stored
        -- in tdata2.
        -- The address accessed during the load and store oprations is calculated in
        -- the execution stage. Using the address caculated in the execution stage
        -- becomes an issue when meeting the ASIC timing constraints. Evaluating the
        -- address in the memory stage instead increases the combinaional path that
        -- is in charge of nullifiying the data cache, making it difficult to achieve
        -- timing closure. For this reason, the comparison is
        -- split between both stages, the MCONTROL6_LOWBITS less-significant bits of
        -- the address are evaluated in the execution stage while the rest are
        -- evaluated in the memory stage. In case of a hit, the data cache is nullified.

        -- According to the specs, the field select could be hardwired to 0 to allow
        -- only address comparisons. This implementation allows the field select to be
        -- set to 1 only when the field execute is also set to 1. Therefore, the MCONTROL6
        -- triggers cannot be configured to fire when a specific data is loaded or stored.

        -- All the possible configurations result in the mcontrol6 trigger firing before
        -- executing the instruction that meets the conditions to fire the trigger.

        -- With the previous characteristics and following the table 5.2 from the RISC-V
        -- Debug Specification Version 1.0-STABLE, we can separate the triggers priorities
        -- in 4 categories. interrupt, exception and count triggers will always have priority
        -- over mcontrol6 triggers. Within mcontrol6 triggers, the priorities will be as follow:
        -- Execute address:    1 (highest priority)
        -- Execute data:       2
        -- load/store address: 3

        -- in : maskmax (constant)
        -- in : select 0 = addr, 1 = data/inst
        -- in : enable: m, s, u, vs, vu
        -- in : size access/inst size to match
        -- in : chain ...
        -- in : match ...
        -- in : exec, load, store
        -- out: hit = priority & match
        -- tdata2 = data (and mask)
        if i < TRIGGER_MC_NUM then
          hit := trigger_mcontrol6(lowhit  => trig_in.lowhit(i),
                                   tdata1  => tdata1,
                                   tdata2  => tdata2,
                                   m_ctrl  => m_ctrl,
                                   avalid  => avalid,
                                   addr    => addr,
                                   size    => size,
                                   awrite  => awrite,
                                   aread   => aread,
                                   wdata   => wdata,
                                   lowbits => MCONTROL6_LOWBITS);

          -- Get the tval value for native mcontrol 6 triggers
          -- tval value is the accessed address for load/store matches
          -- and the PC for execute matches
          mc6_tval_temp := trig_mc6_tval(tdata1 => tdata1,
                                         m_ctrl => m_ctrl,
                                         addr   => addr);

          action1 := tdata1(12);
        end if;

        -- ICOUNT
        -- in : count
        -- out: hit = match
        -- tdata2 = not used
        if TRIGGER_IC_NUM /= 0 and i = TRIGGER_MC_NUM then
          hit := trigger_icount(
                   tdata1 => tdata1,
                   e_swap => e_swap,
                   e_ctrl => e_ctrl,
                   m_ctrl => m_ctrl,
                   x_ctrl => x_ctrl);

          action1 := tdata1(0);
        end if;



        if trigger_reentrancy(csr_file, tdata1) or action1 = '1' then
          hitv := (hit and (hit'range => (valid and conthit_in(i))));
        end if;


        -- Chaining MCONTROL6 triggers
        -- Each iteration the next trigger is checked
        -- Chainhit(j) should be equal to one for any trigger to fire
        -- Chainhit(j) is initialized to 1 and is only set to zero if
        -- a trigger is configured to be chained with the next one and this
        -- trigger does not hit.
        -- Since only MCONTROL6 triggers have priority different than zero, it does not matter
        -- which priority they have (from 1 to 3) when they are compared with other triggers.
        -- Since there are only two MCONTROL6 triggers, the situation where chianed MCONTROL6 triggers
        -- and a non-chained MCONTROL6 trigger fire in the same instruciton is not possible, and
        -- priority when triggers are chianed doesn't matter provided that is different than zero.
        -- This would change if more MCONTROL6 triggers were added.
        if i < TRIGGER_MC_NUM then
          for j in chainhit'range loop -- Triggers must fire at the same instruction
            if tdata1(11) = '1' then
              chainhit(j) := chainhit(j) and hitv(j);
              hitv(j) := '0'; -- can't fire if chained
            else
              hitv(j) := hitv(j) and chainhit(j);
              chainhit(j) := '1';
            end if;
          end loop;
        end if;


        -- We keep the hit information for each trigger and each lane
        -- We also keep for each lane all the actions that have to be
        -- performed according to the trigger hits and their priorities.
        intpri := hit(hit'high downto lanes'high + 1);
        for j in lanes'high downto lanes'low loop
          if hitv(j) = '1' then
            if i < TRIGGER_MC_NUM then  -- mcontrol6 trigger
              -- If any lane produce a hit in any mcontrol6 trigger,
              -- the data cache has to be nullified.
              -- It could happen that a icount trigger is pending in the
              -- memory stage. This trigger has fired in a previous instruction
              -- and therfore the mcontrol6 fire will be discarded. Anyway,
              -- nullifying the cache has no efect. Doing it like this improves
              -- the timing of this critical path.
              if j = memory_lane or m_swap = '1' then
                -- Nullify only if the hit is in the lane 0 or the lanes are swapped
                -- otherwise we could nullify a valid load/store that is executed
                -- previously to a instruction that is firing the trigger.
                mc6nullify := '1';
              end if;
              if u2i(intpri) <= u2i(finpri(j)) then
                mc6hit(j)    := '1';
                action       := trigger_action(tdata1);
                if u2i(intpri) = u2i(finpri(j)) then
                  hitvec(j)(i) := '1';
                  mc6action(j) := mc6action(j) or action(trig.action'range);
                  mc6_tval(j)  := mc6_tval_temp(j);
                else
                  hitvec(j)(TRIGGER_MC_NUM - 1 downto 0) := (others => '0');
                  hitvec(j)(i) := '1';
                  mc6action(j) := action(trig.action'range);
                  mc6_tval(j)  := mc6_tval_temp(j);
                end if;
                finpri(j)    := intpri;
              end if;
            else -- icount triggers
              hitvec(j)(i) := '1';
              ichit(j)     := '1';
              action       := trigger_action(tdata1);
              icaction(j)  := icaction(j) or action(trig.action'range);
            end if;
          end if;
        end loop;
      end loop;
    end if;

    -- We have to bare in mind that we are evaluating the mcontrol6 triggers
    -- in the memory stage while the icount trigger is evaluated in the execution
    -- stage.
    if not all_0(mc6hit) then
      thit     := mc6hit;
      taction  := mc6action;
      tpri     := finpri;
      bypass   := '1';
      swap     := m_swap;
      -- We need to avoid bypassing an icount hit
      -- along with an mcontrol6 hit
      if TRIGGER_IC_NUM /= 0 then
        for j in lanes'high downto lanes'low loop
          hitvec(j)(TRIGGER_MC_NUM) := '0';
        end loop;
      end if;
    else
      if TRIGGER_IC_NUM /= 0 then
        thit    := ichit;
        taction := icaction;
        tpri    := (others => (others => '0'));
        bypass  := '0';
        swap    := e_swap;
      end if;
    end if;

    -- Since we are evaluating both lanes at the same time we should determine wich lane is executing
    -- the first instruction to determine the actions to perform.
    if single_issue = 0 then
      if (thit(0) = '1' and swap = '0') or (thit(0) = '1' and swap = '1' and thit(one) = '0') then
        trig.action   := taction(0);
        trig.priority := tpri(0);
        trig.hit      := hitvec(0);
        trig.mc6tval  := mc6_tval(0);
      elsif (thit(one) = '1' and swap = '1') or (thit(one) = '1' and swap = '0' and thit(0) = '0') then
        trig.action   := taction(one);
        trig.priority := tpri(one);
        trig.hit      := hitvec(one);
        trig.mc6tval  := mc6_tval(one);
      end if;
      trig.lanepri := (thit(0) and not swap) or (thit(one) and swap);
    else
      trig.action   := taction(0);
      trig.priority := tpri(0);
      trig.hit      := hitvec(0);
      trig.mc6tval  := mc6_tval(0);
      trig.lanepri  := '0';
    end if;


    for i in lanes'range loop
      trig.valid(i) := thit(i);
    end loop;

    -- Single and halt step
    if x_rstate = run then
      if step = '1' then
        -- Instructions are issued alone when step=1
        if (m_ctrl(0).valid or m_ctrl(one).valid) = '1' then
          for i in lanes'range loop
            trig.valid(i) := e_ctrl(i).valid;
          end loop;
          trig.pending    := '1';
        end if;
      end if;

      -- Halt
      for i in lanes'range loop
        if haltreq = '1' then
          trig.valid(i) := e_ctrl(i).valid;
        end if;
      end loop;

      if step = '1' or haltreq = '1' then
        trig.action                := (1 => '1', others => '0');
        if TRIGGER_IC_NUM /= 0 then
          trig.hit(TRIGGER_MC_NUM) := '0'; -- If ICOUNT hit, step has priority
        end if;
        if haltreq = '1' then
          trig.hit                 := (others => '0');
        end if;
      end if;
    end if;


    -- When a mcontrol6 fires, the result has to be bypassed to the exception stage since the trigger is
    -- being evaluated in the memory stage.
    -- However, if an icount trigger already fired, this has priority over the mcontrol6 trigger. Although,
    -- if the mcontrol6 trigger and the icount trigger are fired in different instructions and the
    -- instruction that fires the mcontrol6 trigger is executed "before", the trigger has to be bypassed
    -- anyway.
    -- Also Interrupt/Exception triggers have priority over MCONTROL6 trigger
    -- Step sets r.e.trig.valid to 1 when the first instruction reaches the memory stage. The MCONTROL6 trigger
    -- sets r.m.trig.valid to 1 when the instruction that makes the trigger hit reaches the memory stage.
    -- Therefore, step has priority over MCONTROL6 and it won't be bypassed when there is a pending step
    -- That occurs when: not (orv(trig_in.valid) = '1' and orv(trig_in.hit) = '0')
    me_bypass_trig := trig_none;
    if bypass = '1' and
       (all_0(trig_in.valid) or (trig_in.lanepri = '0' and trig.lanepri = '1' and single_issue = 0)) and
       ie_trig_in.pending = '0' and not (not all_0(trig_in.valid) and all_0(trig_in.hit)) then
      me_bypass_trig := trig;
      -- Nullify calculation must be replicated for the bypassed trigger
      me_bypass_trig.nullify(0)     := trig.valid(0) or (to_bit(single_issue = 0) and trig.valid(one) and swap);
      if single_issue = 0 then
        me_bypass_trig.nullify(one) := trig.valid(one) or (trig.valid(0) and (not swap));
      end if;
    else
      bypass := '0';
    end if;
    mc6bypass := bypass;


    if (trig_in.pending or ie_trig_in.pending) = '1' then
      trig            := trig_in;
      for i in lanes'range loop
        trig.valid(i) := e_ctrl(i).valid;
      end loop;
    end if;

    trig.nullify(0)     := trig.valid(0) or (to_bit(single_issue = 0) and trig.valid(one) and swap);
    if single_issue = 0 then
      trig.nullify(one) := trig.valid(one) or (trig.valid(0) and (not swap));
    end if;

    if not all_0(trig_in.nullify) then
      trig.nullify := (others => '1');
    end if;

    if clr_pen = '1' then
      trig.pending := '0';
    end if;

    -- The hardware prevents triggers with action =0 from matching while in M-mode and while
    -- MIE in mstatus is 0. If medeleg [3]=1 then it prevents triggers with action =0 from matching
    -- while in S-mode and while SIE in sstatus is 0. If medeleg [3]=1 and hedeleg [3]=1 then it
    -- prevents triggers with action =0 from matching while in VS-mode and while SIE in vsstatus
    -- is 0.
    -- If *EPC is going to be overwritten, prevent the Interrupt/Exception trigger from firing
    clr_ie_trig := '0';
    ie_trig_hit := '0';
    if ie_trig_in.pending = '1' and ie_trig_in.action(0) = '1' and
       ((r.csr.prv = PRIV_LVL_M) or
        (r.csr.prv = PRIV_LVL_S and r.csr.v = '0' and r.csr.medeleg(3) = '1') or
        (r.csr.prv = PRIV_LVL_S and (r.csr.v and r.csr.medeleg(3) and r.csr.hedeleg(3)) = '1')) then
      clr_ie_trig := '1';
    end if;

    -- Trigger to the memory stage
    m_trig    := trig;


    -- Exception precalculation
    -- Use the trigger in the memory stage to calculate the exception
    -- and values that otherwise would have to be calculated in exception
    -- stage making the timing closure more difficult

    -- If the trigger that has the biggest priority is the MCONTROL6 bypassed
    -- from the memory stage, the trigger is also bypassed here to calculate
    -- these values.
    if bypass = '1' then
      v_x_trig := trig;
    else
      v_x_trig := trig_in;
    end if;

    -- Register: xc, xcs, xc_lane, flush, trig_flushall, action0,
    -- cause, trig_taken, ie_trig_taken, pc, ie_trig_hit, mc6mtval
    if (r.m.ctrl(0).valid or r.m.ctrl(one).valid) = '1' then
      if (v_x_trig.action(1) or ie_trig_in.action(1)) = '1' then
        -- ACTION 1
        -- action 1 has priority over action 0
        -- We prioritize interrupt/exception triggers
        if ie_trig_in.pending = '1' then
          trigxc.xc                 := '0';
          trigxc.xcs                := (others => '0');
          for i in lanes'range loop
            -- Flush instructions in the wb stage and keep
            -- track of the trigger fired for the debug module
            trigxc.flush(i)         := r.m.ctrl(i).valid;
            trigxc.ie_trig_taken(i) := r.m.ctrl(i).valid;
          end loop;
          trigxc.trig_flushall      := '1'; -- Flush following instructions
          trigxc.valid              := '1';
          ie_trig_hit               := '1';
        elsif not all_0(v_x_trig.valid) then
          trigxc.xcs           := (others => '0');
          trigxc.xc            := '0';
          for i in lanes'range loop
            trigxc.flush(i)    := v_x_trig.nullify(i);
          end loop;
          trigxc.trig_taken    := '1';
          trigxc.trig_flushall := '1'; -- Flush following instructions
          trigxc.valid         := '1';
        end if;
      elsif (v_x_trig.action(0) or ie_trig_in.action(0)) = '1' then
        -- ACTION 0
        if ie_trig_in.pending = '1' then
          trigxc.xc         := '1';
          trigxc.xcs        := (others => '0');
          for i in lanes'range loop
            trigxc.flush(i) := r.m.ctrl(i).valid;
          end loop;
          trigxc.cause      := XC_INST_BREAKPOINT;
          -------------
          -- Set the PC and exception to the first valid instruction
          trigxc.xc_lane       := '0';
          if single_issue = 0 then
            if m_swap = '0' then
              trigxc.xc_lane   := not r.m.ctrl(0).valid;
            else
              trigxc.xc_lane   := r.m.ctrl(one).valid;
            end if;
          end if;
          trigxc.pc            := r.m.ctrl(u2i(trigxc.xc_lane)).pc;
          trigxc.xcs(u2i(trigxc.xc_lane)) := '1';
          -------------
          trigxc.trig_flushall := '1';  -- Flush following instructions
          trigxc.action0       := '1';
          trigxc.valid         := '1';
          ie_trig_hit          := '1';
        elsif not all_0(v_x_trig.valid) then
          -----------------------------
          trigxc.xc    := '1';
          trigxc.xcs   := (others => '0');
          trigxc.cause := XC_INST_BREAKPOINT;
          -------------
          -- Set the PC and exception to the first valid instruction
          -- this if is the same as trig.nullify??
          if m_swap = '0' then
            if v_x_trig.valid(0) = '1'  then
              trigxc.pc      := r.m.ctrl(0).pc;
              trigxc.xc_lane := '0';
            elsif single_issue = 0 then  -- x_trig.valid(one) = '1'
              trigxc.pc      := r.m.ctrl(one).pc;
              trigxc.xc_lane := '1';
            end if;
            trigxc.flush := "1" & not trigxc.xc_lane;
          else
            if single_issue = 0 and v_x_trig.valid(one) = '1' then
              trigxc.pc      := r.m.ctrl(one).pc;
              trigxc.xc_lane := '1';
            else -- x_trig.valid(0) = '1'
              trigxc.pc      := r.m.ctrl(0).pc;
              trigxc.xc_lane := '0';
            end if;
            trigxc.flush := trigxc.xc_lane & "1";
          end if;
          trigxc.xcs(u2i(trigxc.xc_lane)) := '1';
          -------------
          trigxc.trig_flushall := '1';  -- Flush following instructions
          trigxc.action0       := '1';
          -----------------------------
          trigxc.trig_taken    := '1';
          trigxc.valid         := '1';
          -- set tval
          trigxc.mc6tval := v_x_trig.mc6tval;
        end if;
      end if;
    end if;

    trigxc_out := trigxc;
  end;

  -- Debug Module Procedure
  procedure debug_module(r               : in  registers;
                         dpc_in          : in  wordx;
                         dcsr_in         : in  csr_dcsr_type;
                         prv_in          : in  priv_lvl_type;
                         v_in            : in  std_ulogic;
                         elp_in          : in  std_ulogic;
                         useDebug        : in  integer;
                         dbgi            : in  nv_debug_in_type;
                         dm_in           : in  debugmodule_reg_type;
                         xc_in           : in  lanes_type;
                         xc_taken_in     : in  std_ulogic;
                         xc_cause_in     : in  cause_type;
                         dret_in         : in  std_ulogic;
                         x_trig          : in  trig_type;
                         x_ie_trig       : in  ie_trig_type;
                         x_ie_trig_taken : in  lanes_type;
                         ebreak_action0  : in  std_ulogic;
                         xc_crit_err     : in  std_ulogic;
                         rfo_data1       : in  wordx;
                         csr_data1       : in  wordx;
                         tbo_data        : in  trace_data;
                         tbufcnt         : in  std_logic_vector;
                         trace_trig_out  : out lanes_type;
                         running_out     : out std_ulogic;
                         halted_out      : out std_ulogic;
                         pc_out          : out pctype;
                         req_out         : out std_ulogic;
                         rstate_out      : out core_state;
                         prv_out         : out priv_lvl_type;
                         v_out           : out std_ulogic;
                         elp_out         : out std_ulogic;
                         dpc_out         : out wordx;
                         dcsr_out        : out csr_dcsr_type;
                         dm_out          : out debugmodule_reg_type;
                         crit_err_out    : out std_ulogic;
                         flushall_out    : out std_ulogic;
                         dvalid_out      : out std_ulogic;
                         ddata_out       : out word64;
                         derr_out       : out std_ulogic;
                         dexec_done_out : out std_ulogic;
                         haltreq_out    : out std_ulogic;
                         stoptime_out   : out std_ulogic) is
    variable dbgi_dsuen  : std_ulogic    := cond(dsuen_delay = 1, r.dbgi_dsuen, dbgi.dsuen);
    -- Non-constant
    -- Output signals to the Debug Module
    variable dvalid      : std_ulogic    := '0';
    variable dexec_done  : std_ulogic    := '0';
    variable ddata       : word64        := (others => '0');
    variable derr        : std_ulogic    := '0';

    variable flushall    : std_ulogic    := '0';
    variable trace_trig  : lanes_type    := (others => '0');
    variable dcsr        : csr_dcsr_type := dcsr_in;
    variable dpc         : wordx;
    variable rstate      : core_state    := r.x.rstate;
    variable prv         : priv_lvl_type := prv_in;
    variable v           : std_ulogic    := v_in;
    variable elp         : std_ulogic    := elp_in;
    variable dm          : debugmodule_reg_type := dm_in;

    -- Signals for the PC Fetch
    variable dfpc        : wordx         := dpc_in;
    variable req         : std_ulogic    := '0';     --

    variable halted      : std_ulogic    := '0';
    variable running     : std_ulogic    := '1';
    variable halt_ebreak : std_ulogic    := '0';
    variable haltreq     : std_ulogic    := '0';
    variable stoptime    : std_ulogic    := '0';
  begin
    -- Generate output signal
    if r.x.rstate /= run and useDebug = 1 then
      running  := '0';
      halted   := '1';
      flushall := '1';
      stoptime := r.csr.dcsr.stoptime;
    end if;

    -- If the step bit is set let the hart commit the instruction
    -- even if there is a halt request (or request by halt group)
    if r.x.rstate = run and
       ((dbgi.halt = '1' and r.csr.dcsr.step = '0')
       ) and useDebug = 1 then
      haltreq  := '1';
    end if;

    dm.havereset := '0' & dm_in.havereset(3 downto 1);

    ---------------
    -- Run State
    ---------------

    if  (r.csr.v = '0' and r.csr.prv = PRIV_LVL_M and r.csr.dcsr.ebreakm  = '1') or
        (r.csr.v = '0' and r.csr.prv = PRIV_LVL_S and r.csr.dcsr.ebreaks  = '1') or
        (r.csr.v = '0' and r.csr.prv = PRIV_LVL_U and r.csr.dcsr.ebreaku  = '1') or
        (r.csr.v = '1' and r.csr.prv = PRIV_LVL_S and r.csr.dcsr.ebreakvs = '1') or
        (r.csr.v = '1' and r.csr.prv = PRIV_LVL_U and r.csr.dcsr.ebreakvu = '1') then
      halt_ebreak    := '1';
    end if;

    -- When there are multiple reasons to enter Debug Mode in a single cycle,
    -- hardware should set cause to the cause with the highest priority.
    -- * 5 -> Halt-group
    -- * 4 -> Trigger Module
    -- * 3 -> Ebreak instruction
    -- * 2 -> ResetHaltRequest
    -- * 1 -> Halt-Request
    -- * 0 -> Single Step from the Hart

    dpc              := dfpc;

    -- Check for halt/reset signal
    if r.x.rstate = run and
       (dbgi_dsuen = '1'
       ) and useDebug = 1 then
      if (TRIGGER /= 0 and not all_0(x_trig.valid) and
          not all_0(x_trig.hit) and x_trig.action(1) = '1') or
         not all_0(x_ie_trig_taken) then  -- Triggers
        dcsr.cause   := DCAUSE_TRIG;
        rstate       := dhalt;
        dcsr.prv     := r.csr.prv;
        dcsr.v       := r.csr.v;
        if ext_zicfilp = 1 then
          dcsr.pelp  := r.csr.elp;
          elp        := '0';
        end if;
        prv          := PRIV_LVL_M;
        v            := '0';
        -- Find the trapped instruction.
        if r.x.swap = '0' then
          if (x_trig.valid(0) or x_ie_trig_taken(0)) = '1'  then
            dpc           := pc2xlen(r.x.ctrl(0).pc);
            trace_trig(0) := '1';
          elsif single_issue = 0 then -- x_trig.valid(one) = '1'
            dpc             := pc2xlen(r.x.ctrl(one).pc);
            trace_trig(one) := '1';
          end if;
        else
          if single_issue = 0 and
             (x_trig.valid(one) or x_ie_trig_taken(one)) = '1' then
            dpc             := pc2xlen(r.x.ctrl(one).pc);
            trace_trig(one) := '1';
          else -- x_trig.valid(0) = '1'
            dpc           := pc2xlen(r.x.ctrl(0).pc);
            trace_trig(0) := '1';
          end if;
        end if;
      elsif not all_0(x_trig.valid) and (dbgi.halt or r.csr.dcsr.step) = '1' then -- Halt and Step
        if dbgi.halt = '1' then
        -- Halt request from the Debug Module
        -- Wait for valid instruction marked with trig in the exception stage.
          dcsr.cause := DCAUSE_HALT;
          if dbgi.haltgroup = '1' then
            dcsr.cause := DCAUSE_GROUPHALT;
          end if;
        elsif r.csr.dcsr.step = '1' then
        -- Single Step from the Hart
        -- Wait for valid instruction in the exception stage.
          dcsr.cause := DCAUSE_STEP;
        end if;

        rstate       := dhalt;
        dcsr.prv     := r.csr.prv;
        dcsr.v       := r.csr.v;
        if ext_zicfilp = 1 then
          dcsr.pelp  := r.csr.elp;
          elp        := '0';
        end if;
        prv          := PRIV_LVL_M;
        v            := '0';
        -- Assert flushall signal in order to annull next instructions.
        flushall     := '1';
        -- Find single step instruction and the next one.
        if r.x.swap = '0' then
          if x_trig.valid(0) = '1' then
            dpc      := pc2xlen(r.x.ctrl(0).pc);
          elsif single_issue = 0 then  -- x_trig.valid(one) = '1'
            dpc      := pc2xlen(r.x.ctrl(one).pc);
          end if;
        else
          if single_issue = 0 and
             x_trig.valid(one) = '1' then
            dpc      := pc2xlen(r.x.ctrl(one).pc);
          else -- x_trig.valid(0) = '1'
            dpc      := pc2xlen(r.x.ctrl(0).pc);
          end if;
        end if;
      elsif xc_taken_in = '1' and ebreak_action0 = '0' and xc_cause_in = XC_INST_BREAKPOINT and halt_ebreak = '1' then
        -- ebreak instruction
        rstate       := dhalt;
        -- Address of the ebreak instruction
        dpc          := pc2xlen(r.x.ctrl(0).pc);
        if single_issue = 0 and
           (xc_in(one) and r.x.ctrl(one).valid) = '1' then
          dpc        := pc2xlen(r.x.ctrl(one).pc);
        end if;
        dcsr.cause   := DCAUSE_EBREAK;
        dcsr.prv     := r.csr.prv;
        dcsr.v       := r.csr.v;
        prv          := PRIV_LVL_M;
        v            := '0';
      end if;


    end if;

    -- If there is a critical error due to a double trap in M-mode (Smdbltrp)
    -- enter in debug mode with cause=7 and extcause=0
    if (xc_crit_err and r.csr.dcsr.cetrig) = '1' then
      dcsr.cause    := DCAUSE_EXTENDED;
      dcsr.extcause := EXTDCAUSE_CRITERROR;
      rstate        := dhalt;
      dcsr.prv      := r.csr.prv;
      dcsr.v        := r.csr.v;
      prv          := PRIV_LVL_M;
      v            := '0';

      -- Find the trapped instruction.
      if single_issue = 1 or
         (r.x.swap = '0' and xc_in(0) = '1') or
         (r.x.swap = '1' and xc_in(one) = '1')  then
        dpc           := pc2xlen(r.x.ctrl(0).pc);
      else
        dpc             := pc2xlen(r.x.ctrl(one).pc);
      end if;
    end if;
    -- If cettrig is not set also rise the critical-error signal
    -- for the platform to take action (reset system, hart)
    if (r.csr.dcsr.cetrig = '0' or useDebug = 0 or dbgi_dsuen = '0') and
       xc_crit_err = '1' then
      crit_err_out := '1';
      rstate       := dhalt; -- Stop the hart
    else
      crit_err_out := '0';
    end if;


    ---------------
    -- Halt State
    ---------------

    -- There can be two reasons to exit from Debug Module, we check them following
    -- the above priorities.
    -- * 2 -> dret instruction
    -- * 1 -> Debug Module Request
    dm.cmdexec := '0' & dm_in.cmdexec(1);

    if r.x.rstate = dhalt and dbgi_dsuen = '1' and useDebug = 1 then
      if dret_in = '1' then  -- Generate in the exception stage
        rstate         := run;
        prv            := r.csr.dcsr.prv;
        v              := r.csr.dcsr.v;
        if ext_zicfilp = 1 then
          elp := '0';
          case prv is
          when PRIV_LVL_M =>
            if r.csr.mseccfg.mlpe = '1' then
              elp := r.csr.dcsr.pelp;
            end if;
          when PRIV_LVL_S =>
            if v = '1' then
              if r.csr.henvcfg.lpe = '1' then
                elp := r.csr.dcsr.pelp;
              end if;
            else
              if r.csr.menvcfg.lpe = '1' then
                elp := r.csr.dcsr.pelp;
              end if;
            end if;
          when others =>
            if mode_s = 1 then
              if r.csr.senvcfg.lpe = '1' then
                elp := r.csr.dcsr.pelp;
              end if;
            else
              if r.csr.menvcfg.lpe = '1' then
                elp := r.csr.dcsr.pelp;
              end if;
            end if;
          end case;
        end if;
        -- Generate signal for the PC
        req            := '1';
      elsif dbgi.resume = '1' and dbgi.denable = '0' then
        -- Check for resume signal from Debug Module.
        -- Do not resume execution if command is still on going.
        rstate         := run;
        prv            := r.csr.dcsr.prv;
        v              := r.csr.dcsr.v;
        if ext_zicfilp = 1 then
          elp := '0';
          case prv is
          when PRIV_LVL_M =>
            if r.csr.mseccfg.mlpe = '1' then
              elp := r.csr.dcsr.pelp;
            end if;
          when PRIV_LVL_S =>
            if v = '1' then
              if r.csr.henvcfg.lpe = '1' then
                elp := r.csr.dcsr.pelp;
              end if;
            else
              if r.csr.menvcfg.lpe = '1' then
                elp := r.csr.dcsr.pelp;
              end if;
            end if;
          when others =>
            if mode_s = 1 then
              if r.csr.senvcfg.lpe = '1' then
                elp := r.csr.dcsr.pelp;
              end if;
            else
              if r.csr.menvcfg.lpe = '1' then
                elp := r.csr.dcsr.pelp;
              end if;
            end if;
          end case;
        end if;
        -- Generate signal for the PC
        req            := '1';
      end if;
      -- Register denable signal
      if dm_in.cmdexec = (dm_in.cmdexec'range => '0') then
        -- Check for command
        if dbgi.denable = '1' then
          dm.cmdexec   := "10";
          dm.size      := dbgi.dsize;
          dm.cmd       := dbgi.dcmd;
          dm.write     := dbgi.dwrite;
          dm.addr      := dbgi.daddr;
        end if;
      elsif dm_in.cmdexec(0) = '1' then
        -- Drive output to Debug Module
        -- We assume 2 cycle latency to access RF.
        -- We actually support only GPRs and CSRr register access.
        if dm_in.addr(15 downto 12) = "0000" or dm_in.addr(15 downto 5) = "00010000000" then
          dvalid       := '1';
          if dm_in.addr(15 downto 12) = "0000" then
            ddata      := to64(csr_data1);
            if dm_in.csr_xc = '1' then
              derr := '1';
            end if;
          else
            ddata      := to64(rfo_data1);
          end if;
        elsif dm_in.addr(15 downto 4) = "110000000000" then
          dvalid       := '1';
          if dm_in.addr(3 downto 0) = x"8" then
            if dm_in.write = '1' then
              dm.tbufaddr := dbgi.ddata(dm.tbufaddr'range);
            else
              ddata    := uext(dm_in.tbufaddr, 64);
            end if;
          elsif dm_in.addr(3 downto 0) = x"9" then
              ddata    := uext(tbufcnt, 64);
          else
            case dm_in.addr(2 downto 0) is
            when "000"  => ddata    := tbo_data( 63 downto   0);
            when "001"  => ddata    := tbo_data(127 downto  64);
            when "010"  => ddata    := tbo_data(191 downto 128);
            when "011"  => ddata    := tbo_data(255 downto 192);
            when "100"  => ddata    := tbo_data(319 downto 256);
            when "101"  => ddata    := tbo_data(383 downto 320);
            when "110"  => ddata    := tbo_data(447 downto 384);
            when others => ddata    := tbo_data(511 downto 448);
            end case;
          end if;
        else
          dvalid       := '1';
          derr         := '1';
        end if;
        -- Set Program Buffer address in Fetch PC.
        if dm_in.cmd(1) = '1'  then
          if derr = '0' then
            req        := '1';
            dfpc       := DPROGBUF;
            rstate     := dexec;
            prv        := PRIV_LVL_M;
            v          := '0';
            elp        := '0';
          else
            -- Don't execute if REG access fails
            dexec_done := '1';
          end if;
        end if;
      end if;
    elsif r.x.rstate = dexec and dbgi_dsuen = '1' and useDebug = 1 then
      -- Mask flush signal
      flushall         := '0';
      -- Search for committed ebreak instruction.
      for i in lanes'range loop
        if (r.x.ctrl(i).valid and xc_in(i)) = '1' then
          rstate       := dhalt;
          dexec_done   := '1';
          -- Not ebreak?
          -- Do not care about this if not first time around the
          -- loop and the first already came inside the outer if-statement.
          if r.x.ctrl(i).inst /= x"00100073" and flushall = '0' then
            derr       := '1';
          end if;
          flushall     := '1';
        end if;
      end loop;
    end if;

    running_out    := running;
    halted_out     := halted;
    trace_trig_out := trace_trig;
    pc_out         := to_addr(dfpc);
    req_out        := req;
    rstate_out     := rstate;
    prv_out        := prv;
    v_out          := v;
    elp_out        := elp;
    dpc_out        := dpc;
    dcsr_out       := dcsr;
    dm_out         := dm;
    flushall_out   := flushall;
    dvalid_out     := dvalid;
    ddata_out      := ddata;
    derr_out       := derr;
    dexec_done_out := dexec_done;
    haltreq_out    := haltreq;
    stoptime_out   := stoptime;
  end;

  function csr_mmu_pipe(reg : atp_type; noreg : atp_type;
                        pipe_ppn : boolean; pipe_id : boolean; pipe_mode : boolean) return atp_type is
    -- Non-constant
    variable atp : atp_type := reg;
  begin
    if not pipe_ppn then
      atp.ppn    := noreg.ppn;
    end if;
    if not pipe_id then
      atp.id     := noreg.id;
    end if;
    if not pipe_mode then
      atp.normal := noreg.normal;
      atp.small  := noreg.small;
    end if;

    return atp;
  end;

begin

  ----------------------------------------------------------------------------
  -- Signal Assignments
  ----------------------------------------------------------------------------

  hart <= dbgi.hartid(hart'range);

  arst <= testrst when (ASYNC_RESET and scantest /= 0 and testen /= '0')  else
          rstn when ASYNC_RESET else '1';

  csr_mmu.hartid         <= dbgi.hartid;
  csr_mmu.satp           <= csr_mmu_pipe(r.mmu.satp,  rin.mmu.satp,  false, false, false);
  csr_mmu.vsatp          <= csr_mmu_pipe(r.mmu.vsatp, rin.mmu.vsatp, false, false, false);
  csr_mmu.hgatp          <= csr_mmu_pipe(r.mmu.hgatp, rin.mmu.hgatp, false, false, false);
  csr_mmu.m_adue         <= rin.mmu.m_adue
                            ;
  csr_mmu.vs_adue        <= rin.mmu.vs_adue
                            ;
  csr_mmu.h_ade          <= r.mmu.h_ade;
  csr_mmu.pma_fault_02   <= r.mmu.pma_fault_02;
  csr_mmu.pma_fault_46   <= r.mmu.pma_fault_46;
  csr_mmu.mmu_sptfault   <= r.mmu.mmu_sptfault;
  csr_mmu.mmu_hptfault   <= r.mmu.mmu_hptfault;
  csr_mmu.mmu_oldfence   <= r.mmu.mmu_oldfence;
  csr_mmu.pmpcfg         <= r.mmu.pmpcfg;
  csr_mmu.mmwp           <= r.mmu.mmwp;
  csr_mmu.mml            <= r.mmu.mml;
  csr_mmu.menvcfg_sse    <= r.mmu.menvcfg_sse;
  csr_mmu.henvcfg_sse    <= r.mmu.henvcfg_sse;
  csr_mmu.precalc        <= r.csr.pmp_precalc;
  -- Do not worry about extra pipelining for PMA, since it is (normally) not writable.
  csr_mmu.pma_precalc    <= r.csr.pma_precalc;
  csr_mmu.pma_data       <= r.csr.pma_data;
  csr_mmu.cctrl          <= r.csr.cctrl;




  comb : process(r, bhto, btbo, raso, ico, dco, rfo, irqi, dbgi,
                 itraceo,
                 mulo, divo,
                 pma_addr, pma_data,
                 fpuo, fpuoa, tbo, hart, rstn, holdn, mmu_csr, perf, cap, imsico)

    variable v                  : registers;

    -- Inputs
    variable xc_rstn            : std_ulogic;

    -- Debug
    variable dbg_request        : std_ulogic;
    variable dbg_pc             : pctype;
    variable dbg_flushall       : std_ulogic;
    variable dbg_dvalid         : std_ulogic;
    variable dbg_ddata          : word64;
    variable dbg_derr           : std_ulogic;
    variable dbg_dexec_done     : std_ulogic;
    variable dbg_running        : std_ulogic;
    variable dbg_halted         : std_ulogic;
    variable trace_trig         : std_ulogic;
    variable dbg_haltreq        : std_ulogic;
    variable dbg_stoptime       : std_ulogic;
    variable dbg_crit_err       : std_ulogic;

    -- FPU
    variable vfpui              : fpu5_in_type;
    variable vfpuia             : fpu5_in_async_type;


    -- IMSIC
    variable vimsici            : imsic_in_type;


    -- Instruction Control
    variable ic_hold_issue      : std_ulogic;
    variable ic_lbranch         : std_ulogic;
    variable ic_lalu            : fetch_pair;

    -- Register File
    variable rfi_raddr12        : rfa_lanes_type;
    variable rfi_raddr34        : rfa_lanes_type;
    variable rfi_ren12          : lanes_type;
    variable rfi_ren34          : lanes_type;
    variable rfi_wen12          : lanes_type;
    variable rfi_wdata12        : wordx_lanes_type;
    variable rfi_waddr12        : rfa_lanes_type;
    variable rfi_rdhold         : std_ulogic;

    variable fpu_ctrl           : pipeline_ctrl_type;

    -- Fetch Stage
    variable f_inull            : std_ulogic;
    variable mux_valid          : std_ulogic;
    variable mux_pc             : pctype;
    variable next_pc            : pctype;
    variable mux_reread         : std_ulogic;  -- Ensure "clean" instruction read
    variable reread_pc          : std_ulogic;  --   when needed.
    variable f_pb_exec          : std_ulogic;
    variable mexc_inull         : std_ulogic;
    variable btb_hitv           : std_ulogic;

    variable ras_hit_1st        : std_ulogic;

    -- Decode Stage
    variable de_inst            : iword_pair_type;
    variable de_inst_buff       : iword_pair_type;
    variable de_comp_ill        : word2;
    variable de_cinst_buff      : word16_fetch_type;
    variable de_inst_valid      : fetch_pair;
    variable de_inst_xc_msb     : std_ulogic;
    variable de_pc              : pc_fetch_type;
    variable de_comp            : fetch_pair;
    variable de_issue           : fetch_pair;
    variable de_lane0_csr       : std_ulogic;
    variable de_swap            : std_ulogic;
    variable de_hold_pc         : std_ulogic;  -- Do not increase PC
    variable de_inull           : std_ulogic;  -- Invalidate current I$ fetch
    variable de_rfa1            : rfa_fetch_type;
    variable de_rfa2            : rfa_fetch_type;
    variable de_rfa1_nmask      : rfa_fetch_type;
    variable de_rfa2_nmask      : rfa_fetch_type;
    variable de_rfa1_nmasked    : rfa_fetch_type;
    variable de_rfa2_nmasked    : rfa_fetch_type;
    variable de_rfrd_valid      : fetch_pair;
    variable de_imm_valid       : fetch_pair;
    variable de_imm             : wordx_pair_type;
    variable de_bj_imm          : wordx_pair_type;
    variable de_pc_valid        : fetch_pair;
    variable de_csr_valid       : fetch_pair;
    variable de_csr_rdo         : fetch_pair;
    variable de_fusel           : fusel_fetch_type;
    variable de_xc              : fetch_pair;
    variable de_xc_cause        : cause_fetch_type;
    variable de_xc_tval         : wordx_pair_type;
    variable de_to_ra_xc        : fetch_pair;
    variable de_to_ra_cause     : cause_fetch_type;
    variable de_to_ra_tval      : wordx_pair_type;
    variable de_buff_inst_xc    : word3;
    variable de_inst_no_buf     : word2;
    variable de_inst_mexc       : word2;
    variable v_a_inst_no_buf    : word2;
    variable de_nullify         : std_ulogic;
    variable de_branch_taken    : std_ulogic;
    variable de_branch_hit      : std_ulogic;
    variable de_branch_valid    : std_ulogic;
    variable de_branch_addr     : pctype;
    variable de_branch_next     : pctype;
    variable de_branch_xc       : std_ulogic;
    variable de_branch_cause    : cause_type;
    variable de_jump            : std_ulogic;
    variable de_jump_addr       : pctype;
    variable de_jump_xc         : std_ulogic;
    variable de_jump_cause      : cause_type;
    variable de_jump_tval       : wordx;
    variable de_bjump           : std_ulogic;
    variable de_btb_taken       : std_ulogic;
    variable de_btb_taken_buff  : std_ulogic;
    variable de_bjump_buff      : std_ulogic;
    variable de_bjump_pos       : word4;
    variable de_bjump_addr      : pctype;
    variable de_bhto_taken      : fetch_pair;
    variable de_bhto_taken_tmp  : std_ulogic;
    variable de_btbo_hit        : fetch_pair;
    variable de_btbo_hit_tmp    : std_ulogic;
    variable de_btb_valid       : word4;
    variable de_lalu_pre        : fetch_pair;
    variable de_dual_branch         : fetch_pair;
    variable de_dbranch             : fetch_pair;
    variable de_hit                 : std_ulogic;
    variable de_l0_hit              : std_ulogic;
    variable de_target              : pctype;
    variable de_raso                : nv_ras_out_type;
    variable de_ras_jump_xc         : std_ulogic;
    variable de_ras_jump_cause      : cause_type;
    variable de_ras_jump_tval       : wordx;
    variable de_rasi                : nv_ras_in_type;
    variable de_rvc_instruction     : word_lanes_type;
    variable de_rvc_illegal         : fetch_pair;
    variable de_rvc_comp            : fetch_pair;
    variable de_rvc_comp_ill        : word2;
    variable de_rvc_aligned         : iword_pair_type;
    variable de_mux_instruction     : iword_pair_type;
    variable de_rvc_bhto_taken      : word2;
    variable de_rvc_btb_hit         : word2;
    variable de_rvc_valid           : fetch_pair;
    variable de_rvc_hold            : std_ulogic;
    variable de_rvc_npc             : word3;
    variable de_rvc_xc              : fetch_pair;
    variable de_ipc                 : pc_fetch_type;
    variable de_rvc_buffer_first    : std_ulogic;
    variable de_rvc_buffer_sec      : std_ulogic;
    variable de_rvc_buffer_third    : std_ulogic;
    variable de_rvc_buffer_inst     : iword_type;
    variable de_rvc_buffer_inst_xc  : std_ulogic;
    variable de_rvc_buffer_inst_exp : word;
    variable de_rvc_buffer_cinst    : word16;
    variable de_rvc_buffer_comp     : std_ulogic;
    variable de_rvc_buffer_comp_ill : std_ulogic;
    variable de_mux_cinstruction    : word16_fetch_type;
    variable de_rvc_buff_lpc        : word2;
    variable de_inst_comp_ill       : word2;

    -- Register File Stage
    variable ra_data12          : wordx_lanes_type;
    variable ra_data34          : wordx_lanes_type;
    variable ra_csr_address     : csratype;
    variable ra_csr_xc          : std_ulogic;
    variable ra_csr_cause       : cause_type;
    variable ra_csr_imsic       : word3;
    variable ra_csr             : wordx;
    variable csr_xc             : xc_type;
    variable ra_csrv            : std_ulogic;
    variable ra_csrw            : std_ulogic;
    variable ra_csrr            : std_ulogic;
    variable ra_alu_valid       : lanes_type;
    variable ra_alu_ctrl        : alu_ctrl_lanes_type;
    variable ra_alu_op1         : wordx_lanes_type;
    variable ra_alu_op2         : wordx_lanes_type;
    variable ra_alu_forw        : rs_lanes_type;
    variable ra_stdata_forw     : lanes_type;
    variable ra_jump_op1        : wordx;
    variable ra_jump_forw       : std_logic_vector(1 to 2);
    variable ra_xc              : lanes_type;
    variable ra_xc_cause        : cause_lanes_type;
    variable ra_xc_tval         : wordx_lanes_type;
    variable ra_flush           : std_ulogic;
    variable ra_stdata          : wordx;

    -- Execute Stage
    variable ex_branch_valid    : std_ulogic;
    variable ex_branch_mis      : std_ulogic;
    variable ex_branch_addr     : pctype;
    variable ex_branch_xc       : std_ulogic;
    variable ex_branch_cause    : cause_type;
    variable ex_branch_tval     : wordx;
    variable ex_branch          : std_ulogic;
    variable ex_branch_target   : pctype;
    variable ex_alu_valid       : lanes_type;
    variable ex_alu_res         : wordx_lanes_type;
    variable ex_result          : wordx_lanes_type;
    variable ex_result_fwd      : lanes_type;
    variable ex_flow_op2        : wordx;
    variable ex_dci             : dcache_in_type;
    variable ex_dci_eaddress    : wordx;
    variable ex_stdata          : wordx;
    variable ex_xc              : lanes_type;
    variable ex_xc_cause        : cause_lanes_type;
    variable ex_xc_tval         : wordx_lanes_type;
    variable ex_mul_valid       : std_ulogic;
    variable ex_mul_op          : std_ulogic;
    variable ex_mul_ctrl        : word3;
    variable ex_mul_op1         : wordx;
    variable ex_mul_op2         : wordx;
    variable ex_alu_op1         : wordx_lanes_type;
    variable ex_alu_op2         : wordx_lanes_type;
    variable ex_hold_pc_muldiv  : std_ulogic;
    variable ex_hold_pc         : std_ulogic;
    variable ex_jump_addr       : pctype;
    variable ex_jump_op1        : wordx;
    variable ex_jump            : std_ulogic;
    variable ex_jump_xc         : std_ulogic;
    variable ex_jump_cause      : cause_type;
    variable ex_jump_tval       : wordx;
    variable mem_jump           : std_ulogic;
    variable ex_flush           : std_ulogic;
    variable ex_fpu_flush       : std_ulogic;
    variable ex_branch_flush    : std_ulogic;
    variable ex_address_xc      : std_ulogic;
    variable ex_address_cause   : cause_type;
    variable ex_address_tval    : wordx;
    variable ex_mprv            : std_ulogic;

    -- Memory Stage
    variable me_stdata          : word64;
    variable me_dcache_xc       : std_ulogic;
    variable me_dcache_cause    : cause_type;
    variable me_xc              : lanes_type;
    variable me_xc_cause        : cause_lanes_type;
    variable me_xc_tval         : wordx_lanes_type;
    variable me_nullify         : std_ulogic;
    variable me_size            : word2;
    variable me_laddr           : word3;
    variable me_signed          : std_ulogic;
    variable me_ld_data         : word64;
    variable me_result          : wordx_lanes_type;
    variable me_flush           : std_ulogic;
    variable me_fpu_flush       : std_ulogic;
    variable me_csrw            : lanes_type;
    variable me_ret             : word2;
    variable me_nret            : std_ulogic;
    variable me_int             : std_ulogic;
    variable me_h_en            : boolean;
    variable me_irqand          : wordx;
    variable me_irqand_m        : wordx;
    variable me_irqand_s        : wordx;
    variable me_irqand_v        : wordx;
    variable me_irqprio_m       : std_logic_vector(cause_prio_m'reverse_range);
    variable me_irqprio_s       : std_logic_vector(cause_prio_s'reverse_range);
    variable me_irqprio_v       : std_logic_vector(cause_prio_v'reverse_range);
    variable me_irqcause_m      : cause_type;
    variable me_irqcause_s      : cause_type;
    variable me_irqcause_v      : cause_type;
    variable me_irqcause        : cause_type;
    variable me_aia_vti         : std_ulogic;
    variable lz_cnt             : unsigned(3 downto 0);
    variable me_int_v           : std_ulogic;
    variable pending_int_v      : std_ulogic;
    variable iprio_v            : unsigned(10 downto 0);
    variable iprio1_v           : unsigned(10 downto 0);
    variable iprio2_v           : unsigned(10 downto 0);
    variable icause_v           : cause_type;
    variable icause1_v          : cause_type;
    variable icause2_v          : cause_type;
    variable dpr                : boolean;
    variable mem_branch         : std_ulogic;   -- Branch mispredict from early BU
    variable mem_branch_flush   : std_ulogic;
    variable mem_branch_target  : pctype;
    variable m_inst             : word_lanes_type;
    variable m_valid            : lanes_type;
    variable m_fusel            : fusel_lanes_type;
    variable me_mc6nullify      : std_logic;
    variable me_mc6bypass       : std_logic;
    variable me_bypass_trig     : trig_type;
    variable me_clr_ie_trig     : std_logic;
    variable me_ie_trig_hit     : std_logic;

    -- Exception Stage
    variable x_wb_data          : wordx_lanes_type;
    variable x_wb_wcsr          : wordx_lanes_type;
    variable x_wcsr             : wordx;
    variable x_xc               : lanes_type;
    variable x_xc_cause         : cause_lanes_type;
    variable x_xc_tval          : wordx_lanes_type;
    variable x_xc_ret           : word2;
    variable x_xc_nret          : std_ulogic;
    variable x_ie_trig_taken    : lanes_type;
    variable x_trigxc_out       : trig_exception_type;
    variable x_ebreak_action0   : std_ulogic;
    variable x_xc_crit_err      : std_ulogic;
    variable x_trig_taken       : std_ulogic;
    variable x_clr_trig         : std_ulogic;
    variable x_trig             : trig_type;
    variable x_ie_trig          : ie_trig_type;
    variable x_bt_xc_taken      : std_ulogic;
    variable x_bt_xc_cause      : cause_type;
    variable x_trigxc           : trig_exception_type;
    variable x_trig_flushall    : std_ulogic;
    variable x_lbnull           : std_ulogic;
    variable x_xc_taken         : std_ulogic;
    variable x_xc_lane_out      : std_ulogic;
    variable x_xc_taken_cause   : cause_type;
    variable x_xc_taken_tval    : wordx;
    variable x_xc_taken_tval2   : wordx;
    variable x_xc_taken_gva     : std_ulogic;
    variable x_xc_flush         : lanes_type;
    variable x_xc_pc            : pctype;
    variable x_xc_inst          : word;
    variable x_xc_tvec          : pctype;
    variable x_irq              : nv_irq_in_type;
    variable x_xc_irq_taken     : word2;
    variable x_xc_nmirq_taken   : std_ulogic;
    variable x_flush            : std_ulogic;
    variable x_fpu_flush        : std_ulogic;
    variable x_csr_pipeflush    : std_ulogic;
    variable x_csr_addrflush    : std_ulogic;
    variable x_alu_op1          : wordx_lanes_type;
    variable x_alu_op2          : wordx_lanes_type;
    variable x_csr_op1          : wordx;
    variable x_csr_special      : word2;
    variable x_branch_valid     : std_ulogic;
    variable x_branch_mispredict: std_ulogic;
    variable x_branch_addr      : pctype;
    variable x_branch_xc        : std_ulogic;
    variable x_branch_cause     : cause_type;
    variable x_branch_tval      : wordx;
    variable x_alu_valid        : lanes_type;
    variable x_alu_res          : wordx_lanes_type;
    variable x_dret             : std_ulogic;
    variable x_nextpc           : pctype;
    variable x_csr_dpc          : wordx;
    variable x_csr_val          : wordx;
    variable x_csr_dcsr         : csr_dcsr_type;
    variable x_csr_prv          : priv_lvl_type;
    variable x_csr_v            : std_ulogic;
    variable x_csr_elp          : std_ulogic;
    variable x_rdata            : dcdtype;
    variable dci_specreadannulv : std_ulogic;

    -- Write Back Stage

    variable wb_csr_wen         : std_ulogic;
    variable wb_csr_csra        : csratype;
    variable wb_csr_wdata       : wordx;
    variable wb_csr             : csr_reg_type;
    variable wb_csr_trig        : csr_reg_type;
    variable wb_upd_mcycle      : std_ulogic;
    variable wb_upd_minstret    : std_ulogic;
    variable wb_upd_counter     : hpm_events_type;
    variable wb_fence_i         : std_ulogic;
    variable wb_pipeflush       : std_ulogic;
    variable wb_addrflush       : std_ulogic;
    variable wb_btbflush        : std_ulogic;
    variable wb_fence_pc        : pctype;
    variable wb_bhti            : nv_bht_in_type;
    variable wb_btbi            : nv_btb_in_type;
    variable wb_rasi            : nv_ras_in_type;
    variable wb_branch          : std_ulogic;     -- Branch mispredict from late BU
    variable wb_branch_addr     : pctype;
    variable bhti_wen_v         : std_ulogic;
    variable bhti_taken_v       : std_ulogic;
    variable bhti_ren_v         : std_ulogic;
    variable bhti_waddr         : pctype;
    variable mode_flush         : std_ulogic;

    -- Output
    variable vfpi               : fpu5_in_type;
    variable vfpia              : fpu5_in_async_type;
    variable vrasi              : nv_ras_in_type;
    variable veto               : nv_etrace_type;

    -- Stall
    variable s_inst             : icdtype;
    variable s_way              : std_logic_vector(IWAYMSB downto 0);
    variable s_mexc             : std_ulogic;
    variable s_exctype          : std_ulogic;
    variable s_exchyper         : std_ulogic;
    variable s_tval2            : wordx;
    variable s_tval2type        : word2;
    variable iustall            : std_ulogic;
    variable s_fpu_wait         : std_ulogic;

    -- Wait For Interrupt (WFI) and Low Power Mode
    variable wfi_flushall       : std_ulogic;
    variable wfi_parkreq        : std_ulogic;
    variable wfi_irqpend        : std_ulogic;
    variable pwrdmode           : std_ulogic;

    -- Hardware Performance Monitoring
    variable ic_lddp            : std_ulogic;
    variable ic_stb2b           : std_ulogic;
    variable ic_jal             : std_ulogic;

    variable hpmevent_active    : boolean;
    variable hpmcount           : std_logic_vector(perf_bits downto 0);
    variable s_time             : word64;
    variable s_vtime            : word64;
    variable sstc_stip          : std_ulogic;
    variable sstc_vstip         : std_ulogic;
    variable envcfg             : csr_envcfg_type;
    variable cfi_en             : cfi_t;
    variable ex_lpad            : std_ulogic;
    variable ex_lpad_fail       : std_ulogic;
    variable x_popchk_eq        : std_ulogic;

    variable icache_en          : std_ulogic;

    variable r_f_pc_21          : word2;  -- Locally static for case statement

    variable iu_fflags          : std_logic_vector(r.csr.fflags'range);


    variable fpu_holdn          : std_ulogic;

    variable m_addr             : pctype;

    variable itrace_in          : itrace_in_type;


    variable r_d_valid          : std_ulogic;

  begin
    v := r;



    iustall := '0';

    -- Instruction cache disabled in MMU/cache controller?
    icache_en := '0';
    if ico.ics_btb = "01" or ico.ics_btb = "11" then
      icache_en := '1';
    end if;


    -----------------------------------------------------------------------
    -- INPUTS
    -----------------------------------------------------------------------

    xc_rstn := rstn;

    x_irq   := irqi;

    -- Shadow of MTIME
    if time_en then
      s_time  := irqi.stime;
      s_vtime := uadd(irqi.stime, r.csr.htimedelta);
    else
      s_time  := zerow64;
      s_vtime := zerow64;
    end if;
    -- Sstc extension (timer interrupt pending)
    sstc_stip  := to_bit(unsigned(s_time)  >= unsigned(r.csr.stimecmp));
    sstc_vstip := to_bit(unsigned(s_vtime) >= unsigned(r.csr.vstimecmp));

    -- Current envcfg from pre-calculation
    envcfg     := r.csr.envcfg;
    cfi_en     := r.csr.cfi_en;


    -----------------------------------------------------------------------
    -- WRITE BACK STAGE
    -----------------------------------------------------------------------

    -- Branch misprediction registered
    wb_branch      := r.wb.ctrl(branch_lane).branch.mpred and r.wb.ctrl(branch_lane).valid;
    wb_branch_addr := r.wb.ctrl(branch_lane).branch.naddr;

    -- Fence Logic --------------------------------------------------------
    fence_unit(r,                               -- in  : Register
               wb_fence_pc,                     -- out : PC + 2/4
               wb_fence_i                       -- out : Fence.i Flush Signal
               );

    -- CSR instructions that can cause flush,
    -- write to lock bits in PMPCFG, write to DFEATURESEN, and write to SATP,
    -- have been steered to lane 0 like the fences, so that the same
    -- restart PC can be used.
    wb_pipeflush := wb_fence_i or r.wb.csr_pipeflush;
    wb_addrflush := wb_fence_i or r.wb.csr_addrflush;
    wb_btbflush  := wb_pipeflush or wb_addrflush;

    -- Branch History Table Update Logic ----------------------------------
    bht_update(r.wb.ctrl(branch_lane),          -- in  : Ctrl
               r.wb.unalg_pc,
               r.csr.dfeaturesen,               -- in  : CSR Feature Enable
               wb_bhti                          -- out : BHTI
               );


    -- Branch Target Buffer Update Logic ----------------------------------
    btb_update(r.wb.ctrl(branch_lane),          -- in  : Ctrl
               r.wb.unalg_pc,
               r.csr.dfeaturesen,               -- in  : CSR Feature Enable
               wb_btbflush,                     -- in  : Fence.i Flush Signal
               r.wb.rstate,                     -- in  : Core State
               wb_btbi                          -- out : BTBI
               );

    -- To Branch Target Buffer --------------------------------------------
    btbi.waddr  <= wb_btbi.waddr;
    btbi.wen    <= wb_btbi.wen and holdn and not r.csr.dfeaturesen.btb_dis and icache_en;
    btbi.wdata  <= wb_btbi.wdata;


    if ras >= 1 then
      -- Return Address Stack Update Logic ----------------------------------
      ras_update(0,                                 -- in  : Speculative Flag
                 r.wb.ctrl(branch_lane).inst,       -- in  : Instruction
                 r.wb.ctrl(branch_lane).fusel,      -- in  : Functional Unit
                 r.wb.ctrl(branch_lane).valid,      -- in  : Instruction Valid
                 r.wb.ctrl(branch_lane).xc,         -- in  : Exception
                 r.wb.ctrl(branch_lane).rdv,        -- in  : Destination Valid
                 to_addr(r.wb.wdata(branch_lane)),  -- in  : Return Address
                 r.wb.rasi,                         -- in  : Speculative RAS
                 wb_addrflush,                      -- in  : Fence.i Flush Signal
                 r.wb.rstate,                       -- in  : Core State
                 wb_rasi                            -- out : RASI
                 );
    end if;

    -- To Register File ---------------------------------------------------
    for i in lanes'range loop
      rfi_waddr12(i)      := rd(r, wb, i);
      rfi_wdata12(i)      := r.wb.wdata(i);
      rfi_wen12(i)        := r.wb.ctrl(i).rdv and r.wb.ctrl(i).valid and holdn;
    end loop;

    -- Only allow one write (latest) to a specific destination register!
    if single_issue = 0 and
       all_1(rfi_wen12) and (rfi_waddr12(0) = rfi_waddr12(one)) then
      if r.wb.swap = '0' then
        rfi_wen12(0)      := '0';
      else
        rfi_wen12(one)    := '0';
      end if;
    end if;

    if dmen = 1 then
      if (r.dm.cmdexec(1) and r.dm.write and r.dm.cmd(0)) = '1' and r.x.rstate = dhalt then
        if r.dm.addr(15 downto 5) = "00010000000" then
          rfi_wen12(0)             := '1';
        end if;
        rfi_waddr12(0)             := r.dm.addr(4 downto 0);
        rfi_wdata12(0)(word'range) := dbgi.ddata(word'range);
        if is_rv64 then
          if r.dm.size = "011" then
            rfi_wdata12(0)         := dbgi.ddata(wordx'range);
          end if;
        end if;
      end if;
    end if;

    -- So far this is only used to handled special dependencies
    -- like MTOPI and MIE dependencies
    v.pwb0.csr  := r.wb.csr;
    v.pwb0.ctrl := r.wb.ctrl;

    v.pwb1.csr  := r.pwb0.csr;
    v.pwb1.ctrl := r.pwb0.ctrl;
    -----------------------------------------------------------------------
    -- EXCEPTION STAGE
    -----------------------------------------------------------------------

    -- Exception Flush ----------------------------------------------------
    x_flush     := wb_pipeflush or wb_branch;
    x_fpu_flush := '0';


    -- Generate Next Pc for Fence -----------------------------------------
    gen_next(r.x.ctrl(branch_lane).branch.naddr,  -- in  : Lane 1 Next PC
             r.x.ctrl(0).pc,                      -- in  : Lane 0 PC
             r.x.ctrl(0).comp,                    -- in  : Lane 0 Compressed
             x_nextpc                             -- out : Next Pc
             );

    -- Late ALUs Forwarding -----------------------------------------------
    for i in lanes'range loop
      if late_alu = 1 or late_branch = 1 then
        xc_alu_forwarding(r,                      -- in  : Registers Record
                          i,                      -- in  : Lane
                          x_alu_op1(i),           -- out : Late ALU op1
                          x_alu_op2(i)            -- out : Late ALU op2
                          );
      elsif csr_lane = i then
        xc_csr_forwarding(r,                      -- in  : Registers Record
                          i,                      -- in  : Lane
                          x_alu_op1(i)            -- out : CSR op1
                          );
        x_alu_op2(i) := zerox;
      else
        x_alu_op1(i) := zerox;
        x_alu_op2(i) := zerox;
      end if;
    end loop;

-- pragma translate_off
    -- for i in lanes'range loop
    --   if is_x(x_alu_op1(i)) then
    --     x_alu_op1(i) := (others => '0');
    --   end if;
    --   if is_x(x_alu_op2(i)) then
    --     x_alu_op2(i) := (others => '0');
    --   end if;
    -- end loop;
-- pragma translate_on

    -- Late ALUs -----------------------------------------------------------
    for i in lanes'range loop
      if late_alu = 1 then
        alu_execute(disable(active_extensions, x_zbc, x_zbkc),
                    x_alu_op1(i),                 -- in  : Op1
                    x_alu_op2(i),                 -- in  : Op2
                    r.x.alu(i).ctrl,              -- in  : Control Bits
                    x_alu_res(i)                  -- out : ALU Result
                    );
        x_alu_valid(i) := r.x.alu(i).valid and r.x.ctrl(i).valid;
      else
        x_alu_valid(i) := '0';
        x_alu_res(i)   := zerox;
      end if;
    end loop;

    -- CSR operation ------------------------------------------------------

    x_csr_val := r.x.csr.v;
    -- IMSIC CSRs have to be read and write the same cycle otherwise the
    -- read value could differ from the overwritten one.
    if imsic = 1 then
      case r.x.csr.imsic is
        when "001" => -- mireg
          x_csr_val := imsico.mireg;
        when "010" => -- sireg
          x_csr_val := imsico.sireg;
        when "011" => -- vsireg
          x_csr_val := imsico.vsireg;
        when "100" => -- mtopei
          x_csr_val := imsico.mtopei;
        when "101" => -- stopei
          x_csr_val := imsico.stopei;
        when "110" => -- vstopei
          x_csr_val := imsico.vstopei;
        when others =>
        end case;
    end if;


    x_csr_op1       := x_alu_op1(csr_lane);
    x_csr_special   := "00";  -- See below
    if ext_zicfiss = 1 and v_fusel_eq(r.x.ctrl(csr_lane).fusel, CFI) then
      -- This is for Zicfiss SSPUSH / SSPOPCHK
      x_csr_special := r.x.ctrl(csr_lane).inst(26 downto 25);
--      -- Do no allow SSP update if access failed!
--      if r.x.mexc = '1' then
--        x_csr_special := "01";
--      end if;
    end if;
    if csr_immediate(r, x) then
      x_csr_op1   := uext(r.x.ctrl(csr_lane).inst(19 downto 15), x_csr_op1);
    end if;
    x_wcsr := csralu_op(x_csr_op1,        -- in  : Op1
                        x_csr_val,        -- in  : Op2
                        r.x.csr.ctrl      -- in  : Control Signal
                        );

    -- Only for trace
    x_wb_wcsr               := (others => zerox);
    x_wb_wcsr(memory_lane)  := r.x.wcsr;           -- At this point, this is load/store address.

    if csr_ok(r, x) then


      -- The specification says that any actual read from MIP/SIP (not the rmw) must
      -- OR the incoming SEIP from the interrupt controller with MIP/SIP value.
      -- when bit 9 of mvien is one, mip.SEIP is simply the supervisor external interrupt signal from the hart’s
      -- external interrupt controller (APLIC or IMSIC).
      if funct12(r.x.ctrl(csr_lane).inst) = CSR_MIP or
         (funct12(r.x.ctrl(csr_lane).inst) = CSR_SIP and
          r.csr.mideleg(IRQ_S_EXTERNAL) /= '0') then
        x_csr_val(IRQ_S_EXTERNAL) :=
          (x_csr_val(IRQ_S_EXTERNAL) and not r.csr.mvien(IRQ_S_EXTERNAL)) or x_irq.seip;
      end if;
    end if;


    -- Write Back Data ----------------------------------------------------
    for i in lanes'range loop
      wbdata_gen(i,                             -- in  : Lane
                 r.x.ctrl(i).fusel,             -- in  : Functional Units
                 x_alu_valid(i),                -- in  : Late ALUs Valid Flag
                 r.x.alu(i).lalu,               -- in  : Late ALUs Enable Flag
                 r.x.result(i),                 -- in  : Result from ALUs
                 r.x.ctrl(i).csrv,              -- in  : CSR Valid Instruction
                 x_csr_val,                     -- in  : Result from CSR read
                 x_alu_res(i),                  -- in  : Result from late ALUs
                 r.x.rdata,                     -- in  : Data from LD
                 x_wb_data(i)                   -- out : Data to write back stage
                 );
    end loop;

    -- Ensure forwarding for CSR reads
    -- Note that the forwarding here does not expect to deal with
    -- swapping, so it is not allowed for the CSR read destination
    -- to be the same as for something that executes in the late ALU
    -- and that it has paired and swapped with!
    -- (That is handled by dual_issue_check().)
    if csr_ok(r, x) then
      -- SSPUSH / SSPOPCHK (Zicfiss) should not be treated as CSRs here.
      if ext_zicfiss = 0 or
         not (v_fusel_eq(r, x, csr_lane, CFI) and v_fusel_eq(r, x, csr_lane, LD or ST)) then
        x_alu_res(csr_lane) := x_csr_val;
        x_wb_wcsr(csr_lane) := x_wcsr;  -- Replace by CSR write data for trace
      end if;

    end if;

    -- Late Branch Unit ---------------------------------------------------
    if late_branch = 1 then
      branch_unit(active_extensions,
                  x_alu_op1(branch_lane),                 -- in  : Forwarded Op1
                  x_alu_op2(branch_lane),                 -- in  : Forwarded Op2
                  r.x.ctrl(branch_lane).valid,            -- in  : Instruction Valid Flag
                  r.x.ctrl(branch_lane).branch.valid,     -- in  : Branch Valid Flag
                  funct3(r.x.ctrl(branch_lane).inst),
                  r.x.ctrl(branch_lane).branch.addr,      -- in  : Branch Target Address
                  r.x.ctrl(branch_lane).branch.naddr,     -- in  : Branch Next Address
                  r.x.ctrl(branch_lane).branch.taken,     -- in  : Branch Prediction
                  r.x.ctrl(branch_lane).pc,               -- in  : PC of Branch Instruction
                  x_branch_valid,                         -- out : Branch Valid Flag
                  x_branch_mispredict,                    -- out : Branch Misprediction Flag
                  x_branch_addr,                          -- out : Branch Target Address
                  x_branch_xc,                            -- out : Branch Exception Flag
                  x_branch_cause,                         -- out : Branch Exception Cause
                  x_branch_tval                           -- out : Branch Exception Value
                  );
    else
      x_branch_valid      := '0';
      x_branch_mispredict := '0';
      x_branch_addr       := (others => '0');
      x_branch_xc         := '0';
      x_branch_cause      := cause_none;
      x_branch_tval       := zerox;
    end if;

    v.wb.unalg_pc := uadd(r.x.ctrl(branch_lane).pc, 2);

    -- Merge results
    if late_branch = 1 then
      if r.x.lbranch = '1' then
        x_wb_data(branch_lane) := x_alu_op1(branch_lane);
        x_wb_wcsr(branch_lane) := x_alu_op2(branch_lane);  -- Replace by branch destination for trace
      end if;
    end if;

    -- If late branch misspredict don't fire the trigger for the instruction
    -- executing after the branch even if it matches
    -- The same applies for the WFI instruction
    x_lbnull     := '0';
    if late_branch = 1 then
      if (x_branch_valid and x_branch_mispredict and r.x.lbranch) = '1' and
         r.x.swap = '1' then
        x_lbnull := '1';
      end if;
    end if;

    -- CSR Write Logic ----------------------------------------------------
    wb_csr_wen        := '0';
    if csr_ok(r, x) then
      wb_csr_wen      := r.x.csrw(csr_lane) and not (x_flush or r.x.trig.nullify(csr_lane));
    end if;
    -- Disable CSR write if at landing pad, which will fail.
    wb_csr_wen        := wb_csr_wen and not r.csr.elp;
    wb_csr_csra       := csr_addr(r, x);
    wb_csr_wdata      := x_wcsr;

    if dmen = 1 then
      if (r.dm.cmdexec(0) and r.dm.write and r.dm.cmd(0)) = '1' and r.x.rstate = dhalt then
        if r.dm.addr(15 downto 12) = "0000" then
          wb_csr_wen                             := '1';
        end if;
        wb_csr_csra                              := r.dm.addr(csratype'range);
        wb_csr_wdata(word'range)                 := dbgi.ddata(word'range);
        x_csr_special                            := "00";  -- See above
        if is_rv64 and r.dm.size = "011" then
          wb_csr_wdata(XLEN - 1 downto XLEN / 2) := dbgi.ddata(XLEN - 1 downto XLEN / 2);
        end if;
      end if;
    end if;

    -- To CSR Regfile -----------------------------------------------------
    csr_write(wb_csr_csra,                      -- in  : CSR Address
              r.x.rstate,                       -- in  : Core State
              r.csr,                            -- in  : CSR File
              x_csr_special,
              wb_csr_wdata,                     -- in  : Write Data
              wb_csr_wen,                       -- in  : Valid/Write Enable
              r.x.ctrl(csr_lane).pc,            -- in  : PC of CSR Instruction
              r.x.ctrl(csr_lane).xc,            -- in  : XC on CSR Instruction
              r.dm.csr_xc,                      -- in  : XC on CSR write from Debug Module
              r.x.int,                          -- in  : Interrupt pending on instruction
              r.x.csrpipeflush,                 -- in  : Precalculated pipeflush requirement
              r.x.csraddrflush,                 -- in  : Precalculated addrflush requirement
              x_csr_pipeflush,                  -- out : Flush Instructions
              x_csr_addrflush,                  -- out : Flush Instructions
              wb_upd_mcycle,                    -- out : CSR mcycle updated
              wb_upd_minstret,                  -- out : CSR minstret updated
              wb_upd_counter,                   -- out : CSR counter updated
              vimsici,                          -- out : imsic inputs
              wb_csr                            -- out : CSR Regfile
              );



    -- Exception Unit -----------------------------------------------------
    xc_popchk_forwarding(r, x_popchk_eq);
    exception_unit(r,                           -- in  : Registers
                   cfi_en,
                   x_popchk_eq,
                   r.x.lpad,
                   r.x.lpad_fail,
                   x_flush,                     -- in  : Flush from fence
                   r.x.swap,                    -- in  : Swapped Instructions
                   r.csr.v,                     -- in  : Executing in Virtualized Mode
                   r.x.dci.vms(2),              -- in  : Virtualized load/store
                   r.x.int,                     -- in  : Interrupt pending on instruction
                   r.x.ie_trig,                 -- in  : Interrupt/Exception trigger
                   r.x.trigxc,                  -- in  : Registered values from triggers
                   x_lbnull,                    -- in  : Late branch trigger nullify
                   x_xc,                        -- out : Exceptions
                   x_xc_cause,                  -- out : Exceptions Cause
                   x_xc_tval,                   -- out : Exceptions Value
                   x_xc_ret,                    -- out : Return Level
                   x_xc_nret,                   -- out : Return from an RNMI
                   x_xc_taken,                  -- out : Exception Taken
                   x_xc_lane_out,               -- out : Exception lane
                   x_xc_irq_taken,              -- out : IRQ taken lane
                   x_xc_nmirq_taken,            -- out : Resumable Non-maskable Interrupt taken
                   x_xc_taken_cause,            -- out : Exception Taken Cause
                   x_xc_taken_tval,             -- out : Exception Taken Value
                   x_xc_taken_tval2,            -- out : Exception Taken Value 2
                   x_xc_taken_gva,              -- out : Exception Taken GVA
                   x_xc_flush,                  -- out : Flush Instructions
                   x_xc_pc,                     -- out : Exception PC
                   x_xc_inst,                   -- out : Exception mtinst/htinst
                   wb_csr.elp,                  -- out : New ELP
                   x_ie_trig,                   -- out : Interrupt/Exception Triggers
                   x_ie_trig_taken,             -- out : Interrupt/Exception Trigger action taken
                   x_bt_xc_taken,               -- out : Exception taken (Before analyzing Triggers)
                   x_bt_xc_cause,               -- out : Exception cause (Before analyzing Triggers)
                   x_trigxc,                    -- out : Triggers precalculated exceptions
                   x_trig_flushall,             -- out : Flush instruction when trigger fires
                   x_ebreak_action0,            -- out : Ebreak due to Trigger with action=0
                   x_trig_taken,                -- out : Trigger action taken
                   x_clr_trig                   -- out : Clears ICOUNT and MCONTROL6 triggers
                   );



    x_trig := r.x.trig;
    if (x_clr_trig or x_lbnull) = '1' then
      x_trig.hit   := (others => '0');
      x_trig.valid := (others => '0');
    end if;



    -- Register Interrupts
    if not all_0(r.evtirq) then
      wb_csr.mip(IRQ_LCOF)     := '1';
    end if;
    wb_csr.mip(IRQ_M_EXTERNAL) := x_irq.meip;
    wb_csr.mip(IRQ_M_TIMER)    := x_irq.mtip;
    wb_csr.mip(IRQ_M_SOFTWARE) := x_irq.msip;

    -- Sstc extension support
    if ext_sstc = 1 and r.csr.menvcfg.stce = '1' then
      wb_csr.mip(IRQ_S_TIMER)     := sstc_stip;
    end if;

    wb_csr.mip(IRQ_M_EXTERNAL) := x_irq.meip;
    wb_csr.mip(IRQ_M_TIMER)      := x_irq.mtip;
    wb_csr.mip(IRQ_M_SOFTWARE)   := x_irq.msip;
    if x_irq.ssip = '1' then
      wb_csr.mip(IRQ_S_SOFTWARE) := '1';
    end if;
    if imsic = 1 then
      wb_csr.hgeip(GEILEN downto 1) := x_irq.hgeip;
    end if;

    if ext_smaia = 1 then
      -- Bit 5 of mvip is an alias of the same bit (STIP) in mip when
      -- that bit is writable in mip. When STIP is not writable in
      -- mip(such as when menvcfg.STCE = 1), bit 5 of mvip is read-only zero.
      if ext_sstc = 1 and r.csr.menvcfg.stce = '1' then
        wb_csr.mvip(IRQ_S_TIMER)     := '0';
      else
        wb_csr.mvip(IRQ_S_TIMER)     := wb_csr.mip(IRQ_S_TIMER);
      end if;
    end if;

    if ext_h /= 0 then
      wb_csr.mip(IRQ_SG_EXTERNAL) := to_bit(not all_0(wb_csr.hgeip and wb_csr.hgeie));
      wb_csr.mip(IRQ_VS_EXTERNAL) := wb_csr.hvip(IRQ_VS_EXTERNAL) or
                                                wb_csr.hgeip(u2i(wb_csr.hstatus.vgein))
                      ;
      wb_csr.mip(IRQ_VS_TIMER)    := wb_csr.hvip(IRQ_VS_TIMER)
                      -- Sstc extension support
                      or (to_bit(ext_sstc = 1) and
                          r.csr.menvcfg.stce and r.csr.henvcfg.stce and
                          sstc_vstip);
      -- When hypervisor extension is enabled, VS-level interrupt is always
      -- delegated to HS-mode
      if r.csr.misa(h_ctrl) = '1' then
        wb_csr.mideleg(IRQ_SG_EXTERNAL) := '1';
        wb_csr.mideleg(IRQ_VS_EXTERNAL) := '1';
        wb_csr.mideleg(IRQ_VS_TIMER)    := '1';
        wb_csr.mideleg(IRQ_VS_SOFTWARE) := '1';
      end if;
    end if;


    -- WFI and Power Down Mode ---------------------------------------------------
    -- WFI instrution is always issued alone in the lane 0.
    -- When WFI instruction reaches the exception stage, provided
    -- that there is not a interrupt, a trigger or an exception pending, and
    -- that there is not a halt request, the core will start entering in
    -- power down mode.
    -- All the instructions in the pipeline, except for the WFI instruction,
    -- are flushed. The cache is requested to enter parked mode and the pipeline
    -- is flushed until the cache is parked.
    -- Once the cache is parked, the clock is gated and disabled for the pipeline.
    -- When a interrupt becomes pending or the halt signal is set, the clock
    -- is ungated and the core gets out of the power down mode loading
    -- the PC of the WFI instruction + 4.
    -- If an interrupt becomes pending the same cycle that the WFI instruction
    -- reaches the exception stage, the interrupt is ignored and will be risen
    -- the next valid instruction.
    -- When step is set to 1 or during the execution of the program buffer, WFI
    -- instructions are ignored, and have the same effect as executing a NOP.
    -- Interrupts do not have to be globally enabled to wake up the core
    if PWRDEN then
      -- Supervisor external interrupt do not modify the writable bit in SIP or MIP
      -- Therefore, we need to check the bit from external interrupt controller
      -- separately.
      wfi_irqpend      := not all_0(wb_csr.mip and r.csr.mie) or
                              (x_irq.seip and r.csr.mie(IRQ_S_EXTERNAL)) or not all_0(x_irq.nmirq);
      -- Wait for interrupt will behave differently if AIA is implemented.
      -- Accodring to the specs interrupt is pending in any mode when one of mtopi/stopi/vstopi are
      -- different than 0.
      -- The AIA’s rule for WFI gives the same behavior as the Privileged Architecture’s rule when
      -- mvien= 0 and, if the hypervisor extension is implemented, also hvien = 0 and hvictl.VTI = 0.
      -- mvien, hvien and hvictl.VTI are used to inject interrupts by software. Therefore, when the
      -- processor is stopped waiting for an interrupt it is impossible to inject an interrupt.
      -- As a result we should only wait for sources of interrupts that modify mip/sip/vsip CSRs
      -- externally. We have to take into account mtopi/stopi/vstopi to skip a wfi instruction if
      -- they are already different than 0 when executing wfi.
      if ext_smaia /= 0 then
        wfi_irqpend      := wfi_irqpend or not all_0(r.csr.mtopi or r.csr.stopi or r.csr.vstopi);
      elsif ext_ssaia /= 0 then
        wfi_irqpend      := wfi_irqpend or not all_0(r.csr.stopi or r.csr.vstopi);
      end if;
      -- wfi_irqpend is registered to improve timing. wfi_flushall depends on it and at the same time
      -- it depends on wb_csr.mip that depends on the interrupts coming from IMSIC which are not
      -- registered to improve interrupt latency. To wake up the CPU we cannot use registered wfi_irpend
      -- because in powerdown mode clock is stopped.
      v.x.wfi_irqpend := wfi_irqpend;

      -- If it is wfi instruction enter low power mode
      -- and wait for interrupts to wake up
      wfi_flushall     := '0';
      wfi_parkreq      := '0';
      if (r.x.is_wfi = '1' and r.x.ctrl(0).valid = '1') and r.x.wfi_irqpend = '0' and
         x_flush = '0' and r.x.ctrl(0).xc = '0' and r.x.trig.hit(0) = '0' and
         (dmen = 0 or (r.x.rstate /= dexec and r.csr.dcsr.step = '0' and dbgi.halt = '0')) then
        wfi_flushall   := '1';
        v.x.wfimode    := '1';
        v.x.wfi_pc     := uadd(r.x.ctrl(0).pc, 4);
      elsif r.x.wfimode = '1' then
        wfi_flushall   := '1';
        wfi_parkreq    := '1';
        if (wfi_irqpend or dbgi.halt) = '1' and holdn = '1' then -- wake up
          v.x.wfimode  := '0';
          v.x.pwrdmode := '0';
        elsif ico.parked = '1' then
          v.x.pwrdmode := '1';
        end if;
      end if;

      -- Input to the clock gating module
      pwrdmode     := r.x.pwrdmode and not (wfi_irqpend or dbgi.halt);
    else
      pwrdmode     := '0';
      wfi_flushall := '0';
      wfi_parkreq  := '0';
    end if;


    -- To Write Back Stage ------------------------------------------------
    v.wb.trap_taken(0)       := '1';
    if single_issue = 0 then
      v.wb.trap_taken(one)   := '0';
      if x_xc_lane_out = '1' then
        v.wb.trap_taken(0)   := '0';
        v.wb.trap_taken(one) := '1';
      end if;
    end if;

    for i in lanes'range loop
      v.wb.ctrl(i).pc      := r.x.ctrl(i).pc;
      v.wb.ctrl(i).inst    := r.x.ctrl(i).inst;
      v.wb.ctrl(i).cinst   := r.x.ctrl(i).cinst;
      v.wb.ctrl(i).valid   := r.x.ctrl(i).valid and not (x_xc_flush(i) or x_flush);
      v.wb.ctrl(i).actual  := r.x.ctrl(i).actual;
      v.wb.ctrl(i).flushed := r.x.ctrl(i).flushed or x_xc_flush(i) or x_flush;
      v.wb.ctrl(i).comp    := r.x.ctrl(i).comp;
      v.wb.ctrl(i).branch  := r.x.ctrl(i).branch;
      v.wb.ctrl(i).rdv     := r.x.ctrl(i).rdv;
      v.wb.ctrl(i).csrv    := r.x.ctrl(i).csrv and r.x.csrw(i);
      v.wb.ctrl(i).csrdo   := r.x.ctrl(i).csrdo;
      v.wb.ctrl(i).xc      := x_xc(i) and r.x.ctrl(i).valid and not x_flush;
      v.wb.ctrl(i).cause   := x_xc_cause(i);
      v.wb.ctrl(i).tval    := x_xc_tval(i);
      v.wb.ctrl(i).fusel   := r.x.ctrl(i).fusel;
      v.wb.wcsr(i)         := x_wb_wcsr(i);        -- Data to the CSR file etc for trace
      v.wb.wdata(i)        := x_wb_data(i);        -- Data to the register file
      v.wb.lalu(i)         := r.x.alu(i).lalu;
    end loop;
    v.wb.ctrl(fpu_lane).fpu       := r.x.ctrl(fpu_lane).fpu;
    v.wb.ctrl(fpu_lane).fpu_flush := r.x.ctrl(fpu_lane).fpu_flush;
    v.wb.fpuflags                 := r.x.fpuflags;


    v.wb.ctrl(branch_lane).branch.mpred         := '0';
    -- r.wb.ctrl(branch_lane).branch.naddr is not used by anything
    -- use that for misprediction address
    v.wb.ctrl(branch_lane).branch.naddr         := r.x.ctrl(branch_lane).branch.naddr;

    -- Generate Branch Signal ---------------------------------------------
    if late_branch = 1 then
      if (x_branch_valid and x_branch_mispredict) = '1' and
         x_flush   = '0' and r.x.lbranch    = '1'       and
         x_xc_irq_taken = "00" then
        v.wb.ctrl(branch_lane).branch.mpred   := '1';
        v.wb.ctrl(branch_lane).branch.taken   := not r.x.ctrl(branch_lane).branch.taken;
        if r.x.ctrl(branch_lane).branch.taken = '0' then
          v.wb.ctrl(branch_lane).branch.naddr := r.x.ctrl(branch_lane).branch.addr;
        end if;
        -- If branch was really first instruction, invalidate second.
        if r.x.swap = '1' and single_issue = 0 then
          v.wb.ctrl(0).valid                  := '0';
          if fpu_lane = 0 then
            x_fpu_flush                       := '1';
          end if;
        end if;
      end if;
    end if;

    dci_specreadannulv   := '0';
    if r.x.spec_ld = '1' and wb_branch = '1' then
      dci_specreadannulv := '1';
    end if;


    v.wb.flushall       := x_bt_xc_taken or wb_pipeflush;
    v.wb.csr_pipeflush  := x_csr_pipeflush;
    v.wb.csr_addrflush  := x_csr_addrflush;
    v.wb.csr            := r.x.csr;
    v.wb.swap           := r.x.swap;
    v.wb.rstate         := r.x.rstate;
    v.wb.xc_taken_tval  := x_xc_taken_tval;
    v.wb.nextpc0        := x_nextpc;
    v.wb.rasi           := r.x.rasi;
    v.wb.prv            := r.csr.prv;
    v.wb.v              := r.csr.v;
    v.wb.fence_flush    := fence_flush_check(r);
    v.wb.ret            := not all_0(x_xc_ret);


    -- Exception Registers Update -----------------------------------------
    exception_flow(x_xc_pc,                     -- in  : Exception PC
                   x_xc_nmirq_taken,            -- in  : Resumable Non-maskable Interrupt taken
                   x_xc_taken,                  -- inout : Exception
                   x_xc_taken_cause,            -- inout : Exception Cause
                   r.x.aia_vti,                 -- in  : Virtual interrupt generated through hvictl when vti=1
                   x_xc_taken_tval,             -- in  : Exception Trap Value I
                   x_xc_taken_tval2,            -- in  : Exception Trap Value 2
                   x_xc_inst,                   -- in  : Exception instruction
                   x_xc_taken_gva,              -- in  : Exception GVA Value
                   x_xc_ret,                    -- in  : Return Level
                   x_xc_nret,                   -- in  : Return from an RNMI
                   wb_csr,                      -- in  : CSR Regfile
                   r.csr,                       -- in  : Registered CSR Regfile
                   r.x.rstate,                  -- in  : Core State
                   x_ebreak_action0,            -- in  : Ebreak exception due to trigger action 0
                   x_xc_crit_err,               -- out : Signals a critical error
                   wb_csr_trig,                 -- out : CSR Regfile
                   x_xc_tvec                    -- out : Trap Vector Base
                   );

  -- Cause could be updated to double trap in exception flow
  v.wb.xc_taken_cause := x_xc_taken_cause;
  -- Interrupt can be cancelled in exception flow if we need to enter
  -- critical error mode
  v.wb.xc_taken       := x_xc_taken;

    trigger_update(
      csr_in     => wb_csr_trig,
      r_csr      => r.csr,
      ic_tdata1  => r.csr.tcsr.tdata1(TRIGGER_MC_NUM),
      ic_tdata3  => r.csr.tcsr.tdata3(TRIGGER_MC_NUM),
      v_wb_ctrl  => v.wb.ctrl,
      trig_in    => x_trig,
      ie_trig_in => r.x.ie_trig,
      trig_flushall => x_trig_flushall,

      csr_out   => v.csr);


    -- Debug Module -------------------------------------------------------
    x_dret    := '0';
    x_csr_dpc := v.csr.dpc;
    x_csr_dcsr:= v.csr.dcsr;
    x_csr_prv := v.csr.prv;
    x_csr_v   := v.csr.v;
    x_csr_elp := v.csr.elp;

    debug_module(r,                        -- in  : Registers
                 x_csr_dpc,                -- in  : DPC CSR Register
                 x_csr_dcsr,               -- in  : DCSR CSR Register
                 x_csr_prv,                -- in  : Privilege mode
                 x_csr_v,                  -- in  : Virtualization mode
                 x_csr_elp,                -- in  : Expected landing pad
                 dmen,                     -- in  : Debug Module Enable
                 dbgi,                     -- in  : Debug Module
                 r.dm,                     -- in  : Debug Module register
                 x_xc,                     -- in  : Exceptions
                 x_bt_xc_taken,            -- in  : Exception Taken (before triggers)
                 x_bt_xc_cause,            -- in  : Exception Cause (before triggers)
                 x_dret,                   -- in  : dret Instruction
                 x_trig,                   -- in  : Trigger trap on instruction
                 r.x.ie_trig,              -- in  : Interrupt/Exception Triggers
                 x_ie_trig_taken,          -- in  : Interrupt/Exception Trigger action taken
                 x_ebreak_action0,         -- in  : Ebreak exception due to trigger with action=0
                 x_xc_crit_err,            -- in  : Sinals a critical error
                 rfo.data1,                -- in  : Register File Read Port 1
                 r.e.csr.v,                -- in  : CSR File Read Register
                 tbo.data,                 -- in  : Trace buffer readout data
                 itraceo.tcnt,             -- in  : Trace buffer current index
                 v.wb.trace_trig,          -- out : Prevents the intructions that fire a trigger from being invalidating in the trace
                 dbg_running,              -- out : Running Signal
                 dbg_halted,               -- out : Halted Signal
                 dbg_pc,                   -- out : PC from DM request
                 dbg_request,              -- out : DM request to PC
                 v.x.rstate,               -- out : Next DM State
                 v.csr.prv,                -- out : Privilege mode out
                 v.csr.v,                  -- out : Virtualization mode
                 v.csr.elp,                -- out : Expected landing pad
                 v.csr.dpc,                -- out : DPC CSR Register
                 v.csr.dcsr,               -- out : DCSR CSR Register
                 v.dm,                     -- out : Debug Module register
                 dbg_crit_err,             -- out : Set system to critical-error state
                 dbg_flushall,             -- out : DM Flushall Signal
                 dbg_dvalid,               -- out : DM Valid Signal
                 dbg_ddata,                -- out : DM Data Signal
                 dbg_derr,                 -- out : DM Error Signal
                 dbg_dexec_done,           -- out : DM Program buffer exec done
                 dbg_haltreq,              -- out : Halt request from DM
                 dbg_stoptime              -- out : stop mtime
                 );


    -- If the hart enters in critical-error state (Smdbltrp extension)
    -- we should set the critical error bit
    if dbg_crit_err = '1' then
      v.x.crit_err := '1';

      if r.csr.dcsr.cetrig = '0' and dmen = 1 and dbgi.dsuen = '1' then
        -- If cetrig is not active do not enter in debug mode
        dbg_running := '1';
        dbg_halted  := '0';
      end if;
    end if;

    if (dbg_flushall or x_trig_flushall) = '1'  then
      v.wb.flushall := '1';
    end if;


    v.wb.bht_bhistory := bhto.bhistory;
    v.wb.bht_phistory := bhto.phistory;

    if r.csr.dfeaturesen.staticbp = '1' then
      v.wb.bht_bhistory := (others => '0');
      v.wb.bht_phistory := (others => '0');
    end if;

    -----------------------------------------------------------------------
    -- MEMORY STAGE
    -----------------------------------------------------------------------

    for i in lanes'range loop
      m_inst(i)  := r.m.ctrl(i).inst;
      m_valid(i) := r.m.ctrl(i).valid;
      m_fusel(i) := r.m.ctrl(i).fusel;
    end loop;

    -- Memory Flush -------------------------------------------------------
    me_flush     := '0';
    -- This is x_flush or x_bt_xc_taken or dbg_flushall or x_trig_flushall.
    if (v.wb.flushall or wb_branch or wfi_flushall) = '1' then
      me_flush   := '1';
    end if;
    me_fpu_flush := '0';

    -- Branch Misprediction from Execute Stage ---------------------------
    mem_branch           := '0';
    mem_branch_target    := r.m.ctrl(branch_lane).branch.naddr;
    mem_branch_flush     := '0';
    if r.m.ctrl(branch_lane).branch.taken = '1' then
      mem_branch_target  := r.m.ctrl(branch_lane).branch.addr;
    end if;
    if r.m.ctrl(branch_lane).branch.mpred = '1' and
       r.m.ctrl(branch_lane).valid = '1' then
      mem_branch         := '1';
      if r.m.swap = '1' then
        mem_branch_flush := '1';
      end if;
    end if;

    -- From Mul Unit ------------------------------------------------------
    mul_res(mulo,                       -- in  : Mul Unit Output
            divo,                       -- in  : Div Unit Output
            fpuo,                       -- in  : FPU Unit Output
            m_inst,                     -- in  : Instructions
            m_valid,                    -- in  : Valids
            m_fusel,                    -- in  : Functional Units
            r.m.result,                 -- in  : Results from Memory Stage
            me_result                   -- out : Results to the Exception Stage
            );

    -- Data Cache Signals -------------------------------------------------
    stdata_unit(r,                      -- in  : Registers
                me_stdata               -- out : Data to Store
                );

    -- Insert Exception ---------------------------------------------------
    me_exceptions(r.m.ctrl,             -- in  : Instruction Ctrl
                  me_ret,               -- out : Return Privileged Level
                  me_nret,              -- out : Return from an RNMI
                  me_xc,                -- out : Memory Stage Exception
                  me_xc_cause,          -- out : Memory Stage Cause
                  me_xc_tval            -- out : Memory Stage Value
                  );

    -- Generate Nullify for Data Cache ------------------------------------
    null_dcache_gen(me_flush,           -- in  : Flush all from Exception Stage
                    me_xc,              -- in  : Instruction Exceptions
                    mem_branch_flush,   -- in  : Branch mispredict from memory stage
                    m_valid,            -- in  : Instruction Valids
                    r.m.swap,           -- in  : Instructions Swapped
                    me_nullify          -- out : Data Cache Nullify
                    );


    -- Mask CSR Write -----------------------------------------------------
    me_csrw             := (others => '0');
    if r.m.ctrl(csr_lane).csrv = '1' and not csr_read_only(r, m) then
      me_csrw(csr_lane) := '1';
    end if;


    -- Interrupt pending --------------------------------------------------
    -- Mask interrupts during step (when stepie = 0).
    -- There can not be an instruction in memory stage when CSR write is in
    -- exception stage hence no corner case with interrupt config bits

    -- Register Interrupts

    -- An interrupt i will be taken if bit i is set in both mip and mie,
    -- and if interrupts are globally enabled. By default, M-mode interrupts are globally
    -- enabled if the hart’s current privilege mode is less than M, or if the current privilege
    -- mode is M and the MIE bit in the mstatus register is set. If bit i in mideleg is set,
    -- however, interrupts are considered to be globally enabled if the hart’s
    -- current privilege mode equals the delegated privilege mode (S or U) and that mode’s interrupt
    -- enable bit (SIE or UIE in mstatus) is set, or if the current privilege mode is less than
    -- the delegated privilege mode.

    -- Multiple simultaneous interrupts destined for different privilege modes are handled
    -- in decreasing order of destined privilege mode. Multiple simultaneous interrupts
    -- destined for the same privilege mode are handled in the following decreasing priority
    -- order: MEI, MSI, MTI, SEI, SSI, STI, UEI, USI, UTI. Synchronous exceptions are of
    -- lower priority than all interrupts.
    me_h_en := r.csr.misa(h_ctrl) = '1';
    me_int  := '0';

    -- It is assumed here that the priority lists are 8 elements long.
    -- Formality complains if the indexing can go outside the array.
    assert me_irqprio_m'length = 8 report "me_irqprio_m'length /= 8" severity failure;
    assert me_irqprio_s'length = 8 report "me_irqprio_s'length /= 8" severity failure;
    assert me_irqprio_v'length = 8 report "me_irqprio_v'length /= 8" severity failure;

    -- Highest priority at lowest index
    me_irqand_m                            := r.csr.mip and r.csr.mie;
    -- Supervisor external interrupt needs to be OR:ed in separately.
    -- when bit 9 of mvien is one, mip.SEIP is simply the supervisor external interrupt signal from the hart’s
    -- external interrupt controller (APLIC or IMSIC).
    me_irqand_m(IRQ_S_EXTERNAL) := (me_irqand_m(IRQ_S_EXTERNAL) and not r.csr.mvien(IRQ_S_EXTERNAL)) or
                                              (x_irq.seip and r.csr.mie(IRQ_S_EXTERNAL));
    me_irqand_m                 := me_irqand_m and not (r.csr.mideleg or r.csr.mvien);
    -- Note that the indices here must match cause_prio_m!
    -- Looping inconveniant due to ext_ dependencies.
    me_irqprio_m      := (others => '0');
    me_irqprio_m(0)   := me_irqand_m(IRQ_M_EXTERNAL);
    me_irqprio_m(1)   := me_irqand_m(IRQ_M_SOFTWARE);
    me_irqprio_m(2)   := me_irqand_m(IRQ_M_TIMER);
    me_irqprio_m(3)   := me_irqand_m(IRQ_S_EXTERNAL);
    me_irqprio_m(4)   := me_irqand_m(IRQ_S_SOFTWARE);
    me_irqprio_m(5)   := me_irqand_m(IRQ_S_TIMER);
    -- The specification requires that SGE/VSE/VSS/VST are
    -- always delegated past M to HS.
    if ext_sscofpmf /= 0 then
      me_irqprio_m(6) := me_irqand_m(IRQ_LCOF);
    end if;

    lz_cnt        := clz(reverse(me_irqprio_m));
    me_irqcause_m := cause_prio_m(u2i(lz_cnt(2 downto 0)));

    -- The value of mtopi is zero unless there is an interrupt pending in mip/miph
    -- and enabled in mie/mieh that is not delegated to a lower privilege level
    v.csr.mtopi      := (others => '0');
    if ext_smaia = 1 and not all_0(me_irqand_m) then
      -- Since machine IPRIO array is read-only zero for all its elements
      -- IPRIO[7:0] field is always 1
      v.csr.mtopi( 7 downto  0) := u2vec(1, 8);
      v.csr.mtopi(27 downto 16) := u2vec(me_irqcause_m.code, 12);
    end if;

    me_irqand_s                            := r.csr.mip and r.csr.mie;
    -- mip.mie register contains the software writable bit which does not
    -- depend on the external interrupt controller and according to the specs:
    -- SEIP is read-only in sip, and is set and cleared by the execution
    -- environment, typically through a platform-specific interrupt controller.
    -- Therefore, we need here the bit from the external interrupt controller
    me_irqand_s(IRQ_S_EXTERNAL) := ((x_irq.seip or r.csr.mip(IRQ_S_EXTERNAL)) and r.csr.mie(IRQ_S_EXTERNAL));
    me_irqand_s                 := me_irqand_s and r.csr.mideleg and not (r.csr.hideleg or r.csr.hvien);
    -- If mvien[n]=1 then sip[n] is an alias of mvip[n]
    if ext_smaia = 1 then
      for i in 0 to XLEN-1 loop
        if r.csr.mvien(i) = '1' and r.csr.mideleg(i) = '0' then
          me_irqand_s(i) := r.csr.mvip(i) and r.csr.sie(i) and
                            mvien_mask(ext_sscofpmf, ext_smcdeleg)(i);
        end if;
      end loop;
    end if;
    -- Note that the indices here must match cause_prio_s!
    -- Looping inconveniant due to ext_ dependencies.
    me_irqprio_s      := (others => '0');
    me_irqprio_s(0)   := me_irqand_s(IRQ_S_EXTERNAL);
    me_irqprio_s(1)   := me_irqand_s(IRQ_S_SOFTWARE);
    me_irqprio_s(2)   := me_irqand_s(IRQ_S_TIMER);
    if ext_h /= 0 then
      me_irqprio_s(3) := me_irqand_s(IRQ_SG_EXTERNAL);
      me_irqprio_s(4) := me_irqand_s(IRQ_VS_EXTERNAL);
      me_irqprio_s(5) := me_irqand_s(IRQ_VS_SOFTWARE);
      me_irqprio_s(6) := me_irqand_s(IRQ_VS_TIMER);
    end if;
    if ext_sscofpmf /= 0 then
      me_irqprio_s(7) := me_irqand_s(IRQ_LCOF);
    end if;

    lz_cnt        := clz(reverse(me_irqprio_s));
    me_irqcause_s := cause_prio_s(u2i(lz_cnt(2 downto 0)));

    -- The value of stopi is zero unless: (a) there is an interrupt that is both pending in sip/siph and
    -- enabled in sie/sieh, or, if the hypervisor extension is implemented, both pending in hip and
    -- enabled in hie; and (b) the interrupt is not delegated to a lower privilege level (by hideleg, if the
    -- hypervisor extension is implemented)
    v.csr.stopi      := (others => '0');
    if (ext_smaia = 1 or ext_ssaia = 1) and not all_0(me_irqand_s) then
      -- Since supervisor IPRIO array is read-only zero for all its elements
      -- IPRIO[7:0] field is always 1
      v.csr.stopi( 7 downto  0) := u2vec(1, 8);
      v.csr.stopi(27 downto 16) := u2vec(me_irqcause_s.code, 12);
    end if;

    me_irqand_v        := r.csr.mip and r.csr.mie;
    me_irqand_v           := me_irqand_v and r.csr.mideleg and (r.csr.hideleg or r.csr.hvien);
    -- Note that the indices here must match cause_prio_v!
    -- Looping inconveniant due to ext_ dependencies.
    me_irqprio_v      := (others => '0');
    -- interrupts from index 13, if hvien[n]=1 then vsip[n] is an alias of hvip[n]
    if ext_smaia = 1 then
      for i in 13 to XLEN-1 loop
        if r.csr.hvien(i) = '1' and r.csr.hideleg(i) = '0' then
          me_irqand_v(i) := r.csr.hvip(i) and r.csr.vsie(i) and
                            hvien_mask(ext_sscofpmf, ext_smcdeleg)(i);
        end if;
      end loop;
    end if;

    me_irqprio_v(0)   := me_irqand_v(IRQ_VS_EXTERNAL);
    me_irqprio_v(1)   := me_irqand_v(IRQ_VS_SOFTWARE);
    me_irqprio_v(2)   := me_irqand_v(IRQ_VS_TIMER);
    me_irqprio_v(3)   := me_irqand_v(IRQ_LCOF);

    lz_cnt        := clz(reverse(me_irqprio_v));
    me_irqcause_v := cause_prio_v(u2i(lz_cnt(2 downto 0)));

    -- If Smaia or Ssaia extension is implemented Virtual Supervisor interrupts are
    -- computed in a different way:
    -- The interrupt with highest priority should be taken from different 5 candidates.
    -- The candidates are mutually exclusive of one another in groups of 3 and 2 leaving
    -- two "finalists". The one with highest priority will be the cause of the interrupt
    v.csr.vstopi    := (others => '0');
    me_int_v        := '0';
    pending_int_v   := '0';
    iprio_v         := (others => '0');
    icause_v        := cause_res;
    if ext_smaia = 1 or ext_ssaia = 1 then
      iprio1_v      := (others => '0');
      icause1_v     := cause_res;
      if me_irqand_v(IRQ_VS_EXTERNAL) = '1' then
        if u2i(r.csr.hstatus.vgein) = 0 and
           r.csr.hvictl.iid = IRQ_S_EXTERNAL and u2i(r.csr.hvictl.iprio) /= 0 then
          -- Supervisor external interrupt with priority number hvictl.IPRIO
          iprio1_v  := uext(unsigned(r.csr.hvictl.iprio), iprio1_v);
          icause1_v := CAUSE_IRQ_S_EXTERNAL;
        elsif u2i(r.csr.hstatus.vgein) /= 0 and u2i(r.csr.hstatus.vgein) <= GEILEN and
              not all_0(imsico.vstopei) then  -- Only 26:16 and 10:0 relevant. u2i() cannot handle > 32 bits
            -- Supervisor external interrupt with the priority number indicated by vstopei
            iprio1_v  := unsigned(imsico.vstopei(10 downto 0));
            icause1_v := CAUSE_IRQ_S_EXTERNAL;
        else
          -- Supervisor external interrupt with priority number 256
          iprio1_v  := u2vec(256, iprio1_v);
          icause1_v := CAUSE_IRQ_S_EXTERNAL;
        end if;
      end if;

      iprio2_v      := (others => '0');
      icause2_v     := cause_res;
      dpr           := false;
      if r.csr.hvictl.vti = '0' then
        -- All pending-and-enabled major interrupts indicated by vsip/vsiph and vsie/vsieh
        -- other than a supervisor external interrupt, with priority numbers assigned
        -- by hviprio1/hviprio1h and hviprio2/hviprio2h;
        icause2_v   := me_irqcause_v;
        if icause2_v = CAUSE_IRQ_VS_SOFTWARE then
          icause2_v := CAUSE_IRQ_S_SOFTWARE;
        elsif icause2_v = CAUSE_IRQ_VS_TIMER then
          icause2_v := CAUSE_IRQ_S_TIMER;
        elsif icause2_v = CAUSE_IRQ_VS_EXTERNAL then
          icause2_v := cause_res;
        end if;
        -- IPRIO Virtual Supervisor array values are all hardwired to 0
        -- Then it has default priority, which for Software and Timer
        -- interrupts is lower than external interrupt.
        -- Set priority to the maximum possible and in case of a tie
        -- external interrupt will win.
        iprio2_v    := (others => '1');
      elsif r.csr.hvictl.iid /= IRQ_S_EXTERNAL then
        -- The major interrupt specified by hvictl fields IID, DPR and IPRIO
        icause2_v   := to_cause(r.csr.hvictl.iid, true);
        iprio2_v    := uext(unsigned(r.csr.hvictl.iprio), iprio2_v);
        -- Set dpr to true to check later if there is a tie if hvictl.dpr is set
        dpr         := true;
        -- When iprio is 0, the priority depends on the default priority (dpr).
        -- If the default priority is higher than a SEI then we set iprio to 0.
        -- If the default priority is lower we set iprio to 2048 so there is no
        -- higher iprio value from an external interrupt. In case of a tie the
        -- dpr field will always make the correct prioritization.
        if all_0(iprio2_v) then
          if r.csr.hvictl.dpr = '1' then
            iprio2_v := (others => '1');
          end if;
        end if;
      end if;

      -- Determine which one has the highest priority
      if icause1_v.code /= 0 and icause2_v.code /= 0 then
        if iprio2_v > iprio1_v then
          iprio_v    := iprio1_v;
          icause_v   := icause1_v;
        elsif iprio1_v = iprio2_v then
          -- Ties in the priority are broken comparing the default priority order.
          -- Note that icause1_v is always IRQ_S_EXTERNAL here, so check against that explicitly.
          iprio_v  := iprio2_v;  -- Assumption
          icause_v := icause2_v;
          if dpr then
            if r.csr.hvictl.dpr = '1' then
              iprio_v  := iprio1_v;
              icause_v := icause1_v;
            end if;
          elsif int_cause2prio(icause2_v.code) > int_cause2prio(IRQ_S_EXTERNAL) then
            iprio_v  := iprio1_v;
            icause_v := icause1_v;
          end if;
        else
          iprio_v    := iprio2_v;
          icause_v   := icause2_v;
        end if;
      elsif icause1_v.code /= 0 then
        iprio_v      := iprio1_v;
        icause_v     := icause1_v;
      elsif icause2_v.code /= 0 then
        iprio_v      := iprio2_v;
        icause_v     := icause2_v;
      end if;

      if icause_v.code /= 0 then
        -- Priority is compressed to 8 bits following the rules
        -- found in the AIA specs
        if r.csr.hvictl.ipriom = '0' then
          iprio_v    := u2vec(1, iprio_v);
        elsif iprio_v > 255 then
          iprio_v    := u2vec(255, iprio_v);
        end if;

        pending_int_v := '1';
        v.csr.vstopi( 7 downto  0) := std_logic_vector(iprio_v(7 downto 0));
        v.csr.vstopi(27 downto 16) := u2vec(icause_v.code, 12);
      end if;
    end if;

    me_aia_vti  := '0';
    me_irqcause := cause_res;
    if all_0(me_irqand_m or me_irqand_s or me_irqand_v) and pending_int_v = '0' then
      -- No enabled interrupt present.
    elsif r.csr.dcsr.step = '1' and r.csr.dcsr.stepie /= '1' then
      -- Stepping, but not into interrupts.
    elsif r.csr.prv = PRIV_LVL_M and r.csr.mstatus.mie /= '1' then
      -- M mode without interrupts enabled.
      -- Note that M mode interrupts are always enabled in non-M modes.
    elsif not all_0(me_irqand_m) then
      -- Some active M IRQ pending
      me_int        := '1';
      me_irqcause   := me_irqcause_m;
    elsif r.csr.prv = PRIV_LVL_M then
      -- M mode with no active M IRQ pending.
    elsif r.csr.prv = PRIV_LVL_U or r.csr.v = '1' or r.csr.mstatus.sie = '1' then
      -- U/VU mode, VS mode, or S mode with interrupts enabled.
      -- Note that S mode interrupts are always enabled in U mode, and HS in VS/VU.
      if not all_0(me_irqand_s) then
        -- No hypervisor, or IRQ not delegated to VS mode, so handle in (H)S mode.
        me_int      := '1';
        me_irqcause := me_irqcause_s;
      elsif r.csr.v = '0' then
        -- Not in VS mode to deal with IRQ.
      elsif r.csr.prv = PRIV_LVL_U or r.csr.vsstatus.sie = '1' then
        -- U mode, or VS mode with interrupts enabled.
        -- Note that VS mode interrupts are always enabled in U mode.
        me_int      := '1';
        me_irqcause := me_irqcause_v;
        if pending_int_v = '1' then
          me_aia_vti := '1';
          me_int_v   := '1';
        end if;
      end if;
    end if;

    if me_int = '1' then
      -- If the interrupt has been delegated to virtual Supervisor mode
      -- and extension Smaia or Ssaia are enabled, the cause may be different
      if me_int_v = '1' then
        -- With only SW/TIMER/EXT interrupts, adding 1 would be enough here.
        -- But prepare to make future updates work without changes.
        if    icause_v.code = IRQ_S_SOFTWARE then me_irqcause := CAUSE_IRQ_VS_SOFTWARE;
        elsif icause_v.code = IRQ_S_TIMER    then me_irqcause := CAUSE_IRQ_VS_TIMER;
        elsif icause_v.code = IRQ_S_EXTERNAL then me_irqcause := CAUSE_IRQ_VS_EXTERNAL;
        else                                      me_irqcause := icause_v;
        end if;
      end if;
    end if;

    -- Resumable Non-maskable Interrupts
    v.x.nmirqpend := '0';
    if ext_smrnmi = 1 then
      if r.csr.mnstatus.nmie = '1' then
        if not all_0(x_irq.nmirq) then
          assert not is_x(x_irq.nmirq) report "Acting on X in NMIRQ vector " & tost(x_irq.nmirq) 
          severity failure;
          -- Causes to be defined
          me_irqcause := u2cause(unsigned(x_irq.nmirq), '1');
          me_int := '1';
          v.x.nmirqpend := '1';
        end if;
      else
        -- If nmie is set to 0 all interrupts are masked
        me_int := '0';
        me_irqcause := cause_res;
      end if;
    end if;

    v.x.irqcause   := me_irqcause;
    v.x.aia_vti    := me_aia_vti;


    -- Debug Module -------------------------------------------------------
    trigger_module (
      r           => r,
      csr_file    => r.csr,
      trig_in     => r.m.trig,
      ie_trig_in  => r.x.ie_trig,
      conthit_in  => r.e.conthit,
      tcsr        => r.csr.tcsr,
      prv         => r.csr.prv,
      v_mode      => r.csr.v,
      step        => r.csr.dcsr.step,
      haltreq     => dbg_haltreq and not (r.e.is_wfi and r.e.ctrl(0).valid),
      x_rstate    => r.x.rstate,
      clr_pen     => x_trig_taken or dbg_flushall,
      x_ctrl      => r.x.ctrl,
      m_swap      => r.m.swap,
      m_ctrl      => r.m.ctrl,
      e_swap      => r.e.swap,
      e_ctrl      => r.e.ctrl,
      avalid      => r.m.dci.enaddr
                     and not r.csr.elp
                     and not r.m.wpnull,
      addr        => r.m.address,
      size        => r.m.dci.size,
      awrite      => r.m.dci.write,
      aread       => r.m.dci.read,
      wdata       => me_stdata,
      conthit_out => v.e.conthit,
      m_trig      => v.m.trig,
      clr_ie_trig => me_clr_ie_trig,
      ie_trig_hit => me_ie_trig_hit,
      trigxc_out  => x_trigxc_out,
      mc6nullify  => me_mc6nullify,
      mc6bypass   => me_mc6bypass,
      me_bypass_trig => me_bypass_trig);


    -- We should clear ie_trig.pending when entering in debug mode
    if me_clr_ie_trig = '1' or r.x.rstate = dhalt then
      v.x.ie_trig := ie_trig_none;
    else
      v.x.ie_trig := x_ie_trig;
      if me_ie_trig_hit = '1' then
        v.x.ie_trig.hit := x_ie_trig.pend_hit;
      end if;
    end if;

    v.x.trigxc  := x_trigxc_out;


    -- To Exception Stage ------------------------------------------------
    for i in lanes'range loop
      v.x.ctrl(i).pc      := r.m.ctrl(i).pc;
      v.x.ctrl(i).inst    := r.m.ctrl(i).inst;
      v.x.ctrl(i).cinst   := r.m.ctrl(i).cinst;
      v.x.ctrl(i).valid   := r.m.ctrl(i).valid and not me_flush;
      v.x.ctrl(i).actual  := r.m.ctrl(i).actual;
      v.x.ctrl(i).flushed := r.m.ctrl(i).flushed or me_flush;
      v.x.ctrl(i).rdv     := r.m.ctrl(i).rdv;
      v.x.ctrl(i).comp    := r.m.ctrl(i).comp;
      v.x.ctrl(i).branch  := r.m.ctrl(i).branch;
      v.x.ctrl(i).csrv    := r.m.ctrl(i).csrv;
      v.x.ctrl(i).csrdo   := r.m.ctrl(i).csrdo;
      v.x.ctrl(i).xc      := me_xc(i);
      v.x.ctrl(i).cause   := me_xc_cause(i);
      v.x.ctrl(i).tval    := me_xc_tval(i);
      v.x.ctrl(i).fusel   := r.m.ctrl(i).fusel;
      v.x.rfa1(i)         := r.m.rfa1(i);
      v.x.rfa2(i)         := r.m.rfa2(i);
      v.x.result(i)       := me_result(i)(wordx'range);
      if me_mc6bypass = '0' then
        v.x.trig.valid(i)   := r.m.trig.valid(i) and not me_flush;
        v.x.trig.nullify(i) := r.m.trig.nullify(i) and not me_flush;
        if TRIGGER_NUM /= 0 then
          v.x.trig.hit(i)   := r.m.trig.hit(i) and not me_flush;
        end if;
      else
        v.x.trig.valid(i)   := me_bypass_trig.valid(i) and not me_flush;
        v.x.trig.nullify(i) := me_bypass_trig.nullify(i) and not me_flush;
        if TRIGGER_NUM /= 0 then
          v.x.trig.hit(i)   := me_bypass_trig.hit(i) and not me_flush;
        end if;
      end if;
      -- Previous code guarantees that there is no CSR write to registers
      -- affecting IRQ either paired with or in the cycle just before
      -- another instruction.
      -- But we must still ensure that no interrupt is taken on a CSR write,
      -- since some things rely on the CSR write always completing.
      -- For example, interrupts could be turned off without the instruction
      -- seemingly executing, causing a rerun after xRET and dropping IRQ enable.
      v.x.int(i)          := r.m.ctrl(i).valid and me_int and not me_flush;
    end loop;
    v.x.ctrl(fpu_lane).fpu       := r.m.ctrl(fpu_lane).fpu;
    v.x.ctrl(fpu_lane).fpu_flush := r.m.ctrl(fpu_lane).fpu_flush;
    v.x.csr               := r.m.csr;
    v.x.swap              := r.m.swap;
    v.x.dci               := r.m.dci;
    v.x.address           := r.m.address;
    v.x.address_full      := r.m.address_full;
    v.x.lbranch           := r.m.lbranch;
    v.x.alu               := r.m.alu;
    v.x.rasi              := r.m.rasi;
    v.x.lpad              := r.m.lpad;
    v.x.lpad_fail         := r.m.lpad_fail;
    v.x.spec_ld           := r.m.spec_ld;
    v.x.csrw              := me_csrw;
    v.x.nret              := me_nret;
    v.x.ret               := me_ret;
    if not all_0(v.x.int) then      -- No xRET if IRQ.
      v.x.ret             := (others => '0');
    end if;
    v.x.fpuflags          := r.m.fpuflags;
    if me_mc6bypass = '0' then
      v.x.trig.hit          := r.m.trig.hit;
      v.x.trig.action       := r.m.trig.action;
      v.x.trig.priority     := r.m.trig.priority;
      v.x.trig.pending      := r.m.trig.pending and not x_trig_taken;
      v.x.trig.lanepri      := r.m.trig.lanepri;
    else
      v.x.trig.hit          := me_bypass_trig.hit;
      v.x.trig.action       := me_bypass_trig.action;
      v.x.trig.priority     := me_bypass_trig.priority;
      v.x.trig.pending      := me_bypass_trig.pending and not x_trig_taken;
      v.x.trig.lanepri      := me_bypass_trig.lanepri;
    end if;
    v.x.is_wfi              := r.m.is_wfi;

    -- FLI.S/D/H
    fpu_ctrl      := r.m.ctrl(fpu_lane);
    if ext_zfa = 1 and funct5(fpu_ctrl.inst) = R_FMV_W_X and
       rs2(fpu_ctrl.inst) = "00001" and funct3(fpu_ctrl.inst) = "000" then
      v.x.fpu_imm := imm_create(active_extensions,
                                fpu_ctrl.inst(19 downto 15), fpu_ctrl.inst(26 downto 25));
    end if;

    -- From Data Cache ----------------------------------------------------
    if v_fusel_eq(r, m, memory_lane, LD) or not dco.mds = '1' then
      for i in 0 to dways - 1 loop
        x_rdata(i) := no_x(dco.data(i));
      end loop;
      v.x.way       := dco.way(DWAYMSB downto 0);
      if dco.mds = '0' then
        me_size     := r.x.dci.size;
        me_laddr    := r.x.address(2 downto 0);
        me_signed   := r.x.dci.signed;
      else
        me_size     := v.x.dci.size;
        me_laddr    := v.x.address(2 downto 0);
        me_signed   := v.x.dci.signed;
      end if;
      me_ld_data    := ld_align_fast(x_rdata,         -- in  : Data in from the cache
                                     v.x.way,         -- in  : Way signals from the cache
                                     me_size,         -- in  : Size for the load data
                                     me_laddr,        -- in  : Low bits for the address
                                     me_signed);      -- in  : Signed or unsigned load
      v.x.rdata     := me_ld_data;
    end if;
    v.x.wdata       := me_stdata;
    v.x.mexc        := dco.mexc;
    v.x.exctype     := dco.exctype;
    v.x.exchyper    := dco.exchyper;
    v.x.tval2       := dco.addrhyper(XLEN - 1 downto 0);
    -- If virtual address is same as guest physical, use it directly.
    if ext_h /= 0 and r.x.dci.vms(2) = '1' and not has_pt(riscv_mmu, r.csr.vsatp) then
      v.x.tval2     := "00" & get_hi(r.x.address_full, -2);
    end if;
    v.x.tval2type   := dco.typehyper;

    --BTB FLUSH---
    mode_flush     := '0';
    if r.csr.prv /= v.csr.prv then
      if r.csr.prv = PRIV_LVL_M or v.csr.prv = PRIV_LVL_M then
        mode_flush := '1';
      end if;
    end if;
    if ext_h /= 0 then
      if r.csr.v /= v.csr.v then
        mode_flush := '1';
      end if;
    end if;

    -- Do not flush BTB when entering or leaving Debug Mode
    if r.x.rstate /= v.x.rstate then
      mode_flush := '0';
    end if;

    btbi.flush <= (wb_btbi.flush or mode_flush or r.csr.dfeaturesen.btb_dis or not icache_en) and holdn;

    -- To Data Cache ------------------------------------------------------
    dci <= nv_dcache_in_none;   -- Just in case
    dci.maddress <= fit0ext(r.m.address, dci.maddress'length);
    dci.enaddr          <= r.m.dci.enaddr;
    dci.size            <= r.m.dci.size;
    dci.nullify         <= me_nullify or r.m.trig.nullify(memory_lane) or me_mc6nullify or me_int;
    dci.lock            <= r.m.dci.lock;
    dci.asi             <= r.m.dci.asi;
    dci.read            <= r.m.dci.read
                           and not r.csr.elp  -- Memmory access must not happen at bad landing point
                           ;
    dci.write           <= r.m.dci.write
                           and not r.csr.elp  -- Memmory access must not happen at bad landing point
                           ;
    dci.dsuen           <= r.m.dci.dsuen;
    dci.msu             <= v.csr.prv(0) or v.csr.prv(1);    -- prv for dcache
    dci.edata           <= me_stdata;
    -- Add guard for writing undefined data to the cache
    if notx(rstn) and rstn = '1' and holdn = '1' then
      assert notx(me_stdata) report "X in data going to cache " & tost(me_stdata) severity failure;
    end if;
    dci.specread        <= v.x.spec_ld;
    dci.specreadannul   <= dci_specreadannulv;

    -----------------------------------------------------------------------
    -- EXECUTE STAGE
    -----------------------------------------------------------------------

    -- Execute Flush ------------------------------------------------------
    ex_flush   := '0';
    if (me_flush or mem_branch) = '1' then   -- Or branch mispredict from EX?
      ex_flush := '1';
    end if;

    -- Branch Flush -------------------------------------------------------
    ex_branch_flush   := '0';
    -- Same as me_flush except for no dependence on mispredict from XC.
    if v.wb.flushall = '1' then
      ex_branch_flush := '1';
    end if;


    -- Forwarding Lanes ---------------------------------------------------
    for i in lanes'range loop
      ex_alu_forwarding(r,                 -- in  : Registers
                        i,                 -- in  : Lane
                        r.e.aluforw(i),    -- in  : Forwarded from previous stages
                        ex_alu_op1(i),     -- out : ALU op1 input
                        ex_alu_op2(i)      -- out : ALU op2 input
                        );

-- pragma translate_off
      if is_x(ex_alu_op1(i)) then
        ex_alu_op1(i) := (others => '0');
      end if;
      if is_x(ex_alu_op2(i)) then
        ex_alu_op2(i) := (others => '0');
      end if;
-- pragma translate_on
    end loop;

    -- Branch Unit --------------------------------------------------------
    branch_unit(active_extensions,
                ex_alu_op1(branch_lane),                  -- in  : Forwarded Op1
                ex_alu_op2(branch_lane),                  -- in  : Forwarded Op2
                r.e.ctrl(branch_lane).valid,              -- in  : Enable/Valid Signal
                r.e.ctrl(branch_lane).branch.valid,       -- in  : Branch Valid Signal
                funct3(r.e.ctrl(branch_lane).inst),       -- in  : Inst funct3
                r.e.ctrl(branch_lane).branch.addr,        -- in  : Branch Target Address
                r.e.ctrl(branch_lane).branch.naddr,       -- in  : Branch Next Address
                r.e.ctrl(branch_lane).branch.taken,       -- in  : Prediction
                r.e.ctrl(branch_lane).pc,                 -- in  : PC
                ex_branch_valid,                          -- out : Branch Valid
                ex_branch_mis,                            -- out : Branch Outcome
                ex_branch_addr,                           -- out : Branch Address
                ex_branch_xc,                             -- out : Branch Exception
                ex_branch_cause,                          -- out : Exception Cause
                ex_branch_tval                            -- out : Exception Value
                );

    -- Jump Forwarding ----------------------------------------------------
    ex_jump_forwarding(r,                  -- in  : Registers
                       branch_lane,        -- in  : Lane
                       ex_jump_op1         -- out : Op1 as output
                       );

    -- Jump Unit ----------------------------------------------------------
    jump_unit(active_extensions,
              r.e.ctrl(branch_lane).fusel, -- in  : Functional Unit
              r.e.ctrl(branch_lane).valid, -- in  : Valid Instruction
              r.e.jimm,                    -- in  : Imm
              r.e.raso,                    -- in  : RAS
              ex_jump_op1,                 -- in  : Forwarded data
              ex_branch_flush,             -- in  : Flush
              ex_jump,                     -- out : Jump Signal
              mem_jump,                    -- out : Delayed Jump Signal
              ex_jump_xc,                  -- out : Jump Exception
              ex_jump_cause,               -- out : Exception Cause
              ex_jump_tval,                -- out : Exception Value
              ex_jump_addr                 -- out : Target Address
              );

    -- ALUs --------------------------------------------------------------
    for i in lanes'range loop
      alu_execute(cond(i = 0, active_extensions, disable(active_extensions, x_zbc, x_zbkc)),
                  ex_alu_op1(i),           -- in  : Op1
                  ex_alu_op2(i),           -- in  : Op2
                  r.e.alu(i).ctrl,         -- in  : Control Signal
                  ex_alu_res(i)            -- out : ALU Result
                  );
      ex_alu_valid(i) := r.e.alu(i).valid and not r.e.alu(i).lalu;
    end loop;

    ex_lpad      := '0';
    ex_lpad_fail := '0';
    if ext_zicfilp = 1 and r.x.rstate = run and cfi_en.lp and r.csr.elp = '1' then
      -- Since LPAD is forced to run alone, it will always be in lane 0, but a
      -- bad landing could end up in a swapped position.
      -- Landing pad error cannot override instruction fetch fault.
      if r.e.swap = '1' then
        ex_lpad        := '1';
        ex_lpad_fail   := '1';
      else
        -- Valid instruction, or actual non-flushed instruction with fault?
        if (r.e.ctrl(0).xc = '0' and r.e.ctrl(0).valid = '1') or
           (r.e.ctrl(0).xc = '1' and r.e.ctrl(0).actual = '1' and r.e.ctrl(0).flushed = '0' and
            not (r.e.ctrl(0).cause = XC_INST_ACCESS_FAULT    or
                 r.e.ctrl(0).cause = XC_INST_INST_PAGE_FAULT or
                 r.e.ctrl(0).cause = XC_INST_INST_G_PAGE_FAULT)) then
          ex_lpad      := '1';
          ex_lpad_fail := lpad_fail(cfi_en, r.e.ctrl(0).pc, ex_alu_op1(0), ex_alu_op2(0), r.e.ctrl(0).inst);
        end if;
      end if;
      -- Only the first instruction after r.csr.elp is set is actually allowed
      -- to cause a landing pad fault. The flag might not have had time to clear if
      -- that instruction is still on the way to the exception stage.
      -- Both still valid instructions and those that would have been valid except for faults count.
      for i in lanes'range loop
        if (r.m.ctrl(i).valid = '1' and r.m.ctrl(i).xc = '0') or
           (r.m.ctrl(i).xc = '1' and r.m.ctrl(i).actual = '1' and r.m.ctrl(i).flushed = '0') or
           (r.x.ctrl(i).valid = '1' and r.x.ctrl(i).xc = '0') or
           (r.x.ctrl(i).xc = '1' and r.x.ctrl(i).actual = '1' and r.x.ctrl(i).flushed = '0') then
          ex_lpad        := '0';
          ex_lpad_fail   := '0';
        end if;
      end loop;
    end if;

    -- Forwarding Store Data ----------------------------------------------
    ex_stdata_forwarding(r,                -- in  : Registers
                         ex_stdata         -- out : Forwarded Data
                         );

    -- Mul Unit -----------------------------------------------------------
    mul_gen(r.e.ctrl(0).inst,              -- in  : Instruction Lane 0
            r.e.ctrl(one).inst,            -- in  : Instruction Lane 1
            r.e.ctrl(0).fusel,             -- in  : Functional Unit Lane 0
            r.e.ctrl(one).fusel,           -- in  : Functional Unit Lane 1
            r.e.ctrl(0).valid,             -- in  : Valid Lane 0
            r.e.ctrl(one).valid,           -- in  : Valid Lane 1
            ex_alu_op1(0),                 -- in  : Execute Operand Lane 0
            ex_alu_op2(0),                 -- in  : Execute Operand Lane 0
            ex_alu_op1(one),               -- in  : Execute Operand Lane 1
            ex_alu_op2(one),               -- in  : Execute Operand Lane 1
            divo.nready,                   -- in  : Div Unit Ready Signal
            ex_hold_pc_muldiv,             -- out : Hold PC due to Mul/Div Unit
            ex_mul_valid,                  -- out : Mul Unit Valid
            ex_mul_op,                     -- out : Mul/Div Operation
            ex_mul_ctrl,                   -- out : Mul Unit Control
            ex_mul_op1,                    -- out : Mul Unit Operand 1
            ex_mul_op2                     -- out : Mul Unit Operand 2
            );


    addr_gen(active_extensions,
             r.e.ctrl(memory_lane).inst,   -- in  : Instruction
             r.e.ctrl(memory_lane).fusel,  -- in  : Functional Unit
             r.e.ctrl(memory_lane).valid,  -- in  : Valid Instruction
             ex_alu_op1(memory_lane),      -- in  : Op1 for Address Generation
             ex_alu_op2(memory_lane),      -- in  : Op2 for Address Generation
             r.csr.ssp,                    -- in  : Shadow Stack Pointer
             ex_dci_eaddress,              -- out : Data Address
             ex_address_xc,                -- out : Misalignment Exception
             ex_address_cause,             -- out : Exception Cause
             ex_address_tval               -- out : Exception Value
             );

    -- Check for misaligned FPU load/store
    ex_fpu_flush := '0';
    if is_fpu_mem(r.e.ctrl(memory_lane).inst) and ex_address_xc = '1' then
      ex_fpu_flush := '1';
    end if;

    fpu_holdn := fpuoa.holdn;
    -- The IU is responsible for holding when it is
    -- waiting for integer results from the FPU.
    -- Are we waiting on results?
    if r.e.fpu_wait = '1' then
      -- FPU operation in EX flushed (normal reasons)?
      if ex_flush = '1' then
      -- FPU operation in EX flushed (misaligned FPU load/store)?
      elsif ex_fpu_flush = '1' then
      -- This is really me_fpu_flush "moved up" here, for now.
      -- FPU operation in EX flushed (paired with swapped early mispredict)?
      elsif (ex_branch_valid and ex_branch_mis) = '1'   and
            ex_branch_flush = '0' and r.e.lbranch = '0' and
            r.e.swap = '1' and fpu_lane = 0 then
      -- FPU operation finished?
      elsif fpuoa.now2int = '1' and fpuoa.id2int = r.e.ctrl(FPU_LANE).fpu then
      else
        -- Keep holding
        if fpu_holdn = '1' then
          fpu_holdn := '0';
        end if;
      end if;
    end if;

    fpu_gen(r.e.ctrl(fpu_lane).inst,       -- in  : Instruction
            r.e.ctrl(fpu_lane).valid,      -- in  : Valid
            fpu_holdn,                     -- in  : FPU Ready Signal
            ex_hold_pc_muldiv,             -- in  : Hold PC due to Mul/Div Unit
            ex_hold_pc                     -- out : Hold PC due to FPU
            );

    -- Insert Exception ---------------------------------------------------
    for i in lanes'range loop
      ex_xc(i)                   := r.e.ctrl(i).xc;
      ex_xc_cause(i)             := r.e.ctrl(i).cause;
      ex_xc_tval(i)              := r.e.ctrl(i).tval;
    end loop;
    if r.e.ctrl(memory_lane).xc = '0' then
      if ex_address_xc = '1' then
        ex_xc(memory_lane)       := '1';
        ex_xc_cause(memory_lane) := check_cause_update(ex_address_cause, ex_xc_cause(memory_lane));
        ex_xc_tval(memory_lane)  := ex_address_tval;
      end if;
    end if;
    if r.e.ctrl(branch_lane).xc = '0' then
      if ex_branch_xc = '1' then
        ex_xc(branch_lane)       := '1';
        ex_xc_cause(branch_lane) := check_cause_update(ex_branch_cause, ex_xc_cause(branch_lane));
        ex_xc_tval(branch_lane)  := ex_branch_tval;
      elsif ex_jump_xc = '1' then
        ex_xc(branch_lane)       := '1';
        ex_xc_cause(branch_lane) := check_cause_update(ex_jump_cause, ex_xc_cause(branch_lane));
        ex_xc_tval(branch_lane)  := ex_jump_tval;
      end if;
    end if;

    -- ALUs Results -------------------------------------------------------
    ex_result_fwd                := ex_alu_valid;
    ex_result                    := ex_alu_res;
    -- Merge result for JAL and JALR instructions.
    if v_fusel_eq(r, e, branch_lane, FLOW) then
      ex_result(branch_lane)     := pc2xlen(r.e.ctrl(branch_lane).branch.naddr);
      ex_result_fwd(branch_lane) := '1';
    end if;

    v.m.fpuflags               := (others => '0');
    if ext_f = 1 and r.e.ctrl(fpu_lane).valid = '1' and
       is_fpu(r.e.ctrl(fpu_lane).inst) then
      ex_result(fpu_lane)        := fpuoa.data2int(wordx'range);
      ex_result_fwd(fpu_lane)    := '1';
      -- Ensure that FPU flags in IU pipeline are only set for FPU->IU operations.
      if not is_fpu_rd(r.e.ctrl(fpu_lane).inst) then
        v.m.fpuflags             := fpuoa.flags2int;
      end if;
    end if;


    -- To Memory Stage ----------------------------------------------------
    for i in lanes'range loop
      v.m.ctrl(i).pc      := r.e.ctrl(i).pc;
      v.m.ctrl(i).inst    := r.e.ctrl(i).inst;
      v.m.ctrl(i).cinst   := r.e.ctrl(i).cinst;
      v.m.ctrl(i).valid   := r.e.ctrl(i).valid and not ex_flush;
      v.m.ctrl(i).actual  := r.e.ctrl(i).actual;
      v.m.ctrl(i).flushed := r.e.ctrl(i).flushed or ex_flush;
      v.m.ctrl(i).rdv     := r.e.ctrl(i).rdv;
      v.m.ctrl(i).comp    := r.e.ctrl(i).comp;
      v.m.ctrl(i).branch  := r.e.ctrl(i).branch;
      v.m.ctrl(i).csrv    := r.e.ctrl(i).csrv;
      v.m.ctrl(i).csrdo   := r.e.ctrl(i).csrdo;
      v.m.ctrl(i).xc      := ex_xc(i);
      v.m.ctrl(i).cause   := ex_xc_cause(i);
      v.m.ctrl(i).tval    := ex_xc_tval(i);
      v.m.ctrl(i).fusel   := r.e.ctrl(i).fusel;
      v.m.ctrl(i).mexc    := r.e.ctrl(i).mexc;
      v.m.rfa1(i)         := r.e.rfa1(i);
      v.m.rfa2(i)         := r.e.rfa2(i);
      v.m.result(i)       := ex_result(i);
      v.m.trig.valid(i)   := v.m.trig.valid(i) and not ex_flush;
      v.m.trig.nullify(i) := v.m.trig.nullify(i) and not ex_flush;
      if TRIGGER_NUM /= 0 then
        v.m.trig.hit(i)   := v.m.trig.hit(i) and not ex_flush;
      end if;
    end loop;
    v.m.ctrl(fpu_lane).fpu       := r.e.ctrl(fpu_lane).fpu;
    v.m.ctrl(fpu_lane).fpu_flush := '0';
    v.m.csr               := r.e.csr;
    v.m.swap              := r.e.swap;
    v.m.stdata            := ex_stdata;
    v.m.stforw            := r.e.stforw;
    v.m.lbranch           := r.e.lbranch;
    v.m.fpdata            := fpuoa.data2int;
    v.m.rasi              := r.e.rasi;
    v.m.lpad              := ex_lpad;
    v.m.lpad_fail         := ex_lpad_fail;
    v.m.spec_ld           := r.e.spec_ld;
    v.m.is_wfi            := r.e.is_wfi;

    -- Branch Signals -----------------------------------------------------
    ex_branch                            := '0';
    ex_branch_target                     := ex_branch_addr;
    v.m.ctrl(branch_lane).branch.mpred   := '0';
    if (ex_branch_valid and ex_branch_mis) = '1' and ex_branch_flush = '0' and r.e.lbranch = '0' then
      v.m.ctrl(branch_lane).branch.mpred := '1';
      v.m.ctrl(branch_lane).branch.taken := not r.e.ctrl(branch_lane).branch.taken;
      if r.e.swap = '1' and single_issue = 0 then
        v.m.ctrl(0).valid := '0';
      end if;
    end if;

    -- Late ALUs Signals --------------------------------------------------
    -- Do not update if a bubble was inserted after EX last cycle!
    if r.e.was_held = '0' then
      v.m.alu          := r.e.alu;
      for i in lanes'range loop
        v.m.alu(i).op1 := ex_alu_op1(i);
        v.m.alu(i).op2 := ex_alu_op2(i);
      end loop;
    end if;

    -- Store JALR Address -------------------------------------------------
    if v_fusel_eq(r, e, branch_lane, JALR) then
      v.m.ctrl(branch_lane).branch.addr := ex_jump_addr;
    end if;

    -- If NMIE equals 0 the hart behaves as if mstatus.MPRV was zero
    ex_mprv := r.csr.mstatus.mprv;
    if ext_smrnmi = 1 then
      if r.csr.mnstatus.nmie = '0' then
        ex_mprv := '0';
      end if;
    end if;

    -- Store Data ---------------------------------------------------------
    dcache_gen(r.e.ctrl(memory_lane).inst,   -- in  : Instruction
               r.e.ctrl(memory_lane).fusel,  -- in  : Functional Unit
               v.m.ctrl(memory_lane).valid,  -- in  : Valid Instruction
               ex_address_xc,                -- in  : Address misaligned?
               r.csr.dfeaturesen,            -- in  : ASI information
               r.csr.prv,                    -- in  : Privilege level
               r.csr.v,                      -- in  : Virtualization mode
               ex_mprv,                      -- in  :
               r.csr.mstatus.mpv,            -- in  :
               r.csr.mstatus.mpp,            -- in  :
               r.csr.mstatus.mxr,            -- in  :
               r.csr.mstatus.sum,            -- in  :
               r.csr.hstatus.spvp,           -- in  :
               r.csr.vsstatus.mxr,           -- in  :
               r.csr.vsstatus.sum,           -- in  :
               v.m.wpnull,                   -- out : Prevents mcontrol6 trigger from matching
               ex_dci                        -- out : Data Cache Signals
               );


    -- Invalid Second Instruction -----------------------------------------
    if v.m.ctrl(branch_lane).branch.mpred = '1' and r.e.swap = '1' then
      v.m.ctrl(0).valid := '0';
      if fpu_lane = 0 then
        me_fpu_flush    := '1';
      end if;
      -- Data cache will be flushed on the next cycle so we don't need to
      -- propagate the valid signal to DC in this stage.
    end if;

    -- Merge branch and mispredicted jumps.
    -- Jump target address is latched on the taken adress.
    -- It should be noted that mispredicted jump is always single issued
    -- and the upcoming slot is always empty so no need for invalidation or
    -- cache flush.
    if mem_jump = '1' then
      v.m.ctrl(branch_lane).branch.mpred := '1';
      v.m.ctrl(branch_lane).branch.taken := '1';
    end if;

    -- Data Cache Signals -------------------------------------------------
    v.m.dci     := ex_dci;
    v.m.address := to_addr(ex_dci_eaddress);
    v.m.address_full := ex_dci_eaddress;

    -- To the Data Cache --------------------------------------------------
    -- Note that most of these are directly dependent on v.m.dci, and thus on ex_dci and on to
    -- r.e.ctrl(mem).inst/fusel
    -- v.m.ctrl(mem).valid, ie r.e.*.valid and not ex_flush or mispredicted early branch (in shadow)
    -- ex_address_xc
    -- ex_mprv
    -- r.csr.dfeaturesen/prv/v/mstatus/hstatus/vsstatus
    dci.easi    <= v.m.dci.asi;
    -- FPU store will hold EX until data is available, but we must also
    -- block the cache access from starting until this is ready.
    dci.eenaddr <= v.m.dci.enaddr and not ex_hold_pc;
    dci.eread   <= v.m.dci.read;
    dci.amo     <= v.m.dci.amo;
    dci.cbo     <= v.m.dci.cbo;
    dci.vms     <= v.m.dci.vms;
    dci.sum     <= v.m.dci.sum;
    dci.mxr     <= v.m.dci.mxr;
    dci.vmxr    <= v.m.dci.vmxr;
    dci.hx      <= v.m.dci.hx;
    dci.ss      <= v.m.dci.ss;
    dci.bar     <= r.e.bar;
    dci.eaddress <= fit0ext(v.m.address, dci.eaddress'length);

    for i in 0 to TRIGGER_MC_NUM - 1 loop
      v.m.trig.lowhit(i) := trigger_mcontrol6_addr_low(tdata1  => r.csr.tcsr.tdata1(i),
                                                       tdata2  => r.csr.tcsr.tdata2(i),
                                                       addr    => v.m.address,
                                                       size    => ex_dci.size,
                                                       inst    => r.e.ctrl(memory_lane).inst,
                                                       lowbits => MCONTROL6_LOWBITS);
    end loop;



    -----------------------------------------------------------------------
    -- REGFILE STAGE
    -----------------------------------------------------------------------

    -- We assume that:
    --                  lane 0 ALU, CSR, MUL/DIV, LD/ST
    --                  lane 1 ALU, MUL/DIV, FLOW, BRANCH

    -- Generate Register Access Flush Signal ------------------------------
    ra_flush   := '0';
    if (ex_flush or ex_jump) = '1' then   -- Or JALR in EX?
      ra_flush := '1';
    end if;

    -- From the Register File ---------------------------------------------
    ra_data12(0)   := rfo.data1;
    ra_data34(0)   := rfo.data3;
    if single_issue = 0 then
      ra_data12(one) := rfo.data2;
      ra_data34(one) := rfo.data4;
    end if;

    -- From the CSR File --------------------------------------------------
    ra_csrv        := '0';
    ra_csrw        := to_bit(not csr_read_only(r, a));
    ra_csrr        := to_bit(not csr_write_only(r, a));
    -- if csr_ok(r, a) and not csr_write_only(r, a) then
    if csr_ok(r, a) then
      ra_csrv      := '1';
    end if;
    ra_csr_address := csr_addr(r, a);

    if dmen = 1 then
      if (r.dm.cmdexec(1) and r.dm.cmd(0)) = '1' and
         r.x.rstate = dhalt then
        ra_csr_address := r.dm.addr(11 downto 0);
        ra_csrw        := r.dm.write;
        ra_csrr        := not(r.dm.write);
        ra_csrv        := '1';
      end if;
    end if;

    -- "Forwarding" of flags from float->integer operations
    -- This is safe to do since if the operations in question are
    -- later flushed, so is the CSR read.
    iu_fflags := (others => '0');
    if v.m.ctrl(fpu_lane).valid = '1' then
      iu_fflags := iu_fflags or v.m.fpuflags;
    end if;
    if r.m.ctrl(fpu_lane).valid = '1' then
      iu_fflags := iu_fflags or r.m.fpuflags;
    end if;
    if r.x.ctrl(fpu_lane).valid = '1' then
      iu_fflags := iu_fflags or r.x.fpuflags;
    end if;
    if r.wb.ctrl(fpu_lane).valid = '1' then
      iu_fflags := iu_fflags or r.wb.fpuflags;
    end if;

    -- Since flags from the FPU might show up at the same instant as a
    -- CSR flag read is allowed through, make sure to take those into account.
    if fpuo.flags_wen = '1' then
      iu_fflags := iu_fflags or fpuo.flags;
    end if;

    -- Initalize
    ra_csr       := zerox;
    ra_csr_imsic := "000";
    ra_csr_xc    := '0';
    -- Only valid if ra_csr_read_xc is set.
    ra_csr_cause := XC_INST_ILLEGAL_INST;
    -- Valid CSR operation
    if ra_csrv = '1' then
      -- Calculate exception
      csr_xc := csr_xc_check(ra_csr_address,
                             ra_csrw = '1',
                             active_extensions,
                             r.csr,
                             r.x.rstate,
                             imsic /= 0,
                             pmp_entries,
                             perf_cnts,
                             trigger
                            );
      if csr_xc = XC_ILLEGAL then
        ra_csr_cause := XC_INST_ILLEGAL_INST;
      else
        ra_csr_cause := XC_INST_VIRTUAL_INST;
      end if;
      ra_csr_xc := to_bit(csr_xc.xc);

      -- Read CSR if exception didn't occur
      if ra_csrr = '1' and csr_xc = XC_NONE then
        csr_read(
                r.csr,                     -- in  : CSR File
                ra_csr_address,            -- in  : CSR Register Address
                iu_fflags,                 -- in  : FPU flags in IU transit
                mmu_csr,                   -- in  : Status form Cache controller
                s_time,                    -- in  : Shadow MTIME for S-mode
                s_vtime,                   -- in  : Shadow MTIME for vitalized mode
                ra_csr_imsic,              -- out : IMSIC CSR read
                ra_csr                     -- out : CSR Register Value
                );
      end if;
    end if;

    -- IMSIC CSRs are read in the X stage to avoid losing interrupts information
    -- For those reason when IMSIC registers are read from the debugger, IMSIC
    -- registers have to be read along with the other CSRs.
    if dmen = 1 then
      if (r.dm.cmdexec(1) and not r.dm.write and r.dm.cmd(0)) = '1' and
         r.x.rstate = dhalt then
        if imsic = 1 then
          case ra_csr_imsic is
            when "001" => -- mireg
              ra_csr := imsico.mireg;
            when "010" => -- sireg
              ra_csr := imsico.sireg;
            when "011" => -- vsireg
              ra_csr := imsico.vsireg;
            when "100" => -- mtopei
              ra_csr := imsico.mtopei;
            when "101" => -- stopei
              ra_csr := imsico.stopei;
            when "110" => -- vstopei
              ra_csr := imsico.vstopei;
            when others =>
            end case;
        end if;
      end if;
    end if;

    -- Insert Exception ---------------------------------------------------
    for i in lanes'range loop
      ra_xc(i)               := r.a.ctrl(i).xc;
      ra_xc_cause(i)         := r.a.ctrl(i).cause;
      ra_xc_tval(i)          := r.a.ctrl(i).tval;
    end loop;
    if r.a.ctrl(csr_lane).xc = '0' and ra_csr_xc = '1' then
      ra_xc(csr_lane)        := '1';
      ra_xc_cause(csr_lane)  := check_cause_update(ra_csr_cause, ra_xc_cause(csr_lane));
      ra_xc_tval(csr_lane)   := to0x(r.a.ctrl(csr_lane).inst);
      if illegalTval0 = 1 then
        ra_xc_tval(csr_lane) := zerox;
      end if;
    end if;
    v.dm.csr_xc              := ra_csr_xc;

    -- ALUs ---------------------------------------------------------------
    for i in lanes'range loop
      alu_gen(active_extensions,
              r.a.ctrl(i).inst,
              ra_alu_ctrl(i)              -- ALU Control Signal
              );
      ra_alu_valid(i) := r.a.ctrl(i).valid and to_bit(v_fusel_eq(r.a.ctrl(i).fusel, ALU));
      a_alu_forwarding(r,                 -- in  : Registers
                       i,                 -- in  : Lane
                       v.m.result,        -- in  : Data from ALU L0/L1 (C)
                       ex_result_fwd(0) and r.e.ctrl(0).valid and r.e.ctrl(0).rdv,
                       ex_result_fwd(one) and r.e.ctrl(one).valid and r.e.ctrl(one).rdv,
                       x_alu_res,         -- in  : Data from LALU L0/L1 (C)
                       v.x.result,        -- in  : Data from Mul/Div Unit
                       ra_data12(i),      -- in  : Regfile Data 1 (Op1)
                       ra_data34(i),      -- in  : Regfile Data 3 (Op2)
                       ra_alu_forw(i),    -- out : Forwarding Signals for ALU L0
                       ra_alu_op1(i),     -- out : Op1 for ALU L0
                       ra_alu_op2(i)      -- out : Op2 for ALU L0
                       );
    end loop;

    -- To Write-Back Data -------------------------------------------------
    a_stdata_forwarding(r,                      -- in  : Registers
                        memory_lane,            -- in  : Lane
                        ex_result_fwd(0)   and r.e.ctrl(0).valid   and r.e.ctrl(0).rdv,
                        ex_result_fwd(one) and r.e.ctrl(one).valid and r.e.ctrl(one).rdv,
                        v.m.result,             -- in  : Data from ALU L0/L1
                        ra_data34(memory_lane), -- in  : Register File Port 3
                        ra_stdata_forw,         -- out : Forwarded Signal
                        ra_stdata               -- out : Write Back Value
                        );

    -- Jump Unit -----------------------------------------------------------
    a_jump_forwarding(r,                        -- in  : Registers
                      branch_lane,              -- in  : Lane
                      v.m.result,               -- in  : Data from ALU L0/L1 (C)
                      ex_result_fwd(0)   and r.e.ctrl(0).valid   and r.e.ctrl(0).rdv, -- ALU0 result valid
                      ex_result_fwd(one) and r.e.ctrl(one).valid and r.e.ctrl(one).rdv,
                      x_alu_res,                -- in  : Data from LALU L0/L1 (C)
                      v.x.result,               -- in  : Data from Mul/Div Unit
                      ra_data12(branch_lane),   -- in  : Regfile Data 2 (Op1)
                      ra_jump_forw,             -- out : Forwarding Signals for ALU L1
                      ra_jump_op1               -- out : Op1 for jump unit
                      );


    -- WFI and Power Down Mode --------------------------------------------
    -- Calculate this here to improve timing in exception unit
    v.e.is_wfi   := '0';
    if is_wfi(r.a.ctrl(0).inst) and PWRDEN then
      v.e.is_wfi := '1';
    end if;

    -- To Execute Stage ---------------------------------------------------
    for i in lanes'range loop
      v.e.ctrl(i).pc      := r.a.ctrl(i).pc;
      v.e.ctrl(i).inst    := r.a.ctrl(i).inst;
      v.e.ctrl(i).cinst   := r.a.ctrl(i).cinst;
      v.e.ctrl(i).valid   := r.a.ctrl(i).valid and not ra_flush;
      v.e.ctrl(i).actual  := r.a.ctrl(i).actual;
      v.e.ctrl(i).flushed := r.a.ctrl(i).flushed or ra_flush;
      v.e.ctrl(i).comp    := r.a.ctrl(i).comp;
      v.e.ctrl(i).branch  := r.a.ctrl(i).branch;
      v.e.ctrl(i).rdv     := r.a.ctrl(i).rdv;
      v.e.ctrl(i).csrv    := r.a.ctrl(i).csrv;
      v.e.ctrl(i).csrdo   := r.a.ctrl(i).csrdo;
      v.e.ctrl(i).xc      := ra_xc(i);
      v.e.ctrl(i).cause   := ra_xc_cause(i);
      v.e.ctrl(i).tval    := ra_xc_tval(i);
      v.e.ctrl(i).fusel   := r.a.ctrl(i).fusel;
      v.e.ctrl(i).mexc    := r.a.ctrl(i).mexc;
      v.e.rfa1(i)         := r.a.rfa1(i);
      v.e.rfa2(i)         := r.a.rfa2(i);
      -- Some kind of fetch fault?
      if r.a.ctrl(i).xc = '1' and
         (r.a.ctrl(i).cause = XC_INST_ACCESS_FAULT    or
          r.a.ctrl(i).cause = XC_INST_INST_PAGE_FAULT or
          r.a.ctrl(i).cause = XC_INST_INST_G_PAGE_FAULT) then
        -- Pass NOOP into the pipeline if there was a fetch fault.
        -- After this point no random instructions will be in the pipeline,
        -- but up to here it is necessary to check xc!
        v.e.ctrl(i).inst  := x"00100013"; -- addi x0,x0,1
        v.e.ctrl(i).cinst := x"0004";     -- c.addi x0,x0,1
        -- Make sure to mask precalculated things.
        v.e.ctrl(i).rdv   := '0';
        v.e.ctrl(i).csrv  := '0';
        v.e.ctrl(i).branch.valid := '0';
        v.e.ctrl(i).fusel := NONE;
      end if;
    end loop;
    v.e.ctrl(fpu_lane).fpu := r.a.ctrl(fpu_lane).fpu;
    if ext_f = 1 then
      -- This condition would have caused a hold in EX above!
      if r.e.fpu_wait = '1' and
         not (ex_flush = '1' or ex_fpu_flush = '1' or me_fpu_flush = '1') and
         not (fpuoa.now2int = '1' and fpuoa.id2int = r.e.ctrl(FPU_LANE).fpu) then
        v.e.fpu_wait := '1';
      else
        v.e.fpu_wait := '0';
        if is_valid_fpu(v, e) and not is_fpu_rd(v.e.ctrl(FPU_LANE).inst) and
           not fpuoa.holdn = '0' and not holdn = '0' then
          v.e.fpu_wait := '1';
        end if;
      end if;
    end if;
    v.e.csr               := r.a.csr;
    v.e.csr.v             := ra_csr;
    v.e.csr.imsic         := ra_csr_imsic;
    v.e.swap              := r.a.swap;
    v.e.stdata            := ra_stdata;
    v.e.jimm              := r.a.imm(branch_lane);
    v.e.jop1              := ra_jump_op1;
    v.e.jumpforw(branch_lane) := ra_jump_forw;
    v.e.aluforw(0)        := ra_alu_forw(0);
    if single_issue = 0 then
      v.e.aluforw(one)    := ra_alu_forw(one);
    end if;
    v.e.stforw            := ra_stdata_forw;
    v.e.raso              := r.a.raso;
    v.e.rasi              := r.a.rasi;

    mem_bar_gen(r.a.ctrl(memory_lane).inst,   -- in  : Instruction
                r.a.ctrl(memory_lane).fusel,  -- in  : Functional Unit
                v.e.ctrl(memory_lane).valid,  -- in  : Valid Instruction
                v.e.bar);


    -- Instruction Control ------------------------------------------------
    instruction_control(r,               -- in  : Registers
                        fpuoa.ready,     -- in  : FPU not busy
                        fpuoa.idle,      -- in  : FPU completely idle
                        ic_lddp,         -- out : Load Dependency Counter
                        ic_stb2b,        -- out : Store b2b Counter
                        ic_lbranch,      -- out : Late Branch Flag
                        ic_lalu,         -- out : Late ALU Flag
                        v.e.spec_ld,     -- out : Speculative load flag
                        v.e.accesshold,  -- inout : Memory access hold due to CSR changes.
                        v.e.hpmchold,    -- inout : Execution hold due to a read from a hpmcounter CSR
                        v.e.exechold,    -- inout : Execution hold due to pipeline flushing instruction.
                        v.e.fpuhold,     -- inout : Execution hold due to FPU instructions.
                        v.e.tracehold,   -- inout : Execution hold due to not delaying tracing.
                        ic_hold_issue    -- out : Hold Issue Signal
                        );

    -- To the ALUs --------------------------------------------------------
    for i in lanes'range loop
      v.e.alu(i).op1    := ra_alu_op1(i);
      v.e.alu(i).op2    := ra_alu_op2(i);
      v.e.alu(i).valid  := ra_alu_valid(i);
      v.e.alu(i).ctrl   := ra_alu_ctrl(i);
      v.e.alu(i).lalu   := ic_lalu(i);
    end loop;

    -- To the Branch Unit -------------------------------------------------
    v.e.lbranch        := ic_lbranch;

    -----------------------------------------------------------------------
    -- DECODE STAGE
    -----------------------------------------------------------------------

    -- Nullify Signal -----------------------------------------------------
    de_nullify     := '0';
    if ra_flush = '1' then   -- Nothing extra from RA!
      de_nullify   := '1';
    end if;

    de_inst        := (others => iword_none);
    de_inst(0).d   := r.d.inst(0)(31 downto 0);
    de_inst(0).dc  := r.d.inst(0)(15 downto 0);
    de_inst(1).d   := r.d.inst(0)(63 downto 32);
    de_inst(1).dc  := r.d.inst(0)(47 downto 32);
    de_inst(0).xc  := "000";
    de_inst(1).xc  := "000";
    de_inst(0).c   := '0';
    de_inst(1).c   := '0';

    if single_issue /= 0 then
      de_inst(1).d  := (others => '0');
      de_inst(1).dc := (others => '0');
    end if;

    r_d_valid := r.d.valid;


    -- RVC Aligner --------------------------------------------------------
    if ext_c = 1 then
      rvc_aligner(active_extensions,
                  de_inst,                      -- in  : Fetch Instructions
                  r.d.pc,                       -- in  : Decode PC
                  r_d_valid,                    -- in  : Valid Instructions
                  true,                         -- Take care of FPU illegality after expansion!
                  de_rvc_aligned,               -- out : Aligned Instructions
                  de_rvc_comp_ill,              -- out : Compressed illegal
                  de_rvc_hold,                  -- out : Hold Signal
                  de_rvc_npc,                   -- out : Next PC
                  de_rvc_valid,                 -- out : Valid Signal
                  de_rvc_buffer_first,          -- out : Buffer first inst if not issued
                  de_rvc_buffer_sec,            -- out : Buffer second inst if not issued
                  de_rvc_buffer_third,          -- out : Buffer third inst or unaligned
                  de_rvc_buffer_inst,           -- out : Buffer inst
                  de_rvc_buffer_comp_ill,       -- out : Buffer comp is illegal
                  v.d.unaligned                 -- out : Unaligned
                );
    else
      no_rvc_aligner(active_extensions,
                     de_inst,                   -- in  : Fetch Instructions
                     r.d.pc,                    -- in  : Decode PC
                     r_d_valid,                 -- in  : Valid Instructions
                     de_rvc_aligned,            -- out : Aligned Instructions
                     de_rvc_comp_ill,           -- out : Compressed illegal
                     de_rvc_hold,               -- out : Hold Signal
                     de_rvc_npc,                -- out : Next PC
                     de_rvc_valid,              -- out : Valid Signal
                     de_rvc_buffer_first,       -- out : Buffer first inst if not issued
                     de_rvc_buffer_sec,         -- out : Buffer second inst if not issued
                     de_rvc_buffer_third,       -- out : Buffer third inst or unaligned
                     de_rvc_buffer_inst,        -- out : Buffer inst
                     de_rvc_buffer_comp_ill,    -- out : Buffer comp is illegal
                     v.d.unaligned              -- out : Unaligned
                );
    end if;


    for i in fetch'range loop
      if de_rvc_valid(i) = '0' or de_rvc_aligned(i).c = '0' then
        de_rvc_comp_ill(i)   := '0';
      end if;
    end loop;
    if de_rvc_buffer_third = '0' and de_rvc_buffer_first = '0' then
      de_rvc_buffer_comp_ill := '0';
    end if;

    de_ipc(0) := r.d.pc(r.d.pc'high downto 3) & de_rvc_aligned(0).lpc & '0';
    de_ipc(1) := r.d.pc(r.d.pc'high downto 3) & de_rvc_aligned(1).lpc & '0';

    de_rvc_aligned(0).xc   := "000";
    de_rvc_aligned(1).xc   := "000";
    if r.d.mexc = '1' and r_d_valid = '1' then
      de_rvc_aligned(0).xc := r.d.exchyper & r.d.exctype & '1';
      de_rvc_aligned(1).xc := r.d.exchyper & r.d.exctype & '1';
      -- In case it is lsb of an unaligned instruction,
      -- make it valid to take the trap.
      de_rvc_valid(0)      := '1';
    end if;

    -- RVC Expander -----------------------------------------------------
    de_mux_instruction         := (others => iword_none);
    for i in fetch'range loop
      de_mux_instruction(i).d  := de_rvc_aligned(i).d;
      de_mux_instruction(i).xc := de_rvc_aligned(i).xc;
      de_rvc_illegal(i)        := '0';
      de_rvc_comp(i)           := de_rvc_aligned(i).c;
    end loop;
    de_mux_cinstruction(0)     := de_rvc_aligned(0).dc;
    de_mux_cinstruction(1)     := de_rvc_aligned(1).dc;

    -- Instruction Buffer Logic ------------------------------------------
    -- Save second instruction in case it is not issued.
    v.d.buff.inst     := de_mux_instruction(1);
    v.d.buff.cinst    := de_mux_cinstruction(1);
    v.d.buff.pc       := to0x(r.d.pc(r.d.pc'high downto 3) & de_rvc_aligned(1).lpc & '0');
    v.d.buff.comp     := de_rvc_comp(1);
    v.d.buff.xc       := de_rvc_illegal(1);
    v.d.buff.comp_ill := de_rvc_comp_ill(1);

    bjump_gen(active_extensions,
              de_inst,
              r.d.buff,
              r.d.bjump_pre,
              r.d.jump_pre,
              r.d.prediction,
              r_d_valid,
              r.d.pc,
              de_bjump_buff,
              de_bjump,
              de_btb_taken,
              de_btb_taken_buff,
              de_bjump_pos,
              de_bjump_addr);

    v.d.buff.bjump_predicted  := '0';
    v.d.buff.prediction.hit   := '0';
    v.d.buff.prediction.taken := '0';

    if (de_bjump = '1' or de_btb_taken = '1') and single_issue = 0 then
      if de_bjump_pos(0) = '1' then
        de_rvc_valid(1)       := '0';
      end if;
      if de_bjump_pos(1) = '1' then
        if de_rvc_aligned(1).lpc = "10" or de_rvc_aligned(1).lpc = "11" then
          de_rvc_valid(1)     := '0';
        end if;
        if r.d.buff.valid = '1' and de_rvc_aligned(1).lpc = "01" then
          -- Second instruction in rvc is jumping and there is a valid instruction in buffer.
          -- In this case assert buffer sec to latch bjump in the buffer,
          -- otherwise it might be lost if there is a valid instruction after that.
          de_rvc_buffer_sec   := '1';
          de_rvc_buffer_third := '0';
          v.d.unaligned       := '0';
        end if;
        if de_rvc_buffer_sec = '1' and de_rvc_aligned(1).lpc = "01" then
          v.d.buff.bjump_predicted := '1';
        end if;
      end if;
      if de_bjump_pos(2) = '1' then
        if de_rvc_aligned(1).lpc = "11" then
          de_rvc_valid(1)     := '0';
        end if;
        if de_rvc_buffer_third = '1' and de_rvc_buffer_inst.lpc = "10" then
          v.d.buff.bjump_predicted := '1';
        end if;
        if r.d.buff.valid = '1' and de_rvc_aligned(1).lpc = "10" then
          de_rvc_buffer_sec   := '1';
          de_rvc_buffer_third := '0';
          v.d.unaligned       := '0';
          -- Second instruction in rvc is jumping and there is a valid instruction in buffer.
          -- In this case assert buffer sec to latch bjump in the buffer,
          -- otherwise it might be lost if there is a valid instruction after that.
        end if;
        if de_rvc_buffer_sec = '1' and de_rvc_aligned(1).lpc = "10" then
          v.d.buff.bjump_predicted := '1';
        end if;
        if de_rvc_buffer_first = '1' then
          v.d.buff.bjump_predicted := '1';
        end if;
      end if;
      if de_bjump_pos(3) = '1' then
        v.d.buff.bjump_predicted   := '1';
        if de_rvc_buffer_first = '1' then
          v.d.buff.bjump_predicted := '1';
        end if;
      end if;
      if de_bjump_buff = '1' or de_btb_taken_buff = '1' then
        -- This can happen when an unaligned instruction exists in the buffer.
        de_rvc_valid   := "00";
      end if;
    end if;

    if (de_bjump = '1' or de_btb_taken = '1') and single_issue /= 0 then
       if de_bjump_pos(0) = '1' then
         de_rvc_buffer_third := '0';
         v.d.unaligned       := '0';
       end if;
    end if;

    if de_rvc_buffer_first = '1' and single_issue = 0 then
      if de_rvc_aligned(0).lpc = "10" then
        v.d.buff.prediction.hit   := r.d.prediction(2).hit;
        v.d.buff.prediction.taken := r.d.prediction(2).taken;
      elsif de_rvc_aligned(0).lpc = "11" then
        v.d.buff.prediction.hit   := r.d.prediction(3).hit;
        v.d.buff.prediction.taken := r.d.prediction(3).taken;
      end if;
    end if;

    if de_rvc_buffer_sec = '1' and single_issue = 0 then
      if de_rvc_aligned(1).lpc = "01" then
        v.d.buff.prediction.hit   := r.d.prediction(1).hit;
        v.d.buff.prediction.taken := r.d.prediction(1).taken;
      elsif de_rvc_aligned(1).lpc = "10" then
        v.d.buff.prediction.hit   := r.d.prediction(2).hit;
        v.d.buff.prediction.taken := r.d.prediction(2).taken;
      elsif de_rvc_aligned(1).lpc = "11" then
        v.d.buff.prediction.hit   := r.d.prediction(3).hit;
        v.d.buff.prediction.taken := r.d.prediction(3).taken;
      end if;
    end if;

    if de_rvc_buffer_third = '1' and single_issue = 0 then
      if de_rvc_buffer_inst.lpc = "10" then
        v.d.buff.prediction.hit   := r.d.prediction(2).hit;
        v.d.buff.prediction.taken := r.d.prediction(2).taken;
      elsif de_rvc_buffer_inst.lpc = "11" then
        v.d.buff.prediction.hit   := r.d.prediction(3).hit;
        v.d.buff.prediction.taken := r.d.prediction(3).taken;
      end if;
    end if;

    de_rvc_bhto_taken(0)   := r.d.prediction(0).taken;
    de_rvc_btb_hit(0)      := r.d.prediction(0).hit;
    if de_rvc_aligned(0).lpc = "01" or ( single_issue /= 0 and de_rvc_aligned(0).lpc = "11" )then
      de_rvc_bhto_taken(0) := r.d.prediction(1).taken;
      de_rvc_btb_hit(0)    := r.d.prediction(1).hit;
    elsif de_rvc_aligned(0).lpc = "10" and single_issue = 0 then
      de_rvc_bhto_taken(0) := r.d.prediction(2).taken;
      de_rvc_btb_hit(0)    := r.d.prediction(2).hit;
    elsif de_rvc_aligned(0).lpc = "11" and single_issue = 0 then
      de_rvc_bhto_taken(0) := r.d.prediction(3).taken;
      de_rvc_btb_hit(0)    := r.d.prediction(3).hit;
    end if;
    de_rvc_bhto_taken(1)   := r.d.prediction(0).taken;
    de_rvc_btb_hit(1)      := r.d.prediction(0).hit;
    if de_rvc_aligned(1).lpc = "01" then
      de_rvc_bhto_taken(1) := r.d.prediction(1).taken;
      de_rvc_btb_hit(1)    := r.d.prediction(1).hit;
    elsif de_rvc_aligned(1).lpc = "10" then
      de_rvc_bhto_taken(1) := r.d.prediction(2).taken;
      de_rvc_btb_hit(1)    := r.d.prediction(2).hit;
    elsif de_rvc_aligned(1).lpc = "11" then
      de_rvc_bhto_taken(1) := r.d.prediction(3).taken;
      de_rvc_btb_hit(1)    := r.d.prediction(3).hit;
    end if;

    if v.d.unaligned = '1' then
      v.d.buff.bjump_predicted := '0';
      v.d.buff.xc              := '0';
    end if;

    de_buff_inst_xc   := "000";
    if r.d.unaligned = '1' and r.d.mexc = '1' then
      de_buff_inst_xc := r.d.exchyper & r.d.exctype & '1';
    end if;

    -- New instructions
    de_inst_xc_msb   := '0';
    de_inst_buff     := de_mux_instruction;
    de_cinst_buff    := de_mux_cinstruction;
    de_pc            := de_ipc;
    de_inst_valid    := de_rvc_valid;
    de_comp          := de_rvc_comp;
    de_rvc_xc        := de_rvc_illegal;
    de_inst_no_buf   := "00";
    de_inst_mexc     := r.d.mexc & r.d.mexc;
    de_inst_comp_ill := de_rvc_comp_ill;
    if r.d.buff.valid = '1' then
      -- Only add one new instruction.
      de_inst_xc_msb       := r.d.unaligned and r.d.mexc;  -- Unaligned [31:16] exception
      de_inst_mexc(0)      := de_inst_xc_msb;
      de_inst_buff(1)      := de_mux_instruction(0);
      de_inst_buff(0)      := r.d.buff.inst;
      de_inst_buff(0).xc   := de_buff_inst_xc;
      de_cinst_buff(1)     := de_mux_cinstruction(0);
      de_cinst_buff(0)     := r.d.buff.cinst;
      de_pc(1)             := de_ipc(0);
      de_pc(0)             := r.d.buff.pc(de_pc(0)'range);
      de_inst_valid(1)     := de_rvc_valid(0);
      de_inst_valid(0)     := r.d.buff.valid;
      de_comp(1)           := de_rvc_comp(0);
      de_comp(0)           := r.d.buff.comp;
      de_rvc_xc(1)         := de_rvc_illegal(0);
      de_rvc_xc(0)         := r.d.buff.xc;
      de_rvc_btb_hit(1)    := de_rvc_btb_hit(0);
      de_rvc_bhto_taken(1) := de_rvc_bhto_taken(0);
      de_rvc_btb_hit(0)    := r.d.buff.prediction.hit;
      de_rvc_bhto_taken(0) := r.d.buff.prediction.taken;
      de_inst_no_buf(0)    := '1';
      de_inst_comp_ill(0)  := r.d.buff.comp_ill;
      de_inst_comp_ill(1)  := de_rvc_comp_ill(0);
    end if;

    if single_issue /= 0 then
      de_inst_valid(1) := '0';
    end if;

    late_alu_precheck(r,
                      cfi_en,
                      de_inst_buff,      -- in  : Aligned Instructions
                      de_inst_valid,     -- in  : Valid Signals
                      ic_lalu,           -- in  : Late ALU Flag
                      de_lalu_pre);      -- out :

    de_rvc_buffer_inst_exp := de_rvc_buffer_inst.d;
    de_rvc_buffer_inst_xc  := '0';
    de_rvc_buffer_comp     := de_rvc_buffer_inst.c;


    if de_rvc_buffer_third = '1' or de_rvc_buffer_first = '1' then
      -- bufferin a third instruction or first instruction or unaligned
      v.d.buff.inst.d   := de_rvc_buffer_inst_exp;
      v.d.buff.cinst    := de_rvc_buffer_inst.dc;
      v.d.buff.comp     := de_rvc_buffer_comp;
      v.d.buff.pc       := to0x(r.d.pc(r.d.pc'high downto 3) & de_rvc_buffer_inst.lpc & '0');
      v.d.buff.comp_ill := de_rvc_buffer_comp_ill;
    -- bufferin of [31:16] is done after the v.d.inst assigment
    end if;

    v.d.buff.bjump := '0';
    if v.d.buff.inst.d(1 downto 0) = "11" then
      if (v.d.buff.inst.d(6 downto 5) = "11") and
        (v.d.buff.inst.d(4 downto 2) = "000" or v.d.buff.inst.d(4 downto 2) = "011") then
        v.d.buff.bjump := '1';
        if v.d.buff.inst.d(3) = '1' then
          v.d.buff.prediction.taken := '1';
          -- Force bjump for jump operations
        end if;
      end if;
    end if;

    for i in fetch'range loop
      exception_check(active_extensions,
                      r.csr.menvcfg,
                      r.csr.henvcfg,
                      r.csr.senvcfg,
                      r.csr.fpu_enabled,
                      not fpu_illegal(active_extensions, de_inst_buff(i).d, r.csr.frm),
                      not alu_illegal(active_extensions, de_inst_buff(i).d),
                      illegalTval0 = 1,
                      r.csr.dfeaturesen.diag_s = '1',
                      de_inst_buff(i).d,   -- in  : Instruction
                      de_cinst_buff(i),    -- in  : Compressed instruction
                      de_comp(i),          -- in  : Instruction is compressed
                      de_pc(i),            -- in  : PC
                      de_inst_comp_ill(i), -- in  : Illegal compressed inst
                      r.csr.misa,          -- in  : CSR MISA
                      r.csr.prv,           -- in  : Current Privileged Level
                      r.csr.v,             -- in  : Current Virtualization mode
                      r.csr.mstatus.tsr,   -- in  : Trap SRET bit
                      r.csr.mstatus.tw,    -- in  : Timeout Wait bit
                      r.csr.mstatus.tvm,   -- in  : Trap Virtual Memory bit
                      r.csr.hstatus.vtsr,  -- in  : Virtual Trap SRET bit
                      r.csr.hstatus.vtw,   -- in  : Virtual Timeout Wait bit
                      r.csr.hstatus.vtvm,  -- in  : Virtual Trap Virtual Memory bit
                      r.csr.hstatus.hu,    -- in  : Hypervisor User mode
                      de_xc(i),            -- out : Exception Valid
                      de_xc_cause(i),      -- out : Exception Cause
                      de_xc_tval(i));      -- out : Exception Value
    end loop;


    if single_issue = 0 then
      -- Issue Checker -----------------------------------------------------
      dual_issue_check(active_extensions,
                       cfi_en,
                       lane,
                       de_inst_buff,      -- in  : Aligned Instructions
                       de_inst_valid,     -- in  : Valid Signals
--                       r.csr.dfeaturesen, -- in  : Machine Features CSR
                       r.csr.dfeaturesen.lbranch_dis,
                       r.csr.dfeaturesen.lalu_dis,
                       r.csr.dfeaturesen.dual_dis,
                       r.csr.dfeaturesen.hpmc_mode,
                       r.csr.dcsr.step,   -- in  : DCSR step
                       r.a.lalu_pre,      -- in  : Late ALUs from RA
                       de_xc,             -- in  : Exception valid
                       r.d.mexc,          -- in  : Fetch exception
                       rd(v, e, 0),       -- in  : rd register from RA
                       v.e.ctrl(0).rdv,   -- in  : Valid rd register from RA
                       rd(v, e, 1),       -- in  : rd register from RA
                       v.e.ctrl(one).rdv, -- in  : Valid rd register from RA
                       de_lane0_csr,      -- out : CSR must be copied to lane 0
                       de_issue           -- out : Issue Flag
                       );

    -- Dual Issue Swap ---------------------------------------------------
      dual_issue_swap(active_extensions,
                      cfi_en,
                      lane,
                      de_inst_buff,       -- in  : Instructions
                      de_inst_valid,      -- in  : Valid Signals
                      de_swap             -- out : Swapped Instructions Flag
                      );
    else
      de_lane0_csr  := '0';
      de_issue      := "01";
      de_swap       := '0';
    end if;

    -- Instruction Queue Logic -------------------------------------------
    buffer_ic(active_extensions,
              r.d.buff.valid,
              de_inst_valid,            -- in  : Instruction Valid from RVC Decoder
              de_rvc_valid,             -- in  : Instruction Decode Valid Signals
              de_rvc_buffer_third,      -- in  : Buffer third inst
              de_rvc_buffer_sec,        -- in  : Buffer sec inst
              de_rvc_buffer_first,      -- in  : Buffer first
              v.d.unaligned,            -- in  : Unaligned
              de_issue,                 -- in  : Instruction Issue Valid Signals
              de_hold_pc,               -- out : Hold PC
              v.d.buff.valid            -- out : Buffer valid
              );

    if r.d.mexc = '1' and r_d_valid = '1' then
      v.d.buff.valid := '0';
    end if;

    -- Hold PC if hold_issue from instruction_control or in dhalt state.
    if de_rvc_hold = '1' or (dmen = 1 and r.x.rstate = dhalt) then
      de_hold_pc := '1';
    end if;


    -- Decode Instructions
    for i in fetch'range loop
      de_rfa1(i)       := rs1_gen(active_extensions,
                                  cfi_en,
                                  de_inst_buff(i).d);
      de_rfa2(i)       := rs2_gen(active_extensions,
                                  cfi_en,
                                  de_inst_buff(i).d);
      -- For register file read port, generate non-masked address to reduce
      -- critical path, since register value does not matter when source
      -- is not valid.
      de_rfa1_nmask(i) := rs1(de_inst_buff(i).d);
      -- Except for an implicit x7 read for LPAD instruction
      if i = 0 and is_lpad(active_extensions, cfi_en, de_inst_buff(0).d) then
        de_rfa1_nmask(0) := "00111";
      end if;
      de_rfa2_nmask(i) := rs2(de_inst_buff(i).d);

      de_rfrd_valid(i) := rd_gen(active_extensions,
                                 cfi_en,
                                 de_inst_buff(i).d);

      imm_gen(active_extensions,
              de_inst_buff(i).d,        -- in  : Instruction
              de_imm_valid(i),          -- out : Immediate Valid Flag
              de_imm(i),                -- out : Immediate Value
              de_bj_imm(i));            -- out : only bjump imm value

      de_pc_valid(i)   := pc_valid(
                                   active_extensions,
                                   cfi_en,
                                   de_inst_buff(i).d);

      de_csr_valid(i)  := to_bit(is_csr(active_extensions,
                                        cfi_en,
                                        de_inst_buff(i).d));

      de_csr_rdo(i)    := '0';
      if csr_read_only(active_extensions, de_inst_buff(i).d) then
        de_csr_rdo(i)  := '1';
      end if;

      de_fusel(i)      := fusel_gen(active_extensions,
                                    de_inst_buff(i).d,   -- in  : Instruction
                                    cfi_en
                                   );
    end loop;

    -- Avoid getting two illegal instructions logged.
    if de_xc(0) = '1' then
      de_inst_valid(1) := '0';
    end if;

    -- Check for previous exceptions --------------------------------------
    de_to_ra_xc            := de_xc;
    de_to_ra_cause         := de_xc_cause;
    de_to_ra_tval          := de_xc_tval;

    -- Instruction fetch fault overrides things from exception check().
    if de_inst_valid(0) = '1' and de_inst_buff(0).xc(0) = '1' then
      de_inst_valid(1)     := '0';
      de_to_ra_xc(0)       := '1';
      -- There is no point in trying to pass these from r.d,
      -- since instructions may have been queued.
      if de_inst_buff(0).xc(1) = '1' then
        de_to_ra_cause(0)  := check_cause_update(XC_INST_ACCESS_FAULT, de_to_ra_cause(0));
      elsif de_inst_buff(0).xc(2) = '1' then
        de_to_ra_cause(0)  := check_cause_update(XC_INST_INST_G_PAGE_FAULT, de_to_ra_cause(0));
      else
        de_to_ra_cause(0)  := check_cause_update(XC_INST_INST_PAGE_FAULT, de_to_ra_cause(0));
      end if;
      de_to_ra_tval(0)     := pc2xlen(de_pc(0));
      if de_inst_xc_msb = '1' then
        -- While fetching the second part of an unaligned instruction,
        -- the PC would be first 16 bytes for r.d.pc.
        de_to_ra_tval(0)   := pc2xlen(r.d.pc(r.d.pc'high downto 3) & "000");
        if single_issue /= 0 then
          de_to_ra_tval(0) := pc2xlen(r.d.pc(r.d.pc'high downto 2) & "00");
        end if;
      end if;
    elsif de_inst_buff(1).xc(0) = '1' then
      de_to_ra_xc(1)       := '1';
      -- There is no point in trying to pass these from r.d,
      -- since instructions may have been queued.
      if de_inst_buff(1).xc(1) = '1' then
        de_to_ra_cause(1)  := check_cause_update(XC_INST_ACCESS_FAULT, de_to_ra_cause(1));
      elsif de_inst_buff(1).xc(2) = '1' then
        de_to_ra_cause(1)  := check_cause_update(XC_INST_INST_G_PAGE_FAULT, de_to_ra_cause(1));
      else
        de_to_ra_cause(1)  := check_cause_update(XC_INST_INST_PAGE_FAULT, de_to_ra_cause(1));
      end if;
      de_to_ra_tval(1)     := pc2xlen(de_pc(1));
    end if;

    if r.d.mexc = '1' and (r.d.buff.valid = '0' or
                           (r.d.buff.valid = '1' and r.d.unaligned = '1' and r.d.mexc = '1')) then
      de_inst_valid(1) := '0';
    end if;

    -- inull icache after encountering an instruction memory exception
    mexc_inull   := '0';
    if (r.d.mexc = '1' and r_d_valid = '1') then
      mexc_inull := '1';
    end if;

    -- Ensure that instruction fetch is not done if a previous one
    -- (which hasn't yet flushed the pipeline) had a fetch fault.
    for i in lanes'range loop
      if (r.a.ctrl(i).mexc = '1' and r.a.ctrl(i).valid = '1') or
         (r.e.ctrl(i).mexc = '1' and r.e.ctrl(i).valid = '1') or
         (r.m.ctrl(i).mexc = '1' and r.m.ctrl(i).valid = '1') then
        -- Exception is not included since the xc will annul the cache on that stage
        mexc_inull := '1';
      end if;
    end loop;

    if r.d.was_xc = '1' then
      de_to_ra_xc    := (others => '1');
      -- To make sure NOP:ing is done in RA.
      for i in lanes'range loop
        de_to_ra_cause(i) := check_cause_update(XC_INST_ACCESS_FAULT, de_to_ra_cause(i));
      end loop;
    end if;

    -- To Register Access Stage -------------------------------------------
    for i in lanes'range loop
      v.a.ctrl(i).pc      := de_pc(i);
      v.a.ctrl(i).inst    := de_inst_buff(i).d;
      v.a.ctrl(i).cinst   := de_cinst_buff(i);
      v.a.ctrl(i).valid   := de_issue(i) and de_inst_valid(i);
      v.a.ctrl(i).actual  := de_issue(i) and de_inst_valid(i);
      v.a.ctrl(i).flushed := '0';
      v.a.ctrl(i).comp    := de_comp(i);
      v.a.ctrl(i).branch  := branch_none;
      v.a.ctrl(i).rdv     := de_rfrd_valid(i);
      v.a.ctrl(i).csrv    := de_csr_valid(i);
      v.a.ctrl(i).csrdo   := de_csr_rdo(i);
      v.a.ctrl(i).xc      := de_to_ra_xc(i);
      v.a.ctrl(i).cause   := de_to_ra_cause(i);
      v.a.ctrl(i).tval    := de_to_ra_tval(i);
      v.a.ctrl(i).fusel   := de_fusel(i);
      v.a.rfa1(i)         := de_rfa1(i);
      v.a.rfa2(i)         := de_rfa2(i);
      de_rfa1_nmasked(i)  := de_rfa1_nmask(i);
      de_rfa2_nmasked(i)  := de_rfa2_nmask(i);
      v.a.imm(i)          := de_imm(i);
      v.a.immv(i)         := de_imm_valid(i);
      v.a.pcv(i)          := de_pc_valid(i);
      v.a.lalu_pre(i)     := de_lalu_pre(i);
      v.a.ctrl(i).mexc    := de_inst_mexc(i);
    end loop;
    v.a.swap              := to_bit(single_issue = 0) and de_swap;
    v_a_inst_no_buf       := de_inst_no_buf;

    -- Swap Instructions --------------------------------------------------
    if de_swap = '1' then
      for i in lanes'range loop
        v.a.ctrl(i).pc      := de_pc(1 - i);
        v.a.ctrl(i).inst    := de_inst_buff(1 - i).d;
        v.a.ctrl(i).cinst   := de_cinst_buff(1 - i);
        v.a.ctrl(i).valid   := de_issue(1 - i) and de_inst_valid(1 - i);
        v.a.ctrl(i).actual  := de_issue(1 - i) and de_inst_valid(1 - i);
        v.a.ctrl(i).flushed := '0';
        v.a.ctrl(i).comp    := de_comp(1 - i);
        v.a.ctrl(i).rdv     := de_rfrd_valid(1 - i);
        v.a.ctrl(i).csrv    := de_csr_valid(1 - i);
        v.a.ctrl(i).csrdo   := de_csr_rdo(1 - i);
        v.a.ctrl(i).xc      := de_to_ra_xc(1 - i);
        v.a.ctrl(i).cause   := de_to_ra_cause(1 - i);
        v.a.ctrl(i).tval    := de_to_ra_tval(1 - i);
        v.a.ctrl(i).fusel   := de_fusel(1 - i);
        v.a.rfa1(i)         := de_rfa1(1 - i);
        v.a.rfa2(i)         := de_rfa2(1 - i);
        de_rfa1_nmasked(i)  := de_rfa1_nmask(1 - i);
        de_rfa2_nmasked(i)  := de_rfa2_nmask(1 - i);
        v.a.imm(i)          := de_imm(1 - i);
        v.a.immv(i)         := de_imm_valid(1 - i);
        v.a.pcv(i)          := de_pc_valid(1 - i);
        v.a.lalu_pre(i)     := de_lalu_pre(1 - i);
        v_a_inst_no_buf(i)  := de_inst_no_buf(1 - i);
        v.a.ctrl(i).mexc    := de_inst_mexc(1 - i);
      end loop;
    end if;

    -- Increase FPU issue ID
    if is_valid_fpu(v, a) then
      v.a.ctrl(fpu_lane).fpu := uadd(r.a.ctrl(fpu_lane).fpu, 1);
    end if;

    v.a.csr.r             := '0';
    v.a.csr.w             := '0';
    if csr_ok(v, a) then
      v.a.csr.r           := '1';
      v.a.csr.w           := '1';
    end if;
    if csr_write_only(v, a) then
      v.a.csr.r           := '0';
    end if;
    if csr_read_only(v, a) then
      v.a.csr.w           := '0';
    end if;
    v.a.csr.addr        := csr_addr(active_extensions, v.a.ctrl(csr_lane).inst);
    if is_csr_access(v.a.ctrl(csr_lane).inst) then
      v.a.csr.raw_cat   := csr_raw_category(csr_access_addr(v, a));
      v.a.csr.waw_cat   := csr_waw_category(csr_access_addr(v, a));
      v.a.csr.hold_cat  := csr_hold_category(csr_access_addr(v, a), r.csr.dfeaturesen.hpmc_mode);
    else
      v.a.csr.raw_cat   := (others => '0');
      v.a.csr.waw_cat   := (others => '0');
      v.a.csr.hold_cat  := (others => '0');
    end if;
    v.a.csr.ctrl          := csralu_gen(v.a.ctrl(csr_lane).inst);

    de_bhto_taken := de_rvc_bhto_taken;
    de_btbo_hit   := de_rvc_btb_hit;
    if de_swap = '1' then
      de_bhto_taken(1) := de_rvc_bhto_taken(0);
      de_bhto_taken(0) := de_rvc_bhto_taken(1);
      de_btbo_hit(1)   := de_rvc_btb_hit(0);
      de_btbo_hit(0)   := de_rvc_btb_hit(1);
    end if;

    if ras >= 1 then
      -- Return Address Stack Logic -----------------------------------------
      ras_resolve(active_extensions,
                  v.a.ctrl(branch_lane).inst,     -- in  : Instruction
                  v.a.ctrl(branch_lane).fusel,    -- in  : Functional Unit
                  v.a.ctrl(branch_lane).valid,    -- in  : Instruction Valid
                  v.a.ctrl(branch_lane).xc,       -- in  : Exception
                  v.a.ctrl(branch_lane).rdv,      -- in  : Destination Valid
                  v.a.rfa1(branch_lane),          -- in  : RS1
                  raso,                           -- in  : RAS Stack Value
                  de_raso,                        -- out : Jump
                  de_ras_jump_xc,                 -- out : Jump Exception
                  de_ras_jump_cause,              -- out : Exception Cause
                  de_ras_jump_tval                -- out : Exception Value
                  );
    end if;
    if ras < 2 then
      de_raso.hit := '0';
    end if;

    -- Return Address Stack Control ---------------------------------------
    v.a.raso.hit   := de_raso.hit;
    v.a.raso.rdata := de_raso.rdata;

    branch_misc(active_extensions,
                v.a.ctrl(branch_lane).fusel,
                v.a.ctrl(branch_lane).valid,
                v.a.ctrl(branch_lane).xc,
                v.a.ctrl(branch_lane).pc,
                v.a.ctrl(branch_lane).comp,
                de_bhto_taken(branch_lane),
                de_btbo_hit(branch_lane),
                de_bj_imm,
                de_swap,
                branch_lane,
                de_branch_valid,
                de_branch_taken,
                de_branch_hit,
                de_branch_xc,
                de_branch_cause,
                de_branch_next,
                de_branch_addr);

    -- Update Branch Control ----------------------------------------------
    v.a.ctrl(branch_lane).branch.valid := de_branch_valid;
    v.a.ctrl(branch_lane).branch.addr  := de_branch_addr;
    v.a.ctrl(branch_lane).branch.naddr := de_branch_next;
    v.a.ctrl(branch_lane).branch.taken := de_branch_taken;
    v.a.ctrl(branch_lane).branch.hit   := de_branch_hit;


    -- Early JAL ----------------------------------------------------------
    ujump_resolve(active_extensions,
                  v.a.ctrl(branch_lane).inst,   -- in  : Instruction
                  v.a.ctrl(branch_lane).valid,  -- in  : Valid Instruction
                  v.a.ctrl(branch_lane).xc,     -- in  : Exception
                  de_branch_addr,               -- in  : Computed Target
                  de_branch_next,               -- in  : Next Pc
                  de_bhto_taken(branch_lane),   -- in  : Prediction
                  de_btbo_hit(branch_lane),     -- in  : Hit
                  de_jump_xc,                   -- out : Jump Exception
                  de_jump_cause,                -- out : Exception Cause
                  de_jump_tval,                 -- out : Exception Value
                  de_jump,                      -- out : Jump Signal
                  de_jump_addr                  -- out : Jump Address
                  );

    -- Store JAL Address --------------------------------------------------
    if de_jump = '1' then
      v.a.ctrl(branch_lane).branch.addr := de_jump_addr;
    end if;

    -- Insert Exception ---------------------------------------------------
    if v.a.ctrl(branch_lane).xc = '0' then
      -- Early Jump
      if de_jump_xc = '1' then
        v.a.ctrl(branch_lane).xc    := '1';
        v.a.ctrl(branch_lane).cause := de_jump_cause;
        v.a.ctrl(branch_lane).tval  := de_jump_tval;
      -- Jump from RAS
      elsif de_ras_jump_xc = '1' then
        v.a.ctrl(branch_lane).xc    := '1';
        v.a.ctrl(branch_lane).cause := de_ras_jump_cause;
        v.a.ctrl(branch_lane).tval  := de_ras_jump_tval;
      -- Early Branch
      elsif de_branch_xc = '1' then
        v.a.ctrl(branch_lane).xc    := '1';
        v.a.ctrl(branch_lane).cause := de_branch_cause;
        v.a.ctrl(branch_lane).tval  := pc2xlen(de_branch_addr);
      end if;
    end if;

    if ras >= 1 then
      -- Return Address Stack Update Logic ----------------------------------
      ras_update(1,                                   -- in  : Speculative Update
                 v.a.ctrl(branch_lane).inst,          -- in  : Instruction
                 v.a.ctrl(branch_lane).fusel,         -- in  : Functional Unit
                 v.a.ctrl(branch_lane).valid,         -- in  : Instruction Valid
                 v.a.ctrl(branch_lane).xc,            -- in  : Exception
                 v.a.ctrl(branch_lane).rdv,           -- in  : Destination Valid
                 v.a.ctrl(branch_lane).branch.naddr,  -- in  : Return Address
                 wb_rasi,                             -- in  : Update from WB Stage
                 ic_hold_issue or ex_hold_pc,         -- in  : Nullify Signal
                 r.x.rstate,                          -- in  : Core State
                 de_rasi                              -- out : RASI
                 );

      -- Register Speculative RAS -------------------------------------------
      v.a.rasi.pop   := de_rasi.pop;
      v.a.rasi.push  := de_rasi.push;
      v.a.rasi.flush := de_rasi.flush;
      v.a.rasi.wdata := de_raso.rdata;

      -- Merge RAS Logic ----------------------------------------------------
      vrasi   := de_rasi;
      if (wb_rasi.pop or wb_rasi.push or wb_rasi.flush) = '1' then
        vrasi := wb_rasi;
      end if;
    end if;

    -- Register File ------------------------------------------------------
    rfi_rdhold := '0';
    if holdn = '0' or ex_hold_pc = '1' or ic_hold_issue = '1' then
      rfi_rdhold := '1';
    end if;
    for i in lanes'range loop
      rfi_raddr12(i)   := de_rfa1_nmasked(i);
      rfi_raddr34(i)   := de_rfa2_nmasked(i);
      rfi_ren12(i)     := v.a.ctrl(i).valid;
      rfi_ren34(i)     := v.a.ctrl(i).valid;
    end loop;


    if dmen = 1 then
      if (r.dm.cmdexec(1) and not r.dm.write and r.dm.cmd(0)) = '1' and
         r.x.rstate = dhalt then
        rfi_raddr12(0)   := r.dm.addr(4 downto 0);
        rfi_ren12(0)     := '1';
      end if;
    end if;


    -- Deassert de_hold_pc on de_btb_taken and bjump instruction is issued
    if de_btb_taken = '1' then
      for i in 0 to 3 - (2 * single_issue) loop
        if de_bjump_pos(i) = '1' then
          for j in lanes'range loop
            if v.a.ctrl(j).valid = '1' and v.a.ctrl(j).pc(2 downto 1) = u2vec(i, 2) and
               v_a_inst_no_buf(j) = '0' and single_issue = 0 then
              de_hold_pc  := '0';
              de_rvc_hold := '0';
            end if;
            if single_issue /= 0 then
              if v.a.ctrl(j).valid = '1' and v.a.ctrl(j).pc(1 downto 1) = u2vec(i, 1) and
                 v_a_inst_no_buf(j) = '0' then
                de_hold_pc  := '0';
                de_rvc_hold := '0';
              end if;
            end if;
          end loop;
          if v.d.buff.valid = '1' and v.d.buff.pc(2 downto 1) = u2vec(i, 2) and single_issue = 0 then
            de_hold_pc  := '0';
            de_rvc_hold := '0';
          end if;
        end if;
      end loop;
      if de_btb_taken_buff = '1' then
        de_hold_pc  := '0';
        de_rvc_hold := '0';
      end if;
    end if;

    if de_btb_taken = '1' then
      if de_btb_taken_buff = '0' then
        for i in 0 to 3 - (2 * single_issue) loop
          if de_bjump_pos(i) = '1' then
            if v.d.buff.pc(2 downto 1) /= u2vec(i, 2) and single_issue = 0 then
              v.d.buff.valid := '0';
            end if;
            if single_issue /= 0 then
              if v.d.buff.pc(1 downto 1) /= u2vec(i, 1) then
                v.d.buff.valid := '0';
              end if;
            end if;
          end if;
        end loop;
      end if;
      if de_btb_taken_buff = '1' and r.d.unaligned = '1' then
        v.d.buff.valid := '0';
      end if;
    end if;

    -----------------------------------------------------------------------
    -- FETCH STAGE
    -----------------------------------------------------------------------

    f_inull   := '0';    -- Discards incoming instructions
    de_inull  := '0';    -- Invalidates current I$ fetch

    -- Prevent unneeded fetching when exception on instruction out of decode,
    -- or in ra, ex or mem.
    -- Flushing pipeline?
    if de_nullify = '1' then
      v.d.was_xc := '0';
    -- New exception reported from DE? (irrelevant when holdn asserted)
    elsif not all_0(de_to_ra_xc and de_issue and de_inst_valid) then
      v.d.was_xc    := '1';
--      de_inull := '1';
    end if;

    -- Common Nullify for Fetch Stage and Instruction Cache ---------------
    if (wb_pipeflush  or
        x_xc_taken    or               -- Exception taken cycle
        ex_hold_pc    or               -- Divide/FPU instruction in EX
        ic_hold_issue or               -- Data or structural hazard in RA
        de_rvc_hold   or               -- Hold due to extra instructions
        mexc_inull    or               -- Exception instruction pipeline
        mem_branch    or wb_branch or  -- Early/late branch mispredict
        de_bjump      or               -- Branch jump from decode stage
        de_raso.hit   or               -- RAS hit in DE
        ex_jump) = '1' then            -- JALR in EX
      f_inull  := '1';
      de_inull := '1';
    end if;

    -- Generate Nullify for Fetch Stage -----------------------------------
    if v.wb.flushall = '1' then
      f_inull  := '1';
    end if;

    -- Generate Nullify for Instruction Cache -----------------------------
    f_pb_exec := to_bit((dmen = 1) and (r.x.rstate = dexec) and -- Execute from program buffer?
                        (r.f.pc(r.f.pc'high downto 7) = DPROGBUF(r.f.pc'high downto 7)));
    if (not rstn   or          -- Reset
        de_hold_pc or          -- Hold PC due to Instruction buffer, RVC alignment or dhalt
        not r.f.valid or       -- Inull during the first cycle after reset
        f_pb_exec) = '1' then  -- Program buffer fetch
      de_inull := '1';
    end if;


    -- To Decode Stage ----------------------------------------------------
    if ico.mds = '0' or de_hold_pc = '0' then
      for i in 0 to IWAYS - 1 loop
        if ico.way(IWAYMSB downto 0) = u2vec(i, IWAYMSB + 1) then
          v.d.inst(0) := ico.data(i);
          if single_issue /= 0 then
            v.d.inst(0)(31 downto 0)     := ico.data(i)(31 downto 0);
            if r.f.pc(2) = '1' then
              v.d.inst(0)(31 downto 0)   := ico.data(i)(63 downto 32);
            end if;
            if ico.mds = '0' then
              v.d.inst(0)(31 downto 0)   := ico.data(i)(31 downto 0);
              if r.d.pc(2) = '1' then
                v.d.inst(0)(31 downto 0) := ico.data(i)(63 downto 32);
              end if;
            end if;
          end if;
        end if;
      end loop;
      v.d.way         := ico.way(IWAYMSB downto 0);   -- hit way
      v.d.mexc        := ico.mexc;                    -- access exception
      v.d.exctype     := ico.exctype;
      v.d.exchyper    := ico.exchyper;
      v.d.tval2       := ico.addrhyper(XLEN - 1 downto 0);
      v.d.tval2type   := ico.typehyper;
      -- Progam buffer
      if f_pb_exec = '1' then
        v.d.inst(0)   := dbgi.pbdata;
        if single_issue /= 0 then
          v.d.inst(0)(31 downto 0) := dbgi.pbdata(31 downto 0);
          if r.f.pc(2) = '1' then
            v.d.inst(0)(31 downto 0) := dbgi.pbdata(63 downto 32);
          end if;
        end if;
        v.d.way       := (others => '0');
        v.d.mexc      := '0';
        v.d.exctype   := '0';
        v.d.exchyper  := '0';
        v.d.tval2     := zerox;
        v.d.tval2type := "00";
      end if;
    end if;

    -- Buffer the MSB of the unaligned instruction
    if de_rvc_buffer_third = '1' and v.d.unaligned = '1' then
      v.d.buff.inst.d(31 downto 16) := v.d.inst(0)(15 downto 0);
    end if;

    if ico.mds = '0' and r.d.unaligned = '1' and r.d.buff.valid = '1' then
      v.d.buff.inst.d(31 downto 16) := v.d.inst(0)(15 downto 0);
    end if;


    v.d.pc := r.f.pc;

    if de_rvc_hold = '1' then
      v.d.pc := r.d.pc(r.d.pc'high downto 3) & de_rvc_npc;
      if single_issue = 0 then
        if de_rvc_valid(1) = '1' and de_issue(1) = '0' then
          v.d.pc := r.d.pc(r.d.pc'high downto 3) & de_rvc_aligned(1).lpc & '0';
        end if;
        if r.d.buff.valid = '1' then
          if de_rvc_valid(0) = '1' and de_issue(1) = '0' then
            v.d.pc := r.d.pc;
          elsif de_rvc_valid(0) = '1' and de_issue(1) = '1' then
            v.d.pc := r.d.pc(r.d.pc'high downto 3) & de_rvc_aligned(1).lpc & '0';
          end if;
        end if;
      end if;
      if single_issue /= 0 then
        v.d.pc := r.d.pc(r.d.pc'high downto 2) & "10";
      end if;
    end if;

    if de_hold_pc = '1' then
      if r.d.buff.valid = '0' and single_issue = 0 then
        if de_rvc_buffer_third = '1' then
          if de_rvc_valid(1) = '1' and de_issue(1) = '0' then
            v.d.pc := r.d.pc(r.d.pc'high downto 3) & de_rvc_aligned(1).lpc & '0';
          end if;
        end if;
      end if;

      if r.d.buff.valid = '1' and single_issue = 0 then
        if de_rvc_buffer_third = '1' then
          if de_issue(1) = '0' then
            v.d.pc := r.d.pc;
          else
            v.d.pc := r.d.pc(r.d.pc'high downto 3) & de_rvc_aligned(1).lpc & '0';
          end if;

          if v.d.unaligned = '1' then
            if de_rvc_valid(0) = '1' and de_issue(1) = '0' then
              v.d.pc := r.d.pc;
            elsif de_rvc_valid(0)= '1' and de_issue(1) = '1' then
              -- If it is holding that means there is a valid instruction in lane 1
              v.d.pc := r.d.pc(r.d.pc'high downto 3) & de_rvc_aligned(1).lpc & '0';
            end if;
          end if;
        end if;
        if de_rvc_buffer_sec = '1' then
          if de_issue(1) = '0' then
            v.d.pc := r.d.pc;
          end if;
        end if;
      end if;

      if r.d.buff.valid = '1' and single_issue /= 0 then
        v.d.pc := r.d.pc;
      end if;
    end if;

    if v.d.buff.valid = '1' and v.d.unaligned = '1' then
      v.d.pc := r.f.pc(r.f.pc'high downto 2) & "10";
    end if;

    if r.f.valid = '1' then
      v.d.valid := '1';
    end if;

--    if r.d.inull = '1' then
--      v.d.valid := '0';
--    end if;

    if de_nullify = '1' then
      for i in lanes'range loop
        v.a.ctrl(i).valid   := '0';
        v.a.ctrl(i).actual  := '0';
        v.a.ctrl(i).flushed := '1';
      end loop;
      v.d.buff.valid        := '0';
      v.d.valid             := '0';
    end if;

    -- On RAS hit, recently fetched instructions need to be discarded.
    if ras >= 2 and de_raso.hit = '1' then
      v.d.buff.valid      := '0';
      v.d.valid           := '0';
    end if;

    if de_bjump = '1' then
      -- Invalidate d.valid when branch is actually issued
      for i in 0 to 3 - (2 * single_issue) loop
        if de_bjump_pos(i) = '1' then
          for j in lanes'range loop
            if v.a.ctrl(j).valid = '1' and v.a.ctrl(j).pc(2 downto 1) = u2vec(i, 2)
            and v_a_inst_no_buf(j) = '0' and single_issue = 0 then
              v.d.valid := '0';
            end if;
            if single_issue /= 0 then
              if v.a.ctrl(j).valid = '1' and v.a.ctrl(j).pc(1 downto 1) = u2vec(i, 1) and v_a_inst_no_buf(j) = '0' then
                v.d.valid := '0';
              end if;
            end if;
          end loop;
          if v.d.buff.valid = '1' and v.d.buff.pc(2 downto 1) = u2vec(i, 2) and single_issue = 0 then
            v.d.valid := '0';
          end if;
        end if;
      end loop;
      if de_bjump_buff = '1' then
        v.d.valid := '0';
        v.d.buff.valid := '0';
      end if;
      if de_bjump_buff = '0' then
        for i in 0 to 3 - (2 * single_issue) loop
          if de_bjump_pos(i) = '1' then
            if v.d.buff.valid = '1' and v.d.buff.pc(2 downto 1) /= u2vec(i, 2) and single_issue = 0 then
              v.d.buff.valid := '0';
            end if;
            if single_issue /= 0 then
              if v.d.buff.valid = '1' and v.d.buff.pc(1 downto 1) /= u2vec(i, 1) then
                v.d.buff.valid := '0';
              end if;
            end if;
          end if;
        end loop;
      end if;
    end if;

    -- Insert Early Exception ---------------------------------------------
    v.d.cause         := XC_INST_ACCESS_FAULT;
    v.d.tval          := zerox;

    -- Valid Instruction for BTB
    de_btb_valid         := (others => '0');
    if r.f.valid = '1' then
      r_f_pc_21          := r.f.pc(2 downto 1);
      case r_f_pc_21 is
        when "00" =>
          de_btb_valid   := "1111";
        when "01" =>
          de_btb_valid   := "1110";
        when "10" =>
          de_btb_valid   := "1100";
          if single_issue /= 0 then
            de_btb_valid := "1111";
          end if;
        when others =>
          de_btb_valid   := "1000";
          if single_issue /= 0 then
            de_btb_valid := "1110";
          end if;
      end case;
    end if;

    -- From Branch History Table ------------------------------------------
    for i in 0 to 3 loop
      v.d.prediction(i).taken := bhto.taken(i);
    end loop;

    if r.csr.dfeaturesen.staticbp = '1' then
      for i in 0 to 3 loop
        v.d.prediction(i).taken := r.csr.dfeaturesen.staticdir;
      end loop;
    end if;

    -- From Branch Target Buffer ------------------------------------------
    de_hit := '0';
    btb_hitv := btbo.hit and to_bit(r.x.rstate = run);
    v.d.buff.prediction.hit := '0';
    for i in 0 to 3 loop
      v.d.prediction(i).hit := '0';
    end loop;
    if btb_hitv = '1' then
      if (btbo.lpc = "00" or (single_issue /= 0 and btbo.lpc = "10")) and
         v.d.prediction(0).taken = '1' and de_btb_valid(0) = '1' then
        v.d.prediction(0).hit := '1';
        de_hit                := '1';
        if v.d.unaligned = '1' then
          v.d.buff.prediction.hit   := '1';
          v.d.buff.prediction.taken := v.d.prediction(0).taken;
          v.d.prediction(0).hit     := '0';
        end if;
      end if;
      if (btbo.lpc = "01" or (single_issue /= 0 and btbo.lpc = "11")) and
         v.d.prediction(1).taken = '1' and de_btb_valid(1) = '1' then
        v.d.prediction(1).hit := '1';
        de_hit                := '1';
      end if;
      if btbo.lpc = "10" and v.d.prediction(2).taken = '1' and de_btb_valid(2) = '1' and single_issue = 0 then
        v.d.prediction(2).hit := '1';
        de_hit                := '1';
      end if;
      if btbo.lpc = "11" and v.d.prediction(3).taken = '1' and de_btb_valid(3) = '1' and single_issue = 0 then
        v.d.prediction(3).hit := '1';
        de_hit                := '1';
      end if;
    end if;




    -- To PCGEN Stage -----------------------------------------------------
    de_target         := btbo.rdata(de_target'range);

    -- Hold PC State ------------------------------------------------------
    if de_hold_pc = '1' then
      v.d.prediction  := r.d.prediction;
    end if;

    -----------------------------------------------------------------------
    -- PCGEN STAGE*
    -----------------------------------------------------------------------

    -- To Fetch Stage ------------------------------------------------------
    v.f.valid        := '1';

    -- PCGEN Mux -----------------------------------------------------------
    -- Two-level Mux

    -- First Stage:
    -->
    -- 0 -> Debug Request from Exception Stage
    -- 1 -> Flush from Write-back Stage
    -- 2 -> Late Branch from Exception Stage
    -- 3 -> Branch from Execute Stage

    -- Second Stage:
    -- 0 -> Reset
    -- 1 -> Exception from Exception Stage
    -- 2 -> Mux from First Stage
    -- 3 -> Jump from Execute Stage
    -- 4 -> Branch from Execute Stage
    -- 5 -> RAS Hit from Decode Stage
    -- 6 -> Early Jump from Decode Stage
    -- 7 -> Hold PC
    -- 8 -> BTB Hit from Decode Stage
    -- 9 -> Next Pc

    v.f.btb_hit  := '0';
    ras_hit_1st  := '0';
    v.f.ras_hit  := '0';

    -- Hierarchical First Stage
    mux_valid    := '1';
    mux_reread   := '0';
    -- Debug ---------------------------------------------------------------
    if r.x.wfimode = '1' then
      mux_pc     := r.x.wfi_pc;
    elsif dbg_request = '1' then
      mux_pc     := dbg_pc; -- From r.csr.dpc
    -- Fence ---------------------------------------------------------------
    elsif wb_pipeflush = '1' then
      mux_pc     := wb_fence_pc; -- From mux of r.wb.nextpc0
      mux_reread := '1';
    -- Late Branch ---------------------------------------------------------
    elsif wb_branch = '1' then
      mux_pc    := wb_branch_addr; -- From mux based on r.wb.ctrl(branch_lane).branch
    -- Branch --------------------------------------------------------------
    elsif mem_branch = '1' then
      mux_pc    := mem_branch_target; -- From mux based on r.m.ctrl(branch_lane).branch
    else
      mux_valid := '0';
      mux_pc    := PC_ZERO;
    end if;

    -- Hierarchical Second Stage
    -- Exception Reset -----------------------------------------------------
    if xc_rstn = '0' or r.f.valid = '0' then
      v.f.pc     := r.f.pc;
    -- Exception/Interrupt -------------------------------------------------
    elsif x_xc_taken = '1' then
      v.f.pc     := x_xc_tvec; -- From mux of r.csr
    -- First Stage ---------------------------------------------------------
    elsif mux_valid = '1' then
      v.f.pc     := mux_pc; -- From level 1 mux
    -- Control Flow Management ---------------------------------------------
    elsif ex_jump = '1' then
      v.f.pc     := ex_jump_addr; -- From AGU in Execute Stage
    -- RAS -----------------------------------------------------------------
    elsif ras >= 2 and de_raso.hit = '1' then
      v.f.pc      := to_addr(de_raso.rdata); -- Generated in RAS
      ras_hit_1st := '1';
      v.f.ras_hit := ras_hit_1st;
    -- Branch or JAL -----------------------------------------------------------------
    elsif de_bjump = '1' then
      v.f.pc     := de_bjump_addr;
    -- Hold ----------------------------------------------------------------
    -- This is the only difference between v.f.pc and next_pc.
    elsif de_hold_pc = '1' or ic_hold_issue = '1' or ex_hold_pc = '1' then
      v.f.pc     := r.f.pc;
      iustall    := '1';
    -- Branch Target Buffer Output -----------------------------------------
    elsif de_hit = '1' then
      v.f.pc     := de_target;
      v.f.btb_hit := '1';
    -- Incremental PC ------------------------------------------------------
    else
      v.f.pc     := npc(r.f.pc);
    end if;

    -- v.f.pc and next_pc must be decoupled in order to remove de_hold_pc from the
    -- address path.
    reread_pc   := '0';
    if xc_rstn = '0' or r.f.valid = '0' then
      next_pc   := r.f.pc;
      reread_pc := '1';
    -- Exception/Interrupt -------------------------------------------------
    --elsif x_xc_taken = '1' then
    elsif (x_bt_xc_taken or x_ebreak_action0) = '1' then
      next_pc   := x_xc_tvec; -- From mux of r.csr
      reread_pc := '1';
    -- First Stage ---------------------------------------------------------
    elsif mux_valid = '1' then
      next_pc   := mux_pc; -- From level 1 mux
      reread_pc := mux_reread;
    -- Control Flow Management ---------------------------------------------
    elsif ex_jump = '1' then
      next_pc   := ex_jump_addr; -- From AGU in Execute Stage
    -- RAS -----------------------------------------------------------------
    elsif ras >= 2 and de_raso.hit = '1' then
      next_pc   := to_addr(de_raso.rdata); -- Generated in RAS
    -- Early branch or JAL -----------------------------------------------------------------
    elsif de_bjump = '1' then
      next_pc   := de_bjump_addr; -- Generated in Decode Stage
    -- Branch Target Buffer Output -----------------------------------------
    elsif de_hit = '1' then
      next_pc   := de_target;
    -- Incremental PC ------------------------------------------------------
    else
      next_pc   := npc(r.f.pc);
    end if;


    -- To Branch History Table ---------------------------------------------

    bhti_ren_v     := '0';
    if r.m.ctrl(branch_lane).valid = '1' then
      if r.m.ctrl(branch_lane).branch.valid = '1' then
        bhti_ren_v := '1';
      end if;

      if v_fusel_eq(r.m.ctrl(branch_lane).fusel, JAL) and r.csr.dfeaturesen.jprd_dis = '0' then
        bhti_ren_v := '1';
      end if;
    end if;

    bhti_wen_v       := '0';
    bhti_taken_v     := r.wb.ctrl(branch_lane).branch.taken;
    if r.wb.ctrl(branch_lane).valid = '1' then
      if r.wb.ctrl(branch_lane).branch.valid = '1' then
        bhti_wen_v   := '1';
      end if;

      if r.wb.ctrl(branch_lane).valid = '1' and
         v_fusel_eq(r.wb.ctrl(branch_lane).fusel, JAL) and r.csr.dfeaturesen.jprd_dis = '0' then
        bhti_wen_v   := '1';
        bhti_taken_v := '1';
      end if;
    end if;

    if r.csr.dfeaturesen.staticbp = '1' then
      bhti_ren_v     := '0';
      bhti_wen_v     := '0';
    end if;

    if r.wb.rstate /= run then
      bhti_wen_v     := '0';
    end if;


    bhti.bhistory    <= r.wb.bht_bhistory;
    bhti.phistory    <= r.wb.bht_phistory;
    bhti.taken       <= bhti_taken_v;
    bhti.ren         <= bhti_ren_v;

    -- Write next address in case of a branch which wraps a word boundary.
    m_addr       := r.m.ctrl(branch_lane).pc;
    if ext_c = 1 then
      if r.m.ctrl(branch_lane).comp = '0' then
        if (single_issue = 0 and r.m.ctrl(branch_lane).pc(2 downto 1) = "11") or
           (single_issue /= 0 and r.m.ctrl(branch_lane).pc(1) = '1') then
          m_addr := uadd(r.m.ctrl(branch_lane).pc, 2);
        end if;
      end if;
    end if;

--    bhti.raddr_comb  <= pc2xlen(r.m.ctrl(branch_lane).pc);
    bhti.raddr_comb  <= pc2xlen(m_addr);
    bhti.waddr       <= wb_bhti.waddr;
    bhti.wen         <= bhti_wen_v and holdn;
    bhti.flush       <= '0';

    bhti.rindex_bhist <= pc2xlen(next_pc);
    bhti.iustall      <= iustall;

    -- To Branch Target Buffer ---------------------------------------------
    btbi.raddr  <= pc2xlen(r.f.pc);

    -- To ICache -----------------------------------------------------------
    ici.dpc                        <= (others => '0');
    ici.fpc                        <= (others => '0');
    ici.rpc                        <= (others => '0');
    ici.dpc(r.d.pc'high downto 3)  <= r.d.pc(r.d.pc'high downto 3);
    ici.fpc(r.f.pc'high downto 3)  <= r.f.pc(r.f.pc'high downto 3);
    ici.rpc(next_pc'high downto 3) <= next_pc(next_pc'high downto 3);
    ici.nostream                   <= reread_pc or r.csr.dfeaturesen.nostream;

    ici.vms                        <= (v.csr.v and to_bit(ext_h = 1)) &
                                      (v.csr.prv and ('1' & to_bit(mode_s = 1)));

    ici.fbranch <= '0';
    ici.rbranch <= '1';
    ici.su      <= '0';
    -- Unused in LEON5.
    ici.fline   <= (others => '0');
    ici.pnull   <= '0';
    ici.nobpmiss<= '0';
    ici.inull   <= de_inull;
    ici.flush   <= wb_fence_i;
    ici.iustall <= iustall;
    ici.parkreq <= wfi_parkreq;

    -----------------------------------------------------------------------
    -- MISCS
    -----------------------------------------------------------------------

    v.fpo := fpuo;         -- For logging

    -- Instruction Trace --------------------------------------------------

    itrace_in.hartid      := dbgi.hartid;
    itrace_in.info        := itrace_gen(r.csr.mcycle, r.wb);
    itrace_in.holdn       := holdn;
    case r.wb.rstate is
    when run   => itrace_in.rstate := "00";
    when dhalt => itrace_in.rstate := "01";
    when dexec => itrace_in.rstate := "11";
    end case;
    itrace_in.tpbuf_en    := r.csr.dfeaturesen.tpbuf_en;
    itrace_in.dm_tbufaddr := uext(r.dm.tbufaddr, itrace_in.dm_tbufaddr);
    itrace_in.dm_trace    := r.csr.dfeaturesen.dm_trace;
    itrace_in.trace       := r.csr.trace;
    itrace_in.is_ld       := v_fusel_eq(r, wb, memory_lane, LD);
    itrace_in.is_st       := v_fusel_eq(r, wb, memory_lane, ST);
    itrace_in.is_amo      := v_fusel_eq(r, wb, memory_lane, AMO);




    -- E-Trace interface --------------------------------------------------
    etrace_gen(
      holdn => holdn,
      r_wb  => r.wb,
      r_x   => r.x,
      r_csr => r.csr,
      eto   => veto);

    v.evt    := evt_none_type;
    v.cevt   := (others => '0');
    v.evtirq := (others => '0');


    hpmcount        := (others => '0');  -- Ensure this is not considered a latch
    hpmevent_active := false;            -- Ensure this is not considered a latch
    if dmen = 0 or (r.x.rstate /= dhalt and r.x.rstate /= dexec) or r.csr.dcsr.stopcount = '0' then
      -- User Mode Counters -------------------------------------------------
      if r.csr.mcountinhibit(0) = '0' and wb_upd_mcycle = '0' then
        v.csr.mcycle     := uadd(r.csr.mcycle, 1);
      end if;
      if holdn = '1' and rstn = '1' and r.csr.mcountinhibit(2) = '0' and wb_upd_minstret = '0' then
        if single_issue = 0 and
           (v.wb.ctrl(0).valid and v.wb.ctrl(one).valid) = '1' then
          v.csr.minstret := uadd(r.csr.minstret, 2);
        elsif (v.wb.ctrl(0).valid or v.wb.ctrl(one).valid) = '1' then
          v.csr.minstret := uadd(r.csr.minstret, 1);
        end if;
      end if;

      -- Hardware Performance Monitoring ------------------------------------
      if rstn = '1' then
        -- Do not count over the entire range since 0-2 are not used
        -- should save some simulation cycles
        for i in 3 to v.cevt'high loop
          hpmevent_active := false;
          if r.csr.v = '0' then
            if (r.csr.prv = PRIV_LVL_M and r.csr.hpmevent(i).minh = '0') or
               (r.csr.prv = PRIV_LVL_S and r.csr.hpmevent(i).sinh = '0') or
               (r.csr.prv = PRIV_LVL_U and r.csr.hpmevent(i).uinh = '0') then
              hpmevent_active := true;
            end if;
          else
            if (r.csr.prv = PRIV_LVL_S and r.csr.hpmevent(i).vsinh = '0') or
               (r.csr.prv = PRIV_LVL_U and r.csr.hpmevent(i).vuinh = '0') then
              hpmevent_active := true;
            end if;
          end if;
          -- Multiplex selected event
          if ext_sscofpmf = 0 or hpmevent_active then
            v.cevt(i) := filter_hpmevent(r.csr.hpmevent(i), r.evt, i);
          end if;
          -- The wb_upd_counter signal is set to 1 when the counter is written in the X stage.
          -- However, the delay between an event and updating the hpmcounter CSR is 3 cycles.
          -- The CSR write can't update the modified counter after writting the value in the X
          -- stage. The worst case scenario is an event that it is recorded in the WB stage.
          -- In that case r.evt is updated after the WB stage and it takes one cycle to update
          -- r.cevt and anotherone to update the hpmcounter. Therefore we need to prevent any
          -- hpmcounter write from updating the hpcounter it is setting by clearing its r.cevt
          -- register.
          v.wb.upd_counter(1)(i) := r.wb.upd_counter(0)(i);
          v.wb.upd_counter(0)(i) := wb_upd_counter(i);
          if (r.wb.upd_counter(1)(i) or r.wb.upd_counter(0)(i) or wb_upd_counter(i)) = '1' then
            v.cevt(i) := '0';
          end if;
          if r.cevt(i) = '1' and r.csr.mcountinhibit(i) = '0' and wb_upd_counter(i) = '0' then
            -- Take care of counter overflow for Sscofpmf.
            hpmcount := uaddx(r.csr.hpmcounter(i)(perf_bits - 1 downto 0), 1);
            if ext_sscofpmf /= 0 and get_hi(hpmcount) = '1' then
              -- IRQ enabled (and not already pending)?
              if r.csr.hpmevent(i).overflow = '0' then
                v.evtirq(i)              := '1';
              end if;
              v.csr.hpmevent(i).overflow := '1';
            end if;
            v.csr.hpmcounter(i) := to64(get_lo(hpmcount, perf_bits));
          end if;
        end loop;
      end if;
    end if;


    -- Update FPU flags ---------------------------------------------------
    -- FPU flags can be written at "random" times.
    -- Not a problem as long as they are not read when the FPU is still working
    -- on previous instructions, and has not finished any later ones.
    if ext_f = 1 and fpuo.flags_wen = '1' then
      v.csr.fflags := v.csr.fflags or fpuo.flags;
    end if;
    if ext_f = 1 and r.wb.ctrl(fpu_lane).valid = '1' and
       is_fpu(r.wb.ctrl(fpu_lane).inst) then
      v.csr.fflags := v.csr.fflags or r.wb.fpuflags;
    end if;

    -- Any FPU instruction that commits and has an FPU register destination
    -- must mark the FPU registers as dirty.
    -- It is not a problem if the operation actually completes later.
    if (
        (r.x.ctrl(fpu_lane).valid = '1') and
        is_fpu_modify(r.x.ctrl(fpu_lane).inst) and
        (x_xc_flush(fpu_lane) or x_flush) = '0'
       ) or
       (
        (r.x.ctrl(memory_lane).valid = '1') and
        is_fpu_modify(r.x.ctrl(memory_lane).inst) and
        (x_xc_flush(memory_lane) or x_flush) = '0'
       ) then
      v.csr.mstatus.fs    := "11";
      if r.csr.v = '1' then
        v.csr.vsstatus.fs := "11";
      end if;
    end if;
    -- Force always dirty?
    if v.csr.dfeaturesen.fs_dirty = '1' then
      if v.csr.mstatus.fs /= "00" then
        v.csr.mstatus.fs  := "11";
      end if;
      if v.csr.vsstatus.fs /= "00" then
        v.csr.vsstatus.fs := "11";
      end if;
    end if;

    if holdn = '0' then
      -- Things that update during hold.
      v.evt(PIPELINE_EV_0)(CSR_HPM_HOLD)            := '1';
    else
      v.evt(PIPELINE_EV_0)(CSR_HPM_DUAL_ISSUE)      := to_bit(single_issue = 0) and r.wb.ctrl(0).valid and r.wb.ctrl(one).valid;
      v.evt(PIPELINE_EV_0)(CSR_HPM_SINGLE_ISSUE)    := r.wb.ctrl(0).valid xor (to_bit(single_issue = 0) and r.wb.ctrl(one).valid);
      v.evt(PIPELINE_EV_0)(CSR_HPM_BTB_HIT)         := r.f.btb_hit;
      v.evt(PIPELINE_EV_0)(CSR_HPM_BRANCH_MISS)     := (mem_branch or wb_branch);
      v.evt(PIPELINE_EV_0)(CSR_HPM_HOLD_ISSUE)      := de_hold_pc and not to_bit(dmen = 1 and r.x.rstate = dhalt);
      v.evt(PIPELINE_EV_0)(CSR_HPM_BRANCH)          := to_bit(v_fusel_eq(r, wb, branch_lane, BRANCH));
      v.evt(PIPELINE_EV_0)(CSR_HPM_LOAD_DEP)        := ic_lddp;
      v.evt(PIPELINE_EV_0)(CSR_HPM_STORE_B2B)       := ic_stb2b;
      v.evt(PIPELINE_EV_0)(CSR_HPM_JALR)            := to_bit(v_fusel_eq(r, wb, branch_lane, JALR));
      v.evt(PIPELINE_EV_0)(CSR_HPM_JAL)             := to_bit(v_fusel_eq(r, wb, branch_lane, JAL));
      v.evt(PIPELINE_EV_0)(CSR_HPM_RAS_HIT)         := r.f.ras_hit;
      v.evt(PIPELINE_EV_0)(CSR_HPM_IDLE_CYCLES_FRONTEND)  := v.evt(PIPELINE_EV_0)(CSR_HPM_HOLD) and not v.evt(PIPELINE_EV_0)(CSR_HPM_HOLD_ISSUE);
      v.evt(PIPELINE_EV_0)(CSR_HPM_IDLE_CYCLES_BACKEND)   := v.evt(PIPELINE_EV_0)(CSR_HPM_HOLD_ISSUE);
    end if;
    v.evt(PIPELINE_EV_0)(CSR_HPM_CPU_CYCLES)  := '1';
    v.evt(CACHETLB_EV_0)(CSR_HPM_ICACHE_MISS)       := perf(0);
    v.evt(CACHETLB_EV_0)(CSR_HPM_ITLB_MISS)         := perf(1);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DCACHE_MISS)       := perf(2);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DTLB_MISS)         := perf(3);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DCACHE_FLUSH)      := perf(4);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DCACHE_ACCESS)     := perf(7);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DCACHE_LOAD)       := perf(6);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DCACHE_STORE)      := perf(9);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DCACHE_LOAD_HIT)   := perf(5);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DCACHE_STORE_HIT)  := perf(8);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DCACHE_STBUF_FULL) := perf(10);
    v.evt(CACHETLB_EV_0)(CSR_HPM_HTLB_MISS)         := perf(11);
    v.evt(CACHETLB_EV_0)(CSR_HPM_ICACHE_STREAM)     := perf(12);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DTLB_ENTRY_FLUSH)  := perf(13);
    v.evt(CACHETLB_EV_0)(CSR_HPM_ITLB_ENTRY_FLUSH)  := perf(14);
    v.evt(CACHETLB_EV_0)(CSR_HPM_HTLB_ENTRY_FLUSH)  := perf(15);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DCACHE_LOAD_MISS)  := v.evt(PIPELINE_EV_0)(CSR_HPM_DCACHE_MISS) and v.evt(PIPELINE_EV_0)(CSR_HPM_DCACHE_LOAD);
    v.evt(CACHETLB_EV_0)(CSR_HPM_DCACHE_STORE_MISS) := v.evt(PIPELINE_EV_0)(CSR_HPM_DCACHE_STORE) and v.evt(PIPELINE_EV_0)(CSR_HPM_DCACHE_MISS);
    --v.evt(CACHETLB_EV_0)(CSR_HPM_ICACHE_ACCESS)  :=
    v.evt(DBG_EV)                                   := u2vec(16#0000ffff#,MHPEVENT_EC);
    -- FPU events moved after SBI to avoid forwarding fpevt_t'length
    v.evt(FPU_EV_0)(CSR_HPM_FPU_LOW + fpevt_t'length - 1 downto CSR_HPM_FPU_LOW) := fpuo.events(fpevt_t'length - 1 downto 0);
    -- Fill unused events
    --v.evt(CSR_HPM_FPU_LOW + fpevt_t'length to v.evt'high) := (others => '0');

    -- holdn is handled explicitly in the seq process
    v.wb.icnt          := (others => '0');
    for i in lanes'range loop
      if r.wb.ctrl(i).valid = '1' and r.wb.ctrl(i).xc = '0' then
        if holdn = '1' then
          v.wb.icnt(i) := '1';
        end if;
      end if;
    end loop;




    -----------------------------------------------------------------------
    -- STALLS
    -----------------------------------------------------------------------

    s_inst      := v.d.inst;
    s_way       := v.d.way;
    s_mexc      := v.d.mexc;
    s_exctype   := v.d.exctype;
    s_exchyper  := v.d.exchyper;
    s_tval2     := v.d.tval2;
    s_tval2type := v.d.tval2type;
    s_fpu_wait  := v.e.fpu_wait;

    -- Bubble after A stage if instruction control says so.
    if ic_hold_issue = '1' and ra_flush = '0' then
      -- Stall stages
      v.f := r.f;
      v.d := r.d;
      v.a := r.a;
      -- Bubbles in Execute Stage
      for i in lanes'range loop
        v.e.ctrl(i).valid := '0';
      end loop;
      -- Mask Memory barrier
      v.e.bar           := (others => '0');
      -- Mask RAS flags
      v.e.rasi.pop      := '0';
      v.e.rasi.push     := '0';
      -- We still need to keep strobed instruction data!
      if holdn = '0' and ico.mds = '0' then
        v.d.inst        := s_inst;
        v.d.way         := s_way;
        v.d.mexc        := s_mexc;
        v.d.exctype     := s_exctype;
        v.d.exchyper    := s_exchyper;
        v.d.tval2       := s_tval2;
        v.d.tval2type   := s_tval2type;
        if r.d.unaligned = '1' and r.d.buff.valid = '1' then
          v.d.buff.inst.d(31 downto 16) := v.d.inst(0)(15 downto 0);
        end if;
      end if;
    end if;

    -- Bubble after EX stage for mul/div.
    v.e.was_held := '0';
    if ex_hold_pc = '1' and ex_flush = '0' then
      -- Stall stages
      v.f := r.f;
      v.d := r.d;
      v.a := r.a;
      v.e := r.e;
      -- Invalidate Memory Next Instruction and triggers
      for i in lanes'range loop
        v.m.ctrl(i).valid   := '0';
        v.m.trig.valid(i)   := '0';
        v.m.trig.nullify(i) := '0';
      end loop;
      -- Mark hold so that we do not update stored forwarding.
      v.e.was_held := '1';
      -- Mask RAS flags
      v.m.rasi.pop      := '0';
      v.m.rasi.push     := '0';
      -- Keep FPU wait information
      v.e.fpu_wait      := s_fpu_wait;
      -- We still need to keep strobed instruction data!
      if holdn = '0' and ico.mds = '0' then
        v.d.inst        := s_inst;
        v.d.way         := s_way;
        v.d.mexc        := s_mexc;
        v.d.exctype     := s_exctype;
        v.d.exchyper    := s_exchyper;
        v.d.tval2       := s_tval2;
        v.d.tval2type   := s_tval2type;
        if r.d.unaligned = '1' and r.d.buff.valid = '1' then
          v.d.buff.inst.d(31 downto 16) := v.d.inst(0)(15 downto 0);
        end if;
      end if;
    end if;

    bjump_pregen(v.d.inst(0), v.d.buff, v.d.bjump_pre, v.d.jump_pre);

    -----------------------------------------------------------------------
    -- Pipeline some signals towards MMU/cache control to improve timing
    -----------------------------------------------------------------------

    -- There is an IU pipeline flush on writes to these CSRs, so no harm is done.
    v.mmu                := nv_csr_out_type_none;
    -- Writes to these (in the exception stage) will cause a pipeline flush
    -- in the writeback stage, so there is time to register the data once
    -- before it is required.
    v.mmu.satp           := r.csr.satp;
    v.mmu.vsatp          := r.csr.vsatp;
    v.mmu.hgatp          := r.csr.hgatp;
    v.mmu.m_adue         := r.csr.menvcfg.adue;
    v.mmu.vs_adue        := r.csr.henvcfg.adue;
    v.mmu.h_ade          := r.csr.dfeaturesen.h_ade;
    v.mmu.pma_fault_02   := r.csr.dfeaturesen.pma_fault_02;
    v.mmu.pma_fault_46   := r.csr.dfeaturesen.pma_fault_46;
    v.mmu.mmu_sptfault   := r.csr.dfeaturesen.mmu_sptfault;
    v.mmu.mmu_hptfault   := r.csr.dfeaturesen.mmu_hptfault;
    v.mmu.mmu_oldfence   := r.csr.dfeaturesen.mmu_oldfence;
    -- These only flush when lock bits are set, but they also do not affect
    -- anything otherwise (machine mode vs others), so pipelining is OK.
    v.mmu.pmpcfg         := r.csr.pmpcfg;
    v.mmu.mmwp           := r.csr.mseccfg.mmwp;
    v.mmu.mml            := r.csr.mseccfg.mml;
    v.mmu.menvcfg_sse    := r.csr.menvcfg.sse;
    v.mmu.henvcfg_sse    := r.csr.henvcfg.sse;


    -----------------------------------------------------------------------
    -- Precheck forwarding one cycle early
    -----------------------------------------------------------------------

    -- Revert back to old code (to synthesize with Synplify).
    if not OLD_RD_VS_RS then
      for lane in lanes'range loop
        v.x.ctrl(lane).rd_vs_rs := check_forwarding(v, x, lane);
        v.m.ctrl(lane).rd_vs_rs := check_forwarding(v, m, lane);
        v.e.ctrl(lane).rd_vs_rs := check_forwarding(v, e, lane);
        v.a.ctrl(lane).rd_vs_rs := check_forwarding(v, a, lane);
      end loop;
    end if;

    if csr_ok(r, m) and is_csr_access(r, m) then
      assert not (r.m.ctrl(csr_lane).xc = '1' and
                  not (r.m.ctrl(csr_lane).cause /= XC_INST_VIRTUAL_INST or
                       r.m.ctrl(csr_lane).cause /= XC_INST_ILLEGAL_INST))
        report "Broken assumption about what causes the csr xc logic can throw" severity failure;
      -- Decide on flush one cycle early for the simple cases.
      csr_write_flush(csr_addr(r, m), active_extensions, v.x.csrpipeflush, v.x.csraddrflush);
    else
      v.x.csrpipeflush := '0';
      v.x.csraddrflush := '0';
    end if;

    -- Revert back to old code (to synthesize with Synplify).
    if not NO_PREFORWARD then
      if late_alu = 1 or late_branch = 1 then
        for i in lanes'range loop
          xc_alu_preforward(v, x, wb, i, v.x.alupreforw1(i), v.x.alupreforw2(i));
        end loop;
      else
        xc_csr_preforward(v, csr_lane, v.x.alupreforw1(csr_lane));
      end if;
      xc_popchk_preforward(v, x, wb, v.x.popchkpreforw);
      for i in lanes'range loop
        ex_alu_preforward(v, e, x, i, v.e.aluforw(i), v.e.alupreforw1(i), v.e.alupreforw2(i));
      end loop;
    end if;


    -- CSR address going to RA same as one earlier one in pipeline?
    -- Related to CSR write hold checks in access stage
    v.a.csrw_eq        := (others => '0');
    if csr_addr(v, a) = csr_addr(r, a) then
      if csr_ok(r, a) then
        v.a.csrw_eq(0) := '1';
      end if;
    end if;
    if csr_addr(v, a) = csr_addr(r, e) then
      if csr_ok(r, e) then
        v.a.csrw_eq(1) := '1';
      end if;
    end if;
    if csr_addr(v, a) = csr_addr(r, m) then
      if csr_ok(r, m) then
        v.a.csrw_eq(2) := '1';
      end if;
    end if;
    if csr_addr(v, a) = csr_addr(r, x) then
      if csr_ok(r, x) then
        v.a.csrw_eq(3) := '1';
      end if;
    end if;


    if ext_f = 1 then
      v.fpflush(1) := '0';
--      v.fpflush(2) := to_bit(is_valid_fpu(r, e)) and (ex_flush or ex_fpu_flush);
--      v.fpflush(3) := to_bit(is_valid_fpu(r, m)) and (me_flush or me_fpu_flush);
      -- The name of me_fpu_flush is bad!
      v.fpflush(2) := to_bit(is_valid_fpu(r, e)) and (ex_flush or ex_fpu_flush or me_fpu_flush);
      v.fpflush(3) := to_bit(is_valid_fpu(r, m)) and (me_flush);
      v.fpflush(4) := to_bit(is_valid_fpu(r, x)) and (x_xc_flush(fpu_lane) or x_flush or x_fpu_flush);
      if holdn = '0' then
        v.fpflush  := (others => '0');
      end if;
      if v.fpflush(2) = '1' then
        v.m.ctrl(fpu_lane).fpu_flush  := '1';
      end if;
      if v.fpflush(3) = '1' then
        v.x.ctrl(fpu_lane).fpu_flush  := '1';
      end if;
      if v.fpflush(4) = '1' then
        v.wb.ctrl(fpu_lane).fpu_flush := '1';
      end if;
    end if;

    -- To avoid UNOPTFLAT in Verilator
    v.dbgi_dsuen := dbgi.dsuen;

    -- Constant registers -------------------------------------------------

    -- Ensure constant values when extensions etc are not enabled.
    tie_csrs(active_extensions, pmp_entries, pma_entries, pma_masked, perf_cnts, perf_bits, mmuen, v.csr);

    -- No NOEL-V extensions (not necessarily only ext_noelv)
    if non_standard = '0' then
      v.csr.misa(x_ctrl) := '0';
    end if;

    -- Forced disabling of NOEL-V extensions (not necessarily only ext_noelv)?
    -- (It will not be possible to turn them back on without reset,
    --  since access to csr.features will no longer be available.)
    if non_standard = '1' and r.csr.dfeaturesen.x0 = '1' then
      v.csr.misa(x_ctrl) := '0';
    end if;


    -- Does a lock bit force "Rule Locking Bypass" to stay deasserted?
    if (ext_smepmp = 1
        ) and r.csr.mseccfg.rlb = '0' then
      for i in 0 to pmp_entries - 1 loop
        if pmpcfg(pmp_entries, r.csr.pmpcfg, i, 7) = '1' then
          v.csr.mseccfg.rlb := '0';
        end if;
      end loop;
    end if;

    -- Once enabled, "Machine Mode Whitelist Policy" and
    --               "Machine Mode Lockdown" cannot be disabled.
    if ext_smepmp = 1 then
      if r.csr.mseccfg.mmwp = '1' then
        v.csr.mseccfg.mmwp := '1';
      end if;
      if r.csr.mseccfg.mml = '1' then
        v.csr.mseccfg.mml  := '1';
      end if;
    end if;

    -- H-extension not implemented?
    if ext_h = 0 then
      v.mmu.vsatp       := atp_none;
      v.mmu.hgatp       := atp_none;
    end if;

    -- S-mode not implemented?
    if mode_s = 0 then
      v.mmu.satp          := atp_none;
      v.mmu.mmu_sptfault  := '0';
      v.mmu.mmu_hptfault  := '0';
    end if;

    -- No Svadu extension
    if ext_svadu = 0 then
      v.csr.menvcfg.adue := '0';
      v.csr.henvcfg.adue := '0';
      v.mmu.m_adue       := '0';
      v.mmu.vs_adue      := '0';
      v.mmu.h_ade        := '0';
    end if;

    -- No MMU (normally also no S-mode, but just in case)?
    if mmuen = 0 then
      v.mmu.satp          := atp_none;
      v.mmu.mmu_sptfault  := '0';
      v.mmu.mmu_hptfault  := '0';
    end if;
    -- U-mode not implemented
    if mode_u = 0 then
      v.csr.mstatus.uxl := "00";
      v.csr.mstatus.mprv:= '0';
      v.csr.mstatus.tw  := '0';
      v.csr.scounteren  := (others => '0');
    end if;
    -- S-mode or N-extension not implemented
    if mode_s = 0
      then
      v.csr.mideleg     := (others => '0');
      v.csr.medeleg     := (others => '0');
    end if;
    -- No Sscofpmf?
    if ext_sscofpmf = 0 then
      v.csr.mip(IRQ_LCOF)     := '0';
      v.csr.mie(IRQ_LCOF)     := '0';
      v.csr.mideleg(IRQ_LCOF) := '0';
    end if;
    if ext_shlcofideleg = 0 then
      v.csr.hideleg(IRQ_LCOF) := '0';
    end if;
    if (ext_f + ext_d + ext_q) = 0 then
      v.csr.mstatus.fs  := "00";
      v.csr.vsstatus.fs := "00";
    end if;
    -- No Sstc extension
    if ext_sstc /= 1 then
      v.csr.stimecmp    := (others => '0');
      v.csr.vstimecmp   := (others => '0');
    end if;
    -- No Zicfilp extension
    if ext_zicfilp /= 1 then
      v.csr.elp             := '0';
      v.csr.mstatus.mpelp   := '0';
      v.csr.mstatus.spelp   := '0';
      v.csr.vsstatus.spelp  := '0';
      v.csr.mnstatus.mnpelp := '0';
      v.csr.dcsr.pelp       := '0';
      v.csr.mseccfg.mlpe    := '0';
      v.csr.menvcfg.lpe     := '0';
      v.csr.henvcfg.lpe     := '0';
      v.csr.senvcfg.lpe     := '0';
    end if;
    -- No Smcdeleg extension
    if ext_smcdeleg /= 1 then
      v.csr.menvcfg.cde     := '0';
    end if;
    -- PMP not implemented
    if pmp_entries = 0 then
      v.csr.mseccfg.rlb  := '0';
      v.csr.mseccfg.mml  := '0';
      v.csr.mseccfg.mmwp := '0';
      v.mmu.mmwp        := '0';
      v.mmu.mml         := '0';
    end if;
    -- Clear unused PMP entries
    if pmp_entries < PMPENTRIES then
      v.csr.pmpcfg(pmp_entries to PMPENTRIES - 1)      := (others => (others => '0'));
      v.mmu.pmpcfg(pmp_entries to PMPENTRIES - 1)      := (others => (others => '0'));
      v.csr.pmpaddr(pmp_entries to PMPENTRIES - 1)     := (others => pmpaddrzero);
      v.csr.pmp_precalc(pmp_entries to PMPENTRIES - 1) := (others => pmp_precalc_none);
    end if;
    -- Clear unused PMA entries
    if pma_entries < PMAENTRIES then
      v.csr.pma_addr(pma_entries to PMAENTRIES - 1)     := (others => (others => '0'));
      v.csr.pma_data(pma_entries to PMAENTRIES - 1)     := (others => (others => '0'));
      v.csr.pma_precalc(pma_entries to PMAENTRIES - 1)  := (others => pmp_precalc_none);
    end if;
    if pma_masked /= 0 then
      v.csr.pma_addr(0 to PMAENTRIES - 1)               := (others => (others => '0'));
      v.csr.pma_precalc(0 to PMAENTRIES - 1)            := (others => pmp_precalc_none);
    end if;

    -- Clear non-existing performance counters
    -- Should not be needed, but makes things clearer.
    for i in 0 to 2 loop
      v.cevt(i)              := '0';
      v.evtirq(i)            := '0';
    end loop;



    -- Trace Code ----------------------------------------------------
    if v_fusel_eq(r, m, memory_lane, ST) then
      v.x.result(memory_lane)     := me_stdata(wordx'range);
      v.x.fsd_hi                  := get_hi(me_stdata, 32);
      if r.m.dci.size = SZWORD then
        -- We can only be here if XLEN = 64 (FPU data comes another way).
        v.x.fsd_hi                  := zerow;
        v.x.result(memory_lane)   := to0x(me_stdata(31 downto 0));
      elsif r.m.dci.size = SZHALF then
        v.x.fsd_hi                  := zerow;
        v.x.result(memory_lane)   := to0x(me_stdata(15 downto 0));
      elsif r.m.dci.size = SZBYTE then
        v.x.fsd_hi                  := zerow;
        v.x.result(memory_lane)   := to0x(me_stdata( 7 downto 0));
      end if;
    end if;

    -- Only for trace
    v.x.wcsr                      := zerox;
    if v_fusel_eq(r, m, memory_lane, LD or ST) or is_cbo(r.m.ctrl(memory_lane).inst) then
      v.x.wcsr := r.m.address_full;
    end if;
    v.wb.fsd_hi                   := r.x.fsd_hi;


    -- To the FPU ---------------------------------------------------------
    v.e.fpu_valid          := to_bit(is_valid_fpu(v, e));
    v.x.data_valid_fpu     := to_bit(is_valid_fpu(v, x) and is_fpu_from_int(v.x.ctrl(fpu_lane).inst));
    v.wb.commit_fpu        := to_bit(is_valid_fpu(v, wb) and is_fpu_rd(v.wb.ctrl(fpu_lane).inst));
    -----------------------------------------------------------------------
    -- OUTPUTS
    -----------------------------------------------------------------------

    rin                 <= v;

    -- To the Register File -----------------------------------------------
    rfi.raddr1          <= rfi_raddr12(0);
    rfi.raddr3          <= rfi_raddr34(0);
    rfi.ren1            <= rfi_ren12(0);
    rfi.ren3            <= rfi_ren34(0);
    rfi.waddr1          <= rfi_waddr12(0);
    rfi.wdata1          <= rfi_wdata12(0);
    rfi.wen1            <= rfi_wen12(0);
    rfi.rdhold          <= rfi_rdhold;
    if single_issue = 0 then
      rfi.raddr2        <= rfi_raddr12(one);
      rfi.raddr4        <= rfi_raddr34(one);
      rfi.ren2          <= rfi_ren12(one);
      rfi.ren4          <= rfi_ren34(one);
      rfi.waddr2        <= rfi_waddr12(one);
      rfi.wdata2        <= rfi_wdata12(one);
      rfi.wen2          <= rfi_wen12(one);
    else
      rfi.raddr2        <= (others => '0');
      rfi.raddr4        <= (others => '0');
      rfi.ren2          <= '0';
      rfi.ren4          <= '0';
      rfi.waddr2        <= (others => '0');
      rfi.wdata2        <= (others => '0');
      rfi.wen2          <= '0';
    end if;

    rasi                <= nv_ras_in_none;
    if ras >= 1 then
      -- To Return Address Stack --------------------------------------------
      rasi.push         <= vrasi.push  and holdn and not r.csr.dfeaturesen.ras_dis;
      rasi.pop          <= vrasi.pop   and holdn and not r.csr.dfeaturesen.ras_dis;
      rasi.flush        <= vrasi.flush and holdn and not r.csr.dfeaturesen.ras_dis;
      rasi.wdata        <= vrasi.wdata;
    end if;

    -- To the clock gating module -----------------------------------------
    pwrd                <= pwrdmode;

    -- To the Instruction Trace Buffer ------------------------------------
    itracei             <= itrace_in;

    -- E-trace interface --------------------------------------------------
    eto                 <= veto;

    -- Performance counters
    cnt.icnt     <= r.wb.icnt;
    -- Branch prediction miss
    cnt.bpmiss   <= r.evt(PIPELINE_EV_0)(CSR_HPM_BRANCH_MISS);
    -- Branch instruction
    cnt.branch   <= r.evt(PIPELINE_EV_0)(CSR_HPM_BRANCH);
    -- Hold issue
    cnt.hold_issue <= r.evt(PIPELINE_EV_0)(CSR_HPM_HOLD_ISSUE);
    -- Hold
    cnt.hold <= r.evt(PIPELINE_EV_0)(CSR_HPM_HOLD);
    -- Not assigned here
    cnt.icmiss   <= '0';
    cnt.itlbmiss <= '0';
    cnt.dcmiss   <= '0';
    cnt.dtlbmiss <= '0';



    -- To the Interrupt Bus -----------------------------------------------
    irqo.irqack         <= '0';

    -- To the Debug Module ------------------------------------------------
    dbgo                <= nv_debug_out_none;
    if dmen = 1 then
      dbgo.dsu          <= '1';
      dbgo.halted       <= dbg_halted;
      dbgo.running      <= dbg_running;
      dbgo.havereset    <= r.dm.havereset(0);
      dbgo.dvalid       <= dbg_dvalid;
      dbgo.ddata        <= dbg_ddata;
      dbgo.derr         <= dbg_derr;
      dbgo.dexec_done   <= dbg_dexec_done;
      dbgo.stoptime     <= dbg_stoptime;
      dbgo.pbaddr       <= r.f.pc(6 downto 2);
      dbgo.mcycle       <= r.csr.mcycle(63 downto 0);
    else
      dbgo              <= nv_debug_out_none;
      dbgo.mcycle       <= r.csr.mcycle(63 downto 0);
      if (r.x.rstate = run)                                    and
         (r.csr.prv = PRIV_LVL_M and r.csr.dcsr.ebreakm = '0') and
         (x_xc_taken = '1' and x_xc_taken_cause = XC_INST_BREAKPOINT) then
        dbgo.error      <= '1';
      end if;
    end if;
    dbgo.cap   <= cap;
    if r.x.crit_err = '1' then
    -- Signal critical from smdbltrp extension even
    -- if debug mode is not enabled
      dbgo.error        <= '1';
    end if;


    -- To IMSIC -----------------------------------------------------------
    vimsici.mtopei_w   := vimsici.mtopei_w and holdn;
    vimsici.mireg_w    := vimsici.mireg_w and holdn;
    vimsici.miselect   := selector2wordx(r.csr.miselect);

    vimsici.stopei_w   := vimsici.stopei_w and holdn;
    vimsici.sireg_w    := vimsici.sireg_w and holdn;
    vimsici.siselect   := selector2wordx(r.csr.siselect);

    vimsici.vstopei_w  := vimsici.vstopei_w and holdn;
    vimsici.vsireg_w   := vimsici.vsireg_w and holdn;
    vimsici.vsiselect  := selector2wordx(r.csr.vsiselect);

    vimsici.vgein      := r.csr.hstatus.vgein;

    imsici             <= vimsici;


    -- To the Mul/Div Unit ------------------------------------------------
    if ext_m = 1 then
      -- Mul
      muli.ctrl         <= ex_mul_ctrl;
      muli.op1          <= ex_mul_op1;
      muli.op2          <= ex_mul_op2;
      muli.flush        <= not ex_mul_valid or ex_mul_op or r.wb.flushall;
      muli.mac          <= '0';
      muli.acc          <= '0';
      -- Div
      divi.flush        <= not ex_mul_valid or not ex_mul_op or r.wb.flushall;
      divi.ctrl         <= ex_mul_ctrl;
      divi.op1          <= ex_mul_op1;
      divi.op2          <= ex_mul_op2;
    else
      muli              <= mul_in_none;
      divi              <= div_in_none;
    end if;


    -- To the FPU ---------------------------------------------------------

    vfpui                  := fpu5_in_none;
    vfpuia                 := fpu5_in_async_none;
    if ext_f = 1 then
      -- From Execute Stage
      fpu_ctrl             := r.e.ctrl(fpu_lane);
      vfpui.inst           := fpu_ctrl.inst;
      vfpui.e_valid        := r.e.fpu_valid;
      vfpui.issue_id       := fpu_ctrl.fpu;
      vfpui.csrfrm         := r.csr.frm;
      vfpui.mode           := r.csr.v & r.csr.prv;
      -- Nullifying on issue is not really necessary.
      -- Removing it simplifies logic.
      vfpuia.e_nullify     := '0';

      -- From Exception Stage
      fpu_ctrl           := r.x.ctrl(fpu_lane);
      vfpui.data_id      := fpu_ctrl.fpu;
      vfpuia.data         := r.x.rdata;   -- Assume load
      -- Floating point and not load?
      -- Mux after clock!
      if opcode(fpu_ctrl.inst) = OP_FP then
--        vfpui.data       := to64(x_alu_op1(fpu_lane));
        vfpuia.data      := to64(x_alu_op1(fpu_lane));
        -- FMVP.D.X
        if ext_zfa = 1 and is_rv32 and funct7(fpu_ctrl.inst) = R_FMVP_D_X and
           funct3(fpu_ctrl.inst) = "000" then
--          set_hi(vfpui.data, x_alu_op2(fpu_lane));
          set_hi(vfpuia.data, x_alu_op2(fpu_lane));
        -- FLI.S/D/H
        elsif ext_zfa = 1 and funct5(fpu_ctrl.inst) = R_FMV_W_X and
              rs2(fpu_ctrl.inst) = "00001" and funct3(fpu_ctrl.inst) = "000" then
--          vfpui.data     := r.x.fpu_imm;
          vfpuia.data    := r.x.fpu_imm;
        end if;
      end if;
      vfpui.data_valid   := r.x.data_valid_fpu;

      -- Flush in various stages
      -- Every FPU operation must be flushed or committed.
      -- These are mostly the same as the masking of valid flags from one
      -- stage to the next.
      -- Note the addition of the *_fpu_flush, which are needed to deal with
      -- the situation where the latter half of a pair is flushed.
      vfpui.flush(1)    := r.fpflush(1);
      vfpui.flush(2)    := r.fpflush(2);
      vfpui.flush(3)    := r.fpflush(3);
      vfpui.flush(4)    := r.fpflush(4);

      -- Commit / unissue
      fpu_ctrl          := r.wb.ctrl(fpu_lane);
      vfpui.commit      := r.wb.commit_fpu;  -- FPU checks holdn
      vfpui.commit_id   := fpu_ctrl.fpu;
--      vfpui.unissue     := holdn and fpu_ctrl.fpu_flush and to_bit(is_fpu_rd(fpu_ctrl.inst));
      vfpui.unissue     := fpu_ctrl.fpu_flush;  -- FPU checks holdn
      vfpui.unissue_id  := fpu_ctrl.fpu;
      if fpu_debug /= 0 then
        vfpui.ctrl      := r.csr.fctrl;
      end if;
    end if;
    fpui                <= vfpui;
    fpuia               <= vfpuia;




  end process;

  syncrregs : if not ASYNC_RESET generate

    -- Sync Reg Process ---------------------------------------------------
    sync_reg : process (clk)
    begin
      if rising_edge(clk) then
        if holdn = '1' then
          r                <= rin;
        else
          -- Some things need to be updated even during hold.
          r.fpflush        <= rin.fpflush;
          r.dm.havereset   <= rin.dm.havereset;
          r.csr.mcycle     <= rin.csr.mcycle;
          r.evt            <= rin.evt;
          r.cevt           <= rin.cevt;
          r.evtirq         <= rin.evtirq;
          r.csr.mip(IRQ_LCOF)
                           <= rin.csr.mip(IRQ_LCOF);
          r.csr.mip(IRQ_S_SOFTWARE)
                           <= rin.csr.mip(IRQ_S_SOFTWARE);
          r.csr.hpmcounter <= rin.csr.hpmcounter;
          r.x.wfimode      <= rin.x.wfimode;
          r.x.wfi_irqpend  <= rin.x.wfi_irqpend;
          r.x.pwrdmode     <= rin.x.pwrdmode;
          for i in 3 to r.cevt'high loop
            r.csr.hpmevent(i).overflow <= rin.csr.hpmevent(i).overflow;
          end loop;
          r.csr.fflags     <= rin.csr.fflags;
          -- Must note if FPU result is awaited
          r.e.fpu_wait     <= rin.e.fpu_wait;
          -- FPU result
          r.fpo            <= rin.fpo;

          r.dbgi_dsuen     <= rin.dbgi_dsuen;


          -- I Cache Miss
          if ico.mds = '0' then
            r.d.inst       <= rin.d.inst;
            r.d.bjump_pre  <= rin.d.bjump_pre;
            r.d.jump_pre   <= rin.d.jump_pre;
            if r.d.unaligned = '1' and r.d.buff.valid = '1' then
              r.d.buff.inst.d(31 downto 16) <= rin.d.buff.inst.d(31 downto 16);
            end if;
            r.d.mexc       <= rin.d.mexc;
            r.d.exctype    <= rin.d.exctype;
            r.d.exchyper   <= rin.d.exchyper;
            r.d.tval2      <= rin.d.tval2;
            r.d.tval2type  <= rin.d.tval2type;
            r.d.way        <= rin.d.way;
          end if;
          -- D Cache Miss
          if dco.mds = '0' then
            r.x.rdata      <= rin.x.rdata;
            r.x.wdata      <= rin.x.wdata;
            r.x.mexc       <= rin.x.mexc;
            r.x.exctype    <= rin.x.exctype;
            r.x.exchyper   <= rin.x.exchyper;
            r.x.tval2      <= rin.x.tval2;
            r.x.tval2type  <= rin.x.tval2type;
            r.x.way        <= rin.x.way;
          end if;
          -- Performance counter
          r.wb.icnt        <= rin.wb.icnt;
        end if;

        -- Synchronous Reset
        if rstn = '0' then
          if RESET_ALL then
            r                  <= RRES;
            -- MISA needs to be reset explicitly!
            r.csr.misa         <= create_misa;
            if DYNRST then
              r.f.pc(r.f.pc'high downto 12) <= RST_VEC(RST_VEC'high downto 12);
              r.d.pc(r.d.pc'high downto 12) <= RST_VEC(RST_VEC'high downto 12);
            end if;
          else
            -- Upon reset, MISA is reset, a hart’s privilege mode is set to M. The mstatus fields
            -- MIE and MPRV are reset to 0. The pc is set to an implementation-defined reset vector.
            -- The mcause register is set to a value indicating the cause of the reset.
            -- All other hart state is undefined.
            r.csr.prv          <= PRIV_LVL_M;
            r.csr.mstatus.mie  <= '0';
            r.csr.mstatus.mprv <= '0';
            r.csr.mcause       <= RST_ASYNC;
            r.csr.misa         <= create_misa;
            r.f.pc             <= PC_RESET;
            r.f.valid          <= '0';
            r.d.valid          <= '0';
            if need_extra_sync_reset(fabtech) /= 0 then
              r.d.inst         <= (others => (others => '0'));
              r.d.bjump_pre    <= (others => '0');
              r.d.jump_pre     <= (others => '0');
              r.x.mexc         <= '0';
            end if;
            r.x.rstate         <= run;
            r.csr              <= RRES.csr;
            r.csr.misa         <= create_misa;
            r.dm.tbufaddr      <= RRES.dm.tbufaddr;
            r.dm.havereset     <= RRES.dm.havereset;
            r.m.trig           <= RRES.m.trig;
          end if;
          -- Halt-on-reset
          if dbgi.haltonrst = '1' and dmen = 1 then
            r.x.rstate         <= dhalt;
          end if;

          if pmaen then
            if pma_masked = 0 then
              -- PMA data is sanitized here.
              r.csr.pma_data    <= pma_data_arr_create(pma_data);
              r.csr.pma_addr    <= pma_arr_create(pma_addr);
              r.csr.pma_precalc <= pma_precalc(pma_addr, pma_entries, physaddr);
            else
              -- Do not touch PMA (contains type masks).
              r.csr.pma_data    <= pma_arr_create(pma_data);
            end if;
          end if;

          if ext_noelv = 0
          then
            -- Activate caches - when no NOEL-V extensions
            --                   or forced enable
            r.csr.cctrl.dsnoop <= '1';
            r.csr.cctrl.iflush <= '1';
            r.csr.cctrl.dflush <= '1';
            r.csr.cctrl.dcs    <= "11";
            r.csr.cctrl.ics    <= "11";
-- pragma translate_off
          else
            -- Activate caches - for simulation
            r.csr.cctrl.dsnoop <= '1';
            r.csr.cctrl.iflush <= '1';
            r.csr.cctrl.dflush <= '1';
            r.csr.cctrl.dcs    <= "11";
            r.csr.cctrl.ics    <= "11";
-- pragma translate_on
          end if;
        end if;

      end if;
    end process; -- sync_reg


  end generate; -- syncrregs

  asyncrregs : if ASYNC_RESET generate

    -- Async Reg Process --------------------------------------------------
    async_dynrst : if DYNRST generate
      async_dynrst_reg : process(clk, arst)
      begin
        if arst = '0' then
          r.f             <= RRES.f;   -- Fetch Stage
          r.d             <= RRES.d;   -- Decode Stage
          r.a             <= RRES.a;   -- Register File Stage
          r.e             <= RRES.e;   -- Execute Stage
          r.m             <= RRES.m;   -- Memory Stage
          r.x             <= RRES.x;   -- Exception Stage
          r.wb            <= RRES.wb;  -- Writeback Stage
        elsif rising_edge(clk) then
          if holdn = '1' then
            r.f           <= rin.f;    -- Fetch Stage
            r.d           <= rin.d;    -- Decode Stage
            r.a           <= rin.a;    -- Register File Stage
            r.e           <= rin.e;    -- Execute Stage
            r.m           <= rin.m;    -- Memory Stage
            r.x           <= rin.x;    -- Exception Stage
            r.wb          <= rin.wb;   -- Writeback Stage
          else -- holdn = '0'
            r.fpflush       <= rin.fpflush;
            -- I Cache Miss
            if ico.mds = '0' then
              r.d.inst      <= rin.d.inst;
              r.d.bjump_pre <= rin.d.bjump_pre;
              r.d.jump_pre  <= rin.d.jump_pre;
              r.d.mexc      <= rin.d.mexc;
              r.d.exctype   <= rin.d.exctype;
              r.d.exchyper  <= rin.d.exchyper;
              r.d.tval2     <= rin.d.tval2;
              r.d.tval2type <= rin.d.tval2type;
              r.d.way       <= rin.d.way;
              if r.d.unaligned = '1' and r.d.buff.valid = '1' then
                r.d.buff.inst.d(31 downto 16) <= rin.d.buff.inst.d(31 downto 16);
              end if;
            end if;
            -- D Cache Miss
            if dco.mds = '0' then
              r.x.rdata     <= rin.x.rdata;
              r.x.mexc      <= rin.x.mexc;
              r.x.exctype   <= rin.x.exctype;
              r.x.exchyper  <= rin.x.exchyper;
              r.x.tval2     <= rin.x.tval2;
              r.x.tval2type <= rin.x.tval2type;
              r.x.way       <= rin.x.way;
            end if;
          end if;
        end if;
      end process;

      async_dynrst_dynreg : process (clk)
      begin
        if rising_edge(clk) then
          if holdn = '1' then
            r.f.pc <= rin.f.pc;
            r.d.pc <= rin.d.pc;
          end if;
          if rstn = '0' then
            r.d.pc <= RST_VEC(RST_VEC'high downto 12) & PC_ZERO(11 downto 0);
          end if;
        end if;
      end process;

    end generate;

    async_not_dynrst : if not DYNRST generate
      async_not_dynrst_reg : process (clk, arst)
      begin
        if arst = '0' then
          r.f             <= RRES.f;   -- Fetch Stage
          r.d             <= RRES.d;   -- Decode Stage
          r.a             <= RRES.a;   -- Register File Stage
          r.e             <= RRES.e;   -- Execute Stage
          r.m             <= RRES.m;   -- Memory Stage
          r.x             <= RRES.x;   -- Exception Stage
          r.wb            <= RRES.wb;  -- Writeback Stage
        elsif rising_edge(clk) then
          if holdn = '1' then
            r.f           <= rin.f;    -- Fetch Stage
            r.d           <= rin.d;    -- Decode Stage
            r.a           <= rin.a;    -- Register File Stage
            r.e           <= rin.e;    -- Execute Stage
            r.m           <= rin.m;    -- Memory Stage
            r.x           <= rin.x;    -- Exception Stage
            r.wb          <= rin.wb;   -- Writeback Stage
          else -- holdn = '0'
            r.fpflush      <= rin.fpflush;
            -- I Cache Miss
            if ico.mds = '0' then
              r.d.inst      <= rin.d.inst;
              r.d.bjump_pre <= rin.d.bjump_pre;
              r.d.jump_pre  <= rin.d.jump_pre;
              r.d.mexc      <= rin.d.mexc;
              r.d.exctype   <= rin.d.exctype;
              r.d.exchyper  <= rin.d.exchyper;
              r.d.tval2     <= rin.d.tval2;
              r.d.tval2type <= rin.d.tval2type;
              r.d.way       <= rin.d.way;
              if r.d.unaligned = '1' and r.d.buff.valid = '1' then
                r.d.buff.inst.d(31 downto 16) <= rin.d.buff.inst.d(31 downto 16);
              end if;
            end if;
            -- D Cache Miss
            if dco.mds = '0' then
              r.x.rdata     <= rin.x.rdata;
              r.x.mexc      <= rin.x.mexc;
              r.x.exctype   <= rin.x.exctype;
              r.x.exchyper  <= rin.x.exchyper;
              r.x.tval2     <= rin.x.tval2;
              r.x.tval2type <= rin.x.tval2type;
              r.x.way       <= rin.x.way;
            end if;
          end if;
        end if;
      end process;

      async_not_dynrst_dynreg : process (clk)
      begin
        if rising_edge(clk) then
          if holdn = '1' then
          end if;
          if rstn = '0' then
          end if;
        end if;
      end process;

    end generate;


  end generate;

end rtl;
