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

  function insn2st(pc           : std_logic_vector;
                   insn         : std_logic_vector(31 downto 0);
                   cinsn        : std_logic_vector(15 downto 0);
                   comp         : std_ulogic) return string;

  procedure print_insn(hndx     : integer;
                       way      : integer;
                       cycle    : integer;
                       instret  : integer;
                       cdual    : integer;
                       valid    : std_ulogic;
                       pc       : std_logic_vector;
                       rd       : std_logic_vector(4 downto 0);
                       csr      : std_logic_vector(11 downto 0);
                       wrdata   : std_logic_vector;
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
    rd       : std_logic_vector(4 downto 0);
    csr      : std_logic_vector(11 downto 0);
    wrdata   : std_logic_vector;
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



  procedure print_spike_special(valid      : std_ulogic;
                                pc         : std_logic_vector;
                                csr        : std_logic_vector(11 downto 0);
                                wrdata     : std_logic_vector;
                                wren       : std_ulogic;
                                wren_f     : std_ulogic;
                                wcdata     : std_logic_vector;
                                wcen       : std_ulogic;
                                inst       : std_logic_vector(31 downto 0);
                                cinst      : std_logic_vector(15 downto 0);
                                comp       : std_ulogic;
                                prv        : std_logic_vector(1 downto 0);
                                trap       : std_ulogic;
                                trap_taken : std_ulogic;
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
      when "0000" => return('0');
      when "0001" => return('1');
      when "0010" => return('2');
      when "0011" => return('3');
      when "0100" => return('4');
      when "0101" => return('5');
      when "0110" => return('6');
      when "0111" => return('7');
      when "1000" => return('8');
      when "1001" => return('9');
      when "1010" => return('a');
      when "1011" => return('b');
      when "1100" => return('c');
      when "1101" => return('d');
      when "1110" => return('e');
      when "1111" => return('f');
      when others => return('X');
    end case;
  end;

  type carr is array (0 to 9) of character;

  constant darr : carr := ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9');

  function tosth(v : std_logic_vector) return string is
    constant vlen : natural := v'length; --'
    constant slen : natural := (vlen+3)/4;
    variable vv : std_logic_vector(vlen-1 downto 0);
    variable s : string(1 to slen);
  begin
    vv := v;
    for i in slen downto 1 loop
      s(i) := tohex(vv(3 downto 0));
      vv := "0000" & vv(vlen-1 downto 4);
    end loop;
    return(s);
  end;

  function tostf(v : std_logic_vector) return string is
    constant vlen : natural := v'length; --'
    constant slen : natural := (vlen+3)/4;
    variable vv : std_logic_vector(vlen-1 downto 0);
    variable s : string(1 to slen);
  begin
    vv := v;
    for i in slen downto 1 loop
      s(i) := tohex(vv(3 downto 0));
      vv := "0000" & vv(vlen-1 downto 4);
    end loop;
    return("0x" & s);
  end;

  function tostd(n : integer) return string is
    variable len : integer := 0;
    variable tmp : string(10 downto 1);
    variable v : integer := n;
  begin
    for i in 0 to 9 loop
      tmp(i+1) := darr(v mod 10);
      if tmp(i+1) /= '0'  then
        len := i;
      end if;
      v := v/10;
    end loop;
    return(tmp(len+1 downto 1));
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
      return('-' & tostd(n));
    else
      return(tost(n));
    end if;
  end;

  ----------------------------------------------------------------------------
  -- Instruction Functions and Procedures
  ----------------------------------------------------------------------------
  function is_ld_sd (inst : std_logic_vector(31 downto 0)) return std_logic is
    variable opcode     : std_logic_vector(6 downto 0);
  begin
    opcode        := inst(6 downto 0);
    case opcode is
      when OP_LOAD => return '1';
      when OP_STORE => return '1';
      when OP_AMO => return '1';
      when others => return '0';
    end case;
  end;

  function prv2string(prv : std_logic_vector) return string is
    variable tmp : std_logic_vector(1 downto 0);
  begin
    tmp := prv(1 downto 0);
    case tmp is
      when "11" => return "M";
      when "01" => return "S";
      when "00" => return "U";
      when others => return "X";
    end case;
  end;

  function cause2string(cause : std_logic_vector) return string is
    constant LEN : integer := 64;
    subtype wordx is std_logic_vector(LEN-1 downto 0);
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

    -- Interrupt Codes
    constant IRQ_U_SOFTWARE               : wordx := x"0000000000000000"; --0
    constant IRQ_S_SOFTWARE               : wordx := x"0000000000000001"; --1
    constant IRQ_M_SOFTWARE               : wordx := x"0000000000000003"; --3
    constant IRQ_U_TIMER                  : wordx := x"0000000000000004"; --4
    constant IRQ_S_TIMER                  : wordx := x"0000000000000005"; --5
    constant IRQ_M_TIMER                  : wordx := x"0000000000000007"; --7
    constant IRQ_U_EXTERNAL               : wordx := x"0000000000000008"; --8
    constant IRQ_S_EXTERNAL               : wordx := x"0000000000000009"; --9
    constant IRQ_M_EXTERNAL               : wordx := x"000000000000000B"; --11
  begin
    tmp(cause'left-1 downto cause'right) := cause(cause'left-1 downto cause'right);
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
        when others => return "TRAP: " & tost(tmp);
      end case;
    else
      case tmp is
        when IRQ_U_SOFTWARE                => return "     MIP_USIP     ";
        when IRQ_S_SOFTWARE                => return "     MIP_SSIP     ";
        when IRQ_M_SOFTWARE                => return "     MIP_MSIP     ";
        when IRQ_U_TIMER                   => return "     MIP_UTIP     ";
        when IRQ_S_TIMER                   => return "     MIP_STIP     ";
        when IRQ_M_TIMER                   => return "     MIP_MTIP     ";
        when IRQ_U_EXTERNAL                => return "     MIP_UEIP     ";
        when IRQ_S_EXTERNAL                => return "     MIP_SEIP     ";
        when IRQ_M_EXTERNAL                => return "     MIP_MEIP     ";
        when others => return "MIP: " & tost(tmp);
      end case;
    end if;
  end;

  function insn2string(insn : std_logic_vector; pc : std_logic_vector; disas : string;
                       cinsn : std_logic_vector; comp : std_ulogic) return string is
  begin
    if comp = '0' then
      return("@" & tostf(pc) & " (" & tostf(insn) & ") " & disas);
    else
      return("@" & tostf(pc) & " (" & tostf(cinsn) & ")     " & disas);
    end if;
  end;

  function branch2str(branch : std_logic_vector) return string is
    variable slice : std_logic_vector(2 downto 0);
  begin
    slice := branch;
    case slice is
      when "000" => return("beq");
      when "001" => return("bne");
      when "100" => return("blt");
      when "101" => return("bge");
      when "110" => return("bltu");
      when "111" => return("bgeu");
      when others => return("xxx");
    end case;
  end;

  function load2str(v : std_logic_vector) return string is
    variable slice : std_logic_vector(2 downto 0);
  begin
    slice := v;
    case slice is
      when "000" => return("lb");
      when "001" => return("lh");
      when "010" => return("lw");
      when "100" => return("lbu");
      when "101" => return("lhu");
      when "110" => return("lwu");
      when "011" => return("ld");
      when others => return("xxx");
    end case;
  end;

  function csrop2str(v : std_logic_vector) return string is
    variable slice : std_logic_vector(2 downto 0);
  begin
    slice := v;
    case slice is
      when "001" => return("csrrw");
      when "010" => return("csrrs");
      when "011" => return("csrrc");
      when "101" => return("csrrwi");
      when "110" => return("csrrsi");
      when "111" => return("csrrci");
      when others => return("xxx");
    end case;
  end;

  function store2str(v : std_logic_vector) return string is
    variable slice : std_logic_vector(2 downto 0);
  begin
    slice := v;
    case slice is
      when "000" => return("sb");
      when "001" => return("sh");
      when "010" => return("sw");
      when "011" => return("sd");
      when others => return("xxx");
    end case;
  end;

  function imm2str(v : std_logic_vector; a_bit : std_ulogic) return string is
    variable a : std_ulogic;
    variable slice : std_logic_vector(2 downto 0);
  begin
    slice := v;
    a := a_bit;
    case slice is
      when "000" => return("addi");
      when "010" => return("slti");
      when "011" => return("sltiu");
      when "100" => return("xori");
      when "110" => return("ori");
      when "111" => return("andi");
      when "001" => return("slli");
      when "101" =>
        case a is
          when '0' => return("srli");
          when '1'=> return("srai");
          when others => return("xxx");
        end case;
      when others => return("xxx");
    end case;
  end;

  function immw2str(v : std_logic_vector; a_bit : std_ulogic) return string is
    variable a : std_ulogic;
    variable slice : std_logic_vector(2 downto 0);
  begin
    slice := v;
    a := a_bit;
    case slice is
      when "000" => return("addiw");
      when "001" => return("slliw");
      when "101" =>
        case a is
          when '0' => return("srliw");
          when '1'=> return("sraiw");
          when others => return("xxx");
        end case;
      when others => return("xxx");
    end case;
  end;

  function reg2str(v : std_logic_vector; a_bit : std_ulogic) return string is
    variable a : std_ulogic;
    variable slice : std_logic_vector(2 downto 0);
  begin
    slice := v;
    a := a_bit;
    case slice is
      when "000" =>
        case a is
          when '0' => return("add");
          when '1'=> return("sub");
          when others => return("xxx");
        end case;
      when "001" => return("sll");
      when "010" => return("slt");
      when "011" => return("sltu");
      when "100" => return("xor");
      when "101" =>
        case a is
          when '0' => return("srl");
          when '1'=> return("sra");
          when others => return("xxx");
        end case;
      when "110" => return("or");
      when "111" => return("and");
      when others => return("xxx");
    end case;
  end;

  function regw2str(v : std_logic_vector; a_bit : std_ulogic) return string is
    variable a : std_ulogic;
    variable slice : std_logic_vector(2 downto 0);
  begin
    slice := v;
    a := a_bit;
    case slice is
      when "000" =>
        case a is
          when '0' => return("addw");
          when '1'=> return("subw");
          when others => return("xxx");
        end case;
      when "001" => return("sllw");
      when "101" =>
        case a is
          when '0' => return("srlw");
          when '1'=> return("sraw");
          when others => return("xxx");
        end case;
      when others => return("xxx");
    end case;
  end;

  function mul2str(v : std_logic_vector) return string is
    variable slice : std_logic_vector(2 downto 0);
  begin
    slice := v;
    case slice is
      when "000" => return("mul");
      when "001" => return("mulh");
      when "010" => return("mulhsu");
      when "011" => return("mulhu");
      when "100" => return("div");
      when "101" => return("divu");
      when "110" => return("rem");
      when "111" => return("remu");
      when others => return("xxx");
    end case;
  end;

  function mulw2str(v : std_logic_vector) return string is
    variable slice : std_logic_vector(2 downto 0);
  begin
    slice := v;
    case slice is
      when "000" => return("mulw");
      when "100" => return("divw");
      when "101" => return("divuw");
      when "110" => return("remw");
      when "111" => return("remuw");
      when others => return("xxx");
    end case;
  end;

  function amo2str(v : std_logic_vector; w : std_ulogic) return string is
    variable slice : std_logic_vector(4 downto 0);
    variable size  : string(1 to 2);
  begin
    slice := v;
    if w = '0' then
      size := ".w";
    else
      size := ".d";
    end if;
    case slice is
      when "00010" => return("lr" & size);
      when "00011" => return("sc" & size);
      when "00001" => return("amoswap" & size);
      when "00000" => return("amoadd" & size);
      when "00100" => return("amoxor" & size);
      when "01100" => return("amoand" & size);
      when "01000" => return("amoor" & size);
      when "10000" => return("amomin" & size);
      when "10100" => return("amomax" & size);
      when "11000" => return("amominu" & size);
      when "11100" => return("amomaxu" & size);
      when others => return("xxx");
    end case;
  end;

  -- General Purpose Register ----------------------------------------
  function reg2st(v : std_logic_vector) return string is
    variable reg : std_logic_vector(4 downto 0);
  begin
    reg := v;
    case reg(4 downto 0) is
      when GPR_X0       => return("x0");
      when GPR_RA       => return("ra");
      when GPR_SP       => return("sp");
      when GPR_GP       => return("gp");
      when GPR_TP       => return("tp");
      when GPR_T0       => return("t0");
      when GPR_T1       => return("t1");
      when GPR_T2       => return("t2");
      when GPR_FP       => return("fp");
      when GPR_S1       => return("s1");
      when GPR_A0       => return("a0");
      when GPR_A1       => return("a1");
      when GPR_A2       => return("a2");
      when GPR_A3       => return("a3");
      when GPR_A4       => return("a4");
      when GPR_A5       => return("a5");
      when GPR_A6       => return("a6");
      when GPR_A7       => return("a7");
      when GPR_S2       => return("s2");
      when GPR_S3       => return("s3");
      when GPR_S4       => return("s4");
      when GPR_S5       => return("s5");
      when GPR_S6       => return("s6");
      when GPR_S7       => return("s7");
      when GPR_S8       => return("s8");
      when GPR_S9       => return("s9");
      when GPR_S10      => return("s10");
      when GPR_S11      => return("s11");
      when GPR_T3       => return("t3");
      when GPR_T4       => return("t4");
      when GPR_T5       => return("t5");
      when GPR_T6       => return("t6");
      when others       => return("XXX");
    end case;
  end;

  -- Control Status Register ----------------------------------------
  function csr2str(v : std_logic_vector) return string is
    variable reg : std_logic_vector(11 downto 0);
  begin
    reg := v;
    case reg is
      -- User Trap Setup
      when CSR_USTATUS          => return("ustatus");
      when CSR_UIE              => return("uie");
      when CSR_UTVEC            => return("utvec");
      -- User Trap Handling
      when CSR_USCRATCH         => return("uscratch");
      when CSR_UEPC             => return("uepc");
      when CSR_UCAUSE           => return("ucause");
      when CSR_UTVAL            => return("utval");
      when CSR_UIP              => return("uip");
      -- User Floating-Point CSRs
      when CSR_FFLAGS           => return("fflags");
      when CSR_FRM              => return("frm");
      when CSR_FCSR             => return("fcsr");
      -- User Counters/Timers
      when CSR_CYCLE            => return("cycle");
      when CSR_TIME             => return("time");
      when CSR_INSTRET          => return("instret");
      when CSR_HPMCOUNTER3      => return("hpmcounter3");
      when CSR_HPMCOUNTER4      => return("hpmcounter4");
      when CSR_HPMCOUNTER5      => return("hpmcounter5");
      when CSR_HPMCOUNTER6      => return("hpmcounter6");
      when CSR_HPMCOUNTER7      => return("hpmcounter7");
      when CSR_HPMCOUNTER8      => return("hpmcounter8");
      when CSR_HPMCOUNTER9      => return("hpmcounter9");
      when CSR_HPMCOUNTER10     => return("hpmcounter10");
      when CSR_HPMCOUNTER11     => return("hpmcounter11");
      when CSR_HPMCOUNTER12     => return("hpmcounter12");
      when CSR_HPMCOUNTER13     => return("hpmcounter13");
      when CSR_HPMCOUNTER14     => return("hpmcounter14");
      when CSR_HPMCOUNTER15     => return("hpmcounter15");
      when CSR_HPMCOUNTER16     => return("hpmcounter16");
      when CSR_HPMCOUNTER17     => return("hpmcounter17");
      when CSR_HPMCOUNTER18     => return("hpmcounter18");
      when CSR_HPMCOUNTER19     => return("hpmcounter19");
      when CSR_HPMCOUNTER20     => return("hpmcounter20");
      when CSR_HPMCOUNTER21     => return("hpmcounter21");
      when CSR_HPMCOUNTER22     => return("hpmcounter22");
      when CSR_HPMCOUNTER23     => return("hpmcounter23");
      when CSR_HPMCOUNTER24     => return("hpmcounter24");
      when CSR_HPMCOUNTER25     => return("hpmcounter25");
      when CSR_HPMCOUNTER26     => return("hpmcounter26");
      when CSR_HPMCOUNTER27     => return("hpmcounter27");
      when CSR_HPMCOUNTER28     => return("hpmcounter28");
      when CSR_HPMCOUNTER29     => return("hpmcounter29");
      when CSR_HPMCOUNTER30     => return("hpmcounter30");
      when CSR_HPMCOUNTER31     => return("hpmcounter31");
      -- High (RV32)
      when CSR_CYCLEH           => return("cycleh");
      when CSR_TIMEH            => return("timeh");
      when CSR_INSTRETH         => return("instreth");
      when CSR_HPMCOUNTER3H     => return("hpmcounter3h");
      when CSR_HPMCOUNTER4H     => return("hpmcounter4h");
      when CSR_HPMCOUNTER5H     => return("hpmcounter5h");
      when CSR_HPMCOUNTER6H     => return("hpmcounter6h");
      when CSR_HPMCOUNTER7H     => return("hpmcounter7h");
      when CSR_HPMCOUNTER8H     => return("hpmcounter8h");
      when CSR_HPMCOUNTER9H     => return("hpmcounter9h");
      when CSR_HPMCOUNTER10H    => return("hpmcounter10h");
      when CSR_HPMCOUNTER11H    => return("hpmcounter11h");
      when CSR_HPMCOUNTER12H    => return("hpmcounter12h");
      when CSR_HPMCOUNTER13H    => return("hpmcounter13h");
      when CSR_HPMCOUNTER14H    => return("hpmcounter14h");
      when CSR_HPMCOUNTER15H    => return("hpmcounter15h");
      when CSR_HPMCOUNTER16H    => return("hpmcounter16h");
      when CSR_HPMCOUNTER17H    => return("hpmcounter17h");
      when CSR_HPMCOUNTER18H    => return("hpmcounter18h");
      when CSR_HPMCOUNTER19H    => return("hpmcounter19h");
      when CSR_HPMCOUNTER20H    => return("hpmcounter20h");
      when CSR_HPMCOUNTER21H    => return("hpmcounter21h");
      when CSR_HPMCOUNTER22H    => return("hpmcounter22h");
      when CSR_HPMCOUNTER23H    => return("hpmcounter23h");
      when CSR_HPMCOUNTER24H    => return("hpmcounter24h");
      when CSR_HPMCOUNTER25H    => return("hpmcounter25h");
      when CSR_HPMCOUNTER26H    => return("hpmcounter26h");
      when CSR_HPMCOUNTER27H    => return("hpmcounter27h");
      when CSR_HPMCOUNTER28H    => return("hpmcounter28h");
      when CSR_HPMCOUNTER29H    => return("hpmcounter29h");
      when CSR_HPMCOUNTER30H    => return("hpmcounter30h");
      when CSR_HPMCOUNTER31H    => return("hpmcounter31h");
      -- Supervisor Trap Setup
      when CSR_SSTATUS          => return("sstatus");
      when CSR_SEDELEG          => return("sedeleg");
      when CSR_SIDELEG          => return("sideleg");
      when CSR_SIE              => return("sie");
      when CSR_STVEC            => return("stvec");
      when CSR_SCOUNTEREN       => return("scounteren");
      -- Supervisor Trap Handling
      when CSR_SSCRATCH         => return("sscratch");
      when CSR_SEPC             => return("sepc");
      when CSR_SCAUSE           => return("scause");
      when CSR_STVAL            => return("stval");
      when CSR_SIP              => return("sip");
      -- Supervisor Protection and Translation
      when CSR_SATP             => return("satp");

      -- Hypervisor Trap Setup
      when CSR_HSTATUS          => return("hstatus");
      when CSR_HEDELEG          => return("hedeleg");
      when CSR_HIDELEG          => return("hideleg");
      when CSR_HIE              => return("hie");
      when CSR_HCOUNTEREN       => return("hcounteren");
      when CSR_HGEIE            => return("hgeie");
      -- Hypervisor Trap Handling
      when CSR_HTVAL            => return("htval");
      when CSR_HIP              => return("hip");
      when CSR_HVIP             => return("hvip");
      when CSR_HTINST           => return("htinst");
      when CSR_HGEIP            => return("hgeip");
      -- Hypervisor Protection and Translation
      when CSR_HGATP            => return("hgatp");
      -- Hypervisor Counter/Timer Virtualization Registers
      when CSR_HTIMEDELTA       => return("htimedelta");
      -- High (RV32)
      when CSR_HTIMEDELTAH      => return("htimedeltah");

      -- Virtual Supervisor Registers
      when CSR_VSSTATUS         => return("vsstatus");
      when CSR_VSIE             => return("vsie");
      when CSR_VSTVEC           => return("vstvec");
      when CSR_VSSCRATCH        => return("vsscratch");
      when CSR_VSEPC            => return("vsepc");
      when CSR_VSCAUSE          => return("vscause");
      when CSR_VSTVAL           => return("vstval");
      when CSR_VSIP             => return("vsip");
      when CSR_VSATP            => return("vsatp");

      -- Machine Information Registers
      when CSR_MVENDORID        => return("mvendorid");
      when CSR_MARCHID          => return("marchid");
      when CSR_MIMPID           => return("mimpid");
      when CSR_MHARTID          => return("mhartid");
      -- Machine Trap Setup
      when CSR_MSTATUS          => return("mstatus");
      when CSR_MISA             => return("misa");
      when CSR_MEDELEG          => return("medeleg");
      when CSR_MIDELEG          => return("mideleg");
      when CSR_MIE              => return("mie");
      when CSR_MTVEC            => return("mtvec");
      when CSR_MCOUNTEREN       => return("mcounteren");
      -- High (RV32)
      when CSR_MSTATUSH         => return("mstatush");
      -- Machine Trap Handling
      when CSR_MSCRATCH         => return("mscratch");
      when CSR_MEPC             => return("mepc");
      when CSR_MCAUSE           => return("mcause");
      when CSR_MTVAL            => return("mtval");
      when CSR_MIP              => return("mip");
      when CSR_MTINST           => return("minst");
      when CSR_MTVAL2           => return("mtval2");
      -- Machine Protection and Translation
      when CSR_PMPCFG0          => return("pmpcfg0");
      when CSR_PMPCFG1          => return("pmpcfg1");
      when CSR_PMPCFG2          => return("pmpcfg2");
      when CSR_PMPCFG3          => return("pmpcfg3");
      when CSR_PMPADDR0         => return("pmpaddr0");
      when CSR_PMPADDR1         => return("pmpaddr1");
      when CSR_PMPADDR2         => return("pmpaddr2");
      when CSR_PMPADDR3         => return("pmpaddr3");
      when CSR_PMPADDR4         => return("pmpaddr4");
      when CSR_PMPADDR5         => return("pmpaddr5");
      when CSR_PMPADDR6         => return("pmpaddr6");
      when CSR_PMPADDR7         => return("pmpaddr7");
      when CSR_PMPADDR8         => return("pmpaddr8");
      when CSR_PMPADDR9         => return("pmpaddr9");
      when CSR_PMPADDR10        => return("pmpaddr10");
      when CSR_PMPADDR11        => return("pmpaddr11");
      when CSR_PMPADDR12        => return("pmpaddr12");
      when CSR_PMPADDR13        => return("pmpaddr13");
      when CSR_PMPADDR14        => return("pmpaddr14");
      when CSR_PMPADDR15        => return("pmpaddr15");
      -- Machine Counter/Timers
      when CSR_MCYCLE           => return("mcycle");
      when CSR_MINSTRET         => return("minstret");
      when CSR_MHPMCOUNTER3     => return("mhpmcounter3");
      when CSR_MHPMCOUNTER4     => return("mhpmcounter4");
      when CSR_MHPMCOUNTER5     => return("mhpmcounter5");
      when CSR_MHPMCOUNTER6     => return("mhpmcounter6");
      when CSR_MHPMCOUNTER7     => return("mhpmcounter7");
      when CSR_MHPMCOUNTER8     => return("mhpmcounter8");
      when CSR_MHPMCOUNTER9     => return("mhpmcounter9");
      when CSR_MHPMCOUNTER10    => return("mhpmcounter10");
      when CSR_MHPMCOUNTER11    => return("mhpmcounter11");
      when CSR_MHPMCOUNTER12    => return("mhpmcounter12");
      when CSR_MHPMCOUNTER13    => return("mhpmcounter13");
      when CSR_MHPMCOUNTER14    => return("mhpmcounter14");
      when CSR_MHPMCOUNTER15    => return("mhpmcounter15");
      when CSR_MHPMCOUNTER16    => return("mhpmcounter16");
      when CSR_MHPMCOUNTER17    => return("mhpmcounter17");
      when CSR_MHPMCOUNTER18    => return("mhpmcounter18");
      when CSR_MHPMCOUNTER19    => return("mhpmcounter19");
      when CSR_MHPMCOUNTER20    => return("mhpmcounter20");
      when CSR_MHPMCOUNTER21    => return("mhpmcounter21");
      when CSR_MHPMCOUNTER22    => return("mhpmcounter22");
      when CSR_MHPMCOUNTER23    => return("mhpmcounter23");
      when CSR_MHPMCOUNTER24    => return("mhpmcounter24");
      when CSR_MHPMCOUNTER25    => return("mhpmcounter25");
      when CSR_MHPMCOUNTER26    => return("mhpmcounter26");
      when CSR_MHPMCOUNTER27    => return("mhpmcounter27");
      when CSR_MHPMCOUNTER28    => return("mhpmcounter28");
      when CSR_MHPMCOUNTER29    => return("mhpmcounter29");
      when CSR_MHPMCOUNTER30    => return("mhpmcounter30");
      when CSR_MHPMCOUNTER31    => return("mhpmcounter31");
      -- High (RV32)
      when CSR_MCYCLEH          => return("mcycleh");
      when CSR_MINSTRETH        => return("minstreth");
      when CSR_MHPMCOUNTER3H    => return("mhpmcounter3h");
      when CSR_MHPMCOUNTER4H    => return("mhpmcounter4h");
      when CSR_MHPMCOUNTER5H    => return("mhpmcounter5h");
      when CSR_MHPMCOUNTER6H    => return("mhpmcounter6h");
      when CSR_MHPMCOUNTER7H    => return("mhpmcounter7h");
      when CSR_MHPMCOUNTER8H    => return("mhpmcounter8h");
      when CSR_MHPMCOUNTER9H    => return("mhpmcounter9h");
      when CSR_MHPMCOUNTER10H   => return("mhpmcounter10h");
      when CSR_MHPMCOUNTER11H   => return("mhpmcounter11h");
      when CSR_MHPMCOUNTER12H   => return("mhpmcounter12h");
      when CSR_MHPMCOUNTER13H   => return("mhpmcounter13h");
      when CSR_MHPMCOUNTER14H   => return("mhpmcounter14h");
      when CSR_MHPMCOUNTER15H   => return("mhpmcounter15h");
      when CSR_MHPMCOUNTER16H   => return("mhpmcounter16h");
      when CSR_MHPMCOUNTER17H   => return("mhpmcounter17h");
      when CSR_MHPMCOUNTER18H   => return("mhpmcounter18h");
      when CSR_MHPMCOUNTER19H   => return("mhpmcounter19h");
      when CSR_MHPMCOUNTER20H   => return("mhpmcounter20h");
      when CSR_MHPMCOUNTER21H   => return("mhpmcounter21h");
      when CSR_MHPMCOUNTER22H   => return("mhpmcounter22h");
      when CSR_MHPMCOUNTER23H   => return("mhpmcounter23h");
      when CSR_MHPMCOUNTER24H   => return("mhpmcounter24h");
      when CSR_MHPMCOUNTER25H   => return("mhpmcounter25h");
      when CSR_MHPMCOUNTER26H   => return("mhpmcounter26h");
      when CSR_MHPMCOUNTER27H   => return("mhpmcounter27h");
      when CSR_MHPMCOUNTER28H   => return("mhpmcounter28h");
      when CSR_MHPMCOUNTER29H   => return("mhpmcounter29h");
      when CSR_MHPMCOUNTER30H   => return("mhpmcounter30h");
      when CSR_MHPMCOUNTER31H   => return("mhpmcounter31h");
      -- Machine Counter Setup
      when CSR_MCOUNTINHIBIT    => return("mcountinhibit");
      when CSR_MHPMEVENT3       => return("mhpmevent3");
      when CSR_MHPMEVENT4       => return("mhpmevent4");
      when CSR_MHPMEVENT5       => return("mhpmevent5");
      when CSR_MHPMEVENT6       => return("mhpmevent6");
      when CSR_MHPMEVENT7       => return("mhpmevent7");
      when CSR_MHPMEVENT8       => return("mhpmevent8");
      when CSR_MHPMEVENT9       => return("mhpmevent9");
      when CSR_MHPMEVENT10      => return("mhpmevent10");
      when CSR_MHPMEVENT11      => return("mhpmevent11");
      when CSR_MHPMEVENT12      => return("mhpmevent12");
      when CSR_MHPMEVENT13      => return("mhpmevent13");
      when CSR_MHPMEVENT14      => return("mhpmevent14");
      when CSR_MHPMEVENT15      => return("mhpmevent15");
      when CSR_MHPMEVENT16      => return("mhpmevent16");
      when CSR_MHPMEVENT17      => return("mhpmevent17");
      when CSR_MHPMEVENT18      => return("mhpmevent18");
      when CSR_MHPMEVENT19      => return("mhpmevent19");
      when CSR_MHPMEVENT20      => return("mhpmevent20");
      when CSR_MHPMEVENT21      => return("mhpmevent21");
      when CSR_MHPMEVENT22      => return("mhpmevent22");
      when CSR_MHPMEVENT23      => return("mhpmevent23");
      when CSR_MHPMEVENT24      => return("mhpmevent24");
      when CSR_MHPMEVENT25      => return("mhpmevent25");
      when CSR_MHPMEVENT26      => return("mhpmevent26");
      when CSR_MHPMEVENT27      => return("mhpmevent27");
      when CSR_MHPMEVENT28      => return("mhpmevent28");
      when CSR_MHPMEVENT29      => return("mhpmevent29");
      when CSR_MHPMEVENT30      => return("mhpmevent30");
      when CSR_MHPMEVENT31      => return("mhpmevent31");
      -- Debug/Trace Registers
      when CSR_TSELECT          => return("tselect");
      when CSR_TDATA1           => return("tdata1");
      when CSR_TDATA2           => return("tdata2");
      when CSR_TDATA3           => return("tdata3");
      -- Debug Mode Registers
      when CSR_DCSR             => return("dcsr");
      when CSR_DPC              => return("dpc");
      when CSR_DSCRATCH0        => return("dscratch0");
      when CSR_DSCRATCH1        => return("dscratch1");
      when others               => return("unknown");
    end case;
  end;

  -- Floating Point Register ----------------------------------------
  function fpreg2st(v : std_logic_vector) return string is
    variable reg : std_logic_vector(4 downto 0);
  begin
    reg := v;
    case reg(4 downto 0) is
      when FPU_FT0      => return("ft0");
      when FPU_FT1      => return("ft1");
      when FPU_FT2      => return("ft2");
      when FPU_FT3      => return("ft3");
      when FPU_FT4      => return("ft4");
      when FPU_FT5      => return("ft5");
      when FPU_FT6      => return("ft6");
      when FPU_FT7      => return("ft7");
      when FPU_FS0      => return("fs0");
      when FPU_FS1      => return("fs1");
      when FPU_FA0      => return("fa0");
      when FPU_FA1      => return("fa1");
      when FPU_FA2      => return("fa2");
      when FPU_FA3      => return("fa3");
      when FPU_FA4      => return("fa4");
      when FPU_FA5      => return("fa5");
      when FPU_FA6      => return("fa6");
      when FPU_FA7      => return("fa7");
      when FPU_FS2      => return("fs2");
      when FPU_FS3      => return("fs3");
      when FPU_FS4      => return("fs4");
      when FPU_FS5      => return("fs5");
      when FPU_FS6      => return("fs6");
      when FPU_FS7      => return("fs7");
      when FPU_FS8      => return("fs8");
      when FPU_FS9      => return("fs9");
      when FPU_FS10     => return("fs10");
      when FPU_FS11     => return("fs11");
      when FPU_FT8      => return("ft8");
      when FPU_FT9      => return("ft9");
      when FPU_FT10     => return("ft10");
      when FPU_FT11     => return("ft11");
      when others       => return("XXXX");
    end case;
  end;

  function fp2str(insn : std_logic_vector) return string is
    constant rs1        : std_logic_vector(4 downto 0) := insn(19 downto 15);
    constant rs2        : std_logic_vector(4 downto 0) := insn(24 downto 20);
    constant rd         : std_logic_vector(4 downto 0) := insn(11 downto 7);
    constant funct3     : std_logic_vector(2 downto 0) := insn(14 downto 12);
    constant funct5     : std_logic_vector(4 downto 0) := insn(31 downto 27);
    constant funct7     : std_logic_vector(6 downto 0) := insn(31 downto 25);
    constant rs2low     : std_logic_vector(1 downto 0) := rs2(1 downto 0);
    constant fdf1f2     : string :=  " " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2);
    constant idf1f2     : string :=  " " &   reg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2);
    constant fdf1       : string :=  " " & fpreg2st(rd) & ", " & fpreg2st(rs1);
    constant fdi1       : string :=  " " & fpreg2st(rd) & ", " &   reg2st(rs1);
    constant idf1       : string :=  " " &   reg2st(rd) & ", " & fpreg2st(rs1);
    variable size       : string(1 to 2);
  begin
    case funct7(1 downto 0) is
      when "00"   => size := ".s";
      when "01"   => size := ".d";
      when "10"   => size := ".h";
      when others => size := ".q";
    end case;

    case funct7(6 downto 2) is
      when R_FADD  => return("fadd"  & size & fdf1f2);
      when R_FSUB  => return("fsub"  & size & fdf1f2);
      when R_FMUL  => return("fmul"  & size & fdf1f2);
      when R_FDIV  => return("fdiv"  & size & fdf1f2);
      when R_FSQRT => return("fsqrt" & size & fdf1);
      when R_FSGN  =>
        case funct3 is
          when R_FSGNJ  => return("fsgnj"  & size & fdf1f2);
          when R_FSGNJN => return("fsgnjn" & size & fdf1f2);
          when R_FSGNJX => return("fsgnjx" & size & fdf1f2);
          when others   => return("xxx");
        end case;
      when R_FMIN =>
        if funct3(0) = '0' then
          return("fmin" & size & fdf1f2);
        else
          return("fmax" & size & fdf1f2);
        end if;
      when R_FCVT_W_S =>
        case rs2low is
          when "00"   => return("fcvt.w"  & size & idf1);
          when "01"   => return("fcvt.wu" & size & idf1);
          when "10"   => return("fcvt.l"  & size & idf1);
          when others => return("fcvt.lu" & size & idf1);
        end case;
      when R_FMV_X_W =>
        if funct3(0) = '0' then
          if funct7(0) = '0' then
            return("fmv.x.w" & idf1);
          else
            return("fmv.x.d" & idf1);
          end if;
        else
          return("fclass" & size & idf1);
        end if;
      when R_FCMP =>
        case funct3 is
          when R_FEQ  => return("feq" & size & idf1f2);
          when R_FLT  => return("flt" & size & idf1f2);
          when R_FLE  => return("fle" & size & idf1f2);
          when others => return("xxx");
        end case;
      when R_FCVT_S_W =>
        case rs2low is
          when "00"   => return("fcvt" & size & ".w"  & fdi1);
          when "01"   => return("fcvt" & size & ".wu" & fdi1);
          when "10"   => return("fcvt" & size & ".l"  & fdi1);
          when others => return("fcvt" & size & ".lu" & fdi1);
        end case;
      when R_FMV_W_X =>
        if funct7(0) = '0' then
          return("fmv.w.x" & fdi1);
        else
          return("fmv.d.x" & fdi1);
        end if;
      when R_FCVT_S_D =>
        if rs2(0) = '0' then
          return("fcvt.d.s" & fdf1);
        else
          return("fcvt.s.d" & fdf1);
        end if;

      when others => return("xxx");
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

  function insn2st(pc           : std_logic_vector;
                   insn         : std_logic_vector(31 downto 0);
                   cinsn        : std_logic_vector(15 downto 0);
                   comp         : std_ulogic) return string is

    constant bb2        : string(1 to 2) := (others => ' ');
    constant bb4        : string(1 to 4) := (others => ' ');
    variable rs1        : std_logic_vector(4 downto 0);
    variable rs2        : std_logic_vector(4 downto 0);
    variable rd         : std_logic_vector(4 downto 0);
    variable imm12      : std_logic_vector(11 downto 0);
    variable imm20      : std_logic_vector(19 downto 0);
    variable opcode     : std_logic_vector(6 downto 0);
    variable funct3     : std_logic_vector(2 downto 0);
    variable funct5     : std_logic_vector(4 downto 0);
    variable funct7     : std_logic_vector(6 downto 0);

    variable disas      : string(1 to 35) := (others => ' ');
    variable imm13      : std_logic_vector(12 downto 0);
    variable imm        : std_logic_vector(31 downto 0);

    variable target     : std_logic_vector(64 downto 0);
    variable target_op  : std_logic_vector(63 downto 0);

  begin

    opcode        := insn(6 downto 0);
    rd            := insn(11 downto 7);
    rs1           := insn(19 downto 15);
    rs2           := insn(24 downto 20);
    funct3        := insn(14 downto 12);
    funct5        := insn(31 downto 27);
    funct7        := insn(31 downto 25);
    imm12         := insn(31 downto 20);
    imm20         := insn(31 downto 12);
    imm           := (others => '0');
    target        := (others => '0');

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
          when I_SLLI | I_SRLI =>  -- funct3 for I_SRAI is the same as I_SRLI
            disas := strpad(imm2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tostd(imm12(5 downto 0)), disas'length);
          when others =>
            disas := strpad(imm2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tosti(imm), disas'length);
        end case;
        if funct3 = "000" and insn(19 downto 15) = "00000" and insn(11 downto 7) = "00000" and insn(31 downto 20) = "000000000000" then --nop
          return insn2string(insn, pc, strpad("nop", disas'length), cinsn, comp);
        else
          return insn2string(insn, pc, disas, cinsn, comp);
        end if;

      when OP_REG =>
        if insn(25) = '0' then
          disas := strpad(reg2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        else -- Multiplication Operations
          disas := strpad(mul2str(funct3) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        end if;

      when OP_FENCE =>
        case funct3 is
          when "000" => return insn2string(insn, pc, strpad("fence", disas'length), cinsn, comp);
          when "001" => return insn2string(insn, pc, strpad("fence.i", disas'length), cinsn, comp);
          when others => return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
        end case;

      when OP_SYSTEM =>
        case funct3 is
          when "000" =>
            if rd = "00000" and insn(31 downto 25) = "0001001" then
              disas := strpad("sfence.vma " & reg2st(rs2) & ", " & reg2st(rs1), disas'length);
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
          when others => return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
        end case;

        ----------------------------------------------------------------------------
        -- RV64IM Base Instruction Set
        ----------------------------------------------------------------------------

      when OP_IMM_32 =>
        imm                   := (others => insn(31));
        imm(11 downto 0)      := imm12;
        case funct3 is
          when "000" => disas := strpad(immw2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tosti(imm), disas'length);
          when "001" | "101" => disas := strpad(immw2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & tost(rs2), disas'length);
          when others => return insn2string(insn, pc, strpad("unknown instruction", disas'length), cinsn, comp);
        end case;
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_32 =>
        if insn(25) = '0' then
          disas := strpad(regw2str(funct3, insn(30)) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        else -- Multiplication Disas
          disas := strpad(mulw2str(funct3) & " " & reg2st(rd) & ", " & reg2st(rs1) & ", " & reg2st(rs2), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        end if;

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
        if funct3 = R_WORD then
          disas := strpad("flw " & fpreg2st(rd) & ", " & tosti(imm12) & "(" & reg2st(rs1) & ")", disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        else  -- Assume funct3 = R_DOUBLE
          disas := strpad("fld " & fpreg2st(rd) & ", " & tosti(imm12) & "(" & reg2st(rs1) & ")", disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        end if;

      when OP_STORE_FP =>
        if funct3 = R_WORD then
          disas := strpad("fsw " & fpreg2st(rs2) & ", " & tosti(insn(31 downto 25) & insn(11 downto 7)) & "(" & reg2st(rs1) & ")", disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        else  -- Assume funct3 = R_DOUBLE
          disas := strpad("fsd " & fpreg2st(rs2) & ", " & tosti(insn(31 downto 25) & insn(11 downto 7)) & "(" & reg2st(rs1) & ")", disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        end if;

      when OP_FP =>
        disas := strpad(fp2str(insn), disas'length);
        return insn2string(insn, pc, disas, cinsn, comp);

      when OP_FMADD =>
        if insn(25) = '0' then
          disas := strpad("fmadd.s " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        else
          disas := strpad("fmadd.d " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        end if;

      when OP_FMSUB =>
        if insn(25) = '0' then
          disas := strpad("fmsub.s " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        else
          disas := strpad("fmsub.d " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        end if;

      when OP_FNMSUB =>
        if insn(25) = '0' then
          disas := strpad("fnmsub.s " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        else
          disas := strpad("fnmsub.d " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        end if;

      when OP_FNMADD =>
        if insn(25) = '0' then
          disas := strpad("fnmadd.s " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
          return insn2string(insn, pc, disas, cinsn, comp);
        else
          disas := strpad("fnmadd.d " & fpreg2st(rd) & ", " & fpreg2st(rs1) & ", " & fpreg2st(rs2) & ", " & fpreg2st(funct5), disas'length);
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
                       rd         : std_logic_vector(4 downto 0);
                       csr        : std_logic_vector(11 downto 0);
                       wrdata     : std_logic_vector;
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
    vcause      := (others => '0');
    vtval       := (others => '0');
    if trap = '1' then
      vcause    := cause;
      vtval     := tval;
    end if;

    if PRINT_ALL or valid = '1' or wren = '1' or wren_f = '1' or wcen = '1' or trap = '1' then

      -- Print Instruction
      if wren_f = '0' then
        grlib.testlib.print ("C" & tost(hndx) & " I" & tost(way) & " : " & strpad(tost(cycle), 8) & " [" &
                             tost(valid) & "] " & insn2st(pc, inst, cinst, comp) &
                             "W[" & strpad(reg2st(rd), 3) & "=" & tost(wrdata) & "][" & tost(wren) & "]" &
                             " W[" & strpad(csr2str(csr), 13) & "=" & tost(wcdata) & "][" & tost(wcen) & "]" &
                             " IPC = " & tost(ipc) & " Dual = " & tost(dual) &
                             " E[cause =" & tost(vcause) & "] E[tval =" & tost(vtval) & "][" & tost(trap) & "]" &
                             " PRV[" & tost(prv) & "]");
      else
        grlib.testlib.print ("C" & tost(hndx) & " I" & tost(way) & " : " & strpad(tost(cycle), 8) & " [" &
                             tost(valid) & "] " & insn2st(pc, inst, cinst, comp) &
                             "WF[" & strpad(fpreg2st(rd), 4) & "=" & tost(wrdata) & "][" & tost(wren) & "]" &
                             " W[" & strpad(csr2str(csr), 13) & "=" & tost(wcdata) & "][" & tost(wcen) & "]" &
                             " IPC = " & tost(ipc) & " Dual = " & tost(dual) &
                             " E[cause =" & tost(vcause) & "] E[tval =" & tost(vtval) & "][" & tost(trap) & "]" &
                             " PRV[" & tost(prv) & "]");
      end if;
    end if;

  end;

  procedure print_spike_special(
    valid      : std_ulogic;
    pc         : std_logic_vector;
    csr        : std_logic_vector(11 downto 0);
    wrdata     : std_logic_vector;
    wren       : std_ulogic;
    wren_f     : std_ulogic;
    wcdata     : std_logic_vector;
    wcen       : std_ulogic;
    inst       : std_logic_vector(31 downto 0);
    cinst      : std_logic_vector(15 downto 0);
    comp       : std_ulogic;
    prv        : std_logic_vector(1 downto 0);
    trap       : std_ulogic;
    trap_taken : std_ulogic;
    cause      : std_logic_vector;
    tval       : std_logic_vector) is
    variable finst : std_logic_vector(31 downto 0);
    variable vcause : std_logic_vector(cause'range);
    variable wrdata_f : std_logic_vector(wrdata'range);
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

    if valid = '1' or wren = '1' or wren_f = '1' or wcen = '1' or (trap_taken = '1' and trap = '1') then
      if wren_f = '0' then
        grlib.testlib.print(tost(pc) & " " & tost(finst) & " " & tost(wren) & " " & tost(wrdata_f) & " " & tost(wcen) & " " & tost(wcdata) & " " & tost(prv) & " " & tost(trap) & " " & tost(vcause) & " " & tost(tval));
      else
        grlib.testlib.print(tost(pc) & " " & tost(finst) & " " & tost(wren_f) & " " & tost(wrdata_f) & " " & tost(wcen) & " " & tost(wcdata) & " " & tost(prv) & " " & tost(trap) & " " & tost(vcause) & " " & tost(tval));
      end if;
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
    rd         : std_logic_vector(4 downto 0);
    csr        : std_logic_vector(11 downto 0);
    wrdata     : std_logic_vector;
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
    --variable ipc        : real := 0.0;
    --variable dual       : real := 0.0;
    variable vcause     : std_logic_vector(cause'range);
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
    vcause      := (others => '0');
    vtval       := (others => '0');
    if trap = '1' then
      vcause    := cause;
      vtval     := tval;
    end if;

    ls := is_ld_sd(inst);

    if PRINT_ALL or valid = '1' or wren = '1' or wren_f = '1' or wcen = '1' or trap = '1' then

      -- Print Instruction
      if wren_f = '0' then
        grlib.testlib.print (
            "C" & tost(hndx)
          & " I" & tost(way)
          & " " & prv2string(prv)
          & " : " & strpad(tost(cycle), 8)
          & " [" & tost(valid) & "] "
          & insn2st(pc, inst, cinst, comp)
          --& "W[" & strpad(reg2st(rd), 3) & "=" & tost(wrdata) & "][" & tost(wren) & "]"
          & print_str((wren or ls), "[" & tost(wrdata) & "]")
          --& " W[" & strpad(csr2str(csr), 13) & "=" & tost(wcdata) & "][" & tost(wcen) & "]"
          & print_str((wcen or ls), "[" & tost(wcdata) & "]")
          --& " IPC = " & tost(ipc) & " Dual = " & tost(dual)
          --& " E[cause =" & tost(vcause) & "] E[tval =" & tost(vtval) & "][" & tost(trap) & "]"
          & print_str(trap, "[" & cause2string(vcause) & "][" & tost(vtval) & "]")
          --& " PRV[" & tost(prv) & "]"
        );
      else
        grlib.testlib.print (
            "C" & tost(hndx)
          & " I" & tost(way)
          & " " & prv2string(prv)
          & " : " & strpad(tost(cycle), 8)
          & " [" & tost(valid) & "] "
          & insn2st(pc, inst, cinst, comp)
          --& "W[" & strpad(reg2st(rd), 3) & "=" & tost(wrdata) & "][" & tost(wren) & "]"
          & print_str((wren_f or ls), "[" & tost(wrdata) & "]")
          --& " W[" & strpad(csr2str(csr), 13) & "=" & tost(wcdata) & "][" & tost(wcen) & "]"
          & print_str((wcen or ls), "[" & tost(wcdata) & "]")
          --& " IPC = " & tost(ipc) & " Dual = " & tost(dual)
          --& " E[cause =" & tost(vcause) & "] E[tval =" & tost(vtval) & "][" & tost(trap) & "]"
          & print_str(trap, "[" & cause2string(vcause) & "][" & tost(vtval) & "]")
          --& " PRV[" & tost(prv) & "]"
        );
      end if;
    end if;

  end;


end;
-- pragma translate_on
