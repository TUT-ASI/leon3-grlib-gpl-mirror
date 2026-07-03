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
-- Entity:      ahb_err_shim
-- File:        ahb_err_shim.vhd
-- Author:      Jonathan Jonsson, Frontgrade Gaisler AB
-- Description: Synthesizable Test IP to inject bus error responses.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;

entity ahb_err_shim is
  generic (
    hindex  : integer := 0;
    pindex  : integer := 0;
    paddr   : integer := 0;
    pmask   : integer := 16#fff#
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    -- APB Interface (Configuration)
    apbi    : in  apb_slv_in_type;
    apbo    : out apb_slv_out_type;
    -- AHB Interface (From Bus/Master)
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    -- Slave Interface (To the actual Slave device)
    s_ahbsi : out ahb_slv_in_type;
    s_ahbso : in  ahb_slv_out_type
  );
end entity;

architecture rtl of ahb_err_shim is

-- APB Register Layout
type regs_type is record
  addr_match : std_logic_vector(31 downto 0);
  addr_mask  : std_logic_vector(31 downto 0);
  en         : std_ulogic;
  rd_en      : std_ulogic;
  wr_en      : std_ulogic;
  hit        : std_ulogic;
end record;

-- AHB Error State Machine
type state_type is (IDLE, ERR1, ERR2);

type core_regs_type is record
  regs  : regs_type;
  state : state_type;
end record;

signal r, rin : core_regs_type;

-- PNP configuration
constant pconfig : apb_config_type := (
  0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_AHB_ERR_SHIM, 0, 0, 0),
  1 => apb_iobar(paddr, pmask)
);

begin

  comb : process(rst, r, apbi, ahbsi, s_ahbso)
    variable v        : core_regs_type;
    variable v_apbo   : apb_slv_out_type;
    variable v_ahbso  : ahb_slv_out_type;
    variable v_sahbsi : ahb_slv_in_type;
    variable addr_hit : std_ulogic;
    variable match    : std_ulogic;
  begin
    v := r;

    -- ---------------------------------------------------------
    -- APB Configuration Logic
    -- ---------------------------------------------------------
    v_apbo := (pirq => (others => '0'), pindex => hindex, pconfig => pconfig, prdata => (others => '0'));

    if (apbi.psel(pindex) and apbi.penable) = '1' then
      if apbi.pwrite = '1' then
        case apbi.paddr(3 downto 2) is
          when "00"   => v.regs.addr_match := apbi.pwdata;
          when "01"   => v.regs.addr_mask  := apbi.pwdata;
          when "10"   =>
            v.regs.en    := apbi.pwdata(0);
            v.regs.rd_en := apbi.pwdata(1);
            v.regs.wr_en := apbi.pwdata(2);
            v.regs.hit   := apbi.pwdata(3);
          when others => null;
        end case;
      else
        case apbi.paddr(3 downto 2) is
          when "00"   => v_apbo.prdata := r.regs.addr_match;
          when "01"   => v_apbo.prdata := r.regs.addr_mask;
          when "10"   =>
            v_apbo.prdata(0) := r.regs.en;
            v_apbo.prdata(1) := r.regs.rd_en;
            v_apbo.prdata(2) := r.regs.wr_en;
            v_apbo.prdata(3) := r.regs.hit;
          when others => null;
        end case;
      end if;
    end if;

    -- ---------------------------------------------------------
    -- AHB Interception Logic
    -- ---------------------------------------------------------
    -- Defaults: Pass-through
    v_ahbso  := s_ahbso;
    v_sahbsi := ahbsi;

    -- Address Comparison (using mask)
    addr_hit := '0';
    if ((ahbsi.haddr and not r.regs.addr_mask) = (r.regs.addr_match and not r.regs.addr_mask)) then
      addr_hit := '1';
    end if;

    -- Determine if we should intercept current transaction
    match := '0';
    if r.regs.en = '1' and ahbsi.hsel(hindex) = '1' and ahbsi.htrans /= HTRANS_IDLE and ahbsi.htrans /= HTRANS_BUSY then
      if (ahbsi.hwrite = '0' and r.regs.rd_en = '1') or (ahbsi.hwrite = '1' and r.regs.wr_en = '1') then
        if addr_hit = '1' then
          match      := '1';
          v.regs.hit := '1';
        end if;
      end if;
    end if;

    -- State Machine for Error Response
    case r.state is
      when IDLE =>
        if match = '1' then
          v.state := ERR1;
          -- Block the slave from seeing this transaction
          v_sahbsi.hsel := (others => '0');
        end if;

      when ERR1 =>
        -- Cycle 1 of Error: HREADY low, HRESP = ERROR
        v_ahbso.hready := '0';
        v_ahbso.hresp  := HRESP_ERROR;
        v_sahbsi.hsel  := (others => '0');
        v.state := ERR2;

      when ERR2 =>
        -- Cycle 2 of Error: HREADY high, HRESP = ERROR
        v_ahbso.hready := '1';
        v_ahbso.hresp  := HRESP_ERROR;
        v.state := IDLE;

      when others => v.state := IDLE;
    end case;

    -- ---------------------------------------------------------
    -- Signal Assignments
    -- ---------------------------------------------------------
    -- Always pass through interrupts
    v_ahbso.hirq := s_ahbso.hirq;

    if rst = '0' then
      v.state := IDLE;
      v.regs.en := '0';
    end if;

    rin     <= v;
    apbo    <= v_apbo;
    ahbso   <= v_ahbso;
    s_ahbsi <= v_sahbsi;

  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

end architecture;
