------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
---------------------------------------------------------------------------------
-- Entity:      iunv
-- File:        iunv.vhd
-- Author:      Andrea Merlo Cobham Gaisler AB
--              Alen Bardizbanyan Cobham Gaisler AB
--              Johan Klockars Cobham Gaisler AB
--              Nils Wessman Cobham Gaisler AB
-- Description: NOEL-V 7-stage integer pipline
---------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.riscv.all;
use grlib.stdlib.tost;
use grlib.stdlib.tost_bits;
use grlib.stdlib.log2;
use grlib.stdlib.log2x;
use grlib.stdlib.orv;
use grlib.stdlib.notx;
use grlib.stdlib.print;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.noelv.XLEN;
use gaisler.noelv.GEILEN;
use gaisler.noelv.nv_irq_in_type;
use gaisler.noelv.nv_irq_out_type;
use gaisler.noelv.nv_debug_in_type;
use gaisler.noelv.nv_debug_out_type;
use gaisler.noelv.nv_debug_out_none;
use gaisler.noelv.nv_counter_out_type;
use gaisler.noelvint.all;
use gaisler.mmucacheconfig.satp_mode;
use gaisler.utilnv.minimum;
use gaisler.utilnv.maximum;
use gaisler.utilnv.to_bit;
use gaisler.utilnv.u2i;
use gaisler.utilnv.to_reg;
use gaisler.utilnv.log;
use gaisler.utilnv.all_0;
use gaisler.utilnv.all_1;
use gaisler.utilnv.u2slv;
use gaisler.utilnv.uadd;
use gaisler.utilnv.uadd_range;
use gaisler.fputilnv.fpu_id;
use gaisler.fputilnv.fpevt_t;
-- pragma translate_off
use grlib.riscv_disas.all;
-- pragma translate_on

entity iunv is
  generic (
    hindex       : integer range 0  to 15;       -- Hart index
    fabtech      : integer range 0  to NTECH;    -- fabtech
    memtech      : integer range 0  to NTECH;    -- memtech
    -- Core
    physaddr     : integer range 32 to 56;       -- Physical Addressing
    pcbits       : integer range 32 to 64;       -- Max bits required for PC
    rstaddr      : integer;                      -- Reset vector (MSB)
    disas        : integer;                      -- Disassembly to console
    perf_cnts    : integer range 0  to 31;       -- Number of performance counters
    perf_evts    : integer range 0  to 255;      -- Number of performance events
    illegalTval0 : integer range 0  to 1;        -- Zero TVAL on illegal instruction
    no_muladd    : integer range 0  to 1;        -- 1 - multiply-add not supported
    single_issue : integer range 0  to 1;        -- 1 - only one pipeline
    -- Caches
    iways        : integer range 1  to 4;        -- I$ Sets
    dways        : integer range 1  to 4;        -- D$ Sets
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
    mode_s       : integer range 0  to 1;        -- Supervisor Mode Support
    mode_u       : integer range 0  to 1;        -- User Mode Support
    dmen         : integer range 0  to 1;        -- Using RISC-V Debug Module
    fpulen       : integer range 0  to 128;      -- Floating-point precision
    trigger      : integer range 0  to 4096;
    -- Advanced Features
    late_branch  : integer range 0  to 1;        -- Late Branch Support
    late_alu     : integer range 0  to 1;        -- Late ALUs Support
    -- Misc
    pbaddr       : integer;                      -- Program buffer exe address
    tbuf         : integer;                      -- Trace buffer size in kB
    scantest     : integer;                      -- Scantest support
    rfreadhold   : integer range 0  to 1;        -- Register File Read Hold
    fpu_lane     : integer range 0  to 1 := 0;   -- Lane where (non-memory) FPU instructions go
    csr_lane     : integer range 0  to 1 := 0;   -- Lane where CSRs are handled
    endian       : integer range 0  to 1
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
    csr_mmu        : out csrtype;              -- CSR values for MMU
    perf           : in  std_logic_vector(31 downto 0);
    cap            : in  std_logic_vector(2 downto 0);
    tbo            : in  nv_trace_out_type;    -- Trace Unit Out Port
    tbi            : out nv_trace_in_type;     -- Trace Unit In Port
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
  constant rv : std_logic_vector(1 downto 0) := u2slv(log2(XLEN / 32) + 1, 2);

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

  -------------------------------------------------------------------------------
  -- Constant Declarations
  -------------------------------------------------------------------------------

  constant va         : std_logic_vector := gaisler.mmucacheconfig.va(riscv_mmu);
  constant pa         : std_logic_vector := gaisler.mmucacheconfig.pa(riscv_mmu);
  constant pmp_msb    : integer          := physaddr - 1;    -- High bit for PMP checks

  -- Sign extend to 64 bit word.
  function to64(v : std_logic_vector) return word64 is
    variable v_normal : std_logic_vector(v'length - 1 downto 0) := v;
    -- Non-constant
    variable ext      : word64                                  := (others => v_normal(v_normal'high));
  begin
    ext(v_normal'range) := v;

    return ext;
  end;

  -- Zero extend to wordx.
  function to0x(v : std_logic_vector) return wordx is
    variable v_normal : std_logic_vector(v'length - 1 downto 0) := v;
    -- Non-constant
    variable ext      : wordx                                   := (others => '0');
  begin
    ext(v_normal'range) := v;

    return ext;
  end;

  -- Not quite the same as in MMU/cache, since there it needs to deal with
  -- an actual address (which may be larger than XLEN) after translation.
  -- In the pipeline, the length is limited to max XLEN bits.
  function addr_bits return integer is
  begin
    return minimum(XLEN, 1 + maximum(va'length, minimum(physaddr, pa'length)));
  end;

  -- Implementation Constants
--  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1
--                                     and GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 0;
  constant RESET_ALL    : boolean := true;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant ENDIAN_B     : boolean := (endian /= 0);

  -- Use old implementation of rd, rs equal check.
  constant OLD_RD_VS_RS  : boolean := false; --(fabtech = virtex4);
  constant NO_PREFORWARD : boolean := false; --(fabtech = virtex4);

  -- Extension Set Constants
  constant ext_f        : integer := to_floating(fpulen, 32);
  constant ext_d        : integer := to_floating(fpulen, 64);
  constant ext_q        : integer := to_floating(fpulen, 128);
  constant ext_n        : integer := 0;

  -- Pipeline Constants
  constant RFBITS       : integer := 5;
  constant FUSELBITS    : integer := 9;
  constant lanes        : std_logic_vector(0 to 1 - single_issue) := (others => '0');  -- Used as range.
  constant CAUSEBITS    : integer := 4 + ext_h;

  -- Cache Constants
  constant DWAYMSB      : integer := log2x(dways) - 1;
  constant IWAYMSB      : integer := log2x(iways) - 1;
  constant DYNRST       : boolean := (rstaddr = 16#FFFFF#);

  -- Trace Buffer Constants
  constant TRACEBUF     : boolean := (tbuf /= 0);
  constant TBUFBITS     : integer := 4 + log2(tbuf);


  -- ISA Constants
  constant ISA_EXTENSION : std_logic_vector(25 downto 0) :=
    '0'                 &     -- Reserved
    '0'                 &     -- Reserved
    '0'                 &     -- Non-standard
    '0'                 &     -- Reserved
    '0'                 &     -- V
    to_bit(mode_u)      &     -- User mode
    '0'                 &     -- T
    to_bit(mode_s)      &     -- Supervisor mode
    '0'                 &     -- Reserved
    to_bit(ext_q)       &     -- Q
    '0'                 &     -- P
    '0'                 &     -- Reserved
    to_bit(ext_n)       &     -- N
    to_bit(ext_m)       &     -- M
    '0'                 &     -- L
    '0'                 &     -- Reserved
    '0'                 &     -- J
    '1'                 &     -- RV64I base ISA
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
  constant h_ctrl      : integer := 7;   -- Hypervisor extension (H)
  constant ISA_CONTROL : wordx   := (h_ctrl => '1', others => '0');
  constant ISA_DEFAULT : word    := "000000" & ISA_EXTENSION;
  constant misa_ctrl   : boolean := true;  -- MISA changes allowed?

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
    addr(31 downto 12) := u2slv(pbaddr, 20);

    return addr;
  end;

  constant DPROGBUF : wordx := create_dprogbuf;

  -------------------------------------------------------------------------------
  -- Type Declarations
  -------------------------------------------------------------------------------

  subtype word2  is std_logic_vector(1 downto 0);
  subtype word3  is std_logic_vector(2 downto 0);
  subtype word8  is std_logic_vector(7 downto 0);
  subtype wordx1 is std_logic_vector(wordx'high + 1 downto 0);

  -- Pipeline

  -- The maximum bits that are required to hold an address (physical or virtual).
  -- May be one bit longer than the actual address, since we need to keep track of
  -- whether higher bits are the same or not (not same - bad address).
  subtype addr_type is std_logic_vector(addr_bits - 1 downto 0);

  function to_addr(addr_in : std_logic_vector) return addr_type is
    variable addr_normal : std_logic_vector(addr_in'length - 1 downto 0)         := addr_in;
    variable high_bits   : std_logic_vector(addr_in'length - 1 downto addr_bits) := (others => '0');
    -- Non-constant
    variable addr        : addr_type;  -- Manipulated from _in for efficiency.
  begin
    addr := addr_normal(addr'range);
    if addr_normal'length > addr'length then
      -- All high bits the same?
      if all_0(addr_normal(high_bits'range)) or
         all_1(addr_normal(high_bits'range)) then
        addr(addr'high) := addr(addr'high - 1);
      else
        -- Mark that some higher bits are different.
        addr(addr'high) := not addr(addr'high - 1);
      end if;
    end if;

    return addr;
  end;

  -- This is the maximum number of bits that need to be stored for PC,
  -- but calculations need full 64 bits (or at least check for bad address).
  subtype pctype         is addr_type;
  subtype rfatype        is std_logic_vector(RFBITS - 1 downto 0);
  subtype fuseltype      is std_logic_vector(FUSELBITS - 1 downto 0);

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


  type iword_type is record
    lpc : std_logic_vector(1 downto 0);
    d   : word;
    dc  : word16;
    xc  : word3;
    c   : std_ulogic;
  end record;
  type iword16_type is record
    lpc : std_logic_vector(1 downto 0);
    d   : word16;
    xc  : word3;
  end record;
  -- These are for the two fetched instructions, not lanes!
  constant fetch          : std_logic_vector(0 to 1) := (others => '0');    -- Used as range.
  subtype fetch_pair     is std_logic_vector(fetch'high downto fetch'low);  -- Must be n downto 0!
  type iword_pair_type   is array (fetch'range) of iword_type;
  type iword16_pair_type is array (fetch'range) of iword16_type;
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
                                       u2slv(rstaddr, 20) & PC_ZERO(11 downto 0);

  -- Functional Units Encoding: one-hot encoding for easier decode.
  constant NONE         : fuseltype := "000000000";
  constant SOMETHING    : fuseltype := "111111111";  -- !None
  constant ALU          : fuseltype := "000000001";  -- ALU
  constant BRANCH       : fuseltype := "000000010";  -- Branch Unit
  constant JAL          : fuseltype := "000000100";  -- JAL
  constant JALR         : fuseltype := "000001000";  -- JALR
  constant FLOW         : fuseltype := "000001100";  -- Jump (JAL/JALR)
  constant MUL          : fuseltype := "000010000";  -- Mul/Div
  constant LD           : fuseltype := "000100000";  -- Load
  constant ST           : fuseltype := "001000000";  -- Store
  constant AMO          : fuseltype := "010000000";  -- Atomics
  constant FPU          : fuseltype := "100000000";  -- From FPU
  constant NOT_LATE     : fuseltype := "111111100";  -- All except ALU and Branch Unit

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
--  type rd_src_type is array (stage_type'(a) to stage_type'(wb)) of lanes_type;
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

  -- Prediction -----------------------------------------------------------------
  type prediction_type is record
    taken       : std_ulogic;                          -- branch predicted to be taken
    dir         : std_logic_vector(bhti.wdata'range);  -- bht branch output
    hit         : std_ulogic;                          -- branch has been found in BTB
  end record;

  constant prediction_none : prediction_type := (
    taken       => '0',
    dir         => (others => '0'),
    hit         => '0'
    );

  type prediction_array_type is array (0 to 3) of prediction_type;

  -- Instruction Queue ------------------------------------------------------
  -- The instruction queue is a single-entry instruction buffer located in the
  -- decode stage.
  type iqueue_type is record
    pc              : pctype;           -- program counter
    inst            : iword_type;       -- instruction
    cinst           : word16;           -- compressed instruction
    valid           : std_ulogic;       -- instruction buffer entry is valid
    comp            : std_ulogic;  -- instruction buffer entry is compressed
    xc              : std_ulogic;  -- instruction buffer entry has generated a trap in previous stages
    bjump           : std_ulogic;       -- 1-> branch or jump inst
    bjump_predicted : std_ulogic;       -- 1-> bjump already predicted before buffering
    prediction      : prediction_type;  -- prediction as from the BHT
    comp_ill        : std_ulogic; --compressed instruction is invalid
  end record;

  constant iqueue_none : iqueue_type := (
    pc              => PC_RESET,
    inst            => ("00", zerow, (others => '0'), "000", '0'),
    cinst           => zerow16,
    valid           => '0',
    comp            => '0',
    xc              => '0',
    --xc_msb          => '0',
    bjump           => '0',
    bjump_predicted => '0',
    prediction      => prediction_none,
    comp_ill        => '0'
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
    uninst      : iword16_type;                       -- unaligned compressed instruction
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
  type alu_in_type is record
    op1         : wordx;                   -- operand 1
    op2         : wordx;                   -- operand 2
    valid       : std_ulogic;              -- enable signal
    ctrl        : word3;                   -- alu control
    alusel      : word2;                   -- alu operation
    lalu        : std_ulogic;              -- instruction makes use of lalu
  end record;

  type alu_in_pair_type is array (lanes'range) of alu_in_type;

  constant alu_in_none  : alu_in_type := (
    op1         => zerox,
    op2         => zerox,
    valid       => '0',
    ctrl        => (others => '0'),
    alusel      => (others => '0'),
    lalu        => '0'
    );

  -- ALU Operations -----------------------------------------------------------
  -- Logic Operation
  constant EXE_AND      : word3 := "000";
  constant EXE_OR       : word3 := "001";
  constant EXE_XOR      : word3 := "010";

  -- Shift Operation
  constant EXE_SLL      : word3 := "100";
  constant EXE_SLLW     : word3 := "000";
  constant EXE_SRL      : word3 := "101";
  constant EXE_SRLW     : word3 := "001";
  constant EXE_SRA      : word3 := "111";
  constant EXE_SRAW     : word3 := "011";

  -- Math Operation
  constant EXE_ADD      : word3 := "100";
  constant EXE_ADDW     : word3 := "000";
  constant EXE_SUB      : word3 := "101";
  constant EXE_SUBW     : word3 := "001";
  constant EXE_SLTU     : word3 := "110";
  constant EXE_SLT      : word3 := "111";

  -- Misc Operation
  constant EXE_BYPASS2  : word3 := "001";

  -- Execute Stage Operation Types
  constant ALU_MATH     : word2 := "00";
  constant ALU_SHIFT    : word2 := "01";
  constant ALU_LOGIC    : word2 := "10";
  constant ALU_MISC     : word2 := "11";

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
    alui        : alu_in_pair_type;          -- ALUs record
    stdata      : wordx;                     -- Data to be stored for ST instructions
    accesshold  : std_logic_vector(0 to 1);  -- Memory access hold due to CSR access.
    exechold    : std_logic_vector(0 to 2);  -- Execution hold due to pipeline flushing instruction.
    fpuhold     : std_logic_vector(0 to 5);  -- Execution hold due to FPU instruction.
    fpu_issued  : std_ulogic;                -- FPU instruction has been issued
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

  type trig_typ_vector_type  is array (0 to TRIGGER_NUM - 1) of std_logic_vector(3 downto 0);
  type trig_info_vector_type is array (0 to TRIGGER_NUM - 1) of std_logic_vector(15 downto 0);
  function set_trig_typ_vector(mc : integer;
                               ic : integer;
                               ie : integer) return trig_typ_vector_type is
    -- Non-constant
    variable typ : trig_typ_vector_type := (others => (others => '0'));
  begin
    for i in 0 to (mc + ic + ie) - 1 loop
      if i < mc then
        typ(i) := x"2";
      elsif (ic /= 0) and i < (mc + ic) then
        typ(i) := x"3";
      elsif (ie /= 0) and i = (mc + ic) then
        typ(i) := x"4";
      else
        typ(i) := x"5";
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
    alui        : alu_in_pair_type;             -- Late ALUs record
    spec_ld     : std_ulogic;                   -- Speculative load operation flag
    rasi        : nv_ras_in_type;               -- Speculative RAS record
    trig        : trig_type;                    -- Trigger on instruction
  end record;

  -- Core State ---------------------------------------------------------------
  type core_state is (run, dhalt, dexec);

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
    wcsr        : wordx;                        -- Write back CSR value
    csrw        : lanes_type;                   -- CSR write enable
    csraxc      : std_ulogic;                   -- CSR write address not OK
    ret         : word2;                        -- Privileged level to return
    swap        : std_ulogic;                   -- Instrutions are swapped
    alupreforw1 : mux_lanes_type;               -- ALUs preforward information
    alupreforw2 : mux_lanes_type;               -- ALUs preforward information
    lbranch     : std_ulogic;                   -- Late branch flag
    alui        : alu_in_pair_type;             -- Late ALUs record
    spec_ld     : std_ulogic;                   -- Speculative load operation flag
    rstate      : core_state;                   -- Core state
    rasi        : nv_ras_in_type;               -- Speculative RAS record
    trig        : trig_type;                    -- Trigger on instruction
    int         : lanes_type;                   -- Interrupt on instruction
    irqcause    : cause_type;                   -- interrupt cause
  end record;

  -- Exception Stage <-> Write Back Stage -------------------------------------
  type writeback_reg_type is record
    ctrl          : pipeline_ctrl_lanes_type;       -- Pipeline control record
    csr           : csr_type;                       -- CSR information
    wdata         : wordx_lanes_type;               -- Write back data to register file
    wcsr          : wordx_lanes_type;               -- Write back data to CSR
    fpuflags      : std_logic_vector(4 downto 0);   -- FPU flags
    lalu          : lanes_type;                     -- Late ALUs flag
    flushall      : std_ulogic;                     -- Flushall instructions flag
    csr_pipeflush : std_ulogic;                     -- Pipeline flush due to CSR instructions flag
    csr_addrflush : std_ulogic;                     -- Address flush due to CSR instructions flag
    fence_flush   : std_ulogic;                     -- Flush due to fence instructions flag
    swap          : std_ulogic;                     -- Instrutions are swapped
    nextpc0       : pctype;                         -- Stored following pc for fence
    rasi          : nv_ras_in_type;                 -- Speculative RAS record
    prv           : priv_lvl_type;                  -- Only used for instruction trace printout
    v             : std_ulogic;                     -- Only used for instruction trace printout
    bht_bhistory  : std_logic_vector(4 downto 0);   -- BHT bhistory input
    bht_phistory  : std_logic_vector(63 downto 0);  -- BHT phistory input
    trap_taken    : lanes_type;                     -- Used for debug printing
    icnt          : std_logic_vector(1 downto 0);   -- instruction count event
    unalg_pc      : pctype;                         -- Unaligned PC to write for BTB/BHT
    fpo           : fpu5_out_type;                  -- FPU output, for logging
  end record;

  -- Debug-Module reegister ---------------------------------------------------
  type debugmodule_reg_type is record
    cmdexec     : std_logic_vector(1 downto 0);              -- Command on going
    write       : std_ulogic;                                -- Command write
    size        : std_logic_vector(2 downto 0);              -- Command size
    cmd         : std_logic_vector(1 downto 0);              -- Command
    addr        : std_logic_vector(15 downto 0);             -- Command addr
    havereset   : std_logic_vector(3 downto 0);              -- Have been reset
    tbufcnt     : std_logic_vector(TBUFBITS - 1 downto 0);   -- Trace buffer counter
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
    mmu     : csrtype;  -- Pipelined on the way to MMU/cache controller
    dm      : debugmodule_reg_type;
    evt     : std_logic_vector(0 to 255);   -- 0 not used
    cevt    : std_logic_vector(0 to perf_cnts - 1);
    fpflush : std_logic_vector(4 downto 0);
--pragma translate_off
    -- To give disassembly values that are never affected by the code.
    dis_mcycle     : word64;
    dis_minstret   : word64;
    dis_dual_issue : word64;
--pragma translate_on
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
    v.d.uninst                  := ("00",(others => '0'), "000");
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
    v.e.alui                    := (others => alu_in_none);
    v.e.stdata                  := zerox;
    v.e.accesshold              := (others => '0');
    v.e.exechold                := (others => '0');
    v.e.fpuhold                 := (others => '0');
    v.e.fpu_issued              := '0';
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
    v.m.alui                    := (others => alu_in_none);
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
    v.x.alui                    := (others => alu_in_none);
    v.x.rstate                  := run;
    v.x.rasi                    := nv_ras_in_none;
    v.x.trig                    := trig_none;
    v.x.int                     := (others => '0');
    v.x.spec_ld                 := '0';
    v.x.irqcause                := (others => '0');
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
    v.wb.nextpc0                := PC_ZERO;
    v.wb.rasi                   := nv_ras_in_none;
    v.wb.prv                    := (others => '0');
    v.wb.v                      := '0';
    v.wb.bht_bhistory           := (others => '0');
    v.wb.bht_phistory           := (others => '0');
    v.wb.trap_taken             := (others => '0');
    v.wb.icnt                   := (others => '0');
    -- CSR Regfile
    v.csr                       := CSRRES;
    -- MMU
    v.mmu                       := ((others => '0'), (others => '0'), (others => '0'),
                                    '0', '0', (others => '0'), (others => '0'),
                                    PMPPRECALCRES);
    -- HPM events
    v.evt                       := (others => '0');
    v.cevt                      := (others => '0');
    -- Triggers
    for i in trig_typ_vector'range loop
      v.csr.tcsr.tdata1(i)(XLEN-1 downto XLEN-4) := trig_typ_vector(i);
      v.csr.tcsr.tinfo(i)                        := trig_info_vector(i);
    end loop;
    -- Debug-Module
    v.dm.cmdexec                := (others => '0');
    v.dm.write                  := '0';
    v.dm.size                   := (others => '0');
    v.dm.cmd                    := (others => '0');
    v.dm.addr                   := (others => '0');
    v.dm.havereset              := (others => '1');
    v.dm.tbufcnt                := (others => '0');
    v.dm.tbufaddr               := (others => '0');
    --FPU related
    v.fpflush                   := (others => '0');

    -- For disassembly
--pragma translate_off
    v.dis_mcycle     := (others => '0');
    v.dis_minstret   := (others => '0');
    v.dis_dual_issue := (others => '0');
--pragma translate_on

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

-- pragma translate_off
  -- Signals consumed by the disassembly units.
  signal disas_en       : std_ulogic;
  signal wren           : lanes_type;
  signal wren_f         : lanes_type;
  signal wcen           : lanes_type;
  signal disas_iv       : lanes_type;
  signal way            : word3_lanes_type;
  signal inst           : word_lanes_type;
  signal cinst          : word16_lanes_type;
  signal comp           : lanes_type;
  signal pc             : pc_lanes_type;
  signal wdata          : wordx_lanes_type;
  signal wcsr           : wordx_lanes_type;
  signal trap           : lanes_type;
  signal cause          : cause_lanes_type;
  signal tval           : wordx_lanes_type;
  signal trap_taken     : lanes_type;
-- pragma translate_on



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

  -- Return whether the two functional units are equivalent.
  -- Or rather that they have at least one bit in common.
  function v_fusel_eq(fusel1 : fuseltype; fusel2 : fuseltype) return boolean is
  begin
    return (fusel1 and fusel2) /= NONE;
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

  function csr_addr(inst : word) return csratype is
    variable addr : csratype := inst(31 downto 20);
  begin
    return addr;
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

  function is_sfence_vma(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return opcode = OP_SYSTEM and funct7 = F7_SFENCE_VMA and
           funct3 = "000"     and rd     = "00000";
  end;

  function is_hfence_vvma(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return ext_h /= 0 and
           opcode = OP_SYSTEM and funct7 = F7_HFENCE_VVMA and
           funct3 = "000"     and rd     = "00000";
  end;

  function is_hfence_gvma(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return ext_h /= 0 and
           opcode = OP_SYSTEM and funct7 = F7_HFENCE_GVMA and
           funct3 = "000"     and rd     = "00000";
  end;

  function is_hlv(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return ext_h /= 0 and
           opcode = OP_SYSTEM and funct3 = "100" and funct7(0) = '0';
  end;

  function is_hsv(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct7 : funct7_type := inst(31 downto 25);
  begin
    return ext_h /= 0 and
           opcode = OP_SYSTEM and funct3 = "100" and funct7(0) = '1';
  end;

  function is_hlsv(inst : std_logic_vector) return std_logic is
  begin
    return to_bit(is_hlv(inst) or is_hsv(inst));
  end;

  function is_fence_i(inst : std_logic_vector) return boolean is
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
  begin
    return opcode = OP_FENCE and funct3 = I_FENCE_I;
  end;

  function is_fpu(inst : std_logic_vector) return boolean is
    variable opcode : opcode_type := inst(6 downto  0);
  begin
    case opcode is
      when OP_FP     |
           OP_FMADD  | OP_FMSUB  |
           OP_FNMADD | OP_FNMSUB => return true;
      when others                => return false;
    end case;
  end;

  function is_fpu_mem(inst : std_logic_vector) return boolean is
    variable opcode : opcode_type := inst(6 downto  0);
  begin
    return opcode = OP_STORE_FP or opcode = OP_LOAD_FP;
  end;

  -- FPU instruction with FPU destination register?
  function is_fpu_rd(inst : std_logic_vector) return boolean is
    variable opcode : opcode_type := inst(6 downto  0);
    variable funct5 : funct5_type := inst(31 downto 27);
    variable has_rd : boolean     := is_fpu(inst) or is_fpu_mem(inst);
  begin
    case opcode is
      -- No destination for store.
      when OP_STORE_FP =>
        has_rd     := false;
      when OP_FP =>
        case funct5 is
          -- FPU comparisons leave results in GPRs.
          -- Moves and conversions to GPRs have no FPU destination.
          when R_FCMP | R_FMV_X_W | R_FCVT_W_S =>
            has_rd := false;
          when others =>
            null;
        end case;
      when others =>
        null;
    end case;

    return has_rd;
  end;

  -- FPU instruction gets data from IU?
  function is_fpu_from_int(inst : std_logic_vector) return boolean is
    variable opcode   : opcode_type := inst(6 downto  0);
    variable funct5   : funct5_type := inst(31 downto 27);
    variable from_int : boolean     := false;
  begin
    case opcode is
      when OP_LOAD_FP =>
        from_int     := true;
      when OP_FP =>
        case funct5 is
          when R_FMV_W_X | R_FCVT_S_W =>
            from_int := true;
          when others =>
            null;
        end case;
      when others =>
        null;
    end case;

    return from_int;
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

  function is_csr(inst : std_logic_vector) return boolean is
    variable opcode : opcode_type := inst( 6 downto  0);
    variable funct3 : funct3_type := inst(14 downto 12);
  begin
    return opcode = OP_SYSTEM and funct3(1 downto 0) /= "00";
  end;

  -- Assumes it is already known that inst is a CSR instruction.
  function csr_read_only(inst : std_logic_vector) return boolean is
    variable rfa1   : rfatype     := inst(19 downto 15);
    variable funct3 : funct3_type := inst(14 downto 12);
  begin
    -- CSRR[S/C] and rs1=x0, or CSRR[S/C]I and imm=0, ie read-only?
    return rfa1 = "00000" and
           (funct3 = I_CSRRS  or funct3 = I_CSRRC or
            funct3 = I_CSRRSI or funct3 = I_CSRRCI);
  end;

  -- Assumes it is already known that inst is a CSR instruction.
  function csr_read_only(r : registers; stage : stage_type) return boolean is
    variable c : pipeline_ctrl_type := ctrl(r, stage, csr_lane);
  begin
    return csr_read_only(c.inst);
  end;

  -- Assumes it is already known that inst is a CSR instruction.
  function csr_write_only(inst : std_logic_vector) return boolean is
    variable rd     : rfatype     := inst(11 downto  7);
    variable funct3 : funct3_type := inst(14 downto 12);
  begin
    -- CSRRW/CSRRWI and rd=x0, ie write-only?
    return rd = "00000" and (funct3 = I_CSRRW or funct3 = I_CSRRWI);
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
    return funct3(funct3'high) = '1';
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
    if ext_n = 0 then
      mstatus.uie  := '0';
      mstatus.upie := '0';
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

  -- Generate data address misaligned flag
  function data_addr_misaligned(addr : std_logic_vector;
                                size : word2) return boolean is
    -- Non-constant
    variable naligned : boolean := false;
  begin
    -- Generate not aligned flag.
    case size is
      when SZHALF =>
        if addr(0) /= '0' then
          naligned := true;
        end if;
      when SZWORD =>
        if addr(1 downto 0) /= "00" then
          naligned := true;
        end if;
      when SZDBL =>
        if addr(2 downto 0) /= "000" then
          naligned := true;
        end if;
      when others => -- byte
    end case;

    return naligned;
  end;

  -- Pad or extend pc to XLEN
  function pc2xlen(pc : pctype) return wordx is
    -- Non-constant
    variable data : wordx;
  begin
    data           := (others => pc(pc'high));
    data(pc'range) := pc;

    return data;
  end;

  -- Generate instruction address misaligned flag
  function inst_addr_misaligned(pc : std_logic_vector) return boolean is
    -- Non-constant
    variable naligned : boolean := false;
  begin
    -- Unaligned instruction if compressed instructions are supported!
    if ext_c = 0 then
      if pc(1 downto 0) /= "00" then
        naligned := true;
      end if;
    end if;

    return naligned;
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

  -- Branch and jump generation
  procedure bjump_gen( inst_in       : in  iword_pair_type;
                       buffer_in     : in  iqueue_type;
                       prediction    : in  prediction_array_type;
                       dvalid        : in  std_ulogic;
                       dpc_in        : in  pctype;
                       bjump_buf_out : out std_ulogic;  --bjump is from the buffer
                       bjump_out     : out std_ulogic;  --bjump is taken
                       btb_taken     : out std_ulogic;  --btb was taken
                       btb_taken_buf : out std_ulogic;  --btb was taken for
                                                        --buffer
                       bjump_pos     : out std_logic_vector(3 downto 0);
                       bjump_addr    : out pctype) is   --bjump addr
    variable inst_word       : std_logic_vector(63 downto 0);
    variable br_imm0         : wordx;   --buffer immediate
    variable br_imm1         : wordx;   --cinst[15:0]
    variable br_imm2         : wordx;   --cinst[31:16]
    variable br_imm3         : wordx;   --cinst[47:32]
    variable br_imm4         : wordx;   --cinst[63:48]
    variable br_imm5         : wordx;   --inst[31:0]
    variable br_imm6         : wordx;   --inst[47 downto 16]
    variable br_imm7         : wordx;   --inst[63 downto 32]
    variable j_imm0          : wordx;   --buffer immediate
    variable j_imm1          : wordx;   --cinst[15:0]
    variable j_imm2          : wordx;   --cinst[31:16]
    variable j_imm3          : wordx;   --cinst[47:32]
    variable j_imm4          : wordx;   --cinst[63:48]
    variable j_imm5          : wordx;   --inst[31:0]
    variable j_imm6          : wordx;   --inst[47 downto 16]
    variable j_imm7          : wordx;   --inst[63 downto 32]
    variable mux_imm0        : wordx;
    variable mux_imm1        : wordx;
    variable mux_imm2        : wordx;
    variable mux_imm3        : wordx;
    variable mux_imm4        : wordx;
    variable mux_imm5        : wordx;
    variable mux_imm6        : wordx;
    variable mux_imm7        : wordx;
    variable mux_immf        : wordx;
    variable addlsb0         : std_logic_vector(12 downto 0);
    variable addlsb1         : std_logic_vector(12 downto 0);
    variable addlsb2         : std_logic_vector(12 downto 0);
    variable addlsb3         : std_logic_vector(12 downto 0);
    variable addlsb4         : std_logic_vector(12 downto 0);
    variable addlsb5         : std_logic_vector(12 downto 0);
    variable addlsb6         : std_logic_vector(12 downto 0);
    variable addlsb7         : std_logic_vector(12 downto 0);
    variable addlsbf         : std_logic_vector(12 downto 0);
    variable addlsb0_op1     : std_logic_vector(12 downto 0);
    variable addlsb0_op2     : std_logic_vector(12 downto 0);
    variable addlsb1_op1     : std_logic_vector(12 downto 0);
    variable addlsb1_op2     : std_logic_vector(12 downto 0);
    variable addlsb2_op1     : std_logic_vector(12 downto 0);
    variable addlsb2_op2     : std_logic_vector(12 downto 0);
    variable addlsb3_op1     : std_logic_vector(12 downto 0);
    variable addlsb3_op2     : std_logic_vector(12 downto 0);
    variable addlsb4_op1     : std_logic_vector(12 downto 0);
    variable addlsb4_op2     : std_logic_vector(12 downto 0);
    variable addlsb5_op1     : std_logic_vector(12 downto 0);
    variable addlsb5_op2     : std_logic_vector(12 downto 0);
    variable addlsb6_op1     : std_logic_vector(12 downto 0);
    variable addlsb6_op2     : std_logic_vector(12 downto 0);
    variable addlsb7_op1     : std_logic_vector(12 downto 0);
    variable addlsb7_op2     : std_logic_vector(12 downto 0);
    variable bjump0          : std_logic;
    variable bjump1          : std_logic;
    variable bjump2          : std_logic;
    variable bjump3          : std_logic;
    variable bjump4          : std_logic;
    variable bjump5          : std_logic;
    variable bjump6          : std_logic;
    variable bjump7          : std_logic;
    variable jump0           : std_logic;
    variable jump1           : std_logic;
    variable jump2           : std_logic;
    variable jump3           : std_logic;
    variable jump4           : std_logic;
    variable jump5           : std_logic;
    variable jump6           : std_logic;
    variable jump7           : std_logic;
    variable bj_taken        : std_logic;
    variable addrmsbt        : std_logic_vector(addr_bits - 1 downto 11);
    variable btb_hit         : std_logic_vector(3 downto 0);
    variable btaken          : std_logic_vector(3 downto 0);
    variable bjump_buf_out_v : std_logic;
    variable dpc_in_t        : std_logic_vector(2 downto 0);
  begin

    for i in 0 to 3 loop
      btb_hit(i) := prediction(i).hit;
      btaken(i)  := prediction(i).taken;
    end loop;
    bjump_pos     := (others => '0');
    btb_taken     := '0';
    btb_taken_buf := '0';

    inst_word := inst_in(1).d & inst_in(0).d;

    br_imm0              := (others => buffer_in.inst.d(31));
    br_imm0(11 downto 0) := buffer_in.inst.d(7) & buffer_in.inst.d(30 downto 25) & buffer_in.inst.d(11 downto 8) & '0';
    br_imm1              := (others => inst_word(12));
    br_imm1(7 downto 0)  := inst_word( 6 downto  5) & inst_word( 2) & inst_word(11 downto 10) & inst_word( 4 downto  3) & '0';
    br_imm2              := (others => inst_word(28));
    br_imm2(7 downto 0)  := inst_word(22 downto 21) & inst_word(18) & inst_word(27 downto 26) & inst_word(20 downto 19) & '0';
    br_imm3              := (others => inst_word(44));
    br_imm3(7 downto 0)  := inst_word(38 downto 37) & inst_word(34) & inst_word(43 downto 42) & inst_word(36 downto 35) & '0';
    br_imm4              := (others => inst_word(60));
    br_imm4(7 downto 0)  := inst_word(54 downto 53) & inst_word(50) & inst_word(59 downto 58) & inst_word(52 downto 51) & '0';
    br_imm5              := (others => inst_word(31));
    br_imm5(11 downto 0) := inst_word( 7) & inst_word(30 downto 25) & inst_word(11 downto  8) & '0';
    br_imm6              := (others => inst_word(47));
    br_imm6(11 downto 0) := inst_word(23) & inst_word(46 downto 41) & inst_word(27 downto 24) & '0';
    br_imm7              := (others => inst_word(63));
    br_imm7(11 downto 0) := inst_word(39) & inst_word(62 downto 57) & inst_word(43 downto 40) & '0';


    j_imm0              := (others => buffer_in.inst.d(31));
    j_imm0(19 downto 0) := buffer_in.inst.d(19 downto 12) & buffer_in.inst.d(20) & buffer_in.inst.d(30 downto 21) & '0';
    j_imm1              := (others => inst_word(12));
    j_imm1(10 downto 0) := inst_word( 8) & inst_word(10 downto  9) & inst_word( 6) & inst_word( 7) & inst_word( 2) & inst_word(11) & inst_word( 5 downto  3) & '0';
    j_imm2              := (others => inst_word(28));
    j_imm2(10 downto 0) := inst_word(24) & inst_word(26 downto 25) & inst_word(22) & inst_word(23) & inst_word(18) & inst_word(27) & inst_word(21 downto 19) & '0';
    j_imm3              := (others => inst_word(44));
    j_imm3(10 downto 0) := inst_word(40) & inst_word(42 downto 41) & inst_word(38) & inst_word(39) & inst_word(34) & inst_word(43) & inst_word(37 downto 35) & '0';
    j_imm4              := (others => inst_word(60));
    j_imm4(10 downto 0) := inst_word(56) & inst_word(58 downto 57) & inst_word(54) & inst_word(55) & inst_word(50) & inst_word(59) & inst_word(53 downto 51) & '0';
    j_imm5              := (others => inst_word(31));
    j_imm5(19 downto 0) := inst_word(19 downto 12) & inst_word(20) & inst_word(30 downto 21) & '0';
    j_imm6              := (others => inst_word(47));
    j_imm6(19 downto 0) := inst_word(35 downto 28) & inst_word(36) & inst_word(46 downto 37) & '0';
    j_imm7              := (others => inst_word(63));
    j_imm7(19 downto 0) := inst_word(51 downto 44) & inst_word(52) & inst_word(62 downto 53) & '0';


    mux_imm0   := br_imm0;
    if buffer_in.inst.d(2) = '1' then
      mux_imm0 := j_imm0;
    end if;

    mux_imm1   := br_imm1;
    if inst_word(14) = '0' then
      mux_imm1 := j_imm1;
    end if;

    mux_imm2   := br_imm2;
    if inst_word(30) = '0' then
      mux_imm2 := j_imm2;
    end if;

    mux_imm3   := br_imm3;
    if inst_word(46) = '0' then
      mux_imm3 := j_imm3;
    end if;

    mux_imm4   := br_imm4;
    if inst_word(62) = '0' then
      mux_imm4 := j_imm4;
    end if;

    mux_imm5   := br_imm5;
    if inst_word(2) = '1' then
      mux_imm5 := j_imm5;
    end if;

    mux_imm6   := br_imm6;
    if inst_word(18) = '1' then
      mux_imm6 := j_imm6;
    end if;

    mux_imm7   := br_imm7;
    if inst_word(34) = '1' then
      mux_imm7 := j_imm7;
    end if;

    addlsb0_op1   := '0' & buffer_in.pc(11 downto 0);
    addlsb0_op2   := '0' & mux_imm0(11 downto 0);
    addlsb0       := uadd(addlsb0_op1, addlsb0_op2);
    addlsb1_op1   := '0' & dpc_in(11 downto 3) & "000";
    if single_issue /= 0 then
      addlsb1_op1 := '0' & dpc_in(11 downto 2) & "00";
    end if;
    addlsb1_op2   := '0' & mux_imm1(11 downto 0);
    addlsb1       := uadd(addlsb1_op1, addlsb1_op2);
    addlsb2_op1   := '0' & dpc_in(11 downto 3) & "010";
    if single_issue /= 0 then
      addlsb2_op1 := '0' & dpc_in(11 downto 2) & "10";
    end if;
    addlsb2_op2   := '0' & mux_imm2(11 downto 0);
    addlsb2       := uadd(addlsb2_op1, addlsb2_op2);
    addlsb3_op1   := '0' & dpc_in(11 downto 3) & "100";
    addlsb3_op2   := '0' & mux_imm3(11 downto 0);
    addlsb3       := uadd(addlsb3_op1, addlsb3_op2);
    addlsb4_op1   := '0' & dpc_in(11 downto 3) & "110";
    addlsb4_op2   := '0' & mux_imm4(11 downto 0);
    addlsb4       := uadd(addlsb4_op1, addlsb4_op2);
    addlsb5_op1   := '0' & dpc_in(11 downto 3) & "000";
    if single_issue /= 0 then
      addlsb5_op1 := '0' & dpc_in(11 downto 2) & "00";
    end if;
    addlsb5_op2   := '0' & mux_imm5(11 downto 0);
    addlsb5       := uadd(addlsb5_op1, addlsb5_op2);
    addlsb6_op1   := '0' & dpc_in(11 downto 3) & "010";
    addlsb6_op2   := '0' & mux_imm6(11 downto 0);
    addlsb6       := uadd(addlsb6_op1, addlsb6_op2);
    addlsb7_op1   := '0' & dpc_in(11 downto 3) & "100";
    addlsb7_op2   := '0' & mux_imm7(11 downto 0);
    addlsb7       := uadd(addlsb7_op1, addlsb7_op2);

    bjump1 := '0';
    bjump2 := '0';
    bjump3 := '0';
    bjump4 := '0';
    bjump5 := '0';
    bjump6 := '0';
    bjump7 := '0';
    jump0  := '0';
    jump1  := '0';
    jump2  := '0';
    jump3  := '0';
    jump4  := '0';
    jump5  := '0';
    jump6  := '0';
    jump7  := '0';

    if (inst_word(15 downto 13) = "001" and XLEN = 32) or inst_word(15 downto 13) = "101" or
       inst_word(15 downto 13) = "110" or inst_word(15 downto 13) = "111" then
      if inst_word(0) = '1' then
        bjump1 := '1';
      end if;
    end if;

    if (inst_word(15 downto 13) = "001" and XLEN = 32) or inst_word(15 downto 13) = "101" then
      jump1 := '1';
    end if;


    if (inst_word(31 downto 29) = "001" and XLEN = 32) or inst_word(31 downto 29) = "101" or
       inst_word(31 downto 29) = "110" or inst_word(31 downto 29) = "111" then
      if inst_word(16) = '1' then
        bjump2 := '1';
      end if;
    end if;

    if (inst_word(31 downto 29) = "001" and XLEN = 32) or inst_word(31 downto 29) = "101" then
      jump2 := '1';
    end if;

    if (inst_word(47 downto 45) = "001" and XLEN = 32) or inst_word(47 downto 45) = "101" or
       inst_word(47 downto 45) = "110" or inst_word(47 downto 45) = "111" then
      if inst_word(32) = '1' then
        bjump3 := '1';
      end if;
    end if;

    if (inst_word(47 downto 45) = "001" and XLEN = 32) or inst_word(47 downto 45) = "101" then
      jump3 := '1';
    end if;

    if (inst_word(63 downto 61) = "001" and XLEN = 32) or inst_word(63 downto 61) = "101" or
       inst_word(63 downto 61) = "110" or inst_word(63 downto 61) = "111" then
      if inst_word(48) = '1' then
        bjump4 := '1';
      end if;
    end if;

    if (inst_word(63 downto 61) = "001" and XLEN = 32) or inst_word(63 downto 61) = "101" then
      jump4 := '1';
    end if;

    if inst_word(6 downto 5) = "11" and (inst_word(4 downto 2) = "000" or inst_word(4 downto 2) = "011") then
      bjump5 := '1';
      if inst_word(3) = '1' then
        jump5 := '1';
      end if;
    end if;

    if inst_word(22 downto 21) = "11" and (inst_word(20 downto 18) = "000" or inst_word(20 downto 18) = "011") then
      bjump6 := '1';
      if inst_word(19) = '1' then
        jump6 := '1';
      end if;
    end if;

    if inst_word(38 downto 37) = "11" and (inst_word(36 downto 34) = "000" or inst_word(36 downto 34) = "011") then
      bjump7 := '1';
      if inst_word(35) = '1' then
        jump7 := '1';
      end if;
    end if;

    addlsbf         := addlsb0;
    mux_immf        := mux_imm0;
    bj_taken        := '0';
    bjump_buf_out_v := '0';
    dpc_in_t(2 downto 1) := dpc_in(2 downto 1);
    if single_issue /= 0 then
      dpc_in_t(2)   := '0';
    end if;
    if buffer_in.valid = '1' and buffer_in.prediction.taken = '1' and buffer_in.bjump = '1' and buffer_in.bjump_predicted = '0' then
      --buffer always containt the olders instruction
      addlsbf  := addlsb0;
      mux_immf := mux_imm0;
      if buffer_in.prediction.hit = '0' then
        bj_taken        := '1';
        bjump_buf_out_v := '1';
      else
        btb_taken       := '1';
        btb_taken_buf   := '1';
      end if;
    elsif dvalid = '1' then
      case dpc_in_t(2 downto 1) is
        when "00" =>
          -- Not Compressed instruction in [31:0]
          if inst_word(1 downto 0) = "11" then
            if bjump5 = '1' and (btaken(0) = '1' or jump5 = '1') then
              addlsbf      := addlsb5;
              mux_immf     := mux_imm5;
              if btb_hit(0) = '0' then
                bj_taken   := '1';
              else
                btb_taken  := '1';
              end if;
              bjump_pos(0) := '1';
            else
              if inst_word(33 downto 32) = "11" then
                -- Not Compressed instruction in [63:32]
                if bjump7 = '1' and (btaken(2) = '1' or jump7 = '1') and single_issue = 0 then
                  addlsbf      := addlsb7;
                  mux_immf     := mux_imm7;
                  if btb_hit(2) = '0' then
                    bj_taken   := '1';
                  else
                    btb_taken  := '1';
                  end if;
                  bjump_pos(2) := '1';
                end if;
              else
                -- Compressed instruction in [47:32]
                if bjump3 = '1' and (btaken(2) = '1' or jump3 = '1') and single_issue = 0 then
                  addlsbf      := addlsb3;
                  mux_immf     := mux_imm3;
                  if btb_hit(2) = '0' then
                    bj_taken   := '1';
                  else
                    btb_taken  := '1';
                  end if;
                  bjump_pos(2) := '1';
                elsif inst_word(49 downto 48) /= "11" then
                  -- Compressed instruction in [63:48]
                  if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') and single_issue = 0 then
                    addlsbf      := addlsb4;
                    mux_immf     := mux_imm4;
                    if btb_hit(3) = '0' then
                      bj_taken   := '1';
                    else
                      btb_taken  := '1';
                    end if;
                    bjump_pos(3) := '1';
                  end if;
                end if;
              end if;  -- inst_word(33 downto 32) = "11" then
            end if;  -- bjump5 = '1' and btb_hit(0) = '0' and btaken(0) = '1'
          else
            -- Compressed instruction in [16:0]
            if bjump1 = '1' and (btaken(0) = '1' or jump1 = '1') then
              addlsbf      := addlsb1;
              mux_immf     := mux_imm1;
              if btb_hit(0) = '0' then
                bj_taken   := '1';
              else
                btb_taken  := '1';
              end if;
              bjump_pos(0) := '1';
            else
              if inst_word(17 downto 16) = "11" then
                -- Not compressed instruction in [47:16]
                if bjump6 = '1' and (btaken(1) = '1' or jump6 = '1') and single_issue = 0 then
                  addlsbf      := addlsb6;
                  mux_immf     := mux_imm6;
                  if btb_hit(1) = '0' then
                    bj_taken   := '1';
                  else
                    btb_taken  := '1';
                  end if;
                  bjump_pos(1) := '1';
                elsif inst_word(49 downto 48) /= "11" then
                  -- Compressed instruction in [63:48]
                  if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') and single_issue = 0 then
                    addlsbf      := addlsb4;
                    mux_immf     := mux_imm4;
                    if btb_hit(3) = '0' then
                      bj_taken   := '1';
                    else
                      btb_taken  := '1';
                    end if;
                    bjump_pos(3) := '1';
                  end if;
                end if;
              else
                -- Compressed instruction in [32:16]
                if bjump2 = '1'and (btaken(1) = '1' or jump2 = '1') and single_issue = 0 then
                  addlsbf      := addlsb2;
                  mux_immf     := mux_imm2;
                  if btb_hit(1) = '0' then
                    bj_taken   := '1';
                  else
                    btb_taken  := '1';
                  end if;
                  bjump_pos(1) := '1';
                else
                  if inst_word(33 downto 32) = "11" then
                    -- Not Compressed instruction in [63:32]
                    if bjump7 = '1' and btaken(2) = '1' and single_issue = 0 then
                      addlsbf      := addlsb7;
                      mux_immf     := mux_imm7;
                      if btb_hit(2) = '0' then
                        bj_taken   := '1';
                      else
                        btb_taken  := '1';
                      end if;
                      bjump_pos(2) := '1';
                    end if;
                  else
                    -- Compressed instruction in [47:32]
                    if bjump3 = '1' and (btaken(2) = '1' or jump3 = '1') and single_issue = 0 then
                      addlsbf      := addlsb3;
                      mux_immf     := mux_imm3;
                      if btb_hit(2) = '0' then
                        bj_taken   := '1';
                      else
                        btb_taken  := '1';
                      end if;
                      bjump_pos(2) := '1';
                    elsif inst_word(49 downto 48) /= "11" then
                      -- Compressed instruction in [63:48]
                      if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') and single_issue = 0 then
                        addlsbf      := addlsb4;
                        mux_immf     := mux_imm4;
                        if btb_hit(3) = '0' then
                          bj_taken   := '1';
                        else
                          btb_taken  := '1';
                        end if;
                        bjump_pos(3) := '1';
                      end if;
                    end if;
                  end if;
                end if;
              end if;  -- inst_word(17 downto 16) = "11" then
            end if;  -- bjump1 = '1' and btb_hit(0) = '0' and btaken(0) = '1'
          end if;  -- inst_word(1 downto 0) = "11" then                     --
        when "01" =>
          if inst_word(17 downto 16) = "11" then
            -- Not compressed instruction in [47:16]
            if bjump6 = '1' and (btaken(1) = '1' or jump6 = '1') and single_issue = 0 then
              addlsbf      := addlsb6;
              mux_immf     := mux_imm6;
              if btb_hit(1) = '0' then
                bj_taken   := '1';
              else
                btb_taken  := '1';
              end if;
              bjump_pos(1) := '1';
            elsif inst_word(49 downto 48) /= "11" then
              -- Compressed instruction in [63:48]
              if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') and single_issue = 0 then
                addlsbf      := addlsb4;
                mux_immf     := mux_imm4;
                if btb_hit(3) = '0' then
                  bj_taken   := '1';
                else
                  btb_taken  := '1';
                end if;
                bjump_pos(3) := '1';
              end if;
            end if;
          else
            -- Compressed instruction in [32:16]
            if bjump2 = '1' and (btaken(1) = '1' or jump2 = '1') then
              addlsbf      := addlsb2;
              mux_immf     := mux_imm2;
              if btb_hit(1) = '0' then
                bj_taken   := '1';
              else
                btb_taken  := '1';
              end if;
              bjump_pos(1) := '1';
            else
              if single_issue = 0 then
                if inst_word(33 downto 32) = "11" then
                  -- Not compressed instruction in [63:32]
                  if bjump7 = '1' and (btaken(2) = '1' or jump7 = '1') and single_issue = 0 then
                    addlsbf      := addlsb7;
                    mux_immf     := mux_imm7;
                    if btb_hit(2) = '0' then
                      bj_taken   := '1';
                    else
                      btb_taken  := '1';
                    end if;
                    bjump_pos(2) := '1';
                  end if;
                else
                  -- Compressed instruction in [47:32]
                  if bjump3 = '1' and (btaken(2) = '1' or jump3 = '1') and single_issue = 0 then
                    addlsbf      := addlsb3;
                    mux_immf     := mux_imm3;
                    if btb_hit(2) = '0' then
                      bj_taken   := '1';
                    else
                      btb_taken  := '1';
                    end if;
                    bjump_pos(2) := '1';
                  elsif inst_word(49 downto 48) /= "11" then
                    -- Compressed instruction in [63:48]
                    if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') and single_issue = 0 then
                      addlsbf      := addlsb4;
                      mux_immf     := mux_imm4;
                      if btb_hit(3) = '0' then
                        bj_taken   := '1';
                      else
                        btb_taken  := '1';
                      end if;
                      bjump_pos(3) := '1';
                    end if;
                  end if;
                end if;
              end if;
            end if;  -- bjump2 = '1' and btb_hit(1) = '0' and btaken(1) = '1' then
          end if;  -- inst_word(17 downto 16) = "11" then
        when "10" =>
          if single_issue = 0 then
            if inst_word(33 downto 32) = "11" then
              -- Not compressed instruction in [63:32]
              if bjump7 = '1' and (btaken(2) = '1' or jump7 = '1') then
                addlsbf      := addlsb7;
                mux_immf     := mux_imm7;
                if btb_hit(2) = '0' then
                  bj_taken   := '1';
                else
                  btb_taken  := '1';
                end if;
                bjump_pos(2) := '1';
              end if;
            else
              -- Comressed instruction in [47:32]
              if bjump3 = '1' and (btaken(2) = '1' or jump3 = '1') then
                addlsbf      := addlsb3;
                mux_immf     := mux_imm3;
                if btb_hit(2) = '0' then
                  bj_taken   := '1';
                else
                  btb_taken  := '1';
                end if;
                bjump_pos(2) := '1';
              elsif inst_word(49 downto 48) /= "11" then
                -- Compressed instruction in [63:48]
                if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') then
                  addlsbf      := addlsb4;
                  mux_immf     := mux_imm4;
                  if btb_hit(3) = '0' then
                    bj_taken   := '1';
                  else
                    btb_taken  := '1';
                  end if;
                  bjump_pos(3) := '1';
                end if;
              end if;
            end if;  -- inst_word(34 downto 33) = "11"
          else
            null;
          end if;  -- single_issue = 0
        when "11" =>
          if single_issue = 0 then
            if inst_word(49 downto 48) /= "11" then
              -- Compressed instruction in [63:48]
              if bjump4 = '1' and (btaken(3) = '1' or jump4 = '1') then
                addlsbf      := addlsb4;
                mux_immf     := mux_imm4;
                if btb_hit(3) = '0' then
                  bj_taken   := '1';
                else
                  btb_taken  := '1';
                end if;
                bjump_pos(3) := '1';
              end if;
            end if;
          else
            null;
          end if;  -- single_issue = 0
        when others =>
          null;
      end case;
    end if;

    addrmsbt := uadd(dpc_in(addr_bits - 1 downto 12) & '1', mux_immf(addr_bits - 1 downto 12) & addlsbf(12));
    if bjump_buf_out_v = '1' then
      addrmsbt := uadd(buffer_in.pc(addr_bits - 1 downto 12) & '1', mux_immf(addr_bits - 1 downto 12) & addlsbf(12));
    end if;
    bjump_addr    := addrmsbt(addr_bits - 1 downto 12) & addlsbf(11 downto 0);
    bjump_out     := bj_taken;
    bjump_buf_out := bjump_buf_out_v;
  end;

  procedure rvc_expander(inst_in  : in  word16;
                         inst_out : out word;
                         xc_out   : out std_ulogic) is
    -- Evaluate compressed instruction
    variable op     : word2                         := inst_in(1 downto 0);
    variable funct3 : funct3_type                   := inst_in(15 downto 13);
    -- Evaluate imm sign-extension, MSB of imm is always bit 12th.
    variable imm12  : std_logic_vector(11 downto 0) := (others => inst_in(12));
    variable rfa1   : rfatype                       := inst_in(11 downto 7);
    variable rfa2   : rfatype                       := inst_in(6 downto 2);
    variable rd     : rfatype                       := inst_in(11 downto 7);
    variable rfa1c  : rfatype                       := "01" & inst_in(9 downto 7);
    variable rfa2c  : rfatype                       := "01" & inst_in(4 downto 2);
    variable rdc    : rfatype                       := "01" & inst_in(4 downto 2);
    -- Non-constant
    variable inst   : word;
    variable xc     : std_ulogic                    := '0';
  begin

    inst := "00" &                   -- imm[11:10]
            inst_in(10 downto 7) &   -- imm[9:6]
            inst_in(12 downto 11) &  -- imm[5:4]
            inst_in(5) &             -- imm[3]
            inst_in(6) &             -- imm[2]
            "00" &                   -- imm[1:0]
            GPR_SP &                 -- rs1
            I_ADDI &                 -- funct3
            rdc &                    -- rd
            OP_IMM;                  -- addi

    -- Expand instruction
    case op is

      -- C0
      when "00" =>
        case funct3 is

          -- c.addi4spn -> addi rd', x2, imm
          when "000" =>
            inst := "00" &                   -- imm[11:10]
                    inst_in(10 downto 7) &   -- imm[9:6]
                    inst_in(12 downto 11) &  -- imm[5:4]
                    inst_in(5) &             -- imm[3]
                    inst_in(6) &             -- imm[2]
                    "00" &                   -- imm[1:0]
                    GPR_SP &                 -- rs1
                    I_ADDI &                 -- funct3
                    rdc &                    -- rd
                    OP_IMM;                  -- addi
            -- imm = 0 are reserved by the standard.
            if inst_in(12 downto 5) = "00000000" then
              xc := '1';
            end if;

            -- c.fld -> fld rd', imm(rs1')
          when "001" =>
              inst := "0000" &                 -- imm[11:8]
                      inst_in(6 downto 5) &    -- imm[7:6]
                      inst_in(12 downto 10) &  -- imm[5:3]
                      "000" &                  -- imm[2:0]
                      rfa1c &                  -- rs1
                      I_FLD &                  -- funct3
                      rdc &                    -- rd
                      OP_LOAD_FP;              -- fld
            if ext_d = 0 then
              xc := '1';
            end if;

            -- c.lw -> lw rd', imm(rs1')
          when "010" =>
            inst := "00000" &                -- imm[11:7]
                    inst_in(5) &             -- imm[6]
                    inst_in(12 downto 10) &  -- imm[5:3]
                    inst_in(6) &             -- imm[2]
                    "00" &                   -- imm[1:0]
                    rfa1c &                  -- rs1
                    I_LW &                   -- funct3
                    rdc &                    -- rd
                    OP_LOAD;                 -- addi

            -- c.flw
            -- c.ld
          when "011" =>
            -- c.flw -> flw rd', imm(rs1')
            if is_rv32 and ext_f = 1 then
              inst := "00000" &                -- imm[11:7]
                      inst_in(5) &             -- imm[6]
                      inst_in(12 downto 10) &  -- imm[5:3]
                      inst_in(6) &             -- imm[2]
                      "00" &                   -- imm[1:0]
                      rfa1c &                  -- rs1
                      I_FLW &                  -- funct3
                      rdc &                    -- rd
                      OP_LOAD_FP;              -- flw
              -- c.ld -> ld rd', imm(rs1')
            elsif is_rv64 then
              inst := "0000" &                 -- imm[11:8]
                      inst_in(6 downto 5) &    -- imm[7:6]
                      inst_in(12 downto 10) &  -- imm[5:3]
                      "000" &                  -- imm[2:0]
                      rfa1c &                  -- rs1
                      I_LD &                   -- funct3
                      rdc &                    -- rd
                      OP_LOAD;                 -- ld
            else
              xc := '1';
            end if;

            -- c.fsd -> fsd rs2', imm(rs1')
          when "101" =>
            if ext_d = 1 then
              inst := "0000" &                 -- imm[11:8]
                      inst_in(6 downto 5) &    -- imm[7:6]
                      inst_in(12) &            -- imm[5]
                      rfa2c &                  -- rs2
                      rfa1c &                  -- rs1
                      S_FSD &                  -- funct3
                      inst_in(11 downto 10) &  -- imm[4:3]
                      "000" &                  -- imm[2:0]
                      OP_STORE_FP;             -- fsd
            else
              xc := '1';
            end if;

            -- c.sw -> sw rs2', imm(rs1')
          when "110" =>
            inst := "00000" &                -- imm[11:7]
                    inst_in(5) &             -- imm[6]
                    inst_in(12) &            -- imm[5]
                    rfa2c &                  -- rs2
                    rfa1c &                  -- rs1
                    S_SW &                   -- funct3
                    inst_in(11 downto 10) &  -- imm[4:3]
                    inst_in(6) &             -- imm[2]
                    "00" &                   -- imm[1:0]
                    OP_STORE;                -- sw

            -- c.fsw
            -- c.sd
          when "111" =>
            -- c.fsw -> fsw rs2', imm(rs1')
            if is_rv32 and ext_f = 1 then
              inst := "00000" &                -- imm[11:7]
                      inst_in(5) &             -- imm[6]
                      inst_in(12) &            -- imm[5]
                      rfa2c &                  -- rs2
                      rfa1c &                  -- rs1
                      S_FSW &                  -- funct3
                      inst_in(11 downto 10) &  -- imm[4:3]
                      inst_in(6) &             -- imm[2]
                      "00" &                   -- imm[1:0]
                      OP_STORE_FP;             -- sw
              -- c.sd -> sd rs2', imm(rs1')
            elsif is_rv64 then
              inst := "0000" &                 -- imm[11:8]
                      inst_in(6 downto 5) &    -- imm[7:6]
                      inst_in(12) &            -- imm[5]
                      rfa2c &                  -- rs2
                      rfa1c &                  -- rs1
                      S_SD &                   -- funct3
                      inst_in(11 downto 10) &  -- imm[4:3]
                      "000" &                  -- imm[2:0]
                      OP_STORE;                -- sw
            else
              xc := '1';
            end if;

            -- 100 -> illegal instruction
          when others =>
            xc := '1';

        end case;  -- funct3

        -- C1
      when "01" =>
        case funct3 is

          -- c.nop -> addi x0, x0, 0
          -- c.addi -> addi rd, rd, imm
          when "000" =>
            inst := imm12(11 downto 6) &   -- imm[11:6]
                    inst_in(12) &          -- imm[5]
                    inst_in(6 downto 2) &  -- imm[4:0]
                    rfa1 &                 -- rs1
                    I_ADDI &               -- funct3
                    rd &                   -- rd
                    OP_IMM;                -- addi
            -- For the c.nop case, imm /= 0 are standard HINTs.
            -- For the c.addi case, imm = 0 are standard HINTs.

            -- c.jal
            -- c.addiw
          when "001" =>
            if is_rv32 then
              -- c.jal -> jal x1, imm
              inst := inst_in(12) &           -- imm[20]
                      inst_in(8) &            -- imm[10]
                      inst_in(10 downto 9) &  -- imm[9:8]
                      inst_in(6) &            -- imm[7]
                      inst_in(7) &            -- imm[6]
                      inst_in(2) &            -- imm[5]
                      inst_in(11) &           -- imm[4]
                      inst_in(5 downto 3) &   -- imm[3:1]
                      inst_in(12) &           -- imm[11]
                      imm12(11 downto 4) &    -- imm[19:12]
                      GPR_RA &                -- rd
                      OP_JAL;                 -- jal
            else
              -- c.addiw -> addiw rd, rd, imm
              inst := imm12(11 downto 6) &    -- imm[11:6]
                      inst_in(12) &           -- imm[5]
                      inst_in(6 downto 2) &   -- imm[4:0]
                      rfa1 &                  -- rs1
                      I_ADDI &                -- funct3
                      rd &                    -- rd
                      OP_IMM_32;              -- addi
              -- rd = x0 are reserved by the standard.
              if rd = "00000" then
                xc := '1';
              end if;
            end if;

            -- c.li -> addi rd, x0, imm
          when "010" =>
            inst := imm12(11 downto 6) &   -- imm[11:6]
                    inst_in(12) &          -- imm[5]
                    inst_in(6 downto 2) &  -- imm[4:0]
                    GPR_X0 &               -- rs1
                    I_ADDI &               -- funct3
                    rd &                   -- rd
                    OP_IMM;                -- addi
            -- rd = x0 are standard HINTs.

            -- c.addi16sp
            -- c.lui
          when "011" =>
            if rd = GPR_SP then
              -- c.addi16sp -> addi x2, x2, imm
              inst := imm12(11 downto 10) &  -- imm[11:10]
                      inst_in(12) &          -- imm[9]
                      inst_in(4 downto 3) &  -- imm[8:7]
                      inst_in(5) &           -- imm[6]
                      inst_in(2) &           -- imm[5]
                      inst_in(6) &           -- imm[4]
                      "0000" &               -- imm[3:0]
                      GPR_SP &               -- rs1
                      I_ADDI &               -- funct3
                      GPR_SP &               -- rd
                      OP_IMM;                -- addi
            elsif rd /= "00000" then
              -- c.lui -> lui rd, imm
              inst := imm12 &                -- imm[31:20]
                      imm12(11 downto 10) &  -- imm[19:18]
                      inst_in(12) &          -- imm[17]
                      inst_in(6 downto 2) &  -- imm[16:12]
                      rd &                   -- rd
                      LUI;                   -- lui
              -- imm /= 0 are standard HINTs.
            end if;
            -- c.addi16sp and c.lui are reserved with imm = 0.
            if inst_in(12) = '0' and inst_in(6 downto 2) = "00000" then
              xc := '1';
            end if;

            -- ALU
          when "100" =>
            case inst_in(11 downto 10) is

              -- c.srli -> srli rd', rs1', shamt
              -- c.srai -> srai rd', rs1', shamt
              when "00" | "01" =>
                inst := inst_in(11 downto 10) &  -- funct7[6:5]
                        "0000" &                 -- funct7[4:1]
                        inst_in(12) &            -- shamt[5]
                        inst_in(6 downto 2) &    -- shamt[4:0]
                        rfa1c &                  -- rs1
                        I_SRLI &                 -- funct3
                        rfa1c &                  -- rd
                        OP_IMM;                  -- srli/srai
                -- For RV32, the code points with the high bit set
                -- are designated for custom extensions.
                if is_rv32 and inst_in(12) = '1' then
                  xc := '1';
                end if;
                -- shamt = 0 are custom HINTs.

                -- c.andi -> andi rd', rs1', imm
              when "10" =>
                inst := imm12(11 downto 6) &   -- imm[11:6]
                        inst_in(12) &          -- imm[5]
                        inst_in(6 downto 2) &  -- imm[4:0]
                        rfa1c &                -- rs1
                        I_ANDI &               -- funct3
                        rfa1c &                -- rd
                        OP_IMM;                -- andi

                -- misc
              when "11" =>
                case inst_in(6 downto 5) is

                  -- c.sub[w] -> sub[w] rd', rs1', rs2'
                  when "00" =>
                    inst := F7_SUB &    -- funct7
                            rfa2c &     -- rs2
                            rfa1c &     -- rs1
                            R_SUB &     -- funct3
                            rfa1c &     -- rd
                            OP_REG;     -- sub
                    if inst_in(12) = '1' then
                      if is_rv64 then
                        inst(6 downto 0) := OP_32;
                      else
                        xc := '1';
                      end if;
                    end if;

                    -- c.xor -> xor rd', rs1', rs2'
                    -- c.addw -> addw rd', rs1', rs2'
                  when "01" =>
                    inst := F7_BASE &   -- funct7
                            rfa2c &     -- rs2
                            rfa1c &     -- rs1
                            R_XOR &     -- funct3
                            rfa1c &     -- rd
                            OP_REG;     -- sub
                    if inst_in(12) = '1' then
                      if is_rv64 then
                        inst(14 downto 12) := R_ADDW;
                        inst(6 downto 0)   := OP_32;
                      else
                        xc := '1';
                      end if;
                    end if;

                    -- c.or -> or rd', rs1', rs2'
                  when "10" =>
                    inst := F7_BASE &   -- funct7
                            rfa2c &     -- rs2
                            rfa1c &     -- rs1
                            R_OR &      -- funct3
                            rfa1c &     -- rd
                            OP_REG;     -- or
                    if inst_in(12) = '1' then
                      xc := '1';
                    end if;

                    -- c.and -> and rd', rs1', rs2'
                  when "11" =>
                    inst := F7_BASE &   -- funct7
                            rfa2c &     -- rs2
                            rfa1c &     -- rs1
                            R_AND &     -- funct3
                            rfa1c &     -- rd
                            OP_REG;     -- and
                    if inst_in(12) = '1' then
                      xc := '1';
                    end if;

                  when others =>
                    xc := '1';

                end case;  -- inst_in(6 downto 5)

              when others =>
                xc := '1';

            end case;  -- inst_in(11 downto 10)

            -- c.j -> jal x0, imm
          when "101" =>
            inst := inst_in(12) &           -- imm[20]
                    inst_in(8) &            -- imm[10]
                    inst_in(10 downto 9) &  -- imm[9:8]
                    inst_in(6) &            -- imm[7]
                    inst_in(7) &            -- imm[6]
                    inst_in(2) &            -- imm[5]
                    inst_in(11) &           -- imm[4]
                    inst_in(5 downto 3) &   -- imm[3:1]
                    inst_in(12) &           -- imm[11]
                    imm12(11 downto 4) &    -- imm[19:12]
                    GPR_X0 &                -- rd
                    OP_JAL;                 -- jal

            -- c.beqz -> beq rs1', x0, imm
            -- c.bnez -> bne rs1', x0, imm
          when "110" | "111" =>
            inst := inst_in(12) &            -- imm[12]
                    imm12(10 downto 9) &     -- imm[10:9]
                    inst_in(12) &            -- imm[8]
                    inst_in(6 downto 5) &    -- imm[7:6]
                    inst_in(2) &             -- imm[5]
                    GPR_X0 &                 -- rs2
                    rfa1c &                  -- rs1
                    "00" & inst_in(13) &     -- funct3
                    inst_in(11 downto 10) &  -- imm[4:3]
                    inst_in(4 downto 3) &    -- imm[2:1]
                    inst_in(12) &            -- imm[11]
                    OP_BRANCH;               -- branch

          when others =>
            xc := '1';

        end case;  -- inst_in(11 downto 10)

        -- C2
      when "10" =>
        case funct3 is

          -- c.slli -> slli rd, rs1, shamt
          when "000" =>
            inst := "000000" &             -- funct7[6:1]
                    inst_in(12) &          -- shamt[5]
                    inst_in(6 downto 2) &  -- shamt[4:0]
                    rfa1 &                 -- rs1
                    I_SLLI &               -- funct3
                    rd &                   -- rd
                    OP_IMM;                -- slli
            -- For RV32, the code points with the high bit set
            -- are designated for custom extensions.
            if is_rv32 and inst_in(12) = '1' then
              xc := '1';
            end if;
            -- rd = x0 are custom HINTs (except as above).

            -- c.fldsp -> fld rd, imm(x2)
          when "001" =>
            inst := "000" &                -- imm[11:9]
                    inst_in(4 downto 2) &  -- imm[8:6]
                    inst_in(12) &          -- imm[5]
                    inst_in(6 downto 5) &  -- imm[4:3]
                    "000" &                -- imm[2:0]
                    GPR_SP &               -- rs1
                    I_LD &                 -- funct3
                    rd &                   -- rd
                    OP_LOAD_FP;            -- fld
            if ext_d = 0 then
              xc := '1';
            end if;

            -- c.lwsp -> lw rd, imm(x2)
          when "010" =>
            inst := "0000" &               -- imm[11:8]
                    inst_in(3 downto 2) &  -- imm[7:6]
                    inst_in(12) &          -- imm[5]
                    inst_in(6 downto 4) &  -- imm[4:2]
                    "00" &                 -- imm[1:0]
                    GPR_SP &               -- rs1
                    I_LW &                 -- funct3
                    rd &                   -- rd
                    OP_LOAD;               -- ld
            -- rd = x0 are reserved by the standard.
            if rd = "00000" then
              xc := '1';
            end if;

            -- c.flwsp
            -- c.ldsp
          when "011" =>
            -- c.flwsp -> flw rd, imm(x2)
            if is_rv32 then
              inst := "0000" &               -- imm[11:8]
                      inst_in(3 downto 2) &  -- imm[7:6]
                      inst_in(12) &          -- imm[5]
                      inst_in(6 downto 4) &  -- imm[4:2]
                      "00" &                 -- imm[1:0]
                      GPR_SP &               -- rs1
                      I_FLW &                -- funct3
                      rd &                   -- rd
                      OP_LOAD_FP;            -- flw
              -- c.ldsp -> ld rd, imm(x2)
            else
              inst := "000" &                -- imm[11:9]
                      inst_in(4 downto 2) &  -- imm[8:6]
                      inst_in(12) &          -- imm[5]
                      inst_in(6 downto 5) &  -- imm[4:3]
                      "000" &                -- imm[2:0]
                      GPR_SP &               -- rs1
                      I_LD &                 -- funct3
                      rd &                   -- rd
                      OP_LOAD;               -- ld
              -- rd = x0 are reserved by the standard.
              if rd = "00000" then
                xc := '1';
              end if;
            end if;

            -- misc
          when "100" =>

            if inst_in(12) = '0' then
              -- c.jr -> jalr x0, 0(rs1)
              if rfa2 = "00000" then
                inst := imm12 &         -- imm[11:0]
                        rfa1 &          -- rs1
                        I_JALR &        -- funct3
                        GPR_X0 &        -- rd
                        OP_JALR;        -- jalr
                -- rs1 = x0 are reserved by the standard.
                if rfa1 = "00000" then
                  xc := '1';
                end if;
              -- c.mv -> add rd, x0, rs2
              else
                inst := F7_BASE &       -- funct7
                        rfa2 &          -- rs2
                        GPR_X0 &        -- rs1
                        R_ADD &         -- funct3
                        rd &            -- rd
                        OP_REG;         -- add
                -- rd = x0 are standard HINTs.
              end if;

            else

              if rfa2 = "00000" then

                -- c.ebreak -> ebreak
                if rd = "00000" then
                  inst             := (others => '0');
                  inst(20)         := '1';
                  inst(6 downto 0) := OP_SYSTEM;
                  -- c.jalr -> jalr x1, 0(rs1)
                else
                  inst := zerow(11 downto 0) &  -- imm[11:0]
                          rfa1 &                -- rs1
                          I_JALR &              -- funct3
                          GPR_RA &              -- rd
                          OP_JALR;              -- jalr
                end if;  -- rd

                -- c.add -> rd, rs1, rs2
              else
                inst := F7_BASE &       -- funct7
                        rfa2 &          -- rs2
                        rfa1 &          -- rs1
                        R_ADD &         -- funct3
                        rd &            -- rd
                        OP_REG;         -- add
              -- rd = x0 are standard HINTs.
              end if;
            end if;  -- inst_in(12)

            -- c.fsdsp -> fsd rs2, imm(x2)
          when "101" =>
            inst := "000" &                  -- imm[11:9]
                    inst_in(9 downto 7) &    -- imm[8:6]
                    inst_in(12) &            -- imm[5]
                    rfa2 &                   -- rs2
                    GPR_SP &                 -- rs1
                    S_FSD &                  -- funct3
                    inst_in(11 downto 10) &  -- imm[4:3]
                    "000" &                  -- imm[2:0]
                    OP_STORE_FP;             -- fld
            if ext_d = 0 then
              xc := '1';
            end if;

            -- c.swsp -> sw rs2, imm(x2)
          when "110" =>
            inst := "0000" &                -- imm[11:8]
                    inst_in(8 downto 7) &   -- imm[7:6]
                    inst_in(12) &           -- imm[5]
                    rfa2 &                  -- rs2
                    GPR_SP &                -- rs1
                    S_SW &                  -- funct3
                    inst_in(11 downto 9) &  -- imm[4:2]
                    "00" &                  -- imm[1:0]
                    OP_STORE;               -- sw

            -- c.fswsp
            -- c.sdsp
          when "111" =>
            -- c.fswsp -> fsw rs2, imm(x2)
            if is_rv32 and ext_f = 1 then
              inst := "0000" &                 -- imm[11:8]
                      inst_in(8 downto 7) &    -- imm[7:6]
                      inst_in(12) &            -- imm[5]
                      rfa2 &                   -- rs2
                      GPR_SP &                 -- rs1
                      S_FSW &                  -- funct3
                      inst_in(11 downto 9) &   -- imm[4:2]
                      "00" &                   -- imm[1:0]
                      OP_STORE_FP;             -- fsw
              -- c.sdsp -> sd rs2, imm(x2)
            elsif is_rv64 then
              inst := "000" &                  -- imm[11:9]
                      inst_in(9 downto 7) &    -- imm[8:6]
                      inst_in(12) &            -- imm[5]
                      rfa2 &                   -- rs2
                      GPR_SP &                 -- rs1
                      S_SD &                   -- funct3
                      inst_in(11 downto 10) &  -- imm[4:3]
                      "000" &                  -- imm[2:0]
                      OP_STORE;                -- sd
            end if;

          when others =>
            xc := '1';

        end case;  -- funct3

      when others =>
        null;

    end case;  -- op

    inst_out := inst;
    xc_out   := xc;
  end;

  -- Align compressed instruction
  procedure rvc_aligner(inst_in          : in  iword_pair_type;
                        rvc_pc           : in  pctype;
                        valid_in         : in  std_ulogic;
                        inst_out         : out iword_pair_type;
                        comp_ill         : out std_logic_vector(1 downto 0);
                        hold_out         : out std_ulogic;
                        npc_out          : out std_logic_vector;
                        valid_out        : out std_logic_vector;
                        buffer_first_out : out std_logic;  -- buffer first instruction
                        buffer_sec_out   : out std_logic;  -- buffer second instruction
                                                           --  if not issued
                        buffer_third_out : out std_logic;  -- buffer the third instruction
                        buffer_inst      : out iword_type;
                        buff_comp_ill    : out std_logic;
                        unaligned_out    : out std_ulogic) is
    -- Non-constant
    variable inst         : iword_pair_type;
    variable unaligned    : std_ulogic := '0';
    variable hold         : std_ulogic := '0';
    variable npc          : word3      := (others => '0');
    variable valid        : fetch_pair := (others => '0');
    variable buffer_first : std_ulogic;
    variable buffer_sec   : std_ulogic;
    variable buffer_third : std_ulogic;
    variable inst_c0e     : word;
    variable inst_c1e     : word;
    variable inst_c2e     : word;
    variable inst_c3e     : word;
    variable inst_c0xc    : std_ulogic;
    variable inst_c1xc    : std_ulogic;
    variable inst_c2xc    : std_ulogic;
    variable inst_c3xc    : std_ulogic;
    variable rvc_pc_t     : std_logic_vector(2 downto 0);
  begin

    rvc_expander(inst_in(0).d(15 downto 0),
                 inst_c0e,
                 inst_c0xc);
    rvc_expander(inst_in(0).d(31 downto 16),
                 inst_c1e,
                 inst_c1xc);
    if single_issue = 0 then
      rvc_expander(inst_in(1).d(15 downto 0),
                   inst_c2e,
                   inst_c2xc);
      rvc_expander(inst_in(1).d(31 downto 16),
                   inst_c3e,
                   inst_c3xc);
    else
      inst_c2e  := (others => '0');
      inst_c3e  := (others => '0');
      inst_c2xc := '0';
      inst_c3xc := '0';
    end if;

    inst(0).lpc   := "00";
    inst(0).d     := inst_in(0).d;
    inst(0).dc    := inst_in(0).d(15 downto 0);
    inst(0).xc    := "000";
    inst(0).c     := '0';
    inst(1).lpc   := "10";
    inst(1).d     := inst_in(1).d;
    inst(1).dc    := inst_in(1).d(15 downto 0);
    inst(1).xc    := "000";
    inst(1).c     := '0';
    comp_ill      := "00";
    buff_comp_ill := '0';

    buffer_inst.d   := (others => '0');
    buffer_inst.lpc := "00";
    buffer_inst.xc  := "000";
    buffer_inst.c   := '0';
    buffer_first    := '0';
    buffer_sec      := '0';
    buffer_third    := '0';

    rvc_pc_t(2 downto 1) := rvc_pc(2 downto 1);
    if single_issue /= 0 then
      rvc_pc_t(2) := '0';
    end if;
    case rvc_pc_t(2 downto 1) is
      -- Decode at 0x00
      when "00" =>
        -- Not Compressed instruction in 0
        if inst_in(0).d(1 downto 0) = "11" then
          inst(0)     := inst_in(0);
          inst(0).lpc := "00";
          valid(0)    := '1';
          if single_issue /= 0 then
            inst(0).lpc := rvc_pc(2) & '0';
          end if;
          -- Not Compressed instruction in 1
          if single_issue = 0 then
            if inst_in(1).d(1 downto 0) = "11" then
              inst(1)     := inst_in(1);
              inst(1).lpc := "10";
              buffer_sec  := '1';
              valid(1)    := '1';
            -- Compressed instruction in 1
            else
              inst(1).d       := inst_c2e;
              inst(1).dc      := inst_in(1).d(15 downto 0);
              inst(1).lpc     := "10";
              valid(1)        := '1';
              inst(1).c       := '1';
              comp_ill(1)     := inst_c2xc;
              -- Generate unaligned flag
              buffer_inst.lpc := "11";
              if inst_in(1).d(17 downto 16) = "11" then
                buffer_third               := '1';
                buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
                unaligned                  := '1';
              else
                -- One more compressed left, buffer it
                buffer_third   := '1';
                buffer_inst.d  := inst_c3e;
                buffer_inst.dc := inst_in(1).d(31 downto 16);
                buffer_inst.c  := '1';
                buff_comp_ill  := inst_c3xc;
              end if;  -- unaligned flag
            end if;  -- instruction in 1
          end if;  -- single_issue = 0
        -- Compressed instruction in 0
        else
          inst(0).d   := inst_c0e;
          inst(0).dc  := inst_in(0).d(15 downto 0);
          inst(0).c   := '1';
          inst(0).lpc := "00";
          comp_ill(0) := inst_c0xc;
          valid(0)    := '1';
          if single_issue /= 0 then
            hold        := '1';
            inst(0).lpc := rvc_pc(2) & '0';
          end if;
          if single_issue = 0 then
            -- Not Compressed instruction in 0 1/2
            if inst_in(0).d(17 downto 16) = "11" then
              inst(1).d       := inst_in(1).d(15 downto 0) & inst_in(0).d(31 downto 16);
              inst(1).lpc     := "01";
              valid(1)        := '1';
              -- Generate unaligned flag
              buffer_inst.lpc := "11";
              if inst_in(1).d(17 downto 16) = "11" then
                buffer_third               := '1';
                buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
                unaligned                  := '1';
              else
                -- One more compressed left, buffer it
                buffer_third   := '1';
                buffer_inst.d  := inst_c3e;
                buffer_inst.dc := inst_in(1).d(31 downto 16);
                buffer_inst.c  := '1';
                buff_comp_ill  := inst_c3xc;
              end if;  -- unaligned flag

            -- Compressed instruction in 0 1/2
            else
              --inst(1).d(15 downto 0) := inst_in(0).d(31 downto 16);
              inst(1).d   := inst_c1e;
              inst(1).dc  := inst_in(0).d(31 downto 16);
              inst(1).c   := '1';
              inst(1).lpc := "01";
              comp_ill(1) := inst_c1xc;
              valid(1)    := '1';
              -- More valid instructions
              if inst_in(1).d(1 downto 0) = "11" then
                --one 32-bit instruction left buffer it
                buffer_third               := '1';
                buffer_inst.d(31 downto 0) := inst_in(1).d(31 downto 0);
                buffer_inst.lpc            := "10";
              else
                -- Two more valid instructions left
                hold := '1';
                npc  := "100";
              end if;
            end if;  -- instruction in 0 1/2
          end if;  -- single_issue = 0
        end if;  -- instruction in 0

      -- Decode at 0x02
      when "01" =>
        -- Not Compressed instruction in 0 1/2
        if inst_in(0).d(17 downto 16) = "11" then
          inst(0).d       := inst_in(1).d(15 downto 0) & inst_in(0).d(31 downto 16);
          inst(0).lpc     := "01";
          valid(0)        := '1';
          -- Generate unaligned flag
          buffer_inst.lpc := "11";
          if single_issue /= 0 then
            -- Unaligned for single issue
            valid(0)      := '0';
            unaligned     := '1';
            buffer_third  := '1';
            buffer_inst.d(15 downto 0) := inst_in(0).d(31 downto 16);
            buffer_inst.lpc := rvc_pc(2) & '1';
            -- Generate instruction lpc in case it is a mexc on lsb of unaligned instruction.
            inst(0).lpc := rvc_pc(2) & '1';
          end if;
          if single_issue = 0 then
            if inst_in(1).d(17 downto 16) = "11" then
              buffer_third               := '1';
              buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
              unaligned                  := '1';
            else
              buffer_sec  := '1';
              inst(1).d   := inst_c3e;
              inst(1).dc  := inst_in(1).d(31 downto 16);
              inst(1).c   := '1';
              inst(1).lpc := "11";
              comp_ill(1) := inst_c3xc;
              valid(1)    := '1';
            end if;  -- unaligned flag
          end if; -- single_issue = 0
        -- Compressed instruction in 0 1/2
        else
          inst(0).d   := inst_c1e;
          inst(0).dc  := inst_in(0).d(31 downto 16);
          inst(0).c   := '1';
          inst(0).lpc := "01";
          comp_ill(0) := inst_c1xc;
          valid(0)    := '1';
          if single_issue /= 0 then
            inst(0).lpc := rvc_pc(2) & '1';
          end if;
          if single_issue = 0 then
            -- Not Compressed instruction in 1
            if inst_in(1).d(1 downto 0) = "11" then
              buffer_sec  := '1';
              inst(1)     := inst_in(1);
              inst(1).lpc := "10";
              valid(1)    := '1';
            -- Compressed instruction in 1
            else
              inst(1).d       := inst_c2e;
              inst(1).dc      := inst_in(1).d(15 downto 0);
              inst(1).c       := '1';
              inst(1).lpc     := "10";
              comp_ill(1)     := inst_c2xc;
              valid(1)        := '1';
              -- Generate unaligned flag
              buffer_inst.lpc := "11";
              if inst_in(1).d(17 downto 16) = "11" then
                buffer_third               := '1';
                buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
                unaligned                  := '1';
              else
                -- Only one compressed inst left buffer it
                buffer_third  := '1';
                --buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
                buffer_inst.d  := inst_c3e;
                buffer_inst.dc := inst_in(1).d(31 downto 16);
                buffer_inst.c  := '1';
                buff_comp_ill  := inst_c3xc;
              end if;  -- unaligned flag
            end if;  -- instruction in 1
          end if;  -- single_issue = 0
        end if;  -- instruction in 0 1/2

      -- Decode at 0x04
      when "10" =>
        if single_issue = 0 then
          -- Not Compressed instruction in 1
          if inst_in(1).d(1 downto 0) = "11" then
            inst(0)                    := inst_in(1);
            inst(0).lpc                := "10";
            valid(0)                   := '1';
            buffer_first               := '1';
            buffer_inst.d(31 downto 0) := inst_in(1).d(31 downto 0);
            buffer_inst.lpc            := "10";
          -- Compressed instruction in 1
          else
            -- Generate unaligned flag
            if inst_in(1).d(17 downto 16) = "11" then
              inst(0).d                  := inst_c2e;
              inst(0).dc                 := inst_in(1).d(15 downto 0);
              inst(0).c                  := '1';
              inst(0).lpc                := "10";
              comp_ill(0)                := inst_c2xc;
              valid(0)                   := '1';
              buffer_third               := '1';
              buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
              unaligned                  := '1';
              buffer_inst.lpc            := "11";
            else
              buffer_sec  := '1';
              inst(0).d   := inst_c2e;
              inst(0).dc  :=  inst_in(1).d(15 downto 0);
              inst(0).c   := '1';
              inst(0).lpc := "10";
              comp_ill(0) := inst_c2xc;
              valid(0)    := '1';
              inst(1).d   := inst_c3e;
              inst(1).dc  := inst_in(1).d(31 downto 16);
              inst(1).c   := '1';
              inst(1).lpc := "11";
              comp_ill(1) := inst_c3xc;
              valid(1)    := '1';
            end if;  -- unaligned flag
          end if;  -- instruction in 1
        else
          null;
        end if; -- single_issue = 0

      -- Decode at 0x06
      when others =>
        if single_issue = 0 then
          -- Generate unaligned flag
          buffer_inst.lpc := "11";
          if inst_in(1).d(17 downto 16) = "11" then
            valid                      := "00";
            buffer_third               := '1';
            buffer_inst.d(15 downto 0) := inst_in(1).d(31 downto 16);
            unaligned                  := '1';
          else
            valid(0)       := '1';
            inst(0).c      := '1';
            comp_ill(0)    := inst_c3xc;
            buffer_first   := '1';
            buffer_inst.d  := inst_c3e;
            buffer_inst.dc := inst_in(1).d(31 downto 16);
            buffer_inst.c  := '1';
            buff_comp_ill  := inst_c3xc;
          end if;  -- unaligned flag

          -- Generate instruction information in case it is a memory exception
          -- on lsb part of unaligned inst
          inst(0).d   := inst_c3e;
          inst(0).dc  := inst_in(1).d(31 downto 16);
          inst(0).lpc := "11";
        else
          null;
        end if;  -- single_issue = 0
    end case;  -- pc_in(2 downto 1)

    if valid_in = '0' then
      valid := "00";
    end if;
    if single_issue /= 0 then
      valid(1)     := '0';
      buffer_first := '0';
      buffer_sec   := '0';
    end if;

    -- Output Signals
    inst_out         := inst;
    unaligned_out    := unaligned and valid_in;
    valid_out        := valid;
    hold_out         := hold and valid_in;
    npc_out          := npc;
    buffer_sec_out   := buffer_sec and valid_in;
    buffer_third_out := buffer_third and valid_in;
    buffer_first_out := buffer_first and valid_in;
  end;

  -- Rd register validity check
  -- Returns '1' if the instruction has a valid integer rd field.
  function rd_gen(inst : word) return std_ulogic is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
    variable rd     : rfatype     := inst(11 downto 7);
    -- Non-constant
    variable wreg   : std_ulogic  := '1';
  begin
    case op is
      when OP_BRANCH   |
           OP_STORE    |
           OP_STORE_FP | OP_LOAD_FP |
           OP_FMADD    | OP_FMSUB   |
           OP_FNMSUB   | OP_FNMADD   => wreg := '0';
      when OP_FP =>
        case funct5 is
          when R_FCVT_W_S | R_FMV_X_W |  -- Latter includes R_FCLASS
               R_FCMP                =>
            null;  -- These have integer results.
          when others                => wreg := '0';
        end case;

      -- These do not really need to be here, since their
      -- encodings already have rd=0.
      when OP_SYSTEM   =>
        -- Only CSR and hlv/hsv among SYSTEM instructions have rd.
        if not is_csr(inst) and not is_hlv(inst) then
          wreg := '0';
        end if;
      when OP_FENCE => wreg := '0';

      when others =>
    end case;

    if rd = "00000" then
      wreg := '0';
    end if;

    return wreg;
  end;

  -- Rs1 register validity check
  -- Returns the rs1 field in case it is valid and integer, otherwise x0.
  function rs1_gen(inst : word) return rfatype is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct5 : funct5_type := inst(31 downto 27);
    -- Non-constant
    variable rs1    : rfatype     := inst(19 downto 15);
    variable vreg   : std_ulogic  := '1';
  begin
    case op is
      when LUI       | AUIPC    | OP_JAL |
           OP_FMADD  | OP_FMSUB |
           OP_FNMSUB | OP_FNMADD      => vreg := '0';
      when OP_SYSTEM =>
        -- I_CSRRWI, I_CSRRSI, I_CSRRCI
        if is_csr(inst) and funct3(2) = '1' then
          vreg  := '0';
        end if;
        -- Only CSR, sfence.vma, hfence.v/gvma, and hvl/hsv among SYSTEM
        -- instructions have rs1.
        if not is_csr(inst) and not is_sfence_vma(inst) and
           not is_hfence_vvma(inst) and not is_hfence_gvma(inst) and
           not is_hlv(inst) and not is_hsv(inst) then
          vreg  := '0';
        end if;
      when OP_FP     =>
        case funct5 is
          when R_FCVT_S_W | R_FMV_W_X =>
          when others                 => vreg := '0';
        end case;

      when others =>
    end case;

    -- This is used to make sure we do not accidentally
    -- use forwarding when there is not a source register at all.
    -- Relies on destination r0 being marked as invalid (.rdv = '0')!
    if vreg = '0' then
      rs1 := "00000";
    end if;

    return rs1;
  end;

  -- Rs2 register validity check
  -- Returns the rs2 field in case it is valid and integer, otherwise x0.
  function rs2_gen(inst : word) return rfatype is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
    -- Non-constant
    variable rs2    : rfatype     := inst(24 downto 20);
    variable vreg   : std_ulogic  := '1';
  begin
    case op is
      when OP_REG | OP_BRANCH | OP_STORE | OP_32 =>
      when OP_SYSTEM =>
        -- Only sfence.vma, sfence.vma, hfence.v/gvma, and hsv among SYSTEM
        -- instructions have rs2.
        if not is_sfence_vma(inst) and
           not is_hfence_vvma(inst) and not is_hfence_gvma(inst) and
           not is_hsv(inst) then
          vreg                := '0';
        end if;
      when OP_AMO =>
        case funct5 is
          when R_LR   => vreg := '0';
          when others =>
        end case;
      when others     => vreg := '0';
    end case;

    -- This is used to make sure we do not accidentally
    -- use forwarding when there is not a source register at all.
    -- Relies on destination r0 being marked as invalid (.rdv = '0')!
    if vreg = '0' then
      rs2 := "00000";
    end if;

    return rs2;
  end;

  -- Fd register validity check
  -- Returns '1' if the instruction has a valid FPU fd field.
  function fd_gen(inst : word) return std_ulogic is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
    -- Non-constant
    variable wreg   : std_ulogic  := '1';
  begin
    case op is
      when OP_LOAD_FP |
           OP_FMADD   | OP_FMSUB |
           OP_FNMSUB  | OP_FNMADD =>
      when OP_FP =>
        case funct5 is
          when R_FCVT_W_S | R_FMV_X_W |  -- Latter includes R_FCLASS
               R_FCMP              => wreg := '0';
          when others              =>
        end case;
      when others                  => wreg := '0';
    end case;

    return wreg;
  end;

  -- FPU state modifying operation check
  -- Returns true if the instruction can modify FPU state.
  function is_fpu_modify(inst : word) return boolean is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct5 : funct5_type := inst(31 downto 27);
    -- Non-constant
    variable modify : boolean     := false;
  begin
    case op is
      when OP_STORE_FP   => null;
      when OP_LOAD_FP    => modify := true;
      when OP_FMADD   |
           OP_FMSUB   |
           OP_FNMSUB  |
           OP_FNMADD     => modify := true;
      when OP_FP         =>
        case funct5 is
          when R_FMV_X_W => null;  -- Includes R_FCLASS
          when others    => modify := true;
        end case;
      when others        => null;
    end case;

    return modify;
  end;

  -- PC validity check
  -- Returns '1' if pc has to be used as an operand.
  function pc_valid(inst : word) return std_ulogic is
    variable op  : opcode_type := inst(6 downto 0);
    -- Non-constant
    variable vpc : std_ulogic  := '0';
  begin
    case op is
      when AUIPC | OP_JAL | OP_JALR => vpc := '1';
      when others => null;
    end case;

    return vpc;
  end;

  -- Immediate generation and validity check
  -- Note that ZI-Type (CSRI) are not done here since CSRs have separate handling.
  procedure imm_gen(inst_in   : in  word;
                    valid_out : out std_ulogic;
                    imm_out   : out wordx;
                    bj_imm    : out wordx) is
    variable op     : opcode_type := inst_in(6 downto 0);
    variable funct5 : funct5_type := inst_in(31 downto 27);
    variable funct3 : funct3_type := inst_in(14 downto 12);
    -- Non-constant
    variable vimm   : std_ulogic  := '0';
    variable imm    : wordx       := (others => '0');
    variable i_imm  : wordx       := (others => inst_in(31));
    variable s_imm  : wordx       := (others => inst_in(31));
    variable b_imm  : wordx       := (others => inst_in(31));
    variable u_imm  : wordx       := (others => inst_in(31));
    variable j_imm  : wordx       := (others => inst_in(31));
    variable si_imm : wordx       := (others => '0');
  begin
    -- Instruction Type Immediate --------------------------------------------
    -- I-Type
    i_imm(11 downto 0) := inst_in(31 downto 20);
    -- S-Type
    s_imm(11 downto 0) := inst_in(31 downto 25) & inst_in(11 downto 7);
    -- B-Type
    b_imm(12 downto 0) := inst_in(31) & inst_in(7) & inst_in(30 downto 25) & inst_in(11 downto 8) & '0';
    -- U-Type
    u_imm(31 downto 0) := inst_in(31 downto 12) & zerox(11 downto 0);
    -- J-Type
    j_imm(20 downto 0) := inst_in(31) & inst_in(19 downto 12) & inst_in(20) & inst_in(30 downto 21) & '0';
    -- SI-Type (shift amount)
    si_imm(5 downto 0) := inst_in(25 downto 20);

    case op is
      when LUI | AUIPC =>
        imm   := u_imm;
        vimm  := '1';
      when OP_JAL =>
        imm   := j_imm;
        vimm  := '1';
      when OP_JALR | OP_LOAD | OP_LOAD_FP =>
        imm   := i_imm;
        vimm  := '1';
      when OP_IMM =>
        if funct3 = I_SLLI or funct3 = I_SRLI then -- I_SRAI
          imm := si_imm;
        else
          imm := i_imm;
        end if;
        vimm  := '1';
      when OP_BRANCH =>
        imm   := b_imm;
        vimm  := '1';
      when OP_STORE | OP_STORE_FP =>
        imm   := s_imm;
        vimm  := '1';
      when OP_IMM_32 =>
        if inst_in(12) = '0' then -- I_ADDIW
          imm := i_imm;
        else
          imm := si_imm;
        end if;
        vimm  := '1';

      when others =>
    end case;

    bj_imm := b_imm;
    if inst_in(2) = '1' then
      bj_imm := j_imm;
    end if;

    valid_out := vimm;
    imm_out   := imm;
  end;

  -- Exception Check
  -- Exception check unit located in Decode stage.
  -- Searches for illegal instructions, breakpoints and environmental calls.
  procedure exception_check(inst_in   : in  word;
                            cinst_in  : in  word16;
                            pc_in     : in  pctype;
                            comp_ill  : in  std_ulogic;
                            misa_in   : in  wordx;
                            prv_in    : in  priv_lvl_type;
                            v_in      : in  std_ulogic;
                            tsr_in    : in  std_ulogic;
                            tw_in     : in  std_ulogic;
                            tvm_in    : in  std_ulogic;
                            vtsr_in   : in  std_ulogic;
                            vtw_in    : in  std_ulogic;
                            vtvm_in   : in  std_ulogic;
                            hu        : in  std_ulogic;
                            xc_out    : out std_ulogic;
                            cause_out : out cause_type;
                            tval_out  : out wordx) is
    variable rfa1    : rfatype       := inst_in(19 downto 15);
    variable rfa2    : rfatype       := inst_in(24 downto 20);
    variable rd      : rfatype       := inst_in(11 downto  7);
    variable opcode  : opcode_type   := inst_in( 6 downto  0);
    variable funct3  : funct3_type   := inst_in(14 downto 12);
    variable funct7  : funct7_type   := inst_in(31 downto 25);
    variable funct5  : funct5_type   := inst_in(31 downto 27);
    variable funct12 : funct12_type  := inst_in(31 downto 20);
    variable fmt     : word2         := inst_in(26 downto 25);
    variable h_en    : boolean       := misa_in(h_ctrl) = '1';
    -- Non-constant
    variable xc_v    : std_ulogic    := '0'; -- Virtual instruction exception
    variable hv_valid: std_ulogic    := '0';
    variable illegal : std_ulogic    := '0';
    variable xc      : std_ulogic;
    variable prv     : priv_lvl_type := prv_in;
    variable ecall   : std_ulogic    := '0';
    variable ebreak  : std_ulogic    := '0';
    variable cause   : cause_type;
    variable tval    : wordx;
  begin
    case opcode is
      when LUI | AUIPC | OP_JAL =>
        -- LUI/AUIPC with rd = x0 are standard HINTs.
        null;
      when OP_JALR =>
        case funct3 is
          when I_JALR => null;
          when others => illegal := '1';
        end case;
      when OP_BRANCH =>
        case funct3 is
          when B_BEQ | B_BNE  | B_BLT |
               B_BGE | B_BLTU | B_BGEU => null;
          when others                  => illegal := '1';
        end case;
      when OP_LOAD =>
        case funct3 is
          when I_LB  | I_LH  | I_LW  |
               I_LBU | I_LHU | I_LWU | I_LD => null;
          when others                       => illegal := '1';
        end case;
        if is_rv32 and funct3 = I_LD then
          illegal := '1';
        end if;
      when OP_STORE =>
        case funct3 is
          when S_SB | S_SH | S_SW | S_SD => null;
          when others                    => illegal := '1';
        end case;
        if is_rv32 and funct3 = S_SD then
          illegal := '1';
        end if;
      when OP_IMM =>
        case funct3 is
          when I_ADDI | I_SLTI | I_SLTIU | I_XORI | I_ORI | I_ANDI =>
            -- ADDI with rd = x0 and (rs1 /= x0 or imm /= 0) are standard HINTs.
            -- ANDI/ORI/XORI with rd = x0 are standard HINTs.
            -- SLTI/SLTIU with rd = x0 are custom HINTs.
            null;
          when I_SLLI | I_SRLI => -- I_SRAI
            -- SLLI/SRLI/SRAI with rd = x0 are custom HINTs.
            illegal   := '1';
            if funct7(6 downto 1) = "000000" or funct7(6 downto 1) = "010000" then -- shamt[5:0]
              if is_rv64 or funct7(0) = '0' then  -- >31 bit shift illegal on rv32.
                illegal := '0';
              end if;
            end if;
          when others =>
            illegal := '1';
        end case;
      when OP_REG =>
        case funct7 is
          when F7_BASE =>
            case funct3 is
              when R_ADD | R_SLL | R_SLT | R_SLTU |
                   R_XOR | R_SRL | R_OR  | R_AND => null;
                -- ADD/AND/OR/XOR/SLL/SRL with rd = x0 are standard HINTs.
                -- SLT/SLTU with rd = x0 are custom HINTs.
              when others                        => illegal := '1';
            end case;
          when F7_SUB =>
            case funct3 is
              when R_SUB | R_SRA => null;
                -- SUB/SRA with rd = x0 are standard HINTs.
              when others        => illegal := '1';
            end case;
          when F7_MUL =>
            if ext_m = 1 then
              case funct3 is
                when R_MUL | R_MULH | R_MULHSU | R_MULHU |
                     R_DIV | R_DIVU | R_REM    | R_REMU => null;
                when others                             => illegal := '1';
              end case;
            else
              illegal := '1';
            end if;
          when others =>
            illegal := '1';
        end case;
      when OP_FENCE =>
        case funct3 is
          when I_FENCE =>
            --   28   24   20    15  12     7
            -- __fm pred succ __rs1 000 ___rd 0001111
            -- rd  = x0, rs1 /= x0, fm = 0 and (pred = 0 or succ = 0) are standard HINTs.
            -- rd /= x0, rs1  = x0, fm = 0 and (pred = 0 or succ = 0) are standard HINTs.
            -- rd  = x0, rs1  = x0, fm = 0, pred  = 0, succ /= 0 are standard HINTs.
            -- rd  = x0, rs1  = x0, fm = 0, pred /= W, succ  = 0 are standard HINTs.
            -- rd  = x0, rs1  = x0, fm = 0, pred  = W, succ  = 0 is standard HINT (PAUSE).
            if inst_in(19 downto 7) /= zerow(19 downto 7) then
              illegal := '1';
            end if;
          when I_FENCE_I =>
            if inst_in(31 downto 13) /= zerow(31 downto 13) and
               inst_in(12) /= '1' and
               inst_in(11 downto  7) /= zerow(11 downto  7) then
              illegal := '1';
            end if;
          when others =>
            illegal := '1';
        end case;
      when OP_SYSTEM =>
        if not is_csr(inst_in) then
          -- Any of the non-CSR SYSTEM instructions?
          if funct3 = "000" and rd = "00000" then
            case funct7 is
              when F7_URET => -- ECALL, EBREAK, URET (not supported)
                if rfa1 = "00000" then
                  case inst_in(24 downto 20) is
                    when "00000" => ecall  := '1'; -- ECALL
                    when "00001" => ebreak := '1'; -- EBREAK
                    when others => illegal := '1';
                  end case;
                else
                  illegal := '1';
                end if;
              when F7_SRET => -- SRET, WFI
                if rfa1 = "00000" then
                  case rfa2 is
                    when "00010" => -- SRET
                      -- The TSR (Trap SRET) bit supports intercepting the supervisor exception
                      -- return instruction, SRET. When TSR=1, attempts to execute SRET while
                      -- executing in S-mode will raise an illegal instruction exception.
                      -- When TSR=0, this operation is permitted in S-mode.
                      -- TSR is hard-wired to 0 when S-mode is not supported.
                      if ((not h_en) or v_in = '0') and
                         (prv_in = PRIV_LVL_U or (prv_in = PRIV_LVL_S and tsr_in = '1')) then
                        illegal := '1';
                      end if;
                      -- In VS-mode, attempts to execute SRET when hstatus.VTSR=1, or
                      -- in VU-mode, attempts to execute supervisor instruction SRET,
                      -- will raise a virtual instruction trap.
                      if (h_en and v_in = '1') and ((prv_in = PRIV_LVL_S and vtsr_in = '1') or
                                                    prv_in = PRIV_LVL_U) then
                        illegal := '1';
                        xc_v := '1';
                      end if;
                    when "00101" => -- WFI
                      -- The TW (Timeout Wait) bit supports intercepting the WFI instruction.
                      -- When TW=0, the WFI instruction is permitted in S-mode.
                      -- When TW=1, if WFI is executed in S-mode, and it does not complete
                      -- within an implementation-specific, bounded time limit, the
                      -- WFI instruction causes an illegal instruction trap. The time limit
                      -- may always be 0, in which case WFI always causes an illegal instruction
                      -- trap in S-mode when TW=1. TW is hard-wired to 0 when
                      -- S-mode is not supported.
                      -- WFI is available in all privileged modes, and optionally available to U-mode.
                      if ((not h_en) or v_in = '0') and
                         (prv_in = PRIV_LVL_U or (prv_in = PRIV_LVL_S and tw_in = '1')) then
                        illegal := '1'; -- timeout = 0
                      end if;
                      -- In VS-mode, attempts to execute WFI when hstatus.VTW=1 and mstatus.TW=0, or
                      -- in VU-mode, attempts to execute WFI, will raise a virtual instruction trap.
                      if (h_en and v_in = '1') and ((prv_in = PRIV_LVL_S and vtw_in = '1' and tw_in = '0') or
                                                    prv_in = PRIV_LVL_U) then
                        illegal := '1';
                        xc_v := '1';
                      end if;
                    when others =>
                      illegal := '1';
                  end case;
                else
                  illegal := '1';
                end if;
              when F7_MRET =>
                if rfa1 = "00000" and rfa2 = "00010" then
                  if prv_in = PRIV_LVL_S or prv_in = PRIV_LVL_U then
                    illegal := '1';
                  end if;
                else
                  illegal   := '1';
                end if;
              when F7_SFENCE_VMA =>
                -- The TVM (Trap Virtual Memory) bit supports intercepting supervisor
                -- virtual-memory management operations. When TVM=1, attempts to read
                -- or write the satp CSR, or execute the SFENCE.VMA instruction while
                -- executing in S-mode, will raise an illegal instruction exception.
                -- When TVM=0, these operations are permitted in S-mode.
                -- TVM is hard-wired to 0 when S-mode is not supported.
                if ((not h_en) or v_in = '0') and prv_in = PRIV_LVL_S and tvm_in = '1' then
                  illegal := '1';
                end if;
                -- In VS-mode, attempts to execute an SFENCE instruction when hstatus.VTVM=1, or
                -- in VU-mode, attempts to execute an SFENCE instruction, will raise a virtual
                -- instruction trap.
                if (h_en and v_in = '1') and ((prv_in = PRIV_LVL_S and vtvm_in = '1') or
                                               prv_in = PRIV_LVL_U) then
                  illegal := '1';
                  xc_v := '1';
                end if;
              when F7_HFENCE_VVMA =>
                if h_en then
                  if v_in = '1' then
                    illegal := '1';
                    xc_v := '1';
                  end if;
                else
                  illegal := '1';
                end if;
              when F7_HFENCE_GVMA =>
                if h_en then
                  if v_in = '0' then
                    if (prv_in = PRIV_LVL_S and tvm_in = '1') or prv_in = PRIV_LVL_U then
                      illegal := '1';
                    end if;
                  else
                    illegal := '1';
                    xc_v := '1';
                  end if;
                else
                  illegal := '1';
                end if;
              when others =>
                illegal := '1';
            end case;
          elsif funct3 = "100" then
            case funct7 is
              when F7_HLVB =>
                if rfa2 = "00000" or rfa2 = "00001"                   then hv_valid := '1'; end if;
              when F7_HLVH =>
                if rfa2 = "00000" or rfa2 = "00001" or rfa2 = "00011" then hv_valid := '1'; end if;
              when F7_HLVW =>
                if rfa2 = "00000" or rfa2 = "00001" or rfa2 = "00011" then hv_valid := '1'; end if;
              when F7_HLVD =>
                if rfa2 = "00000"                                     then hv_valid := '1'; end if;
              when F7_HSVB | F7_HSVH | F7_HSVW | F7_HSVD =>
                if rd = "00000"                                       then hv_valid := '1'; end if;
              when others =>
                illegal := '1';
            end case;
            if h_en then
              if hv_valid = '1' then
                if v_in = '0' then
                  if prv_in = PRIV_LVL_U and hu = '0' then
                    illegal := '1';
                  end if;
                else
                  illegal := '1';
                  xc_v := '1';
                end if;
              else
                illegal := '1';
              end if;
            else
              illegal := '1';
            end if;
          else
            illegal   := '1';
          end if;
        end if;
      when OP_IMM_32 =>
        case funct3 is
          when I_ADDIW =>
            -- ADDIW with rd = x0 are standard HINTs.
            null;
          when I_SLLIW | I_SRLIW => -- I_SRAIW
            -- SLLIW/SRLIW/SRAIW with rd = x0 are custom HINTs.
            illegal   := '1';
            if funct7 = "0000000" or funct7 = "0100000" then -- shamt[4:0]
              illegal := '0';
            end if;
          when others =>
            illegal := '1';
        end case;
        if is_rv32 then
          illegal := '1';
        end if;
      when OP_32 =>
        case funct7 is
          when F7_BASE =>
            case funct3 is
              when R_ADDW | R_SLLW | R_SRLW => null;
                -- ADDW/SLLW/SRLW with rd = x0 are standard HINTs.
              when others                   => illegal := '1';
            end case;
          when F7_SUB =>
            case funct3 is
              when R_SRAW | R_SUBW => null;
                -- SUBW/SRAW with rd = x0 are stanadrd HINTs.
              when others          => illegal := '1';
            end case;
          when F7_MUL =>
            if ext_m = 1 then
              case funct3 is
                when R_MULW | R_DIVW | R_DIVUW | R_REMW | R_REMUW => null;
                when others => illegal := '1';
              end case;
            else
              illegal := '1';
            end if;
          when others =>
            illegal := '1';
        end case;
        if is_rv32 then
          illegal := '1';
        end if;
      when OP_AMO =>
        if ext_a = 1 then
          if funct3 = R_WORD or funct3 = R_DOUBLE then
            case funct5 is
              when R_LR     | R_SC     | R_AMOSWAP | R_AMOADD |
                   R_AMOXOR | R_AMOAND | R_AMOOR   |
                   R_AMOMIN | R_AMOMAX | R_AMOMINU | R_AMOMAXU => null;
              when others => illegal := '1';
            end case;
          else
            illegal := '1';
          end if;
        else
          illegal   := '1';
        end if;
        if is_rv32 and funct3 = R_DOUBLE then
          illegal := '1';
        end if;
      when OP_LOAD_FP | OP_STORE_FP =>
        case funct3 is
          when R_WORD   => illegal := to_bit(ext_f = 0);
          when R_DOUBLE => illegal := to_bit(ext_d = 0);
          when others   => illegal := '1';
        end case;
        if r.csr.mstatus.fs = "00" or
           (r.csr.v = '1' and r.csr.vsstatus.fs = "00") then
          illegal := '1';
        end if;
      when OP_FMADD | OP_FMSUB | OP_FNMSUB | OP_FNMADD =>
        case fmt is
          when "00"   => illegal := to_bit(ext_f = 0);
          when "01"   => illegal := to_bit(ext_d = 0);
          when others => illegal := '1';
        end case;
        if r.csr.mstatus.fs = "00" or
           (r.csr.v = '1' and r.csr.vsstatus.fs = "00") then
          illegal := '1';
        end if;
        if no_muladd = 1 then
          illegal   := '1';
        end if;
      when OP_FP =>
        case fmt is
          when "00"   => illegal := to_bit(ext_f = 0);
          when "01"   => illegal := to_bit(ext_d = 0);
          when others => illegal := '1';
        end case;
        if r.csr.mstatus.fs = "00" or
           (r.csr.v = '1' and r.csr.vsstatus.fs = "00") then
          illegal := '1';
        end if;
        case funct5 is
          when R_FADD | R_FSUB | R_FMUL | R_FDIV => null;
          when R_FSQRT =>
            if rfa2 /= "00000" then
              illegal := '1';
            end if;
          when R_FSGN =>
            case funct3 is
              when R_FSGNJ | R_FSGNJN | R_FSGNJX => null;
              when others                        => illegal := '1';
            end case;
          when R_FMIN => -- R_FMAX
            case funct3 is
              when R_MAX | R_MIN => null;
              when others        => illegal := '1';
            end case;
          when R_FCMP =>
            case funct3 is
              when R_FEQ | R_FLT | R_FLE => null;
              when others                => illegal := '1';
            end case;
          when R_FCVT_W_S | R_FCVT_S_W => -- R_FCVT_L_S, R_FCVT_S_L (and _D_ variants)
            if not (rfa2(4 downto 2) = "000") then
              illegal := '1';
            end if;
            -- No L[U] fpr RV32.
            if is_rv32 and rfa2(1) = '1' then
              illegal := '1';
            end if;
          when R_FMV_X_W | R_FMV_W_X => -- R_FCLASS (and _D_ variants)
            if not (rfa2 = "00000" and (funct3 = "000" or funct3 = "001")) then
              illegal := '1';
            end if;
            -- The move instructions only work for 32 bit float on RV32.
            if is_rv32 and fmt /= "00" and funct3 = "000" then
              illegal := '1';
            end if;
          when R_FCVT_S_D =>  -- R_FCVT_D_S
            if (fmt = "00" and rfa2 /= "00001") or
               (fmt = "01" and rfa2 /= "00000") then
              illegal := '1';
            end if;
          when others =>
            illegal := '1';
        end case;
      when others =>
        illegal := '1';
    end case; -- opcode

    -- Exception generation
    xc        := '0';
    if xc_v = '1' then
      cause     := XC_INST_VIRTUAL_INST;
    else
      cause     := XC_INST_ILLEGAL_INST;
    end if;

    tval      := to0x(inst_in);

    if comp_ill = '1' then
      -- Illegal compressed instruction
      tval    := to0x(cinst_in);
      illegal := '1';
    end if;

    if illegalTval0 = 1 then
      tval    := zerox;
    end if;

    if illegal = '1' or ecall = '1' or ebreak = '1' then
      xc      := '1';
    end if;

    if ebreak = '1' then
      tval    := (others => '0');
      cause   := XC_INST_BREAKPOINT;
    end if;

    if ecall = '1' then
      tval    := (others => '0');
      case prv is
        when PRIV_LVL_M => cause := XC_INST_ENV_CALL_MMODE;
        when PRIV_LVL_S => cause := XC_INST_ENV_CALL_SMODE;
        when PRIV_LVL_U => cause := XC_INST_ENV_CALL_UMODE;
        when others => null;
      end case;
      -- H-ext: Environment call from VS-mode
      if v_in = '1' and prv = PRIV_LVL_S then
        cause := XC_INST_ENV_CALL_VSMODE;
      end if;
    end if;

    cause_out := cause;
    xc_out    := xc;
    tval_out  := tval;
  end;

  -- Categories of dependent/similar CSRs
  -- Bits  Meaning
  -- 0-3   category number, each category counted as "same" CSR for RaW
  -- 5     do not dual-issue write to CSR
  -- 6     memory access following write to CSR must be delayed
  -- 7     pipeline flush may be required by write to CSR, so hold issue
  -- 8     no FPU instructions under way together with this
  -- 9     no new FPU instructions until this completes
  --
  -- Note that PMPCFG gets "overlapping" things set here. This is mainly to
  -- clarify for any future improvements to the code.
  --
  -- Note that many CSRs that might seem to require various bits set here
  -- do not, since they cannot affect anything in the same CPU privilege mode.
  -- Any changes to such CSRs will require a privilege change to do anything,
  -- and thus there will be a pipeline flush anyway.
  function csr_category(addr : csratype) return std_logic_vector is
    -- Non-constant
    variable category : std_logic_vector(9 downto 0) := (others => '0');
  begin
    -- RaW category dependencies
    case addr is
      -- Writes to any in the numbered category affect all.

      when CSR_MSTATUS | CSR_MSTATUSH | CSR_SSTATUS | CSR_USTATUS =>
        category(3 downto 0) := x"1";
      when CSR_MIE     | CSR_SIE      | CSR_UIE     | CSR_HIE     |
           CSR_MIDELEG | CSR_SIDELEG  | CSR_HIDELEG | -- =>
           CSR_MIP     | CSR_SIP      | CSR_UIP     | CSR_HIP     |
           CSR_HVIP    | CSR_VSIP     =>
        category(3 downto 0) := x"2";
      when CSR_FFLAGS  | CSR_FRM | CSR_FCSR =>
        category(3 downto 0) := x"4";

      -- Writes to the first in the numbered category affect the rest.
      -- But putting them all in a single category should not matter for performance.

      -- If a write to any of these causes a timer to be disabled, it would be strange
      -- if two immediately following reads of that timer give different results.
      -- Changes to these can be handled by holding the pipeline, since it should not
      -- matter if the writes are somewhat slow.
      when CSR_MCOUNTINHIBIT  | CSR_MHPMEVENT3     |
           CSR_MHPMEVENT4     | CSR_MHPMEVENT5     | CSR_MHPMEVENT6     | CSR_MHPMEVENT7     |
           CSR_MHPMEVENT8     | CSR_MHPMEVENT9     | CSR_MHPMEVENT10    | CSR_MHPMEVENT11    |
           CSR_MHPMEVENT12    | CSR_MHPMEVENT13    | CSR_MHPMEVENT14    | CSR_MHPMEVENT15    |
           CSR_MHPMEVENT16    | CSR_MHPMEVENT17    | CSR_MHPMEVENT18    | CSR_MHPMEVENT19    |
           CSR_MHPMEVENT20    | CSR_MHPMEVENT21    | CSR_MHPMEVENT22    | CSR_MHPMEVENT23    |
           CSR_MHPMEVENT24    | CSR_MHPMEVENT25    | CSR_MHPMEVENT26    | CSR_MHPMEVENT27    |
           CSR_MHPMEVENT28    | CSR_MHPMEVENT29    | CSR_MHPMEVENT30    | CSR_MHPMEVENT31    |
      -- Writes to M<x> should be immediately visible in <x>.
      -- The <x> cannot be written at all.
           CSR_MCYCLE         | CSR_MINSTRET       | CSR_MHPMCOUNTER3   |
           CSR_MHPMCOUNTER4   | CSR_MHPMCOUNTER5   | CSR_MHPMCOUNTER6   | CSR_MHPMCOUNTER7   |
           CSR_MHPMCOUNTER8   | CSR_MHPMCOUNTER9   | CSR_MHPMCOUNTER10  | CSR_MHPMCOUNTER11  |
           CSR_MHPMCOUNTER12  | CSR_MHPMCOUNTER13  | CSR_MHPMCOUNTER14  | CSR_MHPMCOUNTER15  |
           CSR_MHPMCOUNTER16  | CSR_MHPMCOUNTER17  | CSR_MHPMCOUNTER18  | CSR_MHPMCOUNTER19  |
           CSR_MHPMCOUNTER20  | CSR_MHPMCOUNTER21  | CSR_MHPMCOUNTER22  | CSR_MHPMCOUNTER23  |
           CSR_MHPMCOUNTER24  | CSR_MHPMCOUNTER25  | CSR_MHPMCOUNTER26  | CSR_MHPMCOUNTER27  |
           CSR_MHPMCOUNTER28  | CSR_MHPMCOUNTER29  | CSR_MHPMCOUNTER30  | CSR_MHPMCOUNTER31  |
           CSR_MCYCLEH        | CSR_MINSTRETH      | CSR_MHPMCOUNTER3H  |
           CSR_MHPMCOUNTER4H  | CSR_MHPMCOUNTER5H  | CSR_MHPMCOUNTER6H  | CSR_MHPMCOUNTER7H  |
           CSR_MHPMCOUNTER8H  | CSR_MHPMCOUNTER9H  | CSR_MHPMCOUNTER10H | CSR_MHPMCOUNTER11H |
           CSR_MHPMCOUNTER12H | CSR_MHPMCOUNTER13H | CSR_MHPMCOUNTER14H | CSR_MHPMCOUNTER15H |
           CSR_MHPMCOUNTER16H | CSR_MHPMCOUNTER17H | CSR_MHPMCOUNTER18H | CSR_MHPMCOUNTER19H |
           CSR_MHPMCOUNTER20H | CSR_MHPMCOUNTER21H | CSR_MHPMCOUNTER22H | CSR_MHPMCOUNTER23H |
           CSR_MHPMCOUNTER24H | CSR_MHPMCOUNTER25H | CSR_MHPMCOUNTER26H | CSR_MHPMCOUNTER27H |
           CSR_MHPMCOUNTER28H | CSR_MHPMCOUNTER29H | CSR_MHPMCOUNTER30H | CSR_MHPMCOUNTER31H |
           -- Affect
           CSR_CYCLE          | CSR_INSTRET        | CSR_HPMCOUNTER3    |
           CSR_HPMCOUNTER4    | CSR_HPMCOUNTER5    | CSR_HPMCOUNTER6    | CSR_HPMCOUNTER7    |
           CSR_HPMCOUNTER8    | CSR_HPMCOUNTER9    | CSR_HPMCOUNTER10   | CSR_HPMCOUNTER11   |
           CSR_HPMCOUNTER12   | CSR_HPMCOUNTER13   | CSR_HPMCOUNTER14   | CSR_HPMCOUNTER15   |
           CSR_HPMCOUNTER16   | CSR_HPMCOUNTER17   | CSR_HPMCOUNTER18   | CSR_HPMCOUNTER19   |
           CSR_HPMCOUNTER20   | CSR_HPMCOUNTER21   | CSR_HPMCOUNTER22   | CSR_HPMCOUNTER23   |
           CSR_HPMCOUNTER24   | CSR_HPMCOUNTER25   | CSR_HPMCOUNTER26   | CSR_HPMCOUNTER27   |
           CSR_HPMCOUNTER28   | CSR_HPMCOUNTER29   | CSR_HPMCOUNTER30   | CSR_HPMCOUNTER31   |
           CSR_CYCLEH         | CSR_INSTRETH       | CSR_HPMCOUNTER3H   |
           CSR_HPMCOUNTER4H   | CSR_HPMCOUNTER5H   | CSR_HPMCOUNTER6H   | CSR_HPMCOUNTER7H   |
           CSR_HPMCOUNTER8H   | CSR_HPMCOUNTER9H   | CSR_HPMCOUNTER10H  | CSR_HPMCOUNTER11H  |
           CSR_HPMCOUNTER12H  | CSR_HPMCOUNTER13H  | CSR_HPMCOUNTER14H  | CSR_HPMCOUNTER15H  |
           CSR_HPMCOUNTER16H  | CSR_HPMCOUNTER17H  | CSR_HPMCOUNTER18H  | CSR_HPMCOUNTER19H  |
           CSR_HPMCOUNTER20H  | CSR_HPMCOUNTER21H  | CSR_HPMCOUNTER22H  | CSR_HPMCOUNTER23H  |
           CSR_HPMCOUNTER24H  | CSR_HPMCOUNTER25H  | CSR_HPMCOUNTER26H  | CSR_HPMCOUNTER27H  |
           CSR_HPMCOUNTER28H  | CSR_HPMCOUNTER29H  | CSR_HPMCOUNTER30H  | CSR_HPMCOUNTER31H =>
        category(3 downto 0) := x"5";


      -- Changes to TSELECT will cause TDATAn to return different things.
      when CSR_TSELECT   |
           -- Affects
           CSR_TDATA1    | CSR_TDATA2    | CSR_TDATA3 | CSR_TINFO =>
        category(3 downto 0) := x"6";

      -- The setting in PMPCFG affects values read from PMPADDR.
      when CSR_PMPCFG0   | CSR_PMPCFG1   | CSR_PMPCFG2   | CSR_PMPCFG3   |
           -- Affect
           CSR_PMPADDR0  | CSR_PMPADDR1  | CSR_PMPADDR2  | CSR_PMPADDR3  |
           CSR_PMPADDR4  | CSR_PMPADDR5  | CSR_PMPADDR6  | CSR_PMPADDR7  |
           CSR_PMPADDR8  | CSR_PMPADDR9  | CSR_PMPADDR10 | CSR_PMPADDR11 |
           CSR_PMPADDR12 | CSR_PMPADDR13 | CSR_PMPADDR14 | CSR_PMPADDR15 =>
        category(3 downto 0) := x"7";

      when others => null;
        -- No category if low nybble is 0.
    end case;

    -- Some CSR writes need to issue alone (see also below).
    case addr is
      -- Changes to interrupt enable must not dual-issue, to prevent interrupt
      -- traps from being taken in a pair with such a CSR write.
      when CSR_MSTATUS | CSR_SSTATUS | CSR_USTATUS | CSR_HSTATUS |
           CSR_MIE     | CSR_SIE     | CSR_UIE     | CSR_HIE     |
           CSR_HGEIE   |
           CSR_MIDELEG | CSR_SIDELEG =>
        category(5) := '1';
      when others => null;
    end case;

    -- For some CSR writes, nothing more should leave the issue stage
    -- until the writes are completed.
    -- DCSR would be one such, but can only be used from the DSU.
    case addr is
      -- Changes to these may force pipeline flush since the next instruction
      -- fetch may be required to behave differently.
      -- Writes to PMPCFG lock bits may change execute protection.
      when CSR_PMPCFG0 | CSR_PMPCFG1 | CSR_PMPCFG2 | CSR_PMPCFG3 |
           CSR_SATP    |         -- Changes memory mapping.
           CSR_VSATP   |         -- Changes memory mapping.
           CSR_HGATP   |         -- Changes memory mapping.
           CSR_MISA    |         -- May turn on/off extensions and change MXL.
           CSR_MSTATUS |         -- May turn on/off FPU and extensions.
           CSR_SSTATUS |
           CSR_DFEATURESEN | CSR_DFEATURESENH => -- Can do just about anything.
        category(7) := '1';
        -- To simplify PC logic, ensure that CSR writes that may require pipeline flush
        -- always issue alone (and put them always in the same pipe).
        category(5) := '1';
      when others => null;
    end case;

    -- Some CSR writes may not pair if issued in lane 0, since the behaviour
    -- may change for the very next instruction.
    -- Known examples are mret, sret and uret.
    -- Currently those are handled directly in dual_issue_check(), but
    -- perhaps they should be here instead?

    -- Some CSR writes affect following memory accesses.
    -- The following access must be delayed!
    --
    -- In the case of the FS/XS, FPU and/or other extension instructions may
    -- be enabled/disabled. Affects whether the next instruction is illegal!
    case addr is
      -- MSTATUS
      --   MBE     - switch endianness of following load/store
      --   MXR     - affects following load (allow/disable read from executable space)
      --   SUM     - affects following load/store (allow/disable access to user mode pages)
      --   MPRV    - affects following load/store (physical or virtual addressing in M-mode)
      --   FS/XS   - turning off FPU/ext could cause next instruction to fault
      -- SSTATUS
      --   MXR     - affects following load (allow/disable read from executable space)
      --   SUM     - affects following load/store (allow/disable access to user mode pages)
      --   FS/XS   - turning off FPU/ext which could cause next instruction to fault
      -- HSTATUS
      --   VSBE    - switch endianness of following hypervisor load/store
      --   SPVP    - affects privilege level of following hypervisor load/store
      --   HU      - affects following hypervisor load/store (allow/disable access to user mode pages)
      when CSR_MSTATUS   | CSR_MSTATUSH  | CSR_SSTATUS   | CSR_HSTATUS   |
      -- PMPCFG/PMPADDR affect memory protection.
           CSR_PMPCFG0   | CSR_PMPCFG1   | CSR_PMPCFG2   | CSR_PMPCFG3   |
           CSR_PMPADDR0  | CSR_PMPADDR1  | CSR_PMPADDR2  | CSR_PMPADDR3  |
           CSR_PMPADDR4  | CSR_PMPADDR5  | CSR_PMPADDR6  | CSR_PMPADDR7  |
           CSR_PMPADDR8  | CSR_PMPADDR9  | CSR_PMPADDR10 | CSR_PMPADDR11 |
           CSR_PMPADDR12 | CSR_PMPADDR13 | CSR_PMPADDR14 | CSR_PMPADDR15 |
      -- Special case!
      -- MIE/SIE/UIE can disable interrupts and the interrupt code relies on
      -- there being no load/store directly following that.
           CSR_MIE       | CSR_SIE       | CSR_UIE        | CSR_HIE      |
           CSR_HGEIE =>
        category(6) := '1';
      when others => null;
    end case;

    -- FPU instructions in the pipeline must complete before the FPU flags
    -- can be read or written. Then the write needs to happen before any other
    -- FPU instructions may complete and modify them.
    -- For now, no FPU instructions are allowed in the pipeline together with
    -- any accesses to the FPU related CSRs.
    case addr is
      when CSR_FFLAGS | CSR_FCSR =>
        category(8) := '1';
      when others => null;
    end case;

    -- Writes to some CSR:s must take effect before a new FPU instruction is allowed.
    -- (FPU rounding mode can be read at any time.)
    case addr is
      when CSR_FFLAGS | CSR_FCSR | CSR_FRM =>
        category(9) := '1';
      when others => null;
    end case;

    return category;
  end;

  -- Must the instruction be handled in lane 0?
  function for_lane0(inst : word) return boolean is
    variable op : opcode_type := inst(6 downto 0);
  begin
    if memory_lane = 0 and
       (op = OP_STORE    or op = OP_LOAD    or
        op = OP_STORE_FP or op = OP_LOAD_FP or
        op = OP_AMO      or op = OP_FENCE) then
      return true;
    end if;

    if memory_lane = 0 and is_sfence_vma(inst) then
      return true;
    end if;

    -- Hypervisor instructions are either fence, load, or store.
    if memory_lane = 0 and ext_h /= 0 and
       (is_hfence_vvma(inst) or is_hfence_gvma(inst) or
        is_hlv(inst) or is_hsv(inst)) then
      return true;
    end if;

     -- Writes to PMPCFG lock bits, DFEATURESEN or SATP require the pipeline to be flushed.
     -- To simplify PC logic, such CSR writes always issue alone, but
     -- this also ensures that all CSR accesses are in the proper lane
     -- (used to be lane 0 (like fences), but may now be changed).
    if csr_lane = 0 and is_csr(inst) then
      return true;
    end if;

    -- While floating point load/store need to be in lane 0, and are taken
    -- care of above, the other FPU instructions may also be forced here.
    if fpu_lane = 0 and is_fpu(inst) then
      return true;
    end if;

    return false;
  end;

  -- Must the instruction be handled in lane 1?
  function for_lane1(inst : word) return boolean is
    variable op : opcode_type := inst(6 downto 0);
  begin
    if branch_lane = 1 and (op = OP_JAL or op = OP_JALR or op = OP_BRANCH) then
      return true;
    end if;

     -- Writes to PMPCFG lock bits, DFEATURESEN or SATP require the pipeline to be flushed.
     -- To simplify PC logic, such CSR writes always issue alone, but
     -- this also ensures that all CSR accesses are in the proper lane
     -- (used to be lane 0 (like fences), but may now be changed).
    if csr_lane = 1 and is_csr(inst) then
      return true;
    end if;

    -- While floating point load/store need to be in lane 0, the other
    -- FPU instructions may be forced here instead.
    if fpu_lane = 1 and is_fpu(inst) then
      return true;
    end if;

    return false;
  end;

  -- Functional unit select
  function fusel_gen(inst : word) return fuseltype is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct3 : funct3_type := inst(14 downto 12);
    variable funct5 : funct5_type := inst(31 downto 27);
    variable funct7 : funct7_type := inst(31 downto 25);
    -- Non-constant
    variable fusel  : fuseltype   := NONE;
  begin
    case op is
      when LUI | AUIPC | OP_IMM | OP_IMM_32 =>
        fusel     := ALU;
      when OP_AMO =>
        if ext_a /= 0 then
          if    funct5 = R_LR then
            fusel := (AMO or LD);
          elsif funct5 = R_SC then
            fusel := (AMO or LD or ST);
          else
            fusel := (AMO or LD or ST);
          end if;
        end if;
      when OP_REG | OP_32 =>
        if funct7 = F7_MUL then
          fusel   := MUL;
        else
          fusel   := ALU;
        end if;
      when OP_FP =>
        if ext_f /= 0 then
          if funct5 = R_FCMP or funct5 = R_FMV_X_W or funct5 = R_FCVT_W_S then
            fusel := FPU;
          end if;
        end if;
      when OP_STORE | OP_STORE_FP =>
        fusel     := ST;
      when OP_LOAD  | OP_LOAD_FP =>
        fusel     := LD;
      when OP_JAL =>
        fusel     := JAL;
      when OP_JALR =>
        fusel     := JALR;
      when OP_BRANCH =>
        fusel     := BRANCH;
      when OP_SYSTEM =>
        if ext_h /= 0 and funct3 = "100" then
          if funct7(0) = '0' then
            fusel := LD;
          else --if funct7(0) = '1'
            fusel := ST;
          end if;
        elsif funct3 /= "000" then
          fusel   := ALU;
        end if;
      when others => null;
    end case;

    return fusel;
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
      fusel(i)    := fusel_gen(instx_in(i).d);
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

  -- Dual issue check logic
  -- Check if instructions can be issued in the same clock cycle on both lanes.
  procedure dual_issue_check(instx_in  : in  iword_pair_type;
                             valid_in  : in  lanes_type;
                             csren_in  : in  csr_dfeaturesen_type;
                             step_in   : in  std_ulogic;
                             lalu_in   : in  lanes_type;
                             rd0_in    : in  rfatype;
                             rdv0_in   : in  std_ulogic;
                             rd1_in    : in  rfatype;
                             rdv1_in   : in  std_ulogic;
                             lane0_out : out std_ulogic;
                             issue_out : out lanes_type) is
    -- Non-constant
    variable inst_in   : word_lanes_type;
    variable conflict  : std_ulogic := '0';
    variable rfa1      : rfa_lanes_type;
    variable rfa2      : rfa_lanes_type;
    variable rd        : rfa_lanes_type;
    variable rs1_valid : lanes_type;
    variable rs2_valid : lanes_type;
    variable rd_valid  : lanes_type;
    type op_lanes_t   is array (lanes'range) of opcode_type;
    type f3_lanes_t   is array (lanes'range) of funct3_type;
    type f7_lanes_t   is array (lanes'range) of funct7_type;
    variable opcode    : op_lanes_t;
    variable funct3    : f3_lanes_t;
    variable funct7    : f7_lanes_t;
    variable lane0     : std_ulogic := '0';
    variable opcode_0  : opcode_type;  -- These are needed to have
    variable opcode_1  : opcode_type;  --  locally static object
    variable funct7_1  : funct7_type;  --  subtypes for case statements.
  begin
    for i in lanes'range loop
      inst_in(i)  := instx_in(i).d;
      opcode(i)   := inst_in(i)(6 downto 0);
      funct3(i)   := inst_in(i)(14 downto 12);
      funct7(i)   := inst_in(i)(31 downto 25);
      rfa1(i)     := rs1_gen(inst_in(i));
      rfa2(i)     := rs2_gen(inst_in(i));
      rd_valid(i) := rd_gen(inst_in(i));
      rd(i)       := inst_in(i)(11 downto 7);
    end loop;

    -- Create locally static objects
    opcode_0 := opcode(0);
    opcode_1 := opcode(one);
    funct7_1 := funct7(one);


    -- If both instructions are valid, inst(0) is always the older instruction,
    -- hence only that one should be issued if a dependency exists between the
    -- pair.
    case opcode_0 is
      when OP_LOAD    | OP_STORE | OP_AMO |
           OP_LOAD_FP | OP_STORE_FP =>
        if for_lane0(inst_in(one)) then
          conflict := '1';
        end if;

      when OP_JAL | OP_JALR =>
        -- Raise conflict since we will have a control flow change, so the instruction
        -- after the jal/jalr would not be valid anyway.
        conflict := '1';

      when OP_BRANCH =>
        if late_branch  /= 0 then
          if not (opcode(1) = OP_REG or opcode(1) = OP_32 or opcode(1) = OP_IMM_32 or opcode(1) = OP_IMM
                  or opcode(1) = LUI) then
            conflict := '1';
          end if;
        end if;

        if late_branch = 0 then
          case opcode_1 is
            when OP_BRANCH =>
              -- Raise conflict since only one branch unit is available.
              conflict := '1';
            when OP_JAL | OP_JALR =>
              -- Raise conflict since they use the same lane.
              conflict := '1';
            when OP_SYSTEM =>
              if csr_lane = 1 and is_csr(inst_in(one)) then
                -- Raise conflict since they use the same lane.
                conflict := '1';
              end if;

            when OP_FP | OP_FMADD | OP_FMSUB | OP_FNMADD | OP_FNMSUB | OP_STORE_FP | OP_LOAD_FP =>
              -- In order for combinatorial branch resolution in execute stage
              -- to not affect FPU, prevent dual issue of FPU with branches.
              conflict := '1';

            when others =>

          end case; -- opcode(1)
        end if;

        if r.d.mexc = '1' then
          -- Don't allow dual issue when instruction after branch is exception.
          conflict := '1';
        end if;

      when OP_SYSTEM =>
        if funct3(0) = "000" then
          -- ecall/ebreak/uret/sret/mret
          -- Raise conflict since we will have a control flow change at the
          -- exception stage, so the next istruction will not be valid.
          conflict := '1';
          if inst_in(0)(22 downto 20) = "101" and funct7(0) = F7_WFI then
            -- In case of wfi instruction, do not raise conflict.
            conflict := '0';
          end if;
        end if;
        if is_csr(inst_in(0)) then
          -- For some CSR writes, raise conflict since the execution of the
          -- next instruction may depend on it.
          if not csr_read_only(inst_in(0)) and
             csr_category(csr_addr(inst_in(0)))(5) = '1' then
            conflict := '1';
          end if;
          -- Do not allow CSR writes to FPU flags or rounding mode to
          -- pair with an FPU instruction.
          if is_fpu(inst_in(one)) and
             csr_category(csr_addr(inst_in(0)))(8) = '1' then
            conflict := '1';
          end if;
          -- CSR accesses use the same pipeline as some other things.
          -- (These checks include other CSR accesses.)
          if csr_lane = 0 and for_lane0(inst_in(one)) then
            -- Raise conflict since they use the same lane.
            conflict := '1';
          end if;
          if csr_lane = 1 and for_lane1(inst_in(one)) then
            -- Raise conflict since they use the same lane.
            conflict := '1';
          end if;
          if opcode(one) = OP_SYSTEM then
            -- uret/sret/mret depend on UEPC/SEPC/MEPC, so they may not pair
            -- with a write to those in lane 0.
            if funct3(one) = "000" then
              case funct7_1 is
                when F7_MRET =>
                  if csr_addr(inst_in(0)) = CSR_MEPC then
                    conflict := '1';
                  end if;
                when F7_SRET =>
                  if csr_addr(inst_in(0)) = CSR_SEPC then
                    conflict := '1';
                  end if;
                when F7_URET =>
                  if csr_addr(inst_in(0)) = CSR_UEPC then
                    conflict := '1';
                  end if;
                when others =>
              end case;
            end if;
          end if;
        end if;
        if is_sfence_vma(inst_in(0)) then
          -- Raise conflict since next instruction might be wrong!
          conflict := '1';
        end if;
        -- Hypervisor extension
        if ext_h /= 0 then
          -- Hypervisor load/store, raise conflict when
          if funct3(0) = "100" then
            if for_lane0(inst_in(one)) then
              conflict := '1';
            end if;
          end if;

          -- Raise conflict since next instruction might be wrong!
          if is_hfence_vvma(inst_in(0)) or is_hfence_gvma(inst_in(0)) then
            if is_hlv(inst_in(one)) or is_hsv(inst_in(one)) then
              conflict := '1';
            end if;
          end if;
        end if;

      when OP_FENCE =>
        -- Raise conflict
        conflict := '1';

      when OP_REG | OP_32 =>
        if funct7(0) = F7_MUL then
          case opcode_1 is
            when OP_REG | OP_32 =>
              if funct7(one) = F7_MUL then
                -- Mul/Div Operation
                -- Raise conflict since we have only one Mul/Div Unit
                conflict := '1';
              end if;

            when others =>
          end case; -- opcode(1)
        end if;

      -- There can be only one.
      when OP_FP     |
           OP_FMADD  | OP_FMSUB  |
           OP_FNMADD | OP_FNMSUB =>
        -- Do not allow CSR writes to FPU flags or rounding mode to
        -- pair with an FPU instruction.
        if csr_category(csr_addr(inst_in(one)))(8) = '1' then
          conflict := '1';
        end if;
        -- FPU operations use the same pipeline as some other things.
        -- (These checks include other FPU operations.)
        if fpu_lane = 0 and for_lane0(inst_in(one)) then
          -- Raise conflict since they use the same lane.
          conflict := '1';
        end if;
        if fpu_lane = 1 and for_lane1(inst_in(one)) then
          -- Raise conflict since they use the same lane.
          conflict := '1';
        end if;

      when others =>
    end case; -- opcode(0)

    -- Multi-cycle operations in execute stage do not currently work.
    -- Fortunately, for now that is only divide/remainder and FPU->IU.
    -- This also prevents the problem of division issued together with a branch
    -- because we don't want branch to combinatorially affect ex_hold_pc signal
    -- in execute stage.
    for i in lanes'range loop
      if (opcode(i) = OP_REG or  opcode(i) = OP_32) and
         funct7(i) = F7_MUL and funct3(i)(2) = '1' then   -- DIV[U][W]/REM[U][W]
        conflict := '1';
      end if;
    end loop;
    if ext_f /= 0 then
      for i in lanes'range loop
        -- For now, never pair FPU with anything.
        if is_fpu(inst_in(i)) or is_fpu_mem(inst_in(i)) then
          conflict := '1';
        end if;
      end loop;
    end if;

    -- This is the same as for pipe 0 above.
    -- Writes to some CSRs require the pipeline to be flushed. To simplify PC logic,
    -- ensure that such CSR writes always issue alone.
    -- There are also other reasons for enforcing single-issue of CSR writes.
    if is_csr(inst_in(one)) and not csr_read_only(inst_in(one)) and
       csr_category(csr_addr(inst_in(one)))(5) = '1' then
      conflict := '1';
    end if;


    -- For CSRs that may cause pipeline flush, ensure that they are available
    -- in lane 0 (even with swap), to make later flush code able to only check
    -- there for new PC.
    -- Such CSR must also execute alone, which is already handled above,
    -- since all category(7) CSRs are also in category(5).
    if csr_lane = 1 then
      for i in lanes'range loop
        if valid_in(i) = '1' and is_csr(inst_in(i)) and
           not csr_read_only(inst_in(i))            and
           csr_category(csr_addr(inst_in(i)))(7) = '1' then
          -- If in lane 0, it will execute since it is first.
          -- Otherwise, it will only execute if there is no valid instruction in lane 0.
          if i = 0 or valid_in(0) = '0' then
            lane0 := '1';
          end if;
        end if;
      end loop;
    end if;

    -- Instruction register dependency:

    -- case # 1
    -- | INSTA x1, 0(x2)  |
    -- | INSTB x4, x1, x3 |
    -- If rd of the first instruction is valid and the other instruction
    -- uses it as a source operand, raise conflict. Do not raise conflict in
    -- scenarios covered by forwarding or late alu.

    -- case # 2
    -- | INSTA x1, 0(x2)  |
    -- | INSTB x1, x4, x3 |
    -- If rd of the first istruction is valid and the other instruction
    -- uses it as a valid destination register, raise conflict. Do not raise
    -- conflict if the second instruction is a STORE/LOAD, since we will forward
    -- the operand to the memory. It could be resolved after the exception stage
    -- as soon as we have the validity of both instruction and we could decide
    -- which value to write.

    if rd_valid(0) = '1' then
      -- case # 1
      if rd(0) = rfa1(one) or rd(0) = rfa2(one) then
        case opcode_1 is
          when OP_LOAD   | OP_LOAD_FP |  -- Load (address)
               OP_SYSTEM |               -- System or CSR
               OP_FENCE  |               -- Fence
               OP_FP     |               -- Floating point operation with integer input
               OP_JALR =>                -- Jump and link register (this is resolved early)
            conflict   := '1';

          -- Store in second lane (only in case of Address Generation)
          when OP_STORE | OP_STORE_FP | OP_AMO =>
            if rd(0) = rfa1(one) then
              conflict := '1';
            end if;

            -- Right now it is assumed that multiplier is always 2 stage
            if (opcode(0) = OP_REG or opcode(0) = OP_32) and funct7(0) = F7_MUL then
              if rd(0) = rfa2(one) then
                conflict := '1';
              end if;
            end if;

          -- Branch in second lane (if late branch feature is disabled)
          when OP_BRANCH =>
            if csren_in.lbranchen = '0' or late_branch = 0 then
              conflict := '1';
            end if;

          -- ALU operation in second lane (if late ALU feature is disabled)
          when OP_REG | OP_32 | OP_IMM_32 | OP_IMM | LUI | AUIPC =>
            if csren_in.laluen = '0' or late_alu = 0 then
              conflict := '1';
            end if;
             -- Instruction in RA has been issued to late ALUs
            if ((rd0_in = rfa1(0) or rd0_in = rfa2(0)) and lalu_in(0) = '1' and rdv0_in = '1') or
               ((rd1_in = rfa1(0) or rd1_in = rfa2(0)) and lalu_in(one) = '1' and rdv1_in = '1') then
              conflict := '1';
            end if;
            -- MUL/DIV in any case
            if (opcode(one) = OP_REG or opcode(one) = OP_32) and funct7(one) = F7_MUL then
              conflict := '1';
            end if;

          when others =>
            -- FMADD, FMSUB, FNMSUB, FNMADD - No integer source
            -- JAL - No source
            -- The rest are not available:
            -- custom-0
            -- 48b
            -- custom-1
            -- 64b
            -- reserved-10101_11
            -- custom-2
            -- 48b
            -- reserved-11010_11
            -- reserved-11101_11
            -- custom-3
            -- >= 80b
            null;
        end case;

        -- Values from CSRs will not be available until in the exception stage,
        -- at the same time as the late ALU, so it is not possible for another
        -- instruction in the same pair to access it.
        if is_csr(inst_in(0)) then
          conflict := '1';
        end if;
      end if;

      -- case # 2
      if rd_valid(one) = '1' and rd(0) = rd(one) then
        -- Generate conflict flag in case of
        -- LOAD and other ALU instruction.
        -- JAL/JALR instruction would be placed in lane1,
        -- thus no conflict arises.
        if opcode(one) = OP_LOAD or opcode(0) = OP_LOAD or
           opcode(one) = OP_AMO  or opcode(0) = OP_AMO  or
           is_hlv(inst_in(one))  or is_hlv(inst_in(0)) then
          conflict := '1';
        end if;
        -- Generate conflict in case one of the
        -- instructions is a CSR.
        if is_csr(inst_in(0)) or is_csr(inst_in(one)) then
          conflict := '1';
        end if;
      end if;
    end if;

    lane0_out := lane0;

    -- If only one instructions is valid, we could issue it without any check.
    issue_out  := valid_in;

    -- If dual issue capability is disabled, raise conflict.
    if csren_in.dualen = '0' then
      conflict := '1';
    end if;

    -- If instruction step, raise conflict.
    if step_in = '1' then
      conflict := '1';
    end if;

    if conflict = '1' and all_1(valid_in) then
      issue_out(one) := '0';
    end if;
  end;

  -- Dual issue swap logic, generate swap flag
  procedure dual_issue_swap(inst_in  : in  iword_pair_type;
                            valid_in : in  std_logic_vector;
                            swap_out : out std_ulogic) is
    -- Non-constant
    variable swap : std_logic := '0';
  begin
    if for_lane1(inst_in(0).d) and valid_in(0) = '1' then
      swap := '1';
    end if;

    if for_lane0(inst_in(1).d) and (valid_in(0) = '0' or not for_lane0(inst_in(0).d)) then
      swap := '1';
    end if;

    swap_out := swap;
  end;

  -- Generate instruction trace data
  procedure itrace_gen(r         : in  registers;
                       fpo       : in  fpu5_out_type;
                       xc        : in  lanes_type;
                       xc_taken  : in  std_ulogic;
                       xc_cause  : in  cause_type;
                       xc_tval   : in  wordx;
                       results   : in  wordx_lanes_type;
                       tcnt_out  : out std_logic_vector(TBUFBITS - 1 downto 0);
                       di_out    : out nv_trace_in_type;
                       di_2p_out : out nv_trace_2p_in_type) is
    -- Non-constant
    variable tcnt   : std_logic_vector(r.dm.tbufcnt'range)       := r.dm.tbufcnt;
    variable taddr  : std_logic_vector(r.dm.tbufcnt'range)       := r.dm.tbufcnt;
    variable di     : nv_trace_in_type                           := nv_trace_in_type_none;
    variable di_2p  : nv_trace_2p_in_type                        := nv_trace_2p_in_type_none;
    variable idata  : std_logic_vector(TRACE_WIDTH - 1 downto 0) := (others => '0');
    variable write  : std_logic_vector(TRACE_SEL - 1 downto 0)   := (others => '0');
    variable enable : std_ulogic                                 := '0';
    variable tactive: std_ulogic                                 := '0';
    variable tfpuact: std_ulogic                                 := '0';
    variable valid  : lanes_type;
    type     pc_t  is array (lanes'range) of std_logic_vector(47 downto 1);
    variable pc_l   : pc_t;
    variable j      : integer range lanes'range;
  begin
    -- Generate PC Signals
    for i in lanes'range loop
      valid(i) := r.x.ctrl(i).valid;
      pc_l(i)  := to64(pc2xlen(r.x.ctrl(i).pc))(pc_l(0)'range);
    end loop;

    -- Trace active
    if not all_0(valid) then
      if r.x.rstate = run then
        if r.csr.v = '0' then
          if (r.csr.prv = PRIV_LVL_M and r.csr.dfeaturesen.tmode_dis(0) = '0') or
             (r.csr.prv = PRIV_LVL_S and r.csr.dfeaturesen.tmode_dis(1) = '0') or
             (r.csr.prv = PRIV_LVL_U and r.csr.dfeaturesen.tmode_dis(2) = '0') then
            tactive := '1';
          end if;
        else -- r.csr.v = '1'
          if (r.csr.prv = PRIV_LVL_S and r.csr.dfeaturesen.tmode_dis(3) = '0') or
             (r.csr.prv = PRIV_LVL_U and r.csr.dfeaturesen.tmode_dis(4) = '0') then
            tactive := '1';
          end if;
        end if;
      elsif r.x.rstate = dexec and r.csr.dfeaturesen.tpbuf_en = '1' then
        tactive := '1';
      end if;
    end if;

    if fpo.wen = '1' then
      if r.x.rstate = run then
        if fpo.mode(2) = '0' then
          if (fpo.mode(1 downto 0) = PRIV_LVL_M and r.csr.dfeaturesen.tmode_dis(0) = '0') or
             (fpo.mode(1 downto 0) = PRIV_LVL_S and r.csr.dfeaturesen.tmode_dis(1) = '0') or
             (fpo.mode(1 downto 0) = PRIV_LVL_U and r.csr.dfeaturesen.tmode_dis(2) = '0') then
            tfpuact := '1';
          end if;
        else
          if (fpo.mode(1 downto 0) = PRIV_LVL_S and r.csr.dfeaturesen.tmode_dis(3) = '0') or
             (fpo.mode(1 downto 0) = PRIV_LVL_U and r.csr.dfeaturesen.tmode_dis(4) = '0') then
            tfpuact := '1';
          end if;
        end if;
      end if;
    end if;

    -- Trace signals
    if TRACEBUF then
      -- Common signals are traced once only
      idata(399)              := r.csr.v;                                 -- Virtualization mode
      idata(253 downto 252)   := r.csr.prv;                               -- Privileged
      idata(247)              := xc_taken and xc_cause(xc_cause'high);    -- Interrupt Flag
      idata(246 downto 239)   := "000" & xc_cause(4 downto 0);            -- Exception Cause
      idata(238 downto 175)   := to64(xc_tval);                           -- Exception Value
      idata(174 downto 143)   := r.csr.mcycle(31 downto 0);               -- Timer Value
      for i in lanes'range loop
        idata(254 + i)        := r.x.ctrl(i).valid;
        idata(250 + i)        := '0';                                     -- Multi-cycle
        idata(248 + i)        := xc_taken and xc(i);                      -- Exception Flag
        idata(142 + i * 256 downto  96 + i * 256)   := pc_l(i);           -- VPC[47:1]
        -- When there is an FPU register destination, keep track of commit ID.
        -- Makes it possible to match with FPU write-back.
        if i = fpu_lane and is_fpu_rd(r.x.ctrl(i).inst) then
          idata( 36 + i * 256 downto  32 + i * 256) := r.x.ctrl(i).fpu;   -- FPU commit ID
        else
          idata( 95 + i * 256 downto  32 + i * 256) := to64(results(i));  -- Result
        end if;
        idata( 31 + i * 256 downto   0 + i * 256)   := r.x.ctrl(i).inst;  -- Instruction
      end loop;
      if r.x.swap = '1' then
        -- Swap lane signals
        for i in lanes'range loop
          j := lanes'high - i;
          idata(254 + i)      := r.x.ctrl(j).valid;
          idata(250 + i)      := '0';
          idata(248 + i)      := xc_taken and xc(j);
          idata(142 + i * 256 downto  96 + i * 256)   := pc_l(j);
          if i = fpu_lane and is_fpu_rd(r.x.ctrl(i).inst) then
            idata( 36 + i * 256 downto  32 + i * 256) := r.x.ctrl(j).fpu;
          else
            idata( 95 + i * 256 downto  32 + i * 256) := to64(results(j));
          end if;
          idata( 31 + i * 256 downto   0 + i * 256)   := r.x.ctrl(j).inst;
        end loop;
      end if;
      if holdn = '1' and tactive = '1' then
        write                 := (others => '1');
        enable                := holdn;
        tcnt                  := uadd(r.dm.tbufcnt, 1);
      elsif dmen = 1 and r.x.rstate = dhalt then
        enable                := '1';
        taddr                 := r.dm.tbufaddr;
      end if;

      if fpo.wen = '1' and tfpuact = '1' and
         not (dmen = 1 and r.x.rstate = dhalt) then
        -- Note FPU result.
        idata(400)                                  := '1';
        -- FPU operation ID, for matching with actual instruction.
        idata(405 downto 401)                       := fpo.wb_id;
        -- If nothing else is being recorded this cycle,
        -- make sure to note both instructions as invalid.
        if enable = '0' then
          idata(254 + 0)                            := '0';
          idata(254 + 1)                            := '0';
        end if;

        enable                                      := '1';
        write                                       := (others => '1');
        tcnt                                        := uadd(r.dm.tbufcnt, 1);

        -- Store FPU result in xc_tval if possible,
        -- else in the corresponding results field.
        if idata(248 + 0) = '0' then
          if idata(248 + 1) = '0' then
            idata(238 downto 175)                   := fpo.data;
          else
            idata(95 + 1 * 256 downto 32 + 1 * 256) := fpo.data;
          end if;
        else
          idata(95 + 0 * 256 downto 32 + 0 * 256)   := fpo.data;
        end if;
      end if;
    end if;

    -- Drive trace instruction interface
    di.data                        := idata;
    di.addr(TBUFBITS - 1 downto 0) := taddr;
    di.write                       := write;
    di.enable                      := enable;

    -- Drive output signals
    di_out    := di;
    di_2p_out := di_2p;
    tcnt_out  := tcnt;
  end;


  -- CSR instruction check
  -- Returns '1' if instruction accesses a CSR register.
  procedure csr_gen(inst_in : in  word;
                    valid   : out std_ulogic) is
    -- Non-constant
    variable vcsr : std_ulogic := '0';
  begin
    if is_csr(inst_in) then
      vcsr := '1';
    end if;

    valid  := vcsr;
  end;

  -- Fetch pmpcfg data
  function pmpcfg(csr : csr_reg_type; n : natural) return word8 is
    -- Non-constant
    type cfgv_type is array (0 to 15) of word8;
    variable cfgv   : cfgv_type;
    variable cfg    : word8 := (others => '0');
  begin
    for i in 0 to 7 loop
      cfgv(i)     := csr.pmpcfg0(i * 8 + 7 downto i * 8);
      cfgv(i + 8) := csr.pmpcfg2(i * 8 + 7 downto i * 8);
    end loop;

    if n < pmp_entries then
      cfg := cfgv(n);
    end if;

    return cfg;
  end;

  -- CSR Read
  -- CSR read unit located in register access stage.
  -- All read accesses are combinatorial accesses.
  procedure csr_read(csr_file  : in  csr_reg_type;
                     csra_in   : in  csratype;
                     csrv_in   : in  std_ulogic;
                     rstate_in : in  core_state;
                     iu_fflags : in  std_logic_vector;
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
        -- User Trap Setup
        when CSR_USTATUS =>
          if ext_n = 0 then
            xc := '1';
          else
            csr := to_ustatus(csr_file.mstatus);
          end if;
        when CSR_UIE | CSR_UTVEC =>
          if ext_n = 0 then
            xc := '1';
          end if;
        -- User Trap Handling
        when CSR_USCRATCH | CSR_UEPC | CSR_UCAUSE | CSR_UTVAL | CSR_UIP =>
          if ext_n = 0 then
            xc := '1';
          end if;
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
            csr(csr_file.fflags'range) := csr_file.fflags or iu_fflags;
            csr(csr_file.frm'range)    := csr_file.frm;
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
        -- Supervisor Trap Setup
        when CSR_SSTATUS        =>
          if h_en and csr_file.v = '1' then
            csr := to_vsstatus(csr_file.vsstatus);
          else
            csr := to_sstatus(csr_file.mstatus);
          end if;
          xc_v := vu_mode; -- virtual instruction exception
        when CSR_SEDELEG | CSR_SIDELEG =>
          if ext_n = 0 then
            xc := '1';
          else
            xc_v := vu_mode; -- virtual instruction exception
          end if;
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
        -- Supervisor Trap Handling
        when CSR_SEPC           =>
          if h_en and csr_file.v = '1' then
            csr := csr_file.vsepc;
          else
            csr := csr_file.sepc;
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
          if mode_s = 0 and ext_n = 0 then
            xc := '1';
          else
            csr := csr_file.medeleg;
          end if;
        when CSR_MIDELEG        =>
          if mode_s = 0 and ext_n = 0 then
            xc := '1';
          else
            csr := csr_file.mideleg;
          end if;
        when CSR_MIE            => csr := csr_file.mie;
        when CSR_MCOUNTEREN     => csr := to0x(csr_file.mcounteren);
        -- Machine Trap Handling
        when CSR_MSCRATCH       => csr := csr_file.mscratch;
        when CSR_MEPC           => csr := csr_file.mepc;
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
          csr := zerox;
          -- The time CSR is a read-only shadow of the memory-mapped mtime register.
          -- Implementations can convert reads of the time CSR into loads to the
          -- memory-mapped mtime register, or emulate this functionality in M-mode software.
          xc := '1';
        when CSR_TIMEH          =>
          csr := zerox;
          -- See CSR_TIME.
          xc := '1';
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
        when CSR_DFEATURESEN    =>
          csr(31)               := csr_file.dfeaturesen.tpbuf_en;
          csr(30 downto 26)     := csr_file.dfeaturesen.tmode_dis;
          csr(24)               := csr_file.dfeaturesen.nostream;
          csr(23 downto 16)     := csr_file.dfeaturesen.asi;
          csr(14)               := csr_file.dfeaturesen.staticdir;
          csr(12)               := csr_file.dfeaturesen.staticbp;
          csr(11)               := csr_file.dfeaturesen.mmu_adfault;
          csr(10)               := csr_file.dfeaturesen.pte_nocache;
          csr(9)                := csr_file.dfeaturesen.doasi;
          csr(6)                := csr_file.dfeaturesen.b2bsten;
          csr(5)                := csr_file.dfeaturesen.laluen;
          csr(4)                := csr_file.dfeaturesen.lbranchen;
          csr(3)                := csr_file.dfeaturesen.rasen;
          csr(2)                := csr_file.dfeaturesen.jprden;
          csr(1)                := csr_file.dfeaturesen.btben;
          csr(0)                := csr_file.dfeaturesen.dualen;
        when CSR_DFEATURESENH   =>
          if is_rv32 then
          else
            xc := '1';
          end if;
        when others =>
          case csra_high is
            -- Machine|User Hardware Performance Monitoring
            when CSR_CYCLE |         -- Base for counters.
                 CSR_MCYCLE =>
              -- CYCLE/TIME/INSTRET (0 - 2) handled above
              -- MCYCLE/MINSTRET    (0 & 2) handled above
              if csra_low = 1 then   -- There is no CSR_MTIME!
                xc := '1';
              else
                -- CSR_(M)HPMCOUNTER3-15
                if csra_low - 3 < perf_cnts then
                  csr := csr_file.hpmcounter(csra_low - 3)(wordx'range);
                end if;
              end if;
            when CSR_CYCLEH |         -- Base for counters.
                 CSR_MCYCLEH =>
              -- CYCLEH/TIMEH/INSTRETH (0 - 2) handled above
              -- MCYCLEH/MINSTRETH    (0 & 2) handled above
              if is_rv32 then
                if csra_low = 1 then   -- There is no CSR_MTIMEH!
                  xc := '1';
                else
                  -- CSR_(M)HPMCOUNTER3-15H
                  if csra_low - 3 < perf_cnts then
                    csr := to0x(csr_file.hpmcounter(csra_low - 3)(63 downto 32));
                  end if;
                end if;
              else
                xc := '1';
              end if;
            -- Machine|User Hardware Performance Monitoring (continued)
            when CSR_HPMCOUNTER16 |  -- All the higher counters.
                 CSR_MHPMCOUNTER16 =>
              -- CSR_(M)HPMCOUNTER16-31
              if csra_low - 3 + 16 < perf_cnts then
                csr := csr_file.hpmcounter(csra_low - 3 + 16)(wordx'range);
              end if;
            when CSR_HPMCOUNTER16H |  -- All the higher counters.
                 CSR_MHPMCOUNTER16H =>
              -- CSR_(M)HPMCOUNTER16-31H
              if is_rv32 then
                if csra_low - 3 + 16 < perf_cnts then
                  csr := to0x(csr_file.hpmcounter(csra_low - 3 + 16)(63 downto 32));
                end if;
              else
                xc := '1';
              end if;
            -- According to the RISC-V documentation, the value read back from
            -- CSR_PMPADDR<x> will depend on pmpcfg<x> setting under some circumstances.
            when CSR_PMPADDR0 =>
              if csra_low < pmp_entries then
                csr(pmp_msb - 2 downto 0) := csr_file.pmpaddr(csra_low)(pmp_msb - 2 downto 0);
                if pmpcfg(csr_file, csra_low)(4) = '1' then  -- NA4/NAPOT
                  csr(pmp_g - 2 downto 0) := (others => '1');
                else                                                     -- OFF/TOR
                  csr(pmp_g - 1 downto 0) := (others => '0');
                end if;
              end if;
            -- Machine Performance Monitoring Counter Selector
            when CSR_MCOUNTINHIBIT =>  -- MCOUNTINHIBIT/MHPMEVENT3-15
              if csra_low = 1 or       --  There is nothing at second/third position.
                 csra_low = 2 then
                xc := '1';
              else
                -- CSR_MHPMEVENT3-31
                if csra_low - 3 < perf_cnts then
                  csr := to0x(csr_file.hpmevent(csra_low - 3));
                end if;
              end if;
            when CSR_MHPMEVENT16 =>  -- MHPMEVENT16-31
              if csra_low - 3 + 16 < perf_cnts then
                csr := to0x(csr_file.hpmevent(csra_low - 3 + 16));
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
      priv_lvl := csr_file.prv and csra_in(9 downto 8);
      priv_lvlv:= csr_file.prv and csra_in(9 downto 8);
      if h_en and csr_file.v = '0' then
        priv_lvlv := (csr_file.prv(0) & csr_file.prv(1)) and csra_in(9 downto 8);
      end if;
        if (priv_lvl /= csra_in(9 downto 8) and
            priv_lvlv /= csra_in(9 downto 8)) then
          xc     := '1';
        end if;
        -- Debug Module Registers Access
        if csra_in(11 downto 4) = "01111011" then
          xc     := '1';
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
      csr      := zerox;
    end if;

    data_out   := csr;
    xc_out     := xc;
    if xc_v = '1' then
      cause_out  := XC_INST_VIRTUAL_INST;  -- Only valid when xc_out.
    else
      cause_out  := XC_INST_ILLEGAL_INST;  -- Only valid when xc_out.
    end if;
  end;

  -- ALU record generation
  -- Selects the type of operation and the control bits for that operation.
  procedure alu_gen(inst_in  : in  word;
                    valid_in : in  std_ulogic;
                    fusel_in : in  fuseltype;
                    valid    : out std_ulogic;
                    sel_out  : out word2;
                    ctrl_out : out word3) is
    variable op     : opcode_type := inst_in(6 downto 0);
    variable funct3 : funct3_type := inst_in(14 downto 12);
    -- Non-constant
    variable val    : std_ulogic  := '0';
    variable ctrl   : word3       := EXE_AND;     -- Default assignement
    variable sel    : word2       := ALU_LOGIC;   -- Default assignement
  begin
    -- Assuming the ALU is needed (based on the decoded fusel)
    case op is
      when LUI =>
        sel          := ALU_MISC;
        ctrl         := EXE_BYPASS2;
      when AUIPC | OP_LOAD | OP_STORE | OP_LOAD_FP | OP_STORE_FP =>
        sel          := ALU_MATH;
        ctrl         := EXE_ADD;
      when OP_IMM | OP_IMM_32 =>
        case funct3 is
          when I_ADDI =>
            sel      := ALU_MATH;
            if inst_in(3) = '1' then
              ctrl   := EXE_ADDW;
            else
              ctrl   := EXE_ADD;
            end if;
          when I_SLTI =>        -- Not used in case of OP_IMM_32
            sel      := ALU_MATH;
            ctrl     := EXE_SLT;
          when I_SLTIU =>       -- Not used in case of OP_IMM_32
            sel      := ALU_MATH;
            ctrl     := EXE_SLTU;
          when I_XORI =>        -- Not used in case of OP_IMM_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_XOR;
          when I_ORI =>         -- Not used in case of OP_IMM_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_OR;
          when I_ANDI =>        -- Not used in case of OP_IMM_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_AND;
          when I_SLLI =>
            sel      := ALU_SHIFT;
            if inst_in(3) = '1' then
              ctrl   := EXE_SLLW;
            else
              ctrl   := EXE_SLL;
            end if;
          when I_SRLI =>
            sel      := ALU_SHIFT;
            if inst_in(30) = '1' then -- SRAI, SRAIW
              if inst_in(3) = '1' then
                ctrl := EXE_SRAW;
              else
                ctrl := EXE_SRA;
              end if;
            else
              if inst_in(3) = '1' then
                ctrl := EXE_SRLW;
              else
                ctrl := EXE_SRL;
              end if;
            end if;
          when others =>
        end case;
      when OP_REG | OP_32 =>
        case funct3 is
          when R_ADD =>
            sel      := ALU_MATH;
            if inst_in(30) = '1' then -- SUB, SUBW
              if inst_in(3) = '1' then
                ctrl := EXE_SUBW;
              else
                ctrl := EXE_SUB;
              end if;
            else
              if inst_in(3) = '1' then
                ctrl := EXE_ADDW;
              else
                ctrl := EXE_ADD;
              end if;
            end if;
          when R_SLL =>
            sel       := ALU_SHIFT;
            if inst_in(3) = '1' then
              ctrl   := EXE_SLLW;
            else
              ctrl   := EXE_SLL;
            end if;
          when R_SLT =>         -- Not used in case of OP_32
            sel      := ALU_MATH;
            ctrl     := EXE_SLT;
          when R_SLTU =>        -- Not used in case of OP_32
            sel      := ALU_MATH;
            ctrl     := EXE_SLTU;
          when R_XOR =>         -- Not used in case of OP_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_XOR;
          when R_OR =>          -- Not used in case of OP_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_OR;
          when R_AND =>         -- Not used in case of OP_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_AND;
          when R_SRL =>
            sel      := ALU_SHIFT;
            if inst_in(30) = '1' then -- SRA, SRAW
              if inst_in(3) = '1' then
                ctrl := EXE_SRAW;
              else
                ctrl := EXE_SRA;
              end if;
            else
              if inst_in(3) = '1' then
                ctrl := EXE_SRLW;
              else
                ctrl := EXE_SRL;
              end if;
            end if;
          when others =>
        end case;
      when others =>
    end case;

    -- Valid Signal
    if valid_in = '1' and v_fusel_eq(fusel_in, ALU) then
      val    := '1';
    end if;

    ctrl_out := ctrl;
    sel_out  := sel;
    valid    := val;
  end;

  -- CSRALU record generation
  -- Selects the type of operation and the control bits for that operation.
  function csralu_gen(inst : word) return word2 is
    variable op     : opcode_type := inst(6 downto 0);
    variable funct3 : funct3_type := inst(14 downto 12);
    -- Non-constant
    variable ctrl   : word2       := CSR_BYPASS;
  begin
    -- Assuming the ALU is needed (based on the decoded fusel)
    case op is
      when OP_SYSTEM =>
        case funct3 is
          when I_CSRRS | I_CSRRSI => ctrl := CSR_SET;
          when I_CSRRC | I_CSRRCI => ctrl := CSR_CLEAR;
          when others             => null;             -- I_CSRRW | I_CSRRWI
        end case;
      when others                 => null;
    end case;

    return ctrl;
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
    variable op1      : wordx     := r.e.alui(lane).op1;
    variable op2      : wordx     := r.e.alui(lane).op2;
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
    variable op1      : wordx       := r.x.alui(lane).op1;
    variable op2      : wordx       := r.x.alui(lane).op2;
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
    variable op1      : wordx       := r.x.alui(lane).op1;
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
        if r.x.alui(0).lalu = '1' then
          mux_output_op1 := xc_data_in(0);
        else
          mux_output_op1 := r.x.result(0);
        end if;
      end if;
    elsif single_issue = 0 and
          xc_forw_op1 = "11" then
      if r.x.alui(one).lalu = '1' then
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
        if r.x.alui(0).lalu = '1' then
          mux_output_op2 := xc_data_in(0);
        else
          mux_output_op2 := r.x.result(0);
        end if;
      end if;
    elsif single_issue = 0 and
          xc_forw_op2 = "11" then
      if r.x.alui(one).lalu = '1' then
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
        if r.x.alui(0).lalu = '1' then
          mux_output_op1:= xc_data_in(0);
        else
          mux_output_op1:= r.x.result(0);
        end if;
      end if;
    elsif single_issue = 0 and
          xc_forw_op1 = "11" then
      if r.x.alui(one).lalu = '1' then
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
    if jump = '1' and inst_addr_misaligned(target) then
      jump_xc    := '1';
    end if;

    -- Decouple jump and memjump_xc to not affect the critical path.
    memjump_xc   := '0';
    if mem_jumpt = '1' and inst_addr_misaligned(target) then
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
    if jump = '1' and inst_addr_misaligned(target) then
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
    if valid = '1' and taken_in = '1' and inst_addr_misaligned(target) then
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
    if valid = '1' and taken_in = '1' and inst_addr_misaligned(target) then
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

  -- Branch Unit
  procedure branch_unit(op1_in    : in  wordx;
                        op2_in    : in  wordx;
                        valid_in  : in  std_ulogic;
                        branch_in : in  std_ulogic;
                        ctrl_in   : in  word3;
                        addr_in   : in  pctype;
                        npc_in    : in  pctype;
                        taken_in  : in  std_ulogic;
                        pc_in     : in  pctype;
                        valid_out : out std_ulogic;
                        mis_out   : out std_ulogic;
                        addr_out  : out pctype;
                        xc_out    : out std_ulogic;
                        cause_out : out cause_type;
                        tval_out  : out wordx) is
    -- Non-constant
    variable taken  : std_ulogic := '0';
    variable xc     : std_ulogic := '0';
    variable val    : std_ulogic := '0';
    variable tval   : wordx      := pc2xlen(addr_in);
    variable op1    : wordx1;
    variable op2    : wordx1;
    variable equal  : std_ulogic;
    variable less   : std_ulogic;
    variable target : pctype     := addr_in;
  begin
    -- Signed and unsigned comparison
    op1         := (not ctrl_in(1) and op1_in(op1_in'high)) & op1_in;
    op2         := (not ctrl_in(1) and op2_in(op2_in'high)) & op2_in;
    if signed(op1) < signed(op2) then
      less      := '1';
    else
      less      := '0';
    end if;

    if op1 = op2 then
      equal     := '1';
    else
      equal     := '0';
    end if;

    case ctrl_in is
      when B_BEQ          => taken :=     equal;
      when B_BNE          => taken := not equal;
      when B_BLT | B_BLTU => taken :=     less;
      when B_BGE | B_BGEU => taken := not less;
      when others =>
    end case;

    -- Raise valid signal
    if valid_in = '1' and branch_in = '1' then
      val       := '1';
    end if;

    -- Generate Output Branch Signal
    --                        taken
    --                  0       |       1
    --          0     0(xx)         1(addr_in)
    -- dir
    --          1    1(pc+4)          0(xx)

    -- Generate Target Address
    if  val = '1' and taken = '0' and taken_in = '1' then
      target    := npc_in;
    end if;

    -- Raise exception if branch taken and address is misaligned.
    if taken = '1' and val = '1' and inst_addr_misaligned(target) then
      xc        := '1';
    end if;

    valid_out   := val;
    mis_out     := taken xor taken_in;
    addr_out    := target;
    xc_out      := xc;
    cause_out   := XC_INST_ADDR_MISALIGNED;  -- Only valid when xc_out.
    tval_out    := tval;
  end;

  -- CSR operation
  function csralu_op(op1  : wordx;
                     op2  : wordx;
                     ctrl : word2) return wordx is
    -- Non-constant
    variable res : wordx;
  begin
    case ctrl is
      when CSR_SET   => res := op2 or      op1;   -- OR
      when CSR_CLEAR => res := op2 and not op1;   -- ANDN
      when others    => res := op1;               -- BYPASS1
    end case;

    return res;
  end;

  -- Logic operation
  function logic_op(op1  : wordx;
                    op2  : wordx;
                    ctrl : word3) return wordx is
    -- Non-constant
    variable res : wordx;
  begin
    case ctrl is
      when EXE_XOR   => res := op1 xor op2;
      when EXE_OR    => res := op1 or  op2;
      when EXE_AND   => res := op1 and op2;
      when others    => res := (others => '-');
    end case;

    return res;
  end;

  -- Misc operation
  function misc_op(op1  : wordx;
                   op2  : wordx;
                   ctrl : word3) return wordx is
    -- Non-constant
    variable res : wordx;
  begin
    case ctrl is
      when EXE_BYPASS2 => res := op2;
      when others      => res := (others => '-');
    end case;

    return res;
  end;

  -- Math operation
  -- ctrl(2)   -> size
  -- ctrl(1:0) -> op
  -- ctrl(0)   -> sgn for SLT and SLTU
  function math_op(op1_in : wordx;
                   op2_in : wordx;
                   ctrl   : word3) return wordx is
    -- Non-constant
    variable op1     : wordx1;  -- Manipulated from _in for efficiency.
    variable op2     : wordx1;
    variable add_res : wordx1;
    variable less    : std_ulogic;
    variable res     : wordx;
    variable tmp     : wordx;
  begin
    -- Select Operands
    op1         := op1_in & '1';
    op2         := op2_in & '0';
    case ctrl is
      when EXE_SUB | EXE_SUBW =>
        op2     := (op2_in & '0') xor (not zerox) & '1';
      when EXE_SLT | EXE_SLTU =>
        op1     := (ctrl(0) and op1_in(op1_in'high)) & op1_in;
        op2     := (ctrl(0) and op2_in(op2_in'high)) & op2_in;
      when others => -- EXE_ADD
    end case;

    -- Compute Results
    add_res     := uadd(op1, op2);   -- Carry fixed at 1
    if signed(op1) < signed(op2) then
      less      := '1';
    else
      less      := '0';
    end if;

    case ctrl(1 downto 0) is
      when "00" | "01" => res := add_res(add_res'high downto 1);    -- EXE_ADD | EXE_SUB
      when "11" | "10" => res := zerox(zerox'high downto 1) & less; -- EXE_SLT | EXE_SLTU
      when others      => null;
    end case;

    -- addw/subw?
    if is_rv64 and ctrl(2) = '0' then
      tmp              := res;
      res              := (others => res(31));
      res(31 downto 0) := tmp(31 downto 0);
    end if;

    return res;
  end;

  -- 64-bit shift operation
  function shift64(op  : std_logic_vector(127 downto 0);
                   cnt : std_logic_vector) return word64 is
    -- Non-constant
    variable shiftin : std_logic_vector(127 downto 0) := op;
  begin
    if cnt(5) = '1' then shiftin(95 downto 0) := shiftin(127 downto 32); end if;
    if cnt(4) = '1' then shiftin(79 downto 0) := shiftin( 95 downto 16); end if;
    if cnt(3) = '1' then shiftin(71 downto 0) := shiftin( 79 downto  8); end if;
    if cnt(2) = '1' then shiftin(67 downto 0) := shiftin( 71 downto  4); end if;
    if cnt(1) = '1' then shiftin(65 downto 0) := shiftin( 67 downto  2); end if;
    if cnt(0) = '1' then shiftin(63 downto 0) := shiftin( 64 downto  1); end if;

    return shiftin(63 downto 0);
  end;

  -- 32-bit shift operation
  function shift32(op  : word64;
                   cnt : std_logic_vector) return word64 is
    -- Non-constant
    variable shiftin : word64 := op;
    variable pad     : word;
  begin
    if cnt(4) = '1' then shiftin(47 downto 0) := shiftin(63 downto 16); end if;
    if cnt(3) = '1' then shiftin(39 downto 0) := shiftin(47 downto  8); end if;
    if cnt(2) = '1' then shiftin(35 downto 0) := shiftin(39 downto  4); end if;
    if cnt(1) = '1' then shiftin(33 downto 0) := shiftin(35 downto  2); end if;
    if cnt(0) = '1' then shiftin(31 downto 0) := shiftin(32 downto  1); end if;

    pad                   := (others => shiftin(31));
    shiftin(63 downto 32) := pad;

    return shiftin;
  end;

  -- Shift operation
  -- ctrl(2) -> size
  -- ctrl(1) -> arithmetic
  -- ctrl(0) -> direction
  function shift_op(op1  : wordx;
                    op2  : wordx;
                    ctrl : word3) return wordx is
    -- Non-constant
    variable shiftin64 : std_logic_vector(127 downto 0) := zerow64 & zerow64;
    variable shiftin32 : word64                         := zerow   & op1(word'range);
    variable cnt       : std_logic_vector(  5 downto 0) := op2(5 downto 0);
    variable res32     : word64;
    variable res64     : word64;
  begin
    if is_rv64 then
      shiftin64 := zerow64 & to64(op1);
    end if;
    case ctrl(1 downto 0) is
      when "00" => -- SLL
        if is_rv64 then
          shiftin64( 63 downto  0) := zerow64;
          shiftin64(127 downto 63) := '0' & to64(op1);
        end if;
        shiftin32( 31 downto  0)   := zerow;
        shiftin32( 63 downto 31)   := '0' & op1(word'range);
        cnt                        := not op2(5 downto 0);
      when "11" => -- SRA
        if is_rv64 then
          shiftin64(127 downto 64) := (others => op1(op1'high));
        end if;
        shiftin32( 63 downto 32)   := (others => op1(31));
      when others => -- SRL
    end case;

    res32 := shift32(shiftin32, cnt(4 downto 0));
    res64 := shift64(shiftin64, cnt);

    if is_rv64 then
      if ctrl(2) = '1' then
        return res64(wordx'range);
      else
        return res32(wordx'range);
      end if;
    else
      return res32(wordx'range);
    end if;
  end;

  -- ALU Execute
  procedure alu_execute(op1_in    : in  wordx;
                        op2_in    : in  wordx;
                        valid_in  : in  std_ulogic;
                        ctrl_in   : in  word3;
                        alusel_in : in  word2;
                        valid_out : out std_ulogic;
                        res_out   : out wordx) is
    variable alu_math_res  : wordx := math_op( op1_in, op2_in, ctrl_in);
    variable alu_shift_res : wordx := shift_op(op1_in, op2_in, ctrl_in);
    variable alu_logic_res : wordx := logic_op(op1_in, op2_in, ctrl_in);
    variable alu_misc_res  : wordx := misc_op( op1_in, op2_in, ctrl_in);
    -- Non-constant
    variable res           : wordx := zerox;
  begin
    case alusel_in is
      when ALU_MATH     => res := alu_math_res;
      when ALU_SHIFT    => res := alu_shift_res;
      when ALU_LOGIC    => res := alu_logic_res;
      when others       => res := alu_misc_res; -- ALU_MISC
    end case;

    valid_out   := valid_in;
    res_out     := res;
  end;

  -- Address generation for Load/Store unit.
  procedure addr_gen(inst_in   : in  word;
                     fusel_in  : in  fuseltype;
                     valid_in  : in  std_ulogic;
                     op1_in    : in  wordx;
                     op2_in    : in  wordx;
                     address   : out wordx;
                     xc_out    : out std_ulogic;
                     cause_out : out cause_type;
                     tval_out  : out wordx) is
    variable funct3 : funct3_type := inst_in(14 downto 12);
    variable size   : word2       := funct3(1 downto 0);
    -- Non-constant
    variable xc     : std_ulogic  := '0';
    variable cause  : cause_type  := (others => '0');
    variable add    : wordx1;
  begin
    if (ext_a /= 0 and v_fusel_eq(fusel_in, AMO)) or
       (ext_h /= 0 and
        (is_hlv(inst_in) or is_hsv(inst_in) or
         is_hfence_vvma(inst_in) or is_hfence_gvma(inst_in))) or
       is_sfence_vma(inst_in) then
      add     := '0' & op1_in;
    else
      add     := std_logic_vector(signed('0' & op1_in) +
                                  signed(op2_in(op2_in'high) & op2_in));
    end if;

    if ext_h /= 0 and (is_hlv(inst_in) or is_hsv(inst_in)) then
      size    := inst_in(27 downto 26);
    end if;

    -- Do not check for sfence.vma here, since it does not actually access anything.
    if v_fusel_eq(fusel_in, LD or ST or AMO) and data_addr_misaligned(add, size) then
      xc        := '1';
      cause     := XC_INST_LOAD_ADDR_MISALIGNED;
      if v_fusel_eq(fusel_in, ST) then
        cause   := XC_INST_STORE_ADDR_MISALIGNED;
      end if;
      -- Make misaligned atomics throw access faults so that no emulation
      -- is attempted (allowed according to the RISC-V standard.)
      if ext_a /= 0 and v_fusel_eq(fusel_in, AMO) then
        cause   := XC_INST_STORE_ACCESS_FAULT;
        if inst_in(28) = '1' and inst_in(27) = '0' then     -- LR?
          cause := XC_INST_LOAD_ACCESS_FAULT;
        end if;
      end if;
    end if;

    address   := add(address'range);
    xc_out    := xc and valid_in;
    cause_out := cause;
    tval_out  := add(tval_out'range);
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
    if dfeaturesen.doasi = '0' then
      dci.asi  := "00001010";
    else
      dci.asi  := dfeaturesen.asi;
    end if;

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
      -- We encode a fence_i instruction in an instruction
      -- that flushes and enables both caches.
      elsif is_fence_i(inst_in) then
        dci.asi         := "00000010";
        dci.write       := '1';
        dci.enaddr      := '1';
        dci.size        := "10";
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
      end if;
    end if;

    dci_out := dci;
  end;

  -- Load aligner for 64-bit word
  function ld_align64(data   : word64;
                      size   : word2;
                      laddr  : word3;
                      signed : std_ulogic) return word64 is
    -- Non-constant
    variable rdata   : word64 := (others => '0');
    variable rdata64 : word64 := data;
  begin
    if true or ENDIAN_B then
      case size is
      when SZBYTE => -- byte read
        case laddr(2 downto 0) is
          when "000"  => rdata(7 downto 0) := data( 7 downto  0);
          when "001"  => rdata(7 downto 0) := data(15 downto  8);
          when "010"  => rdata(7 downto 0) := data(23 downto 16);
          when "011"  => rdata(7 downto 0) := data(31 downto 24);
          when "100"  => rdata(7 downto 0) := data(39 downto 32);
          when "101"  => rdata(7 downto 0) := data(47 downto 40);
          when "110"  => rdata(7 downto 0) := data(55 downto 48);
          when others => rdata(7 downto 0) := data(63 downto 56);
        end case;
        if signed = '1' then rdata(63 downto 8) := (others => rdata(7)); end if;
        rdata64 := rdata;

      when SZHALF => -- half-word read
        case laddr(2 downto 1) is
          when "00"   => rdata(15 downto 0) := data(15 downto  0);
          when "01"   => rdata(15 downto 0) := data(31 downto 16);
          when "10"   => rdata(15 downto 0) := data(47 downto 32);
          when others => rdata(15 downto 0) := data(63 downto 48);
        end case;
        if signed = '1' then rdata(63 downto 16) := (others => rdata(15)); end if;
        rdata64 := rdata;

      when SZWORD => -- single word read
        if laddr(2) = '0' then rdata(31 downto 0) := data(31 downto  0);
        else                   rdata(31 downto 0) := data(63 downto 32);
        end if;
        if signed = '1' then rdata(63 downto 32) := (others => rdata(31)); end if;
        rdata64 := rdata;

      when others => -- double word read
      end case;
    else
      case size is
      when SZBYTE => -- byte read
        case laddr(2 downto 0) is
          when "000"  => rdata(7 downto 0) := data(63 downto 56);
          when "001"  => rdata(7 downto 0) := data(55 downto 48);
          when "010"  => rdata(7 downto 0) := data(47 downto 40);
          when "011"  => rdata(7 downto 0) := data(39 downto 32);
          when "100"  => rdata(7 downto 0) := data(31 downto 24);
          when "101"  => rdata(7 downto 0) := data(23 downto 16);
          when "110"  => rdata(7 downto 0) := data(15 downto  8);
          when others => rdata(7 downto 0) := data( 7 downto  0);
        end case;
        if signed = '1' then rdata(63 downto 8) := (others => rdata(7)); end if;
        rdata64 := rdata;

      when SZHALF => -- half-word read
        case laddr(2 downto 1) is
          when "00"   => rdata(15 downto 0) := data(63 downto 48);
          when "01"   => rdata(15 downto 0) := data(47 downto 32);
          when "10"   => rdata(15 downto 0) := data(31 downto 16);
          when others => rdata(15 downto 0) := data(15 downto  0);
        end case;
        if signed = '1' then rdata(63 downto 16) := (others => rdata(15)); end if;
        rdata64 := rdata;

      when SZWORD => -- single word read
        if laddr(2) = '0' then rdata(31 downto 0) := data(63 downto 32);
        else                   rdata(31 downto 0) := data(31 downto 0);
        end if;
        if signed = '1' then rdata(63 downto 32) := (others => rdata(31)); end if;
        rdata64 := rdata;

      when others => -- double word read
      end case;
    end if;

    return rdata64;
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

    if is_fence_i(r.m.ctrl(0).inst) then
      data(31 downto 0)  := x"0081000f";
      data(63 downto 32) := x"0081000f";
    end if;

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
      if v_fusel_eq(r, x, 0, ST) then
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
        cause        := causes(1);
        tval         := tvals(1);
        flush        := "11";           -- flush both
        xc_lane_out  := '1';
      elsif xcs(0) = '1' and r.x.ctrl(0).valid = '1' then
        xc           := '1';
        pc           := r.x.ctrl(0).pc;
        cause        := causes(0);
        tval         := tvals(0);
        flush        := "01";           -- flush lane 0 only
      end if;
    else
      if    xcs(0) = '1' and r.x.ctrl(0).valid = '1' then
        xc           := '1';
        pc           := r.x.ctrl(0).pc;
        cause        := causes(0);
        tval         := tvals(0);
        flush        := "11";           -- flush both
      elsif single_issue = 0 and
            xcs(1) = '1' and r.x.ctrl(1).valid = '1' then
        xc           := '1';
        pc           := r.x.ctrl(1).pc;
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
      if cause = XC_INST_INST_G_PAGE_FAULT then
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

  procedure trigger_update(csr_in    : in  csr_reg_type;
                           v_wb_ctrl : in  pipeline_ctrl_lanes_type;
                           trig_in   : in  trig_type;
                           csr_out   : out csr_reg_type) is
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
  procedure exception_flow(pc_in     : in  pctype;
                           xc_in     : in  std_ulogic;
                           cause_in  : in  cause_type;
                           tval_in   : in  wordx;
                           tval2_in  : in  wordx;
                           gva_in    : in  std_ulogic;
                           ret_in    : in  std_logic_vector;
                           csr_in    : in  csr_reg_type;
                           rcsr_in   : in  csr_reg_type;
                           rstate_in : in  core_state;
                           csr_out   : out csr_reg_type;
                           tvec_out  : out pctype) is
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
    if (    is_irq(cause_in) and rcsr_in.mideleg(u2i(cause_in(CAUSEBITS-1 downto 0))) = '1') or
       (not is_irq(cause_in) and rcsr_in.medeleg(u2i(cause_in(CAUSEBITS-1 downto 0))) = '1') then
      if (rcsr_in.prv = PRIV_LVL_S or rcsr_in.prv = PRIV_LVL_U) then
        trap_prv       := PRIV_LVL_S;
        if h_en and rcsr_in.v = '1' then -- Hypervisor extension
          if (    is_irq(cause_in) and rcsr_in.hideleg(u2i(cause_in(CAUSEBITS-1 downto 0))) = '1') or
             (not is_irq(cause_in) and rcsr_in.hedeleg(u2i(cause_in(CAUSEBITS-1 downto 0))) = '1') then
            trap_v := '1';
            if is_irq(cause_in) then
              if cause_in = IRQ_VS_EXTERNAL then
                -- When delegated to VS-mode: transformed into supervisor external interrupt
                cause_v := IRQ_S_EXTERNAL;
              elsif cause_in = IRQ_VS_SOFTWARE then
                -- When delegated to VS-mode: transformed into supervisor software interrupt
                cause_v := IRQ_S_SOFTWARE;
              elsif cause_in = IRQ_VS_TIMER then
                -- When delegated to VS-mode: transformed into supervisor timer interrupt
                cause_v := IRQ_S_TIMER;
              end if;
            end if;
          end if;
        --elsif ext_n = 1 and rcsr_in.prv = PRIV_LVL_U then -- User Mode interrupts (N extension)
        --  if (    is_irq(cause_in) and rcsr_in.sideleg(u2i(cause_in(CAUSEBITS-1 downto 0))) = '1') or
        --     (not is_irq(cause_in) and rcsr_in.sedeleg(u2i(cause_in(CAUSEBITS-1 downto 0))) = '1') then
        --    trap_prv := PRIV_LVL_U;
        end if;
      end if;
    end if;
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
      if ret_in = "00" then   -- Do not update on xret instruction.
        csr.vscause     := cause2wordx(cause_v);
        csr.vsepc       := pc2xlen(pc_in);
        csr.vstval      := tval_in;
      end if;
    --elsif trap_prv = PRIV_LVL_U then -- trapping to U Mode (N extension)
    elsif trap_prv = PRIV_LVL_S then -- trapping to S/HS Mode
      csr.mstatus.spie := csr_in.mstatus.sie;
      csr.mstatus.sie  := '0';
      csr.mstatus.spp  := prv_lvl(0);
      -- H-ext
      csr.hstatus.spv  := csr_in.v;
      csr.hstatus.gva  := gva_in;
      if rcsr_in.v = '1' then
        csr.hstatus.spvp := prv_lvl(0);
      end if;
      if ret_in = "00" then   -- Do not update on xret instruction.
        csr.scause     := cause2wordx(cause_in);
        csr.sepc       := pc2xlen(pc_in);
        csr.stval      := tval_in;
        -- H-ext
        csr.htval      := tval2_in;
        --csr.htinst     := tinst_in;
      end if;
    else -- trapping to Machine Mode
      csr.mstatus.mpie := csr_in.mstatus.mie;
      csr.mstatus.mie  := '0';
      csr.mstatus.mpp  := csr_in.prv;
      -- H-ext
      if csr_in.prv /= PRIV_LVL_M then
        csr.mstatus.mpv := csr_in.v;
      end if;
      csr.mstatus.gva  := gva_in;
      if ret_in = "00" then   -- Do not update on xret instruction.
        csr.mcause     := cause2wordx(cause_in);
        csr.mepc       := pc2xlen(pc_in);
        csr.mtval      := tval_in;
        -- H-ext
        csr.mtval2     := tval2_in;
        --csr.mtinst     := tinst_in;
      end if;
    end if;

    -- Set privilege mode
    prv_lvl := trap_prv;
    prv_v   := trap_v;


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
      if prv_lvl /= PRIV_LVL_M then
        csr.mstatus.mpv  := '0';
      end if;
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
          tvec  := cause2vec(cause_in, tvec);
        end if;
      end if;
    end if;

    -- Return Instructions
    if ret_in = "11" then
      tvec    := to_addr(rcsr_in.mepc);
    elsif ret_in = "01" then
      tvec    := to_addr(rcsr_in.sepc);
      if rcsr_in.v = '1' then
        tvec    := to_addr(rcsr_in.vsepc);
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
      -- User Trap Setup
      when CSR_USTATUS | CSR_UIE | CSR_UTVEC =>
        if ext_n = 0 then
          xc := '1';
        end if;
      -- User Trap Handling
      when CSR_USCRATCH | CSR_UEPC | CSR_UCAUSE | CSR_UTVAL | CSR_UIP =>
        if ext_n = 0 then
          xc := '1';
        end if;
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
      -- Supervisor Trap Setup
      when CSR_SSTATUS        =>
      when CSR_SEDELEG | CSR_SIDELEG =>
        if ext_n = 0 then
          xc := '1';
        end if;
      when CSR_SIE            =>
      when CSR_STVEC          =>
      when CSR_SCOUNTEREN     =>
      -- Supervisor Trap Handling
      when CSR_SSCRATCH       =>
      when CSR_SEPC           =>
      when CSR_SCAUSE         =>
      when CSR_STVAL          =>
      when CSR_SIP            =>
      -- Supervisor Protection and Translation
      when CSR_SATP           =>
      -- Machine Trap Setup
      when CSR_MSTATUS        =>
      when CSR_MSTATUSH       =>
        if is_rv64 then
          xc := '1';
        end if;
      when CSR_MISA           =>
      when CSR_MEDELEG        =>
        if mode_s = 0 and ext_n = 0 then
          xc := '1';
        end if;
      when CSR_MIDELEG        =>
        if mode_s = 0 and ext_n = 0 then
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
      when CSR_DFEATURESEN =>
      when CSR_DFEATURESENH =>
        if is_rv64 then
          xc := '1';
        end if;
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
  function csr_write_xc(csra   : csratype;
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
        xc := '1';
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
                      csraxc_in        : in  std_ulogic;
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


      return pmpcfg(csr, n)(7);
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
          pmpcfg02(i * 8 + 7 downto i * 8) := pmpcfg_b;
          -- W without R is reserved!
          if pmpcfg_b(1 downto 0) = "10" then
            pmpcfg02(i * 8 + 1)            := '0';
          end if;
          if pmp_g > 0 then
            -- NA4 not possible!
            if pmpcfg_b(4 downto 3) = "10" then
              pmpcfg02(i * 8 + 4)          := '0';      -- Clear to OFF
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
                pmp_entries, pmp_no_tor, pmp_g);

    if writen = '1' and xc = '0' then
      case csra is
        -- User Trap Setup
        when CSR_USTATUS        =>
          mstatus     := to_ustatus(wcsr_in, csr_file.mstatus);
          csr.mstatus := tie_status(mstatus, csr_file.misa);
        when CSR_UIE | CSR_UTVEC =>
        -- User Trap Handling
        when CSR_USCRATCH | CSR_UEPC | CSR_UCAUSE | CSR_UTVAL | CSR_UIP =>
        -- User Floating-Point CSRs
        when CSR_FFLAGS         =>
          csr.fflags     := wcsr_in(csr.fflags'length - 1 downto 0);
          csr.mstatus.fs := "11";
        when CSR_FRM            =>
          csr.frm        := wcsr_in(csr.frm'length - 1 downto 0);
          csr.mstatus.fs := "11";
        when CSR_FCSR           =>
          csr.fflags     := wcsr_in(csr.fflags'range);
          csr.frm        := wcsr_in(csr.frm'range);
          csr.mstatus.fs := "11";
        -- Hypervisor Trap Setup
        when CSR_HSTATUS        => csr.hstatus      := to_hstatus(wcsr_in);
        when CSR_HEDELEG        => csr.hedeleg      := wcsr_in and CSR_HEDELEG_MASK;
        when CSR_HIDELEG        => csr.hideleg      := wcsr_in and CSR_HIDELEG_MASK;
        when CSR_HIE            => csr.mie          := (csr_file.mie and not CSR_HIDELEG_MASK) or
                                                       (wcsr_in and CSR_HIDELEG_MASK);
        when CSR_HCOUNTEREN     =>
            csr.hcounteren(HWPERFMONITORS + 2 downto 0) := wcsr_in(HWPERFMONITORS + 2 downto 0);
        when CSR_HGEIE          =>
            csr.hgeie(GEILEN downto 1)              := wcsr_in(GEILEN downto 1);
        -- Hypervisor Trap Handling
        when CSR_HTVAL          => csr.htval        := wcsr_in;
        when CSR_HIP            =>
          -- only hip(2) VSSIP is writable
          -- mip(2) is aliased in hip(2) and hvip(2)
          csr.mip(2)        := wcsr_in(2);
        when CSR_HVIP           =>
          -- mip(2) is aliased in hip(2) and hvip(2)
          csr.hvip(10)      := wcsr_in(10);
          csr.hvip(6)       := wcsr_in(6);
          csr.mip(2)        := wcsr_in(2);
        when CSR_HTINST         => csr.htinst       := wcsr_in;
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
        when CSR_HTIMEDELTA     =>
          csr.htimedelta(wordx'range)    := wcsr_in;
        when CSR_HTIMEDELTAH    =>
          if is_rv32 then
            csr.htimedelta(63 downto 32) := wcsr_in(word'range);
          end if;
        -- Virtual Supervisor Registers
        when CSR_VSSTATUS       => csr.vsstatus     := to_vsstatus(wcsr_in);
        when CSR_VSIE           =>
          csr.mie(10)                               := (csr_file.mie(10) and not csr_file.hideleg(10)) or
                                                       (wcsr_in(9) and csr_file.hideleg(10));
          csr.mie(6)                                := (csr_file.mie(6) and not csr_file.hideleg(6)) or
                                                       (wcsr_in(5) and csr_file.hideleg(6));
          csr.mie(2)                                := (csr_file.mie(2) and not csr_file.hideleg(2)) or
                                                       (wcsr_in(1) and csr_file.hideleg(2));
        when CSR_VSTVEC         => csr.vstvec       := wcsr_in(csr.vstvec'high downto 2) & '0' & wcsr_in(0);
        when CSR_VSSCRATCH      => csr.vsscratch    := wcsr_in;
        when CSR_VSEPC          => csr.vsepc        := wcsr_in(csr.vsepc'high downto 1) & '0';
        when CSR_VSCAUSE        => csr.vscause      := wcsr_in;
        when CSR_VSTVAL         => csr.vstval       := wcsr_in;
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
          else
            csr.sepc         := wcsr_in(csr.sepc'high downto 1) & '0';
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
            if csr_file.mideleg(1) = '1' then -- only visiable in SIP when delegated
              csr.mip(1)     := wcsr_in(1); -- Others RO
            end if;
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
            csr.misa := mask_misa(csr_file.misa, wcsr_in);
            -- If MISA is changed, a pipeline flush is required.
            if csr.misa /= csr_file.misa then
              pipeflush  := '1';
            end if;
          end if;
        when CSR_MEDELEG        => csr.medeleg      := wcsr_in and medeleg_mask(h_en);
        when CSR_MIDELEG        => csr.mideleg      := to_mideleg(wcsr_in, mode_s, h_en, ext_n);
        when CSR_MIE            => csr.mie          := wcsr_in and mie_mask(mode_s, h_en, ext_n);
        when CSR_MTVEC          =>
          mtvec                                     := wcsr_in(mtvec'high downto 2) & '0' & wcsr_in(0);
          if wcsr_in(0) = '1' then
            mtvec                                   := wcsr_in(mtvec'high downto 8) & "0000000" & wcsr_in(0);
          end if;
          csr.mtvec                                 := mtvec;
        when CSR_MCOUNTEREN     =>
          csr.mcounteren(HWPERFMONITORS + 2 downto 0) := wcsr_in(HWPERFMONITORS + 2 downto 0);
        -- Machine Trap Handling
        when CSR_MSCRATCH       => csr.mscratch     := wcsr_in;
        when CSR_MEPC           =>
          csr.mepc                                  := wcsr_in(csr.mepc'high downto 1) & '0';
          if ext_c = 0 then
            csr.mepc(1)                             := '0';
          end if;
        when CSR_MCAUSE         => csr.mcause       := wcsr_in(csr.mcause'range);
        when CSR_MTVAL          => csr.mtval        := wcsr_in;
        when CSR_MIP            => csr.mip          := wcsr_in and mip_mask(mode_s, h_en, ext_n);
        when CSR_MTINST         => csr.mtinst       := wcsr_in;
        when CSR_MTVAL2         => csr.mtval2       := wcsr_in;
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
        when CSR_DFEATURESEN =>
          csr.dfeaturesen.tpbuf_en                  := wcsr_in(31);
          csr.dfeaturesen.tmode_dis                 := wcsr_in(30 downto 26);
          --access to doasi in run mode = 0         := wcsr_in(25);
          csr.dfeaturesen.nostream                  := wcsr_in(24);
          csr.dfeaturesen.asi                       := wcsr_in(23 downto 16);
          --access to doasi in run mode = 1         := wcsr_in(15);
          csr.dfeaturesen.staticdir                 := wcsr_in(14);
          csr.dfeaturesen.staticbp                  := wcsr_in(12);
          csr.dfeaturesen.mmu_adfault               := wcsr_in(11);
          csr.dfeaturesen.pte_nocache               := wcsr_in(10);
          if (rstate_in /= run) or (wcsr_in(15) ='1' and wcsr_in(25) = '0') then
            csr.dfeaturesen.doasi                   := wcsr_in(9);
          else
            csr.dfeaturesen.doasi                   := '0';
          end if;
          csr.dfeaturesen.b2bsten                   := wcsr_in(6);
          csr.dfeaturesen.laluen                    := wcsr_in(5);
          csr.dfeaturesen.lbranchen                 := wcsr_in(4);
          csr.dfeaturesen.rasen                     := wcsr_in(3);
          csr.dfeaturesen.jprden                    := wcsr_in(2);
          csr.dfeaturesen.btben                     := wcsr_in(1);
          csr.dfeaturesen.dualen                    := wcsr_in(0);
          pipeflush := '1';
          addrflush := '1';
        when CSR_DFEATURESENH =>
          if is_rv32 then
          end if;
        when others =>
          case csra_high is
            -- Machine Hardware Performance Monitoring
            when CSR_MCYCLE =>         -- Base for counters.
              -- MCYCLE/MINSTRET    (0 & 2) handled above
              if csra_low /= 1 then    -- There is no CSR_MTIME!
                -- CSR_(M)HPMCOUNTER3-15
                if csra_low - 3 < perf_cnts then
                  csr.hpmcounter(csra_low - 3)(wordx'range) := wcsr_in;
                  upd_counter(csra_low - 3) := '1';
                end if;
              end if;
            when CSR_MCYCLEH =>        -- Base for counters.
              -- MCYCLEH/MINSTRETH  (0 & 2) handled above
              if is_rv32 and csra_low /= 1 then    -- There is no CSR_MTIMEH!
                -- CSR_(M)HPMCOUNTER3-15H
                if csra_low - 3 < perf_cnts then
                  csr.hpmcounter(csra_low - 3)(63 downto 32) := wcsr_in(word'range);
                  upd_counter(csra_low - 3) := '1';
                end if;
              end if;
            -- Machine Hardware Performance Monitoring (continued)
            when CSR_MHPMCOUNTER16 =>  -- All the higher counters.
              -- CSR_(M)HPMCOUNTER16-31
              if csra_low - 3 + 16 < perf_cnts then
                csr.hpmcounter(csra_low - 3 + 16)(wordx'range) := wcsr_in;
                upd_counter(csra_low - 3 + 16) := '1';
              end if;
            when CSR_MHPMCOUNTER16H => -- All the higher counters.
              -- CSR_(M)HPMCOUNTER16-31H
              if is_rv32 and csra_low - 3 + 16 < perf_cnts then
                csr.hpmcounter(csra_low - 3 + 16)(63 downto 32) := wcsr_in(word'range);
                upd_counter(csra_low - 3 + 16) := '1';
              end if;
            -- Machine Hardware Performance Monitoring Event Selector
            when CSR_MCOUNTINHIBIT =>  -- MCOUNTINHIBIT/MHPMEVENT3-15
              if csra_low = 1 or       --  There is nothing at second/third position.
                 csra_low = 2 then
                null;
              else
                -- CSR_MHPMEVENT3-31
                if csra_low - 3 < perf_cnts then
                  csr.hpmevent(csra_low - 3)    := wcsr_in(csr.hpmevent(0)'range);
                end if;
              end if;
            when CSR_MHPMEVENT16 =>    -- MHPMEVENT16-31
              if csra_low - 3 + 16 < perf_cnts then
                csr.hpmevent(csra_low - 3 + 16) := wcsr_in(csr.hpmevent(0)'range);
              end if;
            when CSR_PMPADDR0 =>
              if pmp_locked(csr, csra_low) = '0' and            -- Not locked?
                 (csra_low = 15 or
                  not (pmp_locked(csr, csra_low + 1) = '1' and   -- Neither is next TOR and locked?
                       pmpcfg(csr, csra_low + 1)(4 downto 3) = "01")) then
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
          if r.e.alui(i).lalu = '1' then
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
        if r.e.alui(csr_lane).lalu = '1' then
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
      if r.e.alui(j).lalu = '1' then
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
        if r.e.alui(j).lalu = '1' then
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
      if r.e.alui(csr_lane).lalu = '1' then
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
        if r.m.alui(j).lalu = '1' then
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
      if r.m.alui(csr_lane).lalu = '1' then
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

    -- MUL in EX followed by a dependent instruction in AR.
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
    --   write to satp (pageing may be turned on/off)
    ---------------------------------------------------------------------------
    exechold := '0' & exechold(0 to exechold'right - 1);
    if csr_ok(r, e) and not csr_read_only(r, e) and csr(r, e).category(7) = '1' then
      exechold   := (exechold'range => '1');
    end if;
    if r.e.ctrl(memory_lane).valid = '1' then
      -- fence.i or sfence.vma
      if is_fence_i(r.e.ctrl(memory_lane).inst) or is_sfence_vma(r.e.ctrl(memory_lane).inst) then
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
    ---------------------------------------------------------------------------
    if ext_f = 1 then
      if r.a.ctrl(memory_lane).valid = '1' and r.a.ctrl(memory_lane).inst(6 downto 0) = OP_STORE_FP then
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
           r.csr.dfeaturesen.b2bsten = '0')) or
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
    -- time for nullify signals hence it has to be at least 2 cycles behind a late
    -- brancha
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
    -- Disable advanced features
    ---------------------------------------------------------------------------

    if (r.csr.dfeaturesen.lbranchen = '0' or late_branch = 0) and lbranch = '1' then
      hold      := '1';
      hvec(12)  := '1';
    end if;

    if (r.csr.dfeaturesen.laluen = '0' or late_alu = 0) and not all_0(lalu) then
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
    lbrancho    := lbranch and r.csr.dfeaturesen.lbranchen;
    laluo       := lcsr or (lalu and (lalu'range => r.csr.dfeaturesen.laluen));
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
                    issued_in   : in  std_ulogic;
                    nready_in   : in  std_ulogic;
                    hold_in     : in  std_ulogic;
                    hold_out    : out std_ulogic) is
    -- Non-constant
    variable hold   : std_ulogic  := '0';
  begin
    if ext_f = 1 then
      if valid_in = '1' and issued_in = '0' and (is_fpu(inst_in) or is_fpu_mem(inst_in)) then
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
      if r.m.alui(1).lalu = '0' then
        -- Do not forward directly from MUL.
        -- Handled by forwarding in a later cycle instead.
        if not v_fusel_eq(r, m, 1, MUL or FPU) then
          mem_forw_op2  := "11";
        end if;
      end if;
    elsif v_rd_eq(r, m,  0, rfa2) then
      -- Do not forward directly from late ALU.
      if r.m.alui(0).lalu = '0' then
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
      if r.x.alui(1).lalu = '0' then
        xc_forw_op2     := "11";
      end if;
    elsif v_rd_eq(r, x,  0, rfa2) then
      -- Do not forward directly from late ALU.
      -- Handled by forwarding in next cycle instead.
      if r.x.alui(0).lalu = '0' then
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
    if r.x.ctrl(0).valid = '1' then
      if is_fence_i(r.x.ctrl(0).inst) or is_sfence_vma(r.x.ctrl(0).inst) then
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
    if r.wb.flushall = '0' and r.wb.fence_flush = '1' and r.wb.ctrl(0).valid = '1' then
      flush   := '1';
    end if;

    flush_out := flush;
    pc_out    := pc;
  end;

  -- Instruction Buffer Control Logic
  procedure buffer_ic(r            : in  registers;
                      valid_in     : in  std_logic_vector;
                      dvalid_in    : in  std_logic_vector;
                      buffer_third : in  std_ulogic;
                      buffer_sec   : in  std_ulogic;
                      buffer_first : in  std_ulogic;
                      unaligned    : in  std_ulogic;
                      issue_in     : in  std_logic_vector;
                      hold_pc      : out std_ulogic;
                      buff_valid   : out std_ulogic) is
  begin
    buff_valid := '0';
    hold_pc    := '0';

    if buffer_third = '1' then
      -- A third instruction or unaligned instruction
      -- in order to buffer all other instructions must be consumed
      if ((valid_in(0) = '1' and issue_in(0) = '1') or (valid_in(0) = '0')) and
         ((valid_in(1) = '1' and issue_in(1) = '1') or (valid_in(1) = '0')) then
        buff_valid := '1';
      end if;

      if valid_in(1) = '1' and issue_in(1) = '0' then
        hold_pc    := '1';
      end if;

      if r.d.buff.valid = '1' and single_issue = 0  then
        -- If buffer is valid also that means there will be at
        -- least two instructions left to issue, so don't buffer.
        buff_valid       := '0';
        hold_pc          := '1';
        if unaligned = '1' then
          -- If unaligned is asserted there might be less than three instructions.
          if dvalid_in(0) = '0' then
            buff_valid   := '1';
            hold_pc      := '0';
          elsif dvalid_in(0) = '1' and dvalid_in(1) = '0' then
            if issue_in(1) = '1' then
              buff_valid := '1';
              hold_pc    := '0';
            end if;
          end if;
          -- In all other cases buffer needs to be hold so first statement applies.
        end if;
      end if;

    end if;

    if buffer_sec = '1' and issue_in(1) = '0' then
      -- Buffer second instructions, when buffer_sec is asserted second instruction
      -- is always valid.
      buff_valid := '1';
    end if;

    if r.d.buff.valid = '1' and buffer_sec = '1' then
      if issue_in(1) = '0' then
        -- If buffer is also valid that means two instructions will left on
        -- regular queue don't buffer.
        buff_valid := '0';
        hold_pc    := '1';
      else
        buff_valid := '1';
      end if;
    end if;

    if r.d.buff.valid = '1' and buffer_first = '1' then
      if issue_in(1) = '0' then
        buff_valid := '1';
      end if;
    end if;


    if r.d.buff.valid = '1' and buffer_third = '0' and single_issue /= 0 then
      hold_pc := '1';
    end if;

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

    if ctrl_in.valid = '1' and v_fusel_eq(ctrl_in.fusel, JAL) and csren_in.jprden = '1' then
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
    btb.wdata := pc2xlen(ctrl_in.branch.addr);
    btb.flush := wb_fence_i;

    if ctrl_in.valid = '1' and v_fusel_eq(ctrl_in.fusel, JAL) and csren_in.jprden = '1' then
      -- Target address is included in ctrl_in.branch.addr
      btb.wen := not ctrl_in.branch.hit;
    end if;

    btb_out   := btb;
  end;


  function trigger_action(tdata : wordx) return std_logic_vector is
    variable typ    : std_logic_vector(3 downto 0) := tdata(tdata'high downto tdata'high - 3);
    -- Non-constant
    variable action : std_logic_vector(63 downto 0);
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
    variable insts    : integer range 0 to 4          := 0;
    variable valid    : std_logic                     := '0';
    variable del      : std_logic                     := '0';
    variable ret      : hit_vec_type;
    variable cnt      : std_logic_vector(3 downto 0);
  begin
    for i in x_ctrl'range loop
      if x_ctrl(i).valid = '1' then
        insts := insts + 1;
      end if;
    end loop;
    for i in m_ctrl'range loop
      if m_ctrl(i).valid = '1' then
        insts := insts + 1;
      end if;
    end loop;

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
    variable action   : std_logic_vector(63 downto 0);
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
    if hitv(hitv'high) = '1' then
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

    if r.x.rstate = run and dbgi.halt = '1' and useDebug = 1 then
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
    if r.x.rstate = run and dbgi.dsuen = '1' and useDebug = 1 then
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
              dm.tbufaddr := dbgi.ddata(TBUFBITS - 1 downto 0);
            else
              ddata(TBUFBITS - 1 downto 0) := dm_in.tbufaddr;
            end if;
          elsif dm_in.addr(3 downto 0) = x"9" then
              ddata(TBUFBITS - 1 downto 0) := dm_in.tbufcnt;
          else
            if dm_in.addr(2 downto 0) = "000" then
              ddata    := tbo_data( 63 downto   0);
            elsif dm_in.addr(2 downto 0) = "001" then
              ddata    := tbo_data(127 downto  64);
            elsif dm_in.addr(2 downto 0) = "010" then
              ddata    := tbo_data(191 downto 128);
            elsif dm_in.addr(2 downto 0) = "011" then
              ddata    := tbo_data(255 downto 192);
            elsif dm_in.addr(2 downto 0) = "100" then
              ddata    := tbo_data(319 downto 256);
            elsif dm_in.addr(2 downto 0) = "101" then
              ddata    := tbo_data(383 downto 320);
            elsif dm_in.addr(2 downto 0) = "110" then
              ddata    := tbo_data(447 downto 384);
            end if;
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

  hart <= u2slv(hindex, 4);

  arst <= testrst when (ASYNC_RESET and scantest /= 0 and testen /= '0')  else
          rstn when ASYNC_RESET else '1';

  csr_mmu.satp        <= r.mmu.satp;
  csr_mmu.vsatp       <= r.mmu.vsatp;
  csr_mmu.hgatp       <= r.mmu.hgatp;
  csr_mmu.mmu_adfault <= r.mmu.mmu_adfault;
  csr_mmu.pte_nocache <= r.mmu.pte_nocache;
  csr_mmu.pmpcfg0     <= r.mmu.pmpcfg0;
  csr_mmu.pmpcfg2     <= r.mmu.pmpcfg2;
  csr_mmu.precalc     <= r.csr.pmp_precalc;


  comb : process(r, bhto, btbo, raso, ico, dco, rfo, irqi, dbgi, mulo, divo, fpuo, tbo, hart, rstn, holdn, perf, cap)

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
    variable ra_alu_alusel      : word2_lanes_type;
    variable ra_alu_ctrl        : word3_lanes_type;
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
    variable me_irqand          : wordx;
    variable me_irqcause        : cause_type;
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
    variable vtbi               : nv_trace_in_type;
    variable vtbi_2p            : nv_trace_2p_in_type;
    variable vrasi              : nv_ras_in_type;

    -- Stall
    variable s_inst             : icdtype;
    variable s_way              : std_logic_vector(IWAYMSB downto 0);
    variable s_mexc             : std_ulogic;
    variable s_exctype          : std_ulogic;
    variable s_exchyper         : std_ulogic;
    variable s_tval2            : wordx;
    variable s_tval2type        : word2;
    variable iustall            : std_ulogic;
    variable s_fpu_issued       : std_ulogic;
    variable s_fpu_wait         : std_ulogic;

    -- Hardware Performance Monitoring
    variable ic_lddp            : std_ulogic;
    variable ic_stb2b           : std_ulogic;
    variable ic_jal             : std_ulogic;

    variable icache_en          : std_ulogic;

    variable r_f_pc_21          : word2;  -- Locally static for case statement

    variable iu_fflags          : std_logic_vector(r.csr.fflags'range);


    variable fpu_holdn          : std_ulogic;

    variable m_addr             : pctype;

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

    xc_rstn             := rstn;

    -----------------------------------------------------------------------
    -- WRITE BACK STAGE
    -----------------------------------------------------------------------

    -- Branch misprediction registered
    wb_branch      := r.wb.ctrl(branch_lane).branch.mpred and r.wb.ctrl(branch_lane).valid;
    wb_branch_addr := r.wb.ctrl(branch_lane).branch.naddr;

    -- Fence Logic --------------------------------------------------------
    fence_unit(r,                               -- in  : Register In
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
    bht_update(r.wb.ctrl(branch_lane),          -- in  : Ctrl In
               r.wb.unalg_pc,
               r.csr.dfeaturesen,               -- in  : CSR Feature Enable In
               wb_bhti                          -- out : BHTI Out
               );

    -- To Branch History Table --------------------------------------------
    bhti.wdata  <= wb_bhti.wdata;

    -- Branch Target Buffer Update Logic ----------------------------------
    btb_update(r.wb.ctrl(branch_lane),          -- in  : Ctrl In
               r.wb.unalg_pc,
               r.csr.dfeaturesen,               -- in  : CSR Feature Enable In
               wb_btbflush,                      -- in  : Fence.i Flush Signal
               wb_btbi                          -- out : BTBI Out
               );

    -- To Branch Target Buffer --------------------------------------------
    btbi.waddr  <= wb_btbi.waddr;
    btbi.wen    <= wb_btbi.wen and holdn and r.csr.dfeaturesen.btben and icache_en;
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
             r.x.ctrl(0).comp,                    -- in  : Lane 0 Compressed In
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
        alu_execute(x_alu_op1(i),                 -- in  : Op1
                    x_alu_op2(i),                 -- in  : Op2
                    r.x.alui(i).valid and r.x.ctrl(i).valid,
                    r.x.alui(i).ctrl,             -- in  : Control Bits
                    r.x.alui(i).alusel,           -- in  : ALU Select Flag
                    x_alu_valid(i),               -- out : ALU Valid Flag
                    x_alu_res(i)                  -- out : ALU Result
                    );
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
    x_wb_wcsr               := (others => zerox);  -- For simulation purposes,
    x_wb_wcsr(memory_lane)  := r.x.wcsr;           --  at this point, this is load/store address.

    -- Write Back Data ----------------------------------------------------
    for i in lanes'range loop
      wbdata_gen(i,                             -- in  : Lane
                 r.x.ctrl(i).fusel,             -- in  : Functional Units
                 x_alu_valid(i),                -- in  : Late ALUs Valid Flag
                 r.x.alui(i).lalu,              -- in  : Late ALUs Enable Flag
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
      x_wb_wcsr(csr_lane) := x_wcsr;
    end if;

    -- Late Branch Unit ---------------------------------------------------
    if late_branch = 1 then
      branch_unit(x_alu_op1(branch_lane),                 -- in  : Forwarded Op1
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
        x_wb_wcsr(branch_lane) := x_alu_op2(branch_lane); -- in simulation
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
    csr_write(wb_csr_csra,                      -- in  : CSR Address In
              r.x.rstate,                       -- in  : Core State In
              r.csr,                            -- in  : CSR File In
              wb_csr_wdata,                     -- in  : Write Data
              wb_csr_wen,                       -- in  : Valid/Write Enable In
              wb_csr_wlane,                     -- in  : Valid Write Lane In
              r.x.csraxc,                       -- in  : Precalculated CSR write exception
              x_csr_pipeflush,                  -- out : Flush Instructions Out
              x_csr_addrflush,                  -- out : Flush Instructions Out
              x_csr_write_xc,                   -- out : CSR Exception Flag
              x_csr_write_cause,                -- out : CSR Exception Cuase
              wb_upd_mcycle,                    -- out : CSR mcycle updated
              wb_upd_minstret,                  -- out : CSR minstret updated
              wb_upd_counter,                   -- out : CSR counter updated
              wb_csr                            -- out : CSR Regfile Out
              );

    -- Exception Unit -----------------------------------------------------
    exception_unit(x_branch_xc,                 -- in  : Late Branch Exception
                   x_branch_cause,              -- in  : Late Branch Cause
                   x_branch_tval,               -- in  : Late Branch Value
                   x_csr_write_xc,              -- in  : CSR Write Exception
                   x_csr_write_cause,           -- in  : CSR Write Cause
                   r,                           -- in  : Registers In
                   x_flush,                     -- in  : Flush from fence
                   r.x.swap,                    -- in  : Swapped Instructions
                   r.csr,                       -- in  : CSR Regfile In
                   r.x.int,                     -- in  : Interrupt pending on instruction
                   x_xc,                        -- out : Exceptions Out
                   x_xc_cause,                  -- out : Exceptions Cause Out
                   x_xc_tval,                   -- out : Exceptions Value Out
                   x_xc_ret,                    -- out : Return Level Out
                   x_xc_taken,                  -- out : Exception Taken Out
                   x_xc_lane_out,               -- out : Exception lane
                   x_xc_irq_taken,              -- out : IRQ taken lane
                   x_xc_taken_cause,            -- out : Exception Taken Cause Out
                   x_xc_taken_tval,             -- out : Exception Taken Value Out
                   x_xc_taken_tval2,            -- out : Exception Taken Value 2 Out
                   x_xc_taken_gva,              -- out : Exception Taken GVA Out
                   x_xc_flush,                  -- out : Flush Instructions Out
                   x_xc_pc,                     -- out : Exception PC Out
                   x_trig_taken                 -- out : Trigger action taken
                   );

    x_irq := irqi;
    -- Register Interrupts
    wb_csr.mip(11) := x_irq.meip;
    wb_csr.mip(9)  := x_irq.seip;
    wb_csr.mip(7)  := x_irq.mtip;
    wb_csr.mip(3)  := x_irq.msip;
    if ext_h /= 0 then
    wb_csr.mip(12) := orv(r.csr.hgeip and r.csr.hgeie);
    wb_csr.mip(10) := wb_csr.hvip(10) or r.csr.hgeip(u2i(r.csr.hstatus.vgein))
                      ;
    wb_csr.mip(6)  := wb_csr.hvip(6)
                      ;
      -- When hypervisor extension is enabled, VS-level interrupt is always
      -- delegated to HS-mode
      if r.csr.misa(h_ctrl) = '1' then
        wb_csr.mideleg(12) := '1';
        wb_csr.mideleg(10) := '1';
        wb_csr.mideleg(6)  := '1';
        wb_csr.mideleg(2)  := '1';
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
      v.wb.wcsr(i)         := x_wb_wcsr(i);        -- Data to the CSR File
      v.wb.wdata(i)        := x_wb_data(i);        -- Data to the Regfile
      v.wb.lalu(i)         := r.x.alui(i).lalu;
    end loop;
    v.wb.ctrl(fpu_lane).fpu       := r.x.ctrl(fpu_lane).fpu;
    v.wb.ctrl(fpu_lane).fpu_flush := r.x.ctrl(fpu_lane).fpu_flush;
    v.wb.fpuflags                 := r.x.fpuflags;
    v.wb.fpo                      := fpuo;         -- For logging


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


    v.wb.flushall      := x_xc_taken or wb_pipeflush;
    v.wb.csr_pipeflush := x_csr_pipeflush;
    v.wb.csr_addrflush := x_csr_addrflush;
    v.wb.swap          := r.x.swap;
    v.wb.nextpc0       := x_nextpc;
    v.wb.rasi          := r.x.rasi;
    v.wb.prv           := r.csr.prv;
    v.wb.v             := r.csr.v;
    v.wb.fence_flush   := fence_flush_check(r);

    -- Exception Registers Update -----------------------------------------
    exception_flow(x_xc_pc,                     -- in  : Exception PC In
                   x_xc_taken,                  -- in  : Exception In
                   x_xc_taken_cause,            -- in  : Exception Cause In
                   x_xc_taken_tval,             -- in  : Exception Trap Value I
                   x_xc_taken_tval2,            -- in  : Exception Trap Value 2
                   x_xc_taken_gva,              -- in  : Exception GVA Value
                   x_xc_ret,                    -- in  : Return Level In
                   wb_csr,                      -- in  : CSR Regfile In
                   r.csr,                       -- in  : Registered CSR Regfile
                   r.x.rstate,                  -- in  : Core State In
                   wb_csr_trig,                 -- out : CSR Regfile Out
                   x_xc_tvec                    -- out : Trap Vector Base Out
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
                 x_csr_dpc,             -- in  : DPC CSR Register In
                 x_csr_dcsr,            -- in  : DCSR CSR Register In
                 x_csr_prv,             -- in  : Privilege mode In
                 x_csr_v,               -- in  : Virtualization mode In
                 dmen,                  -- in  : Debug Module Enable
                 dbgi,                  -- in  : Debug Module In
                 r.dm,                  -- in  : Debug Module register In
                 x_xc,                  -- in  : Exceptions In
                 x_xc_taken,            -- in  : Exception Taken In
                 x_xc_taken_cause,      -- in  : Exception Cause In
                 x_dret,                -- in  : dret Instruction In
                 r.x.trig,              -- in  : Trigger trap on instruction
                 rfo.data1,             -- in  : Register File Read Port 1
                 r.e.csr.v,             -- in  : CSR File Read Register
                 tbo.data,              -- in  : Trace buffer readout data
                 dbg_running,           -- out : Running Signal
                 dbg_halted,            -- out : Halted Signal
                 dbg_pc,                -- out : PC from DM request
                 dbg_request,           -- out : DM request to PC
                 v.x.rstate,            -- out : Next DM State
                 v.csr.prv,             -- out : Privilege mode out
                 v.csr.v,               -- out : Virtualization mode Out
                 v.csr.dpc,             -- out : DPC CSR Register
                 v.csr.dcsr,            -- out : DCSR CSR Register
                 v.dm,                  -- out : Debug Module register Out
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
    stdata_unit(r,                      -- in  : Registers In
                me_stdata               -- out : Data to Store
                );

    -- Insert Exception ---------------------------------------------------
    me_exceptions(r.m.ctrl,             -- in  : Instruction Ctrl In
                  me_dcache_xc,         -- in  : Data Cache Exception In
                  me_dcache_cause,      -- in  : Data Cache Cause In
                  me_dcache_tval,       -- in  : Data Cache Value In
                  me_ret,               -- out : Return Privileged Level Out
                  me_xc,                -- out : Memory Stage Exception Out
                  me_xc_cause,          -- out : Memory Stage Cause Out
                  me_xc_tval            -- out : Memory Stage Value Out
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
    -- order: MEI, MSI, MTI, SEI, SSI, STI, UEI,USI, UTI. Synchronous exceptions are of
    -- lower priority than all interrupts.
    me_h_en       := r.csr.misa(h_ctrl) = '1';
    me_int        := '0';
    me_irqand     := r.csr.mip and r.csr.mie;
    me_irqcause   := (others => '0');
    if me_irqand(11) = '1' then
      me_irqcause := IRQ_M_EXTERNAL;
    elsif me_irqand(3) = '1' then
      me_irqcause := IRQ_M_SOFTWARE;
    elsif me_irqand(7) = '1' then
      me_irqcause := IRQ_M_TIMER;
    elsif me_irqand(9) = '1' then
      me_irqcause := IRQ_S_EXTERNAL;
    elsif me_irqand(1) = '1' then
      me_irqcause := IRQ_S_SOFTWARE;
    elsif me_irqand(5) = '1' then
      me_irqcause := IRQ_S_TIMER;
    elsif me_h_en and me_irqand(12) = '1' then
      me_irqcause := IRQ_SG_EXTERNAL;
    elsif me_h_en and me_irqand(10) = '1' then
      me_irqcause := IRQ_VS_EXTERNAL;
    elsif me_h_en and me_irqand(2) = '1' then
      me_irqcause := IRQ_VS_SOFTWARE;
    elsif me_h_en and me_irqand(6) = '1' then
      me_irqcause := IRQ_VS_TIMER;
    end if;             -- User Mode interrupts are not supported yet
    if (orv(r.csr.mip and r.csr.mie) = '1') and
       (r.csr.dcsr.stepie = '1' or r.csr.dcsr.step = '0') then
      if (r.csr.prv = PRIV_LVL_M and r.csr.mstatus.mie = '1') or
         r.csr.prv = PRIV_LVL_S or r.csr.prv = PRIV_LVL_U then
        if r.csr.mideleg(u2i(me_irqcause(3 downto 0))) = '1' then
          if (r.csr.mstatus.sie = '1' and r.csr.prv = PRIV_LVL_S) or
             r.csr.prv = PRIV_LVL_U then
            if me_h_en and r.csr.hideleg(u2i(me_irqcause(3 downto 0))) = '1' then
              if r.csr.v = '1' and ((r.csr.vsstatus.sie = '1' and r.csr.prv = PRIV_LVL_S) or
                  r.csr.prv = PRIV_LVL_U) then
                me_int := '1';
              end if;
            else
              me_int := '1';
            end if;
          end if;
        else
          me_int   := '1';
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
      v.x.int(i)          := r.m.ctrl(i).valid and (me_int and not me_csrw(i)) and not me_flush;
    end loop;
    v.x.ctrl(fpu_lane).fpu       := r.m.ctrl(fpu_lane).fpu;
    v.x.ctrl(fpu_lane).fpu_flush := r.m.ctrl(fpu_lane).fpu_flush;
    v.x.csr               := r.m.csr;
    v.x.swap              := r.m.swap;
    v.x.dci               := r.m.dci;
    v.x.address           := r.m.address;
    v.x.lbranch           := r.m.lbranch;
    v.x.alui              := r.m.alui;
    v.x.rasi              := r.m.rasi;
    v.x.spec_ld           := r.m.spec_ld;
    v.x.csrw              := me_csrw;
    v.x.ret               := me_ret;
    if not all_0(v.x.int) then
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

    
    btbi.flush  <= (wb_btbi.flush or mode_flush or not(r.csr.dfeaturesen.btben) or not(icache_en) ) and holdn;

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
    branch_unit(ex_alu_op1(branch_lane),                  -- in  : Forwarded Op1
                ex_alu_op2(branch_lane),                  -- in  : Forwarded Op2
                r.e.ctrl(branch_lane).valid,              -- in  : Enable/Valid Signal
                r.e.ctrl(branch_lane).branch.valid,       -- in  : Branch Valid Signal
                r.e.ctrl(branch_lane).inst(14 downto 12), -- in  : Inst funct3
                r.e.ctrl(branch_lane).branch.addr,        -- in  : Branch Target Address
                r.e.ctrl(branch_lane).branch.naddr,       -- in  : Branch Next Address
                r.e.ctrl(branch_lane).branch.taken,       -- in  : Prediction
                r.e.ctrl(branch_lane).pc,                 -- in  : PC In
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
    jump_unit(r.e.ctrl(branch_lane),       -- in  : Ctrl In
              r.e.jimm,                    -- in  : Imm In
              r.e.raso,                    -- in  : RAS In
              ex_jump_op1,                 -- in  : Forwarded data
              ex_branch_flush,             -- in  : Flush In
              ex_jump,                     -- out : Jump Signal
              mem_jump,                    -- out : Delayed Jump Signal
              ex_jump_xc,                  -- out : Jump Exception
              ex_jump_cause,               -- out : Exception Cause
              ex_jump_tval,                -- out : Exception Value
              ex_jump_addr                 -- out : Target Address
              );

    -- ALUs --------------------------------------------------------------
    for i in lanes'range loop
      alu_execute(ex_alu_op1(i),           -- in  : Op1
                  ex_alu_op2(i),           -- in  : Op2
                  r.e.alui(i).valid and not r.e.alui(i).lalu,
                  r.e.alui(i).ctrl,        -- in  : Control Signal
                  r.e.alui(i).alusel,      -- in  : ALU Select
                  ex_alu_valid(i),         -- out : ALU Valid
                  ex_alu_res(i)            -- out : ALU Result
                  );
    end loop;

    -- Forwarding Store Data ----------------------------------------------
    ex_stdata_forwarding(r,                -- in  : Registers In
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

    addr_gen(r.e.ctrl(memory_lane).inst,   -- in  : Instruction In
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
--            r.e.fpu_issued,                -- in  : Already issued this
            '0',                           -- in  : Already issued this
--            fpuo.holdn,                    -- in  : FPU Ready Signal
            fpu_holdn,                    -- in  : FPU Ready Signal
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
      v.m.fpuflags               := fpuo.flags2int;
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
--    if r.e.fpu_issued = '1' then
--      v.m.ctrl(fpu_lane).fpu := r.e.ctrl(fpu_lane).fpu;
--    else
--      v.m.ctrl(fpu_lane).fpu := fpuo.issue_id;
--    end if;
    -- This sometimes notes the issue ID in M before the
    -- instruction actually leaves EX. But that does not
    -- matter, as long as it is correct when it
    -- leaves M.
--    if fpuo.issue = '1' then
--      v.m.ctrl(fpu_lane).fpu := fpuo.issue_id;
--    end if;
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
      v.m.alui          := r.e.alui;
      for i in lanes'range loop
        v.m.alui(i).op1 := ex_alu_op1(i);
        v.m.alui(i).op2 := ex_alu_op2(i);
      end loop;
    end if;

    -- Store JALR Address -------------------------------------------------
    if v_fusel_eq(r, e, branch_lane, JALR) then
      v.m.ctrl(branch_lane).branch.addr := ex_jump_addr;
    end if;

    -- Store Data ---------------------------------------------------------
    dcache_gen(r.e.ctrl(memory_lane).inst,   -- in  : Instruction In
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

    csr_read(r.csr,                     -- in  : CSR File
             ra_csr_address,            -- in  : CSR Register Address
             ra_csrv,                   -- in  : Valid/Read enable
             r.x.rstate,                -- in  : Core State In
             iu_fflags,                 -- in  : FPU flags in IU transit
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
      alu_gen(r.a.ctrl(i).inst,
              r.a.ctrl(i).valid,          -- Valid instruction
              r.a.ctrl(i).fusel,          -- ALU
              ra_alu_valid(i),            -- ALU Valid Signal
              ra_alu_alusel(i),           -- ALU Type Selection
              ra_alu_ctrl(i)              -- ALU Control Signal
              );
      a_alu_forwarding(r,                 -- in  : Registers In
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
    a_stdata_forwarding(r,                      -- in  : Registers In
                        0,                      -- in  : Lane
                        ex_result_fwd(0)   and r.e.ctrl(0).valid   and r.e.ctrl(0).rdv,
                        ex_result_fwd(one) and r.e.ctrl(one).valid and r.e.ctrl(one).rdv,
                        v.m.result,             -- in  : Data from ALU L0/L1
                        ra_data34(memory_lane), -- in  : Register File Port 3
                        ra_stdata_forw,         -- out : Forwarded Signal
                        ra_stdata               -- out : Write Back Value
                        );

    -- Jump Unit -----------------------------------------------------------
    a_jump_forwarding(r,                        -- in  : Registers In
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
--    if fpuo.issue = '1' then
--      v.e.ctrl(fpu_lane).fpu := fpuo.issue_id;
--    end if;
    v.e.ctrl(fpu_lane).fpu := r.a.ctrl(fpu_lane).fpu;
    v.e.fpu_issued        := '0';
    -- Keep track of whether FPU instruction has already issued
--    if holdn = '0' then
    if holdn = '0' or fpuo.holdn = '0' then
      v.e.fpu_issued      := r.e.fpu_issued or fpuo.issue;
--    else
    elsif fpuo.issue = '1' and fpuo.holdn = '0' then
      v.e.fpu_issued      := '1';
    end if;
    if ext_f = 1 then
      -- This condition would have caused a hold in EX above!
      if r.e.fpu_wait = '1' and
         not (ex_flush = '1' or ex_fpu_flush = '1' or me_fpu_flush = '1') and
         not (fpuo.now2int = '1' and fpuo.id2int = r.e.ctrl(FPU_LANE).fpu) then
        v.e.fpu_wait := '1';
      else
        v.e.fpu_wait := '0';
        if is_valid_fpu(v, e) and not is_fpu_rd(v.e.ctrl(FPU_LANE).inst) and
           not fpuo.holdn = '0' then
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
      v.e.alui(i).op1    := ra_alu_op1(i);
      v.e.alui(i).op2    := ra_alu_op2(i);
      v.e.alui(i).valid  := ra_alu_valid(i);
      v.e.alui(i).ctrl   := ra_alu_ctrl(i);
      v.e.alui(i).alusel := ra_alu_alusel(i);
      v.e.alui(i).lalu   := ic_lalu(i);
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
    rvc_aligner(de_inst,                      -- in  : Fetch Instructions In
                r.d.pc,                       -- in  : Decode PC In
                r.d.valid,                    -- in  : Valid Instructions Inxs
                de_rvc_aligned,               -- out : Aligned Instructions Out
                de_rvc_comp_ill,              -- out : Compressed illegal out
                de_rvc_hold,                  -- out : Hold Signal Out
                de_rvc_npc,                   -- out : Next PC Out
                de_rvc_valid,                 -- out : Valid Signal Out
                de_rvc_buffer_first,          -- out : Buffer first inst if not issued
                de_rvc_buffer_sec,            -- out : Buffer second inst if not issued
                de_rvc_buffer_third,          -- out : Buffer third inst or unaligned
                de_rvc_buffer_inst,           -- out : Buffer inst
                de_rvc_buffer_comp_ill,       -- out : Buffer comp is illegal
                v.d.unaligned                 -- out : Unaligned Out
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
    v.d.buff.pc         := r.d.pc(r.d.pc'high downto 3) & de_rvc_aligned(1).lpc & '0';
    v.d.buff.comp       := de_rvc_comp(1);
    v.d.buff.xc         := de_rvc_illegal(1);
    v.d.buff.comp_ill   := de_rvc_comp_ill(1);

    bjump_gen(de_inst,
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
    de_inst_mexc     := r.d.mexc&r.d.mexc;
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
      de_pc(0)             := r.d.buff.pc;
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
      v.d.buff.pc       := r.d.pc(r.d.pc'high downto 3) & de_rvc_buffer_inst.lpc & '0';
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
      dual_issue_check(de_inst_buff,      -- in  : Aligned Instructions In
                       de_inst_valid,     -- in  : Valid Signals In
                       r.csr.dfeaturesen, -- in  : Machine Features CSR In
                       r.csr.dcsr.step,   -- in  : DCSR step
                       r.a.lalu_pre,           -- in  : Late ALUs from RA In
                       rd(v, e, 0),       -- in  : rd register from RA In
                       v.e.ctrl(0).rdv,   -- in  : Valid rd register from RA In
                       rd(v, e, 1),       -- in  : rd register from RA In
                       v.e.ctrl(1).rdv,   -- in  : Valid rd register from RA In
                       de_lane0_csr,      -- out : CSR must be copied to lane 0
                       de_issue           -- out : Issue Flag Out
                       );

    -- Dual Issue Swap ---------------------------------------------------
      dual_issue_swap(de_inst_buff,       -- in  : Instructions In
                      de_inst_valid,      -- in  : Valid Signals In
                      de_swap             -- out : Swapped Instructions Flag
                      );
    else
      de_lane0_csr  := '0';
      de_issue      := "01";
      de_swap       := '0';
    end if;

    -- Instruction Queue Logic -------------------------------------------
    buffer_ic(r,
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

      imm_gen(de_inst_buff(i).d,        -- in  : Instruction In
              de_imm_valid(i),          -- out : Immediate Valid Flag
              de_imm(i),                -- out : Immediate Value
              de_bj_imm(i));            -- out : only bjump imm value

      de_pc_valid(i)   := pc_valid(de_inst_buff(i).d);

      csr_gen(de_inst_buff(i).d,        -- in  : Instruction In
              de_csr_valid(i));         -- out : CSR Valid Flag

      de_csr_rdo(i) := '0';
      if csr_read_only(de_inst_buff(i).d) then
        de_csr_rdo(i) := '1';
      end if;

      de_fusel(i)      := fusel_gen(de_inst_buff(i).d);   -- in  : Instruction In

      exception_check(de_inst_buff(i).d,   -- in  : Instruction In
                      de_cinst_buff(i),    -- in  : Compressed instruction In
                      de_pc(i),            -- in  : PC In
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
    ujump_resolve(v.a.ctrl(branch_lane),        -- in  : Instruction In
                  de_branch_addr,               -- in  : Computed Target In
                  de_branch_next,               -- in  : Next Pc In
                  de_bhto_taken(branch_lane),   -- in  : Prediction In
                  de_btbo_hit(branch_lane),     -- in  : Hit In
                  de_jump_xc,                   -- out : Jump Exception
                  de_jump_cause,                -- out : Exception Cause
                  de_jump_tval,                 -- out : Exception Value
                  de_jump,                      -- out : Jump Signal
                  de_jump_addr                  -- out : Jump Address Out
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
      for i in 0 to 3-(2*single_issue) loop
        if de_bjump_pos(i) = '1' then
          for j in lanes'range loop
            if v.a.ctrl(j).valid = '1' and v.a.ctrl(j).pc(2 downto 1) = u2slv(i, 2)
              and v_a_inst_no_buf(j) = '0' and single_issue = 0 then
              de_hold_pc  := '0';
              de_rvc_hold := '0';
            end if;
            if single_issue /= 0 then
              if v.a.ctrl(j).valid = '1' and v.a.ctrl(j).pc(1 downto 1) = u2slv(i, 1) and
                v_a_inst_no_buf(j) = '0' then
                de_hold_pc  := '0';
                de_rvc_hold := '0';
              end if;
            end if;
          end loop;
          if v.d.buff.valid = '1' and v.d.buff.pc(2 downto 1) = u2slv(i, 2) and single_issue = 0 then
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
            if v.d.buff.pc(2 downto 1) /= u2slv(i, 2) and single_issue = 0 then
              v.d.buff.valid := '0';
            end if;
            if single_issue /= 0 then
              if v.d.buff.pc(1 downto 1) /= u2slv(i, 1) then
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
    f_pb_exec := to_bit((dmen = 1) and      -- Execute from program buffer?
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
        if ico.way(IWAYMSB downto 0) = u2slv(i, IWAYMSB + 1) then
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
      v.d.valid := '0';
    end if;

    if de_bjump = '1' then
      -- Invalidate d.valid when branch is actually issued
      for i in 0 to 3 - (2 * single_issue) loop
        if de_bjump_pos(i) = '1' then
          for j in lanes'range loop
            if v.a.ctrl(j).valid = '1' and v.a.ctrl(j).pc(2 downto 1) = u2slv(i, 2)
            and v_a_inst_no_buf(j) = '0' and single_issue = 0 then
              v.d.valid := '0';
            end if;
            if single_issue /= 0 then
              if v.a.ctrl(j).valid = '1' and v.a.ctrl(j).pc(1 downto 1) = u2slv(i, 1) and v_a_inst_no_buf(j) = '0' then
                v.d.valid := '0';
              end if;
            end if;
          end loop;
          if v.d.buff.valid = '1' and v.d.buff.pc(2 downto 1) = u2slv(i, 2) and single_issue = 0 then
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
            if v.d.buff.valid = '1' and v.d.buff.pc(2 downto 1) /= u2slv(i, 2) and single_issue = 0 then
              v.d.buff.valid := '0';
            end if;
            if single_issue /= 0 then
              if v.d.buff.valid = '1' and v.d.buff.pc(1 downto 1) /= u2slv(i, 1) then
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
        v.d.prediction(i).dir   := (others => '0');
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
    de_target         := to_addr(btbo.rdata);

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

      if v_fusel_eq(r.m.ctrl(branch_lane).fusel, JAL) and r.csr.dfeaturesen.jprden = '1' then
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
         v_fusel_eq(r.wb.ctrl(branch_lane).fusel, JAL) and r.csr.dfeaturesen.jprden = '1' then
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
                                      (v.csr.prv and ('1'&to_bit(mode_s = 1)));

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

    -- Instruction Trace --------------------------------------------------
    itrace_gen(r,                       -- in  : Registers In
               r.wb.fpo,                -- in  : FPU result writes
               x_xc,                    -- in  : Exception Flags
               x_xc_taken,              -- in  : Exception Taken Flag
               x_xc_taken_cause,        -- in  : Exception Cause
               x_xc_taken_tval,         -- in  : Exception Valuex
               v.wb.wdata,              -- in  : Instruction WB Data
               v.dm.tbufcnt,
               vtbi,                    -- out : Trace Interface Out
               vtbi_2p);                -- out : Trace Interface 2p

    v.evt  := (others => '0');
    v.cevt := (others => '0');
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

--pragma translate_off
      -- To give disassembly values that are never affected by the code.
      v.dis_mcycle       := uadd(r.dis_mcycle, 1);
      if holdn = '1' and rstn = '1' then
        if single_issue = 0 and
           (v.wb.ctrl(0).valid and v.wb.ctrl(one).valid) = '1' then
          v.dis_minstret := uadd(r.dis_minstret, 2);
        elsif (v.wb.ctrl(0).valid or v.wb.ctrl(one).valid) = '1' then
          v.dis_minstret := uadd(r.dis_minstret, 1);
        end if;
      end if;
--pragma translate_on

      -- Hardware Performance Monitoring ------------------------------------
      if rstn = '1' then
--pragma translate_off
        if r.evt(CSR_HPM_DUAL_ISSUE) = '1' then
          v.dis_dual_issue := uadd(r.dis_dual_issue, 1);
        end if;
--pragma translate_on
        for i in v.cevt'range loop
          -- Multiplex selected event
          -- 0 means no event counted.
          if not all_0(r.csr.hpmevent(i)) then
            v.cevt(i) := r.evt(u2i(r.csr.hpmevent(i)));
          end if;
          if r.cevt(i) = '1' and r.csr.mcountinhibit(i + 3) = '0' and wb_upd_counter(i) = '0' then
            v.csr.hpmcounter(i) := uadd(r.csr.hpmcounter(i), 1);
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

    if holdn = '0' then
      -- Things that update during hold.
      v.evt(CSR_HPM_ICACHE_MISS) := not ico.mds;
      v.evt(CSR_HPM_DCACHE_MISS) := not dco.mds;
      v.evt(CSR_HPM_HOLD)        := '1';
    else
      v.evt(CSR_HPM_DUAL_ISSUE)  := to_bit(single_issue = 0) and v.wb.ctrl(0).valid and v.wb.ctrl(one).valid;
      v.evt(CSR_HPM_BRANCH_MISS) := (mem_branch or wb_branch);
      v.evt(CSR_HPM_HOLD_ISSUE)  := de_hold_pc;
      v.evt(CSR_HPM_BRANCH)      := to_bit(v_fusel_eq(v, wb, branch_lane, BRANCH));
      v.evt(CSR_HPM_LOAD_DEP)    := ic_lddp;
      v.evt(CSR_HPM_STORE_B2B)   := ic_stb2b;
      v.evt(CSR_HPM_JALR)        := to_bit(v_fusel_eq(v, wb, branch_lane, JALR));
      v.evt(CSR_HPM_JAL)         := to_bit(v_fusel_eq(v, wb, branch_lane, JAL));
    end if;
    v.evt(CSR_HPM_ICACHE_FETCH)  := perf(0);
    v.evt(CSR_HPM_ITLB_MISS)     := perf(1);
    v.evt(CSR_HPM_DCACHE_FETCH)  := perf(2);
    v.evt(CSR_HPM_DTLB_MISS)     := perf(3);
    v.evt(CSR_HPM_DCACHE_FLUSH)  := perf(4);

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
    s_fpu_issued := v.e.fpu_issued;
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
      -- Keep FPU issued information
      v.e.fpu_issued    := s_fpu_issued;
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
    v.mmu             := ((others => '0'), (others => '0'), (others => '0'),
                          '0', '0', (others => '0'), (others => '0'),
                          PMPPRECALCRES);
    -- Writes to these (in the exception stage) will cause a pipeline flush
    -- in the writeback stage, so there is time to register the data once
    -- before it is required.
    v.mmu.satp        := r.csr.satp;
    v.mmu.vsatp       := r.csr.vsatp;
    v.mmu.hgatp       := r.csr.hgatp;
    v.mmu.mmu_adfault := r.csr.dfeaturesen.mmu_adfault;
    v.mmu.pte_nocache := r.csr.dfeaturesen.pte_nocache;
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
      v.x.csraxc := csr_write_xc(csr_addr(r.m.ctrl(csr_lane).inst), r.x.rstate, r.csr);
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
    v.csr.mstatus.sbe  := '0';
    v.csr.mstatus.ube  := '0';
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
      v.csr.mstatus.mpv := '0';
      v.csr.mstatus.gva := '0';
      v.csr.mtval2      := (others => '0');
      v.csr.mtinst      := (others => '0');
      v.mmu.vsatp       := (others => '0');
      v.mmu.hgatp       := (others => '0');
    end if;
    -- S-mode not implemented
    if mode_s = 0 then
      v.csr.satp        := (others => '0');
      v.csr.stvec       := (others => '0');
      v.csr.sepc        := (others => '0');
      v.csr.stval       := (others => '0');
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
      v.mmu.satp        := (others => '0');
      v.mmu.mmu_adfault := '0';
      v.mmu.pte_nocache := '0';
    end if;
    -- U-mode not implemented
    if mode_u = 0 then
      v.csr.mstatus.uxl := "00";
      v.csr.mstatus.mprv:= '0';
      v.csr.mstatus.tw  := '0';
      v.csr.scounteren  := (others => '0');
    end if;
    -- N-extension not implemented
    if ext_n = 0 then
      v.csr.mstatus.uie := '0';
      v.csr.mstatus.upie:= '0';
    end if;
    -- S-mode or N-extension not implemented
    if mode_s = 0 and ext_n = 0 then
      v.csr.mideleg     := (others => '0');
      v.csr.medeleg     := (others => '0');
    end if;
    if (ext_f + ext_d + ext_q) = 0 then
      v.csr.mstatus.fs  := "00";
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
    -- Clear unimplemented performance counters
    if perf_cnts < HWPERFMONITORS then
      for i in perf_cnts to r.csr.hpmcounter'high loop
        v.csr.hpmcounter(i)       := (others => '0');
        v.csr.hpmevent(i)         := (others => '0');
        v.csr.mcountinhibit(i+3)  := '0';
        v.csr.mcounteren(i+3)     := '0';
      end loop;
    end if;

    -- Simulation Code ----------------------------------------------------
-- pragma translate_off
    if v_fusel_eq(r, m, memory_lane, ST) then
      v.x.result(memory_lane)     := me_stdata(wordx'range);
      if r.m.dci.size = SZWORD then
        -- We can only be here if XLEN = 64 (FPU data comes another way).
        v.x.result(memory_lane)   := to0x(me_stdata(31 downto 0));
      elsif r.m.dci.size = SZHALF then
        v.x.result(memory_lane)   := to0x(me_stdata(15 downto 0));
      elsif r.m.dci.size = SZBYTE then
        v.x.result(memory_lane)   := to0x(me_stdata( 7 downto 0));
      end if;
    end if;
    v.x.wcsr                      := zerox;
    if v_fusel_eq(r, m, memory_lane, LD or ST) then
      v.x.wcsr(r.m.address'range) := r.m.address;
    end if;
-- pragma translate_on

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
    rasi.push           <= vrasi.push  and holdn and r.csr.dfeaturesen.rasen;
    rasi.pop            <= vrasi.pop   and holdn and r.csr.dfeaturesen.rasen;
    rasi.flush          <= vrasi.flush and holdn and r.csr.dfeaturesen.rasen;
    rasi.wdata          <= vrasi.wdata;

    -- To the Instruction Trace Buffer ------------------------------------
    if not TRACEBUF then
      vtbi              := nv_trace_in_type_none;
      vtbi_2p           := nv_trace_2p_in_type_none;
    end if;
    tbi                 <= vtbi;

    -- Perf Counters
    cnt.icnt <= r.wb.icnt;
    -- Branch prediction miss
    cnt.bpmiss <= r.evt(CSR_HPM_BRANCH_MISS);

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
      vfpui.e_valid        := to_bit(is_valid_fpu(r, e)) and not r.e.fpu_issued;
      vfpui.issue_id       := fpu_ctrl.fpu;
      vfpui.csrfrm         := r.csr.frm;
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
      vfpui.unissue     := holdn and fpu_ctrl.fpu_flush;
      vfpui.unissue_id  := fpu_ctrl.fpu;
    end if;
    fpui                <= vfpui;



  end process;

  syncrregs : if not ASYNC_RESET generate

    -- Sync Reg Process ---------------------------------------------------
    sync_reg : process (clk)
    begin
      if rising_edge(clk) then
        if holdn = '1' then
          r                                           <= rin;
        else
          -- Some things need to be updated even during hold.
          r.fpflush                                   <= rin.fpflush;
          r.dm.havereset                              <= rin.dm.havereset;
          r.csr.mcycle                                <= rin.csr.mcycle;
--pragma translate_off
          r.dis_mcycle                                <= rin.dis_mcycle;
--pragma translate_on
          r.evt                                       <= rin.evt;
          r.cevt                                      <= rin.cevt;
          r.csr.hpmcounter                            <= rin.csr.hpmcounter;
          r.csr.fflags                                <= rin.csr.fflags;
          -- Must note if FPU instruction was issued
          r.e.fpu_issued                              <= rin.e.fpu_issued;
--          r.m.ctrl(fpu_lane).fpu                      <= rin.m.ctrl(fpu_lane).fpu;
          -- I Cache Miss
          if ico.mds = '0' then
            r.d.inst                                  <= rin.d.inst;
            if r.d.unaligned = '1' and r.d.buff.valid = '1' then
              r.d.buff.inst.d(31 downto 16)           <= rin.d.buff.inst.d(31 downto 16);
            end if;
            r.d.mexc                                  <= rin.d.mexc;
            r.d.exctype                               <= rin.d.exctype;
            r.d.exchyper                              <= rin.d.exchyper;
            r.d.tval2                                 <= rin.d.tval2;
            r.d.tval2type                             <= rin.d.tval2type;
            r.d.way                                   <= rin.d.way;
          end if;
          -- D Cache Miss
          if dco.mds = '0' then
            r.x.data                                  <= rin.x.data;
            r.x.mexc                                  <= rin.x.mexc;
            r.x.exctype                               <= rin.x.exctype;
            r.x.exchyper                              <= rin.x.exchyper;
            r.x.tval2                                 <= rin.x.tval2;
            r.x.tval2type                             <= rin.x.tval2type;
            r.x.way                                   <= rin.x.way;
          end if;
          -- perf counter
          r.wb.icnt <= rin.wb.icnt;

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
            r.dm.tbufcnt       <= RRES.dm.tbufcnt;
            r.dm.tbufaddr      <= RRES.dm.tbufaddr;
            r.dm.havereset     <= RRES.dm.havereset;
            r.m.trig           <= RRES.m.trig;
          end if;
          -- Halt-on-reset
          if dbgi.haltonrst = '1' and dmen = 1 then
            r.x.rstate <= dhalt;
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
              r.d.mexc      <= rin.d.mexc;
              r.d.exctype   <= rin.d.exctype;
              r.d.exchyper  <= rin.d.exchyper;
              r.d.tval2     <= rin.d.tval2;
              r.d.tval2type <= rin.d.tval2type;
              r.d.way       <= rin.d.way;
              if r.d.unaligned = '1' and r.d.buff.valid = '1' then
                r.d.buff.inst.d(31 downto 16)           <= rin.d.buff.inst.d(31 downto 16);
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
                r.d.buff.inst.d(31 downto 16)           <= rin.d.buff.inst.d(31 downto 16);
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

  -----------------------------------------------------------------------
  -- Disassembly
  -----------------------------------------------------------------------

-- pragma translate_off
  dis : if disas >= 1 generate

    disas_en <= '1' when disas /= 0 and
                         (r.x.rstate = run or r.csr.dfeaturesen.tpbuf_en = '1')
           else '0';

    process (clk)
    begin
      if rising_edge(clk) then
        if disas_en = '1' then
          if fpuo.wen = '1' then
            print("FPU " & tost(fpuo.wb_id) & " " & fpreg2st(fpuo.rd) & " = " & tost(fpuo.data));
          end if;
        end if;
      end if;
    end process;

    process (r.wb, holdn)
      -- Non-constant
      variable f : integer range lanes'range;
    begin
      for i in lanes'range loop
        f   := i;
        if single_issue = 0 and
           r.wb.swap = '1' then
          f := 1 - i;
        end if;
        way(i)        <= u2slv(f, 3);
        disas_iv(i)   <= r.wb.ctrl(f).valid   and holdn;
        cinst(i)      <= r.wb.ctrl(f).cinst;
        inst(i)       <= r.wb.ctrl(f).inst;
        comp(i)       <= r.wb.ctrl(f).comp;
        pc(i)         <= r.wb.ctrl(f).pc;
        -- Pass FPU issue ID instead of GPR result when applicable.
        -- Makes it possible to match with FPU write-back.
        if i = fpu_lane and is_fpu_rd(r.wb.ctrl(f).inst) then
          wdata(i)      <= to0x(r.wb.ctrl(f).fpu);
        else
          wdata(i)      <= r.wb.wdata(f);
        end if;
        wcsr(i)       <= r.wb.wcsr(f);
        wren(i)       <= r.wb.ctrl(f).rdv     and holdn and r.wb.ctrl(f).valid;
        wren_f(i)     <= to_bit(fpu_lane = f) and holdn and fd_gen(r.wb.ctrl(f).inst) and r.wb.ctrl(f).valid;
        wcen(i)       <= r.wb.ctrl(f).csrv    and holdn and r.wb.ctrl(f).valid;
        trap(i)       <= r.wb.ctrl(f).xc      and holdn;
        cause(i)      <= r.wb.ctrl(f).cause;
        tval(i)       <= r.wb.ctrl(f).tval;
        trap_taken(i) <= r.wb.trap_taken(f);
      end loop;
    end process;

    iw_gen: for i in lanes'range generate
      iw : entity grlib.cpu_disas
        generic map(
          disasg => disas
          )
        port map(
          clk         => clk,
          rstn        => rstn,
          dummy       => open,
          index       => hart,
          way         => way(i),
          ivalid      => disas_iv(i),
          inst        => inst(i),
          cinst       => cinst(i),
          comp        => comp(i),
          pc          => pc2xlen(pc(i)),
          wregen      => wren(i),
          wregdata    => wdata(i),
          wregen_f    => wren_f(i),
          wcsren      => wcen(i),
          wcsrdata    => wcsr(i),
          prv         => r.wb.prv,
          v           => r.wb.v,
          trap        => trap(i),
          trap_taken  => trap_taken(i),
          cause       => cause(i),
          tval        => tval(i),
--          cycle       => r.csr.mcycle,
--          instret     => r.csr.minstret,
--          dual        => r.csr.hpmcounter(5),
          cycle       => r.dis_mcycle,
          instret     => r.dis_minstret,
          dual        => r.dis_dual_issue,
          disas       => disas_en
          );
    end generate;
  end generate;
-- pragma translate_on

end rtl;
