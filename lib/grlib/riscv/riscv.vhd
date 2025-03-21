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
-- package:     opcodes
-- File:        opcodes.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
-- Description: Instruction definitions according to:

--              RISC-V Instruction Set Manual Volume I: User-Level ISA 2.2
--              RISC-V Instruction Set Manual Volume II: Privileged
--              Architecture 1.12
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package riscv is

  ----------------------------------------------------------------------------
  -- GPRs
  ----------------------------------------------------------------------------

  -- The calling convention is marked for the registers below.
  -- Caller is responsible for saving return address, arguments and temporaries.
  -- Callee is responsible for saving stack pointer and saved registers.

  subtype reg_t is std_logic_vector(4 downto 0);

  constant GPR_X0       : reg_t := "00000";  -- Hard-wired zero
  constant GPR_RA       : reg_t := "00001";  -- Return address
  constant GPR_SP       : reg_t := "00010";  -- Stack pointer
  constant GPR_GP       : reg_t := "00011";  -- Global pointer
  constant GPR_TP       : reg_t := "00100";  -- Thread pointer
  constant GPR_T0       : reg_t := "00101";  -- Temporaries
  constant GPR_T1       : reg_t := "00110";
  constant GPR_T2       : reg_t := "00111";
  constant GPR_FP       : reg_t := "01000";  -- Saved register/frame pointer
  constant GPR_S1       : reg_t := "01001";  -- Saved register
  constant GPR_A0       : reg_t := "01010";  -- Function arguments/return values
  constant GPR_A1       : reg_t := "01011";
  constant GPR_A2       : reg_t := "01100";  -- Function arguments
  constant GPR_A3       : reg_t := "01101";
  constant GPR_A4       : reg_t := "01110";
  constant GPR_A5       : reg_t := "01111";
  constant GPR_A6       : reg_t := "10000";
  constant GPR_A7       : reg_t := "10001";
  constant GPR_S2       : reg_t := "10010";  -- Saved registers
  constant GPR_S3       : reg_t := "10011";
  constant GPR_S4       : reg_t := "10100";
  constant GPR_S5       : reg_t := "10101";
  constant GPR_S6       : reg_t := "10110";
  constant GPR_S7       : reg_t := "10111";
  constant GPR_S8       : reg_t := "11000";
  constant GPR_S9       : reg_t := "11001";
  constant GPR_S10      : reg_t := "11010";
  constant GPR_S11      : reg_t := "11011";
  constant GPR_T3       : reg_t := "11100";  -- Temporaries
  constant GPR_T4       : reg_t := "11101";
  constant GPR_T5       : reg_t := "11110";
  constant GPR_T6       : reg_t := "11111";

  ----------------------------------------------------------------------------
  -- FPUs
  ----------------------------------------------------------------------------

  -- The calling convention is marked for the registers below.
  -- Caller is responsible for saving arguments and temporaries.
  -- Callee is responsible for saving saved registers.

  constant FPU_FT0      : reg_t := "00000";  -- Temporaries
  constant FPU_FT1      : reg_t := "00001";
  constant FPU_FT2      : reg_t := "00010";
  constant FPU_FT3      : reg_t := "00011";
  constant FPU_FT4      : reg_t := "00100";
  constant FPU_FT5      : reg_t := "00101";
  constant FPU_FT6      : reg_t := "00110";
  constant FPU_FT7      : reg_t := "00111";
  constant FPU_FS0      : reg_t := "01000";  -- Saved registers
  constant FPU_FS1      : reg_t := "01001";
  constant FPU_FA0      : reg_t := "01010";  -- Function arguments/return values
  constant FPU_FA1      : reg_t := "01011";
  constant FPU_FA2      : reg_t := "01100";  -- Function arguments
  constant FPU_FA3      : reg_t := "01101";
  constant FPU_FA4      : reg_t := "01110";
  constant FPU_FA5      : reg_t := "01111";
  constant FPU_FA6      : reg_t := "10000";
  constant FPU_FA7      : reg_t := "10001";
  constant FPU_FS2      : reg_t := "10010";  -- Saved registers
  constant FPU_FS3      : reg_t := "10011";
  constant FPU_FS4      : reg_t := "10100";
  constant FPU_FS5      : reg_t := "10101";
  constant FPU_FS6      : reg_t := "10110";
  constant FPU_FS7      : reg_t := "10111";
  constant FPU_FS8      : reg_t := "11000";
  constant FPU_FS9      : reg_t := "11001";
  constant FPU_FS10     : reg_t := "11010";
  constant FPU_FS11     : reg_t := "11011";
  constant FPU_FT8      : reg_t := "11100";  -- Temporaries
  constant FPU_FT9      : reg_t := "11101";
  constant FPU_FT10     : reg_t := "11110";
  constant FPU_FT11     : reg_t := "11111";

  -----------------------------------------------------------------------------
  -- RV32I Base Instruction Set
  -----------------------------------------------------------------------------

  -- funct12 decoding (inst(31 downto 20))

  subtype funct12_type is std_logic_vector(11 downto 0);

  constant I_ECALL      : funct12_type := "000000000000";
  constant I_EBREAK     : funct12_type := "000000000001";

  -- Zbb
  constant F12_ZEXTH      : funct12_type := "000010000000";  -- R_XOR
  constant F12_CLZ        : funct12_type := "011000000000";  -- R_SLL
  constant F12_CTZ        : funct12_type := "011000000001";  -- R_SLL
  constant F12_CPOP       : funct12_type := "011000000010";  -- R_SLL
  constant F12_SEXTB      : funct12_type := "011000000100";  -- R_SLL
  constant F12_SEXTH      : funct12_type := "011000000101";  -- R_SLL
  constant F12_REV8_RV32  : funct12_type := "011010011000";  -- R_SRL
  constant F12_REV8_RV64  : funct12_type := "011010111000";  -- R_SRL
  constant F12_ORCB       : funct12_type := "001010000111";  -- R_SRL

  -- Zbkb
  constant F12_BREV8      : funct12_type := "011010000111";  -- R_SRL
  constant F12_ZIP        : funct12_type := "000010001111";  -- R_SRL UNZIP, R_SLL ZIP

  -- funct7 decoding (inst(31 downto 25))

  subtype funct7_type is std_logic_vector(6 downto 0);

  constant F7_BASE         : funct7_type := "0000000";
  constant F7_SUB          : funct7_type := "0100000";
  constant F7_URET         : funct7_type := "0000000";
  constant F7_SRET         : funct7_type := "0001000";
  constant F7_WFI          : funct7_type := "0001000";
  constant F7_MRET         : funct7_type := "0011000";
  constant F7_MNRET        : funct7_type := "0111000";
  constant F7_SFENCE_VMA   : funct7_type := "0001001";
  constant F7_SINVAL_VMA   : funct7_type := "0001011";
  constant F7_SFENCE_INVAL : funct7_type := "0001100";  -- rs2 0 - W_INVAL, 1 - INVAL_IR
  constant F7_HFENCE_VVMA  : funct7_type := "0010001";
  constant F7_HINVAL_VVMA  : funct7_type := "0010011";
  constant F7_HFENCE_GVMA  : funct7_type := "0110001";
  constant F7_HINVAL_GVMA  : funct7_type := "0110011";
  constant F7_HLVB         : funct7_type := "0110000";
  constant F7_HLVH         : funct7_type := "0110010";
  constant F7_HLVW         : funct7_type := "0110100";
  constant F7_HLVD         : funct7_type := "0110110";
  constant F7_HSVB         : funct7_type := "0110001";
  constant F7_HSVH         : funct7_type := "0110011";
  constant F7_HSVW         : funct7_type := "0110101";
  constant F7_HSVD         : funct7_type := "0110111";

  constant F7_BASE_RV64   : funct7_type := "0000001";
  constant F7_SUB_RV64    : funct7_type := "0100001";

  -- Zba
  constant F7_ADDSLLIUW   : funct7_type := "0000100";  -- R_ADD, R_SLL (see Zbb above)
  constant F7_SLLIUW_I64  : funct7_type := "0000101";  -- R_SLL
  constant F7_SHADD       : funct7_type := "0010000";  -- 010 1, 100 2, 110 3

  -- Zbb / Zbc(CLMUL)
  constant F7_MINMAXCLMUL : funct7_type := "0000101";
  constant F7_LOGICAL_INV : funct7_type := "0100000";  -- R_XOR R_OR R_AND
  constant F7_ROT         : funct7_type := "0110000";  -- R_SLL ROL, R_SRL ROR
  constant F7_ROR_I64     : funct7_type := "0110001";  --   RV64 (>= 32)

  -- Zbs
  constant F7_BSET        : funct7_type := "0010100";  -- R_SLL (see ORCB above)
  constant F7_BSET_I64    : funct7_type := "0010101";  --   RV64 (>= 32)
  constant F7_BINV        : funct7_type := "0110100";  -- R_SLL
  constant F7_BINV_I64    : funct7_type := "0110101";  --   RV64 (>= 32)
  constant F7_BCLREXT     : funct7_type := "0100100";  -- R_SLL BCLR, R_SRL BEXT
  constant F7_BCLREXT_I64 : funct7_type := "0100101";  --   RV64 (>= 32)

  -- Zbkb
  constant F7_PACK        : funct7_type := "0000100";  -- 100 pack/packw, 111 packh (see Zba above)
  -- Zbkx
  constant F7_XPERM       : funct7_type := "0010100";  -- 100 xperm8, 010 xperm4 (see Zbs above)

  -- Zimop
--  constant F12_MOPR        : funct12_type := "1x00xx0111xx";  -- R_XOR
  constant F7_MOPR_0      : funct7_type := "1000000";  -- R_XOR (see above)
  constant F7_MOPR_4      : funct7_type := "1000010";  -- R_XOR (unused)
  constant F7_MOPR_8      : funct7_type := "1000100";  -- R_XOR (unused)
  constant F7_MOPR_12     : funct7_type := "1000110";  -- R_XOR (unused)
  constant F7_MOPR_16     : funct7_type := "1100000";  -- R_XOR (unused)
  constant F7_MOPR_20     : funct7_type := "1100010";  -- R_XOR (unused)
  constant F7_MOPR_24     : funct7_type := "1100100";  -- R_XOR (unused)
  constant F7_MOPR_28     : funct7_type := "1100110";  -- R_XOR (unused)
--  constant F7_MOPRR       : funct7_type := "1x00xx1";  -- R_XOR
  constant F7_MOPRR_0     : funct7_type := "1000001";  -- R_XOR (see below)
  constant F7_MOPRR_1     : funct7_type := "1000011";  -- R_XOR (unused)
  constant F7_MOPRR_2     : funct7_type := "1000101";  -- R_XOR (unused)
  constant F7_MOPRR_3     : funct7_type := "1000111";  -- R_XOR (unused)
  constant F7_MOPRR_4     : funct7_type := "1100001";  -- R_XOR (unused)
  constant F7_MOPRR_5     : funct7_type := "1100011";  -- R_XOR (unused)
  constant F7_MOPRR_6     : funct7_type := "1100101";  -- R_XOR (unused)
  constant F7_MOPRR_7     : funct7_type := "1100111";  -- R_XOR (unused)

  -- Zicfiss
  constant F7_SSPUSH      : funct7_type := F7_MOPRR_7;  -- R_XOR

  -- Zicond
  constant F7_CZERO       : funct7_type := "0000111";  -- R_SRL

  -- Zicfiss
  constant F12_SSRDPOPCHK : funct12_type := F7_MOPR_28 & "11100";  -- R_XOR


  -- funct3 decoding (inst(14 downto 12))

  subtype funct3_type is std_logic_vector(2 downto 0);

  -- I-Type Format
  constant I_ADDI       : funct3_type := "000";
  constant I_SLTI       : funct3_type := "010";
  constant I_SLTIU      : funct3_type := "011";
  constant I_XORI       : funct3_type := "100";
  constant I_ORI        : funct3_type := "110";
  constant I_ANDI       : funct3_type := "111";
  constant I_SLLI       : funct3_type := "001";
  constant I_SRLI       : funct3_type := "101";
  constant I_SRAI       : funct3_type := "101";

  constant I_JALR       : funct3_type := "000";

  constant I_LB         : funct3_type := "000";
  constant I_LH         : funct3_type := "001";
  constant I_LW         : funct3_type := "010";
  constant I_LBU        : funct3_type := "100";
  constant I_LHU        : funct3_type := "101";

  constant I_CSRRW      : funct3_type := "001";
  constant I_CSRRS      : funct3_type := "010";
  constant I_CSRRC      : funct3_type := "011";
  constant I_CSRRWI     : funct3_type := "101";
  constant I_CSRRSI     : funct3_type := "110";
  constant I_CSRRCI     : funct3_type := "111";

  constant I_FENCE      : funct3_type := "000";
  constant I_FENCE_I    : funct3_type := "001";
  constant I_CBO        : funct3_type := "010";

  constant I_ENV        : funct3_type := "000";

  -- R-Type Format
  constant R_ADD        : funct3_type := "000";
  constant R_SUB        : funct3_type := "000";
  constant R_SLL        : funct3_type := "001";
  constant R_SLT        : funct3_type := "010";
  constant R_SLTU       : funct3_type := "011";
  constant R_XOR        : funct3_type := "100";
  constant R_SRL        : funct3_type := "101";
  constant R_SRA        : funct3_type := "101";
  constant R_OR         : funct3_type := "110";
  constant R_AND        : funct3_type := "111";

  -- For MINMAXCLMUL
  constant R_CLMUL        : funct3_type := "001";
  constant R_CLMULR       : funct3_type := "010";
  constant R_CLMULH       : funct3_type := "011";
  constant R_MIN          : funct3_type := "100";
  constant R_MINU         : funct3_type := "101";
  constant R_MAX          : funct3_type := "110";
  constant R_MAXU         : funct3_type := "111";

  -- B-Type Format
  constant B_BEQ        : funct3_type := "000";
  constant B_BNE        : funct3_type := "001";
  constant B_BLT        : funct3_type := "100";
  constant B_BGE        : funct3_type := "101";
  constant B_BLTU       : funct3_type := "110";
  constant B_BGEU       : funct3_type := "111";

  -- S-Type Format
  constant S_SB         : funct3_type := "000";
  constant S_SH         : funct3_type := "001";
  constant S_SW         : funct3_type := "010";

  -- opcode decoding (inst(6 downto 0))

  subtype opcode_type is std_logic_vector(6 downto 0);

  -- I-Type Format
  constant OP_IMM       : opcode_type := "0010011";
  constant OP_LOAD      : opcode_type := "0000011";
  constant OP_SYSTEM    : opcode_type := "1110011";
  constant OP_FENCE     : opcode_type := "0001111";

  -- U-Type Format
  constant LUI          : opcode_type := "0110111";
  constant AUIPC        : opcode_type := "0010111";

  -- R-Type Format
  constant OP_REG       : opcode_type := "0110011";

  -- J-Type Format
  constant OP_JAL       : opcode_type := "1101111";
  constant OP_JALR      : opcode_type := "1100111";

  -- B-Type Format
  constant OP_BRANCH    : opcode_type := "1100011";

  -- S-Type Format
  constant OP_STORE     : opcode_type := "0100011";

  constant OP_CUSTOM0   : opcode_type := "0001011";
  constant OP_CUSTOM1   : opcode_type := "0101011";

  -----------------------------------------------------------------------------
  -- RV64I Base Instruction Set
  -----------------------------------------------------------------------------

  -- funct6 decoding (inst(31 downto 26))

  subtype funct6_type is std_logic_vector(5 downto 0);

  constant F6_SLL       : funct6_type := "000000";
  constant F6_SRL       : funct6_type := "000000";
  constant F6_SRA       : funct6_type := "010000";

  -- Opcode
  constant OP_IMM_32    : opcode_type := "0011011";
  constant OP_32        : opcode_type := "0111011";

  -- I-Type Format
  constant I_LWU        : funct3_type := "110";
  constant I_LD         : funct3_type := "011";
  constant I_ADDIW      : funct3_type := "000";
  constant I_SLLIW      : funct3_type := "001";
  constant I_SRLIW      : funct3_type := "101";
  constant I_SRAIW      : funct3_type := "101";

  -- S-Type Format
  constant S_SD         : funct3_type := "011";

  -- R-Type Format
  constant R_ADDW       : funct3_type := "000";
  constant R_SUBW       : funct3_type := "000";
  constant R_SLLW       : funct3_type := "001";
  constant R_SRLW       : funct3_type := "101";
  constant R_SRAW       : funct3_type := "101";

  -----------------------------------------------------------------------------
  -- RV32M Standard Extension Set
  -----------------------------------------------------------------------------

  constant F7_MUL       : funct7_type := "0000001";

  -- R-Type Format
  constant R_MUL        : funct3_type := "000";
  constant R_MULH       : funct3_type := "001";
  constant R_MULHSU     : funct3_type := "010";
  constant R_MULHU      : funct3_type := "011";
  constant R_DIV        : funct3_type := "100";
  constant R_DIVU       : funct3_type := "101";
  constant R_REM        : funct3_type := "110";
  constant R_REMU       : funct3_type := "111";

  -----------------------------------------------------------------------------
  -- RV64M Standard Extension Set
  -----------------------------------------------------------------------------

  constant R_MULW       : funct3_type := "000";
  constant R_DIVW       : funct3_type := "100";
  constant R_DIVUW      : funct3_type := "101";
  constant R_REMW       : funct3_type := "110";
  constant R_REMUW      : funct3_type := "111";

  -----------------------------------------------------------------------------
  -- RV32A Standard Extension Set
  -----------------------------------------------------------------------------

  -- funct5 decoding (inst(31 downto 27))

  subtype funct5_type is std_logic_vector(4 downto 0);

  -- Opcode
  constant OP_AMO       : opcode_type := "0101111";

  -- R-Type Format
  constant R_WORD       : funct3_type := "010";

  constant R_LR         : funct5_type := "00010";
  constant R_SC         : funct5_type := "00011";
  constant R_AMOSWAP    : funct5_type := "00001";
  constant R_AMOADD     : funct5_type := "00000";
  constant R_AMOXOR     : funct5_type := "00100";
  constant R_AMOAND     : funct5_type := "01100";
  constant R_AMOOR      : funct5_type := "01000";
  constant R_AMOMIN     : funct5_type := "10000";
  constant R_AMOMAX     : funct5_type := "10100";
  constant R_AMOMINU    : funct5_type := "11000";
  constant R_AMOMAXU    : funct5_type := "11100";

  -- Zicfiss
  constant R_SSAMOSWAP  : funct5_type := "01001";

  -----------------------------------------------------------------------------
  -- RV64A Standard Extension Set
  -----------------------------------------------------------------------------

  constant R_DOUBLE     : funct3_type := "011";

  -----------------------------------------------------------------------------
  -- RV32F Standard Extension Set
  -----------------------------------------------------------------------------

  -- funct2 decoding (inst(26 downto 25))

  subtype funct2_type is std_logic_vector(1 downto 0);

  -- Opcode
  constant OP_LOAD_FP   : opcode_type := "0000111";
  constant OP_STORE_FP  : opcode_type := "0100111";
  constant OP_FP        : opcode_type := "1010011";
  constant OP_FMADD     : opcode_type := "1000011";
  constant OP_FMSUB     : opcode_type := "1000111";
  constant OP_FNMSUB    : opcode_type := "1001011";
  constant OP_FNMADD    : opcode_type := "1001111";

  -- I-Type Format
  constant I_FLW        : funct3_type := "010";

  -- S-Type Format
  constant S_FSW        : funct3_type := "010";

  -- R4-Type Format
  constant R4_SINGLE    : funct2_type := "00";

  -- R-Type Format
  constant R_FADD       : funct5_type := "00000";
  constant R_FSUB       : funct5_type := "00001";
  constant R_FMUL       : funct5_type := "00010";
  constant R_FDIV       : funct5_type := "00011";
  constant R_FSQRT      : funct5_type := "01011";
  constant R_FSGN       : funct5_type := "00100";
  constant R_FMINMAX    : funct5_type := "00101";
  constant R_FCVT_W_S   : funct5_type := "11000";
  constant R_FCVT_S_W   : funct5_type := "11010";
  constant R_FMV_X_W    : funct5_type := "11100";
  constant R_FMV_W_X    : funct5_type := "11110";
  constant R_FCMP       : funct5_type := "10100";
  constant R_FCLASS     : funct5_type := "11100";

  constant R_FSGNJ      : funct3_type := "000";
  constant R_FSGNJN     : funct3_type := "001";
  constant R_FSGNJX     : funct3_type := "010";
  constant R_FMIN       : funct3_type := "000";
  constant R_FMAX       : funct3_type := "001";
  constant R_FEQ        : funct3_type := "010";
  constant R_FLT        : funct3_type := "001";
  constant R_FLE        : funct3_type := "000";
  constant R_CLASS      : funct3_type := "001";

  constant R_FCVT_W     : funct5_type := "00000";
  constant R_FCVT_WU    : funct5_type := "00001";

  -----------------------------------------------------------------------------
  -- RV64F Standard Extension Set
  -----------------------------------------------------------------------------

  -- R-Type Format
  constant R_FCVT_L_S   : funct5_type := "11000";
  constant R_FCVT_S_L   : funct5_type := "11010";

  constant R_FCVT_L     : funct5_type := "00010";
  constant R_FCVT_LU    : funct5_type := "00011";

  -----------------------------------------------------------------------------
  -- RV32D Standard Extension Set
  -----------------------------------------------------------------------------

  -- I-Type Format
  constant I_FLD        : funct3_type := "011";

  -- S-Type Format
  constant S_FSD        : funct3_type := "011";

  -- R4-Type Format
  constant R4_DOUBLE    : funct2_type := "01";

  -- R-Type Format
  constant R_FCVT_W_D   : funct5_type := "11000";
  constant R_FCVT_D_W   : funct5_type := "11010";
  constant R_FCVT_S_D   : funct5_type := "01000";
  constant R_FCVT_D_S   : funct5_type := "01000";

  -----------------------------------------------------------------------------
  -- RV64D Standard Extension Set
  -----------------------------------------------------------------------------

  -- R-Type Format
  constant R_FCVT_L_D   : funct5_type := "11000";
  constant R_FCVT_D_L   : funct5_type := "11010";
  constant R_FMV_X_D    : funct5_type := "11100";
  constant R_FMV_D_X    : funct5_type := "11110";

  -----------------------------------------------------------------------------
  -- NOEL-V FPU control codes for non-OP_FP operations
  -----------------------------------------------------------------------------
  constant S_LOAD       : funct5_type := "01110";
  constant S_STORE      : funct5_type := "01111";
  constant S_FMADD      : funct5_type := "10000";  -- Actually same as opcode
  constant S_FMSUB      : funct5_type := "10001";
  constant S_FNMSUB     : funct5_type := "10010";
  constant S_FNMADD     : funct5_type := "10011";


  -----------------------------------------------------------------------------
  -- Opcodes above that are actually the same
  -----------------------------------------------------------------------------
  -- R_FCVT_ S_D  D_S
  -- R_FCVT_ W_S  L_S  W_D  L_D
  -- R_FCVT_ S_W  S_L  D_W  D_L
  -- R_FMV_  W_X  D_X
  -- R_FMV_  X_W  X_D  R_FCLASS
  -- R_FMIN  R_FMAX

  -----------------------------------------------------------------------------
  -- Zfa Extension
  -----------------------------------------------------------------------------

  constant R_FMINM      : funct3_type := "010";
  constant R_FMAXM      : funct3_type := "011";
  constant R_FLTQ       : funct3_type := "101";
  constant R_FLEQ       : funct3_type := "100";
  constant R_FMVH_X_D   : funct7_type := "1110001";  -- funct3 000  rs2 1
  constant R_FMVP_D_X   : funct7_type := "1011001";  -- funct3 000
  constant R_FMVP_5_X   : funct5_type := "10110";    -- funct3 000

  -----------------------------------------------------------------------------
  -- Zfh[min] Extension
  -----------------------------------------------------------------------------

  constant R_HALF       : funct3_type := "001";

  -----------------------------------------------------------------------------
  -- Privileged Level
  -----------------------------------------------------------------------------

  subtype priv_lvl_type is std_logic_vector(1 downto 0);

  constant PRIV_LVL_U   : priv_lvl_type := "00";
  constant PRIV_LVL_S   : priv_lvl_type := "01";
  constant PRIV_LVL_M   : priv_lvl_type := "11";

  ----------------------------------------------------------------------------
  -- CSRs
  ----------------------------------------------------------------------------

  subtype csratype is std_logic_vector(11 downto 0);

  -- User Trap Setup
  constant CSR_USTATUS          : csratype := x"000";
  constant CSR_UIE              : csratype := x"004";
  constant CSR_UTVEC            : csratype := x"005";
  -- User Trap Handling
  constant CSR_USCRATCH         : csratype := x"040";
  constant CSR_UEPC             : csratype := x"041";
  constant CSR_UCAUSE           : csratype := x"042";
  constant CSR_UTVAL            : csratype := x"043";
  constant CSR_UIP              : csratype := x"044";
  -- User Floating-Point CSRs
  constant CSR_FFLAGS           : csratype := x"001";
  constant CSR_FRM              : csratype := x"002";
  constant CSR_FCSR             : csratype := x"003";
  -- Shadow stack pointer
  constant CSR_SSP              : csratype := x"011";
  -- User Counter/Timers
  constant CSR_CYCLE            : csratype := x"c00";
  constant CSR_TIME             : csratype := x"c01";
  constant CSR_INSTRET          : csratype := x"c02";
  constant CSR_HPMCOUNTER3      : csratype := x"c03";
  constant CSR_HPMCOUNTER4      : csratype := x"c04";
  constant CSR_HPMCOUNTER5      : csratype := x"c05";
  constant CSR_HPMCOUNTER6      : csratype := x"c06";
  constant CSR_HPMCOUNTER7      : csratype := x"c07";
  constant CSR_HPMCOUNTER8      : csratype := x"c08";
  constant CSR_HPMCOUNTER9      : csratype := x"c09";
  constant CSR_HPMCOUNTER10     : csratype := x"c0a";
  constant CSR_HPMCOUNTER11     : csratype := x"c0b";
  constant CSR_HPMCOUNTER12     : csratype := x"c0c";
  constant CSR_HPMCOUNTER13     : csratype := x"c0d";
  constant CSR_HPMCOUNTER14     : csratype := x"c0e";
  constant CSR_HPMCOUNTER15     : csratype := x"c0f";
  constant CSR_HPMCOUNTER16     : csratype := x"c10";
  constant CSR_HPMCOUNTER17     : csratype := x"c11";
  constant CSR_HPMCOUNTER18     : csratype := x"c12";
  constant CSR_HPMCOUNTER19     : csratype := x"c13";
  constant CSR_HPMCOUNTER20     : csratype := x"c14";
  constant CSR_HPMCOUNTER21     : csratype := x"c15";
  constant CSR_HPMCOUNTER22     : csratype := x"c16";
  constant CSR_HPMCOUNTER23     : csratype := x"c17";
  constant CSR_HPMCOUNTER24     : csratype := x"c18";
  constant CSR_HPMCOUNTER25     : csratype := x"c19";
  constant CSR_HPMCOUNTER26     : csratype := x"c1a";
  constant CSR_HPMCOUNTER27     : csratype := x"c1b";
  constant CSR_HPMCOUNTER28     : csratype := x"c1c";
  constant CSR_HPMCOUNTER29     : csratype := x"c1d";
  constant CSR_HPMCOUNTER30     : csratype := x"c1e";
  constant CSR_HPMCOUNTER31     : csratype := x"c1f";
  -- High (RV32)
  constant CSR_CYCLEH           : csratype := x"c80";
  constant CSR_TIMEH            : csratype := x"c81";
  constant CSR_INSTRETH         : csratype := x"c82";
  constant CSR_HPMCOUNTER3H     : csratype := x"c83";
  constant CSR_HPMCOUNTER4H     : csratype := x"c84";
  constant CSR_HPMCOUNTER5H     : csratype := x"c85";
  constant CSR_HPMCOUNTER6H     : csratype := x"c86";
  constant CSR_HPMCOUNTER7H     : csratype := x"c87";
  constant CSR_HPMCOUNTER8H     : csratype := x"c88";
  constant CSR_HPMCOUNTER9H     : csratype := x"c89";
  constant CSR_HPMCOUNTER10H    : csratype := x"c8a";
  constant CSR_HPMCOUNTER11H    : csratype := x"c8b";
  constant CSR_HPMCOUNTER12H    : csratype := x"c8c";
  constant CSR_HPMCOUNTER13H    : csratype := x"c8d";
  constant CSR_HPMCOUNTER14H    : csratype := x"c8e";
  constant CSR_HPMCOUNTER15H    : csratype := x"c8f";
  constant CSR_HPMCOUNTER16H    : csratype := x"c90";
  constant CSR_HPMCOUNTER17H    : csratype := x"c91";
  constant CSR_HPMCOUNTER18H    : csratype := x"c92";
  constant CSR_HPMCOUNTER19H    : csratype := x"c93";
  constant CSR_HPMCOUNTER20H    : csratype := x"c94";
  constant CSR_HPMCOUNTER21H    : csratype := x"c95";
  constant CSR_HPMCOUNTER22H    : csratype := x"c96";
  constant CSR_HPMCOUNTER23H    : csratype := x"c97";
  constant CSR_HPMCOUNTER24H    : csratype := x"c98";
  constant CSR_HPMCOUNTER25H    : csratype := x"c99";
  constant CSR_HPMCOUNTER26H    : csratype := x"c9a";
  constant CSR_HPMCOUNTER27H    : csratype := x"c9b";
  constant CSR_HPMCOUNTER28H    : csratype := x"c9c";
  constant CSR_HPMCOUNTER29H    : csratype := x"c9d";
  constant CSR_HPMCOUNTER30H    : csratype := x"c9e";
  constant CSR_HPMCOUNTER31H    : csratype := x"c9f";

  -- Supervisor Trap Setup
  constant CSR_SSTATUS          : csratype := x"100";
  constant CSR_SEDELEG          : csratype := x"102";
  constant CSR_SIDELEG          : csratype := x"103";
  constant CSR_SIE              : csratype := x"104";
  constant CSR_STVEC            : csratype := x"105";
  constant CSR_SCOUNTEREN       : csratype := x"106";
  -- Supervisor Configuration
  constant CSR_SENVCFG          : csratype := x"10a";
  -- Supervisor Trap Handling
  constant CSR_SSCRATCH         : csratype := x"140";
  constant CSR_SEPC             : csratype := x"141";
  constant CSR_SCAUSE           : csratype := x"142";
  constant CSR_STVAL            : csratype := x"143";
  constant CSR_SIP              : csratype := x"144";

  -- Supervisor AIA (Smaia or Ssaia)
  constant CSR_SISELECT         : csratype := x"150";
  constant CSR_SIREG            : csratype := x"151";
  constant CSR_SIREG2           : csratype := x"152";
  constant CSR_SIREG3           : csratype := x"153";
  constant CSR_SIREG4           : csratype := x"155";
  constant CSR_SIREG5           : csratype := x"156";
  constant CSR_SIREG6           : csratype := x"157";
  constant CSR_STOPEI           : csratype := x"15c";
  constant CSR_STOPI            : csratype := x"db0";
  -- High (RV32)
  constant CSR_SIEH             : csratype := x"114";
  constant CSR_SIPH             : csratype := x"154";

  -- Supervisor State Enable (Smstateen)
  constant CSR_SSTATEEN0        : csratype := x"10c";
  constant CSR_SSTATEEN1        : csratype := x"10d";
  constant CSR_SSTATEEN2        : csratype := x"10e";
  constant CSR_SSTATEEN3        : csratype := x"10f";
 
  constant CSR_STIMECMP         : csratype := x"14d";
  constant CSR_STIMECMPH        : csratype := x"15d";
  -- Supervisor Protection and Translation
  constant CSR_SATP             : csratype := x"180";
  -- Supervisor Count Overflow
  constant CSR_SCOUNTOVF        : csratype := x"da0";

  -- Hypervisor Trap Setup
  constant CSR_HSTATUS          : csratype := x"600";
  constant CSR_HEDELEG          : csratype := x"602";
  constant CSR_HIDELEG          : csratype := x"603";
  constant CSR_HIE              : csratype := x"604";
  constant CSR_HCOUNTEREN       : csratype := x"606";
  constant CSR_HGEIE            : csratype := x"607";
  -- Hypervisor Trap Handling
  constant CSR_HTVAL            : csratype := x"643";
  constant CSR_HIP              : csratype := x"644";
  constant CSR_HVIP             : csratype := x"645";
  constant CSR_HTINST           : csratype := x"64a";
  constant CSR_HGEIP            : csratype := x"e12";
  -- Hypervisor Configuration
  constant CSR_HENVCFG          : csratype := x"60a";
  constant CSR_HENVCFGH         : csratype := x"61a";
  -- Hypervisor Protection and Translation
  constant CSR_HGATP            : csratype := x"680";
  -- Hypervisor Counter/Timer Virtualization Registers
  constant CSR_HTIMEDELTA       : csratype := x"605";
  -- High (RV32)
  constant CSR_HTIMEDELTAH      : csratype := x"615";

  -- Virtual Supervisor Registers
  constant CSR_VSSTATUS         : csratype := x"200";
  constant CSR_VSIE             : csratype := x"204";
  constant CSR_VSTVEC           : csratype := x"205";
  constant CSR_VSSCRATCH        : csratype := x"240";
  constant CSR_VSEPC            : csratype := x"241";
  constant CSR_VSCAUSE          : csratype := x"242";
  constant CSR_VSTVAL           : csratype := x"243";
  constant CSR_VSIP             : csratype := x"244";
  constant CSR_VSTIMECMP        : csratype := x"24d";
  constant CSR_VSTIMECMPH       : csratype := x"25d";
  constant CSR_VSATP            : csratype := x"280";

  -- Virtual Supervisor AIA (Smaia or Ssaia)
  constant CSR_HVIEN            : csratype := x"608";
  constant CSR_HVICTL           : csratype := x"609";
  constant CSR_HVIPRIO1         : csratype := x"646";
  constant CSR_HVIPRIO2         : csratype := x"647";
  constant CSR_VSISELECT        : csratype := x"250";
  constant CSR_VSIREG           : csratype := x"251";
  constant CSR_VSIREG2          : csratype := x"252";
  constant CSR_VSIREG3          : csratype := x"253";
  constant CSR_VSIREG4          : csratype := x"255";
  constant CSR_VSIREG5          : csratype := x"256";
  constant CSR_VSIREG6          : csratype := x"257";
  constant CSR_VSTOPEI          : csratype := x"25c";
  constant CSR_VSTOPI           : csratype := x"eb0";
  -- High (RV32)
  constant CSR_HIDELEGH         : csratype := x"613";
  constant CSR_HVIENH           : csratype := x"618";
  constant CSR_HVIPH            : csratype := x"655";
  constant CSR_HVIPRIO1H        : csratype := x"656";
  constant CSR_HVIPRIO2H        : csratype := x"657";
  constant CSR_VSIEH            : csratype := x"214";
  constant CSR_VSIPH            : csratype := x"254";

  -- Hypervisor State Enable (Smstateen)
  constant CSR_HSTATEEN0        : csratype := x"60c";
  constant CSR_HSTATEEN1        : csratype := x"60d";
  constant CSR_HSTATEEN2        : csratype := x"60e";
  constant CSR_HSTATEEN3        : csratype := x"60f";
  -- High (RV32)
  constant CSR_HSTATEEN0H       : csratype := x"61c";
  constant CSR_HSTATEEN1H       : csratype := x"61d";
  constant CSR_HSTATEEN2H       : csratype := x"61e";
  constant CSR_HSTATEEN3H       : csratype := x"61f";

  -- Machine Information Registers
  constant CSR_MVENDORID        : csratype := x"f11";
  constant CSR_MARCHID          : csratype := x"f12";
  constant CSR_MIMPID           : csratype := x"f13";
  constant CSR_MHARTID          : csratype := x"f14";
  constant CSR_MCONFIGPTR       : csratype := x"f15";
  -- Machine Trap Setup
  constant CSR_MSTATUS          : csratype := x"300";
  constant CSR_MISA             : csratype := x"301";
  constant CSR_MEDELEG          : csratype := x"302";
  constant CSR_MIDELEG          : csratype := x"303";
  constant CSR_MIE              : csratype := x"304";
  constant CSR_MTVEC            : csratype := x"305";
  constant CSR_MCOUNTEREN       : csratype := x"306";
  -- High (RV32)
  constant CSR_MSTATUSH         : csratype := x"310";
  -- Machine Trap Handling
  constant CSR_MSCRATCH         : csratype := x"340";
  constant CSR_MEPC             : csratype := x"341";
  constant CSR_MCAUSE           : csratype := x"342";
  constant CSR_MTVAL            : csratype := x"343";
  constant CSR_MIP              : csratype := x"344";
  constant CSR_MTINST           : csratype := x"34a";
  constant CSR_MTVAL2           : csratype := x"34b";
  -- RNMI Trap Handling
  constant CSR_MNSCRATCH        : csratype := x"740";
  constant CSR_MNEPC            : csratype := x"741";
  constant CSR_MNCAUSE          : csratype := x"742";
  constant CSR_MNSTATUS         : csratype := x"744";
  -- Machine AIA (Smaia)
  constant CSR_MISELECT         : csratype := x"350";
  constant CSR_MIREG            : csratype := x"351";
  constant CSR_MIREG2           : csratype := x"352";
  constant CSR_MIREG3           : csratype := x"353";
  constant CSR_MIREG4           : csratype := x"355";
  constant CSR_MIREG5           : csratype := x"356";
  constant CSR_MIREG6           : csratype := x"357";
  constant CSR_MTOPEI           : csratype := x"35c";
  constant CSR_MTOPI            : csratype := x"fb0";
  constant CSR_MVIEN            : csratype := x"308";
  constant CSR_MVIP             : csratype := x"309";
  -- High (RV32)
  constant CSR_MIDELEGH         : csratype := x"313";
  constant CSR_MIEH             : csratype := x"314";
  constant CSR_MVIENH           : csratype := x"318";
  constant CSR_MVIPH            : csratype := x"319";
  constant CSR_MIPH             : csratype := x"354";
  -- Machine State Enable (Smstateen)
  constant CSR_MSTATEEN0        : csratype := x"30c";
  constant CSR_MSTATEEN1        : csratype := x"30d";
  constant CSR_MSTATEEN2        : csratype := x"30e";
  constant CSR_MSTATEEN3        : csratype := x"30f";
  -- High (RV32)
  constant CSR_MSTATEEN0H       : csratype := x"31c";
  constant CSR_MSTATEEN1H       : csratype := x"31d";
  constant CSR_MSTATEEN2H       : csratype := x"31e";
  constant CSR_MSTATEEN3H       : csratype := x"31f";

  -- Machine Configuration
  constant CSR_MENVCFG          : csratype := x"30a";
  constant CSR_MENVCFGH         : csratype := x"31a";
  constant CSR_MSECCFG          : csratype := x"747";
  constant CSR_MSECCFGH         : csratype := x"757";
  -- Machine Protection and Translation
  constant CSR_PMPCFG0          : csratype := x"3a0";
  constant CSR_PMPCFG1          : csratype := x"3a1";
  constant CSR_PMPCFG2          : csratype := x"3a2";
  constant CSR_PMPCFG3          : csratype := x"3a3";
  constant CSR_PMPADDR0         : csratype := x"3b0";
  constant CSR_PMPADDR1         : csratype := x"3b1";
  constant CSR_PMPADDR2         : csratype := x"3b2";
  constant CSR_PMPADDR3         : csratype := x"3b3";
  constant CSR_PMPADDR4         : csratype := x"3b4";
  constant CSR_PMPADDR5         : csratype := x"3b5";
  constant CSR_PMPADDR6         : csratype := x"3b6";
  constant CSR_PMPADDR7         : csratype := x"3b7";
  constant CSR_PMPADDR8         : csratype := x"3b8";
  constant CSR_PMPADDR9         : csratype := x"3b9";
  constant CSR_PMPADDR10        : csratype := x"3ba";
  constant CSR_PMPADDR11        : csratype := x"3bb";
  constant CSR_PMPADDR12        : csratype := x"3bc";
  constant CSR_PMPADDR13        : csratype := x"3bd";
  constant CSR_PMPADDR14        : csratype := x"3be";
  constant CSR_PMPADDR15        : csratype := x"3bf";
  -- Machine Counter/Timers
  constant CSR_MCYCLE           : csratype := x"b00";
  constant CSR_MINSTRET         : csratype := x"b02";
  constant CSR_MHPMCOUNTER3     : csratype := x"b03";
  constant CSR_MHPMCOUNTER4     : csratype := x"b04";
  constant CSR_MHPMCOUNTER5     : csratype := x"b05";
  constant CSR_MHPMCOUNTER6     : csratype := x"b06";
  constant CSR_MHPMCOUNTER7     : csratype := x"b07";
  constant CSR_MHPMCOUNTER8     : csratype := x"b08";
  constant CSR_MHPMCOUNTER9     : csratype := x"b09";
  constant CSR_MHPMCOUNTER10    : csratype := x"b0a";
  constant CSR_MHPMCOUNTER11    : csratype := x"b0b";
  constant CSR_MHPMCOUNTER12    : csratype := x"b0c";
  constant CSR_MHPMCOUNTER13    : csratype := x"b0d";
  constant CSR_MHPMCOUNTER14    : csratype := x"b0e";
  constant CSR_MHPMCOUNTER15    : csratype := x"b0f";
  constant CSR_MHPMCOUNTER16    : csratype := x"b10";
  constant CSR_MHPMCOUNTER17    : csratype := x"b11";
  constant CSR_MHPMCOUNTER18    : csratype := x"b12";
  constant CSR_MHPMCOUNTER19    : csratype := x"b13";
  constant CSR_MHPMCOUNTER20    : csratype := x"b14";
  constant CSR_MHPMCOUNTER21    : csratype := x"b15";
  constant CSR_MHPMCOUNTER22    : csratype := x"b16";
  constant CSR_MHPMCOUNTER23    : csratype := x"b17";
  constant CSR_MHPMCOUNTER24    : csratype := x"b18";
  constant CSR_MHPMCOUNTER25    : csratype := x"b19";
  constant CSR_MHPMCOUNTER26    : csratype := x"b1a";
  constant CSR_MHPMCOUNTER27    : csratype := x"b1b";
  constant CSR_MHPMCOUNTER28    : csratype := x"b1c";
  constant CSR_MHPMCOUNTER29    : csratype := x"b1d";
  constant CSR_MHPMCOUNTER30    : csratype := x"b1e";
  constant CSR_MHPMCOUNTER31    : csratype := x"b1f";
  -- High (RV32)
  constant CSR_MCYCLEH          : csratype := x"b80";
  constant CSR_MINSTRETH        : csratype := x"b82";
  constant CSR_MHPMCOUNTER3H    : csratype := x"b83";
  constant CSR_MHPMCOUNTER4H    : csratype := x"b84";
  constant CSR_MHPMCOUNTER5H    : csratype := x"b85";
  constant CSR_MHPMCOUNTER6H    : csratype := x"b86";
  constant CSR_MHPMCOUNTER7H    : csratype := x"b87";
  constant CSR_MHPMCOUNTER8H    : csratype := x"b88";
  constant CSR_MHPMCOUNTER9H    : csratype := x"b89";
  constant CSR_MHPMCOUNTER10H   : csratype := x"b8a";
  constant CSR_MHPMCOUNTER11H   : csratype := x"b8b";
  constant CSR_MHPMCOUNTER12H   : csratype := x"b8c";
  constant CSR_MHPMCOUNTER13H   : csratype := x"b8d";
  constant CSR_MHPMCOUNTER14H   : csratype := x"b8e";
  constant CSR_MHPMCOUNTER15H   : csratype := x"b8f";
  constant CSR_MHPMCOUNTER16H   : csratype := x"b90";
  constant CSR_MHPMCOUNTER17H   : csratype := x"b91";
  constant CSR_MHPMCOUNTER18H   : csratype := x"b92";
  constant CSR_MHPMCOUNTER19H   : csratype := x"b93";
  constant CSR_MHPMCOUNTER20H   : csratype := x"b94";
  constant CSR_MHPMCOUNTER21H   : csratype := x"b95";
  constant CSR_MHPMCOUNTER22H   : csratype := x"b96";
  constant CSR_MHPMCOUNTER23H   : csratype := x"b97";
  constant CSR_MHPMCOUNTER24H   : csratype := x"b98";
  constant CSR_MHPMCOUNTER25H   : csratype := x"b99";
  constant CSR_MHPMCOUNTER26H   : csratype := x"b9a";
  constant CSR_MHPMCOUNTER27H   : csratype := x"b9b";
  constant CSR_MHPMCOUNTER28H   : csratype := x"b9c";
  constant CSR_MHPMCOUNTER29H   : csratype := x"b9d";
  constant CSR_MHPMCOUNTER30H   : csratype := x"b9e";
  constant CSR_MHPMCOUNTER31H   : csratype := x"b9f";
  -- Machine Counter Setup
  constant CSR_MCOUNTINHIBIT    : csratype := x"320";
  constant CSR_MHPMEVENT3       : csratype := x"323";
  constant CSR_MHPMEVENT4       : csratype := x"324";
  constant CSR_MHPMEVENT5       : csratype := x"325";
  constant CSR_MHPMEVENT6       : csratype := x"326";
  constant CSR_MHPMEVENT7       : csratype := x"327";
  constant CSR_MHPMEVENT8       : csratype := x"328";
  constant CSR_MHPMEVENT9       : csratype := x"329";
  constant CSR_MHPMEVENT10      : csratype := x"32a";
  constant CSR_MHPMEVENT11      : csratype := x"32b";
  constant CSR_MHPMEVENT12      : csratype := x"32c";
  constant CSR_MHPMEVENT13      : csratype := x"32d";
  constant CSR_MHPMEVENT14      : csratype := x"32e";
  constant CSR_MHPMEVENT15      : csratype := x"32f";
  constant CSR_MHPMEVENT16      : csratype := x"330";
  constant CSR_MHPMEVENT17      : csratype := x"331";
  constant CSR_MHPMEVENT18      : csratype := x"332";
  constant CSR_MHPMEVENT19      : csratype := x"333";
  constant CSR_MHPMEVENT20      : csratype := x"334";
  constant CSR_MHPMEVENT21      : csratype := x"335";
  constant CSR_MHPMEVENT22      : csratype := x"336";
  constant CSR_MHPMEVENT23      : csratype := x"337";
  constant CSR_MHPMEVENT24      : csratype := x"338";
  constant CSR_MHPMEVENT25      : csratype := x"339";
  constant CSR_MHPMEVENT26      : csratype := x"33a";
  constant CSR_MHPMEVENT27      : csratype := x"33b";
  constant CSR_MHPMEVENT28      : csratype := x"33c";
  constant CSR_MHPMEVENT29      : csratype := x"33d";
  constant CSR_MHPMEVENT30      : csratype := x"33e";
  constant CSR_MHPMEVENT31      : csratype := x"33f";
  constant CSR_MHPMEVENT0H      : csratype := x"720";  -- Does not exist!
  constant CSR_MHPMEVENT3H      : csratype := x"723";
  constant CSR_MHPMEVENT4H      : csratype := x"724";
  constant CSR_MHPMEVENT5H      : csratype := x"725";
  constant CSR_MHPMEVENT6H      : csratype := x"726";
  constant CSR_MHPMEVENT7H      : csratype := x"727";
  constant CSR_MHPMEVENT8H      : csratype := x"728";
  constant CSR_MHPMEVENT9H      : csratype := x"729";
  constant CSR_MHPMEVENT10H     : csratype := x"72a";
  constant CSR_MHPMEVENT11H     : csratype := x"72b";
  constant CSR_MHPMEVENT12H     : csratype := x"72c";
  constant CSR_MHPMEVENT13H     : csratype := x"72d";
  constant CSR_MHPMEVENT14H     : csratype := x"72e";
  constant CSR_MHPMEVENT15H     : csratype := x"72f";
  constant CSR_MHPMEVENT16H     : csratype := x"730";
  constant CSR_MHPMEVENT17H     : csratype := x"731";
  constant CSR_MHPMEVENT18H     : csratype := x"732";
  constant CSR_MHPMEVENT19H     : csratype := x"733";
  constant CSR_MHPMEVENT20H     : csratype := x"734";
  constant CSR_MHPMEVENT21H     : csratype := x"735";
  constant CSR_MHPMEVENT22H     : csratype := x"736";
  constant CSR_MHPMEVENT23H     : csratype := x"737";
  constant CSR_MHPMEVENT24H     : csratype := x"738";
  constant CSR_MHPMEVENT25H     : csratype := x"739";
  constant CSR_MHPMEVENT26H     : csratype := x"73a";
  constant CSR_MHPMEVENT27H     : csratype := x"73b";
  constant CSR_MHPMEVENT28H     : csratype := x"73c";
  constant CSR_MHPMEVENT29H     : csratype := x"73d";
  constant CSR_MHPMEVENT30H     : csratype := x"73e";
  constant CSR_MHPMEVENT31H     : csratype := x"73f";

  -- Debug/Trace Registers
  constant CSR_TSELECT          : csratype := x"7a0";
  constant CSR_TDATA1           : csratype := x"7a1";
  constant CSR_TDATA2           : csratype := x"7a2";
  constant CSR_TDATA3           : csratype := x"7a3";
  constant CSR_TINFO            : csratype := x"7a4";
  constant CSR_TCONTROL         : csratype := x"7a5";
  constant CSR_HCONTEXT         : csratype := x"6a8";
  constant CSR_MCONTEXT         : csratype := x"7a8";
  constant CSR_SCONTEXT         : csratype := x"5a8"; -- New address in V 1.0 of the spec
  constant CSR_MSCONTEXT        : csratype := x"7aa";
  -- Debug Mode Registers
  constant CSR_DCSR             : csratype := x"7b0";
  constant CSR_DPC              : csratype := x"7b1";
  constant CSR_DSCRATCH0        : csratype := x"7b2";
  constant CSR_DSCRATCH1        : csratype := x"7b3";
  -- Custom Read/Write Registers
  constant CSR_FEATURES         : csratype := x"7c0";
  constant CSR_CCTRL            : csratype := x"7c1";
  constant CSR_TCMICTRL         : csratype := x"7c2";
  constant CSR_TCMDCTRL         : csratype := x"7c3";
  constant CSR_FT               : csratype := x"7c4";
  constant CSR_EINJECT          : csratype := x"7c5";
  constant CSR_DFEATURES        : csratype := x"7c6";
  constant CSR_FEATURESH        : csratype := x"7d0";
  constant CSR_CCTRLH           : csratype := x"7d1";
  constant CSR_TCMICTRLH        : csratype := x"7d2";
  constant CSR_TCMDCTRLH        : csratype := x"7d3";
  constant CSR_FTH              : csratype := x"7d4";
  constant CSR_EINJECTH         : csratype := x"7d5";
  constant CSR_DFEATURESH       : csratype := x"7d6";
  -- Custom Read-only Registers
  constant CSR_CAPABILITY       : csratype := x"fc0";
  constant CSR_CAPABILITYH      : csratype := x"fd0";
  -- Custom Read/Write Unprivileged Registers


  constant DCAUSE_EBREAK        : std_logic_vector(2 downto 0) := "001";
  constant DCAUSE_TRIG          : std_logic_vector(2 downto 0) := "010";
  constant DCAUSE_HALT          : std_logic_vector(2 downto 0) := "011";
  constant DCAUSE_STEP          : std_logic_vector(2 downto 0) := "100";
  constant DCAUSE_RSTHALT       : std_logic_vector(2 downto 0) := "101";
  constant DCAUSE_GROUPHALT     : std_logic_vector(2 downto 0) := "110";
  constant DCAUSE_EXTENDED      : std_logic_vector(2 downto 0) := "111";
  constant EXTDCAUSE_CRITERROR  : std_logic_vector(2 downto 0) := "000";

  function rd(inst : std_logic_vector) return reg_t;
  function rs1(inst : std_logic_vector) return reg_t;
  function rs2(inst : std_logic_vector) return reg_t;
  function rs3(inst : std_logic_vector) return reg_t;
  function opcode(inst : std_logic_vector) return opcode_type;
  function funct3(inst : std_logic_vector) return funct3_type;
  function funct5(inst : std_logic_vector) return funct5_type;
  function funct7(inst : std_logic_vector) return funct7_type;
  function funct12(inst : std_logic_vector) return funct12_type;
  function get_rd(inst : std_logic_vector) return reg_t;
  function get_funct3(inst : std_logic_vector) return funct3_type;
  function get_funct7(inst : std_logic_vector) return funct7_type;
  function get_opcode(inst : std_logic_vector) return opcode_type;
--  function get_rs1(inst : std_logic_vector) return std_logic_vector;
--  function get_rs2(inst : std_logic_vector) return std_logic_vector;
--  function get_rs3(inst : std_logic_vector) return std_logic_vector;

end;

package body riscv is

  function rd(inst : std_logic_vector) return reg_t is
    variable r : reg_t := inst(11 downto 7);
  begin
    return r;
  end;

  function rs1(inst : std_logic_vector) return reg_t is
    variable r : reg_t := inst(19 downto 15);
  begin
    return r;
  end;

  function rs2(inst : std_logic_vector) return reg_t is
    variable r : reg_t := inst(24 downto 20);
  begin
    return r;
  end;

  function rs3(inst : std_logic_vector) return reg_t is
    variable r : reg_t := inst(31 downto 27);
  begin
    return r;
  end;

  function opcode(inst : std_logic_vector) return opcode_type is
    variable r : opcode_type := inst(6 downto 0);
  begin
    return r;
  end;

  function funct3(inst : std_logic_vector) return funct3_type is
    variable r : funct3_type := inst(14 downto 12);
  begin
    return r;
  end;

  function funct5(inst : std_logic_vector) return funct5_type is
    variable r : funct5_type := inst(31 downto 27);
  begin
    return r;
  end;

  function funct7(inst : std_logic_vector) return funct7_type is
    variable r : funct7_type := inst(31 downto 25);
  begin
    return r;
  end;

  function funct12(inst : std_logic_vector) return funct12_type is
    variable r : funct12_type := inst(31 downto 20);
  begin
    return r;
  end;

  function get_rd(inst : std_logic_vector) return reg_t is
  begin
    return rd(inst);
  end;

  function get_funct3(inst : std_logic_vector) return funct3_type is
  begin
    return funct3(inst);
  end;

  function get_funct7(inst : std_logic_vector) return funct7_type is
  begin
    return funct7(inst);
  end;

  function get_opcode(inst : std_logic_vector) return opcode_type is
  begin
    return opcode(inst);
  end;

end;
