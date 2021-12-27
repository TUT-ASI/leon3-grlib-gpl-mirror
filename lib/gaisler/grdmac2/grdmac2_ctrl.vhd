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
-- Entity:      grdmac2_ctrl
-- File:        grdmac2_ctrl.vhd
-- Author:      Krishna K R - Cobham Gaisler AB
-- Description: Main control module for DMA.
------------------------------------------------------------------------------ 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;
library gaisler;
use gaisler.grdmac2_pkg.all;
library techmap;
use techmap.gencomp.all;

-----------------------------------------------------------------------------
-- Control module with main state machine for conditional and data execution
------------------------------------------------------------------------------
-- If GRDMAC2 core is enabled and no error exists, descriptor is read from the
-- first descriptor pointer. Descriptor is then decoded and executed based on
-- the descriptor type. Conditional descriptors(polling and triggering)
-- execution is implemented within the control module itself. Where as data
-- descriptor execution is split to M2B and B2M operation, which is implemented
-- in mem2buf.vhd and buf2mem.vhd. Descriptor write back is implemented in
-- control module. Based on the generic en_bm1 and bus master interface index
-- field in each descriptor, M2B/ B2M signals are connected to either Bus Master
-- interface 0 or Bus Master interface 1.
-- Every time a descriptor is completed, execution comes to idle state before
-- proceeding to next descriptor in the queue.
-----------------------------------------------------------------------------

entity grdmac2_ctrl is
  generic (
    dbits : integer range 32 to 128 := 32  -- Bus master front end data width     
    );
  port (
    rstn          : in  std_ulogic;                     -- Active low reset signal
    clk           : in  std_ulogic;                     -- Clock
    trigger       : in  std_logic_vector(63 downto 0);  -- Input trigger
    -- ctrl signals from APB interface
    ctrl          : in  grdmac2_ctrl_reg_type;          -- Control signals from APB interface
    des_ptr       : in  grdmac2_desc_ptr_type;          -- First descriptor pointer
    active        : in  std_ulogic;                     -- Core enabled after reset?
    trst          : in  grdmac2_trst_reg_type;          -- Timer reset value for timeout mechanism
    err_status    : in  std_ulogic;                     -- Core error status from APB status register    
    curr_desc_out : out curr_des_out_type;              -- Current descriptor field out for debug display
    curr_desc_ptr : out std_logic_vector(31 downto 0);  -- Current descriptor pointer for debug display
    status        : out status_out_type;                -- Status signals
    irq_flag_sts  : out std_ulogic;                     -- IRQ status flag
    --Bus Master signals
    bm_in         : in  bm_out_type;                    -- BM signals from Bus master to control module
    bm_out        : out bm_in_type;                     -- BM signals to BusMaster interface from control module
    bm_num        : out std_ulogic;                     -- Bus master index out
    -- M2B BM signals
    m2b_bm_in     : in  bm_ctrl_reg_type;               -- BM signals from M2B through control module  
    m2b_bm_out    : out bm_out_type;                    -- BM signals to M2B through control module  
    -- B2M BM signals
    b2m_bm_in     : in  bm_ctrl_reg_type;               -- BM signals from B2M through control module
    b2m_bm_out    : out bm_out_type;                    -- BM signals to B2M through control module
    -- data descriptor out for M2B and B2M
    d_desc_out    : out data_dsc_strct_type;            -- Data descriptor passed to M2B and B2M
    ctrl_rst      : out std_ulogic;                     -- Reset signal from APB interface, to M2B and B2M
    err_sts_out   : out std_ulogic;                     -- Core APB status reg error bit. Passed to M2B and B2M
    -- M2B control signals
    m2b_start     : out std_ulogic;                     -- M2B start signal
    m2b_sts_in    : in  d_ex_sts_out_type;              -- M2B status signals
    m2b_resume    : out std_ulogic;                     -- M2B resume signal   
    -- B2M control signals
    b2m_sts_in    : in  d_ex_sts_out_type;              -- B2M status signals
    b2m_start     : out std_logic;                      -- B2M start signal
    b2m_resume    : out std_ulogic;                     -- B2M resume signal
    acc_sts_in    : in d_ex_sts_out_type;
    acc_start     : out std_ulogic;
    acc_resume    : out std_ulogic;
    acc_desc_out  : out acc_dsc_strct_type
  );
end entity grdmac2_ctrl;

------------------------------------------------------------------------------
-- Architecture of grdmac2_apb
------------------------------------------------------------------------------

architecture rtl of grdmac2_ctrl is
  attribute sync_set_reset         : string;
  attribute sync_set_reset of rstn : signal is "true";
  -----------------------------------------------------------------------------
  -- Constant declaration
  -----------------------------------------------------------------------------
  -- Constants for FSM present state display
  constant IDLE_STATE : std_logic_vector(4 downto 0) := "00000";  -- 0x0
  constant FETCH_DES  : std_logic_vector(4 downto 0) := "00001";  -- 0x1
  constant READ_DES   : std_logic_vector(4 downto 0) := "00010";  -- 0x2
  constant DECODE     : std_logic_vector(4 downto 0) := "00011";  -- 0x3
  constant COND_POLL  : std_logic_vector(4 downto 0) := "00100";  -- 0x4
  constant POL_ADR    : std_logic_vector(4 downto 0) := "00101";  -- 0x5
  constant COND_TRIG  : std_logic_vector(4 downto 0) := "00110";  -- 0x6
  --constant M2B_IDLE        : std_logic_vector(4 downto 0) := "00111"; -- 0x07
  --constant M2B_EXEC        : std_logic_vector(4 downto 0) := "01000"; -- 0x08
  --constant DATA_READ       : std_logic_vector(4 downto 0) := "01001"; -- 0x09
  --constant B2M_IDLE        : std_logic_vector(4 downto 0) := "01010"; -- 0x0A
  --constant START_FIFO_READ : std_logic_vector(4 downto 0) := "01011"; -- 0x0B
  --constant FIRST_WORD_WR   : std_logic_vector(4 downto 0) := "01100"; -- 0x0C 
  --constant BURST           : std_logic_vector(4 downto 0) := "01101"; -- 0x0D
  --constant WRITE_CHK       : std_logic_vector(4 downto 0) := "01110"; -- 0x0E
  constant WB_DESC    : std_logic_vector(4 downto 0) := "01111";  -- 0x0F
  constant WB_CHECK   : std_logic_vector(4 downto 0) := "10000";  -- 0x10
  constant RD_NXT_PTR : std_logic_vector(4 downto 0) := "10001";  -- 0x11
  -- 0x12 - 0x1A used for ACC
  
  -- Other constants
  constant DATA                    : std_logic_vector(3 downto 0) := "0000";
  constant C_POLL                  : std_logic_vector(3 downto 0) := "0001";
  constant C_TRIG                  : std_logic_vector(3 downto 0) := "0010";
  constant POLL_IRQ                : std_logic_vector(3 downto 0) := "0011";
  constant AES                     : std_logic_vector(3 downto 0) := "0100"; -- Descriptor type 4
  constant ACC_UPDATE              : std_logic_vector(3 downto 0) := "0101"; -- Descriptor type 5
  constant SHA                     : std_logic_vector(3 downto 0) := "0110"; -- Descriptor type 6
  constant POLL_SZ                 : std_logic_vector(9 downto 0) := "0000000011";  -- 3+1 bytes to be fetched(1 word)
  constant DESC_BYTES              : std_logic_vector(9 downto 0) := "0000011100";  -- 28 bytes to be fetched(7 words)
  constant WB_SZ                   : std_logic_vector(9 downto 0) := "0000000011";  -- 3+1 bytes to be written(1 word)

  -- Constant for bit- byte manipulation
  constant SHIFT_BIT : natural := 3;
  constant sz_bits   : integer := to_integer(shift_left(unsigned(DESC_BYTES), SHIFT_BIT));

  -- Reset configuration
  constant ASYNC_RST : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  -----------------------------------------------------------------------------
  -- Type and record 
  -----------------------------------------------------------------------------
  --- Control FSM states ---
  -- idle =>
  -- Execution starts from idle state and comes back after completion of each
  -- descriptor. Core process a descriptor queue only if there are no errors
  -- and if the core is enabled. If the execution is ongoing and not last descriptor, core
  -- proceeds with the next descriptor fetch from idle state. Else if the whole
  -- queue is completed, execution is paused and core stays idle. In this case,
  -- when the core receives a kick, it reads the current descriptor's
  -- nxt_desc.ptr again to check if a new descriptor is available for
  -- execution. If the core is disables or if there is an error, GRDMAC2 goes
  -- in to a paused state.
  --
  -- fetch_desc =>
  -- Initiates 28 byte long burst read through default Bus Master Interface(BM
  -- IF) to read descriptor.
  --
  -- read_desc =>
  -- Reads data from BM IF output signals and stores in a register.
  -- 
  -- decode_desc =>
  -- Checks if the descriptor is enabled. Disabled descriptors are skipped and
  -- core jumps to idle to proceed with next descriptor in the queue. If the
  -- descriptor is enabled, based on the desc_type field value, it decodes the
  -- type of the descriptor and jumps to respective states. If current
  -- descriptor is a data desc, starts M2B operation and sends m2b_start
  -- signal to mem2buf entity.
  -- 
  -- conditional_poll =>
  -- Always checks for timeout if timeout mechanism is enabled. Timeout is
  -- handled as an error or a failed condition based on err_to bit fild in the
  -- desc. Initiates
  -- polling access on the poll address through BM IF specified in descriptor
  -- field bm_num. Polling interval is maintained between consecutive polling accesses.
  -- 
  -- poll_adr =>
  -- Always checks for timeout if timeout mechanism is enabled. Timeout is
  -- handled as an error or a failed condition based on err_to bit fild in the
  -- desc. Reads polling result data from the BM IF and checks the condition
  -- for success. Iterates the polling- condition check process based on the
  -- cond_count value in desc control word.
  -- 
  -- conditional_trigger =>
  -- Always checks for timeout if timeout mechanism is enabled. Timeout is
  -- handled as an error or a failed condition based on err_to bit fild in the
  -- desc. Monitors event on expected input trigger line. Expected event is
  -- decided by ctrl.trig_type and cond_addr.trig_val of the descriptor.
  -- 
  -- m2b =>
  -- Always monitors for any errors and status from M2B module.
  -- If an error is reported from mem2buf module, handles the error.
  -- If M2B paused status is received from mem2buf module and B2M operation has
  -- not been started yet, core sends b2m_start signal. If the B2M operation is
  -- paused previously when the m2b_paused status is received, core sends b2m_resume
  -- signal to buf2mem module and resumes B2M operation.
  -- 
  -- acc =>
  -- If ACC paused status is received from accelerator module and B2M operation has
  -- not been started yet, core sends b2m_start signal. If the B2M operation is
  -- paused previously when the acc_paused status is received, core sends b2m_resume
  -- signal to buf2mem module and resumes B2M operation. When an acc_comp status is
  -- received and the descriptor type is X"5", core assumes the completion of the
  -- descriptor execution.
  --
  -- b2m =>
  -- Always monitors for any errors and status from B2M module.
  -- If an error is reported from buf2mem module, handles the error.
  -- If B2M paused status is received from buf2mem module core sends m2b_resume
  -- signal to mem2buf module and resumes M2B operation. When a b2m_comp
  -- status is received, core assumes the completion of the descriptor
  -- execution.
  -- 
  -- writeback_desc =>
  -- Initiates a 4 byte write transaction to the descriptor status word address
  -- throgh the default BM IF.
  -- 
  -- writeback_check =>
  -- Monitors BM IF signals and ensures that the descriptor write back was
  -- successful. Handles errors during descriptor write back if there are any.
  -- 
  -- read_nxt_ptr =>
  -- reads the nxt_desc field of the last descriptor in the queue and check the
  -- nxt_desc.last bit field. If it is set to 1, stays idle. If it is zero,
  -- assumes that the descriptor queue has been modified with new descriptors
  -- appended to the queue. Proceed to fetch next descriptor.

  type ctrl_state_type is (idle, fetch_desc, read_desc, decode_desc, conditional_poll, poll_adr, conditional_trigger, m2b, b2m, acc, writeback_desc, writeback_check, read_nxt_ptr);

  -- grdmac2_ctrl local reg type
  type ctrl_reg_type is record
    state        : ctrl_state_type;                 -- Present state register
    err_state    : std_logic_vector(4 downto 0);    -- FSM state in which error occured
    desc_ptr     : std_logic_vector(31 downto 0);   -- Current descriptor pointer
    i            : integer range 0 to 7;            -- Register for index increment
    rd_desc      : std_logic_vector(223 downto 0);  -- Register for descriptor read from BM
    cur_desc     : std_ulogic;                      -- Current descriptor type
    acc_en       : std_ulogic;                      -- Update values enable
    cnt_start    : std_ulogic;                      -- counting between polls started
    tm_start     : std_ulogic;                      -- Timeout counter decrement started
    timeout_cntr : std_logic_vector(31 downto 0);   -- counter for Timeout check
    poll_cnt     : std_logic_vector(7 downto 0);    -- counter for polling loop
    cnd_cntr     : std_logic_vector(7 downto 0);    -- Counter for polling interval
    poll_irq     : std_ulogic;                      -- poll_irq start flag
    bm_num       : std_ulogic;                      -- BM number out
    m2b_start    : std_ulogic;                      -- M2B start signal
    m2b_resume   : std_ulogic;                      -- M2B resume signal
    m2b_paused   : std_ulogic;                      -- M2B paused flag
    b2m_start    : std_ulogic;                      -- B2M start signal
    b2m_resume   : std_ulogic;                      -- B2M resume signal
    b2m_paused   : std_ulogic;                      -- B2M paused flag
    acc_start    : std_ulogic;                      -- ACC start signal
    acc_resume   : std_ulogic;                      -- ACC resume signal
    acc_paused   : std_ulogic;                      -- ACC paused flag
    event        : std_ulogic;                      -- Input trigger event flag
    trigger_1    : std_ulogic;                      -- current value of i/p trigger
    trigger_0    : std_ulogic;                      -- previous value of i/p trigger
    cond_fail    : std_ulogic;                      -- Failed condition check flag
    desc_skip    : std_ulogic;                      -- descriptor skip flag
    err_flag     : std_ulogic;                      -- Error flag
    dcomp_flg    : std_ulogic;                      -- Descriptor completed flag
    init_error   : std_ulogic;                      -- Error occured before starting current descriptor execution
    bmst_wr_busy : std_ulogic;                      -- bus master write busy
    bmst_rd_busy : std_ulogic;                      -- bus master read busy
    bmst_rd_err  : std_ulogic;                      -- bus master read error
    err_status   : std_ulogic;                      -- register to find the falling edge of err_status input signal
    sts          : status_out_type;                 -- Status register   
  end record;
  -- Reset value for grdmac2_ctrl local reg type
  constant CTRL_REG_RST : ctrl_reg_type := (
    state        => idle,
    err_state    => (others => '0'),
    desc_ptr     => (others => '0'),
    i            => 0,
    rd_desc      => (others => '0'),
    cur_desc     => '0',
    acc_en       => '0',
    cnt_start    => '0',
    tm_start     => '0',
    timeout_cntr => (others => '0'),
    poll_cnt     => (others => '0'),
    cnd_cntr     => (others => '0'),
    poll_irq     => '0',
    bm_num       => '0',
    m2b_start    => '0',
    m2b_resume   => '0',
    m2b_paused   => '0',
    b2m_start    => '0',
    b2m_resume   => '0',
    b2m_paused   => '0',
    acc_start    => '0',
    acc_resume   => '0',
    acc_paused   => '0',
    event        => '0',
    trigger_1    => '1',
    trigger_0    => '1',
    cond_fail    => '0',
    desc_skip    => '0',
    err_flag     => '0',
    dcomp_flg    => '0',
    init_error   => '0',
    bmst_wr_busy => '0',
    bmst_rd_busy => '0',
    bmst_rd_err  => '0',
    err_status   => '0',
    sts          => STATUS_OUT_RST
    );

  -----------------------------------------------------------------------------
  -- Signal declaration
  -----------------------------------------------------------------------------

  signal r, rin  : ctrl_reg_type;
  signal c_des   : cond_dsc_strct_type;  -- Conditional descriptor
  signal d_des   : data_dsc_strct_type;  -- Data descriptor and AES descriptor
  signal acc_des : acc_dsc_strct_type;   -- ACC desctiptor
  signal bmst    : bm_ctrl_reg_type;     -- Bus master control signals

  -----------------------------------------------------------------------------
  -- Function/procedure declaration
  -----------------------------------------------------------------------------
  
begin  -- rtl

  -----------------------------------------------------------------------------
  -- Assignments
  -----------------------------------------------------------------------------
  -- Bus master signal assignment switch logic. Based on the current state bus
  -- master signals are driven by M2B or B2M or control unit.
  bm_out.rd_addr <= m2b_bm_in.rd_addr when r.state = m2b else
                    b2m_bm_in.rd_addr when r.state = b2m else
                    bmst.rd_addr;
  bm_out.rd_size <= m2b_bm_in.rd_size when r.state = m2b else
                    b2m_bm_in.rd_size when r.state = b2m else
                    bmst.rd_size;
  bm_out.rd_req <= m2b_bm_in.rd_req when r.state = m2b else
                    b2m_bm_in.rd_req when r.state = b2m else
                    bmst.rd_req;
  bm_out.wr_addr <= m2b_bm_in.wr_addr when r.state = m2b else
                    b2m_bm_in.wr_addr when r.state = b2m else
                    bmst.wr_addr;
  bm_out.wr_size <= m2b_bm_in.wr_size when r.state = m2b else
                    b2m_bm_in.wr_size when r.state = b2m else
                    bmst.wr_size;
  bm_out.wr_req <= m2b_bm_in.wr_req when r.state = m2b else
                    b2m_bm_in.wr_req when r.state = b2m else
                    bmst.wr_req;
  bm_out.wr_data <= m2b_bm_in.wr_data when r.state = m2b else
                    b2m_bm_in.wr_data when r.state = b2m else
                    bmst.wr_data;

  -- Deassert the start signal and resume signal when the M2B,B2M or ACC operation has started.
  m2b_start  <= '0' when m2b_sts_in.operation = '1' else r.m2b_start;
  m2b_resume <= '0' when m2b_sts_in.operation = '1' else r.m2b_resume;
  b2m_start  <= '0' when b2m_sts_in.operation = '1' else r.b2m_start;
  b2m_resume <= '0' when b2m_sts_in.operation = '1' else r.b2m_resume;
  acc_start  <= '0' when acc_sts_in.operation = '1' else r.acc_start;
  acc_resume <= '0' when acc_sts_in.operation = '1' else r.acc_resume;


  -----------------------------------------------------------------------------
  -- Combinational logic
  ----------------------------------------------------------------------------- 
  comb : process (r, ctrl, des_ptr, active, trst, m2b_sts_in, b2m_sts_in, acc_sts_in, m2b_bm_in, b2m_bm_in, trigger, err_status, bm_in, d_des, c_des, acc_des, bmst)

    variable v           : ctrl_reg_type; 
    variable remainder   : integer range 0 to 96;          -- Variable for BM read_data handling
    variable data_rd     : std_logic_vector(31 downto 0);  -- Variable to hold polling out data
    variable trig_id     : integer range 0 to 63;          -- Variable for trigger id
    variable bmst_rd_req : std_ulogic;                     -- Bus master read request variable
    variable bmst_wr_req : std_ulogic;                     -- Bus master write request variable
  begin
    --Variable initialization
    v           := r;
    remainder   := 0;
    data_rd     := (others => '0');
    bmst_rd_req := '0';
    bmst_wr_req := '0';
    bmst        <= BM_CTRL_REG_RST;

    -- Kick flag. Whenever the ctrl.kick is set, this flag is set. This indicates addition of new
    -- descriptors or resuming GRDMAC2 operation after a pause
    if ctrl.kick = '1' then
      v.sts.kick := '1';
    end if;

    -- Restart flag
    if ctrl.restart = '1' then
      v.sts.restart := '1';
    end if;

    -- Counter for timeout check for conditional desc. Decremented every clock cycle
    if r.tm_start = '0' then
      v.timeout_cntr := trst.trst_val;
    elsif (r.tm_start = '1' and conv_integer(r.timeout_cntr) /= 0 and ctrl.te = '1') then
      v.timeout_cntr := r.timeout_cntr - 1;
    end if;

    -- Counter for polling interval. Incremented every clock cycle
    if r.cnt_start = '0' then
      v.cnd_cntr := (others => '0');
    elsif (r.cnd_cntr < c_des.ctrl.pol_interval) then
      v.cnd_cntr := r.cnd_cntr + 1;
    end if;

    -- Deassert the start signal and resume signal when the M2B or B2M operation has started.
    if m2b_sts_in.operation = '1' then
      v.m2b_start  := '0';
      v.m2b_resume := '0';
    elsif b2m_sts_in.operation = '1' then
      v.b2m_start  := '0';
      v.b2m_resume := '0';
    elsif acc_sts_in.operation = '1' then
      v.acc_start  := '0';
      v.acc_resume := '0';
    end if;

    v.err_status := err_status;
    -- Falling edge of err_status signal
    if (r.err_status = '1' and err_status = '0') then
      v.err_flag := '0';
    end if;

    -- Input trigger latching
    -- c_des.ctrl.trig_type :-
    --   0- edge triggered, 1- level triggered
    -- c_des.cond_addr.trig_val :
    --   0- Expecting positive edge when trig_type is edge triggered and level high when trig_type is level triggered.
    --   1- Expecting negative edge when trig_type is edge triggered and level low when trig_type is level triggered.
    trig_id     := conv_integer(c_des.ctrl.irqn);
    v.trigger_1 := trigger(trig_id);
    v.trigger_0 := r.trigger_1;
    if c_des.ctrl.trig_type = '0' then  -- edge triggered
      if (r.trigger_1 xor r.trigger_0) = '1' and (r.trigger_1 = (not c_des.cond_addr.trig_val)) then
        v.event := '1';
      end if;
    else                                -- Level triggered
      if (r.trigger_1 xor r.trigger_0) = '0' and (r.trigger_1 = (not c_des.cond_addr.trig_val)) then
        v.event := '1';
      end if;
    end if;


    -- Controller state machine 
    case r.state is
      when idle =>
        -- Default values
        v.bm_num              := '0';
        v.b2m_start           := '0';
        v.b2m_resume          := '0';
        v.m2b_start           := '0';
        v.m2b_resume          := '0';
        v.acc_start           := '0';
        v.acc_resume          := '0';
        v.m2b_paused          := '0';
        v.b2m_paused          := '0';
        v.acc_paused          := '0';
        -- Clear all errors
        v.sts.err             := '0';
        v.sts.decode_desc_err := '0';
        v.sts.rd_desc_err     := '0';
        v.sts.rd_data_err     := '0';
        v.sts.wr_data_err     := '0';
        v.sts.pol_err         := '0';
        v.sts.trig_err        := '0';
        v.sts.wb_err          := '0';
        v.sts.rd_nxt_ptr_err  := '0';
        v.bmst_rd_busy        := '0';
        v.bmst_wr_busy        := '0';
        v.bmst_rd_err         := '0';
        v.sts.fifo_err        := '0';
        v.sts.desc_comp       := '0';
        if (ctrl.en = '1' and err_status = '0' and r.err_flag = '0') then  -- Not paused(Enabled) and no error
          -- clear any latched events
          v.event      := '0';
          v.err_flag   := '0';
          v.err_state  := (others => '0');
          v.sts.paused := '0';
          v.cnt_start  := '0';
          v.tm_start   := '0';
          v.poll_irq   := '0';
          v.poll_cnt   := (others => '0');
          if active = '0' or r.sts.restart = '1' then
            -- Initial starting after reset. Or restart request is received
            -- Start descriptor read from first descriptor pointer
            v.sts.timeout   := '0';
            v.desc_skip     := '0';
            v.sts.restart   := '0';
            v.sts.ongoing   := '1';
            v.sts.comp      := '0';
            v.dcomp_flg     := '0';
            v.desc_ptr      := des_ptr.ptr;
            v.rd_desc       := (others => '0');
            v.state         := fetch_desc;
          elsif r.sts.ongoing = '1' or r.sts.kick = '1' or v.sts.kick = '1' then
            if r.init_error = '1' then  -- Taking up the same descriptor to fetch again since previously
                                        -- it encountered an error before reaching decoding state
              v.sts.ongoing := '1';
              v.rd_desc     := (others => '0');
              v.state       := fetch_desc;
            elsif r.cur_desc = '0' then  -- No initial desc read error and current desc is data descriptor
              if d_des.nxt_des.last = '1' then -- If current desc was last desc
                v.sts.ongoing := '0';
                v.sts.comp    := '1';
                if r.sts.kick = '1' or v.sts.kick = '1' then
                  -- If a kick request indicating descriptor queue modification is received, read nxt_desc.ptr again
                  if r.bmst_rd_busy = '0' then
                    bmst_rd_req   := '1';
                    v.bmst_rd_err := '0';
                  end if;
                  bmst.rd_addr <= (r.desc_ptr + 4);
                  bmst.rd_size <= conv_std_logic_vector(3, 10);
                  if bmst_rd_req = '1' and bm_in.rd_req_grant = '1' then
                    v.state        := read_nxt_ptr;
                    v.bmst_rd_busy := '1';
                  end if;
                end if;
              else  -- not last descriptor. Continue with next descriptor in the queue
                v.sts.timeout   := '0';
                v.desc_ptr      := d_des.nxt_des.ptr;
                v.dcomp_flg     := '0';
                v.sts.ongoing   := '1';
                v.sts.comp      := '0';
                v.rd_desc       := (others => '0');
                v.state         := fetch_desc;
                v.desc_skip     := '0';
              end if;
            else -- No initial desc read error and current desc is a conditional desc
              if r.cond_fail = '1' then
                -- condition check failed.continue with f_nxt_des.ptr
                v.desc_ptr      := c_des.f_nxt_des.ptr;
                v.sts.ongoing   := '1';
                v.dcomp_flg     := '0';
                v.sts.comp      := '0';
                v.desc_skip     := '0';
                v.rd_desc       := (others => '0');
                v.sts.timeout   := '0';
                v.state         := fetch_desc;
              elsif c_des.nxt_des.last = '1' then -- current desc was the last
                --If a kick request indicating descriptor queue modification is received, read nxt_desc.ptr again
                v.sts.ongoing := '0';
                v.sts.comp    := '1';
                if r.sts.kick = '1' or v.sts.kick = '1' then
                  if r.bmst_rd_busy = '0' then
                    bmst_rd_req   := '1';
                    v.bmst_rd_err := '0';
                  end if;
                  bmst.rd_addr <= (r.desc_ptr + 4);
                  bmst.rd_size <= conv_std_logic_vector(3, 10);
                  if bmst_rd_req = '1' and bm_in.rd_req_grant = '1' then
                    v.state        := read_nxt_ptr;
                    v.bmst_rd_busy := '1';
                  end if;
                end if;
              else  -- Not failed c_des and not last desc - continue with next descriptor.
                v.desc_ptr      := c_des.nxt_des.ptr;
                v.sts.timeout   := '0';
                v.sts.ongoing   := '1';
                v.dcomp_flg     := '0';
                v.sts.comp      := '0';
                v.desc_skip     := '0';
                v.rd_desc       := (others => '0');
                v.state         := fetch_desc;
              end if;
            end if;
          end if;
        else  -- Paused or error
          v.sts.ongoing := '0';
          if active = '1' then
            v.sts.paused := '1';
          end if;
        end if;
        -----------
        
      when read_nxt_ptr =>
        if bm_in.rd_valid = '1' then
          -- Check read errors (single access)
          if bm_in.rd_err = '1' then
            v.bmst_rd_err := '1';
          elsif r.bmst_rd_err = '0' then
            v.rd_desc(191 downto 160) := bm_in.rd_data(127 downto 96);
          end if;
          -- Evaluate if the burst access has finished
          if bm_in.rd_done = '1' then
            if v.bmst_rd_err = '0' then
              -- No errors
              if bm_in.rd_data(96) = '1' then
                -- still last descriptor, stay idle
                v.state    := idle;
                v.sts.kick := '0';
              else
                -- A new descriptor is apended to the queue. Proceed executing the new descriptor.
                if r.cur_desc = '1' then
                  v.sts.timeout   := '0';
                end if;
                v.desc_ptr      := bm_in.rd_data(127 downto 97) & "0";
                v.dcomp_flg     := '0';
                v.sts.ongoing   := '1';
                v.sts.comp      := '0';
                v.desc_skip     := '0';
                v.rd_desc       := (others => '0');
                v.state         := fetch_desc;
              end if; 
            else -- Bus master error
              v.bmst_rd_err        := '1';
              v.sts.err            := '1';
              v.err_flag           := '1';
              v.err_state          := RD_NXT_PTR;
              v.sts.rd_nxt_ptr_err := '1';
              v.state              := idle;
            end if;
            -- Clear bus master flags
            v.bmst_rd_busy := '0';
          end if;
        end if;
        -----------

      when fetch_desc =>
        -- Read all fields of descriptor. Conditional descriptor maximum number of fields. 28 bytes(7 words)
        -- Clear monitor registers before fetching new descriptor
        v.sts.kick   := '0';
        v.cond_fail  := '0';
        v.cur_desc   := '0';
        v.init_error := '0';
        -- Initiate descriptor fetch
        if r.bmst_rd_busy = '0' then
          bmst_rd_req   := '1';
          v.bmst_rd_err := '0';
        end if;
        bmst.rd_addr <= r.desc_ptr;
        bmst.rd_size <= DESC_BYTES - 1;
        if bmst_rd_req = '1' and bm_in.rd_req_grant = '1' then
          v.state        := read_desc;
          v.bmst_rd_busy := '1';
        end if;
        -----------
        
      when read_desc =>
        remainder := (sz_bits mod dbits);
        if bm_in.rd_valid = '1' then
          -- Check read errors (for each access in the burst)
          if bm_in.rd_err = '1' then
            v.bmst_rd_err := '1';
            -- Can not write back here as we dont know type of descriptor before decoding.               
          elsif r.bmst_rd_err = '0' then
            -- Read descriptor and store in 224 bit register 'rd_desc'. Logic to take care of configurable data width 'dbits'
            if (r.i < (sz_bits/dbits)) then
              v.rd_desc                   := std_logic_vector(shift_left(unsigned(r.rd_desc), dbits));
              v.rd_desc(dbits-1 downto 0) := bm_in.rd_data(127 downto (128-dbits));
            elsif remainder /= 0 then
              case remainder is
                when 32 =>              -- remainder = 32
                  v.rd_desc              := std_logic_vector(shift_left(unsigned(r.rd_desc), 32));
                  v.rd_desc(31 downto 0) := bm_in.rd_data(127 downto 96);
                when others =>          -- remainder = 96
                  v.rd_desc              := std_logic_vector(shift_left(unsigned(r.rd_desc), 96));
                  v.rd_desc(95 downto 0) := bm_in.rd_data(127 downto 32);
              end case;
            end if;  -- all fields of descriptor are read.
            v.i := r.i + 1;
          end if;
          -- Evaluate if the burst access has finished
          if bm_in.rd_done = '1' then
            if v.bmst_rd_err = '0' then
              -- No errors during the complete burst
              v.state := decode_desc;
            else -- Bus master error
              v.sts.err         := '1';
              v.sts.rd_desc_err := '1';
              v.err_flag        := '1';
              v.err_state       := READ_DES;
              v.init_error      := '1';
              -- no write back since desc read was not successful
              v.state           := idle;
            end if;
            -- Clear indexing register and bus master flags
            v.i            := 0;
            v.bmst_rd_busy := '0';
          end if;
        end if;
        -----------

      when decode_desc =>
        -- Finding descriptor type based on desc_type field. 0-data,1,2,3 conditional
        case r.rd_desc(196 downto 193) is
          when DATA =>
            v.cur_desc := '0';
            v.acc_en   := '0';
            v.bm_num   := r.rd_desc(198);
            if r.rd_desc(192) = '1' then  -- enabled descriptor
              v.m2b_start := '1';
              v.state     := m2b;
            else  -- Disabled descriptor. go to idle. No write back
              v.desc_skip := '1';
              v.state     := idle;
            end if;

          -- A type of data descriptor used for encryption
          when SHA =>
            v.cur_desc := '0';
            v.acc_en   := '1';
            v.bm_num   := r.rd_desc(198);
            if r.rd_desc(192) = '1' then  -- enabled descriptor
              v.m2b_start := '1';
              v.state     := m2b;
            else  -- Disabled descriptor. go to idle. No write back
              v.desc_skip := '1';
              v.state     := idle;
            end if;

          -- A type of data descriptor used for encryption
          when AES =>
            v.cur_desc := '0';
            v.acc_en   := '1';
            v.bm_num   := r.rd_desc(198);
            if r.rd_desc(192) = '1' then  -- enabled descriptor
              v.m2b_start := '1';
              v.state     := m2b;
            else  -- Disabled descriptor. go to idle. No write back
              v.desc_skip := '1';
              v.state     := idle;
            end if;

          -- A special descriptor used for updating values in accelerator
          when ACC_UPDATE =>
            v.cur_desc := '0';
            v.acc_en   := '1';
            v.bm_num   := r.rd_desc(198);
            if r.rd_desc(192) = '1' then  -- enabled descriptor
              v.m2b_start := '1';
              v.state     := m2b;
            else  -- Disabled descriptor. go to idle. No write back
              v.desc_skip := '1';
              v.state     := idle;
            end if;

          when C_POLL|C_TRIG|POLL_IRQ =>
            v.cur_desc := '1';
            v.acc_en   := '0';
            -- Bus master index
            v.bm_num   := r.rd_desc(198);
            -- check if the descriptor is enabled or not
            if r.rd_desc(192) = '1' then
              -- Ensure that last bit of f_nxt_des is not set
              if r.rd_desc(128) = '1' then  -- nxt_desc_ptr should not be null for c_des
                v.sts.decode_desc_err := '1';
                v.sts.err             := '1';
                v.err_flag            := '1';
                v.err_state           := DECODE;
                if r.rd_desc(197) = '1' then
                  v.bm_num := '0';
                  v.state := writeback_desc;
                else
                  v.state := idle;
                end if;
              else
                if r.rd_desc(196 downto 193) = C_POLL then     --polling
                  v.state := conditional_poll;
                elsif r.rd_desc(196 downto 193) = C_TRIG then  -- Triggering
                  v.state := conditional_trigger;
                else                    -- Poll on trigger
                  v.poll_irq := '1';
                  -- clear any latched events
                  v.event    := '0';
                  v.state    := conditional_trigger;
                end if;
              end if;
            else                        -- Disabled conditional desc
              v.state     := idle;
              v.desc_skip := '1';
            end if;
          when others =>
            -- desc_type field should have a value in the range 0 to 3 
            v.sts.decode_desc_err := '1';
            v.sts.err             := '1';
            v.err_flag            := '1';
            v.err_state           := DECODE;
            if r.rd_desc(197) = '1' then
              v.bm_num := '0';
              v.state := writeback_desc;
            else
              v.state := idle;
            end if;
        end case;  --Decoding completed
        -----------

      when conditional_poll =>
        if orv(r.timeout_cntr) /= '0' then  -- No timeout
          -- Check if the conditional polling has been looped for cond_count times
          if r.poll_cnt < c_des.ctrl.cond_count then
            if r.cnt_start = '0' then   -- first poll
              if r.bmst_rd_busy = '0' then
                v.tm_start    := '1';
                v.cnt_start   := '1';
                bmst_rd_req   := '1';
                v.bmst_rd_err := '0';
                bmst.rd_addr  <= c_des.cond_addr.ptr;
                bmst.rd_size  <= POLL_SZ;
                if bmst_rd_req = '1' and bm_in.rd_req_grant = '1' then
                  v.state        := poll_adr;
                  v.bmst_rd_busy := '1';
                end if;
              end if;
            else                        -- Polling iteration 
              if r.cnd_cntr >= c_des.ctrl.pol_interval then
                if r.bmst_rd_busy = '0' then
                  v.cnt_start   := '0';
                  bmst_rd_req   := '1';
                  v.bmst_rd_err := '0';
                  bmst.rd_addr  <= c_des.cond_addr.ptr;
                  bmst.rd_size  <= POLL_SZ;
                  if bmst_rd_req = '1' and bm_in.rd_req_grant = '1' then
                    v.state        := poll_adr;
                    v.bmst_rd_busy := '1';
                  end if;
                end if;
              end if;
            end if;
          else  -- Tried c_des.ctrl.cond_count times and failed
            v.sts.desc_comp := '1';
            v.dcomp_flg     := '1';
            v.cond_fail     := '1';
            if c_des.ctrl.write_back = '1' then
              v.bm_num := '0';
              v.state  := writeback_desc;
            else
              v.state := idle;
            end if;
          end if;
        else                            -- Timeout
          v.bmst_rd_busy := '0';
          v.bmst_rd_err  := '0';
          v.sts.timeout  := '1';
          if c_des.ctrl.err_to = '1' then   -- Timeout is an error
            v.sts.pol_err := '1';
            v.sts.err     := '1';
            v.err_flag    := '1';
            v.err_state   := COND_POLL;
          else  -- Timeout is a failed condition execution
            v.cond_fail     := '1';
            v.sts.desc_comp := '1';
            v.dcomp_flg     := '1';
          end if;
          if c_des.ctrl.write_back = '1' then
            v.bm_num := '0';
            v.state  := writeback_desc;
          else
            v.state := idle;
          end if;
        end if;
        -----------
        
      when poll_adr =>
        if orv(r.timeout_cntr) /= '0' then  -- No timeout
          -- If rd_valid is asserted and if there are no errors, data is valid
          if bm_in.rd_valid = '1' then
            if bm_in.rd_err = '1' then
              v.bmst_rd_err := '1';
              if c_des.ctrl.write_back = '1' then
                v.bm_num := '0';
                v.state  := writeback_desc;
              else
                v.state := idle;
              end if;
            elsif r.bmst_rd_err = '0' then
              data_rd := bm_in.rd_data(127 downto 96);
            end if;
            -- Check if read is done
            if bm_in.rd_done = '1' then
              if v.bmst_rd_err = '0' then   -- No bus master rd errors
                -- Check if conditon passed
                if (data_rd and c_des.cond_mask) = (c_des.cond_data and c_des.cond_mask) then  -- Successful condition check
                  v.sts.desc_comp := '1';
                  v.dcomp_flg     := '1';
                  if c_des.ctrl.write_back = '1' then
                    v.bm_num := '0';
                    v.state  := writeback_desc;
                  else
                    v.state := idle;
                  end if;
                else  -- Condition fail and no timeout. Polling continues
                  v.state     := conditional_poll;
                  v.poll_cnt  := r.poll_cnt + 1;
                  v.cnt_start := '1';
                end if;
              else                      -- Bus master error on polling access
                v.sts.pol_err := '1';
                v.sts.err     := '1';
                v.err_flag    := '1';
                v.err_state   := POL_ADR;
                if c_des.ctrl.write_back = '1' then
                  v.bm_num := '0';
                  v.state  := writeback_desc;
                else
                  v.state := idle;
                end if;
              end if;
              v.bmst_rd_busy := '0';
            end if;
          end if;
        else                            -- Timeout
          v.bmst_rd_busy := '0';
          v.bmst_rd_err  := '0';
          v.sts.timeout  := '1';
          if c_des.ctrl.err_to = '1' then   -- Timeout is an error
            v.sts.err   := '1';
            v.err_flag  := '1';
            v.err_state := POL_ADR;
          else        -- Timeout is a failed condition execution
            v.cond_fail     := '1';
            v.sts.desc_comp := '1';
            v.dcomp_flg     := '1';
          end if;
          if c_des.ctrl.write_back = '1' then
            v.bm_num := '0';
            v.state  := writeback_desc;
          else
            v.state := idle;
          end if;
        end if;
        -----------

      when conditional_trigger =>
        v.tm_start := '1';
        if orv(r.timeout_cntr) /= '0' then  -- Checking for timeout
        -- Proceed to next desc only when expected interrup is recieved.
        -- Stay in the same state untill success or till timeout
          if r.event = '1' then         -- Successful irq check
            v.event    := '0';
            v.tm_start := '0';
            if r.poll_irq = '1' then
            -- For polling on irq condition type, proceed to conditional polling when trigger is recieved
              v.state := conditional_poll;
            else
            -- For triggering type, proceed for next_des_ptr through idle
              v.sts.desc_comp := '1';
              v.dcomp_flg     := '1';
              if c_des.ctrl.write_back = '1' then
                v.bm_num := '0';
                v.state  := writeback_desc;
              else
                v.state := idle;
              end if;
            end if;
          end if;
        else    -- Timeout before successful reception of trigger
          v.sts.timeout := '1';
          if c_des.ctrl.err_to = '1' then   -- Timeout is an error
            v.sts.err      := '1';
            v.sts.trig_err := '1';
            v.err_flag     := '1';
            v.err_state    := COND_TRIG;
          else  -- Timeout is a failed condition execution
            v.cond_fail     := '1';
            v.sts.desc_comp := '1';
            v.dcomp_flg     := '1';
          end if;
          if c_des.ctrl.write_back = '1' then
            v.bm_num := '0';
            v.state  := writeback_desc;
          else
            v.state := idle;
          end if;
        end if;
        -----------
        
      when m2b =>
        -- Start ACC operation when M2B is completed or M2B buffer full and paused
        if ((r.m2b_resume or r.m2b_start) = '0' and m2b_sts_in.paused = '1' and r.acc_en = '1') then
          if r.acc_paused = '1' then  -- Resume ACC if it was previously paused
            v.acc_resume := '1';
            v.acc_paused := '0';
          else  -- Start ACC if it was not started yet at all.
            v.acc_start := '1';
          end if;
          v.state      := acc;
          -- Flag that M2b is paused and need to be resumed after B2M operation empties buffer
          v.m2b_paused := '1';
        elsif ((r.m2b_resume or r.m2b_start) = '0' and m2b_sts_in.paused = '1' and r.acc_en = '0') then
          if r.b2m_paused = '1' then  -- Resume B2M if it was previously paused
            v.b2m_resume := '1';
            v.b2m_paused := '0';
          else  -- Start B2M if it was not started yet at all.
            v.b2m_start := '1';
          end if;
          v.bm_num     := d_des.ctrl.dest_bm_num;
          v.state      := b2m;
          -- Flag that M2b is paused and need to be resumed after B2M operation empties buffer
          v.m2b_paused := '1';
        elsif ((r.m2b_resume or r.m2b_start) = '0' and m2b_sts_in.comp = '1' and r.acc_en = '1') then
          if r.acc_paused = '1' then  -- Resume ACC if it was previously paused
            v.acc_resume := '1';
            v.acc_paused := '0';
          else  -- Start ACC if it was not started yet at all.
            v.acc_start := '1';
          end if;
          v.state  := acc;
        elsif ((r.m2b_resume or r.m2b_start) = '0' and m2b_sts_in.comp = '1' and r.acc_en = '0') then
          if r.b2m_paused = '1' then  -- Resume B2M if it was previously paused
            v.b2m_resume := '1';
            v.b2m_paused := '0';
          else  -- Start B2M if it was not started yet at all.
            v.b2m_start := '1';
          end if;
          v.bm_num := d_des.ctrl.dest_bm_num;
          v.state  := b2m;
        elsif m2b_sts_in.m2b_err = '1' then  -- M2B error
          v.sts.err         := '1';
          v.err_flag        := '1';
          v.err_state       := m2b_sts_in.state;
          v.sts.rd_data_err := '1';
          -- go to write back if it is enabled, else go to idle
          if d_des.ctrl.write_back = '1' then
            v.state := writeback_desc;
          else
            v.state := idle;
          end if;
          v.bm_num := '0';
        end if;
        -----------

      when acc =>
        if ((r.acc_resume or r.acc_start) = '0' and acc_sts_in.paused = '1' and d_des.ctrl.desc_type = X"4") then
          if r.b2m_paused = '1' then  -- Resume B2M if it was previously paused
            v.b2m_resume := '1';
            v.b2m_paused := '0';
          else  -- Start B2M if it was not started yet at all.
            v.b2m_start := '1';
          end if;
          v.bm_num     := d_des.ctrl.dest_bm_num;
          v.state      := b2m;
          -- Flag that ACC is paused and need to be resumed after M2B operation fills buffer
          v.acc_paused := '1';
        elsif ((r.acc_resume or r.acc_start) = '0' and acc_sts_in.comp = '1' and d_des.ctrl.desc_type = X"4") then
          if (r.b2m_paused = '1') then
            v.b2m_resume := '1';
            v.b2m_paused := '0';
          else  -- Start B2M if it was not started yet at all.
            v.b2m_start := '1';
          end if;
          v.bm_num := d_des.ctrl.dest_bm_num;
          v.state := b2m;

        elsif ((r.acc_resume or r.acc_start) = '0' and acc_sts_in.paused = '1' and d_des.ctrl.desc_type = X"6") then
          --Resume M2b and fetch remaining data
          v.acc_paused := '1';
          v.m2b_resume := '1';
          v.bm_num     := d_des.ctrl.src_bm_num;
          v.state      := m2b;
          v.m2b_paused := '0';
        elsif ((r.acc_resume or r.acc_start) = '0' and acc_sts_in.comp = '1' and d_des.ctrl.desc_type = X"6") then
          v.b2m_start := '1';
          v.rd_desc(223 downto 203) := std_logic_vector(to_unsigned(32, 21));
          v.bm_num := d_des.ctrl.dest_bm_num;
          v.state := b2m;


        -- IF DESCRIPTOR TYPE 5, DATA USED TO UPDATE ACCELERATOR AND SHOULD GO BACK TO M2B OR FINISH DESCRIPTOR
        ----------------------------------------------------------------------------------------------------------
        elsif ((r.acc_resume or r.acc_start) = '0' and acc_sts_in.paused = '1' and d_des.ctrl.desc_type = X"5") then
          --Resume M2b and fetch remaining data
          v.acc_paused := '1';
          v.m2b_resume := '1';
          v.bm_num     := d_des.ctrl.src_bm_num;
          v.state      := m2b;
          v.m2b_paused := '0';
        elsif ((r.acc_resume or r.acc_start) = '0' and acc_sts_in.comp = '1' and d_des.ctrl.desc_type = X"5") then
          -- ACC completed. current data descriptor completed
          v.sts.desc_comp := '1';
          v.dcomp_flg     := '1';
          -- go to write back if it is enabled, else go to idle
          if d_des.ctrl.write_back = '1' then
            v.state := writeback_desc;
          else
            v.state := idle;
          end if;
          v.bm_num := '0';
        end if;
        -----------

      when b2m =>                       -- Current operation is B2M
        if ((r.b2m_resume or r.b2m_start) = '0' and b2m_sts_in.comp = '1') then
          -- B2M completed. current data descriptor completed
          v.sts.desc_comp := '1';
          v.dcomp_flg     := '1';
          -- go to write back if it is enabled, else go to idle
          if d_des.ctrl.write_back = '1' then
            v.state := writeback_desc;
          else
            v.state := idle;
          end if;
          v.bm_num := '0';
        elsif ((r.b2m_resume or r.b2m_start) = '0' and b2m_sts_in.paused = '1') then
          --b2m_buf_empty so resume M2b and fetch remaining data
          v.b2m_paused := '1';
          v.m2b_resume := '1';
          v.bm_num     := d_des.ctrl.src_bm_num;
          v.state      := m2b;
          v.m2b_paused := '0';
        elsif b2m_sts_in.b2m_err = '1' then
          -- Assert errors
          v.sts.err         := '1';
          v.err_flag        := '1';
          v.err_state       := b2m_sts_in.state;
          v.sts.wr_data_err := '1';
          -- go to write back if it is enabled, else go to idle
          if d_des.ctrl.write_back = '1' then
            v.state := writeback_desc;
          else
            v.state := idle;
          end if;
          v.bm_num := '0';
        elsif b2m_sts_in.fifo_err = '1' then
          v.sts.err      := '1';
          v.err_flag     := '1';
          v.err_state    := b2m_sts_in.state;
          v.sts.fifo_err := '1';
          -- go to write back if it is enabled, else go to idle
          if d_des.ctrl.write_back = '1' then
            v.state := writeback_desc;
          else
            v.state := idle;
          end if;
          v.bm_num := '0';
        end if;
        -----------

      when writeback_desc =>
        if r.bmst_wr_busy = '0' then
          -- The status of the descriptor is written to memory
          -- Single access of 4 bytes
          bmst.wr_addr <= r.desc_ptr + 16;  -- Status word of descriptor (offset 0x10)
          bmst.wr_size <= WB_SZ;        -- Write back size is always 4 bytes
          bmst_wr_req  := '1';
          if r.cur_desc = '0' then
            bmst.wr_data <= zero32(31 downto 2) & r.sts.err & r.sts.desc_comp & zero128(95 downto 0);
          else
            bmst.wr_data <= zero32(31 downto 3) & ((not r.cond_fail) and (not r.err_flag)) & r.sts.err & r.sts.desc_comp & zero128(95 downto 0);
          end if;
          if bmst_wr_req = '1' and bm_in.wr_req_grant = '1' then
            v.bmst_wr_busy := '1';
            v.state        := writeback_check;
          end if;
        end if;
        -----------

      when writeback_check =>
        -- Evaluate if the burst access has finished
        if bm_in.wr_done = '1' then
          v.bmst_wr_busy := '0';
          -- Check write errors 
          if bm_in.wr_err = '0' then    -- No errors during write back
            v.state := idle;
          else  -- Errors during write back write-burst access
            v.sts.err    := '1';
            v.err_flag   := '1';
            v.err_state  := WB_CHECK;
            v.sts.wb_err := '1';
            v.state      := idle;
          end if;
        end if;
        -----------
        
      when others =>
       v.state := idle;
    end case;

    ----------------------
    -- Signal update --
    ----------------------
    -- descriptor signal assignment
    -- Data descriptor signals
    d_des.ctrl.en           <= r.rd_desc(192);
    d_des.ctrl.desc_type    <= r.rd_desc(196 downto 193);
    d_des.ctrl.write_back   <= r.rd_desc(197);
    d_des.ctrl.src_bm_num   <= r.rd_desc(198);
    d_des.ctrl.dest_bm_num  <= r.rd_desc(199);
    d_des.ctrl.irq_en       <= r.rd_desc(200);
    d_des.ctrl.src_fix_adr  <= r.rd_desc(201);
    d_des.ctrl.dest_fix_adr <= r.rd_desc(202);
    d_des.ctrl.size         <= r.rd_desc(223 downto 203);
    -- Next descriptor pointer
    d_des.nxt_des.ptr       <= (r.rd_desc(191 downto 161) & "0");
    d_des.nxt_des.last      <= r.rd_desc(160);
    -- Address where data is to be written
    d_des.dest_addr         <= r.rd_desc(159 downto 128);
    -- Address from where data is to be fetched
    d_des.src_addr          <= r.rd_desc(127 downto 96);

    -- Conditional descriptor
    c_des.ctrl.en            <= r.rd_desc(192);
    c_des.ctrl.desc_type     <= r.rd_desc(196 downto 193);
    c_des.ctrl.write_back    <= r.rd_desc(197);
    c_des.ctrl.bm_num        <= r.rd_desc(198);
    c_des.ctrl.err_to        <= r.rd_desc(199);
    c_des.ctrl.irqn          <= r.rd_desc(205 downto 200);
    c_des.ctrl.irq_en        <= r.rd_desc(206);
    c_des.ctrl.trig_type     <= r.rd_desc(207);
    c_des.ctrl.pol_interval  <= r.rd_desc(215 downto 208);
    c_des.ctrl.cond_count    <= r.rd_desc(223 downto 216);
    -- Next descriptor pointer on success
    c_des.nxt_des.ptr        <= (r.rd_desc(191 downto 161) & "0");
    c_des.nxt_des.last       <= r.rd_desc(160);
    -- Next descriptor pointer on failure 
    c_des.f_nxt_des.ptr      <= (r.rd_desc(159 downto 129) & "0");
    c_des.f_nxt_des.last     <= r.rd_desc(128);
    -- status
    -- Address to be polled and expected trigger value
    c_des.cond_addr.ptr      <= r.rd_desc(127 downto 97) & "0";
    c_des.cond_addr.trig_val <= r.rd_desc(96);
    -- Expected data
    c_des.cond_data          <= r.rd_desc(63 downto 32);
    -- Conditional mask
    c_des.cond_mask          <= r.rd_desc(31 downto 0);

    -- Key/IV descriptor signals
    acc_des.ctrl.en           <= r.rd_desc(192);
    acc_des.ctrl.desc_type    <= r.rd_desc(196 downto 193);
    acc_des.ctrl.write_back   <= r.rd_desc(197);
    acc_des.ctrl.src_bm_num   <= r.rd_desc(198);
    acc_des.ctrl.irq_en       <= r.rd_desc(199);
    acc_des.ctrl.src_fix_adr  <= r.rd_desc(200);
    acc_des.ctrl.size         <= r.rd_desc(223 downto 201);
    -- Next descriptor pointer
    acc_des.nxt_des.ptr       <= (r.rd_desc(191 downto 161) & "0");
    acc_des.nxt_des.last      <= r.rd_desc(160);
    -- Address where data is to be fetced
    acc_des.src_addr          <= r.rd_desc(159 downto 128);

    -- Demultiplex Bus Master signals and drive M2B or B2M 
    if r.state = m2b then               --M2B
    m2b_bm_out <= bm_in;
    b2m_bm_out <= BM_OUT_RST;
    else                                --B2M
    b2m_bm_out <= bm_in;
    m2b_bm_out <= BM_OUT_RST;
    end if;

    -- state decoding for status display
    if r.err_flag = '1' then
      status.state <= r.err_state;
    else
      case r.state is
        when fetch_desc =>
          status.state <= FETCH_DES;
        when read_desc =>
          status.state <= READ_DES;
        when decode_desc =>
          status.state <= DECODE;
        when conditional_poll =>
          status.state <= COND_POLL;
        when poll_adr =>
          status.state <= POL_ADR;
        when conditional_trigger =>
          status.state <= COND_TRIG;
        when m2b =>
          status.state <= m2b_sts_in.state;
        when acc =>
          status.state <= acc_sts_in.state;
        when b2m =>
          status.state <= b2m_sts_in.state;
        when writeback_desc =>
          status.state <= WB_DESC;
        when writeback_check =>
          status.state <= WB_CHECK;
        when read_nxt_ptr =>
          status.state <= RD_NXT_PTR;
        when others =>
          status.state <= IDLE_STATE;
      end case;
    end if;
    
    -- Drive IRQ flag
    if (r.sts.err = '1' or err_status = '1') then
      irq_flag_sts <= ctrl.irq_en and ctrl.irq_err;
    elsif r.dcomp_flg = '1' then
      if r.cur_desc = '0' then
        irq_flag_sts <= d_des.ctrl.irq_en and ctrl.irq_en and (not ctrl.irq_msk);
      else
        irq_flag_sts <= c_des.ctrl.irq_en and ctrl.irq_en and (not ctrl.irq_msk);
      end if;
    else
      irq_flag_sts <= '0';
    end if;

    rin                    <= v;
    status.err             <= r.sts.err;
    status.decode_desc_err <= r.sts.decode_desc_err;
    status.rd_desc_err     <= r.sts.rd_desc_err;
    status.rd_data_err     <= r.sts.rd_data_err;
    status.wr_data_err     <= r.sts.wr_data_err;
    status.pol_err         <= r.sts.pol_err;
    status.trig_err        <= r.sts.trig_err;
    status.timeout         <= r.sts.timeout;
    status.wb_err          <= r.sts.wb_err;
    status.ongoing         <= r.sts.ongoing;
    status.desc_comp       <= r.sts.desc_comp;
    status.paused          <= r.sts.paused;
    status.kick            <= r.sts.kick;
    status.restart         <= r.sts.restart;
    status.rd_nxt_ptr_err  <= r.sts.rd_nxt_ptr_err;
    status.fifo_err        <= r.sts.fifo_err;
    status.comp            <= r.sts.comp;

    -- Current descriptor fields for debug display
    curr_desc_out.dbg_ctrl     <= r.rd_desc(223 downto 192);
    curr_desc_out.dbg_nxt      <= r.rd_desc(191 downto 160);
    curr_desc_out.dbg_fnxt     <= r.rd_desc(159 downto 128);
    curr_desc_out.dbg_cnd_addr <= r.rd_desc(127 downto 96);
    if r.cur_desc = '0' then
      curr_desc_out.dbg_cnd_data <= (others => '0');
      curr_desc_out.dbg_msk      <= (others => '0');
    else
      curr_desc_out.dbg_cnd_data <= r.rd_desc(63 downto 32);
      curr_desc_out.dbg_msk      <= r.rd_desc(31 downto 0);
    end if;
    if r.cur_desc = '1' then
      curr_desc_out.dbg_sts <= zero32(31 downto 3) & ((not r.cond_fail) and (not r.err_flag)) & r.err_flag & r.dcomp_flg;
    else
      curr_desc_out.dbg_sts <= zero32(31 downto 2) & r.err_flag & r.dcomp_flg;
    end if;
    
    bm_num        <= r.bm_num;
    d_desc_out    <= d_des;
    acc_desc_out  <= acc_des;
    ctrl_rst      <= ctrl.rst or err_status;
    curr_desc_ptr <= r.desc_ptr;
    err_sts_out   <= err_status;
    bmst.rd_req   <= bmst_rd_req;
    bmst.wr_req   <= bmst_wr_req;
    
  end process comb;

  -----------------------------------------------------------------------------
  -- Sequential process
  -----------------------------------------------------------------------------  
  seq : process (clk, rstn)
  begin
    if (rstn = '0' and ASYNC_RST) then
      r <= CTRL_REG_RST;
    elsif rising_edge(clk) then
      if rstn = '0' or ctrl.rst = '1' then
        r <= CTRL_REG_RST;
      else
        r <= rin;
      end if;
    end if;
  end process seq;

  -----------------------------------------------------------------------------
  -- Component instantiation
  -----------------------------------------------------------------------------  

end architecture rtl;
