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
-- Entity:      itracenv
-- File:        itracenv.vhd
-- Author:      Johan Klockars, Cobham Gaisler AB
-- Description: Instruction trace handler
------------------------------------------------------------------------------

    -- trace.ctrl
    -- 12:8   disable trace for mode VU/VS/U/S/M

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.log2;
use grlib.stdlib.print;
use grlib.stdlib.tost;
use grlib.stdlib.tost_bits;
use grlib.riscv.PRIV_LVL_M;
use grlib.riscv.PRIV_LVL_S;
use grlib.riscv.PRIV_LVL_U;
use grlib.riscv.opcode_type;
use grlib.riscv.funct3_type;
use grlib.riscv.priv_lvl_type;
use grlib.riscv.reg_t;
library gaisler;
use gaisler.noelvtypes.all;
use gaisler.noelv.XLEN;
use gaisler.noelvint.itrace_in_type;
use gaisler.noelvint.itrace_in_none;
use gaisler.noelvint.itrace_out_type;
use gaisler.noelvint.itrace_out_none;
use gaisler.noelvint.fpu5_out_type;
use gaisler.noelvint.fpu5_out_none;
use gaisler.noelvint.trace_type;
use gaisler.noelvint.trace_fpu;
use gaisler.noelvint.trace_fpu_none;
use gaisler.noelvint.trace_info;
use gaisler.noelvint.trace_addr;
use gaisler.utilnv.all_0;
use gaisler.utilnv.all_1;
use gaisler.utilnv.get_hi;
use gaisler.utilnv.get_lo;
use gaisler.utilnv.hi_h;
use gaisler.utilnv.lo_h;
use gaisler.utilnv.uadd;
use gaisler.utilnv.uext;
use gaisler.utilnv.sext;
use gaisler.utilnv.u2i;
use gaisler.utilnv.u2vec;
use gaisler.utilnv.to_bit;
use gaisler.utilnv.cond;
use gaisler.nvsupport.is_fpu_fsd;
use gaisler.nvsupport.rd_gen;
use gaisler.nvsupport.is_csr;
use gaisler.noelvtypes.to_cause;
use gaisler.noelvtypes.cause2int;
use gaisler.nvsupport.CAUSE_IRQ_RAS_HIGH_PRIO;
use gaisler.nvsupport.CAUSE_IRQ_RAS_LOW_PRIO;
-- pragma translate_off
use gaisler.nvsupport.is_fpu_rd;
use gaisler.fputilnv.fpreg2st;
use gaisler.fputilnv.tost_float;
-- pragma translate_on

entity itracenv is
  generic (
    fabtech      : integer range 0 to NTECH;    -- fabtech
    memtech      : integer range 0 to NTECH;    -- memtech
    single_issue : integer range 0 to 1;        -- 1 - only one pipeline
    dmen         : integer range 0 to 1;        -- Using RISC-V Debug Module
    tbuf         : integer;                     -- Trace buffer size in kB
    disas        : integer              := 0;   -- Disassembly to console
    scantest     : integer;                     -- Scantest support
    fpu_lane     : integer range 0 to 1 := 0;   -- Lane where (non-memory) FPU instructions go
    csr_lane     : integer range 0 to 1 := 0;   -- Lane where CSRs are handled
    pipeline_in  : integer range 0 to 1 := 1;   -- Pipeline incoming IU data
    pipeline_fpu : integer range 0 to 1 := 1;   -- Pipeline incoming FPU data
    pipeline_out : integer range 0 to 1 := 1    -- Pipeline outgoing trace
  );
  port (
    clk     : in  std_ulogic;
    rstn    : in  std_ulogic;
    itracei : in  itrace_in_type;
    itraceo : out itrace_out_type;
    fpo     : in  fpu5_out_type;
    testen  : in  std_ulogic;
    testrst : in  std_ulogic
  );
end itracenv;
architecture rtl of itracenv is

  -- Lane where memory operations are handled (must be 0!)
  -- (Copied from iunv.)
  constant memory_lane : integer := 0;

  -- Implementation Constants
--  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1
--                                     and GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 0;
  constant RESET_ALL    : boolean := true;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  -- Trace Buffer Constants
  constant TRACEBUF     : boolean := (tbuf /= 0);
  constant TBUFBITS     : integer := 4 + log2(tbuf);

  constant trace_prv           : std_logic_vector(  1 downto   0) := (others => '0');
  constant trace_v             : integer                          := 2;
  constant trace_irq           : integer                          := 3;
  -- Note that trace_cause is one bit too small to cover RAS interrupt. "Packs" high interrupt.
  constant trace_cause         : std_logic_vector(  8 downto   4) := (others => '0');
  constant trace_skips         : std_logic_vector( 11 downto   9) := (others => '0');  -- Not used here!
  constant trace_fpu_available : integer                          := 12;
  constant trace_swap          : integer                          := 13;
  constant trace_skipx         : integer                          := 14;
  constant trace_tdelta        : integer                          := 15;
  constant trace_fpu_id        : std_logic_vector( 20 downto  16) := (others => '0');
  constant trace_fpu_rd        : std_logic_vector( 28 downto  24) := (others => '0');
  constant trace_adelta        : integer                          := 29;
  constant trace_timestamp     : std_logic_vector( 63 downto  32) := (others => '0');

  constant trace_lane0         : std_logic_vector(255 downto  64) := (others => '0');
  constant trace_lane1         : std_logic_vector(511 downto 320) := (others => '0');

  constant trace_skipinst      : integer                          := 0;
  constant trace_pc32          : std_logic_vector( 31 downto   1) := (others => '0');
  constant trace_pc            : std_logic_vector( 56 downto   1) := (others => '0');
--  constant trace_pc            : std_logic_vector( 42 downto   1) := (others => '0');
--  constant trace_inst_xlo      : std_logic_vector( 58 downto  43) := (others => '0');
  constant trace_skipres       : integer                          := 58;
  constant trace_result_v      : integer                          := 60;
  constant trace_xdata_v       : integer                          := 61;
  constant trace_exception     : integer                          := 62;
  constant trace_valid         : integer                          := 63;
  constant trace_compressed    : std_logic_vector( 65 downto  64) := (others => '0');
  constant trace_cinst         : std_logic_vector( 79 downto  64) := (others => '0');
  constant trace_inst          : std_logic_vector( 95 downto  64) := (others => '0');
  constant trace_xdata_h       : std_logic_vector(127 downto  96) := (others => '0');
  constant trace_result32      : std_logic_vector(159 downto 128) := (others => '0');
  constant trace_result_hi     : std_logic_vector(191 downto 160) := (others => '0');
  constant trace_result        : std_logic_vector(191 downto 128) := (others => '0');

  constant trace_fpu_result    : std_logic_vector(319 downto 256) := (others => '0');

  constant trace_valid0        : integer := trace_lane0'low + trace_valid;
  constant trace_valid1        : integer := trace_lane1'low + trace_valid;
  constant trace_exception0    : integer := trace_lane0'low + trace_exception;
  constant trace_exception1    : integer := trace_lane1'low + trace_exception;

  -- Lane positions for extended (translation_off) trace
  constant trace_csrw          : std_logic_vector( 63 + 192 downto   0 + 192) := (others => '0');
  constant trace_csrw32        : std_logic_vector( 31 + 192 downto   0 + 192) := (others => '0');
  constant trace_inst_lo       : std_logic_vector( 79 + 192 downto  64 + 192) := (others => '0');
  constant trace_cfi           : std_logic_vector( 80 + 192 downto  80 + 192) := (others => '0');
  -- Positions in complete data for extended (translation_off) trace
  constant trace_csrw0         : std_logic_vector( 63 + 512 downto   0 + 512) := (others => '0');
  constant trace_csrw1         : std_logic_vector(127 + 512 downto  64 + 512) := (others => '0');
  constant trace_inst_lo0      : std_logic_vector(143 + 512 downto 128 + 512) := (others => '0');
  constant trace_inst_lo1      : std_logic_vector(159 + 512 downto 144 + 512) := (others => '0');
  constant trace_cfi0          : std_logic_vector(160 + 512 downto 160 + 512) := (others => '0');
  constant trace_cfi1          : std_logic_vector(161 + 512 downto 161 + 512) := (others => '0');

  type fpu_trace_buffer is record
    valid : std_ulogic;                -- FPU data awaiting trace
    id    : fpu_id;
    rd    : reg_t;
    data  : word64;
    hold  : std_logic_vector(0 to 7);  -- Shifted wait cycles
  end record;

  constant fpu_trace_none : fpu_trace_buffer := (
    valid => '0',
    id    => (others => '0'),
    rd    => (others => '0'),
    data  => zerow64,
    hold  => (others => '0')
  );

  type itrace_regs is record
    itracei : itrace_in_type;
    itraceo : itrace_out_type;
    fpo     : fpu5_out_type;
    tcnt    : trace_addr;
    fptbuf  : fpu_trace_buffer;
--    trace   : trace_type;
  end record;

  constant itrace_none : itrace_regs := (
    itracei => itrace_in_none,
    itraceo => itrace_out_none,
    fpo     => fpu5_out_none,
    tcnt    => (others => '0'),
    fptbuf  => fpu_trace_none
  );

  function cause_pack(cause_in : cause_type) return std_logic_vector is
    -- Non-constant
    variable cause : std_logic_vector(trace_cause'length - 1 downto 0);
  begin
    cause := u2vec(cause2int(cause_in), cause);
    -- Deal with known causes that do not fit.
    -- For IRQs, use numbers "Designated for custom use", from the top down.
    if    cause_in = CAUSE_IRQ_RAS_HIGH_PRIO then cause := u2vec(31, cause);
    elsif cause_in = CAUSE_IRQ_RAS_LOW_PRIO  then cause := u2vec(30, cause);
    end if;

    return cause;
  end;

  function cause_unpack(cause_in : std_logic_vector; irq : std_ulogic) return cause_type is
    -- Non-constant
    variable cause : cause_type := to_cause(u2i(cause_in), irq = '1');
  begin
    -- Deal with known causes that do not fit - see cause_pack().
    if    cause = to_cause(31, true) then cause := CAUSE_IRQ_RAS_HIGH_PRIO;
    elsif cause = to_cause(30, true) then cause := CAUSE_IRQ_RAS_LOW_PRIO;
    end if;

    return cause;
  end;

  signal r, rin : itrace_regs;

  function to_addr(addr : std_logic_vector) return std_logic_vector is
  begin
    return uext(addr, 64);
  end;

  signal arst : std_ulogic;

-- pragma translate_off
  -- Types copied from iunv.
  constant lanes             : std_logic_vector(0 to 1 - single_issue) := (others => '0');
  subtype lanes_type        is std_logic_vector(lanes'high downto lanes'low);
  -- These would be nicer with just (lanes'range),
  -- but for some reason Vivado XSIM 2018.1 is then likely to crash.
  subtype word_lanes_type   is word_arr(lanes'low to lanes'high);
  subtype wordx_lanes_type  is wordx_arr(lanes'low to lanes'high);
  subtype word16_lanes_type is word16_arr(lanes'low to lanes'high);
  type word3_lanes_type     is array (lanes'low to lanes'high) of word3;

  -- Signals consumed by the disassembly units.
  signal hart           : word4;
  signal disas_en       : std_ulogic := '0';
  signal disas_iv       : lanes_type := (others => '0');
  signal dis_mcycle     : word64     := zerow64;
  signal dis_minstret   : word64     := zerow64;
  signal dis_dual_issue : word64     := zerow64;
  signal wren           : lanes_type;
  signal wren_f         : lanes_type;
  signal memen          : lanes_type;
  signal wcen           : lanes_type;
  signal way            : word3_lanes_type;
  signal inst           : word_lanes_type;
  signal cinst          : word16_lanes_type;
  signal comp           : lanes_type;
  signal pc             : wordx_lanes_type;
  signal wdata          : wordx_lanes_type;
  signal fsd            : lanes_type;
  signal fsd_hi         : wordx_lanes_type;
  signal wcsr           : wordx_lanes_type;
  signal trap           : lanes_type;
  signal cause          : wordx;
  signal tval           : wordx_lanes_type;
  signal wb_prv         : priv_lvl_type;
  signal wb_v           : std_ulogic;
  signal cfi            : word2;
-- pragma translate_on

begin

  arst <= testrst when (ASYNC_RESET and scantest /= 0 and testen /= '0')  else
          rstn when ASYNC_RESET else '1';
  
-- pragma translate_off
  hart <= itracei.hartid(hart'range);
-- pragma translate_on

  process (r, itracei, fpo) is
    -- Non-constant
    variable v            : itrace_regs;
    variable wcsr         : wordx;
    variable tmode_dis    : word5;
    variable info         : trace_info;
    variable fpu          : trace_fpu;
    variable odata        : trace_data;
    variable lane         : std_logic_vector(trace_lane0'length - 1
-- pragma translate_off
--                                             + trace_csrw'length + trace_inst_lo'length
-- pragma translate_on
                                             downto 0);
    variable taddr        : trace_addr;
    variable write        : trace_sel;
    variable enable       : std_ulogic;
    variable tactive      : std_ulogic;
    variable tfpuact      : std_ulogic;
    variable fptone       : std_ulogic;
    variable fpulog       : boolean;
    variable fp           : fpu_trace_buffer;
    variable holdn        : std_ulogic;
    variable dm_tbufaddr  : trace_addr;
    type     core_state  is (run, dhalt, dexec);  -- Copied from iunv
    variable rstate       : core_state;
    variable r_itracei    : itrace_in_type;
    variable r_fpo        : fpu5_out_type;
    variable tpbuf_en     : std_ulogic;
    variable trace        : trace_type;
    variable itrace_out   : itrace_out_type;
    variable dm_trace     : std_ulogic;
    -- Filtering
    variable active       : boolean;
    variable trigger      : word2;
    variable halt         : boolean;
    variable match_ops    : boolean;
    variable match_op     : boolean;
    variable match_opaddr : boolean;
    variable match_rwaddr : boolean;
    variable match_exc    : boolean;
    variable match_result : boolean;
    variable match_csrw   : boolean;
    variable match_fpu    : boolean;
    variable inst         : word;
    variable pc           : word64;
    variable is_amo       : boolean;
    variable is_ld        : boolean;
    variable is_st        : boolean;
  begin
    v         := r;

    odata     := (others => '0');
    lane      := (others => '0');

    write     := (others => '0');
    enable    := '0';
    fpulog    := false;
    fptone    := '0';

    if pipeline_in = 0 then
      r_itracei := itracei;
    else
      r_itracei := r.itracei;
    end if;
    if pipeline_fpu = 0 then
      r_fpo     := fpo;
    else
      r_fpo     := r.fpo;
    end if;

    holdn       := r_itracei.holdn;
    dm_tbufaddr := r_itracei.dm_tbufaddr;
    dm_trace    := r_itracei.dm_trace;
    tpbuf_en    := r_itracei.tpbuf_en;
    case r_itracei.rstate is
    when "00"   => rstate := run;
    when "01"   => rstate := dhalt;
    when others => rstate := dexec;
    end case;

    trace       := r_itracei.trace;
    tmode_dis   := trace.ctrl(12 downto 8);

    info        := r_itracei.info;
    fpu         := trace_fpu_none;
    wcsr        := info.lanes(memory_lane).xdata;

    taddr       := r.tcnt;

    is_amo      := r_itracei.is_amo;
    is_ld       := r_itracei.is_ld;
    is_st       := r_itracei.is_st;

    halt        := false;

    if pipeline_in = 0 then
      v.itracei := itrace_in_none;
    else
      v.itracei := itracei;
      v.itracei.hartid  := (others => '0'); -- No need ot register this
    end if;
    if pipeline_fpu = 0 then
      v.fpo     := fpu5_out_none;
    else
      v.fpo     := fpo;
    end if;

    -- Trace active
    tactive := '0';
    if (info.lanes(0).valid or info.lanes(0).exception or
        info.lanes(1).valid or info.lanes(1).exception) = '1' then
      if rstate = run then
        if info.v = '0' then
          if (info.prv = PRIV_LVL_M and tmode_dis(0) = '0') or
             (info.prv = PRIV_LVL_S and tmode_dis(1) = '0') or
             (info.prv = PRIV_LVL_U and tmode_dis(2) = '0') then
            tactive := '1';
          end if;
        else
          if (info.prv = PRIV_LVL_S and tmode_dis(3) = '0') or
             (info.prv = PRIV_LVL_U and tmode_dis(4) = '0') then
            tactive := '1';
          end if;
        end if;
      elsif rstate = dexec and tpbuf_en = '1' then
        tactive := '1';
      end if;
    end if;

    tfpuact := '0';
    if r_fpo.wen = '1' then
      if r_fpo.mode(2) = '0' then
        if (r_fpo.mode(1 downto 0) = PRIV_LVL_M and tmode_dis(0) = '0') or
           (r_fpo.mode(1 downto 0) = PRIV_LVL_S and tmode_dis(1) = '0') or
           (r_fpo.mode(1 downto 0) = PRIV_LVL_U and tmode_dis(2) = '0') then
          tfpuact := '1';
        end if;
      else
        if (r_fpo.mode(1 downto 0) = PRIV_LVL_S and tmode_dis(3) = '0') or
           (r_fpo.mode(1 downto 0) = PRIV_LVL_U and tmode_dis(4) = '0') then
          tfpuact := '1';
        end if;
      end if;
    end if;

    if holdn = '1' and tactive = '1' then
      enable                := '1';
      write                 := (others => '1');
      v.tcnt                := uadd(r.tcnt, 1);
    end if;


    for i in 0 to 1 loop
      -- Ensure these are always set
      match_ops    := false;
      match_op     := false;
      match_opaddr := false;
      match_rwaddr := false;
      match_exc    := false;
      match_result := false;
      match_csrw   := false;
      match_fpu    := false;

      inst := info.lanes(i).inst;
      if info.lanes(i).compressed = '1' then
        inst(15 downto 0) := info.lanes(i).cinst;
      end if;
      pc   := sext(info.lanes(i).pc, pc);


      -- Valid and exception are assigned later since they may be modified.
      lane                          := (others => '0');
      lane(trace_pc'range)          := pc(trace_pc'range);
      lane(trace_inst'range)        := inst;
      lane(trace_result_v)          := info.lanes(i).int_res;
      lane(trace_result'range)      := uext(info.lanes(i).result, 64);
      if XLEN = 32 and i = fpu_lane and is_fpu_fsd(info.lanes(i).inst) then
        lane(trace_result_hi'range) := hi_h(info.lanes(i).result);
      end if;
      if i = 0 then
--        lane(trace_inst_xlo'range)  := get_lo(info.lanes(i).inst, 16);
        lane(trace_xdata_v)         := info.lanes(0).csr_write;
        lane(trace_xdata_h'range)   := get_lo(info.lanes(0).xdata, 32);
        odata(trace_lane0'range)    := lane(trace_lane0'length - 1 downto 0);
-- pragma translate_off
        odata(trace_inst_lo0'range) := info.lanes(i).inst(15 downto 0);
        odata(trace_csrw0'range)    := uext(info.lanes(i).xdata, 64);
        odata(trace_cfi0'low)       := info.lanes(i).cfi;
-- pragma translate_on
      else
--        lane(trace_inst_xlo'range)  := get_lo(info.lanes(i).inst, 16);
        lane(trace_xdata_v)         := info.lanes(0).memory;
        lane(trace_xdata_h'range)   := get_hi(info.lanes(0).xdata, 32);
        odata(trace_lane1'range)    := lane(trace_lane0'length - 1 downto 0);
-- pragma translate_off
        odata(trace_inst_lo1'range) := info.lanes(i).inst(15 downto 0);
        odata(trace_csrw1'range)    := uext(info.lanes(i).xdata, 64);
        odata(trace_cfi1'low)       := info.lanes(i).cfi;
-- pragma translate_on
      end if;
    end loop;

    -- Do not log invalid instructions (unless invalid due to fault).
    if (info.lanes(0).valid or info.lanes(0).exception or
        info.lanes(1).valid or info.lanes(1).exception) = '0' then
      enable         := '0';
      write          := (others => '0');
      v.tcnt         := r.tcnt;
    end if;

    -- Add FPU result, but try to combine with committed instruction,
    -- to save space in the trace buffer.

    if r.fptbuf.valid = '0' then
      -- No stored FPU result, so store new one (if any).
      -- Will be traced if an instruction is.
--        fptbuf.valid := to_bit(r_fpo.wen = '1' and tfpuact = '1' and
--                           not (dmen = 1 and rstate = dhalt));
      v.fptbuf.valid := r_fpo.wen and tfpuact;
      v.fptbuf.id    := r_fpo.wb_id;
      v.fptbuf.rd    := r_fpo.rd;
      v.fptbuf.data  := r_fpo.data;
      v.fptbuf.hold  := (others => '1');  -- Maximum wait time
      fp             := v.fptbuf;
      fptone         := '1';              -- Don't store if traced!
--      elsif r_fpo.wen  = '1' and tfpuact = '1' and
--            not (dmen = 1 and rstate = dhalt) then
    elsif r_fpo.wen  = '1' and tfpuact = '1' then
      -- Stored FPU result and new coming in, so dump old to trace
      -- and store new one.
      fp             := r.fptbuf;
      fp.hold        := (others => '0');  -- Force dump to trace
      v.fptbuf.valid := '1';
      v.fptbuf.id    := r_fpo.wb_id;
      v.fptbuf.rd    := r_fpo.rd;
      v.fptbuf.data  := r_fpo.data;
      v.fptbuf.hold  := (others => '1');  -- Maximum wait time
    else
      -- Stored FPU result, but nothing new coming in.
      -- Decrease wait time, unless an instruction is traced.
      v.fptbuf.hold  := '0' & r.fptbuf.hold(0 to r.fptbuf.hold'right - 1);
      fp             := v.fptbuf;
      fptone         := '1';              -- Remove if traced!
    end if;

    -- FPU result to trace?
    -- Do so only if instruction is traced,
    -- new FPU result coming in (see above),
    -- or timeout.
    if fp.valid = '1' and
       (enable = '1'
       ) then
      if fptone = '1' then
        v.fptbuf.valid := '0';
      end if;
      -- Note FPU result.
      fpu.available                               := '1';
      -- FPU operation ID, for matching with actual instruction.
      fpu.id                                      := fp.id;
      -- Used to be for simulation only, but could be of some use.
      fpu.rd                                      := fp.rd;
      -- If nothing else is being recorded this cycle,
      -- make sure to note both instructions as invalid.
      if enable = '0' then
        info.lanes(0).valid                       := '0';
        info.lanes(1).valid                       := '0';
        info.lanes(0).exception                   := '0';
        info.lanes(1).exception                   := '0';
      end if;

      enable                                      := '1';
      write                                       := (others => '1');
      v.tcnt                                      := uadd(r.tcnt, 1);
      fpulog                                      := true;

      fpu.result                                  := fp.data;
    end if;


    -- DM addressing?
    -- Note that FPU data may come in from above (enable will then be '1'),
    -- even for a little while after rstate becomes dhalt.
    if (enable = '0' or dm_trace /= '0') and dmen = 1 and rstate = dhalt then
      enable             := '1';
      write              := (others => '0');
      taddr              := dm_tbufaddr;
    end if;


    odata(trace_prv'range)        := info.prv;
    odata(trace_v)                := info.v;
    odata(trace_cause'range)      := cause_pack(info.cause);
    odata(trace_irq)              := info.cause.irq;
    odata(trace_swap)             := info.swap;
    odata(trace_timestamp'range)  := info.timestamp;
    odata(trace_fpu_id'range)     := fpu.id;
    odata(trace_fpu_rd'range)     := fpu.rd;
    odata(trace_fpu_available)    := fpu.available;
    odata(trace_fpu_result'range) := fpu.result;
    odata(trace_valid0)           := info.lanes(0).valid;
    odata(trace_valid1)           := info.lanes(1).valid;
    odata(trace_exception0)       := info.lanes(0).exception;
    odata(trace_exception1)       := info.lanes(1).exception;


    itrace_out.tcnt    := v.tcnt;
    itrace_out.taddr   := taddr;
    itrace_out.idata   := odata;
    itrace_out.write   := write;
    itrace_out.enable  := enable;


    v.itraceo          := itrace_out;

    -- To the Instruction Trace Buffer ------------------------------------

    if pipeline_out = 0 then
      itraceo <= itrace_out;
    else
      itraceo <= r.itraceo;
    end if;

    rin <= v;
  end process;

-- pragma translate_off
  dis : if disas >= 1 and disas < 4 generate
    process (clk)
      -- Non-constant
      variable fpu    : word64;
      variable fpuo   : word64;
      variable op     : opcode_type;
      variable funct3 : funct3_type;
      variable ucinst : word;
      variable i      : integer;
      variable data   : trace_data;
      variable lane   : std_logic_vector(trace_lane0'length + trace_csrw0'length +
                                         trace_inst_lo0'length + trace_cfi0'length - 1 downto 0);
    begin
      if rising_edge(clk) and rstn = '1' then
        data               := rin.itraceo.idata;
        dis_mcycle <= uadd(dis_mcycle, 1);
        if not (rin.itraceo.enable = '1' and all_1(rin.itraceo.write)) then
          disas_en         <= '0';
          disas_iv         <= (others => '0');
          wren             <= (others => '0');
          wren_f           <= (others => '0');
          memen            <= (others => '0');
          wcen             <= (others => '0');
          trap             <= (others => '0');
        else
          disas_en <= '1';
          if data(trace_fpu_available) = '1' then
            fpu            := data(trace_fpu_result'range);
            print("FPU " & tost(data(trace_fpu_id'range)) & " " &
                           fpreg2st(data(trace_fpu_rd'range)) & " = " &
                           tost(fpu) & " " & tost_float(fpu));
          end if;

          for j in lanes'range loop
            i              := j;
            if data(trace_swap) = '1' then
              i            := lanes'high - j;
            end if;
            lane           := data(trace_cfi0'range)  & data(trace_inst_lo0'range) &
                              data(trace_csrw0'range) & data(trace_lane0'range);
            if i = 1 then
              lane         := data(trace_cfi1'range)  & data(trace_inst_lo1'range) &
                              data(trace_csrw1'range) & data(trace_lane1'range);
            end if;
            way(j)         <= u2vec(i, 3);
            disas_iv(j)    <= lane(trace_valid);
            cinst(j)       <= lane(trace_cinst'range);
            ucinst         := lane(trace_inst'range);
            comp(j)        <= '0';
            if lane(trace_compressed'range) /= "11" then
              comp(j)      <= '1';
              ucinst(15 downto 0) := lane(trace_inst_lo'range);
            end if;
            inst(j)        <= ucinst;
            if lane(trace_valid) = '1' then
              if lane(trace_compressed'range) /= "11" then
--                report "disas " & tost(j) & " C " & tost(lane(trace_cinst'range)) & " " & tost(ucinst);
              else
--                report "disas " & tost(j) & "   " & tost(ucinst);
              end if;
            end if;
            fsd(j)         <= '0';
            if XLEN = 32 then
              fsd(j)       <= to_bit(i = fpu_lane and is_fpu_fsd(ucinst));
              pc(j)        <= sext(lane(trace_pc32'range) & '0', pc(0));
              wdata(j)     <= uext(lane(trace_result32'range), wdata(0));
              fsd_hi(j)    <= uext(lane(trace_result_hi'range), fsd_hi(0));
              wcsr(j)      <= uext(lane(trace_csrw32'range), wcsr(0));
              tval(j)      <= uext(lane(trace_result32'range), tval(0));
            else
              pc(j)        <= sext(lane(trace_pc'range) & '0', pc(0));
              wdata(j)     <= uext(lane(trace_result'range), wdata(0));
              fsd_hi(j)    <= (others => '0');
              wcsr(j)      <= uext(lane(trace_csrw'range), wcsr(0));
              tval(j)      <= uext(lane(trace_result'range), tval(0));
            end if;

            cfi(j)         <= lane(trace_cfi'low);

            wren(j)        <= rd_gen(ucinst) and lane(trace_valid);
            wren_f(j)      <= to_bit(i = fpu_lane and is_fpu_rd(ucinst)) and lane(trace_valid);
--            wcen(j)        <= to_bit(is_csr(ucinst)) and lane(trace_valid);
            trap(j)        <= lane(trace_exception);
          end loop;
          wcen             <= (others => '0');
          memen            <= (others => '0');
          if data(trace_lane0'low + trace_valid) = '1' then
            if data(trace_lane0'low + trace_xdata_v) = '1' then
              wcen(u2i(data(trace_swap))) <= '1';
            end if;
            if data(trace_lane1'low + trace_xdata_v) = '1' then
              memen(u2i(data(trace_swap))) <= '1';
            end if;
          end if;

          if data(trace_valid0) = '1' and data(trace_valid1) = '1' then
            dis_dual_issue <= uadd(dis_dual_issue, 2);
            dis_minstret   <= uadd(dis_minstret, 2);
          elsif data(trace_valid0) = '1' or data(trace_valid1) = '1' then
            dis_minstret   <= uadd(dis_minstret, 1);
          end if;
--          report "cause " & tost(cause(0)) & " " & tost(cause(1)) & " " & tost_bits(trap);

          cause            <= cause2wordx(cause_unpack(data(trace_cause'range), data(trace_irq)));
          wb_prv           <= data(trace_prv'range);
          wb_v             <= data(trace_v);
        end if;
      end if;
    end process;

    iw_gen: for i in lanes'range generate
      iw : entity grlib.cpu_disas
        generic map(
          disasg => disas
          )
        port map(
          clk         => clk,
          rstn        => rstn,
          dummy       => open,
          index       => hart,
          way         => way(i),
          ivalid      => disas_iv(i),
          inst        => inst(i),
          cinst       => cinst(i),
          comp        => comp(i),
          pc          => pc(i),
          wregen      => wren(i),
          wregdata    => wdata(i),
          fsd         => fsd(i),
          fsd_hi      => fsd_hi(i),
          wregen_f    => wren_f(i),
          memen       => memen(i),
          cfi         => cfi(i),
          wcsren      => wcen(i),
          wcsrdata    => wcsr(i),
          prv         => wb_prv,
          v           => wb_v,
          trap        => trap(i),
          cause       => cause,
          tval        => tval(i),
          cycle       => dis_mcycle,
          instret     => dis_minstret,
          dual        => dis_dual_issue,
          disas       => disas_en
          );
    end generate;

  end generate;

-- pragma translate_on

  syncrregs : if not ASYNC_RESET generate

    -- Sync Reg Process ---------------------------------------------------
    sync_reg : process (clk)
    begin
      if rising_edge(clk) then
        r                <= rin;

        -- Synchronous Reset
        if rstn = '0' then
          if RESET_ALL then
            r <= itrace_none;
          else
            if need_extra_sync_reset(fabtech) /= 0 then
            end if;
          end if;
        end if;
      end if;
    end process; -- sync_reg

  end generate; -- syncrregs

  asyncrregs : if ASYNC_RESET generate

    -- Async Reg Process --------------------------------------------------
    async_reg : process (clk, arst)
    begin
      if arst = '0' then
        r <= itrace_none;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;

  end generate;

end rtl;
