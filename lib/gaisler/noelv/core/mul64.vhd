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
-- Entity:      mul64
-- File:        mul64.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
-- Description: NOEL-V Multiplication Unit
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.multlib.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.noelvint.all;
library techmap;
use techmap.gencomp.all;

-----
--arch0 -> generic mult
--arch3 -> design_ware multiplier
----

entity mul64 is
  generic (
    fabtech   : integer range 0 to NTECH := 0;
    arch      : integer := 0;
    scantest  : integer := 0
    );
  port (
    clk       : in  std_ulogic;       
    rstn      : in  std_ulogic;
    holdn     : in  std_ulogic;
    muli      : in  mul_in_type;
    mulo      : out mul_out_type;
    testen    : in  std_ulogic := '0';
    testrst   : in  std_ulogic := '1'
    );
end;

architecture rtl of mul64 is

  constant bits : integer := muli.op1'length;

  -- Constants ----------------------------------------------------
  --constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant RESET_ALL    : boolean := true;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  -- Signals ------------------------------------------------------
  type regtype is record
    ready       : std_ulogic;
    mresult     : std_logic_vector(129 downto 0);
    ctrl        : std_logic_vector(2 downto 0);
  end record;

  constant RES : regtype := (
    ready       => '1',
    mresult     => (others => '0'),
    ctrl        => (others => '0')
    );

  signal r, rin           : regtype;
  signal mul_op1, mul_op2 : std_logic_vector(bits downto 0);
  signal prod             : std_logic_vector(2 * bits + 1 downto 0);
  signal vcc              : std_ulogic;

  signal arstn            : std_ulogic;

begin

  -- Misc
  arstn <= testrst when (ASYNC_RESET and scantest /= 0 and testen /= '0')
      else rstn    when ASYNC_RESET
      else '1';

  vcc   <= '1';

  comb : process (r, muli, prod)
    variable v      : regtype;
    variable sign1  : std_ulogic;
    variable sign2  : std_ulogic;
    variable result : std_logic_vector(bits - 1 downto 0);
  begin
    v := r;

    -- Always Ready
    v.ready     := '1';
    v.mresult   := (others => '0');
    result      := (others => '0');
    sign1       := '1';
    sign2       := '1';

    -- Latch control (we need for the output mux)
    v.ctrl      := muli.ctrl;

    if muli.ctrl = "011" then
      sign1     := '0';
      sign2     := '0';
    elsif muli.ctrl = "010" then
      sign2     := '0';
    end if;

    --if muli.flush = '0' then
    --  v.mresult   := std_logic_vector(signed((muli.op1(63) and sign1) & muli.op1) * signed((muli.op2(63) and sign2) & muli.op2));
    --end if;

    -- Select Higher or Lower part
    case r.ctrl is
      when "000" =>
        result := prod(bits - 1 downto 0);
      when "001" | "010" | "011" =>
        result := prod(2 * bits - 1 downto bits);
      when "100" =>
        -- This is mulw, which does not exist for RV32.
        if bits = 64 then
          result(bits - 1 downto bits - 32) := (others => prod(31));
          result(31 downto 0)               := prod(31 downto 0);
        end if;
      when others =>
    end case;

    rin         <= v;

    mul_op1     <= (muli.op1(bits - 1) and sign1) & muli.op1;
    mul_op2     <= (muli.op2(bits - 1) and sign2) & muli.op2;
    -- Drive Outputs
    mulo.nready <= not r.ready;
    mulo.result <= result;
    mulo.icc    <= (others => '0');

  end process;


  m0: techmult generic map (fabtech, arch, bits + 1, bits + 1, 2, 1)
    port map(mul_op1, mul_op2, clk, holdn, vcc, prod);

  syncrregs : if not ASYNC_RESET generate
    regs : process(clk)
    begin
      if rising_edge(clk) then
        if holdn = '1' then
          r <= rin;
        end if;
        if rstn = '0' then
          r <= RES;
        end if;
      end if;
    end process;
  end generate;

  asyncrregs : if ASYNC_RESET generate
    regs : process(clk, arstn)
    begin
      if arstn = '0' then
        r <= RES;
      elsif rising_edge(clk) then
        if holdn = '1' then
          r <= rin;
        end if;
      end if;
    end process;
  end generate;

end;
