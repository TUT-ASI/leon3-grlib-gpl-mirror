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
-- Entity:      ahbendconvs
-- File:        ahbendconvs.vhd
-- Author:      Frontgrade Gaisler
-- Description: AHB (AHB-Lite) endianness conversion bridge for a 32-bit data
--              bus. The behaviour is selected by the 'mode' generic:
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
--                        data is physically stored byte-reversed. Purely
--                        combinatorial: no registers, no wait states.
--
--              Topology: slave-side record wrapper. Insert in the slave path:
--                  master  -- ahbsi -->  [conv]  -- ahbsi_out -->  slave
--                  master <-- ahbso --   [conv]  <-- ahbso_in  --  slave
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- pragma translate_off
use std.textio.all;
-- pragma translate_on
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;

entity ahbendconvs is
  generic (
    -- Conversion mode:
    --   0 = pass-through          : no endianness change at all
    --   1 = data/word-invariant   : size-dependent byte swap, address kept
    --                               (word round-trip transparent; sub-word
    --                                accesses see the reordered bytes)
    --   2 = byte/address-invariant: unconditional byte reversal + low-address
    --                               mirror (transparent for every size; data
    --                               physically stored byte-reversed)
    mode : integer range 0 to 2 := 2);
  port (
    rstn        : in  std_ulogic;           -- async reset, active low (mode 1)
    clk         : in  std_ulogic;           -- AHB clock (mode 1)
    -- Upstream (master-facing) bus
    ahbsi       : in  ahb_slv_in_type;      -- slave input from the master side
    ahbso       : out ahb_slv_out_type;     -- slave output to the master side
    -- Downstream (slave-facing) bus
    ahbso_in    : in  ahb_slv_out_type;     -- slave output from the real slave
    ahbsi_out   : out ahb_slv_in_type       -- slave input to the real slave
  );
end ahbendconvs;

architecture rtl of ahbendconvs is

  ------------------------------------------------------------------------------
  -- Functions
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
      when HSIZE_HWORD =>                    -- 16-bit: swap bytes in each half
        ret(31 downto 0) :=
          lo(23 downto 16) & lo(31 downto 24) &
          lo( 7 downto  0) & lo(15 downto  8);
      when others =>                         -- 8-bit (and unsupported): no swap
        ret(31 downto 0) := lo;
    end case;
    return ret;
  end function endian_swap;

  -- Unconditional full byte reversal of the low 32 bits (mode 2). Bits above
  -- 31 (only present if AHBDW > 32) are passed through unchanged: this
  -- converter supports a 32-bit data bus only. Size independent.
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
    ahbsi_out <= ahbsi;
    ahbso     <= ahbso_in;
  end generate;

  ------------------------------------------------------------------------------
  -- Mode 1: data/word-invariant. Size-dependent byte swap on HWDATA/HRDATA;
  -- the address is left untouched. A single register holds the address-phase
  -- HSIZE so the swap aligns with the data phase. Adds NO wait states.
  ------------------------------------------------------------------------------
  datainv_gen : if mode = 1 generate
    signal hsize_dp, hsize_dp_in : std_logic_vector(2 downto 0);
  begin
    comb : process(hsize_dp, rstn, ahbsi, ahbso_in)
      variable v : std_logic_vector(2 downto 0);
    begin
      v := hsize_dp;
      if ahbsi.hready = '1' then
        v := ahbsi.hsize;
      end if;

      ahbsi_out        <= ahbsi;
      ahbsi_out.hwdata <= endian_swap(ahbsi.hwdata, hsize_dp);

      ahbso        <= ahbso_in;
      ahbso.hrdata <= endian_swap(ahbso_in.hrdata, hsize_dp);

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
    comb : process(ahbsi, ahbso_in)
    begin
      -- Downstream slave input: byte-reverse the write data and mirror the
      -- byte offset so sub-word writes land in the physically reversed lanes.
      ahbsi_out                   <= ahbsi;
      ahbsi_out.haddr(1 downto 0) <= ahbsi.haddr(1 downto 0) xor addr_xor(ahbsi.hsize);
      ahbsi_out.hwdata            <= byte_reverse(ahbsi.hwdata);

      -- Upstream slave output: byte-reverse the read data.
      ahbso        <= ahbso_in;
      ahbso.hrdata <= byte_reverse(ahbso_in.hrdata);
    end process;
  end generate;

end rtl;

