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
-- Entity:      axis_buffer
-- File:        axis_buffer.vhd
-- Author:      Carl Ehrenstrahle - Frontgrade Gaisler AB
-- Description: AXI-Stream Skid Buffer
-- Provides full decoupling of master and slave ports via registers.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;

entity axis_buffer is
  generic (
    wl : positive := 1
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    s_axis_tdata : in std_logic_vector(wl - 1 downto 0);
    s_axis_tvalid : in std_logic;
    s_axis_tready : out std_logic;

    m_axis_tdata : out std_logic_vector(wl - 1 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in std_logic
  );
end entity;

architecture rtl of axis_buffer is
  constant ASYNC_RESET : boolean :=
    GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  type reg_t is record
    out_dv : std_logic;
    out_data : std_logic_vector(wl - 1 downto 0);
    out_rdy : std_logic;
    buf_dv : std_logic;
    buf_data : std_logic_vector(wl - 1 downto 0);
  end record;

  constant reg_reset_c : reg_t := (
    out_dv => '0',
    out_data => (others => '0'),
    out_rdy => '0',
    buf_dv => '0',
    buf_data => (others => '0')
  );

  signal r, rin : reg_t;
begin
  --------------------
  -- Combinatorial
  --------------------
  comb_p : process(r, m_axis_tready, s_axis_tdata, s_axis_tvalid)
    variable v : reg_t;
  begin
    v := r; -- Copy current state.

    -- Only allow new samples if buffer is empty.
    -- Ready must update independently of pipeline movement.
    v.out_rdy := (m_axis_tready or not r.out_dv) and not r.buf_dv;

    -- Fill buffer if the output is not available.
    if m_axis_tready = '0' and r.out_rdy = '1' and r.out_dv = '1' then
      v.buf_dv := s_axis_tvalid;
      v.buf_data := s_axis_tdata;
    end if;

    -- Standard pipeline movement.
    if m_axis_tready = '1' or r.out_dv = '0' then
      v.out_dv := r.buf_dv or (s_axis_tvalid and r.out_rdy);

      -- Always use buffer if data is available.
      -- This works since the upstream ready is deasserted.
      if r.buf_dv = '1' then
        v.out_data := r.buf_data;
        -- Invalidate buffer
        v.buf_dv := '0';
      elsif r.out_rdy = '1' then
        v.out_data := s_axis_tdata;
      end if;
    end if;

    rin <= v; -- Commit next state.

    -- Output --
    m_axis_tdata <= r.out_data;
    m_axis_tvalid <= r.out_dv;
    s_axis_tready <= r.out_rdy;
  end process;

  --------------------
  -- Clocked process
  --------------------
  syncregs : if not ASYNC_RESET generate
    regs_p : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if rst = '0' then
          r <= reg_reset_c;
        end if;
      end if;
    end process;
  end generate;

  asyncregs : if ASYNC_RESET generate
    regs_p : process(rst, clk)
    begin
      if rst = '0' then
        r <= reg_reset_c;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;
  end generate;
end architecture;
