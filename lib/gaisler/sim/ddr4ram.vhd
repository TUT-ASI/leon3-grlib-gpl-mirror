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
-- Entity:      ddr4ram
-- File:        ddr4ram.vhd
-- Author:      Carl Ehrenstrahle, Frontgrade Gaisler
-- Description: Generic simulation model of DDR4 SDRAM (JESD79-4)
------------------------------------------------------------------------------

--pragma translate_off

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ddr4ram is
  generic (
    data_width : integer range 0 to 64 := 8;
    density : integer range 0 to 3 := 0; -- 2Gb, 4Gb, 8Gb, 16Gb
    device_x : integer range 4 to 16 := 4; -- 4x, 8x, 16x
    unwritten_memory_data : std_logic := 'U' -- Reads to unwritten memory return this
  );
  port (
    ck_t : in std_ulogic;
    ck_c : in std_ulogic;
    cke : in std_ulogic;
    reset_n : in std_ulogic;
    cs_n : in std_ulogic;
    act_n : in std_ulogic;
    ba : in std_logic_vector(1 downto 0);
    bg : in std_logic_vector(1 downto 0);
    a : in std_logic_vector(17 downto 0); -- Includes multi-function pins
    dq : inout std_logic_vector(data_width - 1 downto 0) := (others => 'Z');
    dqs_t : inout std_logic_vector(data_width / 8 - 1 downto 0) := (others => 'Z');
    dqs_c : inout std_logic_vector(data_width / 8 - 1 downto 0) := (others => 'Z');
    dm_dbi_n : inout std_logic_vector(data_width / 8 - 1 downto 0) := (others => 'Z')
  );
end entity;

architecture sim of ddr4ram is
  -- Multi function pin aliases
  alias ras_n : std_ulogic is a(16);
  alias cas_n : std_ulogic is a(15);
  alias we_n : std_ulogic is a(14);
  alias bc_n : std_ulogic is a(12); -- burst chop
  alias ap : std_ulogic is a(10); -- auto precharge

  function to_i(a : std_ulogic) return integer is
    variable t : std_logic_vector(0 downto 0);
  begin
    t(0) := a;
    return to_integer(unsigned(t));
  end function;

  function count_zeroes(a : std_logic_vector) return natural is
    variable r : natural := 0;
  begin
    for i in a'range loop
      if a(i) = '0' then r := r + 1; end if;
    end loop;
    return r;
  end function;

  type bank_status_t is record
    last_precharge : time;
    row : integer;
  end record;
  type bank_status_arr_t is array(natural range <>) of bank_status_t;
  type bg_status_arr_t is array(natural range <>) of
    bank_status_arr_t(0 to (2**ba'length) - 1);

  type tRFC_tab_t is array(0 to 3) of time;
  --                            2Gb     4Gb     8Gb     16Gb
  constant tRFC: tRFC_tab_t := (160 ns, 260 ns, 350 ns, 550 ns);

  constant tXS : time := tRFC(density) + 10 ns;
  -- Use the smallest tRP(min) to avoid speedbin variant complexity.
  constant tRP : time := 11 ns;
  -- Short CAS_n to CAS_n command latency, 4 nCK for every speed bin.
  constant tCCD_S : positive := 4;

  type ddr4_state_t is (init, idle, active, writing, reading, precharging);

  type mode_register_t is record
    -- Register 0
    write_recovery : positive;
    read_to_precharge : positive;
    dll_reset : std_ulogic;
    test_mode : std_ulogic;
    cas_latency : natural;
    read_burst_type : std_ulogic;
    burst_length : std_logic_vector(1 downto 0);

    -- Register 1
    qoff : std_ulogic;
    tdqs_enable : std_ulogic;
    rtt_nom : std_logic_vector(2 downto 0);
    write_leveling_enable : std_ulogic;
    additive_latency : integer;
    dll_enable : std_ulogic;

    -- Register 2
    write_crc : std_ulogic;
    cas_write_latency : natural;

    -- Register 3
    mpr_read_format : std_logic_vector(1 downto 0);
    write_command_latency : std_logic_vector(1 downto 0);
    geardown_mode : std_ulogic;
    mpr_operation : std_ulogic;
    mpr_page_selection : natural;

    -- Register 4
    write_preamble : positive;
    read_preamble : positive;
    cs_to_cmd_latency : natural;

    -- Register 5
    read_dbi : std_ulogic;
    write_dbi : std_ulogic;
    data_mask : std_ulogic;

    -- Register 6
    tccd_l : positive;
  end record;

  constant c_mode_register_reset : mode_register_t  := (
    -- Register 0
    write_recovery => 1,
    read_to_precharge => 1,
    dll_reset => '0',
    test_mode => '0',
    cas_latency => 13,
    read_burst_type => '0',
    burst_length => "00",

    -- Register 1
    qoff => '0',
    tdqs_enable => '0',
    rtt_nom => "000",
    write_leveling_enable => '0',
    additive_latency => 0,
    dll_enable => '0',

    -- Register 2
    write_crc => '0',
    cas_write_latency => 16,

    -- Register 3
    mpr_read_format => "00",
    write_command_latency => "00",
    geardown_mode => '0', -- Specified by standard.
    mpr_operation => '0',
    mpr_page_selection => 0,

    -- Register 4
    write_preamble => 1,
    read_preamble => 1,
    cs_to_cmd_latency => 0, -- Specified by standard.

    -- Register 5
    read_dbi => '0',
    write_dbi => '0',
    data_mask => '0',

    -- Register 6
    tccd_l => 6
  );

  type data_cmd_t is record
    valid : boolean;
    rnw : std_ulogic;
    bg : natural;
    bank : natural;
    row : natural;
    col_base : natural;
    col_offset : natural;
    bl : natural; -- 4 or 8
    issued : time;
  end record;
  type data_cmd_pipe_t is array (natural range <>) of data_cmd_t;

  signal data_cmd_pipe : data_cmd_pipe_t(0 to 30);

  function cas_latency_table(a12 : std_ulogic; a64 : std_logic_vector(2 downto 0);
                             a2 : std_ulogic) return natural is
    variable t : std_logic_vector(4 downto 0);
  begin
    t := a12 & a64 & a2;
    -- Table 15 - CAS Latency
    case t is
      when "00000" => return 9;
      when "00001" => return 10;
      when "00010" => return 11;
      when "00011" => return 12;
      when "00100" => return 13;
      when "00101" => return 14;
      when "00110" => return 15;
      when "00111" => return 16;
      when "01000" => return 18;
      when "01001" => return 20;
      when "01010" => return 22;
      when "01011" => return 24;
      when "01100" => return 23;
      when "01101" => return 17;
      when "01110" => return 19;
      when "01111" => return 21;
      when "10000" => return 25;
      when "10001" => return 26;
      when "10010" => return 27;
      when "10011" => return 28;
      when "10100" => return 29;
      when "10101" => return 30;
      when "10110" => return 31;
      when "10111" => return 32;
      when others =>
        report "Invalid CAS latency specifier." severity error;
        return 32;
    end case;
  end function;

  function write_recovery_table(a13 : std_ulogic; a119 : std_logic_vector(2 downto 0))
    return positive is

    variable t : natural;
    variable r : positive;
  begin
    t := to_integer(unsigned(a13 & a119));

    -- Table 14 - Write Recovery and Read to Precharge (cycles)
    case t is
      when 6 => r := 24;
      when 7 => r := 22;
      when 8 => r := 26;
      when others =>
        assert t < 9 report "Trying to set a reserved write recovery value."
        severity warning;
        r := 2 * t + 10;
    end case;
    return r;
  end function;

  function read_to_precharge_table(a13 : std_ulogic; a119 : std_logic_vector(2 downto 0))
    return positive is

    variable t : natural;
    variable r : positive;
  begin
    t := to_integer(unsigned(a13 & a119));

    -- Table 14 - Write Recovery and Read to Precharge (cycles)
    case t is
      when 6 => r := 12;
      when 7 => r := 11;
      when 8 => r := 13;
      when others =>
        assert t < 9 report "Trying to set a reserved read to precharge value."
        severity warning;
        r := t + 5;
    end case;
    return r;
  end function;

  function cs_to_cmd_latency_table(a86 : std_logic_vector(2 downto 0)) return natural is
  begin
    -- Table 27.
    case a86 is
      when "000" => return 0;
      when "001" => return 3;
      when "010" => return 4;
      when "011" => return 5;
      when "100" => return 6;
      when "101" => return 8;
      when others =>
        report "Reserved CS to CMD latency setting detected." severity warning;
        return 0;
    end case;
  end function;

  function cas_write_latency_table(a53 : std_logic_vector(2 downto 0)) return natural is
  begin
    -- Table 21.
    case a53 is
      when "000" => return 9;
      when "001" => return 10;
      when "010" => return 11;
      when "011" => return 12;
      when "100" => return 14;
      when "101" => return 16;
      when "110" => return 18;
      when "111" => return 20;
      when others => report "Bad CWL value" severity error; return 20;
    end case;
  end function;

  function tccd_l_table(a1210 : std_logic_vector(2 downto 0)) return positive is
  begin
    -- Table 13 - tCCD_L.
    -- TODO: Speed bin validation of the requested tCCD_L.
    case a1210 is
      when "000" => return 4;
      when "001" => return 5;
      when "010" => return 6;
      when "011" => return 7;
      when "100" => return 8;
      when others => report "Reserved tCCD_L value" severity error; return 6;
    end case;
  end function;

  procedure update_mode_register(index : in natural;
                                 variable mode_regs : inout mode_register_t) is
  begin
    case index is
      when 0 =>
        mode_regs.dll_reset := a(8);
        mode_regs.test_mode := a(7);
        mode_regs.cas_latency := cas_latency_table(a(12), a(6 downto 4), a(2));
        mode_regs.read_to_precharge := read_to_precharge_table(a(13), a(11 downto 9));
        mode_regs.write_recovery := write_recovery_table(a(13), a(11 downto 9));
        mode_regs.read_burst_type := a(3);
        mode_regs.burst_length := a(1 downto 0);

      when 1 =>
        mode_regs.qoff := a(12);
        mode_regs.tdqs_enable := a(11);
        mode_regs.rtt_nom := a(10 downto 8);
        mode_regs.write_leveling_enable := a(7);
        mode_regs.dll_enable := a(0);
        if a(4 downto 3) = "00" then
          mode_regs.additive_latency := 0;
        else
          mode_regs.additive_latency := mode_regs.cas_latency -
                                          to_integer(unsigned(a(4 downto 3)));
        end if;

      when 2 =>
        mode_regs.write_crc := a(12);
        mode_regs.cas_write_latency := cas_write_latency_table(a(5 downto 3));

      when 3 =>
        mode_regs.mpr_read_format := a(12 downto 11);
        mode_regs.write_command_latency := a(10 downto 9);
        mode_regs.geardown_mode := a(3);
        mode_regs.mpr_operation := a(2);
        mode_regs.mpr_page_selection := to_integer(unsigned(a(1 downto 0)));

      when 4 =>
        mode_regs.write_preamble := 1 + to_i(a(12));
        mode_regs.read_preamble := 1 + to_i(a(11));
        mode_regs.cs_to_cmd_latency := cs_to_cmd_latency_table(a(8 downto 6));

      when 5 =>
        mode_regs.write_dbi := a(11);
        mode_regs.read_dbi := a(12);
        mode_regs.data_mask := a(10);
        assert (a(11)='0' or a(10)='0') report "Write DBI and data masking cannot both be enabled."
          severity error;

      when 6 =>
        mode_regs.tccd_l := tccd_l_table(a(12 downto 10));

      when others => report "Tried to update missing mode register." severity warning;
    end case;
  end procedure;

  signal initdone : boolean := false;

  shared variable mode_registers : mode_register_t := c_mode_register_reset;
  signal ddr4_state : ddr4_state_t := init;


  signal cke_d1 : std_ulogic;

  type data_arr_t is array (natural range <>) of std_logic_vector(data_width-1 downto 0);
  type mask_arr_t is array (natural range <>) of
    std_logic_vector(data_width / 8 - 1 downto 0);
  signal write_data : data_arr_t(0 to 1);
  signal write_mask : mask_arr_t(0 to 1);
  signal write_enable : std_ulogic := '0'; --  Toggle to sample DQ and DQS
  signal read_data : data_arr_t(0 to 1);
  signal read_enable : std_ulogic := '0'; -- Toggle to push data to DQ
  signal read_preamble_enable : std_ulogic := '0'; -- Toggle to toggle DQS

  signal start_clock_monitor : std_ulogic := '0';
  signal stop_clock_monitor : std_ulogic := '0';
begin
  -----------------------------------------------------------------------------
  -- Init sequence checker
  -----------------------------------------------------------------------------
  init_clock_monitor_p : process
    variable t1 : time;
    variable cnt : natural;
  begin
    wait until start_clock_monitor'event;
    t1 := now;
    cnt := 0;
    loop
      wait until stop_clock_monitor'event or rising_edge(ck_t) or reset_n = '0';
      if rising_edge(ck_t) then cnt := cnt + 1; end if;
      if stop_clock_monitor'event then exit; end if;
      if reset_n = '0' then exit; end if;
    end loop;
    if stop_clock_monitor'event then
      assert now - t1 >= 10 ns report "Clock activity was less than 10 ns."
        severity warning;
      assert cnt >= 5 report "At least 5 clock cycles were not registered."
        severity warning;
    end if;
  end process;

  init_checker_p : process
    procedure check_deselect_command is
    begin
      -- cke should be asserted high previous cycle, but that isn't possible in this
      -- case, since it is the first cycle where cke is high.
      assert cs_n = '1' and cke = '1' report "Expected a deselect command"
        severity warning;
    end procedure;

    procedure mrs(expected_reg : in natural; variable mrs_reg : inout mode_register_t;
                  variable got_reset : out std_ulogic) is
      variable which_mrs : natural;
      variable rst : boolean := false;
    begin
      got_reset := '0';
      rst := false;
      loop
        wait until rising_edge(ck_t) or reset_n = '0';
        if reset_n = '0' then
          rst := true;
          exit;
        elsif cke = '1' and cs_n = '0' and act_n = '1' and ras_n = '0' and cas_n = '0' and
          we_n = '0'
        then
          exit;
        end if;
      end loop;

      if not rst then
        assert bg(1) = '0'
          report "BG1 must be programmed to 0 during MRS" severity warning;
        assert a(17) = '0'
          report "A17 must be programmed to 0 during MRS" severity warning;
        which_mrs := to_integer(unsigned(bg(0) & ba));
        assert which_mrs = expected_reg report
          "Expected MRS index " & integer'image(expected_reg) & " got "  &
          integer'image(which_mrs) & "." severity warning;

        update_mode_register(which_mrs, mrs_reg);
      else
        got_reset := '1';
      end if;
    end procedure;

    variable t1 : time;
    variable got_reset : std_ulogic;


  begin
    -- Allow resetn to be X or U for a while during sim start.
    if reset_n /= '0' then
      wait until reset_n = '0' for 1 us;
    end if;
    assert reset_n = '0' report "RESET_n not asserted on power-up" severity warning;
    -- RESET_n needs to be maintained below 0.2 x VDD for minimum 200us with stable power.
    wait until reset_n /= '0' for 200 us;
    assert reset_n = '0' report "RESET_n raised with less than 200 us init delay"
      severity warning;
    -- Ignore the test enable critereon since the signal is omitted from the model.
    l0 : loop
      initdone <= false;
      if reset_n = '0' then
        wait until reset_n /= '0';
      end if;
      -- 2. After RESET_n is de-asserted, wait for another 500us until CKE becomes active.
      assert cke = '0' report "CKE not low when RESET_n deasserted" severity warning;
      start_clock_monitor <= not start_clock_monitor;
      wait until (reset_n = '0' or cke /= '0') for 500 us;
      if reset_n = '0' then next; end if;
      assert cke = '0' report
        "CKE raised with less than 500 us delay after RESET_n deasserted"
        severity warning;
      wait until (reset_n = '0' or cke /= '0') and rising_edge(ck_t);
      if reset_n = '0' then next; end if;
      -- 3. Clocks (CK_t,CK_c) need to be started and stabilized for at least
      -- 10ns or 5tCK (which is larger) before CKE goes active.
      stop_clock_monitor <= not stop_clock_monitor;
      -- Also, a Deselect command must be registered (with tIS set up time to clock)
      -- at clock edge Td.
      check_deselect_command;
      -- 5. After CKE is being registered high, wait minimum of Reset CKE Exit time,
      -- tXPR, before issuing the first MRS command to load mode register.
      -- (tXPR=Max(tXS, 5nCK)]
      t1 := now;
      -- 6. Issue MRS Command to load MR3 with all application settings
      mrs(expected_reg => 3, mrs_reg => mode_registers, got_reset => got_reset);
      if got_reset = '1' then next l0; end if;
      assert (now - t1) >= tXS report "tXS violation" severity warning;
      -- From time point ‘Td’ until ‘Tk’,
      -- DES commands must be applied between MRS and ZQCL commands
      wait until rising_edge(ck_t); check_deselect_command;
      -- 7. Issue MRS command to load MR6 with all application settings
      mrs(expected_reg => 6, mrs_reg => mode_registers, got_reset => got_reset);
      if got_reset = '1' then next l0; end if;
      wait until rising_edge(ck_t); check_deselect_command;
      -- 8. Issue MRS command to load MR5 with all application settings
      mrs(expected_reg => 5, mrs_reg => mode_registers, got_reset => got_reset);
      if got_reset = '1' then next l0; end if;
      wait until rising_edge(ck_t); check_deselect_command;
      -- 9. Issue MRS command to load MR4 with all application settings
      mrs(expected_reg => 4, mrs_reg => mode_registers, got_reset => got_reset);
      if got_reset = '1' then next l0; end if;
      wait until rising_edge(ck_t); check_deselect_command;
      -- 10. Issue MRS command to load MR2 with all application settings
      mrs(expected_reg => 2, mrs_reg => mode_registers, got_reset => got_reset);
      if got_reset = '1' then next l0; end if;
      wait until rising_edge(ck_t); check_deselect_command;
      -- 11. Issue MRS command to load MR1 with all application settings
      mrs(expected_reg => 1, mrs_reg => mode_registers, got_reset => got_reset);
      if got_reset = '1' then next l0; end if;
      wait until rising_edge(ck_t); check_deselect_command;
      -- 12. Issue MRS command to load MR0 with all application settings
      mrs(expected_reg => 0, mrs_reg => mode_registers, got_reset => got_reset);
      if got_reset = '1' then next l0; end if;
      wait until rising_edge(ck_t); check_deselect_command;
      -- 13. Issue ZQCL command to starting ZQ calibration
      wait until (rising_edge(ck_t) and cke = '1' and cs_n = '0' and act_n = '1' and
        ras_n = '1' and cas_n = '1' and we_n = '0' and ap = '1') or reset_n = '0';
      if reset_n = '0' then next; end if;
      -- 14. Wait for both tDLLK and tZQ init to be completed
      -- tZQ is longer for most speeds, so use that.
      for i in 0 to 1023 loop
        wait until rising_edge(ck_t) or reset_n = '0';
        if reset_n = '0' then next l0; end if;
      end loop;

      initdone <= true;
      wait until reset_n = '0';
    end loop;
  end process;

  fsm : process(ck_t)
    subtype coldata_t is std_logic_vector(data_width - 1 downto 0);
    subtype idata_t is integer range 0 to (2**20)-1;  -- 16 data bits + 2x2 X/U state
    type idata_arr_t is array(natural range <>) of idata_t;
    type idata_arr_acc_t is access idata_arr_t;
    type idata_arr_acc_arr_t is array (natural range <>) of idata_arr_acc_t;
    type row_mem_arr_t is array (natural range <>) of idata_arr_acc_arr_t(0 to 3);

    impure function get_row_bits return natural is
    begin
      case density is
        when 0 => -- 2Gb
          if device_x = 4 then return 15; else return 14; end if;
        when 1 => -- 4Gb
          if device_x = 4 then return 16; else return 15; end if;
        when 2 => -- 8Gb
          if device_x = 4 then return 17; else return 16; end if;
        when 3 => -- 16Gb
          if device_x = 4 then return 18; else return 17; end if;
        when others => report "Bad device density" severity error; return 14;
      end case;
    end function;

    impure function get_bg_bits return natural is
    begin
      if device_x = 16 then return 1; else return 2; end if;
    end function;

    constant col_bits : natural := 10;
    constant row_bits : natural := get_row_bits;
    constant bank_bits : natural := 2;
    constant bg_bits : natural := get_bg_bits;
    constant wl_mem_addr : natural := col_bits + bank_bits + bg_bits;
    constant bank_offset : natural := col_bits;
    constant bg_offset : natural := bank_offset + bank_bits;

    -- The arrays are addressed as (BG, BA, COL) in order of offset size (hi->lo).
    variable memdata : row_mem_arr_t(0 to (2**row_bits) - 1);

    impure function read_memory(bg, bank, row, col : natural) return coldata_t is
      constant loop_top : natural := ((data_width + 15) / 16) - 1;

      variable ptr : natural;
      variable r : coldata_t;
      variable t : std_logic_vector(19 downto 0);
    begin
      ptr := (bg * (2**bg_offset)) + (bank * (2**bank_offset)) + col;

      if memdata(row)(0) /= null then
        for i in 0 to loop_top loop
          t := std_logic_vector(to_unsigned(memdata(row)(i)(ptr), t'length));

          r(7+i*16 downto i*16) := t(7 downto 0);
          if (i < loop_top) or (i = loop_top and data_width mod 16 = 0) then
            r(15+i*16 downto 8+i*16) := t(15 downto 8);
          end if;
        end loop;
      else
        r := (others => unwritten_memory_data);
      end if;

      return r;
    end function;

    procedure write_memory(bg, bank, row, col : in natural;
                           data : in std_logic_vector; mask : in std_logic_vector) is
      constant loop_top : natural := ((data_width + 15) / 16) - 1;

      variable ptr : natural;
      variable t : integer;
    begin
      ptr := (bg * (2**bg_offset)) + (bank * (2**bank_offset)) + col;

      -- Row data allocation
      if memdata(row)(0) = null then
        for i in 0 to 3 loop
          if data_width > (i * 16) then
            memdata(row)(i) := new idata_arr_t(0 to 2**(wl_mem_addr)-1);
          end if;
        end loop;
      end if;

      for i in 0 to loop_top loop
        -- Data retrieval
        t := to_integer(unsigned(data(i * 16 + 7 downto i * 16)));
        if (i < loop_top) or (i = loop_top and data_width mod 16 = 0) then
          t := (to_integer(unsigned(data(i * 16 + 15 downto i * 16 + 8))) * (2**8)) + t;
        end if;

        -- Mask management
        if mask(2*i) = '0' then
          t := ((t / (2**8)) * (2**8)) + (memdata(row)(i)(ptr) mod (2**8));
        end if;
        if (i < loop_top) or (i = loop_top and data_width mod 16 = 0) then
          if mask(2*i + 1) = '0' then
            t := ((memdata(row)(i)(ptr) / (2**8)) * (2**8)) + (t mod (2**8));
          end if;
        end if;

        -- Data write
        memdata(row)(i)(ptr) := t;
      end loop;
    end procedure;

    impure function should_apply_preamble(ci : natural) return boolean is
      variable r : boolean := true;
    begin
      -- Preamble is not applied if the command is matching the tCCD_L/S
      -- Check short tCCD in case of different bank groups.
      if data_cmd_pipe(ci + tCCD_S).valid and
        data_cmd_pipe(ci).bg /= data_cmd_pipe(ci + tCCD_S).bg
      then
        r := false;
      end if;
      -- Check long tCCD in case of the same bank group.
      if data_cmd_pipe(ci + mode_registers.tccd_l).valid and
        data_cmd_pipe(ci).bg = data_cmd_pipe(ci + mode_registers.tccd_l).bg
      then
        r := false;
      end if;
      return r;
    end function;

    variable tCK : time := 0 ps;
    variable tCK_t1 : boolean := false;
    variable tCK_measured : boolean := false;

    variable bank_status : bg_status_arr_t(0 to (2**bg_bits) - 1);
    variable li : natural := 0; -- loop index
    variable burst_length : positive;
    variable col0, col1 : natural := 0;
    variable last_mrs : time := 0 ps;
  begin
    -- Async Reset
    if reset_n = '0' then
      ddr4_state <= init;
      cke_d1 <= '0';
      tCK_measured := false; tCK_t1 := false;
      for i in bank_status'range loop
        for j in bank_status(bank_status'low)'range loop
          bank_status(i)(j).row := -1; -- Not active
          bank_status(i)(j).last_precharge := 0 ns;
        end loop;
      end loop;

    -- Clock action
    elsif rising_edge(ck_t) then
      cke_d1 <= cke;
      data_cmd_pipe(1 to data_cmd_pipe'high) <= data_cmd_pipe(0 to data_cmd_pipe'high-1);
      data_cmd_pipe(0).valid <= false;

      case ddr4_state is
        when init =>
          if initdone = true then ddr4_state <= idle; end if;
        when idle =>
          -- tCK measurement
          if not tCK_measured and tCK_t1 then
            tCK := now - tCK;
            tCK_measured := true;
          elsif not tCK_t1 then
            tCK := now;
            tCK_t1 := true;
          end if;

          -- ACT command
          if cke_d1 = '1' and cke = '1' and cs_n = '0' and act_n = '0' then
            if now - tRP >= bank_status(to_integer(unsigned(bg)))(to_integer(unsigned(ba))).last_precharge then
              ddr4_state <= active;
              if to_integer(unsigned(a)) >= 2**row_bits then
                report "Tried to activate a row outside of the available amount of rows." &
                  " Excess address bits truncated." severity error;
              end if;
              if to_integer(unsigned(bg)) >= 2**bg_bits then
                report "Tried to activate a bank group outside of the available amount of bank groups." &
                  " Excess bank group bit truncated." severity error;
              end if;
              bank_status(to_integer(unsigned(bg(bg_bits - 1 downto 0))))(to_integer(unsigned(ba))).row :=
                to_integer(unsigned(a(row_bits - 1 downto 0)));
            else
              report "tRP(min) violation, ACT command ignored." severity error;
            end if;
          end if;

          -- MRS
          if cke = '1' and cke_d1 = '1' and cs_n = '0' and act_n = '1' and
            ras_n = '0' and cas_n = '0' and we_n = '0'
          then
            -- tMRD = 8 nCK, NOTE this should not be applied to every MRS command.
            -- There are exceptions which are not respected here. See note 2 of fig. 9.
            if now - (8 * tCK) >= last_mrs then
              update_mode_register(to_integer(unsigned(bg(0) & ba)), mode_registers);
              last_mrs := now;
            else
              report "MRS command caused tMRD violation." severity warning;
            end if;
          end if;

          -- READ/WRITE command
          if cke_d1 = '1' and cke = '1' and cs_n = '0' and act_n = '1' and ras_n = '1' and
            cas_n = '0'
          then
            report "Received a READ/WRITE command while in IDLE state." severity warning;
          end if;

          -- TODO: Warn for unsupported commands.

        when active =>
          -- ACT command
          if cke_d1 = '1' and cke = '1' and cs_n = '0' and act_n = '0' then
            if now - tRP >= bank_status(to_integer(unsigned(bg)))(to_integer(unsigned(ba))).last_precharge then
              if bank_status(to_integer(unsigned(bg)))(to_integer(unsigned(ba))).row = -1  then
                if to_integer(unsigned(a)) >= 2**row_bits then
                  report "Tried to activate a row outside of the available amount of rows." &
                    " Excess address bits truncated." severity error;
                end if;
                if to_integer(unsigned(bg)) >= 2**bg_bits then
                  report "Tried to activate a bank group outside of the available amount of bank groups." &
                    " Excess bank group bit truncated." severity error;
                end if;
                bank_status(to_integer(unsigned(bg(bg_bits - 1 downto 0))))(to_integer(unsigned(ba))).row :=
                  to_integer(unsigned(a(row_bits - 1 downto 0)));

              else
                report "Tried to activate a bank that is already active, ACT command ignored." &
                  " BG: " & integer'image(to_integer(unsigned(bg))) &
                  " BA: " & integer'image(to_integer(unsigned(ba))) &
                  " Active row: " & integer'image(
                    bank_status(to_integer(unsigned(bg(bg_bits - 1 downto 0))))(to_integer(unsigned(ba))).row) &
                  " New row: " & integer'image(to_integer(unsigned(a(row_bits - 1 downto 0))))
                  severity warning;
              end if;
            else
              report "tRP(min) violation, ACT command ignored." severity error;
            end if;
          end if;

          -- READ/WRITE command
          if cke_d1 = '1' and cke = '1' and cs_n = '0' and act_n = '1' and ras_n = '1' and
            cas_n = '0'
          then
            -- Check if bank is active.
            if bank_status(to_integer(unsigned(bg)))(to_integer(unsigned(ba))).row >= 0 then
              data_cmd_pipe(0).valid <= true;
              data_cmd_pipe(0).row <=
                bank_status(to_integer(unsigned(bg)))(to_integer(unsigned(ba))).row;
            else
              report "Received a READ/WRITE command for an idle bank." severity warning;
            end if;
            data_cmd_pipe(0).rnw <= we_n;
            data_cmd_pipe(0).bank <= to_integer(unsigned(ba));
            data_cmd_pipe(0).bg <= to_integer(unsigned(bg));
            data_cmd_pipe(0).issued <= now;

            -- tCCD validation
            for i in 1 to mode_registers.tccd_l - 2 loop
              if i < (tCCD_S - 1) and data_cmd_pipe(i).valid then
                report "tCCD Short violation, command ignored." severity warning;
                data_cmd_pipe(0).valid <= false;
              end if;
              if i >= (tCCD_S - 1) and data_cmd_pipe(i).valid and
                data_cmd_pipe(i).bg = to_integer(unsigned(bg))
              then
                report "tCCD Long violation, command ignored." severity warning;
                data_cmd_pipe(0).valid <= false;
              end if;
            end loop;

            -- TODO: Read-to-Write timing verification.

            -- Auto precharge
            -- Changing state will not affect read as a new row can not be activated
            -- before the access is completed. And the pipeline moves independently of
            -- state.
            if ap = '1' then
              bank_status(to_integer(unsigned(bg)))(to_integer(unsigned(ba))).row := -1;
              bank_status(to_integer(unsigned(bg)))(to_integer(unsigned(ba))).last_precharge := now;
              ddr4_state <= idle;
              -- See if the DDR4 rank can become idle.
              for i in bank_status'range loop
                for j in bank_status(bank_status'low)'range loop
                  if bank_status(i)(j).row >= 0 then
                    ddr4_state <= active; -- Override going to idle.
                  end if;
                end loop;
              end loop;
            end if;

            -- Figure out burst length.
            if mode_registers.burst_length = "00" or
              (mode_registers.burst_length = "01" and bc_n = '1')
            then
              burst_length := 8;
            elsif mode_registers.burst_length = "10" or
              (mode_registers.burst_length = "01" and bc_n = '0')
            then
              -- TODO: Handle tWL shortening due to forced BC4.
              burst_length := 4;
            else -- Fall back on BL8
              burst_length := 8;
              report "Fell back to BL8 for read command, most likely due to BL=11 in MR0."
                severity error;
            end if;

            data_cmd_pipe(0).bl <= burst_length;

            -- Data addressing management.
            if we_n = '0' then -- Write
              -- Writes operate on a 8 length offset cycle to simplify calculations.
              data_cmd_pipe(0).col_base <=
                to_integer(unsigned(a(9 downto 3))) * 2**3;

              -- 2 downto 0 should be ignored for BL8, 1 downto 0 for BC4.
              if burst_length = 4 then
                data_cmd_pipe(0).col_offset <=
                  to_integer(unsigned(a(2 downto 2))) * 2**2;
              else
                data_cmd_pipe(0).col_offset <= 0;
              end if;
            else -- Read
              -- Reads operate on a 4 length offset cycle to simplify calculations.
              data_cmd_pipe(0).col_base <=
                to_integer(unsigned(a(9 downto 2))) * 2**2;
              data_cmd_pipe(0).col_offset <= to_integer(unsigned(a(1 downto 0)));
            end if;
          end if;

          -- Precharge Command
          if cke = '1' and cke_d1 = '1' and cs_n = '0' and act_n = '1' and ras_n = '0' and
            cas_n = '1' and we_n = '0'
          then
            ddr4_state <= idle;
            if ap = '1' then -- Precharge all banks
              for i in bank_status'range loop
                for j in bank_status(bank_status'low)'range loop
                  bank_status(i)(j).row := -1; -- Not active
                  bank_status(i)(j).last_precharge := now;
                end loop;
              end loop;
            else -- Precharge single bank
              bank_status(to_integer(unsigned(bg)))(to_integer(unsigned(ba))).row := -1;
              bank_status(to_integer(unsigned(bg)))(to_integer(unsigned(ba))).last_precharge := now;
              -- See if the DDR4 rank can become idle.
              for i in bank_status'range loop
                for j in bank_status(bank_status'low)'range loop
                  if bank_status(i)(j).row >= 0 then
                    ddr4_state <= active; -- Override going to idle.
                  end if;
                end loop;
              end loop;
            end if;
          end if;

          -- MRS
          if cke = '1' and cke_d1 = '1' and cs_n = '0' and act_n = '1' and
            ras_n = '0' and cas_n = '0' and we_n = '0'
          then
            report "Received an MRS command while in ACTIVE state." severity warning;
          end if;

        when others => null;
      end case;

      -- Data Command Pipeline Handling
      -- Read Preamble
      li := mode_registers.cas_latency + mode_registers.additive_latency -
        mode_registers.read_preamble - 1;
      if data_cmd_pipe(li).valid and data_cmd_pipe(li).rnw = '1' then
        if should_apply_preamble(li) then
          read_preamble_enable <= not read_preamble_enable;
        end if;
      end if;
      -- Read
      -- Read Latency (RL) = Additive Latency (AL) + CAS Latency (CL) +
      --   Parity Latency (PL).
      for i in
        mode_registers.cas_latency + mode_registers.additive_latency - 1 to
        mode_registers.cas_latency + mode_registers.additive_latency + 3
      loop
        li := (i - (mode_registers.cas_latency +
          mode_registers.additive_latency - 1));
        if data_cmd_pipe(i).valid and data_cmd_pipe(i).rnw = '1' and
          li < (data_cmd_pipe(i).bl / 2)
        then
          -- Read data organization in accordance with Table 18.
          col0 := data_cmd_pipe(i).col_base +
            ((data_cmd_pipe(i).col_offset + 2 * li) mod 4);

          if mode_registers.read_burst_type = '1' and
            data_cmd_pipe(i).col_offset mod 2 = 1
          then -- Interleaved mode
            -- offset mod 2 = 1 => col1 backwards ordering.
            col1 := data_cmd_pipe(i).col_base +
              ((data_cmd_pipe(i).col_offset + 2 * li + 3) mod 4);
          else -- Sequential or even interleaved.
            col1 := data_cmd_pipe(i).col_base +
              ((data_cmd_pipe(i).col_offset + 2 * li + 1) mod 4);
          end if;
          read_data(0) <= read_memory(data_cmd_pipe(i).bg, data_cmd_pipe(i).bank,
                                      data_cmd_pipe(i).row, col0);
          read_data(1) <= read_memory(data_cmd_pipe(i).bg, data_cmd_pipe(i).bank,
                                      data_cmd_pipe(i).row, col1);
          read_enable <= not read_enable;

          -- BL8 can be considered as two BC4s with an overflowing 3rd bit.
          if li = 1 then
            -- Flip bit 3 of the column base.
            if data_cmd_pipe(i).col_base mod 8 >= 4 then
              data_cmd_pipe(i+1).col_base <= data_cmd_pipe(i).col_base - 4;
            else
              data_cmd_pipe(i+1).col_base <= data_cmd_pipe(i).col_base + 4;
            end if;
          end if;
        end if;
      end loop;

      -- Write
      -- Write Latency (WL) = CAS Write Latency (CWL) + Additive Latency (AL) +
      --  Parity Latency (PL).
      -- Parity not supported -> PL = 0
      -- Note that the access in not delayed by preamble.
      -- The preamble is expected to be included in the CWL.
      -- TODO: tWL shortening due to forced BC4.
      for i in
        mode_registers.cas_write_latency + mode_registers.additive_latency - 1 to
        mode_registers.cas_write_latency + mode_registers.additive_latency + 4
      loop
        li := (i - (mode_registers.cas_write_latency +
          mode_registers.additive_latency - 1));
        if data_cmd_pipe(i).valid and data_cmd_pipe(i).rnw = '0' and
          li < (data_cmd_pipe(i).bl / 2)
        then
          write_enable <= not write_enable;
        end if;

        if data_cmd_pipe(i).valid and data_cmd_pipe(i).rnw = '0' and
          li > 0 and li < (data_cmd_pipe(i).bl / 2) + 1
        then
          col0 := data_cmd_pipe(i).col_base + data_cmd_pipe(i).col_offset;
          write_memory(data_cmd_pipe(i).bg, data_cmd_pipe(i).bank,
                       data_cmd_pipe(i).row, col0 + 2 * (li - 1),
                       write_data(0), write_mask(0));
          write_memory(data_cmd_pipe(i).bg, data_cmd_pipe(i).bank,
                       data_cmd_pipe(i).row, col0 + 2 * (li - 1) + 1,
                       write_data(1), write_mask(1));
        end if;
      end loop;
    end if;
  end process;

  dq_dqs_p : process is
    procedure apply_read_dbi(index : in natural) is
    begin
      for i in 0 to data_width / 8 - 1 loop
        if count_zeroes(read_data(index)(8*(i + 1) - 1 downto 8 * i)) > 4 then
          dq(8*(i + 1) - 1 downto 8 * i) <=
            not read_data(index)(8*(i + 1) - 1 downto 8 * i);
          dm_dbi_n(i) <= '0';
        else
          dq(8*(i + 1) - 1 downto 8 * i) <=
            read_data(index)(8*(i + 1) - 1 downto 8 * i);
          dm_dbi_n(i) <= '1';
        end if;
      end loop;
    end procedure;

    procedure apply_write_dbi(index : in natural) is
    begin
      for i in 0 to data_width / 8 - 1 loop
        if dm_dbi_n(i) = '0' then
          write_data(index)(8*(i + 1) - 1 downto 8 * i) <=
            not dq(8*(i + 1) - 1 downto 8 * i);
        else
          write_data(index)(8*(i + 1) - 1 downto 8 * i) <=
            dq(8*(i + 1) - 1 downto 8 * i);
        end if;
      end loop;
    end procedure;
  begin
    dq <= (others => 'Z');
    dqs_t <= (others => 'Z');
    dqs_c <= (others => 'Z');
    dm_dbi_n <= (others => 'Z');
    wait until read_enable'event or write_enable'event or read_preamble_enable'event;
    if read_preamble_enable'event then
      if mode_registers.read_preamble = 2 then
        dqs_t <= (others => '1');
        dqs_c <= (others => '0');
        wait until rising_edge(ck_t);
      end if;
      dqs_t <= (others => '1');
      dqs_c <= (others => '0');
      wait until falling_edge(ck_t);
      dqs_t <= (others => '0');
      dqs_c <= (others => '1');
      wait until rising_edge(ck_t); -- Should be hold time for speed bin...
    end if;
    if read_enable'event then
      if mode_registers.read_dbi = '1' then
        apply_read_dbi(0);
      else
        dq <= read_data(0);
      end if;
      dqs_t <= (others => '1');
      dqs_c <= (others => '0');
      wait until falling_edge(ck_t);
      if mode_registers.read_dbi = '1' then
        apply_read_dbi(1);
      else
        dq <= read_data(1);
      end if;
      dqs_t <= (others => '0');
      dqs_c <= (others => '1');
      wait until rising_edge(ck_t); -- Should be hold time for speed bin...
    end if;
    if write_enable'event then
      -- Data
      if mode_registers.write_dbi = '1' then
        apply_write_dbi(0);
      else
        write_data(0) <= dq;
      end if;
      -- Mask
      if mode_registers.data_mask = '1' then
        write_mask(0) <= dm_dbi_n;
      else
        write_mask(0) <= (others => '1');
      end if;
      wait until falling_edge(ck_t);
      -- Data
      if mode_registers.write_dbi = '1' then
        apply_write_dbi(1);
      else
        write_data(1) <= dq;
      end if;
      -- Mask
      if mode_registers.data_mask = '1' then
        write_mask(1) <= dm_dbi_n;
      else
        write_mask(1) <= (others => '1');
      end if;
    end if;
  end process;
end architecture;
-- pragma translate_on
