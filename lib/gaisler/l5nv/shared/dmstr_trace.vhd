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
-- Entity:      dmstr_trace
-- File:        dmstr_trace.vhd
-- Author:      Carl Ehrenstrahle
-- Description: Independent stripe AHB trace module.
--              Traces completed accesses on one striped bus.
--              Traces can only be read out while the module is disabled.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;

-- dmstr_trace data type.
library gaisler;
use gaisler.l5nv_shared.all;

-- For syncram and mbist related things.
library techmap;
use techmap.gencomp.all;

entity dmstr_trace is
  generic (
    memtech : integer := 0;
    buffer_depth : integer := 128;
    striped_bus_data_width : integer range 32 to 128 := 128;
    scantest : integer := 0;
    -- Disable debug master tracing at reset. -1 do not disable else hindex.
    dbg_master_trace_reset : integer := -1
  );
  port (
    clk : in std_ulogic;
    rstn : in std_ulogic;
    timer : in std_logic_vector(62 downto 0);
    -- Register interface
    reg_slvi : in dmstr_trace_m2s_type;
    reg_slvo : out dmstr_trace_s2m_type;
    testin : in std_logic_vector(TESTIN_WIDTH - 1 downto 0);
    -- Striped bus to be traced
    sb_slvo : in ahbstripe_slv_out_slice;
    sb_slvi : in ahbstripe_slv_in_slice;
    sb_endian : in std_ulogic -- 0: BE, 1: LE
  );
end entity;

architecture rtl of dmstr_trace is
  constant async_reset_c : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  function min(a, b : integer) return integer is
  begin
    if a < b then return a; else return b; end if;
  end function min;

  function to_usl(a : boolean) return std_ulogic is
    variable r : std_ulogic;
  begin
    if a then r := '1'; else r := '0'; end if; return r;
  end function to_usl;

  -- A copy is tested in the standalone testbench.
  function clog2(arg : natural) return positive is
  begin
    for i in 1 to 31 loop
      if 2**i >= arg then
        return i;
      end if;
    end loop;
    return 32; -- If 2**31 isn't enough, then there is only 32 left for 32-bit integers.
  end function clog2;

  function get_master_filter_reset_mask(dbg_rst : integer) return
    std_logic_vector is
    variable mask : std_logic_vector(15 downto 0);
  begin
    mask := (others => '1');
    if dbg_rst >= 0 then
      mask(dbg_rst) := '0';
    end if;
    return mask;
  end function;

  -- Buffer data placement constants.
  -- Lengths sourced from input record definition (ahbstripe.vhd).
  constant htrans_bot : natural := 0;
  constant htrans_top : natural := htrans_bot + 1;
  constant hsize_bot : natural := htrans_top + 1;
  constant hsize_top : natural := hsize_bot + 2;
  constant hwrite_idx : natural := hsize_top + 1;
  constant hburst_idx : natural := hwrite_idx + 1;
  constant hmaster_bot : natural := hburst_idx + 1;
  constant hmaster_top : natural := hmaster_bot + 3;
  constant hmastlock_idx : natural := hmaster_top + 1;
  constant hresp_bot : natural := hmastlock_idx + 1;
  constant hresp_top : natural := hresp_bot + 1;
  constant haddr_bot : natural := hresp_top + 1;
  constant haddr_top : natural := haddr_bot + 47;
  constant hdata_bot : natural := haddr_top + 1;
  constant hdata_top : natural := hdata_bot + striped_bus_data_width - 1;
  constant timer_bot : natural := hdata_top + 1;
  constant timer_top : natural := timer_bot + 62;
  constant breakpoint_hit_idx : natural := timer_top + 1;
  constant watchpoint_hit_idx : natural := breakpoint_hit_idx + 1;

  constant ram_depth_c : natural := clog2(buffer_depth);
  constant ram_width_c : natural := watchpoint_hit_idx + 1; -- Must be the highest index in the constant list
  constant ram_width_split_c : integer := 64;
  constant level_width_c : natural := clog2(buffer_depth + 1);

  constant xcrement_disabled_c : std_logic_vector(1 downto 0) := "00";
  constant xcrement_increment_c : std_logic_vector(1 downto 0) := "01";
  constant xcrement_decrement_c : std_logic_vector(1 downto 0) := "10";


  type regs_t is record
    enable : std_ulogic;
    level : natural range 0 to buffer_depth;
    buf_i_ptr : natural range 0 to buffer_depth - 1;
    buf_o_ptr : natural range 0 to buffer_depth - 1;
    s2breakpoint_hit : std_ulogic;
    s2watchpoint_hit : std_ulogic;
    s2haddr : std_logic_vector(47 downto 0);
    s2hwrite : std_logic;
    s2htrans : std_logic_vector(1 downto 0);
    s2hsize : std_logic_vector(2 downto 0);
    s2hburst : std_ulogic;
    s2hmaster : std_logic_vector(3 downto 0);
    s2hmastlock : std_logic;
    s2hresp : std_logic_vector(1 downto 0);
    s2data : std_logic_vector(striped_bus_data_width-1 downto 0);
    s2timer : std_logic_vector(62 downto 0);
    s1haddr : std_logic_vector(47 downto 0);
    s1hwrite : std_logic;
    s1htrans : std_logic_vector(1 downto 0);
    s1hsize : std_logic_vector(2 downto 0);
    s1hburst : std_ulogic;
    s1hmaster : std_logic_vector(3 downto 0);
    s1hmastlock : std_logic;
    reg_s2m : dmstr_trace_s2m_type;
    data_read_address : std_logic_vector(3 downto 0);
    do_data_read : std_logic_vector(2 downto 0);
    breakpoint_enable : std_ulogic;
    breakpoint_address : std_logic_vector(63 downto 0);
    breakpoint_address_mask : std_logic_vector(61 downto 0);
    breakpoint_match_read : std_ulogic;
    breakpoint_match_write : std_ulogic;
    breakpoint_timer_run : std_ulogic;
    breakpoint_timer_start_value : std_logic_vector(15 downto 0);
    breakpoint_timer : std_logic_vector(15 downto 0);
    breakpoint_hit_action : std_ulogic;
    xcrement_mode : std_logic_vector(1 downto 0);
    watchpoint_enable : std_ulogic;
    watchpoint_data : std_logic_vector(striped_bus_data_width - 1 downto 0);
    watchpoint_mask : std_logic_vector(striped_bus_data_width / 8 - 1 downto 0);
    watchpoint_match_read : std_ulogic;
    watchpoint_match_write : std_ulogic;
    couple_xpoints : std_ulogic; -- Break and watchpoint both need to trigger.
    breakpoint_hit_en : std_ulogic; -- Enable for the external breakpoint_hit signal.
    master_filter_mask : std_logic_vector(15 downto 0); -- 2**hmaster'length
  end record;

  constant regs_reset_c : regs_t := (
    enable => '1',
    level => 0,
    buf_i_ptr => 0,
    buf_o_ptr => 0,
    s2breakpoint_hit => '0',
    s2watchpoint_hit => '0',
    s2haddr => (others => '0'),
    s2hwrite => '0',
    s2htrans => HTRANS_IDLE,
    s2hsize => "000",
    s2hburst => '0',
    s2hmaster => "0000",
    s2hmastlock => '0',
    s2hresp => "00",
    s2data => (others => '0'),
    s2timer => (others => '0'),
    s1haddr => (others => '0'),
    s1hwrite => '0',
    s1htrans => HTRANS_IDLE,
    s1hsize => "000",
    s1hburst => '0',
    s1hmaster => "0000",
    s1hmastlock => '0',
    reg_s2m => dmstr_trace_s2m_type_none,
    data_read_address => (others => '0'),
    do_data_read => (others => '0'),
    breakpoint_enable => '0',
    breakpoint_address => (others => '0'),
    breakpoint_address_mask => (others => '1'),
    breakpoint_match_read => '1',
    breakpoint_match_write => '1',
    breakpoint_timer_run => '0',
    breakpoint_timer_start_value => (others => '0'),
    breakpoint_timer => (others => '0'),
    breakpoint_hit_action => '0',
    xcrement_mode => xcrement_decrement_c,
    watchpoint_enable => '0',
    watchpoint_data => (others => '0'),
    watchpoint_mask => (others => '1'),
    watchpoint_match_read => '1',
    watchpoint_match_write => '1',
    couple_xpoints => '0',
    breakpoint_hit_en => '0',
    master_filter_mask => get_master_filter_reset_mask(dbg_master_trace_reset)
  );

  constant reg_control_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"0";
  constant reg_status_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"1";
  constant reg_optr_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"2";
  constant reg_iptr_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"3";
  constant reg_breakpoint_msb_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"4";
  constant reg_breakpoint_lsb_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"5";
  constant reg_breakpoint_mask_msb_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"6";
  constant reg_breakpoint_mask_lsb_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"7";
  constant reg_breakpoint_timer_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"8";
  constant reg_watchpoint_data_3_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"9";
  constant reg_watchpoint_data_2_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"A";
  constant reg_watchpoint_data_1_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"B";
  constant reg_watchpoint_data_0_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"C";
  constant reg_watchpoint_mask_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"D";
  constant reg_issuer_filter_idx :
    std_logic_vector(reg_slvi.address'length - 2 downto 0) := x"E";

  signal r, rin : regs_t;
  signal mem_address : std_logic_vector(ram_depth_c - 1 downto 0);
  signal mem_data_in : std_logic_vector(ram_width_c - 1 downto 0);
  signal mem_data_out : std_logic_vector(ram_width_c - 1 downto 0);
  signal mem_enable : std_ulogic;
  signal mem_write : std_ulogic;
begin

  --====================
  -- Combinatorial Logic
  --====================
  comb_p : process(timer, reg_slvi, sb_slvo, sb_slvi, sb_endian, mem_data_out, r) is
    function addr_to_byte_offset (addr : in std_logic_vector;
                                  size : in std_logic_vector;
                                  dw : in positive;
                                  endian : in std_ulogic) return natural is
      variable r : integer range 0 to striped_bus_data_width / 8 - 1;
    begin
      r := 0;
      if endian = '1' then -- Little endian
        -- Manually unroll for Design Compiler support.
        -- Formality will complain if the ranging results in a null range.
        if dw > 8 and size = "000" then
          r := to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 0)));
        end if;
        if dw > 16 and size = "001" then
          r := to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 1)));
        end if;
        if dw > 32 and size = "010" then
          r := to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 2)));
        end if;
        if dw > 64 and size = "011" then
          r := to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 3)));
        end if;
        if dw > 128 and size = "100" then
          r := to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 4)));
        end if;
        if dw > 256 and size = "101" then
          r := to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 5)));
        end if;
        if dw > 512 and size = "110" then
          r := to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 6)));
        end if;
        if dw > 1024 and size = "111" then
          r := to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 7)));
        end if;
      else
        if dw > 8 and size = "000" then
          r := (dw / (8 * 2**0) - 1) - to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 0)));
        end if;
        if dw > 16 and size = "001" then
          r := (dw / (8 * 2**1) - 1) - to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 1)));
        end if;
        if dw > 32 and size = "010" then
          r := (dw / (8 * 2**2) - 1) - to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 2)));
        end if;
        if dw > 64 and size = "011" then
          r := (dw / (8 * 2**3) - 1) - to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 3)));
        end if;
        if dw > 128 and size = "100" then
          r := (dw / (8 * 2**4) - 1) - to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 4)));
        end if;
        if dw > 256 and size = "101" then
          r := (dw / (8 * 2**5) - 1) - to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 5)));
        end if;
        if dw > 512 and size = "110" then
          r := (dw / (8 * 2**6) - 1) - to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 6)));
        end if;
        if dw > 1024 and size = "111" then
          r := (dw / (8 * 2**7) - 1) - to_integer(unsigned(addr(clog2(dw / 8) - 1 downto 7)));
        end if;
      end if;

      return r * (2**to_integer(unsigned(size)));
    end function;

    -- Will return 0 for both no one found and found at index 0.
    -- This currently results in the behaviour that an empty mask will always trigger.
    function find_topmost_one (a : std_logic_vector) return natural is
      variable ret : integer range 0 to 127;
    begin
      ret := 0;
      for i in a'high downto a'low loop
        if a(i) = '1' then
          ret := i;
          exit;
        end if;
      end loop;
      return ret;
    end function;

    variable v : regs_t;
    variable mem_ptr : natural range 0 to buffer_depth - 1;
    variable merged_enable : std_ulogic;
    variable breakpoint_addr_mask : std_logic_vector(61 downto 0);
    variable breakpoint_addr_match : boolean;
    variable watchpoint_data_match : boolean;
    variable watchpoint_data_offset : integer range 0 to striped_bus_data_width / 8 - 1;
    variable watchpoint_data_shifted :
      std_logic_vector(striped_bus_data_width - 1 downto 0);
    variable watchpoint_mask_shifted :
      std_logic_vector(striped_bus_data_width / 8 - 1 downto 0);
  begin
    v := r;
    merged_enable := reg_slvi.enable and r.enable;

    ----------------------
    -- Register File and Data Readout
    ----------------------
    v.reg_s2m.valid := '0';
    -- Shift read data validity, default with no valid read at index 0.
    v.do_data_read := r.do_data_read(r.do_data_read'high - 1 downto 0) & '0';

    if reg_slvi.valid = '1' then
      if reg_slvi.address(reg_slvi.address'high) = '0' then -- Register Accesses
        v.reg_s2m.valid := '1'; -- Registers are 1 cycle accessible.
        v.reg_s2m.data := (others => '0');

        case reg_slvi.address(reg_slvi.address'length - 2 downto 0) is
          when reg_control_idx =>
            if reg_slvi.write = '1' then
              v.breakpoint_hit_en := reg_slvi.data(6);
              v.couple_xpoints := reg_slvi.data(5);
              v.watchpoint_enable := reg_slvi.data(4);
              v.xcrement_mode := reg_slvi.data(3 downto 2);
              v.breakpoint_enable := reg_slvi.data(1);
              v.enable := reg_slvi.data(0);
            else
              v.reg_s2m.data(6) := r.breakpoint_hit_en;
              v.reg_s2m.data(5) := r.couple_xpoints;
              v.reg_s2m.data(4) := r.watchpoint_enable;
              v.reg_s2m.data(3 downto 2) := r.xcrement_mode;
              v.reg_s2m.data(1) := r.breakpoint_enable;
              v.reg_s2m.data(0) := r.enable;
            end if;

          when reg_status_idx =>
            if reg_slvi.write = '1' and r.enable = '0' then
              if reg_slvi.data(0) = '1' then
                v.level := 0;
              end if;
            else
              if striped_bus_data_width = 8 then
                v.reg_s2m.data(31 downto 29) := (others => '0');
              else
                v.reg_s2m.data(31 downto 29) :=
                  std_logic_vector(to_unsigned(clog2(striped_bus_data_width / 8), 3));
              end if;
              v.reg_s2m.data(28) := merged_enable;
              v.reg_s2m.data(level_width_c - 1 downto 0) :=
                std_logic_vector(to_unsigned(r.level, level_width_c));
            end if;

          when reg_optr_idx =>
            if reg_slvi.write = '1' then
              v.buf_o_ptr :=
                to_integer(unsigned(reg_slvi.data(ram_depth_c - 1 downto 0)));
            else
              v.reg_s2m.data(ram_depth_c - 1 downto 0) :=
                std_logic_vector(to_unsigned(r.buf_o_ptr, ram_depth_c));
            end if;

          when reg_iptr_idx => -- Read only
            v.reg_s2m.data(ram_depth_c - 1 downto 0) :=
              std_logic_vector(to_unsigned(r.buf_i_ptr, ram_depth_c));

          when reg_breakpoint_msb_idx =>
            if reg_slvi.write = '1' then
              v.breakpoint_address(min(64, sb_slvi.hsladdr'length) - 1 downto 32) :=
                reg_slvi.data(min(64, sb_slvi.hsladdr'length) - 32 - 1 downto 0);
            else
              v.reg_s2m.data(min(64, sb_slvi.hsladdr'length) - 32 - 1 downto 0) :=
                r.breakpoint_address(min(64, sb_slvi.hsladdr'length) - 1 downto 32);
            end if;

          when reg_breakpoint_lsb_idx =>
            if reg_slvi.write = '1' then
              v.breakpoint_address(31 downto 0) := reg_slvi.data(31 downto 0);
            else
              v.reg_s2m.data(31 downto 0) := r.breakpoint_address(31 downto 0);
            end if;

          when reg_breakpoint_mask_msb_idx =>
            if reg_slvi.write = '1' then
              v.breakpoint_match_read := reg_slvi.data(31);
              v.breakpoint_match_write := reg_slvi.data(30);
              v.breakpoint_address_mask(min(62, sb_slvi.hsladdr'length) - 1 downto 32) :=
                reg_slvi.data(min(62, sb_slvi.hsladdr'length) - 32 - 1 downto 0);
            else
              v.reg_s2m.data(31) := r.breakpoint_match_read;
              v.reg_s2m.data(30) := r.breakpoint_match_write;
              v.reg_s2m.data(min(62, sb_slvi.hsladdr'length) - 32 - 1 downto 0) :=
                r.breakpoint_address_mask(min(62, sb_slvi.hsladdr'length) - 1 downto 32);
            end if;

          when reg_breakpoint_mask_lsb_idx =>
            if reg_slvi.write = '1' then
              v.breakpoint_address_mask(31 downto 0) := reg_slvi.data(31 downto 0);
            else
              v.reg_s2m.data(31 downto 0) := r.breakpoint_address_mask(31 downto 0);
            end if;

          when reg_breakpoint_timer_idx =>
            if reg_slvi.write = '1' then
              v.breakpoint_timer_start_value := reg_slvi.data(15 downto 0);
            else
              v.reg_s2m.data(15 downto 0) := r.breakpoint_timer_start_value;
            end if;

          when reg_watchpoint_data_3_idx =>
            if striped_bus_data_width > 96 then
              if reg_slvi.write = '1' then
                v.watchpoint_data(127 downto 96) := reg_slvi.data;
              else
                v.reg_s2m.data := r.watchpoint_data(127 downto 96);
              end if;
            end if;

          when reg_watchpoint_data_2_idx =>
            if striped_bus_data_width > 64 then
              if reg_slvi.write = '1' then
                v.watchpoint_data(95 downto 64) := reg_slvi.data;
              else
                v.reg_s2m.data := r.watchpoint_data(95 downto 64);
              end if;
            end if;

          when reg_watchpoint_data_1_idx =>
            if striped_bus_data_width > 32 then
              if reg_slvi.write = '1' then
                v.watchpoint_data(63 downto 32) := reg_slvi.data;
              else
                v.reg_s2m.data := r.watchpoint_data(63 downto 32);
              end if;
            end if;

          when reg_watchpoint_data_0_idx =>
            if reg_slvi.write = '1' then
              v.watchpoint_data(31 downto 0) := reg_slvi.data;
            else
              v.reg_s2m.data := r.watchpoint_data(31 downto 0);
            end if;

          when reg_watchpoint_mask_idx =>
            if reg_slvi.write = '1' then
              -- This will break if striped_bus_data_width >= 240.
              v.watchpoint_match_read := reg_slvi.data(31);
              v.watchpoint_match_write := reg_slvi.data(30);
              v.watchpoint_mask := reg_slvi.data(r.watchpoint_mask'range);
            else
              v.reg_s2m.data(31) := r.watchpoint_match_read;
              v.reg_s2m.data(30) := r.watchpoint_match_write;
              v.reg_s2m.data(r.watchpoint_mask'range) := r.watchpoint_mask;
            end if;

          when reg_issuer_filter_idx =>
            if reg_slvi.write = '1' then
              v.master_filter_mask := reg_slvi.data(15 downto 0);
            else
              v.reg_s2m.data(15 downto 0) := r.master_filter_mask;
            end if;

          when others => null;
        end case;

      else -- Data access, read only.
        -- Data accesses are only avaiable when the core is not actively tracing.
        if merged_enable = '0' then
          v.do_data_read(0) := '1';
          v.data_read_address := reg_slvi.address(reg_slvi.address'length - 2 downto 0);
        else
          v.reg_s2m.valid := '1';
          v.reg_s2m.data := (others => '0');
        end if;
      end if;
    end if;

    -- Active data read response handling.
    if r.do_data_read(r.do_data_read'high) = '1' then
      v.reg_s2m.valid := '1';

      -- Data format based on api=1 from dmnv_trace.vhd
      case r.data_read_address is
        when "0111" =>
          if striped_bus_data_width > 96 then
            v.reg_s2m.data := mem_data_out(hdata_bot + 127 downto hdata_bot + 96);
            -- Buffer pointer auto xcrement.
            if r.xcrement_mode = xcrement_increment_c then
              v.buf_o_ptr := (r.buf_o_ptr + 1) mod buffer_depth;
            elsif r.xcrement_mode = xcrement_decrement_c then
              v.buf_o_ptr := (r.buf_o_ptr - 1) mod buffer_depth;
            end if;
          else
            v.reg_s2m.data := (others => '0');
          end if;
        when "0110" =>
          if striped_bus_data_width > 64 then
            v.reg_s2m.data := mem_data_out(hdata_bot + 95 downto hdata_bot + 64);
          else
            v.reg_s2m.data := (others => '0');
          end if;
        when "0101" =>
          if striped_bus_data_width > 32 then
            v.reg_s2m.data := mem_data_out(hdata_bot + 63 downto hdata_bot + 32);
            -- Buffer pointer auto xcrement.
            if striped_bus_data_width = 64 then
              if r.xcrement_mode = xcrement_increment_c then
                v.buf_o_ptr := (r.buf_o_ptr + 1) mod buffer_depth;
              elsif r.xcrement_mode = xcrement_decrement_c then
                v.buf_o_ptr := (r.buf_o_ptr - 1) mod buffer_depth;
              end if;
            end if;
          else
            v.reg_s2m.data := (others => '0');
          end if;
        when "0100" =>
          v.reg_s2m.data := mem_data_out(hdata_bot + 31 downto hdata_bot);
        when "0011" =>
          v.reg_s2m.data := '0' & mem_data_out(timer_bot + 62 downto timer_bot + 32);
        when "0010" =>
          v.reg_s2m.data := mem_data_out(timer_bot + 31 downto timer_bot);
        when "0001" =>
          v.reg_s2m.data := mem_data_out(haddr_bot + 31 downto haddr_bot);
        when "0000" =>
          v.reg_s2m.data := mem_data_out(haddr_bot + 47 downto haddr_bot + 32) &
            mem_data_out(hwrite_idx) &
            mem_data_out(htrans_top downto htrans_bot) &
            mem_data_out(hsize_top downto hsize_bot) &
            mem_data_out(watchpoint_hit_idx) &
            mem_data_out(breakpoint_hit_idx) &
            mem_data_out(hburst_idx) &
            mem_data_out(hmaster_top downto hmaster_bot) &
            mem_data_out(hmastlock_idx) &
            mem_data_out(hresp_top downto hresp_bot);
        when others => v.reg_s2m.data := (others => '0');
      end case;
    end if;

    ----------------------
    -- AHB Tracing
    ----------------------
    --~~~~~~~~~~~~~~~~~~~~
    -- Stage 1 - sample AHB access address phase
    --~~~~~~~~~~~~~~~~~~~~
    if sb_slvo.hready = '1' then
      v.s1haddr := sb_slvi.hsladdr;
      v.s1hwrite := sb_slvi.hwrite;
      v.s1htrans := sb_slvi.htrans;
      v.s1hsize := sb_slvi.hsize;
      v.s1hburst := sb_slvi.hburst0;
      v.s1hmaster := sb_slvi.hmaster;
      v.s1hmastlock := sb_slvi.hmastlock;
    end if;

    --~~~~~~~~~~~~~~~~~~~~
    -- Stage 2 - sample AHB access data phase
    --~~~~~~~~~~~~~~~~~~~~
    -- Data sampled here will be written to the memory.
    v.s2htrans := HTRANS_IDLE; -- htrans used as pipeline qualifier for memory writing.
    if sb_slvo.hready = '1' and merged_enable = '1' and
      r.master_filter_mask(to_integer(unsigned(r.s1hmaster))) = '1'
    then
      v.s2htrans := r.s1htrans;
    end if;
    v.s2haddr := r.s1haddr;
    v.s2hwrite := r.s1hwrite;
    v.s2hsize :=  r.s1hsize;
    v.s2hburst := r.s1hburst;
    v.s2hmaster := r.s1hmaster;
    v.s2hmastlock := r.s1hmastlock;
    v.s2hresp := sb_slvo.hresp;
    if r.s1hwrite = '1' then
      v.s2data := sb_slvi.hwdata(striped_bus_data_width - 1 downto 0);
    else
      v.s2data := sb_slvo.hrdata(striped_bus_data_width - 1 downto 0);
    end if;
    v.s2timer := timer;

    -- Breakpoint
    v.breakpoint_hit_action := '0';
    breakpoint_addr_match := true;
    -- Make sure that wider accesses containing the breakpoint get caught.
    breakpoint_addr_mask := r.breakpoint_address_mask;
    for i in 0 to 6 loop
      if to_integer(unsigned(r.s1hsize)) > i then
        breakpoint_addr_mask(i) := '0';
      end if;
    end loop;
    -- Match the address to the breakpoint adress
    for i in r.s1haddr'range loop
      if breakpoint_addr_mask(i) = '1' then
        if r.s1haddr(i) /= r.breakpoint_address(i) then
          breakpoint_addr_match := false;
        end if;
      end if;
    end loop;
    if r.breakpoint_enable = '1' and v.s2htrans /= HTRANS_IDLE and
      breakpoint_addr_match and
      ((r.s1hwrite = '1' and r.breakpoint_match_write = '1') or
        (r.s1hwrite = '0' and r.breakpoint_match_read = '1'))
    then
      v.s2breakpoint_hit := '1';
    else
      v.s2breakpoint_hit := '0';
    end if;

    -- Watchpoint
    watchpoint_data_offset := addr_to_byte_offset(r.s1haddr, r.s1hsize,
                                                  striped_bus_data_width, sb_endian);
    watchpoint_data_shifted := std_logic_vector(shift_left(unsigned(r.watchpoint_data),
                                                           watchpoint_data_offset * 8));
    watchpoint_mask_shifted := std_logic_vector(shift_left(unsigned(r.watchpoint_mask),
                                                           watchpoint_data_offset));
    -- Only allow watchpoint to trigger if the transaction size is large enough.
    if 2**to_integer(unsigned(r.s1hsize)) > find_topmost_one(r.watchpoint_mask) then
      watchpoint_data_match := true;
    else
      watchpoint_data_match := false;
    end if;
    for i in r.watchpoint_mask'range loop
      if i >= watchpoint_data_offset and
        i < watchpoint_data_offset + 2**to_integer(unsigned(r.s1hsize))
      then
        if watchpoint_mask_shifted(i) = '1' then
          if r.s1hwrite = '1' then
            if watchpoint_data_shifted(i * 8 + 7 downto i * 8) /=
              sb_slvi.hwdata(i * 8 + 7 downto i * 8)
            then
              watchpoint_data_match := false;
            end if;
          else
            if watchpoint_data_shifted(i * 8 + 7 downto i * 8) /=
              sb_slvo.hrdata(i * 8 + 7 downto i * 8)
            then
              watchpoint_data_match := false;
            end if;
          end if;
        end if;
      end if;
    end loop;
    if r.watchpoint_enable = '1' and v.s2htrans /= HTRANS_IDLE and
      watchpoint_data_match and
      ((r.s1hwrite = '1' and r.watchpoint_match_write = '1') or
        (r.s1hwrite = '0' and r.watchpoint_match_read = '1'))
    then
      v.s2watchpoint_hit := '1';
    else
      v.s2watchpoint_hit := '0';
    end if;

    -- Trigger Xpoint action trigger.
    if ((r.couple_xpoints and v.s2watchpoint_hit and v.s2breakpoint_hit) = '1') or
      ((not r.couple_xpoints and (v.s2watchpoint_hit or v.s2breakpoint_hit)) = '1')
    then
      if r.breakpoint_timer_start_value =
        std_logic_vector(to_unsigned(0, r.breakpoint_timer_start_value'length))
      then
        v.breakpoint_hit_action := '1';
      else
        v.breakpoint_timer_run := '1';
        v.breakpoint_timer := r.breakpoint_timer_start_value;
      end if;
    end if;

    --~~~~~~~~~~~~~~~~~~~~
    -- Stage 3 - Memory write / Actions
    --~~~~~~~~~~~~~~~~~~~~
    if r.s2htrans /= HTRANS_IDLE then
      -- Memory management
      v.buf_i_ptr := (r.buf_i_ptr + 1) mod buffer_depth;
      if r.level < buffer_depth then
        v.level := r.level + 1;
      end if;
    end if;

    --~~~~~~~~~~~~~~~~~~~~
    -- Non-pipeline
    --~~~~~~~~~~~~~~~~~~~~
    if r.breakpoint_timer_run = '1' then
      if r.breakpoint_timer =
        std_logic_vector(to_unsigned(0, r.breakpoint_timer'length))
      then
        v.breakpoint_hit_action := '1';
        v.breakpoint_timer_run := '0';
      else
        v.breakpoint_timer := std_logic_vector(unsigned(r.breakpoint_timer) -
          to_unsigned(1, r.breakpoint_timer'length));
      end if;
    end if;

    if r.breakpoint_hit_action = '1' then
      -- Must happen after Stage 2.
      v.enable := '0';
    end if;

    ----------------------
    -- Signal Assignments
    ----------------------
    -- Next state
    rin <= v;

    -- Output
    reg_slvo <= r.reg_s2m;
    reg_slvo.breakpoint_hit <= r.breakpoint_hit_action and r.breakpoint_hit_en;

    -- Memory assignments
    if merged_enable = '1' then mem_ptr := r.buf_i_ptr; else mem_ptr := r.buf_o_ptr; end if;
    mem_address <= std_logic_vector(to_unsigned(mem_ptr, ram_depth_c));
    mem_write <= merged_enable;
    if merged_enable = '1' then
      mem_enable <= to_usl(r.s2htrans /= HTRANS_IDLE);
    else
      mem_enable <= r.do_data_read(0);
    end if;
    mem_data_in(htrans_top downto htrans_bot) <= r.s2htrans;
    mem_data_in(hsize_top downto hsize_bot) <= r.s2hsize;
    mem_data_in(hwrite_idx) <= r.s2hwrite;
    mem_data_in(hburst_idx) <= r.s2hburst;
    mem_data_in(hmaster_top downto hmaster_bot) <= r.s2hmaster;
    mem_data_in(hmastlock_idx) <= r.s2hmastlock;
    mem_data_in(hresp_top downto hresp_bot) <= r.s2hresp;
    mem_data_in(haddr_top downto haddr_bot) <= r.s2haddr;
    mem_data_in(hdata_top downto hdata_bot) <= r.s2data;
    mem_data_in(timer_top downto timer_bot) <= r.s2timer;
    mem_data_in(breakpoint_hit_idx) <= r.s2breakpoint_hit;
    mem_data_in(watchpoint_hit_idx) <= r.s2watchpoint_hit;
  end process;

  --====================
  -- Registers
  --====================
  async_reset_g : if async_reset_c generate
    regs_p : process(clk, rstn)
    begin
      if rstn = '0' then
        r <= regs_reset_c;
      else
        if rising_edge(clk) then
          r <= rin;
        end if;
      end if;
    end process;
  end generate;

  sync_reset_g : if not async_reset_c generate
    regs_p : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if rstn = '0' then
          r <= regs_reset_c;
        end if;
      end if;
    end process;
  end generate;

  --====================
  -- Trace Buffer
  --====================
  trace_buf_g : for i in 0 to ram_width_c/ram_width_split_c - 1 generate
  begin
    syncram_i : syncram
      generic map (
        tech => memtech,
        abits => ram_depth_c,
        dbits => ram_width_split_c,
        pipeline => 1,
        testen => scantest,
        custombits => memtest_vlen)
      port map (
        clk => clk,
        address => mem_address,
        datain => mem_data_in((((i+1)*ram_width_split_c)-1) downto (i*ram_width_split_c)),
        dataout => mem_data_out((((i+1)*ram_width_split_c)-1) downto (i*ram_width_split_c)),
        enable => mem_enable,
        write => mem_write,
        testin => testin
      );
  end generate;
  trace_buf_rem_g : if (ram_width_c mod ram_width_split_c) > 0 generate
    syncram_i : syncram
      generic map (
        tech => memtech,
        abits => ram_depth_c,
        dbits => (ram_width_c mod ram_width_split_c),
        pipeline => 1,
        testen => scantest,
        custombits => memtest_vlen)
      port map (
        clk => clk,
        address => mem_address,
        datain => mem_data_in(ram_width_c-1 downto ram_width_c-(ram_width_c mod ram_width_split_c)),
        dataout => mem_data_out(ram_width_c-1 downto ram_width_c-(ram_width_c mod ram_width_split_c)),
        enable => mem_enable,
        write => mem_write,
        testin => testin
      );
  end generate;


end architecture;
