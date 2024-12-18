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
-- Entity:      cpucorenv
-- File:        coucorenv.vhd
-- Author:      Nils Wessman, Cobham Gaisler AB
-- Description: Top-level NOEL-V components
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
use techmap.netcomp.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.log2;
use grlib.riscv.reg_t;
library gaisler;
use gaisler.noelvtypes.all;
use gaisler.noelv.XLEN;
use gaisler.noelv.nv_irq_in_type;
use gaisler.noelv.nv_irq_out_type;
use gaisler.noelv.nv_nirq_in_type;
use gaisler.noelv.imsic_in_type;
use gaisler.noelv.imsic_out_type;
use gaisler.noelv.nv_debug_in_type;
use gaisler.noelv.nv_debug_out_type;
use gaisler.noelv.nv_counter_out_type;
use gaisler.noelv.nv_etrace_out_type;
use gaisler.noelvint.all;
use gaisler.utilnv.u2vec;
use gaisler.utilnv.b2i;
use gaisler.utilnv.cond;
use gaisler.utilnv.all_0;
use gaisler.utilnv.uext;
use gaisler.utilnv.u2i;
use gaisler.utilnv.u2slv;
use gaisler.utilnv.uadd;
use gaisler.utilnv.get_lo;

entity cpucorenv is
  generic (
    hindex              : integer range 0  to 15        := 0;  -- hart index
    fabtech             : integer range 0  to NTECH     := DEFFABTECH;
    memtech             : integer                       := DEFMEMTECH;
    -- Misc
    dmen                : integer range 0  to 1         := 0;
    pbaddr              : integer                       := 16#90000#; -- Program buffer exe address
    tbuf                : integer                       := 0;  -- trace buffer size in kB
    cached              : integer                       := 0;
    wbmask              : integer                       := 0;
    busw                : integer                       := 64;
    cmemconf            : integer                       := 0;
    rfconf              : integer                       := 0;
    tcmconf             : integer                       := 0;
    mulconf             : integer                       := 0;
    -- Caches
    icen                : integer range 0  to 1         := 0;  -- I$ Cache Enable
    iways               : integer range 1  to 8         := 1;  -- I$ Sets/Ways
    ilinesize           : integer range 4  to 8         := 4;  -- I$ Cache Line Size (words)
    iwaysize            : integer range 1  to 256       := 1;  -- I$ Cache Way Size (KiB)
    dcen                : integer range 0  to 1         := 0;  -- D$ Cache Enable
    dways               : integer range 1  to 8         := 1;  -- D$ Sets/Ways
    dlinesize           : integer range 4  to 8         := 4;  -- D$ Cache Line Size (words)
    dwaysize            : integer range 1  to 256       := 1;  -- D$ Cache Way Size (KiB)
    -- BHT
    bhtentries          : integer range 32 to 1024      := 256;-- BHT Number of Entries
    bhtlength           : integer range 2  to 10        := 5;  -- History Length
    predictor           : integer range 0  to 2         := 0;  -- Predictor
    -- BTB
    btbentries          : integer range 8  to 128       := 32; -- BTB Number of Entries
    btbsets             : integer range 1  to 8         := 1;  -- BTB Sets/Ways
    -- MMU
    mmuen               : integer range 0  to 2         := 0;  -- Enable MMU
    itlbnum             : integer range 2  to 64        := 8;
    dtlbnum             : integer range 2  to 64        := 8;
    htlbnum             : integer range 1  to 64        := 8;
    tlbforepl           : integer range 1  to 4         := 1;
    riscv_mmu           : integer range 0  to 3         := 1;
    tlb_pmp             : integer range 0  to 1         := 1;  -- Do PMP via TLB
    pmp_no_tor          : integer range 0  to 1         := 0;  -- Disable PMP TOR
    pmp_entries         : integer range 0  to 16        := 16; -- Implemented PMP registers
    pmp_g               : integer range 0  to 10        := 0;  -- PMP grain is 2^(pmp_g + 2) bytes
    pma_entries         : integer range 0  to 16        := 8;  -- Implemented PMA entries
    pma_masked          : integer range 0  to 1         := 0;  -- PMA done using masks
    asidlen             : integer range 0  to 16        := 0;  -- Max 9 for Sv32
    vmidlen             : integer range 0  to 14        := 0;  -- Max 7 for Sv32
    -- Interrupts
    imsic               : integer range 0  to 1         := 0;  -- IMSIC implemented
    -- RNMI
    rnmi_iaddr          : integer                       := 16#00100#; -- RNMI interrupt trap handler address
    rnmi_xaddr          : integer                       := 16#00101#; -- RNMI exception trap handler address
    -- Extensions
    ext_noelv           : integer range 0  to 1         := 1;  -- NOEL-V Extensions
    ext_noelvalu        : integer range 0  to 1         := 1;  -- NOEL-V ALU Extensions
    ext_m               : integer range 0  to 1         := 1;  -- M Base Extension Set
    ext_a               : integer range 0  to 1         := 0;  -- A Base Extension Set
    ext_c               : integer range 0  to 1         := 0;  -- C Base Extension Set
    ext_h               : integer range 0  to 1         := 0;  -- H Extension
    ext_zcb             : integer range 0  to 1         := 0;  -- Zcb Extension
    ext_zba             : integer range 0  to 1         := 0;  -- Zba Extension
    ext_zbb             : integer range 0  to 1         := 0;  -- Zbb Extension
    ext_zbc             : integer range 0  to 1         := 0;  -- Zbc Extension
    ext_zbs             : integer range 0  to 1         := 0;  -- Zbs Extension
    ext_zbkb            : integer range 0  to 1         := 0;  -- Zbkb Extension
    ext_zbkc            : integer range 0  to 1         := 0;  -- Zbkc Extension
    ext_zbkx            : integer range 0  to 1         := 0;  -- Zbkx Extension
    ext_sscofpmf        : integer range 0  to 1         := 0;  -- Sscofpmf Extension
    ext_sstc            : integer range 0  to 2         := 0;  -- Sctc Extension (2 : only time csr impl.)
    ext_smaia           : integer range 0  to 1         := 0;  -- Smaia Extension
    ext_ssaia           : integer range 0  to 1         := 0;  -- Ssaia Extension
    ext_smstateen       : integer range 0  to 1         := 0;  -- Smstateen Extension
    ext_smrnmi          : integer range 0  to 1         := 0;  -- Smrnmi Extension
    ext_ssdbltrp        : integer range 0  to 1         := 0;  -- Ssdbltrp Extension
    ext_smdbltrp        : integer range 0  to 1         := 0;  -- Smdbltrp Extension
    ext_sddbltrp        : integer range 0  to 1         := 0;  -- Sddbltrp Extension
    ext_smepmp          : integer range 0  to 1         := 0;  -- Smepmp Extension
    ext_svpbmt          : integer range 0  to 1         := 0;  -- Svpbmt Extension
    ext_zicbom          : integer range 0  to 1         := 0;  -- Zicbom Extension
    ext_zicond          : integer range 0  to 1         := 0;  -- Zicond Extension
    ext_zimop           : integer range 0  to 1         := 0;  -- Zimop Extension
    ext_zcmop           : integer range 0  to 1         := 0;  -- Zcmop Extension
    ext_zicfiss         : integer range 0  to 1         := 0;  -- Zicfiss Extension
    ext_zicfilp         : integer range 0  to 1         := 0;  -- Zicfilp Extension
    ext_svinval         : integer range 0  to 1         := 0;  -- Svinval Extension
    ext_zfa             : integer range 0  to 1         := 0;  -- Zfa Extension
    ext_zfh             : integer range 0  to 1         := 0;  -- Zfh Extension
    ext_zfhmin          : integer range 0  to 1         := 0;  -- Zfhmin Extension
    ext_zfbfmin         : integer range 0  to 1         := 0;  -- Zfbfmin Extension
    mode_s              : integer range 0  to 1         := 0;  -- Supervisor Mode Support
    mode_u              : integer range 0  to 1         := 0;  -- User Mode Support
    fpulen              : integer range 0  to 128       := 0;  -- Floating-point precision
    trigger             : integer                       := 0;
    -- Advanced Features
    late_branch         : integer range 0  to 1         := 0;  -- Late Branch Support
    late_alu            : integer range 0  to 1         := 0;  -- Late ALUs Support
    ras                 : integer range 0  to 2         := 0;  -- Return Address Stack (1 - test, 2 - enable)
    -- Core
    physaddr            : integer range 32 to 56        := 32; -- Physical Addressing
    rstaddr             : integer                       := 16#00000#; -- reset vector (MSB)
    disas               : integer                       := 0;  -- Disassembly to console
    perf_cnts           : integer range 0  to 29        := 16; -- Number of performance counters
    perf_evts           : integer range 0  to 255       := 16; -- Number of performance events
    perf_bits           : integer range 0  to 64        := 64; -- Bits of performance counting
    illegalTval0        : integer range 0  to 1         := 0;  -- Zero TVAL on illegal instruction
    no_muladd           : integer range 0  to 1         := 0;  -- 1 - multiply-add not supported
    single_issue        : integer range 0  to 1         := 0;  -- 1 - only one pipeline
    mularch             : integer                       := 0;  -- multiplier architecture
    div_hiperf          : integer                       := 0;
    div_small           : integer                       := 0;
    hw_fpu              : integer range 0  to 3         := 1;  -- 1 - use hw fpu
    rfreadhold          : integer range 0  to 1         := 0;  -- Register File Read Hold
    scantest            : integer                       := 0;  -- scantest support
    endian              : integer
    );
  port (
    clk         : in  std_ulogic; -- cpu clock
    gclk        : in  std_ulogic; -- gated cpu clock
    rstn        : in  std_ulogic;
    ahbi        : in  ahb_mst_in_type;
    ahbo        : out ahb_mst_out_type;
    ahbsi       : in  ahb_slv_in_type;
    ahbso       : in  ahb_slv_out_vector;
    imsici      : out imsic_in_type;      -- IMSIC In Port
    imsico      : in  imsic_out_type;     -- IMSIC Out Port
    irqi        : in  nv_irq_in_type;     -- irq in
    irqo        : out nv_irq_out_type;    -- irq out
    nirqi       : in  nv_nirq_in_type;    -- RNM irq in
    dbgi        : in  nv_debug_in_type;   -- debug in
    dbgo        : out nv_debug_out_type;  -- debug out
    eto         : out nv_etrace_out_type;
    cnt         : out nv_counter_out_type; -- Perf event Out Port
    pwrd        : out std_ulogic          -- Activate power down mode
    );
end;

architecture rtl of cpucorenv is

  constant ASYNC_RESET : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant MEMTECH_MOD : integer := memtech mod 65536;

  constant WRT          : integer := 1;  -- enable write-through RAM

  constant dtcmen    : integer := b2i((tcmconf mod 32) /= 0);
  constant dtcmabits : integer := (1 - dtcmen) + (tcmconf mod 32);
  constant itcmen    : integer := b2i(((tcmconf / 256) mod 32) /= 0);
  constant itcmabits : integer := (1 - itcmen) + ((tcmconf / 256) mod 32);

  -- *waysize  is in kByte, thus add 10 (1k = 2^10).
  -- *linesize is in words, thus add 2 (4 = 2^2).
  -- Low bit is (sometimes) valid mark, thus add 1.

  constant iidxwidth    : integer := (log2(iwaysize) + 10) - (log2(ilinesize) + 2);
  constant itagwidth    : integer := physaddr - (log2(iwaysize) + 10) + 1;

  constant didxwidth    : integer := (log2(dwaysize) + 10) - (log2(dlinesize) + 2);
  constant dtagwidth    : integer := physaddr - (log2(dwaysize) + 10) + 1;

  constant cdataw       : integer := 64;

  constant dtagconf     : integer := cmemconf mod 4;
  constant dusebw       : integer := (cmemconf / 4) mod 2;
  constant mulconf_int  : integer := mulconf mod 4;
  constant mulconf_fpu  : integer := (mulconf / 16) mod 4;

  function regen_fpuconf return integer is
  begin
    if hw_fpu = 3 then
      return 1;
    else
      return 0;
    end if;
  end;

  constant fpuconf       : integer := regen_fpuconf;

  -- No support for Zfa/Zfh/Zfhmin on nanoFPUnv
  constant actual_zfa     : integer := cond(hw_fpu = 3, ext_zfa, 0);
  constant actual_zfh     : integer := cond(hw_fpu = 3, ext_zfh, 0);
  constant actual_zfhmin  : integer := cond(hw_fpu = 3, ext_zfhmin, 0);
  constant actual_zfbfmin : integer := cond(hw_fpu = 3, ext_zfbfmin, 0);


  function gen_capability return std_logic_vector is
    variable cap : std_logic_vector(9 downto 0) := (others => '0');
  begin
    cap(9 downto 7) := u2vec(NOELV_TRACE_VERSION, 3);
    cap(6 downto 3) := u2vec(NOELV_VERSION, 4);
    return cap;
  end;

  constant capability   : std_logic_vector(9 downto 0) := gen_capability;

  -- Ensures riscv_mmu is OK.
  -- Sv32 if and only if XLEN is 32, else Sv39 unless explicitly Sv48.
  function constrain_riscv_mmu return integer is
  begin
    if XLEN = 32 then
      return gaisler.mmucacheconfig.sv32;
    end if;
    if riscv_mmu = gaisler.mmucacheconfig.sv48 then
      return riscv_mmu;
    end if;

    return gaisler.mmucacheconfig.sv39;
  end;

  constant actual_riscv_mmu : integer := constrain_riscv_mmu;

  -- Returns how many bits are needed to represent an address (virtual or "physical").
  -- Not quite the same as in MMU/cache, since there it needs to deal with
  -- an actual address (which may be larger than XLEN) after translation.
  -- In the pipeline, the length is limited to max XLEN bits.
  function max_addr_bits return integer is
    constant pa : std_logic_vector := gaisler.mmucacheconfig.pa(actual_riscv_mmu);
    constant va : std_logic_vector := gaisler.mmucacheconfig.va(actual_riscv_mmu);
    constant ga : std_logic_vector := gaisler.mmucacheconfig.ga(actual_riscv_mmu);
  begin
    if ext_h = 0 then
      if mode_s = 0 then
        return gaisler.utilnv.minimum(XLEN, physaddr);
      else
        return gaisler.utilnv.maximum(va'length, gaisler.utilnv.minimum(physaddr, pa'length));
      end if;
    else
      return gaisler.utilnv.minimum(XLEN, ga'length);
    end if;
  end;

  constant addr_bits    : integer := max_addr_bits;
  constant pcaddr_bits  : integer := cond(addr_bits = XLEN, addr_bits, addr_bits + 2);

  function pnp_bar_ok(hconfig : amba_config_word) return boolean is
  begin
    case hconfig(3 downto 0) is
    when "0010" | "0011" | "0001" => return true;
    when others                   => return false;
    end case;
  end;

  -- Convert PnP address/mask to PMA equivalent
  -- Returns array with count as first element
  function pnp_to_pma_addr(ahbso : ahb_slv_out_vector; entries : integer; top : std_logic_vector) return word64_arr is
    -- Non-constant
    variable index   : integer                  := 0;
    variable pma     : word64_arr(0 to entries) := (others => zerow64);
    variable hconfig : amba_config_word;
    variable addr    : std_logic_vector(11 downto 0);
    variable mask    : std_logic_vector(11 downto 0);
    variable mask32  : word32;
  begin
    for i in 0 to NAHBSLV - 1 loop
      for j in NAHBAMR to NAHBCFG - 1 loop
        hconfig      := ahbso(i).hconfig(j);
        mask         := hconfig(15 downto 4);
        addr         := hconfig(31 downto 20) and mask;
        if not all_0(mask) and pnp_bar_ok(hconfig) then
          index      := index + 1;
          assert index <= entries report "Too many PnP entries" severity failure;
          mask32     := not (mask & x"00000");
          pma(index) := uext(top & ((addr & x"00000") or ('0' & mask32(31 downto 1))), 64);
        end if;
      end loop;
    end loop;

    pma(0) := u2slv(index, 64);
    return pma(0 to entries);
  end;

  -- Returns array with count as first element
  -- PMA bits
  --   busw lrsc amo idempotent   burst cache PT_W PT_R   X W R allocated
  function pnp_to_pma_data(ahbso : ahb_slv_out_vector; entries : integer) return word64_arr is
    -- Non-constant
    variable index : integer                          := 0;
    variable pma   : word64_arr(0 to entries) := (others => zerow64);
    variable hconfig : amba_config_word;
    variable mask  : std_logic_vector(11 downto 0);
  begin
    for i in 0 to NAHBSLV - 1 loop
      for j in NAHBAMR to NAHBCFG - 1 loop
        hconfig := ahbso(i).hconfig(j);
        mask    := hconfig(15 downto 4);
        if not all_0(mask) and pnp_bar_ok(hconfig) then
          index := index + 1;
          assert index <= entries report "Too many PnP entries" severity failure;
          case hconfig(3 downto 0) is
          when "0010" =>  -- AHB memory
            pma(index)    := uext(std_logic_vector'(x"fff"), 64);  -- Assume all
            pma(index)(6) := hconfig(16);                          -- Cacheability
            pma(index)(8) := hconfig(17);                          -- Interpret prefetchable as idempotency
          when "0011" =>  -- AHB I/O
            pma(index)    := uext(std_logic_vector'(x"207"), 64);
          when others =>  -- APB I/O (0001)
            pma(index)    := uext(std_logic_vector'(x"207"), 64);
          end case;
        end if;
      end loop;
    end loop;

    pma(0) := u2slv(index, 64);
    return pma(0 to entries);
  end;

  -- Increase the size of an array by extending with zeros.
  function word64_arr_size(arr_in : word64_arr; length : integer) return word64_arr is
    variable arr   : word64_arr(0 to arr_in'length - 1) := arr_in;
    variable sized : word64_arr(0 to length - 1)        := (others => zerow64);
  begin
    if arr'length <= length then
      sized(arr'range) := arr;
    else
      sized            := arr(sized'range);
    end if;

    return sized;
  end;

  -- Add an extra element at the end of an array
  -- Returns array with count as first element
  function word64_arr_extend(arr_in : word64_arr; data : word64) return word64_arr is
    variable arr      : word64_arr(0 to arr_in'length - 1) := arr_in;
    variable extended : word64_arr(0 to arr_in'length)     := word64_arr_size(arr_in, arr_in'length + 1);
  begin
    assert u2i(get_lo(arr(0), 8)) < arr'high report "No room in array" severity failure;
      arr(u2i(get_lo(arr(0), 8)) + 1)      := data;
      arr(0)                    := uadd(arr(0), 1);
      return arr;
  end;

  -- Remove initial count and return the initial part of the array to the specified length.
  function word64_arr_normal(arr_in : word64_arr; length : integer) return word64_arr is
    variable arr : word64_arr(0 to arr_in'length - 1) := arr_in;
  begin
    assert arr'length > length report "Too small array" severity failure;


    return arr(1 to length);
  end;

  -- Remove initial count and return the initial part of the array according to the count.
  function word64_arr_normal(arr_in : word64_arr) return word64_arr is
    variable arr    : word64_arr(0 to arr_in'length - 1) := arr_in;
  begin
    return word64_arr_normal(arr, arr'length - 1);
  end;

  -- Crop and return the array according to its initial count.
  function word64_arr_crop(arr_in : word64_arr) return word64_arr is
    variable arr    : word64_arr(0 to arr_in'length - 1) := arr_in;
    variable length : integer                            := u2i(get_lo(arr(0), 8));
  begin
    assert arr'length > length report "Too small array" severity failure;

    return arr(0 to length);
  end;

  -- PMA
  --   RAM: all                                  1111 1111 1111
  --   ROM: busw?   burst cache   XRvalid        .000 1100 1011
  --   I/O: busw? amo   WRvalid                  .010 0000 0111

  -- GR765
  constant pma_addr_gr765 : word64_arr := (
    uext(std_logic_vector'(x"09fffffff"), 64),   -- 0x080... - 0x0bf...
    uext(std_logic_vector'(x"0c7ffffff"), 64),   -- 0x0c0... - 0x0cf...
    uext(std_logic_vector'(x"0d7ffffff"), 64),   -- 0x0d0... - 0x0df...
    uext(std_logic_vector'(x"0efffffff"), 64),   -- 0x0e0... - 0x0ff...
    uext(std_logic_vector'(x"7ffffffff"), 64));  -- 0x000... - 0xfff...
  --   busw lrsc amo idempotent   burst cache PT_W PT_R   X W R allocated
  constant pma_data_gr765 : word64_arr := (
--  uext(std_logic_vector'(x"1cb"), 64),   -- idem burst cache X R
    uext(std_logic_vector'(x"1cf"), 64),   --  Temporarily allow W for UART in test
    uext(std_logic_vector'(x"14b"), 64),   -- idem cache X R
    uext(std_logic_vector'(x"207"), 64),   -- amo W R
    uext(std_logic_vector'(x"207"), 64),
    uext(std_logic_vector'(x"fff"), 64));  -- All

  -- Small
  constant pma_addr_arr : word64_arr := (
--    uext(std_logic_vector'(x"0007ffff"), 64),    -- 0x000... - 0x000fffff
    uext(std_logic_vector'(x"0afffffff"), 64),  -- 0x0a0... - 0x0bf...???
    uext(std_logic_vector'(x"0c00007ff"), 64),  -- 0x0c0... - 0x0c0...0fff
    uext(std_logic_vector'(x"0efffffff"), 64),  -- 0x0e0... - 0x0ff...
    uext(std_logic_vector'(x"07fffffff"), 64),  -- 0x000... - 0xfff...
    uext(std_logic_vector'(x"0"), 64)          -- Dummy
  );
  --   busw lrsc amo idempotent   burst cache PT_W PT_R   X W R allocated
  constant pma_data_arr : word64_arr := (
    uext(std_logic_vector'(x"a07"), 64),       -- wide amo W R
    uext(std_logic_vector'(x"acb"), 64),       -- wide amo burst cache X R
    uext(std_logic_vector'(x"207"), 64),       -- amo W R
    uext(std_logic_vector'(x"fff"), 64),       -- all
--    uext(std_logic_vector'(x"9cb"), 64),     -- busw idem burst cache X R
--    uext(std_logic_vector'(x"207"), 64)      -- amo W R
    uext(std_logic_vector'(x"0"), 64)          -- Dummy
  );

  -- Word 0: High type   00        01  10  11
  -- Word 1: Low       unallocated I/O RAM ROM
  -- Word 2: Cacheable (if RAM/ROM)
  -- Word 3: Wide bus
  constant pma_data_mask : word64_arr := (
--    -- 0x00000000-0x7fffffff RAM cacheable wide
--    -- 0x80000000-0xbfffffff ROM cacheable wide
--    -- 0xc0000000-0xcfffffff ROM cacheable
--    -- 0xd0000000-0xffffffff unallocated
--    uext(std_logic_vector'(x"1fff"), 64),      -- High type
--    uext(std_logic_vector'(x"1f00"), 64),      -- Low
--    uext(std_logic_vector'(x"1fff"), 64),      -- Cacheable
--    uext(std_logic_vector'(x"00ff"), 64)       -- Wide bus

    -- Hypervisor tests etc
    -- 0x00000000-0x7fffffff RAM cacheable wide
    -- 0x80000000-0x8fffffff I/O
    -- 0x90000000-0x9fffffff I/O
    -- 0xa0000000-0xafffffff I/O (IMSIC@0xa00)
    -- 0xb0000000-0xbfffffff I/O
    -- 0xc0000000-0xcfffffff ROM wide cacheable
    -- 0xd0000000-0xdfffffff I/O
    -- 0xe0000000-0xefffffff I/O wide (ACLINT@0xe)
    -- 0xf0000000-0xffffffff I/O (UART@0xff9 and APLIC@0xfc0)
    uext(std_logic_vector'(x"10ff"), 64),      -- High type
    uext(std_logic_vector'(x"ff00"), 64),      -- Low
    uext(std_logic_vector'(x"10ff"), 64),      -- Cacheable
    uext(std_logic_vector'(x"50ff"), 64)       -- Wide bus (as in various config_local)
  );

  signal pma_addr : word64_arr(0 to pma_entries - 1);
  signal pma_data : word64_arr(0 to pma_entries - 1);

  -- Misc
  signal gnd            : std_ulogic;
  signal vcc            : std_ulogic;
  signal holdn          : std_ulogic;
  signal rst            : std_ulogic;
  signal rstx           : std_ulogic;

  -- Register File
  signal rfi            : iregfile_in_type;
  signal rfo            : iregfile_out_type;
  signal rff            : fregfile_in_type;

  -- BHT
  signal bhti           : nv_bht_in_type;
  signal bhto           : nv_bht_out_type;

  -- BTB
  signal btbi           : nv_btb_in_type;
  signal btbo           : nv_btb_out_type;

  -- RAS
  signal rasi           : nv_ras_in_type;
  signal raso           : nv_ras_out_type;

  -- Cache Controller
  signal crami          : nv_cram_in_type;
  signal cramo          : nv_cram_out_type;

  -- Trace Buffer
  signal tbi            : nv_trace_in_type;
  signal tbo            : nv_trace_out_type;


  -- Cache Signals
  signal ici          : nv_icache_in_type;
  signal ico          : nv_icache_out_type;
  signal dci          : nv_dcache_in_type;
  signal dco          : nv_dcache_out_type;

  signal csr_mmu      : nv_csr_out_type;    -- CSR values for MMU
  signal mmu_csr      : nv_csr_in_type;    -- CSR values for MMU

  -- Mul/Div Unit
  signal muli         : mul_in_type;
  signal mulo         : mul_out_type;
  signal divi         : div_in_type;
  signal divo         : div_out_type;

  signal c_perf       : std_logic_vector(31 downto 0);
  signal iu_cnt       : nv_counter_out_type;


  -- FPU
  signal fpi            : fpu5_in_type;
  signal fpia           : fpu5_in_async_type;
  signal fpo            : fpu5_out_type;
  signal fpoa           : fpu5_out_async_type;
  signal fpc_mosi       : nv_intreg_mosi_type;
  signal fpc_miso       : nv_intreg_miso_type;
  signal c2c_mosi       : nv_intreg_mosi_type;
  signal c2c_miso       : nv_intreg_miso_type;

  signal fs1_data       : std_logic_vector(fpulen - 1 downto 0);
  signal fs2_data       : std_logic_vector(fpulen - 1 downto 0);
  signal fs3_data       : std_logic_vector(fpulen - 1 downto 0);


  signal rff_fd         : std_logic_vector(fpulen - 1 downto 0);
  signal rff_rs1        : reg_t;
  signal rff_rs2        : reg_t;
  signal rff_rs3        : reg_t;
  signal rff_ren        : std_logic_vector(1 to 3);
--  signal rff_rd         : reg_t;
  signal rff_wen        : std_ulogic;

  signal rff_rdummy     : std_logic_vector(fpulen - 1 downto 0);

  signal fs1_word64     : word64;
  signal fs2_word64     : word64;
  signal fs3_word64     : word64;


  signal mtesti_none    : std_logic_vector(memtest_vlen - 1 downto 0);

  signal etrace         : nv_etrace_out_type;

  attribute sync_set_reset : string;
  attribute sync_set_reset of rst : signal is "true";

  signal itracei : itrace_in_type;
  signal itraceo : itrace_out_type;


begin

  -- Signal Assignments -----------------------------------------------------
  gnd                   <= '0';
  vcc                   <= '1';
  holdn                 <= ico.hold and dco.hold;
  mtesti_none           <= (others => '0');
  eto                   <= etrace;

--  -- Use PnP information to set up PMA.
--  pma_addr <= word64_arr_normal(word64_arr_size(
--                word64_arr_extend(pnp_to_pma_addr(ahbso, pma_entries, ""), uext(std_logic_vector'(x"7ffffffff"), 64)),  -- 0x000... - 0xfff...
--                pma_addr'length + 1));
--  pma_data <= word64_arr_normal(word64_arr_size(
--                word64_arr_extend(pnp_to_pma_data(ahbso, pma_entries), uext(std_logic_vector'(x"fff"), 64)),
--                pma_data'length + 1));

--  -- Direct PMA setup
--  pma_addr <= word64_arr_size(pma_addr_arr, pma_addr'length);
--  pma_data <= word64_arr_size(pma_data_arr, pma_data'length);

  -- PMA via masks
  pma_data <= word64_arr_size(pma_data_mask, pma_data'length);

--  -- PMA equivalent to the PnP values from my KCU105 build.
--  pma_addr <= (uext(std_logic_vector'(x"ff97ffff"), 64),
--               uext(std_logic_vector'(x"1fffffff"), 64),
--               uext(std_logic_vector'(x"c07fffff"), 64),
--               uext(std_logic_vector'(x"e007ffff"), 64),
--               uext(std_logic_vector'(x"a007ffff"), 64),
--               uext(std_logic_vector'(x"f9ffffff"), 64),
--               uext(std_logic_vector'(x"fc07ffff"), 64),
--               uext(std_logic_vector'(x"7fffffff"), 64));
--    --   busw lrsc amo idempotent   burst cache PT_W PT_R   X W R allocated
--  pma_data <= (uext(std_logic_vector'(x"ebf"), 64),  -- Temp allow W for UART in test
--               uext(std_logic_vector'(x"fff"), 64),
--               uext(std_logic_vector'(x"fff"), 64),
--               uext(std_logic_vector'(x"ebf"), 64),
--               uext(std_logic_vector'(x"ebf"), 64),
--               uext(std_logic_vector'(x"ebf"), 64),
--               uext(std_logic_vector'(x"ebf"), 64),
--               uext(std_logic_vector'(x"fff"), 64));

  itrace : entity work.itracenv
    generic map (
      hindex        => hindex,
      fabtech       => fabtech,
      memtech       => memtech,
      single_issue  => single_issue,
      dmen          => dmen,
      tbuf          => tbuf,
      disas         => disas,
      scantest      => scantest
    )
    port map (
      clk        => gclk,
      rstn       => rstx,
      itracei    => itracei,
      itraceo    => itraceo,
      fpo        => fpo,
      testen     => ahbsi.testen,
      testrst    => ahbsi.testrst
    );






  tbi.addr   <= itraceo.taddr;
  tbi.data   <= itraceo.idata;
  tbi.enable <= itraceo.enable;
  tbi.write  <= itraceo.write;

  -- Pipeline ---------------------------------------------------------------
  iu0 : iunv
    generic map (
      hindex        => hindex,
      fabtech       => fabtech,
      memtech       => memtech,
      -- Core
      physaddr      => physaddr,
      addr_bits     => addr_bits,
      rstaddr       => rstaddr,
      perf_cnts     => perf_cnts,
      perf_evts     => perf_evts,
      perf_bits     => perf_bits,
      illegalTval0  => illegalTval0,
      no_muladd     => no_muladd,
      single_issue  => single_issue,
      -- Caches
      iways         => iways,
      dways         => dways,
      dlinesize     => dlinesize,
      itcmen        => itcmen,
      dtcmen        => dtcmen,
      -- MMU
      mmuen         => mmuen,
      riscv_mmu     => actual_riscv_mmu,
      pmp_no_tor    => pmp_no_tor,
      pmp_entries   => pmp_entries,
      pmp_g         => pmp_g,
      pma_entries   => pma_entries,
      pma_masked    => pma_masked,
      asidlen       => asidlen,
      vmidlen       => vmidlen,
      -- Interrupts
      imsic         => imsic,
      -- RNMI
      rnmi_iaddr    => rnmi_iaddr,
      rnmi_xaddr    => rnmi_xaddr,
      -- Extensions
      ext_noelv     => ext_noelv,
      ext_noelvalu  => ext_noelvalu,
      ext_m         => ext_m,
      ext_a         => ext_a,
      ext_c         => ext_c,
      ext_h         => ext_h,
      ext_zcb       => ext_zcb,
      ext_zba       => ext_zba,
      ext_zbb       => ext_zbb,
      ext_zbc       => ext_zbc,
      ext_zbs       => ext_zbs,
      ext_zbkb      => ext_zbkb,
      ext_zbkc      => ext_zbkc,
      ext_zbkx      => ext_zbkx,
      ext_sscofpmf  => ext_sscofpmf,
      ext_sstc      => ext_sstc,
      ext_smaia     => ext_smaia,
      ext_ssaia     => ext_ssaia,
      ext_smstateen => ext_smstateen,
      ext_smrnmi    => ext_smrnmi,
      ext_ssdbltrp  => ext_ssdbltrp,
      ext_smdbltrp  => ext_smdbltrp,
      ext_sddbltrp  => ext_sddbltrp,
      ext_smepmp    => ext_smepmp,
      ext_zicbom    => ext_zicbom,
      ext_zicond    => ext_zicond,
      ext_zimop     => ext_zimop,
      ext_zcmop     => ext_zcmop,
      ext_zicfiss   => ext_zicfiss,
      ext_zicfilp   => ext_zicfilp,
      ext_svinval   => ext_svinval,
      ext_zfa       => actual_zfa,
      ext_zfh       => actual_zfh,
      ext_zfhmin    => actual_zfhmin,
      ext_zfbfmin   => actual_zfbfmin,
      mode_s        => mode_s,
      mode_u        => mode_u,
      dmen          => dmen,
      fpulen        => fpulen,
      fpuconf       => fpuconf,
      trigger       => trigger,
      -- Advanced Features
      late_branch   => late_branch,
      late_alu      => late_alu,
      ras           => ras,
      -- Misc
      pbaddr        => pbaddr,
      tbuf          => tbuf,
      scantest      => scantest,
      endian        => endian
      )
    port map (
      clk           => gclk,
      rstn          => rstx,
      holdn         => holdn,
      ici           => ici,
      ico           => ico,
      bhti          => bhti,
      bhto          => bhto,
      btbi          => btbi,
      btbo          => btbo,
      rasi          => rasi,
      raso          => raso,
      dci           => dci,
      dco           => dco,
      rfi           => rfi,
      rfo           => rfo,
      imsici        => imsici,
      imsico        => imsico,
      irqi          => irqi,
      irqo          => irqo,
      nirqi         => nirqi,
      dbgi          => dbgi,
      dbgo          => dbgo,
      muli          => muli,
      mulo          => mulo,
      divi          => divi,
      divo          => divo,
      fpui          => fpi,
      fpuia         => fpia,
      fpuo          => fpo,
      fpuoa         => fpoa,
      cnt           => iu_cnt,
      itracei       => itracei,
      itraceo       => itraceo,
      pma_addr      => pma_addr,
      pma_data      => pma_data,
      csr_mmu       => csr_mmu,
      mmu_csr       => mmu_csr,
      cap           => capability,
      perf          => c_perf,
      tbo           => tbo,
      eto           => etrace,
      sclk          => clk,
      pwrd          => pwrd,
      testen        => ahbsi.testen,
      testrst       => ahbsi.testrst
      );

  -- Mul/Div Unit -----------------------------------------------------------
  mgen : if ext_m = 1 generate
    mul0 : mul64
      generic map (
        fabtech     => fabtech,
        arch        => mularch,
        split       => mulconf_int,
        scantest    => scantest
        )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        ctrl        => muli.ctrl,
        op1         => muli.op1,
        op2         => muli.op2,
        nready      => mulo.nready,
        mresult     => mulo.result,
        testen      => ahbsi.testen,
        testrst     => ahbsi.testrst
        );

    mulo.icc <= (others => '0');

    div0 : div64
      generic map (
        fabtech     => fabtech,
        scantest    => scantest,
        hiperf      => div_hiperf,
        small       => div_small
        )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        divi        => divi,
        divo        => divo,
        testen      => ahbsi.testen,
        testrst     => ahbsi.testrst
        );
  end generate; -- mgen

  nomgen : if ext_m = 0 generate
    divo  <= div_out_none;
    mulo  <= mul_out_none;
  end generate;



  -- Cache Controller -----------------------------------------------------------
  mmu0 : cctrlnv
    generic map  (
      hindex        => hindex,
      -- Core
      physaddr      => physaddr,
      -- Caches
      iways         => iways,
      ilinesize     => ilinesize,
      iwaysize      => iwaysize,
      dways         => dways,
      dlinesize     => dlinesize,
      dwaysize      => dwaysize,
      dtagconf      => dtagconf,
      dusebw        => dusebw,
      itcmen        => itcmen,
      itcmabits     => itcmabits,
      dtcmen        => dtcmen,
      dtcmabits     => dtcmabits,
      -- MMU
      itlbnum       => itlbnum,
      dtlbnum       => dtlbnum,
      htlbnum       => htlbnum,
      riscv_mmu     => actual_riscv_mmu,
      pmp_no_tor    => pmp_no_tor,
      pmp_entries   => pmp_entries,
      pmp_g         => pmp_g,
      pma_entries   => pma_entries,
      pma_masked    => pma_masked,
      asidlen       => asidlen,
      vmidlen       => vmidlen,
      ext_noelv     => ext_noelv,
      ext_a         => ext_a,
      ext_h         => ext_h,
      ext_smepmp    => ext_smepmp,
      ext_zicbom    => ext_zicbom,
      ext_svpbmt    => ext_svpbmt,
      ext_zicfiss   => ext_zicfiss,
      tlb_pmp       => tlb_pmp,
      -- Misc
      cached        => cached,
      wbmask        => wbmask,
      busw          => busw,
      cdataw        => cdataw,
      icrepl        => tlbforepl,
      dcrepl        => tlbforepl,
      hrepl         => tlbforepl,
      mmuen         => mmuen,
      endian        => endian
      )
    port map (
      rst           => rstx,
      clk           => gclk,
      ici           => ici,
      ico           => ico,
      dci           => dci,
      dco           => dco,
      ahbi          => ahbi,
      ahbo          => ahbo,
      ahbsi         => ahbsi,
      ahbso         => ahbso,
      crami         => crami,
      cramo         => cramo,
      sclk          => clk,
      csro          => csr_mmu,
      csri          => mmu_csr,
      fpc_mosi      => fpc_mosi,
      fpc_miso      => fpc_miso,
      c2c_mosi      => c2c_mosi,
      c2c_miso      => c2c_miso,
      freeze        => dbgi.freeze,
      bootword      => zerow,
      smpflush      => zerow(1 downto 0),
      --fpuholdn      => fpo.holdn,
      perf          => c_perf
      );

  -- Unused
  fpc_miso       <= nv_intreg_miso_none;
  c2c_miso       <= nv_intreg_miso_none;

  cnt.icnt       <= iu_cnt.icnt;
  cnt.icmiss     <= c_perf(0);
  cnt.itlbmiss   <= c_perf(1);
  cnt.dcmiss     <= c_perf(2);
  cnt.dtlbmiss   <= c_perf(3);
  cnt.bpmiss     <= iu_cnt.bpmiss;
  cnt.hold       <= iu_cnt.hold;
  cnt.hold_issue <= iu_cnt.hold_issue;
  cnt.branch     <= iu_cnt.branch;

  -- Branch History Table ---------------------------------------------------
  bht0 : bhtnv
    generic map (
      tech              => memtech,
      nentries          => bhtentries,
      hlength           => bhtlength,
      predictor         => predictor,
      ext_c             => ext_c,
      dissue            => 1 - single_issue,
      testen            => scantest
      )
    port map (
      clk               => gclk,
      rstn              => rstx,
      bhti              => bhti,
      bhto              => bhto,
      holdn             => holdn,
      testin            => ahbi.testin
    );

  -- Branch Target Buffer ----------------------------------------------------
  btb0 : btbdmnv
    generic map (
      nentries          => btbentries,
      pcbits            => pcaddr_bits,
      dissue            => 1 - single_issue
      )
    port map (
      clk               => gclk,
      rstn              => rstx,
      btbi              => btbi,
      btbo              => btbo
    );

  -- Return Address Stack ----------------------------------------------------
  rasgen : if ras >= 1 generate
    ras0 : rasnv
      generic map (
        depth             => 8,
        pcbits            => pcaddr_bits
      )
      port map (
        clk               => gclk,
        rstn              => rstx,
        rasi              => rasi,
        raso              => raso
      );
  end generate;

  -- IU Register File ----------------------------------------------------------
  ramrf : if (rfconf mod 16) = 0 generate
    rf0 : regfile64sramnv
      generic map (
        tech            => memtech,
        dissue          => 1 - single_issue,
        testen          => scantest
        )
      port map (
        clk             => gclk,
        rstn            => rstx,
        rdhold          => rfi.rdhold,
        waddr1          => rfi.waddr1,
        wdata1          => rfi.wdata1,
        we1             => rfi.wen1,
        waddr2          => rfi.waddr2,
        wdata2          => rfi.wdata2,
        we2             => rfi.wen2,
        raddr1          => rfi.raddr1,
        re1             => rfi.ren1,
        rdata1          => rfo.data1,
        raddr2          => rfi.raddr2,
        re2             => rfi.ren2,
        rdata2          => rfo.data2,
        raddr3          => rfi.raddr3,
        re3             => rfi.ren3,
        rdata3          => rfo.data3,
        raddr4          => rfi.raddr4,
        re4             => rfi.ren4,
        rdata4          => rfo.data4,
        testin          => ahbi.testin
        );
  end generate;

  dffrf : if (rfconf mod 16) = 1 generate
  begin
    rf0 : regfile64dffnv
      generic map (
        tech            => memtech,
        wrfst           => WRT
        )
      port map (
        clk             => gclk,
        rstn            => rstx,
        rdhold          => rfi.rdhold,
        waddr1          => rfi.waddr1,
        wdata1          => rfi.wdata1,
        we1             => rfi.wen1,
        waddr2          => rfi.waddr2,
        wdata2          => rfi.wdata2,
        we2             => rfi.wen2,
        raddr1          => rfi.raddr1,
        re1             => rfi.ren1,
        rdata1          => rfo.data1,
        raddr2          => rfi.raddr2,
        re2             => rfi.ren2,
        rdata2          => rfo.data2,
        raddr3          => rfi.raddr3,
        re3             => rfi.ren3,
        rdata3          => rfo.data3,
        raddr4          => rfi.raddr4,
        re4             => rfi.ren4,
        rdata4          => rfo.data4
        );

  end generate;

  -- FPU Register File ----------------------------------------------------------
  fpu_regs : if fpulen /= 0 generate
   ramrff : if (rfconf mod 16) = 0 generate
    rf1 : regfile64sramnv
      generic map (
        tech            => memtech,
        reg0write       => 1,
        testen          => scantest
        )
      port map (
        clk             => gclk,
        rstn            => rstx,
        rdhold          => '0',
        waddr1          => fpo.rd,
        wdata1          => rff_fd,
        we1             => rff_wen,
        waddr2          => fpo.rd,      -- Dummy
        wdata2          => rff_fd,      -- Dummy
        we2             => '0',
        raddr1          => rff_rs1,
        re1             => rff_ren(1),
        rdata1          => fs1_data,
        raddr2          => rff_rs2,
        re2             => rff_ren(2),
        rdata2          => fs2_data,
        raddr3          => rff_rs3,
        re3             => rff_ren(3),
        rdata3          => fs3_data,
        raddr4          => rff_rs3,     -- Dummy
        re4             => '0',
        rdata4          => rff_rdummy,  -- Dummy
        testin          => ahbi.testin
        );
   end generate;

   dffrff : if (rfconf mod 16) = 1 generate
    rf1 : regfile64dffnv
      generic map (
        tech            => memtech,
        wrfst           => WRT,
        reg0write       => 1,
        -- GHDL+Verilator circular logic fix,
        -- together with appropriate FPU changes.
        forward       => 0
        )
      port map (
        clk             => gclk,
        rstn            => rstx,
        rdhold          => '0',
        waddr1          => fpo.rd,
        wdata1          => rff_fd,
        we1             => rff_wen,
        waddr2          => fpo.rd,      -- Dummy
        wdata2          => rff_fd,      -- Dummy
        we2             => '0',
        raddr1          => rff_rs1,
        re1             => rff_ren(1),
        rdata1          => fs1_data,
        raddr2          => rff_rs2,
        re2             => rff_ren(2),
        rdata2          => fs2_data,
        raddr3          => rff_rs3,
        re3             => rff_ren(3),
        rdata3          => fs3_data,
        raddr4          => rff_rs3,     -- Dummy
        re4             => '0',
        rdata4          => rff_rdummy   -- Dummy
        );

    end generate;
  end generate;


  -- L1 Caches -----------------------------------------------------------------

  cmem1 : cachememnv
    generic map (
      tech      => MEMTECH_MOD,
      iways     => iways,
      ilinesize => ilinesize,
      iidxwidth => iidxwidth,
      itagwidth => itagwidth,
      itcmen    => itcmen,
      itcmabits => itcmabits,
      dways     => dways,
      dlinesize => dlinesize,
      didxwidth => didxwidth,
      dtagwidth => dtagwidth,
      dtagconf  => dtagconf,
      dusebw    => dusebw,
      dtcmen    => dtcmen,
      dtcmabits => dtcmabits,
      testen    => scantest
      )
    port map (
      rstn   => rstx,
      clk    => gclk,
      sclk   => clk,
      crami  => crami,
      cramo  => cramo,
      testin => ahbi.testin
      );

  -- Instruction Buffer -----------------------------------------------------
  tbmem_gen : if (tbuf /= 0) generate
    tbmem0 : tbufmemnv
      generic map (
        tech    => MEMTECH_MOD,
        tbuf    => tbuf,
        dwidth  => cdataw,
        testen  => scantest,
        proc    => 1
      )
      port map (
        clk      => gclk,
        trace_in => tbi,
        trace_out=> tbo,
        testin   => ahbi.testin
      );
  end generate;

  notbmem_gen : if (tbuf = 0) generate
    tbo       <= nv_trace_out_type_none;
  end generate;

  -- FPU Unit ---------------------------------------------------------------
  nofpu_gen : if (fpulen = 0) generate
    fpo         <= fpu5_out_none;
  end generate;

  sp_fpu: if fpulen = 32 generate
    fs1_word64 <= (not zerow) & fs1_data;
    fs2_word64 <= (not zerow) & fs2_data;
    fs3_word64 <= (not zerow) & fs3_data;
  end generate;

  dp_fpu: if fpulen = 64 generate
    fs1_word64 <= fs1_data;
    fs2_word64 <= fs2_data;
    fs3_word64 <= fs3_data;
  end generate;

  fpu_gen : if fpulen /= 0 and hw_fpu = 1 generate
    nano : nanofpunv
      generic map (
        fpulen    => fpulen,
        no_muladd => no_muladd
      )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        fpi         => fpi,
        fpia        => fpia,
        fpo         => fpo,
        fpoa        => fpoa,
        rs1         => rff_rs1,
        rs2         => rff_rs2,
        rs3         => rff_rs3,
        ren         => rff_ren,
        s1          => fs1_word64,
        s2          => fs2_word64,
        s3          => fs3_word64
      );

    rff_fd        <= fpo.data(rff_fd'range);
    rff_wen       <= fpo.wen
                     ;
  end generate;

  pfpu_gen : if fpulen /= 0 and hw_fpu = 3 generate
    piped : pipefpunv
      generic map (
        fpulen      => fpulen,
        ext_zfa     => ext_zfa,
        ext_zfh     => ext_zfh,
        ext_zfhmin  => ext_zfhmin,
        ext_zfbfmin => ext_zfbfmin,
        mulconf     => mulconf_fpu
      )
      port map (
        clk         => gclk,
        rstn        => rstx,
        holdn       => holdn,
        fpi         => fpi,
        fpia        => fpia,
        fpo         => fpo,
        fpoa        => fpoa,
        rs1         => rff_rs1,
        rs2         => rff_rs2,
        rs3         => rff_rs3,
        ren         => rff_ren,
        s1          => fs1_word64,
        s2          => fs2_word64,
        s3          => fs3_word64
      );

    rff_fd   <= fpo.data(rff_fd'range);
    rff_wen  <= fpo.wen
                ;
  end generate;


  -- 1-clock reset delay
  rstreg : process(clk)
  begin
    if rising_edge(clk) then
      rst <= rstn and (not dbgi.reset);
    end if;
  end process;

  rstx <= rst and rstn when ASYNC_RESET else rst;

-- pragma translate_off
  assert endian = 1
    report "NOEL-V: Only little endian is supported"
    severity warning;
  assert ( ((endian /= 0) = (ahbi.endian  /= '0') or ahbi.endian  = 'U') and
           ((endian /= 0) = (ahbsi.endian /= '0') or ahbsi.endian = 'U') )
    report "NOEL-V: Mismatch between endianness generic and AHB bus endianness signal"
    severity warning;
-- pragma translate_on

end;
