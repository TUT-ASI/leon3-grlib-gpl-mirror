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
-- Entity:      cctrlnv
-- File:        cctrlnv.vhd
-- Author:      Magnus Hjorth and Johan Klockars, Cobham Gaisler
-- Based on:    LEON3/LEON4 cache and MMU by Jiri Gaisler, Edvin Catovic
--              and Konrad Eisele
-- Description: Complete cache controller with MMU for LEON5 and NOEL-V.
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.config.all;
use grlib.config_types.all;
use grlib.devices.VENDOR_GAISLER;
use grlib.devices.GAISLER_RV64GC;
use grlib.sparc.ASI_UDATA;
use grlib.sparc.ASI_SDATA;
use grlib.stdlib.log2;
use grlib.stdlib.log2x;
use grlib.stdlib.orv;
use grlib.stdlib.notx;
use grlib.stdlib.setx;
library gaisler;
use gaisler.noelvtypes.all;
use gaisler.noelvint.nv_cram_in_type;
use gaisler.noelvint.nv_cram_in_none;
use gaisler.noelvint.nv_cram_out_type;
use gaisler.noelvint.cram_tags;
use gaisler.noelvint.csr_in_cctrl_type;
use gaisler.noelvint.nv_csr_in_type;
use gaisler.noelvint.nv_csr_in_type_none;
use gaisler.noelvint.nv_csr_out_type;
use gaisler.noelvint.nv_csr_out_type;
use gaisler.noelvint.nv_csr_out_type_none;
use gaisler.noelvint.nv_intreg_miso_type;
use gaisler.noelvint.nv_intreg_mosi_type;
use gaisler.noelvint.nv_intreg_miso_none;
use gaisler.noelvint.nv_intreg_mosi_none;
use gaisler.noelvint.nv_icache_in_type;
use gaisler.noelvint.nv_icache_out_type;
use gaisler.noelvint.nv_dcache_in_type;
use gaisler.noelvint.nv_dcache_out_type;
use gaisler.noelvint.nv_dcache_out_none;
use gaisler.noelvint.nv_cdatatype;
use gaisler.mmucacheconfig.rv_pte_pbmt;
use gaisler.mmucacheconfig.rv_pte_resv;
use gaisler.mmucacheconfig.rv_ppn;
use gaisler.mmucacheconfig.rv_pte_rsw;
use gaisler.mmucacheconfig.rv_pte_v;
use gaisler.mmucacheconfig.rv_pte_r;
use gaisler.mmucacheconfig.rv_pte_w;
use gaisler.mmucacheconfig.rv_pte_x;
use gaisler.mmucacheconfig.rv_pte_u;
use gaisler.mmucacheconfig.rv_pte_g;
use gaisler.mmucacheconfig.rv_pte_a;
use gaisler.mmucacheconfig.rv_pte_d;
use grlib.riscv.priv_lvl_type;
use grlib.riscv.PRIV_LVL_M;
use grlib.riscv.PRIV_LVL_S;
use grlib.riscv.PRIV_LVL_U;
use grlib.riscv.R_LR;
use grlib.riscv.R_SC;
use gaisler.nvsupport.pmpcfg_access_type;
use gaisler.nvsupport.PMP_ACCESS_R;
use gaisler.nvsupport.PMP_ACCESS_W;
use gaisler.nvsupport.PMP_ACCESS_X;
use gaisler.nvsupport.pmp_unit;
use gaisler.nvsupport.pmp_mmuu;
use gaisler.nvsupport.pma_t;
use gaisler.nvsupport.pma_unused;
use gaisler.nvsupport.pma_all;
use gaisler.nvsupport.to_pma;
use gaisler.nvsupport.from_pma;
use gaisler.nvsupport.pma_valid;
use gaisler.nvsupport.pma_r;
use gaisler.nvsupport.pma_w;
use gaisler.nvsupport.pma_x;
use gaisler.nvsupport.pma_pt_r;
use gaisler.nvsupport.pma_pt_w;
use gaisler.nvsupport.pma_cache;
use gaisler.nvsupport.pma_burst;
use gaisler.nvsupport.pma_idem;
use gaisler.nvsupport.pma_amo;
use gaisler.nvsupport.pma_lrsc;
use gaisler.nvsupport.pma_busw;
use gaisler.nvsupport.pma_rwx;
use gaisler.nvsupport.tost_pma_vrwx;
use gaisler.nvsupport.pma_pbmt_nc;
use gaisler.nvsupport.pma_pbmt_io;
use gaisler.nvsupport.PMA_SIZE;
use gaisler.nvsupport.pma_masks;
use gaisler.nvsupport.pma_unit;
use gaisler.nvsupport.pma_mmuu;
use gaisler.nvsupport.smepmp_ok_r;
use gaisler.nvsupport.smepmp_ok_w;
use gaisler.nvsupport.smepmp_ok_x;
use gaisler.nvsupport.limit_mask;
use gaisler.nvsupport.lru_3way_table;
use gaisler.nvsupport.lru_4way_table;
use gaisler.nvsupport.amo_math_op;
use gaisler.utilnv.cond;
use gaisler.utilnv.minimum;
use gaisler.utilnv.maximum;
use gaisler.utilnv.to_bit;
use gaisler.utilnv.u2i;
use gaisler.utilnv.u2vec;
use gaisler.utilnv.get_zeros;
use gaisler.utilnv.get_ones;
use gaisler.utilnv.get;
use gaisler.utilnv.get_hi;
use gaisler.utilnv.get_lo;
use gaisler.utilnv.get_right;
use gaisler.utilnv.get_left;
use gaisler.utilnv.set;
use gaisler.utilnv.set_hi;
use gaisler.utilnv.all_1;
use gaisler.utilnv.all_0;
use gaisler.utilnv.uadd;
use gaisler.utilnv.uadd_range;
use gaisler.utilnv.lo_h;
use gaisler.utilnv.hi_h;
use gaisler.utilnv.log;
use gaisler.utilnv.uext;
use gaisler.utilnv.no_x;
use gaisler.utilnv.make_same;
use gaisler.utilnv.make_downto0;
use gaisler.utilnv.fit0ext;
use gaisler.alunv.clz;
use gaisler.alunv.reverse;

entity cctrlnv is
  generic (
    hindex     : integer;                  -- Hart index
    -- Core
    physaddr   : integer range 32 to 56;   -- Physical Addressing
    -- Caches
    iways      : integer range 1 to   8;   -- I$ ways
    ilinesize  : integer range 4 to   8;   --    cache line size (32 bit words)
    iwaysize   : integer range 1 to 256;   --    way size (KiB)
    dways      : integer range 1 to   8;   -- D$ ways
    dlinesize  : integer range 4 to   8;   --    cache line size (32 bit words)
    dwaysize   : integer range 1 to 256;   --    way size (KiB)
    dtagconf   : integer range 0 to   2;
    dusebw     : integer range 0 to   1;
    itcmen     : integer range 0 to   1;
    itcmabits  : integer range 1 to  20;
    dtcmen     : integer range 0 to   1;
    dtcmabits  : integer range 1 to  20;
    -- MMU
    itlbnum    : integer range 2 to  64;   -- # instruction TLB entries
    dtlbnum    : integer range 2 to  64;   -- # data TLB entries
    htlbnum    : integer range 1 to  64;   -- # hypervisor TLB entries
    riscv_mmu  : integer range 0 to   3;
    pmp_no_tor : integer range 0 to   1;   -- Disable PMP TOR (not with TLB PMP)
    pmp_entries: integer range 0 to  16;   -- Implemented PMP registers
    pmp_g      : integer range 0 to  10;   -- PMP grain is 2^(pmp_g + 2) bytes
--    pma_no_tor : integer range 0 to   1 := 1;   -- Disable PMA TOR
    pma_entries: integer range 0 to  16;   -- Implemented PMA entries
    pma_masked : integer range 0 to   1;   -- PMA done using masks
    asidlen    : integer range 0 to  16;   -- Max 9 for Sv32
    vmidlen    : integer range 0 to  14;   -- Max 7 for Sv32
    ext_noelv  : integer range 0 to   1;   -- NOEL-V Extensions
    ext_a      : integer range 0 to   1;   -- Support for Atomic operations
    ext_h      : integer range 0 to   1;   -- Support for Hypervisor, needs tlb_pmp if any PMP.
    ext_smepmp : integer range 0 to   1;   -- Support for Smepmp extension
    ext_zicbom : integer range 0 to   1;   -- Support for Zicbom extension
    ext_svpbmt : integer range 0 to   1;   -- Support for Svpbmt Extension
    ext_zicfiss: integer range 0 to   1;   -- Support for Zicfiss Extension
    tlb_pmp    : integer range 0 to   1;   -- Do PMP via TLB
    -- Misc
    cached     : integer;                  -- Mask indexed by 4 MSB of address regarding cacheability when no TLB used
    wbmask     : integer;                  -- Wide bus mask
    busw       : integer;                  -- AHB bus width in bits
--jk    dataw      : integer;                  -- Maximum load/store data width in bits
    cdataw     : integer;                  -- Cache memory width in bits
    icrepl     : integer;                  -- Address replication for TLB lookup
    dcrepl     : integer;
    hrepl      : integer;
    addr_check : integer range 0 to 255 := 255; -- Instruction PMP (7 TLB, 6 acc), high bits (5 physical, 4 virtual)
    mmu_debug  : boolean := false;              --   Data      PMP (3 TLB, 2 acc), high bits (1 physical, 0 virtual)
    walk_state : boolean := true;               -- Decouple page walk start using a separate state.
    walk_mark  : boolean := true;               -- Mark PT walk start.
    walk_fault : boolean := false;              -- Fault on PT walk start.
    walk_pmp   : boolean := false;               -- Do "page walk" and use TLBs for pure PMP/PMA
    pmp_mmuu_test : integer range 0 to 1 := 1;  -- Enable PMP test via diagnostics
    pma_mmuu_test : integer range 0 to 1 := 1;  -- Enable PMA test via diagnostics
    tlb_valid_r   : integer range 0 to 1 := 1;  -- Enable TLB valid setting via diagnostics
    mmuen      : integer range 0 to 1;
    endian     : integer range 0 to 1      -- LEON5 is big endian, NOEL-V little endian
    );
  port (
    rst        : in  std_ulogic;
    clk        : in  std_ulogic;
    ici        : in  nv_icache_in_type;             -- I$ requests from iunv
    ico        : out nv_icache_out_type;            --    replies
    dci        : in  nv_dcache_in_type;             -- D$ requests from iunv
    dco        : out nv_dcache_out_type;            --    replies
    ahbi       : in  ahb_mst_in_type;               -- AHB replies
    ahbo       : out ahb_mst_out_type;              --     requests
    ahbsi      : in  ahb_slv_in_type;               -- AHB snoop address
    ahbso      : in  ahb_slv_out_vector;            -- Some AHB config data used to check for cacheability when no TLB
    crami      : out nv_cram_in_type;
    cramo      : in  nv_cram_out_type;
    sclk       : in  std_ulogic;                    -- sclk for snoop (not gated)
    csro       : in  nv_csr_out_type := nv_csr_out_type_none;
    csri       : out nv_csr_in_type  := nv_csr_in_type_none;
    fpc_mosi   : out nv_intreg_mosi_type;
    fpc_miso   : in  nv_intreg_miso_type;
    c2c_mosi   : out nv_intreg_mosi_type;
    c2c_miso   : in  nv_intreg_miso_type;
    freeze     : in std_ulogic;
    bootword   : in std_logic_vector(31 downto 0);
    smpflush   : in std_logic_vector( 1 downto 0);
    -- Temp perf counter
    perf       : out std_logic_vector(31 downto 0)
    );


end;

architecture rtl of cctrlnv is


  constant dataw : integer := 64;

  constant zerov : word64 := (others => '0');
  constant onev  : word64 := (others => '1');



  function get64(data : std_logic_vector; start : integer) return std_logic_vector is
  begin
    return get(data, start, 64);
  end;

  -- Wrapper functions for mmucacheconfig.

  function is_riscv return boolean is
  begin
    return gaisler.mmucacheconfig.is_riscv(riscv_mmu);
  end;

  -- Actual physical address MSB.
  function pa_msb return integer is
  begin
    return minimum(physaddr - 1, gaisler.mmucacheconfig.pa_msb(riscv_mmu));
  end;

  -- Guest physical address MSB.
  function ga_msb return integer is
  begin
    return gaisler.mmucacheconfig.ga_msb(riscv_mmu);
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

  -- Virtual address MSB.
  function va_msb return integer is
  begin
    return gaisler.mmucacheconfig.va_msb(riscv_mmu);
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

  -- Incoming addresses have, at maximum, this many useful bits.
  function addr_bits return integer is
  begin
    return maximum(gva_msb + 1, pa_msb + 1);
  end;

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

  -- The maximum bits that are required to hold an address (physical or virtual).
  -- Two bits longer than the actual address, since we need to keep track of
  -- whether higher bits are the same or not (not same - bad address).
  -- These are what is really passed from iunv!
  subtype addr_type      is std_logic_vector(addr_bits + 1 downto 0);


  function pte_hsize return std_logic_vector is
  begin
    return gaisler.mmucacheconfig.pte_hsize(riscv_mmu);
  end;

  function va_size(index : integer) return integer is
  begin
    return gaisler.mmucacheconfig.va_size(riscv_mmu, index);
  end;

  function va_size return integer is
  begin
    return gaisler.mmucacheconfig.va_size(riscv_mmu);
  end;

  constant va_size_a : gaisler.mmucacheconfig.va_bits(1 to va_size) := (others => 0);

  function is_pt_invalid(data : std_logic_vector) return boolean is
  begin
    return gaisler.mmucacheconfig.is_pt_invalid(riscv_mmu, data);
  end;

  function is_valid_pte(data : std_logic_vector; mask : std_logic_vector
                       ) return boolean is
  begin
    if is_riscv then
      return gaisler.mmucacheconfig.is_valid_pte(riscv_mmu, data, mask, ext_svpbmt = 1);
    else
      return gaisler.mmucacheconfig.is_valid_pte(riscv_mmu, data, mask);
    end if;
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

  subtype va_type is integer range 0 to 3;
  constant sparc : integer := 0;
  constant sv32  : integer := 1;
  constant sv39  : integer := 2;
  constant sv48  : integer := 3;

  type va_bits is array (integer range <>) of integer;

  -- Returns address of page table entry.
  -- Returned address is 64 bit long and must be cut down to size by caller.
  function pt_addr(data  : std_logic_vector; mask : std_logic_vector;
                   vaddr : std_logic_vector; code : std_logic_vector) return word64 is
    -- Non-constant
    -- Using hypervisor guest address size here.
    variable addr   : word64 := (others => '0');
    variable pos    : integer;
  begin
    if not is_riscv then
      -- Since physical address is only 32 bit, do not use the top 4 bits of PTP.
      addr(31 downto 8) := data(27 downto 4);
      -- Index into table, depending on current level.
      if mask(1) = '0' then
        addr(9 downto 2) := addr(9 downto 2) or vaddr(31 downto 24);
      end if;
      if mask(1 to 2) = "10" then
        addr(7 downto 2) := addr(7 downto 2) or vaddr(23 downto 18);
      end if;
      if mask(1 to 2) = "11" then
        addr(7 downto 2) := addr(7 downto 2) or vaddr(17 downto 12);
      end if;
    else
      -- Every page table is the size of one page (thus downto 12).
      -- 12 due to smallest page size, 10 are the information bits.
      if addr'length >= data'length + (12 - 10) then
        addr(data'high + (12 - 10) downto 12) := data(data'high downto 10);
      else
        addr(addr'high downto 12) := data(addr'high - (12 - 10) downto 10);
      end if;
      pos := 12;
      for i in mask'length downto 1 loop
        if i > u2i(code) then
          pos := pos + va_size(i);
        end if;
      end loop;


      -- DesignCompiler cannot count by itself...
      if riscv_mmu = sv32 then
        -- We know that on RISC-V32 (Sv32), va_size(what)(index) is always 10.
        -- This means pos must be 12 + 10n (n in [0,2]).
        addr(11 downto 11 - 10 + 1) := vaddr(pos - 1 downto pos - 10);
      else
        -- We know that on RISC-V64 (Sv39/48), va_size(what)(index) is always 9.
        -- This means pos must be 12 + 9n (n in [0,3], the latter only for Sv48).
        addr(11 downto 11 - 9 + 1) := vaddr(pos - 1 downto pos - 9);
      end if;
    end if;

    return addr;
  end;

  function pt_code(mask_in : std_logic_vector) return std_logic_vector is
    -- Ensure we have the expected bit range.
    variable mask : std_logic_vector(1 to mask_in'length) := mask_in;
  begin
    if    mask(1) = '0' then
      return "00";
    elsif mask(2) = '0' then
      return "01";
    elsif mask'length > 2 and mask(3) = '0' then
      return "10";
    else
      return "11";
    end if;
  end;

  -- Create a mask for bits to keep from a PT address,
  -- depending on the mask/code (see above).
  -- 0 - all mappable address bits
  -- 1 - no mask for lowest group of mappable address bits
  -- 2 - no mask for two lowest groups of mappable address bits
  -- 3 - no mask for three lowest groups of mappable address bits
  function pt_mask(mask : std_logic_vector(va_size_a'range)) return std_logic_vector is
    -- Non-constant
--    variable addr     : gpaddr_type := (others => '1');
    variable addr     : addr_type := (others => '1');
    variable pos      : integer range 0 to gaisler.mmucacheconfig.pa_msb(riscv_mmu);
  begin
    if not is_riscv then
      -- Function is only used for RISC-V!
    else
      pos := 12;
      -- Add up page mask sizes from bottom.
      -- Any 0:s will be in a row from high indices.
      for i in mask'length downto 1 loop
        if mask(i) = '0' then
          -- This will not sum to above gaisler.mmucacheconfig.pa_msb.
          pos := pos + va_size(i);
        end if;
      end loop;

      addr(11 downto 0) := (others => '0');
      for i in 12 to addr'high loop
        if i < pos then
          addr(i) := '0';
        end if;
      end loop;

    end if;

    return addr;
  end;


  function pte_paddr(data : std_logic_vector) return std_logic_vector is
  begin
    return gaisler.mmucacheconfig.pte_paddr(riscv_mmu, data);
  end;

  -- For RISC-V, this will simply return the PnP cachability information
  -- from PnP for the base address of the given PTE entry.
  function pte_cached(ahbso : ahb_slv_out_vector; data : std_logic_vector) return std_logic is
    -- Non-constant
    variable paddr     : paddr_type := (others => '0');
    variable ahbo_t    : ahb_mst_out_type;
    variable tmp_paddr : word64;
  begin
    if is_riscv then
      tmp_paddr        := uext(pte_paddr(data), 64);
      paddr(ppn'range) := tmp_paddr(ppn'length - 1 downto 0);
      return ahb_slv_dec_cache(paddr(ahbo_t.haddr'range), ahbso, cached);
    else
      return gaisler.mmucacheconfig.pte_cached(riscv_mmu, data);
    end if;
  end;

  procedure pte_mark_modacc(data   : inout std_logic_vector; modified : std_logic;
                            needwb : out std_logic; needwblock : out std_logic) is
  begin
    gaisler.mmucacheconfig.pte_mark_modacc(riscv_mmu, data, modified, needwb, needwblock);
  end;

  -- Update existing PMA information according to PBMT
  -- Note that if the system normally separates memory ordering between
  -- main memory abd I/O, changing the type via PBMT actually means that
  -- _both_ orderings must be observed for FENCE, .aq and .rl.
  function pbmt_pma_update(pbmt : word2; pma : pma_t) return pma_t is
  begin
    if ext_svpbmt = 0 then
      return pma;
    end if;

    case pbmt is
    when "00"   =>          -- PMA - no change
      return pma;
    when "01"   =>          -- NC  - Non-cachable, idempotent, weakly-ordered, main memory
      return pma_pbmt_nc(pma);
    when others =>          -- IO  - Non-cachable, non-idempotent, strongly-ordered, I/O
      return pma_pbmt_io(pma);
    end case;
  end;

  -- Convert virtual vaddr to physical paddr, using vmask to OR correct levels.
  procedure virtual2physical(vaddr : std_logic_vector; mask : std_logic_vector;
                             paddr : inout std_logic_vector) is
  begin
    gaisler.mmucacheconfig.virtual2physical(riscv_mmu, vaddr, mask, paddr);
  end;

  function ft_acc_resolve(at : word3; data : std_logic_vector)
    return std_logic_vector is
  begin
    return gaisler.mmucacheconfig.ft_acc_resolve(riscv_mmu, at, data);
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


  constant pmpen   : boolean := pmp_entries /= 0;
  constant pmp_msb : integer := physaddr - 1;    -- High bit for PMP checks

  constant pmaen   : boolean := pma_entries /= 0;


  -- TLB PMP is required for ext_h,
  -- if there actually are any PMP entries.
  constant actual_tlb_pmp : boolean := (tlb_pmp = 1 or ext_h = 1) and (mmuen = 1 or walk_pmp) and (pmpen or pmaen);

  constant LINESZMAX    : integer := maximum(dlinesize, ilinesize);   -- Longest $ line in 32 bit words
  constant TLBNUMMAX    : integer := maximum(htlbnum, maximum(dtlbnum, itlbnum));
  constant BUF_HIGH     : integer := log2(LINESZMAX * 4) - 1;         -- MSB of byte addressing in $ line.

  -- Nomenclature here is non-standard. Some explanations:
  --
  -- Way size (here called waysize) in kbyte, and number of ways (here called ways)
  -- are specified rather than total cache size. Cache line size (linesize) in 32 bit words.
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

  -- Tags use physical addresses.
  constant TAG_HIGH     : integer := physaddr - 1;

  constant DLINE_BITS   : integer := log2(dlinesize);                 -- Offset - 2 above (32 bit).
  constant DOFFSET_BITS : integer := 8 + log2(dwaysize) - DLINE_BITS; -- Index above.
  constant DTAG_LOW     : integer := DOFFSET_BITS + DLINE_BITS + 2;   -- Total set addressing above.
  constant DOFFSET_HIGH : integer := DTAG_LOW - 1;
  constant DOFFSET_LOW  : integer := DLINE_BITS + 2;                  -- Offset above.

  constant ILINE_BITS   : integer := log2(ilinesize);                 -- See above.
  constant IOFFSET_BITS : integer := 8 + log2(iwaysize) - ILINE_BITS;
  constant ITAG_LOW     : integer := IOFFSET_BITS + ILINE_BITS + 2;
  constant IOFFSET_HIGH : integer := ITAG_LOW - 1;
  constant IOFFSET_LOW  : integer := ILINE_BITS + 2;

  -- Max bits needed to represent an I/D cache set.
  constant MAX_SET_BITS : integer := maximum(DOFFSET_BITS, IOFFSET_BITS);

  constant ILINE_HIGH   : integer := IOFFSET_LOW - 1;
  constant ILINE_LOW    : integer := 3;
  constant DLINE_HIGH   : integer := DOFFSET_LOW - 1;
  constant DLINE_LOW    : integer := 2;  -- for legacy reasons
  -- Bits for byte addressing in D$ access part.
  constant DLINE_LOW_REAL : integer := log2(cdataw / 8);
   -- Bits for part addressing of cache access width in a cacheline.
  constant DLINE_P_BITS : integer := DLINE_HIGH - DLINE_LOW_REAL + 1;
  constant ILINE_P_BITS : integer := ILINE_HIGH - ILINE_LOW + 1;

  -- The caches have a limited range of addressing.
  constant DCACHE_HIGH  : integer := DOFFSET_HIGH - DLINE_LOW;        -- D$ addressed in 32 bit words.
  constant ICACHE_HIGH  : integer := IOFFSET_HIGH - ILINE_LOW;        -- I$ addressed in 64 bit words.
  constant d_cache      : std_logic_vector(DCACHE_HIGH downto 0)       := (others => '0');
  constant i_cache      : std_logic_vector(ICACHE_HIGH downto 0)       := (others => '0');

  constant d_addr   : std_logic_vector(DOFFSET_HIGH downto DLINE_LOW)   := (others => '0');
  constant i_addr   : std_logic_vector(IOFFSET_HIGH downto ILINE_LOW)   := (others => '0');
  constant d_tag    : std_logic_vector(TAG_HIGH downto DTAG_LOW)        := (others => '0');
  constant i_tag    : std_logic_vector(TAG_HIGH downto ITAG_LOW)        := (others => '0');
  constant d_index  : std_logic_vector(DOFFSET_HIGH downto DOFFSET_LOW) := (others => '0');
  constant i_index  : std_logic_vector(IOFFSET_HIGH downto IOFFSET_LOW) := (others => '0');
  constant d_ways   : std_logic_vector(0 to DWAYS - 1)                  := (others => '0');
  constant i_ways   : std_logic_vector(0 to IWAYS - 1)                  := (others => '0');
  constant d_line   : std_logic_vector(DLINE_HIGH downto 0)             := (others => '0');
  constant i_line   : std_logic_vector(ILINE_HIGH downto 0)             := (others => '0');
  constant i_linew  : std_logic_vector(ILINE_HIGH downto 2)             := (others => '0');
  constant d_sets   : std_logic_vector(DOFFSET_BITS - 1 downto 0)       := (others => '0');
  constant i_sets   : std_logic_vector(IOFFSET_BITS - 1 downto 0)       := (others => '0');
  constant max_sets : std_logic_vector(MAX_SET_BITS - 1 downto 0)       := (others => '0');
  constant d_offset : std_logic_vector(DLINE_P_BITS - 1 downto 0)       := (others => '0');
  constant i_offset : std_logic_vector(ILINE_P_BITS - 1 downto 0)       := (others => '0');

  subtype  dways_t     is std_logic_vector(d_ways'range);
  subtype  iways_t     is std_logic_vector(i_ways'range);

  constant IMUXDATA     : boolean := false;

  constant IMISSPIPE     : boolean := false;
  constant DMISSPIPE     : boolean := false;

  constant ENDIAN_B      : boolean := (endian /= 0);

  constant AMO_P         : integer := 0
  ;

  function get_itags_default return cram_tags is
    variable r: cram_tags;
  begin
    r := (others => (others => '0'));
    for w in i_ways'range loop
      r(w)(TAG_HIGH - ITAG_LOW + 1 downto TAG_HIGH - ITAG_LOW - 6)  := x"FF";
      r(w)(TAG_HIGH - ITAG_LOW - 7 downto TAG_HIGH - ITAG_LOW - 8)  := u2vec(w, 2);
      r(w)(TAG_HIGH - ITAG_LOW - 9 downto TAG_HIGH - ITAG_LOW - 10) := u2vec(w, 2);
      r(w)(0) := '0';
    end loop;

    return r;
  end;
  constant itags_default: cram_tags := get_itags_default;

  function has_context return boolean is
  begin
    return asidlen + vmidlen > 0;
  end;

  -- Some tools _really_ don't like types with zero length!
  function context_length return integer is
  begin
    if has_context then
      return asidlen + vmidlen;
    else
      return 1;
    end if;
  end;
  subtype ctxword is std_logic_vector(context_length - 1 downto 0);

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

  type tlbent is record
    valid    : std_ulogic;
    ctx      : ctxword;
    mode     : mode_t;
    mask     : std_logic_vector(va_size_a'range);
    vaddr    : std_logic_vector(gvn'range);
    paddr    : std_logic_vector(gpn'range);
    perm     : word5;                         -- priv write/priv read/user write/user read OK
    busw     : std_ulogic;                    --   RISC-V SUXWR
    cached   : std_ulogic;
    modified : std_ulogic;
    acc      : std_logic_vector(4 downto 2);  -- For SPARC (delayed perm calculation)
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

  function create_tlbent(x : std_logic) return tlbent is
    -- Non-constant
    variable ent : tlbent;
  begin
    ent.valid      := x;
    ent.ctx        := (others => '0');
    ent.mode       := (others => '0');
    ent.mask     := (others => '0');
    ent.vaddr    := (others => '0');
    ent.paddr    := (others => '0');
    ent.perm     := (others => x);
    ent.busw     := '0';
    ent.cached   := '0';
    ent.modified := x;
    if not is_riscv then
      ent.acc    := "011";
    else
      ent.acc    := "000";
    end if;
    ent.h_r      := '0';
    ent.pmp_r    := '0';
    ent.pmp_no_w := '0';
    ent.pmp_no_x := '0';
    ent.pmp_none := '0';
    ent.pmp_lock := '0';
    ent.pmp_rwx  := "000";
    ent.pbmt     := "00";
    ent.pma      := pma_unused;

    return ent;
  end;

  constant tlbent_defmap : tlbent := create_tlbent('1');
  constant tlbent_empty  : tlbent := create_tlbent('0');

  function tlbent_mask(entry_in : tlbent) return tlbent is
    -- Non-constant
    variable mask  : gvaddr_type := (others => '1');
    variable entry : tlbent := entry_in;
  begin
--    mask(gpa'range) := pt_mask(entry.mask);
    mask(gpa'range) := get_right(pt_mask(entry.mask), gpa'length);
    entry.vaddr     := entry.vaddr and mask(entry.vaddr'range);
    entry.paddr     := entry.paddr and mask(entry.paddr'range);


    return entry;
  end;

  function create_tlb_def(size : integer) return tlbentarr is
    -- Non-constant
    variable tlb : tlbentarr(0 to size - 1) := (others => tlbent_empty);
  begin
    -- LEON5 apparently wants a TLB entry set by default.
    if not is_riscv then
      tlb(0) := tlbent_defmap;
    end if;

    return tlb;
  end;

  constant tlb_def : tlbentarr(0 to TLBNUMMAX - 1) := create_tlb_def(TLBNUMMAX);

--  subtype lruent is word5;
  subtype lruent is std_logic_vector(8 * 3 - 1 downto 0);  -- Only 4-0 needed without 8 ways
  type    lruarr is array(natural range <>) of lruent;

  type stbufent is record
    addr      : paddr_type;
    size      : word2;
    data      : word64;
    snoopmask : dways_t;
  end record;
  type stbufarr is array(natural range <>) of stbufent;


  function create_stbufent_zero return stbufent is
    -- Non-constant
    variable ent : stbufent;
  begin
    ent.addr      := (others => '0');
    ent.size      := (others => '0');
    ent.data      := (others => '0');
    ent.snoopmask := (others => '0');

    return ent;
  end;

  constant stbufent_zero: stbufent := create_stbufent_zero;

  type cctrlnv_state is (as_normal, as_flush, as_icfetch,
                        as_dcfetch, as_dcfetch2, as_dcsingle,
                        as_wptectag1, as_wptectag2, as_wptectag3,
                        as_store, as_slowwr, as_wrburst,
                        as_wrasi, as_wrasi2, as_wrasi3,
                        as_rdasi, as_rdasi2, as_rdasi3, as_rdcdiag, as_rdcdiag2,
                        as_check_busw,
                        as_getlock, as_parked, as_mmuprobe2, as_mmuprobe3, as_mmuflush2,
                        as_regflush,
                        as_ifailkind, as_dfailkind,
                        as_start_walk, as_start_pmp,
                        as_mmu_pt1addr_chk, as_mmuwalk, as_mmu_pte1_hchk, as_mmu_pte1_pmpchk,
                        as_mmuwalk_lock,    as_xmmuwalk_lock, as_xwpte,
                        as_mmuwalk_pterr,   as_mmuwalk_pmperr,
                        as_mmu_pt2addr_pmpchk, as_hmmuwalk, as_mmu_pte2_pmpchk,
                        as_hmmuwalk_lock,      as_hmmuwalk_done, as_hwpte,
                        as_hmmuwalk_pterr,     as_hmmuwalk_pmperr,
                        as_amo, as_cbo);

  type nv_cctrltype is record
    dfrz    : std_ulogic;                    -- dcache freeze enable
    ifrz    : std_ulogic;                    -- icache freeze enable
    dsnoop  : std_ulogic;                    -- data cache snooping
    dcs     : word2;                         -- dcache state
    ics     : word2;                         -- icache state
    ics_btb : word2;                         -- icache state output to btb
  end record;

  constant MMCTRL_CTXP_SZ : integer := 30;

  -- # mmu ctrl reg
  -- Unused for RISC-V (currently)
  type mmctrl_type1 is record
    e      : std_logic;                      -- enable
    nf     : std_logic;                      -- no fault
    pso    : std_logic;                      -- partial store order (unused)
    ctx    : ctxword;                        -- context nr
    ctxp   : std_logic_vector(MMCTRL_CTXP_SZ - 1 downto 0);  -- context table pointer (unused on RISC-V)
    tlbdis : std_logic;                      -- tlb disabled
    bar    : word2;                          -- preplace barrier
  end record;

  constant mmctrl_type1_none : mmctrl_type1 :=
    ('0', '0', '0', (others => '0'), (others => '0'), '0', (others => '0'));

  -- # fault status reg
  type mmctrl_fs_type is record
    ow    : std_logic;
    fav   : std_logic;
    ft    : word3;                          -- fault type
    at_ls : std_logic;                      -- access type, 0 / 1 - load / store
    at_id : std_logic;                      -- access type, 0 / 1 - dcache / icache
    at_su : std_logic;                      -- access type, 0 / 1 - su / user
    l     : word2;                          -- level
    ebe   : word8;
  end record;

  constant mmctrl_fs_zero : mmctrl_fs_type :=
    ('0', '0', "000", '0', '0', '0', "00", "00000000");

  -- CBO TYPE
  type cbo_type is record
    d1type    : word3;
    d2type    : word3;
    hold      : std_logic;
  end record;

  -- AMO TYPE
  type amo_type is record
    d1type    : std_logic_vector(5 downto 0);
    d2type    : std_logic_vector(5 downto 0);
    reserved  : std_logic;
    hold      : std_logic;
    addr      : std_logic_vector(ahbo.haddr'range);
    data      : word64;
    store     : std_logic_vector(5 downto 1);
    sc        : std_logic;
    s4hit     : dways_t;
    s4tag     : std_logic_vector(d_tag'range);
    s4offs    : std_logic_vector(d_sets'range);
  end record amo_type;

  type d12_type is record
    asi        : word8;
    su         : std_ulogic;
    m          : std_ulogic;
    sum        : std_ulogic;
    mxr        : std_ulogic;
    vmxr       : std_ulogic;
    mode       : mode_t;
    hx         : std_ulogic;
    ss         : std_ulogic;
  end record;

  constant d12_empty : d12_type := ((others => '0'), '1', '1', '0', '0', '0', (others => '0'), '0', '0');

  type i12_type is record
    pc         : addr_type;                       -- First from ici.rpc
    nostream   : std_ulogic;                      -- Force no stream buffer hit?
    su         : std_ulogic;                      -- Supervisor mode execution?
    m          : std_ulogic;                      -- Machine mode execution?
    ctx        : ctxword;
    mode       : mode_t;
  end record;

  constant i12_empty : i12_type := ((others => '0'), '0', '1', '1', (others => '0'), (others => '0'));

  type regfl_pipe_entry is record
    valid  : std_ulogic;
    addr   : std_logic_vector(d_sets'range);
  end record;
  constant regfl_pipe_entry_zero: regfl_pipe_entry := (
    valid => '0',
    addr  => (others => '0')
    );
  type regfl_pipe_array is array (0 to 2) of regfl_pipe_entry;


  type irep_type is record
    hitv    : iways_t;
    validv  : iways_t;
    way     : word2;
    data    : nv_cdatatype;
    tlbhit  : std_ulogic;
    tlbpaddr : paddr_type;
    tlbid   : std_logic_vector(log2x(itlbnum) - 1 downto 0);

  end record;

  type ahb_type is record
    hbusreq   : std_ulogic;
    hlock     : std_ulogic;
    htrans    : word2;
    haddr     : std_logic_vector(ahbo.haddr'range);
    hwrite    : std_ulogic;
    hsize     : word3;
    hburst    : word3;
    hprot     : word4;
    hwdata    : word64;
    snoopmask : dways_t;
  end record;

  type ahb2_type is record
    inacc    : std_ulogic;
    hwrite   : std_ulogic;
    addrmask : std_logic_vector(LINESZMAX - 1 downto 0);
    ifetch   : std_ulogic;
    dacc     : std_ulogic;
  end record;

  type ahb3_type is record
    inacc    : std_ulogic;
    rdbuf    : std_logic_vector(LINESZMAX * 32 - 1 downto 0);  -- Buffered data from RAM.
    error    : std_ulogic;
    rdbvalid : std_logic_vector(LINESZMAX - 1 downto 0);
    rdberr   : std_logic_vector(LINESZMAX - 1 downto 0);
  end record;

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

  function is_access_i(mmusel : mmusel_type) return boolean is
  begin
    return mmusel(0) = '0';
  end;

  function is_access_asi_walk(mmusel : mmusel_type) return boolean is
  begin
    return not is_riscv and mmusel(2) = '1';
  end;

  function is_access_w(mmusel : mmusel_type) return boolean is
  begin
    return mmusel(1) = '1';
  end;

  function is_access_r(mmusel : mmusel_type) return boolean is
  begin
    return mmusel(2 downto 0) = "001";
  end;

  function is_access_hpt(mmusel : mmusel_type) return boolean is
  begin
    return mmusel(3) = '1';
  end;

  type cctrlnv_regs is record
    -- Config registers
    cctrl         : nv_cctrltype;
    mmctrl1       : mmctrl_type1;          -- Unused for RISC-V (currently)
    mmfsr         : mmctrl_fs_type;        -- Unused for RISC-V
    mmfar         : std_logic_vector(31 downto 12);
    regflmask     : std_logic_vector(31 downto 4);
    regfladdr     : std_logic_vector(31 downto 4);
    iregflush     : std_ulogic;
    dregflush     : std_ulogic;
    icignerr      : std_ulogic;
    dcignerr      : std_ulogic;
    dcerrmask     : std_ulogic;
    dcerrmaskval  : std_ulogic;
    itcmenp       : std_ulogic;
    itcmenva      : std_ulogic;
    itcmenvc      : std_ulogic;
    itcmperm      : word2;
    itcmaddr      : std_logic_vector(31 downto 16);
    itcmctx       : ctxword;
    dtcmenp       : std_ulogic;
    dtcmenva      : std_ulogic;
    dtcmenvc      : std_ulogic;
    dtcmperm      : word4;
    dtcmaddr      : std_logic_vector(31 downto 16);
    dtcmctx       : ctxword;
    itcmwipe      : std_ulogic;
    dtcmwipe      : std_ulogic;
    -- FSM state
    s             : cctrlnv_state;
    -- Control flags
    imisspend     : std_ulogic;
    ifailkind     : word2;          -- Instruction fault not dependent on anything in TLB
    dmisspend     : std_ulogic;
    dfailkind     : word2;          -- Data fault not dependent on anything in TLB
    iflushpend    : std_ulogic;
    dflushpend    : std_ulogic;
    slowwrpend    : std_ulogic;     -- Write cannot be done via store buffer.
    syncbar       : std_ulogic;
    holdn         : std_ulogic;     -- 0 - inhibit progress due to handling slow operation.
    ramreload     : std_ulogic;
    stbuffull     : std_ulogic;     -- No more space in write buffer.
    flushwrd      : dways_t;
    flushwri      : iways_t;
    regflpipe     : regfl_pipe_array;
    regfldone     : std_ulogic;
    -- AHB output registers
    ahb           : ahb_type;
    -- AHB delayed registers
    ahb3          : ahb3_type;
    ahb2          : ahb2_type;
    -- AHB grant tracking
    granted       : std_ulogic;
    -- Write error
    werr          : std_ulogic;
    -- MMU TLBs
    itlb        : tlbentarr(0 to itlbnum - 1);
    dtlb        : tlbentarr(0 to dtlbnum - 1);
    htlb        : tlbentarr(0 to htlbnum - 1);
    tlbflush    : word2;                                -- 1 - sTLB, 2 - hTLB
    newent      : tlbent;
    hnewent     : tlbent;                               -- For hypervisor. Needed?
    mmuerr      : mmctrl_fs_type;
    hmmuerr     : mmctrl_fs_type;                       -- For hypervisor. Needed?
    curerrclass : word2;
    newerrclass : word2;
    itlbpmru    : std_logic_vector(0 to itlbnum - 1);   -- Vectors for TLB pseudo-MRU
    dtlbpmru    : std_logic_vector(0 to dtlbnum - 1);
    htlbpmru    : std_logic_vector(0 to htlbnum - 1);
    tlbupdate   : std_ulogic;
    -- Tag pipeline registers for special functions (region flush)
    itagpipe    : cram_tags;
    dtagpipe    : cram_tags;
    untagd      : std_logic_vector(2 * DWAYS - 1 downto 0);
    untagi      : std_logic_vector(2 * IWAYS - 1 downto 0);
    -- IĆache logic registers
    i2          : i12_type;
    i2paddr     : paddr_type;
    i2paddrv    : std_ulogic;                      -- TLB hit and permissions OK
    i2busw      : std_ulogic;                      -- Use wide bus
    i2paddrc    : std_ulogic;                      -- unused (marks whether cacheable)
    i2tlbhit    : std_ulogic;                      -- TLB entry touched
    i2tlbclr    : std_ulogic;                      -- Invalidate TLB entry due to permission failure
    i2tlbid     : std_logic_vector(log2x(itlbnum) - 1 downto 0);
    i2bufmatch  : std_ulogic;
    i2hitv      : iways_t;
    i2validv    : iways_t;
    i2tcmhit    : std_ulogic;
    i1ten       : std_ulogic;                      -- Instruction access with I$ enabled
    i1          : i12_type;
    i1pc_repl   : gvaddr_repl_type(0 to icrepl - 1);
    i1cont      : std_ulogic;
    i1rep       : std_ulogic;                      -- IU stalling itself? No invalidation on repeated TLB lookup.
    i1tcmen     : std_ulogic;
    ibpmiss     : std_ulogic;                    -- I$ miss under branch predict was ignored?
    irdbufen    : std_ulogic;                    -- I$ line fetch ongoing
    irdbufpaddr : std_logic_vector(pa'high downto IOFFSET_LOW);     -- Current I$ read buffer base.
    irdbufvaddr : std_logic_vector(va'high downto IOFFSET_LOW);
    iramaddr    : std_logic_vector(ILINE_HIGH downto ILINE_LOW);    --  Low part of address / 8.
    irep        : irep_type;
    itlbprobeid : std_logic_vector(log2x(itlbnum) - 1 downto 0);
    tcmdata     : word32;
    -- DCache logic registers
    d2vaddr     : addr_type;
    d2paddr     : paddr_type;
    d2paddrv    : std_ulogic;                      -- TLB hit and permissions OK
    d2tlbhit    : std_ulogic;                      -- TLB entry touched
    d2tlbamatch : std_ulogic;
    d2tlbid     : std_logic_vector(log2x(dtlbnum) - 1 downto 0);
    d2tlbclr    : std_ulogic;                      -- Invalidate TLB entry due to permission failure
    d2data      : word64;
    d2write     : std_ulogic;
    d2size      : word2;
    d2busw      : std_ulogic;                      -- Use wide bus
    d2tlbmod    : std_ulogic;
    d2hitv      : dways_t;
    d2validv    : dways_t;
    d2          : d12_type;
    d2specialasi: std_ulogic;
    d2forcemiss : std_ulogic;
    d2lock      : std_ulogic;
    d2stbuf     : stbufarr(0 to 3);
    d2stbw      : unsigned(1 downto 0);
    d2stba      : unsigned(1 downto 0);
    d2stbd      : unsigned(1 downto 0);
    d2specread  : std_ulogic;
    d2nocache   : std_ulogic;                      -- Marks whether cacheable
    d2tcmhit    : std_ulogic;
    h2tlbupd    : std_ulogic;                      -- TLB entry updated
    h2tlbid     : std_logic_vector(log2x(htlbnum) - 1 downto 0);
    h2tlbclr    : std_ulogic;                      -- Invalidate TLB entry due to permission failure
    -- The d1* are valid when instruction is in memory access stage.
    d1ten       : std_ulogic;                      -- Data access with D$ enabled
    d1chk       : std_ulogic;                      -- Data access (delayed dci.eenaddr, r.holdn = '1')
    d1vaddr     : addr_type;
    d1vaddr_repl : gvaddr_repl_type(0 to dcrepl - 1);
    d1          : d12_type;
    d1specialasi: std_ulogic;
    d1forcemiss : std_ulogic;
    d1tcmen     : std_ulogic;
    dramaddr    : std_logic_vector(d_line'high downto DLINE_LOW_REAL);
    dvtagdone   : std_ulogic;
    dregval     : word32;                           -- ASI read value
    dregval64   : word32;
    aregval     : word32;
    dregerr     : std_ulogic;
    dtlbrecheck : std_ulogic;
    -- LRU
    ilru        : lruarr(0 to 2 ** IOFFSET_BITS - 1);
    dlru        : lruarr(0 to 2 ** DOFFSET_BITS - 1);
    -- Common flush registers
    flushctr    : std_logic_vector(max_sets'range);
    flushpart   : word2;
    dtflushdone : std_ulogic;
    mmusel      : mmusel_type;
    -- PMP in TLB
    pmp_mask    : addr_type;
    pmp_low     : addr_type;
    pmp_m       : std_ulogic;                       -- M mode for TLB PMP lookup
    pmp_do      : std_ulogic;
    pmp_only    : std_ulogic;                       -- For diagnostics
    pmp_hit     : std_ulogic;
    pmp_fit     : std_ulogic;
    pmp_hitv    : std_logic_vector(pmp_entries - 1 downto 0);  -- For diagnostics
    pmp_fitv    : std_logic_vector(pmp_entries - 1 downto 0);  -- For diagnostics
    pmp_m_rwx   : word3;
    pmp_su_rwx  : word3;
    pmp_rwx     : word3;
    pmp_idx     : std_logic_vector(5 downto 0);
    pmp_none    : std_ulogic;
    pmp_lock    : std_ulogic;
    -- PMA in TLB
    pma_hit     : std_ulogic;
    pma_fit     : std_ulogic;
    --pma_hitv    : std_logic_vector(pma_entries - 1 downto 0);  -- For diagnostics
    --pma_fitv    : std_logic_vector(pma_entries - 1 downto 0);  -- For diagnostics
    --pma_idx     : std_logic_vector(log2x(pma_entries) - 1 downto 0);
    pma_hitv    : std_logic_vector(PMAENTRIES - 1 downto 0);  -- For diagnostics
    pma_fitv    : std_logic_vector(PMAENTRIES - 1 downto 0);  -- For diagnostics
    pma_idx     : std_logic_vector(log2x(PMAENTRIES) - 1 downto 0);
    pma         : pma_t;
    -- Hypervisor
    h_addr      : gaddr_type;
    h_addr_repl : gvaddr_repl_type(0 to hrepl - 1);
    h_do        : std_ulogic;
    h_done      : std_ulogic;
    h_v         : std_ulogic;
    h_x         : std_ulogic;
    h_ls        : std_ulogic;
    h_mxr       : std_ulogic;
    h_vmxr      : std_ulogic;
    h_hx        : std_ulogic;
    h_cause     : word2;
    h_w         : std_ulogic;
    h_pmp_no_w  : std_ulogic;
    h_pmp_no_x  : std_ulogic;
    addrhyper   : gaddr_type;
    itypehyper  : word2;  -- 00 OK, 01 data RW, 10 PT R, 11 - PT W
    dtypehyper  : word2;
    -- FPC debug interface (ASI 0x20)
    fpc_mosi    : nv_intreg_mosi_type;
    -- CPU-to-CPU control interface (ASI 0x22)
    c2c_mosi    : nv_intreg_mosi_type;
    -- IU BTB/BHT diagnostic interface (ASI 0x24)
    iudiag_mosi : nv_intreg_mosi_type;
    -- context switch status signal
    -- Page fault markers
    swalk_fault : std_ulogic;
    hwalk_fault : std_ulogic;
    -- Temp perf counter
    perf        : word32;
    -- Atomic instruction interface (RISC-V)
    amo         : amo_type;
    -- Cache Block Operation interface (RISC-V)
    cbo         : cbo_type;
  end record;


  function cctrlnv_regs_res return cctrlnv_regs is
    -- Non-constant
    variable v : cctrlnv_regs;
  begin
    v.cctrl := (dfrz => '0', ifrz => '0', dsnoop => '0',
                dcs  => (others => '0'), ics => (others => '0'),
                ics_btb => (others => '0')
                );
    v.mmctrl1    := mmctrl_type1_none; v.mmfsr := mmctrl_fs_zero; v.mmfar := (others => '0');
    v.regflmask  := (others => '0'); v.regfladdr := (others => '0'); v.iregflush := '0'; v.dregflush := '0';
    v.icignerr   := '0'; v.dcignerr := '0'; v.dcerrmask := '0'; v.dcerrmaskval := '0';
    v.itcmenp    := '0'; v.itcmenva := '0'; v.itcmenvc := '0'; v.itcmperm := "00";
    v.itcmaddr   := (others => '0'); v.itcmctx := (others => '0');
    v.dtcmenp    := '0'; v.dtcmenva := '0'; v.dtcmenvc := '0'; v.dtcmperm := "0000";
    v.dtcmaddr   := (others => '0'); v.dtcmctx := (others => '0'); v.itcmwipe := '0'; v.dtcmwipe := '0';
    v.s          := as_normal; v.imisspend := '0'; v.ifailkind := "00"; v.dmisspend := '0'; v.dfailkind := "00";
    v.iflushpend := '1'; v.dflushpend := '1'; v.slowwrpend := '0'; v.holdn := '1'; v.syncbar := '0';
    v.ramreload  := '0';
    v.stbuffull := '0';
    v.flushwrd   := (others => '0'); v.flushwri := (others => '0'); v.regflpipe := (others => regfl_pipe_entry_zero);
    v.regfldone  := '0';
    v.untagd     := (others => '0'); v.untagi := (others => '0');
    v.ahb.hbusreq   := '0'; v.ahb.hlock := '0'; v.ahb.htrans := HTRANS_IDLE;
    v.ahb.haddr     := (others => '0'); v.ahb.hwrite := '0'; v.ahb.hsize := HSIZE_WORD;
    v.ahb.hburst    := HBURST_SINGLE; v.ahb.hprot := "0000"; v.ahb.hwdata := (others => '0');
    v.ahb.snoopmask := (others => '0');
    v.ahb3.inacc    := '0'; v.ahb3.rdbuf := (others => '0'); v.ahb3.error := '0'; v.ahb3.rdbvalid := (others => '0');
    v.ahb3.rdberr := (others => '0');
    v.ahb2.inacc  := '0'; v.ahb2.hwrite := '0'; v.ahb2.addrmask := (others => '0');
    v.ahb2.ifetch := '0'; v.ahb2.dacc := '0';
    v.granted     := '0'; v.werr := '0';
    v.itlb        := tlb_def(v.itlb'range); v.dtlb := tlb_def(v.dtlb'range); v.htlb := tlb_def(v.htlb'range);
    v.tlbflush    := "00"; v.newent := tlbent_empty; v.mmuerr := mmctrl_fs_zero;
    v.curerrclass := "00"; v.newerrclass := "00";
    v.itlbpmru    := (others => '0'); v.dtlbpmru := (others => '0'); v.htlbpmru := (others => '0');
    v.tlbupdate   := '0'; v.itagpipe := (others => (others => '0')); v.dtagpipe := (others => (others => '0'));
    v.i2paddr    := get_zeros(v.i2paddr); v.i2paddrv := '0';
    v.i2busw     := '0'; v.i2paddrc := '0';
    v.i2tlbhit   := '0'; v.i2tlbid := (others => '0');
    v.i2         := i12_empty;
    v.i2bufmatch := '0';
    v.i2hitv     := (others => '0'); v.i2validv := (others => '0'); v.i2tcmhit := '0';
    v.i1ten      := '0';
    v.i1         := i12_empty;
    v.i1pc_repl  := (others => get_zeros(v.i1pc_repl(0)));
    v.i1cont     := '0'; v.i1rep := '0'; v.i1tcmen := '0';
    v.ibpmiss    := '0'; v.iramaddr := (others => '0');
    v.irdbufen   := '0'; v.irdbufpaddr := (others => '0'); v.irdbufvaddr := (others => '0');
    v.irep.hitv     := (others => '0'); v.irep.validv := (others => '0');
    v.irep.way      := (others => '0'); v.irep.data := (others => (others => '0'));
    v.irep.tlbhit   := '0';
    v.irep.tlbpaddr := (others => '0'); v.irep.tlbid := (others => '0'); v.tcmdata := (others => '0');
    v.itlbprobeid  := (others => '0');
    v.d2vaddr  := get_zeros(v.d2vaddr); v.d2paddr := get_zeros(v.d2paddr); v.d2paddrv := '0';
    v.d2tlbhit := '0'; v.d2tlbamatch := '0'; v.d2tlbid := (others => '0'); v.d2tlbclr := '0';
    v.d2data   := (others => '0'); v.d2write := '0'; v.d2busw := '0'; v.d2tlbmod := '0';
    v.d2hitv   := (others => '0'); v.d2validv := (others => '0');
    v.d2size   := "00"; v.d2lock := '0';
    v.d2       := d12_empty;
    v.d2specialasi := '0'; v.d2forcemiss := '0';
    v.d2stbuf  := (others => stbufent_zero); v.d2stbw := "00"; v.d2stba := "00"; v.d2stbd := "00";
    v.d2specread := '0'; v.d2nocache := '0'; v.d2tcmhit := '0';
    v.h2tlbupd := '0'; v.h2tlbid := (others => '0'); v.h2tlbclr := '0';
    v.d1ten    := '0'; v.d1chk := '0'; v.d1vaddr := get_zeros(v.d1vaddr);
    v.d1vaddr_repl := (others => get_zeros(v.d1vaddr_repl(0)));
    v.d1       := d12_empty;
    v.d1specialasi := '0'; v.d1forcemiss := '0';
    v.dramaddr := (others => '0'); v.dvtagdone := '0';
    v.dregval  := (others => '0'); v.dregval64 := (others => '0'); v.aregval := (others => '0');
    v.dregerr  := '0'; v.dtlbrecheck := '0';
    v.ilru     := (others => (others => '0')); v.dlru := (others => (others => '0'));
    v.flushctr := (others => '0'); v.flushpart := (others => '0'); v.dtflushdone := '0';
    v.mmusel   := access_i;
    v.fpc_mosi := nv_intreg_mosi_none; v.c2c_mosi := nv_intreg_mosi_none;
    v.iudiag_mosi := nv_intreg_mosi_none;
    v.pmp_mask := (others => '0'); v.pmp_low := (others => '0'); v.pmp_m := '0'; v.pmp_do := '0'; v.pmp_only := '0';
    v.pmp_hit := '0'; v.pmp_fit := '0';
    v.pmp_hitv := (others => '0'); v.pmp_fitv := (others => '0');
    v.pmp_m_rwx := (others => '0'); v.pmp_su_rwx := (others => '0'); v.pmp_rwx := (others => '0');
    v.pmp_idx := (others => '0'); v.pmp_none := '0'; v.pmp_lock := '0';
    v.pma_hit := '0'; v.pma_fit := '0';
    v.pma_hitv := (others => '0'); v.pma_fitv := (others => '0');
    v.pma_idx := (others => '0'); v.pma := pma_unused;
    v.h_addr  := (others => '0'); v.h_addr_repl := (others => get_zeros(v.h_addr_repl(0)));
    v.h_do    := '0'; v.h_done := '0'; v.h_v := '0'; v.h_x := '0';
    v.h_ls    := '0'; v.h_mxr := '0'; v.h_vmxr := '0'; v.h_hx := '0';
    v.h_cause := "00";
    v.h_w     := '0'; v.h_pmp_no_w := '0'; v.h_pmp_no_x := '0';
    v.addrhyper    := (others => '0');
    v.itypehyper   := (others => '0');
    v.dtypehyper   := (others => '0');
    v.swalk_fault  := '0'; v.hwalk_fault := '0';
    v.perf         := (others => '0');
    v.amo.d1type   := (others => '0');
    v.amo.d2type   := (others => '0');
    v.amo.reserved := '0';
    v.amo.hold     := '0';
    v.amo.addr     := (others => '0');
    v.amo.store    := (others => '0');
    v.amo.sc       := '0';
    v.amo.s4hit    := (others => '0');
    v.amo.s4tag    := (others => '0');
    v.amo.s4offs   := (others => '0');
    v.cbo.d1type   := (others => '0');
    v.cbo.d2type   := (others => '0');
    v.cbo.hold     := '0';

    return v;
  end cctrlnv_regs_res;


  constant RRES : cctrlnv_regs := cctrlnv_regs_res;

  subtype vbitent is dways_t;
  type    vbitarr is array(natural range <>) of vbitent;

  type cctrlnv_snoop_regs is record
    sgranted : std_ulogic;
    s3hit    : dways_t;
    s3tag    : std_logic_vector(d_tag'range);
    s3offs   : std_logic_vector(d_sets'range);
    s3read   : dways_t;
    s3flush  : dways_t;
    s3tagmsb : std_logic_vector(2 * DWAYS - 1 downto 0);
    s2en     : dways_t;
    s2tag    : std_logic_vector(d_tag'range);
    s2offs   : std_logic_vector(d_sets'range);
    s2read   : dways_t;
    s2flush  : dways_t;
    s2tagmsb : std_logic_vector(2 * DWAYS - 1 downto 0);
    s2eread  : std_ulogic;
    s1en     : dways_t;
    s1haddr  : std_logic_vector(ahbo.haddr'range);
    s1read   : std_ulogic;
    s1flush  : dways_t;
    s1tagmsb : std_logic_vector(2 * DWAYS - 1 downto 0);
    s1hwrite : std_ulogic;
    s1hsize  : word3;
    s1hmaster: word4;
    s1htrans0: std_ulogic;
    -- DCache valid bits for dtagconf > 0
    validarr : vbitarr(0 to 2 ** DOFFSET_BITS - 1);
    -- AHB error status
    ahberr        : std_ulogic;
    ahboerr       : std_ulogic;
    ahberrm       : std_ulogic;
    ahboerrm      : std_ulogic;
    ahberrhaddr   : std_logic_vector(ahbo.haddr'range);
    ahberrhwrite  : std_ulogic;
    ahberrhsize   : word3;
    ahberrhmaster : word4;
    errburstfilt  : std_ulogic;
    ahberrtype    : word2;
    ahberracc     : word5;
    -- External (diagnostic) access holding regs
    --  dcache tag write (data from r.dtagpipe except 2 msbs and lsb(valid) from regs)
    dtwrite       : std_ulogic;
    dtaccidx      : std_logic_vector(d_sets'range);
    dtaccways     : dways_t;
    dtacctagmod   : std_ulogic;
    dtacctagmsb   : std_logic_vector(2 * DWAYS - 1 downto 0);
    dtacctaglsb   : std_logic_vector(DWAYS - 1 downto 0);
    --  snoop tag read / write
    stread        : std_ulogic;
    stwrite       : std_ulogic;
    staccidx      : std_logic_vector(d_sets'range);
    stacctag      : std_logic_vector(TAG_HIGH - DTAG_LOW + 1 downto 1);
    staccways     : dways_t;
    strdstarted   : std_ulogic;
    strddone      : std_ulogic;
    -- Deadlock counter for diag access
    dlctr         : word8;
    raisereq      : std_ulogic;
  end record;

  constant RSRES : cctrlnv_snoop_regs :=
    (sgranted => '0',
     s3hit    => (others => '0'),
     s3tag    => (others => '0'),
     s3offs   => (others => '0'),
     s3read   => (others => '0'),
     s3flush  => (others => '0'),
     s3tagmsb => (others => '0'),
     s2en     => (others => '0'),
     s2tag    => (others => '0'),
     s2offs   => (others => '0'),
     s2read   => (others => '0'),
     s2flush  => (others => '0'),
     s2tagmsb => (others => '0'),
     s2eread  => '0',
     s1en     => (others => '0'),
     s1haddr  => (others => '0'),
     s1read   => '0',
     s1flush  => (others => '0'),
     s1tagmsb => (others => '0'),
     s1hwrite   => '0',
     s1hsize    => "000",
     s1hmaster  => "0000",
     s1htrans0  => '0',
     validarr => (others => (others => '0')),
     ahberr       => '0',
     ahboerr      => '0',
     ahberrm      => '0',
     ahboerrm     => '0',
     ahberrhaddr  => (others => '0'),
     ahberrhwrite => '0',
     ahberrhsize  => "000",
     ahberrhmaster => "0000",
     errburstfilt => '0',
     ahberrtype   => "00",
     ahberracc    => "00000",
     dtwrite      => '0',
     dtaccidx     => (others => '0'),
     dtaccways    => (others => '0'),
     dtacctagmod  => '0',
     dtacctagmsb  => (others => '0'),
     dtacctaglsb  => (others => '0'),
     stread       => '0',
     stwrite      => '0',
     staccidx     => (others => '0'),
     stacctag     => (others => '0'),
     staccways    => (others => '0'),
     strdstarted  => '0',
     strddone     => '0',
     dlctr        => (others => '0'),
     raisereq     => '0'
     );

  constant hconfig : ahb_config_type := (
    0      => ahb_device_reg(VENDOR_GAISLER, GAISLER_RV64GC, 0, 0, 0),
    others => (others => '0'));

  constant addr_check_mask : word8 := u2vec(addr_check, 8);

  signal rs, rsin : cctrlnv_snoop_regs;
  signal r, rin   : cctrlnv_regs;

  signal dbg    : std_logic_vector(11 downto 0);

  type tlbcheck is record
    hit        : std_ulogic;
    amatch     : std_ulogic;
    paddr      : gpaddr_type;
    perm       : word5;                                 -- unused
    hitv       : std_logic_vector(0 to TLBNUMMAX - 1);  -- unused
    id         : std_logic_vector(log2(TLBNUMMAX) - 1 downto 0);
    busw       : std_ulogic;
    cached     : std_ulogic;
    modded     : std_ulogic;
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
    (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '0', '0',
    (others => '0'), (others => '0'),
    "00", pma_unused, '0', '0', "000",
    '0');

--  impure
  function permitted(x        : std_logic;     -- 1 - execute access
                     su       : std_logic;     -- 1 - S access
                     w        : std_logic;     -- 1 - write access
                     lock     : std_logic;     -- Unused for RISC-V
                     perm     : word5;         -- RISC-V: SUXWR, LEON decoded
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
    if is_riscv then
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
      acc  := ft_acc_resolve("" & w & x & su, data);
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
--        ok := ok or (acc(2) = '0');
        ok := ok or (x = '0' and w = '0' and (data(rv_pte_x) = '1' or pmp_no_x = '1'));
      end if;
      -- HX is mostly the same as for MXR, but X is required.
      if ext_h = 1 and hx = '1' then
        ok := pmp_r = '1' and data(rv_pte_x) = '1' and
              ((su = '0' and data(rv_pte_u) = '1') or
               (su = '1' and (data(rv_pte_u + 1) = '1' or sum = '1')));
      end if;
    else
      if (su  = '1' and (w = '1' or  lock = '1') and perm(3) = '1') or
         (su  = '1' and (w = '0' and lock = '0') and perm(2) = '1') or
         (su  = '0' and (w = '1' or  lock = '1') and perm(1) = '1') or
         (su  = '0' and (w = '0' and lock = '0') and perm(0) = '1') then
        ok := true;
      end if;
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
      acc  := ft_acc_resolve("100", data);   -- W ~X ~S
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

    return u2i(addr(addr'high downto physaddr)) = 0;
  end;

  -- Guest physical addresses should have zeroes at the top.
  function gphysical_ok(addr : std_logic_vector) return boolean is
  begin
    -- Addresses are always OK for RV32!
    if riscv_mmu = sv32 then
      return true;
    end if;

    return u2i(addr(addr'high downto ga_msb+1)) = 0;
  end;

  -- Virtual addresses must be sign extended.
  function virtual_ok(addr : std_logic_vector) return boolean is
  begin
    -- Addresses are always OK for RV32!
    if riscv_mmu = sv32 then
      return true;
    end if;

    return u2i(    addr(addr'high downto va'high)) = 0 or
           u2i(not addr(addr'high downto va'high)) = 0;
  end;

  function get_mode(csr : nv_csr_out_type; vms : word3) return mode_t is
    -- Non-constant
    variable mode : mode_t := (others => '0');
  begin
    if vms(2) = '0' then
      -- Machine mode always has zeroed mode,
      -- supervisor and user mode only when non-bare SATP.
      if vms(1 downto 0) /= PRIV_LVL_M then
        mode(0) := to_bit(gaisler.mmucacheconfig.satp_mode(riscv_mmu, csr.satp) /= 0);
      end if;
    elsif mmuen /= 0 and ext_h = 1 and vms(2) = '1' then
      mode(2) := '1';
      mode(1) := to_bit(gaisler.mmucacheconfig.satp_mode(riscv_mmu, csr.hgatp) /= 0);
      mode(0) := to_bit(gaisler.mmucacheconfig.satp_mode(riscv_mmu, csr.vsatp) /= 0);
    end if;

    return mode;
  end;

  function is_v(mode : mode_t) return boolean is
  begin
    return is_riscv and mmuen = 1 and ext_h = 1 and mode(2) = '1';
  end;

  function is_v(mode : mode_t) return std_logic is
  begin
    return to_bit(is_v(mode));
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

  -- Unlike for RISC-V, the SPARC implementation will call this even
  -- without the MMU being "enabled", thus the checks.
  procedure tlb_lookup(x          : word2;             -- x1 - ITLB, 1x - hTLB
                       tlb        : tlbentarr;
                       addr_ok    : boolean;           -- Top address bits OK
                       vaddr_repl : gvaddr_repl_type;  -- Copies of virtual address
                       vaddr_in   : std_logic_vector;  -- Virtual address
                       dsuaddr    : std_logic_vector;  -- Unused for RISC-V
                       ctx        : std_logic_vector;  -- ASID (+VMID)
                       su         : std_logic;         -- 1 - S access
                       w          : std_logic;         -- 1 - write access
                       lock       : std_logic;         -- Unused for RISC-V
                       enabled    : std_logic;         -- Unused for RISC-V
                       check      : std_logic;         -- Do check
                       specialasi : std_logic;         -- No entry clear on permission failure
                       nullify    : std_logic;         -- No entry clear on permission failure
                       repeat     : std_logic;         -- No entry clear on permission failure
                       dsuen      : std_logic;         -- Unused for RISC-V
                       tlbchk     : out tlbcheck;
                       sum        : std_logic;         -- S access as if U
                       mxr        : std_logic;         -- Allow R if X
                       vmxr       : std_logic;         -- V allow R if X
                       hx         : std_logic;         -- Allow R _only_ if X
                       mode       : mode_t;            -- Current V and *APT setup
                       ss         : std_logic := '0';  -- Shadow stack access
                       ss_010en   : std_logic := '0';  -- Shadow stack XWR=010 enabled
                       display    : boolean   := false -- Enable debug output
                       ) is
    -- Non-constant
    variable vaddr     : gvaddr_type;
    variable paddr     : gpaddr_type;
    variable mask      : std_logic_vector(tlb(0).mask'range) := (others => '0');
    variable vbusw     : std_logic                           := '0';
    variable match     : boolean;
    variable pos       : integer;
    variable tmpchk    : tlbcheck                            := tlbcheck_none;
    variable index     : integer                             := -1;
    variable ctx_match : boolean                             := true;
  begin

    for n in tlb'range loop
      if not is_riscv and dsuen = '1' then
        vaddr := dsuaddr(vaddr'range);
      else
        vaddr := vaddr_repl(n mod vaddr_repl'length)(vaddr'range);
      end if;
      match := true;
      pos   := 12;
      for i in tlb(n).mask'reverse_range loop
        match := match and (tlb(n).mask(i) = '0' or
                            get(tlb(n).vaddr, pos, va_size(i)) = get(vaddr, pos, va_size(i)));
        pos := pos + va_size(i);
      end loop;
      -- Check extra top two bits when guest physical address,
      -- ie when hPT lookup or guest physical address from IU (V and hPT and not vsPT).
      if x(1) = '1' or (is_v(mode) and has_hgatp(mode) and not has_xsatp(mode)) then
        match := match and get(tlb(n).vaddr, pos, 2) = get(vaddr, pos, 2);
      end if;

      -- Check context if not only fetching PMP/PMA.
      if has_context and is_mapping(mode) then
        ctx_match := tlb(n).ctx = ctx;
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

      if (addr_ok and tlb(n).valid = '1' and ctx_match and match) or
         (not is_riscv and (n) = 0 and enabled = '0')
      then
        if (walk_pmp and not is_mapping(mode)) or     -- If only fetching PMP/PMA information,
           permitted(x(0), su, w, lock, tlb(n).perm,  --   or PT permissions OK.
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
        index := (n);
        -- Note that 'or' can be used since only one TLB entry may really hit,
        -- and it avoids prioritizing so less logic.
        tmpchk.amatch  := '1';
        set(tmpchk.paddr, 12, get(tmpchk.paddr, 12, gpn) or tlb(n).paddr);
        tmpchk.id      := tmpchk.id      or u2vec(n, tmpchk.id);
        tmpchk.busw    := tmpchk.busw    or tlb(n).busw;
        tmpchk.cached  := tmpchk.cached  or tlb(n).cached;
        tmpchk.modded  := tmpchk.modded  or tlb(n).modified;
        mask           := (others => '0');
        mask           := mask           or tlb(n).mask;
        paddr          := (others => '0');
        if is_riscv or enabled = '1' then
          virtual2physical(vaddr, mask, paddr);
        else
          virtual2physical(vaddr, get_zeros(mask), paddr);
        end if;
        tmpchk.paddr    := tmpchk.paddr  or paddr;
        if ext_h = 1 then
          tmpchk.h_pmp_r    := tmpchk.h_pmp_r    or tlb(n).pmp_r;
          tmpchk.h_pmp_no_w := tmpchk.h_pmp_no_w or tlb(n).pmp_no_w;
          tmpchk.h_pmp_no_x := tmpchk.h_pmp_no_x or tlb(n).pmp_no_x;
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

    if not is_riscv and dsuen = '1' then
      tmpchk.paddr(11 downto 0) := tmpchk.paddr(11 downto 0) or dci.maddress(11 downto 0);
    else
      tmpchk.paddr(11 downto 0) := tmpchk.paddr(11 downto 0) or
                                   vaddr_in(11 downto 0);
    end if;
    if display and (is_riscv or enabled = '1') and check = '1' then
      if tmpchk.hit = '0'then
      else
      end if;
    end if;

    -- Select bus width from TLB unless 4 GiB entry, then decode from virt addr
    if not is_riscv and mask(1) = '0' then
      vbusw       := dec_wbmask_fixed(vaddr_in(ahbo.haddr'high downto 2), wbmask);
      tmpchk.busw := tmpchk.busw or vbusw;
    end if;

    -- Select cacheability from TLB unless cache is off
    if not is_riscv and enabled = '0' then
      tmpchk.cached := ahb_slv_dec_cache(vaddr_in(ahbo.haddr'range), ahbso, cached);
    end if;

    tlbchk := tmpchk;
  end;

begin


--  comb: process(r, rs, rst, ici, dci, ahbi, ahbsi, ahbso, cramo, csro, fpc_miso, c2c_miso, freeze, bootword, smpflush)
  comb: process(r, rs, rst, ici, dci, ahbi, ahbsi, ahbso, cramo, csro, freeze, bootword, smpflush)

    function mmu_base(r : cctrlnv_regs; csr : nv_csr_out_type) return std_logic_vector is
    begin
      if is_riscv then
        -- This will never be called for RISC-V!
        return "";
      else
        return r.mmctrl1.ctxp(25 downto 4) & r.mmctrl1.ctx & "00";
      end if;
    end;

    function mmu_base(r : cctrlnv_regs; csr : nv_csr_out_type; mode : mode_t) return std_logic_vector is
    begin
      if is_riscv then
        if not is_v(mode) then
          return gaisler.mmucacheconfig.satp_base(riscv_mmu, csr.satp);
        else
          return gaisler.mmucacheconfig.satp_base(riscv_mmu, csr.vsatp);
        end if;
      else
        return r.mmctrl1.ctxp(25 downto 4) & r.mmctrl1.ctx & "00";
      end if;
    end;

    function hmmu_base(csr : nv_csr_out_type; gpaddr : gaddr_type) return std_logic_vector is
      -- Non-constant
      variable base     : paddr_type;
      variable base_tmp : std_logic_vector(gaisler.mmucacheconfig.pa_msb(riscv_mmu) downto 0);
    begin
      if is_riscv then
        base_tmp := gaisler.mmucacheconfig.satp_base(riscv_mmu, csr.hgatp);
        base     := base_tmp(base'range);
        -- Two extra bits of address at the top, so possibly "add" n*4k to base.
        set(base, 12, get_hi(gpaddr, 2));
        return base;
      else
        -- This will never be called except for RISC-V!
        return "";
      end if;
    end;

    -- Return current context, cut down to appropriate size.
    function mmu_ctx(r : cctrlnv_regs; csr : nv_csr_out_type;
                     mode : mode_t := (others => '1')) return std_logic_vector is
      -- Non-constant
      variable ctx : ctxword := (others => '0');
    begin
      if is_riscv then
        if riscv_mmu = Sv32 then
-- pragma translate_off
          assert vmidlen <= 7 and asidlen <= 9 report "Bad VM/ASIDLEN" severity failure;
-- pragma translate_on
        end if;
        if has_context then
          if not is_v(mode) then
            ctx := zerov(vmidlen - 1 downto 0) &
                   gaisler.mmucacheconfig.satp_asid(riscv_mmu, csr.satp) (asidlen - 1 downto 0);
          else
            ctx := gaisler.mmucacheconfig.satp_asid(riscv_mmu, csr.hgatp)(vmidlen - 1 downto 0) &
                   gaisler.mmucacheconfig.satp_asid(riscv_mmu, csr.vsatp)(asidlen - 1 downto 0);
          end if;
        end if;
        return ctx;
      else
        return r.mmctrl1.ctx;
      end if;
    end;

    -- This will never be called for Sparc!
    function hmmu_enabled(csr : nv_csr_out_type; v : std_ulogic) return boolean is
    begin
      if not is_riscv or ext_h = 0 or mmuen = 0 then
        return false;
      end if;

      return v = '1' and gaisler.mmucacheconfig.satp_mode(riscv_mmu, csr.hgatp) /= 0;
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

    -- This will never be called for RISC-V!
    function mmu_enabled(r : cctrlnv_regs) return std_logic is
    begin
      if is_riscv or mmuen = 0 then
        return '0';
      end if;

      return r.mmctrl1.e;
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

    -- Called from places that are common for RISC-V and Sparc
    function mmu_enabled(r : cctrlnv_regs; mode : mode_t) return std_logic is
    begin
      if mmuen = 0 then
        return '0';
      end if;

      if is_riscv then
        return to_bit(mmu_enabled(mode));
      else
        return mmu_enabled(r);
      end if;
    end;

    -- This returns '1' if I$ is enabled/frozen!
    function icache_active(r : cctrlnv_regs) return std_logic is
    begin
      if is_riscv then
        return r.cctrl.ics(0);
      else
        return r.cctrl.ics(0);
      end if;
    end;

    function icache_enabled(r : cctrlnv_regs) return boolean is
    begin
      if is_riscv then
        return r.cctrl.ics = "11";
      else
        return r.cctrl.ics = "11";
      end if;
    end;

    -- This returns '1' if D$ is enabled/frozen!
    function dcache_active(r : cctrlnv_regs) return std_logic is
    begin
      if is_riscv then
        return r.cctrl.dcs(0);
      else
        return r.cctrl.dcs(0);
      end if;
    end;

    function dcache_enabled(r : cctrlnv_regs) return boolean is
    begin
      if is_riscv then
        return r.cctrl.dcs = "11";
      else
        return r.cctrl.dcs = "11";
      end if;
    end;

    -- Create a word (32 bit) mask to select a properly sized chunk
    -- out of a 128/256 (depending on LINESZMAX) bit vector, depending on address.
    -- Size can be 1-16 bytes (8-128 bits).
    function getvalidmask(haddr : std_logic_vector;
                          hsize : word3;
                          le    : boolean) return std_logic_vector is
      -- Non-constant
      variable vmask64  : word2;
      variable vmask128 : word4;
      variable vmask256 : word8;
      variable r, rt    : std_logic_vector(LINESZMAX - 1 downto 0);
    begin
      vmask64 := "11";
      -- <64 (2^3 bytes) bit access?
      if (hsize(2) = '0' and hsize(1 downto 0) /= "11") then
        -- Mask off low or high depending on address alignment.
        if haddr(2) = '0' then
          vmask64(0) := '0';
        else
          vmask64(1) := '0';
        end if;
      end if;
      vmask128 := vmask64 & vmask64;
      -- <128 (2^4 bytes) bit access?
      if hsize(2) = '0' then
        -- Mask off low or high depending on address alignment.
        if haddr(3) = '0' then
          vmask128(1 downto 0) := "00";
        else
          vmask128(3 downto 2) := "00";
        end if;
      end if;
      vmask256 := vmask128 & vmask128;
      -- Mask off low or high depending on address alignment.
      if haddr(4) = '0' then
        vmask256(3 downto 0) := "0000";
      else
        vmask256(7 downto 4) := "0000";
      end if;
      case LINESZMAX is
        when 4      => r := vmask128;
        when others => r := vmask256;
      end case;
      -- Handle little endian case by flipping the vector
      if le then
        rt := r;
        for x in r'range loop
          r(LINESZMAX - 1 - x) := rt(x);
        end loop;
      end if;

      return r;
    end;

    -- Create a byte (8 bit) mask to select a properly sized chunk
    -- out of a 32 bit vector, depending on address.
    -- Size can be 1-4 bytes (8-32 bits).
    function getdmask(addr : std_logic_vector;
                      size : word2;
                      le   : boolean) return std_logic_vector is
      variable vaddr : std_logic_vector(addr'length - 1 downto 0) := addr;
      -- Non-constant
      variable dmask : word4                                      := "1111";
    begin
      -- <32 (2^2 bytes) bit access?
      if size(1) = '0' then
        -- Mask off low or high depending on address alignment.
        if vaddr(1) = '0' then
          dmask := dmask and "1100";
        else
          dmask := dmask and "0011";
        end if;
      end if;
      -- 8 (2^0 bytes) bit access?
      if size(1 downto 0) = "00" then
        -- Mask off low or high depending on address alignment.
        if vaddr(0) = '0' then
          dmask := dmask and "1010";
        else
          dmask := dmask and "0101";
        end if;
      end if;
      if le then
        dmask := dmask(0) & dmask(1) & dmask(2) & dmask(3);
      end if;

      return dmask;
    end;

    function getdmask64(addr : std_logic_vector;
                        size : word2;
                        le   : boolean) return std_logic_vector is
      variable vaddr : std_logic_vector(addr'length - 1 downto 0) := addr;
      -- Non-constant
      variable dmask : word8                                      := "11111111";
    begin
      if size(1 downto 0) /= "11" then
        if vaddr(2) = '0' xor le then
          dmask := dmask and "11110000";
        else
          dmask := dmask and "00001111";
        end if;
      end if;
      if size(1) = '0' then
        if vaddr(1) = '0' xor le then
          dmask := dmask and "11001100";
        else
          dmask := dmask and "00110011";
        end if;
      end if;
      if size(1 downto 0) = "00" then
        if vaddr(0) = '0' xor le then
          dmask := dmask and "10101010";
        else
          dmask := dmask and "01010101";
        end if;
      end if;

      return dmask;
    end;

    function cache_cfg5(crepl, ways, linesize, waysize, lock, snoop,
                        lram, lramsize, lramstart, mmuen : integer) return word32 is
      -- Non-constant
      variable cfg : word32;
    begin
      cfg := (others => '0');
      if ways /= 1 then
        cfg(30 downto 28) := u2vec(crepl * 2 + 1, 3);
      end if;
      if snoop /= 0 then
        cfg(27) := '1';
      end if;
      cfg(26 downto 24) := u2vec(ways - 1, 3);
      cfg(23 downto 20) := u2vec(log2(waysize), 4);
      cfg(18 downto 16) := u2vec(log2(linesize), 3);
      cfg(3  downto  3) := u2vec(mmuen, 1);

      return cfg;
    end;

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
                  1, 1, dtagconf, icrepl, dcrepl
                 );

    -- Function to calculate tag msb bits to guarantee that the tags are unique,
    -- regardless of the other bits of the tag.
    function uniquemsb(msbin : std_logic_vector; wways : std_logic_vector) return std_logic_vector is
      -- Non-constant
      variable r       : std_logic_vector(msbin'length - 1 downto 0) := (others => '0');
      variable msbused : std_logic_vector(0 to 3)                    := "0000";
      variable nmsb    : word2;
    begin
      if notx(msbin) and notx(wways) then
        -- Generate a vector of which 2-bit msb values will remain in use
        for x in 0 to msbin'length / 2 - 1 loop
          if wways(x) = '0' then
            msbused(u2i(msbin(2 * x + 1 downto 2 * x))) := '1';
          end if;
        end loop;
        -- For all ways that will be replaced, select the lowest free value from the
        -- msbused list, and update the msbused list for the next way.
        for x in 0 to msbin'length / 2 - 1 loop
          if wways(x) = '0' then
            nmsb     := "11";
            for y in 3 downto 0 loop
              if msbused(y) = '0' then
                nmsb := u2vec(y, nmsb);
              end if;
            end loop;
            r(2 * x + 1 downto 2 * x) := nmsb;
            msbused(u2i(nmsb))        := '1';
          end if;
        end loop;
      else
-- pragma translate_off
        for x in 0 to msbin'length / 2 - 1 loop
          if wways(x) /= '0' then
            r(2 * x + 1 downto 2 * x) := "XX";
          end if;
        end loop;
-- pragma translate_on
        null;
      end if;

      return r;
    end;

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

    -- Non-constant
    variable v         : cctrlnv_regs;
    variable vs        : cctrlnv_snoop_regs;
    variable oico      : nv_icache_out_type;
    variable odco      : nv_dcache_out_type;
    variable oahbo     : ahb_mst_out_type;
    variable ocrami    : nv_cram_in_type;
    variable ihit      : std_ulogic;
    variable ivalid    : std_ulogic;
    variable ibufaddrmatch : std_ulogic;
    variable ihitv     : iways_t;
    variable ivalidv   : iways_t;
    variable itcmhit   : std_ulogic;
    variable iway      : word2;
    variable icont     : std_ulogic;
    variable itlbchk   : tlbcheck;
    variable ilruent   : lruent;
    variable itcmact   : std_ulogic;
    variable dctagsv   : cram_tags;
    variable dhitv     : dways_t;
    variable dvalidv   : dways_t;
    variable dhit      : std_ulogic;
    variable dvalid    : std_ulogic;
    variable dtcmhit   : std_ulogic;
    variable dway      : std_logic_vector(log2(DWAYS) - 1 downto 0);
    --variable dasi      : word8;
    --variable dsu       : std_ulogic;
    variable dlock     : std_ulogic;
    variable dspecialasi : std_ulogic;
    variable dforcemiss  : std_ulogic;
    variable dtlbchk     : tlbcheck;
    variable dtlb_write  : std_ulogic;
    variable dtlb_lock   : std_ulogic;
    variable dtenall   : std_ulogic;
    variable dlruent   : lruent;
    variable dtcmact   : std_ulogic;
    variable vaddr5    : word5;
    variable vaddr3    : word3;                         -- sub field for ASI
    variable fastwr    : std_ulogic;                    -- simple write
    variable vdiagasi  : word4;
    variable d64       : word64;
    variable dwriting  : std_ulogic;
    variable d32       : word32;
    variable htlbchk   : tlbcheck;

    variable rdb64     : word64;
    alias    rdb32    is rdb64(31 downto 0);
    variable rdb32v    : std_ulogic;
    variable rdb64v    : std_ulogic;
    variable vneedwb   : std_ulogic;
    variable vneedwblock : std_ulogic;
--    variable vway      : unsigned(1 downto 0);
    variable vway      : unsigned(2 downto 0);
    variable vhit      : std_ulogic;
    variable vtmp2     : word2;
    variable vtmp3     : word3;
    variable vwdata128 : std_logic_vector(127 downto 0);
    variable vwdata64  : word64;
    variable vwdata    : std_logic_vector(cdataw - 1 downto 0);
    variable vwad      : std_logic_vector(4 downto 3);
    variable vtmp4i    : std_logic_vector(0 to MAXWAYS - 1);
    variable keepreq   : std_ulogic;
    variable voffs     : std_logic_vector(d_index'range);
    variable vfoffs    : std_logic_vector(d_index'range);

    variable frdmatch  : dways_t;
    variable frimatch  : iways_t;
    variable frmsbd    : std_logic_vector(2 * DWAYS - 1 downto 0);
    variable frmsbi    : std_logic_vector(2 * IWAYS - 1 downto 0);
    variable vbubble0  : std_ulogic;
    variable vstall    : std_ulogic;

    variable vvalididx : std_logic_vector(DOFFSET_HIGH - DOFFSET_LOW downto 0);
    variable vvalidclr : dways_t;
    variable vvalidset : dways_t;

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
    --variable pma_hit   : std_logic_vector(pma_entries - 1 downto 0);
    --variable pma_prio  : std_logic_vector(pma_entries - 1 downto 0);
    --variable pma_fit   : std_logic_vector(pma_entries - 1 downto 0);
    variable pma_hit   : std_logic_vector(PMAENTRIES - 1 downto 0);
    variable pma_prio  : std_logic_vector(PMAENTRIES - 1 downto 0);
    variable pma_fit   : std_logic_vector(PMAENTRIES - 1 downto 0);
    variable pma_idx   : std_logic_vector(r.pma_idx'range);
    variable pma       : pma_t;


    variable start_walk : boolean;
    variable start_pmp  : boolean;
    variable mmu_data  : word64;         -- To fake MMU page table data from mmu_base.

    variable iaddr_ok  : boolean;
    variable daddr_ok  : boolean;

    variable i_mexc    : std_ulogic;     -- Instruction memory exception
    variable i_exctype : std_ulogic;     --  0 - page fault, 1 - access fault (PMP/bus)
    variable d_mexc    : std_ulogic;     -- Data memory exception
    variable d_exctype : std_ulogic;     --  0 - page fault, 1 - access fault (PMP/bus)

    -- Atomic operations
    variable amo_op    : word4;
    variable amo_src1  : word64;
    variable amo_src2  : word64;
    variable amo_data  : word64;
    variable amo_snoop : std_logic;


    variable haddr     : word64;

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

    -- Used to avoid comparisons on v.s
    variable do_access    : boolean;
    variable do_mmu_lock  : boolean;
    variable do_icfetch   : boolean;
    variable do_wrasi2    : boolean;
    variable do_rdcdiag   : boolean;

    -- Get cache control parameters
    function get_ccr(r : cctrlnv_regs; rs : cctrlnv_snoop_regs) return word32 is
      -- Non-constant
      variable ccr : word32 := (others => '0');
    begin
      ccr(23) := r.cctrl.dsnoop;
      ccr(17) := '1';
      ccr(15 downto 14) := r.iflushpend & r.dflushpend;
      ccr( 5 downto  0) := r.cctrl.dfrz & r.cctrl.ifrz & r.cctrl.dcs & r.cctrl.ics;

      return ccr;
    end;

    -- Set cache control parameters
    procedure set_ccr(val : word32) is
      -- Non-constant
      variable vx : word32 := val;
    begin
      if not is_riscv then
        v.cctrl.dsnoop  := vx(23);
        v.dflushpend    := v.dflushpend or vx(22);
        v.iflushpend    := v.iflushpend or vx(21);
        v.cctrl.dfrz    := vx(5);
        v.cctrl.ifrz    := vx(4);
        v.cctrl.dcs     := vx(3 downto 2);
        v.cctrl.ics     := vx(1 downto 0);
        v.cctrl.ics_btb := vx(1 downto 0);
      end if;
    end;

    -- Find first zero in pmru vector, returns index
    -- (returns highest index if all ones)
    function pmru_decode(pmru : std_logic_vector) return std_logic_vector is
      constant nent  : integer                   := pmru'length;
      -- Non-constant
      variable r     : std_logic_vector(log2(nent) - 1 downto 0);
      variable xpmru : std_logic_vector(0 to 2 ** log2(nent) - 1);
    begin
      xpmru                := (others => '0');
      xpmru(0 to nent - 1) := pmru;
      xpmru(nent - 1)      := '0'; -- Return highest index if all-ones
      r                    := (others => '0');
      for q in r'high downto 0 loop
        if all_1(xpmru(0 to (2 ** q - 1))) then
          r(q)                     := '1';
          xpmru(0 to (2 ** q - 1)) := xpmru(2 ** q to 2 ** (q + 1) - 1);
        end if;
      end loop;

      return r;
    end;

    function lruent_compact(oent : lruent; way : std_logic_vector; ways : integer) return lruent is
      variable size  : integer := log2(ways);
      -- Non-constant
      variable found : boolean := false;
      variable ent   : lruent  := (others => '0');
    begin
      for i in 1 to ways - 1 loop
        found := found or way = get(oent, (i - 1) * size, size);
        if not found then
          set(ent, i * size, get(oent, (i - 1) * size, size));
        else
          set(ent, i * size, get(oent, i * size, size));
        end if;
      end loop;

      return ent;
    end;

    function calc_lruent(oent : lruent; hway : unsigned; nways : integer) return lruent is
      -- Non-constant
      variable nent : lruent := (others => '0');
    begin
      case nways is
        when 1 =>
        when 2 =>
          nent(3)          := not hway(0);
        when 3 =>
          nent(4 downto 2) := lru_3way_table(u2i(oent(4 downto 2)))(u2i(hway(1 downto 0)));
        when 8 =>
          nent             := lruent_compact(oent, std_logic_vector(hway), nways);
          nent(hway'range) := std_logic_vector(hway);
        when others =>
          nent(4 downto 0) := lru_4way_table(u2i(oent(4 downto 0)))(u2i(hway(1 downto 0)));
      end case;

      return nent;
    end;

    -- Return vector with a bit set at n mod w.
    -- Normally only used with n < w.
    function decwrap(n : std_logic_vector; w : integer) return std_logic_vector is
      -- Non-constant
      variable r : std_logic_vector(0 to 2 ** n'length - 1) := (others => '0');
    begin
      for i in r'range loop
        if n = u2vec(i, n) then
          r(i mod w) := '1';
        end if;
      end loop;

      return r;
    end;

    function flushmatch(e : tlbent; vaddr : std_logic_vector; curctx : std_logic_vector) return boolean is
      variable fltp    : word4   := vaddr(11 downto 8);
      -- Non-constant
      variable r       : boolean := false;
      variable acctype : boolean := false;
      variable ctxeq   : boolean := false;
      variable match   : boolean := true;
      variable pos     : integer := 12;
    begin
      if not is_riscv then
        if unsigned(e.acc) > 5 then
          acctype := true;
        end if;
        if not has_context or e.ctx = curctx then
          ctxeq := true;
        end if;
        case fltp is
          when "0000" =>
          if (acctype or ctxeq) and vaddr(31 downto 12) = e.vaddr(31 downto 12) and e.mask(3) = '1' then
            r := true;
          end if;
          when "0001" =>
            if (acctype or ctxeq) and vaddr(31 downto 18) = e.vaddr(31 downto 18) and e.mask(2) = '1' then
              r := true;
            end if;
          when "0010" =>
            if (acctype or ctxeq) and vaddr(31 downto 24) = e.vaddr(31 downto 24) and e.mask(1) = '1' then
              r := true;
            end if;
          when "0011" =>
            if not acctype and ctxeq then
              r := true;
            end if;
          when "0100" => r := true;
          when others => r := false;
        end case;
      end if;

      return r;
    end;

    function flushmatch(h : boolean; vs : boolean;
                        e : tlbent; vaddr : std_logic_vector; data : std_logic_vector) return boolean is
      variable match    : boolean := true;
      variable x0s      : word4   := get_hi(data, 4);
      variable x0_addr  : boolean := x0s(3) = '1';
      variable x0_asid  : boolean := x0s(2) = '1';
      variable x0_vmid  : boolean := x0s(1) = '1';
      variable x0_haddr : boolean := x0s(0) = '1';
      -- Non-constant
      variable pos      : integer := 12;
      variable asid_ok  : boolean := true;
      variable vmid_ok  : boolean := true;
    begin
      if is_riscv then
        for i in e.mask'reverse_range loop
          match := match and (e.mask(i) = '0' or
                              get(e.vaddr, pos, va_size(i)) = get(vaddr, pos, va_size(i)));
          pos := pos + va_size(i);
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
        if not x0_asid then
          match := match and asid_ok;
        end if;
        match := match and e.valid = '1';
      end if;

      return match;
    end;

    function tcmaddr_comp(accaddr : std_logic_vector(31 downto 16);
                          tcmaddr : std_logic_vector(31 downto 16);
                          tcmen   : integer; tcmabits : integer) return std_ulogic is
      -- Non-constant
      variable r     : std_ulogic;
      variable vmask : std_logic_vector(31 downto 16);
    begin
      vmask := (others => '0');
      for x in 31 downto 16 loop
        if x > (2 + tcmabits) then
          vmask(x) := '1';
        end if;
      end loop;

      r := '0';
      if (accaddr and vmask) = (tcmaddr and vmask) and tcmen /= 0 then
        r := '1';
      end if;

      return r;
    end;

    -- Select way to replace
    function replace_vec(validv : std_logic_vector; lruent : std_logic_vector) return std_logic_vector is
      -- Non-constant
      variable hitv   : std_logic_vector(validv'range) := (others => '0');
      variable vtmp4i : std_logic_vector(0 to MAXWAYS - 1);
    begin
      for x in 1 to validv'high loop                  -- Next unused
        if validv(x) = '0' and all_1(validv(0 to x - 1)) then
          hitv(x) := '1';
        end if;
      end loop;
      if validv(0) = '0' then                         -- First if unused
        hitv(0)   := '1';
      end if;
      if all_1(validv) then                           -- LRU
        if MAXWAYS <= 4 then
          vtmp4i  := decwrap(lruent(4 downto 3), validv'length);
        else
          vtmp4i  := (others => '0');
          vtmp4i(u2i(lruent(23 downto 21))) := '1';
        end if;
        hitv      := hitv or vtmp4i(hitv'range);
      end if;

      return hitv;
    end;

    -- Rewritten using rr parameter (earlier used global r directly),
    -- to make Vivado XSIM 2022.2 like it better.
    procedure burst_update(rr             : in cctrlnv_regs;
                           linesize       : in integer; wide : in boolean;
                           ahb_htrans_out : out std_logic_vector;
                           ahb_haddr_out  : out std_logic_vector) is
      -- Non-constant
      variable ahb_htrans : std_logic_vector(HTRANS_IDLE'range);
      variable ahb_haddr  : std_logic_vector(ahb_haddr_out'range) := rr.ahb.haddr;
    begin
      -- Vivado XSIM 2022.2 did not like this
      -- in the variable declaration above, for some reason.
      -- It also needed the pointless 'range specification.
      ahb_htrans := rr.ahb.htrans(ahb_htrans'range);

      if ahbi.hresp(1) = '1'  and rr.ahb2.inacc = '1' then
        ahb_htrans := HTRANS_IDLE;
      end if;
      if ahbi.hready = '1'then
        -- Advance haddr/htrans
        if rr.granted = '1' and (ahbi.hresp(1) = '0' or rr.ahb2.inacc = '0') and rr.ahb.htrans(1) = '1' then
          -- Move haddr forward
          -- Note we can not look at r.i2busw here as it may get updated while streaming
          --   therefore we look directly at ahb_hsize instead
          if wide then
            uadd_range(rr.ahb.haddr, 1, ahb_haddr(BUF_HIGH downto log2(busw / 8)));
          else
            uadd_range(rr.ahb.haddr, 1, ahb_haddr(BUF_HIGH downto 2));
          end if;
          ahb_htrans := HTRANS_SEQ;
          -- Was last address the final one?
          if wide then
            if all_1(rr.ahb.haddr(log2(linesize * 4) - 1 downto log2(busw / 8))) then
              ahb_htrans := HTRANS_IDLE;
            end if;
          else
            if all_1(rr.ahb.haddr(log2(linesize * 4) - 1 downto 2)) then
              ahb_htrans := HTRANS_IDLE;
            end if;
          end if;
        elsif rr.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
          -- Move haddr backward for retry/split
          if wide then
            uadd_range(rr.ahb.haddr, -1, ahb_haddr(BUF_HIGH downto log2(busw / 8)));
          else
            uadd_range(rr.ahb.haddr, -1, ahb_haddr(BUF_HIGH downto 2));
          end if;
          ahb_htrans := HTRANS_NONSEQ;
        end if;
      end if;

      ahb_htrans_out := ahb_htrans;
      ahb_haddr_out  := ahb_haddr;
    end;

  begin
    dbg <= (others => '0');

    --------------------------------------------------------------------------
    -- Variable init
    --------------------------------------------------------------------------
    v          := r;
    vs         := rs;

    -- Clarify for GHDL (240528) that these are not latches
    vdiagasi     := (others => '0');
    vneedwb      := '0';
    vneedwblock  := '0';
    vtmp4i       := (others => '0');
    vfoffs       := (others => '0');
    vbubble0     := '0';
    vstall       := '0';
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


    d_mexc    := '0';
    d_exctype := '0';  -- Default to page fault
    i_mexc    := '0';
    i_exctype := '0';  -- Default to page fault

    start_walk := false;
    start_pmp  := false;
    pmp_mmu    := '0';

    iaddr_ok  := true;
    daddr_ok  := true;

    oico.data      := cramo.idatadout;
    oico.way       := (others => '0');
    oico.mexc      := '0';
    oico.exctype   := '0';
    oico.exchyper  := '0';     -- Default to non-hypervisor fault
    oico.hold      := r.holdn;
    oico.flush     := r.flushpart(1);
    oico.mds       := '1';
    oico.cfg       := (others => '0');
    oico.bpmiss    := r.ibpmiss;
    oico.eocl      := '0';
    if r.i2.pc(2) = '1' and r.i2.pc(3) = '1' and (ilinesize = 4 or r.i2.pc(4) = '1') then
      oico.eocl    := '1';
    end if;
    oico.badtag    := '0';
    oico.ics_btb   := r.cctrl.ics_btb;
    oico.btb_flush := r.flushpart(1);
    oico.parked    := '0';

    odco           := nv_dcache_out_none;
    -- GRLIB_INTERNAL_BEGIN
    -- To be able to discvoer if the IU writes undefined values to the cache we need to assure that
    -- the cache itself can't give undefined values. If a program loads from a location not written
    -- to that would happen.
    -- odco.data      := cramo.ddatadout;
    -- GRLIB_INTERNAL_END
    for way in cramo.ddatadout'range loop
      odco.data(way) := no_x(cramo.ddatadout(way));
    end loop;
    odco.way       := (others => '0');
    odco.mexc      := '0';
    odco.exctype   := '0';
    odco.exchyper  := '0';     -- Default to non-hypervisor fault
    odco.hold      := r.holdn;
    odco.mds       := '1';
    odco.werr      := r.werr;
    odco.cache     := '0';
    odco.wbhold    := '0';
    odco.badtag    := '0';
    odco.iudiag_mosi := r.iudiag_mosi;

    oahbo.hbusreq := r.ahb.hbusreq or rs.raisereq;
    oahbo.hlock   := r.ahb.hlock;
    oahbo.htrans  := r.ahb.htrans;
    oahbo.haddr   := r.ahb.haddr;
    oahbo.hwrite  := r.ahb.hwrite;
    oahbo.hsize   := r.ahb.hsize;
    oahbo.hburst  := r.ahb.hburst;
    oahbo.hprot   := r.ahb.hprot;
    oahbo.hwdata  := ahbdrivedata(r.ahb.hwdata);
    oahbo.hirq    := (others => '0');
    oahbo.hconfig := hconfig;
    oahbo.hindex  := hindex;


    ocrami           := nv_cram_in_none;
    ocrami.iindex    := (others => '0');
    ocrami.idataoffs := (others => '0');
    if r.holdn = '0' then
      ocrami.iindex(i_sets'range)      := r.i1.pc(i_index'range);
      ocrami.idataoffs(i_offset'range) := r.i1.pc(ILINE_HIGH downto ILINE_LOW);
      ocrami.ifulladdr                 := r.i1.pc(ocrami.ifulladdr'range);
    else
      ocrami.iindex(i_sets'range)      := ici.rpc(i_index'range);
      ocrami.idataoffs(i_offset'range) := ici.rpc(ILINE_HIGH downto ILINE_LOW);
      ocrami.ifulladdr                 := ici.rpc(ocrami.ifulladdr'range);
    end if;
    ocrami.itagen    := (others => '0');
    ocrami.itagwrite := '0';
    ocrami.itagdin   := (others => (others => '0'));
    for s in i_ways'range loop
      ocrami.itagdin(s)(TAG_HIGH - ITAG_LOW + 1 downto 1) := r.irdbufpaddr(i_tag'range);
      ocrami.itagdin(s)(0) := '1';
    end loop;
    ocrami.idataen    := (others => '0');
    ocrami.idatawrite := "00";
    ocrami.idatadin   := (others => '0');
    -- Mux current 64 bit part of fetched RAM data for I$.
    for x in 0 to LINESZMAX / 2 - 1 loop
      if r.iramaddr = u2vec(x, r.iramaddr) then
        if not ENDIAN_B then
          ocrami.idatadin := get64(r.ahb3.rdbuf, (LINESZMAX / 2 - 1 - x) * 64);
        else
          ocrami.idatadin := get64(r.ahb3.rdbuf, x * 64);
        end if;
      end if;
    end loop;
    ocrami.itcmen     := '0';
    ocrami.dtagcindex  := (others => '0');
    if r.holdn = '0' then
      ocrami.dtagcindex(d_sets'range) := r.d1vaddr(d_index'range);
    else
      ocrami.dtagcindex(d_sets'range) := dci.eaddress(d_index'range);
    end if;
    ocrami.dtagcen     := (others => '0');
    ocrami.dtaguindex  := (others => '0');
    ocrami.dtaguwrite  := (others => '0');
    ocrami.dtagudin    := (others => (others => '0'));
    ocrami.dtagcuindex := (others => '0');
    ocrami.dtagcuen    := (others => '0');
    ocrami.dtagcuwrite := '0';
    ocrami.dtagsindex  := (others => '0');
    ocrami.dtagsen     := (others => '0');
    ocrami.dtagswrite  := '0';
    ocrami.dtagsdin    := (others => (others => '0'));
    ocrami.ddataindex  := (others => '0');
    ocrami.ddataoffs   := (others => '0');
    if r.holdn = '0' or dci.write = '1' then
      ocrami.ddataindex(d_sets'range)  := r.d1vaddr(d_index'range);
      ocrami.ddataoffs(d_offset'range) := r.d1vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
      ocrami.ddatafulladdr             := r.d1vaddr(ocrami.ddatafulladdr'range);
    else
      ocrami.ddataindex(d_sets'range)  := dci.eaddress(d_index'range);
      ocrami.ddataoffs(d_offset'range) := dci.eaddress(DLINE_HIGH downto DLINE_LOW_REAL);
      ocrami.ddatafulladdr             := dci.eaddress(ocrami.ddatafulladdr'range);
    end if;
    ocrami.ddataen     := (others => '0');
    ocrami.ddatawrite  := (others => '0');
    ocrami.ddatadin    := (others => (others => '0'));
    for w in d_ways'range loop
      ocrami.ddatadin(w) := dci.edata;
    end loop;
    ocrami.dtcmen  := '0';
    ocrami.dtcmdin := dci.edata;

    vwad        := (others => '0');
    vwad(d_line'high downto DLINE_LOW_REAL) := r.dramaddr;
    vwdata128   := r.ahb3.rdbuf(4 * 32 - 1 downto 0);
    if (vwad(4) = '0') xor ENDIAN_B then
      vwdata128 := r.ahb3.rdbuf(LINESZMAX * 32 - 1 downto LINESZMAX * 32 - 128);
    end if;
    if (vwad(3) = '0') xor ENDIAN_B then
      vwdata64  := vwdata128(127 downto 64);
    else
      vwdata64  := vwdata128(63 downto 0);
    end if;
    if r.s = as_dcfetch then
      for x in 0 to 3 loop
        ocrami.ddatadin(x) := vwdata64;
      end loop;
    end if;

    v.perf := (others => '0');


    --------------------------------------------------------------------------
    -- ICache logic
    --------------------------------------------------------------------------

    -- ICache TLB lookup
    -- Note that this is for the previous (registered) access.
    -- Note that this is done in parallel with cache fetch (registered access).
    if is_riscv and not walk_pmp and (r.i1.m = '1' or not mmu_enabled(r.i1.mode)) then
      itlbchk         := tlbcheck_none;
      -- Some non-defaults to "fake" an MMU access
      itlbchk.hit     := '1';
      itlbchk.paddr   := fit0ext(r.i1.pc, itlbchk.paddr);
      -- The busw/cached settings are overwritten below if PMA (not in TLB here)!
      if not pmaen then
        itlbchk.busw   := dec_wbmask_fixed(r.i1.pc(ahbo.haddr'high downto 2), wbmask);
        itlbchk.cached := ahb_slv_dec_cache(r.i1.pc(ahbo.haddr'range), ahbso, cached);
      end if;
      itlbchk.modded  := '1';
      iaddr_ok        := physical_ok(r.i1.pc);
      if addr_check_mask(5) = '0' then
        iaddr_ok      := true;
      end if;
    else
      if is_riscv then
        if walk_pmp and (r.i1.m = '1' or not mmu_enabled(r.i1.mode)) then
          iaddr_ok      := physical_ok(r.i1.pc);
          if addr_check_mask(5) = '0' then
            iaddr_ok    := true;
          end if;
        else
          if hmmu_only(r.i1.mode) then
            iaddr_ok    := gphysical_ok(r.i1.pc);
          else
            iaddr_ok    := virtual_ok(r.i1.pc);
          end if;
          if addr_check_mask(4) = '0' then
            iaddr_ok    := true;
          end if;
        end if;
      end if;
      -- Pass along actual r.i1.pc too, for LEON5 code equivalence.
      tlb_lookup("01", r.itlb, iaddr_ok, r.i1pc_repl, r.i1.pc, "0", r.i1.ctx, r.i1.su, '0', '0',
                 mmu_enabled(r, r.i1.mode) and not r.i1.m,  -- Unused on RISC-V
                 r.i1ten, '0', ici.inull, r.i1rep, '0',
                 itlbchk, '0', '0', '0', '0', r.i1.mode,
                 '0', '0',
                 false
                 );
      -- With PMP/PMA in TLBs, the actual non-PT permissions check is done here.
      -- Needs to set .clr on failure, since new PT walk will be done!
      if is_riscv and walk_pmp and (r.i1.m = '1' or not mmu_enabled(r.i1.mode)) then
        itlbchk.paddr   := fit0ext(r.i1.pc, itlbchk.paddr);  -- qqq Needed?
        -- The busw/cached settings are overwritten below if PMA!
        if not pmaen then
          itlbchk.busw   := dec_wbmask_fixed(r.i1.pc(ahbo.haddr'high downto 2), wbmask);
          itlbchk.cached := ahb_slv_dec_cache(r.i1.pc(ahbo.haddr'range), ahbso, cached);
        end if;
        itlbchk.modded  := '1';
        if r.i1ten = '1' and ici.inull = '0' and r.i1rep = '0' then
        end if;
        if itlbchk.hit = '1' then           -- Actual mode below is only M or not M
          if smepmp_ok_x(ext_smepmp, csro.mml,
                         cond(r.i1.m = '1', PRIV_LVL_M, PRIV_LVL_S),
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
    if is_riscv and not walk_pmp then
      if r.i1.m = '0' and not actual_tlb_pmp then
        pmp.addr := get_lo(itlbchk.paddr, pa'length);
      else
        pmp.addr := get_lo(r.i1.pc, pa'length);
      end if;
      -- Machine, supervisor or user mode?
      if pmpen then
        pmp_unit(
                 cond(r.i1.m = '1', PRIV_LVL_M, cond(r.i1.su = '1', PRIV_LVL_S, PRIV_LVL_U)),
                 csro.precalc, csro.pmpcfg, csro.mmwp, csro.mml,
                '0', "00",
                 cond(r.i1.m = '0' and not actual_tlb_pmp,
                      get_lo(itlbchk.paddr, pa'length), get_lo(r.i1.pc, pa'length)),
                 PMP_ACCESS_X,
                 not ici.inull and r.holdn,
                 pmp_xc,
                 pmp_hit,
                 pmp_entries, pmp_no_tor, pmp_g, pmp_msb, ext_smepmp);
      end if;

      if pmaen then
        if pma_masked = 0 then
          pma_unit(csro.pma_precalc,
                   cond(r.i1.m = '0' and not actual_tlb_pmp,
                        get_lo(itlbchk.paddr, pa'length), get_lo(r.i1.pc, pa'length)),
                   not ici.inull and r.holdn,
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
                    cond(r.i1.m = '0' and not actual_tlb_pmp,
                         get_lo(itlbchk.paddr, pa'length), get_lo(r.i1.pc, pa'length)),
                    not ici.inull and r.holdn,
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

        if (not ici.inull and r.holdn) = '1' then
          -- Need to hit a PMA entry!
          if all_0(pma_hit) then
            pmp_xc := '1';
          elsif not pma_valid(pma) then
            pmp_xc := '1';
          else
            -- Overwrite settings from above (not in TLB here)
            if is_riscv and (r.i1.m = '1' or not mmu_enabled(r.i1.mode)) then
              itlbchk.busw   := pma_busw(pma);
              itlbchk.cached := pma_cache(pma);
            end if;
            if not pma_x(pma) then
              pmp_xc := '1';
            else
            end if;
          end if;
        end if;
      end if;

      if itlbchk.hit = '0' then
        pmp_xc := '0';
      end if;

      if actual_tlb_pmp and r.i1.m = '0' and
         mmu_enabled(r.i1.mode) then
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
    if is_riscv and not iaddr_ok then
      if itlbchk.hit = '1' then
        -- Signal page/access fault
        v.ifailkind := "1" & (r.i1.m or not to_bit(mmu_enabled(r.i1.mode)));
      end if;
    end if;


    -- "free running" TLB id register used in probe state
    v.itlbprobeid := itlbchk.id(v.itlbprobeid'range);


    -- Tag compare logic
    ihitv  := (others => '0');
    ihit   := '0';
    iway   := "00";
    ivalid := '0';
    for i in i_ways'range loop
      if cramo.itagdout(i)(TAG_HIGH - ITAG_LOW + 1 downto 1) = itlbchk.paddr(i_tag'range) and
         r.i1ten = '1' and itlbchk.hit = '1' then
        ihitv(i)      := '1';
        if ihit = '1' then
          oico.badtag := '1';
        end if;
        ihit          := '1';
        iway          := iway or u2vec(i, iway);
      end if;
      ivalidv(i)      := cramo.itagdout(i)(0);
    end loop;
    ivalid := ivalidv(u2i(iway));
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
    itcmhit          := '0';
    if itcmen /= 0 then
      if r.i1tcmen = '1' and tcmaddr_comp(r.i1.pc(31 downto 16), r.itcmaddr, itcmen, itcmabits) = '1' then
        itcmhit      := '1';
        ihit         := '1';
        ihitv        := (others => '0');
        iway         := "00";
        oico.data(0) := cramo.itcmdout;
        if r.holdn = '1' then
          if (r.itcmperm(0) = '0' and r.i1.su = '0') or (r.itcmperm(1) = '0' and r.i1.su = '1') then
            oico.mexc := '1';
          end if;
        end if;
      end if;
    end if;


    if r.i1rep = '1' then
      ihitv         := r.irep.hitv;
      ivalidv       := r.irep.validv;
      iway          := r.irep.way;
      ihit          := ihitv(u2i(iway));
      ivalid        := ivalidv(u2i(iway));
      ihit          := ihit and ivalid;
      oico.data     := r.irep.data;
      itlbchk.hit   := r.irep.tlbhit;
      itlbchk.paddr := fit0ext(r.irep.tlbpaddr, itlbchk.paddr);
      itlbchk.id    := fit0ext(r.irep.tlbid, itlbchk.id);
    end if;


    -- No hits are valid if *failkind, since
    if v.ifailkind(1) = '1' then
      itlbchk.hit := '0';
      ihit        := '0';
      ihitv       := (others => '0');
    end if;

    ibufaddrmatch := '0';
    -- If line fetch buffer filling, look for hit in it.
    if r.irdbufen = '1' and v.ifailkind(1) = '0' then
      ihit       := '0';
      -- Always fail instruction streaming from read buffer when told to by IU.
      if r.i1.pc(r.irdbufvaddr'range) = r.irdbufvaddr and r.i1.nostream = '0' then
        ibufaddrmatch := '1';
        if not ENDIAN_B then
          if r.ahb3.rdbvalid(LINESZMAX - 2 - 2 * u2i(r.i1.pc(log2(4 * ilinesize) - 1 downto 3))) = '1' then
            ihit := '1';
          end if;
        else
          if r.ahb3.rdbvalid(1 + 2 * u2i(r.i1.pc(log2(4 * ilinesize) - 1 downto 3))) = '1' then
            ihit := '1';
          end if;
        end if;
      end if;
    elsif r.i1cont = '1' and v.ifailkind(1) = '0' then
      ihitv    := r.i2hitv;
      ivalidv  := r.i2validv;
      itcmhit  := r.i2tcmhit;
      ihit     := orv(r.i2hitv) or r.i2tcmhit;
      ivalid   := orv(r.i2validv);
      iway     := (others => '0');
      for x in i_ways'range loop
        if ihitv(x) = '1' then
          iway := iway or u2vec(x, iway);
        end if;
      end loop;
    end if;

    oico.way             := (others => '0');
    oico.way(iway'range) := iway;
    if IMUXDATA then
      oico.data(0)       := oico.data(u2i(oico.way));
      oico.way           := (others => '0');
    end if;

    if r.imisspend = '1' and r.i2tcmhit = '0' then
      oico.mds := '0';
    end if;

    if r.irdbufen = '1' then
      -- Mux out buffer data
      oico.way           := (others => '0');
      for x in 0 to LINESZMAX / 2 - 1 loop
        if (r.imisspend = '1' and u2i(r.i2.pc(BUF_HIGH downto 3)) = x) or
           (r.imisspend = '0' and u2i(r.i1.pc(BUF_HIGH downto 3)) = x) then
          if not ENDIAN_B then
            oico.data(0) := get64(r.ahb3.rdbuf, (LINESZMAX / 2 - x) * 64 - 64);
          else
            oico.data(0) := get64(r.ahb3.rdbuf, x * 64);
          end if;
        end if;
        -- Allow for streaming from read data buffer

        if r.imisspend = '1' and r.i2bufmatch = '1' and u2i(r.i2.pc(BUF_HIGH downto 3)) = x then
          if not ENDIAN_B then
            if get(r.ahb3.rdbvalid, LINESZMAX - 2 * x - 2, 2) = "11" then
              v.imisspend := '0';
              v.perf(12)  := '1';
            end if;
          else
            if get(r.ahb3.rdbvalid, 2 * x, 2) = "11" then
              v.imisspend := '0';
              v.perf(12)  := '1';
            end if;
          end if;
        end if;
      end loop;
    end if;

    -- Main hit/miss checking logic (v.imisspend propagates to main FSM)
    -- Stage 2 ITLB update in case of hit
    d32 := r.i2.pc(d32'range);
    if ext_noelv = 1 and r.s = as_rdasi then
      d32 := r.d2vaddr(d32'range);
    end if;
    if notx(d32) then
      ilruent := r.ilru(u2i(d32(i_index'range)));
    else
      setx(ilruent);
    end if;
    if r.holdn = '1' then
      vway     := (others => '0');
      vhit     := '0';
      for x in r.i2hitv'range loop
        if r.i2hitv(x) = '1' then
          vhit := '1';
          vway := vway or u2vec(x, vway);
        end if;
      end loop;
      if vhit = '1' then
        v.ilru(u2i(r.i2.pc(i_index'range))) := calc_lruent(ilruent, vway, IWAYS);
      end if;
    end if;
    -- Stage 1 tag check (insn in fetch stage)
    v.i2tlbclr := '0';
    if r.holdn = '1' then
      v.ibpmiss       := '0';
    end if;
    if r.holdn = '1' then
      dbg(0)          <= '1';
      v.i2paddr       := itlbchk.paddr(v.i2paddr'range);
      v.i2paddrv      := itlbchk.hit;
      v.i2tlbhit      := itlbchk.hit;
      v.i2tlbid       := itlbchk.id(v.i2tlbid'range);
      v.i2tlbclr      := itlbchk.clr;
      v.i2busw        := itlbchk.busw;
      v.i2paddrc      := itlbchk.cached;
      v.i2            := r.i1;
      v.i2bufmatch    := ibufaddrmatch;
      v.i2tcmhit      := itcmhit;
      if r.irdbufen = '0' then
        v.i2validv    := ivalidv;
        v.i2hitv      := ihitv;
        v.irdbufvaddr := r.i1.pc(r.irdbufvaddr'range);
        v.irdbufpaddr := v.i2paddr(r.irdbufpaddr'range);
      end if;

      -- Set I$ miss pending?
      if ici.inull = '0' and ihit /= '1' then
        -- Miss under branch prediction allowed?
        if ici.nobpmiss = '0' then
          v.imisspend := '1';
        else
          v.ibpmiss   := '1';
        end if;
      end if;
      if r.i1rep = '0' then
        v.irep.hitv     := ihitv;
        v.irep.validv   := ivalidv;
        v.irep.way      := iway;
        v.irep.data     := cramo.idatadout;
        v.irep.tlbhit   := itlbchk.hit;
        v.irep.tlbpaddr := itlbchk.paddr(v.irep.tlbpaddr'range);
        v.irep.tlbid    := itlbchk.id(v.irep.tlbid'range);
      end if;
    end if;

    -- Stage 0 drive addresses (insn in pre-fetch stage)
    if r.holdn = '1' then
      -- NOTE: Assuming read-hold behavior
      v.i1ten := '0';
    end if;
    if (r.holdn = '1' or r.ramreload = '1') and icache_active(r) = '1' then
      ocrami.itagen  := (others => '1');
      ocrami.idataen := (others => '1');
      v.i1ten := '1';
    end if;
    itcmact := '0';
    if r.itcmenp  = '1' and r.mmctrl1.e = '0' then      itcmact := '1'; end if;
    if r.itcmenva = '1' and r.mmctrl1.e = '1' then      itcmact := '1'; end if;
    if r.itcmenvc = '1' and r.mmctrl1.e = '1' and
       (has_context and r.mmctrl1.ctx = r.itcmctx) then itcmact := '1'; end if;
    if r.holdn = '1' or r.ramreload = '1' then
      v.i1tcmen       := '0';
      if itcmact = '1' then
        ocrami.itcmen := '1';
        v.i1tcmen     := '1';
      end if;
    end if;

    icont := '0';
    if ici.rbranch = '0' and not all_1(ici.fpc(ILINE_HIGH downto ILINE_LOW)) then
      icont    := '1';
    end if;
    if r.i1ten = '0' and r.i1cont = '0' then
      icont    := '0';
    end if;
    if r.i1cont = '0' and ici.inull = '1' then
      icont    := '0';
    end if;
    if r.ramreload = '1' then
      icont    := '0';
      v.i1cont := '0';
    end if;
    if icont = '1' and (r.i1ten = '1' or r.i1cont = '1') then
      ocrami.itagen := (others => '0');
    end if;
    if icont = '1' and r.i1cont = '1' then
      ocrami.idataen(i_ways'range) := ocrami.idataen(i_ways'range) and r.i2hitv;
    end if;
    if icache_active(r) = '0' then
      icont    := '0';
    end if;
    if r.holdn = '1' then
      -- Integer pipeline not stalling itself?
      if ici.iustall = '0' then
        v.i1.pc       := ici.rpc(v.i1.pc'range);
        v.i1.nostream := ici.nostream;
        v.i1.su       := ici.su;
        v.i1.m        := '0';
        v.i1.mode     := (others => '0');
        if is_riscv then
          -- Machine, supervisor or user mode?
          v.i1.m      := ici.vms(1);
          v.i1.su     := ici.vms(0);
          -- Virtual or not?
          v.i1.mode   := get_mode(csro, ici.vms);
        end if;
        v.i1cont      := icont;
        v.i1.ctx      := mmu_ctx(r, csro, v.i1.mode);
      end if;
      v.i1rep         := ici.iustall;
    end if;
    if r.ramreload = '1' then
      v.i1rep         := '0';
    end if;


    -- Select input data for Icache

    --------------------------------------------------------------------------
    -- DCache logic
    --------------------------------------------------------------------------

    dctagsv := cramo.dtagcdout;
    if dtagconf > 0 then
      voffs := r.d1vaddr(d_index'range);
      if r.s = as_regflush then
        voffs := r.regflpipe(2).addr;
      end if;
      for w in d_ways'range loop
        if notx(voffs) then
          dctagsv(w)(0) := rs.validarr(u2i(voffs))(w);
        else
          setx(dctagsv(w)(0));
        end if;
      end loop;
    end if;

    -- DCache TLB lookup
    -- Note that this is for the previous (registered) access.

    dtlb_write   := dci.write;
    dtlb_lock    := dci.lock;
    if r.dtlbrecheck = '1' then
      dtlb_write := r.d2write;
      dtlb_lock  := r.d2lock;
    end if;

    if is_riscv and not walk_pmp and (r.d1.m = '1' or not mmu_enabled(r.d1.mode)) then
      -- From tlb_lookup and dummy TLB entry.
      dtlbchk        := tlbcheck_none;
      -- Some non-defaults to "fake" an MMU access
      dtlbchk.hit    := '1';
      dtlbchk.paddr  := fit0ext(r.d1vaddr, dtlbchk.paddr);
      -- The busw/cached settings are overwritten below if PMA (not in TLB here)!
      if not pmaen then
        dtlbchk.busw   := dec_wbmask_fixed(r.d1vaddr(ahbo.haddr'high downto 2), wbmask);
        dtlbchk.cached := ahb_slv_dec_cache(r.d1vaddr(ahbo.haddr'range), ahbso, cached);
      end if;
      dtlbchk.modded := '1';
      daddr_ok       := physical_ok(r.d1vaddr);
      if addr_check_mask(1) = '0' then
        daddr_ok     := true;
      end if;
    else
      if is_riscv then
        if walk_pmp and (r.d1.m = '1' or not mmu_enabled(r.d1.mode)) then
          daddr_ok     := physical_ok(r.d1vaddr);
          if addr_check_mask(1) = '0' then
            daddr_ok   := true;
          end if;
        else
          if hmmu_only(r.d1.mode) then
            daddr_ok   := gphysical_ok(r.d1vaddr);
          else
            daddr_ok   := virtual_ok(r.d1vaddr);
          end if;
          if addr_check_mask(0) = '0' then
            daddr_ok   := true;
          end if;
        end if;
      end if;
      -- Pass along actual rd1vaddr too, for LEON5 code equivalence.
      tlb_lookup("00", r.dtlb, daddr_ok, r.d1vaddr_repl, r.d1vaddr, dci.maddress,
                 mmu_ctx(r, csro, r.d1.mode), r.d1.su, dtlb_write, dtlb_lock,
                 mmu_enabled(r, r.d1.mode) and not r.d1.m,  -- Unused on RISC-V
                 r.d1chk,
                 r.d1specialasi, dci.nullify, '0', dci.dsuen,
                 dtlbchk, r.d1.sum, r.d1.mxr, r.d1.vmxr, r.d1.hx, r.d1.mode,
                 r.d1.ss, cond(not is_v(r.d1.mode),
                               csro.menvcfg_sse, csro.menvcfg_sse and csro.henvcfg_sse),
                 true
                 );
      -- With PMP/PMA in TLBs, the actual non-PT permissions check is done here.
      -- Needs to set .clr on failure, since new PT walk will be done!
      if is_riscv and walk_pmp and (r.d1.m = '1' or not mmu_enabled(r.d1.mode)) then
        dtlbchk.paddr  := fit0ext(r.d1vaddr, dtlbchk.paddr);
        -- The busw/cached settings are overwritten below if PMA (not in TLB here)!
        if not pmaen then
          dtlbchk.busw   := dec_wbmask_fixed(r.d1vaddr(ahbo.haddr'high downto 2), wbmask);
          dtlbchk.cached := ahb_slv_dec_cache(r.d1vaddr(ahbo.haddr'range), ahbso, cached);
        end if;
        dtlbchk.modded := '1';
        if dtlbchk.hit = '1' then             -- Actual mode below is only M or not M
          if (dtlb_write = '0' and smepmp_ok_r(ext_smepmp, csro.mml,
                                               cond(r.d1.m = '1', PRIV_LVL_M, PRIV_LVL_S),
                                               dtlbchk.pmp_none, dtlbchk.pmp_lock,
                                               dtlbchk.pmp_rwx) and
              (not pmaen or pma_r(dtlbchk.pma))) or
             (dtlb_write = '1' and smepmp_ok_w(ext_smepmp, csro.mml,
                                               cond(r.d1.m = '1', PRIV_LVL_M, PRIV_LVL_S),
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

    -- Shadow stack access without using (v)sPT causes fault,
    -- but does not touch TLB so it is safe to use *failkind.
    if is_riscv and ext_zicfiss = 1 and r.d1.ss = '1' then
      if r.d1.m = '1' then
        -- In M, only SSAMOSWAP can get here, and that throws store/AMO access fault
        -- Signal access fault
        v.dfailkind := "11";
        v.dmisspend := '1';
      else
        if not mmu_enabled(r.d1.mode) or hmmu_only(r.d1.mode) then
          -- If bare, store/AMO access fault
          -- Signal access fault
          v.dfailkind := "11";
          v.dmisspend := '1';
        end if;
      end if;
    end if;

    -- Note that this is for the previous (registered) access.
    -- Note that this is done in parallel with cache fetch (registered access).

    -- Tag compare logic
    dhitv             := (others => '0');
    dhit              := '0';
    dway              := (others => '0');
    dvalid            := '0';
    dvalidv           := (others => '0');
    for i in d_ways'range loop
      if dctagsv(i)(TAG_HIGH - DTAG_LOW + 1 downto 1) = dtlbchk.paddr(d_tag'range) and
         r.d1ten = '1' and dtlbchk.hit = '1' then
        dhitv(i)          := '1';
        if dhit = '1' then
          odco.badtag     := '1';
        end if;
        dhit              := '1';
        dway              := dway or u2vec(i, dway);
      end if;
      dvalidv(i)          := dctagsv(i)(0);
    end loop;
    dvalid := dvalidv(u2i(dway));
    -- Note: dhit is AND:ed with valid, but dhitv is _not_ AND:ed with validv
    -- If we miss due to valid bit being zero after a snoop hit we want
    -- r.d2hitv to be set to the way where we had the cache line, in order to
    -- avoid putting it in another way and getting two ways with idential tag.
    --   dhitv := dhitv and dvalidv;
    dhit := dhit and dvalid;

    -- Data TCM hit and muxing logic
    dtcmhit := '0';
    if dtcmen /= 0 then
      if r.d1tcmen = '1' and tcmaddr_comp(r.d1vaddr(31 downto 16), r.dtcmaddr, dtcmen, dtcmabits) = '1' then
        dtcmhit      := '1';
        dhit         := '1';
        dhitv        := (others => '0');
        dway         := (others => '0');
        odco.data(0) := cramo.dtcmdout;
        if r.holdn = '1' then
          if (dci.read  = '1' and r.d1.su = '0' and r.dtcmperm(0) = '0') or
             (dci.write = '1' and r.d1.su = '0' and r.dtcmperm(1) = '0') or
             (dci.read  = '1' and r.d1.su = '1' and r.dtcmperm(2) = '0') or
             (dci.write = '1' and r.d1.su = '1' and r.dtcmperm(3) = '0') then
            odco.mexc := '1';
          end if;
        end if;
      end if;
    end if;

    odco.way := uext(dway, odco.way);

    dspecialasi   := r.d1specialasi;
    dforcemiss    := r.d1forcemiss;
    if r.holdn = '0' then
      dspecialasi := r.d2specialasi;
      dforcemiss  := r.d2forcemiss;
    end if;

    dlock   := dci.lock;
    if r.holdn = '0' then
      dlock := r.d2lock;
    end if;

    -- PMP
    if is_riscv and not walk_pmp then
      pmp       := pmp_clear;      -- Ensure no latches!
      pmp_xc    := '0';
      pmp_hit   := (others => '0');
      pmp.acc   := PMP_ACCESS_R;
      if dtlb_write = '1' then
        pmp.acc := PMP_ACCESS_W;
      end if;
      -- Shadow stack instructions always check for writeability
      if ext_zicfiss = 1 and r.d1.ss = '1' then
        pmp.acc := PMP_ACCESS_W;
      end if;
      if r.d1.m = '0' and not actual_tlb_pmp then
        pmp.addr := fit0ext(dtlbchk.paddr, pmp.addr);
      else
        pmp.addr := fit0ext(r.d1vaddr, pmp.addr);
      end if;
      -- Only check if access now and it hit in the TLB (otherwise address is wrong).
      pmp.valid := r.d1chk and dtlbchk.hit and not dci.nullify and not dspecialasi;
      -- Also check if slow write with finished TLB lookup.
      if r.dtlbrecheck = '1' and r.d1ten = '1' and not actual_tlb_pmp then
        -- Also check if delayed access with finished TLB lookup.
        pmp.valid := pmp.valid or dtlbchk.hit;
        pmp.addr := fit0ext(dtlbchk.paddr, pmp.addr);
        if pmp.valid = '1' then
        end if;
      end if;

      -- Machine, supervisor or user mode?
      pmp.mprv    := '0';
      pmp.mpp     := (others => '0');

      -- The rest here should, hopefully, be possible to replace with common later.
      if pmpen then
        pmp_unit(
                 cond(r.d1.m = '1', PRIV_LVL_M, cond(r.d1.su = '1', PRIV_LVL_S, PRIV_LVL_U)),
                 csro.precalc, csro.pmpcfg, csro.mmwp, csro.mml,
                 pmp.mprv, pmp.mpp,
                 pmp.addr,
                 pmp.acc,
                 pmp.valid,
                 pmp_xc,
                 pmp_hit,
                 pmp_entries, pmp_no_tor, pmp_g, pmp_msb, ext_smepmp);
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
            if is_riscv and (r.d1.m = '1' or not mmu_enabled(r.d1.mode)) then
              dtlbchk.busw   := pma_busw(pma);
              dtlbchk.cached := pma_cache(pma);
            end if;
            if pmp.acc = PMP_ACCESS_R and not pma_r(pma) then
              pmp_xc := '1';
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
          end if;
        end if;
      end if;

      if actual_tlb_pmp and r.d1.m = '0' and mmu_enabled(r.d1.mode) then
        pmp_xc := '0';
      end if;

      if addr_check_mask(2) = '0' then
        pmp_xc := '0';
      end if;

      if pmp.valid = '1' and pmp_xc = '1' then
      elsif (r.d1.m = '1' or not actual_tlb_pmp) and pmp.valid = '1' then
      end if;
    end if;

    -- This is already true, but be more clear about it.
    if walk_pmp then
      pmp    := pmp_clear;
      pmp_xc := '0';
    end if;

    -- Hit/miss checking logic (v.dmisspend, v.dflushpend, fastwr propagates to main FSM)
    -- Stage 2 DTLB update in case of hit
    if notx(r.d2vaddr) then
      dlruent := r.dlru(u2i(r.d2vaddr(d_index'range)));
    else
      setx(dlruent);
    end if;
    if r.holdn = '1' then
      vway     := (others => '0');
      vhit     := '0';
      for x in r.d2hitv'range loop
        if r.d2hitv(x) = '1' then
          vhit := '1';
          vway := vway or u2vec(x, vway);
        end if;
      end loop;
      if vhit = '1' then
        v.dlru(u2i(r.d2vaddr(d_index'range))) := calc_lruent(dlruent, vway, DWAYS);
      end if;
    end if;

    -- Stage 1 tag check
    fastwr          := '0';
    dwriting        := '0';
    v.d2tlbclr      := '0';
    if r.holdn = '1' then
      v.d2hitv      := (others => '0');
      v.d2tlbhit    := '0';
      v.d2tlbamatch := '0';
      v.d2write     := '0';
      v.d2tcmhit    := '0';
    end if;


    -- Data access now?
    if r.d1chk = '1' and r.holdn = '1' then
      v.d2vaddr      := r.d1vaddr;
      v.d2data       := dci.edata;
      v.d2write      := dci.write and (not dci.nullify or dci.dsuen);
      v.d2paddr      := dtlbchk.paddr(v.d2paddr'range);
      v.d2paddrv     := dtlbchk.hit;
      v.d2tlbhit     := dtlbchk.hit;
      v.d2tlbclr     := dtlbchk.clr;
      v.d2tlbamatch  := dtlbchk.amatch;
      v.d2tlbid      := dtlbchk.id(v.d2tlbid'range);
      v.d2tlbmod     := dtlbchk.modded;
      v.d2hitv       := dhitv;
      v.d2validv     := dvalidv;
      v.d2size       := dci.size;
      v.d2busw       := dtlbchk.busw;
      v.d2lock       := dci.lock;
      v.d2           := r.d1;
      v.d2specialasi := r.d1specialasi;
      v.d2forcemiss  := r.d1forcemiss;
      v.d2stbuf(u2i(r.d2stbw)).addr      := v.d2paddr;
      v.d2stbuf(u2i(r.d2stbw)).size      := v.d2size;
      v.d2stbuf(u2i(r.d2stbw)).data      := v.d2data;
      v.d2stbuf(u2i(r.d2stbw)).snoopmask := (others => r.cctrl.dcs(0));
      v.d2specread   := dci.specread;
      v.d2nocache    := not dtlbchk.cached;
      v.d2tcmhit     := dtcmhit;

      if is_riscv and pmp.valid = '1' and not daddr_ok then
        -- Signal page/access fault
        v.dfailkind := "1" & (r.d1.m or not to_bit(mmu_enabled(r.d1.mode)));
        v.dmisspend := '1';
      elsif is_riscv and pmp.valid = '1' and pmp_xc = '1' then
        v.dfailkind := "11";
        v.dmisspend := '1';
      else
        -- Do not do any of this if we fail on PMP!

        -- Set dcmiss pending bit for load cache miss
        if (dci.nullify = '0' or dci.dsuen = '1') and
           not (dhit = '1' and dforcemiss = '0' and dspecialasi = '0' and dci.lock = '0') and
           dci.read = '1' and r.cbo.d1type(2) = '0' then
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

        -- Cache update for writes
        --   Generate ocrami.ddatawrite independently of dci.nullify to avoid
        --     nullify -> ddatawrite -> ddatain path via data loopback
        if dci.nullify = '0' and r.d1ten = '1' and dci.write = '1' and r.d1specialasi = '0' and
           r.amo.d1type(5) = '0' and r.cbo.d1type(2) = '0' then
          ocrami.ddataen(d_ways'range) := dhitv;
        end if;
        if dci.nullify = '0' and r.d1tcmen = '1' and dci.write = '1' and r.d1specialasi = '0' and r.cbo.d1type(2) = '0' then
          ocrami.dtcmen := dtcmhit;
        end if;
        if (r.d1ten = '1' or r.d1tcmen = '1') and dci.write = '1' and r.d1specialasi = '0' and
           r.amo.d1type(5) = '0' and r.cbo.d1type(2) = '0' then
          dwriting := '1';
          ocrami.ddatawrite := getdmask64(r.d1vaddr, dci.size, ENDIAN_B);
        end if;

        -- Store buffer update for writes
        if (dci.nullify = '0' or dci.dsuen = '1') and dci.write = '1' and dtcmhit = '0' and r.cbo.d1type(2) = '0' then
          dbg(1) <= '1';
          if v.d2paddrv = '1' and v.d2busw = '1' and v.d2tlbmod = '1' and
             -- Ready to do fast write?
             ((r.s = as_normal and r.ahb.hlock = '0') or r.s = as_store) and
             dspecialasi = '0' and dci.lock = '0' then
            -- Fast write path (TLB hit, modified set in PTE, wide bus, store buffer
            -- idle, and standard ASIs)
            fastwr := '1';
          else
            -- Slow write path (TLB miss, modified not set in PTE, narrow bus, store buffer
            -- busy, or special ASI)
            dbg(2)       <= '1';
            v.slowwrpend := '1';
          end if;
        end if;

        -- Set slowwrpend for CBO to handle MMU the same way
        if dci.nullify = '0' and r.cbo.d1type(2) = '1' then
          v.slowwrpend := '1';
        end if;

        if dci.dsuen = '1' and r.holdn = '1' then
          v.d2vaddr := dci.maddress(v.d2vaddr'range);
        end if;
      end if;
    end if;

    -- We need to check data PMP here if the TLB was just rechecked.
    if is_riscv and r.holdn = '0' and r.dtlbrecheck = '1' and r.d1ten = '1' and pmp.valid = '1' then
      if not daddr_ok then
        v.dfailkind := "1" & (r.d1.m or not to_bit(mmu_enabled(r.d1.mode)));
        v.dmisspend := '1';
      elsif pmp_xc = '1' then
        v.dfailkind := "11";
        v.dmisspend := '1';
      end if;
    end if;

    -- Stage 0 address to tag ram
    dtenall := ((r.holdn and dci.eenaddr) or (r.ramreload and r.d1chk));
    if dtenall = '1' and dcache_active(r) = '1' then
      ocrami.dtagcen   := (others => '1');
      if dwriting = '0' then
        ocrami.ddataen := (others => '1');
      end if;
    end if;
    dtcmact := '0';
    if r.dtcmenp  = '1' and r.mmctrl1.e = '0' then      dtcmact := '1'; end if;
    if r.dtcmenva = '1' and r.mmctrl1.e = '1' then      dtcmact := '1'; end if;
    if r.dtcmenvc = '1' and r.mmctrl1.e = '1' and
       (has_context and r.mmctrl1.ctx = r.dtcmctx) then dtcmact := '1'; end if;
    if dtenall = '1' and dtcmact = '1' and dwriting = '0' then
      ocrami.dtcmen := '1';
    end if;

    -- Force re-read in case of snoop hit to ensure updated valid bits propagate.
    if dtagconf = 0 then
      ocrami.dtagcen(d_ways'range) := ocrami.dtagcen(d_ways'range) or rs.s3hit;
    end if;
    if r.holdn = '1' then
      v.d1ten           := dci.eenaddr and dcache_active(r);
      v.d1tcmen         := dci.eenaddr and dtcmact;
      v.d1chk           := dci.eenaddr;
      v.d1vaddr         := dci.eaddress(v.d1vaddr'range);
      v.d1.asi          := dci.easi;
      v.d1.su           := v.d1.asi(0);
      v.d1forcemiss     := '0';
      v.d1specialasi    := '0';
      if v.d1.asi(7 downto 1) = "0000000" then
        v.d1forcemiss   := '1';
        v.d1.su         := '1';
      elsif v.d1.asi(4 downto 0) /= ASI_UDATA and v.d1.asi(4 downto 0) /= ASI_SDATA then
        v.d1specialasi  := '1';
      end if;
      v.d1.m     := '0';
      v.d1.sum   := '0';
      v.d1.mxr   := '0';
      v.d1.vmxr  := '0';
      v.d1.hx    := '0';
      v.d1.ss    := '0';
      v.d1.mode  := (others => '0');
      if is_riscv then
        v.d1.sum   := dci.sum;
        v.d1.mxr   := dci.mxr;
        v.d1.vmxr  := dci.vmxr;
        if ext_h = 1 then
          v.d1.hx  := dci.hx;
        end if;
        if ext_zicfiss = 1 then
          v.d1.ss  := dci.ss;
        end if;
        v.d1.m     := dci.vms(1);
        v.d1.su    := dci.vms(0);
        v.d1.mode  := get_mode(csro, dci.vms);
      end if;
    end if;

    -- Flushing from IU
    if r.holdn = '1' and dci.flush = '1' then
      v.iflushpend := '1';
      v.dflushpend := '1';
    end if;
    if is_riscv then
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
    if ext_zicbom /= 0 then
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
    if ext_a /= 0 then
      if r.holdn = '1' then
        -- AMO_LR
        if r.amo.d2type(5) = '1' and r.amo.d2type(1 downto 0) = "10" and r.d2paddrv = '1' then
          v.amo.addr     := r.d2paddr(v.amo.addr'range);
          v.amo.reserved := '1';
        end if;
      end if;
      -- Track regular store operation from this hart to not invalidate the reservation
      v.amo.store := r.amo.store(4 downto 1) & (r.ahb.htrans(1) and r.ahb.hwrite and
                                                r.granted and not r.amo.sc);
      v.amo.s4hit   := rs.s3hit;
      v.amo.s4tag   := rs.s3tag;
      v.amo.s4offs  := rs.s3offs;

      -- Reserved address write match
      if not all_0(rs.s1en) and r.amo.store(1) = '0' then
        if r.amo.addr(r.amo.addr'high downto d_tag'low) = rs.s1haddr(r.amo.addr'high downto d_tag'low) and
           r.amo.addr(d_index'range) = rs.s1haddr(d_index'range) then
          v.amo.reserved := '0';
        end if;
        -- Need to clear based of d2paddr when cache busy (holdn = 0) between
        -- lr and reserved being set
        if r.amo.d2type(5) = '1' and r.amo.d2type(1 downto 0) = "10" and r.d2paddrv = '1' then
          if r.d2paddr(rs.s1haddr'high downto d_tag'low) = rs.s1haddr(rs.s1haddr'high downto d_tag'low) and
             r.d2paddr(d_index'range) = rs.s1haddr(d_index'range) then
            v.amo.reserved := '0';
            v.amo.d2type   := (others => '0');
          end if;
        end if;
      end if;
      if not all_0(rs.s2en) and r.amo.store(2 + AMO_P) = '0' then
        -- Need to clear based of d2paddr and s2tag when snooping and lr happens simultaneously
        if r.amo.d2type(5) = '1' and r.amo.d2type(1 downto 0) = "10" and r.d2paddrv = '1' then
          if r.d2paddr(rs.s2tag'high downto d_tag'low) = rs.s2tag(rs.s2tag'high downto d_tag'low) and
             r.d2paddr(d_index'range) = rs.s2offs then
            v.amo.reserved := '0';
            v.amo.d2type   := (others => '0');
          end if;
        end if;
      end if;
      if not all_0(rs.s3hit) and r.amo.store(3 + AMO_P) = '0' then
        -- Need to clear based of d2paddr and s3tag when snooping and lr happens simultaneously
        if r.amo.d2type(5) = '1' and r.amo.d2type(1 downto 0) = "10" and r.d2paddrv = '1' then
          if r.d2paddr(rs.s3tag'high downto d_tag'low) = rs.s3tag(rs.s3tag'high downto d_tag'low) and
             r.d2paddr(d_index'range) = rs.s3offs then
            v.amo.reserved := '0';
            v.amo.d2type   := (others => '0');
          end if;
        end if;
      end if;
      if not all_0(r.amo.s4hit) and r.amo.store(4 + AMO_P) = '0' then
        -- Need to clear based of d2paddr and s4tag when snooping and lr happens simultaneously
        if r.amo.d2type(5) = '1' and r.amo.d2type(1 downto 0) = "10" and r.d2paddrv = '1' then
          if r.d2paddr(r.amo.s4tag'high downto d_tag'low) = r.amo.s4tag(rs.s3tag'high downto d_tag'low) and
             r.d2paddr(d_index'range) = r.amo.s4offs then
            v.amo.reserved := '0';
            v.amo.d2type   := (others => '0');
          end if;
        end if;
      end if;

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
    -- Grant status with ungated clock for the snooping
    if ahbi.hready = '1' then
      vs.sgranted := ahbi.hgrant(hindex);
    end if;

    -- Stage 4 virtual tag update commit (inside SRAM)
    -- Stage 3 virtual tag update to RAM
    ocrami.dtaguindex(d_sets'range) := rs.s3offs;
    ocrami.dtaguwrite(d_ways'range) := rs.s3hit or rs.s3read;
    for i in d_ways'range loop
      ocrami.dtagudin(i)(TAG_HIGH - DTAG_LOW + 1 downto 0) := rs.s3tag & rs.s3read(i);
      ocrami.dtagudin(i)(TAG_HIGH - DTAG_LOW + 1 downto TAG_HIGH - DTAG_LOW) :=
        rs.s3tagmsb(2 * i + 1 downto 2 * i);
    end loop;
    vvalidset   := rs.s3read;
    vvalidclr   := rs.s3hit;
    vvalididx   := rs.s3offs;
    vs.dlctr    := (others => '0');
    vs.raisereq := '0';
    -- Setup address and data inputs for diag access if no snoop tag update
    if all_0(rs.s3hit) and all_0(rs.s3read) then
      vvalididx := rs.dtaccidx;
    end if;
    if (dtagconf /= 0 or all_0(rs.s3hit)) and all_0(rs.s3read) and all_0(rs.s3flush) then
      ocrami.dtaguindex(d_sets'range) := rs.dtaccidx;
      for i in d_ways'range loop
        ocrami.dtagudin(i)(TAG_HIGH - DTAG_LOW + 1 downto 0) := r.dtagpipe(i)(TAG_HIGH - DTAG_LOW + 1 downto 0);
        if rs.dtacctagmod = '1' then
          ocrami.dtagudin(i)(TAG_HIGH - DTAG_LOW + 1 downto TAG_HIGH - DTAG_LOW) :=
            rs.dtacctagmsb(2 * i + 1 downto 2 * i);
          ocrami.dtagudin(i)(0) := rs.dtacctaglsb(i);
        end if;
      end loop;
    end if;
    -- Inject diagnostic tag writes during idle cycles
    if rs.dtwrite = '1' then
      if not all_1(rs.dlctr) then
        vs.dlctr           := uadd(rs.dlctr, 1);
      end if;
      if all_0(rs.s3hit) and all_0(rs.s3read) and all_0(rs.s3flush) then
        vs.dtwrite                      := '0';
        ocrami.dtaguwrite(d_ways'range) := rs.dtaccways;
        for w in d_ways'range loop
          if rs.dtaccways(w) = '1' then
            if ocrami.dtagudin(w)(0) = '0' then
              vvalidclr(w) := '1';
            else
              vvalidset(w) := '1';
            end if;
          end if;
        end loop;
      elsif all_1(rs.dlctr) then
        vs.raisereq        := '1';
      end if;
    end if;
    if notx(vvalididx) then
      vs.validarr(u2i(vvalididx)) :=
        (vs.validarr(u2i(vvalididx)) and (not vvalidclr)) or vvalidset;
    else
      if (not all_0(vvalidclr)) or (not all_0(vvalidset)) then
        for x in vs.validarr'range loop
          setx(vs.validarr(x));
        end loop;
      end if;
    end if;
    -- Stage 2 snoop tag compare
    vs.s3hit          := (others => '0');
    for i in d_ways'range loop
      if rs.s2en(i) = '1' then
        if cramo.dtagsdout(i)(TAG_HIGH - DTAG_LOW + 1 downto 1) = rs.s2tag then
          vs.s3hit(i) := '1';
        end if;
      end if;
    end loop;
    vs.s3hit    := vs.s3hit or rs.s2flush;
    vs.s3read   := (others => '0');
    vs.s3tag    := rs.s2tag;
    vs.s3read   := rs.s2read;
    vs.s3offs   := rs.s2offs;
    vs.s3tagmsb := rs.s2tagmsb;
    vs.s3flush  := rs.s2flush;
    -- Collect data for external read
    vs.strddone := '0';
    if rs.s2eread = '1' then
      vs.strddone := '1';
      for w in d_ways'range loop
        if rs.staccways(w) = '1' then
          vs.stacctag := cramo.dtagsdout(w)(TAG_HIGH - DTAG_LOW + 1 downto 1);
        end if;
      end loop;
    end if;
    -- Stage 1
    --  Send address to snoop to snoop tag RAM,
    --  or send address and data to update snoop tag.
    ocrami.dtagsindex(d_sets'range) := rs.s1haddr(d_index'range);
    ocrami.dtagsen(d_ways'range)    := rs.s1en;
    if rs.s1read = '1' then
      ocrami.dtagswrite             := '1';
      ocrami.dtagsen(d_ways'range)  := r.d2hitv;
    end if;
    for w in d_ways'range loop
      ocrami.dtagsdin(w)(TAG_HIGH - DTAG_LOW + 1 downto 1) := rs.s1haddr(d_tag'range);
      ocrami.dtagsdin(w)(TAG_HIGH - DTAG_LOW + 1 downto TAG_HIGH - DTAG_LOW) := rs.s1tagmsb(2 * w + 1 downto 2 * w);
    end loop;
    vs.s2en     := rs.s1en and not rs.s1flush;
    vs.s2tag    := rs.s1haddr(d_tag'range);
    vs.s2offs   := rs.s1haddr(d_index'range);
    vs.s2read   := (others => '0');
    if rs.s1read = '1' then
      vs.s2read := r.d2hitv;
    end if;
    vs.s2read   := vs.s2read and not rs.s1flush;
    vs.s2flush  := rs.s1flush;
    vs.s2tagmsb := rs.s1tagmsb;
    if not all_0(rs.s1flush) then
      ocrami.dtagsen(d_ways'range) := rs.s1flush;
      vs.s2read := (others => '0');
    end if;
    vs.s2eread  := '0';
    if all_0(rs.s1en) and rs.s1read = '0' and all_0(rs.s1flush) then
      ocrami.dtagsindex(d_sets'range) := rs.staccidx;
      for w in d_ways'range loop
        ocrami.dtagsdin(w)(TAG_HIGH - DTAG_LOW + 1 downto 1) := rs.stacctag;
      end loop;
      vs.s2offs := rs.staccidx;
      vs.s2tag  := rs.stacctag;
      for w in d_ways'range loop
        vs.s2tagmsb(2 * w + 1 downto 2 * w) := rs.stacctag(TAG_HIGH - DTAG_LOW + 1 downto TAG_HIGH - DTAG_LOW);
      end loop;
    end if;
    if rs.stwrite = '1' or rs.stread = '1' then
      if (not all_1(rs.dlctr)) and all_0(rs.s1flush) then
        vs.dlctr := uadd(rs.dlctr, 1);
      end if;
      -- Mux in diagnostic tag access if RAM is available this cycle
      if all_0(rs.s1en) and rs.s1read = '0' and all_0(rs.s1flush) then
        if rs.stwrite = '1' then
          vs.stwrite        :=  '0';
          ocrami.dtagsen(d_ways'range)    := rs.staccways;
          ocrami.dtagswrite               := '1';
          ocrami.dtagsindex(d_sets'range) := rs.staccidx;
        elsif rs.stread = '1' and rs.strdstarted = '0' then
          vs.s2eread        := '1';
          ocrami.dtagsen(d_ways'range) := rs.staccways;
          vs.strdstarted    := '1';
          ocrami.dtagsen    := (others => '1');
          ocrami.dtagswrite := '0';
        end if;
      elsif all_1(rs.dlctr) then
        vs.raisereq         := '1';
      end if;
    end if;
    if rs.strdstarted = '1' and rs.strddone = '1' then
      vs.stread      := '0';
      vs.strdstarted := '0';
    end if;
    -- AMBA error register handling
    if ahbsi.hready = '1' then
      if rs.s1htrans0 = '0' then
        vs.errburstfilt       := '0';
      end if;
      if ahbi.hresp = "01" then
        vs.errburstfilt       := '1';
        if rs.s1htrans0 = '0' or rs.errburstfilt = '0' then
          if r.ahb2.inacc = '1' then
            vs.ahberr         := '1';
            if rs.ahberr = '1' then
              vs.ahberrm      := '1';
            end if;
            if r.ahb2.ifetch = '1' then
              vs.ahberracc(0) := '1';
            end if;
            if r.ahb2.dacc = '1' and r.ahb2.hwrite = '0' then
              vs.ahberracc(1) := '1';
            end if;
            if r.ahb2.dacc = '1' and r.ahb2.hwrite = '1' then
              vs.ahberracc(2) := '1';
            end if;
            if r.ahb2.ifetch = '0' and r.ahb2.dacc = '0' and r.ahb.hwrite = '0' then
              vs.ahberracc(3) := '1';
            end if;
            if r.ahb2.ifetch = '0' and r.ahb2.dacc = '0' and r.ahb.hwrite = '1' then
              vs.ahberracc(4) := '1';
            end if;
          else
            vs.ahboerr        := '1';
            if rs.ahboerr = '1' then
              vs.ahboerrm     := '1';
            end if;
          end if;
        end if;
      end if;
    end if;
    if rs.ahberr = '0' then
      if r.ahb2.ifetch = '1' then
        vs.ahberrtype := "00";
      elsif r.ahb2.dacc = '1' then
        vs.ahberrtype := "01";
      else
        vs.ahberrtype := "10";
      end if;
    end if;
    if (vs.ahberr = '1' and rs.ahberr = '0') or (rs.ahberr = '0' and rs.ahboerr = '0') then
      vs.ahberrhaddr    := rs.s1haddr;
      vs.ahberrhwrite   := rs.s1hwrite;
      vs.ahberrhsize    := rs.s1hsize;
      vs.ahberrhmaster  := rs.s1hmaster;
    end if;
    -- Stage 0 get address from AHB bus
    vs.s1en         := (others => '0');
    vs.s1read       := '0';
    vs.s1flush      := (others => '0');
    if ahbsi.hready = '1' then
      vs.s1haddr    := ahbsi.haddr;
      vs.s1hwrite   := ahbsi.hwrite;
      vs.s1hsize    := ahbsi.hsize;
      vs.s1hmaster  := ahbsi.hmaster;
      vs.s1htrans0  := ahbsi.htrans(0);
    end if;
    if ahbsi.hready = '1' and ahbsi.htrans(1) = '1' and ahbsi.hwrite = '1' and r.cctrl.dsnoop = '1' then
      if rs.sgranted = '0' then
        vs.s1en     := (others => '1');
      else
        vs.s1en     := not r.ahb.snoopmask;
      end if;
    elsif ahbsi.hready = '1' and ahbsi.htrans = HTRANS_NONSEQ and ahbsi.hwrite = '0' and rs.sgranted = '1' then
      -- Note in first cycle of dcfetch we do not know which set will be used
      if r.s = as_dcfetch then
        vs.s1read   := '1';
      end if;
    end if;
    for x in d_ways'range loop
      vs.s1tagmsb(2 * x + 1 downto 2 * x) := vs.s1haddr(TAG_HIGH downto TAG_HIGH - 1);
    end loop;

    --------------------------------------------------------------------------
    -- MMU TLB update logic
    --------------------------------------------------------------------------

    -- TLB update
    if r.i2tlbclr = '1' then
      v.itlb(u2i(r.i2tlbid)).valid := '0';
    end if;
    if r.d2tlbclr = '1' then
      v.dtlb(u2i(r.d2tlbid)).valid := '0';
    end if;
    if r.h2tlbclr = '1' then
      v.htlb(u2i(r.h2tlbid)).valid := '0';
    end if;
    if r.tlbupdate = '1' then
      if is_access_i(r.mmusel) and r.i2tlbhit = '1' then
        v.itlb(u2i(r.i2tlbid))     := tlbent_mask(r.newent);
      end if;
      if not is_access_i(r.mmusel) and r.d2tlbhit = '1' then
        v.dtlb(u2i(r.d2tlbid))     := tlbent_mask(r.newent);
      end if;
    end if;
    if r.h2tlbupd = '1' then
      v.htlb(u2i(r.h2tlbid))       := tlbent_mask(r.hnewent);
    end if;

    v.h2tlbupd   := '0';
    v.tlbupdate  := '0';

    -- On RISC-V, it is not as simple as the MMU being enabled or not.
    -- Even when it is otherwise in use, machine mode will (normally)
    -- still be using physical addresses.

    -- Set default 1:1 mapping if MMU disabled
    if not is_riscv and mmu_enabled(r) = '0' then
      v.dtlb(0) := tlbent_defmap;
      v.itlb(0) := tlbent_defmap;
    end if;
    -- Clear valid bits on flush or MMU disable
    if r.tlbflush(0) = '1' or (not is_riscv and mmu_enabled(r) = '0') then
      for x in v.dtlb'range loop
        v.dtlb(x).valid := '0';
      end loop;
      for x in v.itlb'range loop
        v.itlb(x).valid := '0';
      end loop;
    end if;
    if is_riscv and ext_h = 1 and r.tlbflush(1) = '1' then
      for x in v.htlb'range loop
        v.htlb(x).valid := '0';
      end loop;
    end if;
    v.tlbflush := "00";

    if not is_riscv then
      -- Generate decoded access permissions for each TLB entry
      for x in v.dtlb'range loop
        vtmp3             := ft_acc_resolve("000", r.dtlb(x).acc);
        v.dtlb(x).perm(0) := not vtmp3(1);       -- user load
        vtmp3             := ft_acc_resolve("100", r.dtlb(x).acc);
        v.dtlb(x).perm(1) := not vtmp3(1);       -- user store
        vtmp3             := ft_acc_resolve("001", r.dtlb(x).acc);
        v.dtlb(x).perm(2) := not vtmp3(1);       -- supervisor load/execute
        vtmp3             := ft_acc_resolve("101", r.dtlb(x).acc);
        v.dtlb(x).perm(3) := not vtmp3(1);       -- supervisor store
      end loop;
      for x in v.itlb'range loop
        vtmp3             := ft_acc_resolve("010", r.itlb(x).acc);
        v.itlb(x).perm(0) := not vtmp3(1);       -- user execute
        v.itlb(x).perm(1) := '0';
        vtmp3             := ft_acc_resolve("011", r.itlb(x).acc);
        v.itlb(x).perm(2) := not vtmp3(1);       -- supervisor execute
        v.itlb(x).perm(3) := '0';
      end loop;
    end if;

    -- TLB replacement strategy
    -- *tlbpmru is a vector with a bit per TLB entry.
    -- Set corresponding bit on TLB hit.
    -- Clear any bits corresponding to invalid TLB entries.
    -- Once all bits are set, start over with cleared vector.
    --
    -- When needed, replace highest numbered unset entry.

    -- Set pseudo-MRU bit for touched entry
    if r.d2tlbhit = '1' and r.holdn = '1' and r.d2specialasi = '0' then
      v.dtlbpmru(u2i(r.d2tlbid)) := '1';
    end if;
    if r.i2tlbhit = '1' and r.holdn = '1' then
      v.itlbpmru(u2i(r.i2tlbid)) := '1';
    end if;
    if r.h2tlbupd = '1' then
      v.htlbpmru(u2i(r.h2tlbid)) := '1';
    end if;
    -- Reset pseudo-MRU once all bits set
    --   single-cycle window where all are set need to be handled
    if all_1(r.dtlbpmru) then
      v.dtlbpmru := (others => '0');
    end if;
    if all_1(r.itlbpmru) then
      v.itlbpmru := (others => '0');
    end if;
    if all_1(r.htlbpmru) then
      v.htlbpmru := (others => '0');
    end if;
    -- Clear pseudo-MRU bits for TLB entries that are not valid
    --  (using v.valid to avoid single-cycle window)
    for x in v.dtlb'range loop
      if v.dtlb(x).valid = '0' then
        v.dtlbpmru(x) := '0';
      end if;
    end loop;
    for x in v.itlb'range loop
      if v.itlb(x).valid = '0' then
        v.itlbpmru(x) := '0';
      end if;
    end loop;
    for x in v.htlb'range loop
      if v.htlb(x).valid = '0' then
        v.htlbpmru(x) := '0';
      end if;
    end loop;

    if not is_riscv then
      -- MMU fault status register handling
      if r.mmuerr.fav = '1' then
        if r.mmfsr.fav = '0' or unsigned(r.newerrclass) > unsigned(r.curerrclass) then
          v.mmfsr       := r.mmuerr;
          v.mmfar       := r.newent.vaddr(v.mmfar'range);
          v.curerrclass := r.newerrclass;
        elsif r.mmfsr.fav = '1' and r.newerrclass = r.curerrclass then
          -- Overwrite with the new error and set overwrite flag.
          v.mmfsr       := r.mmuerr;
          v.mmfar       := r.newent.vaddr(v.mmfar'range);
          v.mmfsr.ow    := '1';
        end if;
      end if;
      v.mmuerr.fav      := '0';
      v.mmuerr.ow       := '0';
      v.mmuerr.ebe      := (others => '0');
    end if;


    ---------------------------------------------------------------------------
    -- Region flush
    ---------------------------------------------------------------------------

    v.regflpipe(0 to r.regflpipe'high - 1) := r.regflpipe(1 to r.regflpipe'high);
    v.regflpipe(r.regflpipe'high).valid    := '0';
    v.regflpipe(r.regflpipe'high).addr     := r.flushctr;

    -- Stage 4: Write back commit
    --   inside SRAMs
    -- Stage 3: Command write back in case of match
    --  handled in FSM
    -- Stage 2: Compare with region flush mask
    v.regflpipe(0)  := r.regflpipe(1);
    frdmatch        := (others => '0');
    for x in d_ways'range loop
      if (r.dtagpipe(x)(TAG_HIGH - DTAG_LOW + 1 downto 1) and r.regflmask(d_tag'range))
           = r.regfladdr(d_tag'range) then
        frdmatch(x) := '1';
      end if;
    end loop;
    v.flushwrd      := frdmatch;
    frimatch        := (others => '0');
    for x in i_ways'range loop
      if (r.itagpipe(x)(TAG_HIGH - ITAG_LOW + 1 downto 1) and r.regflmask(i_tag'range))
           = r.regfladdr(i_tag'range) then
        frimatch(x) := '1';
      end if;
    end loop;
    v.flushwri := frimatch;
    -- Compute unique msb:s for the tags we are replacing to avoid duplicate tags
    for x in d_ways'range loop
      frmsbd(2 * x + 1 downto 2 * x) := r.dtagpipe(x)(TAG_HIGH - DTAG_LOW + 1 downto TAG_HIGH - DTAG_LOW);
    end loop;
    v.untagd := uniquemsb(frmsbd, frdmatch);
    for x in i_ways'range loop
      frmsbi(2 * x + 1 downto 2 * x) := r.itagpipe(x)(TAG_HIGH - ITAG_LOW + 1 downto TAG_HIGH - ITAG_LOW);
    end loop;
    v.untagi := uniquemsb(frmsbi, frimatch);

    -- Stage 1: Capture tags
    v.regflpipe(1) := r.regflpipe(2);
    v.dtagpipe     := dctagsv;
    v.itagpipe     := cramo.itagdout;

    -- Stage 0: Read from tag RAMs, done in main FSM


    --------------------------------------------------------------------------
    -- AHB access state machine
    --------------------------------------------------------------------------
    if ahbi.hready = '1' then
      -- This captures granted with the gated CPU clock.
      -- Powerdown state ensures this is synced up when starting
      -- up the clock again before any AHB accesses are done.
      v.granted := ahbi.hgrant(hindex);
    end if;
    -- Flag set by FSM to indicate next cycles access is not the last so hbusreq
    -- should be kept high
    keepreq := '0';

    if r.dcerrmask = '1' or r.ahb2.ifetch = '1' then
      for x in LINESZMAX - 1 downto 0 loop
        if r.ahb3.rdberr(x) = '1' then
          v.ahb3.rdbuf((x + 1) * 32 - 1 downto x * 32) := (others => (r.dcerrmaskval and not r.ahb2.ifetch));
        end if;
      end loop;
    end if;
    -- Read data buffer pipeline, advance with AHB hready
    v.werr                := '0';
    if ahbi.hready = '1' then
      dbg(3)              <= '1';
      v.ahb3.inacc := r.ahb2.inacc;
      -- Reading?
      if r.ahb2.inacc = '1' and r.ahb2.hwrite = '0' then
        dbg(4)            <= '1';
        if ahbi.hresp = HRESP_ERROR then
          v.ahb3.error    := '1';
        end if;
        for x in LINESZMAX - 1 downto 0 loop
          if r.ahb2.addrmask(x) = '1' then
            set(v.ahb3.rdbuf, x * 32, get(ahbi.hrdata, (x * 32) mod busw, 32));
          end if;
        end loop;
        -- Allow both OK and ERROR, to not hang the cache in as_dcfetch.
        if ahbi.hresp(1) = '0' then
          dbg(5)          <= '1';
          v.ahb3.rdbvalid := v.ahb3.rdbvalid or r.ahb2.addrmask;
        end if;
      end if;
      if r.ahb2.inacc = '1' and r.ahb2.hwrite = '1' then
        if ahbi.hresp = HRESP_ERROR then
          v.werr          := '1';
        end if;
      end if;
      v.ahb2.inacc        := r.granted and r.ahb.htrans(1);
      v.ahb2.hwrite       := r.ahb.hwrite;
      v.ahb2.addrmask     := getvalidmask(r.ahb.haddr(4 downto 2), r.ahb.hsize, ENDIAN_B);
      v.ahb2.ifetch       := '0';
      if r.s = as_icfetch then
        v.ahb2.ifetch     := '1';
      end if;
      v.ahb2.dacc         := '0';
      if r.s = as_store or r.s = as_dcfetch or r.s = as_dcsingle or r.s = as_wrburst then
        v.ahb2.dacc       := '1';
      end if;
    end if;
    v.ahb3.rdbvalid       := v.ahb3.rdbvalid or r.ahb3.rdberr;
    -- Set rdberr during first cycle of response, to get another cycle to clear
    -- ahb3_rdbuf if needed (to simplify logic both cycles of error response).
    -- We also clear ahb2_addrmask during the first cycle of the response, to
    -- allow the assignment of hrdata to ahb3_rdbuf to be muxed in last without
    -- any extra masking logic needed afterwards.
    if ahbi.hready = '0' and ahbi.hresp = "01" and (r.dcerrmask = '1' or r.ahb2.ifetch = '1') then
      v.ahb2.addrmask     := (others => '0');
    end if;
    if ahbi.hresp = "01" and r.ahb2.inacc = '1' and r.ahb2.hwrite = '0' then
      v.ahb3.rdberr       := v.ahb3.rdberr or r.ahb2.addrmask;
    end if;

    -- Read data from 32/64 bit single reads
    rdb64        := (others => '0');
    rdb32v       := '0';
    if pte_hsize = HSIZE_WORD then
      for x in r.ahb3.rdbvalid'range loop
        if r.ahb3.rdbvalid(x) = '1' then
          rdb32v := '1';
          rdb32  := rdb32 or get(r.ahb3.rdbuf, x * 32, 32);
        end if;
      end loop;
    else
      for x in r.ahb3.rdbvalid'length / 2 - 1 downto 0 loop
        if get(r.ahb3.rdbvalid, x * 2, 2) = "11" then
          rdb32v := '1';
          rdb64v := '1';
          rdb64  := rdb64 or get64(r.ahb3.rdbuf, x * 64);
        end if;
      end loop;
    end if;


    -- Speculative load handling
    if r.dmisspend = '1' and r.d2specread = '1' then
      if dci.specreadannul = '1' then
        v.dmisspend  := '0';
        v.dfailkind  := "00";
      else
        v.d2specread := '0';
      end if;
    end if;

    -- memory barrier
    if dci.bar(1 downto 0) /= "00" and r.holdn='1' then
      -- for now the store/load barrier is implemented as a full synchronizing
      -- barrier for simplicity. This case may be optimized later.
      v.syncbar := '1';
    end if;

    -- Do this above FSM as it may set ramreload
    if r.imisspend = '0' and r.dmisspend  = '0' and r.slowwrpend = '0' and
       r.iflushpend = '0' and r.dflushpend = '0' and r.ramreload  = '1' then
      v.ramreload := '0';
    end if;

    v.newent.valid      := '1';
    if ext_h = 1 then
      v.hnewent.valid   := '1';
     end if;
    v.dtlbrecheck       := '0';
    v.fpc_mosi.accen    := '0';
    v.fpc_mosi.accwr    := '0';
    v.fpc_mosi.addr(v.fpc_mosi.addr'high downto 1)       := r.d2vaddr(v.fpc_mosi.addr'high + 2 downto 3);
    v.c2c_mosi.accen    := '0';
    v.c2c_mosi.accwr    := '0';
    v.c2c_mosi.addr(v.c2c_mosi.addr'high downto 1)       := r.d2vaddr(v.c2c_mosi.addr'high + 2 downto 3);
    v.iudiag_mosi.accen := '0';
    v.iudiag_mosi.accwr := '0';
    v.iudiag_mosi.addr(v.iudiag_mosi.addr'high downto 1) := r.d2vaddr(v.iudiag_mosi.addr'high + 2 downto 3);

    if is_riscv and actual_tlb_pmp then
      pmp_mmuu(csro.precalc(0 to pmp_entries - 1),
               csro.pmpcfg, csro.mml,
               r.pmp_low, r.pmp_mask, r.pmp_do,
               pmp_hit, pmp_fit, pmp_l, pmp_r, pmp_w, pmp_x,
               pmp_msb, ext_smepmp);

      -- Keep only the lowest numbered hit, since that is
      -- defined as the highest priority PMP.
      pmp_prio := pmp_hit and std_logic_vector(-signed(pmp_hit));

      -- Hit but not fit means a smaller MMU page size must be tried!

      if r.pmp_do = '1' then
        v.pmp_hitv := pmp_hit;  -- For diagnostics
        v.pmp_fitv := pmp_fit;  -- For diagnostics
        if pmp_mmuu_test = 1 then
--          v.pmp_idx := uext(clz(uext(reverse(pmp_hit), 16)), v.pmp_idx);
          v.pmp_idx := uext(clz(reverse(uext(pmp_hit, PMPENTRIES))), v.pmp_idx);
        end if;
        v.pmp_hit := not all_0(pmp_hit);
        v.pmp_fit := not all_0(pmp_prio and pmp_fit);
        v.pmp_rwx(2) := not all_0(pmp_r and pmp_prio);
        v.pmp_rwx(1) := not all_0(pmp_w and pmp_prio);
        v.pmp_rwx(0) := not all_0(pmp_x and pmp_prio);
        v.pmp_none   := not v.pmp_hit;
        v.pmp_lock   := not all_0(pmp_l and pmp_prio);

        -- Fault masking
        if is_access_i(r.mmusel) then  -- Instruction fetch
          if addr_check_mask(3) = '0' then
            pmp_hit    := (others => '1');
            v.pmp_hit  := '1';
            v.pmp_fit  := '1';
            v.pmp_rwx  := "111";
          end if;
        else                           -- Data read/write?
          if addr_check_mask(7) = '0' then
            pmp_hit    := (others => '1');
            v.pmp_hit  := '1';
            v.pmp_fit  := '1';
            v.pmp_rwx  := "111";
          end if;
        end if;
        -- Ensure no hit if physical top address bits are wrong
        if not physical_ok(r.pmp_low) and addr_check_mask(1) = '1' then
          pmp_hit    := (others => '0');
          v.pmp_hit  := '0';
          v.pmp_fit  := '0';
          v.pmp_rwx  := "000";
        end if;
      end if;

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
--            if get_left(get_right(r.pmp_low, 32), 4) /=
--               get_left(get_right(r.pmp_low or not r.pmp_mask, 32), 4) then
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

        -- Hit but not fit means a smaller MMU page size must be tried!

        if r.pmp_do = '1' then
          if pma_masked = 0 then
--            pma_idx     := uext(clz(uext(reverse(pma_hit), 16)), v.pma_idx);
            pma_idx     := fit0ext(clz(reverse(uext(pma_hit, PMAENTRIES))), pma_idx);

            pma := to_pma(csro.pma_data(u2i(pma_idx)));
          end if;

          -- Ensure no hit if physical top address bits are wrong
          if not physical_ok(r.pmp_low) and addr_check_mask(1) = '1' then
            pma_hit    := (others => '0');
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


          -- No need to update v.pma* here
          -- PMP test (pmp_mmuu_test) can bypass this
          if r.pmp_only = '0' then
            if v.pma_hit = '0' then
              v.pmp_hit  := '0';
              v.pmp_fit  := '0';
              v.pmp_rwx  := "000";
            end if;
            if v.pma_fit = '0' then
              v.pmp_fit  := '0';
              v.pmp_rwx  := "000";
            end if;
            if not pma_valid(pma) then
              v.pmp_rwx  := "000";
            end if;
          end if;

          -- Calculate current PMP+PMA access rights
          v.pmp_m_rwx(2)  := to_bit(smepmp_ok_r(ext_smepmp, csro.mml, PRIV_LVL_M,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));
          v.pmp_m_rwx(1)  := to_bit(smepmp_ok_w(ext_smepmp, csro.mml, PRIV_LVL_M,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));
          v.pmp_m_rwx(0)  := to_bit(smepmp_ok_x(ext_smepmp, csro.mml, PRIV_LVL_M,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));

          -- The mode here is non-M (U vs S makes no difference for PMP)
          v.pmp_su_rwx(2) := to_bit(smepmp_ok_r(ext_smepmp, csro.mml, PRIV_LVL_S,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));
          v.pmp_su_rwx(1) := to_bit(smepmp_ok_w(ext_smepmp, csro.mml, PRIV_LVL_S,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));
          v.pmp_su_rwx(0) := to_bit(smepmp_ok_x(ext_smepmp, csro.mml, PRIV_LVL_S,
                                                v.pmp_none, v.pmp_lock, v.pmp_rwx));

          -- Combine with current PMA?
          if r.pmp_only = '0' then
            v.pmp_m_rwx     := v.pmp_m_rwx  and pma_rwx(pma);
            v.pmp_su_rwx    := v.pmp_su_rwx and pma_rwx(pma);
          end if;

        end if;
      else
        -- Calculate current PMP+PMA access rights
        v.pmp_m_rwx(2)  := to_bit(smepmp_ok_r(ext_smepmp, csro.mml, PRIV_LVL_M,
                                              v.pmp_none, v.pmp_lock, v.pmp_rwx));
        v.pmp_m_rwx(1)  := to_bit(smepmp_ok_w(ext_smepmp, csro.mml, PRIV_LVL_M,
                                              v.pmp_none, v.pmp_lock, v.pmp_rwx));
        v.pmp_m_rwx(0)  := to_bit(smepmp_ok_x(ext_smepmp, csro.mml, PRIV_LVL_M,
                                              v.pmp_none, v.pmp_lock, v.pmp_rwx));

        -- The mode here is non-M (U vs S makes no difference for PMP)
        v.pmp_su_rwx(2) := to_bit(smepmp_ok_r(ext_smepmp, csro.mml, PRIV_LVL_S,
                                              v.pmp_none, v.pmp_lock, v.pmp_rwx));
        v.pmp_su_rwx(1) := to_bit(smepmp_ok_w(ext_smepmp, csro.mml, PRIV_LVL_S,
                                              v.pmp_none, v.pmp_lock, v.pmp_rwx));
        v.pmp_su_rwx(0) := to_bit(smepmp_ok_x(ext_smepmp, csro.mml, PRIV_LVL_S,
                                              v.pmp_none, v.pmp_lock, v.pmp_rwx));
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

    v.h2tlbclr := '0';
    htlbchk := tlbcheck_none;
    if ext_h = 1 and r.h_do = '1' then
      tlb_lookup('1' & r.h_x, r.htlb, true, r.h_addr_repl, r.h_addr, "0", mmu_ctx(r, csro), '0', r.h_ls, '0',
                 to_bit(ext_h),  -- Unused on RISC-V
                 r.h_do, '0', '0', '0', '0',
                 htlbchk, '0', r.h_mxr, r.h_vmxr, r.h_hx, "010",
                 '0', '0',
                 true
                 );
      -- These may be needed later.
      v.h_w        := htlbchk.h_w;
      v.h_pmp_no_w := htlbchk.h_pmp_no_w;
      v.h_pmp_no_x := htlbchk.h_pmp_no_x;
      v.h2tlbclr   := htlbchk.clr;
      v.h2tlbid    := htlbchk.id(v.h2tlbid'range);
    end if;
    v.h_do := '0';

    case r.s is
      when as_normal =>
        -- PMP setup for TLB lookup OK and cached data read is already done above.
        v.ahb.htrans    := HTRANS_IDLE;
        v.ahb.hwrite    := '0';
        v.ahb.hburst    := HBURST_INCR;
        v.ahb.snoopmask := (others => '0');
        if dcache_active(r) = '1' and dforcemiss = '0' then
          v.ahb.snoopmask := (others => '1');
        end if;
        v.ahb3.error    := '0';
        v.ahb3.rdbvalid := (others => '0');
        v.ahb3.rdberr   := (others => '0');
        v.mmusel        := access_i;
        v.flushctr      := (others => '0');
        v.flushpart     := v.iflushpend & v.dflushpend;
        v.dtflushdone   := '0';
        v.regfldone     := '0';
        v.iramaddr      := (others => '0');
        v.irdbufen      := '0';
        v.dramaddr      := (others => '0');
        v.dvtagdone     := '0';
        v.dregerr       := '0';
        v.newent.mask   := (others => '0');
        v.d2stbw        := "00";
        v.d2stba        := "00";
        v.d2stbd        := "00";
        v.stbuffull     := '0';
        -- Release lock?
        if r.ahb.hlock = '1' and dlock = '0' then
          v.ahb.hlock   := '0';
        -- Normal write?
        elsif fastwr = '1' then
          v.ahb.htrans    := HTRANS_NONSEQ;
          v.ahb.hburst    := HBURST_SINGLE;
          v.ahb.haddr     := v.d2paddr(v.ahb.haddr'range);
          v.ahb.hsize     := "0" & v.d2size;
          v.ahb.hwrite    := '1';
          v.d2stbw        := r.d2stbw + 1;
          do_access       := true;
          v.s := as_store;
        -- I$/D$ flush?
        elsif ( ((not IMISSPIPE) and v.iflushpend = '1') or (IMISSPIPE and r.iflushpend = '1') or
                ((not DMISSPIPE) and v.dflushpend = '1') or (DMISSPIPE and r.dflushpend = '1') ) then
          -- GRLIB_INTERNAL_BEGIN
          -- qqq it looks like we can never end up here (as_regflush)
          -- GRLIB_INTERNAL_END
          if r.iregflush = '1' or r.dregflush = '1' then
            v.s         := as_regflush;
            v.flushpart := r.iregflush & r.dregflush;
            v.flushctr  := r.regfladdr(d_index'range) and
                           r.regflmask(d_index'range);
          else
            v.s         := as_flush;
          end if;
          v.perf(4) := '1';
        -- Instruction fetch on I$ miss?
        elsif (((not IMISSPIPE) and v.imisspend = '1') or (IMISSPIPE and r.imisspend = '1')) then
          v.ahb.haddr   := v.i2paddr(v.ahb.haddr'range);
          v.ahb.haddr(i_line'range) := (others => '0');
          v.ahb.hsize   := u2vec(log2(busw / 8), v.ahb.hsize);
          v.mmusel      := access_i;
          if v.i2busw = '0' then   -- 32 bit bus?
            v.ahb.hsize := HSIZE_WORD;
          end if;
          -- Fault on (non-TLB) PMP/PMA or high bits?
          if is_riscv and v.ifailkind(1) = '1' then
            v.s           := as_ifailkind;
          -- TLB hit and permissions OK?
          elsif v.i2paddrv = '1' then
            v.ahb.htrans  := HTRANS_NONSEQ;
            do_icfetch    := true;
            v.s           := as_icfetch;
            keepreq       := '1';
            v.perf(0)     := '1';
          -- Both TLB misses and permission fails go here!
          elsif mmuen = 1 or walk_pmp then
            if walk_pmp and not mmu_enabled(v.i2.mode) then
              start_pmp     := true;   -- See more after case.
            else
              -- This will never happen without MMU enabled.
              start_walk    := true;   -- See more after case.
--              v.s           := as_start_walk;
              if not is_riscv then
                v.ahb.haddr := r.mmctrl1.ctxp(25 downto 4) & v.i2.ctx & "00";
              end if;
              v.perf(1)     := '1';
            end if;
          end if;
        -- Data fetch on D$ miss, and not speculative?
        elsif (((not DMISSPIPE) and v.dmisspend = '1') or (DMISSPIPE and r.dmisspend = '1')) and v.d2specread = '0' then
          v.ahb.haddr     := v.d2paddr(v.ahb.haddr'range);
          v.ahb.hsize     := "000";
          v.mmusel        := access_r;
          -- Lock change?
          if v.d2lock /= r.ahb.hlock then
            v.s           := as_getlock;
            v.ahb.hlock   := not r.ahb.hlock;
            if r.ahb.hlock = '0' then
              v.granted   := '0';
            end if;
          -- Fault on (non-TLB) PMP/PMA or high bits?
          elsif is_riscv and v.dfailkind(1) = '1' then
            v.s := as_dfailkind;
          -- TLB hit and permissions OK?
          elsif v.d2paddrv = '1' and dspecialasi = '0' then
            if v.d2busw = '1' then     -- Burst if wide bus.
              if v.d2nocache = '0' then
                v.ahb.hsize := u2vec(log2(busw / 8), v.ahb.hsize);
                v.ahb.haddr(log2(busw / 8) - 1 downto 0) := (others => '0');
              else -- Use access size and offset when area is uncached
                v.ahb.hsize := "0" & v.d2size;
              end if;
            else
              v.ahb.hsize   := "010";
              v.ahb.haddr(1 downto 0) := "00";
            end if;
            do_access       := true;
            if v.d2nocache = '0' then
              v.ahb.htrans  := HTRANS_NONSEQ;
              v.s           := as_dcfetch;
              keepreq       := '1';
              v.ahb.haddr(d_line'range) := (others => '0');
              v.perf(2)     := '1';
            else                       -- Single accesses on 32 bit bus.
              v.ahb.htrans  := HTRANS_NONSEQ;
              v.ahb.hbusreq := '1';
              v.ahb.hburst  := HBURST_SINGLE;
              v.s           := as_dcsingle;
            end if;
          -- Both TLB misses and permission fails go here!
          elsif (mmuen = 1 or walk_pmp) and dspecialasi = '0' then
            if walk_pmp and not mmu_enabled(v.d2.mode) then
              start_pmp     := true;   -- See more after case.
            else
              -- This will never happen without MMU enabled.
              if not is_riscv then
                v.ahb.haddr := mmu_base(r, csro);
              end if;
              start_walk    := true;   -- See more after case.
--              v.s           := as_start_walk;
              v.perf(3)     := '1';
            end if;
          -- Special reads
          elsif ext_noelv = 1 then
            -- This will never happen without ext_noelv,
            -- since only write-ASI is then used (0x0a / 0x1b).
            v.s := as_rdasi;
          end if;
        -- Non-fast write?
        elsif v.slowwrpend = '1' then
          if (v.amo.d2type(5) = '0' or ext_a = 0) and (v.cbo.d2type(2) = '0' or ext_zicbom = 0) then
            v.s := as_slowwr;
          elsif v.cbo.d2type(2) = '1' then
            v.s := as_cbo;
          else
            -- Lock change?
            if v.d2lock /= r.ahb.hlock then
              v.s           := as_getlock;
              v.ahb.hlock   := not r.ahb.hlock;
              if r.ahb.hlock = '0' then
                v.granted   := '0';
              end if;
            else
              -- Atomic instruction (SC or AMO)
              v.s := as_amo;
            end if;
          end if;
        --elsif v.cbo.d2type(2) = '1' then
        --  v.s := as_cbo;
        elsif v.syncbar = '1' then
          v.syncbar := '0';
          if r.d1chk = '1' then v.ramreload := '1'; end if;
        elsif ici.parkreq = '1' then
          v.s := as_parked;
        end if;

      -- Delayed handling for symmetry with as_dfailkind below.
      when as_ifailkind =>
        v.imisspend := '0';
        i_mexc      := '1';
        i_exctype   := r.ifailkind(0);
        v.imisspend := '0';
        v.ifailkind := "00";
        v.ramreload := '1';
        v.s         := as_normal;

      -- Delayed handling to lessen impact of odco.mds assert.
      when as_dfailkind =>
        v.dmisspend  := '0';
        odco.mds     := '0';
        d_mexc       := '1';
        d_exctype    := r.dfailkind(0);
        v.slowwrpend := '0';
        v.dmisspend  := '0';
        v.dfailkind  := "00";
        v.ramreload  := '1';
        v.s          := as_normal;

      -- Check accessibility of a first level page table address.
      -- PMP check unless hypervisor enabled.
      -- Address will be properly mapped if hypervisor is used.
      -- This is the actual entrypoint into as_mmuwalk.
      when as_mmu_pt1addr_chk =>
        if mmuen = 1 and is_riscv then
          if hmmu_enabled(csro, r.h_v) then
            v.h_done       := '0';  -- Do not remember finished lookup any longer.
            -- OK?
            if htlbchk.hit = '1' then
              v.ahb.haddr  := htlbchk.paddr(v.ahb.haddr'range);
              v.ahb.htrans := HTRANS_NONSEQ;
              v.s          := as_mmuwalk;
              -- Just about to start sPT walk?
              if r.newent.mask(r.newent.mask'low) = '1' then
                if walk_mark then
                end if;
                if walk_fault and csro.mmu_sptfault = '1' then
                  v.swalk_fault := '1';
                  v.s           := as_mmuwalk_pterr;
                  v.ahb.htrans  := HTRANS_IDLE;
                end if;
              end if;
            -- Hit but did not allow reading page table!
            elsif htlbchk.amatch = '1' then
              v.s          := as_hmmuwalk_pterr;
            -- Miss
            else
              v.ahb.hsize    := pte_hsize;

              -- First TLB level.
              v.hnewent.mask := (others => '0');

              -- First level page table accessibility
              v.pmp_do       := '1';

              -- On RISC-V, the base is indexed directly for the first level.
              -- Return physical address for next level of page table.
              -- mask - pre-shift (ie before new 1 at bit 1 (first)) page table mask
              mmu_data                                := (others => '0');
              mmu_data(ppn'length + 10 - 1 downto 10) := hmmu_base(csro, r.h_addr)(ppn'range);
              haddr := pt_addr(mmu_data, v.hnewent.mask, r.h_addr, "00");

              -- Prepare for second TLB level.
              v.hnewent.mask(v.hnewent.mask'low) := '1';

              v.ahb.haddr := haddr(v.ahb.haddr'range);
              v.pmp_low   := fit0ext(mmu_data & "00", v.pmp_low);
              v.h_cause := "00";   -- Back here afterwards.

              v.hnewent.ctx      := mmu_ctx(r, csro);
              v.hnewent.vaddr    := r.h_addr(gvn'range);
              v.hnewent.modified := '0';
              v.h_x              := '0';
              v.h_ls             := '0';
              v.h_mxr            := '0';
              v.h_vmxr           := '0';
              v.h_hx             := '0';

              v.mmusel(3)        := '1';              -- Doing hPT walk

              if pmpen or pmaen then
                v.s          := as_mmu_pt2addr_pmpchk;
              else
                v.s          := as_hmmuwalk;
                v.ahb.htrans := HTRANS_NONSEQ;
                -- Just about to start hPT walk!
                v.perf(11)   := '1';
                if walk_mark then
                end if;
                if walk_fault and csro.mmu_hptfault = '1' then
                  v.hwalk_fault := '1';
                  v.s           := as_hmmuwalk_pterr;
                  v.ahb.htrans  := HTRANS_IDLE;
                end if;
              end if;
            end if;
          else
            v.s := as_mmuwalk;
            if (v.pmp_su_rwx(2) = '1' or not actual_tlb_pmp) and
               (not pmaen or pma_pt_r(v.pma)) then
              v.ahb.htrans := HTRANS_NONSEQ;
              -- Just about to start sPT walk?
              if r.newent.mask(r.newent.mask'low) = '1' then
                if walk_mark then
                end if;
                if walk_fault and csro.mmu_sptfault = '1' then
                  v.swalk_fault := '1';
                  v.s           := as_mmuwalk_pterr;
                  v.ahb.htrans  := HTRANS_IDLE;
                end if;
              end if;
            else
              -- PMP/PMA did not allow reading page table!
              v.s          := as_mmuwalk_pmperr;
            end if;
            if not actual_tlb_pmp then
              pmp_mmu      := '1';
            end if;
          end if;
        end if;

      -- Check accessibility of a first level PTE range via hypervisor TLB.
      -- This will update the proposed TLB entry.
      when as_mmu_pte1_hchk =>
        if ext_h = 1 then
          v.h_done        := '0';  -- Do not remember finished lookup any longer.
          -- Same as in as_normal
          v.ahb.htrans    := HTRANS_IDLE;
          v.ahb.hwrite    := '0';
          v.ahb.hburst    := HBURST_INCR;
          v.ahb3.error    := '0';
          v.ahb3.rdbvalid := (others => '0');
          -- OK?
          if htlbchk.hit = '1' then
            -- Only allow for same or smaller page size!
            if unsigned(htlbchk.h_mask) > unsigned(r.newent.mask) then
              v.newent.mask := htlbchk.h_mask;
            end if;
            v.newent.perm(2 downto 0) := r.newent.perm(2 downto 0) and htlbchk.h_perm;

            v.newent.h_r      := htlbchk.h_perm(0);
            v.newent.pmp_r    := htlbchk.h_pmp_r;
            v.newent.pmp_no_w := htlbchk.h_pmp_no_w;
            v.newent.pmp_no_x := htlbchk.h_pmp_no_x;
            v.newent.busw     := htlbchk.busw;
            if ext_svpbmt = 1 then
              v.newent.pbmt   := htlbchk.pbmt;
            end if;
            v.newent.cached   := htlbchk.cached;
            if pmaen then
              v.newent.pma    := htlbchk.pma;
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
            -- The type of fault reported depends on the actual reason.
            if (is_access_i(r.mmusel) and htlbchk.h_pmp_no_x = '1') or
               (is_access_w(r.mmusel) and htlbchk.h_pmp_no_w = '1') or
               (is_access_r(r.mmusel) and r.h_hx = '1' and htlbchk.h_pmp_no_x = '1') then
              v.s := as_hmmuwalk_pmperr;
            else
              v.s := as_hmmuwalk_pterr;
            end if;
          -- Miss
          else
            v.ahb.hsize    := pte_hsize;

            -- First TLB level.
            v.hnewent.mask := (others => '0');

            -- First level page table accessibility
            v.pmp_do       := '1';

            -- On RISC-V, the base is indexed directly for the first level.
            -- Return physical address for next level of page table.
            -- mask - pre-shift (ie before new 1 at bit 1 (first)) page table mask
            mmu_data                                := (others => '0');
            mmu_data(ppn'length + 10 - 1 downto 10) := hmmu_base(csro, r.h_addr)(ppn'range);
            haddr := pt_addr(mmu_data, v.hnewent.mask, r.h_addr, "00");

            -- Prepare for second TLB level.
            v.hnewent.mask(v.hnewent.mask'low) := '1';

            v.ahb.haddr := haddr(v.ahb.haddr'range);
            v.pmp_low   := fit0ext(mmu_data & "00", v.pmp_low);
            v.h_cause := "01";   -- Back here afterwards.

            v.hnewent.vaddr    := r.h_addr(gvn'range);
            v.hnewent.ctx      := mmu_ctx(r, csro);
            v.hnewent.modified := r.h_ls;

            if pmpen or pmaen then
              v.s          := as_mmu_pt2addr_pmpchk;
            else
              v.s          := as_hmmuwalk;
              v.ahb.htrans := HTRANS_NONSEQ;
              -- Just about to start hPT walk!
              v.perf(11)   := '1';
              if walk_mark then
              end if;
              if walk_fault and csro.mmu_hptfault = '1' then
                v.hwalk_fault := '1';
                v.s           := as_hmmuwalk_pterr;
                v.ahb.htrans  := HTRANS_IDLE;
              end if;
            end if;
          end if;

          -- Note the use of v.newent.mask here, unlike in the
          -- other two equivalent places!
          -- This is because we actually update it above on hit.
          if is_access_i(r.mmusel) then
            v.i2paddr   := fit0ext(v.newent.paddr & r.i2.pc(11 downto 0), v.i2paddr);
            virtual2physical(r.i2.pc, v.newent.mask, v.i2paddr);
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
          v.irdbufvaddr := r.i2.pc(r.irdbufvaddr'range);
          v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
          v.iramaddr    := r.i2.pc(r.iramaddr'range);
        end if;

      -- Check physical hypervisor address via PMP/PMA.
      -- This is the actual entrypoint into as_hmmuwalk.
      -- Must have r.hmmuwalk_cause set!
      when as_mmu_pt2addr_pmpchk =>
        if ext_h = 1 and (pmpen or pmaen) then
          v.s            := as_hmmuwalk;
          if v.pmp_su_rwx(2) = '1' and
             (not pmaen or pma_pt_r(v.pma)) then
            v.ahb.htrans := HTRANS_NONSEQ;
            -- Just about to start hPT walk?
            if r.hnewent.mask(v.hnewent.mask'low) = '1' then
              v.perf(11) := '1';
              if walk_mark then
              end if;
              if walk_fault and csro.mmu_hptfault = '1' then
                v.hwalk_fault := '1';
                v.s           := as_hmmuwalk_pterr;
                v.ahb.htrans  := HTRANS_IDLE;
              end if;
            end if;
          else
            -- PMP/PMA did not allow reading page table!
            v.s := as_hmmuwalk_pmperr;
          end if;
        end if;

      -- Flush pending, from as_normal or explicit as_wrasi.
      when as_flush =>
        if r.flushpart(1) = '1' then
          v.ilru         := (others => (others => '0'));
          v.i1cont       := '0';
        end if;
        if r.flushpart(0) = '1' then
          v.dlru         := (others => (others => '0'));
        end if;
        v.flushctr       := uadd(r.flushctr, 1);
        if r.flushpart(1) = '1' and all_0(v.flushctr) then
          v.flushpart(1) := '0';
          v.iflushpend   := '0';
        end if;
        if r.flushpart(0) = '1' and all_0(v.flushctr) then
          v.dtflushdone  := '1';
        end if;
        if r.flushpart(0) = '1' and r.dtflushdone = '1' and rs.s3flush(0) = '0' then
          v.flushpart(0) := '0';
          v.dflushpend   := '0';
        end if;
        if v.flushpart = "00" then
          v.ramreload    := '1';
          v.s            := as_normal;
        end if;
        ocrami.iindex               := (others => '0');
        ocrami.iindex(i_sets'range) := get_hi(r.flushctr, i_sets'length);
        ocrami.idataoffs            := (others => '0');
        ocrami.itagdin              := itags_default;
        if r.flushpart(1) = '1' then
          ocrami.itagen             := (others => '1');
          ocrami.itagwrite          := '1';
        end if;
        if r.flushpart(0) = '1' and r.dtflushdone = '0' then
          vs.s1haddr(d_tag'range)                  := (others => '0');
          vs.s1haddr(TAG_HIGH downto TAG_HIGH - 7) := x"F3";
          for x in d_ways'range loop
            vs.s1tagmsb(2 * x + 1 downto 2 * x)    := u2vec(x, 2);
          end loop;
          vs.s1haddr(d_index'range) := r.flushctr(DOFFSET_HIGH - DOFFSET_LOW downto 0);
          vs.s1read                 := '1';
          vs.s1flush                := (others => '1');
        end if;

      -- Instruction fetch on I$ miss.
      when as_icfetch =>
        do_icfetch := true;
        v.i1ten         := '0';
        -- Only allocate if I$ actually enabled!
        if all_0(r.i2hitv) and icache_enabled(r) and r.irdbufen = '0' then
          -- Select way to replace
          v.i2hitv      := replace_vec(r.i2validv, ilruent);
        end if;
        v.irdbufen      := '1';
        -- Just beginning fetch?
        if r.irdbufen = '0' then
          v.irdbufvaddr := r.i2.pc(r.irdbufvaddr'range);
          v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
          v.i2bufmatch  := '1';
        end if;

        burst_update(r, ilinesize, r.ahb.hsize(1 downto 0) /= "10", v.ahb.htrans, v.ahb.haddr);

        keepreq := '1';
        if r.ahb.hsize(1 downto 0) /= "10" then
          if all_1(v.ahb.haddr(log2(ilinesize * 4) - 1 downto log2(busw / 8))) then
            keepreq := '0';
          end if;
        else
          if all_1(v.ahb.haddr(log2(ilinesize * 4) - 1 downto 2)) then
            keepreq := '0';
          end if;
        end if;

        -- Write read data buffer into I$ data RAM.
        ocrami.iindex(i_sets'range)      := r.irdbufvaddr(i_index'range);
        ocrami.idataoffs(i_offset'range) := r.iramaddr;
        if icache_active(r) = '1' and r.irdbufen = '1' then
          ocrami.itagen(i_ways'range)    := r.i2hitv;
          ocrami.itagwrite               := '1';
          ocrami.idataen(i_ways'range)   := r.i2hitv;
          ocrami.idatawrite              := "11";
        end if;
        if ((not ENDIAN_B) and r.ahb3.rdbvalid(LINESZMAX - 1 - u2i(r.iramaddr & onev(3))) = '1') or
           ((ENDIAN_B)     and r.ahb3.rdbvalid(u2i(r.iramaddr & onev(3))) = '1') then
          v.iramaddr        := uadd(r.iramaddr, 1);
          -- Finished fetching I$ line?
          if all_1(r.iramaddr) then
            v.irdbufen      := '0';
            v.ramreload     := '1';
            -- Update irdbufvaddr/paddr since used in icfetch2 stage
            if r.imisspend = '1' then
              v.irdbufvaddr := r.i2.pc(r.irdbufvaddr'range);
              v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
              v.iramaddr    := r.i2.pc(r.iramaddr'range);
            else
              v.irdbufvaddr := r.i1.pc(r.irdbufvaddr'range);
              v.irdbufpaddr := itlbchk.paddr(r.irdbufpaddr'range);
              v.iramaddr    := r.i1.pc(r.iramaddr'range);
            end if;
            do_icfetch      := false;
            if v.imisspend = '1' and v.i2paddrv = '1' then
              v.s           := as_wptectag1;
            else
              v.s           := as_normal;
            end if;
          end if;
        end if;
        i_mexc    := r.ahb3.error and not r.icignerr;
        i_exctype := '1';
        if r.ahb3.error = '1' and r.icignerr = '0' then
          v.iflushpend := '1';
        end if;
        ocrami.itcmen := '0';

      when as_dcfetch =>
        do_access := true;
        -- Only allocate if D$ actually enabled!
        if all_0(r.d2hitv) and dcache_enabled(r) and r.d2nocache = '0' then
          v.d2hitv := replace_vec(r.d2validv, dlruent);
        end if;
        if not all_0(rs.s2read) then
          v.dvtagdone := '1';
        end if;

        burst_update(r, dlinesize, r.d2busw = '1', v.ahb.htrans, v.ahb.haddr);

        keepreq := '1';
        if r.d2busw = '1' then
          if all_1(v.ahb.haddr(log2(dlinesize * 4) - 1 downto log2(busw / 8))) then
            keepreq := '0';
          end if;
        else
          if all_1(v.ahb.haddr(log2(dlinesize * 4) - 1 downto 2)) then
            keepreq := '0';
          end if;
        end if;

        -- Write read data buffer into D$ data RAM
        -- Note virtual and physical tag write managed by snoop pipeline above
        -- Data managed here
        ocrami.ddataindex(d_sets'range)  := r.d2vaddr(d_index'range);
        ocrami.ddataoffs(d_offset'range) := r.dramaddr;
        if ((not ENDIAN_B) and r.ahb3.rdbvalid(LINESZMAX - 1 - u2i(std_logic_vector'(r.dramaddr & onev(DLINE_LOW_REAL - 1 downto 2)))) = '1') or
           ((ENDIAN_B)     and r.ahb3.rdbvalid(u2i(std_logic_vector'(r.dramaddr & onev(DLINE_LOW_REAL - 1 downto 2)))) = '1')
        then
          ocrami.ddataen                 := (others => '0');
          if dcache_active(r) = '1' then
            ocrami.ddataen(d_ways'range) := r.d2hitv;
            ocrami.ddatawrite            := (others => '1');
          end if;
          v.dramaddr      := uadd(r.dramaddr, 1);
          if all_1(r.dramaddr) then
            do_access     := false;
            if r.dvtagdone = '0' then
              v.s         := as_dcfetch2;
            else
              v.dmisspend := '0';
              v.s         := as_normal;
            end if;
            if r.d1ten = '1' then
              v.ramreload := '1';
            end if;
          end if;
        end if;
        d_mexc    := r.ahb3.error and not r.dcignerr;
        d_exctype := r.ahb3.error;  -- Count AHB error as access fault.
        if r.ahb3.error = '1' and r.dcignerr = '0' then
          v.dflushpend := '1';
        end if;
        odco.way := (others => '0');
        for x in 0 to LINESZMAX / 2 - 1 loop
          if r.d2vaddr(BUF_HIGH downto 3) = u2vec(x, BUF_HIGH - 2) then
            if not ENDIAN_B then
              odco.data(0) := get64(r.ahb3.rdbuf, (LINESZMAX - 2 * x - 2) * 32);
            else
              odco.data(0) := get64(r.ahb3.rdbuf, x * 64);
            end if;
          end if;
        end loop;
        odco.mds := '0';

      when as_dcfetch2 =>
        if not all_0(rs.s2read) then
          v.dvtagdone   := '1';
        end if;
        if r.dvtagdone = '1' or all_0(r.d2hitv) then
          v.s           := as_normal;
          v.dmisspend   := '0';
          if r.d1ten = '1' then
            v.ramreload := '1';
          end if;
        end if;

      when as_dcsingle =>
        do_access := true;
        if ahbi.hready = '1' then
          if r.granted = '1' and (ahbi.hresp(1) = '0' or r.ahb2.inacc = '0') and r.ahb.htrans(1) = '1' then
            v.ahb.htrans   := HTRANS_IDLE;
          elsif r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb.htrans   := HTRANS_NONSEQ;
          elsif r.ahb2.inacc = '1' and r.d2busw = '0' and r.d2size = "11" and r.ahb.haddr(2) = '0' then
            v.ahb.haddr(2) := '1';
            v.ahb.htrans   := HTRANS_NONSEQ;
          end if;
        end if;

        if r.ahb3.inacc = '1' and r.ahb.htrans(1) = '0' then
          do_access     := false;
          v.dmisspend   := '0';
          v.s           := as_normal;
          if r.d1ten = '1' then
            v.ramreload := '1';
          end if;
        end if;
        for x in 0 to LINESZMAX / 2 - 1 loop
          if r.d2vaddr(BUF_HIGH downto 3) = u2vec(x, BUF_HIGH - 2) then
            if not ENDIAN_B then
              odco.data(0) := get64(r.ahb3.rdbuf, (LINESZMAX - 2 * x - 2) * 32);
            else
              odco.data(0) := get64(r.ahb3.rdbuf, x * 64);
            end if;
          end if;
        end loop;
        odco.way  := (others => '0');
        odco.mds  := '0';
        d_mexc    := r.ahb3.error;
        d_exctype := r.ahb3.error;  -- Count AHB error as access fault.

      -- Normal page table walk.
      -- For RISC-V, this must always be entered via as_mmu_pt1addr_chk since it relies
      -- on an already hPT/PMP-checked address being accessed.
      when as_mmuwalk =>
        if mmuen = 1 then
          -- Complete current AHB access
          if r.ahb.htrans = "00" and r.ahb2.inacc = '0' then
            null;
          elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '0' then
            null;
          elsif ahbi.hready = '0' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb.htrans := "00";
          elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb.htrans := "10";
          elsif ahbi.hready = '1' and r.granted = '1' then
            v.ahb.htrans := "00";
          end if;

          -- New entry and new error (if error occurs)
          if is_access_i(r.mmusel) then
            v.newent.ctx      := r.i2.ctx;
            v.newent.mode     := r.i2.mode;
            v.newent.vaddr    := r.i2.pc(gvn'range);
            v.newent.modified := '0';
            if not is_riscv then
              v.newerrclass   := "01";
            end if;
            v.mmuerr.at_ls    := '0';        -- Load/Execute
            v.mmuerr.at_id    := '1';        -- Instruction space
            v.mmuerr.at_su    := r.i2.su;
          else
            v.newent.ctx      := mmu_ctx(r, csro, r.d2.mode);
            v.newent.mode     := r.d2.mode;
            v.newent.vaddr    := r.d2vaddr(gvn'range);
            v.newent.modified := to_bit(is_access_w(r.mmusel));
            if not is_riscv then
              v.newerrclass   := "10";
            end if;
            v.mmuerr.at_ls    := to_bit(is_access_w(r.mmusel));
            v.mmuerr.at_id    := '0';
            v.mmuerr.at_su    := r.d2.su;
            -- Treat atomic access as store to avoid store phase of atomic
            -- causing mmu fault.
            if r.d2lock = '1' then
              v.newent.modified := '1';
              v.mmuerr.at_ls    := '1';
            end if;
          end if;

          v.newent.paddr  := fit0ext(pte_paddr(rdb64), v.newent.paddr);

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
            if is_riscv then
              v.newent.modified := v.newent.modified or rdb32(7);
            else
              v.newent.modified := v.newent.modified or rdb32(6);
            end if;
          end if;

          -- Prepare hwdata for writing back PTE with R/M bits set
          -- Check if write-back is needed
          v.ahb.hwdata := rdb64;                   -- Don't care if it is really 32 bits.
          pte_mark_modacc(v.ahb.hwdata, r.newent.modified, vneedwb, vneedwblock);
          -- If it was not 64 bit earlier, duplicate on bus.
          if pte_hsize = HSIZE_WORD then
            v.ahb.hwdata(63 downto 32) := lo_h(v.ahb.hwdata);
          end if;

          if is_riscv then
            v.newent.perm := (not rdb32(rv_pte_u)) & rdb32(rv_pte_u downto rv_pte_r);
          end if;

          if not is_riscv then
            v.newent.acc := rdb32(4 downto 2);
          else
            v.newent.acc := (others => '0');
          end if;
          v.dregval      := rdb32;

          if rdb32v = '1' then
            v.ahb3.rdbvalid := (others => '0');
            -- Depending on level/type -
            --   update haddr to go down to next level
            --   write back "accessed" bit
            --   update TLB and register of access causing miss

            -- AHB error fetching entry?
            if r.ahb3.error = '1' then
              v.s             := as_mmuwalk_pmperr;
              if not is_riscv then
                v.newerrclass := "11";
                v.mmuerr.ft   := "100";       -- Translation error
                v.mmuerr.fav  := '1';
              end if;

            -- Page table entry?
            elsif is_pte(rdb32) then
              if not is_riscv then
                v.mmuerr.ft := ft_acc_resolve(r.mmuerr.at_ls & r.mmuerr.at_id & r.mmuerr.at_su, rdb32);
              end if;

              if is_access_asi_walk(r.mmusel) then
                v.s := as_rdasi2;

              -- Not valid?
              elsif not is_valid_pte(rdb64, r.newent.mask) then
                v.s := as_mmuwalk_pterr;
                if not is_riscv then
                  v.mmuerr.fav := '1';
                end if;

              -- Permission error according to page table?
              elsif (not is_riscv and v.mmuerr.ft(1) /= '0') or
                    -- For now, assume PMP and hypervisor allows read (corrected later),
                    -- since we need to do any writeback before that check, anyway.
                    -- Since permissions check knows about execution vs data read/write,
                    -- it does not matter if we always pass the r.d2* here.
                    (is_riscv and not permitted(r.mmuerr.at_id, r.mmuerr.at_su, r.mmuerr.at_ls, '0',
                                                (not rdb32(rv_pte_u)) & rdb32(rv_pte_u downto rv_pte_r),
                                                '1', '1', '0',    -- pmp_r, h_r, pmp_no_x
                                                r.d2.sum  and not r.mmuerr.at_id,
                                                r.d2.mxr  and not r.mmuerr.at_id,
                                                r.d2.vmxr and not r.mmuerr.at_id,
                                                r.d2.hx   and not r.mmuerr.at_id,
                                                r.d2.ss   and not r.mmuerr.at_id,
                                                cond(not is_v(r.d2.mode),
                                                     csro.menvcfg_sse,
                                                     csro.menvcfg_sse and csro.henvcfg_sse)
                                               )) then
                v.s := as_mmuwalk_pterr;
                if is_riscv and ext_zicfiss = 1 and
                   ((not is_v(r.d2.mode) and csro.menvcfg_sse = '1') or
                    (csro.menvcfg_sse = '1' and csro.henvcfg_sse = '1')) then
                  -- Shadow stack instruction?
                  if r.d2.ss = '1' then
                    if rdb32(rv_pte_x downto rv_pte_r) = "001" then
                      -- Store/AMO page fault when read-only
                    else
                      -- Otherwise, store/AMO access fault
                      v.s := as_mmuwalk_pmperr;
                    end if;
                  -- Normal fetch or store at shadow stack page (load would not fail)?
                  elsif rdb32(rv_pte_x downto rv_pte_r) = "010" then
                    -- Access fault
                    v.s := as_mmuwalk_pmperr;
                  end if;
                end if;
                if not is_riscv then
                  v.mmuerr.fav := '1';
                end if;

              -- Address is not zero extended?
              elsif is_riscv and
                    not ((not hmmu_enabled(csro, r.h_v) and all_0(rdb64(rv_ppn'high downto pa_msb  + 1 - 12 + 10))) or
                         (    hmmu_enabled(csro, r.h_v) and all_0(rdb64(rv_ppn'high downto gpa_msb + 1 - 12 + 10)))) then
                v.s := as_mmuwalk_pmperr;

              -- Writeback needed?
              elsif vneedwb = '1' then
                fault        := false;
                fault_access := false;
                fault_hyper  := false;
                if hmmu_enabled(csro, r.h_v) then
                  -- Writeback permission according to hypervisor TLB, and not always fault?
                  if csro.mmu_adfault = '0' then
                    if r.h_w = '1' then
                      if vneedwblock = '1' and r.ahb.hlock = '0' then
                        do_mmu_lock  := true;
                        v.s          := as_xmmuwalk_lock;
                      else
                        v.s          := as_xwpte;
                      end if;
                    else
                      fault          := true;
                      fault_hyper    := true;
                      -- L1 PT write fault due to L2 PT.
                      -- Instruction or data access.
                      v.itypehyper   := not (r.mmusel(0) & r.mmusel(0));
                      v.dtypehyper   :=      r.mmusel(0) & r.mmusel(0);
                    end if;
                  else
                    fault            := true;
                  end if;

                elsif is_riscv and actual_tlb_pmp then
                  -- Writeback permission according to PMP/PMA, and not always fault?
                  if csro.mmu_adfault = '0' then
                    if v.pmp_su_rwx(1) = '1' and
                       (not pmaen or pma_pt_w(v.pma)) then
                      if vneedwblock = '1' and r.ahb.hlock = '0' then
                        do_mmu_lock := true;
                        v.s         := as_xmmuwalk_lock;
                      else
                        v.s         := as_xwpte;
                      end if;
                    else
                      fault         := true;
                      fault_access  := true;
                    end if;
                  else
                    fault           := true;
                  end if;

                elsif csro.mmu_adfault = '1' then
                  fault            := true;
                else
                  if vneedwblock = '1' and r.ahb.hlock = '0' then
                    do_mmu_lock    := true;
                    v.s            := as_mmuwalk_lock;
                  else
                    v.s            := as_wptectag1;
                  end if;
                end if;

                if not fault then
                  v.ahb.htrans   := HTRANS_NONSEQ;
                  v.ahb.hwrite   := '1';
                  if vneedwblock = '1' and r.ahb.hlock = '0' then
                    v.ahb.hlock  := '1';
                    v.ahb.htrans := HTRANS_IDLE;
                    v.ahb.hwrite := '0';
                    v.granted    := '0';
                  else
                    v.ahb.htrans := HTRANS_NONSEQ;
                    v.tlbupdate  := '1';
                  end if;
                elsif fault_hyper then
                  -- Was non-writability caused by PMP rather than hypervisor PT?
                  if r.h_pmp_no_w = '1' then
                    v.s := as_mmuwalk_pmperr;
                  else
                    v.s := as_hmmuwalk_pterr;
                  end if;
                elsif fault_access then
                  v.s := as_mmuwalk_pmperr;
                else
                  v.s := as_mmuwalk_pterr;
                  if not is_riscv then
                    v.mmuerr.fav := '1';
                  end if;
                end if;

              -- OK!
              else

                -- Check PTE range with hypervisor page tables, if applicable.
                if hmmu_enabled(csro, r.h_v) then
                  if is_access_i(r.mmusel) then
                    v.h_addr := fit0ext(v.newent.paddr & x"000", v.h_addr);
                    virtual2physical(r.i2.pc, v.newent.mask, v.h_addr);
                  else
                    v.h_addr := fit0ext(v.newent.paddr & x"000", v.h_addr);
                    virtual2physical(r.d2vaddr, v.newent.mask, v.h_addr);
                  end if;
                  v.h_do     := '1';
                  v.h_x      := r.mmuerr.at_id;
                  v.h_ls     := r.mmuerr.at_ls;
                  if is_riscv and ext_zicfiss = 1 then
                    -- Shadow stack instructions always check for writeability
                    v.h_ls   := v.h_ls or r.d2.ss;
                  end if;
                  v.h_mxr    := r.d2.mxr  and not v.h_x;
                  v.h_vmxr   := r.d2.vmxr and not v.h_x;
                  v.h_hx     := r.d2.hx   and not v.h_x;
                  v.s        := as_mmu_pte1_hchk;
                  -- Possible access fault due to L2 PT.
                  -- Instruction or data access.
                  v.itypehyper := '0' & v.h_x;
                  v.dtypehyper := '0' & not v.h_x;
                -- Check PMP permission error, if applicable.
                elsif is_riscv and actual_tlb_pmp then
                  v.pmp_mask := pt_mask(r.newent.mask)(v.pmp_mask'range);
                  v.pmp_low  := fit0ext(v.newent.paddr & x"000", v.pmp_low) and v.pmp_mask;
                  v.pmp_do   := '1';
                  v.s        := as_mmu_pte1_pmpchk;
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
            elsif is_ptd(rdb32) and is_valid_ptd(rdb64) and get_hi(r.newent.mask) = '0' then
              -- Address is not zero extended?
              if is_riscv and
                 not ((not hmmu_enabled(csro, r.h_v) and all_0(rdb64(rv_ppn'high downto pa_msb  + 1 - 12 + 10))) or
                      (    hmmu_enabled(csro, r.h_v) and all_0(rdb64(rv_ppn'high downto gpa_msb + 1 - 12 + 10)))) then
                v.s           := as_mmuwalk_pmperr;
              else
                -- Shift in a '1' for each new TLB level.
                v.newent.mask := '1' & r.newent.mask(r.newent.mask'low to r.newent.mask'high - 1);

                haddr         := pt_addr(rdb64, r.newent.mask, r.newent.vaddr, pt_code(r.newent.mask));
                v.ahb.haddr   := haddr(v.ahb.haddr'range);

                if ext_h = 1 then
                  v.h_addr    := haddr(v.h_addr'range);
                end if;

                if is_riscv then
                  if actual_tlb_pmp then
                    -- "va" is all zeroes and will give the base address.
                    -- v.pmp_mask is already set from above. Always 4 kByte.
                    v.pmp_low := fit0ext(pt_addr(rdb64, r.newent.mask, va, pt_code(r.newent.mask)), v.pmp_low);
                    v.pmp_do  := '1';
                  end if;
                end if;

                -- Return physical address for next level of page table.
                -- mask - pre-shift (ie before new 1 at bit 1 (first)) page table mask
                -- code - mask recoded as position for first 0 (from 1)
                v.ahb.htrans  := HTRANS_NONSEQ;
                -- ASI?
                if is_access_asi_walk(r.mmusel) then
                  v.d2vaddr(9 downto 8) := uadd(r.d2vaddr(9 downto 8), 1);
                  if r.d2vaddr(9 downto 8) = "11" then
                    v.s                 := as_rdasi2;
                  end if;
                elsif is_riscv then
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
                  v.s          := as_mmu_pt1addr_chk;
                  v.ahb.htrans := HTRANS_IDLE;
                end if;
              end if;

            -- Invalid/reserved or too many levels of PTDs
            else
              v.s := as_mmuwalk_pterr;
              if not is_riscv then
                if is_pt_invalid(rdb32) then
                  v.mmuerr.ft := "001";     -- Invalid address error
                else
                  v.mmuerr.ft := "100";     -- Translation error
                end if;
                v.mmuerr.fav  := '1';
              end if;
            end if;
          end if;

          if not is_riscv or not actual_tlb_pmp then
            if is_access_i(r.mmusel) then
              v.i2paddr   := fit0ext(v.newent.paddr & r.i2.pc(11 downto 0), v.i2paddr);
              virtual2physical(r.i2.pc, r.newent.mask, v.i2paddr);
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
            v.irdbufvaddr := r.i2.pc(r.irdbufvaddr'range);
            v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
            v.iramaddr    := r.i2.pc(r.iramaddr'range);
          end if;
        end if;

      -- Hypervisor page table walk finished.
      -- Where to return to depends on why the walk was done.
      when as_hmmuwalk_done =>
        if ext_h = 1 then
          -- Same as in as_normal
          v.ahb.htrans    := HTRANS_IDLE;
          v.ahb.hwrite    := '0';
          v.ahb.hburst    := HBURST_INCR;
          v.ahb3.error    := '0';
          v.ahb3.rdbvalid := (others => '0');
          v.h_do := '1';
          -- Checking first level PT address?
          if v.h_cause = "00" then
            v.mmusel(3) := '0';      -- Done with hPT walk
            v.h_x    := '0';
            v.h_ls   := '0';
            v.h_mxr  := '0';
            v.h_vmxr := '0';
            v.h_hx   := '0';
            v.s      := as_mmu_pt1addr_chk;
          -- Checking first level PTE range?
          else
            v.h_x    := r.mmuerr.at_id;
            v.h_ls   := r.mmuerr.at_ls;
            v.h_mxr  := r.d2.mxr  and not v.h_x;
            v.h_vmxr := r.d2.vmxr and not v.h_x;
            v.h_hx   := r.d2.hx   and not v.h_x;
            v.s      := as_mmu_pte1_hchk;
          end if;
          -- The hypervisor TLB is now supposed to have been updated
          -- with a matching entry. Mark so that this can be verified!
          v.h_done := '1';
        end if;

      -- Hypervisor page table walk.
      -- Must always be entered via as_mmu_pt2addr_pmpchk since it relies
      -- on an already PMP/PMA-checked address being accessed.
      when as_hmmuwalk =>
        if ext_h = 1 then
          -- Complete current AHB access
          if r.ahb.htrans = "00" and r.ahb2.inacc = '0' then
            null;
          elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '0' then
            null;
          elsif ahbi.hready = '0' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb.htrans := "00";
          elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb.htrans := "10";
          elsif ahbi.hready = '1' and r.granted = '1' then
            v.ahb.htrans := "00";
          end if;

          v.hnewent.mode := "010";   -- Hypervisor TLB

          -- Select which TLB entry to replace
          v.h2tlbid := pmru_decode(r.htlbpmru);

          v.hnewent.paddr  := fit0ext(pte_paddr(rdb64), v.hnewent.paddr);

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
            v.hnewent.modified := v.hnewent.modified or rdb32(7);
          end if;

          -- Prepare hwdata for writing back PTE with R/M bits set
          -- Check if write-back is needed
          v.ahb.hwdata := rdb64;                   -- Don't care if it is really 32 bits.
          pte_mark_modacc(v.ahb.hwdata, r.hnewent.modified, vneedwb, vneedwblock);
          -- If it was not 64 bit earlier, duplicate on bus.
          if pte_hsize = HSIZE_WORD then
            v.ahb.hwdata(63 downto 32) := lo_h(v.ahb.hwdata);
          end if;

          v.hnewent.perm := "11" & rdb32(rv_pte_x downto rv_pte_r);
          v.hnewent.h_r  := rdb32(rv_pte_r);

          if not is_riscv then
            v.hnewent.acc := rdb32(4 downto 2);
          else
            v.hnewent.acc := (others => '0');
          end if;
          v.dregval       := rdb32;

          if rdb32v = '1' then
            v.ahb3.rdbvalid := (others => '0');
            -- Depending on level/type -
            --   update haddr to go down to next level
            --   write back "accessed" bit
            --   update TLB and register of access causing miss

            -- AHB error fetching entry?
            if r.ahb3.error = '1' then
              v.s := as_hmmuwalk_pterr;

            -- Page table entry?
            elsif is_pte(rdb32) then

              -- Not valid?
              if not is_valid_pte(rdb64, r.hnewent.mask) or
                 -- All accesses are "user mode" at hypervisor PT level.
                 rdb64(rv_pte_u) = '0' then
                v.s := as_hmmuwalk_pterr;

              -- Permission error according to page table?
              -- For now, assume PMP allows read (corrected later),
              -- since we need to do any writeback before that check, anyway.
              elsif not permitted(r.h_x, '0', r.h_ls, '0',
                                  "11" & rdb32(rv_pte_x downto rv_pte_r),
                                  '1', rdb32(rv_pte_r), '0',
                                  '0', r.h_mxr, r.h_vmxr, r.h_hx) then
                v.s := as_hmmuwalk_pterr;

              -- Address is not zero extended?
              elsif is_riscv and not all_0(rdb64(rv_ppn'high downto physaddr - 12 + 10)) then
                v.s := as_hmmuwalk_pmperr;

              -- Writeback needed?
              elsif vneedwb = '1' then
                -- Writeback permission according to PMP/PMA, and not always fault?
                if csro.mmu_h_adfault = '0' then
                  if (v.pmp_su_rwx(1) = '1' or not (pmpen or pmaen)) and
                      (pma_pt_w(v.pma) or not pmaen) then
                    v.ahb.htrans   := HTRANS_NONSEQ;
                    v.ahb.hwrite   := '1';
                    if vneedwblock = '1' and r.ahb.hlock = '0' then
                      do_mmu_lock  := true;
                      v.s          := as_hmmuwalk_lock;
                      v.ahb.hlock  := '1';
                      v.ahb.htrans := HTRANS_IDLE;
                      v.ahb.hwrite := '0';
                      v.granted    := '0';
                    else
                      v.ahb.htrans := HTRANS_NONSEQ;
                      v.s          := as_hwpte;
--                      v.h2tlbupd   := '1';
                    end if;
                  else
                    v.s            := as_hmmuwalk_pmperr;
                  end if;
                else
                  v.s              := as_hmmuwalk_pterr;
                end if;

              -- Check PMP/PMA permission error, if applicable.
              elsif pmpen or pmaen then
                v.pmp_mask := pt_mask(r.hnewent.mask)(v.pmp_mask'range);
                v.pmp_low  := fit0ext(v.hnewent.paddr & x"000", v.pmp_low) and v.pmp_mask;
                v.pmp_do   := '1';
                v.s        := as_mmu_pte2_pmpchk;

              -- OK!
              else

                v.h2tlbupd    := '1';

                v.s := as_hmmuwalk_done;
              end if;

            -- Page table descriptor (and not too deep)?
            elsif is_ptd(rdb32) and is_valid_ptd(rdb64) and get_hi(r.hnewent.mask) = '0' then
              -- Address is not zero extended?
              if is_riscv and not all_0(rdb64(rv_ppn'high downto physaddr - 12 + 10)) then
                v.s := as_hmmuwalk_pmperr;
              else
                -- Shift in a '1' for each new TLB level.
                v.hnewent.mask := '1' & r.hnewent.mask(r.hnewent.mask'low to r.hnewent.mask'high - 1);

                v.ahb.haddr  := pt_addr(rdb64, r.hnewent.mask, r.hnewent.vaddr, pt_code(r.hnewent.mask))(v.ahb.haddr'range);

                -- "va" is all zeroes and will give the base address.
                -- v.pmp_mask is already set from above. Always 4 kByte.
                v.pmp_low   := fit0ext(pt_addr(rdb64, r.hnewent.mask, va, pt_code(r.hnewent.mask)), v.pmp_low);
                v.pmp_do    := '1';

                -- Return physical address for next level of page table.
                -- mask - pre-shift (ie before new 1 at bit 1 (first)) page table mask
                -- code - mask recoded as position for first 0 (from 1)
                v.ahb.htrans  := HTRANS_NONSEQ;

                -- This is needed to split the PMP/PMA dependancy chain.
                if pmpen or pmaen then
                  v.s          := as_mmu_pt2addr_pmpchk;
                  v.ahb.htrans := HTRANS_IDLE;
                else
                  v.s          := as_hmmuwalk;
                end if;
              end if;

            -- Invalid/reserved or too many levels of PTDs
            else
              v.s := as_hmmuwalk_pterr;
            end if;
          end if;
        end if;

      -- Check PTE range for PMP/PMA accessability, and shrink as necessary.
      when as_mmu_pte1_pmpchk =>
        if is_riscv and actual_tlb_pmp then
          -- Same as in as_normal
          v.ahb.htrans    := HTRANS_IDLE;
          v.ahb.hwrite    := '0';
          v.ahb.hburst    := HBURST_INCR;
          v.ahb3.error    := '0';
          v.ahb3.rdbvalid := (others => '0');

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
                -- Even without PMA, at least cachability can be disabled.
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
                  (ext_zicfiss = 1 and r.d2.ss = '1') or
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
              v.s := as_mmuwalk_pmperr;

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
          elsif v.pmp_hit = '1' and get_hi(r.newent.mask) = '0' then
            -- Shift in a '1' for each new fake TLB level.
            v.newent.mask := '1' & r.newent.mask(r.newent.mask'low to r.newent.mask'high - 1);


            -- Insert next part of address
            part_mask := get_right(pt_mask(r.newent.mask) xor pt_mask(v.newent.mask), part_mask);
            if is_access_i(r.mmusel) then
              part    := fit0ext(r.i2.pc, part) and part_mask;
            else
              part    := fit0ext(r.d2vaddr, part) and part_mask;
            end if;
            v.newent.paddr := r.newent.paddr or part(v.newent.paddr'range);
            v.pmp_mask     := pt_mask(v.newent.mask)(v.pmp_mask'range);
            v.pmp_low      := fit0ext(v.newent.paddr & x"000", v.pmp_low) and v.pmp_mask;
            v.pmp_do       := '1';
            -- Need to remember the state of pmp_m and pmp_only!
            if walk_pmp then
              v.pmp_m      := r.pmp_m;
              v.pmp_only   := r.pmp_only;
            end if;

            v.s            := as_mmu_pte1_pmpchk;

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
                -- Even without PMA, at least cachability can be disabled.
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
            v.s := as_mmuwalk_pmperr;
          end if;

          if is_access_i(r.mmusel) then
            v.i2paddr   := fit0ext(v.newent.paddr & r.i2.pc(11 downto 0), v.i2paddr);
            virtual2physical(r.i2.pc, r.newent.mask, v.i2paddr);
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
          v.irdbufvaddr := r.i2.pc(r.irdbufvaddr'range);
          v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
          v.iramaddr    := r.i2.pc(r.iramaddr'range);
        end if;

      -- Check HPTE range for PMP accessability, and shrink as necessary.
      when as_mmu_pte2_pmpchk =>
        if ext_h = 1 and (pmpen or pmaen) then
          -- Same as in as_normal
          v.ahb.htrans    := HTRANS_IDLE;
          v.ahb.hwrite    := '0';
          v.ahb.hburst    := HBURST_INCR;
          v.ahb3.error    := '0';
          v.ahb3.rdbvalid := (others => '0');

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
                -- Even without PMA, at least cachability can be disabled.
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
                  (ext_zicfiss = 1 and r.d2.ss = '1') or
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
              v.s := as_mmuwalk_pmperr;

            -- OK!
            else
              v.h2tlbupd := '1';
              v.s        := as_hmmuwalk_done;
            end if;

          -- PMP hit but not fit (and not too deep in shrinking)?
          elsif v.pmp_hit = '1' and get_hi(r.hnewent.mask) = '0' then
            -- Shift in a '1' for each new fake TLB level.
            v.hnewent.mask := '1' & r.hnewent.mask(r.hnewent.mask'low to r.hnewent.mask'high - 1);


            -- Insert next part of address
            part_mask := get_right(pt_mask(r.hnewent.mask) xor pt_mask(v.hnewent.mask), part_mask);
            part            := fit0ext(r.h_addr, part) and part_mask;
            v.hnewent.paddr := r.hnewent.paddr or part(v.hnewent.paddr'range);
            v.pmp_mask      := pt_mask(v.hnewent.mask)(v.pmp_mask'range);
            v.pmp_low       := fit0ext(v.hnewent.paddr & x"000", v.pmp_low) and v.pmp_mask;
            v.pmp_do        := '1';

            v.s             := as_mmu_pte2_pmpchk;

          -- Invalid/reserved or too many levels of PTDs
          else
            v.s := as_mmuwalk_pmperr;
          end if;
        end if;

      -- Some kind of page table error occurred during MMU walk
      when as_mmuwalk_pterr =>
        if is_access_asi_walk(r.mmusel) then
          v.s := as_rdasi2;
        else
          if is_access_i(r.mmusel) then
            oico.mds    := '0';
            if is_riscv or r.mmctrl1.nf = '0' then
              i_mexc    := '1';
            end if;
            v.imisspend := '0';
          else
            odco.mds       := '0';
            if is_riscv or r.mmctrl1.nf = '0' then
              d_mexc       := '1';
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

      -- Some kind of page table error occurred during HMMU walk
      when as_hmmuwalk_pterr =>
        if ext_h = 1 then
          if is_access_i(r.mmusel) then
            oico.mds       := '0';
            i_mexc         := '1';
            oico.exchyper  := '1';
            v.imisspend    := '0';
          else
            odco.mds       := '0';
            d_mexc         := '1';
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
        end if;

      -- Some kind of PMP error occurred after MMU walk,
      -- or a PMP/bus error when fetching PT data.
      when as_mmuwalk_pmperr =>
        if is_riscv then
          if is_access_asi_walk(r.mmusel) then
            v.s := as_rdasi2;
          else
            if is_access_i(r.mmusel) then
              oico.mds    := '0';
              i_mexc      := '1';
              v.imisspend := '0';
              i_exctype   := '1';             -- PMP fault
            else
              odco.mds     := '0';
              d_mexc       := '1';
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
              d_exctype := '1';              -- PMP fault
            end if;
            v.ramreload := '1';
            v.s         := as_normal;
          end if;
        end if;
        v.dregval     := (others => '0');

      -- Some kind of PMP error occurred after MMU walk,
      -- or a PMP/bus error when fetching PT data.
      when as_hmmuwalk_pmperr =>
        if ext_h = 1 then
          if is_access_i(r.mmusel) then
            oico.mds      := '0';
            i_mexc        := '1';
            oico.exchyper := '1';
            v.imisspend   := '0';
            i_exctype     := '1';             -- PMP fault
          else
            odco.mds       := '0';
            d_mexc         := '1';
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
            d_exctype := '1';              -- PMP fault
          end if;
          v.ramreload := '1';
          v.s         := as_normal;
        end if;

      -- Aquire AHB lock and then write back PTE.
      -- (Needed when writeback with 'modified' set.)
      when as_mmuwalk_lock =>
        do_mmu_lock := true;
        if r.ahb3.error = '1' then
          do_mmu_lock := false;
          -- AHB error fetching entry
          v.s              := as_mmuwalk_pmperr;
          if not is_riscv then
            v.newerrclass    := "11";
            v.mmuerr.ft      := "100";       -- Translation error
            v.mmuerr.fav     := '1';
          end if;
        elsif rdb32v = '1' then
          do_mmu_lock := false;
          if is_riscv then
            v.ahb.hwdata(7 downto 6) := v.ahb.hwdata(7 downto 6) or rdb32(7 downto 6);
            v.newent.modified        := v.newent.modified or rdb32(7);
          else
            v.ahb.hwdata(6 downto 5) := v.ahb.hwdata(6 downto 5) or rdb32(6 downto 5);
            v.newent.modified        := v.newent.modified or rdb32(6);
          end if;
          v.s              := as_wptectag1;
          v.ahb.htrans     := HTRANS_NONSEQ;
          v.ahb.hwrite     := '1';
          v.tlbupdate      := '1';
        elsif r.ahb2.inacc = '1' then
          if ahbi.hresp(1) = '1' then
            v.ahb.htrans   := HTRANS_IDLE;
            if ahbi.hready = '1' then
              v.ahb.htrans := HTRANS_NONSEQ;
            end if;
          end if;
        elsif r.ahb.htrans(1) = '1' then
          if r.granted = '1' then
            v.ahb.htrans   := HTRANS_IDLE;
          end if;
        else
          if r.granted = '1' then
            v.ahb.htrans   := HTRANS_NONSEQ;
          end if;
        end if;

      -- Aquire AHB lock and then write back PTE.
      -- (Needed when writeback with 'modified' set.)
      when as_xmmuwalk_lock =>
        if is_riscv and (ext_h = 1 or pmpen or pmaen) then
          do_mmu_lock := true;
          if r.ahb3.error = '1' then
            do_mmu_lock := false;
            -- AHB error fetching entry
            v.s              := as_mmuwalk_pmperr;
          elsif rdb32v = '1' then
            do_mmu_lock := false;
            v.ahb.hwdata(7 downto 6) := v.ahb.hwdata(7 downto 6) or rdb32(7 downto 6);
            v.newent.modified        := v.newent.modified or rdb32(7);
            v.s              := as_xwpte;
            v.ahb.htrans     := HTRANS_NONSEQ;
            v.ahb.hwrite     := '1';
            v.tlbupdate      := '1';
          elsif r.ahb2.inacc = '1' then
            if ahbi.hresp(1) = '1' then
              v.ahb.htrans   := HTRANS_IDLE;
              if ahbi.hready = '1' then
                v.ahb.htrans := HTRANS_NONSEQ;
              end if;
            end if;
          elsif r.ahb.htrans(1) = '1' then
            if r.granted = '1' then
              v.ahb.htrans   := HTRANS_IDLE;
            end if;
          else
            if r.granted = '1' then
              v.ahb.htrans   := HTRANS_NONSEQ;
            end if;
          end if;
        end if;

      -- Write back supervisor PTE
      when as_xwpte =>
        if is_riscv and (ext_h = 1 or pmpen or pmaen) then
          done           := false;
          if r.ahb.htrans = HTRANS_IDLE and r.ahb2.inacc = '0' then
            done         := true;
          elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '0' then
            -- Done!
            done         := true;
            if ahbi.hresp(0) = '1' then
              -- PTE writeback error
              v.werr     := '1';
            end if;
          elsif ahbi.hready = '0' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb.htrans := HTRANS_IDLE;
          elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb.htrans := HTRANS_NONSEQ;
          elsif ahbi.hready = '1' and r.granted = '1' then
            v.ahb.htrans := HTRANS_IDLE;
          end if;

          if done then
            -- Check PTE range with hypervisor page tables, if applicable.
            if hmmu_enabled(csro, r.h_v) then
                if is_access_i(r.mmusel) then
                  v.h_addr := fit0ext(r.newent.paddr & x"000", v.h_addr);
                  virtual2physical(r.i2.pc, r.newent.mask, v.h_addr);
                else
                  v.h_addr := fit0ext(r.newent.paddr & x"000", v.h_addr);
                  virtual2physical(r.d2vaddr, r.newent.mask, v.h_addr);
                end if;
              v.h_do     := '1';
              v.h_x      := r.mmuerr.at_id;
              v.h_ls     := r.mmuerr.at_ls;
              v.h_mxr    := r.d2.mxr  and not v.h_x;
              v.h_vmxr   := r.d2.vmxr and not v.h_x;
              v.h_hx     := r.d2.hx   and not v.h_x;
              v.s        := as_mmu_pte1_hchk;
              -- Possible access fault due to L2 PT.
              -- Instruction or data access.
              v.itypehyper := '0' & v.h_x;
              v.dtypehyper := '0' & not v.h_x;
            -- Check PMP permission error.
            else
              v.pmp_mask := pt_mask(r.newent.mask)(v.pmp_mask'range);
              v.pmp_low  := fit0ext(r.newent.paddr & x"000", v.pmp_low) and v.pmp_mask;
              v.pmp_do   := '1';
              v.s        := as_mmu_pte1_pmpchk;
            end if;
          end if;
        end if;

      -- Aquire AHB lock and then write back HPTE.
      -- (Needed when writeback with 'modified' set.)
      when as_hmmuwalk_lock =>
        if ext_h = 1 then
          do_mmu_lock := true;
          if r.ahb3.error = '1' then
            do_mmu_lock := false;
            -- AHB error fetching entry
            v.s              := as_hmmuwalk_pterr;
          elsif rdb32v = '1' then
            do_mmu_lock := false;
            v.ahb.hwdata(7 downto 6) := v.ahb.hwdata(7 downto 6) or rdb32(7 downto 6);
            v.hnewent.modified       := v.hnewent.modified or rdb32(7);
            v.s              := as_hwpte;
            v.ahb.htrans     := HTRANS_NONSEQ;
            v.ahb.hwrite     := '1';
--            v.h2tlbupd       := '1';
          elsif r.ahb2.inacc = '1' then
            if ahbi.hresp(1) = '1' then
              v.ahb.htrans   := HTRANS_IDLE;
              if ahbi.hready = '1' then
                v.ahb.htrans := HTRANS_NONSEQ;
              end if;
            end if;
          elsif r.ahb.htrans(1) = '1' then
            if r.granted = '1' then
              v.ahb.htrans   := HTRANS_IDLE;
            end if;
          else
            if r.granted = '1' then
              v.ahb.htrans   := HTRANS_NONSEQ;
            end if;
          end if;
        end if;

      -- Write back hypervisor PTE
      when as_hwpte =>
        if ext_h = 1 then
          done           := false;
          if r.ahb.htrans = HTRANS_IDLE and r.ahb2.inacc = '0' then
            done         := true;
          elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '0' then
            -- Done!
            done         := true;
            if ahbi.hresp(0) = '1' then
              -- PTE writeback error
              v.werr     := '1';
            end if;
          elsif ahbi.hready = '0' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb.htrans := HTRANS_IDLE;
          elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb.htrans := HTRANS_NONSEQ;
          elsif ahbi.hready = '1' and r.granted = '1' then
            v.ahb.htrans := HTRANS_IDLE;
          end if;

          if done then
            -- Check PMP permission error, if applicable.
            if pmpen or pmaen then
              v.pmp_mask := pt_mask(r.hnewent.mask)(v.pmp_mask'range);
              v.pmp_low  := fit0ext(r.hnewent.paddr & x"000", v.pmp_low) and v.pmp_mask;
              v.pmp_do   := '1';
              v.s        := as_mmu_pte2_pmpchk;
            else
              v.h2tlbupd := '1';
              v.s        := as_hmmuwalk_done;
            end if;
          end if;
        end if;

      when as_wptectag1 =>
        -- Write PTE and recheck tags stage 1
        v.s := as_wptectag2;
        -- Continue PTE writeback
        if r.ahb.htrans = HTRANS_IDLE and r.ahb2.inacc = '0' then
          null;
        elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '0' then
          null;
        elsif ahbi.hready = '0' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
          v.ahb.htrans := HTRANS_IDLE;
        elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
          v.ahb.htrans := HTRANS_NONSEQ;
        elsif ahbi.hready = '1' and r.granted = '1' then
          v.ahb.htrans := HTRANS_IDLE;
        end if;
        -- Drive Icache tag/data addresses
        ocrami.iindex(i_sets'range)      := r.irdbufvaddr(i_index'range);
        ocrami.idataoffs(i_offset'range) := r.iramaddr;
        ocrami.ifulladdr                 := r.i2.pc(ocrami.ifulladdr'range);
        v.i1cont := '0';
        -- To avoid complicating the tag comparison logic we swap i1.pc and i2.pc
        -- and then swap back in icfetch3.
        v.i2     := r.i1;
        v.i1     := r.i2;
        if icache_active(r) = '1' and r.imisspend = '1' then
          ocrami.itagen  := (others => '1');
          ocrami.idataen := (others => '1');
          v.i1ten := '1';
        end if;
        v.i1rep   := '0';
        -- Drive Dcache tag/data addresses
        ocrami.dtagcindex(d_sets'range)  := r.d2vaddr(d_index'range);
        ocrami.ddataindex(d_sets'range)  := r.d2vaddr(d_index'range);
        ocrami.ddataoffs(d_offset'range) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.ddatafulladdr             := r.d2vaddr(ocrami.ddatafulladdr'range);
        -- Temporarily swap d1 and d2 virt addresses for tag comparison in next state
        v.d1vaddr     := r.d2vaddr;
        v.d2vaddr     := r.d1vaddr;
        v.d1          := r.d2;
        v.d2          := r.d1;
        v.dtlbrecheck := '1';           -- To swap dci.write/dci.lock
        v.d1ten       := '0';
        -- Did we miss earlier and need to do a new tag check?
        if dcache_active(r) = '1' and not is_access_i(r.mmusel) and
           (r.dmisspend = '1' or r.slowwrpend = '1') then
          ocrami.dtagcen := (others => '1');
          ocrami.ddataen := (others => '1');
          v.d1ten        := '1';
        end if;

      when as_wptectag2 =>
        -- Write PTE and recheck tags stage 2 - tag check
        done           := false;
        v.s            := as_wptectag3;
        -- Continue PTE writeback
        if r.ahb.htrans = HTRANS_IDLE and r.ahb2.inacc = '0' then
          done         := true;
        elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '0' then
          -- Done!
          done         := true;
          if ahbi.hresp(0) = '1' then
            -- PTE writeback error
            v.werr     := '1';
          end if;
        elsif ahbi.hready = '0' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
          v.ahb.htrans := HTRANS_IDLE;
        elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
          v.ahb.htrans := HTRANS_NONSEQ;
        elsif ahbi.hready = '1' and r.granted = '1' then
          v.ahb.htrans := HTRANS_IDLE;
        end if;
        -- Check Icache tags
        if r.imisspend = '1' then
          oico.mds    := '0';
        end if;
        -- Swap back to get i1.pc
        v.i2          := r.i1;
        v.i1          := r.i2;
        v.i1ten       := '0';
        v.i2validv    := ivalidv;
        v.i2hitv      := ihitv;
        if ihit = '1' then
          v.imisspend := '0';
        end if;
        -- Check Dcache tags
        if r.dmisspend = '1' and r.d2tcmhit = '0' then
          odco.mds    := '0';
        end if;
        -- Swap back
        v.d1vaddr     := r.d2vaddr;
        v.d2vaddr     := r.d1vaddr;
        v.d1          := r.d2;
        v.d2          := r.d1;
        if r.d1ten = '1' then
          v.d2hitv    := dhitv;
          v.d2validv  := dvalidv;
        end if;
        ocrami.ddataen := (others => '0');
        ocrami.dtcmen  := '0';
        if dhit = '1' then
          if r.d2nocache = '0' and r.d2specialasi = '0' and r.d2forcemiss = '0' and r.d2lock = '0' then
            v.dmisspend := '0';
          end if;
          if r.d2tcmhit = '1' then
            v.dmisspend := '0';
          end if;
        end if;
        if r.d2write = '1' and r.d2specialasi = '0' and r.amo.d2type(5) = '0' then
          ocrami.ddataen(d_ways'range) := dhitv;
          ocrami.dtcmen                := r.d2tcmhit;
        end if;
        ocrami.ddatawrite := getdmask64(r.d1vaddr, r.d2size, ENDIAN_B);
        ocrami.ddatadin   := (others => r.d2data);
        v.d1ten           := r.d1chk and dcache_active(r);
        v.d1tcmen         := r.d1chk and dtcmact;
        v.ramreload       := '1';
        if done then
          v.s            := as_normal;
        end if;

      when as_wptectag3 =>
        -- Write PTE and recheck tags stage 3 - finish writeback
        done           := false;
        if r.ahb.htrans = HTRANS_IDLE and r.ahb2.inacc = '0' then
          done         := true;
        elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '0' then
          -- Done!
          done         := true;
          if ahbi.hresp(0) = '1' then
            -- PTE writeback error
            v.werr     := '1';
          end if;
        elsif ahbi.hready = '0' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
          v.ahb.htrans := HTRANS_IDLE;
        elsif ahbi.hready = '1' and r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
          v.ahb.htrans := HTRANS_NONSEQ;
        elsif ahbi.hready = '1' and r.granted = '1' then
          v.ahb.htrans := HTRANS_IDLE;
        end if;
        if done then
          v.s        := as_normal;
        end if;

      -- Stay in this state until store buffer is empty.
      when as_store =>
        do_access := true;
        if r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' and ahbi.hready = '0' then
          v.ahb.htrans   := HTRANS_IDLE;
          v.d2stba       := r.d2stba - 1;
        else
          if ahbi.hready = '1' and r.granted = '1' then
            if r.ahb.htrans(1) = '1' then
              v.d2stba   := r.d2stba + 1;
              if dcache_active(r) = '1' then
                v.ahb.snoopmask := (others => '1');
              end if;
            end if;
          end if;
          if ahbi.hready = '1' then
            v.d2stbd     := r.d2stba;
          end if;
          v.ahb.htrans   := HTRANS_IDLE;
          if v.d2stba /= r.d2stbw or r.stbuffull = '1' then
            v.ahb.htrans := HTRANS_NONSEQ;
          end if;
        end if;

        v.ahb.hwrite    := '1';
        v.ahb.haddr     := r.d2stbuf(u2i(v.d2stba)).addr(v.ahb.haddr'range);
        v.ahb.hsize     := '0' & r.d2stbuf(u2i(v.d2stba)).size;
        v.ahb.hwdata    := r.d2stbuf(u2i(v.d2stbd)).data;
        v.ahb.hburst    := HBURST_SINGLE;

        if v.d2stba /= r.d2stbw - 1 or r.stbuffull = '1' or fastwr = '1' then
          keepreq := '1';
        end if;

        if r.d2stbd /= r.d2stbw then
          v.stbuffull := '0';
        end if;
        if fastwr = '1' then
          v.d2stbw      := r.d2stbw + 1;
          if v.d2stbw = r.d2stbd then
            v.stbuffull := '1';
            v.perf(10)  := '1';
          end if;
        end if;

        if fastwr = '0' and r.stbuffull = '0' and r.d2stbd = r.d2stbw then
          do_access  := false;
          v.s        := as_normal;
          v.d2stbw   := "00";
          v.d2stba   := "00";
          v.d2stbd   := "00";
          store_done := true;
        end if;

      when as_slowwr =>
        -- Translate addr
        -- MMU permission check
        -- Check written flag
        -- Write burst on narrow bus
        -- Perform write
        v.mmusel          := access_w;
        -- Special access?
        if dspecialasi = '1' then
          v.s             := as_wrasi;
        elsif walk_pmp and (r.d2paddrv = '0' or r.d2tlbmod = '0') and not mmu_enabled(v.d2.mode) then
          start_pmp     := true;   -- See more after case.
        -- Miss or not written before.
        elsif mmuen = 1 and (r.d2paddrv = '0' or r.d2tlbmod = '0') then
          -- This will never happen without MMU enabled.
          if not is_riscv then
            v.ahb.haddr   := mmu_base(r, csro);
          end if;
          start_walk      := true;   -- See more after case.
--          v.s             := as_start_walk;
        -- 64 bit write on 32 bit bus?
        elsif r.d2size = "11" and r.d2busw = '0' then
          v.ahb.hbusreq   := '1';
          v.ahb.haddr     := r.d2paddr(v.ahb.haddr'range);
          v.ahb.hsize     := HSIZE_WORD;
          v.ahb.htrans    := HTRANS_NONSEQ;
          v.ahb.hburst    := HBURST_INCR;
          v.ahb.hwrite    := '1';
          do_access       := true;
          v.s             := as_wrburst;
          keepreq         := '1';
        -- Store buffer needs emptying
        else
          v.ahb.haddr     := r.d2paddr(v.ahb.haddr'range);
          v.ahb.hsize     := "0" & r.d2size;
          v.ahb.htrans    := HTRANS_NONSEQ;
          v.ahb.hburst    := HBURST_SINGLE;
          v.ahb.hwrite    := '1';
          v.d2stbuf(0).addr      := r.d2paddr;
          v.d2stbuf(0).size      := r.d2size;
          v.d2stbuf(0).data      := r.d2data;
          v.d2stbuf(0).snoopmask := r.ahb.snoopmask;
          v.d2stbw               := "01";
          do_access       := true;
          v.s             := as_store;
          v.slowwrpend    := '0';
          if r.d1ten = '1' then
            v.ramreload   := '1';
          end if;
        end if;

      -- 64 bit write to 32 bit bus using two word burst.
      when as_wrburst =>
        do_access := true;
        if ahbi.hresp(1) = '1' and r.ahb2.inacc = '1' then
          v.ahb.htrans      := HTRANS_IDLE;
        end if;
        if ahbi.hready = '1' then
          if r.granted = '1' and (ahbi.hresp(1) = '0' or r.ahb2.inacc = '0') and r.ahb.htrans(1) = '1' then
            v.ahb.haddr(2)  := not r.ahb.haddr(2);
            if r.ahb.haddr(2) = '1' then
              v.ahb.htrans  := HTRANS_IDLE;
            else
              v.ahb.htrans  := HTRANS_SEQ;
            end if;
            if (r.ahb.haddr(2) = '0') xor ENDIAN_B then
              v.ahb.hwdata  := hi_h(r.d2data) & hi_h(r.d2data);
            else
              v.ahb.hwdata  := lo_h(r.d2data) & lo_h(r.d2data);
            end if;
          elsif r.ahb2.inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb.haddr(2)  := not r.ahb.haddr(2);
            v.ahb.htrans    := HTRANS_NONSEQ;
          elsif r.ahb.htrans(1) = '0' then
            do_access       := false;
            v.s             := as_normal;
            v.slowwrpend    := '0';
            store_done      := true;
            if r.d1ten = '1' then
              v.ramreload   := '1';
            end if;
          end if;
        end if;
        if v.ahb.haddr(2) = '0' then
          keepreq           := '1';
        end if;

      -- Special writes
      when as_wrasi =>
        do_wrasi2     := true;
        v.s           := as_wrasi2;
        -- For next state in case of ASI 0xC-0xF
        v.flushctr    := r.d2vaddr(d_index'range);
        if MAXWAYS <= 4 then
          vtmp4i      := decwrap(get(r.d2vaddr, DOFFSET_HIGH + 1, 2), DWAYS);
        else
          vtmp4i      := (others => '0');
          vtmp4i(u2i(get(r.d2vaddr, DOFFSET_HIGH + 1, 3))) := '1';
        end if;
        v.d2hitv      := vtmp4i(d_ways'range);
        if MAXWAYS <= 4 then
          vtmp4i      := decwrap(get(r.d2vaddr, DOFFSET_HIGH + 1, 2), IWAYS);
        else
          vtmp4i      := (others => '0');
          vtmp4i(u2i(get(r.d2vaddr, DOFFSET_HIGH + 1, 3))) := '1';
        end if;
        v.i2hitv      := vtmp4i(i_ways'range);
        for x in 0 to LINESZMAX / 2 - 1 loop
          v.ahb3.rdbuf(x * 64 + 63 downto x * 64) := r.d2data;
        end loop;
        v.dregval64   := hi_h(r.d2data);
        v.dregval     := lo_h(r.d2data);
        v.ramreload   := '1';
        d32 := hi_h(r.d2data);
        if r.d2vaddr(2) = '1' xor ENDIAN_B then
          d32 := lo_h(r.d2data);
        end if;
        for w in d_ways'range loop
          v.dtagpipe(w)(TAG_HIGH - DTAG_LOW + 1 downto 1) := d32(d_tag'range);
          v.dtagpipe(w)(0) := d32(0);
        end loop;

        case r.d2.asi is
          when x"0c" =>                 -- ICache tags
            null;

          when x"0d" =>                 -- ICache data
            null;

          when x"0e" =>                 -- DCache tags
            if ext_noelv = 1 then
              if vs.dtwrite = '0' then
                vs.dtwrite    := '1';
                vs.dtaccidx   := r.d2vaddr(d_index'range);
                vs.dtaccways  := (others => '0');
                vs.dtaccways(u2i(get(r.d2vaddr, DOFFSET_HIGH + 1, 2))) := '1';
                vs.dtacctagmod := '0';
              else
                do_wrasi2 := false;
                v.s := r.s;
              end if;
            end if;

          when x"0f" =>                 -- DCache data
            null;

          when x"10" | x"13" =>         -- ICache+Dcache flush
            v.flushpart   := "11";
            v.dflushpend  := '1';
            v.iflushpend  := '1';
            v.flushctr    := (others => '0');
            v.slowwrpend  := '0';
            do_wrasi2     := false;
            v.s           := as_flush;
            v.perf(4)     := '1';

          when x"11" =>                 -- DCache flush
            v.dflushpend   := '1';
            v.flushpart(0) := '1';
            v.flushctr     := (others => '0');
            v.slowwrpend   := '0';
            do_wrasi2      := false;
            v.s            := as_flush;
            v.perf(4)      := '1';


          when x"18" | x"03" =>         -- Cache+TLB flush
            v.tlbflush   := "11";
            v.flushpart  := "11";
            v.dflushpend := '1';
            v.iflushpend := '1';
            v.flushctr   := (others => '0');
            v.slowwrpend := '0';
            do_wrasi2    := false;
            v.s          := as_flush;
            v.perf(4)    := '1';


          -- On RISC-V the access size defines the specific TLB flush:
          --   00 sfence.vma
          --   01 hfence.vvma
          --   10 hfence.gvma
          -- Also, parts of the access type are being used to tell the
          -- flush whether VMID/ASID and/or address should be checked.
          when x"1b" =>                 -- MMU flush/probe
            do_wrasi2        := false;
            v.s              := as_mmuflush2;
            if mmuen = 0 then
              v.ramreload    := '1';
              v.slowwrpend   := '0';
              v.s            := as_normal;
            end if;
            v.itlbprobeid    := (others => '0');
            v.d2tlbid        := (others => '0');
            v.h2tlbid        := (others => '0');
            if mmuen = 1 and is_riscv then
              if csro.mmu_oldfence = '1' then
                v.tlbflush   := "11";
                v.flushpart  := "11";  -- Should not be needed!
                v.dflushpend := '1';   -- Should not be needed!
                v.iflushpend := '1';   -- Should not be needed!
                v.flushctr   := (others => '0');
                v.slowwrpend := '0';
                v.s          := as_flush;
                v.perf(4)    := '1';
              else
                -- Set top data bits as not checking sTLB address, ASID, VMID, hTLB address.
                if r.d2size = "00" then                         -- sfence.vma
                  if ext_h = 1 and is_v(r.d2.mode) then
                    set_hi(v.d2data, r.d2.su & r.d2.m & "01");  --  Check current VMID when vs.
                    set(v.d2data, asidlen, get(mmu_ctx(r, csro), asidlen, vmidlen));
                  else
                    set_hi(v.d2data, r.d2.su & r.d2.m & "11");  --  Do not check VMID.
                  end if;
                elsif ext_h = 1 then
                  if r.d2size = "01" then                       -- hfence.vvma
                    set_hi(v.d2data, r.d2.su & r.d2.m & "01");  --  Check current VMID.
                    set(v.d2data, asidlen, get(mmu_ctx(r, csro), asidlen, vmidlen));
                  else  -- if r.d2size = "10" then              -- hfence.gvma
                    set_hi(v.d2data, "11" & r.d2.m & r.d2.su);
                    set(v.d2data, asidlen, get(r.d2data, 0, vmidlen));
                  end if;
                end if;
              end if;
            end if;

          when x"1c" =>                 -- MMU/Cache bypass
            if ext_noelv = 1 then
              -- Update registers and jump back to normal to handle in standard path
              v.d2paddr       := fit0ext(r.d2vaddr, v.d2paddr);
              v.d2paddrv      := '1';
              v.d2tlbmod      := '1';
              if not pmaen then
                v.d2busw      := dec_wbmask_fixed(r.d2vaddr(ahbo.haddr'high downto 2), wbmask);
              end if;
              v.d2.asi        := "000" & ASI_SDATA;
              v.d2specialasi  := '0';
              v.d2forcemiss   := '1';
              v.d2nocache     := '1';
              v.d2.su         := '1';
              v.d2hitv        := (others => '0');
              do_wrasi2       := false;
              if not pmaen then
                v.s           := as_normal;
              else
                -- v.pmp_mask is already set from above. Always 4 kByte.
                v.pmp_low     := fit0ext(v.d2paddr, v.pmp_low);
                v.pmp_do      := '1';
                v.s           := as_check_busw;
              end if;
            end if;

          when x"1e" =>                 -- Snoop tags
            if ext_noelv = 1 then
              if vs.stwrite = '0' and vs.stread = '0' then
                vs.stwrite    := '1';
                vs.staccidx   := r.d2vaddr(d_index'range);
                vs.staccways  := (others => '0');
                vs.staccways(u2i(get(r.d2vaddr, DOFFSET_HIGH + 1, 2))) := '1';
                vs.stacctag   := r.d2data(32 + TAG_HIGH downto 32 + DTAG_LOW);
              else
                do_wrasi2     := false;
                v.s           := r.s;
              end if;
            end if;


          when x"23" =>                 -- TLB diagnostic access
            if (mmuen = 1 or walk_pmp) and (ext_noelv = 1 or not is_riscv) then
              -- RISC-V needs extra bits from an ASI write to 0x2f!
              -- d2vaddr( downto 12)  - vaddr (RISC-V)
              -- d2vaddr(11)          - Together with x below - 2 MSBs for hTLB (RISC-V)
              -- d2vaddr(10 downto 9) - 00 - dTLB, 10 - iTLB, x1 - hTLB (RISC-V, else (9) - iTLB)
              -- d2vaddr(8)           - PMRU state
              -- d2vaddr(7 downto 3)  - entry
              if not is_riscv then
                if r.d2vaddr(9) = '0' then
                  v.newent := r.dtlb(u2i(r.d2vaddr(2 + log2x(dtlbnum) downto 3)));
                else
                  v.newent := r.itlb(u2i(r.d2vaddr(2 + log2x(itlbnum) downto 3)));
                end if;
              end if;
              if r.d2vaddr(8) = '0' then
                if not is_riscv then
                  if r.d2vaddr(2) = '0' or r.d2size = "11" then
                    v.newent.vaddr     := get(r.d2data, 32 + 12, 20);
                    v.newent.ctx       := get(r.d2data, 32 + 4, v.newent.ctx);
                    v.newent.mask(1)   := r.d2data(32 + 3);
                    v.newent.mask(2)   := r.d2data(32 + 2);
                    v.newent.valid     := r.d2data(32 + 0);
                  end if;
                  if r.d2vaddr(2) = '1' or r.d2size = "11" then
                    v.newent.paddr     := get(r.d2data, 12, 20);
                    v.newent.acc       := get(r.d2data, 3, 3);
                    v.newent.busw      := r.d2data(2);
                    v.newent.cached    := r.d2data(1);
                    v.newent.modified  := r.d2data(0);
                  end if;
                else
                  -- Use high part from 0x2f ASI data on RV32.
                  d64 := r.d2data;
                  if riscv_mmu = Sv32 then
                    set_hi(d64, r.dregval64);
                  end if;
                  -- Use low part from 0x2f ASI for VMID/ASID.
                  v.newent.ctx        := get_lo(r.dregval, v.newent.ctx'length);

                  v.newent.vaddr      := uext(r.d2vaddr(vpn'range), v.newent.vaddr);
                  -- A guest physical address "as virtual" in hTLB has two extra bits.
                  if ext_h = 1 and r.d2vaddr(9) = '1' then
                    set_hi(v.newent.vaddr, r.d2vaddr(11 downto 10));
                  end if;
                  v.newent.paddr      := d64(v.newent.paddr'range);

                  v.newent.valid      := d64(rv_pte_v);  -- PTE-A below is "S"
                  if mmuen = 1 then
                    v.newent.perm     := d64(rv_pte_a) & d64(rv_pte_u downto rv_pte_r);
                    -- Save the G bit (5) for later use.
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
                  -- Save the N bit (63) for later use.

                  if ext_h = 1 and (pmpen or pmaen) then
                    v.newent.h_r      := r.aregval(28);
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
                  v.newent.acc       := (others => '0');
                end if;
                if is_riscv and ext_h = 1 then
                  v.hnewent          := v.newent;
                  if r.d2vaddr(9) = '0' then
                    v.tlbupdate      := '1';
                  else
                    v.h2tlbupd       := '1';
                  end if;
                else
                  v.tlbupdate        := '1';
                end if;
                v.i2tlbid            := r.d2vaddr(2 + log2x(itlbnum) downto 3);
                v.d2tlbid            := r.d2vaddr(2 + log2x(dtlbnum) downto 3);
                v.h2tlbid            := r.d2vaddr(2 + log2x(htlbnum) downto 3);
                v.mmusel(0)          := not r.d2vaddr(10);  -- 0 - I, 1 - D
                v.i2tlbhit           := r.d2vaddr(10);
                v.d2tlbhit           := not r.d2vaddr(10);
              else
                if is_riscv then
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
                else
                  if r.d2vaddr(9) = '0' then
                    v.dtlbpmru := get(r.d2data, 32, v.dtlbpmru);
                  else
                    v.itlbpmru := get(r.d2data, 32, v.itlbpmru);
                  end if;
                end if;
              end if;
              v.s := as_wrasi2;
            end if;

          when x"24" =>                 -- BTB/BHT diagnostic access
            if ext_noelv = 1 then
              do_wrasi2               := false;
              v.s                     := as_wrasi;
              v.iudiag_mosi.accen     := '1';
              v.iudiag_mosi.accwr     := '1';
              if r.iudiag_mosi.accen = '0' then
                v.iudiag_mosi.addr(0) := r.d2vaddr(2);
              elsif r.iudiag_mosi.accen = '1' and dci.iudiag_miso.accrdy = '1' and r.d2size = "11" then
                v.iudiag_mosi.addr(0) := '1';
              end if;
              if v.iudiag_mosi.addr(0) = '0' xor ENDIAN_B then
                v.iudiag_mosi.wrdata  := hi_h(r.d2data);
              else
                v.iudiag_mosi.wrdata  := lo_h(r.d2data);
              end if;
              if r.iudiag_mosi.accen = '1' and dci.iudiag_miso.accrdy = '1' then
                v.dregval64           := r.dregval;
                v.dregval             := dci.iudiag_miso.rddata;
                if r.d2size /= "11" or r.iudiag_mosi.addr(0) = '1' then
                  v.s                 := as_wrasi3;
                  v.iudiag_mosi.accen := '0';
                end if;
              end if;
            end if;

          when x"25" =>                 -- Cache LRU diagnostic interface
            if ext_noelv = 1 then
              if r.d2vaddr(31) = '1' then
                v.ilru(u2i(r.d2vaddr(i_index'range))) :=
                  r.d2data(32 + v.ilru(0)'high downto 32 + 0);
              else
                v.dlru(u2i(r.d2vaddr(d_index'range))) :=
                  r.d2data(32 + v.dlru(0)'high downto 32 + 0);
              end if;
              v.s := as_wrasi2;
            end if;

          when x"26" =>                 -- Instruction TCM access
            if ext_noelv = 1 then
              v.s := as_wrasi2;
            end if;

          when x"27" =>                 -- Data TCM access
            if ext_noelv = 1 then
              v.s := as_wrasi2;
            end if;

          when x"2e" =>                 -- PMP MMUU test
            if (mmuen = 1 or walk_pmp) and ext_noelv = 1 then
              if is_riscv then
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
                  -- Use high part from 0x2f ASI data on RV32.
                  d64 := r.d2data;
                  if riscv_mmu = Sv32 then
                    set_hi(d64, r.dregval64);
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
              end if;
              v.s := as_wrasi2;
            end if;

          when x"2f" =>                 -- Extra 64 bits of ASI data
            if ext_noelv = 1 then
              -- Get a bunch of bits from the address.
              v.aregval := r.d2vaddr(31 downto 0);
              if is_riscv then
                -- 32 bit access?
                if r.d2size /= "11" then
                  v.dregval   := r.d2data(31 downto 0);
                  v.dregval64 := r.dregval;
                else
                  v.dregval   := r.d2data(31 downto 0);
                  v.dregval64 := r.d2data(63 downto 32);
                end if;
              end if;
              v.s := as_wrasi2;
            end if;

          when others =>
            v.dregerr := '1';
        end case;

        if do_wrasi2 then
          v.irdbufvaddr := r.d2vaddr(r.irdbufvaddr'range);
          v.iramaddr    := r.d2vaddr(r.iramaddr'range);
        end if;

      when as_wrasi2 =>
        if ext_noelv = 1 then
          v.s                               := as_wrasi3;
          v.ramreload                       := r.ramreload;
          ocrami.iindex(i_sets'range)       := r.irdbufvaddr(i_index'range);
          ocrami.idataoffs(i_offset'range)  := r.iramaddr;
          if r.d2vaddr(2) = '1' then
            for w in i_ways'range loop
              ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW + 1 downto 1)  := r.dregval(i_tag'range);
              ocrami.itagdin(w)(0)                                 := r.dregval(0);
            end loop;
          else
            for w in i_ways'range loop
              ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW + 1 downto 1) := r.dregval64(i_tag'range);
              ocrami.itagdin(w)(0)                                := r.dregval64(0);
            end loop;
          end if;
          ocrami.idatadin                   := r.dregval64 & r.dregval;
          ocrami.dtagcindex(d_sets'range)   := r.d2vaddr(d_index'range);
          ocrami.ddataindex(d_sets'range)   := r.d2vaddr(d_index'range);
          ocrami.ddataoffs(d_offset'range)  := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
          if all_0(rs.s3hit) then
            ocrami.dtaguindex(d_sets'range) := r.flushctr(d_sets'range);
            if r.d2vaddr(2) = '1' then
              for w in d_ways'range loop
                ocrami.dtagudin(w)(TAG_HIGH - DTAG_LOW + 1 downto 1) := r.dregval(d_tag'range);
                ocrami.dtagudin(w)(0)                                := r.dregval(0);
              end loop;
            else
              for w in d_ways'range loop
                ocrami.dtagudin(w)(TAG_HIGH - DTAG_LOW + 1 downto 1) := r.dregval64(d_tag'range);
                ocrami.dtagudin(w)(0)                                := r.dregval64(0);
              end loop;
            end if;
          end if;
          if all_0(rs.s1en) then
            ocrami.dtagsindex(d_sets'range) := r.flushctr(d_sets'range);
          end if;
          ocrami.ifulladdr     := r.d2vaddr(ocrami.ifulladdr'range);
          ocrami.ddatafulladdr := r.d2vaddr(ocrami.ddatafulladdr'range);
          v.dtagpipe           := r.dtagpipe;

          case r.d2.asi is
          when x"0c" =>                 -- ICache tags
            ocrami.itagen(i_ways'range)  := r.i2hitv;
            ocrami.itagwrite             := '1';
          when x"0d" =>                 -- ICache data
            ocrami.idataen(i_ways'range) := r.i2hitv;
            ocrami.idatawrite            := "00";
            if (r.d2vaddr(2) = '0' xor ENDIAN_B) or r.d2size = "11" then
              ocrami.idatawrite(1)       := '1';
            end if;
            if (r.d2vaddr(2) = '1' xor ENDIAN_B) or r.d2size = "11" then
              ocrami.idatawrite(0)       := '1';
            end if;
          when x"0e" =>                 -- DCache tags
            -- Wait for write to complete in snoop tag pipeline
            if rs.dtwrite = '1' then
              v.s := r.s;
            end if;
          when x"0f" =>                 -- DCache data
            ocrami.ddataen(d_ways'range)    := r.d2hitv;
            if (r.d2vaddr(2) = '0' xor ENDIAN_B) or r.d2size = "11" then
              ocrami.ddatawrite(7 downto 4) := "1111";
            end if;
            if (r.d2vaddr(2) = '1' xor ENDIAN_B) or r.d2size = "11" then
              ocrami.ddatawrite(3 downto 0) := "1111";
            end if;
          when x"1e" =>                 -- Snoop tags
            -- Wait for write to complete in snoop tag pipeline
            if rs.stwrite = '1' then
              v.s := r.s;
            end if;
          when x"26" =>                 -- Instruction TCM
            ocrami.itcmen          := '1';
            ocrami.idatawrite      := "00";
            if (r.d2vaddr(2) = '0' xor ENDIAN_B) or r.d2size = "11" then
              ocrami.idatawrite(1) := '1';
            end if;
            if (r.d2vaddr(2) = '1' xor ENDIAN_B) or r.d2size = "11" then
              ocrami.idatawrite(0) := '1';
            end if;
          when x"27" =>                 -- Data TCM
            ocrami.dtcmen := '1';
            if (r.d2vaddr(2) = '0' xor ENDIAN_B) or r.d2size = "11" then
              ocrami.ddatawrite(7 downto 4) := "1111";
            end if;
            if (r.d2vaddr(2) = '1' xor ENDIAN_B) or r.d2size = "11" then
              ocrami.ddatawrite(3 downto 0) := "1111";
            end if;
          when others =>
            null;
          end case;

          v.ahb3.error := r.dregerr;
        end if;

      when as_wrasi3 =>
        if ext_noelv = 1 then
          v.ramreload  := r.ramreload;
          odco.mds     := '0';
          d_mexc       := r.ahb3.error;
          v.slowwrpend := '0';
          v.s          := as_normal;
        end if;

      -- Special reads
      when as_rdasi =>
        if ext_noelv = 1 then
          do_rdcdiag    := false;
          v.dregval     := (others => '0');
          case r.d2.asi is

          when x"0c" =>                 -- ICache tags
            do_rdcdiag := true;
            v.s        := as_rdcdiag;

          when x"0d" =>                 -- ICache data
            do_rdcdiag := true;
            v.s        := as_rdcdiag;

          when x"0e" =>                 -- DCache tags
            do_rdcdiag := true;
            v.s        := as_rdcdiag;

          when x"0f" =>                 -- DCache data
            do_rdcdiag := true;
            v.s        := as_rdcdiag;


          when x"1b" =>                 -- MMU flush/probe
            if mmuen = 1 then
              if r.d2vaddr(11) = '1' or (r.d2vaddr(10) = '1' and r.d2vaddr(9 downto 8) /= "00") then
                -- Undefined probe type -- return 0
                v.dregval := (others => '0');
                v.s       := as_rdasi2;
              elsif r.d2vaddr(10) = '1' then
                -- Return data from DTLB if address matched and "entire" mode
                if r.d2tlbamatch = '1' then
                  v.dregval(31 downto 28) := "0000";
                  v.dregval(7)          := r.dtlb(u2i(r.d2tlbid)).cached;
                  v.dregval(6)          := r.dtlb(u2i(r.d2tlbid)).modified;
                  v.dregval(5)          := '1';    -- referenced
                  v.dregval(4 downto 2) := r.dtlb(u2i(r.d2tlbid)).acc;
                  v.dregval(1 downto 0) := "10";  -- PTE
                  v.s                   := as_rdasi2;
                else
                  -- Try reading from ITLB
                  v.s       := as_mmuprobe2;
                  v.i1.pc   := r.d2vaddr;
                  v.d2vaddr := r.i1.pc;
                end if;
              elsif not is_riscv then
                -- Fall back to MMU walk
                start_walk  := true;
--              v.s         := as_start_walk;
                v.mmusel    := access_asi_walk;
                if not is_riscv then
                  v.ahb.haddr := mmu_base(r, csro);
                end if;
              else
                v.dregerr   := '1';
                v.s         := as_rdasi2;
              end if;
            end if;

          when x"1c" =>                 -- MMU/Cache bypass
            -- Update registers and jump back to normal to handle in standard path
            v.d2paddr      := fit0ext(r.d2vaddr, v.d2paddr);
            v.d2paddrv     := '1';
            if not pmaen then
              v.d2busw     := dec_wbmask_fixed(r.d2vaddr(ahbo.haddr'high downto 2), wbmask);
            end if;
            v.d2.asi       := "000" & ASI_SDATA;
            v.d2specialasi := '0';
            v.d2.su        := '1';
            v.d2hitv       := (others => '0');
            v.d2nocache    := '1';
            if not pmaen then
              v.s          := as_normal;
            else
              -- v.pmp_mask is already set from above. Always 4 kByte.
              v.pmp_low    := fit0ext(v.d2paddr, v.pmp_low);
              v.pmp_do     := '1';
              v.s          := as_check_busw;
            end if;

          when x"1e" =>                 -- Snoop tags
            do_rdcdiag := true;
            v.s        := as_rdcdiag;


          when x"23" =>                 -- TLB diagnostic access
            if (mmuen = 1 or walk_pmp) and (ext_noelv = 1 or not is_riscv) then
              -- d2vaddr(11)         - paddr instead of vaddr (RISC-V)
              -- d2vaddr(10)         - H (RISC-V)
              -- d2vaddr(9)          - I / D
              -- d2vaddr(8)          - PMRU state, and VMID/ASID (RISC-V)
              -- d2vaddr(7 downto 3) - entry
              v.dregval := (others => '0');
              if is_riscv then
                if r.d2vaddr(9) = '1' then
                  entry   := r.htlb(u2i(r.d2vaddr(2 + log2x(htlbnum) downto 3)));
                else
                  if r.d2vaddr(10) = '0' then
                    entry := r.dtlb(u2i(r.d2vaddr(2 + log2x(dtlbnum) downto 3)));
                  else
                    entry := r.itlb(u2i(r.d2vaddr(2 + log2x(itlbnum) downto 3)));
                  end if;
                end if;
              else
                if r.d2vaddr(9) = '0' then
                  entry := r.dtlb(u2i(r.d2vaddr(2 + log2x(dtlbnum) downto 3)));
                else
                  entry := r.itlb(u2i(r.d2vaddr(2 + log2x(itlbnum) downto 3)));
                end if;
              end if;
              if r.d2vaddr(8) = '0' then
                if not is_riscv then
                  if r.d2vaddr(2) = '0' then
                    v.dregval(31 downto 12) := entry.vaddr;
                    v.dregval(11 downto 4)  := entry.ctx;
                    v.dregval(3)            := entry.mask(1);
                    v.dregval(2)            := entry.mask(2);
                    v.dregval(1)            := entry.mask(3);
                    v.dregval(0)            := entry.valid;
                  else
                    v.dregval(31 downto 12) := entry.paddr;
                    v.dregval(5 downto 3)   := entry.acc;
                    v.dregval(2)            := entry.busw;
                    v.dregval(1)            := entry.cached;
                    v.dregval(0)            := entry.modified;
                  end if;
                else
                  d64                       := (others => '0');

                  if r.d2vaddr(11) = '0' then
                    d64(entry.vaddr'range)    := entry.vaddr;

                    d64(rv_pte_v)             := entry.valid;
                    if mmuen = 1 then
                      d64(rv_pte_u downto rv_pte_r) := get_lo(entry.perm, 4);
                      -- Save the G bit (5) for later use.
                      d64(rv_pte_a)             := get_hi(entry.perm);  -- "S"
                      d64(rv_pte_d)             := entry.modified;
                    end if;
                    -- The RSW bits are for software, so free to use.
                    -- Also, address shifted up by two compared to PTE,
                    -- to fit with paddr'range, giving two more bits.
                    -- Enough mask bits for up to Sv48.
                    d64(rv_pte_rsw'low + entry.mask'length - 1 downto rv_pte_rsw'low) := entry.mask;
                    if ext_h = 1 and (pmpen or pmaen) then
                      d64(rv_pte_pbmt'low - 11) := entry.h_r;
                      d64(rv_pte_pbmt'low - 10) := entry.pmp_r;
                      d64(rv_pte_pbmt'low - 9)  := entry.pmp_no_w;
                      d64(rv_pte_pbmt'low - 8)  := entry.pmp_no_x;
                    end if;
                    -- Save two bits here for later.
                    d64(rv_pte_pbmt'low - 5)  := entry.cached;
                    d64(rv_pte_pbmt'low - 4)  := entry.busw;
                    d64(rv_pte_pbmt'low - 1 downto rv_pte_pbmt'low - 3) := entry.mode;
                    if ext_svpbmt = 1 then
                      d64(rv_pte_pbmt'range)    := entry.pbmt;
                    end if;
                    -- Save the N bit (63) for later use.
                  else
                    d64(entry.paddr'range)   := entry.paddr;

                    if pmaen then
                      assert PMA_SIZE <= 12 report "Too large PMA" severity failure;
                      d64(PMA_SIZE - 1 downto 0)  := from_pma(entry.pma);
                    end if;
                    if walk_pmp then
                      d64(59)           := entry.pmp_none;
                      d64(60)           := entry.pmp_lock;
                      d64(63 downto 61) := entry.pmp_rwx;
                    end if;
                  end if;

                  v.dregval64 := hi_h(d64);
                  v.dregval   := lo_h(d64);
                end if;
              else
                if is_riscv and mmuen = 1 then
                  v.dregval64 := uext(entry.ctx, v.dregval64);
                end if;
                if is_riscv then
                  -- This returns PMRU with TLB entry n represented by bit n.
                  if ext_h = 1 and r.d2vaddr(9) = '1' then
                    v.dregval   := uext(make_downto0(r.htlbpmru), v.dregval);
                  else
                    if r.d2vaddr(10) = '0' then
                      v.dregval := uext(make_downto0(r.dtlbpmru), v.dregval);
                    else
                      v.dregval := uext(make_downto0(r.itlbpmru), v.dregval);
                    end if;
                  end if;
                else
                  if r.d2vaddr(9) = '0' then
                    v.dregval := uext(r.dtlbpmru, v.dregval);
                  else
                    v.dregval := uext(r.itlbpmru, v.dregval);
                  end if;
                end if;
              end if;
              v.s := as_rdasi2;
            end if;

          when x"24" =>                 -- IU BTB/BHT diagnostic interface
            v.dregval               := r.dregval;
            v.iudiag_mosi.accen     := '1';
            v.iudiag_mosi.accwr     := '0';
            if r.iudiag_mosi.accen = '0' then
              v.iudiag_mosi.addr(0) := r.d2vaddr(2);
            elsif r.iudiag_mosi.accen = '1' and dci.iudiag_miso.accrdy = '1' and r.d2size = "11" then
              v.iudiag_mosi.addr(0) := '1';
            end if;
            if r.iudiag_mosi.accen = '1' and dci.iudiag_miso.accrdy = '1' then
              if not ENDIAN_B then
                v.dregval64         := r.dregval;
                v.dregval           := dci.iudiag_miso.rddata;
              else
                v.dregval           := r.dregval64;
                v.dregval64         := dci.iudiag_miso.rddata;
              end if;
              if r.d2size /= "11" or r.iudiag_mosi.addr(0) = '1' then
                v.s                 := as_rdasi2;
                v.iudiag_mosi.accen := '0';
              end if;
            end if;

          when x"25" =>                 -- Cache LRU diagnostic interface
            if r.d2vaddr(31) = '1' then
              v.dregval(ilruent'range) := ilruent;
            else
              v.dregval(dlruent'range) := dlruent;
            end if;
            v.s := as_rdasi2;

          when x"26" =>                 -- Instruction TCM access
            if itcmen = 0 then
              v.dregerr  := '1';
              v.s        := as_rdasi2;
            else
              do_rdcdiag := true;
              v.s        := as_rdcdiag;
            end if;

          when x"27" =>                 -- Data TCM access
            if dtcmen = 0 then
              v.dregerr := '1';
              v.s       := as_rdasi2;
            else
              do_rdcdiag := true;
              v.s        := as_rdcdiag;
            end if;

          when x"2e" =>                 -- Data output from PMUU test etc
            if (mmuen = 1 or walk_pmp) and is_riscv then
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
              v.dregval64 := hi_h(d64);
              v.dregval   := lo_h(d64);
            end if;
            v.s := as_rdasi2;

          when x"2f" =>                 -- Extra 64 bits of ASI data
            if is_riscv then
              -- 32 bit access?
              if r.d2size /= "11" then
                -- Read high part, assuming that low was read
                -- by another ASI earlier.
                -- Swap words to enable other half to be read later.
                v.dregval   := r.dregval64;
                v.dregval64 := r.dregval;
              end if;
            end if;
            v.s := as_rdasi2;

          when others =>                -- Unimplemented ASI
            v.dregerr := '1';
            v.s       := as_rdasi2;
          end case;
          if do_rdcdiag then
            -- Set irdbufaddr/iramaddr regs for Icache diag accesses
            v.irdbufvaddr := r.d2vaddr(r.irdbufvaddr'range);
            v.iramaddr    := r.d2vaddr(r.iramaddr'range);
          end if;
        end if;

      when as_rdasi2 =>
        if r.d2size = "11" then
          v.ahb3.rdbuf(LINESZMAX * 32 - 1 downto LINESZMAX * 32 - 64) := r.dregval64 & r.dregval;
        else
          v.ahb3.rdbuf(LINESZMAX * 32 - 1 downto LINESZMAX * 32 - 64) := r.dregval & r.dregval;
        end if;
        v.ahb3.error := r.dregerr;
        v.s          := as_rdasi3;

      when as_rdasi3 =>
        odco.data(0) := r.ahb3.rdbuf(LINESZMAX * 32 - 1 downto LINESZMAX * 32 - 64);
        odco.way     := (others => '0');
        odco.mds     := '0';
        d_mexc       := r.ahb3.error;
        v.dmisspend  := '0';
        v.s          := as_normal;

      when as_rdcdiag =>
        if ext_noelv = 1 then
          ocrami.iindex(i_sets'range)       := r.irdbufvaddr(i_index'range);
          ocrami.idataoffs(i_offset'range)  := r.iramaddr;
          ocrami.ifulladdr                  := r.d2vaddr(ocrami.ifulladdr'range);
          ocrami.itagen                     := (others => '1');
          ocrami.idataen                    := (others => '1');
          ocrami.itcmen                     := '1';
          ocrami.dtagcindex(d_sets'range)   := r.d2vaddr(d_index'range);
          ocrami.ddataindex(d_sets'range)   := r.d2vaddr(d_index'range);
          ocrami.ddataoffs(d_offset'range)  := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
          ocrami.ddatafulladdr              := r.d2vaddr(ocrami.ddatafulladdr'range);
          ocrami.dtagcen                    := (others => '1');
          ocrami.ddataen                    := (others => '1');
          ocrami.dtcmen                     := '1';
          v.s := as_rdcdiag2;
          if r.d2.asi = x"1e" then          -- Snoop tags?
            if vs.stread = '0' and vs.stwrite = '0' then
              vs.stread    := '1';
              vs.staccidx  := r.d2vaddr(d_index'range);
              vs.staccways := (others => '0');
              vs.staccways(u2i(get(r.d2vaddr, DTAG_LOW, 2))) := '1';
            else
              v.s := as_rdcdiag;
            end if;
          end if;
        end if;

      when as_rdcdiag2 =>
        if ext_noelv = 1 then
          v.s        := as_rdasi2;
          vdiagasi   := r.d2.asi(5) & r.d2.asi(4) & r.d2.asi(1 downto 0);
          case vdiagasi is
          when "0000" | "0100" | "1000" | "1100" =>                  -- 0x0C ICache tags
            d32 := cramo.itagdout(u2i(get(r.d2vaddr, ITAG_LOW, 2)));
            v.dregval                           := (others => '0');
            v.dregval(TAG_HIGH downto ITAG_LOW) := d32(TAG_HIGH - ITAG_LOW + 1 downto 1);
            v.dregval(7 downto 0)               := (others => d32(0));
          when "0001" | "0101" | "1001" | "1101" =>                  -- 0x0D ICache data
            d64 := cramo.idatadout(u2i(get(r.d2vaddr, ITAG_LOW, 2)));
            if (r.d2vaddr(2) = '0') xor ENDIAN_B then
              if r.d2write = '0' then
                v.dregval   := hi_h(d64);
              else
                v.dregval   := lo_h(d64);
              end if;
            else
              if r.d2write = '0' then
                v.dregval   := lo_h(d64);
                v.dregval64 := hi_h(d64);
              else
                v.dregval64 := hi_h(d64);
              end if;
            end if;
          when "0010" =>                  -- 0x0E DCache tags
            d32   := dctagsv(u2i(get(r.d2vaddr, DTAG_LOW, 2)));
            v.dregval              := (others => '0');
            v.dregval(d_tag'range) := d32(TAG_HIGH - DTAG_LOW + 1 downto 1);
            v.dregval(7 downto 0)  := (others => d32(0));
          when "0110" | "1110"            =>  -- 0x1E snoop tags
            d32   := dctagsv(u2i(get(r.d2vaddr, DTAG_LOW, 2)));
            v.dregval              := (others => '0');
            v.dregval(d_tag'range) := d32(TAG_HIGH - DTAG_LOW + 1 downto 1);
            v.dregval(7 downto 0)  := (others => d32(0));
            if rs.strddone = '1' then
              v.dregval              := (others => '0');
              v.dregval(d_tag'range) := rs.stacctag;
            else
              v.s := r.s;
            end if;
          when "1010" =>                -- 0x26 ITCM
            d64 := cramo.itcmdout;
            if (r.d2vaddr(2) = '0') xor ENDIAN_B then
              v.dregval := hi_h(d64);
            else
              v.dregval := lo_h(d64);
            end if;
            v.dregval64 := hi_h(d64);
          when "1011" =>                -- 0x27 DTCM
            d64 := cramo.dtcmdout;
            if (r.d2vaddr(2) = '0') xor ENDIAN_B then
              v.dregval := hi_h(d64);
            else
              v.dregval := lo_h(d64);
            end if;
            v.dregval64 := hi_h(d64);
          when others =>                -- 0x0F DCache data
            d64 := cramo.ddatadout(u2i(get(r.d2vaddr, DTAG_LOW, 2)));
            if (r.d2vaddr(2) = '0') xor ENDIAN_B then
              v.dregval := hi_h(d64);
            else
              v.dregval := lo_h(d64);
            end if;
            v.dregval64 := hi_h(d64);
          end case;
          -- Must set ramreload here since we have done a Itag read from another addr
          v.ramreload := '1';
        end if;

      when as_check_busw =>
        if pmaen then
          v.d2busw := pma_busw(v.pma);
          v.s      := as_normal;
        else
          v.s      := as_normal;
        end if;

      when as_getlock =>
        if r.granted = '1' then
          v.s := as_normal;
        end if;

      when as_amo =>
        if ext_a /= 0 then
          amo_snoop         := '0';
          v.mmusel          := access_w;
          -- Need to have the physical address to handle atomics
          if walk_pmp and (r.d2paddrv = '0' or r.d2tlbmod = '0') and not mmu_enabled(v.d2.mode) then
            start_pmp     := true;   -- See more after case.
          elsif mmuen = 1 and (r.d2paddrv = '0' or r.d2tlbmod = '0') then
            -- This will never happen without MMU enabled.
            if not is_riscv then
              v.ahb.haddr   := mmu_base(r, csro);
            end if;
            start_walk      := true;   -- See more after case.
--            v.s             := as_start_walk;
          -- SC:
          elsif r.amo.d2type(1 downto 0) = "11" then -- SC
            v.amo.d2type    := (others => '0');
            v.amo.reserved  := '0';
            odco.way        := (others => '0');
            odco.mds        := '0';
            odco.data(0)    := (others => '0');
            -- Cancel SC: if valid, need to invalidate reservation
            if (r.amo.reserved = '0' or r.d2paddr(v.ahb.haddr'range) /= r.amo.addr) then
              v.slowwrpend       := '0';
              v.amo.reserved     := '0';
              v.s                := as_normal;
              odco.data(0)(0)    := '1';
              if r.d2size = "10" then
                odco.data(0)(32) := '1';
              end if;
            else
              v.s        := as_slowwr;
              v.amo.hold := '1';
              v.amo.sc   := '1';
              amo_snoop  := '1';
            end if;
          else                                    -- AMO
            v.s        := as_slowwr;
            v.amo.hold := '1';
            v.d2data   := amo_data;
            amo_snoop  := '1';
          end if;
          -- Force a snooping hit on all atomics writes
          vs.s1en    := (others => amo_snoop);
          vs.s1haddr := (others => '0');
          vs.s1haddr(rs.s1haddr'high downto d_tag'low) := r.d2paddr(rs.s1haddr'high downto d_tag'low);
          vs.s1haddr(d_index'range)                    := r.d2paddr(d_index'range);
          vs.s1read := '0';
        else
          v.s := as_normal;
        end if;

      when as_cbo =>
        if ext_zicbom /= 0 then
          -- Miss before.
          v.mmusel             := access_w;
          if walk_pmp and r.d2paddrv = '0' and not mmu_enabled(v.d2.mode) then
            start_pmp     := true;   -- See more after case.
          elsif mmuen = 1 and r.d2paddrv = '0' then
            -- This will never happen without MMU enabled.
            if not is_riscv then
              v.ahb.haddr      := mmu_base(r, csro);
            end if;
            start_walk         := true;   -- See more after case.
          else
            if rs.dtwrite = '0' or all_0(r.d2hitv) then
              if not all_0(r.d2hitv) then
                vs.dtwrite     := '1';
                vs.dtaccidx    := r.d2paddr(d_index'range);
                vs.dtaccways   := r.d2hitv;
                vs.dtacctagmod := '1';
                -- Reuse same tags
                for x in d_ways'range loop
                  vs.dtacctagmsb(2 * x + 1 downto 2 * x) :=
                   r.dtagpipe(x)(TAG_HIGH - DTAG_LOW + 1 downto TAG_HIGH - DTAG_LOW);
                end loop;
                --vs.dtacctagmsb := r.untagd;
                vs.dtacctaglsb := (others => '0');
 
                v.dtagpipe := r.dtagpipe;
                v.ramreload := '1';
              end if;
              v.cbo.d2type(2)  := '0';
              v.s              := as_normal;
              v.slowwrpend     := '0';
              v.cbo.hold       := '1';
            end if;
          end if;
        else
          v.s          := as_normal;
          v.slowwrpend := '0';
        end if;

      when as_parked =>
        oico.parked := '1';
        -- Check on hready to ensure r.granted status is up to date in case we were
        -- clock gated while parked.
        if ici.parkreq = '0' and ahbi.hready = '1' then
          v.s := as_normal;
        end if;

      when as_mmuprobe2 =>
        if ext_noelv = 1 and mmuen = 1 then
          -- Swap back addresses
          v.i1.pc         := r.d2vaddr;
          v.d2vaddr       := r.i1.pc;
          -- Check if ITLB hit
          if itlbchk.amatch = '1' then
            v.s           := as_mmuprobe3;
          elsif not is_riscv then
            -- Fall back to MMU walk
            start_walk    := true;
--          v.s           := as_start_walk;
            v.mmusel      := access_asi_walk;
            if not is_riscv then
              v.ahb.haddr := mmu_base(r, csro);
            end if;
          else
            v.dregerr     := '1';
            v.s           := as_rdasi2;
          end if;
        end if;

      when as_mmuprobe3 =>
        if ext_noelv = 1 and mmuen = 1 then
          v.dregval(31 downto 28) := "0000";
          v.dregval(7)            := r.dtlb(u2i(r.itlbprobeid)).cached;
          v.dregval(6)            := r.dtlb(u2i(r.itlbprobeid)).modified;
          v.dregval(5)            := '1';    -- Referenced
          v.dregval(4 downto 2)   := r.dtlb(u2i(r.itlbprobeid)).acc;
          v.dregval(1 downto 0)   := "10";   -- PTE
          v.s                     := as_rdasi2;
        end if;

      when as_mmuflush2 =>
        if not is_riscv then
          v.itlbprobeid  := uadd(r.itlbprobeid, 1);
          v.d2tlbid      := uadd(r.d2tlbid, 1);
          if flushmatch(r.itlb(u2i(r.itlbprobeid)), r.d2vaddr, mmu_ctx(r, csro)) then
            v.itlb(u2i(r.itlbprobeid)).valid := '0';
          end if;
          if flushmatch(r.dtlb(u2i(r.d2tlbid)), r.d2vaddr, mmu_ctx(r, csro)) then
            v.dtlb(u2i(r.d2tlbid)).valid     := '0';
          end if;
          if (dtlbnum >= itlbnum and all_1(r.d2tlbid)) or
             (dtlbnum  < itlbnum and all_1(r.itlbprobeid)) then
            v.s          := as_normal;
            v.ramreload  := '1';
            v.slowwrpend := '0';
          end if;
        elsif mmuen = 1 or walk_pmp then
          if not all_1(r.itlbprobeid) then
            v.itlbprobeid := uadd(r.itlbprobeid, 1);
          end if;
          if not all_1(r.d2tlbid) then
            v.d2tlbid     := uadd(r.d2tlbid, 1);
          end if;
          if not all_1(r.h2tlbid) then
            v.h2tlbid     := uadd(r.h2tlbid, 1);
          end if;
          if r.itlb(u2i(r.itlbprobeid)).valid = '1' then
            if flushmatch(false, is_v(r.d2.mode),
                          r.itlb(u2i(r.itlbprobeid)), r.d2vaddr, r.d2data) then
              v.itlb(u2i(r.itlbprobeid)).valid := '0';
              v.perf(13) := '1';
            end if;
          end if;
          if r.dtlb(u2i(r.d2tlbid)).valid = '1' then
            if flushmatch(false, is_v(r.d2.mode),
                          r.dtlb(u2i(r.d2tlbid)), r.d2vaddr, r.d2data) then
              v.dtlb(u2i(r.d2tlbid)).valid := '0';
              v.perf(14) := '1';
            end if;
          end if;
          -- Only check hTLB for hfence.gvma
          if ext_h = 1 and r.d2size = "10" and r.htlb(u2i(r.h2tlbid)).valid = '1' then
            if flushmatch(true, false, r.htlb(u2i(r.h2tlbid)), r.d2vaddr, r.d2data) then
              v.htlb(u2i(r.h2tlbid)).valid := '0';
              v.perf(15) := '1';
            end if;
          end if;
          -- All counters done?
          if all_1(r.itlbprobeid) and all_1(r.d2tlbid) and
             (ext_h = 0 or all_1(r.h2tlbid)) then
            v.s          := as_normal;
            v.ramreload  := '1';
            v.slowwrpend := '0';
          end if;
        end if;

      when as_regflush =>
        ocrami.iindex               := (others => '0');
        ocrami.iindex(i_sets'range) := r.flushctr(i_sets'range);
        ocrami.idataoffs            := (others => '0');
        for w in i_ways'range loop
          -- ocrami.itagdin(w) := (others => '0');
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW + 1 downto TAG_HIGH - ITAG_LOW - 6)  := x"FF";
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW - 7 downto TAG_HIGH - ITAG_LOW - 8)  := u2vec(w, 2);
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW - 9 downto TAG_HIGH - ITAG_LOW - 10) := u2vec(w, 2);
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW + 1 downto TAG_HIGH - ITAG_LOW)      := r.untagi(2 * w + 1 downto 2 * w);
          ocrami.itagdin(w)(0)                                                       := '0';
        end loop;
        ocrami.dtagcindex               := (others => '0');
        ocrami.dtagcindex(d_sets'range) := get_hi(r.flushctr, d_sets'length);

        -- Stage 3: Write back to itag/dtag
        vbubble0 := '0';
        vstall   := '0';
        if r.regflpipe(0).valid = '1' then
          if not all_0(r.flushwri) then
            ocrami.iindex(i_sets'range) := r.regflpipe(0).addr(i_sets'range);
            ocrami.itagen(i_ways'range) := r.flushwri;
            ocrami.itagwrite            := '1';
            vbubble0                    := '1';
          end if;
          if dtagconf /= 0 then
            for w in d_ways'range loop
              if r.flushwrd(w) = '1' then
                vs.validarr(u2i(r.regflpipe(0).addr))(w) := '0';
              end if;
            end loop;
          else
            if vs.dtwrite = '0' then
              vs.dtaccidx    := r.regflpipe(0).addr(d_sets'range);
              vs.dtacctagmsb := r.untagd;
              vs.dtacctaglsb := (others => '0');
            end  if;
            if not all_0(r.flushwrd) then
              if vs.dtwrite = '0' then
                vs.dtwrite      := '1';
                vs.dtaccways    := r.flushwrd;
                vs.dtacctagmod  := '1';
              else
                vstall := '1';
              end if;
            end if;
          end if;
        end if;
        if vstall = '1' then
          v.regflpipe := r.regflpipe;
        end if;
        -- Stage 2: Compare with region flush mask
        -- Most is handled in region flush section above FSM, just handle stall
        -- here
        if vstall = '1' then
          v.untagi   := r.untagi;
          v.untagd   := r.untagd;
          v.flushwrd := r.flushwrd;
          v.flushwri := r.flushwri;
        end if;
        -- Stage 1: Capture tags or itag/dtag write ongoing
        -- Most is handled in region flush section above FSM, just handle stall
        -- here
        if vstall = '1' then
          v.dtagpipe := r.dtagpipe;
          v.itagpipe := r.itagpipe;
        end if;
        -- Stage 0: Command Read from tag RAMs
        if r.regfldone = '0' and vbubble0 = '0' and vstall = '0' then
          if r.flushpart(1) = '1' then
            ocrami.itagen    := (others => '1');
            ocrami.itagwrite := '0';
          end if;
          if r.flushpart(0) = '1' then
            ocrami.dtagcen   := (others => '1');
          end if;
          v.regflpipe(r.regflpipe'high).valid := '1';
          -- Advance counter, skip addrs guaranteed not to match
          --   set fixed bits to 1 before incrementing
          --   after incrementing, force fixed bits back to determined value
          vfoffs := r.flushctr;
          vfoffs := vfoffs or r.regflmask(d_index'range);
          vfoffs := uadd(vfoffs, 1);
          if all_0(vfoffs) then
            v.regfldone := '1';
          end if;
          vfoffs     := vfoffs and not r.regflmask(d_index'range);
          vfoffs     := vfoffs or (r.regflmask(d_index'range) and
                                   r.regfladdr(d_index'range));
          v.flushctr := vfoffs;
        end if;

        if r.regfldone = '1' then
          vhit := '0';
          for x in 0 to r.regflpipe'high loop
            if r.regflpipe(x).valid = '1' then
              vhit := '1';
            end if;
          end loop;
          if vhit = '0' then
            v.ramreload := '1';
            v.s         := as_normal;
            if r.flushpart(1) = '1' then v.iflushpend := '0'; v.iregflush := '0'; end if;
            if r.flushpart(0) = '1' then v.dflushpend := '0'; v.dregflush := '0'; end if;
          end if;
        end if;


      when as_start_walk =>
       if mmuen = 1 and walk_state then
        iaddr_ok  := true;
        daddr_ok  := true;

        v.newent  := tlbent_empty;

        -- Ensure PTE writes get snooped
        if not is_access_asi_walk(r.mmusel) then
          v.ahb.snoopmask := (others => '0');
        end if;
        v.ahb.hsize       := pte_hsize;
        if not is_riscv then
          v.ahb.htrans    := HTRANS_NONSEQ;
          v.s             := as_mmuwalk;
        else
          -- Need to go via another state, to split PMP dependency chain.
          v.ahb.htrans    := HTRANS_IDLE;

          -- First TLB level.
          v.newent.mask   := (others => '0');

          -- Assume supervisor page tables need to be checked
          v.h_x    := '0';
          v.h_ls   := '0';
          v.h_mxr  := '0';
          v.h_vmxr := '0';
          v.h_hx   := '0';
          v.s      := as_mmu_pt1addr_chk;

          -- On RISC-V, the base is indexed directly for the first level.
          -- Return physical address for next level of page table.
          -- mask - pre-shift (ie before new 1 at bit 1 (first)) page table mask
          -- code - mask recoded as position for first 0 (from 1)
          -- Also, remember the V flag and perhaps set up a fake entry if hypervisor.
          mmu_data                                  := (others => '0');
          case r.mmusel is
          when access_i =>
            mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(r, csro, r.i2.mode)(gpn'range);
            haddr                                   := pt_addr(mmu_data, v.newent.mask, r.i2.pc, "00");
            v.h_v               := is_v(r.i2.mode);
            iaddr_ok            := virtual_ok(r.i2.pc);
            -- Actually hypervisor but no supervisor page tables?
            if hmmu_only(r.i2.mode) then
              iaddr_ok          := gphysical_ok(r.i2.pc);
              v.newent.ctx      := r.i2.ctx;
              v.newent.mode     := r.i2.mode;
              v.newent.vaddr    := r.i2.pc(gvn'range);
              v.mmuerr.at_ls    := '0';        -- Load/Execute
              v.mmuerr.at_id    := '1';        -- Instruction space
              v.mmuerr.at_su    := r.i2.su;
              v.h_mxr           := '0';
              v.h_vmxr          := '0';
              v.h_hx            := '0';
              do_pte1_hchk      := true;
            end if;
          when access_r | access_asi_walk =>
            mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(r, csro, r.d2.mode)(gpn'range);
            haddr                                   := pt_addr(mmu_data, v.newent.mask, r.d2vaddr, "00");
            v.h_v               := is_v(r.d2.mode);
            daddr_ok            := virtual_ok(r.d2vaddr);
            -- Actually hypervisor but no supervisor page tables?
            if hmmu_only(r.d2.mode) then
              daddr_ok          := gphysical_ok(r.d2vaddr);
              v.newent.ctx      := mmu_ctx(r, csro, r.d2.mode);
              v.newent.mode     := r.d2.mode;
              v.newent.vaddr    := r.d2vaddr(gvn'range);
              v.mmuerr.at_ls    := to_bit(is_access_w(r.mmusel));
              v.mmuerr.at_id    := '0';
              v.mmuerr.at_su    := r.d2.su;
              v.h_mxr           := r.d2.mxr;
              v.h_vmxr          := r.d2.vmxr;
              v.h_hx            := r.d2.hx;
              -- Treat atomic access as store to avoid store phase of atomic
              -- causing mmu fault.
              if r.d2lock = '1' then
                v.mmuerr.at_ls  := '1';
              end if;
              do_pte1_hchk      := true;
            end if;
          -- Really "11" (access_w), since "10" is unused.
          when others =>
            mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(r, csro, r.d2.mode)(gpn'range);
            haddr                                   := pt_addr(mmu_data, v.newent.mask, r.d2vaddr, "00");
            v.h_v               := is_v(r.d2.mode);
            daddr_ok            := virtual_ok(r.d2vaddr);
            -- Actually hypervisor but no supervisor page tables?
            if hmmu_only(r.d2.mode) then
              daddr_ok          := gphysical_ok(r.d2vaddr);
              v.newent.ctx      := mmu_ctx(r, csro, r.d2.mode);
              v.newent.vaddr    := r.d2vaddr(gvn'range);
              v.newent.mode     := r.d2.mode;
              v.mmuerr.at_ls    := '1';
              v.mmuerr.at_id    := '0';
              v.mmuerr.at_su    := r.d2.su;
              v.h_mxr           := r.d2.mxr;
              v.h_vmxr          := r.d2.vmxr;
              v.h_hx            := r.d2.hx;
              do_pte1_hchk      := true;
            end if;
          end case;

          if addr_check_mask(4) = '0' then
            iaddr_ok := true;
          end if;
          if addr_check_mask(0) = '0' then
            daddr_ok := true;
          end if;

          v.ahb.haddr := haddr(v.ahb.haddr'range);
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

          -- Prepare for second TLB level.
          v.newent.mask(v.newent.mask'low) := '1';

          if do_pte1_hchk then
            v.s               := as_mmu_pte1_hchk;
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
              v.s := as_hmmuwalk_pterr;
            else
            end if;
          else
            if not iaddr_ok or not daddr_ok then
              v.s := as_mmuwalk_pterr;
            end if;
          end if;
        end if;
       else
         -- This can never happen!
         v.s := as_normal;
       end if;

      when as_start_pmp =>
        if actual_tlb_pmp and walk_pmp then
          iaddr_ok  := true;
          daddr_ok  := true;

          v.newent  := tlbent_empty;

          case r.mmusel is
          when access_i =>
            iaddr_ok          := gphysical_ok(r.i2.pc);
            v.newent.ctx      := (others => '0');
            v.newent.mode     := r.i2.mode;
            v.newent.vaddr    := r.i2.pc(gvn'range);
            v.mmuerr.at_ls    := '0';        -- Load/Execute
            v.mmuerr.at_id    := '1';        -- Instruction space
            v.mmuerr.at_su    := r.i2.su;
            v.pmp_m           := r.i2.m;
          when access_r | access_asi_walk =>
            daddr_ok          := gphysical_ok(r.d2vaddr);
            v.newent.ctx      := (others => '0');
            v.newent.mode     := r.d2.mode;
            v.newent.vaddr    := r.d2vaddr(gvn'range);
            v.mmuerr.at_ls    := to_bit(is_access_w(r.mmusel));
            v.mmuerr.at_id    := '0';
            v.mmuerr.at_su    := r.d2.su;
            -- Treat atomic access as store to avoid store phase of atomic
            -- causing mmu fault.
            if r.d2lock = '1' then
              v.mmuerr.at_ls  := '1';
            end if;
            v.pmp_m           := r.d2.m;
          -- Really "11" (access_w), since "10" is unused.
          when others =>
            daddr_ok          := gphysical_ok(r.d2vaddr);
            v.newent.ctx      := (others => '0');
            v.newent.vaddr    := r.d2vaddr(gvn'range);
            v.newent.mode     := r.d2.mode;
            v.mmuerr.at_ls    := '1';
            v.mmuerr.at_id    := '0';
            v.mmuerr.at_su    := r.d2.su;
            v.pmp_m           := r.d2.m;
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

          -- First TLB level.
          v.newent.mask := (others => '0');

          -- Prepare for second TLB level.
          v.newent.mask(v.newent.mask'low) := '1';

          v.pmp_mask := pt_mask(v.newent.mask)(v.pmp_mask'range);
          v.pmp_low  := fit0ext(v.newent.vaddr & x"000", v.pmp_low) and v.pmp_mask;
          v.pmp_do   := '1';

          v.s        := as_mmu_pte1_pmpchk;

          v.newent.perm     := (others => '1');
          v.newent.modified := v.mmuerr.at_ls;

          v.newent.paddr    := fit0ext(v.newent.vaddr, v.newent.paddr);

          if not iaddr_ok then
            v.ifailkind := "11";
            v.s := as_ifailkind;
          elsif not daddr_ok then
            v.dfailkind := "11";
            v.s := as_dfailkind;
          else
          end if;
        else
          -- This can never happen!
          v.s := as_normal;
        end if;

    end case;


    if actual_tlb_pmp and walk_pmp and start_pmp then
      do_access  := false;  -- Cannot really be true if we get here!
      start_walk := false;  -- Cannot really be true if we get here!
      v.s        := as_start_pmp;
    end if;

  if mmuen = 1 and start_walk then
    if walk_state then
      do_access := false;  -- Cannot really be true if we get here!
      v.s := as_start_walk;
    else
      iaddr_ok  := true;
      daddr_ok  := true;
      do_access := false;  -- Cannot really be true if we get here!
      -- Ensure PTE writes get snooped
      if not is_access_asi_walk(r.mmusel) then
        v.ahb.snoopmask := (others => '0');
      end if;
      v.ahb.hsize       := pte_hsize;
      if not is_riscv then
        v.ahb.htrans    := HTRANS_NONSEQ;
        v.s             := as_mmuwalk;
      else
        -- Need to go via another state, to split PMP dependency chain.
        v.ahb.htrans    := HTRANS_IDLE;

        -- First TLB level.
        v.newent.mask   := (others => '0');

        -- Assume supervisor page tables need to be checked
        v.h_x    := '0';
        v.h_ls   := '0';
        v.h_mxr  := '0';
        v.h_vmxr := '0';
        v.h_hx   := '0';
        v.s      := as_mmu_pt1addr_chk;

        -- On RISC-V, the base is indexed directly for the first level.
        -- Return physical address for next level of page table.
        -- mask - pre-shift (ie before new 1 at bit 1 (first)) page table mask
        -- code - mask recoded as position for first 0 (from 1)
        -- Also, remember the V flag and perhaps set up a fake entry if hypervisor.
        mmu_data                                  := (others => '0');
        case v.mmusel is
        when access_i =>
          mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(r, csro, v.i2.mode)(gpn'range);
          haddr                                   := pt_addr(mmu_data, v.newent.mask, v.i2.pc, "00");
          v.h_v               := is_v(v.i2.mode);
          iaddr_ok            := virtual_ok(v.i2.pc);
          -- Actually hypervisor but no supervisor page tables?
          if hmmu_only(v.i2.mode) then
            iaddr_ok          := gphysical_ok(v.i2.pc);
            v.newent.ctx      := v.i2.ctx;
            v.newent.mode     := v.i2.mode;
            v.newent.vaddr    := v.i2.pc(gvn'range);
            v.mmuerr.at_ls    := '0';        -- Load/Execute
            v.mmuerr.at_id    := '1';        -- Instruction space
            v.mmuerr.at_su    := r.i2.su;
            v.h_mxr           := '0';
            v.h_vmxr          := '0';
            v.h_hx            := '0';
            do_pte1_hchk      := true;
          end if;
        when access_r | access_asi_walk =>
          mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(r, csro, v.d2.mode)(gpn'range);
          haddr                                   := pt_addr(mmu_data, v.newent.mask, v.d2vaddr, "00");
          v.h_v               := is_v(v.d2.mode);
          daddr_ok            := virtual_ok(v.d2vaddr);
          -- Actually hypervisor but no supervisor page tables?
          if hmmu_only(v.d2.mode) then
            daddr_ok          := gphysical_ok(v.d2vaddr);
            v.newent.ctx      := mmu_ctx(r, csro, v.d2.mode);
            v.newent.mode     := v.d2.mode;
            v.newent.vaddr    := v.d2vaddr(gvn'range);
            v.mmuerr.at_ls    := to_bit(is_access_w(r.mmusel));
            v.mmuerr.at_id    := '0';
            v.mmuerr.at_su    := v.d2.su;
            v.h_mxr           := v.d2.mxr;
            v.h_vmxr          := v.d2.vmxr;
            v.h_hx            := v.d2.hx;
            -- Treat atomic access as store to avoid store phase of atomic
            -- causing mmu fault.
            if v.d2lock = '1' then
              v.mmuerr.at_ls  := '1';
            end if;
            do_pte1_hchk      := true;
          end if;
        -- Really "11" (access_w), since "10" is unused.
        when others =>
          mmu_data(gpn'length + 10 - 1 downto 10) := mmu_base(r, csro, r.d2.mode)(gpn'range);
          haddr                                   := pt_addr(mmu_data, v.newent.mask, r.d2vaddr, "00");
          v.h_v               := is_v(r.d2.mode);
          daddr_ok            := virtual_ok(r.d2vaddr);
          -- Actually hypervisor but no supervisor page tables?
          if hmmu_only(r.d2.mode) then
            daddr_ok          := gphysical_ok(r.d2vaddr);
            v.newent.ctx      := mmu_ctx(r, csro, r.d2.mode);
            v.newent.vaddr    := r.d2vaddr(gvn'range);
            v.newent.mode     := r.d2.mode;
            v.mmuerr.at_ls    := '1';
            v.mmuerr.at_id    := '0';
            v.mmuerr.at_su    := r.d2.su;
            v.h_mxr           := r.d2.mxr;
            v.h_vmxr          := r.d2.vmxr;
            v.h_hx            := r.d2.hx;
            do_pte1_hchk      := true;
          end if;
        end case;

        if addr_check_mask(4) = '0' then
          iaddr_ok := true;
        end if;
        if addr_check_mask(0) = '0' then
          daddr_ok := true;
        end if;

        v.ahb.haddr := haddr(v.ahb.haddr'range);
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

        -- Prepare for second TLB level.
        v.newent.mask(v.newent.mask'low) := '1';

        if do_pte1_hchk then
          v.s               := as_mmu_pte1_hchk;
          v.newent.perm     := (others => '1');
          v.newent.modified := v.mmuerr.at_ls;

          -- Check PTE range with hypervisor page tables, if applicable.
--          v.newent.paddr    := fit0ext(pte_paddr(rdb64), v.newent.paddr);
          v.h_addr          := fit0ext(v.newent.vaddr & x"000", v.h_addr);
          v.h_ls            := v.mmuerr.at_ls;
          v.h_x             := v.mmuerr.at_id;
          -- Possible access fault due to L2 PT.
          -- Instruction or data access.
          v.itypehyper      := '0' & v.h_x;
          v.dtypehyper      := '0' & not v.h_x;
          if not iaddr_ok or not daddr_ok then
            v.s := as_hmmuwalk_pterr;
          else
          end if;
        else
          if not iaddr_ok or not daddr_ok then
            v.s := as_mmuwalk_pterr;
          end if;
        end if;
      end if;
    end if;
  end if;

    if is_riscv and not actual_tlb_pmp then
      -- PMP check page table address, if pmp_mmu.
      pmp_xc     := '0';
      pmp_hit    := (others => '0');
      if pmpen then
        pmp      := pmp_clear;      -- Ensure no latches!
        pmp.mpp  := (others => '0');
        pmp.addr := fit0ext(r.ahb.haddr, pmp.addr);

        pmp_unit(PRIV_LVL_S, csro.precalc, csro.pmpcfg, csro.mmwp, csro.mml,
                 '0', pmp.mpp, pmp.addr, PMP_ACCESS_R, pmp_mmu,
                 pmp_xc, pmp_hit,
                 pmp_entries, pmp_no_tor, pmp_g, pmp_msb, ext_smepmp);
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
          -- Need to hit a PMA entry!
          if all_0(pma_hit) then
            pmp_xc := '1';
          elsif not pma_valid(pma) then
            pmp_xc := '1';
          elsif not pma_pt_r(pma) then
            pmp_xc := '1';
          else
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
        v.s       := as_mmuwalk_pmperr;
      end if;
    end if;

    -- AMO: extend hold until store is executed
    if (r.amo.hold = '1' and store_done) or ext_a = 0 then
      v.amo.hold := '0';
      v.amo.sc   := '0';
    end if;
    -- AMO: data
    if odco.mds = '0' or r.holdn = '1' then
      v.amo.data := odco.data(u2i(odco.way));
    end if;

    -- CBO: extend hold until tag is updated
    if rs.dtwrite = '0' and r.s /= as_cbo then
      v.cbo.hold := '0';
    end if;

    if v.itcmwipe = '1' or v.dtcmwipe = '1' then
      v.itcmenp  := '0';
      v.itcmenva := '0';
      v.itcmenvc := '0';
      v.dtcmenp  := '0';
      v.dtcmenva := '0';
      v.dtcmenvc := '0';
    end if;

    -- SMP broadcast flush
    if smpflush(1) = '1' then
      v.iflushpend := '1';
    end if;
    if smpflush(0) = '1' then
      v.tlbflush   := "11";
    end if;


    -- Assume no hold ('1'), but assert ('0') if
    --  pending I/D$ miss or flush,
    --  pending slow write,
    --  store buffer full
    -- or AMO ongoing.
    v.holdn := '1';
    if v.imisspend  = '1' or v.dmisspend  = '1' or v.slowwrpend = '1' or
       v.iflushpend = '1' or v.dflushpend = '1' or v.ramreload  = '1' or
       v.stbuffull = '1' or v.syncbar = '1' or freeze = '1' or
       v.amo.hold = '1' or v.cbo.hold = '1' then
      v.holdn := '0';
    end if;


    -- Bus request handling
    v.ahb.hbusreq := '0';
    if (v.ahb.htrans(1) = '1' or r.s = as_getlock or
        do_mmu_lock) and
       (v.granted = '0' or v.ahb.hlock = '1' or keepreq = '1') then
      v.ahb.hbusreq := '1';
    end if;

    -- hprot generation
    v.ahb.hprot := "1101";
    if do_icfetch then
      v.ahb.hprot := "11" & v.i2.su & '0';
    elsif do_access then
      v.ahb.hprot := "11" & v.d2.su & '1';
    end if;

    -- Data loopback if no bw support
    if dusebw = 0 then
      for w in d_ways'range loop
        for x in 7 downto 0 loop
          if ocrami.ddatawrite(x) = '0' then
            ocrami.ddatadin(w)(8 * x + 7 downto 8 * x) := cramo.ddatadout(w)(8 * x + 7 downto 8 * x);
          end if;
        end loop;
      end loop;
      for x in 7 downto 0 loop
        if ocrami.ddatawrite(x) = '0' then
          ocrami.dtcmdin(8 * x + 7 downto 8 * x) := cramo.dtcmdout(8 * x + 7 downto 8 * x);
        end if;
      end loop;
      if ocrami.ddatawrite(7 downto 4) /= "0000" then
        ocrami.ddatawrite(7 downto 4) := "1111";
      end if;
      if ocrami.ddatawrite(3 downto 0) /= "0000" then
        ocrami.ddatawrite(3 downto 0) := "1111";
      end if;
    end if;

    -- Combined read/update port for Dtag RAM
    ocrami.dtagcuindex                 := ocrami.dtagcindex;
    ocrami.dtagcuen                    := ocrami.dtagcen;
    ocrami.dtagcuwrite                 := '0';
    if not all_0(rs.s3read) or not all_0(rs.s3flush) then
      ocrami.dtagcuindex(d_sets'range) := rs.s3offs;
      ocrami.dtagcuen(d_ways'range)    := rs.s3read or rs.s3flush;
      ocrami.dtagcuwrite               := '1';
    elsif rs.dtwrite = '1' then
      ocrami.dtagcuindex(d_sets'range) := rs.dtaccidx;
      ocrami.dtagcuen(d_ways'range)    := rs.dtaccways;
      ocrami.dtagcuwrite               := '1';
    end if;

    -- TCM wiping support
    ocrami.dtcmwrite := ocrami.ddatawrite;
    if r.dtcmwipe = '1' then
      ocrami.dtcmen        := '1';
      ocrami.dtcmwrite     := (others => '1');
      ocrami.dtcmdin       := (others => '0');
      ocrami.ddatafulladdr := r.tcmdata;
    end if;
    ocrami.itcmwrite       := ocrami.idatawrite;
      ocrami.itcmdin       := ocrami.idatadin;
    if r.itcmwipe = '1' then
      ocrami.itcmen    := '1';
      ocrami.itcmwrite := "11";
      ocrami.itcmdin   := (others => '1');
      ocrami.ifulladdr := r.tcmdata;
    end if;
    if r.dtcmwipe = '1' or r.itcmwipe = '1' then
      v.tcmdata(31 downto 3) := uadd(r.tcmdata(31 downto 3), 1);
      v.tcmdata(2 downto 0)  := "000";
      for x in 31 downto 3 loop
        if (itcmen = 0 or x > (2 + itcmabits)) and (dtcmen = 0 or x > (2 + dtcmabits)) then
          v.tcmdata(x)       := '0';
        end if;
      end loop;
      if all_0(v.tcmdata) then
        v.dtcmwipe := '0';
        v.itcmwipe := '0';
      end if;
    end if;

    --------------------------------------------------------------------------
    -- Reset
    --------------------------------------------------------------------------
    if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)    = 0 and
       GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 0 then
      if rst = '0' then
        v.ahb.hlock      := RRES.ahb.hlock;
        v.cctrl          := RRES.cctrl;
        --v.iuctrl         := RRES.iuctrl;
        v.icignerr       := RRES.icignerr;
        v.dcignerr       := RRES.dcignerr;
        v.dcerrmask      := RRES.dcerrmask;
        v.dcerrmaskval   := RRES.dcerrmaskval;
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
        v.mmctrl1.e      := RRES.mmctrl1.e;
        v.mmctrl1.nf     := RRES.mmctrl1.nf;
        v.mmctrl1.ctx    := RRES.mmctrl1.ctx;
        v.mmctrl1.tlbdis := RRES.mmctrl1.tlbdis;
        v.mmctrl1.pso    := RRES.mmctrl1.pso;
        v.mmctrl1.bar    := RRES.mmctrl1.bar;
        v.mmfsr.fav      := RRES.mmfsr.fav;
        v.s              := RRES.s;
        v.imisspend      := RRES.imisspend;
        v.ifailkind      := RRES.ifailkind;
        v.dmisspend      := RRES.dmisspend;
        v.dfailkind      := RRES.dfailkind;
        v.iflushpend     := RRES.iflushpend;
        v.dflushpend     := RRES.dflushpend;
        v.slowwrpend     := RRES.slowwrpend;
        v.syncbar        := RRES.syncbar;
        v.irdbufen       := RRES.irdbufen;
        v.holdn          := RRES.holdn;
        v.ahb.hbusreq    := RRES.ahb.hbusreq;
        v.ahb.hlock      := RRES.ahb.hlock;
        v.ahb.htrans     := RRES.ahb.htrans;
        v.granted        := RRES.granted;
        v.i2paddrv       := RRES.i2paddrv;
        v.i1ten          := RRES.i1ten;
        v.i1cont         := RRES.i1cont;
        v.i1rep          := RRES.i1rep;
        v.ibpmiss        := RRES.ibpmiss;
        v.d1ten          := RRES.d1ten;
        v.h_done         := RRES.h_done;
        v.addrhyper      := RRES.addrhyper;
        v.itypehyper     := RRES.itypehyper;
        v.dtypehyper     := RRES.dtypehyper;
        vs.sgranted      := RSRES.sgranted;
        if dtagconf = 0 then
          vs.validarr    := RSRES.validarr;
        end if;
        vs.dtwrite       := RSRES.dtwrite;
        vs.stread        := RSRES.stread;
        vs.stwrite       := RSRES.stwrite;
        vs.strdstarted   := RSRES.strdstarted;
        vs.strddone      := RSRES.strddone;
        -- Atomic operations
        v.amo.d1type     := RRES.amo.d1type;
        v.amo.d2type     := RRES.amo.d2type;
        v.amo.reserved   := RRES.amo.reserved;
        v.amo.hold       := RRES.amo.hold;
        v.amo.store      := RRES.amo.store;
        v.amo.sc         := RRES.amo.sc;
        v.amo.s4hit      := RRES.amo.s4hit;
        -- Cache block Operations
        v.cbo.d1type     := RRES.cbo.d1type;
        v.cbo.d2type     := RRES.cbo.d2type;
        v.cbo.hold       := RRES.cbo.hold;
        -- RISC-V does not use a default TLB, so must invalidate.
        if is_riscv then
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
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Replication
    ---------------------------------------------------------------------------
    for x in v.i1pc_repl'range loop
      v.i1pc_repl(x)    := fit0ext(v.i1.pc, v.i1pc_repl(0));
    end loop;
    for x in v.d1vaddr_repl'range loop
      v.d1vaddr_repl(x) := fit0ext(v.d1vaddr, v.d1vaddr_repl(0));
    end loop;
    for x in v.h_addr_repl'range loop
      v.h_addr_repl(x)  := fit0ext(v.h_addr, v.h_addr_repl(0));
    end loop;

    ---------------------------------------------------------------------------
    -- Constant registers
    ---------------------------------------------------------------------------
    case DWAYS is
      when 1 =>
        for w in r.dlru'range loop
          v.dlru(w)                          := (others => '0');
        end loop;
      when 2 =>
        for w in r.dlru'range loop
          v.dlru(w)(v.dlru(0)'high downto 4) := (others => '0');
          v.dlru(w)(2 downto 0)              := "000";
        end loop;
      when 3 =>
        for w in r.dlru'range loop
          v.dlru(w)(v.dlru(0)'high downto 5) := (others => '0');
          v.dlru(w)(1 downto 0)              := "00";
        end loop;
      when 4 =>
        for w in r.dlru'range loop
          v.dlru(w)(v.dlru(0)'high downto 5) := (others => '0');
        end loop;
      when others => null;
    end case;
    case IWAYS is
      when 1 =>
        for w in r.ilru'range loop
          v.ilru(w)                          := (others => '0');
        end loop;
      when 2 =>
        for w in r.ilru'range loop
          v.ilru(w)(v.ilru(0)'high downto 4) := (others => '0');
          v.ilru(w)(2 downto 0)              := "000";
        end loop;
      when 3 =>
        for w in r.ilru'range loop
          v.ilru(w)(v.ilru(0)'high downto 5) := (others => '0');
          v.ilru(w)(1 downto 0)              := "00";
        end loop;
      when 4 =>
        for w in r.dlru'range loop
          v.ilru(w)(v.ilru(0)'high downto 5) := (others => '0');
        end loop;
      when others => null;
    end case;
    for x in 31 downto 16 loop
      if (x <= 2 + itcmabits) or itcmen = 0 then
        v.itcmaddr(x) := '0';
      end if;
      if (x <= 2 + dtcmabits) or dtcmen = 0 then
        v.dtcmaddr(x) := '0';
      end if;
    end loop;
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

    if mmuen = 0 and not walk_pmp then
      v.itlb := tlb_def(v.itlb'range);
      v.dtlb := tlb_def(v.dtlb'range);
      v.htlb := tlb_def(v.htlb'range);
    end if;

    --------------------------------------------------------------------------
    -- Assign signals
    --------------------------------------------------------------------------
    odco.mexc     := d_mexc;
    odco.exctype  := d_exctype;
    oico.mexc     := i_mexc;
    oico.exctype  := i_exctype;

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

    rin      <= v;
    rsin     <= vs;
    ico      <= oico;
    dco      <= odco;

    ahbo     <= oahbo;

    crami    <= ocrami;
    fpc_mosi <= r.fpc_mosi;
    c2c_mosi <= r.c2c_mosi;
    perf     <= r.perf;

    csri.cctrl   <= csr_in_cctrl_type'(
      iflushpend => r.iflushpend,
      dflushpend => r.dflushpend,
      itcmwipe   => r.itcmwipe,
      dtcmwipe   => r.dtcmwipe
    );
    csri.cconfig <= cache_config;
  end process;

  srstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 0 generate
    regs: process(clk, csro)
    begin
      if rising_edge(clk) then
        r   <= rin;
        if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rst = '0' then
          r <= RRES;
        end if;
      end if;
      -- These are really set in IUNV in NOEL-V.
      if is_riscv then
        -- Replace CCTRL with CSR_CCTRL
        r.cctrl.dsnoop  <= csro.cctrl.dsnoop;
        r.cctrl.dcs     <= csro.cctrl.dcs;
        r.cctrl.ics     <= csro.cctrl.ics;
        r.cctrl.ics_btb <= csro.cctrl.ics;
        r.cctrl.dfrz    <= '0';
        r.cctrl.ifrz    <= '0';
      end if;
    end process;

    sregs: process(sclk)
    begin
      if rising_edge(sclk) then
        rs <= rsin;
        if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rst = '0' then
          rs <= RSRES;
        end if;
      end if;
    end process;
  end generate srstregs;

  arstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) /= 0 generate
    regs: process(clk, rst, csro)
    begin
      if rst = '0' then
        r <= RRES;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
      -- These are really set in IUNV in NOEL-V.
      if is_riscv then
        -- Replace CCTRL with CSR_CCTRL
        r.cctrl.dsnoop  <= csro.cctrl.dsnoop;
        r.cctrl.dcs     <= csro.cctrl.dcs;
        r.cctrl.ics     <= csro.cctrl.ics;
        r.cctrl.ics_btb <= csro.cctrl.ics;
        r.cctrl.dfrz    <= '0';
        r.cctrl.ifrz    <= '0';
      end if;
    end process;

    sregs: process(sclk, rst)
    begin
      if rst = '0' then
        rs <= RSRES;
      elsif rising_edge(sclk) then
        rs <= rsin;
      end if;
    end process;
  end generate arstregs;

-- pragma translate_off
  --ahbxchk: process(clk)
  --begin
  --  if rising_edge(clk) then
  --    if r.ahb2.inacc = '1' and r.ahb2.hwrite = '0' and ahbi.hready = '1' and ahbi.hresp = "00" then
  --      for x in LINESZMAX - 1 downto 0 loop
  --        assert
  --          not (r.ahb2.addrmask(x) = '1' and is_x(ahbi.hrdata((((x+1)*32-1) mod busw) downto ((x * 32) mod busw))))
  --          report "Reading in X over AHB bus into CPU"
  --          severity warning;
  --      end loop;
  --    end if;
  --  end if;
  --end process;
-- pragma translate_on

end;
