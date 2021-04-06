------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.tost;
use grlib.stdlib.tost_bits;
use grlib.stdlib.log2;
use grlib.stdlib.log2x;
use grlib.stdlib.orv;
use grlib.stdlib.andv;
use grlib.stdlib.conv_std_logic_vector;
use grlib.stdlib.notx;
use grlib.stdlib.setx;
use grlib.stdlib.print;
use grlib.devices.all;
use grlib.sparc.all;
use grlib.config.all;
use grlib.config_types.all;
library gaisler;
use gaisler.noelvint.nv_icache_in_type;
use gaisler.noelvint.nv_icache_out_type;
use gaisler.noelvint.nv_dcache_in_type;
use gaisler.noelvint.nv_dcache_out_type;
use gaisler.noelvint.cword3;
use gaisler.noelvint.nv_cdatatype;
use gaisler.noelvint.amo_math_op;
use gaisler.noelvint.all;
use gaisler.mmucacheconfig.ctxword;
use gaisler.mmucacheconfig.rv_pte_u;
use gaisler.mmucacheconfig.rv_pte_r;
use grlib.riscv.PRIV_LVL_M;
use grlib.riscv.PRIV_LVL_S;
use grlib.riscv.PRIV_LVL_U;
use gaisler.noelvint.PMP_ACCESS_R;
use gaisler.noelvint.PMP_ACCESS_W;
use gaisler.noelvint.PMP_ACCESS_X;
use gaisler.noelvint.pmp_unit;
use gaisler.noelvint.PMPPRECALCRES;
use gaisler.noelvint.csrtype;
use gaisler.noelvint.nv_intreg_miso_type;
use gaisler.noelvint.nv_intreg_mosi_type;
use gaisler.noelvint.nv_intreg_miso_none;
use gaisler.noelvint.nv_intreg_mosi_none;
use gaisler.utilnv.minimum;
use gaisler.utilnv.maximum;
use gaisler.utilnv.u2i;
use gaisler.utilnv.u2slv;
use gaisler.utilnv.get;
use gaisler.utilnv.set;
use gaisler.utilnv.all_1;
use gaisler.utilnv.all_0;
use gaisler.utilnv.uadd_range;
use gaisler.utilnv.lo_h;
use gaisler.utilnv.hi_h;
use gaisler.utilnv.log;

entity cctrlnv is
  generic (
    hindex     : integer;                  -- Hart index
    -- Core
    physaddr   : integer range 32 to 56;   -- Physical Addressing
    -- Caches
    isets      : integer range 1 to   4;   -- I$ ways
    ilinesize  : integer range 4 to   8;   --    cache line size (32 bit words)
    isetsize   : integer range 1 to 256;   --    way size (KiB)
    dsets      : integer range 1 to   4;   -- D$ ways
    dlinesize  : integer range 4 to   8;   --    cache line size (32 bit words)
    dsetsize   : integer range 1 to 256;   --    way size (KiB)
    dtagconf   : integer range 0 to   2;
    dusebw     : integer range 0 to   1;
    -- MMU
    itlbnum    : integer range 2 to  64;   -- # I$ TLB entries
    dtlbnum    : integer range 2 to  64;   -- # D$ TLB entries
    riscv_mmu  : integer range 0 to   3;
    pmp_no_tor : integer range 0 to   1;   -- Disable PMP TOR
    pmp_entries: integer range 0 to  16;   -- Implemented PMP registers
    pmp_g      : integer range 0 to  10;   -- PMP grain is 2^(pmp_g + 2) bytes
    ext_a      : integer range 0  to 1;    -- Support for Atomic operations
    -- Misc
    cached     : integer;                  -- Mask indexed by 4 MSB of address regarding cacheability when no TLB used
    wbmask     : integer;                  -- ?
    busw       : integer;                  -- AHB bus width in bits
    cdataw     : integer;                  -- Cache memory width in bits
    icrepl     : integer;
    dcrepl     : integer;
    addr_check : integer range 0 to 255 := 223;  -- Instruction PMP (7 TLB, 6 acc), high bits (5 physical, 4 virtual)
    mmu_debug  : boolean := false;               --   Data      PMP (3 TLB, 2 acc), high bits (1 physical, 0 virtual)
    no_mmu     : boolean := false;
    endian     : integer range 0 to 1
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
    csr        : in  csrtype := ((others => '0'), "00", '0', '0', '0', "00",
                                 '0', '0', (others => '0'), (others => '0'),
                                 PMPPRECALCRES);
    fpc_mosi   : out nv_intreg_mosi_type;
    fpc_miso   : in  nv_intreg_miso_type;
    c2c_mosi   : out nv_intreg_mosi_type;
    c2c_miso   : in  nv_intreg_miso_type;
    fpuholdn   : in  std_ulogic;                    -- unused
    -- Temp perf counter
    perf       : out std_logic_vector(31 downto 0);
    hclk, sclk : in  std_ulogic;                    -- hclk unused, sclk for snoop (not gated)
    hclken     : in  std_ulogic                     -- unused
    );


end;

architecture rtl of cctrlnv is

  subtype word2  is std_logic_vector( 1 downto 0);
  subtype word3  is std_logic_vector( 2 downto 0);
  subtype word8  is std_logic_vector( 7 downto 0);
  subtype word32 is std_logic_vector(31 downto 0);
  subtype word64 is std_logic_vector(63 downto 0);

  constant zerov : word64 := (others => '0');
  constant onev  : word64 := (others => '1');

  -- Endianness reverse function
  function decode_size(size : in std_logic_vector(2 downto 0)) return unsigned is
    -- Non-constant
    variable ret : unsigned(7 downto 0);
  begin
    case size is
      when "000"  => ret := "00000001";
      when "001"  => ret := "00000010";
      when "010"  => ret := "00000100";
      when "011"  => ret := "00001000";
      when "100"  => ret := "00010000";
      when "101"  => ret := "00100000";
      when "110"  => ret := "01000000";
      when "111"  => ret := "10000000";
      when others => null;
    end case;

    return ret;
  end decode_size;

  function full_dwsize(size : in integer) return std_logic_vector is
    -- Non-constant
    variable hsize : std_logic_vector(2 downto 0);
  begin
    --default 32-bit
    hsize := "010";

    case size is
      when 64     => hsize := "011";
      when 128    => hsize := "100";
      when 256    => hsize := "101";
      when others => null;
    end case;

    return hsize;
  end full_dwsize;

  function be_to_le_address(data_width : integer;               --constant
                            address_in : std_logic_vector(log2((128 / 2 / 8)) - 1 downto 0);
                            size       : std_logic_vector(2 downto 0)
                           ) return std_logic_vector is
    -- Non-constant
    variable max_add : unsigned(7 downto 0);
    variable temp    : unsigned(7 downto 0);
    variable ret     : unsigned(7 downto 0);
  begin
    max_add := (others=>'0');
    max_add(log2(128 / 2 / 8)) := '1';
    temp    := (others => '0');
    ret     := (others => '0');

    if full_dwsize(data_width) = size then
      return address_in;
    else
      temp := max_add - decode_size(size);
      ret  := temp - unsigned(address_in);
      return std_logic_vector(ret(log2((128 / 2 / 8)) - 1 downto 0));
    end if;
  end be_to_le_address;

  function to_be_address(addr_in : std_logic_vector;
                         size    : std_logic_vector(1 downto 0)) return std_logic_vector is
    -- Non-constant
    variable hsize : std_logic_vector(2 downto 0);
    variable haddr : std_logic_vector(addr_in'length - 1 downto 0);
  begin
    hsize := '0' & size;
    haddr := addr_in;

    if haddr(31 downto 30) = "01" then
      haddr(log2(128 / 2 / 8) - 1 downto 0) := be_to_le_address(128, haddr(log2(128 / 2 / 8) - 1 downto 0), hsize);
    end if;

    return haddr;
  end to_be_address;

  -- This is actually exactly the same as the above,
  -- since the conversion is reversible!
  function to_le_address(addr_in : std_logic_vector;
                         size    : std_logic_vector(1 downto 0)) return std_logic_vector is
    -- Non-constant
    variable hsize : std_logic_vector(2 downto 0);
    variable haddr : std_logic_vector(addr_in'length - 1 downto 0);
  begin
    hsize := '0' & size;
    haddr := addr_in;

    if haddr(31 downto 30) = "01" then
      haddr(log2(128 / 2 / 8) - 1 downto 0) := be_to_le_address(128, haddr(log2(128 / 2 / 8) - 1 downto 0), hsize);
    end if;

    return haddr;
  end to_le_address;


  -- Wrapper functions for mmucacheconfig.

  function is_riscv return boolean is
  begin
    return gaisler.mmucacheconfig.is_riscv(riscv_mmu);
  end;
  
  constant va  : std_logic_vector(gaisler.mmucacheconfig.va_msb(riscv_mmu) downto 0) := (others=>'0');
  constant vpn : std_logic_vector(va'high downto 12) := (others=>'0');

  constant pa  : std_logic_vector(gaisler.mmucacheconfig.pa_msb(riscv_mmu) downto 0) := (others=>'0');
  constant ppn : std_logic_vector(pa'high downto 12) := (others=>'0');

  function pte_hsize return std_logic_vector is
  begin
    return gaisler.mmucacheconfig.pte_hsize(riscv_mmu);
  end;

  function va_size_tmp return gaisler.mmucacheconfig.va_bits is
  begin
    return gaisler.mmucacheconfig.va_size(riscv_mmu);
  end;
  constant va_size : gaisler.mmucacheconfig.va_bits := va_size_tmp;

  function is_pt_invalid(data : std_logic_vector) return boolean is
  begin
    return gaisler.mmucacheconfig.is_pt_invalid(riscv_mmu, data);
  end;

  function is_valid_pte(data : std_logic_vector; mask : std_logic_vector) return boolean is
  begin
    return gaisler.mmucacheconfig.is_valid_pte(riscv_mmu, data, mask, physaddr);
  end;

  function is_pte(data : std_logic_vector) return boolean is
  begin
    return gaisler.mmucacheconfig.is_pte(riscv_mmu, data);
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
  

  function va_sizet(what : va_type) return va_bits is
    variable SZ_SPARC : va_bits(1 to 3) := (8, 6, 6);    -- 8 + 6 + 6     + 12 = 32 bits
    variable SZ_SV32  : va_bits(1 to 2) := (10, 10);     -- 10 + 10       + 12 = 32
    variable SZ_SV39  : va_bits(1 to 3) := (9, 9, 9);    -- 9 + 9 + 9     + 12 = 39
    variable SZ_SV48  : va_bits(1 to 4) := (9, 9, 9, 9); -- 9 + 9 + 9 + 9 + 12 = 48
  begin
    case what is
      when sv32   => return SZ_SV32;
      when sv39   => return SZ_SV39;
      when sv48   => return SZ_SV48;
      when others => return SZ_SPARC;
    end case;
  end;

  function pt_addr(data  : std_logic_vector; mask : std_logic_vector;
                   vaddr : std_logic_vector; code : std_logic_vector) return std_logic_vector is
    constant pa_tmp : std_logic_vector               := pa;  -- constant
    -- Non-constant
    variable addr   : std_logic_vector(pa_tmp'range) := (others => '0');
    variable pos    : integer;
  begin
    if riscv_mmu = 0 then
      -- Since physical address is only 32 bit, do not use the top 4 bits of PTP.
      addr(addr'high downto 8) := data(27 downto 4);
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
      addr(addr'high downto 12) := data(pa_tmp'high - 12 + 10 downto 10);
      pos := 12;
      for i in mask'length downto 1 loop
        if i > u2i(code) then
          pos := pos + va_sizet(riscv_mmu)(i);
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

  function pte_paddr(data : std_logic_vector) return std_logic_vector is
  begin
    return gaisler.mmucacheconfig.pte_paddr(riscv_mmu, data);
  end;

  function pte_cached(ahbso : ahb_slv_out_vector; data : std_logic_vector) return std_logic is
    -- Non-constant
    variable paddr  : std_logic_vector(pa'range) := (others => '0');
    variable ahbo_t : ahb_mst_out_type;
  begin
    if is_riscv then
      paddr(ppn'range) := pte_paddr(data);
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

  -- Convert virtual vaddr to physical paddr, using vmask to OR correct levels.
  procedure virtual2physical(vaddr : std_logic_vector; mask : std_logic_vector;
                             paddr : inout std_logic_vector) is
  begin
    gaisler.mmucacheconfig.virtual2physical(riscv_mmu, vaddr, mask, paddr);
  end;

  function ft_acc_resolve(at : std_logic_vector(2 downto 0); data : std_logic_vector)
    return std_logic_vector is
  begin
    return gaisler.mmucacheconfig.ft_acc_resolve(riscv_mmu, at, data);
  end;


  function pte_busw(data : std_logic_vector) return std_logic is
    -- Non-constant
    variable paddr  : std_logic_vector(pa'range) := (others => '0');
    variable ahbo_t : ahb_mst_out_type;
  begin
    paddr(ppn'range) := pte_paddr(data);

    return dec_wbmask_fixed(paddr(ahbo_t.haddr'high downto 2), wbmask);
  end;


  function addr_bits return integer is
  begin
    return maximum(va'length, minimum(physaddr, pa'length));
  end;

  -- The maximum bits that are required to hold an address (physical or virtual).
  -- One bit longer than the actual address, since we need to keep track of
  -- whether higher bits are the same or not (not same - bad address).
  -- These are what is really passed from iunv!
  subtype addr_type      is std_logic_vector(addr_bits downto 0);
  type    addr_repl_type is array(integer range <>) of addr_type;

  constant pmpen   : boolean := pmp_entries /= 0;
  constant pmp_msb : integer := physaddr - 1;

  constant LINESZMAX    : integer := maximum(dlinesize, ilinesize);   -- Longest $ line in 32 bit words
  constant TLBNUMMAX    : integer := maximum(dtlbnum, itlbnum);
  constant BUF_HIGH     : integer := log2(LINESZMAX * 4) - 1;         -- MSB of byte addressing in $ line.

  -- Nomenclature here is non-standard. Some explanations:
  --
  -- Way size (here called setsize) in kbyte, and number of ways (here called sets)
  -- are specified rather than total cache size. Cache line size (linesize) in 32 bit words.
  -- Way size:                                                      = setsize * 1024
  -- Cache line size:                                               = linesize * 4
  --
  -- Total cache size:          <way size> * <ways>                 = setsize * 1024 * sets
  -- Number of sets:            <cache size> / <ways> / <line size> = setsize * 1024 / (linesize * 4) =
  --                                                                = 256 * setsize / linesize
  --
  -- Total bits of addressing for a way: log2(<way size>)           = log2(setsize) + 10
  -- Offset (in cache line) bits:        log2(<line size>)          = log2(linesize) + 2
  -- Set index bits:                     <way bits> - <offset bits> = log2(setsize) - log2(linesize) + 8

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
  constant DOFFSET_BITS : integer := 8 + log2(dsetsize) - DLINE_BITS; -- Index above.
  constant DTAG_LOW     : integer := DOFFSET_BITS + DLINE_BITS + 2;   -- Total set addressing above.
  constant DOFFSET_HIGH : integer := DTAG_LOW - 1;
  constant DOFFSET_LOW  : integer := DLINE_BITS + 2;                  -- Offset above.

  constant ILINE_BITS   : integer := log2(ilinesize);                 -- See above.
  constant IOFFSET_BITS : integer := 8 + log2(isetsize) - ILINE_BITS;
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
  constant d_ways   : std_logic_vector(0 to DSETS - 1)                  := (others => '0');
  constant i_ways   : std_logic_vector(0 to ISETS - 1)                  := (others => '0');
  constant d_line   : std_logic_vector(DLINE_HIGH downto 0)             := (others => '0');
  constant i_line   : std_logic_vector(ILINE_HIGH downto 0)             := (others => '0');
  constant i_linew  : std_logic_vector(ILINE_HIGH downto 2)             := (others => '0');
  constant d_sets   : std_logic_vector(DOFFSET_BITS - 1 downto 0)       := (others => '0');
  constant i_sets   : std_logic_vector(IOFFSET_BITS - 1 downto 0)       := (others => '0');
  constant max_sets : std_logic_vector(MAX_SET_BITS - 1 downto 0)       := (others => '0');
  constant d_offset : std_logic_vector(DLINE_P_BITS - 1 downto 0)       := (others => '0');
  constant i_offset : std_logic_vector(ILINE_P_BITS - 1 downto 0)       := (others => '0');

  constant IMUXDATA     : boolean := false;

  constant IMISSPIPE     : boolean := false;
  constant DMISSPIPE     : boolean := false;

  constant ENDIAN_B      : boolean := (endian /= 0);

  type tlbent is record
    valid    : std_ulogic;
    ctx      : ctxword;
    mask     : std_logic_vector(va_size'range);
    vaddr    : std_logic_vector(vpn'range);
    paddr    : std_logic_vector(ppn'range);
    perm     : std_logic_vector(3 downto 0);  -- priv write/priv read/user write/user read OK
    busw     : std_ulogic;
    cached   : std_ulogic;
    modified : std_ulogic;
    acc      : std_logic_vector(2 downto 0);  -- To reproduce PTE for probe ASI
  end record;

  type tlbentarr is array(natural range <>) of tlbent;

  function create_tlbent(x : std_logic) return tlbent is
    -- Non-constant
    variable ent : tlbent;
  begin
    ent.valid      := x;
    ent.ctx        := (others => '0');
    ent.mask     := (others => '0');
    ent.vaddr    := (others => '0');
    ent.paddr    := (others => '0');
    ent.perm     := (others => x);
    ent.busw     := '0';
    ent.cached   := '0';
    ent.modified := x;
    ent.acc      := "011";

    return ent;
  end;

  constant tlbent_defmap : tlbent := create_tlbent('1');
  constant tlbent_empty  : tlbent := create_tlbent('0');

  function create_tlb_def(size : integer) return tlbentarr is
    -- Non-constant
    variable tlb : tlbentarr(0 to size - 1) := (others => tlbent_empty);
  begin
    tlb(0) := tlbent_defmap;

    return tlb;
  end;

  constant tlb_def : tlbentarr(0 to itlbnum - 1) := create_tlb_def(itlbnum);

  subtype lruent is std_logic_vector(4 downto 0);
  type    lruarr is array(natural range <>) of lruent;

  type stbufent is record
    addr      : std_logic_vector(pa'range);
    size      : std_logic_vector(1 downto 0);
    data      : word64;
    snoopmask : std_logic_vector(d_ways'range);
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
                        as_wmmuwalk, as_mmuwalk, as_mmuwalk3, as_mmuwalk4,
                        as_wptectag1, as_wptectag2, as_wptectag3,
                        as_store, as_slowwr, as_wrburst,
                        as_wrasi, as_wrasi2, as_wrasi3,
                        as_rdasi, as_rdasi2, as_rdasi3, as_rdcdiag, as_rdcdiag2,
                        as_getlock, as_parked, as_mmuprobe2, as_mmuprobe3,
                        as_regflush, as_regflush2,
                        as_mmuflush2, as_amo, as_amo_hold);

  type nv_cctrltype is record
    dfrz    : std_ulogic;                             -- dcache freeze enable
    ifrz    : std_ulogic;                             -- icache freeze enable
    dsnoop  : std_ulogic;                             -- data cache snooping
    dcs     : std_logic_vector(1 downto 0);           -- dcache state
    ics     : std_logic_vector(1 downto 0);           -- icache state
    ics_btb : std_logic_vector(1 downto 0);           -- icache state output to btb
  end record;

  constant MMCTRL_CTXP_SZ : integer := 30;

  -- # mmu ctrl reg
  type mmctrl_type1 is record
    e      : std_logic;                      -- enable
    nf     : std_logic;                      -- no fault
    pso    : std_logic;                      -- partial store order
    ctx    : ctxword;                        -- context nr
    ctxp   : std_logic_vector(MMCTRL_CTXP_SZ - 1 downto 0);  -- context table pointer
    tlbdis : std_logic;                      -- tlb disabled
    bar    : std_logic_vector(1 downto 0);   -- preplace barrier
  end record;

  constant mmctrl_type1_none : mmctrl_type1 :=
    ('0', '0', '0', (others => '0'), (others => '0'), '0', (others => '0'));

  -- # fault status reg
  type mmctrl_fs_type is record
    ow    : std_logic;
    fav   : std_logic;
    ft    : std_logic_vector(2 downto 0);   -- fault type
    at_ls : std_logic;                      -- access type, load / store
    at_id : std_logic;                      -- access type, i / dcache
    at_su : std_logic;                      -- access type, su / user
    l     : std_logic_vector(1 downto 0);   -- level
    ebe   : std_logic_vector(7 downto 0);
  end record;

  constant mmctrl_fs_zero : mmctrl_fs_type :=
    ('0', '0', "000", '0', '0', '0', "00", "00000000");

  -- AMO TYPE
  type amo_type is record
    d1type    : std_logic_vector(5 downto 0);
    d2type    : std_logic_vector(5 downto 0);
    reserved  : std_logic;
    hold      : std_logic;
    addr      : std_logic_vector(ahbo.haddr'range);
    data      : word64;
    store     : std_logic_vector(4 downto 1);
    sc        : std_logic;
    s4hit     : std_logic_vector(d_ways'range);
    s4tag     : std_logic_vector(d_tag'range);
    s4offs    : std_logic_vector(d_sets'range);
  end record amo_type;

  type cctrlnv_regs is record
    -- Config registers
    cctrl      : nv_cctrltype;
    mmctrl1    : mmctrl_type1;
    mmfsr      : mmctrl_fs_type;
    mmfar      : std_logic_vector(31 downto 12);
    regflmask  : std_logic_vector(31 downto 4);
    regfladdr  : std_logic_vector(31 downto 4);
    iregflush  : std_ulogic;
    dregflush  : std_ulogic;
    -- FSM state
    s          : cctrlnv_state;
    -- Control flags
    imisspend  : std_ulogic;
    ifailkind  : std_logic_vector(1 downto 0);
    dmisspend  : std_ulogic;
    dfailkind  : std_logic_vector(1 downto 0);
    iflushpend : std_ulogic;
    dflushpend : std_ulogic;
    slowwrpend : std_ulogic;     -- Write cannot be done via store buffer.
    holdn      : std_ulogic;     -- 0 - inhibit progress due to handling slow operation.
    ramreload  : std_ulogic;
    fastwr_rdy : std_ulogic;     -- Ready to do fast write.
    stbuffull  : std_ulogic;     -- No more space in write buffer.
    flushwrd   : std_logic_vector(d_ways'range);
    flushwri   : std_logic_vector(i_ways'range);
    regflpipe  : std_logic_vector(1 downto 0);
    d_mexc     : std_ulogic;     -- Memory exception (unused)
    d_exctype  : std_ulogic;     --  0 - page fault, 1 - access fault (PMP/bus) (unused)
    -- AHB output registers
    ahb_hbusreq   : std_ulogic;
    ahb_hlock     : std_ulogic;
    ahb_htrans    : std_logic_vector(1 downto 0);
    ahb_haddr     : std_logic_vector(ahbo.haddr'range);
    ahb_hwrite    : std_ulogic;
    ahb_hsize     : std_logic_vector(2 downto 0);
    ahb_hburst    : std_logic_vector(2 downto 0);
    ahb_hprot     : std_logic_vector(3 downto 0);
    ahb_hwdata    : word64;
    ahb_snoopmask : std_logic_vector(d_ways'range);
    -- AHB delayed registers
    ahb3_inacc    : std_ulogic;
    ahb3_rdbuf    : std_logic_vector(LINESZMAX * 32 - 1 downto 0);  -- Buffered data from RAM.
    ahb3_error    : std_ulogic;
    ahb3_rdbvalid : std_logic_vector(LINESZMAX - 1 downto 0);
    ahb2_inacc    : std_ulogic;
    ahb2_hwrite   : std_ulogic;
    ahb2_addrmask : std_logic_vector(LINESZMAX - 1 downto 0);
    -- AHB grant tracking
    granted       : std_ulogic;
    -- Write error
    werr          : std_ulogic;
    -- MMU TLBs
    itlb        : tlbentarr(0 to itlbnum - 1);
    dtlb        : tlbentarr(0 to dtlbnum - 1);
    tlbflush    : std_ulogic;
    newent      : tlbent;
    mmuerr      : mmctrl_fs_type;
    curerrclass : std_logic_vector(1 downto 0);
    newerrclass : std_logic_vector(1 downto 0);
    itlbpmru    : std_logic_vector(0 to itlbnum - 1);   -- Vectors for TLB pseudo-MRU
    dtlbpmru    : std_logic_vector(0 to dtlbnum - 1);
    tlbupdate   : std_ulogic;
    -- Tag pipeline registers for special functions (region flush)
    itagpipe    : cram_tags;
    dtagpipe    : cram_tags;
    untagd      : std_logic_vector(2 * DSETS - 1 downto 0);
    untagi      : std_logic_vector(2 * ISETS - 1 downto 0);
    -- IĆache logic registers
    i2pc       : addr_type;
    i2paddr    : std_logic_vector(pa'range);
    i2paddrv   : std_ulogic;                      -- TLB hit and permissions OK
    i2busw     : std_ulogic;                      -- Use wide bus
    i2paddrc   : std_ulogic;                      -- unused (marks whether cacheable)
    i2tlbhit   : std_ulogic;                      -- TLB entry touched
    i2tlbid    : std_logic_vector(log2(itlbnum) - 1 downto 0);
    i2ctx      : ctxword;
    i2su       : std_ulogic;
    i2m        : std_ulogic;
    i2bufmatch : std_ulogic;
    i2hitv     : std_logic_vector(i_ways'range);
    i2validv   : std_logic_vector(i_ways'range);
    i1ten      : std_ulogic;                      -- Instruction access with I$ enabled
    i1pc       : addr_type;
    i1pc_repl  : addr_repl_type(0 to icrepl - 1);
    i1ctx      : ctxword;
    i1su       : std_ulogic;
    i1m        : std_ulogic;                      -- Machine mode execution?
    i1cont     : std_ulogic;
    i1rep      : std_ulogic;                      -- IU stalling itself?
    ibpmiss      : std_ulogic;
    ireadway     : std_logic_vector(i_ways'range);
    irdbufen     : std_ulogic;
    irdbufpaddr  : std_logic_vector(pa'high downto IOFFSET_LOW);     -- Current I$ read buffer base.
    irdbufvaddr  : std_logic_vector(va'high downto IOFFSET_LOW);
    iramaddr     : std_logic_vector(ILINE_HIGH downto ILINE_LOW);    --  Low part of address / 8.
    irephitv     : std_logic_vector(i_ways'range);
    irepvalidv   : std_logic_vector(i_ways'range);
    irepset      : std_logic_vector(maximum(1, log2(ISETS)) - 1 downto 0);
    irepdata     : nv_cdatatype;
    ireptlbhit   : std_ulogic;
    irepfailkind : std_logic_vector(1 downto 0);
    ireptlbpaddr : std_logic_vector(pa'range);
    ireptlbid    : std_logic_vector(log2(itlbnum) - 1 downto 0);
    itlbprobeid  : std_logic_vector(log2(itlbnum) - 1 downto 0);
    -- DCache logic registers
    d2vaddr     : addr_type;
    d2paddr     : std_logic_vector(pa'range);
    d2paddrv    : std_ulogic;                      -- TLB hit and permissions OK
    d2tlbhit    : std_ulogic;                      -- TLB entry touched
    d2tlbamatch : std_ulogic;
    d2tlbid     : std_logic_vector(log2(dtlbnum) - 1 downto 0);
    d2data      : word64;
    d2write     : std_ulogic;
    d2size      : std_logic_vector(1 downto 0);
    d2busw      : std_ulogic;                      -- Use wide bus
    d2tlbmod    : std_ulogic;
    d2hitv      : std_logic_vector(d_ways'range);
    d2validv    : std_logic_vector(d_ways'range);
    d2asi       : std_logic_vector(7 downto 0);
    d2specialasi : std_ulogic;
    d2forcemiss  : std_ulogic;
    d2lock      : std_ulogic;
    d2su        : std_ulogic;
    d2m         : std_ulogic;
    d2sum       : std_ulogic;
    d2mxr       : std_ulogic;
    d2stbuf     : stbufarr(0 to 3);
    d2stbw      : unsigned(1 downto 0);
    d2stba      : unsigned(1 downto 0);
    d2stbd      : unsigned(1 downto 0);
    d2specread  : std_ulogic;
    d2nocache   : std_ulogic;
    -- The d1* are valid when instruction is in memory access stage.
    d1ten        : std_ulogic;                      -- Data access with D$ enabled
    d1chk        : std_ulogic;                      -- Data access (delayed dci.eenaddr, r.holdn = '1')
    d1vaddr      : addr_type;
    d1vaddr_repl : addr_repl_type(0 to dcrepl - 1);
    d1asi        : std_logic_vector(7 downto 0);
    d1su         : std_ulogic;
    d1specialasi : std_ulogic;
    d1forcemiss  : std_ulogic;
    d1m          : std_ulogic;                      -- Machine mode memory access?
    d1sum       : std_ulogic;
    d1mxr       : std_ulogic;
    dramaddr    : std_logic_vector(d_line'high downto DLINE_LOW_REAL);
    dvtagdone   : std_ulogic;
    dregval     : word32;                           -- ASI read value
    dregval64   : word32;
    dregerr     : std_ulogic;
    dtlbrecheck : std_ulogic;
    -- LRU
    ilru        : lruarr(0 to 2 ** IOFFSET_BITS - 1);
    dlru        : lruarr(0 to 2 ** DOFFSET_BITS - 1);
    -- Common flush registers
    flushctr    : std_logic_vector(max_sets'range);
    flushpart   : std_logic_vector(1 downto 0);
    -- MMU table walk registers
    mmusel      : std_logic_vector(2 downto 0);
    -- FPC debug interface (ASI 0x20)
    fpc_mosi    : nv_intreg_mosi_type;
    -- CPU-to-CPU control interface (ASI 0x22)
    c2c_mosi    : nv_intreg_mosi_type;
    -- IU BTB/BHT diagnostic interface (ASI 0x24)
    iudiag_mosi : nv_intreg_mosi_type;
    -- Temp perf counter
    perf        : word32;
    -- Atomic instruction interface (RISC-V)
    amo         : amo_type;
  end record;

  function to_bx_address(addr_in : std_logic_vector;
                         size    : std_logic_vector(1 downto 0)) return std_logic_vector is
  begin
    if ENDIAN_B then
      return addr_in;
    else
      return to_be_address(addr_in, size);
    end if;
  end to_bx_address;


  function create_zeros(v : std_logic_vector) return std_logic_vector is
    variable tmp : std_logic_vector(v'range);
  begin
    tmp := (others => '0');

    return tmp;
  end;

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
    v.s := as_normal; v.imisspend := '0'; v.ifailkind := "00"; v.dmisspend := '0'; v.dfailkind := "00";
    v.iflushpend := '1'; v.dflushpend := '1'; v.slowwrpend := '0'; v.holdn := '1';
    v.ramreload  := '0'; v.fastwr_rdy := '1'; v.stbuffull := '0';
    v.flushwrd   := (others => '0'); v.flushwri := (others => '0'); v.regflpipe := "00";
    v.untagd     := (others => '0'); v.untagi := (others => '0');
    v.d_mexc     := '0'; v.d_exctype := '0';
    v.ahb_hbusreq   := '0'; v.ahb_hlock := '0'; v.ahb_htrans := HTRANS_IDLE;
    v.ahb_haddr     := (others => '0'); v.ahb_hwrite := '0'; v.ahb_hsize := HSIZE_WORD;
    v.ahb_hburst    := HBURST_SINGLE; v.ahb_hprot := "0000"; v.ahb_hwdata := (others => '0');
    v.ahb_snoopmask := (others => '0');
    v.ahb3_inacc    := '0'; v.ahb3_rdbuf := (others => '0'); v.ahb3_error := '0'; v.ahb3_rdbvalid := (others => '0');
    v.ahb2_inacc    := '0'; v.ahb2_hwrite := '0'; v.ahb2_addrmask := (others => '0');
    v.granted     := '0'; v.werr := '0';
    v.itlb        := tlb_def; v.dtlb := tlb_def; v.tlbflush := '0'; v.newent := tlbent_empty; v.mmuerr := mmctrl_fs_zero;
    v.curerrclass := "00"; v.newerrclass := "00";
    v.itlbpmru    := (others => '0'); v.dtlbpmru := (others => '0');
    v.tlbupdate   := '0'; v.itagpipe := (others => (others => '0')); v.dtagpipe := (others => (others => '0'));
    v.i2pc := create_zeros(v.i2pc); v.i2paddr := create_zeros(v.i2paddr); v.i2paddrv := '0';
    v.i2busw     := '0'; v.i2paddrc := '0';
    v.i2tlbhit   := '0'; v.i2tlbid := (others => '0');
    v.i2ctx      := (others => '0'); v.i2su := '0'; v.i2m := '0';
    v.i2bufmatch := '0';
    v.i2hitv     := (others => '0'); v.i2validv := (others => '0');
    v.i1ten      := '0'; v.i1pc := (others => '0'); v.i1ctx := (others => '0'); v.i1su := '0'; v.i1m := '0'; v.i1cont := '0'; v.i1rep := '0';
    v.i1ten      := '0'; v.i1pc := create_zeros(v.i1pc);
    v.i1pc_repl  := (others => create_zeros(v.i1pc));
    v.i1ctx      := (others => '0'); v.i1su := '0'; v.i1m := '0'; v.i1cont := '0'; v.i1rep := '0';
    v.ibpmiss    := '0'; v.iramaddr := (others => '0'); v.ireadway := (others => '0');
    v.irdbufen   := '0'; v.irdbufpaddr := (others => '0'); v.irdbufvaddr := (others => '0');
    v.irephitv   := (others => '0'); v.irepvalidv := (others => '0');
    v.irepset    := (others => '0'); v.irepdata := (others => (others => '0'));
    v.ireptlbhit := '0'; v.irepfailkind := "00"; v.ireptlbpaddr := (others => '0'); v.ireptlbid := (others => '0');
    v.itlbprobeid := (others => '0');
    v.d2vaddr  := create_zeros(v.d2vaddr); v.d2paddr := create_zeros(v.d2paddr); v.d2paddrv := '0';
    v.d2tlbhit := '0'; v.d2tlbamatch := '0'; v.d2tlbid := (others => '0');
    v.d2data   := (others => '0'); v.d2write := '0'; v.d2busw := '0'; v.d2tlbmod := '0';
    v.d2hitv   := (others => '0'); v.d2validv := (others => '0');
    v.d2size   := "00"; v.d2asi := x"00"; v.d2specialasi := '0'; v.d2forcemiss := '0'; v.d2lock := '0';
    v.d2su     := '0'; v.d2m := '0'; v.d2sum := '0'; v.d2mxr := '0';
    v.d2stbuf  := (others => stbufent_zero); v.d2stbw := "00"; v.d2stba := "00"; v.d2stbd := "00";
    v.d2specread := '0'; v.d2nocache := '0';
    v.d1ten    := '0'; v.d1chk := '0'; v.d1vaddr := create_zeros(v.d1vaddr);
    v.d1vaddr_repl  := (others => create_zeros(v.d1vaddr));
    v.d1asi    := (others => '0');
    v.d1specialasi := '0'; v.d1forcemiss := '0';
    v.d1su     := '0'; v.d1m := '0'; v.d1sum := '0'; v.d1mxr := '0';
    v.dramaddr := (others => '0'); v.dvtagdone := '0';
    v.dregval  := (others => '0'); v.dregval64 := (others => '0');
    v.dregerr  := '0'; v.dtlbrecheck := '0';
    v.ilru     := (others => (others => '0')); v.dlru := (others => (others => '0'));
    v.flushctr := (others => '0'); v.flushpart := (others => '0');
    v.mmusel   := (others => '0'); v.fpc_mosi := nv_intreg_mosi_none; v.c2c_mosi := nv_intreg_mosi_none;
    v.iudiag_mosi := nv_intreg_mosi_none;
    v.perf     := (others => '0');
    v.amo.d1type    := (others => '0');
    v.amo.d2type    := (others => '0');
    v.amo.reserved  := '0';
    v.amo.hold      := '0';
    v.amo.addr      := (others => '0');
    v.amo.store     := (others => '0');
    v.amo.sc        := '0';
    v.amo.s4hit     := (others => '0');
    v.amo.s4tag     := (others => '0');
    v.amo.s4offs    := (others => '0');

    return v;
  end cctrlnv_regs_res;


  constant RRES : cctrlnv_regs := cctrlnv_regs_res;

  subtype vbitent is std_logic_vector(d_ways'range);
  type    vbitarr is array(natural range <>) of vbitent;

  type cctrlnv_snoop_regs is record
    sgranted : std_ulogic;
    s3hit    : std_logic_vector(d_ways'range);
    s3tag    : std_logic_vector(d_tag'range);
    s3offs   : std_logic_vector(d_sets'range);
    s3read   : std_logic_vector(d_ways'range);
    s3flush  : std_logic_vector(d_ways'range);
    s3tagmsb : std_logic_vector(2 * DSETS - 1 downto 0);
    s2en     : std_logic_vector(d_ways'range);
    s2tag    : std_logic_vector(d_tag'range);
    s2offs   : std_logic_vector(d_sets'range);
    s2read   : std_logic_vector(d_ways'range);
    s2flush  : std_logic_vector(d_ways'range);
    s2tagmsb : std_logic_vector(2 * DSETS - 1 downto 0);
    s1en     : std_logic_vector(d_ways'range);
    s1tag    : std_logic_vector(d_tag'range);
    s1offs   : std_logic_vector(d_sets'range);
    s1read   : std_ulogic;
    s1flush  : std_logic_vector(d_ways'range);
    s1tagmsb : std_logic_vector(2 * DSETS - 1 downto 0);
    -- DCache valid bits for dtagconf > 0
    validarr : vbitarr(0 to 2 ** DOFFSET_BITS - 1);
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
     s1en     => (others => '0'),
     s1tag    => (others => '0'),
     s1offs   => (others => '0'),
     s1read   => '0',
     s1flush  => (others => '0'),
     s1tagmsb => (others => '0'),
     validarr => (others => (others => '0'))
     );

  constant hconfig : ahb_config_type := (
    0      => ahb_device_reg(VENDOR_GAISLER, GAISLER_RV64GC, 0, 0, 0),
    others => (others => '0'));

  constant addr_check_mask : word8 := u2slv(addr_check, 8);

  signal r, c   : cctrlnv_regs;
  signal rs, cs : cctrlnv_snoop_regs;

  signal dbg    : std_logic_vector(11 downto 0);

  type tlbcheck is record
    hit    : std_ulogic;
    amatch : std_ulogic;
    paddr  : std_logic_vector(pa'range);
    perm   : std_logic_vector(3 downto 0);          -- unused
    hitv   : std_logic_vector(0 to TLBNUMMAX - 1);  -- unused
    id     : std_logic_vector(log2(TLBNUMMAX) - 1 downto 0);
    busw   : std_ulogic;
    cached : std_ulogic;
    modded : std_ulogic;
  end record;

  constant tlbcheck_none : tlbcheck := (
    '0', '0', (others => '0'), (others => '0'),
    (others => '0'), (others => '0'), '0', '0', '0');

  function permitted(x : std_logic; su : std_logic; w : std_logic; lock : std_logic;
                     perm : std_logic_vector(3 downto 0);
                     sum : std_logic; mxr : std_logic) return boolean is
    -- Non-constant
    variable data : word32  := (others => '0');
    variable acc  : std_logic_vector(2 downto 0);
    variable ok   : boolean := false;
  begin
    if is_riscv then
      data(rv_pte_u downto rv_pte_r) := perm;
      acc  := ft_acc_resolve(w & x & su, data);
      if sum = '0' then
        ok := acc(1) = '0';   -- acc(1) is normal check.
      else
        ok := acc(0) = '0';   -- acc(0) is check assuming SUM.
      end if;
      -- Special case when MXR read.
      -- acc(2) is check for read access and X or R allowed.
      -- Check here for correct mode (including SUM bit and supervisor (passed in)).
      if mxr = '1' and
         ((not su) = data(rv_pte_u) or sum = '1') then
        ok := ok or (acc(2) = '0');
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

  -- Physical addresses should have zeroes at the top, right?
  function physical_ok(addr : std_logic_vector) return boolean is
  begin
    -- Addresses are always OK for RV32!
    if riscv_mmu = sv32 then
      return true;
    end if;

    return u2i(addr(addr'high downto physaddr)) = 0;
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

  -- x - execution (ie ITLB, as opposed to DTLB)
  procedure tlb_lookup(x          : std_logic;        tlb      : tlbentarr;
                       vaddr_repl : addr_repl_type;   vaddr_in : addr_type; 
                       dsuaddr : std_logic_vector;    context    : std_logic_vector;
                       su      : std_logic;           w          : std_logic;
                       lock    : std_logic;           enabled    : std_logic;
                       check   : std_logic;           specialasi : std_logic;
                       nullify : std_logic;           repeat     : std_logic;
                       dsuen   : std_logic;           tlbo       : out tlbentarr;
                       tlbchk  : out tlbcheck;        sum        : std_logic;
                       mxr     : std_logic;           display    : boolean := false) is
    variable di     : string(1 to 2)                             := "DI";
    -- Non-constant
    variable vaddr  : std_logic_vector(va'range);
    variable paddr  : std_logic_vector(pa'range);
    variable mask   : std_logic_vector(tlb(0).mask'range)        := (others => '0');
    variable vbusw  : std_logic                                  := '0';
    variable match  : boolean;
    variable pos    : integer;
    variable tmpchk : tlbcheck := tlbcheck_none;
    variable index  : integer                                    := -1;
  begin
    tlbo := tlb;

    for n in tlb'range loop
      if not is_riscv and dsuen = '1' then
        vaddr := dsuaddr(va'range);
      else
        vaddr := vaddr_repl(n mod vaddr_repl'length)(va'range);
      end if;
      match := true;
      pos   := 12;
      for i in tlb(n).mask'reverse_range loop
        match := match and (tlb(n).mask(i) = '0' or
                            get(tlb(n).vaddr, pos, va_size(i)) = get(vaddr, pos, va_size(i)));
        pos := pos + va_size(i);
      end loop;

      if (tlb(n).valid = '1' and tlb(n).ctx = context and
          match) or
         (not is_riscv and (n) = 0 and enabled = '0')
      then
        if permitted(x, su, w, lock, tlb(n).perm, sum, mxr) then
          tmpchk.hit     := '1';
          tmpchk.hitv(n) := '1';  -- unused (had better only get one bit set, anyway!)
        else
          -- Invalidate matching TLB entry on permission fail since there will be a
          -- new MMU walk, and it would be a bad idea to have two instances in the TLB!
          -- Will not invalidate on repeat due to stall, since walk already done.
          if check = '1' and specialasi = '0' and nullify = '0' and repeat = '0' then
            tlbo(n).valid := '0';
          end if;
        end if;
        index := (n);
        -- Note that 'or' can be used since only one TLB entry may really hit,
        -- and it avoids prioritizing so less logic.
        tmpchk.amatch  := '1';
        set(tmpchk.paddr, 12, get(tmpchk.paddr, 12, ppn'length) or tlb(n).paddr);
        tmpchk.id      := tmpchk.id      or u2slv((n), tmpchk.id'length);
        tmpchk.busw    := tmpchk.busw    or tlb(n).busw;
        tmpchk.cached  := tmpchk.cached  or tlb(n).cached;
        tmpchk.modded  := tmpchk.modded  or tlb(n).modified;
        mask           := (others => '0');
        mask           := mask           or tlb(n).mask;
        paddr          := (others => '0');
        if enabled = '1' then
          virtual2physical(vaddr, mask, paddr);
        else
          virtual2physical(vaddr, create_zeros(mask), paddr);
        end if;
        tmpchk.paddr   := tmpchk.paddr or paddr;

      end if;
    end loop;

   
    if not is_riscv and dsuen = '1' then
      tmpchk.paddr(11 downto 0) := tmpchk.paddr(11 downto 0) or dci.maddress(11 downto 0);
    else
      tmpchk.paddr(11 downto 0) := tmpchk.paddr(11 downto 0) or
                                   vaddr_in(11 downto 0);
    end if;
    if enabled = '1' and check = '1' then
      if tmpchk.hit = '0'then
      else
      end if;
    end if;

    -- Select bus width from TLB unless 4 GiB entry, then decode from virt addr
    vbusw := dec_wbmask_fixed(vaddr_in(ahbo.haddr'high downto 2), wbmask);
    if mask(1) = '0' then
      tmpchk.busw := tmpchk.busw or vbusw;
    end if;

    -- Select cacheability from TLB unless cache is off
    if enabled = '0' then
      tmpchk.cached := ahb_slv_dec_cache(vaddr_in(ahbo.haddr'range), ahbso, cached);
    end if;

    tlbchk := tmpchk;
  end;

  type line_info is record
    tag   : cword3;    -- From libiunv (32 bit)
  end record;
  type line_info_arr is array (integer range <>) of line_info;  -- Array of sets


  -- Tag compare logic
  procedure tags_check(info    : line_info_arr;        vaddr   : std_logic_vector;
                       enabled : std_logic;            ten     : std_logic;
                       tlbhit  : std_logic;            index   : std_logic_vector;
                       set     : out std_logic_vector; validv  : out std_logic_vector;
                       hitv    : out std_logic_vector; hit     : out std_logic;
                       badtag  : out std_logic) is
    -- Non-constant
    variable valid     : std_logic := '0';
    variable tmphit    : std_logic := '0';
    variable tmpset    : std_logic_vector(set'range)    := (others => '0');
    variable tmpvalidv : std_logic_vector(validv'range) := (others => '0');
  begin
    badtag := '0';
    hitv   := (hitv'range => '0');
    for i in info'range loop
      -- Check for (tag vs actual vaddr OK), access being done and TLB hit
      if (info(i).tag(i_tag'range) = vaddr(i_tag'range)) and
         ten = '1' and tlbhit = '1' then
        hitv(i) := '1';
        if tmphit = '1' then
          badtag := '1';
        end if;
        tmphit  := '1';
        tmpset  := tmpset or u2slv(i, tmpset'length);
      end if;
      tmpvalidv(i) := info(i).tag(0);
    end loop;

    if dtagconf > 0 and index'length > 0 then
      if notx(index) then
        tmpvalidv := rs.validarr(u2i(index));
      else
        setx(tmpvalidv);
      end if;
    end if;

    valid  := tmpvalidv(u2i(tmpset));
    hit    := tmphit and valid;
    set    := tmpset;
    validv := tmpvalidv;
  end;

  procedure itags_check(cramo   : nv_cram_out_type;     paddr   : std_logic_vector;
                        enabled : std_logic;            ten     : std_logic;
                        tlbhit  : std_logic;
                        set     : out std_logic_vector; validv  : out std_logic_vector;
                        hitv    : out std_logic_vector; hit     : out std_logic;
                        badtag  : out std_logic) is
    -- No separate valid bits for instruction cache, so use dummy zero length index.
    variable dummy : std_logic_vector(0 downto 1) := (others => '0');
    -- Non-constant
    variable info : line_info_arr(i_ways'range);
  begin
    for i in info'range loop
      info(i).tag              := (others => '0');
      info(i).tag(i_tag'range) := cramo.itagdout(i)(TAG_HIGH - ITAG_LOW + 1 downto 1);
      info(i).tag(0)           := cramo.itagdout(i)(0);
    end loop;
    tags_check(info, paddr, enabled, ten, tlbhit, dummy, set, validv, hitv, hit, badtag);
  end;

  procedure dtags_check(dcramo  : nv_cram_out_type;     paddr  : std_logic_vector;
                        enabled : std_logic;            ten    : std_logic;
                        tlbhit  : std_logic;            index  : std_logic_vector;
                        set     : out std_logic_vector; validv : out std_logic_vector;
                        hitv    : out std_logic_vector; hit : out std_logic;
                        badtag  : out std_logic) is
    -- Non-constant
    variable info : line_info_arr(d_ways'range);
  begin
    for i in info'range loop
      info(i).tag              := (others => '0');
      info(i).tag(i_tag'range) := cramo.dtagcdout(i)(TAG_HIGH - DTAG_LOW + 1 downto 1);
      info(i).tag(0)           := cramo.dtagcdout(i)(0);
    end loop;
    tags_check(info, paddr, enabled, ten, tlbhit, index, set, validv, hitv, hit, badtag);
  end;

begin

  comb: process(r, rs, rst, ici, dci, ahbi, ahbsi, ahbso, cramo, csr, fpuholdn, hclken, fpc_miso, c2c_miso)

    function mmu_base(r : cctrlnv_regs; csr : csrtype) return std_logic_vector is
    begin
      if is_riscv then
        return gaisler.mmucacheconfig.satp_base(riscv_mmu, csr.satp);
      else
        return r.mmctrl1.ctxp(25 downto 4) & r.mmctrl1.ctx & "00";
      end if;
    end;

    -- Return current context, cut down to appropriate size.
    function mmu_ctx(r : cctrlnv_regs; csr : csrtype) return std_logic_vector is
    begin
      if is_riscv then
        return gaisler.mmucacheconfig.satp_asid(riscv_mmu, csr.satp)(ctxword'range);
      else
        return r.mmctrl1.ctx;
      end if;
    end;

    function mmu_enabled(r : cctrlnv_regs; csr : csrtype) return std_logic is
    begin
      if no_mmu then
        return '0';
      end if;
      if is_riscv then
        if gaisler.mmucacheconfig.satp_mode(riscv_mmu, csr.satp) /= 0 then
          return '1';
        else
          return '0';
        end if;
      else
        return r.mmctrl1.e;
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
                          hsize : std_logic_vector(2 downto 0);
                          le    : boolean) return std_logic_vector is
      -- Non-constant
      variable vmask64  : std_logic_vector(1 downto 0);
      variable vmask128 : std_logic_vector(3 downto 0);
      variable vmask256 : std_logic_vector(7 downto 0);
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
    end getvalidmask;

    -- Create a byte (8 bit) mask to select a properly sized chunk
    -- out of a 32 bit vector, depending on address.
    -- Size can be 1-4 bytes (8-32 bits).
    function getdmask(addr : std_logic_vector;
                      size : std_logic_vector(1 downto 0);
                      le   : boolean) return std_logic_vector is
      variable vaddr : std_logic_vector(addr'length - 1 downto 0) := addr;
      variable vsize : std_logic_vector(size'length - 1 downto 0) := size;
      -- Non-constant
      variable dmask : std_logic_vector(3 downto 0)               := "1111";
    begin
      -- <32 (2^2 bytes) bit access?
      if vsize(1) = '0' then
        -- Mask off low or high depending on address alignment.
        if vaddr(1) = '0' then
          dmask := dmask and "1100";
        else
          dmask := dmask and "0011";
        end if;
      end if;
      -- 8 (2^0 bytes) bit access?
      if vsize(1 downto 0) = "00" then
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
    end getdmask;

    function getdmask64(addr : std_logic_vector;
                        size : std_logic_vector;
                        le : boolean) return std_logic_vector is
      variable vaddr : std_logic_vector(addr'length - 1 downto 0) := addr;
      variable vsize : std_logic_vector(size'length - 1 downto 0) := size;
      -- Non-constant
      variable dmask : std_logic_vector(7 downto 0)               := "11111111";
    begin
      if vsize(1 downto 0) /= "11" then
        if vaddr(2) = '0' xor le then
          dmask := dmask and "11110000";
        else
          dmask := dmask and "00001111";
        end if;
      end if;
      if vsize(1) = '0' then
        if vaddr(1) ='0' xor le then
          dmask := dmask and "11001100";
        else
          dmask := dmask and "00110011";
        end if;
      end if;
      if vsize(1 downto 0) = "00" then
        if vaddr(0) = '0' xor le then
          dmask := dmask and "10101010";
        else
          dmask := dmask and "01010101";
        end if;
      end if;

      return dmask;
    end getdmask64;

    function cache_cfg5(crepl, sets, linesize, setsize, lock, snoop,
                        lram, lramsize, lramstart, mmuen : integer) return std_logic_vector is
      variable cfg : word32;
    begin
      cfg := (others => '0');
      if sets /= 1 then
        cfg(30 downto 28) := conv_std_logic_vector(crepl * 2 + 1, 3);
      end if;
      if snoop /= 0 then
        cfg(27) := '1';
      end if;
      cfg(26 downto 24) := conv_std_logic_vector(sets - 1, 3);
      cfg(23 downto 20) := conv_std_logic_vector(log2(setsize), 4);
      cfg(18 downto 16) := conv_std_logic_vector(log2(linesize), 3);
      cfg(3  downto  3) := conv_std_logic_vector(mmuen, 1);

      return cfg;
    end cache_cfg5;

    function uniquemsb(msbin: std_logic_vector; wways: std_logic_vector) return std_logic_vector is
      -- Non-constant
      variable r       : std_logic_vector(msbin'length - 1 downto 0) := (others => '0');
      variable msbused : std_logic_vector(0 to 3)                    := "0000";
      variable nmsb    : std_logic_vector(1 downto 0);
    begin
      for x in 0 to msbin'length / 2 - 1 loop
        if wways(x) = '0' then
          msbused(u2i(msbin(2 * x + 1 downto 2 * x))) := '1';
        end if;
      end loop;
      for x in 0 to msbin'length / 2 - 1 loop
        if wways(x) = '0' then
          nmsb     := "11";
          for y in 3 downto 0 loop
            if msbused(y) = '0' then
              nmsb := u2slv(y, 2);
            end if;
          end loop;
          r(2 * x + 1 downto 2 * x) := nmsb;
          msbused(u2i(nmsb))        := '1';
        end if;
      end loop;

      return r;
    end uniquemsb;

    variable v         : cctrlnv_regs;
    variable vs        : cctrlnv_snoop_regs;
    variable oico      : nv_icache_out_type;
    variable odco      : nv_dcache_out_type;
    variable oahbo     : ahb_mst_out_type;
    variable ocrami    : nv_cram_in_type;
    variable ihit      : std_ulogic;
    variable ivalid    : std_ulogic;
    variable ibufaddrmatch : std_ulogic;
    variable ihitv     : std_logic_vector(i_ways'range);
    variable ivalidv   : std_logic_vector(i_ways'range);
    variable iset      : std_logic_vector(maximum(1, log2(ISETS)) - 1 downto 0);
    variable icont     : std_ulogic;
    variable itlbchk   : tlbcheck;
    variable ilruent   : lruent;
    variable dhitv     : std_logic_vector(d_ways'range);
    variable dvalidv   : std_logic_vector(d_ways'range);
    variable dhit      : std_ulogic;
    variable dvalid    : std_ulogic;
    variable dset      : std_logic_vector(1 downto 0);
    variable dasi      : std_logic_vector(7 downto 0);
    variable dsu       : std_ulogic;
    variable dlock     : std_ulogic;
    variable dspecialasi : std_ulogic;
    variable dforcemiss  : std_ulogic;
    variable dtlbchk     : tlbcheck;
    variable dtlb_write  : std_ulogic;
    variable dtlb_lock   : std_ulogic;
    variable dtenall   : std_ulogic;
    variable dlruent   : lruent;
    variable vaddr4    : std_logic_vector(3 downto 0);
    variable vaddr3    : std_logic_vector(2 downto 0);  -- sub field for ASI
    variable fastwr    : std_ulogic;                    -- simple write
    variable vdiagasi  : std_logic_vector(1 downto 0);
    variable d64       : word64;
    variable dwriting  : std_ulogic;
    variable d32       : word32;

    variable rdb64     : word64;
    alias    rdb32    is rdb64(31 downto 0);
    variable rdb32v    : std_ulogic;
    variable rdb64v    : std_ulogic;
    variable vneedwb   : std_ulogic;
    variable vneedwblock : std_ulogic;
    variable vway      : unsigned(1 downto 0);
    variable vhit      : std_ulogic;
    variable vtmp2     : std_logic_vector(1 downto 0);
    variable vtmp3     : std_logic_vector(2 downto 0);
    variable vwdata128 : std_logic_vector(127 downto 0);
    variable vwdata64  : word64;
    variable vwdata    : std_logic_vector(cdataw - 1 downto 0);
    variable vwad      : std_logic_vector(4 downto 3);
    variable vtmp4i    : std_logic_vector(0 to MAXSETS - 1);
    variable keepreq   : std_ulogic;

    variable frdmatch  : std_logic_vector(d_ways'range);
    variable frimatch  : std_logic_vector(i_ways'range);
    variable frmsbd    : std_logic_vector(2 * DSETS - 1 downto 0);
    variable frmsbi    : std_logic_vector(2 * ISETS - 1 downto 0);

    -- PMP
    variable pmp_prv   : std_logic_vector(PRIV_LVL_S'range);
    variable pmp_mprv  : std_ulogic;
    variable pmp_mpp   : std_logic_vector(PRIV_LVL_S'range);
    variable pmp_virt  : std_logic_vector(va'range);
    variable pmp_addr  : std_logic_vector(pa'range);
    variable pmp_iaddr : std_logic_vector(pa'range);
    variable pmp_size  : std_logic_vector(1 downto 0);
    variable pmp_acc   : std_logic_vector(PMP_ACCESS_W'range);
    variable pmp_valid : std_ulogic;
    variable pmp_direct : std_logic;
    variable pmp_type  : std_logic_vector(1 downto 0);
    variable pmp_xc    : std_ulogic;
    variable pmp_cause : std_logic_vector(3 downto 0);    -- Dummies
    variable pmp_tval  : std_logic_vector(3 downto 0);    -- Dummies
    variable pmp_mmu   : boolean;

    variable pmp_dfail : boolean;

    variable start_walk : boolean;
    variable mmu_data  : word64;         -- To fake MMU page table data from mmu_base.

    variable iaddr_ok  : boolean;
    variable daddr_ok  : boolean;

    variable i_mexc    : std_ulogic;     -- Instruction memory exception
    variable i_exctype : std_ulogic;     --  0 - page fault, 1 - access fault (PMP/bus)
    variable d_mexc    : std_ulogic;     -- Data memory exception
    variable d_exctype : std_ulogic;     --  0 - page fault, 1 - access fault (PMP/bus)

    -- Atomic operations
    variable amo_op    : std_logic_vector(3 downto 0);
    variable amo_src1  : word64;
    variable amo_src2  : word64;
    variable amo_data  : word64;


    -- Get cache control parameters
    function get_ccr(r : cctrlnv_regs; rs : cctrlnv_snoop_regs) return std_logic_vector is
      -- Non-constant
      variable ccr : word32 := (others => '0');
    begin
      ccr(23) := r.cctrl.dsnoop;
      ccr(17) := '1';
      ccr(15 downto 14) := r.iflushpend & r.dflushpend;
      ccr(5 downto 0) := r.cctrl.dfrz & r.cctrl.ifrz & r.cctrl.dcs & r.cctrl.ics;

      return ccr;
    end get_ccr;

    -- Set cache control parameters
    procedure set_ccr(val : std_logic_vector) is
      -- Non-constant
      variable vx : word32 := val;
    begin
      v.cctrl.dsnoop  := vx(23);
      v.dflushpend    := v.dflushpend or vx(22);
      v.iflushpend    := v.iflushpend or vx(21);
      v.cctrl.dfrz    := vx(5);
      v.cctrl.ifrz    := vx(4);
      v.cctrl.dcs     := vx(3 downto 2);
      v.cctrl.ics     := vx(1 downto 0);
      v.cctrl.ics_btb := vx(1 downto 0);
    end set_ccr;

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
    end pmru_decode;

    function calc_lruent(oent : lruent; hway : unsigned(1 downto 0); nsets : integer) return lruent is
      -- Non-constant
      variable nent : lruent;
    begin
      nent := (others => '0');
      case nsets is
        when 1 =>
          nent             := "00000";
        when 2 =>
          nent(4)          := '0';
          nent(3)          := not hway(0);
          nent(2 downto 0) := "000";
        when 3 =>
          nent(4 downto 2) := lru_3set_table(u2i(oent(4 downto 2)))(u2i(hway));
          nent(1 downto 0) := "00";
        when others =>
          nent             := lru_4set_table(u2i(oent))(u2i(hway));
      end case;

      return nent;
    end calc_lruent;

    -- Return vector with a bit set at n mod w.
    -- Normally only used with n < w.
    function decwrap(n : std_logic_vector; w : integer) return std_logic_vector is
      -- Non-constant
      variable r : std_logic_vector(0 to 2 ** n'length - 1) := (others => '0');
    begin
      for i in r'range loop
        if n = u2slv(i, n'length) then
          r(i mod w) := '1';
        end if;
      end loop;

      return r;
    end decwrap;

    function flushmatch(e : tlbent; vaddr : std_logic_vector; curctx : std_logic_vector) return std_ulogic is
      variable fltp    : std_logic_vector(3 downto 0) := vaddr(11 downto 8);
      -- Non-constant
      variable r       : std_ulogic := '0';
      variable acctype : std_ulogic := '0';
      variable ctxeq   : std_ulogic := '0';
    begin
      if unsigned(e.acc) > 5 then
        acctype := '1';
      end if;
      if e.ctx = curctx then
        ctxeq := '1';
      end if;
      case fltp is
        when "0000" =>
        when "0001" =>
          if (acctype = '1' or ctxeq = '1') and vaddr(31 downto 18) = e.vaddr(31 downto 18) and e.mask(2) = '1' then
            r := '1';
          end if;
        when "0010" =>
          if (acctype = '1' or ctxeq = '1') and vaddr(31 downto 24) = e.vaddr(31 downto 24) and e.mask(1) = '1' then
            r := '1';
          end if;
        when "0011" =>
          if acctype = '0' and ctxeq = '1' then
            r := '1';
          end if;
        when "0100" => r := '1';
        when others => r := '0';
      end case;

      return r;
    end flushmatch;

    -- Select way to replace
    function replace_vec(validv : std_logic_vector; lruent : std_logic_vector) return std_logic_vector is
      -- Non-constant
      variable hitv   : std_logic_vector(validv'range) := (others => '0');
      variable vtmp4i : std_logic_vector(0 to MAXSETS - 1);
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
        vtmp4i    := decwrap(lruent(4 downto 3), validv'length);
        hitv      := hitv or vtmp4i(hitv'range);
      end if;

      return hitv;
    end;

    procedure burst_update(linesize       : in integer; wide : in boolean;
                           ahb_htrans_out : out std_logic_vector;
                           ahb_haddr_out  : out std_logic_vector) is
      -- Non-constant
      variable ahb_htrans : std_logic_vector(HTRANS_IDLE'range)   := r.ahb_htrans;
      variable ahb_haddr  : std_logic_vector(ahb_haddr_out'range) := r.ahb_haddr;
    begin
      if ahbi.hresp(1) = '1' then
        ahb_htrans := HTRANS_IDLE;
      end if;
      if ahbi.hready = '1' then
        -- Advance haddr/htrans
        if r.granted = '1' and ahbi.hresp(1) = '0' and r.ahb_htrans(1) = '1' then
          -- Move haddr forward
          -- Note we can not look at r.i2busw here as it may get updated while streaming
          --   therefore we look directly at ahb_hsize instead
          if wide then
            uadd_range(r.ahb_haddr, 1, ahb_haddr(BUF_HIGH downto log2(busw / 8)));
          else
            uadd_range(r.ahb_haddr, 1, ahb_haddr(BUF_HIGH downto 2));
          end if;
          ahb_htrans := HTRANS_SEQ;
          -- Was last address the final one?
          if all_1(r.ahb_haddr(log2(linesize * 4) - 1 downto log2(busw / 8))) and
            (all_1(r.ahb_haddr(log2(busw / 8) - 1 downto 2)) or wide) then
            ahb_htrans := HTRANS_IDLE;
          end if;
        elsif r.ahb2_inacc = '1' and ahbi.hresp(1) = '1' then
          -- Move haddr backward for retry/split
          if wide then
            uadd_range(r.ahb_haddr, -1, ahb_haddr(BUF_HIGH downto log2(busw / 8)));
          else
            uadd_range(r.ahb_haddr, -1, ahb_haddr(BUF_HIGH downto 2));
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


    d_mexc    := '0';
    d_exctype := '0';
    i_mexc    := '0';
    i_exctype := '0';

    start_walk := false;

    iaddr_ok  := true;
    daddr_ok  := true;

    pmp_prv    := (others => '0');
    pmp_mprv   := '0';
    pmp_mpp    := (others => '0');
    pmp_virt   := (others => '0');
    pmp_addr   := (others => '0');
    pmp_iaddr  := (others => '0');
    pmp_size   := (others => '0');
    pmp_acc    := (others => '0');
    pmp_valid  := '0';
    pmp_direct := '0';
    pmp_type   := (others => '0');
    pmp_xc     := '0';
    pmp_cause  := (others => '0');
    pmp_tval   := (others => '0');
    pmp_mmu    := false;

    oico.data     := cramo.idatadout;
    oico.set      := "00";
    oico.mexc     := '0';
    oico.exctype  := '0';
    oico.hold     := r.holdn;
    oico.flush    := '0';
    oico.diagrdy  := '0';
    oico.diagdata := (others => '0');
    oico.mds      := '1';
    oico.cfg      := (others => '0');
    oico.bpmiss   := r.ibpmiss;
    oico.eocl     := '0';
    if r.i2pc(2) = '1' and r.i2pc(3) = '1' and (ilinesize = 4 or r.i2pc(4) = '1') then
      oico.eocl   := '1';
    end if;
    oico.badtag   := '0';
    oico.ics_btb  := r.cctrl.ics_btb;
    oico.btb_flush:= '0';
    oico.parked   := '0';

      odco.data   := cramo.ddatadout;
    odco.set      := "00";
    odco.mexc     := '0';
    odco.exctype  := '0';
    odco.hold     := r.holdn;
    odco.mds      := '1';
    odco.werr     := r.werr;
    odco.cache    := '0';
    odco.wbhold   := '0';
    odco.badtag   := '0';
    odco.logan    := (others => '0');
    odco.iudiag_mosi := r.iudiag_mosi;

    oahbo.hbusreq := r.ahb_hbusreq;
    oahbo.hlock   := r.ahb_hlock;
    oahbo.htrans  := r.ahb_htrans;
    oahbo.haddr   := r.ahb_haddr;
    oahbo.hwrite  := r.ahb_hwrite;
    oahbo.hsize   := r.ahb_hsize;
    oahbo.hburst  := r.ahb_hburst;
    oahbo.hprot   := r.ahb_hprot;
    oahbo.hwdata  := ahbdrivedata(r.ahb_hwdata);
    oahbo.hirq    := (others => '0');
    oahbo.hconfig := hconfig;
    oahbo.hindex  := hindex;


    ocrami.iindex    := (others => '0');
    ocrami.idataoffs := (others => '0');
    if r.holdn = '0' then
      ocrami.iindex(i_sets'range)      := r.i1pc(i_index'range);
      ocrami.idataoffs(i_offset'range) := r.i1pc(ILINE_HIGH downto ILINE_LOW);
    else
      ocrami.iindex(i_sets'range)      := ici.rpc(i_index'range);
      ocrami.idataoffs(i_offset'range) := ici.rpc(ILINE_HIGH downto ILINE_LOW);
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
      if r.iramaddr = u2slv(x, r.iramaddr'length) then
        if not ENDIAN_B then
          ocrami.idatadin := get(r.ahb3_rdbuf, (LINESZMAX / 2 - 1 - x) * 64, 64);
        else
          ocrami.idatadin := get(r.ahb3_rdbuf, x * 64, 64);
        end if;
      end if;
    end loop;
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
    else
      ocrami.ddataindex(d_sets'range)  := dci.eaddress(d_index'range);
      ocrami.ddataoffs(d_offset'range) := dci.eaddress(DLINE_HIGH downto DLINE_LOW_REAL);
    end if;
    ocrami.ddataen     := (others => '0');
    ocrami.ddatawrite  := (others => '0');
    ocrami.ddatadin    := (others => (others => '0'));
    for w in d_ways'range loop
      ocrami.ddatadin(w) := dci.edata;
    end loop;

    vwad        := (others => '0');
    vwad(d_line'high downto DLINE_LOW_REAL) := r.dramaddr;
    vwdata128   := r.ahb3_rdbuf(4 * 32 - 1 downto 0);
    if (vwad(4) = '0') xor ENDIAN_B then
      vwdata128 := r.ahb3_rdbuf(LINESZMAX * 32 - 1 downto LINESZMAX * 32 - 128);
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
    if is_riscv and (r.i1m = '1' or mmu_enabled(r, csr) = '0') then
      itlbchk         := tlbcheck_none;
      -- Some non-defaults to "fake" an MMU access
      itlbchk.hit     := '1';
      if r.i1pc'length <= itlbchk.paddr'length then
        itlbchk.paddr(r.i1pc'range) := r.i1pc;
      else
        itlbchk.paddr := r.i1pc(itlbchk.paddr'range);
      end if;
      itlbchk.busw    := dec_wbmask_fixed(r.i1pc(ahbo.haddr'high downto 2), wbmask);
      itlbchk.cached  := ahb_slv_dec_cache(r.i1pc(ahbo.haddr'range), ahbso, cached);
      itlbchk.modded  := '1';
      iaddr_ok        := physical_ok(r.i1pc);
      if addr_check_mask(5) = '0' then
        iaddr_ok      := true;
      end if;
    else
      if is_riscv then
        iaddr_ok      := virtual_ok(r.i1pc);
        if addr_check_mask(4) = '0' then
          iaddr_ok    := true;
        end if;
      end if;
      -- Pass along actual r.i1pc too, for LEON5 code equivalence.
      tlb_lookup('1', r.itlb, r.i1pc_repl , r.i1pc, "0", mmu_ctx(r, csr), r.i1su, '0', '0',
                 mmu_enabled(r, csr) and not r.i1m, r.i1ten, '0', ici.inull, r.i1rep, '0',
                 v.itlb, itlbchk, '0', '0', false);
    end if;

    -- PMP - a separate unit is needed for cached instruction fetch!
    if is_riscv then
      pmp_iaddr := (others => '0');
      if r.i1m = '0' then
        pmp_iaddr(itlbchk.paddr'range) := itlbchk.paddr;
      else
        if pmp_iaddr'length <= r.i1pc'length then
          pmp_iaddr := r.i1pc(pmp_iaddr'range);
        else
          pmp_iaddr(r.i1pc'range) := r.i1pc;
        end if;
      end if;
      -- Machine, supervisor or user mode?
      pmp_prv     := PRIV_LVL_M;
      if r.i1m = '0' then
        pmp_prv   := PRIV_LVL_S;
        if r.i1su = '0' then
          pmp_prv := PRIV_LVL_U;
        end if;
      end if;
      if pmpen then
        pmp_unit(pmp_prv, csr.precalc, csr.pmpcfg0, csr.pmpcfg2,
                 pmp_mprv, pmp_mpp,   -- Not used for execution
                 r.i1pc, pmp_iaddr,
                 "11", PMP_ACCESS_X,  -- Always 8 byte access
--                 r.i1ten and not ici.inull,
                 r.i1ten,
                 pmp_xc, pmp_cause, pmp_tval,
                 pmp_entries, pmp_no_tor, pmp_g, pmp_msb);
        if itlbchk.hit = '0' then
          pmp_xc := '0';
        end if;
      end if;
      if addr_check_mask(6) = '0' then
        pmp_xc := '0';
      end if;
      if pmp_xc = '1' then
        v.ifailkind := "11";
      elsif r.imisspend = '0' then
        v.ifailkind := "00";
      end if;
    end if;

    if is_riscv and not iaddr_ok then
      if itlbchk.hit = '1' then
        -- Signal page/access fault
        v.ifailkind := "1" & (r.i1m or not mmu_enabled(r, csr));
      end if;
    end if;



    -- "free running" TLB id register used in probe state
    v.itlbprobeid := itlbchk.id;

    -- Note that this is for the previous (registered) access.
    itags_check(cramo, itlbchk.paddr, mmu_enabled(r, csr) and not r.i1m, r.i1ten,
                itlbchk.hit, iset, ivalidv, ihitv, ihit, oico.badtag);

    ihitv  := ihitv and ivalidv;


    if v.ifailkind(1) = '1' then
      itlbchk.hit := '0';
      ihit        := '0';
      ihitv       := (others => '0');
    end if;

    if r.i1rep = '1' then
      ihitv         := r.irephitv;
      ivalidv       := r.irepvalidv;
      iset          := r.irepset;
      ihit          := ihitv(u2i(iset));
      oico.data     := r.irepdata;
      itlbchk.hit   := r.ireptlbhit;
      itlbchk.paddr := r.ireptlbpaddr;
      itlbchk.id    := r.ireptlbid;
      v.ifailkind   := r.irepfailkind;
    end if;

    ibufaddrmatch := '0';
    -- If line fetch buffer filling, look for hit in it.
    if r.irdbufen = '1' and v.ifailkind(1) = '0' then
      ihit       := '0';
      if r.i1pc(r.irdbufvaddr'range) = r.irdbufvaddr then
        ibufaddrmatch := '1';
        if not ENDIAN_B then
          if r.ahb3_rdbvalid(LINESZMAX - 1 - u2i(r.i1pc(i_linew'range))) = '1' then
            ihit := '1';
          end if;
        else
          if r.ahb3_rdbvalid(u2i(r.i1pc(i_linew'range))) = '1' then
            ihit := '1';
          end if;
        end if;
      end if;
    elsif r.i1cont = '1' and v.ifailkind(1) = '0' then
      ihitv    := r.i2hitv;
      ivalidv  := r.i2validv;
      ihit     := orv(r.i2hitv);
      iset     := (others => '0');
      for x in i_ways'range loop
        if ihitv(x) = '1' then
          iset := iset or u2slv(x, iset'length);
        end if;
      end loop;
    end if;

    oico.set             := (others => '0');
    oico.set(iset'range) := iset;
    if IMUXDATA then
      oico.data(0)       := oico.data(u2i(oico.set));
      oico.set           := (others => '0');
    end if;

    if r.imisspend = '1' then
      oico.mds := '0';
    end if;
    if r.irdbufen = '1' then
      -- Mux out buffer data
      oico.set           := "00";
      for x in 0 to LINESZMAX / 2 - 1 loop
        if (r.imisspend = '1' and u2i(r.i2pc(BUF_HIGH downto 3)) = x) or
           (r.imisspend = '0' and u2i(r.i1pc(BUF_HIGH downto 3)) = x) then
          if not ENDIAN_B then
            oico.data(0) := get(r.ahb3_rdbuf, (LINESZMAX / 2 - x) * 64 - 64, 64);
          else
            oico.data(0) := get(r.ahb3_rdbuf, x * 64, 64);
          end if;
        end if;
        -- Allow for streaming from read data buffer

        if r.imisspend = '1' and r.i2bufmatch = '1' and u2i(r.i2pc(BUF_HIGH downto 3)) = x then
          if not ENDIAN_B then
            if get(r.ahb3_rdbvalid, LINESZMAX - 2 * x - 2, 2) = "11" then
              v.imisspend := '0';
            end if;
          else
            if get(r.ahb3_rdbvalid, 2 * x, 2) = "11" then
              v.imisspend := '0';
            end if;
          end if;
        end if;
      end loop;
    end if;


    -- Main hit/miss checking logic (v.imisspend propagates to main FSM)
    -- Stage 2 ITLB update in case of hit
--pragma translate_off
    if is_x(r.i2pc) then
      ilruent := (others => 'X');
    else
--pragma translate_on
      ilruent := r.ilru(u2i(r.i2pc(i_index'range)));
--pragma translate_off
    end if;
--pragma translate_on
    if r.holdn = '1' then
      vway     := "00";
      vhit     := '0';
      for x in r.i2hitv'range loop
        if r.i2hitv(x) = '1' then
          vhit := '1';
          vway := vway or to_unsigned(x, 2);
        end if;
      end loop;
      if vhit = '1' then
        v.ilru(u2i(r.i2pc(i_index'range))) := calc_lruent(ilruent, vway, ISETS);
      end if;
    end if;

    -- Stage 1 tag check (insn in fetch stage)
    if r.holdn = '1' then
      v.ibpmiss    := '0';
    end if;
    if r.holdn = '1' then
      dbg(0)          <= '1';
      v.i2pc          := r.i1pc;
      v.i2paddr       := itlbchk.paddr;
      v.i2paddrv      := itlbchk.hit;
      v.i2tlbhit      := itlbchk.hit;
      v.i2tlbid       := itlbchk.id;
      v.i2busw        := itlbchk.busw;
      v.i2paddrc      := itlbchk.cached;
      v.i2ctx         := r.i1ctx;
      v.i2su          := r.i1su;
      v.i2m           := r.i1m;
      v.i2bufmatch    := ibufaddrmatch;
      if r.irdbufen = '0' then
        v.i2validv    := ivalidv;
        v.i2hitv      := ihitv;
        v.irdbufvaddr := r.i1pc(r.irdbufvaddr'range);
        v.irdbufpaddr := v.i2paddr(r.irdbufpaddr'range);
      end if;
      -- Set icmiss pending bit
      if ici.inull = '0' and ihit /= '1' then
        if ici.nobpmiss = '0' then
          v.imisspend := '1';
        else
          v.ibpmiss   := '1';
        end if;
      end if;
      if r.i1rep = '0' then
        v.irephitv     := ihitv;
        v.irepvalidv   := ivalidv;
        v.irepset      := iset;
        v.irepdata     := cramo.idatadout;
        v.ireptlbhit   := itlbchk.hit;
        v.ireptlbpaddr := itlbchk.paddr;
        v.ireptlbid    := itlbchk.id;
        v.irepfailkind := v.ifailkind;
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
      ocrami.itagen := "0000";
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
        v.i1pc     := ici.rpc(v.i1pc'range);
        v.i1su     := ici.su;
        v.i1m      := '0';
        if is_riscv then
          -- Machine, supervisor or user mode?
          if csr.prv = PRIV_LVL_M then
            v.i1m  := '1';
          end if;
          v.i1su   := '0';
          if csr.prv = PRIV_LVL_S then
            v.i1su := '1';
          end if;
        end if;
        v.i1cont   := icont;
        v.i1ctx    := mmu_ctx(r, csr);
      end if;
      v.i1rep      := ici.iustall;
    end if;
    if r.ramreload = '1' then
      v.i1rep      := '0';
    end if;


    -- Select input data for Icache

    --------------------------------------------------------------------------
    -- DCache logic
    --------------------------------------------------------------------------

    -- DCache TLB lookup
    -- Note that this is for the previous (registered) access.

    dtlb_write   := dci.write;
    dtlb_lock    := dci.lock;
    if r.dtlbrecheck = '1' then
      dtlb_write := r.d2write;
      dtlb_lock  := r.d2lock;
    end if;

    if is_riscv and (r.d1m = '1' or mmu_enabled(r, csr) = '0') then
      -- From tlb_lookup and dummy TLB entry.
      dtlbchk        := tlbcheck_none;
      -- Some non-defaults to "fake" an MMU access
      dtlbchk.hit    := '1';
      dtlbchk.paddr(r.d1vaddr'range) := r.d1vaddr;
      dtlbchk.busw   := dec_wbmask_fixed(r.d1vaddr(ahbo.haddr'high downto 2), wbmask);
      dtlbchk.cached := ahb_slv_dec_cache(r.d1vaddr(ahbo.haddr'range), ahbso, cached);
      dtlbchk.modded := '1';
      pmp_direct     := '1';
      daddr_ok       := physical_ok(r.d1vaddr);
      if addr_check_mask(1) = '0' then
        daddr_ok     := true;
      end if;
    else
      if is_riscv then
        daddr_ok     := virtual_ok(r.d1vaddr);
        if addr_check_mask(0) = '0' then
          daddr_ok   := true;
        end if;
      end if;
      -- Pass along actual rd1vaddr too, for LEON5 code equivalence.
      tlb_lookup('0', r.dtlb, r.d1vaddr_repl , r.d1vaddr, dci.maddress, mmu_ctx(r, csr), r.d1su, dtlb_write, dtlb_lock,
                 mmu_enabled(r, csr) and not r.d1m, r.d1chk, r.d1specialasi, dci.nullify, '0', dci.dsuen,
                 v.dtlb, dtlbchk, r.d1sum, r.d1mxr, false);
    end if;

    -- Note that this is for the previous (registered) access.
    -- Note that this is done in parallel with cache fetch (registered access).
    dtags_check(cramo, dtlbchk.paddr, mmu_enabled(r, csr) and not r.d1m, r.d1ten,
                dtlbchk.hit, r.d1vaddr(d_index'range),
                dset, dvalidv, dhitv, dhit, odco.badtag);
    if r.d1ten = '1' then
      if dhit = '0' then
      else
      end if;
    end if;


    -- Note: dhit is AND:ed with valid, but dhitv is _not_ AND:ed with validv
    -- If we miss due to valid bit being zero after a snoop hit we want
    -- r.d2hitv to be set to the way where we had the cache line, in order to
    -- avoid putting it in another way and getting two ways with idential tag.
    --   dhitv := dhitv and dvalidv;
    odco.set := dset;

    dasi          := r.d1asi;
    dspecialasi   := r.d1specialasi;
    dforcemiss    := r.d1forcemiss;
    dsu           := r.d1su;
    if r.holdn = '0' then
      dasi        := r.d2asi;
      dspecialasi := r.d2specialasi;
      dforcemiss  := r.d2forcemiss;
      dsu         := r.d2su;
    end if;

    dlock   := dci.lock;
    if r.holdn = '0' then
      dlock := r.d2lock;
    end if;


    -- PMP
    if is_riscv then
      pmp_acc   := PMP_ACCESS_R;
      if dtlb_write = '1' then
        pmp_acc := PMP_ACCESS_W;
      end if;
      pmp_addr  := (others => '0');
      if r.d1m = '0' then
        pmp_addr(dtlbchk.paddr'range) := dtlbchk.paddr;
      else
        pmp_addr(r.d1vaddr'range) := r.d1vaddr;
      end if;
      pmp_size  := dci.size;
      pmp_prv   := csr.prv;
      pmp_mprv  := csr.mprv;
      pmp_mpp   := csr.mpp;
      pmp_virt  := r.d1vaddr(pmp_virt'range);
      pmp_type  := "01";
      -- Only check if access now and it hit in the TLB (otherwise address is wrong).
      pmp_valid := r.d1chk and dtlbchk.hit and not dci.nullify and not dspecialasi;
        -- Also check if slow write with finished TLB lookup.
      if r.dtlbrecheck = '1' and r.d1ten = '1' then
        -- Also check if delayed access with finished TLB lookup.
        pmp_valid := pmp_valid or dtlbchk.hit;
        pmp_addr := (others => '0');
        pmp_addr(dtlbchk.paddr'range) := dtlbchk.paddr;
        pmp_size := r.d2size;
        if pmp_valid = '1' then
        end if;
      end if;

      -- The rest here should, hopefully, be possible to replace with common later.
      if pmpen then
        pmp_unit(pmp_prv, csr.precalc, csr.pmpcfg0, csr.pmpcfg2,
                 pmp_mprv, pmp_mpp,
                 pmp_virt, pmp_addr,
                 pmp_size, pmp_acc,
                 pmp_valid,
                 pmp_xc, pmp_cause, pmp_tval,
                 pmp_entries, pmp_no_tor, pmp_g, pmp_msb);
      end if;
      if addr_check_mask(2) = '0' then
        pmp_xc := '0';
      end if;

      if pmp_valid = '1' and pmp_xc = '1' then
      elsif pmp_valid = '1' then
      end if;
    end if;

    -- Hit/miss checking logic (v.dmisspend,v.dflushpend,fastwr propagates to main FSM)
    -- Stage 2 DTLB update in case of hit
--pragma translate_off
    if is_x(r.d2vaddr) then
      dlruent := (others => 'X');
    else
--pragma translate_on
      dlruent := r.dlru(u2i(r.d2vaddr(d_index'range)));
--pragma translate_off
    end if;
--pragma translate_on
    if r.holdn = '1' then
      vway     := "00";
      vhit     := '0';
      for x in r.d2hitv'range loop
        if r.d2hitv(x) = '1' then
          vhit := '1';
          vway := vway or to_unsigned(x, 2);
        end if;
      end loop;
      if vhit = '1' then
        v.dlru(u2i(r.d2vaddr(d_index'range))) := calc_lruent(dlruent, vway, DSETS);
      end if;
    end if;

    -- Stage 1 tag check
    fastwr          := '0';
    dwriting        := '0';
    if r.holdn = '1' then
      v.d2hitv      := (others => '0');
      v.d2tlbhit    := '0';
      v.d2tlbamatch := '0';
    end if;

    pmp_dfail := false;

    -- Data access now?
    if r.d1chk = '1' and r.holdn = '1' then
      v.d2vaddr      := to_bx_address(r.d1vaddr, dci.size);
      v.d2paddr      := to_bx_address(dtlbchk.paddr, dci.size);
      v.d2data       := dci.edata;
      v.d2write      := dci.write;
      v.d2paddrv     := dtlbchk.hit;
      v.d2tlbhit     := dtlbchk.hit;
      v.d2tlbamatch  := dtlbchk.amatch;
      v.d2tlbid      := dtlbchk.id;
      v.d2tlbmod     := dtlbchk.modded;
      v.d2hitv       := dhitv;
      v.d2validv     := dvalidv;
      v.d2size       := dci.size;
      v.d2busw       := dtlbchk.busw;
      v.d2asi        := r.d1asi;
      v.d2lock       := dci.lock;
      v.d2su         := r.d1su;
      v.d2specialasi := r.d1specialasi;
      v.d2forcemiss  := r.d1forcemiss;
      v.d2m          := r.d1m;
      v.d2sum        := r.d1sum;
      v.d2mxr        := r.d1mxr;
      v.d2stbuf(u2i(r.d2stbw)).addr      := v.d2paddr;
      v.d2stbuf(u2i(r.d2stbw)).size      := v.d2size;
      v.d2stbuf(u2i(r.d2stbw)).data      := v.d2data;
      v.d2stbuf(u2i(r.d2stbw)).snoopmask := dhitv;
      v.d2specread   := dci.specread;
      v.d2nocache    := not dtlbchk.cached;

      if is_riscv and pmp_valid = '1' and not daddr_ok then
        v.dfailkind := "1" & (r.d1m or not mmu_enabled(r, csr));
        v.dmisspend := '1';
      elsif is_riscv and pmp_valid = '1' and pmp_xc = '1' then
        v.dfailkind := "11";
        v.dmisspend := '1';
      else
        -- Do not do any of this if we fail on PMP!

        -- Set dcmiss pending bit for load cache miss
        if (dci.nullify = '0' or dci.dsuen = '1') and
           not (dhit = '1' and dforcemiss = '0' and dspecialasi = '0' and dci.lock = '0') and
           dci.read = '1' then
          v.dmisspend := '1';
        end if;

        -- Cache update for writes
        if dci.nullify = '0' and r.d1ten = '1' and dci.write = '1' and r.d1specialasi = '0' and r.amo.d1type(5) = '0' then
          dwriting                     := '1';
          ocrami.ddataen(d_ways'range) := dhitv;
          ocrami.ddatawrite            := getdmask64(r.d1vaddr, dci.size, ENDIAN_B);
        end if;

        -- Store buffer update for writes
        if (dci.nullify = '0' or dci.dsuen = '1') and dci.write = '1' then
          dbg(1) <= '1';
          if v.d2paddrv = '1' and v.d2busw = '1' and v.d2tlbmod = '1' and r.fastwr_rdy = '1' and dspecialasi = '0' and dci.lock = '0' then
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

        if dci.dsuen = '1' and r.holdn = '1' then
          v.d2vaddr := to_bx_address(dci.maddress, dci.size)(v.d2vaddr'range);
        end if;

      end if;
    end if;

    -- We need to check data PMP here if the TLB was just rechecked.
    if is_riscv and r.holdn = '0' and r.dtlbrecheck = '1' and r.d1ten = '1' and pmp_valid = '1' then
      if not daddr_ok then
        v.dfailkind := "1" & (r.d1m or not mmu_enabled(r, csr));
        v.dmisspend := '1';
      elsif pmp_xc = '1' then
        v.dfailkind := "11";
        v.dmisspend := '1';
      end if;
    end if;

    -- Copied from above, to ensure no latches.
    pmp_prv    := (others => '0');
    pmp_mprv   := '0';
    pmp_mpp    := (others => '0');
    pmp_virt   := (others => '0');
    pmp_addr   := (others => '0');
    pmp_iaddr  := (others => '0');
    pmp_size   := (others => '0');
    pmp_acc    := (others => '0');
    pmp_valid  := '0';
    pmp_direct := '0';
    pmp_type   := (others => '0');
    pmp_xc     := '0';
    pmp_cause  := (others => '0');
    pmp_tval   := (others => '0');
    pmp_mmu    := false;

    -- Stage 0 address to tag ram
    dtenall := ((r.holdn and dci.eenaddr) or (r.ramreload and r.d1chk)) and dcache_active(r);
    if dtenall = '1' then
      ocrami.dtagcen   := (others => '1');
      if dwriting = '0' then
        ocrami.ddataen := (others => '1');
      end if;
    end if;
    -- Force re-read in case of snoop hit to ensure updated valid bits propagate.
    if dtagconf = 0 then
      ocrami.dtagcen(d_ways'range) := ocrami.dtagcen(d_ways'range) or rs.s3hit;
    end if;
    if r.holdn = '1' then
      v.d1ten          := dci.eenaddr and dcache_active(r);
      v.d1chk          := dci.eenaddr;
      v.d1vaddr        := dci.eaddress(v.d1vaddr'range);
      v.d1asi          := dci.easi;
      v.d1su           := v.d1asi(0);
      v.d1forcemiss    := '0';
      v.d1specialasi   := '0';
      if v.d1asi(7 downto 1) = "0000000" then
        v.d1forcemiss  := '1';
        v.d1su         := '1';
      elsif v.d1asi(4 downto 0) /= ASI_UDATA and v.d1asi(4 downto 0) /= ASI_SDATA then
        v.d1specialasi := '1';
      end if;
      v.d1m     := '0';
      v.d1sum   := '0';
      v.d1mxr   := '0';
      if is_riscv then
        v.d1sum := csr.sum and dci.msu;
        v.d1mxr := csr.mxr;
        -- Should R/W be done in machine mode or not?
        -- Also figure out supervisor vs user mode.
        if csr.prv = PRIV_LVL_M then
          v.d1m := '1';
        end if;
        v.d1su := '0';
        if csr.prv = PRIV_LVL_S then
          v.d1su := '1';
        end if;
        if csr.mprv = '1' then
          if csr.mpp /= PRIV_LVL_M then
            v.d1m    := '0';
            if csr.mpp = PRIV_LVL_S then
              v.d1su := '1';
            elsif csr.mpp = PRIV_LVL_U then
              v.d1su := '0';
            end if;
          end if;
        end if;
      end if;
    end if;

    -- Flushing from IU
    if r.holdn = '1' and dci.flush = '1' then
      v.iflushpend := '1';
      v.dflushpend := '1';
    end if;

    --------------------------------------------------------------------------
    -- Atomic operations
    --------------------------------------------------------------------------
    if ext_a /= 0 then
      if r.holdn = '1' then
        if dci.eenaddr = '1' then
          v.amo.d1type := dci.amo;
        else
          v.amo.d1type := (others => '0');
        end if;
        v.amo.d2type   := r.amo.d1type;

        -- AMO_LR
        if r.amo.d2type(1 downto 0) = "10" and r.d2paddrv = '1' then
          v.amo.addr     := r.d2paddr(v.amo.addr'range);
          v.amo.reserved := '1';
        end if;
      end if;
      -- track regular store operation from this hart to not invalidate the reservation
      v.amo.store := r.amo.store(3 downto 1) & (r.ahb_htrans(1) and r.ahb_hwrite and
                                                r.granted and not r.amo.sc);
      v.amo.s4hit   := rs.s3hit;
      v.amo.s4tag   := rs.s3tag;
      v.amo.s4offs  := rs.s3offs;

      -- Reserved address write match
      if not all_0(rs.s1en) and r.amo.store(1) = '0' then
        if r.amo.addr(r.amo.addr'high downto d_tag'low) = rs.s1tag(r.amo.addr'high downto d_tag'low) and
           r.amo.addr(d_index'range) = rs.s1offs then
          v.amo.reserved := '0';
        end if;
        -- Need to clear based of d2paddr when cache busy (holdn = 0) between 
        -- lr and reserved being set
        if r.amo.d2type(1 downto 0) = "10" and r.d2paddrv = '1' then
          if r.d2paddr(rs.s1tag'high downto d_tag'low) = rs.s1tag(rs.s1tag'high downto d_tag'low) and
             r.d2paddr(d_index'range) = rs.s1offs then
            v.amo.reserved := '0';
            v.amo.d2type   := (others => '0');
          end if;
        end if;
      end if;
      if not all_0(rs.s2en) and r.amo.store(2) = '0' then
        -- Need to clear based of d2paddr and s2tag when snooping and lr happens simultaneously
        if r.amo.d2type(1 downto 0) = "10" and r.d2paddrv = '1' then
          if r.d2paddr(rs.s2tag'high downto d_tag'low) = rs.s2tag(rs.s2tag'high downto d_tag'low) and
             r.d2paddr(d_index'range) = rs.s2offs then
            v.amo.reserved := '0';
            v.amo.d2type   := (others => '0');
          end if;
        end if;
      end if;
      if not all_0(rs.s3hit) and r.amo.store(3) = '0' then
        -- Need to clear based of d2paddr and s3tag when snooping and lr happens simultaneously
        if r.amo.d2type(1 downto 0) = "10" and r.d2paddrv = '1' then
          if r.d2paddr(rs.s3tag'high downto d_tag'low) = rs.s3tag(rs.s3tag'high downto d_tag'low) and
             r.d2paddr(d_index'range) = rs.s3offs then
            v.amo.reserved := '0';
            v.amo.d2type := (others => '0');
          end if;
        end if;
      end if;
      if not all_0(r.amo.s4hit) and r.amo.store(4) = '0' then
        -- Need to clear based of d2paddr and s4tag when snooping and lr happens simultaneously
        if r.amo.d2type(1 downto 0) = "10" and r.d2paddrv = '1' then
          if r.d2paddr(r.amo.s4tag'high downto d_tag'low) = r.amo.s4tag(rs.s3tag'high downto d_tag'low) and
             r.d2paddr(d_index'range) = r.amo.s4offs then
            v.amo.reserved := '0';
            v.amo.d2type := (others => '0');
          end if;
        end if;
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
      ocrami.dtagudin(i)(TAG_HIGH - DTAG_LOW + 1 downto TAG_HIGH - DTAG_LOW) := rs.s3tagmsb(2 * i + 1 downto 2 * i);
      if rs.s3read(i) = '1' then
        ocrami.dtagudin(i)(0) := '1';
      else
        ocrami.dtagudin(i)(0) := '0';
      end if;
    end loop;

    if notx(rs.s3offs) then
      vs.validarr(u2i(rs.s3offs)) := (vs.validarr(u2i(rs.s3offs)) and (not rs.s3hit)) or rs.s3read;
    else
      for x in vs.validarr'range loop
        setx(vs.validarr(x));
      end loop;
    end if;

    -- Stage 2 snoop tag compare
    vs.s3hit := (others => '0');
    for i in d_ways'range loop
      if rs.s2en(i) = '1' then
        if cramo.dtagsdout(i)(TAG_HIGH - DTAG_LOW + 1 downto 1) = rs.s2tag then
          vs.s3hit(i) := '1';
        end if;
      end if;
    end loop;
    vs.s3read   := (others => '0');
    vs.s3hit    := vs.s3hit or rs.s2flush;
    vs.s3tag    := rs.s2tag;
    vs.s3read   := rs.s2read;
    vs.s3offs   := rs.s2offs;
    vs.s3tagmsb := rs.s2tagmsb;
    vs.s3flush  := rs.s2flush;

    -- Stage 1
    --  Send address to snoop to snoop tag RAM
    --  or send address and data to update snoop tag
    ocrami.dtagsindex(d_sets'range) := rs.s1offs;
    ocrami.dtagsen(d_ways'range)    := rs.s1en;
    if rs.s1read = '1' then
      ocrami.dtagswrite             := '1';
      ocrami.dtagsen(d_ways'range)  := r.d2hitv;
    end if;
    for w in d_ways'range loop
      ocrami.dtagsdin(w)(TAG_HIGH - DTAG_LOW + 1 downto 1) := rs.s1tag;
      ocrami.dtagsdin(w)(TAG_HIGH - DTAG_LOW + 1 downto TAG_HIGH - DTAG_LOW) := rs.s1tagmsb(2 * w + 1 downto 2 * w);
    end loop;
    vs.s2en     := rs.s1en and not rs.s1flush;
    vs.s2tag    := rs.s1tag;
    vs.s2offs   := rs.s1offs;
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

    -- Stage 0 get address from AHB bus
    vs.s1en     := (others => '0');
    vs.s1read   := '0';
    vs.s1flush  := (others => '0');
    if ahbsi.hready = '1' and ahbsi.htrans(1) = '1' and ahbsi.hwrite = '1' and r.cctrl.dsnoop = '1' then
      vs.s1tag  := (others => '0');
      vs.s1tag(ahbsi.haddr'high downto d_tag'low) := ahbsi.haddr(ahbsi.haddr'high downto d_tag'low);
      vs.s1offs := ahbsi.haddr(d_index'range);
      if rs.sgranted = '0' then
        vs.s1en := (others => '1');
      else
        vs.s1en := not r.ahb_snoopmask;
      end if;
    elsif ahbsi.hready = '1' and ahbsi.htrans = HTRANS_NONSEQ and ahbsi.hwrite = '0' and rs.sgranted = '1' then
      vs.s1tag  := (others => '0');
      vs.s1tag(ahbsi.haddr'high downto d_tag'low) := ahbsi.haddr(ahbsi.haddr'high downto d_tag'low);
      vs.s1offs := ahbsi.haddr(d_index'range);
      -- Note in first cycle of dcfetch we do not know which set will be used
      if r.s = as_dcfetch then
        vs.s1read := '1';
      end if;
    end if;
    for x in d_ways'range loop
      vs.s1tagmsb(2 * x + 1 downto 2 * x) := vs.s1tag(TAG_HIGH downto TAG_HIGH - 1);
    end loop;

    --------------------------------------------------------------------------
    -- MMU TLB update logic
    --------------------------------------------------------------------------

    -- TLB update
    if r.tlbupdate = '1' then
      if r.mmusel(0) = '0' and r.i2tlbhit = '1' then
        v.itlb(u2i(r.i2tlbid)) := r.newent;
      end if;
      if r.mmusel(0) = '1' and r.d2tlbhit = '1' then
        v.dtlb(u2i(r.d2tlbid)) := r.newent;
      end if;
    end if;
    v.tlbupdate := '0';

    -- On RISC-V, it is not as simple as the MMU being enabled or not.
    -- Even when it is otherwise in use, machine mode will (normally)
    -- still be using physical addresses.

    -- Set default 1:1 mapping if MMU disabled
    if mmu_enabled(r, csr) = '0' and not is_riscv then
      v.dtlb(0) := tlbent_defmap;
      v.itlb(0) := tlbent_defmap;
    end if;
    -- Clear valid bits on flush or MMU disable
    if r.tlbflush = '1' or (mmu_enabled(r, csr) = '0' and not is_riscv) then
      for x in v.dtlb'range loop
        v.dtlb(x).valid := '0';
      end loop;
      for x in v.itlb'range loop
        v.itlb(x).valid := '0';
      end loop;
    end if;
    v.tlbflush := '0';

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
    -- Reset pseudo-MRU once all bits set
    --   single-cycle window where all are set need to be handled
    if all_1(r.dtlbpmru) then
      v.dtlbpmru := (others => '0');
    end if;
    if all_1(r.itlbpmru) then
      v.itlbpmru := (others => '0');
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
    v.mmuerr.fav := '0';
    v.mmuerr.ow  := '0';
    v.mmuerr.ebe := (others => '0');


    ---------------------------------------------------------------------------
    -- Region flush
    ---------------------------------------------------------------------------

    -- Stage 3: Write back in case of flush
    --  handled in FSM

    -- Stage 2: Compare with region flush mask
    frdmatch        := (others => '0');
    for x in d_ways'range loop
      if (r.dtagpipe(x)(d_tag'range) and r.regflmask(d_tag'range))
         = r.regfladdr(d_tag'range) then
        frdmatch(x) := '1';
      end if;
    end loop;
    frimatch        := (others => '0');
    for x in i_ways'range loop
      if (r.itagpipe(x)(i_tag'range) and r.regflmask(i_tag'range))
           = r.regfladdr(i_tag'range) then
        frimatch(x) := '1';
      end if;
    end loop;
    -- Compute unique msb:s for the tags we are replacing to avoid duplicate tags
    for x in d_ways'range loop
      frmsbd(2 * x + 1 downto 2 * x) := r.dtagpipe(x)(TAG_HIGH downto TAG_HIGH - 1);
    end loop;
    v.untagd := uniquemsb(frmsbd, frdmatch);
    for x in i_ways'range loop
      frmsbi(2 * x + 1 downto 2 * x) := r.itagpipe(x)(TAG_HIGH downto TAG_HIGH - 1);
    end loop;
    v.untagi := uniquemsb(frmsbi, frimatch);

    -- Stage 1: Capture tags
    v.dtagpipe := cramo.dtagcdout;
    v.itagpipe := cramo.itagdout;

    -- Stage 0: Read from tag RAMs, done in main FSM


    --------------------------------------------------------------------------
    -- AHB access state machine
    --------------------------------------------------------------------------
    if ahbi.hready = '1' then
      -- this captures granted with the gated CPU clock. powerdown state ensures
      -- this is synced up when starting up the clock again before any AHB
      -- accesses are done.
      v.granted := ahbi.hgrant(hindex);
    end if;
    -- Flag set by FSM to indicate next cycles access is not the last so hbusreq
    -- should be kept high
    keepreq := '0';

    -- Read data buffer pipeline, advance with AHB hready
    v.werr := '0';
    if ahbi.hready = '1' then
      dbg(3) <= '1';
      v.ahb3_inacc := r.ahb2_inacc;
      -- Reading?
      if r.ahb2_inacc = '1' and r.ahb2_hwrite = '0' then
        dbg(4) <= '1';
        if ahbi.hresp = HRESP_ERROR then
          v.ahb3_error := '1';
        end if;
        for x in LINESZMAX - 1 downto 0 loop
          if r.ahb2_addrmask(x) = '1' then
            set(v.ahb3_rdbuf, x * 32, get(ahbi.hrdata, (x * 32) mod busw, 32));
          end if;
        end loop;
        -- Allow both OK and ERROR, to not hang the cache in as_dcfetch.
        if ahbi.hresp(1) = '0' then
          dbg(5) <= '1';
          v.ahb3_rdbvalid := v.ahb3_rdbvalid or r.ahb2_addrmask;
        end if;
      end if;
      if r.ahb2_inacc = '1' and r.ahb2_hwrite = '1' then
        if ahbi.hresp = HRESP_ERROR then
          v.werr := '1';
        end if;
      end if;
      v.ahb2_inacc    := r.granted and r.ahb_htrans(1);
      v.ahb2_hwrite   := r.ahb_hwrite;
      v.ahb2_addrmask := getvalidmask(r.ahb_haddr(4 downto 2), r.ahb_hsize, ENDIAN_B);
    end if;

    -- Read data from 32/64 bit single reads
    rdb64  := (others => '0');
    rdb32v := '0';
    if pte_hsize = HSIZE_WORD then
      -- rdb64 := (others => '0');
      for x in r.ahb3_rdbvalid'range loop
        if r.ahb3_rdbvalid(x) = '1' then
          rdb32v := '1';
          rdb32 := rdb32 or get(r.ahb3_rdbuf, x * 32, 32);
        end if;
      end loop;
    else
      for x in r.ahb3_rdbvalid'length / 2 - 1 downto 0 loop
        if get(r.ahb3_rdbvalid, x * 2, 2) = "11" then
          rdb32v := '1';
          rdb64v := '1';
          rdb64  := rdb64 or get(r.ahb3_rdbuf, x * 64, 64);
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

    -- Do this above FSM as it may set ramreload
    if r.imisspend = '0' and r.dmisspend  = '0' and r.slowwrpend = '0' and
      r.iflushpend = '0' and r.dflushpend = '0' and r.ramreload  = '1' then
      v.ramreload := '0';
    end if;

    v.newent.valid      := '1';
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
    v.regflpipe         := r.regflpipe(0) & '0';
    v.flushwrd          := (others => '0');
    v.flushwri          := (others => '0');

    case r.s is
      when as_normal =>
        -- PMP setup for TLB lookup OK and cached data read is already done above.
        v.ahb_htrans    := HTRANS_IDLE;
        v.ahb_hwrite    := '0';
        v.ahb_hburst    := HBURST_INCR;
        v.ahb_snoopmask := (others => '0');
        v.ahb3_error    := '0';
        v.ahb3_rdbvalid := (others => '0');
        v.mmusel        := "000";
        v.flushctr      := (others => '0');
        v.flushpart     := v.iflushpend & v.dflushpend;
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
        if r.ahb_hlock = '1' and dlock = '0' then
          v.ahb_hlock := '0';
        -- Normal write?
        elsif fastwr = '1' then
          v.ahb_htrans    := HTRANS_NONSEQ;
          v.ahb_hburst    := HBURST_SINGLE;
          v.ahb_haddr     := v.d2paddr(v.ahb_haddr'range);
          v.ahb_hsize     := "0" & v.d2size;
          v.ahb_hwrite    := '1';
          v.ahb_snoopmask := v.d2hitv;
          v.d2stbw := r.d2stbw + 1;
          v.s := as_store;
        -- I$/D$ flush?
        elsif ( ((not IMISSPIPE) and v.iflushpend = '1') or (IMISSPIPE and r.iflushpend = '1') or
                ((not DMISSPIPE) and v.dflushpend = '1') or (DMISSPIPE and r.dflushpend = '1') ) then
          if r.iregflush = '1' or r.dregflush = '1' then
            v.s         := as_regflush;
            v.flushpart := r.iregflush & r.dregflush;
          else
            v.s         := as_flush;
          end if;
          v.perf(4) := '1';
        -- Instruction fetch on I$ miss?
        elsif (((not IMISSPIPE) and v.imisspend = '1') or (IMISSPIPE and r.imisspend = '1')) then
          v.ahb_haddr   := v.i2paddr(v.ahb_haddr'range);
          v.ahb_haddr(i_line'range) := (others => '0');
          v.ahb_hsize   := u2slv(log2(busw / 8), 3);
          v.mmusel      := "000";
          if v.i2busw = '0' then   -- 32 bit bus?
            v.ahb_hsize := HSIZE_WORD;
          end if;
          if is_riscv and v.ifailkind(1) = '1' then
            v.imisspend   := '0';
            i_mexc        := '1';
            i_exctype     := v.ifailkind(0);
            v.imisspend   := '0';
            v.ifailkind   := "00";
            v.newerrclass := "11";
            v.mmuerr.ft   := "100";       -- Translation error
            v.mmuerr.fav  := '1';
            v.ramreload   := '1';
          -- TLB hit and permissions OK?
          elsif v.i2paddrv = '1' then
            v.ahb_htrans  := HTRANS_NONSEQ;
            v.s           := as_icfetch;
            keepreq       := '1';
            v.perf(0)     := '1';
          -- Both TLB misses and permission fails go here!
          else
            start_walk    := true;   -- See more after case.
            if not is_riscv then
              v.ahb_haddr := r.mmctrl1.ctxp(25 downto 4) & v.i2ctx & "00";
            end if;
            v.perf(1)     := '1';
          end if;
        -- Data fetch on D$ miss, and not speculative?
        elsif (((not DMISSPIPE) and v.dmisspend = '1') or (DMISSPIPE and r.dmisspend = '1')) and v.d2specread = '0' then
          v.ahb_haddr     := v.d2paddr(v.ahb_haddr'range);
          v.ahb_hsize     := "000";
          v.mmusel        := "001";
          -- Lock change?
          if v.d2lock /= r.ahb_hlock then
            v.s           := as_getlock;
            v.ahb_hlock   := not r.ahb_hlock;
            if r.ahb_hlock = '0' then
              v.granted   := '0';
            end if;
          elsif is_riscv and v.dfailkind(1) = '1' then
            v.dmisspend   := '0';
            odco.mds      := '0';
            d_mexc        := '1';
            d_exctype     := v.dfailkind(0);
            v.slowwrpend  := '0';
            v.dmisspend   := '0';
            v.dfailkind   := "00";
            v.newerrclass := "11";
            v.mmuerr.ft   := "100";       -- Translation error
            v.mmuerr.fav  := '1';
            v.ramreload     := '1';
          -- TLB hit and permissions OK?
          elsif v.d2paddrv = '1' and dspecialasi = '0' then
            if v.d2busw = '1' then     -- Burst if wide bus.
              if v.d2nocache = '0' then
                v.ahb_hsize     := u2slv(log2(busw / 8), 3);
                v.ahb_haddr(log2(busw / 8) - 1 downto 0) := (others => '0');
              else -- Use access size and offset when area is uncached
                v.ahb_hsize     := "0" & v.d2size;
              end if;
            else
              v.ahb_hsize   := "010";
              v.ahb_haddr(1 downto 0) := "00";
            end if;
            if v.d2nocache = '0' then
              v.ahb_htrans  := HTRANS_NONSEQ;
              v.s           := as_dcfetch;
              keepreq       := '1';
              v.ahb_haddr(d_line'range) := (others => '0');
              v.perf(2)     := '1';
            else                       -- Single accesses on 32 bit bus.
              v.ahb_htrans  := HTRANS_NONSEQ;
              v.ahb_hbusreq := '1';
              v.ahb_hburst  := HBURST_SINGLE;
              v.s           := as_dcsingle;
            end if;
          -- Both TLB misses and permission fails go here!
          elsif dspecialasi = '0' then
            if not is_riscv then
              v.ahb_haddr := mmu_base(r, csr);
            end if;
            start_walk    := true;   -- See more after case.
            v.perf(3)     := '1';
          -- Special reads
          else
            v.s := as_rdasi;
          end if;
        -- Non-fast write?
        elsif v.slowwrpend = '1' then
          if v.amo.d2type(5) = '0' or ext_a = 0 then
            v.s := as_slowwr;
          else
            -- Lock change?
            if v.d2lock /= r.ahb_hlock then
              v.s           := as_getlock;
              v.ahb_hlock   := not r.ahb_hlock;
              if r.ahb_hlock = '0' then
                v.granted   := '0';
              end if;
            else
              -- Atomic instruction (SC or AMO)
              v.s := as_amo;
            end if;
          end if;
        elsif ici.parkreq = '1' then
          v.s := as_parked;
        end if;

      -- Check PMP
      when as_wmmuwalk =>
        v.s          := as_mmuwalk;
        v.ahb_htrans := HTRANS_NONSEQ;
        pmp_mmu      := true;
        pmp_type     := r.mmusel(1 downto 0);

      -- Flush pending, from as_normal or explicit as_wrasi.
      when as_flush =>
        if r.flushpart(1) = '1' then
          v.ilru         := (others => (others => '0'));
          v.i1cont       := '0';
        end if;
        if r.flushpart(0) = '1' then
          v.dlru         := (others => (others => '0'));
        end if;
        v.flushctr       := std_logic_vector(unsigned(r.flushctr) + 1);
        if r.flushpart(1) = '1' and all_0(v.flushctr) then
          v.flushpart(1) := '0';
          v.iflushpend   := '0';
        end if;
        if r.flushpart(0) = '1' and rs.s3flush(0) = '1' and all_1(rs.s3offs) then
          v.flushpart(0) := '0';
          v.dflushpend   := '0';
        end if;
        if v.flushpart = "00" then
          v.ramreload    := '1';
          v.s            := as_normal;
        end if;
        ocrami.iindex               := (others => '0');
        ocrami.iindex(i_sets'range) :=
          r.flushctr(r.flushctr'high downto r.flushctr'high - IOFFSET_BITS + 1);
        ocrami.idataoffs := (others => '0');
        for w in i_ways'range loop
          -- ocrami.itagdin(w) := (others => '0');
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW + 1 downto TAG_HIGH - ITAG_LOW - 6)  := x"FF";
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW - 7 downto TAG_HIGH - ITAG_LOW - 8)  := u2slv(w, 2);
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW - 9 downto TAG_HIGH - ITAG_LOW - 10) := u2slv(w, 2);
          ocrami.itagdin(w)(0) := '0';
        end loop;
        if r.flushpart(1) = '1' then
          ocrami.itagen    := "1111";
          ocrami.itagwrite := '1';
        end if;
        if r.flushpart(0) = '1' then
          vs.s1tag                               := (others => '0');
          vs.s1tag(TAG_HIGH downto TAG_HIGH - 7) := x"F3";
          for x in d_ways'range loop
            vs.s1tagmsb(2 * x + 1 downto 2 * x)  := u2slv(x, 2);
          end loop;
          vs.s1offs  := r.flushctr(DOFFSET_HIGH - DOFFSET_LOW downto 0);
          vs.s1read  := '1';
          vs.s1flush := (others => '1');
        end if;

      -- Instruction fetch on I$ miss.
      when as_icfetch =>
        v.i1ten         := '0';
        -- Only allocate if I$ actually enabled!
        if all_0(r.i2hitv) and icache_enabled(r) and r.irdbufen = '0' then
          v.i2hitv      := replace_vec(r.i2validv, ilruent);
        end if;
        v.irdbufen      := '1';
        -- Just beginning fetch?
        if r.irdbufen = '0' then
          v.irdbufvaddr := r.i2pc(r.irdbufvaddr'range);
          v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
          v.i2bufmatch  := '1';
        end if;

        burst_update(ilinesize, r.ahb_hsize(1 downto 0) /= "10", v.ahb_htrans, v.ahb_haddr);

        keepreq := '1';
        if all_1(v.ahb_haddr(log2(ilinesize * 4) - 1 downto log2(busw / 8))) and
          (all_1(v.ahb_haddr(log2(busw / 8) - 1 downto 2)) or (r.ahb_hsize(1 downto 0) /= "10")) then
          keepreq := '0';
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
        if ((not ENDIAN_B) and r.ahb3_rdbvalid(LINESZMAX - 1 - u2i(r.iramaddr & onev(3))) = '1') or
           ((ENDIAN_B)     and r.ahb3_rdbvalid(u2i(r.iramaddr & onev(3))) = '1') then
          v.iramaddr        := std_logic_vector(unsigned(r.iramaddr) + 1);
          -- Finished fetching I$ line?
          if all_1(r.iramaddr) then
            v.irdbufen      := '0';
            v.ramreload     := '1';
            -- Update irdbufvaddr/paddr since used in icfetch2 stage
            if r.imisspend = '1' then
              v.irdbufvaddr := r.i2pc(r.irdbufvaddr'range);
              v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
              v.iramaddr    := r.i2pc(r.iramaddr'range);
            else
              v.irdbufvaddr := r.i1pc(r.irdbufvaddr'range);
              v.irdbufpaddr := itlbchk.paddr(r.irdbufpaddr'range);
              v.iramaddr    := r.i1pc(r.iramaddr'range);
            end if;
            if v.imisspend = '1' and v.i2paddrv = '1' then
              v.s           := as_wptectag1;
            else
              v.s           := as_normal;
            end if;
          end if;
        end if;
        i_mexc    := r.ahb3_error;
        i_exctype := '1';
        if r.ahb3_error = '1' then
          v.iflushpend := '1';
        end if;

      when as_dcfetch =>
        -- Only allocate if D$ actually enabled!
        if all_0(r.d2hitv) and dcache_enabled(r) and r.d2nocache = '0' then
          v.d2hitv := replace_vec(r.d2validv, dlruent);
        end if;
        if not all_0(rs.s2read) then
          v.dvtagdone := '1';
        end if;

        burst_update(dlinesize, r.d2busw = '1', v.ahb_htrans, v.ahb_haddr);
        
        keepreq := '1';
        if all_1(v.ahb_haddr(log2(dlinesize * 4) - 1 downto log2(busw / 8))) and
          (all_1(v.ahb_haddr(log2(busw / 8) - 1 downto 2)) or (r.d2busw = '1')) then
          keepreq := '0';
        end if; 

        -- Write read data buffer into D$ data RAM
        -- Note virtual and physical tag write managed by snoop pipeline above
        -- Data managed here
        ocrami.ddataindex(d_sets'range)  := r.d2vaddr(d_index'range);
        ocrami.ddataoffs(d_offset'range) := r.dramaddr;
        if ((not ENDIAN_B) and r.ahb3_rdbvalid(LINESZMAX - 1 - u2i(std_logic_vector'(r.dramaddr & onev(DLINE_LOW_REAL - 1 downto 2)))) = '1') or
           ((ENDIAN_B)     and r.ahb3_rdbvalid(u2i(std_logic_vector'(r.dramaddr & onev(DLINE_LOW_REAL - 1 downto 2)))) = '1')
        then
          ocrami.ddataen                 := (others => '0');
          if dcache_active(r) = '1' then
            ocrami.ddataen(d_ways'range) := r.d2hitv;
            ocrami.ddatawrite            := (others => '1');
          end if;
          v.dramaddr := std_logic_vector(unsigned(r.dramaddr) + 1);
          if all_1(r.dramaddr) then
            if r.dvtagdone = '0' then
              v.s := as_dcfetch2;
            else
              v.dmisspend := '0';
              v.s         := as_normal;
            end if;
            if r.d1ten = '1' then
              v.ramreload := '1';
            end if;
          end if;
        end if;
        d_mexc    := r.ahb3_error;
        d_exctype := r.ahb3_error;  -- Count AHB error as access fault.
        if r.ahb3_error = '1' then
          v.dflushpend := '1';
        end if;
        odco.set := "00";
        for x in 0 to LINESZMAX / 2 - 1 loop
          if r.d2vaddr(BUF_HIGH downto 3) = u2slv(x, BUF_HIGH - 2) then
            if not ENDIAN_B then
              odco.data(0) := get(r.ahb3_rdbuf, (LINESZMAX - 2 * x - 2) * 32, 64);
            else
              odco.data(0) := get(r.ahb3_rdbuf, x * 64, 64);
            end if;
          end if;
        end loop;
        odco.mds := '0';

      when as_dcfetch2 =>
        if not all_0(rs.s2read) then
          v.dvtagdone := '1';
        end if;
        if r.dvtagdone = '1' or all_0(r.d2hitv) then
          v.s := as_normal;
          v.dmisspend := '0';
          if r.d1ten = '1' then
            v.ramreload := '1';
          end if;
        end if;

      when as_dcsingle =>
        if ahbi.hready = '1' then
          if r.granted = '1' and ahbi.hresp(1) = '0' and r.ahb_htrans(1) = '1' then
            v.ahb_htrans   := HTRANS_IDLE;
          elsif r.ahb2_inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb_htrans   := HTRANS_NONSEQ;
          elsif r.ahb2_inacc = '1' and r.d2busw = '0' and r.d2size = "11" and r.ahb_haddr(2) = '0' then
            v.ahb_haddr(2) := '1';
            v.ahb_htrans   := HTRANS_NONSEQ;
          end if;
        end if;

        if r.ahb3_inacc = '1' and r.ahb_htrans(1) = '0' then
          v.dmisspend   := '0';
          v.s           := as_normal;
          if r.d1ten = '1' then
            v.ramreload := '1';
          end if;
        end if;
        for x in 0 to LINESZMAX / 2 - 1 loop
          if r.d2vaddr(BUF_HIGH downto 3) = u2slv(x, BUF_HIGH - 2) then
            if not ENDIAN_B then
              odco.data(0) := get(r.ahb3_rdbuf, (LINESZMAX - 2 * x - 2) * 32, 64);
            else
              odco.data(0) := get(r.ahb3_rdbuf, x * 64, 64);
            end if;
          end if;
        end loop;
        odco.set  := "00";
        odco.mds  := '0';
        d_mexc    := r.ahb3_error;
        d_exctype := r.ahb3_error;  -- Count AHB error as access fault.

      when as_mmuwalk =>
        -- Complete current AHB access
        if ahbi.hready = '1' and r.granted = '1' then
          v.ahb_htrans := HTRANS_IDLE;
        end if;

        -- New entry and new error (if error occurs)
        if r.mmusel(0) = '0' then
          v.newent.ctx      := r.i2ctx;
          v.newent.vaddr    := r.i2pc(vpn'range);
          v.newent.modified := '0';
          v.newerrclass     := "01";
          v.mmuerr.at_ls    := '0';        -- Load/Execute
          v.mmuerr.at_id    := '1';        -- Instruction space
          v.mmuerr.at_su    := r.i2su;
        else
          v.newent.ctx      := mmu_ctx(r, csr);
          v.newent.vaddr    := r.d2vaddr(vpn'range);
          v.newent.modified := r.mmusel(1);
          v.newerrclass     := "10";
          v.mmuerr.at_ls    := r.mmusel(1);
          v.mmuerr.at_id    := '0';
          v.mmuerr.at_su    := r.d2su;
          -- Treat atomic access as store to avoid store phase of atomic
          -- causing mmu fault.
          if r.d2lock = '1' then
            v.newent.modified := '1';
            v.mmuerr.at_ls    := '1';
          end if;
        end if;

        if r.newent.mask(1) = '0' then
          v.mmuerr.l := "00";
        elsif r.newent.mask(2) = '0' then
          v.mmuerr.l := "01";
        elsif r.newent.mask'length > 2 and r.newent.mask(3) = '0' then
          v.mmuerr.l := "10";
        else
          v.mmuerr.l := "11";
        end if;

        v.newent.paddr  := pte_paddr(rdb64);
        if not is_riscv or csr.pte_nocache = '0' then
          v.newent.cached := pte_cached(ahbso, rdb64);
        else
          v.newent.cached := not rdb64(8);
        end if;
        v.newent.busw   := pte_busw(rdb64);
        if rdb32v = '1' then
          if is_riscv then
            v.newent.modified := v.newent.modified or rdb32(7);
          else
            v.newent.modified := v.newent.modified or rdb32(6);
          end if;
        end if;

        -- Prepare hwdata for writing back PTE with R/M bits set
        -- Check if write-back is needed
        v.ahb_hwdata := rdb64;                   -- Don't care if it is really 32 bits.
        pte_mark_modacc(v.ahb_hwdata, r.newent.modified, vneedwb, vneedwblock);
        -- If it was not 64 bit earlier, duplicate on bus.
        if pte_hsize = HSIZE_WORD then
          v.ahb_hwdata(63 downto 32) := lo_h(v.ahb_hwdata);
        end if;

        if is_riscv then
          v.newent.perm := rdb32(rv_pte_u downto rv_pte_r);
        end if;

        v.newent.acc := rdb32(4 downto 2);
        v.dregval    := rdb32;

        if rdb32v = '1' then
          v.ahb3_rdbvalid := (others => '0');
          -- Depending on level/type -
          --   update haddr to go down to next level
          --   write back "accessed" bit
          --   update TLB and register of access causing miss

          -- AHB error fetching entry?
          if r.ahb3_error = '1' then
            v.s           := as_mmuwalk3;
            v.newerrclass := "11";
            v.mmuerr.ft   := "100";       -- Translation error
            v.mmuerr.fav  := '1';

          -- Page table entry?
          elsif is_pte(rdb32) then
            v.mmuerr.ft := ft_acc_resolve(r.mmuerr.at_ls & r.mmuerr.at_id & r.mmuerr.at_su, rdb32);
            if r.mmusel(2) = '1' then
              v.s := as_rdasi2;
            -- Valid?
            elsif not is_valid_pte(rdb64, r.newent.mask) then
              v.s           := as_mmuwalk3;
              v.mmuerr.fav  := '1';

            -- Permission error?
            elsif (not is_riscv and v.mmuerr.ft(1) /= '0') or
               (is_riscv and not permitted(r.mmuerr.at_id, r.mmuerr.at_su, r.mmuerr.at_ls, '0',
                                           rdb32(rv_pte_u downto rv_pte_r), r.d2sum, r.d2mxr)) then
              v.s           := as_mmuwalk3;
              v.mmuerr.fav  := '1';
            -- Writeback needed?
            elsif vneedwb = '1' then
              if csr.mmu_adfault = '0' then
                v.ahb_htrans   := HTRANS_NONSEQ;
                v.ahb_hwrite   := '1';
                if vneedwblock = '1' and r.ahb_hlock = '0' then
                  v.s          := as_mmuwalk4;
                  v.ahb_hlock  := '1';
                  v.ahb_htrans := HTRANS_IDLE;
                  v.ahb_hwrite := '0';
                  v.granted    := '0';
                else
                  v.ahb_htrans := HTRANS_NONSEQ;
                  v.s          := as_wptectag1;
                  v.tlbupdate  := '1';
                end if;
              else
                v.s            := as_mmuwalk3;
                v.mmuerr.fav   := '1';
              end if;
            -- OK!
            else
              v.tlbupdate := '1';
              -- Re-read tags and check for a potential hit
              if r.mmusel(0) = '0' and r.imisspend = '1' then
                v.s := as_wptectag1;
              elsif r.mmusel(0) = '1' and (r.dmisspend = '1' or r.slowwrpend = '1') then
                v.s := as_wptectag1;
              else
                v.s := as_normal;
              end if;
            end if;

          -- Page table descriptor (and not too deep)?
          elsif is_ptd(rdb32) and r.newent.mask(r.newent.mask'high) = '0' then
            -- Shift in a '1' for each new TLB level.
            v.newent.mask := '1' & r.newent.mask(r.newent.mask'low to r.newent.mask'high - 1);
            v.ahb_haddr   := pt_addr(rdb64, r.newent.mask, r.newent.vaddr, r.mmuerr.l)(v.ahb_haddr'range);
            -- Return physical address for next level of page table.
            -- mask - pre-shift (ie before new 1 at bit 1 (first)) page table mask
            -- code - mask recoded as position for first 0 (from 1)
            v.ahb_htrans  := HTRANS_NONSEQ;
            if r.mmusel(2) = '1' then
              v.d2vaddr(9 downto 8) := std_logic_vector(unsigned(r.d2vaddr(9 downto 8)) + 1);
              if r.d2vaddr(9 downto 8) = "11" then
                v.s                 := as_rdasi2;
              end if;
            elsif is_riscv then
              pmp_type     := r.mmusel(1 downto 0);
              v.s          := as_wmmuwalk;
              v.ahb_htrans := HTRANS_IDLE;
            end if;

          -- Invalid/reserved or too many levels of PTDs
          else
            v.s := as_mmuwalk3;
            if is_pt_invalid(rdb32) then
              v.mmuerr.ft := "001";     -- Invalid address error
            else
              v.mmuerr.ft := "100";     -- Translation error
            end if;
            v.mmuerr.fav := '1';
          end if;
        end if;

        if r.mmusel(0) = '0' then
          v.i2paddr   := v.newent.paddr & r.i2pc(11 downto 0);
          virtual2physical(r.i2pc, r.newent.mask, v.i2paddr);
          v.i2paddrv  := '1';
          v.i2busw    := v.newent.busw;
          v.i2paddrc  := v.newent.cached;
        else
          v.d2paddr   := to_bx_address(v.newent.paddr & r.d2vaddr(11 downto 0), v.d2size);
          virtual2physical(r.d2vaddr, r.newent.mask, v.d2paddr);
          -- Reverse since it will be done again next cycle...
          v.d2paddrv  := '1';
          v.d2busw    := v.newent.busw;
          v.d2nocache := not v.newent.cached;
          v.d2tlbmod  := v.newent.modified;
        end if;

        -- Select which TLB entry to replace
        if r.mmusel(0) = '0' then
          if r.i2tlbhit = '0' and r.mmctrl1.tlbdis = '0' then
            v.i2tlbhit := '1';
            v.i2tlbid  := pmru_decode(r.itlbpmru);
          end if;
        else
          if r.d2tlbhit = '0' and r.mmctrl1.tlbdis = '0' and r.mmusel(2) = '0' then
            v.d2tlbhit := '1';
            v.d2tlbid  := pmru_decode(r.dtlbpmru);
          end if;
        end if;
        -- Set up for as_wptectag1 state in case of recheck
        v.irdbufvaddr := r.i2pc(r.irdbufvaddr'range);
        v.irdbufpaddr := r.i2paddr(r.irdbufpaddr'range);
        v.iramaddr    := r.i2pc(r.iramaddr'range);

        -- Did walk finish successfully?
        if v.s = as_normal then
        end if;

      -- Some kind of error occurred during MMU walk
      when as_mmuwalk3 =>
        if r.mmusel(2) = '0' then
          if r.mmusel(0) = '0' then
            oico.mds    := '0';
            if r.mmctrl1.nf = '0' then
              i_mexc    := '1';
            end if;
            v.imisspend := '0';
          else
            odco.mds       := '0';
            if r.mmctrl1.nf = '0' then
              d_mexc       := '1';
            end if;
            if r.mmusel(1) = '1' then
              v.slowwrpend := '0';
            else
              v.dmisspend  := '0';
              -- For AMO and SC also stop write
              if r.amo.d2type(5) = '1' and (r.amo.d2type(1) = '0' or
                                            r.amo.d2type(1 downto 0) = "11") then
                v.slowwrpend := '0';
              end if;
            end if;
            if is_riscv then
              d_exctype  := '0';
            end if;
          end if;
          v.ramreload := '1';
          v.s         := as_normal;
          pmp_valid   := '0';   -- Reporting error, so do not check this time!
        else
          v.s         := as_rdasi2;
        end if;
        v.dregval     := (others => '0');

      when as_mmuwalk4 =>
        if r.ahb3_error = '1' then
          -- AHB error fetching entry
          v.s              := as_mmuwalk3;
          v.newerrclass    := "11";
          v.mmuerr.ft      := "100";       -- Translation error
          v.mmuerr.fav     := '1';
        elsif rdb32v = '1' then
          if is_riscv then
            v.ahb_hwdata(7 downto 6) := v.ahb_hwdata(7 downto 6) or rdb32(7 downto 6);
            v.newent.modified        := v.newent.modified or rdb32(7);
          else
            v.ahb_hwdata(6 downto 5) := v.ahb_hwdata(6 downto 5) or rdb32(6 downto 5);
            v.newent.modified        := v.newent.modified or rdb32(6);
          end if;
          v.s              := as_wptectag1;
          v.ahb_htrans     := HTRANS_NONSEQ;
          v.ahb_hwrite     := '1';
          v.tlbupdate      := '1';
        elsif r.ahb2_inacc = '1' then
          if ahbi.hresp(1) = '1' then
            v.ahb_htrans   := HTRANS_IDLE;
            if ahbi.hready = '1' then
              v.ahb_htrans := HTRANS_NONSEQ;
            end if;
          end if;
        elsif r.ahb_htrans(1) = '1' then
          if r.granted = '1' then
            v.ahb_htrans   := HTRANS_IDLE;
          end if;
        else
          if r.granted = '1' then
            v.ahb_htrans   := HTRANS_NONSEQ;
          end if;
        end if;

      when as_wptectag1 =>
        -- Write PTE and recheck tags stage 1
        v.s := as_wptectag2;
        -- Continue PTE writeback
        if ahbi.hready = '1' and r.granted = '1' then
          v.ahb_htrans := HTRANS_IDLE;
        end if;
        -- Drive Icache tag/data addresses
        ocrami.iindex(i_sets'range)      := r.irdbufvaddr(i_index'range);
        ocrami.idataoffs(i_offset'range) := r.iramaddr;
        v.i1cont := '0';
        -- To avoid complicating the tag comparison logic we swap i1pc and i2pc
        -- and then swap back in icfetch3.
        v.i2pc    := r.i1pc;
        v.i1pc    := r.i2pc;
        v.i2su    := r.i1su;
        v.i1su    := r.i2su;
        v.i1m     := r.i2m;
        v.i2m     := r.i1m;
        v.i2ctx   := r.i1ctx;
        v.i1ctx   := r.i2ctx;
        if icache_active(r) = '1' and r.imisspend = '1' then
          ocrami.itagen  := "1111";
          ocrami.idataen := "1111";
          v.i1ten := '1';
        end if;
        v.i1rep   := '0';
        -- Drive Dcache tag/data addresses
        ocrami.dtagcindex(d_sets'range)  := r.d2vaddr(d_index'range);
        ocrami.ddataindex(d_sets'range)  := r.d2vaddr(d_index'range);
        ocrami.ddataoffs(d_offset'range) := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        -- Temporarily swap d1 and d2 virt addresses for tag comparison in next state
        v.d1vaddr     := r.d2vaddr;
        v.d2vaddr     := r.d1vaddr;
        v.d1su        := r.d2su;
        v.d2su        := r.d1su;
        v.d1m         := r.d2m;
        v.d2m         := r.d1m;
        v.dtlbrecheck := '1';           -- To swap dci.write/dci.lock
        v.d1ten       := '0';
        -- Did we miss earlier and need to do a new tag check?
        if dcache_active(r) = '1' and r.mmusel(0) = '1' and
           (r.dmisspend = '1' or r.slowwrpend = '1') then
          ocrami.dtagcen := (others => '1');
          ocrami.ddataen := (others => '1');
          v.d1ten        := '1';
        end if;

      when as_wptectag2 =>
        -- Write PTE and recheck tags stage 2 - tag check
        v.s   := as_wptectag3;
        -- Continue PTE writeback
        if r.ahb_htrans = HTRANS_IDLE and r.ahb2_inacc = '0' then
          v.s := as_normal;
        elsif ahbi.hready = '1' and r.ahb2_inacc = '1' and ahbi.hresp(1) = '0' then
          -- Done!
          v.s := as_normal;
          if ahbi.hresp(0) = '1' then
            -- PTE writeback error
            v.werr := '1';
          end if;
        elsif ahbi.hready = '0' and r.ahb2_inacc = '1' and ahbi.hresp(1) = '1' then
          v.ahb_htrans := HTRANS_IDLE;
        elsif ahbi.hready = '1' and r.ahb2_inacc = '1' and ahbi.hresp(1) = '1' then
          v.ahb_htrans := HTRANS_NONSEQ;
        elsif ahbi.hready = '1' and r.granted = '1' then
          v.ahb_htrans := HTRANS_IDLE;
        end if;
        -- Check Icache tags
        if r.imisspend = '1' then
          oico.mds := '0';
        end if;
        -- Swap back to get i1pc
        v.i2pc     := r.i1pc;
        v.i1pc     := r.i2pc;
        v.i2pc     := r.i1pc;
        v.i1pc     := r.i2pc;
        v.i2su     := r.i1su;
        v.i1su     := r.i2su;
        v.i1m      := r.i2m;
        v.i2m      := r.i1m;
        v.i2ctx    := r.i1ctx;
        v.i1ctx    := r.i2ctx;
        v.i1ten    := '0';
        v.i2validv := ivalidv;
        v.i2hitv   := ihitv;
        if ihit = '1' then
          v.imisspend := '0';
        end if;
        -- Check Dcache tags
        if r.dmisspend = '1' then
          odco.mds   := '0';
        end if;
        v.d1vaddr    := r.d2vaddr;
        v.d2vaddr    := r.d1vaddr;
        v.d1su       := r.d2su;
        v.d2su       := r.d1su;
        v.d1m        := r.d2m;
        v.d2m        := r.d1m;
        if r.d1ten = '1' then
          v.d2hitv   := dhitv;
          v.d2validv := dvalidv;
        end if;
        ocrami.ddataen := (others => '0');
        if dhit = '1' then
          if r.d2nocache = '0' and r.d2specialasi = '0' and r.d2forcemiss = '0' then
            v.dmisspend := '0';
          end if;
        end if;
        if r.mmusel(0) = '1' and r.slowwrpend = '1' and r.d2specialasi = '0' then
          ocrami.ddataen(d_ways'range) := dhitv;
        end if;
        ocrami.ddatawrite := getdmask64(r.d1vaddr, r.d2size, ENDIAN_B);
        ocrami.ddatadin   := (others => r.d2data);
        v.d1ten           := r.d1chk and dcache_active(r);
        v.ramreload       := '1';

      when as_wptectag3 =>
        -- Write PTE and recheck tags stage 3 - finish writeback
        if r.ahb_htrans = HTRANS_IDLE and r.ahb2_inacc = '0' then
          v.s := as_normal;
        elsif ahbi.hready = '1' and r.ahb2_inacc = '1' and ahbi.hresp(1) = '0' then
          -- Done!
          v.s := as_normal;
          if ahbi.hresp(0) = '1' then
            -- PTE writeback error
            v.werr := '1';
          end if;
        elsif ahbi.hready = '0' and r.ahb2_inacc = '1' and ahbi.hresp(1) = '1' then
          v.ahb_htrans := HTRANS_IDLE;
        elsif ahbi.hready = '1' and r.ahb2_inacc = '1' and ahbi.hresp(1) = '1' then
          v.ahb_htrans := HTRANS_NONSEQ;
        elsif ahbi.hready = '1' and r.granted = '1' then
          v.ahb_htrans := HTRANS_IDLE;
        end if;

      -- Stay in this state until store buffer is empty.
      when as_store =>
        if r.ahb2_inacc = '1' and ahbi.hresp(1) = '1' and ahbi.hready = '0' then
          v.ahb_htrans   := HTRANS_IDLE;
          v.d2stba       := r.d2stba - 1;
        else
          if ahbi.hready = '1' and r.granted = '1' then
            if r.ahb_htrans(1) = '1' then
              v.d2stba   := r.d2stba + 1;
            end if;
          end if;
          if ahbi.hready = '1' then
            v.d2stbd     := r.d2stba;
          end if;
          v.ahb_htrans   := HTRANS_IDLE;
          if v.d2stba /= r.d2stbw or r.stbuffull = '1' then
            v.ahb_htrans := HTRANS_NONSEQ;
          end if;
        end if;

        v.ahb_hwrite    := '1';
        v.ahb_haddr     := r.d2stbuf(u2i(v.d2stba)).addr(v.ahb_haddr'range);
        v.ahb_hsize     := '0' & r.d2stbuf(u2i(v.d2stba)).size;
        v.ahb_snoopmask := r.d2stbuf(u2i(v.d2stba)).snoopmask;
        v.ahb_hwdata    := r.d2stbuf(u2i(v.d2stbd)).data;
        v.ahb_hburst    := HBURST_SINGLE;

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
          end if;
        end if;

        if fastwr = '0' and r.stbuffull = '0' and r.d2stbd = r.d2stbw then
          v.s      := as_normal;
          v.d2stbw := "00";
          v.d2stba := "00";
          v.d2stbd := "00";
        end if;

      when as_slowwr =>
        -- Translate addr
        -- MMU permission check
        -- Check written flag
        -- Write burst on narrow bus
        -- Perform write
        v.mmusel          := "011";
        -- Special access?
        if dspecialasi = '1' then
          v.s             := as_wrasi;
        -- Miss or not written before.
        elsif r.d2paddrv = '0' or r.d2tlbmod = '0' then
          if not is_riscv then
            v.ahb_haddr   := mmu_base(r, csr);
          end if;
          start_walk      := true;   -- See more after case.
        -- 64 bit write on 32 bit bus?
        elsif r.d2size = "11" and r.d2busw = '0' then
          v.ahb_hbusreq   := '1';
          v.ahb_haddr     := r.d2paddr(v.ahb_haddr'range);
          v.ahb_hsize     := HSIZE_WORD;
          v.ahb_htrans    := HTRANS_NONSEQ;
          v.ahb_hburst    := HBURST_INCR;
          v.ahb_hwrite    := '1';
          v.ahb_snoopmask := r.d2hitv;
          v.s             := as_wrburst;
          keepreq         := '1';
        -- Store buffer needs emptying
        else
          v.ahb_haddr     := r.d2paddr(v.ahb_haddr'range);
          v.ahb_hsize     := "0" & r.d2size;
          v.ahb_htrans    := HTRANS_NONSEQ;
          v.ahb_hburst    := HBURST_SINGLE;
          v.ahb_hwrite    := '1';
          v.ahb_snoopmask := r.d2hitv;
          v.d2stbuf(0).addr      := r.d2paddr;
          v.d2stbuf(0).size      := r.d2size;
          v.d2stbuf(0).data      := r.d2data;
          v.d2stbuf(0).snoopmask := r.d2hitv;
          v.d2stbw               := "01";
          v.s             := as_store;
          v.slowwrpend    := '0';
          if r.d1ten = '1' then
            v.ramreload   := '1';
          end if;
        end if;

      -- 64 bit write to 32 bit bus using two word burst.
      when as_wrburst =>
        if ahbi.hresp(1) = '1' then
          v.ahb_htrans      := HTRANS_IDLE;
        end if;
        if ahbi.hready = '1' then
          if r.granted = '1' and ahbi.hresp(1) = '0' and r.ahb_htrans(1) = '1' then
            v.ahb_haddr(2)  := not r.ahb_haddr(2);
            v.ahb_htrans(0) := '1';
            if r.ahb_haddr(2) = '1' then
              v.ahb_htrans  := HTRANS_IDLE;
            end if;
            if (r.ahb_haddr(2) = '0') xor ENDIAN_B then
              v.ahb_hwdata  := hi_h(r.d2data) & hi_h(r.d2data);
            else
              v.ahb_hwdata  := lo_h(r.d2data) & lo_h(r.d2data);
            end if;
          elsif r.ahb2_inacc = '1' and ahbi.hresp(1) = '1' then
            v.ahb_haddr(2)  := not r.ahb_haddr(2);
            v.ahb_htrans    := HTRANS_NONSEQ;
          elsif r.ahb_htrans(1) = '0' then
            v.s             := as_normal;
            v.slowwrpend    := '0';
            if r.d1ten = '1' then
              v.ramreload   := '1';
            end if;
          end if;
        end if;
        if v.ahb_haddr(2) = '0' then
          keepreq           := '1';
        end if;

      -- Special writes
      when as_wrasi =>
        v.s           := as_wrasi2;
        -- For next state in case of ASI 0xC-0xF
        v.flushctr    := r.d2vaddr(d_index'range);
        v.irdbufvaddr := r.d2vaddr(r.irdbufvaddr'range);
        v.iramaddr    := r.d2vaddr(r.iramaddr'range);
        -- Get fake way hit vectors.
        vtmp4i        := decwrap(get(r.d2vaddr, DOFFSET_HIGH + 1, 2), DSETS);
        v.d2hitv      := vtmp4i(d_ways'range);
        vtmp4i        := decwrap(get(r.d2vaddr, DOFFSET_HIGH + 1, 2), ISETS);
        v.i2hitv      := vtmp4i(i_ways'range);
        for x in 0 to LINESZMAX / 2 - 1 loop
          v.ahb3_rdbuf(x * 64 + 63 downto x * 64) := r.d2data;
        end loop;
        v.dregval64   := hi_h(r.d2data);
        v.dregval     := lo_h(r.d2data);
        v.ramreload   := '1';

        case r.d2asi is
          when x"02" =>                 -- System control registers
            vaddr4 := r.d2vaddr(5 downto 2);
            case vaddr4 is
              when "0000" =>    -- Cache control register
                set_ccr(r.d2data(63 downto 32));
                if r.d2data(32 + 21) = '1' then
                  oico.btb_flush := '1';
                end if;

              when "0010" =>    -- ICache configuration register
                null;
              when "0011" =>    -- DCache configuration register
                null;
              when "0100" =>    -- LEON5 configuration register

              when "0110" =>    -- LEON5 region flush mask register
                v.regflmask := r.d2data(32 + 31 downto 32 + 4);

              when "0111" =>    -- LEON5 region flush register
                v.regfladdr  := r.d2data(31 downto 4);
                v.iregflush  := r.d2data(1);
                v.dregflush  := r.d2data(0);
                v.iflushpend := v.iflushpend or v.iregflush;
                v.dflushpend := v.dflushpend or v.dregflush;

              when others =>    -- Unimplemented
                v.dregerr := '1';
            end case;

          when x"0c" =>                 -- ICache tags
            null;

          when x"0d" =>                 -- ICache data
            -- Go to read diag state to read other part of 64-bit data
            if r.d2size /= "11" then
              v.s := as_rdcdiag;
            end if;

          when x"0e" =>                 -- DCache tags
            null;

          when x"0f" =>                 -- DCache data
            null;

          when x"11" =>                 -- DCache flush
            v.dflushpend   := '1';
            v.flushpart(0) := '1';
            v.flushctr     := (others => '0');
            v.slowwrpend   := '0';
            v.s            := as_flush;
            v.perf(4)      := '1';

          when x"18" =>                 -- Cache+TLB flush
            v.tlbflush   := '1';
            v.flushpart  := "11";
            v.dflushpend := '1';
            v.iflushpend := '1';
            v.flushctr   := (others => '0');
            v.slowwrpend := '0';
            v.s          := as_flush;
            v.perf(4)    := '1';

          when x"19" =>                 -- MMU registers
            if not is_riscv then
              vaddr3 := r.d2vaddr(10 downto 8);
              case vaddr3 is
                when "000" =>  -- 0x000 MMU control register
                  v.mmctrl1.tlbdis     := r.d2data(32 + 15);
                  v.mmctrl1.nf   := r.d2data(32 + 1);
                  v.mmctrl1.e    := r.d2data(32 + 0);
                when "001" =>  -- 0x100 Context pointer register
                  v.mmctrl1.ctxp := r.d2data(32 + 31 downto 32 + 2);
                when "010" =>  -- 0x200 Context register
                  v.mmctrl1.ctx  := r.d2data(32 + 7 downto 32 + 0);
                when others =>
                  v.dregerr := '1';
              end case;
            else
              v.dregerr := '1';
            end if;

          when x"1b" =>                 -- MMU flush/probe
            if r.d2vaddr(11) = '1' or (r.d2vaddr(10) = '1' and r.d2vaddr(9 downto 8) /= "00") then
              -- Undefined probe type -- return 0
              v.dregval := (others => '0');
              v.s       := as_rdasi2;
            elsif r.d2vaddr(10) = '1' then
              -- Return data from DTLB if address matched and "entire" mode
              if r.d2tlbamatch = '1' then
                v.dregval(31 downto 28) := "0000";
                v.dregval(7)            := r.dtlb(u2i(r.d2tlbid)).cached;
                v.dregval(6)            := r.dtlb(u2i(r.d2tlbid)).modified;
                v.dregval(5)            := '1';    -- Referenced
                v.dregval(4 downto 2)   := r.dtlb(u2i(r.d2tlbid)).acc;
                v.dregval(1 downto 0)   := "10";   -- PTE
                v.s                     := as_rdasi2;
              else
                -- Try reading from ITLB
                v.s         := as_mmuprobe2;
                v.i1pc      := r.d2vaddr;
                v.d2vaddr   := r.i1pc;
              end if;
            else
              -- Fall back to MMU walk
              start_walk    := true;
              v.mmusel      := "101";
              if not is_riscv then
                v.ahb_haddr := mmu_base(r, csr);
              end if;
            end if;

          when x"1c" =>                 -- MMU/Cache bypass
            -- Update registers and jump back to normal to handle in standard path
            v.d2paddr  := (others => '0');
            if v.d2paddr'length < r.d2vaddr'length then
              v.d2paddr                  := r.d2vaddr(v.d2paddr'range);
            else
              v.d2paddr(r.d2vaddr'range) := r.d2vaddr;
            end if;
            v.d2paddrv     := '1';
            v.d2tlbmod     := '1';
            v.d2busw       := dec_wbmask_fixed(r.d2vaddr(ahbo.haddr'high downto 2), wbmask);
            v.d2asi        := "000" & ASI_SDATA;
            v.d2specialasi := '0';
            v.d2su         := '1';
            v.d2hitv       := (others => '0');
            v.s            := as_normal;

          when x"1e" =>                 -- Snoop tags
            null;

          when x"20" =>                 -- FPC control/debug
            v.s                  := as_wrasi;
            v.fpc_mosi.accen     := '1';
            v.fpc_mosi.accwr     := '1';
            if r.fpc_mosi.accen = '0' then
              v.fpc_mosi.addr(0) := r.d2vaddr(2);
            elsif r.fpc_mosi.accen = '1' and fpc_miso.accrdy = '1' and r.d2size = "11" then
              v.fpc_mosi.addr(0) := '1';
            end if;
            if v.fpc_mosi.addr(0) = '0' xor ENDIAN_B then
              v.fpc_mosi.wrdata  := hi_h(r.d2data);
            else
              v.fpc_mosi.wrdata  := lo_h(r.d2data);
            end if;
            if r.fpc_mosi.accen = '1' and fpc_miso.accrdy = '1' then
              if not ENDIAN_B then
                v.dregval64      := r.dregval;
                v.dregval        := fpc_miso.rddata;
              else
                v.dregval        := r.dregval64;
                v.dregval64      := fpc_miso.rddata;
              end if;
              if r.d2size /= "11" or r.fpc_mosi.addr(0) = '1' then
                v.s              := as_wrasi3;
                v.fpc_mosi.accen := '0';
              end if;
            end if;

          when x"21" =>                 -- CPC (coprocessor) control/debug
            v.dregerr := '1';

          when x"22" =>                 -- CPU-to-CPU interface
            v.s                  := as_wrasi;
            v.c2c_mosi.accen     := '1';
            v.c2c_mosi.accwr     := '1';
            if r.c2c_mosi.accen = '0' then
              v.c2c_mosi.addr(0) := r.d2vaddr(2);
            elsif r.c2c_mosi.accen = '1' and c2c_miso.accrdy = '1' and r.d2size = "11" then
              v.c2c_mosi.addr(0) := '1';
            end if;
            if v.c2c_mosi.addr(0) = '0' xor ENDIAN_B then
              v.c2c_mosi.wrdata  := hi_h(r.d2data);
            else
              v.c2c_mosi.wrdata  := lo_h(r.d2data);
            end if;
            if r.c2c_mosi.accen = '1' and c2c_miso.accrdy = '1' then
              v.dregval64        := r.dregval;
              v.dregval          := c2c_miso.rddata;
              if r.d2size /= "11" or r.c2c_mosi.addr(0) = '1' then
                v.s              := as_wrasi3;
                v.c2c_mosi.accen := '0';
              end if;
            end if;

          when x"23" =>                 -- TLB diagnostic access
            -- d2vaddr(9) -- I / D
            -- d2vaddr(8) -- PMRU state
            -- d2vaddr(7 downto 3) -- entry
            if r.d2vaddr(9) = '0' then
              v.newent := r.dtlb(u2i(r.d2vaddr(2 + log2x(dtlbnum) downto 3)));
            else
              v.newent := r.itlb(u2i(r.d2vaddr(2 + log2x(itlbnum) downto 3)));
            end if;
            if r.d2vaddr(8) = '0' then
              if r.d2vaddr(2) = '0' or r.d2size = "11" then
                v.newent.ctx      := r.d2data(32 + 11 downto 32 + 4);
                v.newent.mask(1)  := r.d2data(32 + 3);
                v.newent.mask(2)  := r.d2data(32 + 2);
                v.newent.valid    := r.d2data(32 + 0);
              end if;
              if r.d2vaddr(2) = '1' or r.d2size = "11" then
                v.newent.acc      := r.d2data(5 downto 3);
                v.newent.busw     := r.d2data(2);
                v.newent.cached   := r.d2data(1);
                v.newent.modified := r.d2data(0);
              end if;
              v.tlbupdate         := '1';
              v.i2tlbid           := r.d2vaddr(2 + log2x(itlbnum) downto 3);
              v.d2tlbid           := r.d2vaddr(2 + log2x(dtlbnum) downto 3);
              v.mmusel(0)         := not r.d2vaddr(9);
              v.i2tlbhit          := r.d2vaddr(9);
              v.d2tlbhit          := not r.d2vaddr(9);
            else
              if r.d2vaddr(9) = '0' then
                for x in v.dtlbpmru'range loop
                  v.dtlbpmru(x)   := r.d2data(32 + x);
                end loop;
              else
                for x in v.itlbpmru'range loop
                  v.itlbpmru(x)   := r.d2data(32 + x);
                end loop;
              end if;
            end if;
            v.s := as_wrasi2;

          when x"24" =>                 -- BTB/BHT diagnostic access
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

          when others =>
            v.dregerr := '1';
        end case;

      when as_wrasi2 =>
        v.s         := as_wrasi3;
        v.ramreload := r.ramreload;
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

        case r.d2asi is
          when x"0c" =>                 -- ICache tags
            ocrami.itagen(i_ways'range)     := r.i2hitv;
            ocrami.itagwrite                := '1';
          when x"0d" =>                 -- ICache data
            ocrami.idataen(i_ways'range)    := r.i2hitv;
            ocrami.idatawrite               := "11";
          when x"0e" =>                 -- DCache tags
            if all_0(rs.s3hit) then
              ocrami.dtaguwrite(d_ways'range) := r.d2hitv;
            else
              if dtagconf = 0 then
                -- Interference with snooping
                v.s := r.s;             -- Stall here and try again next cycle
              end if;
            end if;
            if r.dregval(0) = '1' then
              vs.validarr(u2i(r.d2vaddr(d_index'range))) :=
                vs.validarr(u2i(r.d2vaddr(d_index'range))) or r.d2hitv;
            else
              vs.validarr(u2i(r.d2vaddr(d_index'range))) :=
                vs.validarr(u2i(r.d2vaddr(d_index'range))) and not r.d2hitv;
            end if;
          when x"0f" =>                 -- DCache data
            ocrami.ddataen(d_ways'range)    := r.d2hitv;
            if r.d2vaddr(2) = '0' xor ENDIAN_B then
              ocrami.ddatawrite(7 downto 4) := "1111";
            else
              ocrami.ddatawrite(3 downto 0) := "1111";
            end if;
          when x"1e" =>                 -- Snoop tags
            if all_0(rs.s1en) then
              ocrami.dtagsen(d_ways'range)  := r.d2hitv;
              ocrami.dtagswrite             := '1';
            else
              v.s := r.s; -- Stall here
            end if;
          when others =>
            null;
        end case;

        v.ahb3_error := r.dregerr;


      when as_wrasi3 =>
        v.ramreload  := r.ramreload;
        odco.mds     := '0';
        d_mexc       := r.ahb3_error;
        v.slowwrpend := '0';
        v.s          := as_normal;

      -- Special reads
      when as_rdasi =>
        v.dregval     := (others => '0');
        -- Set irdbufaddr/iramaddr regs for Icache diag accesses
        v.irdbufvaddr := r.d2vaddr(r.irdbufvaddr'range);
        v.iramaddr    := r.d2vaddr(r.iramaddr'range);
        case r.d2asi is
          when x"02" =>                 -- System control registers
            vaddr4 := r.d2vaddr(5 downto 2);
            case vaddr4 is
              when "0000" =>    -- Cache control register
                v.dregval := get_ccr(r, rs);
              when "0010" =>    -- ICache configuration register
                v.dregval := cache_cfg5(0, ISETS, ilinesize, isetsize, 0,
                                        0, 0, 0, 0, 1);
              when "0011" =>    -- DCache configuration register
                v.dregval := cache_cfg5(0, DSETS, dlinesize, dsetsize, 0,
                                        6, 0, 0, 0, 1);
              when "0100" =>    -- LEON5 configuration register
                v.dregval               := (others => '0');
                v.dregval(31 downto 30) := u2slv(dtagconf, 2);

              when "0110" =>    -- LEON5 region flush mask register
                v.dregval(31 downto 4)  := r.regflmask;

              when "0111" =>    -- LEON5 region flush register
                v.dregval(31 downto 4)  := r.regfladdr;
                v.dregval(1)            := r.iregflush;
                v.dregval(0)            := r.dregflush;

              when others =>    -- Unimplemented
                v.dregerr := '1';
            end case;
            v.s := as_rdasi2;

          when x"0c" =>                 -- ICache tags
            v.s := as_rdcdiag;

          when x"0d" =>                 -- ICache data
            v.s := as_rdcdiag;

          when x"0e" =>                 -- DCache tags
            v.s := as_rdcdiag;

          when x"0f" =>                 -- DCache data
            v.s := as_rdcdiag;

          when x"19" =>                 -- MMU registers
            if not is_riscv then
              vaddr3 := r.d2vaddr(10 downto 8);
              case vaddr3 is
                when "000" =>  -- 0x000 MMU control register
                  v.dregval(31 downto 28)   := "0000";  -- impl
                  v.dregval(27 downto 24)   := "0001";  -- ver
                  v.dregval(23 downto 21)   := u2slv(log2(itlbnum), 3);
                  v.dregval(20 downto 18)   := u2slv(log2(dtlbnum), 3);
                  v.dregval(17 downto 16)   := u2slv(0, 2);
                  v.dregval(15)             := r.mmctrl1.tlbdis;
                  v.dregval(14)             := '1';   -- Sep tlb
                  v.dregval(1)              := r.mmctrl1.nf;
                  v.dregval(0)              := r.mmctrl1.e;
                when "001" =>  -- 0x100 Context pointer register
                  v.dregval(31 downto 2)    := r.mmctrl1.ctxp;
                when "010" =>  -- 0x200 Context register
                  v.dregval(7 downto 0)     := r.mmctrl1.ctx;
                when "011" =>  -- 0x300 Fault status register
                  v.dregval(17 downto 10)   := r.mmfsr.ebe;
                  v.dregval(9 downto 8)     := r.mmfsr.l;
                  v.dregval(7 downto 5)     := r.mmfsr.at_ls & r.mmfsr.at_id & r.mmfsr.at_su;
                  v.dregval(4 downto 2)     := r.mmfsr.ft;
                  v.dregval(1)              := r.mmfsr.fav;
                  v.dregval(0)              := r.mmfsr.ow;
                  -- Self-clearing on read but not if read through DSU
                  if dci.dsuen = '0' then
                    v.mmfsr.ft  := "000";
                    v.mmfsr.fav := '0';
                    v.mmfsr.ow  := '0';
                  end if;
                when "100" =>  -- 0x400 Fault address register
                  v.dregval(r.mmfar'range) := r.mmfar;
                when others =>
                  v.dregerr := '1';
              end case;
            end if;
            v.s := as_rdasi2;

          when x"1b" =>                 -- MMU flush/probe
            v.s           := as_mmuflush2;
            v.itlbprobeid := (others => '0');
            v.d2tlbid     := (others => '0');

          when x"1c" =>                 -- MMU/Cache bypass
            -- Update registers and jump back to normal to handle in standard path
            v.d2paddr  := (others => '0');
            if v.d2paddr'length < r.d2vaddr'length then
              v.d2paddr                  := r.d2vaddr(v.d2paddr'range);
            else
              v.d2paddr(r.d2vaddr'range) := r.d2vaddr;
            end if;
            v.d2paddrv     := '1';
            v.d2busw       := dec_wbmask_fixed(r.d2vaddr(ahbo.haddr'high downto 2), wbmask);
            v.d2asi        := "000" & ASI_SDATA;
            v.d2specialasi := '0';
            v.d2su         := '1';
            v.d2hitv       := (others => '0');
            v.d2nocache    := '1';
            v.s            := as_normal;

          when x"1e" =>                 -- Snoop tags
            v.s := as_rdcdiag;

          when x"20" =>                 -- FPC control/debug
            v.dregval            := r.dregval;
            v.fpc_mosi.accen     := '1';
            v.fpc_mosi.accwr     := '0';
            if r.fpc_mosi.accen = '0' then
              v.fpc_mosi.addr(0) := r.d2vaddr(2);
            elsif r.fpc_mosi.accen = '1' and fpc_miso.accrdy = '1' and r.d2size = "11" then
              v.fpc_mosi.addr(0) := '1';
            end if;
            if r.fpc_mosi.accen = '1' and fpc_miso.accrdy = '1' then
              v.dregval64        := r.dregval;
              v.dregval          := fpc_miso.rddata;
              if r.d2size /= "11" or r.fpc_mosi.addr(0) = '1' then
                v.s              := as_rdasi2;
                v.fpc_mosi.accen := '0';
              end if;
            end if;

          when x"21" =>                 -- CPC (co-processor) control/debug
            v.dregerr := '1';
            v.s       := as_rdasi2;

          when x"22" =>                 -- CPU-to-CPU interface
            v.dregval            := r.dregval;
            v.c2c_mosi.accen     := '1';
            v.c2c_mosi.accwr     := '0';
            if r.c2c_mosi.accen = '0' then
              v.c2c_mosi.addr(0) := r.d2vaddr(2);
            elsif r.c2c_mosi.accen = '1' and c2c_miso.accrdy = '1' and r.d2size = "11" then
              v.c2c_mosi.addr(0) := '1';
            end if;
            if r.c2c_mosi.accen = '1' and c2c_miso.accrdy = '1' then
              if not ENDIAN_B then
                v.dregval64      := r.dregval;
                v.dregval        := c2c_miso.rddata;
              else
                v.dregval        := r.dregval64;
                v.dregval64      := c2c_miso.rddata;
              end if;
              if r.d2size /= "11" or r.c2c_mosi.addr(0) = '1' then
                v.s              := as_rdasi2;
                v.c2c_mosi.accen := '0';
              end if;
            end if;

          when x"23" =>                 -- TLB diagnostic access
            -- d2vaddr(9) -- I / D
            -- d2vaddr(8) -- PMRU state
            -- d2vaddr(7 downto 3) -- entry
            if r.d2vaddr(9) = '0' then
              v.newent := r.dtlb(u2i(r.d2vaddr(2 + log2x(dtlbnum) downto 3)));
            else
              v.newent := r.itlb(u2i(r.d2vaddr(2 + log2x(itlbnum) downto 3)));
            end if;
            if r.d2vaddr(8) = '0' then
              if r.d2vaddr(2) = '0' then
                v.dregval(11 downto 4)  := v.newent.ctx;
                v.dregval(3)            := v.newent.mask(1);
                v.dregval(2)            := v.newent.mask(2);
                v.dregval(0)            := v.newent.valid;
              else
                v.dregval(5 downto 3)   := v.newent.acc;
                v.dregval(2)            := v.newent.busw;
                v.dregval(1)            := v.newent.cached;
                v.dregval(0)            := v.newent.modified;
              end if;
            else
              if r.d2vaddr(9) = '0' then
                for x in r.dtlbpmru'range loop
                  v.dregval(x)          := r.dtlbpmru(x);
                end loop;
              else
                for x in r.itlbpmru'range loop
                  v.dregval(x)          := r.itlbpmru(x);
                end loop;
              end if;
            end if;
            v.s := as_rdasi2;

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

          when others =>                -- Unimplemented ASI
            v.dregerr := '1';
            v.s       := as_rdasi2;
        end case;

      when as_rdasi2 =>
        if r.d2size = "11" then
          v.ahb3_rdbuf(LINESZMAX * 32 - 1 downto LINESZMAX * 32 - 64) := r.dregval64 & r.dregval;
        else
          v.ahb3_rdbuf(LINESZMAX * 32 - 1 downto LINESZMAX * 32 - 64) := r.dregval & r.dregval;
        end if;
        v.ahb3_error := r.dregerr;
        v.s          := as_rdasi3;

      when as_rdasi3 =>
        odco.data(0) := r.ahb3_rdbuf(LINESZMAX * 32 - 1 downto LINESZMAX * 32 - 64);
        odco.set     := "00";
        odco.mds     := '0';
        d_mexc       := r.ahb3_error;
        v.dmisspend  := '0';
        v.s          := as_normal;

      when as_rdcdiag =>
        ocrami.iindex(i_sets'range)       := r.irdbufvaddr(i_index'range);
        ocrami.idataoffs(i_offset'range)  := r.iramaddr;
        ocrami.itagen                     := "1111";
        ocrami.idataen                    := "1111";
        ocrami.dtagcindex(d_sets'range)   := r.d2vaddr(d_index'range);
        ocrami.ddataindex(d_sets'range)   := r.d2vaddr(d_index'range);
        ocrami.ddataoffs(d_offset'range)  := r.d2vaddr(DLINE_HIGH downto DLINE_LOW_REAL);
        ocrami.dtagcen                    := (others => '1');
        ocrami.ddataen                    := (others => '1');
        v.s := as_rdcdiag2;
        if all_0(rs.s1en) then
          ocrami.dtagcindex(d_sets'range) := r.d2vaddr(d_index'range);
          ocrami.dtagsen                  := (others => '1');
        elsif r.d2asi = "00011110" then
          -- Snooping logic is using the tag RAM this cycle - stall
          v.s := as_rdcdiag;
        end if;

      when as_rdcdiag2 =>
        vdiagasi := r.d2asi(1 downto 0);
        case vdiagasi is
          when "00" =>                  -- 0x0C ICache tags
            d32 := cramo.itagdout(u2i(r.d2vaddr(ITAG_LOW + 1 downto ITAG_LOW)));
            v.dregval                           := (others => '0');
            v.dregval(TAG_HIGH downto ITAG_LOW) := d32(TAG_HIGH - ITAG_LOW + 1 downto 1);
            v.dregval(7 downto 0)               := (others => d32(0));
          when "01" =>                  -- 0x0D ICache data
            d64 := cramo.idatadout(u2i(r.d2vaddr(ITAG_LOW + 1 downto ITAG_LOW)));
            if (r.d2vaddr(2) = '0') xor ENDIAN_B then
              if r.d2write = '0' then
                v.dregval   := hi_h(d64);
              else
                v.dregval   := lo_h(d64);
              end if;
            else
              if r.d2write = '0' then
                v.dregval   := lo_h(d64);
              else
                v.dregval64 := hi_h(d64);
              end if;
            end if;
          when "10" =>                  -- 0x0E DCache tags / 0x1E Snoop tags
            d32 := cramo.dtagcdout(u2i(r.d2vaddr(DTAG_LOW + 1 downto DTAG_LOW)));
            v.dregval              := (others => '0');
            v.dregval(d_tag'range) := d32(TAG_HIGH - DTAG_LOW + 1 downto 1);
            v.dregval(7 downto 0)  := (others => d32(0));
            if dtagconf > 0 then
              v.dregval(0) := rs.validarr(u2i(r.d2vaddr(d_index'range)))
                              (u2i(r.d2vaddr(DTAG_LOW + 1 downto DTAG_LOW)));
              v.dregval(7 downto 1) := (others => v.dregval(0));
            end if;
            if r.d2asi(4)='1' then
              v.dregval := (others => '0');
              d32 := cramo.dtagsdout(u2i(r.d2vaddr(DTAG_LOW + 1 downto DTAG_LOW)));
              v.dregval(d_tag'range) := d32(TAG_HIGH - DTAG_LOW + 1 downto 1);
            end if;
          when others =>                -- 0x0F DCache data
            d64 := cramo.ddatadout(u2i(r.d2vaddr(DTAG_LOW + 1 downto DTAG_LOW)));
            if (r.d2vaddr(2) = '0') xor ENDIAN_B then
              v.dregval := hi_h(d64);
            else
              v.dregval := lo_h(d64);
            end if;
        end case;
        if r.d2write = '0' then
          v.s       := as_rdasi2;
        else
          v.s       := as_wrasi2;
        end if;
        -- Must set ramreload here since we have done a Itag read from another addr
        v.ramreload := '1';

      when as_getlock =>
        if r.granted = '1' then
          v.s := as_normal;
        end if;

      when as_amo =>
        if ext_a /= 0 then
          v.mmusel          := "011";
          if r.d2paddrv = '0' or r.d2tlbmod = '0' then
            if not is_riscv then
              v.ahb_haddr   := mmu_base(r, csr);
            end if;
            start_walk      := true;   -- See more after case.
          -- SC:
          elsif r.amo.d2type(1 downto 0) = "11" then -- SC
            v.amo.d2type    := (others => '0');
            v.amo.reserved  := '0';
            odco.mds        := '0';
            odco.data(0)    := (others => '0');
            -- Cancel SC
            if (r.amo.reserved = '0' or r.d2paddr(v.ahb_haddr'range) /= r.amo.addr) then
              v.slowwrpend       := '0';
              v.s                := as_amo_hold;
              odco.data(0)(0)    := '1';
              if r.d2size = "10" then
                odco.data(0)(32) := '1';
              end if;
            else
              v.s        := as_slowwr;
              -- Snoop on this write
              v.d2hitv   := (others => '0');
              v.amo.hold := '1';
              v.amo.sc   := '1';
            end if;
          else                                    -- AMO
            v.s        := as_slowwr;
            -- Snoop on this write
            v.d2hitv   := (others => '0');
            v.amo.hold := '1';
            v.d2data   := amo_data;
          end if;
          -- Force a snooping hit on all atomics 
          vs.s1en   := (others => '1');
          vs.s1tag  := (others => '0');
          vs.s1tag(ahbsi.haddr'high downto d_tag'low) := r.d2paddr(ahbsi.haddr'high downto d_tag'low);
          vs.s1offs := r.d2paddr(d_index'range);
          vs.s1read := '0';
        else
          v.s := as_normal;
        end if;
      when as_amo_hold =>
        if (all_0(rs.s1en) and all_0(rs.s2en) and all_0(rs.s3hit)) or
           ext_a = 0 then
          v.s := as_normal;
        end if;

      when as_parked =>
        oico.parked := '1';
        -- Check on hready to ensure r.granted status is up to date in case we were
        -- clock gated while parked.
        if ici.parkreq = '0' and ahbi.hready = '1' then
          v.s := as_normal;
        end if;

      when as_mmuprobe2 =>
        -- Swap back addresses
        v.i1pc          := r.d2vaddr;
        v.d2vaddr       := r.i1pc;
        -- Check if ITLB hit
        if itlbchk.amatch = '1' then
          v.s           := as_mmuprobe3;
        else
          -- Fall back to MMU walk
          v.mmusel      := "101";
          if not is_riscv then
            v.ahb_haddr := mmu_base(r, csr);
          end if;
        end if;

      when as_mmuprobe3 =>
        v.dregval(31 downto 28) := "0000";
        v.dregval(7)            := r.dtlb(u2i(r.itlbprobeid)).cached;
        v.dregval(6)            := r.dtlb(u2i(r.itlbprobeid)).modified;
        v.dregval(5)            := '1';    -- Referenced
        v.dregval(4 downto 2)   := r.dtlb(u2i(r.itlbprobeid)).acc;
        v.dregval(1 downto 0)   := "10";   -- PTE
        v.s                     := as_rdasi2;

      when as_mmuflush2 =>
        v.itlbprobeid  := std_logic_vector(unsigned(r.itlbprobeid) + 1);
        v.d2tlbid      := std_logic_vector(unsigned(r.d2tlbid) + 1);
        if flushmatch(r.itlb(u2i(r.itlbprobeid)), r.d2vaddr, mmu_ctx(r, csr)) = '1' then
          v.itlb(u2i(r.itlbprobeid)).valid := '0';
        end if;
        if flushmatch(r.dtlb(u2i(r.d2tlbid)), r.d2vaddr, mmu_ctx(r, csr)) = '1' then
          v.dtlb(u2i(r.d2tlbid)).valid     := '0';
        end if;
        if (dtlbnum >= itlbnum and all_1(r.d2tlbid)) or
           (dtlbnum  < itlbnum and all_1(r.itlbprobeid)) then
          v.s          := as_normal;
          v.ramreload  := '1';
          v.slowwrpend := '0';
        end if;

      when as_regflush =>
        ocrami.iindex               := (others => '0');
        ocrami.iindex(i_sets'range) := r.flushctr(i_sets'range);
        ocrami.idataoffs            := (others => '0');
        for w in i_ways'range loop
          -- ocrami.itagdin(w) := (others => '0');
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW + 1 downto TAG_HIGH - ITAG_LOW - 6)  := x"FF";
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW - 7 downto TAG_HIGH - ITAG_LOW - 8)  := u2slv(w, 2);
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW - 9 downto TAG_HIGH - ITAG_LOW - 10) := u2slv(w, 2);
          ocrami.itagdin(w)(TAG_HIGH - ITAG_LOW + 1 downto TAG_HIGH - ITAG_LOW)      := r.untagi(2 * w + 1 downto 2 * w);
          ocrami.itagdin(w)(0)                                                       := '0';
        end loop;
        if r.flushpart(1) = '1' then
          ocrami.itagen      := "1111";
          ocrami.itagwrite   := '0';
          if not all_0(r.flushwri) then
            ocrami.itagen(i_ways'range) := r.flushwri;
            ocrami.itagwrite            := '1';
          end if;
        end if;
        if r.flushpart(0) = '1' then
          if vs.s1en(0) = '0' then
            vs.s1tag                               := (others => '0');
            vs.s1tag(TAG_HIGH downto TAG_HIGH - 7) := x"F3";
            vs.s1tagmsb := r.untagd;
            vs.s1offs   := r.flushctr(DOFFSET_HIGH - DOFFSET_LOW downto 0);
            vs.s1read   := '1';
            vs.s1flush  := r.flushwrd;
          end if;
        end if;

        if r.regflpipe(1) = '1' and
           ((not all_0(frdmatch) and r.dregflush = '1') or
            (not all_0(frimatch) and r.iregflush = '1')) then
          v.regflpipe      := "00";
          if r.flushpart(0) = '1' then
            v.flushwrd     := frdmatch;
          end if;
          if r.flushpart(1) = '1' then
            v.flushwri     := frimatch;
          end if;
          v.flushctr       := std_logic_vector(unsigned(r.flushctr) - 2);
        elsif all_0(r.flushwrd) and all_0(r.flushwri) then
          if (r.flushctr(d_sets'range) and r.regflmask(d_index'range))
             = r.regfladdr(d_index'range) then
            v.regflpipe(0) := '1';
          end if;
          v.flushctr       := std_logic_vector(unsigned(r.flushctr) + 1);
          if all_0(v.flushctr) then
            v.s            := as_regflush2;
          end if;
        else
          if not all_0(r.flushwrd) and vs.s1en(0) = '1' then
            -- Stall due to contention with AHB snooping
            v.flushwrd     := r.flushwrd;
          else
            v.flushctr     := std_logic_vector(unsigned(r.flushctr) + 1);
            if all_0(v.flushctr) then
              v.s          := as_regflush2;
            end if;
          end if;
        end if;

      when as_regflush2 =>
        if r.regflpipe(1) = '1' and
           ((not all_0(frdmatch) and r.dregflush = '1') or
            (not all_0(frimatch) and r.iregflush = '1')) then
          v.regflpipe    := "00";
          if r.flushpart(0) = '1' then
            v.flushwrd   := frdmatch;
          end if;
          if r.flushpart(1) = '1' then
            v.flushwri   := frimatch;
          end if;
          v.flushctr     := std_logic_vector(unsigned(r.flushctr) - 2);
          v.s            := as_regflush;
        elsif r.regflpipe = "00" and all_0(rs.s1flush) and
              all_0(rs.s2flush) and all_0(rs.s3flush) then
          if r.flushpart(1) = '1' then
            v.iflushpend := '0';
            v.iregflush  := '0';
          end if;
          if r.flushpart(0) = '1' then
            v.dflushpend := '0';
            v.dregflush  := '0';
          end if;
          v.ramreload    := '1';
          v.s            := as_normal;
        end if;

    end case;

    -- There really should never be a table walk with MMU disabled.
    -- Ensure this!
    if mmu_enabled(r, csr) = '0' then
      start_walk := false;
      pmp_mmu    := false;
    end if;

    if start_walk then
      v.ahb_hsize     := pte_hsize;
      if not is_riscv then
        v.ahb_htrans  := HTRANS_NONSEQ;
        v.s           := as_mmuwalk;
      else
        -- Need to go via another state, to split PMP dependency chain.
        v.ahb_htrans  := HTRANS_IDLE;

        -- First TLB level.
        v.newent.mask                    := (others => '0');
        v.newent.mask(v.newent.mask'low) := '1';

        -- On RISC-V, the base is indexed directly for the first level.
        -- Return physical address for next level of page table.
        -- mask - pre-shift (ie before new 1 at bit 1 (first)) page table mask
        -- code - mask recoded as position for first 0 (from 1)
        mmu_data                                := (others => '0');
        mmu_data(ppn'length + 10 - 1 downto 10) := mmu_base(r, csr)(ppn'range);
        case v.mmusel(1 downto 0) is
        when "00"   => v.ahb_haddr := pt_addr(mmu_data, v.newent.mask, r.i1pc, "00")(v.ahb_haddr'range);
        when "01"   => v.ahb_haddr := pt_addr(mmu_data, v.newent.mask, v.d2vaddr, "00")(v.ahb_haddr'range);
        when others => v.ahb_haddr := pt_addr(mmu_data, v.newent.mask, r.d2vaddr, "00")(v.ahb_haddr'range);
        end case;
        pmp_type := v.mmusel(1 downto 0);
        v.s      := as_wmmuwalk;
      end if;
    end if;

    if is_riscv then
      -- PMP
      if pmp_mmu then
        -- Check page table address!
        pmp_prv       := PRIV_LVL_S;
        pmp_mprv      := '0';
        pmp_mpp       := (others => '0');
        pmp_virt      := (others => '0');
        pmp_addr      := (others => '0');
        pmp_addr(r.ahb_haddr'range) := r.ahb_haddr;
        pmp_size      := r.ahb_hsize(pmp_size'range);
        if not ENDIAN_B then
          pmp_addr    := to_le_address(pmp_addr, pmp_size);
        end if;
        pmp_acc       := PMP_ACCESS_R;
        pmp_valid     := '1';
      end if;

      if pmpen then
        pmp_unit(pmp_prv, csr.precalc, csr.pmpcfg0, csr.pmpcfg2,
                 pmp_mprv, pmp_mpp, pmp_virt, pmp_addr, pmp_size, pmp_acc, pmp_valid,
                 pmp_xc, pmp_cause, pmp_tval,
                 pmp_entries, pmp_no_tor, pmp_g, pmp_msb);
      end if;
      if r.mmusel(0) = '0' then
        if addr_check_mask(7) = '0' then
          pmp_xc := '0';
        end if;
      else
        if addr_check_mask(3) = '0' then
          pmp_xc := '0';
        end if;
      end if;

      if pmp_mmu and pmp_valid = '1' and pmp_xc = '1' then
        v.newerrclass := "11";
        v.mmuerr.ft   := "100";       -- Translation error
        v.mmuerr.fav  := '1';
        v.s           := as_mmuwalk3;
      end if;
    end if;

    -- AMO: extend hold until store is executed
    if (r.amo.hold = '1' and v.s = as_normal) or ext_a = 0 then
      v.amo.hold := '0';
      v.amo.sc   := '0';
    end if;
    -- AMO: data
    if odco.mds = '0' or r.holdn = '1' then
      v.amo.data := odco.data(u2i(odco.set));
    end if;

    -- Assume no hold ('1'), but assert ('0') if
    --  pending I/D$ miss or flush,
    --  pending slow write,
    --  or store buffer full.
    v.holdn := '1';
    if v.imisspend  = '1' or v.dmisspend  = '1' or v.slowwrpend = '1' or
       v.iflushpend = '1' or v.dflushpend = '1' or v.ramreload  = '1' or
       v.stbuffull  = '1' or
       v.amo.hold = '1' then
      v.holdn := '0';
    end if;

    v.fastwr_rdy := '0';
    if (v.s = as_normal and v.ahb_hlock = '0') or v.s = as_store then
      v.fastwr_rdy := '1';
    end if;

    -- Bus request handling
    v.ahb_hbusreq := '0';
    if (v.ahb_htrans(1) = '1' or r.s = as_getlock or v.s = as_mmuwalk4) and
       (v.granted = '0' or v.ahb_hlock = '1' or keepreq = '1') then
      v.ahb_hbusreq := '1';
    end if;


    -- No implementation of hprot currently
    v.ahb_hprot := "0000";

    -- Data loopback if no bw support
    if dusebw = 0 then
      for w in d_ways'range loop
        for x in 7 downto 0 loop
          if ocrami.ddatawrite(x) = '0' then
            ocrami.ddatadin(w)(8 * x + 7 downto 8 * x) :=
              cramo.ddatadout(w)(8 * x + 7 downto 8 * x);
          end if;
        end loop;
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
    elsif r.s = as_wrasi2 and r.d2asi = "00001110" then
      ocrami.dtagcuen(d_ways'range)    := r.d2hitv;
      ocrami.dtagcuwrite               := '1';
    end if;



    if no_mmu then
      v.itlb := tlb_def;
      v.dtlb := tlb_def;
    end if;

    --------------------------------------------------------------------------
    -- Reset
    --------------------------------------------------------------------------
    if rst = '0' then
      v.ahb_hlock      := '0';
      v.cctrl          := RRES.cctrl;
      v.mmctrl1.e      := RRES.mmctrl1.e;
      v.mmctrl1.nf     := RRES.mmctrl1.nf;
      v.mmctrl1.pso    := RRES.mmctrl1.pso;
      v.mmctrl1.ctx    := RRES.mmctrl1.ctx;
      v.mmctrl1.tlbdis := RRES.mmctrl1.tlbdis;
      v.mmctrl1.bar    := RRES.mmctrl1.bar;
      v.mmfsr.fav      := RRES.mmfsr.fav;
      v.regflmask      := RRES.regflmask;
      v.regfladdr      := RRES.regfladdr;
      v.iregflush      := RRES.iregflush;
      v.dregflush      := RRES.dregflush;
      v.s              := RRES.s;
      v.imisspend      := RRES.imisspend;
      v.ifailkind      := RRES.ifailkind;
      v.dmisspend      := RRES.dmisspend;
      v.dfailkind      := RRES.dfailkind;
      v.iflushpend     := RRES.iflushpend;
      v.dflushpend     := RRES.dflushpend;
      v.slowwrpend     := RRES.slowwrpend;
      v.holdn          := RRES.holdn;
      v.ahb_hbusreq    := RRES.ahb_hbusreq;
      v.ahb_hlock      := RRES.ahb_hlock;
      v.ahb_htrans     := RRES.ahb_htrans;
      v.granted        := RRES.granted;
      v.i2paddrv       := RRES.i2paddrv;
      v.i1ten          := RRES.i1ten;
      v.i1cont         := RRES.i1cont;
      v.i1rep          := RRES.i1rep;
      v.ibpmiss        := RRES.ibpmiss;
      v.irdbufen       := RRES.irdbufen;
      v.d1ten          := RRES.d1ten;
      vs.sgranted      := RSRES.sgranted;
      -- Atomic operations
      v.amo.d1type     := RRES.amo.d1type;
      v.amo.d2type     := RRES.amo.d2type;
      v.amo.reserved   := RRES.amo.reserved;
      v.amo.hold       := RRES.amo.hold;
      v.amo.store      := RRES.amo.store;
      v.amo.sc         := RRES.amo.sc;
      v.amo.s4hit      := RRES.amo.s4hit;
      -- RISC-V does not use a default TLB, so must invalidate.
      if is_riscv then
        for x in v.itlb'range loop
          v.itlb(x).valid := RRES.itlb(0).valid;
        end loop;
        for x in v.dtlb'range loop
          v.dtlb(x).valid := RRES.dtlb(0).valid;
        end loop;
      end if;
    end if;

    if dtagconf = 0 then
      vs.validarr     := RSRES.validarr;
    end if;

    ---------------------------------------------------------------------------
    -- Replication
    ---------------------------------------------------------------------------
    for x in v.i1pc_repl'range loop
      v.i1pc_repl(x)    := v.i1pc;
    end loop;
    for x in v.d1vaddr_repl'range loop
      v.d1vaddr_repl(x) := v.d1vaddr;
    end loop;

    --------------------------------------------------------------------------
    -- Assign signals
    --------------------------------------------------------------------------
    odco.mexc     := d_mexc;
    odco.exctype  := d_exctype;
    oico.mexc     := i_mexc;
    oico.exctype  := i_exctype;

    c        <= v;
    cs       <= vs;
    ico      <= oico;
    dco      <= odco;
    ahbo     <= oahbo;
    crami    <= ocrami;
    fpc_mosi <= r.fpc_mosi;
    c2c_mosi <= r.c2c_mosi;
    perf     <= r.perf;
  end process;

  regs: process(clk)
  begin
    if rising_edge(clk) then
      r <= c;

    end if;
  end process;

  sregs: process(sclk)
  begin
    if rising_edge(sclk) then
      rs <= cs;
    end if;
  end process;

end;
