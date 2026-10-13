--------------------------------------------------------------------------------
--  COPM design
--  Copyright (C) 2025 Frontgrade Gaisler AB
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
--------------------------------------------------------------------------------
-- Entity:      ahbendconvm
-- File:        ahbendconvm.vhd
-- Author:      Frontgrade Gaisler
-- Description: AHB (AHB-Lite) endianness conversion bridge for a 32-bit data
--              bus, MASTER-side variant of ahbendconvs. Insert it between a
--              real AHB master and the bus arbiter. The behaviour is selected by
--              the 'mode' generic (identical semantics to the slave version):
--
--                mode=0  Pass-through. No endianness change.
--
--                mode=1  Data/word-invariant. A size-dependent byte-lane
--                        permutation on HWDATA/HRDATA, address unchanged:
--                          WORD  : reverse all 4 bytes
--                          HWORD : swap the two bytes in each halfword
--                          BYTE  : no change
--                        A word round-trip is transparent, but sub-word
--                        accesses observe the reordered bytes. One register
--                        aligns HSIZE to the data phase; no wait states.
--
--                mode=2  Byte/address-invariant (BE-8). Two combinatorial
--                        transforms applied together:
--                          1. Data    : UNCONDITIONAL full 32-bit byte
--                                       reversal {b0,b1,b2,b3}->{b3,b2,b1,b0}.
--                          2. Address : HADDR[1:0] := HADDR[1:0] xor m,
--                                       m = (4 - size_in_bytes):
--                                       BYTE->"11", HWORD->"10", WORD->"00".
--                        Mirroring the offset keeps every byte at the address
--                        the master expects, so the round trip is transparent
--                        for byte, halfword and word accesses alike while the
--                        data is physically transferred byte-reversed. Purely
--                        combinatorial: no registers, no wait states.
--
--              Topology: master-side record wrapper. Insert in the master path:
--                  master  -- ahbmo -->  [conv]  -- ahbmo_out -->  bus (msto)
--                  master <-- ahbmi --   [conv]  <-- ahbmi_in  --   bus (msti)
--
--              Only the data-bearing signals are touched: HWDATA on the way out,
--              HRDATA on the way in, and (mode 2 only) HADDR[1:0] on the way out.
--              Arbitration/control (HBUSREQ, HLOCK, HTRANS, HBURST, HPROT,
--              HGRANT, HREADY, HRESP, ...) pass through unmodified.
--
--              Data-phase alignment (mode 1): the address phase advances when
--              the bus asserts HREADY, so HSIZE is sampled on ahbmi_in.hready
--              (the bus-side ready), NOT a slave-side ready.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;

entity ahbendconvm is
  generic (
    -- Conversion mode:
    --   0 = pass-through          : no endianness change at all
    --   1 = data/word-invariant   : size-dependent byte swap, address kept
    --                               (word round-trip transparent; sub-word
    --                                accesses see the reordered bytes)
    --   2 = byte/address-invariant: unconditional byte reversal + low-address
    --                               mirror (transparent for every size; data
    --                               physically transferred byte-reversed)
    mode : integer range 0 to 2 := 2);
  port (
    rstn        : in  std_ulogic;           -- async reset, active low (mode 1)
    clk         : in  std_ulogic;           -- AHB clock (mode 1)
    -- Master-facing side (connects to the real master)
    ahbmi       : out ahb_mst_in_type;      -- master input, towards the master
    ahbmo       : in  ahb_mst_out_type;     -- master output, from the master
    -- Bus-facing side (connects to the arbiter, e.g. msti/msto(hindex))
    ahbmi_in    : in  ahb_mst_in_type;      -- master input, from the bus
    ahbmo_out   : out ahb_mst_out_type      -- master output, towards the bus
  );
end ahbendconvm;

architecture rtl of ahbendconvm is

  ------------------------------------------------------------------------------
  -- Functions (shared semantics with the slave-side ahbendconvs)
  ------------------------------------------------------------------------------

  -- Size-dependent byte-lane permutation (mode 1, data/word-invariant). The
  -- permutation is involutive and serves both directions and both data paths.
  function endian_swap (
    data  : std_logic_vector(AHBDW-1 downto 0);
    hsize : std_logic_vector(2 downto 0))
    return std_logic_vector is
    variable lo  : std_logic_vector(31 downto 0);
    variable ret : std_logic_vector(AHBDW-1 downto 0);
  begin
    ret := data;
    lo  := data(31 downto 0);
    case hsize is
      when HSIZE_WORD =>                     -- 32-bit: reverse all 4 bytes
        ret(31 downto 0) :=
          lo( 7 downto  0) & lo(15 downto  8) &
          lo(23 downto 16) & lo(31 downto 24);
      when HSIZE_HWORD =>                    -- 16-bit: swap bytes within each hw
        ret(31 downto 0) :=
          lo(23 downto 16) & lo(31 downto 24) &
          lo( 7 downto  0) & lo(15 downto  8);
      when others =>                         -- byte (and other): no change
        ret(31 downto 0) := lo;
    end case;
    return ret;
  end function endian_swap;

  -- Unconditional full 32-bit byte reversal (mode 2, byte/address-invariant).
  function byte_reverse (
    data : std_logic_vector(AHBDW-1 downto 0))
    return std_logic_vector is
    variable lo  : std_logic_vector(31 downto 0);
    variable ret : std_logic_vector(AHBDW-1 downto 0);
  begin
    ret := data;
    lo  := data(31 downto 0);
    ret(31 downto 0) :=
      lo( 7 downto  0) & lo(15 downto  8) &
      lo(23 downto 16) & lo(31 downto 24);
    return ret;
  end function byte_reverse;

  -- Byte-offset correction for a 4-byte bus: HADDR[1:0] xor (4 - size_in_bytes)
  -- so the low address bits track the reversed byte lanes.
  function addr_xor (
    hsize : std_logic_vector(2 downto 0))
    return std_logic_vector is
  begin
    case hsize is
      when HSIZE_BYTE  => return "11";       -- 1 byte  -> xor 3
      when HSIZE_HWORD => return "10";       -- 2 bytes -> xor 2
      when others      => return "00";       -- word (and wider): no correction
    end case;
  end function addr_xor;

begin

  ------------------------------------------------------------------------------
  -- Mode 0: pass-through. No endianness change (rstn/clk unused).
  ------------------------------------------------------------------------------
  passthru_gen : if mode = 0 generate
    ahbmo_out <= ahbmo;
    ahbmi     <= ahbmi_in;
  end generate;

  ------------------------------------------------------------------------------
  -- Mode 1: data/word-invariant. Size-dependent byte swap on HWDATA/HRDATA;
  -- the address is left untouched. A single register holds the address-phase
  -- HSIZE so the swap aligns with the data phase. The address phase advances
  -- with the BUS ready (ahbmi_in.hready). Adds NO wait states.
  ------------------------------------------------------------------------------
  datainv_gen : if mode = 1 generate
    signal hsize_dp, hsize_dp_in : std_logic_vector(2 downto 0);
  begin
    comb : process(hsize_dp, rstn, ahbmo, ahbmi_in)
      variable v : std_logic_vector(2 downto 0);
    begin
      v := hsize_dp;
      if ahbmi_in.hready = '1' then
        v := ahbmo.hsize;
      end if;

      ahbmo_out        <= ahbmo;
      ahbmo_out.hwdata <= endian_swap(ahbmo.hwdata, hsize_dp);

      ahbmi        <= ahbmi_in;
      ahbmi.hrdata <= endian_swap(ahbmi_in.hrdata, hsize_dp);

      if rstn = '0' then
        v := HSIZE_WORD;
      end if;
      hsize_dp_in <= v;
    end process;

    regs : process(clk)
    begin
      if rising_edge(clk) then
        hsize_dp <= hsize_dp_in;
      end if;
    end process;
  end generate;

  ------------------------------------------------------------------------------
  -- Mode 2: byte/address-invariant. Unconditional byte reversal plus low
  -- address-bit mirroring. Purely combinatorial (rstn/clk unused).
  ------------------------------------------------------------------------------
  byteinv_gen : if mode = 2 generate
    comb : process(ahbmo, ahbmi_in)
    begin
      -- Bus-side master output: byte-reverse the write data and mirror the
      -- byte offset so sub-word writes land in the physically reversed lanes.
      ahbmo_out                   <= ahbmo;
      ahbmo_out.haddr(1 downto 0) <= ahbmo.haddr(1 downto 0) xor addr_xor(ahbmo.hsize);
      ahbmo_out.hwdata            <= byte_reverse(ahbmo.hwdata);

      -- Master-side master input: byte-reverse the read data.
      ahbmi        <= ahbmi_in;
      ahbmi.hrdata <= byte_reverse(ahbmi_in.hrdata);
    end process;
  end generate;

end rtl;

