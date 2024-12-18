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
-- Entity:      mul64
-- File:        mul64.vhd
-- Author:      Andrea Merlo and Johan Klockars, Cobham Gaisler AB
-- Description: NOEL-V Multiplication Unit
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.multlib.all;
library gaisler;
use gaisler.utilnv.get_hi;

-----
-- arch0 -> generic mult
-- arch3 -> design_ware multiplier
----

entity mul64 is
  generic (
    fabtech   : integer range 0 to NTECH := 0;
    arch      : integer := 0;
    split     : integer := 1;
    scantest  : integer := 0
    );
  port (
    clk       : in  std_ulogic;
    rstn      : in  std_ulogic;
    holdn     : in  std_ulogic;
    ctrl      : in  std_logic_vector(2 downto 0);
    op1       : in  std_logic_vector;
    op2       : in  std_logic_vector;
    nready    : out std_ulogic;
    mresult   : out std_logic_vector;
    testen    : in  std_ulogic := '0';
    testrst   : in  std_ulogic := '1'
    );
end;

architecture rtl of mul64 is

  constant bits    : integer := op1'length;

  constant bottom  : unsigned(bits / 2 - 1 downto 0)    := (others => '0');
  constant top     : unsigned(bits - 1 downto bits / 2) := (others => '0');

  subtype op_1to1 is unsigned(bits - 1 downto 0);
  subtype op_3to2 is unsigned(bits * 3 / 2 - 1 downto 0);
  subtype op_2to1 is unsigned(bits * 2 - 1 downto 0);

  -- Constants ----------------------------------------------------
  constant RESET_ALL    : boolean := true;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  -- Signals ------------------------------------------------------
  type regtype is record
    ready       : std_ulogic;
    mresult     : std_logic_vector(129 downto 0);
    ctrl        : std_logic_vector(2 downto 0);
    mul0        : op_1to1;
    mul1        : op_1to1;
    mul2        : op_1to1;
    mul3        : op_1to1;
    negate      : std_ulogic;
  end record;

  constant RES : regtype := (
    ready       => '1',
    mresult     => (others => '0'),
    ctrl        => (others => '0'),
    mul0        => (others => '0'),
    mul1        => (others => '0'),
    mul2        => (others => '0'),
    mul3        => (others => '0'),
    negate      => '0'
    );

  signal r, rin  : regtype;
  signal mul_op1 : std_logic_vector(bits downto 0);
  signal mul_op2 : std_logic_vector(bits downto 0);
  signal prod    : std_logic_vector(2 * bits + 1 downto 0);
  signal vcc     : std_ulogic;

  signal arstn   : std_ulogic;

begin

  -- Misc
  arstn <= testrst when (ASYNC_RESET and scantest /= 0 and testen /= '0')
      else rstn    when ASYNC_RESET
      else '1';

  vcc   <= '1';

  comb : process (r, ctrl, op1, op2, prod)
    variable v          : regtype;
    variable sign1      : std_ulogic;
    variable sign2      : std_ulogic;
    variable result     : std_logic_vector(bits - 1 downto 0);
    variable v1         : op_1to1;
    variable v2         : op_1to1;
    variable adda_3to2  : op_3to2;
    variable addb_3to2  : op_3to2;
    variable proda_3to2 : op_3to2;
    variable prodb_3to2 : op_3to2;
    variable add_2to1   : op_2to1;
    variable prod_2to1  : op_2to1;
  begin
    v := r;

    -- Always Ready
    v.ready     := '1';
    v.mresult   := (others => '0');
    result      := (others => '0');
    sign1       := '1';
    sign2       := '1';

    -- Remember control (we need for the output mux)
    v.ctrl      := ctrl;

    v1 := unsigned(op1);
    v2 := unsigned(op2);

    v.negate     := '0';
    if ctrl = "011" then     -- MULHU
      sign1      := '0';
      sign2      := '0';
    elsif ctrl = "010" then  -- MULHSU
      sign2      := '0';
      if get_hi(v1) = '1' then
        v1       := (not v1) + 1;
        v.negate := '1';
      end if;
    elsif ctrl = "001" then  -- MULH
      if get_hi(v1) = '1' then
        v1       := (not v1) + 1;
        v.negate := not v.negate;
      end if;
      if get_hi(v2) = '1' then
        v2       := (not v2) + 1;
        v.negate := not v.negate;
      end if;
    elsif get_hi(v2) = '1' then
      v1        := (not v1) + 1;
      v2        := (not v2) + 1;
    end if;

    adda_3to2               := (others => '0');
    adda_3to2(r.mul0'range) := r.mul0;
    addb_3to2               := (others => '0');
    addb_3to2(r.mul2'range) := r.mul2;
    proda_3to2              := adda_3to2 + (r.mul1 & bottom);
    prodb_3to2              := addb_3to2 + (r.mul3 & bottom);
    add_2to1                := (others => '0');
    add_2to1(proda_3to2'range) := proda_3to2;
    prod_2to1               := add_2to1 + (prodb_3to2 & bottom);
    if r.negate = '1' then
      prod_2to1             := (not prod_2to1) + 1;
    end if;

    v.mul0 := v1(bottom'range) * v2(bottom'range);
    v.mul1 := v1(top'range)    * v2(bottom'range);
    v.mul2 := v1(bottom'range) * v2(top'range);
    v.mul3 := v1(top'range)    * v2(top'range);


    -- Select Higher or Lower part
    if split = 0 then
      case r.ctrl is
        when "000" =>   -- MUL
          result                := prod(bits - 1 downto 0);
        when "100" =>   -- MULW (does not exist for RV32)
          if bits = 64 then
            result              := (others => prod(31));
            result(31 downto 0) := prod(31 downto 0);
          end if;
        when others =>  -- MULH / MULHSU / MULHU (1 - 3)
          result                := prod(2 * bits - 1 downto bits);
      end case;
    else
      case r.ctrl is
        when "000" =>   -- MUL
          result                := std_logic_vector(prod_2to1(bits - 1 downto 0));
        when "100" =>   -- MULW (does not exist for RV32)
          if bits = 64 then
            result              := (others => prod_2to1(31));
            result(31 downto 0) := std_logic_vector(prod_2to1(31 downto 0));
          end if;
        when others =>  -- MULH / MULHSU / MULHU (1 - 3)
          result                := std_logic_vector(prod_2to1(2 * bits - 1 downto bits));
      end case;
    end if;

    rin         <= v;

    mul_op1  <= (op1(op1'left) and sign1) & op1;
    mul_op2  <= (op2(op2'left) and sign2) & op2;

    -- Drive Outputs
    nready  <= not r.ready;
    mresult <= result;

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
