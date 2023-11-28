------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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
-- Package: 	mmucacheconfig
-- File:	mmuconfig.vhd
-- Author:	Konrad Eisele, Jiri Gaisler, Johan Klockars Cobham Gaisler AB
-- Description:	MMU types and constants
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.log2;
use grlib.stdlib.notx;
use grlib.stdlib.setx;
use grlib.amba.hsize_word;
use grlib.amba.hsize_dword;
library gaisler;
use gaisler.utilnv.all_0;
use gaisler.utilnv.u2i;
use gaisler.utilnv.cond;

package mmucacheconfig is

constant M_CTX_SZ       : integer := 8;
constant M_ENT_MAX      : integer := 64;
constant XM_ENT_MAX_LOG : integer := log2(M_ENT_MAX);
constant M_ENT_MAX_LOG  : integer := XM_ENT_MAX_LOG;

subtype ctxword is std_logic_vector(M_CTX_SZ - 1 downto 0);

type mmu_idcache is (id_icache, id_dcache);

--type va_type is (sparc, sv32, sv39, sv48);
subtype va_type is integer range 0 to 3;
constant sparc : integer := 0;
constant sv32  : integer := 1;
constant sv39  : integer := 2;
constant sv48  : integer := 3;

-- Virtual address bits of the various map levels.
type va_bits is array (integer range <>) of integer;

-- Note that M mode uses physical addresses unless MPRV.
constant mstatus_mxr  : integer := 19;  -- 1 - allow read from X-only pages
constant mstatus_sum  : integer := 18;  -- 1 - allow U mode data page access from S mode
constant mstatus_mprv : integer := 17;  -- 1 - data access according to MPP
constant mstatus_mpp  : std_logic_vector(12 downto 11) := "00"; -- 00 U, 01 S, 11 M

subtype page_offset is std_logic_vector(11 downto 0);

-- ##############################################################
--     Sv32 virtual address [riscv-privileged: p.68, 4.3.1, Figure 4.13]
--     (only available for RISC-V32)
--           10            10            12
--     +------------+-------------+---------------+
--  a) |  INDEX2/1  |   INDEX3/0  |    OFFSET     |
--     +------------+-------------+---------------+
--      31        22 21         12 11            0
--
--
--     Sv39 virtual address [riscv-privileged: p.68, 4.3.1, Figure 4.13]
--     (only available for RISC-V64)
--          9          9          9            12
--     +----------+----------+----------+---------------+
--  b) | INDEX1/2 | INDEX2/1 | INDEX3/0 |    OFFSET     |
--     +----------+----------+----------+---------------+
--      38      30 29      21 20      12 11            0
--
--
--     Sv48 virtual address [riscv-privileged: p.68, 4.3.1, Figure 4.13]
--     (only available for RISC-V64)
--          9          9          9          9            12
--     +----------+----------+----------+----------+---------------+
--  c) |  INDEX3  | INDEX1/2 | INDEX2/1 | INDEX3/0 |    OFFSET     |
--     +----------+----------+----------+----------+---------------+
--      47      39 38      30 29      21 20      12 11            0

-- Note that RISC-V counts indices from 0, starting at low bits,
-- while Sparc counts from 1, starting at high bits (at least in the LEON MMU code).

function va(what : va_type) return std_logic_vector;
function va_msb(what : va_type) return integer;
function vpn(what : va_type) return std_logic_vector;
function pa(what : va_type) return std_logic_vector;
function pa_msb(what : va_type) return integer;
function ga(what : va_type) return std_logic_vector;
function ga_msb(what : va_type) return integer;
function ppn(what : va_type) return std_logic_vector;
function pte_hsize(what : va_type) return std_logic_vector;
function va_size(what : va_type) return integer;
function va_size(what : va_type; index : integer) return integer;
function is_riscv(what : va_type) return boolean;
function is_pt_invalid(what : va_type; data : std_logic_vector) return boolean;
function is_valid_pte(what : va_type;
                      data : std_logic_vector; mask : std_logic_vector;
                      physaddr : integer range 32 to 56) return boolean;
function is_pte(what : va_type; data : std_logic_vector) return boolean;
function is_valid_ptd(what : va_type;
                      data : std_logic_vector;
                      physaddr : integer range 32 to 56) return boolean;
function is_ptd(what : va_type; data : std_logic_vector) return boolean;
function satp_base(what : va_type; satp : std_logic_vector) return std_logic_vector;
function satp_asid(what : va_type; satp : std_logic_vector) return std_logic_vector;
function satp_mode(what : va_type; satp : std_logic_vector) return integer;
function pt_addr(what : va_type; data  : std_logic_vector; mask : std_logic_vector;
                 vaddr : std_logic_vector; code : std_logic_vector) return std_logic_vector;
function pte_paddr(what : va_type; data : std_logic_vector) return std_logic_vector;
function pte_cached(what : va_type; data : std_logic_vector) return std_logic;
procedure pte_mark_modacc(what   : va_type;
                          data   : inout std_logic_vector; modified   : std_logic;
                          needwb : out std_logic;          needwblock : out std_logic);
procedure virtual2physical(what : va_type; vaddr : std_logic_vector; mask : std_logic_vector;
                           paddr : inout std_logic_vector);
function ft_acc_resolve(what : va_type; at : std_logic_vector(2 downto 0);
                        data : std_logic_vector) return std_logic_vector;


--     Sv32 Supervisor Address Translation and Protection (satp) Register [riscv-privileged: p.63, 4.1.12, Figure 4.11]
--        1       9                    22
--     +------+--------+---------------------------------+
--     | MODE |  ASID  |   PPN (of start of page table)  |
--     +------+--------+---------------------------------+
--        31    30  22   21                            0
--
-- ##############################################################
--     Sv39/48 Supervisor Address Translation and Protection (satp) Register [riscv-privileged: p.63, 4.1.12, Figure 4.12]
--         4        16                   44
--     +--------+--------+---------------------------------+
--     |  MODE  |  ASID  |   PPN (of start of page table)  |
--     +--------+--------+---------------------------------+
--       63  60   59  44   43                            0
--
--  MODE : 0        no translation
--         1        Sv32 page-based 32-bit virtual addressing, reserved in 64 bit mode
--         2 - 7    reserved
--         8        Sv39 page-based 39-bit virtual addressing
--         9        Sv48 page-based 48-bit virtual addressing
--         10       reserved for Sv57 page-based 57-bit virtual addressing
--         11       reserved for Sv64 page-based 64-bit virtual addressing
--         12 - 15  reserved
--  ASID : Address Space Identifier, up to 9/16 (RISC-V32/64) bits (non-implemented read as 0)

--
--     Sv32 PAGE TABE ENTRY (PTE) [riscv-privileged: p.68, 4.3.1, Figure 4.15]
--          12         10       2     1   1   1   1   1   1   1   1
--     +----------+----------+------+---+---+---+---+---+---+---+---+
--     |   PPN1   |   PPN0   | RSW  | D | A | G | U | X | W | R | V |
--     +----------+----------+------+---+---+---+---+---+---+---+---+
--       31    20   19    10   9  8   7   6   5   4   3   2   1   0
--
--
--     Sv39 PAGE TABE ENTRY (PTE) [riscv-privileged: p.72, 4.3.1, Figure 4.18]
--        1       2          7          26         9          9         2     1   1   1   1   1   1   1   1
--     +-----+----------+----------+----------+----------+----------+-------+---+---+---+---+---+---+---+---+
--     |  N  |   PBMT   | Reserved |   PPN2   |   PPN1   |   PPN0   |  RSW  | D | A | G | U | X | W | R | V |
--     +-----+----------+----------+----------+----------+----------+-------+---+---+---+---+---+---+---+---+
--        63   62    61   60    54   53    28   27    19   18    10   9   8   7   6   5   4   3   2   1   0
--
--
--     Sv48 PAGE TABE ENTRY (PTE) [riscv-privileged: p.72, 4.3.1, Figure 4.18]
--       1        2          7          17         9          9          9         2     1   1   1   1   1   1   1   1
--     +-----+----------+----------+----------+----------+----------+----------+-------+---+---+---+---+---+---+---+---+
--     |  N  |   PBMT   | Reserved |   PPN3   |   PPN2   |   PPN1   |   PPN0   |  RSW  | D | A | G | U | X | W | R | V |
--     +-----+----------+----------+----------+----------+----------+----------+-------+---+---+---+---+---+---+---+---+
--        63   62    61   60    54   53    37   36    28   27    19   18    10   9   8   7   6   5   4   3   2   1   0
--
--  N    : NAPOT (Svnapot)
--  PBMT : Page-Based Memory Types (Svpbmt)
--  PPNx : Physical Page Number
--  RSW  : Reserved for Software
--  V    : valid (rest don't care if 0)
--  R    : readble    (when RWX == "000", pointer to next level of table)
--  W    : writable   (RWX == "010" | "110" are reserved for future use)
--  X    : executable
--  U    : user mode accessible
--  G    : global mapping
--  A    : accessed (since cleared)
--  D    : written  (since cleared)


constant rv_pte_n    : integer := 63;
constant rv_pte_pbmt : std_logic_vector(62 downto 61) := "00";
constant rv_pte_resv : std_logic_vector(60 downto 54) := "0000000";
constant rv_pte_rsw  : std_logic_vector( 9 downto  8) := "00";
constant rv_pte_xwr  : std_logic_vector( 3 downto  1) := "000";
constant rv_pte_v    : integer := 0;  -- valid (rest don't care if 0)
constant rv_pte_r    : integer := 1;  -- readable (RWX == "000" - pointer to next level of table)
constant rv_pte_w    : integer := 2;  -- writable (RWX == "010" | "110" reserved)
constant rv_pte_x    : integer := 3;  -- executable
constant rv_pte_u    : integer := 4;  -- user mode accessible
constant rv_pte_g    : integer := 5;  -- global mapping
constant rv_pte_a    : integer := 6;  -- accessed (since cleared)
constant rv_pte_d    : integer := 7;  -- written (since cleared)



-- ##############################################################
--     1.0 virtual address [sparc V8: p.243,Appx.H,Figure H-4]
--     +--------+--------+--------+---------------+
--  a) | INDEX1 | INDEX2 | INDEX3 |    OFFSET     |
--     +--------+--------+--------+---------------+
--      31    24 23    18 17    12 11            0

-- 1 - bits 31:24, '1' for 16MiB or smaller,'0' for 4 GiB
-- 2 - bits 23:18, '1' for 256KiB or smaller, '0' for 512KiB+
-- 3 - bits 17:12, '1' for 4 KiB, '0' for 8KiB+


-- ##############################################################
--     2.0 PAGE TABE DESCRIPTOR (PTD) [sparc V8: p.247,Appx.H,Figure H-7]
--
--     +-------------------------------------------------+---+---+
--     |    Page Table Pointer (PTP)                     | 0 | 0 |
--     +-------------------------------------------------+---+---+
--      31                                              2  1   0
--
--     2.1 PAGE TABE ENTRY (PTE) [sparc V8: p.247,Appx.H,Figure H-8]
--
--     +-----------------------------+---+---+---+-----------+---+
--     |Physical Page Number (PPN)   | C | M | R |     ACC   | ET|
--     +-----------------------------+---+---+---+-----------+---+
--      31                          8  7   6   5  4         2 1 0
--

constant PTE_C     : integer := 7;    -- PTE: Cacheable bit
constant PTE_M     : integer := 6;    -- PTE: Modified bit
constant PTE_R     : integer := 5;    -- PTE: Reference Bit - a "1" indicates an PTE

constant PTE_ACC_U : integer := 4;    -- PTE: Access field
constant PTE_ACC_D : integer := 2;
constant ACC_W     : integer := 2;    -- PTE::ACC : write permission
constant ACC_E     : integer := 3;    -- PTE::ACC : exec permission
constant ACC_SU    : integer := 4;    -- PTE::ACC : privileged

constant PT_ET_U   :  integer := 1;      -- PTD/PTE: PTE Type
constant PT_ET_D   : integer  := 0;

constant ET_INV    : std_logic_vector(1 downto 0) := "00";
constant ET_PTD    : std_logic_vector(1 downto 0) := "01";
constant ET_PTE    : std_logic_vector(1 downto 0) := "10";
constant ET_RVD    : std_logic_vector(1 downto 0) := "11";

end mmucacheconfig;


package body mmucacheconfig is

  function va(what : va_type) return std_logic_vector is
    variable VA_SPARC : std_logic_vector(31 downto  0) := (others => '0');
    variable VA_SV32  : std_logic_vector(31 downto  0) := (others => '0');
    variable VA_SV39  : std_logic_vector(38 downto  0) := (others => '0');
    variable VA_SV48  : std_logic_vector(47 downto  0) := (others => '0');
  begin
    case what is
    when sv32   => return VA_SV32;
    when sv39   => return VA_SV39;
    when sv48   => return VA_SV48;
    when others => return VA_SPARC;
    end case;
  end;

  function va_msb(what : va_type) return integer is
  begin
    case what is
    when sv32   => return 31;
    when sv39   => return 38;
    when sv48   => return 47;
    when others => return 31;
    end case;
  end;

  function vpn(what : va_type) return std_logic_vector is
    constant va_tmp : std_logic_vector                        := va(what);  -- constant
    variable tmp    : std_logic_vector(va_tmp'high downto 12) := (others => '0');
  begin
    return tmp;
  end;

  function ga(what : va_type) return std_logic_vector is
    variable GA_SPARC : std_logic_vector(31 downto  0) := (others => '0');
    variable GA_SV32  : std_logic_vector(33 downto  0) := (others => '0');
    variable GA_SV39  : std_logic_vector(40 downto  0) := (others => '0');
    variable GA_SV48  : std_logic_vector(49 downto  0) := (others => '0');
  begin
    case what is
    when sv32   => return GA_SV32;
    when sv39   => return GA_SV39;
    when sv48   => return GA_SV48;
    when others => return GA_SPARC;
    end case;
  end;

  function ga_msb(what : va_type) return integer is
  begin
    case what is
    when sv32   => return 33;
    when sv39   => return 40;
    when sv48   => return 49;
    when others => return 31;
    end case;
  end;

  function pa(what : va_type) return std_logic_vector is
    variable PA_SPARC : std_logic_vector(31 downto  0) := (others => '0');
    variable PA_SV32  : std_logic_vector(33 downto  0) := (others => '0');
    variable PA_SV39  : std_logic_vector(55 downto  0) := (others => '0');
    variable PA_SV48  : std_logic_vector(55 downto  0) := (others => '0');
  begin
    case what is
    when sv32   => return PA_SV32;
    when sv39   => return PA_SV39;
    when sv48   => return PA_SV48;
    when others => return PA_SPARC;
    end case;
  end;

  function pa_msb(what : va_type) return integer is
  begin
    case what is
    when sv32   => return 33;
    when sv39   => return 55;
    when sv48   => return 55;
    when others => return 31;
    end case;
  end;

  function ppn(what : va_type) return std_logic_vector is
    constant pa_tmp : std_logic_vector                        := pa(what);  -- constant
    variable tmp    : std_logic_vector(pa_tmp'high downto 12) := (others => '0');
  begin
    return tmp;
  end;

  function pte_hsize(what : va_type) return std_logic_vector is
    variable HSIZE_SPARC : std_logic_vector(2 downto 0) := HSIZE_WORD;
    variable HSIZE_SV32  : std_logic_vector(2 downto 0) := HSIZE_WORD;
    variable HSIZE_SV39  : std_logic_vector(2 downto 0) := HSIZE_DWORD;
    variable HSIZE_SV48  : std_logic_vector(2 downto 0) := HSIZE_DWORD;
  begin
    case what is
    when sv32   => return HSIZE_SV32;
    when sv39   => return HSIZE_SV39;
    when sv48   => return HSIZE_SV48;
    when others => return HSIZE_SPARC;
    end case;
  end;

  -- Bits per PTD, from MSB:s (low index) to LSB:s.
  -- Smallest pages are 4 kbyte, ie 12 bits.
  constant SZ_SPARC : va_bits(1 to 3) := (8, 6, 6);    -- 8 + 6 + 6     + 12 = 32 bits
  constant SZ_SV32  : va_bits(1 to 2) := (10, 10);     -- 10 + 10       + 12 = 32
  constant SZ_SV39  : va_bits(1 to 3) := (9, 9, 9);    -- 9 + 9 + 9     + 12 = 39
  constant SZ_SV48  : va_bits(1 to 4) := (9, 9, 9, 9); -- 9 + 9 + 9 + 9 + 12 = 48

  -- Return number of PTD:s
  function va_size(what : va_type) return integer is
  begin
    case what is
    when sv32   => return SZ_SV32'length;
    when sv39   => return SZ_SV39'length;
    when sv48   => return SZ_SV48'length;
    when others => return SZ_SPARC'length;
    end case;
  end;

  -- Return number of bits for specified PTD
  function va_size(what : va_type; index : integer) return integer is
  begin
    case what is
    when sv32   => return SZ_SV32(index);
    when sv39   => return SZ_SV39(index);
    when sv48   => return SZ_SV48(index);
    when others => return SZ_SPARC(index);
    end case;
  end;

  function is_riscv(what : va_type) return boolean is
  begin
    return what /= sparc;
  end;

  function is_pt_invalid(what : va_type;
                         data : std_logic_vector) return boolean is
  begin
    if what = sparc then
      return data(PT_ET_U downto PT_ET_D) = ET_INV;
    else
      return data(rv_pte_v) = '0';
    end if;
  end;

  function is_valid_pte(what : va_type;
                        data : std_logic_vector; mask : std_logic_vector;
                        physaddr : integer range 32 to 56) return boolean is
  begin
    if what = sparc then
      return true;
    else
      if what = sv32 then
        if mask(mask'high) = '0' and not all_0(data(19 downto 10)) then
          return false;
        end if;
        if mask(mask'high - 1) = '0' and not all_0(data(31 downto 20)) then
          return false;
        end if;
      else
        if mask(mask'high) = '0' and not all_0(data(18 downto 10)) then
          return false;
        end if;
        if mask(mask'high - 1) = '0' and not all_0(data(27 downto 19)) then
          return false;
        end if;
        if what = sv48 then
          if mask(mask'high - 2) = '0' and not all_0(data(36 downto 28)) then
            return false;
          end if;
        end if;
      end if;

      -- Reserved top bits must be zero.
      if not all_0(data(rv_pte_resv'range)) then
        return false;
      end if;

      -- PBMT 11 is reserved.
      if data(rv_pte_pbmt'range) = "11" then
        return false;
      end if;

      -- N (Svnapot) is not yet supported.
      if data(rv_pte_n) /= '0' then
        return false;
      end if;

      -- Do not allow addressing outside the specified physical address space.
      if not all_0(data(53 downto physaddr - 12 + 10)) then
        return false;
      end if;
    end if;

    return true;
  end;

  function is_pte(what : va_type;
                  data : std_logic_vector) return boolean is
  begin
    if what = sparc then
      return data(PT_ET_U downto PT_ET_D) = ET_PTE;
    else
      -- PTE is marked by not R=0, W=0, X=0. Must also be valid.
      return data(rv_pte_v) = '1' and data(rv_pte_xwr'range) /= "000";
    end if;
  end;

  function is_valid_ptd(what : va_type;
                        data : std_logic_vector;
                        physaddr : integer range 32 to 56) return boolean is
  begin
    if what = sparc then
      return true;
    else
      -- Reserved top bits must be zero.
      if not all_0(data(rv_pte_resv'range)) then
        return false;
      end if;

      -- PBMT is reserved.
      if data(rv_pte_pbmt'range) /= "00" then
        return false;
      end if;

      -- N is assumed to be reserved (the standar does not appear to say).
      if data(rv_pte_n) /= '0' then
        return false;
      end if;

      -- Do not allow addressing outside the specified physical address space.
      if not all_0(data(53 downto physaddr - 12 + 10)) then
        return false;
      end if;


      -- PTD also has D, A and U reserved, so enforce 0 (Spike does).
      if data(rv_pte_d) = '1' or data(rv_pte_a) = '1' or data(rv_pte_u) = '1' then
        return false;
      end if;
    end if;

    return true;
  end;

  function is_ptd(what : va_type;
                  data : std_logic_vector) return boolean is
  begin
    if what = sparc then
      return data(PT_ET_U downto PT_ET_D) = ET_PTD;
    else
      -- PTD is marked by R=0, W=0, X=0. Must also be valid.
      return data(rv_pte_v) = '1' and data(rv_pte_xwr'range) = "000";
    end if;
  end;

  function satp_base(what : va_type; satp : std_logic_vector) return std_logic_vector is
    --variable BASE_SV32  : std_logic_vector(21 downto 0)  := (others => '0');
    --variable BASE_SV39  : std_logic_vector(43 downto 0)  := (others => '0');
    --variable BASE_SV48  : std_logic_vector(43 downto 0)  := (others => '0');
    constant pa_tmp     : std_logic_vector               := pa(what);   -- constant
    constant ppn_sv32   : std_logic_vector               := ppn(sv32);  -- constant
    constant ppn_sv39   : std_logic_vector               := ppn(sv39);  -- constant
    constant ppn_sv48   : std_logic_vector               := ppn(sv48);  -- constant
    -- Non-constant
    variable base       : std_logic_vector(pa_tmp'range) := (others => '0');
  begin

    case what is
    when sv32   => -- base(ppn_sv32'range) := satp(BASE_SV32'range);
      for i in ppn_sv32'high downto ppn_sv32'low loop
        base(i) := satp(i - 12);
      end loop;
    when sv39   => -- base(ppn_sv39'range) := satp(BASE_SV39'range);
      for i in ppn_sv39'high downto ppn_sv39'low loop
        base(i) := satp(i - 12);
      end loop;
    when sv48   => -- base(ppn_sv48'range) := satp(BASE_SV48'range);
      for i in ppn_sv48'high downto ppn_sv48'low loop
        base(i) := satp(i - 12);
      end loop;
    when others => assert false
                     report "This function does not work for Sparc!"
                     severity failure;
    end case;

    return base;
  end;

  function satp_asid(what : va_type; satp : std_logic_vector) return std_logic_vector is
    variable ASID_SV32 : std_logic_vector(30 downto 22) := (others => '0');
    variable ASID_SV39 : std_logic_vector(59 downto 44) := (others => '0');
    variable ASID_SV48 : std_logic_vector(59 downto 44) := (others => '0');
    -- Non-constant
    variable asid32    : std_logic_vector(ASID_SV32'length - 1 downto 0);
    variable asid39    : std_logic_vector(ASID_SV39'length - 1 downto 0);
    variable asid48    : std_logic_vector(ASID_SV48'length - 1 downto 0);
  begin
    case what is
    when sv32   => asid32 := satp(ASID_SV32'range); return asid32;
    when sv39   => asid39 := satp(ASID_SV39'range); return asid39;
    when sv48   => asid48 := satp(ASID_SV48'range); return asid48;
    when others => assert false
                     report "This function does not work for Sparc!"
                     severity failure;
    end case;

    return "0";      -- Can never happen!
  end;

  function satp_mode(what : va_type; satp : std_logic_vector) return integer is
    variable MODE_RV32 : std_logic_vector(31 downto 31) := (others => '0');
    variable MODE_RV64 : std_logic_vector(63 downto 60) := (others => '0');
  begin
    case what is
    when sv32 =>
      if satp'length = 32 then
        return u2i(satp(MODE_RV32'range));
      else
        return u2i(satp(MODE_RV64'range));
      end if;
    when sv39 | sv48 =>
      assert satp'length = 64
        report "XLEN does not match requested MMU mode!"
        severity failure;
      return u2i(satp(MODE_RV64'range));
    when others => assert false
                     report "This function does not work for Sparc!"
                     severity failure;
    end case;

    return 0;        -- Can never happen!
  end;

  -- Calculates page table address.
  function pt_addr(what  : va_type;
                   data  : std_logic_vector; mask : std_logic_vector;
                   vaddr : std_logic_vector; code : std_logic_vector) return std_logic_vector is
    --constant pa_tmp : std_logic_vector               := pa(what);  -- constant
    variable index  : integer range 1 to mask'length := mask'length - u2i(code);
    variable lowbit : integer                        := 11 - va_size(what, index) + 1;
    -- Non-constant
    variable addr   : std_logic_vector(pa_msb(what) downto 0) := (others => '0');
    variable pos    : integer;
  begin
    if what = sparc then
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
      addr(addr'high downto 12) := data(addr'high - 12 + 10 downto 10);
      pos := 12;
      for i in mask'length downto 1 loop
        if i > u2i(code) then
          pos := pos + va_size(what, i);
        end if;
      end loop;


      -- DesignCompiler cannot count by itself...
--      addr(11 downto lowbit) := vaddr(pos - 1 downto pos - va_size(what)(index));
      if what = sv32 then
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

  function pte_paddr(what : va_type;
                     data : std_logic_vector) return std_logic_vector is
    constant pa_tmp : std_logic_vector := pa(what);  -- constant
  begin
    if what = sparc then
      -- Actual PTP is (31 downto 2) with only 256 byte alignment allowed.
      -- We do not allow for more than 32 bits of physical address (Sparc
      -- documentation says 36 bits), so skip the top 4 bits.
      -- We also require 4k page aligment, so skip at the bottom as well.
      return data(27 downto 8);
    else
      -- Every page table is the size of one page (thus downto 12).
      -- 12 due to smallest page size, 10 are the information bits.
      return data(pa_tmp'high - 12 + 10 downto 10);
    end if;
  end;

  function pte_cached(what : va_type;
                      data : std_logic_vector) return std_logic is
    variable pbmt : std_logic_vector(rv_pte_pbmt'range) := data(rv_pte_pbmt'range);
  begin
    if what = sparc then
      return data(PTE_C);
    else
      case pbmt is
        when "01"   => return '0';  -- NC
        when "10"   => return '0';  -- I/O
        when others => return '1';  -- PMA (reserved for "11")
      end case;
    end if;
  end;

  -- Check if PTE will be modified (Accessed/Dirty bits).
  -- needwb     - writeback is needed since D and/or A is changed
  -- needwblock - locked RMW writeback is needed due to not setting D
  -- (It is safe to set D+A, but setting only A could, without locked RMW,
  --  potentially over-write another CPU's "simultaneous" setting of D+A.)
  procedure pte_mark_modacc(what   : va_type;
                            data   : inout std_logic_vector; modified   : std_logic;
                            needwb : out std_logic;          needwblock : out std_logic) is
    -- Non-constant
--    variable was_modified : std_logic;
--    variable tmpneedwb    : std_logic := '0';  -- Since reading from out parameter is impossible.
--    variable accessed     : std_logic;
    variable accessed : std_logic := cond(what = sparc, data(PTE_R), data(rv_pte_a));
    variable dirty    : std_logic := cond(what = sparc, data(PTE_M), data(rv_pte_d));
  begin
--    if what = sparc then
--      was_modified     := data(PTE_M);
--      if modified = '1' then
--        tmpneedwb      := not data(PTE_M);                  -- Mark if was not '1' already.
--        data(PTE_M)    := '1';
--      end if;
--      tmpneedwb        := tmpneedwb or not data(PTE_R);     -- Mark if was not '1' already.
--      data(PTE_R)      := '1';         -- Referenced
--    else
--      was_modified     := data(rv_pte_d);
--      if modified = '1' then
--        tmpneedwb      := not data(rv_pte_d);               -- Mark if was not '1' already.
--        data(rv_pte_d) := '1';
--      end if;
--      tmpneedwb        := tmpneedwb or not data(rv_pte_a);  -- Mark if was not '1' already.
--      data(rv_pte_a)   := '1';         -- Accessed
--    end if;
--
--    needwblock := tmpneedwb and not was_modified;
--    needwb     := tmpneedwb;

    data(cond(what = sparc, PTE_R, rv_pte_a)) := '1';    -- Always accessed!

    if modified = '1' then
      data(cond(what = sparc, PTE_M, rv_pte_d)) := '1';  -- Now dirty!
      needwb     := not dirty;                           -- First modification?
      needwblock := '0';                                 -- No lock needed!
    else
      needwb     := not accessed;                        -- First access?
      needwblock := not accessed;                        --  Then use locked RMW update.
    end if;
  end;

  -- Convert virtual vaddr to physical paddr, using vmask to OR correct levels.
  procedure virtual2physical(what  : va_type;
                             vaddr : std_logic_vector; mask : std_logic_vector;
                             paddr : inout std_logic_vector) is
    constant pa_tmp      : std_logic_vector := pa(what);       -- constant
    -- Non-constant
    variable xpaddr      : std_logic_vector(pa_tmp'range) := (others => '0');
    variable pos         : integer;
  begin
    --     RISC-V requires high bits to equal MSB of VA.
    xpaddr(paddr'range) := paddr;
    -- Loop from low bits to high
    pos := 12;
    for i in va_size(what) downto 1 loop
      if mask(i) = '0' then
        xpaddr(pos + va_size(what, i) - 1 downto pos) := xpaddr(pos + va_size(what, i) - 1 downto pos) or
                                                          vaddr(pos + va_size(what, i) - 1 downto pos);
      end if;
      pos := pos + va_size(what, i);
    end loop;

    paddr := xpaddr(paddr'range);
  end;

  -- Return the SPARC v8 Fault Type field (thus 0 means OK).
  -- at(0) - privileged
  -- at(1) - execution
  -- at(2) - write
  -- r(0)  - invalid address (Sparc), SUM permission error (RISC-V)
  -- r(1)  - permission error
  -- r(2)  - translation error (Sparc, unused here), MXR permission error (RISC-V)
  function ft_acc_resolve(what : va_type;
                          at : std_logic_vector(2 downto 0); data : std_logic_vector)
    return std_logic_vector is
    variable sparc_acc : integer := u2i(data(PTE_ACC_U downto PTE_ACC_D));
    -- For RISC-V
    variable is_user   : boolean := at(0) = '0';
    variable is_exec   : boolean := at(1) = '1';
    variable is_write  : boolean := at(2) = '1';
    -- From the table in SPARC v8 H.5
    --
    -- Bit Permission
    -- 0 - read
    -- 1 - read/write
    -- 2 - read/execute                          xxx      user
    -- 3 - all                                  w w
    -- 4 - execute                             rrrr r
    -- 5 - user read, supervisor read/write      xxx xx   supervisor
    -- 6 - supervisor read/execute              w w w w
    -- 7 - supervisor all                      rrrr rrr       space        access
    variable v0 : std_logic_vector(0 to 7) := "00001011";  -- user       d load
    variable v1 : std_logic_vector(0 to 7) := "00001000";  -- supervisor d load
    variable v2 : std_logic_vector(0 to 7) := "11000111";  -- user       i load/execute
    variable v3 : std_logic_vector(0 to 7) := "11000100";  -- supervisor i load/execute
    variable v4 : std_logic_vector(0 to 7) := "10101111";  -- user       d store
    variable v5 : std_logic_vector(0 to 7) := "10101010";  -- supervisor d store
    variable v6 : std_logic_vector(0 to 7) := "11101111";  -- user       i store
    variable v7 : std_logic_vector(0 to 7) := "11101110";  -- supervisor i store
    -- Non-constant
    variable r        : std_logic_vector(2 downto 0);
    -- For RISC-V
    variable err_mxr  : std_logic := '0';  -- Assume all is OK.
    variable err_perm : std_logic := '0';
    variable err_sum  : std_logic := '0';
  begin
    if what = sparc then
      r := "000";                     -- Assume OK
      if notx(data(PTE_ACC_U downto PTE_ACC_D)) and notx(at) then
        case at is
          when "000"  => r(1) := v0(sparc_acc);
          when "001"  => r(1) := v1(sparc_acc);
          when "010"  => r(1) := v2(sparc_acc);
          when "011"  => r(1) := v3(sparc_acc);
          when "100"  => r(1) := v4(sparc_acc);
          when "101"  => r(1) := v5(sparc_acc);
          when "110"  => r(1) := v6(sparc_acc);
          when others => r(1) := v7(sparc_acc);
        end case;
        -- If not permitted, supervisor read/execute(/write) permission,
        --    and not doing supervisor store
        if r(1) = '1' and (sparc_acc = 6 or sparc_acc = 7) and not (at = "101" or at = "111") then
          r(0) := '1';
        end if;
      else
        setx(r);
      end if;
    else
      -- Normally, allow access only from correct mode!
      -- SUM flag allows user page accesses from supervisor mode,
      -- but only for read/write (see below).
      if (    is_user and (data(rv_pte_u)     = '0')) or
         (not is_user and (data(rv_pte_u + 1) = '0')) then
        err_perm    := '1';
      end if;

      if is_exec then
        if data(rv_pte_x) = '0' then
          err_perm  := '1';
        end if;
        err_sum     := '1';            -- SUM flag does not affect execute.
        err_mxr     := '1';            -- MXR is only OK for read.
      elsif is_write then
        if data(rv_pte_w) = '0' then
          err_perm  := '1';
          err_sum   := '1';
        end if;
        err_mxr     := '1';            -- MXR is only OK for read.
      else                             -- Read
        if data(rv_pte_r) = '0' then
          err_perm  := '1';
          err_sum   := '1';
          -- MXR read fails only if both R and X would.
          if data(rv_pte_x) = '0' then
            err_mxr := '1';
          end if;
        end if;
      end if;

      -- W without R is reserved!
      -- Execute & Write is an invalid query!
      if data(rv_pte_w downto rv_pte_r) = "10" or
         (is_exec and is_write) then
        err_mxr     := '1';
        err_perm    := '1';
        err_sum     := '1';
      end if;

      r := err_mxr & err_perm & err_sum;
    end if;

    return r;
  end ft_acc_resolve;

end;
