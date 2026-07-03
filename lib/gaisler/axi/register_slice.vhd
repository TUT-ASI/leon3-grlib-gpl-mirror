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
-- Entity:      register_slice
-- File:        register_slice.vhd
-- Author:      Martin Caous George - Frontgrade Gaisler AB
-- Description: Stream register slice for AXI memory mapped or stream.
--              Cuts handshake timing between subordinate and manager interface.
--              Can be implemented with either registered input or output
--              for the data.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;

entity register_slice is
  generic (
    dwidth      : integer;
    direction   : integer range 0 to 1 := 0;  -- 0: Registered output, 1: Registered input
    reset_data  : integer range 0 to 1 := 0;  -- 0: Only reset handshake signals, 1: Reset handshake and xdata
    bypass      : integer range 0 to 1 := 0
  );
  port (
    clk       : in  std_ulogic;
    rstn      : in  std_ulogic;

    s_xdata   : in  std_logic_vector(dwidth-1 downto 0);
    s_xvalid  : in  std_ulogic;
    s_xready  : out std_ulogic;

    m_xdata   : out std_logic_vector(dwidth-1 downto 0);
    m_xvalid  : out std_ulogic;
    m_xready  : in  std_ulogic
  );
end;

architecture rtl of register_slice is

  constant ASYNC_RST  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant RESET_ALL  : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

  type reg_type is record
    xdata       : std_logic_vector(dwidth-1 downto 0);
    xdata_spill : std_logic_vector(dwidth-1 downto 0);
    xvalid      : std_ulogic;
    xready      : std_ulogic;
  end record;

  constant RST : reg_type := (
    xdata       => (others => '0'),
    xdata_spill => (others => '0'),
    xvalid      => '0',
    xready      => '1'
  );

  signal r, rin : reg_type;

begin

  p_comb : process(r, rstn, s_xdata, s_xvalid, m_xready)
    variable v : reg_type;
  begin
    v := r;

    if direction = 0 then
      -- Registered output

      -- Fill spill register if downstream port is not ready
      if s_xvalid = '1' and r.xready = '1' and r.xvalid = '1' and m_xready = '0' then
        v.xready := '0';
      elsif m_xready = '1' then
        v.xready := '1';
      end if;

      if r.xready = '1' then
        v.xdata_spill := s_xdata;
      end if;

      -- Fill manager port data if empty or downstream port is ready
      if r.xvalid = '0' or m_xready = '1' then
        v.xvalid  := s_xvalid or not r.xready;
        if r.xready = '0' then
          -- Use spill register if filled
          v.xdata := r.xdata_spill;
        else
          -- Use data from the subordinate port
          v.xdata := s_xdata;
        end if;
      end if;
    else
      -- Registered input

      -- Main register
      if (s_xvalid = '1' or r.xvalid = '1') and r.xready = '1' then
        v.xvalid := s_xvalid and r.xready;
      end if;

      if s_xvalid = '1' and r.xready = '1' then
        v.xdata := s_xdata;
      end if;

      -- Spill register
      if (r.xvalid = '1' and r.xready = '1' and m_xready = '0') or
         (r.xready = '0' and m_xready = '1') then
        v.xready := not (r.xvalid and r.xready and not m_xready);
      end if;

      if r.xready = '1' and m_xready = '0' then
        v.xdata_spill := r.xdata;
      end if;
    end if;

    if not ASYNC_RST and rstn = '0' then
      if RESET_ALL then
        v := RST;
      else
        if reset_data /= 0 then
          v.xdata := RST.xdata;
        end if;
        v.xready := RST.xready;
        v.xvalid := RST.xvalid;
      end if;
    end if;

    rin <= v;

    if bypass = 0 then
      if direction = 0 then
        s_xready  <= r.xready;
        m_xdata   <= r.xdata;
        m_xvalid  <= r.xvalid;
      else
        s_xready  <= r.xready;
        if r.xready = '1' then
          m_xdata   <= r.xdata;
        else
          m_xdata   <= r.xdata_spill;
        end if;
        m_xvalid  <= r.xvalid or not r.xready;
      end if;
    else
      s_xready  <= m_xready;
      m_xdata   <= s_xdata;
      m_xvalid  <= s_xvalid;
    end if;
  end process;

  p_reg : process(clk, rstn)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
    if ASYNC_RST and rstn = '0' then
      if RESET_ALL then
        r <= RST;
      else
        if reset_data /= 0 then
          r.xdata <= RST.xdata;
        end if;
        r.xready <= RST.xready;
        r.xvalid <= RST.xvalid;
      end if;
    end if;
  end process;

end;
