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
-- Entity:  mdio_ctrl
-- File:    mdio_ctrl.vhd
-- Author:  Carl Ehrenstrahle
-- Description: MDIO Serial Bus Controller
------------------------------------------------------------------------------
-- MDIO Control
-- ============
-- The MDIO controller is an MDIO bus master with built in clock generation.
-- It also provides the following features:
-- * Support for 32 PHYs on one single MDIO interface.
-- * Automated auto negotiation configuration of selected PHYs.
--   - Initial setup ran after reset.
--   - Periodic checking of auto negotiation results.
-- * Interface compatible with GRETH_GBIT.
-- * Software issued MDIO transactions via APB register file.
-- * Handling and synchronization of an external interrupt.
-- * Build-time configurable output and input delays.
--
-- Architecture
-- ------------
-- The figure below illustrates the flow of data and interfaces within and to the outside of the MDIO controller.
--
--           ┌──────────────┐
--     APB   │              │
-- ─────────►│ APB Register │  MDIO Job
--           │     File     ├─────────────┐
--           │              │             │
--           └─┬────────────┘             │
--             │        ▲                 ▼
--             │        │            ┌──────────┐
--      control│        │            │          │            ┌─────────┐   i
--             │        │            │ MDIO Job │  MDIO Job  │         │◄──────
--             │  status│            │ Arbiter  │◄──────────►│ MDIO IF │ o, oe, clk
--             │        │            │          │            │         ├──────►
--             │        │            └──────────┘            └─────────┘
--   do        ▼        │                 ▲
--  init  ┌─────────────┴───┐             │
-- ──────►│                 │   MDIO Job  │
--        │ Autonegotiation ├─────────────┘
-- Result │  Configuration  │
-- ◄──────┤                 │
--        └─────────────────┘
--
-- APB Register File
-- ~~~~~~~~~~~~~~~~~
-- The APB register file contains the logic needed for the APB interface.
-- It offers various status registers and some control registers. Additionally,
-- it offers an interface to create MDIO transactions using the MDIO job register.
--
-- Auto Negotiation Configuration
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- The auto negotiation block performs automated reset and enabling of auto negotiation
-- for the PHYs specified by the phy_init_mask generic. If the negotiation can be completed
-- the results are gathered and speed and duplex parameters generated, saved and output
-- on the results interface. The auto negotiation configuration block operates in two different
-- modes: initialization and periodic.
--
-- Initialization
-- ..............
-- The initialization mode of the configuration block runs once after reset,
-- if the corresponding signal is asserted when the reset is lifted.
-- Which PHYs the initialization tries to initialize is decided with the
-- phy_init_mask build-time parameter.
-- The block tries to reset and enable auto negotiation. The number of times
-- the block tries to do this, before giving up on the PHY and going to the next one,
-- is decided by the phy_init_retry build-time parameter.
-- If the PHY is successfully reset, the initialization checks for the auto negotiation
-- results. If the PHY and its partner PHY has been able to complete the operation, the
-- results are read out. The speed and duplex parameters are calculated and then
-- published on the results interface. The parameters are also available in the register
-- file. If the PHY lacks the capability of auto negotiation, the initialization
-- will publish a 10 MBit/s half duplex result.
-- The whole process is repeated for each PHY index indicated by the phy_init_mask.
-- After the initialization process is completed, the configuration block tries to
-- enter the periodic mode.
--
-- Periodic
-- ........
-- When the configuration block enters the periodic mode, a register bit in the
-- control register is checked. If the bit is not set the configuration block
-- will enter an idle state.
-- The periodic mode will cycle through the PHYs that were successfully initialized
-- and support auto negotiation. The process is the same as the latter half of the
-- initialization mode (i.e. after reset and auto negotiation capability check).
-- The periodic mode will be active until the register bit is unset. The results
-- of the periodic checking will also be published on the results interface.
--
-- MDIO Job Arbiter
-- ~~~~~~~~~~~~~~~~
-- The MDIO job arbiter block is responsible for forwarding the MDIO jobs.
-- It ensures that only one job is running at the time and that the results
-- of the job ends up with the issuer of the job. The jobs are prioritized
-- as follows:
-- 1. Initialization configuration jobs
-- 2. APB jobs
-- 3. Periodic configuration jobs
--
-- MDIO IF
-- ~~~~~~~
-- The communication over the MDIO bus is handled by the MDIO IF. It acts as
-- the bus master and clock generator for the bus. When a job request is received,
-- from the job arbiter, the MDIO IF will create the corresponding transaction on
-- the MDIO bus. The results, in the case of a read transactions, are reported back
-- to the job arbiter and the MDIO IF starts listening for another job. The switching
-- of the data output can be delayed at a clock cycle granularity. The same goes for
-- the sampling of the input data. Both are controlled by build-time parameters.
-- The clock period of the generated clock is also controlled by a build-time parameter.
--
-- APB Issued MDIO Jobs
-- ------------------------
-- MDIO transactions can be created via the APB interface. There is an MDIO job register
-- which is used for both control and status. A job is created when writing to the register.
-- The data field is required for write transactions as it is the source of the data to be
-- transmitted to the specified PHY's register. In the case of a read transaction the read
-- data will be placed in the data field when the done status bit is asserted. A new write
-- to the register should not be performed until the current APB issued job has been
-- completed. For information about the individual fields and layout of the MDIO job register,
-- please refer to the register map section.
--
-- Register Map
-- ------------
-- The register map is divided into two segments. The segments contain up to 32
-- registers each. The two segments are: general MDIO controller registers and
-- PHY specific registers. The addresses for the registers are in a byte address
-- format. The two segments are divided based on the most significant bit of the
-- address; the general MDIO registers are preceded by a 0 while the PHY registers
-- are preceded by a 1.
--
-- ---------------------------------------
-- | Offset | Segment                    |
-- |--------|----------------------------|
-- | 0x00   | General MDIO controller    |
-- |--------|----------------------------|
-- | 0x80   | PHYs                       |
-- ---------------------------------------
--
-- Status Register
-- ~~~~~~~~~~~~~~~
-- Offset: 0x00
--
-- The status register contains read only registers. These registers
-- reflect the current state of different parts of the MDIO controller.
-- Writing to the status register will clear any active interrupt.
--
-- 31                                                    5   3 2 1 0
-- -----------------------------------------------------------------
-- | | | | | | | | | | | | | | | | | | | | | | | | | | | |St |P|B|I|
-- -----------------------------------------------------------------
-- --------------------------------------------------------------------------
-- | Bit | Field                                                            |
-- |-----|------------------------------------------------------------------|
-- | 0   | Active interrupt. 1 if an interrupt is active. Can be cleared    |
-- |     | by writing the status register.                                  |
-- |-----|------------------------------------------------------------------|
-- | 1   | MDIO busy. 1 if the MDIO interface is busy with a transaction.   |
-- |-----|------------------------------------------------------------------|
-- | 2   | Perform init configuration. A mirror of the input signal.        |
-- |-----|------------------------------------------------------------------|
-- | 4:3 | Configuration state. The current state of the configuration      |
-- |     | block state machine.                                             |
-- |     | 0x0: Initialization                                              |
-- |     | 0x1: Periodic                                                    |
-- |     | 0x2: Done                                                        |
-- --------------------------------------------------------------------------
--
-- Control Register
-- ~~~~~~~~~~~~~~~~
-- Offset: 0x4
--
-- The control register contains writable bit fields that control the operation
-- of the MDIO controller.
--
-- 31                                                          2 1 0
-- -----------------------------------------------------------------
-- | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | |P|I|
-- -----------------------------------------------------------------
-- --------------------------------------------------------------------------
-- | Bit | Field                                                            |
-- |-----|------------------------------------------------------------------|
-- | 0   | Interrupt enable. Set the field to 1 if incoming interrupts      |
-- |     | should be output on the IRQ output and the corresponding status  |
-- |     | bit should be set.                                               |
-- |-----|------------------------------------------------------------------|
-- | 1   | Periodic configuration enable. Set the field to 1 if the         |
-- |     | configuration block should perform periodic checking of the      |
-- |     | link auto negotiation results. Once disabled the function can't  |
-- |     | be enabled again unless a reset of the core is performed.        |
-- --------------------------------------------------------------------------
--
-- APB MDIO Job Register
-- ~~~~~~~~~~~~~~~~~~~~~
-- Offset: 0x8
--
-- The APB MDIO job register contains both writable and read-only bit fields.
-- The register is the gateway to which APB masters can perform MDIO transactions.
-- A transaction can be initiated by writing to the register when the APB MDIO job
-- is not busy (active is 0).
-- For read transactions, the data read from the PHY will be placed in the data
-- field of the register when the done field is asserted by the core via a 1.
--
-- 31                             16        11         6 5   3 2 1 0
-- -----------------------------------------------------------------
-- | Data                          | Reg     | PHY     |W| | |L|D|A|
-- -----------------------------------------------------------------
-- --------------------------------------------------------------------------
-- | Bit | Field                                                            |
-- |-----|------------------------------------------------------------------|
-- | 0   | Job active. Read only. Set if an APB MDIO job is currently       |
-- |     | active (either to be issued or transaction in action).           |
-- |-----|------------------------------------------------------------------|
-- | 1   | Job done. Read only. Set if an APB MDIO job is completed.        |
-- |     | Acts as a qualifier for the read data in case of a read          |
-- |     | transaction. Cleared when the APB MDIO job register is read.     |
-- |-----|------------------------------------------------------------------|
-- | 2   | Link failure. Read only. Set if a read transaction failed due to |
-- |     | the PHY not reacting in accordance with the MDIO protocol.       |
-- |     | Acts as a disqualifier of the read data, trumps job done.        |
-- |-----|------------------------------------------------------------------|
-- | 5   | Write not read. Writable. Controls whether the transaction is a  |
-- |     | read transaction or a write transaction. A 1 will result in a    |
-- |     | write transaction, while a 0 will result in a read transaction.  |
-- |-----|------------------------------------------------------------------|
-- |10:6 | PHY address. Writable. The address of the PHY the transaction is |
-- |     | intended for.                                                    |
-- |-----|------------------------------------------------------------------|
-- |15:11| Reg address. Writable. The address of the PHY register the       |
-- |     | transaction is intended for.                                     |
-- |-----|------------------------------------------------------------------|
-- |31:16| Data. Writable. The data to be either written or read from the   |
-- |     | specified PHY and register. A write transaction will source its  |
-- |     | data from this field while a read transaction will place the     |
-- |     | read data in this field. Qualified by job done and link failure. |
-- --------------------------------------------------------------------------
--
-- Init Bit Mask Register
-- ~~~~~~~~~~~~~~~~~~~~~
-- Offset: 0xC
--
-- The initialization bit mask register contains the value of the phy_init_mask
-- build-time parameter. The bit mask controls which PHYs are automatically
-- initialized by the configuration block when the reset is released. By extension
-- it also controls which of the PHYs are subject to the periodic configuration.
--
-- 31                                                              0
-- -----------------------------------------------------------------
-- | Initialization build-time parameter bit mask                  |
-- -----------------------------------------------------------------
-- --------------------------------------------------------------------------
-- | Bit | Field                                                            |
-- |-----|------------------------------------------------------------------|
-- |31:0 | Initialization build-time parameter bit mask. Read only.         |
-- --------------------------------------------------------------------------
--
-- PHY Specific Registers
-- ~~~~~~~~~~~~~~~~~~~~~~
-- Offset: 0x80 + 4*(PHY index/address)
--
-- The PHY specific registers contain information specific for each PHY.
--
-- 31                                                  6     3     0
-- -----------------------------------------------------------------
-- | | | | | | | | | | | | | | | | | | | | | | | | | | |ANEG | IS  |
-- -----------------------------------------------------------------
-- --------------------------------------------------------------------------
-- | Bit | Field                                                            |
-- |-----|------------------------------------------------------------------|
-- | 2:0 | Initialization status. Read only.                                |
-- |     | 0x0: Not performed. Skipped due to mask bit not set or init not  |
-- |     |      performed at all.                                           |
-- |     | 0x1: Running. Currently running.                                 |
-- |     | 0x2: Done. Performed successfully.                               |
-- |     | 0x3: Failed. Auto negotiation could not be enabled.              |
-- |     | 0x4: Timeout. A read transaction resulted in a link failure or   |
-- |     |      the PHY could not be reset within the retry limit.          |
-- |     | 0x5: Deferred. Auto negotiation was not performed, most          |
-- |     |      likely due to a missing Ethernet link.                      |
-- |-----|------------------------------------------------------------------|
-- | 5:3 | Auto negotiation results. Read only.                             |
-- |     | Bit 0: 0 - 10 MBit/s, 1 - 100 MBit/s                             |
-- |     | Bit 1: 0 - Refer to bit 0, 1 - 1000 MBit/s                       |
-- |     | Bit 2: 0 - Half duplex, 1 - Full duplex                          |
-- --------------------------------------------------------------------------
--
-- Interrupt
-- ---------
-- The MDIO controller contains an interrupt handler for a single source MDIO interrupt.
-- The interrupt signal is synchronized and the first detected flank is deemed as the
-- "active" flank. Care should therefore be taken to ensure that the input interrupt is
-- not asserted when the core leaves reset. If an active flank is encountered, the
-- interrupt handler will assert its output interrupt and set the corresponding
-- status bit in the register file. The interrupt can be cleared by writing to the
-- status register. The interrupt handling can also be disabled by clearing the
-- IRQ enable bit in the general control register.
--
-- Build-time Parameters
-- ---------------------
-- The MDIO controller can be configured at build-time using a number of different
-- parameters. These parameters are presented and explained in this section.
--
-- MDIO clock period (mdio_clk_divisor)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Sets the divisor value use to generate the MDIO clock.
-- The MDIO clock frequency will be clk/(2*(mdio_clk_divisor+1)).
--
-- MDIO output switching delay (mdio_output_delay)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- According to 802.3, the output must be stable at a minimum of 10 ns before and after
-- the rising edge of the MDIO clock. This build-time parameter controls the delay of
-- the output switching with regard to the rising edge of the MDIO clock. The delay
-- is specified in core clock cycles, i.e. a core clock of 100MHz will result in a delay
-- granularity of 10 ns. The delay must be greater or equal to 1, but care should be taken
-- that the delay does not spill into the next MDIO clock cycle.
--
-- MDIO input sampling delay (mdio_input_delay)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- According to 802.3, the PHY output delay can be anywhere between 0 and 300 ns.
-- The MDIO controller must therefore be able to delay the sampling of the input
-- in relation to the rising edge of the MDIO clock. This build-time parameter
-- controls the delay of the input sampling by the specified number of core
-- clock cycles. The delay must be greater or equal to 2, but care should be taken
-- that the delay does not spill into the next MDIO clock cycle.
--
-- PHY initialization mask (phy_init_mask)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- The PHY initialization mask defines which PHYs the auto negotiation
-- configuration block will try to initialize. A '1' will tell the
-- configuration to try to initialize the PHY with the address corresponding
-- to the bit index. A '1' at bit position 20 will lead to the initialization of
-- the PHY responding to address 20.
--
-- PHY initialization reset retry count (phy_reset_retry_count)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- During the initialization mode of the configuration, the PHY might be
-- unresponsive. If this is detected during the reset phase of the initialization
-- mode, the core will retry the operation as many times as the value of this
-- build-time parameter. If the retry count is exceeded the PHY will be skipped
-- and will not be included in the periodic checking.
--
-- Output enable polarity (oe_polarity)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- The output enable polarity build-time parameter controls the active signal
-- level for the MDIO output enable. A polarity of '1' will result in the MDIO
-- controller using the level '1' to assert active output from the MDIO interface.
--
-- Reset
-- -----
-- The core changes reset behaviour depending on settings in the GRLIB
-- configuration package, please refer to the GRLIB User’s Manual for details.
-- The core will add reset for all registers, except synchronization registers,
-- if the GRLIB config package setting grlib_sync_reset_enable_all is set.
-- The core will use asynchronous reset for all registers if the GRLIB config
-- package setting grlib_async_reset_enable is set.
--
-- Interfaces
-- ----------
-- The MDIO controller implements a number of interfaces. These interfaces are listed
-- here with their respective signals.
--
-- Clock
-- ~~~~~
-- The MDIO controller core clock. Everything internally in the core is synchronous to
-- this clock. The MDIO clock is also generated from this clock.
--
-- Reset
-- ~~~~~
-- The reset to the core can be either synchronous to the core clock or asynchronous.
-- For more information, please refer to the Reset section. The reset is an active low
-- reset.
--
-- APB
-- ~~~
-- The APB slave interface allows the system to manipulate the operation of the MDIO
-- controller. A multitude of status fields are accessible through this interface.
-- The APB logic uses the core clock as the interface clock.
--
-- MDIO
-- ~~~~
-- The MDIO interface provides the generated clock and the IO signals of the bus.
-- An output enable is provided to interface the data input and output singnals to
-- a tri-state buffer. The polarity of the output enable can be controlled by the
-- output enable polarity build-time parameter.
--
-- Auto Negotiation
-- ~~~~~~~~~~~~~~~~
-- The auto negotiation interface bundles the signals related to the automated
-- configuration functionality.
--
-- The perform_startup_init signal controls whether the automated configuration
-- process will be ran. If it is asserted with a '1' during the release of the
-- core reset, the process will start, otherwise it will be skipped.
--
-- The aneg_results vector contains the different speed settings calculated as a
-- result of the automated configuration process.
-- Bit 0 indicates whether the link
-- is 10 mbit/s or 100 mbit/s. This bit will be 0 if the gbit indicator is asserted.
-- Bit 1 indicates whether the link negotiated is a Gbit link or not, if asserted
-- then bit 0 will be '0' as a result.
-- Bit 2 indicates whether the link is full duplex or not, a '1' means that the link
-- has negotiated full duplex.
--
-- The aneg_valid vector contains one bit per PHY, where the bit index corresponds
-- to the PHY address. An asserted bit in the vector qualifies the aneg_results for
-- the PHY corresponding to the asserted bit's index. The bit will stay asserted for
-- one clock cycle and the results vector is only valid when a bit in the valid vector
-- is asserted. The results should therefore be stored by the recipient.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;

entity mdio_ctrl is
  generic (
    mdio_clk_divisor : positive := 1;
    oe_polarity : std_logic := '1'; -- Output enable polarity
    -- MDIO output data vs clock delay in clk cycles.
    -- Needs to be minimum 10 ns according to spec.
    mdio_output_delay : positive := 1;
    -- MDIO input data vs output clock delay in clk cycles.
    -- Minimum is 2 due to input register.
    -- PHYs can have 0 ns to 300 ns output delay according to the spec.
    mdio_input_delay : integer range 2 to 2147483647 := 2;
    -- Which PHYs to init, a 1 will cause the controller to enable auto negotiation.
    phy_init_mask : std_logic_vector(31 downto 0) := (others => '0');
    -- The number of times the controller will try to reset a phy in case of
    -- link failure during the reset procedure. A loss of link during subsequent
    -- stages of the initialization process are not affected by this generic.
    phy_reset_retry_count : natural := 0
  );
  port (
    clk : in std_logic;
    rstn : in std_logic; -- Active low reset

    -- MDIO Interface
    mdio_clk : out std_logic;
    mdio_i : in std_logic;
    mdio_o : out std_logic;
    mdio_oe : out std_logic; -- Output Enable
    mdio_irq : in std_logic;

    -- Initialize PHYs after reset?
    perform_startup_init : in std_logic;

    -- APB Slave
    psel    : in   std_logic;
    penable : in   std_logic;
    paddr   : in   std_logic_vector(31 downto 0);
    pwrite  : in   std_logic;
    pwdata  : in   std_logic_vector(31 downto 0);
    prdata  : out  std_logic_vector(31 downto 0);

    irq : out std_logic;

    -- Auto negotiation results.
    aneg_valid : out std_logic_vector(31 downto 0); -- Which PHY
    aneg_results : out std_logic_vector(2 downto 0) -- 0: 100M, 1: gbit, 2: full duplex
  );
end entity;

architecture rtl of mdio_ctrl is
  constant ASYNC_RESET : boolean :=
    GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  constant n_job_masters : positive := 2;

  function to_sl(a : boolean) return std_logic is
  begin
    if a then return '1'; else return '0'; end if;
  end function;

  function max(a, b : natural) return natural is
  begin
    if a > b then return a; else return b; end if;
  end function;

  -- Unary or function
  function unary_or(v : std_logic_vector) return std_logic is
    variable x: std_logic;
  begin
    x := '0';
    for c in v'range loop
      x := x or v(c);
    end loop;
    return x;
  end function;

  type slv_32_vec_t is array (integer range <>) of std_logic_vector(31 downto 0);

  -- Idle: Waiting for a job to initiate transaction.
  -- Others: Transaction fields.
  type mdio_if_state_t is (idle, preamble, startst, op, op2, phyadr, regadr,
                           ta, ta2, ta3, data, dataend);

  -- Idle: Waiting for a job.
  -- Job: Waiting for job to complete.
  type arbiter_state_t is (idle, job);

  -- Init: Running initial configuration and auto negotiation.
  -- Periodic: Running period check of link status (speed & duplex).
  -- Done: No actions taken.
  type configuration_state_t is (init, periodic, done);

  -- Start: Waiting for initialization to start.
  -- Reset PHY: Write PHY reset to MDIO.
  -- Wait for reset: Wait while PHY is running its internal reset procedure.
  -- Calc settings: Calculate GRETH_GBIT settings vector from link capabilities.
  -- Done: Done with initialization, no more actions to perform.
  -- Others: Current PHY register being accessed.
  type configuration_init_state_t is (start, reset_phy, wait_for_reset, control, status,
                                      aneg_adv, aneg_lpbpa, mst_slv_ctrl, mst_slv_status,
                                      calc_settings, done);

  -- Start: waiting for periodic to begin and loop head.
  -- Done: Done with periodic checking, software is now in charge.
  -- Others: Current PHY register being accessed.
  type configuration_periodic_state_t is (start, aneg_adv, aneg_lpbpa, mst_slv_ctrl,
                                          mst_slv_status, calc_settings, done);

  -- Idle: No job issued or not yet accepted by arbiter.
  -- Job: Waiting for job acceptance/completion.
  type job_master_state_t is (idle, job);

  -- Configuration state encoder
  function to_slv(s : configuration_state_t) return std_logic_vector is
    variable r : std_logic_vector(1 downto 0);
  begin
    case s is
      when init => r := "00";
      when periodic => r := "01";
      when done => r := "10";
    end case;
    return r;
  end function;

  -- MDIO IF controller registers
  type mdio_if_reg_t is record
    mdccnt          : std_logic_vector(7 downto 0);
    clk             : std_ulogic;
    clkold          : std_logic_vector(max(mdio_output_delay, mdio_input_delay)-1 downto
                                       0);
    state           : mdio_if_state_t;
    o               : std_ulogic;
    o_pre_delay     : std_ulogic;
    i               : std_ulogic;
    en              : std_ulogic;
    en_pre_delay    : std_ulogic;
    cnt             : unsigned(4 downto 0);
    mdint_sync      : std_logic_vector(2 downto 0);
    mdint_active    : std_logic;
  end record;

  -- Job interface between arbiter and MDIO IF controller
  -- Alternatively used between masters and the arbiter as well,
  -- with slight semantic variations.
  type mdio_job_reg_t is record
    write_not_read : std_logic;
    phyaddr   : std_logic_vector(4 downto 0);
    regaddr   : std_logic_vector(4 downto 0);
    data     : std_logic_vector(15 downto 0); -- Update by slave in case of read.
    busy     : std_logic; -- Can also be used as a request.
    linkfail : std_logic; -- Updated by job slave (mdio_if or arbiter).
  end record;

  -- Job arbiter registers
  type mdio_arbiter_reg_t is record
    state : arbiter_state_t;
    accept : std_logic_vector(n_job_masters - 1 downto 0); -- Job acceptance feedback.
    done : std_logic_vector(n_job_masters - 1 downto 0); -- Job completion feedback.
    current_master : natural range 0 to n_job_masters - 1; -- Index of current master.
  end record;

  type apb_reg_t is record
    job : mdio_job_reg_t;
    job_state : job_master_state_t;
    job_done : std_logic;
    rdata : std_logic_vector(31 downto 0);
    irq_en : std_logic;
  end record;

  type configuration_reg_t is record
    job : mdio_job_reg_t;
    state : configuration_state_t;
    init_state : configuration_init_state_t;
    periodic_state : configuration_periodic_state_t;
    run_periodic : std_logic;
    job_state : job_master_state_t;
    phy_index : natural range 0 to 32; -- 32 = done
    aneg_valid : std_logic_vector(aneg_valid'range);
    aneg_results : std_logic_vector(aneg_results'range);
    -- Negotiated capabilities of the link. Combination of local and partner PHYs.
    -- Bits 4:0 are related to sub 1000BASE-T
    -- Bits 6:5 are related to 1000BASE-T
    aneg_capabilities : std_logic_vector(6 downto 0);
    wait_counter : natural range 0 to 4095;
    phy_aneg_avail : std_logic_vector(31 downto 0); -- PHY supports auto negotiation?
    phy_ext_reg : std_logic_vector(31 downto 0); -- PHY has extended registers?
    phy_status_reg : slv_32_vec_t(0 to 31); -- Contains status information.
    phy_reset_retry_cnt : natural range 0 to phy_reset_retry_count + 1;
    reset_timeout : boolean; -- Did the reset MDIO job experience link failure?
  end record;

  type mdio_ctrl_reg_t is record
    mdio_if : mdio_if_reg_t;
    mdio_job : mdio_job_reg_t;
    arbiter : mdio_arbiter_reg_t;
    apb : apb_reg_t;
    config : configuration_reg_t;
    irq : std_logic;
  end record;

  constant mdio_if_reg_reset_c : mdio_if_reg_t := (
    mdccnt          => std_logic_vector(to_unsigned(mdio_clk_divisor, 8)),
    clk             => '0',
    clkold          => (others => '0'),    state           => idle,
    o               => '0',                i               => '0',
    o_pre_delay     => '0',
    en              => not oe_polarity, -- Dont drive bus by default
    en_pre_delay    => not oe_polarity,
    cnt             => (others => '0'),
    mdint_sync      => (others => '0'), mdint_active => '0');

  constant mdio_job_reg_reset_c : mdio_job_reg_t := (
    write_not_read => '0',
    phyaddr => (others => '0'),
    regaddr => (others => '0'),
    data => (others => '0'),
    busy => '0',
    linkfail => '0'
  );

  constant arbiter_reg_reset_c : mdio_arbiter_reg_t := (
    state => idle,
    accept => (others => '0'),
    done => (others => '0'),
    current_master => 0
  );

  constant apb_reg_reset_c : apb_reg_t := (
    job => mdio_job_reg_reset_c,
    job_state => idle,
    job_done => '0',
    rdata => (others => '0'),
    irq_en => '1'
  );

  constant configuration_reg_reset_c : configuration_reg_t := (
    job => mdio_job_reg_reset_c,
    state => init,
    init_state => start,
    periodic_state => start,
    run_periodic => '1',
    job_state => idle,
    phy_index => 0,
    aneg_valid => (others => '0'),
    aneg_results => (others => '0'),
    aneg_capabilities => (others => '0'),
    wait_counter => 0,
    phy_aneg_avail => (others => '0'),
    phy_ext_reg => (others => '0'),
    phy_status_reg => (others => (others => '0')),
    phy_reset_retry_cnt => 0,
    reset_timeout => false
  );

  constant mdio_ctrl_reset_c : mdio_ctrl_reg_t := (
    mdio_if => mdio_if_reg_reset_c,
    mdio_job => mdio_job_reg_reset_c,
    arbiter => arbiter_reg_reset_c,
    apb => apb_reg_reset_c,
    config => configuration_reg_reset_c,
    irq => '0'
  );

  -- APB register addresses
  constant apb_reg_addr_width_c : positive := 6;

  constant apb_reg_status_c : std_logic_vector(apb_reg_addr_width_c - 1 downto 0) :=
    "000000";
  constant apb_reg_control_c : std_logic_vector(apb_reg_addr_width_c - 1 downto 0) :=
    "000001";
  constant apb_reg_job_c : std_logic_vector(apb_reg_addr_width_c - 1 downto 0) :=
    "000010";
  constant apb_reg_init_bitmask_c : std_logic_vector(apb_reg_addr_width_c - 1 downto 0) :=
    "000011";


  -- Status register fields
  constant apb_field_status_irq_c : natural := 0;
  constant apb_field_status_mdio_busy_c : natural := 1;
  constant apb_field_status_do_init_c : natural := 2;
  constant apb_field_status_config_state_base_c : natural := 3;

  -- Control register fields
  constant apb_field_control_irq_en_c : natural := 0;
  constant apb_field_control_periodic_c : natural := 1;

  -- Job register fields
  constant apb_field_job_active_c : natural := 0;
  constant apb_field_job_done_c : natural := 1;
  constant apb_field_job_linkfail_c : natural := 2;
  constant apb_field_job_wnr_c : natural := 5;
  constant apb_field_job_phy_addr_base_c : natural := 6;
  constant apb_field_job_reg_addr_base_c : natural := 11;
  constant apb_field_job_data_base_c : natural := 16;

  -- Job master indices
  constant job_master_idx_config_c : natural := 0;
  constant job_master_idx_apb_c : natural := 1;

  -- Job operation encoding
  constant job_op_read_c : std_logic := '0';
  constant job_op_write_c : std_logic := '1';

  -- PHY addresses
  constant phy_reg_control_c : std_logic_vector(4 downto 0) := "00000";
  constant phy_reg_status_c : std_logic_vector(4 downto 0) := "00001";
  -- Auto negotiation advertisement
  constant phy_reg_aneg_adv_c : std_logic_vector(4 downto 0) := "00100";
  -- Auto negotiation link partner base page ability
  constant phy_reg_aneg_lpbpa_c : std_logic_vector(4 downto 0) := "00101";
  constant phy_reg_mst_slv_control_c : std_logic_vector(4 downto 0) := "01001";
  constant phy_reg_mst_slv_status_c : std_logic_vector(4 downto 0) := "01010";

  -- Auto negotiation results
  constant half_duplex_10_mbit_c : std_logic_vector(2 downto 0) := "000";

  -- PHY specific status register fields
  constant cfg_field_init_status_base_c : natural := 0;
  constant cfg_field_aneg_results_base_c : natural := 3;

  -- Encoding of the init status field.
  constant phy_status_init_not_performed_c : std_logic_vector(2 downto 0) := "000";
  constant phy_status_init_running_c : std_logic_vector(2 downto 0) := "001";
  constant phy_status_init_done_c : std_logic_vector(2 downto 0) := "010"; -- Aneg done
  constant phy_status_init_failed_c : std_logic_vector(2 downto 0) := "011"; -- Aneg fail
  constant phy_status_init_timeout_c : std_logic_vector(2 downto 0) := "100"; -- PHY t/o
  constant phy_status_init_deferred_c : std_logic_vector(2 downto 0) := "101"; -- ANeg not completed

  -- Current and next register state.
  signal r, rin : mdio_ctrl_reg_t;
begin

  --==================
  -- Main process
  --==================
  comb : process(r, mdio_i, mdio_irq, perform_startup_init,
                 psel, penable, pwrite, paddr, pwdata) is
    -- Function to calculate auto negotiation results from aneg_capabilities vector.
    function get_aneg_results(aneg_capabilities : std_logic_vector) return
      std_logic_vector is

      variable vspeed  : std_ulogic;
      variable vgbit   : std_ulogic;
      variable vduplex : std_ulogic;
      variable ret : std_logic_vector(2 downto 0);
    begin
      vspeed := '0'; vgbit := '0'; vduplex := '0';
      -- Auto Negotiation ability priority list from annex 28B.3 of 802.3-2008
      -- a) 10GBASE-T full duplex
      -- b) 1000BASE-T full duplex
      -- c) 1000BASE-T
      -- d) 100BASE-T2 full duplex
      -- e) 100BASE-TX full duplex
      -- f) 100BASE-T2
      -- g) 100BASE-T4
      -- h) 100BASE-TX
      -- i) 10BASE-T full duplex
      -- j) 10BASE-T
      -- tl;dr faster is higher prioritized.
      vgbit := aneg_capabilities(6) or aneg_capabilities(5);
      vspeed := not vgbit and (aneg_capabilities(4) or aneg_capabilities(3) or
                               aneg_capabilities(2));

      vduplex := (vgbit and aneg_capabilities(6)) or
                 (vspeed and aneg_capabilities(3)) or
                 ((not vgbit) and (not vspeed) and aneg_capabilities(1));
      ret(0) := vspeed;
      ret(1) := vgbit;
      ret(2) := vduplex;
      return ret;
    end function;

    -- Job master job creation and manager procedure
    procedure create_job (phy_addr : in std_logic_vector(4 downto 0);
                          reg_addr : in std_logic_vector(4 downto 0);
                          write_not_read : in std_logic;
                          write_data : in std_logic_vector(15 downto 0);
                          variable master_job : out mdio_job_reg_t;
                          master_index : in natural;
                          arbiter : in mdio_arbiter_reg_t;
                          job_state_reg : in job_master_state_t;
                          variable job_state_io : inout job_master_state_t) is
    begin
      case job_state_reg is
        when idle =>
          -- Create job
          master_job.phyaddr := phy_addr;
          master_job.regaddr := reg_addr;
          master_job.write_not_read := write_not_read;
          if write_not_read = '1' then
            master_job.data := write_data;
          end if;

          master_job.busy := '1';

          if arbiter.accept(master_index) = '1' then
            master_job.busy := '0';
            job_state_io := job;
          end if;

        when job =>
          if arbiter.done(master_index) = '1' then
            job_state_io := idle;
          end if;
      end case;
    end procedure;

    -- Arbiter accept job procedure
    procedure accept_job (master_job : in mdio_job_reg_t;
                          variable mdio_job : out mdio_job_reg_t;
                          variable arbiter : out mdio_arbiter_reg_t;
                          master_index : in natural) is
    begin
      mdio_job := master_job;
      arbiter.accept(master_index) := '1';
      arbiter.current_master := master_index;
      arbiter.state := job;
    end procedure;

    -- Arbiter complete job procedure
    procedure complete_job (variable master_job : out mdio_job_reg_t;
                            mdio_job : in mdio_job_reg_t;
                            arbiter_i : in mdio_arbiter_reg_t;
                            variable arbiter_o : out mdio_arbiter_reg_t) is
    begin
      if mdio_job.write_not_read = '0' then
        master_job.data := mdio_job.data;
      end if;
      master_job.linkfail := mdio_job.linkfail;

      arbiter_o.done(arbiter_i.current_master) := '1';
      arbiter_o.state := idle;
    end procedure;

    -- Handle different ways to skip ahead in the init process
    procedure init_go_next_phy(cfg_i : in configuration_reg_t;
                               phy_status_code : in std_logic_vector(2 downto 0);
                               code_base : in natural;
                               variable cfg_o : out configuration_reg_t) is
    begin
      cfg_o.phy_status_reg(cfg_i.phy_index)(code_base + phy_status_code'length - 1 downto
                                            code_base) :=
        phy_status_code;

      if cfg_i.phy_index = 32 then
        cfg_o.init_state := done;
      else
        cfg_o.phy_index := cfg_i.phy_index + 1;
        cfg_o.init_state := start;
      end if;
    end procedure;

    -- Handle different ways to skip ahead in the periodic process
    procedure periodic_go_next_phy(cfg_i_reg : in configuration_reg_t;
                                   variable cfg_io : inout configuration_reg_t) is
    begin
      cfg_io.phy_index := (cfg_i_reg.phy_index + 1) mod 32;
      cfg_io.periodic_state := start;
      cfg_io.wait_counter := 4095;
    end procedure;

    -- Next register state.
    variable v : mdio_ctrl_reg_t;

    -- MDIO IF variables
    variable mclkvec : std_logic_vector(r.mdio_if.clkold'length downto 0);
    variable sample_mdio_input : std_logic;
    variable switch_mdio_output : std_logic;
    variable mdio_rising_edge : std_logic;
    variable mdioindex : integer range 0 to 31;

    -- APB variables.
    variable vprdata : std_logic_vector(prdata'range);
    variable apb_phy_index : integer range 0 to 31;
  begin
    v := r; -- Copy current register state to next state.

    --------------------
    -- APB Interface
    --------------------
    vprdata := (others => '0'); -- Avoid latch.
    apb_phy_index := 0;

    if psel = '1' and penable = '1' then
      -- Byte addresses, disregard sub-word part.
      case paddr(apb_reg_addr_width_c + 2 - 1 downto 2) is
        when apb_reg_status_c =>
          if pwrite = '1' then
            v.irq := '0';
          else
            vprdata(apb_field_status_irq_c) := r.irq;
            vprdata(apb_field_status_mdio_busy_c) := r.mdio_job.busy;
            vprdata(apb_field_status_do_init_c) := perform_startup_init;
            vprdata(apb_field_status_config_state_base_c + 2 - 1 downto
                    apb_field_status_config_state_base_c) := to_slv(r.config.state);
          end if;

        when apb_reg_control_c =>
          if pwrite = '1' then
            v.apb.irq_en := pwdata(apb_field_control_irq_en_c);
            v.config.run_periodic := pwdata(apb_field_control_periodic_c);
          else
            vprdata(apb_field_control_irq_en_c) := r.apb.irq_en;
            vprdata(apb_field_control_periodic_c) := r.config.run_periodic;
          end if;

        when apb_reg_job_c =>
          if pwrite = '1' then
            -- Create a new job, don't care if one already exists.
            v.apb.job.busy := '1';
            v.apb.job.write_not_read := pwdata(apb_field_job_wnr_c);
            v.apb.job.phyaddr := pwdata(apb_field_job_phy_addr_base_c + 5 - 1 downto
                                        apb_field_job_phy_addr_base_c);
            v.apb.job.regaddr := pwdata(apb_field_job_reg_addr_base_c + 5 - 1 downto
                                        apb_field_job_reg_addr_base_c);
            if pwdata(apb_field_job_wnr_c) = '1' then
              v.apb.job.data := pwdata(apb_field_job_data_base_c + 16 - 1 downto
                                       apb_field_job_data_base_c);
            end if;
          else
            vprdata(apb_field_job_active_c) := r.apb.job.busy or
                                               to_sl(r.apb.job_state = job);
            vprdata(apb_field_job_done_c) := r.apb.job_done;
            vprdata(apb_field_job_linkfail_c) := r.apb.job.linkfail;
            vprdata(apb_field_job_wnr_c) := r.apb.job.write_not_read;
            vprdata(apb_field_job_phy_addr_base_c + 5 - 1 downto
                    apb_field_job_phy_addr_base_c) := r.apb.job.phyaddr;
            vprdata(apb_field_job_reg_addr_base_c + 5 - 1 downto
                    apb_field_job_reg_addr_base_c) := r.apb.job.regaddr;
            vprdata(apb_field_job_data_base_c + 16 - 1 downto
                    apb_field_job_data_base_c) := r.apb.job.data;
            -- Clear job status when reading.
            v.apb.job_done := '0';
          end if;

        when apb_reg_init_bitmask_c =>
          vprdata := phy_init_mask;
        -- Use others to capture MSB of address for PHY specific registers and use LSBs
        -- for indexing which PHY's status to return as read data.
        when others =>
          -- PHY specific status registers.
          if paddr(apb_reg_addr_width_c + 2 - 1) = '1' then
            apb_phy_index :=
              to_integer(unsigned(paddr(apb_reg_addr_width_c + 2 - 2 downto 2)));
            vprdata := r.config.phy_status_reg(apb_phy_index);
          end if;
      end case;
    end if;

    --~~~~~~~~~~~~~~~~~~
    -- MDIO Job
    -- Special handling needed due to APB transactions not being persistent.
    --~~~~~~~~~~~~~~~~~~
    case r.apb.job_state is
      when idle =>
        -- Acceptance will not happen unless job is requested via busy.
        if r.arbiter.accept(job_master_idx_apb_c) = '1' then
          v.apb.job.busy := '0';
          v.apb.job_state := job;
        end if;

      when job =>
        if r.arbiter.done(job_master_idx_apb_c) = '1' then
          v.apb.job_done := '1';
          v.apb.job_state := idle;
        end if;
    end case;


    --------------------
    -- Configuration Controller
    --------------------
    v.config.aneg_valid := (others => '0');

    case r.config.state is
      -- Initialization is performed for each PHY in phy_init_mask.
      when init =>
        if unary_or(phy_init_mask) = '1' then
          if r.config.init_state = done then
            v.config.phy_index := 0;
            -- Only do periodic checking if at least one PHY supports it.
            if unary_or(r.config.phy_aneg_avail) = '1' then
              v.config.state := periodic;
            else
              v.config.state := done;
            end if;
          end if;
        else
          v.config.state := done;
        end if;


      -- Periodic readout of link status (speed, duplex) is performed and broadcast.
      when periodic =>
        if r.config.periodic_state = done then
          v.config.state := done;
        end if;

      -- Configuration is left to SW.
      when done => null;
    end case;

    --~~~~~~~~~~~~~~~~~~
    -- Initialization
    --~~~~~~~~~~~~~~~~~~
    case r.config.init_state is
      when start =>
        if perform_startup_init = '1' and unary_or(phy_init_mask) = '1' then
          if r.config.phy_index = 32 then
            v.config.init_state := done;
          else
            -- Only initialize specified PHYs.
            if phy_init_mask(r.config.phy_index) = '1' then
              v.config.aneg_capabilities := (others => '0');
              v.config.phy_aneg_avail(r.config.phy_index) := '0';
              v.config.phy_ext_reg(r.config.phy_index) := '0';
              v.config.phy_reset_retry_cnt := 0;
              v.config.init_state := reset_phy;

              v.config.phy_status_reg(r.config.phy_index)(cfg_field_init_status_base_c + 3 - 1 downto
                                      cfg_field_init_status_base_c) :=
                phy_status_init_running_c;
            else
              v.config.phy_index := r.config.phy_index + 1;
            end if;
          end if;
        else
          v.config.init_state := done;
        end if;

      -- Try to issue a reset command to the PHY, retry if link fails.
      when reset_phy =>
        -- If the retry threshold has been reached, stop trying to reset
        -- the current PHY and go to the next one.
        if r.config.phy_reset_retry_cnt > phy_reset_retry_count then
          init_go_next_phy(cfg_i => r.config,
                           phy_status_code => phy_status_init_timeout_c,
                           code_base => cfg_field_init_status_base_c,
                           cfg_o => v.config);
        else
          create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                     reg_addr => phy_reg_control_c,
                     write_not_read => job_op_write_c,
                     write_data => x"9000", -- Reset and enable auto neg
                     master_job => v.config.job,
                     master_index => job_master_idx_config_c,
                     arbiter => r.arbiter,
                     job_state_reg => r.config.job_state,
                     job_state_io => v.config.job_state);

          if r.arbiter.done(job_master_idx_config_c) = '1' then
            v.config.init_state := wait_for_reset;
            v.config.wait_counter := 2047;
            v.config.reset_timeout := false;
          end if;
        end if;

      -- Wait for reset to be completed for PHY.
      -- The reset operation might have timed out, therefore the next state
      -- will depend on that.
      when wait_for_reset =>
        if r.config.wait_counter = 0 then
          if r.config.reset_timeout then
            v.config.init_state := reset_phy;
          else
            v.config.init_state := control;
          end if;
        else
          v.config.wait_counter := r.config.wait_counter - 1;
        end if;

      -- Read control register for reset status etc.
      when control =>
        create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                   reg_addr => phy_reg_control_c,
                   write_not_read => job_op_read_c,
                   write_data => x"0000",
                   master_job => v.config.job,
                   master_index => job_master_idx_config_c,
                   arbiter => r.arbiter,
                   job_state_reg => r.config.job_state,
                   job_state_io => v.config.job_state);

        if r.arbiter.done(job_master_idx_config_c) = '1' then
          v.config.reset_timeout := r.config.job.linkfail = '1';

          if r.config.job.linkfail = '1' then
            v.config.phy_reset_retry_cnt := r.config.phy_reset_retry_cnt + 1;
          end if;

          -- Reset still ongoing or timed out.
          if r.config.job.data(15) = '1' or r.config.job.linkfail = '1' then
            v.config.wait_counter := 2047;
            v.config.init_state := wait_for_reset;

          -- Reset completed, decide course of action
          else
            -- Auto negotiation could not be enabled, fall back to 10Mbit half duplex.
            if r.config.job.data(12) = '0' then
              v.config.aneg_valid(r.config.phy_index) := '1';
              v.config.aneg_results := half_duplex_10_mbit_c;

              init_go_next_phy(cfg_i => r.config,
                               phy_status_code => phy_status_init_failed_c,
                               code_base => cfg_field_init_status_base_c,
                               cfg_o => v.config);

            -- Auto negotiation enabled, continue with initialization.
            else
              v.config.init_state := status;
            end if;
          end if;
        end if;

      when status =>
        create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                   reg_addr => phy_reg_status_c,
                   write_not_read => job_op_read_c,
                   write_data => x"0000",
                   master_job => v.config.job,
                   master_index => job_master_idx_config_c,
                   arbiter => r.arbiter,
                   job_state_reg => r.config.job_state,
                   job_state_io => v.config.job_state);

        -- Check if auto negotiation is supported and can be read out.
        if r.arbiter.done(job_master_idx_config_c) = '1' then
          if r.config.job.linkfail = '1' then
            init_go_next_phy(cfg_i => r.config,
                             phy_status_code => phy_status_init_timeout_c,
                             code_base => cfg_field_init_status_base_c,
                             cfg_o => v.config);
          else
            v.config.phy_aneg_avail(r.config.phy_index) := r.config.job.data(3);

            -- Extended status registers available? Affects link speed calculation.
            -- Standard: "The Extended Status register is implemented for all PHYs
            --            capable of operation at speeds above 100 Mb/s."
            -- Use this as a qualifier for the MST-SLV registers. As they can
            -- be of either 100BASE-T2 or 1000BASE-T. If register 15 exists,
            -- as indicated by bit 8 of the status register; then the MST-SLV
            -- registers are most likely of the 1000BASE-T kind (section 40.5).
            v.config.phy_ext_reg(r.config.phy_index) := r.config.job.data(8);

            -- Auto negotiation must be available (bit 3) and the corresponding registers
            -- must be implemented (bit 0).
            -- No luck, fall back and go to next PHY.
            if r.config.job.data(3) = '0' or r.config.job.data(0) = '0' then
              v.config.aneg_valid(r.config.phy_index) := '1';
              v.config.aneg_results := half_duplex_10_mbit_c;

              init_go_next_phy(cfg_i => r.config,
                               phy_status_code => phy_status_init_failed_c,
                               code_base => cfg_field_init_status_base_c,
                               cfg_o => v.config);

            -- Status is acceptable, continue.
            else
              -- Auto-negotiation is completed. Continue.
              if r.config.job.data(5) = '1' then
                v.config.init_state := aneg_adv;

              -- Auto-negotiation is not completed. Cable probably not plugged in.
              -- Fall back to the periodic checking for link speed capabilities.
              else
                init_go_next_phy(cfg_i => r.config,
                                 phy_status_code => phy_status_init_deferred_c,
                                 code_base => cfg_field_init_status_base_c,
                                 cfg_o => v.config);
              end if;
            end if;
          end if;
        end if;

      -- Auto negotiation advertisement.
      -- From standard: This register contains the Advertised Ability of the PHY.
      when aneg_adv =>
        create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                   reg_addr => phy_reg_aneg_adv_c,
                   write_not_read => job_op_read_c,
                   write_data => x"0000",
                   master_job => v.config.job,
                   master_index => job_master_idx_config_c,
                   arbiter => r.arbiter,
                   job_state_reg => r.config.job_state,
                   job_state_io => v.config.job_state);

        -- Record auto negotiation advertisement register values.
        if r.arbiter.done(job_master_idx_config_c) = '1' then
          if r.config.job.linkfail = '1' then
            init_go_next_phy(cfg_i => r.config,
                             phy_status_code => phy_status_init_timeout_c,
                             code_base => cfg_field_init_status_base_c,
                             cfg_o => v.config);
          else
            -- Table 28B1 of 802.3-2008:
            -- Abilitiy field index: Technology
            -- 0: 10BASE-T
            -- 1: 10BASE-T Full Duplex
            -- 2: 100BASE-TX
            -- 3: 100BASE-TX Full Duplex
            -- 4: 100BASE-T(4)
            -- Seed the capabilities with the capabilities of the PHY under config.
            v.config.aneg_capabilities(4 downto 0) := r.config.job.data(9 downto 5);

            v.config.init_state := aneg_lpbpa;
          end if;
        end if;

      -- This register contains the Advertised Ability of the Link Partner’s PHY.
      -- i.e. the PHY that we are connected to.
      when aneg_lpbpa =>
        create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                   reg_addr => phy_reg_aneg_lpbpa_c,
                   write_not_read => job_op_read_c,
                   write_data => x"0000",
                   master_job => v.config.job,
                   master_index => job_master_idx_config_c,
                   arbiter => r.arbiter,
                   job_state_reg => r.config.job_state,
                   job_state_io => v.config.job_state);

        -- Record register values.
        if r.arbiter.done(job_master_idx_config_c) = '1' then
          if r.config.job.linkfail = '1' then
            init_go_next_phy(cfg_i => r.config,
                             phy_status_code => phy_status_init_timeout_c,
                             code_base => cfg_field_init_status_base_c,
                             cfg_o => v.config);
          else
            v.config.aneg_capabilities(6 downto 5) := (others => '0');
            -- The bit fields are identical to the advertisement register.
            -- Use the seeded values and add them together with the negotiated values.
            -- Use the and operation since both PHYs must support the ability.
            v.config.aneg_capabilities(4 downto 0) :=
              r.config.aneg_capabilities(4 downto 0) and r.config.job.data(9 downto 5);

            if r.config.phy_ext_reg(r.config.phy_index) = '1' then
              v.config.init_state := mst_slv_ctrl;
            -- No further updates to aneg_capabilities possible.
            else
              v.config.init_state := calc_settings;
            end if;
          end if;
        end if;

      when mst_slv_ctrl =>
        create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                   reg_addr => phy_reg_mst_slv_control_c,
                   write_not_read => job_op_read_c,
                   write_data => x"0000",
                   master_job => v.config.job,
                   master_index => job_master_idx_config_c,
                   arbiter => r.arbiter,
                   job_state_reg => r.config.job_state,
                   job_state_io => v.config.job_state);

        -- Record register values.
        if r.arbiter.done(job_master_idx_config_c) = '1' then
          if r.config.job.linkfail = '1' then
            init_go_next_phy(cfg_i => r.config,
                             phy_status_code => phy_status_init_timeout_c,
                             code_base => cfg_field_init_status_base_c,
                             cfg_o => v.config);
          else
            -- This reading assumes that the MST-SLV registers are of the 1000BASE-T kind.
            -- The definition can be found in 802.3 Section 40.5, table 40-3.
            -- Bit 8: 1000BASE-T half duplex
            -- Bit 9: 1000BASE-T Full duplex
            v.config.aneg_capabilities(6 downto 5) := r.config.job.data(9 downto 8);

            v.config.init_state := mst_slv_status;
          end if;
        end if;

      when mst_slv_status =>
        create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                   reg_addr => phy_reg_mst_slv_status_c,
                   write_not_read => job_op_read_c,
                   write_data => x"0000",
                   master_job => v.config.job,
                   master_index => job_master_idx_config_c,
                   arbiter => r.arbiter,
                   job_state_reg => r.config.job_state,
                   job_state_io => v.config.job_state);

        -- Record register values.
        if r.arbiter.done(job_master_idx_config_c) = '1' then
          if r.config.job.linkfail = '1' then
            init_go_next_phy(cfg_i => r.config,
                             phy_status_code => phy_status_init_timeout_c,
                             code_base => cfg_field_init_status_base_c,
                             cfg_o => v.config);
          else
            -- Combined advertised abilities with link partner's.
            -- From table 40-3:
            -- Reg 10 Bit 10: 1000BASE-T Half duplex
            -- Reg 10 Bit 11: 1000BASE-T Full duplex
            v.config.aneg_capabilities(6 downto 5) :=
              r.config.aneg_capabilities(6 downto 5) and r.config.job.data(11 downto 10);

            v.config.init_state := calc_settings;
          end if;
        end if;

      when calc_settings =>
        v.config.aneg_valid(r.config.phy_index) := '1';
        v.config.aneg_results := get_aneg_results(r.config.aneg_capabilities);

        v.config.phy_status_reg(r.config.phy_index)(cfg_field_aneg_results_base_c + aneg_results'length - 1 downto
                                                    cfg_field_aneg_results_base_c) :=
          v.config.aneg_results;

        init_go_next_phy(cfg_i => r.config,
                         phy_status_code => phy_status_init_done_c,
                         code_base => cfg_field_init_status_base_c,
                         cfg_o => v.config);
      when done => null;
      when others => null;
    end case;

    --~~~~~~~~~~~~~~~~~~
    -- Periodic
    -- Basically just the latter half of the init procedure.
    -- For register details etc. please refer to the init procedure.
    --~~~~~~~~~~~~~~~~~~
    case r.config.periodic_state is
      when start =>
        if r.config.state = periodic then
          if r.config.run_periodic = '1' then
            if phy_init_mask(r.config.phy_index) = '1' and
               r.config.phy_aneg_avail(r.config.phy_index) = '1' then

              -- Wait a bit between updates to save on MDIO bandwidth.
              if r.config.wait_counter = 0 then
                v.config.periodic_state := aneg_adv;
              else
                v.config.wait_counter := r.config.wait_counter - 1;
              end if;
            else
              v.config.phy_index := (r.config.phy_index + 1) mod 32;
            end if;
          else
            v.config.periodic_state := done;
          end if;
        end if;

      -- Auto negotiation advertisement.
      when aneg_adv =>
        create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                   reg_addr => phy_reg_aneg_adv_c,
                   write_not_read => job_op_read_c,
                   write_data => x"0000",
                   master_job => v.config.job,
                   master_index => job_master_idx_config_c,
                   arbiter => r.arbiter,
                   job_state_reg => r.config.job_state,
                   job_state_io => v.config.job_state);

        -- Record auto negotiation advertisement register values.
        if r.arbiter.done(job_master_idx_config_c) = '1' then
          if r.config.job.linkfail = '1' then
            periodic_go_next_phy(cfg_i_reg => r.config,
                                 cfg_io => v.config);
          else
            v.config.aneg_capabilities(4 downto 0) := r.config.job.data(9 downto 5);

            v.config.periodic_state := aneg_lpbpa;
          end if;
        end if;
      when aneg_lpbpa =>
        create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                   reg_addr => phy_reg_aneg_lpbpa_c,
                   write_not_read => job_op_read_c,
                   write_data => x"0000",
                   master_job => v.config.job,
                   master_index => job_master_idx_config_c,
                   arbiter => r.arbiter,
                   job_state_reg => r.config.job_state,
                   job_state_io => v.config.job_state);

        -- Record register values.
        if r.arbiter.done(job_master_idx_config_c) = '1' then
          if r.config.job.linkfail = '1' then
            periodic_go_next_phy(cfg_i_reg => r.config,
                                 cfg_io => v.config);
          else
            v.config.aneg_capabilities(6 downto 5) := (others => '0');
            v.config.aneg_capabilities(4 downto 0) :=
              r.config.aneg_capabilities(4 downto 0) and r.config.job.data(9 downto 5);

            -- Extended registers exist, further updates possible.
            if r.config.phy_ext_reg(r.config.phy_index) = '1' then
              v.config.periodic_state := mst_slv_ctrl;
            -- No further updates to aneg_capabilities possible.
            else
              v.config.periodic_state := calc_settings;
            end if;
          end if;
        end if;
      when mst_slv_ctrl =>
        create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                   reg_addr => phy_reg_mst_slv_control_c,
                   write_not_read => job_op_read_c,
                   write_data => x"0000",
                   master_job => v.config.job,
                   master_index => job_master_idx_config_c,
                   arbiter => r.arbiter,
                   job_state_reg => r.config.job_state,
                   job_state_io => v.config.job_state);

        -- Record register values.
        if r.arbiter.done(job_master_idx_config_c) = '1' then
          if r.config.job.linkfail = '1' then
            periodic_go_next_phy(cfg_i_reg => r.config,
                                 cfg_io => v.config);
          else
            v.config.aneg_capabilities(6 downto 5) := r.config.job.data(9 downto 8);

            v.config.periodic_state := mst_slv_status;
          end if;
        end if;
      when mst_slv_status =>
        create_job(phy_addr => std_logic_vector(to_unsigned(r.config.phy_index, 5)),
                   reg_addr => phy_reg_mst_slv_status_c,
                   write_not_read => job_op_read_c,
                   write_data => x"0000",
                   master_job => v.config.job,
                   master_index => job_master_idx_config_c,
                   arbiter => r.arbiter,
                   job_state_reg => r.config.job_state,
                   job_state_io => v.config.job_state);

        -- Record register values.
        if r.arbiter.done(job_master_idx_config_c) = '1' then
          if r.config.job.linkfail = '1' then
            periodic_go_next_phy(cfg_i_reg => r.config,
                                 cfg_io => v.config);
          else
            v.config.aneg_capabilities(6 downto 5) :=
              r.config.aneg_capabilities(6 downto 5) and r.config.job.data(11 downto 10);

            v.config.periodic_state := calc_settings;
          end if;
        end if;
      when calc_settings =>
        v.config.aneg_valid(r.config.phy_index) := '1';
        v.config.aneg_results := get_aneg_results(r.config.aneg_capabilities);

        v.config.phy_status_reg(r.config.phy_index)(cfg_field_aneg_results_base_c + aneg_results'length - 1 downto
                                                    cfg_field_aneg_results_base_c) :=
          v.config.aneg_results;

        periodic_go_next_phy(cfg_i_reg => r.config,
                             cfg_io => v.config);
      when done => null;
    end case;

    --------------------
    -- Job Arbiter
    --------------------
    case r.arbiter.state is
      -- Waiting for a master to issue a transaction.
      when idle =>
        v.arbiter.done := (others => '0'); -- Clear job done indicators.

        -- Should always be true when the arbiter is idle...
        if r.mdio_job.busy = '0' then
          -- Prioritize auto negotiation jobs
          if r.config.state = init and r.config.job.busy = '1' then
            accept_job(master_job => r.config.job, mdio_job => v.mdio_job,
                       arbiter => v.arbiter, master_index => job_master_idx_config_c);

          -- Prioritize APB jobs over periodic configuration jobs
          elsif r.apb.job.busy = '1' then
            accept_job(master_job => r.apb.job, mdio_job => v.mdio_job,
                       arbiter => v.arbiter, master_index => job_master_idx_apb_c);

          -- Periodic configuration jobs.
          elsif r.config.job.busy = '1' then
            accept_job(master_job => r.config.job, mdio_job => v.mdio_job,
                       arbiter => v.arbiter, master_index => job_master_idx_config_c);
          end if;
        end if;

      -- A job is currently running. Wait for it to finish and return the data
      -- to the correct master.
      when job =>
        v.arbiter.accept := (others => '0'); -- Clear job request acks.

        -- Transaction completed.
        if r.mdio_job.busy = '0' then
          case r.arbiter.current_master is
            when job_master_idx_config_c =>
              complete_job(master_job => v.config.job, mdio_job => r.mdio_job,
                           arbiter_i => r.arbiter, arbiter_o => v.arbiter);

            when job_master_idx_apb_c =>
              complete_job(master_job => v.apb.job, mdio_job => r.mdio_job,
                           arbiter_i => r.arbiter, arbiter_o => v.arbiter);

            when others => null;
          end case;
        end if;

      -- Shouldn't happen.
      when others => null;
    end case;


    --------------------
    -- MDIO Interface
    --------------------
    -- Create output MDIO clock.
    mdio_rising_edge := '0';
    if r.mdio_if.mdccnt = "00000000" then
      v.mdio_if.mdccnt := std_logic_vector(to_unsigned(mdio_clk_divisor,
                                                       r.mdio_if.mdccnt'length));
      v.mdio_if.clk := not r.mdio_if.clk;
      if r.mdio_if.clk = '0' then
        mdio_rising_edge := '1';
      end if;
    else
      v.mdio_if.mdccnt := std_logic_vector(unsigned(r.mdio_if.mdccnt) -
                                           to_unsigned(1, r.mdio_if.mdccnt'length));
    end if;

    -- Sample Control
    mclkvec := r.mdio_if.clkold & r.mdio_if.clk;
    -- Delay the rising edge clock actions by mdio_output_delay cycles.
    switch_mdio_output := mclkvec(mdio_output_delay-1) and not mclkvec(mdio_output_delay);
    -- Delay input sampling rising edge by mdio_input_delay cycle.
    if mdio_input_delay = 0 then
      sample_mdio_input := mdio_rising_edge;
    else
      sample_mdio_input := mclkvec(mdio_input_delay-1) and not mclkvec(mdio_input_delay);
    end if;
    -- Clock history shift register.
    v.mdio_if.clkold := mclkvec(mclkvec'high-1 downto 0);

    v.mdio_if.i := mdio_i;

    -- IRQ Sync & handling
    v.mdio_if.mdint_sync(0) := mdio_irq;
    for i in 0 to r.mdio_if.mdint_sync'length - 2 loop
      v.mdio_if.mdint_sync(i + 1) := r.mdio_if.mdint_sync(i);
    end loop;

    if (r.mdio_if.mdint_sync(r.mdio_if.mdint_sync'high) xor
       r.mdio_if.mdint_sync(r.mdio_if.mdint_sync'high - 1)) = '1' then

      -- Assert interrupt on first toggle.
      if r.apb.irq_en = '1' and r.mdio_if.mdint_active = '0' then
        v.irq := '1';
      end if;
      v.mdio_if.mdint_active := not r.mdio_if.mdint_active;
    end if;

    -- Interface state machine and IO
    mdioindex := to_integer(r.mdio_if.cnt);

    -- Delay the switching of the output and output enable.
    if switch_mdio_output = '1' then
      v.mdio_if.o := r.mdio_if.o_pre_delay;
      v.mdio_if.en := r.mdio_if.en_pre_delay;
    end if;

    case r.mdio_if.state is
      when idle =>
        if mdio_rising_edge = '1' then
          v.mdio_if.cnt := (others => '0');
          if r.mdio_job.busy = '1' then
            v.mdio_job.linkfail := '0';
            v.mdio_if.state := preamble;
            v.mdio_if.o_pre_delay := '1';
            v.mdio_if.en_pre_delay := oe_polarity;
          end if;
        end if;
      when preamble =>
        if mdio_rising_edge = '1' then
          v.mdio_if.cnt := r.mdio_if.cnt + to_unsigned(1, r.mdio_if.cnt'length);
          if r.mdio_if.cnt = "11111" then
            v.mdio_if.o_pre_delay := '0';
            v.mdio_if.state := startst;
          end if;
        end if;
      when startst =>
        if mdio_rising_edge = '1' then
          v.mdio_if.o_pre_delay := '1';
          v.mdio_if.state := op;
          v.mdio_if.cnt := (others => '0');
        end if;
      when op =>
        if mdio_rising_edge = '1' then
          v.mdio_if.state := op2;
          if r.mdio_job.write_not_read = '0' then
            v.mdio_if.o_pre_delay := '1';
          else
            v.mdio_if.o_pre_delay := '0';
          end if;
        end if;
      when op2 =>
        if mdio_rising_edge = '1' then
          v.mdio_if.o_pre_delay := not r.mdio_if.o_pre_delay;
          v.mdio_if.state := phyadr;
          v.mdio_if.cnt := (others => '0');
        end if;
      when phyadr =>
        if mdio_rising_edge = '1' then
          v.mdio_if.cnt := r.mdio_if.cnt + to_unsigned(1, r.mdio_if.cnt'length);
          case mdioindex is
            when 0 =>
              v.mdio_if.o_pre_delay := r.mdio_job.phyaddr(4);
            when 1 =>
              v.mdio_if.o_pre_delay := r.mdio_job.phyaddr(3);
            when 2 =>
              v.mdio_if.o_pre_delay := r.mdio_job.phyaddr(2);
            when 3 =>
              v.mdio_if.o_pre_delay := r.mdio_job.phyaddr(1);
            when 4 =>
              v.mdio_if.o_pre_delay := r.mdio_job.phyaddr(0);
              v.mdio_if.state := regadr;
              v.mdio_if.cnt := (others => '0');
            when others =>
              null;
          end case;
        end if;
      when regadr =>
        if mdio_rising_edge = '1' then
          v.mdio_if.cnt := r.mdio_if.cnt + to_unsigned(1, r.mdio_if.cnt'length);
          case mdioindex is
            when 0 =>
              v.mdio_if.o_pre_delay := r.mdio_job.regaddr(4);
            when 1 =>
              v.mdio_if.o_pre_delay := r.mdio_job.regaddr(3);
            when 2 =>
              v.mdio_if.o_pre_delay := r.mdio_job.regaddr(2);
            when 3 =>
              v.mdio_if.o_pre_delay := r.mdio_job.regaddr(1);
            when 4 =>
              v.mdio_if.o_pre_delay := r.mdio_job.regaddr(0);
              v.mdio_if.state := ta;
              v.mdio_if.cnt := (others => '0');
            when others => null;
          end case;
        end if;
      when ta =>
        if mdio_rising_edge = '1' then
          v.mdio_if.state := ta2;
          if r.mdio_job.write_not_read = '0' then
            -- Stop driving output during read data.
            v.mdio_if.en_pre_delay := not oe_polarity;
          else
            v.mdio_if.o_pre_delay := '1';
          end if;
        end if;
      when ta2 =>
        if mdio_rising_edge = '1' then
          v.mdio_if.cnt := "01111";
          v.mdio_if.state := ta3;
          if r.mdio_job.write_not_read = '1' then
            v.mdio_if.o_pre_delay := '0';
            v.mdio_if.state := data;
          end if;
        end if;
      when ta3 =>
        if mdio_rising_edge = '1' then
          v.mdio_if.state := data;
        end if;
        if sample_mdio_input = '1' then
          if r.mdio_if.i /= '0' then
            v.mdio_job.linkfail := '1';
          end if;
        end if;
      when data =>
        if mdio_rising_edge = '1' then
          v.mdio_if.cnt := r.mdio_if.cnt - to_unsigned(1, r.mdio_if.cnt'length);
          if r.mdio_if.cnt = "00000" then
            v.mdio_if.state := dataend;
          end if;
          if r.mdio_job.write_not_read = '1' then
            v.mdio_if.o_pre_delay := r.mdio_job.data(mdioindex);
          end if;
        end if;
        if sample_mdio_input = '1' then
          if r.mdio_job.write_not_read = '0' then
            -- Input shift register
            v.mdio_job.data := r.mdio_job.data(r.mdio_job.data'high - 1 downto
                                               r.mdio_job.data'low) & r.mdio_if.i;
          end if;
        end if;
      when dataend =>
        if mdio_rising_edge = '1' then
          v.mdio_job.busy := '0';
          v.mdio_if.state := idle;
          v.mdio_if.en_pre_delay := not oe_polarity;
        end if;
      when others =>
        null;
    end case;

    --------------------
    -- Outputs
    --------------------
    -- MDIO IF
    mdio_clk <= r.mdio_if.clk;
    mdio_o <= r.mdio_if.o;
    mdio_oe <= r.mdio_if.en;

    irq <= r.irq;

    -- APB
    prdata <= vprdata;

    -- Auto negotiation results
    aneg_valid <= r.config.aneg_valid;
    aneg_results <= r.config.aneg_results;

    --------------------
    -- Next
    --------------------
    rin <= v;
  end process;

  --==================
  -- Clocked process
  --==================
  syncregs : if not ASYNC_RESET generate
    regs_p : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if rstn = '0' then
          r <= mdio_ctrl_reset_c;
        end if;

        -- Suppress reset of synchronization registers to avoid reset logic insertion.
        r.mdio_if.mdint_sync <= rin.mdio_if.mdint_sync;
      end if;
    end process;
  end generate;

  asyncregs : if ASYNC_RESET generate
    regs_p : process(rstn, clk)
    begin
      if rstn = '0' then
        r <= mdio_ctrl_reset_c;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;
  end generate;
end architecture;
