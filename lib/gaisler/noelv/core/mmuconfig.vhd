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
use gaisler.utilnv.u2vec;
use gaisler.utilnv.cond;
use gaisler.utilnv.uext;
use gaisler.utilnv.get;
use gaisler.utilnv.get_lo;
use gaisler.utilnv.get_right;
use gaisler.utilnv.maximum;
use gaisler.noelvint.atp_type;
use gaisler.noelvint.atp_none;
use gaisler.noelvtypes.word16_arr;
use gaisler.noelvtypes.zerow16;
use gaisler.noelvtypes.integer64;

package mmucacheconfig is

subtype  va_type is integer range 0 to 3;
constant sparc    : integer := 0;
constant sv32     : integer := 1;
constant sv39     : integer := 2;
constant sv48     : integer := 3;

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

function supports_impl_mmu_sv32(what : integer) return boolean;
function supports_impl_mmu_sv39(what : integer) return boolean;
function supports_impl_mmu_sv48(what : integer) return boolean;

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
function is_valid_pte(what        : va_type;
                      data        : std_logic_vector;
                      mask        : std_logic_vector;
                      ext_svpbmt  : boolean := false;
                      ext_svnapot : boolean := false
                     ) return boolean;
function is_pte(what : va_type; data : std_logic_vector) return boolean;
function is_valid_ptd(what : va_type;
                      data : std_logic_vector
                     ) return boolean;
function is_ptd(what : va_type; data : std_logic_vector) return boolean;
function satp_base(what : va_type; satp : atp_type) return std_logic_vector;
--function satp_asid(what : va_type; satp : atp_type) return std_logic_vector;
--function satp_mode(what : va_type; satp : atp_type) return integer;
--function satp_mask(id : integer; physaddr : integer; what : va_type) return std_logic_vector;
--function vsatp_mask(id : integer; what : va_type) return std_logic_vector;
function from_atp(what : va_type; atp : atp_type) return std_logic_vector;
function to_satp(satp_prv : atp_type;
                 satp_in  : std_logic_vector;
                 proc_xlen : integer;
                 asid_len  : integer;
                 phys_addr : integer;
                 what      : va_type) return atp_type;
function to_vsatp(vsatp_prv : atp_type;
                  vsatp_in  : std_logic_vector;
                  hgatp     : atp_type;
                  as_satp   : boolean;
                  proc_xlen : integer;
                  asid_len  : integer;
                  phys_addr : integer;
                  what      : va_type) return atp_type;
function to_hgatp(hgatp_prv : atp_type;
                  hgatp_in  : std_logic_vector;
                  proc_xlen : integer;
                  vmid_len  : integer;
                  phys_addr : integer;
                  what      : va_type) return atp_type;
function has_pt(what : va_type; atp : atp_type) return boolean;
function pte_paddr(what : va_type; data : std_logic_vector) return std_logic_vector;
function vpn_split(what : va_type; vaddr : std_logic_vector) return word16_arr;
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
constant rv_ppn      : std_logic_vector(53 downto 10) := (others => '0');
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

  function supports_impl_mmu_sv32(what : integer) return boolean is
  begin
    return what = sv32;
  end;

  function supports_impl_mmu_sv39(what : integer) return boolean is
  begin
    return what >= sv39;
  end;

  function supports_impl_mmu_sv48(what : integer) return boolean is
  begin
    return what >= sv48;
  end;

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

  function is_valid_pte(what        : va_type;
                        data        : std_logic_vector;
                        mask        : std_logic_vector;
                        ext_svpbmt  : boolean := false;
                        ext_svnapot : boolean := false
                       ) return boolean is
  begin

    -- Reserved top bits must be zero.
    if not all_0(data(rv_pte_resv'range)) then
      return false;
    end if;

    if ext_svpbmt then
      -- PBMT 11 is reserved.
      if data(rv_pte_pbmt'range) = "11" then
        return false;
      end if;
    else
      -- PBMT is reserved
      if data(rv_pte_pbmt'range) /= "00" then
        return false;
      end if;
    end if;

    if ext_svnapot then
      -- Only 64 kByte NAPOT defined so far,
      -- and NAPOT is only defined at the base page level.
      if data(rv_pte_n) = '1' and
         (mask(mask'right) = '0' or get_lo(data(rv_ppn'range), 4) /= "1000") then
        return false;
      end if;
    else
      -- N (Svnapot) is reserved
      if data(rv_pte_n) /= '0' then
        return false;
      end if;
    end if;

    return true;
  end;

  function is_pte(what : va_type;
                  data : std_logic_vector) return boolean is
  begin
    -- PTE is marked by not R=0, W=0, X=0. Must also be valid.
    return data(rv_pte_v) = '1' and data(rv_pte_xwr'range) /= "000";
  end;

  function is_valid_ptd(what : va_type;
                        data : std_logic_vector
                       ) return boolean is
  begin
    -- Reserved top bits must be zero.
    if not all_0(data(rv_pte_resv'range)) then
      return false;
    end if;

    -- PBMT is reserved.
    if data(rv_pte_pbmt'range) /= "00" then
      return false;
    end if;

    -- N is assumed to be reserved (the standard does not appear to say).
    if data(rv_pte_n) /= '0' then
      return false;
    end if;

    -- PTD also has D, A and U reserved, so enforce 0 (Spike does).
    if data(rv_pte_d) = '1' or data(rv_pte_a) = '1' or data(rv_pte_u) = '1' then
      return false;
    end if;

    return true;
  end;

  function is_ptd(what : va_type;
                  data : std_logic_vector) return boolean is
  begin
    -- PTD is marked by R=0, W=0, X=0. Must also be valid.
    return data(rv_pte_v) = '1' and data(rv_pte_xwr'range) = "000";
  end;

  function satp_base(what : va_type; satp : atp_type) return std_logic_vector is
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
        base(i) := satp.ppn(i - 12);
      end loop;
    when sv39   => -- base(ppn_sv39'range) := satp(BASE_SV39'range);
      for i in ppn_sv39'high downto ppn_sv39'low loop
        base(i) := satp.ppn(i - 12);
      end loop;
    when sv48   => -- base(ppn_sv48'range) := satp(BASE_SV48'range);
      for i in ppn_sv48'high downto ppn_sv48'low loop
        base(i) := satp.ppn(i - 12);
      end loop;
    when others => assert false
                     report "This function does not work for Sparc!"
                     severity failure;
    end case;

    return base;
  end;

--  function satp_asid(what : va_type; satp : std_logic_vector) return std_logic_vector is
--    variable ASID_SV32 : std_logic_vector(30 downto 22) := (others => '0');
--    variable ASID_SV39 : std_logic_vector(59 downto 44) := (others => '0');
--    variable ASID_SV48 : std_logic_vector(59 downto 44) := (others => '0');
--    -- Non-constant
--    variable asid32    : std_logic_vector(ASID_SV32'length - 1 downto 0);
--    variable asid39    : std_logic_vector(ASID_SV39'length - 1 downto 0);
--    variable asid48    : std_logic_vector(ASID_SV48'length - 1 downto 0);
--  begin
--    case what is
--    when sv32   => asid32 := satp(ASID_SV32'range); return asid32;
--    when sv39   => asid39 := satp(ASID_SV39'range); return asid39;
--    when sv48   => asid48 := satp(ASID_SV48'range); return asid48;
--    when others => assert false
--                     report "This function does not work for Sparc!"
--                     severity failure;
--    end case;
--
--    return "0";      -- Can never happen!
--  end;
--
--  function satp_mode(what : va_type; satp : std_logic_vector) return integer is
--    variable MODE_RV32 : std_logic_vector(31 downto 31) := (others => '0');
--    variable MODE_RV64 : std_logic_vector(63 downto 60) := (others => '0');
--  begin
--    case what is
--    when sv32 =>
--      if satp'length = 32 then
--        return u2i(satp(MODE_RV32'range));
--      else
--        return u2i(satp(MODE_RV64'range));
--      end if;
--    when sv39 | sv48 =>
--      assert satp'length = 64
--        report "XLEN does not match requested MMU mode!"
--        severity failure;
--      return u2i(satp(MODE_RV64'range));
--    when others => assert false
--                     report "This function does not work for Sparc!"
--                     severity failure;
--    end case;
--
--    return 0;        -- Can never happen!
--  end;

  function from_atp(what : va_type; atp : atp_type) return std_logic_vector is
    constant ASID_32 : std_logic_vector(30 downto 22) := (others => '0');
    -- Non-constant
    variable mode    : std_logic_vector(3 downto 0)   := (others => '0');
  begin
    if what = sv32 then
      assert not atp.small severity failure;
      return cond(atp.normal, '1', '0') & get_lo(atp.id, ASID_32'length) & get_lo(atp.ppn, ASID_32'low);
    else
      assert not (atp.normal and atp.small) severity failure;
      assert not (what = sv39 and atp.small) severity failure;
      if atp.normal then
        mode := u2vec(cond(what = sv39, 8, 9), mode);
      elsif what = sv48 and atp.small then
        mode := u2vec(8, mode);
      end if;
      return mode & atp.id & atp.ppn;
    end if;
  end;

  constant ATP32_MODE : std_logic_vector(31 downto 31) := "1";
  constant ATP32_ID   : std_logic_vector(30 downto 22) := (others => '1');
  constant ATP32_PPN  : std_logic_vector(21 downto  0) := (others => '1');

  constant ATP64_ID   : std_logic_vector(59 downto 44) := (others => '1');
  constant ATP64_MODE : std_logic_vector(63 downto 60) := (others => '1');
  constant ATP64_PPN  : std_logic_vector(43 downto  0) := (others => '1');

  constant MODE_BARE : integer := 0;
  constant MODE_SV39 : integer := 8;
  constant MODE_SV48 : integer := 9;

  function to_satp(satp_prv  : atp_type;
                   satp_in   : std_logic_vector;
                   proc_xlen : integer;
                   asid_len  : integer;
                   phys_addr : integer;
                   what      : va_type) return atp_type is
    variable mode64_in : integer range 0 to 15 := u2i(satp_in(proc_xlen - 1 downto proc_xlen - 4));
    -- Non-constant
    variable satp_out : atp_type := atp_none;
  begin
    assert proc_xlen = 32 or proc_xlen = 64 severity failure;
    satp_out.mmu := what;  -- For RVVI debug
    if proc_xlen = 32 then
      assert not supports_impl_mmu_sv39(what) and                -- Illegal config
             not supports_impl_mmu_sv48(what) severity failure;

      if (supports_impl_mmu_sv32(what)) then
        satp_out.ppn      := uext(satp_in(ATP32_PPN'range), satp_out.ppn);
        satp_out.id       := uext(get_right(satp_in(ATP32_ID'range), asid_len), satp_out.id);
        satp_out.normal   := satp_in(ATP32_MODE'range) = "1";
        satp_out.small    := false;
      end if;
    else
      assert not supports_impl_mmu_sv32(what) severity failure;  -- Illegal config

      satp_out.ppn        := uext(get_right(satp_in(ATP64_PPN'range), phys_addr - 12), satp_out.ppn);
      satp_out.id         := uext(get_right(satp_in(ATP64_ID'range), asid_len), satp_out.id);
      -- Any of the legal modes trying to be written?
      case mode64_in is
      when MODE_BARE =>
        satp_out.normal   := false;
        satp_out.small    := false;
      when MODE_SV39 =>
        if supports_impl_mmu_sv39(what) then
          satp_out.normal := not supports_impl_mmu_sv48(what);
          satp_out.small  :=     supports_impl_mmu_sv48(what);
        end if;
      when MODE_SV48 =>
        if supports_impl_mmu_sv48(what) then
          satp_out.normal := true;
          satp_out.small  := false;
        else
          -- Bad mode selection, keep previous fields
          satp_out        := satp_prv;
        end if;
      when others =>
        -- Bad mode selection, keep previous fields
        satp_out          := satp_prv;
      end case;

      return satp_out;
    end if;

    return satp_out;
  end;

  function to_vsatp(vsatp_prv : atp_type;
                    vsatp_in  : std_logic_vector;
                    hgatp     : atp_type;
                    as_satp   : boolean;
                    proc_xlen : integer;
                    asid_len  : integer;
                    phys_addr : integer;
                    what      : va_type) return atp_type is
    variable mode64_in : integer range 0 to 15 := u2i(vsatp_in(proc_xlen - 1 downto proc_xlen - 4));
    -- Non-constant
    variable vsatp_out : atp_type := atp_none;
  begin
    assert proc_xlen = 32 or proc_xlen = 64 severity failure;
    vsatp_out.mmu := what;  -- For RVVI debug
    if proc_xlen = 32 then
      assert not supports_impl_mmu_sv39(what) and                -- Illegal config
             not supports_impl_mmu_sv48(what) severity failure;

      if (supports_impl_mmu_sv32(what)) then
        vsatp_out.ppn      := uext(vsatp_in(ATP32_PPN'range), vsatp_out.ppn);
        vsatp_out.id       := uext(get_right(vsatp_in(ATP32_ID'range), asid_len), vsatp_out.id);
        vsatp_out.normal   := vsatp_in(ATP32_MODE'range) = "1";
        vsatp_out.small    := false;
      end if;
    else
      assert not supports_impl_mmu_sv32(what) severity failure;  -- Illegal config

      vsatp_out.ppn        := uext(get_right(vsatp_in(ATP64_PPN'range),
                                             maximum(phys_addr, ga_msb(what) + 1) - 12), vsatp_out.ppn);
      vsatp_out.id         := uext(get_right(vsatp_in(ATP64_ID'range), asid_len), vsatp_out.id);
      -- Any of the legal modes trying to be written?
      case mode64_in is
      when MODE_BARE =>
        vsatp_out.normal   := false;
        vsatp_out.small    := false;
      when MODE_SV39 =>
        if supports_impl_mmu_sv39(what) then
          vsatp_out.normal := not supports_impl_mmu_sv48(what);
          vsatp_out.small  :=     supports_impl_mmu_sv48(what);
        else
          -- Bad mode selection, keep previous mode
          vsatp_out.normal := vsatp_prv.normal;
          vsatp_out.small  := vsatp_prv.small;
        end if;
      when MODE_SV48 =>
        if supports_impl_mmu_sv48(what) then
          vsatp_out.normal := true;
          vsatp_out.small  := false;
        else
          if as_satp then
            -- Bad mode selection, keep previous fields
            vsatp_out      := vsatp_prv;
          else
            -- Bad mode selection, keep previous mode
            vsatp_out.normal := vsatp_prv.normal;
            vsatp_out.small  := vsatp_prv.small;
          end if;
        end if;
      when others =>
        if as_satp then
          -- Bad mode selection, keep previous fields
          vsatp_out        := vsatp_prv;
        else
          -- Bad mode selection, keep previous mode
          vsatp_out.normal := vsatp_prv.normal;
          vsatp_out.small  := vsatp_prv.small;
        end if;
      end case;

      return vsatp_out;
    end if;

    return vsatp_out;
  end;

  function to_hgatp(hgatp_prv : atp_type;
                    hgatp_in  : std_logic_vector;
                    proc_xlen : integer;
                    vmid_len  : integer;
                    phys_addr : integer;
                    what      : va_type) return atp_type is
    variable mode64_in : integer range 0 to 15 := u2i(hgatp_in(proc_xlen - 1 downto proc_xlen - 4));
    -- Non-constant
    variable hgatp_out : atp_type := atp_none;
  begin
    assert proc_xlen = 32 or proc_xlen = 64 severity failure;
    hgatp_out.mmu := what;  -- For RVVI debug
    if proc_xlen = 32 then
      assert not supports_impl_mmu_sv39(what) and                -- Illegal config
             not supports_impl_mmu_sv48(what) severity failure;

      if (supports_impl_mmu_sv32(what)) then
        hgatp_out.ppn    := uext(hgatp_in(ATP32_PPN'range), hgatp_out.ppn);
        hgatp_out.id     := uext(get_right(hgatp_in(ATP32_ID'range), vmid_len), hgatp_out.id);
        hgatp_out.normal := hgatp_in(ATP32_MODE'range) = "1";
        hgatp_out.small  := false;
      end if;
    else
      assert not supports_impl_mmu_sv32(what) severity failure;  -- Illegal config

      hgatp_out.ppn := uext(get_right(hgatp_in(ATP64_PPN'high downto 2) & "00", phys_addr - 12), hgatp_out.ppn);
      hgatp_out.id  := uext(get_right(hgatp_in(ATP64_ID'range), vmid_len), hgatp_out.id);
      -- Any of the legal modes trying to be written?
      case mode64_in is
      when MODE_BARE =>
        hgatp_out.normal   := false;
        hgatp_out.small    := false;
      when MODE_SV39 =>
        if supports_impl_mmu_sv39(what) then
          hgatp_out.normal := not supports_impl_mmu_sv48(what);
          hgatp_out.small  :=     supports_impl_mmu_sv48(what);
        else
          -- Invalid mode so keep the old one
          hgatp_out.normal := hgatp_prv.normal;
          hgatp_out.small  := hgatp_prv.small;
        end if;
      when MODE_SV48 =>
        if supports_impl_mmu_sv48(what) then
          hgatp_out.normal := true;
          hgatp_out.small  := false;
        else
          -- Invalid mode so keep the old one
          hgatp_out.normal := hgatp_prv.normal;
          hgatp_out.small  := hgatp_prv.small;
        end if;
      when others =>
        -- Invalid mode so keep the old one
        hgatp_out.normal   := hgatp_prv.normal;
        hgatp_out.small    := hgatp_prv.small;
      end case;

      return hgatp_out;
    end if;

    return hgatp_out;
  end;

  function has_pt(what : va_type; atp : atp_type) return boolean is
  begin
    return atp.normal or (supports_impl_mmu_sv48(what) and atp.small);
  end;

  function pte_paddr(what : va_type;
                     data : std_logic_vector) return std_logic_vector is
    constant pa_tmp : std_logic_vector := pa(what);  -- constant
  begin
    -- Every page table is the size of one page (thus downto 12).
    -- 12 due to smallest page size, 10 are the information bits.
    return data(pa_tmp'high - 12 + 10 downto 10);
  end;

  -- Create an array of the various VPN levels, to simplify synthesis.
  function vpn_split(what : va_type; vaddr : std_logic_vector) return word16_arr is
    variable va_step : integer            := va_size(what, 1);  -- On RISC-V, va_size(n) is the same for all n.
    -- Non-constant
    variable vpn     : word16_arr(0 to 3) := (others => zerow16);
    variable pos     : integer64          := 12;
  begin
    for i in vpn'range loop
      if pos + va_step <= vaddr'high + 1 then
        vpn(i)(va_step - 1 downto 0) := get(vaddr, pos, va_step);
      end if;
      pos := pos + va_step;
    end loop;

    return vpn;
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
    variable accessed : std_logic := data(rv_pte_a);
    variable dirty    : std_logic := data(rv_pte_d);
  begin
--    was_modified     := data(rv_pte_d);
--    if modified = '1' then
--      tmpneedwb      := not data(rv_pte_d);               -- Mark if was not '1' already.
--      data(rv_pte_d) := '1';
--    end if;
--    tmpneedwb        := tmpneedwb or not data(rv_pte_a);  -- Mark if was not '1' already.
--    data(rv_pte_a)   := '1';         -- Accessed
--
--    needwblock := tmpneedwb and not was_modified;
--    needwb     := tmpneedwb;

    data(rv_pte_a) := '1';    -- Always accessed!

    if modified = '1' then
      data(rv_pte_d) := '1';  -- Now dirty!
      needwb     := not dirty or not accessed;           -- First modification?
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
    --constant pa_tmp      : std_logic_vector := pa(what);       -- constant
    -- Non-constant
    variable xpaddr      : std_logic_vector(pa_msb(what) downto 0) := (others => '0');
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

  -- at(0) - privileged
  -- at(1) - execution
  -- at(2) - write
  -- r(0)  - SUM permission error (RISC-V)
  -- r(1)  - permission error
  -- r(2)  - MXR permission error (RISC-V)
  function ft_acc_resolve(what : va_type;
                          at : std_logic_vector(2 downto 0); data : std_logic_vector)
    return std_logic_vector is
    variable is_user  : boolean := at(0) = '0';
    variable is_exec  : boolean := at(1) = '1';
    variable is_write : boolean := at(2) = '1';
    -- Non-constant
    variable r        : std_logic_vector(2 downto 0);
    variable err_mxr  : std_logic := '0';  -- Assume all is OK.
    variable err_perm : std_logic := '0';
    variable err_sum  : std_logic := '0';
  begin
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

    return r;
  end;

end;
