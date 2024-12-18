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
-- Package:     alunv
-- File:        alunv.vhd
-- Description: Internal ALU for NOEL-V
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.riscv.all;
use grlib.stdlib.log2;
use grlib.stdlib.tost;
library gaisler;
use gaisler.noelvtypes.all;
use gaisler.utilnv.all;
use gaisler.nvsupport.is_enabled;
--library DWARE;
--use DWARE.DW_dp_functions.DWF_dp_count_ones;

package alunv is

  type alu_ctrl is record
    sel   : word2;         -- Operation
    ctrl  : word3;         -- Control
    ctrlx : word3;         -- Extra control
  end record;

  constant alu_ctrl_none : alu_ctrl := ((others => '0'), (others => '0'), (others => '0'));

  -- ALU Operations -----------------------------------------------------------
  -- Logic Operation
  constant EXE_AND      : word3 := "000";
  constant EXE_OR       : word3 := "001";
  constant EXE_XOR      : word3 := "010";
  constant EXE_ORCB     : word3 := "011";
  constant EXE_Z        : word3 := "100";
  constant EXE_NZ       : word3 := "101";
  constant EXE_AND01    : word3 := "110";

  -- Shift Operation
  constant EXE_SLL      : word3 := "100";
  constant EXE_SLLW     : word3 := "000";
  constant EXE_SRL      : word3 := "101";
  constant EXE_SRLW     : word3 := "001";
  constant EXE_SRA      : word3 := "111";
  constant EXE_SRAW     : word3 := "011";

  -- Math Operation
  constant EXE_ADD      : word3 := "100";
  constant EXE_ADDW     : word3 := "000";
  constant EXE_SUB      : word3 := "101";
  constant EXE_SUBW     : word3 := "001";
  constant EXE_SLTU     : word3 := "110";
  constant EXE_SLT      : word3 := "111";

  -- Misc Operation
  constant EXE_BYPASS2  : word3 := "000";
  constant EXE_GREVI    : word3 := "001";
  constant EXE_EXT      : word3 := "010";
  constant EXE_COUNT    : word3 := "011";
  constant EXE_CLMUL    : word3 := "100";
  constant EXE_PACK     : word3 := "101";
  constant EXE_SHFLI    : word3 := "110";
  constant EXE_XPERM    : word3 := "111";

  -- Execute Stage Operation Types
  constant ALU_MATH     : word2 := "00";
  constant ALU_SHIFT    : word2 := "01";
  constant ALU_LOGIC    : word2 := "10";
  constant ALU_MISC     : word2 := "11";

  constant R_CLMUL      : word3 := "001";
  constant R_CLMULR     : word3 := "010";
  constant R_CLMULH     : word3 := "011";


  procedure alu_gen(active   : extension_type;
                    inst     : word;
                    ctrl_out : out alu_ctrl);

  function alu_illegal(active  : extension_type;
                       inst_in : word) return boolean;

  procedure alu_execute(active  : extension_type;
                        op1     : wordx;
                        op2     : wordx;
                        ctrl    : alu_ctrl;
                        res_out : out wordx);

  function math_op(active : extension_type;
                   op1_in : wordx;
                   op2_in : wordx;
                   ctrl   : word3;
                   ctrlx  : word3) return wordx;
  function logic_op(active : extension_type;
                    op1_in : wordx;
                    op2_in : wordx;
                    ctrl   : word3;
                    ctrlx  : word3) return wordx;
  function misc_op(active : extension_type;
                   op1_in : wordx;
                   op2_in : wordx;
                   ctrl   : word3;
                   ctrlx  : word3) return wordx;
  function shift_op(active : extension_type;
                    op1    : wordx;
                    op2    : wordx;
                    ctrl   : word3;
                    ctrlx  : word3) return wordx;

  function reverse(op_in : std_logic_vector) return std_logic_vector;
  function clz(op_in : std_logic_vector) return unsigned;
  function pop(op_in : std_logic_vector) return unsigned;
  function clmul_div(op1 : wordx;
                     op2 : wordx;
                     n   : integer;
                     pos : integer) return std_logic_vector;
  function clmul_hdiv(op1_in : std_logic_vector;
                      op2_in : std_logic_vector;
                      n      : integer;
                      pos    : integer) return std_logic_vector;
  function clmul(op1 : wordx; op2 : wordx) return wordx;
  function clmulr(op1 : wordx; op2 : wordx) return wordx;
  function clmulh(op1 : wordx; op2 : wordx) return wordx;
  function shift64(op  : std_logic_vector(127 downto 0);
                   cnt : std_logic_vector(5 downto 0)) return word64;
  function shift32(op  : word64;
                   cnt : std_logic_vector(4 downto 0)) return word64;

end package;

package body alunv is

  -- Sign extend to 64 bit word.
  function to64(v : std_logic_vector) return word64 is
    variable v_normal : std_logic_vector(v'length - 1 downto 0) := v;
    -- Non-constant
    variable ext      : word64                                  := (others => get_hi(v_normal));
  begin
    ext(v_normal'range) := v;

    return ext;
  end;

  -- ALU record generation
  -- Selects the type of operation and the control bits for that operation.
  procedure alu_gen(active   : extension_type;
                    inst     : word;
                    ctrl_out : out alu_ctrl) is
--    variable is_rv64 : boolean      := true;
--    variable is_rv32 : boolean      := not is_rv64;
--    variable ext_zba : integer      := 1;
--    variable ext_zbb : integer      := 1;
--    variable ext_zbc : integer      := 1;
--    variable ext_zbs : integer      := 1;
    variable is_rv64      : boolean      := is_enabled(active, x_rv64);
    variable is_rv32      : boolean      := not is_rv64;
    variable ext_zba      : boolean      := is_enabled(active, x_zba);
    variable ext_zbb      : boolean      := is_enabled(active, x_zbb);
    variable ext_zbc      : boolean      := is_enabled(active, x_zbc);
    variable ext_zbs      : boolean      := is_enabled(active, x_zbs);
    variable ext_zbkb     : boolean      := is_enabled(active, x_zbkb);
    variable ext_zbkc     : boolean      := is_enabled(active, x_zbkc);
    variable ext_zbkx     : boolean      := is_enabled(active, x_zbkx);
    variable ext_zimop    : boolean      := is_enabled(active, x_zimop);
    variable ext_zicond   : boolean      := is_enabled(active, x_zicond);
    variable ext_noelvalu : boolean      := is_enabled(active, x_noelvalu);
    variable op           : opcode_type  := inst(6 downto 0);
    variable funct3       : funct3_type  := inst(14 downto 12);
    variable funct7       : funct7_type  := inst(31 downto 25);
    variable funct12      : funct12_type := inst(31 downto 20);
    -- Non-constant
    variable ctrl         : word3        := EXE_AND;     -- Default assignment
    variable ctrlx        : word3        := "000";       -- Default to no special handling
    variable sel          : word2        := ALU_LOGIC;   -- Default assignment
  begin
    -- Assuming the ALU is needed (based on the decoded fusel)
    case op is
      when LUI =>
        sel          := ALU_MISC;
        ctrl         := EXE_BYPASS2;
      when AUIPC | OP_LOAD | OP_STORE | OP_LOAD_FP | OP_STORE_FP =>
        sel          := ALU_MATH;
        ctrl         := EXE_ADD;
      when OP_IMM | OP_IMM_32 =>
        case funct3 is
          when I_ADDI =>
            sel      := ALU_MATH;
            if inst(3) = '1' then
              ctrl   := EXE_ADDW;
            else
              ctrl   := EXE_ADD;
            end if;
          when I_SLTI =>        -- Not used in case of OP_IMM_32
            sel      := ALU_MATH;
            ctrl     := EXE_SLT;
          when I_SLTIU =>       -- Not used in case of OP_IMM_32
            sel      := ALU_MATH;
            ctrl     := EXE_SLTU;
          when I_XORI =>        -- Not used in case of OP_IMM_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_XOR;
          when I_ORI =>         -- Not used in case of OP_IMM_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_OR;
          when I_ANDI =>        -- Not used in case of OP_IMM_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_AND;
          when I_SLLI =>
            sel      := ALU_SHIFT;
            if inst(3) = '1' then
              ctrl   := EXE_SLLW;
            else
              ctrl   := EXE_SLL;
            end if;
          when others =>  -- I_SRLI
            sel      := ALU_SHIFT;
            if inst(30) = '1' then -- SRAI, SRAIW
              if inst(3) = '1' then
                ctrl := EXE_SRAW;
              else
                ctrl := EXE_SRA;
              end if;
            else
              if inst(3) = '1' then
                ctrl := EXE_SRLW;
              else
                ctrl := EXE_SRL;
              end if;
            end if;
        end case;
        if ext_zba and op = OP_IMM_32 then
          case funct7 is
          when F7_ADDSLLIUW | F7_SLLIUW_I64 =>
            if funct3 = R_SLL then
              sel   := ALU_SHIFT;
              ctrl  := EXE_SLL;
              ctrlx := "001";
            end if;
          when others =>
            null;
          end case;
        end if;
        if ext_zbb or ext_zbkb then
          if funct3 = R_SRL then
            case funct12 is
              when F12_ORCB =>
                if ext_zbb and op = OP_IMM then
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_ORCB;
                end if;
              when F12_REV8_RV32 =>
                if is_rv32 and op = OP_IMM then
                  sel   := ALU_MISC;
                  ctrl  := EXE_GREVI;
                  ctrlx := "001";
                end if;
              when F12_REV8_RV64 =>
                if is_rv64 and op = OP_IMM then
                  sel   := ALU_MISC;
                  ctrl  := EXE_GREVI;
                  ctrlx := "001";
                end if;
              when F12_BREV8 =>
                if ext_zbkb and op = OP_IMM then
                  sel   := ALU_MISC;
                  ctrl  := EXE_GREVI;
                  ctrlx := "010";
                end if;
              when F12_ZIP =>
                if is_rv32 and ext_zbkb and op = OP_IMM then
                  sel   := ALU_MISC;
                  ctrl  := EXE_SHFLI;
                  ctrlx := "001";
                end if;
              when others =>
                case funct7 is
                  when F7_ROT | F7_ROR_I64 =>
                    sel    := ALU_SHIFT;
                    if inst(3) = '1' then
                      ctrl := EXE_SRLW;
                    else
                      ctrl := EXE_SRL;
                    end if;
                    ctrlx  := "010";
                  when others =>
                    null;
                end case;
            end case;
          elsif funct3 = R_SLL then
            case funct12 is
              when F12_CLZ | F12_CTZ | F12_CPOP =>
                if ext_zbb then
                  sel   := ALU_MISC;
                  ctrl  := EXE_COUNT;
                  ctrlx := inst(21 downto 20) & to_bit(op = OP_IMM_32);
                end if;
              when F12_SEXTB =>
                if ext_zbb and op = OP_IMM then
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_AND;
                  ctrlx := "101";
                end if;
              when F12_SEXTH =>
                if ext_zbb and op = OP_IMM then
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_AND;
                  ctrlx := "110";
                end if;
              when F12_ZIP =>
                if is_rv32 and ext_zbkb and op = OP_IMM then
                  sel   := ALU_MISC;
                  ctrl  := EXE_SHFLI;
                  ctrlx := "010";
                end if;
              when others =>
                null;
            end case;
          end if;
        end if;
        if ext_zbs then
          if op = OP_IMM then
            if funct3 = R_SLL then
              case funct7 is
                when F7_BCLREXT | F7_BCLREXT_I64 =>
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_AND;
                  ctrlx := "111";
                when F7_BINV    | F7_BINV_I64 =>
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_XOR;
                  ctrlx := "011";
                when F7_BSET    | F7_BSET_I64 =>
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_OR;
                  ctrlx := "011";
                when others =>
                  null;
              end case;
            elsif funct3 = R_SRL then
              case funct7 is
                when F7_BCLREXT | F7_BCLREXT_I64 =>
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_AND01;
                  ctrlx := "011";
                when others =>
                  null;
              end case;
            end if;
          end if;
        end if;
      when OP_REG | OP_32 =>
        case funct3 is
          when R_ADD =>
            sel      := ALU_MATH;
            if inst(30) = '1' then -- SUB, SUBW
              if inst(3) = '1' then
                ctrl := EXE_SUBW;
              else
                ctrl := EXE_SUB;
              end if;
            else
              if inst(3) = '1' then
                ctrl := EXE_ADDW;
              else
                ctrl := EXE_ADD;
              end if;
            end if;
          when R_SLL =>
            sel       := ALU_SHIFT;
            if inst(3) = '1' then
              ctrl   := EXE_SLLW;
            else
              ctrl   := EXE_SLL;
            end if;
          when R_SLT =>         -- Not used in case of OP_32
            sel      := ALU_MATH;
            ctrl     := EXE_SLT;
          when R_SLTU =>        -- Not used in case of OP_32
            sel      := ALU_MATH;
            ctrl     := EXE_SLTU;
          when R_XOR =>         -- Not used in case of OP_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_XOR;
            if (ext_zbb or ext_zbkb) and inst(30) = '1' then
              ctrlx  := "100";  -- Invert
            end if;
          when R_OR =>          -- Not used in case of OP_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_OR;
            if (ext_zbb or ext_zbkb) and inst(30) = '1' then
              ctrlx  := "100";  -- Invert
            end if;
          when R_AND =>         -- Not used in case of OP_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_AND;
            if (ext_zbb or ext_zbkb) and inst(30) = '1' then
              ctrlx  := "100";  -- Invert
            end if;
          when others =>  -- R_SRL
            sel      := ALU_SHIFT;
            if inst(30) = '1' then -- SRA, SRAW
              if inst(3) = '1' then
                ctrl := EXE_SRAW;
              else
                ctrl := EXE_SRA;
              end if;
            else
              if inst(3) = '1' then
                ctrl := EXE_SRLW;
              else
                ctrl := EXE_SRL;
              end if;
            end if;
        end case;
        if ext_zba then
          case funct7 is
          when F7_SHADD =>
            sel   := ALU_MATH;
            ctrl  := EXE_ADD;
            ctrlx := funct3(2 downto 1) & to_bit(op = OP_32);
          when F7_ADDSLLIUW =>
            if funct3 = R_ADD and op = OP_32 then
              sel   := ALU_MATH;
              ctrl  := EXE_ADD;
              ctrlx := "001";
            end if;
          when others =>
            null;
          end case;
        end if;
        if ext_zbb then
          if not ext_zbkb and funct12 = F12_ZEXTH and funct3 = R_XOR then
            sel   := ALU_LOGIC;
            ctrl  := EXE_AND;
            ctrlx := "010";
          elsif funct7 = F7_MINMAXCLMUL and op = OP_REG then
            case funct3 is
              when R_MIN | R_MAX =>
                sel   := ALU_MATH;
                ctrl  := EXE_SLT;
                ctrlx := "0" & funct3(2 downto 1);
              when R_MINU | R_MAXU =>
                sel   := ALU_MATH;
                ctrl  := EXE_SLTU;
                ctrlx := "0" & funct3(2 downto 1);
              when others =>
                null;
            end case;
          elsif funct7 = F7_ROT then
            -- sel and ctrl are OK from above!
            ctrlx := "010";
          end if;
        end if;
        if ext_zbkb then
          -- This will actually "override" F12_ZEXTH, since that is
          -- only a special case of F7_PACK/R_XOR.
          if funct7 = F7_PACK then
            if funct3 = R_XOR then
              sel     := ALU_MISC;
              ctrl    := EXE_PACK;
              if op = OP_REG then
                ctrlx := "001";
              else  -- OP_32
                ctrlx := "011";
              end if;
            elsif funct3 = R_AND then
              sel     := ALU_MISC;
              ctrl    := EXE_PACK;
              ctrlx  := "010";
            end if;
          end if;
        end if;
        if ext_zbc or ext_zbkc then
          if funct7 = F7_MINMAXCLMUL and op = OP_REG then
            case funct3 is
             -- R_CLMULR is not actually valid for ext_zbkc, but that does not matter here.
             when R_CLMUL | R_CLMULR | R_CLMULH =>
                sel   := ALU_MISC;
                ctrl  := EXE_CLMUL;
                ctrlx := funct3;
              when others =>
                null;
            end case;
          end if;
        end if;
        if ext_zbs then
          if op = OP_REG then
            if funct3 = R_SLL then
              case funct7 is
                when F7_BCLREXT | F7_BCLREXT_I64 =>
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_AND;
                  ctrlx := "111";
                when F7_BINV    | F7_BINV_I64 =>
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_XOR;
                  ctrlx := "011";
                when F7_BSET    | F7_BSET_I64 =>
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_OR;
                  ctrlx := "011";
                when others =>
                  null;
              end case;
            elsif funct3 = R_SRL then
              case funct7 is
                when F7_BCLREXT | F7_BCLREXT_I64 =>
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_AND01;
                  ctrlx := "011";
                when others =>
                  null;
              end case;
            end if;
          end if;
        end if;
        if ext_zbkx then
          if op = OP_REG and funct7 = F7_XPERM then
            if funct3 = R_XOR then     -- xperm8
              sel   := ALU_MISC;
              ctrl  := EXE_XPERM;
              ctrlx := "000";
            elsif funct3 = R_SLT then  -- xperm4
              sel   := ALU_MISC;
              ctrl  := EXE_XPERM;
              ctrlx := "001";
            end if;
          end if;
        end if;
        if ext_zicond then
          if op = OP_REG and funct7 = F7_CZERO then
            if funct3 = R_SRL then
              sel   := ALU_LOGIC;
              ctrl  := EXE_Z;
              ctrlx := "001";
            elsif funct3 = R_AND then
              sel   := ALU_LOGIC;
              ctrl  := EXE_NZ;
              ctrlx := "001";
            end if;
          end if;
        end if;
      when OP_SYSTEM =>
        if ext_zimop then
          -- Zimop
          sel   := ALU_LOGIC;
          ctrl  := EXE_AND;
          ctrlx := "001";
        end if;
      when OP_CUSTOM0 =>
        if ext_noelvalu and funct7 = F7_BASE_RV64 then
          case funct3 is
            when "000" =>  -- Upper 32 bits (xpacku.w)
              if is_rv64 then
                sel   := ALU_MISC;
                ctrl  := EXE_PACK;
                ctrlx := "000";
              end if;
            when "001" =>  -- Upper 8 bits (xpacku.b)
              sel     := ALU_MISC;
              ctrl    := EXE_PACK;
              if is_rv64 then
                ctrlx := "100";
              else
                ctrlx := "101";
              end if;
            when "010" =>  -- Upper 16 bits (xpacku.h)
              sel     := ALU_MISC;
              ctrl    := EXE_PACK;
              if is_rv64 then
                ctrlx := "101";
              else
                ctrlx := "000";
              end if;
            when "011" =>  -- Lower 8 bits (xpack.b)
              sel     := ALU_MISC;
              ctrl    := EXE_PACK;
              if is_rv64 then
                ctrlx := "110";
              else
                ctrlx := "111";
              end if;
            when "100" =>  -- Lower 16 bits (xpack.h)
              if is_rv64 then
                sel   := ALU_MISC;
                ctrl  := EXE_PACK;
                ctrlx := "111";
              end if;
            when others =>
              null;
          end case;
        end if;
      when others =>
    end case;

    ctrl_out.sel   := sel;
    ctrl_out.ctrl  := ctrl;
    ctrl_out.ctrlx := ctrlx;
  end;

  function alu_illegal(active   : extension_type;
                       inst_in  : word) return boolean is
--    variable is_rv64 : boolean      := true;
--    variable is_rv32 : boolean      := not is_rv64;
--    variable ext_zba : integer      := 1;
--    variable ext_zbb : integer      := 1;
--    variable ext_zbc : integer      := 1;
--    variable ext_zbs : integer      := 1;
--    variable ext_m   : integer      := 1;
    variable is_rv64      : boolean      := is_enabled(active, x_rv64);
    variable is_rv32      : boolean      := not is_rv64;
    variable ext_zba      : boolean      := is_enabled(active, x_zba);
    variable ext_zbb      : boolean      := is_enabled(active, x_zbb);
    variable ext_zbc      : boolean      := is_enabled(active, x_zbc);
    variable ext_zbs      : boolean      := is_enabled(active, x_zbs);
    variable ext_zbkb     : boolean      := is_enabled(active, x_zbkb);
    variable ext_zbkc     : boolean      := is_enabled(active, x_zbkc);
    variable ext_zbkx     : boolean      := is_enabled(active, x_zbkx);
    variable ext_zimop    : integer      := is_enabled(active, x_zimop);
    variable ext_zicond   : boolean      := is_enabled(active, x_zicond);
    variable ext_m        : boolean      := is_enabled(active, x_m);
    variable ext_noelvalu : boolean      := is_enabled(active, x_noelvalu);
    variable opcode       : opcode_type  := inst_in( 6 downto  0);
    variable funct3       : funct3_type  := inst_in(14 downto 12);
    variable funct7       : funct7_type  := inst_in(31 downto 25);
    variable funct12      : funct12_type := inst_in(31 downto 20);
    -- Non-constant
    variable illegal      : std_ulogic   := '0';
  begin
    case opcode is
      when OP_IMM =>
        case funct3 is
          when I_ADDI | I_SLTI | I_SLTIU | I_XORI | I_ORI | I_ANDI =>
            -- ADDI with rd = x0 and (rs1 /= x0 or imm /= 0) are standard HINTs.
            -- ANDI/ORI/XORI with rd = x0 are standard HINTs.
            -- SLTI/SLTIU with rd = x0 are custom HINTs.
            null;
          when I_SLLI =>
            illegal   := '1';
            case funct12 is
              when F12_CLZ | F12_CTZ | F12_CPOP | F12_SEXTB | F12_SEXTH =>
                if ext_zbb then
                  illegal := '0';
                end if;
              when F12_ZIP =>
                if is_rv32 and ext_zbkb then
                  illegal := '0';
                end if;
              when others =>
                case funct7 is
                  when F7_BCLREXT | F7_BINV | F7_BSET =>  -- BCLRI/BINVI/BSETI
                    if ext_zbs then
                      illegal := '0';
                    end if;
                  when F7_BCLREXT_I64 | F7_BINV_I64 | F7_BSET_I64 =>
                    if ext_zbs and is_rv64 then
                      illegal := '0';
                    end if;
                  when others =>
                    -- SLLI with rd = x0 are custom HINTs.
                    if funct7(6 downto 1) = "000000" then -- shamt[5:0]
                      if is_rv64 or funct7(0) = '0' then  -- >31 bit shift illegal on rv32.
                        illegal := '0';
                      end if;
                    end if;
                end case;
            end case;
          when others =>  -- I_SRLI / I_SRAI
            illegal   := '1';
            case funct12 is
              when F12_ORCB =>
                if ext_zbb then
                  illegal := '0';
                end if;
              when F12_REV8_RV32 =>
                if (ext_zbb or ext_zbkb) and is_rv32 then
                  illegal := '0';
                end if;
              when F12_REV8_RV64 =>
                if (ext_zbb or ext_zbkb) and is_rv64 then
                  illegal := '0';
                end if;
              when F12_BREV8 =>
                if ext_zbkb then
                  illegal := '0';
                end if;
              when F12_ZIP =>
                if is_rv32 and ext_zbkb then
                  illegal := '0';
                end if;
              when others =>
                case funct7 is
                  when F7_BCLREXT =>  -- BEXTI
                    if ext_zbs then
                      illegal := '0';
                    end if;
                  when F7_BCLREXT_I64 =>
                    if ext_zbs and is_rv64 then
                      illegal := '0';
                    end if;
                  when F7_ROT =>
                    if ext_zbb or ext_zbkb then
                      illegal := '0';
                    end if;
                  when F7_ROR_I64 =>
                    if (ext_zbb or ext_zbkb) and is_rv64 then
                      illegal := '0';
                    end if;
                  when others =>
                    -- SRLI/SRAI with rd = x0 are custom HINTs.
                    if funct7(6 downto 1) = "000000" or funct7(6 downto 1) = "010000" then -- shamt[5:0]
                      if is_rv64 or funct7(0) = '0' then  -- >31 bit shift illegal on rv32.
                        illegal := '0';
                      end if;
                    end if;
                end case;
            end case;
        end case;

      when OP_REG =>
        case funct7 is
          when F7_BASE =>
            -- No need to check funct3 here!
            -- ADD/AND/OR/XOR/SLL/SRL with rd = x0 are standard HINTs.
            -- SLT/SLTU with rd = x0 are custom HINTs.
          when F7_SUB =>
            case funct3 is
              when R_SUB | R_SRA => null;
                -- SUB/SRA with rd = x0 are standard HINTs.
              when R_AND | R_OR | R_XOR =>  -- ANDN/ORN/XORN
                if not ext_zbb and not ext_zbkb then
                  illegal := '1';
                end if;
              when others => illegal := '1';
            end case;
--          when F7_MUL =>
--            if ext_m then
--              case funct3 is
--                when R_MUL | R_MULH | R_MULHSU | R_MULHU |
--                     R_DIV | R_DIVU | R_REM    | R_REMU => null;
--                when others => illegal := '1';
--              end case;
--            else
--              illegal := '1';
--            end if;
          when F7_BCLREXT =>  -- BCLR/BEXT
            if ext_zbs then
              case funct3 is
                when R_SLL | R_SRL => null;
                when others => illegal := '1';
              end case;
            else
              illegal := '1';
            end if;
          when F7_BINV =>
            if ext_zbs and funct3 = R_SLL then
              null;
            else
              illegal := '1';
            end if;
          when F7_BSET =>  -- BSET/XPERM
            if ext_zbs and funct3 = R_SLL then
              null;
            elsif ext_zbkx and (funct3 = R_XOR or funct3 = R_SLT) then
              null;
            else
              illegal := '1';
            end if;
          when F7_ROT =>
            if ext_zbb or ext_zbkb then
              case funct3 is
                when R_SLL | R_SRL => null;  -- ROL/ROR
                when others => illegal := '1';
              end case;
            else
              illegal := '1';
            end if;
          when F7_SHADD =>
            if ext_zba then
              case funct3 is
                when "010" | "100" | "110" => null;  -- SH1/2/3ADD
                when others => illegal := '1';
              end case;
            else
              illegal := '1';
            end if;
          when F7_MINMAXCLMUL =>
            case funct3 is
              when "001" | "011" =>  -- CLMUL/CLMULH
                if not ext_zbc and not ext_zbkc then
                  illegal := '1';
                end if;
              when "010" =>  -- CLMULR
                if not ext_zbc then
                  illegal := '1';
                end if;
              when "100" | "101" | "110" | "111" =>  -- MIN/MINU/MAX/MAXU
                if not ext_zbb then
                  illegal := '1';
                end if;
              when others =>
                illegal := '1';
            end case;
          when F7_CZERO =>
            if ext_zicond then
              case funct3 is
                when R_SRL | R_AND => null;  -- CZERO.EQZ/NEZ
                when others => illegal := '1';
              end case;
            else
              illegal := '1';
            end if;
          when others =>
            if ext_zbb and is_rv32 and funct12 = F12_ZEXTH and funct3 = "100" then
              null;
            elsif ext_zbkb and funct7 = F7_PACK and (funct3 = R_XOR or funct3 = R_AND) then
              null;
            else
              illegal := '1';
            end if;
        end case;

      when OP_IMM_32 =>
        case funct3 is
          when I_ADDIW =>
            -- ADDIW with rd = x0 are standard HINTs.
            null;
          when I_SLLIW =>
            illegal   := '1';
            case funct12 is
              when F12_CLZ | F12_CTZ | F12_CPOP =>  -- CLZW/CTZW/CPOPW
                if ext_zbb then
                  illegal := '0';
                end if;
              when others =>
                case funct7 is
                  when F7_ADDSLLIUW | F7_SLLIUW_I64 =>
                    if ext_zba and funct3 = R_SLL then
                      illegal := '0';
                    end if;
                  when others =>
                    -- SLLIW with rd = x0 are custom HINTs.
                    if funct7 = "0000000" or funct7 = "0100000" then -- shamt[4:0]
                      illegal := '0';
                    end if;
                end case;
            end case;
          when I_SRLIW => -- I_SRAIW
            illegal   := '1';
            case funct7 is
              when F7_ROT =>  -- RORIW
                if ext_zbb or ext_zbkb then
                  illegal := '0';
                end if;
              when others =>
                -- SRLIW/SRAIW with rd = x0 are custom HINTs.
                if funct7 = "0000000" or funct7 = "0100000" then -- shamt[4:0]
                  illegal := '0';
                end if;
              end case;
          when others =>
            illegal := '1';
        end case;
        if is_rv32 then
          illegal := '1';
        end if;

      when OP_32 =>
        if ext_zbb and funct12 = F12_ZEXTH and funct3 = "100" then
          null;
        else
          case funct7 is
            when F7_BASE =>
              case funct3 is
                when R_ADDW | R_SLLW | R_SRLW => null;
                  -- ADDW/SLLW/SRLW with rd = x0 are standard HINTs.
                when others => illegal := '1';
              end case;
            when F7_SUB =>
              case funct3 is
                when R_SRAW | R_SUBW => null;
                  -- SUBW/SRAW with rd = x0 are stanadrd HINTs.
                when others => illegal := '1';
              end case;
--            when F7_MUL =>
--              if ext_m then
--                case funct3 is
--                  when R_MULW | R_DIVW | R_DIVUW | R_REMW | R_REMUW => null;
--                  when others => illegal := '1';
--                end case;
--              else
--                illegal := '1';
--              end if;
            -- This is the same as F7_PACK
            when F7_ADDSLLIUW =>  -- Note that this uses same funct7 as F12_ZEXT above!
              if ext_zba and funct3 = R_ADD then
                null;
              elsif ext_zbkb and funct3 = R_XOR then
                null;
              else
                illegal := '1';
              end if;
            when F7_ROT =>
              if ext_zbb or ext_zbkb then
                case funct3 is
                  when R_SLL | R_SRL => null;  -- ROLW/RORW
                  when others => illegal := '1';
                end case;
              else
                illegal := '1';
              end if;
            when F7_SHADD =>
              if ext_zba then
                case funct3 is
                  when "010" | "100" | "110" => null;  -- SH1/2/3ADD.UW
                  when others => illegal := '1';
                end case;
              else
                illegal := '1';
              end if;
            when others =>
              illegal := '1';
          end case;
        end if;
        if is_rv32 then
          illegal := '1';
        end if;

      when OP_CUSTOM0 =>
        if ext_noelvalu and funct7 = F7_BASE_RV64 then
          case funct3 is
            when "000" | "100"         => illegal := to_bit(is_rv32 or not ext_zbkb);
            when "001" | "010" | "011" => illegal := to_bit(not ext_zbkb);
            when others                => illegal := '1';
          end case;
        else
          illegal := '1';
        end if;

      when others =>
        illegal := '1';
    end case;

    return illegal = '1';
  end;

  -- Logic operation
  function logic_op(active : extension_type;
                    op1_in : wordx;
                    op2_in : wordx;
                    ctrl   : word3;
                    ctrlx  : word3) return wordx is
--    variable ext_zba : integer := 1;
--    variable ext_zbb : integer := 1;
--    variable ext_zbc : integer := 1;
--    variable ext_zbs : integer := 1;
    variable is_rv64    : boolean := is_enabled(active, x_rv64);
    variable is_rv32    : boolean := not is_rv64;
    variable ext_zba    : integer := is_enabled(active, x_zba);
    variable ext_zbb    : integer := is_enabled(active, x_zbb);
    variable ext_zbc    : integer := is_enabled(active, x_zbc);
    variable ext_zbs    : integer := is_enabled(active, x_zbs);
    variable ext_zbkb   : integer := is_enabled(active, x_zbkb);
    variable ext_zbkc   : integer := is_enabled(active, x_zbkc);
    variable ext_zbkx   : integer := is_enabled(active, x_zbkx);
    variable ext_zimop  : integer := is_enabled(active, x_zimop);
    variable ext_zicond : integer := is_enabled(active, x_zicond);
    variable op1      : wordx   := op1_in;
    variable op2      : wordx   := op2_in;
    -- Non-constant
    variable res      : wordx   := (others => '-');
    variable bits     : std_logic_vector(7 downto 0);
  begin
    case ctrlx is
      -- Used with EXE_OR/XOR (only 011), EXT_AND (only 111) and EXT_AND01 (only 011)
      when "111" | "011" =>  -- Bit set/clear/extract mask
        if ext_zbs = 1 then
          -- Prepare mask "backgrounds"
          op2  := (others => ctrlx(2));
          bits := (others => ctrlx(2));
          -- Set up a byte with mask for bit number modulo 8.
          bits(u2i(op2_in(2 downto 0))) := not ctrlx(2);
          -- Set the correct byte to create the full mask.
          for i in wordx'length / 8 - 1 downto 0 loop
            if (is_rv64 and u2vec(i, 3) = op2_in(5 downto 3)) or
               (is_rv32 and u2vec(i, 2) = op2_in(4 downto 3)) then
              set(op2, i * 8, bits);
            end if;
          end loop;
        end if;
      -- Used with EXE_AND
      when "110" | "010" =>  -- 16 bit sign/zero extension
        if ext_zbb = 1 then
          op1(op1'high downto 16) := (others => op1(15) and ctrlx(2));
          op2                     := (others => '1');
        end if;
      -- Used with EXE_AND
      when "101" =>          -- 8 bit sign extension
        if ext_zbb = 1 then
          op1(op1'high downto 8) := (others => op1(7));
          op2 := (others => '1');
        end if;
      -- Used with EXE_OR/XOR/AND (100 - negation)
      when "100" | "000" =>  -- Possible inversion
        if ext_zbb = 1 or ext_zbkb = 1 then
          op2 := op2 xor (wordx'range => ctrlx(2));
        end if;
      -- Used with EXE_Z/NZ and EXE_AND
      when others =>  -- "001"
        -- EXE_Z/NZ for conditional clear
        if ext_zicond = 1 and ctrl(2) = '1' then
          -- Only EXE_Z and EXE_NZ get here (ctrl(0) = 0/1).
          if all_0(op2_in) = ctrl(0) then
            op2 := (others => '1');
          else
            op2 := (others => '0');
          end if;
        -- EXE_AND for always clear
        elsif ext_zimop = 1 then
          op2 := (others => '0');
        end if;
    end case;

    case ctrl is
      when EXE_XOR                  => res := op1 xor op2;
      when EXE_OR                   => res := op1 or  op2;
      when EXE_AND | EXE_AND01 |
           EXE_Z   | EXE_NZ         => res := op1 and op2;
      when EXE_ORCB  =>
        if ext_zbb = 1 then
          res := zerox;
          for i in 0 to op1_in'length / 8 - 1 loop
            if not all_0(get(op1_in, i * 8, 8)) then
              set(res, i * 8, x"ff");
            end if;
          end loop;
        end if;
      when others    => null;  -- res := (others => '-');
    end case;

    -- BEXT?
    if ext_zbs = 1 and ctrl = EXE_AND01 then
      res := u2vec(not all_0(res), res);
    end if;

    return res;
  end;

  function reverse(op_in : std_logic_vector) return std_logic_vector is
    variable op  : std_logic_vector(op_in'length - 1 downto 0) := op_in;
    -- Non-constant
    variable res : std_logic_vector(op'range);
  begin
    for i in 0 to op'high loop
      res(i) := op(op'high - i);
    end loop;

    return res;
  end;

   function clz_orig(op_in : std_logic_vector) return unsigned is
     variable op      : std_logic_vector(op_in'length - 1 downto 0) := op_in;
--     variable cnt_top : integer := log2(op'length);
     constant cnt_top : integer := log2(op'length);
     -- Non-constant
     -- GHDL synth does not seem to like using cnt_top here. for some reason!
     variable cnt     : unsigned(log2(op'length) downto 0);
   begin
     if op'length = 1 then
       cnt(0) := not op(0);
     else
       if not all_0(hi_h(op)) then
         cnt := "0" & clz_orig(hi_h(op));
       else
         cnt := uaddx(clz_orig(lo_h(op)), u2vec(op'length / 2, cnt_top));
       end if;
     end if;

     return cnt;
   end;

  -- Simple non-recursive count-leading-zeros
  -- (A version of GHDL crashed on the recursive one.)
  function clz_simple(op_in : std_logic_vector) return unsigned is
    -- Non-constant
    variable lead : unsigned(log2(op_in'length) downto 0) := (others => '0');
  begin
    for i in op_in'left downto op_in'right loop
      if op_in(i) = '0' then
        lead := lead + 1;
      else
        exit;
      end if;
    end loop;

    return lead;
  end;



  function pop_orig(op_in : std_logic_vector) return unsigned is
    variable op : std_logic_vector(op_in'length - 1 downto 0) := op_in;
  begin
    if op'length = 1 then
      return u2vec(u2i(op(0)), 1);
    else
      return uaddx(pop_orig(hi_h(op)), pop_orig(lo_h(op)));
    end if;
  end;

  function pop_loop(op_in : std_logic_vector) return unsigned is
    variable cnt : word8 := (others => '0');
  begin
    for i in op_in'range loop
      if op_in(i) = '1' then
        cnt := uadd(cnt,  1);
      end if;
    end loop;

    return unsigned(cnt);
  end;


  function pop_arr(op_in : std_logic_vector) return unsigned is
    variable op     : word64                                := uext(op_in, 64);
    -- Non-constant
--    variable v1     : std_logic_vector(16 * 3 - 1 downto 0) := (others => '0');
--    variable v2     : std_logic_vector( 8 * 4 - 1 downto 0) := (others => '0');
--    variable v3     : std_logic_vector( 4 * 5 - 1 downto 0) := (others => '0');
--    variable v4     : std_logic_vector( 2 * 6 - 1 downto 0) := (others => '0');
    type v1_t is array (0 to 15) of std_logic_vector(2 downto 0);
    type v2_t is array (0 to  7) of std_logic_vector(3 downto 0);
    type v3_t is array (0 to  3) of std_logic_vector(4 downto 0);
    type v4_t is array (0 to  1) of std_logic_vector(5 downto 0);
    variable v1 : v1_t := (others => (others => '0'));
    variable v2 : v2_t := (others => (others => '0'));
    variable v3 : v3_t := (others => (others => '0'));
    variable v4 : v4_t := (others => (others => '0'));
    variable p2a, p2b : unsigned(3 downto 0);
    variable p3a, p3b : unsigned(4 downto 0);
    variable p4a, p4b : unsigned(5 downto 0);
    variable p5a, p5b : unsigned(6 downto 0);
    variable nybble : std_logic_vector(3 downto 0);
  begin
    for i in 0 to 15 loop
      nybble := get(op, i * 4, 4);
      case nybble is
--        when "0000"                            => set(v1, i * 3, "000");  -- Not needed
--        when "1111"                            => set(v1, i * 3, "100");
--        when "0001" | "0010" | "0100" | "1000" => set(v1, i * 3, "001");
--        when "1110" | "1101" | "1011" | "0111" => set(v1, i * 3, "011");
--        when others                            => set(v1, i * 3, "010");
--        when "0000"                            => v1 := set(v1, i * 3, "000");  -- Not needed
--        when "1111"                            => v1 := set(v1, i * 3, "100");
--        when "0001" | "0010" | "0100" | "1000" => v1 := set(v1, i * 3, "001");
--        when "1110" | "1101" | "1011" | "0111" => v1 := set(v1, i * 3, "011");
--        when others                            => v1 := set(v1, i * 3, "010");
--        when "0000"                            => v1(i * 3 + 2 downto i * 3) := "000";  -- Not needed
--        when "1111"                            => v1(i * 3 + 2 downto i * 3) := "100";
--        when "0001" | "0010" | "0100" | "1000" => v1(i * 3 + 2 downto i * 3) := "001";
--        when "1110" | "1101" | "1011" | "0111" => v1(i * 3 + 2 downto i * 3) := "011";
--        when others                            => v1(i * 3 + 2 downto i * 3) := "010";
        when "0000"                            => v1(i) := "000";  -- Not needed
        when "1111"                            => v1(i) := "100";
        when "0001" | "0010" | "0100" | "1000" => v1(i) := "001";
        when "1110" | "1101" | "1011" | "0111" => v1(i) := "011";
        when others                            => v1(i) := "010";
      end case;
    end loop;

    for i in 0 to 7 loop
--      set(v2, i * 4, uaddx(get(v1, i * 2 * 3, 3), get(v1, i * 2 * 3 + 3, 3)));
--      v2 := set(v2, i * 4, uaddx(get(v1, i * 2 * 3, 3), get(v1, i * 2 * 3 + 3, 3)));
--      v2(i * 4 + 3 downto i * 4) := uaddx(get(v1, i * 2 * 3, 3), get(v1, i * 2 * 3 + 3, 3));
      p2a := unsigned('0' & v1(i * 2));
      p2b := unsigned('0' & v1(i * 2 + 1));
--      v2(i * 4 + 3 downto i * 4) := uaddx(p2a, p2b);
--      v2(i * 4 + 3 downto i * 4) := std_logic_vector(p2a + p2b);
      v2(i) := std_logic_vector(p2a + p2b);
    end loop;

    for i in 0 to 3 loop
--      set(v3, i * 5, uaddx(get(v2, i * 2 * 4, 4), get(v2, i * 2 * 4 + 4, 4)));
--      v3 := set(v3, i * 5, uaddx(get(v2, i * 2 * 4, 4), get(v2, i * 2 * 4 + 4, 4)));
--      v3(i * 5 + 4 downto i * 5) := uaddx(get(v2, i * 2 * 4, 4), get(v2, i * 2 * 4 + 4, 4));
      p3a := unsigned('0' & v2(i * 2));
      p3b := unsigned('0' & v2(i * 2 + 1));
      v3(i) := std_logic_vector(p3a + p3b);
    end loop;

    for i in 0 to 1 loop
--      set(v4, i * 6, uaddx(get(v3, i * 2 * 5, 5), get(v3, i * 2 * 5 + 5, 5)));
--      v4 := set(v4, i * 6, uaddx(get(v3, i * 2 * 5, 5), get(v3, i * 2 * 5 + 5, 5)));
--      v4(i * 6 + 5 downto i * 6) := uaddx(get(v3, i * 2 * 5, 5), get(v3, i * 2 * 5 + 5, 5));
      p4a := unsigned('0' & v3(i * 2));
      p4b := unsigned('0' & v3(i * 2 + 1));
      v4(i) := std_logic_vector(p4a + p4b);
    end loop;

--    return uaddx(get(v4, 0, 6), get(v4, 6, 6));
    p5a := unsigned('0' & v4(0));
    p5b := unsigned('0' & v4(1));
    return p5a + p5b;
  end;

  function pop_add(op_in : std_logic_vector) return unsigned is
    variable op : word64 := uext(op_in, 64);
    variable v1, v2, v3, v4, v5, v6 : unsigned(63 downto 0);
  begin
    v1 := unsigned(op) - ('0' & unsigned(op(63 downto 1)) and x"5555555555555555");
    v2 := (v1 and x"3333333333333333") + (("00" & v1(63 downto 2)) and x"3333333333333333");
    v3 := (v2 + (("0000" & v2(63 downto 4))) and x"0F0F0F0F0F0F0F0F");
    v4 := (v3 + (x"00" & v3(63 downto 8))) and x"00FF00FF00FF00FF";
    v5 := (v4 + (x"0000" & v4(63 downto 16))) and x"0000FFFF0000FFFF";
    v6 := (v5 + (x"00000000" & v5(63 downto 32))) and x"000000000000FFFF";

    return v6(6 downto 0);
  end;

  function pop(op_in : std_logic_vector) return unsigned is
  begin
--    return DWF_dp_count_ones(op_in);
--    return pop_add(op_in);       -- 153 LUT, 38 CARRY8, lots of levels
--    return pop_arr(op_in);     -- 88 LUT, probably 7 levels
--    return pop_loop(op_in);    -- 299, lots and lots of levels
    return pop_orig(op_in);  -- 84 LUT, probably 7 levels
  end;

  function clz(op_in : std_logic_vector) return unsigned is
  begin
    return clz_orig(op_in);
--    return clz_simple(op_in);
  end;

  function clmul_div(op1 : wordx;
                     op2 : wordx;
                     n   : integer;
                     pos : integer) return std_logic_vector is
    -- Non-constant
    subtype x2wordx is std_logic_vector(wordx'length * 2 - 1 downto 0);
    variable lo  : x2wordx;
    variable hi  : x2wordx;
    variable res : x2wordx := (others => '0');
  begin
    if n = 1 then
      if op2(pos) = '1' then
        set(res, pos, op1);
      end if;
    else
      lo  := clmul_div(op1, op2, n / 2, pos);
      hi  := clmul_div(op1, op2, n / 2, pos + n / 2);
      res := lo xor hi;
    end if;

    return res;
  end;

  function clmul_hdiv(op1_in : std_logic_vector;
                      op2_in : std_logic_vector;
                      n      : integer;
                      pos    : integer) return std_logic_vector is
    -- Non-constant
    subtype res_t is std_logic_vector(op1_in'length - 1 downto 0);
    subtype op2_t is std_logic_vector(op2_in'length - 1 downto 0);
    variable op1 : res_t := op1_in;
    variable op2 : op2_t := op2_in;
    variable lo  : res_t := (others => '0');
    variable hi  : res_t := (others => '0');
    variable res : res_t := (others => '0');
  begin
    if n = 1 then
      if op2(0) = '1' then
        set(res, pos, op1(op1'length - pos - 1 downto 0));
      end if;
    else
      lo  := clmul_hdiv(op1, lo_h(op2), n / 2, pos);
      hi  := clmul_hdiv(op1, hi_h(op2), n / 2, pos + n / 2);
      res := lo xor hi;
    end if;

    return res;
  end;

--  function clmul_hdiv1(op1_in : std_logic_vector;
--                       op2_in : std_logic_vector;
--                       pos    : integer) return std_logic_vector is
--    -- Non-constant
--    subtype res_t is std_logic_vector(op1_in'length - 1 downto 0);
--    subtype op2_t is std_logic_vector(op2_in'length - 1 downto 0);
--    variable op1 : res_t := op1_in;
--    variable op2 : op2_t := op2_in;
--    variable res : res_t := (others => '0');
--  begin
--    if op2(0) = '1' then
--      set(res, pos, op1(op1'length - pos - 1 downto 0));
--    end if;
--
--    return res;
--  end;
--
--  function clmul_hdiv2(op1_in : std_logic_vector;
--                       op2_in : std_logic_vector;
--                       pos    : integer) return std_logic_vector is
--    -- Non-constant
--    subtype res_t is std_logic_vector(op1_in'length - 1 downto 0);
--    subtype op2_t is std_logic_vector(op2_in'length - 1 downto 0);
--    variable op1 : res_t := op1_in;
--    variable op2 : op2_t := op2_in;
--    variable lo  : res_t := (others => '0');
--    variable hi  : res_t := (others => '0');
--    variable res : res_t := (others => '0');
--  begin
--    lo  := clmul_hdiv1(op1, lo_h(op2), pos);
--    hi  := clmul_hdiv1(op1, hi_h(op2), pos + 1);
--    res := lo xor hi;
--
--    return res;
--  end;
--
--  function clmul_hdiv4(op1_in : std_logic_vector;
--                       op2_in : std_logic_vector;
--                       pos    : integer) return std_logic_vector is
--    -- Non-constant
--    subtype res_t is std_logic_vector(op1_in'length - 1 downto 0);
--    subtype op2_t is std_logic_vector(op2_in'length - 1 downto 0);
--    variable op1 : res_t := op1_in;
--    variable op2 : op2_t := op2_in;
--    variable lo  : res_t := (others => '0');
--    variable hi  : res_t := (others => '0');
--    variable res : res_t := (others => '0');
--  begin
--    lo  := clmul_hdiv2(op1, lo_h(op2), pos);
--    hi  := clmul_hdiv2(op1, hi_h(op2), pos + 2);
--    res := lo xor hi;
--
--    return res;
--  end;
--
--  function clmul_hdiv8(op1_in : std_logic_vector;
--                       op2_in : std_logic_vector;
--                       pos    : integer) return std_logic_vector is
--    -- Non-constant
--    subtype res_t is std_logic_vector(op1_in'length - 1 downto 0);
--    subtype op2_t is std_logic_vector(op2_in'length - 1 downto 0);
--    variable op1 : res_t := op1_in;
--    variable op2 : op2_t := op2_in;
--    variable lo  : res_t := (others => '0');
--    variable hi  : res_t := (others => '0');
--    variable res : res_t := (others => '0');
--  begin
--    lo  := clmul_hdiv4(op1, lo_h(op2), pos);
--    hi  := clmul_hdiv4(op1, hi_h(op2), pos + 4);
--    res := lo xor hi;
--
--    return res;
--  end;
--
--  function clmul_hdiv16(op1_in : std_logic_vector;
--                        op2_in : std_logic_vector;
--                        pos    : integer) return std_logic_vector is
--    -- Non-constant
--    subtype res_t is std_logic_vector(op1_in'length - 1 downto 0);
--    subtype op2_t is std_logic_vector(op2_in'length - 1 downto 0);
--    variable op1 : res_t := op1_in;
--    variable op2 : op2_t := op2_in;
--    variable lo  : res_t := (others => '0');
--    variable hi  : res_t := (others => '0');
--    variable res : res_t := (others => '0');
--  begin
--    lo  := clmul_hdiv8(op1, lo_h(op2), pos);
--    hi  := clmul_hdiv8(op1, hi_h(op2), pos + 8);
--    res := lo xor hi;
--
--    return res;
--  end;
--
--  function clmul_hdiv32(op1_in : std_logic_vector;
--                        op2_in : std_logic_vector;
--                        pos    : integer) return std_logic_vector is
--    -- Non-constant
--    subtype res_t is std_logic_vector(op1_in'length - 1 downto 0);
--    subtype op2_t is std_logic_vector(op2_in'length - 1 downto 0);
--    variable op1 : res_t := op1_in;
--    variable op2 : op2_t := op2_in;
--    variable lo  : res_t := (others => '0');
--    variable hi  : res_t := (others => '0');
--    variable res : res_t := (others => '0');
--  begin
--    lo  := clmul_hdiv16(op1, lo_h(op2), pos);
--    hi  := clmul_hdiv16(op1, hi_h(op2), pos + 16);
--    res := lo xor hi;
--
--    return res;
--  end;
--
--  function clmul_hdiv64(op1_in : std_logic_vector;
--                        op2_in : std_logic_vector;
--                        pos    : integer) return std_logic_vector is
--    -- Non-constant
--    subtype res_t is std_logic_vector(op1_in'length - 1 downto 0);
--    subtype op2_t is std_logic_vector(op2_in'length - 1 downto 0);
--    variable op1 : res_t := op1_in;
--    variable op2 : op2_t := op2_in;
--    variable lo  : res_t := (others => '0');
--    variable hi  : res_t := (others => '0');
--    variable res : res_t := (others => '0');
--  begin
--    lo  := clmul_hdiv32(op1, lo_h(op2), pos);
--    hi  := clmul_hdiv32(op1, hi_h(op2), pos + 32);
--    res := lo xor hi;
--
--    return res;
--  end;

  function clmul(op1 : wordx; op2 : wordx) return wordx is
    -- Non-constant
    subtype x2wordx is std_logic_vector(wordx'length * 2 - 1 downto 0);
    variable x2res : x2wordx := clmul_div(op1, op2, wordx'length, 0);
    variable res   : wordx   := lo_h(x2res);
    variable hres  : wordx   := clmul_hdiv(op1, op2, op1'length, 0);
  begin
--    return res;
    return hres;
  end;

  function clmulr(op1 : wordx; op2 : wordx) return wordx is
    -- Non-constant
    subtype x2wordx is std_logic_vector(wordx'length * 2 - 1 downto 0);
    variable x2res : x2wordx := clmul_div(op1, op2, wordx'length, 0);
    variable res   : wordx   := get(x2res, wordx'length - 1, wordx'length);
    variable hres  : wordx   := reverse(clmul_hdiv(reverse(op1), reverse(op2), op1'length, 0));
  begin
--    return res;
    return hres;
  end;

  function clmulh(op1 : wordx; op2 : wordx) return wordx is
    -- Non-constant
    subtype x2wordx is std_logic_vector(wordx'length * 2 - 1 downto 0);
    variable x2res : x2wordx := clmul_div(op1, op2, wordx'length, 0);
    variable res   : wordx   := hi_h(x2res);
    variable hres  : wordx   := '0' & clmulr(op1, op2)(wordx'high downto 1);
  begin
--    return res;
    return hres;
  end;

  function xperm4(data : wordx; sel : wordx; clear : wordx) return wordx is
    -- Non-constant
    variable res      : wordx           := (others => '0');
    type     w4_arr  is array (integer range <>) of word4;
    variable nybbles  : w4_arr(0 to 15) := (others => x"0");
  begin
    -- Create all possible nybbles
    for i in 0 to data'length / 4 - 1 loop
      nybbles(i) := get(data, i * 4, 4);
    end loop;
    -- Select nybbles
    for i in 0 to data'length / 4 - 1 loop
      if clear(i) = '0' then
        set(res, i * 4, nybbles(u2i(get(sel, i * 4, 4))));
      end if;
    end loop;

    return res;
  end;

  -- Misc operation
  function misc_op(active : extension_type;
                   op1_in : wordx;
                   op2_in : wordx;
                   ctrl   : word3;
                   ctrlx  : word3) return wordx is
--    variable is_rv64 : boolean  := true;
--    variable ext_zba : integer  := 1;
--    variable ext_zbb : integer  := 1;
--    variable ext_zbc : integer  := 1;
--    variable ext_zbs : integer  := 1;
    variable is_rv64      : boolean := is_enabled(active, x_rv64);
    variable is_rv32      : boolean := not is_rv64;
    variable ext_zba      : boolean := is_enabled(active, x_zba);
    variable ext_zbb      : boolean := is_enabled(active, x_zbb);
    variable ext_zbc      : boolean := is_enabled(active, x_zbc);
    variable ext_zbs      : boolean := is_enabled(active, x_zbs);
    variable ext_zbkb     : boolean := is_enabled(active, x_zbkb);
    variable ext_zbkc     : boolean := is_enabled(active, x_zbkc);
    variable ext_zbkx     : boolean := is_enabled(active, x_zbkx);
    variable ext_noelvalu : boolean := is_enabled(active, x_noelvalu);
    -- Non-constant
    subtype  x2wordx is std_logic_vector(wordx'length * 2 - 1 downto 0);
    subtype  hwordx  is std_logic_vector(wordx'length / 2 - 1 downto 0);
--    variable x2res        : x2wordx := clmul_div(op1_in, op2_in, wordx'length, 0);
    variable hop1         : hwordx;
    variable op1r         : wordx   := op1_in;
    variable op2r         : wordx   := op2_in;
    variable res          : wordx   := (others => '-');  -- Default to whatever
  begin
    if (ext_zbb and ctrl = EXE_COUNT and ctrlx(2 downto 1) = "01") or  -- CTZ?
       ((ext_zbc or ext_zbkc) and
        ctrl = EXE_CLMUL and ctrlx /= R_CLMUL) then                        -- Reverse clmul?
      op1r := reverse(op1_in);
      op2r := reverse(op2_in);  -- Irrelevant for CTZ
    end if;

    case ctrl is
      when EXE_BYPASS2 =>
        res := op2_in;
      when EXE_GREVI =>
        if (ext_zbb or ext_zbkb) and ctrlx = "001" then
          for i in 0 to op1_in'length / 8 - 1 loop
            set(res, (op1_in'length / 8 - 1 - i) * 8, get(op1_in, i * 8, 8));
          end loop;
        elsif ext_zbkb and ctrlx = "010" then
          for i in 0 to op1_in'length / 8 - 1 loop
            set(res, i * 8, reverse(get(op1_in, i * 8, 8)));
          end loop;
        end if;
      when EXE_PACK =>
        if ext_zbkb then
          case ctrlx is
          when "001" =>      -- ba 21 ->
              res := lo_h(op2_in) & lo_h(op1_in);
          when "011" =>
            if is_rv64 then
              res := sext(get(op2_in, 0, 16) & get(op1_in, 0, 16), res);
            end if;
          when "010" =>
            res := uext(get(op2_in, 0,  8) & get(op1_in, 0,  8), res);
          when others =>
            if ext_noelvalu then
              case ctrlx is
              when "000" =>  -- ba 21 ->
                res := hi_h(op2_in) & hi_h(op1_in);
              when "100" =>  -- hgfedcba 87654321 ->
                if is_rv64 then
                  res := hi_h(hi_h(hi_h(op2_in))) & hi_h(hi_h(hi_h(op1_in))) &
                         hi_h(lo_h(hi_h(op2_in))) & hi_h(lo_h(hi_h(op1_in))) &
                         hi_h(hi_h(lo_h(op2_in))) & hi_h(hi_h(lo_h(op1_in))) &
                         hi_h(lo_h(lo_h(op2_in))) & hi_h(lo_h(lo_h(op1_in)));
                end if;
              when "101" =>  -- dcba 4321 ->
                res := hi_h(hi_h(op2_in)) & hi_h(hi_h(op1_in)) &
                       hi_h(lo_h(op2_in)) & hi_h(lo_h(op1_in));
              when "110" =>  -- hgfedcba 87654321 ->
                if is_rv64 then
                  res := lo_h(hi_h(hi_h(op2_in))) & lo_h(hi_h(hi_h(op1_in))) &
                         lo_h(lo_h(hi_h(op2_in))) & lo_h(lo_h(hi_h(op1_in))) &
                         lo_h(hi_h(lo_h(op2_in))) & lo_h(hi_h(lo_h(op1_in))) &
                         lo_h(lo_h(lo_h(op2_in))) & lo_h(lo_h(lo_h(op1_in)));
                end if;
              when "111" =>  -- dcba 4321 ->
                res := lo_h(hi_h(op2_in)) & lo_h(hi_h(op1_in)) &
                       lo_h(lo_h(op2_in)) & lo_h(lo_h(op1_in));
              when others =>
              end case;
            end if;
          end case;
        end if;
      when EXE_SHFLI =>
        if is_rv32 and ext_zbkb then
          if ctrlx = "001" then
            for i in 0 to op1_in'high loop
              if i mod 2 = 0 then
                res(i / 2) := op1_in(i);
              else
                res(res'length / 2 + i / 2) := op1_in(i);
              end if;
            end loop;
          else
            for i in 0 to op1_in'high loop
              if i mod 2 = 0 then
                res(i) := op1_in(i / 2);
              else
                res(i) := op1_in(op1_in'length / 2 + i / 2);
              end if;
            end loop;
          end if;
        end if;
      when EXE_XPERM =>
        if ext_zbkx then
          op1r := (others => '0');
          -- xperm8?
          if ctrlx(0) = '0' then
            for i in 0 to op2_in'length / 8 - 1 loop
              -- Split byte chunk into its two nybble parts.
              set(op2r, i * 8,     get(op2_in, i * 8, 3) & '0');
              set(op2r, i * 8 + 4, get(op2_in, i * 8, 3) & '1');
              -- Zero output if index too high.
              if not all_0(get(op2_in, i * 8 + 3, 5)) then
                set(op1r, i * 2, "11");
              end if;
            end loop;
          end if;
          if is_rv32 then
            for i in 0 to op2_in'length / 4 - 1 loop
              -- Zero output if index too high.
              if op2r(i * 4 + 3) = '1' then
                op1r(i) := '1';
              end if;
            end loop;
          end if;
          res := xperm4(op1_in, op2r, op1r);
        end if;
      when EXE_COUNT =>
        if ext_zbb then
          -- xxxW?
          if is_rv64 and ctrlx(0) = '1' then
            -- Flip words if not CTZ.
            if ctrlx(2 downto 1) /= "01" then
              set_hi(op1r, lo_h(op1r));
            end if;
            -- 1's at the bottom, except for CPOP.
            if ctrlx(2 downto 1) = "10" then
              op1r(word'range) := (others => '0');
            else
              op1r(word'range) := (others => '1');
            end if;
          end if;
          case ctrlx(2 downto 1) is
            when "10"   => res := uext(pop(op1r), res);
            when others => res := uext(clz(op1r), res);
          end case;
        end if;
      when EXE_CLMUL =>
        if ext_zbc or ext_zbkc then
          res := clmul_hdiv(op1r, op2r, op1r'length, 0);
--          res := clmul_hdiv64(op1r, op2r, 0);
          case ctrlx is
            when R_CLMUL  => null;
            when R_CLMULH => res := '0' & reverse(res)(res'high downto 1);
            when others   =>
              if ext_zbc then
                res := reverse(res);
              end if;
          end case;
        end if;
      when others =>
        null;
    end case;

    return res;
  end;

  -- Math operation
  -- ctrl(2)   -> size
  -- ctrl(1:0) -> op
  -- ctrl(0)   -> sgn for SLT and SLTU
  function math_op(active : extension_type;
                   op1_in : wordx;
                   op2_in : wordx;
                   ctrl   : word3;
                   ctrlx  : word3) return wordx is
    variable is_rv64  : boolean := is_enabled(active, x_rv64);
    variable ext_zba  : boolean := is_enabled(active, x_zba);
    variable ext_zbb  : boolean := is_enabled(active, x_zbb);
    variable ext_zbc  : boolean := is_enabled(active, x_zbc);
    variable ext_zbs  : boolean := is_enabled(active, x_zbs);
    variable ext_zbkb : boolean := is_enabled(active, x_zbkb);
    variable ext_zbkc : boolean := is_enabled(active, x_zbkc);
    variable ext_zbkx : boolean := is_enabled(active, x_zbkx);
    -- Non-constant
    variable op1      : wordx1;  -- Manipulated from _in for efficiency.
    variable op2      : wordx1;
    subtype  wordx2  is std_logic_vector(wordx'high + 2 downto 0);
    variable add_res  : wordx2;
    variable less     : std_ulogic;
    variable res      : wordx   := (others => '0');
    variable tmp      : wordx;
  begin
    -- Select Operands
    op1 := op1_in & '1';
    op2 := op2_in & '0';

    if ext_zba and ctrl = EXE_ADD then
      if ctrlx(0) = '1' then
        op1 := uext(op1_in(word'range), op1_in) & '1';
      end if;
      -- SHnADD?
      case ctrlx(2 downto 1) is
        when "11"   => op1 := op1(op1'high - 3 downto 1) & "0001";
        when "10"   => op1 := op1(op1'high - 2 downto 1) & "001";
        when "01"   => op1 := op1(op1'high - 1 downto 1) & "01";
        when others => null;
      end case;
    end if;

    case ctrl is
      when EXE_SUB | EXE_SUBW | EXE_SLT | EXE_SLTU =>
        op2 := (op2_in xor (not zerox)) & '1';
      when others => -- EXE_ADD
    end case;

    -- Compute Results
    add_res := uaddx(op1, op2);   -- Carry fixed at 1
    -- Unsigned - less if borrow
    if ctrl = EXE_SLTU then
      less := not get_hi(add_res);
    -- Signed and different signs
    elsif get_hi(op1) /= get_hi(op2_in) then
      less := get_hi(op1);
    else
      less := add_res(add_res'high - 1);
    end if;

    case ctrl(1 downto 0) is
      when "00" | "01" => res := get(add_res, 1, res'length);  -- EXE_ADD | EXE_SUB
      when others      => res := u2vec(u2i(less), res);        -- EXE_SLT | EXE_SLTU
    end case;

    -- MIN/MAX?
    if ext_zbb and (ctrl = EXE_SLT or ctrl = EXE_SLTU) and ctrlx(1) = '1' then
      if (ctrlx(0) xor less) = '1' then
        res := op1_in;
      else
        res := op2_in;
      end if;
    end if;

    -- addw/subw?
    if is_rv64 and ctrl(2) = '0' then
      tmp              := res;
      res              := (others => res(31));
      res(31 downto 0) := tmp(31 downto 0);
    end if;

    return res;
  end;

  -- 64-bit shift operation
  function shift64(op  : std_logic_vector(127 downto 0);
                   cnt : std_logic_vector(5 downto 0)) return word64 is
    -- Non-constant
    variable shiftin : std_logic_vector(127 downto 0) := op;
  begin
--    case cnt(5 downto 4) is
--      when "00"   =>
--      when "01"   => shiftin(79 downto 0) := shiftin( 95 downto 16);
--      when "10"   => shiftin(79 downto 0) := shiftin(111 downto 32);
--      when others => shiftin(79 downto 0) := shiftin(127 downto 48);
--    end case;
--    case cnt(3 downto 2) is
--      when "00"   =>
--      when "01"   => shiftin(67 downto 0) := shiftin( 71 downto  4);
--      when "10"   => shiftin(67 downto 0) := shiftin( 75 downto  8);
--      when others => shiftin(67 downto 0) := shiftin( 79 downto 12);
--    end case;
--    case cnt(1 downto 0) is
--      when "00"   =>
--      when "01"   => shiftin(64 downto 0) := shiftin( 65 downto  1);
--      when "10"   => shiftin(64 downto 0) := shiftin( 66 downto  2);
--      when others => shiftin(64 downto 0) := shiftin( 67 downto  3);
--    end case;
--    if cnt(5) = '1' then shiftin(95 downto 0) := shiftin(127 downto 32); end if;
--    if cnt(4) = '1' then shiftin(79 downto 0) := shiftin( 95 downto 16); end if;
--    if cnt(3) = '1' then shiftin(71 downto 0) := shiftin( 79 downto  8); end if;
--    if cnt(2) = '1' then shiftin(67 downto 0) := shiftin( 71 downto  4); end if;
--    if cnt(1) = '1' then shiftin(65 downto 0) := shiftin( 67 downto  2); end if;
--    if cnt(0) = '1' then shiftin(63 downto 0) := shiftin( 64 downto  1); end if;
    -- This is the only implementation that DC recognizes as a shifter.
    -- Actually more logic than one of the above, but implementation might be better.
    shiftin := std_logic_vector(shift_right(unsigned(shiftin), u2i(cnt)));
--    for i in 0 to 63 loop
--      shiftin(i) := shiftin(i + u2i(cnt));
--    end loop;

    return shiftin(63 downto 0);
  end;

  -- 32-bit shift operation
  function shift32(op  : word64;
                   cnt : std_logic_vector(4 downto 0)) return word64 is
    -- Non-constant
    variable shiftin : word64 := op;
    variable pad     : word;
  begin
--    if cnt(4) = '1' then shiftin(47 downto 0) := shiftin(63 downto 16); end if;
--    if cnt(3) = '1' then shiftin(39 downto 0) := shiftin(47 downto  8); end if;
--    if cnt(2) = '1' then shiftin(35 downto 0) := shiftin(39 downto  4); end if;
--    if cnt(1) = '1' then shiftin(33 downto 0) := shiftin(35 downto  2); end if;
--    if cnt(0) = '1' then shiftin(31 downto 0) := shiftin(32 downto  1); end if;
    -- This is the only implementation that DC recognizes as a shifter.
    -- Actually more logic than the above, but implementation might be better.
    shiftin := std_logic_vector(shift_right(unsigned(shiftin), u2i(cnt)));
--    for i in 0 to 31 loop
--      shiftin(i) := shiftin(i + u2i(cnt));
--    end loop;

    pad                   := (others => shiftin(31));
    shiftin(63 downto 32) := pad;

    return shiftin;
  end;

  -- Shift operation
  -- ctrl(2) -> size
  -- ctrl(1) -> arithmetic
  -- ctrl(0) -> direction
  function shift_op(active : extension_type;
                    op1    : wordx;
                    op2    : wordx;
                    ctrl   : word3;
                    ctrlx  : word3) return wordx is
--    variable is_rv64 : boolean := true;
--    variable ext_zba : integer := 1;
--    variable ext_zbb : integer := 1;
--    variable ext_zbc : integer := 1;
--    variable ext_zbs : integer := 1;
    variable is_rv64   : boolean := is_enabled(active, x_rv64);
    variable ext_zba   : boolean := is_enabled(active, x_zba);
    variable ext_zbb   : boolean := is_enabled(active, x_zbb);
    variable ext_zbc   : boolean := is_enabled(active, x_zbc);
    variable ext_zbs   : boolean := is_enabled(active, x_zbs);
    variable ext_zbkb  : boolean := is_enabled(active, x_zbkb);
    variable ext_zbkc  : boolean := is_enabled(active, x_zbkc);
    variable ext_zbkx  : boolean := is_enabled(active, x_zbkx);
    -- Non-constant
    variable shiftin64 : std_logic_vector(127 downto 0) := (others => '0');
    variable shiftin32 : word64                         := (others => '0');
    variable cnt       : std_logic_vector(  5 downto 0) := op2(5 downto 0);
    variable res32     : word64;
    variable res64     : word64;
  begin
    -- SLLI.UW?
    if is_rv64 and ext_zba and ctrlx = "001" then
      set(shiftin64, 64 - 1, op1(word'range));
      -- Always left
      cnt := not op2(5 downto 0);  -- Preshifted above for negation!
    -- Rotate?
    elsif (ext_zbb or ext_zbkb) and ctrlx = "010" then
      shiftin32     := op1(word'range) & op1(word'range);
      if is_rv64 then
        shiftin64   := to64(op1) & to64(op1);
      end if;
      -- Left?
      if ctrl(1 downto 0) = "00" then
        shiftin32 := shiftin32(0) & shiftin32(shiftin32'high downto 1);
        shiftin64 := shiftin64(0) & shiftin64(shiftin64'high downto 1);
        cnt := not op2(5 downto 0);  -- Preshifted above for negation!
      end if;
    -- Normal shift
    else
      case ctrl(1 downto 0) is
        when "00" => -- SLL
          shiftin32   := (others => '0');
          set(shiftin32, 32 - 1, op1(word'range));
          if is_rv64 then
            set(shiftin64, 64 - 1, op1);
          end if;
          cnt         := not op2(5 downto 0);  -- Preshifted above for negation!
        when "11" => -- SRA
          shiftin32     := sext(op1(word'range), shiftin32);
          if is_rv64 then
            shiftin64   := sext(op1, shiftin64);
          end if;
        when others => -- SRL
          shiftin32     := uext(op1(word'range), shiftin32);
          if is_rv64 then
            shiftin64   := uext(op1, shiftin64);
          end if;
      end case;
    end if;

    if is_rv64 and ctrl(2) = '0' then
      shiftin64 := shiftin32 & shiftin32;
      cnt(5)    := '0';
    end if;

    res32 := shift32(shiftin32, cnt(4 downto 0));
    res64 := shift64(shiftin64, cnt);

    if is_rv64 then
      if ctrl(2) = '1' then
        return res64(wordx'range);
      else
        return sext(res64(word'range), wordx'length);
      end if;
    else
      return res32(wordx'range);
    end if;
  end;

  -- ALU Execute
  procedure alu_execute(active  : extension_type;
                        op1     : wordx;
                        op2     : wordx;
                        ctrl    : alu_ctrl;
                        res_out : out wordx) is
    variable alu_math_res  : wordx := math_op( active, op1, op2, ctrl.ctrl, ctrl.ctrlx);
    variable alu_shift_res : wordx := shift_op(active, op1, op2, ctrl.ctrl, ctrl.ctrlx);
    variable alu_logic_res : wordx := logic_op(active, op1, op2, ctrl.ctrl, ctrl.ctrlx);
    variable alu_misc_res  : wordx := misc_op( active, op1, op2, ctrl.ctrl, ctrl.ctrlx);
    -- Non-constant
    variable res           : wordx := zerox;
  begin
    case ctrl.sel is
      when ALU_MATH     => res := alu_math_res;
      when ALU_SHIFT    => res := alu_shift_res;
      when ALU_LOGIC    => res := alu_logic_res;
      when others       => res := alu_misc_res;
    end case;

    res_out     := res;
  end;

end package body;
