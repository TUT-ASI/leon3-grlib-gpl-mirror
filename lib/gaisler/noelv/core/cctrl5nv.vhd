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
-- Entity:      cctrl5nv
-- File:        cctrl5nv.vhd
-- Author:      Magnus Hjorth and Johan Klockars, Cobham Gaisler
-- Based on:    LEON3/LEON4 cache and MMU by Jiri Gaisler, Edvin Catovic
--              and Konrad Eisele
-- Description: Complete cache controller with MMU for LEON5 and NOEL-V.
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.sparc.all;
use grlib.config.all;
use grlib.config_types.all;
use grlib.riscv.all;
library gaisler;
use gaisler.l5nv_shared.all;
use gaisler.busif5_types.all;
use gaisler.noelvint.all;
use gaisler.noelvtypes.all;
use gaisler.utilnv.all;
use gaisler.mmucacheconfig.all;
use gaisler.noelv.XLEN;
use gaisler.nvsupport.all;
use gaisler.alunv.clz;
use gaisler.alunv.reverse;

entity cctrl5nv is
  generic (
    iways     : integer range 1 to 4;
    ilinesize : integer range 4 to 8;
    iwaysize  : integer range 1 to 256;
    dways     : integer range 1 to 4;
    dlinesize : integer range 4 to 8;
    dwaysize  : integer range 1 to 256;
    dtagconf  : integer range 0 to 2;
    dusebw    : integer range 0 to 1;
    itcmen    : integer range 0 to 1;
    itcmabits : integer range 1 to 20;
    itcmfrac  : integer range 0 to 7;
    dtcmen    : integer range 0 to 1;
    dtcmabits : integer range 1 to 20;
    dtcmfrac  : integer range 0 to 7;
    itlbnum   : integer range 2 to 64;
    dtlbnum   : integer range 2 to 64;
    -- RISCV
    htlbnum     : integer range 1 to  64;   -- # hypervisor TLB entries
    mmuen       : integer range 0 to   1;
    riscv_mmu   : integer range 0 to   3;
    pmp_no_tor  : integer range 0 to   1;   -- Disable PMP TOR (not with TLB PMP)
    pmp_entries : integer range 0 to  16;   -- Implemented PMP registers
    pmp_g       : integer range 0 to  10;   -- PMP grain is 2^(pmp_g + 2) bytes
--    pma_no_tor  : integer range 0 to   1 := 1;   -- Disable PMA TOR
    pma_entries : integer range 0 to  16;   -- Implemented PMA entries
    pma_masked  : integer range 0 to   1;   -- PMA done using masks
    asidlen     : integer range 0 to  16;   -- Max 9 for Sv32
    vmidlen     : integer range 0 to  14;   -- Max 7 for Sv32
    ext_noelv   : integer range 0 to   1;   -- NOEL-V Extensions
    ext_a       : integer range 0 to   1;   -- Support for Atomic operations
    ext_h       : integer range 0 to   1;   -- Support for Hypervisor, needs tlb_pmp if any PMP.
    ext_smepmp  : integer range 0 to   1;   -- Support for Smepmp extension
    ext_zicbom  : integer range 0 to   1;   -- Support for Zicbom extension
    ext_svpbmt  : integer range 0 to   1;   -- Support for Svpbmt Extension
    ext_svnapot : integer range 0 to   1;   -- Support for Svnapot Extension
    ext_zicfiss : integer range 0 to   1;   -- Support for Zicfiss Extension
    tlb_pmp     : integer range 0 to   1;   -- Do PMP via TLB
    --
    cached    : integer;
    wbmask    : integer;
    busw      : integer;
    cdataw    : integer;
    tlbrepl   : integer;
    -- RISCV
    addr_check : integer range 0 to 255 := 255; -- Instruction PMP (7 TLB, 6 acc), high bits (5 physical, 4 virtual)
    mmu_debug  : boolean := false;              --   Data      PMP (3 TLB, 2 acc), high bits (1 physical, 0 virtual)
    walk_state : boolean := true;               -- Decouple page walk start using a separate state.
    walk_fault : boolean := true;               -- Enabled fault on PT walk start.
    walk_sw    : boolean := false;              -- Only SW PT walk (using TLB diagnostics)
    walk_pmp   : boolean := false;              -- Do "page walk" and use TLBs for pure PMP/PMA (not yet working!)
    pma_gr765  : boolean := false;               -- Special PMA handling according to GR765 memory map
    enable_g      : integer range 0 to 1 := 0;  -- Enable handling of G (global) bit in page tables
    pmp_mmuu_test : integer range 0 to 1 := 1;  -- Enable PMP test via diagnostics
    pma_mmuu_test : integer range 0 to 1 := 1;  -- Enable PMA test via diagnostics
    tlb_valid_r   : integer range 0 to 1 := 1;  -- Enable TLB valid setting via diagnostics
    --
    addrbits  : integer;
    iphysbits : integer;
    dphysbits : integer
    );
  port (
    rst      : in  std_ulogic;
    clk      : in  std_ulogic;
    --ici      : in  icache_in_type5;
    --ico      : out icache_out_type5;
    --dci      : in  dcache_in_type5;
    --dco      : out dcache_out_type5;
    ici      : in  nv_icache_in_type;
    ico      : out nv_icache_out_type;
    dci      : in  nv_dcache_in_type;
    dco      : out nv_dcache_out_type;
    ahbso    : in  ahb_slv_out_vector;
    endian   : in  std_ulogic;
    crami    : out cram_in_type5;
    cramo    : in  cram_out_type5;
    bifi     : out busif_in_type5;
    bifo     : in  busif_out_type5;
    sclk     : in  std_ulogic;
    fpc_mosi : out l5_intreg_mosi_type;
    fpc_miso : in  l5_intreg_miso_type;
    c2c_mosi : out l5_intreg_mosi_type;
    c2c_miso : in  l5_intreg_miso_type;
    csro     : in  nv_csr_out_type := nv_csr_out_type_none;
    csri     : out nv_csr_in_type  := nv_csr_in_type_none;
    --
    freeze   : in  std_ulogic;
    bootword : in  std_logic_vector(31 downto 0);
    smpflush : in  std_logic_vector(1 downto 0);
    perf     : out std_logic_vector(31 downto 0)
    );


begin
  assert not walk_pmp                report "walk_pmp not yet supported!" severity failure;
  assert tlb_pmp = 0                 report "tlb_pmp currently broken!" severity failure;
  assert not walk_pmp or mmuen = 1   report "walk_pmp must have mmuen!" severity failure;
  assert not walk_pmp or tlb_pmp = 1 report "walk_pmp must have tlb_pmp!" severity failure;
  assert ext_svnapot * tlb_pmp = 0   report "svnapot not yet supported with tlb_pmp!" severity failure;
end;

architecture rtl of cctrl5nv is

  signal hindex : integer range 0 to 15;


  function max(x,y: integer) return integer is
  begin
    if x>y then return x; else return y; end if;
  end max;

  function pick(b: boolean; tv,fv: integer) return integer is
  begin
    if b then return tv; else return fv; end if;
  end pick;


  -- To select different implementations
  constant SPARC : integer := 0;
  constant RISCV : integer := 1;
  constant arch  : integer := RISCV;
  constant L5    : integer := b2i(arch = SPARC);
  constant NV    : integer := b2i(arch = RISCV);

  constant TLBNUMMAX    : integer := maximum(htlbnum, maximum(dtlbnum, itlbnum));

  -- For NOELV 2 extra bits are needed to validate address.
  -- The maximum bits that are required to hold an address (physical or virtual).
  -- Two bits longer than the actual address, since we need to keep track of
  -- whether higher bits are the same or not (not same - bad address).
  -- These are what is really passed from iunv!
  constant vaddrbits  : integer := cond(addrbits = XLEN or (arch = SPARC), addrbits, addrbits + 2);
  constant physbits : integer := maximum(iphysbits, dphysbits);

  constant pmpen   : boolean := pmp_entries /= 0;
  constant pmp_msb : integer := physbits - 1;    -- High bit for PMP checks
  constant pmaen   : boolean := pma_entries /= 0;

  -- TLB PMP is required for ext_h,
  -- if there actually are any PMP entries.
  constant actual_tlb_pmp : boolean := tlb_pmp = 1 and (mmuen = 1 or walk_pmp) and (pmpen or pmaen);

  constant addr_check_mask : word8 := u2vec(addr_check, 8);

  -- Wrapper functions for mmucacheconfig.

  function is_riscv return boolean is
  begin
    return gaisler.mmucacheconfig.is_riscv(riscv_mmu);
  end;

  -- Actual physical address MSB.
  function pa_msb return integer is
  begin
    return minimum(physbits - 1, gaisler.mmucacheconfig.pa_msb(riscv_mmu));
  end;

  -- Guest physical address MSB.
  function ga_msb return integer is
  begin
    if ext_h = 1 then
      return gaisler.mmucacheconfig.ga_msb(riscv_mmu);
    else
      return pa_msb;
    end if;
  end;

  function has_pt(atp : atp_type) return boolean is
  begin
    return gaisler.mmucacheconfig.has_pt(riscv_mmu, atp);
  end;

  function vpn_split(vaddr : std_logic_vector) return word16_arr is
  begin
    return gaisler.mmucacheconfig.vpn_split(riscv_mmu, vaddr);
  end;

  function pte_paddr(data : std_logic_vector) return std_logic_vector is
  begin
    return gaisler.mmucacheconfig.pte_paddr(riscv_mmu, data);
  end;

  procedure pte_mark_modacc(data   : inout std_logic_vector; modified : std_logic;
                            needwb : out std_logic; needwblock : out std_logic) is
  begin
    gaisler.mmucacheconfig.pte_mark_modacc(riscv_mmu, data, modified, needwb, needwblock);
  end;

  -- Convert virtual vaddr to physical paddr, using vmask to OR correct levels.
  procedure virtual2physical(vaddr : std_logic_vector; mask : std_logic_vector;
                             paddr : inout std_logic_vector) is
  begin
    gaisler.mmucacheconfig.virtual2physical(riscv_mmu, vaddr, mask, paddr);
  end;

  -- Virtual address MSB.
  function va_msb return integer is
  begin
    return gaisler.mmucacheconfig.va_msb(riscv_mmu);
  end;

  function va_size(index : integer) return integer is
  begin
    return gaisler.mmucacheconfig.va_size(riscv_mmu, index);
  end;

  function va_size return integer is
  begin
    return gaisler.mmucacheconfig.va_size(riscv_mmu);
  end;

  function rv_ft_acc_resolve(at : word3; data : std_logic_vector)
    return std_logic_vector is
  begin
    return gaisler.mmucacheconfig.ft_acc_resolve(riscv_mmu, at, data);
  end;

  function is_valid_pte(data : std_logic_vector; mask : std_logic_vector
                       ) return boolean is
  begin
    return gaisler.mmucacheconfig.is_valid_pte(riscv_mmu, data, mask,
                                               ext_svpbmt = 1, ext_svnapot = 1);
  end;

  function is_pte(data : std_logic_vector) return boolean is
  begin
    return gaisler.mmucacheconfig.is_pte(riscv_mmu, data);
  end;

  function is_valid_ptd(data : std_logic_vector) return boolean is
  begin
    return gaisler.mmucacheconfig.is_valid_ptd(riscv_mmu, data);
  end;

  function is_ptd(data : std_logic_vector) return boolean is
  begin
    return gaisler.mmucacheconfig.is_ptd(riscv_mmu, data);
  end;

  function satp_base(satp : atp_type) return std_logic_vector is
  begin
    return gaisler.mmucacheconfig.satp_base(riscv_mmu, satp);
  end;


  -- Guest (or actual when no hypervisor) physical address MSB.
  -- For now this assumes that supervisor and hypervisor
  -- page table types are always the "same" and fixed.
  function gpa_msb return integer is
  begin
    if ext_h = 1 then
      return maximum(pa_msb, ga_msb);
    else
      return pa_msb;
    end if;
  end;

  -- MSB for TLB lookup address.
  -- This can be a virtual address, or a guest physical address when hypervisor.
  -- For now this assumes that supervisor and hypervisor
  -- page table typers are always the "same" and fixed.
  function gva_msb return integer is
  begin
    if ext_h = 1 then
      return maximum(va_msb, ga_msb);
    else
      return va_msb;
    end if;
  end;

  -- Virtual address
  constant va  : std_logic_vector(va_msb downto 0)  := (others => '0');
  constant vpn : std_logic_vector(va_msb downto 12) := (others => '0');

  -- Guest physical address
  constant ga  : std_logic_vector(ga_msb downto 0)  := (others => '0');

-- --  -- Incoming addresses have, at maximum, this many useful bits.
-- --  function addr_bits return integer is
-- --  begin
-- --    return maximum(gva_msb + 1, pa_msb + 1);
-- --  end;

  -- Actual physical address and page number
  --  constant pa  : std_logic_vector(gaisler.mmucacheconfig.pa_msb(riscv_mmu) downto 0) := (others => '0');
  constant pa  : std_logic_vector(pa_msb downto 0)   := (others => '0');
  constant ppn : std_logic_vector(pa_msb downto 12)  := (others => '0');

  -- To PT lookup
  -- Virtual address or guest physical address.
  constant gva : std_logic_vector(gva_msb downto 0)  := (others => '0');
  constant gvn : std_logic_vector(gva_msb downto 12) := (others => '0');

  -- From PT lookup
  -- Guest physical address or actual physical address.
  constant gpa : std_logic_vector(gpa_msb downto 0)  := (others => '0');
  constant gpn : std_logic_vector(gpa_msb downto 12) := (others => '0');

  -- These would be nicer with just (*a'range),
  -- but for some reason Vivado XSIM 2018.1 is then likely to crash.
  subtype gaddr_type  is std_logic_vector(ga'high downto ga'low);
  subtype paddr_type  is std_logic_vector(pa'high downto pa'low);
  subtype gvaddr_type is std_logic_vector(gva'high downto gva'low);
  subtype gpaddr_type is std_logic_vector(gpa'high downto gpa'low);

  type    gvaddr_repl_type is array(integer range <>) of gvaddr_type;

  subtype addr_type      is std_logic_vector(vaddrbits-1 downto 0);

  -- New
  -- TLB address bits always >= actual physical bits
  function tlb_addr_bits(arch : integer; physbits : integer; addrbits : integer) return integer is
  begin
    if arch = RISCV then
      return maximum(physbits, addrbits);
    else
      return 36; --physbits;
    end if;
  end;

  constant tlbabits : integer := tlb_addr_bits(arch, physbits, addrbits);

  function context_length(arch : integer; id : integer) return integer is
  begin
    if arch = SPARC then
      return 8;
    else -- RISCV
      if id > 0 then
        return id;
      else
        return 1;
      end if;
    end if;
  end;

  constant ctxbits : integer := context_length(arch, asidlen + vmidlen);
  subtype ctxword is std_logic_vector(ctxbits - 1 downto 0);


  -- CBO TYPE
  type cbo_type is record
    d1type    : word3;
    d2type    : word3;
    hold      : std_logic;
  end record;
  constant cbo_type_none : cbo_type := (
    d1type => (others => '0'), d2type => (others => '0'), hold => '0'
  );
  -- AMO TYPE
  type amo_type is record
    d1type    : std_logic_vector(5 downto 0);
    d2type    : std_logic_vector(5 downto 0);
    reserved  : std_logic;
    hold      : std_logic;
    addr      : std_logic_vector(physbits-1 downto 0);
    data      : word64;
    store     : std_logic_vector(5 downto 1);
    sc        : std_logic;
    lr_set    : std_logic;
  end record amo_type;
  constant amo_type_none : amo_type := (
    d1type => (others => '0'), d2type => (others => '0'),
    reserved => '0', hold => '0',
    addr => (others => '0'), data => (others => '0'), store => (others => '0'),
    sc => '0', lr_set => '0'
  );

  constant pte_hsize : std_logic_vector(2 downto 0) := gaisler.mmucacheconfig.pte_hsize(riscv_mmu);

  constant va_size_a : gaisler.mmucacheconfig.va_bits(1 to va_size) := (others => 0);

  -- 1xx - V, x1x - hPT, xx1 - (v)sPT
  -- 000  (H)U/(H)S/M no SATP                  (no mapping - not used in TLB unless walk_pmp)
  -- 001  (H)U/(H)S   SATP                     (stage-1 mapping only, via SATP)
  -- With H extension
  -- 010              HGATP                    (only used explicitly, in the actual hTLB)
  -- 011              <impossible>             (HGATP only valid with V)
  -- 100  VS/VU       neither VSATP nor HGATP  (no mapping - not used in TLB unless walk_pmp)
  -- 101  VS/VU       VSATP                    (stage-1 mapping only, via VSATP)
  -- 110  VS/VU       HGATP                    (stage-2 mapping only - guest physical (VA+2 bits) from IU)
  -- 111  VS/VU       VSATP and HGATP          (2-stage mapping)
  subtype mode_t is word3;

  -- MMU table walk registers
  -- bit set meaing
  --  0      data access (as opposed to instruction fetch)
  --  1      write
  --  2      ASI (only used by ASI read, and thus with ext_noelv, not yet in RISC-V!)
  --  3      doing hPT walk
  subtype  mmusel_type    is word4;
  constant access_i        : mmusel_type := "0000";
  constant access_r        : mmusel_type := "0001";
  constant access_w        : mmusel_type := "0011";
  constant access_asi_walk : mmusel_type := "0101";

  type pmp_t is record
    prv   : priv_lvl_type;
    mprv  : std_ulogic;
    mpp   : priv_lvl_type;
    addr  : paddr_type;
    acc   : pmpcfg_access_type;
    valid : std_ulogic;
  end record;

  constant pmp_clear : pmp_t := ((others => '0'), '0', (others => '0'),
                                 (others => '0'),
                                 (others => '0'), '0');

  type tlbcheck is record
    hit        : std_ulogic;
    amatch     : std_ulogic;
    paddr      : std_logic_vector(tlbabits-1 downto 0);
    perm       : word5;                                 -- unused
    hitv       : std_logic_vector(0 to TLBNUMMAX - 1);  -- unused
    id         : std_logic_vector(log2(TLBNUMMAX) - 1 downto 0);
    busw       : std_ulogic;
    cached     : std_ulogic;
    modded     : std_ulogic;
    svnapot    : std_ulogic;                         -- RISC-V svnapot (64 kByte entry)
    h_w        : std_ulogic;                         -- For RISC-V hypervisor, also writeable
    h_pmp_r    : std_ulogic;                         -- For RISC-V hypervisor (PMP R)
    h_pmp_no_w : std_ulogic;                         -- For RISC-V hypervisor (PMP blocks W)
    h_pmp_no_x : std_ulogic;                         -- For RISC-V hypervisor (PMP blocks X)
    h_perm     : word3;                              -- For RISC-V hypervisor (XWR)
    h_mask     : std_logic_vector(va_size_a'range);  -- For RISC-V hypervisor
    pbmt       : word2;                              -- RISC-V Svpbmt
    pma        : pma_t;                              -- RISC-V from PMA
    pmp_none   : std_ulogic;                         -- For RISC-V PMP unmatched (when walk_pmp)
    pmp_lock   : std_ulogic;                         -- For RISC-V PMP lock (when walk_pmp)
    pmp_rwx    : word3;                              -- For RISC-V PMP full rwx (when walk_pmp)
    clr        : std_ulogic;                         -- Hit but permission fail, so remove from TLB.
  end record;

  constant tlbcheck_none : tlbcheck := (
    '0', '0', (others => '0'), (others => '0'),
    (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '0', '0', '0',
    (others => '0'), (others => '0'),
    "00", pma_unused, '0', '0', "000",
    '0');

  -- ---------------------------------------------------------------------------
  --
  -- ---------------------------------------------------------------------------

  -- Way size in kbyte, and number of ways are specified rather than total cache size.
  -- Cache line size in 32 bit words.
  -- Way size:                                                      = waysize * 1024
  -- Cache line size:                                               = linesize * 4
  --
  -- Total cache size:          <way size> * <ways>                 = waysize * 1024 * ways
  -- Number of sets:            <cache size> / <ways> / <line size> = waysize * 1024 / (linesize * 4) =
  --                                                                = 256 * waysize / linesize
  --
  -- Total bits of addressing for a way: log2(<way size>)           = log2(waysize) + 10
  -- Offset (in cache line) bits:        log2(<line size>)          = log2(linesize) + 2
  -- Set index bits:                     <way bits> - <offset bits> = log2(waysize) - log2(linesize) + 8

  -- For a 4x4kByte cache with 32 byte (8 word) line we get:
  -- Data cache
  -- 2   1 -  0  Not used (bytes within 32 bit word)
  -- 3   4 -  2  DLINE_BITS (index correct word in line), DLINE_HIGH downto DLINE_LOW
  -- 7  11 -  5  DOFFSET_BITS, DOFFSET_HIGH downto DOFFSET_LOW (DLINE_HIGH + 1)
  --       - 12  TAG_HIGH downto DTAG_LOW
  -- Instruction cache
  -- 3   2 -  0  Not used (bytes within 64 bit word)
  -- 3*  4 -  3  ILINE_BITS (index correct word in line), ILINE_HIGH downto ILINE_LOW
  -- 7  11 -  5  IOFFSET_BITS, IOFFSET_HIGH downto IOFFSET_LOW (ILINE_HIGH + 1)
  --       - 12  TAG_HIGH downto ITAG_LOW

  constant LINESZMAX    : integer := max(dlinesize,ilinesize);
  constant BUF_HIGH     : integer := log2(LINESZMAX*4)-1;
  constant DLINE_BITS   : integer := log2(dlinesize);
  constant DOFFSET_BITS : integer := 8 +log2(dwaysize) - DLINE_BITS;
  constant DTAG_HIGH    : integer := dphysbits-1;
  constant DTAG_LOW     : integer := DOFFSET_BITS + DLINE_BITS + 2;  -- 10 + log2(dwaysize);
  constant DOFFSET_HIGH : integer := DTAG_LOW - 1;
  constant DOFFSET_LOW  : integer := DLINE_BITS + 2;
  constant ILINE_BITS   : integer := log2(ilinesize);
  constant IOFFSET_BITS : integer := 8 +log2(iwaysize) - ILINE_BITS;
  constant ITAG_HIGH    : integer := iphysbits-1;
  constant ITAG_LOW     : integer := IOFFSET_BITS + ILINE_BITS + 2;
  constant IOFFSET_HIGH : integer := ITAG_LOW - 1;
  constant IOFFSET_LOW  : integer := ILINE_BITS + 2;
  constant ILINE_HIGH   : integer := IOFFSET_LOW - 1;
  constant ILINE_LOW    : integer := 3;
  constant DLINE_HIGH   : integer := DOFFSET_LOW - 1;
  constant DLINE_LOW    : integer := 2;  -- for legacy reasons
  constant DLINE_LOW_REAL: integer := log2(cdataw/8);
  constant MAXOFFSET_HIGH: integer := max(DOFFSET_HIGH,IOFFSET_HIGH);
  constant MAXOFFSET_LOW : integer := max(DOFFSET_LOW,IOFFSET_LOW);
  constant MAXOFFSET_BITS: integer := MAXOFFSET_HIGH-MAXOFFSET_LOW+1;

  constant IMUXDATA     : boolean := false;

  constant IMISSPIPE     : boolean := false;
  constant DMISSPIPE     : boolean := false;

  constant REPL_SOFT    : integer := 0;
  constant REPL_RAND    : integer := 1;

  constant RND     : std_logic_vector(1 downto 0) := "11";
  constant LRR     : std_logic_vector(1 downto 0) := "10";
  constant LRU     : std_logic_vector(1 downto 0) := "01";
  constant DIR     : std_logic_vector(1 downto 0) := "00";

  -- If either wbmask=0 or busw=32, we have a 32-bit only system
  --  create modified constants xwbmask=0 and xbusw=32 for
  --  this case to make the code consistent.
  constant xwbmask : integer := pick(busw=32 or wbmask=0, 0,  wbmask);
  constant xbusw   : integer := pick(busw=32 or wbmask=0, 32, busw);

  constant d_ways   : std_logic_vector(0 to DWAYS - 1)                  := (others => '0');


  function get_itags_default return cram_tags is
    variable r: cram_tags;
  begin
    r := (others => (others => '0'));
    for w in 0 to IWAYS-1 loop
      r(w)(ITAG_HIGH-ITAG_LOW+1 downto ITAG_HIGH-ITAG_LOW-6) := x"FF";
      r(w)(ITAG_HIGH-ITAG_LOW-7 downto ITAG_HIGH-ITAG_LOW-8) := std_logic_vector(to_unsigned(w,2));
      r(w)(ITAG_HIGH-ITAG_LOW-9 downto ITAG_HIGH-ITAG_LOW-10) := std_logic_vector(to_unsigned(w,2));
      r(w)(0) := '0';
    end loop;
    return r;
  end get_itags_default;
  constant itags_default: cram_tags := get_itags_default;

  -- 3-way way permutations, per set
  -- s012 => way 0 - least recently used
  --         way 2 - most recently used
  constant s012 : std_logic_vector(2 downto 0) := "000";
  constant s021 : std_logic_vector(2 downto 0) := "001";
  constant s102 : std_logic_vector(2 downto 0) := "010";
  constant s120 : std_logic_vector(2 downto 0) := "011";
  constant s201 : std_logic_vector(2 downto 0) := "100";
  constant s210 : std_logic_vector(2 downto 0) := "101";


  -- 4-way way permutations, per set
  -- s0123 => way 0 - least recently used
  --          way 3 - most recently used
  -- bits assigned so bits 4:3 is LRU and 1:0 is MRU
  -- middle bit is 0 for 01 02 03 12 13 23, 1 for 10 20 30 21 31 32
  constant s0123 : std_logic_vector(4 downto 0) := "00011";
  constant s0132 : std_logic_vector(4 downto 0) := "00010";
  constant s0213 : std_logic_vector(4 downto 0) := "00111";
  constant s0231 : std_logic_vector(4 downto 0) := "00001";
  constant s0312 : std_logic_vector(4 downto 0) := "00110";
  constant s0321 : std_logic_vector(4 downto 0) := "00101";
  constant s1023 : std_logic_vector(4 downto 0) := "01011";
  constant s1032 : std_logic_vector(4 downto 0) := "01010";
  constant s1203 : std_logic_vector(4 downto 0) := "01111";
  constant s1230 : std_logic_vector(4 downto 0) := "01000";
  constant s1302 : std_logic_vector(4 downto 0) := "01110";
  constant s1320 : std_logic_vector(4 downto 0) := "01100";
  constant s2013 : std_logic_vector(4 downto 0) := "10011";
  constant s2031 : std_logic_vector(4 downto 0) := "10001";
  constant s2103 : std_logic_vector(4 downto 0) := "10111";
  constant s2130 : std_logic_vector(4 downto 0) := "10000";
  constant s2301 : std_logic_vector(4 downto 0) := "10101";
  constant s2310 : std_logic_vector(4 downto 0) := "10100";
  constant s3012 : std_logic_vector(4 downto 0) := "11010";
  constant s3021 : std_logic_vector(4 downto 0) := "11001";
  constant s3102 : std_logic_vector(4 downto 0) := "11110";
  constant s3120 : std_logic_vector(4 downto 0) := "11000";
  constant s3201 : std_logic_vector(4 downto 0) := "11101";
  constant s3210 : std_logic_vector(4 downto 0) := "11100";

  type lru_3way_table_vector_type is array(0 to 2) of std_logic_vector(2 downto 0);
  type lru_3way_table_type is array (0 to 7) of lru_3way_table_vector_type;

  constant lru_3way_table : lru_3way_table_type :=
    ( (s120, s021, s012),                   -- s012
      (s210, s021, s012),                   -- s021
      (s120, s021, s102),                   -- s102
      (s120, s201, s102),                   -- s120
      (s210, s201, s012),                   -- s201
      (s210, s201, s102),                   -- s210
      (s210, s201, s102),                   -- dummy
      (s210, s201, s102)                    -- dummy
      );

  type lru_4way_table_vector_type is array(0 to 3) of std_logic_vector(4 downto 0);
  type lru_4way_table_type is array(0 to 31) of lru_4way_table_vector_type;

  constant lru_4way_table : lru_4way_table_type :=
    ( (s2310, s0231, s0312, s0213),       -- "00000" (s0231/reset)
      (s2310, s0231, s0312, s0213),       -- "00001" s0231
      (s1320, s0321, s0132, s0123),       -- "00010" s0132
      (s1230, s0231, s0132, s0123),       -- "00011" s0123
      (s3210, s0321, s0312, s0213),       -- "00100" (s0321)
      (s3210, s0321, s0312, s0213),       -- "00101" s0321
      (s3120, s0321, s0312, s0123),       -- "00110" s0312
      (s2130, s0231, s0132, s0213),       -- "00111" s0213
      (s1230, s2301, s1302, s1203),       -- "01000" s1230
      (s1230, s2301, s1302, s1203),       -- "01001" (s1230)
      (s1320, s0321, s1032, s1023),       -- "01010" s1032
      (s1230, s0231, s1032, s1023),       -- "01011" s1023
      (s1320, s3201, s1302, s1203),       -- "01100" s1320
      (s1320, s3201, s1302, s1203),       -- "01101" (s1320)
      (s1320, s3021, s1302, s1023),       -- "01110" s1302
      (s1230, s2031, s1032, s1203),       -- "01111" s1203
      (s2130, s2301, s1302, s2103),       -- "10000" s2130
      (s2310, s2031, s0312, s2013),       -- "10001" s2031
      (s2130, s2031, s0132, s2013),       -- "10010" (s2013)
      (s2130, s2031, s0132, s2013),       -- "10011" s2013
      (s2310, s2301, s3102, s2103),       -- "10100" s2310
      (s2310, s2301, s3012, s2013),       -- "10101" s2301
      (s2130, s2031, s1032, s2103),       -- "10110" (s2103)
      (s2130, s2031, s1032, s2103),       -- "10111" s2103
      (s3120, s3201, s3102, s1203),       -- "11000" s3120
      (s3210, s3021, s3012, s0213),       -- "11001" s3021
      (s3120, s3021, s3012, s0123),       -- "11010" s3012
      (s3120, s3021, s3012, s0123),       -- "11011" (s3012)
      (s3210, s3201, s3102, s2103),       -- "11100" s3210
      (s3210, s3201, s3012, s2013),       -- "11101" s3201
      (s3120, s3021, s3102, s1023),       -- "11110" s3102
      (s3120, s3021, s3102, s1023)        -- "11111" (s3102)
      );

  type lru3_repl_table_single_type is array(0 to 2) of integer range 0 to 2;
  type lru3_repl_table_type is array(0 to 7) of lru3_repl_table_single_type;

  constant lru3_repl_table : lru3_repl_table_type :=
    ( (0, 1, 2),      -- s012
      (0, 2, 2),      -- s021
      (1, 1, 2),      -- s102
      (1, 1, 2),      -- s120
      (2, 2, 2),      -- s201
      (2, 2, 2),      -- s210
      (2, 2, 2),      -- dummy
      (2, 2, 2)       -- dummy
      );

  type lru4_repl_table_single_type is array(0 to 3) of integer range 0 to 3;
  type lru4_repl_table_type is array(0 to 31) of lru4_repl_table_single_type;

  constant lru4_repl_table : lru4_repl_table_type :=
    ( (0, 2, 2, 3), -- (s0231/reset)
      (0, 2, 2, 3), -- s0231
      (0, 1, 3, 3), -- s0132
      (0, 1, 2, 3), -- s0123
      (0, 3, 3, 3), -- (s0321)
      (0, 3, 3, 3), -- s0321
      (0, 3, 3, 3), -- s0312
      (0, 2, 2, 3), -- s0213
      (1, 1, 2, 3), -- s1230
      (1, 1, 2, 3), -- (s1230)
      (1, 1, 3, 3), -- s1032
      (1, 1, 2, 3), -- s1023
      (1, 1, 3, 3), -- s1320
      (1, 1, 3, 3), -- (s1320)
      (1, 1, 3, 3), -- s1302
      (1, 1, 2, 3), -- s1203
      (2, 2, 2, 3), -- s2130
      (2, 2, 2, 3), -- s2031
      (2, 2, 2, 3), -- (s2013)
      (2, 2, 2, 3), -- s2013
      (2, 2, 2, 3), -- s2310
      (2, 2, 2, 3), -- s2301
      (2, 2, 2, 3), -- (s2103)
      (2, 2, 2, 3), -- s2103
      (3, 3, 3, 3), -- s3120
      (3, 3, 3, 3), -- s3021
      (3, 3, 3, 3), -- s3012
      (3, 3, 3, 3), -- (s3012)
      (3, 3, 3, 3), -- s3210
      (3, 3, 3, 3), -- s3201
      (3, 3, 3, 3), -- s3102
      (3, 3, 3, 3)  -- (s3102)
      );

  type tlbent is record
    valid : std_ulogic;
    ctx   : std_logic_vector(ctxbits - 1 downto 0);
    mask  : std_logic_vector(va_size_a'range);
    vaddr : std_logic_vector(addrbits - 1 downto 12);
    paddr : std_logic_vector(tlbabits - 1 downto 12);
    perm  : std_logic_vector(4 downto 0);    -- priv write/priv read/user write/user read OK
    busw  : std_ulogic;
    cached: std_ulogic;
    modified: std_ulogic;
    acc: std_logic_vector(2 downto 0);        -- For SPARC: To reproduce PTE for probe ASI
    mode     : mode_t;                        -- RISC-V TLB entry type (V/hPT/[v]sPT)
    global   : std_ulogic;                    -- RISC-V global ([v]sPT ASID independent) entry
    svnapot  : std_ulogic;                    -- RISC-V svnapot (64 kByte entry)
    h_r      : std_ulogic;                    -- For RISC-V hypervisor (Hypervisor R)
    pmp_r    : std_ulogic;                    -- For RISC-V hypervisor (PMP R)
    pmp_no_w : std_ulogic;                    -- For RISC-V hypervisor (PMP blocks W)
    pmp_no_x : std_ulogic;                    -- For RISC-V hypervisor (PMP blocks X)
    pmp_none : std_ulogic;                    -- For RISC-V PMP unmatched (when walk_pmp)
    pmp_lock : std_ulogic;                    -- For RISC-V PMP lock (when walk_pmp)
    pmp_rwx  : word3;                         -- For RISC-V PMP full rwx (when walk_pmp)
    pbmt     : word2;                         -- RISC-V Svpbmt
    pma      : pma_t;                         -- RISC-V from PMA
  end record;
  type tlbentarr is array(natural range <>) of tlbent;
  constant tlbent_defmap: tlbent := (
    valid => to_bit(L5), ctx => (others => '0'), mask => (others => '0'), --mask1 => '0', mask2 => '0', mask3 => '0',
    vaddr => (others => '0'),
    paddr => (others => '0'),
    perm => "11111",
    busw => '0',
    cached => '0',
    modified => '1',
    acc => "011",
    mode => (others => '0'),
    global => '0',
    svnapot => '0',
    h_r => '0',
    pmp_r => '0',
    pmp_no_w => '0',
    pmp_no_x => '0',
    pmp_none => '0',
    pmp_lock => '0',
    pmp_rwx => "000",
    pbmt => "00",
    pma => pma_unused
    );
  constant tlbent_empty: tlbent := (
    valid => '0', ctx => (others => '0'), mask => (others => '0'), --mask1 => '0', mask2 => '0', mask3 => '0',
    vaddr => (others => '0'),
    paddr => (others => '0'),
    perm => "00000",
    busw => '0',
    cached => '0',
    modified => '0',
    acc => "011",
    mode => (others => '0'),
    global => '0',
    svnapot => '0',
    h_r => '0',
    pmp_r => '0',
    pmp_no_w => '0',
    pmp_no_x => '0',
    pmp_none => '0',
    pmp_lock => '0',
    pmp_rwx => "000",
    pbmt => "00",
    pma => pma_unused
    );
  constant tlb_def1: tlbentarr(1 to TLBNUMMAX-1) := (others => tlbent_empty);
  constant tlb_def: tlbentarr(0 to TLBNUMMAX-1) := tlbent_defmap & tlb_def1;

  subtype lruent is std_logic_vector(4 downto 0);
  type lruarr is array(natural range <>) of lruent;

  type cctrl5nv_state is (as_normal, as_flush, as_icfetch,
                        as_dcfetch, as_dcfetch2,
                        as_dcsingle, as_mmuwalk, as_mmuwalk3, as_mmuwalk4,
                        as_wptectag1, as_wptectag2, as_wptectag3,       --10...
                        as_slowwr,                                      -- 15..
                        as_wrasi, as_wrasi2, as_wrasi3,
                        as_rdasi, as_rdasi2,
                        as_rdcdiag, as_rdcdiag2,
                        as_atomic1, as_atomic2, as_atomic3, as_atomic4, -- 23..
                        as_parked,
                        as_mmuprobe2, as_mmuprobe3, as_mmuflush2,
                        as_regflush, as_bifwait,
                        as_bifwait_unlock,                              -- 33..
                        as_rv_check_busw,
                        as_rv_ifailkind, as_rv_dfailkind,
                        as_rv_start_walk, as_rv_start_pmp,              -- 37..
                        as_rv_mmu_pt1addr_chk, as_rv_mmuwalk, as_rv_mmu_pte1_hchk, as_rv_mmu_pte1_pmpchk,
                        as_rv_mmuwalk_lock, as_rv_xmmuwalk_lock, as_rv_xwpte,
                        as_rv_mmuwalk_pterr, as_rv_mmuwalk_pmperr,
                        as_rv_mmu_pt2addr_pmpchk, as_rv_hmmuwalk, as_rv_mmu_pte2_pmpchk,
                        as_rv_hmmuwalk_lock, as_rv_hmmuwalk_done, as_rv_hwpte,
                        as_rv_hmmuwalk_pterr, as_rv_hmmuwalk_pmperr,
                        as_rv_cbo
                       );


  type cctrltype5 is record
    dfrz    : std_ulogic;                                -- dcache freeze enable
    ifrz    : std_ulogic;                                -- icache freeze enable
    dsnoop  : std_ulogic;                                -- data cache snooping
    dcs     : std_logic_vector(1 downto 0);      -- dcache state
    ics     : std_logic_vector(1 downto 0);      -- icache state
    ics_btb : std_logic_vector(1 downto 0);     -- icache state output to btb
    wcomben : std_ulogic;                       -- automatic write combining enable
    wchinten: std_ulogic;                       -- write combining hint enable
    diaemru : std_ulogic;               -- defer instruction access exception
                                        -- mmu register updates until trap is
                                        -- taken
  end record;

  constant M_CTX_SZ       : integer := 8*L5 + ctxbits*NV; -- Not used in RISCV (always 8 for SPARC)
  constant MMCTRL_CTXP_SZ : integer := 30;

  type mmctrl_type1 is record
    e       : std_logic;                                        -- enable
    nf      : std_logic;                                        -- no fault
    pso     : std_logic;                                        -- partial store order
    ctx     : std_logic_vector(M_CTX_SZ-1 downto 0);-- context nr
    ctxp    : std_logic_vector(MMCTRL_CTXP_SZ-1 downto 0);  -- context table pointer
    tlbdis  : std_logic;                            -- tlb disabled
    bar     : std_logic_vector(1 downto 0);         -- preplace barrier
  end record;

  constant mmctrl_type1_none : mmctrl_type1 := ('0', '0', '0', (others => '0'), (others => '0'), '0', (others => '0'));

  --# fault status reg
  type mmctrl_fs_type is record
    ow    : std_logic;
    fav   : std_logic;
    ft    : std_logic_vector(2 downto 0);                 -- fault type
    at_ls : std_logic;                              -- access type, load/store
    at_id : std_logic;                              -- access type, i/dcache
    at_su : std_logic;                              -- access type, su/user
    l     : std_logic_vector(1 downto 0);           -- level
    ebe   : std_logic_vector(7 downto 0);
  end record;

  constant mmctrl_fs_zero : mmctrl_fs_type :=
    ('0', '0', "000", '0', '0', '0', "00", "00000000");

  type regfl_pipe_entry is record
    valid: std_ulogic;
    addr: std_logic_vector(MAXOFFSET_HIGH downto MAXOFFSET_LOW);
  end record;
  constant regfl_pipe_entry_zero: regfl_pipe_entry := (
    valid => '0',
    addr => (others => '0')
    );
  type regfl_pipe_array is array (0 to 2) of regfl_pipe_entry;

  -- ECC configuration
  type ftctrltype5 is record
    cemode: std_logic_vector(1 downto 0);  -- 00=correct, 01=ignore, 11=flush
    uemode: std_logic_vector(1 downto 0);  -- 00=flush minimal, 01=flush all,
                                           -- 10=enter ECC-fail mode
    itcmcemode : std_ulogic;            -- 1=do not restart on FPGA-CE 0=restart/correct
    itcmuemode : std_ulogic;            -- 1=ECC-fail mode, 0=set location to zeros
    dtcmcemode : std_ulogic;            -- 1=do not restart on FPGA-CE 0=restart/correct
    dtcmuemode : std_ulogic;            -- 1=ECC-fail mode, 0=set location to zeros/ones
    dtcmueval  : std_ulogic;            -- value to set on DTCM UE
    rfcemode: std_logic_vector(0 downto 0);  -- 1=do not restart on FPGA-CE 0=restart/correct
    rfuemode: std_logic_vector(0 downto 0);  -- 1=ECC-fail mode, 0=restart/correct
    scrubper : std_logic_vector(15 downto 0);
    scruben  : std_ulogic;
  end record;

  constant ftctrl_init : ftctrltype5 := ("00", "00", '0', '0', '0', '0', '0', "0", "0", x"00ff", '0');

  type eictrltype5 is record
    eiue     : std_ulogic;
    eibit1   : std_logic_vector(5 downto 0);
    eibit2   : std_logic_vector(5 downto 0);
  end record;

  constant eictrl_init : eictrltype5 := ('0', "000000", "000000");

  type cctrl5nv_regs is record
    -- config registers
    cctrl: cctrltype5;    -- Not used on RISC-V (CSR)
    mmctrl1: mmctrl_type1;
    mmfsr: mmctrl_fs_type;
    mmfar: std_logic_vector(31 downto 12);
    regflmask: std_logic_vector(dphysbits-1 downto 4);
    regfladdr: std_logic_vector(dphysbits-1 downto 4);
    iregflush: std_ulogic;
    dregflush: std_ulogic;
    iuctrl: iu_control_reg_type;
    itcmenp: std_ulogic;
    itcmenva: std_ulogic;
    itcmenvc: std_ulogic;
    itcmperm: std_logic_vector(1 downto 0);
    itcmaddr: std_logic_vector(31 downto 16);
    itcmctx: std_logic_vector(ctxbits-1 downto 0);
    dtcmenp: std_ulogic;
    dtcmenva: std_ulogic;
    dtcmenvc: std_ulogic;
    dtcmperm: std_logic_vector(3 downto 0);
    dtcmaddr: std_logic_vector(31 downto 16);
    dtcmctx: std_logic_vector(ctxbits-1 downto 0);
    itcmwipe: std_ulogic;
    dtcmwipe: std_ulogic;
    -- FSM state
    s: cctrl5nv_state;
    -- control flags
    imisspend: std_ulogic;
    dmisspend: std_ulogic;
    iflushpend: std_ulogic;
    dflushpend: std_ulogic;
    slowwrpend: std_ulogic;
    dbgaccpend: std_ulogic;
    syncbar: std_ulogic;  -- Barrier (dci.bar(1:0) /= 0, AMO/fence)
    holdn: std_ulogic;
    ramreload: std_ulogic;
    stbuffull: std_ulogic;
    flushwrd: std_logic_vector(0 to DWAYS-1);
    flushwri: std_logic_vector(0 to IWAYS-1);
    regflpipe: regfl_pipe_array;
    regfldone: std_ulogic;
    mmuaddr: std_logic_vector(physbits-1 downto 0);
    -- MMU TLBs
    itlb: tlbentarr(0 to itlbnum-1);
    dtlb: tlbentarr(0 to dtlbnum-1);
    tlbflush: std_ulogic;
    newent: tlbent;
    mmuerr: mmctrl_fs_type;
    curerrclass: std_logic_vector(1 downto 0);
    newerrclass: std_logic_vector(1 downto 0);
    itlbpmru: std_logic_vector(0 to itlbnum-1);
    dtlbpmru: std_logic_vector(0 to dtlbnum-1);
    tlbupdate: std_ulogic;
    -- Tag pipeline registers for special functions (region flush)
    itagpipe: cram_tags;
    dtagpipe: cram_tags;
    untagd: std_logic_vector(2*DWAYS-1 downto 0);
    untagi: std_logic_vector(2*IWAYS-1 downto 0);
    -- IĆache logic registers
    i2pc: std_logic_vector(vaddrbits-1 downto 0);
    i2paddr: std_logic_vector(iphysbits-1 downto 0);
    i2paddrv: std_ulogic;
    i2busw: std_ulogic;
    i2paddrc: std_ulogic;
    i2tlbhit: std_ulogic;
    i2tlbclr: std_ulogic;
    i2tlbid: std_logic_vector(log2x(itlbnum)-1 downto 0);
    i2ctx: std_logic_vector(ctxbits-1 downto 0);
    i2su: std_ulogic;
    i2nostream : std_ulogic;                      -- Force no stream buffer hit?
    i2m : std_ulogic;                             -- Machine mode execution?
    i2mode : mode_t;
    --
    i2bufmatch: std_ulogic;
    i2hitv: std_logic_vector(0 to IWAYS-1);
    i2validv: std_logic_vector(0 to IWAYS-1);
    i2tcmhit: std_ulogic;
    i1ten: std_ulogic;
    i1pc: std_logic_vector(vaddrbits-1 downto 0);
    i1pc_repl: std_logic_vector(tlbrepl*vaddrbits-1 downto 0);
    i1ctx: std_logic_vector(ctxbits-1 downto 0);
    i1ctx_repl: std_logic_vector(tlbrepl*ctxbits-1 downto 0);
    i1su: std_ulogic;
    i1cont: std_ulogic;
    i1rep: std_ulogic;
    i1tcmen: std_ulogic;
    i1nostream : std_ulogic;                      -- Force no stream buffer hit?
    i1m : std_ulogic;                             -- Machine mode execution?
    i1mode : mode_t;
    --
    ibpmiss: std_ulogic;
    iramaddr: std_logic_vector(log2(ilinesize*4)-1 downto 3);
    irdbufen: std_ulogic;
    irdbufpaddr: std_logic_vector(iphysbits-1 downto log2(ilinesize*4));
    irdbufvaddr: std_logic_vector(vaddrbits-1 downto log2(ilinesize*4));
    irephitv: std_logic_vector(0 to IWAYS-1);
    irepvalidv: std_logic_vector(0 to IWAYS-1);
    irepway: std_logic_vector(1 downto 0);
    ireptcmhit: std_ulogic;
    irepdata: cdatatype5;
    ireptlbhit: std_ulogic;
    ireptlbpaddr: std_logic_vector(tlbabits-1 downto 0);
    ireptlbid: std_logic_vector(log2x(itlbnum)-1 downto 0);
    tcmdata: std_logic_vector(31 downto 0);
    itlbprobeid: std_logic_vector(log2x(itlbnum)-1 downto 0);
    -- DCache logic registers
    d2vaddr: std_logic_vector(vaddrbits-1 downto 0);
    d2paddr: std_logic_vector(dphysbits-1 downto 0);
    d2paddrv: std_ulogic;
    d2tlbhit: std_ulogic;
    d2tlbamatch: std_ulogic;
    d2tlbid: std_logic_vector(log2x(dtlbnum)-1 downto 0);
    d2tlbclr: std_ulogic;
    d2data: std_logic_vector(63 downto 0);
    d2write: std_ulogic;
    d2size: std_logic_vector(1 downto 0);
    d2busw: std_ulogic;
    d2tlbmod: std_ulogic;
    d2hitv: std_logic_vector(0 to DWAYS-1);
    d2validv: std_logic_vector(0 to DWAYS-1);
    d2asi: std_logic_vector(7 downto 0);
    d2specialasi: std_ulogic;
    d2forcemiss: std_ulogic;
    d2su: std_ulogic;
    d2m : std_ulogic;
    d2sum : std_ulogic;
    d2mxr : std_ulogic;
    d2vmxr : std_ulogic;
    d2mode : mode_t;
    d2ctx: std_logic_vector(ctxbits-1 downto 0);
    d2hx : std_ulogic;
    d2ss : std_ulogic;
    --
    d2nb64en: std_ulogic;
    d2nb64ctr: std_ulogic;
    d2nb64den: std_ulogic;
    d2nb64dctr: std_ulogic;
    d2stbcont: std_ulogic;
    d2wcctr: std_logic_vector(1 downto 0);
    d2wchold: std_logic_vector(2 downto 0);
    d2specread: std_ulogic;
    d2nocache: std_ulogic;                      -- Marks whether cacheable
    d2tcmhit: std_ulogic;
    d2atomic: std_ulogic;
    d2cas: std_ulogic;
    d2casdata: std_logic_vector(31 downto 0);
    d2cascmp: std_logic_vector(7 downto 0);  -- max of 2*DWAYS and DLINESIZE
    d1ten: std_ulogic;                          -- Check D$ tags
    d1chk: std_ulogic;                          -- Check DTLB etc
    d1vaddr: std_logic_vector(vaddrbits-1 downto 0);
    d1vaddr_repl: std_logic_vector(tlbrepl*vaddrbits-1 downto 0);
    d1asi: std_logic_vector(7 downto 0);
    d1su: std_ulogic;
    d1m : std_ulogic;
    d1sum : std_ulogic;
    d1mxr : std_ulogic;
    d1vmxr : std_ulogic;
    d1mode : mode_t;
    d1ctx: std_logic_vector(ctxbits-1 downto 0);
    d1ctx_repl: std_logic_vector(tlbrepl*ctxbits-1 downto 0);
    d1hx : std_ulogic;
    d1ss : std_ulogic;
    --
    d1specialasi: std_ulogic;
    d1forcemiss: std_ulogic;
    d1tcmen: std_ulogic;
    dramaddr: std_logic_vector(log2(dlinesize*4)-1 downto log2(cdataw/8));
    dvtagdone: std_ulogic;
    dregval: std_logic_vector(63 downto 0);
    dregerr: std_ulogic;
    dregmux: std_ulogic;
    dtlbbypass: std_ulogic;
    dwchint: std_ulogic;  -- Write combine hint (dci.bar(2) /= 0)
    -- LRU
    ilru: lruarr(0 to 2**IOFFSET_BITS-1);
    dlru: lruarr(0 to 2**DOFFSET_BITS-1);
    -- Common flush registers
    flushctr: std_logic_vector(MAXOFFSET_HIGH downto MAXOFFSET_LOW);
    flushpart: std_logic_vector(1 downto 0);
    dtflushdone: std_ulogic;
    -- MMU table walk registers
    mmusel: std_logic_vector(3 downto 0);
    -- FPC debug interface (ASI 0x20)
    fpc_mosi : l5_intreg_mosi_type;
    -- CPU-to-CPU control interface (ASI 0x22)
    c2c_mosi : l5_intreg_mosi_type;
    -- IU BTB/BHT diagnostic interface (ASI 0x24)
    iudiag_mosi : l5_intreg_mosi_type;
    -- context switch status signal
    ctxswitch : std_ulogic;
    -- debug access state
    fsmidle : std_ulogic;
    dbgacc : std_logic_vector(1 downto 0);
    dbgaccwr : std_ulogic;
    -- pending and lost trap state
    itrappend: std_logic_vector(2 downto 0);  -- 0:AHB error 1:MMU error 2:TCM perm error
    itraplost: std_logic_vector(2 downto 0);  -- 0:AHB error 1:MMU error 2:TCM perm error
    itraptype: std_logic_vector(1 downto 0);  -- Reason for most recent instruction
                                              -- access exception
    wtrappend: std_logic_vector(1 downto 0);  -- 0:AHB error, 1:MMU writeback error
    wtraplost: std_logic_vector(1 downto 0);
    wtraptype: std_ulogic;
    ahbwtrapmode: std_logic_vector(1 downto 0);
    mmuwtrapmode: std_logic_vector(1 downto 0);
    ctrappend: std_logic_vector(3 downto 0);
    ctraptype: std_logic_vector(1 downto 0);
    ctrapacc: std_logic_vector(3 downto 0);
    dtrapet0: std_ulogic;
    dtrapet1: std_ulogic;
    dtraptt: std_logic_vector(5 downto 0);
    perf     : std_logic_vector(31 downto 0);
    -- Bus interface registers
    bifwait_op : std_logic_vector(3 downto 0);
    bifwait_wc : std_ulogic;
    biflocked  : std_ulogic;
    ifailkind   : word2;          -- Instruction fault not dependent on anything in TLB
    dfailkind   : word2;          -- Data fault not dependent on anything in TLB
    i1pmp       : std_ulogic;     -- wptectag IPMP recheck
    d1pmp       : std_ulogic;     -- wptectag DPMP recheck
    aregval     : word32;
    bregval     : word64;
    -- Atomic instruction interface (RISC-V)
    amo         : amo_type;
    -- Cache Block Operation interface (RISC-V)
    cbo         : cbo_type;
    -- PMP not in TLB
    pt_no_w     : std_ulogic;                       -- PMP/PMA blocks PT write
    -- PMP in TLB
    pmp_mask    : addr_type;                        -- Address mask for lookup
    pmp_low     : addr_type;                        -- Low address for lookup
    pmp_m       : std_ulogic;                       -- M mode check
    pmp_do      : std_ulogic;                       -- Do PMP check
    pmp_only    : std_ulogic;                       -- No PMA (for diagnostics)
    pmp_hit     : std_ulogic;                       -- There was a hit
    pmp_fit     : std_ulogic;                       -- Hit fit in PMP entry
    pmp_hitv    : std_logic_vector(pmp_entries - 1 downto 0);  -- For diagnostics
    pmp_fitv    : std_logic_vector(pmp_entries - 1 downto 0);  -- For diagnostics
    pmp_m_rwx   : word3;                            -- [SME]PMP rights for M
    pmp_su_rwx  : word3;                            -- [SME]PMP rights for S/U
    pmp_rwx     : word3;                            -- PMP RWX bits
    pmp_idx     : std_logic_vector(5 downto 0);     -- Matching PMP index
    pmp_none    : std_ulogic;                       -- No PMP hit
    pmp_lock    : std_ulogic;                       -- Matching PMP was locked
    -- PMA in TLB
    pma_hit     : std_ulogic;
    pma_fit     : std_ulogic;
    pma_hitv    : std_logic_vector(PMAENTRIES - 1*b2i(pmaen) downto 0);  -- For diagnostics
    pma_fitv    : std_logic_vector(PMAENTRIES - 1*b2i(pmaen) downto 0);  -- For diagnostics
    pma_idx     : std_logic_vector(log2x(PMAENTRIES) - 1*b2i(pmaen) downto 0);
    pma         : pma_t;
    -- Page fault markers
    swalk_fault : std_ulogic;                       -- Fault due to sPT walk start
    hwalk_fault : std_ulogic;                       -- Fault due to hPT walk start
    -- Hypervisor
    htlb        : tlbentarr(0 to htlbnum - 1);
    htlbpmru    : std_logic_vector(0 to htlbnum - 1);
    htlbflush   : std_ulogic;
    h2tlbupd    : std_ulogic;                       -- TLB entry updated
    h2tlbid     : std_logic_vector(log2x(htlbnum) - 1 downto 0);
    h2tlbclr    : std_ulogic;                       -- Invalidate TLB entry due to permission failure
    h_addr      : gaddr_type;                       -- Address to check against hTLB
    h_addr_repl: std_logic_vector(tlbrepl*vaddrbits-1 downto 0);
    h_ctx_repl: std_logic_vector(tlbrepl*ctxbits-1 downto 0);
    h_do        : std_ulogic;                       -- Do hTLB lookup
    h_done      : std_ulogic;                       -- Marks end of hPT walk and hTLB update
    h_v         : std_ulogic;
    h_x         : std_ulogic;
    h_ls        : std_ulogic;
    h_mxr       : std_ulogic;
    h_vmxr      : std_ulogic;
    h_hx        : std_ulogic;
    h_cause     : word2;                            -- 00 - PT walk, 01 - PTE area
    h_w         : std_ulogic;
    h_pmp_no_w  : std_ulogic;  -- Hypervisor note about PMP causing blocking of writes.
    h_pmp_no_x  : std_ulogic;  -- Hypervisor note about PMP causing blocking of execution.
    addrhyper   : gaddr_type;
    itypehyper  : word2;  -- 00 OK, 01 access, 10 PT R, 11 - PT W  (full addrhyper for 10/11).
    dtypehyper  : word2;
    hnewent     : tlbent;
    dbg         : std_logic_vector(31 downto 0);
    --
  end record;

  function cctrl5_regs_res return cctrl5nv_regs is
    variable v: cctrl5nv_regs;
  begin
    v := (
      cctrl => (dfrz => '0', ifrz => '0', dsnoop => '0',
                dcs => (others => '0'), ics => (others => '0'),
                ics_btb => (others=>'0'), wcomben => '0', wchinten => '1',
                diaemru => '0'
                ),
      mmctrl1 => mmctrl_type1_none, mmfsr => mmctrl_fs_zero, mmfar => (others => '0'),
      regflmask => (others => '0'), regfladdr => (others => '0'), iregflush => '0', dregflush => '0',
      iuctrl => iu_control_reg_default,
      itcmenp => '0', itcmenva => '0', itcmenvc => '0', itcmperm => "00",
      itcmaddr => (others => '0'), itcmctx => (others => '0'),
      dtcmenp => '0', dtcmenva => '0', dtcmenvc => '0', dtcmperm => "0000",
      dtcmaddr => (others => '0'), dtcmctx => (others => '0'), itcmwipe => '0', dtcmwipe => '0',
      s => as_normal, imisspend => '0', dmisspend => '0',
      iflushpend => '1', dflushpend => '1', slowwrpend => '0', dbgaccpend => '0', syncbar => '0',
      holdn => '1',
      ramreload => '0', stbuffull => '0',
      flushwrd => (others => '0'), flushwri => (others => '0'), regflpipe => (others => regfl_pipe_entry_zero),
      regfldone => '0',
      untagd => (others => '0'), untagi => (others => '0'),
      mmuaddr => (others => '0'),
      itlb => tlb_def(0  to itlbnum-1), dtlb => tlb_def(0 to dtlbnum-1),
      tlbflush => '0', newent => tlbent_empty, mmuerr => mmctrl_fs_zero,
      curerrclass => "00", newerrclass => "00",
      itlbpmru => (others => '0'), dtlbpmru => (others => '0'),
      tlbupdate => '0', itagpipe => (others => (others => '0')), dtagpipe => (others => (others => '0')),
      i2pc => (others => '0'), i2paddr => (others => '0'),
      i2paddrv => '0',
      i2busw => '0', i2paddrc => '0',
      i2tlbhit => '0', i2tlbclr => '0', i2tlbid => (others => '0'),
      i2ctx => (others => '0'), i2su => '0',
      -- RISCV
      i2nostream => '0', i2m => '0', i2mode => (others => '0'),
      --
      i2bufmatch => '0',
      i2hitv => (others => '0'), i2validv => (others => '0'), i2tcmhit => '0',
      i1ten => '0', i1pc => (others => '0'), i1pc_repl => (others => '0'), i1ctx => (others => '0'), i1ctx_repl => (others => '0'), i1su => '0', i1cont => '0', i1rep => '0', i1tcmen => '0',
      -- RISCV
      i1nostream => '0', i1m => '0', i1mode => (others => '0'),
      --
      ibpmiss => '0', iramaddr => (others => '0'),
      irdbufen => '0', irdbufpaddr => (others => '0'), irdbufvaddr => (others => '0'),
      irephitv => (others => '0'), irepvalidv => (others => '0'),
      irepway => "00", ireptcmhit => '0', irepdata => (others => (others => '0')),  ireptlbhit => '0',
      ireptlbpaddr => (others => '0'), ireptlbid => (others => '0'), tcmdata => (others => '0'),
      itlbprobeid => (others => '0'),
      d2vaddr => (others => '0'), d2paddr => (others => '0'),
      d2paddrv => '0',
      d2tlbhit => '0', d2tlbamatch => '0', d2tlbid => (others => '0'), d2tlbclr => '0',
      d2data => (others => '0'), d2write => '0', d2busw => '0', d2tlbmod => '0',
      d2hitv => (others => '0'), d2validv => (others => '0'),
      d2size => "00", d2asi => "00000000", d2specialasi => '0', d2forcemiss => '0', d2su => '0',
      -- RISCV
      d2m => '0', d2sum => '0', d2mxr => '0', d2vmxr => '0', d2mode => (others => '0'),
      d2ctx => (others => '0'), d2hx => '0', d2ss => '0',
      --
      d2nb64en => '0', d2nb64ctr => '0', d2nb64den => '0', d2nb64dctr => '0',
      d2stbcont => '0', d2wcctr => "00", d2wchold => "000",
      d2specread => '0', d2nocache => '0', d2tcmhit => '0',
      d2atomic => '0', d2cas => '0', d2casdata => (others => '0'), d2cascmp => (others => '0'),
      d1ten => '0', d1chk => '0', d1vaddr => (others => '0'), d1vaddr_repl => (others => '0'),
      d1asi => "00000000", d1su => '0',
      -- RISCV
      d1m => '0', d1sum => '0', d1mxr => '0', d1vmxr => '0', d1mode => (others => '0'),
      d1ctx => (others => '0'), d1ctx_repl => (others => '0'), d1hx => '0', d1ss => '0',
      --
      d1specialasi => '0', d1forcemiss => '0', d1tcmen => '0',
      dramaddr => (others => '0'), dvtagdone => '0',
      dregval => (others => '0'), dregerr => '0', dregmux => '0', dtlbbypass => '0',
      ilru => (others => (others => '0')), dlru => (others => (others => '0')),
      flushctr => (others => '0'), flushpart => (others => '0'), dtflushdone => '0',
      dwchint => '0',
      mmusel => (others => '0'), fpc_mosi => l5_intreg_mosi_none, c2c_mosi => l5_intreg_mosi_none,
      iudiag_mosi => l5_intreg_mosi_none,
      ctxswitch => '0',
      fsmidle => '0', dbgacc => "00", dbgaccwr => '0',
      itrappend => "000", itraplost => "000", itraptype => "00",
      wtrappend => "00", wtraplost => "00", wtraptype => '0',
      ahbwtrapmode => "01", mmuwtrapmode => "10",
      ctrappend => "0000", ctraptype => "00", ctrapacc => "0000",
      dtrapet0 => '0', dtrapet1 => '0', dtraptt => "000000"
      , perf => (others => '0'),
      bifwait_op => BIFOP_NOP,
      bifwait_wc => '0',
      biflocked => '0',
      ifailkind => "00", dfailkind => "00",
      i1pmp => '0', d1pmp => '0',
      aregval => (others => '0'), bregval => (others => '0'),
      amo => amo_type_none, cbo => cbo_type_none,
      pt_no_w => '0',
      pmp_mask => (others => '0'), pmp_low => (others => '0'), pmp_m => '0', pmp_do => '0', pmp_only => '0',
      pmp_hit => '0', pmp_fit => '0',
      pmp_hitv => (others => '0'), pmp_fitv => (others => '0'),
      pmp_m_rwx => (others => '0'), pmp_su_rwx => (others => '0'), pmp_rwx => (others => '0'),
      pmp_idx => (others => '0'), pmp_none => '0', pmp_lock => '0',
      pma_hit => '0', pma_fit => '0', pma_hitv => (others => '0'), pma_fitv => (others => '0'),
      pma_idx => (others => '0'), pma => pma_unused,
      swalk_fault => '0', hwalk_fault => '0',
      htlb => tlb_def(0 to htlbnum-1), htlbpmru => (others => '0'),
      htlbflush => '0', h2tlbupd => '0', h2tlbid => (others => '0'), h2tlbclr => '0',
      h_addr => (others => '0'), h_addr_repl => (others => '0'), h_ctx_repl => (others => '0'),
      h_do => '0', h_done => '0', h_v => '0', h_x => '0', h_ls => '0', h_mxr => '0', h_vmxr => '0',
      h_hx => '0', h_cause => (others => '0'), h_w => '0', h_pmp_no_w => '0', h_pmp_no_x => '0',
      addrhyper => (others => '0'), itypehyper => (others => '0'), dtypehyper => (others => '0'),
      hnewent => tlbent_empty
      ,dbg => (others => '0')
      );
    return v;
  end cctrl5_regs_res;

  constant RRES: cctrl5nv_regs := cctrl5_regs_res;

  subtype vbitent is std_logic_vector(0 to dways-1);
  type vbitarr is array(natural range <>) of vbitent;

  type cctrl5_snoop_regs is record
    -- DCache valid bits for dtagconf>0
    validarr: vbitarr(0 to 2**DOFFSET_BITS-1);
  end record;

  constant RSRES: cctrl5_snoop_regs :=
    (validarr => (others => (others => '0'))
     );

  constant hconfig : ahb_config_type := (
    --0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_LEON5, 0, LEON5_VERSION, 0),
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_LEON5, 0, 0, 0),
    others => zero32);

  constant zerov: std_logic_vector(31 downto 0) := (others => '0');
  constant onev : std_logic_vector(31 downto 0) := (others => '1');

  signal r,c: cctrl5nv_regs;
  signal rs,cs: cctrl5_snoop_regs;

  signal dbg: std_logic_vector(12 downto 0);

begin

  comb: process(r, rs, rst,
                ici, dci, ahbso, cramo, bifo,
                fpc_miso, c2c_miso,
                csro,
                freeze, bootword, smpflush, endian)

    function getdmask64(addr: std_logic_vector; size: std_logic_vector; le: boolean) return std_logic_vector is
      variable vaddr: std_logic_vector(addr'length-1 downto 0);
      variable vsize: std_logic_vector(size'length-1 downto 0);
      variable dmask: std_logic_vector(7 downto 0);
    begin
      vaddr := addr; vsize := size;
      dmask := "11111111";
      if vsize(1 downto 0)/="11" then
        if vaddr(2)='0' xor le then
          dmask := dmask and "11110000";
        else
          dmask := dmask and "00001111";
        end if;
      end if;
      if vsize(1)='0' then
        if vaddr(1)='0' xor le then
          dmask := dmask and "11001100";
        else
          dmask := dmask and "00110011";
        end if;
      end if;
      if vsize(1 downto 0)="00" then
        if vaddr(0)='0' xor le then
          dmask := dmask and "10101010";
        else
          dmask := dmask and "01010101";
        end if;
      end if;
      return dmask;
    end getdmask64;

    function cache_cfg5(crepl, ways, linesize, waysize, lock, snoop,
                        lram, lramsize, lramstart, mmuen : integer) return std_logic_vector is
      variable cfg : std_logic_vector(31 downto 0);
    begin
      cfg := (others => '0');
      if ways /= 1 then
        cfg(30 downto 28) := conv_std_logic_vector(crepl*2+1, 3);
      end if;
      if snoop /= 0 then cfg(27) := '1'; end if;
      cfg(26 downto 24) := conv_std_logic_vector(ways-1, 3);
      cfg(23 downto 20) := conv_std_logic_vector(log2(waysize), 4);
      cfg(18 downto 16) := conv_std_logic_vector(log2(linesize), 3);
      cfg(3  downto  3) := conv_std_logic_vector(mmuen, 1);
      return(cfg);
    end cache_cfg5;

    -- function to calculate tag msb bits to guarantee that the tags are unique
    -- regarless of the other bits of the tag.
    function uniquemsb(msbin: std_logic_vector; wways: std_logic_vector) return std_logic_vector is
      variable r: std_logic_vector(msbin'length-1 downto 0);
      variable msbused: std_logic_vector(0 to 3);
      variable nmsb: std_logic_vector(1 downto 0);
    begin
      r := (others => '0');
      if notx(msbin) and notx(wways) then
        -- Generate a vector of which 2-bit msb values will remain in use
        msbused := "0000";
        for x in 0 to msbin'length/2-1 loop
          if wways(x)='0' then
            msbused(to_integer(unsigned(msbin(2*x+1 downto 2*x)))) := '1';
          end if;
        end loop;
        -- For all ways that will be replaced, select the lowest free value from the
        -- msbused list, and update the msbused list for the next way
        for x in 0 to msbin'length/2-1 loop
          if wways(x)='1' then
            nmsb := "11";
            for y in 3 downto 0 loop
              if msbused(y)='0' then
                nmsb := std_logic_vector(to_unsigned(y,2));
              end if;
            end loop;
            r(2*x+1 downto 2*x) := nmsb;
            msbused(to_integer(unsigned(nmsb))) := '1';
          end if;
        end loop;
      else
--pragma translate_off
        for x in 0 to msbin'length/2-1 loop
          if wways(x) /= '0' then
            r(2*x+1 downto 2*x) := "XX";
          end if;
        end loop;
--pragma translate_on
        null;
      end if;
      return r;
    end uniquemsb;

    function cache_cfgnv(iways, ilinesize, iwaysize, dways, dlinesize, dwaysize,
                         itcmen, itcmabits, dtcmen, dtcmabits,
                         lock, snoop, dtagconf, icrepl, dcrepl
                         : integer) return word64 is
      -- Non-constant
      variable cfg : word64;
    begin
      cfg := (others => '0');
      cfg(63 downto 60) := u2vec(NOELV_VERSION, 4);
      --cfg(55        44) := RESERVED (used in IU)
      --cfg(          43) := RESERVED
      cfg(42 downto 38) := u2vec(dtcmabits * dtcmen, 5);
      --cfg(          37) := RESERVED
      cfg(36 downto 32) := u2vec(itcmabits * itcmen, 5);

      cfg(          31) := to_bit(lock);
      cfg(          30) := to_bit(snoop /= 0);
      cfg(29 downto 28) := u2vec(dtagconf, 2);
      if dways /= 1 then
        cfg(27 downto 26) := u2vec(dcrepl, 2);
      end if;
      if iways /= 1 then
        cfg(25 downto 24) := u2vec(icrepl, 2);
      end if;
      --cfg(          23) := RESERVED
      cfg(22 downto 20) := u2vec(dways - 1, 3);
      --cfg(          19) := RESERVED
      cfg(18 downto 15) := u2vec(log2(dwaysize), 4);
      --cfg(          14) := RESERVED
      cfg(13 downto 12) := u2vec(log2(dlinesize) - 1, 2); -- 1 = 16 byte, 2 = 32 byte, (3 = 64 byte NOT supported)
      --cfg(          11) := RESERVED
      cfg(10 downto  8) := u2vec(iways - 1, 3);
      --cfg(           7) := RESERVED
      cfg( 6 downto  3) := u2vec(log2(iwaysize), 4);
      --cfg(           2) := RESERVED
      cfg( 1 downto  0) := u2vec(log2(ilinesize) - 1, 2); -- 1 = 16 byte, 2 = 32 byte, (3 = 64 byte NOT supported)

      return cfg;
    end;
    constant cache_config : word64 :=
      cache_cfgnv(iways, ilinesize, iwaysize, dways, dlinesize, dwaysize,
                  itcmen, itcmabits, dtcmen, dtcmabits,
                  1, 1, dtagconf, 1, 1
                 );

    function has_context return boolean is
    begin
      return asidlen + vmidlen > 0;
    end;

    function is_v(mode : mode_t) return boolean is
    begin
      return is_riscv and mmuen = 1 and ext_h = 1 and mode(2) = '1';
    end;

    function is_v(mode : mode_t) return std_logic is
    begin
      return to_bit(is_v(mode));
    end;

    function is_sv39(csr : nv_csr_out_type; mode : mode_t) return boolean is
    begin
      if mmuen = 0 then
        return false;
      elsif riscv_mmu = sv39 then
        return true;                  -- Do not care if paging is turned on
      elsif riscv_mmu = sv48 then
        if is_v(mode) then
          return csr.vsatp.small;
        else
          return csr.satp.small;
        end if;
      end if;

      return false;
    end;

    function is_sv48(csr : nv_csr_out_type; mode : mode_t) return boolean is
    begin
      if mmuen = 0 then
        return false;
      elsif riscv_mmu = sv48 then
        if is_v(mode) then
          return csr.vsatp.normal;
        else
          return csr.satp.normal;
        end if;
      end if;

      return false;
    end;

    function is_sv_smaller(csr : nv_csr_out_type; mode : mode_t) return boolean is
    begin
      if riscv_mmu /= sv48 then
        return false;
      end if;

      return is_sv39(csr, mode);
    end;

    function is_sv39x4(csr : nv_csr_out_type) return boolean is
    begin
      if mmuen = 0 then
        return false;
      elsif riscv_mmu = sv39 then
        return true;                  -- Do not care if paging is turned on
      elsif riscv_mmu = sv48 then
        return csr.hgatp.small;
      end if;

      return false;
    end;

    function is_sv48x4(csr : nv_csr_out_type) return boolean is
    begin
      if mmuen = 0 then
        return false;
      elsif riscv_mmu = sv48 then
        return csr.hgatp.normal;
      end if;

      return false;
    end;

    function is_svx4_smaller(csr : nv_csr_out_type) return boolean is
    begin
      if riscv_mmu /= sv48 then
        return false;
      end if;

      return is_sv39x4(csr);
    end;

    -- Returns where extra guest physical bits start
    function gp_extra(smaller : boolean) return integer64 is
    begin
      if riscv_mmu = sv32 then
        return 32;
      elsif riscv_mmu = sv39 or smaller then
        return 39;
      else
        return 48;
      end if;
    end;

    function mmu_base(csr : nv_csr_out_type; mode : mode_t) return std_logic_vector is
      -- Non-constant
      variable base : word64 := (others => '0');
    begin
      if not is_v(mode) then
        base := uext(satp_base(csr.satp), base);
      else
        base := uext(satp_base(csr.vsatp), base);
      end if;

      return base(gpn'range);
    end;

    function hmmu_base(csr : nv_csr_out_type; gpaddr : gaddr_type) return std_logic_vector is
      -- Non-constant
      variable base     : paddr_type;
      variable base_tmp : std_logic_vector(gaisler.mmucacheconfig.pa_msb(riscv_mmu) downto 0);
      variable top      : word2;
    begin
      assert riscv_mmu = sv32 or riscv_mmu = sv39 or riscv_mmu = sv48
        report "Bad RISC-V MMU" severity failure;

      if riscv_mmu = sv32 then
        top := get(gpaddr, 32, 2);
      elsif riscv_mmu = sv39 or is_svx4_smaller(csr) then
        top := get(gpaddr, 39, 2);
      else
        top := get(gpaddr, 48, 2);
      end if;

      base_tmp := satp_base(csr.hgatp);
      base     := base_tmp(base'range);
      -- Two extra bits of address at the top, so possibly "add" n*4k to base.
--      set(base, 12, get(gpaddr, gp_extra(is_svx4_smaller(csr)), 2));
      set(base, 12, top);  -- GHDL crash work-around

      return base(ppn'range);
    end;

    function first_level_mask(smaller : boolean) return std_logic_vector is
      -- Non-constant
      variable mask : std_logic_vector(va_size_a'range) := (others => '0');
    begin
      mask(1) := '1';
      if riscv_mmu = sv48 and smaller then
        mask(2) := '1';
      end if;

      return mask;
    end;

    function next_level_mask(mask : std_logic_vector) return std_logic_vector is
    begin
      assert mask'ascending report "Bad mask" severity failure;

      return '1' & get_left(mask, -1);
    end;

    -- Returns    3          2        1        0
    -- Sv32:                       10 4M,   11 4k
    -- Sv39:             100 1G,  110 2M,  111 4k
    -- Sv48: 1000 512G, 1100 1G, 1110 2M, 1111 4k
    -- Sv39 under Sv48 uses the same encoding as Sv48, but starts one step down.
    function mask2index(mask : std_logic_vector; smaller : boolean := false) return integer4 is
    begin
      assert mask'ascending report "Bad mask" severity failure;

      if mask(mask'right) = '1' then
        return 0;                                  -- 4k
      elsif riscv_mmu = sv32 or mask(mask'right - 1) = '1' then
        return 1;                                  -- 2M (Sv32 4M)
      elsif riscv_mmu = sv39 or smaller or mask(2) = '1' then
        return 2;                                  -- 1G
      else
        return 3;                                  -- 512G
      end if;
    end;

    -- Returns    1000       x100     xx10     xx11
    -- Sv32:                       10 4M,   11 4k
    -- Sv39:             100 1G,  110 2M,  111 4k
    -- Sv48: 1000 512G, 1100 1G, 1110 2M, 1111 4k
    -- Sv39 under Sv48 uses the same encoding as Sv48, but starts one step down.
    function mask2word4(mask_in : std_logic_vector; smaller : boolean := false) return word4 is
      -- Non-constant
      variable mask : word4 := (others => '1');
    begin
      assert mask_in'ascending report "Bad mask" severity failure;
      mask(mask_in'length - 1 downto 0) := mask_in;

      return mask;
    end;

    function mask2word4masked(mask_in : std_logic_vector; smaller : boolean := false) return word4 is
      -- Non-constant
      variable mask : word4 := mask2word4(mask_in, smaller);
    begin
      -- Mask out unused high bits
      if riscv_mmu = sv32 then
        mask := mask and "0011";
      elsif riscv_mmu = sv39 or smaller then
        mask := mask and "0111";
      end if;

      return mask;
    end;

    function pt_end_reached(mask : std_logic_vector; smaller : boolean) return boolean is
    begin
      return mask(mask'right) = '1';
    end;

    -- Returns address of page table entry.
    -- Returned address is 64 bit long and must be cut down to size by caller.
    -- smaller - Use Sv39 when Sv48 is supported
    function pt_addr(data  : std_logic_vector; mask : std_logic_vector;
                     vaddr : std_logic_vector; smaller : boolean) return word64 is
      variable va_step : integer            := va_size(1);  -- On RISC-V, va_size(n) is the same for all n.
      variable vpn     : word16_arr(0 to 3) := vpn_split(vaddr);
      variable sel     : integer4           := mask2index(mask, smaller);
      -- Non-constant
      variable addr    : word64             := (others => '0');
    begin
      assert riscv_mmu = sv32 or riscv_mmu = sv39 or riscv_mmu = sv48
        report "Bad RISC-V MMU" severity failure;

      report "pt_addr " & tost(data) & " " & tost_bits(mask) & "/" & tost(sel) & " " & tost(vaddr) & " " & tost(vpn(sel)) & " " & tost(smaller);
      -- Every page table is the size of one page (thus downto 12).
      -- Bottom 10 bits of data are the information bits.
      if riscv_mmu = sv32 then
        -- 32 bit entries, so "00" at the end.
        addr := fit0ext(data(31 downto 10) & get_lo(vpn(sel), va_step) & "00", addr);
      else
        -- 64 bit entries, so "000" at the end.
        addr := fit0ext(data(XLEN - 1 - (1 + 2 + 7) downto 10) & get_lo(vpn(sel), va_step) & "000", addr);
      end if;

      return addr;
    end;

    function pt_addr_base(data  : std_logic_vector; vaddr : std_logic_vector; smaller : boolean) return word64 is
      variable mask : std_logic_vector(va_size_a'range) := (others => '0');
    begin
      return pt_addr(data, mask, vaddr, smaller);
    end;

    -- Create a mask for bits to keep from a PT address,
    -- depending on the mask/code (see above).
    -- 0 - all mappable address bits
    -- 1 - no mask for lowest group of mappable address bits
    -- 2 - no mask for two lowest groups of mappable address bits
    -- 3 - no mask for three lowest groups of mappable address bits
    function pt_mask(mask_in : std_logic_vector; smaller : boolean) return addr_type is
      variable va_step : integer := va_size(1);  -- On RISC-V, va_size(n) is the same for all n.
      variable mask    : word4   := mask2word4(mask_in, smaller);
      -- Non-constant
      variable addr    : word64  := (others => '1');
      variable pos     : integer64;
    begin
      addr(11 downto 0) := (others => '0');
      -- Add up page mask sizes from the bottom.
      -- Any 0:s will be in a row from the right.
      pos := 12;
      for i in mask'right to mask'left loop
        if mask(i) = '0' then
          addr(pos + va_step - 1 downto pos) := (others => '0');
        end if;
        pos := pos + va_step;
      end loop;

      return addr(addr_type'range);
    end;

    function top_gpa_zeros(addr_in : std_logic_vector; smaller : boolean) return boolean is
      variable addr : std_logic_vector(addr_in'length - 1 downto 0) := addr_in;
      -- Non-constant
      variable ok   : boolean := all_0(addr(addr'high downto ga_msb + 1));
    begin
      if gaisler.mmucacheconfig.supports_impl_mmu_sv48(riscv_mmu) and smaller and
         not all_0(addr(ga_msb downto gaisler.mmucacheconfig.ga_msb(sv39) + 1)) then
        ok := false;
      end if;

      return ok;
    end;

    function tlbent_mask(entry_in : tlbent; smaller : boolean) return tlbent is
      -- Non-constant
      variable mask  : gvaddr_type := (others => '1');
      variable entry : tlbent := entry_in;
    begin
      -- mask(gpa'range) := pt_mask(entry.mask, smaller);
      mask(gpa'range) := get_right(pt_mask(entry.mask, smaller), gpa'length);
      entry.vaddr     := entry.vaddr and mask(entry.vaddr'range);
      entry.paddr     := entry.paddr and mask(entry.paddr'range);


      return entry;
    end;


    --  impure
    function permitted(x        : std_logic;     -- 1 - execute access
                       su       : std_logic;     -- 1 - S access
                       w        : std_logic;     -- 1 - write access
                       perm     : word5;         -- SUXWR
                       pmp_r    : std_logic;     -- PMP allows R
                       h_r      : std_logic;     -- Hypervisor allows R
                       pmp_no_x : std_logic;     -- PMP blocks X
                       sum      : std_logic;     -- S access as if U
                       mxr      : std_logic;     -- Allow R if X
                       vmxr     : std_logic;     -- V allow R if X
                       hx       : std_logic      -- Allow R _only_ if X
                       ; ss     : std_logic := '0';  -- Shadow stack access
                       ss_010en : std_logic := '0'   -- Shadow stack XWR=010 enabled
                      ) return boolean is
      -- Non-constant
      variable data : word32  := (others => '0');
      variable acc  : word3;
      variable ok   : boolean := false;
    begin
      data(rv_pte_u + 1 downto rv_pte_r) := perm;
      -- Check for W but not R moved from is_valid_pte() due to Zicfiss.
      if data(rv_pte_w downto rv_pte_r) = "10" then
        -- Special handling of XWR = 010
        -- Note that normal permission masking due to hPT or PMP will
        -- ensure that WR=10 can not happen if read is disallowed
        -- (since that also guarantees that W is also not allowed).
        if ext_zicfiss = 1 and data(rv_pte_x) = '0' and ss_010en = '1' then
          -- Specifically check shadow stack accesses
          if ss = '1' then
            return (su = '0' and data(rv_pte_u) = '1') or
                   (su = '1' and (data(rv_pte_u + 1) = '1' or sum = '1'));
          end if;
          -- Shadow stack marking allows any read
          data(rv_pte_x downto rv_pte_r) := "001";
        else
          return false;
        end if;
      -- Shadow stack access otherwise not allowed
      elsif ext_zicfiss = 1 and ss = '1' then
        return false;
      end if;
      acc  := rv_ft_acc_resolve("" & w & x & su, data);
      if sum = '0' then
        ok := acc(1) = '0';   -- acc(1) is normal check.
      else
        ok := acc(0) = '0';   -- acc(0) is check assuming SUM.
      end if;
      -- Special case when MXR read.
      -- acc(2) is checked for read access and X or R allowed.
      -- Check here for correct mode (including SUM bit and supervisor (passed in)).
      -- [V]MXR does not affect shadow stack accesses.
      if (mxr = '1' or (ext_h = 1 and (vmxr = '1' and h_r = '1'))) and
         pmp_r = '1' and
         ((su = '0' and data(rv_pte_u) = '1') or
          (su = '1' and (data(rv_pte_u + 1) = '1' or sum = '1'))) then
        -- ok := ok or (acc(2) = '0');
        ok := ok or (x = '0' and w = '0' and (data(rv_pte_x) = '1' or pmp_no_x = '1'));
      end if;
      -- HX is mostly the same as for MXR, but X is required.
      -- Also RX for PMP, but that does not need explicit handling here.
      if ext_h = 1 and hx = '1' then
        ok := pmp_r = '1' and data(rv_pte_x) = '1' and
              ((su = '0' and data(rv_pte_u) = '1') or
               (su = '1' and (data(rv_pte_u + 1) = '1' or sum = '1')));
      end if;

      return ok;
    end;

    -- Used to also provide writeability information for the
    -- RISC-V hypervisor page table read case - write-back possible?
    -- Assumes proper check is already done for the read case!
    function h_also_writeable(perm : word5) return boolean is
      -- Non-constant
      variable data : word32  := (others => '0');
      variable acc  : word3;
      variable ok   : boolean := false;
    begin
      if is_riscv then
        -- Hypervisor page table makes no difference between U and S.
        data(rv_pte_u + 1 downto rv_pte_r) := "11" & perm(2 downto 0);
        acc  := rv_ft_acc_resolve("100", data);   -- W ~X ~S
        ok   := acc(1) = '0';   -- acc(1) is normal check.
      else
        ok := false;
      end if;

      return ok;
    end;

    -- Physical addresses should have zeroes at the top.
    function physical_ok(addr : std_logic_vector) return boolean is
    begin
      -- Addresses are always OK for RV32!
      if riscv_mmu = sv32 then
        return true;
      end if;

      return u2i(addr(addr'high downto physbits)) = 0;
    end;

    -- Guest physical addresses should have zeroes at the top.
    function gphysical_ok(addr : std_logic_vector; smaller : boolean) return boolean is
    begin
      assert riscv_mmu = sv32 or riscv_mmu = sv39 or riscv_mmu = sv48
        report "Bad RISC-V MMU" severity failure;

      -- Addresses are always OK for RV32!
      if riscv_mmu = sv32 then
        return true;
      end if;

      if riscv_mmu = sv39 or (riscv_mmu = sv48 and not smaller) then
        return u2i(addr(addr'high downto ga_msb + 1)) = 0;
      else
        -- This is Sv39x4 under Sv48x4
        return u2i(addr(addr'high downto gaisler.mmucacheconfig.ga_msb(sv39) + 1)) = 0;
      end if;
    end;

    -- Virtual addresses must be sign extended.
    function virtual_ok(addr : std_logic_vector; smaller : boolean) return boolean is
    begin
      assert riscv_mmu = sv32 or riscv_mmu = sv39 or riscv_mmu = sv48
        report "Bad RISC-V MMU" severity failure;

      -- Addresses are always OK for RV32!
      if riscv_mmu = sv32 then
        return true;
      end if;

      if riscv_mmu = sv39 or (riscv_mmu = sv48 and not smaller) then
        return u2i(    addr(addr'high downto va'high)) = 0 or
               u2i(not addr(addr'high downto va'high)) = 0;
      else
        -- This is Sv39 under Sv48
        return u2i(    addr(addr'high downto gaisler.mmucacheconfig.va_msb(sv39))) = 0 or
               u2i(not addr(addr'high downto gaisler.mmucacheconfig.va_msb(sv39))) = 0;
      end if;
    end;

    function get_mode(csr : nv_csr_out_type; vms : word3) return mode_t is
      -- Non-constant
      variable mode : mode_t := (others => '0');
    begin
      if vms(2) = '0' then
        -- Machine mode always has zeroed mode,
        -- supervisor and user mode only when non-bare SATP.
        if vms(1 downto 0) /= PRIV_LVL_M then
          mode(0) := to_bit(has_pt(csr.satp));
        end if;
      elsif mmuen /= 0 and ext_h = 1 and vms(2) = '1' then
        mode(2) := '1';
        mode(1) := to_bit(has_pt(csr.hgatp));
        mode(0) := to_bit(has_pt(csr.vsatp));
      end if;

      return mode;
    end;

    -- False for mode that only keeps PMP/PMA in TLB
    function is_mapping(mode : mode_t) return boolean is
    begin
      return mode(1 downto 0) /= "00";
    end;

    function has_hgatp(mode : mode_t) return boolean is
    begin
      return is_riscv and mmuen = 1 and ext_h = 1 and mode(1) = '1';
    end;

    function has_xsatp(mode : mode_t) return boolean is
    begin
      return is_riscv and mmuen = 1 and mode(0) = '1';
    end;

    -- Return current context, cut down to appropriate size.
    function mmu_ctx(csr  : nv_csr_out_type;
                     mode : mode_t := (others => '1')) return std_logic_vector is
      variable s_asid  : word16 := csr.satp.id;
      variable vs_asid : word16 := csr.vsatp.id;
      variable vmid    : word16 := csr.hgatp.id;
      -- Non-constant
      variable ctx : ctxword := (others => '0');
    begin
      if riscv_mmu = Sv32 then
        -- pragma translate_off
        assert vmidlen <= 7 and asidlen <= 9 report "Bad VM/ASIDLEN" severity failure;
        -- pragma translate_on
      end if;
      if has_context then
        if not is_v(mode) then
          ctx := zerov(vmidlen - 1 downto 0) & s_asid(asidlen - 1 downto 0);
        else
          ctx := vmid(vmidlen - 1 downto 0) & vs_asid(asidlen - 1 downto 0);
        end if;
      end if;

      return ctx;
    end;

    -- This will never be called for Sparc!
    function hmmu_enabled(csr : nv_csr_out_type; v : std_ulogic) return boolean is
    begin
      if not is_riscv or ext_h = 0 or mmuen = 0 then
        return false;
      end if;

      return v = '1' and has_pt(csr.hgatp);
    end;

    -- This will never be called for Sparc!
    function hmmu_enabled(mode : mode_t) return boolean is
    begin
      return is_v(mode) and has_hgatp(mode);
    end;

    -- This will never be called for Sparc!
    function hmmu_only(mode : mode_t) return boolean is
    begin
      return hmmu_enabled(mode) and not has_xsatp(mode);
    end;

    -- This will never be called for Sparc!
    function mmu_enabled(mode : mode_t) return boolean is
    begin
      if not is_v(mode) then
        return has_xsatp(mode);
      else
        return has_xsatp(mode) or hmmu_enabled(mode);
      end if;
    end;

    -- This returns '1' if D$ is enabled/frozen!
    function dcache_active(cctrl : cctrltype5) return std_logic is
    begin
      if is_riscv then
        return cctrl.dcs(0);
      else
        return cctrl.dcs(0);
      end if;
    end;

    function is_access_i(mmusel : mmusel_type) return boolean is
    begin
      return mmusel(0) = '0';
    end;

    function is_access_asi_walk(mmusel : mmusel_type) return boolean is
    begin
      return not is_riscv and mmusel(2) = '1';
    end;

    function is_access_r(mmusel : mmusel_type) return boolean is
    begin
      return mmusel(2 downto 0) = "001";
    end;

    function is_access_w(mmusel : mmusel_type) return boolean is
    begin
      return mmusel(1) = '1';
    end;

    function is_access_hpt(mmusel : mmusel_type) return boolean is
    begin
      return mmusel(3) = '1';
    end;

    -- This will simply return the PnP cacheability information
    -- from PnP for the base address of the given PTE entry.
    function pte_cached(ahbso : ahb_slv_out_vector; data : std_logic_vector) return std_logic is
      -- Non-constant
      variable paddr     : paddr_type := (others => '0');
      variable ahbo_t    : ahb_mst_out_type;
      variable tmp_paddr : word64;
    begin
      tmp_paddr        := uext(pte_paddr(data), 64);
      paddr(ppn'range) := tmp_paddr(ppn'length - 1 downto 0);

      return ahb_slv_dec_cache(paddr(ahbo_t.haddr'range), ahbso, cached);
    end;

    -- Update existing PMA information according to PBMT
    -- Note that if the system normally separates memory ordering between
    -- main memory and I/O, changing the type via PBMT actually means that
    -- _both_ orderings must be observed for FENCE, .aq and .rl.
    function pbmt_pma_update(pbmt : word2; pma : pma_t) return pma_t is
    begin
      if ext_svpbmt = 0 then
        return pma;
      end if;

      case pbmt is
      when "00"   =>          -- PMA - no change
        return pma;
      when "01"   =>          -- NC  - Non-cacheable, idempotent, weakly-ordered, main memory
        return pma_pbmt_nc(pma);
      when others =>          -- IO  - Non-cacheable, non-idempotent, strongly-ordered, I/O
        return pma_pbmt_io(pma);
      end case;
    end;

    -- Not for use when PMA is enabled!
    function pte_busw(data : std_logic_vector) return std_logic is
      -- Non-constant
      variable paddr     : paddr_type := (others => '0');
      variable ahbo_t    : ahb_mst_out_type;
      variable tmp_paddr : word64;
    begin
      tmp_paddr := uext(pte_paddr(data), 64);
      paddr(ppn'range) := tmp_paddr(ppn'length - 1 downto 0);

      return dec_wbmask_fixed(paddr(ahbo_t.haddr'high downto 2), wbmask);
    end;

    -- Check for forced area faults from CSR
    function pma_forced_fault(csr : nv_csr_out_type; addr : std_logic_vector) return boolean is
    begin
      if pma_gr765 then
        -- 0 - 2G and disallowed?
        if csr.pma_fault_02 = '1' and
           all_0(addr(addr'high downto 32)) and addr(31) = '0' then
          return true;
        end if;
        -- 4 - 2G and disallowed?
        if csr.pma_fault_46 = '1' and
           all_0(addr(addr'high downto 33)) and addr(32 downto 31) = "10" then
          return true;
        end if;
      end if;

      return false;
    end;

    procedure tlb_lookup(x          : word2;             -- x1 - ITLB, 1x - hTLB
                         tlb        : tlbentarr;
                         addr_ok    : boolean;           -- Top address bits OK
                         vaddr_repl : std_logic_vector;  -- Copies of virtual address
                         vaddr_in   : std_logic_vector;  -- Virtual address
                         ctx_repl   : std_logic_vector;  -- ASID (+VMID)
                         su         : std_logic;         -- 1 - S access
                         w          : std_logic;         -- 1 - write access
                         check      : std_logic;         -- Do check (only used for debug output)
                         specialasi : std_logic;         -- No entry clear on permission failure
                         nullify    : std_logic;         -- No entry clear on permission failure
                         repeat     : std_logic;         -- No entry clear on permission failure
                         tlbchk     : out tlbcheck;
                         sum        : std_logic;         -- S access as if U
                         mxr        : std_logic;         -- Allow R if X
                         vmxr       : std_logic;         -- V allow R if X
                         hx         : std_logic;         -- Allow R _only_ if X
                         mode       : mode_t;            -- Current V and *APT setup
                         smaller    : boolean;           -- Sv39 when Sv48 is supported
                         ss         : std_logic := '0';  -- Shadow stack access
                         ss_010en   : std_logic := '0';  -- Shadow stack XWR=010 enabled
                         display    : boolean   := false -- Enable debug output
                         ) is
      -- Non-constant
      variable vaddr     : gvaddr_type;
      variable ctx       : ctxword;
      --variable paddr     : gpaddr_type;
      variable paddr     : std_logic_vector(tlbabits-1 downto 0);
      variable mask      : std_logic_vector(tlb(0).mask'range) := (others => '0');
      variable vbusw     : std_logic                           := '0';
      variable match     : boolean;
      variable pos       : integer;
      variable tmpchk    : tlbcheck                            := tlbcheck_none;
      variable index     : integer                             := -1;
      variable ctx_match : boolean                             := true;
      variable vaddr_vpn : word16_arr(0 to 3);
      variable tlb_vpn   : word16_arr(0 to 3);
      variable tlb_mask  : word4;
    begin

      for n in tlb'range loop
        vaddr := vaddr_repl((n mod tlbrepl) * vaddrbits + tlbabits - 1 downto (n mod tlbrepl) * vaddrbits);
        ctx   := get(ctx_repl, (n mod tlbrepl) * ctxbits, ctxbits);
        match := true;
        pos   := 12;
        vaddr_vpn := vpn_split(vaddr);
        tlb_vpn   := vpn_split(tlb(n).vaddr);
        -- Deal with Svnapot by copying low bits from vaddr to low virtual tlb part.
        if ext_svnapot = 1 and tlb(n).svnapot = '1' then
          set_lo(tlb_vpn(0), get_lo(vaddr_vpn(0), 4));
        end if;
        tlb_mask  := mask2word4masked(tlb(n).mask, smaller);
        for i in tlb_mask'low to tlb_mask'high loop
          match := match and (tlb_mask(i) = '0' or tlb_vpn(i) = vaddr_vpn(i));
        end loop;
        -- Check extra top two bits when guest physical address,
        -- ie when hPT lookup or guest physical address from IU (V and hPT and not vsPT).
        if x(1) = '1' or (is_v(mode) and has_hgatp(mode) and not has_xsatp(mode)) then
          if riscv_mmu = sv32 then
            match := match and get(tlb(n).vaddr, 32, 2) = get(vaddr, 32, 2);
          elsif riscv_mmu = sv39 or smaller then
            match := match and get(tlb(n).vaddr, 39, 2) = get(vaddr, 39, 2);
          else
            match := match and get(tlb(n).vaddr, 48, 2) = get(vaddr, 48, 2);
          end if;
        end if;

        -- Check context if not only fetching PMP/PMA.
        if has_context and (not walk_pmp or is_mapping(mode)) then
          -- Global entries only need to match on VMID
          if enable_g = 0 or tlb(n).global = '0' then
            ctx_match := tlb(n).ctx = ctx;
          else
            ctx_match := tlb(n).ctx(tlb(0).ctx'high downto asidlen) = ctx(tlb(0).ctx'high downto asidlen);
          end if;
        else
          ctx_match := true;
        end if;
        -- HGATP - guest to physical translation
        if x(1) = '1' then
          if has_context then
            ctx_match := tlb(n).ctx(tlb(0).ctx'high downto asidlen) = ctx(tlb(0).ctx'high downto asidlen);
          end if;
        elsif mode'length /= 0 then
          if tlb(n).mode /= mode then
            ctx_match := false;
          end if;
        end if;

        if tlb(n).valid = '1' and ctx_match and match then
         -- There is no point in making OR:ed data depend on whether the top bits were OK.
         if addr_ok then
          if (walk_pmp and not is_mapping(mode)) or     -- If only fetching PMP/PMA information,
             permitted(x(0), su, w, tlb(n).perm,        --   or PT permissions OK.
                       tlb(n).pmp_r, tlb(n).h_r, tlb(n).pmp_no_x,
                       sum, mxr, vmxr, hx,
                       ss, ss_010en
                      ) then
            tmpchk.hit     := '1';
            tmpchk.hitv(n) := '1';  -- unused (had better only get one bit set, anyway!)
            if ext_h = 1 then
              tmpchk.h_w   := to_bit(h_also_writeable(tlb(n).perm));
            end if;
          else
            -- Invalidate matching TLB entry on permission fail since there will be a
            -- new MMU walk, and it would be a bad idea to have two instances in the TLB!
            -- Will not invalidate on repeat due to stall, since walk already done.
            if check = '1' and specialasi = '0' and nullify = '0' and repeat = '0' then
              tmpchk.clr := '1';
            end if;
          end if;
         end if;
          index := (n);
          -- Note that 'or' can be used since only one TLB entry may really hit,
          -- and it avoids prioritizing so less logic.
          tmpchk.amatch  := '1';
          --set(tmpchk.paddr, 12, get(tmpchk.paddr, 12, gpn) or tlb(n).paddr);
          --set(tmpchk.paddr, 12, get(tmpchk.paddr, 12, gpn) or tlb(n).paddr(gpn'range));
          tmpchk.paddr(tmpchk.paddr'high downto 12) := tmpchk.paddr(tmpchk.paddr'high downto 12) or tlb(n).paddr;
          tmpchk.id      := tmpchk.id      or u2vec(n, tmpchk.id);
          tmpchk.busw    := tmpchk.busw    or tlb(n).busw;
          tmpchk.cached  := tmpchk.cached  or tlb(n).cached;
          tmpchk.modded  := tmpchk.modded  or tlb(n).modified;
          mask           := (others => '0');
          mask           := mask           or tlb(n).mask;
          paddr          := (others => '0');
          virtual2physical(vaddr, mask, paddr);
          tmpchk.paddr    := tmpchk.paddr  or paddr;
          if actual_tlb_pmp then
            tmpchk.h_pmp_r    := tmpchk.h_pmp_r    or tlb(n).pmp_r;
            tmpchk.h_pmp_no_w := tmpchk.h_pmp_no_w or tlb(n).pmp_no_w;
            tmpchk.h_pmp_no_x := tmpchk.h_pmp_no_x or tlb(n).pmp_no_x;
          else
            -- Permit if no PMP in TLB
            tmpchk.h_pmp_r    := '1';
            tmpchk.h_pmp_no_w := '0';
            tmpchk.h_pmp_no_x := '0';
          end if;
          if ext_h = 1 then
            tmpchk.h_perm     := tmpchk.h_perm     or tlb(n).perm(tmpchk.h_perm'range);
            tmpchk.h_mask     := tmpchk.h_mask     or tlb(n).mask;
          end if;
          if walk_pmp then
            tmpchk.pmp_none   := tmpchk.pmp_none   or tlb(n).pmp_none;
            tmpchk.pmp_lock   := tmpchk.pmp_lock   or tlb(n).pmp_lock;
            tmpchk.pmp_rwx    := tmpchk.pmp_rwx    or tlb(n).pmp_rwx;
          end if;
          if ext_svpbmt = 1 then
            tmpchk.pbmt       := tmpchk.pbmt       or tlb(n).pbmt;
          end if;
          if ext_svnapot = 1 then
            tmpchk.svnapot    := tmpchk.svnapot    or tlb(n).svnapot;
          end if;
          if pmaen then
            tmpchk.pma        := to_pma(from_pma(tmpchk.pma) or from_pma(tlb(n).pma));
          end if;

        end if;
      end loop;

      -- Ensure proper PMP return if there is no PMP/PMA.
      if not pmpen and not pmaen then
        tmpchk.h_pmp_r    := '1';
        tmpchk.h_pmp_no_w := '0';
        tmpchk.h_pmp_no_x := '0';
      end if;
      -- Ensure proper PMA return if there is no PMA.
      if not pmaen then
        tmpchk.pma        := pma_all;
      end if;

      tmpchk.paddr(11 downto 0) := tmpchk.paddr(11 downto 0) or vaddr_in(11 downto 0);
      -- Deal with Svnapot by copying low bits from vaddr to low virtual tlb part.
      if ext_svnapot = 1 and tmpchk.svnapot = '1' then
        set(tmpchk.paddr, 12, get_lo(vaddr_vpn(0), 4));
      end if;

      if display and check = '1' then
        if tmpchk.hit = '0'then
        else
        end if;
      end if;

      tlbchk := tmpchk;
    end;

    function flushmatch(h : boolean; vs : boolean;
                        e : tlbent; vaddr : std_logic_vector; data : std_logic_vector;
                        smaller : boolean) return boolean is
      variable match    : boolean := true;
      variable x0s       : word4   := get_hi(data, 4);
      variable x0_addr   : boolean := x0s(3) = '1';
      variable x0_asid   : boolean := x0s(2) = '1';
      variable x0_vmid   : boolean := x0s(1) = '1';
      variable x0_haddr  : boolean := x0s(0) = '1';
      variable vaddr_vpn : word16_arr(0 to 3) := vpn_split(vaddr);
      -- Non-constant
      variable asid_ok   : boolean := true;
      variable vmid_ok   : boolean := true;
      variable tlb_vpn   : word16_arr(0 to 3) := vpn_split(e.vaddr);
      variable tlb_mask  : word4;
    begin
      if is_riscv then
        -- Deal with Svnapot by copying low bits from vaddr to low virtual tlb part.
        if ext_svnapot = 1 and e.svnapot = '1' then
          set_lo(tlb_vpn(0), get_lo(vaddr_vpn(0), 4));
        end if;
        tlb_mask := mask2word4masked(e.mask, smaller);
        for i in tlb_mask'low to tlb_mask'high loop
          match := match and (tlb_mask(i) = '0' or tlb_vpn(i) = vaddr_vpn(i));
        end loop;
        if has_context then
          if asidlen /= 0 then
            asid_ok := e.ctx(asidlen - 1 downto 0) = data(asidlen - 1 downto 0);
          end if;
          if vmidlen /= 0 then
            vmid_ok := e.ctx(e.ctx'high downto asidlen) = data(e.ctx'high downto asidlen);
          end if;
        end if;
        if h then
          match   := match or x0_haddr;
        else
          match   := match or x0_addr;
          if vs then
            match := match and is_v(e.mode);
          else
            match := match and not is_v(e.mode);
          end if;
        end if;
        if not x0_vmid then
          match := match and vmid_ok;
        end if;
        -- When checking a specific ASID, do not match for flush on global entries!
        if not x0_asid then
          match := match and asid_ok and (enable_g = 0 or e.global = '0');
        end if;
        match := match and e.valid = '1';
      end if;

      return match;
    end;
    -- -------------------------------------------------------------------------
    --
    -- -------------------------------------------------------------------------

    variable v: cctrl5nv_regs;
    variable vs: cctrl5_snoop_regs;
    variable oico: nv_icache_out_type;
    variable odco: nv_dcache_out_type;
    variable ocrami: cram_in_type5;
    variable obifi: busif_in_type5;
    variable ihit, ivalid, ibufaddrmatch, idblhit: std_ulogic;
    variable ihitv, ivalidv: std_logic_vector(0 to IWAYS-1);
    variable itcmhit: std_ulogic;
    variable iway: std_logic_vector(1 downto 0);
    variable icont: std_ulogic;
    variable ipc: std_logic_vector(31 downto 0);
    variable itlbhit: std_ulogic;
    variable itlbclr: std_ulogic;
    --variable ientpaddr: std_logic_vector(35 downto 0);
    variable ientpaddr: std_logic_vector(tlbabits-1 downto 0);
    variable itlbamatch: std_ulogic;
    --variable itlbpaddr: std_logic_vector(35 downto 0);
    variable itlbpaddr: std_logic_vector(tlbabits-1 downto 0);
    variable itlbperm: std_logic_vector(3 downto 0);
    variable itlbid: std_logic_vector(log2x(itlbnum)-1 downto 0);
    variable itlbbusw,itlbcached,ivbusw: std_ulogic;
    variable ientbusw,ientcached: std_ulogic;
    variable ilruent: lruent;
    variable itcmact: std_ulogic;
    variable dctagsv: cram_tags;
    variable dhitv, dvalidv: std_logic_vector(0 to DWAYS-1);
    variable dhit, dvalid, ddblhit: std_ulogic;
    variable dtcmhit: std_ulogic;
    variable dway: std_logic_vector(1 downto 0);
    variable dlock: std_ulogic;
    variable dspecialasi, dforcemiss: std_ulogic;
    variable dvaddr: std_logic_vector(31 downto 0);
    variable dtlbhit: std_ulogic;
    variable dtlbclr: std_ulogic;
    --variable dentpaddr: std_logic_vector(35 downto 0);
    variable dentpaddr: std_logic_vector(tlbabits-1 downto 0);
    variable dentbusw: std_ulogic;
    variable dentcached: std_ulogic;
    variable dtlbamatch: std_ulogic;
    variable dtlbpaddr: std_logic_vector(tlbabits-1 downto 0);
    variable dtlbperm: std_logic_vector(3 downto 0);
    variable dtlbid: std_logic_vector(log2x(dtlbnum)-1 downto 0);
    variable dtlbbusw, dvbusw, dtlbcached, dtlbmod: std_logic;
    variable dtlb_write, dtlb_lock: std_ulogic;
    variable dtlbpaddr_chk: std_logic_vector(dphysbits-1 downto 0);
    variable dtlbhit_chk: std_ulogic;
    variable ss_chk: std_ulogic;
    variable m_chk: std_ulogic;
    variable hx_chk: std_ulogic;
    variable su_chk: std_ulogic;
    variable dtenall: std_ulogic;
    variable dlruent: lruent;
    variable dtcmact: std_ulogic;
    variable vdciwm: std_ulogic;
    variable fastwr: std_ulogic;
    variable fastwr_wcomb: std_ulogic;
    variable wrcomb_valid, wrcomb_nvalid: std_logic_vector(0 to 3);
    variable vstoresu: std_ulogic;
    variable vdiagasi: std_logic_vector(2 downto 0);
    variable vwide: std_ulogic;
    variable d64: std_logic_vector(63 downto 0);
    variable dwriting: std_ulogic;
    variable d32: std_logic_vector(31 downto 0);
    variable dm8: std_logic_vector(7 downto 0);
    variable rdb64     : word64;
    alias    rdb32    is rdb64(31 downto 0);
    variable rdb64v    : std_ulogic;
    --variable rdb32: std_logic_vector(31 downto 0);
    variable rdb32v: std_ulogic;
    variable vneedwb: std_ulogic;
    variable vneedwblock: std_ulogic;
    variable vway: unsigned(1 downto 0);
    variable vhit: std_ulogic;
    variable vtmp2: std_logic_vector(1 downto 0);
    variable vtmp3: std_logic_vector(2 downto 0);
    variable vwdata128: std_logic_vector(127 downto 0);
    variable vwdata64: std_logic_vector(63 downto 0);
    variable vwdata: std_logic_vector(cdataw-1 downto 0);
    variable vwad: std_logic_vector(4 downto 3);
    variable vtmp4i: std_logic_vector(0 to 3);
    variable voffs: std_logic_vector(DOFFSET_HIGH downto DOFFSET_LOW);
    variable vfoffs: std_logic_vector(MAXOFFSET_HIGH downto MAXOFFSET_LOW);
    variable vrflag: std_ulogic;
    variable vstd64: word64;
    alias    vstd32 is vstd64(31 downto 0);
    variable vtoglock: std_ulogic;
    variable vregwdata0: std_logic_vector(31 downto 0);
    variable vregwdata1: std_logic_vector(31 downto 0);
    variable vregw0, vregw1, vregwmmu: std_ulogic;
    variable vwidereg: std_ulogic;
    variable vwideregwdata: std_logic_vector(63 downto 0);
    variable vwideregwh, vwideregwl: std_ulogic;
    variable vwideregrdata: std_logic_vector(63 downto 0);
    variable vregrdata0: std_logic_vector(31 downto 0);
    variable vregrdata1: std_logic_vector(31 downto 0);
    variable vbadreg0, vbadreg1, vbadreg: std_ulogic;
    variable vregaddr64: std_logic_vector(7 downto 3);
    variable vregaddrmmu: std_logic_vector(10 downto 8);

    variable frdmatch: std_logic_vector(0 to DWAYS-1);
    variable frimatch: std_logic_vector(0 to IWAYS-1);
    variable frmsbd: std_logic_vector(2*DWAYS-1 downto 0);
    variable frmsbi: std_logic_vector(2*IWAYS-1 downto 0);
    variable vbubble0: std_ulogic;
    variable vstall: std_ulogic;

    variable vvalididx: std_logic_vector(DOFFSET_HIGH-DOFFSET_LOW downto 0);
    variable vcashit: std_ulogic;
    variable vbitset: vbitarr(0 to 2**DOFFSET_BITS-1);
    variable vbitclr: vbitarr(0 to 2**DOFFSET_BITS-1);
    variable vmaskwtrap: std_logic_vector(1 downto 0);

    variable vdlyop : std_ulogic;

    variable itlbchk : tlbcheck;
    variable dtlbchk : tlbcheck;
    variable htlbchk : tlbcheck;
    -- PMP
    variable pmp       : pmp_t;
    variable pmp_xc    : std_ulogic;
    variable pmp_mmu   : std_ulogic;
    variable pmp_hit   : std_logic_vector(pmp_entries - 1 downto 0);
    -- These are only used when actual_tlb_pmp
    variable pmp_prio  : std_logic_vector(pmp_entries - 1 downto 0);
    variable pmp_fit   : std_logic_vector(pmp_entries - 1 downto 0);
    variable pmp_l     : std_logic_vector(pmp_entries - 1 downto 0);
    variable pmp_r     : std_logic_vector(pmp_entries - 1 downto 0);
    variable pmp_w     : std_logic_vector(pmp_entries - 1 downto 0);
    variable pmp_x     : std_logic_vector(pmp_entries - 1 downto 0);
    variable pmp_rwx   : word3;
    -- PMA
    variable pma_hit   : std_logic_vector(PMAENTRIES - 1 downto 0);
    variable pma_prio  : std_logic_vector(PMAENTRIES - 1 downto 0);
    variable pma_fit   : std_logic_vector(PMAENTRIES - 1 downto 0);
    variable pma_idx   : std_logic_vector(r.pma_idx'range);
    variable pma       : pma_t;

    variable start_walk  : boolean;
    variable start_hwalk : boolean;
    variable start_pmp   : boolean;
    variable mmu_data  : word64;         -- To fake MMU page table data from mmu_base.

    variable iaddr_ok  : boolean;
    variable daddr_ok  : boolean;

    variable guest_top_ok : boolean;
    variable phys_top_ok  : boolean;

    --variable i_mexc    : std_ulogic;     -- Instruction memory exception
    --variable i_exctype : std_ulogic;     --  0 - page fault, 1 - access fault (PMP/bus)
    --variable d_mexc    : std_ulogic;     -- Data memory exception
    --variable d_exctype : std_ulogic;     --  0 - page fault, 1 - access fault (PMP/bus)

    -- Atomic operations
    variable dci_atomic: std_ulogic;
    variable amo_op    : word4;
    variable amo_src1  : word64;
    variable amo_src2  : word64;
    variable amo_data  : word64;
    variable amo_snoop : std_logic;

    variable haddr     : word64;
    variable tmpaddr   : word64;

    variable fault        : boolean;
    variable fault_access : boolean;
    variable fault_hyper  : boolean;

    variable part_mask    : gpaddr_type;
    variable part         : gpaddr_type;

    variable done         : boolean;
    variable ok           : boolean;
    variable store_done   : boolean;
    variable do_pte1_hchk : boolean;

    variable entry        : tlbent;

    variable rdbuf_data   : word64;

    -- Used to avoid comparisons on v.s
    variable do_access    : boolean;
    variable do_mmu_lock  : boolean;
    variable do_icfetch   : boolean;
    variable do_wrasi2    : boolean;
    variable do_rdcdiag   : boolean;
    --

    -- To avoid doing awkward things with the r signal on RISC-V
    variable r_cctrl      : cctrltype5;
    variable r_ft         : ftctrltype5;
    variable r_ei         : eictrltype5;

    function get_ccr(r: cctrl5nv_regs; rs: cctrl5_snoop_regs) return std_logic_vector is
      variable ccr: std_logic_vector(31 downto 0);
    begin
     if arch = SPARC then
      ccr := (others => '0');
      ccr(23) := r.cctrl.dsnoop;
      ccr(17) := '1';
      ccr(15 downto 14) := r.iflushpend & r.dflushpend;
      ccr(5 downto 0) :=
        r.cctrl.dfrz & r.cctrl.ifrz & r.cctrl.dcs & r.cctrl.ics;
     else
       assert false report "get_ccr() must not be called for RISC-V!" severity failure;
     end if;
      return ccr;
    end get_ccr;

    procedure set_ccr(val: std_logic_vector) is
      variable vx: std_logic_vector(31 downto 0);
    begin
     if arch = SPARC then
      vx := val;
      v.cctrl.dsnoop := vx(23);
      v.dflushpend := v.dflushpend or vx(22);
      v.iflushpend := v.iflushpend or vx(21);
      v.cctrl.dfrz := vx(5);
      v.cctrl.ifrz := vx(4);
      v.cctrl.dcs := vx(3 downto 2);
      v.cctrl.ics := vx(1 downto 0);
      v.cctrl.ics_btb := vx(1 downto 0);
     end if;
    end set_ccr;

    function ft_acc_resolve(at: std_logic_vector(2 downto 0); acc: std_logic_vector(2 downto 0))
      return std_logic_vector is
      variable r: std_logic_vector(2 downto 0);
      -- From the table in SPARC v8 H.5
      constant v0: std_logic_vector(0 to 7) := "00001011";
      constant v1: std_logic_vector(0 to 7) := "00001000";
      constant v2: std_logic_vector(0 to 7) := "11000111";
      constant v3: std_logic_vector(0 to 7) := "11000100";
      constant v4: std_logic_vector(0 to 7) := "10101111";
      constant v5: std_logic_vector(0 to 7) := "10101010";
      constant v6: std_logic_vector(0 to 7) := "11101111";
      constant v7: std_logic_vector(0 to 7) := "11101110";
    begin
      r := "000";
      if notx(acc) and notx(at) then
        case at is
          when "000"  => r(1) := v0(to_integer(unsigned(acc)));
          when "001"  => r(1) := v1(to_integer(unsigned(acc)));
          when "010"  => r(1) := v2(to_integer(unsigned(acc)));
          when "011"  => r(1) := v3(to_integer(unsigned(acc)));
          when "100"  => r(1) := v4(to_integer(unsigned(acc)));
          when "101"  => r(1) := v5(to_integer(unsigned(acc)));
          when "110"  => r(1) := v6(to_integer(unsigned(acc)));
          when others => r(1) := v7(to_integer(unsigned(acc)));
        end case;
        if r(1)='1' and (acc="110" or acc="111") and not (at="101" or at="111") then
          r(0) := '1';
        end if;
      else
        setx(r);
      end if;
      return r;
    end ft_acc_resolve;

    -- Find first zero in pmru vector, returns index
    -- (returns highest index if all ones)
    function pmru_decode(pmru: std_logic_vector) return std_logic_vector is
      constant nent: integer := pmru'length;
      variable r: std_logic_vector(log2(nent)-1 downto 0);
      variable xpmru: std_logic_vector(0 to 2**log2(nent)-1);
      constant onev: std_logic_vector(0 to 15) := "1111111111111111";
    begin
      xpmru := (others => '0');
      xpmru(0 to nent-1) := pmru;
      xpmru(nent-1) := '0'; -- return highest index if all-ones
      r := (others => '0');
      for q in r'high downto 0 loop
        if xpmru(0 to (2**q-1))=onev(0 to (2**q-1)) then
          r(q) := '1';
          xpmru(0 to (2**q-1)) := xpmru(2**q to 2**(q+1)-1);
        end if;
      end loop;
      return r;
    end pmru_decode;

    function calc_lruent(oent: lruent; hway: unsigned(1 downto 0); nways: integer) return lruent is
      variable nent: lruent;
    begin
      nent := (others => '0');
      case nways is
        when 1 =>
          nent := "00000";
        when 2 =>
          nent(4) := '0';
          nent(3) := not hway(0);
          nent(2 downto 0) := "000";
        when 3 =>
          nent(4 downto 2) := lru_3way_table(to_integer(unsigned(oent(4 downto 2))))(to_integer(hway));
          nent(1 downto 0) := "00";
        when others =>
          nent := lru_4way_table(to_integer(unsigned(oent)))(to_integer(hway));
      end case;
      return nent;
    end calc_lruent;

    function dec4wrap(n: std_logic_vector(1 downto 0); w: integer) return std_logic_vector is
      variable r: std_logic_vector(0 to 3);
    begin
      r := (others => '0');
      for v in 0 to 3 loop
        if n=std_logic_vector(to_unsigned(v,2)) then
          r(v mod w) := '1';
        end if;
      end loop;
      return r;
    end dec4wrap;

    -- SPARC only
    function flushmatch(e: tlbent; vaddr: std_logic_vector; curctx: std_logic_vector) return std_ulogic is
      variable fltp: std_logic_vector(3 downto 0);
      variable r: std_ulogic;
      variable acctype, ctxeq: std_ulogic;
    begin
      r := '0';
      if notx(e.acc) and notx(e.ctx) and notx(e.vaddr) and notx(e.mask(3)) and notx(e.mask(2)) and notx(e.mask(1)) then
        fltp := vaddr(11 downto 8);
        acctype := '0';
        if unsigned(e.acc) > 5 then acctype := '1'; end if;
        ctxeq := '0';
        if e.ctx=curctx then ctxeq := '1'; end if;
        case fltp is
          when "0000" =>
            if (acctype='1' or ctxeq='1') and vaddr(31 downto 12)=e.vaddr(31 downto 12) and e.mask(3)='1' then
              r := '1';
            end if;
          when "0001" =>
            if (acctype='1' or ctxeq='1') and vaddr(31 downto 18)=e.vaddr(31 downto 18) and e.mask(2)='1' then
              r := '1';
            end if;
          when "0010" =>
            if (acctype='1' or ctxeq='1') and vaddr(31 downto 24)=e.vaddr(31 downto 24) and e.mask(1)='1' then
              r := '1';
            end if;
          when "0011" =>
            if acctype='0' and ctxeq='1' then
              r := '1';
            end if;
          when "0100" => r := '1';
          when others => r := '0';
        end case;
      else
        setx(r);
      end if;
      return r;
    end flushmatch;

    function tcmaddr_comp(accaddr: std_logic_vector(31 downto 16); tcmaddr: std_logic_vector(31 downto 16);
                          tcmen: integer; tcmabits: integer) return std_ulogic is
      variable r: std_ulogic;
      variable vmask: std_logic_vector(31 downto 16);
    begin
      vmask := (others => '0');
      for x in 31 downto 16 loop
        if x>(2+tcmabits) then
          vmask(x) := '1';
        end if;
      end loop;
      r := '0';
      if (accaddr and vmask)=(tcmaddr and vmask) and tcmen/=0 then r:='1'; end if;
      return r;
    end tcmaddr_comp;

  begin

    dbg <= (others => '0');
    --------------------------------------------------------------------------
    -- Variable init
    --------------------------------------------------------------------------
    v := r;
    vs := rs;

    if arch = SPARC then
      r_cctrl := r.cctrl;
      hindex  <= 0;
    else
      hindex  <= u2i(csro.hartid);
      r_cctrl := (
        dsnoop     => csro.cctrl.dsnoop,
        dcs        => csro.cctrl.dcs,
        ics        => csro.cctrl.ics,
        ics_btb    => csro.cctrl.ics,
        dfrz       => '0',
        ifrz       => '0',
        wcomben    => '0',  -- ?
        wchinten   => '0',  -- ?
        diaemru    => '0'   -- ?
      );
    end if;

    -- Ensure clearing
    oico                := nv_icache_out_none;
    odco                := nv_dcache_out_none;
    ocrami              := cram_in_none;
    obifi               := busif_in_type5_none;

    oico.data := cramo.idatadout;
    oico.way := "00";
    oico.mexc := '0';
    oico.exctype   := '0';
    oico.exchyper  := '0';     -- Default to non-hypervisor fault
    --
    oico.mexcdata := (others => '0');
    oico.mexcdata(7 downto 6) := r.mmuerr.l;
    oico.mexcdata(5) := r.mmuerr.at_su;
    oico.mexcdata(4 downto 2) := r.mmuerr.ft;
    oico.hold := r.holdn;
    oico.flush := r.flushpart(1);
    oico.mds := '1';
    oico.cfg := (others => '0');
    oico.bpmiss := r.ibpmiss;
    oico.eocl := '0';
    if r.i2pc(2)='1' and r.i2pc(3)='1' and (ilinesize=4 or r.i2pc(4)='1') then
      oico.eocl := '1';
    end if;
    oico.ics_btb := r_cctrl.ics_btb;
    oico.btb_flush := r.flushpart(1);
    oico.parked := '0';
    oico.ctxswitch := r.ctxswitch;
    odco.data := cramo.ddatadout;
    odco.way := "00";
    odco.mexc := '0';
    odco.exctype := '0';
    odco.exchyper := '0';     -- Default to non-hypervisor fault
    --
    odco.hold := r.holdn;
    odco.mds := '1';
    odco.dtrapet1 := r.dtrapet1;
    odco.dtrapet0 := r.dtrapet0;
    odco.dtraptt := r.dtraptt;
    odco.cache := '0';
    odco.wbhold := '0';
    odco.iudiag_mosi := r.iudiag_mosi;
    odco.iuctrl := r.iuctrl;

    -- Mux current 64 bit part of fetched RAM data
    rdbuf_data := (others => '-');  -- A better way?
    for x in 0 to LINESZMAX / 2 - 1 loop
      if r.d2vaddr(BUF_HIGH downto 3) = u2vec(x, BUF_HIGH - 2) then
        if not (endian = '1') then
          rdbuf_data := get(bifo.rdb.buf, (LINESZMAX - 2 * x - 2) * 32, 64);
        else
          rdbuf_data := get(bifo.rdb.buf, x * 64, 64);
        end if;
      end if;
    end loop;


    ocrami.iindex := (others => '0');
    ocrami.idataoffs := (others => '0');
    if r.holdn='0' then
      ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.i1pc(IOFFSET_HIGH downto IOFFSET_LOW);
      ocrami.idataoffs(log2(ilinesize)-2 downto 0) := r.i1pc(ILINE_HIGH downto ILINE_LOW);
      ocrami.ifulladdr := r.i1pc(ocrami.ifulladdr'range);
    else
      ocrami.iindex(IOFFSET_BITS-1 downto 0) := ici.rpc(IOFFSET_HIGH downto IOFFSET_LOW);
      ocrami.idataoffs(log2(ilinesize)-2 downto 0) := ici.rpc(ILINE_HIGH downto ILINE_LOW);
      ocrami.ifulladdr := ici.rpc(ocrami.ifulladdr'range);
    end if;
    ocrami.ifulladdrw := r.d2vaddr(ocrami.ifulladdrw'range);
    ocrami.itagen := (others => '0');
    ocrami.itagwrite := '0';
    ocrami.itagdin := (others => (others => '0'));
    for s in 0 to IWAYS-1 loop
      ocrami.itagdin(s)(ITAG_HIGH-ITAG_LOW+1 downto 1) := r.irdbufpaddr(ITAG_HIGH downto ITAG_LOW);
      ocrami.itagdin(s)(0) := '1';
    end loop;
    ocrami.idataen := (others => '0');
    ocrami.idatawrite := "00";
    ocrami.idatadin := (others => '0');
--    for x in 0 to 3 loop
--      if r.iramaddr=std_logic_vector(to_unsigned(x,2)) then
    for x in 0 to ilinesize/2-1 loop
      if r.iramaddr=std_logic_vector(to_unsigned(x,r.iramaddr'length)) then
        if (not (endian='1')) then
--          ocrami.idatadin := bifo.rdb.buf((3-x)*64+63 downto (3-x)*64);
          ocrami.idatadin := bifo.rdb.buf((ilinesize/2-1-x)*64+63 downto (ilinesize/2-1-x)*64);
        else
          ocrami.idatadin := bifo.rdb.buf(x*64+63 downto x*64);
        end if;
      end if;
    end loop;
    ocrami.itcmen := '0';
    ocrami.dtagcindex := (others => '0');
    if r.holdn='0' then
      ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d1vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
    else
      ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := dci.eaddress(DOFFSET_HIGH downto DOFFSET_LOW);
    end if;
    ocrami.dtagcen := (others => '0');
    ocrami.dtaguindex := (others => '0');
    ocrami.dtaguwrite := (others => '0');
    ocrami.dtagudin := (others => (others => '0'));
    ocrami.dtagcuindex := (others => '0');
    ocrami.dtagcuen := (others => '0');
    ocrami.dtagcuwrite := '0';
    ocrami.ddataindex := (others => '0');
    ocrami.ddataoffs := (others => '0');
    if r.holdn='0' or dci.write='1' then
      ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d1vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
      ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d1vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
      ocrami.ddatafulladdr := r.d1vaddr(ocrami.ddatafulladdr'range);
    else
      ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := dci.eaddress(DOFFSET_HIGH downto DOFFSET_LOW);
      ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := dci.eaddress(DLINE_HIGH downto DLINE_LOW_REAL);
      ocrami.ddatafulladdr := dci.eaddress(ocrami.ddatafulladdr'range);
    end if;
    ocrami.ddatafulladdrw := r.d1vaddr(ocrami.ddatafulladdrw'range);
    ocrami.ddataen := (others => '0');
    ocrami.ddatawrite := (others => '0');
    ocrami.ddatadin := (others => (others => '0'));
    for w in 0 to DWAYS-1 loop
      ocrami.ddatadin(w) := dci.edata;
    end loop;
    ocrami.dtcmen := '0';
    ocrami.dtcmdin := dci.edata;
    obifi.bifop := r.bifwait_op;
    obifi.clrrdbuf := '0';
    obifi.busaddr := (others => '0');
    obifi.busid := (others => '0');
    obifi.widebus := '1';
    obifi.size := "00";
    obifi.stdata := (others => '0');
    obifi.nosnoop := '0';
    obifi.su := '0';
    obifi.mmuacc := '0';
    obifi.maskwerr := "00";
    obifi.wcomb := r.bifwait_wc;
    obifi.dlfway := uext(r.d2hitv, obifi.dlfway);
    obifi.snoopen := r_cctrl.dsnoop;

    v.amo.lr_set := '0';
    obifi.lr_set := '0';
    obifi.lr_clr := '0';

    vwad := (others => '0');
    vwad(log2(dlinesize*4)-1 downto log2(cdataw/8)) := r.dramaddr;
    vwdata128 := bifo.rdb.buf(4*32-1 downto 0);
    if (vwad(4)='0') xor (endian='1') then
      vwdata128 := bifo.rdb.buf(LINESZMAX*32-1 downto LINESZMAX*32-128);
    end if;
    if (vwad(3)='0') xor (endian='1') then
      vwdata64 := vwdata128(127 downto 64);
    else
      vwdata64 := vwdata128(63 downto 0);
    end if;
    if cdataw=64 then
      vwdata := vwdata64;
    else
      vwdata := vwdata128;
    end if;
    if r.s=as_dcfetch then
      for x in 0 to 3 loop
        ocrami.ddatadin(x) := vwdata64;
      end loop;
    end if;
    v.perf := (others=>'0');
    vrflag := '0';


    if arch = SPARC then
      vdciwm := dci.write and not dci.lock;
    else -- arch = RISCV
      vdciwm := dci.write;
    end if;

    haddr        := (others => '0');
    fault        := false;
    fault_access := false;
    fault_hyper  := false;
    part_mask    := (others => '0');
    part         := (others => '0');
    ok           := false;
    entry        := tlbent_empty;

    done         := false;
    store_done   := false;
    do_pte1_hchk := false;
    do_access    := false;
    do_mmu_lock  := false;
    do_icfetch   := false;
    do_wrasi2    := false;
    do_rdcdiag   := false;

    pma_hit  := (others => '0');
    pma_prio := (others => '0');
    pma_fit  := (others => '0');
    pma_idx  := (others => '0');
    pma      := pma_unused;

    -- Ensure proper PMP setup in TLB if there is no PMP/PMA.
    if not pmpen and not pmaen then
      v.newent.pmp_r     := '1';
      v.newent.pmp_no_w  := '0';
      v.newent.pmp_no_x  := '0';
      v.hnewent.pmp_r    := '1';
      v.hnewent.pmp_no_w := '0';
      v.hnewent.pmp_no_x := '0';
    end if;
    if not pmaen then
      v.newent.pma       := pma_all;
      v.hnewent.pma      := pma_all;
    end if;


    --d_mexc    := '0';
    --d_exctype := '0';  -- Default to page fault
    --i_mexc    := '0';
    --i_exctype := '0';  -- Default to page fault

    start_walk  := false;
    start_hwalk := false;
    start_pmp   := false;
    pmp_mmu     := '0';

    iaddr_ok     := true;
    daddr_ok     := true;
    guest_top_ok := true;
    phys_top_ok  := true;
    --

    --------------------------------------------------------------------------
    -- Configuration register access via ASIs 0x02 and 0x04/0x19
    --------------------------------------------------------------------------
    if (not (endian='1')) then
      vregwdata0 := r.dregval(63 downto 32);
      vregwdata1 := r.dregval(31 downto 0);
    else
      vregwdata1 := r.dregval(63 downto 32);
      vregwdata0 := r.dregval(31 downto 0);
    end if;
    vregw0 := '0';
    vregw1 := '0';
    vregrdata0 := (others => '0');
    vregrdata1 := (others => '0');
    vbadreg0 := '0';
    vbadreg1 := '0';
    vregaddr64 := r.d2vaddr(7 downto 3);
    vregaddrmmu := r.d2vaddr(10 downto 8);
    if r.s=as_wrasi and r.d2asi=x"02" then
      if r.d2size="11" then vregw0 := '1'; vregw1 := '1'; end if;
      if r.d2vaddr(2)='0' then vregw0 := '1'; else vregw1 := '1'; end if;
    end if;
    vwidereg := '0';
    vwideregrdata := (others => '0');
    vwideregwdata := r.dregval;
    if endian='0' then
      vwideregwh := vregw0;
      vwideregwl := vregw1;
    else
      vwideregwh := vregw1;
      vwideregwl := vregw0;
    end if;
    vregwmmu := '0';
    if r.s=as_wrasi and (r.d2asi=x"19" or r.d2asi=x"04") then
      vregwmmu := '1';
    end if;
    case vregaddr64 is
      when "00000" =>   -- 0x00: Cache control register,
       if arch = SPARC then
        vregrdata0 := get_ccr(r,rs);
        if vregw0='1' then set_ccr(vregwdata0); end if;
                       -- 0x04: Unimplemented
        vbadreg1 := '1';
       end if;
      when "00001" =>  -- 0x08: ICache configuration register
       if arch = SPARC then
        vregrdata0 := cache_cfg5(0, iways, ilinesize, iwaysize, 0,
                                 0, 0, 0, 0, 1);
                       -- 0x0C: DCache configuration register
        vregrdata1 := cache_cfg5(0, dways, dlinesize, dwaysize, 0,
                                 6, 0, 0, 0, 1);
       end if;
      when "00010" =>  -- 0x10: LEON5 configuration register
       if arch = SPARC then
        vregrdata0(31 downto 30) := std_logic_vector(to_unsigned(dtagconf,2));
        if itcmen /= 0 then
          vregrdata0(28) := '1';
        end if;
        if dtcmen /= 0 then
          vregrdata0(27) := '1';
        end if;
        vregrdata0(26) := '0';   -- GRLIB AHB bus implementation
        vregrdata0(25 downto 23) := "001";  -- Revision 1
        if dphysbits /= 32 or iphysbits /= 32 then
          vregrdata0(21) := '1'; -- Indicate >4G address space support
        end if;
        vregrdata0(11) := r_cctrl.wcomben;
        vregrdata0(10) := r.iuctrl.staticd;
        vregrdata0(8)  := r.iuctrl.staticbp;
        vregrdata0(7)  := r.iuctrl.fbp;
        vregrdata0(6)  := r.iuctrl.fbtb;
        vregrdata0(5)  := r.iuctrl.dlatearith;
        vregrdata0(4)  := r.iuctrl.dlatewicc;
        vregrdata0(3)  := r.iuctrl.dbtb;
        vregrdata0(2)  := r.iuctrl.single_issue;
        vregrdata0(1)  := r.iuctrl.dlatealu;
        vregrdata0(0)  := r.iuctrl.fpspec;
        if vregw0='1' then
          v.cctrl.wcomben       := vregwdata0(11);
          v.iuctrl.staticd      := vregwdata0(10);
          --bit9 is reserved
          v.iuctrl.staticbp     := vregwdata0(8);
          v.iuctrl.fbp          := vregwdata0(7);
          v.iuctrl.fbtb         := vregwdata0(6);
          v.iuctrl.dlatearith   := vregwdata0(5);
          v.iuctrl.dlatewicc    := vregwdata0(4);
          v.iuctrl.dbtb         := vregwdata0(3);
          v.iuctrl.single_issue := vregwdata0(2);
          v.iuctrl.dlatealu     := vregwdata0(1);
          v.iuctrl.fpspec       := vregwdata0(0);
        end if;
                      -- 0x14: LEON5 FT configuration register (FT only)
        vbadreg1 := '1';
       end if;
      when "00011" =>  -- 0x18: LEON5 region flush mask register
       if arch = SPARC then
        vregrdata0(31 downto 4) := r.regflmask(31 downto 4);
        if vregw0='1' then
          v.regflmask := (others => '0');
          v.regflmask(31 downto 4) := vregwdata0(31 downto 4);
        end if;
                      -- 0x1C: LEON5 region flush register
        vregrdata1(31 downto 4) := r.regfladdr(31 downto 4);
        vregrdata1(1) := r.iregflush;
        vregrdata1(0) := r.dregflush;
        if vregw1='1' then
          v.regfladdr := (others => '0');
          v.regfladdr(31 downto 4) := vregwdata1(31 downto 4);
          v.iregflush := vregwdata1(1);
          v.dregflush := vregwdata1(0);
          v.iflushpend := v.iflushpend or v.iregflush;
          v.dflushpend := v.dflushpend or v.dregflush;
        end if;
       end if;

      when "00100" =>  -- 0x20: AHB error register
                       -- 0x24: AHB error address register
        -- Handled via bus interface in state machine code
        --   except writing trapmode fields of error register
        if vregw0='1' then
          v.mmuwtrapmode := vregwdata0(31 downto 30);
          v.ahbwtrapmode := vregwdata0(29 downto 28);
        end if;

      when "00101" =>  -- 0x28: AHB stripe configuration register
        -- This register is not implemented in standard AHB version
        -- of LEON5 (LEON5 config reg bits 26 and 21 are 0)
        vbadreg0 := '1';
        if dphysbits > 32 or iphysbits > 32 then
          vbadreg0 := '0';
          vregrdata0(27 downto 22) := std_logic_vector(to_unsigned(DTAG_HIGH, 6));
          vregrdata0(21 downto 16) := std_logic_vector(to_unsigned(ITAG_HIGH, 6));
        end if;
                      -- 0x2C: Trap register
        vregrdata1(25 downto 22) := r.ctrapacc;
        vregrdata1(21 downto 18) := r.ctrappend;
        vregrdata1(17 downto 16) := r.ctraptype;
        vregrdata1(12 downto 11) := r.wtraplost;
        vregrdata1(10 downto 9)  := r.wtrappend;
        vregrdata1(8)            := r.wtraptype;
        vregrdata1(7 downto 5)   := r.itraplost;
        vregrdata1(4 downto 2)   := r.itrappend;
        vregrdata1(1 downto 0)   := r.itraptype;
        if vregw1='1' then
          v.ctrapacc  := v.ctrapacc  and not vregwdata1(25 downto 22);
          v.ctrappend := v.ctrappend and not vregwdata1(21 downto 18);
          v.ctraptype := v.ctraptype and not vregwdata1(17 downto 16);
          v.wtraplost := v.wtraplost and not vregwdata1(12 downto 11);
          v.wtrappend := v.wtrappend and not vregwdata1(10 downto 9);
          v.wtraptype := v.wtraptype and not vregwdata1(8);
          v.itraplost := v.itraplost and not vregwdata1(7 downto 5);
          v.itrappend := v.itrappend and not vregwdata1(4 downto 2);
        end if;

      when "00111" =>  -- 0x38: FT error counters (FT only)
        vbadreg0 := '1';
                      -- 0x3C: Boot word
        vregrdata1 := bootword;

      when "01000" =>   -- 0x40: TCM configuration register
        if itcmen=0 and dtcmen=0 then
          vbadreg0 := '1';
        else
          if itcmen /= 0 then
            vregrdata0(31) := r.itcmwipe;
            vregrdata0(23 downto 21) := std_logic_vector(to_unsigned(itcmfrac,3));
            vregrdata0(20 downto 16) := std_logic_vector(to_unsigned(itcmabits+3,5));
            if vregw0='1' then
              v.itcmwipe := vregwdata0(31);
            end if;
          end if;
          if dtcmen /= 0 then
            vregrdata0(15) := r.dtcmwipe;
            vregrdata0(7 downto 5) := std_logic_vector(to_unsigned(dtcmfrac,3));
            vregrdata0(4 downto 0) := std_logic_vector(to_unsigned(dtcmabits+3,5));
            if vregw0='1' then
              v.dtcmwipe := vregwdata0(15);
            end if;
          end if;
        end if;

      when "01001" =>  -- 0x48: Instruction TCM control register
        if itcmen=0 and dtcmen=0 then
          vbadreg0 := '1';
        end if;
        if itcmen /=0 then
          vregrdata0(31 downto 16) := r.itcmaddr;
          vregrdata0(15 downto 8) := r.itcmctx;
          vregrdata0(4 downto 3) := r.itcmperm;
          vregrdata0(2) := r.itcmenva;
          vregrdata0(1) := r.itcmenvc;
          vregrdata0(0) := r.itcmenp;
          if vregw0='1' then
            v.itcmaddr := vregwdata0(31 downto 16);
            v.itcmctx := vregwdata0(15 downto 8);
            v.itcmperm := vregwdata0(4 downto 3);
            v.itcmenva := vregwdata0(2);
            v.itcmenvc := vregwdata0(1);
            v.itcmenp := vregwdata0(0);
          end if;
        end if;
                      -- 0x4C: Data TCM control register
        if itcmen=0 and dtcmen=0 then
          vbadreg1 := '1';
        end if;
        if dtcmen /= 0 then
          vregrdata1(31 downto 16) := r.dtcmaddr;
          vregrdata1(15 downto 8) := r.dtcmctx;
          vregrdata1(6 downto 3) := r.dtcmperm;
          vregrdata1(2) := r.dtcmenva;
          vregrdata1(1) := r.dtcmenvc;
          vregrdata1(0) := r.dtcmenp;
          if vregw1='1' then
            v.dtcmaddr := vregwdata1(31 downto 16);
            v.dtcmctx := vregwdata1(15 downto 8);
            v.dtcmperm := vregwdata1(6 downto 3);
            v.dtcmenva := vregwdata1(2);
            v.dtcmenvc := vregwdata1(1);
            v.dtcmenp := vregwdata1(0);
          end if;
        end if;

      when "10000" =>   -- 0x80,0x84: Extended region flush mask register (64-bit)
       if arch = SPARC then
        vwidereg := '1';
        vwideregrdata := (others => '0');
        vwideregrdata(dphysbits-1 downto 4) := r.regflmask;
        for x in dphysbits-1 downto 4 loop
          if (x>=32 and vwideregwh='1') or (x<32 and vwideregwl='1') then
            v.regflmask(x) := vwideregwdata(x);
          end if;
        end loop;
       end if;

      when "10001" =>   -- 0x88,0x8C: Extended region flush address register (64-bit)
       if arch = SPARC then
        vwidereg := '1';
        vwideregrdata := (others => '0');
        vwideregrdata(dphysbits-1 downto 4) := r.regfladdr;
        vwideregrdata(1) := r.iregflush;
        vwideregrdata(0) := r.dregflush;
        for x in dphysbits-1 downto 4 loop
          if (x>=32 and vwideregwh='1') or (x<32 and vwideregwl='1') then
            v.regfladdr(x) := vwideregwdata(x);
          end if;
        end loop;
        if vwideregwl='1' then
          v.iregflush := vwideregwdata(1);
          v.dregflush := vwideregwdata(0);
          v.iflushpend := v.iflushpend or v.iregflush;
          v.dflushpend := v.dflushpend or v.dregflush;
        end if;
       end if;

      when "10100" =>   -- 0xA0,0xA4: Extended AHB error address register (64-bit)
        -- Handled via bus interface in state machine code
        null;

      when others =>    -- Unimplemented
        vbadreg0 := '1';
        vbadreg1 := '1';
    end case;
    -- MMU registers
    if r.d2asi(0)='1' or r.d2asi(2)='1' then
      vbadreg1 := '1';
      vregrdata0 := (others => '0');
      vregrdata1 := (others => '0');
      case vregaddrmmu is
        when "000" =>  -- 0x000 MMU control register
          vregrdata0(31 downto 28) := "0000";  -- impl
          vregrdata0(27 downto 24) := "0001";  -- ver
          vregrdata0(23 downto 21) := std_logic_vector(to_unsigned(log2(itlbnum),3));
          vregrdata0(20 downto 18) := std_logic_vector(to_unsigned(log2(dtlbnum),3));
          vregrdata0(17 downto 16) := std_logic_vector(to_unsigned(0,2));
          vregrdata0(15) := r.mmctrl1.tlbdis;
          vregrdata0(14) := '1';   -- Sep tlb
         if arch = SPARC then
          vregrdata0(1) := r.mmctrl1.nf;
          vregrdata0(0) := r.mmctrl1.e;
         end if;
          if vregwmmu='1' then
            v.mmctrl1.tlbdis := vregwdata0(15);
           if arch = SPARC then
            v.mmctrl1.nf := vregwdata0(1);
            v.mmctrl1.e := vregwdata0(0);
           end if;
          end if;
        when "001" =>  -- 0x100 Context pointer register
         if arch = SPARC then
          vregrdata0(31 downto 2) := r.mmctrl1.ctxp;
          if vregwmmu='1' then
            v.mmctrl1.ctxp := vregwdata0(31 downto 2);
          end if;
         end if;
        when "010" =>  -- 0x200 Context register
         if arch = SPARC then
          --vregrdata0(7 downto 0) := r.mmctrl1.ctx;
          --vregrdata0(7 downto 0) := r.mmctrl1.ctx(7 downto 0);
          if vregwmmu='1' then
            --v.mmctrl1.ctx := vregwdata0(7 downto 0);
            --v.mmctrl1.ctx(7 downto 0) := vregwdata0(7 downto 0);
          end if;
         end if;
          -- Side effect of setting ctxflush in as_wrasi code
        when "011" =>  -- 0x300 Fault status register
         if arch = SPARC then
          -- Field cleared on read handled in FSM
          vregrdata0(17 downto 10) := r.mmfsr.ebe;
          vregrdata0(9 downto 8) := r.mmfsr.l;
          vregrdata0(7 downto 5) := r.mmfsr.at_ls & r.mmfsr.at_id & r.mmfsr.at_su;
          vregrdata0(4 downto 2) := r.mmfsr.ft;
          vregrdata0(1) := r.mmfsr.fav;
          vregrdata0(0) := r.mmfsr.ow;
         end if;
        when "100" =>  -- 0x400 Fault address register
         if arch = SPARC then
          vregrdata0(31 downto 12) := r.mmfar;
         end if;
        when others =>
          vbadreg0 := '1';
      end case;
    end if;

    vbadreg := '0';
    if vbadreg0='1' and vbadreg1='1'     then vbadreg:='1'; end if;
    if r.d2size /= "11" then
      if vbadreg0='1' and r.d2vaddr(2)='0' then vbadreg:='1'; end if;
      if vbadreg1='1' and r.d2vaddr(2)='1' then vbadreg:='1'; end if;
    end if;

   if arch = SPARC then
    --------------------------------------------------------------------------
    -- Trap handshake management
    --------------------------------------------------------------------------
    v.mmuerr.fav := '0';
    vmaskwtrap := "00";
    if r.holdn='1' and dci.trapack='1' then
      if dci.trapacktt=x"01" then           -- Instruction access exception
        v.itraptype := dci.trapackidata(1 downto 0);
        case v.itraptype is
          when "00" =>
            v.itrappend(0) := '0';
          when "01" =>
            v.itrappend(1) := '0';
            if r_cctrl.diaemru='1' then
              v.newerrclass := "01";
              v.newent.vaddr(31 downto 12) := dci.trapackpc(31 downto 12);
              v.mmuerr.fav := '1';
              v.mmuerr.l := dci.trapackidata(7 downto 6);
              v.mmuerr.at_ls := '0';        -- Load/Execute
              v.mmuerr.at_id := '1';        -- Instruction space
              v.mmuerr.at_su := dci.trapackidata(5);
              v.mmuerr.ft := dci.trapackidata(4 downto 2);
            end if;
          when others =>
            v.itrappend(2) := '0';
        end case;
      end if;
      v.itraplost := v.itraplost or v.itrappend;
      v.itrappend := (others => '0');
      -- Write error
      if dci.trapacktt=x"2b" then
        v.wtraptype := r.wtrappend(1);
        if v.wtraptype='0' then
          v.wtrappend(0) := '0';
        else
          v.wtrappend(1) := '0';
        end if;
      end if;
      if r.ahbwtrapmode="01" then
        v.wtraplost(0) := v.wtraplost(0) or v.wtrappend(0);
        v.wtrappend(0) := '0';
        vmaskwtrap(0) := '1';
      end if;
      if r.mmuwtrapmode="01" then
        v.wtraplost(1) := v.wtraplost(1) or v.wtrappend(1);
        v.wtrappend(1) := '0';
        vmaskwtrap(1) := '1';
      end if;
      -- Internal error
      if dci.trapacktt=x"60" then
        v.ctraptype := "00";
        for x in r.ctrappend'range loop
          if r.ctrappend(x)='1' then
            v.ctraptype := std_logic_vector(to_unsigned(x,2));
          end if;
        end loop;
        for x in r.ctrappend'range loop
          if v.ctraptype=std_logic_vector(to_unsigned(x,2)) then
            v.ctrappend(x) := '0';
          end if;
        end loop;
      end if;
    end if;
    if r.ahbwtrapmode="00" then
      vmaskwtrap(0) := '1';
    end if;
    if r.mmuwtrapmode="00" then
      vmaskwtrap(1) := '1';
    end if;

    obifi.maskwerr := vmaskwtrap;

    if bifo.stat.sterr(0)='1' and vmaskwtrap(0)='0' then v.wtrappend(0) := '1'; end if;
    if bifo.stat.sterr(1)='1' and vmaskwtrap(1)='0' then v.wtrappend(1) := '1'; end if;
    if bifo.stat.sterr(2)='1' or (bifo.stat.sterr(0)='1' and vmaskwtrap(0)='1') then v.wtraplost(0) := '1'; end if;
    if bifo.stat.sterr(3)='1' or (bifo.stat.sterr(1)='1' and vmaskwtrap(1)='1') then v.wtraplost(1) := '1'; end if;
   end if;

    --------------------------------------------------------------------------
    -- ICache logic
    --------------------------------------------------------------------------

    -- ICache TLB lookup
    itlbhit := '0';
    itlbamatch := '0';
    itlbpaddr := (others => '0');
    itlbperm := "0000";
    itlbclr := '0';
    itlbid := (others => '0');
    itlbbusw := '0';
    itlbcached := '0';
    -- -------------------------------------------------------------------------
    -- LEON5 iTLB lookup
    -- -------------------------------------------------------------------------
    if arch = SPARC then
      for x in 0 to itlbnum-1 loop
        ipc := r.i1pc_repl((x mod tlbrepl)*32+31 downto (x mod tlbrepl)*32);
        -- Calculate translation if entry x would match
        ientpaddr(r.itlb(0).paddr'high downto 12) := r.itlb(x).paddr;
        if r.itlb(x).mask(1)='0' then
          ientpaddr(31 downto 24) := ientpaddr(31 downto 24) or ipc(31 downto 24);
        end if;
        if r.itlb(x).mask(2)='0' then
          ientpaddr(23 downto 18) := ientpaddr(23 downto 18) or ipc(23 downto 18);
        end if;
        if r.itlb(x).mask(3)='0' then
          ientpaddr(17 downto 12) := ientpaddr(17 downto 12) or ipc(17 downto 12);
        end if;
        ientpaddr(11 downto 0) := ipc(11 downto 0);
        -- Select bus width from TLB unless 4 GiB entry, then decode from virt addr
        -- For cached, take from TLB entry but if cache is off take from PnP
        -- Note that cached is under user control in page table but busw is
        --   just a cached value that is implied from address
        ientbusw := r.itlb(x).busw;
        if r.itlb(x).mask(1)='0' then
          if ientpaddr(31)='0' then
            ientbusw := '1';
          else
            ientbusw := dec_wbmask_fixed(r.i1pc(31 downto 2), xwbmask);
          end if;
        end if;
        ientcached := r.itlb(x).cached;
        if x=0 and r.mmctrl1.e='0' then
          if r.i1pc(31)='0' then
            ientcached := '1';
          else
            ientcached := ahb_slv_dec_cache(r.i1pc(31 downto 0), ahbso, cached);
          end if;
        end if;
        -- Check if we match and if so OR in current entry's output into result
        if ( ( r.itlb(x).valid='1' and r.itlb(x).ctx=r.i1ctx_repl((x mod tlbrepl)*ctxbits+ctxbits-1 downto (x mod tlbrepl)*ctxbits) and
               (r.itlb(x).mask(1)='0' or r.itlb(x).vaddr(31 downto 24)=ipc(31 downto 24)) and
               (r.itlb(x).mask(2)='0' or r.itlb(x).vaddr(23 downto 18)=ipc(23 downto 18)) and
               (r.itlb(x).mask(3)='0' or r.itlb(x).vaddr(17 downto 12)=ipc(17 downto 12)) ) or
             (x=0 and r.mmctrl1.e='0') )
        then
          if (r.i1su='1' and r.itlb(x).perm(2)='1') or (r.i1su='0' and r.itlb(x).perm(0)='1') then
            itlbhit := '1';
          else
            if r.i1ten='1' and ici.inull='0' and r.i1rep='0' then
              itlbclr := '1';
            end if;
          end if;
          itlbamatch := '1';
          itlbid      := itlbid      or std_logic_vector(to_unsigned(x,itlbid'length));
          itlbpaddr   := itlbpaddr   or ientpaddr;
          itlbbusw    := itlbbusw    or ientbusw;
          itlbcached  := itlbcached  or ientcached;
        end if;
      end loop;
      itlbpaddr  (11 downto 0) := r.i1pc(11 downto 0);

      -- "free running" TLB id register used in probe state
      v.itlbprobeid := itlbid;
    end if;

    -- -------------------------------------------------------------------------
    -- NOELV iTLB lookup
    -- -------------------------------------------------------------------------
    if arch = RISCV then
      -- Note that this is for the previous (registered) access.
      -- Note that this is done in parallel with cache fetch (registered access).
      if not walk_pmp and (r.i1m = '1' or not mmu_enabled(r.i1mode)) then
        itlbchk         := tlbcheck_none;
        -- Some non-defaults to "fake" an MMU access
        itlbchk.hit     := '1';
        itlbchk.paddr   := fit0ext(r.i1pc, itlbchk.paddr);
        -- The busw/cached settings are overwritten below if PMA (not in TLB here)!
        if not pmaen then
          itlbchk.busw   := dec_wbmask_fixed(r.i1pc(31 downto 2), wbmask);
          itlbchk.cached := ahb_slv_dec_cache(r.i1pc(31 downto 0), ahbso, cached);
        end if;
        itlbchk.modded  := '1';
        iaddr_ok        := physical_ok(r.i1pc);
        if addr_check_mask(5) = '0' then
          iaddr_ok      := true;
        end if;
      else
        if walk_pmp and (r.i1m = '1' or not mmu_enabled(r.i1mode)) then
          iaddr_ok      := physical_ok(r.i1pc);
          if addr_check_mask(5) = '0' then
            iaddr_ok    := true;
          end if;
        else
          if hmmu_only(r.i1mode) then
            iaddr_ok    := gphysical_ok(r.i1pc, is_svx4_smaller(csro));
          else
            iaddr_ok    := virtual_ok(r.i1pc, is_sv_smaller(csro, r.i1mode));
          end if;
          if addr_check_mask(4) = '0' then
            iaddr_ok    := true;
          end if;
        end if;

        -- Pass along actual r.i1pc too, for LEON5 code equivalence.
        tlb_lookup("01", r.itlb, iaddr_ok, r.i1pc_repl, r.i1pc, r.i1ctx_repl, r.i1su, '0',
                   r.i1ten, '0', ici.inull, r.i1rep,
                   itlbchk, '0', '0', '0', '0', r.i1mode, is_sv_smaller(csro, r.i1mode),
                   '0', '0',
                   false
                   );
        -- With PMP/PMA in TLBs, the actual non-PT permissions check is done here.
        -- Needs to set .clr on failure, since new PT walk will be done!
        if walk_pmp and (r.i1m = '1' or not mmu_enabled(r.i1mode)) then
          itlbchk.paddr   := fit0ext(r.i1pc, itlbchk.paddr);
          -- The busw/cached settings are overwritten below if PMA!
          if not pmaen then
            itlbchk.busw   := dec_wbmask_fixed(r.i1pc(31 downto 2), wbmask);
            itlbchk.cached := ahb_slv_dec_cache(r.i1pc(31 downto 0), ahbso, cached);
          end if;
          itlbchk.modded  := '1';
          if r.i1ten = '1' and ici.inull = '0' and r.i1rep = '0' then
          end if;
          if itlbchk.hit = '1' then           -- Actual mode below is only M or not M
            if smepmp_ok_x(ext_smepmp, csro.mmwp, csro.mml,
                           cond(r.i1m = '1', PRIV_LVL_M, PRIV_LVL_S),
                           itlbchk.pmp_none, itlbchk.pmp_lock, itlbchk.pmp_rwx) and
               (not pmaen or pma_x(itlbchk.pma)) then
              -- Nothing to do here
            else
              itlbchk.hit  := '0';
              itlbchk.hitv := (others => '0');
              -- Invalidate matching TLB entry on permission fail since there will be a
              -- new MMU walk, and it would be a bad idea to have two instances in the TLB!
              -- Will not invalidate on repeat due to stall, since walk already done.
              if r.i1ten = '1' and ici.inull = '0' and r.i1rep = '0' then
                itlbchk.clr := '1';
              end if;
            end if;
          end if;
        else
          iaddr_ok := true;  -- Not used for its original purpose any longer!
        end if;
      end if;

      -- PMP - a separate unit is needed for cached instruction fetch!
      pmp          := pmp_clear;    -- Ensure no latches!
      pmp_xc       := '0';
      pmp_hit      := (others => '0');
      if not walk_pmp then
        if r.i1m = '0' and not actual_tlb_pmp then
          pmp.addr := get_lo(itlbchk.paddr, pa'length);
        else
          pmp.addr := get_lo(r.i1pc, pa'length);
        end if;
        -- Machine, supervisor or user mode?
        pmp.prv     := PRIV_LVL_M;
        if r.i1m = '0' then
          pmp.prv   := PRIV_LVL_S;
          if r.i1su = '0' then
            pmp.prv := PRIV_LVL_U;
          end if;
        end if;
        pmp.valid := (not ici.inull and r.holdn) or r.i1pmp;
        v.i1pmp   := '0';
        if pmpen then
          pmp_hit := pmp_match(csro.precalc,
                               pmp.addr,
                               pmp_entries, pmp_no_tor, pmp_g, pmp_msb);
          pmp_rwx := smepmp_rwx(csro.pmpcfg, csro.mmwp, csro.mml,
                                pmp.prv,
                                pmp_hit,
                                pmp_entries, ext_smepmp);
          pmp_xc := not pmp_rwx(0) and pmp.valid;
        end if;

        if pmaen then
          if pma_masked = 0 then
            pma_unit(csro.pma_precalc,
                     pmp.addr,
                     pmp.valid,
                     pma_hit,
                     pma_entries, 0, pmp_msb);
            pma_fit := (others => '0');

            -- Keep only the lowest numbered hit, since that is
            -- defined as the highest priority PMA.
            pma_prio := pma_hit and std_logic_vector(-signed(pma_hit));
            pma_idx  := fit0ext(clz(reverse(uext(pma_hit, PMAENTRIES))), pma_idx);
            pma      := to_pma(csro.pma_data(u2i(pma_idx)));
          else
            pma_masks(csro.pma_data,
                      pmp.addr,
                      pmp.valid,
                      pma, pma_fit,
                      pmp_msb);
            pma_hit  := (others => '1');
            pma_prio := (others => '1');
            pma_idx  := (others => '0');
            -- pma_fit is only useful for debug here!
            -- In the Sv32 case, the first level page table covers bits 31:22, so
            -- with masks at 31:28 (only supported case) there will always be a fit.
            if riscv_mmu = Sv32 then
              pma_fit := (others => '1');
            end if;
          end if;

          if pmp.valid = '1' then
            -- Need to hit a PMA entry!
            if all_0(pma_hit) then
              pmp_xc := '1';
            elsif not pma_valid(pma) then
              pmp_xc := '1';
            else
              -- Overwrite settings from above (not in TLB here)
              if r.i1m = '1' or not mmu_enabled(r.i1mode) or not actual_tlb_pmp then
                itlbchk.busw   := pma_busw(pma);
                itlbchk.cached := pma_cache(pma);
              end if;
              if not pma_x(pma) then
                pmp_xc := '1';
              else
              end if;
            end if;

            if pma_forced_fault(csro, pmp.addr) then
              pmp_xc := '1';
            end if;
          end if;
        end if;

        if itlbchk.hit = '0' then
          pmp_xc := '0';
        end if;

        if actual_tlb_pmp and r.i1m = '0' and mmu_enabled(r.i1mode) then
          pmp_xc := '0';
        end if;

        if addr_check_mask(6) = '0' then
          pmp_xc := '0';
        end if;

        -- Note that this is only for PMP/PMA _not_ using the TLBs,
        -- so *failkind is safe to use.
        if pmp_xc = '1' then
          -- Signal access fault
          v.ifailkind := "11";
        -- ifailkind(1) will cause an imisspend via ihit, and will be remembered
        -- until the I$ miss has been dealt with.
        elsif r.imisspend = '0' then
          v.ifailkind := "00";
        end if;
      end if;

      -- An iaddr_ok failure means that the original address was not OK,
      -- and thus can not have been in the TLBs - so *failkind is safe.
      if not iaddr_ok then
        if itlbchk.hit = '1' then
          -- Signal page/access fault
          v.ifailkind := "1" & (r.i1m or not to_bit(mmu_enabled(r.i1mode)));
        end if;
      end if;

      -- "free running" TLB id register used in probe state
      v.itlbprobeid := itlbchk.id(v.itlbprobeid'range);


      itlbhit     := itlbchk.hit;
      itlbamatch  := itlbchk.amatch;
      itlbid      := itlbchk.id;
      itlbpaddr   := itlbchk.paddr;
      itlbbusw    := itlbchk.busw;
      itlbcached  := itlbchk.cached;
      itlbclr     := itlbchk.clr;

      ipc := r.i1pc(ipc'range);

      itlbpaddr  (11 downto 0) := r.i1pc(11 downto 0);

    end if;

    -- -------------------------------------------------------------------------
    -- iTLB lookup end
    -- -------------------------------------------------------------------------


    -- Tag compare logic
    -- ihitv := "0000";
    ihitv := (others => '0');
    ihit := '0';
    iway := "00";
    ivalid := '0';
    idblhit := '0';
    for i in IWAYS-1 downto 0 loop
      if cramo.itagdout(i)(ITAG_HIGH-ITAG_LOW+1 downto 1) = itlbpaddr(ITAG_HIGH downto ITAG_LOW) then
        if
           r.i1ten='1' and itlbhit='1' then
          ihitv(i) := '1';
          if ihit='1' then idblhit := '1'; end if;  -- duplicated itag detected
          ihit := '1';
        end if;
        -- There is no point in making iway depend on whether there was a TLB hit.
        iway := iway or std_logic_vector(to_unsigned(i,2));
      end if;
      ivalidv(i) := cramo.itagdout(i)(0);
    end loop;
    ivalid := ivalidv(to_integer(unsigned(iway)));
    -- Note: ihit is AND:ed with ivalid, but ihitv is _not_ AND:ed with ivalidv
    -- If we happen to have a Icache miss to an address matching a tag,
    -- we need r.i2hitv to be set on the way where we had the cache line,
    -- in order to avoid putting the new cache line in another way and getting
    -- two ways with idential tag.
    -- This would be quite unlikely, only if the instruction address matches
    -- one of the default tags after a flush or a tag is invalidated via
    -- diagnostic access and we then match the address that was written.
    --   ihitv := ihitv and ivalidv;
    ihit := ihit and ivalid;

    -- Instruction TCM hit and muxing logic
    itcmhit := '0';
    if itcmen /= 0 then
      if r.i1tcmen='1' and tcmaddr_comp(r.i1pc(31 downto 16),r.itcmaddr,itcmen,itcmabits)='1' then
        itcmhit := '1';
        ihit := '1';
        ihitv := (others => '0');
        iway := "00";
        idblhit := '0';
        oico.data(0) := cramo.itcmdout;
        if r.holdn='1' then
          if (r.itcmperm(0)='0' and r.i1su='0') or (r.itcmperm(1)='0' and r.i1su='1') then
            oico.mexc := '1';
            oico.mexcdata(1 downto 0) := "10";
            v.itrappend(1) := '1';
          end if;
        end if;
      end if;
    end if;

    if r.i1rep='1' then
      ihitv := r.irephitv;
      ivalidv := r.irepvalidv;
      iway := r.irepway;
      ihit := ihitv(to_integer(unsigned(iway)));
      ivalid := ivalidv(to_integer(unsigned(iway)));
      itcmhit := r.ireptcmhit;
      ihit := (ihit and ivalid) or itcmhit;
      idblhit := '0';
      oico.data := r.irepdata;
      itlbhit := r.ireptlbhit;
      itlbpaddr := r.ireptlbpaddr;
      itlbid := r.ireptlbid;
    end if;


    -- No hits are valid if *failkind, since
    if v.ifailkind(1) = '1' then
      itlbchk.hit := '0';
      ihit        := '0';
      ihitv       := (others => '0');
    end if;

    ibufaddrmatch := '0';
    if r.irdbufen='1' and v.ifailkind(1)='0' then
      ihit := '0';
      idblhit := '0';
      if r.i1pc(r.irdbufvaddr'range)=r.irdbufvaddr and r.i1nostream='0' then
        ibufaddrmatch := '1';
        if (not (endian='1')) then
          if bifo.rdb.bufv(LINESZMAX-2-2*to_integer(unsigned(r.i1pc(log2(4*ilinesize)-1 downto 3))))='1' then
            ihit := '1';
          end if;
        else
          if bifo.rdb.bufv(1+2*to_integer(unsigned(r.i1pc(log2(4*ilinesize)-1 downto 3))))='1' then
            ihit := '1';
          end if;
        end if;
      end if;
    elsif r.i1cont='1' and v.ifailkind(1)='0' then
      ihitv := r.i2hitv;
      ivalidv := r.i2validv;
      itcmhit := r.i2tcmhit;
      ihit := orv(r.i2hitv) or r.i2tcmhit;
      ivalid := orv(r.i2validv);
      iway := "00";
      idblhit := '0';
      for x in 0 to IWAYS-1 loop
        if ihitv(x)='1' then
          iway := iway or std_logic_vector(to_unsigned(x,2));
        end if;
      end loop;
    end if;

    oico.way := iway;
    if IMUXDATA then
      oico.data(0) := oico.data(to_integer(unsigned(oico.way)));
      oico.way := "00";
    end if;

    if r.imisspend='1' and r.i2tcmhit='0' then
      oico.mds := '0';
    end if;
    if r.irdbufen='1' then
      -- Mux out buffer data
      oico.way := "00";
      for x in 0 to LINESZMAX/2-1 loop
        if (r.imisspend='1' and r.i2pc(BUF_HIGH downto 3)=std_logic_vector(to_unsigned(x,BUF_HIGH-2))) or
          (r.imisspend='0' and r.i1pc(BUF_HIGH downto 3)=std_logic_vector(to_unsigned(x,BUF_HIGH-2))) then
          if (not (endian='1')) then
            oico.data(0) := bifo.rdb.buf((LINESZMAX/2-x)*64-1 downto (LINESZMAX/2-x)*64-64);
          else
            oico.data(0) := bifo.rdb.buf(x*64+63 downto x*64);
          end if;
        end if;
        -- Allow for streaming from read data buffer
        if ( r.imisspend='1' and r.i2bufmatch='1' and
             r.i2pc(BUF_HIGH downto 3)=std_logic_vector(to_unsigned(x,BUF_HIGH-2))) then
          if (not (endian='1')) then
            if bifo.rdb.bufv(LINESZMAX-2*x-1 downto LINESZMAX-2*x-2)="11" then
              v.imisspend := '0';
              v.perf(12)  := '1';
            end if;
          else
            if bifo.rdb.bufv(2*x+1 downto 2*x)="11" then
              v.imisspend := '0';
              v.perf(12)  := '1';
            end if;
          end if;
        end if;
      end loop;
    end if;

    -- Main hit/miss checking logic (v.imisspend propagates to main FSM)
    -- Stage 2 ITLB update in case of hit
    d32 := r.i2pc(d32'range);
    if (arch = SPARC or ext_noelv = 1) and r.s=as_rdasi then
      d32 := r.d2vaddr(d32'range);
    end if;
    if notx(d32) then
      ilruent := r.ilru(to_integer(unsigned(d32(IOFFSET_HIGH downto IOFFSET_LOW))));
    else
      setx(ilruent);
    end if;
    if r.holdn='1' then
      vway := "00";
      vhit := '0';
      for x in r.i2hitv'range loop
        if r.i2hitv(x)='1' then
          vhit:='1';
          vway:=vway or to_unsigned(x,2);
        end if;
      end loop;
      if vhit='1' then
        v.ilru(to_integer(unsigned(r.i2pc(DOFFSET_HIGH downto DOFFSET_LOW)))) := calc_lruent(ilruent, vway, IWAYS);
      end if;
    end if;
    -- Stage 1 tag check (insn in fetch stage)
    v.i2tlbclr := '0';
    if r.holdn='1' then
      v.ibpmiss := '0';
    end if;
    if r.holdn='1' then
      dbg(0) <= '1';
      v.i2pc := r.i1pc;
      v.i2paddr := itlbpaddr(v.i2paddr'range);
      v.i2paddrv := itlbhit;
      v.i2tlbhit := itlbhit;
      v.i2tlbid := itlbid;
      v.i2tlbclr := itlbclr;
      v.i2busw := itlbbusw;
      v.i2paddrc := itlbcached;
      v.i2ctx := r.i1ctx;
      v.i2su := r.i1su;
      v.i2nostream := r.i1nostream;
      v.i2m := r.i1m;
      v.i2mode := r.i1mode;
      --
      v.i2bufmatch := ibufaddrmatch;
      v.i2tcmhit := itcmhit;
      if r.irdbufen='0' then
        v.i2validv := ivalidv;
        v.i2hitv := ihitv;
        v.irdbufvaddr := r.i1pc(r.irdbufvaddr'range);
        v.irdbufpaddr := v.i2paddr(r.irdbufpaddr'range);
      end if;
      -- Set icmiss pending bit
      if ici.inull='0' and ihit/='1' then
        if ici.nobpmiss='0' then
          v.imisspend := '1';
        else
          v.ibpmiss := '1';
        end if;
      end if;
      if r.i1rep='0' then
        v.irephitv := ihitv;
        v.irepvalidv := ivalidv;
        v.irepway := iway;
        v.irepdata := cramo.idatadout;
        v.ireptcmhit := itcmhit;
        if itcmhit='1' then
          v.irepdata(0) := cramo.itcmdout;
        end if;
        v.ireptlbhit := itlbhit;
        v.ireptlbpaddr := itlbpaddr;
        v.ireptlbid := itlbid;
      end if;
      if idblhit='1' then
        v.ctrappend(0) := '1';
      end if;
    end if;
    -- Stage 0 drive addresses (insn in pre-fetch stage)
    if r.holdn='1' then
      -- NOTE: Assuming read-hold behavior
      v.i1ten := '0';
    end if;
    if (r.holdn='1' or r.ramreload='1') and r_cctrl.ics(0)='1' then
      ocrami.itagen := "1111";
      ocrami.idataen := "1111";
      v.i1ten := '1';
    end if;
    itcmact := '0';
   if arch = SPARC then
    if r.itcmenp='1' and r.mmctrl1.e='0' then itcmact := '1'; end if;
    if r.itcmenva='1' and r.mmctrl1.e='1' then itcmact := '1'; end if;
    if r.itcmenvc='1' and r.mmctrl1.e='1' and r.mmctrl1.ctx=r.itcmctx then itcmact:='1'; end if;
   end if;
    if (r.holdn='1' or r.ramreload='1') then
      v.i1tcmen := '0';
      if itcmact='1' then
        ocrami.itcmen := '1';
        v.i1tcmen := '1';
      end if;
    end if;

    icont := '0';
    if ici.rbranch='0' and ici.fpc(ILINE_HIGH downto ILINE_LOW)/=onev(ILINE_HIGH downto ILINE_LOW) then
      icont := '1';
    end if;
    if r.i1ten='0' and r.i1cont='0' then
      icont := '0';
    end if;
    if r.i1cont='0' and ici.inull='1' then
      icont := '0';
    end if;
    if r.ramreload='1' then
      icont := '0';
      v.i1cont := '0';
    end if;
    if icont='1' and (r.i1ten='1' or r.i1cont='1') then
      ocrami.itagen := "0000";
    end if;
    if icont='1' and r.i1cont='1' then
      ocrami.idataen(0 to IWAYS-1) := ocrami.idataen(0 to IWAYS-1) and r.i2hitv;
    end if;
    if r_cctrl.ics(0)='0' then
      icont := '0';
    end if;
    if r.holdn='1' then
      if ici.iustall = '0' then
        v.i1pc := ici.rpc(v.i1pc'range);
        v.i1su := ici.su;
        v.i1cont := icont;
        v.i1ctx := r.mmctrl1.ctx;
        v.i1m        := '0';
        v.i1mode     := (others => '0');
        v.i1nostream := ici.nostream;
        if arch = RISCV then
          -- Machine, supervisor or user mode?
          v.i1m      := ici.vms(1);
          v.i1su     := ici.vms(0);
          -- Virtual or not?
          v.i1mode   := get_mode(csro, ici.vms);
          v.i1ctx    := mmu_ctx(csro, v.i1mode);
        end if;
      end if;
      v.i1rep := ici.iustall;
    end if;
    if r.ramreload='1' then
      v.i1rep := '0';
    end if;


    -- select input data for Icache

    --------------------------------------------------------------------------
    -- DCache logic
    --------------------------------------------------------------------------

    dctagsv := cramo.dtagcdout;
    if dtagconf > 0 then
      voffs := r.d1vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
      if r.s=as_regflush then
        voffs := r.regflpipe(2).addr(DOFFSET_HIGH downto DOFFSET_LOW);
      elsif r.s=as_rdcdiag2 or r.s=as_wptectag2 or r.s=as_atomic2 then
        voffs := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
      end if;
      for w in 0 to DWAYS-1 loop
        if notx(voffs) then
          dctagsv(w)(0) := rs.validarr(to_integer(unsigned(voffs)))(w);
        else
          setx(dctagsv(w)(0));
        end if;
      end loop;
    end if;

    -- DCache TLB lookup
    dtlbhit := '0';
    dtlbamatch := '0';
    dtlbpaddr := (others => '0');
    dtlbperm := "0000";
    dtlbid := (others => '0');
    dtlbbusw := '0';
    dtlbcached := '0';
    dtlbmod := '0';
    dtlbclr := '0';
    dtlb_write := vdciwm;
    dci_atomic   := r.amo.d1type(5);
    dtlb_lock    := dci_atomic;
    --
    -- -------------------------------------------------------------------------
    -- LEON5 TLB lookup
    -- -------------------------------------------------------------------------
    if arch = SPARC then
      for x in 0 to dtlbnum-1 loop
        dvaddr := r.d1vaddr_repl((x mod tlbrepl)*32+31 downto (x mod tlbrepl)*32);
        -- Calculate translation if entry x would match
        dentpaddr(35 downto 12) := r.dtlb(x).paddr;
        dentpaddr(11 downto 0) := (others => '0');
        if r.dtlb(x).mask(1)='0' then
          dentpaddr(31 downto 24) := dentpaddr(31 downto 24) or dvaddr(31 downto 24);
        end if;
        if r.dtlb(x).mask(2)='0' then
          dentpaddr(23 downto 18) := dentpaddr(23 downto 18) or dvaddr(23 downto 18);
        end if;
        if r.dtlb(x).mask(3)='0' then
          dentpaddr(17 downto 12) := dentpaddr(17 downto 12) or dvaddr(17 downto 12);
        end if;
        -- Select bus width from TLB unless 4 GiB entry on low 4GiB, then decode from virt addr
        -- For cached, take from TLB entry but if cache is off take from PnP
        -- Note that cached is under user control in page table but busw is
        --   just a cached value that is implied from address
        dentbusw := r.dtlb(x).busw;
        if r.dtlb(x).mask(1)='0' then
          if dentpaddr(35 downto 32)="0000" and dentpaddr(31)='0' then
            dentbusw := '1';
          else
            dentbusw := dec_wbmask_fixed(r.d1vaddr(31 downto 2), xwbmask);
          end if;
        end if;
        dentcached := r.dtlb(x).cached;
        if x=0 and r.mmctrl1.e='0' then
          if r.d1vaddr(31)='0' then
            dentcached := '1';
          else
            dentcached := ahb_slv_dec_cache(r.d1vaddr(31 downto 0), ahbso, cached);
          end if;
        end if;
        -- Check if we match and if so OR in current entry's output into results
        if ( ( r.dtlb(x).valid='1' and r.dtlb(x).ctx=r.mmctrl1.ctx and
             (r.dtlb(x).mask(1)='0' or r.dtlb(x).vaddr(31 downto 24)=dvaddr(31 downto 24)) and
             (r.dtlb(x).mask(2)='0' or r.dtlb(x).vaddr(23 downto 18)=dvaddr(23 downto 18)) and
             (r.dtlb(x).mask(3)='0' or r.dtlb(x).vaddr(17 downto 12)=dvaddr(17 downto 12)) ) or
             (x=0 and r.mmctrl1.e='0') ) then
          if ( (r.d1su='1' and (dtlb_write='1' or  dtlb_lock='1') and r.dtlb(x).perm(3)='1') or
               (r.d1su='1' and (dtlb_write='0' and dtlb_lock='0') and r.dtlb(x).perm(2)='1') or
               (r.d1su='0' and (dtlb_write='1' or  dtlb_lock='1') and r.dtlb(x).perm(1)='1') or
               (r.d1su='0' and (dtlb_write='0' and dtlb_lock='0') and r.dtlb(x).perm(0)='1') ) then
            dtlbhit := '1';
          else
            if r.d1chk='1' and r.d1specialasi='0' and dci.nullify='0' then
              dtlbclr := '1';
            end if;
          end if;
          dtlbamatch := '1';
          dtlbid      := dtlbid      or std_logic_vector(to_unsigned(x,dtlbid'length));
          dtlbpaddr   := dtlbpaddr   or dentpaddr;
          dtlbbusw    := dtlbbusw    or dentbusw;
          dtlbcached  := dtlbcached  or dentcached;
          dtlbmod     := dtlbmod     or r.dtlb(x).modified;
        end if;
      end loop;
      if r_cctrl.dcs(0)='0' then
        dtlbcached := '0';
      end if;
      dtlbpaddr(11 downto 0) := r.d1vaddr(11 downto 0);

      dtlbpaddr_chk := '0' & dtlbpaddr;
      dtlbhit_chk := dtlbhit;
      if r.dtlbbypass='1' then
        dtlbpaddr_chk := r.d2paddr;
        dtlbhit_chk := r.d2paddrv;
      end if;
    end if;

    -- -------------------------------------------------------------------------
    -- NOELV TLB lookup and PMP
    -- -------------------------------------------------------------------------
    if arch = RISCV then
      if not walk_pmp and (r.d1m = '1' or not mmu_enabled(r.d1mode)) then
        -- From tlb_lookup and dummy TLB entry.
        dtlbchk        := tlbcheck_none;
        -- Some non-defaults to "fake" an MMU access
        dtlbchk.hit    := '1';
        dtlbchk.paddr  := fit0ext(r.d1vaddr, dtlbchk.paddr);
        -- The busw/cached settings are overwritten below if PMA (not in TLB here)!
        if not pmaen then
          dtlbchk.busw   := dec_wbmask_fixed(r.d1vaddr(31 downto 2), wbmask);
          dtlbchk.cached := ahb_slv_dec_cache(r.d1vaddr(31 downto 0), ahbso, cached);
        end if;
        dtlbchk.modded := '1';
        daddr_ok       := physical_ok(r.d1vaddr);
        if addr_check_mask(1) = '0' then
          daddr_ok     := true;
        end if;
      else
        -- Shadow stack accesses without using (v)sPT causes fault,
        -- but do not touch TLB so it is safe to treat at top bit error.
        if walk_pmp and (r.d1m = '1' or not mmu_enabled(r.d1mode)) then
          daddr_ok     := physical_ok(r.d1vaddr);
          if addr_check_mask(1) = '0' then
            daddr_ok   := true;
          end if;
          if ext_zicfiss = 1 and r.d1ss = '1' then
            if r.d1m = '1' then
              -- In M, only SSAMOSWAP can get here, and that throws store/AMO access fault
            else
              -- If bare, store/AMO access fault
            end if;
            -- Signal access fault
            daddr_ok   := false;
          end if;
        else
          if hmmu_only(r.d1mode) then
            daddr_ok   := gphysical_ok(r.d1vaddr, is_svx4_smaller(csro));
            if ext_zicfiss = 1 and r.d1ss = '1' then
              -- If bare, store/AMO access fault
              -- Signal access fault
              daddr_ok := false;
            end if;
          else
            daddr_ok   := virtual_ok(r.d1vaddr, is_sv_smaller(csro, r.d1mode));
          end if;
          if addr_check_mask(0) = '0' then
            daddr_ok   := true;
          end if;
        end if;
        -- Pass along actual rd1vaddr too, for LEON5 code equivalence.
        tlb_lookup("00", r.dtlb, daddr_ok, r.d1vaddr_repl, r.d1vaddr,
                   r.d1ctx_repl, r.d1su, dtlb_write,
                   r.d1chk,
                   r.d1specialasi, dci.nullify, '0',
                   dtlbchk, r.d1sum, r.d1mxr, r.d1vmxr, r.d1hx, r.d1mode, is_sv_smaller(csro, r.d1mode),
                   r.d1ss, cond(not is_v(r.d1mode),
                                 csro.menvcfg_sse, csro.menvcfg_sse and csro.henvcfg_sse),
                   true
                   );
        -- With PMP/PMA in TLBs, the actual non-PT permissions check is done here.
        -- Needs to set .clr on failure, since new PT walk will be done!
        if walk_pmp and (r.d1m = '1' or not mmu_enabled(r.d1mode)) then
          dtlbchk.paddr  := fit0ext(r.d1vaddr, dtlbchk.paddr);
          -- The busw/cached settings are overwritten below if PMA (not in TLB here)!
          if not pmaen then
            dtlbchk.busw   := dec_wbmask_fixed(r.d1vaddr(31 downto 2), wbmask);
            dtlbchk.cached := ahb_slv_dec_cache(r.d1vaddr(31 downto 0), ahbso, cached);
          end if;
          dtlbchk.modded := '1';
          if dtlbchk.hit = '1' then             -- Actual mode below is only M or not M
            if (dtlb_write = '0' and smepmp_ok_r(ext_smepmp, csro.mmwp, csro.mml,
                                                 cond(r.d1m = '1', PRIV_LVL_M, PRIV_LVL_S),
                                                 dtlbchk.pmp_none, dtlbchk.pmp_lock,
                                                 dtlbchk.pmp_rwx) and
                (not pmaen or pma_r(dtlbchk.pma)) and
                (ext_h = 0 or r.d1hx = '0' or
                                     smepmp_ok_x(ext_smepmp, csro.mmwp, csro.mml,
                                                 cond(r.d1m = '1', PRIV_LVL_M, PRIV_LVL_S),
                                                 dtlbchk.pmp_none, dtlbchk.pmp_lock,
                                                 dtlbchk.pmp_rwx))) or
               (dtlb_write = '1' and smepmp_ok_w(ext_smepmp, csro.mmwp, csro.mml,
                                                 cond(r.d1m = '1', PRIV_LVL_M, PRIV_LVL_S),
                                                 dtlbchk.pmp_none, dtlbchk.pmp_lock,
                                                 dtlbchk.pmp_rwx) and
                (not pmaen or pma_w(dtlbchk.pma))) then
            -- Nothing to do here
            else
              dtlbchk.hit  := '0';
              dtlbchk.hitv := (others => '0');
              -- Invalidate matching TLB entry on permission fail since there will be a
              -- new MMU walk, and it would be a bad idea to have two instances in the TLB!
              if r.d1chk = '1' and r.d1specialasi = '0' and dci.nullify = '0' then
                dtlbchk.clr := '1';
              end if;
            end if;
          end if;
        else
          daddr_ok := true;  -- Not used for its original purpose any longer!
        end if;
      end if;


      dtlbhit     := dtlbchk.hit;
      dtlbamatch  := dtlbchk.amatch;
      dtlbid      := dtlbchk.id;
      dtlbpaddr   := dtlbchk.paddr;
      dtlbbusw    := dtlbchk.busw;
      dtlbcached  := dtlbchk.cached;
      dtlbmod     := dtlbchk.modded;
      dtlbclr     := dtlbchk.clr;

      dvaddr := r.d1vaddr(dvaddr'range);

      dtlbpaddr(11 downto 0) := r.d1vaddr(11 downto 0);


      dtlbpaddr_chk := dtlbpaddr(dtlbpaddr_chk'range);
      dtlbhit_chk := dtlbhit;
      ss_chk := r.d1ss;
      m_chk  := r.d1m;
      hx_chk := r.d1hx;
      su_chk := r.d1su;
      if r.dtlbbypass='1' then
        dtlbpaddr_chk := r.d2paddr;
        dtlbhit_chk := r.d2paddrv;
        dtlb_write := r.d2write;  -- Cannot use dci.write here!
        ss_chk := r.d2ss;
        m_chk  := r.d2m;
        hx_chk := r.d2hx;
        su_chk := r.d2su;
      end if;

      -- PMP
      if not walk_pmp then
        pmp       := pmp_clear;      -- Ensure no latches!
        pmp_xc    := '0';
        pmp_hit   := (others => '0');
        pmp.acc   := PMP_ACCESS_R;
        if dtlb_write = '1' then
          pmp.acc := PMP_ACCESS_W;
        end if;
        -- Shadow stack instructions always check for writeability
--        if ext_zicfiss = 1 and r.d1ss = '1' then
        if ext_zicfiss = 1 and ss_chk = '1' then
          pmp.acc := PMP_ACCESS_W;
        end if;
--        if r.d1m = '0' and not actual_tlb_pmp then
        if m_chk = '0' and not actual_tlb_pmp then
          pmp.addr := fit0ext(dtlbpaddr_chk, pmp.addr);
        else
          pmp.addr := fit0ext(r.d1vaddr, pmp.addr);
        end if;
        -- Only check if access now and it hit in the TLB (otherwise address is wrong).
        pmp.valid := (r.d1chk and dtlbhit_chk and not dci.nullify and not r.d1specialasi) or r.d1pmp;
        v.d1pmp   := '0';
        if r.dtlbbypass = '1' and not actual_tlb_pmp then
          --pmp.valid := pmp.valid or dtlbchk.hit;
          pmp.valid := pmp.valid or dtlbhit_chk;
          --pmp.addr := fit0ext(dtlbchk.paddr, pmp.addr);
          pmp.addr := fit0ext(dtlbpaddr_chk, pmp.addr);
          if pmp.valid = '1' then
          end if;
        end if;

        -- Machine, supervisor or user mode?
        pmp.prv     := PRIV_LVL_M;
--        if r.d1m = '0' then
        if m_chk = '0' then
          pmp.prv   := PRIV_LVL_S;
--          if r.d1su = '0' then
          if su_chk = '0' then
            pmp.prv := PRIV_LVL_U;
          end if;
        end if;
        pmp.mprv    := '0';
        pmp.mpp     := (others => '0');

        -- The rest here should, hopefully, be possible to replace with common later.
        if pmpen then
          pmp_hit := pmp_match(csro.precalc,
                               pmp.addr,
                               pmp_entries, pmp_no_tor, pmp_g, pmp_msb);
          pmp_rwx := smepmp_rwx(csro.pmpcfg, csro.mmwp, csro.mml,
                                pmp.prv,
                                pmp_hit,
                                pmp_entries, ext_smepmp);
          if pmp.acc = PMP_ACCESS_R then
            pmp_xc := not pmp_rwx(2);
--            if ext_h = 1 and r.d1hx = '1' then
            if ext_h = 1 and hx_chk = '1' then
              pmp_xc := pmp_xc or not pmp_rwx(0);
            end if;
          else
            pmp_xc := not pmp_rwx(1);
          end if;
        end if;

        -- Shadow stack accesses without using (v)sPT causes fault,
        -- but do not touch TLB so it is safe to treat at PMP error.
        -- Note that this check is only relevant for non-mapped accesses,
        -- so there is no need to worry about r.dtlbbypass/d1pmp.
        if ext_zicfiss = 1 and r.d1ss = '1' and
           (r.d1chk and dtlbhit_chk and not dci.nullify and not r.d1specialasi) = '1' then
          if r.d1m = '1' then
            -- In M, only SSAMOSWAP can get here, and that throws store/AMO access fault
            -- Signal access fault
            pmp_xc := '1';
          else
            if not mmu_enabled(r.d1mode) or hmmu_only(r.d1mode) then
              -- If bare, store/AMO access fault
              -- Signal access fault
              pmp_xc := '1';
            end if;
          end if;
        end if;


        if pmaen then
          if pma_masked = 0 then
            pma_unit(csro.pma_precalc,
                     pmp.addr,
                     pmp.valid,
                     pma_hit,
                     pma_entries, 0, pmp_msb);
            pma_fit := (others => '0');

            -- Keep only the lowest numbered hit, since that is
            -- defined as the highest priority PMA.
            pma_prio := pma_hit and std_logic_vector(-signed(pma_hit));
            pma_idx  := fit0ext(clz(reverse(uext(pma_hit, PMAENTRIES))), pma_idx);
            pma      := to_pma(csro.pma_data(u2i(pma_idx)));
          else
            pma_masks(csro.pma_data,
                      pmp.addr,
                      pmp.valid,
                      pma, pma_fit,
                      pmp_msb);
            pma_hit  := (others => '1');
            pma_prio := (others => '1');
            pma_idx  := (others => '0');
            -- pma_fit is only useful for debug here!
            -- In the Sv32 case, the first level page table covers bits 31:22, so
            -- with masks at 31:28 (only supported case) there will always be a fit.
            if riscv_mmu = Sv32 then
              pma_fit := (others => '1');
            end if;
          end if;

          if pmp.valid = '1' then
            -- Need to hit a PMA entry!
            if all_0(pma_hit) then
              pmp_xc := '1';
            elsif not pma_valid(pma) then
              pmp_xc := '1';
            else
              -- Overwrite settings from above (not in TLB here)
              if r.d1m = '1' or not mmu_enabled(r.d1mode) or not actual_tlb_pmp then
                dtlbchk.busw   := pma_busw(pma);
                dtlbchk.cached := pma_cache(pma);
                dtlbbusw    := dtlbchk.busw;
                dtlbcached  := dtlbchk.cached;
              end if;
              if pmp.acc = PMP_ACCESS_R and not pma_r(pma) then
                pmp_xc := '1';
--              elsif pmp.acc = PMP_ACCESS_R and ext_h = 1 and r.d1hx = '1' and not pma_x(pma) then
              elsif pmp.acc = PMP_ACCESS_R and ext_h = 1 and hx_chk = '1' and not pma_x(pma) then
                pmp_xc := pmp_xc or not pmp_rwx(0);
              elsif pmp.acc = PMP_ACCESS_W and not pma_w(pma) then
                pmp_xc := '1';
              -- LR/SC?
              elsif (r.amo.d1type(5) = '1' and r.amo.d1type(1) = '1') and not pma_lrsc(pma) then
                pmp_xc := '1';
              -- Normal AMO
              elsif not all_0(r.amo.d1type) and not pma_amo(pma) then
                pmp_xc := '1';
              else
              end if;

              if pma_forced_fault(csro, pmp.addr) then
                pmp_xc := '1';
              end if;
            end if;
          end if;
        end if;

        if actual_tlb_pmp and r.d1m = '0' and mmu_enabled(r.d1mode) then
          pmp_xc := '0';
        end if;

        if addr_check_mask(2) = '0' then
          pmp_xc := '0';
        end if;

        if pmp.valid = '1' and pmp_xc = '1' then
        elsif (r.d1m = '1' or not actual_tlb_pmp) and pmp.valid = '1' then
        end if;
      end if;

      -- Data cache explicitly disabled?
      if r_cctrl.dcs(0)='0' then
        dtlbcached := '0';
      end if;

      -- This is already true, but be more clear about it.
      if walk_pmp then
        pmp    := pmp_clear;
        pmp_xc := '0';
      end if;

    end if;
    -- -------------------------------------------------------------------------
    -- TLB lookup and PMP end
    -- -------------------------------------------------------------------------

    -- Tag compare logic
    dhitv := (others => '0');
    dhit := '0';
    dway := "00";
    dvalid := '0';
    dvalidv := (others => '0');
    ddblhit := '0';
    for i in DWAYS-1 downto 0 loop
      if dctagsv(i)(DTAG_HIGH-DTAG_LOW+1 downto 1) = dtlbpaddr_chk(DTAG_HIGH downto DTAG_LOW) then
        if
           r.d1ten='1' and dtlbhit_chk='1' then
          dhitv(i) := '1';
          if dhit='1' then ddblhit := '1'; end if;  -- duplicated dtag detected
          dhit := '1';
        end if;
        -- There is no point in making dway depend on whether there was a TLB hit.
        dway := dway or std_logic_vector(to_unsigned(i,2));
      end if;
      dvalidv(i) := dctagsv(i)(0);
    end loop;
    dvalid := dvalidv(to_integer(unsigned(dway)));
    -- Note: dhit is AND:ed with valid, but dhitv is _not_ AND:ed with validv
    -- If we miss due to valid bit being zero after a snoop hit we want
    -- r.d2hitv to be set to the way where we had the cache line, in order to
    -- avoid putting it in another way and getting two ways with idential tag.
    --   dhitv := dhitv and dvalidv;
    dhit := dhit and dvalid;

    -- Data TCM hit and muxing logic
    dtcmhit := '0';
    if dtcmen /= 0 then
      if r.d1tcmen='1' and tcmaddr_comp(r.d1vaddr(31 downto 16),r.dtcmaddr,dtcmen,dtcmabits)='1' then
        dtcmhit := '1';
        dhit := '1';
        dhitv := (others => '0');
        dway := "00";
        odco.data(0) := cramo.dtcmdout;
        if r.holdn='1' then
          if ( (dci.read='1' and r.d1su='0' and r.dtcmperm(0)='0') or
               (vdciwm='1' and r.d1su='0' and r.dtcmperm(1)='0') or
               (dci.read='1' and r.d1su='1' and r.dtcmperm(2)='0') or
               (vdciwm='1' and r.d1su='1' and r.dtcmperm(3)='0') ) then
            odco.mexc := '1';
          end if;
        end if;
      end if;
    end if;

    -- Register read logic
    if r.dregmux='1' then
      dway := "00";
      odco.data(0) := r.dregval;
      odco.mds := '0';
      odco.mexc := r.dregerr;
    end if;
    v.dregmux := '0';

    odco.way := dway;

    dspecialasi := r.d1specialasi;
    dforcemiss := r.d1forcemiss;
    if r.holdn='0' then
      dspecialasi := r.d2specialasi;
      dforcemiss := r.d2forcemiss;
    end if;

    -- Hit/miss checking logic (v.dmisspend,v.dflushpend,fastwr propagates to main FSM)
    -- Stage 2 DTLB update in case of hit
    if notx(r.d2vaddr) then
      dlruent := r.dlru(to_integer(unsigned(r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW))));
    else
      setx(dlruent);
    end if;
    if r.holdn='1' then
      vway := "00";
      vhit := '0';
      for x in r.d2hitv'range loop
        if r.d2hitv(x)='1' then
          vhit:='1';
          vway:=vway or to_unsigned(x,2);
        end if;
      end loop;
      if vhit='1' then
        v.dlru(to_integer(unsigned(r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW)))) := calc_lruent(dlruent,vway,DWAYS);
      end if;
    end if;
    -- Stage 1 tag check
    fastwr := '0';
    fastwr_wcomb := '0';
    dwriting := '0';
    v.d2tlbclr := '0';
    if r.holdn='1' then
      v.d2hitv := (others => '0');
      v.d2tlbhit := '0';
      v.d2tlbamatch := '0';
      v.d2write := '0';
      v.d2tcmhit := '0';
      v.d2atomic := '0';
    end if;

    -- On an initial DTLB miss, there is no correct cache/busw.
    --
    if r.d1pmp = '1' then
      v.d2nocache    := not dtlbcached;
      v.d2busw       := dtlbbusw;
    end if;

    if r.d1chk='1' and (r.dbgacc(1)='1' or r.holdn='1') then
      v.d2vaddr := r.d1vaddr;
      v.d2data := dci.edata;
      v.d2write := vdciwm and not dci.nullify;
      -- Avoid write phase of locked acc since we handle both on first cycle
      if dci.lock='1' then v.d2write := '0'; end if;
      if r.dbgacc(1)='1' then v.d2write := r.dbgaccwr; end if;
      v.d2atomic := dci_atomic;
      v.d2cas := dci.cas;
      v.d2casdata := dci.casdata;
      v.d2paddr := dtlbpaddr(v.d2paddr'range);
      v.d2paddrv := dtlbhit;
      v.d2tlbhit := dtlbhit;
      v.d2tlbclr := dtlbclr;
      v.d2tlbamatch := dtlbamatch;
      v.d2tlbid := dtlbid;
      v.d2tlbmod := dtlbmod;
      v.d2hitv := dhitv;
      v.d2validv := dvalidv;
      v.d2size := dci.size;
      v.d2busw := dtlbbusw;
      v.d2asi := r.d1asi;
      v.d2su := r.d1su;
      v.d2m := r.d1m;
      v.d2sum := r.d1sum;
      v.d2mxr := r.d1mxr;
      v.d2vmxr := r.d1vmxr;
      v.d2mode := r.d1mode;
      v.d2ctx := r.d1ctx;
      v.d2hx := r.d1hx;
      v.d2ss := r.d1ss;
      --
      v.d2specialasi := r.d1specialasi;
      v.d2forcemiss := r.d1forcemiss;
      v.d2nocache := not dtlbcached;
      v.d2specread := dci.specread;
      if r.dbgacc(1)='1' then v.d2specread := '0'; end if;
      v.d2tcmhit := dtcmhit;

      if is_riscv and pmp.valid = '1' and not daddr_ok then
        v.dfailkind := "1" & (r.d1m or not to_bit(mmu_enabled(r.d1mode)));
        v.dmisspend := '1';
      elsif is_riscv and pmp.valid = '1' and pmp_xc = '1' then
        v.dfailkind := "11";
        v.dmisspend := '1';
      else
        -- Do not do any of this if we fail on PMP!
        -- Set dcmiss pending bit for load cache miss
        if (dci.nullify='0' or r.dbgacc(1)='1') and not (dhit='1' and dforcemiss='0' and dspecialasi='0' and dci_atomic='0' and r.cbo.d1type(2) = '0') and ((dci.read='1' and r.cbo.d1type(2) = '0') or (r.dbgacc(1)='1' and r.dbgaccwr='0')
        or dci_atomic = '1' or r.cbo.d1type(2) = '1')
        then
          v.dmisspend := '1';
        end if;

        -- Hit/miss status signals
        if (dci.nullify = '0' or dci.dsuen = '1') then
          -- D-cache access
          v.perf(7) := '1';
          if dci.read = '1' and r.cbo.d1type(2) = '0' then
            -- D-cache read access
            v.perf(6) := '1';
            if (dhit = '1' and dforcemiss = '0' and dspecialasi = '0' and dci.lock = '0') then
              -- D-cache read hit
              v.perf(5) := '1';
            end if;
          end if;
          if dci.write = '1' and r.cbo.d1type(2) = '0' then
            -- D-cache write access
            v.perf(9) := '1';
            if (dhit = '1' and dspecialasi = '0' and r.amo.d1type(5) = '0') then
              -- D-cache write hit
              v.perf(8) := '1';
            end if;
          end if;
        end if;
        --

        -- Cache update for writes
        --   generate ocrami.ddatawrite independently of dci.nullify to avoid
        --     nullify -> ddatawrite -> ddatain path via data loopback
        if ((dci.nullify='0' and vdciwm='1') or r.dbgaccwr='1') and r.d1ten='1' and r.d1specialasi='0' and
           r.amo.d1type(5) = '0' and r.cbo.d1type(2) = '0' then
          ocrami.ddataen(0 to DWAYS-1) := dhitv;
          -- moved to separate if-statement below:
          --   dwriting := '1';
          --   ocrami.ddatawrite := getdmask64(r.d1vaddr,dci.size,(endian='1'));
        end if;
        if dci.nullify='0' and r.d1tcmen='1' and vdciwm='1' and r.d1specialasi='0' and r.cbo.d1type(2) = '0' then
          ocrami.dtcmen := dtcmhit;
        end if;
        if (r.d1ten='1' or r.d1tcmen='1') and (vdciwm='1' or r.dbgaccwr='1') and r.d1specialasi='0' and
           r.amo.d1type(5) = '0' and r.cbo.d1type(2) = '0' then
          dwriting := '1';
          ocrami.ddatawrite := getdmask64(r.d1vaddr,dci.size,(endian='1'));
        end if;
        -- Store buffer update for writes
        if dci.nullify='0' and vdciwm='1' and dtcmhit='0' and r.cbo.d1type(2) = '0' then
          dbg(1) <= '1';
          if v.d2paddrv='1' and v.d2tlbmod='1' and
            dspecialasi='0' and dci.lock=r.biflocked then
            -- Fast write path (TLB hit, written set in PTE, wide bus, store buffer
            -- idle, and standard ASIs)
            fastwr := '1';
            if v.d2size="11" and (r_cctrl.wcomben='1' or r.dwchint='1') then
              fastwr_wcomb := '1';
            end if;
          else
            -- Slow write path (TLB miss, written not set in PTE, narrow bus, store buffer
            -- busy, or special ASI)
            dbg(2) <= '1';
            v.slowwrpend := '1';
          end if;
        end if;

      end if;
      if ddblhit='1' then
        v.ctrappend(1) := '1';
      end if;
    end if;

    -- We need to check data PMP here if the TLB was just rechecked.
    if is_riscv and r.holdn = '0' and r.dtlbbypass = '1' and r.d1ten = '1' and pmp.valid = '1' then
      if pmp_xc = '1' then
        v.dfailkind := "11";
        v.dmisspend := '1';
      end if;
    end if;
    --

    obifi.busaddr(v.d2paddr'range) := v.d2paddr;
    obifi.widebus := v.d2busw;
    obifi.size := v.d2size;
    obifi.stdata := v.d2data;
    obifi.nosnoop := not v.d2nocache;
    obifi.su := v.d2su;

    -- Stage 0 address to tag ram
    dtenall := ((r.holdn and dci.eenaddr) or (r.ramreload and r.d1chk));
    if dtenall='1' and r_cctrl.dcs(0)='1' then
      ocrami.dtagcen := (others => '1');
      if dwriting = '0' then
        ocrami.ddataen := (others => '1');
      end if;
    end if;
    dtcmact := '0';
   if arch = SPARC then
    if r.dtcmenp='1' and r.mmctrl1.e='0' then dtcmact := '1'; end if;
    if r.dtcmenva='1' and r.mmctrl1.e='1' then dtcmact := '1'; end if;
    if r.dtcmenvc='1' and r.mmctrl1.e='1' and r.mmctrl1.ctx=r.dtcmctx then dtcmact:='1'; end if;
   end if;
    if dtenall='1' and dtcmact='1' and dwriting='0' then
      ocrami.dtcmen := '1';
    end if;

    -- force re-read in case of snoop hit to ensure updated valid bits propagate
    if dtagconf=0 then ocrami.dtagcen(0 to DWAYS-1) := ocrami.dtagcen(0 to DWAYS-1) or bifo.dtu.upd(0 to DWAYS-1); end if;
    if r.holdn='1' then
      v.d1ten := dci.eenaddr and r_cctrl.dcs(0);
      v.d1tcmen := dci.eenaddr and dtcmact;
      v.d1chk := dci.eenaddr;
      v.d1vaddr := dci.eaddress(v.d1vaddr'range);
      v.d1asi := dci.easi;
      v.d1su := v.d1asi(0);
      v.d1forcemiss := '0';
      v.d1specialasi := '0';
      if v.d1asi(7 downto 1)="0000000" then
        v.d1forcemiss := '1';
        v.d1su:='1';
      elsif v.d1asi(4 downto 0)/=ASI_UDATA and v.d1asi(4 downto 0)/=ASI_SDATA then
        v.d1specialasi := '1';
      end if;
      v.d1m     := '0';
      v.d1sum   := '0';
      v.d1mxr   := '0';
      v.d1vmxr  := '0';
      v.d1hx    := '0';
      v.d1ss    := '0';
      v.d1mode  := (others => '0');
      v.d1ctx   := (others => '0');
      if arch = RISCV then
        v.d1sum   := dci.sum;
        v.d1mxr   := dci.mxr;
        v.d1vmxr  := dci.vmxr;
        if ext_h = 1 then
          v.d1hx  := dci.hx;
        end if;
        if ext_zicfiss = 1 then
          v.d1ss  := dci.ss;
        end if;
        v.d1m     := dci.vms(1);
        v.d1su    := dci.vms(0);
        v.d1mode  := get_mode(csro, dci.vms);
        v.d1ctx   := mmu_ctx(csro, v.d1mode);
      end if;

    end if;

    -- Flushing from IU
    if r.holdn='1' and dci.flush='1' then
      v.iflushpend := '1';
      v.dflushpend := '1';
    end if;

    if arch = RISCV then
      if r.holdn = '1' then
        if ici.flush = '1' then
          v.iflushpend := '1';
        end if;
        if csro.cctrl.iflush = '1' then
          v.iflushpend := '1';
        end if;
        if csro.cctrl.dflush = '1' then
          v.dflushpend := '1';
        end if;
        if csro.cctrl.itcmwipe = '1' then
          v.itcmwipe := '1';
        end if;
        if csro.cctrl.dtcmwipe = '1' then
          v.dtcmwipe := '1';
        end if;
      end if;
    end if;


    --------------------------------------------------------------------------
    -- CBO operations
    --------------------------------------------------------------------------
    if arch = RISCV and ext_zicbom /= 0 then
      if r.holdn = '1' then
        if dci.eenaddr = '1' then
          v.cbo.d1type := dci.cbo;
        else
          v.cbo.d1type := (others => '0');
        end if;
        v.cbo.d2type(2)           := r.cbo.d1type(2) and (not dci.nullify);
        v.cbo.d2type(1 downto 0)  := r.cbo.d1type(1 downto 0);
      end if;
    end if;

    --------------------------------------------------------------------------
    -- Atomic operations
    --------------------------------------------------------------------------
    amo_snoop := '0';
    if arch = RISCV and ext_a /= 0 then

      if r.holdn = '1' then
        if dci.eenaddr = '1' then
          v.amo.d1type := dci.amo;
        else
          v.amo.d1type := (others => '0');
        end if;
        v.amo.d2type(5)           := r.amo.d1type(5) and (not dci.nullify);
        v.amo.d2type(4 downto 0)  := r.amo.d1type(4 downto 0);

      end if;

      -- AMO data
      amo_op   := (r.d2size(1) and r.d2size(0)) & r.amo.d2type(4 downto 2);
      amo_src1 := r.d2data;
      amo_src2 := r.amo.data;
      if r.d2size = "10" then
        if r.d2vaddr(2) = '1' then
          amo_src2(31 downto 0) := amo_src2(63 downto 32);
        end if;
        amo_src1(63 downto 32)  := (others => amo_src1(31));
        amo_src2(63 downto 32)  := (others => amo_src2(31));
      end if;
      if r.amo.d2type(5) = '1' and r.amo.d2type(1 downto 0) = "00" then
        amo_data := amo_math_op(amo_src1, amo_src2, amo_op);
      else
        amo_data := r.d2data;
      end if;

      -- Data need to be replicated
      if r.d2size = "10" then
        amo_data(63 downto 32) := lo_h(amo_data);
      end if;
    end if;

    --------------------------------------------------------------------------
    -- DCache AHB snooping and Dtag write port pipeline
    --------------------------------------------------------------------------
    ocrami.dtaguwrite := bifo.dtu.upd;
    ocrami.dtaguindex := bifo.dtu.uidx;
    for w in 0 to 3 loop
      ocrami.dtagudin(w)(DTAG_HIGH-DTAG_LOW-1 downto 0) :=
        bifo.dtu.uval(DTAG_HIGH-DTAG_LOW-1 downto 0);
      ocrami.dtagudin(w)(DTAG_HIGH-DTAG_LOW+1 downto DTAG_HIGH-DTAG_LOW) :=
        bifo.dtu.umsb(2*w+1 downto 2*w);
    end loop;

    -- Set/clear valid bits in flip flops when tag is updated
    vbitset := (others => (others => '0'));
    vbitclr := (others => (others => '0'));

    vvalididx := ocrami.dtaguindex(DOFFSET_HIGH-DOFFSET_LOW downto 0);
    for w in DWAYS-1 downto 0 loop
      if ocrami.dtaguwrite(w)='1' then
        if ocrami.dtagudin(w)(0)='1' then
          vbitset(to_integer(unsigned(vvalididx)))(w) := '1';
        else
          vbitclr(to_integer(unsigned(vvalididx)))(w) := '1';
        end if;
      end if;
    end loop;


    --------------------------------------------------------------------------
    -- MMU TLB update logic
    --------------------------------------------------------------------------
    -- TLB update
    if r.i2tlbclr='1' then
      v.itlb(to_integer(unsigned(r.i2tlbid))).valid := '0';
    end if;
    if r.d2tlbclr='1' then
      v.dtlb(to_integer(unsigned(r.d2tlbid))).valid := '0';
    end if;
    if r.h2tlbclr = '1' then
      v.htlb(u2i(r.h2tlbid)).valid := '0';
    end if;
    if arch = SPARC then
      if r.tlbupdate='1' then
        if r.mmusel(0)='0' and r.i2tlbhit='1' then
          v.itlb(to_integer(unsigned(r.i2tlbid))) := r.newent;
        end if;
        if r.mmusel(0)='1' and r.d2tlbhit='1' then
          v.dtlb(to_integer(unsigned(r.d2tlbid))) := r.newent;
        end if;
      end if;
    else -- arch = RISCV
      if r.tlbupdate = '1' then
        if is_access_i(r.mmusel) and r.i2tlbhit = '1' then
          v.itlb(u2i(r.i2tlbid))     := tlbent_mask(r.newent, is_sv_smaller(csro, r.newent.mode));
        end if;
        if not is_access_i(r.mmusel) and r.d2tlbhit = '1' then
          v.dtlb(u2i(r.d2tlbid))     := tlbent_mask(r.newent, is_sv_smaller(csro, r.newent.mode));
        end if;
      end if;
      if r.h2tlbupd = '1' then
        v.htlb(u2i(r.h2tlbid))       := tlbent_mask(r.hnewent, is_svx4_smaller(csro));
      end if;
    end if;
    v.h2tlbupd  := '0';
    v.tlbupdate := '0';

    -- On RISC-V, it is not as simple as the MMU being enabled or not.
    -- Even when it is otherwise in use, machine mode will (normally)
    -- still be using physical addresses.

    -- Set default 1:1 mapping if MMU disabled
    if arch = SPARC and r.mmctrl1.e='0' then
      v.dtlb(0) := tlbent_defmap;
      v.itlb(0) := tlbent_defmap;
    end if;
    -- Clear valid bits on flush or TLB disable
    if r.tlbflush='1' or (arch = SPARC and r.mmctrl1.e='0') then
      for x in 0 to dtlbnum-1 loop
        v.dtlb(x).valid := '0';
      end loop;
      for x in 0 to itlbnum-1 loop
        v.itlb(x).valid := '0';
      end loop;
    end if;
    if is_riscv and ext_h = 1 and r.htlbflush = '1' then
      for x in v.htlb'range loop
        v.htlb(x).valid := '0';
      end loop;
    end if;
    v.htlbflush := '0';
    v.tlbflush := '0';

    -- Generate decoded accesses permissions for each TLB entry
    if arch = SPARC then
      for x in 0 to dtlbnum-1 loop
        vtmp3 := ft_acc_resolve("000", v.dtlb(x).acc);
        v.dtlb(x).perm(0) := not vtmp3(1);
        vtmp3 := ft_acc_resolve("100", v.dtlb(x).acc);
        v.dtlb(x).perm(1) := not vtmp3(1);
        vtmp3 := ft_acc_resolve("001", v.dtlb(x).acc);
        v.dtlb(x).perm(2) := not vtmp3(1);
        vtmp3 := ft_acc_resolve("101", v.dtlb(x).acc);
        v.dtlb(x).perm(3) := not vtmp3(1);
      end loop;
      for x in 0 to itlbnum-1 loop
        vtmp3 := ft_acc_resolve("010", v.itlb(x).acc);
        v.itlb(x).perm(0) := not vtmp3(1);
        v.itlb(x).perm(1) := '0';
        vtmp3 := ft_acc_resolve("011", v.itlb(x).acc);
        v.itlb(x).perm(2) := not vtmp3(1);
        v.itlb(x).perm(3) := '0';
      end loop;
    end if;

    -- Set pseudo-MRU bit for touched entry
    if r.d2tlbhit='1' and r.holdn='1' and r.d2specialasi='0' then
      v.dtlbpmru(to_integer(unsigned(r.d2tlbid))) := '1';
    end if;
    if r.i2tlbhit='1' and r.holdn='1' then
      v.itlbpmru(to_integer(unsigned(r.i2tlbid))) := '1';
    end if;
    if r.h2tlbupd = '1' then
      v.htlbpmru(u2i(r.h2tlbid)) := '1';
    end if;
    -- Reset pseudo-MRU once all bits set
    --   single-cycle window where all are set need to be handled
    if r.dtlbpmru=(r.dtlbpmru'range => '1') then
      v.dtlbpmru := (others => '0');
    end if;
    if r.itlbpmru=(r.itlbpmru'range => '1') then
      v.itlbpmru := (others => '0');
    end if;
    if all_1(r.htlbpmru) then
      v.htlbpmru := (others => '0');
    end if;
    -- Clear pseudo-MRU bits for TLB entries that are not valid
    --  (using v.valid to avoid single-cycle window)
    for x in 0 to dtlbnum-1 loop
      if v.dtlb(x).valid='0' then v.dtlbpmru(x) := '0'; end if;
    end loop;
    for x in 0 to itlbnum-1 loop
      if v.itlb(x).valid='0' then v.itlbpmru(x) := '0'; end if;
    end loop;
    for x in v.htlb'range loop
      if v.htlb(x).valid = '0' then
        v.htlbpmru(x) := '0';
      end if;
    end loop;

    -- MMU fault status register handling
    if arch = SPARC and r.mmuerr.fav='1' then
      if r.mmfsr.fav='0' or unsigned(r.newerrclass) > unsigned(r.curerrclass) then
        v.mmfsr := r.mmuerr;
        v.mmfar := r.newent.vaddr;
        v.curerrclass := r.newerrclass;
      elsif r.mmfsr.fav='1' and r.newerrclass=r.curerrclass then
        -- overwrite with the new error and set overwrite flag
        v.mmfsr := r.mmuerr;
        v.mmfar := r.newent.vaddr;
        v.mmfsr.ow := '1';
      end if;
    end if;
    v.mmuerr.ow := '0';
    v.mmuerr.ebe := (others => '0');



    ---------------------------------------------------------------------------
    -- Region flush
    ---------------------------------------------------------------------------

    v.regflpipe(0 to r.regflpipe'high-1) := r.regflpipe(1 to r.regflpipe'high);
    v.regflpipe(r.regflpipe'high).valid := '0';
    v.regflpipe(r.regflpipe'high).addr := r.flushctr;

    -- Stage 4: Write back commit
    --   inside SRAMs
    -- Stage 3: Command write back in case of match
    --  handled in FSM
    -- Stage 2: Compare with region flush mask
    v.regflpipe(0) := r.regflpipe(1);
    frdmatch := (others => '0');
    for x in 0 to DWAYS-1 loop
      if ( (r.dtagpipe(x)(DTAG_HIGH-DTAG_LOW+1 downto 1) and r.regflmask(DTAG_HIGH downto DTAG_LOW))
           = r.regfladdr(DTAG_HIGH downto DTAG_LOW) ) then
        frdmatch(x) := '1';
      end if;
    end loop;
    v.flushwrd := frdmatch;
    frimatch := (others => '0');
    for x in 0 to IWAYS-1 loop
      if ( (r.itagpipe(x)(ITAG_HIGH-ITAG_LOW+1 downto 1) and r.regflmask(ITAG_HIGH downto ITAG_LOW))
           = r.regfladdr(ITAG_HIGH downto ITAG_LOW) ) then
        frimatch(x) := '1';
      end if;
    end loop;
    v.flushwri := frimatch;
    -- compute unique msb:s for the tags we are replacing to avoid duplicate tags
    for x in 0 to DWAYS-1 loop
      frmsbd(2*x+1 downto 2*x) := r.dtagpipe(x)(DTAG_HIGH-DTAG_LOW+1 downto DTAG_HIGH-DTAG_LOW);
    end loop;
    v.untagd := uniquemsb(frmsbd, frdmatch);
    for x in 0 to IWAYS-1 loop
      frmsbi(2*x+1 downto 2*x) := r.itagpipe(x)(ITAG_HIGH-ITAG_LOW+1 downto ITAG_HIGH-ITAG_LOW);
    end loop;
    v.untagi := uniquemsb(frmsbi, frimatch);

    -- Stage 1: Capture tags
    v.regflpipe(1) := r.regflpipe(2);
    v.dtagpipe := dctagsv;
    v.itagpipe := cramo.itagdout;

    -- Stage 0: Read from tag RAMs, done in main FSM

    htlbchk := tlbcheck_none;
    v.h2tlbclr := '0';
    v.h_do := '0';
    if arch = RISCV then
      if actual_tlb_pmp then
        pmp_mmuu(csro.precalc(0 to pmp_entries - 1),
                 csro.pmpcfg, csro.mml,
                 r.pmp_low, r.pmp_mask, r.pmp_do,
                 pmp_hit, pmp_fit, pmp_l, pmp_r, pmp_w, pmp_x,
                 pmp_msb, ext_smepmp);

        -- Keep only the lowest numbered hit, since that is
        -- defined as the highest priority PMP.
        pmp_prio := pmp_hit and std_logic_vector(-signed(pmp_hit));

        if pmaen then
          if pma_masked = 0 then
            pma_mmuu(csro.pma_precalc, r.pmp_low, r.pmp_mask, r.pmp_do,
                     pma_hit, pma_fit,
                     pmp_msb);

            v.pma_hitv := pma_hit;  -- For diagnostics
            v.pma_fitv := pma_fit;  -- For diagnostics

            -- Keep only the lowest numbered hit, since that is
            -- defined as the highest priority PMA.
            pma_prio := pma_hit and std_logic_vector(-signed(pma_hit));

            --pma_idx     := uext(clz(uext(reverse(pma_hit), 16)), v.pma_idx);
            pma_idx     := fit0ext(clz(reverse(uext(pma_hit, PMAENTRIES))), pma_idx);

            pma := to_pma(csro.pma_data(u2i(pma_idx)));
          else
            pma_masks(csro.pma_data, r.pmp_low, r.pmp_do,
                      pma, pma_fit,
                      pmp_msb);
            -- In the Sv32 case, the first level page table covers bits 31:22, so
            -- with masks at 31:28 (only supported case) there will always be a fit.
            if riscv_mmu = Sv32 then
              pma_fit := (others => '1');
            end if;
            -- Two smallest page sizes will fit for Sv39/Sv48 (never a problem for Sv32).
            if (riscv_mmu = sv39 or riscv_mmu = sv48) then
              -- v2 v1 v0 low
              -- 1's where replacing
              -- 4k replace v2/1/0, 2M replace v2/1, 1G replace v2
              --           >       <
              -- 111  1111  11, 1 1  111 1  111, 1  1111  1111  xxxx xxxx xxxx  4k
              -- 111  1111  11, 1 1  111 1  111, 0  0000  0000  xxxx xxxx xxxx  2M
              -- 111  1111  11, 0 0  000 0  000, 0  0000  0000  xxxx xxxx xxxx  1G
              --
              -- if get_left(get_right(r.pmp_low, 32), 4) /=
              --    get_left(get_right(r.pmp_low or not r.pmp_mask, 32), 4) then
              if get_left(get_right(r.pmp_low, 32), 2) /=
                 get_left(get_right(r.pmp_low or not r.pmp_mask, 32), 2) then
                pma_fit := (others => '0');
              end if;
            end if;
            pma_hit   := (others => '1');
            pma_prio  := (others => '1');
            pma_idx   := (others => '0');

            v.pma_hitv := pma_hit;  -- For diagnostics
            v.pma_fitv := pma_fit;  -- For diagnostics
          end if;
        end if;


        -- Hit but not fit means a smaller MMU page size must be tried!

        if r.pmp_do = '1' then
          v.pmp_hitv := pmp_hit;  -- For diagnostics
          v.pmp_fitv := pmp_fit;  -- For diagnostics
          if pmp_mmuu_test = 1 then
          -- v.pmp_idx := uext(clz(uext(reverse(pmp_hit), 16)), v.pmp_idx);
            v.pmp_idx := uext(clz(reverse(uext(pmp_hit, PMPENTRIES))), v.pmp_idx);
          end if;
          v.pmp_hit := not all_0(pmp_hit);
          v.pmp_fit := not all_0(pmp_prio and pmp_fit);
          v.pmp_rwx(2) := not all_0(pmp_r and pmp_prio);
          v.pmp_rwx(1) := not all_0(pmp_w and pmp_prio);
          v.pmp_rwx(0) := not all_0(pmp_x and pmp_prio);
          v.pmp_none   := not v.pmp_hit;
          v.pmp_lock   := not all_0(pmp_l and pmp_prio);


          -- Calculate current [SME]PMP access rights

          v.pmp_m_rwx(2)  := to_bit(smepmp_ok_r(ext_smepmp, csro.mmwp, csro.mml, PRIV_LVL_M,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));
          v.pmp_m_rwx(1)  := to_bit(smepmp_ok_w(ext_smepmp, csro.mmwp, csro.mml, PRIV_LVL_M,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));
          v.pmp_m_rwx(0)  := to_bit(smepmp_ok_x(ext_smepmp, csro.mmwp, csro.mml, PRIV_LVL_M,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));

          -- The mode here is non-M (U vs S makes no difference for PMP)
          v.pmp_su_rwx(2) := to_bit(smepmp_ok_r(ext_smepmp, csro.mmwp, csro.mml, PRIV_LVL_S,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));
          v.pmp_su_rwx(1) := to_bit(smepmp_ok_w(ext_smepmp, csro.mmwp, csro.mml, PRIV_LVL_S,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));
          v.pmp_su_rwx(0) := to_bit(smepmp_ok_x(ext_smepmp, csro.mmwp, csro.mml, PRIV_LVL_S,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));

          -- Fault masking
          if (    is_access_i(r.mmusel) and addr_check_mask(3) = '0') or    -- Instruction fetch?
             (not is_access_i(r.mmusel) and addr_check_mask(7) = '0') then  -- Data read/write?
            pmp_hit      := (others => '1');
            v.pmp_hit    := '1';
            v.pmp_fit    := '1';
            v.pmp_rwx    := "111";
            v.pmp_m_rwx  := "111";
            v.pmp_su_rwx := "111";
          end if;

          -- Ensure no hit if physical top address bits are wrong
          if not physical_ok(r.pmp_low) and addr_check_mask(1) = '1' then
            pmp_hit      := (others => '0');
            v.pmp_hit    := '0';
            v.pmp_fit    := '0';
            v.pmp_rwx    := "000";
            if pmaen then
              pma_hit    := (others => '0');
            end if;
          end if;

          if pmaen then

            if pma_forced_fault(csro, r.pmp_low) then
              pma.valid := '0';
            end if;

            if pma_valid(pma) then
              v.pma     := pma;
            else
              v.pma     := pma_unused;
            end if;

            if pma_mmuu_test = 1 then
              v.pma_hit := not all_0(pma_hit);
              v.pma_fit := not all_0(pma_prio and pma_fit);
              v.pma_idx := pma_idx;
            end if;


            -- Combine with current PMA
            -- PMP test (pmp_mmuu_test) can bypass this
            -- No need to update v.pma* here
            if r.pmp_only = '0' then
              v.pmp_m_rwx    := v.pmp_m_rwx  and pma_rwx(pma);
              v.pmp_su_rwx   := v.pmp_su_rwx and pma_rwx(pma);
              if v.pma_hit = '0' or v.pma_fit = '0' or not pma_valid(pma) then
                v.pmp_rwx    := "000";
                v.pmp_m_rwx  := "000";
                v.pmp_su_rwx := "000";
              end if;
              if v.pma_hit = '0' or v.pma_fit = '0' then
                v.pmp_fit    := '0';
              end if;
              if v.pma_hit = '0' then
                v.pmp_hit    := '0';
              end if;
            end if;

          end if;
        end if;

        -- No hit means failure in non-machine mode, if there are implemented entries.
      end if;

      -- First level page table accessibility
      v.pmp_low               := (others => '0');
      v.pmp_mask              := (others => '0');
      v.pmp_do                := '0';
      v.pmp_m                 := '0';  -- Default to not checking for M mode permissions
      v.pmp_only              := '0';  -- Default to combining PMA into PMP information
      if is_riscv and actual_tlb_pmp then
        v.pmp_mask(ppn'range) := (others => '1');
      end if;

      if ext_h = 1 and r.h_do = '1' then
        tlb_lookup('1' & r.h_x, r.htlb, true, r.h_addr_repl, r.h_addr, r.h_ctx_repl, '0', r.h_ls,
                   r.h_do, '0', '0', '0',
                   htlbchk, '0', r.h_mxr, r.h_vmxr, r.h_hx, "010", is_svx4_smaller(csro),
                   '0', '0',
                   true
                   );
        -- Hitting TLB when writing to a page that has formerly only seen reads?
        -- Only option then is to fake a miss, invalidate and do a new hPT walk.
        if htlbchk.hit = '1' and htlbchk.modded = '0' and r.h_ls = '1' then
          htlbchk.hit    := '0';
          htlbchk.amatch := '0';
          htlbchk.clr    := '1';
        end if;
        -- These may be needed later.
        v.h_w        := htlbchk.h_w;
        v.h_pmp_no_w := htlbchk.h_pmp_no_w;
        v.h_pmp_no_x := htlbchk.h_pmp_no_x;
        v.h2tlbclr   := htlbchk.clr;
        v.h2tlbid    := htlbchk.id(v.h2tlbid'range);
      end if;
    end if;


    --------------------------------------------------------------------------
    -- Main cache controller state machine
    --------------------------------------------------------------------------

    -- Read data from 32/64 bit single reads
    rdb32 := (others => '0');
    rdb32v := '0';
    rdb64 := (others => '0');
    rdb64v := '0';
    if arch = SPARC or pte_hsize = HSIZE_WORD then
      for x in bifo.rdb.bufv'range loop
        if bifo.rdb.bufv(x)='1' then
          rdb32v := '1';
          rdb32 := rdb32 or bifo.rdb.buf(x*32+31 downto x*32);
        end if;
      end loop;
    else
      for x in bifo.rdb.bufv'length/2-1 downto 0 loop
        if bifo.rdb.bufv(x*2+1 downto x*2)="11" then
          rdb32v := '1';
          rdb64v := '1';
          rdb64 := rdb64 or bifo.rdb.buf(x*64+63 downto x*64);
        end if;
      end loop;
    end if;

    -- Speculative load handling
    if r.dmisspend='1' and r.d2specread='1' then
      if dci.specreadannul='1' then
        v.dmisspend := '0';
        v.dfailkind  := "00";
      else
        v.d2specread := '0';
      end if;
    end if;

    -- Memory barrier
    if dci.bar(1 downto 0) /= "00" and r.holdn='1' then
      -- For now, the store/load barrier is implemented as a full synchronizing
      -- barrier for simplicity. This case may be optimized later.
      v.syncbar := '1';
    end if;
    -- write combining hint
    if dci.bar(2)/='0' and r.holdn='1' then
      v.dwchint := '1';
    end if;
   if arch = SPARC then
    if r.holdn='1' and dci.trapack='1' then
      -- drop write hint on trap
      v.dwchint := '0';
    end if;
   end if;
    if r_cctrl.wchinten='0' then
      v.dwchint := '0';
    end if;

    v.newent.valid := '1';
    if arch = RISCV and ext_h = 1 then
      v.hnewent.valid   := '1';
    end if;
    v.dtlbbypass := '0';
    v.fpc_mosi.accen := '0';
    v.fpc_mosi.accwr := '0';
    v.fpc_mosi.addr(v.fpc_mosi.addr'high downto 1) := r.d2vaddr(v.fpc_mosi.addr'high+2 downto 3);
    v.c2c_mosi.accen := '0';
    v.c2c_mosi.accwr := '0';
    v.c2c_mosi.addr(v.fpc_mosi.addr'high downto 1) := r.d2vaddr(v.fpc_mosi.addr'high+2 downto 3);
    v.iudiag_mosi.accen := '0';
    v.iudiag_mosi.accwr := '0';
    v.iudiag_mosi.addr(v.fpc_mosi.addr'high downto 1) := r.d2vaddr(v.fpc_mosi.addr'high+2 downto 3);
    v.ctxswitch := '0';
    vstd32 := (others => '0');
    vstoresu := v.d2su;
    v.fsmidle := '0';
    vtoglock := '0';
    vdlyop := '0';
    case r.s is
      when as_normal =>
        v.ramreload := '0';
        obifi.clrrdbuf := '1';
        obifi.wcomb := fastwr_wcomb;
        v.mmusel := "0000";
        v.flushctr := (others => '0');
        v.flushpart := v.iflushpend & v.dflushpend;
        v.dtflushdone := '0';
        v.regfldone := '0';
        v.iramaddr := (others => '0');
        v.irdbufen := '0';
        v.dramaddr := (others => '0');
        v.dvtagdone := '0';
        v.dregerr := '0';
        v.newent.mask := (others => '0');
        v.d2nb64en := '0';
        v.d2nb64ctr := '0';
        v.d2stbcont := '0';
        v.d2wchold := "000";
        v.stbuffull := '0';
        if r.biflocked='1' then
          vtoglock := '1';
        elsif fastwr='1' then
          obifi.bifop := BIFOP_STORE;
          v.bifwait_op := BIFOP_STORE;
          v.bifwait_wc := fastwr_wcomb;
          if bifo.stat.ready='0' then
            v.stbuffull := '1';
            v.s := as_bifwait;
          end if;
          v.dwchint := '0';
        elsif ( ((not IMISSPIPE) and v.iflushpend='1') or (IMISSPIPE and r.iflushpend='1') or
                ((not DMISSPIPE) and v.dflushpend='1') or (DMISSPIPE and r.dflushpend='1') ) then
          if r.iregflush='1' or r.dregflush='1' then
            v.s := as_regflush;
            v.flushpart := r.iregflush & r.dregflush;
            v.flushctr := r.regfladdr(MAXOFFSET_HIGH downto MAXOFFSET_LOW) and
                          r.regflmask(MAXOFFSET_HIGH downto MAXOFFSET_LOW);
          else
            v.s := as_flush;
          end if;
          v.perf(4) := '1';
        elsif ((not IMISSPIPE) and v.imisspend='1') or (IMISSPIPE and r.imisspend='1') then
          obifi.busaddr(v.i2paddr'range) := v.i2paddr;
          obifi.busaddr(ILINE_HIGH downto 0) := (others => '0');
          obifi.widebus := v.i2busw;
          v.mmusel := "0000";
          -- Fault on (non-TLB) PMP/PMA or high bits?
          if arch = RISCV and v.ifailkind(1) = '1' then
            v.s           := as_rv_ifailkind;
          elsif v.i2paddrv='1' then
            obifi.bifop := BIFOP_ILFET;
            v.bifwait_op := BIFOP_ILFET;
            v.s := as_icfetch;
            v.perf(0) := '1';
          else
            if arch = SPARC then
              v.s := as_mmuwalk;
              obifi.bifop := BIFOP_SMFET;
              v.bifwait_op := BIFOP_SMFET;
              obifi.size := "10";
              obifi.widebus := '0';
              obifi.mmuacc := '1';
              v.mmuaddr(31 downto 0) := r.mmctrl1.ctxp(25 downto 4) & v.i2ctx & "00";
              obifi.busaddr := (others => '0');
              obifi.busaddr(31 downto 0) := v.mmuaddr(31 downto 0);
              v.perf(1) := '1';
            else -- arch = RISCV
              if mmuen = 1 or walk_pmp then
                if walk_pmp and not mmu_enabled(v.i2mode) then
                  start_pmp     := true;   -- See more after case.
                else
                  start_walk := true;
                  v.perf(1) := '1';
                end if;
              end if;
            end if;
          end if;
        elsif (((not DMISSPIPE) and v.dmisspend='1') or (DMISSPIPE and r.dmisspend='1')) and v.d2specread='0' then
          v.mmusel := "0001";
          -- Fault on (non-TLB) PMP/PMA or high bits?
          if is_riscv and v.dfailkind(1) = '1' then
            v.s := as_rv_dfailkind;
          elsif v.d2paddrv='1' and dspecialasi='0' and not (v.d2atomic='1' and v.d2tlbmod='0' and
                                                            (arch /= RISCV or v.amo.d2type /= "100010")) then
            if v.d2atomic='1' then
              v.s := as_atomic1;
            elsif v.cbo.d2type(2) = '1' then
              v.s := as_rv_cbo;
            elsif v.d2nocache='0' then
              obifi.bifop := BIFOP_DLFET;
              v.bifwait_op := BIFOP_DLFET;
              v.s := as_dcfetch;
              v.perf(2) := '1';
            else
              v.s := as_dcsingle;
              obifi.bifop := BIFOP_SMFET;
              v.bifwait_op := BIFOP_SMFET;
            end if;
          elsif dspecialasi='0' then
            if arch = SPARC then
              v.s := as_mmuwalk;
              obifi.bifop := BIFOP_SMFET;
              v.bifwait_op := BIFOP_SMFET;
              obifi.size := "10";
              obifi.widebus := '0';
              obifi.mmuacc := '1';
              v.mmuaddr(31 downto 0) := r.mmctrl1.ctxp(25 downto 4) & r.mmctrl1.ctx & "00";
              obifi.busaddr := (others => '0');
              obifi.busaddr(31 downto 0) := v.mmuaddr(31 downto 0);
              v.perf(3) := '1';
            else -- arch = RISCV
              if (mmuen = 1 or walk_pmp)then
                if walk_pmp and not mmu_enabled(v.d2mode) then
                  start_pmp     := true;   -- See more after case.
                else
                  start_walk := true;
                  v.perf(3) := '1';
                end if;
              end if;
            end if;
          elsif arch = SPARC or ext_noelv = 1 then
            v.s := as_rdasi;
          end if;
        elsif v.slowwrpend='1' then
          v.s := as_slowwr;
        elsif v.syncbar='1' then
          if bifo.stat.idle='1' then
            v.syncbar := '0';
            if r.d1chk='1' then v.ramreload := '1'; end if;
          end if;
        else
          v.fsmidle := '1';
          if ici.parkreq='1' then
            v.s := as_parked;
          end if;
        end if;

      when as_flush =>
        if r.flushpart(1)='1' then
          v.ilru := (others => (others => '0'));
          v.i1cont := '0';
        end if;
        if r.flushpart(0)='1' then
          v.dlru := (others => (others => '0'));
        end if;
        if bifo.stat.ready='1' then
          if IOFFSET_LOW > DOFFSET_LOW and r.flushpart(0)='0' then
            v.flushctr(MAXOFFSET_HIGH downto IOFFSET_LOW) := add(r.flushctr(MAXOFFSET_HIGH downto IOFFSET_LOW),1);
          elsif DOFFSET_LOW > IOFFSET_LOW and r.flushpart(1)='0' then
            v.flushctr(MAXOFFSET_HIGH downto DOFFSET_LOW) := add(r.flushctr(MAXOFFSET_HIGH downto DOFFSET_LOW),1);
          else
            v.flushctr(MAXOFFSET_HIGH downto MAXOFFSET_LOW) := add(r.flushctr(MAXOFFSET_HIGH downto MAXOFFSET_LOW),1);
          end if;
          if r.flushpart(1)='1' and v.flushctr(IOFFSET_HIGH downto MAXOFFSET_LOW)=zerov(IOFFSET_HIGH downto MAXOFFSET_LOW) then
            v.flushpart(1) := '0';
            v.iflushpend := '0';
          end if;
          if r.flushpart(0)='1' and v.flushctr(DOFFSET_HIGH downto MAXOFFSET_LOW)=zerov(DOFFSET_HIGH downto MAXOFFSET_LOW) then
            v.dtflushdone := '1';
          end if;
        end if;
        if r.flushpart(0)='1' and r.dtflushdone='1' and bifo.dtu.utype(0)='0' then
          v.flushpart(0) := '0';
          v.dflushpend := '0';
        end if;
        if v.flushpart="00" then
          v.ramreload := '1';
          v.s := as_normal;
        end if;
        ocrami.iindex := (others => '0');
        ocrami.iindex(IOFFSET_BITS-1 downto 0) :=
          r.flushctr(IOFFSET_HIGH downto IOFFSET_LOW);
        ocrami.idataoffs := (others => '0');
        ocrami.itagdin := itags_default;
        if r.flushpart(1)='1' then
          ocrami.itagen := "1111";
          ocrami.itagwrite := '1';
        end if;
        obifi.busaddr := (others => '0');
        obifi.busaddr(DOFFSET_HIGH downto DOFFSET_LOW) := r.flushctr(DOFFSET_HIGH downto DOFFSET_LOW);
        -- Note no translation done on flush commands
        obifi.stdata(11 downto 0) := "111001001111";
        if r.flushpart(0)='1' and r.dtflushdone='0' then
          obifi.bifop := BIFOP_FFLUSH;
        end if;

      when as_icfetch =>
        if r.bifwait_op=BIFOP_ILFET then
          obifi.busaddr(r.i2paddr'range) := r.i2paddr;
          obifi.widebus := r.i2busw;
        end if;
        v.i1ten := '0';
        if r.i2hitv=(r.i2hitv'range=>'0') and r_cctrl.ics="11" and r.irdbufen='0' then
          -- Select way to replace
          for x in 1 to IWAYS-1 loop
            if r.i2validv(x)='0' and r.i2validv(0 to x-1)=onev(x-1 downto 0) then
              v.i2hitv(x) := '1';
            end if;
          end loop;
          if r.i2validv(0)='0' then
            v.i2hitv(0) := '1';
          end if;
          if r.i2validv=(r.i2validv'range=>'1') then
            vtmp4i := dec4wrap(ilruent(4 downto 3), IWAYS);
            v.i2hitv := v.i2hitv or vtmp4i(0 to IWAYS-1);
          end if;
        end if;
        v.irdbufen := '1';
        if r.irdbufen='0' then
          v.irdbufvaddr := r.i2pc(r.irdbufvaddr'range);
          v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
          v.i2bufmatch := '1';
        end if;
        -- write read data buffer into I$ data RAM
        ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.irdbufvaddr(IOFFSET_HIGH downto IOFFSET_LOW);
        ocrami.idataoffs(log2(ilinesize)-2 downto 0) := r.iramaddr;
        if r_cctrl.ics(0)='1' and r.irdbufen='1' then
          ocrami.itagen(0 to IWAYS-1) := r.i2hitv;
          ocrami.itagwrite := '1';
          ocrami.idataen(0 to IWAYS-1) := r.i2hitv;
          ocrami.idatawrite := "11";
        end if;
        if ( ((not (endian='1')) and bifo.rdb.bufv(LINESZMAX-1-to_integer(unsigned(r.iramaddr & onev(3))))='1') or
             (((endian='1')) and bifo.rdb.bufv(to_integer(unsigned(r.iramaddr & onev(3))))='1') ) then
          if r.iramaddr /= (r.iramaddr'range => '1') then
            v.iramaddr := std_logic_vector(unsigned(r.iramaddr)+1);
          end if;
          if r.iramaddr=(r.iramaddr'range => '1') and not (r_cctrl.ics(0)='0' and ici.parkreq='0' and (r.holdn='1' or (r.imisspend='1' and r.i2bufmatch='1'))) then
            v.irdbufen := '0';
            v.ramreload := '1';
            -- Update irdbufvaddr/paddr since used in icfetch2 stage
            if r.imisspend='1' then
              v.irdbufvaddr := r.i2pc(r.irdbufvaddr'range);
              v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
              v.iramaddr := r.i2pc(r.iramaddr'high downto r.iramaddr'low);
            else
              v.irdbufvaddr := r.i1pc(r.irdbufvaddr'range);
              v.irdbufpaddr := itlbpaddr(r.irdbufpaddr'range);
              v.iramaddr := r.i1pc(r.iramaddr'high downto r.iramaddr'low);
            end if;
            if v.imisspend='1' and v.i2paddrv='1' then
              v.s := as_wptectag1;
            elsif bifo.stat.ready='0' then
              v.s := as_bifwait;
            else
              v.s := as_normal;
            end if;
          end if;
        end if;
        oico.mexc := bifo.rdb.err;
        oico.exctype := '1';
        if bifo.rdb.err='1' then
          v.iflushpend := '1';
          v.itrappend(0) := '1';
        end if;
        ocrami.itcmen := '0';

        -- Handle stores while streaming instructions from buffer
        if fastwr='1' then
          obifi.bifop := BIFOP_STORE;
          v.bifwait_op := BIFOP_STORE;
          obifi.wcomb := fastwr_wcomb;
          v.bifwait_wc := fastwr_wcomb;
          if bifo.stat.ready='0' then
            v.stbuffull := '1';
          end if;
        elsif r.stbuffull='1' and bifo.stat.ready='1' then
          v.stbuffull := '0';
        end if;

      when as_dcfetch =>
        if r.d2hitv=(r.d2hitv'range => '0') and r_cctrl.dcs="11" and r.d2nocache='0' then
          -- Select way to replace
          for x in 1 to DWAYS-1 loop
            if r.d2validv(x)='0' and r.d2validv(0 to x-1)=onev(x-1 downto 0) then
              v.d2hitv(x) := '1';
            end if;
          end loop;
          if r.d2validv(0)='0' then
            v.d2hitv(0) := '1';
          end if;
          if r.d2validv=(r.d2validv'range => '1') then
            vtmp4i := dec4wrap(dlruent(4 downto 3), DWAYS);
            v.d2hitv := v.d2hitv or vtmp4i(0 to DWAYS-1);
          end if;
        end if;
        if bifo.dtu.utype="10" or not (r_cctrl.dcs="11" and r.d2nocache='0') then
          v.dvtagdone := '1';
        end if;

        -- write read data buffer into D$ data RAM
        -- note virtual and physical tag write managed by snoop pipeline above
        -- data managed here
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.dramaddr;
        if ((not (endian='1')) and bifo.rdb.bufv(LINESZMAX-1-to_integer(unsigned(std_logic_vector'(r.dramaddr & onev(log2(cdataw/8)-1 downto 2)))))='1') or
          (((endian='1')) and bifo.rdb.bufv(to_integer(unsigned(std_logic_vector'(r.dramaddr & onev(log2(cdataw/8)-1 downto 2)))))='1')
        then
          ocrami.ddataen := (others => '0');
          if r_cctrl.dcs(0)='1' then
            ocrami.ddataen(0 to DWAYS-1) := r.d2hitv;
            ocrami.ddatawrite := (others => '1');
          end if;
          v.dramaddr := std_logic_vector(unsigned(r.dramaddr)+1);
          if r.dramaddr=(r.dramaddr'range => '1') then
            if r.dvtagdone='0' then
              v.s := as_dcfetch2;
            elsif r.d2atomic='1' then
              v.s := as_atomic4;
            else
              v.dmisspend := '0';
              v.s := as_normal;
            end if;
            if r.d1ten='1' then
              v.ramreload := '1';
            end if;
          end if;
        end if;
        odco.mexc := bifo.rdb.err;
        odco.exctype := bifo.rdb.err;
        if bifo.rdb.err='1' then
          v.dflushpend := '1';
        end if;
        odco.way := "00";
        odco.mds := '0';

        if arch = SPARC then
          v.d2cascmp := (others => '0');
          for x in 0 to DLINESIZE-1 loop
            if (not (endian='1')) then
              if bifo.rdb.buf(DLINESIZE*32-32*x-1 downto DLINESIZE*32-32*x-32)=r.d2casdata then v.d2cascmp(x) := '1'; end if;
            else
              if bifo.rdb.buf(32*x+31 downto 32*x)=r.d2casdata then v.d2cascmp(x) := '1'; end if;
            end if;
          end loop;

          -- Merge in read data into d2data for ldstub (done as 32-bit write in
          -- as_atomic4 state)
          if r.d2atomic='1' and r.d2size="00" then
            for x in 0 to 7 loop
              if r.d2vaddr(1 downto 0)/=std_logic_vector(to_unsigned(x mod 4,2)) then
                v.d2data(63-x*8 downto 56-x*8) := odco.data(0)(63-x*8 downto 56-x*8);
              end if;
            end loop;
          end if;
        else -- arch = RISCV
          if r.d2atomic = '1' then
            v.amo.data := rdbuf_data;
          end if;
        end if;

      when as_dcfetch2 =>
        if bifo.dtu.utype="10" then
          v.dvtagdone := '1';
        end if;
        if r.dvtagdone='1' or r.d2hitv=(r.d2hitv'range=>'0') then
          if r.d2atomic='1' then
            v.s := as_atomic4;
          else
            v.s := as_normal;
            v.dmisspend := '0';
          end if;
          if r.d1ten='1' then
            v.ramreload := '1';
          end if;
        end if;

      when as_dcsingle =>
        if bifo.rdb.done='1' then
          if r.d2atomic='1' then
            v.s := as_atomic4;
          else
            v.dmisspend := '0';
            v.s := as_normal;
          end if;
          if r.d1ten='1' then
            v.ramreload := '1';
          end if;
        end if;
        odco.way := "00";
        odco.mds := '0';

        odco.mexc := bifo.rdb.err;
        odco.exctype := bifo.rdb.err;  -- Count AHB error as access fault.

        if arch = SPARC then
          v.d2cascmp := (others => '0');
          for x in 0 to DLINESIZE-1 loop
            if (not (endian='1')) then
              if bifo.rdb.buf(DLINESIZE*32-32*x-1 downto DLINESIZE*32-32*x-32)=r.d2casdata then v.d2cascmp(x) := '1'; end if;
            else
              if bifo.rdb.buf(32*x+31 downto 32*x)=r.d2casdata then v.d2cascmp(x) := '1'; end if;
            end if;
          end loop;

          -- Merge in read data into d2data for ldstub (done as 32-bit write in
          -- as_atomic4 state)
          if r.d2atomic='1' and r.d2size="00" then
            for x in 0 to 7 loop
              if r.d2vaddr(1 downto 0)/=std_logic_vector(to_unsigned(x mod 4,2)) then
                v.d2data(63-x*8 downto 56-x*8) := odco.data(0)(63-x*8 downto 56-x*8);
              end if;
            end loop;
          end if;
        else -- arch = RISCV
          if r.d2atomic = '1' then
            v.amo.data := rdbuf_data;
          end if;
        end if;

      when as_mmuwalk =>
        if arch = SPARC then
          obifi.busaddr := (others => '0');
          obifi.busaddr(31 downto 0) := r.mmuaddr(31 downto 0);
          obifi.size := "10";
          obifi.widebus := '0';
          -- Ensure PTE writes get snooped
          obifi.nosnoop := '0';
          obifi.mmuacc := '1';
          -- New entry and new error (if error occurs)
          if r.mmusel(0)='0' then
            v.newent.ctx := r.i2ctx;
            v.newent.vaddr := r.i2pc(31 downto 12);
            v.newent.modified := '0';
            v.newerrclass := "01";
            v.mmuerr.at_ls := '0';        -- Load/Execute
            v.mmuerr.at_id := '1';        -- Instruction space
            v.mmuerr.at_su := r.i2su;
          else
            v.newent.ctx := r.mmctrl1.ctx;
            v.newent.vaddr := r.d2vaddr(31 downto 12);
            v.newent.modified := r.mmusel(1);
            v.newerrclass := "10";
            v.mmuerr.at_ls := r.mmusel(1);
            v.mmuerr.at_id := '0';
            v.mmuerr.at_su := r.d2su;
            -- Treat atomic access as store to avoid store phase of atomic
            -- causing mmu fault
            if r.d2atomic='1' then
              v.newent.modified := '1';
              v.mmuerr.at_ls := '1';
            end if;
          end if;
          if r.newent.mask(1)='0' then
            v.mmuerr.l := "00";
          elsif r.newent.mask(2)='0' then
            v.mmuerr.l := "01";
          elsif r.newent.mask(3)='0' then
            v.mmuerr.l := "10";
          else
            v.mmuerr.l := "11";
          end if;
          v.newent.paddr(35 downto 12) := rdb32(31 downto 8);
          v.newent.cached := rdb32(7);
          v.newent.busw := dec_wbmask_fixed(v.newent.paddr(31 downto 12) & "0000000000", xwbmask);
          if rdb32v='1' then
            v.newent.modified := v.newent.modified or rdb32(6);
          end if;
          -- Prepare hwdata for writing back PTE with R/M bits set
          -- Check if write-back is needed
          vstd32 := rdb32;
          if r.newent.modified='1' then
            vstd32(6) := '1';
          end if;
          vstd32(5) := '1';         -- referenced bit
          vneedwb := '0';
          vneedwblock := '0';
          if vstd32(6 downto 5) /= rdb32(6 downto 5) then
            vneedwb := '1';
            if vstd32(6) = '0' then
              vneedwblock := '1';
            end if;
          end if;
          obifi.stdata := vstd32 & vstd32;
          v.newent.acc := rdb32(4 downto 2);
          v.dregval := rdb32 & rdb32;
          if rdb32v='1' and bifo.stat.ready='1' then
            obifi.clrrdbuf := '1';
            -- Depending on level/type -
            --   update haddr to go down to next level
            --   write back "accessed" bit
            --   update TLB and register of access causing miss
            if bifo.rdb.err='1' then
              -- AHB error fetching entry
              v.s := as_mmuwalk3;
              v.newerrclass := "11";
              v.mmuerr.ft := "100";       -- Translation error
              v.mmuerr.fav := '1';
            elsif rdb32(1 downto 0)="10" then
              -- Page table entry
              v.mmuerr.ft := ft_acc_resolve(r.mmuerr.at_ls & r.mmuerr.at_id & r.mmuerr.at_su, rdb32(4 downto 2));
              if r.mmusel(2)='1' then
                v.s := as_rdasi2;
              elsif v.mmuerr.ft(1) /= '0' then
                v.s := as_mmuwalk3;
                v.mmuerr.fav := '1';
              elsif vneedwb='1' then
                if vneedwblock='1' and r.biflocked='0' then
                  v.s := as_mmuwalk4;
                else
                  v.s := as_wptectag1;
                  v.tlbupdate := '1';
                  obifi.bifop := BIFOP_STORE;
                  -- note - no need to set bifwait_op here as we know the bus
                  -- interface is ready.
                end if;
              else
                v.tlbupdate := '1';
                -- Re-read tags and check for a potential hit
                if r.mmusel(0)='0' and r.imisspend='1' then
                  v.s := as_wptectag1;
                elsif r.mmusel(0)='1' and (r.dmisspend='1' or r.slowwrpend='1') then
                  v.s := as_wptectag1;
                else
                  v.s := as_normal;
                end if;
              end if;
            elsif rdb32(1 downto 0)="01" and r.newent.mask(3)='0' then
              -- Page table descriptor
              v.newent.mask(3) := r.newent.mask(2);
              v.newent.mask(2) := r.newent.mask(1);
              v.newent.mask(1) := '1';
              v.mmuaddr(31 downto 0) := rdb32(27 downto 4) & "00000000";
              if r.newent.mask(1)='0' then
                v.mmuaddr(9 downto 2) := v.mmuaddr(9 downto 2) or r.newent.vaddr(31 downto 24);
              end if;
              if r.newent.mask(1)='1' and r.newent.mask(2)='0' then
                v.mmuaddr(7 downto 2) := v.mmuaddr(7 downto 2) or r.newent.vaddr(23 downto 18);
              end if;
              if r.newent.mask(1)='1' and r.newent.mask(2)='1' then
                v.mmuaddr(7 downto 2) := v.mmuaddr(7 downto 2) or r.newent.vaddr(17 downto 12);
              end if;
              obifi.busaddr := (others => '0');
              obifi.busaddr(31 downto 0) := v.mmuaddr(31 downto 0);
              if r.mmusel(2)='1' then
                v.d2vaddr(9 downto 8) := std_logic_vector(unsigned(r.d2vaddr(9 downto 8)) + 1);
              end if;
              if r.mmusel(2)='1' and r.d2vaddr(9 downto 8)="11" then
                v.s := as_rdasi2;
              else
                obifi.bifop := BIFOP_SMFET;
              end if;
            else
              -- Invalid/reserved or too many levels of PTDs
              v.s := as_mmuwalk3;
              if rdb32(1 downto 0)="00" then
                v.mmuerr.ft := "001";     -- Invalid address error
              else
                v.mmuerr.ft := "100";     -- Translation error
              end if;
              v.mmuerr.fav := '1';
            end if;
          end if;
          -- If DIAEMRU is set, we do not set FAV here for instruction
          -- MMU miss, we handle that in the trap ack so that we only
          -- update the FSR/FAR if the trapping instruction is actually
          -- executed
          if r_cctrl.diaemru='1' and r.mmusel="0000" then
            v.mmuerr.fav := '0';
          end if;
          if r.mmusel(0)='0' then
            v.i2paddr := v.newent.paddr & r.i2pc(11 downto 0);
            if r.newent.mask(1)='0' then
              v.i2paddr(31 downto 24) := v.i2paddr(31 downto 24) or r.i2pc(31 downto 24);
            end if;
            if r.newent.mask(2)='0' then
              v.i2paddr(23 downto 18) := v.i2paddr(23 downto 18) or r.i2pc(23 downto 18);
            end if;
            if r.newent.mask(3)='0' then
              v.i2paddr(17 downto 12) := v.i2paddr(17 downto 12) or r.i2pc(17 downto 12);
            end if;
            v.i2paddrv := '1';
            v.i2busw := v.newent.busw;
            v.i2paddrc := v.newent.cached;
          else
            v.d2paddr := v.newent.paddr & r.d2vaddr(11 downto 0);
            if r.newent.mask(1)='0' then
              v.d2paddr(31 downto 24) := v.d2paddr(31 downto 24) or r.d2vaddr(31 downto 24);
            end if;
            if r.newent.mask(2)='0' then
              v.d2paddr(23 downto 18) := v.d2paddr(23 downto 18) or r.d2vaddr(23 downto 18);
            end if;
            if r.newent.mask(3)='0' then
              v.d2paddr(17 downto 12) := v.d2paddr(17 downto 12) or r.d2vaddr(17 downto 12);
            end if;
            v.d2paddrv := '1';
            v.d2busw := v.newent.busw;
            v.d2nocache := not v.newent.cached;
            v.d2tlbmod := v.newent.modified;
          end if;
          -- Select which TLB entry to replace
          if r.mmusel(0)='0' then
            if r.i2tlbhit='0' and r.mmctrl1.tlbdis='0' then
              v.i2tlbhit := '1';
              v.i2tlbid := pmru_decode(r.itlbpmru);
            end if;
          else
            if r.d2tlbhit='0' and r.mmctrl1.tlbdis='0' and r.mmusel(2)='0' then
              v.d2tlbhit := '1';
              v.d2tlbid := pmru_decode(r.dtlbpmru);
            end if;
          end if;
          -- setup for as_wptectag1 state in case of recheck
          v.irdbufvaddr := r.i2pc(r.irdbufvaddr'range);
          v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
          v.iramaddr := r.i2pc(r.iramaddr'high downto r.iramaddr'low);
        end if;

      when as_mmuwalk3 =>
       if arch = SPARC then
        if r.mmusel(2)='0' then
          if r.mmusel(0)='0' then
            oico.mds := '0';
            if r.mmctrl1.nf='0' then
              oico.mexc := '1';
              v.itrappend(2) := '1';
            end if;
            v.imisspend := '0';
          else
            odco.mds := '0';
            if r.mmctrl1.nf='0' then
              odco.mexc := '1';
            end if;
            if r.mmusel(1)='1' then
              v.slowwrpend := '0';
            else
              v.dmisspend := '0';
            end if;
          end if;
          v.ramreload := '1';
          v.s := as_normal;
        else
          v.s := as_rdasi2;
        end if;
        v.dregval := (others => '0');
        oico.mexcdata(1 downto 0) := "01";
       else
         assert false report "Reached as_mmuwalk3!" severity failure;
       end if;

      when as_mmuwalk4 =>
       if arch = SPARC then
        obifi.busaddr := (others => '0');
        obifi.busaddr(31 downto 0) := r.mmuaddr(31 downto 0);
        obifi.widebus := '0';
        obifi.size := "10";
        obifi.nosnoop := '0';
        obifi.mmuacc := '1';
        vstd32 := rdb32;
        vstd32(5) := '1';  -- set referenced bit
        obifi.stdata := vstd32 & vstd32;
        if r.biflocked='0' then
          vtoglock := '1';
        end if;
        if bifo.rdb.err='1' then
          -- AHB error fetching entry
          v.s := as_mmuwalk3;
          v.newerrclass := "11";
          v.mmuerr.ft := "100";       -- Translation error
          if r.mmusel /= "0000" then
            v.mmuerr.fav := '1';
          end if;
        elsif rdb32v='1' and bifo.stat.ready='1' then
          v.s := as_wptectag1;
          v.newent.modified := v.newent.modified or rdb32(6);
          v.tlbupdate := '1';
          obifi.bifop := BIFOP_STORE;
        elsif rdb32v='1' or bifo.stat.idle='0' then
          -- wait for read access to complete
          null;
        elsif r.biflocked='1' and bifo.stat.ready='1' then
          -- start read access with lock held
          obifi.bifop := BIFOP_SMFET;
        end if;
       else
         assert false report "Reached as_mmuwalk4!" severity failure;
       end if;

      when as_wptectag1 =>
        -- Write PTE and recheck tags stage 1
        v.s := as_wptectag2;
        -- Drive Icache tag/data addresses
        ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.irdbufvaddr(IOFFSET_HIGH downto IOFFSET_LOW);
        ocrami.idataoffs(log2(ilinesize)-2 downto 0) := r.iramaddr;
        ocrami.ifulladdr := r.i2pc(ocrami.ifulladdr'range);
        v.i1cont := '0';
        -- To avoid complicating the tag comparison logic we swap i1pc and i2pc
        -- and then swap back in icfetch3
        v.i2pc := r.i1pc;
        v.i1pc := r.i2pc;
        v.i2su := r.i1su;
        v.i1su := r.i2su;
        v.i2ctx := r.i1ctx;
        v.i1ctx := r.i2ctx;
        v.i2m := r.i1m;
        v.i1m := r.i2m;
        v.i2mode := r.i1mode;
        v.i1mode := r.i2mode;
        v.i2nostream := r.i1nostream;
        v.i1nostream := r.i2nostream;
        -- This state will be entered after TLB updates, which
        -- will also necessitate PMP/PMA recheck (if not in TLBs).
        if not actual_tlb_pmp then
          v.d1pmp := '1';
          v.i1pmp := '1';
        end if;
        --
        if r_cctrl.ics(0)='1' and r.imisspend='1' then
          ocrami.itagen := "1111";
          ocrami.idataen := "1111";
          v.i1ten := '1';
        end if;
        v.i1rep := '0';
        -- Drive Dcache tag/data addresses
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ddatafulladdr := r.d2vaddr(ocrami.ddatafulladdr'range);
        ocrami.ddatafulladdrw := r.d2vaddr(ocrami.ddatafulladdrw'range);
        v.dtlbbypass := '1';           -- skip dtlb check and inject d2paddr directly
        v.d1ten := '0';
        if r_cctrl.dcs(0)='1' and r.mmusel(0)='1' and (r.dmisspend='1' or r.slowwrpend='1') then
          ocrami.dtagcen := (others => '1');
          ocrami.ddataen := (others => '1');
          v.d1ten := '1';
        end if;

      when as_wptectag2 =>
        -- Write PTE and recheck tags stage 2 - tag check
        v.s := as_normal;
        if bifo.stat.ready='0' and (r.bifwait_op /= BIFOP_NOP and r.bifwait_op /= BIFOP_LOCK) then
          v.s := as_bifwait;
          v.stbuffull := '1';
        end if;
        -- Check Icache tags
        if r.imisspend='1' then
          oico.mds := '0';
        end if;
        -- Swap back to get i1pc
        v.i2pc := r.i1pc;
        v.i1pc := r.i2pc;
        v.i2pc := r.i1pc;
        v.i1pc := r.i2pc;
        v.i2su := r.i1su;
        v.i1su := r.i2su;
        v.i2ctx := r.i1ctx;
        v.i1ctx := r.i2ctx;
        v.i2m := r.i1m;
        v.i1m := r.i2m;
        v.i2mode := r.i1mode;
        v.i1mode := r.i2mode;
        v.i2nostream := r.i1nostream;
        v.i1nostream := r.i2nostream;
        --
        v.i1ten := '0';
        v.i2validv := ivalidv;
        v.i2hitv := ihitv;
        if ihit='1' then
          v.imisspend := '0';
        end if;
        -- Drive Dcache tag/data addresses
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ddatafulladdr := r.d2vaddr(ocrami.ddatafulladdr'range);
        ocrami.ddatafulladdrw := r.d2vaddr(ocrami.ddatafulladdrw'range);
        -- Check Dcache tags
        if r.dmisspend='1' and r.d2tcmhit='0' then
          odco.mds := '0';
        end if;
        if r.d1ten='1' then
          v.d2hitv := dhitv;
          v.d2validv := dvalidv;
        end if;
        ocrami.ddataen := (others => '0');
        ocrami.dtcmen := '0';
        if dhit='1' and (arch = SPARC or v.dfailkind(1) = '0') then
          if r.d2nocache='0' and r.d2specialasi='0' and r.d2forcemiss='0' and r.d2atomic='0' then
            v.dmisspend := '0';
          end if;
          if r.d2tcmhit='1' and (arch = SPARC or v.dfailkind(1) = '0') then
            -- TODO atomics on TCM
            v.dmisspend := '0';
          end if;
        end if;
        if r.d2write='1' and r.d2specialasi='0' and r.amo.d2type(5)='0' then
          ocrami.ddataen(0 to DWAYS-1) := dhitv;
          ocrami.dtcmen := r.d2tcmhit;
        end if;
        ocrami.ddatawrite := getdmask64(r.d2vaddr,r.d2size,(endian='1'));
        ocrami.ddatadin := (others => r.d2data);
        v.d1ten := r.d1chk and r_cctrl.dcs(0);
        v.d1tcmen := r.d1chk and dtcmact;
        v.ramreload := '1';

      when as_wptectag3 =>
        -- Write PTE and recheck tags stage 3 - finish writeback
        v.s := as_normal;
        if bifo.stat.ready='0' and (r.bifwait_op /= BIFOP_NOP and r.bifwait_op /= BIFOP_LOCK) then
          v.s := as_bifwait;
          v.stbuffull := '1';
        end if;

      when as_slowwr =>
        -- Translate addr
        -- MMU permission check
        -- Check written flag
        -- Write burst on narrow bus
        -- Perform write
        v.mmusel := "0011";
        if 
        (
        false)
        and r.d2asi(6)='1' then
        elsif dspecialasi='1' then
          v.s := as_wrasi;
          v.d2paddr := (others => '0');
          v.d2paddr(31 downto 0) := r.d2vaddr(31 downto 0);
        elsif arch = RISCV and walk_pmp and (r.d2paddrv = '0' or r.d2tlbmod = '0') and not mmu_enabled(v.d2mode) then
          start_pmp     := true;   -- See more after case.
        elsif mmuen = 1 and (r.d2paddrv='0' or r.d2tlbmod='0') then
          if arch = SPARC then
            v.s := as_mmuwalk;
            obifi.bifop := BIFOP_SMFET;
            v.bifwait_op := BIFOP_SMFET;
            obifi.size := "10";
            obifi.widebus := '0';
            obifi.mmuacc := '1';
            v.mmuaddr(31 downto 0) := r.mmctrl1.ctxp(25 downto 4) & r.mmctrl1.ctx & "00";
            obifi.busaddr := (others => '0');
            obifi.busaddr(31 downto 0) := v.mmuaddr(31 downto 0);
          else -- arch = RISCV
            start_walk := true;
          end if;
        else
          obifi.bifop := BIFOP_STORE;
          v.bifwait_op := BIFOP_STORE;
          if r.biflocked = '1' or bifo.stat.locked='1' then
            v.s := as_bifwait_unlock;
          else
            v.s := as_normal;
          end if;
          if bifo.stat.ready='0' then
            v.s := as_bifwait;
            v.stbuffull := '1';
          end if;
          v.slowwrpend := '0';
          if r_cctrl.wcomben='1' or r.dwchint='1' then
            obifi.wcomb := '1';
            v.bifwait_wc := '1';
          end if;
          v.dwchint := '0';
        end if;
        -- Set up dregval with write data for register access case
        v.dregval := r.d2data;

      when as_wrasi =>
        v.s := as_wrasi2;
        -- For next state in case of ASI 0xC-0xF
        v.flushctr(MAXOFFSET_HIGH downto MAXOFFSET_LOW) := r.d2vaddr(MAXOFFSET_HIGH downto MAXOFFSET_LOW);
        vtmp4i := dec4wrap(r.d2vaddr(DOFFSET_HIGH+2 downto DOFFSET_HIGH+1), DWAYS);
        v.d2hitv := vtmp4i(0 to DWAYS-1);
        vtmp4i := dec4wrap(r.d2vaddr(DOFFSET_HIGH+2 downto DOFFSET_HIGH+1), IWAYS);
        v.i2hitv := vtmp4i(0 to IWAYS-1);
        v.ramreload := '1';

        case r.d2asi is
          when "00000010" =>            -- 0x02 System control registers
            -- Mostly handled in register access code above FSM
            if vbadreg='1' then
              v.dregerr := '1'; v.s := as_wrasi3;
            else
              v.slowwrpend := '0'; v.s := as_normal;
            end if;
            if r.d2vaddr(6 downto 3)="0100" then
              -- Access to AHB error / AHB error address / extended AHB error
              -- address register
              obifi.bifop := BIFOP_AREGW;
              v.bifwait_op := BIFOP_AREGW;
              if bifo.stat.ready='0' then v.s := as_bifwait; end if;
            end if;
            -- When writing into the TCM config reigster, clear tcmdata register
            -- used as address counter during wipe
            if r.d2vaddr(6 downto 2)="10000" then
              v.tcmdata := (others => '0');
            end if;

            -- when "00000011" =>            -- 0x03 Cache+TLB flush
            -- merged with ASI 0x18

            -- when "00000100" =>            -- 0x04 MMU registers
            -- merged with ASI 0x19

          when "00001100" =>            -- 0x0C ICache tags
            null;

          when "00001101" =>            -- 0x0D ICache data
            null;

          when "00001110" =>            -- 0x0E DCache tags
            obifi.bifop := BIFOP_DTAGW;
            v.bifwait_op := BIFOP_DTAGW;

          when "00001111" =>            -- 0x0F DCache data
            null;

          when "00010000" | "00010011" =>            -- 0x10 ICache+Dcache flush
            v.flushpart := "11";
            v.dflushpend := '1';
            v.iflushpend := '1';
            v.flushctr := (others => '0');
            v.slowwrpend := '0';
            v.s := as_flush;
            v.perf(4) := '1';

          when "00010001" =>            -- 0x11 DCache flush
            v.dflushpend := '1';
            v.flushpart(0) := '1';
            v.flushctr := (others => '0');
            v.slowwrpend := '0';
            v.s := as_flush;
            v.perf(4) := '1';

            --when "00010011" =>            -- 0x13 ICache+Dcache flush
            -- merged with ASI 0x10

          when "00011000" | "00000011" =>            -- 0x18 Cache+TLB flush
            v.tlbflush := '1';
            v.htlbflush := '1';
            v.flushpart := "11";
            v.dflushpend := '1';
            v.iflushpend := '1';
            v.flushctr := (others => '0');
            v.slowwrpend := '0';
            v.s := as_flush;
            v.perf(4) := '1';

          when "00011001" | "00000100" =>            -- 0x19 MMU registers
            -- Mostly handled in register access code above FSM
            if vbadreg='1' then
              v.dregerr := '1'; v.s := as_wrasi3;
            else
              v.slowwrpend := '0'; v.s := as_normal;
            end if;
            -- Set ctxswitch flag when context register is written to trigger
            -- BTB flush in pipeline
            if r.d2vaddr(10 downto 8)="010" then
              v.ctxswitch := '1';
            end if;

          -- On RISC-V the access size defines the specific TLB flush:
          --   00 sfence.vma
          --   01 hfence.vvma
          --   10 hfence.gvma
          -- Also, parts of the access type are being used to tell the
          -- flush whether VMID/ASID and/or address should be checked.
          when "00011011" =>               -- 0x1B MMU flush/probe
            v.s := as_mmuflush2;
            -- Swap addresses for TLB check
            --  use r.dregval[31:0] is used as temp holding register for i1pc
            --  and r.dregval[39:32] for i1ctx
            v.i1pc := r.d2vaddr;
            v.dregval(r.i1pc'range) := r.i1pc;
            v.dregval(r.i1ctx'length-1+r.i1pc'length downto r.i1pc'length) := r.i1ctx;
            v.i1ctx := r.mmctrl1.ctx;
            v.d1vaddr := r.d2vaddr;
            v.d2vaddr := r.d1vaddr;
            if arch = RISCV and mmuen = 1 then
              if csro.mmu_oldfence = '1' then
                v.tlbflush   := '1';
                v.htlbflush  := '1';
                v.flushpart  := "11";  -- Should not be needed!
                v.dflushpend := '1';   -- Should not be needed!
                v.iflushpend := '1';   -- Should not be needed!
                v.flushctr   := (others => '0');
                v.slowwrpend := '0';
                v.s          := as_flush;
                v.perf(4)    := '1';
              else
                v.h_addr := r.d2vaddr(v.h_addr'range);
                -- Set top data bits as not checking sTLB address, ASID, VMID, hTLB address.
                if r.d2size = "00" then                         -- sfence.vma
                  if ext_h = 1 and is_v(r.d2mode) then
                    set_hi(v.d2data, r.d2su & r.d2m & "01");  --  Check current VMID when vs.
                    set(v.d2data, asidlen, get(mmu_ctx(csro), asidlen, vmidlen));
                  else
                    set_hi(v.d2data, r.d2su & r.d2m & "11");  --  Do not check VMID.
                  end if;
                elsif ext_h = 1 then
                  if r.d2size = "01" then                       -- hfence.vvma
                    set_hi(v.d2data, r.d2su & r.d2m & "01");  --  Check current VMID.
                    set(v.d2data, asidlen, get(mmu_ctx(csro), asidlen, vmidlen));
                  else  -- if r.d2size = "10" then              -- hfence.gvma
                    set_hi(v.d2data, "11" & r.d2m & r.d2su);
                    set(v.d2data, asidlen, get(r.d2data, 0, vmidlen));
                  end if;
                end if;
              end if;
            end if;

          when "00011100" =>            -- 0x1C MMU/Cache bypass
            -- Update registers and jump back to normal to handle in standard
            -- path
            v.d2paddr := (others => '0');
            v.d2paddr(31 downto 0) := r.d2vaddr(31 downto 0);
            v.d2paddrv := '1';
            v.d2tlbmod := '1';
            v.d2busw := dec_wbmask_fixed(r.d2vaddr(31 downto 2), xwbmask);
            v.d2asi := "000" & ASI_SDATA;
            v.d2specialasi := '0';
            v.d2forcemiss := '1';
            v.d2nocache := '1';
            v.d2su := '1';
            v.d2hitv := (others => '0');
            v.s := as_normal;

          when "00011110" =>            -- 0x1E snoop tags
            obifi.bifop := BIFOP_STAGW;
            v.bifwait_op := BIFOP_STAGW;

          when "00100000" =>            -- 0x20  FPC control/debug
           if arch = SPARC then
            v.s := as_wrasi;
            v.fpc_mosi.accen := '1';
            v.fpc_mosi.accwr := '1';
            if r.fpc_mosi.accen='0' then
              v.fpc_mosi.addr(0) := r.d2vaddr(2);
            elsif r.fpc_mosi.accen='1' and fpc_miso.accrdy='1' and r.d2size="11" then
              v.fpc_mosi.addr(0) := '1';
            end if;
            if v.fpc_mosi.addr(0)='0' xor (endian='1') then
              v.fpc_mosi.wrdata := r.d2data(63 downto 32);
            else
              v.fpc_mosi.wrdata := r.d2data(31 downto 0);
            end if;
            if r.fpc_mosi.accen='1' and fpc_miso.accrdy='1' then
              if r.d2size /= "11" or r.fpc_mosi.addr(0)='1' then
                v.s := as_wrasi3;
                v.fpc_mosi.accen := '0';
              end if;
            end if;
           else
            v.dregerr := '1';
           end if;

          when "00100001" =>            -- 0x21 CPC (coprocessor) control/debug
            v.dregerr := '1';

          when "00100010" =>            -- 0x22  CPU-to-CPU interface
           if arch = SPARC then
            v.s := as_wrasi;
            v.c2c_mosi.accen := '1';
            v.c2c_mosi.accwr := '1';
            if r.c2c_mosi.accen='0' then
              v.c2c_mosi.addr(0) := r.d2vaddr(2);
            elsif r.c2c_mosi.accen='1' and c2c_miso.accrdy='1' and r.d2size="11" then
              v.c2c_mosi.addr(0) := '1';
            end if;
            if v.c2c_mosi.addr(0)='0' xor (endian='1') then
              v.c2c_mosi.wrdata := r.d2data(63 downto 32);
            else
              v.c2c_mosi.wrdata := r.d2data(31 downto 0);
            end if;
            if r.c2c_mosi.accen='1' and c2c_miso.accrdy='1' then
              if r.d2size /= "11" or r.c2c_mosi.addr(0)='1' then
                v.s := as_wrasi3;
                v.c2c_mosi.accen := '0';
              end if;
            end if;
           else
             v.dregerr := '1';
           end if;

          when "00100011" =>            -- 0x23 TLB diagnostic access
            if arch = SPARC then
            -- d2vaddr(9) -- I / D
            -- d2vaddr(8) -- PMRU state
            -- d2vaddr(7 downto 3) -- entry
              if r.d2vaddr(9)='0' then
                v.newent := r.dtlb(to_integer(unsigned(r.d2vaddr(2+log2x(dtlbnum) downto 3))));
              else
                v.newent := r.itlb(to_integer(unsigned(r.d2vaddr(2+log2x(itlbnum) downto 3))));
              end if;
              if r.d2vaddr(8)='0' then
                if r.d2vaddr(2)='0' or r.d2size="11" then
                  d32 := r.d2data(63 downto 32);
                  if (endian='1') then d32 := r.d2data(31 downto 0); end if;
                  v.newent.vaddr := d32(31 downto 12);
                  v.newent.ctx   := d32(11 downto 4);
                  v.newent.mask(1) := d32(3);
                  v.newent.mask(2) := d32(2);
                  v.newent.mask(3) := d32(1);
                  v.newent.valid := d32(0);
                end if;
                if r.d2vaddr(2)='1' or r.d2size="11" then
                  d32 := r.d2data(31 downto 0);
                  if (endian='1') then d32 := r.d2data(63 downto 32); end if;
                  v.newent.paddr    := d32(9 downto 6) & d32(31 downto 12);
                  v.newent.acc      := d32(5 downto 3);
                  v.newent.busw     := d32(2);
                  v.newent.cached   := d32(1);
                  v.newent.modified := d32(0);
                end if;
                v.tlbupdate := '1';
                v.i2tlbid := r.d2vaddr(2+log2x(itlbnum) downto 3);
                v.d2tlbid := r.d2vaddr(2+log2x(dtlbnum) downto 3);
                v.mmusel(0) := not r.d2vaddr(9);
                v.i2tlbhit := r.d2vaddr(9);
                v.d2tlbhit := not r.d2vaddr(9);
              else
                d32 := r.d2data(63 downto 32);
                if (endian='1') then d32 := r.d2data(31 downto 0); end if;
                if r.d2vaddr(9)='0' then
                  for x in 0 to dtlbnum-1 loop
                    v.dtlbpmru(x) := d32(x);
                  end loop;
                else
                  for x in 0 to itlbnum-1 loop
                    v.itlbpmru(x) := d32(x);
                  end loop;
                end if;
              end if;
            elsif (mmuen = 1 or walk_pmp) and ext_noelv = 1 then
              -- RISC-V needs extra bits from an ASI write to 0x2f!
              -- d2vaddr( downto 12)  - vaddr
              -- d2vaddr(11)          - Together with x below - 2 MSBs for hTLB
              -- d2vaddr(10 downto 9) - 00 - dTLB, 10 - iTLB, x1 - hTLB
              -- d2vaddr(8)           - PMRU state
              -- d2vaddr(7 downto 3)  - entry
              if r.d2vaddr(8) = '0' then
                d64 := r.d2data;
                -- Use high part from 0x2f ASI data on RV32.
                if riscv_mmu = Sv32 then
                  set_hi(d64, hi_h(r.bregval));
                end if;
                -- Use low part from 0x2f ASI for VMID/ASID.
                v.newent.ctx        := get_lo(r.bregval, v.newent.ctx'length);

                v.newent.vaddr      := uext(r.d2vaddr(vpn'range), v.newent.vaddr);
                -- A guest physical address "as virtual" in hTLB has two extra bits.
                if ext_h = 1 and r.d2vaddr(9) = '1' then
                  set_hi(v.newent.vaddr, r.d2vaddr(11 downto 10));
                end if;
                v.newent.paddr      := d64(v.newent.paddr'range);

                v.newent.valid      := d64(rv_pte_v);  -- PTE-A below is "S"
                if mmuen = 1 then
                  v.newent.perm     := d64(rv_pte_a) & d64(rv_pte_u downto rv_pte_r);
                  if enable_g = 1 then
                    v.newent.global := d64(rv_pte_g);
                  end if;
                  v.newent.modified := d64(rv_pte_d);
                end if;
                -- The RSW bits are for software, so free to use.
                -- Also, address shifted up by two compared to PTE,
                -- to fit with paddr'range, giving two more bits.
                -- Enough mask bits for up to Sv48.
                v.newent.mask       := get(d64, rv_pte_rsw'low, v.newent.mask);
                v.newent.cached     := d64(rv_pte_pbmt'low - 5);
                v.newent.busw       := d64(rv_pte_pbmt'low - 4);
                v.newent.mode       := d64(rv_pte_pbmt'low - 1 downto rv_pte_pbmt'low - 3);
                if ext_svpbmt = 1 then
                  v.newent.pbmt     := d64(rv_pte_pbmt'range);
                end if;
                if ext_svnapot = 1 then
                  v.newent.svnapot  := d64(rv_pte_n);
                end if;

                if ext_h = 1 then
                  v.newent.h_r      := r.aregval(28);
                end if;

                if ext_h = 1 and actual_tlb_pmp and (pmpen or pmaen) then
                  v.newent.pmp_r    := r.aregval(29);
                  v.newent.pmp_no_w := r.aregval(30);
                  v.newent.pmp_no_x := r.aregval(31);
                end if;

                if pmaen then
                  v.newent.pma      := to_pma(get_hi(r.aregval, -3));
                end if;
                if walk_pmp then
                  v.newent.pmp_none := r.aregval(23);
                  v.newent.pmp_lock := r.aregval(24);
                  v.newent.pmp_rwx  := r.aregval(27 downto 25);
                end if;

                -- Not used by NOEL-V
                v.newent.acc        := (others => '0');
                if ext_h = 1 then
                  v.hnewent         := v.newent;
                  if r.d2vaddr(9) = '0' then
                    v.tlbupdate     := '1';
                  else
                    v.h2tlbupd      := '1';
                  end if;
                else
                  v.tlbupdate       := '1';
                end if;
                v.i2tlbid           := r.d2vaddr(2 + log2x(itlbnum) downto 3);
                v.d2tlbid           := r.d2vaddr(2 + log2x(dtlbnum) downto 3);
                v.h2tlbid           := r.d2vaddr(2 + log2x(htlbnum) downto 3);
                v.mmusel(0)         := not r.d2vaddr(10);  -- 0 - I, 1 - D
                v.i2tlbhit          := r.d2vaddr(10);
                v.d2tlbhit          := not r.d2vaddr(10);
              else
                -- This accepts PMRU with TLB entry n represented by bit n.
                if ext_h = 1 and r.d2vaddr(9) = '1' then
                  v.htlbpmru   := make_same(get(r.d2data, 0, v.htlbpmru), v.htlbpmru);
                else
                  if r.d2vaddr(10) = '0' then
                    v.dtlbpmru := make_same(get(r.d2data, 0, v.dtlbpmru), v.dtlbpmru);
                  else
                    v.itlbpmru := make_same(get(r.d2data, 0, v.itlbpmru), v.itlbpmru);
                  end if;
                end if;
              end if;
            else
              v.dregerr := '1';
            end if;
            v.s := as_wrasi2;

          when "00100100" =>            -- 0x24 BTB/BHT diagnostic access
           if arch = SPARC then
            v.s := as_wrasi;
            v.iudiag_mosi.accen := '1';
            v.iudiag_mosi.accwr := '1';
            if r.iudiag_mosi.accen='0' then
              v.iudiag_mosi.addr(0) := r.d2vaddr(2);
            elsif r.iudiag_mosi.accen='1' and dci.iudiag_miso.accrdy='1' and r.d2size="11" then
              v.iudiag_mosi.addr(0) := '1';
            end if;
            if v.iudiag_mosi.addr(0)='0' xor (endian='1') then
              v.iudiag_mosi.wrdata := r.d2data(63 downto 32);
            else
              v.iudiag_mosi.wrdata := r.d2data(31 downto 0);
            end if;
            if r.iudiag_mosi.accen='1' and dci.iudiag_miso.accrdy='1' then
              if r.d2size /= "11" or r.iudiag_mosi.addr(0)='1' then
                v.s := as_wrasi3;
                v.iudiag_mosi.accen := '0';
              end if;
            end if;
           else
            v.dregerr := '1';
           end if;

          when "00100101" =>         -- 0x25 Cache LRU diagnostic interface
           if arch = SPARC or ext_noelv = 1 then
            if r.d2vaddr(31)='1' then
              v.ilru(to_integer(unsigned(r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW)))) :=
                vregwdata0(4 downto 0);
            else
              v.dlru(to_integer(unsigned(r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW)))) :=
                vregwdata0(4 downto 0);
            end if;
           else
            v.dregerr := '1';
           end if;

          when "00100110" =>            -- 0x26 Instruction TCM access
           if arch = SPARC or ext_noelv = 1 then
            v.s := as_wrasi2;
           else
            v.dregerr := '1';
           end if;

          when "00100111" =>            -- 0x27 Data TCM access
           if arch = SPARC or ext_noelv = 1 then
            v.s := as_wrasi2;
           else
            v.dregerr := '1';
           end if;

          when "00101000" =>            -- 0x28 Stripe mapping table access
            -- busif address bit 31 set to 1 in slowwr state
            obifi.bifop := BIFOP_AREGW;
            v.bifwait_op := BIFOP_AREGW;

          when "00101001" =>            -- 0x29 Extended cache tag access
            if r.d2size/="11" then
              -- We need to perform a read-modify-write cycle to only modify
              -- part of the tag
              v.s := as_rdcdiag;
            else
              if r.d2vaddr(23)='1' then
                if r.d2vaddr(22)='0' then
                  -- DCache tags
                  obifi.bifop := BIFOP_DTAGW;
                  v.bifwait_op := BIFOP_DTAGW;
                else
                  -- DCache snoop tags
                  obifi.bifop := BIFOP_STAGW;
                  v.bifwait_op := BIFOP_STAGW;
                end if;
              end if;
            end if;

          when x"2e" =>                 -- PMP MMUU test
            if arch = RISCV and (mmuen = 1 or walk_pmp) and ext_noelv = 1 then
              if r.d2vaddr(5 downto 3) = "011" then                    -- 24
                -- Do nothing on write!
              -- 0 PMP+PMA, 8 only PMP, 16 PMA
              elsif r.d2vaddr(5) = '0' then                            -- 0/8/16
                if actual_tlb_pmp and pmp_mmuu_test = 1 then
                  v.pmp_mask := fit0ext(r.d2data, v.pmp_mask);
                  v.pmp_low  := fit0ext(r.d2vaddr, v.pmp_low);
                  v.pmp_do   := '1';
                  v.pmp_only := to_bit(r.d2vaddr(4 downto 3) = "01");
                end if;
              elsif r.d2vaddr(5) = '1' and tlb_valid_r = 1 then
                -- Use high part from 0x2f ASI data if 32 bit access.
                d64 := r.d2data;
                -- Use low part from 0x2f ASI data on RV32.
                if riscv_mmu = Sv32 then
                  set_hi(d64, lo_h(r.bregval));
                end if;
                if r.d2vaddr(4 downto 3) = "00" then                   -- 32
                  for x in v.dtlb'range loop
                    v.dtlb(x).valid := d64(x);
                  end loop;
                elsif r.d2vaddr(4 downto 3) = "01" then                -- 40
                  for x in v.itlb'range loop
                    v.itlb(x).valid := d64(x);
                  end loop;
                elsif r.d2vaddr(4 downto 3) = "10" and ext_h = 1 then  -- 48
                  for x in v.htlb'range loop
                    v.htlb(x).valid := d64(x);
                  end loop;
                else                                                   -- 56
                  for x in v.dtlb'range loop
                    v.dtlb(x).valid := d64(x);
                  end loop;
                  for x in v.itlb'range loop
                    v.itlb(x).valid := d64(x + v.dtlb'length);
                  end loop;
                  if ext_h = 1 then
                    for x in v.htlb'range loop
                      v.htlb(x).valid := d64(x + v.dtlb'length + v.itlb'length);
                    end loop;
                  end if;
                end if;
              end if;
              v.s := as_wrasi2;
            else
              v.dregerr := '1';
            end if;

          when x"2f" =>                 -- Extra 64 bits of ASI data
            if arch = RISCV and ext_noelv = 1 then
              -- Get a bunch of bits from the address.
              v.aregval := r.d2vaddr(31 downto 0);
              -- 32 bit access?
              if r.d2size /= "11" then
                v.bregval := lo_h(r.bregval) & lo_h(r.d2data);
              else
                v.bregval := r.d2data;
              end if;
              v.s := as_wrasi2;
            else
              v.dregerr := '1';
            end if;

          when others =>
            v.dregerr := '1';
        end case;

        if v.s=as_wrasi2 then
          v.irdbufvaddr := r.d2vaddr(r.irdbufvaddr'range);
          v.iramaddr := r.d2vaddr(r.iramaddr'high downto r.iramaddr'low);
        end if;

      when as_wrasi2 =>
       if arch = SPARC or ext_noelv = 1 then
        v.s := as_wrasi3;
        v.ramreload := r.ramreload;
        ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.irdbufvaddr(IOFFSET_HIGH downto IOFFSET_LOW);
        ocrami.idataoffs(log2(ilinesize)-2 downto 0) := r.iramaddr;

        -- Write data for tags
        d64 := r.dregval;
        if r.d2asi(5)='0' then
          -- Using old diagnostic tag ASI, pick high or low part depending
          -- on address used for access for bits 31:0 of tag and one for
          -- bit 32 to get compatible physical address
          if r.d2vaddr(2)='0' xor (endian='1') then
            d64(31 downto 0) := r.dregval(63 downto 32);
          end if;
          d64(63 downto 32) := (others => '0');
          if d64(31)='1' then d64(32):='1'; end if;
        end if;

        for w in 0 to IWAYS-1 loop
          ocrami.itagdin(w) := (others => '0');
          ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW+1 downto 1) := d64(ITAG_HIGH downto ITAG_LOW);
          ocrami.itagdin(w)(0) := d64(0);
        end loop;

        ocrami.idatadin := r.dregval;
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ifulladdr := r.d2vaddr(ocrami.ifulladdr'range);
        ocrami.ifulladdrw := r.d2vaddr(ocrami.ifulladdrw'range);
        ocrami.ddatafulladdr := r.d2vaddr(ocrami.ddatafulladdr'range);
        ocrami.ddatafulladdrw := r.d2vaddr(ocrami.ddatafulladdrw'range);
        v.dtagpipe := r.dtagpipe;

        -- Make sure cache data RAMs are masked by default if tcm is written
        -- and vice versa. Otherwise we can trigger an unwanted write if the
        -- ramreload flag is set on this cycle since they share the same
        -- idatawrite/ddatawrite mask
        if itcmen /= 0 then
          ocrami.idataen := (others => '0');
          ocrami.itcmen := '0';
        end if;
        if dtcmen /= 0 then
          ocrami.ddataen := (others => '0');
          ocrami.dtcmen := '0';
        end if;
        case r.d2asi is
          when "00001100" =>            -- 0x0C ICache tags
            ocrami.itagen(0 to IWAYS-1) := r.i2hitv;
            ocrami.itagwrite := '1';
          when "00001101" =>            -- 0x0D ICache data
            ocrami.idataen(0 to IWAYS-1) := r.i2hitv;
            ocrami.idatawrite := "00";
            if (r.d2vaddr(2)='0' xor (endian='1')) or r.d2size="11" then
              ocrami.idatawrite(1) := '1';
            end if;
            if (r.d2vaddr(2)='1' xor (endian='1')) or r.d2size="11" then
              ocrami.idatawrite(0) := '1';
            end if;
          when "00001110" =>            -- 0x0E DCache tags
            -- wait for write to complete in snoop tag pipeline
            if bifo.stat.idle='0' then
              v.s := r.s;
            end if;
          when "00001111" =>            -- 0x0F DCache data
            ocrami.ddataen(0 to DWAYS-1) := r.d2hitv;
            if (r.d2vaddr(2)='0' xor (endian='1')) or r.d2size="11" then
              ocrami.ddatawrite(7 downto 4) := "1111";
            end if;
            if (r.d2vaddr(2)='1' xor (endian='1')) or r.d2size="11" then
              ocrami.ddatawrite(3 downto 0) := "1111";
            end if;
          when "00011110" =>            -- 0x1E snoop tags
            -- wait for write to complete in snoop tag pipeline
            if bifo.stat.idle='0' then
              v.s := r.s;
            end if;
          when "00100110" =>            -- 0x26 Instruction TCM
           if itcmen /= 0 then
            ocrami.itcmen := '1';
            ocrami.idatawrite := "00";
            if (r.d2vaddr(2)='0' xor (endian='1')) or r.d2size="11" then
              ocrami.idatawrite(1) := '1';
            end if;
            if (r.d2vaddr(2)='1' xor (endian='1')) or r.d2size="11" then
              ocrami.idatawrite(0) := '1';
            end if;
           end if;
          when "00100111" =>            -- 0x27 Data TCM
           if dtcmen /= 0 then
            ocrami.dtcmen := '1';
            if (r.d2vaddr(2)='0' xor (endian='1')) or r.d2size="11" then
              ocrami.ddatawrite(7 downto 4) := "1111";
            end if;
            if (r.d2vaddr(2)='1' xor (endian='1')) or r.d2size="11" then
              ocrami.ddatawrite(3 downto 0) := "1111";
            end if;
           end if;
          when "00101000" =>            -- 0x28 Stripe mapping table access
            if bifo.stat.idle='0' then
              v.s := r.s;
            end if;
          when "00101001" =>            -- 0x29 Extended cache tag access
            if r.d2vaddr(23)='1' then
              -- DCache tag or snoop tag
              -- wait for write to complete in snoop tag pipeline
              if bifo.stat.idle='0' then
                v.s := r.s;
              end if;
            else
              -- ICache tag
              ocrami.itagen(0 to IWAYS-1) := r.i2hitv;
              ocrami.itagwrite := '1';
            end if;
          when others =>
            null;
        end case;
       else
        assert false report "Reached as_wrasi2!" severity failure;
       end if;

      when as_wrasi3 =>
       if arch = SPARC or ext_noelv = 1 then
        v.ramreload := r.ramreload;
        odco.mds := '0';
        odco.mexc := bifo.rdb.err;
        v.slowwrpend := '0';
        v.s := as_normal;
       else
        assert false report "Reached as_wrasi3!" severity failure;
       end if;

      when as_rdasi =>
       if arch = SPARC or ext_noelv = 1 then
        obifi.clrrdbuf := '1';
        v.dregmux := '1';
        v.dregval := (others => '0');
        case r.d2asi is
          when "00000010" =>            -- 0x02 System control registers
            if vwidereg='1' then
              v.dregval := vwideregrdata;
            elsif (not (endian='1')) then
              v.dregval := vregrdata0 & vregrdata1;
            else
              v.dregval := vregrdata1 & vregrdata0;
            end if;
            v.dregerr := vbadreg;
            v.s := as_rdasi2;
            if r.d2vaddr(6 downto 3)="0100" then
              -- Access to AHB error / AHB error address / AHB extended address
              -- register
              -- Note that d2paddrbs logic above applies to this access so
              -- address bits (:DOFFSET_HIGH+4) selects stripe.
              vdlyop := '1'; -- need extra cycle for d2paddrba generation above
              v.bifwait_op := BIFOP_AREGR;
              v.s := as_dcsingle;
            end if;
            -- Pass through current values of mmuwtrapmode and ahbwtrapmode into
            -- store data bits going into the busif, used for reading the AHB error
            -- register
            v.d2data(63 downto 60) := r.mmuwtrapmode & r.ahbwtrapmode;
            v.d2data(31 downto 28) := r.mmuwtrapmode & r.ahbwtrapmode;

          when "00001100" =>            -- 0x0C ICache tags
            v.s := as_rdcdiag;

          when "00001101" =>            -- 0x0D ICache data
            v.s := as_rdcdiag;

          when "00001110" =>            -- 0x0E DCache tags
            v.s := as_rdcdiag;

          when "00001111" =>            -- 0x0F DCache data
            v.s := as_rdcdiag;

          when "00011001" =>            -- 0x19 MMU registers
           if arch = SPARC then
            v.dregval := vregrdata0 & vregrdata0;
            v.s := as_rdasi2;
            if r.d2vaddr(10 downto 8)="011" then
              -- MMU Fault status register fields self-clearing on read
              -- but not if read through DSU
              if dci.dsuen='0' then
                v.mmfsr.ft := "000";
                v.mmfsr.fav := '0';
                v.mmfsr.ow := '0';
              end if;
            end if;
           else
            v.dregerr := '1';
            v.s := as_rdasi2;
           end if;

          when "00011011" =>            -- 0x1B MMU flush/probe
           if arch = SPARC or mmuen = 1 then
            if r.d2vaddr(11)='1' or (r.d2vaddr(10)='1' and r.d2vaddr(9 downto 8)/="00") then
              -- Undefined probe type -- return 0
              v.dregval := (others => '0');
              v.s := as_rdasi2;
            elsif r.d2vaddr(10)='1' then
              -- Return data from DTLB if address matched and "entire" mode
              if r.d2tlbamatch='1' then
                if arch = SPARC then
                  v.dregval(31 downto 8) := r.dtlb(to_integer(unsigned(r.d2tlbid))).paddr;
                  v.dregval(7) := r.dtlb(to_integer(unsigned(r.d2tlbid))).cached;
                  v.dregval(6) := r.dtlb(to_integer(unsigned(r.d2tlbid))).modified;
                  v.dregval(5) := '1';    -- referenced
                  v.dregval(4 downto 2) := r.dtlb(to_integer(unsigned(r.d2tlbid))).acc;
                  v.dregval(1 downto 0) := "10";  -- PTE
                  v.dregval(63 downto 32) := v.dregval(31 downto 0);
                end if;
                v.s := as_rdasi2;
              else
                -- Try reading from ITLB
                v.s := as_mmuprobe2;
                v.i1pc := r.d2vaddr;
                v.d2vaddr := r.i1pc;
              end if;
            else
              -- Fall back to MMU walk
              if arch = SPARC then
                v.s := as_mmuwalk;
              else -- arch = RISCV
                start_walk := true;
              end if;
              v.mmusel := "0101";
            end if;
           else
            v.dregerr := '1';
            v.s := as_rdasi2;
           end if;

          when "00011100" =>            -- 0x1C MMU/Cache bypass
            -- Update registers and jump back to normal to handle in standard
            -- path
            v.d2paddr := (others => '0');
            v.d2paddr(31 downto 0) := r.d2vaddr(31 downto 0);
            v.d2paddrv := '1';
            v.d2busw := dec_wbmask_fixed(r.d2vaddr(31 downto 2), xwbmask);
            v.d2asi := "000" & ASI_SDATA;
            v.d2specialasi := '0';
            v.d2su := '1';
            v.d2hitv := (others => '0');
            v.d2nocache := '1';
           if arch = SPARC or not pmaen then
            v.s := as_normal;
           else
            -- v.pmp_mask is already set from above. Always 4 kByte.
            v.pmp_low    := fit0ext(v.d2paddr, v.pmp_low);
            v.pmp_do     := '1';
            v.s          := as_rv_check_busw;
           end if;

          when "00011110" =>            -- 0x1E  Snoop tags
            vdlyop := '1'; -- need extra cycle for d2paddrba generation above
            v.bifwait_op := BIFOP_STAGR;
            -- Jump directly to dcsingle and wait for the data to come out
            v.s := as_dcsingle;

          when "00100000" =>            -- 0x20  FPC control/debug
           if arch = SPARC then
            v.dregval := r.dregval;
            v.fpc_mosi.accen := '1';
            v.fpc_mosi.accwr := '0';
            if r.fpc_mosi.accen='0' then
              v.fpc_mosi.addr(0) := r.d2vaddr(2);
            elsif r.fpc_mosi.accen='1' and fpc_miso.accrdy='1' and r.d2size="11" then
              v.fpc_mosi.addr(0) := '1';
            end if;
            if r.fpc_mosi.addr(0)='0' xor endian='1' then
              v.dregval(63 downto 32) := fpc_miso.rddata;
            else
              v.dregval(31 downto 0) := fpc_miso.rddata;
            end if;
            if r.fpc_mosi.accen='1' and fpc_miso.accrdy='1' then
              if r.d2size /= "11" or r.fpc_mosi.addr(0)='1' then
                v.s := as_rdasi2;
                v.fpc_mosi.accen := '0';
              end if;
            end if;
           else
            v.dregerr := '1';
            v.s := as_rdasi2;
           end if;

          when "00100001" =>            -- 0x21  CPC (co-processor) control/debug
           if arch = SPARC then
            v.dregerr := '1';
            v.s := as_rdasi2;
           else
            v.dregerr := '1';
            v.s := as_rdasi2;
           end if;

          when "00100010" =>            -- 0x22 CPU-to-CPU interface
           if arch = SPARC then
            v.dregval := r.dregval;
            v.c2c_mosi.accen := '1';
            v.c2c_mosi.accwr := '0';
            if r.c2c_mosi.accen='0' then
              v.c2c_mosi.addr(0) := r.d2vaddr(2);
            elsif r.c2c_mosi.accen='1' and c2c_miso.accrdy='1' and r.d2size="11" then
              v.c2c_mosi.addr(0) := '1';
            end if;
            if r.c2c_mosi.addr(0)='0' xor endian='1' then
              v.dregval(63 downto 32) := c2c_miso.rddata;
            else
              v.dregval(31 downto 0) := c2c_miso.rddata;
            end if;
            if r.c2c_mosi.accen='1' and c2c_miso.accrdy='1' then
              if r.d2size /= "11" or r.c2c_mosi.addr(0)='1' then
                v.s := as_rdasi2;
                v.c2c_mosi.accen := '0';
              end if;
            end if;
           else
            v.dregerr := '1';
            v.s := as_rdasi2;
           end if;

          when "00100011" =>            -- 0x23 TLB diagnostic access
            if arch = SPARC then
            -- d2vaddr(9) -- I / D
            -- d2vaddr(8) -- PMRU state
            -- d2vaddr(7 downto 3) -- entry
            if r.d2vaddr(9)='0' then
              v.newent := r.dtlb(to_integer(unsigned(r.d2vaddr(2+log2x(dtlbnum) downto 3))));
            else
              v.newent := r.itlb(to_integer(unsigned(r.d2vaddr(2+log2x(itlbnum) downto 3))));
            end if;
              if r.d2vaddr(8)='0' then
                d32 := (others => '0');
                d32(31 downto 12) := v.newent.vaddr;
                d32(11 downto 4) := v.newent.ctx;
                d32(3) := v.newent.mask(1);
                d32(2) := v.newent.mask(2);
                d32(1) := v.newent.mask(3);
                d32(0) := v.newent.valid;
                if (not (endian='1')) then
                  v.dregval(63 downto 32) := d32;
                else
                  v.dregval(31 downto 0) := d32;
                end if;
                d32 := (others => '0');
                d32(31 downto 12) := v.newent.paddr(31 downto 12);
                d32(9 downto 6) := v.newent.paddr(35 downto 32);
                d32(5 downto 3) := v.newent.acc;
                d32(2) := v.newent.busw;
                d32(1) := v.newent.cached;
                d32(0) := v.newent.modified;
                if (not (endian='1')) then
                  v.dregval(31 downto 0) := d32;
                else
                  v.dregval(63 downto 32) := d32;
                end if;
              else
                if r.d2vaddr(9)='0' then
                  for x in 0 to dtlbnum-1 loop
                    v.dregval(x) := r.dtlbpmru(x);
                    v.dregval(32+x) := r.dtlbpmru(x);
                  end loop;
                else
                  for x in 0 to itlbnum-1 loop
                    v.dregval(x) := r.itlbpmru(x);
                    v.dregval(32+x) := r.itlbpmru(x);
                  end loop;
                end if;
              end if;
            elsif (mmuen = 1 or walk_pmp) and ext_noelv = 1 then
              -- d2vaddr(11)         - paddr instead of vaddr
              -- d2vaddr(10)         - H
              -- d2vaddr(9)          - I / D
              -- d2vaddr(8)          - PMRU state, and VMID/ASID
              -- d2vaddr(7 downto 3) - entry
              v.dregval := (others => '0');
              if r.d2vaddr(9) = '1' then
                entry   := r.htlb(u2i(r.d2vaddr(2 + log2x(htlbnum) downto 3)));
              else
                if r.d2vaddr(10) = '0' then
                  entry := r.dtlb(u2i(r.d2vaddr(2 + log2x(dtlbnum) downto 3)));
                else
                  entry := r.itlb(u2i(r.d2vaddr(2 + log2x(itlbnum) downto 3)));
                end if;
              end if;
              if r.d2vaddr(8) = '0' then
                d64                           := (others => '0');

                if r.d2vaddr(11) = '0' then
                  d64(entry.vaddr'range)      := entry.vaddr;

                  d64(rv_pte_v)               := entry.valid;
                  if mmuen = 1 then
                    d64(rv_pte_u downto rv_pte_r) := get_lo(entry.perm, 4);
                    if enable_g = 1 then
                      d64(rv_pte_g)           := entry.global;
                    end if;
                    d64(rv_pte_a)             := get_hi(entry.perm);  -- "S"
                    d64(rv_pte_d)             := entry.modified;
                  end if;
                  -- The RSW bits are for software, so free to use.
                  -- Also, address shifted up by two compared to PTE,
                  -- to fit with paddr'range, giving two more bits.
                  -- Enough mask bits for up to Sv48.
                  d64(rv_pte_rsw'low + entry.mask'length - 1 downto rv_pte_rsw'low) := entry.mask;
                  if ext_h = 1 then
                    d64(rv_pte_pbmt'low - 11) := entry.h_r;
                  end if;
                  if ext_h = 1 and actual_tlb_pmp and (pmpen or pmaen) then
                    d64(rv_pte_pbmt'low - 10) := entry.pmp_r;
                    d64(rv_pte_pbmt'low - 9)  := entry.pmp_no_w;
                    d64(rv_pte_pbmt'low - 8)  := entry.pmp_no_x;
                  end if;
                  -- Save two bits here for later.
                  d64(rv_pte_pbmt'low - 5)    := entry.cached;
                  d64(rv_pte_pbmt'low - 4)    := entry.busw;
                  d64(rv_pte_pbmt'low - 1 downto rv_pte_pbmt'low - 3) := entry.mode;
                  if ext_svpbmt = 1 then
                    d64(rv_pte_pbmt'range)    := entry.pbmt;
                  end if;
                  if ext_svnapot = 1 then
                    d64(rv_pte_n)             := entry.svnapot;
                  end if;
                else
                  d64(entry.paddr'range)      := entry.paddr;

                  if pmaen then
                    assert PMA_SIZE <= 12 report "Too large PMA" severity failure;
                    d64(PMA_SIZE - 1 downto 0) := from_pma(entry.pma);
                  end if;
                  if walk_pmp then
                    d64(59)                   := entry.pmp_none;
                    d64(60)                   := entry.pmp_lock;
                    d64(63 downto 61)         := entry.pmp_rwx;
                  end if;
                end if;

                v.dregval := d64;
              else
                -- This returns PMRU with TLB entry n represented by bit n.
                if ext_h = 1 and r.d2vaddr(9) = '1' then
                  v.dregval   := uext(entry.ctx & uext(make_downto0(r.htlbpmru), 32), v.dregval);
                elsif mmuen = 1 then
                  if r.d2vaddr(10) = '0' then
                    v.dregval := uext(entry.ctx & uext(make_downto0(r.dtlbpmru), 32), v.dregval);
                  else
                    v.dregval := uext(entry.ctx & uext(make_downto0(r.itlbpmru), 32), v.dregval);
                  end if;
                end if;
              end if;
            end if;
            v.s := as_rdasi2;

          when "00100100" =>            -- 0x24 IU BTB/BHT diagnostic interface
            v.dregval := r.dregval;
            v.iudiag_mosi.accen := '1';
            v.iudiag_mosi.accwr := '0';
            if r.iudiag_mosi.accen='0' then
              v.iudiag_mosi.addr(0) := r.d2vaddr(2);
            elsif r.iudiag_mosi.accen='1' and dci.iudiag_miso.accrdy='1' and r.d2size="11" then
              v.iudiag_mosi.addr(0) := '1';
            end if;
            if r.iudiag_mosi.addr(0)='0' xor endian='1' then
              v.dregval(63 downto 32) := dci.iudiag_miso.rddata;
            else
              v.dregval(31 downto 0) := dci.iudiag_miso.rddata;
            end if;
            if r.iudiag_mosi.accen='1' and dci.iudiag_miso.accrdy='1' then
              if r.d2size /= "11" or r.iudiag_mosi.addr(0)='1' then
                v.s := as_rdasi2;
                v.iudiag_mosi.accen := '0';
              end if;
            end if;

          when "00100101" =>         -- 0x25 Cache LRU diagnostic interface
            if r.d2vaddr(31)='1' then
              v.dregval(4 downto 0) := ilruent;
            else
              v.dregval(4 downto 0) := dlruent;
            end if;
            v.dregval(63 downto 32) := v.dregval(31 downto 0);
            v.s := as_rdasi2;

          when "00100110" =>            -- 0x26 Instruction TCM access
            if itcmen=0 then
              v.dregerr := '1';
              v.s := as_rdasi2;
            else
              v.s := as_rdcdiag;
            end if;

          when "00100111" =>            -- 0x27 Data TCM access
            if dtcmen=0 then
              v.dregerr := '1';
              v.s := as_rdasi2;
            else
              v.s := as_rdcdiag;
            end if;


          when "00101001" =>            -- 0x29 Extended tag access
            if r.d2vaddr(23 downto 22)="11" then
              -- Snoop tags
              vdlyop := '1'; -- need extra cycle for d2paddrba generation above
              v.bifwait_op := BIFOP_STAGRX;
              -- Jump directly to dcsingle and wait for the data to come out
              v.s := as_dcsingle;
            else
              v.s := as_rdcdiag;
            end if;

          when x"2e" =>                 -- Data output from PMUU test etc
            if arch = RISCV and (mmuen = 1 or walk_pmp) and ext_noelv = 1 then
              d64 := (others => '0');
              if r.d2vaddr(5 downto 3) = "011" then                    -- 24
                if walk_fault then
                  d64(0)            := r.swalk_fault;
                  d64(1)            := r.hwalk_fault;
                  v.swalk_fault     := '0';
                  v.hwalk_fault     := '0';
                end if;
              -- 0 PMP+PMA, 8 only PMP, 16 PMA
              elsif r.d2vaddr(5) = '0' then
                if r.d2vaddr(4) = '0' then
                  if actual_tlb_pmp and pmp_mmuu_test = 1 then         -- 0/8
                    d64( 5 downto  0) := uext(r.pmp_idx, 6);
                    d64(6)            := r.pmp_hit;
                    d64(7)            := r.pmp_fit;
                    d64(31 downto 16) := fit0ext(r.pmp_hitv, 8) & fit0ext(r.pmp_fitv, 8);
                    d64(34 downto 32) := r.pmp_rwx;
                    d64(35)           := r.pmp_lock;
                    d64(36)           := r.pmp_none;
                    d64(42 downto 40) := r.pmp_m_rwx;
                    d64(46 downto 44) := r.pmp_su_rwx;
                  end if;
                else                                                   -- 16
                  if actual_tlb_pmp and pma_mmuu_test = 1 then
                    d64( 5 downto  0) := uext(r.pma_idx, 6);
                    d64(6)            := r.pma_hit;
                    d64(7)            := r.pma_fit;
                    d64(31 downto 16) := fit0ext(r.pma_hitv, 8) & fit0ext(r.pma_fitv, 8);
                    d64(63 downto 32) := uext(from_pma(r.pma), 32);
                  end if;
                end if;
              elsif r.d2vaddr(5) = '1' and tlb_valid_r = 1 then
                if r.d2vaddr(4 downto 3) = "00" then                   -- 32
                  for x in r.dtlb'range loop
                    d64(x) := r.dtlb(x).valid;
                  end loop;
                elsif r.d2vaddr(4 downto 3) = "01" then                -- 40
                  for x in r.itlb'range loop
                    d64(x) := r.itlb(x).valid;
                  end loop;
                elsif r.d2vaddr(4 downto 3) = "10" and ext_h = 1 then  -- 48
                  for x in r.htlb'range loop
                    d64(x) := r.htlb(x).valid;
                  end loop;
                else                                                   -- 56
                  for x in r.dtlb'range loop
                    d64(x) := r.dtlb(x).valid;
                  end loop;
                  for x in r.itlb'range loop
                    d64(x + r.dtlb'length) := r.itlb(x).valid;
                  end loop;
                  if ext_h = 1 then
                    for x in r.htlb'range loop
                      d64(x + r.dtlb'length + r.itlb'length) := r.htlb(x).valid;
                    end loop;
                  end if;
                end if;
              end if;
              v.dregval := d64;
            else
              v.dregerr := '1';
            end if;
            v.s := as_rdasi2;

          when x"2f" =>                 -- Extra 64 bits of ASI data
            if arch = RISCV then
              -- 32 bit access?
              if r.d2size /= "11" then
                -- Read high part, assuming that low was read
                -- by another ASI earlier.
                -- Swap words to enable other half to be read later.
                v.dregval := lo_h(r.bregval) & hi_h(r.bregval);
              else
                v.dregval := r.bregval;
              end if;
            else
              v.dregerr := '1';
            end if;
            v.s := as_rdasi2;


          when others =>                -- Unimplemented ASI
            v.dregerr := '1';
            v.s := as_rdasi2;
        end case;
        if v.s=as_rdcdiag then
          -- Set irdbufaddr/iramaddr regs for Icache diag accesses
          v.irdbufvaddr := r.d2vaddr(r.irdbufvaddr'range);
          v.iramaddr := r.d2vaddr(r.iramaddr'high downto r.iramaddr'low);
        end if;

        if arch = RISCV then
          -- Ensure we can read out all of a 64 bit value even on RV32
          v.bregval := v.dregval;
        end if;
       end if;

      when as_rdasi2 =>
        v.s := as_normal;
        v.dmisspend := '0';

      when as_rdcdiag =>
       if arch = SPARC or ext_noelv = 1 then
        ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.irdbufvaddr(IOFFSET_HIGH downto IOFFSET_LOW);
        ocrami.idataoffs(log2(ilinesize)-2 downto 0) := r.iramaddr;
        ocrami.ifulladdr := r.d2vaddr(ocrami.ifulladdr'range);
        ocrami.itagen := "1111";
        ocrami.idataen := "1111";
        ocrami.itcmen := '1';
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ddatafulladdr := r.d2vaddr(ocrami.ddatafulladdr'range);
        ocrami.ddatafulladdrw := r.d2vaddr(ocrami.ddatafulladdrw'range);
        ocrami.dtagcen := (others => '1');
        ocrami.ddataen := (others => '1');
        ocrami.dtcmen := '1';
        v.s := as_rdcdiag2;
       else
        v.dregerr := '1';
        v.s := as_rdcdiag2;
       end if;

      when as_rdcdiag2 =>
       if arch = SPARC or ext_noelv = 1 then
        v.s := as_rdasi2;
        v.dregmux := '1';
        -- 0x0C ITags --> 000 x00
        -- 0x0D IData --> 001 x01
        -- 0x0E DTags --> 010 010
        -- 0x0F DDaga --> 011 011
        -- 0x26 ITCM  --> 110 110
        -- 0x27 DTCM  --> 111 111
        vdiagasi := r.d2asi(5) & r.d2asi(1 downto 0);
        vwide := '0';
        if r.d2asi="00101001" then
          -- Convert ASI 0x29 address bits to diagasi and set wide flag
          -- Note snoop tags handled separately in as_rdasi, so this state
          --   does not get reached for ASI 0x1E.
          vdiagasi := "000";
          vdiagasi(1) := r.d2vaddr(23);
          vwide := '1';
        end if;
        d64 := (others => '0');
        -- Get read data into d64 variable
        case vdiagasi is
          when "000" | "100"  =>                  -- 0x0C ICache tags
            d32 := cramo.itagdout(to_integer(unsigned(r.d2vaddr(ITAG_LOW+1 downto ITAG_LOW))));
            d64(ITAG_HIGH downto ITAG_LOW) := d32(ITAG_HIGH-ITAG_LOW+1 downto 1);
            d64(7 downto 0) := (others => d32(0));
          when "001" | "101" =>                  -- 0x0D ICache data
            d64 := cramo.idatadout(to_integer(unsigned(r.d2vaddr(ITAG_LOW+1 downto ITAG_LOW))));
            vwide := '1';
          when "010" =>                  -- 0x0E DCache tags
            d32 := dctagsv(to_integer(unsigned(r.d2vaddr(DTAG_LOW+1 downto DTAG_LOW))));
            d64(DTAG_HIGH downto DTAG_LOW) := d32(DTAG_HIGH-DTAG_LOW+1 downto 1);
            d64(7 downto 0) := (others => d32(0));
          when "110" =>                -- 0x26 ITCM
            d64 := cramo.itcmdout;
            vwide := '1';
          when "111"  =>                -- 0x27 DTCM
            d64 := cramo.dtcmdout;
            vwide := '1';
          when others =>                -- 0x0F DCache data
            d64 := cramo.ddatadout(to_integer(unsigned(r.d2vaddr(DTAG_LOW+1 downto DTAG_LOW))));
            vwide := '1';
        end case;
        -- Mux d64 into dregval
        v.dregval := d64;
        if vwide='0' then
          v.dregval(63 downto 32) := d64(31 downto 0);
        end if;
        -- must set ramreload here since we have done a Itag read from another addr
        v.ramreload := '1';
       else
        v.dregerr := '1';
        v.s := as_rdasi2;
       end if;

      when as_atomic1 =>
        obifi.clrrdbuf := '1';
        -- Drive Dcache tag/data addresses
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ddatafulladdr := r.d2vaddr(ocrami.ddatafulladdr'range);
        if r.d2nocache='0' then
          if bifo.stat.locked='1' then
            -- We have lock and no potential snoop write in pipe.
            -- Proceed to check tags for match
            -- to see if we can perform the load part of the atomic in the Dcache
            -- In the case of forced miss we still need to see if we are in cache
            -- in order to replace the same way.
            v.s := as_atomic2;
            v.dtlbbypass := '1';           -- use d2paddr
            ocrami.dtagcen := (others => '1');
            ocrami.ddataen := (others => '1');
            v.d1ten := '1';
          end if;
        else
          if r.biflocked='1' then
            -- We have lock, proceed to perform bus access
            obifi.bifop := BIFOP_SMFET;
            v.bifwait_op := BIFOP_SMFET;
            v.s := as_dcsingle;
          end if;
        end if;
        -- Request lock on desired bus
        -- Note: for multi-bus/striped implementation we wait for previous
        -- accesses to have completed, to avoid locking the stripe while waiting
        -- for stores on other buses to complete.
        if r.biflocked='0' and (
                                bifo.stat.idle='1') then
          vtoglock := '1';
        end if;

      when as_atomic2 =>
        obifi.clrrdbuf := '1';
        -- Drive Dcache tag/data addresses
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ddatafulladdr := r.d2vaddr(ocrami.ddatafulladdr'range);
        ocrami.ddatafulladdrw := r.d2vaddr(ocrami.ddatafulladdrw'range);
        -- Tag/data check for atomic
        -- Capture hit/valid status
        v.d2hitv := dhitv;
        v.d2validv := dvalidv;
        --
        odco.mds := '0';
        v.d2cascmp := (others => '0');
        v.d1ten := r.d1chk and dcache_active(r_cctrl);
        if arch = SPARC then
          for w in 0 to DWAYS-1 loop
            for p in 0 to 1 loop
              if cramo.ddatadout(w)(32*p+31 downto 32*p)=r.d2casdata then
                v.d2cascmp(2*w+p) := '1';
              end if;
            end loop;
          end loop;
          if r.d2cas='0' then
            ocrami.ddataen(0 to DWAYS-1) := dhitv;
          end if;
        else -- arch = RISCV
          for w in 0 to DWAYS-1 loop
            if dhitv(w) = '1' then
              v.amo.data := cramo.ddatadout(w);
            end if;
          end loop;
          if r.d2cas='0' and (r.amo.d2type(1 downto 0) = "01" or
                              (r.amo.d2type(1 downto 0) = "11" and r.amo.reserved = '1')) then
            ocrami.ddataen(0 to DWAYS-1) := dhitv;
          end if;
        end if;
        ocrami.ddatawrite := getdmask64(r.d2vaddr,r.d2size,(endian='1'));
        ocrami.ddatadin := (others => r.d2data);
        if r.amo.d2type(1 downto 0) = "10" then -- LR
          v.amo.addr     := r.d2paddr(v.amo.addr'range);
          v.amo.reserved := '1';
          obifi.lr_set := '1';
          obifi.stdata := (others => '0');
          obifi.stdata(r.d2paddr'range) := r.d2paddr;
        end if;
        if (r.d2cas='1' or r.amo.d2type(1 downto 0) = "00")
           and dhit='1' and r.d2forcemiss='0' then
          -- Allow another cycle for CAS in order to not depend combinatorially on
          -- cache data comparison
          v.s := as_atomic3;
        elsif dhit='1' and r.d2forcemiss='0' then
          -- We got the read data from cache, we need to update cache with
          -- write data and perform store
          if arch = SPARC then
            v.d2atomic := '0';
            v.d2write := '1';
            v.dmisspend := '0';
            v.slowwrpend := '1';
            v.s := as_slowwr;             -- TODO jump directly to as_store instead
            v.ramreload := '1';
          else -- arch = RISCV
            v.d2atomic := '0';
            v.dmisspend := '0';
            v.slowwrpend := '0';
            v.ramreload := '1';
            if r.amo.d2type(1 downto 0) = "11" then -- SC
              -- clear reservation on SC
              v.amo.reserved := '0';
              obifi.lr_clr := '1';
              for i in dhitv'range loop
                if dhitv(i) = '1' then
                  odco.data(i)    := (others => '0');
                end if;
              end loop;
            end if;
            if r.amo.d2type(1 downto 0) = "01" or
              (r.amo.d2type(1 downto 0) = "11" and r.amo.reserved = '1' and
               bifo.stat.lr_valid = '1' and
               r.d2paddr(r.amo.addr'range) = r.amo.addr) then
              v.d2write := '1';
              v.slowwrpend := '1';
              v.s := as_slowwr;             -- TODO jump directly to as_store instead
            else
              -- SC and no valid reservation, we are done!
              if r.amo.d2type(1 downto 0) = "11" then -- SC
                for i in dhitv'range loop
                  if dhitv(i) = '1' then
                    odco.data(i)(0) := '1';
                    if r.d2size = "10" then
                      odco.data(i)(32) := '1';
                    end if;
                  end if;
                end loop;
              end if;
              ocrami.ddatawrite := (others => '0');
              --v.s := as_normal;
              v.s := as_bifwait_unlock;
            end if;
          end if;
        else
          -- Not in cache, fall back to bus access
          if r.d2nocache='0' then
            obifi.bifop := BIFOP_DLFET;
            v.bifwait_op := BIFOP_DLFET;
            v.s := as_dcfetch;
            v.perf(2) := '1';
          else
            obifi.bifop := BIFOP_SMFET;
            v.bifwait_op := BIFOP_SMFET;
            v.s := as_dcsingle;
          end if;
          v.ramreload := '1';
        end if;

      when as_atomic3 =>
        -- CAS check for cache hit
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ddatafulladdr := r.d2vaddr(ocrami.ddatafulladdr'range);
        ocrami.ddatafulladdrw := r.d2vaddr(ocrami.ddatafulladdrw'range);
        ocrami.ddatadin := (others => r.d2data);
        vcashit := '0';
        if arch = SPARC then
          -- Note d2cascmp here is two bits per cache way from the cache data RAM outputs
          for w in 0 to DWAYS-1 loop
            if r.d2hitv(w)='1' and
              ( (r.d2vaddr(2)='0' and r.d2cascmp(2*w+1)='1') or
                (r.d2vaddr(2)='1' and r.d2cascmp(2*w)='1') ) then
              vcashit := '1';
              ocrami.ddataen(w) := '1';
            end if;
          end loop;
          if r.d2vaddr(2)='0' xor (endian='1') then
            ocrami.ddatawrite := "11110000";
            v.d2data(31 downto 0) := r.d2data(63 downto 32);
          else
            ocrami.ddatawrite := "00001111";
            v.d2data(63 downto 32) := r.d2data(31 downto 0);
          end if;
          ocrami.ddatadin := (others => r.d2data);
        else -- arch = RISCV
          if r.amo.d2type(1 downto 0) /= "10" then -- not LR
            vcashit := '1';
          end if;
          for w in 0 to DWAYS-1 loop
            if r.d2hitv(w)='1' then
              ocrami.ddataen(w) := '1';
            end if;
          end loop;
          v.d2data := amo_data;
          ocrami.ddatawrite := getdmask64(r.d2vaddr,r.d2size,(endian='1'));
          ocrami.ddatadin := (others => amo_data); --(others => r.d2data);
        end if;
        v.d2atomic := '0';
        v.dmisspend := '0';
        v.slowwrpend := '0';
        v.ramreload := '1';
        if vcashit='1' then
          -- We got the read data from cache, we need to update cache with
          -- write data and perform store
          v.d2write := '1';
          v.slowwrpend := '1';
          v.s := as_slowwr;             -- TODO jump directly to as_store instead
        else
          -- CAS miscompare, we are done!
          --v.s := as_normal;
          v.s := as_bifwait_unlock;
        end if;

      when as_atomic4 =>
        -- Atomic after data load from bus
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataindex(DOFFSET_BITS-1 downto 0) := r.d2vaddr(DOFFSET_HIGH downto DOFFSET_LOW);
        ocrami.ddataoffs(log2(dlinesize)-2 downto 0) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ddatafulladdr := r.d2vaddr(ocrami.ddatafulladdr'range);
        ocrami.ddatafulladdrw := r.d2vaddr(ocrami.ddatafulladdrw'range);
        ocrami.ddatadin := (others => r.d2data);
        ocrami.ddataen := (others => '0');
        vcashit := '0';
        if arch = SPARC then
          -- Note d2cascmp here is one bit per word in the cache line fetched
          for x in 0 to DLINESIZE-1 loop
            if r.d2vaddr(DLINE_HIGH downto DLINE_LOW)=std_logic_vector(to_unsigned(x,DLINE_BITS)) and r.d2cascmp(x)='1' then
              vcashit := '1';
            end if;
          end loop;
          if r.d2vaddr(2)='0' xor (endian='1') then
            ocrami.ddatawrite := "11110000";
            v.d2data(31 downto 0) := r.d2data(63 downto 32);
          else
            ocrami.ddatawrite := "00001111";
            v.d2data(63 downto 32) := r.d2data(31 downto 0);
          end if;
        else
          if r.amo.d2type(1 downto 0) /= "10" then -- not LR
            vcashit := '1';
          end if;
          v.d2data := amo_data;
          ocrami.ddatawrite := getdmask64(r.d2vaddr,r.d2size,(endian='1'));
          ocrami.ddatadin := (others => amo_data);
          if r.amo.d2type(1 downto 0) = "11" then -- SC
            -- clear reservation on SC
            v.amo.reserved  := '0';
            obifi.lr_clr    := '1';
            odco.data(0)    := (others => '0');
            odco.mds        := '0';
            odco.way        := "00";
          end if;
        end if;
        v.d2atomic := '0';
        v.dmisspend := '0';
        v.slowwrpend := '0';
        if arch = SPARC then
          if r.d2cas='0' or vcashit='1' then
            ocrami.ddataen(0 to DWAYS-1) := r.d2hitv;
            v.d2write := '1';
            v.slowwrpend := '1';
            v.s := as_slowwr;             -- TODO jump directly to as_store instead
          else
            -- CAS miscompare, we are done!
            --v.s := as_normal;
            v.s := as_bifwait_unlock;
          end if;
        else -- arch = RISCV
          if vcashit = '1' and
             (r.amo.d2type(1 downto 0) /= "11" or
              (r.amo.reserved = '1' and bifo.stat.lr_valid = '1' and
              r.d2paddr(r.amo.addr'range) = r.amo.addr)) then
            ocrami.ddataen(0 to DWAYS-1) := r.d2hitv;
            v.d2write := '1';
            v.slowwrpend := '1';
            v.s := as_slowwr;             -- TODO jump directly to as_store instead
          else
            -- CAS miscompare, we are done!
            -- SC and no valid reservation, we are done!
            if r.amo.d2type(1 downto 0) = "11" then -- SC
              odco.data(0)(0) := '1';
              if r.d2size = "10" then
                odco.data(0)(32) := '1';
              end if;
            end if;
            --v.s := as_normal;
            v.s := as_bifwait_unlock;
          end if;
        end if;

      when as_parked =>
        oico.parked := '1';
        if ici.parkreq='0' then
          v.s := as_normal;
        end if;

      when as_mmuprobe2 =>
        -- Swap back addresses
        v.i1pc := r.d2vaddr;
        v.d2vaddr := r.i1pc;
        -- Check if ITLB hit
        if itlbamatch='1' then
          v.s := as_mmuprobe3;
        else
          -- Fall back to MMU walk
          if arch = SPARC then
            v.s := as_mmuwalk;
            obifi.bifop := BIFOP_SMFET;
            v.bifwait_op := BIFOP_SMFET;
            v.mmusel := "0101";
          else -- arch = RISCV
            start_walk := true;
          end if;
        end if;
        if arch = SPARC then
          obifi.size := "10";
          obifi.widebus := '0';
          v.mmuaddr(31 downto 0) := r.mmctrl1.ctxp(25 downto 4) & v.i2ctx & "00";
          obifi.busaddr := (others => '0');
          obifi.busaddr(31 downto 0) := v.mmuaddr(31 downto 0);
          obifi.mmuacc := '1';            -- for MMU walk access
        end if;

      when as_mmuprobe3 =>
        if arch = SPARC then
          v.dregval(31 downto 8) := r.itlb(to_integer(unsigned(r.itlbprobeid))).paddr;
          v.dregval(7) := r.itlb(to_integer(unsigned(r.itlbprobeid))).cached;
          v.dregval(6) := r.itlb(to_integer(unsigned(r.itlbprobeid))).modified;
          v.dregval(5) := '1';    -- referenced
          v.dregval(4 downto 2) := r.itlb(to_integer(unsigned(r.itlbprobeid))).acc;
          v.dregval(1 downto 0) := "10";  -- PTE
          v.dregval(63 downto 32) := v.dregval(31 downto 0);
        end if;
        v.s := as_rdasi2;

      when as_mmuflush2 =>
       if mmuen = 1 then
        -- Note use same registers for address/context as in regular TLB lookup
        -- should equality checks inside flushmatch function to be merged with
        -- regular TLB.
       if mmuen = 1 then
        if arch = SPARC then
          for e in 0 to itlbnum-1 loop
            ipc := r.i1pc_repl((e mod tlbrepl)*32+31 downto (e mod tlbrepl)*32);
            if flushmatch(r.itlb(e), ipc, r.i1ctx) = '1' then
              v.itlb(e).valid := '0';
            end if;
          end loop;
          for e in 0 to dtlbnum-1 loop
            dvaddr := r.d1vaddr_repl((e mod tlbrepl)*32+31 downto (e mod tlbrepl)*32);
            if flushmatch(r.dtlb(e), dvaddr, r.mmctrl1.ctx) = '1' then
              v.dtlb(e).valid := '0';
            end if;
          end loop;
        else -- arch = RISCV
          for e in 0 to itlbnum-1 loop
            tmpaddr(tlbabits-1 downto 0) := r.i1pc_repl((e mod tlbrepl)*vaddrbits+tlbabits-1 downto (e mod tlbrepl)*vaddrbits);
            if flushmatch(false, is_v(r.d2mode), r.itlb(e), tmpaddr(tlbabits-1 downto 0), r.d2data,
                          is_sv_smaller(csro, r.d2mode)) then
              v.itlb(e).valid := '0';
              v.perf(13) := '1';
            end if;
          end loop;
          for e in 0 to dtlbnum-1 loop
            tmpaddr(tlbabits-1 downto 0) := r.d1vaddr_repl((e mod tlbrepl)*vaddrbits+tlbabits-1 downto (e mod tlbrepl)*vaddrbits);
            if flushmatch(false, is_v(r.d2mode), r.dtlb(e), tmpaddr(tlbabits-1 downto 0), r.d2data,
                          is_sv_smaller(csro, r.d2mode)) then
              v.dtlb(e).valid := '0';
              v.perf(14) := '1';
            end if;
          end loop;
         if ext_h = 1 then
          for e in 0 to htlbnum-1 loop
            tmpaddr(tlbabits-1 downto 0) := r.h_addr_repl((e mod tlbrepl)*vaddrbits+tlbabits-1 downto (e mod tlbrepl)*vaddrbits);
            -- Only check hTLB for hfence.gvma
            if r.d2size = "10" then
              if flushmatch(true, false, r.htlb(e), tmpaddr(tlbabits-1 downto 0), r.d2data,
                            is_svx4_smaller(csro)) then
                v.htlb(e).valid := '0';
               v.perf(15) := '1';
             end if;
            end if;
          end loop;
         end if;
        end if;
       end if;
        v.s := as_normal;
        -- Swap back addresses to restore correct state
        --  use r.dregval is used as temp holding register for i1pc
        v.i1pc := r.dregval(v.i1pc'length-1 downto 0);
        v.i1ctx := r.dregval(r.i1ctx'length-1+r.i1pc'length downto r.i1pc'length);
        v.d1vaddr := r.d2vaddr;
        v.d2vaddr := r.d1vaddr;
        v.ramreload := '1';
        v.slowwrpend := '0';
       else
         assert false report "Reached as_mmuflush2!" severity failure;
       end if;

      when as_regflush =>
        ocrami.iindex := (others => '0');
        ocrami.iindex(IOFFSET_BITS-1 downto 0) :=
          r.flushctr(IOFFSET_HIGH downto IOFFSET_LOW);
        ocrami.idataoffs := (others => '0');
        for w in 0 to IWAYS-1 loop
          -- ocrami.itagdin(w) := (others => '0');
          ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW+1 downto ITAG_HIGH-ITAG_LOW-6) := x"FF";
          ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW-7 downto ITAG_HIGH-ITAG_LOW-8) := std_logic_vector(to_unsigned(w,2));
          ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW-9 downto ITAG_HIGH-ITAG_LOW-10) := std_logic_vector(to_unsigned(w,2));
          ocrami.itagdin(w)(ITAG_HIGH-ITAG_LOW+1 downto ITAG_HIGH-ITAG_LOW) := r.untagi(2*w+1 downto 2*w);
          ocrami.itagdin(w)(0) := '0';
        end loop;
        ocrami.dtagcindex := (others => '0');
        ocrami.dtagcindex(DOFFSET_BITS-1 downto 0) :=
          r.flushctr(DOFFSET_HIGH downto DOFFSET_LOW);

        obifi.busaddr := (others => '0');
        obifi.busaddr(DOFFSET_HIGH downto DOFFSET_LOW) := r.regflpipe(0).addr(DOFFSET_HIGH downto DOFFSET_LOW);
        obifi.stdata(3 downto 0) := uext(r.flushwrd, 4);
        obifi.stdata(4+2*DWAYS-1 downto 4) := r.untagd;
        -- Stage 3: Write back to itag/dtag
        vbubble0 := '0';
        vstall := '0';
        if r.regflpipe(0).valid='1' then
          if r.flushwri /= (r.flushwri'range => '0') then
            ocrami.iindex(IOFFSET_BITS-1 downto 0) := r.regflpipe(0).addr(IOFFSET_HIGH downto IOFFSET_LOW);
            ocrami.itagen(0 to IWAYS-1) := r.flushwri;
            ocrami.itagwrite := '1';
            vbubble0 := '1';
          end if;
          if dtagconf /= 0 then
            for w in 0 to DWAYS-1 loop
              if r.flushwrd(w)='1' then
                vbitclr(to_integer(unsigned(r.regflpipe(0).addr(DOFFSET_HIGH downto DOFFSET_LOW))))(w) := '1';
                -- vs.validarr(to_integer(unsigned(r.regflpipe(0).addr(DOFFSET_HIGH downto DOFFSET_LOW))))(w) := '0';
              end if;
            end loop;
          else
            if r.flushwrd /= (r.flushwrd'range => '0') then
              if bifo.stat.ready='1' then
                obifi.bifop := BIFOP_FLUSH;
              else
                vstall := '1';
              end if;
            end if;
          end if;
        end if;
        -- Special case - simultaneous flushwri and flushwrd and bifo.stat.ready is
        -- low. Prevent itag update until we stopped stalling to keep tag read
        -- data bus stable.
        if vstall='1' then
          ocrami.itagen := (others => '0');
        end if;
        if vstall='1' then
          v.regflpipe := r.regflpipe;
        end if;
        -- Stage 2: Compare with region flush mask
        -- Most is handled in region flush section above FSM, just handle stall
        -- here
        if vstall='1' then
          v.untagi := r.untagi;
          v.untagd := r.untagd;
          v.flushwrd := r.flushwrd;
          v.flushwri := r.flushwri;
        end if;
        -- Stage 1: Capture tags or itag/dtag write ongoing
        -- Most is handled in region flush section above FSM, just handle stall
        -- here
        if vstall='1' then
          v.dtagpipe := r.dtagpipe;
          v.itagpipe := r.itagpipe;
        end if;
        -- Stage 0: Command Read from tag RAMs
        if r.regfldone='0' and vbubble0='0' and vstall='0' then
          if r.flushpart(1)='1' then
            ocrami.itagen := (others => '1');
            ocrami.itagwrite := '0';
          end if;
          if r.flushpart(0)='1' then
            ocrami.dtagcen := (others => '1');
          end if;
          v.regflpipe(r.regflpipe'high).valid := '1';
          -- Advance counter, skip addrs guaranteed not to match
          --   set fixed bits to 1 before incrementing
          --   after incrementing, force fixed bits back to determined value
          vfoffs := r.flushctr;
          vfoffs := vfoffs or r.regflmask(MAXOFFSET_HIGH downto MAXOFFSET_LOW);
          if IOFFSET_LOW > DOFFSET_LOW and r.flushpart(0)='0' then
            vfoffs(MAXOFFSET_HIGH downto IOFFSET_LOW) := add(vfoffs(MAXOFFSET_HIGH downto IOFFSET_LOW),1);
          elsif DOFFSET_LOW > IOFFSET_LOW and r.flushpart(1)='0' then
            vfoffs(MAXOFFSET_HIGH downto DOFFSET_LOW) := add(vfoffs(MAXOFFSET_HIGH downto DOFFSET_LOW),1);
          else
            vfoffs(MAXOFFSET_HIGH downto MAXOFFSET_LOW) := add(vfoffs(MAXOFFSET_HIGH downto MAXOFFSET_LOW),1);
          end if;
          if vfoffs=(vfoffs'range => '0') then
            v.regfldone := '1';
          end if;
          vfoffs := vfoffs and not r.regflmask(MAXOFFSET_HIGH downto MAXOFFSET_LOW);
          vfoffs := vfoffs or (r.regflmask(MAXOFFSET_HIGH downto MAXOFFSET_LOW) and
                               r.regfladdr(MAXOFFSET_HIGH downto MAXOFFSET_LOW));
          v.flushctr := vfoffs;
        end if;

        if r.regfldone='1' then
          vhit := '0';
          for x in 0 to r.regflpipe'high loop
            if r.regflpipe(x).valid='1' then vhit := '1'; end if;
          end loop;
          if vhit='0' then
            v.ramreload := '1';
            v.s := as_normal;
            if r.flushpart(1)='1' then v.iflushpend:='0'; v.iregflush:='0'; end if;
            if r.flushpart(0)='1' then v.dflushpend:='0'; v.dregflush:='0'; end if;
          end if;
        end if;


      when as_bifwait =>
        v.stbuffull := not bifo.stat.ready;
        if bifo.stat.ready='1' then
          if r.biflocked = '1' or bifo.stat.locked='1' then
            v.s := as_bifwait_unlock;
          else
            v.s := as_normal;
          end if;
        end if;

      when as_bifwait_unlock =>
        v.ramreload := '1';
        obifi.bifop := BIFOP_NOP;
        v.bifwait_op := BIFOP_NOP;
        if bifo.stat.locked='0' then
          v.s := as_normal;
        end if;
      when as_rv_check_busw =>
        if pmaen then
          v.d2busw := pma_busw(v.pma);
          v.s      := as_normal;
        else
          v.s      := as_normal;
        end if;

      -- Delayed handling for symmetry with as_dfailkind below.
      when as_rv_ifailkind =>
        v.imisspend := '0';
        oico.mexc   := '1';
        oico.exctype:= r.ifailkind(0);
        v.imisspend := '0';
        v.ifailkind := "00";
        v.ramreload := '1';
        v.s         := as_normal;

      -- Delayed handling to lessen impact of odco.mds assert.
      when as_rv_dfailkind =>
        v.dmisspend  := '0';
        odco.mds     := '0';
        odco.mexc    := '1';
        odco.exctype := r.dfailkind(0);
        v.slowwrpend := '0';
        v.dmisspend  := '0';
        v.dfailkind  := "00";
        v.d1ten      := '0';
        v.d1tcmen    := '0';
        v.d1chk      := '0';
        v.ramreload  := '1';
        v.s          := as_normal;

      when as_rv_start_walk =>
       if mmuen = 1 and walk_state and not walk_sw then
          iaddr_ok  := true;
          daddr_ok  := true;

          v.newent  := tlbent_empty;


          -- Assume supervisor page tables need to be checked
          v.h_x    := '0';
          v.h_ls   := '0';
          v.h_mxr  := '0';
          v.h_vmxr := '0';
          v.h_hx   := '0';
          v.s      := as_rv_mmu_pt1addr_chk;

          -- On RISC-V, the base is indexed directly for the first level.
          -- Return physical address for next level of page table.
          -- Also, remember the V flag and perhaps set up a fake entry if hypervisor.
          mmu_data                                  := (others => '0');
          case r.mmusel is
          when access_i =>
            mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(csro, r.i2mode);
            haddr                                   := pt_addr_base(mmu_data, r.i2pc, is_sv_smaller(csro, r.i2mode));
            v.h_v               := is_v(r.i2mode);
            iaddr_ok            := virtual_ok(r.i2pc, is_sv_smaller(csro, r.i2mode));
            v.newent.ctx        := r.i2ctx;
            v.newent.mode       := r.i2mode;
            v.newent.vaddr      := r.i2pc(gvn'range);
            v.mmuerr.at_ls      := '0';        -- Load/Execute
            v.mmuerr.at_id      := '1';        -- Instruction space
            v.mmuerr.at_su      := r.i2su;
            -- Actually hypervisor but no supervisor page tables?
            if hmmu_only(r.i2mode) then
              iaddr_ok          := gphysical_ok(r.i2pc, is_svx4_smaller(csro));
              v.h_mxr           := '0';
              v.h_vmxr          := '0';
              v.h_hx            := '0';
              do_pte1_hchk      := true;
            end if;
          when access_r | access_asi_walk =>
            mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(csro, r.d2mode);
            haddr                                   := pt_addr_base(mmu_data, r.d2vaddr, is_sv_smaller(csro, r.d2mode));
            v.h_v               := is_v(r.d2mode);
            daddr_ok            := virtual_ok(r.d2vaddr, is_sv_smaller(csro, r.d2mode));
            v.newent.ctx        := mmu_ctx(csro, r.d2mode);
            v.newent.mode       := r.d2mode;
            v.newent.vaddr      := r.d2vaddr(gvn'range);
            v.mmuerr.at_ls      := to_bit(is_access_w(r.mmusel));
            v.mmuerr.at_id      := '0';
            v.mmuerr.at_su      := r.d2su;
            -- Actually hypervisor but no supervisor page tables?
            if hmmu_only(r.d2mode) then
              daddr_ok          := gphysical_ok(r.d2vaddr, is_svx4_smaller(csro));
              v.h_mxr           := r.d2mxr;
              v.h_vmxr          := r.d2vmxr;
              v.h_hx            := r.d2hx;
              -- Treat atomic access as store to avoid store phase of atomic
              -- causing mmu fault.
              if r.d2atomic = '1' and r.amo.d2type /= "100010" then  -- Atomic but not LR
                v.mmuerr.at_ls  := '1';
              end if;
              do_pte1_hchk      := true;
            end if;
          -- Really "11" (access_w), since "10" is unused.
          when others =>
            mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(csro, r.d2mode);
            haddr                                   := pt_addr_base(mmu_data, r.d2vaddr, is_sv_smaller(csro, r.d2mode));
            v.h_v               := is_v(r.d2mode);
            daddr_ok            := virtual_ok(r.d2vaddr, is_sv_smaller(csro, r.d2mode));
            v.newent.ctx        := mmu_ctx(csro, r.d2mode);
            v.newent.mode       := r.d2mode;
            v.newent.vaddr      := r.d2vaddr(gvn'range);
            v.mmuerr.at_ls      := '1';
            v.mmuerr.at_id      := '0';
            v.mmuerr.at_su      := r.d2su;
            -- Actually hypervisor but no supervisor page tables?
            if hmmu_only(r.d2mode) then
              daddr_ok          := gphysical_ok(r.d2vaddr, is_svx4_smaller(csro));
              v.h_mxr           := r.d2mxr;
              v.h_vmxr          := r.d2vmxr;
              v.h_hx            := r.d2hx;
              do_pte1_hchk      := true;
            end if;
          end case;

          if addr_check_mask(4) = '0' then
            iaddr_ok := true;
          end if;
          if addr_check_mask(0) = '0' then
            daddr_ok := true;
          end if;

          v.mmuaddr := haddr(v.mmuaddr'range);
          if ext_h = 1 then
            v.h_addr  := haddr(v.h_addr'range);
          end if;
          v.pmp_low   := fit0ext(mmu_data & "00", v.pmp_low);

          -- First level page table accessibility
          if hmmu_enabled(csro, v.h_v) then
            v.h_do            := '1';
            v.h_x             := '0';
            v.h_ls            := '0';
            -- Possible L1 PT read fault due to L2 PT.
            -- Instruction or data access.
            v.itypehyper      := v.h_x       & '0';
            v.dtypehyper      := (not v.h_x) & '0';
          elsif actual_tlb_pmp then
            v.pmp_do          := '1';
          end if;

          v.newent.mask       := first_level_mask(is_sv_smaller(csro, v.newent.mode));

          -- Check top bits of *ATP
          guest_top_ok        := true;
          phys_top_ok         := true;
          if hmmu_enabled(csro, v.h_v) then
            guest_top_ok      := top_gpa_zeros(haddr, is_svx4_smaller(csro));
          else
            phys_top_ok       := all_0(haddr(haddr'high downto pa_msb + 1));
          end if;

          -- hPT only?
          if do_pte1_hchk then
            v.s               := as_rv_mmu_pte1_hchk;
            v.newent.perm     := (others => '1');
            v.newent.modified := v.mmuerr.at_ls;

            -- Check PTE range with hypervisor page tables, if applicable.
            v.h_addr          := fit0ext(v.newent.vaddr & x"000", v.h_addr);
            v.h_ls            := v.mmuerr.at_ls;
            v.h_x             := v.mmuerr.at_id;
            -- Possible access fault due to L2 PT.
            -- Instruction or data access.
            v.itypehyper      := '0' & v.h_x;
            v.dtypehyper      := '0' & not v.h_x;
            if not iaddr_ok or not daddr_ok then
              v.s := as_rv_hmmuwalk_pterr;
            else
            end if;
          else
            if not iaddr_ok or not daddr_ok then
              v.s := as_rv_mmuwalk_pterr;
            elsif not guest_top_ok then
              v.s := as_rv_hmmuwalk_pterr;
            elsif not phys_top_ok then
              v.s := as_rv_mmuwalk_pmperr;
            end if;
          end if;
          -- end if;
        else
         assert false report "Reached as_rv_start_walk!" severity failure;
        end if;

      -- Do PMP as if it was a PT walk
      when as_rv_start_pmp =>
        if actual_tlb_pmp and walk_pmp then
          iaddr_ok  := true;
          daddr_ok  := true;

          v.newent  := tlbent_empty;

          case r.mmusel is
          when access_i =>
            iaddr_ok          := gphysical_ok(r.i2pc, is_svx4_smaller(csro));
            v.newent.ctx      := (others => '0');
            v.newent.mode     := r.i2mode;
            v.newent.vaddr    := r.i2pc(gvn'range);
            v.mmuerr.at_ls    := '0';        -- Load/Execute
            v.mmuerr.at_id    := '1';        -- Instruction space
            v.mmuerr.at_su    := r.i2su;
            v.pmp_m           := r.i2m;
          when access_r | access_asi_walk =>
            daddr_ok          := gphysical_ok(r.d2vaddr, is_svx4_smaller(csro));
            v.newent.ctx      := (others => '0');
            v.newent.mode     := r.d2mode;
            v.newent.vaddr    := r.d2vaddr(gvn'range);
            v.mmuerr.at_ls    := to_bit(is_access_w(r.mmusel));
            v.mmuerr.at_id    := '0';
            v.mmuerr.at_su    := r.d2su;
            -- Treat atomic access as store to avoid store phase of atomic
            -- causing mmu fault.
            --if r.d2lock = '1' then
            if r.d2atomic = '1' and r.amo.d2type /= "100010" then  -- Atomic but not LR
              v.mmuerr.at_ls  := '1';
            end if;
            v.pmp_m           := r.d2m;
          -- Really "11" (access_w), since "10" is unused.
          when others =>
            daddr_ok          := gphysical_ok(r.d2vaddr, is_svx4_smaller(csro));
            v.newent.ctx      := (others => '0');
            v.newent.mode     := r.d2mode;
            v.newent.vaddr    := r.d2vaddr(gvn'range);
            v.mmuerr.at_ls    := '1';
            v.mmuerr.at_id    := '0';
            v.mmuerr.at_su    := r.d2su;
            v.pmp_m           := r.d2m;
          end case;

          if not pmaen then
            -- Use fake PTE data
            rdb64 := uext(v.newent.vaddr & x"00" & "00", rdb64);
            v.newent.cached := pte_cached(ahbso, rdb64);
            v.newent.busw   := pte_busw(rdb64);
          else
            -- With PMA, the proper cached/busw setting can not yet be known!
          end if;


          if addr_check_mask(4) = '0' then
            iaddr_ok := true;
          end if;
          if addr_check_mask(0) = '0' then
            daddr_ok := true;
          end if;

          v.newent.mask := first_level_mask(is_sv_smaller(csro, v.newent.mode));

          v.pmp_mask := pt_mask(v.newent.mask, is_sv_smaller(csro, v.newent.mode));
          v.pmp_low  := fit0ext(v.newent.vaddr & x"000", v.pmp_low) and v.pmp_mask;
          v.pmp_do   := '1';

          v.s        := as_rv_mmu_pte1_pmpchk;

          v.newent.perm     := (others => '1');
          v.newent.modified := v.mmuerr.at_ls;

          v.newent.paddr    := fit0ext(v.newent.vaddr, v.newent.paddr);

          if not iaddr_ok then
            v.ifailkind := "11";
            v.s := as_rv_ifailkind;
          elsif not daddr_ok then
            v.dfailkind := "11";
            v.s := as_rv_dfailkind;
          else
          end if;
        else
          assert false report "Reached as_start_pmp!" severity failure;
        end if;

      -- Check accessibility of a first level page table address.
      -- PMP check unless hypervisor enabled.
      -- Address will be properly mapped if hypervisor is used.
      -- This is the actual entrypoint into as_rv_mmuwalk.
      when as_rv_mmu_pt1addr_chk =>
        if mmuen = 1 and is_riscv and not walk_sw then
          if hmmu_enabled(csro, r.h_v) then
            v.h_done       := '0';  -- Do not remember finished lookup any longer.
            -- OK?
            if htlbchk.hit = '1' then
              v.s          := as_rv_mmuwalk;
              obifi.bifop := BIFOP_SMFET;
              v.bifwait_op := BIFOP_SMFET;
              obifi.size := pte_hsize(1 downto 0);
              obifi.widebus := '1';
              obifi.mmuacc := '1';
              v.mmuaddr := htlbchk.paddr(v.mmuaddr'range);
              obifi.busaddr := (others => '0');
              obifi.busaddr(v.mmuaddr'range) := v.mmuaddr;
            -- Hit but did not allow reading page table!
            elsif htlbchk.amatch = '1' then
              v.s          := as_rv_hmmuwalk_pterr;
            -- Miss
            else

              -- First level page table accessibility
              if actual_tlb_pmp then
                v.pmp_do     := '1';
              end if;

              -- On RISC-V, the base is indexed directly for the first level.
              -- Return physical address for next level of page table.
              mmu_data                                := (others => '0');
              mmu_data(ppn'length + 10 - 1 downto 10) := hmmu_base(csro, r.h_addr);
              haddr := pt_addr_base(mmu_data, r.h_addr, is_svx4_smaller(csro));

              v.hnewent.mask := first_level_mask(is_svx4_smaller(csro));

              obifi.size := pte_hsize(1 downto 0);
              obifi.widebus := '1';
              obifi.mmuacc := '1';
              v.mmuaddr := haddr(v.mmuaddr'range);
              obifi.busaddr := (others => '0');
              obifi.busaddr(v.mmuaddr'range) := v.mmuaddr;

              v.pmp_low   := fit0ext(mmu_data & "00", v.pmp_low);
              v.h_cause := "00";   -- Back here afterwards.

              v.hnewent.ctx      := mmu_ctx(csro);
              v.hnewent.vaddr    := r.h_addr(gvn'range);
              v.hnewent.modified := '0';
              v.h_x              := '0';
              v.h_ls             := '0';
              v.h_mxr            := '0';
              v.h_vmxr           := '0';
              v.h_hx             := '0';

              v.mmusel(3)        := '1';              -- Doing hPT walk

              start_hwalk        := true;
            end if;
          else
            v.s := as_rv_mmuwalk;
            obifi.size := pte_hsize(1 downto 0);
            obifi.widebus := '1';
            obifi.mmuacc := '1';
            obifi.busaddr := (others => '0');
            obifi.busaddr(v.mmuaddr'range) := r.mmuaddr;
            if not actual_tlb_pmp then
              pmp_mmu      := '1';
              obifi.bifop := BIFOP_SMFET;
              v.bifwait_op := BIFOP_SMFET;
            elsif v.pmp_su_rwx(2) = '1' and (not pmaen or pma_pt_r(v.pma)) then
              --v.ahb.htrans := HTRANS_NONSEQ;
              obifi.bifop := BIFOP_SMFET;
              v.bifwait_op := BIFOP_SMFET;
            elsif actual_tlb_pmp then
              -- PMP/PMA did not allow reading page table!
              v.s          := as_rv_mmuwalk_pmperr;
            end if;
          end if;
        else
          assert false report "Reached as_rv_mmu_pt1addr_chk!" severity failure;
        end if;

      -- Normal page table walk.
      -- For RISC-V, this must always be entered via as_rv_mmu_pt1addr_chk since it relies
      -- on an already hPT/PMP-checked address being accessed.
      when as_rv_mmuwalk =>
        if is_riscv and mmuen = 1 and not walk_sw then

          obifi.busaddr := (others => '0');
          obifi.busaddr(r.mmuaddr'range) := r.mmuaddr;
          obifi.size := pte_hsize(1 downto 0);
          obifi.widebus := '1';
          -- Ensure PTE writes get snooped
          obifi.nosnoop := '0';
          obifi.mmuacc := '1';

          -- New entry and new error (if error occurs)
          if is_access_i(r.mmusel) then
            v.newent.ctx      := r.i2ctx;
            v.newent.mode     := r.i2mode;
            v.newent.vaddr    := r.i2pc(gvn'range);
            v.newent.modified := '0';
            v.mmuerr.at_ls    := '0';        -- Load/Execute
            v.mmuerr.at_id    := '1';        -- Instruction space
            v.mmuerr.at_su    := r.i2su;
          else
            v.newent.ctx      := mmu_ctx(csro, r.d2mode);
            v.newent.mode     := r.d2mode;
            v.newent.vaddr    := r.d2vaddr(gvn'range);
            v.newent.modified := to_bit(is_access_w(r.mmusel));
            v.mmuerr.at_ls    := to_bit(is_access_w(r.mmusel));
            v.mmuerr.at_id    := '0';
            v.mmuerr.at_su    := r.d2su;
            -- Treat atomic access as store to avoid store phase of atomic
            -- causing mmu fault.
            if r.d2atomic = '1' and r.amo.d2type /= "100010" then  -- Atomic but not LR
              v.newent.modified := '1';
              v.mmuerr.at_ls    := '1';
            end if;
          end if;

          v.newent.paddr  := fit0ext(pte_paddr(rdb64), v.newent.paddr);
          -- Deal with Svnapot by copying low bits from vaddr to low physical part.
          -- For later matches in TLB, the same kind of copying is done.
          if ext_svnapot = 1 and rdb64(rv_pte_n) = '1' then
            if is_access_i(r.mmusel) then
              set_lo(v.newent.paddr, get(r.i2pc, gvn'low, 4));
            else
              set_lo(v.newent.paddr, get(r.d2vaddr, gvn'low, 4));
            end if;
          end if;

          if ext_svpbmt = 1 then
            v.newent.pbmt := rdb64(rv_pte_pbmt'range);
          end if;

          if not pmaen then
            v.newent.cached := pte_cached(ahbso, rdb64);
            v.newent.busw   := pte_busw(rdb64);
          else
            -- With PMA, the proper cached/busw setting can not yet be known!
          end if;
          if rdb32v = '1' then
            v.newent.modified := v.newent.modified or rdb32(rv_pte_d);
          end if;

          -- Prepare hwdata for writing back PTE with R/M bits set
          -- Check if write-back is needed
          obifi.stdata := rdb64;
          pte_mark_modacc(obifi.stdata, r.newent.modified, vneedwb, vneedwblock);

          v.newent.perm := (not rdb32(rv_pte_u)) & rdb32(rv_pte_u downto rv_pte_r);
          v.newent.acc := (others => '0');

          v.dregval      := rdb64;

          if rdb32v = '1' and bifo.stat.ready='1' then
            obifi.clrrdbuf := '1';

            -- Specification says that G in PTDs imply it for lower PTEs.
            if enable_g = 1 then
              v.newent.global := r.newent.global or rdb32(rv_pte_g);
            end if;

            -- Depending on level/type -
            --   update haddr to go down to next level
            --   write back "accessed" bit
            --   update TLB and register of access causing miss

            -- AHB error fetching entry?
            if bifo.rdb.err='1' then
              v.s             := as_rv_mmuwalk_pmperr;

            -- Page table entry?
            elsif is_pte(rdb32) then

              if is_access_asi_walk(r.mmusel) then
                v.s := as_rdasi2;

              -- Not valid?
              elsif not is_valid_pte(rdb64, r.newent.mask) then
                v.s := as_rv_mmuwalk_pterr;

              -- Permission error according to page table?
              elsif -- For now, assume PMP and hypervisor allows read (corrected later),
                    -- since we need to do any writeback before that check, anyway.
                    -- Since permissions check knows about execution vs data read/write,
                    -- it does not matter if we always pass the r.d2* here.
                    (not permitted(r.mmuerr.at_id, r.mmuerr.at_su, r.mmuerr.at_ls,
                                   (not rdb32(rv_pte_u)) & rdb32(rv_pte_u downto rv_pte_r),
                                   '1', '1', '0',    -- pmp_r, h_r, pmp_no_x
                                   r.d2sum  and not r.mmuerr.at_id,
                                   r.d2mxr  and not r.mmuerr.at_id,
                                   r.d2vmxr and not r.mmuerr.at_id,
                                   r.d2hx   and not r.mmuerr.at_id,
                                   r.d2ss   and not r.mmuerr.at_id,
                                   cond(not is_v(r.d2mode),
                                        csro.menvcfg_sse,
                                        csro.menvcfg_sse and csro.henvcfg_sse)
                                   )) then
                v.s := as_rv_mmuwalk_pterr;
                if ext_zicfiss = 1 and
                   ((not is_v(r.d2mode) and csro.menvcfg_sse = '1') or
                    (csro.menvcfg_sse = '1' and csro.henvcfg_sse = '1')) then
                  -- Shadow stack instruction?
                  if r.d2ss = '1' then
                    if rdb32(rv_pte_x downto rv_pte_r) = "001" then
                      -- Store/AMO page fault when read-only
                    else
                      -- Otherwise, store/AMO access fault
                      v.s := as_rv_mmuwalk_pmperr;
                    end if;
                  -- Normal fetch or store at shadow stack page (load would not fail)?
                  elsif rdb32(rv_pte_x downto rv_pte_r) = "010" then
                    -- Access fault
                    v.s := as_rv_mmuwalk_pmperr;
                  end if;
                end if;

              -- Address is not zero extended (PA)?
              elsif not hmmu_enabled(csro, r.h_v) and
                    not all_0(rdb64(rv_ppn'high downto pa_msb + 1 - 12 + 10)) then
                v.s := as_rv_mmuwalk_pmperr;

              -- Address is not zero extended (GPA)?
              elsif hmmu_enabled(csro, r.h_v) and
                    not top_gpa_zeros(rdb64(rv_ppn'high downto 10) & x"000", is_svx4_smaller(csro)) then
                v.itypehyper := '0' &     v.mmuerr.at_id;
                v.dtypehyper := '0' & not v.mmuerr.at_id;
                v.addrhyper  := fit0ext(rdb64(rv_ppn'range) & "0000000000", v.addrhyper);
                v.s := as_rv_hmmuwalk_pterr;

              -- Writeback needed?
              elsif vneedwb = '1' then
                fault        := false;
                fault_access := false;
                fault_hyper  := false;
                -- Always fault?
                if csro.m_adue = '0' or (ext_h = 1 and r.h_v = '1' and csro.vs_adue = '0') then
                  fault            := true;
                elsif hmmu_enabled(csro, r.h_v) then
                  -- Writeback permission according to hypervisor TLB?
                  -- If not PMP in TLBs, also check recent PMP information.
                  if r.h_w = '1' and (actual_tlb_pmp or r.pt_no_w = '0') then
                    if vneedwblock = '1' and r.biflocked = '0' then
                      do_mmu_lock  := true;
                      v.s          := as_rv_xmmuwalk_lock;
                    else
                      v.s          := as_rv_xwpte;
                    end if;
                  elsif r.h_w = '0' and not (actual_tlb_pmp and r.h_pmp_no_w = '1') then
                    fault          := true;
                    fault_hyper    := true;
                    -- L1 PT write fault due to L2 PT.
                    -- Instruction or data access.
                    v.itypehyper   := not (r.mmusel(0) & r.mmusel(0));
                    v.dtypehyper   :=      r.mmusel(0) & r.mmusel(0);
                  else
                    fault          := true;
                    fault_access   := true;
                  end if;

                elsif actual_tlb_pmp then
                  -- Writeback permission according to PMP/PMA?
                  if (actual_tlb_pmp and v.pmp_su_rwx(1) = '1' and
                      (not pmaen or pma_pt_w(v.pma))) or
                     (not actual_tlb_pmp and r.pt_no_w = '0') then
                    if vneedwblock = '1' and r.biflocked = '0' then
                      do_mmu_lock  := true;
                      v.s          := as_rv_xmmuwalk_lock;
                    else
                      v.s          := as_rv_xwpte;
                    end if;
                  else
                    fault          := true;
                    fault_access   := true;
                  end if;

                elsif r.pt_no_w = '1' then
                  -- Writeback not allowed by PMP/PMA
                  fault          := true;
                  fault_access   := true;

                else
                  if vneedwblock = '1' and r.biflocked = '0' then
                    do_mmu_lock    := true;
                    v.s            := as_rv_mmuwalk_lock;
                  else
                    v.s            := as_wptectag1;
                  end if;
                end if;

                if not fault then
                  if vneedwblock = '1' and r.biflocked = '0' then
                  else
                    obifi.bifop := BIFOP_STORE;
                    v.tlbupdate  := '1';
                  end if;
                elsif ext_h = 1 and fault_hyper then
                  -- Was non-writability caused by PMP rather than hypervisor PT?
                  if r.h_pmp_no_w = '1' then
                    v.s := as_rv_mmuwalk_pmperr;
                  else
                    v.s := as_rv_hmmuwalk_pterr;
                  end if;
                elsif fault_access then
                  v.s := as_rv_mmuwalk_pmperr;
                else
                  v.s := as_rv_mmuwalk_pterr;
                end if;

              -- OK!
              else

                -- Check PTE range with hypervisor page tables, if applicable.
                if hmmu_enabled(csro, r.h_v) then
                  if is_access_i(r.mmusel) then
                    v.h_addr := fit0ext(v.newent.paddr & x"000", v.h_addr);
                    virtual2physical(r.i2pc, v.newent.mask, v.h_addr);
                  else
                    v.h_addr := fit0ext(v.newent.paddr & x"000", v.h_addr);
                    virtual2physical(r.d2vaddr, v.newent.mask, v.h_addr);
                  end if;
                  v.h_do     := '1';
                  v.h_x      := r.mmuerr.at_id;
                  v.h_ls     := r.mmuerr.at_ls;
                  if ext_zicfiss = 1 then
                    -- Shadow stack instructions always check for writeability
                    v.h_ls   := v.h_ls or r.d2ss;
                  end if;
                  v.h_mxr    := r.d2mxr  and not v.h_x;
                  v.h_vmxr   := r.d2vmxr and not v.h_x;
                  v.h_hx     := r.d2hx   and not v.h_x;
                  v.s        := as_rv_mmu_pte1_hchk;
                  -- Possible access fault due to L2 PT.
                  -- Instruction or data access.
                  v.itypehyper := '0' & v.h_x;
                  v.dtypehyper := '0' & not v.h_x;
                -- Check PMP permission error, if applicable.
                elsif actual_tlb_pmp then
                  v.pmp_mask := pt_mask(r.newent.mask, is_sv_smaller(csro, r.newent.mode));
                  v.pmp_low  := fit0ext(v.newent.paddr & x"000", v.pmp_low) and v.pmp_mask;
                  v.pmp_do   := '1';
                  v.s        := as_rv_mmu_pte1_pmpchk;
                else
                  v.tlbupdate := '1';
                  -- Re-read tags and check for a potential hit
                  if is_access_i(r.mmusel) and r.imisspend = '1' then
                    v.s := as_wptectag1;
                  elsif not is_access_i(r.mmusel) and (r.dmisspend = '1' or r.slowwrpend = '1') then
                    v.s := as_wptectag1;
                  else
                    v.s := as_normal;
                  end if;
                end if;
              end if;

            -- Page table descriptor (and not too deep)?
            elsif is_ptd(rdb32) and is_valid_ptd(rdb64) and
                  not pt_end_reached(r.newent.mask, is_sv_smaller(csro, r.newent.mode)) then
              -- Address is not zero extended (PA)?
              if not hmmu_enabled(csro, r.h_v) and
                 not all_0(rdb64(rv_ppn'high downto pa_msb  + 1 - 12 + 10)) then
                v.s           := as_rv_mmuwalk_pmperr;
              -- Address is not zero extended (GPA)?
              elsif hmmu_enabled(csro, r.h_v) and
                    not top_gpa_zeros(rdb64(rv_ppn'high downto 10) & x"000", is_svx4_smaller(csro)) then
                v.addrhyper   := fit0ext(rdb64(rv_ppn'range) & "0000000000", v.addrhyper);
                v.s           := as_rv_hmmuwalk_pterr;
              else
                -- Shift in a '1' for each new TLB level.
                v.newent.mask := next_level_mask(r.newent.mask);

                haddr         := pt_addr(rdb64, v.newent.mask, r.newent.vaddr, is_sv_smaller(csro, r.newent.mode));
                v.mmuaddr     := haddr(v.mmuaddr'range);
                obifi.busaddr := (others => '0');
                obifi.busaddr(v.mmuaddr'range) := v.mmuaddr;

                if ext_h = 1 then
                  v.h_addr    := haddr(v.h_addr'range);
                end if;

                if actual_tlb_pmp then
                  -- "va" is all zeroes and will give the base address.
                  -- v.pmp_mask is already set from above. Always 4 kByte.
                  v.pmp_low   := fit0ext(pt_addr(rdb64, v.newent.mask, va,
                                                 is_sv_smaller(csro, r.newent.mode)), v.pmp_low);
                  v.pmp_do    := '1';
                end if;

                -- Return physical address for next level of page table.
                -- ASI?
                if is_access_asi_walk(r.mmusel) then
                  v.d2vaddr(9 downto 8) := uadd(r.d2vaddr(9 downto 8), 1);
                  if r.d2vaddr(9 downto 8) = "11" then
                    v.s                 := as_rdasi2;
                  else
                    obifi.bifop := BIFOP_SMFET;
                  end if;
                else
                  -- This is needed to split the PMP dependancy chain.
                  -- Also enables hypervisor guest translation to take place.
                  if hmmu_enabled(csro, r.h_v) then
                    v.h_do     := '1';
                    v.h_x      := '0';
                    v.h_ls     := '0';
                    v.h_mxr    := '0';
                    v.h_vmxr   := '0';
                    v.h_hx     := '0';
                    -- Possible L1 PT read fault due to L2 PT.
                    -- Instruction or data access.
                    v.itypehyper := to_bit(is_access_i(r.mmusel)) & '0';
                    v.dtypehyper := not v.itypehyper(1)           & '0';
                  end if;
                  v.s          := as_rv_mmu_pt1addr_chk;
                end if;
              end if;

            -- Invalid/reserved or too many levels of PTDs
            else
              v.s := as_rv_mmuwalk_pterr;
            end if;
          end if;

          if not actual_tlb_pmp then
            if is_access_i(r.mmusel) then
              v.i2paddr   := fit0ext(v.newent.paddr & r.i2pc(11 downto 0), v.i2paddr);
              virtual2physical(r.i2pc, r.newent.mask, v.i2paddr);
              v.i2paddrv  := '1';
              v.i2busw    := v.newent.busw;
              v.i2paddrc  := v.newent.cached;
            else
              v.d2paddr   := fit0ext(v.newent.paddr & r.d2vaddr(11 downto 0), v.d2paddr);
              virtual2physical(r.d2vaddr, r.newent.mask, v.d2paddr);
              -- Reverse since it will be done again next cycle...
              v.d2paddrv  := '1';
              v.d2busw    := v.newent.busw;
              v.d2nocache := not v.newent.cached;
              v.d2tlbmod  := v.newent.modified;
            end if;

            -- Select which TLB entry to replace
            if is_access_i(r.mmusel) then
              if r.i2tlbhit = '0' and r.mmctrl1.tlbdis = '0' then
                v.i2tlbhit := '1';
                v.i2tlbid  := pmru_decode(r.itlbpmru);
              end if;
            else
              if r.d2tlbhit = '0' and r.mmctrl1.tlbdis = '0' and
                 not is_access_asi_walk(r.mmusel) then
                v.d2tlbhit := '1';
                v.d2tlbid  := pmru_decode(r.dtlbpmru);
              end if;
            end if;
            -- Set up for as_wptectag1 state in case of recheck
            v.irdbufvaddr := r.i2pc(r.irdbufvaddr'range);
            v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
            v.iramaddr    := r.i2pc(r.iramaddr'range);
          end if;
        else
          assert false report "Reached as_mmuwalk!" severity failure;
        end if;

      -- Check accessibility of a first level PTE range via hypervisor TLB.
      -- This will update the proposed TLB entry.
      when as_rv_mmu_pte1_hchk =>
        if arch = RISCV and ext_h = 1 and not walk_sw then
          v.h_done        := '0';  -- Do not remember finished lookup any longer.
          obifi.clrrdbuf := '1';
          -- OK?
          if htlbchk.hit = '1' then
            -- Only allow for same or smaller page size!
            -- hPT page smaller (higher value) than (v)sPT page?
            -- For svnapot, also check if we are at base page mask,
            -- since there might then be an svnapot bit to clear as well.
            if unsigned(htlbchk.h_mask) > unsigned(r.newent.mask) or
               (ext_svnapot = 1 and htlbchk.h_mask(htlbchk.h_mask'right) = '1') then
              v.newent.mask := htlbchk.h_mask;
              if ext_svnapot = 1 and r.newent.svnapot = '1' then
                v.newent.svnapot := htlbchk.svnapot;
              end if;
            end if;
            v.newent.perm(2 downto 0) := r.newent.perm(2 downto 0) and htlbchk.h_perm;

            v.newent.h_r      := htlbchk.h_perm(0);
            if actual_tlb_pmp then
              v.newent.pmp_r    := htlbchk.h_pmp_r;
              v.newent.pmp_no_w := htlbchk.h_pmp_no_w;
              v.newent.pmp_no_x := htlbchk.h_pmp_no_x;
              v.newent.busw     := htlbchk.busw;
              v.newent.cached   := htlbchk.cached;
              if pmaen then
                v.newent.pma    := htlbchk.pma;
              end if;
            end if;
            if ext_svpbmt = 1 then
              v.newent.pbmt     := htlbchk.pbmt;
            end if;
            if walk_pmp then
              v.newent.pmp_none := htlbchk.pmp_none;
              v.newent.pmp_lock := htlbchk.pmp_lock;
              v.newent.pmp_rwx  := htlbchk.pmp_rwx;
            end if;

            v.newent.paddr    := htlbchk.paddr(v.newent.paddr'range);

            -- OK!
            v.tlbupdate := '1';
            -- Re-read tags and check for a potential hit
            if is_access_i(r.mmusel) and r.imisspend = '1' then
              v.s := as_wptectag1;
            elsif not is_access_i(r.mmusel) and (r.dmisspend = '1' or r.slowwrpend = '1') then
              v.s := as_wptectag1;
            else
              v.s := as_normal;
            end if;

          -- Hit but did not allow requested access!
          elsif htlbchk.amatch = '1' then
            if not actual_tlb_pmp then
              v.s := as_rv_hmmuwalk_pterr;
            else
              -- The type of fault reported depends on the actual reason.
              if (is_access_i(r.mmusel) and htlbchk.h_pmp_no_x = '1') or
                 (is_access_w(r.mmusel) and htlbchk.h_pmp_no_w = '1') or
                 (is_access_r(r.mmusel) and r.h_hx = '1' and htlbchk.h_pmp_no_x = '1') then
                v.s := as_rv_hmmuwalk_pmperr;
              else
                v.s := as_rv_hmmuwalk_pterr;
              end if;
            end if;
          -- Miss
          else

            -- First level page table accessibility
            if actual_tlb_pmp then
              v.pmp_do     := '1';
            end if;

            -- On RISC-V, the base is indexed directly for the first level.
            -- Return physical address for next level of page table.
            mmu_data                                := (others => '0');
            mmu_data(ppn'length + 10 - 1 downto 10) := hmmu_base(csro, r.h_addr);
            haddr := pt_addr_base(mmu_data, r.h_addr, is_svx4_smaller(csro));

            v.hnewent.mask := first_level_mask(is_svx4_smaller(csro));

            obifi.size := pte_hsize(1 downto 0);
            obifi.widebus := '1';
            obifi.mmuacc := '1';
            v.mmuaddr := haddr(v.mmuaddr'range);
            obifi.busaddr := (others => '0');
            obifi.busaddr(v.mmuaddr'range) := v.mmuaddr;

            v.pmp_low   := fit0ext(mmu_data & "00", v.pmp_low);
            v.h_cause := "01";   -- Back here afterwards.

            v.hnewent.vaddr    := r.h_addr(gvn'range);
            v.hnewent.ctx      := mmu_ctx(csro);
            v.hnewent.modified := r.h_ls;

            start_hwalk        := true;
          end if;

          -- Note the use of v.newent.mask here, unlike in the
          -- other two equivalent places!
          -- This is because we actually update it above on hit.
          if is_access_i(r.mmusel) then
            v.i2paddr   := fit0ext(v.newent.paddr & r.i2pc(11 downto 0), v.i2paddr);
            virtual2physical(r.i2pc, v.newent.mask, v.i2paddr);
            v.i2paddrv  := '1';
            v.i2busw    := v.newent.busw;
            v.i2paddrc  := v.newent.cached;
          else
            v.d2paddr   := fit0ext(v.newent.paddr & r.d2vaddr(11 downto 0), v.d2paddr);
            virtual2physical(r.d2vaddr, v.newent.mask, v.d2paddr);
            -- Reverse since it will be done again next cycle...
            v.d2paddrv  := '1';
            v.d2busw    := v.newent.busw;
            v.d2nocache := not v.newent.cached;
            v.d2tlbmod  := v.newent.modified;
          end if;

          -- Select which TLB entry to replace
          if is_access_i(r.mmusel) then
            if r.i2tlbhit = '0' and r.mmctrl1.tlbdis = '0' then
              v.i2tlbhit := '1';
              v.i2tlbid  := pmru_decode(r.itlbpmru);
            end if;
          else
            if r.d2tlbhit = '0' and r.mmctrl1.tlbdis = '0' and
               not is_access_asi_walk(r.mmusel) then
              v.d2tlbhit := '1';
              v.d2tlbid  := pmru_decode(r.dtlbpmru);
            end if;
          end if;
          -- Set up for as_wptectag1 state in case of recheck
          v.irdbufvaddr := r.i2pc(r.irdbufvaddr'range);
          v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
          v.iramaddr    := r.i2pc(r.iramaddr'range);
        else
          assert false report "Reached as_rv_mmu_pte1_hchk!" severity failure;
        end if;

      -- Check PTE range for PMP/PMA accessability, and shrink as necessary.
      when as_rv_mmu_pte1_pmpchk =>
        if is_riscv and actual_tlb_pmp and not walk_sw then
          obifi.clrrdbuf := '1';

          -- PMP/PMA area matches (or is larger than) PTE area?
          if v.pmp_fit = '1' then

            -- Update TLB permissions according to PMP
            if v.pmp_su_rwx(0) = '0' then  -- Execute?
              v.newent.perm(2) := '0';
            end if;
            if v.pmp_su_rwx(1) = '0' then  -- Write?
              v.newent.perm(1) := '0';
            end if;
            if v.pmp_su_rwx(2) = '0' then  -- Read?
              v.newent.perm(0) := '0';
            end if;

            if pmaen then
              if ext_svpbmt = 1 then
                v.pma         := pbmt_pma_update(r.newent.pbmt, v.pma);
              end if;
              v.newent.pma    := v.pma;
              -- With PMA these are not known before!
              v.newent.busw   := pma_busw(v.pma);
              v.newent.cached := pma_cache(v.pma);
            else
              if ext_svpbmt = 1 then
                -- Even without PMA, at least cacheability can be disabled.
                if r.newent.pbmt /= "00" then
                  v.newent.cached := '0';
                end if;
              end if;
            end if;
            if walk_pmp then
              v.newent.pmp_none := v.pmp_none;
              v.newent.pmp_lock := v.pmp_lock;
              v.newent.pmp_rwx  := v.pmp_rwx;
            end if;

            pmp_rwx   := v.pmp_su_rwx;
            if walk_pmp and r.pmp_m = '1' then
              pmp_rwx := v.pmp_m_rwx;
            end if;

            -- PMP permission error?
            if    is_access_i(r.mmusel) then    -- Execute?
              ok := pmp_rwx(0) = '1';
            elsif is_access_w(r.mmusel) or      -- Write?
                  -- Shadow stack instructions always check for writeability
                  (ext_zicfiss = 1 and r.d2ss = '1') or
                  -- Most AMO also do write, even though it is not visible in mmusel.
                  (r.amo.d2type(5) = '1' and
                   (r.amo.d2type(1) = '0' or r.amo.d2type(1 downto 0) = "11")) then
              ok := pmp_rwx(1) = '1';
              if pmaen and r.amo.d2type(5) = '1' then
                if r.amo.d2type(1) = '1' and not pma_lrsc(v.pma) then
                  ok := false;
                elsif not pma_amo(v.pma) then
                  ok := false;
                end if;
              end if;
            else                                -- Read?
              ok := pmp_rwx(2) = '1';
              if pmaen and r.amo.d2type(5) = '1' then
                if r.amo.d2type(1) = '1' and not pma_lrsc(v.pma) then
                  ok := false;
                end if;
              end if;
            end if;

            if not ok then
              v.s := as_rv_mmuwalk_pmperr;

            -- OK!
            else
              v.tlbupdate := '1';
              -- Re-read tags and check for a potential hit
              if is_access_i(r.mmusel) and r.imisspend = '1' then
                v.s := as_wptectag1;
              elsif not is_access_i(r.mmusel) and (r.dmisspend = '1' or r.slowwrpend = '1') then
                v.s := as_wptectag1;
              else
                v.s := as_normal;
              end if;
            end if;

          -- PMP hit but not fit (and not too deep in shrinking)?
          elsif v.pmp_hit = '1' and not pt_end_reached(r.newent.mask, is_sv_smaller(csro, r.newent.mode)) then
            -- Shift in a '1' for each new fake TLB level.
            v.newent.mask := next_level_mask(r.newent.mask);


            -- Insert next part of address
            part_mask := get_right(pt_mask(r.newent.mask, is_sv_smaller(csro, r.newent.mode)) xor
                                   pt_mask(v.newent.mask, is_sv_smaller(csro, r.newent.mode)), part_mask);
            if is_access_i(r.mmusel) then
              part    := fit0ext(r.i2pc, part) and part_mask;
            else
              part    := fit0ext(r.d2vaddr, part) and part_mask;
            end if;
            v.newent.paddr := r.newent.paddr or part(v.newent.paddr'range);
            v.pmp_mask     := pt_mask(v.newent.mask, is_sv_smaller(csro, r.newent.mode));
            v.pmp_low      := fit0ext(v.newent.paddr & x"000", v.pmp_low) and v.pmp_mask;
            v.pmp_do       := '1';
            -- Need to remember the state of pmp_m and pmp_only!
            if walk_pmp then
              v.pmp_m      := r.pmp_m;
              v.pmp_only   := r.pmp_only;
            end if;

            v.s            := as_rv_mmu_pte1_pmpchk;

          -- No hit or too many levels - no MMU means PMP background hit!
          elsif walk_pmp and (ext_smepmp = 0 or csro.mml = '0') and not is_mapping(r.newent.mode) then

            -- TLB permissions are irrelevant
            v.newent.perm := (others => '0');

            if pmaen then
              if ext_svpbmt = 1 then
                v.pma         := pbmt_pma_update(r.newent.pbmt, v.pma);
              end if;
              v.newent.pma    := v.pma;
              -- With PMA these are not known before!
              v.newent.busw   := pma_busw(v.pma);
              v.newent.cached := pma_cache(v.pma);
            else
              if ext_svpbmt = 1 then
                -- Even without PMA, at least cacheability can be disabled.
                if r.newent.pbmt /= "00" then
                  v.newent.cached := '0';
                end if;
              end if;
            end if;
            v.newent.pmp_none  := '1';
            v.newent.pmp_lock  := '0';
            if pmaen then
              v.newent.pmp_rwx := pma_rwx(v.pma);
            else
              v.newent.pmp_rwx := "111";
            end if;

            v.tlbupdate := '1';
            -- Re-read tags and check for a potential hit
            if is_access_i(r.mmusel) and r.imisspend = '1' then
              v.s := as_wptectag1;
            elsif not is_access_i(r.mmusel) and (r.dmisspend = '1' or r.slowwrpend = '1') then
              v.s := as_wptectag1;
            else
              v.s := as_normal;
            end if;

          -- Invalid/reserved or too many levels of PTDs
          else
            v.s := as_rv_mmuwalk_pmperr;
          end if;

          if is_access_i(r.mmusel) then
            v.i2paddr   := fit0ext(v.newent.paddr & r.i2pc(11 downto 0), v.i2paddr);
            virtual2physical(r.i2pc, r.newent.mask, v.i2paddr);
            v.i2paddrv  := '1';
            v.i2busw    := v.newent.busw;
            v.i2paddrc  := v.newent.cached;
          else
            v.d2paddr   := fit0ext(v.newent.paddr & r.d2vaddr(11 downto 0), v.d2paddr);
            virtual2physical(r.d2vaddr, r.newent.mask, v.d2paddr);
            -- Reverse since it will be done again next cycle...
            v.d2paddrv  := '1';
            v.d2busw    := v.newent.busw;
            v.d2nocache := not v.newent.cached;
            v.d2tlbmod  := v.newent.modified;
          end if;

          -- Select which TLB entry to replace
          if is_access_i(r.mmusel) then
            if r.i2tlbhit = '0' then
              v.i2tlbhit := '1';
              v.i2tlbid  := pmru_decode(r.itlbpmru);
            end if;
          else
            if r.d2tlbhit = '0' and not is_access_asi_walk(r.mmusel) then
              v.d2tlbhit := '1';
              v.d2tlbid  := pmru_decode(r.dtlbpmru);
            end if;
          end if;
          -- Set up for as_wptectag1 state in case of recheck
          v.irdbufvaddr := r.i2pc(r.irdbufvaddr'range);
          v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
          v.iramaddr    := r.i2pc(r.iramaddr'range);
        else
          assert false report "Reached as_rv_mmu_pte1_pmpchk!" severity failure;
        end if;

      -- Aquire AHB lock, re-read PTE, update and then write back PTE.
      -- (Needed when writeback with 'modified' set.)
      when as_rv_mmuwalk_lock => -- as_mmuwalk4
        if arch = RISCV then
          if not walk_sw then
            obifi.busaddr := (others => '0');
            obifi.busaddr(r.mmuaddr'range) := r.mmuaddr;
            obifi.widebus := '1';
            obifi.size := pte_hsize(1 downto 0);
            obifi.nosnoop := '0';
            obifi.mmuacc := '1';
            vstd64 := rdb64;
              do_mmu_lock := true;
              vstd32(rv_pte_a) := '1';  -- set accessed bit
            obifi.stdata := vstd64;
            if r.biflocked='0' then
              vtoglock := '1';
            end if;
            if bifo.rdb.err='1' then
              -- AHB error fetching entry

              do_mmu_lock := false;
              v.s := as_rv_mmuwalk_pmperr;
            elsif rdb32v='1' and bifo.stat.ready='1' then
              v.s := as_wptectag1;
              --if arch = RISCV then
                do_mmu_lock := false;
                v.newent.modified := r.newent.modified or rdb32(rv_pte_d);
              v.tlbupdate := '1';
              obifi.size := pte_hsize(1 downto 0);
              obifi.bifop := BIFOP_STORE;
            elsif rdb32v='1' or bifo.stat.idle='0' then
              -- wait for read access to complete
              null;
            elsif r.biflocked='1' and bifo.stat.ready='1' then
              -- start read access with lock held
              obifi.bifop := BIFOP_SMFET;
            end if;
          else
            assert false report "Reached as_rv_mmuwalk_lock!" severity failure;
          end if;
        end if;

      -- Aquire AHB lock, re-read PTE, update and then write back PTE.
      -- (Needed when writeback with 'modified' set.)
      -- This variant will check the eventual PTE against hTLB and/or PMP and "bake in".
      when as_rv_xmmuwalk_lock => -- almost as_mmuwalk4
        if arch = RISCV and (ext_h = 1 or pmpen or pmaen) and not walk_sw then
          obifi.busaddr := (others => '0');
          obifi.busaddr(r.mmuaddr'range) := r.mmuaddr;
          obifi.widebus := '1';
          obifi.size := pte_hsize(1 downto 0);
          obifi.nosnoop := '0';
          obifi.mmuacc := '1';
          vstd64 := rdb64;
            do_mmu_lock := true;
            vstd32(rv_pte_a) := '1';  -- set accessed bit
          obifi.stdata := vstd64;
          if r.biflocked='0' then
            vtoglock := '1';
          end if;
          if bifo.rdb.err='1' then
            -- AHB error fetching entry

            do_mmu_lock := false;
            v.s := as_rv_mmuwalk_pmperr;
          elsif rdb32v='1' and bifo.stat.ready='1' then
            v.s := as_rv_xwpte;
              do_mmu_lock := false;
              v.newent.modified := r.newent.modified or rdb32(rv_pte_d);
            v.tlbupdate := '1';
            obifi.size := pte_hsize(1 downto 0);
            obifi.bifop := BIFOP_STORE;
          elsif rdb32v='1' or bifo.stat.idle='0' then
            -- wait for read access to complete
            null;
          elsif r.biflocked='1' and bifo.stat.ready='1' then
            -- start read access with lock held
            obifi.bifop := BIFOP_SMFET;
          end if;
        else
          assert false report "Reached as_rv_xmmuwalk_lock!" severity failure;
        end if;

      -- Write back supervisor PTE
      -- This variant will check the eventual PTE against hTLB and/or PMP and "bake in".
      when as_rv_xwpte =>
        if is_riscv and (ext_h = 1 or pmpen or pmaen) and not walk_sw then
          done           := false;
          if bifo.stat.ready='1' then
            done := true;
          end if;

          if done then
            -- Check PTE range with hypervisor page tables, if applicable.
            if hmmu_enabled(csro, r.h_v) then
              if is_access_i(r.mmusel) then
                v.h_addr := fit0ext(r.newent.paddr & x"000", v.h_addr);
                virtual2physical(r.i2pc, r.newent.mask, v.h_addr);
              else
                v.h_addr := fit0ext(r.newent.paddr & x"000", v.h_addr);
                virtual2physical(r.d2vaddr, r.newent.mask, v.h_addr);
              end if;
              v.h_do     := '1';
              v.h_x      := r.mmuerr.at_id;
              v.h_ls     := r.mmuerr.at_ls;
              v.h_mxr    := r.d2mxr  and not v.h_x;
              v.h_vmxr   := r.d2vmxr and not v.h_x;
              v.h_hx     := r.d2hx   and not v.h_x;
              v.s        := as_rv_mmu_pte1_hchk;
              -- Possible access fault due to L2 PT.
              -- Instruction or data access.
              v.itypehyper := '0' & v.h_x;
              v.dtypehyper := '0' & not v.h_x;
            -- Check PMP permission error.
            elsif actual_tlb_pmp then
              v.pmp_mask := pt_mask(r.newent.mask, is_sv_smaller(csro, r.newent.mode));
              v.pmp_low  := fit0ext(r.newent.paddr & x"000", v.pmp_low) and v.pmp_mask;
              v.pmp_do   := '1';
              v.s        := as_rv_mmu_pte1_pmpchk;
            else
              v.tlbupdate := '1';
              -- Re-read tags and check for a potential hit
              if is_access_i(r.mmusel) and r.imisspend = '1' then
                v.s := as_wptectag1;
              elsif not is_access_i(r.mmusel) and (r.dmisspend = '1' or r.slowwrpend = '1') then
                v.s := as_wptectag1;
              else
                v.s := as_normal;
              end if;
            end if;
          end if;
        else
          assert false report "Reached as_rv_xwpte!" severity failure;
        end if;

      -- Some kind of page table error occurred during MMU walk
      when as_rv_mmuwalk_pterr => -- as_mmuwalk3
        if is_access_asi_walk(r.mmusel) then
          v.s := as_rdasi2;
        else
          if is_access_i(r.mmusel) then
            oico.mds    := '0';
            if is_riscv or r.mmctrl1.nf = '0' then
              oico.mexc := '1';
            end if;
            v.imisspend := '0';
          else
            odco.mds       := '0';
            if is_riscv or r.mmctrl1.nf = '0' then
              odco.mexc    := '1';
            end if;
            if is_access_w(r.mmusel) then
              v.slowwrpend := '0';
            else
              v.dmisspend  := '0';
              -- For AMO and SC also stop write
              if r.amo.d2type(5) = '1' and (r.amo.d2type(1) = '0' or
                                            r.amo.d2type(1 downto 0) = "11") then
                v.slowwrpend := '0';
              end if;
            end if;
          end if;
          v.ramreload := '1';
          v.s         := as_normal;
        end if;
        v.dregval     := (others => '0');

      -- Some kind of PMP error occurred after MMU walk,
      -- or a PMP/bus error when fetching PT data.
      when as_rv_mmuwalk_pmperr =>
        if is_riscv then
          if is_access_asi_walk(r.mmusel) then
            v.s := as_rdasi2;
          else
            if is_access_i(r.mmusel) then
              oico.mds    := '0';
              oico.mexc   := '1';
              v.imisspend := '0';
              oico.exctype:= '1';             -- PMP fault
            else
              odco.mds     := '0';
              odco.mexc    := '1';
              if is_access_w(r.mmusel) then
                v.slowwrpend := '0';
              else
                v.dmisspend  := '0';
                -- For AMO and SC also stop write
                if r.amo.d2type(5) = '1' and (r.amo.d2type(1) = '0' or
                                              r.amo.d2type(1 downto 0) = "11") then
                  v.slowwrpend := '0';
                end if;
              end if;
              odco.exctype := '1';              -- PMP fault
            end if;
            v.ramreload := '1';
            v.s         := as_normal;
          end if;
        else
          assert false report "Reached as_rv_mmuwalk_pmperr!" severity failure;
        end if;
        v.dregval     := (others => '0');


      -- Check physical hypervisor address via PMP/PMA.
      -- With PMP/PMA, this is the actual entrypoint into as_rv_hmmuwalk.
      -- Must have r.hmmuwalk_cause set!
      when as_rv_mmu_pt2addr_pmpchk =>
        if ext_h = 1 and (pmpen or pmaen) and actual_tlb_pmp and not walk_sw then
          obifi.size := pte_hsize(1 downto 0);
          obifi.widebus := '1';
          obifi.mmuacc := '1';
          obifi.busaddr := (others => '0');
          obifi.busaddr(r.mmuaddr'range) := r.mmuaddr;

          v.s            := as_rv_hmmuwalk;
          if v.pmp_su_rwx(2) = '1' and (not pmaen or pma_pt_r(v.pma)) then
            obifi.bifop := BIFOP_SMFET;
            v.bifwait_op := BIFOP_SMFET;
          else
            -- PMP/PMA did not allow reading page table!
            v.s := as_rv_hmmuwalk_pmperr;
          end if;
        else
          assert false report "Reached as_rv_mmu_pt2addr_pmpchk!" severity failure;
        end if;

      -- Hypervisor page table walk.
      -- With PMP/PMA, always entered via as_rv_mmu_pt2addr_pmpchk since it relies
      -- on an already PMP/PMA-checked address being accessed.
      when as_rv_hmmuwalk =>
        if ext_h = 1 then

          obifi.busaddr := (others => '0');
          obifi.busaddr(r.mmuaddr'range) := r.mmuaddr;
          obifi.size := pte_hsize(1 downto 0);
          obifi.widebus := '1';
          -- Ensure PTE writes get snooped
          obifi.nosnoop := '0';
          obifi.mmuacc := '1';

          v.hnewent.mode := "010";   -- Hypervisor TLB

          -- Select which TLB entry to replace
          v.h2tlbid := pmru_decode(r.htlbpmru);

          v.hnewent.paddr  := fit0ext(pte_paddr(rdb64), v.hnewent.paddr);
          -- Deal with Svnapot by copying low bits from vaddr to low physical part.
          -- For later matches in TLB, the same kind of copying is done.
          if ext_svnapot = 1 and rdb64(rv_pte_n) = '1' then
            set_lo(v.hnewent.paddr, get(r.h_addr, gvn'low, 4));
          end if;

          if ext_svpbmt = 1 then
            v.hnewent.pbmt := rdb64(rv_pte_pbmt'range);
          end if;

          if not pmaen then
            v.hnewent.cached := pte_cached(ahbso, rdb64);
            v.hnewent.busw   := pte_busw(rdb64);
          else
            -- With PMA, the proper cached/busw setting can not yet be known!
          end if;
          if rdb32v = '1' then
            v.hnewent.modified := v.hnewent.modified or rdb32(rv_pte_d);
          end if;

          -- Coming from a PT permission check?
          -- A change to the privileged specification then allows us to set
          -- modified immediately if write is allowed.
          if r.h_cause = "00" then
            v.hnewent.modified := v.hnewent.modified or rdb32(rv_pte_w);
          end if;

          -- Prepare hwdata for writing back PTE with R/M bits set
          -- Check if write-back is needed
          obifi.stdata := rdb64;
          pte_mark_modacc(obifi.stdata, r.hnewent.modified, vneedwb, vneedwblock);
          v.hnewent.perm := "11" & rdb32(rv_pte_x downto rv_pte_r);
          v.hnewent.h_r  := rdb32(rv_pte_r);

          --if not is_riscv then
          --  v.hnewent.acc := rdb32(4 downto 2);
          --else
            v.hnewent.acc := (others => '0');
          --end if;
          --v.dregval       := rdb32;
          v.dregval       := rdb64;

          if rdb32v = '1' and bifo.stat.ready='1' then
            obifi.clrrdbuf := '1';


            -- Depending on level/type -
            --   update haddr to go down to next level
            --   write back "accessed" bit
            --   update TLB and register of access causing miss

            -- AHB error fetching entry?
            if bifo.rdb.err='1' then
              v.s := as_rv_hmmuwalk_pterr;

            -- Page table entry?
            elsif is_pte(rdb32) then

              -- Not valid?
              if not is_valid_pte(rdb64, r.hnewent.mask) or
                 -- All accesses are "user mode" at hypervisor PT level.
                 rdb64(rv_pte_u) = '0' then
                v.s := as_rv_hmmuwalk_pterr;

              -- Permission error according to page table?
              -- For now, assume PMP allows read (corrected later),
              -- since we need to do any writeback before that check, anyway.
              elsif not permitted(r.h_x, '0', r.h_ls,
                                  "11" & rdb32(rv_pte_x downto rv_pte_r),
                                  '1', rdb32(rv_pte_r), '0',
                                  '0', r.h_mxr, r.h_vmxr, r.h_hx) then
                v.s := as_rv_hmmuwalk_pterr;

              -- Address is not zero extended?
              elsif is_riscv and not all_0(rdb64(rv_ppn'high downto physbits - 12 + 10)) then
                v.s := as_rv_hmmuwalk_pmperr;

              -- Writeback needed?
              elsif vneedwb = '1' then
                -- Always fault?
                if csro.m_adue = '0' or (ext_h = 1 and csro.h_ade = '1') then
                  v.s            := as_rv_hmmuwalk_pterr;
                -- Writeback permission according to PMP/PMA?
                elsif (    actual_tlb_pmp and (v.pmp_su_rwx(1) = '1' or not (pmpen or pmaen)) and
                                              (pma_pt_w(v.pma) or not pmaen)) or
                      (not actual_tlb_pmp and r.pt_no_w = '0') then
                  if vneedwblock = '1' and r.biflocked = '0' then
                    do_mmu_lock  := true;
                    v.s          := as_rv_hmmuwalk_lock;
                  else
                    v.s          := as_rv_hwpte;
                    obifi.bifop  := BIFOP_STORE;
                  end if;
                else
                  v.s            := as_rv_hmmuwalk_pmperr;
                end if;

              -- Check PMP/PMA permission error, if applicable.
              elsif actual_tlb_pmp and (pmpen or pmaen) then
                v.pmp_mask := pt_mask(r.hnewent.mask, is_svx4_smaller(csro));
                v.pmp_low  := fit0ext(v.hnewent.paddr & x"000", v.pmp_low) and v.pmp_mask;
                v.pmp_do   := '1';
                v.s         := as_rv_mmu_pte2_pmpchk;

              -- OK!
              else

                v.h2tlbupd    := '1';

                v.s := as_rv_hmmuwalk_done;
              end if;

            -- Page table descriptor (and not too deep)?
            elsif is_ptd(rdb32) and is_valid_ptd(rdb64) and
                  not pt_end_reached(r.hnewent.mask, is_svx4_smaller(csro)) then
              -- Address is not zero extended?
              if is_riscv and not all_0(rdb64(rv_ppn'high downto physbits - 12 + 10)) then
                v.s := as_rv_hmmuwalk_pmperr;
              else
                -- Shift in a '1' for each new TLB level.
                v.hnewent.mask := next_level_mask(r.hnewent.mask);

                haddr  := pt_addr(rdb64, v.hnewent.mask, r.hnewent.vaddr, is_svx4_smaller(csro));
                v.mmuaddr   := haddr(v.mmuaddr'range);
                obifi.busaddr := (others => '0');
                obifi.busaddr(v.mmuaddr'range) := v.mmuaddr;

                -- "va" is all zeroes and will give the base address.
                -- v.pmp_mask is already set from above. Always 4 kByte.
                v.pmp_low   := fit0ext(pt_addr(rdb64, v.hnewent.mask, va, is_svx4_smaller(csro)), v.pmp_low);
                if actual_tlb_pmp then
                  v.pmp_do  := '1';
                end if;

                -- Return physical address for next level of page table.

                -- This is needed to split the PMP/PMA dependancy chain.
                if pmpen or pmaen then
                  if actual_tlb_pmp then
                    v.s          := as_rv_mmu_pt2addr_pmpchk;
                  else
                    pmp_mmu      := '1';
                    v.s          := as_rv_hmmuwalk;
                    obifi.bifop  := BIFOP_SMFET;
                  end if;
                else
                  v.s          := as_rv_hmmuwalk;
                  obifi.bifop := BIFOP_SMFET;
                end if;
              end if;

            -- Invalid/reserved or too many levels of PTDs
            else
              v.s := as_rv_hmmuwalk_pterr;
            end if;
          end if;
        else
          assert false report "Reached as_rv_hmmuwalk!" severity failure;
        end if;

      -- Check HPTE range for PMP accessability, and shrink as necessary.
      when as_rv_mmu_pte2_pmpchk =>
        if ext_h = 1 and actual_tlb_pmp and (pmpen or pmaen) and not walk_sw then

          -- PMP area matches (or is larger than) PTE area?
          if v.pmp_fit = '1' then

            -- Update TLB permissions according to PMP
            v.hnewent.pmp_r     := v.pmp_su_rwx(2);
            v.hnewent.pmp_no_w  := '0';
            v.hnewent.pmp_no_x  := '0';
            if v.pmp_su_rwx(0) = '0' then  -- Execute?
              v.hnewent.perm(2) := '0';
            end if;
            if v.pmp_su_rwx(1) = '0' then  -- Write?
              v.hnewent.perm(1) := '0';
            end if;
            if v.pmp_su_rwx(2) = '0' then  -- Read?
              v.hnewent.perm(0) := '0';
            end if;

            if pmaen then
              if ext_svpbmt = 1 then
                v.pma          := pbmt_pma_update(r.hnewent.pbmt, v.pma);
              end if;
              v.hnewent.pma    := v.pma;
              -- With PMA these are not known before!
              v.hnewent.busw   := pma_busw(v.pma);
              v.hnewent.cached := pma_cache(v.pma);
            else
              if ext_svpbmt = 1 then
                -- Even without PMA, at least cacheability can be disabled.
                if r.hnewent.pbmt /= "00" then
                  v.hnewent.cached := '0';
                end if;
              end if;
            end if;
            if walk_pmp then
              v.hnewent.pmp_none := v.pmp_none;
              v.hnewent.pmp_lock := v.pmp_lock;
              v.hnewent.pmp_rwx  := v.pmp_rwx;
            end if;

            -- PMP permission error?
            if    is_access_hpt(r.mmusel) then  -- hPT walk?
              ok := v.pmp_su_rwx(2) = '1';
              if pmaen and not pma_pt_r(v.hnewent.pma) then
                ok := false;
              end if;
            elsif is_access_i(r.mmusel) then    -- Execute?
              ok := v.pmp_su_rwx(0) = '1';
            elsif is_access_w(r.mmusel) or      -- Write?
                  -- Shadow stack instructions always check for writeability
                  (ext_zicfiss = 1 and r.d2ss = '1') or
                  -- Most AMO also do write, even though it is not visible in mmusel.
                  (r.amo.d2type(5) = '1' and
                   (r.amo.d2type(1) = '0' or r.amo.d2type(1 downto 0) = "11")) then
              ok := v.pmp_su_rwx(1) = '1';
              if pmaen and r.amo.d2type(5) = '1' then
                if r.amo.d2type(1) = '1' and not pma_lrsc(v.pma) then
                  ok := false;
                elsif not pma_amo(v.pma) then
                  ok := false;
                end if;
              end if;
            else                                -- Read?
              ok := v.pmp_su_rwx(2) = '1';
              if pmaen and r.amo.d2type(5) = '1' then
                if r.amo.d2type(1) = '1' and not pma_lrsc(v.pma) then
                  ok := false;
                end if;
              end if;
            end if;

            if not ok then
              v.s := as_rv_mmuwalk_pmperr;

            -- OK!
            else
              v.h2tlbupd := '1';
              v.s        := as_rv_hmmuwalk_done;
            end if;

          -- PMP hit but not fit (and not too deep in shrinking)?
          elsif v.pmp_hit = '1' and not pt_end_reached(r.hnewent.mask, is_svx4_smaller(csro)) then
            -- Shift in a '1' for each new fake TLB level.
            v.hnewent.mask := next_level_mask(r.hnewent.mask);


            -- Insert next part of address
            part_mask := get_right(pt_mask(r.hnewent.mask, is_svx4_smaller(csro)) xor
                                   pt_mask(v.hnewent.mask, is_svx4_smaller(csro)), part_mask);
            part            := fit0ext(r.h_addr, part) and part_mask;
            v.hnewent.paddr := r.hnewent.paddr or part(v.hnewent.paddr'range);
            v.pmp_mask      := pt_mask(v.hnewent.mask, is_svx4_smaller(csro));
            v.pmp_low       := fit0ext(v.hnewent.paddr & x"000", v.pmp_low) and v.pmp_mask;
            v.pmp_do        := '1';

            v.s             := as_rv_mmu_pte2_pmpchk;

          -- Invalid/reserved or too many levels of PTDs
          else
            v.s := as_rv_mmuwalk_pmperr;
          end if;
        else
          assert false report "Reached as_rv_mmu_pte2_pmpchk!" severity failure;
        end if;

      -- Aquire AHB lock and then write back HPTE.
      -- (Needed when writeback with 'modified' set.)
      when as_rv_hmmuwalk_lock =>
        if ext_h = 1 and not walk_sw then
          obifi.busaddr := (others => '0');
          obifi.busaddr(r.mmuaddr'range) := r.mmuaddr;
          obifi.widebus := '1';
          obifi.size := pte_hsize(1 downto 0);
          obifi.nosnoop := '0';
          obifi.mmuacc := '1';
          vstd64 := rdb64;
            do_mmu_lock := true;
            vstd32(rv_pte_a) := '1';  -- set accessed bit
          obifi.stdata := vstd64;
          if r.biflocked='0' then
            vtoglock := '1';
          end if;
          if bifo.rdb.err='1' then
            -- AHB error fetching entry

            do_mmu_lock := false;
            v.s := as_rv_hmmuwalk_pmperr;
          elsif rdb32v='1' and bifo.stat.ready='1' then
            v.s := as_rv_hwpte;
              do_mmu_lock := false;
              v.newent.modified := r.newent.modified or rdb32(rv_pte_d);
            obifi.bifop := BIFOP_STORE;
          elsif rdb32v='1' or bifo.stat.idle='0' then
            -- wait for read access to complete
            null;
          elsif r.biflocked='1' and bifo.stat.ready='1' then
            -- start read access with lock held
            obifi.bifop := BIFOP_SMFET;
          end if;
        else
          assert false report "Reached as_rv_hmmuwalk_lock!" severity failure;
        end if;

      -- Hypervisor page table walk finished.
      -- Where to return to depends on why the walk was done.
      when as_rv_hmmuwalk_done =>
        if ext_h = 1 then
          -- TLB is now updated, so do another lookup.
          v.h_do := '1';
          -- Checking first level PT address?
          if r.h_cause = "00" then
            v.mmusel(3) := '0';      -- Done with hPT walk
            v.h_x    := '0';
            v.h_ls   := '0';
            v.h_mxr  := '0';
            v.h_vmxr := '0';
            v.h_hx   := '0';
            v.s      := as_rv_mmu_pt1addr_chk;
          -- Checking first level PTE range?
          else
            v.h_x    := r.mmuerr.at_id;
            v.h_ls   := r.mmuerr.at_ls;
            v.h_mxr  := r.d2mxr  and not v.h_x;
            v.h_vmxr := r.d2vmxr and not v.h_x;
            v.h_hx   := r.d2hx   and not v.h_x;
            v.s      := as_rv_mmu_pte1_hchk;
          end if;
          -- The hypervisor TLB is now supposed to have been updated
          -- with a matching entry. Mark so that this can be verified!
          v.h_done := '1';
        else
          assert false report "Reached as_rv_hmmuwalk_done!" severity failure;
        end if;

      -- Write back hypervisor PTE
      when as_rv_hwpte =>
        if ext_h = 1 and not walk_sw then
          done           := false;
          if bifo.stat.ready='1' then
            done := true;
          end if;

          if done then
            -- Check PMP permission error, if applicable.
            if actual_tlb_pmp and (pmpen or pmaen) then
              v.pmp_mask := pt_mask(r.hnewent.mask, is_svx4_smaller(csro));
              v.pmp_low  := fit0ext(r.hnewent.paddr & x"000", v.pmp_low) and v.pmp_mask;
              v.pmp_do   := '1';
              v.s        := as_rv_mmu_pte2_pmpchk;
            else
              v.h2tlbupd := '1';
              v.s        := as_rv_hmmuwalk_done;
            end if;
          end if;
        else
          assert false report "Reached as_hwpte!" severity failure;
        end if;

      -- Some kind of page table error occurred during HMMU walk
      -- (or MMU walk turned up invalid GPA)
      when as_rv_hmmuwalk_pterr =>
        if ext_h = 1 then
          if is_access_i(r.mmusel) then
            oico.mds       := '0';
            oico.mexc      := '1';
            oico.exchyper  := '1';
            v.imisspend    := '0';
          else
            odco.mds       := '0';
            odco.mexc      := '1';
            odco.exchyper  := '1';
            if is_access_w(r.mmusel) then
              v.slowwrpend := '0';
            else
              v.dmisspend  := '0';
              -- For AMO and SC also stop write
              if r.amo.d2type(5) = '1' and (r.amo.d2type(1) = '0' or
                                            r.amo.d2type(1 downto 0) = "11") then
                v.slowwrpend  := '0';
              end if;
            end if;
          end if;
          v.ramreload := '1';
          v.s         := as_normal;
        else
          assert false report "Reached as_rv_hmmuwalk_pterr!" severity failure;
        end if;

      -- Some kind of PMP error occurred after MMU walk,
      -- or a PMP/bus error when fetching PT data.
      when as_rv_hmmuwalk_pmperr =>
        if ext_h = 1 then
          if is_access_i(r.mmusel) then
            oico.mds      := '0';
            oico.mexc     := '1';
            oico.exchyper := '1';
            v.imisspend   := '0';
            oico.exctype  := '1';             -- PMP fault
          else
            odco.mds       := '0';
            odco.mexc      := '1';
            odco.exchyper  := '1';
            if is_access_w(r.mmusel) then
              v.slowwrpend := '0';
            else
              v.dmisspend  := '0';
              -- For AMO and SC also stop write
              if r.amo.d2type(5) = '1' and (r.amo.d2type(1) = '0' or
                                            r.amo.d2type(1 downto 0) = "11") then
                v.slowwrpend := '0';
              end if;
            end if;
            odco.exctype := '1';              -- PMP fault
          end if;
          v.ramreload := '1';
          v.s         := as_normal;
        else
          assert false report "Reached as_rv_hmmuwalk_pmperr!" severity failure;
        end if;

      when as_rv_cbo =>
        if arch = RISCV and ext_zicbom /= 0 then
          -- Miss before.
          v.mmusel             := access_w;
          if walk_pmp and r.d2paddrv = '0' and not mmu_enabled(v.d2mode) then
            start_pmp     := true;   -- See more after case.
          elsif mmuen = 1 and r.d2paddrv = '0' then
            -- This will never happen without MMU enabled.
            start_walk         := true;   -- See more after case.
          else
            v.s             := as_normal;
            v.cbo.d2type(2) := '0';
            v.slowwrpend    := '0';
            v.dmisspend     := '0';
            v.iregflush     := '0';
            v.dregflush     := '1';
            v.iflushpend := v.iflushpend or v.iregflush;
            v.dflushpend := v.dflushpend or v.dregflush;
            v.regflmask     := (others => '1');
            v.regflmask(4)  := '0';
            v.regfladdr     := (others => '0');
            v.regfladdr(dphysbits-1 downto 4) := r.d2paddr(dphysbits-1 downto 4);
          end if;
        else
          v.s          := as_normal;
          v.dmisspend      := '0';
          v.slowwrpend := '0';
        end if;
    end case;


    if ext_h = 1 and start_hwalk then
      v.perf(11)       := '1';
      if walk_fault and csro.mmu_hptfault = '1' then
        v.hwalk_fault  := '1';
        v.s            := as_rv_hmmuwalk_pterr;
        --v.ahb.htrans   := HTRANS_IDLE;
      elsif pmpen or pmaen then
        if actual_tlb_pmp then
          v.s          := as_rv_mmu_pt2addr_pmpchk;
        else
          pmp_mmu      := '1';
          v.s          := as_rv_hmmuwalk;
          --v.ahb.htrans := HTRANS_NONSEQ;
          obifi.bifop := BIFOP_SMFET;
          v.bifwait_op := BIFOP_SMFET;
        end if;
      else
        v.s            := as_rv_hmmuwalk;
        --v.ahb.htrans   := HTRANS_NONSEQ;
        obifi.bifop := BIFOP_SMFET;
        v.bifwait_op := BIFOP_SMFET;
      end if;
      start_pmp  := false;  -- Cannot really be true if we get here!
      start_walk := false;  -- Cannot really be true if we get here!
    end if;

    if actual_tlb_pmp and walk_pmp and start_pmp then
      do_access  := false;  -- Cannot really be true if we get here!
      start_walk := false;  -- Cannot really be true if we get here!
      v.s        := as_rv_start_pmp;
    end if;

    if is_riscv and mmuen = 1 and start_walk then
      if walk_sw or (walk_fault and csro.mmu_sptfault = '1') then
        v.swalk_fault := '1';
        v.s           := as_rv_mmuwalk_pterr;
        pmp_mmu       := '0';
      elsif walk_state then
        do_access := false;  -- Cannot really be true if we get here!
        v.s := as_rv_start_walk;
      else
        iaddr_ok  := true;
        daddr_ok  := true;
        do_access := false;  -- Cannot really be true if we get here!

        -- Assume supervisor page tables need to be checked
        v.h_x    := '0';
        v.h_ls   := '0';
        v.h_mxr  := '0';
        v.h_vmxr := '0';
        v.h_hx   := '0';
        v.s      := as_rv_mmu_pt1addr_chk;

        -- On RISC-V, the base is indexed directly for the first level.
        -- Return physical address for next level of page table.
        -- Also, remember the V flag and perhaps set up a fake entry if hypervisor.
        mmu_data                                  := (others => '0');
        case v.mmusel is
        when access_i =>
          mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(csro, v.i2mode);
          haddr                                   := pt_addr_base(mmu_data, v.i2pc, is_sv_smaller(csro, v.i2mode));
          v.h_v               := is_v(v.i2mode);
          iaddr_ok            := virtual_ok(v.i2pc, is_sv_smaller(csro, v.i2mode));
          v.newent.ctx        := v.i2ctx;
          v.newent.mode       := v.i2mode;
          v.newent.vaddr      := v.i2pc(gvn'range);
          v.mmuerr.at_ls      := '0';        -- Load/Execute
          v.mmuerr.at_id      := '1';        -- Instruction space
          v.mmuerr.at_su      := r.i2su;
          -- Actually hypervisor but no supervisor page tables?
          if hmmu_only(v.i2mode) then
            iaddr_ok          := gphysical_ok(v.i2pc, is_svx4_smaller(csro));
            v.h_mxr           := '0';
            v.h_vmxr          := '0';
            v.h_hx            := '0';
            do_pte1_hchk      := true;
          end if;
        when access_r | access_asi_walk =>
          mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(csro, v.d2mode);
          haddr                                   := pt_addr_base(mmu_data, v.d2vaddr, is_sv_smaller(csro, v.d2mode));
          v.h_v               := is_v(v.d2mode);
          daddr_ok            := virtual_ok(v.d2vaddr, is_sv_smaller(csro, v.d2mode));
          v.newent.ctx        := mmu_ctx(csro, v.d2mode);
          v.newent.mode       := v.d2mode;
          v.newent.vaddr      := v.d2vaddr(gvn'range);
          v.mmuerr.at_ls      := to_bit(is_access_w(r.mmusel));
          v.mmuerr.at_id      := '0';
          v.mmuerr.at_su      := v.d2su;
          -- Actually hypervisor but no supervisor page tables?
          if hmmu_only(v.d2mode) then
            daddr_ok          := gphysical_ok(v.d2vaddr, is_svx4_smaller(csro));
            v.h_mxr           := v.d2mxr;
            v.h_vmxr          := v.d2vmxr;
            v.h_hx            := v.d2hx;
            -- Treat atomic access as store to avoid store phase of atomic
            -- causing mmu fault.
            if v.d2atomic = '1' and v.amo.d2type /= "100010" then  -- Atomic but not LR
              v.mmuerr.at_ls  := '1';
            end if;
            do_pte1_hchk      := true;
          end if;
        -- Really "11" (access_w), since "10" is unused.
        when others =>
          mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(csro, r.d2mode);
          haddr                                   := pt_addr_base(mmu_data, r.d2vaddr, is_sv_smaller(csro, r.d2mode));
          v.h_v               := is_v(r.d2mode);
          daddr_ok            := virtual_ok(r.d2vaddr, is_sv_smaller(csro, r.d2mode));
          v.newent.ctx        := mmu_ctx(csro, r.d2mode);
          v.newent.mode       := r.d2mode;
          v.newent.vaddr      := r.d2vaddr(gvn'range);
          v.mmuerr.at_ls      := '1';
          v.mmuerr.at_id      := '0';
          v.mmuerr.at_su      := r.d2su;
          -- Actually hypervisor but no supervisor page tables?
          if hmmu_only(r.d2mode) then
            daddr_ok          := gphysical_ok(r.d2vaddr, is_svx4_smaller(csro));
            v.h_mxr           := r.d2mxr;
            v.h_vmxr          := r.d2vmxr;
            v.h_hx            := r.d2hx;
            do_pte1_hchk      := true;
          end if;
        end case;

        if addr_check_mask(4) = '0' then
          iaddr_ok := true;
        end if;
        if addr_check_mask(0) = '0' then
          daddr_ok := true;
        end if;

        v.mmuaddr := haddr(v.mmuaddr'range);
        if ext_h = 1 then
          v.h_addr  := haddr(v.h_addr'range);
        end if;
        v.pmp_low   := fit0ext(mmu_data & "00", v.pmp_low);

        -- First level page table accessibility
        if hmmu_enabled(csro, v.h_v) then
          v.h_do            := '1';
          v.h_x             := '0';
          v.h_ls            := '0';
          -- Possible L1 PT read fault due to L2 PT.
          -- Instruction or data access.
          v.itypehyper      := v.h_x       & '0';
          v.dtypehyper      := (not v.h_x) & '0';
        elsif actual_tlb_pmp then
          v.pmp_do          := '1';
        end if;

        v.newent.mask := first_level_mask(is_sv_smaller(csro, v.newent.mode));

        -- Check top bits of *ATP
        guest_top_ok        := true;
        phys_top_ok         := true;
        if hmmu_enabled(csro, v.h_v) then
          guest_top_ok      := top_gpa_zeros(haddr, is_svx4_smaller(csro));
        else
          phys_top_ok       := all_0(haddr(haddr'high downto pa_msb + 1));
        end if;

        -- hPT only?
        if do_pte1_hchk then
          v.s               := as_rv_mmu_pte1_hchk;
          v.newent.perm     := (others => '1');
          v.newent.modified := v.mmuerr.at_ls;

          -- Check PTE range with hypervisor page tables, if applicable.
          -- v.newent.paddr    := fit0ext(pte_paddr(rdb64), v.newent.paddr);
          v.h_addr          := fit0ext(v.newent.vaddr & x"000", v.h_addr);
          v.h_ls            := v.mmuerr.at_ls;
          v.h_x             := v.mmuerr.at_id;
          -- Possible access fault due to L2 PT.
          -- Instruction or data access.
          v.itypehyper      := '0' & v.h_x;
          v.dtypehyper      := '0' & not v.h_x;
          if not iaddr_ok or not daddr_ok then
            v.s := as_rv_hmmuwalk_pterr;
          else
          end if;
        else
          if not iaddr_ok or not daddr_ok then
            v.s := as_rv_mmuwalk_pterr;
          elsif not guest_top_ok then
            v.s := as_rv_hmmuwalk_pterr;
          elsif not phys_top_ok then
            v.s := as_rv_mmuwalk_pmperr;
          end if;
        end if;
        -- end if;
      end if;
    end if;

    if is_riscv and not actual_tlb_pmp then
      -- PMP check page table address, if pmp_mmu.
      pmp_xc     := '0';
      pmp_hit    := (others => '0');
      if pmpen then
        pmp      := pmp_clear;      -- Ensure no latches!
        pmp.mpp  := (others => '0');
        pmp.addr := fit0ext(v.mmuaddr, pmp.addr);

        pmp_hit := pmp_match(csro.precalc,
                             pmp.addr,
                             pmp_entries, pmp_no_tor, pmp_g, pmp_msb);
        pmp_rwx := smepmp_rwx(csro.pmpcfg, csro.mmwp, csro.mml,
                              PRIV_LVL_S,
                              pmp_hit,
                              pmp_entries, ext_smepmp);
        pmp_xc  := not pmp_rwx(2);
        if pmp_mmu = '1' then
          -- Remember writability for later PTE writeback check
          v.pt_no_w := not pmp_rwx(1);
        end if;
      end if;

      if pmaen then
        if pma_masked = 0 then
          pma_unit(csro.pma_precalc,
                   pmp.addr,
                   pmp_mmu,
                   pma_hit,
                   pma_entries, 0, pmp_msb);
          pma_fit := (others => '0');

          -- Keep only the lowest numbered hit, since that is
          -- defined as the highest priority PMA.
          pma_prio := pma_hit and std_logic_vector(-signed(pma_hit));
          pma_idx  := fit0ext(clz(reverse(uext(pma_hit, PMAENTRIES))), pma_idx);
          pma      := to_pma(csro.pma_data(u2i(pma_idx)));
        else
          pma_masks(csro.pma_data,
                    pmp.addr,
                    pmp_mmu,
                    pma, pma_fit,
                    pmp_msb);
          pma_hit  := (others => '1');
          pma_prio := (others => '1');
          pma_idx  := (others => '0');
          -- pma_fit is only useful for debug here!
          -- In the Sv32 case, the first level page table covers bits 31:22, so
          -- with masks at 31:28 (only supported case) there will always be a fit.
          if riscv_mmu = Sv32 then
            pma_fit := (others => '1');
          end if;
        end if;

        if pmp_mmu = '1' then
          -- Remember writability for later PTE writeback check
          if not pma_pt_w(pma) then
            v.pt_no_w := '1';
          end if;
          -- Also busw etc (bypass ASI)
          if pma_valid(pma) then
            v.pma := pma;
          else
            v.pma := pma_unused;
          end if;
          -- Need to hit a PMA entry!
          if all_0(pma_hit) then
            pmp_xc := '1';
          elsif not pma_valid(pma) then
            pmp_xc := '1';
          elsif not pma_pt_r(pma) then
            pmp_xc := '1';
          else
          end if;

          if pma_forced_fault(csro, pmp.addr) then
            pmp_xc := '1';
          end if;
        end if;
      end if;

      -- Fault masking
      if is_access_i(r.mmusel) then  -- Instruction fetch
        if addr_check_mask(3) = '0' then
          pmp_xc := '0';
        end if;
      else                           -- Data read/write?
        if addr_check_mask(7) = '0' then
          pmp_xc := '0';
        end if;
      end if;

      if pmp_mmu = '1' and pmp_xc = '1' then
        do_access := false;
        v.s       := as_rv_mmuwalk_pmperr;
        if ext_h = 1 and v.mmusel(3) = '1' then  -- Doing hPT walk?
          v.s     := as_rv_hmmuwalk_pmperr;
        end if;
      end if;
    end if;

    -- AMO: extend hold until store is executed
    if (r.amo.hold = '1' and store_done) or ext_a = 0 then
      v.amo.hold := '0';
      v.amo.sc   := '0';
    end if;

    if r.d2atomic = '1' and v.d2atomic = '0' then
      v.amo.d2type := (others => '0');
    end if;


    if obifi.bifop=BIFOP_LOCK then
      v.biflocked := '1';
    elsif obifi.bifop=BIFOP_NOP then
      v.biflocked := '0';
    end if;
    if bifo.stat.ready='1' and vdlyop='0' then
      if (r.biflocked='0' and vtoglock='1') or (v.biflocked='1' and vtoglock='0') then
        v.bifwait_op := BIFOP_LOCK;
      else
        v.bifwait_op := BIFOP_NOP;
      end if;
      v.bifwait_wc := '0';
    end if;

    if v.itcmwipe='1' or v.dtcmwipe='1' then
      v.itcmenp := '0';
      v.itcmenva := '0';
      v.itcmenvc := '0';
      v.dtcmenp := '0';
      v.dtcmenva := '0';
      v.dtcmenvc := '0';
    end if;

    -- SMP broadcast flush
    if smpflush(1)='1' then
      v.iflushpend := '1';
    end if;
    if smpflush(0)='1' then
      v.tlbflush := '1';
      v.htlbflush := '1';
    end if;


   if arch = SPARC then
    -- Debug link access
    -- Stage 4 : tag recheck d1 -> d2, set dmisspend (if read miss) / slowwrpend
    if r.dbgacc(1)='1' then
      if r.dbgaccwr='1' then
        v.slowwrpend := '1';
      end if;
    end if;
    -- Stage 3 : ram reload in progress
    v.dbgacc(1) := r.dbgacc(0);
    if r.dbgacc(0)='1' then
      v.ramreload := '0';
      if r.dbgacc(1)='0' then
        v.d1chk := '1';
      end if;
    end if;
    -- Stage 2 : capture virtual address and set ramreload
    if r.dbgaccpend='1' and r.fsmidle='1' then
      v.dbgacc(0) := '1';
      v.d1vaddr := dci.maddress(v.d1vaddr'range);
      if r.dbgacc(0)='0' then
        v.ramreload := '1';
      end if;
    end if;
    -- Stage 1 : capture read/write command
    if dci.dsuen='1' and dci.enaddr='1' and r.holdn='1' then
      if dci.read='1' then
        v.dbgaccpend := '1';
      end if;
      if dci.write='1' then
        v.dbgaccpend := '1';
        v.dbgaccwr := '1';
      end if;
    end if;
    if r.dbgacc(1)='1' or dci.dsuen='0' then
      v.dbgacc := (others => '0');
      v.dbgaccpend := '0';
      v.dbgaccwr := '0';
    end if;
   end if;

    v.holdn := '1';
    if ( v.imisspend='1' or v.dmisspend='1' or v.slowwrpend='1' or
         v.iflushpend='1' or v.dflushpend='1' or v.ramreload='1' or
         v.amo.hold='1' or v.cbo.hold='1' or
         --
         v.stbuffull='1' or v.syncbar='1' or v.dbgaccpend='1' or freeze='1') then
      v.holdn := '0';
    end if;

    -- Update valid bits
    for i in vs.validarr'range loop
      vs.validarr(i) := (rs.validarr(i) and (not vbitclr(i))) or vbitset(i);
    end loop;

    -- Data loopback if no bw support
    ocrami.ddataloop := (others => '0');
    if dusebw=0 then
      -- ocrami.ddataloop := not ocrami.ddatawrite;
      -- Mimic generation of ddatawrite but in a way that
      -- does not depend on r.holdn or dhit
      if r.s=as_flush or r.s=as_dcfetch or r.s=as_wrasi2 or r.s=as_atomic4 then
        ocrami.ddataloop := (others => '0');
      elsif r.s=as_wptectag2 or r.s=as_atomic2 or r.s=as_atomic3 then
        ocrami.ddataloop := not getdmask64(r.d2vaddr,r.d2size,(endian='1'));
      else
        ocrami.ddataloop := not getdmask64(r.d1vaddr,dci.size,(endian='1'));
      end if;
--pragma translate_off
      assert (ocrami.ddatawrite(7 downto 4)=(not ocrami.ddataloop(7 downto 4)) or
              ocrami.ddatawrite(7 downto 4)="0000" or ocrami.ddataen="0000"   );
      assert (ocrami.ddatawrite(3 downto 0)=(not ocrami.ddataloop(3 downto 0)) or
              ocrami.ddatawrite(3 downto 0)="0000" or ocrami.ddataen="0000"   );
--pragma translate_on
      if ocrami.ddatawrite(7 downto 4) /= "0000" then
        ocrami.ddatawrite(7 downto 4) := "1111";
      end if;
      if ocrami.ddatawrite(3 downto 0) /= "0000" then
        ocrami.ddatawrite(3 downto 0) := "1111";
      end if;
    end if;

    -- Combined read/update port for Dtag RAM
    ocrami.dtagcuindex := ocrami.dtagcindex;
    ocrami.dtagcuen := ocrami.dtagcen;
    ocrami.dtagcuwrite := '0';
    if bifo.dtu.utype/="00" then
      ocrami.dtagcuindex := bifo.dtu.uidx;
      ocrami.dtagcuen := bifo.dtu.upd;
      ocrami.dtagcuwrite := '1';
    end if;

    if r.s = as_dcfetch or r.s = as_dcsingle then
      odco.data(0) := rdbuf_data;
    end if;

    -- TCM wiping support
    ocrami.dtcmwrite := ocrami.ddatawrite;
    if r.dtcmwipe='1' then
      ocrami.dtcmen := '1';
      ocrami.dtcmwrite := "11111111";
      ocrami.dtcmdin := (others => '0');
      ocrami.ddatafulladdr := r.tcmdata;
      ocrami.ddatafulladdrw := r.tcmdata;
    end if;
    ocrami.itcmwrite := ocrami.idatawrite;
    ocrami.itcmdin := ocrami.idatadin;
    if r.itcmwipe='1' then
      ocrami.itcmen := '1';
      ocrami.itcmwrite := "11";
      ocrami.itcmdin := (others => '1');
      ocrami.ifulladdr := r.tcmdata;
      ocrami.ifulladdrw := r.tcmdata;
    end if;
    if r.dtcmwipe='1' or r.itcmwipe='1' then
      v.tcmdata(31 downto 3) := std_logic_vector(unsigned(r.tcmdata(31 downto 3))+1);
      v.tcmdata(2 downto 0) := "000";
      for x in 31 downto 3 loop
        if (itcmen=0 or x>(2+itcmabits)) and (dtcmen=0 or x>(2+dtcmabits)) then
          v.tcmdata(x) := '0';
        end if;
      end loop;
      if v.tcmdata=(v.tcmdata'range => '0') then
        v.dtcmwipe := '0';
        v.itcmwipe := '0';
      end if;
    end if;

    v.dtraptt := TT_DSEX;
    v.dtrapet1 := '0';
    v.dtrapet0 := '0';
    if v.ctrappend /= "0000" then
      v.dtrapet1 := '1';
      v.dtrapet0 := '1';
      v.dtraptt := "110000";
    elsif v.wtrappend /= "00" then
      v.dtrapet1 := '1';
      v.dtrapet0 := '0';
      if (v.wtrappend(0)='1' and r.ahbwtrapmode(0)='1') or (v.wtrappend(1)='1' and r.mmuwtrapmode(0)='1') then
        v.dtrapet0 := '1';
      end if;
    end if;
    if notx(r.ctrappend) and notx(rst) then
      assert r.ctrappend(1) = '0' or rst /= '1' report "Double D-Tag read" severity failure;
    end if;

    v.ctrapacc := v.ctrapacc or v.ctrappend;

    --------------------------------------------------------------------------
    -- Reset
    --------------------------------------------------------------------------

    if ( GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 and
         GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all)=0 ) then
      if rst='0' then
       if arch = SPARC then
        v.cctrl.dcs      := RRES.cctrl.dcs;
        v.cctrl.ics      := RRES.cctrl.ics;
        v.cctrl.ics_btb  := RRES.cctrl.ics_btb;
        v.cctrl.dsnoop   := RRES.cctrl.dsnoop;
        v.cctrl.wcomben  := RRES.cctrl.wcomben;
        v.cctrl.wchinten := RRES.cctrl.wchinten;
        v.cctrl.diaemru  := RRES.cctrl.diaemru;
       end if;
        v.iuctrl         := RRES.iuctrl;
        v.itcmenp        := RRES.itcmenp;
        v.itcmenva       := RRES.itcmenva;
        v.itcmenvc       := RRES.itcmenvc;
        v.itcmperm       := RRES.itcmperm;
        v.itcmaddr       := RRES.itcmaddr;
        v.itcmctx        := RRES.itcmctx;
        v.dtcmenp        := RRES.dtcmenp;
        v.dtcmenva       := RRES.dtcmenva;
        v.dtcmenvc       := RRES.dtcmenvc;
        v.dtcmperm       := RRES.dtcmperm;
        v.dtcmaddr       := RRES.dtcmaddr;
        v.dtcmctx        := RRES.dtcmctx;
        v.itcmwipe       := RRES.itcmwipe;
        v.dtcmwipe       := RRES.dtcmwipe;
        v.regflmask      := RRES.regflmask;
        v.regfladdr      := RRES.regfladdr;
        v.iregflush      := RRES.iregflush;
        v.dregflush      := RRES.dregflush;
       if arch = SPARC then
        v.mmctrl1.e      := RRES.mmctrl1.e;
        v.mmctrl1.nf     := RRES.mmctrl1.nf;
        v.mmctrl1.ctx    := RRES.mmctrl1.ctx;
       end if;
        v.mmctrl1.tlbdis := RRES.mmctrl1.tlbdis;
        v.mmctrl1.pso    := RRES.mmctrl1.pso;
        v.mmctrl1.bar    := RRES.mmctrl1.bar;
        v.mmfsr.fav      := RRES.mmfsr.fav;
        v.s              := RRES.s;
        v.imisspend      := RRES.imisspend;
        v.dmisspend      := RRES.dmisspend;
        v.iflushpend     := RRES.iflushpend;
        v.dflushpend     := RRES.dflushpend;
        v.slowwrpend     := RRES.slowwrpend;
        v.syncbar        := RRES.syncbar;
        v.irdbufen       := RRES.irdbufen;
        v.holdn          := RRES.holdn;
        v.i2paddrv       := RRES.i2paddrv;
        v.i1ten          := RRES.i1ten;
        v.i1cont         := RRES.i1cont;
        v.i1rep          := RRES.i1rep;
        v.ibpmiss        := RRES.ibpmiss;
        v.d1ten          := RRES.d1ten;
        v.dwchint        := RRES.dwchint;
        v.bifwait_op     := RRES.bifwait_op;
        v.itrappend      := RRES.itrappend;
        v.itraplost      := RRES.itraplost;
        v.wtrappend      := RRES.wtrappend;
        v.wtraplost      := RRES.wtraplost;
        v.ahbwtrapmode   := RRES.ahbwtrapmode;
        v.mmuwtrapmode   := RRES.mmuwtrapmode;
        v.ctrappend      := RRES.ctrappend;
        if dtagconf=0 then
          vs.validarr    := RSRES.validarr;
        end if;
        v.amo            := RRES.amo;
        v.cbo            := RRES.cbo;
        -- RISC-V does not use a default TLB, so must invalidate.
        if arch = RISCV then
          for x in v.itlb'range loop
            v.itlb(x).valid := '0';  -- RRES.itlb(0).valid;
          end loop;
          for x in v.dtlb'range loop
            v.dtlb(x).valid := '0';  -- RRES.dtlb(0).valid;
          end loop;
          for x in v.htlb'range loop
            v.htlb(x).valid := '0';  -- RRES.htlb(0).valid;
          end loop;
        end if;
        v.dbg := RRES.dbg;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Replication
    ---------------------------------------------------------------------------
    for x in 0 to tlbrepl-1 loop
      v.i1pc_repl(x*vaddrbits+vaddrbits-1 downto x*vaddrbits) := v.i1pc;
      v.i1ctx_repl(x*ctxbits+ctxbits-1 downto x*ctxbits) := v.i1ctx;
    end loop;
    for x in 0 to tlbrepl-1 loop
      v.d1vaddr_repl(x*vaddrbits+vaddrbits-1 downto x*vaddrbits) := v.d1vaddr;
      v.d1ctx_repl(x*ctxbits+ctxbits-1 downto x*ctxbits) := v.d1ctx;
    end loop;
   if ext_h = 1 then
    for x in 0 to tlbrepl-1 loop
      v.h_addr_repl(x*vaddrbits+vaddrbits-1 downto x*vaddrbits) := (others => '0');
      v.h_addr_repl(x*vaddrbits+ga_msb downto x*vaddrbits) := v.h_addr;
      v.h_ctx_repl(x*ctxbits+ctxbits-1 downto x*ctxbits) := mmu_ctx(csro);
    end loop;
   end if;

    ---------------------------------------------------------------------------
    -- Constant registers
    ---------------------------------------------------------------------------
    case dways is
      when 1 =>
        for w in r.dlru'range loop v.dlru(w) := (others => '0'); end loop;
      when 2 =>
        for w in r.dlru'range loop
          v.dlru(w)(4) := '0';
          v.dlru(w)(2 downto 0) := "000";
        end loop;
      when 3 =>
        for w in r.dlru'range loop
          v.dlru(w)(1 downto 0) := "00";
        end loop;
      when 4 => null;
    end case;
    case iways is
      when 1 =>
        for w in r.ilru'range loop v.ilru(w) := (others => '0'); end loop;
      when 2 =>
        for w in r.ilru'range loop
          v.ilru(w)(4) := '0';
          v.ilru(w)(2 downto 0) := "000";
        end loop;
      when 3 =>
        for w in r.ilru'range loop
          v.ilru(w)(1 downto 0) := "00";
        end loop;
      when 4 => null;
    end case;
    for x in 31 downto 16 loop
      if (x <= 2+itcmabits) or itcmen=0 then
        v.itcmaddr(x) := '0';
      end if;
      if (x <= 2+dtcmabits) or dtcmen=0 then
        v.dtcmaddr(x) := '0';
      end if;
    end loop;

    -- If wbmask is zero we force all bus-width related registers to zero
    if xwbmask=0 then
      for x in 0 to itlbnum-1 loop
        v.itlb(x).busw := '0';
      end loop;
      for x in 0 to dtlbnum-1 loop
        v.dtlb(x).busw := '0';
      end loop;
      v.newent.busw := '0';
      v.i2busw := '0';
      v.d2busw := '0';
    end if;

    if itcmen = 0 then
      v.itcmwipe     := '0';
      v.itcmaddr     := (others => '0');
      v.itcmctx      := (others => '0');
      v.itcmperm     := (others => '0');
      v.i2tcmhit     := '0';
      v.itcmenp      := '0';
      v.itcmenva     := '0';
      v.itcmenvc     := '0';
    end if;
    if dtcmen = 0 then
      v.dtcmwipe     := '0';
      v.dtcmaddr     := (others => '0');
      v.dtcmctx      := (others => '0');
      v.dtcmperm     := (others => '0');
      v.d2tcmhit     := '0';
      v.dtcmenp      := '0';
      v.dtcmenva     := '0';
      v.dtcmenvc     := '0';
    end if;

    if ext_h = 0 or mmuen = 0 then
      for n in v.htlb'range loop
        v.htlb(n)          := tlbent_empty;
      end loop;
      for n in v.itlb'range loop
        v.itlb(n).h_r      := '0';
      end loop;
      for n in v.dtlb'range loop
        v.dtlb(n).h_r      := '0';
      end loop;
    end if;

    if ext_h = 0 or mmuen = 0 or not actual_tlb_pmp then
      for n in v.htlb'range loop
        v.htlb(n).pmp_r    := '1';
        v.htlb(n).pmp_no_w := '0';
        v.htlb(n).pmp_no_x := '0';
      end loop;
      for n in v.itlb'range loop
        v.itlb(n).pmp_r    := '1';
        v.itlb(n).pmp_no_w := '0';
        v.itlb(n).pmp_no_x := '0';
      end loop;
      for n in v.dtlb'range loop
        v.dtlb(n).pmp_r    := '1';
        v.dtlb(n).pmp_no_w := '0';
        v.dtlb(n).pmp_no_x := '0';
      end loop;
    end if;

    if not walk_pmp then
      for n in v.htlb'range loop
        v.htlb(n).pmp_none := '0';
        v.htlb(n).pmp_lock := '0';
        v.htlb(n).pmp_rwx  := "000";
      end loop;
      for n in v.itlb'range loop
        v.itlb(n).pmp_none := '0';
        v.itlb(n).pmp_lock := '0';
        v.itlb(n).pmp_rwx  := "000";
      end loop;
      for n in v.dtlb'range loop
        v.dtlb(n).pmp_none := '0';
        v.dtlb(n).pmp_lock := '0';
        v.dtlb(n).pmp_rwx  := "000";
      end loop;
    end if;

    if ext_svpbmt = 0 or mmuen = 0 then
      for n in v.htlb'range loop
        v.htlb(n).pbmt := "00";
      end loop;
      for n in v.itlb'range loop
        v.itlb(n).pbmt := "00";
      end loop;
      for n in v.dtlb'range loop
        v.dtlb(n).pbmt := "00";
      end loop;
    end if;

    if not pmaen then
      for n in v.htlb'range loop
        v.htlb(n).pma      := pma_unused;
      end loop;
      for n in v.itlb'range loop
        v.itlb(n).pma      := pma_unused;
      end loop;
      for n in v.dtlb'range loop
        v.dtlb(n).pma      := pma_unused;
      end loop;
    end if;

    if mmuen = 0 then
      v.htlb   := tlb_def(v.htlb'range);
      if not walk_pmp then
        v.itlb := tlb_def(v.itlb'range);
        v.dtlb := tlb_def(v.dtlb'range);
      else
        for n in v.itlb'range loop
          v.itlb(n).ctx      := (others => '0');
          v.itlb(n).perm     := (others => '0');
          v.itlb(n).modified := '0';
        end loop;
        for n in v.dtlb'range loop
          v.dtlb(n).ctx      := (others => '0');
          v.dtlb(n).perm     := (others => '0');
          v.dtlb(n).modified := '0';
        end loop;
      end if;
    end if;

    if is_riscv then
      for n in v.htlb'range loop
        v.htlb(n).acc := (others => '0');
      end loop;
      for n in v.itlb'range loop
        v.itlb(n).acc := (others => '0');
      end loop;
      for n in v.dtlb'range loop
        v.dtlb(n).acc := (others => '0');
      end loop;
    end if;
    --------------------------------------------------------------------------
    -- Assign signals
    --------------------------------------------------------------------------

    -- Address that may have caused fault due to L2 PT.
    -- L1 PT faults are handled by a complete new page walk, so they
    -- will mark faults in the same way as when an L2 PT walk is being done!
    if ext_h = 1 and r.h_do = '1' then
      v.addrhyper := uext(r.h_addr(r.h_addr'high downto 2), v.addrhyper);
    end if;


    oico.typehyper := r.itypehyper;
    oico.addrhyper := uext(r.addrhyper, oico.addrhyper);
    odco.typehyper := r.dtypehyper;
    odco.addrhyper := uext(r.addrhyper, odco.addrhyper);


    c <= v;
    cs <= vs;
    ico <= oico;
    dco <= odco;
    crami <= ocrami;
    for i in ocrami.dtagcuen'range loop
      if ocrami.dtagcuwrite = '0' or ocrami.dtagcuen(i) = '0' then
        crami.dtagudin(i) <= (others => '0');
      end if;
    end loop;
    bifi <= obifi;
    fpc_mosi <= r.fpc_mosi;
    c2c_mosi <= r.c2c_mosi;
    perf <= r.perf;

    csri.cctrl   <= csr_in_cctrl_type'(
      iflushpend => r.iflushpend,
      dflushpend => r.dflushpend,
      itcmwipe   => r.itcmwipe,
      dtcmwipe   => r.dtcmwipe
    );
    csri.cconfig <= cache_config;
    --
  end process;

  srstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 generate
    regs: process(clk)
    begin
      if rising_edge(clk) then
        r <= c;
        if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rst='0' then
          r <= RRES;
        end if;

      end if;

    end process;

    sregs: process(sclk)
    begin
      if rising_edge(sclk) then
        rs <= cs;
        if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rst='0' then
          rs <= RSRES;
        end if;
      end if;
    end process;
  end generate srstregs;

  arstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)/=0 generate
    regs: process(clk,rst)
    begin
      if rst='0' then
        r <= RRES;
      elsif rising_edge(clk) then
        r <= c;
      end if;
    end process;

    sregs: process(sclk,rst)
    begin
      if rst='0' then
        rs <= RSRES;
      elsif rising_edge(sclk) then
        rs <= cs;
      end if;
    end process;
  end generate arstregs;

--pragma translate_off
-- TODO
--  ahbxchk: process(clk)
--  begin
--    if rising_edge(clk) then
--      if r.ahb2_inacc='1' and r.ahb2_hwrite='0' and ahbi.hready='1' and ahbi.hresp="00" then
--        for x in LINESZMAX-1 downto 0 loop
--          assert
--            not (r.ahb2_addrmask(x)='1' and is_x(ahbi.hrdata((((x+1)*32-1) mod xbusw) downto ((x*32) mod xbusw))))
--            report "Reading in X over AHB bus into CPU"
--            severity warning;
--        end loop;
--      end if;
--    end if;
--  end process;
--pragma translate_on

end;
