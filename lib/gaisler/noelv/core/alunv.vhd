library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
library gaisler;
use gaisler.utilnv.all;
use grlib.stdlib.log2;
use grlib.stdlib.tost;
use grlib.riscv.all;
use gaisler.noelvint.word64;
use gaisler.noelvint.word8;
use gaisler.noelvint.word;
use gaisler.noelvint.wordx;
use gaisler.noelvint.zerox;

package alunv is

  subtype word2  is std_logic_vector(1 downto 0);
  subtype word3  is std_logic_vector(2 downto 0);
  subtype wordx1 is std_logic_vector(wordx'high + 1 downto 0);

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
                   cnt : std_logic_vector) return word64;
  function shift32(op  : word64;
                   cnt : std_logic_vector) return word64;

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
    variable is_rv64  : boolean      := is_enabled(active, x_rv64);
    variable is_rv32  : boolean      := not is_rv64;
    variable ext_zba  : integer      := is_enabled(active, x_zba);
    variable ext_zbb  : integer      := is_enabled(active, x_zbb);
    variable ext_zbc  : integer      := is_enabled(active, x_zbc);
    variable ext_zbs  : integer      := is_enabled(active, x_zbs);
    variable ext_zbkb : integer      := is_enabled(active, x_zbkb);
    variable ext_zbkc : integer      := is_enabled(active, x_zbkc);
    variable ext_zbkx : integer      := is_enabled(active, x_zbkx);
    variable op       : opcode_type  := inst(6 downto 0);
    variable funct3   : funct3_type  := inst(14 downto 12);
    variable funct7   : funct7_type  := inst(31 downto 25);
    variable funct12  : funct12_type := inst(31 downto 20);
    -- Non-constant
    variable ctrl     : word3        := EXE_AND;     -- Default assignment
    variable ctrlx    : word3        := "000";       -- Default to no special handling
    variable sel      : word2        := ALU_LOGIC;   -- Default assignment
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
          when I_SRLI =>
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
          when others =>
        end case;
        if ext_zba = 1 and op = OP_IMM_32 then
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
        if ext_zbb = 1 or ext_zbkb = 1 then
          if funct3 = R_SRL then
            case funct12 is
              when F12_ORCB =>
                if ext_zbb = 1 and op = OP_IMM then
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
                if ext_zbkb = 1 and op = OP_IMM then
                  sel   := ALU_MISC;
                  ctrl  := EXE_GREVI;
                  ctrlx := "010";
                end if;
              when F12_ZIP =>
                if is_rv32 and ext_zbkb = 1 and op = OP_IMM then
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
                if ext_zbb = 1 then
                  sel   := ALU_MISC;
                  ctrl  := EXE_COUNT;
                  ctrlx := inst(21 downto 20) & to_bit(op = OP_IMM_32);
                end if;
              when F12_SEXTB =>
                if ext_zbb = 1 and op = OP_IMM then
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_AND;
                  ctrlx := "101";
                end if;
              when F12_SEXTH =>
                if ext_zbb = 1 and op = OP_IMM then
                  sel   := ALU_LOGIC;
                  ctrl  := EXE_AND;
                  ctrlx := "110";
                end if;
              when F12_ZIP =>
                if is_rv32 and ext_zbkb = 1 and op = OP_IMM then
                  sel   := ALU_MISC;
                  ctrl  := EXE_SHFLI;
                  ctrlx := "010";
                end if;
              when others =>
                null;
            end case;
          end if;
        end if;
        if ext_zbs = 1 then
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
                  ctrl  := EXE_AND;
                  ctrlx := "001";
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
            if (ext_zbb = 1 or ext_zbkb = 1) and inst(30) = '1' then
              ctrlx  := "100";  -- Invert
            end if;
          when R_OR =>          -- Not used in case of OP_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_OR;
            if (ext_zbb = 1 or ext_zbkb = 1) and inst(30) = '1' then
              ctrlx  := "100";  -- Invert
            end if;
          when R_AND =>         -- Not used in case of OP_32
            sel      := ALU_LOGIC;
            ctrl     := EXE_AND;
            if (ext_zbb = 1 or ext_zbkb = 1) and inst(30) = '1' then
              ctrlx  := "100";  -- Invert
            end if;
          when R_SRL =>
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
          when others =>
        end case;
        if ext_zba = 1 then
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
        if ext_zbb = 1 then
          if ext_zbkb = 0 and funct12 = F12_ZEXTH and funct3 = R_XOR then
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
        if ext_zbkb = 1 then
          -- This will actually "override" F12_ZEXTH, since that is
          -- only a special case of F7_PACK/R_XOR.
          if funct7 = F7_PACK then  -- qqq Same as F7_ADDSLLIUW!
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
        if ext_zbc = 1 or ext_zbkc = 1 then
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
        if ext_zbs = 1 then
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
                  ctrl  := EXE_AND;
                  ctrlx := "001";
                when others =>
                  null;
              end case;
            end if;
          end if;
        end if;
        if ext_zbkx = 1 then
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
    variable is_rv64  : boolean      := is_enabled(active, x_rv64);
    variable is_rv32  : boolean      := not is_rv64;
    variable ext_zba  : integer      := is_enabled(active, x_zba);
    variable ext_zbb  : integer      := is_enabled(active, x_zbb);
    variable ext_zbc  : integer      := is_enabled(active, x_zbc);
    variable ext_zbs  : integer      := is_enabled(active, x_zbs);
    variable ext_zbkb : integer      := is_enabled(active, x_zbkb);
    variable ext_zbkc : integer      := is_enabled(active, x_zbkc);
    variable ext_zbkx : integer      := is_enabled(active, x_zbkx);
    variable ext_m    : integer      := is_enabled(active, x_m);
    variable opcode   : opcode_type  := inst_in( 6 downto  0);
    variable funct3   : funct3_type  := inst_in(14 downto 12);
    variable funct7   : funct7_type  := inst_in(31 downto 25);
    variable funct12  : funct12_type := inst_in(31 downto 20);
    -- Non-constant
    variable illegal  : std_ulogic   := '0';
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
                if ext_zbb = 1 then
                  illegal := '0';
                end if;
              when F12_ZIP =>
                if is_rv32 and ext_zbkb = 1 then
                  illegal := '0';
                end if;
              when others =>
                case funct7 is
                  when F7_BCLREXT | F7_BINV | F7_BSET =>  -- BCLRI/BINVI/BSETI
                    if ext_zbs= 1 then
                      illegal := '0';
                    end if;
                  when F7_BCLREXT_I64 | F7_BINV_I64 | F7_BSET_I64 =>
                    if ext_zbs = 1 and is_rv64 then
                      illegal := '0';
                    end if;
                  when others =>
                    -- SLLI with rd = x0 are custom HINTs.
                    if funct7(6 downto 1) = "000000" or funct7(6 downto 1) = "010000" then -- shamt[5:0]
                      if is_rv64 or funct7(0) = '0' then  -- >31 bit shift illegal on rv32.
                        illegal := '0';
                      end if;
                    end if;
                end case;
            end case;
          when I_SRLI => -- I_SRAI
            illegal   := '1';
            case funct12 is
              when F12_ORCB =>
                if ext_zbb = 1 then
                  illegal := '0';
                end if;
              when F12_REV8_RV32 =>
                if (ext_zbb = 1 or ext_zbkb = 1) and is_rv32 then
                  illegal := '0';
                end if;
              when F12_REV8_RV64 =>
                if (ext_zbb = 1 or ext_zbkb = 1) and is_rv64 then
                  illegal := '0';
                end if;
              when F12_BREV8 =>
                if ext_zbkb = 1 then
                  illegal := '0';
                end if;
              when F12_ZIP =>
                if is_rv32 and ext_zbkb = 1 then
                  illegal := '0';
                end if;
              when others =>
                case funct7 is
                  when F7_BCLREXT =>  -- BEXTI
                    if ext_zbs = 1 then
                      illegal := '0';
                    end if;
                  when F7_BCLREXT_I64 =>
                    if ext_zbs = 1 and is_rv64 then
                      illegal := '0';
                    end if;
                  when F7_ROT =>
                    if (ext_zbb = 1 or ext_zbkb = 1) then
                      illegal := '0';
                    end if;
                  when F7_ROR_I64 =>
                    if (ext_zbb = 1 or ext_zbkb = 1) and is_rv64 then
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
          when others =>
            illegal := '1';
        end case;
      when OP_REG =>
        case funct7 is
          when F7_BASE =>
            case funct3 is
              when R_ADD | R_SLL | R_SLT | R_SLTU |
                   R_XOR | R_SRL | R_OR  | R_AND => null;
                -- ADD/AND/OR/XOR/SLL/SRL with rd = x0 are standard HINTs.
                -- SLT/SLTU with rd = x0 are custom HINTs.
              when others => illegal := '1';
            end case;
          when F7_SUB =>
            case funct3 is
              when R_SUB | R_SRA => null;
                -- SUB/SRA with rd = x0 are standard HINTs.
              when R_AND | R_OR | R_XOR =>  -- ANDN/ORN/XORN
                if (ext_zbb = 0 and ext_zbkb = 0) then
                  illegal := '1';
                end if;
              when others => illegal := '1';
            end case;
--          when F7_MUL =>
--            if ext_m = 1 then
--              case funct3 is
--                when R_MUL | R_MULH | R_MULHSU | R_MULHU |
--                     R_DIV | R_DIVU | R_REM    | R_REMU => null;
--                when others => illegal := '1';
--              end case;
--            else
--              illegal := '1';
--            end if;
          when F7_BCLREXT =>  -- BCLR/BEXT
            if ext_zbs = 1 then
              case funct3 is
                when R_SLL | R_SRL => null;
                when others => illegal := '1';
              end case;
            else
              illegal := '1';
            end if;
          when F7_BINV =>
            if ext_zbs = 1 and funct3 = R_SLL then
              null;
            else
              illegal := '1';
            end if;
          when F7_BSET =>  -- BSET/XPERM
            if ext_zbs = 1 and funct3 = R_SLL then
              null;
            elsif ext_zbkx = 1 and (funct3 = R_XOR or funct3 = R_SLT) then
              null;
            else
              illegal := '1';
            end if;
          when F7_ROT =>
            if (ext_zbb = 1 or ext_zbkb = 1) then
              case funct3 is
                when R_SLL | R_SRL => null;  -- ROL/ROR
                when others => illegal := '1';
              end case;
            else
              illegal := '1';
            end if;
          when F7_SHADD =>
            if ext_zba = 1 then
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
                if ext_zbc = 0 and ext_zbkc = 0 then
                  illegal := '1';
                end if;
              when "010" =>  -- CLMULR
                if ext_zbc = 0 then
                  illegal := '1';
                end if;
              when "100" | "101" | "110" | "111" =>  -- MIN/MINU/MAX/MAXU
                if ext_zbb = 0 then
                  illegal := '1';
                end if;
              when others =>
                illegal := '1';
            end case;
          when others =>
            if ext_zbb = 1 and is_rv32 and funct12 = F12_ZEXTH and funct3 = "100" then
              null;
            elsif ext_zbkb = 1 and funct7 = F7_PACK and (funct3 = R_XOR or funct3 = R_AND) then
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
                if ext_zbb = 1 then
                  illegal := '0';
                end if;
              when others =>
                case funct7 is
                  when F7_ADDSLLIUW | F7_SLLIUW_I64 =>
                    if ext_zba = 1 and funct3 = R_SLL then
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
                if (ext_zbb = 1 or ext_zbkb = 1) then
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
        if ext_zbb = 1 and funct12 = F12_ZEXTH and funct3 = "100" then
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
--              if ext_m = 1 then
--                case funct3 is
--                  when R_MULW | R_DIVW | R_DIVUW | R_REMW | R_REMUW => null;
--                  when others => illegal := '1';
--                end case;
--              else
--                illegal := '1';
--              end if;
            -- This is the same as F7_PACK
            when F7_ADDSLLIUW =>  -- Note that this uses same funct7 as F12_ZEXT above!
              if ext_zba = 1 and funct3 = R_ADD then
                null;
              elsif ext_zbkb = 1 and funct3 = R_XOR then
                null;
              else
                illegal := '1';
              end if;
            when F7_ROT =>
              if (ext_zbb = 1 or ext_zbkb = 1) then
                case funct3 is
                  when R_SLL | R_SRL => null;  -- ROLW/RORW
                  when others => illegal := '1';
                end case;
              else
                illegal := '1';
              end if;
            when F7_SHADD =>
              if ext_zba = 1 then
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
  function logic_op(active : extension_type;
                    op1_in : wordx;
                    op2_in : wordx;
                    ctrl   : word3;
                    ctrlx  : word3) return wordx is
--    variable ext_zba : integer := 1;
--    variable ext_zbb : integer := 1;
--    variable ext_zbc : integer := 1;
--    variable ext_zbs : integer := 1;
    variable is_rv64  : boolean := is_enabled(active, x_rv64);
    variable is_rv32  : boolean := not is_rv64;
    variable ext_zba  : integer := is_enabled(active, x_zba);
    variable ext_zbb  : integer := is_enabled(active, x_zbb);
    variable ext_zbc  : integer := is_enabled(active, x_zbc);
    variable ext_zbs  : integer := is_enabled(active, x_zbs);
    variable ext_zbkb : integer := is_enabled(active, x_zbkb);
    variable ext_zbkc : integer := is_enabled(active, x_zbkc);
    variable ext_zbkx : integer := is_enabled(active, x_zbkx);
    variable op1      : wordx   := op1_in;
    variable op2      : wordx   := op2_in;
    -- Non-constant
    variable res      : wordx   := (others => '-');
    variable bits     : std_logic_vector(7 downto 0);
  begin
    case ctrlx is
      when "111" | "011" | "001" =>
        if ext_zbs = 1 then
          op2              := (others => ctrlx(2));
          bits                          := (others => ctrlx(2));
          bits(u2i(op2_in(2 downto 0))) := not ctrlx(2);
          for i in wordx'length / 8 - 1 downto 0 loop
            if (is_rv64 and u2vec(i, 3) = op2_in(5 downto 3)) or
               (is_rv32 and u2vec(i, 2) = op2_in(4 downto 3)) then
              set(op2, i * 8, bits);
            end if;
          end loop;
        end if;
      when "110" | "010" =>  -- 16 bit sign/zero extension
        if ext_zbb = 1 then
          op1(op1'high downto 16) := (others => op1(15) and ctrlx(2));
          op2                     := (others => '1');
        end if;
      when "101" =>          -- 8 bit sign extension
        if ext_zbb = 1 then
          op1(op1'high downto 8) := (others => op1(7));
          op2 := (others => '1');
        end if;
      when "100" | "000" =>  -- Possible inversion
        if ext_zbb = 1 or ext_zbkb = 1 then
          op2 := op2 xor (wordx'range => ctrlx(2));
        end if;
      when others =>
    end case;

    case ctrl is
      when EXE_XOR   => res := op1 xor op2;
      when EXE_OR    => res := op1 or  op2;
      when EXE_AND   => res := op1 and op2;
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
    if ext_zbs = 1 and ctrlx = "001" then
      res := u2vec(u2i(not all_0(res)), res);
    end if;

    return res;
  end;

--  function reverse(op : wordx) return wordx is
--    -- Non-constant
--    variable res : wordx;
--  begin
--    for i in 0 to op'high loop
--      res(i) := op(op'high - i);
--    end loop;
--
--    return res;
--  end;
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

  function clz(op_in : std_logic_vector) return unsigned is
    variable op      : std_logic_vector(op_in'length - 1 downto 0) := op_in;
    variable cnt_top : integer := log2(op'length);
    -- Non-constant
    variable cnt     : unsigned(cnt_top downto 0);
  begin
    if op'length = 1 then
      cnt(0) := not op(0);
    else
      if not all_0(hi_h(op)) then
        cnt := "0" & clz(hi_h(op));
      else
        cnt := uaddx(clz(lo_h(op)), u2vec(op'length / 2, cnt_top));
      end if;
    end if;

    return cnt;
  end;

  function pop(op_in : std_logic_vector) return unsigned is
    variable op : std_logic_vector(op_in'length - 1 downto 0) := op_in;
  begin
    if op'length = 1 then
      return u2vec(u2i(op(0)), 1);
    else
      return uaddx(pop(hi_h(op)), pop(lo_h(op)));
    end if;
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
    variable res : wordx := (others => '0');
  begin
    for i in 0 to data'length / 4 - 1 loop
      if clear(i) = '0' then
        set(res, i * 4, get(data, u2i(get(sel, i * 4, 4)) * 4, 4));
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
    variable is_rv64  : boolean  := is_enabled(active, x_rv64);
    variable is_rv32  : boolean  := not is_rv64;
    variable ext_zba  : integer  := is_enabled(active, x_zba);
    variable ext_zbb  : integer  := is_enabled(active, x_zbb);
    variable ext_zbc  : integer  := is_enabled(active, x_zbc);
    variable ext_zbs  : integer  := is_enabled(active, x_zbs);
    variable ext_zbkb : integer  := is_enabled(active, x_zbkb);
    variable ext_zbkc : integer  := is_enabled(active, x_zbkc);
    variable ext_zbkx : integer  := is_enabled(active, x_zbkx);
    -- Non-constant
    subtype  x2wordx is std_logic_vector(wordx'length * 2 - 1 downto 0);
    subtype  hwordx  is std_logic_vector(wordx'length / 2 - 1 downto 0);
--    variable x2res    : x2wordx  := clmul_div(op1_in, op2_in, wordx'length, 0);
    variable hop1     : hwordx;
    variable op1r     : wordx    := op1_in;
    variable op2r     : wordx    := op2_in;
    variable res      : wordx;
  begin
    if (ext_zbb = 1 and ctrl = EXE_COUNT and ctrlx(2 downto 1) = "01") or  -- CTZ?
       ((ext_zbc = 1 or ext_zbkc = 1) and
        ctrl = EXE_CLMUL and ctrlx /= R_CLMUL) then                        -- Reverse clmul?
      op1r := reverse(op1_in);
      op2r := reverse(op2_in);  -- Irrelevant for CTZ
    end if;

    case ctrl is
      when EXE_BYPASS2 =>
        res := op2_in;
      when EXE_GREVI =>
        if (ext_zbb = 1 or ext_zbkb = 1) and ctrlx = "001" then
          for i in 0 to op1_in'length / 8 - 1 loop
            set(res, (op1_in'length / 8 - 1 - i) * 8, get(op1_in, i * 8, 8));
          end loop;
        elsif ext_zbkb = 1 and ctrlx = "010" then
          for i in 0 to op1_in'length / 8 - 1 loop
            set(res, i * 8, reverse(get(op1_in, i * 8, 8)));
          end loop;
        else
          res := (others => '-');
        end if;
      when EXE_PACK =>
        if ext_zbkb = 1 then
          case ctrlx is
          when "001"  => res := lo_h(op2_in) & lo_h(op1_in);
          when "011"  => res := sext(get(op2_in, 0, 16) & get(op1_in, 0, 16), res);
          when others => res := uext(get(op2_in, 0,  8) & get(op1_in, 0,  8), res);
          end case;
        else
          res := (others => '-');
        end if;
      when EXE_SHFLI =>
        if is_rv32 and ext_zbkb = 1 then
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
        else
          res := (others => '-');
        end if;
      when EXE_XPERM =>
        if ext_zbkx = 1 then
          op1r := (others => '0');
          -- xperm8?
          if ctrlx(0) = '0' then
            for i in 0 to op2_in'length / 8 - 1 loop
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
              if op2r(i * 4 + 3) = '1' then
                op1r(i) := '1';
              end if;
            end loop;
          end if;
          res := xperm4(op1_in, op2r, op1r);
        else
          res := (others => '-');
        end if;
      when EXE_COUNT =>
        if ext_zbb = 1 then
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
        if ext_zbc = 1 or ext_zbkc = 1 then
          res := clmul_hdiv(op1r, op2r, op1r'length, 0);
          case ctrlx is
            when R_CLMUL  => null;
            when R_CLMULH => res := '0' & reverse(res)(res'high downto 1);
            when others   =>
              if ext_zbc = 1 then
                res := reverse(res);
              end if;
          end case;
        end if;
      when others =>
        res := (others => '-');
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
--    variable is_rv64 : boolean := true;
--    variable ext_zba : integer := 1;
--    variable ext_zbb : integer := 1;
--    variable ext_zbc : integer := 1;
--    variable ext_zbs : integer := 1;
    variable is_rv64  : boolean := is_enabled(active, x_rv64);
    variable ext_zba  : integer := is_enabled(active, x_zba);
    variable ext_zbb  : integer := is_enabled(active, x_zbb);
    variable ext_zbc  : integer := is_enabled(active, x_zbc);
    variable ext_zbs  : integer := is_enabled(active, x_zbs);
    variable ext_zbkb : integer := is_enabled(active, x_zbkb);
    variable ext_zbkc : integer := is_enabled(active, x_zbkc);
    variable ext_zbkx : integer := is_enabled(active, x_zbkx);
    -- Non-constant
    variable op1      : wordx1;  -- Manipulated from _in for efficiency.
    variable op2      : wordx1;
    subtype  wordx2  is std_logic_vector(wordx'high + 2 downto 0);
    variable add_res  : wordx2;
    variable less     : std_ulogic;
    variable res      : wordx;
    variable tmp      : wordx;
  begin
    -- Select Operands
    op1 := op1_in & '1';
    op2 := op2_in & '0';

    if ext_zba = 1 and ctrl = EXE_ADD then
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
      when "11" | "10" => res := u2vec(u2i(less), res);        -- EXE_SLT | EXE_SLTU
      when others      => null;
    end case;

    -- MIN/MAX?
    if ext_zbb = 1 and (ctrl = EXE_SLT or ctrl = EXE_SLTU) and ctrlx(1) = '1' then
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
                   cnt : std_logic_vector) return word64 is
    -- Non-constant
    variable shiftin : std_logic_vector(127 downto 0) := op;
  begin
    if cnt(5) = '1' then shiftin(95 downto 0) := shiftin(127 downto 32); end if;
    if cnt(4) = '1' then shiftin(79 downto 0) := shiftin( 95 downto 16); end if;
    if cnt(3) = '1' then shiftin(71 downto 0) := shiftin( 79 downto  8); end if;
    if cnt(2) = '1' then shiftin(67 downto 0) := shiftin( 71 downto  4); end if;
    if cnt(1) = '1' then shiftin(65 downto 0) := shiftin( 67 downto  2); end if;
    if cnt(0) = '1' then shiftin(63 downto 0) := shiftin( 64 downto  1); end if;

    return shiftin(63 downto 0);
  end;

  -- 32-bit shift operation
  function shift32(op  : word64;
                   cnt : std_logic_vector) return word64 is
    -- Non-constant
    variable shiftin : word64 := op;
    variable pad     : word;
  begin
    if cnt(4) = '1' then shiftin(47 downto 0) := shiftin(63 downto 16); end if;
    if cnt(3) = '1' then shiftin(39 downto 0) := shiftin(47 downto  8); end if;
    if cnt(2) = '1' then shiftin(35 downto 0) := shiftin(39 downto  4); end if;
    if cnt(1) = '1' then shiftin(33 downto 0) := shiftin(35 downto  2); end if;
    if cnt(0) = '1' then shiftin(31 downto 0) := shiftin(32 downto  1); end if;

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
    variable ext_zba   : integer := is_enabled(active, x_zba);
    variable ext_zbb   : integer := is_enabled(active, x_zbb);
    variable ext_zbc   : integer := is_enabled(active, x_zbc);
    variable ext_zbs   : integer := is_enabled(active, x_zbs);
    variable ext_zbkb  : integer := is_enabled(active, x_zbkb);
    variable ext_zbkc  : integer := is_enabled(active, x_zbkc);
    variable ext_zbkx  : integer := is_enabled(active, x_zbkx);
    -- Non-constant
    variable shiftin64 : std_logic_vector(127 downto 0) := (others => '0');
    variable shiftin32 : word64                         := (others => '0');
    variable cnt       : std_logic_vector(  5 downto 0) := op2(5 downto 0);
    variable res32     : word64;
    variable res64     : word64;
  begin
    -- SLLI.UW?
    if is_rv64 and ext_zba = 1 and ctrlx = "001" then
      set(shiftin64, 64 - 1, op1(word'range));
      -- Always left
      cnt := not op2(5 downto 0);  -- Preshifted above for negation!
    -- Rotate?
    elsif (ext_zbb = 1 or ext_zbkb = 1) and ctrlx = "010" then
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
      when others       => res := alu_misc_res; -- ALU_MISC
    end case;

    res_out     := res;
  end;

end package body;
