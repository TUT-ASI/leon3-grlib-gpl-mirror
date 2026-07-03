------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
library gaisler;
use gaisler.noelv.all;
use gaisler.noelvtypes.all;
use gaisler.utilnv.all;
use gaisler.nvsupport.is_enabled;
--library DWARE;
--use DWARE.DW_dp_functions.DWF_dp_count_ones;

package alunv is

  subtype  noelvalu_t  is word32;
  constant noelvalu_all : noelvalu_t := (others => '1');

  -- Indices for noelvalu_t bits
  -- Standard RISC-V options
  constant alu_clz      : integer := 0;
  constant alu_pop      : integer := 1;

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
  constant EXE_MISC     : word3 := "111";
  -- ctrlx 111     - create mask with single bit as ctrlx(2) (EXE_AND, BEXT)
  --       011     -                                         (EXE_OR/XOR, BSET/BCLR)
  --       110 010 - 16 bit sign/zero extension, op1(15) and ctrlx(2) (EXE_AND)
  --       101     - 8 bit sign extension, op1(7) (EXE_AND)
  --       100 000 - possibly invert op2 (xor with ctrlx(2)) (EXE_OR/XOR/AND)
  --       001     - ctrl(2) 0 - clear op2 (EXE_AND, Zimop)
  --                         1 - op2 all (op2_in == 0) = ctrl(0) (EXE_Z/NZ, Zicond)
  -- EXE_AND/OR/XOR/ORCB do the obvious operations
  -- EXE_AND01/Z/NZ do AND operation
  -- EXE_AND01 (BEXT) sets result according to all_0(res)
  -- EXE_ORCB
  --   ctrlx 000 - standard OR-combine per byte
  --   ctrlx 001 - OR-combine per nybble
  -- EXE_MISC
  --   ctrlx 000 - pick bits from half as for XPERM8 (RV64 only)
  --   ctrlx 001 - pick bits from half as for XPERM4 (RV32 only)

  -- Shift Operation
  constant EXE_SLL      : word3 := "100";
  constant EXE_SLLW     : word3 := "000";
  constant EXE_SRL      : word3 := "101";  -- Also used for RORMIXI
  constant EXE_SRLW     : word3 := "001";
  constant EXE_SRA      : word3 := "111";
  constant EXE_SRAW     : word3 := "011";
  constant EXE_COMPEXP  : word3 := "010";
  constant EXE_ALIGN    : word3 := "110";  -- Turned into SLL/SLR later
  -- ctrlx 001 - prepare low word for left shift (SLLI.UW)
  --       010 - copy op1 top and bottom (ROT)
  --       011 - prepare for rotation and mix (RORMIXI)
  --       else  prepare for normal shifts (see above)
  -- ctrl(1:0) - 00 Negative shift (SLL[W] and corresponding rotation)
  -- ctrl(2)   - 0  W (except for COMPEXP, but does not matter there)

  -- Math Operation
  constant EXE_ADD      : word3 := "100";
  constant EXE_ADDW     : word3 := "000";
  constant EXE_SUB      : word3 := "101";
  constant EXE_SUBW     : word3 := "001";
  constant EXE_SLTU     : word3 := "110";
  constant EXE_SLT      : word3 := "111";
  constant EXE_CMPNU    : word3 := "010";
  constant EXE_CMPN     : word3 := "011";
  -- ADD*
  --   ctrlx(0)   - unsigned 32 bit
  --   ctrlx(2:1) - SHnADD <<n
  -- SUB*/SLT*
  --   invert + 1 (do subtract)
  -- SLTU
  --   less if borrow
  --  otherwise
  --   less if op1 negative and op2 not
  --   or if result negative
  -- CMPN*
  --   ctrl(0)    - signed
  --   ctrlx(2)   - 0/1 8/16 bit
  --   less (per lane) if actually smaller (unsigned expanded to signed)
  -- ADD*/SUB* (W - RV64)
  --   ctrl(2)    - sign extended 32 bit result
  -- SLT*/CMPN*
  --   ctrlx(1)   - actually MIN/MAX
  --   ctrlx(0)   - 0/1 MIN/MAX (qqq or the other way around?)

  -- Misc Operation
  constant EXE_BYPASS2  : word3 := "000";
  constant EXE_GREVI    : word3 := "001";
  constant EXE_MIX      : word3 := "010";
  constant EXE_COUNT    : word3 := "011";
  constant EXE_CLMUL    : word3 := "100";
  constant EXE_PACK     : word3 := "101";
  constant EXE_SHFLI    : word3 := "110";  -- Not only actual SHFLI
  constant EXE_XPERM    : word3 := "111";
  -- (EXE_COUNT and ctrlx(2:1) = 01 (CTZ)) or (EXE_CLMUL and ctrlx /= R_CLMUL)
  --   reverse both operands (to op1r)
  -- EXE_GREVI ctrlx 001 - byte reverse
  --                 010 - bit reverse bytes
  -- EXE_PACK  ctrlx 001 - ba,21 -> 1a                   (PACK)
  --                 011 - xxba,yy21 -> 001a             (PACKW)
  --                 010 - xxxxxxxa,yyyyyyy1 -> 0000001a (PACKH)
  --                 000 - ba 21 -> 2b                   (opposite of 001)
  --                 100 - hgfedcba 87654321 -> 8h6f4d2b (opposite of 110)
  --                 101 - dcba 4321 -> 4d2b             (opposite of 111)
  --                 110 - hgfedcba 87654321 -> 7g5e3c1a (extension of 010)
  --                 111 - dcba 4321 -> 3c1a             (extension of 011)
  -- EXE_SHFLI ctrlx 000 - pick byte sign bits into LSBs (S2MASK.B)
  --                 001 - pick half sign bits into LSBs (S2MASK.H)
  --                 010 - bit deinterleave              (UNZIP)
  --                 011 - bit interleave                (ZIP)
  --                 100 - byte mask splat               (SPLAT.B)
  --                 101 - half mask splat               (SPLAT.H)
  -- EXE_PERM ctrlx(0) 0 - update permutation nybbles for byte operation (XPERM8 vs 4)
  -- EXE_COUNT ctrlx __x - 1 W, move bottom word to top unless CTZ, bottom as 1's unless CPOP
  --                 00x - CLZ
  --                 01x - CTZ
  --                 10x - CPOP
  --                 11x - unused (interpreted as CLZ)

  -- Execute Stage Operation Types
  constant ALU_MATH     : word2 := "00";
  constant ALU_SHIFT    : word2 := "01";
  constant ALU_LOGIC    : word2 := "10";
  constant ALU_MISC     : word2 := "11";

  constant R_CLMUL      : word3 := "001";
  constant R_CLMULR     : word3 := "010";
  constant R_CLMULH     : word3 := "011";


  procedure alu_gen(active   : extension_type;
                    options  : noelvalu_t;
                    inst     : word;
                    ctrl_out : out alu_ctrl);


  function alu_illegal(active  : extension_type;
                       options : noelvalu_t;
                       inst_in : word) return boolean;

  procedure alu_execute(active  : extension_type;
                        options : noelvalu_t;
                        op1     : wordx;
                        op2     : wordx;
                        ctrl    : alu_ctrl;
                        inst    : word32;
                        res_out : out wordx);

  function math_op(active  : extension_type;
                   options : noelvalu_t;
                   op1_in  : wordx;
                   op2_in  : wordx;
                   ctrl_in : word3;
                   ctrlx   : word3;
                   inst    : word32) return wordx;
  function logic_op(active  : extension_type;
                    options : noelvalu_t;
                    op1_in  : wordx;
                    op2_in  : wordx;
                    ctrl    : word3;
                    ctrlx   : word3) return wordx;
  function misc_op(active  : extension_type;
                   options : noelvalu_t;
                   op1_in  : wordx;
                   op2_in  : wordx;
                   ctrl    : word3;
                   ctrlx   : word3;
                   inst    : word32
                  ) return wordx;
  function shift_op(active   : extension_type;
                    options  : noelvalu_t;
                    op1      : wordx;
                    op2      : wordx;
                    ctrl_in  : word3;
                    ctrlx_in : word3;
                    inst     : word32) return wordx;

  function pop(op_in : std_logic_vector; split : std_logic) return unsigned;
  function pop(op_in : std_logic_vector) return unsigned;
  function clmul_hdiv(op1_in : std_logic_vector;
                      op2_in : std_logic_vector;
                      n      : integer;
                      pos    : integer) return std_logic_vector;
  function shift64(op  : std_logic_vector(127 downto 0);
                   cnt : std_logic_vector(5 downto 0)) return word64;
  function shift32(op  : word64;
                   cnt : std_logic_vector(4 downto 0)) return word64;

end package;

package body alunv is

  -- NOEL-V ALU default enables
  -- Also enables for some standard RISC-V extensions.
  -- These are combined with provided options, so that
  -- enables here can be overridden on calls, but
  -- disables here cannot be overriden.
  -- See noelvalu_t and alu_* above.

  -- These two are mainly for testing, but could be
  -- used to lower the complexity of some ALUs.
  -- Note that they do not remove the instructions, only the implementation (alu_execute).
  constant enable_clz       : boolean := true;   -- misc (count leading/trailing zeros)
  constant enable_pop       : boolean := true;   -- misc (population count)


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
                    options  : noelvalu_t;
                    inst     : word;
                    ctrl_out : out alu_ctrl) is
    variable is_rv64      : boolean := is_enabled(active, x_rv64);
    variable is_rv32      : boolean := not is_rv64;
    variable ext_zba      : boolean := is_enabled(active, x_zba);
    variable ext_zbb      : boolean := is_enabled(active, x_zbb);
    variable ext_zbc      : boolean := is_enabled(active, x_zbc);
    variable ext_zbs      : boolean := is_enabled(active, x_zbs);
    variable ext_zbkb     : boolean := is_enabled(active, x_zbkb);
    variable ext_zbkc     : boolean := is_enabled(active, x_zbkc);
    variable ext_zbkx     : boolean := is_enabled(active, x_zbkx);
    variable ext_zimop    : boolean := is_enabled(active, x_zimop);
    variable ext_zicond   : boolean := is_enabled(active, x_zicond);
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
                  ctrlx := "010";
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
                  ctrlx := "011";
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
      when others =>
    end case;

    ctrl_out.sel   := sel;
    ctrl_out.ctrl  := ctrl;
    ctrl_out.ctrlx := ctrlx;
  end;


  function alu_illegal(active  : extension_type;
                       options : noelvalu_t;
                       inst_in : word) return boolean is
    variable is_rv64      : boolean := is_enabled(active, x_rv64);
    variable is_rv32      : boolean := not is_rv64;
    variable ext_zba      : boolean := is_enabled(active, x_zba);
    variable ext_zbb      : boolean := is_enabled(active, x_zbb);
    variable ext_zbc      : boolean := is_enabled(active, x_zbc);
    variable ext_zbs      : boolean := is_enabled(active, x_zbs);
    variable ext_zbkb     : boolean := is_enabled(active, x_zbkb);
    variable ext_zbkc     : boolean := is_enabled(active, x_zbkc);
    variable ext_zbkx     : boolean := is_enabled(active, x_zbkx);
    variable ext_zicond   : boolean := is_enabled(active, x_zicond);
    variable ext_m        : boolean := is_enabled(active, x_m);
    variable opcode       : opcode_type  := inst_in( 6 downto  0);
    variable rfa2         : reg_t        := rs2(inst_in);
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
                    if ext_zba then
                      illegal := '0';
                    end if;
                  when others =>
                    -- SLLIW with rd = x0 are custom HINTs.
                    if funct7 = "0000000" then -- shamt[4:0]
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


      when others =>
        illegal := '1';
    end case;

    return illegal = '1';
  end;


  -- Logic operation
  function logic_op(active  : extension_type;
                    options : noelvalu_t;
                    op1_in  : wordx;
                    op2_in  : wordx;
                    ctrl    : word3;
                    ctrlx   : word3) return wordx is
    variable is_rv64      : boolean := is_enabled(active, x_rv64);
    variable is_rv32      : boolean := not is_rv64;
    variable ext_zbb      : boolean := is_enabled(active, x_zbb);
    variable ext_zbs      : boolean := is_enabled(active, x_zbs);
    variable ext_zbkb     : boolean := is_enabled(active, x_zbkb);
    variable ext_zimop    : boolean := is_enabled(active, x_zimop);
    variable ext_zicond   : boolean := is_enabled(active, x_zicond);
    variable op1          : wordx   := op1_in;
    variable op2          : wordx   := op2_in;
    -- Non-constant
    variable res          : wordx   := (others => '-');
    variable bits         : word8;
    variable index        : word8;
  begin
    case ctrlx is
      -- Used with EXE_OR/XOR (only 011), EXT_AND (only 111) and EXT_AND01 (only 011)
      when "111" | "011" =>  -- Bit set/clear/extract mask
        if ext_zbs then
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
        if ext_zbb then
          op1(op1'high downto 16) := (others => op1(15) and ctrlx(2));
          op2                     := (others => '1');
        end if;
      -- Used with EXE_AND
      when "101" =>          -- 8 bit sign extension
        if ext_zbb then
          op1(op1'high downto 8) := (others => op1(7));
          op2 := (others => '1');
        end if;
      -- Used with EXE_OR/XOR/AND (100 - negation)
      when "100" | "000" =>  -- Possible inversion
        if ext_zbb or ext_zbkb then
          op2 := op2 xor (wordx'range => ctrlx(2));
        end if;
      -- Used with EXE_Z/NZ and EXE_AND
      when others =>  -- "001"
        -- EXE_Z/NZ for conditional clear
        if ext_zicond and ctrl(2) = '1' then
          -- Only EXE_Z and EXE_NZ get here (ctrl(0) = 0/1).
          if all_0(op2_in) = ctrl(0) then
            op2 := (others => '1');
          else
            op2 := (others => '0');
          end if;
        -- EXE_AND for always clear
        elsif ext_zimop then
          op2 := (others => '0');
        end if;
    end case;

    case ctrl is
      when EXE_XOR =>
        res := op1 xor op2;
      when EXE_OR  =>
        res := op1 or  op2;
      when EXE_AND | EXE_AND01 |
           EXE_Z   | EXE_NZ =>
        res := op1 and op2;
        -- BEXT?
        if ext_zbs and ctrl = EXE_AND01 then
          res := u2vec(not all_0(res), res);
        end if;
      when EXE_ORCB  =>
        if ext_zbb then
          res                  := zerox;
          for i in 0 to op1_in'length / 8 - 1 loop
            bits := get(op1_in, i * 8, 8);
            index(0)           := not all_0(lo_h(bits));
            index(1)           := not all_0(hi_h(bits));
            bits               := (others => index(0) or index(1));  -- Assume or.b (8 bit)
            set(res, i * 8, bits);
          end loop;
        end if;
      when others    =>  -- EXE_MISC
    end case;

    return res;
  end;


  function pop_bytes(op_in : std_logic_vector;
                     split : std_logic) return word64 is
    -- Population count for nybble
    function bits4(nybble : word4) return word3 is
    begin
      case nybble is
      when "0000"                            => return "000";
      when "1111"                            => return "100";
      when "0001" | "0010" | "0100" | "1000" => return "001";
      when "1110" | "1101" | "1011" | "0111" => return "011";
      when others                            => return "010";
      end case;
    end;

    -- Population count for byte
    function bits8(byte : word8) return word4 is
      variable bits_hi  : word3 := bits4(hi_h(byte));
      variable bits_lo  : word3 := bits4(lo_h(byte));
    begin

      return uaddx(bits_hi, bits_lo);
    end;

    variable op   : word64 := uext(op_in, 64);
    -- Non-constant
    variable ret  : word64 := zerow64;
    variable pop8 : word8;
  begin
    for i in op'length / 8 - 1 downto 0 loop
        pop8 := uext(bits8(get(op, i * 8, 8)), pop8);
      set(ret, i * 8, pop8);
    end loop;

    if split = '0' then
      pop8   := get_lo(ret, 8);
      for i in op'length / 8 - 1 downto 1 loop
        pop8 := uadd(pop8, get(ret, i * 8, 8));
      end loop;
      ret    := uext(pop8, ret);
    end if;

    return ret;
  end;


  -- Terrible hardware implementation of population count,
  -- converted from what was pretty good for software.
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

  function pop(op_in : std_logic_vector; split : std_logic) return unsigned is
  begin
    return unsigned(pop_bytes(op_in, split));    -- 83 LUT, 6 levels (fixed, else 88/7)
  end;

  function pop(op_in : std_logic_vector) return unsigned is
  begin
--    return pop(op_in, '0');
    return pop_add(op_in);
  end;

  function clzx(op_in : std_logic_vector; split : std_logic) return unsigned is
    variable op   : word64 := uext(op_in, 64);
    -- Non-constant
    variable ret  : word64 := zerow64;
    variable clz8 : word8;
  begin
    for i in op_in'length / 8 - 1 downto 0 loop
        clz8 := uext(clz(get(op, i * 8, 8)), clz8);
      set(ret, i * 8, clz8);
    end loop;

    -- 166 with old impl 202 with new below
    if split = '0' then
        -- Check for empty bytes (bit 3 set means 8 zeros)
        if op_in'length = 64 then
          set(ret, 6 * 8, cond(ret(7 * 8 + 3) = '0', get(ret, 7 * 8, 8), uadd(get(ret, 7 * 8, 8), get(ret, 6 * 8, 8))));
          set(ret, 7 * 8, zerow8);
          set(ret, 4 * 8, cond(ret(5 * 8 + 3) = '0', get(ret, 5 * 8, 8), uadd(get(ret, 5 * 8, 8), get(ret, 4 * 8, 8))));
          set(ret, 5 * 8, zerow8);
        end if;
        set(ret, 2 * 8, cond(ret(3 * 8 + 3) = '0', get(ret, 3 * 8, 8), uadd(get(ret, 3 * 8, 8), get(ret, 2 * 8, 8))));
        set(ret, 3 * 8, zerow8);
        set(ret, 0 * 8, cond(ret(1 * 8 + 3) = '0', get(ret, 1 * 8, 8), uadd(get(ret, 1 * 8, 8), get(ret, 0 * 8, 8))));
        set(ret, 1 * 8, zerow8);

        if op_in'length = 64 then
          set(ret, 4 * 8, cond(ret(6 * 8 + 4) = '0', get(ret, 6 * 8, 8), uadd(get(ret, 6 * 8, 8), get(ret, 4 * 8, 8))));
          set(ret, 6 * 8, zerow8);
        end if;
        set(ret, 0 * 8, cond(ret(2 * 8 + 4) = '0', get(ret, 2 * 8, 8), uadd(get(ret, 2 * 8, 8), get(ret, 0 * 8, 8))));
        set(ret, 2 * 8, zerow8);

        if op_in'length = 64 then
          set(ret, 0 * 8, cond(ret(4 * 8 + 5) = '0', get(ret, 4 * 8, 8), uadd(get(ret, 4 * 8, 8), get(ret, 0 * 8, 8))));
          set(ret, 4 * 8, zerow8);
        end if;

    end if;

    return unsigned(get_lo(ret, op_in'length));
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



  function xperm4(
                  data    : wordx;
                  sel     : wordx;
                  clear   : wordx) return wordx is
    -- Non-constant
    variable res      : wordx           := (others => '0');
    type     w4_arr  is array (integer range <>) of word4;
    variable nybbles  : w4_arr(0 to 15) := (others => x"0");
    variable nybble   : word4;
    variable nybbleh  : word4;
  begin
    -- Create all possible nybbles
    for i in 0 to data'length / 4 - 1 loop
      nybbles(i) := get(data, i * 4, 4);
    end loop;
    -- Select nybbles
    for i in 0 to data'length / 4 - 1 loop
      nybble     := nybbles(u2i(get(sel, i * 4, 4)));
      nybbleh    := nybbles(u2i(get(sel, (i / 2) * 8 + 4, 4)));
      if clear(i) = '0' then
      else
        nybble   := (others => '0');
      end if;
      set(res, i * 4, nybble);
    end loop;

    return res;
  end;

  -- Misc operation
  function misc_op(active  : extension_type;
                   options : noelvalu_t;
                   op1_in  : wordx;
                   op2_in  : wordx;
                   ctrl    : word3;
                   ctrlx   : word3;
                   inst    : word32
                  ) return wordx is
    variable is_rv64      : boolean := is_enabled(active, x_rv64);
    variable is_rv32      : boolean := not is_rv64;
    variable ext_zbb      : boolean := is_enabled(active, x_zbb);
    variable ext_zbc      : boolean := is_enabled(active, x_zbc);
    variable ext_zbkb     : boolean := is_enabled(active, x_zbkb);
    variable ext_zbkc     : boolean := is_enabled(active, x_zbkc);
    variable ext_zbkx     : boolean := is_enabled(active, x_zbkx);
    variable en_clz       : boolean := options(alu_clz)      = '1' and enable_clz and ext_zbb;
    variable en_pop       : boolean := options(alu_pop)      = '1' and enable_pop and ext_zbb;
    -- Non-constant
    subtype  x2wordx is std_logic_vector(wordx'length * 2 - 1 downto 0);
    subtype  hwordx  is std_logic_vector(wordx'length / 2 - 1 downto 0);
    variable hop1         : hwordx;
    variable op1r         : wordx   := op1_in;
    variable op2r         : wordx   := op2_in;
    variable res          : wordx   := (others => '-');  -- Default to whatever
    variable split        : std_logic := '0';
    variable splatv       : word16  := zerow16;
    variable splatm       : word8   := zerow8;
  begin
    if (ext_zbb and ctrl = EXE_COUNT and ctrlx(2 downto 1) = "01") or  -- CTZ?
       ((ext_zbc or ext_zbkc) and
        ctrl = EXE_CLMUL and ctrlx /= R_CLMUL) then                    -- Reverse clmul?
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
        if ext_zbkb
           then
          op1r := op1_in;
          op2r := op2_in;
          case ctrlx is      -- *pack* rd, rs1, rs2
          when "001"    -- pack("xpack.w/h"): ba,21 -> 1a
            =>
            if ext_zbkb then
              res := lo_h(op2r) & lo_h(op1r);
            end if;
          when "011" |   -- packw: xxba,yy21 -> 001a
               "010" =>  -- packh: xxxxxxxa,yyyyyyy1 -> 0000001a
            if ctrlx = "011" then
              if is_rv64 and ext_zbkb then
                res := sext(get(op2r, 0, 16) & get(op1r, 0, 16), res);
              end if;
            else
              if ext_zbkb then
                res := uext(get(op2r, 0,  8) & get(op1r, 0,  8), res);
              end if;
            end if;
          when others =>
          end case;
        end if;
      when EXE_SHFLI =>
        case ctrlx is
        when "010" =>  -- unzip
          if (is_rv32 and ext_zbkb)
             then
            for i in 0 to op1_in'high loop
              if i mod 2 = 0 then
                res(i / 2) := op1_in(i);
              else
                res(res'length / 2 + i / 2) := op1_in(i);
              end if;
            end loop;
          end if;
        when "011" =>  -- zip
          if (is_rv32 and ext_zbkb)
             then
            for i in 0 to op1_in'high loop
              if i mod 2 = 0 then
                res(i) := op1_in(i / 2);
              else
                res(i) := op1_in(op1_in'length / 2 + i / 2);
              end if;
            end loop;
          end if;
        when others =>
        end case;
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
          res := xperm4(
                        op1_in, op2r, op1r);
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
            when "10"   => if en_pop then res := fit0ext(pop( op1r, split), res); end if;
            when others => if en_clz then res := fit0ext(clzx(op1r, split), res); end if;
          end case;
        end if;
      when EXE_CLMUL =>
        if ext_zbc or ext_zbkc then
          res := clmul_hdiv(op1r, op2r, op1r'length, 0);
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
  function math_op(active  : extension_type;
                   options : noelvalu_t;
                   op1_in  : wordx;
                   op2_in  : wordx;
                   ctrl_in : word3;
                   ctrlx   : word3;
                   inst    : word32) return wordx is
    variable is_rv64      : boolean := is_enabled(active, x_rv64);
    variable ext_zba      : boolean := is_enabled(active, x_zba);
    variable ext_zbb      : boolean := is_enabled(active, x_zbb);
    -- Non-constant
    variable op1          : wordx1;  -- Manipulated from _in for efficiency.
    variable op2          : wordx1;
    subtype  wordx2      is std_logic_vector(wordx'high + 2 downto 0);
    variable add_res      : wordx2;
--    variable less         : std_ulogic;
    variable less         : word8;
    variable equal        : word8;
    variable res          : wordx   := (others => '0');
    variable tmp          : wordx;
    variable ctrl         : word3;
    variable horizontal   : boolean := false;
    variable sel          : word8   := (others => '0');
    variable halfres      : word16  := (others => '0');
  begin
    ctrl := ctrl_in;

    -- Select Operands
    op1 := op1_in & '1';
    op2 := op2_in & '0';

    if ext_zba and ctrl = EXE_ADD then
      -- Limit to unsigned 32 bit?
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
      less := (others => not get_hi(add_res));
    -- Signed and different signs
    elsif get_hi(op1) /= get_hi(op2_in) then
      less := (others => get_hi(op1));
    else
      less := (others => add_res(add_res'high - 1));
    end if;


    case ctrl(1 downto 0) is
      when "00" | "01" =>   -- EXE_ADD | EXE_SUB
        res := get(add_res, 1, res'length);
        -- addw/subw?
        if is_rv64 and ctrl(2) = '0' then
          tmp              := res;
          res              := (others => res(31));
          res(31 downto 0) := tmp(31 downto 0);
        end if;
      when others =>        -- EXE_SLT | EXE_SLTU | EXE_CMPN | EXE_CMPNU
        res := u2vec(u2i(less(0)), res);
        -- MIN/MAX?
        if (ext_zbb
           ) and ctrlx(1) = '1' then
            if (ctrlx(0) xor less(0)) = '1' then
              res := op1_in;
            else
              res := op2_in;
            end if;
        end if;
    end case;

    return res;
  end;

  -- 64-bit shift operation
  function shift64(op  : std_logic_vector(127 downto 0);
                   cnt : std_logic_vector(5 downto 0)) return word64 is
    -- Non-constant
    variable shiftin : std_logic_vector(127 downto 0) := op;
  begin
    -- This is the only implementation that DC recognizes as a shifter.
    shiftin := std_logic_vector(shift_right(unsigned(shiftin), u2i(cnt)));

    return shiftin(63 downto 0);
  end;

  -- 32-bit shift operation
  function shift32(op  : word64;
                   cnt : std_logic_vector(4 downto 0)) return word64 is
    -- Non-constant
    variable shiftin : word64 := op;
    variable pad     : word;
  begin
    -- This is the only implementation that DC recognizes as a shifter.
    shiftin := std_logic_vector(shift_right(unsigned(shiftin), u2i(cnt)));

    pad                   := (others => shiftin(31));
    shiftin(63 downto 32) := pad;

    return shiftin;
  end;

  -- Shift operation
  -- ctrl(2) -> size
  -- ctrl(1) -> arithmetic
  -- ctrl(0) -> direction
  function shift_op(active   : extension_type;
                    options  : noelvalu_t;
                    op1      : wordx;
                    op2      : wordx;
                    ctrl_in  : word3;
                    ctrlx_in : word3;
                    inst     : word32) return wordx is
    variable is_rv64      : boolean := is_enabled(active, x_rv64);
    variable ext_zba      : boolean := is_enabled(active, x_zba);
    variable ext_zbb      : boolean := is_enabled(active, x_zbb);
    variable ext_zbkb     : boolean := is_enabled(active, x_zbkb);
    variable ext_zbkx     : boolean := is_enabled(active, x_zbkx);
    -- Non-constant
    variable shiftin64    : std_logic_vector(127 downto 0) := (others => '0');
    variable shiftin32    : word64                         := (others => '0');
    variable cnt          : std_logic_vector(  5 downto 0) := op2(5 downto 0);
    variable res32        : word64;
    variable res64        : word64;
    variable ctrl         : word3   := ctrl_in;
    variable ctrlx        : word3   := ctrlx_in;
    variable res          : wordx;
  begin
      if ctrl(1 downto 0) = "00" then  -- SLL
        cnt := not op2(5 downto 0);  -- Preshifted below for negation!
      end if;
    -- W operation?
    if is_rv64 and ctrl(2) = '0' then
      cnt(5) := '0';
    end if;

    -- SLLI.UW?
    if is_rv64 and ext_zba and ctrlx = "001" then
      -- Preshift for negation!
      set(shiftin64, 64 - 1, op1(word'range));
      -- Always left (noted as ctrl = EXE_SLL)
    -- Rotate?
    elsif (ext_zbb or ext_zbkb) and ctrlx = "010" then
      shiftin32     := op1(word'range) & op1(word'range);
      if is_rv64 then
        shiftin64   := to64(op1) & to64(op1);
      end if;
      -- Left?
      if ctrl(1 downto 0) = "00" then
        -- Preshift for negation!
        shiftin32 := shiftin32(0) & shiftin32(shiftin32'high downto 1);
        shiftin64 := shiftin64(0) & shiftin64(shiftin64'high downto 1);
      end if;
    -- Normal shift
    else
      case ctrl(1 downto 0) is
        when "00" => -- SLL
          shiftin32   := (others => '0');
          -- Preshift for negation!
          set(shiftin32, 32 - 1, op1(word'range));
          if is_rv64 then
            set(shiftin64, 64 - 1, op1);
          end if;
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

    -- W operation?
    if is_rv64 and ctrl(2) = '0' then
      shiftin64 := shiftin32 & shiftin32;
    end if;

    res32 := shift32(shiftin32, cnt(4 downto 0));
    res64 := shift64(shiftin64, cnt);


      if is_rv64 then
        if ctrl(2) = '1' then
          res := res64(wordx'range);
        else
          res := sext(res64(word'range), wordx'length);
        end if;
      else
        res := res32(wordx'range);
      end if;

    return res;
  end;

  -- ALU Execute
  procedure alu_execute(active  : extension_type;
                        options : noelvalu_t;
                        op1     : wordx;
                        op2     : wordx;
                        ctrl    : alu_ctrl;
                        inst    : word32;
                        res_out : out wordx) is
    variable alu_math_res  : wordx;
    variable alu_shift_res : wordx;
    variable alu_logic_res : wordx;
    variable alu_misc_res  : wordx;
    -- Non-constant
    variable res           : wordx := zerox;
  begin
    case ctrl.sel is
      when ALU_MATH  => res := math_op( active, options, op1, op2, ctrl.ctrl, ctrl.ctrlx, inst);
      when ALU_SHIFT => res := shift_op(active, options, op1, op2, ctrl.ctrl, ctrl.ctrlx, inst);
      when ALU_LOGIC => res := logic_op(active, options, op1, op2, ctrl.ctrl, ctrl.ctrlx);
      when others    => res := misc_op( active, options, op1, op2, ctrl.ctrl, ctrl.ctrlx, inst
                                      );
    end case;

    res_out := res;
  end;

end package body;
