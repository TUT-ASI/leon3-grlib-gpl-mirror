------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
use grlib.stdlib.orv;
library gaisler;
use gaisler.utilnv.all;
use gaisler.nvsupport.all;
use gaisler.noelv.XLEN;
use gaisler.noelv.GEILEN;
use gaisler.noelv.CAUSELEN;
use gaisler.noelv.nv_irq_in_type;
use gaisler.noelv.nv_irq_out_type;
use gaisler.noelv.nv_debug_in_type;
use gaisler.noelv.nv_debug_out_type;
use gaisler.noelv.nv_debug_out_none;
use gaisler.noelv.nv_counter_out_type;
use gaisler.noelv.nv_etrace_out_type;
use gaisler.noelv.nv_etrace_out_none;
use gaisler.mmucacheconfig.satp_mode;
use gaisler.fputilnv.fpevt_t;
use gaisler.fputilnv.fpuevent_t;
use gaisler.fputilnv.fpu_event;
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
use gaisler.noelvint.nv_dcache_out_type;
use gaisler.noelvint.iregfile_in_type;
use gaisler.noelvint.iregfile_out_type;
use gaisler.noelvint.mul_in_type;
use gaisler.noelvint.mul_in_none;
use gaisler.noelvint.mul_out_type;
use gaisler.noelvint.div_in_type;
use gaisler.noelvint.div_in_none;
use gaisler.noelvint.div_out_type;
use gaisler.noelvint.fpu5_in_type;
use gaisler.noelvint.fpu5_in_none;
use gaisler.noelvint.fpu5_out_type;
use gaisler.noelvint.fpu5_out_none;
use gaisler.noelvint.itrace_in_type;
use gaisler.noelvint.itrace_out_type;
use gaisler.noelvint.nv_csr_in_type;
use gaisler.noelvint.nv_csr_out_type;
use gaisler.noelvint.nv_csr_out_type_none;
use gaisler.noelvint.nv_trace_out_type;
use gaisler.noelvint.TRACE_WIDTH;
use gaisler.noelvint.trace_info;
use gaisler.noelvint.trace_rst;
use gaisler.noelvint.cause_type;
use gaisler.noelvint.pmpaddrzero;
use gaisler.noelvint.PMPPRECALCRES;
use gaisler.noelvint.fpu_id;
use gaisler.noelvint.reg_t;


entity iunv is
  generic (
    hindex       : integer range 0  to 15;       -- Hart index
    fabtech      : integer range 0  to NTECH;    -- fabtech
    memtech      : integer range 0  to NTECH;    -- memtech
    -- Core
    physaddr     : integer range 32 to 56;       -- Physical Addressing
    addr_bits    : integer range 32 to 64;       -- Max bits required for an address
    rstaddr      : integer;                      -- Reset vector (MSB)
    perf_cnts    : integer range 0  to 29;       -- Number of performance counters
    perf_evts    : integer range 0  to 255;      -- Number of performance events
    perf_bits    : integer range 0  to 64;       -- Bits of performance counting
    illegalTval0 : integer range 0  to 1;        -- Zero TVAL on illegal instruction
    no_muladd    : integer range 0  to 1;        -- 1 - multiply-add not supported
    single_issue : integer range 0  to 1;        -- 1 - only one pipeline
    -- Caches
    iways        : integer range 1  to 8;        -- I$ Sets
    dways        : integer range 1  to 8;        -- D$ Sets
    itcmen       : integer range 0  to 1;        -- Instruction TCM
    dtcmen       : integer range 0  to 1;        -- Data TCM
    -- MMU
    mmuen        : integer range 0  to 2;        -- 0 - MMU disable
    riscv_mmu    : integer range 0  to 3;
    pmp_no_tor   : integer range 0  to 1;        -- Disable PMP TOR
    pmp_entries  : integer range 0  to 16;       -- Implemented PMP registers
    pmp_g        : integer range 0  to 10;       -- PMP grain is 2^(pmp_g + 2) bytes
    asidlen      : integer range 0 to  16 := 0;  -- Max 9 for Sv32
    vmidlen      : integer range 0 to  14 := 0;  -- Max 7 for Sv32
    -- Extensions
    ext_m        : integer range 0  to 1;        -- M Base Extension Set
    ext_a        : integer range 0  to 1;        -- A Base Extension Set
    ext_c        : integer range 0  to 1;        -- C Base Extension Set
    ext_h        : integer range 0  to 1;        -- H-Extension
    ext_zba      : integer range 0  to 1;        -- Zba Extension
    ext_zbb      : integer range 0  to 1;        -- Zbb Extension
    ext_zbc      : integer range 0  to 1;        -- Zbc Extension
    ext_zbs      : integer range 0  to 1;        -- Zbs Extension
    ext_zbkb     : integer range 0  to 1;        -- Zbkb Extension
    ext_zbkc     : integer range 0  to 1;        -- Zbkc Extension
    ext_zbkx     : integer range 0  to 1;        -- Zbkx Extension
    ext_sscofpmf : integer range 0  to 1;        -- Sscofpmf Extension
    ext_sstc     : integer range 0  to 2;        -- Sctc Extension (2 : only time csr impl.)  
    ext_zicbom   : integer range 0  to 1;        -- Zicbom Extension
    mode_s       : integer range 0  to 1;        -- Supervisor Mode Support
    mode_u       : integer range 0  to 1;        -- User Mode Support
    dmen         : integer range 0  to 1;        -- Using RISC-V Debug Module
    fpulen       : integer range 0  to 128;      -- Floating-point precision
    fpuconf      : integer range 0  to 1;        -- 0 = nanoFPUnv, 1 = GRFPUnv
    trigger      : integer range 0  to 4096;
    -- Advanced Features
    late_branch  : integer range 0  to 1;        -- Late Branch Support
    late_alu     : integer range 0  to 1;        -- Late ALUs Support
    -- Misc
    pbaddr       : integer;                      -- Program buffer exe address
    tbuf         : integer;                      -- Trace buffer size in kB
    scantest     : integer;                      -- Scantest support
    rfreadhold   : integer range 0  to 1;        -- Register File Read Hold
    fpu_debug    : integer range 0  to 1 := 0;   -- FCSR bits for controlling the FPU
    fpu_lane     : integer range 0  to 1 := 0;   -- Lane where (non-memory) FPU instructions go
    csr_lane     : integer range 0  to 1 := 0;   -- Lane where CSRs are handled
    endian       : integer range 0  to 1         -- 1 - little endian
    );
  port (
    clk            : in  std_ulogic;           -- clk
    rstn           : in  std_ulogic;           -- active low reset
    holdn          : in  std_ulogic;           -- active low hold signal
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
    irqi           : in  nv_irq_in_type;       -- Irq In Port
    irqo           : out nv_irq_out_type;      -- Irq Out Port
    dbgi           : in  nv_debug_in_type;     -- Debug In Port
    dbgo           : out nv_debug_out_type;    -- Debug Out Port
    muli           : out mul_in_type;          -- Mul Unit In Port
    mulo           : in  mul_out_type;         -- Mul Unit Out Port
    divi           : out div_in_type;          -- Div Unit In Port
    divo           : in  div_out_type;         -- Div Unit Out Port
    fpui           : out fpu5_in_type;         -- FPU Unit In Port
    fpuo           : in  fpu5_out_type;        -- FPU Unit Out Port
    cnt            : out nv_counter_out_type;  -- Perf event Out Port
    itracei        : out itrace_in_type;
    itraceo        : in  itrace_out_type;
    csr_mmu        : out nv_csr_out_type;      -- CSR values for MMU
    mmu_csr        : in  nv_csr_in_type;       -- CSR values for MMU
    perf           : in  std_logic_vector(31 downto 0);
    cap            : in  std_logic_vector(9 downto 0);
    tbo            : in  nv_trace_out_type;    -- Trace Unit Out Port
    eto            : out nv_etrace_out_type;   -- E-trace output
    sclk           : in  std_ulogic;
    testen         : in  std_ulogic;
    testrst        : in  std_ulogic
    );
end;

architecture rtl of iunv is

  -- Regarding instructions swapping lanes
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
  -- so for forwarding only the following are relevent:
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
  -- 0 -> 1
  --   JAL, JALR
  --   CSRs, if csr_lane = 1
  -- 1 -> 0
  --   load integer, amo
  --   CSRs, if csr_lane = 0
  --
  -- JAL/JALR will not pair when first due to control flow change,
  -- so there will never be a swap with them paired.
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
  -- Lane where branches are handled (0 not allowed when dual-issue!)
  constant branch_lane : integer := 1 - single_issue;
  -- Lane 1 (the one that does not exist when not dual-issue!)
  -- No uses of this will be relevant without dual-issue.
  constant one         : integer := 1 - single_issue;

  -- Defined as in MISA
  constant rv : std_logic_vector(1 downto 0) := u2vec(log2(XLEN / 32) + 1, 2);

  function is_rv(len : integer; rv : std_logic_vector(1 downto 0)) return boolean is
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
  constant ext_n        : integer := 0;

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
    extension(x_m,            is_set(ext_m))         or
    extension(x_f,            is_set(ext_f))         or
    extension(x_d,            is_set(ext_d))         or
    extension(x_a,            is_set(ext_a))         or
    extension(x_c,            is_set(ext_c))         or
    extension(x_h,            is_set(ext_h))         or
    extension(x_sscofpmf,     is_set(ext_sscofpmf))  or
    extension(x_sstc,         (ext_sstc = 1))        or
    extension(x_zicbom,       is_set(ext_zicbom))    or
    extension(x_time,         is_set(ext_sstc))      or
    extension(x_zba,          is_set(ext_zba))       or
    extension(x_zbb,          is_set(ext_zbb))       or
    extension(x_zbc,          is_set(ext_zbc))       or
    extension(x_zbs,          is_set(ext_zbs))       or
    extension(x_zbkb,         is_set(ext_zbkb))      or
    extension(x_zbkc,         is_set(ext_zbkc))      or
    extension(x_zbkx,         is_set(ext_zbkx));

  -- Supported xENVCFG extensions
  constant active_menvcfg : csr_envcfg_type := gen_envcfg_mmask(active_extensions);
  constant active_senvcfg : csr_envcfg_type := gen_envcfg_smask(active_extensions);

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


  -- ISA Constants
  constant ISA_EXTENSION : std_logic_vector(25 downto 0) :=
    '0'                 &     -- Z Reserved
    '0'                 &     -- Y Reserved
    '0'                 &     -- X Non-standard
    '0'                 &     -- W Reserved
    '0'                 &     -- V
    to_bit(mode_u)      &     -- U User mode
    '0'                 &     -- T
    to_bit(mode_s)      &     -- S Supervisor mode
    '0'                 &     -- R Reserved
    to_bit(ext_q)       &     -- Q
    '0'                 &     -- P
    '0'                 &     -- O Reserved
    to_bit(ext_n)       &     -- N
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
    '0'                 &     -- B
    to_bit(ext_a);            -- A

  -- A set bit marks that the corresponding extention etc can be disabled.
  -- Note that each such bit added will need code changes to actually be useful.
  -- Current things that can be disabled:
  constant c_ctrl      : integer := 2;   -- Compressed instructions extension (C)
  constant h_ctrl      : integer := 7;   -- Hypervisor extension (H)
  constant x_ctrl      : integer := 23;  -- Non-standard extensions (X)
  constant ISA_CONTROL : wordx   := (
    h_ctrl => '1',
    x_ctrl => '1',
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

  -- Debug Constants
  function create_dprogbuf return wordx is
    -- Non-constant
    variable addr : wordx := zerox;
  begin
    addr(31 downto 12) := u2vec(pbaddr, 20);

    return addr;
  end;

  constant DPROGBUF : wordx := create_dprogbuf;

  -------------------------------------------------------------------------------
  -- Type Declarations
  -------------------------------------------------------------------------------

  -- Pipeline

  -- The maximum bits that are required to hold an address (physical or virtual).
  -- May be two bits longer than the actual address, since we need to keep track of
  -- whether higher bits are the same or not (not same - bad address).
  subtype addr_type is std_logic_vector(cond(addr_bits = XLEN, addr_bits - 1, addr_bits + 1) downto 0);

  -- Shortens addresses to the size that is actually needed (see addr_type).
  -- If an address is "sign extended" above the useable part, the two bits
  -- just above that part will be the same as that one.
  -- A mix of 0s and 1s above the useable part will force the two bits
  -- just above that part to be "10".
  -- Example - MSB is top of actually useable address bits:
  --   Incoming address <n bits (X)><1 MSB><(XLEN - n - 1) LSBs>
  --   1 X = 111...111 -> 11<MSB><LSBs>
  --   2 X = 000...000 -> 00<MSB><LSBs>
  --   3 X = <mix 0/1> -> 10<MSB><LSBs>
  --   ->
  --   1 - The extra bits will be a sign extension if MSB is 1.
  --   2 - The extra bits will be a sign extension if MSB is 0.
  --   3 - Top two bits always different.
  --   ->
  --     A properly sign extended virtual address will stay sign extended in short form.
  --     A badly sign extended virtual address will stay badly sign extended.
  --     A physical address will have "00" at the top if and only if all were zero up there.
  function to_addr(addr_in : std_logic_vector) return addr_type is
    variable addr_normal : std_logic_vector(addr_in'length - 1 downto 0)         := addr_in;
    variable high_bits   : std_logic_vector(addr_in'length - 1 downto addr_bits) := (others => '0');
    -- Non-constant
    variable addr        : addr_type;  -- Manipulated from _in for efficiency.
  begin
    addr := addr_normal(addr'range);
    if addr_normal'length > addr'length then
      addr(addr'high)     := not all_0(addr_normal(high_bits'range));  -- Some hign 1s?
      addr(addr'high - 1) :=     all_1(addr_normal(high_bits'range));  -- All hign 1s?
    end if;

    return addr;
  end;

  -- This is the maximum number of bits that need to be stored for PC,
  -- but calculations need full 64 bits (or at least check for bad address).
--  subtype pctype         is std_logic_vector(pcbits - 1 downto 0);
  subtype pctype         is addr_type;

  subtype lanes_range    is integer range lanes'range;
  subtype lanes_type     is std_logic_vector(lanes'high downto lanes'low);  -- Must be n downto 0!

  -- Lanes types
  type pc_lanes_type     is array (lanes'range) of pctype;
  type rfa_lanes_type    is array (lanes'range) of rfatype;
  type word_lanes_type   is array (lanes'range) of word;
  type wordx_lanes_type  is array (lanes'range) of wordx;
  type word16_lanes_type is array (lanes'range) of word16;
  type word2_lanes_type  is array (lanes'range) of word2;
  type word3_lanes_type  is array (lanes'range) of word3;
  type fusel_lanes_type  is array (lanes'range) of fuseltype;
  type rs_lanes_type     is array (lanes'range) of std_logic_vector(1 to 2);
  type mux_lanes_type    is array (lanes'range) of word3;
  type cause_lanes_type  is array (lanes'range) of cause_type;
  type alu_ctrl_lanes_type is array (lanes'range) of alu_ctrl;

--  type iword16_type is record
--    lpc : std_logic_vector(1 downto 0);
--    d   : word16;
--    xc  : word3;
--  end record;

  -- These are for the two fetched instructions, not lanes!
  constant fetch          : std_logic_vector(0 to 1) := (others => '0');    -- Used as range.
  subtype fetch_pair     is std_logic_vector(fetch'high downto fetch'low);  -- Must be n downto 0!
--  type iword16_pair_type is array (fetch'range) of iword16_type;
  type wordx_pair_type   is array (fetch'range) of wordx;
  type pc_fetch_type     is array (fetch'range) of pctype;
  type word16_fetch_type is array (fetch'range) of word16;
  type rfa_fetch_type    is array (fetch'range) of rfatype;
  type fusel_fetch_type  is array (fetch'range) of fuseltype;
  type cause_fetch_type  is array (fetch'range) of cause_type;

  -- Caches
  type icdtype           is array (0 to iways - 1) of word64;
  type dcdtype           is array (0 to dways - 1) of word64;

  -- PC
  constant PC_ZERO      : pctype    := (others => '0');
  constant PC_RESET     : pctype    := PC_ZERO(PC_ZERO'high downto 32) &
                                       u2vec(rstaddr, 20) & PC_ZERO(11 downto 0);

  -- Stages
  type stage_type is (a, e, m, x, wb);

  -- Branch Type ----------------------------------------------------------------
  type branch_type is record
    valid       : std_ulogic;                          -- instruction is a branch instruction
    dir         : std_logic_vector(bhti.wdata'range);  -- branch output prediction from the BHT
    addr        : pctype;                              -- target address where to branch
    naddr       : pctype;                              -- address of the next instruction
    taken       : std_ulogic;                          -- branch has been taken
    hit         : std_ulogic;                          -- branch target address has been found in the BTB
    mpred       : std_ulogic;                          -- branch mispredicted
  end record;

  type branch_pair_type is array (lanes'range) of branch_type;

  constant branch_none : branch_type := (
    valid       => '0',
    dir         => (others => '0'),
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
    comp        => '0',
    branch      => branch_none,
    rdv         => '0',
    rd_vs_rs    => rd_vs_rs_none,
    csrv        => '0',
    csrdo       => '0',
    xc          => '0',
    mexc        => '0',
    cause       => (others => '0'),
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
    category : std_logic_vector(9 downto 0);
    ctrl     : word2;
    v        : wordx;         -- Value read from CSR register
  end record;

  constant csr_none : csr_type := (
    r        => '0',
    w        => '0',
    category => (others => '0'),
    ctrl     => (others => '0'),
    v        => (others => '0')
  );

  type pipeline_ctrl_lanes_type is array (lanes'range) of pipeline_ctrl_type;

  -- PC Gen <-> Fetch Stage --------------------------------------------------
  type fetch_reg_type is record
    pc          : pctype;                             -- pc to be fetched
    valid       : std_ulogic;                         -- valid fetch request
  end record;

  -- Fetch Stage <-> Decode Stage --------------------------------------------
  type decode_reg_type is record
    pc          : pctype;                             -- fetched program counter as from fetch stage
    inst        : icdtype;                            -- instructions
    buff        : iqueue_type;                        -- single-entry instruction buffer
    valid       : std_ulogic;                         -- instructions are valid
    xc          : std_ulogic;                         -- exception/trap from previous stages
    cause       : cause_type;                         -- exception/trap cause from previous stages
    tval        : wordx;                              -- exception/trap value from previous stages
    way         : std_logic_vector(IWAYMSB downto 0); -- cache way where instructions are located
    mexc        : std_ulogic;                         -- error in cache access
    was_xc      : std_ulogic;                         -- error just before
    exctype     : std_ulogic;                         -- error type in cache access
    exchyper    : std_ulogic;                         -- Hypervisor exception in cache access
    tval2       : wordx;                              -- Hypervisor exception info from cache
    tval2type   : word2;                              -- Hypervisor exception info from cache
    prediction  : prediction_array_type;              -- BHT record
    hit         : std_ulogic;                         -- fetched pc hit BTB
    unaligned   : std_ulogic;                         -- unaligned compressed instruction flag due to previous fetched pair
--    uninst      : iword16_type;                       -- unaligned compressed instruction
  end record;

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
    csrw_eq     : std_logic_vector(3 downto 0);  --related to csr write hold checks
    lalu_pre    : lanes_type;                -- prechecked lalu
  end record;


  -- ALU Inputs --------------------------------------------------------------
  type alu_type is record
    op1         : wordx;                   -- operand 1
    op2         : wordx;                   -- operand 2
    valid       : std_ulogic;              -- enable signal
    ctrl        : alu_ctrl;                -- ALU control
    lalu        : std_ulogic;              -- instruction makes use of lalu
  end record;

  type alu_pair_type is array (lanes'range) of alu_type;

  constant alu_none  : alu_type := (
    op1         => zerox,
    op2         => zerox,
    valid       => '0',
    ctrl        => alu_ctrl_none,
    lalu        => '0'
    );

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
    accesshold  : std_logic_vector(0 to 1);  -- Memory access hold due to CSR access.
    exechold    : std_logic_vector(0 to 2);  -- Execution hold due to pipeline flushing instruction.
    fpuhold     : std_logic_vector(0 to 5);  -- Execution hold due to FPU instruction.
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
    raso        : nv_ras_out_type;           -- RAS record
    rasi        : nv_ras_in_type;            -- Speculative RAS record
  end record;

  -- Data Cache Inputs --------------------------------------------------------
  type dcache_in_type is record
    signed      : std_ulogic;
    enaddr      : std_ulogic;
    read        : std_ulogic;
    write       : std_ulogic;
    lock        : std_ulogic;
    dsuen       : std_ulogic;
    size        : word2;
    asi         : word8;
    amo         : std_logic_vector(5 downto 0);
    cbo         : std_logic_vector(2 downto 0);
    vms         : std_logic_vector(2 downto 0);
    sum         : std_ulogic;
    mxr         : std_ulogic;
    vmxr        : std_ulogic;
    hx          : std_ulogic;
  end record;

  constant dcache_in_none : dcache_in_type := (
    signed      => '0',
    enaddr      => '0',
    read        => '0',
    write       => '0',
    lock        => '0',
    dsuen       => '0',
    size        => (others => '0'),
    asi         => (others => '0'),
    amo         => (others => '0'),
    cbo         => (others => '0'),
    vms         => (others => '0'),
    sum         => '0',
    mxr         => '0',
    vmxr        => '0',
    hx          => '0'
    );

  -- Load types
  constant SZBYTE       : word2 := "00";
  constant SZHALF       : word2 := "01";
  constant SZWORD       : word2 := "10";
  constant SZDBL        : word2 := "11";

  constant TRIGGER_MC_NUM : integer range 0 to 16 := (trigger mod 16);        -- MCONTROL
  constant TRIGGER_IC_NUM : integer range 0 to 1  := ((trigger / 16) mod 2);  -- ICOUNT
  constant TRIGGER_IE_NUM : integer range 0 to 2  := ((trigger / 32) mod 3);  -- I/ETRIGGE
  constant TRIGGER_NUM    : integer := TRIGGER_MC_NUM + TRIGGER_IC_NUM + TRIGGER_IE_NUM;

  subtype trighit_type   is std_logic_vector(TRIGGER_NUM - 1 downto 0);

  type trig_typ_vector_type  is array (0 to TRIGGER_NUM - 1) of std_logic_vector(11 downto 0);
--  type trig_info_vector_type is array (0 to TRIGGER_NUM - 1) of std_logic_vector(15 downto 0);
  constant dummy_csr : csr_reg_type := CSRRES;
  type trig_info_vector_type is array (0 to 2 ** dummy_csr.tcsr.tselect'length - 1) of std_logic_vector(15 downto 0);
  function set_trig_typ_vector(mc : integer;
                               ic : integer;
                               ie : integer) return trig_typ_vector_type is
    -- Non-constant
    variable typ : trig_typ_vector_type := (others => (others => '0'));
  begin
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

    return typ;
  end function;
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
    for i in 0 to (mc + ic + ie) - 1 loop
      if i < mc then
        info(i) := x"0004";
      elsif (ic /= 0) and i < (mc + ic) then
        info(i) := x"0008";
      elsif (ie /= 0) and i = (mc + ic) then
        info(i) := x"0030";
      else
        info(i) := x"0030";
      end if;
    end loop;

    return info;
  end function;
  constant trig_info_vector : trig_info_vector_type := set_trig_info_vector(
                                                         TRIGGER_MC_NUM,
                                                         TRIGGER_IC_NUM,
                                                         TRIGGER_IE_NUM);

  -- Pipeline trigger type
  type trig_type is record
    valid   : lanes_type;
    nullify : lanes_type;
    pending : std_logic;
    action  : std_logic_vector(1 downto 0);
    hit     : trighit_type;
  end record;
  constant trig_none : trig_type := ((others => '0'), (others => '0'), '0', (others => '0'), (others => '0'));

  -- Execute Stage <-> Memory Stage -------------------------------------------
  type memory_reg_type is record
    ctrl        : pipeline_ctrl_lanes_type;     -- Pipeline control record
    csr         : csr_type;                     -- CSR information
    rfa1        : rfa_lanes_type;               -- Register file record for op1
    rfa2        : rfa_lanes_type;               -- Register file record for op2
    result      : wordx_lanes_type;             -- ALUs result
    fpuflags    : std_logic_vector(4 downto 0); -- FPU flags
    dci         : dcache_in_type;               -- Data cache input record
    stdata      : wordx;                        -- Data to store for ST instructions
    stforw      : lanes_type;                   -- Store unit forwarded flags
    fpdata      : word64;                       -- Float data to store
    swap        : std_ulogic;                   -- Instrutions are swapped
    address     : addr_type;                    -- Address pre-computation for DCache
    lbranch     : std_ulogic;                   -- Late branch flag
    alu         : alu_pair_type;                -- Late ALUs record
    spec_ld     : std_ulogic;                   -- Speculative load operation flag
    rasi        : nv_ras_in_type;               -- Speculative RAS record
    trig        : trig_type;                    -- Trigger on instruction
  end record;

--  -- Core State ---------------------------------------------------------------
--  type core_state is (run, dhalt, dexec);

  -- Memory Stage <-> Exception Stage -----------------------------------------
  type exception_reg_type is record
    ctrl        : pipeline_ctrl_lanes_type;     -- Pipeline control record
    csr         : csr_type;                     -- CSR information
    rfa1        : rfa_lanes_type;               -- Register file record for op1
    rfa2        : rfa_lanes_type;               -- Register file record for op2
    result      : wordx_lanes_type;             -- ALUs result
    fpuflags    : std_logic_vector(4 downto 0); -- FPU flags
    address     : addr_type;                    -- Computed address for Data cache
    dci         : dcache_in_type;               -- Data Cache record
    data        : dcdtype;                      -- Data from Load unit
    way         : std_logic_vector(DWAYMSB downto 0);
    mexc        : std_ulogic;                   -- Exception flag from Data cache
    exctype     : std_ulogic;                   -- Exception type from Data cache
    exchyper    : std_ulogic;                   -- Hypervisor exception from cache
    tval2       : wordx;                        -- Hypervisor exception info from cache
    tval2type   : word2;                        -- Hypervisor exception info from cache
    wcsr        : wordx;                        -- Load/store address for trace
    csrw        : lanes_type;                   -- CSR write enable
    csraxc      : std_ulogic;                   -- CSR write address not OK
    ret         : word2;                        -- Privileged level to return
    swap        : std_ulogic;                   -- Instrutions are swapped
    alupreforw1 : mux_lanes_type;               -- ALUs preforward information
    alupreforw2 : mux_lanes_type;               -- ALUs preforward information
    lbranch     : std_ulogic;                   -- Late branch flag
    alu         : alu_pair_type;                -- Late ALUs record
    spec_ld     : std_ulogic;                   -- Speculative load operation flag
    rstate      : core_state;                   -- Core state
    rasi        : nv_ras_in_type;               -- Speculative RAS record
    trig        : trig_type;                    -- Trigger on instruction
    int         : lanes_type;                   -- Interrupt on instruction
    irqcause    : cause_type;                   -- interrupt cause
    fsd_hi      : word;                         -- High half of fsd data
  end record;

  -- Exception Stage <-> Write Back Stage -------------------------------------
  type writeback_reg_type is record
    ctrl          : pipeline_ctrl_lanes_type;       -- Pipeline control record
    csr           : csr_type;                       -- CSR information
    wdata         : wordx_lanes_type;               -- Write-back data to register file
    wcsr          : wordx_lanes_type;               -- Write-back data to CSR etc for trace
    fpuflags      : std_logic_vector(4 downto 0);   -- FPU flags
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
    bht_bhistory  : std_logic_vector(4 downto 0);   -- BHT bhistory input
    bht_phistory  : word64;                         -- BHT phistory input
    ret           : std_logic;                      -- xRet instruction
    trap_taken    : lanes_type;                     -- Used for debug printing
    icnt          : std_logic_vector(1 downto 0);   -- instruction count event
    unalg_pc      : pctype;                         -- Unaligned PC to write for BTB/BHT
    fsd_hi        : word;                           -- High half of fsd data
  end record;

  -- Debug-Module reegister ---------------------------------------------------
  type debugmodule_reg_type is record
    cmdexec     : std_logic_vector(1 downto 0);              -- Command on going
    write       : std_ulogic;                                -- Command write
    size        : std_logic_vector(2 downto 0);              -- Command size
    cmd         : std_logic_vector(1 downto 0);              -- Command
    addr        : std_logic_vector(15 downto 0);             -- Command addr
    havereset   : std_logic_vector(3 downto 0);              -- Have been reset
    tbufaddr    : std_logic_vector(TBUFBITS - 1 downto 0);   -- Trace buffer readout address
  end record;

  -- All Stages ---------------------------------------------------------------
  type registers is record
    f       : fetch_reg_type;
    d       : decode_reg_type;
    a       : regacc_reg_type;
    e       : execute_reg_type;
    m       : memory_reg_type;
    x       : exception_reg_type;
    wb      : writeback_reg_type;
    csr     : csr_reg_type;
    mmu     : nv_csr_out_type;  -- Pipelined on the way to MMU/cache controller
    dm      : debugmodule_reg_type;
    evt     : std_logic_vector(0 to 255);                -- 0 not used
    cevt    : std_logic_vector(0 to perf_cnts + 3 - 1);  -- 0-2 not used
    evtirq  : std_logic_vector(0 to perf_cnts + 3 - 1);  -- 0-2 not used
    fpo     : fpu5_out_type;    -- FPU output, for logging
    fpflush : std_logic_vector(4 downto 0);
  end record;

  ----------------------------------------------------------------------------
  -- Reset Functions and Constants
  ----------------------------------------------------------------------------

  function registers_rst return registers is
    -- Non-constant
    variable v : registers;
  begin
    -- Fetch Stage
    v.f.pc                      := PC_RESET;
    v.f.valid                   := '0';
    -- Decode Stage
    v.d.pc                      := PC_RESET;
    v.d.inst                    := (others => (others => '0'));
    v.d.buff                    := iqueue_none;
    v.d.valid                   := '0';
    v.d.xc                      := '0';
    v.d.cause                   := RST_HARD_ALL;
    v.d.tval                    := zerox;
    v.d.way                     := (others => '0');
    v.d.mexc                    := '0';
    v.d.was_xc                  := '0';
    v.d.exctype                 := '0';
    v.d.exchyper                := '0';
    v.d.tval2                   := zerox;
    v.d.tval2type               := "00";
    v.d.prediction              := (others => prediction_none);
    v.d.hit                     := '0';
    v.d.unaligned               := '0';
--    v.d.uninst                  := ("00",(others => '0'), "000");
    -- Register Access Stage
    v.a.ctrl                    := (others => pipeline_ctrl_none);
    v.a.csr                     := csr_none;
    v.a.rfa1                    := (others => (others => '0'));
    v.a.rfa2                    := (others => (others => '0'));
    v.a.imm                     := (others => zerox);
    v.a.immv                    := (others => '0');
    v.a.pcv                     := (others => '0');
    v.a.swap                    := '0';
    v.a.raso                    := nv_ras_out_none;
    v.a.rasi                    := nv_ras_in_none;
    v.a.csrw_eq                 := (others => '0');
    v.a.lalu_pre                := (others => '0');
    -- Execute Stage
    v.e.ctrl                    := (others => pipeline_ctrl_none);
    v.e.csr                     := csr_none;
    v.e.rfa1                    := (others => (others => '0'));
    v.e.rfa2                    := (others => (others => '0'));
    v.e.alu                     := (others => alu_none);
    v.e.stdata                  := zerox;
    v.e.accesshold              := (others => '0');
    v.e.exechold                := (others => '0');
    v.e.fpuhold                 := (others => '0');
    v.e.fpu_wait                := '0';
    v.e.swap                    := '0';
    v.e.jimm                    := zerox;
    v.e.jop1                    := zerox;
    v.e.jumpforw                := (others => (others => '0'));
    v.e.aluforw                 := (others => (others => '0'));
    v.e.alupreforw1             := (others => (others => '0'));
    v.e.alupreforw2             := (others => (others => '0'));
    v.e.stforw                  := (others => '0');
    v.e.lbranch                 := '0';
    v.e.raso                    := nv_ras_out_none;
    v.e.rasi                    := nv_ras_in_none;
    v.e.spec_ld                 := '0';
    -- Memory Stage
    v.m.ctrl                    := (others => pipeline_ctrl_none);
    v.m.csr                     := csr_none;
    v.m.rfa1                    := (others => (others => '0'));
    v.m.rfa2                    := (others => (others => '0'));
    v.m.result                  := (others => zerox);
    v.m.fpuflags                := (others => '0');
    v.m.dci                     := dcache_in_none;
    v.m.stdata                  := zerox;
    v.m.stforw                  := (others => '0');
    v.m.fpdata                  := zerow64;
    v.m.swap                    := '0';
    v.m.address                 := (others => '0');
    v.m.lbranch                 := '0';
    v.m.alu                     := (others => alu_none);
    v.m.rasi                    := nv_ras_in_none;
    v.m.trig                    := trig_none;
    v.m.spec_ld                 := '0';
    -- Exception Stage
    v.x.ctrl                    := (others => pipeline_ctrl_none);
    v.x.csr                     := csr_none;
    v.x.rfa1                    := (others => (others => '0'));
    v.x.rfa2                    := (others => (others => '0'));
    v.x.result                  := (others => zerox);
    v.x.fpuflags                := (others => '0');
    v.x.address                 := (others => '0');
    v.x.dci                     := dcache_in_none;
    v.x.data                    := (others => zerow64);
    v.x.way                     := (others => '0');
    v.x.mexc                    := '0';
    v.x.exctype                 := '0';
    v.x.exchyper                := '0';
    v.x.tval2                   := zerox;
    v.x.tval2type               := "00";
    v.x.wcsr                    := zerox;
    v.x.csrw                    := (others => '0');
    v.x.csraxc                  := '0';
    v.x.ret                     := (others => '0');
    v.x.swap                    := '0';
    v.x.alupreforw1             := (others => (others => '0'));
    v.x.alupreforw2             := (others => (others => '0'));
    v.x.lbranch                 := '0';
    v.x.alu                     := (others => alu_none);
    v.x.rstate                  := run;
    v.x.rasi                    := nv_ras_in_none;
    v.x.trig                    := trig_none;
    v.x.int                     := (others => '0');
    v.x.spec_ld                 := '0';
    v.x.irqcause                := (others => '0');
    v.x.fsd_hi                  := (others => '0');
    -- Writeback Stage
    v.wb.ctrl                   := (others => pipeline_ctrl_none);
    v.wb.csr                    := csr_none;
    v.wb.wdata                  := (others => zerox);
    v.wb.wcsr                   := (others => zerox);
    v.wb.fpuflags               := (others => '0');
    v.wb.lalu                   := (others => '0');
    v.wb.flushall               := '0';
    v.wb.csr_pipeflush          := '0';
    v.wb.csr_addrflush          := '0';
    v.wb.fence_flush            := '0';
    v.wb.swap                   := '0';
    v.wb.rstate                 := run;
    v.wb.xc_taken               := '0';
    v.wb.xc_taken_cause         := (others => '0');
    v.wb.xc_taken_tval          := zerox;
    v.wb.nextpc0                := PC_ZERO;
    v.wb.rasi                   := nv_ras_in_none;
    v.wb.prv                    := (others => '0');
    v.wb.v                      := '0';
    v.wb.bht_bhistory           := (others => '0');
    v.wb.bht_phistory           := (others => '0');
    v.wb.ret                    := '0';
    v.wb.trap_taken             := (others => '0');
    v.wb.icnt                   := (others => '0');
    v.wb.fsd_hi                 := (others => '0');
    -- CSR Regfile
    v.csr                       := CSRRES;
    -- MMU
    v.mmu                       := nv_csr_out_type_none;
    -- HPM events
    v.evt                       := (others => '0');
    v.cevt                      := (others => '0');
    v.evtirq                    := (others => '0');
    -- Triggers
    for i in trig_typ_vector'range loop
      v.csr.tcsr.tdata1(i)(XLEN-1 downto XLEN-12) := trig_typ_vector(i);
      v.csr.tcsr.tinfo(i)                         := trig_info_vector(i);
    end loop;
    -- Debug-Module
    v.dm.cmdexec                := (others => '0');
    v.dm.write                  := '0';
    v.dm.size                   := (others => '0');
    v.dm.cmd                    := (others => '0');
    v.dm.addr                   := (others => '0');
    v.dm.havereset              := (others => '1');
    v.dm.tbufaddr               := (others => '0');
    --FPU related
    v.fpo                       := fpu5_out_none;
    v.fpflush                   := (others => '0');

    return v;
  end registers_rst;

  constant RRES         : registers := registers_rst;

  ----------------------------------------------------------------------------
  -- Signal Declarations
  ----------------------------------------------------------------------------

  signal r, rin         : registers;
  signal arst           : std_ulogic;

  -- Hart index
  signal hart           : std_logic_vector(3 downto 0);




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
  function rd(r : registers; stage : stage_type; lane : lanes_range) return std_logic_vector is
  begin
    return ctrl(r, stage, lane).inst(11 downto 7);
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

-- pragma translate_off
    assert old_eq = new_eq report "Forwarding difference" severity failure;
-- pragma translate_on


    return new_eq;
  end;


  -- Is rd valid and the same as given rs?
  function v_rd_eq(r  : registers; stage : stage_type; lane : lanes_range;
                   rs : std_logic_vector) return boolean is
    -- Non-constant
    variable c_valid : std_logic;
    variable c_rdv   : std_logic;
    variable c_rd    : rfatype;
  begin
    if    stage = a then
      c_valid := r.a.ctrl(lane).valid;
      c_rdv   := r.a.ctrl(lane).rdv;
      c_rd    := r.a.ctrl(lane).inst(11 downto 7);
    elsif stage = e then
      c_valid := r.e.ctrl(lane).valid;
      c_rdv   := r.e.ctrl(lane).rdv;
      c_rd    := r.e.ctrl(lane).inst(11 downto 7);
    elsif stage = m then
      c_valid := r.m.ctrl(lane).valid;
      c_rdv   := r.m.ctrl(lane).rdv;
      c_rd    := r.m.ctrl(lane).inst(11 downto 7);
    elsif stage = x then
      c_valid := r.x.ctrl(lane).valid;
      c_rdv   := r.x.ctrl(lane).rdv;
      c_rd    := r.x.ctrl(lane).inst(11 downto 7);
    else
      c_valid := r.wb.ctrl(lane).valid;
      c_rdv   := r.wb.ctrl(lane).rdv;
      c_rd    := r.wb.ctrl(lane).inst(11 downto 7);
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
                        rdv : std_logic; rs    : std_logic_vector) return boolean is
    -- Non-constant
    variable c_valid : std_logic;
    variable c_rd    : rfatype;
  begin
    if    stage = a then
      c_valid := r.a.ctrl(lane).valid;
      c_rd    := r.a.ctrl(lane).inst(11 downto 7);
    elsif stage = e then
      c_valid := r.e.ctrl(lane).valid;
      c_rd    := r.e.ctrl(lane).inst(11 downto 7);
    elsif stage = m then
      c_valid := r.m.ctrl(lane).valid;
      c_rd    := r.m.ctrl(lane).inst(11 downto 7);
    elsif stage = x then
      c_valid := r.x.ctrl(lane).valid;
      c_rd    := r.x.ctrl(lane).inst(11 downto 7);
    else
      c_valid := r.wb.ctrl(lane).valid;
      c_rd    := r.wb.ctrl(lane).inst(11 downto 7);
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
                          valid : std_logic; rs    : std_logic_vector) return boolean is
    -- Non-constant
    variable c_rdv : std_logic;
    variable c_rd  : rfatype;
  begin
    if    stage = a then
      c_rdv := r.a.ctrl(lane).rdv;
      c_rd  := r.a.ctrl(lane).inst(11 downto 7);
    elsif stage = e then
      c_rdv := r.e.ctrl(lane).rdv;
      c_rd  := r.e.ctrl(lane).inst(11 downto 7);
    elsif stage = m then
      c_rdv := r.m.ctrl(lane).rdv;
      c_rd  := r.m.ctrl(lane).inst(11 downto 7);
    elsif stage = x then
      c_rdv := r.x.ctrl(lane).rdv;
      c_rd  := r.x.ctrl(lane).inst(11 downto 7);
    else
      c_rdv := r.wb.ctrl(lane).rdv;
      c_rd  := r.wb.ctrl(lane).inst(11 downto 7);
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
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return csr_addr(c.inst);
  end;

  function csr_eq(r : registers; stage1 : stage_type; stage2 : stage_type) return boolean is
  begin
    return csr_addr(r, stage1) = csr_addr(r, stage2);
  end;

  function csr_category_eq(r : registers; stage1 : stage_type; stage2 : stage_type) return boolean is
    variable csr1 : csr_type                     := csr(r, stage1);
    variable csr2 : csr_type                     := csr(r, stage2);
    variable cat1 : std_logic_vector(3 downto 0) := csr1.category(3 downto 0);
    variable cat2 : std_logic_vector(3 downto 0) := csr2.category(3 downto 0);
  begin
    return cat1 /= "0000" and cat1 = cat2;
  end;

  -- Is instruction a CSR access and actually valid?
  function csr_ok(r : registers; stage : stage_type) return boolean is
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return c.csrv = '1' and c.valid = '1';
  end;

  function to_asi(func : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable asi : std_logic_vector(7 downto 0);
  begin
    case func is
      when "0000" => asi := x"0C";
      when "0001" => asi := x"0D";
      when "0010" => asi := x"0E";
      when "0011" => asi := x"0F";
      when "0100" => asi := x"1B";
      when "0101" => asi := x"1C";
      when "0110" => asi := x"1E";
      when "0111" => asi := x"23";
      when "1000" => asi := x"24";
      when "1001" => asi := x"25";
      when "1010" => asi := x"26";
      when "1011" => asi := x"27";
      when others => asi := x"0B";
    end case;

    return asi;
  end;

  function to_asi_load(inst : std_logic_vector) return std_logic_vector is
    variable func : std_logic_vector(3 downto 0) := inst(23 downto 20);
  begin
    return to_asi(func);
  end;

  function to_asi_store(inst : std_logic_vector) return std_logic_vector is
    variable func : std_logic_vector(3 downto 0) := inst(10 downto 7);
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
    return csr_read_only(c.inst);
  end;

  -- Assumes it is already known that inst is a CSR instruction.
  function csr_write_only(r : registers; stage : stage_type) return boolean is
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return csr_write_only(c.inst);
  end;

  -- Assumes it is already known that inst is a CSR instruction.
  function csr_immediate(r : registers; stage : stage_type) return boolean is
    variable c      : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
    variable funct3 : funct3_type        := c.inst(14 downto 12);
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
        if r.a.ctrl(i).inst(11 downto 7) =  rfa1(dst_lane) then
          forwarding.rfa1(stage_type'pos(a))(i) := '1';
        end if;
        if r.a.ctrl(i).inst(11 downto 7) =  rfa2(dst_lane) then
          forwarding.rfa2(stage_type'pos(a))(i) := '1';
        end if;
      end if;

      if r.e.ctrl(i).valid = '1' and r.e.ctrl(i).rdv = '1' and e_valid = '1' then
        if r.e.ctrl(i).inst(11 downto 7) =  rfa1(dst_lane) then
          forwarding.rfa1(stage_type'pos(e))(i) := '1';
        end if;
        if r.e.ctrl(i).inst(11 downto 7) =  rfa2(dst_lane) then
          forwarding.rfa2(stage_type'pos(e))(i) := '1';
        end if;
      end if;

      if r.m.ctrl(i).valid = '1' and r.m.ctrl(i).rdv = '1' and m_valid = '1' then
        if r.m.ctrl(i).inst(11 downto 7) =  rfa1(dst_lane) then
          forwarding.rfa1(stage_type'pos(m))(i) := '1';
        end if;
        if r.m.ctrl(i).inst(11 downto 7) =  rfa2(dst_lane) then
          forwarding.rfa2(stage_type'pos(m))(i) := '1';
        end if;
      end if;

      if r.x.ctrl(i).valid = '1' and r.x.ctrl(i).rdv = '1' and x_valid = '1' then
        if r.x.ctrl(i).inst(11 downto 7) =  rfa1(dst_lane) then
          forwarding.rfa1(stage_type'pos(x))(i) := '1';
        end if;
        if r.x.ctrl(i).inst(11 downto 7) =  rfa2(dst_lane) then
          forwarding.rfa2(stage_type'pos(x))(i) := '1';
        end if;
      end if;

      if r.wb.ctrl(i).valid = '1' and r.wb.ctrl(i).rdv = '1' and wb_valid = '1' then
        if r.wb.ctrl(i).inst(11 downto 7) =  rfa1(dst_lane) then
          forwarding.rfa1(stage_type'pos(wb))(i) := '1';
        end if;
        if r.wb.ctrl(i).inst(11 downto 7) =  rfa2(dst_lane) then
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

  -- Hardwire status CSR bits
  function tie_status(status : csr_status_type; misa : wordx) return csr_status_type is
    variable h_en    : boolean         := misa(h_ctrl) = '1';
    -- Non-constant
    variable mstatus : csr_status_type := status;
  begin
    -- Big-endian not supported
    mstatus.sbe  := '0';
    mstatus.ube  := '0';

    if mode_s = 0 then
      mstatus.sxl  := "00";
      mstatus.spp  := '0';
      mstatus.mxr  := '0';
      mstatus.sum  := '0';
      mstatus.tvm  := '0';
      mstatus.tsr  := '0';
      mstatus.sie  := '0';
      mstatus.spie := '0';
    end if;
    if mode_u = 0 then
      mstatus.uxl  := "00";
      mstatus.mprv := '0';
      mstatus.tw   := '0';
    end if;
    if not h_en then
      mstatus.mpv  := '0';
      mstatus.gva  := '0';
    end if;
    if (ext_f + ext_d + ext_q) = 0 then
      mstatus.fs  := "00";
    end if;

    -- Unsupported privilege mode - default to user-mode.
    if status.mpp = "10" or (mode_s = 0 and status.mpp = "01") or (mode_u = 0 and status.mpp = "00") then
      if mode_u /= 0 then
        mstatus.mpp  := "00";
      else
        mstatus.mpp  := "11";
      end if;
    end if;

    return mstatus;
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

  -- Pad or extend pc to XLEN
  function pc2xlen(pc : pctype) return wordx is
    -- Non-constant
    variable data : wordx;
  begin
    data           := (others => get_hi(pc));
    data(pc'range) := pc;

    return data;
  end;

  -- Generate Next PC with adder, depending on whether compressed or not.
  function npc_adder(pc   : pctype;
                     comp : std_ulogic) return pctype is
    -- Non-constant
    variable op2 : integer;
    variable npc : pctype;
  begin
    op2   := 4;
    if comp = '1' then
      op2 := 2;
    end if;

    npc   := uadd(pc, op2);

    return to_addr(npc);
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

  -- Precheck of late alu issues in order to reduce
  -- critical path on decode stage.
  procedure late_alu_precheck(r         : in  registers;
                              instx_in  : in  iword_pair_type;
                              valid_in  : in  fetch_pair;
                              lalu_exe  : in  fetch_pair;
                              lalu_pre  : out fetch_pair
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
      rfa1(i)     := rs1_gen(inst_in(i));
      rfa2(i)     := rs2_gen(inst_in(i));
      rd_valid(i) := rd_gen(inst_in(i));
      rd(i)       := inst_in(i)(11 downto 7);
    end loop;

    if single_issue = 0 then
      if v_fusel_eq(fusel(0), ALU or LD or MUL or FPU) and valid_in(0) = '1' then
        if rd_valid(0) = '1' then
          if rd(0) = rfa1(1) or rd(0) = rfa2(1) then
            lalu_pre(1) := '1';
          end if;
        end if;
      end if;
    end if;

    if v_fusel_eq(r, a, 0, LD) then
      for i in lanes'range loop
        if v_fusel_eq(fusel(i),ALU) then
          if v_rd_eq(r, a, 0, rfa1(i)) or
             v_rd_eq(r, a, 0, rfa2(i)) then
            lalu_pre(i) := '1';
          end if;
        end if;
      end loop;
    end if;

    for i in lanes'range loop
      if v_fusel_eq(r, a, i, MUL) then
        for j in lanes'range loop
          if v_fusel_eq(fusel(j),ALU) then
            if v_rd_eq(r, a, i, rfa1(j)) or
               v_rd_eq(r, a, i, rfa2(j)) then
              lalu_pre(j) := '1';
            end if;
          end if;
        end loop;
      end if;
    end loop;

    for i in lanes'range loop
      if lalu_exe(i) = '1' and r.a.ctrl(i).valid = '1' then
        for j in lanes'range loop
          if v_fusel_eq(fusel(j),ALU) then
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
  function itrace_gen(timestamp   : in  word64;
                      r_wb        : in  writeback_reg_type) return trace_info is
    variable ctrl       : pipeline_ctrl_lanes_type := r_wb.ctrl;       -- Pipeline control record
    variable v          : std_ulogic               := r_wb.v;          -- Current Virtualization mode
    variable xc_cause   : cause_type               := r_wb.xc_taken_cause;  -- Exception Cause
    variable wcsr       : wordx_lanes_type         := r_wb.wcsr;       -- Write back data to CSR etc
    variable trap_taken : lanes_type               := r_wb.trap_taken;
    variable results    : wordx_lanes_type         := r_wb.wdata;      -- Write back data to RF
    variable fsd_hi     : word                     := r_wb.fsd_hi;     -- High half of fsd data (RV32)
    -- Non-constant
    variable info    : trace_info;
  begin
    -- Common signals are traced once only
    info.v         := v;                           -- Virtualization mode
    info.prv       := r_wb.prv;                    -- Privileged
    info.cause     := xc_cause;                    -- Exception Cause
    info.timestamp := timestamp(31 downto 0);      -- Timer Value
    info.swap      := r_wb.swap;

    for i in lanes'range loop
      info.lanes(i).valid        := ctrl(i).valid;
      info.lanes(i).exception    := r_wb.xc_taken and ctrl(i).xc and trap_taken(i);  -- Exception Flag
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

-- pragma translate_off
      info.lanes(i).xdata := wcsr(i);
-- pragma translate_on

      if ctrl(i).valid = '1' then
        info.lanes(i).int_res   := ctrl(i).rdv;
        info.lanes(i).csr_write := ctrl(i).csrv;
      end if;
    end loop;

    return info;
  end;

  -- Generate E-trace interface signal
  procedure etrace_gen(
    holdn      : in  std_ulogic;
    r_wb       : in  writeback_reg_type;
    r_x        : in  exception_reg_type;
    r_csr      : in  csr_reg_type;
    eto        : out nv_etrace_out_type) is
    -- Non-constant
    variable et   : nv_etrace_out_type := nv_etrace_out_none;
    variable last : lanes_range := 0;
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
      if r_wb.ctrl(last).cause(CAUSELEN) = '1' then -- Interrupt
        et.itype := x"2";
      else                                          -- Exception
        et.itype := x"1";
      end if;
    end if;

    et.cause := r_wb.ctrl(last).cause(CAUSELEN-1 downto 0);
    et.tval  := r_wb.ctrl(last).tval;

    -- Privilege level for current retired instruction
    et.priv := '0' & r_wb.prv;
    if ext_h /= 0 and r_wb.v = '1' then
      if r_wb.prv = "00" then
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
    --context   : std_logic_vector(XLEN-1 downto 0);
    et.ctext := (others => '0');
    --tetime    : std_logic_vector(XLEN-1 downto 0);
    et.tetime := (others => '0');
    --ctype     : std_logic_vector(1 downto 0);
    et.ctype := (others => '0');
    --sijump    : std_logic_vector(0 downto 0);
    et.sijump := (others => '0');

    eto := et;
  end procedure;

  -- CSR Read
  -- CSR read unit located in register access stage.
  -- All read accesses are combinatorial accesses.
  procedure csr_read(envcfg    : in  csr_envcfg_type;
                     csr_file  : in  csr_reg_type;
                     csra_in   : in  csratype;
                     csrv_in   : in  std_ulogic;
                     rstate_in : in  core_state;
                     iu_fflags : in  std_logic_vector;
                     mmu_csr   : in  nv_csr_in_type;
                     s_time    : in  std_logic_vector;
                     s_vtime   : in  std_logic_vector;
                     data_out  : out wordx;
                     xc_out    : out std_ulogic;
                     cause_out : out cause_type) is
    variable csra_high : csratype      := csra_in(csra_in'high downto 4) & "0000";
    variable csra_low  : integer       := u2i(csra_in(3 downto 0));
    variable h_en      : boolean       := csr_file.misa(h_ctrl) = '1';
    variable v_mode    : std_ulogic    := csr_file.misa(h_ctrl) and csr_file.v;
    variable vu_mode   : std_ulogic    := v_mode and to_bit(csr_file.prv = "00");
    -- Non-constant
    variable csr       : wordx         := zerox;
    variable xc        : std_ulogic    := '0';
    variable xc_v      : std_ulogic    := '0';
    variable priv_lvl  : priv_lvl_type := (others => '0');
    variable priv_lvlv : priv_lvl_type := (others => '0');
  begin
    if csrv_in = '1' then
      case csra_in is
        -- User Floating-Point CSRs
        when CSR_FFLAGS =>
          if ext_f = 1 and csr_file.mstatus.fs /= "00" and
             (csr_file.v = '0' or csr_file.vsstatus.fs /= "00") then
            csr := to0x(csr_file.fflags);
            csr(csr_file.fflags'range) := csr(csr_file.fflags'range) or iu_fflags;
          else
            xc := '1';
          end if;
        when CSR_FRM =>
          if ext_f = 1 and csr_file.mstatus.fs /= "00" and
             (csr_file.v = '0' or csr_file.vsstatus.fs /= "00") then
            csr := to0x(csr_file.frm);
          else
            xc := '1';
          end if;
        when CSR_FCSR =>
          if ext_f = 1 and csr_file.mstatus.fs /= "00" and
             (csr_file.v = '0' or csr_file.vsstatus.fs /= "00") then
            if fpu_debug /= 0 then
              csr(csr_file.fctrl'range) := csr_file.fctrl;
            end if;
            csr(csr_file.fflags'range)  := csr_file.fflags or iu_fflags;
            csr(csr_file.frm'range)     := csr_file.frm;
          else
            xc := '1';
          end if;
        -- Hypervisor Trap Setup
        when CSR_HSTATUS        =>
          if h_en then
            csr := to_hstatus(csr_file.hstatus);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HEDELEG        =>
          if h_en then
            csr := csr_file.hedeleg and CSR_HEDELEG_MASK;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HIDELEG        =>
          if h_en then
            csr := csr_file.hideleg and CSR_HIDELEG_MASK;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HIE            =>
          if h_en then
            csr := csr_file.mie and CSR_HIE_MASK;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HCOUNTEREN     =>
          if h_en then
            csr := to0x(csr_file.hcounteren);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HGEIE          =>
          if h_en then
            csr := csr_file.hgeie;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        -- Hypervisor Trap Handling
        when CSR_HTVAL          =>
          if h_en then
            csr := csr_file.htval;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HIP            =>
          if h_en then
            csr := csr_file.mip and CSR_HIE_MASK;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HVIP           =>
          if h_en then
            csr     := csr_file.hvip and CSR_HIDELEG_MASK;
            csr(2)  := csr_file.mip(2);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HTINST         =>
          if h_en then
            csr := csr_file.htinst;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HGEIP          =>
          if h_en then
            csr := csr_file.hgeip;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        -- Hypervisor Protection and Translation
        when CSR_HGATP          =>
          if h_en then
            if csr_file.prv = PRIV_LVL_S and csr_file.mstatus.tvm = '1' then
              xc  := '1';
            else
              csr := csr_file.hgatp;
            end if;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HENVCFG        =>
          if h_en then
            csr := to_envcfg(csr_file.henvcfg, csr_file.menvcfg);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HENVCFGH       =>
          if h_en and is_rv32 then
            csr := to_envcfgh(csr_file.henvcfg, csr_file.menvcfg);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        -- Hypervisor Counter/Timer Virtualization Registers
        when CSR_HTIMEDELTA     =>
          if h_en then
            csr := csr_file.htimedelta(wordx'range);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_HTIMEDELTAH    =>
          if h_en and is_rv32 then
            csr := to0x(csr_file.htimedelta(63 downto 32));
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        -- Virtual Supervisor Registers
        when CSR_VSSTATUS       =>
          if h_en then
            csr := to_vsstatus(csr_file.vsstatus);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSIE           =>
          if h_en then
            csr(9)  := csr_file.mie(10) and csr_file.hideleg(10);
            csr(5)  := csr_file.mie(6)  and csr_file.hideleg(6);
            csr(1)  := csr_file.mie(2)  and csr_file.hideleg(2);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSTVEC         =>
          if h_en then
            csr := csr_file.vstvec;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSSCRATCH      =>
          if h_en then
            csr := csr_file.vsscratch;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSEPC          =>
          if h_en then
            csr := csr_file.vsepc;
            if ext_c = 1 and ISA_CONTROL(c_ctrl) = '1' and csr_file.misa(c_ctrl) = '0' then
              csr(1) := '0';
            end if;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSCAUSE        =>
          if h_en then
            csr := csr_file.vscause;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSTVAL         =>
          if h_en then
            csr := csr_file.vstval;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSIP           =>
          if h_en then
            csr(9)  := csr_file.mip(10) and csr_file.hideleg(10);
            csr(5)  := csr_file.mip(6)  and csr_file.hideleg(6);
            csr(1)  := csr_file.mip(2)  and csr_file.hideleg(2);
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        when CSR_VSATP          =>
          if h_en then
            csr := csr_file.vsatp;
          else
            xc := '1';
          end if;
          xc_v := v_mode; -- virtual instruction exception
        -- User Counters/Timers - see below
        when CSR_VSTIMECMP     =>
          if envcfg.stce = '1' and h_en then
            csr := csr_file.vstimecmp(wordx'range);
          else
            xc := '1';
          end if;
          if csr_file.menvcfg.stce = '1' then
            xc_v := v_mode; -- virtual instruction exception
          end if;
        when CSR_VSTIMECMPH    =>
          if envcfg.stce = '1' and h_en and is_rv32 then 
            csr := to0x(csr_file.vstimecmp(63 downto 32));
          else
            xc := '1';
          end if;
          if csr_file.menvcfg.stce = '1' then
            xc_v := v_mode; -- virtual instruction exception
          end if;
        -- Supervisor Trap Setup
        when CSR_SSTATUS        =>
          if h_en and csr_file.v = '1' then
            csr := to_vsstatus(csr_file.vsstatus);
          else
            csr := to_sstatus(csr_file.mstatus);
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SIE            =>
          if h_en and csr_file.v = '1' then
            csr(9)  := csr_file.mie(10) and csr_file.hideleg(10);
            csr(5)  := csr_file.mie(6)  and csr_file.hideleg(6);
            csr(1)  := csr_file.mie(2)  and csr_file.hideleg(2);
          else
            csr := csr_file.mie and (csr_file.mideleg and not CSR_HIE_MASK);
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_STVEC          =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vstvec;
          else
            csr := csr_file.stvec;
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SCOUNTEREN     =>
          if mode_u = 1 then
            csr := to0x(csr_file.scounteren);
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SENVCFG        =>
          if mode_u = 1 then
            csr := to_envcfg(csr_file.senvcfg, csr_file.menvcfg);
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        -- Supervisor Trap Handling
        when CSR_SEPC           =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vsepc;
          else
            csr := csr_file.sepc;
          end if;
          if ext_c = 1 and ISA_CONTROL(c_ctrl) = '1' and csr_file.misa(c_ctrl) = '0' then
            csr(1) := '0';
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SCAUSE         =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vscause;
          else
            csr := csr_file.scause;
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_STVAL          =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vstval;
          else
            csr := csr_file.stval;
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SIP            =>
          if h_en and csr_file.v = '1' then
            csr(9)  := csr_file.mip(10) and csr_file.hideleg(10);
            csr(5)  := csr_file.mip(6)  and csr_file.hideleg(6);
            csr(1)  := csr_file.mip(2)  and csr_file.hideleg(2);
          else
            csr := csr_file.mip and csr_file.mideleg;
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SSCRATCH       =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vsscratch;
          else
            csr := csr_file.sscratch;
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        -- Supervisor Protection and Translation
        when CSR_SATP           =>
          xc_v := vu_mode; -- virtual instruction exception
          if h_en and csr_file.v = '1' then
            if csr_file.prv = PRIV_LVL_S and csr_file.hstatus.vtvm = '1' then
              xc  := '1';
              xc_v := v_mode; -- virtual instruction exception
            else
              csr := csr_file.vsatp;
            end if;
          else
            if csr_file.prv = PRIV_LVL_S and csr_file.mstatus.tvm = '1' then
              xc  := '1';
            else
              csr := csr_file.satp;
            end if;
          end if;
        when CSR_STIMECMP     =>
          if envcfg.stce = '1' then
            if h_en and csr_file.v = '1' then
              if csr_file.hcounteren(1) = '0' or csr_file.mcounteren(1) = '0' then
                xc := '1';
              else
                csr := csr_file.vstimecmp(wordx'range);
              end if;
            else
              if csr_file.mcounteren(1) = '0' and csr_file.prv = PRIV_LVL_S then
                xc := '1';
              else
                csr := csr_file.stimecmp(wordx'range);
              end if;
            end if;
          else
            xc := '1';
          end if;
          if csr_file.menvcfg.stce = '1' and (csr_file.mcounteren(1) or not envcfg.stce) = '1' then
            xc_v := v_mode; -- virtual instruction exception
          end if;
        when CSR_STIMECMPH    =>
          if envcfg.stce = '1' and is_rv32 then 
            if h_en and csr_file.v = '1' then
              if csr_file.hcounteren(1) = '0' or csr_file.mcounteren(1) = '0' then
                xc := '1';
              else
                csr := to0x(csr_file.vstimecmp(63 downto 32));
              end if;
            else
              if csr_file.mcounteren(1) = '0' and csr_file.prv = PRIV_LVL_S then
                xc := '1';
              else
                csr := to0x(csr_file.stimecmp(63 downto 32));
              end if;
            end if;
          else
            xc := '1';
          end if;
          if csr_file.menvcfg.stce = '1' and (csr_file.mcounteren(1) or not envcfg.stce) = '1' then
            xc_v := v_mode; -- virtual instruction exception
          end if;
        -- Supervisor Count Overflow
        when CSR_SCOUNTOVF      =>
          if ext_sscofpmf = 0 or mode_s = 0 then
            xc         := '1';
          else
            for i in 3 to perf_cnts + 3 - 1 loop
              csr(i) := csr_file.hpmevent(i).overflow;
              if csr_file.mcounteren(i) = '0' then
                csr(i) := '0';
              elsif h_en and csr_file.v = '1' and
                    csr_file.hcounteren(i) = '0' then
                csr(i) := '0';
              end if;
            end loop;
          end if;
        -- Machine Information Registers
        when CSR_MVENDORID      => csr := CSR_VENDORID;
        when CSR_MARCHID        => csr := CSR_ARCHID;
        when CSR_MIMPID         => csr := CSR_IMPID;
        when CSR_MHARTID        => csr := to0x(hart);
        --  Machine Trap Setup
        when CSR_MSTATUS        => csr := to_mstatus(csr_file.mstatus);
        when CSR_MSTATUSH       =>
          if is_rv32 then
            csr := to_mstatush(csr_file.mstatus);
          else
            xc := '1';
          end if;
        when CSR_MISA           => csr := csr_file.misa;
        when CSR_MTVEC          => csr := csr_file.mtvec;
        when CSR_MEDELEG        =>
          if mode_s = 0
            then
            xc := '1';
          else
            csr := csr_file.medeleg;
          end if;
        when CSR_MIDELEG        =>
          if mode_s = 0
            then
            xc := '1';
          else
            csr := csr_file.mideleg;
          end if;
        when CSR_MIE            => csr := csr_file.mie;
        when CSR_MCOUNTEREN     => csr := to0x(csr_file.mcounteren);
        -- Machine Trap Handling
        when CSR_MSCRATCH       => csr := csr_file.mscratch;
        when CSR_MEPC           =>
          csr := csr_file.mepc;
          if ext_c = 1 and ISA_CONTROL(c_ctrl) = '1' and csr_file.misa(c_ctrl) = '0' then
            csr(1) := '0';
          end if;
        when CSR_MCAUSE         => csr := csr_file.mcause;
        when CSR_MTVAL          => csr := csr_file.mtval;
        when CSR_MIP            => csr := csr_file.mip;
        when CSR_MTINST         =>
          if h_en then
            csr := csr_file.mtinst;
          else
            xc := '1';
          end if;
        when CSR_MTVAL2         =>
          if h_en then
            csr := csr_file.mtval2;
          else
            xc := '1';
          end if;
        when CSR_MENVCFG        =>
          if mode_u = 1 then
            csr := to_envcfg(csr_file.menvcfg);
          else
            xc := '1';
          end if;
        when CSR_MENVCFGH       =>
          if mode_u = 1 and is_rv32 then
            csr := to_envcfgh(csr_file.menvcfg);
          else
            xc := '1';
          end if;
        -- Machine Protection and Translation
        when CSR_PMPCFG0        => csr := csr_file.pmpcfg0(wordx'range);
        when CSR_PMPCFG1        =>
          if is_rv32 then
            csr := to0x(csr_file.pmpcfg0(63 downto 32));
          else
            xc := '1';
          end if;
        when CSR_PMPCFG2        => csr := csr_file.pmpcfg2(wordx'range);
        when CSR_PMPCFG3        =>
          if is_rv32 then
            csr := to0x(csr_file.pmpcfg2(63 downto 32));
          else
            xc := '1';
          end if;
        -- Machine|User Counter/Timers
        when CSR_CYCLE |
             CSR_MCYCLE         => csr := csr_file.mcycle(wordx'range);
        when CSR_CYCLEH |
             CSR_MCYCLEH        =>
          if is_rv32 then
            csr := to0x(csr_file.mcycle(63 downto 32));
          else
            xc := '1';
          end if;
        when CSR_TIME           =>
          -- The time CSR is a read-only shadow of the memory-mapped mtime register.
          -- Implementations can convert reads of the time CSR into loads to the
          -- memory-mapped mtime register, or emulate this functionality in M-mode software.
          if time_en then
            if h_en and csr_file.v = '1' then
              csr := s_vtime(wordx'range);
            else
              csr := s_time(wordx'range);
            end if;
          else
            xc := '1';
          end if;
        when CSR_TIMEH          =>
          if is_rv32 and time_en then
            if h_en and csr_file.v = '1' then
              csr := to0x(s_vtime(63 downto 32));
            else
              csr := to0x(s_time(63 downto 32));
            end if;
          else
            xc := '1';
          end if;
        when CSR_INSTRET |
             CSR_MINSTRET       => csr := csr_file.minstret(wordx'range);
        when CSR_INSTRETH |
             CSR_MINSTRETH      =>
          if is_rv32 then
            csr := to0x(csr_file.minstret(63 downto 32));
          else
            xc := '1';
          end if;
        -- Machine Performance Monitoring Counter Selector
        when CSR_MCOUNTINHIBIT  => csr := to0x(csr_file.mcountinhibit);
        -- Debug/Trace Registers
        when CSR_TSELECT        =>
          csr := to0x(csr_file.tcsr.tselect);
          if TRIGGER = 0 then
            xc := '1';
          end if;
        when CSR_TDATA1         =>
          csr := csr_file.tcsr.tdata1(u2i(csr_file.tcsr.tselect));
          if TRIGGER = 0 then
            xc := '1';
          end if;
        when CSR_TDATA2         =>
          csr := csr_file.tcsr.tdata2(u2i(csr_file.tcsr.tselect));
          if TRIGGER = 0 then
            xc := '1';
          end if;
        when CSR_TDATA3         =>
          csr := csr_file.tcsr.tdata3(u2i(csr_file.tcsr.tselect));
          if TRIGGER = 0 then
            xc := '1';
          end if;
        when CSR_TINFO          =>
          csr := to0x(csr_file.tcsr.tinfo(u2i(csr_file.tcsr.tselect)));
          if TRIGGER = 0 then
            xc := '1';
          end if;
        -- Core Debug Registers
        when CSR_DCSR           =>
          csr(31 downto 28)     := csr_file.dcsr.xdebugver;
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
            csr(5)                := csr_file.dcsr.v;
          end if;
          csr(4)                := csr_file.dcsr.mprven;
          csr(3)                := csr_file.dcsr.nmip;
          csr(2)                := csr_file.dcsr.step;
          csr(1 downto 0)       := csr_file.dcsr.prv;
        when CSR_DPC            => csr := csr_file.dpc;
        when CSR_DSCRATCH0      => csr := csr_file.dscratch0;
        when CSR_DSCRATCH1      => csr := csr_file.dscratch1;
        when CSR_FEATURES       =>
          csr(31)               := csr_file.dfeaturesen.tpbuf_en;
          csr(30 downto 26)     := csr_file.trace.ctrl(12 downto 8);
          -- [25:14] RESERVED
          csr(13)               := csr_file.dfeaturesen.dm_trace;
          csr(12)               := csr_file.dfeaturesen.new_irq;
          csr(11)               := csr_file.dfeaturesen.fs_dirty;
          csr(10)               := csr_file.dfeaturesen.nostream;
          csr(9)                := csr_file.dfeaturesen.staticdir;
          csr(8)                := csr_file.dfeaturesen.staticbp;
          csr(7)                := csr_file.dfeaturesen.mmu_adfault;
          csr(6)                := csr_file.dfeaturesen.b2bst_dis;
          csr(5)                := csr_file.dfeaturesen.lalu_dis;
          csr(4)                := csr_file.dfeaturesen.lbranch_dis;
          csr(3)                := csr_file.dfeaturesen.ras_dis;
          csr(2)                := csr_file.dfeaturesen.jprd_dis;
          csr(1)                := csr_file.dfeaturesen.btb_dis;
          csr(0)                := csr_file.dfeaturesen.dual_dis;
        when CSR_FEATURESH      =>
          if is_rv32 then
          else
            xc := '1';
          end if;
        when CSR_CCTRL          =>
          csr(13)               := mmu_csr.cctrl.iflushpend;
          csr(12)               := mmu_csr.cctrl.dflushpend;
          -- Bit[11] is RESERVED
          if itcmen = 1 then
            csr(10)             := mmu_csr.cctrl.itcmwipe;
          end if;
          if dtcmen = 1 then
            csr(9)              := mmu_csr.cctrl.dtcmwipe;
          end if;
          csr(8)                := csr_file.cctrl.dsnoop;
          csr(7)                := csr_file.cctrl.dflush;
          csr(6)                := csr_file.cctrl.iflush;
          -- Bit[5:4] is RESERVED
          csr(3 downto 2)       := csr_file.cctrl.dcs;
          csr(1 downto 0)       := csr_file.cctrl.ics;
        when CSR_TCMICTRL       =>
          xc := '1';
        when CSR_TCMDCTRL       =>
          xc := '1';
        when CSR_CAPABILITY =>
          csr                   := to_capability(u2vec(fpuconf, 2), mmu_csr.cconfig);
        when CSR_CAPABILITYH =>
          if is_rv32 then
            csr(word'range)     := to_capabilityh(u2vec(fpuconf, 2), mmu_csr.cconfig);
          else
            xc := '1';
          end if;
        when others =>
          case csra_high is
            -- Machine|User Hardware Performance Monitoring
            when CSR_CYCLE |         -- Base for counters.
                 CSR_MCYCLE =>
              if csra_low = 1 then   -- There is no CSR_MTIME!
                xc := '1';
              end if;
              -- CSR_(M)HPMCOUNTER3-15  (0-2 never _ok here!)
              if counter_ok(csra_low) = '1' then
                csr := csr_file.hpmcounter(csra_low)(wordx'range);
              end if;
            when CSR_CYCLEH |         -- Base for counters.
                 CSR_MCYCLEH =>
              if not is_rv32 or csra_low = 1 then   -- There is no CSR_MTIMEH!
                xc := '1';
              end if;
              -- CSR_(M)HPMCOUNTER3-15H  (0-2 never _ok here!)
              if is_rv32 and counter_ok(csra_low) = '1' then
                csr := to0x(csr_file.hpmcounter(csra_low)(63 downto 32));
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
              if not is_rv32 then
                xc := '1';
              end if;
              -- CSR_(M)HPMCOUNTER16-31H
              if is_rv32 and counter_ok(csra_low + 16) = '1' then
                csr := to0x(csr_file.hpmcounter(csra_low + 16)(63 downto 32));
              end if;
            -- According to the RISC-V documentation, the value read back from
            -- CSR_PMPADDR<x> will depend on pmpcfg<x> setting under some circumstances.
            when CSR_PMPADDR0 =>
              if csra_low < pmp_entries then
                csr(pmp_msb - 2 downto 0) := csr_file.pmpaddr(csra_low)(pmp_msb - 2 downto 0);
                if pmpcfg(pmp_entries, csr_file, csra_low)(4) = '1' then  -- NA4/NAPOT
                  csr(pmp_g - 2 downto 0) := (others => '1');
                else                                                      -- OFF/TOR
                  csr(pmp_g - 1 downto 0) := (others => '0');
                end if;
              end if;
            -- Machine Performance Monitoring Counter Selector
            when CSR_MCOUNTINHIBIT =>  -- MCOUNTINHIBIT/MHPMEVENT3-15
              if csra_low = 1 or       --  There is nothing at second/third position.
                 csra_low = 2 then
                xc := '1';
              end if;
              -- CSR_MHPMEVENT3-15  (0-2 never _ok here!)
              if counter_ok(csra_low) = '1' then
                csr := to_hpmevent(csr_file.hpmevent(csra_low));
              end if;
            when CSR_MHPMEVENT16 =>  -- MHPMEVENT16-31
              if counter_ok(csra_low + 16) = '1' then
                csr := to_hpmevent(csr_file.hpmevent(csra_low + 16));
              end if;
            when CSR_MHPMEVENT0H =>  -- MHPMEVENT3-15H
              if not is_rv32 or csra_low < 3 then  --  There is nothing at 0-2.
                xc := '1';
              end if;
              -- CSR_MHPMEVENT3-15  (0-2 never _ok here!)
              if is_rv32 and counter_ok(csra_low) = '1' then
                csr := to_hpmeventh(csr_file.hpmevent(csra_low));
              end if;
            when CSR_MHPMEVENT16H =>  -- MHPMEVENT16-31H
              if not is_rv32 then
                xc := '1';
              end if;
              if is_rv32 and counter_ok(csra_low + 16) = '1' then
                csr := to_hpmeventh(csr_file.hpmevent(csra_low + 16));
              end if;
            when others =>
              xc := '1';
          end case;
      end case;
    end if;

    -- Check for privileged level and read/write accessibility
    -- The standard RISC-V ISA sets aside a 12-bit encoding space (csr[11:0])
    -- for up to 4,096 CSRs. By convention, the upper 4 bits of the CSR address
    -- (csr[11:8]) are used to encode the read and write accessibility of the
    -- CSRs according to privilege level as shown in Table 2.1. The top two
    -- bits (csr[11:10]) indicate whether the register is read/write (00, 01, or 10)
    -- or read-only (11). The next two bits (csr[9:8]) encode the lowest privilege
    -- level that can access the CSR.
    if rstate_in = run and csrv_in = '1' then
      -- Lower Privileged Level
      priv_lvl    := csr_file.prv and csra_in(9 downto 8);
      priv_lvlv   := csr_file.prv and csra_in(9 downto 8);
      if h_en and csr_file.v = '0' then
        priv_lvlv := (csr_file.prv(0) & csr_file.prv(1)) and csra_in(9 downto 8);
      end if;
        if priv_lvl  /= csra_in(9 downto 8) and
           priv_lvlv /= csra_in(9 downto 8) then
          xc      := '1';
        end if;
        -- Debug Module Registers Access
        if csra_in(11 downto 4) = "01111011" then
          xc      := '1';
        end if;
      -- Performance Features
      -- Hardware Performance Features
      -- (CYCLE, TIME, INSTRET, HPMCOUNTERn)
      -- Bit 7 is high for the ...H CSR variants.
      if csra_in(11 downto 8) = x"c" and csra_in(6 downto 5) = "00" then
        if csr_file.mcounteren(u2i(csra_in(4 downto 0))) = '0' then
          if csr_file.prv = PRIV_LVL_S or csr_file.prv = PRIV_LVL_U then
            xc := '1';
          end if;
        elsif h_en and csr_file.v = '1' and
              csr_file.hcounteren(u2i(csra_in(4 downto 0))) = '0' then
          xc   := '1';
          xc_v := '1';
        elsif mode_u = 1 and csr_file.prv = PRIV_LVL_U and
              csr_file.scounteren(u2i(csra_in(4 downto 0))) = '0' then
          xc   := '1';
        end if;
      end if;
    end if;

    -- Mask output if exception occured.
    if xc = '1' then
      csr       := zerox;
    end if;

    data_out    := csr;
    xc_out      := xc;
    if xc_v = '1' then
      cause_out := XC_INST_VIRTUAL_INST;  -- Only valid when xc_out.
    else
      cause_out := XC_INST_ILLEGAL_INST;  -- Only valid when xc_out.
    end if;
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
              r.wb.lalu(1) = '1' and v_rd_eq(r, wb, 1, rfa2) then
          data := r.wb.wdata(1);
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
    variable debug : boolean   := false;
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
            v_rd_eq(r, late, 1, rfa1) and v_fusel_eq(r, late, 1, MUL or FPU) then
        op1   := "001";
      elsif v_rd_eq(r, late, 0, rfa1) then
        if    v_fusel_eq(r, late, 0, LD) then
          op1 := "010";
        elsif v_fusel_eq(r, late, 0, MUL or FPU) then
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
            v_rd_eq(r, late, 1, rfa2) and v_fusel_eq(r, late, 1, MUL or FPU) then
        op2   := "001";
      elsif v_rd_eq(r, late, 0, rfa2) then
        if    v_fusel_eq(r, late, 0, LD) then
          op2 := "010";
        elsif v_fusel_eq(r, late, 0, MUL or FPU) then
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
    when "10"   => op1 := r.x.data(0)(wordx'range);
    when "11"   => op1 := r.x.result(0);
    when others =>
    end case;

    -- Op2
    -- Do not forward for Store operation.


    case forw_op2 is
    when "01"   => op2 := r.x.result(one);
    when "10"   => op2 := r.x.data(0)(wordx'range);
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
    when "10"   => op1 := r.x.data(0)(wordx'range);
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
    variable debug : boolean     := false;
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
    elsif single_issue = 0                              and
          v_rd_eq(r, same, nlane, rfa1)                 and
          v_fusel_eq(r, same, nlane, MUL or ALU or FPU) and
          (slane xor swap) = '1' then
      op1       := "010";
    -- Get value from late ALU:
    -- lane | stage | instr
    --   0  |   wb  | ld x1, 0(x2)
    --   1  |   wb  | addi x2, x1, 3
    --   0  |   x   | add x1, x2, x0
    --   1  |   x   | ...
    elsif single_issue = 0 and
          v_rd_eq(r, late, 1, rfa1) then
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
    elsif single_issue = 0                              and
          v_rd_eq(r, same, nlane, rfa2)                 and
          v_fusel_eq(r, same, nlane, MUL or ALU or FPU) and
          (slane xor swap) = '1' then
      op2       := "010";
    elsif single_issue = 0 and
          v_rd_eq(r, late, 1, rfa2) then
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
    when "001"  => op1 := r.x.data(0)(wordx'range);
    when "010"  => op1 := r.x.result(nlane);
    when "011"  => op1 := r.wb.wdata(one);
    when "100"  => op1 := r.wb.wdata(0);
    when others =>
    end case;

    -- Op2 First Stage Mux
    case forw_op2 is
    when "001"  => op2 := r.x.data(0)(wordx'range);
    when "010"  => op2 := r.x.result(nlane);
    when "011"  => op2 := r.wb.wdata(one);
    when "100"  => op2 := r.wb.wdata(0);
    when others =>
    end case;

    op1_out := op1;
    op2_out := op2;
  end;

  -- Limited version of xc_alu_preforwarding
  -- Used when only CSRs do calculations in exception stage.
  procedure xc_csr_preforward(r       : in  registers;
                              lane    : in  lanes_range;
                              op1_out : out std_logic_vector) is
    variable rfa1  : rfa_tuple   := rfa(1, x, lane);
    variable debug : boolean     := false;
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
    elsif single_issue = 0                           and
          v_rd_eq(r, x, nlane, rfa1)                 and
          v_fusel_eq(r, x, nlane, MUL or ALU or FPU) and
          (slane xor swap) = '1' then
      op1       := "010";
    -- Get value from late ALU:
    -- lane | stage | instr
    --   0  |   wb  | ld x1, 0(x2)
    --   1  |   wb  | addi x2, x1, 3
    --   0  |   x   | add x1, x2, x0
    --   1  |   x   | ...
    elsif single_issue = 0 and
          v_rd_eq(r, wb, 1, rfa1) then
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
    when "001"  => op1 := r.x.data(0)(wordx'range);
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
    type     op_data_t     is array (rfa'range) of wordx;
    variable rf_in          : op_data_t := (1 => rf1_in, 2 => rf2_in);
    -- Non-constant
    variable op1            : wordx;
    variable op2            : wordx;
    variable mux_output_op1 : wordx;
    variable mux_output_op2 : wordx;
    variable wb_forw_op1    : word2     := "00";
    variable wb_forw_op2    : word2     := "00";
    variable xc_forw_op1    : word2     := "00";
    variable xc_forw_op2    : word2     := "00";
    variable mem_forw_op1   : word2     := "00";
    variable mem_forw_op2   : word2     := "00";
    variable ex_forw_op1    : word2     := "00";
    variable ex_forw_op2    : word2     := "00";
  begin

    -- Compute mux forwarding signals
    -- bit(1) indicates forwarding should happen from that stage
    -- bit(0) indicates from which lane the data should be forwarded

    -- Op1
    if    single_issue = 0 and
          v_rd_eq_xrdv(r, e,  1, ex1_rdv_in, rfa1) then
      ex_forw_op1    := "11";
    elsif v_rd_eq_xrdv(r, e,  0, ex0_rdv_in, rfa1) then
      ex_forw_op1    := "10";
    elsif single_issue = 0 and
          v_rd_eq(r, m,  1, rfa1) then
      mem_forw_op1 := "11";
    elsif v_rd_eq(r, m,  0, rfa1) then
      -- Do not forward directly from cache access.
      -- Handled by forwarding in next cycle instead.
      if not v_fusel_eq(r, m, memory_lane, LD) then
        mem_forw_op1 := "10";
      end if;
    elsif single_issue = 0 and
          v_rd_eq(r, x,  1, rfa1) then
      xc_forw_op1    := "11";
    elsif v_rd_eq(r, x,  0, rfa1) then
      xc_forw_op1    := "10";
    elsif single_issue = 0 and
          v_rd_eq(r, wb, 1, rfa1) then
      wb_forw_op1    := "11";
    elsif v_rd_eq(r, wb, 0, rfa1) then
      wb_forw_op1    := "10";
    end if;

    -- Op2
    if    single_issue = 0 and
          v_rd_eq_xrdv(r, e,  1, ex1_rdv_in, rfa2) then
      ex_forw_op2    := "11";
    elsif v_rd_eq_xrdv(r, e,  0, ex0_rdv_in, rfa2) then
      ex_forw_op2    := "10";
    elsif single_issue = 0 and
          v_rd_eq(r, m,  1, rfa2) then
      mem_forw_op2 := "11";
    elsif v_rd_eq(r, m,  0, rfa2) then
      -- Do not forward directly from cache access.
      -- Handled by forwarding in next cycle instead.
      if not v_fusel_eq(r, m, memory_lane, LD) then
        mem_forw_op2 := "10";
      end if;
    elsif single_issue = 0 and
          v_rd_eq(r, x,  1, rfa2) then
      xc_forw_op2    := "11";
    elsif v_rd_eq(r, x,  0, rfa2) then
      xc_forw_op2    := "10";
    elsif single_issue = 0 and
          v_rd_eq(r, wb, 1, rfa2) then
      wb_forw_op2    := "11";
    elsif v_rd_eq(r, wb, 0, rfa2) then
      wb_forw_op2    := "10";
    end if;


    -- First Stage Mux for Op1
    if r.a.pcv(lane) = '1' then
      mux_output_op1     := pc2xlen(r.a.ctrl(lane).pc);
    elsif xc_forw_op1 = "10" then
      if v_fusel_eq(r, x, 0, LD) then
        mux_output_op1   := r.x.data(0)(wordx'range);
      else
        if r.x.alu(0).lalu = '1' then
          mux_output_op1 := xc_data_in(0);
        else
          mux_output_op1 := r.x.result(0);
        end if;
      end if;
    elsif single_issue = 0 and
          xc_forw_op1 = "11" then
      if r.x.alu(one).lalu = '1' then
        mux_output_op1   := xc_data_in(one);
      else
        mux_output_op1   := r.x.result(one);
      end if;
    elsif mem_forw_op1 = "10" then
      if v_fusel_eq(r, m, 0, MUL) then
        mux_output_op1   := mul_data_in(0);
      else
        mux_output_op1   := r.m.result(0);
      end if;
    elsif single_issue = 0 and
          mem_forw_op1 = "11" then
      if v_fusel_eq(r, m, 1, MUL) then
        mux_output_op1   := mul_data_in(one);
      else
        mux_output_op1   := r.m.result(one);
      end if;
    elsif wb_forw_op1 = "10" then
      mux_output_op1     := r.wb.wdata(0);
    elsif single_issue = 0 and
          wb_forw_op1 = "11" then
      mux_output_op1     := r.wb.wdata(one);
    end if;

    -- Second Stage Mux for Op1
    if xc_forw_op1(1) = '1' or mem_forw_op1(1) = '1' or
       wb_forw_op1(1) = '1' or r.a.pcv(lane)   = '1' then
      op1                := mux_output_op1;
    elsif single_issue = 0 and
          ex_forw_op1 = "11" then
      op1                := ex_data_in(one);
    elsif ex_forw_op1 = "10" then
      op1                := ex_data_in(0);
    else
      op1                := rf1_in;
    end if;

    -- First Stage Mux for Op2
      -- True even with zimm, but do not forward imm generated fron Branch.
    if r.a.immv(lane) = '1' and r.a.ctrl(lane).inst(6 downto 0) /= OP_BRANCH then
      mux_output_op2     := r.a.imm(lane);
    elsif xc_forw_op2 = "10" then
      if v_fusel_eq(r, x, 0, LD) then
        mux_output_op2   := r.x.data(0)(wordx'range);
      else
        if r.x.alu(0).lalu = '1' then
          mux_output_op2 := xc_data_in(0);
        else
          mux_output_op2 := r.x.result(0);
        end if;
      end if;
    elsif single_issue = 0 and
          xc_forw_op2 = "11" then
      if r.x.alu(one).lalu = '1' then
        mux_output_op2   := xc_data_in(one);
      else
        mux_output_op2   := r.x.result(one);
      end if;
    elsif mem_forw_op2 = "10" then
      if v_fusel_eq(r, m, 0, MUL) then
        mux_output_op2   := mul_data_in(0);
      else
        mux_output_op2   := r.m.result(0);
      end if;
    elsif single_issue = 0 and
          mem_forw_op2 = "11" then
      if v_fusel_eq(r, m, 1, MUL) then
        mux_output_op2   := mul_data_in(one);
      else
        mux_output_op2   := r.m.result(one);
      end if;
    elsif wb_forw_op2 = "10" then
      mux_output_op2     := r.wb.wdata(0);
    elsif single_issue = 0 and
          wb_forw_op2 = "11" then
      mux_output_op2     := r.wb.wdata(one);
    end if;

    -- Second Stage Mux for Op2
    if xc_forw_op2(1) = '1' or mem_forw_op2(1) = '1' or wb_forw_op2(1) = '1' or
       (r.a.immv(lane) = '1' and r.a.ctrl(lane).inst(6 downto 0) /= OP_BRANCH) then
      op2                := mux_output_op2;
    elsif single_issue = 0 and
          ex_forw_op2 = "11" then
      op2                := ex_data_in(one);
    elsif ex_forw_op2 = "10" then
      op2                := ex_data_in(0);
    else
      op2                := rf2_in;
    end if;

    op1_out              := op1;
    op2_out              := op2;
    forw_out(1)          := ex_forw_op1(1) or mem_forw_op1(1) or xc_forw_op1(1) or wb_forw_op1(1);
    forw_out(2)          := ex_forw_op2(1) or mem_forw_op2(1) or xc_forw_op2(1) or wb_forw_op2(1);
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
          v_rd_eq_xrdv(r, e,  1, ex1_rdv_in, rfa1) then
      ex_forw_op1       := "11";
    elsif v_rd_eq_xrdv(r, e,  0, ex0_rdv_in, rfa1) then
      ex_forw_op1       := "10";
    elsif single_issue = 0 and
          v_rd_eq(r, m,  1, rfa1) then
      mem_forw_op1      := "11";
    elsif v_rd_eq(r, m,  0, rfa1) then
      -- Do not forward directly from cache access.
      -- Handled by forwarding in next cycle instead.
      if not v_fusel_eq(r, m, memory_lane, LD) then
        mem_forw_op1    := "10";
      end if;
    elsif single_issue = 0 and
          v_rd_eq(r, x,  1, rfa1) then
      xc_forw_op1       := "11";
    elsif v_rd_eq(r, x,  0, rfa1) then
      xc_forw_op1       := "10";
    elsif single_issue = 0 and
          v_rd_eq(r, wb, 1, rfa1) then
      wb_forw_op1       := "11";
    elsif v_rd_eq(r, wb, 0, rfa1) then
      wb_forw_op1       := "10";
    end if;

    -- First Stage Mux for Op1
    if xc_forw_op1 = "10" then
      if v_fusel_eq(r, x, 0, LD) then
        mux_output_op1  := r.x.data(0)(wordx'range);
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
      if v_fusel_eq(r, m, 1, MUL) then
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

  -- Jump Unit for JAL and JALR instructions
  procedure jump_unit(ctrl_in   : in  pipeline_ctrl_type;
                      imm_in    : in  wordx;
                      ras_in    : in  nv_ras_out_type;
                      rf1       : in  wordx;
                      flush_in  : in  std_ulogic;
                      jump_out  : out std_ulogic;
                      mem_jump  : out std_ulogic;
                      xc_out    : out std_ulogic;
                      cause_out : out cause_type;
                      tval_out  : out wordx;
                      addr_out  : out pctype) is
    -- Non-constant
    variable op1         : wordx;
    variable target      : wordx;
    variable jump_xc     : std_ulogic;
    variable memjump_xc  : std_ulogic;
    variable jump        : std_ulogic := '0';
    variable mem_jumpt   : std_ulogic;
    variable tval        : wordx;
  begin
    -- Jump in case of:
    -- * Valid JALR instruction and ras_in.hit = '0' or address mismatch

    -- Operations:
    -- * JALR   -> rs1 + sign_extend(imm)
    target       := std_logic_vector(signed(rf1) + signed(imm_in));

    -- Generate Jump Signal
    if ctrl_in.valid = '1' and v_fusel_eq(ctrl_in.fusel, JALR) and flush_in = '0' then
        jump     := '1';
    end if;


    mem_jumpt := '0';

    -- Setting the least-significat bit to zero.
    target(0)    := '0';

    -- Generate Exception Signal due to Address Misaligned.
    jump_xc := '0';
    if jump = '1' and inst_addr_misaligned(active_extensions, target) then
      jump_xc    := '1';
    end if;

    -- Decouple jump and memjump_xc to not affect the critical path.
    memjump_xc   := '0';
    if mem_jumpt = '1' and inst_addr_misaligned(active_extensions, target) then
      memjump_xc := '1';
    end if;

    xc_out       := jump_xc or memjump_xc;
    cause_out    := XC_INST_ADDR_MISALIGNED;  -- Only valid when xc_out.
    addr_out     := to_addr(target);
    tval_out     := target;
    jump_out     := jump and not jump_xc;
    mem_jump     := mem_jumpt and not memjump_xc;
  end;

  -- Resolve Unconditional Jumps
  procedure ujump_resolve(ctrl_in   : in  pipeline_ctrl_type;
                          target_in : in  pctype;
                          next_in   : in  pctype;
                          taken_in  : in  std_ulogic;
                          hit_in    : in  std_ulogic;
                          xc_out    : out std_ulogic;
                          cause_out : out cause_type;
                          tval_out  : out wordx;
                          jump_out  : out std_ulogic;
                          addr_out  : out pctype) is
    variable inst   : word       := ctrl_in.inst;
    -- Non-constant
    variable target : pctype     := target_in;
    variable xc     : std_ulogic := '0';
    variable jump   : std_ulogic := '0';
    variable mis    : std_ulogic := '0';
  begin
    -- Jump here in case of:
    --        * taken_in = 0 -> We did not get a hit from prediction
    --        * taken_in = 1 and not JAL -> We get an alias

    -- Generate Misprediction Signal due to wrong instruction.
    if (taken_in and hit_in and ctrl_in.valid) = '1' and ctrl_in.xc = '0' then
      if inst(6 downto 0) /= OP_JAL and inst(6 downto 0) /= OP_BRANCH then
        mis     := '1';
        target  := next_in;
      end if;
    end if;

    -- Generate Jump Signal
    if ctrl_in.valid = '1' and ctrl_in.xc = '0' and inst(6 downto 0) = OP_JAL and (taken_in and hit_in) = '0' then
      jump      := '1';
    end if;

    -- Generate Exception Signal
    if jump = '1' and inst_addr_misaligned(active_extensions, target) then
      xc        := '1';
    end if;

    xc_out      := xc;
    cause_out   := XC_INST_ADDR_MISALIGNED;  -- Only valid when xc_out.
    tval_out    := pc2xlen(target);
    addr_out    := target;
    jump_out    := (jump or mis) and not xc;
  end;

  -- Resolve Early Branch in Decode Stage.
  procedure branch_resolve(ctrl_in    : in  pipeline_ctrl_type;
                           taken_in   : in  std_ulogic;
                           hit_in     : in  std_ulogic;
                           imm_in     : in  wordx;
                           valid_out  : out std_ulogic;
                           branch_out : out std_ulogic;
                           taken_out  : out std_ulogic;
                           hit_out    : out std_ulogic;
                           xc_out     : out std_ulogic;
                           cause_out  : out cause_type;
                           next_out   : out pctype;
                           addr_out   : out pctype) is
    -- Non-constant
    variable valid   : std_ulogic := '0';
    variable xc      : std_ulogic := '0';
    variable pc      : wordx;
    variable target  : wordx;
    variable nextpc  : pctype;
    variable brancho : std_ulogic;
  begin
    -- Signal to branch in decode stage in case we got a taken from bht
    -- but the btb does not have the target address where to branch.
    brancho     := taken_in and not hit_in;

    -- Check if branch
    if ctrl_in.valid = '1' and ctrl_in.xc = '0' and v_fusel_eq(ctrl_in.fusel, BRANCH) then
      valid     := '1';
    end if;

    -- Operations:
    -- * BRANCH -> pc + sign_extend(imm)
    pc          := pc2xlen(ctrl_in.pc);
    target      := std_logic_vector(signed(pc) + signed(imm_in));
    nextpc      := npc_adder(ctrl_in.pc, ctrl_in.comp);

    -- Generate Exception Signal
    if valid = '1' and taken_in = '1' and inst_addr_misaligned(active_extensions, target) then
      xc        := '1';
    end if;

    -- Generate Output
    addr_out    := to_addr(target);
    next_out    := nextpc;
    valid_out   := valid;
    branch_out  := brancho and valid;
    -- Taken signal for later stage of the pipeline
    taken_out   := taken_in and valid;
    xc_out      := xc;
    cause_out   := XC_INST_ADDR_MISALIGNED;  -- Only valid when xc_out.
    hit_out     := hit_in;
  end;

  procedure branch_misc(ctrl_in   : in  pipeline_ctrl_type;
                        taken_in  : in  std_ulogic;
                        hit_in    : in  std_ulogic;
                        imm_in    : in  wordx_pair_type;
                        swap      : in  std_logic;
                        valid_out : out std_ulogic;
                        taken_out : out std_ulogic;
                        hit_out   : out std_ulogic;
                        xc_out    : out std_ulogic;
                        cause_out : out cause_type;
                        next_out  : out pctype;
                        addr_out  : out pctype) is
    -- Non-constant
    variable valid  : std_ulogic := '0';
    variable xc     : std_ulogic := '0';
    variable pc     : wordx;
    variable target_l0 : wordx;
    variable target_l1 : wordx;
    variable target : wordx;
    variable nextpc : pctype;
  begin
    -- Check if branch
    if ctrl_in.valid = '1' and ctrl_in.xc = '0' and v_fusel_eq(ctrl_in.fusel, BRANCH) then
      valid := '1';
    end if;

    -- Operations:
    -- * BRANCH -> pc + sign_extend(imm)
    pc     := pc2xlen(ctrl_in.pc);

    target_l0 := std_logic_vector(signed(pc) + signed(imm_in(0)));
    target_l1 := std_logic_vector(signed(pc) + signed(imm_in(1)));

    if branch_lane = 0 then
      target := target_l0;
      if swap = '1' then
        target := target_l1;
      end if;
    else
      target := target_l1;
      if swap = '1' then
        target := target_l0;
      end if;
    end if;

    nextpc := npc_adder(ctrl_in.pc, ctrl_in.comp);

    -- Generate Exception Signal
    if valid = '1' and taken_in = '1' and inst_addr_misaligned(active_extensions, target) then
      xc := '1';
    end if;

    -- Generate Output
    addr_out  := to_addr(target);
    next_out  := nextpc;
    valid_out := valid;
    taken_out := taken_in and valid;
    xc_out    := xc;
    cause_out := XC_INST_ADDR_MISALIGNED;  -- Only valid when xc_out.
    hit_out   := hit_in;
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
                       dci_out     : out dcache_in_type) is
    variable funct3 : funct3_type    := inst_in(14 downto 12);
    -- Non-constant
    variable dci    : dcache_in_type := dcache_in_none;
  begin
    -- Drive Cache Signal
    dci.signed := not funct3(2);
    dci.size   := funct3(1 downto 0);
    -- During normal operation, the LEON5 processor accesses instructions
    -- and data using ASI 0x8 - 0xB, so we do the same.
    dci.asi  := "00001010";

    dci.mxr   := mxr_in;
    dci.vmxr  := vmxr_in;
    dci.vms    := v_in & prv_in;
    if mprv_in = '1' then -- M-mode is assumed
      dci.vms  := mpv_in & mpp_in;
    end if;

    dci.hx     := '0';
    dci.sum    := '0';
    if prv_in = PRIV_LVL_S or                       -- HS-mode or VS-mode
       (mprv_in = '1' and mpp_in = PRIV_LVL_S) then -- M-mode, access as through HS-mode or VS-mode
      if ext_h /= 0 and (v_in = '1' or (mprv_in and mpv_in) = '1') then
        dci.sum := vsum_in;
      else
        dci.sum := sum_in;
      end if;
    end if;
    if ext_h /= 0 and (is_hlv(inst_in) or is_hsv(inst_in)) then
      dci.vms         := "10" & spvp_in;
      dci.sum         := vsum_in;
      dci.hx          := inst_in(21) and not inst_in(25); -- HLVX
    end if;

    if valid_in = '1' then
      if v_fusel_eq(fusel_in, LD or ST) and misaligned = '0' then
        dci.enaddr      := '1';
        dci.write       := inst_in(5);
        dci.read        := not inst_in(5);
        dci.amo         := (others => '0');
        if ext_a /= 0 and v_fusel_eq(fusel_in, AMO) then
          dci.amo := '1' & inst_in(31 downto 27);
          if inst_in(28) = '1' then   -- LRSC
            if inst_in(27) = '0' then -- LR
              dci.write := '0';
              dci.read  := '1';
            else                      -- SC
              dci.write := '1';
              dci.read  := '0';
              dci.lock  := '1';
            end if;
          else                        -- AMO
            dci.write   := '1';
            dci.read    := '1';
            dci.lock    := '1';
          end if;
        end if;
        if ext_h /= 0 and (is_hlv(inst_in) or is_hsv(inst_in)) then
          dci.write       := inst_in(25);
          dci.read        := not inst_in(25);
          dci.signed      := not inst_in(20);
          dci.size        := inst_in(27 downto 26);
        end if;
        if v_fusel_eq(fusel_in, DIAG) then
          if is_diag_store(inst_in) then
            dci.write   := '1';
            dci.read    := '0';
            dci.asi     := to_asi_store(inst_in);
          else
            dci.write   := '0';
            dci.read    := '1';
            dci.asi     := to_asi_load(inst_in);
          end if;
        end if;
      -- We encode a fence_i instruction in an instruction
      -- that flushes and enables both caches.
--      elsif is_fence_i(inst_in) then
--        dci.asi         := "00000010";
--        dci.write       := '1';
--        dci.enaddr      := '1';
--        dci.size        := "10";
      -- We encode an sfence.vma instruction in an instruction
      -- that flushes caches amd TLB.
      elsif is_sfence_vma(inst_in) then
        dci.asi         := "00011000";
        dci.write       := '1';
        dci.enaddr      := '1';
        dci.size        := "10";
      elsif is_hfence_vvma(inst_in) or is_hfence_gvma(inst_in) then
        dci.asi         := "00011000";
        dci.write       := '1';
        dci.enaddr      := '1';
        dci.size        := "10";
      elsif is_cbo(inst_in) and inst_in(20) = '0' then -- Clean = NOP, inval/flush = inval
        dci.cbo         := "100";
        dci.write       := '0';
        dci.read        := '1';
        dci.enaddr      := '1';
        dci.size        := "10";
      end if;
    end if;

    dci_out := dci;
  end;

  -- Load aligner
  function ld_align_fast(data   : dcdtype;
                         way    : std_logic_vector(DWAYMSB downto 0);
                         size   : word2;
                         laddr  : word3;
                         signed : std_ulogic) return word64 is
    -- Non-constant
    variable rdata : dcdtype;
  begin
    for i in 0 to dways-1 loop
      rdata(i) := ld_align64(data(i), size, laddr, signed);
    end loop;

    return rdata(u2i(way));
  end;

  -- Generate data to store
  procedure stdata_unit(r        : in  registers;
                        data_out : out word64) is
    variable op     : opcode_type := r.m.ctrl(memory_lane).inst(6 downto 0);
    variable rfa2   : rfatype     := r.m.ctrl(memory_lane).inst(24 downto 20);
    -- Hypervisor store instruction
    variable hsv    : boolean     := (ext_h /= 0) and is_hsv(r.m.ctrl(memory_lane).inst);
    -- Non-constant
    variable data   : word64      := to64(r.m.stdata);
    variable mvalid : std_ulogic  := '1';
    variable mdata  : wordx;
  begin
    -- Opt for a 2 stage mux

    -- Forwarding Logic
    -- A LOAD, which could cause a lane swap, is guaranteed by dual_issue_check()
    -- to not be paired with anything that has the same destination.
    if    v_fusel_eq(r, x, 0, LD)  and v_rd_eq(r, x, 0, rfa2) then
      mdata     := r.x.data(0)(wordx'range);
    elsif single_issue = 0 and
          v_fusel_eq(r, x, 1, MUL or FPU) and v_rd_eq(r, x, 1, rfa2) then
      mdata     := r.x.result(one);
    elsif v_fusel_eq(r, x, 0, MUL or FPU) and v_rd_eq(r, x, 0, rfa2) and
          (single_issue = 1 or not v_rd_eq(r, x, 1, rfa2)) then
      mdata     := r.x.result(0);
    -- Forward from late ALUs or late Results
    elsif single_issue = 0 and
          (r.wb.lalu(1) = '1' or v_fusel_eq(r, wb, 1, MUL or FPU)) and
          v_rd_eq(r, wb, 1, rfa2) and r.m.stforw(0) = '0' then
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
       v_fusel_eq(r, m, 1, ALU) and v_rd_eq(r, m, 1, rfa2) and r.m.swap = '1' then
      data      := to64(r.m.result(one));
    -- Forward from something above?
    elsif mvalid = '1' then
      data      := to64(mdata);
    end if;

    if op = OP_STORE_FP  then
      data      := r.m.fpdata;
    end if;

    -- Replicate word/halfword/byte
    if    (not hsv and r.m.ctrl(memory_lane).inst(13 downto 12) = "10") or
          (    hsv and r.m.ctrl(memory_lane).inst(27 downto 26) = "10") then -- SW
      data(63 downto 32) := data(31 downto 0);
    elsif (not hsv and r.m.ctrl(memory_lane).inst(13 downto 12) = "01") or
          (    hsv and r.m.ctrl(memory_lane).inst(27 downto 26) = "01") then -- SH
      data(63 downto 48) := data(15 downto 0);
      data(47 downto 32) := data(15 downto 0);
      data(31 downto 16) := data(15 downto 0);
    elsif (not hsv and r.m.ctrl(memory_lane).inst(13 downto 12) = "00") or
          (    hsv and r.m.ctrl(memory_lane).inst(27 downto 26) = "00") then -- SB
      data(63 downto 56) := data(7 downto 0);
      data(55 downto 48) := data(7 downto 0);
      data(47 downto 40) := data(7 downto 0);
      data(39 downto 32) := data(7 downto 0);
      data(31 downto 24) := data(7 downto 0);
      data(23 downto 16) := data(7 downto 0);
      data(15 downto 8)  := data(7 downto 0);
    end if;

--    if is_fence_i(r.m.ctrl(0).inst) then
--      data(31 downto 0)  := x"0081000f";
--      data(63 downto 32) := x"0081000f";
--    end if;

    -- Hold data in case of holdn from cache
    if holdn = '0' then
      data   := r.x.data(0);
    end if;

    data_out := data;
  end;


  -- Memory Stage Exception Handling
  procedure me_exceptions(ctrl_in            : in  pipeline_ctrl_lanes_type;
                          dcache_xc_in       : in  std_ulogic;
                          dcache_xc_cause_in : in  cause_type;
                          dcache_xc_tval_in  : in  std_logic_vector;
                          ret_out            : out std_logic_vector;
                          xc_out             : out std_logic_vector;
                          cause_out          : out cause_lanes_type;
                          tval_out           : out wordx_lanes_type) is
    -- Non-constant
    variable xc    : lanes_type;
    variable cause : cause_lanes_type;
    variable tval  : wordx_lanes_type;
    variable ret   : word2 := (others => '0');
  begin
    for i in lanes'range loop
      xc(i)             := ctrl_in(i).xc;
      cause(i)          := ctrl_in(i).cause;
      tval(i)           := ctrl_in(i).tval;
    end loop;


    -- Evaluate Trap-Return Instructions
    for i in lanes'range loop
      if ctrl_in(i).xc = '0' and ctrl_in(i).valid = '1' then
        if ctrl_in(i).inst(24 downto 7) = "000100000000000000" and ctrl_in(i).inst(6 downto 0) = OP_SYSTEM then
          if ctrl_in(i).inst(31 downto 25) = F7_SRET then
            xc(i)       := '1';
            cause(i)    := XC_INST_ENV_CALL_SMODE;
            tval(i)     := zerox;
            ret         := "01";
          elsif ctrl_in(i).inst(31 downto 25) = F7_MRET then
            xc(i)       := '1';
            cause(i)    := XC_INST_ENV_CALL_MMODE;
            tval(i)     := zerox;
            ret         := "11";
          end if;
        end if;
      end if;
    end loop;

    -- Drive outputs
    xc_out              := xc;
    cause_out           := cause;
    tval_out            := tval;
    ret_out             := ret;
  end;

  -- Nullify dor DCache
  procedure null_dcache_gen(xc_flush_in : in  std_ulogic;
                            me_xc_in    : in  std_logic_vector;
                            mem_branch  : in  std_ulogic;
                            inst        : in  std_logic_vector;
                            valid_in    : in  std_logic_vector;
                            swap_in     : in  std_ulogic;
                            nullify_out : out std_ulogic) is
    -- Non-constant
    variable nullify : std_ulogic := '0';
  begin
    if xc_flush_in = '1'                         or       -- flush from xc
       mem_branch = '1'                          or       -- mem branch missp
       (me_xc_in(0) = '1' and valid_in(0) = '1') or       -- xc in LD/ST op
       (single_issue = 0 and                              -- xc in previous instruction
        swap_in = '1' and valid_in(1) = '1' and me_xc_in(1) = '1') then
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
      if csrv_in = '1' then
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

  -- Exception Management
  procedure exception_unit(branch_xc    : in  std_ulogic;
                           branch_cause : in  cause_type;
                           branch_tval  : in  wordx;
                           csr_xc       : in  std_logic_vector;
                           csr_cause    : in  cause_type;
                           r            : in  registers;
                           fence_in     : in  std_ulogic;
                           swap_in      : in  std_ulogic;
                           csr_in       : in  csr_reg_type;
                           int_in       : in  lanes_type;
                           xcs_out      : out std_logic_vector;
                           causes_out   : out cause_lanes_type;
                           tvals_out    : out wordx_lanes_type;
                           ret_out      : out std_logic_vector;
                           xc_out       : out std_ulogic;
                           xc_lane_out  : out std_ulogic;
                           irq_taken    : out std_logic_vector(1 downto 0);
                           cause_out    : out cause_type;
                           tval_out     : out wordx;
                           tval2_out    : out wordx;
                           gva_out      : out std_ulogic;
                           flush_out    : out std_logic_vector;
                           pc_out       : out pctype;
                           inst_out     : out word;
                           trig_taken   : out std_ulogic) is
    variable taken     : wordx          := csr_in.mip and csr_in.mie;
    -- Non-constant
    variable irqenable : std_ulogic     := '0';
    variable xc        : std_ulogic     := '0';
    variable cause     : cause_type     := (others => '0');
    variable irqcause  : cause_type     := (others => '0');
    variable csr       : csr_reg_type   := csr_in;
    variable xcs       : lanes_type;
    variable causes    : cause_lanes_type;
    variable tvals     : wordx_lanes_type;
    variable pc        : pctype         := PC_ZERO;
    variable inst      : word           := (others => '0');
    variable gva       : std_ulogic     := '0';
    variable tval      : wordx          := zerox;
    variable tval2     : wordx          := zerox;
    variable ret       : word2          := r.x.ret;
    variable flush     : word2          := "00";
  begin
    irq_taken   := "00";
    trig_taken  := '0';
    xc_lane_out := '0';
    -- Check exception from previous stages
    for i in lanes'range loop
      xcs(i)    := r.x.ctrl(i).xc;
      causes(i) := r.x.ctrl(i).cause;
      tvals(i)  := r.x.ctrl(i).tval;
    end loop;

    -- Insert CSR write exception
    if r.x.ctrl(csr_lane).xc = '0' then
      if csr_xc(csr_lane) = '1' then
        xcs(csr_lane)    := '1';
        causes(csr_lane) := csr_cause;
        tvals(csr_lane)  := to0x(r.x.ctrl(csr_lane).inst);
      end if;
    end if;

    if xcs(0) = '0' and r.x.mexc = '1' then
      xcs(0)        := '1';
      if r.x.exctype = '1' then
        causes(0)   := XC_INST_LOAD_ACCESS_FAULT;
      elsif r.x.exchyper = '1' then
        causes(0)   := XC_INST_LOAD_G_PAGE_FAULT;
      else
        causes(0)   := XC_INST_LOAD_PAGE_FAULT;
      end if;
      if v_fusel_eq(r, x, 0, ST) or is_cbo(r.x.ctrl(memory_lane).inst) then
        if r.x.exctype = '1' then
          causes(0) := XC_INST_STORE_ACCESS_FAULT;
        elsif r.x.exchyper = '1' then
          causes(0) := XC_INST_STORE_G_PAGE_FAULT;
        else
          causes(0) := XC_INST_STORE_PAGE_FAULT;
        end if;
      end if;
      tvals(0)      := pc2xlen(r.x.address);
    end if;


    -- Check if we have to raise an exception due to previous stages.
    -- First instruction should be in the upper arm, but in case of a
    -- swap it is in the second arm.

    -- Raise exception only if not flushed by fence in write back stage.
    if swap_in = '1' then
      if    single_issue = 0 and
            xcs(1) = '1' and r.x.ctrl(1).valid = '1' then
        xc           := '1';
        pc           := r.x.ctrl(1).pc;
        inst         := r.x.ctrl(1).inst;
        inst(1)      := not r.x.ctrl(1).comp;
        cause        := causes(1);
        tval         := tvals(1);
        flush        := "11";           -- flush both
        xc_lane_out  := '1';
      elsif xcs(0) = '1' and r.x.ctrl(0).valid = '1' then
        xc           := '1';
        pc           := r.x.ctrl(0).pc;
        inst         := r.x.ctrl(0).inst;
        inst(1)      := not r.x.ctrl(0).comp;
        cause        := causes(0);
        tval         := tvals(0);
        flush        := "01";           -- flush lane 0 only
      end if;
    else
      if    xcs(0) = '1' and r.x.ctrl(0).valid = '1' then
        xc           := '1';
        pc           := r.x.ctrl(0).pc;
        inst         := r.x.ctrl(0).inst;
        inst(1)      := not r.x.ctrl(0).comp;
        cause        := causes(0);
        tval         := tvals(0);
        flush        := "11";           -- flush both
      elsif single_issue = 0 and
            xcs(1) = '1' and r.x.ctrl(1).valid = '1' then
        xc           := '1';
        pc           := r.x.ctrl(1).pc;
        inst         := r.x.ctrl(1).inst;
        inst(1)      := not r.x.ctrl(1).comp;
        cause        := causes(1);
        tval         := tvals(1);
        flush        := "10";           -- flush lane 1 only
        xc_lane_out  := '1';
      end if;
    end if;

    -- Mask flush on:
    --
    -- control and system instructions such as mret, sret, ...
    -- instruction access fault on JALR
    for i in lanes'range loop
      if (r.x.ctrl(i).inst( 6 downto  0) = OP_SYSTEM and
          r.x.ctrl(i).inst(14 downto 12) = "000"     and
          r.x.ctrl(i).inst(24 downto 20) = "00010"   and
          r.x.ctrl(i).cause(3 downto  2) = "10"      and  -- env call u/s/m
          not is_irq(r.x.ctrl(i).cause)) then
        flush(i) := '0';
        xcs(i)   := '0';
      end if;
    end loop;

    -- All interrupt related checks are done in memory stage
    -- hence no extra check needed in this stage.
    irqenable := int_in(0) or int_in(one);
    irqcause  := r.x.irqcause;

    -- Raise exception if interrupts
    if irqenable = '1' and is_irq(irqcause) then
      xc     := '1';
      causes := (others => irqcause);
      cause  := irqcause;
      tvals  := (others => (others => '0'));
      tval   := (others => '0');
      inst   := (others => '0');
      if swap_in = '1' then
        if    single_issue = 0 and
              int_in(1) = '1' and r.x.ctrl(1).valid = '1' then
          xcs(1)       := '1';
          pc           := r.x.ctrl(1).pc;
          flush        := "11";         -- flush both
          xc_lane_out  := '1';
          irq_taken(1) := '1';
        elsif int_in(0) = '1' and r.x.ctrl(0).valid = '1' then
          xcs(0)       := '1';
          pc           := r.x.ctrl(0).pc;
          flush        := "01";         -- flush lane 0 only
          xc_lane_out  := '0';  -- Needed to overwrite exception from other lane
          irq_taken(0) := '1';
        end if;
      else
        if    int_in(0) = '1' and r.x.ctrl(0).valid = '1' then
          xcs(0)       := '1';
          pc           := r.x.ctrl(0).pc;
          flush        := "11";         -- flush both
          xc_lane_out  := '0';  -- Needed to overwrite exception from other lane
          irq_taken(0) := '1';
        elsif single_issue = 0 and
              int_in(1) = '1' and r.x.ctrl(1).valid = '1' then
          xcs(1)       := '1';
          pc           := r.x.ctrl(1).pc;
          flush        := "10";         -- flush lane 1 only
          xc_lane_out  := '1';
          irq_taken(1) := '1';
        end if;
      end if;
    end if;

    -- Triggers: step, debug trigger (clear exception and instruction in wb)
    if (r.x.ctrl(0).valid or r.x.ctrl(one).valid) = '1' then
      if orv(r.x.trig.valid) = '1' and r.x.trig.action(1) = '1' then
        xcs         := (others => '0');
        xc          := '0';
        for i in lanes'range loop
          flush(i)  := r.x.trig.nullify(i);
        end loop;
        trig_taken  := '1';
      end if;
    end if;

    if ext_h /= 0 then
      if    cause = XC_INST_BREAKPOINT or
            cause = XC_INST_ADDR_MISALIGNED or
            cause = XC_INST_LOAD_ADDR_MISALIGNED or
            cause = XC_INST_STORE_ADDR_MISALIGNED then
        gva   := csr.v;
      elsif cause = XC_INST_INST_G_PAGE_FAULT then
        gva   := csr.v;
        tval2 := r.d.tval2;
        if r.d.tval2type = "01" then
          -- The value from MMU/cache controller has no knowledge of
          -- exactly what part of the word the faulting instruction
          -- was in, so copy from virtual address.
          tval2(11 - 2 downto 0) := tval(11 downto 2);
        end if;
      elsif cause = XC_INST_LOAD_G_PAGE_FAULT or
            cause = XC_INST_STORE_G_PAGE_FAULT then
        gva   := csr.v or is_hlsv(r.x.ctrl(0).inst);
        tval2 := r.x.tval2;
        if r.x.tval2type = "01" then
          -- The value from MMU/cache controller has no knowledge of
          -- exactly what part of the word the faulting instruction
          -- was in, so copy from virtual address.
          tval2(11 - 2 downto 0) := tval(11 downto 2);
        end if;
      elsif cause = XC_INST_INST_PAGE_FAULT or
            cause = XC_INST_ACCESS_FAULT then
        gva   := csr.v;
      elsif cause = XC_INST_LOAD_PAGE_FAULT   or
            cause = XC_INST_STORE_PAGE_FAULT  or
            cause = XC_INST_LOAD_ACCESS_FAULT or
            cause = XC_INST_STORE_ACCESS_FAULT then
        gva   := csr.v or is_hlsv(r.x.ctrl(0).inst);
      end if;

      -- mtinst / htinst
      -- Since there is no support for misaligned addresses,
      -- only masking of the offending instruction is needed.
      -- Unless the error was with the PT read/update itself,
      -- which will instead use special instructions.

      -- Load error?
      if    cause = XC_INST_LOAD_G_PAGE_FAULT or
            cause = XC_INST_LOAD_PAGE_FAULT   or
            cause = XC_INST_LOAD_ACCESS_FAULT then
        if is_hlv(inst) then
          inst := inst and TINST_H_MASK;
        else
          inst := inst and TINST_LOAD_MASK;
        end if;
      -- Store error?
      elsif cause = XC_INST_STORE_G_PAGE_FAULT or
            cause = XC_INST_STORE_PAGE_FAULT   or
            cause = XC_INST_STORE_ACCESS_FAULT then
        if is_hsv(inst) then
          inst := inst and TINST_H_MASK;
        elsif inst(6 downto 0) = OP_AMO then
          inst := inst and TINST_AMO_MASK;
        else
          inst := inst and TINST_STORE_MASK;
        end if;
      else
        inst  := (others => '0');
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

    -- Output exceptions pair (no interrupts infos here)
    xcs_out     := xcs;
    causes_out  := causes;
    tvals_out   := tvals;

    -- Output taken exception
    xc_out      := xc and not fence_in;
    cause_out   := cause;
    tval_out    := tval;
    tval2_out   := tval2;
    gva_out     := gva;
    pc_out      := pc;
    inst_out    := inst;
    ret_out     := ret;
    for i in lanes'range loop
      flush_out(i) := flush(i) and not fence_in;
    end loop;
  end;

  function trigger_valid(prv   : priv_lvl_type;
                         tdata : wordx) return std_logic is
    variable typ   : std_logic_vector(3 downto 0) := tdata(tdata'high downto tdata'high - 3);
    variable prvi  : integer                      := u2i(prv);
    -- Non-constant
    variable valid : std_logic;
  begin
    valid     := '0';
    case typ is
      when "0000" | "1111" =>
        valid := '0';
      when "0001" =>
        valid := '0';
      when "0010" =>
        valid := tdata(3 + prvi);
      when others =>
        valid := tdata(6 + prvi);
    end case;

    return valid;
  end;

  function trigger_set_hit(tdata : wordx) return wordx is
    variable typ  : std_logic_vector(3 downto 0) := tdata(tdata'high downto tdata'high - 3);
    -- Non-constant
    variable data : wordx                        := tdata;
  begin
    case typ is
      when "0000" | "1111" =>
      when "0001" =>
      when "0010" => -- MCONTROL
        data(20)       := '1';
      when "0011" => -- ICOUNT
        data(24)       := '1';
      when "0100" | "0101" => -- ITRIGGER or ETRIGGER
        data(XLEN - 6) := '1';
      when others =>
    end case;

    return data;
  end;

  procedure trigger_update(csr_in      : in  csr_reg_type;
                           v_wb_ctrl   : in  pipeline_ctrl_lanes_type;
                           trig_in     : in  trig_type;
                           csr_out     : out csr_reg_type) is
    variable tdata1_ic_in : wordx        := csr_in.tcsr.tdata1(TRIGGER_MC_NUM);
    -- Non-constant
    variable csr          : csr_reg_type := csr_in;
  begin
    if TRIGGER /= 0 then
      -- Trigger hit
      if orv(trig_in.valid) = '1' then
        for i in trig_in.hit'range loop
          if trig_in.hit(i) = '1' then
            csr.tcsr.tdata1(i) := trigger_set_hit(csr_in.tcsr.tdata1(i));
          end if;
        end loop;
      end if;
      -- Trigger icount
      if TRIGGER_IC_NUM /= 0 then
        if trigger_valid(csr_in.prv, tdata1_ic_in) = '1' then
          if (v_wb_ctrl(0).valid and v_wb_ctrl(one).valid) = '1' then
            uadd_range(tdata1_ic_in, -2, csr.tcsr.tdata1(TRIGGER_MC_NUM)(23 downto 10));
          elsif (v_wb_ctrl(0).valid or v_wb_ctrl(one).valid) = '1' then
            uadd_range(tdata1_ic_in, -1, csr.tcsr.tdata1(TRIGGER_MC_NUM)(23 downto 10));
          end if;
        end if;
        if (csr.tcsr.tdata1(TRIGGER_MC_NUM)(23) and not tdata1_ic_in(23)) = '1' then
          csr.tcsr.tdata1(TRIGGER_MC_NUM)(23 downto 10) := zerow(23 downto 10);
        end if;
      end if;
    end if;

    csr_out := csr;
  end;

  -- Exception flow
  procedure exception_flow(pc_in       : in  pctype;
                           xc_in       : in  std_ulogic;
                           cause_in    : in  cause_type;
                           tval_in     : in  wordx;
                           tval2_in    : in  wordx;
                           tinst_in    : in  word;
                           gva_in      : in  std_ulogic;
                           ret_in      : in  std_logic_vector;
                           csr_in      : in  csr_reg_type;
                           rcsr_in     : in  csr_reg_type;
                           rstate_in   : in  core_state;
                           csr_out     : out csr_reg_type;
                           tvec_out    : out pctype) is
    -- Non-constant
    variable csr      : csr_reg_type  := csr_in;
    variable prv_lvl  : priv_lvl_type := csr_in.prv;
    variable prv_v    : std_ulogic    := csr_in.v;
    variable trap_prv : priv_lvl_type := PRIV_LVL_M; -- by default trap to Machine Mode
    variable tvec     : pctype;
    variable mask_xc  : std_ulogic    := '0';
    variable h_en     : boolean       := rcsr_in.misa(h_ctrl) = '1';
    variable trap_v   : std_ulogic    := '0';
    variable cause_v  : cause_type    := cause_in;
  begin
    -- Check the privileged mode where to trap.
    if (    is_irq(cause_in) and cause_bit(rcsr_in.mideleg, cause_in) = '1') or
       (not is_irq(cause_in) and cause_bit(rcsr_in.medeleg, cause_in) = '1') then
      -- Delegated from M.
      if (rcsr_in.prv = PRIV_LVL_S or rcsr_in.prv = PRIV_LVL_U) then
        -- In S/HS/VS/U.
        trap_prv       := PRIV_LVL_S;
--qqq XXX Translation should no longer be needed!
        if h_en and rcsr_in.v = '1' then -- Hypervisor extension
          -- In VS/VU,
          if (    is_irq(cause_in) and cause_bit(rcsr_in.hideleg, cause_in) = '1') or
             (not is_irq(cause_in) and cause_bit(rcsr_in.hedeleg, cause_in) = '1') then
            -- Delegated from HS.
            trap_v := '1';
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
        csr.vsstatus.spie := csr_in.vsstatus.sie;
        csr.vsstatus.sie  := '0';
        csr.vsstatus.spp  := prv_lvl(0);
        csr.vscause     := cause2wordx(cause_v);
        csr.vsepc       := pc2xlen(pc_in);
        csr.vstval      := tval_in;
      elsif trap_prv = PRIV_LVL_S then  -- Trapping to S/HS Mode
        csr.mstatus.spie := csr_in.mstatus.sie;
        csr.mstatus.sie  := '0';
        csr.mstatus.spp  := prv_lvl(0);
        -- H-ext
        csr.hstatus.spv  := csr_in.v;
        csr.hstatus.gva  := gva_in;
        if rcsr_in.v = '1' then
          csr.hstatus.spvp := prv_lvl(0);
        end if;
          csr.scause     := cause2wordx(cause_in);
          csr.sepc       := pc2xlen(pc_in);
          csr.stval      := tval_in;
          -- H-ext
          csr.htval      := tval2_in;
          csr.htinst     := to0x(tinst_in);

      else                              -- Trapping to Machine Mode
        csr.mstatus.mpie := csr_in.mstatus.mie;
        csr.mstatus.mie  := '0';
        csr.mstatus.mpp  := csr_in.prv;
        -- H-ext
        if csr_in.prv /= PRIV_LVL_M then
          csr.mstatus.mpv := csr_in.v;
        end if;
        csr.mstatus.gva  := gva_in;
        csr.mcause     := cause2wordx(cause_in);
        csr.mepc       := pc2xlen(pc_in);
        csr.mtval      := tval_in;
        -- H-ext
        csr.mtval2     := tval2_in;
        csr.mtinst     := to0x(tinst_in);

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
        csr.mstatus.mie    := csr_in.mstatus.mpie;
        prv_lvl            := csr_in.mstatus.mpp;
        -- H-ext
        prv_v              := csr_in.mstatus.mpv;
        if prv_lvl = PRIV_LVL_M then
          prv_v            := '0';
        end if;
        if prv_lvl /= PRIV_LVL_M then
          csr.mstatus.mprv := '0';
        end if;
        csr.mstatus.mpie   := '1';
        csr.mstatus.mpp    := PRIV_LVL_U;
        if mode_u = 0 then
          csr.mstatus.mpp  := PRIV_LVL_M;
        end if;
        -- H-ext
--      if prv_lvl /= PRIV_LVL_M then
          csr.mstatus.mpv  := '0';
--      end if;
      elsif ret_in = "01" then    -- sret
        if rcsr_in.v = '1' then   -- VS Mode
          csr.vsstatus.sie   := csr_in.vsstatus.spie;
          prv_lvl            := '0' & csr_in.vsstatus.spp;
          prv_v              := '1';
          csr.vsstatus.spie  := '1';
          csr.vsstatus.spp   := PRIV_LVL_U(0);
          if mode_u = 0 then
            csr.vsstatus.spp := PRIV_LVL_M(0);
          end if;
        else                      -- S/HS Mode
          csr.mstatus.sie    := csr_in.mstatus.spie;
          prv_lvl            := '0' & csr_in.mstatus.spp;
          -- H-ext
          prv_v              := csr_in.hstatus.spv;
          if prv_lvl /= PRIV_LVL_M then
            csr.mstatus.mprv := '0';
          end if;
          csr.mstatus.spie   := '1';
          csr.mstatus.spp    := PRIV_LVL_U(0);
          if mode_u = 0 then
            csr.mstatus.spp  := PRIV_LVL_M(0);
          end if;
          -- H-ext
          csr.hstatus.spv    := '0';
        end if;
      end if;
    end if;

    -- Generate Return PC for Trap/Return Instructions.
    -- Trap/Exceptions
    tvec      := to_addr(rcsr_in.mtvec);
    tvec(0)   := '0';
    if rcsr_in.mtvec(0) = '1' and is_irq(cause_in) then
      tvec    := cause2vec(cause_in, tvec);
    end if;
    if trap_prv = PRIV_LVL_S then
      tvec    := to_addr(rcsr_in.stvec);
      if rcsr_in.stvec(0) = '1' and is_irq(cause_in) then
        tvec  := cause2vec(cause_in, tvec);
      end if;
      if trap_v = '1' then -- VS Mode (H extension)
        tvec    := to_addr(rcsr_in.vstvec);
        if rcsr_in.vstvec(0) = '1' and is_irq(cause_in) then
          tvec  := cause2vec(cause_v, tvec);
        end if;
      end if;
    end if;

    -- Return Instructions
    if ret_in = "11" then
      tvec    := to_addr(rcsr_in.mepc);
    elsif ret_in = "01" then
      tvec    := to_addr(rcsr_in.sepc);
      if rcsr_in.v = '1' then
        tvec  := to_addr(rcsr_in.vsepc);
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
       ((rstate_in = run) and (cause_in = XC_INST_BREAKPOINT) and
        ((csr_in.v = '0' and csr_in.prv = PRIV_LVL_M and csr_in.dcsr.ebreakm  = '1') or
         (csr_in.v = '0' and csr_in.prv = PRIV_LVL_S and csr_in.dcsr.ebreaks  = '1') or
         (csr_in.v = '0' and csr_in.prv = PRIV_LVL_U and csr_in.dcsr.ebreaku  = '1') or
         (csr_in.v = '1' and csr_in.prv = PRIV_LVL_S and csr_in.dcsr.ebreakvs = '1') or
         (csr_in.v = '1' and csr_in.prv = PRIV_LVL_U and csr_in.dcsr.ebreakvu = '1'))) then
      mask_xc := '1';
    end if;

    -- If we receive a valid exception, we have to update some CSR registers.
    if xc_in = '1' and mask_xc = '0' then
      csr_out := csr;
    else
      csr_out := csr_in;
    end if;
  end;

  -- Check if CSR write address should always cause illegal instruction fault.
  function csr_write_addr_xc(csra : csratype; misa : wordx) return std_logic is
    variable csra_high : csratype   := csra(csra'high downto 4) & "0000";
    variable csra_low  : integer    := u2i(csra(3 downto 0));
    variable h_en      : boolean    := misa(h_ctrl) = '1';
    -- Non-constant
    variable xc        : std_ulogic := '0';
  begin
    case csra is
      -- User Floating-Point CSRs
      when CSR_FFLAGS | CSR_FRM | CSR_FCSR =>
        if not (ext_f = 1) then
          xc := '1';
        end if;
      -- Hypervisor Trap Setup
      when CSR_HSTATUS        =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HEDELEG        =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HIDELEG        =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HIE            =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HCOUNTEREN     =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HGEIE          =>
        if not h_en then
          xc := '1';
        end if;
      -- Hypervisor Trap Handling
      when CSR_HTVAL          =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HIP            =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HVIP           =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HTINST         =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HGEIP          =>
        if not h_en then
          xc := '1';
        end if;
      -- Hypervisor Protection and Translation
      when CSR_HGATP          =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HENVCFG        =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HENVCFGH       =>
        if not h_en or is_rv64 then
          xc := '1';
        end if;
      -- Hypervisor Counter/Timer Virtualization Registers
      when CSR_HTIMEDELTA     =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_HTIMEDELTAH    =>
        if not h_en or not is_rv32 then
          xc := '1';
        end if;
      -- Virtual Supervisor Registers
      when CSR_VSSTATUS       =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSIE           =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSTVEC         =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSSCRATCH      =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSEPC          =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSCAUSE        =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSTVAL         =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSIP           =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_VSATP          =>
        if not h_en then
          xc := '1';
        end if;
      -- User Counters/Timers - see below
      when CSR_VSTIMECMP      =>
        if ext_sstc /= 1 or not h_en then
          xc := '1';
        end if;
      when CSR_VSTIMECMPH     =>
        if ext_sstc /= 1 or h_en then
          xc := '1';
        end if;
      -- Supervisor Trap Setup
      when CSR_SSTATUS        =>
      when CSR_SIE            =>
      when CSR_STVEC          =>
      when CSR_SCOUNTEREN     =>
      when CSR_SENVCFG        =>
        if mode_u = 0 then
          xc := '1';
        end if;
      when CSR_SCOUNTOVF      =>
        if ext_sscofpmf = 0 or mode_s = 0 then
          xc := '1';
        end if;
      -- Supervisor Trap Handling
      when CSR_SSCRATCH       =>
      when CSR_SEPC           =>
      when CSR_SCAUSE         =>
      when CSR_STVAL          =>
      when CSR_SIP            =>
      -- Supervisor Protection and Translation
      when CSR_SATP           =>
      when CSR_STIMECMP       =>
        if ext_sstc /= 1 then
          xc := '1';
        end if;
      when CSR_STIMECMPH      =>
        if ext_sstc /= 1 then
          xc := '1';
        end if;
      -- Machine Trap Setup
      when CSR_MSTATUS        =>
      when CSR_MSTATUSH       =>
        if is_rv64 then
          xc := '1';
        end if;
      when CSR_MISA           =>
      when CSR_MEDELEG        =>
        if mode_s = 0
          then
          xc := '1';
        end if;
      when CSR_MIDELEG        =>
        if mode_s = 0
          then
          xc := '1';
        end if;
      when CSR_MIE            =>
      when CSR_MTVEC          =>
      when CSR_MCOUNTEREN     =>
      -- Machine Trap Handling
      when CSR_MSCRATCH       =>
      when CSR_MEPC           =>
      when CSR_MCAUSE         =>
      when CSR_MTVAL          =>
      when CSR_MIP            =>
      when CSR_MTINST         =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_MTVAL2         =>
        if not h_en then
          xc := '1';
        end if;
      when CSR_MENVCFG        =>
        if mode_u = 0 then
          xc := '1';
        end if;
      when CSR_MENVCFGH       =>
        if mode_u = 0 or is_rv64 then
          xc := '1';
        end if;
      -- Machine Protection and Translation
      when CSR_PMPCFG0        =>
      when CSR_PMPCFG1        =>
        if is_rv64 then
          xc := '1';
        end if;
      when CSR_PMPCFG2        =>
      when CSR_PMPCFG3        =>
        if is_rv64 then
          xc := '1';
        end if;
      -- Debug/Trace Registers
      when CSR_TSELECT        =>
        if TRIGGER = 0 then
          xc := '1';
        end if;
      when CSR_TDATA1         =>
        if TRIGGER = 0 then
          xc := '1';
        end if;
      when CSR_TDATA2         =>
        if TRIGGER = 0 then
          xc := '1';
        end if;
      when CSR_TDATA3         =>
        if TRIGGER = 0 then
          xc := '1';
        end if;
      when CSR_TINFO         =>
        xc := '1';
      -- Core Debug Registers
      when CSR_DCSR =>
      when CSR_DPC =>
      when CSR_DSCRATCH0 =>
      when CSR_DSCRATCH1 =>
      -- Custom Read/Write Registers
      when CSR_FEATURES =>
      when CSR_FEATURESH =>
        if is_rv64 then
          xc := '1';
        end if;
      when CSR_CCTRL =>
      when CSR_TCMICTRL =>
        xc := '1';
      when CSR_TCMDCTRL =>
        xc := '1';
      when others =>
        case csra_high is
          -- Machine Counter/Timers
          when CSR_MCYCLE         =>  -- MCYCLE/MINSTRET/HPMCOUNTER3-15
            if csra_low = 1 then      --  There is no CSR_MTIME!
              xc := '1';
            end if;
          when CSR_MCYCLEH        =>
            if is_rv64 or csra_low = 1 then --  There is no CSR_MTIMEH!
              xc := '1';
            end if;
          when CSR_MHPMCOUNTER16  =>  -- HPMCOUNTER16-31
          when CSR_MHPMCOUNTER16H =>  -- HPMCOUNTER16-31H
            if is_rv64 then
              xc := '1';
            end if;
          -- Machine Hardware Performance Monitoring Event Selector
          when CSR_MCOUNTINHIBIT  =>  -- MCOUNTINHIBIT/MHPMEVENT3-15
            if csra_low = 1 or        --  There is nothing at second/third position.
               csra_low = 2 then
              xc := '1';
            end if;
          when CSR_MHPMEVENT16    =>  -- MHPMEVENT16-31
          when CSR_MHPMEVENT0H    =>  -- MHPMEVENT3-15H
            if ext_sscofpmf = 0 or is_rv64 or csra_low < 3 then  --  There is nothing at 0-2.
              xc := '1';
            end if;
          when CSR_MHPMEVENT16H   =>  -- MHPMEVENT16-31H
            if ext_sscofpmf = 0 or is_rv64 then
              xc := '1';
            end if;
          when CSR_PMPADDR0       =>
          when others =>
            xc := '1';
        end case;
    end case;

    return xc;
  end;


  -- Check if CSR write address should cause illegal instruction fault,
  -- depending on circumstances.
  -- Privilege cannot change without exception and thus pipeline flush.
  function csr_write_xc(envcfg : csr_envcfg_type;
                        csra   : csratype;
                        rstate : core_state;
                        csr    : csr_reg_type) return std_logic is
    variable priv_lvl : priv_lvl_type := csr.prv and csra(9 downto 8);
    variable h_en     : boolean    := csr.misa(h_ctrl) = '1';
    -- Non-constant
    variable priv_lvlv: priv_lvl_type := csr.prv and csra(9 downto 8);
    variable xc       : std_ulogic    := csr_write_addr_xc(csra, csr.misa);
  begin
    -- Check for privileged level and read/write accessibility to CSR registers
    -- The standard RISC-V ISA sets aside a 12-bit encoding space (csr[11:0])
    -- for up to 4,096 CSRs. By convention, the upper 4 bits of the CSR address
    -- (csr[11:8]) are used to encode the read and write accessibility of the
    -- CSRs according to privilege level as shown in Table 2.1. The top two
    -- bits (csr[11:10]) indicate whether the register is read/write (00, 01, or 10)
    -- or read-only (11). The next two bits (csr[9:8]) encode the lowest privilege
    -- level that can access the CSR.
    if h_en and csr.v = '0' then
      priv_lvlv := (csr.prv(0) & csr.prv(1)) and csra(9 downto 8);
    end if;

    -- Exception due to lower priviledge or read-only.
    --if (((priv_lvl(1) = '0' and csra(9) = '1') or  -- Only hypervisor or machine mode
    --     (priv_lvl(0) = '0' and csra(8) = '1'))    -- Only supervisor or machine mode
    if ((priv_lvl /= csra(9 downto 8) and
         priv_lvlv /= csra(9 downto 8))
        ) or csra(11 downto 10) = "11" then        -- Read-only
      xc    := '1';
    end if;

    -- Exception if access Debug Core CSR or Features Enable not in Debug Mode.
    if rstate = run and
       (
        csra(11 downto 4) = "01111011") then
      xc      := '1';
    end if;

    -- Exception if access SATP in S-mode and TVM set or VS-mode and VTVM.
    if csra = CSR_SATP then
      if csr.v = '0' and csr.prv = PRIV_LVL_S and csr.mstatus.tvm = '1' then
        xc      := '1';
      end if;
      if csr.v = '1' and csr.prv = PRIV_LVL_S and csr.hstatus.vtvm = '1' then
        xc      := '1';
      end if;
    end if;

    -- Exception if access HGATP in HS-mode and TVM set.
    if h_en then
      if csra = CSR_HGATP and csr.prv = PRIV_LVL_S and csr.mstatus.tvm = '1' then
        xc      := '1';
      end if;
    end if;

    -- FPU CSRs not accessible if FPU is not active.
    if not (ext_f = 1) then
      if (csra = CSR_FFLAGS or csra = CSR_FRM or csra = CSR_FCSR) and
         (csr.mstatus.fs = "00" or (csr.v = '1' and csr.vsstatus.fs = "00")) then
        xc      := '1';
      end if;
    end if;

    -- SSTC
    if ext_sstc = 1 then 
      if envcfg.stce = '0' then
        if csra = CSR_STIMECMP or csra = CSR_STIMECMPH or 
           csra = CSR_VSTIMECMP or csra = CSR_VSTIMECMPH then
          xc := '1';
        end if;
      else
        if csra = CSR_STIMECMP or csra = CSR_STIMECMPH then
          -- When counteren(time) = 0: exception also on STIMECMP 
          if (csr.v = '0' and csr.prv = PRIV_LVL_S and csr.mcounteren(1) = '0') or
             (csr.v = '1' and csr.prv = PRIV_LVL_S and (csr.mcounteren(1) = '0' or
                                                       csr.hcounteren(1) = '0')) then
            xc := '1';
          end if;
        end if;
      end if;
    end if;

    return xc;
  end;

  -- Check if CSR read address should always cause illegal instruction fault.
  -- No CSRs are write-only, so this slightly modifies the write check above.
  function csr_read_addr_xc(csra : csratype; misa : wordx) return std_logic is
    -- Non-constant
    variable xc : std_ulogic := '0';
  begin
    case csra is
      -- User Counter/Timers
      when CSR_CYCLE          =>
      when CSR_TIME           =>
        -- The time CSR is a read-only shadow of the memory-mapped mtime register
        -- Implementations can convert reads of the time CSR into loads to the
        -- memory-mapped mtime register, or emulate this functionality in M-mode software.
        if not time_en then
          xc := '1';
        end if;
      when CSR_INSTRET        =>
      -- Machine Information Registers
      when CSR_MVENDORID      =>
      when CSR_MARCHID        =>
      when CSR_MIMPID         =>
      when CSR_MHARTID        =>
      -- User Hardware Performance Monitoring
      when CSR_HPMCOUNTER3  | CSR_HPMCOUNTER4  | CSR_HPMCOUNTER5  |
           CSR_HPMCOUNTER6  | CSR_HPMCOUNTER7  | CSR_HPMCOUNTER8  |
           CSR_HPMCOUNTER9  | CSR_HPMCOUNTER10 | CSR_HPMCOUNTER11 |
           CSR_HPMCOUNTER12 | CSR_HPMCOUNTER13 | CSR_HPMCOUNTER14 |
           CSR_HPMCOUNTER15 | CSR_HPMCOUNTER16 | CSR_HPMCOUNTER17 |
           CSR_HPMCOUNTER18 | CSR_HPMCOUNTER19 | CSR_HPMCOUNTER20 |
           CSR_HPMCOUNTER21 | CSR_HPMCOUNTER22 | CSR_HPMCOUNTER23 |
           CSR_HPMCOUNTER24 | CSR_HPMCOUNTER25 | CSR_HPMCOUNTER26 |
           CSR_HPMCOUNTER27 | CSR_HPMCOUNTER28 | CSR_HPMCOUNTER29 |
           CSR_HPMCOUNTER30 | CSR_HPMCOUNTER31 =>
      when CSR_TINFO =>
        if TRIGGER = 0 then
          xc := '1';
        end if;
      when others             => xc := csr_write_addr_xc(csra, misa);
    end case;

    return xc;
  end;

  -- CSR Write
  procedure csr_write(csra_in          : in  csratype;
                      rstate_in        : in  core_state;
                      csr_file         : in  csr_reg_type;
                      wcsr_in          : in  wordx;
                      csrv_in          : in  std_ulogic;
                      wlane_in         : in  std_logic_vector;
                      pc_in            : in  pctype;
                      csraxc_in        : in  std_ulogic;
                      envcfg           : in  csr_envcfg_type;
                      pipeflush_out    : out std_ulogic;
                      addrflush_out    : out std_ulogic;
                      xc_out           : out std_logic_vector;
                      cause_out        : out cause_type;
                      upd_mcycle_out   : out std_ulogic;
                      upd_minstret_out : out std_ulogic;
                      upd_counter_out  : out std_logic_vector;

                      csr_out          : out csr_reg_type
                      ) is

    -- Locked or unimplemented PMP?
    function pmp_locked(csr : csr_reg_type; n : integer) return std_logic is
    begin
      if n >= pmp_entries then
        return '1';
      end if;


      return pmpcfg(pmp_entries, csr, n)(7);
    end;

    procedure pmpcfg_write(csr_in    : in    csr_reg_type;
                           first_in  : in    integer; last_in   : in  integer; wcsr_in : in wordx;
                           pmpcfg_io : inout word64;  flush_out : out std_ulogic) is
      --  Non-constant
      variable pmpcfg02 : word64     := pmpcfg_io;
      variable flush    : std_ulogic := '0';
      variable pmpcfg_b : word8;
    begin
      -- Should flush pipeline if (at least new) lock bit is set, since that
      -- should "take" immediately and might invalidate instruction fetches.
      for i in first_in to last_in loop
        if pmp_locked(csr_in, i) = '0' then
          pmpcfg_b                         := wcsr_in((i - first_in) * 8 + 7 downto (i - first_in) * 8);
          pmpcfg02(i * 8 + 7 downto i * 8) := pmpcfg_b and not x"60"; --Clear bit 6 & 5 since these are unused and WARL
          -- W without R is reserved!
          if pmpcfg_b(1 downto 0) = "10" then
            pmpcfg02(i * 8 + 1)            := '0';
          end if;
          if pmp_g > 0 then
            -- NA4 not possible!
            if pmpcfg_b(4 downto 3) = "10" then
              pmpcfg02(i * 8 + 4 downto i * 8 + 3) :=
                pmpcfg_io((i - first_in) * 8 + 4 downto (i - first_in) * 8 + 3); -- Keep old value on illegal write
            end if;
          end if;
          if pmp_no_tor = 1 then
            -- TOR not possible!
            if pmpcfg_b(4 downto 3) = "01" then
              pmpcfg02(i * 8 + 3)          := '0';      -- Clear to OFF
            end if;
          end if;
          -- Flush if lock is being set with execute protection.
          flush := flush or (pmpcfg_b(7) and not pmpcfg_b(2));
        end if;
      end loop;

      pmpcfg_io := pmpcfg02;
      flush_out := flush;
    end;

    procedure tdata_write(tcsr_in   : in  csr_tcsr_type;
                          reg       : in  integer;
                          rstate_in : in  core_state;
                          wcsr_in   : in  wordx;
                          tcsr_out  : out csr_tcsr_type) is
      variable sel    : integer                      := u2i(tcsr_in.tselect);
      variable typ    : std_logic_vector(3 downto 0) := tcsr_in.tdata1(sel)(XLEN - 1 downto XLEN - 4);
      variable typ_in : std_logic_vector(3 downto 0) := wcsr_in(XLEN - 1 downto XLEN - 4);
      -- Non-constant
      variable valid  : std_logic                    := '0';
      variable tcsr   : csr_tcsr_type                := tcsr_in;

      function tdata1_mcontrol(rstate : core_state; wcsr : wordx) return std_logic_vector is
        -- Non-constant
        variable tdata1 : std_logic_vector(XLEN - 6 downto 0) := (others => '0');
      begin
        tdata1(XLEN - 6 downto XLEN - 11) := "111111";       -- maskmax
        tdata1(20)  := wcsr(20);        -- hit
        tdata1(19)  := wcsr(19);        -- select
        -- timing
        tdata1(18)  := wcsr(19) and (wcsr(1) or wcsr(0)); -- 1: data watch point, 0: others

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
      end function;

      function tdata1_icount(rstate : core_state; wcsr : wordx) return std_logic_vector is
        -- Non-constant
        variable tdata1 : std_logic_vector(XLEN - 6 downto 0) := (others => '0');
      begin
        tdata1(24)           := wcsr(24);             -- hit
        tdata1(23 downto 10) := wcsr(23 downto 10);   -- count
        tdata1(9)            := wcsr(9);              -- m
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
      end function;

      function tdata1_ietrigger(rstate : core_state; wcsr : wordx; e : std_logic) return std_logic_vector is
        -- Non-constant
        variable tdata1 : std_logic_vector(XLEN - 6 downto 0) := (others => '0');
      begin
        tdata1(XLEN - 6) := wcsr(XLEN - 6);  -- hit
        tdata1(10)       := e and wcsr(10);  -- nim
        tdata1(9)        := wcsr(9);         -- m
        if mode_s = 1 then
          tdata1(7)    := wcsr(7);           -- s
        end if;
        if mode_u = 1 then
          tdata1(6)    := wcsr(6);           -- u
        end if;
        -- action
        tdata1(5 downto 0) := "00000" & (wcsr(0) and to_bit((wcsr(XLEN - 5) = '1') and
                                                            rstate /= run));
        return tdata1;
      end function;

    begin
      if TRIGGER /= 0 then
        valid := trig_info_vector(sel)(u2i(typ_in));
        case reg is
          when 1 =>
            if tcsr_in.tdata1(sel)(XLEN - 5) = '0' or rstate_in /= run then
              if valid = '1' then  -- New trigger supported
                tcsr.tdata1(sel)(XLEN - 1 downto XLEN - 4) := wcsr_in(XLEN - 1 downto XLEN - 4);
                if rstate_in /= run then
                  tcsr.tdata1(sel)(XLEN - 5)               := wcsr_in(XLEN - 5);
                end if;
                case typ_in is
                  when x"2" =>     -- MCONTROL
                    tcsr.tdata1(sel)(XLEN - 6 downto 0) := tdata1_mcontrol(rstate_in, wcsr_in);
                  when x"3" =>     -- ICOUNT
                    tcsr.tdata1(sel)(XLEN - 6 downto 0) := tdata1_icount(rstate_in, wcsr_in);
                  when x"4" =>     -- ITRIGGER
                    tcsr.tdata1(sel)(XLEN - 6 downto 0) := tdata1_ietrigger(rstate_in, wcsr_in, '0');
                  when x"5" =>     -- ETRIGGER
                    tcsr.tdata1(sel)(XLEN - 6 downto 0) := tdata1_ietrigger(rstate_in, wcsr_in, '1');
                  when others =>
                end case;
              else
                tcsr.tdata1(sel) := (others => '0');
              end if;
            end if;
          when 2 =>
            if tcsr_in.tdata1(sel)(XLEN - 5) = '0' or rstate_in /= run then
              if typ = x"2" then
                tcsr.tdata2(sel) := wcsr_in;
              end if;
            end if;
          when 3 =>
            if tcsr_in.tdata1(sel)(XLEN - 5) = '0' or rstate_in /= run then
            end if;
          when others =>
        end case;
      end if;
      tcsr_out := tcsr;
      

    end;

    function tselect_write(w : std_logic_vector) return std_logic_vector is
      -- Non-constant
      variable tsel : std_logic_vector(w'range) := (others => '0');
    begin
      if u2i(w) < TRIGGER_NUM then
        tsel := w;
      end if;

      return tsel;
    end;

    variable csra_high    : csratype     := csra_in(csra_in'high downto 4) & "0000";
    variable csra_low     : integer      := u2i(csra_in(3 downto 0));
    variable xc           : std_ulogic   := csraxc_in;
    variable h_en         : boolean      := csr_file.misa(h_ctrl) = '1';
    variable v_mode       : std_ulogic   := csr_file.misa(h_ctrl) and csr_file.v;
    variable vu_mode      : std_ulogic   := v_mode and to_bit(csr_file.prv = "00");
    -- Non-constant
    variable xc_v         : std_ulogic   := '0';
    variable writen       : std_ulogic   := csrv_in;
    variable csra         : csratype     := csra_in;
    variable csr          : csr_reg_type := csr_file;
    variable mstatus      : csr_status_type;
    variable hpmevent     : hpmevent_type;
    variable mtvec        : wordx;
    variable pipeflush    : std_ulogic   := '0';
    variable addrflush    : std_ulogic   := '0';
    variable mode         : integer;
    variable upd_mcycle   : std_ulogic   := '0';
    variable upd_minstret : std_ulogic   := '0';
    variable upd_counter  : std_logic_vector(r.csr.hpmcounter'range) := (others => '0');

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

    pmp_precalc(csr_file.pmpaddr, csr_file.pmpcfg0, csr_file.pmpcfg2,
                csr.pmp_precalc,
                pmp_entries, pmp_no_tor, pmp_g, physaddr - 1);

    -- flush should be single cycle
    csr.cctrl.iflush := '0';
    csr.cctrl.dflush := '0';
    csr.cctrl.itcmwipe := '0';
    csr.cctrl.dtcmwipe := '0';


    if writen = '1' and xc = '0' then
      case csra is
        when CSR_FFLAGS         =>
          csr.fflags        := wcsr_in(csr.fflags'length - 1 downto 0);
          csr.mstatus.fs    := "11";
          if csr_file.v = '1' then
            csr.vsstatus.fs := "11";
          end if;
        when CSR_FRM            =>
          csr.frm           := wcsr_in(csr.frm'length - 1 downto 0);
          csr.mstatus.fs    := "11";
          if csr_file.v = '1' then
            csr.vsstatus.fs := "11";
          end if;
        when CSR_FCSR           =>
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
        when CSR_HSTATUS        =>
          csr.hstatus      := to_hstatus(wcsr_in);

        when CSR_HEDELEG        =>
          csr.hedeleg      := wcsr_in and CSR_HEDELEG_MASK;
        when CSR_HIDELEG        =>
          csr.hideleg      := wcsr_in and CSR_HIDELEG_MASK;
        when CSR_HIE            =>
          csr.mie          := (csr_file.mie and not CSR_HIDELEG_MASK) or
                                                       (wcsr_in and CSR_HIDELEG_MASK);
        when CSR_HCOUNTEREN     =>
          csr.hcounteren(HWPERFMONITORS + 2 downto 0) := wcsr_in(HWPERFMONITORS + 2 downto 0);
        when CSR_HGEIE          =>
          csr.hgeie(GEILEN downto 1)              := wcsr_in(GEILEN downto 1);
        -- Hypervisor Trap Handling
        when CSR_HTVAL          =>
          csr.htval        := wcsr_in;
        when CSR_HIP            =>
          -- Only hip(2) VSSIP is writable
          -- mip(2) is aliased in hip(2) and hvip(2)
          csr.mip(2)        := wcsr_in(2);
        when CSR_HVIP           =>
          -- mip(2) is aliased in hip(2) and hvip(2)
          csr.hvip(10)      := wcsr_in(10);
          csr.hvip(6)       := wcsr_in(6);
          csr.mip(2)        := wcsr_in(2);
        when CSR_HTINST         =>
            csr.htinst       := wcsr_in;
        when CSR_HGEIP          =>
          -- Read only
        -- Hypervisor Protection and Translation
        when CSR_HGATP          =>
          -- Assume value is OK
          csr.hgatp                               := wcsr_in and satp_mask(vmidlen, physaddr);
          -- Check that mode is OK, given build options.
          mode := satp_mode(riscv_mmu, wcsr_in);
          if mode = 0 then
            -- Always OK to turn off (0).
            -- All fields are then required to be zero.
            csr.hgatp := (others => '0');
          elsif is_rv32 then
            -- Only off (0 above) or sv32 (1) available for RV32.
          elsif mode = 8 then
            -- Always OK with sv39 (8) for RV64.
          elsif mode = 9 and va'length >= 48 then
            -- When built for it, sv48 (9) is OK too.
          else
            -- Bad mode selection, so turn off MMU.
            -- All fields are then required to be zero.
            csr.hgatp := (others => '0');
          end if;
          pipeflush := '1';
          addrflush := '1';
          if mmuen = 0 then
            csr.hgatp                                := (others => '0');
          end if;
        -- Hypervisor Counter/Timer Virtualization Registers

        when CSR_HENVCFG        =>
          csr.henvcfg        := to_envcfg(wcsr_in, csr_file.henvcfg, csr_file.menvcfg);
        when CSR_HENVCFGH       =>
          if is_rv32 then
            csr.henvcfg      := to_envcfgh(wcsr_in, csr_file.henvcfg, csr_file.menvcfg);
          end if;
        when CSR_HTIMEDELTA     =>
          csr.htimedelta(wordx'range)    := wcsr_in;
        when CSR_HTIMEDELTAH    =>
          if is_rv32 then
            csr.htimedelta(63 downto 32) := wcsr_in(word'range);
          end if;
        -- Virtual Supervisor Registers
        when CSR_VSSTATUS       =>
            csr.vsstatus     := to_vsstatus(wcsr_in);
        when CSR_VSIE           =>
          csr.mie(10)                               := (csr_file.mie(10) and not csr_file.hideleg(10)) or
                                                       (wcsr_in(9) and csr_file.hideleg(10));
          csr.mie(6)                                := (csr_file.mie(6) and not csr_file.hideleg(6)) or
                                                       (wcsr_in(5) and csr_file.hideleg(6));
          csr.mie(2)                                := (csr_file.mie(2) and not csr_file.hideleg(2)) or
                                                       (wcsr_in(1) and csr_file.hideleg(2));
        when CSR_VSTVEC         =>
            csr.vstvec       := wcsr_in(csr.vstvec'high downto 2) & '0' & wcsr_in(0);
        when CSR_VSSCRATCH      =>
            csr.vsscratch    := wcsr_in;
        when CSR_VSEPC          =>
            csr.vsepc        := wcsr_in(csr.vsepc'high downto 1) & '0';
            if ext_c = 0 then
              csr.vsepc(1)   := '0';
            end if;
        when CSR_VSCAUSE        =>
            csr.vscause      := wcsr_in;
        when CSR_VSTVAL         =>
            csr.vstval       := wcsr_in;
        when CSR_VSIP           =>
          csr.mip(2)                                := (csr_file.hvip(2) and not csr_file.hideleg(2)) or
                                                       (wcsr_in(1) and csr_file.hideleg(2));
        when CSR_VSATP          =>
          -- Assume value is OK
          csr.vsatp                               := wcsr_in and satp_mask(asidlen, physaddr);
          -- Check that mode is OK, given build options.
          mode := satp_mode(riscv_mmu, wcsr_in);
          if mode = 0 or is_rv32 then
            -- Always OK to turn off (0), and only that or sv32 (1) available for RV32.
          elsif mode = 8 then
            -- Always OK with sv39 (8) for RV64.
          elsif mode = 9 and va'length >= 48 then
            -- When built for it, sv48 (9) is OK too.
          else
            -- Bad mode selection, so ignore write.
            --csr.vsatp                             := csr_file.vsatp;
            -- Bad mode selection, so turn off MMU.
            -- All fields are then required to be zero.
            csr.vsatp := (others => '0');
          end if;
          pipeflush := '1';
          addrflush := '1';
          if mmuen = 0 then
            csr.vsatp                               := (others => '0');
          end if;
        -- User Counters/Timers - see below
        -- Supervisor Trap Setup
        when CSR_VSTIMECMP      =>
          csr.vstimecmp(wordx'range)    := wcsr_in;
        when CSR_VSTIMECMPH     =>
          if is_rv32 then
            csr.vstimecmp(63 downto 32) := wcsr_in(word'range);
          end if;
        when CSR_SSTATUS        =>
          if h_en and csr_file.v = '1' then
            csr.vsstatus      := to_vsstatus(wcsr_in);
          else
            mstatus     := to_sstatus(wcsr_in, csr_file.mstatus);
            csr.mstatus := tie_status(mstatus, csr_file.misa);
          end if;
        when CSR_SEDELEG        =>
        when CSR_SIDELEG        =>
        when CSR_SIE            =>
          -- mie(10) is aliased in hie(10) and vsie(9)
          -- mie(6)  is aliased in hie(6)  and vsie(5)
          -- mie(2)  is aliased in hie(2)  and vsie(1)
          if h_en and csr_file.v = '1' then
            csr.mie(10)      := (csr_file.mie(10) and not csr_file.hideleg(10)) or
                                (wcsr_in(9) and csr_file.hideleg(10));
            csr.mie(6)       := (csr_file.mie(6) and not csr_file.hideleg(6)) or
                                (wcsr_in(5) and csr_file.hideleg(6));
            csr.mie(2)       := (csr_file.mie(2) and not csr_file.hideleg(2)) or
                                (wcsr_in(1) and csr_file.hideleg(2));
          else
            csr.mie          := (csr_file.mie and (not csr_file.mideleg or CSR_HIE_MASK)) or
                                (wcsr_in and (csr_file.mideleg and not CSR_HIE_MASK));
          end if;
        when CSR_STVEC          =>
          if h_en and csr_file.v = '1' then
            csr.vstvec       := wcsr_in(csr.vstvec'high downto 2) & '0' & wcsr_in(0);
          else
            csr.stvec        := wcsr_in(csr.stvec'high downto 2) & '0' & wcsr_in(0);
          end if;
        when CSR_SCOUNTEREN     =>
          if mode_u = 1 then
            csr.scounteren(HWPERFMONITORS + 2 downto 0) := wcsr_in(HWPERFMONITORS + 2 downto 0);
          end if;
        when CSR_SENVCFG     =>
          if mode_u = 1 then
            csr.senvcfg      := to_envcfg(wcsr_in, csr_file.senvcfg,
                                          envcfg_mask(csr_file.menvcfg, active_senvcfg));
          end if;
        -- Supervisor Trap Handling
        when CSR_SSCRATCH       =>
          if h_en and csr_file.v = '1' then
            csr.vsscratch    := wcsr_in;
          else
            csr.sscratch     := wcsr_in;
          end if;
        when CSR_SEPC           =>
          if h_en and csr_file.v = '1' then
            csr.vsepc        := wcsr_in(csr.sepc'high downto 1) & '0';
            if ext_c = 0 then
              csr.vsepc(1)   := '0';
            end if;
          else
            csr.sepc         := wcsr_in(csr.sepc'high downto 1) & '0';
            if ext_c = 0 then
              csr.sepc(1)      := '0';
            end if;
          end if;
        when CSR_SCAUSE         =>
          if h_en and csr_file.v = '1' then
            csr.vscause      := wcsr_in;
          else
            csr.scause       := wcsr_in;
          end if;
        when CSR_STVAL          =>
          if h_en and csr_file.v = '1' then
            csr.vstval       := wcsr_in;
          else
            csr.stval        := wcsr_in;
          end if;
        when CSR_SIP            =>
          if h_en and csr_file.v = '1' then
            -- hideleg(2) always 1 when hypervisor extension is enabled
            -- mip(2) is aliased in hip(2), hvip(2) and vsip(1)
            if csr_file.hideleg(2) = '1' then
              csr.mip(2)     := wcsr_in(1);
            end if;
          else
            if csr_file.mideleg(1) = '1' then -- Only visible in SIP when delegated
              csr.mip(1)     := wcsr_in(1);   -- Others RO
            end if;
            csr.mip(13)    := wcsr_in(13);
          end if;
        -- Supervisor Protection and Translation
        when CSR_SATP           =>
          -- Assume value is OK
          if h_en and csr_file.v = '1' then
            csr.vsatp                             := wcsr_in and satp_mask(asidlen, physaddr);
          else
            csr.satp                              := wcsr_in and satp_mask(asidlen, physaddr);
          end if;
          -- Check that mode is OK, given build options.
          mode := satp_mode(riscv_mmu, wcsr_in);
          if mode = 0 or is_rv32 then
            -- Always OK to turn off (0), and only that or sv32 (1) available for RV32.
          elsif mode = 8 then
            -- Always OK with sv39 (8) for RV64.
          elsif mode = 9 and va'length >= 48 then
            -- When built for it, sv48 (9) is OK too.
          else
            -- Bad mode selection, so ignore write.
            if h_en and csr_file.v = '1' then
              csr.vsatp                           := csr_file.satp;
            else
              csr.satp                            := csr_file.satp;
            end if;
          end if;
          pipeflush := '1';
          addrflush := '1';
          if mmuen = 0 then
            csr.vsatp                               := (others => '0');
            csr.satp                                := (others => '0');
          end if;
        when CSR_STIMECMP       =>
          if h_en and csr_file.v = '1' then
            csr.vstimecmp(wordx'range)    := wcsr_in;
          else
            csr.stimecmp(wordx'range)     := wcsr_in;
          end if;
        when CSR_STIMECMPH      =>
          if is_rv32 then
            if h_en and csr_file.v = '1' then
              csr.vstimecmp(63 downto 32)    := wcsr_in(word'range);
            else
              csr.stimecmp(63 downto 32)     := wcsr_in(word'range);
            end if;
          end if;
        -- Machine Trap Setup
        when CSR_MSTATUS        =>
          mstatus     := to_mstatus(wcsr_in, csr_file.mstatus);
          csr.mstatus := tie_status(mstatus, csr_file.misa);
        when CSR_MSTATUSH       =>
          if is_rv32 and h_en then
            mstatus   := to_mstatush(wcsr_in, csr_file.mstatus);
          end if;
        when CSR_MISA           =>
          if misa_ctrl then
            -- If changing C extension support is possible,
            -- do not allow turning it off on an unaligned PC.
            -- Specification says that MISA write must then be ignored.
            if ISA_CONTROL(c_ctrl) = '0' or csr_file.misa(c_ctrl) = '0' or
               wcsr_in(c_ctrl) = '1' or pc_in(1 downto 0) = "00" then
              csr.misa := mask_misa(csr_file.misa, wcsr_in);
            end if;
            -- If MISA is changed, a pipeline flush is required.
            if csr.misa /= csr_file.misa then
              pipeflush  := '1';
            end if;
          end if;
        when CSR_MEDELEG        =>
            csr.medeleg      := wcsr_in and medeleg_mask(h_en);
        when CSR_MIDELEG        =>
            csr.mideleg      := to_mideleg(wcsr_in, mode_s, h_en,
                                           ext_sscofpmf);
        when CSR_MIE            =>
            csr.mie          := wcsr_in and mie_mask(mode_s, h_en,
                                                     ext_sscofpmf);
        when CSR_MTVEC          =>
          mtvec                                     := wcsr_in(mtvec'high downto 2) & '0' & wcsr_in(0);
          if wcsr_in(0) = '1' then
            mtvec                                   := wcsr_in(mtvec'high downto 8) & "0000000" & wcsr_in(0);
          end if;
          csr.mtvec                                 := mtvec;
        when CSR_MCOUNTEREN     =>
          csr.mcounteren(HWPERFMONITORS + 2 downto 0) := wcsr_in(HWPERFMONITORS + 2 downto 0);
        -- Machine Trap Handling
        when CSR_MSCRATCH       =>
            csr.mscratch     := wcsr_in;
        when CSR_MEPC           =>
          csr.mepc                                  := wcsr_in(csr.mepc'high downto 1) & '0';
          if ext_c = 0 then
            csr.mepc(1)                             := '0';
          end if;
        when CSR_MCAUSE         =>
            csr.mcause       := wcsr_in(csr.mcause'range);
        when CSR_MTVAL          =>
            csr.mtval        := wcsr_in;
        when CSR_MIP            =>
            csr.mip          := wcsr_in and mip_mask(mode_s, h_en,
                                                     ext_sscofpmf, 
                                                     csr_file.menvcfg.stce);
        when CSR_MTINST         =>
            csr.mtinst       := wcsr_in;
        when CSR_MTVAL2         =>
            csr.mtval2       := wcsr_in;
        when CSR_MENVCFG        =>
            csr.menvcfg      := to_envcfg(wcsr_in, csr_file.menvcfg, active_menvcfg);
        when CSR_MENVCFGH       =>
            csr.menvcfg      := to_envcfgh(wcsr_in, csr_file.menvcfg, active_menvcfg);
        -- Machine Protection and Translation
        when CSR_PMPCFG0        =>
          if is_rv64 then
            pmpcfg_write(csr_file, 0, 7, wcsr_in, csr.pmpcfg0, pipeflush);
          else
            -- Less data in writes to PMPCFG0/2.
            pmpcfg_write(csr_file, 0, 3, wcsr_in, csr.pmpcfg0, pipeflush);
          end if;
        when CSR_PMPCFG1        =>
          if is_rv32 then
            pmpcfg_write(csr_file, 4, 7, wcsr_in, csr.pmpcfg0, pipeflush);
          end if;
        when CSR_PMPCFG2        =>
          if is_rv64 then
            pmpcfg_write(csr_file, 0, 7, wcsr_in, csr.pmpcfg2, pipeflush);
          else
            pmpcfg_write(csr_file, 0, 3, wcsr_in, csr.pmpcfg2, pipeflush);
          end if;
        when CSR_PMPCFG3        =>
          if is_rv32 then
            pmpcfg_write(csr_file, 4, 7, wcsr_in, csr.pmpcfg2, pipeflush);
          end if;
        -- Machine Counter/Timers
        when CSR_MCYCLE         =>
          csr.mcycle(wordx'range)      := wcsr_in;
          upd_mcycle                   := '1';
        when CSR_MCYCLEH        =>
          if is_rv32 then
            csr.mcycle(63 downto 32)   := wcsr_in(word'range);
            upd_mcycle                 := '1';
          end if;
        when CSR_MINSTRET       =>
          csr.minstret(wordx'range)    := wcsr_in;
          upd_minstret                 := '1';
        when CSR_MINSTRETH      =>
          if is_rv32 then
            csr.minstret(63 downto 32) := wcsr_in(word'range);
            upd_minstret               := '1';
          end if;
        -- Machine Hardware Performance Monitoring Event Selector
        when CSR_MCOUNTINHIBIT  =>
          csr.mcountinhibit(0)                      := wcsr_in(0);
          csr.mcountinhibit(31 downto 2)            := wcsr_in(31 downto 2);
        -- Debug/Trace Registers
        when CSR_TSELECT        =>
          csr.tcsr.tselect := tselect_write(wcsr_in(csr.tcsr.tselect'range));
        when CSR_TDATA1         =>
          tdata_write(csr_file.tcsr, 1, rstate_in, wcsr_in, csr.tcsr);
        when CSR_TDATA2         =>
          tdata_write(csr_file.tcsr, 2, rstate_in, wcsr_in, csr.tcsr);
        when CSR_TDATA3         =>
          tdata_write(csr_file.tcsr, 3, rstate_in, wcsr_in, csr.tcsr);
        -- Core Debug Registers
        when CSR_DCSR =>
          if rstate_in /= run then
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
            csr.dcsr.prv                            := wcsr_in(1 downto 0);
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
          csr.dfeaturesen.tpbuf_en                  := wcsr_in(31);
          csr.trace.ctrl(12 downto 8)               := wcsr_in(30 downto 26); 
          -- [25:14] RESERVED
          csr.dfeaturesen.dm_trace                  := wcsr_in(13);
          csr.dfeaturesen.new_irq                   := wcsr_in(12);
          csr.dfeaturesen.fs_dirty                  := wcsr_in(11);
          csr.dfeaturesen.nostream                  := wcsr_in(10);
          csr.dfeaturesen.staticdir                 := wcsr_in(9);
          csr.dfeaturesen.staticbp                  := wcsr_in(8);
          csr.dfeaturesen.mmu_adfault               := wcsr_in(7);
          csr.dfeaturesen.b2bst_dis                 := wcsr_in(6);
          csr.dfeaturesen.lalu_dis                  := wcsr_in(5);
          csr.dfeaturesen.lbranch_dis               := wcsr_in(4);
          csr.dfeaturesen.ras_dis                   := wcsr_in(3);
          csr.dfeaturesen.jprd_dis                  := wcsr_in(2);
          csr.dfeaturesen.btb_dis                   := wcsr_in(1);
          csr.dfeaturesen.dual_dis                  := wcsr_in(0);
          pipeflush := '1';
          addrflush := '1';
        when CSR_FEATURESH =>
          if is_rv32 then
          end if;
        when CSR_CCTRL =>
          -- Bit[11] is RESERVED
          if itcmen = 1 then
            csr.cctrl.itcmwipe                      := wcsr_in(10);
          end if;
          if dtcmen = 1 then
            csr.cctrl.dtcmwipe                      := wcsr_in(9);
          end if;
          csr.cctrl.dsnoop                          := wcsr_in(8);
          csr.cctrl.dflush                          := wcsr_in(7);
          csr.cctrl.iflush                          := wcsr_in(6);
          -- Bit[5:4] is RESERVED
          csr.cctrl.dcs                             := wcsr_in(3 downto 2);
          csr.cctrl.ics                             := wcsr_in(1 downto 0);
          pipeflush := '1';
          addrflush := '1';
        when CSR_TCMICTRL =>
        when CSR_TCMDCTRL =>
        when others =>
          case csra_high is
            -- Machine Hardware Performance Monitoring

            when CSR_MCYCLE =>         -- Base for counters.
              -- CSR_(M)HPMCOUNTER3-15  (0-2 never _ok here!)
              if counter_ok(csra_low) = '1' then
                csr.hpmcounter(csra_low)(wordx'range) := wcsr_in;
                upd_counter(csra_low)                 := '1';
              end if;
            when CSR_MCYCLEH =>        -- Base for counters.
              -- CSR_(M)HPMCOUNTER3-15H  (0-2 never _ok here!)
              if is_rv32 and counter_ok(csra_low) = '1' then
                csr.hpmcounter(csra_low)(63 downto 32) := wcsr_in(word'range);
                upd_counter(csra_low)                  := '1';
              end if;
            -- Machine Hardware Performance Monitoring (continued)
            when CSR_MHPMCOUNTER16 =>  -- All the higher counters.
              -- CSR_(M)HPMCOUNTER16-31
              if counter_ok(csra_low + 16) = '1' then
                csr.hpmcounter(csra_low + 16)(wordx'range) := wcsr_in;
                upd_counter(csra_low + 16)                 := '1';
              end if;
            when CSR_MHPMCOUNTER16H => -- All the higher counters.
              -- CSR_(M)HPMCOUNTER16-31H
              if is_rv32 and counter_ok(csra_low + 16) = '1' then
                csr.hpmcounter(csra_low + 16)(63 downto 32) := wcsr_in(word'range);
                upd_counter(csra_low + 16)                  := '1';
              end if;
            -- Machine Hardware Performance Monitoring Event Selector
            when CSR_MCOUNTINHIBIT =>  -- MCOUNTINHIBIT/MHPMEVENT3-15
              -- CSR_MHPMEVENT3-31  (0-2 never _ok here!)
              if counter_ok(csra_low) = '1' then
                hpmevent               := to_hpmevent(wcsr_in, csr_file.hpmevent(csra_low));
                csr.hpmevent(csra_low) := tie_hpmevent(hpmevent, csr_file.misa);
              end if;
            when CSR_MHPMEVENT16 =>    -- MHPMEVENT16-31
              if counter_ok(csra_low + 16) = '1' then
                hpmevent                    := to_hpmevent(wcsr_in, csr_file.hpmevent(csra_low + 16));
                csr.hpmevent(csra_low + 16) := tie_hpmevent(hpmevent, csr_file.misa);
              end if;
            when CSR_MHPMEVENT0H =>  -- MHPMEVENT3-15H
              -- CSR_MHPMEVENT3-31H  (0-2 never _ok here!)
              if is_rv32 and counter_ok(csra_low) = '1' then
                hpmevent               := to_hpmeventh(wcsr_in, csr_file.hpmevent(csra_low));
                csr.hpmevent(csra_low) := tie_hpmevent(hpmevent, csr_file.misa);
              end if;
            when CSR_MHPMEVENT16H =>    -- MHPMEVENT16-31H
              if is_rv32 and counter_ok(csra_low + 16) = '1' then
                hpmevent                    := to_hpmeventh(wcsr_in, csr_file.hpmevent(csra_low + 16));
                csr.hpmevent(csra_low + 16) := tie_hpmevent(hpmevent, csr_file.misa);
              end if;
            when CSR_PMPADDR0 =>
              if pmp_locked(csr, csra_low) = '0' and            -- Not locked?
                 (csra_low = 15 or
                  not (pmp_locked(csr, csra_low + 1) = '1' and   -- Neither is next TOR and locked?
                       pmpcfg(pmp_entries, csr, csra_low + 1)(4 downto 3) = "01")) then
                csr.pmpaddr(csra_low)                       := (others => '0');
                csr.pmpaddr(csra_low)(pmp_msb - 2 downto 0) := wcsr_in(pmp_msb - 2 downto 0);
              end if;
            when others =>
              null;
          end case;
      end case;
    end if;

    -- Was FPU turned on/off?
    if (csr.mstatus.fs  = "00" and csr_file.mstatus.fs /= "00") or
       (csr.mstatus.fs /= "00" and csr_file.mstatus.fs  = "00") or
       (csr_file.v = '1' and
        ((csr.vsstatus.fs  = "00" and csr_file.vsstatus.fs /= "00") or
         (csr.vsstatus.fs /= "00" and csr_file.vsstatus.fs  = "00"))) then
      pipeflush := '1';
    end if;

    -- Virtual instruction exception
    case csra is
      when CSR_HSTATUS    | CSR_HEDELEG     | CSR_HIDELEG    | CSR_HIE     |
           CSR_HCOUNTEREN | CSR_HGEIE       | CSR_HTVAL      | CSR_HIP     |
           CSR_HVIP       | CSR_HTINST      | CSR_HGEIP      | CSR_HGATP   |
           CSR_HTIMEDELTA | CSR_HTIMEDELTAH | CSR_VSSTATUS   | CSR_VSIE    |
           CSR_VSTVEC     | CSR_VSSCRATCH   | CSR_VSEPC      | CSR_VSCAUSE |
           CSR_VSTVAL     | CSR_VSIP        | CSR_VSATP =>
        xc_v := v_mode;
      when CSR_SSTATUS    | CSR_SEDELEG  | CSR_SIDELEG | CSR_SIE    | CSR_STVEC |
           CSR_SCOUNTEREN | CSR_SSCRATCH | CSR_SEPC    | CSR_SCAUSE | CSR_STVAL |
           CSR_SIP        | CSR_SATP =>
        xc_v := vu_mode;
      when CSR_VSTIMECMP  | CSR_VSTIMECMPH  =>
        if csr_file.menvcfg.stce = '1' then
          xc_v := v_mode;
        end if;
      when CSR_STIMECMP   | CSR_STIMECMPH =>
        if csr_file.menvcfg.stce = '1' and (csr_file.mcounteren(1) or not envcfg.stce) = '1' then
          xc_v := v_mode;
        end if;
      when others =>
    end case;

    -- Hardware Performance Features
    -- (CYCLE, TIME, INSTRET, HPMCOUNTERn)
    -- Bit 7 is high for the ...H CSR variants.
    if csra_in(11 downto 8) = x"c" and csra_in(6 downto 5) = "00" then
      if h_en and csr_file.v = '1' and
         csr_file.mcounteren(u2i(csra_in(4 downto 0))) = '1' and
         csr_file.hcounteren(u2i(csra_in(4 downto 0))) = '0' then
        xc_v := '1';
      end if;
    end if;

    pipeflush_out    := pipeflush;
    addrflush_out    := addrflush;
    xc_out           := (wlane_in'range => xc) and wlane_in;
    if xc_v = '1' then
      cause_out        := XC_INST_VIRTUAL_INST;  -- Only valid when xc_out.
    else
      cause_out        := XC_INST_ILLEGAL_INST;  -- Only valid when xc_out.
    end if;
    csr_out          := csr;
    upd_mcycle_out   := upd_mcycle;
    upd_minstret_out := upd_minstret;
    upd_counter_out  := upd_counter;
  end;

  -- Instruction Control Unit
  -- Note that both v_fusel_eq(r, stage, lane, fusel) and v_rd_eq(r, stage, lane, rs)
  -- verify that the instruction in that stage and lane is actually valid.
  procedure instruction_control(r          : in    registers;
                                fpu_ready  : in    std_ulogic;
                                fpu_idle   : in    std_ulogic;
                                lddp       : out   std_ulogic;
                                sdb2b      : out   std_ulogic;
                                lbrancho   : out   std_ulogic;
                                laluo      : out   std_logic_vector;
                                spec_ldo   : out   std_ulogic;
                                accesshold : inout std_logic_vector;
                                exechold   : inout std_logic_vector;
                                fpuhold    : inout std_logic_vector;
                                holdi      : out   std_ulogic) is
    -- Non-constant
    variable hold      : std_ulogic    := '0';
    variable hvec      : word16        := (others => '0');  -- Only for debug
    variable mul_rd    : rfatype;
    variable lbranch   : std_ulogic    := '0';
    variable lbranchdp : std_ulogic    := '0';
    variable lcsr      : fetch_pair    := (others => '0');
    variable lalu      : fetch_pair    := (others => '0');
    variable laludp    : std_ulogic    := '0';  -- Lane 1 is dependent on lane 0 (no swap)
    variable csrw_eq   : std_ulogic    := '0';
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
    if v_fusel_eq(r, a, 0, ALU or MUL or LD or FPU) then
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

    -- This is an implicit "late ALU"!
    if csr_ok(r, a) then
      lcsr(csr_lane) := '1';
    end if;

    -- Lane 0: LD/ALU
    -- Lane 1: ALU
    --      0                  1
    -- A    ALU,LD,MUL -> Rn   ALU <- Rn   (no swap)
    -- If there is a swap it is not actually a dependency.
    if v_fusel_eq(r, a, 0, ALU or LD or MUL or FPU)  then
      if single_issue = 0 and
         v_fusel_eq(r, a, 1, ALU) and r.a.ctrl(1).rdv = '1' and r.a.swap = '0' then
        if v_rd_eq(r, a, 0, r.a.rfa1(1)) or
           v_rd_eq(r, a, 0, r.a.rfa2(1)) then
          lalu(1)     := '1';
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

    -- In case previous instructions use late alus, drive this one to them as well
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

    -- Some ALU instructions can never be handled in the late ALU:s!
    for j in lanes'range loop
      if lalu(j) = '1' then
        if v_fusel_eq(r, a, j, ALU_SPECIAL) then
          hold := '1';
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
        -- lalu(1) = '1' implies that the instruction at A(1) must be valid.
        (v_fusel_eq(r, a, memory_lane, ST) and lalu(1) = '1' and rd(r, a, 1) = r.a.rfa2(memory_lane) and r.a.swap = '1') or
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
    csrw_eq := '0';
    for i in 0 to r.a.csrw_eq'high loop
      if r.a.csrw_eq(i) = '1' then
        csrw_eq := '1';
      end if;
    end loop;
    if csr_ok(r, a) and not csr_write_only(r, a) then
      -- Hold Issue stage if there is already a CSR instruction in the pipeline
      -- that accesses the same register, or one in the same category, unless
      -- that access is read-only. Also unless the new access is write-only.
      if (r.wb.ctrl(csr_lane).csrdo = '0') and csr_ok(r, wb) then
        if (csrw_eq = '1') or csr_category_eq(r, a, wb) then
          hold    := '1';
          hvec(5) := '1';
        end if;
      end if;
      if (r.x.ctrl(csr_lane).csrdo = '0') and csr_ok(r, x) then
        if (csrw_eq = '1') or csr_category_eq(r, a, x) then
          hold    := '1';
          hvec(5) := '1';
        end if;
      end if;
      if (r.m.ctrl(csr_lane).csrdo = '0') and csr_ok(r, m) then
        if (csrw_eq = '1')  or csr_category_eq(r, a, m) then
          hold    := '1';
          hvec(5) := '1';
        end if;
      end if;
      if (r.e.ctrl(csr_lane).csrdo = '0') and csr_ok(r, e) then
        if (csrw_eq = '1')  or csr_category_eq(r, a, e) then
          hold    := '1';
          hvec(5) := '1';
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
    if csr_ok(r, e) and not csr_read_only(r, e) and csr(r, e).category(6) = '1' then
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
    if csr_ok(r, e) and not csr_read_only(r, e) and
       csr_category(csr_addr(r, e))(5) = '1'    and
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
    if csr_ok(r, e) and not csr_read_only(r, e) and csr(r, e).category(7) = '1' then
      exechold   := (exechold'range => '1');
    end if;
    if r.e.ctrl(memory_lane).valid = '1' then
      if is_fence_i(r.e.ctrl(memory_lane).inst)     or
         is_sfence_vma(r.e.ctrl(memory_lane).inst)  or
         is_hfence_vvma(r.e.ctrl(memory_lane).inst) or
         is_hfence_gvma(r.e.ctrl(memory_lane).inst) then
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
      if csr_ok(r, a) and csr(r, a).category(8) = '1' then
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
      if csr_ok(r, a) and csr(r, a).category(9) = '1' and not csr_read_only(r, a) then
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
          ((((not is_hsv(r.a.ctrl(memory_lane).inst) and r.a.ctrl(memory_lane).inst(13) = '0') or
             (    is_hsv(r.a.ctrl(memory_lane).inst) and r.a.ctrl(memory_lane).inst(27) = '0')) or
            ((not is_hsv(r.e.ctrl(memory_lane).inst) and r.e.ctrl(memory_lane).inst(13) = '0') or
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
    -- time for nullify signals hence it has to be at least 2 cycles behind a late branch.
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
          if is_sfence_vma(r.a.ctrl(memory_lane).inst)  or
             (ext_h = 1 and (is_hfence_vvma(r.a.ctrl(memory_lane).inst) or
                             is_hfence_gvma(r.a.ctrl(memory_lane).inst))) then
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
      if v_fusel_eq(r, a, memory_lane, LD) and not(v_fusel_eq(r, a, memory_lane, AMO)) then
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
    -- A load/store operation need to be at least 2 cycles behind CBO operations
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
    lbrancho    := lbranch and not(r.csr.dfeaturesen.lbranch_dis);
    laluo       := lcsr or (lalu and (lalu'range => not(r.csr.dfeaturesen.lalu_dis)));
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
                    ctrl_out    : out std_logic_vector;
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
                    l_valid     : in  std_logic_vector;
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
                                forw_out     : out std_logic_vector;
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
          v_rd_eq_xvalid(r, e, 1, ex1_valid_in, rfa2) then
      ex_forw_op2       := "11";
    elsif v_rd_eq_xvalid(r, e, 0, ex0_valid_in, rfa2) then
      ex_forw_op2       := "10";
    elsif single_issue = 0 and
          v_rd_eq(r, m,  1, rfa2) then
      -- Do not forward directly from late ALU.
      if r.m.alu(1).lalu = '0' then
        -- Do not forward directly from MUL.
        -- Handled by forwarding in a later cycle instead.
        if not v_fusel_eq(r, m, 1, MUL or FPU) then
          mem_forw_op2  := "11";
        end if;
      end if;
    elsif v_rd_eq(r, m,  0, rfa2) then
      -- Do not forward directly from late ALU.
      if r.m.alu(0).lalu = '0' then
        -- Do not forward directly from cache access or MUL.
        -- Handled by forwarding in a later cycle instead.
        if not v_fusel_eq(r, m, 0, LD or MUL or FPU) then
          mem_forw_op2  := "10";
        end if;
      end if;
    elsif single_issue = 0 and
          v_rd_eq(r, x,  1, rfa2) then
      -- Do not forward directly from late ALU.
      -- Handled by forwarding in next cycle instead.
      if r.x.alu(1).lalu = '0' then
        xc_forw_op2     := "11";
      end if;
    elsif v_rd_eq(r, x,  0, rfa2) then
      -- Do not forward directly from late ALU.
      -- Handled by forwarding in next cycle instead.
      if r.x.alu(0).lalu = '0' then
        xc_forw_op2     := "10";
      end if;
    elsif single_issue = 0 and
          v_rd_eq(r, wb, 1, rfa2) then
      wb_forw_op2       := "11";
    elsif v_rd_eq(r, wb, 0, rfa2) then
      wb_forw_op2       := "10";
    else
    end if;

    -- First Stage Mux for Op2
    if xc_forw_op2 = "10" then
      -- Forward data from load result if LD operation.
      if v_fusel_eq(r, x, memory_lane, LD) then
        mux_output_op2  := r.x.data(0)(wordx'range);
      else
        mux_output_op2  := r.x.result(0);
      end if;
    elsif single_issue = 0 and
          xc_forw_op2 = "11" then
      mux_output_op2    := r.x.result(1);
    elsif mem_forw_op2 = "10" then
      mux_output_op2    := r.m.result(0);
    elsif single_issue = 0 and
          mem_forw_op2 = "11" then
      mux_output_op2    := r.m.result(1);
    elsif wb_forw_op2 = "10" then
      mux_output_op2    := r.wb.wdata(0);
    elsif single_issue = 0 and
          wb_forw_op2 = "11" then
      mux_output_op2    := r.wb.wdata(1);
    else
    end if;

    -- Second Stage Mux for Op2
    if    (xc_forw_op2(1) or mem_forw_op2(1) or wb_forw_op2(1)) = '1' then
      stdata            := mux_output_op2;
    elsif single_issue = 0 and
          ex_forw_op2 = "11" then
      stdata            := ex_result(1);
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
      if is_fence_i(r.x.ctrl(memory_lane).inst)     or
         is_sfence_vma(r.x.ctrl(memory_lane).inst)  or
         is_hfence_vvma(r.x.ctrl(memory_lane).inst) or
         is_hfence_gvma(r.x.ctrl(memory_lane).inst) then
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
    -- Non-constant
    variable bht   : nv_bht_in_type;
    variable waddr : pctype := ctrl_in.pc;
  begin
    -- Write next address in case of a branch which wraps
    -- a word boundary.
    if ext_c = 1 then
      if ctrl_in.comp = '0' then
        if (single_issue = 0 and ctrl_in.pc(2 downto 1) = "11") or
        (single_issue /= 0 and ctrl_in.pc(1) = '1') then
          waddr   := unalg_pc;
        end if;
      end if;
    end if;

    -- Update BHT with branch or unconditional jump address.
    bht.waddr   := pc2xlen(waddr);
    bht.wen     := ctrl_in.valid and ctrl_in.branch.valid;
    bht.wdata   := ctrl_in.branch.dir;
    bht.taken   := ctrl_in.branch.taken;

    if ctrl_in.valid = '1' and v_fusel_eq(ctrl_in.fusel, JAL) and csren_in.jprd_dis = '0' then
      bht.wen   := '1';
      bht.taken := '1';
    end if;

    bht_out     := bht;
  end;

  -- BTB Update Procedure
  procedure btb_update(ctrl_in    : in  pipeline_ctrl_type;
                       unalg_pc   : in  pctype;
                       csren_in   : in  csr_dfeaturesen_type;
                       wb_fence_i : in  std_ulogic;
                       btb_out    : out nv_btb_in_type) is
    -- Non-constant
    variable waddr : pctype := ctrl_in.pc;
    variable btb   : nv_btb_in_type;
  begin
    -- Write next address in case of a branch which wraps
    -- a word boundary.
    if ext_c = 1 then
      if ctrl_in.comp = '0' then
        if (single_issue = 0 and ctrl_in.pc(2 downto 1) = "11") or
          (single_issue /= 0 and ctrl_in.pc(1) = '1') then
          waddr := unalg_pc;
        end if;
      end if;
    end if;

    -- Update BTB with branch or unconditional jump address
    btb.waddr := pc2xlen(waddr);
    btb.wen   := ctrl_in.valid and ctrl_in.branch.valid and ctrl_in.branch.taken and not ctrl_in.branch.hit and not ctrl_in.xc;
    btb.wdata := to0x(ctrl_in.branch.addr);
    btb.flush := wb_fence_i;

    if ctrl_in.valid = '1' and v_fusel_eq(ctrl_in.fusel, JAL) and csren_in.jprd_dis = '0' then
      -- Target address is included in ctrl_in.branch.addr
      btb.wen := not ctrl_in.branch.hit;
    end if;

    btb_out   := btb;
  end;


  function trigger_action(tdata : wordx) return std_logic_vector is
    variable typ    : std_logic_vector(3 downto 0) := tdata(tdata'high downto tdata'high - 3);
    -- Non-constant
    variable action : word64;
  begin
    action  := (others => '0');
    case typ is
      when "0000" | "0001" | "1111"  =>
      when "0010" =>
        action(u2i(tdata(15 downto 12))) := '1';
      when others =>
        action(u2i(tdata(5 downto 0)))   := '1';
    end case;

    return action;
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

  function trigger_mcontrol_match(tdata1 : wordx;
                                  tdata2 : wordx;
                                  value  : wordx) return std_logic is
    variable match  : std_logic_vector(3 downto 0) := tdata1(10 downto 7);
    -- Non-constant
    variable hit    : std_logic;
    variable mask   : wordx;
  begin
    hit     := '0';

    -- [3] = 1 : invert match
    case match(2 downto 0) is
      when "000" =>         -- value = tdata2
        hit := match(3) xor to_bit(tdata2 = value);
      when "001" =>         -- value(high:high-M) = tdata2(high:high-M)
        mask := trigger_mcontrol_mask(63, tdata2);
        hit := match(3) xor to_bit((tdata2 and mask) =
                                   (value and mask));
      when "010" | "011" => -- value >= tdata2, value < tdata2
        hit := match(3) xor (match(0) xor to_bit(unsigned(tdata2) < unsigned(value)));
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

    return hit;
  end;

  subtype hit_vec_type is std_logic_vector(lanes_type'high + 1 downto lanes_type'low);
  function trigger_mcontrol(tdata1 : wordx;
                            tdata2 : wordx;
                            e_ctrl : pipeline_ctrl_lanes_type;
                            avalid : std_logic;
                            addr   : addr_type;
                            size   : std_logic_vector(1 downto 0);
                            awrite : std_logic;
                            rvalid : std_logic;
                            rdata  : word64;
                            wvalid : std_logic;
                            wdata  : word64) return hit_vec_type is
    variable sizev    : std_logic_vector(3 downto 0) := tdata1(22 downto 21) & tdata1(17 downto 16);
    variable selectv  : std_logic                    := tdata1(19);
    variable exec     : std_logic                    := tdata1(2);
    variable store    : std_logic                    := tdata1(1);
    variable load     : std_logic                    := tdata1(0);
    -- Non-constant
    variable hit      : lanes_type                   := (others => '0');
    variable ehit     : lanes_type                   := (others => '0');
    variable ahit     : std_logic                    := '0';
    variable valid    : std_logic                    := '0';
    variable value    : wordx_lanes_type             := (others => (others => '0'));
    variable del      : std_logic                    := '0';
    variable ret      : hit_vec_type;
  begin
    if exec = '1' then
      for i in e_ctrl'range loop
        if selectv = '0' then
          value(i) := to64(e_ctrl(i).pc)(wordx'range);
        else
          value(i)(e_ctrl(i).inst'range) := e_ctrl(i).inst;
        end if;
        ehit(i)    := trigger_mcontrol_match(tdata1, tdata2, value(i));
      end loop;
    else
      if selectv = '0' then
        valid      := avalid and ((load and not awrite) or (store and awrite));
        value(0)   := to64(addr)(wordx'range);
      else
        if load = '1' then
          valid    := rvalid;
          value(0) := rdata(wordx'range);
        elsif store = '1' then
          valid    := wvalid;
          value(0) := wdata(wordx'range);
        end if;
        del        := '1';
      end if;
      ahit         := trigger_mcontrol_match(tdata1, tdata2, value(0));
    end if;

    for i in hit'range loop
      hit(i)       := (e_ctrl(i).valid and ehit(i));
      if i = 0 then
        hit(i)     := hit(i) or (valid and ahit);
      end if;
    end loop;

    ret := ((valid and del) & hit);

    return ret;
  end;

  function trigger_icount(tdata1 : wordx;
                          e_swap : std_logic;
                          e_ctrl : pipeline_ctrl_lanes_type;
                          m_ctrl : pipeline_ctrl_lanes_type;
                          x_ctrl : pipeline_ctrl_lanes_type) return hit_vec_type is
    variable cnt_hi   : std_logic_vector(13 downto 3) := tdata1(23 downto 13);
    variable cnt_low  : std_logic_vector(2 downto 0)  := tdata1(12 downto 10);
    -- Non-constant
    variable hit      : lanes_type                    := (others => '0');
    variable instv    : std_logic_vector(3 downto 0)  := (others => '0');
    variable insts    : integer range 0 to 4          := 0;
    variable valid    : std_logic                     := '0';
    variable del      : std_logic                     := '0';
    variable ret      : hit_vec_type;
    variable cnt      : std_logic_vector(3 downto 0);
  begin
    -- Somewhat strange implementation of valid instruction count.
    -- Done this way to make Formality understand that there is
    -- no possibility for insts to go outside of its 0-4 range.
    instv(0)   := x_ctrl(0).valid;
    instv(1)   := m_ctrl(0).valid;
    if single_issue /= 0 then
      instv(2) :=x_ctrl(one).valid;
      instv(3) :=m_ctrl(one).valid;
    end if;
    if all_1(instv) then
      insts := 4;
    else
      insts := u2i(pop(instv)(1 downto 0));
    end if;

    cnt := std_logic_vector(signed('0' & cnt_low) - insts);

    if cnt_hi = (cnt_hi'range => '0') then
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
      elsif cnt = x"1" then
        if (e_ctrl(0).valid and e_ctrl(one).valid) = '1' then
          if e_swap = '0' then
            hit(one) := '1';
          else
            hit(0)   := '1';
          end if;
        end if;
      end if;
    end if;

    ret := ('0' & hit);

    return ret;
  end;

  -- Trigger Module
  procedure trigger_module(trig_in  : in  trig_type;
                           tcsr     : in  csr_tcsr_type;
                           prv      : in  priv_lvl_type;
                           flush    : in  std_logic;
                           step     : in  std_logic;
                           haltreq  : in  std_logic;
                           x_rstate : in  core_state;
                           clr_pen  : in  std_logic;
                           x_ctrl   : in  pipeline_ctrl_lanes_type;
                           m_swap   : in  std_logic;
                           m_ctrl   : in  pipeline_ctrl_lanes_type;
                           e_swap   : in  std_logic;
                           e_ctrl   : in  pipeline_ctrl_lanes_type;
                           avalid   : in  std_logic;
                           addr     : in  addr_type;
                           size     : in  std_logic_vector(1 downto 0);
                           awrite   : in  std_logic;
                           rvalid   : in  std_logic;
                           rdata    : in  word64;
                           wvalid   : in  std_logic;
                           wdata    : in  word64;
                           m_trig   : out trig_type) is
    -- Non-constant
    variable valid    : std_logic;
    variable trig     : trig_type    := trig_none;
    variable hit      : hit_vec_type := (others => '0');
    variable hitv     : hit_vec_type := (others => '0');
    variable tdata1   : wordx;
    variable tdata2   : wordx;
    variable mchitv   : trighit_type := (others => '0');
    variable ichitv   : trighit_type := (others => '0');
    variable iethitv  : trighit_type := (others => '0');
    variable swap     : std_logic    := e_swap;
    variable action   : word64;
  begin

    if TRIGGER /= 0 then
      for i in 0 to TRIGGER_MC_NUM + TRIGGER_IC_NUM - 1 loop

        tdata1  := tcsr.tdata1(i);
        tdata2  := tcsr.tdata2(i);

        -- Active common for all trigger types
        -- in : m,s,u
        -- Check privilege mode
        if x_rstate = run then
          valid := trigger_valid(prv, tdata1);
        else
          valid := '0';
        end if;

        -- MCONTROL
        -- in : maskmax (constant)
        -- in : select 0 = addr, 1 = data/inst
        -- in : timing (constant ?)
        -- in : sizelo/hi access/inst size to match
        -- in : chain ...
        -- in : match ...
        -- in : exec, load, store
        -- out: hit = match
        -- tdata2 = data (and mask)
        if i < TRIGGER_MC_NUM then
          hit := trigger_mcontrol(
                   tdata1 => tdata1,
                   tdata2 => tdata2,
                   e_ctrl => e_ctrl,
                   avalid => avalid,
                   addr   => addr,
                   size   => size,
                   awrite => awrite,
                   rvalid => rvalid,
                   rdata  => rdata,
                   wvalid => wvalid,
                   wdata  => wdata);
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
        end if;

        mchitv(i) := valid and orv(hit(lanes_type'range));
        hitv      := hitv or (hit and (hit'range => valid));

        -- ITRIGGER / ETRIGGER
        -- out: hit = match
        -- tdata2 = interrupt
        -- action taken on the next inst (first inst in trap handler)
        -- only fires if the hart takes a trap because of the interrupt

        -- ETRIGGER
        -- in : NMI
        -- tdata2 = exception
        -- action taken on the next inst (first inst in trap handler)
        -- trigger may fire on up to XLEN of the Exception Codes defined in mcause

        -- Action common for all trigger types
        -- in : action
        --        0   = trap breakpoint exception in M-mode, set mepc
        --        1   = enter debug-mode, set mepc (dmode need to be 1)
        --        2-5 = Reserved for use by the trace specification
        if valid = '1' then
          action      := trigger_action(tdata1);
          trig.action := trig.action or action(trig.action'range);
        end if;
      end loop;
    end if;

    for i in lanes'range loop
      trig.valid(i)   := hitv(i);
    end loop;
    -- Imprecise trigger
    if get_hi(hitv) = '1' then
      for i in lanes'range loop
        trig.valid(i) := e_ctrl(i).valid;
      end loop;
      trig.pending    := '1';
    end if;
    trig.hit          := mchitv;

    -- Single and halt step
    if x_rstate = run then
      -- Single
      if step = '1' then
        if single_issue = 0 and
           (m_ctrl(0).valid and m_ctrl(one).valid) = '1' then
          swap              := m_swap;
          if m_swap = '0' then
            trig.valid(1)   := '1';
          else
            trig.valid(0)   := '1';
          end if;
        -- Only one of m_ctrl(0/1).valid can be set here.
        elsif (m_ctrl(0).valid or m_ctrl(one).valid) = '1' then
          if (e_ctrl(0).valid = '1') xor (single_issue = 0 and e_ctrl(one).valid = '1') then
            for i in lanes'range loop
              trig.valid(i) := e_ctrl(i).valid;
            end loop;
          end if;
          -- Always set pending, this instruction could be nullified
          trig.pending      := '1';
        end if;
      end if;

      -- Halt
      for i in lanes'range loop
        if haltreq = '1' then
          trig.valid(i) := e_ctrl(i).valid;
        end if;
      end loop;

      if step = '1' or haltreq = '1' then
        trig.action := (1 => '1', others => '0');
        trig.hit    := (others => '0');
      end if;
    end if;

    if trig_in.pending = '1' then
      trig            := trig_in;
      for i in lanes'range loop
        trig.valid(i) := e_ctrl(i).valid;
      end loop;
    end if;

    trig.nullify(0)     := trig.valid(0) or (to_bit(single_issue = 0) and trig.valid(one) and swap);
    if single_issue = 0 then
      trig.nullify(one) := trig.valid(one) or (trig.valid(0) and (not swap));
    end if;

    if orv(trig_in.nullify) = '1' then
      trig.nullify := (others => '1');
    end if;

    if flush = '1' then
      trig.valid   := (others => '0');
      trig.nullify := (others => '0');
    end if;

    if clr_pen = '1' then
      trig.pending := '0';
    end if;

    m_trig  := trig;
  end;

  -- Deb Module Procedure
  procedure debug_module(r              : in  registers;
                         dpc_in         : in  wordx;
                         dcsr_in        : in  csr_dcsr_type;
                         prv_in         : in  priv_lvl_type;
                         v_in           : in  std_ulogic;
                         useDebug       : in  integer;
                         dbgi           : in  nv_debug_in_type;
                         dm_in          : in  debugmodule_reg_type;
                         xc_in          : in  std_logic_vector;
                         xc_taken_in    : in  std_ulogic;
                         xc_cause_in    : in  cause_type;
                         dret_in        : in  std_ulogic;
                         x_trig         : in  trig_type;
                         rfo_data1      : in  wordx;
                         csr_data1      : in  wordx;
                         tbo_data       : in  std_logic_vector(TRACE_WIDTH - 1 downto 0);
                         tbufcnt        : in  std_logic_vector;
                         running_out    : out std_ulogic;
                         halted_out     : out std_ulogic;
                         pc_out         : out pctype;
                         req_out        : out std_ulogic;
                         rstate_out     : out core_state;
                         prv_out        : out priv_lvl_type;
                         v_out          : out std_ulogic;
                         dpc_out        : out wordx;
                         dcsr_out       : out csr_dcsr_type;
                         dm_out         : out debugmodule_reg_type;
                         flushall_out   : out std_ulogic;
                         dvalid_out     : out std_ulogic;
                         ddata_out      : out word64;
                         derr_out       : out std_ulogic;
                         dexec_done_out : out std_ulogic;
                         error_out      : out std_ulogic;
                         haltreq_out    : out std_ulogic;
                         stoptime_out   : out std_ulogic) is
    -- Non-constant
    -- Output signals to the Debug Module
    variable dvalid      : std_ulogic    := '0';
    variable dexec_done  : std_ulogic    := '0';
    variable ddata       : word64        := (others => '0');
    variable derr        : std_ulogic    := '0';

    variable flushall    : std_ulogic    := '0';
    variable dcsr        : csr_dcsr_type := dcsr_in;
    variable dpc         : wordx;
    variable rstate      : core_state    := r.x.rstate;
    variable prv         : priv_lvl_type := prv_in;
    variable v           : std_ulogic    := v_in;
    variable dm          : debugmodule_reg_type := dm_in;

    -- Signals for the PC Fetch
    variable dfpc        : wordx         := dpc_in;
    variable req         : std_ulogic    := '0';     --

    variable halted      : std_ulogic    := '0';
    variable running     : std_ulogic    := '1';
    variable halt_ebreak : std_ulogic    := '0';
    variable verror      : std_ulogic    := '0';
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

    if r.x.rstate = run and
       (dbgi.halt = '1'
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
       (dbgi.dsuen = '1'
       ) and useDebug = 1 then
      if TRIGGER /= 0 and orv(x_trig.valid) = '1' and
         orv(x_trig.hit) = '1' and x_trig.action(1) = '1' then -- triggers
        dcsr.cause   := DCAUSE_TRIG;
        rstate       := dhalt;
        dcsr.prv     := r.csr.prv;
        dcsr.v       := r.csr.v;
        prv          := PRIV_LVL_M;
        v            := '0';
        -- Assert flushall signal in order to annull next instructions.
        flushall     := '1';
        -- Find the trapped instruction.
        if r.x.swap = '0' then
          if x_trig.valid(0) = '1' then
            dpc      := pc2xlen(r.x.ctrl(0).pc);
          elsif single_issue = 0 then -- x_trig.valid(1) = '1'
            dpc      := pc2xlen(r.x.ctrl(one).pc);
          end if;
        else
          if single_issue = 0 and
             x_trig.valid(1) = '1' then
            dpc      := pc2xlen(r.x.ctrl(one).pc);
          else -- x_trig.valid(0) = '1'
            dpc      := pc2xlen(r.x.ctrl(0).pc);
          end if;
        end if;
      elsif xc_taken_in = '1' and xc_cause_in = XC_INST_BREAKPOINT and halt_ebreak = '1' then
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
      elsif orv(x_trig.valid) = '1' then -- Halt and Step
        if dbgi.halt = '1' then
        -- Halt request from the Debug Module
        -- Wait for valid instruction marked with trig in the exception stage.
          dcsr.cause := DCAUSE_HALT;
        elsif r.csr.dcsr.step = '1' then
        -- Single Step from the Hart
        -- Wait for valid instruction in the exception stage.
          dcsr.cause := DCAUSE_STEP;
        end if;

        rstate       := dhalt;
        dcsr.prv     := r.csr.prv;
        dcsr.v       := r.csr.v;
        prv          := PRIV_LVL_M;
        v            := '0';
        -- Assert flushall signal in order to annull next instructions.
        flushall     := '1';
        -- Find single step instruction and the next one.
        if r.x.swap = '0' then
          if x_trig.valid(0) = '1' then
            dpc      := pc2xlen(r.x.ctrl(0).pc);
          elsif single_issue = 0 then  -- x_trig.valid(1) = '1'
            dpc      := pc2xlen(r.x.ctrl(one).pc);
          end if;
        else
          if single_issue = 0 and
             x_trig.valid(1) = '1' then
            dpc      := pc2xlen(r.x.ctrl(one).pc);
          else -- x_trig.valid(0) = '1'
            dpc      := pc2xlen(r.x.ctrl(0).pc);
          end if;
        end if;
      end if;
      

      -- Assert error signal when not entering debug mode on EBREAK exception
      if xc_taken_in = '1' and xc_cause_in = XC_INST_BREAKPOINT and
         halt_ebreak = '0' and r.csr.prv = PRIV_LVL_M then
        verror       := '1';
      end if;
    elsif r.x.rstate = run and (dbgi.dsuen = '0' or useDebug = 0) then
      -- Assert error signal when not entering debug mode on EBREAK exception
      if xc_taken_in = '1' and xc_cause_in = XC_INST_BREAKPOINT and
         halt_ebreak = '0' and r.csr.prv = PRIV_LVL_M then
        verror       := '1';
      end if;
    end if;

    ---------------
    -- Halt State
    ---------------

    -- There can be two reasons to exit from Debug Module, we check them following
    -- the above priorities.
    -- * 2 -> dret instruction
    -- * 1 -> Debug Module Request
    dm.cmdexec := '0' & dm_in.cmdexec(1);

    if r.x.rstate = dhalt and dbgi.dsuen = '1' and useDebug = 1 then
      if dret_in = '1' then -- generate in the exception stage
        rstate         := run;
        prv            := r.csr.dcsr.prv;
        v              := r.csr.dcsr.v;
        -- Generate signal for the PC
        req            := '1';
      elsif dbgi.resume = '1' and dbgi.denable = '0' then
        -- Check for resume signal from Debug Module.
        -- Do not resume execution if command is still on going.
        rstate         := run;
        prv            := r.csr.dcsr.prv;
        v              := r.csr.dcsr.v;
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
          else
            -- Don't execute if REG access fails
            dexec_done := '1';
          end if;
        end if;
      end if;
    elsif r.x.rstate = dexec and dbgi.dsuen = '1' and useDebug = 1 then
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
    pc_out         := to_addr(dfpc);
    req_out        := req;
    rstate_out     := rstate;
    prv_out        := prv;
    v_out          := v;
    dpc_out        := dpc;
    dcsr_out       := dcsr;
    dm_out         := dm;
    flushall_out   := flushall;
    dvalid_out     := dvalid;
    ddata_out      := ddata;
    derr_out       := derr;
    dexec_done_out := dexec_done;
    error_out      := verror;
    haltreq_out    := haltreq;
    stoptime_out   := stoptime;
  end;

begin

  ----------------------------------------------------------------------------
  -- Signal Assignments
  ----------------------------------------------------------------------------

  hart <= u2vec(hindex, hart);

  arst <= testrst when (ASYNC_RESET and scantest /= 0 and testen /= '0')  else
          rstn when ASYNC_RESET else '1';

  csr_mmu.satp        <= r.mmu.satp;
  csr_mmu.vsatp       <= r.mmu.vsatp;
  csr_mmu.hgatp       <= r.mmu.hgatp;
  csr_mmu.mmu_adfault <= r.mmu.mmu_adfault;
  csr_mmu.pmpcfg0     <= r.mmu.pmpcfg0;
  csr_mmu.pmpcfg2     <= r.mmu.pmpcfg2;
  csr_mmu.precalc     <= r.csr.pmp_precalc;
  csr_mmu.cctrl       <= r.csr.cctrl;


  comb : process(r, bhto, btbo, raso, ico, dco, rfo, irqi, dbgi,
                 itraceo,
                 mulo, divo, fpuo, tbo, hart, rstn, holdn, mmu_csr, perf, cap)

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
    variable dbg_error          : std_ulogic;
    variable dbg_haltreq        : std_ulogic;
    variable dbg_stoptime       : std_ulogic;

    -- FPU
    variable vfpui              : fpu5_in_type;


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

    -- Decode Stage
    variable de_inst            : iword_pair_type;
    variable de_inst_buff       : iword_pair_type;
    variable de_comp_ill        : std_logic_vector(1 downto 0);
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
    variable de_buff_inst_xc    : std_logic_vector(2 downto 0);
    variable de_inst_no_buf     : std_logic_vector(1 downto 0);
    variable de_inst_mexc       : std_logic_vector(1 downto 0);
    variable v_a_inst_no_buf    : std_logic_vector(1 downto 0);
    variable de_nullify         : std_ulogic;
    variable de_branch          : std_ulogic;
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
    variable de_bjump_pos       : std_logic_vector(3 downto 0);
    variable de_bjump_addr      : pctype;
    variable de_bhto_taken      : fetch_pair;
    variable de_bhto_taken_tmp  : std_ulogic;
    variable de_bhto_dir0       : std_logic_vector(bhti.wdata'range);
    variable de_bhto_dir1       : std_logic_vector(bhti.wdata'range);
    variable de_bhto_dir_tmp    : std_logic_vector(bhti.wdata'range);
    variable de_btbo_hit        : fetch_pair;
    variable de_btbo_hit_tmp    : std_ulogic;
    variable de_btb_valid       : std_logic_vector(3 downto 0);
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
    variable de_rvc_comp_ill        : std_logic_vector(1 downto 0);
    variable de_rvc_aligned         : iword_pair_type;
    variable de_mux_instruction     : iword_pair_type;
    variable de_rvc_bhto_taken      : std_logic_vector(1 downto 0);
    variable de_rvc_btb_hit         : std_logic_vector(1 downto 0);
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
    variable de_rvc_buff_lpc        : std_logic_vector(1 downto 0);
    variable de_inst_comp_ill       : std_logic_vector(1 downto 0);

    -- Register File Stage
    variable ra_data12          : wordx_lanes_type;
    variable ra_data34          : wordx_lanes_type;
    variable ra_csr_address     : csratype;
    variable ra_csr_read_xc     : std_ulogic;
    variable ra_csr_read_cause  : cause_type;
    variable ra_csr             : wordx;
    variable ra_csrv            : std_ulogic;
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

    -- Memory Stage
    variable me_stdata          : word64;
    variable me_dcache_xc       : std_ulogic;
    variable me_dcache_cause    : cause_type;
    variable me_dcache_tval     : wordx;
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
    variable me_int             : std_ulogic;
    variable me_h_en            : boolean;
    variable me_irqand          : wordx;        -- qqq XXX Remove again!
    variable me_irqand_m        : wordx;
    variable me_irqand_s        : wordx;
    variable me_irqand_v        : wordx;
    variable me_irqprio         : std_logic_vector(cause_prio'reverse_range);
    variable me_irqprio_m       : std_logic_vector(cause_prio'reverse_range);
    variable me_irqprio_s       : std_logic_vector(cause_prio'reverse_range);
    variable me_irqprio_v       : std_logic_vector(cause_prio'reverse_range);
    variable me_irqcause        : cause_type;
    variable lz_cnt             : unsigned(4 downto 0);
    variable mem_branch         : std_ulogic;   -- Branch mispredict from early BU
    variable mem_branch_flush   : std_ulogic;
    variable mem_branch_target  : pctype;
    variable m_inst             : word_lanes_type;
    variable m_valid            : lanes_type;
    variable m_fusel            : fusel_lanes_type;

    -- Exception Stage
    variable x_wb_data          : wordx_lanes_type;
    variable x_wb_wcsr          : wordx_lanes_type;
    variable x_wcsr             : wordx;
    variable x_xc               : lanes_type;
    variable x_xc_cause         : cause_lanes_type;
    variable x_xc_tval          : wordx_lanes_type;
    variable x_xc_ret           : word2;
    variable x_trig_taken       : std_ulogic;
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
    variable x_xc_irq_taken     : std_logic_vector(1 downto 0);
    variable x_flush            : std_ulogic;
    variable x_fpu_flush        : std_ulogic;
    variable x_csr_pipeflush    : std_ulogic;
    variable x_csr_addrflush    : std_ulogic;
    variable x_alu_op1          : wordx_lanes_type;
    variable x_alu_op2          : wordx_lanes_type;
    variable x_csr_op1          : wordx;
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
    variable x_csr_dcsr         : csr_dcsr_type;
    variable x_csr_prv          : priv_lvl_type;
    variable x_csr_v            : std_ulogic;
    variable x_csr_write_xc     : lanes_type;
    variable x_csr_write_cause  : cause_type;
    variable dci_specreadannulv : std_ulogic;

    -- Write Back Stage

    variable wb_csr_wlane       : lanes_type;
    variable wb_csr_wen         : std_ulogic;
    variable wb_csr_csra        : csratype;
    variable wb_csr_wdata       : wordx;
    variable wb_csr             : csr_reg_type;
    variable wb_csr_trig        : csr_reg_type;
    variable wb_upd_mcycle      : std_ulogic;
    variable wb_upd_minstret    : std_ulogic;
    variable wb_upd_counter     : std_logic_vector(r.csr.hpmcounter'range);
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
    variable vrasi              : nv_ras_in_type;
    variable veto               : nv_etrace_out_type;

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
    variable envcfg, henvcfg    : csr_envcfg_type;

    variable icache_en          : std_ulogic;

    variable r_f_pc_21          : word2;  -- Locally static for case statement

    variable iu_fflags          : std_logic_vector(r.csr.fflags'range);


    variable fpu_holdn          : std_ulogic;

    variable m_addr             : pctype;

    variable itrace_in : itrace_in_type;


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
    sstc_stip := to_bit(s_time >= r.csr.stimecmp);
    sstc_vstip := to_bit(s_vtime >= r.csr.vstimecmp);

    -- Current envcfg
    envcfg  := gen_envcfg_mmask(active_extensions);
    henvcfg := envcfg_mask(r.csr.henvcfg, r.csr.menvcfg);
    if r.csr.v = '1' then
      if r.csr.prv = PRIV_LVL_S then
        envcfg := henvcfg;
      elsif r.csr.prv = PRIV_LVL_U then
        envcfg := envcfg_mask(r.csr.senvcfg, henvcfg);
      end if;
    else
      if r.csr.prv = PRIV_LVL_S then
        envcfg := r.csr.menvcfg;
      elsif r.csr.prv = PRIV_LVL_U then
        envcfg := envcfg_mask(r.csr.senvcfg, r.csr.menvcfg);
      end if;
    end if;


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

    -- CSR intructions that can cause flush,
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

    -- To Branch History Table --------------------------------------------
    bhti.wdata  <= wb_bhti.wdata;

    -- Branch Target Buffer Update Logic ----------------------------------
    btb_update(r.wb.ctrl(branch_lane),          -- in  : Ctrl
               r.wb.unalg_pc,
               r.csr.dfeaturesen,               -- in  : CSR Feature Enable
               wb_btbflush,                     -- in  : Fence.i Flush Signal
               wb_btbi                          -- out : BTBI
               );

    -- To Branch Target Buffer --------------------------------------------
    btbi.waddr  <= wb_btbi.waddr;
    btbi.wen    <= wb_btbi.wen and holdn and not(r.csr.dfeaturesen.btb_dis) and icache_en;
    btbi.wdata  <= wb_btbi.wdata;



    -- To Register File ---------------------------------------------------
    for i in lanes'range loop
      rfi_waddr12(i)      := rd(r, wb, i);
      rfi_wdata12(i)      := r.wb.wdata(i);
      rfi_wen12(i)        := r.wb.ctrl(i).rdv and r.wb.ctrl(i).valid and holdn;
    end loop;

    -- Only allow one write (latest) to a specific destination register!
    if single_issue = 0 and
       all_1(rfi_wen12) and (rfi_waddr12(0) = rfi_waddr12(1)) then
      if r.wb.swap = '0' then
        rfi_wen12(0)      := '0';
      else
        rfi_wen12(1)      := '0';
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
    for i in lanes'range loop
      if is_x(x_alu_op1(i)) then
        x_alu_op1(i) := (others => '0');
      end if;
      if is_x(x_alu_op2(i)) then
        x_alu_op2(i) := (others => '0');
      end if;
    end loop;
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
    x_csr_op1               := x_alu_op1(csr_lane);
    if csr_immediate(r, x) then
      x_csr_op1             := (others => '0');
      x_csr_op1(4 downto 0) := r.x.ctrl(csr_lane).inst(19 downto 15);
    end if;
    x_wcsr := csralu_op(x_csr_op1,        -- in  : Op1
                        r.x.csr.v,        -- in  : Op2
                        r.x.csr.ctrl      -- in  : Control Signal
                        );
    -- Only for trace
    x_wb_wcsr               := (others => zerox);
    x_wb_wcsr(memory_lane)  := r.x.wcsr;           -- At this point, this is load/store address.

    -- Write Back Data ----------------------------------------------------
    for i in lanes'range loop
      wbdata_gen(i,                             -- in  : Lane
                 r.x.ctrl(i).fusel,             -- in  : Functional Units
                 x_alu_valid(i),                -- in  : Late ALUs Valid Flag
                 r.x.alu(i).lalu,               -- in  : Late ALUs Enable Flag
                 r.x.result(i),                 -- in  : Result from ALUs
                 r.x.ctrl(i).csrv,              -- in  : CSR Valid Instruction
                 r.x.csr.v,                     -- in  : Result from CSR read
                 x_alu_res(i),                  -- in  : Result from late ALUs
                 r.x.data(0),                   -- in  : Data from LD/ST
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
      x_alu_res(csr_lane) := r.x.csr.v;
      x_wb_wcsr(csr_lane) := x_wcsr;  -- Replace by CSR write data for trace

      -- The specification says that any actual read from MIP/SIP (not the rmw) must
      -- OR the incoming SEIP from the interrupt controller with MIP/SIP value.
      if (r.x.ctrl(csr_lane).inst(31 downto 20) = CSR_MIP and
          r.csr.mideleg(cause2int(IRQ_S_EXTERNAL)) = '0') or
         (r.x.ctrl(csr_lane).inst(31 downto 20) = CSR_SIP and
          r.csr.mideleg(cause2int(IRQ_S_EXTERNAL)) /= '0') then
        x_wb_data(csr_lane)(cause2int(IRQ_S_EXTERNAL)) :=
          x_wb_data(csr_lane)(cause2int(IRQ_S_EXTERNAL)) or x_irq.seip;
      end if;
    end if;

    -- Late Branch Unit ---------------------------------------------------
    if late_branch = 1 then
      branch_unit(active_extensions,
                  x_alu_op1(branch_lane),                 -- in  : Forwarded Op1
                  x_alu_op2(branch_lane),                 -- in  : Forwarded Op2
                  r.x.ctrl(branch_lane).valid,            -- in  : Instruction Valid Flag
                  r.x.ctrl(branch_lane).branch.valid,     -- in  : Branch Valid Flag
                  r.x.ctrl(branch_lane).inst(14 downto 12),
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
      x_branch_cause      := (others => '0');
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

    -- CSR Write Logic ----------------------------------------------------
    wb_csr_wlane      := (others => '0');
    if csr_ok(r, x) then
      wb_csr_wlane(csr_lane) := r.x.csrw(csr_lane) and not (x_flush or r.x.trig.nullify(csr_lane));
    end if;
    wb_csr_wen        := wb_csr_wlane(csr_lane);
    wb_csr_csra       := csr_addr(r, x);
    wb_csr_wdata      := x_wcsr;

    if dmen = 1 then
      if (r.dm.cmdexec(1) and r.dm.write and r.dm.cmd(0)) = '1' and r.x.rstate = dhalt then
        if r.dm.addr(15 downto 12) = "0000" then
          wb_csr_wen                             := '1';
        end if;
        wb_csr_csra                              := r.dm.addr(csratype'range);
        wb_csr_wdata(word'range)                 := dbgi.ddata(word'range);
        if is_rv64 and r.dm.size = "011" then
          wb_csr_wdata(XLEN - 1 downto XLEN / 2) := dbgi.ddata(XLEN - 1 downto XLEN / 2);
        end if;
      end if;
    end if;

    -- To CSR Regfile -----------------------------------------------------
    csr_write(wb_csr_csra,                      -- in  : CSR Address
              r.x.rstate,                       -- in  : Core State
              r.csr,                            -- in  : CSR File
              wb_csr_wdata,                     -- in  : Write Data
              wb_csr_wen,                       -- in  : Valid/Write Enable
              wb_csr_wlane,                     -- in  : Valid Write Lane
              r.x.ctrl(csr_lane).pc,            -- in  : PC of CSR Instruction
              r.x.csraxc,                       -- in  : Precalculated CSR write exception
              envcfg,                           -- in  : Envcfg base on privilege level
              x_csr_pipeflush,                  -- out : Flush Instructions
              x_csr_addrflush,                  -- out : Flush Instructions
              x_csr_write_xc,                   -- out : CSR Exception Flag
              x_csr_write_cause,                -- out : CSR Exception Cuase
              wb_upd_mcycle,                    -- out : CSR mcycle updated
              wb_upd_minstret,                  -- out : CSR minstret updated
              wb_upd_counter,                   -- out : CSR counter updated
              wb_csr                            -- out : CSR Regfile
              );


    -- Exception Unit -----------------------------------------------------
    exception_unit(x_branch_xc,                 -- in  : Late Branch Exception
                   x_branch_cause,              -- in  : Late Branch Cause
                   x_branch_tval,               -- in  : Late Branch Value
                   x_csr_write_xc,              -- in  : CSR Write Exception
                   x_csr_write_cause,           -- in  : CSR Write Cause
                   r,                           -- in  : Registers
                   x_flush,                     -- in  : Flush from fence
                   r.x.swap,                    -- in  : Swapped Instructions
                   r.csr,                       -- in  : CSR Regfile
                   r.x.int,                     -- in  : Interrupt pending on instruction
                   x_xc,                        -- out : Exceptions
                   x_xc_cause,                  -- out : Exceptions Cause
                   x_xc_tval,                   -- out : Exceptions Value
                   x_xc_ret,                    -- out : Return Level
                   x_xc_taken,                  -- out : Exception Taken
                   x_xc_lane_out,               -- out : Exception lane
                   x_xc_irq_taken,              -- out : IRQ taken lane
                   x_xc_taken_cause,            -- out : Exception Taken Cause
                   x_xc_taken_tval,             -- out : Exception Taken Value
                   x_xc_taken_tval2,            -- out : Exception Taken Value 2
                   x_xc_taken_gva,              -- out : Exception Taken GVA
                   x_xc_flush,                  -- out : Flush Instructions
                   x_xc_pc,                     -- out : Exception PC
                   x_xc_inst,                   -- out : Exception mtinst/htinst
                   x_trig_taken                 -- out : Trigger action taken
                   );



    -- Register Interrupts
    if not all_0(r.evtirq) then
      wb_csr.mip(cause2int(IRQ_LCOF))     := '1';
    end if;
    wb_csr.mip(cause2int(IRQ_M_EXTERNAL)) := x_irq.meip;
    wb_csr.mip(cause2int(IRQ_M_TIMER))    := x_irq.mtip;
    wb_csr.mip(cause2int(IRQ_M_SOFTWARE)) := x_irq.msip;

    -- Sstc extension support
    if ext_sstc = 1 and r.csr.menvcfg.stce = '1' then
      wb_csr.mip(cause2int(IRQ_S_TIMER))     := sstc_stip;
    end if;
    if ext_h /= 0 then
      wb_csr.mip(cause2int(IRQ_SG_EXTERNAL)) := to_bit(not all_0(r.csr.hgeip and r.csr.hgeie));
      wb_csr.mip(cause2int(IRQ_VS_EXTERNAL)) := wb_csr.hvip(cause2int(IRQ_VS_EXTERNAL)) or
                                                r.csr.hgeip(u2i(r.csr.hstatus.vgein))
                      ;
      wb_csr.mip(cause2int(IRQ_VS_TIMER))    := wb_csr.hvip(cause2int(IRQ_VS_TIMER))
                      -- Sstc extension support
                      or (to_bit(ext_sstc = 1) and 
                          r.csr.menvcfg.stce and r.csr.henvcfg.stce and 
                          sstc_vstip);
      -- When hypervisor extension is enabled, VS-level interrupt is always
      -- delegated to HS-mode
      if r.csr.misa(h_ctrl) = '1' then
        wb_csr.mideleg(cause2int(IRQ_SG_EXTERNAL)) := '1';
        wb_csr.mideleg(cause2int(IRQ_VS_EXTERNAL)) := '1';
        wb_csr.mideleg(cause2int(IRQ_VS_TIMER))    := '1';
        wb_csr.mideleg(cause2int(IRQ_VS_SOFTWARE)) := '1';
      end if;
    end if;

    -- To Write Back Stage ------------------------------------------------
    v.wb.trap_taken(0)     := '1';
    if single_issue = 0 then
      v.wb.trap_taken(1)   := '0';
      if x_xc_lane_out = '1' then
        v.wb.trap_taken(0) := '0';
        v.wb.trap_taken(1) := '1';
      end if;
    end if;

    for i in lanes'range loop
      v.wb.ctrl(i).pc      := r.x.ctrl(i).pc;
      v.wb.ctrl(i).inst    := r.x.ctrl(i).inst;
      v.wb.ctrl(i).cinst   := r.x.ctrl(i).cinst;
      v.wb.ctrl(i).valid   := r.x.ctrl(i).valid and not (x_xc_flush(i) or x_flush);
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


    v.wb.flushall       := x_xc_taken or wb_pipeflush;
    v.wb.csr_pipeflush  := x_csr_pipeflush;
    v.wb.csr_addrflush  := x_csr_addrflush;
    v.wb.swap           := r.x.swap;
    v.wb.rstate         := r.x.rstate;
    v.wb.xc_taken       := x_xc_taken;
    v.wb.xc_taken_cause := x_xc_taken_cause;
    v.wb.xc_taken_tval  := x_xc_taken_tval;
    v.wb.nextpc0        := x_nextpc;
    v.wb.rasi           := r.x.rasi;
    v.wb.prv            := r.csr.prv;
    v.wb.v              := r.csr.v;
    v.wb.fence_flush    := fence_flush_check(r);
    v.wb.ret            := orv(x_xc_ret);

    -- Exception Registers Update -----------------------------------------
    exception_flow(x_xc_pc,                     -- in  : Exception PC
                   x_xc_taken,                  -- in  : Exception
                   x_xc_taken_cause,            -- in  : Exception Cause
                   x_xc_taken_tval,             -- in  : Exception Trap Value I
                   x_xc_taken_tval2,            -- in  : Exception Trap Value 2
                   x_xc_inst,                   -- in  : Exception instruction
                   x_xc_taken_gva,              -- in  : Exception GVA Value
                   x_xc_ret,                    -- in  : Return Level
                   wb_csr,                      -- in  : CSR Regfile
                   r.csr,                       -- in  : Registered CSR Regfile
                   r.x.rstate,                  -- in  : Core State
                   wb_csr_trig,                 -- out : CSR Regfile
                   x_xc_tvec                    -- out : Trap Vector Base
                   );

    trigger_update(
      csr_in    => wb_csr_trig,
      v_wb_ctrl => v.wb.ctrl,
      trig_in   => r.x.trig,
      csr_out   => v.csr);


    -- Debug Module -------------------------------------------------------
    x_dret    := '0';
    x_csr_dpc := v.csr.dpc;
    x_csr_dcsr:= v.csr.dcsr;
    x_csr_prv := v.csr.prv;
    x_csr_v   := v.csr.v;

    debug_module(r,                     -- in  : Registers
                 x_csr_dpc,             -- in  : DPC CSR Register
                 x_csr_dcsr,            -- in  : DCSR CSR Register
                 x_csr_prv,             -- in  : Privilege mode
                 x_csr_v,               -- in  : Virtualization mode
                 dmen,                  -- in  : Debug Module Enable
                 dbgi,                  -- in  : Debug Module
                 r.dm,                  -- in  : Debug Module register
                 x_xc,                  -- in  : Exceptions
                 x_xc_taken,            -- in  : Exception Taken
                 x_xc_taken_cause,      -- in  : Exception Cause
                 x_dret,                -- in  : dret Instruction
                 r.x.trig,              -- in  : Trigger trap on instruction
                 rfo.data1,             -- in  : Register File Read Port 1
                 r.e.csr.v,             -- in  : CSR File Read Register
                 tbo.data,              -- in  : Trace buffer readout data
                 itraceo.tcnt,          -- in  : Trace buffer current index
                 dbg_running,           -- out : Running Signal
                 dbg_halted,            -- out : Halted Signal
                 dbg_pc,                -- out : PC from DM request
                 dbg_request,           -- out : DM request to PC
                 v.x.rstate,            -- out : Next DM State
                 v.csr.prv,             -- out : Privilege mode out
                 v.csr.v,               -- out : Virtualization mode
                 v.csr.dpc,             -- out : DPC CSR Register
                 v.csr.dcsr,            -- out : DCSR CSR Register
                 v.dm,                  -- out : Debug Module register
                 dbg_flushall,          -- out : DM Flushall Signal
                 dbg_dvalid,            -- out : DM Valid Signal
                 dbg_ddata,             -- out : DM Data Signal
                 dbg_derr,              -- out : DM Error Signal
                 dbg_dexec_done,        -- out : DM Program buffer exec done
                 dbg_error,             -- out : Error signal
                 dbg_haltreq,           -- out : Halt request from DM
                 dbg_stoptime           -- out : stop mtime
                 );

    if dbg_flushall = '1' then
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
    -- This is x_flush or x_xc_taken or dbg_flushall.
    if (v.wb.flushall or wb_branch) = '1' then
--      report "me_flush";
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
                  me_dcache_xc,         -- in  : Data Cache Exception
                  me_dcache_cause,      -- in  : Data Cache Cause
                  me_dcache_tval,       -- in  : Data Cache Value
                  me_ret,               -- out : Return Privileged Level
                  me_xc,                -- out : Memory Stage Exception
                  me_xc_cause,          -- out : Memory Stage Cause
                  me_xc_tval            -- out : Memory Stage Value
                  );

    -- Generate Nullify for Data Cache ------------------------------------
    null_dcache_gen(me_flush,           -- in  : Flush all from Exception Stage
                    me_xc,              -- in  : Instruction Exceptions
                    mem_branch_flush,   -- in  : branch missp from memory stage
                    r.m.ctrl(0).inst,
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

    -- Highest priority at lowest index
    me_irqprio_m       := (others => '0');
    me_irqand_m        := r.csr.mip and r.csr.mie;
    -- Supervisor external interrupt needs to be OR:ed in separately.
    me_irqand_m(cause2int(IRQ_S_EXTERNAL)) := me_irqand_m(cause2int(IRQ_S_EXTERNAL)) or
                                              (x_irq.seip and r.csr.mie(cause2int(IRQ_S_EXTERNAL)));
    me_irqand_m        := me_irqand_m and not r.csr.mideleg;
    me_irqprio_m(0)    := me_irqand_m(cause2int(IRQ_M_EXTERNAL));
    me_irqprio_m(1)    := me_irqand_m(cause2int(IRQ_M_SOFTWARE));
    me_irqprio_m(2)    := me_irqand_m(cause2int(IRQ_M_TIMER));
    me_irqprio_m(3)    := me_irqand_m(cause2int(IRQ_S_EXTERNAL));
    me_irqprio_m(4)    := me_irqand_m(cause2int(IRQ_S_SOFTWARE));
    me_irqprio_m(5)    := me_irqand_m(cause2int(IRQ_S_TIMER));
    -- The specification requires that SGE/VSE/VSS/VST are
    -- always delegated past M to HS.
    if ext_sscofpmf /= 0 then
      me_irqprio_m(10) := me_irqand_m(cause2int(IRQ_LCOF));
    end if;

    me_irqprio_s       := (others => '0');
    me_irqand_s        := r.csr.mip and r.csr.mie;
    -- Supervisor external interrupt needs to be OR:ed in separately.
    me_irqand_s(cause2int(IRQ_S_EXTERNAL)) := me_irqand_s(cause2int(IRQ_S_EXTERNAL)) or
                                              (x_irq.seip and r.csr.mie(cause2int(IRQ_S_EXTERNAL)));
    me_irqand_s        := me_irqand_s and r.csr.mideleg and not r.csr.hideleg;
--    me_irqprio_s(0)    := me_irqand_s(cause2int(IRQ_M_EXTERNAL));
--    me_irqprio_s(1)    := me_irqand_s(cause2int(IRQ_M_SOFTWARE));
--    me_irqprio_s(2)    := me_irqand_s(cause2int(IRQ_M_TIMER));
    me_irqprio_s(3)    := me_irqand_s(cause2int(IRQ_S_EXTERNAL));
    me_irqprio_s(4)    := me_irqand_s(cause2int(IRQ_S_SOFTWARE));
    me_irqprio_s(5)    := me_irqand_s(cause2int(IRQ_S_TIMER));
    if ext_h /= 0 then
      me_irqprio_s(6)  := me_irqand_s(cause2int(IRQ_SG_EXTERNAL));
      me_irqprio_s(7)  := me_irqand_s(cause2int(IRQ_VS_EXTERNAL));
      me_irqprio_s(8)  := me_irqand_s(cause2int(IRQ_VS_SOFTWARE));
      me_irqprio_s(9)  := me_irqand_s(cause2int(IRQ_VS_TIMER));
    end if;
    if ext_sscofpmf /= 0 then
      me_irqprio_s(10) := me_irqand_s(cause2int(IRQ_LCOF));
    end if;
    me_irqprio_v       := (others => '0');
    me_irqand_v        := r.csr.mip and r.csr.mie;
    me_irqand_v        := me_irqand_v and r.csr.mideleg and r.csr.hideleg;
--    me_irqprio_v(0)    := me_irqand_v(cause2int(IRQ_M_EXTERNAL));
--    me_irqprio_v(1)    := me_irqand_v(cause2int(IRQ_M_SOFTWARE));
--    me_irqprio_v(2)    := me_irqand_v(cause2int(IRQ_M_TIMER));
--    me_irqprio_v(3)    := me_irqand_v(cause2int(IRQ_S_EXTERNAL));
--    me_irqprio_v(4)    := me_irqand_v(cause2int(IRQ_S_SOFTWARE));
--    me_irqprio_v(5)    := me_irqand_v(cause2int(IRQ_S_TIMER));
    me_irqprio_v(6)    := me_irqand_v(cause2int(IRQ_SG_EXTERNAL));
    me_irqprio_v(7)    := me_irqand_v(cause2int(IRQ_VS_EXTERNAL));
    me_irqprio_v(8)    := me_irqand_v(cause2int(IRQ_VS_SOFTWARE));
    me_irqprio_v(9)    := me_irqand_v(cause2int(IRQ_VS_TIMER));
    if ext_sscofpmf /= 0 then
      me_irqprio_v(10) := me_irqand_v(cause2int(IRQ_LCOF));
    end if;

    me_irqprio := (others => '0');
    if all_0(me_irqand_m or me_irqand_s or me_irqand_v) then
      -- No enabled interrupt present.
    elsif r.csr.dcsr.step = '1' and r.csr.dcsr.stepie /= '1' then
      -- Stepping, but not into interrupts.
    elsif r.csr.prv = PRIV_LVL_M and r.csr.mstatus.mie /= '1' then
      -- M mode without interrupts enabled.
      -- Note that M mode interrupts are always enabled in non-M modes.
    elsif not all_0(me_irqand_m) then
      -- Some active M IRQ pending
      me_int       := '1';
      me_irqprio   := me_irqprio_m;
    elsif r.csr.prv = PRIV_LVL_M then
      -- M mode with no active M IRQ pending.
    elsif r.csr.prv = PRIV_LVL_U or r.csr.v = '1' or r.csr.mstatus.sie = '1' then
      -- U/VU mode, VS mode, or S mode with interrupts enabled.
      -- Note that S mode interrupts are always enabled in U mode, and HS in VS/VU.
      if not all_0(me_irqand_s) then
        -- No hypervisor, or IRQ not delegated to VS mode, so handle in (H)S mode.
        me_int     := '1';
        me_irqprio := me_irqprio_s;
      elsif r.csr.v = '0' then
        -- Not in VS mode to deal with IRQ.
      elsif r.csr.prv = PRIV_LVL_U or r.csr.vsstatus.sie = '1' then
        -- U mode, or VS mode with interrupts enabled.
        -- Note that VS mode interrupts are always enabled in U mode.
        me_int     := '1';
        me_irqprio := me_irqprio_v;
      end if;
    end if;

    me_irqcause   := (others => '0');
    if me_int = '1' then
      -- It is assumed here that the priority list is 16 elements long.
      -- Formality complains if the indexing can go outside the array.
      assert me_irqprio'length = 16 severity failure;
      lz_cnt := clz(reverse(me_irqprio));
      me_irqcause := cause_prio(u2i(lz_cnt(3 downto 0)));
    end if;

    -- This code only deals with IRQ in fixed modes, except for LCOF.
    -- qqq XXX This code should be removed. The above is better (but possibly incorrect ;-)
    if r.csr.dfeaturesen.new_irq = '0' then
      me_int        := '0';
      me_irqand     := r.csr.mip and r.csr.mie;
      -- Supervisor external interrupt needs to be OR:ed in separately.
      me_irqand(cause2int(IRQ_S_EXTERNAL)) := me_irqand(cause2int(IRQ_S_EXTERNAL)) or
                                              (x_irq.seip and r.csr.mie(cause2int(IRQ_S_EXTERNAL)));
--      report "MIP&MIE " & tost_bits(me_irqand(15 downto 0));
      me_irqcause   := (others => '0');
      if      me_irqand(cause2int(IRQ_M_EXTERNAL)) = '1' then
        me_irqcause := IRQ_M_EXTERNAL;
      elsif   me_irqand(cause2int(IRQ_M_SOFTWARE)) = '1' then
        me_irqcause := IRQ_M_SOFTWARE;
      elsif   me_irqand(cause2int(IRQ_M_TIMER)) = '1' then
        me_irqcause := IRQ_M_TIMER;
      elsif ext_sscofpmf /= 0 and r.csr.mideleg(cause2int(IRQ_LCOF)) = '0' and
              me_irqand(cause2int(IRQ_LCOF)) = '1' then
        me_irqcause := IRQ_LCOF;
      elsif   me_irqand(cause2int(IRQ_S_EXTERNAL)) = '1' then
        me_irqcause := IRQ_S_EXTERNAL;
      elsif   me_irqand(cause2int(IRQ_S_SOFTWARE)) = '1' then
        me_irqcause := IRQ_S_SOFTWARE;
      elsif   me_irqand(cause2int(IRQ_S_TIMER)) = '1' then
        me_irqcause := IRQ_S_TIMER;
      elsif me_h_en then
        if ext_sscofpmf /= 0 and r.csr.mideleg(cause2int(IRQ_LCOF)) = '1' and r.csr.hideleg(cause2int(IRQ_LCOF)) = '0' and
              me_irqand(cause2int(IRQ_LCOF)) = '1' then
          me_irqcause := IRQ_LCOF;
        elsif me_irqand(cause2int(IRQ_SG_EXTERNAL)) = '1' then
          me_irqcause := IRQ_SG_EXTERNAL;
        elsif me_irqand(cause2int(IRQ_VS_EXTERNAL)) = '1' then
          me_irqcause := IRQ_VS_EXTERNAL;
        elsif me_irqand(cause2int(IRQ_VS_SOFTWARE)) = '1' then
          me_irqcause := IRQ_VS_SOFTWARE;
        elsif me_irqand(cause2int(IRQ_VS_TIMER)) = '1' then
          me_irqcause := IRQ_VS_TIMER;
        elsif ext_sscofpmf /= 0 and me_irqand(cause2int(IRQ_LCOF)) = '1' then
          me_irqcause := IRQ_LCOF;
        end if;
      elsif ext_sscofpmf /= 0 and r.csr.mideleg(cause2int(IRQ_LCOF)) = '1' and
              me_irqand(cause2int(IRQ_LCOF)) = '1' then
          me_irqcause := IRQ_LCOF;
      end if;

      if not all_0(me_irqand) and
         (r.csr.dcsr.stepie = '1' or r.csr.dcsr.step = '0') then
        -- Some enabled IRQ pending, no step (or into interrupts is allowed).
        if (r.csr.prv = PRIV_LVL_M and r.csr.mstatus.mie = '1') or
           r.csr.prv = PRIV_LVL_S or r.csr.prv = PRIV_LVL_U then
          -- In M with IRQ enabled, or in lower priority mode.
          if r.csr.mideleg(u2i(me_irqcause(3 downto 0))) = '1' then
            -- Cause of interrupt is delegated from M.
            if (r.csr.mstatus.sie = '1' and r.csr.prv = PRIV_LVL_S) or
               r.csr.v = '1' or r.csr.prv = PRIV_LVL_U then
              -- In S/HS with IRQ enabled, or in lower priority mode.
              if me_h_en and r.csr.hideleg(u2i(me_irqcause(3 downto 0))) = '1' then
                -- Cause of interrupt is delegated from HS.
                if r.csr.v = '1' and ((r.csr.vsstatus.sie = '1' and r.csr.prv = PRIV_LVL_S) or
                    r.csr.prv = PRIV_LVL_U) then
                  -- In VS with IRQ enabled, or in lower priority mode.
                  me_int := '1';
                end if;
              else
                -- S, or cause of interrupt was not delegated from HS.
                me_int := '1';
              end if;
            end if;
          else
            -- Cause of interrupt was not delegated from M.
            me_int   := '1';
          end if;
        end if;
      end if;
    end if;

    v.x.irqcause   := me_irqcause;

    -- To Exception Stage ------------------------------------------------
    for i in lanes'range loop
      v.x.ctrl(i).pc      := r.m.ctrl(i).pc;
      v.x.ctrl(i).inst    := r.m.ctrl(i).inst;
      v.x.ctrl(i).cinst   := r.m.ctrl(i).cinst;
      v.x.ctrl(i).valid   := r.m.ctrl(i).valid and not me_flush;
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
      v.x.trig.valid(i)   := r.m.trig.valid(i) and not me_flush;
      v.x.trig.nullify(i) := r.m.trig.nullify(i);
      -- Previous code guarantees that there is no CSR write to registers
      -- affecting IRQ either paired with or in the cycle just before
      -- another instruction.
      -- But we must still ensure that no interrupt is taken on a CSR write,
      -- since some things rely on the CSR write always completing.
      -- For example, interrupts could be turned off without the instruction
      -- seemingly executing, causing a rerun after xRET and dropping IRQ enable.
      v.x.int(i)          := r.m.ctrl(i).valid and (me_int and not me_csrw(i)) and not me_flush;
    end loop;
    v.x.ctrl(fpu_lane).fpu       := r.m.ctrl(fpu_lane).fpu;
    v.x.ctrl(fpu_lane).fpu_flush := r.m.ctrl(fpu_lane).fpu_flush;
    v.x.csr               := r.m.csr;
    v.x.swap              := r.m.swap;
    v.x.dci               := r.m.dci;
    v.x.address           := r.m.address;
    v.x.lbranch           := r.m.lbranch;
    v.x.alu               := r.m.alu;
    v.x.rasi              := r.m.rasi;
    v.x.spec_ld           := r.m.spec_ld;
    v.x.csrw              := me_csrw;
    v.x.ret               := me_ret;
    if not all_0(v.x.int) then      -- No xRET if IRQ.
      v.x.ret := (others => '0');
    end if;
    v.x.fpuflags          := r.m.fpuflags;
    v.x.trig.hit          := r.m.trig.hit;
    v.x.trig.action       := r.m.trig.action;
    v.x.trig.pending      := r.m.trig.pending and not x_trig_taken;

    -- From Data Cache ----------------------------------------------------
    if v_fusel_eq(r, m, memory_lane, LD) or not dco.mds = '1' then
      for i in 0 to dways-1 loop
        v.x.data(i) := dco.data(i);
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
      me_ld_data    := ld_align_fast(v.x.data,        -- in  : Data in from the cache
                                     v.x.way,         -- in  : Way signals from the cache
                                     me_size,         -- in  : Size for the load data
                                     me_laddr,        -- in  : Low bits for the address
                                     me_signed);      -- in  : Signed or unsigned load
      v.x.data(0)   := me_ld_data;
    else
      v.x.data(0)   := me_stdata;
    end if;
    v.x.mexc        := dco.mexc;
    v.x.exctype     := dco.exctype;
    v.x.exchyper    := dco.exchyper;
    v.x.tval2       := dco.addrhyper(XLEN-1 downto 0);
    v.x.tval2type   := dco.typehyper;

    --BTB FLUSH---
    mode_flush := '0';
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


    btbi.flush  <= (wb_btbi.flush or mode_flush or r.csr.dfeaturesen.btb_dis or not(icache_en) ) and holdn;

    -- To Data Cache ------------------------------------------------------
    if dci.maddress'length < r.m.address'length then
      dci.maddress                    <= r.m.address(dci.maddress'range);
    else
      dci.maddress                    <= (others => '0');
      dci.maddress(r.m.address'range) <= r.m.address;
    end if;
    dci.enaddr          <= r.m.dci.enaddr;
    dci.size            <= r.m.dci.size;
    dci.nullify         <= me_nullify or r.m.trig.nullify(memory_lane) or me_int;
    dci.lock            <= r.m.dci.lock;
    dci.asi             <= r.m.dci.asi;
    dci.read            <= r.m.dci.read;
    dci.write           <= r.m.dci.write;
    dci.flush           <= wb_fence_i;
    dci.dsuen           <= r.m.dci.dsuen;
    dci.msu             <= v.csr.prv(0) or v.csr.prv(1);    -- prv for dcache
    dci.esu             <= '0';
    dci.intack          <= '0';
    dci.mmucacheclr     <= '0';
    dci.edata           <= me_stdata;
    dci.specread        <= v.x.spec_ld;
    dci.specreadannul   <= dci_specreadannulv;
    dci.iudiag_miso.accrdy <= '1';
    dci.iudiag_miso.rddata <= (others => '0');

    -----------------------------------------------------------------------
    -- EXECUTE STAGE
    -----------------------------------------------------------------------

    -- Execute Flush ------------------------------------------------------
    ex_flush   := '0';
    if (me_flush or mem_branch) = '1' then   -- Or branch mispredict from EX?
--      report "ex_flush " & tost_bits(me_flush & mem_branch);
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
                        i,                 -- in  : Lane 0
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
                r.e.ctrl(branch_lane).inst(14 downto 12), -- in  : Inst funct3
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
    jump_unit(r.e.ctrl(branch_lane),       -- in  : Ctrl
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
             ex_dci_eaddress,              -- out : Data Address
             ex_address_xc,                -- out : Misalignment Exception
             ex_address_cause,             -- out : Exception Cause
             ex_address_tval               -- out : Exception Value
             );

    -- Check for misaligned FPU load/store
    ex_fpu_flush := '0';
    if is_fpu_mem(r.e.ctrl(memory_lane).inst) and ex_address_xc = '1' then
--      report "ex_fpu_flush " & tost(ex_address_xc);
      ex_fpu_flush := '1';
    end if;

    fpu_holdn := fpuo.holdn;
    -- The IU is responsible for holding when it is
    -- waiting for integer results from the FPU.
    -- Are we waiting on results?
    if r.e.fpu_wait = '1' then
      -- FPU operation in EX flushed (normal reasons)?
      if ex_flush = '1' then
--        report "Release EX hold due to ex_flush";
      -- FPU operation in EX flushed (misaligned FPU load/store)?
      elsif ex_fpu_flush = '1' then
--        report "Release EX hold due to ex_fpu_flush";
      -- This is really me_fpu_flush "moved up" here, for now.
      -- FPU operation in EX flushed (paired with swapped early mispredict)?
      elsif (ex_branch_valid and ex_branch_mis) = '1'   and
            ex_branch_flush = '0' and r.e.lbranch = '0' and
            r.e.swap = '1' and fpu_lane = 0 then
--        report "Release EX hold due to me_fpu_flush";
      -- FPU operation finished?
      elsif fpuo.now2int = '1' and fpuo.id2int = r.e.ctrl(FPU_LANE).fpu then
--        report "Release EX hold due to finished FPU->int";
      else
        -- Keep holding
        if fpu_holdn = '1' then
--          report "Hold EX due to in-progress FPU->int";
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
        ex_xc_cause(memory_lane) := ex_address_cause;
        ex_xc_tval(memory_lane)  := ex_address_tval;
      end if;
    end if;
    if r.e.ctrl(branch_lane).xc = '0' then
      if ex_branch_xc = '1' then
        ex_xc(branch_lane)       := '1';
        ex_xc_cause(branch_lane) := ex_branch_cause;
        ex_xc_tval(branch_lane)  := ex_branch_tval;
      elsif ex_jump_xc = '1' then
        ex_xc(branch_lane)       := '1';
        ex_xc_cause(branch_lane) := ex_jump_cause;
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
      ex_result(fpu_lane)        := fpuo.data2int(wordx'range);
      ex_result_fwd(fpu_lane)    := '1';
      -- Ensure that FPU flags in IU pipeline are only set for FPU->IU operations.
      if not is_fpu_rd(r.e.ctrl(fpu_lane).inst) then
        v.m.fpuflags             := fpuo.flags2int;
      end if;
    end if;

    -- To Memory Stage ----------------------------------------------------
    for i in lanes'range loop
      v.m.ctrl(i).pc      := r.e.ctrl(i).pc;
      v.m.ctrl(i).inst    := r.e.ctrl(i).inst;
      v.m.ctrl(i).cinst   := r.e.ctrl(i).cinst;
      v.m.ctrl(i).valid   := r.e.ctrl(i).valid and not ex_flush;
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
    end loop;
    v.m.ctrl(fpu_lane).fpu := r.e.ctrl(fpu_lane).fpu;
    v.m.ctrl(fpu_lane).fpu_flush := '0';
    v.m.csr               := r.e.csr;
    v.m.swap              := r.e.swap;
    v.m.stdata            := ex_stdata;
    v.m.stforw            := r.e.stforw;
    v.m.lbranch           := r.e.lbranch;
    v.m.fpdata            := fpuo.data2int;
    v.m.rasi              := r.e.rasi;
    v.m.spec_ld           := r.e.spec_ld;

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

    -- Store Data ---------------------------------------------------------
    dcache_gen(r.e.ctrl(memory_lane).inst,   -- in  : Instruction
               r.e.ctrl(memory_lane).fusel,  -- in  : Functional Unit
               v.m.ctrl(memory_lane).valid,  -- in  : Valid Instruction
               ex_address_xc,                -- in  : Address misaligned?
               r.csr.dfeaturesen,            -- in  : ASI information
               r.csr.prv,                    -- in  : Privilege level
               r.csr.v,                      -- in  : Virtualization mode
               r.csr.mstatus.mprv,           -- in  :
               r.csr.mstatus.mpv,            -- in  :
               r.csr.mstatus.mpp,            -- in  :
               r.csr.mstatus.mxr,            -- in  :
               r.csr.mstatus.sum,            -- in  :
               r.csr.hstatus.spvp,           -- in  :
               r.csr.vsstatus.mxr,           -- in  :
               r.csr.vsstatus.sum,           -- in  :
               ex_dci                        -- out : Data Cache Signals
               );


    -- Invalid Second Instruction -----------------------------------------
    if v.m.ctrl(branch_lane).branch.mpred = '1' and r.e.swap = '1' then
      v.m.ctrl(0).valid := '0';
      if fpu_lane = 0 then
--        report "me_fpu_flush";
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

    -- To the Data Cache --------------------------------------------------
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
    if dci.eaddress'length < v.m.address'length then
      dci.eaddress                    <= v.m.address(dci.eaddress'range);
    else
      dci.eaddress                    <= (others => '0');
      dci.eaddress(v.m.address'range) <= v.m.address;
    end if;

    -- Debug Module -------------------------------------------------------
    trigger_module (
      trig_in   => r.m.trig,
      tcsr      => r.csr.tcsr,
      prv       => r.csr.prv,
      flush     => ex_flush or ex_hold_pc,
      step      => r.csr.dcsr.step,
      haltreq   => dbg_haltreq,
      x_rstate  => r.x.rstate,
      clr_pen   => x_trig_taken or dbg_flushall,
      x_ctrl    => r.x.ctrl,
      m_swap    => r.m.swap,
      m_ctrl    => r.m.ctrl,
      e_swap    => r.e.swap,
      e_ctrl    => r.e.ctrl,
      avalid    => v.m.dci.enaddr,
      addr      => v.m.address,
      size      => v.m.dci.size,
      awrite    => v.m.dci.write,
      rvalid    => r.x.dci.read,
      rdata     => r.x.data(0),
      wvalid    => r.m.dci.write,
      wdata     => me_stdata,
      m_trig    => v.m.trig);

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
    if csr_ok(r, a) and not csr_write_only(r, a) then
      ra_csrv      := '1';
    end if;
    ra_csr_address := csr_addr(r, a);

    if dmen = 1 then
      if (r.dm.cmdexec(1) and not r.dm.write and r.dm.cmd(0)) = '1' and
         r.x.rstate = dhalt then
        ra_csr_address := r.dm.addr(11 downto 0);
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

    csr_read(
--             active_extensions, TRIGGER, perf_cnts, counter_ok, hart,
--             fpuconf, pmp_entries, pmp_g, pmp_msb,
             envcfg,                    -- in  : Envcfg base on privilege level
             r.csr,                     -- in  : CSR File
             ra_csr_address,            -- in  : CSR Register Address
             ra_csrv,                   -- in  : Valid/Read enable
             r.x.rstate,                -- in  : Core State
             iu_fflags,                 -- in  : FPU flags in IU transit
             mmu_csr,                   -- in  : Status form Cache controller
             s_time,                    -- in  : Shadow MTIME for S-mode
             s_vtime,                   -- in  : Shadow MTIME for vitalized mode 
             ra_csr,                    -- out : CSR Register Value
             ra_csr_read_xc,            -- out : Read Exception
             ra_csr_read_cause          -- out : Read Cause
             );

    -- Insert Exception ---------------------------------------------------
    for i in lanes'range loop
      ra_xc(i)               := r.a.ctrl(i).xc;
      ra_xc_cause(i)         := r.a.ctrl(i).cause;
      ra_xc_tval(i)          := r.a.ctrl(i).tval;
    end loop;
    if r.a.ctrl(csr_lane).xc = '0' and ra_csr_read_xc = '1' then
      ra_xc(csr_lane)        := '1';
      ra_xc_cause(csr_lane)  := ra_csr_read_cause;
      ra_xc_tval(csr_lane)   := to0x(r.a.ctrl(csr_lane).inst);
      if illegalTval0 = 1 then
        ra_xc_tval(csr_lane) := zerox;
      end if;
    end if;

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
                        0,                      -- in  : Lane
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

    -- To Execute Stage ---------------------------------------------------
    for i in lanes'range loop
      v.e.ctrl(i).pc      := r.a.ctrl(i).pc;
      v.e.ctrl(i).inst    := r.a.ctrl(i).inst;
      v.e.ctrl(i).cinst   := r.a.ctrl(i).cinst;
      v.e.ctrl(i).valid   := r.a.ctrl(i).valid and not ra_flush;
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
         not (fpuo.now2int = '1' and fpuo.id2int = r.e.ctrl(FPU_LANE).fpu) then
        v.e.fpu_wait := '1';
      else
        v.e.fpu_wait := '0';
        if is_valid_fpu(v, e) and not is_fpu_rd(v.e.ctrl(FPU_LANE).inst) and
           not fpuo.holdn = '0' and not holdn = '0' then
          v.e.fpu_wait := '1';
        end if;
      end if;
    end if;
    v.e.csr               := r.a.csr;
    v.e.csr.v             := ra_csr;
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


    -- Instruction Control ------------------------------------------------
    instruction_control(r,              -- in  : Registers
                        fpuo.ready,     -- in  : FPU not busy
                        fpuo.idle,      -- in  : FPU completely idle
                        ic_lddp,        -- out : Load Dependency Counter
                        ic_stb2b,       -- out : Store b2b Counter
                        ic_lbranch,     -- out : Late Branch Flag
                        ic_lalu,        -- out : Late ALU Flag
                        v.e.spec_ld,    -- out : Speculative load flag
                        v.e.accesshold, -- out : Memory access hold due to CSR changes.
                        v.e.exechold,   -- out : Execution hold due to pipeline flushing instruction.
                        v.e.fpuhold,    -- out : Execution hold due to FPU instructions.
                        ic_hold_issue   -- out : Hold Issue Signal
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

    -- RVC Aligner --------------------------------------------------------
    rvc_aligner(active_extensions,
                de_inst,                      -- in  : Fetch Instructions
                r.d.pc,                       -- in  : Decode PC
                r.d.valid,                    -- in  : Valid Instructions
                not (r.csr.mstatus.fs = "00" or
                (r.csr.v = '1' and r.csr.vsstatus.fs = "00")),
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
    if r.d.mexc = '1' and r.d.valid = '1' then
      de_rvc_aligned(0).xc := r.d.exchyper & r.d.exctype & '1';
      de_rvc_aligned(1).xc := r.d.exchyper & r.d.exctype & '1';
    -- In case it is lsb of an unaligned instruction,
    -- make it valid to take the trap.
      de_rvc_valid(0)      := '1';
    end if;

    -- RVC Expander -----------------------------------------------------
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
    v.d.buff.inst       := de_mux_instruction(1);
    v.d.buff.cinst      := de_mux_cinstruction(1);
    v.d.buff.pc         := to0x(r.d.pc(r.d.pc'high downto 3) & de_rvc_aligned(1).lpc & '0');
    v.d.buff.comp       := de_rvc_comp(1);
    v.d.buff.xc         := de_rvc_illegal(1);
    v.d.buff.comp_ill   := de_rvc_comp_ill(1);

    bjump_gen(active_extensions,
              de_inst,
              r.d.buff,
              r.d.prediction,
              r.d.valid,
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
                      de_inst_buff,
                      de_inst_valid,
                      ic_lalu,
                      de_lalu_pre);

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


    if single_issue = 0 then
      -- Issue Checker -----------------------------------------------------
      dual_issue_check(active_extensions,
                       lane,
                       de_inst_buff,      -- in  : Aligned Instructions
                       de_inst_valid,     -- in  : Valid Signals
--                       r.csr.dfeaturesen, -- in  : Machine Features CSR
                       r.csr.dfeaturesen.lbranch_dis,
                       r.csr.dfeaturesen.lalu_dis,
                       r.csr.dfeaturesen.dual_dis,
                       r.csr.dcsr.step,   -- in  : DCSR step
                       r.a.lalu_pre,      -- in  : Late ALUs from RA
                       r.d.mexc,          -- in  : Fetch exception
                       rd(v, e, 0),       -- in  : rd register from RA
                       v.e.ctrl(0).rdv,   -- in  : Valid rd register from RA
                       rd(v, e, 1),       -- in  : rd register from RA
                       v.e.ctrl(1).rdv,   -- in  : Valid rd register from RA
                       de_lane0_csr,      -- out : CSR must be copied to lane 0
                       de_issue           -- out : Issue Flag
                       );

    -- Dual Issue Swap ---------------------------------------------------
      dual_issue_swap(active_extensions,
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

    if r.d.mexc = '1' and r.d.valid = '1' then
      v.d.buff.valid := '0';
    end if;

    -- Hold PC if hold_issue from instruction_control or in dhalt state.
    if de_rvc_hold = '1' or (dmen = 1 and r.x.rstate = dhalt) then
      de_hold_pc := '1';
    end if;


    -- Decode Instructions
    for i in fetch'range loop
      de_rfa1(i)       := rs1_gen(de_inst_buff(i).d);
      de_rfa2(i)       := rs2_gen(de_inst_buff(i).d);
      -- For register file read port, generate non-masked address to reduce
      -- critical path, since register value does not matter when source
      -- is not valid.
      de_rfa1_nmask(i)  := de_inst_buff(i).d(19 downto 15);
      de_rfa2_nmask(i)  := de_inst_buff(i).d(24 downto 20);

      de_rfrd_valid(i) := rd_gen(de_inst_buff(i).d);

      imm_gen(de_inst_buff(i).d,        -- in  : Instruction
              de_imm_valid(i),          -- out : Immediate Valid Flag
              de_imm(i),                -- out : Immediate Value
              de_bj_imm(i));            -- out : only bjump imm value

      de_pc_valid(i)   := pc_valid(de_inst_buff(i).d);

      de_csr_valid(i)  := to_bit(is_csr(de_inst_buff(i).d));

      de_csr_rdo(i) := '0';
      if csr_read_only(de_inst_buff(i).d) then
        de_csr_rdo(i) := '1';
      end if;

      de_fusel(i)      := fusel_gen(active_extensions,
                                    de_inst_buff(i).d);   -- in  : Instruction

      exception_check(active_extensions,
                      envcfg,
                      not (r.csr.mstatus.fs = "00" or
                           (r.csr.v = '1' and r.csr.vsstatus.fs = "00")),
                      not alu_illegal(active_extensions, de_inst_buff(i).d),
                      illegalTval0 = 1,
                      de_inst_buff(i).d,   -- in  : Instruction
                      de_cinst_buff(i),    -- in  : Compressed instruction
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
        de_to_ra_cause(0)  := XC_INST_ACCESS_FAULT;
      elsif de_inst_buff(0).xc(2) = '1' then
        de_to_ra_cause(0)  := XC_INST_INST_G_PAGE_FAULT;
      else
        de_to_ra_cause(0)  := XC_INST_INST_PAGE_FAULT;
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
        de_to_ra_cause(1)  := XC_INST_ACCESS_FAULT;
      elsif de_inst_buff(1).xc(2) = '1' then
        de_to_ra_cause(1)  := XC_INST_INST_G_PAGE_FAULT;
      else
        de_to_ra_cause(1)  := XC_INST_INST_PAGE_FAULT;
      end if;
      de_to_ra_tval(1)     := pc2xlen(de_pc(1));
    end if;

    if r.d.mexc = '1' and (r.d.buff.valid = '0' or
                           (r.d.buff.valid = '1' and r.d.unaligned = '1' and r.d.mexc = '1')) then
      de_inst_valid(1) := '0';
    end if;

    -- inull icache after encountering an instruction memory exception
    mexc_inull   := '0';
    if (r.d.mexc = '1' and r.d.valid = '1') then
      mexc_inull := '1';
    end if;

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
      de_to_ra_cause := (others => XC_INST_ACCESS_FAULT);   -- To make sure NOP:ing is done in RA.
    end if;

    -- To Register Access Stage -------------------------------------------
    for i in lanes'range loop
      v.a.ctrl(i).pc      := de_pc(i);
      v.a.ctrl(i).inst    := de_inst_buff(i).d;
      v.a.ctrl(i).cinst   := de_cinst_buff(i);
      v.a.ctrl(i).valid   := de_issue(i) and de_inst_valid(i);
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
    -- CSRs that may cause pipeline flush always execute alone, but it is
    -- necessary to ensure that their PC is available in lane 0 (even with swap),
    -- to make later flush code able to only check there.
    --if single_issue = 0 and
    --   csr_lane = 1 then
    --  if de_lane0_csr = '1' then
    --    if de_swap = '1' then
    --      v.a.ctrl(0).pc  := de_pc(0);  -- Was in lane 0 before swap
    --    else
    --      v.a.ctrl(0).pc  := de_pc(1);  -- Was in lane 1 already
    --    end if;
    --  end if;
    --end if;

    -- Increase FPU issue ID
    if is_valid_fpu(v, a) then
      v.a.ctrl(fpu_lane).fpu := uadd(r.a.ctrl(fpu_lane).fpu, 1);
    end if;

    -- Related to CSR write hold checks in access stage
    v.a.csrw_eq := (others => '0');
    if v.a.ctrl(csr_lane).inst(31 downto 20) = r.a.ctrl(csr_lane).inst(31 downto 20) then
      if csr_ok(r,a) then
        v.a.csrw_eq(0) := '1';
      end if;
    end if;
    if v.a.ctrl(csr_lane).inst(31 downto 20) = r.e.ctrl(csr_lane).inst(31 downto 20) then
      if csr_ok(r,e) then
        v.a.csrw_eq(1) := '1';
      end if;
    end if;
    if v.a.ctrl(csr_lane).inst(31 downto 20) = r.m.ctrl(csr_lane).inst(31 downto 20) then
      if csr_ok(r,m) then
        v.a.csrw_eq(2) := '1';
      end if;
    end if;
    if v.a.ctrl(csr_lane).inst(31 downto 20) = r.x.ctrl(csr_lane).inst(31 downto 20) then
      if csr_ok(r,x) then
        v.a.csrw_eq(3) := '1';
      end if;
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
    v.a.csr.category      := csr_category(csr_addr(v, a));
    v.a.csr.ctrl          := csralu_gen(v.a.ctrl(csr_lane).inst);

    de_bhto_taken := de_rvc_bhto_taken;
    de_btbo_hit   := de_rvc_btb_hit;
    if de_swap = '1' then
      de_bhto_taken(1) := de_rvc_bhto_taken(0);
      de_bhto_taken(0) := de_rvc_bhto_taken(1);
      de_btbo_hit(1)   := de_rvc_btb_hit(0);
      de_btbo_hit(0)   := de_rvc_btb_hit(1);
    end if;

    de_raso.hit := '0';

    -- Return Address Stack Control ---------------------------------------
    v.a.raso.hit   := de_raso.hit;
    v.a.raso.rdata := de_raso.rdata;

    branch_misc(v.a.ctrl(branch_lane),
                de_bhto_taken(branch_lane),
                de_btbo_hit(branch_lane),
                de_bj_imm,
                de_swap,
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
    v.a.ctrl(branch_lane).branch.dir   := de_bhto_dir1;
    v.a.ctrl(branch_lane).branch.hit   := de_branch_hit;

    -- Invalid Second Instruction ----------------------------------------
    if de_branch = '1' and v.a.swap = '1' then
      v.a.ctrl(0).valid := '0';
    end if;

    -- Early JAL ----------------------------------------------------------
    ujump_resolve(v.a.ctrl(branch_lane),        -- in  : Instruction
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
        v.a.ctrl(branch_lane).tval  := pc2xlen(de_jump_addr);
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


    -- Dessert de_hold_pc on de_btb_taken and bjump instruction is issued
    if de_btb_taken = '1' then
      for i in 0 to 3 - (2 * single_issue) loop
        if de_bjump_pos(i) = '1' then
          for j in lanes'range loop
            if v.a.ctrl(j).valid = '1' and v.a.ctrl(j).pc(2 downto 1) = u2vec(i, 2)
              and v_a_inst_no_buf(j) = '0' and single_issue = 0 then
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
        for i in 0 to 3-(2*single_issue) loop
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
    -- Remember exception from last cycle?
    if r.d.was_xc = '1' then
--      de_inull := '1';
    end if;
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
            v.d.inst(0)(31 downto 0) := ico.data(i)(31 downto 0);
            if r.f.pc(2) = '1' then
              v.d.inst(0)(31 downto 0) := ico.data(i)(63 downto 32);
            end if;
            if ico.mds = '0' then
              v.d.inst(0)(31 downto 0) := ico.data(i)(31 downto 0);
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
      v.d.tval2       := ico.addrhyper(XLEN-1 downto 0);
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

    if de_nullify = '1' then
      for i in lanes'range loop
        v.a.ctrl(i).valid := '0';
      end loop;
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

    -- Insert Early Execption ---------------------------------------------
    v.d.cause         := XC_INST_ACCESS_FAULT;
    v.d.tval          := zerox;

    -- Valid Instruction for BTB
    de_btb_valid     := (others => '0');
    if r.f.valid = '1' then
      r_f_pc_21 := r.f.pc(2 downto 1);
      case r_f_pc_21 is
        when "00" =>
          de_btb_valid := "1111";
        when "01" =>
          de_btb_valid := "1110";
        when "10" =>
          de_btb_valid := "1100";
          if single_issue /= 0 then
            de_btb_valid := "1111";
          end if;
        when "11" =>
          de_btb_valid := "1000";
          if single_issue /= 0 then
            de_btb_valid := "1110";
          end if;
        when others =>
          null;
      end case;
    end if;

    -- From Branch History Table ------------------------------------------
    --v.d.prediction(0).dir     := bhto.rdata(1 downto 0);
    --v.d.prediction(1).dir     := bhto.rdata(3 downto 2);
    for i in 0 to 3 loop
      v.d.prediction(i).taken := bhto.taken(i);
    end loop;

    if r.csr.dfeaturesen.staticbp = '1' then
      for i in 0 to 3 loop
--        v.d.prediction(i).dir   := (others => '0');
        v.d.prediction(i).taken := r.csr.dfeaturesen.staticdir;
      end loop;
    end if;

    -- From Branch Target Buffer ------------------------------------------
    de_hit := '0';
    btb_hitv := btbo.hit;
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
    -- 0 -> Debug Request from Exception Stage
    -- 1 -> Flush from Write-back Stage
    -- 2 -> Late Branch from Exception Stage
    -- 3 -> Branch from Execute Stage
    -- 4 -> RAS Hit from Decode Stage

    -- Second Stage:
    -- 0 -> Reset
    -- 1 -> Exception from Exception Stage
    -- 2 -> Mux from First Stage
    -- 3 -> Jump from Execute Stage
    -- 4 -> Branch from Execute Stage
    -- 5 -> Early Jump from Decode Stage
    -- 6 -> Hold PC
    -- 7 -> BTB Hit from Decode Stage
    -- 8 -> Next Pc

    -- Hierarchical First Stage
    mux_valid    := '1';
    mux_reread   := '0';
    -- Debug ---------------------------------------------------------------
    if dbg_request = '1' then
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
    elsif x_xc_taken = '1' then
      next_pc   := x_xc_tvec; -- From mux of r.csr
      reread_pc := '1';
    -- First Stage ---------------------------------------------------------
    elsif mux_valid = '1' then
      next_pc   := mux_pc; -- From level 1 mux
      reread_pc := mux_reread;
    -- Control Flow Management ---------------------------------------------
    elsif ex_jump = '1' then
      next_pc   := ex_jump_addr; -- From AGU in Execute Stage
    -- early branch or JAL -----------------------------------------------------------------
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

    --bhti_waddr       := r.wb.ctrl(branch_lane).pc;
    --if ext_c = 1 then
    --  if r.wb.ctrl(branch_lane).comp = '0' and r.wb.ctrl(branch_lane).pc(2) = '1' then
    --    bhti_waddr   := r.wb.unalg_pc;
    --  end if;
    --end if;

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
    ici.parkreq <= '0';

    -----------------------------------------------------------------------
    -- MISCS
    -----------------------------------------------------------------------

    v.fpo := fpuo;         -- For logging

    -- Instruction Trace --------------------------------------------------

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

    itracei               <= itrace_in;


    -- E-Trace interface --------------------------------------------------
    etrace_gen(
      holdn => holdn,
      r_wb  => r.wb,
      r_x   => r.x,
      r_csr => r.csr,
      eto   => veto);

    v.evt    := (others => '0');
    v.cevt   := (others => '0');
    v.evtirq := (others => '0');

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
          -- .event = 0 means no event counted, but r.evt(0) is also never set!
          if ext_sscofpmf = 0 or hpmevent_active then
            v.cevt(i) := r.evt(u2i(r.csr.hpmevent(i).event));
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
            v.csr.hpmcounter(i) := to64(get(hpmcount, 0, perf_bits));
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

    -- Speculative updating of FPU register dirty status
    -- It does not matter that we sometimes set dirty for instructions
    -- that are later nullified. This is allowed by the standard.
    if (r.a.ctrl(fpu_lane).valid    = '1' and r.a.ctrl(fpu_lane).xc = '0' and
        is_fpu_modify(r.a.ctrl(fpu_lane).inst)) or
       (r.a.ctrl(memory_lane).valid = '1' and r.a.ctrl(memory_lane).xc = '0' and
        is_fpu_modify(r.a.ctrl(memory_lane).inst)) then
      v.csr.mstatus.fs    := "11";
      if r.csr.v = '1' then
        v.csr.vsstatus.fs := "11";
      end if;
    end if;
    -- Force always dirty?
    if v.csr.dfeaturesen.fs_dirty = '1' then
      if v.csr.mstatus.fs /= "00" then
        v.csr.mstatus.fs := "11";
      end if;
      if v.csr.vsstatus.fs /= "00" then
        v.csr.vsstatus.fs := "11";
      end if;
    end if;

    if holdn = '0' then
      -- Things that update during hold.
      v.evt(CSR_HPM_HOLD)         := '1';
    else
      v.evt(CSR_HPM_DUAL_ISSUE)   := to_bit(single_issue = 0) and v.wb.ctrl(0).valid and v.wb.ctrl(one).valid;
      v.evt(CSR_HPM_SINGLE_ISSUE) := v.wb.ctrl(0).valid xor (to_bit(single_issue = 0) and v.wb.ctrl(one).valid);
      v.evt(CSR_HPM_BRANCH_MISS)  := (mem_branch or wb_branch);
      v.evt(CSR_HPM_HOLD_ISSUE)   := de_hold_pc;
      v.evt(CSR_HPM_BRANCH)       := to_bit(v_fusel_eq(v, wb, branch_lane, BRANCH));
      v.evt(CSR_HPM_LOAD_DEP)     := ic_lddp;
      v.evt(CSR_HPM_STORE_B2B)    := ic_stb2b;
      v.evt(CSR_HPM_JALR)         := to_bit(v_fusel_eq(v, wb, branch_lane, JALR));
      v.evt(CSR_HPM_JAL)          := to_bit(v_fusel_eq(v, wb, branch_lane, JAL));
    end if;
    v.evt(CSR_HPM_ICACHE_MISS)    := perf(0);
    v.evt(CSR_HPM_ITLB_MISS)      := perf(1);
    v.evt(CSR_HPM_DCACHE_MISS)    := perf(2);
    v.evt(CSR_HPM_DTLB_MISS)      := perf(3);
    v.evt(CSR_HPM_DCACHE_FLUSH)   := perf(4);

    v.evt(CSR_HPM_FPU_LOW to CSR_HPM_FPU_LOW + fpevt_t'length - 1) := fpuo.events(fpevt_t'length - 1 downto 0);

    v.evt(perf_evts to v.evt'high) := (others => '0');

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
      -- Invalidate Memory Next Instruction
      for i in lanes'range loop
        v.m.ctrl(i).valid := '0';
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


    -----------------------------------------------------------------------
    -- Pipeline some signals towards MMU/cache control to improve timing
    -----------------------------------------------------------------------

    -- There is an IU pipeline flush on writes to these CSRs, so no harm is done.
    v.mmu             := nv_csr_out_type_none;
    -- Writes to these (in the exception stage) will cause a pipeline flush
    -- in the writeback stage, so there is time to register the data once
    -- before it is required.
    v.mmu.satp        := r.csr.satp;
    v.mmu.vsatp       := r.csr.vsatp;
    v.mmu.hgatp       := r.csr.hgatp;
    v.mmu.mmu_adfault := r.csr.dfeaturesen.mmu_adfault;
    -- These only flush when lock bits are set, but they also do not affect
    -- anything otherwise (machine mode vs others) , so pipelining is OK.
    v.mmu.pmpcfg0     := r.csr.pmpcfg0;
    v.mmu.pmpcfg2     := r.csr.pmpcfg2;


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

    if csr_ok(r, m) then
      v.x.csraxc := csr_write_xc(
--                                 active_extensions, TRIGGER,
                                 envcfg,
                                 csr_addr(r.m.ctrl(csr_lane).inst), r.x.rstate, r.csr);
    else
      v.x.csraxc := '0';
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
      for i in lanes'range loop
        ex_alu_preforward(v, e, x, i, v.e.aluforw(i), v.e.alupreforw1(i), v.e.alupreforw2(i));
      end loop;
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

    -- Constant registers -------------------------------------------------

    -- Big-endian not supported
    v.csr.mstatus.sbe   := '0';
    v.csr.mstatus.ube   := '0';
    -- Reserved interrupts
    v.csr.mip     := v.csr.mip     and not CSR_IRQ_RSV_MASK;
    v.csr.mie     := v.csr.mie     and not CSR_IRQ_RSV_MASK;
    v.csr.mideleg := v.csr.mideleg and not CSR_IRQ_RSV_MASK;
    -- H-extension not implemented
    if ext_h = 0 then
      v.csr.v           := '0';
      v.csr.dcsr.v      := '0';
      v.csr.hstatus     := csr_hstatus_rst;
      v.csr.hideleg     := (others => '0');
      v.csr.hedeleg     := (others => '0');
      v.csr.hgatp       := (others => '0');
      v.csr.hvip        := (others => '0');
      v.csr.hip         := (others => '0');
      v.csr.hie         := (others => '0');
      v.csr.hgeip       := (others => '0');
      v.csr.hgeie       := (others => '0');
      v.csr.hcounteren  := (others => '0');
      v.csr.htimedelta  := (others => '0');
      v.csr.htval       := (others => '0');
      v.csr.htinst      := (others => '0');
      v.csr.vsstatus    := csr_status_rst;
      v.csr.vsepc       := (others => '0');
      v.csr.vsatp       := (others => '0');
      v.csr.vsscratch   := (others => '0');
      v.csr.vscause     := (others => '0');
      v.csr.vstval      := (others => '0');
      v.csr.vstimecmp   := (others => '0');
      v.csr.mstatus.mpv := '0';
      v.csr.mstatus.gva := '0';
      v.csr.mtval2      := (others => '0');
      v.csr.mtinst      := (others => '0');
      v.mmu.vsatp       := (others => '0');
      v.mmu.hgatp       := (others => '0');
      v.csr.mip         := v.csr.mip     and not CSR_HIE_MASK;
      v.csr.mie         := v.csr.mie     and not CSR_HIE_MASK;
      v.csr.mideleg     := v.csr.mideleg and not CSR_HIE_MASK;
    end if;
    -- S-mode not implemented
    if mode_s = 0 then
      v.csr.satp        := (others => '0');
      v.csr.stvec       := (others => '0');
      v.csr.sepc        := (others => '0');
      v.csr.stval       := (others => '0');
      v.csr.stimecmp    := (others => '0');
      v.csr.scause      := (others => '0');
      v.csr.sscratch    := (others => '0');
      v.csr.mstatus.sxl := "00";
      v.csr.mstatus.spp := '0';
      v.csr.mstatus.mxr := '0';
      v.csr.mstatus.sum := '0';
      v.csr.mstatus.tvm := '0';
      v.csr.mstatus.tsr := '0';
      v.csr.mstatus.sie := '0';
      v.csr.mstatus.spie:= '0';
      v.csr.mip         := v.csr.mip     and not CSR_SIE_MASK;
      v.csr.mie         := v.csr.mie     and not CSR_SIE_MASK;
      v.csr.mideleg     := v.csr.mideleg and not CSR_SIE_MASK;
      v.mmu.satp        := (others => '0');
      v.mmu.mmu_adfault := '0';
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
      v.csr.mip(cause2int(IRQ_LCOF))     := '0';
      v.csr.mie(cause2int(IRQ_LCOF))     := '0';
      v.csr.mideleg(cause2int(IRQ_LCOF)) := '0';
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
    -- PMP not implemented
    if pmp_entries = 0 then
      v.csr.pmpaddr     := (others => pmpaddrzero);
      v.csr.pmpcfg0     := (others => '0');
      v.csr.pmpcfg2     := (others => '0');
      v.csr.pmp_precalc := PMPPRECALCRES;
      v.mmu.pmpcfg0     := (others => '0');
      v.mmu.pmpcfg2     := (others => '0');
    end if;
    -- Clear non-existing performance counters
    -- Should not be needed, but makes things clearer.
    for i in 0 to 2 loop
      v.cevt(i)              := '0';
      v.evtirq(i)            := '0';
      v.csr.hpmcounter(i)    := (others => '0');
      v.csr.hpmevent(i)      := hpmevent_none;
    end loop;
    -- Clear unimplemented performance counters
    for i in perf_cnts + 3 to r.csr.hpmcounter'high loop
      v.csr.hpmcounter(i)    := (others => '0');
      v.csr.hpmevent(i)      := hpmevent_none;
      v.csr.mcountinhibit(i) := '0';
      v.csr.mcounteren(i)    := '0';
      v.csr.hcounteren(i)    := '0';
      v.csr.scounteren(i)    := '0';
    end loop;
    -- Clear unimplemented MSB:s of performance counters
    for i in r.csr.hpmcounter'range loop
      v.csr.hpmcounter(i)(v.csr.hpmcounter(0)'high downto perf_bits) := (others => '0');
    end loop;

    -- Trace Code ----------------------------------------------------
    if v_fusel_eq(r, m, memory_lane, ST) then
      v.x.result(memory_lane)     := me_stdata(wordx'range);
      v.x.fsd_hi                  := get_hi(me_stdata, 32);
      if r.m.dci.size = SZWORD then
        -- We can only be here if XLEN = 64 (FPU data comes another way).
        v.x.result(memory_lane)   := to0x(me_stdata(31 downto 0));
      elsif r.m.dci.size = SZHALF then
        v.x.result(memory_lane)   := to0x(me_stdata(15 downto 0));
      elsif r.m.dci.size = SZBYTE then
        v.x.result(memory_lane)   := to0x(me_stdata( 7 downto 0));
      end if;
    end if;
    -- Only for trace
    v.x.wcsr                      := zerox;
    if v_fusel_eq(r, m, memory_lane, LD or ST) then
      v.x.wcsr(r.m.address'range) := r.m.address;
    end if;
    v.wb.fsd_hi                   := r.x.fsd_hi;

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
      rfi.raddr2        <= rfi_raddr12(1);
      rfi.raddr4        <= rfi_raddr34(1);
      rfi.ren2          <= rfi_ren12(1);
      rfi.ren4          <= rfi_ren34(1);
      rfi.waddr2        <= rfi_waddr12(1);
      rfi.wdata2        <= rfi_wdata12(1);
      rfi.wen2          <= rfi_wen12(1);
    else
      rfi.raddr2        <= (others => '0');
      rfi.raddr4        <= (others => '0');
      rfi.ren2          <= '0';
      rfi.ren4          <= '0';
      rfi.waddr2        <= (others => '0');
      rfi.wdata2        <= (others => '0');
      rfi.wen2          <= '0';
    end if;
    -- To Return Address Stack --------------------------------------------
    rasi.push           <= vrasi.push  and holdn and not(r.csr.dfeaturesen.ras_dis);
    rasi.pop            <= vrasi.pop   and holdn and not(r.csr.dfeaturesen.ras_dis);
    rasi.flush          <= vrasi.flush and holdn and not(r.csr.dfeaturesen.ras_dis);
    rasi.wdata          <= vrasi.wdata;

    -- To the Instruction Trace Buffer ------------------------------------
    itracei             <= itrace_in;

    -- E-trace interface --------------------------------------------------
    eto                 <= veto;

    -- Performance counters
    cnt.icnt     <= r.wb.icnt;
    -- Branch prediction miss
    cnt.bpmiss   <= r.evt(CSR_HPM_BRANCH_MISS);
    -- Not assigned here
    cnt.icmiss   <= '0';
    cnt.itlbmiss <= '0';
    cnt.dcmiss   <= '0';
    cnt.dtlbmiss <= '0';

    -- To the Interrupt Bus -----------------------------------------------
    irqo.irqack         <= '0';

    -- To the Debug Module ------------------------------------------------
    if dmen = 1 then
      dbgo.dsu          <= '1';
      dbgo.error        <= dbg_error;
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
    if ext_f = 1 then
      -- From Execute Stage
      fpu_ctrl             := r.e.ctrl(fpu_lane);
      vfpui.inst           := fpu_ctrl.inst;
      vfpui.e_valid        := to_bit(is_valid_fpu(r, e));
      vfpui.issue_id       := fpu_ctrl.fpu;
      vfpui.csrfrm         := r.csr.frm;
      vfpui.mode           := r.csr.v & r.csr.prv;
      -- qqq This must be wrong, right?
      --     The reasonable thing would be ex_flush.
--      vfpui.e_nullify    := v.wb.flushall or mem_branch;
      vfpui.e_nullify      := ex_flush or ex_fpu_flush or me_fpu_flush;
      -- From Exception Stage
      if holdn = '1' then
        vfpui.data_id      := r.x.ctrl(fpu_lane).fpu;
        vfpui.data         := r.x.data(0);   -- Assume load
        -- Floating point and not load?
        if r.x.ctrl(fpu_lane).inst(6 downto 0) = OP_FP then
          vfpui.data       := to64(x_alu_op1(fpu_lane));
        end if;
        if is_valid_fpu(r, x) and is_fpu_from_int(r.x.ctrl(fpu_lane).inst) then
          vfpui.data_valid := '1';
        end if;
      end if;
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
      -- Commit
      fpu_ctrl          := r.wb.ctrl(fpu_lane);
      vfpui.commit      := holdn and to_bit(is_valid_fpu(r, wb) and
                                            is_fpu_rd(fpu_ctrl.inst));
      vfpui.commit_id   := fpu_ctrl.fpu;
--      vfpui.unissue     := holdn and fpu_ctrl.fpu_flush and to_bit(is_fpu_rd(fpu_ctrl.inst));
      vfpui.unissue     := holdn and fpu_ctrl.fpu_flush;
      vfpui.unissue_id  := fpu_ctrl.fpu;
      if fpu_debug /= 0 then
        vfpui.ctrl      := r.csr.fctrl;
      end if;
    end if;
    fpui                <= vfpui;



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
          r.csr.mip(13)    <= rin.csr.mip(13);
          r.csr.hpmcounter <= rin.csr.hpmcounter;
          for i in 3 to r.cevt'high loop
            r.csr.hpmevent(i).overflow <= rin.csr.hpmevent(i).overflow;
          end loop;
          r.csr.fflags     <= rin.csr.fflags;
          -- Must note if FPU result is awaited
          r.e.fpu_wait     <= rin.e.fpu_wait;
          -- FPU result
          r.fpo            <= rin.fpo;

          -- I Cache Miss
          if ico.mds = '0' then
            r.d.inst       <= rin.d.inst;
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
            r.x.data       <= rin.x.data;
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
            r.csr.mcause       <= cause2wordx(RST_ASYNC);
            r.csr.misa         <= create_misa;
            r.f.pc             <= PC_RESET;
            r.f.valid          <= '0';
            r.d.valid          <= '0';
            if need_extra_sync_reset(fabtech) /= 0 then
              r.d.inst         <= (others => (others => '0'));
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

-- pragma translate_off
          -- Activate caches - for simulation
          r.csr.cctrl.dsnoop <= '1';
          r.csr.cctrl.iflush <= '1';
          r.csr.cctrl.dflush <= '1';
          r.csr.cctrl.dcs    <= "11";
          r.csr.cctrl.ics    <= "11";
-- pragma translate_on
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
              r.x.data      <= rin.x.data;
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
              r.x.data      <= rin.x.data;
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
