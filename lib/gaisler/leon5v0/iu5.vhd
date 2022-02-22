------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity:      iu5
-- File:        iu5.vhd
-- Author:      Alen Bardizbanyan, Cobham Gaisler AB
-- Based on:    LEON3/LEON4 pipeline by Jiri Gaisler and Edvin Catovic
-- Description: LEON5 7-stage dual-issue integer pipline
------------------------------------------------------------------------------





library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.sparc.all;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.leon5.all;
use gaisler.leon5int.all;
use gaisler.arith.all;
-- pragma translate_off
use grlib.sparc_disas.all;
-- pragma translate_on

entity iu5 is
  generic (
    nwin        : integer range 2 to 32;
    iways       : integer range 1 to 4;
    dways       : integer range 1 to 4;
    mulimpl     : integer range 0 to 63;
    cp          : integer range 0 to 1;
    nwp         : integer range 0 to 4;
    pclow       : integer range 0 to 2;
    index       : integer range 0 to 15;
    disas       : integer range 0 to 2;
    rstaddr     : integer;                -- reset vector MSB address
    fabtech     : integer range 0 to NTECH;
    scantest    : integer;
    memtech     : integer range 0 to NTECH;
    rfconf      : integer;
    cgen        : integer range 0 to 1
    );
  port (
    clk         : in  std_logic;
    uclk        : in  std_logic;
    rstn        : in  std_logic;
    holdn       : in  std_logic;
    ici         : out icache_in_type5;
    ico         : in  icache_out_type5;
    dci         : out dcache_in_type5;
    dco         : in  dcache_out_type5;
    rfi         : out iregfile_in_type5;
    rfo         : in  iregfile_out_type5;
    irqi        : in  l5_irq_in_type;
    irqo        : out l5_irq_out_type;
    dbgi        : in  l5_debug_in_type;
    dbgo        : out l5_debug_out_type;
    muli        : out mul32_in_type;
    mulo        : in  mul32_out_type;
    divi        : out div32_in_type;
    divo        : in  div32_out_type;
    fpu5o       : in  fpc5_out_type;
    fpu5i       : out fpc5_in_type;
    tpo         : out trace_port_out_type;
    tco         : in  trace_control_out_type; 
    fpc_retire  : in  std_logic;
    fpc_rfwen   : in  std_logic_vector(1 downto 0);
    fpc_rfwdata : in  std_logic_vector(63 downto 0);
    fpc_retid   : in  std_logic_vector(4 downto 0);
    testen      : in  std_logic;
    testrst     : in  std_logic;
    testin      : in std_logic_vector(TESTIN_WIDTH-1 downto 0);
    perf        : out std_logic_vector(63 downto 0)
    );


end;

architecture rtl of iu5 is

  constant v8       : integer := 16#32# + 4*mulimpl;
  constant fpu      : integer := 1;
  constant mac      : integer := 0;
  constant dsu      : integer := 1;
  constant notag    : integer := 0;
  constant lddel    : integer := 1;
  constant irfwt    : integer := 1;
  constant pwd      : integer := 2;
  constant svt      : integer := 0;
  constant smp      : integer := 1;
  constant clk2x    : integer := 0;
  constant npasi    : integer := 0;
  constant pwrpsr   : integer := 1;

  constant IWAYMSB  : integer                               := log2x(iways)-1;
  constant DWAYMSB  : integer                               := log2x(dways)-1;
  constant RFBITS   : integer range 6 to 10                 := log2(NWIN+1) + 4;
  constant NWINLOG2 : integer range 1 to 5                  := log2(NWIN);
  constant CWPOPT   : boolean                               := (NWIN = (2**NWINLOG2));
  constant CWPMIN   : std_logic_vector(NWINLOG2-1 downto 0) := (others => '0');
  constant CWPMAX   : std_logic_vector(NWINLOG2-1 downto 0) :=
    conv_std_logic_vector(NWIN-1, NWINLOG2);
  constant FPEN        : boolean                             := (fpu /= 0);
  constant CPEN        : boolean                             := (cp = 1);
  constant MULEN       : boolean                             := (v8 /= 0);
  constant MULTYPE     : integer                             := (v8 / 16);
  constant DIVEN       : boolean                             := (v8 /= 0);
  constant MACEN       : boolean                             := (mac = 1);
  constant MACPIPE     : boolean                             := (mac = 1) and (v8/2 = 1);
  constant IMPL        : integer                             := 15;
  constant VER         : integer                             := 5;
  constant DBGUNIT     : boolean                             := (dsu = 1);
  constant PWRD1       : boolean                             := false;  --(pwd = 1) and not (index /= 0);
  constant PWRD2       : boolean                             := pwd /= 0;  --(pwd = 2) or (index /= 0);
  constant DYNRST      : boolean                             := (rstaddr = 16#FFFFF#);
  constant RF_READHOLD : boolean                             := regfile_4p_infer(memtech) /= 0 or syncram_2p_readhold(memtech) /= 0;
  constant RF_ZERO     : std_logic_vector(RFBITS-1 downto 0) := (others => '0');
  constant DIV_LANE    : integer                             := 1;
  constant globals_v : std_logic_vector(RFBITS-5 downto 0) := conv_std_logic_vector(NWIN, RFBITS-4);
  

  signal BPRED       : std_logic;
  signal BLOCKBPMISS : std_logic;
  signal LATEALU     : std_logic;
  signal DLATEWICC   : std_logic;
  signal DLATEARITH  : std_logic;
  signal cpu_index   : std_logic_vector(3 downto 0);

  subtype word is std_logic_vector(31 downto 0);
  subtype word64 is std_logic_vector(63 downto 0);
  subtype pctype is std_logic_vector(31 downto 0);
  subtype rfatype is std_logic_vector(RFBITS downto 0);
  subtype cwptype is std_logic_vector(NWINLOG2-1 downto 0);
  type    icdtype is array (0 to iways-1) of word64;
  type    dcdtype is array (0 to dways-1) of word64;

  --LEON5--
  type inst_pair_type is array (0 to 1) of word;
  type reg_pair_type is array (0 to 1) of rfatype;
  type inst_pc_type is array (0 to 1) of std_logic_vector(31 downto 0);
  type imm_pair_type is array (0 to 1) of word;
  type operand_pair_type is array (0 to 1) of word;
  type aluop_pair_type is array (0 to 1) of std_logic_vector(2 downto 0);
  type alusel_pair_type is array (0 to 1) of std_logic_vector(1 downto 0);
  type shcnt_pair_type is array (0 to 1) of std_logic_vector(4 downto 0);
  type result_pair_type is array (0 to 1) of word;
  type cwp_pair_type is array (0 to 1) of cwptype;
  type reg_short_pair_type is array (0 to 1) of std_logic_vector(4 downto 0);
  type ex_add_pair_type is array (0 to 1) of std_logic_vector(32 downto 0);
  type icc_pair_type is array (0 to 1) of std_logic_vector(3 downto 0);
  type op_array is array (0 to 1) of std_logic_vector(1 downto 0);
  type op2_array is array (0 to 1) of std_logic_vector(2 downto 0);
  type op3_array is array (0 to 1) of std_logic_vector(5 downto 0);
  type pccomp_type is array (0 to 1) of std_logic_vector(3 downto 0);
  type hissue_type_counter_type is array (0 to 31) of std_logic_vector(31 downto 0);
  type wb_data_type is array (0 to 1) of std_logic_vector(63 downto 0);
  type we_data_type is array (0 to 1) of std_logic_vector(1 downto 0);
  type rf_wa_data_type is array (0 to 1) of std_logic_vector(9 downto 0);
  type tt_array_type is array (0 to 1) of std_logic_vector(5 downto 0);

  type exception_state is (run, trap, dsu1, dsu2, run_pre, dsu3, dsu4, unpcti_repeat
                           );

  signal hold_issue_s     : std_logic;
  signal waiting_ficc_s   : std_logic;
  signal atomic_nullify_s : std_logic;
  signal mul_lane_s       : std_logic;
  signal ex_logic_res1_s  : std_logic_vector(31 downto 0);
  signal exc_logic_res1_s : std_logic_vector(31 downto 0);
  signal ex_add_res1_s    : std_logic_vector(31 downto 0);
  signal exc_add_res1_s   : std_logic_vector(31 downto 0);
  signal exc_res0_s       : std_logic_vector(31 downto 0);
  signal exc_res1_s       : std_logic_vector(31 downto 0);
  signal btb_diag_in      : l5_btb_diag_in_type;
  signal btb_diag_out     : l5_btb_diag_out_type;
  signal bht_diag_in      : l5_btb_diag_in_type;
  signal bht_diag_out     : l5_btb_diag_out_type;

  signal xc_trapl_dbg                : std_logic;
  signal xc_trap_dbg                 : std_logic;
  signal mask_we_dbg                 : std_logic_vector(1 downto 0);
  signal rfi_wdata1_dbg              : std_logic_vector(63 downto 0);
  signal rfi_wdata2_dbg              : std_logic_vector(63 downto 0);

  type dc_in_type is record
    signed, enaddr, read, write, lock , dsuen : std_logic;
    size                                      : std_logic_vector(1 downto 0);
    asi                                       : std_logic_vector(7 downto 0);
  end record;

  constant dc_in_none : dc_in_type := (
    signed => '0',
    enaddr => '0',
    read   => '0',
    write  => '0',
    lock   => '0',
    dsuen  => '0',
    size   => (others => '0'),
    asi    => (others => '0'));

  type pipeline_ctrl_type is record
    pc            : pctype;
    inst_pc       : inst_pc_type;
    inst          : inst_pair_type;
    branch        : std_logic_vector(1 downto 0);
    br_taken      : std_logic;
    br_dual_ld    : std_logic;
    br_missp      : std_logic;
    delay_slot    : std_logic_vector(1 downto 0);
    rd            : reg_pair_type;
    rdw           : std_logic_vector(1 downto 0);
    ldd_z         : std_logic;
    tt            : tt_array_type;
    trap          : std_logic_vector(1 downto 0);
    wicc          : std_logic;
    wicc_dexc     : std_logic;          --wicc delayed to exception
    wicc_dmem     : std_logic;          --wicc delayed to mem
    wicc_muldiv   : std_logic;
    wy            : std_logic_vector(1 downto 0);
    alu_dexc      : std_logic_vector(1 downto 0);  --alu operation delayed to exception
    lalu_s1       : std_logic_vector(1 downto 0);
    inst_valid    : std_logic_vector(1 downto 0);
    delay_inst    : std_logic_vector(1 downto 0);
    delay_annuled : std_logic_vector(1 downto 0);
    swap          : std_logic;
    rett_op       : std_logic;
    jmpl_op       : std_logic;
    cwp_prev      : cwptype;
    cwp_annuled   : std_logic;
    cwp_annul_val : cwptype;
    cwp_update    : std_logic;
    cwp_updatel   : std_logic;
    bht_data      : std_logic_vector(1 downto 0);
    --used when two instructions write to same register,
    --the old instruction is marked as no forward
    --remove no_forward if one instruction in the pair gets annuled
    --means there was abranch missprediction and no forward is now valid
    --similar applies to delay_annuled
    no_forward    : std_logic_vector(1 downto 0);
    ctx_switch    : std_logic;
    spec_access   : std_logic_vector(1 downto 0);
    unpcti        : std_logic_vector(1 downto 0);
    --statistics
    dual_issued   : std_logic;
    btb_miss      : std_logic;
    mexc          : std_logic;
    single_issue  : std_logic;
  end record;

  type alu_ctrl_type is record
    --ALU operations no reset is needed
    aluop          : aluop_pair_type;               -- Alu operation
    alusel         : alusel_pair_type;              -- Alu result select
    aluadd         : std_logic_vector(1 downto 0);
    alucin         : std_logic_vector(1 downto 0);
    invop2         : std_logic_vector(1 downto 0);  --v
    shcnt          : shcnt_pair_type;               -- shift count
    sari           : std_logic_vector(1 downto 0);  --v
    shleft         : std_logic_vector(1 downto 0);  --v;
    use_sethi      : std_logic_vector(1 downto 0);
    use_logic      : std_logic_vector(1 downto 0);
    use_addsub     : std_logic_vector(1 downto 0);
    use_logicshift : std_logic;
  end record;

  type bht_ctrl_type is record
    br_miss_pc    : std_logic_vector(31 downto 0);
    pc_delay_slot : std_logic_vector(31 downto 0);  --this is needed when bicc,a
                                                    --gets a trap
    bhistory      : std_logic_vector(4 downto 0);
    phistory      : std_logic_vector(31 downto 0);
    btb_taken     : std_logic;
  end record;

  type fpc_ctrl_type is record
    opid       : std_logic_vector(4 downto 0);
    issued     : std_logic;
    issue_lane : std_logic;
    trap_fp    : std_logic;
    illegal_fp : std_logic;
    spstore    : std_logic;
  end record;

  constant pc_zero  : pctype := (others => '0');
  constant pc_reset : pctype := conv_std_logic_vector(rstaddr, 20) & pc_zero(11 downto pc_zero'low);
  constant ir_reset : pctype := pc_reset(31 downto 3) & "100";

  constant pipeline_ctrl_none : pipeline_ctrl_type := (
    pc            => pc_reset,
    inst_pc       => (others => (others => '0')),
    inst          => (others => (others => '0')),
    branch        => "00",
    br_taken      => '0',
    br_dual_ld    => '0',
    br_missp      => '0',
    delay_slot    => "00",
    rd            => (others => (others => '0')),
    rdw           => "00",
    ldd_z         => '0',
    tt            => (others => (others => '0')),
    trap          => "00",
    wicc          => '0',
    wicc_dexc     => '0',
    wicc_dmem     => '0',
    wicc_muldiv   => '0',
    wy            => "00",
    alu_dexc      => "00",
    lalu_s1       => "00",
    inst_valid    => "00",
    delay_inst    => "00",
    delay_annuled => "00",
    swap          => '0',
    rett_op       => '0',
    jmpl_op       => '0',
    cwp_prev      => (others => '0'),
    cwp_annuled   => '0',
    cwp_annul_val => (others => '0'),
    cwp_update    => '0',
    cwp_updatel   => '0',
    bht_data      => "00",
    no_forward    => "00",
    ctx_switch    => '0',
    spec_access   => "00",
    unpcti        => "00",
    dual_issued   => '0',
    btb_miss      => '0',
    mexc          => '0',
    single_issue  => '0'
    );

  

  type fetch_reg_type is record
    valid   : std_logic;
    pc      : pctype;
    bht_pc  : pctype;
    bht_pc2 : pctype;
    btb_pc  : pctype;
  end record;

  --Control of Transfer state
  --toc_d <-- previous toc was taken in decode stage
  --toc_a <-- previous toc is going to be taken in access stage
  --toc_e <-- previous toc is going to be taken in execute stage
  type ct_state_type is (idle, toc_d, toc_e);
  type iudiag_state is (idle, btb_rw, bht_rw_c0, bht_rw_c1, bht_rw_c2);

  type decode_reg_type is record
    pc                      : pctype;
    ct_state                : ct_state_type;
    br_cond                 : std_logic;  --to detect unpreditable cti couples
    inst                    : icdtype;
    inst_pc                 : inst_pc_type;                  --
    inst_valid              : std_logic_vector(1 downto 0);  --
    rett_op_delayed         : std_logic;
    hold_only_pcreg         : std_logic;
    cwp                     : cwptype;
    way                     : std_logic_vector(IWAYMSB downto 0);
    mexc                    : std_logic;
    delay_slot              : std_logic;
    delay_slot_annuled      : std_logic;
    bht_taken               : std_logic;
    bht_data                : std_logic_vector(1 downto 0);
    btb_hit                 : std_logic;
    b2bstore_en             : std_logic;
    specload_en             : std_logic;
    dual_ldissue_en         : std_logic;
    br_flush                : std_logic;
    pc_reset                : std_logic;
    speculative_insts       : std_logic;
    speculative_lock        : std_logic;
    ico_bpmiss              : std_logic;
    br_counting             : std_logic;
    --
    bht_ctrl                : bht_ctrl_type;
    fpc_ctrl                : fpc_ctrl_type;
    fpc_issued              : std_logic;
    fpc_annuled             : std_logic;
    fp_stdata_latched       : std_logic;
    fpustdata               : std_logic_vector(63 downto 0);
    iudiag_miso             : l5_intreg_miso_type;
    diag_btb_flush          : std_logic;
    diag_bht_flush          : std_logic;
    iudiags                 : iudiag_state;
    btb_diag_in             : l5_btb_diag_in_type;
    btb_diag_out            : l5_btb_diag_out_type;
    bht_diag_in_en          : std_logic;
    bht_diag_in_wren        : std_logic;
    --DEBUG
    holdn_deadlock_counter  : std_logic_vector(19 downto 0);
    fpc_deadlock_counter    : std_logic_vector(19 downto 0);
    hissue_deadlock_counter : std_logic_vector(19 downto 0);
  end record;

  type atomic_state is (idle, count, ld_exe, ld_mem, ld_exc);

  type regacc_reg_type is record
    ctrl                : pipeline_ctrl_type;
    rs1, rs2            : reg_pair_type;
    rs3                 : std_logic_vector(RFBITS downto 0);
    cwp                 : cwptype;
    imm                 : imm_pair_type;
    su                  : std_logic;
    et                  : std_logic;
    wovf                : std_logic_vector(1 downto 0);
    wunf                : std_logic_vector(1 downto 0);
    ticc                : std_logic;
    jmpl                : std_logic;
    mulstart            : std_logic;
    divstart            : std_logic;
    mul_lane            : std_logic;    --
    div_lane            : std_logic;
    use_sethi           : std_logic_vector(1 downto 0);
    use_logic           : std_logic_vector(1 downto 0);
    use_addsub          : std_logic_vector(1 downto 0);
    use_memaddr_add1    : std_logic;
    use_logicshift      : std_logic;
    rs3_ra2u            : std_logic;
    rs3_ra3u            : std_logic;
    rs3_ra4u            : std_logic;
    astate              : atomic_state;
    atomic_cnt          : std_logic_vector(1 downto 0);
    call_op             : std_logic_vector(1 downto 0);
    casa                : std_logic;
    atomic_nullified    : std_logic;
    e_annul_align4      : std_logic_vector(1 downto 0);
    e_cond_annul_align4 : std_logic_vector(1 downto 0);
    e_cancel_annul      : std_logic_vector(1 downto 0);
    call_lane           : std_logic;
    bp_disabled         : std_logic;
    spec_check          : std_logic_vector(1 downto 0);
    bht_ctrl            : bht_ctrl_type;
    fpc_ctrl            : fpc_ctrl_type;
    fpustdata           : std_logic_vector(63 downto 0);
    fp_stdata_latched   : std_logic;
  end record;

  type execute_reg_type is record
    ctrl                : pipeline_ctrl_type;
    rs1, rs2            : reg_pair_type;
    rs3                 : std_logic_vector(RFBITS downto 0);
    ex_op1              : operand_pair_type;
    ex_op2              : operand_pair_type;
    ymsb                : std_logic_vector(1 downto 0);  --v                           -- shift left/right
    rd                  : std_logic_vector(4 downto 0);
    jmpl_taddr          : std_logic_vector(31 downto 0);
    jmpl                : std_logic;
    su                  : std_logic;
    et                  : std_logic;
    cwp                 : cwptype;
    icc                 : std_logic_vector(3 downto 0);
    mulstep             : std_logic_vector(1 downto 0);  --v
    mul                 : std_logic_vector(1 downto 0);  --v
    mac                 : std_logic_vector(1 downto 0);  --v
    ldfwd_rs1           : std_logic_vector(1 downto 0);
    ldfwd_rs2           : std_logic_vector(1 downto 0);
    mul_lane            : std_logic;                     --
    div_lane            : std_logic;
    use_muldiv_rs1      : std_logic_vector(1 downto 0);
    use_muldiv_rs2      : std_logic_vector(1 downto 0);
    mul_op1             : std_logic_vector(31 downto 0);
    mul_op2             : std_logic_vector(31 downto 0);
    mul_sign            : std_logic;
    ldfwd_tomul_rs1     : std_logic;
    ldfwd_tomul_rs2     : std_logic;
    mul_rs10            : std_logic;
    mul_rs20            : std_logic;
    use_memaddr_add1    : std_logic;
    iustdata            : std_logic_vector(63 downto 0);
    alu_ctrl            : alu_ctrl_type;
    call_op             : std_logic_vector(1 downto 0);
    e_annul_align4      : std_logic_vector(1 downto 0);
    e_cond_annul_align4 : std_logic_vector(1 downto 0);
    e_cancel_annul      : std_logic_vector(1 downto 0);
    call_lane           : std_logic;
    atomic_trapped      : std_logic;
    bht_ctrl            : bht_ctrl_type;
    fpc_ctrl            : fpc_ctrl_type;
    casa_asiA           : std_logic;
    itrhit              : std_logic_vector(1 downto 0);
  end record;

  type memory_reg_type is record
    ctrl                : pipeline_ctrl_type;
    rs1, rs2            : reg_pair_type;
    rs3                 : std_logic_vector(RFBITS downto 0);
    result              : result_pair_type;
    y                   : word;
    icc                 : std_logic_vector(3 downto 0);
    icc_dannul          : std_logic_vector(3 downto 0);
    nalign              : std_logic;
    dci                 : dc_in_type;
    werr                : std_logic;
    wcwp                : std_logic_vector(1 downto 0);
    irqen               : std_logic;
    irqen2              : std_logic;
    mac                 : std_logic;
    divz                : std_logic;
    su                  : std_logic;
    mul                 : std_logic;
    fpdata              : std_logic_vector(63 downto 0);
    iustdata            : std_logic_vector(63 downto 0);
    casz                : std_logic;
    itrhit              : std_logic_vector(1 downto 0);
    jmpl_taddr          : std_logic_vector(31 downto 0);
    alu_op1             : operand_pair_type;
    alu_op2             : operand_pair_type;
    late_wicc_rs1       : rfatype;
    late_wicc_rs2       : rfatype;
    late_wicc_op1_ldfwd : std_logic;
    late_wicc_op2_ldfwd : std_logic;
    late_wicc_op1_lalu0 : std_logic;
    late_wicc_op1_lalu1 : std_logic;
    late_wicc_op2_lalu0 : std_logic;
    late_wicc_op2_lalu1 : std_logic;
    lalu0_ldfwd_rs1     : std_logic;
    lalu0_ldfwd_rs2     : std_logic;
    lalu0_wb0fwd_rs1    : std_logic;
    lalu0_wb0fwd_rs2    : std_logic;
    lalu0_wb1fwd_rs1    : std_logic;
    lalu0_wb1fwd_rs2    : std_logic;
    --1->(63 downto 32) 
    mem_data_alu1       : std_logic_vector(1 downto 0);
    -->1&H(63 downto 32)
    mem_data_xdataH     : std_logic_vector(1 downto 0);
    --1->(63 downto 32)   L->(31 downto 0)
    mem_data_xdataL     : std_logic_vector(1 downto 0);
    --1->(63 downto 32)
    mem_data_xresult0   : std_logic_vector(1 downto 0);
    mem_data_lalu0      : std_logic_vector(1 downto 0);
    mem_data_lalu1      : std_logic_vector(1 downto 0);
    alu_ctrl            : alu_ctrl_type;
    bht_ctrl            : bht_ctrl_type;
    fpc_ctrl            : fpc_ctrl_type;
    dc_nullify          : std_logic;
  end record;

  type exception_reg_type is record
    ctrl                : pipeline_ctrl_type;
    rs1, rs2            : reg_pair_type;
    rs3                 : std_logic_vector(RFBITS downto 0);
    result              : result_pair_type;
    y                   : word;
    icc                 : std_logic_vector(3 downto 0);
    icc_dannul          : std_logic_vector(3 downto 0);
    annul_all           : std_logic;
    data                : dcdtype;
    way                 : std_logic_vector(DWAYMSB downto 0);
    mexc                : std_logic;
    dci                 : dc_in_type;
    laddr               : std_logic_vector(2 downto 0);
    rstate              : exception_state;
    cpustate            : std_logic_vector(1 downto 0);
    captcmd_ack         : std_ulogic;
    npc                 : std_logic_vector(31 downto 0);
    intack              : std_logic;
    ipend               : std_logic;
    mac                 : std_logic;
    debug               : std_logic;
    nerror              : std_logic;
    ldd                 : std_logic;
    alu_op1             : operand_pair_type;
    alu_op2             : operand_pair_type;
    ldfwd               : alusel_pair_type;
    multfwd             : alusel_pair_type;
    late_wicc_op1       : std_logic_vector(31 downto 0);
    late_wicc_op2       : std_logic_vector(31 downto 0);
    late_wicc_rs1       : rfatype;
    late_wicc_rs2       : rfatype;
    late_wicc_op1_ldfwd : std_logic;
    late_wicc_op2_ldfwd : std_logic;
    late_wicc_alucin    : std_logic;
    late_wicc_aluop     : std_logic_vector(2 downto 0);
    late_wicc_aluadd    : std_logic;
    late_wicc_alusel    : std_logic_vector(1 downto 0);
    late_wicc_invop2    : std_logic;
    icc_prev            : std_logic_vector(3 downto 0);
    wicc_prev_lateld    : std_logic;
    update_late_dannul  : std_logic;
    muldiv_result       : std_logic_vector(31 downto 0);
    trapl               : std_logic;
    debug_ret           : std_logic;
    debug_ret2          : std_logic;
    speculative_load    : std_logic;
    xc_ld_replay        : std_logic;
    alu_ctrl            : alu_ctrl_type;
    storedata           : std_logic_vector(63 downto 0);
    bht_ctrl            : bht_ctrl_type;
    fpc_ctrl            : fpc_ctrl_type;
    miso                : l5_intreg_miso_type;
    ret_sleep           : std_logic;
    tt_ticc             : std_logic;
    itrhit              : std_logic_vector(1 downto 0);
  end record;

  type dsu_registers is record
    tt      : std_logic_vector(7 downto 0);
    -- err     : std_logic;
    brktype : std_logic_vector(1 downto 0);
    asi     : std_logic_vector(7 downto 0);
    asihiad : std_logic_vector(31 downto 19);
    crdy    : std_logic_vector(2 downto 1);  -- diag cache access ready
    cfc     : std_logic_vector(6 downto 0);  -- control-flow change
  end record;

  type irestart_register is record
    addr : pctype;
    pwd  : std_logic;
  end record;

  type pwd_register_type is record
    idle  : std_ulogic;
    pwd   : std_logic;
    error : std_logic;
  end record;

  type special_register_type is record
    cwp             : cwptype;          -- current window pointer
    icc             : std_logic_vector(3 downto 0);  -- integer condition codes
    tt              : std_logic_vector(7 downto 0);  -- trap type
    tba             : std_logic_vector(19 downto 0);      -- trap base address
    wim             : std_logic_vector(NWIN-1 downto 0);  -- window invalid mask
    pil             : std_logic_vector(3 downto 0);  -- processor interrupt level
    ec              : std_logic;        -- enable CP
    ef              : std_logic;        -- enable FP
    ps              : std_logic;        -- previous supervisor flag
    s               : std_logic;        -- supervisor flag
    et              : std_logic;        -- enable traps
    y               : word;
    asr18           : word;
    svt             : std_logic;        -- enable traps
    dwt             : std_logic;        -- disable write error trap
    dbp             : std_logic;        -- disable branch prediction
    dbprepl         : std_logic;  -- Disable speculative Icache miss/replacement
    ducnt           : std_logic;        -- disable upcounter
    --dbg
    holdn_deadlock  : std_logic;
    fpc_deadlock    : std_logic;
    hissue_deadlock : std_logic;
  end record;

  type step_reg_type is record
    en      : std_logic;
    counter : std_logic_vector(31 downto 0);
    dbgm    : std_logic;
  end record;

  type write_reg_type is record
    s               : special_register_type;
    icc_dannul      : std_logic_vector(3 downto 0);
    except          : std_logic;
    rd              : reg_pair_type;
    wb_data         : wb_data_type;
    we              : we_data_type;
    waddr           : rf_wa_data_type;
    step            : step_reg_type;
    tdata           : std_logic_vector(383 downto 0);
    fp_exc_ack      : std_logic_vector(1 downto 0);
    tco             : trace_control_out_type; 
    fpu_unissue     : std_logic;
    fpu_unissue_sid : std_logic_vector(4 downto 0);
  end record;

  type registers is record
    f     : fetch_reg_type;
    d     : decode_reg_type;
    a     : regacc_reg_type;
    e     : execute_reg_type;
    m     : memory_reg_type;
    x     : exception_reg_type;
    w     : write_reg_type;
    perf  : std_logic_vector(63 downto 0);
  end record;

  type ungated_registers is record
    -- capture register for command from dbgmod if gated when
    -- command was received
    captcmd: std_logic_vector(2 downto 0);
  end record;

  type exception_type is record
    pri   : std_logic;
    ill   : std_logic;
    fpdis : std_logic;
    cpdis : std_logic;
    wovf  : std_logic;
    wunf  : std_logic;
    ticc  : std_logic;
  end record;

  type watchpoint_register is record
    addr  : std_logic_vector(31 downto 2);  -- watchpoint address
    mask  : std_logic_vector(31 downto 2);  -- watchpoint mask
    exec  : std_logic;                      -- trap on instruction
    load  : std_logic;                      -- trap on load
    store : std_logic;                      -- trap on store
  end record;

  type watchpoint_registers is array (0 to 3) of watchpoint_register;

  constant wpr_none : watchpoint_register := (
    zero32(31 downto 2), zero32(31 downto 2), '0', '0', '0');

  function dbgexc(
    lane : integer range 0 to 1; r : registers; dbgi : l5_debug_in_type;
    trap : std_logic; tt : std_logic_vector(7 downto 0);
    dsur : dsu_registers) return std_logic is
    variable dmode : std_logic;
  begin
    dmode := '0';
    if (r.x.ctrl.inst_valid(lane) and trap) = '1' then
      if (((tt = "00" & TT_WATCH) and (dbgi.bwatch = '1')) or
          ((dbgi.bsoft = '1') and (tt = "10000001")) or
          (dbgi.btrapa = '1') or
          ((dbgi.btrape = '1') and not ((tt(5 downto 0) = TT_PRIV) or
                                        (tt(5 downto 0) = TT_FPDIS) or (tt(5 downto 0) = TT_WINOF) or
                                        (tt(5 downto 0) = TT_WINUF) or (tt(5 downto 4) = "01") or (tt(7) = '1'))) or
          ((not r.w.s.et) = '1')) then
        dmode := '1';
      end if;
    end if;
    return(dmode);
  end;

  signal v_m : registers;
  
  function dbgerr(r : registers; dbgi : l5_debug_in_type;
  tt                : std_logic_vector(7 downto 0))
    return std_logic is
    variable err : std_logic;
  begin
    err := not r.w.s.et;
    if (((dbgi.cmd = CPUCMD_BREAK) and (tt = ("00" & TT_WATCH))) or
        ((dbgi.bsoft = '1') and (tt = ("10000001"))) or
        (r.w.step.dbgm = '1' and r.w.step.en = '1')             
        ) then
      err := '0';
    end if;
    return(err);
  end;

  procedure diagwr(r               : in  registers;
                   dsur            : in  dsu_registers;
                   ir              : in  irestart_register;
                   dbg             : in  l5_debug_in_type;
                   wpr             : in  watchpoint_registers;
                   s               : out special_register_type;
                   step            : out step_reg_type;
                   vwpr            : out watchpoint_registers;
                   asi             : out std_logic_vector(7 downto 0);
                   asihiad         : out std_logic_vector(31 downto 19);
                   pc, npc         : out pctype;
                   wr              : out std_logic;
                   addr            : out std_logic_vector(9 downto 0);
                   data            : out word;
                   fpcwr           : out std_logic;
                   b2bstore_en     : out std_logic;
                   specload_en     : out std_logic;
                   dual_ldissue_en : out std_logic;
                   br_flush        : out std_logic) is
    variable i    : integer range 0 to 3;
    variable area : std_logic_vector(2 downto 0);
  begin
    s               := r.w.s;
    step            := r.w.step;
    pc              := r.f.pc;
    npc             := ir.addr;
    wr              := '0';
    vwpr            := wpr;
    asi             := dsur.asi;
    asihiad         := dsur.asihiad;
    addr            := (others => '0');
    data            := dbg.mosi.wrdata;
    fpcwr           := '0';
    b2bstore_en     := r.d.b2bstore_en;
    specload_en     := r.d.specload_en;
    dual_ldissue_en := r.d.dual_ldissue_en;
    br_flush        := '0';
    area            := dbg.mosi.addr(21-2 downto 19-2);
    if (dbg.mosi.accen and dbg.mosi.accwr) = '1' then
      case area is
        when "011" =>                   -- IU reg file
          if dbg.mosi.addr(12-2) = '0' then
            wr                      := '1';
            addr                    := (others => '0');
            addr(RFBITS-1 downto 0) := dbg.mosi.addr(RFBITS+1-2 downto 2-2);
          else                          -- FPC
            fpcwr := '1';
          end if;
        when "100" =>                   -- IU special registers
          case dbg.mosi.addr(7-2 downto 6-2) is
            when "00" =>                -- IU regs Y
              case dbg.mosi.addr(5-2 downto 2-2) is
                when "0000" =>          -- Y
                  s.y := dbg.mosi.wrdata;
                when "0001" =>          -- PSR
                  s.cwp             := dbg.mosi.wrdata(NWINLOG2-1 downto 0);
                  s.icc             := dbg.mosi.wrdata(23 downto 20);
                  s.ec              := dbg.mosi.wrdata(13);
                  if FPEN then s.ef := dbg.mosi.wrdata(12); end if;
                  s.pil             := dbg.mosi.wrdata(11 downto 8);
                  s.s               := dbg.mosi.wrdata(7);
                  s.ps              := dbg.mosi.wrdata(6);
                  s.et              := dbg.mosi.wrdata(5);
                when "0010" =>          -- WIM
                  s.wim := dbg.mosi.wrdata(NWIN-1 downto 0);
                when "0011" =>          -- TBR
                  s.tba := dbg.mosi.wrdata(31 downto 12);
                  s.tt  := dbg.mosi.wrdata(11 downto 4);
                when "0100" =>          -- PC
                  pc := dbg.mosi.wrdata(31 downto PCLOW);
                when "0101" =>          -- NPC
                  npc := dbg.mosi.wrdata(31 downto PCLOW);
                when "0110" =>          --FSR
                  fpcwr := '1';
                when "0111" =>          --CFSR
                when "1001" =>          -- ASI reg
                  asi     := dbg.mosi.wrdata(7 downto 0);
                  asihiad := dbg.mosi.wrdata(23 downto 11);
                when others =>
              end case;
            when "01" =>                -- ASR16 - ASR31
              case dbg.mosi.addr(5-2 downto 2-2) is
                when "0001" =>          -- %ASR17
                  s.dbp          := dbg.mosi.wrdata(27);
                  s.dbprepl      := dbg.mosi.wrdata(25);
                  s.dwt          := dbg.mosi.wrdata(14);
                  s.svt          := dbg.mosi.wrdata(13);
                when "0010" =>          -- %ASR18
                  if MACEN then s.asr18 := dbg.mosi.wrdata; end if;
                when "0110" =>          -- %ASR22
                  s.ducnt := dbg.mosi.wrdata(31);
                when "1000" =>          -- %ASR24 - %ASR31
                  vwpr(0).addr := dbg.mosi.wrdata(31 downto 2);
                  vwpr(0).exec := dbg.mosi.wrdata(0);
                when "1001" =>
                  vwpr(0).mask  := dbg.mosi.wrdata(31 downto 2);
                  vwpr(0).load  := dbg.mosi.wrdata(1);
                  vwpr(0).store := dbg.mosi.wrdata(0);
                when "1010" =>
                  vwpr(1).addr := dbg.mosi.wrdata(31 downto 2);
                  vwpr(1).exec := dbg.mosi.wrdata(0);
                when "1011" =>
                  vwpr(1).mask  := dbg.mosi.wrdata(31 downto 2);
                  vwpr(1).load  := dbg.mosi.wrdata(1);
                  vwpr(1).store := dbg.mosi.wrdata(0);
                when "1100" =>
                  vwpr(2).addr := dbg.mosi.wrdata(31 downto 2);
                  vwpr(2).exec := dbg.mosi.wrdata(0);
                when "1101" =>
                  vwpr(2).mask  := dbg.mosi.wrdata(31 downto 2);
                  vwpr(2).load  := dbg.mosi.wrdata(1);
                  vwpr(2).store := dbg.mosi.wrdata(0);
                when "1110" =>
                  vwpr(3).addr := dbg.mosi.wrdata(31 downto 2);
                  vwpr(3).exec := dbg.mosi.wrdata(0);
                when "1111" =>          --
                  vwpr(3).mask  := dbg.mosi.wrdata(31 downto 2);
                  vwpr(3).load  := dbg.mosi.wrdata(1);
                  vwpr(3).store := dbg.mosi.wrdata(0);
                when others =>          --
              end case;
            when "10" =>                --special control register
              b2bstore_en     := dbg.mosi.wrdata(3);
              specload_en     := dbg.mosi.wrdata(4);
              dual_ldissue_en := dbg.mosi.wrdata(5);
            when "11" =>
              br_flush := dbg.mosi.wrdata(0);
            when others =>
          end case;
        when "101" =>                   --step 
          case dbg.mosi.addr(5-2 downto 2-2) is
            when "0000" =>
              --  0x500000
              step.en := dbg.mosi.wrdata(0);
            when "0001" =>
              --  0x500004
              step.counter := dbg.mosi.wrdata;
            when others =>
              null;
          end case;
        when "110" =>                   --dbg deadlock
          s.fpc_deadlock    := dbg.mosi.wrdata(0);
          s.holdn_deadlock  := dbg.mosi.wrdata(1);
          s.hissue_deadlock := dbg.mosi.wrdata(2);
        when others =>
      end case;
    end if;
  end;

  function asr17_gen (r : in registers; cpi : std_logic_vector) return word is
    variable asr17 : word;
    variable fpu2  : integer range 0 to 3;
  begin
    asr17               := zero32;
    asr17(31 downto 28) := cpi;
    asr17(24 downto 23) := "00";
    if (clk2x > 8) then
      asr17(16 downto 15) := conv_std_logic_vector(clk2x-8, 2);
      asr17(17)           := '1';
    elsif (clk2x > 0) then
      asr17(16 downto 15) := conv_std_logic_vector(clk2x, 2);
    end if;
    asr17(27)                   := r.w.s.dbp;
    asr17(25)                   := r.w.s.dbprepl;
    asr17(14)                   := r.w.s.dwt;
    --
    if svt = 1 then asr17(13)   := r.w.s.svt; end if;
    if lddel = 2 then asr17(12) := '1'; end if;
    if (fpu > 0) and (fpu < 8) then
      fpu2 := 1;
    elsif (fpu >= 8) and (fpu < 15) then
      fpu2 := 3;
    elsif fpu = 15 then
      fpu2 := 2;
    else
      fpu2 := 0;
    end if;
    asr17(11 downto 10)      := conv_std_logic_vector(fpu2, 2);
    if mac = 1 then asr17(9) := '1'; end if;
    if v8 /= 0 then asr17(8) := '1'; end if;
    asr17(7 downto 5)        := conv_std_logic_vector(nwp, 3);
    asr17(4 downto 0)        := conv_std_logic_vector(nwin-1, 5);
    return(asr17);
  end;


  procedure diagread(dbgi : in  l5_debug_in_type;
                     r    : in  registers;
                     dsur : in  dsu_registers;
                     ir   : in  irestart_register;
                     wpr  : in  watchpoint_registers;
                     dco  : in  dcache_out_type5;
                     data : out word) is
    variable cwp  : std_logic_vector(4 downto 0);
    variable rd   : std_logic_vector(4 downto 0);
    variable i    : integer range 0 to 3;
    variable area : std_logic_vector(2 downto 0);
  begin
    data                     := (others => '0'); cwp := (others => '0');
    cwp(NWINLOG2-1 downto 0) := r.w.s.cwp;
    area                     := dbgi.mosi.addr(21-2 downto 19-2);
    case area is
      when "011" =>                     -- IU reg file
        if dbgi.mosi.addr(12-2) = '0' then
          if dbgi.mosi.addr(2-2) = '0' then
            data := rfo.rdata1(63 downto 32);
          else
            data := rfo.rdata1(31 downto 0);
          end if;
          if (dbgi.mosi.addr(11-2) = '1') and (is_fpga(fabtech) = 0) then
            if dbgi.mosi.addr(2-2) = '0' then
              data := rfo.rdata2(63 downto 32);
            else
              data := rfo.rdata2(31 downto 0);
            end if;
          end if;
        else
          data := (others => '0');      -- fpo.dbg.data;
        end if;
      when "100" =>                     -- IU regs
        case dbgi.mosi.addr(7-2 downto 6-2) is
          when "00" =>                  -- IU regs Y
            case dbgi.mosi.addr(5-2 downto 2-2) is
              when "0000" =>
                data := r.w.s.y;
              when "0001" =>
                data := conv_std_logic_vector(IMPL, 4) & conv_std_logic_vector(VER, 4) &
                        r.w.s.icc & "000000" & r.w.s.ec & r.w.s.ef & r.w.s.pil &
                        r.w.s.s & r.w.s.ps & r.w.s.et & cwp;
              when "0010" =>
                data(NWIN-1 downto 0) := r.w.s.wim;
              when "0011" =>
                data := r.w.s.tba & r.w.s.tt & "0000";
              when "0100" =>
                data(31 downto PCLOW) := r.f.pc;
              when "0101" =>
                data(31 downto PCLOW) := ir.addr;
              when "0110" =>            -- FSR
                data := fpu5o.dbgfsr;
              when "0111" =>            -- CPSR
              when "1000" =>            -- TT reg
                data(14 downto 13) := dsur.brktype;
                data(12 downto 4)  := r.x.cpustate(1) & dsur.tt;
              when "1001" =>            -- ASI reg
                data(23 downto 11) := dsur.asihiad(31 downto 19);
                data(7 downto 0)   := dsur.asi;
              when others =>
            end case;
          when "01" =>
            if dbgi.mosi.addr(5-2) = '0' then                    -- %ASR17
              if dbgi.mosi.addr(4-2 downto 2-2) = "001" then     -- %ASR17
                data := asr17_gen(r, cpu_index);
              elsif MACEN and dbgi.mosi.addr(4-2 downto 2-2) = "010" then  -- %ASR18
                data := r.w.s.asr18;
              elsif dbgi.mosi.addr(4-2 downto 2-2) = "110" then  -- %ASR22
                data(31) := r.w.s.ducnt;
              end if;
            else                        -- %ASR24 - %ASR31
              i := conv_integer(dbgi.mosi.addr(4-2 downto 3-2));           --
              if dbgi.mosi.addr(2-2) = '0' then
                data(31 downto 2) := wpr(i).addr;
                data(0)           := wpr(i).exec;
              else
                data(31 downto 2) := wpr(i).mask;
                data(1)           := wpr(i).load;
                data(0)           := wpr(i).store;
              end if;
            end if;
          when "10" =>                  --special control register
            data(3) := r.d.b2bstore_en;
            data(4) := r.d.specload_en;
            data(5) := r.d.dual_ldissue_en;
          when "11"   =>
            --if dbgi.mosi.addr(4-2 downto 2-2) = "000" then
            --  data := r.d.icomds_counter;
            --elsif dbgi.mosi.addr(4-2 downto 2-2) = "001" then
            --  data := r.d.dcomds_counter;
            --elsif dbgi.mosi.addr(4-2 downto 2-2) = "010" then
            --  data := r.d.hold_counter;
            --elsif dbgi.mosi.addr(4-2 downto 2-2) = "011" then
            --  data := r.d.branch_miss_counter;
            --elsif dbgi.mosi.addr(4-2 downto 2-2) = "100" then
            --  data := r.d.hissue_counter;
            --elsif dbgi.mosi.addr(4-2 downto 2-2) = "101" then
            --  data := r.d.tcycle_counter;
            --elsif dbgi.mosi.addr(4-2 downto 2-2) = "110" then
            --  data := r.d.tinst_counter;
            --else
            --  data := r.d.tdual_counter;
            --end if;              
          when others =>
        end case;
      when "101" =>
        case dbgi.mosi.addr(5-2 downto 2-2) is
          when "0000" =>
            data(0) := r.w.step.en;
          when "0001" =>
            data := r.w.step.counter;
          when others =>
            null;
        end case;
      when "110" =>
        data(0) := r.w.s.fpc_deadlock;
        data(1) := r.w.s.holdn_deadlock;
        data(2) := r.w.s.hissue_deadlock;
      when "111" =>
        if dbgi.mosi.addr(2-2) = '0' then
          data := r.x.data(conv_integer(r.x.way))(63 downto 32);
        else
          data := r.x.data(conv_integer(r.x.way))(31 downto 0);
        end if;
      when others =>
    end case;
  end;
  
  --PC comparison hardware 
  procedure pccompare (lane   : in  integer range 0 to 1;
                       r      : in  registers;
                       wpr    : in  watchpoint_registers;
                       pccomp : out std_logic_vector(3 downto 0)) is
  begin
    pccomp := (others => '0');

    for i in 1 to NWP loop
      if (((wpr(i-1).addr xor r.a.ctrl.inst_pc(lane)(31 downto 2)) and wpr(i-1).mask) = Zero32(31 downto 2)) then
        pccomp(i-1) := '1';
      end if;
    end loop;

  end;

  --itrace filtering
  function itrhitc(r: registers;pccomp : std_logic_vector(3 downto 0))
    return std_logic is
    variable hit : std_logic;
    variable temp_hit_inc_array : std_logic_vector(NWP downto 0);
    variable temp_hit_exc_array : std_logic_vector(NWP downto 0);
    variable temp_hit_array : std_logic_vector(NWP downto 0);
  begin
    
    temp_hit_inc_array := ( others => '0' );
    temp_hit_exc_array := ( others => '0' );
    temp_hit_array := ( others => '0' );

    for i in 1 to NWP loop
      if (r.w.tco.addr_f(i-1) = '1') then
        if (pccomp(i-1) = '1') then 
          if (r.w.tco.addr_f_p(i-1)) = '0' then
            temp_hit_inc_array(i) := '1';
          end if;
        else
          if (r.w.tco.addr_f_p(i-1)) = '1' then
            temp_hit_exc_array(i) := '1';
          end if;
        end if;
      else
        --if there is no filter set it should be a hit
        temp_hit_inc_array(i) := '1';
        temp_hit_exc_array(i) := '1';
      end if;
    end loop;

    --combine the filter result
    temp_hit_array(0) := '1';
    for i in 1 to NWP loop
      temp_hit_array(i) := temp_hit_array(i-1) and (temp_hit_inc_array(i) or temp_hit_exc_array(i));
    end loop;
    
    hit := temp_hit_array(NWP);

    
    return(hit);

  end;
  

  function is_ldst(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "11" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_load(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "11" and inst(21) = '0' then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_fpop(inst : word) return std_logic is
    variable ret : std_logic;
    variable op3 : std_logic_vector(5 downto 0);
  begin

    ret := '0';
    op3 := inst(24 downto 19);

    if inst(31 downto 30) = "10" then
      --fpop1/fpop2
      if op3(5 downto 1) = "11010" then
        ret := '1';
      end if;
    end if;

    if inst(31 downto 30) = "11" then
      if op3 = STF or op3 = STDF or op3 = STFSR or op3 = STDFQ then
        ret := '1';
      end if;

      if op3 = LDF or op3 = LDDF or op3 = LDFSR then
        ret := '1';
      end if;
    end if;

    return ret;
  end;

  function is_atomic(inst : word) return std_logic is
    variable ret : std_logic;
  begin
    ret := '0';
    if inst(31 downto 30) = "11" then
      if inst(24 downto 19) = SWAP or inst(24 downto 19) = SWAPA or
        inst(24 downto 19) = LDSTUB or inst(24 downto 19) = LDSTUBA or
        inst(24 downto 19) = CASA then
        ret := '1';
      end if;
    end if;
    return ret;
  end;

  function is_pwd(inst : word) return std_logic is
    variable ret : std_logic;
  begin
    ret := '0';
    if inst(31 downto 30) = FMT3 and inst(24 downto 19) = WRY and inst(29 downto 25) = "10011" then
      ret := '1';
    end if;
    return ret;
  end;

  function is_store(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "11" and inst(21) = '1' and is_atomic(inst) = '0' then
      return '1';
    else
      return '0';
    end if;
  end;

  function itfilt(inst : word; filter : std_logic_vector(3 downto 0); trap : std_logic)
    return std_logic is
    variable hit : std_logic;
  begin
    hit := '0';
    case filter is
      when "0001" => 	-- Bicc, SETHI
        if inst(31 downto 30) = "00" then
          hit := '1';
        end if;
      when "0010" => 	-- Control-flow change
        if (inst(31 downto 30) = "01") -- Call
          or ((inst(31 downto 30) = "00") and (inst(23 downto 22) /= "00")) --Bicc
          or ((inst(31 downto 30) = "10") and (inst(24 downto 19) = JMPL)) --Jmpl
          or ((inst(31 downto 30) = "10") and (inst(24 downto 19) = RETT)) --Rett
          or (trap = '1') then
          hit := '1';
        end if;
      when "0100" => 	-- Call
        if inst(31 downto 30) = "01" then
          hit := '1';
        end if;
      when "1000" => 	-- Normal instructions
        if inst(31 downto 30) = "10" then
          hit := '1';
        end if;
      when "1100" => 	-- LDST
        if inst(31 downto 30) = "11" then
          hit := '1';
        end if;
      when "1101" =>      -- LDST from alternate space
        if inst(31 downto 30) = "11" and inst(24 downto 23) = "01" then
          hit := '1';
        end if;
      when others =>
        hit := '1';
    end case;
    
    return hit;
  end;

  procedure itrace(r           : in  registers;
                   swap        : in  std_logic;
                   valid       : in  std_logic_vector(1 downto 0);
                   res_l0      : in  word;
                   res_l1      : in  word;
                   exc         : in  std_logic;
                   dbgi        : in  l5_debug_in_type;
                   error       : in  std_logic;
                   trap_l0     : in  std_logic;
                   trap_l1     : in  std_logic;
                   fpc_retire  : in  std_logic;
                   fpc_rfwen   : in  std_logic_vector(1 downto 0);
                   fpc_rfwdata : in  std_logic_vector(63 downto 0);
                   fpc_retid   : in  std_logic_vector(4 downto 0);
                   tdata       : out std_logic_vector(383 downto 0)
                   ) is
    variable indata : std_logic_vector(383 downto 0);
    variable itfilt0 : std_logic;
    variable itfilt1 : std_logic;
  begin

    itfilt0 := itfilt(r.x.ctrl.inst(0),r.w.tco.inst_filter,r.x.ctrl.trap(0));
    itfilt1 := itfilt(r.x.ctrl.inst(1),r.w.tco.inst_filter,r.x.ctrl.trap(1));
    
    indata(383 downto 320) := r.x.storedata;
    if is_load(r.x.ctrl.inst(0)) = '1' then
      indata(383 downto 320) := r.x.data(0);
    end if;
    indata(319)            := valid(0) and r.x.itrhit(0) and itfilt0;
    indata(318)            := '0';
    indata(317 downto 288) := dbgi.timer(29 downto 0);
    indata(287 downto 256) := res_l0;
    if is_fpop(r.x.ctrl.inst(0)) = '1' and is_store(r.x.ctrl.inst(0)) = '0' then
      indata(258 downto 256) := r.x.fpc_ctrl.opid(2 downto 0);
    end if;
    if is_ldst(r.x.ctrl.inst(0)) = '1' then
      indata(287 downto 256) := r.x.result(0);
      --95 downto 64 is always address for LOAD and STORE
      --data is tores in 191 downto 128
    end if;
    indata(255 downto 226) := r.x.ctrl.inst_pc(0)(31 downto 2);
    indata(225)            := trap_l0;
    indata(224)            := error;
    indata(223 downto 192) := r.x.ctrl.inst(0);
    indata(191 downto 128) := (others => '0');
    indata(127)            := valid(1) and r.x.itrhit(1) and itfilt1;
    indata(126)            := '0';
    indata(125 downto 96)  := dbgi.timer(29 downto 0);
    indata(95 downto 64)   := res_l1;
    if is_fpop(r.x.ctrl.inst(1)) = '1' and is_store(r.x.ctrl.inst(1)) = '0' then
      indata(66 downto 64) := r.x.fpc_ctrl.opid(2 downto 0);
    end if;
    indata(63 downto 34) := r.x.ctrl.inst_pc(1)(31 downto 2);
    indata(33)           := trap_l1;
    indata(32)           := error;
    indata(31 downto 0)  := r.x.ctrl.inst(1);
    if swap = '1' then
      indata(319)            := valid(1) and r.x.itrhit(1) and itfilt1; 
      indata(127)            := valid(0) and r.x.itrhit(0) and itfilt0;
      indata(287 downto 256) := res_l1;
      if is_fpop(r.x.ctrl.inst(1)) = '1' then
        indata(258 downto 256) := r.x.fpc_ctrl.opid(2 downto 0);
      end if;
      indata(95 downto 64) := res_l0;
      if is_fpop(r.x.ctrl.inst(0)) = '1' and is_store(r.x.ctrl.inst(0)) = '0' then
        indata(66 downto 64) := r.x.fpc_ctrl.opid(2 downto 0);
      end if;
      if is_ldst(r.x.ctrl.inst(0)) = '1' then
        indata(95 downto 64) := r.x.result(0);
      end if;
      indata(191 downto 128) := r.x.storedata;
      if is_load(r.x.ctrl.inst(0)) = '1' then
        indata(191 downto 128) := r.x.data(0);
      end if;
      indata(255 downto 226) := r.x.ctrl.inst_pc(1)(31 downto 2);
      indata(63 downto 34)   := r.x.ctrl.inst_pc(0)(31 downto 2);
      indata(225)            := trap_l1;
      indata(33)             := trap_l0;
      indata(223 downto 192) := r.x.ctrl.inst(1);
      indata(31 downto 0)    := r.x.ctrl.inst(0);
    end if;
    tdata := indata;
  end;
  
  procedure dbg_cache(holdn    : in  std_logic;
                      dbgi     : in  l5_debug_in_type;
                      r        : in  registers;
                      dsur     : in  dsu_registers;
                      mresult  : in  word;
                      dci      : in  dc_in_type;
                      mresult2 : out word;
                      dci2     : out dc_in_type
                      ) is
    variable area : std_logic_vector(2 downto 0);
  begin
    mresult2   := mresult;
    dci2       := dci;
    dci2.dsuen := '0';
    area       := dbgi.mosi.addr(21-2 downto 19-2);
    if DBGUNIT then
      if r.x.rstate = dsu3 or r.x.rstate = dsu4 then
        dci2.asi := dsur.asi;
        if (area = "111") then
          dci2.dsuen := '1';
          if r.x.rstate = dsu3 then
            dci2.enaddr := '1';
          else
            dci2.enaddr := '0';
          end if;
          dci2.size              := "10";
          dci2.read              := '1';
          dci2.write             := '0';
          mresult2               := (others => '0');
          mresult2(31 downto 19) := dsur.asihiad(31 downto 19);
          mresult2(18 downto 2)  := dbgi.mosi.addr(18-2 downto 2-2);
          if dbgi.mosi.accwr = '1' then
            dci2.read  := '0';
            dci2.write := '1';
          end if;
        end if;
      end if;
    end if;
  end;

  constant RESET_ALL : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1 and
                                  GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 0;
  constant ASYNC_RESET : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  function registers_res return registers is
    variable v : registers;
  begin
    v.f.pc(31 downto 12) := conv_std_logic_vector(rstaddr, 20);  -- Has special handling
    v.f.pc(11 downto 0)  := (others => '0');
    v.f.bht_pc           := v.f.pc;
    v.f.bht_pc2          := v.f.pc;
    v.f.btb_pc           := v.f.pc;
    --v.f.branch := '0';
    v.f.valid            := '0';
    v.d.pc               := v.f.pc;
    v.d.ct_state         := idle;
    v.d.br_cond          := '0';
    for i in 0 to (iways-1) loop
      v.d.inst(i) := (others => '0');
    end loop;
    v.d.inst_pc             := (others => (others => '0'));
    v.d.inst_valid          := "00";
    v.d.delay_slot          := '0';
    v.d.delay_slot_annuled  := '0';
    v.d.bht_taken           := '0';
    v.d.bht_data            := (others => '0');
    v.d.btb_hit             := '0';
    v.d.hold_only_pcreg     := '0';
    v.d.rett_op_delayed     := '0';
    v.d.cwp                 := (others => '0');
    v.d.way                 := (others => '0');
    v.d.mexc                := '0';
    v.d.b2bstore_en         := '1';
    v.d.specload_en         := '1';
    v.d.dual_ldissue_en     := '1';
    v.d.br_flush            := '0';
    v.d.speculative_insts   := '0';
    v.d.pc_reset            := '0';
    v.d.speculative_lock    := '0';
    v.d.ico_bpmiss          := '0';
    v.d.br_counting         := '0';
    v.d.bht_ctrl            := (
      br_miss_pc => (others => '0'),
      pc_delay_slot => (others => '0'),
      bhistory => (others => '0'),
      phistory => (others => '0'),
      btb_taken => '0');
    v.d.diag_btb_flush      := '0';
    v.d.diag_bht_flush      := '0';
    v.d.iudiags             := idle;
    v.d.iudiag_miso         := l5_intreg_miso_none;
    v.d.btb_diag_in.wren    := '0';
    v.d.btb_diag_in.en      := '0';
    v.d.bht_diag_in_en      := '0';
    v.d.btb_diag_in       := l5_btb_diag_in_none;
    v.d.btb_diag_out      := l5_btb_diag_out_none;
    v.d.bht_diag_in_en    := '0';
    v.d.bht_diag_in_wren  := '0';
    v.d.holdn_deadlock_counter := (others => '0');
    v.d.fpc_deadlock_counter := (others => '0');
    v.d.hissue_deadlock_counter := (others => '0');
    v.a.ctrl                := pipeline_ctrl_none;
    v.a.rs1                 := (others => (others => '0'));
    v.a.rs2                 := (others => (others => '0'));
    v.a.rs3                 := (others => '0');
    v.a.cwp                 := (others => '0');
    v.a.imm                 := (others => (others => '0'));
    v.a.su                  := '1';
    v.a.et                  := '0';
    v.a.wovf                := "00";
    v.a.wunf                := "00";
    v.a.ticc                := '0';
    v.a.jmpl                := '0';
    v.a.mulstart            := '0';
    v.a.divstart            := '0';
    v.a.mul_lane            := '0';
    v.a.div_lane            := '0';
    v.a.use_sethi  := (others => '0');
    v.a.use_logic  := (others => '0');
    v.a.use_addsub := (others => '0');
    v.a.use_memaddr_add1 := '0';
    v.a.use_logicshift := '0';
    v.a.rs3_ra2u := '0';
    v.a.rs3_ra3u := '0';
    v.a.rs3_ra4u := '0';
    v.a.astate              := idle;
    v.a.atomic_cnt          := "00";
    v.a.casa                := '0';
    v.a.atomic_nullified    := '0';
    v.a.call_op             := "00";
    v.a.e_annul_align4      := "00";
    v.a.e_cond_annul_align4 := "00";
    v.a.e_cancel_annul      := "00";
    v.a.call_lane         := '0';
    v.a.bp_disabled         := '0';
    v.a.spec_check          := "00";
    v.a.bht_ctrl            := v.d.bht_ctrl;
    v.e.ctrl                := pipeline_ctrl_none;
    v.e.ex_op1              := (others => (others => '0'));
    v.e.ex_op2              := (others => (others => '0'));
    v.e.rs1                 := (others => (others => '0'));
    v.e.rs2                 := (others => (others => '0'));
    v.e.rs3                 := (others => '0');
    v.e.ymsb                := "00";
    v.e.rd                  := (others => '0');
    v.e.jmpl_taddr          := (others => '0');
    v.e.jmpl                := '0';
    v.e.su                  := '1';
    v.e.et                  := '0';
    v.e.cwp                 := (others => '0');
    v.e.icc                 := (others => '0');
    v.e.mulstep             := "00";
    v.e.mul                 := "00";
    v.e.mac                 := "00";
    v.e.ldfwd_rs1           := "00";
    v.e.ldfwd_rs2           := "00";
    v.e.ctrl.ctx_switch     := '0';
    v.e.mul_lane            := '0';
    v.e.div_lane            := '0';
    v.e.use_muldiv_rs1      := (others => '0');
    v.e.use_muldiv_rs2      := (others => '0');
    v.e.mul_op1             := (others => '0');
    v.e.mul_op2             := (others => '0');
    v.e.mul_sign            := '0';
    v.e.ldfwd_tomul_rs1     := '0';
    v.e.ldfwd_tomul_rs2     := '0';
    v.e.mul_rs10            := '0';
    v.e.mul_rs20            := '0';
    v.e.use_memaddr_add1    := '0';
    v.e.iustdata            := (others => '0');
    v.e.alu_ctrl := (
      aluop => (others => (others => '0')),
      alusel => (others => (others => '0')),
      aluadd => (others => '0'),
      alucin => (others => '0'),
      invop2 => (others => '0'),
      shcnt => (others => (others => '0')),
      sari => (others => '0'),
      shleft => (others => '0'),
      use_sethi => (others => '0'),
      use_logic => (others => '0'),
      use_addsub => (others => '0'),
      use_logicshift => '0'
      );
    v.e.call_op             := "00";
    v.e.e_annul_align4      := "00";
    v.e.e_cond_annul_align4 := "00";
    v.e.e_cancel_annul      := "00";
    v.e.call_lane           := '0';
    v.e.atomic_trapped      := '0';
    v.e.bht_ctrl            := v.a.bht_ctrl;
    v.e.casa_asiA           := '0';
    v.e.itrhit              := "00";
    v.m.ctrl                := pipeline_ctrl_none;
    v.m.rs1                 := (others => (others => '0'));
    v.m.rs2                 := (others => (others => '0'));
    v.m.rs3                 := (others => '0');
    v.m.result              := (others => (others => '0'));
    v.m.y                   := (others => '0');
    v.m.icc                 := (others => '0');
    v.m.icc_dannul          := (others => '0');
    v.m.nalign              := '0';
    v.m.dci                 := dc_in_none;
    v.m.werr                := '0';
    v.m.wcwp                := "00";
    v.m.irqen               := '0';
    v.m.irqen2              := '0';
    v.m.mac                 := '0';
    v.m.divz                := '0';
    v.m.su                  := '0';
    v.m.mul                 := '0';
    v.m.fpdata              := (others => '0');
    v.m.iustdata            := (others => '0');
    v.m.casz                := '0';
    v.m.itrhit              := "00";
    v.m.jmpl_taddr          := (others => '0');
    v.m.alu_op1             := (others => (others => '0'));
    v.m.alu_op2             := (others => (others => '0'));
    v.m.late_wicc_rs1       := (others => '0');
    v.m.late_wicc_rs2       := (others => '0');
    v.m.late_wicc_op1_ldfwd := '0';
    v.m.late_wicc_op2_ldfwd := '0';
    v.m.late_wicc_op1_lalu0 := '0';
    v.m.late_wicc_op1_lalu1 := '0';
    v.m.late_wicc_op2_lalu0 := '0';
    v.m.late_wicc_op2_lalu1 := '0';
    v.m.lalu0_ldfwd_rs1     := '0';
    v.m.lalu0_ldfwd_rs2     := '0';
    v.m.lalu0_wb0fwd_rs1    := '0';
    v.m.lalu0_wb0fwd_rs2    := '0';
    v.m.lalu0_wb1fwd_rs1    := '0';
    v.m.lalu0_wb1fwd_rs2    := '0';
    v.m.mem_data_alu1       := (others => '0');
    v.m.mem_data_xdatah     := (others => '0');
    v.m.mem_data_xdatal     := (others => '0');
    v.m.mem_data_xresult0   := (others => '0');
    v.m.mem_data_lalu0      := (others => '0');
    v.m.mem_data_lalu1      := (others => '0');
    v.m.alu_ctrl            := v.e.alu_ctrl;
    v.m.bht_ctrl            := v.e.bht_ctrl;
    v.m.dc_nullify          := '0';
    v.x.ctrl                := pipeline_ctrl_none;
    v.x.rs1                 := (others => (others => '0'));
    v.x.rs2                 := (others => (others => '0'));
    v.x.rs3                 := (others => '0');
    v.x.result              := (others => (others => '0'));
    v.x.y                   := (others => '0');
    v.x.icc                 := (others => '0');
    v.x.icc_dannul          := (others => '0');
    v.x.annul_all           := '1';
    for i in 0 to (dways-1) loop
      v.x.data(i) := (others => '0');
    end loop;
    v.x.way               := (others => '0');
    v.x.mexc              := '0';
    v.x.dci               := dc_in_none;
    v.x.laddr             := (others => '0');
    v.x.rstate            := dsu2;
    v.x.cpustate          := CPUSTATE_STOPPED;
    v.x.debug_ret         := '0';
    v.x.debug_ret2        := '0';
    v.x.npc               := (others => '0');
    v.x.intack            := '0';
    v.x.ipend             := '0';
    v.x.mac               := '0';
    v.x.debug             := '1';
    v.x.nerror            := '0';
    v.x.ldd               := '0';
    v.x.alu_op1           := (others => (others => '0'));
    v.x.alu_op2           := (others => (others => '0'));
    v.x.ldfwd             := (others => (others => '0'));
    v.x.multfwd           := (others => (others => '0'));
    v.x.late_wicc_op1     := (others => '0');
    v.x.late_wicc_op2     := (others => '0');
    v.x.late_wicc_rs1     := (others => '0');
    v.x.late_wicc_rs2     := (others => '0');
    v.x.late_wicc_op1_ldfwd := '0';
    v.x.late_wicc_op2_ldfwd := '0';
    v.x.late_wicc_alucin    := '0';
    v.x.late_wicc_aluop     := (others => '0');
    v.x.late_wicc_aluadd    := '0';
    v.x.late_wicc_alusel    := (others => '0');
    v.x.late_wicc_invop2    := '0';
    v.x.icc_prev            := (others => '0');
    v.x.wicc_prev_lateld    := '0';
    v.x.update_late_dannul  := '0';
    v.x.muldiv_result       := (others => '0');
    v.x.trapl             := '0';
    v.x.speculative_load  := '0';
    v.x.xc_ld_replay      := '0';
    v.x.alu_ctrl          := v.e.alu_ctrl;
    v.x.storedata         := (others => '0');
    v.x.bht_ctrl          := v.e.bht_ctrl;
    v.x.ret_sleep         := '0';
    v.x.tt_ticc           := '0';
    v.x.itrhit            := "00";
    v.w.s.cwp             := (others => '0');
    v.w.s.icc             := (others => '0');
    v.w.s.tt              := (others => '0');
    v.w.s.tba             := conv_std_logic_vector(rstaddr, 20);  -- Has special handling
    v.w.s.wim             := (others => '0');
    v.w.s.pil             := (others => '0');
    v.w.s.ec              := '0';
    v.w.s.ef              := '0';
    v.w.s.ps              := '1';
    v.w.s.s               := '1';
    v.w.s.et              := '0';
    v.w.s.y               := (others => '0');
    v.w.s.asr18           := (others => '0');
    v.w.s.svt             := '0';
    v.w.s.dwt             := '0';
    v.w.s.dbp             := '0';
    v.w.s.dbprepl         := '1';
    v.w.s.ducnt           := '1';
    v.w.s.holdn_deadlock  := '0';
    v.w.s.fpc_deadlock    := '0';
    v.w.s.hissue_deadlock := '0';
    v.w.icc_dannul        := (others => '0');
    v.w.except            := '0';
    v.w.we                := (others => (others => '0'));
    v.w.rd                := (others => (others => '0'));
    v.w.wb_data           := (others => (others => '0'));
    v.w.waddr             := (others => (others => '0'));
    v.w.step := (
      en => '0',
      counter => (others => '0'),
      dbgm => '0'
      );
    v.w.fp_exc_ack        := "00";
    v.w.tdata             := (others => '0');
    v.w.tco.inst_filter   := (others=>'0');
    v.w.tco.addr_f        := (others=>'0');
    v.w.tco.addr_f_p      := (others=>'0');
    --FPC
    v.d.fpc_issued        := '0';
    v.d.fp_stdata_latched := '0';
    v.d.fpc_annuled       := '0';
    v.d.fpc_ctrl := (
      opid => (others => '0'),
      issued => '0',
      issue_lane => '0',
      trap_fp => '0',
      illegal_fp => '0',
      spstore => '0'
      );
    v.d.fpustdata         := (others => '0');
    v.a.fpc_ctrl          := v.d.fpc_ctrl;
    v.a.fpustdata         := (others => '0');
    v.a.fp_stdata_latched := '0';
    v.e.fpc_ctrl          := v.d.fpc_ctrl;
    v.m.fpc_ctrl          := v.d.fpc_ctrl;
    v.x.fpc_ctrl          := v.d.fpc_ctrl;
--    v.d.fpc_ctrl.issued   := '0';
--    v.a.fpc_ctrl.issued   := '0';
--    v.a.fpc_ctrl.trap_fp  := '0';
--    v.e.fpc_ctrl.issued   := '0';
--    v.e.fpc_ctrl.trap_fp  := '0';
--    v.m.fpc_ctrl.issued   := '0';
--    v.m.fpc_ctrl.trap_fp  := '0';
--    v.x.fpc_ctrl.issued   := '0';
--    v.x.fpc_ctrl.trap_fp  := '0';
    v.x.miso              := l5_intreg_miso_none;
    v.w.fpu_unissue       := '0';
    v.w.fpu_unissue_sid   := (others => '0');
    v.perf                := (others => '0');
    return v;
  end function registers_res;
  constant RRES : registers           := registers_res;
  constant WRES : watchpoint_register := wpr_none;
  constant DRES : dsu_registers := (
    tt      => (others => '0'), asi => (others => '0'), asihiad => (others => '0'),
    brktype => "00",
    crdy    => (others => '0'), cfc => (others => '0'));
  constant IRES : irestart_register := (ir_reset, '0');
  constant PRES : pwd_register_type := ('0', '0', '1');

  signal r, rin      : registers;
  signal wpr, wprin  : watchpoint_registers;
  signal dsur, dsuin : dsu_registers;
  signal ir, irin    : irestart_register;
  signal rp, rpin    : pwd_register_type;
  signal ur, urin    : ungated_registers;

  signal bhti        : l5_bht_in_type;
  signal bhto        : l5_bht_out_type;
  signal btb_hit     : std_logic;
  signal btb_outdata : std_logic_vector(31 downto 0);
  signal btb_wen     : std_logic;
  signal btb_instpc  : std_logic_vector(31 downto 0);
  signal btb_indata  : std_logic_vector(31 downto 0);
  signal btb_flush   : std_logic;
  signal FPSPEC      : std_logic;

-- execute stage operations

  constant EXE_AND  : std_logic_vector(2 downto 0) := "000";
  constant EXE_XOR  : std_logic_vector(2 downto 0) := "001";  -- must be equal to EXE_PASS2
  constant EXE_OR   : std_logic_vector(2 downto 0) := "010";
  constant EXE_XNOR : std_logic_vector(2 downto 0) := "011";
  constant EXE_ANDN : std_logic_vector(2 downto 0) := "100";
  constant EXE_ORN  : std_logic_vector(2 downto 0) := "101";
  constant EXE_DIV  : std_logic_vector(2 downto 0) := "110";

  constant EXE_PASS1 : std_logic_vector(2 downto 0) := "000";
  constant EXE_PASS2 : std_logic_vector(2 downto 0) := "001";
  constant EXE_STB   : std_logic_vector(2 downto 0) := "010";
  constant EXE_STH   : std_logic_vector(2 downto 0) := "011";
  constant EXE_ONES  : std_logic_vector(2 downto 0) := "100";
  constant EXE_RDY   : std_logic_vector(2 downto 0) := "101";
  constant EXE_SPR   : std_logic_vector(2 downto 0) := "110";
  constant EXE_LINK  : std_logic_vector(2 downto 0) := "111";

  constant EXE_SLL : std_logic_vector(2 downto 0) := "001";
  constant EXE_SRL : std_logic_vector(2 downto 0) := "010";
  constant EXE_SRA : std_logic_vector(2 downto 0) := "100";

  constant EXE_NOP : std_logic_vector(2 downto 0) := "000";

-- EXE result select

  constant EXE_RES_ADD   : std_logic_vector(1 downto 0) := "00";
  constant EXE_RES_SHIFT : std_logic_vector(1 downto 0) := "01";
  constant EXE_RES_LOGIC : std_logic_vector(1 downto 0) := "10";
  constant EXE_RES_MISC  : std_logic_vector(1 downto 0) := "11";

-- Load types

  constant SZBYTE : std_logic_vector(1 downto 0) := "00";
  constant SZHALF : std_logic_vector(1 downto 0) := "01";
  constant SZWORD : std_logic_vector(1 downto 0) := "10";
  constant SZDBL  : std_logic_vector(1 downto 0) := "11";

  function is_fpop_noldst(inst : word) return std_logic is
    variable ret : std_logic;
    variable op3 : std_logic_vector(5 downto 0);
  begin
    
    ret := '0';
    op3 := inst(24 downto 19);

    if inst(31 downto 30) = "10" then
      --fpop1/fpop2
      if op3(5 downto 1) = "11010" then
        ret := '1';
      end if;
    end if;

    return ret;
  end;

  --LEON5 check if source register is sued
  procedure rs_check(inst      :     word;
                     rs1_valid : out std_logic;
                     rs2_valid : out std_logic) is
    variable op  : std_logic_vector(1 downto 0);
    variable op3 : std_logic_vector(5 downto 0);
  begin

    rs1_valid := '0';
    rs2_valid := '0';
    op        := inst(31 downto 30);
    op3       := inst(24 downto 19);

    if op = FMT3 then
      rs1_valid := '1';
      if inst(13) = '0' then
        rs2_valid := '1';
      end if;
      if (op3 = RDY) or (op3 = RDPSR) or (op3 = RDWIM) or (op3 = RDTBR) then
        rs2_valid := '0';
      end if;
    end if;

    if op = LDST then
      rs1_valid := '1';
      if inst(13) = '0' then
        rs2_valid := '1';
      end if;
    end if;

    if inst(18 downto 14) = "00000" then
      rs1_valid := '0';
    end if;
    if inst(4 downto 0) = "00000" then
      rs2_valid := '0';
    end if;

    if is_fpop(inst) = '1' and is_ldst(inst) = '0' and FPEN then
      rs1_valid := '0';
      rs2_valid := '0';
    end if;

  end;

-- calculate register file address

  procedure regaddr(cwp :     std_logic_vector; reg : std_logic_vector(4 downto 0); valid : std_logic;
  rao                   : out rfatype) is
    variable zero    : std_logic;
    variable ra      : rfatype;
    constant globals : std_logic_vector(RFBITS-5 downto 0) := conv_std_logic_vector(NWIN, RFBITS-4);
  begin
    zero           := not(valid);
    ra             := (others => '0');
    ra(4 downto 0) := reg;
    if reg(4 downto 3) = "00" then
      ra(RFBITS -1 downto 4) := globals;
    else
      ra(NWINLOG2+3 downto 4) := cwp + ra(4);
      if ra(RFBITS-1 downto 4) = globals then
        ra(RFBITS-1 downto 4) := (others => '0');
      end if;
    end if;
    rao := ra;
  end;

  function is_logic(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = FMT3 and
      (inst(24 downto 19) = IAND or inst(24 downto 19) = IOR
       or inst(24 downto 19) = IXOR or inst(24 downto 19) = ANDN
       or inst(24 downto 19) = ORN or inst(24 downto 19) = IXNOR) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_addsub(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = FMT3 and
      (inst(24 downto 19) = IADD or inst(24 downto 19) = ADDX
       or inst(24 downto 19) = ISUB or inst(24 downto 19) = SUBX)
    then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_shift(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = FMT3 and
      (inst(24 downto 19) = ISLL or inst(24 downto 19) = ISRL
       or inst(24 downto 19) = ISRA) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_wsri(inst : word) return std_logic is
  begin

    if inst(31 downto 30) = "10" and inst(24 downto 21) = "1100" then
      return '1';
    else
      return '0';
    end if;

  end;

  function is_rdsri(inst : word) return std_logic is
  begin

    if inst(31 downto 30) = "10" and inst(24 downto 21) = "1010" then
      return '1';
    else
      return '0';
    end if;

  end;

  function is_rdpsr(inst : word) return std_logic is
  begin

    if inst(31 downto 30) = "10" and inst(24 downto 19) = "101001" then
      return '1';
    else
      return '0';
    end if;

  end;

  function is_rdy(inst : word) return std_logic is
  begin

    if inst(31 downto 30) = "10" and inst(24 downto 14) = "10100000000" then
      return '1';
    else
      return '0';
    end if;

  end;

  function is_branch_unc(inst : word) return std_logic is
  begin
    if inst(27 downto 25) = "000" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_branch(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "00" and inst(24 downto 22) = "010" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_bicc(inst: word) return std_logic is
    --acording to definition TABLE 5-13 SPARC V8 manual
  begin
    if inst(28 downto 25) /= "1000" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_fpu_branch(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "00" and inst(24 downto 22) = "110" then
      return '1';
    else
      return '0';
    end if;
  end;


  function is_branch_annul_int(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "00" and inst(24 downto 22) = "010" and inst(29) = '1' then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_branch_annul(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "00" and inst(23 downto 22) = "10" and inst(29) = '1' then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_jmpl(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and inst(24 downto 19) = JMPL then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_rett(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and inst(24 downto 19) = RETT then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_toc(inst : word) return std_logic is
  begin
    if is_branch(inst) = '1' or is_fpu_branch(inst) = '1' or inst(31 downto 30) = "01" or is_jmpl(inst) = '1' or is_rett(inst) = '1' then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_ticc(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and inst(24 downto 19) = TICC then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_tcctv(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and (inst(24 downto 19) = TADDCC or inst(24 downto 19) = TSUBCC or inst(24 downto 19) = TADDCCTV or inst(24 downto 19) = TSUBCCTV) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_store_mmu(inst : word) return std_logic is
    variable ret : std_logic;
  begin
    ret := '0';
    if inst(31 downto 30) = "11" and inst(21) = '1' and inst(23) = '1' and inst(13) = '0' and inst(12 downto 5) = x"19" then
      ret := '1';
    end if;
    return ret;
  end;

  function is_store_int(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "11" and inst(21) = '1' and (inst(24 downto 23) = "00" or inst(24 downto 23) = "01") and is_atomic(inst) = '0' then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_fpu_store(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "11" and inst(24 downto 21) = "1001" and is_atomic(inst) = '0' then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_stdfq(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "11" and inst(24 downto 19) = "100110" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_fpu_load(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "11" and inst(24 downto 21) = "1000" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_load_int(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "11" and inst(21) = '0' and (inst(24 downto 23) = "00" or inst(24 downto 23) = "01") then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_flush(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and inst(24 downto 19) = "111011" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_ldd_int(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "11" and (inst(24 downto 19) = LDD or inst(24 downto 19) = LDDA) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_stdb(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "11" and (inst(24 downto 19) = ISTD or inst(24 downto 19) = STDA) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_wicc(inst : word) return std_logic is
    variable op3 : std_logic_vector(5 downto 0);
  begin
    op3 := inst(24 downto 19);
    if inst(31 downto 30) = "10" then
      if (op3 = ADDCC) or (op3 = ANDCC) or (op3 = ORCC) or (op3 = XORCC) or (op3 = SUBCC)
        or (op3 = ANDNCC) or (op3 = ORNCC) or (op3 = XNORCC) or (op3 = ADDXCC) or (op3 = SUBXCC)
        or (op3 = TADDCC) or (op3 = TSUBCC) or (op3 = TADDCCTV) or (op3 = UDIVCC) or (op3 = SDIVCC)
        or (op3 = UMULCC) or (op3 = SMULCC) or (op3 = MULSCC) or (op3 = TSUBCCTV) then
        return '1';
      else
        return '0';
      end if;
    else
      return '0';
    end if;
  end;

  function is_wicc_latealu(inst : word) return std_logic is
    variable op3 : std_logic_vector(5 downto 0);
  begin
    op3 := inst(24 downto 19);
    if inst(31 downto 30) = "10" then
      if (op3 = ADDCC) or (op3 = ANDCC) or (op3 = ORCC) or (op3 = XORCC) or (op3 = SUBCC)
        or (op3 = ANDNCC) or (op3 = ORNCC) or (op3 = XNORCC) then
        return '1';
      else
        return '0';
      end if;
    else
      return '0';
    end if;
  end;

  function is_ficc(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and inst(24 downto 19) = "110101" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_opx(inst : word) return std_logic is
    variable op3 : std_logic_vector(5 downto 0);
    variable ret : std_logic;
  begin
    ret := '0';
    op3 := inst(24 downto 19);
    if inst(31 downto 30) = "10" then
      if (op3 = ADDX) or (op3 = SUBX) or (op3 = ADDXCC) or (op3 = SUBXCC) then
        ret := '1';
      end if;
    end if;
    return ret;
  end;

  function is_div(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and (inst(24 downto 19) = UDIV or inst(24 downto 19) = SDIV
                                      or inst(24 downto 19) = UDIVCC or inst(24 downto 19) = SDIVCC) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_mul(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and (inst(24 downto 19) = UMUL or inst(24 downto 19) = SMUL
                                      or inst(24 downto 19) = UMULCC or inst(24 downto 19) = SMULCC) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_mul_all(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and (inst(24 downto 19) = UMUL or inst(24 downto 19) = SMUL
                                      or inst(24 downto 19) = UMULCC or inst(24 downto 19) = SMULCC
                                      or inst(24 downto 19) = MULSCC) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_mulscc(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and inst(24 downto 19) = MULSCC then
      return '1';
    else
      return '0';
    end if;
  end;


  function is_divmulscc(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and (inst(24 downto 19) = UDIV or inst(24 downto 19) = SDIV
                                      or inst(24 downto 19) = UDIVCC or inst(24 downto 19) = SDIVCC
                                      or inst(24 downto 19) = UMUL or inst(24 downto 19) = SMUL
                                      or inst(24 downto 19) = UMULCC or inst(24 downto 19) = SMULCC
                                      or inst(24 downto 19) = MULSCC) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_divmul(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and (inst(24 downto 19) = UDIV or inst(24 downto 19) = SDIV
                                      or inst(24 downto 19) = UDIVCC or inst(24 downto 19) = SDIVCC
                                      or inst(24 downto 19) = UMUL or inst(24 downto 19) = SMUL
                                      or inst(24 downto 19) = UMULCC or inst(24 downto 19) = SMULCC) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_muldivcc(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and (inst(24 downto 19) = UDIVCC or inst(24 downto 19) = SDIVCC
                                      or inst(24 downto 19) = UMULCC or inst(24 downto 19) = SMULCC) then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_saverestore(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and inst(24 downto 20) = "11110" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_save(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and inst(24 downto 19) = "111100" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_restore(inst : word) return std_logic is
  begin
    if inst(31 downto 30) = "10" and inst(24 downto 19) = "111101" then
      return '1';
    else
      return '0';
    end if;
  end;

  function is_legal_fpu(inst : word) return std_logic is
    variable ret    : std_logic;
    variable fpop_t : std_logic_vector(8 downto 0);
    variable op3    : std_logic_vector(5 downto 0);
  begin
   
    ret    := '0';
    fpop_t := inst(13 downto 5);
    op3    := inst(24 downto 19);

    if inst(31 downto 30) = "10" and op3 = "110100" then
      --fpop1
      if fpop_t = FITOS or fpop_t = FITOD or fpop_t = FITOQ or
        fpop_t = FSTOI or fpop_t = FDTOI or fpop_t = FQTOI or
        fpop_t = FSTOD or fpop_t = FSTOQ or fpop_t = FDTOS or
        fpop_t = FDTOQ or fpop_t = FQTOS or fpop_t = FQTOD or
        fpop_t = FMOVS or fpop_t = FNEGS or fpop_t = FABSS or
        fpop_t = FSQRTS or fpop_t = FSQRTD or fpop_t = FSQRTQ or
        fpop_t = FADDS or fpop_t = FADDD or fpop_t = FADDQ or
        fpop_t = FSUBS or fpop_t = FSUBD or fpop_t = FSUBQ or
        fpop_t = FMULS or fpop_t = FMULD or fpop_t = FMULQ or
        fpop_t = FSMULD or fpop_t = FDMULQ or
        fpop_t = FDIVS or fpop_t = FDIVD or fpop_t = FDIVQ then
        ret := '1';
      end if;
    end if;

    if inst(31 downto 30) = "10" and op3 = "110101" then
      --fpop2
      if fpop_t = FCMPS or fpop_t = FCMPD or fpop_t = FCMPQ or
        fpop_t = FCMPES or fpop_t = FCMPED or fpop_t = FCMPEQ then
        ret := '1';
      end if;
    end if;

    if inst(31 downto 30) = "11" then
      if op3 = STF or op3 = STDF or op3 = STFSR or op3 = STDFQ then
        ret := '1';
      end if;

      if op3 = LDF or op3 = LDDF or op3 = LDFSR then
        ret := '1';
      end if;
    end if;

    return ret;

  end;

  function is_fpu_spec_nallow(inst : word) return std_logic is
    variable ret    : std_logic;
    variable fpop_t : std_logic_vector(8 downto 0);
    variable op3    : std_logic_vector(5 downto 0);
  begin

    ret    := '0';
    fpop_t := inst(13 downto 5);
    op3    := inst(24 downto 19);

    if inst(31 downto 30) = "11" and (op3 = STFSR or op3 = STDFQ) then
      ret := '1';
    end if;
    if inst(31 downto 30) = "10" and op3 = "110100" then
      if fpop_t = FSQRTS or fpop_t = FSQRTD or fpop_t = FSQRTQ
        or fpop_t = FDIVS or fpop_t = FDIVD or fpop_t = FDIVQ then
        ret := '1';
      end if;
    end if;

    return ret;
  end;

  function is_fpu_spstore(inst : word) return std_logic is
    variable ret : std_logic;
    variable op3 : std_logic_vector(5 downto 0);
  begin
    op3 := inst(24 downto 19);
    ret := '0';
    if inst(31 downto 30) = "11" and (op3 = STFSR or op3 = STDFQ) then
      ret := '1';
    end if;
    return ret;
  end;

  function is_light_alu(inst : word) return std_logic is
    variable op3 : std_logic_vector(5 downto 0);
  begin
    op3 := inst(24 downto 19);
    if inst(31 downto 30) = "10" then
      if op3 = IADD or op3 = IAND or op3 = IOR or op3 = IXOR or op3 = ISUB or op3 = ANDN
        or op3 = ORN or op3 = IXNOR then
        return '1';
      else
        return '0';
      end if;
    else
      return '0';
    end if;
  end;

  function is_late_alu_op(inst : word) return std_logic is
    variable op3 : std_logic_vector(5 downto 0);
  begin
    op3 := inst(24 downto 19);
    if inst(31 downto 30) = "10" then
      if op3 = IADD or op3 = IAND or op3 = IOR or op3 = IXOR or op3 = ISUB or op3 = ANDN
        or op3 = ORN or op3 = IXNOR or op3 = ISLL
        or op3 = ISRL or op3 = ISRA or op3 = ADDCC or op3 = ANDCC or op3 = ORCC
        or op3 = XORCC or op3 = SUBCC or op3 = ANDNCC or op3 = ORNCC or op3 = XNORCC then
        return '1';
      else
        return '0';
      end if;
    else
      return '0';
    end if;
  end;

  function is_late_alu_depen(r  : registers;
                             rs : rfatype) return std_logic is
    variable ret : std_logic;
  begin

    ret := '0';
    for i in 0 to 1 loop
      if r.e.ctrl.inst_valid(i) = '1' and r.e.ctrl.delay_annuled(i) = '0' and r.e.ctrl.no_forward(i) = '0' and r.e.ctrl.rdw(i) = '1' and r.e.ctrl.alu_dexc(i) = '1' then
        if r.e.ctrl.rd(i) = rs then
          ret := '1';
        end if;
      end if;
      if r.m.ctrl.inst_valid(i) = '1' and r.m.ctrl.delay_annuled(i) = '0' and r.m.ctrl.no_forward(i) = '0' and r.m.ctrl.rdw(i) = '1' and r.m.ctrl.alu_dexc(i) = '1' then
        if r.m.ctrl.rd(i) = rs then
          ret := '1';
        end if;
      end if;
    end loop;

    return ret;
    
  end;

  function is_late_alu_depen_s1(r  : registers;
                                rs : rfatype) return std_logic is
    variable ret : std_logic;
  begin

    ret := '0';
    for i in 0 to 1 loop
      if r.a.ctrl.inst_valid(i) = '1' and r.a.ctrl.delay_annuled(i) = '0' and r.a.ctrl.no_forward(i) = '0' and r.a.ctrl.rdw(i) = '1' and (r.a.ctrl.alu_dexc(i) = '1' or r.a.ctrl.lalu_s1(i) = '1') then
        if r.a.ctrl.rd(i) = rs then
          ret := '1';
        end if;
      end if;
      if r.e.ctrl.inst_valid(i) = '1' and r.e.ctrl.delay_annuled(i) = '0' and r.e.ctrl.no_forward(i) = '0' and r.e.ctrl.rdw(i) = '1' and r.e.ctrl.alu_dexc(i) = '1' then
        if r.e.ctrl.rd(i) = rs then
          ret := '1';
        end if;
      end if;
    end loop;

    return ret;
    
  end;

  function is_late_alu_depen_exe(r  : registers;
                                 rs : rfatype) return std_logic is
    variable ret : std_logic;
  begin

    ret := '0';
    for i in 0 to 1 loop
      if r.e.ctrl.inst_valid(i) = '1' and r.e.ctrl.delay_annuled(i) = '0' and r.e.ctrl.no_forward(i) = '0' and r.e.ctrl.rdw(i) = '1' and r.e.ctrl.alu_dexc(i) = '1' then
        if r.e.ctrl.rd(i) = rs then
          ret := '1';
        end if;
      end if;
    end loop;
    return ret;
  end;

  procedure late_alu_s1(r              :     registers;
                        rs1            :     reg_pair_type;
                        rs2            :     reg_pair_type;
                        use_sethi      :     std_logic_vector(1 downto 0);
                        use_logic      :     std_logic_vector(1 downto 0);
                        use_addsub     :     std_logic_vector(1 downto 0);
                        use_logicshift :     std_logic;
                        lalu_s1        : out std_logic_vector(1 downto 0)) is
    variable lalu_s1_t : std_logic_vector(1 downto 0);
  begin

    lalu_s1_t := "00";

    for i in 0 to 1 loop
      if r.a.ctrl.inst_valid(i) = '1' and r.a.ctrl.inst(i)(31 downto 30) = FMT3 and r.a.ctrl.rdw(i) = '1' then
        if r.a.ctrl.inst(i)(24 downto 19) = UMUL or r.a.ctrl.inst(i)(24 downto 19) = SMUL
          or r.a.ctrl.inst(i)(24 downto 19) = UMULCC or r.a.ctrl.inst(i)(24 downto 19) = SMULCC then
          for j in 0 to 1 loop
            if ((rs1(j) = r.a.ctrl.rd(i)) or (rs2(j) = r.a.ctrl.rd(i))) then
              lalu_s1_t(j) := '1';
            end if;
          end loop;
        end if;
      end if;
    end loop;

    if is_load_int(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.inst_valid(0) = '1' and r.a.ctrl.delay_annuled(0) = '0' and r.a.ctrl.rdw(0) = '1' and r.a.ctrl.no_forward(0) = '0' then

      for j in 0 to 1 loop
        if ((rs1(j) = r.a.ctrl.rd(0)) or (rs2(j) = r.a.ctrl.rd(0))) then
          lalu_s1_t(j) := '1';
        end if;
        if (is_ldd_int(r.a.ctrl.inst(0)) = '1' and
             (rs1(j)(RFBITS downto 1) = r.a.ctrl.rd(0)(RFBITS downto 1) or
               rs2(j)(RFBITS downto 1) = r.a.ctrl.rd(0)(RFBITS downto 1))) then     
          lalu_s1_t(j) := '1';
        end if;
      end loop;
      
    end if;

    for i in 0 to 1 loop
      if is_late_alu_depen_s1(r, rs1(i)) = '1' or is_late_alu_depen_s1(r, rs2(i)) = '1' then
        lalu_s1_t(i) := '1';
      end if;
    end loop;

    if use_sethi /= "00" or use_logic /= "00" or use_addsub /= "00" or use_logicshift /= '0' then
      if lalu_s1_t(0) = '1' then
        lalu_s1_t(1) := '1';
      end if;
    end if;

    lalu_s1 := lalu_s1_t;

  end;


-- branch adder

  function branch_address(inst : word; pc : pctype)
    return std_logic_vector is
    variable baddr      : std_logic_vector(31 downto 0);
    variable caddr, tmp : pctype;
  begin
    caddr               := (others => '0');
    caddr(31 downto 2)  := inst(29 downto 0);
    caddr(31 downto 2)  := caddr(31 downto 2) + pc(31 downto 2);
    baddr               := (others => '0');
    baddr(31 downto 24) := (others => inst(21));
    baddr(23 downto 2)  := inst(21 downto 0);
    baddr(31 downto 2)  := baddr(31 downto 2) + pc(31 downto 2);
    if inst(30) = '1' then
      tmp := caddr;
    else
      tmp := baddr(31 downto PCLOW);
    end if;
    return(tmp);
  end;



-- evaluate branch condition

  function fpbranch_true(inst : in word; fcc : in std_logic_vector(1 downto 0))
    return std_logic is
    variable cond   : std_logic_vector(3 downto 0);
    variable fbres  : std_logic;
    variable branch : std_logic;
  begin
    cond := inst(28 downto 25);
    case cond(2 downto 0) is
      when "000"  => fbres := '0';      -- fba, fbn
      when "001"  => fbres := fcc(1) or fcc(0);
      when "010"  => fbres := fcc(1) xor fcc(0);
      when "011"  => fbres := fcc(0);
      when "100"  => fbres := (not fcc(1)) and fcc(0);
      when "101"  => fbres := fcc(1);
      when "110"  => fbres := fcc(1) and not fcc(0);
      when others => fbres := fcc(1) and fcc(0);
    end case;
    branch := cond(3) xor fbres;
    return branch;
  end;

  function branch_mispredict_fpu(icc      : std_logic_vector(1 downto 0);
                                 inst     : word;
                                 br_taken : std_logic)
    return std_logic is
    variable br_true : std_logic;
  begin

    br_true := fpbranch_true(inst, icc);

    if br_taken = '1' then
      return not(br_true);
    else
      return br_true;
    end if;

  end;


  function branch_true(icc : std_logic_vector(3 downto 0); inst : word)
    return std_logic is
    variable n, z, v, c, branch : std_logic;
  begin
    n := icc(3); z := icc(2); v := icc(1); c := icc(0);
    case inst(27 downto 25) is
      when "000"  => branch := inst(28) xor '0';               -- bn, ba
      when "001"  => branch := inst(28) xor z;                 -- be, bne
      when "010"  => branch := inst(28) xor (z or (n xor v));  -- ble, bg
      when "011"  => branch := inst(28) xor (n xor v);         -- bl, bge
      when "100"  => branch := inst(28) xor (c or z);          -- bleu, bgu
      when "101"  => branch := inst(28) xor c;                 -- bcs, bcc
      when "110"  => branch := inst(28) xor n;                 -- bneg, bpos
      when others => branch := inst(28) xor v;                 -- bvs, bvc
    end case;
    return(branch);
  end;

  function branch_mispredict(icc      : std_logic_vector(3 downto 0);
                             inst     : word;
                             br_taken : std_logic)
    return std_logic is
    variable br_true : std_logic;
  begin

    br_true := branch_true(icc, inst);

    if br_taken = '1' then
      return not(br_true);
    else
      return br_true;
    end if;

  end;

-- detect RETT instruction in the pipeline and set the local psr.su and psr.et

  procedure su_et_select(r, v : in  registers; xc_ps, xc_s, xc_et : in std_logic;
  su, et                      : out std_logic) is
  begin
    --a rett can speculatively reach access stage due to branch prediction hence
    --make sure that SU bit is not set wrongly when branch missprediction is detected
    --and control of transfer is made to correct address by checking validity
    --from the input of the next stage
    if (
      (r.a.ctrl.rett_op = '1' and v.e.ctrl.inst_valid(1) = '1' and r.a.ctrl.trap(1) = '0') or
      (r.e.ctrl.rett_op = '1' and v.m.ctrl.inst_valid(1) = '1' and r.e.ctrl.trap(1) = '0') or
      (r.m.ctrl.rett_op = '1' and v.x.ctrl.inst_valid(1) = '1' and r.m.ctrl.trap(1) = '0') or
      (r.x.ctrl.rett_op = '1' and r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.trap(1) = '0'))
      and (r.x.annul_all = '0') then
      su := xc_ps;
      et := '1';
    else
      su := xc_s;
      et := xc_et;
    end if;
  end;

-- detect watchpoint trap

  function wphit(lane   : integer range 0 to 1;
                 r      : registers;
                 wpr    : watchpoint_registers;
                 debug  : l5_debug_in_type;
                 dsur   : dsu_registers;
                 pccomp : std_logic_vector(3 downto 0))
    return std_logic is
    variable exc : std_logic;
  begin
    exc := '0';
    for i in 1 to NWP loop
      if ((wpr(i-1).exec and r.a.ctrl.inst_valid(lane)) = '1') then
        if (pccomp(i-1) = '1') then
          exc := '1';
        end if;
      end if;
    end loop;

    -- Can not handle breaking on RETT
    --   if r.a.ctrl.rett_op = '1' then
    --     exc := '0';
    --   end if;
    return(exc);
  end;

  function shift(shleft         : std_logic;
                 aluin1, aluin2 : word;
                 shiftcnt       : std_logic_vector(4 downto 0);
                 sari           : std_logic) return word is
    variable shiftin : std_logic_vector(63 downto 0);
  begin
    shiftin := zero32 & aluin1;
    if shleft = '1' then
      shiftin(31 downto 0)  := zero32;
      shiftin(63 downto 31) := '0' & aluin1;
    else
      shiftin(63 downto 32) := (others => sari);
    end if;
    if shiftcnt (4) = '1' then
      shiftin(47 downto 0) := shiftin(63 downto 16);
    end if;
    if shiftcnt (3) = '1' then
      shiftin(39 downto 0) := shiftin(47 downto 8);
    end if;
    if shiftcnt (2) = '1' then
      shiftin(35 downto 0) := shiftin(39 downto 4);
    end if;
    if shiftcnt (1) = '1' then
      shiftin(33 downto 0) := shiftin(35 downto 2);
    end if;
    if shiftcnt (0) = '1' then
      shiftin(31 downto 0) := shiftin(32 downto 1);
    end if;
    return(shiftin(31 downto 0));
  end;

-- Check for illegal and privileged instructions

  procedure exception_detect(lane :     integer range 0 to 1; r : registers; wpr : watchpoint_registers; dbgi : l5_debug_in_type; fpu5i : fpc5_out_type;
  trap                            : out std_logic; tt : out std_logic_vector(5 downto 0); pccomp : in std_logic_vector(3 downto 0)) is
    variable illegal_inst, privileged_inst  : std_logic;
    variable cp_disabled, fp_disabled, fpop : std_logic;
    variable op                             : std_logic_vector(1 downto 0);
    variable op2                            : std_logic_vector(2 downto 0);
    variable op3                            : std_logic_vector(5 downto 0);
    variable rd                             : std_logic_vector(4 downto 0);
    variable inst                           : word;
    variable wph                            : std_logic;
    variable ticc_exc                       : std_logic;
  begin
    inst := r.a.ctrl.inst(lane);
    trap := r.a.ctrl.trap(lane);
    tt   := r.a.ctrl.tt(lane);
    if r.a.ctrl.inst_valid(lane) = '1' then
      op              := inst(31 downto 30);
      op2             := inst(24 downto 22);
      op3             := inst(24 downto 19);
      rd              := inst(29 downto 25);
      illegal_inst    := '0';
      privileged_inst := '0';
      cp_disabled     := '0';
      fp_disabled     := '0';
      fpop            := '0';
      case op is
        when CALL => null;
        when FMT2 =>
          case op2 is
            when SETHI | BICC => null;
            when FBFCC        =>
              if FPEN then
                fp_disabled := not r.w.s.ef;
              else
                fp_disabled := '1';
              end if;
            when CBCCC =>
              if (not CPEN) or (r.w.s.ec = '0') then
                cp_disabled := '1';
              end if;
            when others =>
              illegal_inst := '1';
          end case;
        when FMT3 =>
          case op3 is
            when IAND | ANDCC | ANDN | ANDNCC | IOR | ORCC | ORN | ORNCC | IXOR |
              XORCC | IXNOR | XNORCC | ISLL | ISRL | ISRA | MULSCC | IADD | ADDX |
              ADDCC | ADDXCC | ISUB | SUBX | SUBCC | SUBXCC | FLUSH | JMPL | TICC |
              SAVE | RESTORE | RDY => null;
            when TADDCC | TADDCCTV | TSUBCC | TSUBCCTV =>
              if notag = 1 then
                illegal_inst := '1';
              end if;
            when UMAC | SMAC =>
              if not MACEN then
                illegal_inst := '1';
              end if;
            when UMUL | SMUL | UMULCC | SMULCC =>
              if not MULEN then
                illegal_inst := '1';
              end if;
            when UDIV | SDIV | UDIVCC | SDIVCC =>
              if not DIVEN then
                illegal_inst := '1';
              end if;
            when RETT =>
              illegal_inst    := r.a.et;
              privileged_inst := not r.a.su;
            when RDPSR | RDTBR | RDWIM =>
              privileged_inst := not r.a.su;
            when WRY =>
              if rd(4) = '1' and rd(3 downto 0) /= "0010" then  -- %ASR16-17, %ASR19-31
                privileged_inst := not r.a.su;
              end if;
            when WRPSR =>
              privileged_inst := not r.a.su;
            when WRWIM | WRTBR =>
              privileged_inst := not r.a.su;
            when FPOP1 | FPOP2 =>
              if FPEN then
                fp_disabled := not r.w.s.ef;
                fpop        := '1';
              else
                fp_disabled := '1';
                fpop        := '0';
              end if;
              if r.a.fpc_ctrl.illegal_fp = '1' then
                illegal_inst := '1';
              end if;
            when CPOP1 | CPOP2 =>
              if (not CPEN) or (r.w.s.ec = '0') then
                cp_disabled := '1';
              end if;
            when others =>
              illegal_inst := '1';
          end case;
        when others =>                  -- LDST
          case op3 is
            when LDD | ISTD =>
              illegal_inst := rd(0);    -- trap if odd destination register
            when LD | LDUB | LDSTUB | LDUH | LDSB | LDSH | ST | STB | STH | SWAP =>
              null;
            when LDDA | STDA =>
              illegal_inst := inst(13) or rd(0);
              if (npasi = 0) or (inst(12) = '0') then
                privileged_inst := not r.a.su;
              end if;
            when LDA | LDUBA| LDSTUBA | LDUHA | LDSBA | LDSHA | STA | STBA | STHA | SWAPA =>
              illegal_inst := inst(13);
              if (npasi = 0) or (inst(12) = '0') then
                privileged_inst := not r.a.su;
              end if;
            when CASA =>
              illegal_inst := inst(13);
              if (inst(12 downto 5) /= X"0A") then
                privileged_inst := not r.a.su;
              end if;
            when LDDF | STDF | LDF | LDFSR | STF | STFSR =>
              if FPEN then
                fp_disabled := not r.w.s.ef;
              else
                fp_disabled := '1';
              end if;
              if r.a.fpc_ctrl.illegal_fp = '1' then
                illegal_inst := '1';
              end if;
            when STDFQ =>
              privileged_inst := not r.a.su;
              if (not FPEN) or (r.w.s.ef = '0') then
                fp_disabled := '1';
              end if;
            when STDCQ =>
              privileged_inst := not r.a.su;
              if (not CPEN) or (r.w.s.ec = '0') then
                cp_disabled := '1';
              end if;
            when LDC | LDCSR | LDDC | STC | STCSR | STDC =>
              if (not CPEN) or (r.w.s.ec = '0') then
                cp_disabled := '1';
              end if;
            when others =>
              illegal_inst := '1';
          end case;
      end case;

      wph := wphit(lane, r, wpr, dbgi, dsur, pccomp);


      trap := '1';
      if r.a.ctrl.trap(lane) = '1' then
        tt := TT_IAEX;
      elsif privileged_inst = '1' then
        tt := TT_PRIV;
      elsif illegal_inst = '1' then
        tt := TT_IINST;
      elsif fp_disabled = '1' then
        tt := TT_FPDIS;
      elsif cp_disabled = '1' then
        tt := TT_CPDIS;
      elsif FPEN and r.a.fpc_ctrl.trap_fp = '1' and (is_fpop(r.a.ctrl.inst(lane)) = '1' or is_fpu_branch(r.a.ctrl.inst(lane)) = '1') then
        tt := TT_FPEXC;
      elsif FPEN and is_fpu_branch(r.a.ctrl.inst(lane)) = '1' and fpu5i.trapon_flop = '1' then
        tt := TT_FPEXC;
      elsif wph = '1' then
        tt := TT_WATCH;
      elsif r.a.wovf(lane) = '1' then
        tt := TT_WINOF;
      elsif r.a.wunf(lane) = '1' then
        tt := TT_WINUF;
      else
        trap := '0';
        tt   := (others => '0');
      end if;
    end if;
  end;

-- instructions that write the condition codes (psr.icc)

  procedure wicc_y_gen(valid : std_logic; inst : word; wicc, wy : out std_logic) is
  begin
    wicc := '0';
    wy   := '0';
    if inst(31 downto 30) = FMT3 and valid = '1' then
      case inst(24 downto 19) is
        when SUBCC | TSUBCC | TSUBCCTV | ADDCC | ANDCC | ORCC | XORCC | ANDNCC |
          ORNCC | XNORCC | TADDCC | TADDCCTV | ADDXCC | SUBXCC | WRPSR =>
          wicc := '1';
          if (pwrpsr /= 0) and inst(24 downto 19) = WRPSR and inst(29 downto 25) /= "00000" then
            wicc := '0';
          end if;
        when WRY =>
          if inst(29 downto 25) = "00000" then
            wy := '1';
          end if;
        when MULSCC =>
          wicc := '1';
          wy   := '1';
        when UMULCC | SMULCC =>
          wy   := '1';
          wicc := '1';
        when UMUL | SMUL =>
          wy := '1';
        when UDIVCC | SDIVCC =>
          wicc := '1';
        when others =>
      end case;
    end if;
  end;

-- select cwp

  procedure cwp_gen(r, v :     registers; valid, wcwp : std_logic; ncwp : cwptype;
  cwp                    : out cwptype; cwp_updated : out std_logic) is
  begin
    cwp_updated := '0';
    if (r.x.rstate = trap) or (r.x.rstate = dsu2) or (rstn = '0') then
      cwp := v.w.s.cwp;
    elsif (wcwp = '1') and (valid = '1') then
      cwp         := ncwp;
      cwp_updated := '1';
    elsif r.m.wcwp(0) = '1' then
      cwp := r.m.result(0)(NWINLOG2-1 downto 0);
    elsif r.m.wcwp(1) = '1' then
      cwp := r.m.result(1)(NWINLOG2-1 downto 0);
    else
      cwp := r.d.cwp;
    end if;
    
  end;

-- generate wcwp in ex stage

  procedure cwp_ex(inst : in word; valid : in std_logic; wcwp : out std_logic) is
  begin
    if (inst(31 downto 30) = FMT3) and
      (inst(24 downto 19) = WRPSR) and
      (pwrpsr = 0 or inst(29 downto 25) = "00000")
    then
      wcwp := valid;
    else
      wcwp := '0';
    end if;
  end;

-- generate next cwp & window under- and overflow traps

  procedure cwp_ctrl(r : in registers; xc_wim : in std_logic_vector(NWIN-1 downto 0);
  inst                 :    word; de_cwp : out cwptype; wovf_exc, wunf_exc, wcwp : out std_logic) is
    variable op   : std_logic_vector(1 downto 0);
    variable op3  : std_logic_vector(5 downto 0);
    variable wim  : word;
    variable ncwp : cwptype;
  begin
    op                   := inst(31 downto 30);
    op3                  := inst(24 downto 19);
    wovf_exc             := '0';
    wunf_exc             := '0';
    wim                  := (others => '0');
    wim(NWIN-1 downto 0) := xc_wim;
    ncwp                 := r.d.cwp;
    wcwp                 := '0';

    if (op = FMT3) and ((op3 = RETT) or (op3 = RESTORE) or (op3 = SAVE)) then
      wcwp := '1';
      if (op3 = SAVE) then
        if (not CWPOPT) and (r.d.cwp = CWPMIN) then
          ncwp := CWPMAX;
        else
          ncwp := r.d.cwp - 1;
        end if;
      else
        if (not CWPOPT) and (r.d.cwp = CWPMAX) then
          ncwp := CWPMIN;
        else
          ncwp := r.d.cwp + 1;
        end if;
      end if;
      if wim(conv_integer(ncwp)) = '1' then
        if op3 = SAVE then
          wovf_exc := '1';
        else
          wunf_exc := '1';
        end if;
      end if;
    end if;
    de_cwp := ncwp;
  end;


  --LEON5 instruction control
  procedure instruction_control(r               :     registers;
                                v               :     registers;
                                fpu5o           :     fpc5_out_type;
                                de_inst         :     inst_pair_type;
                                inst            :     inst_pair_type;
                                inst_valid      :     std_logic_vector(1 downto 0);
                                mul_start       : out std_logic;
                                mul_lane        : out std_logic;
                                div_start       : out std_logic;
                                div_lane        : out std_logic;
                                div_flush       : out std_logic;
                                hold_issue      : out std_logic;
                                hold_issue_call : out std_logic;
                                mem_wicc        : out std_logic;
                                exc_wicc        : out std_logic;
                                alu_dexc_a      : out std_logic_vector(1 downto 0);
                                mask_divstart   : out std_logic;
                                waiting_ficc    : out std_logic;
                                hold_issue_type : out std_logic_vector(31 downto 0)) is
    variable op_0, op_1   : std_logic_vector(1 downto 0);
    variable op2_0, op2_1 : std_logic_vector(2 downto 0);
    variable op3_0, op3_1 : std_logic_vector(5 downto 0);

    variable ldd_ve               : std_logic;
    variable hold_issue_int       : std_logic;
    variable hold_issue_wicc      : std_logic;
    variable hold_issue_wicc_mult : std_logic;
    variable load_dependency      : std_logic_vector(1 downto 0);
    variable wicc_mem_delayed     : std_logic;
    variable hold_issue_type_int  : std_logic_vector(31 downto 0);
    variable hold_issue_lane      : std_logic;
    variable alu_dexc_a_t         : std_logic_vector(1 downto 0);
    variable hold_issue_div       : std_logic;
    variable late_mult_annul      : std_logic_vector(1 downto 0);
    variable late_load_annul      : std_logic_vector(1 downto 0);
    variable wicc_active          : std_logic;
    variable branch_active        : std_logic;
    variable late_depen           : std_logic_vector(1 downto 0);
  begin
    hold_issue          := '0';
    hold_issue_call     := '0';
    mul_start           := '0';
    mul_lane            := '0';
    div_start           := '0';
    div_lane            := '0';
    div_flush           := '0';
    mem_wicc            := '0';
    exc_wicc            := '0';
    alu_dexc_a_t        := "00";
    hold_issue_wicc     := '0';
    hold_issue_int      := '0';
    mask_divstart       := '0';
    hold_issue_div      := '0';
    load_dependency     := "00";
    hold_issue_type_int := (others => '0');
    hold_issue_lane     := '0';

    hold_issue_wicc_mult := '0';
    late_mult_annul      := "00";
    late_load_annul      := "00";
    waiting_ficc         := '0';

    

    op_0  := inst(0)(31 downto 30);
    op2_0 := inst(0)(24 downto 22);
    op3_0 := inst(0)(24 downto 19);
    op_1  := inst(1)(31 downto 30);
    op2_1 := inst(1)(24 downto 22);
    op3_1 := inst(1)(24 downto 19);


    --wicc_active means there is a instruction in the execute, memory or
    --exception stage in the pipeline that will modify ICC
    --branch_active means there is a branch instruction in the execute, memory,
    --or exception stage in the pipeline which is not resolved yet
    wicc_mem_delayed := r.m.ctrl.wicc_dexc or r.m.ctrl.wicc_dmem or r.m.ctrl.wicc_muldiv;
    wicc_active      := '0';
    if (r.e.ctrl.inst_valid(1) = '1' and r.e.ctrl.wicc = '1') or
      (r.m.ctrl.inst_valid(1) = '1' and wicc_mem_delayed = '1') or
      (r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.wicc_dexc = '1') then
      wicc_active := '1';
    end if;
    branch_active := '0';
    for i in 0 to 1 loop
      if (r.e.ctrl.inst_valid(i) = '1' and r.e.ctrl.branch(i) = '1') or
        (r.m.ctrl.inst_valid(i) = '1' and r.m.ctrl.branch(i) = '1') then
        branch_active := '1';
      end if;
    end loop;

    case op_0 is
      when FMT3 =>
        case op3_0 is
          when UMUL | SMUL | UMULCC | SMULCC =>
            mul_start := '1';
          when others =>
            null;
        end case;
      when others =>
        null;
    end case;

    case op_1 is
      when FMT3 =>
        case op3_1 is
          when UMUL | SMUL | UMULCC | SMULCC =>
            mul_start := '1';
            mul_lane  := '1';
          when UDIV | SDIV | UDIVCC | SDIVCC =>
            div_start := '1';
            div_lane  := '1';
          when others =>
            null;
        end case;
      when others =>
        null;
    end case;

    --Late ALU checks are done first so that if there is any other dependency
    --that will cause an hold issue it will be overwritten
    ---------------------------------------------------------------------------
    --forwarding hazard Multiplication 
    ---------------------------------------------------------------------------
    for i in 0 to 1 loop
      if r.e.ctrl.inst_valid(i) = '1' and r.e.ctrl.inst(i)(31 downto 30) = FMT3 and r.e.ctrl.rdw(i) = '1' then
        if r.e.ctrl.inst(i)(24 downto 19) = UMUL or r.e.ctrl.inst(i)(24 downto 19) = SMUL
          or r.e.ctrl.inst(i)(24 downto 19) = UMULCC or r.e.ctrl.inst(i)(24 downto 19) = SMULCC then
          for j in 0 to 1 loop
            if (r.a.ctrl.inst_valid(j) = '1') and ((r.a.rs1(j) = r.e.ctrl.rd(i)) or (r.a.rs2(j) = r.e.ctrl.rd(i))) then
              hold_issue_int         := '1';
              hold_issue_type_int(0) := '1';
              if j = 1 then
                hold_issue_wicc := '1';
              end if;
              hold_issue_wicc_mult := '1';

              if is_late_alu_op(r.a.ctrl.inst(j)) = '1' and LATEALU = '1' and not(DLATEWICC = '1' and is_wicc(r.a.ctrl.inst(j)) = '1') then
                alu_dexc_a_t(j) := '1';
              else
                late_mult_annul(j) := '1';
              end if;
            end if;
          end loop;
        end if;
      end if;
    end loop;

    --when issuing to late alu due to mult dependence, make sure that the other instruction
    --in the pair can also be issued to late alu if that one also have dependence to same mult, 
    --otherwise hold the pipeline
    if hold_issue_wicc_mult = '1' and late_mult_annul = "00" then
      hold_issue_int         := '0';
      hold_issue_type_int(0) := '1';
    else
      alu_dexc_a_t := "00";
    end if;


    ldd_ve := '0';
    if is_ldd_int(r.e.ctrl.inst(0)) = '1' then
      ldd_ve := '1';
    end if;

    if is_load_int(r.e.ctrl.inst(0)) = '1' and r.e.ctrl.inst_valid(0) = '1' and r.e.ctrl.delay_annuled(0) = '0' and r.e.ctrl.rdw(0) = '1' and r.e.ctrl.no_forward(0) = '0' then

      
      if (r.a.ctrl.inst_valid(0) = '1') then
        if ((r.a.rs1(0) = r.e.ctrl.rd(0)) or (r.a.rs2(0) = r.e.ctrl.rd(0))) then
          load_dependency(0)     := '1';
          hold_issue_type_int(6) := '1';
        end if;
        if (ldd_ve = '1' and (r.a.rs1(0)(RFBITS downto 1) = r.e.ctrl.rd(0)(RFBITS downto 1) or
                                r.a.rs2(0)(RFBITS downto 1) = r.e.ctrl.rd(0)(RFBITS downto 1))) then     
          load_dependency(0)     := '1';
          hold_issue_type_int(6) := '1';
        end if;
      end if;

      if (r.a.ctrl.inst_valid(1) = '1') then
        if ((r.a.rs1(1) = r.e.ctrl.rd(0)) or (r.a.rs2(1) = r.e.ctrl.rd(0))) then
          hold_issue_wicc        := '1';
          load_dependency(1)     := '1';
          hold_issue_type_int(6) := '1';
          hold_issue_lane        := '1';
        end if;
        if (ldd_ve = '1' and (r.a.rs1(1)(RFBITS downto 1) = r.e.ctrl.rd(0)(RFBITS downto 1) or
                                r.a.rs2(1)(RFBITS downto 1) = r.e.ctrl.rd(0)(RFBITS downto 1))) then
          hold_issue_wicc        := '1';
          load_dependency(1)     := '1';
          hold_issue_type_int(6) := '1';
          hold_issue_lane        := '1';
        end if;
      end if;
      
    end if;

    --when issuing to late alu due to load dependence, make sure that the other instruction
    --in the pair can also be issued to late alu if that one also have dependence to same load,
    --otherwise hold the pipeline
    for i in 0 to 1 loop
      if load_dependency(i) = '1' then
        if is_late_alu_op(r.a.ctrl.inst(i)) = '1' and LATEALU = '1' and not(DLATEWICC = '1' and is_wicc(r.a.ctrl.inst(i)) = '1') then
          alu_dexc_a_t(i) := '1';
        else
          late_load_annul(i) := '1';
        end if;
      end if;
    end loop;

    if load_dependency /= "00" then
      if late_load_annul = "00" and hold_issue_int = '0' then
        hold_issue_type_int(6) := '0';
      else
        hold_issue_int := '1';
        alu_dexc_a_t   := "00";
      end if;
    end if;

    --characterize load dependency
    --load dependency to AGU or MUL operation can not be
    --resolved with late ALU
    if hold_issue_type_int(6) = '1' then
      if (is_load_int(r.a.ctrl.inst(0)) = '1' and hold_issue_lane = '0') or
        (is_load_int(r.a.ctrl.inst(1)) = '1' and hold_issue_lane = '1') then
        hold_issue_type_int(31) := '1';
      end if;

      if (is_mul(r.a.ctrl.inst(0)) = '1' and hold_issue_lane = '0') or
        (is_mul(r.a.ctrl.inst(1)) = '1' and hold_issue_lane = '1') then
        hold_issue_type_int(30) := '1';
      end if;
    end if;

    --mult/div to mult/div forwarding thorugh execute stage does not exists in order to
    --reduce critical path
    for i in 0 to 1 loop
      if r.m.ctrl.inst_valid(i) = '1' and r.m.ctrl.inst(i)(31 downto 30) = FMT3 and r.m.ctrl.rdw(i) = '1' then
        if is_mul(r.m.ctrl.inst(i)) = '1' or (i = 1 and is_div(r.m.ctrl.inst(i)) = '1') then
          for j in 0 to 1 loop
            if (r.a.ctrl.inst_valid(j) = '1') and (is_mul(r.a.ctrl.inst(j)) = '1' or (is_div(r.a.ctrl.inst(j)) = '1' and j = 1)) and ((r.a.rs1(j) = r.m.ctrl.rd(i)) or (r.a.rs2(j) = r.m.ctrl.rd(i))) then
              hold_issue_int         := '1';
              hold_issue_type_int(0) := '1';
            end if;
          end loop;
        end if;
      end if;
      if r.e.ctrl.inst_valid(i) = '1' and r.e.ctrl.inst(i)(31 downto 30) = FMT3 and r.e.ctrl.rdw(i) = '1' then
        --division check here is not needed since it is done in forwarding
        --hazard (DIV) check
        if is_mul(r.e.ctrl.inst(i)) = '1' then
          for j in 0 to 1 loop
            if (r.a.ctrl.inst_valid(j) = '1') and (is_mul(r.a.ctrl.inst(j)) = '1' or (is_div(r.a.ctrl.inst(j)) = '1' and j = 1)) and ((r.a.rs1(j) = r.e.ctrl.rd(i)) or (r.a.rs2(j) = r.e.ctrl.rd(i))) then
              hold_issue_int         := '1';
              hold_issue_type_int(0) := '1';
            end if;
          end loop;
        end if;
      end if;
    end loop;

    --Don't start a divison until Y register is updated
    if r.a.ctrl.inst_valid(1) = '1' and is_div(r.a.ctrl.inst(1)) = '1' then
      for i in 0 to 1 loop
        if (r.e.ctrl.wy(i) = '1' and r.e.ctrl.inst_valid(i) = '1') or
          (r.m.ctrl.wy(i) = '1' and r.m.ctrl.inst_valid(i) = '1') then
          hold_issue_int := '1';
        end if;
      end loop;
    end if;

    ---------------------------------------------------------------------------
    --forwarding hazard (DIV) data can not be used when div is in execute stage,
    --stall the stages FETCH/DECODE/ACCESS
    ---------------------------------------------------------------------------
    if r.e.ctrl.inst_valid(1) = '1' and is_div(r.e.ctrl.inst(1)) = '1' then
      if ((r.a.ctrl.inst_valid(0) = '1') and ((r.a.rs1(0) = r.e.ctrl.rd(1)) or (r.a.rs2(0) = r.e.ctrl.rd(1)))) or
        ((r.a.ctrl.inst_valid(1) = '1') and ((r.a.rs1(1) = r.e.ctrl.rd(1)) or (r.a.rs2(1) = r.e.ctrl.rd(1)))) then
        hold_issue_int         := '1';
        hold_issue_type_int(1) := '1';
      end if;
    end if;

    if is_store(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.inst_valid(0) = '1' and is_store(r.e.ctrl.inst(0)) = '1' and r.e.ctrl.inst_valid(0) = '1' then
      if r.d.b2bstore_en = '1' then
        if not ((r.a.ctrl.inst(0)(24 downto 19) = ISTD or r.a.ctrl.inst(0)(24 downto 19) = ST
                  or r.a.ctrl.inst(0)(24 downto 19) = STF or r.a.ctrl.inst(0)(24 downto 19) = STDF) and
                 (r.e.ctrl.inst(0)(24 downto 19) = ISTD or r.e.ctrl.inst(0)(24 downto 19) = ST
                  or r.e.ctrl.inst(0)(24 downto 19) = STF or r.e.ctrl.inst(0)(24 downto 19) = STDF) ) then
          hold_issue_int         := '1';
          hold_issue_type_int(2) := '1';
        end if;
      else
        hold_issue_int         := '1';
        hold_issue_type_int(2) := '1';
      end if;
    end if;

    if is_load(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.inst_valid(0) = '1' and is_store(r.e.ctrl.inst(0)) = '1' and r.e.ctrl.inst_valid(0) = '1' then
      hold_issue_int         := '1';
      hold_issue_type_int(3) := '1';
    end if;

    if is_atomic(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.inst_valid(0) = '1' then
      --no speculative atomic instruction
      --in addition don't start atomic operation until a jmpl/rett is resolved
      --the reason we check r.x.ctrl.branch here is that atomic should not
      --start even on the cycle where branch is resolved and can cause a miss signal
      --because that would fail the sate machine
      for i in 0 to 1 loop
        if (r.e.ctrl.branch(i) = '1' and r.e.ctrl.inst_valid(i) = '1') or
          (r.m.ctrl.branch(i) = '1' and r.m.ctrl.inst_valid(i) = '1') or
          (r.x.ctrl.branch(i) = '1' and r.x.ctrl.inst_valid(i) = '1') or
          r.d.ct_state = toc_e then
          hold_issue_int         := '1';
          hold_issue_type_int(5) := '1';
        end if;
      end loop;
    end if;

    ---------------------------------------------------------------------------
    --For mulscc operations the actual dependency of the register is not checked
    --this can cause some unnecessary stalls but can improve the timing path
    --for hold signal. Since mulscc is not compiler generated instrcution
    --no need to optimize the performance for it.
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --Don't allow mulscc to proceed execute stage if RS1 depends on load
    --forwarding from exception stage we don't want to add a shifter to the execute stage
    ---------------------------------------------------------------------------
    if is_load_int(r.m.ctrl.inst(0)) = '1' and r.m.ctrl.inst_valid(0) = '1' then
      if r.a.ctrl.inst_valid(1) = '1' and r.a.ctrl.inst(1)(31 downto 30) = "10" and r.a.ctrl.inst(1)(24 downto 19) = MULSCC then
        hold_issue_int         := '1';
        hold_issue_type_int(7) := '1';
      end if;
    end if;

    ---------------------------------------------------------------------------
    --Don't allow mulscc to proceed to execute stage if RS1 depends on MUL or division
    --we don't want to create a shifter in execute stage
    ---------------------------------------------------------------------------
    for i in 0 to 1 loop
      if (is_divmul(r.e.ctrl.inst(i)) = '1' and r.e.ctrl.inst_valid(i) = '1') or
        (is_divmul(r.m.ctrl.inst(i)) = '1' and r.m.ctrl.inst_valid(i) = '1') then
        if r.a.ctrl.inst_valid(1) = '1' and r.a.ctrl.inst(1)(31 downto 30) = "10" and r.a.ctrl.inst(1)(24 downto 19) = MULSCC then
          hold_issue_int         := '1';
          hold_issue_type_int(7) := '1';
        end if;
      end if;
    end loop;

    ---------------------------------------------------------------------------
    --Don't allow mulscc to proceed to execute stage if there is a late flag
    --calculation
    ---------------------------------------------------------------------------
    if r.a.ctrl.inst_valid(1) = '1' and r.a.ctrl.inst(1)(31 downto 30) = "10" and r.a.ctrl.inst(1)(24 downto 19) = MULSCC then
      if ((r.e.ctrl.wicc_dexc = '1' or r.e.ctrl.wicc_dmem = '1' or r.e.ctrl.wicc_muldiv = '1') and r.e.ctrl.inst_valid(1) = '1') or
        ((r.m.ctrl.wicc_dexc = '1' or r.m.ctrl.wicc_muldiv = '1') and r.m.ctrl.inst_valid(1) = '1') then       
        --right now mulscc uses combinatorial v.m.icc hence there is
        --forwarding when icc is calculated.
        hold_issue_int         := '1';
        hold_issue_type_int(7) := '1';
      end if;
    end if;

    ---------------------------------------------------------------------------
    --Division stall
    ---------------------------------------------------------------------------
    hold_issue_div := '0';
    for i in 0 to 1 loop
      if r.a.ctrl.inst_valid(i) = '1' and r.a.ctrl.inst(i)(31 downto 30) = FMT3 and
        (r.a.ctrl.inst(i)(24 downto 19) = UDIV or r.a.ctrl.inst(i)(24 downto 19) = SDIV
         or r.a.ctrl.inst(i)(24 downto 19) = UDIVCC or r.a.ctrl.inst(i)(24 downto 19) = SDIVCC) then
        hold_issue_div := '1';
        if v.e.ctrl.inst_valid(i) = '0' then
          --divison operation is going to be annuled
          div_flush := '1';
        end if;
      end if;
    end loop;

    --no speculative jump register
    if ((r.a.ctrl.jmpl_op = '1' or r.a.ctrl.rett_op = '1') and r.a.ctrl.inst_valid(1) = '1') then
      if branch_active = '1' then
        hold_issue_int          := '1';
        hold_issue_type_int(10) := '1';
      end if;
    end if;

    --dont allow brcc,a and st for late branch
    --ld is handled by speculative load
    if (is_branch_annul_int(r.a.ctrl.inst(1)) = '1' and r.a.ctrl.inst_valid(1) = '1' and r.a.ctrl.swap = '1' and r.a.ctrl.inst_valid(0) = '1' and (is_store(r.a.ctrl.inst(0)) = '1' or (is_load(r.a.ctrl.inst(0)) = '1' and r.d.specload_en = '0'))) then
      if (r.e.ctrl.wicc_dexc = '1' or r.e.ctrl.wicc_muldiv = '1') then
        hold_issue_int          := '1';
        hold_issue_type_int(11) := '1';
      end if;
    end if;

    --ADDX SUBX can not proceed when there is a late flag calculation
    if (r.a.ctrl.inst_valid(0) = '1' and is_opx(r.a.ctrl.inst(0)) = '1') or
      (r.a.ctrl.inst_valid(1) = '1' and is_opx(r.a.ctrl.inst(1)) = '1') then
      if (r.e.ctrl.inst_valid(1) = '1' and (r.e.ctrl.wicc_dexc = '1' or r.e.ctrl.wicc_dmem = '1' or r.e.ctrl.wicc_muldiv = '1')) or
        ((r.m.ctrl.wicc_dexc = '1' or r.m.ctrl.wicc_muldiv = '1') and r.m.ctrl.inst_valid(1) = '1') then
        --right now ADDx/SUBX uses combinatorial v.m.icc hence there is
        --forwarding when icc is calculated.
        hold_issue_int          := '1';
        hold_issue_type_int(12) := '1';
      end if;
    end if;

    --valid bit ins rs1 and rs2 will prevent false positives
    --late alu assignment for arithmetic ops
    late_depen := "00";
    for i in 0 to 1 loop
      if (is_late_alu_depen(r, r.a.rs1(i)) = '1' or is_late_alu_depen(r, r.a.rs2(i)) = '1') and r.a.ctrl.inst_valid(i) = '1' then
        late_depen(i) := '1';
        if is_late_alu_op(r.a.ctrl.inst(i)) = '1' and LATEALU = '1' and (DLATEWICC = '0' or is_wicc(r.a.ctrl.inst(i)) = '0') then
          alu_dexc_a_t(i) := '1';
          if i = 1 and is_wicc(r.a.ctrl.inst(i)) = '1' then
            mem_wicc := '0';
            exc_wicc := '1';
          end if;
        else
          hold_issue_int          := '1';
          hold_issue_type_int(16) := '1';
        end if;
      end if;
    end loop;

    --If there is a flag calculation operation which would not update the
    --register file then it can be calculated in memory stage since no data forwrding
    --is needed. This would reduce branch missprediction penalty.
    if hold_issue_wicc = '1' and hold_issue_int = '0' and is_wicc(r.a.ctrl.inst(1)) = '1' and is_late_alu_op(r.a.ctrl.inst(1)) = '1' and r.a.ctrl.rdw(1) = '0' then
      --no direct forwarding from mul/div result and late alu result to memory
      --stage
      if is_late_alu_depen_exe(r, r.a.rs1(1)) = '0' and is_late_alu_depen_exe(r, r.a.rs2(1)) = '0' and hold_issue_wicc_mult = '0' then
        --alu_dexc_a_t(1) := '0';
        mem_wicc        := '1';
      else
        --alu_dexc_a_t(1) := '1';
        exc_wicc        := '1';
      end if;
    end if;

    --if a ALUcc operations has a load/mul dependency and destination register
    --is written the result will be calculated in exception stage but the flag
    --can actually be calculated in memory stage to reduce the branch
    --missprediction latench
    --if there is a mult dependency don't calculate it on mem stage
    --since there is no direct forwarding path
    if hold_issue_wicc = '1' and hold_issue_int = '0' and is_wicc(r.a.ctrl.inst(1)) = '1' and is_late_alu_op(r.a.ctrl.inst(1)) = '1' and r.a.ctrl.rdw(1) = '1' then
      --no direct forwarding from mul/div result and late alu result to memory
      --stage
      if is_late_alu_depen_exe(r, r.a.rs1(1)) = '0' and is_late_alu_depen_exe(r, r.a.rs2(1)) = '0' and hold_issue_wicc_mult = '0' then
        mem_wicc := '1';
      else
        exc_wicc := '1';
      end if;
      --alu_dexc_a_t(1) := '1';
    end if;

    --Don't allow speculative flush
    if (r.a.ctrl.inst_valid(0) = '1' and r.a.ctrl.trap(0) = '0' and is_flush(r.a.ctrl.inst(0)) = '1') then
      if wicc_active = '1' then
        hold_issue_int          := '1';
        hold_issue_type_int(14) := '1';
      end if;
    end if;

    --Dont allow RDPSR if there is a late cc op
    if r.a.ctrl.inst_valid(0) = '1' and is_rdpsr(r.a.ctrl.inst(0)) = '1' then
      if r.e.ctrl.inst_valid(1) = '1' then
        if r.e.ctrl.wicc_dexc = '1' or r.e.ctrl.wicc_dmem = '1' or r.e.ctrl.wicc_muldiv = '1' then
          hold_issue_int          := '1';
          hold_issue_type_int(15) := '1';
        end if;
      end if;
      if r.m.ctrl.inst_valid(1) = '1' then
        if r.m.ctrl.wicc_dexc = '1' then
          hold_issue_int          := '1';
          hold_issue_type_int(15) := '1';
        end if;
      end if;
    end if;

    --TICC,TADD/SUBcctv is resolved in memory stage
    if (is_tcctv(r.a.ctrl.inst(1)) = '1' and r.a.ctrl.inst_valid(1) = '1') or
      (is_ticc(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.inst_valid(0) = '1') then
      if r.e.ctrl.inst_valid(1) = '1' and (r.e.ctrl.wicc_dexc = '1' or r.e.ctrl.wicc_muldiv = '1') then
        hold_issue_int := '1';
      end if;
    end if;


    --for cascaded operations if old operation depends on late alu, new
    --operation should also be calculated in the late alu stage
    --this operations are always swapped
    if r.a.use_sethi /= "00" or r.a.use_logic /= "00" or r.a.use_addsub /= "00" or r.a.use_logicshift = '1' then
      if alu_dexc_a_t(1) = '1' then
        alu_dexc_a_t(0) := '1';
      end if;
    end if;
       
    --if a store value depends on a register in access or execute stage which
    --will be calculated in the late alu stall one cycle because only registered
    --result of late alu can be used as a store word
    if r.a.ctrl.inst_valid(0) = '1' and is_store_int(r.a.ctrl.inst(0)) = '1' then
      if is_late_alu_depen_exe(r, r.a.rs3) = '1' then
        hold_issue_int          := '1';
        hold_issue_type_int(17) := '1';
      end if;
      if is_stdb(r.a.ctrl.inst(0)) = '1' and is_late_alu_depen_exe(r, r.a.rs3(RFBITS downto 1)&'1') = '1' then
        hold_issue_int          := '1';
        hold_issue_type_int(17) := '1';
      end if;
      if r.a.ctrl.swap = '1' and r.a.ctrl.inst_valid(1) = '1' and r.a.ctrl.rdw(1) = '1' and alu_dexc_a_t(1) = '1' then
        if r.a.rs3 = r.a.ctrl.rd(1) then
          hold_issue_int          := '1';
          hold_issue_type_int(17) := '1';
        end if;
        if is_stdb(r.a.ctrl.inst(0)) = '1' and r.a.rs3(RFBITS downto 1) = r.a.ctrl.rd(1)(RFBITS downto 1) then
          hold_issue_int          := '1';
          hold_issue_type_int(17) := '1';
        end if;
      end if;
    end if;

    if r.a.use_memaddr_add1 = '1' and alu_dexc_a_t(1) = '1' then
      hold_issue_int          := '1';
      hold_issue_type_int(18) := '1';
    end if;


    if r.d.ct_state = toc_e then
      for i in 0 to 1 loop
        if is_branch(r.a.ctrl.inst(i)) = '1' and r.a.ctrl.inst_valid(i) = '1' then
          --if branch is in the delay slot of a CTI it needs to be able to
          --resolved in execute stage
          if (r.e.ctrl.inst_valid(1) = '1' and (r.e.ctrl.wicc_dexc = '1' or r.e.ctrl.wicc_dmem = '1' or r.e.ctrl.wicc_muldiv = '1'))
            or (r.m.ctrl.inst_valid(1) = '1' and (r.m.ctrl.wicc_dexc = '1' or r.m.ctrl.wicc_muldiv = '1')) then
            hold_issue_int          := '1';
            hold_issue_type_int(19) := '1';
          end if;
        end if;
      end loop;

      --don't allow speculative access for CTI couples
      for i in 0 to 1 loop
        if r.e.ctrl.spec_access(i) = '1' and r.e.ctrl.inst_valid(i) = '1' and r.e.ctrl.branch(i) = '1' then
          hold_issue_int          := '1';
          hold_issue_type_int(19) := '1';
        end if;
      end loop;
    end if;

    --FPbranch needs to stall if fpicc is not ready
    --or branch needs to be resolved in execute stage
    for i in 0 to 1 loop
      if r.a.ctrl.branch(i) = '1' and r.a.ctrl.inst_valid(i) = '1' and is_fpu_branch(r.a.ctrl.inst(i)) = '1' then
        --we have to assert waiting_ficc even if branch will be resolved due to
        --the case that resolvable branch can be stalled due to anoher
        --instruction which its duall issued with and we don't want to use hold_issue
        --signal in the fpc issue
        waiting_ficc := '1';
        if fpu5o.fccready = '0' and fpu5o.trapon_flop = '0' then
          hold_issue_int := '1';
        end if;
      end if;
    end loop;

    if BPRED = '0' then
      --when branch prediction is disabled branches need to stall in acess
      --stage if there is an unresolved wicc
      for i in 0 to 1 loop
        if r.a.ctrl.branch(i) = '1' and r.a.ctrl.inst_valid(i) = '1' then
          if wicc_active = '1' then
            hold_issue_int          := '1';
            hold_issue_type_int(19) := '1';
          end if;
        end if;
      end loop;
    end if;

    --Don't let WSRI/MUL(scc)/DIV/TICC,TCCTV/SAVE/RESTORE go forward if they are predicted to be
    --annuled and branch is not resolved
    for i in 0 to 1 loop
      if (is_saverestore(r.a.ctrl.inst(i)) = '1' or is_divmulscc(r.a.ctrl.inst(i)) = '1'
          or is_ticc(r.a.ctrl.inst(i)) = '1' or is_tcctv(r.a.ctrl.inst(i)) = '1' or is_wsri(r.a.ctrl.inst(i)) = '1')

        and r.a.ctrl.inst_valid(i) = '1' and r.a.ctrl.delay_annuled(i) = '1' then
        if (r.a.ctrl.branch(0) = '1' and r.a.ctrl.swap = '0') or
          (r.a.ctrl.branch(1) = '1' and r.a.ctrl.swap = '1') then
          --issued together with the branch, wait until branch
          --is resolvable
          --if it is an fpu branch it will stall here anyway
          if wicc_active = '1' then
            hold_issue_int          := '1';
            hold_issue_type_int(13) := '1';
          end if;
        else
          --save restore is not issued together with the branch, wait until
          --branches are resolved in the pipeline
          if branch_active = '1' then
            hold_issue_int          := '1';
            hold_issue_type_int(13) := '1';
          end if;
        end if;
      end if;
    end loop;

    
    if LATEALU = '0' then
      mem_wicc     := '0';
      exc_wicc     := '0';
      alu_dexc_a_t := "00";
    end if;


    if hold_issue_div = '1' then
      if hold_issue_int = '1' then
        mask_divstart := '1';
      else
        hold_issue_int         := '1';
        hold_issue_type_int(8) := '1';
        if divo.ready = '1' then
          hold_issue_int         := '0';
          hold_issue_type_int(8) := '0';
        end if;
      end if;
    end if;

    hold_issue      := hold_issue_int;
    hold_issue_type := hold_issue_type_int;
    alu_dexc_a      := alu_dexc_a_t;
  end;

  --LEON5
  function imm_select(inst : word) return std_logic is
    variable imm : std_logic;
  begin
    imm := '0';
    case inst(31 downto 30) is
      when CALL =>
        imm := '1';                     --PC or 0 to dest
      when FMT2 =>
        if inst(24 downto 22) = SETHI then
          imm := '1';
        end if;
      when FMT3 =>
        if (inst(13) = '1') then
          imm := '1';
        end if;
        if (inst(13) = '0') and (inst(4 downto 0) = "00000") then
          imm := '1';
        end if;
      when LDST =>
        if (inst(13) = '1') then
          imm := '1';
        end if;
        if (inst(13) = '0') and (inst(4 downto 0) = "00000") then
          imm := '1';
        end if;
        if is_atomic(inst) = '1' and inst(24 downto 19) = CASA then
          imm := '1';
        end if;
      when others =>
    end case;
    return(imm);
  end;

  procedure rs3_select(inst : word;
                       rs3_sel : out std_logic_vector(1 downto 0);
                       store_double : out std_logic;
                       store_double_a0 : out std_logic
                       ) is
  begin
    --rs3_sel=00 -> all zeros
    --rs3_sel=01 -> use own rs2
    --rs3_sel=10 -> use other rs2
    rs3_sel := "00";
    store_double := '0';
    store_double_a0 := '0';

    if is_store_int(inst) = '1' and (inst(29 downto 25) /= "00000" or inst(21 downto 19) = "111") then
      rs3_sel := "10";
      if inst(13) = '1' or (inst(13) = '0' and inst(4 downto 0) = "00000") then
        rs3_sel := "01";
      end if;
    end if;

    if is_stdb(inst) = '1' then
      store_double := '1';
    end if;
    if inst(29 downto 25) = "00000" then
      store_double_a0 := '1';
    end if;

    if is_atomic(inst) = '1' then
      rs3_sel := "10";
    end if;
    
  end;



  --LEON5
  procedure forwarding_unit(v            :     registers;
                             r           :     registers;
                             lane        :     integer range 0 to 1;
                             alu_out_l0  :     word;
                             alu_out_l1  :     word;
                             rf_data1    :     word;
                             rf_data2    :     word;
                             mem_data_l0 :     word;
                             mem_data_l1 :     word;
                             exc_data_l0 :     word64;
                             exc_data_l1 :     word64;
                             exc_alu_l0  :     word;
                             exc_alu_l1  :     word;
                             imm         :     word;
                             pc          :     word;
                             alu_rs1     : out word;
                             alu_rs2     : out word

                             ) is
    variable rs1                   : std_logic_vector(RFBITS downto 0);
    variable rs2                   : std_logic_vector(RFBITS downto 0);
    variable exe_forw_rs1          : std_logic_vector(1 downto 0);
    variable exe_forw_rs2          : std_logic_vector(1 downto 0);
    variable mem_forw_rs1          : std_logic_vector(1 downto 0);
    variable mem_forw_rs2          : std_logic_vector(1 downto 0);
    variable exc_forw_rs1          : std_logic_vector(1 downto 0);
    variable exc_forw_rs2          : std_logic_vector(1 downto 0);
    variable exc_alu_forw_rs1      : std_logic_vector(1 downto 0);
    variable exc_alu_forw_rs2      : std_logic_vector(1 downto 0);
    variable exc_alu_forw_rs1_temp : std_logic_vector(31 downto 0);
    variable exc_alu_forw_rs2_temp : std_logic_vector(31 downto 0);
    variable mux_output_rs1        : word;
    variable mux_output_rs2        : word;
    variable use_imm               : std_logic;
    variable use_pc                : std_logic;

    variable use_zero : std_logic;
    
  begin


    --issue logic guarantees that same register will not be written by two lanes
    --in the same cycle

    rs1 := r.a.rs1(lane);
    rs2 := r.a.rs2(lane);


    --exc_data_l0_muxed_rs1 := exc_data_l0(31 downto 0);
    --if rs1(0) = '1' then
    --  exc_data_l0_muxed_rs1 := exc_data_l0(63 downto 32);
    --end if;
    --exc_data_l0_muxed_rs2 := exc_data_l0(31 downto 0);
    --if rs2(0) = '1' then
    --  exc_data_l0_muxed_rs2 := exc_data_l0(63 downto 32);
    --end if;

    -- bit(1) indicates forwarding should happen from that stage
    -- bit(0) indicates which lane should the data forwarded from

    exe_forw_rs1     := "00";
    exe_forw_rs2     := "00";
    mem_forw_rs1     := "00";
    mem_forw_rs2     := "00";
    exc_forw_rs1     := "00";
    exc_forw_rs2     := "00";
    exc_alu_forw_rs1 := "00";
    exc_alu_forw_rs2 := "00";
    mux_output_rs1   := (others => '0');
    mux_output_rs2   := (others => '0');
    use_imm          := imm_select(r.a.ctrl.inst(lane));
    use_pc           := (not(r.a.ctrl.inst(lane)(31)) and r.a.ctrl.inst(lane)(30));  --call/jmpl operation add PC or 0 to destination
    use_zero         := '0';
    if r.a.ctrl.inst(lane)(18 downto 14) = "00000" then
      use_zero := '1';
    end if;
    if lane = 1 and is_atomic(r.a.ctrl.inst(1)) = '1' and r.a.ctrl.inst(1)(24 downto 19) = CASA and r.a.ctrl.inst(1)(4 downto 0) = "00000" then
      use_zero := '1';
    end if;

    if r.e.ctrl.rdw(0) = '1' and r.e.ctrl.inst_valid(0) = '1' and r.e.ctrl.delay_annuled(0) = '0' and r.e.ctrl.no_forward(0) = '0' and (r.e.ctrl.rd(0) = rs1) then
      exe_forw_rs1 := "10";
    elsif r.e.ctrl.rdw(1) = '1' and r.e.ctrl.inst_valid(1) = '1' and r.e.ctrl.delay_annuled(1) = '0' and r.e.ctrl.no_forward(1) = '0' and (r.e.ctrl.rd(1) = rs1) then
      exe_forw_rs1 := "11";
    elsif r.m.ctrl.rdw(0) = '1' and r.m.ctrl.inst_valid(0) = '1' and r.m.ctrl.delay_annuled(0) = '0' and r.m.ctrl.no_forward(0) = '0' and (r.m.ctrl.rd(0) = rs1) then
      mem_forw_rs1 := "10";
    elsif r.m.ctrl.rdw(1) = '1' and r.m.ctrl.inst_valid(1) = '1' and r.m.ctrl.delay_annuled(1) = '0' and r.m.ctrl.no_forward(1) = '0' and (r.m.ctrl.rd(1) = rs1) then
      mem_forw_rs1 := "11";
    elsif r.x.ctrl.rdw(0) = '1' and r.x.ctrl.inst_valid(0) = '1' and r.x.ctrl.delay_annuled(0) = '0' and r.x.ctrl.no_forward(0) = '0' and (r.x.ctrl.rd(0) = rs1) then
      exc_forw_rs1 := "10";
      if r.x.ctrl.alu_dexc(0) = '1' then
        exc_forw_rs1     := "00";
        exc_alu_forw_rs1 := "10";
      end if;
    elsif r.x.ctrl.rdw(0) = '1' and r.x.ctrl.inst_valid(0) = '1' and r.x.ctrl.delay_annuled(0) = '0' and is_ldd_int(r.x.ctrl.inst(0)) = '1' and r.x.ctrl.rd(0)(RFBITS downto 1) = rs1(RFBITS downto 1) then
      exc_forw_rs1 := "10";
    elsif r.x.ctrl.rdw(1) = '1' and r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.delay_annuled(1) = '0' and r.x.ctrl.no_forward(1) = '0' and (r.x.ctrl.rd(1) = rs1) then
      exc_forw_rs1 := "11";
      if r.x.ctrl.alu_dexc(1) = '1' then
        exc_forw_rs1     := "00";
        exc_alu_forw_rs1 := "11";
      end if;
    end if;
    --wb forwarding is handled in the register file

    if r.e.ctrl.rdw(0) = '1' and r.e.ctrl.inst_valid(0) = '1' and r.e.ctrl.delay_annuled(0) = '0' and r.e.ctrl.no_forward(0) = '0' and (r.e.ctrl.rd(0) = rs2) then
      exe_forw_rs2 := "10";
    elsif r.e.ctrl.rdw(1) = '1' and r.e.ctrl.inst_valid(1) = '1' and r.e.ctrl.delay_annuled(1) = '0' and r.e.ctrl.no_forward(1) = '0' and (r.e.ctrl.rd(1) = rs2) then
      exe_forw_rs2 := "11";
    elsif r.m.ctrl.rdw(0) = '1' and r.m.ctrl.inst_valid(0) = '1' and r.m.ctrl.delay_annuled(0) = '0' and r.m.ctrl.no_forward(0) = '0' and (r.m.ctrl.rd(0) = rs2) then
      mem_forw_rs2 := "10";
    elsif r.m.ctrl.rdw(1) = '1' and r.m.ctrl.inst_valid(1) = '1' and r.m.ctrl.delay_annuled(1) = '0' and r.m.ctrl.no_forward(1) = '0' and (r.m.ctrl.rd(1) = rs2) then
      mem_forw_rs2 := "11";
    elsif r.x.ctrl.rdw(0) = '1' and r.x.ctrl.inst_valid(0) = '1' and r.x.ctrl.delay_annuled(0) = '0' and r.x.ctrl.no_forward(0) = '0' and (r.x.ctrl.rd(0) = rs2) then
      exc_forw_rs2 := "10";
      if r.x.ctrl.alu_dexc(0) = '1' then
        exc_forw_rs2     := "00";
        exc_alu_forw_rs2 := "10";
      end if;
    elsif r.x.ctrl.rdw(0) = '1' and r.x.ctrl.inst_valid(0) = '1' and r.x.ctrl.delay_annuled(0) = '0' and is_ldd_int(r.x.ctrl.inst(0)) = '1' and r.x.ctrl.rd(0)(RFBITS downto 1) = rs2(RFBITS downto 1) then
      exc_forw_rs2 := "10";
    elsif r.x.ctrl.rdw(1) = '1' and r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.delay_annuled(1) = '0' and r.x.ctrl.no_forward(1) = '0' and (r.x.ctrl.rd(1) = rs2) then
      exc_forw_rs2 := "11";
      if r.x.ctrl.alu_dexc(1) = '1' then
        exc_forw_rs2     := "00";
        exc_alu_forw_rs2 := "11";
      end if;
    end if;

    exc_alu_forw_rs1_temp := exc_alu_l0;
    if exc_alu_forw_rs1(0) = '1' then
      exc_alu_forw_rs1_temp := exc_alu_l1;
    end if;

    if use_pc = '1' then
      mux_output_rs1 := pc;
    elsif use_zero = '1' then
      mux_output_rs1 := (others => '0');
    elsif mem_forw_rs1 = "10" then
      mux_output_rs1 := mem_data_l0;
    elsif mem_forw_rs1 = "11" then
      mux_output_rs1 := mem_data_l1;
    elsif exc_forw_rs1 = "10" then
      if rs1(0) = '0' then
        mux_output_rs1 := exc_data_l0(63 downto 32);
      else
        mux_output_rs1 := exc_data_l0(31 downto 0);
      end if;
    elsif exc_forw_rs1 = "11" then
      if rs1(0) = '0' then
        mux_output_rs1 := exc_data_l1(63 downto 32);
      else
        mux_output_rs1 := exc_data_l1(31 downto 0);
      end if;
    elsif exc_alu_forw_rs1(1) = '1' then
      mux_output_rs1 := exc_alu_forw_rs1_temp;
    end if;


    --final multiplexer has 4 inputs to reduce critical path from
    --combinatorial alu output and register file
    if mem_forw_rs1(1) = '1' or exc_alu_forw_rs1(1) = '1' or exc_forw_rs1(1) = '1' or use_pc = '1' or use_zero = '1' then
      alu_rs1 := mux_output_rs1;
    elsif exe_forw_rs1 = "10" then
      alu_rs1 := alu_out_l0;
    elsif exe_forw_rs1 = "11" then
      alu_rs1 := alu_out_l1;
    else
      alu_rs1 := rf_data1;
    end if;

    exc_alu_forw_rs2_temp := exc_alu_l0;
    if exc_alu_forw_rs2(0) = '1' then
      exc_alu_forw_rs2_temp := exc_alu_l1;
    end if;

    if use_imm = '1' then
      mux_output_rs2 := imm;
    elsif mem_forw_rs2 = "10" then
      mux_output_rs2 := mem_data_l0;
    elsif mem_forw_rs2 = "11" then
      mux_output_rs2 := mem_data_l1;
    elsif exc_forw_rs2 = "10" then
      if rs2(0) = '0' then
        mux_output_rs2 := exc_data_l0(63 downto 32);
      else
        mux_output_rs2 := exc_data_l0(31 downto 0);
      end if;
    elsif exc_forw_rs2 = "11" then
      if rs2(0) = '0' then
        mux_output_rs2 := exc_data_l1(63 downto 32);
      else
        mux_output_rs2 := exc_data_l1(31 downto 0);
      end if;
    elsif exc_alu_forw_rs2(1) = '1' then
      mux_output_rs2 := exc_alu_forw_rs2_temp;
    end if;

    --final multiplexer has 4 inputs to reduce critical path from
    --combinatorial alu output and register file
    if use_imm = '1' or mem_forw_rs2(1) = '1' or exc_forw_rs2(1) = '1' or exc_alu_forw_rs2(1) = '1' then
      alu_rs2 := mux_output_rs2;
    elsif exe_forw_rs2 = "10" then
      alu_rs2 := alu_out_l0;
    elsif exe_forw_rs2 = "11" then
      alu_rs2 := alu_out_l1;
    else
      alu_rs2 := rf_data2;
    end if;


    
    
  end;

  procedure forwarding_unit_late_alu(v            :     registers;
                                      r           :     registers;
                                      lane        :     integer range 0 to 1;
                                      late_alu_l0 :     word;
                                      late_alu_l1 :     word;
                                      mem_lalu0   :     word;
                                      alu_rs1     : out word;
                                      alu_rs2     : out word;
                                      ld_fwd      : out std_logic_vector(1 downto 0);
                                      mul_fwd     : out std_logic_vector(1 downto 0);
                                      sari        : out std_logic;
                                      shcnt       : out std_logic_vector(4 downto 0)
                                      ) is
    variable rs1           : std_logic_vector(RFBITS downto 0);
    variable rs2           : std_logic_vector(RFBITS downto 0);
    variable forwarded_rs1 : std_logic;
    variable forwarded_rs2 : std_logic;
    variable alu_rs1_t     : word;
    variable alu_rs2_t     : word;
  begin

    rs1 := r.m.rs1(lane);
    rs2 := r.m.rs2(lane);

    alu_rs1_t := r.m.alu_op1(lane);
    alu_rs2_t := r.m.alu_op2(lane);

    sari  := r.m.alu_ctrl.sari(lane);
    shcnt := r.m.alu_ctrl.shcnt(lane);

    ld_fwd  := "00";
    mul_fwd := "00";

    forwarded_rs1 := '0';
    forwarded_rs2 := '0';

    --*RS1 forwarding
    --forwarding from write-back registers
    if r.w.we(0) = "01" or r.w.we(0) = "10" then
      if rs1 = r.w.rd(0) then
        alu_rs1_t     := r.w.wb_data(0)(63 downto 32);
        forwarded_rs1 := '1';
      end if;
    end if;

    if r.w.we(0) = "11" then
      if rs1(0) = '1' and rs1(RFBITS downto 1) = r.w.rd(0)(RFBITS downto 1) then
        alu_rs1_t     := r.w.wb_data(0)(31 downto 0);
        forwarded_rs1 := '1';
      end if;
    end if;

    --forwarding from write-back registers
    if r.w.we(1) /= "00" then
      if rs1 = r.w.rd(1) then
        alu_rs1_t     := r.w.wb_data(1)(63 downto 32);
        forwarded_rs1 := '1';
      end if;
    end if;

    --forwarding from load result
    if is_load_int(r.x.ctrl.inst(0)) = '1' and v.w.we(0) /= "00" then
      if rs1 = r.x.ctrl.rd(0) and r.x.ctrl.ldd_z = '0' then
        if rs1(0) = '0' then
          alu_rs1_t     := r.x.data(0)(63 downto 32);
          forwarded_rs1 := '1';
        else
          alu_rs1_t     := r.x.data(0)(31 downto 0);
          forwarded_rs1 := '1';
        end if;
      end if;
      if is_ldd_int(r.x.ctrl.inst(0)) = '1' then
        if rs1(RFBITS downto 1) = r.x.ctrl.rd(0)(RFBITS downto 1) and rs1(0) = '1' then
          alu_rs1_t     := r.x.data(0)(31 downto 0);
          forwarded_rs1 := '1';
        end if;
      end if;
    end if;

    --forwarding from mult result
    if (is_mul(r.x.ctrl.inst(0)) = '1' and v.w.we(0) /= "00" and rs1 = r.x.ctrl.rd(0)) or
      (is_mul(r.x.ctrl.inst(1)) = '1' and v.w.we(1) /= "00" and rs1 = r.x.ctrl.rd(1)) then
      alu_rs1_t     := r.x.muldiv_result;
      forwarded_rs1 := '1';
    end if;

    --forwarding from the calculated excp result
    if r.x.ctrl.alu_dexc(0) = '0' and v.w.we(0) /= "00" and is_load_int(r.x.ctrl.inst(0)) = '0' and is_mul(r.x.ctrl.inst(0)) = '0' then
      if rs1 = r.x.ctrl.rd(0) then
        alu_rs1_t     := r.x.result(0);
        forwarded_rs1 := '1';
      end if;
    end if;
    if r.x.ctrl.alu_dexc(1) = '0' and v.w.we(1) /= "00" and is_mul(r.x.ctrl.inst(1)) = '0'then
      if rs1 = r.x.ctrl.rd(1) then
        alu_rs1_t     := r.x.result(1);
        forwarded_rs1 := '1';
      end if;
    end if;

    --forwarding from late alu result
    if r.x.ctrl.alu_dexc(0) = '1' and v.w.we(0) /= "00" then
      if rs1 = r.x.ctrl.rd(0) then
        alu_rs1_t     := late_alu_l0;
        forwarded_rs1 := '1';
      end if;
    end if;

    if r.x.ctrl.alu_dexc(1) = '1' and v.w.we(1) /= "00" then
      if rs1 = r.x.ctrl.rd(1) then
        alu_rs1_t     := late_alu_l1;
        forwarded_rs1 := '1';
      end if;
    end if;

    --no no_forward check here because there is an actual dependence between
    --the instructions in the same pair
    if lane = 0 and r.m.ctrl.swap = '1' and v.x.ctrl.inst_valid(1) = '1' and v.x.ctrl.delay_annuled(1) = '0' and r.m.ctrl.rdw(1) = '1' then
      if rs1 = r.m.ctrl.rd(1) then
        alu_rs1_t     := r.m.result(1);
        forwarded_rs1 := '1';
      end if;
    end if;

    --no no_forward check here because there is an actual dependence between
    --the instructions in the same pair
    if lane = 1 and r.m.ctrl.swap = '0' and v.x.ctrl.inst_valid(0) = '1' and v.x.ctrl.delay_annuled(0) = '0' and r.m.ctrl.rdw(0) = '1' then
      if rs1 = r.m.ctrl.rd(0) then
        alu_rs1_t     := r.m.result(0);
        forwarded_rs1 := '1';
      end if;
    end if;

    --ALU/ALUcc dual issued together and ALU has late ALU dependency
    --no no_forward check here because there is an actual dependence between
    --the instructions in the same pair
    if lane = 1 and r.m.ctrl.swap = '0' and v.x.ctrl.inst_valid(0) = '1' and v.x.ctrl.delay_annuled(0) = '0' and r.m.ctrl.rdw(0) = '1' and r.m.ctrl.alu_dexc(0) = '1' and is_wicc(r.m.ctrl.inst(1)) = '1' then
      if rs1 = r.m.ctrl.rd(0) then
        forwarded_rs1 := '1';
        alu_rs1_t     := mem_lalu0;
      end if;
    end if;

    if forwarded_rs1 = '1' and r.m.ctrl.inst(lane)(31 downto 30) = FMT3 and r.m.ctrl.inst(lane)(24 downto 19) = ISRA then
      sari := alu_rs1_t(31);
    end if;

    --*RS2 forwarding
    --forwarding from write-back registers
    if r.w.we(0) = "01" or r.w.we(0) = "10" then
      if rs2 = r.w.rd(0) then
        alu_rs2_t     := r.w.wb_data(0)(63 downto 32);
        forwarded_rs2 := '1';
      end if;
    end if;

    if r.w.we(0) = "11" then
      if rs2(0) = '1' and rs2(RFBITS downto 1) = r.w.rd(0)(RFBITS downto 1) then
        alu_rs2_t     := r.w.wb_data(0)(31 downto 0);
        forwarded_rs2 := '1';
      end if;
    end if;

    --forwarding from write-back registers
    if r.w.we(1) /= "00" then
      if rs2 = r.w.rd(1) then
        alu_rs2_t     := r.w.wb_data(1)(63 downto 32);
        forwarded_rs2 := '1';
      end if;
    end if;

    --forwarding from load result
    if is_load_int(r.x.ctrl.inst(0)) = '1' and v.w.we(0) /= "00" then
      if rs2 = r.x.ctrl.rd(0) and r.x.ctrl.ldd_z = '0' then
        if rs2(0) = '0' then
          alu_rs2_t     := r.x.data(0)(63 downto 32);
          forwarded_rs2 := '1';
        else
          alu_rs2_t     := r.x.data(0)(31 downto 0);
          forwarded_rs2 := '1';
        end if;
      end if;
      if is_ldd_int(r.x.ctrl.inst(0)) = '1' then
        if rs2(RFBITS downto 1) = r.x.ctrl.rd(0)(RFBITS downto 1) and rs2(0) = '1' then
          alu_rs2_t     := r.x.data(0)(31 downto 0);
          forwarded_rs2 := '1';
        end if;
      end if;
    end if;

    --forwarding from mult result
    if (is_mul(r.x.ctrl.inst(0)) = '1' and v.w.we(0) /= "00" and rs2 = r.x.ctrl.rd(0)) or
      (is_mul(r.x.ctrl.inst(1)) = '1' and v.w.we(1) /= "00" and rs2 = r.x.ctrl.rd(1)) then
      alu_rs2_t     := r.x.muldiv_result;
      forwarded_rs2 := '1';
    end if;

    --forwarding from the calculated excp result
    if r.x.ctrl.alu_dexc(0) = '0' and v.w.we(0) /= "00" and is_load_int(r.x.ctrl.inst(0)) = '0' and is_mul(r.x.ctrl.inst(0)) = '0' then
      if rs2 = r.x.ctrl.rd(0) then
        alu_rs2_t     := r.x.result(0);
        forwarded_rs2 := '1';
      end if;
    end if;
    if r.x.ctrl.alu_dexc(1) = '0' and v.w.we(1) /= "00" and is_mul(r.x.ctrl.inst(1)) = '0' then
      if rs2 = r.x.ctrl.rd(1) then
        alu_rs2_t     := r.x.result(1);
        forwarded_rs2 := '1';
      end if;
    end if;

    --forwarding from late alu result
    if r.x.ctrl.alu_dexc(0) = '1' and v.w.we(0) /= "00" then
      if rs2 = r.x.ctrl.rd(0) then
        alu_rs2_t     := late_alu_l0;
        forwarded_rs2 := '1';
      end if;
    end if;

    if r.x.ctrl.alu_dexc(1) = '1' and v.w.we(1) /= "00" then
      if rs2 = r.x.ctrl.rd(1) then
        alu_rs2_t     := late_alu_l1;
        forwarded_rs2 := '1';
      end if;
    end if;

    --no no_forward check here because there is an actual dependence between
    --the instructions in the same pair
    if lane = 0 and r.m.ctrl.swap = '1' and v.x.ctrl.inst_valid(1) = '1' and v.x.ctrl.delay_annuled(1) = '0' and r.m.ctrl.rdw(1) = '1' then
      if rs2 = r.m.ctrl.rd(1) then
        alu_rs2_t     := r.m.result(1);
        forwarded_rs2 := '1';
      end if;
    end if;

    --no no_forward check here because there is an actual dependence between
    --the instructions in the same pair
    if lane = 1 and r.m.ctrl.swap = '0' and v.x.ctrl.inst_valid(0) = '1' and v.x.ctrl.delay_annuled(0) = '0' and r.m.ctrl.rdw(0) = '1' then
      if rs2 = r.m.ctrl.rd(0) then
        alu_rs2_t     := r.m.result(0);
        forwarded_rs2 := '1';
      end if;
    end if;

    --ALU/ALUcc dual issued together and ALU has late ALU dependency
    --no no_forward check here because there is an actual dependence between
    --the instructions in the same pair
    if lane = 1 and r.m.ctrl.swap = '0' and v.x.ctrl.inst_valid(0) = '1' and v.x.ctrl.delay_annuled(0) = '0' and r.m.ctrl.rdw(0) = '1' and r.m.ctrl.alu_dexc(0) = '1' and is_wicc(r.m.ctrl.inst(1)) = '1' then
      if rs2 = r.m.ctrl.rd(0) then
        forwarded_rs2 := '1';
        alu_rs2_t     := mem_lalu0;
      end if;
    end if;

    if forwarded_rs2 = '1' then
      shcnt := alu_rs2_t(4 downto 0);
    end if;

    if r.m.alu_ctrl.invop2(lane) = '1' and forwarded_rs2 = '1' then
      shcnt     := not(alu_rs2_t(4 downto 0));
      alu_rs2_t := not(alu_rs2_t);
    end if;

    --instruction can be issued together with a load or multiply
    --forward in the exception stage itself

    --since ld always go to lane 0 there can not be a load forwarding on lane 0
    if lane = 1 and r.m.ctrl.swap = '0' and is_load_int(r.m.ctrl.inst(0)) = '1' and r.m.ctrl.delay_annuled(0) = '0' and v.x.ctrl.inst_valid(0) = '1' then
      if rs1 = r.m.ctrl.rd(0) then
        ld_fwd(0) := '1';
        if r.m.ctrl.ldd_z = '1' and rs1(0) = '0' then
          ld_fwd(0) := '0';
        end if;
      end if;
      if rs2 = r.m.ctrl.rd(0) then
        ld_fwd(1) := '1';
        if r.m.ctrl.ldd_z = '1' and rs2(0) = '0' then
          ld_fwd(1) := '0';
        end if;
      end if;

      if is_ldd_int(r.m.ctrl.inst(0)) = '1' then
        if rs1(RFBITS downto 1) = r.m.ctrl.rd(0)(RFBITS downto 1) and rs1(0) = '1' then
          ld_fwd(0) := '1';
        end if;
        if rs2(RFBITS downto 1) = r.m.ctrl.rd(0)(RFBITS downto 1) and rs2(0) = '1' then
          ld_fwd(1) := '1';
        end if;
      end if;
    end if;


    if lane = 1 and r.m.ctrl.swap = '0' and is_mul(r.m.ctrl.inst(0)) = '1' and v.x.ctrl.delay_annuled(0) = '0' and v.x.ctrl.inst_valid(0) = '1' then
      if rs1 = r.m.ctrl.rd(0) then
        mul_fwd(0) := '1';
      end if;
      if rs2 = r.m.ctrl.rd(0) then
        mul_fwd(1) := '1';
      end if;
    end if;

    if lane = 0 and r.m.ctrl.swap = '1' and is_mul(r.m.ctrl.inst(1)) = '1' and v.x.ctrl.delay_annuled(1) = '0' and v.x.ctrl.inst_valid(1) = '1' then
      if rs1 = r.m.ctrl.rd(1) then
        mul_fwd(0) := '1';
      end if;
      if rs2 = r.m.ctrl.rd(1) then
        mul_fwd(1) := '1';
      end if;
    end if;

    alu_rs1 := alu_rs1_t;
    alu_rs2 := alu_rs2_t;
    
  end;

  procedure forwarding_mux_mem_stage(r               :     registers;
                                     mem_lalu_l0_op1 : out std_logic_vector(31 downto 0);
                                     mem_lalu_l0_op2 : out std_logic_vector(31 downto 0);
                                     mem_lalu_l1_op1 : out std_logic_vector(31 downto 0);
                                     mem_lalu_l1_op2 : out std_logic_vector(31 downto 0)) is
    variable mem_lalu_l0_op2_v : std_logic_vector(31 downto 0);
    variable mem_lalu_l1_op2_v : std_logic_vector(31 downto 0);
  begin

    mem_lalu_l0_op1   := r.m.alu_op1(0);
    mem_lalu_l0_op2_v := r.m.alu_op2(0);
    mem_lalu_l1_op1   := r.m.alu_op1(1);
    mem_lalu_l1_op2_v := r.m.alu_op2(1);

    --forwarding ALU0
    if r.m.lalu0_ldfwd_rs1 = '1' then
      if r.m.rs1(0)(0) = '0' then
        mem_lalu_l0_op1 := r.x.data(0)(63 downto 32);
      else
        mem_lalu_l0_op1 := r.x.data(0)(31 downto 0);
      end if;
      --following forwardings can happen only for alu ops
      --hence it does not matter which part is used  
    elsif r.m.lalu0_wb0fwd_rs1 = '1' then
      mem_lalu_l0_op1 := r.w.wb_data(0)(63 downto 32);
    elsif r.m.lalu0_wb1fwd_rs1 = '1' then
      mem_lalu_l0_op1 := r.w.wb_data(1)(63 downto 32);
    end if;

    if r.m.lalu0_ldfwd_rs2 = '1' then
      if r.m.rs2(0)(0) = '0' then
        mem_lalu_l0_op2_v := r.x.data(0)(63 downto 32);
      else
        mem_lalu_l0_op2_v := r.x.data(0)(31 downto 0);
      end if;
      --following forwardings can happen only for alu ops
      --hence it does not matter which part is used  
    elsif r.m.lalu0_wb0fwd_rs2 = '1' then
      mem_lalu_l0_op2_v := r.w.wb_data(0)(63 downto 32);
    elsif r.m.lalu0_wb1fwd_rs2 = '1' then
      mem_lalu_l0_op2_v := r.w.wb_data(1)(63 downto 32);
    end if;

    mem_lalu_l0_op2 := mem_lalu_l0_op2_v;
    if r.m.alu_ctrl.invop2(0) = '1' and (r.m.lalu0_ldfwd_rs2 = '1' or r.m.lalu0_wb0fwd_rs2 = '1' or r.m.lalu0_wb1fwd_rs2 = '1') then
      mem_lalu_l0_op2 := not(mem_lalu_l0_op2_v);
    end if;


    --forwarding ALU1
    if r.m.late_wicc_op1_ldfwd = '1' then
      if r.m.late_wicc_rs1(0) = '0' then
        mem_lalu_l1_op1 := r.x.data(0)(63 downto 32);
      else
        mem_lalu_l1_op1 := r.x.data(0)(31 downto 0);
      end if;
      --following forwardings can happen only for alu ops
      --hence it does not matter which part is used  
    elsif r.m.late_wicc_op1_lalu0 = '1' then
      mem_lalu_l1_op1 := r.w.wb_data(0)(63 downto 32);
    elsif r.m.late_wicc_op1_lalu1 = '1' then
      mem_lalu_l1_op1 := r.w.wb_data(1)(63 downto 32);
    end if;

    if r.m.late_wicc_op2_ldfwd = '1' then
      if r.m.late_wicc_rs2(0) = '0' then
        mem_lalu_l1_op2_v := r.x.data(0)(63 downto 32);
      else
        mem_lalu_l1_op2_v := r.x.data(0)(31 downto 0);
      end if;
      --following forwardings can happen only for alu ops
      --hence it does not matter which part is used  
    elsif r.m.late_wicc_op2_lalu0 = '1' then
      mem_lalu_l1_op2_v := r.w.wb_data(0)(63 downto 32);
    elsif r.m.late_wicc_op2_lalu1 = '1' then
      mem_lalu_l1_op2_v := r.w.wb_data(1)(63 downto 32);
    end if;

    mem_lalu_l1_op2 := mem_lalu_l1_op2_v;
    if r.m.alu_ctrl.invop2(1) = '1' and (r.m.late_wicc_op2_ldfwd = '1' or r.m.late_wicc_op2_lalu0 = '1' or r.m.late_wicc_op2_lalu1 = '1') then
      mem_lalu_l1_op2 := not(mem_lalu_l1_op2_v);
    end if;


  end;


  --LEON5
  function inst_lane_check(inst : std_logic_vector(31 downto 0);
                           lane : std_logic)
    return std_logic is
    variable ret : std_logic;
    variable op1 : std_logic_vector(1 downto 0);
    variable op3 : std_logic_vector(5 downto 0);
  begin

    op1 := inst(31 downto 30);
    op3 := inst(24 downto 19);

    ret := '0';

    if lane = '0' then
      --WRPSR is forced to lane-1 because it writes to icc
      case op1 is
        when FMT3 =>
          case op3 is
            when ADDCC | ANDCC | ORCC | XORCC | SUBCC | ANDNCC
              | ORNCC | XNORCC | ADDXCC | SUBXCC | TADDCC | TSUBCC
              | TADDCCTV | TSUBCCTV | UDIV | UDIVCC | SDIV | SDIVCC
              | UMULCC | SMULCC | MULSCC | WRPSR | JMPL | RETT =>
              ret := '1';
            when others =>
              ret := '0';
          end case;
        when others =>
          ret := '0';
      end case;
    end if;

    if lane = '1' then
      case op1 is
        when LDST =>
          ret := '1';
        when FMT3 =>
          case op3 is
            when RDPSR =>
              ret := '1';
            when WRY | WRWIM | WRTBR | FLUSH =>
              ret := '1';
            when TICC =>
              ret := '1';
            when others =>
              null;
          end case;
        when others =>
          null;
      end case;
    end if;

    return ret;

  end;

  --LEON5
  procedure inst_swap_check(de_inst  :     inst_pair_type;
                            de_issue :     std_logic_vector(1 downto 0);
                            de_swap  : out std_logic) is
  begin

    de_swap := '0';

    if inst_lane_check(de_inst(0), '0') = '1' and r.d.inst_valid(0) = '1' then
      de_swap := '1';
    end if;

    if inst_lane_check(de_inst(1), '1') = '1' and (inst_lane_check(de_inst(0), '1') = '0' or r.d.inst_valid(0) = '0') then
      de_swap := '1';
    end if;


  end;


  --rd_gen for LEON5
  procedure rd_gen(inst  :     word;
                   wreg  : out std_logic;
                   ldd_z : out std_logic;
                   rdo   : out std_logic_vector(4 downto 0)) is
    variable op    : std_logic_vector(1 downto 0);
    variable op2   : std_logic_vector(2 downto 0);
    variable op3   : std_logic_vector(5 downto 0);
    variable rdo_V : std_logic_vector(4 downto 0);
  begin

    op    := inst(31 downto 30);
    op2   := inst(24 downto 22);
    op3   := inst(24 downto 19);
    rdo_v := inst(29 downto 25);
    wreg  := '0';
    ldd_z := '0';


    case op is
      when CALL =>
        rdo_v := "01111";               -- CALL saves PC in r[15] (%o7)
        wreg  := '1';
      when FMT2 =>
        if (op2 = SETHI) then
          wreg := '1';
        end if;
      when FMT3 =>
        case op3 is
          when RETT | WRPSR | WRY | WRWIM | WRTBR | TICC | FLUSH =>
            null;
          when others =>
            wreg := '1';
        end case;
      when others =>
        --LDST
        if (op3(2) = '0') and not ((CPEN or FPEN) and (op3(5) = '1')) then
          wreg := '1';
        end if;

        if op3 = SWAP or op3 = SWAPA or op3 = LDSTUB or op3 = LDSTUBA or op3 = CASA then
          --this is handled by atomic state machine
          wreg := '0';
        end if;
    end case;

    if (rdo_v = "00000") then
      wreg := '0';
      if is_ldd_int(inst) = '1' then
        ldd_z := '1';
        wreg  := '1';
      end if;
    end if;

    if is_fpop(inst) = '1' then
      wreg := '0';
    end if;

    rdo := rdo_v;
    
  end;


  procedure fpc_issue_check(fpu5i    :     fpc5_out_type;
                            de_inst  :     std_logic_vector(31 downto 0);
                            de_issue : out std_logic) is
    variable rd       : std_logic_vector(4 downto 0);
    variable op3      : std_logic_vector(5 downto 0);
    variable ready_sw : std_logic_vector(1 downto 0);
    variable ready_lw : std_logic_vector(1 downto 0);
  begin
    rd       := de_inst(29 downto 25);
    op3      := de_inst(24 downto 19);
    de_issue := '1';
    ready_sw := "00";
    ready_lw := "00";

    if notx(rd) then
      
      ready_sw(0) := fpu5i.ready_st(to_integer(unsigned(rd)));
      ready_sw(1) := fpu5i.ready_st(to_integer(unsigned(rd(4 downto 1)&'1')));
      ready_lw(0) := fpu5i.ready_ld(to_integer(unsigned(rd)));
      ready_lw(1) := fpu5i.ready_ld(to_integer(unsigned(rd(4 downto 1)&'1')));
    else
      setx(ready_sw);
      setx(ready_lw);
    end if;

    if is_store(de_inst) = '1' then
      if op3(1 downto 0) = "00" then
        --STF
        if ready_sw(0) = '0' then
          de_issue := '0';
        end if;
      end if;
      if op3(1 downto 0) = "11" then
        --STDF
        if ready_sw /= "11" then
          de_issue := '0';
        end if;
      end if;

      if op3(1 downto 0) = "01" then
        if fpu5i.ready_st(32) = '0' then
          de_issue := '0';
        end if;
      end if;

      if op3(1 downto 0) = "10" then
        if fpu5i.ready_st(34) = '0' then
          de_issue := '0';
        end if;
      end if;
    end if;

    if is_load(de_inst) = '1' then
      if op3(1 downto 0) = "00" then
        --LDF
        if ready_lw(0) = '0' then
          de_issue := '0';
        end if;
      end if;
      if op3(1 downto 0) = "11" then
        --LDDF
        if ready_lw /= "11" then
          de_issue := '0';
        end if;
      end if;

      if op3(1 downto 0) = "01" then
        if fpu5i.ready_st(32) = '0' then
          de_issue := '0';
        end if;
      end if;
    end if;

    if fpu5i.ready_flop = '0' then
      if is_fpu_load(de_inst) = '0' and is_fpu_store(de_inst) = '0' then
        de_issue := '0';
      end if;
    end if;

    if fpu5i.trapon_flop = '1' then
      if is_fpu_load(de_inst) = '0' and is_fpu_store(de_inst) = '0' then
        de_issue := '1';
      end if;
    end if;

    if fpu5i.trapon_ldst = '1' then
      if is_fpu_load(de_inst) = '1' or (is_fpu_store(de_inst) = '1' and op3 /= "100110") then
        de_issue := '1';
      end if;
    end if;

    if fpu5i.trapon_stdfq = '1' then
      if is_store(de_inst) = '1' and op3 = "100110" then
        de_issue := '1';
      end if;
    end if;

  end procedure;



  --dual issue logic
  procedure dual_issue_check(r                 :     registers;
                             de_inst           :     inst_pair_type;
                             inst_valid        :     std_logic_vector(1 downto 0);
                             ra_delay_no_annul :     std_logic;
                             alu_dexc_acc      :     std_logic_vector(1 downto 0);
                             fpu5i             :     fpc5_out_type;
                             wicc_dexc         : out std_logic;
                             wicc_dmem         : out std_logic;
                             alu_dexc          : out std_logic_vector(1 downto 0);
                             no_forward        : out std_logic;
                             use_sethi         : out std_logic_vector(1 downto 0);
                             use_logic         : out std_logic_vector(1 downto 0);
                             use_addsub        : out std_logic_vector(1 downto 0);
                             use_memaddr_add1  : out std_logic;
                             use_logicshift    : out std_logic;
                             dual_ldissue      : out std_logic;
                             de_issue          : out std_logic_vector(1 downto 0);
                             de_fpc_issue      : out std_logic_vector(1 downto 0)) is
    variable conflict         : std_logic;
    variable fpc_conflict     : std_logic;
    variable arith_conflict   : std_logic;
    variable op               : op_array;
    variable op2              : op2_array;
    variable op3              : op3_array;
    variable rd0              : std_logic_vector(4 downto 0);
    variable rd0w             : std_logic;
    variable rd1              : std_logic_vector(4 downto 0);
    variable rd1w             : std_logic;
    variable rs1_1            : std_logic_vector(4 downto 0);
    variable rs1_1v           : std_logic;
    variable rs2_1            : std_logic_vector(4 downto 0);
    variable rs2_1v           : std_logic;
    variable rs3_1            : std_logic_vector(4 downto 0);
    variable rs1_0            : std_logic_vector(4 downto 0);
    variable rs2_0            : std_logic_vector(4 downto 0);
    variable rs2_0v           : std_logic;
    variable alu_dexc_t       : std_logic;
    variable wicc_d0, wicc_d1 : std_logic;
    variable wy_d0, wy_d1     : std_logic;

    variable a_rd         : reg_short_pair_type;
    variable a_rdw        : std_logic_vector(1 downto 0);
    variable e_rd         : reg_short_pair_type;
    variable e_rdw        : std_logic_vector(1 downto 0);
    variable late_depen   : std_logic_vector(1 downto 0);
    variable late_depen_t : std_logic_vector(1 downto 0);
    variable ldd_zd       : std_logic_vector(1 downto 0);
    variable ldd_za       : std_logic_vector(1 downto 0);
    variable ldd_ze       : std_logic_vector(1 downto 0);
    
  begin

    de_issue         := (others => '0');
    de_fpc_issue     := (others => '0');
    conflict         := '0';
    fpc_conflict     := '0';
    arith_conflict   := '0';
    wicc_dexc        := '0';
    wicc_dmem        := '0';
    alu_dexc         := "00";
    no_forward       := '0';
    use_sethi        := "00";
    use_logic        := "00";
    use_addsub       := "00";
    use_memaddr_add1 := '0';
    use_logicshift   := '0';
    dual_ldissue     := '0';
    alu_dexc_t       := '0';
    rd_gen(de_inst(0), rd0w, ldd_zd(0), rd0);
    rd_gen(de_inst(1), rd1w, ldd_zd(1), rd1);
    rs1_1            := de_inst(1)(18 downto 14);
    rs2_1            := de_inst(1)(4 downto 0);
    rs2_1v           := not(de_inst(1)(13));
    rs1_0            := de_inst(0)(18 downto 14);
    rs2_0            := de_inst(0)(4 downto 0);
    rs2_0v           := not(de_inst(0)(13));
    for i in 0 to 1 loop
      op(i)  := de_inst(i)(31 downto 30);
      op2(i) := de_inst(i)(24 downto 22);
      op3(i) := de_inst(i)(24 downto 19);
    end loop;
    rs3_1 := de_inst(1)(29 downto 25);

    for i in 0 to 1 loop
      rd_gen(r.a.ctrl.inst(i), a_rdw(i), ldd_za(i), a_rd(i));
      rd_gen(r.e.ctrl.inst(i), e_rdw(i), ldd_ze(i), e_rd(i));
    end loop;
    late_depen   := "00";
    late_depen_t := "00";

    rs1_1v := '1';

    if FPEN then
      if is_fpop_noldst(de_inst(1)) = '1' then
        rs1_1v := '0';
        rs2_1v := '0';
      end if;
    end if;

    --this part concerns the ALCucc/branch or ALU/ALUcc combinations
    --which can not be dual issued due to late ALU dependency
    for i in 0 to 1 loop
      if (r.a.ctrl.lalu_s1(i) = '1' or r.a.ctrl.alu_dexc(i) = '1') and r.a.ctrl.inst_valid(i) = '1' and r.a.ctrl.delay_annuled(i) = '0' and r.a.ctrl.no_forward(i) = '0' and a_rdw(i) = '1' then

        if a_rd(i) = rs1_0 or (a_rd(i) = rs2_0 and rs2_0v = '1') then
          late_depen(0) := '1';
        end if;

        if a_rd(i) = rs1_1 or (a_rd(i) = rs2_1 and rs2_1v = '1') then
          late_depen(1) := '1';
        end if;

        if r.a.ctrl.cwp_update = '1' then
          --when there is a save restore registers are not directly related and
          --in order not to cause a long critical path we just assert late depen
          late_depen := "11";
        end if;
      end if;

      if r.e.ctrl.alu_dexc(i) = '1' and r.e.ctrl.inst_valid(i) = '1' and r.e.ctrl.delay_annuled(i) = '0' and r.e.ctrl.no_forward(i) = '0' and e_rdw(i) = '1' then
        
        if e_rd(i) = rs1_0 or (e_rd(i) = rs2_0 and rs2_0v = '1') then
          late_depen(0) := '1';
        end if;

        if e_rd(i) = rs1_1 or (e_rd(i) = rs2_1 and rs2_1v = '1') then
          late_depen(1) := '1';
        end if;

        if r.a.ctrl.cwp_update = '1' or r.e.ctrl.cwp_update = '1' then
          late_depen := "11";
        end if;
        
      end if;
      
    end loop;

    for i in 0 to 1 loop
      if is_mul(r.a.ctrl.inst(i)) = '1' and r.a.ctrl.inst_valid(i) = '1' and r.a.ctrl.delay_annuled(i) = '0' and r.a.ctrl.rdw(i) = '1' then
        if a_rd(i) = rs1_0 or (a_rd(i) = rs2_0 and rs2_0v = '1') then
          late_depen(0) := '1';
        end if;
        if a_rd(i) = rs1_1 or (a_rd(i) = rs2_1 and rs2_1v = '1') then
          late_depen(1) := '1';
        end if;
        if r.a.ctrl.cwp_update = '1' then
          --when there is a save restore registers are not directly related and
          --in order not to cause a long critical path we just assert late depen
          late_depen := "11";
        end if;
      end if;
    end loop;

    late_depen_t := late_depen;

    if is_load_int(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.inst_valid(0) = '1' and r.a.ctrl.delay_annuled(0) = '0' and a_rdw(0) = '1' then
      if a_rd(0) = rs1_0 or (a_rd(0) = rs2_0 and rs2_0v = '1') then
        late_depen(0) := '1';
      end if;

      if a_rd(0) = rs1_1 or (a_rd(0) = rs2_1 and rs2_1v = '1') then
        late_depen(1) := '1';
      end if;

      if is_ldd_int(r.a.ctrl.inst(0)) = '1' then
        if a_rd(0)(4 downto 1) = rs1_0(4 downto 1) or (a_rd(0)(4 downto 1) = rs2_0(4 downto 1) and rs2_0v = '1') then
          late_depen(0) := '1';
        end if;

        if a_rd(0)(4 downto 1) = rs1_1(4 downto 1) or (a_rd(0)(4 downto 1) = rs2_1(4 downto 1) and rs2_1v = '1') then
          late_depen(1) := '1';
        end if;
      end if;
      if r.a.ctrl.cwp_update = '1' then
        --when there is a save restore registers are not directly related and
        --in order not to cause a long critical path we just assert late depen
        late_depen := "11";
      end if;
    end if;

    --if two instructions are valid, inst(0) is always the older instruction
    --hence only that one should be issued if a dependency exists between the
    --pair
    case op(0) is
      when CALL =>
        if op(1) = FMT3 or op(1) = LDST then
          if (rd0 = rs1_1 and rs1_1v = '1') or (rd0 = rs2_1 and rs2_1v = '1') then
            conflict := '1';

            if is_ldst(de_inst(1)) = '1' then
              fpc_conflict := '1';
            end if;
          end if;
        end if;
        
      when LDST =>

        if op3(0)(2) = '1' and op3(0)(4) = '1' then
          --single issue STA on slot 0 since it can be reg write
          --to mmu cache registers
          conflict := '1';
          fpc_conflict := '1';
        end if;

        case op(1) is
          when LDST =>
            conflict     := '1';
            fpc_conflict := '1';
            
          when FMT3 =>
            --if load destination is a source operand for the
            --upcoming inst. create a conflict
            if de_inst(0)(21) = '0' then
              if (rd0 = rs1_1 and rs1_1v = '1') or (rd0 = rs2_1 and rs2_1v = '1') then
                conflict   := '1';
                alu_dexc_t := '1';
              end if;

              if is_ldd_int(de_inst(0)) = '1' then
                --if load double check the second register also
                if (rd0(4 downto 1) = rs1_1(4 downto 1) and rs1_1v = '1') or (rd0(4 downto 1) = rs2_1(4 downto 1) and rs2_1v = '1') then
                  conflict   := '1';
                  alu_dexc_t := '1';
                end if;
              end if;

              if alu_dexc_t = '1' and is_late_alu_op(de_inst(1)) = '1' and LATEALU = '1' then
                if not (DLATEWICC = '1' and is_wicc(de_inst(1)) = '1') then
                  conflict := '0';
                  alu_dexc := "10";
                  if is_wicc_latealu(de_inst(1)) = '1' then
                    wicc_dexc := '1';
                  end if;
                end if;
              end if;
              
            end if;

            if is_store_int(de_inst(0)) = '1' and de_inst(0)(13) = '0' and (de_inst(0)(4 downto 0) /= "00000") and (de_inst(0)(29 downto 25) /= "00000" or de_inst(0)(21 downto 19) = "111") then
              --store operation which uses 3 registers
              if de_inst(1)(13) = '0' and de_inst(1)(4 downto 0) /= "00000" and (is_fpop(de_inst(1)) = '0' or FPEN = false) then
                --integer operation also uses 2 regisers, it is not possible to
                --issue them at the same time since there are only 4 read ports
                conflict := '1';
              end if;
            end if;
            
          when others =>
            null;

        end case;
        
      when FMT3 =>

        if is_mul(de_inst(0)) = '1' then
          if rd0w = '1' then
            if (rd0 = rs1_1 and rs1_1v = '1') or (rd0 = rs2_1 and rs2_1v = '1') then
              conflict := '1';

              if is_late_alu_op(de_inst(1)) = '1' and LATEALU = '1' then
                if not (DLATEWICC = '1' and is_wicc(de_inst(1)) = '1') then
                  alu_dexc := "10";
                  conflict := '0';
                end if;
              end if;
            end if;

            --it is not possible to forward mul/div data before it is latched
            --in exception stage register. DIV is always dual issued so only
            --mul is needs to be checked explicitly.
            if is_store_int(de_inst(1)) = '1' then
              if rd0 = rd1 or (de_inst(1)(21 downto 19) = "111" and rd0(4 downto 1) = rd1(4 downto 1)) then
                conflict := '1';
              end if;
            end if;
          end if;
        end if;

        if op(1) = FMT3 or op(1) = LDST then
          if rd0w = '1' then
            if (rd0 = rs1_1 and rs1_1v = '1') or (rd0 = rs2_1 and rs2_1v = '1') then
              conflict       := '1';
              arith_conflict := '1';

              if is_ldst(de_inst(1)) = '1' then
                fpc_conflict := '1';
              end if;

              if is_divmulscc(de_inst(0)) = '1' then
                arith_conflict := '0';
              end if;
              
            end if;

            if is_logic(de_inst(0)) = '1' and is_logic(de_inst(1)) = '1' then
              conflict := '0';

              if rd0 = rs1_1 then
                use_logic(0) := '1';
              end if;

              if rd0 = rs2_1 and rs2_1v = '1' then
                use_logic(1) := '1';
              end if;
            end if;

            if is_addsub(de_inst(0)) = '1' and is_logic(de_inst(1)) = '1' then
              conflict := '0';

              if rd0 = rs1_1 then
                use_addsub(0) := '1';
              end if;

              if rd0 = rs2_1 and rs2_1v = '1' then
                use_addsub(1) := '1';
              end if;

            end if;

            --shifter usually have the shift amount as critical path so
            --it should be fine to increase path on input data little bit more
            use_logicshift := '0';
            if is_logic(de_inst(0)) = '1' and is_shift(de_inst(1)) = '1' then
              if rd0 = rs1_1 and (rs1_1 /= rs2_1 and rs2_1v = '1') then
                -- conflict := '0';
                -- use_logicshift := '1';
              end if;
            end if;

            if is_addsub(de_inst(0)) = '1' and is_load_int(de_inst(1)) = '1' then
              if de_inst(1)(13) = '0' and de_inst(1)(4 downto 0) = "00000" and arith_conflict = '1' then
                conflict         := '0';
                use_memaddr_add1 := '1';
              end if;
            end if;

            if arith_conflict = '1' and r.d.delay_slot_annuled = '1' then
              conflict     := '0';
              fpc_conflict := '0';
            end if;
            
          end if;

          if is_wicc_latealu(de_inst(1)) = '1' and arith_conflict = '1' and late_depen(0) = '0'
            and LATEALU = '1' and DLATEWICC = '0' then
            wicc_dmem := '1';
            conflict  := '0';
            if r.d.delay_slot_annuled = '1' then
              wicc_dmem := '0';
            end if;

            --if only ALUcc is late alu dependent, calculate ALUcc in exception
            --stage
            if late_depen(1) = '1' then
              if late_depen_t(1) = '0' then
                --if it depends on a load operation CC can be calculated in
                --memory stage
                wicc_dmem := '1';
              else
                wicc_dmem := '0';
                wicc_dexc := '1';
              end if;
            end if;

            if rd1w = '1' then
              --if wicc needs to write to a register it will happen in
              --exception stage although CC can be calclulated early in the pipeline
              alu_dexc := "10";
            end if;
          end if;

          if is_store_int(de_inst(1)) = '1' and de_inst(1)(13) = '0' and (de_inst(1)(4 downto 0) /= "00000") and (de_inst(1)(29 downto 25) /= "00000" or de_inst(1)(21 downto 19) = "111") then
            --store operation which uses 3 registers
            if de_inst(0)(13) = '0' and de_inst(0)(4 downto 0) /= "00000" and (is_fpop(de_inst(0)) = '0' or FPEN = false)then
              --integer operation also uses 2 regisers, it is not possible to
              --issue them at the same time since there are only 4 read ports
              conflict := '1';
            end if;
          end if;
          
        end if;

        if op3(0) = SAVE or op3(0) = RESTORE or op3(0) = RETT then
          if op(1) = FMT3 and (op3(1) = SAVE or op3(1) = RESTORE or op3(1) = RETT) then
            conflict := '1';
          end if;
        end if;

        if is_divmulscc(de_inst(0)) = '1' and is_divmulscc(de_inst(1)) = '1' then
          conflict := '1';
        end if;

        if is_wicc(de_inst(0)) = '1' and is_opx(de_inst(1)) = '1' then
          conflict := '1';
        end if;

        if is_wicc(de_inst(0)) = '1' and late_depen(0) = '1' and is_branch(de_inst(1)) = '1' then

          --if it is not a wicc_latealu then it is something that will be calculated
          --until expcetion stage like mulscc/divcc so we don't need to create
          --conflict since branche resolve logic will handle it
          
          if late_depen_t(0) = '1' and is_wicc_latealu(de_inst(0)) = '1' then
            conflict := '1';
          else
            if is_wicc_latealu(de_inst(0)) = '1' then
              wicc_dmem := '1';
              if rd0w = '1' then
                alu_dexc := "10";
              end if;
            end if;
          end if;

          if r.d.delay_slot_annuled = '1' then
            conflict := '0';
          end if;
        end if;

        if is_wicc_latealu(de_inst(1)) = '1' and arith_conflict = '1' and late_depen(0) = '1' then
          conflict := '1';
          if rd1w = '0' and late_depen_t(0) = '0' and is_light_alu(de_inst(0)) = '1' and LATEALU = '1' and DLATEWICC = '0' then
            --ALU operation will be calculated temporarily in the light ALU of
            --Memory stage and forwarded to the ALUcc operaton before the excpetion
            --stage
            conflict  := '0';
            wicc_dmem := '0';
            wicc_dexc := '1';
            alu_dexc  := "10";
          end if;
        end if;
        
      when FMT2 =>

        if op2(0) = SETHI then
          if rd0w = '1' then
            if (rd0 = rs1_1 and rs1_1v = '1') or (rd0 = rs2_1 and rs2_1v = '1') then
              conflict := '1';

              if is_ldst(de_inst(1)) = '1' then
                fpc_conflict := '1';
              end if;
              
            end if;

            if is_logic(de_inst(1)) = '1' then
              conflict := '0';
              if rd0 = rs1_1 then
                use_sethi(0) := '1';
              end if;

              if rd0 = rs2_1 and rs2_1v = '1' then
                use_sethi(1) := '1';
              end if;
            end if;

            
          end if;
        end if;

      when others =>
        null;
        
    end case;

    if (is_rdy(de_inst(0)) = '1' and is_mul_all(de_inst(1)) = '1') or
      (is_rdy(de_inst(1)) = '1' and is_mul_all(de_inst(0)) = '1') then
      conflict := '1';
    end if;

    --when a save restore is issued together with another instruction
    --which make a register write there are 
    --some tricky corner cases like
    --add ..,..,%o3
    --save ..,..,%i3
    --here o3 and i3 is same register.
    --we simplify the check by comparing lsb 2 bits
    --though it might cause some uneccesary stal 
    --we check lsb 2 bits to include LDD without any additional check also
    if (rd0(2 downto 1) = rd1(2 downto 1)) and (rd0(4 downto 3) = "01" or rd0(4 downto 3) = "11")
      and (rd1(4 downto 3) = "01" or rd1(4 downto 3) = "11") then
      if is_save(de_inst(1)) = '1' and rd0w = '1' then
        conflict := '1';
      end if;
      if is_save(de_inst(0)) = '1' and rd1w = '1' then
        conflict := '1';
      end if;
      if is_restore(de_inst(1)) = '1' and rd0w = '1' then
        conflict := '1';
      end if;
      if is_restore(de_inst(0)) = '1' and rd1w = '1' then
        conflict := '1';
      end if;
    end if;

    if r.d.delay_slot = '1' and (is_save(de_inst(0)) = '1' or is_restore(de_inst(0)) = '1') then
      --when save or restore is a delay slot instruction don't dual issue
      --otherwise it becomes very complex to calculate register for second inst
      --when save/restore reside in an annulable delay slot
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    if is_toc(de_inst(0)) = '1' and is_toc(de_inst(1)) = '1' then
      conflict := '1';
    end if;

    --to simplify the control logic
    if is_div(de_inst(0)) = '1' or is_div(de_inst(1)) = '1' then
      conflict     := '1';
      fpc_conflict := '1';
    end if;
    if is_mulscc(de_inst(0)) = '1' or is_mulscc(de_inst(1)) = '1' then
      conflict     := '1';
      fpc_conflict := '1';
    end if;
    if is_ticc(de_inst(0)) = '1' or is_tcctv(de_inst(0)) = '1' or is_ticc(de_inst(1)) = '1' or is_tcctv(de_inst(1)) = '1' then
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    wicc_d0 := '0';
    wicc_d1 := '0';
    wy_d0   := '0';
    wy_d1   := '0';
    --dont dual issue two instructions writing to ICC
    wicc_y_gen('1', de_inst(0), wicc_d0, wy_d0);
    wicc_y_gen('1', de_inst(1), wicc_d1, wy_d1);
    if wicc_d0 = '1' and wicc_d1 = '1' then
      conflict := '1';
    end if;

    if wicc_d0 = '1' and is_ticc(de_inst(1)) = '1' then
      --TCCTV is covered by wcc_d0 = '1' and wcc_d1 = '1'
      conflict := '1';
    end if;

    if (rd0 = rd1) and (rd0w = '1' and rd1w = '1') and r.d.inst_valid = "11" then
      --note that this optimization do not remove the conflict so if
      --there is a rd<->rs dependency between two it will hold
      --no_forward bit will only set if both instructions are issued in decode
      --stage
      no_forward := '1';
      if (is_ldd_int(de_inst(0)) = '1' or is_ldd_int(de_inst(1)) = '1'
          or is_toc(de_inst(0)) = '1' or is_toc(de_inst(1)) = '1'
          or is_divmulscc(de_inst(0)) = '1' or is_divmulscc(de_inst(1)) = '1'
          or is_saverestore(de_inst(0)) = '1' or is_saverestore(de_inst(1)) = '1') then
        conflict   := '1';
        no_forward := '0';
      end if;
    end if;

    if (is_ldd_int(de_inst(1)) = '1') then
      if rd0(4 downto 1) = rd1(4 downto 1) and rd0w = '1' then
        conflict := '1';
      end if;
    end if;
    if (is_ldd_int(de_inst(0)) = '1') then
      if rd0(4 downto 1) = rd1(4 downto 1) and rd1w = '1' then
        conflict := '1';
      end if;
    end if;

    --Single issue power down instructions
    if is_pwd(de_inst(0)) = '1' or is_pwd(de_inst(1)) = '1' then
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    --Single issue atomic instructions
    if is_atomic(de_inst(0)) = '1' or is_atomic(de_inst(1)) = '1' then
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    --Single issue flush instruction
    if is_flush(de_inst(0)) = '1' or is_flush(de_inst(1)) = '1' then
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    if FPEN then
      if (is_fpop(de_inst(0)) = '1' or is_fpu_branch(de_inst(0)) = '1') and
         (is_fpop(de_inst(1)) = '1' or is_fpu_branch(de_inst(1)) = '1') then
        conflict     := '1';
        fpc_conflict := '1';
      end if;
    end if;

    --right now no speculative fpop issue
    --if a branch has a=0 delay slot it is not speculative so it can be issued
    --together with branch
    --an FPOP2 can not be issued together with a FBcc because when it reaches
    --access stage it will affect the flag hence branch result will be wrong
    --if the branch itself is speculative it will not be dual issued with the
    --check in the decode stage itself
    if FPEN and is_fpu_branch(de_inst(0)) = '1' and is_fpop(de_inst(1)) = '1' then
      if FPSPEC = '0' or is_ficc(de_inst(1)) = '1' or de_inst(0)(29) = '1' then
        conflict     := '1';
        fpc_conflict := '1';
      end if;
    end if;

    if FPEN and is_branch(de_inst(0)) = '1' and is_fpop(de_inst(1)) = '1' and de_inst(0)(29) = '1' then
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    --if two instructions needs to execute on same lane create a conflict
    if (inst_lane_check(de_inst(0), '0') = '1' and inst_lane_check(de_inst(1), '0') = '1') or
      (inst_lane_check(de_inst(0), '1') = '1' and inst_lane_check(de_inst(1), '1') = '1') then
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    --for backward compability right now issue only single instruction
    --when WPSR/WY/WRWIM/WRTBR/WRASR is in the pipeline
    --later on you might optimize the WY
    if (is_wsri(de_inst(0)) = '1' and r.d.inst_valid(0) = '1')
      or (is_wsri(de_inst(1)) = '1' and r.d.inst_valid(1) = '1') then
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    if r.a.ctrl.single_issue = '1' or r.e.ctrl.single_issue = '1' or r.m.ctrl.single_issue = '1' then
      conflict := '1';
      fpc_conflict := '1';
    end if;

    if is_load_int(de_inst(0)) = '1' and is_load_int(de_inst(1)) = '1' and r.d.delay_slot_annuled = '1' and r.d.dual_ldissue_en = '1' and dco.iuctrl.single_issue = '0' and r.a.ctrl.single_issue = '0' and r.e.ctrl.single_issue = '0' and r.m.ctrl.single_issue = '0' then
      conflict     := '0';
      dual_ldissue := '1';
    end if;

    --this is needed for RDPSR
    if is_rdsri(de_inst(0)) = '1' or is_rdsri(de_inst(1)) = '1' then
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    if FPEN and (is_stdfq(de_inst(0)) = '1' or is_stdfq(de_inst(1)) = '1') then
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    --This is needed to handle traps correctly
    --later on you might do this check only FP traps is enabled to reduce
    --unnecessary single issue of Fbranch/Fpop combinations
    if FPEN and (fpu5i.trapon_flop = '1' or fpu5i.fccready = '0') then
      if is_fpu_branch(de_inst(0)) = '1' and is_fpu_branch(de_inst(1)) = '1' then
        conflict     := '1';
        fpc_conflict := '1';
      end if;
    end if;

    if dco.iuctrl.single_issue = '1' or r.w.step.en = '1' then
      conflict     := '1';
      fpc_conflict := '1';
    end if;

    if BPRED = '0' then
      --if branch prediction is disabled dont issue a branch which
      --depends on wicc in the same pair otherwise it will be a dead lock
      --in issue stage since branch can not proceed when there is a wicc
      --in access stage
      if is_wicc(de_inst(0)) = '1' and is_branch(de_inst(1)) = '1' then
        conflict := '1';
      end if;
      
    end if;

    if conflict = '1' then
      alu_dexc := "00";
    end if;

    if inst_valid = "00" then
      de_issue     := (others => '1');
      de_fpc_issue := (others => '1');
    elsif inst_valid = "01" then
      de_issue     := "01";
      de_fpc_issue := "01";
    elsif inst_valid = "10" then
      de_issue     := "10";
      de_fpc_issue := "10";
    else
      de_issue     := "11";
      de_fpc_issue := "11";
      if conflict = '1' then
        de_issue := "01";
      end if;
      if fpc_conflict = '1' then
        de_fpc_issue := "01";
      end if;
    end if;

    if r.d.mexc = '1' then
      --during memory exception issue both instructions they will not have an impact
      --on pipeline state, if you don't issue both the later issued will become
      --invalid hence next pc will fail
      de_issue     := "11";
      de_fpc_issue := "11";
    end if;

    if LATEALU = '0' then
      alu_dexc  := "00";
      wicc_dexc := '0';
      wicc_dmem := '0';
    end if;

  end;

-- immediate data generation

  function imm_data (insn : word)
    return word is
    variable immediate_data, inst : word;
  begin
    immediate_data := (others => '0');
    inst           := insn;
    case inst(31 downto 30) is
      when FMT2 =>
        immediate_data := inst(21 downto 0) & "0000000000";
      when others =>
        immediate_data(31 downto 13) := (others => inst(12));
        immediate_data(12 downto 0)  := inst(12 downto 0);
        if inst(13) = '0' and inst(4 downto 0) = "00000" then
          immediate_data := (others => '0');
        end if;
    end case;
    if is_atomic(insn) = '1' and inst(24 downto 19) = CASA then
      immediate_data := (others => '0');
    end if;
    return(immediate_data);
  end;

-- read special registers
  function get_spr (r : registers; inst : word) return word is
    variable spr : word;
  begin
    spr := (others => '0');
    case inst(24 downto 19) is
      when RDPSR =>
        spr(31 downto 5) := conv_std_logic_vector(IMPL, 4) &
                            conv_std_logic_vector(VER, 4) & r.m.icc & "000000" &
                            r.w.s.ec & r.w.s.ef &
                            r.w.s.pil & r.e.su & r.w.s.ps & r.e.et;
        spr(NWINLOG2-1 downto 0) := r.e.cwp;
      when RDTBR =>
        spr(31 downto 4) := r.w.s.tba & r.w.s.tt;
      when RDWIM =>
        spr(NWIN-1 downto 0) := r.w.s.wim;
      when others =>
    end case;
    return(spr);
  end;


  procedure load_forward_s(lane : integer range 0 to 1; v : in registers; r : in registers; ldfwd_rs1, ldfwd_rs2 : out std_logic) is
    variable ldd_e, ldd_m : std_logic;
  begin
    ldfwd_rs1 := '0';
    ldfwd_rs2 := '0';

    ldd_e := '0';
    if is_ldd_int(r.e.ctrl.inst(0)) = '1' then
      ldd_e := '1';
    end if;

    ldd_m := '0';
    if is_ldd_int(r.m.ctrl.inst(0)) = '1' then
      ldd_m := '1';
    end if;

    if (is_load_int(r.m.ctrl.inst(0)) = '1' and ldd_m = '0' and r.m.ctrl.inst_valid(0) = '1' and r.m.ctrl.delay_annuled(0) = '0' and r.m.ctrl.no_forward(0) = '0') and r.m.ctrl.rdw(0) = '1' then
      if r.a.rs1(lane) = r.m.ctrl.rd(0) then
        ldfwd_rs1 := '1';
      end if;
      if r.a.rs2(lane) = r.m.ctrl.rd(0) then
        ldfwd_rs2 := '1';
      end if;
    elsif (is_load_int(r.m.ctrl.inst(0)) = '1' and ldd_m = '1' and r.m.ctrl.inst_valid(0) = '1' and r.m.ctrl.delay_annuled(0) = '0' and r.m.ctrl.no_forward(0) = '0' and r.m.ctrl.rdw(0) = '1') then
      if r.a.rs1(lane)(RFBITS downto 1) = r.m.ctrl.rd(0)(RFBITS downto 1) then
        ldfwd_rs1 := '1';
        if r.m.ctrl.ldd_z = '1' and r.a.rs1(lane)(0) = '0' then
          ldfwd_rs1 := '0';
        end if;
      end if;
      if r.a.rs2(lane)(RFBITS downto 1) = r.m.ctrl.rd(0)(RFBITS downto 1) then
        ldfwd_rs2 := '1';
        if r.m.ctrl.ldd_z = '1' and r.a.rs2(lane)(0) = '0' then
          ldfwd_rs2 := '0';
        end if;
      end if;
    end if;

    --if the load operation is in memory stage make sure that an instruction in
    --the execute stage or another slot in memory stage do not write to the same destination because then
    --load forwarding is invalid.
    --RD is compared between the execute and access stage in order to cover
    --ldd operations correctly
    --(here v.m might be unnecessary since on branch missprediction forwarding
    --will become pointless think about that)

    if v.x.ctrl.inst_valid(1) = '1' and r.m.ctrl.swap = '0' and r.m.ctrl.delay_annuled(1) = '0' and r.m.ctrl.no_forward(1) = '0' and r.m.ctrl.rdw(1) = '1' then
      if r.m.ctrl.rd(1) = r.a.rs1(lane) then
        ldfwd_rs1 := '0';
      end if;
      if r.m.ctrl.rd(1) = r.a.rs2(lane) then
        ldfwd_rs2 := '0';
      end if;
    end if;

    for i in 0 to 1 loop
      if v.m.ctrl.inst_valid(i) = '1' and r.e.ctrl.delay_annuled(i) = '0' and r.e.ctrl.no_forward(i) = '0' and r.e.ctrl.rdw(i) = '1' then
        if r.e.ctrl.rd(i) = r.a.rs1(lane) then
          ldfwd_rs1 := '0';
        end if;
        if r.e.ctrl.rd(i) = r.a.rs2(lane) then
          ldfwd_rs2 := '0';
        end if;
      end if;
    end loop;

    
  end;


  procedure muldiv_forward_s(lane : integer range 0 to 1; v : in registers; r : in registers; use_muldiv_rs1, use_muldiv_rs2 : out std_logic) is
    variable execute_stage_depen : std_logic_vector(1 downto 0);
  begin

    use_muldiv_rs1      := '0';
    use_muldiv_rs2      := '0';
    execute_stage_depen := "00";

    for i in 0 to 1 loop
      if v.m.ctrl.inst_valid(0) = '1' and r.e.ctrl.delay_annuled(0) = '0' and r.e.ctrl.no_forward(0) = '0' and r.e.ctrl.rdw(0) = '1' and r.e.ctrl.rdw(0) = '1' and r.e.ctrl.rd(0) = r.m.ctrl.rd(i) then
        execute_stage_depen(i) := '1';
      end if;
      --if there is an LDD operation which overwrites the mul/div dest in memory stage
      --there is no problem because instruction will not proceed to execute
      --stage in that case or it will proceed but will be calculated in late
      --ALU
      if v.m.ctrl.inst_valid(1) = '1' and r.e.ctrl.delay_annuled(1) = '0' and r.e.ctrl.no_forward(1) = '0' and r.e.ctrl.rdw(1) = '1' and r.e.ctrl.rd(1) = r.m.ctrl.rd(i) then
        execute_stage_depen(i) := '1';
      end if;
    end loop;

    --two dependent instructions can be issued together due to cascaded alu operations
    --and it can overwrite the memory forward data
    --but in that case ldfwd signal becomes obsolate since actual data is forwarded
    --later on in the execute stage

    if r.m.ctrl.inst_valid(1) = '1' and is_div(r.m.ctrl.inst(1)) = '1' and r.m.ctrl.delay_annuled(1) = '0' and r.m.ctrl.no_forward(1) = '0' and r.m.ctrl.rdw(1) = '1' and execute_stage_depen(1) = '0' then
      if r.m.ctrl.rd(1) = r.a.rs1(lane) then
        use_muldiv_rs1 := '1';
      end if;
      if r.m.ctrl.rd(1) = r.a.rs2(lane) then
        use_muldiv_rs2 := '1';
      end if;
    end if;

    for i in 0 to 1 loop
      if r.m.ctrl.inst_valid(i) = '1' and is_mul(r.m.ctrl.inst(i)) = '1' and r.m.ctrl.delay_annuled(i) = '0' and r.m.ctrl.no_forward(i) = '0' and r.m.ctrl.rdw(i) = '1' and execute_stage_depen(i) = '0' then
        if r.m.ctrl.rd(i) = r.a.rs1(lane) then
          use_muldiv_rs1 := '1';
        end if;
        if r.m.ctrl.rd(i) = r.a.rs2(lane) then
          use_muldiv_rs2 := '1';
        end if;
      end if;
    end loop;
    
  end;


-- EXE operation

  procedure alu_op(lane                            :     integer range 0 to 1; r : in registers; iop1, iop2 : in word; me_icc : std_logic_vector(3 downto 0);
  my                                               :     std_logic; aop1, aop2 : out word; aluop : out std_logic_vector(2 downto 0);
  alusel                                           : out std_logic_vector(1 downto 0); aluadd : out std_logic;
  shcnt                                            : out std_logic_vector(4 downto 0); sari, shleft, ymsb,
  mulins, divins, mulstep, macins, fldbp2z, invop2 : out std_logic) is
    variable op  : std_logic_vector(1 downto 0);
    variable op2 : std_logic_vector(2 downto 0);
    variable op3 : std_logic_vector(5 downto 0);
    variable rd  : std_logic_vector(4 downto 0);
    variable icc : std_logic_vector(3 downto 0);
    variable y0  : std_logic;
  begin

    op      := r.a.ctrl.inst(lane)(31 downto 30);
    op2     := r.a.ctrl.inst(lane)(24 downto 22);
    op3     := r.a.ctrl.inst(lane)(24 downto 19);
    aop1    := iop1;
    aop2    := iop2;
    fldbp2z := '0';
    aluop   := EXE_NOP;
    alusel  := EXE_RES_MISC;
    aluadd  := '1';
    shcnt   := iop2(4 downto 0);
    sari    := '0';
    shleft  := '0';
    invop2  := '0';
    ymsb    := iop1(0);
    mulins  := '0';
    divins  := '0';
    mulstep := '0';
    macins  := '0';

    --logic op in the ALU takes care of
    --Y forwarding
    y0 := my;

    --icc forwarding is done outside of the procedure
    icc := me_icc;

    case op is
      when CALL =>
        aluop := EXE_LINK;
      when FMT2 =>
        case op2 is
          when SETHI =>
            aluop := EXE_PASS2;
          when others =>
        end case;
      when FMT3 =>
        case op3 is
          when JMPL =>
            aluop := EXE_LINK;
          when IADD | ADDX | ADDCC | ADDXCC | TADDCC | TADDCCTV | SAVE | RESTORE |
            TICC | RETT =>
            alusel := EXE_RES_ADD;
          when ISUB | SUBX | SUBCC | SUBXCC | TSUBCC | TSUBCCTV =>
            alusel := EXE_RES_ADD;
            aluadd := '0';
            aop2   := not iop2;
            invop2 := '1';
          when MULSCC =>
            if lane = 1 then
              alusel := EXE_RES_ADD;
              aop1   := (icc(3) xor icc(1)) & iop1(31 downto 1);
              if y0 = '0' then
                aop2    := (others => '0');
                fldbp2z := '1';
              end if;
            end if;
            mulstep := '1';
          when UMUL | UMULCC | SMUL | SMULCC =>
            if MULEN then
              mulins := '1';
            end if;
          when UMAC | SMAC =>
            if MACEN then
              mulins := '1';
              macins := '1';
            end if;
          when UDIV | UDIVCC | SDIV | SDIVCC =>
            if DIVEN then
              aluop  := EXE_DIV;
              alusel := EXE_RES_LOGIC;
              divins := '1';
            end if;
          when IAND | ANDCC =>
            aluop  := EXE_AND;
            alusel := EXE_RES_LOGIC;
          when ANDN | ANDNCC =>
            aluop  := EXE_ANDN;
            alusel := EXE_RES_LOGIC;
          when IOR | ORCC =>
            aluop  := EXE_OR;
            alusel := EXE_RES_LOGIC;
          when ORN | ORNCC =>
            aluop  := EXE_ORN;
            alusel := EXE_RES_LOGIC;
          when IXNOR | XNORCC =>
            aluop  := EXE_XNOR;
            alusel := EXE_RES_LOGIC;
          when XORCC | IXOR | WRPSR | WRWIM | WRTBR | WRY =>
            aluop  := EXE_XOR;
            alusel := EXE_RES_LOGIC;
          when RDPSR | RDTBR | RDWIM =>
            aluop := EXE_SPR;
          when RDY =>
            aluop := EXE_RDY;
          when ISLL =>
            aluop  := EXE_SLL;
            alusel := EXE_RES_SHIFT;
            shleft := '1';
            shcnt  := not iop2(4 downto 0);
            invop2 := '1';
          when ISRL =>
            aluop  := EXE_SRL;
            alusel := EXE_RES_SHIFT;
          when ISRA =>
            aluop  := EXE_SRA;
            alusel := EXE_RES_SHIFT;
            sari   := iop1(31);
          when FPOP1 | FPOP2 =>
          when others        =>
        end case;
      when others =>                    -- LDST
        --if CASAEN then
        --  if (r.a.ctrl.cnt = "10") then
        --    alusel := EXE_RES_ADD;
        --    aluadd := '0';
        --    aop2 := not iop2;
        --    invop2 := '1';
--        ldbp2 := '0';
        --  end if;
        --end if;
        alusel := EXE_RES_ADD;
    end case;
  end;

-- generate carry-in for alu

  procedure cin_gen(lane :    integer range 0 to 1; r : registers;
  me_cin                 : in std_logic; cin : out std_logic) is
    variable op   : std_logic_vector(1 downto 0);
    variable op3  : std_logic_vector(5 downto 0);
    variable ncin : std_logic;
  begin

    op   := r.a.ctrl.inst(lane)(31 downto 30);
    op3  := r.a.ctrl.inst(lane)(24 downto 19);
    ncin := me_cin;
    cin  := '0';
    case op is
      when FMT3 =>
        case op3 is
          when ISUB | SUBCC | TSUBCC | TSUBCCTV => cin := '1';
          when ADDX | ADDXCC                    => cin := ncin;
          when SUBX | SUBXCC                    => cin := not ncin;
          when others                           => null;
        end case;
        -- when LDST =>
        --   if CASAEN and (r.a.ctrl.cnt = "10") then cin := '1'; end if;
      when others => null;
    end case;
  end;

  procedure logic_op(r                   : registers;
                     ind                 : integer range 0 to 1;
                     aluin1, aluin2, mey : word;
                     ymsb                : std_logic; logicres, y : out word) is
    variable logicout : word;
  begin
    case r.e.alu_ctrl.aluop(ind) is
      when EXE_AND  => logicout := aluin1 and aluin2;
      when EXE_ANDN => logicout := aluin1 and not aluin2;
      when EXE_OR   => logicout := aluin1 or aluin2;
      when EXE_ORN  => logicout := aluin1 or not aluin2;
      when EXE_XOR  => logicout := aluin1 xor aluin2;
      when EXE_XNOR => logicout := aluin1 xor not aluin2;
      when EXE_DIV  =>
        if DIVEN then logicout := aluin2;
        else logicout          := (others => '-'); end if;
      when others => logicout := (others => '-');
    end case;
    if (r.e.ctrl.wy(1) and r.e.mulstep(1) and r.e.ctrl.inst_valid(1)) = '1' then
      y := ymsb & r.m.y(31 downto 1);
    elsif (r.e.ctrl.wy(0) = '1' and r.e.ctrl.inst_valid(0) = '1' and is_mul(r.e.ctrl.inst(0)) = '0') or
      (r.e.ctrl.wy(1) = '1' and r.e.ctrl.inst_valid(1) = '1' and is_mul(r.e.ctrl.inst(1)) = '0') then
      --WRY instruction
      y := logicout;
    elsif (r.m.ctrl.wy(0) = '1' and r.m.ctrl.inst_valid(0) = '1') or
      (r.m.ctrl.wy(1) = '1' and r.m.ctrl.inst_valid(1) = '1') then
      y := mey;
    elsif (r.x.ctrl.wy(0) = '1' and r.x.ctrl.inst_valid(0) = '1') or
      (r.x.ctrl.wy(1) = '1' and r.x.ctrl.inst_valid(1) = '1') then
      y := r.x.y;
    else
      y := r.w.s.y;
    end if;
    logicres := logicout;
  end;

  procedure logic_op_exc(r              :     registers;
                         aluop          :     std_logic_vector(2 downto 0);
                         aluin1, aluin2 :     word;
                         logicres       : out word) is
    variable logicout : word;
  begin
    case aluop is
      when EXE_AND  => logicout := aluin1 and aluin2;
      when EXE_ANDN => logicout := aluin1 and not aluin2;
      when EXE_OR   => logicout := aluin1 or aluin2;
      when EXE_ORN  => logicout := aluin1 or not aluin2;
      when EXE_XOR  => logicout := aluin1 xor aluin2;
      when EXE_XNOR => logicout := aluin1 xor not aluin2;
      when others   => logicout := (others => 'X');
    end case;
    logicres := logicout;
  end;

  procedure misc_op(r              :     registers;
                    ind            :     integer range 0 to 1;
                    wpr            :     watchpoint_registers;
                    aluin1, aluin2 :     word; ldata : word64; mey : word;
                    mout           : out word) is
    variable miscout, bpdata, stdata : word;
    variable wpi                     : integer;
  begin
    wpi                  := 0;
    miscout              := (others => '0');
    miscout(31 downto 0) := r.e.ctrl.inst_pc(ind);
    bpdata               := aluin1;

    case r.e.alu_ctrl.aluop(ind) is
      when EXE_STB => miscout := bpdata(7 downto 0) & bpdata(7 downto 0) &
                                   bpdata(7 downto 0) & bpdata(7 downto 0);
      when EXE_STH   => miscout := bpdata(15 downto 0) & bpdata(15 downto 0);
      when EXE_PASS1 => miscout := bpdata;
      when EXE_PASS2 => miscout := aluin2;
      when EXE_ONES  => miscout := (others => '1');
      when EXE_RDY   =>
        if MULEN and (r.m.ctrl.wy /= "00") then
          miscout := mey;
        else
          miscout := r.x.y;
        end if;
        if (NWP > 0) and (r.e.ctrl.inst(ind)(18 downto 17) = "11") then
          wpi := conv_integer(r.e.ctrl.inst(ind)(16 downto 15));
          if r.e.ctrl.inst(ind)(14) = '0' then
            miscout := wpr(wpi).addr & '0' & wpr(wpi).exec;
          else
            miscout := wpr(wpi).mask & wpr(wpi).load & wpr(wpi).store;
          end if;
        end if;
        if (r.e.ctrl.inst(ind)(18 downto 17) = "10") and (r.e.ctrl.inst(ind)(14) = '1') then  --%ASR17
          miscout := asr17_gen(r, cpu_index);
        end if;
        if MACEN then
          if (r.e.ctrl.inst(ind)(18 downto 14) = "10010") then   --%ASR18
            if ((r.m.mac = '1') and not MACPIPE) or ((r.x.mac = '1') and MACPIPE) then
              miscout := mulo.result(31 downto 0);   -- data forward of asr18
            else
              miscout := r.w.s.asr18;
            end if;
          else
            if ((r.m.mac = '1') and not MACPIPE) or ((r.x.mac = '1') and MACPIPE) then
              miscout := mulo.result(63 downto 32);  -- data forward Y
            end if;
          end if;
        end if;
        if (r.e.ctrl.inst(ind)(18 downto 14) = "10110") then     --%ASR22
          miscout(31)          := r.w.s.ducnt;
          miscout(30 downto 0) := dbgi.timer(62 downto 32);
        elsif (r.e.ctrl.inst(ind)(18 downto 14) = "10111") then  --%ASR23
          miscout := dbgi.timer(31 downto 0);
        end if;
      when EXE_SPR =>
        miscout := get_spr(r, r.e.ctrl.inst(ind));
      when others => null;
    end case;
    mout := miscout;
  end;


  procedure alu_select(lane :     integer range 0 to 1; v : registers; r : registers; addout : std_logic_vector(32 downto 0);
  op1, op2                  :     word; shiftout, logicout, miscout : word; res : out word;
  me_icc                    :     std_logic_vector(3 downto 0);
  icco, icco_dannul         : out std_logic_vector(3 downto 0); divz, cz : out std_logic) is
    variable op        : std_logic_vector(1 downto 0);
    variable op3       : std_logic_vector(5 downto 0);
    variable icc       : std_logic_vector(3 downto 0);
    variable aluresult : word;
  begin
    op  := r.e.ctrl.inst(lane)(31 downto 30);
    op3 := r.e.ctrl.inst(lane)(24 downto 19);
    icc := (others => '0');
    case r.e.alu_ctrl.alusel(lane) is
      when EXE_RES_ADD =>
        aluresult := addout(32 downto 1);
        if r.e.alu_ctrl.aluadd(lane) = '0' then
          icc(0) := ((not op1(31)) and not op2(31)) or             -- Carry
                    (addout(32) and ((not op1(31)) or not op2(31)));
          icc(1) := (op1(31) and (op2(31)) and not addout(32)) or  -- Overflow
                    (addout(32) and (not op1(31)) and not op2(31));
        else
          icc(0) := (op1(31) and op2(31)) or                       -- Carry
                    ((not addout(32)) and (op1(31) or op2(31)));
          icc(1) := (op1(31) and op2(31) and not addout(32)) or    -- Overflow
                    (addout(32) and (not op1(31)) and (not op2(31)));
        end if;
        if notag = 0 then
          case op is
            when FMT3 =>
              case op3 is
                when TADDCC | TADDCCTV =>
                  icc(1) := op1(0) or op1(1) or op2(0) or op2(1) or icc(1);
                when TSUBCC | TSUBCCTV =>
                  icc(1) := op1(0) or op1(1) or (not op2(0)) or (not op2(1)) or icc(1);
                when others => null;
              end case;
            when others => null;
          end case;
        end if;

        if aluresult = zero32 then icc(2) := '1'; end if;
      when EXE_RES_SHIFT =>
        aluresult := shiftout;
      when EXE_RES_LOGIC =>
        aluresult                         := logicout;
        if aluresult = zero32 then icc(2) := '1'; end if;
      when others => aluresult := miscout;
    end case;
    if r.e.jmpl = '1' then
      aluresult := r.e.ctrl.pc(31 downto 2) & "00";
    end if;
    icc(3) := aluresult(31);
    divz   := icc(2);
    if r.e.ctrl.wicc = '1' and v.m.ctrl.inst_valid(1) = '1' and v.m.ctrl.delay_annuled(1) = '0' and r.e.ctrl.wicc_muldiv = '0' and r.e.ctrl.wicc_dmem = '0' and r.e.ctrl.wicc_dexc = '0' then      
      if (op = FMT3) and (op3 = WRPSR) then
        icco := logicout(23 downto 20);
      else
        icco := icc;
      end if;
      --there is no speculative update to r.m.icc / r.x.icc / r.w.s.icc hence
      --no need to add more checks
    elsif r.m.ctrl.wicc = '1' and r.m.ctrl.inst_valid(1) = '1' and r.m.ctrl.wicc_dexc = '0' then
      icco := me_icc;
    elsif r.x.ctrl.wicc = '1' and r.x.ctrl.inst_valid(1) = '1' then
      icco := r.x.icc;
    else
      icco := r.w.s.icc;
    end if;
    icco_dannul := icc;
    res         := aluresult;
    cz          := icc(2);
  end;

  procedure alu_select_exc(r        :     registers;
                           alusel   :     std_logic_vector(1 downto 0);
                           aluadd   :     std_logic;
                           addout   :     std_logic_vector(32 downto 0);
                           op1, op2 :     word;
                           logicout :     word;
                           shiftout :     word;
                           icco     : out std_logic_vector(3 downto 0);
                           res      : out word) is
    variable op        : std_logic_vector(1 downto 0);
    variable op3       : std_logic_vector(5 downto 0);
    variable icc       : std_logic_vector(3 downto 0);
    variable aluresult : word;
  begin
    op        := r.x.ctrl.inst(1)(31 downto 30);
    op3       := r.x.ctrl.inst(1)(24 downto 19);
    icc       := (others => '0');
    aluresult := addout(32 downto 1);
    case alusel is
      when EXE_RES_ADD =>
        if aluadd = '0' then
          icc(0) := ((not op1(31)) and not op2(31)) or             -- Carry
                    (addout(32) and ((not op1(31)) or not op2(31)));
          icc(1) := (op1(31) and (op2(31)) and not addout(32)) or  -- Overflow
                    (addout(32) and (not op1(31)) and not op2(31));
        else
          icc(0) := (op1(31) and op2(31)) or                       -- Carry
                    ((not addout(32)) and (op1(31) or op2(31)));
          icc(1) := (op1(31) and op2(31) and not addout(32)) or    -- Overflow
                    (addout(32) and (not op1(31)) and (not op2(31)));
        end if;

        if aluresult = zero32 then
          icc(2) := '1';
        end if;
      when EXE_RES_LOGIC =>
        aluresult := logicout;
        if aluresult = zero32 then
          icc(2) := '1';
        end if;
      when EXE_RES_SHIFT =>
        aluresult := shiftout;
      when others =>
    end case;
    icc(3) := aluresult(31);
    icco   := icc;
    res    := aluresult;
  end;

  --ALU without condition code 
  procedure alu_select_nocc(lane                        :     integer range 0 to 1;
                            r                           :     registers;
                            addout                      :     std_logic_vector(32 downto 0);
                            shiftout, logicout, miscout :     word;
                            res                         : out word
                            ) is
    variable op        : std_logic_vector(1 downto 0);
    variable op3       : std_logic_vector(5 downto 0);
    variable aluresult : word;
  begin
    op  := r.e.ctrl.inst(lane)(31 downto 30);
    op3 := r.e.ctrl.inst(lane)(24 downto 19);
    case r.e.alu_ctrl.alusel(lane) is
      when EXE_RES_ADD =>
        aluresult := addout(32 downto 1);
      when EXE_RES_SHIFT =>
        aluresult := shiftout;
      when EXE_RES_LOGIC =>
        aluresult := logicout;
      when others =>
        aluresult := miscout;
    end case;
    res := aluresult;
  end;

  procedure alu_select_nocc_exc(r                   :     registers;
                                 addout             :     std_logic_vector(32 downto 0);
                                 shiftout, logicout :     word;
                                 res                : out word
                                 ) is
    variable aluresult : word;
  begin
    aluresult := addout(32 downto 1);
    case r.x.alu_ctrl.alusel(0) is
      when EXE_RES_SHIFT =>
        aluresult := shiftout;
      when EXE_RES_LOGIC =>
        aluresult := logicout;
      when others =>
        null;
    end case;
    res := aluresult;
  end;

  procedure alu_select_nocc_mem(r         :     registers;
                                 addout   :     std_logic_vector(32 downto 0);
                                 logicout :     word;
                                 res      : out word
                                 ) is
    variable aluresult : word;
  begin
    aluresult := addout(32 downto 1);
    case r.m.alu_ctrl.alusel(0) is
      when EXE_RES_LOGIC =>
        aluresult := logicout;
      when others =>
        null;
    end case;
    res := aluresult;
  end;

  procedure gen_exstdata(r                 :     registers;
                         regdata           :     std_logic_vector(63 downto 0);
                         exstdata_fwd      : out std_logic;
                         stdata            : out std_logic_vector(63 downto 0);
                         mem_data_alu1     : out std_logic_vector(1 downto 0);
                         mem_data_xdataH   : out std_logic_vector(1 downto 0);
                         mem_data_xdataL   : out std_logic_vector(1 downto 0);
                         mem_data_xresult0 : out std_logic_vector(1 downto 0);
                         mem_data_lalu0    : out std_logic_vector(1 downto 0);
                         mem_data_lalu1    : out std_logic_vector(1 downto 0)
                         ) is
    variable vstdata         : std_logic_vector(63 downto 0);
    variable std_v           : std_logic;
    variable ldd_v           : std_logic;
    variable ldd_vm          : std_logic;
    variable m_lane0_valid   : std_logic;
    variable m_lane1_valid   : std_logic;
    variable x_lane0_valid   : std_logic;
    variable x_lane1_valid   : std_logic;
    variable mem_lane_ow     : std_logic_vector(1 downto 0);
    variable mem_lane_ow_std : std_logic_vector(1 downto 0);
    variable xc_lane_ow      : std_logic_vector(1 downto 0);
    variable xc_lane_ow_std  : std_logic_vector(1 downto 0);
  begin
    vstdata      := regdata;
    exstdata_fwd := '0';

    std_v := '0';
    if is_stdb(r.e.ctrl.inst(0)) = '1' then
      std_v := '1';
    end if;
    ldd_v := '0';
    if (is_ldd_int(r.x.ctrl.inst(0)) = '1') then
      ldd_v := '1';
    end if;
    ldd_vm := '0';
    if (is_ldd_int(r.m.ctrl.inst(0)) = '1') then
      ldd_vm := '1';
    end if;

    m_lane0_valid := '0';
    if r.m.ctrl.rdw(0) = '1' and r.m.ctrl.inst_valid(0) = '1' and r.m.ctrl.delay_annuled(0) = '0' and r.m.ctrl.no_forward(0) = '0' then
      m_lane0_valid := '1';
    end if;
    m_lane1_valid := '0';
    if r.m.ctrl.rdw(1) = '1' and r.m.ctrl.inst_valid(1) = '1' and r.m.ctrl.delay_annuled(1) = '0' and r.m.ctrl.no_forward(1) = '0' then
      m_lane1_valid := '1';
    end if;
    x_lane0_valid := '0';
    if r.x.ctrl.rdw(0) = '1' and r.x.ctrl.inst_valid(0) = '1' and r.x.ctrl.delay_annuled(0) = '0' and r.x.ctrl.no_forward(0) = '0' then
      x_lane0_valid := '1';
    end if;
    x_lane1_valid := '0';
    if r.x.ctrl.rdw(1) = '1' and r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.delay_annuled(1) = '0' and r.x.ctrl.no_forward(1) = '0' then
      x_lane1_valid := '1';
    end if;

    --forwarding (63 downto 32)
    if m_lane1_valid = '1' and r.e.rs3 = r.m.ctrl.rd(1) then
      vstdata(63 downto 32) := r.m.result(1);
      exstdata_fwd          := '1';
    elsif m_lane0_valid = '1' and r.e.rs3 = r.m.ctrl.rd(0) then
      vstdata(63 downto 32) := r.m.result(0);
      exstdata_fwd          := '1';
    elsif x_lane0_valid = '1' and is_load_int(r.x.ctrl.inst(0)) = '0' and r.e.rs3 = r.x.ctrl.rd(0) then
      vstdata(63 downto 32) := r.x.result(0);
      exstdata_fwd          := '1';
    elsif x_lane1_valid = '1' and r.e.rs3 = r.x.ctrl.rd(1) then
      vstdata(63 downto 32) := r.x.result(1);
      exstdata_fwd          := '1';
    elsif x_lane0_valid = '1' and is_load_int(r.x.ctrl.inst(0)) = '1' and r.e.rs3 = r.x.ctrl.rd(0) then
      vstdata(63 downto 32) := r.x.data(0)(63 downto 32);
      exstdata_fwd          := '1';
      if ldd_v = '1' and std_v = '1' then
        vstdata := r.x.data(0);
      end if;
    elsif (r.w.we(0) = "01" or r.w.we(0) = "11") and r.e.rs3 = r.w.rd(0) then
      vstdata(63 downto 32) := r.w.wb_data(0)(63 downto 32);
      exstdata_fwd          := '1';
      if r.w.we(0) = "11" and std_v = '1' then
        vstdata := r.w.wb_data(0);
      end if;
    elsif (r.w.we(1) = "01" and r.e.rs3 = r.w.rd(1)) then
      vstdata(63 downto 32) := r.w.wb_data(1)(63 downto 32);
      exstdata_fwd          := '1';
    end if;

    --forwarding for (31 downto 0)
    if m_lane0_valid = '1' and r.e.rs3 = r.m.ctrl.rd(0) and r.m.ctrl.delay_annuled(0) = '0' and std_v = '0' then
      vstdata(31 downto 0) := r.m.result(0);
      exstdata_fwd         := '1';
    elsif m_lane1_valid = '1' and r.e.rs3 = r.m.ctrl.rd(1) and std_v = '0' then
      vstdata(31 downto 0) := r.m.result(1);
      exstdata_fwd         := '1';
    elsif m_lane0_valid = '1' and r.e.rs3(RFBITS downto 1) = r.m.ctrl.rd(0)(RFBITS downto 1) and r.m.ctrl.rd(0)(0) = '1' and std_v = '1' then
      -- add %l0,10,%l1
      -- std %l0, address
      vstdata(31 downto 0) := r.m.result(0);
      exstdata_fwd         := '1';
    elsif m_lane1_valid = '1' and r.e.rs3(RFBITS downto 1) = r.m.ctrl.rd(1)(RFBITS downto 1) and r.m.ctrl.rd(1)(0) = '1' and std_v = '1' then
      vstdata(31 downto 0) := r.m.result(1);
      exstdata_fwd         := '1';
    elsif x_lane0_valid = '1' and r.e.rs3 = r.x.ctrl.rd(0) and is_load_int(r.x.ctrl.inst(0)) = '0' and std_v = '0' then
      vstdata(31 downto 0) := r.x.result(0);
      exstdata_fwd         := '1';
    elsif x_lane0_valid = '1' and r.e.rs3(RFBITS downto 1) = r.x.ctrl.rd(0)(RFBITS downto 1) and r.x.ctrl.rd(0)(0) = '1' and is_load_int(r.x.ctrl.inst(0)) = '0' and std_v = '1' then
      vstdata(31 downto 0) := r.x.result(0);
      exstdata_fwd         := '1';
    elsif x_lane1_valid = '1' and r.e.rs3 = r.x.ctrl.rd(1) and std_v = '0' then
      vstdata(31 downto 0) := r.x.result(1);
      exstdata_fwd         := '1';
    elsif x_lane1_valid = '1' and r.e.rs3(RFBITS downto 1) = r.x.ctrl.rd(1)(RFBITS downto 1) and r.x.ctrl.rd(1)(0) = '1' and std_v = '1' then
      vstdata(31 downto 0) := r.x.result(1);
      exstdata_fwd         := '1';
    elsif x_lane0_valid = '1' and is_load_int(r.x.ctrl.inst(0)) = '1' and ldd_v = '1' and std_v = '0' and r.e.rs3(RFBITS downto 1) = r.x.ctrl.rd(0)(RFBITS downto 1) then
      if r.e.rs3(0) = '1' then
        vstdata(31 downto 0) := r.x.data(0)(31 downto 0);
      else
        vstdata(31 downto 0) := r.x.data(0)(63 downto 32);
      end if;
      exstdata_fwd := '1';
    elsif x_lane0_valid = '1' and is_load_int(r.x.ctrl.inst(0)) = '1' and ldd_v = '1' and std_v = '1' and r.e.rs3(RFBITS downto 1) = r.x.ctrl.rd(0)(RFBITS downto 1) then
      vstdata(31 downto 0) := r.x.data(0)(31 downto 0);
      exstdata_fwd         := '1';
    elsif x_lane0_valid = '1' and std_v = '1' and ldd_v = '0' and is_load_int(r.x.ctrl.inst(0)) = '1' and (r.e.rs3(RFBITS downto 1) = r.x.ctrl.rd(0)(RFBITS downto 1)) and r.x.ctrl.rd(0)(0) = '1' then
      --the case for (63 downto 32) is set in the corresponding muxing
      vstdata(31 downto 0) := r.x.data(0)(31 downto 0);
      exstdata_fwd         := '1';
    elsif x_lane0_valid = '1' and std_v = '0' and ldd_v = '0' and is_load_int(r.x.ctrl.inst(0)) = '1' and r.e.rs3 = r.x.ctrl.rd(0) then
      vstdata(31 downto 0) := r.x.data(0)(31 downto 0);
      exstdata_fwd         := '1';
    elsif (r.w.we(0) = "01" or r.w.we(0) = "10") and std_v = '0' and r.e.rs3 = r.w.rd(0) then
      vstdata(31 downto 0) := r.w.wb_data(0)(31 downto 0);
      exstdata_fwd         := '1';
    elsif r.w.we(0) = "11" and std_v = '0' and r.e.rs3(RFBITS downto 1) = r.w.rd(0)(RFBITS downto 1) then
      exstdata_fwd := '1';
      if r.e.rs3(0) = '1' then
        vstdata(31 downto 0) := r.w.wb_data(0)(31 downto 0);
      else
        vstdata(31 downto 0) := r.w.wb_data(0)(63 downto 32);
      end if;
    elsif r.w.we(0) = "11" and std_v = '1' and r.e.rs3(RFBITS downto 1) = r.w.rd(0)(RFBITS downto 1) then
      exstdata_fwd         := '1';
      vstdata(31 downto 0) := r.w.wb_data(0)(31 downto 0);
    elsif r.w.we(0) = "10" and std_v = '1' and r.e.rs3(RFBITS downto 1) = r.w.rd(0)(RFBITS downto 1) then
      vstdata(31 downto 0) := r.w.wb_data(0)(31 downto 0);
      exstdata_fwd         := '1';
    elsif (r.w.we(1) = "01" or r.w.we(1) = "10") and std_v = '0' and r.e.rs3 = r.w.rd(1) then
      vstdata(31 downto 0) := r.w.wb_data(1)(31 downto 0);
      exstdata_fwd         := '1';
    elsif r.w.we(1) = "10" and std_v = '1' and r.e.rs3(RFBITS downto 1) = r.w.rd(1)(RFBITS downto 1) then
      vstdata(31 downto 0) := r.w.wb_data(1)(31 downto 0);
      exstdata_fwd         := '1';
    end if;


    if r.e.ctrl.inst(0)(29 downto 25) = "00000" then     -- %g0, force zero
      vstdata(63 downto 32) := (others => '0');
    end if;
    -- Replicate word/halfword/byte
    if r.e.ctrl.rd(0)(0) = '1' then     --no STD, (63 downto 32) forwarding is
                                        --correct
      -- vstdata(31 downto 0) := vstdata(63 downto 32);
      vstdata(63 downto 32) := vstdata(31 downto 0);
    elsif r.e.ctrl.inst(0)(22 downto 19) /= "0111" then  -- not STD
      vstdata(31 downto 0) := vstdata(63 downto 32);
    end if;

    if r.e.ctrl.inst(0)(20 downto 19) = "10" then     -- STH
      for i in 1 to 3 loop
        vstdata((i+1)*16-1 downto i*16) := vstdata(15 downto 0);
      end loop;
    elsif r.e.ctrl.inst(0)(20 downto 19) = "01" then  -- STB
      for i in 1 to 7 loop
        vstdata((i+1)*8-1 downto i*8) := vstdata(7 downto 0);
      end loop;
    end if;

    -- Could potentially mux fpc output here too...
    stdata := vstdata;


    ---------------------------------------------------------------------------
    --Forwarding select for mem stage (reduces critical path)
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    --If there is a regular register forwarding that would overwrite the operation
    --forwarding mux in memory stage should be masked
    mem_lane_ow     := "00";
    mem_lane_ow_std := "00";
    xc_lane_ow      := "00";
    xc_lane_ow_std  := "00";
    for i in 0 to 1 loop
      --we don't check alu_dexc for memory stage since in that case store instruction will stall
      if r.m.ctrl.inst_valid(i) = '1' and is_load_int(r.m.ctrl.inst(i)) = '0' and is_divmul(r.m.ctrl.inst(i)) = '0' and r.m.ctrl.no_forward(i) = '0' and r.m.ctrl.delay_annuled(i) = '0' and r.m.ctrl.rdw(i) = '1' then
        if r.m.ctrl.rd(i) = r.e.rs3 then
          mem_lane_ow(i) := '1';
        end if;
        if r.m.ctrl.rd(i)(RFBITS-1 downto 1) = r.e.rs3(RFBITS-1 downto 1) then
          mem_lane_ow_std(i) := '1';
        end if;
      end if;

      if r.x.ctrl.inst_valid(i) = '1' and is_load_int(r.x.ctrl.inst(i)) = '0' and is_divmul(r.x.ctrl.inst(i)) = '0' and r.x.ctrl.no_forward(i) = '0' and r.x.ctrl.delay_annuled(i) = '0' and r.x.ctrl.alu_dexc(i) = '0' and r.x.ctrl.rdw(i) = '1' then
        if r.x.ctrl.rd(i) = r.e.rs3 then
          xc_lane_ow(i) := '1';
        end if;
        if r.x.ctrl.rd(i)(RFBITS-1 downto 1) = r.e.rs3(RFBITS-1 downto 1) then
          xc_lane_ow_std(i) := '1';
        end if;
      end if;
    end loop;
    ---------------------------------------------------------------------------


    --there can not be a load and muldiv writing to same register in the same
    --pair hence mem_data_xdata / mem_data_xresult do not require any strict ordering 
    mem_data_alu1     := "00";
    mem_data_xdataH   := "00";
    mem_data_xdataL   := "00";
    mem_data_xresult0 := "00";

    --since one instruction in the pair is store there can not be a no_forward
    if r.e.ctrl.swap = '1' and r.e.ctrl.rdw(1) = '1' and r.e.ctrl.inst_valid(1) = '1' and r.e.ctrl.delay_annuled(1) = '0' and r.e.rs3 = r.e.ctrl.rd(1) then
      mem_data_alu1(1) := '1';
      if std_v = '0' then
        mem_data_alu1(0) := '1';
      end if;
    end if;

    if r.e.ctrl.swap = '1' and r.e.ctrl.rdw(1) = '1' and r.e.ctrl.inst_valid(1) = '1' and std_v = '1'
      and r.e.ctrl.delay_annuled(1) = '0' and r.e.rs3(RFBITS downto 1) = r.e.ctrl.rd(1)(RFBITS downto 1)
      and r.e.ctrl.rd(1)(0) = '1' then
      mem_data_alu1(0) := '1';
    end if;

    if r.m.ctrl.rdw(0) = '1' and r.m.ctrl.inst_valid(0) = '1' and r.m.ctrl.delay_annuled(0) = '0' and r.m.ctrl.no_forward(0) = '0' and is_load_int(r.m.ctrl.inst(0)) = '1' then
      if (std_v = ldd_vm) then
        if r.e.rs3 = r.m.ctrl.rd(0) then
          mem_data_xdataH := "10";
          mem_data_xdataL := "01";
          if r.m.ctrl.ldd_z = '1' and ldd_vm = '1' then
            mem_data_xdataH := "00";
          end if;
        end if;
      end if;
      if std_v = '0' and ldd_vm = '1' then
        if r.e.rs3 = r.m.ctrl.rd(0) then
          mem_data_xdataH := "11";
          mem_data_xdataL := "00";
          if r.m.ctrl.ldd_z = '1' then
            mem_data_xdataH := "00";
          end if;
        end if;
        if r.e.rs3(0) = '1' and r.e.rs3(RFBITS downto 1) = r.m.ctrl.rd(0)(RFBITS downto 1) then
          mem_data_xdataH := "00";
          mem_data_xdataL := "11";
        end if;
      end if;

      if std_v = '1' and ldd_vm = '0' then
        if r.e.rs3 = r.m.ctrl.rd(0) then
          mem_data_xdataH := "10";
        end if;
        if r.m.ctrl.rd(0)(0) = '1' and r.e.rs3(RFBITS downto 1) = r.m.ctrl.rd(0)(RFBITS downto 1) then
          mem_data_xdataH := "01";
        end if;
      end if;

      if r.m.ctrl.swap = '0' and mem_lane_ow(1) = '1' and std_v = '0' then
        mem_data_xdataH := "00";
        mem_data_xdataL := "00";
      end if;
      if r.m.ctrl.swap = '0' and mem_lane_ow_std(1) = '1' and std_v = '1' then
        if r.m.ctrl.rd(1)(0) = '0' then
          mem_data_xdataH(1) := '0';
          mem_data_xdataL(1) := '0';
        else
          mem_data_xdataH(0) := '0';
          mem_data_xdataL(0) := '0';
        end if;
      end if;
      
    end if;

    for i in 0 to 1 loop
      --there can be only one mul or div instruction in one stage
      if is_divmul(r.m.ctrl.inst(i)) = '1' and r.m.ctrl.inst_valid(i) = '1' and r.m.ctrl.delay_annuled(i) = '0' and r.m.ctrl.no_forward(i) = '0' and r.m.ctrl.rdw(i) = '1' then
        if std_v = '0' then
          if r.e.rs3 = r.m.ctrl.rd(i) then
            mem_data_xresult0 := "11";
          end if;
        else
          --std_v = 1 
          if r.e.rs3 = r.m.ctrl.rd(i) then
            mem_data_xresult0 := "10";
          elsif r.m.ctrl.rd(i)(0) = '1' and r.e.rs3(RFBITS downto 1) = r.m.ctrl.rd(i)(RFBITS downto 1) then
            mem_data_xresult0 := "01";
          end if;
        end if;

        if (i = 0 and r.m.ctrl.swap = '0' and mem_lane_ow(1) = '1') or
          (i = 1 and r.m.ctrl.swap = '1' and mem_lane_ow(0) = '1') then
          if std_v = '0' then
            mem_data_xresult0 := "00";
          end if;
        end if;

        if (i = 0 and r.m.ctrl.swap = '0' and mem_lane_ow_std(1) = '1') or
          (i = 1 and r.m.ctrl.swap = '1' and mem_lane_ow_std(0) = '1') then
          if std_v = '1' then
            if i = 0 then
              if r.m.ctrl.rd(1)(0) = '0' then
                mem_data_xresult0(1) := '0';
              else
                mem_data_xresult0(0) := '0';
              end if;
            else
              if r.m.ctrl.rd(0)(0) = '0' then
                mem_data_xresult0(1) := '0';
              else
                mem_data_xresult0(0) := '0';
              end if;
            end if;
          end if;
        end if;
        
      end if;
    end loop;


    mem_data_lalu0 := "00";
    mem_data_lalu1 := "00";
    if r.x.ctrl.inst_valid(0) = '1' and r.x.ctrl.rdw(0) = '1' and r.x.ctrl.delay_annuled(0) = '0' and r.x.ctrl.no_forward(0) = '0' and r.x.ctrl.alu_dexc(0) = '1' then

      if r.e.rs3 = r.x.ctrl.rd(0) then
        mem_data_lalu0 := "11";
        if std_v = '1' then
          mem_data_lalu0(0) := '0';
        end if;
      end if;

      if std_v = '1' and (r.e.rs3(RFBITS downto 1) = r.x.ctrl.rd(0)(RFBITS downto 1)) and r.x.ctrl.rd(0)(0) = '1' then
        mem_data_lalu0(0) := '1';
      end if;
    end if;

    if r.x.ctrl.swap = '1' and xc_lane_ow(1) = '1' then
      if std_v = '0' then
        mem_data_lalu0 := "00";
      else
        if r.x.ctrl.rd(1)(0) = '0' then
          mem_data_lalu0(1) := '0';
        else
          mem_data_lalu0(0) := '0';
        end if;
      end if;
    end if;

    if r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.rdw(1) = '1' and r.x.ctrl.delay_annuled(1) = '0' and r.x.ctrl.no_forward(1) = '0' and r.x.ctrl.alu_dexc(1) = '1' then

      if r.e.rs3 = r.x.ctrl.rd(1) then
        mem_data_lalu1 := "11";
        if std_v = '1' then
          mem_data_lalu1(0) := '0';
        end if;
      end if;

      if std_v = '1' and (r.e.rs3(RFBITS downto 1) = r.x.ctrl.rd(1)(RFBITS downto 1)) and r.x.ctrl.rd(1)(0) = '1' then
        mem_data_lalu1(0) := '1';
      end if;
    end if;

    if mem_lane_ow /= "00" and std_v = '0' then
      mem_data_lalu0 := "00";
      mem_data_lalu1 := "00";
    end if;

    if mem_lane_ow_std /= "00" and std_v = '1' then
      for i in 0 to 1 loop
        if mem_lane_ow_std(i) = '1' then
          if r.m.ctrl.rd(i)(0) = '0' then
            mem_data_lalu0(1) := '0';
            mem_data_lalu1(1) := '0';
          else
            mem_data_lalu0(0) := '0';
            mem_data_lalu1(0) := '0';
          end if;
        end if;
      end loop;
    end if;

    if r.e.ctrl.inst(0)(29 downto 25) = "00000" then
      mem_data_alu1(1)     := '0';
      mem_data_xdataH(1)   := '0';
      mem_data_xdataL(1)   := '0';
      mem_data_xresult0(1) := '0';
      mem_data_lalu0(1)    := '0';
      mem_data_lalu1(1)    := '0';
    end if;
    
  end procedure;

  procedure dcache_gen(r     :     registers;
                       etrap :     std_logic;
                       valid :     std_logic;
                       dci   : out dc_in_type) is
    variable op       : std_logic_vector(1 downto 0);
    variable op3      : std_logic_vector(5 downto 0);
    variable su, rfe3 : std_logic;

    
  begin
    op         := r.e.ctrl.inst(0)(31 downto 30);
    op3        := r.e.ctrl.inst(0)(24 downto 19);
    dci.signed := '0';
    dci.lock   := '0';
    dci.dsuen  := '0';
    dci.size   := SZWORD;
    if op = LDST then
      case op3 is
        when LDUB | LDUBA =>
          dci.size := SZBYTE;
        when LDSTUB | LDSTUBA =>
          dci.size := SZBYTE;
          if r.a.astate /= idle and r.a.astate /= count and r.a.astate /= ld_exc then
            dci.lock := '1';
          end if;
        when LDUH | LDUHA =>
          dci.size := SZHALF;
        when LDSB | LDSBA =>
          dci.size   := SZBYTE;
          dci.signed := '1';
        when LDSH | LDSHA =>
          dci.size   := SZHALF;
          dci.signed := '1';
        when LD | LDA | LDF | LDC =>
          dci.size := SZWORD;
        when SWAP | SWAPA | CASA =>
          dci.size := SZWORD;
          if r.a.astate /= idle and r.a.astate /= count and r.a.astate /= ld_exc then
            dci.lock := '1';
          end if;
        when LDD | LDDA | LDDF | LDDC =>
          dci.size := SZDBL;
        when STB | STBA =>
          dci.size := SZBYTE;
        when STH | STHA =>
          dci.size := SZHALF;
        when ST | STA | STF =>
          dci.size := SZWORD;
        when ISTD | STDA =>
          dci.size := SZDBL;
        when STDF | STDFQ =>
          if FPEN then
            dci.size := SZDBL;
          end if;
        when STDC | STDCQ =>
          if CPEN then
            dci.size := SZDBL;
          end if;
        when others =>
          dci.size   := SZWORD;
          dci.lock   := '0';
          dci.signed := '0';
      end case;
    end if;

    rfe3       := '0';
    dci.enaddr := '0';
    dci.read   := '0';
    dci.write  := '0';

-- load/store control decoding
    if ((valid = '1' or (r.a.astate /= idle and r.a.astate /= count and r.a.astate /= ld_exc)) and op = LDST) then
      dci.enaddr := '1';
      dci.read   := not op3(2);
      dci.write  := op3(2);
      if r.a.astate = ld_mem or r.a.astate = ld_exc then
        dci.write := '1';
      end if;
      if op3(3 downto 2) = "11" then    -- LDST/SWAP/CASA
        if (r.a.astate = ld_exe) then
          dci.write := '0';
          dci.read  := '1';
        end if;
      end if;
      rfe3 := op3(2);
      if r.e.ctrl.trap(0) = '1' and r.a.astate = idle then
        dci.enaddr := '0';
      end if;
      if r.e.ctrl.trap(1) = '1' and r.e.ctrl.swap = '1' and r.e.ctrl.inst_valid(1) = '1' and r.e.ctrl.delay_annuled(1) = '0' then
        dci.enaddr := '0';
      end if;
    end if;

    if (r.x.ctrl.rett_op = '1' and r.x.ctrl.inst_valid(1) = '1') or
      (r.m.ctrl.rett_op = '1' and r.m.ctrl.inst_valid(1) = '1') then
      su := r.w.s.ps;
    else
      su := r.w.s.s;
    end if;
    if su = '1' then
      dci.asi := "00001011";
    else
      dci.asi := "00001010";
    end if;
    --certain ASIs are not enabled in LEON4
    --try to understand the reason
    if (op3(4) = '1') and ((op3(5) = '0') or not CPEN) then
      dci.asi := r.e.ctrl.inst(0)(12 downto 5);
      if r.e.ctrl.inst(0)(12 downto 11) /= "00" then
        dci.enaddr := '0';
      end if;
      --for CASA 0xA operations translate 0xA to 0xB
      --if in supervisor mode for backwards compability
      if r.e.casa_asiA = '1' then
        if su = '1' then
          dci.asi := x"0B";
        end if;
      end if;
    end if;

  end;

  procedure gen_stdata(r : in registers; iustdata, fpstdata : in word64; stdataout : out word64) is
    
    variable op3    : std_logic_vector(5 downto 0);
    variable stdata : word64;
  begin

    stdata := iustdata;
    op3    := r.m.ctrl.inst(0)(24 downto 19);

    if r.m.mem_data_alu1(0) = '1' then
      stdata(31 downto 0) := r.m.result(1);
    elsif r.m.mem_data_xdataH(0) = '1' then
      stdata(31 downto 0) := r.x.data(0)(63 downto 32);
    elsif r.m.mem_data_xdataL(0) = '1' then
      stdata(31 downto 0) := r.x.data(0)(31 downto 0);
    elsif r.m.mem_data_xresult0(0) = '1' then
      stdata(31 downto 0) := r.x.muldiv_result;
    elsif r.m.mem_data_lalu0(0) = '1' then
      stdata(31 downto 0) := r.w.wb_data(0)(63 downto 32);
    elsif r.m.mem_data_lalu1(0) = '1' then
      stdata(31 downto 0) := r.w.wb_data(1)(63 downto 32);
    end if;

    if r.m.mem_data_alu1(1) = '1' then
      stdata(63 downto 32) := r.m.result(1);
    elsif r.m.mem_data_xdataH(1) = '1' then
      stdata(63 downto 32) := r.x.data(0)(63 downto 32);
    elsif r.m.mem_data_xdataL(1) = '1' then
      stdata(63 downto 32) := r.x.data(0)(31 downto 0);
    elsif r.m.mem_data_xresult0(1) = '1' then
      stdata(63 downto 32) := r.x.muldiv_result;
    elsif r.m.mem_data_lalu0(1) = '1' then
      stdata(63 downto 32) := r.w.wb_data(0)(63 downto 32);
    elsif r.m.mem_data_lalu1(1) = '1' then
      stdata(63 downto 32) := r.w.wb_data(1)(63 downto 32);
    end if;

    if r.m.ctrl.inst(0)(20 downto 19) = "10" then     -- STH
      for i in 1 to 3 loop
        stdata((i+1)*16-1 downto i*16) := stdata(15 downto 0);
      end loop;
    elsif r.m.ctrl.inst(0)(20 downto 19) = "01" then  -- STB
      for i in 1 to 7 loop
        stdata((i+1)*8-1 downto i*8) := stdata(7 downto 0);
      end loop;
    end if;

    if FPEN and is_fpu_store(r.m.ctrl.inst(0)) = '1' then
      stdata := iustdata;
    end if;

    if holdn = '0' or r.a.astate = ld_exc then
      stdata := r.x.storedata;
    end if;
    if op3(3 downto 0) = "1101" then    -- LDSTUB
      stdata := (others => '1');
    end if;
    if DBGUNIT and (r.m.dci.dsuen = '1') then
      stdata := dbgi.mosi.wrdata & dbgi.mosi.wrdata;
    end if;

    stdataout := stdata;
  end;

  function ld_align64(data : word64; size : std_logic_vector(1 downto 0);
  laddr                    : std_logic_vector(2 downto 0); signed : std_logic; rd : std_logic_vector(RFBITS-1 downto 0); cpld, dsuen : std_logic)
    return word64 is
    variable align_data, rdata : word;
    variable rdata64           : word64;
  begin
    rdata64 := data;
    if laddr(2) = '0' then
      align_data := rdata64(63 downto 32);
    else
      align_data := rdata64(31 downto 0);
    end if;
    rdata := (others => '0');
    case size is
      when "00" =>                      -- byte read
        case laddr(1 downto 0) is
          when "00" =>
            rdata(7 downto 0)                       := align_data(31 downto 24);
            if signed = '1' then rdata(31 downto 8) := (others => align_data(31)); end if;
          when "01" =>
            rdata(7 downto 0)                       := align_data(23 downto 16);
            if signed = '1' then rdata(31 downto 8) := (others => align_data(23)); end if;
          when "10" =>
            rdata(7 downto 0)                       := align_data(15 downto 8);
            if signed = '1' then rdata(31 downto 8) := (others => align_data(15)); end if;
          when others =>
            rdata(7 downto 0)                       := align_data(7 downto 0);
            if signed = '1' then rdata(31 downto 8) := (others => align_data(7)); end if;
        end case;
        rdata64 := rdata & rdata;
      when "01" =>                      -- half-word read
        if laddr(1) = '1' then
          rdata(15 downto 0)                       := align_data(15 downto 0);
          if signed = '1' then rdata(31 downto 15) := (others => align_data(15)); end if;
        else
          rdata(15 downto 0)                       := align_data(31 downto 16);
          if signed = '1' then rdata(31 downto 15) := (others => align_data(31)); end if;
        end if;
        rdata64 := rdata & rdata;
      when "10" =>                      -- single word read
        rdata(31 downto 0) := align_data;
        rdata64            := rdata & rdata;
      when others =>                    -- double word read
    end case;
    return(rdata64);
  end;

  function ld_align_slow(data : dcdtype; way : std_logic_vector(DWAYMSB downto 0); size : std_logic_vector(1 downto 0);
  laddr                       : std_logic_vector(2 downto 0); signed : std_logic; rd : std_logic_vector(RFBITS-1 downto 0); cpld, dsuen : std_logic)
    return word64 is
    variable rdata : word64;
  begin
    rdata := data(conv_integer(way));
    return(ld_align64(rdata, size, laddr, signed, rd, cpld, dsuen));
  end;

  function ld_align_fast(data : dcdtype; way : std_logic_vector(DWAYMSB downto 0); size : std_logic_vector(1 downto 0);
  laddr                       : std_logic_vector(2 downto 0); signed : std_logic; rd : std_logic_vector(RFBITS-1 downto 0); cpld, dsuen : std_logic)
    return word64 is
    variable rdata : dcdtype;
  begin
    for i in 0 to dways-1 loop
      rdata(i) := ld_align64(data(i), size, laddr, signed, rd, cpld, dsuen);
    end loop;
    return(rdata(conv_integer(way)));
  end;

  procedure mem_trap(r     :     registers; wpr : watchpoint_registers;
  annul, holdn             : in  std_logic;
  trapout                  : out std_logic_vector(1 downto 0);
  iflush, nullify, werrout : out std_logic;
  tt                       : out tt_array_type) is
    variable cwpx    : std_logic_vector(5 downto NWINLOG2);
    variable op_0    : std_logic_vector(1 downto 0);
    variable op2_0   : std_logic_vector(2 downto 0);
    variable op3_0   : std_logic_vector(5 downto 0);
    variable op_1    : std_logic_vector(1 downto 0);
    variable op2_1   : std_logic_vector(2 downto 0);
    variable op3_1   : std_logic_vector(5 downto 0);
    variable werr    : std_logic;
    variable trap    : std_logic_vector(1 downto 0);
    variable wprmask : std_logic_vector(31 downto 2);
    variable tt_a    : tt_array_type;
  begin
    op_0    := r.m.ctrl.inst(0)(31 downto 30);
    op2_0   := r.m.ctrl.inst(0)(24 downto 22);
    op3_0   := r.m.ctrl.inst(0)(24 downto 19);
    op_1    := r.m.ctrl.inst(1)(31 downto 30);
    op2_1   := r.m.ctrl.inst(1)(24 downto 22);
    op3_1   := r.m.ctrl.inst(1)(24 downto 19);
    cwpx    := r.m.result(1)(5 downto NWINLOG2);
    cwpx(5) := '0';
    iflush  := '0';
    trap    := "00";
    nullify := annul;

    trap    := r.m.ctrl.trap;
    tt_a    := r.m.ctrl.tt;
    werr    := (dco.werr or r.m.werr) and not r.w.s.dwt;
    wprmask := (others => '0');

    
    --lane 0 trap checks
    if annul = '0' and (r.m.ctrl.trap(0) = '0' or r.m.ctrl.tt(0) = TT_FPEXC) and r.m.ctrl.inst_valid(0) = '1' then
      case op_0 is
        when LDST =>
          case op3_0 is
            when LDDF | STDF | STDFQ =>
              if FPEN then
                if r.m.result(0)(2 downto 0) /= "000" then
                  trap(0) := '1';
                  tt_a(0) := TT_UNALA;
                  nullify := '1';
                end if;
              end if;
            when LDDC | STDC | STDCQ =>
              if CPEN then
                if r.m.result(0)(2 downto 0) /= "000" then
                  trap(0) := '1';
                  tt_a(0) := TT_UNALA;
                  nullify := '1';
                end if;
              end if;
            when LDD | ISTD | LDDA | STDA =>
              if r.m.result(0)(2 downto 0) /= "000" then
                trap(0) := '1';
                tt_a(0) := TT_UNALA;
                nullify := '1';
              end if;
            when LDF | LDFSR | STFSR | STF =>
              if FPEN and (r.m.result(0)(1 downto 0) /= "00") then
                trap(0) := '1';
                tt_a(0) := TT_UNALA;
                nullify := '1';
              end if;
            when LDC | LDCSR | STCSR | STC =>
              if CPEN and (r.m.result(0)(1 downto 0) /= "00") then
                trap(0) := '1';
                tt_a(0) := TT_UNALA;
                nullify := '1';
              end if;
            when LD | LDA | ST | STA | SWAP | SWAPA | CASA =>
              if r.m.result(0)(1 downto 0) /= "00" then
                trap(0) := '1';
                tt_a(0) := TT_UNALA;
                nullify := '1';
              end if;
            when LDUH | LDUHA | LDSH | LDSHA | STH | STHA =>
              if r.m.result(0)(0) /= '0' then
                trap(0) := '1';
                tt_a(0) := TT_UNALA;
                nullify := '1';
              end if;
            when others => null;
          end case;
          for i in 1 to NWP loop
            wprmask    := wpr(i-1).mask;  -- Clear LSb for LDD/STD:
            wprmask(2) := wprmask(2) and not andv(op3_0(1 downto 0));
            if ((((wpr(i-1).load and not op3_0(2)) or (wpr(i-1).store and op3_0(2))) = '1') and
                (((wpr(i-1).addr xor r.m.result(0)(31 downto 2)) and wprmask) = zero32(31 downto 2)))
            then
              trap(0) := '1';
              tt_a(0) := TT_WATCH;
              nullify := '1';
            end if;
          end loop;
        when others => null;
      end case;

      if is_ticc(r.m.ctrl.inst(0)) = '1' then
        if branch_true(r.m.icc, r.m.ctrl.inst(0)) = '1' then
          trap(0) := '1';
          tt_a(0) := TT_TICC;
        end if;
      end if;
      
    end if;

    --lane 1 trap checks
    if annul = '0' and r.m.ctrl.trap(1) = '0' and r.m.ctrl.inst_valid(1) = '1' then
      case op_1 is
        when FMT3 =>
          case op3_1 is
            --WRPSR/DIV/TagCC/JMPL/RETT is always executed on lane 1
            when WRPSR =>
              if (orv(cwpx) = '1') and (pwrpsr = 0 or r.m.ctrl.inst(1)(29 downto 25) = "00000") then
                trap(1) := '1';
                tt_a(1) := TT_IINST;
              end if;
            when UDIV | SDIV | UDIVCC | SDIVCC =>
              if DIVEN then
                if r.m.divz = '1' then
                  trap(1) := '1';
                  tt_a(1) := TT_DIV;
                end if;
              end if;
            when JMPL | RETT =>
              if r.m.nalign = '1' then
                trap(1) := '1';
                tt_a(1) := TT_UNALA;
              end if;
            when TADDCCTV | TSUBCCTV =>
              if (notag = 0) and (r.m.icc(1) = '1') then
                trap(1) := '1';
                tt_a(1) := TT_TAG;
              end if;
            when others => null;
          end case;
        when others => null;
      end case;
    end if;

    if annul = '0' and r.m.ctrl.inst_valid(0) = '1' and is_flush(r.m.ctrl.inst(0)) = '1' and r.m.ctrl.trap(0) = '0' then
      iflush := '1';
    end if;

    if (rstn = '0') or (r.x.rstate = dsu2) then
      werr := '0';
    end if;

    trapout := trap;
    tt      := tt_a;
    werrout := werr;
  end;

  procedure irq_trap(v        : in  registers;
                     r        : in  registers;
                     ir       : in  irestart_register;
                     irl      : in  std_logic_vector(3 downto 0);
                     annul    : in  std_logic;
                     trap     : in  std_logic_vector(1 downto 0);
                     tt       : in  tt_array_type;
                     nullify  : in  std_logic;
                     irqen    : out std_logic;
                     irqen2   : out std_logic;
                     nullify2 : out std_logic;
                     trap2    : out std_logic_vector(1 downto 0);
                     ipend    : out std_logic;
                     tt2      : out tt_array_type) is
    variable op          : std_logic_vector(1 downto 0);
    variable op3         : std_logic_vector(5 downto 0);
    variable pend        : std_logic;
    variable irq_allowed : std_logic;
    variable irq_lane    : std_logic;
  begin
    nullify2 := nullify;
    trap2    := trap;
    tt2      := tt;
    op       := r.m.ctrl.inst(1)(31 downto 30);
    op3      := r.m.ctrl.inst(1)(24 downto 19);
    irqen    := '1';
    irqen2   := r.m.irqen;

    irq_allowed := '1';
    irq_lane    := '0';

    if ((op = FMT3) and (op3 = WRPSR) and r.m.ctrl.inst_valid(1) = '1' and annul = '0') then
      irqen := '0';
    end if;

    pend := '0';
    if (irl = "1111") or (irl > r.w.s.pil) then
      pend := r.m.irqen and r.m.irqen2 and r.w.s.et;
    end if;
    ipend := pend;


    if annul = '1' then
      irq_allowed := '0';
    end if;
    if r.m.ctrl.inst_valid = "00" then
      irq_allowed := '0';
    end if;
    --if you fix atomic active in npc_find this can works also
    --think if it makes sense to take interrupt in the middle of
    --atomic operation
    if r.m.ctrl.inst_valid(0) = '1' and is_atomic(r.m.ctrl.inst(0)) = '1' then
      irq_allowed := '0';
    end if;
    if trap /= "00" then
      irq_allowed := '0';
    end if;
    if r.m.ctrl.unpcti /= "00" then
      irq_allowed := '0';
    end if;

    if r.m.ctrl.inst_valid = "10" and is_div(r.m.ctrl.inst(1)) = '1' then
      --don't take interrupt on finished division operation
      irq_allowed := '0';
    end if;


    --here we use v.x.ctrl.inst_valid to cover the case
    --in which a delay instruction of a branch which is resolved
    --in expcetion stage exists here
    if v.x.ctrl.inst_valid = "10" then
      irq_lane := '1';
    end if;
    if v.x.ctrl.inst_valid = "11" then
      if r.m.ctrl.swap = '0' then
        --new instruction should get the IRQ
        irq_lane := '1';
      end if;
      if r.m.ctrl.branch /= "00" then
        --dont trap on delay instrucion if there is an unresolved branch
        if r.m.ctrl.swap = '1' and (is_branch(r.m.ctrl.inst(1)) = '1' or (FPEN and is_fpu_branch(r.m.ctrl.inst(1)) = '1')) then
          irq_lane := '1';
        end if;

        if r.m.ctrl.swap = '0' and (is_branch(r.m.ctrl.inst(0)) = '1' or (FPEN and is_fpu_branch(r.m.ctrl.inst(1)) = '1')) then
          irq_lane := '0';
        end if;
      end if;
    end if;

    if irq_allowed = '1' and pend = '1' then
      if irq_lane = '0' then
        trap2(0) := '1';
        tt2(0)   := "01" & irl;
      else
        trap2(1) := '1';
        tt2(1)   := "01" & irl;
      end if;

      if (irq_lane = '0' and is_ldst(r.m.ctrl.inst(0)) = '1') then
        nullify2 := '1';
      end if;

      if (irq_lane = '1' and is_ldst(r.m.ctrl.inst(0)) = '1' and r.m.ctrl.swap = '1') then
        nullify2 := '1';
      end if;
      
    end if;
  end;

  procedure irq_intack(r : in registers; holdn : in std_logic; intack : out std_logic) is
  begin
    intack := '0';
    if r.x.rstate = trap then
      if r.w.s.tt(7 downto 4) = "0001" then
        intack := '1';
      end if;
    end if;
  end;

  procedure sp_write_l1 (r : registers; sin : in special_register_type; sout : out special_register_type) is
    variable op  : std_logic_vector(1 downto 0);
    variable op2 : std_logic_vector(2 downto 0);
    variable op3 : std_logic_vector(5 downto 0);
    variable rd  : std_logic_vector(4 downto 0);
  begin
    
    sout := sin;

    op  := r.x.ctrl.inst(1)(31 downto 30);
    op2 := r.x.ctrl.inst(1)(24 downto 22);
    op3 := r.x.ctrl.inst(1)(24 downto 19);
    rd  := r.x.ctrl.inst(1)(29 downto 25);

    if op = FMT3 then
      if op3 = SAVE then
        if (not CWPOPT) and (r.w.s.cwp = CWPMIN) then
          sout.cwp := CWPMAX;
        else
          sout.cwp := r.w.s.cwp - 1;
        end if;
      end if;
      if op3 = RESTORE then
        if (not CWPOPT) and (r.w.s.cwp = CWPMAX) then
          sout.cwp := CWPMIN;
        else
          sout.cwp := r.w.s.cwp + 1;
        end if;
      end if;
      if op3 = RETT then
        if (not CWPOPT) and (r.w.s.cwp = CWPMAX) then
          sout.cwp := CWPMIN;
        else
          sout.cwp := r.w.s.cwp + 1;
        end if;
        sout.s  := r.w.s.ps;
        sout.et := '1';
      end if;
      if op3 = WRPSR then
        if pwrpsr = 0 or rd = "00000" then
          sout.cwp := r.x.result(1)(NWINLOG2-1 downto 0);
          sout.icc := r.x.result(1)(23 downto 20);
          sout.ec  := r.x.result(1)(13);
          if FPEN then
            sout.ef := r.x.result(1)(12);
          end if;
          sout.pil := r.x.result(1)(11 downto 8);
          sout.s   := r.x.result(1)(7);
          sout.ps  := r.x.result(1)(6);
        end if;
        sout.et := r.x.result(1)(5);
      end if;
      
    end if;

    --LATER on fix annull
    if r.x.ctrl.wicc = '1' and r.x.ctrl.inst_valid(1) = '1' then
      sout.icc := r.x.icc;
    end if;
    if r.x.ctrl.wy(1) = '1' and r.x.ctrl.inst_valid(1) = '1' then
      sout.y := r.x.y;
    end if;
  end;

-- write special registers

  procedure sp_write (r :     registers; wpr : watchpoint_registers;
  s                     : out special_register_type; vwpr : out watchpoint_registers) is
    variable op  : std_logic_vector(1 downto 0);
    variable op2 : std_logic_vector(2 downto 0);
    variable op3 : std_logic_vector(5 downto 0);
    variable rd  : std_logic_vector(4 downto 0);
    variable i   : integer range 0 to 3;
  begin

    op   := r.x.ctrl.inst(0)(31 downto 30);
    op2  := r.x.ctrl.inst(0)(24 downto 22);
    op3  := r.x.ctrl.inst(0)(24 downto 19);
    s    := r.w.s;
    rd   := r.x.ctrl.inst(0)(29 downto 25);
    vwpr := wpr;


    --this is here to make sure WRY writes the 'Y' correctly
    if r.x.ctrl.wy(0) = '1' then
      s.y := r.x.y;
    end if;

    case op is
      when FMT3 =>
        case op3 is
          when WRY =>
            if rd = "00000" then
              s.y := r.x.result(0);
            elsif MACEN and (rd = "10010") then  -- %asr18
              s.asr18 := r.x.result(0);
            elsif (rd = "10001") then            -- %asr17
              s.dbp                   := r.x.result(0)(27);
              s.dbprepl               := r.x.result(0)(25);
              s.dwt                   := r.x.result(0)(14);
              if (svt = 1) then s.svt := r.x.result(0)(13); end if;
            elsif rd = "10110" then              -- ASR22
              s.ducnt := r.x.result(0)(31);
            elsif rd(4 downto 3) = "11" then     -- %ASR24 - %ASR31
              case rd(2 downto 0) is
                when "000" =>
                  vwpr(0).addr := r.x.result(0)(31 downto 2);
                  vwpr(0).exec := r.x.result(0)(0);
                when "001" =>
                  vwpr(0).mask  := r.x.result(0)(31 downto 2);
                  vwpr(0).load  := r.x.result(0)(1);
                  vwpr(0).store := r.x.result(0)(0);
                when "010" =>
                  vwpr(1).addr := r.x.result(0)(31 downto 2);
                  vwpr(1).exec := r.x.result(0)(0);
                when "011" =>
                  vwpr(1).mask  := r.x.result(0)(31 downto 2);
                  vwpr(1).load  := r.x.result(0)(1);
                  vwpr(1).store := r.x.result(0)(0);
                when "100" =>
                  vwpr(2).addr := r.x.result(0)(31 downto 2);
                  vwpr(2).exec := r.x.result(0)(0);
                when "101" =>
                  vwpr(2).mask  := r.x.result(0)(31 downto 2);
                  vwpr(2).load  := r.x.result(0)(1);
                  vwpr(2).store := r.x.result(0)(0);
                when "110" =>
                  vwpr(3).addr := r.x.result(0)(31 downto 2);
                  vwpr(3).exec := r.x.result(0)(0);
                when others =>                   -- "111"
                  vwpr(3).mask  := r.x.result(0)(31 downto 2);
                  vwpr(3).load  := r.x.result(0)(1);
                  vwpr(3).store := r.x.result(0)(0);
              end case;
            end if;
          when WRPSR =>
            if pwrpsr = 0 or rd = "00000" then
              s.cwp := r.x.result(0)(NWINLOG2-1 downto 0);
              s.icc := r.x.result(0)(23 downto 20);
              s.ec  := r.x.result(0)(13);
              if FPEN then
                s.ef := r.x.result(0)(12);
              end if;
              s.pil := r.x.result(0)(11 downto 8);
              s.s   := r.x.result(0)(7);
              s.ps  := r.x.result(0)(6);
            end if;
            s.et := r.x.result(0)(5);
          when WRWIM =>
            s.wim := r.x.result(0)(NWIN-1 downto 0);
          when WRTBR =>
            s.tba := r.x.result(0)(31 downto 12);
          when SAVE =>
            if (not CWPOPT) and (r.w.s.cwp = CWPMIN) then
              s.cwp := CWPMAX;
            else
              s.cwp := r.w.s.cwp - 1;
            end if;
          when RESTORE =>
            if (not CWPOPT) and (r.w.s.cwp = CWPMAX) then
              s.cwp := CWPMIN;
            else
              s.cwp := r.w.s.cwp + 1;
            end if;
          when RETT =>
            if (not CWPOPT) and (r.w.s.cwp = CWPMAX) then
              s.cwp := CWPMIN;
            else
              s.cwp := r.w.s.cwp + 1;
            end if;
            s.s  := r.w.s.ps;
            s.et := '1';
          when others => null;
        end case;
      when others => null;
    end case;

    if MACPIPE and (r.x.mac = '1') then
      s.asr18 := mulo.result(31 downto 0);
      s.y     := mulo.result(63 downto 32);
    end if;
  end;

  function npc_find (lane           : integer range 0 to 1;
                     xc_br_miss_npc : std_logic;
                     r              : registers)
    return std_logic_vector is
    variable npc           : std_logic_vector(31 downto 0);
    variable atomic_active : std_logic;
  begin

    atomic_active := '0';

    if lane = 0 and is_atomic(r.x.ctrl.inst(0)) = '1' and r.x.ctrl.inst_valid(0) = '1' and r.a.ctrl.inst_valid(0) = '1' and r.a.astate = ld_exc then
      atomic_active := '1';
    end if;

    npc := r.f.pc;
    if lane = 0 and r.x.ctrl.inst_valid(0) = '1' and r.x.ctrl.swap = '0' and r.x.ctrl.inst_valid(1) = '1' and atomic_active = '0' then
      npc := r.x.ctrl.inst_pc(1);
    elsif lane = 1 and r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.swap = '1' and r.x.ctrl.inst_valid(0) = '1' and atomic_active = '0' then
      npc := r.x.ctrl.inst_pc(0);
    elsif r.m.ctrl.inst_valid /= "00" and atomic_active = '0' then
      if r.m.ctrl.inst_valid(0) = '1' and (r.m.ctrl.swap = '0' or r.m.ctrl.inst_valid(1) = '0') then
        npc := r.m.ctrl.inst_pc(0);
      else
        npc := r.m.ctrl.inst_pc(1);
      end if;
    elsif r.e.ctrl.inst_valid /= "00" and atomic_active = '0' then
      if r.e.ctrl.inst_valid(0) = '1' and (r.e.ctrl.swap = '0' or r.e.ctrl.inst_valid(1) = '0') then
        npc := r.e.ctrl.inst_pc(0);
      else
        npc := r.e.ctrl.inst_pc(1);
      end if;
    elsif r.a.ctrl.inst_valid /= "00" and atomic_active = '0' then
      if r.a.ctrl.inst_valid(0) = '1' and (r.a.ctrl.swap = '0' or r.a.ctrl.inst_valid(1) = '0') then
        npc := r.a.ctrl.inst_pc(0);
      else
        npc := r.a.ctrl.inst_pc(1);
      end if;
    elsif r.d.inst_valid /= "00" then
      --instructions in the decode stage are always
      --in correct order
      if r.d.inst_valid(0) = '1' then
        npc := r.d.inst_pc(0);
      else
        npc := r.d.inst_pc(1);
      end if;
    end if;

    if (is_branch(r.x.ctrl.inst(lane)) = '1' or is_fpu_branch(r.x.ctrl.inst(lane)) = '1') and r.x.ctrl.tt(lane) /= TT_IAEX then
      if r.x.ctrl.inst(lane)(29) = '1' then
        --bcc,a special case because delay slot might have been
        --invalidated. We need to set explicitly set the delay
        --slot as npc which would be NPC of bcc,a-4
        --on instruction access exception don't execute this since
        --the actual instruction is unknown
        npc := r.x.bht_ctrl.pc_delay_slot;  -- std_logic_vector(unsigned(r.x.bht_ctrl.br_ntaken_pc)-4);
      end if;
    end if;


    --if previous instruction is a branch and it is not resolved yet and it is
    --determined to be wrong prediction we need to use the branch correction PC
    --as next pc otherwise next_pc will be set wrongly to the wrong prediction
    --address
    if (lane = 0 and r.x.ctrl.swap = '1' and r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.branch(1) = '1' and xc_br_miss_npc = '1')
      or (lane = 1 and r.x.ctrl.swap = '0' and r.x.ctrl.inst_valid(0) = '1' and r.x.ctrl.branch(0) = '1' and xc_br_miss_npc = '1') then
      npc := r.x.bht_ctrl.br_miss_pc;
    end if;

    return(npc);
  end;

  procedure mul_res(lane             :     integer range 0 to 1;
                    r                :     registers;
                    result, y, asr18 : out word;
                    wr_y             : out std_logic;
                    wr_icc           : out std_logic;
                    wr_asr           : out std_logic;
                    icc              : out std_logic_vector(3 downto 0)) is
    variable op  : std_logic_vector(1 downto 0);
    variable op3 : std_logic_vector(5 downto 0);
  begin
    op     := r.m.ctrl.inst(lane)(31 downto 30);
    op3    := r.m.ctrl.inst(lane)(24 downto 19);
    result := r.m.result(lane);
    y      := r.m.y;
    icc    := r.m.icc;
    asr18  := mulo.result(31 downto 0);
    wr_y   := '0';
    wr_icc := '0';
    wr_asr := '0';
    case op is
      when FMT3 =>
        case op3 is
          when UMUL | SMUL =>
            if MULEN then
              result := mulo.result(31 downto 0);
              y      := mulo.result(63 downto 32);
              wr_y   := '1';
            end if;
          when UMULCC | SMULCC =>
            if MULEN then
              result := mulo.result(31 downto 0);
              y      := mulo.result(63 downto 32);
              wr_y   := '1';
              if lane = 1 then
                wr_icc := '1';
                icc    := mulo.icc;
              end if;
            end if;
          when UMAC | SMAC =>
            if MACEN and not MACPIPE then
              result := mulo.result(31 downto 0);
              --  asr18  := mulo.result(31 downto 0);
              y      := mulo.result(63 downto 32);
              wr_y   := '1';
              wr_asr := '1';
            end if;
          when UDIV | SDIV =>
            if lane = 1 then
              if DIVEN then
                result := divo.result(31 downto 0);
              end if;
            end if;
          when UDIVCC | SDIVCC =>
            if lane = 1 then
              if DIVEN then
                result := divo.result(31 downto 0);
                icc    := divo.icc;
                wr_icc := '1';
              end if;
            end if;
          when others => null;
        end case;
      when others => null;
    end case;
  end;

  function powerdwn(r : registers; trap : std_logic; rp : pwd_register_type) return std_logic is
    variable pd : std_logic;
  begin
    --powerdwn instruction is always force to lane0 due to WRY
    pd := '0';
    if trap = '0' and r.x.ctrl.inst_valid(0) = '1' then
      if is_pwd(r.x.ctrl.inst(0)) = '1' then
        pd := '1';
      end if;
    end if;
    return(pd);
  end;



  signal dummy : std_logic;


  signal rstv_pwd   : std_logic;
  signal rstv_debug : std_logic;
  signal arst       : std_logic;

begin

  cpu_index   <= dbgi.dynid;
  BPRED       <= not r.w.s.dbp;
  --blockbpmiss is disabled when branch prediciton is disabled
  --since there is no speculative fetch
  BLOCKBPMISS <= r.w.s.dbprepl and (not r.w.s.dbp);
  LATEALU     <= not dco.iuctrl.dlatealu;
  DLATEWICC   <= dco.iuctrl.dlatewicc;
  DLATEARITH  <= dco.iuctrl.dlatearith;
  FPSPEC      <= dco.iuctrl.fpspec;


  rstv_pwd <= '0';
  arst     <= testrst when (ASYNC_RESET and scantest /= 0 and testen /= '0') else
          rstn when ASYNC_RESET else
          '1';

  comb : process(ico, dco, rfo, r, wpr, ir, dsur, ur, rstn, holdn, irqi, dbgi, fpu5o, tco,
                 mulo, divo, dummy, rp, bhto, BPRED, BLOCKBPMISS, LATEALU, DLATEWICC, DLATEARITH, cpu_index,
                 hold_issue_s, waiting_ficc_s, atomic_nullify_s, mul_lane_s, ex_logic_res1_s,
                 ex_add_res1_s, exc_logic_res1_s, exc_add_res1_s, v_m, btb_hit, btb_outdata,
                 exc_res0_s, exc_res1_s, bht_diag_out, btb_diag_out, FPSPEC, fpc_retire, fpc_rfwen,
                 fpc_rfwdata, fpc_retid)

    variable v                      : registers;
    variable vp                     : pwd_register_type;
    variable vwpr                   : watchpoint_registers;
    variable vdsu                   : dsu_registers;
    variable de_hold_pc             : std_logic;
    variable de_inull               : std_logic;
    variable ex_ymsb                : std_logic;
    variable me_asr18               : word;
    variable diagdata               : word;
    variable dbgm, dbgm_l0, dbgm_l1 : std_logic;
    variable fpcdbgwr               : std_logic;
    variable dsign                  : std_logic;
    variable pwrd, sidle            : std_logic;
    variable parkreq                : std_ulogic;
    variable vir                    : irestart_register;
    variable icnt, fcnt             : std_logic;
    variable pccomp                 : pccomp_type;
    variable iustall                : std_logic;
    variable vu                     : ungated_registers;
    variable dbgcmd                 : std_logic_vector(2 downto 0);

    -----------------------------------------------------------------------------
    --LEON5
    -----------------------------------------------------------------------------
    variable btb_hitv                                       : std_logic;
    variable diag_btb_flush                                 : std_logic;
    --mul/div
    variable mul_op1, mul_op2                               : operand_pair_type;
    variable mul_op1_muxed, mul_op2_muxed                   : std_logic_vector(31 downto 0);
    variable mul_sign                                       : std_logic;
    variable div_op1_muxed, div_op2_muxed                   : std_logic_vector(31 downto 0);
    variable div_sign, div_a_sign, div_a_valid              : std_logic;
    variable mul_lane, div_start                            : std_logic;
    --FPU
    variable fpu5i_issue_cmd                                : std_logic_vector(2 downto 0);
    variable fpu5i_issue_cmd_btrap                          : std_logic_vector(2 downto 0);
    variable fpu5i_issue_ldstreg                            : std_logic_vector(5 downto 0);
    variable fpu5i_issue_ldstdp                             : std_ulogic;
    variable fpu5i_issue_op3_0                              : std_ulogic;
    variable fpu5i_issue_flop                               : std_logic_vector(8 downto 0);
    variable fpu5i_issue_rd                                 : std_logic_vector(4 downto 0);
    variable fpu5i_issue_rs1                                : std_logic_vector(4 downto 0);
    variable fpu5i_issue_rs2                                : std_logic_vector(4 downto 0);
    variable fpu5i_issue_dfqdata                            : std_logic_vector(63 downto 0);
    variable fpu5i_commit                                   : std_ulogic;
    variable fpu5i_commitid                                 : std_logic_vector(4 downto 0);
    variable fpu5i_lddata                                   : std_logic_vector(63 downto 0);
    variable fpu5i_unissue                                  : std_ulogic;
    variable fpu5i_unissue_sid                              : std_logic_vector(4 downto 0);
    variable fpu5i_unissue_comb                             : std_logic;
    variable fpu5i_unissue_comb_sid                         : std_logic_vector(4 downto 0);
    variable fpu5i_unissue_sid_final_muxed                  : std_logic_vector(4 downto 0);
    variable fpu5i_spstore_pend                             : std_logic;
    variable fpu5i_spstore_done                             : std_logic;
    variable fpu_issue_inst                                 : std_logic_vector(31 downto 0);
    --FETCH STAGE
    variable next_pc_t                                      : std_logic_vector(32 downto 0);
    variable next_pc, comb_pc                               : std_logic_vector(31 downto 0);
    variable inst_mux_prio                                  : std_logic;
    variable branch_reg                                     : std_logic;
    variable branch_reg_pc                                  : std_logic_vector(31 downto 0);
    variable ld_recover_inst                                : std_logic_vector(31 downto 0);
    --DECODE STAGE
    variable de_branch                                      : std_logic;
    variable de_branch_addr_muxed                           : std_logic_vector(31 downto 0);
    variable de_branchl                                     : std_logic_vector(1 downto 0);
    variable de_branch_l0_resolve                           : std_logic;
    variable de_branch_l1_resolve                           : std_logic;
    variable de_branch_l0_true                              : std_logic;
    variable de_branch_l1_true                              : std_logic;
    variable de_inst                                        : inst_pair_type;
    variable de_issue                                       : std_logic_vector(1 downto 0);
    variable de_fpc_issue                                   : std_logic_vector(1 downto 0);
    variable de_fpc_stdata_latch_mask                       : std_logic;
    variable bhto_taken                                     : std_logic;
    variable fpc_issue_mask                                 : std_logic_vector(1 downto 0);
    variable fpc_lane0_issue                                : std_logic;
    variable fpc_annul                                      : std_logic_vector(1 downto 0);
    variable fpc_issue_lane                                 : std_logic;
    variable v_d_fpc_annuled                                : std_logic;
    variable de_issue_clear_force                           : std_logic;
    variable de_fpc_issue_final                             : std_logic_vector(1 downto 0);
    variable de_issue_inst                                  : std_logic_vector(1 downto 0);
    variable de_branch_address                              : inst_pc_type;
    variable br_ntaken_pc                                   : inst_pc_type;
    variable pc_delay_slot                                  : inst_pc_type;
    variable v_a_wovf, v_a_wunf                             : std_logic_vector(1 downto 0);
    variable v_a_lalu_s1_tmp                                : std_logic;
    variable de_cwp                                         : cwp_pair_type;
    variable de_wcwp                                        : std_logic_vector(1 downto 0);
    variable de_rs1, de_rs2                                 : reg_short_pair_type;
    variable de_rs1_valid, de_rs2_valid                     : std_logic_vector(1 downto 0);
    variable de_rs3                                         : std_logic_vector(4 downto 0);
    variable de_rd                                          : reg_short_pair_type;
    variable de_waddr                                       : reg_pair_type;
    variable cwp_valid                                      : std_logic;
    variable de_cwp_f                                       : cwptype;
    variable de_wcwp_f                                      : std_logic;
    variable de_swap                                        : std_logic;
    variable de_rdw                                         : std_logic_vector(1 downto 0);
    variable ldd_z                                          : std_logic_vector(1 downto 0);
    variable de_raddr1, de_raddr2                           : reg_pair_type;
    variable delay_inst0_tmp                                : std_logic;
    variable v_d_inst                                       : icdtype;
    variable v_d_way                                        : std_logic_vector(IWAYMSB downto 0);
    variable v_d_mexc                                       : std_logic;
    variable v_a_branch0_tmp                                : std_logic;
    variable rfi_rdhold                                     : std_logic;
    variable rfi_raddr1, rfi_raddr2, rfi_raddr3, rfi_raddr4 : std_logic_vector(9 downto 0);
    variable rfi_raddr1lsb                                  : std_logic;
    variable rfi_raddr2lsb                                  : std_logic;
    variable rfi_raddr3lsb                                  : std_logic;
    variable rfi_raddr4lsb                                  : std_logic;
    variable rfi_re10,rfi_re11                              : std_logic;
    variable rfi_re20,rfi_re21                              : std_logic;
    variable rfi_re30,rfi_re31                              : std_logic;
    variable rfi_re40,rfi_re41                              : std_logic;
    variable rfi_debugen                                    : std_logic;
    variable rgz1,rgz2,rgz3,rgz4                            : std_logic;
    variable v_a_wunf0_tmp, v_a_wovf0_tmp                   : std_logic;
    variable late_wicc                                      : std_logic;
    variable late_wicc_ic                                   : std_logic;
    variable wicc_dexc_d                                    : std_logic;
    variable wicc_dmem_d                                    : std_logic;
    variable exc_wicc                                       : std_logic;
    variable alu_dexc_a                                     : std_logic_vector(1 downto 0);
    variable late_wicc_arith                                : std_logic;
    variable alu_dexc                                       : std_logic_vector(1 downto 0);
    variable v_a_delay_annuled0_tmp                         : std_logic;
    variable no_forward                                     : std_logic;
    variable use_sethi                                      : std_logic_vector(1 downto 0);
    variable use_logic                                      : std_logic_vector(1 downto 0);
    variable use_addsub                                     : std_logic_vector(1 downto 0);
    variable use_memaddr_add1                               : std_logic;
    variable use_logicshift                                 : std_logic;
    variable dual_ldissue                                   : std_logic;
    variable mask_divstart                                  : std_logic;
    variable de_mask_branch                                 : std_logic_vector(1 downto 0);
    variable mask_de_hold_pc                                : std_logic;
    variable annul_align4                                   : std_logic;
    variable no_b2b_cti                                     : std_logic;
    variable de_mask_insts                                  : std_logic;
    variable spec_in_pipeline                               : std_logic;
    variable ic_spec_access                                 : std_logic;
    variable cancel_annul_delayed                           : std_logic;
    variable cancel_annul                                   : std_logic;
    variable toc_e_dnext                                    : std_logic;
    variable hold_cti                                       : std_logic;
    variable wicc_d_temp                                    : std_logic;
    variable wy_d_temp                                      : std_logic;
    variable bht_takenv                                     : std_logic;
    variable speculative_lock_release                       : std_logic;
    variable v_d_iudiags                                    : iudiag_state;
    variable v_d_iudiag_miso                                : l5_intreg_miso_type;
    variable v_d_diag_btb_flush                             : std_logic; 
    variable v_d_diag_bht_flush                             : std_logic;
    variable v_d_btb_diag_in                                : l5_btb_diag_in_type;
    variable v_d_bht_diag_in_en                             : std_logic;
    variable v_d_bht_diag_in_wren                           : std_logic;
    --dbg
    variable holdn_deadlock_counter_tmp                     : std_logic_vector(20 downto 0);
    variable fpc_deadlock_counter_tmp                       : std_logic_vector(20 downto 0);
    variable hissue_deadlock_counter_tmp                    : std_logic_vector(20 downto 0);
    --
    --ACCESS STAGE
    variable ra_br_miss                                     : std_logic;
    variable ra_br_miss_pc                                  : std_logic_vector(31 downto 0);
    variable ra_br_lane                                     : std_logic;
    variable ra_branch_l0_resolve                           : std_logic;
    variable ra_branch_l0_misspredict                       : std_logic;
    variable ra_branch_l1_resolve                           : std_logic;
    variable ra_branch_l1_misspredict                       : std_logic;
    variable hold_issue                                     : std_logic;
    variable hold_issue_call                                : std_logic;
    variable waiting_ficc                                   : std_logic;
    variable ra_delay_annuled                               : std_logic;
    variable ra_delay_annuled_lane                          : std_logic;
    variable ra_delay_annul                                 : std_logic;
    variable ra_delay_no_annul                              : std_logic;
    variable de_delay_annul_next                            : std_logic;
    variable oper0_final_muxed_ra                           : operand_pair_type;
    variable oper1_final_muxed_ra                           : operand_pair_type;
    variable ex_fldbp2z                                     : std_logic_vector(1 downto 0);
    variable ra_div                                         : std_logic_vector(1 downto 0);  
    variable ex_data1, ex_data2                             : operand_pair_type;
    variable wicc_unused                                    : std_logic;
    variable rs3_sel                                        : std_logic_vector(1 downto 0);
    variable rs3_select_lane                                : std_logic;
    variable rs3_select_inst                                : std_logic_vector(31 downto 0);
    variable st_dbl                                         : std_logic;
    variable st_dbla0                                       : std_logic;
    variable rs3_control_inst                               : std_logic_vector(31 downto 0);
    variable atomic_nullify                                 : std_logic;
    variable atomic_finished                                : std_logic;
    variable v_a_astate                                     : atomic_state;
    variable atomic_hold_issue                              : std_logic;
    variable v_a_atomic_cnt                                 : std_logic_vector(1 downto 0);
    variable v_a_atomic_cnts                                : unsigned(2 downto 0);
    variable v_e_ctrl_inst_valid0                           : std_logic;
    variable v_a_casa                                       : std_logic;
    variable hold_issue_type                                : std_logic_vector(31 downto 0);
    variable divi_start                                     : std_logic;
    --EXECUTE STAGE
    variable exe_br_miss                                    : std_logic;
    variable exe_br_lane                                    : std_logic;
    variable exe_jmpl_ct                                    : std_logic;
    variable exe_rett_ct                                    : std_logic;
    variable exe_br_miss_pc                                 : std_logic_vector(31 downto 0);
    variable exe_delay_annuled                              : std_logic;
    variable exe_delay_annul                                : std_logic;
    variable exe_delay_no_annul                             : std_logic;
    variable exe_delay_annuled_lane                         : std_logic;
    variable exe_branch_l0_resolve                          : std_logic;
    variable exe_branch_l1_resolve                          : std_logic;
    variable exe_branch_l0_misspredict                      : std_logic;
    variable exe_branch_l1_misspredict                      : std_logic;
    variable ex_op1, ex_op2                                 : operand_pair_type;
    variable ex_op1_mul, ex_op2_mul                         : operand_pair_type;
    variable ex_shcnt                                       : shcnt_pair_type;
    variable ex_sari                                        : std_logic_vector(1 downto 0);
    variable ex_add_res                                     : ex_add_pair_type;
    variable ex_mem_address                                 : std_logic_vector(31 downto 0);
    variable ex_jump_address                                : std_logic_vector(31 downto 0);
    variable ex_logic_res                                   : operand_pair_type;
    variable ex_shift_res                                   : operand_pair_type;
    variable ex_misc_res                                    : operand_pair_type;
    variable ex_result                                      : operand_pair_type;
    variable ex_dci                                         : dc_in_type;
    variable v_m_result0                                    : std_logic_vector(31 downto 0);
    variable v_x_trap                                       : std_logic;
    variable y_unused                                       : std_logic_vector(31 downto 0);
    variable r_x_br_taken                                   : std_logic;
    variable logic_op1_alu0                                 : std_logic_vector(31 downto 0);
    variable logic_op2_alu0                                 : std_logic_vector(31 downto 0);
    variable shift_op1_alu0                                 : std_logic_vector(31 downto 0);
    variable exstdata_fwd                                   : std_logic;
    variable exe_ld_recover                                 : std_logic;
    variable bhti_ren                                       : std_logic;
    --MEMORY STAGE
    variable mem_br_miss                                    : std_logic;
    variable mem_br_lane                                    : std_logic;
    variable mem_br_miss_pc                                 : std_logic_vector(31 downto 0);
    variable mem_delay_annul                                : std_logic;
    variable mem_delay_annuled                              : std_logic;
    variable mem_delay_no_annul                             : std_logic;
    variable mem_delay_annuled_lane                         : std_logic;
    variable mem_jmpl_rett_op                               : std_logic;
    variable wr_y, wr_icc, wr_asr                           : std_logic_vector(1 downto 0);
    variable v_x_y_l                                        : operand_pair_type;
    variable me_asr18_l                                     : operand_pair_type;
    variable me_icc_l                                       : icc_pair_type;
    variable me_newtrap                                     : std_logic_vector(1 downto 0);
    variable me_newtt                                       : tt_array_type;
    variable me_nullify, me_nullify2                        : std_logic;
    variable me_iflush                                      : std_logic;
    variable me_edata                                       : std_logic_vector(63 downto 0);
    variable me_signed                                      : std_logic;
    variable me_size                                        : std_logic_vector(1 downto 0);
    variable me_laddr                                       : std_logic_vector(2 downto 0);
    variable me_icc                                         : std_logic_vector(3 downto 0);
    variable me_rd                                          : std_logic_vector(RFBITS-1 downto 0);
    variable me_cpld                                        : std_logic;
    variable memory_icc                                     : std_logic_vector(3 downto 0);
    variable icc_overwrite_m                                : std_logic;
    variable wicc_mem_delayed                               : std_logic;
    variable wicc_mem_overwrite                             : std_logic;
    variable mem_lalu_l1_op1                                : std_logic_vector(31 downto 0);
    variable mem_lalu_l1_op2                                : std_logic_vector(31 downto 0);
    variable mem_add_res                                    : std_logic_vector(32 downto 0);
    variable mem_logic_res                                  : std_logic_vector(31 downto 0);
    variable mem_shift_res                                  : std_logic_vector(31 downto 0);
    variable mem_add_res0                                   : std_logic_vector(32 downto 0);
    variable mem_logic_res_alu0                             : std_logic_vector(31 downto 0);
    variable mem_lalu_l0_op1                                : std_logic_vector(31 downto 0);
    variable mem_lalu_l0_op2                                : std_logic_vector(31 downto 0);
    variable mem_res_alu0                                   : std_logic_vector(31 downto 0);
    variable mem_icc                                        : std_logic_vector(3 downto 0);
    variable debug_read                                     : std_logic;
    variable irq_nullify                                    : std_logic;
    variable res_mem_temp                                   : std_logic_vector(31 downto 0);
    variable mem_ld_recover                                 : std_logic;
    --EXCEPTION STAGE
    variable xc_br_miss                                     : std_logic;
    variable xc_br_lane                                     : std_logic;
    variable xc_br_miss_pc                                  : std_logic_vector(31 downto 0);
    variable xc_delay_annul                                 : std_logic;
    variable xc_delay_no_annul                              : std_logic;
    variable xc_delay_annuled                               : std_logic;
    variable xc_delay_annuled_lane                          : std_logic;
    variable xc_me_nullify2                                 : std_logic;
    variable xc_exception, xc_wreg, xc_wregdbg              : std_logic;
    variable xc_exception_taken                             : std_logic;
    variable xc_wreg_l1                                     : std_logic;
    variable xc_trap_address                                : pctype;
    variable vir_addr_t                                     : std_logic_vector(32 downto 0);
    variable xc_trapl                                       : std_logic;
    variable wicc_exc_overwrite                             : std_logic;
    variable we1_invalid                                    : std_logic;
    variable we2_invalid                                    : std_logic;
    variable icc_overwrite_w                                : std_logic;
    variable exception_icc                                  : std_logic_vector(3 downto 0);
    variable xc_waddr_t                                     : std_logic_vector(9 downto 0);
    variable xc_ld_recover                                  : std_logic;
    variable r_x_ctrl_br_missp                              : std_logic;
    variable btb_wen_v                                      : std_logic;
    variable btb_instpc_v                                   : std_logic_vector(31 downto 0);
    variable btb_indata_temp                                : std_logic_vector(32 downto 0);
    variable btb_indata_v                                   : std_logic_vector(31 downto 0);
    variable btb_addr_op0                                   : std_logic_vector(31 downto 0);
    variable btb_addr_op1                                   : std_logic_vector(31 downto 0);
    variable btb_wl                                         : std_logic;
    variable rfi_wdata1v                                    : word64;
    variable xc_result, xc_result_l1                        : word;
    variable xc_result64, xc_result64_l1                    : word64;
    variable xc_df_result                                   : word64;
    variable xc_waddr, xc_waddr_l1                          : std_logic_vector(RFBITS-1 downto 0);
    variable xc_vectt                                       : std_logic_vector(7 downto 0);
    variable xc_trap                                        : std_logic;
    variable xc_fpexack                                     : std_logic;
    variable xc_rstn                                        : std_logic;
    variable xc_ldd                                         : std_logic;
    variable xc_inull                                       : std_logic;
    variable xc_mmucacheclr                                 : std_logic;
    variable exc_op1, exc_op2                               : operand_pair_type;
    variable logic_exc_op1_alu0, logic_exc_op2_alu0         : std_logic_vector(31 downto 0);
    variable exc_logic_res                                  : operand_pair_type;
    variable exc_add_res                                    : ex_add_pair_type;
    variable exc_shift_res                                  : operand_pair_type;
    variable exc_shcnt                                      : shcnt_pair_type;
    variable exc_sari                                       : std_logic_vector(1 downto 0);
    variable exc_res                                        : operand_pair_type;
    variable shift_exc_op1_alu0                             : std_logic_vector(31 downto 0);
    variable exc_icc                                        : std_logic_vector(3 downto 0);
    variable mask_we1, mask_we2                             : std_logic;
    variable xc_delay_annuled_remove                        : std_logic_vector(1 downto 0);
    variable rfi_we2                                        : std_logic_vector(1 downto 0);
    variable rfi_waddr2                                     : std_logic_vector(9 downto 0);
    variable rfi_wdata2                                     : std_logic_vector(63 downto 0);
    variable div_flush                                      : std_logic;
    variable br_ntaken_pc0                                  : std_logic_vector(32 downto 0);
    variable pc_next                                        : std_logic_vector(32 downto 0);
    variable bhti_wen                                       : std_logic;
    variable bhti_taken_final                               : std_logic;
    variable bhti_raddr_mux                                 : std_logic;
    variable bhti_waddr_mux                                 : std_logic;
    variable bhti_raddr_final                               : std_logic_vector(63 downto 0);
    variable bhti_raddr2_final                              : std_logic_vector(63 downto 0);
    variable bhti_waddr_final                               : std_logic_vector(63 downto 0);
    variable itr_valid                                      : std_logic_vector(1 downto 0);
    variable specreadannul                                  : std_logic;
    variable mask_trap_l                                    : std_logic_vector(1 downto 0);
    variable xc_br_miss_npc                                 : std_logic;
    variable xc_branch_true                                 : std_logic;
    variable xc_branch_addr                                 : pctype;
    variable xc_branch_pc                                   : pctype;
    variable xc_branch_inst                                 : std_logic_vector(31 downto 0);
    variable npc_lane0                                      : pctype;
    variable npc_lane1                                      : pctype;
    variable step_add                                       : std_logic_vector(32 downto 0);
    variable icache_en                                      : std_logic;
    variable wakeup_req                                     : std_logic;
    variable spectmp                                        : special_register_type;
--  WB
    variable rfi_waddr1_f                                   : std_logic_vector(9 downto 0);
    variable rfi_we10_f, rfi_we11_f                         : std_logic;
    variable rfi_wdata1_f                                   : std_logic_vector(63 downto 0);
    
  begin

    v                    := r;
    vwpr                 := wpr;
    vdsu                 := dsur;
    vp                   := rp;
    vu                   := ur;
    xc_fpexack           := '0';
    sidle                := '0';
    parkreq              := '0';
    fpcdbgwr             := '0';
    vir                  := ir;
    xc_rstn              := rstn;
    bhti_wen             := '0';
    bhti_taken_final     := '0';
    bhti_raddr_mux       := '0';
    bhti_waddr_mux       := '0';
    v.x.wicc_prev_lateld := '0';
    icc_overwrite_w      := '0';
    atomic_nullify       := '0';
    atomic_hold_issue    := '0';
    annul_align4         := '0';
    toc_e_dnext          := '0';        --ct_state is switching to toc_e state
    --if delay slot is in the next pair
    --assert this one

    icache_en := '0';
    if ico.ics_btb = "01" or ico.ics_btb = "11" then
      icache_en := '1';
    end if;

    btb_hitv := btb_hit and not(dco.iuctrl.dbtb) and BPRED and icache_en;
    iustall  := '0';

    bhto_taken := bhto.btb_taken;
    if dco.iuctrl.staticbp = '1' then
      bhto_taken := dco.iuctrl.staticd;
    end if;

-------------------------------------------------------------------------------
-- LEON5 Exception & Writeback STAGE
-------------------------------------------------------------------------------

    --trace filter related
    if tco.trace_upd = '1' then
      v.w.tco.addr_f      := tco.addr_f;
      v.w.tco.addr_f_p    := tco.addr_f_p;
      v.w.tco.inst_filter := tco.inst_filter;
    end if;
    v.x.itrhit := r.m.itrhit;

    exception_icc := r.w.s.icc;
    if (r.x.ctrl.wicc = '1' and r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.swap = '1') then
      --Flag was calculated in a previous stage hence use that value
      --we don't need to check delay_annuled because wicc instruction is older
      --here hence delay_annuled should be resolved when it reaches this stage
      exception_icc := r.x.icc;
    end if;

    mask_trap_l := "00";

    --if an instruction that will cause a trap is located in an annulable delay
    --slot and if the branch is not resolved yet resolve the branch and mask
    --the trap if the instruction is going to be anunled

    xc_branch_true := '0';
    if r.x.ctrl.branch(0) = '1' and r.x.ctrl.inst(0)(29) = '1' and r.x.ctrl.swap = '0' and r.x.ctrl.inst_valid(0) = '1' then
      xc_branch_true := branch_true(exception_icc,r.x.ctrl.inst(0));
      if (branch_mispredict(exception_icc, r.x.ctrl.inst(0), r.x.ctrl.br_taken) xor r.x.ctrl.br_taken) = '0' then
        mask_trap_l(1) := '1';
      end if;
    end if;

    if r.x.ctrl.branch(1) = '1' and r.x.ctrl.inst(1)(29) = '1' and r.x.ctrl.swap = '1' and r.x.ctrl.inst_valid(1) = '1' then
      xc_branch_true := branch_true(r.w.s.icc,r.x.ctrl.inst(1));
      if (branch_mispredict(r.w.s.icc, r.x.ctrl.inst(1), r.x.ctrl.br_taken) xor r.x.ctrl.br_taken) = '0' then
        mask_trap_l(0) := '1';
      end if;
    end if;

    if (r.x.ctrl.branch(0) = '0' and r.x.ctrl.unpcti(0) = '1') or
      (r.x.ctrl.branch(1) = '0' and r.x.ctrl.unpcti(1) = '1') then
      xc_branch_true := r.x.ctrl.br_taken;
    end if;

    xc_branch_pc := r.x.ctrl.inst_pc(0);
    xc_branch_inst := r.x.ctrl.inst(0);
    if r.x.ctrl.inst_valid(1) = '1' and is_branch(r.x.ctrl.inst(1)) = '1' then
      xc_branch_pc    := r.x.ctrl.inst_pc(1);
      xc_branch_inst := r.x.ctrl.inst(1);
    end if;
    xc_branch_inst(30) := '0';
    xc_branch_addr := branch_address(xc_branch_inst,xc_branch_pc);
    
    xc_br_miss_npc := branch_mispredict(exception_icc, r.x.ctrl.inst(0), r.x.ctrl.br_taken);
    if r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.branch(1) = '1' then
      xc_br_miss_npc := branch_mispredict(r.w.s.icc, r.x.ctrl.inst(1), r.x.ctrl.br_taken);
    end if;

    npc_lane0 := npc_find(0, xc_br_miss_npc, r);
    npc_lane1 := npc_find(1, xc_br_miss_npc, r);

    xc_exception                   := '0';
    icnt                           := '0';
    fcnt                           := '0';
    xc_waddr(RFBITS-1 downto 0)    := r.x.ctrl.rd(0)(RFBITS-1 downto 0);
    xc_waddr_l1(RFBITS-1 downto 0) := r.x.ctrl.rd(1)(RFBITS-1 downto 0);


    --memory operations are always on lane0
    xc_trap := (r.x.mexc and r.x.ctrl.inst_valid(0) and not(mask_trap_l(0)))
               or (r.x.ctrl.trap(0) and r.x.ctrl.inst_valid(0) and not(mask_trap_l(0)))
               or (r.x.ctrl.trap(1) and r.x.ctrl.inst_valid(1) and not(mask_trap_l(1)));

    --determine the lane for the trap, both instructions can have a trap in
    --that case the older instruction is selected for trap
    if ((r.x.mexc = '1' or r.x.ctrl.trap(0) = '1') and r.x.ctrl.inst_valid(0) = '1' and mask_trap_l(0) = '0') and (r.x.ctrl.swap = '0' or r.x.ctrl.trap(1) = '0' or r.x.ctrl.inst_valid(1) = '0') then
      xc_trapl := '0';
    else
      xc_trapl := '1';
    end if;
    v.x.nerror     := rp.error;
    xc_mmucacheclr := '0';
    xc_ldd         := '0';

    xc_vectt := "00" & r.x.ctrl.tt(0);
    if xc_trapl = '1' then
      xc_vectt := "00" & r.x.ctrl.tt(1);
    end if;
    if r.x.mexc = '1' and xc_trapl = '0' then
      xc_vectt := "00" & TT_DAEX;
    elsif xc_trapl = '0' and r.x.tt_ticc = '1' then
      xc_vectt := '1' & r.x.result(0)(6 downto 0);
    end if;

    if r.w.s.svt = '0' then
      xc_trap_address(31 downto 4) := r.w.s.tba & xc_vectt;
    else
      xc_trap_address(31 downto 4) := r.w.s.tba & "00000000";
    end if;
    xc_trap_address(3 downto PCLOW) := (others => '0');
    xc_wreg                         := '0';
    xc_wregdbg                      := '0';
    xc_wreg_l1                      := '0';
    v.x.annul_all                   := '0';
    xc_inull                        := '0';

    --Result for lane0 and lane1. If there is a late alu operation the result
    --will be taken from the ALU output of exception stage
    if ((is_load_int(r.x.ctrl.inst(0)) = '1' or is_atomic(r.x.ctrl.inst(0)) = '1') and r.x.ctrl.inst_valid(0) = '1') then
      xc_result64 := r.x.data(0);
    else
      xc_result64 := r.x.result(0) & r.x.result(0);
    end if;
    if r.x.ctrl.alu_dexc(0) = '1' then
      xc_result64 := exc_res0_s&exc_res0_s;
    end if;

    xc_df_result   := xc_result64;
    xc_result64_l1 := r.x.result(1) & r.x.result(1);

    if r.x.ctrl.alu_dexc(1) = '1' then
      xc_result64_l1 := exc_res1_s&exc_res1_s;
    end if;

    if PWRD2 then
      pwrd := powerdwn(r, xc_trap, rp);
    else
      pwrd := '0';
    end if;
    --temporary


    xc_result    := r.x.ctrl.pc(31 downto 2) & "00";
    xc_result_l1 := r.x.ctrl.inst_pc(1);

    --depending on the trap disable the register write of the other instruction
    --of the pair if required
    mask_we2 := '0';
    if xc_trapl = '0' and r.x.ctrl.swap = '0' and xc_trap = '1' then
      mask_we2 := '1';
    end if;

    mask_we1 := '0';
    if xc_trapl = '1' and r.x.ctrl.swap = '1' and xc_trap = '1' then
      mask_we1 := '1';
    end if;

    dbgm    := '0';
    dbgm_l0 := '0';
    dbgm_l1 := '0';
    if DBGUNIT then
      dbgm_l0 := dbgexc(0, r, dbgi, xc_trap and not(xc_trapl), xc_vectt, dsur);
      dbgm_l1 := dbgexc(1, r, dbgi, xc_trap and xc_trapl, xc_vectt, dsur);
      dbgm_l0 := dbgm_l0 and not(mask_trap_l(0)) and not(mask_we1);
      dbgm_l1 := dbgm_l1 and not(mask_trap_l(1)) and not(mask_we2);
      dbgm    := dbgm_l0 or dbgm_l1;
    end if;

    --Right not single step mode is only run with single issue
    if r.w.step.en = '1' then
      if r.w.step.counter = x"00000000" and r.x.rstate = run then
        v.w.step.dbgm := '1';
      end if;
      if (r.x.ctrl.inst_valid /= "00") and r.w.step.dbgm = '0' and xc_trap = '0' and r.x.rstate = run then
        step_add         := std_logic_vector(unsigned('1'&r.w.step.counter)-1);
        v.w.step.counter := step_add(31 downto 0);
        if r.w.step.counter = x"00000001" then
          v.w.step.dbgm := '1';
        end if;
      end if;
      if r.w.step.dbgm = '1' then
        if (r.x.ctrl.inst_valid /= "00") and xc_trap = '0' then
          dbgm          := '1';
          xc_vectt      := "00" & TT_WATCH;
          v.w.step.dbgm := '0';
          if r.x.ctrl.inst_valid(0) = '1' then
            dbgm_l0 := '1';
          end if;
          if r.x.ctrl.inst_valid(1) = '1' then
            dbgm_l1 := '1';
          end if;
        end if;
      end if;
    end if;

    if dbgi.mosi.accen = '0' or r.x.miso.accrdy = '1' then
      v.x.miso.accrdy := '0';
    end if;

    v.x.debug_ret      := '0';
    v.x.debug_ret2     := '0';
    v.d.br_flush       := '0';
    vp.pwd             := '0';
    xc_exception_taken := '0';
    v.x.captcmd_ack    := '0';
    vu.captcmd := (others => '0');
    dbgcmd := dbgi.cmd;
    if ur.captcmd /= "000" then
      dbgcmd := ur.captcmd;
    end if;
    case r.x.rstate is
      when run =>
        v.x.cpustate := CPUSTATE_RUNNING;
        --decouple xc_excetption signal from the hierarchical if structure
        --in order to not create an unnecessary false path
        if xc_trap = '1' then
          xc_exception := '1';
        end if;

        if dbgm = '1' then
          v.x.annul_all := '1';
          vir.addr      := r.x.ctrl.inst_pc(0);
          if (dbgm_l0 = '0' and dbgm_l1 = '1') or (r.x.ctrl.swap = '1' and dbgm_l1 = '1') then
            vir.addr := r.x.ctrl.inst_pc(1);
          end if;
          v.x.rstate := dsu1;
          v.x.debug  := '1';
          v.x.npc    := npc_lane0;
          if (dbgm_l0 = '0' and dbgm_l1 = '1') or (r.x.ctrl.swap = '1' and dbgm_l1 = '1') then
            v.x.npc := npc_lane1;
          end if;
          vdsu.tt      := xc_vectt;
          vdsu.brktype := "00";

          if dbgm_l0 = '0' and dbgm_l1 = '1' and r.x.ctrl.swap = '0' then
            --it is not possible to enter debug mode if the old instruction has
            --a trap hence no need to check trap here
            xc_wreg := r.x.ctrl.rdw(0) and r.x.ctrl.inst_valid(0);
            if r.x.ctrl.inst_valid(0) = '1' then
              sp_write (r, wpr, v.w.s, vwpr);
            end if;
            if is_ldd_int(r.x.ctrl.inst(0)) = '1' then
              xc_ldd := '1';
            end if;
          end if;

          if dbgm_l0 = '1' and dbgm_l1 = '0' and r.x.ctrl.swap = '1' then
            --it is not possible to enter debug mode if the old instruction has
            --a trap hence no need to check trap here
            xc_wreg_l1 := r.x.ctrl.rdw(1) and r.x.ctrl.inst_valid(1);
            if r.x.ctrl.inst_valid(1) = '1' then
              sp_write_l1(r, v.w.s, spectmp); v.w.s := spectmp;
            end if;
          end if;

          if dbgerr(r, dbgi, xc_vectt) = '1' then
            v.x.cpustate := CPUSTATE_ERRMODE;
          else
            v.x.cpustate := CPUSTATE_STOPPED;
          end if;
        elsif ((pwrd = '1') or (((dbgi.cmd(2) = '1') or (dbgi.cmd(1 downto 0) = "11")) and r.x.ctrl.inst_valid /= "00")) then
          v.x.annul_all := '1';
          vir.addr      := r.x.ctrl.inst_pc(0);
          v.x.rstate    := dsu1;
          v.x.npc       := npc_lane0;
          vdsu.tt       := "00" & TT_WATCH;
          if pwrd = '1' then
            v.x.cpustate := CPUSTATE_INSLEEP;
            vp.pwd       := '1';
            vdsu.brktype := "01";
          elsif dbgi.cmd(2) = '1' then
            v.x.cpustate := dbgi.cmd(1 downto 0);
            vdsu.brktype := "11";
            if r.x.ctrl.inst_valid(0) = '0' or (r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.swap = '1') then
              vir.addr := r.x.ctrl.inst_pc(1);
              v.x.npc  := npc_lane1;
            end if;
          else
            v.x.cpustate := CPUSTATE_STOPPED;
            vdsu.brktype := "10";
            if r.x.ctrl.inst_valid(0) = '0' or (r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.swap = '1') then
              vir.addr := r.x.ctrl.inst_pc(1);
              v.x.npc  := npc_lane1;
            end if;
          end if;
        elsif (xc_trap) = '0' then
          xc_wreg    := r.x.ctrl.rdw(0) and r.x.ctrl.inst_valid(0);
          xc_wreg_l1 := r.x.ctrl.rdw(1) and r.x.ctrl.inst_valid(1);


          if r.x.ctrl.inst_valid(0) = '1' and mask_trap_l(0) = '0' then
            sp_write (r, wpr, v.w.s, vwpr);
          end if;
          --right now we assume SAVE,RESTORE,RETT can not be issued in parallel
          --in addition write special register ops are issued only to lane0
          if r.x.ctrl.inst_valid(1) = '1' and mask_trap_l(1) = '0' then
            sp_write_l1(r, v.w.s, spectmp); v.w.s := spectmp;
          end if;
          vir.pwd := '0';
          if is_ldd_int(r.x.ctrl.inst(0)) = '1' then
            xc_ldd := '1';
          end if;
        elsif (xc_trap) = '1' then
          xc_exception_taken := '1';

          if xc_trapl = '1' and r.x.ctrl.swap = '0' then
            xc_wreg := r.x.ctrl.rdw(0) and r.x.ctrl.inst_valid(0) and not(r.x.ctrl.trap(0));
            if r.x.ctrl.inst_valid(0) = '1' and r.x.ctrl.trap(0) = '0' then
              sp_write (r, wpr, v.w.s, vwpr);
            end if;
            if is_ldd_int(r.x.ctrl.inst(0)) = '1' then
              xc_ldd := '1';
            end if;
          end if;

          if xc_trapl = '0' and r.x.ctrl.swap = '1' then
            xc_wreg_l1 := r.x.ctrl.rdw(1) and r.x.ctrl.inst_valid(1) and not(r.x.ctrl.trap(1));
            if r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.trap(1) = '0' then
              sp_write_l1(r, v.w.s, spectmp); v.w.s := spectmp;
            end if;
          end if;

          --we use v.w.s.cwp here since if a SAVE/RESTORE is commited
          --while there is a trap due to trap instruction being newer
          --the new instruciton should see the updated CWP

          if xc_trapl = '0' then
            xc_result                       := (others => '0');
            xc_result(31 downto PCLOW)      := r.x.ctrl.inst_pc(0)(31 downto PCLOW);
            xc_wreg                         := '1';
            xc_waddr                        := (others => '0');
            xc_waddr(NWINLOG2 + 3 downto 0) := v.w.s.cwp & "0001";
          end if;

          if xc_trapl = '1' then
            xc_result_l1                       := (others => '0');
            xc_result_l1(31 downto PCLOW)      := r.x.ctrl.inst_pc(1)(31 downto PCLOW);
            xc_wreg_l1                         := '1';
            xc_waddr_l1                        := (others => '0');
            xc_waddr_l1(NWINLOG2 + 3 downto 0) := v.w.s.cwp & "0001";
          end if;

          v.x.trapl     := xc_trapl;
          v.w.s.tt      := xc_vectt;
          v.w.s.ps      := r.w.s.s;
          v.w.s.s       := '1';
          v.x.annul_all := '1';
          v.x.rstate    := trap;
          v.x.npc       := npc_lane0;
          if xc_trapl = '1' then
            v.x.npc := npc_lane1;
          end if;
          assert r.w.s.et = '1';
        end if;

      when trap =>

        if r.x.trapl = '0' then
          xc_result                       := r.x.npc;
          xc_wreg                         := '1';
          xc_waddr                        := (others => '0');
          xc_waddr(NWINLOG2 + 3 downto 0) := r.w.s.cwp & "0010";
        end if;

        if r.x.trapl = '1' then
          xc_result_l1                       := r.x.npc;
          xc_wreg_l1                         := '1';
          xc_waddr_l1                        := (others => '0');
          xc_waddr_l1(NWINLOG2 + 3 downto 0) := r.w.s.cwp & "0010";
        end if;

        assert r.w.s.et = '1';

        v.w.s.et   := '0';
        v.x.rstate := run;
        if (not CWPOPT) and (r.w.s.cwp = CWPMIN) then
          v.w.s.cwp := CWPMAX;
        else
          v.w.s.cwp := r.w.s.cwp - 1;
        end if;
        
      when dsu1 =>
        vp.pwd                           := rp.pwd;
        xc_exception                     := '1';
        v.x.annul_all                    := '1';
        xc_trap_address(31 downto PCLOW) := r.f.pc;
        if DBGUNIT or PWRD2 or (smp /= 0) then
          xc_trap_address(31 downto PCLOW) := ir.addr;
          vir.addr                         := r.x.npc;
          v.x.rstate                       := dsu2;
          if rp.pwd = '1' then
            --when a power down instruction executed set the next PC
            --to upcoming instruction and the next pc to +4 of that
            --this way power down instruction is not executed continously
            xc_trap_address(31 downto PCLOW) := r.x.npc;
            vir_addr_t                       := std_logic_vector(unsigned('0'&r.x.npc)+4);
            vir.addr                         := vir_addr_t(31 downto 0);
          end if;
        end if;
        if DBGUNIT then
          v.x.debug := r.x.debug;
        end if;
      when unpcti_repeat =>
        v.x.annul_all                    := '1';
        xc_exception                     := '1';
        xc_trap_address(31 downto PCLOW) := r.x.npc;
        v.x.rstate                       := run_pre;
        v.x.debug_ret                    := '1';
      when dsu2 =>
        xc_exception                     := '1';
        v.x.annul_all                    := '1';
        xc_trap_address(31 downto PCLOW) := r.f.pc;
        parkreq                          := '1';
        vu.captcmd                       := ur.captcmd;
        if cgen /= 0 and (dbgi.cmd/="000" or r.x.captcmd_ack='1') then
          vu.captcmd                       := dbgi.cmd;
        end if;
        if ur.captcmd /= "000" then
          v.x.captcmd_ack := '1';
        end if;
        if r.x.cpustate /= CPUSTATE_RUNNING and ico.parked = '1' and
          ur.captcmd="000" and dbgi.mosi.accen='0' and r.x.captcmd_ack='0' then
          sidle := '1';
        end if;
        case r.x.cpustate is
          when CPUSTATE_STOPPED =>
            if dbgcmd(2) = '1' then
              v.x.cpustate := dbgcmd(1 downto 0);
            elsif dbgcmd = CPUCMD_START then
              v.x.cpustate := CPUSTATE_RUNNING;
            elsif dbgi.mosi.accen = '1' then
              v.x.rstate := dsu3;
            end if;
            if dbgi.pushpc = '1' then
              xc_trap_address(31 downto PCLOW) := ir.addr;
              vir.addr                         := (others => '0');
              vir.addr(31 downto 2)            := dbgi.pcin;
            end if;
          when CPUSTATE_ERRMODE =>
            if dbgcmd(2) = '1' then
              v.x.cpustate := dbgcmd(1 downto 0);
            elsif dbgi.mosi.accen = '1' then
              v.x.rstate := dsu3;
            end if;
          when CPUSTATE_INSLEEP =>
            vp.pwd := '1';
            if dbgcmd(2) = '1' then
              v.x.cpustate := dbgcmd(1 downto 0);
            elsif dbgcmd = CPUCMD_WAKEUP then
              v.x.cpustate  := CPUSTATE_RUNNING;
              v.x.ret_sleep := '1';
            elsif dbgcmd = CPUCMD_BREAK then
              v.x.cpustate := CPUSTATE_STOPPED;
            end if;
          when others =>                -- CPUSTATE_RUNNING
            v.x.rstate    := run_pre;
            vp.error      := '0';
            v.x.debug_ret := '1';
            v.x.debug     := '0';
            vir.pwd       := '1';
            v.x.ret_sleep := '0';
        end case;

      when run_pre =>
        --to make it work with only ici.rpc input
        xc_exception                     := '1';
        xc_trap_address(31 downto PCLOW) := ir.addr;
        v.x.rstate                       := run;
        v.x.annul_all                    := '0';
        v.x.debug_ret2                   := '1';
        v.w.step.dbgm                    := '0';

      when dsu3 =>
        xc_exception                     := '1';
        v.x.annul_all                    := '1';
        xc_trap_address(31 downto PCLOW) := r.f.pc;
        -- Debug register access
        if r.x.miso.accrdy = '0' then
          diagwr(r, dsur, ir, dbgi, wpr, v.w.s, v.w.step, vwpr, vdsu.asi, vdsu.asihiad, xc_trap_address,
                 vir.addr, xc_wreg, xc_waddr_t, xc_result, fpcdbgwr,
                 v.d.b2bstore_en, v.d.specload_en, v.d.dual_ldissue_en, v.d.br_flush);
          xc_waddr := xc_waddr_t(RFBITS-1 downto 0);
          if dbgi.mosi.addr(21-2 downto 19-2) = "111" then
            -- Cache access
            v.x.rstate := dsu4;
          else
            if holdn='1' then
              v.x.miso.accrdy := '1';
            end if;
          end if;
        else
          v.x.rstate := dsu2;
        end if;

      when dsu4 =>
        xc_exception                     := '1';
        v.x.annul_all                    := '1';
        xc_trap_address(31 downto PCLOW) := r.f.pc;
        -- Debug register access
        if r.x.miso.accrdy = '1' then
          v.x.rstate := dsu2;
        elsif dsur.crdy(2) = '1' then
          v.x.miso.accrdy := '1';
        end if;

      when others =>
    end case;

    xc_trapl_dbg <= xc_trapl;
    xc_trap_dbg  <= xc_trap;

    irq_intack(r, holdn, v.x.intack);

    --if a branch is comitted update the branch history table
    if r.x.ctrl.inst_valid(0) = '1' and r.x.annul_all = '0' and mask_we1 = '0' and (is_branch(r.x.ctrl.inst(0)) = '1' or (FPEN and is_fpu_branch(r.x.ctrl.inst(0)) = '1')) then
      if r.x.ctrl.inst(0)(28 downto 25) /= "0000" and r.x.ctrl.inst(0)(28 downto 25) /= "1000" then
        bhti_wen := '1';
      end if;
    end if;

    if r.x.ctrl.inst_valid(1) = '1' and r.x.annul_all = '0' and mask_we2 = '0' and (is_branch(r.x.ctrl.inst(1)) = '1' or (FPEN and is_fpu_branch(r.x.ctrl.inst(1)) = '1')) then
      if r.x.ctrl.inst(1)(28 downto 25) /= "0000" and r.x.ctrl.inst(1)(28 downto 25) /= "1000" then
        bhti_wen       := '1';
        bhti_waddr_mux := '1';
      end if;
    end if;

    v.w.except := xc_exception;
    if (r.x.rstate = dsu2) then
      v.w.except := '0';
    end if;

    ---------------------------------------------------------------------------
    -- LATE ALUcc (EXCEPTION)
    ---------------------------------------------------------------------------

    exc_op1   := r.x.alu_op1;
    exc_op2   := r.x.alu_op2;
    exc_shcnt := r.x.alu_ctrl.shcnt;
    exc_sari  := r.x.alu_ctrl.sari;

    --combinatorial forwarding for ALU in the exception stage
    --if there is a load operation that needs to be forwarded it can only be
    --forwarded to ALU in the lane-1 since load operation is in the lane-0
    for i in 0 to 1 loop
      if (r.x.ldfwd(i)(0) = '1' and i = 1) or r.x.multfwd(i)(0) = '1' then
        if r.x.rs1(i)(0) = '0' then
          exc_op1(i) := r.x.data(0)(63 downto 32);
        else
          exc_op1(i) := r.x.data(0)(31 downto 0);
        end if;
        if r.x.multfwd(i)(0) = '1' then
          exc_op1(i) := r.x.muldiv_result;
        end if;
        exc_sari(i) := exc_op1(i)(31) and r.x.ctrl.inst(i)(19) and r.x.ctrl.inst(i)(20);
      end if;

      if (r.x.ldfwd(i)(1) = '1' and i = 1) or r.x.multfwd(i)(1) = '1' then
        if r.x.rs2(i)(0) = '0' then
          exc_op2(i) := r.x.data(0)(63 downto 32);
        else
          exc_op2(i) := r.x.data(0)(31 downto 0);
        end if;
        if r.x.multfwd(i)(1) = '1' then
          exc_op2(i) := r.x.muldiv_result;
        end if;
        exc_shcnt(i) := exc_op2(i)(4 downto 0);
      end if;
    end loop;

    for i in 0 to 1 loop
      if r.x.alu_ctrl.invop2(i) = '1' and (r.x.ldfwd(i)(1) = '1' or r.x.multfwd(i)(1) = '1') then
        exc_op2(i)   := not(exc_op2(i));
        exc_shcnt(i) := not(exc_shcnt(i));
      end if;
    end loop;

    --forwarding for cascaded operations
    logic_exc_op1_alu0 := exc_op1(0);
    if r.x.alu_ctrl.use_sethi(0) = '1' then
      logic_exc_op1_alu0 := exc_op2(1);
    end if;

    logic_exc_op2_alu0 := exc_op2(0);
    if r.x.alu_ctrl.use_sethi(1) = '1' then
      logic_exc_op2_alu0 := exc_op2(1);
    end if;

    if r.x.alu_ctrl.use_logic(0) = '1' then
      logic_exc_op1_alu0 := exc_logic_res1_s;
    end if;

    if r.x.alu_ctrl.use_logic(1) = '1' then
      logic_exc_op2_alu0 := exc_logic_res1_s;
    end if;

    if r.x.alu_ctrl.use_addsub(0) = '1' then
      logic_exc_op1_alu0 := exc_add_res1_s;
    end if;

    if r.x.alu_ctrl.use_addsub(1) = '1' then
      logic_exc_op2_alu0 := exc_add_res1_s;
    end if;

    shift_exc_op1_alu0 := exc_op1(0);
    if r.x.alu_ctrl.use_logicshift = '1' then
      shift_exc_op1_alu0 := exc_logic_res1_s;
      exc_sari(0)        := shift_exc_op1_alu0(31) and r.x.ctrl.inst(0)(19) and r.x.ctrl.inst(0)(20);
    end if;

    --LANE0 ALU
    exc_add_res(0)   := (exc_op1(0) & '1') + (exc_op2(0) & r.x.alu_ctrl.alucin(0));
    logic_op_exc(r, r.x.alu_ctrl.aluop(0), logic_exc_op1_alu0, logic_exc_op2_alu0, exc_logic_res(0));
    exc_shift_res(0) := shift(r.x.alu_ctrl.shleft(0), shift_exc_op1_alu0, exc_op2(0), exc_shcnt(0), exc_sari(0));
    alu_select_nocc_exc(r, exc_add_res(0), exc_shift_res(0), exc_logic_res(0), exc_res(0));
    exc_res0_s       <= exc_res(0);
    --LANE1 ALUcc
    exc_add_res(1)   := (exc_op1(1) & '1') + (exc_op2(1) & r.x.alu_ctrl.alucin(1));
    logic_op_exc(r, r.x.alu_ctrl.aluop(1), exc_op1(1), exc_op2(1), exc_logic_res(1));
    exc_shift_res(1) := shift(r.x.alu_ctrl.shleft(1), exc_op1(1), exc_op2(1), exc_shcnt(1), exc_sari(1));
    alu_select_exc(r, r.x.alu_ctrl.alusel(1), r.x.alu_ctrl.aluadd(1), exc_add_res(1), exc_op1(1), exc_op2(1), exc_logic_res(1), exc_shift_res(1), exc_icc, exc_res(1));
    exc_res1_s       <= exc_res(1);

    exc_logic_res1_s <= exc_logic_res(1);
    exc_add_res1_s   <= exc_add_res(1)(32 downto 1);

    wicc_exc_overwrite := '0';
    if r.x.annul_all = '0' and r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.delay_annuled(1) = '0' and (xc_trap = '0' or (xc_trapl = '0' and r.x.ctrl.swap = '1')) and mask_trap_l(1) = '0' then
      if r.x.ctrl.wicc_dexc = '1' then
        --ICC flags are updated from the late ALU result
        wicc_exc_overwrite := '1';
        v.w.s.icc          := exc_icc;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Exception branch handling
    ---------------------------------------------------------------------------
    xc_br_miss        := '0';
    xc_delay_annul    := '0';
    xc_delay_no_annul := '0';
    xc_br_lane        := '0';
    xc_br_miss_pc     := r.x.bht_ctrl.br_miss_pc;
    r_x_br_taken      := r.x.ctrl.br_taken;

    xc_ld_recover     := '0';
    r_x_ctrl_br_missp := r.x.ctrl.br_missp;

    --trap masking for branch done later on
    --Branch handling for lane-0
    if r.x.ctrl.branch(0) = '1' and r.x.ctrl.inst_valid(0) = '1' and r.x.annul_all = '0' then
      if branch_mispredict(exception_icc, r.x.ctrl.inst(0), r.x.ctrl.br_taken) = '1' then
        --branch misspredicted
        r_x_ctrl_br_missp := '1';
        r_x_br_taken      := not(r.x.ctrl.br_taken);  --correct for BHT table write
        xc_br_miss        := '1';
        if r.x.ctrl.inst(0)(29) = '0' then
          --if a branch without annul flag then delay instruction
          --should not be annuled
          xc_delay_no_annul := '1';
        end if;
        if r.x.ctrl.inst(0)(29) = '1' then
          if r.x.ctrl.br_taken = '0' and is_branch_unc(r.x.ctrl.inst(0)) = '0' then
            --branch annul was in fact taken hence delay instruction
            --should not be annuled
            xc_delay_no_annul := '1';
            if r.x.ctrl.br_dual_ld = '1' then
              xc_delay_no_annul := '0';
              xc_ld_recover     := '1';
            end if;
          else
            --branch annul and branch was in fact taken hence delay
            --instrucion should be annuled
            xc_delay_annul := '1';
          end if;
        end if;
      else
        --branch predicted correctly
        if r.x.ctrl.inst(0)(29) = '1' then
          --branch annul instruction
          if r.x.ctrl.br_taken = '0' or is_branch_unc(r.x.ctrl.inst(0)) = '1' then
            --branch is not taken or BA
            --hence delay instruction should be annuled
            xc_delay_annul := '1';
            --delay slot instruction of a branch annul in memory stage
            --will always be in a previous stage
          end if;
        end if;
      end if;
    end if;

    --Branch handling for lane-1
    if r.x.ctrl.branch(1) = '1' and r.x.ctrl.inst_valid(1) = '1' and r.x.annul_all = '0' then
      xc_br_lane := '1';
      --if the pair contains a wicc branch can not be in lane-1 hence when
      --branch resides in lane 1 it is always possible to use r.w.s.icc
      if branch_mispredict(r.w.s.icc, r.x.ctrl.inst(1), r.x.ctrl.br_taken) = '1' then
        --branch misspredicted
        r_x_ctrl_br_missp := '1';
        r_x_br_taken      := not(r.x.ctrl.br_taken);  --correct for BHT table
        xc_br_miss        := '1';
        if r.x.ctrl.inst(1)(29) = '0' then
          --if a branch without annul flag then delay instruction
          --should not be annuled
          xc_delay_no_annul := '1';
        end if;
        if r.x.ctrl.inst(1)(29) = '1' then
          if r.x.ctrl.br_taken = '0' and is_branch_unc(r.x.ctrl.inst(1)) = '0' then
            --branch annul was in fact taken hence delay instruction
            --should not be annuled
            xc_delay_no_annul := '1';
            if r.x.ctrl.br_dual_ld = '1' then
              xc_delay_no_annul := '0';
              xc_ld_recover     := '1';
            end if;
          else
            --branch annul and branch was in fact taken hence delay
            --instrucion should be annuled
            xc_delay_annul := '1';
          end if;
        end if;
      else
        --branch predicted correctly
        if r.x.ctrl.inst(1)(29) = '1' then
          --branch annul instruction
          if r.x.ctrl.br_taken = '0' or is_branch_unc(r.x.ctrl.inst(1)) = '1' then
            --branch is not taken or BA
            --hence delay instruction should be annuled
            xc_delay_annul := '1';
            --delay slot instruction of a branch annul in memory stage
            --will always be in a previous stage
          end if;
        end if;
      end if;
    end if;

    if xc_trap = '1' then
      --if a branch gets a trap due to interrupt etc. mask
      --all the branch flags to prevent any wrong action on CWP
      --updates
      if xc_trapl = '0' and xc_br_lane = '0' then
        xc_br_miss        := '0';
        xc_delay_no_annul := '0';
        xc_delay_annul    := '0';
        v.x.xc_ld_replay  := '0';
      end if;
      if xc_trapl = '1' and xc_br_lane = '1' then
        xc_br_miss        := '0';
        xc_delay_no_annul := '0';
        xc_delay_annul    := '0';
        v.x.xc_ld_replay  := '0';
      end if;
    end if;

    ---------------------------------------------------------------------------
    --BTB handling
    ---------------------------------------------------------------------------
    btb_wen_v    := '0';
    btb_wl       := '0';
    btb_instpc_v := r.x.ctrl.inst_pc(0);
    if r.x.ctrl.inst_valid(0) = '1' and r.x.annul_all = '0' and mask_we1 = '0' and is_branch(r.x.ctrl.inst(0)) = '1'and r.x.ctrl.inst_pc(0)(2) = '0' and r.x.ctrl.trap(0) = '0' then
      if r_x_br_taken = '1' and (r.x.ctrl.bht_data /= "00" or r.x.ctrl.inst(0)(28 downto 25) = "1000") then
        btb_wen_v := '1';
      end if;
    end if;

    if r.x.ctrl.inst_valid(1) = '1' and r.x.annul_all = '0' and mask_we2 = '0' and is_branch(r.x.ctrl.inst(1)) = '1'and r.x.ctrl.inst_pc(1)(2) = '0' and r.x.ctrl.trap(1) = '0' then
      if r_x_br_taken = '1' and (r.x.ctrl.bht_data /= "00" or r.x.ctrl.inst(1)(28 downto 25) = "1000") then
        btb_wen_v    := '1';
        btb_wl       := '1';
        btb_instpc_v := r.x.ctrl.inst_pc(1);
      end if;
    end if;

    --right now only branches goes to BTB
    btb_addr_op0 := r.x.ctrl.inst_pc(0);
    btb_addr_op1 := r.x.ctrl.inst(0);
    if btb_wl = '1' then
      btb_addr_op0 := r.x.ctrl.inst_pc(1);
      btb_addr_op1 := r.x.ctrl.inst(1);
    end if;

    --generate the branch target address
    btb_addr_op1(31 downto 24) := (others => (btb_addr_op1(21)));
    btb_addr_op1(23 downto 2)  := btb_addr_op1(21 downto 0);
    btb_addr_op1(1 downto 0)   := "00";
    if notx(btb_addr_op0) and notx(btb_addr_op1) then
      btb_indata_temp := std_logic_vector(unsigned('0'&btb_addr_op0)+unsigned('0'&btb_addr_op1));
    else
      setx(btb_indata_temp);
    end if;
    btb_indata_v := btb_indata_temp(31 downto 0);

    ---------------------------------------------------------------------------

    xc_delay_annuled_remove := "00";
    xc_me_nullify2          := '0';
    xc_delay_annuled        := '0';
    xc_delay_annuled_lane   := '0';
    if xc_delay_annul = '1' then
      if xc_br_lane = '0' and r.x.ctrl.swap = '0' then
        if r.x.ctrl.delay_inst(1) = '1' and r.x.ctrl.inst_valid(1) = '1' then
          mask_we2              := '1';
          xc_delay_annul        := '0';
          xc_delay_annuled      := '1';
          xc_delay_annuled_lane := '1';
        end if;
      end if;

      if xc_br_lane = '1' and r.x.ctrl.swap = '1' then
        if r.x.ctrl.delay_inst(0) = '1' and r.x.ctrl.inst_valid(0) = '1' then
          xc_delay_annul   := '0';
          xc_delay_annuled := '1';
          mask_we1         := '1';
        end if;
      end if;
    end if;

    if xc_delay_no_annul = '1' then
      if xc_br_lane = '0' and r.x.ctrl.swap = '0' then
        if r.x.ctrl.delay_inst(1) = '1' and r.x.ctrl.inst_valid(1) = '1' then
          xc_delay_no_annul := '0';
          if is_wicc(r.x.ctrl.inst(1)) = '1' and r.x.ctrl.delay_annuled(1) = '1' then
            v.w.s.icc := r.x.icc_dannul;
            if r.x.ctrl.wicc_dexc = '1' then
              v.w.s.icc := exc_icc;
            end if;
          end if;
          if r.x.ctrl.delay_annuled(1) = '1' then
            xc_delay_annuled_remove(1) := '1';
          end if;
        end if;
      end if;

      if xc_br_lane = '1' and r.x.ctrl.swap = '1' then
        if r.x.ctrl.delay_inst(0) = '1' and r.x.ctrl.inst_valid(0) = '1' then
          xc_delay_no_annul := '0';
          if r.x.ctrl.delay_annuled(0) = '1' then
            xc_delay_annuled_remove(0) := '1';
          end if;
        end if;
      end if;
    end if;


    mask_we1 := mask_we1 or (r.x.ctrl.delay_annuled(0) and r.x.ctrl.inst_valid(0) and not(xc_delay_annuled_remove(0)));
    mask_we2 := mask_we2 or (r.x.ctrl.delay_annuled(1) and r.x.ctrl.inst_valid(1) and not(xc_delay_annuled_remove(1)));

    if (r.x.ctrl.wy(0) = '1' and r.x.ctrl.inst_valid(0) = '1' and mask_we1 = '1') or
      (r.x.ctrl.wy(1) = '1' and r.x.ctrl.inst_valid(1) = '1' and mask_we2 = '1') then
      v.w.s.y := r.w.s.y;
    end if;

    if (r.x.ctrl.inst_valid(0) = '1' and r.x.ctrl.unpcti(0) = '1' and mask_we1 = '0') or
      (r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.unpcti(1) = '1' and mask_we2 = '0') then
      if xc_branch_true = '1' then
        --during unpcti the next instruction is a branch hence can not be dual
        --issued so nothing to mask
        v.x.annul_all := '1';
        v.x.rstate    := unpcti_repeat;
        v.x.npc       := npc_lane0;
        if r.x.ctrl.unpcti(1) = '1' then
          v.x.npc := npc_lane1;
        end if;
        vir.addr := xc_branch_addr;
      end if;
    end if;


    specreadannul := '0';
    --if there is a speculative load opeartion and the load oeprations is going
    --to be annuled assert the specreadannul in order to not cause a miss
    --if a speculative load causes a miss there will be one cycle window to assert
    --annul in which cache will deassert the holdn signal
    if r.x.speculative_load = '1' and mask_we1 = '1' and holdn = '0' then
      specreadannul := '1';
    end if;

    --Handle the register writes if two instructions are writing to the same destination.
    --The instruction which has the no_forward bit is set is masked
    we1_invalid := '0';
    we2_invalid := '0';
    if xc_wreg = '1' and xc_wreg_l1 = '1' and r.x.ctrl.inst_valid = "11" and r.x.ctrl.rd(0) = r.x.ctrl.rd(1) and mask_we1 = '0' and mask_we2 = '0' and xc_trap = '0' then
      if r.x.ctrl.no_forward(0) = '1' then
        we1_invalid := '1';
      end if;

      if r.x.ctrl.no_forward(1) = '1' then
        we2_invalid := '1';
      end if;
    end if;

    rfi_we2(0) := xc_wreg_l1 and not(xc_waddr_l1(0)) and not(mask_we2) and not(we2_invalid);
    rfi_we2(1) := xc_wreg_l1 and xc_waddr_l1(0) and not(mask_we2) and not(we2_invalid);
    rfi_waddr2 := (others => '0');
    rfi_waddr2(RFBITS-2 downto 0) := xc_waddr_l1(RFBITS-1 downto 1);
    rfi_wdata2 := xc_result64_l1;
    if (r.x.rstate /= run) or (xc_exception = '1' and xc_exception_taken = '1' and xc_trapl = '1') then
      rfi_wdata2 := xc_result_l1 & xc_result_l1;
    end if;

    rfi_wdata1v := xc_result64;
    if (r.x.rstate /= run) or (xc_exception = '1' and xc_exception_taken = '1' and xc_trapl = '0') then
      rfi_wdata1v := xc_result & xc_result;
    end if;

    v.w.wb_data(0) := rfi_wdata1v;
    v.w.wb_data(1) := rfi_wdata2;

    rfi_wdata1_f   := r.w.wb_data(0);
    
    rfi.wdata1 <= rfi_wdata1_f;
    rfi.wdata2 <= r.w.wb_data(1);

    rfi_wdata1_dbg <= v.w.wb_data(0);
    if FPEN and is_fpu_load(r.x.ctrl.inst(0)) = '1' then
      rfi_wdata1_dbg <= r.x.data(0);
    end if;
    rfi_wdata2_dbg <= v.w.wb_data(1);

    if DBGUNIT then
      --make sure diagnostic RF writes
      --does not get masked
      if r.x.rstate = dsu2 then
        we1_invalid := '0';
        mask_we1    := '0';
        xc_ldd      := '0';
      end if;
    end if;

    --when step.dbgm is set the instruction is going to cause debug mode hence
    --don't log
    itr_valid(0) := r.x.ctrl.inst_valid(0) and not(mask_we1) and not(r.w.step.dbgm) and holdn;
    itr_valid(1) := r.x.ctrl.inst_valid(1) and not(mask_we2) and not(r.w.step.dbgm) and holdn;

    itrace(r,
           r.x.ctrl.swap,
           itr_valid,
           v.w.wb_data(0)(63 downto 32),
           v.w.wb_data(1)(63 downto 32),
           xc_exception,
           dbgi,
           rp.error,
           xc_trap and not(xc_trapl),
           xc_trap and xc_trapl,
           fpc_retire,
           fpc_rfwen,
           fpc_rfwdata,
           fpc_retid,
           v.w.tdata);

    tpo.tdata <= r.w.tdata;


    v.w.waddr(0) := (others => '0');
    v.w.waddr(0)(RFBITS-2 downto 0) := xc_waddr(RFBITS-1 downto 1);
    v.w.we(0)(0) := xc_wreg and ((xc_ldd and not(r.x.ctrl.ldd_z)) or (not xc_waddr(0))) and not(mask_we1) and not(we1_invalid);
    v.w.we(0)(1) := xc_wreg and (xc_ldd or xc_waddr(0)) and not(mask_we1) and not (we1_invalid);

    v.w.waddr(1) := rfi_waddr2;
    v.w.we(1)(0) := rfi_we2(0) and not(we2_invalid);
    v.w.we(1)(1) := rfi_we2(1) and not(we2_invalid);

    v.w.rd(0) := r.x.ctrl.rd(0);
    v.w.rd(1) := r.x.ctrl.rd(1);

    rfi_waddr1_f := r.w.waddr(0);
    rfi_we10_f   := r.w.we(0)(0) and holdn;
    rfi_we11_f   := r.w.we(0)(1) and holdn;
 

    rfi.waddr1 <= rfi_waddr1_f;
    rfi.we1(0) <= rfi_we10_f;
    rfi.we1(1) <= rfi_we11_f;
    rfi.waddr2 <= r.w.waddr(1);
    rfi.we2(0) <= r.w.we(1)(0) and holdn;
    rfi.we2(1) <= r.w.we(1)(1) and holdn;


    irqo.intack <= r.x.intack and holdn;
    irqo.irl    <= r.w.s.tt(3 downto 0);
    irqo.pwd    <= rp.pwd;
    irqo.fpen   <= r.w.s.ef;
    irqo.err    <= r.x.nerror;

    dci.intack      <= r.x.intack and holdn;
    dci.mmucacheclr <= xc_mmucacheclr;

    mask_we_dbg <= (mask_we2) & (mask_we1);
    
    if (not ASYNC_RESET) and (not RESET_ALL) and (xc_rstn = '0') then
      v.w.except           := RRES.w.except;
      v.w.we               := RRES.w.we;
      v.w.rd               := RRES.w.rd;
      v.w.s.et             := RRES.w.s.et;
      v.w.s.svt            := RRES.w.s.svt;
      v.w.s.dwt            := RRES.w.s.dwt;
      v.w.s.dbp            := RRES.w.s.dbp;
      v.w.s.dbprepl        := RRES.w.s.dbprepl;
      v.w.s.ducnt          := RRES.w.s.ducnt;
      v.w.s.ef             := RRES.w.s.ef;
      v.w.s.icc            := RRES.w.s.icc;
      v.x.annul_all        := RRES.x.annul_all;
      v.x.rstate           := RRES.x.rstate;
      v.x.cpustate         := RRES.x.cpustate;
      v.x.debug_ret        := '0';
      v.x.debug_ret2       := '0';
      v.x.trapl            := '0';
      v.x.speculative_load := '0';
      v.x.xc_ld_replay     := '0';
      vir.pwd              := IRES.pwd;
      vp.pwd               := PRES.pwd;
      v.x.debug            := RRES.x.debug;
      vp.error             := '1';

      -- pragma translate_off
      --vp.error := '0';
      -- pragma translate_on

      v.x.nerror             := RRES.x.nerror;
      v.x.npc                := RRES.x.npc;
      v.x.mexc               := '0';
      v.x.update_late_dannul := '0';
      v.m.casz               := '0';
      if svt = 1 then
        v.w.s.tt := RRES.w.s.tt;
      end if;
    end if;
    if (not ASYNC_RESET or DYNRST) and (not RESET_ALL) and (xc_rstn = '0') then
--      if DYNRST then v.w.s.tba := irqi.rstvec; else
      v.w.s.tba := RRES.w.s.tba;
--    end if;
    end if;

-------------------------------------------------------------------------------
-- LEON5 Memory STAGE
-------------------------------------------------------------------------------

    v.x.ctrl        := r.m.ctrl;
    v.x.alu_ctrl    := r.m.alu_ctrl;
    v.x.dci         := r.m.dci;
    v.x.laddr       := r.m.result(0)(2 downto 0);
    v.x.rs1         := r.m.rs1;
    v.x.rs2         := r.m.rs2;
    v.x.rs3         := r.m.rs3;
    v.x.bht_ctrl    := r.m.bht_ctrl;
    v.x.fpc_ctrl    := r.m.fpc_ctrl;
    icc_overwrite_m := '0';

    if r.m.ctrl.inst_valid /= "11" then
      if is_atomic(r.m.ctrl.inst(0)) = '0' then
        v.x.ctrl.no_forward := "00";
      end if;
    end if;

    v.x.ctrl.inst_valid(0) := r.m.ctrl.inst_valid(0) and not(v.x.annul_all) and not xc_br_miss;
    v.x.ctrl.inst_valid(1) := r.m.ctrl.inst_valid(1) and not(v.x.annul_all) and not xc_br_miss;


    --This applies for all the pipeline stages
    --There can be only one delay instruction in a pair.
    --if ***_delay_annul is set and the instruction is a delay instruction
    --it is invalidated and **_delay_annul signal is deasserted. This is
    --mainly used when a bcc,a is predicted to be not taken and the prediction
    --was resolved to be correct in a later stage. This will annul the delay
    --instruction only. If no delay instruction exists in the pair it will
    --continue to check subsequent stages. (it can happen if bubbles are inserted
    --after a branch which is single issued or aligned to 0x4)



    mem_delay_annuled      := '0';
    mem_delay_annuled_lane := '0';
    if xc_delay_annul = '1' then
      if r.m.ctrl.delay_inst(0) = '1' and r.m.ctrl.inst_valid(0) = '1' then
        v.x.ctrl.inst_valid(0) := '0';
        mem_delay_annuled      := '1';
        xc_me_nullify2         := '1';
      elsif r.m.ctrl.delay_inst(1) = '1' and r.m.ctrl.inst_valid(1) = '1' then
        v.x.ctrl.inst_valid(1) := '0';
        mem_delay_annuled      := '1';
        mem_delay_annuled_lane := '1';
      end if;
    end if;

    if xc_br_miss = '1' then
      if (r.m.ctrl.delay_inst(0) = '1' and r.m.ctrl.inst_valid(0) = '1' and xc_delay_no_annul = '1') then
        v.x.ctrl.delay_annuled(0) := '0';
        v.x.ctrl.inst_valid(0)    := '1';
        xc_delay_no_annul         := '0';
      else
        v.x.ctrl.inst_valid(0) := '0';
        xc_me_nullify2         := '1';
      end if;

      if (r.m.ctrl.delay_inst(1) = '1' and r.m.ctrl.inst_valid(1) = '1' and xc_delay_no_annul = '1') then
        v.x.ctrl.delay_annuled(1) := '0';
        v.x.ctrl.inst_valid(1)    := '1';
        xc_delay_no_annul         := '0';
        if is_wicc(r.m.ctrl.inst(1)) = '1' and r.m.ctrl.delay_annuled(1) = '1' then
          --if dmem and dexc is 0 it means wicc was calculated in execute stage
          --and stored in r.m.icc_dannul
          if r.m.ctrl.wicc_dmem = '0' and r.m.ctrl.wicc_dexc = '0' then
            icc_overwrite_m := '1';
            v.x.icc         := r.m.icc_dannul;
          end if;
        end if;
      else
        v.x.ctrl.inst_valid(1) := '0';
      end if;
    end if;

    mul_res(0, r, v.x.result(0), v_x_y_l(0), me_asr18_l(0), wr_y(0), wr_icc(0), wr_asr(0), me_icc_l(0));
    mul_res(1, r, v.x.result(1), v_x_y_l(1), me_asr18_l(1), wr_y(1), wr_icc(1), wr_asr(1), me_icc_l(1));


    if (r.m.ctrl.inst_valid(1) = '1' and is_div(r.m.ctrl.inst(1)) = '1') then
      v.x.muldiv_result := divo.result(31 downto 0);
    end if;

    if (r.m.ctrl.inst_valid(0) = '1' and is_mul(r.m.ctrl.inst(0)) = '1')
      or (r.m.ctrl.inst_valid(1) = '1' and is_mul(r.m.ctrl.inst(1)) = '1') then
      v.x.muldiv_result := mulo.result(31 downto 0);
    end if;

    mem_trap(r, wpr, v.x.annul_all, holdn, v.x.ctrl.trap, me_iflush,
             me_nullify, v.m.werr, v.x.ctrl.tt);
    me_newtrap := v.x.ctrl.trap;
    me_newtt := v.x.ctrl.tt;

    irq_trap(v,
             r,
             ir,
             irqi.irl,
             v.x.annul_all or xc_br_miss,
             me_newtrap,
             me_newtt,
             me_nullify,
             v.m.irqen,
             v.m.irqen2,
             irq_nullify,
             v.x.ctrl.trap,
             v.x.ipend,
             v.x.ctrl.tt);

    if r.x.cpustate = CPUSTATE_INSLEEP then
      sidle := sidle and not v.x.ipend;
    end if;
    dbgo.idle   <= sidle;
    ici.parkreq <= parkreq;

    me_nullify2 := '0';
    if xc_me_nullify2 = '1' or irq_nullify = '1' or r.m.dc_nullify = '1' then
      me_nullify2 := '1';
    end if;

    --this is for when a ldst is dual issed with a SAVE/RESTORE 
    if r.m.ctrl.trap(1) = '1' and r.m.ctrl.inst_valid(1) = '1' and r.m.ctrl.swap = '1' then
      if is_ldst(r.m.ctrl.inst(0)) = '1' then
        me_nullify2 := '1';
      end if;
    end if;


    v.x.y    := r.m.y;
    me_icc   := r.m.icc;
    me_asr18 := v.w.s.asr18;


    mem_br_miss        := '0';
    mem_delay_annul    := '0';
    mem_delay_no_annul := '0';
    mem_br_lane        := '0';
    mem_br_miss_pc     := r.m.bht_ctrl.br_miss_pc;

    memory_icc := r.m.icc;

    if r.m.ctrl.swap = '0' and r.m.ctrl.inst_valid(1) = '1' and r.m.ctrl.wicc = '1'
      and r.m.ctrl.delay_annuled(1) = '0' and r.m.ctrl.wicc_dmem = '0'
      and r.m.ctrl.wicc_dexc = '0' and r.m.ctrl.wicc_muldiv = '0' then
      --there is an wicc on lane-1 and instructions are not swapped. r.m.icc is
      --updated with the wicc value. If there is a branch on lane-0 it should
      --not see this value because wicc comes later hence use the r.x.icc
      memory_icc := r.x.icc;
    end if;

    v.x.ctrl.br_missp := '0';
    mem_ld_recover    := '0';
    if r.m.ctrl.branch(0) = '1' and r.m.ctrl.inst_valid(0) = '1' and r.m.ctrl.trap(0) = '0' then
      if not (((r.m.ctrl.wicc_dmem = '1' or r.m.ctrl.wicc_muldiv = '1' or r.m.ctrl.wicc_dexc = '1')
                and r.m.ctrl.swap = '1' and r.m.ctrl.inst_valid(1) = '1')        
               or (r.x.ctrl.inst_valid(1) = '1' and r.x.ctrl.wicc_dexc = '1')) then
        v.x.ctrl.branch(0) := '0';
        if branch_mispredict(memory_icc, r.m.ctrl.inst(0), r.m.ctrl.br_taken) = '1' then
          --branch misspredicted
          v.x.ctrl.br_missp := '1';
          v.x.ctrl.br_taken := not(r.m.ctrl.br_taken);  --correct for BHT table
          mem_br_miss       := '1';
          if r.m.ctrl.inst(0)(29) = '0' then
            --if a branch without annul flag then delay instruction
            --should not be annuled
            mem_delay_no_annul := '1';
          end if;
          if r.m.ctrl.inst(0)(29) = '1' then
            if r.m.ctrl.br_taken = '0' and is_branch_unc(r.m.ctrl.inst(0)) = '0' then
              --branch annul was in fact taken hence delay instruction
              --should not be annuled
              mem_delay_no_annul := '1';
              if r.m.ctrl.br_dual_ld = '1' then
                mem_delay_no_annul := '0';
                mem_ld_recover     := '1';
              end if;
            else
              --branch annul and branch was in fact taken hence delay
              --instrucion should be annuled
              mem_delay_annul := '1';
            end if;
          end if;
        else
          --branch predicted correctly
          if r.m.ctrl.inst(0)(29) = '1' then
            --branch annul instruction
            if r.m.ctrl.br_taken = '0' or is_branch_unc(r.m.ctrl.inst(0)) = '1' then
              --branch is not taken or BA
              --hence delay instruction should be annuled
              mem_delay_annul := '1';
              --delay slot instruction of a branch annul in memory stage
              --will always be in a previous stage
            end if;
          end if;
        end if;
      end if;
    end if;


    if r.m.ctrl.branch(1) = '1' and r.m.ctrl.inst_valid(1) = '1' and r.m.ctrl.trap(1) = '0' then
      --if branch is on lane-1 that means there can not be a CC operation in
      --the same pair so just look at the exception 
      if not ((r.x.ctrl.inst_valid(1) or r.m.ctrl.inst_valid(1)) = '1' and r.x.ctrl.wicc_dexc = '1') then
        v.x.ctrl.branch(1) := '0';
        mem_br_lane        := '1';
        --  if branch_mispredict(memory_icc,r.m.ctrl.inst(1),r.m.ctrl.br_taken) = '1' then
        --if branch is on lane-1 it means there is no wicc instruction in the pair
        --so r.m.icc value can be used
        if branch_mispredict(r.m.icc, r.m.ctrl.inst(1), r.m.ctrl.br_taken) = '1' then
          --branch misspredicted
          v.x.ctrl.br_missp := '1';
          v.x.ctrl.br_taken := not(r.m.ctrl.br_taken);  --correct for BHT table
          mem_br_miss       := '1';
          if r.m.ctrl.inst(1)(29) = '0' then
            --if a branch without annul flag then delay instruction
            --should not be annuled
            mem_delay_no_annul := '1';
          end if;
          if r.m.ctrl.inst(1)(29) = '1' then
            if r.m.ctrl.br_taken = '0' and is_branch_unc(r.m.ctrl.inst(1)) = '0' then
              --branch annul was in fact taken hence delay instruction
              --should not be annuled
              mem_delay_no_annul := '1';
              if r.m.ctrl.br_dual_ld = '1' then
                mem_delay_no_annul := '0';
                mem_ld_recover     := '1';
              end if;
            else
              --branch annul and branch was in fact taken hence delay
              --instrucion should be annuled
              mem_delay_annul := '1';
            end if;
          end if;
        else
          --branch predicted correctly
          if r.m.ctrl.inst(1)(29) = '1' then
            --branch annul instruction
            if r.m.ctrl.br_taken = '0' or is_branch_unc(r.m.ctrl.inst(1)) = '1' then
              --branch is not taken or BA
              --hence delay instruction should be annuled
              mem_delay_annul := '1';
              --delay slot instruction of a branch annul in memory stage
              --will always be in a previous stage
            end if;
          end if;
        end if;
      end if;
    end if;

    if xc_br_miss = '1' then
      mem_delay_no_annul := '0';
    end if;

    if mem_delay_annul = '1' then
      if mem_br_lane = '0' and r.m.ctrl.swap = '0' then
        if r.m.ctrl.delay_inst(1) = '1' and r.m.ctrl.inst_valid(1) = '1' then
          v.x.ctrl.inst_valid(1) := '0';
          mem_delay_annul        := '0';
          mem_delay_annuled      := '1';
          mem_delay_annuled_lane := '1';
        end if;
      end if;

      if mem_br_lane = '1' and r.m.ctrl.swap = '1' then
        if r.m.ctrl.delay_inst(0) = '1' and r.m.ctrl.inst_valid(0) = '1' then
          v.x.ctrl.inst_valid(0) := '0';
          mem_delay_annul        := '0';
          me_nullify2            := '1';
          mem_delay_annuled      := '1';
        end if;
      end if;
    end if;

    if mem_delay_no_annul = '1' then
      if mem_br_lane = '0' and r.m.ctrl.swap = '0' then
        if r.m.ctrl.delay_inst(1) = '1' and r.m.ctrl.inst_valid(1) = '1' then
          mem_delay_no_annul        := '0';
          v.x.ctrl.delay_annuled(1) := '0';
          if is_wicc(r.m.ctrl.inst(1)) = '1' and r.m.ctrl.delay_annuled(1) = '1' then
            --if dmem and dexc is 0 it means wicc was calculated in execute stage
            --and stored in r.m.icc_dannul
            if r.m.ctrl.wicc_dmem = '0' and r.m.ctrl.wicc_dexc = '0' then
              --if wicc_dmem is '1' then wicc_mem_overwrite will write the
              --correct value
              v.x.icc         := r.m.icc_dannul;
              icc_overwrite_m := '1';
            end if;
          end if;
        end if;
      end if;

      if mem_br_lane = '1' and r.m.ctrl.swap = '1' then
        if r.m.ctrl.delay_inst(0) = '1' and r.m.ctrl.inst_valid(0) = '1' then
          v.x.ctrl.delay_annuled(0) := '0';
          mem_delay_no_annul        := '0';
        end if;
      end if;
    end if;

    --can happen due to hold issue
    if xc_delay_annul = '1' and mem_delay_annuled = '0' then
      mem_delay_annul := '1';
    end if;

    if xc_delay_no_annul = '1' then
      mem_delay_no_annul := '1';
    end if;

    gen_stdata(r, r.m.iustdata, r.m.fpdata, me_edata);

    debug_read := '0';
    if (DBGUNIT and (r.x.rstate = dsu2)) then
      debug_read := '1';
    end if;

    if ((is_load(r.m.ctrl.inst(0)) and r.m.ctrl.inst_valid(0)) or not dco.mds or debug_read) = '1' then
      for i in 0 to dways-1 loop
        v.x.data(i) := dco.data(i);
      end loop;
      v.x.way := dco.way(DWAYMSB downto 0);
      if dco.mds = '0' then
        me_size   := r.x.dci.size;
        me_laddr  := r.x.laddr;
        me_signed := r.x.dci.signed;
        me_rd     := r.x.ctrl.rd(0)(RFBITS-1 downto 0);
        --me_rd := r.x.ctrl.inst(0)(29 downto 25);
        me_cpld   := r.x.ctrl.inst(0)(24);
      else
        me_size   := v.x.dci.size;
        me_laddr  := v.x.laddr;
        me_signed := v.x.dci.signed;
        me_rd     := r.x.ctrl.rd(0)(RFBITS-1 downto 0);
        --me_rd := r.m.ctrl.inst(0)(29 downto 25);
        me_cpld   := r.m.ctrl.inst(0)(24);
      end if;
      v.x.data(0) := ld_align_fast(v.x.data, v.x.way, me_size, me_laddr, me_signed, me_rd, me_cpld, r.m.dci.dsuen);
      --else
      --  v.x.data(0) := me_edata;
    end if;

    v.x.mexc      := dco.mexc;
    v.x.storedata := me_edata;

    v.x.speculative_load := '0';
    if v.x.ctrl.inst_valid(0) = '1' and is_load(r.m.ctrl.inst(0)) = '1' and v.x.ctrl.branch(1) = '1' and v.x.ctrl.inst_valid(1) = '1' and v.x.ctrl.inst(1)(29) = '1' and r.m.ctrl.swap = '1' then
      v.x.speculative_load := '1';
    end if;


    ---------------------------------------------------------------------------
    -- LATE ALUcc (MEM)
    ---------------------------------------------------------------------------
    forwarding_mux_mem_stage(r,
                             mem_lalu_l0_op1,
                             mem_lalu_l0_op2,
                             mem_lalu_l1_op1,
                             mem_lalu_l1_op2);

    --LANE0 generate result to dual issue ALU/ALUcc (late arith) operations
    --when first ALU has late alu dependency, the result is only used for ALUcc
    --and not forwarded anywhere else in order to not impact forwarding path
    --Only add/sub and logic operations are used to reduce area overhead
    
    mem_add_res0 := (mem_lalu_l0_op1 & '1') + (mem_lalu_l0_op2 & r.m.alu_ctrl.alucin(0));
    logic_op_exc(r, r.m.alu_ctrl.aluop(0), mem_lalu_l0_op1, mem_lalu_l0_op2, mem_logic_res_alu0);
    alu_select_nocc_mem(r, mem_add_res0, mem_logic_res_alu0, mem_res_alu0);

    --LANE1 CC calculation
    mem_add_res   := (mem_lalu_l1_op1 & '1') + (mem_lalu_l1_op2 & r.m.alu_ctrl.alucin(1));
    logic_op_exc(r, r.m.alu_ctrl.aluop(1), mem_lalu_l1_op1, mem_lalu_l1_op2, mem_logic_res);
    mem_shift_res := (others => '0');
    alu_select_exc(r, r.m.alu_ctrl.alusel(1), r.m.alu_ctrl.aluadd(1), mem_add_res, mem_lalu_l1_op1, mem_lalu_l1_op2, mem_logic_res, mem_shift_res, mem_icc, res_mem_temp);

    wicc_mem_overwrite := (r.m.ctrl.wicc_dmem or r.m.ctrl.wicc_muldiv) and v.x.ctrl.inst_valid(1) and not v.x.ctrl.delay_annuled(1) and not v.x.annul_all;
    v.x.icc_prev       := r.w.s.icc;

    --delayed annuled icc must not modify the v.m.icc
    --but it can resolved to be not delay annuled
    --in that case correct value of icc is retrieved
    --from icc_dannul
    v.x.icc_dannul := r.m.icc_dannul;
    if r.m.ctrl.wicc_dmem = '1' then
      --icc_dannul value is caluclated in mem stage
      v.x.icc_dannul := mem_icc;
    end if;

    --mul/div cc
    if wr_icc(1) = '1' then
      mem_icc := me_icc_l(1);
    end if;

    --there can not be mul and div instructions in parallel
    for i in 0 to 1 loop
      if wr_y(i) = '1' and v.x.ctrl.inst_valid(i) = '1' then
        v.x.y := v_x_y_l(i);
      end if;
      if wr_asr(i) = '1' then
        me_asr18 := me_asr18_l(i);
      end if;
    end loop;

    v.x.icc := r.m.icc;
    if icc_overwrite_m = '1' then
      v.x.icc := r.m.icc_dannul;
    elsif wicc_mem_overwrite = '1' then
      v.x.icc := mem_icc;
    elsif wicc_exc_overwrite = '1' and (r.m.ctrl.wicc = '0' or r.m.ctrl.inst_valid(1) = '0' or r.m.ctrl.delay_annuled(1) = '1') then
      v.x.icc := exc_icc;
    end if;
    v.x.ctrl.wicc      := r.m.ctrl.wicc and not v.x.annul_all;
    v.x.ctrl.wicc_dexc := r.m.ctrl.wicc_dexc and not v.x.annul_all;

    --v.x.late_wicc_alucin := r.m.late_wicc_alucin;
    v.x.late_wicc_rs1 := r.m.late_wicc_rs1;
    v.x.late_wicc_rs2 := r.m.late_wicc_rs2;

    forwarding_unit_late_alu(v, r, 0, exc_res(0), exc_res(1), mem_res_alu0, v.x.alu_op1(0), v.x.alu_op2(0), v.x.ldfwd(0), v.x.multfwd(0), v.x.alu_ctrl.sari(0), v.x.alu_ctrl.shcnt(0));
    forwarding_unit_late_alu(v, r, 1, exc_res(0), exc_res(1), mem_res_alu0, v.x.alu_op1(1), v.x.alu_op2(1), v.x.ldfwd(1), v.x.multfwd(1), v.x.alu_ctrl.sari(1), v.x.alu_ctrl.shcnt(1));

    me_nullify2 := me_nullify2 or atomic_nullify_s or v.x.annul_all;

    if (r.x.rstate = dsu2) then
      me_nullify2 := '0';
      v.x.way     := dco.way(DWAYMSB downto 0);
    end if;

    mem_jmpl_rett_op := '0';
    if (r.m.ctrl.jmpl_op = '1' or r.m.ctrl.rett_op = '1') and r.m.ctrl.inst_valid(1) = '1' and r.m.ctrl.trap(1) = '0' then
      mem_jmpl_rett_op := '1';
    end if;

    v.x.bht_ctrl.phistory := bhto.phistory;
    if dco.iuctrl.staticbp = '1' or BPRED = '0' then
      v.x.bht_ctrl.phistory := (others=>'0');
    end if;

    
    dci.maddress      <= r.m.result(0);
    dci.enaddr        <= r.m.dci.enaddr;
    dci.asi           <= r.m.dci.asi;
    dci.size          <= r.m.dci.size;
    dci.nullify       <= me_nullify2;
    dci.lock          <= r.m.dci.lock;  --r.m.dci.lock and not r.m.ctrl.annul;
    dci.read          <= r.m.dci.read;
    dci.write         <= r.m.dci.write;
    dci.flush         <= me_iflush;
    dci.dsuen         <= r.m.dci.dsuen;
    dci.msu           <= r.m.su;
    dci.esu           <= r.e.su;
    dci.edata         <= me_edata;
    dci.specread      <= v.x.speculative_load;
    dci.specreadannul <= specreadannul;

    if (not ASYNC_RESET) and (not RESET_ALL) and (xc_rstn = '0') then
      v.x.ctrl := pipeline_ctrl_none;
    end if;


    
    if dco.badtag = '1' then
      v.x.ctrl.trap(0) := '1';
      v.x.ctrl.tt(0)   := TT_IINST;
    end if;

    v.x.tt_ticc := '0';
    if v.x.ctrl.tt(0) = TT_TICC then
      v.x.tt_ticc := '1';
    end if;

-------------------------------------------------------------------------------
-- LEON5 Execute STAGE
-------------------------------------------------------------------------------
    v.m.ctrl     := r.e.ctrl;
    v.m.rs1      := r.e.rs1;
    v.m.rs2      := r.e.rs2;
    v.m.rs3      := r.e.rs3;
    v.m.su       := r.e.su;
    v.m.bht_ctrl := r.e.bht_ctrl;
    v.m.fpc_ctrl := r.e.fpc_ctrl;
    v.m.itrhit   := r.e.itrhit;
    ex_ymsb      := r.e.ymsb(1);

    if r.e.ctrl.inst_valid /= "11" then
      if is_atomic(r.e.ctrl.inst(0)) = '0' then
        v.m.ctrl.no_forward := "00";
      end if;
    end if;

    exe_delay_annuled      := '0';
    exe_delay_annuled_lane := '0';
    if mem_delay_annul = '1' then
      --there can be only 1 delay instruction in two lanes
      if r.e.ctrl.delay_inst(0) = '1' and r.e.ctrl.inst_valid(0) = '1' then
        v.m.ctrl.inst_valid(0) := '0';
        exe_delay_annuled      := '1';
      elsif r.e.ctrl.delay_inst(1) = '1' and r.e.ctrl.inst_valid(1) = '1' then
        v.m.ctrl.inst_valid(1) := '0';
        exe_delay_annuled      := '1';
        exe_delay_annuled_lane := '1';
      end if;
    end if;

    
    if mem_br_miss = '1' or xc_br_miss = '1' then
      if r.e.ctrl.delay_inst(0) = '1' and r.e.ctrl.inst_valid(0) = '1' then
        if mem_delay_no_annul = '0' then
          v.m.ctrl.inst_valid(0) := '0';
        else
          v.m.ctrl.delay_annuled(0) := '0';
        end if;
        mem_delay_no_annul := '0';
      else
        v.m.ctrl.inst_valid(0) := '0';
      end if;
      if r.e.ctrl.delay_inst(1) = '1' and r.e.ctrl.inst_valid(1) = '1' then
        if mem_delay_no_annul = '0' then
          v.m.ctrl.inst_valid(1) := '0';
        else
          v.m.ctrl.delay_annuled(1) := '0';
        end if;
        mem_delay_no_annul := '0';
      else
        v.m.ctrl.inst_valid(1) := '0';
      end if;
    end if;

    if v.x.annul_all = '1' then
      v.m.ctrl.inst_valid := "00";
    end if;

    ex_op1   := r.e.ex_op1;
    ex_op2   := r.e.ex_op2;
    ex_shcnt := r.e.alu_ctrl.shcnt;
    ex_sari  := r.e.alu_ctrl.sari;

    --forwarding from the memory stage 
    for i in 0 to 1 loop
      if r.e.ldfwd_rs1(i) = '1' then
        if r.e.rs1(i)(0) = '0' then
          ex_op1(i) := r.x.data(0)(63 downto 32);
        else
          ex_op1(i) := r.x.data(0)(31 downto 0);
        end if;
      end if;
      ex_op1_mul(i) := ex_op1(i);
      if r.e.use_muldiv_rs1(i) = '1' then
        ex_op1(i) := r.x.muldiv_result;
      end if;

      if r.e.ldfwd_rs1(i) = '1' or r.e.use_muldiv_rs1(i) = '1' then
        ex_sari(i) := ex_op1(i)(31) and r.e.ctrl.inst(i)(19) and r.e.ctrl.inst(i)(20);
      end if;

      --later merge r.a.casa = '1' and ldfwd_rs2 to reduce critical path
      if r.e.ldfwd_rs2(i) = '1' or (i = 1 and r.a.casa = '1') then
        if r.e.rs2(i)(0) = '0' then
          ex_op2(i) := r.x.data(0)(63 downto 32);
        else
          ex_op2(i) := r.x.data(0)(31 downto 0);
        end if;
      end if;
      ex_op2_mul(i) := ex_op2(i);
      if r.e.use_muldiv_rs2(i) = '1' then
        ex_op2(i) := r.x.muldiv_result;
      end if;

      if r.e.ldfwd_rs2(i) = '1' or (i = 1 and r.a.casa = '1') or r.e.use_muldiv_rs2(i) = '1' then
        ex_shcnt(i) := ex_op2(i)(4 downto 0);
      end if;
      
    end loop;

    for i in 0 to 1 loop
      if r.e.alu_ctrl.invop2(i) = '1' and (r.e.ldfwd_rs2(i) = '1' or r.e.use_muldiv_rs2(i) = '1') then
        ex_op2(i)   := not(ex_op2(i));
        ex_shcnt(i) := not(ex_shcnt(i));  
      end if;
    end loop;

    
    --forwarding for multiplier
    mul_op1_muxed := r.e.mul_op1;
    mul_op2_muxed := r.e.mul_op2;

    if r.e.ldfwd_tomul_rs1 = '1' then
      mul_op1_muxed := r.x.data(0)(63 downto 32);
      if r.e.mul_rs10 = '1' then
        mul_op1_muxed := r.x.data(0)(31 downto 0);
      end if;
    end if;

    if r.e.ldfwd_tomul_rs2 = '1' then
      mul_op2_muxed := r.x.data(0)(63 downto 32);
      if r.e.mul_rs20 = '1' then
        mul_op2_muxed := r.x.data(0)(31 downto 0);
      end if;
    end if;


    v.m.late_wicc_rs1 := r.e.rs1(1);
    v.m.late_wicc_rs2 := r.e.rs2(1);
    v.m.alu_op1(0)    := ex_op1(0);
    v.m.alu_op2(0)    := ex_op2(0);
    v.m.alu_op1(1)    := ex_op1(1);
    v.m.alu_op2(1)    := ex_op2(1);

    v.m.alu_ctrl       := r.e.alu_ctrl;
    v.m.alu_ctrl.shcnt := ex_shcnt;
    v.m.alu_ctrl.sari  := ex_sari;

    v.m.late_wicc_op1_ldfwd := '0';
    v.m.late_wicc_op2_ldfwd := '0';
    v.m.late_wicc_op1_lalu0 := '0';
    v.m.late_wicc_op1_lalu1 := '0';
    v.m.late_wicc_op2_lalu0 := '0';
    v.m.late_wicc_op2_lalu1 := '0';
    v.m.lalu0_ldfwd_rs1     := '0';
    v.m.lalu0_ldfwd_rs2     := '0';
    v.m.lalu0_wb0fwd_rs1    := '0';
    v.m.lalu0_wb0fwd_rs2    := '0';
    v.m.lalu0_wb1fwd_rs1    := '0';
    v.m.lalu0_wb1fwd_rs2    := '0';
    if v.w.we(0) /= "00" and (r.x.ctrl.rd(0) = r.e.rs1(1)) and r.x.ctrl.alu_dexc(0) = '1' then
      v.m.late_wicc_op1_lalu0 := '1';
    end if;
    if v.w.we(1) /= "00" and (r.x.ctrl.rd(1) = r.e.rs1(1)) and r.x.ctrl.alu_dexc(1) = '1' then
      v.m.late_wicc_op1_lalu1 := '1';
    end if;
    if v.w.we(0) /= "00" and (r.x.ctrl.rd(0) = r.e.rs1(0)) and r.x.ctrl.alu_dexc(0) = '1' then
      v.m.lalu0_wb0fwd_rs1 := '1';
    end if;
    if v.w.we(1) /= "00" and (r.x.ctrl.rd(1) = r.e.rs1(0)) and r.x.ctrl.alu_dexc(1) = '1' then
      v.m.lalu0_wb1fwd_rs1 := '1';
    end if;
    if is_load_int(r.m.ctrl.inst(0)) = '1' and r.m.ctrl.inst_valid(0) = '1' and r.m.ctrl.no_forward(0) = '0' and r.m.ctrl.delay_annuled(0) = '0' then
      if (r.m.ctrl.rd(0) = r.e.rs1(1)) then
        v.m.late_wicc_op1_ldfwd := '1';
      end if;
      if is_ldd_int(r.m.ctrl.inst(0)) = '1' then
        if r.m.ctrl.rd(0)(RFBITS downto 1) = r.e.rs1(1)(RFBITS downto 1) then
          v.m.late_wicc_op1_ldfwd := '1';
        end if;
      end if;
      if r.m.ctrl.ldd_z = '1' and r.e.rs1(1)(0) = '0' then
        v.m.late_wicc_op1_ldfwd := '0';
      end if;

      if (r.m.ctrl.rd(0) = r.e.rs1(0)) then
        v.m.lalu0_ldfwd_rs1 := '1';
      end if;
      if is_ldd_int(r.m.ctrl.inst(0)) = '1' then
        if r.m.ctrl.rd(0)(RFBITS downto 1) = r.e.rs1(0)(RFBITS downto 1) then
          v.m.lalu0_ldfwd_rs1 := '1';
        end if;
      end if;
      if r.m.ctrl.ldd_z = '1' and r.e.rs1(0)(0) = '0' then
        v.m.lalu0_ldfwd_rs1 := '0';
      end if;
    end if;

    if v.w.we(0) /= "00" and (r.x.ctrl.rd(0) = r.e.rs2(1)) and r.x.ctrl.alu_dexc(0) = '1' then
      v.m.late_wicc_op2_lalu0 := '1';
    end if;
    if v.w.we(1) /= "00" and (r.x.ctrl.rd(1) = r.e.rs2(1)) and r.x.ctrl.alu_dexc(1) = '1' then
      v.m.late_wicc_op2_lalu1 := '1';
    end if;
    if v.w.we(0) /= "00" and (r.x.ctrl.rd(0) = r.e.rs2(0)) and r.x.ctrl.alu_dexc(0) = '1' then
      v.m.lalu0_wb0fwd_rs2 := '1';
    end if;
    if v.w.we(1) /= "00" and (r.x.ctrl.rd(1) = r.e.rs2(0)) and r.x.ctrl.alu_dexc(1) = '1' then
      v.m.lalu0_wb1fwd_rs2 := '1';
    end if;

    if is_load_int(r.m.ctrl.inst(0)) = '1' and r.m.ctrl.inst_valid(0) = '1' and r.m.ctrl.no_forward(0) = '0' and r.m.ctrl.delay_annuled(0) = '0' then
      if r.m.ctrl.rd(0) = r.e.rs2(1) then
        v.m.late_wicc_op2_ldfwd := '1';
      end if;
      if is_ldd_int(r.m.ctrl.inst(0)) = '1' then
        if r.m.ctrl.rd(0)(RFBITS downto 1) = r.e.rs2(1)(RFBITS downto 1) then
          v.m.late_wicc_op2_ldfwd := '1';
        end if;
      end if;
      if r.m.ctrl.ldd_z = '1' and r.e.rs2(1)(0) = '0' then
        v.m.late_wicc_op2_ldfwd := '0';
      end if;

      if (r.m.ctrl.rd(0) = r.e.rs2(0)) then
        v.m.lalu0_ldfwd_rs2 := '1';
      end if;
      if is_ldd_int(r.m.ctrl.inst(0)) = '1' then
        if r.m.ctrl.rd(0)(RFBITS downto 1) = r.e.rs2(0)(RFBITS downto 1) then
          v.m.lalu0_ldfwd_rs2 := '1';
        end if;
      end if;
      if r.m.ctrl.ldd_z = '1' and r.e.rs2(0)(0) = '0' then
        v.m.lalu0_ldfwd_rs2 := '0';
      end if;
    end if;

    ex_add_res(0) := (ex_op1(0) & '1') + (ex_op2(0) & r.e.alu_ctrl.alucin(0));

    --  ex_mem_address := ex_op1(0) + ex_op2(0);
    ex_mem_address := ex_add_res(0)(32 downto 1);

    logic_op1_alu0 := ex_op1(0);
    if r.e.alu_ctrl.use_sethi(0) = '1' then
      logic_op1_alu0 := ex_op2(1);
    end if;

    logic_op2_alu0 := ex_op2(0);
    if r.e.alu_ctrl.use_sethi(1) = '1' then
      logic_op2_alu0 := ex_op2(1);
    end if;

    if r.e.alu_ctrl.use_logic(0) = '1' then
      logic_op1_alu0 := ex_logic_res1_s;
    end if;

    if r.e.alu_ctrl.use_logic(1) = '1' then
      logic_op2_alu0 := ex_logic_res1_s;
    end if;

    if r.e.alu_ctrl.use_addsub(0) = '1' then
      logic_op1_alu0 := ex_add_res1_s;
    end if;

    if r.e.alu_ctrl.use_addsub(1) = '1' then
      logic_op2_alu0 := ex_add_res1_s;
    end if;

    shift_op1_alu0 := ex_op1(0);
    if r.e.alu_ctrl.use_logicshift = '1' then
      shift_op1_alu0 := ex_logic_res1_s;
      ex_sari(0)     := shift_op1_alu0(31) and r.e.ctrl.inst(0)(19) and r.e.ctrl.inst(0)(20);
    end if;

    --ALU0
    --LANE0 -> ALU/MUL/DIV/LDST
    ex_add_res(0)   := (ex_op1(0) & '1') + (ex_op2(0) & r.e.alu_ctrl.alucin(0));
    logic_op(r, 0 , logic_op1_alu0, logic_op2_alu0, v.x.y, ex_ymsb, ex_logic_res(0), v.m.y);
    ex_shift_res(0) := shift(r.e.alu_ctrl.shleft(0), shift_op1_alu0, ex_op2(0), ex_shcnt(0), ex_sari(0));
    misc_op(r, 0, wpr, ex_op1(0), ex_op2(0), xc_df_result, v.x.y, ex_misc_res(0));
    alu_select_nocc(0, r, ex_add_res(0), ex_shift_res(0), ex_logic_res(0),
                    ex_misc_res(0), ex_result(0));

    v.m.result(0) := ex_result(0);

    ex_add_res(1)   := (ex_op1(1) & '1') + (ex_op2(1) & r.e.alu_ctrl.alucin(1));
    ex_add_res1_s   <= ex_add_res(1)(32 downto 1);
    ex_jump_address := ex_op1(1) + ex_op2(1);
    v_x_trap        := ((v.x.ctrl.trap(0) and v.x.ctrl.inst_valid(0)) or (v.x.ctrl.trap(1) and v.x.ctrl.inst_valid(1))) and (not v.x.annul_all);

    if r.e.use_memaddr_add1 = '1' then
      ex_mem_address := ex_add_res(1)(32 downto 1);
      v.m.result(0)  := ex_mem_address;
    end if;

    --ALU1
    --LANE1 -> ALUcc/MUL/DIV
    ex_add_res(1)   := (ex_op1(1) & '1') + (ex_op2(1) & r.e.alu_ctrl.alucin(1));
    logic_op(r, 1, ex_op1(1), ex_op2(1), v.x.y, ex_ymsb, ex_logic_res(1), y_unused);
    ex_shift_res(1) := shift(r.e.alu_ctrl.shleft(1), ex_op1(1), ex_op2(1), ex_shcnt(1), ex_sari(1));
    misc_op(r, 1, wpr, ex_op1(1), ex_op2(1), xc_df_result, v.x.y, ex_misc_res(1));
    alu_select(1, v_m, r, ex_add_res(1), ex_op1(1), ex_op2(1), ex_shift_res(1), ex_logic_res(1),
               ex_misc_res(1), ex_result(1), me_icc, v.m.icc, v.m.icc_dannul, v.m.divz, v.m.casz);

    v.m.result(1)   := ex_result(1);
    ex_logic_res1_s <= ex_logic_res(1);

    if (r.e.ctrl.wicc = '0' or v.m.ctrl.inst_valid(1) = '0' or r.e.ctrl.delay_annuled(1) = '1' or r.e.ctrl.wicc_dmem = '1' or r.e.ctrl.wicc_dexc = '1' or r.e.ctrl.wicc_muldiv = '1') then
      if icc_overwrite_m = '1' then
        v.m.icc := r.m.icc_dannul;
      elsif wicc_mem_overwrite = '1' then
        v.m.icc := mem_icc;
      elsif icc_overwrite_w = '1' then
        v.m.icc := r.w.icc_dannul;
      elsif wicc_exc_overwrite = '1' and (r.m.ctrl.wicc = '0' or v.x.ctrl.inst_valid(1) = '0' or r.m.ctrl.delay_annuled(1) = '1') then
        v.m.icc := exc_icc;
      end if;
    end if;

    v.m.nalign := '0';
    if ex_jump_address(1 downto 0) /= "00" then
      v.m.nalign := '1';
    end if;

    cin_gen(0, r, v.m.icc(0), v.e.alu_ctrl.alucin(0));
    cin_gen(1, r, v.m.icc(0), v.e.alu_ctrl.alucin(1));

    v.m.jmpl_taddr := ex_jump_address;

    cwp_ex(r.e.ctrl.inst(0), v.m.ctrl.inst_valid(0), v.m.wcwp(0));
    cwp_ex(r.e.ctrl.inst(1), v.m.ctrl.inst_valid(1), v.m.wcwp(1));

    exe_br_miss        := '0';
    exe_br_lane        := '0';
    exe_delay_annul    := '0';
    exe_delay_no_annul := '0';
    exe_br_miss_pc     := r.e.bht_ctrl.br_miss_pc;
    wicc_mem_delayed   := r.m.ctrl.wicc_dexc or r.m.ctrl.wicc_dmem or r.m.ctrl.wicc_muldiv;
    v.m.ctrl.br_missp  := '0';
    exe_ld_recover     := '0';

    exe_branch_l0_resolve := not((r.e.ctrl.swap and r.e.ctrl.wicc and r.e.ctrl.inst_valid(1))
                                 or (r.m.ctrl.inst_valid(1) and wicc_mem_delayed)
                                 or (r.x.ctrl.inst_valid(1) and r.x.ctrl.wicc_dexc));
    if FPEN and (is_fpu_branch(r.e.ctrl.inst(0))) = '1' then
      exe_branch_l0_resolve := '1';
    end if;

    exe_branch_l0_misspredict := branch_mispredict(r.m.icc, r.e.ctrl.inst(0), r.e.ctrl.br_taken);
    if FPEN and (is_fpu_branch(r.e.ctrl.inst(0))) = '1' then
      exe_branch_l0_misspredict := branch_mispredict_fpu(fpu5o.fcc, r.e.ctrl.inst(0), r.e.ctrl.br_taken);
    end if;

    if r.e.ctrl.branch(0) = '1' and r.e.ctrl.inst_valid(0) = '1' and r.e.ctrl.trap(0) = '0' then
      if exe_branch_l0_resolve = '1' then
        --condition flag will not be moidifed hence branch can be evaluated
        --in this stage
        v.m.ctrl.branch(0) := '0';
        if exe_branch_l0_misspredict = '1' then
          --branch misspredicted
          v.m.ctrl.br_missp := '1';
          v.m.ctrl.br_taken := not(r.e.ctrl.br_taken);  -- correct for BHT
          exe_br_miss       := '1';
          if r.e.ctrl.inst(0)(29) = '0' then
            --if a branch without annul flag then delay instruction
            --should not be annuled
            exe_delay_no_annul := '1';
          end if;
          if r.e.ctrl.inst(0)(29) = '1' then
            if r.e.ctrl.br_taken = '0' and is_branch_unc(r.e.ctrl.inst(0)) = '0' then
              --branch annul was in fact taken hence delay instruction
              --should not be annuled
              exe_delay_no_annul := '1';
              if r.e.ctrl.br_dual_ld = '1' then
                exe_delay_no_annul := '0';
                exe_ld_recover     := '1';
              end if;
            else
              --branch annul and branch is in fact not taken hence delay
              --instruction should be annuled
              exe_delay_annul := '1';
            end if;
          end if;
        else
          --branch predicted correctly
          if r.e.ctrl.inst(0)(29) = '1' then
            --branch annul instruction
            if r.e.ctrl.br_taken = '0' or is_branch_unc(r.e.ctrl.inst(0)) = '1' then
              --branch is not taken or BA
              --hence delay instruction should be annuled
              exe_delay_annul := '1';
              --delay slot instruction of a branch annul in memory stage
              --will always be in a previous stage
            end if;
          end if;
        end if;
      end if;
    end if;
    
    exe_branch_l1_resolve := not((r.m.ctrl.inst_valid(1) and wicc_mem_delayed)
                                   or (r.x.ctrl.inst_valid(1) and r.x.ctrl.wicc_dexc));
    if FPEN and (is_fpu_branch(r.e.ctrl.inst(1))) = '1' then
      exe_branch_l1_resolve := '1';
    end if;

    exe_branch_l1_misspredict := branch_mispredict(r.m.icc, r.e.ctrl.inst(1), r.e.ctrl.br_taken);
    if FPEN and (is_fpu_branch(r.e.ctrl.inst(1))) = '1' then
      exe_branch_l1_misspredict := branch_mispredict_fpu(fpu5o.fcc, r.e.ctrl.inst(1), r.e.ctrl.br_taken);
    end if;

    if r.e.ctrl.branch(1) = '1' and r.e.ctrl.inst_valid(1) = '1' and r.e.ctrl.trap(1) = '0' then
      if exe_branch_l1_resolve = '1' then
        exe_br_lane        := '1';
        --condition flag will not be moidifed hence branch can be evaluated
        --in this stage
        v.m.ctrl.branch(1) := '0';
        if exe_branch_l1_misspredict = '1' then
          --branch misspredicted
          v.m.ctrl.br_missp := '1';
          v.m.ctrl.br_taken := not(r.e.ctrl.br_taken);  -- correct for BHT
          exe_br_miss       := '1';
          if r.e.ctrl.inst(1)(29) = '0' then
            --if a branch without annul flag then delay instruction
            --should not be annuled
            exe_delay_no_annul := '1';
          end if;
          if r.e.ctrl.inst(1)(29) = '1' then
            if r.e.ctrl.br_taken = '0' and is_branch_unc(r.e.ctrl.inst(1)) = '0' then
              --branch annul was in fact taken hence delay instruction
              --should not be annuled
              exe_delay_no_annul := '1';
              if r.e.ctrl.br_dual_ld = '1' then
                exe_delay_no_annul := '0';
                exe_ld_recover     := '1';
              end if;
            else
              --branch annul and branch was in fact not taken hence delay
              --instruction should be annuled
              exe_delay_annul := '1';
            end if;
          end if;
        else
          --branch predicted correctly
          if r.e.ctrl.inst(1)(29) = '1' then
            --branch annul instruction
            if r.e.ctrl.br_taken = '0' or is_branch_unc(r.e.ctrl.inst(1)) = '1' then
              --branch is not taken or BA
              --hence delay instruction should be annuled
              exe_delay_annul := '1';
              --delay slot instruction of a branch annul in memory stage
              --will always be in a previous stage
            end if;
          end if;
        end if;
      end if;
    end if;

    exe_rett_ct := '0';
    if (r.e.ctrl.rett_op = '1' and r.e.ctrl.inst_valid(1) = '1' and r.e.ctrl.trap(1) = '0') then
      exe_rett_ct    := '1';
      exe_br_miss_pc := v.m.jmpl_taddr;
    end if;

    exe_jmpl_ct := '0';
    if (r.e.ctrl.jmpl_op = '1' and r.e.ctrl.inst_valid(1) = '1' and r.e.ctrl.trap(1) = '0') then
      exe_jmpl_ct    := '1' and not(exe_rett_ct);
      exe_br_miss_pc := v.m.jmpl_taddr;
    end if;


    if mem_br_miss = '1' or xc_br_miss = '1' then
      exe_delay_no_annul := '0';
    end if;

    if exe_delay_annul = '1' then
      if exe_br_lane = '0' and r.e.ctrl.swap = '0' then
        if r.e.ctrl.delay_inst(1) = '1' and r.e.ctrl.inst_valid(1) = '1' then
          v.m.ctrl.inst_valid(1) := '0';
          exe_delay_annul        := '0';
          exe_delay_annuled      := '1';
          exe_delay_annuled_lane := '1';
        end if;
      end if;

      if exe_br_lane = '1' and r.e.ctrl.swap = '1' then
        if r.e.ctrl.delay_inst(0) = '1' and r.e.ctrl.inst_valid(0) = '1' then
          v.m.ctrl.inst_valid(0) := '0';
          exe_delay_annul        := '0';
          exe_delay_annuled      := '1';
        end if;
      end if;
    end if;

    if exe_delay_no_annul = '1' then
      if exe_br_lane = '0' and r.e.ctrl.swap = '0' then
        if r.e.ctrl.delay_inst(1) = '1' and r.e.ctrl.inst_valid(1) = '1' then
          exe_delay_no_annul        := '0';
          v.m.ctrl.delay_annuled(1) := '0';
        end if;
      end if;

      if exe_br_lane = '1' and r.e.ctrl.swap = '1' then
        if r.e.ctrl.delay_inst(0) = '1' and r.e.ctrl.inst_valid(0) = '1' then
          exe_delay_no_annul        := '0';
          v.m.ctrl.delay_annuled(0) := '0';
        end if;
      end if;
    end if;

    if mem_delay_no_annul = '1' then
      exe_delay_no_annul := '1';
    end if;

    if r.e.call_op = "10" then
      if (r.e.call_lane = '0' and r.e.ctrl.inst_valid(0) = '1') or
        (r.e.call_lane = '1' and r.e.ctrl.inst_valid(1) = '1') then
        --this happens when a call is in the delay slot of a CTI
        exe_br_miss := '1';
      end if;
    end if;

    --bypass for ALUcc in memory stage
    --no_forward is not checked here beucase there can be a real dependence
    --between two
    if r.e.ctrl.wicc_dmem = '1' and r.e.ctrl.swap = '0' and r.e.ctrl.inst_valid(0) = '1' and r.e.ctrl.rdw(0) = '1' and r.e.ctrl.delay_annuled(0) = '0' then
      if r.e.ctrl.rd(0) = r.e.rs1(1) then
        v.m.alu_op1(1)          := ex_result(0);
        v.m.late_wicc_op1_ldfwd := '0';
      end if;
      if r.e.ctrl.rd(0) = r.e.rs2(1) then
        v.m.alu_op2(1) := ex_result(0);
        if r.e.alu_ctrl.invop2(1) = '1' then
          v.m.alu_op2(1) := not(ex_result(0));
        end if;
        v.m.late_wicc_op2_ldfwd := '0';
      end if;
    end if;

    dcache_gen(r, v_x_trap , v.m.ctrl.inst_valid(0), ex_dci);
    dbg_cache(holdn, dbgi, r, dsur, v.m.result(0), ex_dci, v_m_result0, v.m.dci);

    v.m.dc_nullify := '0';
    if r.a.astate /= idle and r.a.astate /= ld_exc then
      if r.e.ctrl.inst_valid(0) = '1' and v.m.ctrl.inst_valid(0) = '0' and v.m.dci.enaddr = '1' then
        v.m.dc_nullify := '1';
      end if;
    end if;

    v.m.result(0) := v_m_result0;
    dci.easi      <= v.m.dci.asi;
    dci.eenaddr   <= v.m.dci.enaddr;
    dci.eread     <= ex_dci.read;
    dci.eaddress  <= ex_mem_address;
    gen_exstdata(r, r.e.iustdata, exstdata_fwd, v.m.iustdata,
                 v.m.mem_data_alu1, v.m.mem_data_xdataH, v.m.mem_data_xdataL,
                 v.m.mem_data_xresult0, v.m.mem_data_lalu0, v.m.mem_data_lalu1
                 );





    if is_fpu_store(r.e.ctrl.inst(0)) = '1' and FPEN then
      v.m.iustdata := r.e.iustdata;
    end if;

    if mem_delay_annul = '1' and exe_delay_annuled = '0' then
      --this can happen due to bubbles in the pipeline
      exe_delay_annul := '1';
    end if;

    v_m <= v;

-------------------------------------------------------------------------------
-- LEON5 Register Access STAGE
-------------------------------------------------------------------------------
    pccompare(0, r, wpr, pccomp(0));
    pccompare(1, r, wpr, pccomp(1));

    v.e.itrhit(0) := itrhitc(r,pccomp(0));
    v.e.itrhit(1) := itrhitc(r,pccomp(1));
    
    
--Resource sharing watchpoint / itrace

    v.e.ctrl                    := r.a.ctrl;
    v.e.rs1                     := r.a.rs1;
    v.e.rs2                     := r.a.rs2;
    v.e.rs3                     := r.a.rs3;
    v.e.su                      := r.a.su;
    v.e.et                      := r.a.et;
    v.e.div_lane                := r.a.div_lane;
    v.e.alu_ctrl.use_sethi      := r.a.use_sethi;
    v.e.alu_ctrl.use_logic      := r.a.use_logic;
    v.e.alu_ctrl.use_addsub     := r.a.use_addsub;
    v.e.alu_ctrl.use_logicshift := r.a.use_logicshift;
    v.e.cwp                     := r.a.cwp;
    v.e.use_memaddr_add1        := r.a.use_memaddr_add1;
    v.e.call_op                 := r.a.call_op;
    v.e.call_lane               := r.a.call_lane;
    v.e.e_annul_align4          := r.a.e_annul_align4;
    v.e.e_cond_annul_align4     := r.a.e_cond_annul_align4;
    v.e.e_cancel_annul          := r.a.e_cancel_annul;
    v.e.bht_ctrl                := r.a.bht_ctrl;
    v.e.fpc_ctrl                := r.a.fpc_ctrl;

    v.e.casa_asiA := '0';
    if r.a.ctrl.inst(0)(24 downto 19) = CASA then
      if r.a.ctrl.inst(0)(12 downto 5) = x"0A" then
        v.e.casa_asiA := '1';
      end if;
    end if;
    
    if r.a.ctrl.inst_valid /= "11" then
      v.e.ctrl.no_forward := "00";
    end if;


    v.e.iustdata := (others => '0');
    if r.a.rs3_ra2u = '1' then
      v.e.iustdata := rfo.rdata2;
    elsif r.a.rs3_ra3u = '1' then
      v.e.iustdata := rfo.rdata3;
    elsif r.a.rs3_ra4u = '1' then
      v.e.iustdata := rfo.rdata4;
    end if;

    if is_fpu_store(r.a.ctrl.inst(0)) = '1' and fpu /= 0 then
      v.e.iustdata := fpu5o.stdata;
      if r.a.fp_stdata_latched = '1' then
        v.e.iustdata := r.a.fpustdata;
      end if;
    end if;

    ra_delay_annuled      := '0';
    ra_delay_annuled_lane := '0';
    if exe_delay_annul = '1' then
      --there can be only 1 delay instruction in two lanes
      if r.a.ctrl.delay_inst(0) = '1' and r.a.ctrl.inst_valid(0) = '1' then
        v.e.ctrl.inst_valid(0) := '0';
        ra_delay_annuled       := '1';
      elsif r.a.ctrl.delay_inst(1) = '1' and r.a.ctrl.inst_valid(1) = '1' then
        v.e.ctrl.inst_valid(1) := '0';
        ra_delay_annuled       := '1';
        ra_delay_annuled_lane  := '1';
      end if;
    end if;

    if exe_br_miss = '1' or mem_br_miss = '1' or xc_br_miss = '1' then
      if r.a.ctrl.delay_inst(0) = '1' and r.a.ctrl.inst_valid(0) = '1' then
        if exe_delay_no_annul = '0' then
          v.e.ctrl.inst_valid(0) := '0';
        else
          v.e.ctrl.delay_annuled(0) := '0';
        end if;
        exe_delay_no_annul := '0';
      else
        v.e.ctrl.inst_valid(0) := '0';
      end if;
      if r.a.ctrl.delay_inst(1) = '1' and r.a.ctrl.inst_valid(1) = '1' then
        if exe_delay_no_annul = '0' then
          v.e.ctrl.inst_valid(1) := '0';
        else
          v.e.ctrl.delay_annuled(1) := '0';
        end if;
        exe_delay_no_annul := '0';
      else
        v.e.ctrl.inst_valid(1) := '0';
      end if;
    end if;

    if v.x.annul_all = '1' then
      v.e.ctrl.inst_valid(0) := '0';
      v.e.ctrl.inst_valid(1) := '0';
    end if;

    if r.a.rs1(0)(0) = '0' then
      ex_data1(0) := rfo.rdata1(63 downto 32);
    else
      ex_data1(0) := rfo.rdata1(31 downto 0);
    end if;
    if r.a.rs2(0)(0) = '0' then
      ex_data2(0) := rfo.rdata2(63 downto 32);
    else
      ex_data2(0) := rfo.rdata2(31 downto 0);
    end if;
    if r.a.rs1(1)(0) = '0' then
      ex_data1(1) := rfo.rdata3(63 downto 32);
    else
      ex_data1(1) := rfo.rdata3(31 downto 0);
    end if;
    if r.a.rs2(1)(0) = '0' then
      ex_data2(1) := rfo.rdata4(63 downto 32);
    else
      ex_data2(1) := rfo.rdata4(31 downto 0);
    end if;


    exception_detect(0, r, wpr, dbgi, fpu5o, v.e.ctrl.trap(0), v.e.ctrl.tt(0), pccomp(0));
    exception_detect(1, r, wpr, dbgi, fpu5o, v.e.ctrl.trap(1), v.e.ctrl.tt(1), pccomp(1));

    --forwarding
    --lane0
    forwarding_unit(v, r, 0, ex_result(0), ex_result(1), ex_data1(0), ex_data2(0),
                    r.m.result(0), r.m.result(1), v.w.wb_data(0), v.w.wb_data(1),
                    exc_res(0), exc_res(1), r.a.imm(0), r.a.ctrl.inst_pc(0),
                    oper0_final_muxed_ra(0), oper1_final_muxed_ra(0));
    --lane1
    forwarding_unit(v, r, 1, ex_result(0), ex_result(1), ex_data1(1), ex_data2(1),
                    r.m.result(0), r.m.result(1), v.w.wb_data(0), v.w.wb_data(1),
                    exc_res(0), exc_res(1), r.a.imm(1), r.a.ctrl.inst_pc(1),
                    oper0_final_muxed_ra(1), oper1_final_muxed_ra(1));

    --ALUOP
    for i in 0 to 1 loop
      alu_op(i, r, oper0_final_muxed_ra(i), oper1_final_muxed_ra(i), v.m.icc, v.m.y(0),
             v.e.ex_op1(i), v.e.ex_op2(i), v.e.alu_ctrl.aluop(i), v.e.alu_ctrl.alusel(i),
             v.e.alu_ctrl.aluadd(i), v.e.alu_ctrl.shcnt(i), v.e.alu_ctrl.sari(i),
             v.e.alu_ctrl.shleft(i), v.e.ymsb(i), v.e.mul(i), ra_div(i), v.e.mulstep(i),
             v.e.mac(i), ex_fldbp2z(i), v.e.alu_ctrl.invop2(i));
      load_forward_s(i, v, r, v.e.ldfwd_rs1(i), v.e.ldfwd_rs2(i));
      if i = 1 then
        if v.e.mulstep(1) = '1' and ex_fldbp2z(1) = '1' then
          v.e.ldfwd_rs2(1) := '0';
        end if;
      end if;
      muldiv_forward_s(i, v, r, v.e.use_muldiv_rs1(i), v.e.use_muldiv_rs2(i));
    end loop;


    v.e.mul_op1         := oper0_final_muxed_ra(0);
    v.e.mul_op2         := oper1_final_muxed_ra(0);
    v.e.mul_sign        := r.a.ctrl.inst(0)(19);
    v.e.ldfwd_tomul_rs1 := v.e.ldfwd_rs1(0);
    v.e.ldfwd_tomul_rs2 := v.e.ldfwd_rs2(0);
    v.e.mul_rs10        := v.e.rs1(0)(0);
    v.e.mul_rs20        := v.e.rs2(0)(0);
    if r.a.mul_lane = '1' then
      v.e.mul_op1         := oper0_final_muxed_ra(1);
      v.e.mul_op2         := oper1_final_muxed_ra(1);
      v.e.mul_sign        := r.a.ctrl.inst(1)(19);
      v.e.ldfwd_tomul_rs1 := v.e.ldfwd_rs1(1);
      v.e.ldfwd_tomul_rs2 := v.e.ldfwd_rs2(1);
      v.e.mul_rs10        := v.e.rs1(1)(0);
      v.e.mul_rs20        := v.e.rs2(1)(0);
    end if;


    ---------------------------------------------------------------------------
    --CASA
    ---------------------------------------------------------------------------
    if r.a.astate /= idle and r.a.astate /= count and r.a.casa = '1' then
      v.e.alu_ctrl.alusel(1) := EXE_RES_ADD;
      v.e.alu_ctrl.aluadd(1) := '0';
      v.e.alu_ctrl.invop2(1) := '1';
      v.e.alu_ctrl.alucin(1) := '1';
      v.e.ldfwd_rs1(1)       := '0';
      v.e.ldfwd_rs2(1)       := '1';
      v.e.use_muldiv_rs1(1)  := '0';
      --during atomic operation rs1 of the ALU1 which does the comparison
      --uses the forwarding logic. Since the loaded data can not be used
      --as rs2 in casa instruction this works. CASA does not proceed when
      --rs2 is late alu dependent.
      --Since when actual load data is loaded to the exception stage data register
      --for comparison use_muldiv_rs1 and ldfwd_rs1 is always set to '0' there
      --can not be a parallel mul or ld operation.
    end if;

    ra_br_miss        := '0';
    ra_br_lane        := '0';
    ra_delay_annul    := '0';
    ra_delay_no_annul := '0';
    ra_br_miss_pc     := r.a.bht_ctrl.br_miss_pc;
    v.e.ctrl.br_missp := '0';

    ra_branch_l0_resolve := not((r.a.ctrl.swap and r.a.ctrl.wicc and r.a.ctrl.inst_valid(1))
                                  or (r.e.ctrl.inst_valid(1) and r.e.ctrl.wicc)
                                  or (r.m.ctrl.inst_valid(1) and wicc_mem_delayed)
                                  or (r.x.ctrl.inst_valid(1) and r.x.ctrl.wicc_dexc));
    if FPEN and (is_fpu_branch(r.a.ctrl.inst(0))) = '1' then
      ra_branch_l0_resolve := fpu5o.fccready;
    end if;
    if r.d.ct_state = toc_e then
      ra_branch_l0_resolve := '0';
    end if;

    ra_branch_l0_misspredict := branch_mispredict(r.m.icc, r.a.ctrl.inst(0), r.a.ctrl.br_taken);
    if FPEN and (is_fpu_branch(r.a.ctrl.inst(0))) = '1' then
      ra_branch_l0_misspredict := branch_mispredict_fpu(fpu5o.fcc, r.a.ctrl.inst(0), r.a.ctrl.br_taken);
    end if;

    if r.a.ctrl.branch(0) = '1' and r.a.ctrl.inst_valid(0) = '1' and r.a.ctrl.trap(0) = '0' then
      if ra_branch_l0_resolve = '1' then
        --condition flag will not be moidifed hence branch can be evaluated
        --in this stage
        v.e.ctrl.branch(0) := '0';
        if ra_branch_l0_misspredict = '1' then
          --branch misspredicted
          v.e.ctrl.br_missp := '1';
          v.e.ctrl.br_taken := not(r.a.ctrl.br_taken);  --correct for BHT
          ra_br_miss        := '1';
          if r.a.ctrl.inst(0)(29) = '0' then
            --if a branch without annul flag then delay instruction
            --should not be annuled
            ra_delay_no_annul := '1';
          end if;
          if r.a.ctrl.inst(0)(29) = '1' then
            if r.a.ctrl.br_taken = '0' and is_branch_unc(r.a.ctrl.inst(0)) = '0' then
              --branch annul was in fact taken hence delay instruction
              --should not be annuled
              ra_delay_no_annul := '1';
            else
              --branch annul and branch was in fact not taken hence delay instruction
              --should be annuled
              ra_delay_annul := '1';
            end if;
          end if;
        else
          --branch predicted correctly
          if r.a.ctrl.inst(0)(29) = '1' then
            --branch annul instruction
            if r.a.ctrl.br_taken = '0' or is_branch_unc(r.a.ctrl.inst(0)) = '1' then
              --branch is not taken or BA
              --hence delay instruction should be annuled
              ra_delay_annul := '1';
              --delay slot instruction of a branch annul in memory stage
              --will always be in a previous stage
            end if;
          end if;
        end if;
      end if;
    end if;

    ra_branch_l1_resolve := not((r.e.ctrl.inst_valid(1) and r.e.ctrl.wicc)
                                   or (r.m.ctrl.inst_valid(1) and wicc_mem_delayed)
                                   or (r.x.ctrl.inst_valid(1) and r.x.ctrl.wicc_dexc));
    if FPEN and (is_fpu_branch(r.a.ctrl.inst(1))) = '1' then
      ra_branch_l1_resolve := fpu5o.fccready;
    end if;
    if r.d.ct_state = toc_e then
      ra_branch_l1_resolve := '0';
    end if;

    ra_branch_l1_misspredict := branch_mispredict(r.m.icc, r.a.ctrl.inst(1), r.a.ctrl.br_taken);
    if FPEN and (is_fpu_branch(r.a.ctrl.inst(1))) = '1' then
      ra_branch_l1_misspredict := branch_mispredict_fpu(fpu5o.fcc, r.a.ctrl.inst(1), r.a.ctrl.br_taken);
    end if;

    if r.a.ctrl.branch(1) = '1' and r.a.ctrl.inst_valid(1) = '1' and r.a.ctrl.trap(1) = '0' then
      if ra_branch_l1_resolve = '1' then
        --condition flag will not be moidifed hence branch can be evaluated
        --in this stage
        ra_br_lane         := '1';
        v.e.ctrl.branch(1) := '0';
        if ra_branch_l1_misspredict = '1' then
          --branch misspredicted
          v.e.ctrl.br_missp := '1';
          v.e.ctrl.br_taken := not(r.a.ctrl.br_taken);  --correct for BHT
          ra_br_miss        := '1';
          if r.a.ctrl.inst(1)(29) = '0' then
            --if a branch without annul flag then delay instruction
            --should not be annuled
            ra_delay_no_annul := '1';
          end if;
          if r.a.ctrl.inst(1)(29) = '1' then
            if r.a.ctrl.br_taken = '0' and is_branch_unc(r.a.ctrl.inst(1)) = '0' then
              --branch annul was in fact taken hence delay instruction
              --should not be annuled
              ra_delay_no_annul := '1';
            else
              --branch annul and branch was in fact not taken hence delay instruction
              --should be annuled
              ra_delay_annul := '1';
            end if;
          end if;
        else
          --branch predicted correctly
          if r.a.ctrl.inst(1)(29) = '1' then
            --branch annul instruction
            if r.a.ctrl.br_taken = '0' or is_branch_unc(r.a.ctrl.inst(1)) = '1' then
              --branch is not taken or BA
              --hence delay instruction should be annuled
              ra_delay_annul := '1';
              --delay slot instruction of a branch annul in memory stage
              --will always be in a previous stage
            end if;
          end if;
        end if;
      end if;
    end if;

    for i in 0 to 1 loop
      if FPEN and r.a.ctrl.inst_valid(i) = '1' and is_fpu_branch(r.a.ctrl.inst(i)) = '1' and fpu5o.trapon_flop = '1' then
        v.e.ctrl.branch(i) := '0';
      end if;
    end loop;

    if xc_br_miss = '1' or mem_br_miss = '1' or exe_br_miss = '1' then
      ra_delay_no_annul := '0';
    end if;

    if ra_delay_annul = '1' then
      if ra_br_lane = '0' and r.a.ctrl.swap = '0' then
        if r.a.ctrl.delay_inst(1) = '1' and r.a.ctrl.inst_valid(1) = '1' then
          v.e.ctrl.inst_valid(1) := '0';
          ra_delay_annul         := '0';
          ra_delay_annuled       := '1';
        end if;
      end if;

      if ra_br_lane = '1' and r.a.ctrl.swap = '1' then
        if r.a.ctrl.delay_inst(0) = '1' and r.a.ctrl.inst_valid(0) = '1' then
          v.e.ctrl.inst_valid(0) := '0';
          ra_delay_annul         := '0';
          ra_delay_annuled       := '1';
        end if;
      end if;
    end if;

    if ra_delay_no_annul = '1' then
      if ra_br_lane = '0' and r.a.ctrl.swap = '0' then
        if r.a.ctrl.delay_inst(1) = '1' and r.a.ctrl.inst_valid(1) = '1' then
          ra_delay_no_annul         := '0';
          v.e.ctrl.delay_annuled(1) := '0';
          ra_delay_annuled_lane     := '1';
        end if;
      end if;

      if ra_br_lane = '1' and r.a.ctrl.swap = '1' then
        if r.a.ctrl.delay_inst(0) = '1' and r.a.ctrl.inst_valid(0) = '1' then
          ra_delay_no_annul         := '0';
          v.e.ctrl.delay_annuled(0) := '0';
        end if;
      end if;
    end if;


    if exe_delay_annul = '1' and ra_delay_annuled = '0' then
      --it can happen due to bubbles in the pipeline
      ra_delay_annul := '1';
    end if;

    --if r.a.call_op = '1' and r.a.ctrl.inst_valid(0) = '1' then
    --  ra_br_miss := '1';
    --  ra_br_miss_pc := r.a.ctrl.br_taken_pc;
    --  ra_delay_no_annul := '1';
    --end if;

    ---------------------------------------------------------------------------
    --Atomic Instruction State Machine
    ---------------------------------------------------------------------------
    atomic_finished    := '0';
    v.e.atomic_trapped := '0';  
    case r.a.astate is
      when idle =>
        v.a.casa := '0';
        v.a.atomic_cnt := "00";
        if v.e.ctrl.inst_valid(0) = '1' and is_atomic(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.trap(0) = '0' then
          --in order to prevent any forwarding during atomic operation wait
          --until the last operation before atomic reaches wb stage
          v.a.astate := count;
        end if;

        if v.e.ctrl.trap(0) = '1' then
          --atomic instruction can get privilage trap
          v.a.astate         := idle;
          v.e.atomic_trapped := '1';
          v.a.atomic_cnt     := "00";
        end if;

      when count =>
        if unsigned(r.a.atomic_cnt) = 2 then
          v.a.astate := ld_exe;
          if r.a.ctrl.inst(0)(24 downto 19) = CASA then
            v.a.casa := '1';
          end if;
        else
          v_a_atomic_cnts := unsigned('0'&r.a.atomic_cnt)+1;
          v.a.atomic_cnt := std_logic_vector(v_a_atomic_cnts(1 downto 0));
        end if;

      when ld_exe =>
        v.a.astate := ld_mem;

      when ld_mem =>
        v.a.astate := ld_exc;

      when ld_exc =>
        v.a.astate             := idle;
        v.e.ctrl.inst_valid(0) := '0';
        atomic_finished        := '1';
        v.a.casa               := '0';
        --make sure that when CASA instruction loads the data in exception stage
        --there is no new instruction in access stage due to no_forward scheme
        --used to prevent false forwarding when RS2=RD for CASA instruction
    end case;

    v.a.atomic_nullified := '0';
    if v.e.ctrl.inst_valid(0) = '0' then
      if r.a.astate /= idle and r.a.astate /= count and v.a.astate /= idle then
        atomic_nullify       := '1';
        v.a.atomic_nullified := '1';
      end if;
      v.a.astate := idle;
    end if;

    if r.a.astate /= idle and r.a.astate /= count then
      v.e.ex_op1 := r.e.ex_op1;
      v.e.ex_op2 := r.e.ex_op2;
      v.e.iustdata := r.e.iustdata;
    end if;

    if r.a.astate = ld_mem or r.a.astate = ld_exc then
      v.m.result(0) := r.m.result(0);
    end if;
    

    if r.a.atomic_nullified = '1' then
      atomic_nullify := '1';
    end if;

    if is_atomic(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.inst_valid(0) = '1' and r.a.ctrl.trap(0) = '0' and r.e.atomic_trapped = '0' and atomic_finished = '0' then
      atomic_hold_issue := '1';
    end if;

    v.e.ctrl.ctx_switch := '0';
    if is_store_mmu(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.inst_valid(0) = '1' then
      v.e.ctrl.ctx_switch := '1';
    end if;

    if is_store(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.inst_valid(0) = '1' then
      if r.a.ctrl.inst(0)(23) = '1' and r.a.ctrl.inst(0)(13) = '0' and r.a.ctrl.inst(0)(12 downto 5) = x"02" then
        v.e.ctrl.ctx_switch := '1';
      end if;
    end if;
    if hold_issue_s = '0' then
      if (v.e.ctrl.inst_valid(0) = '1' and r.a.ctrl.trap(0) = '0' and is_flush(r.a.ctrl.inst(0)) = '1') or
        (v.e.ctrl.inst_valid(1) = '1' and r.a.ctrl.trap(1) = '0' and is_flush(r.a.ctrl.inst(1)) = '1') then
        v.e.ctrl.ctx_switch := '1';
      end if;
    end if;
    if r.x.cpustate = CPUSTATE_ERRMODE and dbgcmd /= CPUCMD_NONE then
      v.e.ctrl.ctx_switch := '1';
    end if;

    if exe_delay_no_annul = '1' then
      ra_delay_no_annul := '1';
    end if;

    if v.e.ctrl.inst_valid /= "11" then
      v.e.alu_ctrl.use_sethi      := "00";
      v.e.alu_ctrl.use_logic      := "00";
      v.e.alu_ctrl.use_addsub     := "00";
      v.e.use_memaddr_add1        := '0';
      v.e.alu_ctrl.use_logicshift := '0';
    end if;

-----------------------------------------------------------------------
-- LEON5 DECODE STAGE
-----------------------------------------------------------------------

    v.d.diag_btb_flush   := '0';
    v.d.diag_bht_flush   := '0';
    v.d.btb_diag_in.wren := '0';
    v.d.btb_diag_in.en   := '0';
    v.d.bht_diag_in_en   := '0';
    v.d.bht_diag_in_wren := '0';
    if dco.iudiag_mosi.accen = '0' or r.d.iudiag_miso.accrdy = '1' then
      v.d.iudiag_miso.accrdy := '0';
    end if;
    if dco.iudiag_mosi.accen = '1' and r.d.iudiag_miso.accrdy = '0' then
      case r.d.iudiags is
        when idle =>
          v.d.btb_diag_in.addr              := (others => '0');
          v.d.btb_diag_in.addr(21 downto 0) := dco.iudiag_mosi.addr;
          v.d.btb_diag_in.wrdata            := dco.iudiag_mosi.wrdata;
          if dco.iudiag_mosi.addr(14) = '0' then
            --either BTB or flush commands
            if dco.iudiag_mosi.addr(9) = '0' and dco.iudiag_mosi.accwr = '1' then
              --flush commands
              if dco.iudiag_mosi.addr(0) = '0' then
                v.d.diag_btb_flush := '1';
              else
                v.d.diag_bht_flush := '1';
              end if;
              v.d.iudiag_miso.accrdy := '1';
            elsif dco.iudiag_mosi.addr(9) = '0' and dco.iudiag_mosi.accwr = '0' then
              v.d.iudiag_miso.accrdy := '1';
            else
              --BTB RD/W
              v.d.iudiags        := btb_rw;
              v.d.btb_diag_in.en := '1';
              if dco.iudiag_mosi.accwr = '1' then
                v.d.btb_diag_in.wren := '1';
              end if;
            end if;
          else
            --BHT commands
            v.d.iudiags        := bht_rw_c0;
            v.d.bht_diag_in_en := '1';
          end if;
        when btb_rw =>
          v.d.iudiags            := idle;
          v.d.iudiag_miso.accrdy := '1';
          v.d.iudiag_miso.rddata := btb_diag_out.rdata;
        when bht_rw_c0 =>
          v.d.iudiags := bht_rw_c1;
          v.d.bht_diag_in_en := '1';
        when bht_rw_c1 =>
          v.d.iudiags := bht_rw_c2;
          v.d.bht_diag_in_en := '1';
        when bht_rw_c2 =>
          v.d.iudiag_miso.rddata := bht_diag_out.rdata;
          v.d.iudiag_miso.accrdy := '1';
          v.d.iudiags := idle;
          if dco.iudiag_mosi.accwr = '1' then
              v.d.bht_diag_in_wren := '1';
          end if;
          v.d.bht_diag_in_en := '1';
      end case;
    end if;
    dci.iudiag_miso <= r.d.iudiag_miso;

    --right now we only work on an instruction pair aligned to 0x0 and 0x4
    --later on we will change to have an additional instruction buffer
    --to check two instructions regardless of alignment

    de_inull               := '0';
    de_hold_pc             := '0';
    de_branch              := '0';
    de_branchl             := "00";
    de_mask_branch         := "00";
    de_mask_insts          := '0';
    mask_de_hold_pc        := '0';
    de_inst(0)             := r.d.inst(0)(63 downto 32);
    de_inst(1)             := r.d.inst(0)(31 downto 0);
    v.a.ctrl.jmpl_op       := '0';
    v.a.ctrl.rett_op       := '0';
    v.d.delay_slot         := '0';
    v.d.delay_slot_annuled := '0';
    --v.a.ctrl.bht_data := bhto.rdata(1 downto 0);
    v.a.ctrl.bht_data      := r.d.bht_data;
    v.a.ctrl.no_forward    := "00";
    v.a.bht_ctrl           := r.d.bht_ctrl;
    --if IWAYS > 1 then
    --  de_inst(0) := r.d.inst(conv_integer(r.d.way))(63 downto 32);
    --  de_inst(1) := r.d.inst(conv_integer(r.d.way))(31 downto 0);
    --end if;
    v.a.cwp                := r.d.cwp;

    de_swap := '0';
    dual_issue_check(r, de_inst, r.d.inst_valid, ra_delay_no_annul, alu_dexc_a, fpu5o, wicc_dexc_d, wicc_dmem_d, alu_dexc, no_forward, use_sethi, use_logic, use_addsub, use_memaddr_add1, use_logicshift, dual_ldissue, de_issue, de_fpc_issue_final);
    inst_swap_check(de_inst, de_issue, de_swap);

    de_issue_inst := de_issue;

    fpc_issue_mask := "00";
    fpc_annul      := "00";
    if FPEN then
      fpc_issue_check(fpu5o, de_inst(0), de_fpc_issue(0));
      fpc_issue_check(fpu5o, de_inst(1), de_fpc_issue(1));

      if r.d.inst_valid(0) = '1' and is_fpop(de_inst(0)) = '1' and r.d.mexc = '0' and ico.bpmiss = '0' and r.d.ico_bpmiss = '0' then
        --right now no speculative fp op
        --delay slot of a branch without annul can proceed if there is no
        --other speculative branches in the pipeline because delay slot is
        --always executed when a=0
        for i in 0 to 1 loop
          if (r.a.ctrl.branch(i) = '1' and r.a.ctrl.inst_valid(i) = '1' and
               (r.a.ctrl.inst(i)(29) = '1' or r.d.delay_slot = '0')) or
            (r.e.ctrl.branch(i) = '1' and r.e.ctrl.inst_valid(i) = '1') or
            (r.m.ctrl.branch(i) = '1' and r.m.ctrl.inst_valid(i) = '1') then
            if FPSPEC = '0' or is_fpu_spec_nallow(de_inst(0)) = '1' or r.d.delay_slot_annuled = '1' then
              if r.d.fpc_issued = '0' then
                de_issue           := "00";
                de_fpc_issue_final := "00";
                fpc_issue_mask     := "11";
              end if;
            end if;
          end if;
        end loop;
        if de_fpc_issue(0) = '0' and r.d.fpc_issued = '0' then
          de_issue           := "00";
          de_fpc_issue_final := "00";
          fpc_issue_mask     := "11";
        end if;
        if r.d.fpc_issued = '0' and is_ficc(de_inst(0)) = '1' and waiting_ficc_s = '1' then
          de_issue           := "00";
          de_fpc_issue_final := "00";
          fpc_issue_mask     := "11";
        end if;
      end if;

      if r.d.inst_valid(1) = '1' and is_fpop(de_inst(1)) = '1' and r.d.mexc = '0' then
        --right now no speculative fp op
        --delay slot of a branch without annul can proceed if there is no
        --other speculative branches in the pipeline because delay slot is
        --always executed when a=0
        for i in 0 to 1 loop
          if (r.a.ctrl.branch(i) = '1' and r.a.ctrl.inst_valid(i) = '1' and
               (r.a.ctrl.inst(i)(29) = '1' or r.d.delay_slot = '0' or r.d.inst_valid(0) = '1')) or
            (r.e.ctrl.branch(i) = '1' and r.e.ctrl.inst_valid(i) = '1') or
            (r.m.ctrl.branch(i) = '1' and r.m.ctrl.inst_valid(i) = '1') then
            if FPSPEC = '0' or is_fpu_spec_nallow(de_inst(1)) = '1' or r.d.delay_slot_annuled = '1' then
              if r.d.fpc_issued = '0' then
                de_issue(1)           := '0';
                de_fpc_issue_final(1) := '0';
                fpc_issue_mask(1)     := '1';
              end if;
            end if;
          end if;
        end loop;
        if is_branch_annul(de_inst(0)) = '1' and r.d.inst_valid(0) = '1' then
          de_issue(1)           := '0';
          de_fpc_issue_final(1) := '0';
          fpc_issue_mask(1)     := '1';
        end if;
        if r.d.inst_valid(0) = '1' and is_fpu_branch(de_inst(0)) = '1' and is_ficc(de_inst(1)) = '1' then
          de_issue(1)           := '0';
          de_fpc_issue_final(1) := '0';
          fpc_issue_mask(1)     := '1';
        end if;
        if de_fpc_issue(1) = '0' and r.d.fpc_issued = '0' then
          de_issue(1)           := '0';
          de_fpc_issue_final(1) := '0';
          fpc_issue_mask(1)     := '1';
        end if;
        if r.d.fpc_issued = '0' and is_ficc(de_inst(1)) = '1' and waiting_ficc_s = '1' then
          de_issue (1)          := '0';
          de_fpc_issue_final(1) := '0';
          fpc_issue_mask(1)     := '1';
        end if;
      end if;
    end if;

    
    ---------------------------------------------------------------------------
    su_et_select(r, v, v.w.s.ps, v.w.s.s, v.w.s.et, v.a.su, v.a.et);
    ---------------------------------------------------------------------------
    
    spec_in_pipeline := '0';
    ic_spec_access   := '0';
    for i in 0 to 1 loop
      if (r.a.ctrl.spec_access(i) = '1' and r.a.ctrl.inst_valid(i) = '1' and r.a.ctrl.branch(i) = '1') or
        (r.e.ctrl.spec_access(i) = '1' and r.e.ctrl.inst_valid(i) = '1' and r.e.ctrl.branch(i) = '1') or
        (r.m.ctrl.spec_access(i) = '1' and r.m.ctrl.inst_valid(i) = '1' and r.m.ctrl.branch(i) = '1') then
        ic_spec_access   := '1';
        spec_in_pipeline := '1';
      end if;
    end loop;


    speculative_lock_release := '0';
    if r.d.speculative_lock = '1' then
      --there was an instruciton cache miss on speculative access
      v.d.inst_valid := "00";
      de_mask_insts  := '1';
      if r.d.pc_reset = '0' then
        --if there was a miss on speculative access the v.f.pc is set to r.d.pc
        --which would take one more cycle for icache SRAMs to latch
        if spec_in_pipeline = '0' then
          --no speculation in pipeline
          --release the inull
          v.d.speculative_lock     := '0';
          de_mask_insts            := '0';
          speculative_lock_release := '1';
        end if;
      end if;
    end if;

    --this signal is only set during the
    --first cycle of hold_issue in order not
    --to loose ico_bpmiss signal
    de_issue_clear_force := '0';
    v.d.ico_bpmiss       := '0';
    if r.d.speculative_insts = '1' and r.d.inst_valid /= "00" then
      if ico.bpmiss = '1' or r.d.ico_bpmiss = '1' then
        de_issue_clear_force  := '1';
        de_issue              := "00";
        de_fpc_issue_final    := "00";
        v.d.inst_valid        := "00";
        v.d.speculative_lock  := '1';
        v.d.speculative_insts := '0';
        de_mask_insts         := '1';
      end if;
    end if;

    for i in 0 to 1 loop
      if r.d.inst_valid(i) = '1' then
        if de_issue(i) = '1' then
          v.d.inst_valid(i) := '0';
        else
          de_hold_pc := '1';
          de_inull   := '1';
        end if;
      end if;
    end loop;

    if r.d.hold_only_pcreg = '1' then
      de_hold_pc := '1';
      de_inull   := '1';
    end if;

    if hold_issue_s = '1' then
      --when hold_issue_s is asserted v.d is not updated so
      --no need to change de_hold_pc but next_pc is explicitily handled
      --with hold_issue signal
      de_inull := '1';
    end if;

    if (ico.mds and de_hold_pc) = '0' then
      for i in 0 to IWAYS-1 loop
        if ico.way(IWAYMSB downto 0) = std_logic_vector(to_unsigned(i, IWAYMSB+1)) then
          v.d.inst(0) := ico.data(i);         --data from all ways
        end if;
      end loop;
      v.d.way  := ico.way(IWAYMSB downto 0);  --hit way
      v.d.mexc := ico.mexc;                   --icache access exception      
    end if;

    if de_hold_pc = '0' then
      v.d.inst_pc(0) := r.f.pc(31 downto 3)&"000";
      v.d.inst_pc(1) := r.f.pc(31 downto 3)&"100";
    end if;

    if r.f.valid = '0' then
      v.d.inst_valid := "00";
    end if;

    v.a.ctrl.tt   := (others => (others => '0'));
    v.a.ctrl.trap := "00";
    v.a.ctrl.mexc := '0';
    if r.d.mexc = '1' then
      --make sure the older instruction recieves the trap
      v.a.ctrl.trap := "11";
      v.a.ctrl.mexc := '1';
    end if;

    --don't fetch new instructions when there is an active
    --instruction memory exception
    for i in 0 to 1 loop
      if (r.d.mexc = '1' and r.d.inst_valid /= "00") or
        (r.a.ctrl.inst_valid(i) = '1' and r.a.ctrl.mexc = '1') or
        (r.e.ctrl.inst_valid(i) = '1' and r.e.ctrl.mexc = '1') or
        (r.m.ctrl.inst_valid(i) = '1' and r.m.ctrl.mexc = '1') then
        --r.x is not included since v.x.annul_all will be set when
        --it reaches exception stage
        de_mask_insts := '1';
      end if;
    end loop;

    v.a.ctrl.delay_inst    := "00";
    v.a.ctrl.delay_annuled := "00";

    if r.d.delay_slot = '1' then
      
      if r.d.inst_valid(0) = '1' then
        v.a.ctrl.delay_inst(0) := '1';
        if r.d.delay_slot_annuled = '1' then
          v.a.ctrl.delay_annuled(0) := '1';
        end if;
      else
        --this can happen if an instruction and branch can not be dual issued
        --because of something happening later in the pipeline
        v.a.ctrl.delay_inst(1) := '1';
        if r.d.delay_slot_annuled = '1' then
          v.a.ctrl.delay_annuled(1) := '1';
        end if;
      end if;
      
    end if;

--Detection of unpredictable CTI couples
    v.e.ctrl.unpcti(0) := '0';
    v.e.ctrl.unpcti(1) := '0';
    if r.d.br_cond = '1' and r.d.mexc = '0' then
      if (v.a.ctrl.delay_inst(0) = '1' and is_toc(de_inst(0)) = '1' and r.d.inst_valid(0) = '1') or
        (v.a.ctrl.delay_inst(1) = '1' and is_toc(de_inst(1)) = '1' and r.d.inst_valid(1) = '1') then
        --find the first branch in CTI couple and assert the trap
        if r.a.ctrl.inst_valid(0) = '1' and is_branch(r.a.ctrl.inst(0)) = '1' then
          v.e.ctrl.unpcti(0) := '1';
        elsif r.a.ctrl.inst_valid(1) = '1' and is_branch(r.a.ctrl.inst(1)) = '1' then
          v.e.ctrl.unpcti(1) := '1';
        end if;
      end if;
    end if;
       
    de_branch_address(0) := branch_address(de_inst(0), r.d.inst_pc(0)(31 downto PCLOW));
    de_branch_address(1) := branch_address(de_inst(1), r.d.inst_pc(1)(31 downto PCLOW));
    v.a.ctrl.branch      := "00";

    pc_next          := add('0'&r.f.pc, 4);
    br_ntaken_pc(1)  := pc_next(31 downto 0);
    pc_delay_slot(1) := r.f.pc;

    br_ntaken_pc0    := add(('0'&r.d.inst_pc(0)), 8);
    pc_delay_slot(0) := r.d.inst_pc(1);
    if r.d.inst_valid(1) = '0' then
      --if instruction 1 is invalid that means it is either return from a trap
      --sequence or CTI/CTI sequence and delay slot might not be sequential
      br_ntaken_pc0    := pc_next;
      pc_delay_slot(0) := r.f.pc;
    end if;
    br_ntaken_pc(0)     := br_ntaken_pc0(31 downto 0);
    de_delay_annul_next := '0';

    v.a.call_op := "00";
    -- v.a.call_op = "01" means call_op is postponed to access stage
    -- v.a.call_op = "10" means call_op is postponed to execute stage

    v.a.ctrl.jmpl_op        := '0';
    v.a.ctrl.rett_op        := '0';
    v.a.e_annul_align4      := "00";
    v.a.e_cond_annul_align4 := "00";
    v.a.e_cancel_annul      := "00";
    v.a.spec_check          := "00";
    v.a.ctrl.spec_access    := "00";

    if r.d.ct_state = toc_d then
      v.d.ct_state := idle;
    end if;

    if r.x.debug_ret2 = '1' and de_hold_pc = '0' then
      if r.f.pc(2) = '0' then
        v.d.inst_valid := "11";
      else
        v.d.inst_valid := "10";
      end if;
    end if;

    if r.x.debug_ret2 = '1' and de_hold_pc = '1' then
      --if the first instruction after return is for example
      --a floating point it can be stalled due to FPU unit in that case
      --delay the debug_ret2 operation
      v.x.debug_ret2 := '1';
    end if;


    wicc_d_temp := '0';
    wy_d_temp   := '0';
    bht_takenv  := r.d.bht_taken and BPRED;

    wicc_y_gen(r.d.inst_valid(0), de_inst(0), wicc_d_temp, wy_d_temp);
    de_branch_l1_resolve := not ((wicc_d_temp and r.d.inst_valid(0))
                                  or (r.a.ctrl.wicc and r.a.ctrl.inst_valid(1))
                                  or (r.e.ctrl.inst_valid(1) and r.e.ctrl.wicc)
                                  or (r.m.ctrl.inst_valid(1) and wicc_mem_delayed)
                                  or (r.x.ctrl.inst_valid(1) and r.x.ctrl.wicc_dexc));
    if FPEN and is_fpu_branch(de_inst(1)) = '1' then
      de_branch_l1_resolve := fpu5o.fccready;
      if de_inst(1)(27 downto 25) = "000" then
        de_branch_l1_resolve := '1';
      end if;
    end if;

    de_branch_l1_true := branch_true(r.m.icc, de_inst(1));
    if FPEN and is_fpu_branch(de_inst(1)) = '1' then
      de_branch_l1_true := fpbranch_true(de_inst(1), fpu5o.fcc);
    end if;

    v.d.br_cond := '0';
    if (is_branch(de_inst(1)) = '1' or (FPEN and is_fpu_branch(de_inst(1)) = '1'))
      and r.d.inst_valid(1) = '1' and r.d.mexc = '0'
      and r.d.ct_state /= toc_d and r.d.ct_state /= toc_e then

      --decouple de_issue from branch signal in order to reduce the critical path
      if bht_takenv = '1' then
        de_branchl(1) := '1';
      end if;

      wicc_y_gen(r.d.inst_valid(0), de_inst(0), wicc_d_temp, wy_d_temp);
      if de_branch_l1_resolve = '1' or de_inst(1)(27 downto 25) = "000" then
        if de_branch_l1_true = '1' then
          de_branchl(1) := '1';
        else
          de_branchl(1) := '0';
        end if;
      end if;

      if de_issue(1) = '1' then
        --branch is already issued to the next stage 
        v.a.ctrl.branch(1) := '1';
        bhti_raddr_mux     := '1';
        v.a.ctrl.br_taken  := bht_takenv;
        --if branch is predicted to be taken fetch the new PC during next cycle
        --otherwise just mark the delay slot and continue fetching
        if v.a.ctrl.br_taken = '1' then
          --instruction after delay slot is invalid
          --if it is a return from a trap or similar delay slot can exist
          --in any of the slots
          if r.f.pc(2) = '0' then
            v.d.inst_valid := "01";
          else
            v.d.inst_valid := "10";
          end if;
        end if;
        v.d.delay_slot := '1';

        if de_inst(1)(29) = '1' then
          if v.a.ctrl.br_taken = '0' then
            v.d.delay_slot_annuled := '1';
          end if;
        end if;

        --for the detection of unpredictable CTI couples
        if is_bicc(de_inst(1)) = '1' then
          v.d.br_cond := '1';
        end if;

        --if icc is not going to be modified it is possible to determine branch in
        --this stage
        --validity of v.a. might be modified later but it would
        --only cause performance penalty due to branch pediction
        --getting delayed
        if de_branch_l1_resolve = '1' or de_inst(1)(27 downto 25) = "000" then
          v.a.ctrl.branch(1)     := '0';
          v.d.delay_slot_annuled := '0';
          v.d.inst_valid         := "00";
          if de_branch_l1_true = '1' then
            --branch is taken
            v.a.ctrl.br_taken := '1';
            --instruction after delay slot is invalid
            if r.f.pc(2) = '0' then
              v.d.inst_valid := "01";
            else
              v.d.inst_valid := "10";
            end if;

            if de_inst(1)(29) = '1' and de_inst(1)(28 downto 25) = "1000" then
              --branch always with annul bit, annul the delay inst
              v.d.inst_valid := "00";
            end if;
          else
            --de_branchl(1) := '0';
            v.a.ctrl.br_taken := '0';
            --branch is not taken
            --annul delay slot for branch annul
            if de_inst(1)(29) = '1' then
              de_delay_annul_next := '1';
              --if the next slot only contains delay instruction due to return
              --from trap etc assert the mask_de_hold_pc because if
              --v.d.inst_valid becomes "00" it will try to hold the pc
              --which would result in delay instruciton being repeated
              --and executed
              if r.f.pc(2) = '1' then
                mask_de_hold_pc := '1';
              end if;
              v.d.br_cond := '0';
            end if;
          end if;

          if de_inst(1)(28 downto 25) = "1000" and de_inst(1)(29) = '0' then
            --BA(a=0) means a valid CTI can appear in the delay slot
            v.d.ct_state := toc_d;
          end if;
        end if;

        v.a.bht_ctrl.br_miss_pc := br_ntaken_pc(1)(31 downto 0);
        if v.a.ctrl.br_taken = '0' then
          v.a.bht_ctrl.br_miss_pc := de_branch_address(1);
        end if;
        v.a.bht_ctrl.pc_delay_slot := pc_delay_slot(1)(31 downto 0);
        
        
      end if;  --de_issue

      if BLOCKBPMISS = '1' and v.a.ctrl.branch(1) = '1' then
        --if second instruction is branch then the next pair will
        --always be delay slot hence the instruction when branch
        --reaches access stage will be speculative
        v.a.spec_check(1) := '1';
      end if;
    end if;

    if (is_branch(de_inst(1)) = '1' or (FPEN and is_fpu_branch(de_inst(1)) = '1'))
      and r.d.inst_valid(1) = '1' and r.d.mexc = '0'
      and (r.d.ct_state = toc_d or r.d.ct_state = toc_e) then
      --branch is in the delay slot of a CTI it needs to be resolved in execute
      --stage
      if de_issue(1) = '1' then
        --branch is already issued to the next stage 
        v.a.ctrl.branch(1)         := '1';
        v.a.ctrl.br_taken          := '0';
        --v.a.ctrl.br_taken_pc := de_branch_address(1);
        --v.a.ctrl.br_ntaken_pc := br_ntaken_pc(1)(31 downto 0);
        --it should only annul if branch is resolved to be taken in execute stage
        v.a.e_cond_annul_align4(1) := '1';
        if r.d.ct_state = toc_d then
          v.d.ct_state       := toc_e;
          v.a.e_cancel_annul := "10";
        end if;
        v.a.bht_ctrl.br_miss_pc    := de_branch_address(1);
        v.a.bht_ctrl.pc_delay_slot := pc_delay_slot(1)(31 downto 0);
      end if;
    end if;


    v.a.call_lane := '0';
    if (de_inst(1)(31 downto 30) = "01") and r.d.inst_valid(1) = '1' and r.d.mexc = '0' then
      --call instruction

      --decouple de_issue from branch signal to reduce
      --critical path to IC
      if r.d.ct_state = idle then
        de_branchl(1) := '1';
      end if;

      if de_issue(1) = '1' then
        v.a.bht_ctrl.br_miss_pc := de_branch_address(1);
        if r.d.ct_state = idle then
          --call is not in the delay slot of a CTI
          v.d.ct_state   := toc_d;
          v.d.inst_valid := "01";
          if r.f.pc(2) = '1' then
            --this one is needed in order to handle cases in which for example
            --a jmpl/rett couple can create a sequence in which delay instruction
            --will not be consecutive to call
            v.d.inst_valid := "10";
          end if;
          v.d.delay_slot := '1';        --added for BLOCKBPMISS to work        
        elsif r.d.ct_state = toc_d then
          --call is in the delay slot of a CTI which was taken in decode stage
          --postpone it to execute stage in order not to create an additional case
          --for v.d.inst_valid since de_branchl(1) will be asserted otherwise
          v.a.call_op           := "10";
          v.a.e_annul_align4(1) := '1';
          v.a.call_lane         := '1';
          v.d.ct_state          := toc_e;
          v.a.e_cancel_annul    := "10";
          --annul "0x4" if previous CT was made to alignment "0x0"
          --v.d.ct_state := idle;
          --annul_align4 := '1';
          --v.a.ctrl.br_taken_pc := de_branch_address(1);
          --de_branchl(1) := '1';
          --elsif r.d.ct_state = toc_a then
          --  --call is in the delay slot of a CTI which is going to be taken in
          --  --access stage
          --  --delay call by one cycle to get correct behaviour
          --  v.a.call_op = "01";
          --  v.a.toc_clr = "01";
        else                            --toc_e
                                        --call is in the delay slot of CTI which is going to be taken in
                                        --execute stage
          v.a.call_op           := "10";
          v.a.e_annul_align4(1) := '1';
          v.a.call_lane         := '1';
        end if;
      end if;
    end if;

    if is_jmpl(de_inst(1)) = '1' and r.d.inst_valid(1) = '1' and r.d.mexc = '0' then
      --Jump and Link
      if de_issue(1) = '1' then
        if r.d.ct_state = idle then
          --jmpl is not in the delay slot of a CTI
          v.d.ct_state   := toc_e;
          v.d.inst_valid := "01";
          if r.f.pc(2) = '1' then
            --this one is needed in order to handle cases in which for example
            --a jmpl/rett couple can create a sequence in which delay instruction
            --will not be consecutive to jmpl
            v.d.inst_valid := "10";
          end if;
          v.a.ctrl.jmpl_op := '1';
          v.d.delay_slot   := '1';      --added for BLOCKBPMISS to work
        elsif r.d.ct_state = toc_d then
          --jmpl is in the delay slot of a CTI which was taken in decode stage
          --annul "0x4" if previous CT was made to alignment "0x0"
          --stall the pipline until jmpl is complete
          v.a.e_annul_align4(1) := '1';
          v.a.ctrl.jmpl_op      := '1';
          v.d.ct_state          := toc_e;
          v.a.e_cancel_annul(1) := '1';
          --elsif r.d.ct_state = toc_a then
          --you might have branches which will be resolved in access stage like FBcc,CPcc
        else
          --toc_e
          --jmpl is in the delay slot of a CTI which is going to be taken in
          --execute stage
          v.a.ctrl.jmpl_op      := '1';
          --annul "0x4" of toc_e target 
          v.a.e_annul_align4(1) := '1';
        end if;
      end if;
    end if;

    if is_rett(de_inst(1)) = '1' and r.d.inst_valid(1) = '1' and r.d.mexc = '0' then
      --RETT operation
      if de_issue(1) = '1' then
        if r.d.ct_state = idle then
          --rett is not in the delay slot of a CTI (very unusual case but can
          --happen according to SPARC spec)
          v.d.ct_state   := toc_e;
          v.d.inst_valid := "01";
          if r.f.pc(2) = '1' then
            --this one is needed in order to handle cases in which for example
            --a jmpl/rett couple can create a sequence in which delay instruction
            --will not be consecutive to rett
            v.d.inst_valid := "10";
          end if;
          v.a.ctrl.rett_op := '1';
          v.d.delay_slot   := '1';      --added for BLOCKBPMISS to work
        elsif r.d.ct_state = toc_d then
          --rett is in the delay slot of a CTI which was taken in decode stage
          --annul "0x4" if previous CT was made to alignment "0x0"
          --stall the pipline until jmpl is complete
          v.a.e_annul_align4(1) := '1';
          v.a.ctrl.rett_op      := '1';
          v.d.ct_state          := toc_e;
          v.a.e_cancel_annul(1) := '1';
          --elsif r.d.ct_state = toc_a then
          --you might have branches which will be resolved in access stage like FBcc,CPcc
        else
          --toc_e
          --rett is in the delay slot of a CTI which is going to be taken in
          --execute stage
          v.a.ctrl.rett_op      := '1';
          --annul "0x4" of toc_e target 
          v.a.e_annul_align4(1) := '1';
        end if;
      end if;
    end if;

    de_branch_l0_resolve := not((r.a.ctrl.wicc and r.a.ctrl.inst_valid(1))
                                  or (r.e.ctrl.inst_valid(1) and r.e.ctrl.wicc)
                                  or (r.m.ctrl.inst_valid(1) and wicc_mem_delayed)
                                  or (r.x.ctrl.inst_valid(1) and r.x.ctrl.wicc_dexc));
    if FPEN and is_fpu_branch(de_inst(0)) = '1' then
      de_branch_l0_resolve := fpu5o.fccready;
      if de_inst(0)(27 downto 25) = "000" then
        de_branch_l0_resolve := '1';
      end if;
    end if;

    de_branch_l0_true := branch_true(r.m.icc, de_inst(0));
    if FPEN and is_fpu_branch(de_inst(0)) = '1' then
      de_branch_l0_true := fpbranch_true(de_inst(0), fpu5o.fcc);
    end if;

    --Only one branch instruction can be issued
    if (is_branch(de_inst(0)) = '1' or (FPEN and is_fpu_branch(de_inst(0)) = '1'))
      and r.d.inst_valid(0) = '1' and r.d.mexc = '0'
      and r.d.ct_state /= toc_d and r.d.ct_state /= toc_e then

      --decouple de_issue from branch signal in order to reduce
      --critical path to IC
      if bht_takenv = '1' then
        de_branchl(0) := '1';
      end if;

      if de_branch_l0_resolve = '1' or de_inst(0)(27 downto 25) = "000" then
        if de_branch_l0_true = '1' then
          de_branchl(0) := '1';
        else
          if r.d.btb_hit = '0' or r.d.bht_taken = '0' then
            de_branchl(0) := '0';
          else
            --we don't want to create a special case
            --in which BHT and BTB says taken and it is
            --actually not taken
            --let it go one stage further and recover from there
            de_branchl(0) := '1';
          end if;
        end if;
      end if;

      --since branch signal does not depend on de_issue both of them
      --might be asserted on B2B CTI couples hence the old one needs to be
      --masked
      if de_branchl(0) = '1' then
        de_branchl(1) := '0';
      end if;

      if de_issue(0) = '1' then
        v.a.ctrl.branch(0) := '1';
        v.a.ctrl.br_taken  := bht_takenv;
        -- v.a.ctrl.br_taken_pc := de_branch_address(0);
        -- v.a.ctrl.br_ntaken_pc := br_ntaken_pc(0)(31 downto 0);

        v.a.ctrl.delay_inst(1) := '1';
        if de_inst(0)(29) = '1' then
          if v.a.ctrl.br_taken = '0' and de_inst(0)(27 downto 25) /= "000" then
            v.a.ctrl.delay_annuled(1) := '1';
          end if;
        end if;

        if v.a.ctrl.br_taken = '1' then
          --   de_branchl(0) := '1';
          v.d.inst_valid := "00";
          if r.d.inst_valid(1) = '0' then
            --return from trap type of CTI or return from debug
            if r.f.pc(2) = '0' then
              v.d.inst_valid(0) := '1';
            else
              v.d.inst_valid(1) := '1';
            end if;
          else
            --branch and delay slot are not dual issued
            if de_issue(1) = '0' then
              v.d.inst_valid(1) := '1';
            end if;
          end if;
        end if;

        --for the detection of unpredictable CTI couples
        if is_bicc(de_inst(0)) = '1' then
          if r.d.inst_valid(1) = '0' or is_toc(de_inst(1)) = '1' then 
            v.d.br_cond := '1';
          end if;
        end if;
        

        if de_branch_l0_resolve = '1' or de_inst(0)(27 downto 25) = "000" then
          v.a.ctrl.branch(0)        := '0';
          v.d.delay_slot            := '0';
          v.a.ctrl.delay_annuled(1) := '0';
          if de_branch_l0_true = '1' then
            v.d.inst_valid    := "00";
            v.a.ctrl.br_taken := '1';
            --branch is taken
            --  de_branchl(0) := '1';
            if de_inst(0)(29) = '1' and de_inst(0)(28 downto 25) = "1000" then
              --branch always with annul bit, annul the delay inst
              --if delay slot is in the next slot then it will be automatically
              --annuled due to v.d.inst_valid := "00"
              --if delay slot can not be issued then clear the v.d.inst_valid
              --in order to clear the delay slot
              if r.d.inst_valid(1) = '1' and de_issue(1) = '0' then
                v.d.inst_valid(1) := '0';
              end if;
              de_issue(1)           := '0';
              de_fpc_issue_final(1) := '0';
              fpc_annul(1)          := '1';
            else
              --delay slot should not be annuled
              if r.d.inst_valid(1) = '1' then
                if de_issue(1) = '0' then
                  v.d.inst_valid(1) := '1';
                end if;
              else
                --delay slot is not in this pair
                --return from trap type of CTI or return from debug
                v.d.delay_slot := '1';
                if r.f.pc(2) = '0' then
                  v.d.inst_valid(0) := '1';
                else
                  v.d.inst_valid(1) := '1';
                end if;
              end if;
            end if;
          else
            --branch is not taken
            --annul delay slot for branch annul
            v.a.ctrl.br_taken := '0';
            if r.d.btb_hit = '0' or r.d.bht_taken = '0' then
              --  de_branchl(0) := '0';
              if de_inst(0)(29) = '1' then
                v.d.br_cond := '0';
                if r.d.inst_valid(1) = '1' then
                  if de_issue(1) = '1' then
                    de_issue(1)           := '0';
                    de_fpc_issue_final(1) := '0';
                    fpc_annul(1)          := '1';
                  else
                    v.d.inst_valid(1) := '0';
                  end if;
                else
                  --if instruction(1) is invalid that means delay instruction is in
                  --the upcoming slot
                  de_delay_annul_next := '1';

                  --if the next slot only contains delay instruction due to return
                  --from trap etc assert the mask_de_hold_pc because if
                  --v.d.inst_valid becomes "00" it will try to hold the pc
                  --which would result in delay instruciton being repeated
                  --and executed

                  if r.f.pc(2) = '1' then
                    mask_de_hold_pc := '1';
                  end if;
                  
                end if;
              end if;
            else
              --we don't want to create a special case
              --in which BHT and BTB says taken and it is
              --actually not taken
              --let it go one stage further and recover from there
              --      de_branchl(0) := '1';
              v.a.ctrl.branch(0) := '1';
              v.a.ctrl.br_taken  := '1';
              --BA can not be here because it is always taken
              --BN can not be here because never logged in BHT since it is never taken
              --this does not conflict with CTI in delay slot scheme since there
              --can not be a CTI in the delay slot of a conditional branch and BA/BN
              --can never reach here
            end if;
          end if;

          if de_inst(0)(28 downto 25) = "1000" and de_inst(0)(29) = '0' then
            if de_issue(1) = '0' or r.d.inst_valid(1) = '0' then
              --BA(a=0) means a valid CTI can appear in the delay slot
              --if delay slot is issued that means there was no CTI in the delay
              --slot
              v.d.ct_state := toc_d;
            end if;
          end if;
        end if;

        if BPRED = '0' then
          if v.a.ctrl.branch(0) = '1' then
            --if branch and delay slot can be issued together when BP is disbled
            --annul the next one and keep the PC since that pair is speculative
            if r.d.inst_valid(1) = '1' and de_issue(1) = '1' then
              de_inull      := '1';
              de_hold_pc    := '1';
              de_mask_insts := '1';
            end if;
          end if;
        end if;

        if BLOCKBPMISS = '1' then
          if v.a.ctrl.branch(0) = '1' then
            if r.d.inst_valid(1) = '1' and de_issue(1) = '1' then
              if de_branchl(0) = '0' or (de_branchl(0) = '1' and r.d.btb_hit = '1') then
                --branch is not resolved
                --either it is predicted as not taken hence next pair is speculative
                --or it is predicted as taken and BTB hit hence next pair is speculative
                ic_spec_access          := '1';
                v.a.ctrl.spec_access(0) := '1';
              else
                --branch is taken but not btb hit hence the speculative pair will
                --arive when branch is in access stage
                v.a.spec_check(0) := '1';
              end if;
            else
              --either delay slot is in the next pair or delay slot can
              --not be issued together hence speculative pair will arrive
              --in the next stage
              v.a.spec_check(0) := '1';
            end if;
          end if;
        end if;

        if v.a.ctrl.branch(0) = '1' then
          if r.d.inst_valid(1) = '0' or de_issue(1) = '0' then
            --if instruction(1) is invalid or it can not be issued
            --we need to set the decode flags otherwise delay instruction
            --will not be tagged correctly
            v.d.delay_slot := '1';
            if v.a.ctrl.delay_annuled(1) = '1' then
              v.d.delay_slot_annuled := '1';
            end if;
          end if;
        end if;

        v.a.bht_ctrl.br_miss_pc := br_ntaken_pc(0)(31 downto 0);
        if v.a.ctrl.br_taken = '0' then
          v.a.bht_ctrl.br_miss_pc := de_branch_address(0);
        end if;
        v.a.bht_ctrl.pc_delay_slot := pc_delay_slot(0)(31 downto 0);

      end if;  --de_issue
    end if;

    if (is_branch(de_inst(0)) = '1' or (FPEN and is_fpu_branch(de_inst(0)) = '1'))
      and r.d.inst_valid(0) = '1' and r.d.mexc = '0'
      and (r.d.ct_state = toc_d or r.d.ct_state = toc_e) then
      --branch is in the delay slot of a CTI it needs to be resolved in execute
      --stage
      if de_issue(0) = '1' then
        v.a.ctrl.branch(0) := '1';
        v.a.ctrl.br_taken  := '0';
        --v.a.ctrl.br_taken_pc := de_branch_address(0);
        --v.a.ctrl.br_ntaken_pc := br_ntaken_pc(0)(31 downto 0);
        if r.d.ct_state = toc_d then
          v.d.ct_state       := toc_e;
          v.a.e_cancel_annul := "01";
        end if;
        v.a.e_cond_annul_align4(0) := '1';
        v.a.bht_ctrl.br_miss_pc    := de_branch_address(0);
        v.a.bht_ctrl.pc_delay_slot := pc_delay_slot(0)(31 downto 0);
      end if;
    end if;

    --if a delay slot can not be issued hold the delay slot flags
    --for i in 0 to 1 loop
    --  if v.a.ctrl.delay_inst(i) = '1' and r.d.inst_valid(i) = '1' and de_issue(i) = '0' then
    --    v.d.delay_slot := '1';
    --  end if;
    --  if v.a.ctrl.delay_annuled(i) = '1' and r.d.inst_valid(i) = '1' and de_issue(i) = '0' then
    --    v.d.delay_slot_annuled := '1';
    --  end if;
    --end loop;

    if (de_inst(0)(31 downto 30) = "01") and r.d.inst_valid(0) = '1' and r.d.mexc = '0' then
      --call instruction in lane 0

      --decouple de_issue from branch signal in order
      --to reduce critical path to IC
      if r.d.ct_state = idle then
        de_branchl(0) := '1';
      end if;

      --since branch signal does not depend on de_issue both of them
      --might be asserted on B2B CTI couples hence the old one needs to be
      --masked
      if de_branchl(0) = '1' then
        de_branchl(1) := '0';
      end if;

      if de_issue(0) = '1' then
        v.a.bht_ctrl.br_miss_pc := de_branch_address(0);
        if r.d.ct_state = idle then
          --call is not in the delay slot of a CTI
          v.d.ct_state := toc_d;
          if r.d.inst_valid(1) = '0' then
            --second instruction is invalid either return from debug mode
            --or it is part of jmpl/rett type of sequence
            v.d.inst_valid := "01";
            if r.f.pc(2) = '1' then
              v.d.inst_valid := "10";
            end if;
            v.d.delay_slot := '1';      --added for BLOCKBPMISS to work
          end if;

          if r.d.inst_valid(1) = '1' and de_issue(1) = '1' then
            --call is issued with delay slot so delay slot
            --can not be a CTI
            v.d.ct_state := idle;
          end if;
        elsif r.d.ct_state = toc_d then
          --call is in the delay slot of a CTI which was taken in decode stage
          --postpone it to execute stage in order not to create an additional case
          --for v.d.inst_valid since de_branchl(1) will be asserted otherwise
          --v.a.ctrl.br_taken_pc := de_branch_address(0);
          v.a.call_op           := "10";
          v.a.e_annul_align4(0) := '1';
          v.d.ct_state          := toc_e;
          v.a.e_cancel_annul    := "01";
          --call is in the delay slot of a CTI which was taken in decode stage
          --annul "0x4" if previous CT was made to alignment "0x0"
          -- v.d.ct_state := idle;
          -- annul_align4 := '1';
          --elsif r.d.ct_state = toc_a then   
        else                            --toc_e
          --call is in the delay slot of CTI which is going to be taken in
          --execute stage
          --v.a.ctrl.br_taken_pc := de_branch_address(0);
          v.a.call_op           := "10";
          --annul "0x4" of toc_e target 
          v.a.e_annul_align4(0) := '1';
        end if;
      end if;
    end if;

    if is_jmpl(de_inst(0)) = '1' and r.d.inst_valid(0) = '1' and r.d.mexc = '0' then
      --Jump and Link instruction in slot (0)
      if de_issue(0) = '1' then
        if r.d.ct_state = idle then
          --jmpl is not in the delay slot of a CTI
          v.d.ct_state     := toc_e;
          v.a.ctrl.jmpl_op := '1';
          if r.d.inst_valid(1) = '0' then
            --or it is part of jmpl/rett type of sequence
            v.d.inst_valid := "01";
            if r.f.pc(2) = '1' then
              v.d.inst_valid := "10";
            end if;
            v.d.delay_slot := '1';      --added for BLOCKBPMISS to work
          end if;
        elsif r.d.ct_state = toc_d then
          --jmpl is in the delay slot of a CTI which was taken in decode stage
          --annul "0x4" if previous CT was made to alignment "0x0"
          --stall the pipline until jmpl is complete
          v.a.e_annul_align4(0) := '1';
          v.a.ctrl.jmpl_op      := '1';
          v.d.ct_state          := toc_e;
          v.a.e_cancel_annul(0) := '1';
          --elsif r.d.ct_state = toc_a then
          --you might have branches which will be resolved in access stage like FBcc,CPcc
        else
          --jmpl is in the delay slot of a CTI which is going to be taken in
          --execute stage
          v.a.ctrl.jmpl_op      := '1';
          --annul "0x4" of toc_e target 
          v.a.e_annul_align4(0) := '1';
        end if;
      end if;
    end if;

    if is_rett(de_inst(0)) = '1' and r.d.inst_valid(0) = '1' and r.d.mexc = '0' then
      --Rett instruction in slot (0)
      if de_issue(0) = '1' then
        if r.d.ct_state = idle then
          --rett is not in the delay slot of a CTI
          v.a.ctrl.rett_op := '1';
          v.d.ct_state     := toc_e;
          if r.d.inst_valid(1) = '0' then
            --or it is part of jmpl/rett type of sequence
            v.d.inst_valid := "01";
            if r.f.pc(2) = '1' then
              v.d.inst_valid := "10";
            end if;
            v.d.delay_slot := '1';      --added for BLOCKBPMISS to work
          end if;
        elsif r.d.ct_state = toc_d then
          --rett is in the delay slot of a CTI which was taken in decode stage
          --annul "0x4" if previous CT was made to alignment "0x0"
          --stall the pipline until jmpl is complete
          v.a.e_annul_align4(0) := '1';
          v.a.ctrl.rett_op      := '1';
          v.d.ct_state          := toc_e;
          v.a.e_cancel_annul(0) := '1';
          --elsif r.d.ct_state = toc_a then
          --you might have branches which will be resolved in access stage like FBcc,CPcc
        else
          --toc_e
          --rett is in the delay slot of a CTI which is going to be taken in
          --execute stage
          v.a.ctrl.rett_op      := '1';
          --annul "0x4" of toc_e target 
          v.a.e_annul_align4(0) := '1';
        end if;
      end if;
    end if;


    --cancel annul is used in case back-to-back CTI combination can not be
    --executed consecutively in the execute stage. The PC of the first CTI
    --is hold in r.f.pc with cancel_annul cycle the instruction for this PC
    --is read while new target adress is coming from the new CTI    
    cancel_annul := '0';
    if (r.e.e_cancel_annul(0) = '1' and r.e.ctrl.inst_valid(0) = '1') or
      (r.e.e_cancel_annul(1) = '1' and r.e.ctrl.inst_valid(1) = '1') then
      cancel_annul := '1';
      v.d.ct_state := idle;
    end if;

    hold_cti := '0';
    for i in 0 to 1 loop
      if ((r.a.e_annul_align4(i) = '1' or r.a.e_cond_annul_align4(i) = '1') and r.a.ctrl.inst_valid(i) = '1') then
        --the second CTI in the back-to-back CTI combination is still in access
        --stage due to hold_issue, the v.d.inst_valid must stay "00" for cancel_annul
        --scheme to work
        hold_cti := '1';
      end if;
    end loop;

    for i in 0 to 1 loop
      if v.e.ctrl.branch(i) = '1' and r.a.ctrl.inst_valid(i) = '1' and r.a.spec_check(i) = '1' then
        --speculative inst is arriving to the decode stage next cycle
        ic_spec_access          := '1';
        v.e.ctrl.spec_access(i) := '1';
      end if;
    end loop;

    --if a branch can not be issued de_branchl can still be asserted but
    --de_hold_pc will be also asserted so there is no problem
    if r.f.valid = '1' and de_mask_insts = '0' and hold_cti = '0' and (r.d.ct_state /= toc_e or cancel_annul = '1') and (v.d.ct_state /= toc_e or cancel_annul = '1') and de_hold_pc = '0' and (de_branchl = "00" or (de_branchl(0) = '1' and r.d.btb_hit = '1' and r.d.bht_taken = '1')) then
      v.d.inst_valid := "11";

      if r.f.pc(2) = '1' then
        --if (PC mod 8) is 4 then only the second instruction is valid
        v.d.inst_valid(0) := '0';
      end if;
    end if;

    if de_delay_annul_next = '1' then
      v.d.inst_valid(0) := '0';
      if r.f.pc(2) = '1' then
        v.d.inst_valid(1) := '0';
      end if;
    end if;

    v.a.ctrl.btb_miss := '0';
    if de_branchl(0) = '1' and r.d.bht_taken = '1' and r.d.btb_hit = '0' then
      v.a.ctrl.btb_miss := '1';
    end if;

    if annul_align4 = '1' then
      v.d.inst_valid(1) := '0';
    end if;

    for i in 0 to 1 loop
      if r.e.e_annul_align4(i) = '1' and r.e.ctrl.inst_valid(i) = '1' then
        if r.f.pc(2) = '0' then
          v.d.inst_valid(1) := '0';
        end if;
      end if;
      if r.e.e_cond_annul_align4(i) = '1' and r.e.ctrl.inst_valid(i) = '1' then
        if r.e.ctrl.inst(i)(29) = '0' then
          if exe_br_miss = '1' then
            --B*cc(a=0) taken means only first instruction of preivoust CTI
            --target is valid
            if r.f.pc(2) = '0' then
              v.d.inst_valid(1) := '0';
            end if;
          end if;
        else
          if exe_br_miss = '0' then
            --B*cc(a=1) untaken means the first instruction from the preivout CTI
            --is annuled
            if r.f.pc(2) = '0' then
              v.d.inst_valid(0) := '0';
            else
              v.d.inst_valid  := "00";
              --v.d.inst_valid := "00" will cause de_hold_pc to be asserted which
              --will repeat the first CTI target PC and it will be executed wrongly
              --hence remove de_hold_pc
              mask_de_hold_pc := '1';
            end if;
          else
            if r.e.ctrl.inst(i)(28 downto 25) = "1000" then
              --BA(a=1) target instruction for first CTI is invalid
              --since BA will be propagated as not taken it will cause
              --prediction miss
              v.d.inst_valid := "00";
              --we don't need mask_de_hold_pc here because PC is updated
              --with the branch target address
            else
              --branch is taken hence only first instuction of previous CTI target
              --is valid
              if r.f.pc(2) = '0' then
                v.d.inst_valid(1) := '0';
              end if;
            end if;
          end if;
        end if;
      end if;
    end loop;

    --right now only branch prediction happens only when branch
    --is in slot 1, during call operations there is no
    --prediction
    de_branch            := (de_branchl(0) and not(r.d.btb_hit and r.d.bht_taken)) or de_branchl(1);
    de_branch_addr_muxed := de_branch_address(0);
    if de_branchl(1) = '1' then
      de_branch_addr_muxed := de_branch_address(1);
    end if;

    cwp_ctrl(r, v.w.s.wim, de_inst(0), de_cwp(0), v_a_wovf(0), v_a_wunf(0), de_wcwp(0));
    cwp_ctrl(r, v.w.s.wim, de_inst(1), de_cwp(1), v_a_wovf(1), v_a_wunf(1), de_wcwp(1));
    if r.d.inst_valid(0) = '0' then
      de_cwp(0)  := r.d.cwp;
      de_wcwp(0) := '0';
    end if;
    if r.d.inst_valid(1) = '0' then
      de_wcwp(1) := '0';
    end if;

    de_rs1(0) := de_inst(0)(18 downto 14);
    de_rs2(0) := de_inst(0)(4 downto 0);
    de_rs1(1) := de_inst(1)(18 downto 14);
    de_rs2(1) := de_inst(1)(4 downto 0);

    --mark the rs1 and rs2 valid to zero if instruction do not make use of
    --to prevent unnecessary stalls
    --mark the rs1 and rs2 valid to zero if it is %g0 to prevent wrong
    --forwarding
    rs_check(de_inst(0), de_rs1_valid(0), de_rs2_valid(0));
    rs_check(de_inst(1), de_rs1_valid(1), de_rs2_valid(1));
    
    rd_gen(de_inst(0), de_rdw(0), ldd_z(0), de_rd(0));
    regaddr(r.d.cwp, de_rs1(0), de_rs1_valid(0), de_raddr1(0)(RFBITS downto 0));
    regaddr(r.d.cwp, de_rs2(0), de_rs2_valid(0), de_raddr2(0)(RFBITS downto 0));
    regaddr(r.d.cwp, de_rd(0), '1', de_waddr(0));
    --destination register of SAVE/RESTORE is calculated
    --with new CWP
    if de_wcwp(0) = '1' then
      regaddr(de_cwp(0), de_rd(0), '1', de_waddr(0));
    end if;

    --second instructions must use new CWP in case first instruction
    --is save or restore
    rd_gen(de_inst(1), de_rdw(1), ldd_z(1), de_rd(1));
    regaddr(de_cwp(0), de_rs1(1), de_rs1_valid(1), de_raddr1(1)(RFBITS downto 0));
    regaddr(de_cwp(0), de_rs2(1), de_rs2_valid(1), de_raddr2(1)(RFBITS downto 0));
    regaddr(de_cwp(0), de_rd(1), '1', de_waddr(1));

    --destination register of SAVE/RESTORE is calculated
    --with new CWP
    if de_wcwp(1) = '1' then
      regaddr(de_cwp(1), de_rd(1), '1', de_waddr(1));
    end if;

    cancel_annul_delayed := '0';
    for i in 0 to 1 loop
      if ((r.a.e_annul_align4(i) = '1' or r.a.e_cond_annul_align4(i) = '1') and r.a.ctrl.inst_valid(i) = '1') then
        if hold_issue_s = '1' then
          cancel_annul_delayed := '1';
        end if;
      end if;
    end loop;

    if xc_br_miss = '1' or mem_br_miss = '1' or exe_br_miss = '1' or exe_jmpl_ct = '1' or exe_rett_ct = '1' or ra_br_miss = '1' or v.x.annul_all = '1' then

      if not((exe_br_miss = '1' or exe_jmpl_ct = '1' or exe_rett_ct = '1') and cancel_annul_delayed = '1') then
        --if b2b CTI and second CTI is delayed don't set the v.d.ct_state to
        --idle since it will take more cycles for second CTI to arrive in
        --execute stage
        v.d.ct_state := idle;
      end if;
      if xc_br_miss = '1' or mem_br_miss = '1' or ra_br_miss = '1' or v.x.annul_all = '1' then
        v.d.ct_state := idle;
      end if;
      v.d.delay_slot      := '0';
      v.d.hold_only_pcreg := '0';
      ic_spec_access      := '0';
    end if;

    if xc_br_miss = '1' or mem_br_miss = '1' or exe_br_miss = '1' or exe_jmpl_ct = '1' or exe_rett_ct = '1' or (ra_br_miss = '1' and r.d.delay_slot = '0') or v.x.annul_all = '1' then
      v.d.speculative_insts := '0';
      v.d.speculative_lock  := '0';
    end if;



    no_b2b_cti := '0';
    for i in 0 to 1 loop
      if (r.e.e_annul_align4(i) = '1' or r.e.e_cond_annul_align4(i) = '1') and r.e.ctrl.inst_valid(i) = '1' then
        no_b2b_cti := '1';
      end if;
    end loop;

    if xc_br_miss = '1' or mem_br_miss = '1' or (exe_br_miss = '1' and no_b2b_cti = '0') or ra_br_miss = '1' then
      --exe_jmpl_ct, exe_rett_ct is not here because toc_e state already
      --handles the valid bits
      v.d.inst_valid(1) := '0';
      v.d.inst_valid(0) := '0';
    end if;

    if ra_br_miss = '1' or exe_br_miss = '1' or mem_br_miss = '1' or xc_br_miss = '1' then
      if v.a.ctrl.delay_inst(0) = '1' and ra_delay_no_annul = '1' then
        v.a.ctrl.delay_annuled(0) := '0';
        ra_delay_no_annul         := '0';
        if de_issue_clear_force = '0' and de_issue(0) = '0' then
          --instruction has to stall in decode stage
          v.d.inst_valid(0) := '1';
        end if;
      else
        de_issue(0)           := '0';
        de_fpc_issue_final(0) := '0';
        fpc_annul(0)          := '1';
      end if;
      if v.a.ctrl.delay_inst(1) = '1' and ra_delay_no_annul = '1' then
        v.a.ctrl.delay_annuled(1) := '0';
        ra_delay_no_annul         := '0';
        if de_issue_clear_force = '0' and de_issue(1) = '0' then
          --instruction has to stall in decode stage
          v.d.inst_valid(1) := '1';
        end if;
      else
        de_issue(1)           := '0';
        de_fpc_issue_final(1) := '0';
        fpc_annul(1)          := '1';
      end if;
    end if;

    if ra_delay_annul = '1' then
      --there can be only 1 delay instruction in two lanes
      if v.a.ctrl.delay_inst(0) = '1' then
        de_issue(0)           := '0';
        de_fpc_issue_final(0) := '0';
        fpc_annul(0)          := '1';
        if de_hold_pc = '1' then
          v.d.inst_valid(0) := '0';
        end if;
      end if;

      if v.a.ctrl.delay_inst(1) = '1' then
        de_issue(1)           := '0';
        de_fpc_issue_final(1) := '0';
        fpc_annul(1)          := '1';
        if de_hold_pc = '1' then
          v.d.inst_valid(1) := '0';
        end if;
      end if;
    end if;

    --if a delay slot can not be issued hold the delay slot flags
    for i in 0 to 1 loop
      if de_hold_pc = '1' then
        if v.a.ctrl.delay_inst(i) = '1' and r.d.inst_valid(i) = '1' and de_issue(i) = '0' and v.d.inst_valid(i) = '1' then
          v.d.delay_slot := '1';
        end if;
        if v.a.ctrl.delay_annuled(i) = '1' and r.d.inst_valid(i) = '1' and de_issue(i) = '0' and v.d.inst_valid(i) = '1' then
          v.d.delay_slot_annuled := '1';
        end if;
      end if;
    end loop;

    if de_mask_insts = '1' then
      v.d.inst_valid := "00";
    end if;

    if v.x.annul_all = '1' then
      de_fpc_issue_final := "00";
      de_issue           := "00";
      fpc_annul          := "11";
      v.d.inst_valid     := "00";
    end if;


    if de_issue(0) = '0' or v.x.annul_all = '1' then
      de_wcwp(0) := '0';
    end if;
    if de_issue(1) = '0' or v.x.annul_all = '1' then
      de_wcwp(1) := '0';
    end if;

    --window overflow
    v.a.wovf := "00";
    if v_a_wovf(0) = '1' and r.d.inst_valid(0) = '1' and de_issue(0) = '1' then
      v.a.wovf(0) := '1';
    elsif v_a_wovf(1) = '1' and r.d.inst_valid(1) = '1' and de_issue(1) = '1' then
      v.a.wovf(1) := '1';
    end if;

    --window underflow
    v.a.wunf := "00";
    if v_a_wunf(0) = '1' and r.d.inst_valid(0) = '1' and de_issue(0) = '1' then
      v.a.wunf(0) := '1';
    elsif v_a_wunf(1) = '1' and r.d.inst_valid(1) = '1' and de_issue(1) = '1' then
      v.a.wunf(1) := '1';
    end if;

    de_wcwp_f := de_wcwp(0) or de_wcwp(1);
    de_cwp_f  := de_cwp(1);
    cwp_valid := r.d.inst_valid(1) and de_issue(1) and not(v.a.ctrl.delay_annuled(1));
    --two instructions that modify cwp is never issued together
    --hence wcwp(0) overwrites
    if de_wcwp(0) = '1' and r.d.inst_valid(0) = '1' then
      de_cwp_f  := de_cwp(0);
      cwp_valid := r.d.inst_valid(0) and de_issue(0) and not(v.a.ctrl.delay_annuled(0));
    end if;
    cwp_gen(r, v, cwp_valid, de_wcwp_f, de_cwp_f, v.d.cwp, v.a.ctrl.cwp_update);

    v.a.ctrl.cwp_prev    := r.d.cwp;
    v.a.ctrl.cwp_updatel := not(de_wcwp(0));

    v.a.ctrl.cwp_annuled   := '0';
    v.a.ctrl.cwp_annul_val := de_cwp(1);
    if de_wcwp(1) = '1' and r.d.inst_valid(1) = '1' and de_issue(1) = '1' and v.a.ctrl.delay_annuled(1) = '1' then
      v.a.ctrl.cwp_updatel := '1';
      v.a.ctrl.cwp_annuled := '1';
    end if;

    if de_wcwp(0) = '1' and r.d.inst_valid(0) = '1' and de_issue(0) = '1' and v.a.ctrl.delay_annuled(0) = '1' then
      v.a.ctrl.cwp_annul_val := de_cwp(0);
      v.a.ctrl.cwp_updatel   := '0';
      v.a.ctrl.cwp_annuled   := '1';
    end if;


    if xc_br_miss = '1' or ra_br_miss = '1' or exe_br_miss = '1' or mem_br_miss = '1' or v.x.annul_all = '1' then
      if r.a.ctrl.cwp_update = '1' then
        if (r.a.ctrl.cwp_updatel = '0' and r.a.ctrl.inst_valid(0) = '1' and v.e.ctrl.inst_valid(0) = '0') or
          (r.a.ctrl.cwp_updatel = '1' and r.a.ctrl.inst_valid(1) = '1' and v.e.ctrl.inst_valid(1) = '0') then
          v.d.cwp := r.a.ctrl.cwp_prev;
        end if;
      end if;
      if r.a.ctrl.cwp_annuled = '1' then
        if (r.a.ctrl.cwp_updatel = '0' and r.a.ctrl.inst_valid(0) = '1' and r.a.ctrl.delay_annuled(0) = '1' and v.e.ctrl.delay_annuled(0) = '0') then
          v.d.cwp := r.a.ctrl.cwp_annul_val;
        end if;
        if (r.a.ctrl.cwp_updatel = '1' and r.a.ctrl.inst_valid(1) = '1' and r.a.ctrl.delay_annuled(1) = '1' and v.e.ctrl.delay_annuled(1) = '0') then
          v.d.cwp := r.a.ctrl.cwp_annul_val;
        end if;
      end if;
    end if;

    --Delay annuled save/restore will not reach speculatively beyond access stage
    if xc_br_miss = '1' or exe_br_miss = '1' or mem_br_miss = '1' or v.x.annul_all = '1' then
      if r.e.ctrl.cwp_update = '1' then
        if (r.e.ctrl.cwp_updatel = '0' and r.e.ctrl.inst_valid(0) = '1' and v.m.ctrl.inst_valid(0) = '0') or
          (r.e.ctrl.cwp_updatel = '1' and r.e.ctrl.inst_valid(1) = '1' and v.m.ctrl.inst_valid(1) = '0') then
          v.d.cwp := r.e.ctrl.cwp_prev;
        end if;
      end if;
    end if;

    if mem_br_miss = '1' or xc_br_miss = '1' or v.x.annul_all = '1' then
      if r.m.ctrl.cwp_update = '1' then
        if (r.m.ctrl.cwp_updatel = '0' and r.m.ctrl.inst_valid(0) = '1' and v.x.ctrl.inst_valid(0) = '0') or
          (r.m.ctrl.cwp_updatel = '1' and r.m.ctrl.inst_valid(1) = '1' and v.x.ctrl.inst_valid(1) = '0') then
          v.d.cwp := r.m.ctrl.cwp_prev;
        end if;
      end if;
    end if;

    if xc_br_miss = '1' or v.x.annul_all = '1' then
      --During window overflow or window underflow r.d.cwp is not updated so no
      --recovery is needed
      if xc_exception = '1' and (xc_vectt(5 downto 0) /= TT_WINOF and xc_vectt(5 downto 0) /= TT_WINUF) then
        if r.x.ctrl.cwp_update = '1' then
          if (r.x.ctrl.cwp_updatel = '0' and r.x.ctrl.inst_valid(0) = '1' and (mask_we1 = '1')) or
            (r.x.ctrl.cwp_updatel = '1' and r.x.ctrl.inst_valid(1) = '1' and (mask_we2 = '1')) then
            v.d.cwp := r.x.ctrl.cwp_prev;
          end if;
        end if;
      else
        if r.x.ctrl.cwp_update = '1' then
          if (r.x.ctrl.cwp_updatel = '0' and r.x.ctrl.inst_valid(0) = '1' and mask_we1 = '1') or
            (r.x.ctrl.cwp_updatel = '1' and r.x.ctrl.inst_valid(1) = '1' and mask_we2 = '1') then
            v.d.cwp := r.x.ctrl.cwp_prev;
          end if;
        end if;
      end if;
    end if;

    if no_forward = '1' and de_issue = "11" and r.d.inst_valid = "11" then
      v.a.ctrl.no_forward := "01";
    end if;

    --here de_issue_inst is used to reduce critical path
    --valid bits are checked in access stage to make sure no false
    --chain ALU operation happens which would case wrong data
    v.a.use_sethi := "00";
    if use_sethi /= "00" and de_issue_inst = "11" and r.d.inst_valid = "11" and r.d.delay_slot_annuled = '0' then
      v.a.use_sethi := use_sethi;
      de_swap       := '1';
    end if;

    v.a.use_logic := "00";
    if use_logic /= "00" and de_issue_inst = "11" and r.d.inst_valid = "11" and r.d.delay_slot_annuled = '0' then
      v.a.use_logic := use_logic;
      de_swap       := '1';
    end if;

    v.a.use_addsub := "00";
    if use_addsub /= "00" and de_issue_inst = "11" and r.d.inst_valid = "11" and r.d.delay_slot_annuled = '0' then
      v.a.use_addsub := use_addsub;
      de_swap        := '1';
    end if;

    v.a.use_memaddr_add1 := '0';
    if use_memaddr_add1 = '1' and de_issue_inst = "11" and r.d.inst_valid = "11" and r.d.delay_slot_annuled = '0' then
      v.a.use_memaddr_add1 := '1';
    end if;

    v.a.use_logicshift := '0';
    if use_logicshift = '1' and de_issue_inst = "11" and r.d.inst_valid = "11" and r.d.delay_slot_annuled = '0' then
      v.a.use_logicshift := '1';
      de_swap            := '1';
    end if;

    v.e.ctrl.br_dual_ld := '0';
    if dual_ldissue = '1' and r.d.inst_valid = "11" and ra_br_miss = '0' then
      de_swap := '1';
      if r.d.mexc = '0' then
        --in case of bpmiss branch will be annuled anyway
        v.e.ctrl.br_dual_ld := '1';
      end if;
    end if;

    --this is used to avoid corner cases after bp disable bit is
    --changed 
    v.a.bp_disabled := not(BPRED);

    if v.d.inst_valid /= "00" and ic_spec_access = '1' then
      v.d.speculative_insts := '1';
    end if;

    if v.d.inst_valid = "00" or (r.d.mexc = '1' and r.d.inst_valid /= "00") then
      --if no insturction is valid in decode stage
      --we should inull it, this will prevent all the
      --unneeded fetches from the icache
      --we also hold the pc because in some cases we need
      --the last pc available and remove only inull
      de_inull := '1';
      if mask_de_hold_pc = '0' then
        de_hold_pc := '1';
      end if;
    end if;

    if v.x.annul_all = '1' then
      exe_ld_recover := '0';
      mem_ld_recover := '0';
      xc_ld_recover  := '0';
    end if;
    if xc_br_miss = '1' then
      mem_ld_recover := '0';
      exe_ld_recover := '0';
    end if;
    if mem_br_miss = '1' then
      exe_ld_recover := '0';
    end if;

    if xc_ld_recover = '1' or mem_ld_recover = '1' or exe_ld_recover = '1' then
      v.d.inst_valid(0) := '1';
      v.d.way           := (others => '0');
    end if;

    ld_recover_inst := r.a.ctrl.inst(1);
    if xc_ld_recover = '1' then
      v.d.inst_pc(0) := r.a.ctrl.inst_pc(1);
      if r.m.ctrl.inst_valid(1) = '1' then
        ld_recover_inst := r.m.ctrl.inst(1);
        v.d.inst_pc(0)  := r.m.ctrl.inst_pc(1);
      elsif r.e.ctrl.inst_valid(1) = '1' then
        ld_recover_inst := r.e.ctrl.inst(1);
        v.d.inst_pc(0)  := r.e.ctrl.inst_pc(1);
      end if;
    end if;
    if mem_ld_recover = '1' then
      v.d.inst_pc(0) := r.a.ctrl.inst_pc(1);
      if r.e.ctrl.inst_valid(1) = '1' then
        ld_recover_inst := r.e.ctrl.inst(1);
        v.d.inst_pc(0)  := r.e.ctrl.inst_pc(1);
      end if;
    end if;
    if exe_ld_recover = '1' then
      v.d.inst_pc(0) := r.a.ctrl.inst_pc(1);
    end if;

    if xc_ld_recover = '1' or mem_ld_recover = '1' or exe_ld_recover = '1' then
      v.d.inst(0)(63 downto 32) := ld_recover_inst;
    end if;

    if r.d.mexc = '1' then
      v.a.ctrl.branch  := "00";
      v.a.ctrl.jmpl_op := '0';
      v.a.ctrl.rett_op := '0';
    end if;

    if r.d.inst_valid(0) = '0' then
      de_rs1_valid(0) := '0';
      de_rs2_valid(0) := '0';
    end if;
    if r.d.inst_valid(1) = '0' then
      de_rs1_valid(1) := '0';
      de_rs2_valid(1) := '0';
    end if;

    v.a.ctrl.inst_pc       := r.d.inst_pc;
    v.a.ctrl.inst          := de_inst;
    v.a.ctrl.inst_valid(0) := r.d.inst_valid(0) and de_issue(0) and not(v.x.annul_all);
    v.a.ctrl.inst_valid(1) := r.d.inst_valid(1) and de_issue(1) and not(v.x.annul_all);
    v.a.rs1(0)             := de_rs1_valid(0)&de_raddr1(0)(RFBITS-1 downto 0);
    v.a.rs1(1)             := de_rs1_valid(1)&de_raddr1(1)(RFBITS-1 downto 0);
    v.a.rs2(0)             := de_rs2_valid(0)&de_raddr2(0)(RFBITS-1 downto 0);
    v.a.rs2(1)             := de_rs2_valid(1)&de_raddr2(1)(RFBITS-1 downto 0);
    v.a.ctrl.rd(0)         := '1'&de_waddr(0)(RFBITS-1 downto 0);
    v.a.ctrl.rd(1)         := '1'&de_waddr(1)(RFBITS-1 downto 0);
    v.a.ctrl.rdw           := de_rdw;
    delay_inst0_tmp        := v.a.ctrl.delay_inst(0);
    v.a.ctrl.swap          := '0';
    v_a_branch0_tmp        := v.a.ctrl.branch(0);
    v_a_wovf0_tmp          := v.a.wovf(0);
    v_a_wunf0_tmp          := v.a.wunf(0);
    v_a_delay_annuled0_tmp := v.a.ctrl.delay_annuled(0);
    v.a.ctrl.alu_dexc(0)   := '0';
    v.a.ctrl.alu_dexc(1)   := alu_dexc(1) and v.a.ctrl.inst_valid(0) and v.a.ctrl.inst_valid(1) and not(v.a.ctrl.delay_annuled(0));
    v.a.ctrl.ldd_z         := ldd_z(0);
    late_alu_s1(r, v.a.rs1, v.a.rs2, use_sethi, use_logic, use_addsub, use_logicshift, v.a.ctrl.lalu_s1);
    v_a_lalu_s1_tmp        := v.a.ctrl.lalu_s1(0);
    if de_swap = '1' then
      --instructions needs to be swapped in the pipeline
      v.a.ctrl.swap             := '1';
      v.a.ctrl.inst_pc(0)       := r.d.inst_pc(1);
      v.a.ctrl.inst_pc(1)       := r.d.inst_pc(0);
      v.a.ctrl.inst(0)          := de_inst(1);
      v.a.ctrl.inst(1)          := de_inst(0);
      v.a.ctrl.inst_valid(0)    := r.d.inst_valid(1) and de_issue(1);
      v.a.ctrl.inst_valid(1)    := r.d.inst_valid(0) and de_issue(0);
      v.a.ctrl.delay_inst(0)    := v.a.ctrl.delay_inst(1);
      v.a.ctrl.delay_inst(1)    := delay_inst0_tmp;
      v.a.rs1(0)                := de_rs1_valid(1)&de_raddr1(1)(RFBITS-1 downto 0);
      v.a.rs2(0)                := de_rs2_valid(1)&de_raddr2(1)(RFBITS-1 downto 0);
      v.a.rs1(1)                := de_rs1_valid(0)&de_raddr1(0)(RFBITS-1 downto 0);
      v.a.rs2(1)                := de_rs2_valid(0)&de_raddr2(0)(RFBITS-1 downto 0);
      v.a.ctrl.rd(0)            := '1'&de_waddr(1)(RFBITS-1 downto 0);
      v.a.ctrl.rdw(0)           := de_rdw(1);
      v.a.ctrl.rd(1)            := '1'&de_waddr(0)(RFBITS-1 downto 0);
      v.a.ctrl.rdw(1)           := de_rdw(0);
      v.a.ctrl.branch(0)        := v.a.ctrl.branch(1);
      v.a.ctrl.branch(1)        := v_a_branch0_tmp;
      v.a.wovf(0)               := v.a.wovf(1);
      v.a.wovf(1)               := v_a_wovf0_tmp;
      v.a.wunf(0)               := v.a.wunf(1);
      v.a.wunf(1)               := v_a_wunf0_tmp;
      v.a.ctrl.cwp_updatel      := not(v.a.ctrl.cwp_updatel);
      v.a.ctrl.delay_annuled(0) := v.a.ctrl.delay_annuled(1);
      v.a.ctrl.delay_annuled(1) := v_a_delay_annuled0_tmp;
      v.a.ctrl.ldd_z            := ldd_z(1);
      v.a.ctrl.lalu_s1(0)       := v.a.ctrl.lalu_s1(1);
      v.a.ctrl.lalu_s1(1)       := v_a_lalu_s1_tmp;
      if v.a.ctrl.no_forward = "01" then
        v.a.ctrl.no_forward := "10";
      end if;
      if v.a.ctrl.alu_dexc(1) = '1' then
        v.a.ctrl.alu_dexc(0) := '1';
        v.a.ctrl.alu_dexc(1) := '0';
      end if;
      if v.a.call_lane = '0' then
        v.a.call_lane := '1';
      else
        v.a.call_lane := '0';
      end if;
      if v.a.e_annul_align4(0) = '1' then
        v.a.e_annul_align4 := "10";
      elsif v.a.e_annul_align4(1) = '1' then
        v.a.e_annul_align4 := "01";
      end if;
      if v.a.e_cond_annul_align4(0) = '1' then
        v.a.e_cond_annul_align4 := "10";
      elsif v.a.e_cond_annul_align4(1) = '1' then
        v.a.e_cond_annul_align4 := "01";
      end if;
      if v.a.e_cancel_annul(0) = '1' then
        v.a.e_cancel_annul := "10";
      elsif v.a.e_cancel_annul(1) = '1' then
        v.a.e_cancel_annul := "01";
      end if;
      if v.a.spec_check(0) = '1' then
        v.a.spec_check := "10";
      elsif v.a.spec_check(1) = '1' then
        v.a.spec_check := "01";
      end if;
      if v.a.ctrl.spec_access(0) = '1' then
        v.a.ctrl.spec_access := "10";
      elsif v.a.ctrl.spec_access(1) = '1' then
        v.a.ctrl.spec_access := "01";
      end if;
    end if;

    v.a.ctrl.single_issue := '0';
    if (is_wsri(v.a.ctrl.inst(0)) = '1' and v.a.ctrl.inst_valid(0) = '1') or
      (is_wsri(v.a.ctrl.inst(1)) = '1' and v.a.ctrl.inst_valid(1) = '1') then
      v.a.ctrl.single_issue := '1';
    end if;

    if is_store(v.a.ctrl.inst(0)) = '1' and v.a.ctrl.inst(0)(23) = '1' then
      --STA instruction to MMU/Cache register
      if v.a.ctrl.inst(0)(12 downto 5) = x"02" or v.a.ctrl.inst(0)(12 downto 5) = x"03" or
        v.a.ctrl.inst(0)(12 downto 5) = x"04" or v.a.ctrl.inst(0)(12 downto 5) = x"10" or
        v.a.ctrl.inst(0)(12 downto 5) = x"11" or v.a.ctrl.inst(0)(12 downto 5) = x"13" or
        v.a.ctrl.inst(0)(12 downto 5) = x"18" or v.a.ctrl.inst(0)(12 downto 5) = x"19" then
        v.a.ctrl.single_issue := '1';
      end if;
    end if;

    v.a.imm(0) := imm_data(v.a.ctrl.inst(0));
    v.a.imm(1) := imm_data(v.a.ctrl.inst(1));

    if (r.d.inst_valid(0) = '1' and is_atomic(de_inst(0)) = '1') or
      (r.d.inst_valid(0) = '0' and is_atomic(de_inst(1)) = '1') then
      --  if is_atomic(v.a.ctrl.inst(0)) = '1' and v.a.ctrl.inst_valid(0) = '1' then
      --For CASA
      --ALU1 is used for the comparison hence RS2 is transferred to RS1 of
      --other lane and RS2 of other lane is set to forward load result
      v.a.rs1(1)             := v.a.rs2(0);
      v.a.ctrl.inst(1)       := v.a.ctrl.inst(0);
      --For CASA
      --this is to prevent false forwarding when RS2 and Rd is same for CASA
      --since when casa load is in exception stage the same casa is still
      --in access stage there is no problem with forwarding
      --For all atomic it prevents if false forwarding if destination and
      --address register is same
      v.a.ctrl.no_forward(0) := '1';
    end if;

    de_rs3 := de_inst(0)(29 downto 25);

    if de_swap = '1' then
      de_rs3 := de_inst(1)(29 downto 25);
    end if;

    if de_swap = '0' then
      regaddr(r.d.cwp, de_rs3, '1', v.a.rs3);
    else
      regaddr(de_cwp(0), de_rs3, '1', v.a.rs3);
    end if;
    v.a.rs3(RFBITS) := '1';

    rs3_select_inst  := de_inst(0);
    rs3_control_inst := de_inst(1);
    rs3_select_lane  := '0';
    if r.d.inst_valid(0) = '0' or (is_store(de_inst(0)) = '0' and is_atomic(de_inst(0)) = '0') then
      rs3_select_inst  := de_inst(1);
      rs3_control_inst := de_inst(0);
      rs3_select_lane  := '1';
    end if;

    rs3_select(rs3_select_inst, rs3_sel, st_dbl, st_dbla0);

    v.a.rs3_ra2u := '0';
    v.a.rs3_ra3u := '0';
    v.a.rs3_ra4u := '0';

    if rs3_sel = "01" then
      v.a.rs3_ra2u := '1';
    elsif rs3_sel = "10" then
      if rs3_control_inst(4 downto 0) = "00000" or rs3_control_inst(13) = '1' or is_atomic(rs3_select_inst) = '1' then
        v.a.rs3_ra4u := '1';
      else
        v.a.rs3_ra3u := '1';
      end if;
    end if;

    --in order to remove de_issue from the v.a.rs3 signals we use this approach
    --a store with 3 operands always try to read the register regardless it is
    --issued or not. If that register is actually used by other instruction then mask it
    --it. In this case store instruction will not be issued anyway
    if rs3_select_lane = '1' then
      if r.d.inst_valid(0) = '1' and de_rs1_valid(0) = '1' and v.a.rs3_ra3u = '1' then
        v.a.rs3_ra3u := '0';
      end if;
      if r.d.inst_valid(0) = '1' and de_rs2_valid(0) = '1' and v.a.rs3_ra4u = '1' then
        v.a.rs3_ra4u := '0';
      end if;
    end if;

    if rs3_select_lane = '1' and r.d.inst_valid(0) = '1' and inst_lane_check(de_inst(0), '1') = '1' then
      --de_inst(0) will be forced to lane-0 hence remove rs3_ra2u (store will
      --not be issued)
      v.a.rs3_ra2u := '0';
    end if;


    v.a.divstart := '0';
    if (v.a.ctrl.inst_valid(0) = '1' and is_div(v.a.ctrl.inst(0)) = '1') or
      (v.a.ctrl.inst_valid(1) = '1' and is_div(v.a.ctrl.inst(1)) = '1') then
      v.a.divstart := '1';
    end if;

    --this part concerns what happens with fpc store data when hold_issue is 0 hence it is placed here
    v.a.fp_stdata_latched := '0';
    if FPEN and r.d.fpc_issued = '1' and v.a.ctrl.inst_valid(0) = '1' and is_fpu_store(v.a.ctrl.inst(0)) = '1' then
      v.a.fpustdata := fpu5o.stdata;
      if r.d.fp_stdata_latched = '1' then
        v.a.fpustdata := r.d.fpustdata;
      end if;
      v.a.fp_stdata_latched := '1';
    end if;

    de_fpc_stdata_latch_mask := '0';
    if FPEN and r.d.fpc_issued = '1' and r.d.fp_stdata_latched = '0' then
      v.d.fp_stdata_latched := '1';
      v.d.fpustdata         := fpu5o.stdata;
    end if;
    ---------------------------------------------------------------------------
    
    instruction_control(r,
                        v,
                        fpu5o,
                        de_inst,
                        v.a.ctrl.inst,
                        v.a.ctrl.inst_valid,
                        v.a.mulstart,
                        mul_lane,
                        div_start,
                        v.a.div_lane,
                        div_flush,
                        hold_issue,
                        hold_issue_call,
                        late_wicc_ic,
                        exc_wicc,
                        alu_dexc_a,
                        mask_divstart,
                        waiting_ficc,
                        hold_issue_type);

    
    hold_issue_s       <= hold_issue or atomic_hold_issue;
    waiting_ficc_s     <= waiting_ficc;
    v.a.mul_lane       := mul_lane and v.a.ctrl.inst_valid(1);
    wicc_y_gen(v.a.ctrl.inst_valid(0), v.a.ctrl.inst(0), wicc_unused , v.a.ctrl.wy(0));
    wicc_y_gen(v.a.ctrl.inst_valid(1), v.a.ctrl.inst(1), v.a.ctrl.wicc, v.a.ctrl.wy(1));
    v.a.ctrl.wicc_dmem := wicc_dmem_d and v.a.ctrl.inst_valid(0) and v.a.ctrl.inst_valid(1);
    v.a.ctrl.wicc_dexc := wicc_dexc_d and v.a.ctrl.inst_valid(0) and v.a.ctrl.inst_valid(1);
    v.e.ctrl.wicc_dexc := (r.a.ctrl.wicc_dexc or exc_wicc) and v.e.ctrl.inst_valid(1);
    v.e.ctrl.wicc_dmem := ((late_wicc_ic and r.a.ctrl.wicc) or r.a.ctrl.wicc_dmem) and v.e.ctrl.inst_valid(1);

    v.e.ctrl.alu_dexc(0) := (r.a.ctrl.alu_dexc(0) or alu_dexc_a(0)) and v.e.ctrl.inst_valid(0);
    v.e.ctrl.alu_dexc(1) := (r.a.ctrl.alu_dexc(1) or alu_dexc_a(1)) and v.e.ctrl.inst_valid(1);

    v.a.ctrl.wicc_muldiv := '0';
    if v.a.ctrl.inst_valid(1) = '1' and is_muldivcc(v.a.ctrl.inst(1)) = '1' then
      v.a.ctrl.wicc_muldiv := '1';
    end if;

    -- rfi_raddr1    := "00" & v.a.rs1(0)(RFBITS downto 1);
    rfi_raddr1    := (others => '0');
    rfi_raddr1(RFBITS-1 downto 0) := v.a.rs1(0)(RFBITS downto 1);
    rfi_raddr1lsb := v.a.rs1(0)(0);
    rgz1 := '0';
    if (v.a.rs1(0)(RFBITS-1 downto 4) = globals_v) and (v.a.rs1(0)(3 downto 1) = "000") then
      rgz1 := '1';
    end if;
      
    -- rfi_raddr2    := "00" & v.a.rs2(0)(RFBITS downto 1);
    rgz2 := '0';
    rfi_raddr2    := (others => '0');
    rfi_raddr2(RFBITS-1 downto 0) := v.a.rs2(0)(RFBITS downto 1);
    rfi_raddr2lsb := v.a.rs2(0)(0);
    if (v.a.rs2(0)(RFBITS-1 downto 4) = globals_v) and (v.a.rs2(0)(3 downto 1) = "000") then
      rgz2 := '1';
    end if;
    if v.a.rs3_ra2u = '1' then
      rgz2 := '0';
      rfi_raddr2(RFBITS-1 downto 0) := v.a.rs3(RFBITS downto 1);
      rfi_raddr2lsb := v.a.rs3(0);
      if (v.a.rs3(RFBITS-1 downto 4) = globals_v) and (v.a.rs3(3 downto 1) = "000") then
        rgz2 := '1';
      end if;
    end if;
    -- rfi_raddr3    := "00" & v.a.rs1(1)(RFBITS downto 1);
    rgz3  := '0';
    rfi_raddr3    := (others => '0');
    rfi_raddr3(RFBITS-1 downto 0) := v.a.rs1(1)(RFBITS downto 1);
    rfi_raddr3lsb := v.a.rs1(1)(0);
    if (v.a.rs1(1)(RFBITS-1 downto 4) = globals_v) and (v.a.rs1(1)(3 downto 1) = "000") then
      rgz3 := '1';
    end if;
    if v.a.rs3_ra3u = '1' then
      rgz3 := '0';
      rfi_raddr3(RFBITS-1 downto 0) := v.a.rs3(RFBITS downto 1);
      rfi_raddr3lsb := v.a.rs3(0);
      if (v.a.rs3(RFBITS-1 downto 4) = globals_v) and (v.a.rs3(3 downto 1) = "000") then
        rgz3 := '1';
      end if;
    end if;
    -- rfi_raddr4    := "00" & v.a.rs2(1)(RFBITS downto 1);
    rgz4 := '0';
    rfi_raddr4    := (others => '0');
    rfi_raddr4(RFBITS-1 downto 0) := v.a.rs2(1)(RFBITS downto 1);
    rfi_raddr4lsb := v.a.rs2(1)(0);
    if (v.a.rs2(1)(RFBITS-1 downto 4) = globals_v) and (v.a.rs2(1)(3 downto 1) = "000") then
      rgz4 := '1';
    end if;
    if v.a.rs3_ra4u = '1' then
      rgz4 := '0';
      rfi_raddr4(RFBITS-1 downto 0) := v.a.rs3(RFBITS downto 1);
      rfi_raddr4lsb := v.a.rs3(0);
      if (v.a.rs3(RFBITS-1 downto 4) = globals_v) and (v.a.rs3(3 downto 1) = "000") then
        rgz4 := '1';
      end if;
    end if;
    rfi_rdhold := not(holdn) or hold_issue_s;

    rfi_debugen := '0';
    if DBGUNIT then
      if (dbgi.mosi.accwr = '0') and (r.x.rstate = dsu2) then
        rfi_raddr1(RFBITS-1 downto 0) := dbgi.mosi.addr(RFBITS+2-2 downto 3-2);
        rfi_raddr1(RFBITS-1)          := '1';
        rfi_debugen := '1';
      end if;
    end if;



    --FPU--
    fpu5i_issue_cmd         := "000";
    fpu5i_issue_flop        := de_inst(0)(13 downto 5);
    fpu5i_issue_rd          := de_inst(0)(29 downto 25);
    fpu5i_issue_rs1         := de_inst(0)(18 downto 14);
    fpu5i_issue_rs2         := de_inst(0)(4 downto 0);
    fpu5i_issue_op3_0       := de_inst(0)(19);
    fpu5i_issue_ldstdp      := de_inst(0)(20);
    fpu5i_issue_ldstreg     := '0'&fpu5i_issue_rd;
    fpu5i_issue_dfqdata     := r.d.inst_pc(0)&de_inst(0);
    fpu5i_unissue           := '0';
    fpu5i_unissue_sid       := (others => '0');
    fpu5i_commit            := '0';
    fpu5i_commitid          := r.x.fpc_ctrl.opid;
    fpu5i_spstore_done      := '0';
    fpu5i_lddata            := r.x.data(0);
    fpu_issue_inst          := de_inst(0);
    v.a.fpc_ctrl.trap_fp    := '0';
    v.a.fpc_ctrl.opid       := fpu5o.issue_id;
    v.a.fpc_ctrl.issued     := '0';
    v.a.fpc_ctrl.illegal_fp := '0';
    fpc_lane0_issue         := '0';
    if FPEN then
      if r.d.inst_valid(0) = '1' and fpc_issue_mask(0) = '0' and is_fpop(de_inst(0)) = '1' and r.d.fpc_issued = '0' and r.d.fpc_annuled = '0' and is_legal_fpu(de_inst(0)) = '1' and r.d.mexc = '0' and ico.bpmiss = '0' and r.d.ico_bpmiss = '0' then
        fpu5i_issue_cmd := "001";
        fpc_lane0_issue := '1';
        if is_store(de_inst(0)) = '1' then
          fpu5i_issue_cmd := "010";
          if de_inst(0)(24 downto 19) = "100101" then
            fpu5i_issue_ldstreg := "100000";
          end if;
          if de_inst(0)(24 downto 19) = "100110" then
            fpu5i_issue_ldstreg := "100010";
          end if;
        end if;
        if is_load(de_inst(0)) = '1' then
          fpu5i_issue_cmd := "011";
          if de_inst(0)(24 downto 19) = "100001" then
            fpu5i_issue_ldstreg := "100000";
          end if;
        end if;
      end if;

      for i in 0 to 1 loop
        if r.d.inst_valid(i) = '1' and de_issue(i) = '1' and is_fpop(de_inst(i)) = '1' and is_legal_fpu(de_inst(i)) = '0' then
          v.a.fpc_ctrl.illegal_fp := '1';
        end if;
      end loop;

      fpc_issue_lane          := '0';
      v.d.fpc_ctrl.issue_lane := '0';
      v.a.fpc_ctrl.issue_lane := '0';
      if r.d.inst_valid(0) = '0' or (r.d.inst_valid(0) = '1' and is_fpop(de_inst(0)) = '0') then
        v.a.fpc_ctrl.issue_lane := '1';
        v.d.fpc_ctrl.issue_lane := '1';
        fpc_issue_lane          := '1';
        fpu_issue_inst          := de_inst(1);
        fpu5i_issue_flop        := de_inst(1)(13 downto 5);
        fpu5i_issue_rd          := de_inst(1)(29 downto 25);
        fpu5i_issue_rs1         := de_inst(1)(18 downto 14);
        fpu5i_issue_rs2         := de_inst(1)(4 downto 0);
        fpu5i_issue_op3_0       := de_inst(1)(19);
        fpu5i_issue_ldstdp      := de_inst(1)(20);
        fpu5i_issue_dfqdata     := r.d.inst_pc(1)&de_inst(1);
        fpu5i_issue_ldstreg     := '0'&fpu5i_issue_rd;
      end if;

      if de_swap = '1' then
        v.a.fpc_ctrl.issue_lane := not(v.a.fpc_ctrl.issue_lane);
      end if;

      if r.d.inst_valid(1) = '1' and fpc_issue_mask(1) = '0' and fpc_lane0_issue = '0' and is_fpop(de_inst(1)) = '1' and r.d.fpc_issued = '0' and r.d.fpc_annuled = '0' and is_legal_fpu(de_inst(1)) = '1' and r.d.mexc = '0' and ico.bpmiss = '0' and r.d.ico_bpmiss = '0' then
        fpu5i_issue_cmd := "001";
        if is_store(de_inst(1)) = '1' then
          fpu5i_issue_cmd := "010";
          if de_inst(1)(24 downto 19) = "100101" then
            fpu5i_issue_ldstreg := "100000";
          end if;
          if de_inst(1)(24 downto 19) = "100110" then
            fpu5i_issue_ldstreg := "100010";
          end if;
        end if;
        if is_load(de_inst(1)) = '1' then
          fpu5i_issue_cmd := "011";
          if de_inst(1)(24 downto 19) = "100001" then
            fpu5i_issue_ldstreg := "100000";
          end if;
        end if;
      end if;

      --in order not to generate cascaded fpu masks
      fpu5i_issue_cmd_btrap := fpu5i_issue_cmd;

      if fpu5o.trapon_flop = '1' then
        if is_fpu_load(fpu_issue_inst) = '0' and is_fpu_store(fpu_issue_inst) = '0' then
          if fpu5i_issue_cmd_btrap /= "000" then
            v.a.fpc_ctrl.trap_fp := '1';
          end if;
          fpu5i_issue_cmd := "000";
        end if;
      end if;

      if fpu5o.trapon_flop = '1' and v.a.fpc_ctrl.trap_fp = '0' then
        if r.d.inst_valid(0) = '1' and is_fpu_branch(de_inst(0)) = '1' and de_issue(0) = '1' then
          v.a.fpc_ctrl.trap_fp := '1';
        end if;
        if r.d.inst_valid(1) = '1' and is_fpu_branch(de_inst(1)) = '1' and de_issue(1) = '1' then
          v.a.fpc_ctrl.trap_fp := '1';
        end if;
      end if;

      if fpu5o.trapon_ldst = '1' then
        if is_fpu_load(fpu_issue_inst) = '1' or (is_fpu_store(fpu_issue_inst) = '1' and fpu_issue_inst(24 downto 19) /= "100110") then
          if fpu5i_issue_cmd_btrap /= "000" then
            v.a.fpc_ctrl.trap_fp := '1';
          end if;
          fpu5i_issue_cmd := "000";
        end if;
      end if;

      if fpu5o.trapon_stdfq = '1' then
        if is_store(fpu_issue_inst) = '1' and fpu_issue_inst(24 downto 19) = "100110" then
          if fpu5i_issue_cmd_btrap /= "000" then
            v.a.fpc_ctrl.trap_fp := '1';
          end if;
          fpu5i_issue_cmd := "000";
        end if;
      end if;

      --hold issue is not used to mask fpc issue commands to reduce the
      --critical path hence check if an instruction in decode stage is issued
      --after hold issue is released
      --an fpc that is going to trapped will not cause r.d.fpc_issued to be set
      --hence will be handled correctly
      --issue lane also independent from actual issue cmd hence will be set correctly
      if r.d.fpc_ctrl.issued = '1' then
        if (fpc_issue_lane = '0' and de_issue(0) = '1') or
          (fpc_issue_lane = '1' and de_issue(1) = '1') then
          v.a.fpc_ctrl.issued := '1';
          v.a.fpc_ctrl.opid   := r.d.fpc_ctrl.opid;
          v.d.fpc_ctrl.issued := '0';
        end if;
      end if;

      if r.d.fpc_issued = '1' then
        if (fpc_issue_lane = '0' and de_issue(0) = '1') or
          (fpc_issue_lane = '1' and de_issue(1) = '1') then
          v.d.fpc_issued        := '0';
          v.d.fp_stdata_latched := '0';
        end if;
      end if;

      if r.d.mexc = '1' then
        fpu5i_issue_cmd := "000";
      end if;

      --PIPELINE the fp exception acknowledge to reduce
      --critical path on issue path. It is ok to delay
      --one cycle since no other commit can come the next
      --cycle when trap is taken
      v.w.fp_exc_ack := "00";

      if xc_trapl = '0' then
        if is_store(r.x.ctrl.inst(0)) = '1' and r.x.ctrl.inst(0)(24 downto 19) = "100110" then
          v.w.fp_exc_ack(1) := '1';
        end if;
      end if;

      if r.x.rstate = run and xc_trap = '1' and xc_vectt = "00"&TT_FPEXC and dbgm = '0' then
        v.w.fp_exc_ack(0) := '1';
      end if;

      if r.x.fpc_ctrl.issued = '1' or r.x.fpc_ctrl.spstore = '1' then
        if (r.x.ctrl.inst_valid(0) = '1' and is_fpop(r.x.ctrl.inst(0)) = '1' and (mask_we1 = '0' and (xc_trapl = '1' or xc_trap = '0'))) or
          (r.x.ctrl.inst_valid(1) = '1' and is_fpop(r.x.ctrl.inst(1)) = '1' and mask_we2 = '0' and r.x.ctrl.trap(1) = '0') then
          if r.x.fpc_ctrl.spstore = '0' then
            fpu5i_commit := '1';
          end if;
          if r.x.fpc_ctrl.spstore = '1' then
            fpu5i_spstore_done := '1';
          end if;
        end if;
      end if;

      if holdn = '0' then
        fpu5i_commit       := '0';
        fpu5i_issue_cmd    := "000";
        fpu5i_spstore_done := '0';
        v.w.fp_exc_ack     := "00";
      end if;

      if r.w.fp_exc_ack(0) = '1' then
        fpu5i_issue_cmd := "100";
        if r.w.fp_exc_ack(1) = '1' then
          fpu5i_issue_cmd := "110";
        end if;
      end if;

      if fpu5i_issue_cmd /= "000" and fpu5i_issue_cmd /= "100" and fpu5i_issue_cmd /= "110" and is_store(fpu_issue_inst) = '0' then
        v.a.fpc_ctrl.issued := '1';
      end if;

      if fpu5i_issue_cmd /= "000" and fpu5i_issue_cmd /= "100" and fpu5i_issue_cmd /= "110" then
        if (fpc_issue_lane = '0' and de_issue(0) = '0') or
          (fpc_issue_lane = '1' and de_issue(1) = '0') then
          v.d.fpc_issued      := '1';
          v.d.fpc_ctrl.issued := '1';
          v.a.fpc_ctrl.issued := '0';
          v.d.fpc_ctrl.opid   := fpu5o.issue_id;
          if fpu5i_issue_cmd = "010" then
            v.d.fpc_ctrl.issued := '0';
          end if;
        end if;
      end if;


      -------------------------------------------------------------------------
      v_d_fpc_annuled := '0';
      --this part handles both branch missprediction and traps
      if r.d.fpc_issued = '1' then
        if (r.d.fpc_ctrl.issue_lane = '0' and fpc_annul(0) = '1') or
          (r.d.fpc_ctrl.issue_lane = '1' and fpc_annul(1) = '1') then
          --since hold issue is removed from issue masking this can happe
          v.d.fp_stdata_latched    := '0';
          de_fpc_stdata_latch_mask := '1';
          v.d.fpc_issued           := '0';
          v_d_fpc_annuled          := '1';
        end if;
      end if;

      if v.d.fpc_ctrl.issued = '1' then
        if (fpc_issue_lane = '0' and fpc_annul(0) = '1') or
          (fpc_issue_lane = '1' and fpc_annul(1) = '1') then
          --since hold issue is removed from issue masking this can happen if a
          --fpu operation is issued while hold issue was asserted and then annuled
          --in the pipeline
          fpu5i_unissue            := '1';
          fpu5i_unissue_sid        := v.d.fpc_ctrl.opid;
          v.d.fpc_ctrl.issued      := '0';
          v.d.fpc_issued           := '0';
          v.d.fp_stdata_latched    := '0';
          de_fpc_stdata_latch_mask := '1';
          v_d_fpc_annuled          := '1';
        end if;
      end if;

      if r.d.fpc_ctrl.issued = '1' then
        if (r.d.fpc_ctrl.issue_lane = '0' and fpc_annul(0) = '1') or
          (r.d.fpc_ctrl.issue_lane = '1' and fpc_annul(1) = '1') then
          --since hold issue is removed from issue masking this can happen if a
          --fpu operation is issued while hold issue was asserted and then annuled
          --in the pipeline
          fpu5i_unissue       := '1';
          fpu5i_unissue_sid   := r.d.fpc_ctrl.opid;
          v.a.fpc_ctrl.issued := '0';
          v.d.fpc_ctrl.issued := '0';
        end if;
      end if;

      if r.a.fpc_ctrl.issued = '1' then
        if (r.a.fpc_ctrl.issue_lane = '0' and v.e.ctrl.inst_valid(0) = '0')
          or (r.a.fpc_ctrl.issue_lane = '1' and v.e.ctrl.inst_valid(1) = '0') then
          fpu5i_unissue       := '1';
          fpu5i_unissue_sid   := r.a.fpc_ctrl.opid;
          v.e.fpc_ctrl.issued := '0';
        end if;
      end if;

      if r.e.fpc_ctrl.issued = '1' then
        if (r.e.fpc_ctrl.issue_lane = '0' and v.m.ctrl.inst_valid(0) = '0')
          or (r.e.fpc_ctrl.issue_lane = '1' and v.m.ctrl.inst_valid(1) = '0') then
          fpu5i_unissue       := '1';
          fpu5i_unissue_sid   := r.e.fpc_ctrl.opid;
          v.m.fpc_ctrl.issued := '0';
        end if;
      end if;

      if r.m.fpc_ctrl.issued = '1' then
        if (r.m.fpc_ctrl.issue_lane = '0' and v.x.ctrl.inst_valid(0) = '0')
          or (r.m.fpc_ctrl.issue_lane = '1' and v.x.ctrl.inst_valid(1) = '0') then
          fpu5i_unissue       := '1';
          fpu5i_unissue_sid   := r.m.fpc_ctrl.opid;
          v.x.fpc_ctrl.issued := '0';
        end if;
      end if;

      if r.x.fpc_ctrl.issued = '1' then
        if (r.x.fpc_ctrl.issue_lane = '0' and mask_we1 = '1') or
          (r.x.fpc_ctrl.issue_lane = '1' and mask_we2 = '1') then
          fpu5i_unissue     := '1';
          fpu5i_unissue_sid := r.x.fpc_ctrl.opid;
        end if;
      end if;

      if v.x.annul_all = '1' then
        if r.x.fpc_ctrl.issued = '1' then
          if xc_vectt /= "00"&TT_FPEXC then
            --when an FPU inst gets an interrupt or fp load store gets
            --unaligned access trap
            if (r.x.ctrl.inst_valid(0) = '1' and r.x.fpc_ctrl.issue_lane = '0' and xc_trapl = '0') or
              (r.x.ctrl.inst_valid(1) = '1' and r.x.fpc_ctrl.issue_lane = '1' and xc_trapl = '1') then
              fpu5i_unissue     := '1';
              fpu5i_unissue_sid := r.x.fpc_ctrl.opid;
            end if;
          end if;
        end if;
      end if;

      -------------------------------------------------------------------------


      if v.d.fpc_issued = '1' then
        if (fpc_issue_lane = '0' and fpc_annul(0) = '1') or
          (fpc_issue_lane = '1' and fpc_annul(1) = '1') then
          v.d.fpc_issued           := '0';
          v.d.fp_stdata_latched    := '0';
          v.d.fpc_ctrl.issued      := '0';
          de_fpc_stdata_latch_mask := '1';
        end if;
      end if;

      v.w.fpu_unissue     := fpu5i_unissue;
      v.w.fpu_unissue_sid := fpu5i_unissue_sid;
      if holdn = '0' then
        v.w.fpu_unissue := '0';
      end if;

      
    end if;  --fpu/=0

    fpu5i_spstore_pend   := '0';
    if r.d.fpc_issued='1' then
      if ( (r.d.fpc_ctrl.issue_lane='0' and is_fpu_spstore(de_inst(0))='1') or
           (r.d.fpc_ctrl.issue_lane='1' and is_fpu_spstore(de_inst(1))='1') ) then
        fpu5i_spstore_pend := '1';
      end if;
    end if;
    v.e.fpc_ctrl.spstore := '0';
    if (r.a.ctrl.inst_valid(0) = '1' and is_fpu_spstore(r.a.ctrl.inst(0)) = '1') or
      (r.a.ctrl.inst_valid(1) = '1' and is_fpu_spstore(r.a.ctrl.inst(1)) = '1') then
      fpu5i_spstore_pend   := '1';
      v.e.fpc_ctrl.spstore := '1';
    end if;
    if r.e.fpc_ctrl.spstore = '1' then
      if (r.e.fpc_ctrl.issue_lane = '0' and r.e.ctrl.inst_valid(0) = '1') or
        (r.e.fpc_ctrl.issue_lane = '1' and r.e.ctrl.inst_valid(1) = '1') then
        fpu5i_spstore_pend := '1';
      end if;
    end if;
    if r.m.fpc_ctrl.spstore = '1' then
      if (r.m.fpc_ctrl.issue_lane = '0' and r.m.ctrl.inst_valid(0) = '1') or
        (r.m.fpc_ctrl.issue_lane = '1' and r.m.ctrl.inst_valid(1) = '1') then
        fpu5i_spstore_pend := '1';
      end if;
    end if;
    if r.x.fpc_ctrl.spstore = '1' then
      if (r.x.fpc_ctrl.issue_lane = '0' and r.x.ctrl.inst_valid(0) = '1') or
        (r.x.fpc_ctrl.issue_lane = '1' and r.x.ctrl.inst_valid(1) = '1') then
        fpu5i_spstore_pend := '1';
      end if;
    end if;


    divi_start := r.a.divstart and div_a_valid and not(mask_divstart);

    --right now the read enable signals will be active during holdn
    --cycles if there is a valid instruction with RS,
    --think about optimizing that further later on
    rfi.raddr1 <= rfi_raddr1;
    rfi.raddr2 <= rfi_raddr2;
    rfi_re10   := (rfi_raddr1(RFBITS-1) and (not rfi_raddr1lsb)) or rfi_debugen;
    rfi_re11   := (rfi_raddr1(RFBITS-1) and rfi_raddr1lsb) or rfi_debugen;
    rfi_re20   := rfi_raddr2(RFBITS-1) and ((not rfi_raddr2lsb) or (v.a.rs3_ra2u and st_dbl and not st_dbla0));
    rfi_re21   := rfi_raddr2(RFBITS-1) and (rfi_raddr2lsb or (v.a.rs3_ra2u and st_dbl));
    rfi.rgz1   <= rgz1;
    rfi.rgz2   <= rgz2;
    

    rfi.re1(0) <= rfi_re10;
    rfi.re1(1) <= rfi_re11;
    rfi.re2(0) <= rfi_re20;
    rfi.re2(1) <= rfi_re21;

    rfi.raddr3 <= rfi_raddr3;
    rfi.raddr4 <= rfi_raddr4;
    rfi_re30   := rfi_raddr3(RFBITS-1) and ((not rfi_raddr3lsb) or (v.a.rs3_ra3u and st_dbl and not st_dbla0));
    rfi_re31   := rfi_raddr3(RFBITS-1) and (rfi_raddr3lsb or (v.a.rs3_ra3u and st_dbl));
    rfi_re40   := rfi_raddr4(RFBITS-1) and ((not rfi_raddr4lsb) or (v.a.rs3_ra4u and st_dbl and not st_dbla0));
    rfi_re41   := rfi_raddr4(RFBITS-1) and (rfi_raddr4lsb or (v.a.rs3_ra4u and st_dbl));
    rfi.rgz3   <= rgz3;
    rfi.rgz4   <= rgz4;
    

    rfi.re3(0) <= rfi_re30;
    rfi.re3(1) <= rfi_re31;
    rfi.re4(0) <= rfi_re40;
    rfi.re4(1) <= rfi_re41;

    rfi.rdhold <= rfi_rdhold;

    fpu5i.issue_cmd     <= fpu5i_issue_cmd;
    fpu5i.issue_ldstreg <= fpu5i_issue_ldstreg;
    fpu5i.issue_ldstdp  <= fpu5i_issue_ldstdp;
    fpu5i.issue_op3_0   <= fpu5i_issue_op3_0;
    fpu5i.issue_flop    <= fpu5i_issue_flop;
    fpu5i.issue_rd      <= fpu5i_issue_rd;
    fpu5i.issue_rs1     <= fpu5i_issue_rs1;
    fpu5i.issue_rs2     <= fpu5i_issue_rs2;
    fpu5i.issue_dfqdata <= fpu5i_issue_dfqdata;
    fpu5i.commit        <= fpu5i_commit;
    fpu5i.commitid      <= fpu5i_commitid;
    fpu5i.lddata        <= fpu5i_lddata;
    fpu5i.unissue       <= r.w.fpu_unissue;
    fpu5i.unissue_sid   <= r.w.fpu_unissue_sid;
    fpu5i.spstore_pend  <= fpu5i_spstore_pend;
    fpu5i.spstore_done  <= fpu5i_spstore_done;
    fpu5i.mosi          <= l5_intreg_mosi_none;  -- mosi from iu unused

-----------------------------------------------------------------------
-- LEON5 FETCH STAGE
-----------------------------------------------------------------------

    v.f.valid := '1';
    --address increment for the PC that accesses the instruction cache
    --on all kinds of transfer of control (PC mod 8) might become 4
    --in that case it should be incremented by 4
    next_pc_t := add('0'&r.f.pc, 8);
    next_pc   := next_pc_t(31 downto 0);
    if r.f.pc(2) = '1' then
      next_pc_t := std_logic_vector(unsigned('0'&r.f.pc) + 4);
      next_pc   := next_pc_t(31 downto 0);
    end if;

    comb_pc := r.f.pc;

    --hierarchical muxing to reduce critical path
    inst_mux_prio := xc_br_miss or mem_br_miss;
    branch_reg    := ra_br_miss or inst_mux_prio;
    if xc_br_miss = '1' then
      branch_reg_pc := xc_br_miss_pc;
    elsif mem_br_miss = '1' then
      branch_reg_pc := mem_br_miss_pc;
    else
      branch_reg_pc := ra_br_miss_pc;
    end if;

    --btb hit is only used for slot(0) hence if de_hold_pc is set
    --it means branch can not be dual issued but branch itself will be issued
    --and btb_hit will no longer needed
    v.d.btb_hit := '0';

    if de_hold_pc = '1' then
      v.d.pc := r.d.pc;
    else
      v.d.pc                 := r.f.pc;
      v.d.bht_taken          := bhto_taken;
      v.d.bht_data           := bhto.rdata(1 downto 0);
      v.d.bht_ctrl.bhistory  := bhto.bhistory;
      if dco.iuctrl.staticbp = '1' or BPRED = '0' then
        v.d.bht_data := (others=>'0');
        v.d.bht_ctrl.bhistory := (others=>'0');
      end if;
      v.d.bht_ctrl.btb_taken := bhto_taken;
    end if;

    if xc_rstn = '0' then
      de_inull := '1';
      if ((not ASYNC_RESET) or DYNRST) and (not RESET_ALL) then
        v.f.pc               := RRES.f.pc;
        v.f.pc(31 downto 12) := RRES.f.pc(31 downto 12);
      end if;
    elsif xc_exception = '1' then
      v.f.pc := xc_trap_address;
    elsif (exe_br_miss = '1' or exe_jmpl_ct = '1' or exe_rett_ct = '1') and inst_mux_prio = '0' then
      v.f.pc := exe_br_miss_pc;
    elsif branch_reg = '1' then
      v.f.pc := branch_reg_pc;
    elsif de_branch = '1' and r.d.mexc = '0' then
      --de_issue is removed from asserting de_branchl in order to
      --reduce the ciritcal path. If a branch can not be issued it mean iustall
      --is asserted hence there is no problem. But update v.f.pc only when
      --branch is actually issued and taken
      if hold_issue_s = '0' and ((de_branchl(0) = '1' and de_issue(0) = '1') or (de_branchl(1) = '1' and de_issue(1) = '1')) then
        v.f.pc := de_branch_addr_muxed;
      else
        iustall := '1';
      end if;
    elsif de_hold_pc = '1' or hold_issue_s = '1' then
      v.f.pc  := r.f.pc;
      iustall := '1';
    elsif btb_hitv = '1' and bhto_taken = '1' then
      v.f.pc      := btb_outdata;
      --during JMPL/RETT a branch an delay slot can be fetched
      --consecutively hence btb hit in that case will be invalid
      --as a result btb_hit is only set here
      v.d.btb_hit := btb_hitv;
    else
      v.f.pc := next_pc;
    end if;

    if r.d.pc_reset = '1' then
      iustall := '0';
    end if;

    --In order to reduce critical path next_pc has its own muxing
    --de_hold_pc and hold_issue_s is handled with iustall
    if xc_rstn = '0' then
      next_pc := r.f.pc;
    elsif xc_exception = '1' then
      next_pc := xc_trap_address;
    elsif (exe_br_miss = '1' or exe_jmpl_ct = '1' or exe_rett_ct = '1') and inst_mux_prio = '0' then
      next_pc := exe_br_miss_pc;
    elsif branch_reg = '1' then
      next_pc := branch_reg_pc;
    elsif de_branch = '1' and r.d.mexc = '0' then
      next_pc := de_branch_addr_muxed;
    elsif r.d.speculative_lock = '1' and speculative_lock_release = '0' then
      --it might be possible to use br_taken_pc or br_ntaken_pc for
      --pc_reset
      next_pc := r.f.pc;
    elsif btb_hitv = '1' and bhto_taken = '1' then
      next_pc := btb_outdata;
    end if;

    --fanout splitting to reduce
    --critical path
    v.f.btb_pc  := v.f.pc;
    v.f.bht_pc  := v.f.pc;
    v.f.bht_pc2 := v.f.pc;

 
    comb_pc := next_pc;

    if xc_rstn = '0' then
      v.d.pc := RRES.f.pc;
    end if;

    ici.dpc           <= r.d.pc;
    ici.fpc           <= r.f.pc;
    ici.rpc           <= comb_pc;
    bhti.rindex_bhist <= comb_pc&comb_pc;

    ici.su       <= v.a.su;
    ici.fbranch  <= '0';
    ici.rbranch  <= '1';                -- Temp enables itags every cycle
    ici.fline    <= (others => '0');
    ici.pnull    <= '0';
    ici.inull    <= de_inull;
    ici.nobpmiss <= ic_spec_access;
    ici.flush    <= me_iflush;

-----------------------------------------------------------------------
-----------------------------------------------------------------------

    if DBGUNIT then                     -- DSU diagnostic read
      diagread(dbgi, r, dsur, ir, wpr, dco, diagdata);
      vdsu.crdy := dsur.crdy(1) & '0';
      if r.m.dci.dsuen = '1' then
        vdsu.crdy(2) := dco.hold and not r.m.dci.enaddr;
      end if;
    end if;
    v.x.miso.rddata := diagdata;


    if mem_jmpl_rett_op = '1' then
      --if there is a sequence of jmpl/bicc,a this will set the
      --next pc correctly for bicc,a
      v.a.bht_ctrl.pc_delay_slot := r.m.jmpl_taddr;
      v.e.bht_ctrl.pc_delay_slot := r.m.jmpl_taddr;
      v.m.bht_ctrl.pc_delay_slot := r.m.jmpl_taddr;
    end if;

    --if a resolvable branch gets hold issue due to the other instruction in
    --the pair an fpc instruction in decode stage will continously issue/unissue
    --in order to prevent that we set this bit and it automatically clears when
    --hold issue is deasserted. Note that once a branch miss is asserted it is
    --final and can not change hence there is no problem.
    v.d.fpc_annuled := '0';

    v_d_inst             := v.d.inst;
    v_d_way              := v.d.way;
    v_d_mexc             := v.d.mexc;
    v_a_astate           := v.a.astate;
    v_a_atomic_cnt       := v.a.atomic_cnt;
    v_e_ctrl_inst_valid0 := v.e.ctrl.inst_valid(0);
    v_a_casa             := v.a.casa;
    v_d_iudiags          := v.d.iudiags;
    v_d_iudiag_miso      := v.d.iudiag_miso;
    v_d_diag_btb_flush   := v.d.diag_btb_flush;
    v_d_diag_bht_flush   := v.d.diag_bht_flush;
    v_d_btb_diag_in      := v.d.btb_diag_in;
    v_d_bht_diag_in_en   := v.d.bht_diag_in_en;
    v_d_bht_diag_in_wren := v.d.bht_diag_in_wren;
    if ((hold_issue = '1' or atomic_hold_issue = '1') and v.x.annul_all = '0' and exe_br_miss = '0' and mem_br_miss = '0' and exe_jmpl_ct = '0' and exe_rett_ct = '0' and xc_br_miss = '0') then
      v.a                 := r.a;
      v.d                 := r.d;
      v.f                 := r.f;
      v.e.ctrl.inst_valid := "00";
      v.e.fpc_ctrl.issued := '0';
      v.e.ctrl.wy         := "00";
      --there can be only 1 delay slot instruction in two slots
      if exe_delay_annul = '1' then
        if r.a.ctrl.delay_inst(0) = '1' and r.a.ctrl.inst_valid(0) = '1' then
          v.a.ctrl.inst_valid(0) := '0';
        elsif r.a.ctrl.delay_inst(1) = '1' and r.a.ctrl.inst_valid(1) = '1' then
          v.a.ctrl.inst_valid(1) := '0';
        end if;
      end if;

      --delay_no_annul can only happen on a branch missprediction hence need
      --not to be handled here


      if r.a.divstart = '1' and mask_divstart = '0' then
        v.a.divstart := '0';
      end if;

      if holdn = '0' and ico.mds = '0' then
        v.d.inst           := v_d_inst;
        v.d.way            := v_d_way;
        v.d.mexc           := v_d_mexc;
      end if;
      if holdn = '0' then
        v.d.iudiags          := v_d_iudiags;
        v.d.iudiag_miso      := v_d_iudiag_miso;
        v.d.diag_btb_flush   := v_d_diag_btb_flush;
        v.d.diag_bht_flush   := v_d_diag_bht_flush;
        v.d.btb_diag_in      := v_d_btb_diag_in;
        v.d.bht_diag_in_en   := v_d_bht_diag_in_en;
        v.d.bht_diag_in_wren := v_d_bht_diag_in_wren;
      end if;

      if r.d.ico_bpmiss = '0' then
        if ico.bpmiss = '1' then
          v.d.ico_bpmiss := '1';
        end if;
      end if;

      if mem_jmpl_rett_op = '1' then
        --if there is a sequence of jmpl/bicc,a this will set the
        --next pc correctly for bicc,a
        v.a.bht_ctrl.pc_delay_slot := r.m.jmpl_taddr;
      end if;

      -------------------------------------------------------------------------
      --FPU related
      -------------------------------------------------------------------------
      if FPEN then
        if fpu5i_issue_cmd /= "000" and fpu5i_issue_cmd /= "100" and fpu5i_issue_cmd /= "110" then
          if v_d_fpc_annuled = '0' then
            v.d.fpc_issued      := '1';
            v.d.fpc_ctrl.issued := '1';
            v.d.fpc_ctrl.opid   := fpu5o.issue_id;
            if fpu5i_issue_cmd = "010" then
              v.d.fpc_ctrl.issued := '0';
            end if;
          else
            v.d.fpc_annuled := '1';
          end if;
        end if;
      end if;

      -------------------------------------------------------------------------
      --Atomic instruction related
      -------------------------------------------------------------------------
      if hold_issue = '0' then
        if v_e_ctrl_inst_valid0 = '1' and v.e.ctrl.trap(0) = '0' then
          v.a.astate             := v_a_astate;
          v.a.casa               := v_a_casa;
          v.e.ctrl.no_forward(0) := r.a.ctrl.no_forward(0);
          v.a.atomic_cnt         := v_a_atomic_cnt;
          --CASA instruction never has rs2 as address offset
          if v_a_casa = '1' then
            v.e.ldfwd_rs2(0)      := '0';
            v.e.use_muldiv_rs2(0) := '0';
          end if;
          if v_a_astate = ld_exe then
            v.e.ctrl.rdw(0)        := '1';
            v.e.ctrl.inst_valid(0) := '1';
          end if;
        else
          if r.a.astate /= idle and r.a.astate /= count then
            atomic_nullify := '1';
          end if;
        end if;
      end if;
    end if;

    if r.a.astate = ld_exc then
      if r.a.casa = '1' and r.m.casz = '0' and holdn = '1' then
        atomic_nullify := '1';
      end if;
    end if;

    atomic_nullify_s <= atomic_nullify;


    if hold_issue = '1' and (exe_br_miss /= '0' or mem_br_miss /= '0' or exe_jmpl_ct /= '0' or exe_rett_ct /= '0' or xc_br_miss /= '0') then

      --when a delay slot instruction is holding the issue and a branch
      --missprediction happens the instruction is still hold in the issue
      --stage otherwise forwarding will fail. This way we can completely avoid
      --to hold the pipeline in executage stage also.

      --This also solves the problem if delay instruction of JMPL is aligned to
      --0x0 (meaning on a different pair) and needs to stall due to instruction
      --dual issued with JMPL

      v.a := r.a;

      if v.e.ctrl.inst_valid(0) = '0' then
        v.a.ctrl.inst_valid(0) := '0';
      else
        v.e.ctrl.inst_valid(0) := '0';
      end if;

      if v.e.ctrl.inst_valid(1) = '0' then
        v.a.ctrl.inst_valid(1) := '0';
      else
        v.e.ctrl.inst_valid(1) := '0';
      end if;

      if v.e.ctrl.delay_annuled(0) = '0' then
        v.a.ctrl.delay_annuled(0) := '0';
      end if;

      if v.e.ctrl.delay_annuled(1) = '0' then
        v.a.ctrl.delay_annuled(1) := '0';
      end if;

      if v.e.fpc_ctrl.issued = '0' then
        v.a.fpc_ctrl.issued := '0';
      else
        v.e.fpc_ctrl.issued := '0';
      end if;
      
    end if;

    if hold_issue = '0' then
      v.d.pc_reset := '0';
    end if;

    if r.d.speculative_insts = '1' and r.d.pc_reset = '0' and v.d.speculative_lock = '1' then
      --there was a speculative ic miss
      --load back the value to v.f.pc
      --otherwise it will be lost
      --any branch or trap will deassert the
      --speculative lock signal hence there
      --is no problem
      v.f.pc       := r.d.pc;
      v.f.btb_pc   := v.f.pc;
      v.f.bht_pc   := v.f.pc;
      v.f.bht_pc2  := v.f.pc;
      v.d.pc_reset := '1';

      --special cases
      --some cases require instruction replay otherwise
      --it would be hard to recover for example if
      --instruction was a delay slot
      --the code is placed here to overwrite valid bits in case
      --hold issue is set
      if r.d.delay_slot = '1' then
        if is_toc(r.a.ctrl.inst(0)) = '1' and r.a.ctrl.inst_valid(0) = '1' then
          v.f.pc                 := r.a.ctrl.inst_pc(0);
          v.a.ctrl.inst_valid(0) := '0';
          v.e.ctrl.inst_valid(0) := '0';
          v.d.ct_state           := idle;
        end if;
        if is_toc(r.a.ctrl.inst(1)) = '1' and r.a.ctrl.inst_valid(1) = '1' then
          v.f.pc                 := r.a.ctrl.inst_pc(1);
          v.a.ctrl.inst_valid(1) := '0';
          v.e.ctrl.inst_valid(1) := '0';
          v.d.ct_state           := idle;
        end if;
      end if;
      
    end if;

    if hold_issue_s = '1' and FPEN then

      v.d.fpc_ctrl.issue_lane := '0';
      if r.d.inst_valid(0) = '0' or (r.d.inst_valid(0) = '1' and is_fpop(de_inst(0)) = '0') then
        v.d.fpc_ctrl.issue_lane := '1';
      end if;

      if r.a.fp_stdata_latched = '0' and is_fpu_store(r.a.ctrl.inst(0)) = '1' then
        v.a.fp_stdata_latched := '1';
        v.a.fpustdata         := fpu5o.stdata;
        if r.d.fp_stdata_latched = '1' then
          v.a.fpustdata := r.d.fpustdata;
        end if;
      end if;

      --v.d.fp_stdata_latched is not deasserted by default
      --if v.d.fp_stdata_latched is forced to '0' that means the corresponding
      --fpc operation is annuled while hold_issue is asserted hence dont assert
      --fp_stdata_latched otherwise it will get stuck to '1' and cause wrong behavior
      --later on
      --if holdn is deasserted v.d.fp_stdata_latched will be asserted in this
      --case but it will correct itself when holdn is asserted itself again
      if r.d.fpc_issued = '1' and r.d.fp_stdata_latched = '0' and de_fpc_stdata_latch_mask /= '1' and FPEN then
        v.d.fp_stdata_latched := '1';
        v.d.fpustdata         := fpu5o.stdata;
      end if;
    end if;

    for i in 0 to 1 loop
      if ((r.a.e_annul_align4(i) = '1' or r.a.e_cond_annul_align4(i) = '1') and r.a.ctrl.inst_valid(i) = '1') then
        if hold_issue_s = '1' then
          --back to back CTI and the second CTI can not arrive just after the
          --first CTI to execute stage hence cancel_annul approach should be used
          v.a.e_cancel_annul(i) := '1';
        end if;
        if r.e.ctrl.inst_valid = "00" then
          --second CTI is delayed iustall is needed in order to keep
          --the PC of first CTI in the IC
          if xc_br_miss = '0' and mem_br_miss = '0' and v.x.annul_all = '0' then
            iustall := '1';
          end if;
        end if;
      end if;
    end loop;


    ici.iustall <= iustall;


    ---------------------------------------------------------------------------
    --DEBUG
    ---------------------------------------------------------------------------

    v.d.holdn_deadlock_counter := (others => '0');
    if holdn = '0' then
      holdn_deadlock_counter_tmp := std_logic_vector(unsigned('0'&r.d.holdn_deadlock_counter)+1);
      v.d.holdn_deadlock_counter := holdn_deadlock_counter_tmp(19 downto 0);
      if r.w.s.holdn_deadlock = '0' then
        v.w.s.holdn_deadlock := holdn_deadlock_counter_tmp(20);
      end if;
    end if;

    v.d.fpc_deadlock_counter := (others => '0');
    if r.d.inst_valid(0) = '1' and is_fpop(de_inst(0)) = '1' and de_fpc_issue(0) = '0' and r.d.fpc_issued = '0' then
      fpc_deadlock_counter_tmp := std_logic_vector(unsigned('0'&r.d.fpc_deadlock_counter)+1);
      v.d.fpc_deadlock_counter := fpc_deadlock_counter_tmp(19 downto 0);
      if r.w.s.fpc_deadlock = '0' then
        v.w.s.fpc_deadlock := fpc_deadlock_counter_tmp(9);
      end if;
    end if;

    if r.d.inst_valid(1) = '1' and is_fpop(de_inst(1)) = '1' and de_fpc_issue(1) = '0' and r.d.fpc_issued = '0' then
      fpc_deadlock_counter_tmp := std_logic_vector(unsigned('0'&r.d.fpc_deadlock_counter)+1);
      v.d.fpc_deadlock_counter := fpc_deadlock_counter_tmp(19 downto 0);
      if r.w.s.fpc_deadlock = '0' then
        v.w.s.fpc_deadlock := fpc_deadlock_counter_tmp(9);
      end if;
    end if;

    v.d.hissue_deadlock_counter := (others => '0');
    if hold_issue_s = '1' then
      hissue_deadlock_counter_tmp := std_logic_vector(unsigned('0'&r.d.hissue_deadlock_counter)+1);
      v.d.hissue_deadlock_counter := hissue_deadlock_counter_tmp(19 downto 0);
      if r.w.s.hissue_deadlock = '0' then
        v.w.s.hissue_deadlock := hissue_deadlock_counter_tmp(20);
      end if;
    end if;


    if r.x.rstate = dsu2 then
      v.d.holdn_deadlock_counter  := (others => '0');
      v.d.fpc_deadlock_counter    := (others => '0');
      v.d.hissue_deadlock_counter := (others => '0');
    end if;


    ---------------------------------------------------------------------------
    if r.x.debug_ret = '1' then
      if r.f.pc(2) = '0' then
        v.d.inst_valid := "01";
      else
        v.d.inst_valid := "10";
      end if;
    end if;

    v.d.br_flush := v.d.br_flush or r.d.diag_bht_flush;

-----------------------------------------------------------------------
-- OUTPUTS
-----------------------------------------------------------------------

    div_op1_muxed := ex_op1(1);
    div_op2_muxed := ex_op2(1);         
                                        
    div_sign      := r.e.ctrl.inst(1)(19);
    div_a_sign    := r.a.ctrl.inst(1)(19);

    div_a_valid := r.a.ctrl.inst_valid(1);

    if (not ASYNC_RESET) and (not RESET_ALL) and (xc_rstn = '0') then
      v.a.rs1                 := (others => (others => '0'));
      v.a.rs2                 := (others => (others => '0'));
      v.a.rs3                 := (others => '0');
      v.a.ctrl.trap           := "00";
      v.x.ctrl                := pipeline_ctrl_none;
      v.m.ctrl                := pipeline_ctrl_none;
      v.e.ctrl                := pipeline_ctrl_none;
      v.a.ctrl                := pipeline_ctrl_none;
      v.f.valid               := '1';
      v.d.ct_state            := idle;
      v.d.hold_only_pcreg     := '0';
      v.d.inst_valid          := "00";
      v.d.rett_op_delayed     := '0';
      v.d.delay_slot          := '0';
      v.d.delay_slot_annuled  := '0';
      v.d.mexc                := '0';
      v.d.pc_reset            := '0';
      v.d.speculative_insts   := '0';
      v.d.speculative_lock    := '0';
      v.d.ico_bpmiss          := '0';
      v.a.call_op             := "00";
      v.e.call_op             := "00";
      v.a.e_annul_align4      := "00";
      v.a.e_cond_annul_align4 := "00";
      v.a.e_cancel_annul      := "00";
      v.e.e_annul_align4      := "00";
      v.e.e_cond_annul_align4 := "00";
      v.e.e_cancel_annul      := "00";
      v.a.astate              := idle;
      v.a.casa                := '0';
      v.a.atomic_nullified    := '0';
      v.a.bp_disabled         := '0';
      v.a.spec_check          := "00";
      v.d.b2bstore_en         := '1';
      v.d.specload_en         := '1';
      v.d.dual_ldissue_en     := '1';
      v.d.br_flush            := '0';
    end if;


    ---------------------------------------------------------------------------
    -- perf counter
    ---------------------------------------------------------------------------
    if r_x_ctrl_br_missp = '1' then
      if (is_branch(r.x.ctrl.inst(0)) = '1' and r.x.ctrl.inst_valid(0) = '1' and mask_we1 = '0') or
        (is_branch(r.x.ctrl.inst(1)) = '1' and r.x.ctrl.inst_valid(1) = '1' and mask_we2 = '0') then
        v.d.br_counting := '1';
      end if;

    end if;

    if r.d.br_counting = '1' then

      if r.x.ctrl.inst_valid(0) = '1' and mask_we1 = '0' and r.x.ctrl.delay_inst(0) = '0' then
        v.d.br_counting := '0';
      end if;

      if r.x.ctrl.inst_valid(1) = '1' and mask_we2 = '0' and r.x.ctrl.delay_inst(1) = '0' then
        v.d.br_counting := '0';
      end if;

      --  v.d.branch_miss_counter := std_logic_vector(unsigned(r.d.branch_miss_counter)+1);
    end if;

    --valid inst on lane-0  (index-0)
    v.perf(0)           := r.x.ctrl.inst_valid(0) and not(mask_we1) and not(xc_trap and not(xc_trapl)) and holdn;
    --valid inst on lane-1  (index-1)
    v.perf(1)           := r.x.ctrl.inst_valid(1) and not(mask_we2) and not(xc_trap and xc_trapl) and holdn;
    --branch on lane-0   (index-2)
    v.perf(2)           := '0';
    if is_branch(r.x.ctrl.inst(0)) = '1' and holdn = '1' then
      v.perf(2) := '1';
    end if;
    --branch on lane-1  (index-3)
    v.perf(3) := '0';
    if (is_branch(r.x.ctrl.inst(1)) = '1' or is_fpu_branch(r.x.ctrl.inst(1)) = '1') and holdn = '1' then
      v.perf(3) := '1';
    end if;
    --misspredict (index-4)
    v.perf(4) := r_x_ctrl_br_missp and holdn;
    --ncycles lost on holdn (index-5) asserted on sequential process
    v.perf(5) := '0';
    --ncycles lost on branch misspredict (index-6)
    v.perf(6) := r.d.br_counting and holdn;
    --number of stores (index-7)
    v.perf(7) := '0';
    if is_store(r.x.ctrl.inst(0)) = '1' and holdn = '1' then
      v.perf(7) := '1';
    end if;
    --number of load (index-8)
    v.perf(8) := '0';
    if is_load(r.x.ctrl.inst(0)) = '1' and holdn = '1' then
      v.perf(8) := '1';
    end if;
    --is fpu operation lane-0 (index-9)
    v.perf(9) := '0';
    if (is_fpop(r.x.ctrl.inst(0)) = '1' or is_fpu_branch(r.x.ctrl.inst(0)) = '1') and holdn = '1' then
      v.perf(9) := '1';
    end if;
    --s fpu operation lane-1 (index-10)
    v.perf(10) := '0';
    if (is_fpop(r.x.ctrl.inst(1)) = '1' or is_fpu_branch(r.x.ctrl.inst(1)) = '1') and holdn = '1' then
      v.perf(10) := '1';
    end if;
    --cpu is not in debugmode
    v.perf(11) := '0';
    if r.x.cpustate = CPUSTATE_RUNNING or r.x.cpustate = CPUSTATE_INSLEEP then
      v.perf(11) := '1';
    end if;
    perf <= r.perf;

    rin                    <= v;
    wprin                  <= vwpr;
    dsuin                  <= vdsu;
    irin                   <= vir;
    muli.start             <= r.a.mulstart and ((v.e.ctrl.inst_valid(0) and not(r.a.mul_lane)) or (v.e.ctrl.inst_valid(1) and r.a.mul_lane));
    muli.signed            <= r.e.mul_sign;
    muli.op1               <= (mul_op1_muxed(31) and r.e.mul_sign) & mul_op1_muxed;
    muli.op2               <= (mul_op2_muxed(31) and r.e.mul_sign) & mul_op2_muxed;
    muli.mac               <= '0';  --r.e.inst(0)(24);        --!!!not implemented yet for LEON5
    if MACPIPE then
      muli.acc(39 downto 32) <= r.w.s.y(7 downto 0);
    else
      muli.acc(39 downto 32) <= r.x.y(7 downto 0);
    end if;
    muli.acc(31 downto 0) <= r.w.s.asr18;
    muli.flush            <= '0';  
    ---------------------------------------------------------------------------
    --holdn is handled internally in the division unit
    divi.start            <= divi_start;
    divi.signed           <= div_a_sign;
    divi.flush            <= r.x.annul_all or div_flush;
    divi.op1              <= (div_op1_muxed(31) and div_a_sign) & div_op1_muxed;
    divi.op2              <= (div_op2_muxed(31) and div_a_sign) & div_op2_muxed;
    dsign                 := div_a_sign;
    divi.y                <= (r.m.y(31) and dsign) & r.m.y;
    ---------------------------------------------------------------------------
    rpin                  <= vp;
    urin                  <= vu;


    dbgo.cpustate <= r.x.cpustate;
    dbgo.miso     <= r.x.miso;
    wakeup_req    := '0';
    if r.x.ipend = '1' and r.x.cpustate = CPUSTATE_INSLEEP then
      wakeup_req := '1';
    end if;
    dbgo.wakeup_req <= wakeup_req;
    dbgo.c2c_mosi <= l5_intreg_mosi_none;



    -------------------------------------------------------------------------------
    --BHT
    ---------------------------------------------------------------------------

    --Enable branch prediction SRAM read if actually there is a branch instruction
    bhti_ren := '0';
    if (r.e.ctrl.inst_valid(0) = '1' and is_branch(r.e.ctrl.inst(0)) = '1') or
      (r.e.ctrl.inst_valid(1) = '1' and is_branch(r.e.ctrl.inst(1)) = '1') then
      bhti_ren := '1';
    end if;

    if BPRED = '0' or dco.iuctrl.staticbp = '1' then
      bhti_ren := '0';
    end if;

    bhti_raddr_final := x"00000000"&r.e.ctrl.inst_pc(0);
    if r.e.ctrl.inst_valid(1) = '1' and is_branch(r.e.ctrl.inst(1)) = '1' then
      bhti_raddr_final := x"00000000"&r.e.ctrl.inst_pc(1);
    end if;

    bhti_waddr_final := x"00000000"&r.x.ctrl.inst_pc(0);
    if bhti_waddr_mux = '1' then
      bhti_waddr_final := x"00000000"&r.x.ctrl.inst_pc(1);
    end if;

    bhti.raddr_comb <= bhti_raddr_final;
    bhti.waddr      <= bhti_waddr_final;
    bhti.taken      <= r_x_br_taken;
    bhti.wen        <= bhti_wen and holdn and BPRED and not(dco.iuctrl.staticbp) and not(dco.iuctrl.fbp);
    bhti.flush      <= r.d.br_flush;
    bhti.bhistory   <= r.x.bht_ctrl.bhistory;
    bhti.phistory   <= r.x.bht_ctrl.phistory;
    bhti.btb_taken  <= r.x.bht_ctrl.btb_taken;
    bhti.ren        <= bhti_ren;
    bhti.iustall    <= iustall;

    btb_wen    <= btb_wen_v and holdn and not(dco.iuctrl.dbtb) and icache_en and not(dco.iuctrl.fbtb);
    btb_instpc <= btb_instpc_v;
    btb_indata <= btb_indata_v;

    diag_btb_flush := '0';
    if r.x.rstate /= run and r.x.rstate /= trap then
      --when GRMON flushes icache, flush BTB also
      if ico.btb_flush = '1' then
        diag_btb_flush := '1';
      end if;
    end if;
    btb_flush <= v.e.ctrl.ctx_switch or r.e.ctrl.ctx_switch or r.m.ctrl.ctx_switch or r.x.ctrl.ctx_switch or not(xc_rstn) or r.d.br_flush or diag_btb_flush or r.d.diag_btb_flush;

    bht_diag_in.en       <= r.d.bht_diag_in_en;
    bht_diag_in.wren     <= r.d.bht_diag_in_wren;
    bht_diag_in.addr     <= r.d.btb_diag_in.addr;
    bht_diag_in.wrdata   <= r.d.btb_diag_in.wrdata;
    btb_diag_in          <= r.d.btb_diag_in;
    
  end process;

  bht0 : bht_pap
    generic map(
      tech     => memtech,
      nentries => 128,
      hlength  => 4,
      testen   => scantest)
    port map(
      clk      => clk,
      rstn     => rstn,
      holdn    => holdn,
      bhti     => bhti,
      bhto     => bhto,
      diag_in  => bht_diag_in,
      diag_out => bht_diag_out,
      testin   => testin
      );
 
  btb0 : btb
    generic map(
      nentries => 16)
    port map(
      clk         => clk,
      rstn        => rstn,
      btb_flush   => btb_flush,
      btb_wen     => btb_wen,
      btb_instpc  => btb_instpc,
      btb_indata  => btb_indata,
      btb_pcread  => r.f.btb_pc,
      btb_hit     => btb_hit,
      btb_outdata => btb_outdata,
      diag_in     => btb_diag_in,
      diag_out    => btb_diag_out);


  syncrregs : if not ASYNC_RESET generate
    preg : process (uclk)
    begin
      if rising_edge(uclk) then
        rp <= rpin;
        if rstn = '0' then
          rp.error <= PRES.error;
          rp.pwd   <= rstv_pwd;
          --pragma translate_off
          rp.error <= '0';
          --pragma translate_on
        end if;
      end if;
    end process;

    reg : process (clk)
    begin
      if rising_edge(clk) then
        if (holdn = '1') then
          r <= rin;
        else
          if dbgi.pushpc = '1' then
            r.f.pc <= rin.f.pc;
          end if;
          r.w.fpu_unissue             <= rin.w.fpu_unissue;
          r.w.fp_exc_ack              <= rin.w.fp_exc_ack;
          r.w.tdata                   <= rin.w.tdata;
          r.w.s.holdn_deadlock        <= rin.w.s.holdn_deadlock;
          r.w.s.fpc_deadlock          <= rin.w.s.fpc_deadlock;
          r.w.s.hissue_deadlock       <= rin.w.s.hissue_deadlock;
          r.d.iudiag_miso             <= rin.d.iudiag_miso;
          r.d.holdn_deadlock_counter  <= rin.d.holdn_deadlock_counter;
          r.d.fpc_deadlock_counter    <= rin.d.fpc_deadlock_counter;
          r.d.hissue_deadlock_counter <= rin.d.hissue_deadlock_counter;
          r.x.ipend                   <= rin.x.ipend;
          if r.x.rstate /= run then
            r.x.cpustate <= rin.x.cpustate;
          end if;
          if r.x.rstate = dsu4 then
            r.x.rstate <= rin.x.rstate;
          end if;
          r.x.miso <= rin.x.miso;
          r.m.werr <= rin.m.werr;
          r.m.casz <= rin.m.casz;
          if (holdn or ico.mds) = '0' then
            r.d.inst <= rin.d.inst;
            r.d.mexc <= rin.d.mexc;
            r.d.way  <= rin.d.way;
          end if;
          if (holdn or dco.mds) = '0' then
            r.x.data <= rin.x.data;
            r.x.mexc <= rin.x.mexc;
            r.x.way  <= rin.x.way;
          end if;
          --BHT/BTB diagnostic
          r.d.iudiags          <= rin.d.iudiags;
          r.d.diag_btb_flush   <= rin.d.diag_btb_flush;
          r.d.diag_bht_flush   <= rin.d.diag_bht_flush;
          r.d.btb_diag_in      <= rin.d.btb_diag_in;
          r.d.bht_diag_in_en   <= rin.d.bht_diag_in_en;
          r.d.bht_diag_in_wren <= rin.d.bht_diag_in_wren;
          if FPEN then
            if holdn = '0' and is_fpu_store(r.a.ctrl.inst(0)) = '1' then
              if r.a.fp_stdata_latched = '0' then
                r.a.fp_stdata_latched <= '1';
                r.a.fpustdata         <= fpu5o.stdata;
                if r.d.fp_stdata_latched = '1' then
                  r.a.fpustdata <= r.d.fpustdata;
                end if;
              end if;
            end if;
            if holdn = '0' and r.d.fpc_issued = '1' then
              if r.d.fp_stdata_latched = '0' then
                r.d.fp_stdata_latched <= '1';
                r.d.fpustdata         <= fpu5o.stdata;
              end if;
            end if;
          end if;
        end if;
        if rstn = '0' then
            r <= RRES;
        end if;
      end if;
    end process;

    dsugen : if DBGUNIT generate
      dsureg : process(clk)
      begin
        if rising_edge(clk) then
          if holdn = '1' then
            dsur <= dsuin;
          else
            dsur.crdy <= dsuin.crdy;
          end if;
          if rstn = '0' then
            dsur <= DRES;
          end if;
        end if;
      end process;
    end generate;

    irreg : if (DBGUNIT or PWRD2) generate
      dsureg : process(clk)
      begin
        if rising_edge(clk) then
          if holdn = '1' or dbgi.pushpc = '1' then
            ir <= irin;
          end if;
          if rstn = '0' then
            ir <= IRES;
          end if;
        end if;
      end process;
    end generate;

    wpgen : for i in 0 to 3 generate
      wpg0 : if nwp > i generate
        wpreg : process(clk)
        begin
          if rising_edge(clk) then
            if holdn = '1' then
              wpr(i) <= wprin(i);
            end if;
            if rstn = '0' then
              wpr(i) <= WRES;
            end if;
          end if;
        end process;
      end generate;
      wpg1 : if nwp <= i generate
        wpr(i) <= wpr_none;
      end generate;
    end generate;
  end generate;

  ungreg: process(uclk)
  begin
    if rising_edge(uclk) then
      ur <= urin;
      if rstn='0' then
        ur <= (captcmd => "000");
      end if;
    end if;
  end process;


  nirreg : if not (DBGUNIT or PWRD2) generate
    ir.pwd <= '0'; ir.addr <= (others => '0');
  end generate;

  --pragma translate_off
  dis1 : if disas > 0 generate
    trc : process(clk)
      variable valid       : std_logic_vector(1 downto 0);
      variable valids      : std_logic_vector(1 downto 0);
      variable op          : std_logic_vector(1 downto 0);
      variable op3         : std_logic_vector(5 downto 0);
      variable fpins, fpld : boolean;
      variable pc          : inst_pc_type;  --std_logic_vector(31 downto 0);
      variable in_irq      : std_logic := '0';
      type repeat_type is array (0 to 1) of boolean;
    begin
      if (disas > 0) and rising_edge(clk) and (rstn = '1') then
        for i in 0 to 1 loop
          if (fpu /= 0) then
            --op := r.x.ctrl.inst(31 downto 30);
            --  op3 := r.x.ctrl.inst(24 downto 19);
            -- fpins := (op = FMT3) and ((op3 = FPOP1) or (op3 = FPOP2));
            -- fpld := (op = LDST) and ((op3 = LDF) or (op3 = LDDF) or (op3 = LDFSR));
          else
            --  fpins := false; fpld := false;
          end if;

          valid(i) := '0';
          valids(i) := '0';
          if r.x.ctrl.inst_valid(i) = '1' and r.x.annul_all /= '1' and mask_we_dbg(i) = '0' then
            valid(i) := '1';
            valids(i) := '1';
          end if;


          valid(i) := valid(i) and holdn;
          valids(i) := valids(i) and holdn;

          if false then
            if r.w.s.et = '0' and r.w.s.tt(5 downto 4) = "01" then
              valid(i) := '0';
              valids(i) := '0';
              in_irq   := '1';
            end if;
            if xc_trapl_dbg = '0' and i = 0 and xc_trap_dbg = '1' and r.x.ctrl.tt(0)(5 downto 4) = "01" then
              valid(0) := '0';
              valids(0) := '0';
            end if;
            if xc_trapl_dbg = '1' and i = 1 and xc_trap_dbg = '1' and r.x.ctrl.tt(1)(5 downto 4) = "01" then
              valid(1) := '0';
              valids(1) := '0';
            end if;

            if in_irq = '1' then
              valid := "00";
              valids := "00";
            end if;

            if r.x.ctrl.rett_op = '1' and r.x.ctrl.inst_valid(1) = '1' then
              in_irq := '0';
            end if;
          end if;


          pc(i) := r.x.ctrl.inst_pc(i);
        end loop;

        if rising_edge(clk) and (rstn = '1') then

          if r.x.ctrl.swap = '0' then

              print_insn (conv_integer(cpu_index),
                          pc(0),
                          r.x.ctrl.inst(0),
                          rfi_wdata1_dbg(63 downto 32),  
                          valid(0) = '1',
                          r.x.ctrl.trap(0) = '1',
                          (r.x.ctrl.rdw(0) and not(is_div(r.x.ctrl.inst(0)))) = '1',
                          false);
              print_insn (conv_integer(cpu_index),
                          pc(1),
                          r.x.ctrl.inst(1),
                          rfi_wdata2_dbg(63 downto 32),  
                          valid(1) = '1',
                          r.x.ctrl.trap(1) = '1',
                          (r.x.ctrl.rdw(1) and not(is_div(r.x.ctrl.inst(1)))) = '1',
                          false);
          else

              print_insn (conv_integer(cpu_index),
                          pc(1),
                          r.x.ctrl.inst(1),
                          rfi_wdata2_dbg(63 downto 32), 
                          valid(1) = '1',
                          r.x.ctrl.trap(1) = '1',
                          (r.x.ctrl.rdw(1) and not(is_div(r.x.ctrl.inst(1)))) = '1',
                          false);

              print_insn (conv_integer(cpu_index),
                          pc(0),
                          r.x.ctrl.inst(0),
                          rfi_wdata1_dbg(63 downto 32),  
                          valid(0) = '1',
                          r.x.ctrl.trap(0) = '1',
                          (r.x.ctrl.rdw(0) and not(is_div(r.x.ctrl.inst(0)))) = '1',
                          false);
          end if;
          
        end if;
      end if;
    end process;
  end generate;
  --pragma translate_on


end;

