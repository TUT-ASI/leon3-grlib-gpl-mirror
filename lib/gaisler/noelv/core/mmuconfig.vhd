------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-- Package: 	mmucacheconfig
-- File:	mmuconfig.vhd
-- Author:	Konrad Eisele, Jiri Gaisler, Johan Klockars Cobham Gaisler AB
-- Description:	MMU types and constants
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;

use grlib.amba.hsize_word;
use grlib.amba.hsize_dword;

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
function vpn(what : va_type) return std_logic_vector;
function pa(what : va_type) return std_logic_vector;
function ppn(what : va_type) return std_logic_vector;
function pte_hsize(what : va_type) return std_logic_vector;
function va_size(what : va_type) return va_bits;
function va_i_size(what : va_type) return integer;
function va_i_max(what : va_type) return integer;
function is_riscv(what : va_type) return boolean;
function is_pt_invalid(what : va_type; data : std_logic_vector) return boolean;
function is_valid_pte(what : va_type;
                      data : std_logic_vector; mask : std_logic_vector;
                      physaddr : integer range 32 to 56) return boolean;
function is_pte(what : va_type; data : std_logic_vector) return boolean;
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
--          10         26         9          9        2     1   1   1   1   1   1   1   1
--     +----------+----------+----------+----------+------+---+---+---+---+---+---+---+---+
--     | Reserved |   PPN2   |   PPN1   |   PPN0   | RSW  | D | A | G | U | X | W | R | V |
--     +----------+----------+----------+----------+------+---+---+---+---+---+---+---+---+
--       63    54   53    28   27    19   18    10   9  8   7   6   5   4   3   2   1   0
--
--
--     Sv48 PAGE TABE ENTRY (PTE) [riscv-privileged: p.72, 4.3.1, Figure 4.18]
--          10         17          9          9          9       2     1   1   1   1   1   1   1   1
--     +----------+----------+----------+----------+----------+------+---+---+---+---+---+---+---+---+
--     | Reserved |   PPN3   |   PPN2   |   PPN1   |   PPN0   | RSW  | D | A | G | U | X | W | R | V |
--     +----------+----------+----------+----------+----------+------+---+---+---+---+---+---+---+---+
--       63    54   53    37   36    28   27    19   18    10   9  8   7   6   5   4   3   2   1   0
--
--  PPN = Physical Page Number
--  RSW = Reserved for Software
--  V : valid (rest don't care if 0)
--  R : readble    (when RWX == "000", pointer to next level of table)
--  W : writable   (RWX == "010" | "110" are reserved for future use)
--  X : executable
--  U : user mode accessible
--  G : global mapping
--  A : accessed (since cleared)
--  D : written  (since cleared)


constant rv_pte_xwr : std_logic_vector(3 downto 1) := "000";
constant rv_pte_v   : integer := 0;  -- valid (rest don't care if 0)
constant rv_pte_r   : integer := 1;  -- readable (RWX == "000" - pointer to next level of table)
constant rv_pte_w   : integer := 2;  -- writable (RWX == "010" | "110" reserved)
constant rv_pte_x   : integer := 3;  -- executable
constant rv_pte_u   : integer := 4;  -- user mode accessible
constant rv_pte_g   : integer := 5;  -- global mapping
constant rv_pte_a   : integer := 6;  -- accessed (since cleared)
constant rv_pte_d   : integer := 7;  -- written (since cleared)



-- ##############################################################
--     1.0 virtual address [sparc V8: p.243,Appx.H,Figure H-4]
--     +--------+--------+--------+---------------+
--  a) | INDEX1 | INDEX2 | INDEX3 |    OFFSET     |
--     +--------+--------+--------+---------------+
--      31    24 23    18 17    12 11            0

-- 1 - bits 31:24, '1' for 16MiB or smaller,'0' for 4 GiB
-- 2 - bits 23:18, '1' for 256KiB or smaller, '0' for 512KiB+
-- 3 - bits 17:12, '1' for 4 KiB, '0' for 8KiB+
constant VA_SZ  : va_bits(1 to 3) := (8, 6, 6);
--constant VA_SZ  : va_bits := va_size(sparc);
constant VA_I_SZ  : integer := VA_SZ(1) + VA_SZ(2) + VA_SZ(3);
--constant VA_I_SZ : integer := va_i_size(sparc);
-- Only used for range!
--constant VA_VA  : std_logic_vector(31 downto  0) := (others => '0');
--constant VA_PA  : std_logic_vector(31 downto  0) := (others => '0');
--constant VA_VPN : std_logic_vector(31 downto 12) := (others => '0');
--constant VA_PPN : std_logic_vector(31 downto 12) := (others => '0');

constant VA_I1_SZ : integer := 8;
constant VA_I2_SZ : integer := 6;
constant VA_I3_SZ : integer := 6;
--constant VA_I_SZ  : integer := VA_I1_SZ+VA_I2_SZ+VA_I3_SZ;
--constant VA_I_MAX : integer := 8;

constant VA_I1_U  : integer := 31;
constant VA_I1_D  : integer := 32-VA_I1_SZ;
constant VA_I2_U  : integer := 31-VA_I1_SZ;
constant VA_I2_D  : integer := 32-VA_I1_SZ-VA_I2_SZ;
constant VA_I3_U  : integer := 31-VA_I1_SZ-VA_I2_SZ;
constant VA_I3_D  : integer := 32-VA_I_SZ;
constant VA_I_U   : integer := 31;
constant VA_I_D   : integer := 32-VA_I_SZ;
constant VA_OFF_U : integer := 31-VA_I_SZ;
constant VA_OFF_D : integer := 0;

constant VA_OFFCTX_U : integer := 31;
constant VA_OFFCTX_D : integer := 0;
constant VA_OFFREG_U : integer := 31-VA_I1_SZ;
constant VA_OFFREG_D : integer := 0;
constant VA_OFFSEG_U : integer := 31-VA_I1_SZ-VA_I2_SZ;
constant VA_OFFSEG_D : integer := 0;
constant VA_OFFPAG_U : integer := 31-VA_I_SZ;
constant VA_OFFPAG_D : integer := 0;


-- 8k pages
--         7        6        6         13
--     +--------+--------+--------+---------------+
--  a) | INDEX1 | INDEX2 | INDEX3 |    OFFSET     |
--     +--------+--------+--------+---------------+
--      31    25 24    19 18    13 12            0

constant P8K_VA_I1_SZ : integer := 7;
constant P8K_VA_I2_SZ : integer := 6;
constant P8K_VA_I3_SZ : integer := 6;
constant P8K_VA_I_SZ  : integer := P8K_VA_I1_SZ+P8K_VA_I2_SZ+P8K_VA_I3_SZ;
constant P8K_VA_I_MAX : integer := 7;

constant P8K_VA_I1_U  : integer := 31;
constant P8K_VA_I1_D  : integer := 32-P8K_VA_I1_SZ;
constant P8K_VA_I2_U  : integer := 31-P8K_VA_I1_SZ;
constant P8K_VA_I2_D  : integer := 32-P8K_VA_I1_SZ-P8K_VA_I2_SZ;
constant P8K_VA_I3_U  : integer := 31-P8K_VA_I1_SZ-P8K_VA_I2_SZ;
constant P8K_VA_I3_D  : integer := 32-P8K_VA_I_SZ;
constant P8K_VA_I_U   : integer := 31;
constant P8K_VA_I_D   : integer := 32-P8K_VA_I_SZ;
constant P8K_VA_OFF_U : integer := 31-P8K_VA_I_SZ;
constant P8K_VA_OFF_D : integer := 0;

constant P8K_VA_OFFCTX_U : integer := 31;
constant P8K_VA_OFFCTX_D : integer := 0;
constant P8K_VA_OFFREG_U : integer := 31-P8K_VA_I1_SZ;
constant P8K_VA_OFFREG_D : integer := 0;
constant P8K_VA_OFFSEG_U : integer := 31-P8K_VA_I1_SZ-P8K_VA_I2_SZ;
constant P8K_VA_OFFSEG_D : integer := 0;
constant P8K_VA_OFFPAG_U : integer := 31-P8K_VA_I_SZ;
constant P8K_VA_OFFPAG_D : integer := 0;


-- 16k pages
--         6        6        6         14
--     +--------+--------+--------+---------------+
--  a) | INDEX1 | INDEX2 | INDEX3 |    OFFSET     |
--     +--------+--------+--------+---------------+
--      31    26 25    20 19    14 13            0

constant P16K_VA_I1_SZ : integer := 6;
constant P16K_VA_I2_SZ : integer := 6;
constant P16K_VA_I3_SZ : integer := 6;
constant P16K_VA_I_SZ  : integer := P16K_VA_I1_SZ+P16K_VA_I2_SZ+P16K_VA_I3_SZ;
constant P16K_VA_I_MAX : integer := 6;

constant P16K_VA_I1_U  : integer := 31;
constant P16K_VA_I1_D  : integer := 32-P16K_VA_I1_SZ;
constant P16K_VA_I2_U  : integer := 31-P16K_VA_I1_SZ;
constant P16K_VA_I2_D  : integer := 32-P16K_VA_I1_SZ-P16K_VA_I2_SZ;
constant P16K_VA_I3_U  : integer := 31-P16K_VA_I1_SZ-P16K_VA_I2_SZ;
constant P16K_VA_I3_D  : integer := 32-P16K_VA_I_SZ;
constant P16K_VA_I_U   : integer := 31;
constant P16K_VA_I_D   : integer := 32-P16K_VA_I_SZ;
constant P16K_VA_OFF_U : integer := 31-P16K_VA_I_SZ;
constant P16K_VA_OFF_D : integer := 0;

constant P16K_VA_OFFCTX_U : integer := 31;
constant P16K_VA_OFFCTX_D : integer := 0;
constant P16K_VA_OFFREG_U : integer := 31-P16K_VA_I1_SZ;
constant P16K_VA_OFFREG_D : integer := 0;
constant P16K_VA_OFFSEG_U : integer := 31-P16K_VA_I1_SZ-P16K_VA_I2_SZ;
constant P16K_VA_OFFSEG_D : integer := 0;
constant P16K_VA_OFFPAG_U : integer := 31-P16K_VA_I_SZ;
constant P16K_VA_OFFPAG_D : integer := 0;


-- 32k pages
--         4        7        6         15
--     +--------+--------+--------+---------------+
--  a) | INDEX1 | INDEX2 | INDEX3 |    OFFSET     |
--     +--------+--------+--------+---------------+

constant P32K_VA_I1_SZ : integer := 4;
constant P32K_VA_I2_SZ : integer := 7;
constant P32K_VA_I3_SZ : integer := 6;
constant P32K_VA_I_SZ  : integer := P32K_VA_I1_SZ+P32K_VA_I2_SZ+P32K_VA_I3_SZ;
constant P32K_VA_I_MAX : integer := 7;

constant P32K_VA_I1_U  : integer := 31;
constant P32K_VA_I1_D  : integer := 32-P32K_VA_I1_SZ;
constant P32K_VA_I2_U  : integer := 31-P32K_VA_I1_SZ;
constant P32K_VA_I2_D  : integer := 32-P32K_VA_I1_SZ-P32K_VA_I2_SZ;
constant P32K_VA_I3_U  : integer := 31-P32K_VA_I1_SZ-P32K_VA_I2_SZ;
constant P32K_VA_I3_D  : integer := 32-P32K_VA_I_SZ;
constant P32K_VA_I_U   : integer := 31;
constant P32K_VA_I_D   : integer := 32-P32K_VA_I_SZ;
constant P32K_VA_OFF_U : integer := 31-P32K_VA_I_SZ;
constant P32K_VA_OFF_D : integer := 0;

constant P32K_VA_OFFCTX_U : integer := 31;
constant P32K_VA_OFFCTX_D : integer := 0;
constant P32K_VA_OFFREG_U : integer := 31-P32K_VA_I1_SZ;
constant P32K_VA_OFFREG_D : integer := 0;
constant P32K_VA_OFFSEG_U : integer := 31-P32K_VA_I1_SZ-P32K_VA_I2_SZ;
constant P32K_VA_OFFSEG_D : integer := 0;
constant P32K_VA_OFFPAG_U : integer := 31-P32K_VA_I_SZ;
constant P32K_VA_OFFPAG_D : integer := 0;


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
constant PTD_PTP_U : integer := 31;   -- PTD: page table pointer
constant PTD_PTP_D : integer := 2;
constant PTD_PTP32_U : integer := 27;   -- PTD: page table pointer 32 bit
constant PTD_PTP32_D : integer := 2;
constant PTE_PPN_U : integer := 31;   -- PTE: physical page number
constant PTE_PPN_D : integer := 8;
constant PTE_PPN_S : integer := (PTE_PPN_U+1)-PTE_PPN_D;  -- PTE: pysical page number size
constant PTE_PPN32_U : integer := 27; -- PTE: physical page number 32 bit addr
constant PTE_PPN32_D : integer := 8;
constant PTE_PPN32_S : integer := (PTE_PPN32_U+1)-PTE_PPN32_D;  -- PTE: pysical page number 32 bit size

constant PTE_PPN32REG_U : integer := PTE_PPN32_U;  -- PTE: pte part of merged result address
constant PTE_PPN32REG_D : integer := PTE_PPN32_U+1-VA_I1_SZ;
constant PTE_PPN32SEG_U : integer := PTE_PPN32_U;
constant PTE_PPN32SEG_D : integer := PTE_PPN32_U+1-VA_I1_SZ-VA_I2_SZ;
constant PTE_PPN32PAG_U : integer := PTE_PPN32_U;
constant PTE_PPN32PAG_D : integer := PTE_PPN32_U+1-VA_I_SZ;

-- 8k pages
constant P8K_PTE_PPN32REG_U : integer := PTE_PPN32_U;  -- PTE: pte part of merged result address
constant P8K_PTE_PPN32REG_D : integer := PTE_PPN32_U+1-P8K_VA_I1_SZ;
constant P8K_PTE_PPN32SEG_U : integer := PTE_PPN32_U;
constant P8K_PTE_PPN32SEG_D : integer := PTE_PPN32_U+1-P8K_VA_I1_SZ-P8K_VA_I2_SZ;
constant P8K_PTE_PPN32PAG_U : integer := PTE_PPN32_U;
constant P8K_PTE_PPN32PAG_D : integer := PTE_PPN32_U+1-P8K_VA_I_SZ;

-- 16k pages
constant P16K_PTE_PPN32REG_U : integer := PTE_PPN32_U;  -- PTE: pte part of merged result address
constant P16K_PTE_PPN32REG_D : integer := PTE_PPN32_U+1-P16K_VA_I1_SZ;
constant P16K_PTE_PPN32SEG_U : integer := PTE_PPN32_U;
constant P16K_PTE_PPN32SEG_D : integer := PTE_PPN32_U+1-P16K_VA_I1_SZ-P16K_VA_I2_SZ;
constant P16K_PTE_PPN32PAG_U : integer := PTE_PPN32_U;
constant P16K_PTE_PPN32PAG_D : integer := PTE_PPN32_U+1-P16K_VA_I_SZ;

-- 32k pages
constant P32K_PTE_PPN32REG_U : integer := PTE_PPN32_U;  -- PTE: pte part of merged result address
constant P32K_PTE_PPN32REG_D : integer := PTE_PPN32_U+1-P32K_VA_I1_SZ;
constant P32K_PTE_PPN32SEG_U : integer := PTE_PPN32_U;
constant P32K_PTE_PPN32SEG_D : integer := PTE_PPN32_U+1-P32K_VA_I1_SZ-P32K_VA_I2_SZ;
constant P32K_PTE_PPN32PAG_U : integer := PTE_PPN32_U;
constant P32K_PTE_PPN32PAG_D : integer := PTE_PPN32_U+1-P32K_VA_I_SZ;



constant PTE_C : integer := 7;        -- PTE: Cacheable bit
constant PTE_M : integer := 6;        -- PTE: Modified bit
constant PTE_R : integer := 5;        -- PTE: Reference Bit - a "1" indicates an PTE

constant PTE_ACC_U : integer := 4;    -- PTE: Access field
constant PTE_ACC_D : integer := 2;
constant ACC_W : integer := 2;        -- PTE::ACC : write permission
constant ACC_E : integer := 3;        -- PTE::ACC : exec permission
constant ACC_SU : integer := 4;       -- PTE::ACC : privileged

constant PT_ET_U : integer := 1;      -- PTD/PTE: PTE Type
constant PT_ET_D : integer := 0;
constant ET_INV : std_logic_vector(1 downto 0) := "00";
constant ET_PTD : std_logic_vector(1 downto 0) := "01";
constant ET_PTE : std_logic_vector(1 downto 0) := "10";
constant ET_RVD : std_logic_vector(1 downto 0) := "11";

constant PADDR_PTD_U : integer := 31;
constant PADDR_PTD_D : integer := 6;

-- ##############################################################
--     3.0 TLBCAM TAG hardware representation (TTG)
--
type tlbcam_reg is record
   ET     : std_logic_vector(1 downto 0);              -- et field
   ACC    : std_logic_vector(2 downto 0);              -- on flush/probe this will become FPTY
   M      : std_logic;                                 -- modified
   R      : std_logic;                                 -- referenced
   SU     : std_logic;                                 -- equal ACC >= 6
   VALID  : std_logic;
   LVL    : std_logic_vector(1 downto 0);              -- level in pth
   I1     : std_logic_vector(7 downto 0);              -- vaddr
   I2     : std_logic_vector(5 downto 0);
   I3     : std_logic_vector(5 downto 0);
   CTX    : std_logic_vector(M_CTX_SZ-1 downto 0);     -- ctx number
   PPN    : std_logic_vector(PTE_PPN_S-1 downto 0);    -- physical page number
   C      : std_logic;                                 -- cachable
end record;

constant tlbcam_reg_none : tlbcam_reg := ("00", "000", '0', '0', '0', '0',
	"00", "00000000", "000000", "000000", "00000000", (others => '0'), '0');
-- tlbcam_reg::LVL
constant LVL_PAGE    : std_logic_vector(1 downto 0) := "00"; -- equal tlbcam_tfp::TYP FPTY_PAGE
constant LVL_SEGMENT : std_logic_vector(1 downto 0) := "01"; -- equal tlbcam_tfp::TYP FPTY_SEGMENT
constant LVL_REGION  : std_logic_vector(1 downto 0) := "10"; -- equal tlbcam_tfp::TYP FPTY_REGION
constant LVL_CTX     : std_logic_vector(1 downto 0) := "11"; -- equal tlbcam_tfp::TYP FPTY_CTX

-- ##############################################################
--     4.0 TLBCAM tag i/o for translation/flush/(probe)
--
type tlbcam_tfp is record
   TYP    : std_logic_vector(2 downto 0);        -- f/(p) type
   I1     : std_logic_vector(7 downto 0);        -- vaddr
   I2     : std_logic_vector(5 downto 0);
   I3     : std_logic_vector(5 downto 0);
   CTX    : std_logic_vector(M_CTX_SZ-1 downto 0);  -- ctx number
   M      : std_logic;
end record;

constant tlbcam_tfp_none : tlbcam_tfp := ("000", "00000000", "000000", "000000", "00000000", '0');

--tlbcam_tfp::TYP
constant FPTY_PAGE    : std_logic_vector(2 downto 0) := "000";  -- level 3 PTE  match I1+I2+I3
constant FPTY_SEGMENT : std_logic_vector(2 downto 0) := "001";  -- level 2/3 PTE/PTD match I1+I2
constant FPTY_REGION  : std_logic_vector(2 downto 0) := "010";  -- level 1/2/3 PTE/PTD match I1
constant FPTY_CTX     : std_logic_vector(2 downto 0) := "011";  -- level 0/1/2/3 PTE/PTD ctx
constant FPTY_N       : std_logic_vector(2 downto 0) := "100";  -- entire tlb

-- ##############################################################
--     5.0 MMU Control Register [sparc V8: p.253,Appx.H,Figure H-10]
--
--     +-------+-----+------------------+-----+-------+--+--+
--     |  IMPL | VER |        SC        | PSO | resvd |NF|E |
--     +-------+-----+------------------+-----+-------+--+--+
--      31  28  27 24 23               8   7   6     2  1  0
--
--     MMU Context Pointer [sparc V8: p.254,Appx.H,Figure H-11]
--     +-------------------------------------------+--------+
--     |         Context Table Pointer             |  resvd |
--     +-------------------------------------------+--------+
--      31                                        2 1      0
--
--     MMU Context Number [sparc V8: p.255,Appx.H,Figure H-12]
--     +----------------------------------------------------+
--     |              Context Table Pointer                 |
--     +----------------------------------------------------+
--      31                                                 0
--
--     fault status/address register [sparc V8: p.256,Appx.H,Table H-13/14]
--     +------------+-----+---+----+----+-----+----+
--     |   reserved | EBE | L | AT | FT | FAV | OW |
--     +------------+-----+---+----+----+-----+----+
--     31         18 17 10 9 8 7  5 4  2   1    0
--
--     +----------------------------------------------------+
--     |              fault address register                |
--     +----------------------------------------------------+
--      31                                                 0

constant MMCTRL_PTP32_U : integer := 25;
constant MMCTRL_PTP32_D : integer := 0;

constant MMCTRL_E  : integer := 0;
constant MMCTRL_NF : integer := 1;
constant MMCTRL_PSO : integer := 7;
constant MMCTRL_SC_U : integer := 23;
constant MMCTRL_SC_D : integer := 8;

constant MMCTRL_PGSZ_U : integer := 17;
constant MMCTRL_PGSZ_D : integer := 16;

constant MMCTRL_VER_U : integer := 27;
constant MMCTRL_VER_D : integer := 24;
constant MMCTRL_IMPL_U : integer := 31;
constant MMCTRL_IMPL_D : integer := 28;
constant MMCTRL_TLBDIS : integer := 15;
constant MMCTRL_TLBSEP : integer := 14;

constant MMCTRL_SUBIT : integer := 13;  --SU bit used during diagnostic tag write

constant MMCTXP_U : integer := 31;
constant MMCTXP_D : integer := 2;

constant MMCTXNR_U : integer := M_CTX_SZ-1;
constant MMCTXNR_D : integer := 0;

constant FS_SZ : integer := 18;  -- fault status size

constant FS_EBE_U : integer := 17;
constant FS_EBE_D : integer := 10;

constant FS_L_U : integer := 9;
constant FS_L_D : integer := 8;
constant FS_L_CTX : std_logic_vector(1 downto 0) := "00";
constant FS_L_L1 : std_logic_vector(1 downto 0) := "01";
constant FS_L_L2 : std_logic_vector(1 downto 0) := "10";
constant FS_L_L3 : std_logic_vector(1 downto 0) := "11";

constant FS_AT_U : integer := 7;
constant FS_AT_D : integer := 5;
constant FS_AT_LS : natural := 7;       --L=0 S=1
constant FS_AT_ID : natural := 6;       --D=0 I=1
constant FS_AT_SU : natural := 5;       --U=0 SU=1
constant FS_AT_LUDS : std_logic_vector(2 downto 0) := "000";
constant FS_AT_LSDS : std_logic_vector(2 downto 0) := "001";
constant FS_AT_LUIS : std_logic_vector(2 downto 0) := "010";
constant FS_AT_LSIS : std_logic_vector(2 downto 0) := "011";
constant FS_AT_SUDS : std_logic_vector(2 downto 0) := "100";
constant FS_AT_SSDS : std_logic_vector(2 downto 0) := "101";
constant FS_AT_SUIS : std_logic_vector(2 downto 0) := "110";
constant FS_AT_SSIS : std_logic_vector(2 downto 0) := "111";

constant FS_FT_U : integer := 4;
constant FS_FT_D : integer := 2;
constant FS_FT_NONE : std_logic_vector(2 downto 0) := "000";
constant FS_FT_INV : std_logic_vector(2 downto 0)  := "001";
constant FS_FT_PRO : std_logic_vector(2 downto 0)  := "010";
constant FS_FT_PRI : std_logic_vector(2 downto 0)  := "011";
constant FS_FT_TRANS : std_logic_vector(2 downto 0):= "100";
constant FS_FT_BUS : std_logic_vector(2 downto 0)  := "101";
constant FS_FT_INT : std_logic_vector(2 downto 0)  := "110";
constant FS_FT_RVD : std_logic_vector(2 downto 0)  := "111";

constant FS_FAV : natural := 1;
constant FS_OW : natural := 0;

-- ##############################################################
--     6. Virtual Flush/Probe address [sparc V8: p.249,Appx.H,Figure H-9]
--     +---------------------------------------+--------+-------+
--     |   VIRTUAL FLUSH&Probe Address (VFPA)  |  type  |  rvd  |
--     +---------------------------------------+--------+-------+
--      31                                   12 11     8 7      0
--
--
subtype FPA is natural range  31 downto 12;
constant FPA_I1_U : integer := 31;
constant FPA_I1_D : integer := 24;
constant FPA_I2_U : integer := 23;
constant FPA_I2_D : integer := 18;
constant FPA_I3_U : integer := 17;
constant FPA_I3_D : integer := 12;
constant FPTY_U : integer := 10;        -- only 3 bits
constant FPTY_D : integer := 8;

-- ##############################################################
--     7. control register virtual address [sparc V8: p.253,Appx.H,Table H-5]
--     +---------------------------------+-----+--------+
--     |                                 | CNR |  rsvd  |
--     +---------------------------------+-----+--------+
--      31                                10  8 7      0

constant CNR_U        : integer := 10;
constant CNR_D        : integer := 8;
constant CNR_CTRL     : std_logic_vector(2 downto 0) := "000";
constant CNR_CTXP     : std_logic_vector(2 downto 0) := "001";
constant CNR_CTX      : std_logic_vector(2 downto 0) := "010";
constant CNR_F        : std_logic_vector(2 downto 0) := "011";
constant CNR_FADDR    : std_logic_vector(2 downto 0) := "100";

-- ##############################################################
--     8. Precise flush (ASI 0x10-14) [sparc V8: p.266,Appx.I]
--        supported: ASI_FLUSH_PAGE
--                   ASI_FLUSH_CTX

constant PFLUSH_PAGE : std_logic := '0';
constant PFLUSH_CTX  : std_logic := '1';

-- ##############################################################
--     9. Diagnostic access
--
constant DIAGF_LVL_U : integer := 1;
constant DIAGF_LVL_D : integer := 0;
constant DIAGF_WR    : integer := 3;
constant DIAGF_HIT   : integer := 4;
constant DIAGF_CTX_U : integer := 12;
constant DIAGF_CTX_D : integer := 5;
constant DIAGF_VALID : integer := 13;
end mmucacheconfig;


package body mmucacheconfig is

  function va(what : va_type) return std_logic_vector is
    constant VA_SPARC : std_logic_vector(31 downto  0) := (others => '0');
    constant VA_SV32  : std_logic_vector(31 downto  0) := (others => '0');
    constant VA_SV39  : std_logic_vector(38 downto  0) := (others => '0');
    constant VA_SV48  : std_logic_vector(47 downto  0) := (others => '0');
  begin
    case what is
    when sv32   => return VA_SV32;
    when sv39   => return VA_SV39;
    when sv48   => return VA_SV48;
    when others => return VA_SPARC;
    end case;
  end;

  function vpn(what : va_type) return std_logic_vector is
    constant va_tmp : std_logic_vector                        := va(what);  -- constant
    constant tmp    : std_logic_vector(va_tmp'high downto 12) := (others => '0');
  begin
    return tmp;
  end;

  function pa(what : va_type) return std_logic_vector is
    constant PA_SPARC : std_logic_vector(31 downto  0) := (others => '0');
    constant PA_SV32  : std_logic_vector(33 downto  0) := (others => '0');
    constant PA_SV39  : std_logic_vector(55 downto  0) := (others => '0');
    constant PA_SV48  : std_logic_vector(55 downto  0) := (others => '0');
  begin
    case what is
    when sv32   => return PA_SV32;
    when sv39   => return PA_SV39;
    when sv48   => return PA_SV48;
    when others => return PA_SPARC;
    end case;
  end;

  function ppn(what : va_type) return std_logic_vector is
    constant pa_tmp : std_logic_vector                        := pa(what);  -- constant
    constant tmp    : std_logic_vector(pa_tmp'high downto 12) := (others => '0');
  begin
    return tmp;
  end;

  function pte_hsize(what : va_type) return std_logic_vector is
    constant HSIZE_SPARC : std_logic_vector(2 downto 0) := HSIZE_WORD;
    constant HSIZE_SV32  : std_logic_vector(2 downto 0) := HSIZE_WORD;
    constant HSIZE_SV39  : std_logic_vector(2 downto 0) := HSIZE_DWORD;
    constant HSIZE_SV48  : std_logic_vector(2 downto 0) := HSIZE_DWORD;
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
  function va_size(what : va_type) return va_bits is
    constant SZ_SPARC : va_bits(1 to 3) := (8, 6, 6);    -- 8 + 6 + 6     + 12 = 32 bits
    constant SZ_SV32  : va_bits(1 to 2) := (10, 10);     -- 10 + 10       + 12 = 32
    constant SZ_SV39  : va_bits(1 to 3) := (9, 9, 9);    -- 9 + 9 + 9     + 12 = 39
    constant SZ_SV48  : va_bits(1 to 4) := (9, 9, 9, 9); -- 9 + 9 + 9 + 9 + 12 = 48
  begin
    case what is
    when sv32   => return SZ_SV32;
    when sv39   => return SZ_SV39;
    when sv48   => return SZ_SV48;
    when others => return SZ_SPARC;
    end case;
  end;

  function va_i_size(what : va_type) return integer is
    constant sz  : va_bits := va_size(what);  -- constant
    -- Non-constant
    variable sum : integer := 0;
  begin
    for i in sz'range loop
      sum := sum + sz(i);
    end loop;

    return sum;
  end;

  function va_i_max(what : va_type) return integer is
    constant sz  : va_bits := va_size(what);  -- constant
    -- Non-constant
    variable max : integer := 0;
  begin
    for i in sz'range loop
      if sz(i) > max then
        max := sz(i);
      end if;
    end loop;

    return max;
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
      -- W without R is reserved!
      if data(rv_pte_w downto rv_pte_r) = "10" then
        return false;
      end if;
      if mask(mask'high) = '0' and data(18 downto 10) /= "000000000" then
        return false;
      end if;
      if mask(mask'high - 1) = '0' and data(27 downto 19) /= "000000000" then
        return false;
      end if;
      if what = sv48 then
        if mask(mask'high - 2) = '0' and data(36 downto 28) /= "000000000" then
          return false;
        end if;
      end if;

      -- Reserved top bits must be zero.
      if data(63 downto 54) /= "0000000000" then
        return false;
      end if;

      -- Do not allow addressing outside the specified physical address space.
      if to_integer(unsigned(data(53 downto physaddr - 12 + 10))) /= 0 then
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
    constant BASE_SV32  : std_logic_vector(21 downto 0)  := (others => '0');
    constant BASE_SV39  : std_logic_vector(43 downto 0)  := (others => '0');
    constant BASE_SV48  : std_logic_vector(43 downto 0)  := (others => '0');
    constant pa_tmp     : std_logic_vector               := pa(what);   -- constant
    constant ppn_sv32   : std_logic_vector               := ppn(sv32);  -- constant
    constant ppn_sv39   : std_logic_vector               := ppn(sv39);  -- constant
    constant ppn_sv48   : std_logic_vector               := ppn(sv48);  -- constant
    -- Non-constant
    variable base       : std_logic_vector(pa_tmp'range) := (others => '0');
  begin
    case what is
    when sv32   => base(ppn_sv32'range) := satp(BASE_SV32'range);
    when sv39   => base(ppn_sv39'range) := satp(BASE_SV39'range);
    when sv48   => base(ppn_sv48'range) := satp(BASE_SV48'range);
    when others => assert false
                     report "This function does not work for Sparc!"
                     severity failure;
    end case;

    return base;
  end;

  function satp_asid(what : va_type; satp : std_logic_vector) return std_logic_vector is
    constant ASID_SV32 : std_logic_vector(30 downto 22) := (others => '0');
    constant ASID_SV39 : std_logic_vector(59 downto 44) := (others => '0');
    constant ASID_SV48 : std_logic_vector(59 downto 44) := (others => '0');
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
    constant MODE_RV32 : std_logic_vector(31 downto 31) := (others => '0');
    constant MODE_RV64 : std_logic_vector(63 downto 60) := (others => '0');
  begin
    case what is
    when sv32 =>
      if satp'length = 32 then
        return to_integer(unsigned(satp(MODE_RV32'range)));
      else
        return to_integer(unsigned(satp(MODE_RV64'range)));
      end if;
    when sv39 | sv48 =>
      assert satp'length = 64
        report "XLEN does not match requested MMU mode!"
        severity failure;
      return to_integer(unsigned(satp(MODE_RV64'range)));
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
    constant pa_tmp : std_logic_vector               := pa(what);  -- constant
--    constant index  : integer range 1 to mask'length := mask'length - u2i(code);
    constant index  : integer range 1 to mask'length := mask'length - to_integer(unsigned(code));
    constant lowbit : integer                        := 11 - va_size(what)(index) + 1;
    -- Non-constant
    variable addr   : std_logic_vector(pa_tmp'range) := (others => '0');
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
      addr(addr'high downto 12) := data(pa_tmp'high - 12 + 10 downto 10);
      pos := 12;
--      for i in mask'length downto u2i(code) + 1 loop
      for i in mask'length downto 1 loop
        if i > to_integer(unsigned(code)) then
          pos := pos + va_size(what)(i);
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
  begin
    if what = sparc then
      return data(PTE_C);
    else
      assert false
        report "There is no cacheability info in PTE on RISC-V!"
        severity failure;
      return '0';
    end if;
  end;

  procedure pte_mark_modacc(what   : va_type;
                            data   : inout std_logic_vector; modified   : std_logic;
                            needwb : out std_logic;          needwblock : out std_logic) is
    -- Non-constant
    variable was_modified : std_logic;
    variable tmpneedwb    : std_logic := '0';  -- Since reading from out parameter is impossible.
  begin
    if what = sparc then
      was_modified     := data(PTE_M);
      if modified = '1' then
        tmpneedwb      := not data(PTE_M);                  -- Mark if was not '1' already.
        data(PTE_M)    := '1';
      end if;
      tmpneedwb        := tmpneedwb or not data(PTE_R);     -- Mark if was not '1' already.
      data(PTE_R)      := '1';         -- Referenced
    else
      was_modified     := data(rv_pte_d);
      if modified = '1' then
        tmpneedwb      := not data(rv_pte_d);               -- Mark if was not '1' already.
        data(rv_pte_d) := '1';
      end if;
      tmpneedwb        := tmpneedwb or not data(rv_pte_a);  -- Mark if was not '1' already.
      data(rv_pte_a)   := '1';         -- Accessed
    end if;

    needwblock := tmpneedwb and not was_modified;
    needwb     := tmpneedwb;
  end;

  -- Convert virtual vaddr to physical paddr, using vmask to OR correct levels.
  procedure virtual2physical(what  : va_type;
                             vaddr : std_logic_vector; mask : std_logic_vector;
                             paddr : inout std_logic_vector) is
    constant pa_tmp      : std_logic_vector := pa(what);       -- constant
    constant va_size_tmp : va_bits          := va_size(what);  -- constant
    -- Non-constant
    variable xpaddr      : std_logic_vector(pa_tmp'range) := (others => '0');
    variable pos         : integer;
  begin
    --     RISC-V requires high bits to equal MSB of VA.
    xpaddr := paddr;
    -- Loop from low bits to high
    pos := 12;
    for i in va_size_tmp'reverse_range loop
      if mask(i) = '0' then
--        set(xpaddr, pos, get(xpaddr, pos, va_size_tmp(i)) or get(vaddr, pos, va_size_tmp(i)));
        xpaddr(pos + va_size_tmp(i) - 1 downto pos) := xpaddr(pos + va_size_tmp(i) - 1 downto pos) or
                                                        vaddr(pos + va_size_tmp(i) - 1 downto pos);
      end if;
      pos := pos + va_size_tmp(i);
    end loop;

    paddr := xpaddr;
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
    constant sparc_acc : integer := to_integer(unsigned(data(PTE_ACC_U downto PTE_ACC_D)));
    constant riscv_acc : integer := to_integer(unsigned(data(rv_pte_u downto rv_pte_r)));
    -- For RISC-V
    constant is_user   : boolean := at(0) = '0';
    constant is_exec   : boolean := at(1) = '1';
    constant is_write  : boolean := at(2) = '1';
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
    constant v0 : std_logic_vector(0 to 7) := "00001011";  -- user       d load
    constant v1 : std_logic_vector(0 to 7) := "00001000";  -- supervisor d load
    constant v2 : std_logic_vector(0 to 7) := "11000111";  -- user       i load/execute
    constant v3 : std_logic_vector(0 to 7) := "11000100";  -- supervisor i load/execute
    constant v4 : std_logic_vector(0 to 7) := "10101111";  -- user       d store
    constant v5 : std_logic_vector(0 to 7) := "10101010";  -- supervisor d store
    constant v6 : std_logic_vector(0 to 7) := "11101111";  -- user       i store
    constant v7 : std_logic_vector(0 to 7) := "11101110";  -- supervisor i store
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
      if is_user /= (data(rv_pte_u) = '1') then
        err_perm    := '1';
      end if;

      if is_exec then
        if data(rv_pte_x) = '0' then
          err_perm  := '1';
        end if;
        err_sum     := err_perm;       -- SUM flag does not affect execute.
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
