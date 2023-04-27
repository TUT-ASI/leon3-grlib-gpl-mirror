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
-- Package: 	riscv_disas
-- File:	riscv_disas.vhd
-- Author:	Andrea Merlo, Gaisler Research AB
-- Description:	RISC-V disassembler according to:

--              RISC-V Instruction Set Manual Volume I: User-Level ISA 2.2
--              RISC-V Instruction Set Manual Volume II: Privileged
--              Architecture 1.12
------------------------------------------------------------------------------

-- pragma translate_off

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use grlib.riscv.all;
use grlib.testlib.print;
use std.textio.all;

package riscv_disas is

  ----------------------------------------------------------------------------
  -- Function and Procedure Declarations
  ----------------------------------------------------------------------------

  function tostf(v : std_logic_vector) return string;
  function csr2str(reg : csratype) return string;

  function fpreg2st(reg : reg_t) return string;
  function reg2st(reg : reg_t) return string;
  function prv2string(prv : std_logic_vector(1 downto 0); v : std_ulogic) return string;

  function insn2st(pc           : std_logic_vector;
                   insn         : std_logic_vector(31 downto 0);
                   cinsn        : std_logic_vector(15 downto 0);
                   comp         : std_ulogic) return string;

  function cause2string(cause : std_logic_vector) return string;

  procedure print_insn(hndx     : integer;
                       way      : integer;
                       cycle    : integer;
                       instret  : integer;
                       cdual    : integer;
                       valid    : std_ulogic;
                       pc       : std_logic_vector;
                       rd       : reg_t;
                       csr      : csratype;
                       wrdata   : std_logic_vector;
                       fsd      : std_ulogic;
                       fsd_hi   : std_logic_vector;
                       wren     : std_ulogic;
                       wren_f   : std_ulogic;
                       wcdata   : std_logic_vector;
                       wcen     : std_ulogic;
                       inst     : std_logic_vector(31 downto 0);
                       cinst    : std_logic_vector(15 downto 0);
                       comp     : std_ulogic;
                       prv      : std_logic_vector(1 downto 0);
                       trap     : std_ulogic;
                       cause    : std_logic_vector;
                       tval     : std_logic_vector);

  procedure print_insn3(
    hndx     : integer;
    way      : integer;
    cycle    : integer;
    instret  : integer;
    cdual    : integer;
    valid    : std_ulogic;
    pc       : std_logic_vector;
    rd       : reg_t;
    csr      : csratype;
    wrdata   : std_logic_vector;
    fsd      : std_ulogic;
    fsd_hi   : std_logic_vector;
    wren     : std_ulogic;
    wren_f   : std_ulogic;
    wcdata   : std_logic_vector;
    wcen     : std_ulogic;
    inst     : std_logic_vector(31 downto 0);
    cinst    : std_logic_vector(15 downto 0);
    comp     : std_ulogic;
    prv      : std_logic_vector(1 downto 0);
    v        : std_ulogic;
    trap     : std_ulogic;
    cause    : std_logic_vector;
    tval     : std_logic_vector);



  procedure print_spike_special(valid      : std_ulogic;
                                pc         : std_logic_vector;
                                csr        : csratype;
                                wrdata     : std_logic_vector;
                                fsd        : std_ulogic;
                                fsd_hi     : std_logic_vector;
                                wren       : std_ulogic;
                                wren_f     : std_ulogic;
                                wcdata     : std_logic_vector;
                                wcen       : std_ulogic;
                                inst       : std_logic_vector(31 downto 0);
                                cinst      : std_logic_vector(15 downto 0);
                                comp       : std_ulogic;
                                prv        : std_logic_vector(1 downto 0);
                                trap       : std_ulogic;
                                cause      : std_logic_vector;
                                tval       : std_logic_vector);


end;

package body riscv_disas is

  constant PRINT_ALL    : boolean := false;

  ----------------------------------------------------------------------------
  -- Misc Functions and Procedures
  ----------------------------------------------------------------------------

  type base_type is (hex, dec);

  subtype nibble is std_logic_vector(3 downto 0);

  type reg_type is record
    pc  : std_logic_vector(63 downto 0);
    rs1 : std_logic_vector(63 downto 0);
    rs2 : std_logic_vector(63 downto 0);
    rs3 : std_logic_vector(63 downto 0);
  end record;

  function tostd(v : std_logic_vector) return string;
  function tosth(v : std_logic_vector) return string;

  function tohex(n : nibble) return character is
  begin
    case n is
      when "0000" => return '0';
      when "0001" => return '1';
      when "0010" => return '2';
      when "0011" => return '3';
      when "0100" => return '4';
      when "0101" => return '5';
      when "0110" => return '6';
      when "0111" => return '7';
      when "1000" => return '8';
      when "1001" => return '9';
      when "1010" => return 'a';
      when "1011" => return 'b';
      when "1100" => return 'c';
      when "1101" => return 'd';
      when "1110" => return 'e';
      when "1111" => return 'f';
      when others => return 'X';
    end case;
  end;

  type carr is array (0 to 9) of character;

  constant darr : carr := ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9');

  function tosth(v : std_logic_vector) return string is
    constant vlen : natural := v'length; --'
    constant slen : natural := (vlen + 3) / 4;
    variable vv   : std_logic_vector(vlen - 1 downto 0);
    variable s    : string(1 to slen);
  begin
    vv := v;
    for i in slen downto 1 loop
      s(i) := tohex(vv(3 downto 0));
      vv   := "0000" & vv(vlen - 1 downto 4);
    end loop;

    return s;
  end;

  function tostf(v : std_logic_vector) return string is
    constant vlen : natural := v'length; --'
    constant slen : natural := (vlen + 3) / 4;
    variable vv   : std_logic_vector(vlen - 1 downto 0);
    variable s    : string(1 to slen);
  begin
    vv := v;
    for i in slen downto 1 loop
      s(i) := tohex(vv(3 downto 0));
      vv   := "0000" & vv(vlen - 1 downto 4);
    end loop;

    return "0x" & s;
  end;

  function tostd(n : integer) return string is
    variable len : integer := 0;
    variable tmp : string(10 downto 1);
    variable v   : integer := n;
  begin
    for i in 0 to 9 loop
      tmp(i + 1) := darr(v mod 10);
      if tmp(i + 1) /= '0'  then
        len := i;
      end if;
      v := v / 10;
    end loop;

    return tmp(len+1 downto 1);
  end;

  function tostd(v : std_logic_vector) return string is
    variable val : integer;
  begin
    val := conv_integer(v);

    return tostd(val);
  end;

  function tosti(v : std_logic_vector) return string is
    variable n : integer;
  begin
    if v(v'high) = '1' then
      n := conv_integer(not(v) + 1);
    else
      n := conv_integer(v);
    end if;
    if v(v'high) = '1' then
      return '-' & tostd(n);
    else
      return tost(n);
    end if;
  end;

  ----------------------------------------------------------------------------
  -- Instruction Functions and Procedures
  ----------------------------------------------------------------------------
  function is_ld_sd(inst : std_logic_vector(31 downto 0)) return std_logic is
    variable opcode : opcode_type := inst(6 downto 0);
    constant funct3 : funct3_type := inst(14 downto 12);
  begin
    case opcode is
      when OP_LOAD  => return '1';
      when OP_STORE => return '1';
      when OP_AMO   => return '1';
      when OP_SYSTEM => 
        if funct3 = "100" then
          return '1'; 
        else
          return '0';
        end if;
      when OP_CUSTOM0 => 
        if funct3(1 downto 0) = "10" or funct3(1 downto 0) = "11" then
          return '1'; 
        else
          return '0';
        end if;
      when others   => return '0';
    end case;
  end;

  function prv2string(prv : std_logic_vector(1 downto 0); v : std_ulogic) return string is
  begin
    if v = '0' then
      case prv is
        when PRIV_LVL_M => return " M";
        when PRIV_LVL_S => return " S";
        when PRIV_LVL_U => return " U";
        when others     => return "XX";
      end case;
    else
      case prv is
        when PRIV_LVL_S => return "VS";
        when PRIV_LVL_U => return "VU";
        when others     => return "XX";
      end case;
    end if;
  end;

  function cause2string(cause : std_logic_vector) return string is
    constant LEN : integer := 64;
    subtype wordx is std_logic_vector(LEN - 1 downto 0);
    variable tmp : wordx := (others => '0');

    -- Exception Codes
    constant XC_INST_ADDR_MISALIGNED      : wordx := x"0000000000000000"; --0
    constant XC_INST_ACCESS_FAULT         : wordx := x"0000000000000001"; --1
    constant XC_INST_ILLEGAL_INST         : wordx := x"0000000000000002"; --2
    constant XC_INST_BREAKPOINT           : wordx := x"0000000000000003"; --3
    constant XC_INST_LOAD_ADDR_MISALIGNED : wordx := x"0000000000000004"; --4
    constant XC_INST_LOAD_ACCESS_FAULT    : wordx := x"0000000000000005"; --5
    constant XC_INST_STORE_ADDR_MISALIGNED: wordx := x"0000000000000006"; --6
    constant XC_INST_STORE_ACCESS_FAULT   : wordx := x"0000000000000007"; --7
    constant XC_INST_ENV_CALL_UMODE       : wordx := x"0000000000000008"; --8
    constant XC_INST_ENV_CALL_SMODE       : wordx := x"0000000000000009"; --9
    constant XC_INST_ENV_CALL_MMODE       : wordx := x"000000000000000B"; --11
    constant XC_INST_INST_PAGE_FAULT      : wordx := x"000000000000000C"; --12
    constant XC_INST_LOAD_PAGE_FAULT      : wordx := x"000000000000000D"; --13
    constant XC_INST_STORE_PAGE_FAULT     : wordx := x"000000000000000F"; --15
    constant XC_INST_INST_G_PAGE_FAULT    : wordx := x"0000000000000014"; --20
    constant XC_INST_LOAD_G_PAGE_FAULT    : wordx := x"0000000000000015"; --21
    constant XC_INST_VIRTUAL_INST         : wordx := x"0000000000000016"; --22
    constant XC_INST_STORE_G_PAGE_FAULT   : wordx := x"0000000000000017"; --23
    constant XC_INST_RFFT                 : wordx := x"000000000000001F"; --31

    -- Interrupt Codes
    constant IRQ_U_SOFTWARE               : wordx := x"0000000000000000"; --0
    constant IRQ_S_SOFTWARE               : wordx := x"0000000000000001"; --1
    constant IRQ_VS_SOFTWARE              : wordx := x"0000000000000002"; --2
    constant IRQ_M_SOFTWARE               : wordx := x"0000000000000003"; --3
    constant IRQ_U_TIMER                  : wordx := x"0000000000000004"; --4
    constant IRQ_S_TIMER                  : wordx := x"0000000000000005"; --5
    constant IRQ_VS_TIMER                 : wordx := x"0000000000000006"; --6
    constant IRQ_M_TIMER                  : wordx := x"0000000000000007"; --7
    constant IRQ_U_EXTERNAL               : wordx := x"0000000000000008"; --8
    constant IRQ_S_EXTERNAL               : wordx := x"0000000000000009"; --9
    constant IRQ_VS_EXTERNAL              : wordx := x"000000000000000A"; --10
    constant IRQ_M_EXTERNAL               : wordx := x"000000000000000B"; --11
    constant IRQ_SG_EXTERNAL              : wordx := x"000000000000000C"; --12
    constant IRQ_LCOF                     : wordx := x"000000000000000D"; --13
  begin
    tmp(cause'left - 1 downto cause'right) := cause(cause'left - 1 downto cause'right);
    if cause(cause'left) = '0' then
      case tmp is
        when XC_INST_ADDR_MISALIGNED       => return " MISALIGNED_FETCH ";
        when XC_INST_ACCESS_FAULT          => return "   FETCH_ACCESS   ";
        when XC_INST_ILLEGAL_INST          => return "   ILLEGAL_INST   ";
        when XC_INST_BREAKPOINT            => return "    BREAKPOINT    ";
        when XC_INST_LOAD_ADDR_MISALIGNED  => return " MISALIGNED_LOAD  ";
        when XC_INST_LOAD_ACCESS_FAULT     => return "   LOAD_ACCESS    ";
        when XC_INST_STORE_ADDR_MISALIGNED => return " MISALIGNED_STORE ";
        when XC_INST_STORE_ACCESS_FAULT    => return "   STORE_ACCESS   ";
        when XC_INST_ENV_CALL_UMODE        => return "    USER_ECALL    ";
        when XC_INST_ENV_CALL_SMODE        => return " SUPERVISOR_ECALL ";
        when XC_INST_ENV_CALL_MMODE        => return "  MACHINE_ECALL   ";
        when XC_INST_INST_PAGE_FAULT       => return " FETCH_PAGE_FAULT ";
        when XC_INST_LOAD_PAGE_FAULT       => return " LOAD_PAGE_FAULT  ";
        when XC_INST_STORE_PAGE_FAULT      => return " STORE_PAGE_FAULT ";
        when XC_INST_INST_G_PAGE_FAULT     => return " FTC_G_PAGE_FAULT ";
        when XC_INST_LOAD_G_PAGE_FAULT     => return " LD_G_PAGE_FAULT  ";
        when XC_INST_VIRTUAL_INST          => return "  VIRTUAL_INST    ";
        when XC_INST_STORE_G_PAGE_FAULT    => return " ST_G_PAGE_FAULT  ";
        when XC_INST_RFFT                  => return "       RFFT       ";
        when others => return "TRAP: " & tost(tmp);
      end case;
    else
      case tmp is
        when IRQ_U_SOFTWARE                => return "     MIP_USIP     ";
        when IRQ_S_SOFTWARE                => return "     MIP_SSIP     ";
        when IRQ_VS_SOFTWARE               => return "     MIP_VSSIP    ";
        when IRQ_M_SOFTWARE                => return "     MIP_MSIP     ";
        when IRQ_U_TIMER                   => return "     MIP_UTIP     ";
        when IRQ_S_TIMER                   => return "     MIP_STIP     ";
        when IRQ_VS_TIMER                  => return "     MIP_VSTIP    ";
        when IRQ_M_TIMER                   => return "     MIP_MTIP     ";
        when IRQ_U_EXTERNAL                => return "     MIP_UEIP     ";
        when IRQ_S_EXTERNAL                => return "     MIP_SEIP     ";
        when IRQ_VS_EXTERNAL               => return "     MIP_VSEIP    ";
        when IRQ_M_EXTERNAL                => return "     MIP_MEIP     ";
        when IRQ_SG_EXTERNAL               => return "     MIP_SGEIP    ";
        when IRQ_LCOF                      => return "     MIP_LCOF     ";
        when others => return "MIP: " & tost(tmp);
      end case;
    end if;
  end;

  function insn2string(insn  : std_logic_vector; pc   : std_logic_vector; disas : string;
                       cinsn : std_logic_vector; comp : std_ulogic) return string is
  begin
    if comp = '0' then
      return "@" & tostf(pc) & " (" & tostf(insn) & ") " & disas;
    else
      return "@" & tostf(pc) & " (" & tostf(cinsn) & ")     " & disas;
    end if;
  end;

  function branch2str(branch : funct3_type) return string is
  begin
    case branch is
      when B_BEQ  => return "beq";
      when B_BNE  => return "bne";
      when B_BLT  => return "blt";
      when B_BGE  => return "bge";
      when B_BLTU => return "bltu";
      when B_BGEU => return "bgeu";
      when others => return "xxx";
    end case;
  end;

  function load2str(v : funct3_type) return string is
  begin
    case v is
      when I_LB   => return "lb";
      when I_LH   => return "lh";
      when I_LW   => return "lw";
      when I_LBU  => return "lbu";
      when I_LHU  => return "lhu";
      when I_LWU  => return "lwu";
      when I_LD   => return "ld";
      when others => return "xxx";
    end case;
  end;

  function csrop2str(v : funct3_type) return string is
  begin
    case v is
      when I_CSRRW  => return "csrrw";
      when I_CSRRS  => return "csrrs";
      when I_CSRRC  => return "csrrc";
      when I_CSRRWI => return "csrrwi";
      when I_CSRRSI => return "csrrsi";
      when I_CSRRCI => return "csrrci";
      when others   => return "xxx";
    end case;
  end;

  function store2str(v : funct3_type) return string is
  begin
    case v is
      when S_SB   => return "sb";
      when S_SH   => return "sh";
      when S_SW   => return "sw";
      when S_SD   => return "sd";
      when others => return "xxx";
    end case;
  end;

  function imm2str(v : funct3_type; a_bit : std_ulogic) return string is
    variable a : std_ulogic;
  begin
    a := a_bit;
    case v is
      when I_ADDI     => return "addi";
      when I_SLTI     => return "slti";
      when I_SLTIU    => return "sltiu";
      when I_XORI     => return "xori";
      when I_ORI      => return "ori";
      when I_ANDI     => return "andi";
      when I_SLLI     => return "slli";
      when I_SRLI =>  -- Also I_SRAI
        case a is
          when '0'    => return "srli";
          when '1'    => return "srai";
          when others => return "xxx";
        end case;
      when others     => return "xxx";
    end case;
  end;

  function immw2str(v : funct3_type; a_bit : std_ulogic) return string is
    variable a : std_ulogic;
  begin
    a := a_bit;
    case v is
      when I_ADDI     => return "addiw";
      when I_SLLI     => return "slliw";
      when I_SRLI =>  -- Also I_SRAI
        case a is
          when '0'    => return "srliw";
          when '1'    => return "sraiw";
          when others => return "xxx";
        end case;
      when others     => return "xxx";
    end case;
  end;

  function reg2str(v : funct3_type; a_bit : std_ulogic) return string is
    variable a : std_ulogic;
  begin
    a := a_bit;
    case v is
      when R_ADD =>  -- Also R_SUB
        case a is
          when '0'    => return "add";
          when '1'    => return "sub";
          when others => return "xxx";
        end case;
      when R_SLL      => return "sll";
      when R_SLT      => return "slt";
      when R_SLTU     => return "sltu";
      when R_XOR =>
        case a is
          when '0'    => return "xor";
          when '1'    => return "xnor";
          when others => return "xxx";
        end case;
      when R_SRL =>  -- Also R_SRA
        case a is
          when '0'    => return "srl";
          when '1'    => return "sra";
          when others => return "xxx";
        end case;
      when R_OR =>
        case a is
          when '0'    => return "or";
          when '1'    => return "orn";
          when others => return "xxx";
        end case;
      when R_AND =>
        case a is
          when '0'    => return "and";
          when '1'    => return "andn";
          when others => return "xxx";
        end case;
      when others     => return "xxx";
    end case;
  end;

  function regw2str(v : funct3_type; a_bit : std_ulogic) return string is
    variable a : std_ulogic;
  begin
    a := a_bit;
    case v is
      when R_ADD =>  -- Also R_SUB
        case a is
          when '0'    => return "addw";
          when '1'    => return "subw";
          when others => return "xxx";
        end case;
      when R_SLL      => return "sllw";
      when R_SRL =>  -- Also R_SRA
        case a is
          when '0'    => return "srlw";
          when '1'    => return "sraw";
          when others => return "xxx";
        end case;
      when others     => return "xxx";
    end case;
  end;

  function rot2str(v : funct3_type) return string is
  begin
    case v is
      when R_SLL  => return "rol";
      when R_SRL  => return "ror";
      when others => return "xxx";
    end case;
  end;

  function rotw2str(v : funct3_type) return string is
  begin
    case v is
      when R_SLL  => return "rolw";
      when R_SRL  => return "rorw";
      when others => return "xxx";
    end case;
  end;

  function mul2str(v : funct3_type) return string is
  begin
    case v is
      when R_MUL    => return "mul";
      when R_MULH   => return "mulh";
      when R_MULHSU => return "mulhsu";
      when R_MULHU  => return "mulhu";
      when R_DIV    => return "div";
      when R_DIVU   => return "divu";
      when R_REM    => return "rem";
      when R_REMU   => return "remu";
      when others   => return "xxx";
    end case;
  end;

  function minmaxclmul2str(v : funct3_type) return string is
  begin
    case v is
      when R_CLMUL  => return "clmul";
      when R_CLMULR => return "clmulr";
      when R_CLMULH => return "clmulh";
      when R_MIN    => return "min";
      when R_MINU   => return "minu";
      when R_MAX    => return "max";
      when R_MAXU   => return "maxu";
      when others   => return "xxx";
    end case;
  end;

  function mulw2str(v : funct3_type) return string is
  begin
    case v is
      when R_MUL  => return "mulw";
      when R_DIV  => return "divw";
      when R_DIVU => return "divuw";
      when R_REM  => return "remw";
      when R_REMU => return "remuw";
      when others => return "xxx";
    end case;
  end;

  function amo2str(v : funct5_type; w : std_ulogic) return string is
    variable size  : string(1 to 2);
  begin
    if w = '0' then
      size := ".w";
    else
      size := ".d";
    end if;
    case v is
      when "00010" => return "lr" & size;
      when "00011" => return "sc" & size;
      when "00001" => return "amoswap" & size;
      when "00000" => return "amoadd" & size;
      when "00100" => return "amoxor" & size;
      when "01100" => return "amoand" & size;
      when "01000" => return "amoor" & size;
      when "10000" => return "amomin" & size;
      when "10100" => return "amomax" & size;
      when "11000" => return "amominu" & size;
      when "11100" => return "amomaxu" & size;
      when others  => return "xxx";
    end case;
  end;

  function hlv2str(v : std_logic_vector(2 downto 0); v2 : std_logic_vector(1 downto 0)) return string is
  begin
    case v is
      when "000" => 
        case v2 is
          when "00"   => return "hlv.b";
          when "01"   => return "hlv.bu";
          when others => return "xxx";
        end case;
      when "010" => 
        case v2 is
          when "00"   => return "hlv.h";
          when "01"   => return "hlv.hu";
          when "11"   => return "hlvx.hu";
          when others => return "xxx";
        end case;
      when "100" => 
        case v2 is
          when "00"   => return "hlv.w";
          when "01"   => return "hlv.wu";
          when "11"   => return "hlvx.wu";
          when others => return "xxx";
        end case;
      when "110" => 
        case v2 is
          when "00"   => return "hlv.d";
          when others => return "xxx";
        end case;
      when others     => return "xxx";
    end case;
  end;

  function hsv2str(v : funct3_type) return string is
  begin
    case v is
      when "001"  => return "hsv.b";
      when "011"  => return "hsv.h";
      when "101"  => return "hsv.w";
      when "111"  => return "hsv.d";
      when others => return "xxx";
    end case;
  end;
  
  function custom0_diag2str(v : std_logic_vector(3 downto 0); s : funct3_type; store : boolean) return string is
    variable size : std_logic_vector(1 downto 0) := s(1 downto 0);
    variable t    : string(1 to 2);
  begin
    if store then
      if size = "11" then
        t := "sd";
      else
        t := "sw";
      end if;
    else
      if size = "11" then
        t := "ld";
      else
        t := "lw";
      end if;
    end if;

    case v is
      when x"0" => return "diag." & t & ".ict";
      when x"1" => return "diag." & t & ".icd";
      when x"2" => return "diag." & t & ".dct";
      when x"3" => return "diag." & t & ".dcd";
      when x"4" => return "diag." & t & ".mmup";
      when x"5" => return "diag." & t & ".byp";
      when x"6" => return "diag." & t & ".dst";
      when x"7" => return "diag." & t & ".tlb";
      when x"8" => return "diag." & t & ".bra";
      when x"9" => return "diag." & t & ".lru";
      when x"a" => return "diag." & t & ".itcm";
      when x"b" => return "diag." & t & ".dtcm";
      when x"c" => return "diag." & t & ".pmp";
      when x"d" => return "diag." & t & ".xtnd";
      when others => return "diag." & t & ".xxx";
    end case;
  end;

  function cbo2str(v : funct12_type; rd : reg_t) return string is
  begin
    if rd = GPR_X0 then
      case v is
        when "000000000000" => return "cbo.inval";
        when "000000000001" => return "cbo.clean";
        when "000000000010" => return "cbo.flush";
        when "000000000100" => return "cbo.zero";
        when others  => return "cbo.xxx";
      end case;
    else
      return "cbo.xxx";
    end if;
  end;

  -- General Purpose Register ----------------------------------------
  function reg2st(reg : reg_t) return string is
  begin
    case reg is
      when GPR_X0       => return "x0";
      when GPR_RA       => return "ra";
      when GPR_SP       => return "sp";
      when GPR_GP       => return "gp";
      when GPR_TP       => return "tp";
      when GPR_T0       => return "t0";
      when GPR_T1       => return "t1";
      when GPR_T2       => return "t2";
      when GPR_FP       => return "fp";
      when GPR_S1       => return "s1";
      when GPR_A0       => return "a0";
      when GPR_A1       => return "a1";
      when GPR_A2       => return "a2";
      when GPR_A3       => return "a3";
      when GPR_A4       => return "a4";
      when GPR_A5       => return "a5";
      when GPR_A6       => return "a6";
      when GPR_A7       => return "a7";
      when GPR_S2       => return "s2";
      when GPR_S3       => return "s3";
      when GPR_S4       => return "s4";
      when GPR_S5       => return "s5";
      when GPR_S6       => return "s6";
      when GPR_S7       => return "s7";
      when GPR_S8       => return "s8";
      when GPR_S9       => return "s9";
      when GPR_S10      => return "s10";
      when GPR_S11      => return "s11";
      when GPR_T3       => return "t3";
      when GPR_T4       => return "t4";
      when GPR_T5       => return "t5";
      when GPR_T6       => return "t6";
      when others       => return "XXX";
    end case;
  end;

  -- GRLIB_INTERNAL_BEGIN
  -- Use the following command to see if there are CSRs which lack a string but are defined.
  -- diff <(grep -ioP "CSR_\w*" riscv.vhd) <(grep -iPo "(?<=when )CSR_\w*" riscv_disas.vhd)
  -- GRLIB_INTERNAL_END
  -- Control Status Register ----------------------------------------
  function csr2str(reg : csratype) return string is
  begin
    case reg is
      -- User Trap Setup
      when CSR_USTATUS          => return "ustatus";
      when CSR_UIE              => return "uie";
      when CSR_UTVEC            => return "utvec";
      -- User Trap Handling
      when CSR_USCRATCH         => return "uscratch";
      when CSR_UEPC             => return "uepc";
      when CSR_UCAUSE           => return "ucause";
      when CSR_UTVAL            => return "utval";
      when CSR_UIP              => return "uip";
      -- User Floating-Point CSRs
      when CSR_FFLAGS           => return "fflags";
      when CSR_FRM              => return "frm";
      when CSR_FCSR             => return "fcsr";
      -- User Counters/Timers
      when CSR_CYCLE            => return "cycle";
      when CSR_TIME             => return "time";
      when CSR_INSTRET          => return "instret";
      when CSR_HPMCOUNTER3      => return "hpmcounter3";
      when CSR_HPMCOUNTER4      => return "hpmcounter4";
      when CSR_HPMCOUNTER5      => return "hpmcounter5";
      when CSR_HPMCOUNTER6      => return "hpmcounter6";
      when CSR_HPMCOUNTER7      => return "hpmcounter7";
      when CSR_HPMCOUNTER8      => return "hpmcounter8";
      when CSR_HPMCOUNTER9      => return "hpmcounter9";
      when CSR_HPMCOUNTER10     => return "hpmcounter10";
      when CSR_HPMCOUNTER11     => return "hpmcounter11";
      when CSR_HPMCOUNTER12     => return "hpmcounter12";
      when CSR_HPMCOUNTER13     => return "hpmcounter13";
      when CSR_HPMCOUNTER14     => return "hpmcounter14";
      when CSR_HPMCOUNTER15     => return "hpmcounter15";
      when CSR_HPMCOUNTER16     => return "hpmcounter16";
      when CSR_HPMCOUNTER17     => return "hpmcounter17";
      when CSR_HPMCOUNTER18     => return "hpmcounter18";
      when CSR_HPMCOUNTER19     => return "hpmcounter19";
      when CSR_HPMCOUNTER20     => return "hpmcounter20";
      when CSR_HPMCOUNTER21     => return "hpmcounter21";
      when CSR_HPMCOUNTER22     => return "hpmcounter22";
      when CSR_HPMCOUNTER23     => return "hpmcounter23";
      when CSR_HPMCOUNTER24     => return "hpmcounter24";
      when CSR_HPMCOUNTER25     => return "hpmcounter25";
      when CSR_HPMCOUNTER26     => return "hpmcounter26";
      when CSR_HPMCOUNTER27     => return "hpmcounter27";
      when CSR_HPMCOUNTER28     => return "hpmcounter28";
      when CSR_HPMCOUNTER29     => return "hpmcounter29";
      when CSR_HPMCOUNTER30     => return "hpmcounter30";
      when CSR_HPMCOUNTER31     => return "hpmcounter31";
      -- High (RV32)
      when CSR_CYCLEH           => return "cycleh";
      when CSR_TIMEH            => return "timeh";
      when CSR_INSTRETH         => return "instreth";
      when CSR_HPMCOUNTER3H     => return "hpmcounter3h";
      when CSR_HPMCOUNTER4H     => return "hpmcounter4h";
      when CSR_HPMCOUNTER5H     => return "hpmcounter5h";
      when CSR_HPMCOUNTER6H     => return "hpmcounter6h";
      when CSR_HPMCOUNTER7H     => return "hpmcounter7h";
      when CSR_HPMCOUNTER8H     => return "hpmcounter8h";
      when CSR_HPMCOUNTER9H     => return "hpmcounter9h";
      when CSR_HPMCOUNTER10H    => return "hpmcounter10h";
      when CSR_HPMCOUNTER11H    => return "hpmcounter11h";
      when CSR_HPMCOUNTER12H    => return "hpmcounter12h";
      when CSR_HPMCOUNTER13H    => return "hpmcounter13h";
      when CSR_HPMCOUNTER14H    => return "hpmcounter14h";
      when CSR_HPMCOUNTER15H    => return "hpmcounter15h";
      when CSR_HPMCOUNTER16H    => return "hpmcounter16h";
      when CSR_HPMCOUNTER17H    => return "hpmcounter17h";
      when CSR_HPMCOUNTER18H    => return "hpmcounter18h";
      when CSR_HPMCOUNTER19H    => return "hpmcounter19h";
      when CSR_HPMCOUNTER20H    => return "hpmcounter20h";
      when CSR_HPMCOUNTER21H    => return "hpmcounter21h";
      when CSR_HPMCOUNTER22H    => return "hpmcounter22h";
      when CSR_HPMCOUNTER23H    => return "hpmcounter23h";
      when CSR_HPMCOUNTER24H    => return "hpmcounter24h";
      when CSR_HPMCOUNTER25H    => return "hpmcounter25h";
      when CSR_HPMCOUNTER26H    => return "hpmcounter26h";
      when CSR_HPMCOUNTER27H    => return "hpmcounter27h";
      when CSR_HPMCOUNTER28H    => return "hpmcounter28h";
      when CSR_HPMCOUNTER29H    => return "hpmcounter29h";
      when CSR_HPMCOUNTER30H    => return "hpmcounter30h";
      when CSR_HPMCOUNTER31H    => return "hpmcounter31h";
      -- Supervisor Trap Setup
      when CSR_SSTATUS          => return "sstatus";
      when CSR_SEDELEG          => return "sedeleg";
      when CSR_SIDELEG          => return "sideleg";
      when CSR_SIE              => return "sie";
      when CSR_STVEC            => return "stvec";
      when CSR_SCOUNTEREN       => return "scounteren";
      -- Supervisor Configuration
      when CSR_SENVCFG          => return "senvcfg";
      -- Supervisor Trap Handling
      when CSR_SSCRATCH         => return "sscratch";
      when CSR_SEPC             => return "sepc";
      when CSR_SCAUSE           => return "scause";
      when CSR_STVAL            => return "stval";
      when CSR_SIP              => return "sip";

      -- Supervisor AIA (Smaia or Ssaia)
      when CSR_SISELECT         => return "siselect";
      when CSR_SIREG            => return "sireg";
      when CSR_STOPEI           => return "stopei";
      when CSR_STOPI            => return "stopi";
      -- High (RV32)
      when CSR_SIEH             => return "sieh";
      when CSR_SIPH             => return "siph";

      -- Supervisor State Enable (Smstateen)
      when CSR_SSTATEEN0        => return "sstateen0";
      when CSR_SSTATEEN1        => return "sstateen1";
      when CSR_SSTATEEN2        => return "sstateen2";
      when CSR_SSTATEEN3        => return "sstateen3";
 
      when CSR_STIMECMP         => return "stimecmp";
      when CSR_STIMECMPH        => return "stimecmph";
      -- Supervisor Protection and Translation
      when CSR_SATP             => return "satp";
      -- Supervisor Count Overflow
      when CSR_SCOUNTOVF        => return "scountovf";

      -- Hypervisor Trap Setup
      when CSR_HSTATUS          => return "hstatus";
      when CSR_HEDELEG          => return "hedeleg";
      when CSR_HIDELEG          => return "hideleg";
      when CSR_HIE              => return "hie";
      when CSR_HCOUNTEREN       => return "hcounteren";
      when CSR_HGEIE            => return "hgeie";
      -- Hypervisor Trap Handling
      when CSR_HTVAL            => return "htval";
      when CSR_HIP              => return "hip";
      when CSR_HVIP             => return "hvip";
      when CSR_HTINST           => return "htinst";
      when CSR_HGEIP            => return "hgeip";
      -- Hypervisor Configuration
      when CSR_HENVCFG          => return "henvcfg";
      -- High (RV32)
      when CSR_HENVCFGH         => return "henvcfgh";
      -- Hypervisor Protection and Translation
      when CSR_HGATP            => return "hgatp";
      -- Hypervisor Counter/Timer Virtualization Registers
      when CSR_HTIMEDELTA       => return "htimedelta";
      -- High  (RV32)
      when CSR_HTIMEDELTAH      => return "htimedeltah";

      -- Virtual Supervisor Registers
      when CSR_VSSTATUS         => return "vsstatus";
      when CSR_VSIE             => return "vsie";
      when CSR_VSTVEC           => return "vstvec";
      when CSR_VSSCRATCH        => return "vsscratch";
      when CSR_VSEPC            => return "vsepc";
      when CSR_VSCAUSE          => return "vscause";
      when CSR_VSTVAL           => return "vstval";
      when CSR_VSIP             => return "vsip";
      when CSR_VSTIMECMP        => return "vstimecmp";
      when CSR_VSTIMECMPH       => return "vstimecmph";
      when CSR_VSATP            => return "vsatp";

      -- Virtual Supervisor AIA (Smaia or Ssaia)
      when CSR_HVIEN            => return "hvien";
      when CSR_HVICTL           => return "hvictl";
      when CSR_HVIPRIO1         => return "hviprio1";
      when CSR_HVIPRIO2         => return "hviprio2";
      when CSR_VSISELECT        => return "vsiselect";
      when CSR_VSIREG           => return "vsireg";
      when CSR_VSTOPEI          => return "vstopei";
      when CSR_VSTOPI           => return "vstopi";
      -- High (RV32)
      when CSR_HIDELEGH         => return "hidelegh";
      when CSR_HVIENH           => return "hvienh";
      when CSR_HVIPH            => return "hviph";
      when CSR_HVIPRIO1H        => return "hviprio1h";
      when CSR_HVIPRIO2H        => return "hviprio2h";
      when CSR_VSIEH            => return "vsieh";
      when CSR_VSIPH            => return "vsiph";

      -- Hypervisor State Enable (Smstateen)
      when CSR_HSTATEEN0        => return "hstateen0";
      when CSR_HSTATEEN1        => return "hstateen1";
      when CSR_HSTATEEN2        => return "hstateen2";
      when CSR_HSTATEEN3        => return "hstateen3";
      -- High (RV32)
      when CSR_HSTATEEN0H       => return "hstateen0h";
      when CSR_HSTATEEN1H       => return "hstateen1h";
      when CSR_HSTATEEN2H       => return "hstateen2h";
      when CSR_HSTATEEN3H       => return "hstateen3h";


      -- Machine Information Registers
      when CSR_MVENDORID        => return "mvendorid";
      when CSR_MARCHID          => return "marchid";
      when CSR_MIMPID           => return "mimpid";
      when CSR_MHARTID          => return "mhartid";
      when CSR_MCONFIGPTR       => return "mconfigptr";
      -- Machine Trap Setup
      when CSR_MSTATUS          => return "mstatus";
      when CSR_MISA             => return "misa";
      when CSR_MEDELEG          => return "medeleg";
      when CSR_MIDELEG          => return "mideleg";
      when CSR_MIE              => return "mie";
      when CSR_MTVEC            => return "mtvec";
      when CSR_MCOUNTEREN       => return "mcounteren";
      -- High (RV32)
      when CSR_MSTATUSH         => return "mstatush";
      -- Machine Trap Handling
      when CSR_MSCRATCH         => return "mscratch";
      when CSR_MEPC             => return "mepc";
      when CSR_MCAUSE           => return "mcause";
      when CSR_MTVAL            => return "mtval";
      when CSR_MIP              => return "mip";
      when CSR_MTINST           => return "mtinst";
      when CSR_MTVAL2           => return "mtval2";

      -- Machine AIA (Smaia)
      when CSR_MISELECT         => return "miselect";
      when CSR_MIREG            => return "mireg";
      when CSR_MTOPEI           => return "mtopei";
      when CSR_MTOPI            => return "mtopi";
      when CSR_MVIEN            => return "mvien";
      when CSR_MVIP             => return "mvip";
      -- High (RV32)
      when CSR_MIDELEGH         => return "midelegh";
      when CSR_MIEH             => return "mieh";
      when CSR_MVIENH           => return "mvienh";
      when CSR_MVIPH            => return "mviph";
      when CSR_MIPH             => return "miph";
  
      -- Machine State Enable (Smstateen)
      when CSR_MSTATEEN0        => return "mstateen0";
      when CSR_MSTATEEN1        => return "mstateen1";
      when CSR_MSTATEEN2        => return "mstateen2";
      when CSR_MSTATEEN3        => return "mstateen3";
      -- High (RV32)
      when CSR_MSTATEEN0H        => return "mstateen0h";
      when CSR_MSTATEEN1H        => return "mstateen1h";
      when CSR_MSTATEEN2H        => return "mstateen2h";
      when CSR_MSTATEEN3H        => return "mstateen3h";

      -- Machine Configuration
      when CSR_MENVCFG          => return "menvcfg";
      when CSR_MSECCFG          => return "mseccfg";
      -- High (RV32)
      when CSR_MENVCFGH         => return "menvcfgh";
      when CSR_MSECCFGH         => return "mseccfgh";

      -- Machine Protection and Translation
      when CSR_PMPCFG0          => return "pmpcfg0";
      when CSR_PMPCFG1          => return "pmpcfg1";
      when CSR_PMPCFG2          => return "pmpcfg2";
      when CSR_PMPCFG3          => return "pmpcfg3";
      when CSR_PMPADDR0         => return "pmpaddr0";
      when CSR_PMPADDR1         => return "pmpaddr1";
      when CSR_PMPADDR2         => return "pmpaddr2";
      when CSR_PMPADDR3         => return "pmpaddr3";
      when CSR_PMPADDR4         => return "pmpaddr4";
      when CSR_PMPADDR5         => return "pmpaddr5";
      when CSR_PMPADDR6         => return "pmpaddr6";
      when CSR_PMPADDR7         => return "pmpaddr7";
      when CSR_PMPADDR8         => return "pmpaddr8";
      when CSR_PMPADDR9         => return "pmpaddr9";
      when CSR_PMPADDR10        => return "pmpaddr10";
      when CSR_PMPADDR11        => return "pmpaddr11";
      when CSR_PMPADDR12        => return "pmpaddr12";
      when CSR_PMPADDR13        => return "pmpaddr13";
      when CSR_PMPADDR14        => return "pmpaddr14";
      when CSR_PMPADDR15        => return "pmpaddr15";
      -- Machine Counter/Timers
      when CSR_MCYCLE           => return "mcycle";
      when CSR_MINSTRET         => return "minstret";
      when CSR_MHPMCOUNTER3     => return "mhpmcounter3";
      when CSR_MHPMCOUNTER4     => return "mhpmcounter4";
      when CSR_MHPMCOUNTER5     => return "mhpmcounter5";
      when CSR_MHPMCOUNTER6     => return "mhpmcounter6";
      when CSR_MHPMCOUNTER7     => return "mhpmcounter7";
      when CSR_MHPMCOUNTER8     => return "mhpmcounter8";
      when CSR_MHPMCOUNTER9     => return "mhpmcounter9";
      when CSR_MHPMCOUNTER10    => return "mhpmcounter10";
      when CSR_MHPMCOUNTER11    => return "mhpmcounter11";
      when CSR_MHPMCOUNTER12    => return "mhpmcounter12";
      when CSR_MHPMCOUNTER13    => return "mhpmcounter13";
      when CSR_MHPMCOUNTER14    => return "mhpmcounter14";
      when CSR_MHPMCOUNTER15    => return "mhpmcounter15";
      when CSR_MHPMCOUNTER16    => return "mhpmcounter16";
      when CSR_MHPMCOUNTER17    => return "mhpmcounter17";
      when CSR_MHPMCOUNTER18    => return "mhpmcounter18";
      when CSR_MHPMCOUNTER19    => return "mhpmcounter19";
      when CSR_MHPMCOUNTER20    => return "mhpmcounter20";
      when CSR_MHPMCOUNTER21    => return "mhpmcounter21";
      when CSR_MHPMCOUNTER22    => return "mhpmcounter22";
      when CSR_MHPMCOUNTER23    => return "mhpmcounter23";
      when CSR_MHPMCOUNTER24    => return "mhpmcounter24";
      when CSR_MHPMCOUNTER25    => return "mhpmcounter25";
      when CSR_MHPMCOUNTER26    => return "mhpmcounter26";
      when CSR_MHPMCOUNTER27    => return "mhpmcounter27";
      when CSR_MHPMCOUNTER28    => return "mhpmcounter28";
      when CSR_MHPMCOUNTER29    => return "mhpmcounter29";
      when CSR_MHPMCOUNTER30    => return "mhpmcounter30";
      when CSR_MHPMCOUNTER31    => return "mhpmcounter31";
      -- High (RV32)
      when CSR_MCYCLEH          => return "mcycleh";
      when CSR_MINSTRETH        => return "minstreth";
      when CSR_MHPMCOUNTER3H    => return "mhpmcounter3h";
      when CSR_MHPMCOUNTER4H    => return "mhpmcounter4h";
      when CSR_MHPMCOUNTER5H    => return "mhpmcounter5h";
      when CSR_MHPMCOUNTER6H    => return "mhpmcounter6h";
      when CSR_MHPMCOUNTER7H    => return "mhpmcounter7h";
      when CSR_MHPMCOUNTER8H    => return "mhpmcounter8h";
      when CSR_MHPMCOUNTER9H    => return "mhpmcounter9h";
      when CSR_MHPMCOUNTER10H   => return "mhpmcounter10h";
      when CSR_MHPMCOUNTER11H   => return "mhpmcounter11h";
      when CSR_MHPMCOUNTER12H   => return "mhpmcounter12h";
      when CSR_MHPMCOUNTER13H   => return "mhpmcounter13h";
      when CSR_MHPMCOUNTER14H   => return "mhpmcounter14h";
      when CSR_MHPMCOUNTER15H   => return "mhpmcounter15h";
      when CSR_MHPMCOUNTER16H   => return "mhpmcounter16h";
      when CSR_MHPMCOUNTER17H   => return "mhpmcounter17h";
      when CSR_MHPMCOUNTER18H   => return "mhpmcounter18h";
      when CSR_MHPMCOUNTER19H   => return "mhpmcounter19h";
      when CSR_MHPMCOUNTER20H   => return "mhpmcounter20h";
      when CSR_MHPMCOUNTER21H   => return "mhpmcounter21h";
      when CSR_MHPMCOUNTER22H   => return "mhpmcounter22h";
      when CSR_MHPMCOUNTER23H   => return "mhpmcounter23h";
      when CSR_MHPMCOUNTER24H   => return "mhpmcounter24h";
      when CSR_MHPMCOUNTER25H   => return "mhpmcounter25h";
      when CSR_MHPMCOUNTER26H   => return "mhpmcounter26h";
      when CSR_MHPMCOUNTER27H   => return "mhpmcounter27h";
      when CSR_MHPMCOUNTER28H   => return "mhpmcounter28h";
      when CSR_MHPMCOUNTER29H   => return "mhpmcounter29h";
      when CSR_MHPMCOUNTER30H   => return "mhpmcounter30h";
      when CSR_MHPMCOUNTER31H   => return "mhpmcounter31h";
      -- Machine Counter Setup
      when CSR_MCOUNTINHIBIT    => return "mcountinhibit";
      when CSR_MHPMEVENT3       => return "mhpmevent3";
      when CSR_MHPMEVENT4       => return "mhpmevent4";
      when CSR_MHPMEVENT5       => return "mhpmevent5";
      when CSR_MHPMEVENT6       => return "mhpmevent6";
      when CSR_MHPMEVENT7       => return "mhpmevent7";
      when CSR_MHPMEVENT8       => return "mhpmevent8";
      when CSR_MHPMEVENT9       => return "mhpmevent9";
      when CSR_MHPMEVENT10      => return "mhpmevent10";
      when CSR_MHPMEVENT11      => return "mhpmevent11";
      when CSR_MHPMEVENT12      => return "mhpmevent12";
      when CSR_MHPMEVENT13      => return "mhpmevent13";
      when CSR_MHPMEVENT14      => return "mhpmevent14";
      when CSR_MHPMEVENT15      => return "mhpmevent15";
      when CSR_MHPMEVENT16      => return "mhpmevent16";
      when CSR_MHPMEVENT17      => return "mhpmevent17";
      when CSR_MHPMEVENT18      => return "mhpmevent18";
      when CSR_MHPMEVENT19      => return "mhpmevent19";
      when CSR_MHPMEVENT20      => return "mhpmevent20";
      when CSR_MHPMEVENT21      => return "mhpmevent21";
      when CSR_MHPMEVENT22      => return "mhpmevent22";
      when CSR_MHPMEVENT23      => return "mhpmevent23";
      when CSR_MHPMEVENT24      => return "mhpmevent24";
      when CSR_MHPMEVENT25      => return "mhpmevent25";
      when CSR_MHPMEVENT26      => return "mhpmevent26";
      when CSR_MHPMEVENT27      => return "mhpmevent27";
      when CSR_MHPMEVENT28      => return "mhpmevent28";
      when CSR_MHPMEVENT29      => return "mhpmevent29";
      when CSR_MHPMEVENT30      => return "mhpmevent30";
      when CSR_MHPMEVENT31      => return "mhpmevent31";
      when CSR_MHPMEVENT3H      => return "mhpmevent3h";
      when CSR_MHPMEVENT4H      => return "mhpmevent4h";
      when CSR_MHPMEVENT5H      => return "mhpmevent5h";
      when CSR_MHPMEVENT6H      => return "mhpmevent6h";
      when CSR_MHPMEVENT7H      => return "mhpmevent7h";
      when CSR_MHPMEVENT8H      => return "mhpmevent8h";
      when CSR_MHPMEVENT9H      => return "mhpmevent9h";
      when CSR_MHPMEVENT10H     => return "mhpmevent10h";
      when CSR_MHPMEVENT11H     => return "mhpmevent11h";
      when CSR_MHPMEVENT12H     => return "mhpmevent12h";
      when CSR_MHPMEVENT13H     => return "mhpmevent13h";
      when CSR_MHPMEVENT14H     => return "mhpmevent14h";
      when CSR_MHPMEVENT15H     => return "mhpmevent15h";
      when CSR_MHPMEVENT16H     => return "mhpmevent16h";
      when CSR_MHPMEVENT17H     => return "mhpmevent17h";
      when CSR_MHPMEVENT18H     => return "mhpmevent18h";
      when CSR_MHPMEVENT19H     => return "mhpmevent19h";
      when CSR_MHPMEVENT20H     => return "mhpmevent20h";
      when CSR_MHPMEVENT21H     => return "mhpmevent21h";
      when CSR_MHPMEVENT22H     => return "mhpmevent22h";
      when CSR_MHPMEVENT23H     => return "mhpmevent23h";
      when CSR_MHPMEVENT24H     => return "mhpmevent24h";
      when CSR_MHPMEVENT25H     => return "mhpmevent25h";
      when CSR_MHPMEVENT26H     => return "mhpmevent26h";
      when CSR_MHPMEVENT27H     => return "mhpmevent27h";
      when CSR_MHPMEVENT28H     => return "mhpmevent28h";
      when CSR_MHPMEVENT29H     => return "mhpmevent29h";
      when CSR_MHPMEVENT30H     => return "mhpmevent30h";
      when CSR_MHPMEVENT31H     => return "mhpmevent31h";
      -- Debug/Trace Registers
      when CSR_TSELECT          => return "tselect";
      when CSR_TDATA1           => return "tdata1";
      when CSR_TDATA2           => return "tdata2";
      when CSR_TDATA3           => return "tdata3";
      when CSR_TINFO            => return "tinfo";
      when CSR_TCONTROL         => return "tcontrol";
      when CSR_MCONTEXT         => return "mcontext";
      when CSR_SCONTEXT         => return "scontext";
      -- Debug Mode Registers
      when CSR_DCSR             => return "dcsr";
      when CSR_DPC              => return "dpc";
      when CSR_DSCRATCH0        => return "dscratch0";
      when CSR_DSCRATCH1        => return "dscratch1";
      -- Custom Read/Write Registers
      when CSR_FEATURES         => return "features";
      when CSR_CCTRL            => return "cctrl";
      when CSR_TCMICTRL         => return "tcmictrl";
      when CSR_TCMDCTRL         => return "tcmdctrl";
      when CSR_FT               => return "ft";
      when CSR_EINJECT          => return "einject";
      when CSR_DFEATURES        => return "dfeatures";
      when CSR_FEATURESH        => return "featuresh";
      when CSR_CCTRLH           => return "cctrlh";
      when CSR_TCMICTRLH        => return "tcmictrlh";
      when CSR_TCMDCTRLH        => return "tcmdctrlh";
      when CSR_FTH              => return "fth";
      when CSR_EINJECTH         => return "einjecth";
      when CSR_DFEATURESH       => return "dfeaturesh";
      -- Custom Read-only Registers
      when CSR_CAPABILITY       => return "capability";
      when CSR_CAPABILITYH      => return "capabilityh";
      when others                => return "unknown";
    end case;
  end;

  -- Floating Point Register ----------------------------------------
  function fpreg2st(reg : reg_t) return string is
  begin
    case reg is
      when FPU_FT0      => return "ft0";
      when FPU_FT1      => return "ft1";
      when FPU_FT2      => return "ft2";
      when FPU_FT3      => return "ft3";
      when FPU_FT4      => return "ft4";
      when FPU_FT5      => return "ft5";
      when FPU_FT6      => return "ft6";
      when FPU_FT7      => return "ft7";
      when FPU_FS0      => return "fs0";
      when FPU_FS1      => return "fs1";
      when FPU_FA0      => return "fa0";
      when FPU_FA1      => return "fa1";
      when FPU_FA2      => return "fa2";
      when FPU_FA3      => return "fa3";
      when FPU_FA4      => return "fa4";
      when FPU_FA5      => return "fa5";
      when FPU_FA6      => return "fa6";
      when FPU_FA7      => return "fa7";
      when FPU_FS2      => return "fs2";
      when FPU_FS3      => return "fs3";
      when FPU_FS4      => return "fs4";
      when FPU_FS5      => return "fs5";
      when FPU_FS6      => return "fs6";
      when FPU_FS7      => return "fs7";
      when FPU_FS8      => return "fs8";
      when FPU_FS9      => return "fs9";
      when FPU_FS10     => return "fs10";
      when FPU_FS11     => return "fs11";
      when FPU_FT8      => return "ft8";
      when FPU_FT9      => return "ft9";
      when FPU_FT10     => return "ft10";
      when FPU_FT11     => return "ft11";
      when others       => return "XXXX";
    end case;
  end;

  function fli_imm(rs1 : reg_t) return string is
  begin
    case rs1 is
      when "00000" => return "-1.0";
      when "00001" => return "min";
      when "00010" => return "2.0^-16";
      when "00011" => return "2.0^-15";
      when "00100" => return "2.0^-8";
      when "00101" => return "2.0^-7";
      when "00110" => return "2.0^-4";
      when "00111" => return "2.0^-3";
      when "01000" => return "0.25";
      when "01001" => return "0.3125";
      when "01010" => return "0.375";
      when "01011" => return "0.4375";
      when "01100" => return "0.5";
      when "01101" => return "0.625";
      when "01110" => return "0.75";
      when "01111" => return "0.875";
      when "10000" => return "1.0";
      when "10001" => return "1.25";
      when "10010" => return "1.5";
      when "10011" => return "1.75";
      when "10100" => return "2.0";
      when "10101" => return "2.5";
      when "10110" => return "3.0";
      when "10111" => return "4.0";
      when "11000" => return "8.0";
      when "11001" => return "16.0";
      when "11010" => return "128.0";
      when "11011" => return "256.0";
      when "11100" => return "32768.0";
      when "11101" => return "65536.0";
      when "11110" => return "inf";
      when others  => return "nan";
    end case;
  end;

  function rnd2str(insn : std_logic_vector) return string is
    constant rnd_modes : string(1 to 3 * 8) := "rnertzrdnruprmmxxxyyydyn";
    variable funct3    : funct3_type        := insn(14 downto 12);
    variable mode      : integer            := to_integer(unsigned(funct3));
  begin
    if mode <= 4 then
      return ", " & rnd_modes(mode * 3 + 1 to mode * 3 + 3);
    else
      return "";
    end if;
  end;

  function fp2str(insn : std_logic_vector) return string is
    variable rs1    : reg_t       := insn(19 downto 15);
    variable rs2    : reg_t       := insn(24 downto 20);
    variable rd     : reg_t       := insn(11 downto 7);
    variable opcode : opcode_type := insn(6 downto 0);
    variable funct3 : funct3_type := insn(14 downto 12);
    variable funct5 : funct5_type := insn(31 downto 27);
    variable funct7 : funct7_type := insn(31 downto 25);
    constant fdf1f2 : string :=  " " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2);
    constant idf1f2 : string :=  " " &   reg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2);
    constant fd     : string :=  " " & fpreg2st(rd);
    constant fdf1   : string :=  " " & fpreg2st(rd) & ", " & fpreg2st(rs1);
    constant fdi1   : string :=  " " & fpreg2st(rd) & ", " &   reg2st(rs1);
    constant fdi1i2 : string :=  " " & fpreg2st(rd) & ", " &   reg2st(rs1) & ", " &   reg2st(rs2);
    constant idf1   : string :=  " " &   reg2st(rd) & ", " & fpreg2st(rs1);
    variable size   : string(1 to 2);
  begin
    case funct7(1 downto 0) is
      when "00"   => size := ".s";
      when "01"   => size := ".d";
      when "10"   => size := ".h";
      when others => size := ".q";
    end case;

    case funct7(6 downto 2) is
      when R_FADD  => return "fadd"  & size & fdf1f2 & rnd2str(insn);
      when R_FSUB  => return "fsub"  & size & fdf1f2 & rnd2str(insn);
      when R_FMUL  => return "fmul"  & size & fdf1f2 & rnd2str(insn);
      when R_FDIV  => return "fdiv"  & size & fdf1f2 & rnd2str(insn);
      when R_FSQRT => return "fsqrt" & size & fdf1   & rnd2str(insn);
      when R_FSGN  =>
        case funct3 is
          when R_FSGNJ  => return "fsgnj"  & size & fdf1f2;
          when R_FSGNJN => return "fsgnjn" & size & fdf1f2;
          when R_FSGNJX => return "fsgnjx" & size & fdf1f2;
          when others   => return "xxx";
        end case;
      when R_FMINMAX =>
        if funct3(1) = '0' then
          if funct3(0) = '0' then
            return "fmin" & size & fdf1f2;
          else
            return "fmax" & size & fdf1f2;
          end if;
        else
          if funct3(0) = '0' then
            return "fminm" & size & fdf1f2;
          else
            return "fmaxm" & size & fdf1f2;
          end if;
        end if;
      when R_FCVT_W_S =>
        case rs2(1 downto 0) is
          when "00"   =>
            if funct7(1 downto 0) = "01" and rs2 = "01000" then
              return "fcvtmod.w.d" & idf1 & rnd2str(insn);
            else
              return "fcvt.w" & size & idf1 & rnd2str(insn);
            end if;
          when "01"   => return "fcvt.wu" & size & idf1 & rnd2str(insn);
          when "10"   => return "fcvt.l"  & size & idf1 & rnd2str(insn);
          when others => return "fcvt.lu" & size & idf1 & rnd2str(insn);
        end case;
      when R_FMV_X_W =>
        if funct3(0) = '0' then
          if rs2(0) = '0' then
            return "fmv.x" & size & idf1;
          else
            return "fmvh.x.d" & idf1;
          end if;
        else
          return "fclass" & size & idf1;
        end if;
      when R_FCMP =>
        case funct3 is
          when R_FEQ  => return "feq" & size & idf1f2;
          when R_FLT  => return "flt" & size & idf1f2;
          when R_FLE  => return "fle" & size & idf1f2;
          when R_FLTQ => return "fltq" & size & idf1f2;
          when R_FLEQ => return "fleq" & size & idf1f2;
          when others => return "xxx";
        end case;
      when R_FCVT_S_W =>
        case rs2(1 downto 0) is
          when "00"   => return "fcvt" & size & ".w"  & fdi1 & rnd2str(insn);
          when "01"   => return "fcvt" & size & ".wu" & fdi1 & rnd2str(insn);
          when "10"   => return "fcvt" & size & ".l"  & fdi1 & rnd2str(insn);
          when others => return "fcvt" & size & ".lu" & fdi1 & rnd2str(insn);
        end case;
      when R_FMV_W_X =>
        if rs2(0) = '0' then
          return "fmv" & size & ".x" & fdi1;
        else
          return "fli" & size & fd & ", " & fli_imm(rs1);
        end if;
      when R_FCVT_S_D =>
        case rs2(2 downto 0) is
          when "000"  => return "fcvt" & size & ".s" & fdf1 & rnd2str(insn);
          when "001"  => return "fcvt" & size & ".d" & fdf1 & rnd2str(insn);
          when "010"  => return "fcvt" & size & ".h" & fdf1 & rnd2str(insn);
          when "011"  => return "fcvt" & size & ".q" & fdf1 & rnd2str(insn);
          when "100"  => return "fround" & size & fdf1 & rnd2str(insn);
          when others => return "xxx";
        end case;
      when R_FMVP_5_X =>
        return "fmvp.d.x" & fdi1i2;

      when others => return "xxx";
    end case;
  end;

  ----------------------------------------------------------------------------
  -- Pad String
  ----------------------------------------------------------------------------

  function strpad(str   : string;
                  len   : integer) return string is
    variable stro       : string(1 to len) := (others => ' ');
    variable leni       : integer;

  begin

    leni                := str'length;
    stro(1 to leni)     := str;

    return stro;

  end;

  ----------------------------------------------------------------------------
  -- Instruction To String
  ----------------------------------------------------------------------------

  
  -- Return data interpreted as unsigned, as an integer.
  function u2i(data : std_logic_vector) return integer is
  begin
    return to_integer(unsigned(data));
  end;

  function insn2st(pc           : std_logic_vector;
                   insn         : std_logic_vector(31 downto 0);
                   cinsn        : std_logic_vector(15 downto 0);
                   comp         : std_ulogic) return string is

    constant bb2        : string(1 to 2) := (others => ' ');
    constant bb4        : string(1 to 4) := (others => ' ');
    variable imm12      : std_logic_vector(11 downto 0) := insn(31 downto 20);
    variable imm20      : std_logic_vector(19 downto 0) := insn(31 downto 12);
    variable rs1        : reg_t          := insn(19 downto 15);
    variable rs2        : reg_t          := insn(24 downto 20);
    variable rd         : reg_t          := insn(11 downto 7);
    variable opcode     : opcode_type    := insn(6 downto 0);
    variable funct3     : funct3_type    := insn(14 downto 12);
    variable funct5     : funct5_type    := insn(31 downto 27);
    variable funct7     : funct7_type    := insn(31 downto 25);
    variable funct12    : funct12_type   := insn(31 downto 20);

    variable disas      : string(1 to 35)               := (others => ' ');
    variable imm        : std_logic_vector(31 downto 0) := (others => '0');

    variable target     : std_logic_vector(64 downto 0) := (others => '0');
    variable target_op  : std_logic_vector(63 downto 0);

  begin
    case opcode is

      ----------------------------------------------------------------------------
      -- RV32IM Base Instruction Set
      ----------------------------------------------------------------------------

      when LUI =>
        disas := strpad("lui " & reg2st(rd) & ", " & tostf(imm20), disas'length);
        return insn2string(insn, pc, disas, cinsn, comp);

      when AUIPC =>
        disas := strpad("auipc " & reg2st(rd) & ", " & tostf(imm20), disas'length);
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_JAL =>
        imm20 := insn(31) & insn(19 downto 12) & insn(20) & insn(30 downto 21);
        imm   := (others => insn(31));
        imm(20 downto 0) := imm20 & '0';
        disas := strpad("jal " & reg2st(rd) & ", " & tosti(imm), disas'length);
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_JALR =>
        imm                     := (others => insn(31));
        imm(11 downto 0)        := imm12;
        disas := strpad("jalr " & reg2st(rd) & ", " & tosti(imm) & "(" & reg2st(rs1) & ")", disas'length);
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_BRANCH =>
        target_op               := (others => insn(31));
        target_op(12 downto 0)  := insn(31) & insn(7) & insn(30 downto 25) & insn(11 downto 8) & '0';
        target                  := std_logic_vector(signed('0' & pc) + signed(insn(31) & target_op));
        disas := strpad(branch2str(funct3) & " " & reg2st(rs1) & ", " & reg2st(rs2) & ", " & tostf(target), disas'length);
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_LOAD =>
        imm                     := (others => insn(31));
        imm(11 downto 0)        := imm12;
        disas := strpad(load2str(funct3) & " " & reg2st(rd) & ", " & tosti(imm) & "(" & reg2st(rs1) & ")", disas'length);
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_STORE =>
        imm                     := (others => insn(31));
        imm(11 downto 0)        := insn(31 downto 25) & insn(11 downto 7);
        disas := strpad(store2str(funct3) & " " & reg2st(rs2) & ", " & tosti(imm) & "(" & reg2st(rs1) & ")", disas'length);
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_IMM =>
        imm                   := (others => insn(31));
        imm(11 downto 0)      := imm12;
        case funct3 is
--          when I_SLTIU => -- Unsigned Operands
--            -- qqq Documentation seems to claim sign extension should be done!
--            disas := strpad(imm2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostf(imm12), disas'length);
          when I_SLLI =>
            case funct12 is
              when F12_CLZ =>
                disas := strpad("clz " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_CTZ =>
                disas := strpad("ctz " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_CPOP =>
                disas := strpad("cpop " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_SEXTB =>
                disas := strpad("sext.b " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_SEXTH =>
                disas := strpad("sext.h " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_ZIP=>
                disas := strpad("zip " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when others =>
                case funct7 is
                  when F7_BASE | F7_SUB | F7_BASE_RV64 | F7_SUB_RV64 =>
                    disas := strpad(imm2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
                  when F7_BSET | F7_BSET_I64 =>
                    disas := strpad("bseti " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
                  when F7_BINV | F7_BINV_I64 =>
                    disas := strpad("binvi " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
                  when F7_BCLREXT | F7_BCLREXT_I64=>
                    disas := strpad("bclri " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
                  when others =>
                    disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
                end case;
            end case;
          when I_SRLI =>  -- funct3 for I_SRAI is the same as I_SRLI
            case funct12 is
              when F12_REV8_RV32 =>  -- Really only on RV32.
                disas := strpad("rev8 " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_REV8_RV64 =>  -- Really only on RV64.
                disas := strpad("rev8 " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_BREV8 =>
                disas := strpad("brev8 " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_ORCB =>
                disas := strpad("orc.b " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_ZIP =>
                disas := strpad("unzip " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when others =>
                case funct7 is
                  when F7_BASE | F7_SUB | F7_BASE_RV64 | F7_SUB_RV64 =>
                    disas := strpad(imm2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
                  when F7_ROT | F7_ROR_I64 =>
                    disas := strpad("rori " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
                  when F7_BCLREXT | F7_BCLREXT_I64=>
                    disas := strpad("bexti " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
                  when others =>
                    disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
                end case;
            end case;
          when others =>
            disas := strpad(imm2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tosti(imm), disas'length);
        end case;
        if funct3 = "000" and insn(19 downto 15) = "00000" and insn(11 downto 7) = "00000" and insn(31 downto 20) = "000000000000" then --nop
          return insn2string(insn, pc, strpad("nop", disas'length), cinsn, comp);
        else
          return insn2string(insn, pc, disas, cinsn, comp);
        end if;

      when OP_REG =>
        -- Special case of PACK? (Really only on RV32.)
        if funct12 = F12_ZEXTH and funct3 = R_XOR then
          disas := strpad("zext.h " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
        else
          case funct7 is
            when F7_BASE | F7_SUB =>
              disas := strpad(reg2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
            when F7_MUL =>
              disas := strpad(mul2str(funct3) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
            when F7_SHADD =>
              if funct3(0) = '0' then
                disas := strpad("sh" & tost(funct3(2 downto 1)) & "add " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              else
                disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              end if;
            when F7_MINMAXCLMUL =>
              disas := strpad(minmaxclmul2str(funct3) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
            when F7_ROT =>
              disas := strpad(rot2str(funct3) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
            when F7_BSET =>
              if funct3 = R_SLL then
                disas := strpad("bset " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              elsif funct3 = R_XOR then
                disas := strpad("xperm8 " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              elsif funct3 = R_SLT then
                disas := strpad("xperm4 " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              else
                disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              end if;
            when F7_BINV =>
              if funct3 = R_SLL then
                disas := strpad("binv " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              else
                disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              end if;
            when F7_BCLREXT =>
              if funct3 = R_SLL then
                disas := strpad("bclr " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              elsif funct3 = R_SRL then
                disas := strpad("bext " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              else
                disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              end if;
            when F7_PACK =>
              if funct3 = R_XOR then
                disas := strpad("pack " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              elsif funct3 = R_AND then
                disas := strpad("packh " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              else
                disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              end if;
            when F7_CZERO =>
              if funct3 = R_SRL then
                disas := strpad("czero.eqz " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              elsif funct3 = R_AND then
                disas := strpad("czero.nez " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              else
                disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              end if;
            when others =>
              disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
          end case;
        end if;
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_FENCE =>
        case funct3 is
          when "000" => return insn2string(insn, pc, strpad("fence", disas'length), cinsn, comp);
          when "001" => return insn2string(insn, pc, strpad("fence.i", disas'length), cinsn, comp);
          when "010" => return insn2string(insn, pc, strpad(cbo2str(funct12, rd) & " 0(" & reg2st(rs1) & ")", disas'length), cinsn, comp);
          when others => return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
        end case;

      when OP_SYSTEM =>
        case funct3 is
          when "000" =>
            if rd = "00000" and insn(31 downto 25) = "0001001" then
              disas := strpad("sfence.vma " & reg2st(rs2) & ", " & reg2st(rs1), disas'length);
              return insn2string(insn, pc, disas, cinsn, comp);
            elsif rd = "00000" and insn(31 downto 25) = "0010001" then
              disas := strpad("hfence.vvma " & reg2st(rs2) & ", " & reg2st(rs1), disas'length);
              return insn2string(insn, pc, disas, cinsn, comp);
            elsif rd = "00000" and insn(31 downto 25) = "0110001" then
              disas := strpad("hfence.gvma " & reg2st(rs2) & ", " & reg2st(rs1), disas'length);
              return insn2string(insn, pc, disas, cinsn, comp);
            elsif rd = "00000" and rs1 = "00000" then
              case insn(31 downto 20) is
                when "000000000000" => return insn2string(insn, pc, strpad("ecall", disas'length), cinsn, comp);
                when "000000000001" => return insn2string(insn, pc, strpad("ebreak", disas'length), cinsn, comp);
                when "000000000010" => return insn2string(insn, pc, strpad("uret", disas'length), cinsn, comp);
                when "000100000010" => return insn2string(insn, pc, strpad("sret", disas'length), cinsn, comp);
                when "001100000010" => return insn2string(insn, pc, strpad("mret", disas'length), cinsn, comp);
                when "000100000101" => return insn2string(insn, pc, strpad("wfi", disas'length), cinsn, comp);
                when others => return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
              end case; -- insn(31 downto 25)
            elsif rd = "00000" then
              disas := strpad("sfence.vma " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              return insn2string(insn, pc, disas, cinsn, comp);
            else
              return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
            end if;
          when "001" | "010" | "011" =>
            disas := strpad(csrop2str(funct3) & " " & reg2st(rd) & ", " & csr2str(imm12) & ", " & reg2st(rs1), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when "101" | "110" | "111" =>
            imm                 := (others => '0');
            imm(4 downto 0)     := rs1;
            disas := strpad(csrop2str(funct3) & " " & reg2st(rd) & ", " & csr2str(imm12) & ", " & tosti(imm), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when "100" =>
            case funct7 is
              when F7_MOPR_000 =>
                if funct12 = F12_SSPOP and rd /= "00000" and rs1 = "00000" then
                  disas := strpad("sspop " & reg2st(rd), disas'length);
                elsif funct12 = F12_SSPRR and rd /= "00000" and rs1 = "00000" then
                  disas := strpad("ssprr " & reg2st(rd), disas'length);
                else
                  disas := strpad("mopr " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
                end if;
                return insn2string(insn, pc, disas, cinsn, comp);
              when F7_MOPR_001 | F7_MOPR_010 | F7_MOPR_011 | F7_MOPR_100 |
                   F7_MOPR_101 | F7_MOPR_110 | F7_MOPR_111 =>
                disas := strpad("mopr " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
                return insn2string(insn, pc, disas, cinsn, comp);
              when F7_MOPRR_000 =>
                if rd /= "00000" then
                  disas := strpad("ssamoswap " & reg2st(rd) & ", " & reg2st(rs2) & ", (" & reg2st(rs1) & ")", disas'length);
                elsif insn(24) = '0' then
                  disas := strpad("lpsll " & tost(u2i(insn(23 downto 15))), disas'length);
                else
                  disas := strpad("lpcll " & tost(u2i(insn(23 downto 15))), disas'length);
                end if;
                return insn2string(insn, pc, disas, cinsn, comp);
              when F7_MOPRR_001 =>
                if rd = "00000" then
                  case insn(24 downto 23) is
                    when "00"   => disas := strpad("lpsml " & tost(u2i(insn(22 downto 15))), disas'length);
                    when "01"   => disas := strpad("lpcml " & tost(u2i(insn(22 downto 15))), disas'length);
                    when "10"   => disas := strpad("lpsul " & tost(u2i(insn(22 downto 15))), disas'length);
                    when others => disas := strpad("lpcul " & tost(u2i(insn(22 downto 15))), disas'length);
                  end case;
                else
                  disas := strpad("moprr " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
                end if;
                return insn2string(insn, pc, disas, cinsn, comp);
              when F7_MOPRR_010 =>
                if rd = "00000" and rs1 = "00101" and rs2 = "00001" then
                  disas := strpad("sschkra rs5, rs1", disas'length);
                elsif rd = "00000" and rs1 = "00000" and rs2 /= "00000" then
                  disas := strpad("sspush " & reg2st(rs2), disas'length);
                else
                  disas := strpad("moprr " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
                end if;
                return insn2string(insn, pc, disas, cinsn, comp);
              when F7_MOPRR_011 | F7_MOPRR_100 | F7_MOPRR_101 |
                   F7_MOPRR_110 | F7_MOPRR_111  =>
                disas := strpad("moprr " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
                return insn2string(insn, pc, disas, cinsn, comp);
              when others =>
                if funct7(6 downto 3) = "0110" then
                  if funct7(0) = '0' then
                    if rs2(4 downto 2) = "000" then
                      disas := strpad(hlv2str(funct7(2 downto 0), rs2(1 downto 0)) & " " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
                      return insn2string(insn, pc, disas, cinsn, comp);
                    else
                      return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
                    end if;
                  else -- funct7(0) = '1'
                    if rd = "00000" then
                      disas := strpad(hsv2str(funct7(2 downto 0)) & " " & reg2st(rs2) & ", " & reg2st(rs1), disas'length);
                      return insn2string(insn, pc, disas, cinsn, comp);
                    else
                      return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
                    end if;
                  end if;
                else
                  return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
                end if;
            end case;
          when others => return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
        end case;

        ----------------------------------------------------------------------------
        -- RV64IM Base Instruction Set
        ----------------------------------------------------------------------------

      when OP_IMM_32 =>
        imm                   := (others => insn(31));
        imm(11 downto 0)      := imm12;
        case funct3 is
          when "000" =>
            disas := strpad(immw2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tosti(imm), disas'length);
          when "001" =>
            case funct12 is
              when F12_CLZ =>
                disas := strpad("clzw " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_CTZ =>
                disas := strpad("ctzw " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when F12_CPOP =>
                disas := strpad("cpopw " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
              when others =>
                case funct7 is
                  when F7_BASE | F7_SUB | F7_BASE_RV64 | F7_SUB_RV64 =>
                    disas := strpad(immw2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tost(rs2), disas'length);
                  when F7_ADDSLLIUW | F7_SLLIUW_I64 =>
                    disas := strpad("slli.uw " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
                  when others =>
                    return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
                end case;
            end case;
          when "101" =>
            case funct7 is
              when F7_BASE | F7_SUB | F7_BASE_RV64 | F7_SUB_RV64 =>
                disas := strpad(immw2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tost(rs2), disas'length);
              when F7_ROT | F7_ROR_I64 =>
                disas := strpad("roriw " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
              when others =>
                return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
            end case;
          when others =>
            return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
        end case;
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_32 =>
        -- Special case of PACK? (Really only on RV64.)
        if funct12 = F12_ZEXTH and funct3 = R_XOR then
          disas := strpad("zext.h " & reg2st(rd) & ", " & reg2st(rs1), disas'length);
        else
          case funct7 is
            when F7_BASE | F7_SUB =>
              disas := strpad(regw2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
            when F7_MUL =>
              disas := strpad(mulw2str(funct3) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
            when F7_ADDSLLIUW =>
              if funct3 = R_ADD then
                disas := strpad("add.uw " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              elsif funct3 = R_XOR then
                disas := strpad("packw " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              else
                disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              end if;
            when F7_SHADD =>
              if funct3(0) = '0' then
                disas := strpad("sh" & tost(funct3(2 downto 1)) & "add.uw " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              else
                disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
              end if;
            when F7_ROT =>
              disas := strpad(rotw2str(funct3) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
            when others =>
              disas := strpad("xxx " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
          end case;
        end if;
        return insn2string(insn, pc, disas, cinsn, comp);

        ----------------------------------------------------------------------------
        -- RV[32/64]A Instruction Set
        ----------------------------------------------------------------------------

      when OP_AMO =>
        if funct5 = "00010" then
          disas := strpad(amo2str(funct5, insn(12)) & " " & reg2st(rd) & ", (" & reg2st(rs1) & ")", disas'length);
        else
          disas := strpad(amo2str(funct5, insn(12)) & " " & reg2st(rd) & ", " & reg2st(rs2) & ", (" & reg2st(rs1) & ")", disas'length);
        end if;
        return insn2string(insn, pc, disas, cinsn, comp);

        ----------------------------------------------------------------------------
        -- RV[32/64][F/D] Instruction Set
        ----------------------------------------------------------------------------

      when OP_LOAD_FP =>
        case funct3 is
          when R_WORD =>
            disas := strpad("flw " & fpreg2st(rd) & ", " & tosti(imm12) & "(" & reg2st(rs1) & ")", disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when R_DOUBLE =>
            disas := strpad("fld " & fpreg2st(rd) & ", " & tosti(imm12) & "(" & reg2st(rs1) & ")", disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when R_HALF =>
            disas := strpad("flh " & fpreg2st(rd) & ", " & tosti(imm12) & "(" & reg2st(rs1) & ")", disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when others =>
            disas := strpad("flq " & fpreg2st(rd) & ", " & tosti(imm12) & "(" & reg2st(rs1) & ")", disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
        end case;

      when OP_STORE_FP =>
        case funct3 is
          when R_WORD =>
            disas := strpad("fsw " & fpreg2st(rs2) & ", " & tosti(insn(31 downto 25) & insn(11 downto 7)) & "(" & reg2st(rs1) & ")", disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when R_DOUBLE =>
            disas := strpad("fsd " & fpreg2st(rs2) & ", " & tosti(insn(31 downto 25) & insn(11 downto 7)) & "(" & reg2st(rs1) & ")", disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when R_HALF =>
            disas := strpad("fsh " & fpreg2st(rs2) & ", " & tosti(insn(31 downto 25) & insn(11 downto 7)) & "(" & reg2st(rs1) & ")", disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when others =>
            disas := strpad("fsq " & fpreg2st(rs2) & ", " & tosti(insn(31 downto 25) & insn(11 downto 7)) & "(" & reg2st(rs1) & ")", disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
        end case;

      when OP_FP =>
        disas := strpad(fp2str(insn), disas'length);
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_FMADD =>
        case funct7(1 downto 0) is
          when "00" =>
            disas := strpad("fmadd.s " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5) & rnd2str(insn), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when "01" =>
            disas := strpad("fmadd.d " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5) & rnd2str(insn), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when "10" =>
            disas := strpad("fmadd.h " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5) & rnd2str(insn), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when others =>
            disas := strpad("fmadd.q " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5) & rnd2str(insn), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
        end case;

      when OP_FMSUB =>
        case funct7(1 downto 0) is
          when "00" =>
            disas := strpad("fmsub.s " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when "01" =>
            disas := strpad("fmsub.d " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when "10" =>
            disas := strpad("fmsub.h " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when others =>
            disas := strpad("fmsub.q " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
        end case;

      when OP_FNMSUB =>
        case funct7(1 downto 0) is
          when "00" =>
            disas := strpad("fnmsub.s " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when "01" =>
            disas := strpad("fnmsub.d " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when "10" =>
            disas := strpad("fnmsub.h " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when others =>
            disas := strpad("fnmsub.q " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
        end case;

      when OP_FNMADD =>
        case funct7(1 downto 0) is
          when "00" =>
            disas := strpad("fnmadd.s " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when "01" =>
            disas := strpad("fnmadd.d " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when "10" =>
            disas := strpad("fnmadd.h " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
          when others =>
            disas := strpad("fnmadd.q " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
            return insn2string(insn, pc, disas, cinsn, comp);
        end case;

      when OP_CUSTOM0 =>
        if funct3(2) = '0' then  -- Load
          disas := strpad(custom0_diag2str(insn(23 downto 20), funct3, false) & " " & reg2st(rd) & ", " & "(" & reg2st(rs1) & ")", disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        else                    -- Store
          disas := strpad(custom0_diag2str(insn(10 downto 7), funct3, true) & " " & reg2st(rs2) & ", " & "(" & reg2st(rs1) & ")", disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        end if;

      when others => return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
    end case;
  end;

  function print_str(valid : std_logic; s : string) return string is
  begin
    if valid = '1' then
      return s;
    else
      return "";
    end if;
  end;

  procedure print_insn(hndx       : integer;
                       way        : integer;
                       cycle      : integer;
                       instret    : integer;
                       cdual      : integer;
                       valid      : std_ulogic;
                       pc         : std_logic_vector;
                       rd         : reg_t;
                       csr        : csratype;
                       wrdata     : std_logic_vector;
                       fsd        : std_ulogic;
                       fsd_hi     : std_logic_vector;
                       wren       : std_ulogic;
                       wren_f     : std_ulogic;
                       wcdata     : std_logic_vector;
                       wcen       : std_ulogic;
                       inst       : std_logic_vector(31 downto 0);
                       cinst      : std_logic_vector(15 downto 0);
                       comp       : std_ulogic;
                       prv        : std_logic_vector(1 downto 0);
                       trap       : std_ulogic;
                       cause      : std_logic_vector;
                       tval       : std_logic_vector) is
    variable ipc        : real := 0.0;
    variable dual       : real := 0.0;
    variable vcause     : std_logic_vector(cause'range);
    variable vwrdata    : std_logic_vector(wrdata'range);
    variable vtval      : std_logic_vector(tval'range);
  begin

    -- Evaluate IPC
    if cycle /= 0 then
      ipc       := real(instret) / real(cycle);
    else
      ipc       := real(0);
    end if;

    -- Evaluate Dual Issue Rate
    if instret /= 0 then
      dual      := real(cdual / 2) / real(instret - cdual / 2);
    end if;

    -- Mask exception cause and value in case of no exception
    vwrdata     := wrdata;
    vcause      := (others => '0');
    vtval       := (others => '0');
    if trap = '1' then
      vwrdata   := (others => '0');
      vcause    := cause;
      vtval     := tval;
    end if;

--    if PRINT_ALL or valid = '1' or wren = '1' or wren_f = '1' or wcen = '1' or trap = '1' then
    if PRINT_ALL or valid = '1' or trap = '1' then

      -- Print Instruction
      grlib.testlib.print ("C" & tost(hndx) & " I" & tost(way) & " : " & strpad(tost(cycle), 8) & " [" &
                           tost(valid) & "] " & insn2st(pc, inst, cinst, comp) &
                           print_str(not wren_f,  "W[" & strpad(reg2st(rd),   3)) &
                           print_str(    wren_f, "WF[" & strpad(fpreg2st(rd), 4)) & "=" &
                           print_str(fsd, tost(fsd_hi & vwrdata)) & print_str(not fsd, tost(vwrdata)) &
                           "][" & tost(wren) & "]" &
                           " W[" & strpad(csr2str(csr), 14) & "=" & tost(wcdata) & "][" & tost(wcen) & "]" &
                           " IPC = " & tost(ipc) & " Dual = " & tost(dual) &
                           " E[cause =" & tost(vcause) & "] E[tval =" & tost(vtval) & "][" & tost(trap) & "]" &
                           " PRV[" & tost(prv) & "]" & " Instruction Count = " & tost(instret));
    end if;

  end;

  procedure print_spike_special(
    valid      : std_ulogic;
    pc         : std_logic_vector;
    csr        : csratype;
    wrdata     : std_logic_vector;
    fsd        : std_ulogic;
    fsd_hi     : std_logic_vector;
    wren       : std_ulogic;
    wren_f     : std_ulogic;
    wcdata     : std_logic_vector;
    wcen       : std_ulogic;
    inst       : std_logic_vector(31 downto 0);
    cinst      : std_logic_vector(15 downto 0);
    comp       : std_ulogic;
    prv        : std_logic_vector(1 downto 0);
    trap       : std_ulogic;
    cause      : std_logic_vector;
    tval       : std_logic_vector) is
    variable finst : std_logic_vector(31 downto 0);
    variable vcause : std_logic_vector(cause'range);
    variable wrdata_f : std_logic_vector(wrdata'range);
    variable fsd_hi_f : std_logic_vector(fsd_hi'range);
  begin

    finst := inst;
    if comp = '1' then
      finst := x"0000"&cinst;
    end if;

    vcause := (others=>'0');
    if trap = '1' then
      vcause := cause;
    end if;

    wrdata_f := wrdata;
    for i in wrdata'range loop
      if wrdata(i) = 'X' or wrdata(i) = 'U' then
        wrdata_f(i) := '0';
      end if;
    end loop;
    if fsd = '1' then
      fsd_hi_f := fsd_hi;
      for i in fsd_hi'range loop
        if fsd_hi(i) = 'X' or fsd_hi(i) = 'U' then
          fsd_hi_f(i) := '0';
        end if;
      end loop;
    end if;

--    if valid = '1' or wren = '1' or wren_f = '1' or wcen = '1' or (trap_taken = '1' and trap = '1') then
    if valid = '1' or trap = '1' then
      -- More difference depending on wren_f would perhaps be useful.
      -- Also, high part of fsd (see other prinouts) would be good to have.
      grlib.testlib.print(tost(pc) & " " & tost(finst) & " " &
                          print_str(not wren_f, tost(wren)) &
                          print_str(    wren_f, tost(wren_f)) & " " &
                          print_str(not fsd,    tost(wrdata_f)) &
                          print_str(    fsd,    tost(fsd_hi_f & wrdata_f)) & " " &
                          tost(wcen) & " " & tost(wcdata) & " " &
                          tost(prv) & " " & tost(trap) & " " & tost(vcause) & " " & tost(tval));
    end if;

  end;

  procedure print_insn3(
    hndx       : integer;
    way        : integer;
    cycle      : integer;
    instret    : integer;
    cdual      : integer;
    valid      : std_ulogic;
    pc         : std_logic_vector;
    rd         : reg_t;
    csr        : csratype;
    wrdata     : std_logic_vector;
    fsd        : std_ulogic;
    fsd_hi     : std_logic_vector;
    wren       : std_ulogic;
    wren_f     : std_ulogic;
    wcdata     : std_logic_vector;
    wcen       : std_ulogic;
    inst       : std_logic_vector(31 downto 0);
    cinst      : std_logic_vector(15 downto 0);
    comp       : std_ulogic;
    prv        : std_logic_vector(1 downto 0);
    v          : std_ulogic;
    trap       : std_ulogic;
    cause      : std_logic_vector;
    tval       : std_logic_vector) is
    --variable ipc        : real := 0.0;
    --variable dual       : real := 0.0;
    variable vcause     : std_logic_vector(cause'range);
    variable vwrdata    : std_logic_vector(wrdata'range);
    variable vtval      : std_logic_vector(tval'range);
    variable ls         : std_logic;
  begin

    -- Evaluate IPC
    --if cycle /= 0 then
    --  ipc       := real(instret) / real(cycle);
    --else
    --  ipc       := real(0);
    --end if;

    -- Evaluate Dual Issue Rate
    --if instret /= 0 then
    --  dual      := real(cdual / 2) / real(instret - cdual / 2);
    --end if;

    -- Mask exception cause and value in case of no exception
    vwrdata     := wrdata;
    vcause      := (others => '0');
    vtval       := (others => '0');
    if trap = '1' then
      vwrdata   := (others => '0');
      vcause    := cause;
      vtval     := tval;
    end if;

    ls := is_ld_sd(inst);

--    if PRINT_ALL or valid = '1' or wren = '1' or wren_f = '1' or wcen = '1' or trap = '1' then
    if PRINT_ALL or valid = '1' or trap = '1' then

      -- Print Instruction
      grlib.testlib.print (
          "C" & tost(hndx)
        & " I" & tost(way)
        & " " & prv2string(prv, v)
        & " : " & strpad(tost(cycle), 8)
        & " [" & tost(valid) & "] "
        & insn2st(pc, inst, cinst, comp)
        --& "W[" & strpad(reg2st(rd), 3) & "=" & tost(vwrdata) & "][" & tost(wren) & "]"
        & print_str(not wren_f, print_str((wren   or ls), "[" &
                                          print_str(not fsd, tost(vwrdata)) &
                                          print_str(    fsd, tost(fsd_hi & vwrdata)) & "]"))
        & print_str(    wren_f, print_str((wren_f or ls), "[" & tost(wrdata) & "]"))
        --& " W[" & strpad(csr2str(csr), 14) & "=" & tost(wcdata) & "][" & tost(wcen) & "]"
        & print_str((wcen or ls), "[" & tost(wcdata) & "]")
        --& " IPC = " & tost(ipc) & " Dual = " & tost(dual)
        --& " E[cause =" & tost(vcause) & "] E[tval =" & tost(vtval) & "][" & tost(trap) & "]"
        & print_str(trap, "[" & cause2string(vcause) & "][" & tost(vtval) & "]")
        --& " PRV[" & tost(prv) & "]"
      );
    end if;

  end;


end;
-- pragma translate_on
