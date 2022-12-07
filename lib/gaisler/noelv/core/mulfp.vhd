------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity:      mulfp
-- File:        mulfp.vhd
-- Author:      Magnus Hjorth and Johan Klockars, Cobham Gaisler
-- Description: Configurable FPU mantissa multiplier for NOEL-V,
--              based on the one for LEON5.
------------------------------------------------------------------------------

-- Multiplier implementation for non-pipelined IEEE754-2008 FPU.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config.all;
use grlib.config_types.all;
use grlib.stdlib.tost;
use grlib.stdlib.tost_bits;
use grlib.stdlib.notx;
use grlib.stdlib.setx;
library gaisler;
use gaisler.fputilnv.all;
use gaisler.utilnv.log;
use gaisler.utilnv.all_0;
use gaisler.utilnv.to_bit;
use gaisler.nvsupport.word64;

entity mulfp is
  generic (
    -- Extensions
    fpulen    : integer range 0  to 128 := 64  -- Floating-point precision
  );
  port (
    clk           : in  std_ulogic;
    rstn          : in  std_ulogic;
    multiply      : in  std_ulogic;
    sqrt          : in  std_ulogic;
    rddp          : in  std_ulogic;
    src           : in  std_logic_vector(55 downto 0);
    mant          : out std_logic_vector(55 downto 0);
    bottom        : out std_logic_vector(51 downto 0);
    lo0           : out std_logic_vector(0 downto 0);
    done          : out std_ulogic
    -- Debug
    ; state_d     : out std_logic_vector(7 downto 0)
    ; data_d      : out std_logic_vector(56 * 2 - 2 - 1 downto 2 * 2)
  );
end;

architecture rtl of mulfp is

  constant no_muladd : integer := 0;

  constant FPUVER : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(5, 3));

  type nanofpu_state is (
                         nf_idle, nf_mulfast, nf_mul4, nf_mul5, nf_mul6, nf_mul7,
                         nf_sqrt3, nf_sqrt4, nf_sqrt5, nf_sqrt6,
                         nf_sqrt7, nf_sqrt8, nf_sqrt9, nf_sqrt10, nf_sqrt11
);

  signal dummy : float;

  type nanofpu_regs is record
    -- State
    s           : nanofpu_state;
    multiply    : std_ulogic;
    sqrt        : std_ulogic;
    res         : word64;
    op1         : float;
    op2         : float;
    carry       : std_ulogic;
    mulctr1     : unsigned(1 downto 0);
    mulctr2     : unsigned(1 downto 0);
    mulctrlim   : unsigned(1 downto 0);
    mulsel2     : std_ulogic;
    shftpl      : std_ulogic;
    shftpl2     : std_ulogic;
    sqrtctr     : unsigned(5 downto 0);
    -- 16x16 multiplier/accumulator pipeline
    muli1       : unsigned(15 downto 0);
    muli2       : unsigned(15 downto 0);
    mulo        : unsigned(31 downto 0);
    mulen       : std_ulogic;
    accen       : std_ulogic;
    accshft     : std_ulogic;
    mulres      : std_logic_vector(dummy.mant'length * 2 - 2 - 1 downto 2 * 2);
    acc         : unsigned(31 downto 0);
    acclo       : unsigned(27 downto 0);   -- Low multiplier bits for muladd
    acclo0      : unsigned(0 downto 0);
    accbot      : unsigned(51 downto 0);
    divcmp1     : std_ulogic;
    divcmp2     : std_ulogic;
    divrem128   : std_ulogic;
    divrem228   : std_ulogic;
  end record;

  constant RRES : nanofpu_regs := (
    s           => nf_idle,
    multiply    => '0',
    sqrt        => '0',
    res         => (others => '0'),
    op1         => float_none,
    op2         => float_none,
    carry       => '0',
    mulctr1     => "00",
    mulctr2     => "00",
    mulctrlim   => "00",
    mulsel2     => '0',
    shftpl      => '0',
    shftpl2     => '0',
    sqrtctr     => "000000",
    muli1       => (others => '0'),
    muli2       => (others => '0'),
    mulo        => (others => '0'),
    mulen       => '0',
    accen       => '0',
    accshft     => '0',
    mulres      => (others => '0'),
    acc         => (others => '0'),
    acclo       => (others => '0'),
    acclo0      => (others => '0'),
    accbot      => (others => '0'),
    divcmp1     => '0',
    divcmp2     => '0',
    divrem128   => '0',
    divrem228   => '0'
  );


  signal r, rin : nanofpu_regs;

begin

  comb : process(r, rstn, multiply, sqrt, rddp, src)
    variable v        : nanofpu_regs;
    variable vtmpadd  : unsigned(28 downto 0);
    variable vgrd     : std_ulogic;
    variable vop      : float;
    variable use_fs2  : boolean;
    variable n        : integer range 0 to 7;

    function tost(x : signed) return string is
    begin
      return tost(std_logic_vector(x));
    end;

    -- FPU Signals Generation

  begin
    v := r;

    -- Multiplier/accumulator pipeline
    -- Dealing with 14 bits at a time.
    if r.accen = '1' then
      if r.accshft = '1' then
        -- Shift down 14 bits
        if no_muladd = 0 then
          v.accbot            := r.acclo(13 downto 1) & r.acclo0 & v.accbot(v.accbot'high downto 14);
          v.acclo0            := r.acclo(14 downto 14);
        end if;
        v.acclo(13 downto 1)  := r.acclo(27 downto 15);
        vgrd                  := '0';
        for x in 0 to 14 loop
          vgrd                := vgrd or r.acclo(x);
        end loop;
        v.acclo(0)            := vgrd;
        v.acclo(27 downto 14) := r.acc(13 downto 0);
        v.acc(17 downto 0)    := r.acc(31 downto 14);
        v.acc(31 downto 18)   := (others => '0');
      end if;
      v.acc                   := v.acc + r.mulo;
    end if;

    if notx(std_logic_vector(r.muli1)) and notx(std_logic_vector(r.muli2)) then
      v.mulo := r.muli1 * r.muli2;
    else
      setx(v.mulo);
    end if;

    case r.mulctr1 is
      when "00"   => v.muli1 := unsigned'("00") & unsigned(r.op1.mant(12 downto 1)) & unsigned'("00");
      when "01"   => v.muli1 := unsigned'("00") & unsigned(r.op1.mant(26 downto 13));
      when "10"   => v.muli1 := unsigned'("00") & unsigned(r.op1.mant(40 downto 27));
      when others => v.muli1 := unsigned'("00") & unsigned(r.op1.mant(54 downto 41));
    end case;
    vop   := r.op2;
    if r.mulsel2 = '1' then
      vop := r.op1;
    end if;
    case r.mulctr2 is
      when "00"   => v.muli2 := unsigned'("00") & unsigned(vop.mant(12 downto 1)) & unsigned'("00");
      when "01"   => v.muli2 := unsigned'("00") & unsigned(vop.mant(26 downto 13));
      when "10"   => v.muli2 := unsigned'("00") & unsigned(vop.mant(40 downto 27));
      when others => v.muli2 := unsigned'("00") & unsigned(vop.mant(54 downto 41));
    end case;
    if r.mulsel2 = '1' and std_logic_vector(r.mulctr1) /= std_logic_vector(r.mulctr2) then
      v.muli2 := v.muli2(14 downto 0) & '0';
    end if;

    v.accen     := r.mulen;
    v.accshft   := r.shftpl;
    v.mulen     := '0';
    v.shftpl    := r.shftpl2;
    v.shftpl2   := '0';
    v.mulsel2   := '0';

    case r.s is
      when nf_idle =>
        v.acc         := (others => '0');
        v.acclo       := (others => '0');
        v.acclo0      := (others => '0');
        v.accbot      := (others => '0');
        v.shftpl      := '0';
        -- If sources are single precision we can skip ahead in the sequence.
        v.mulctrlim   := "00";
        if rddp = '0' then
          v.mulctrlim := "10";
        end if;
        v.mulctr1     := v.mulctrlim;
        v.mulctr2     := v.mulctrlim;
        if multiply = '0' and sqrt = '0' then
          v.op1.mant  := src;
        end if;
        if multiply = '1' then
          v.op2.mant  := src;
          v.multiply  := '1';
--          v.s         := nf_mul4;
          v.s         := nf_mulfast;
        elsif sqrt = '1' then
          v.sqrt      := '1';
          v.s         := nf_sqrt3;
          -- qqq Why are not mulctr1/2 set up somewhere?
          -- Start multiplier pipeline to get first 2 bits
          v.muli1             := (others => '0');
          v.muli1(1 downto 0) := "11";
          v.muli2             := v.muli1;
        end if;

      when nf_mulfast =>
        v.s         := nf_idle;

      -- dp lim 0
      --   01 02 103 210 3213 23 3
      --   00 10 120 123 1232 33 4
      -- sp lim 2
      --   213 23 3
      --   232 33 4
      when nf_mul4 =>
        -- Run multiplier pipeline
        v.mulctr1     := r.mulctr1 - 1;
        v.mulctr2     := r.mulctr2 + 1;
        v.mulen       := '1';
        v.shftpl2     := '0';
        if r.mulctr1 = r.mulctrlim or r.mulctr2 = "11" then
          if r.mulctr2 = "11" then
            v.mulctr1 := "11";
            v.mulctr2 := r.mulctr1 + 1;
          else
            v.mulctr1 := r.mulctr2 + 1;
            v.mulctr2 := r.mulctrlim;
          end if;
          v.shftpl2   := '1';
          if r.mulctr1 = "11" then
            v.s       := nf_mul5;
            v.shftpl2 := '0';
          end if;
        end if;

      when nf_mul5 =>
        -- Finish multiplier pipeline
        v.mulen                    := '0';
        v.shftpl2                  := '0';
        if r.accen = '0' then
          v.s := nf_idle;
        end if;


      when nf_sqrt3 => 
        v.op2.mant               := src;
        v.s                      := nf_sqrt4;
        -- Continue multiplier pipeline
        v.muli1                  := r.muli1;
        v.muli1(1 downto 0)      := "10";
        v.muli2                  := v.muli1;
        -- Init op1.mant here just to avoid triggering the check in nf_sqrt7 too early.
        v.op1.mant(55 downto 42) := std_logic_vector(r.muli1(13 downto 0));

      when nf_sqrt4 =>
        -- Move top 32 bits of mantissa over to accumulator
        v.res(31 downto 0)    := r.op2.mant(55 downto 24);
        -- Check for bits "11"
        if r.mulo(3 downto 0) <= unsigned(r.op2.mant(55 downto 52)) then
          v.muli1             := r.muli1(13 downto 2) & "1111";
          v.res               := v.res(59 downto 0) & "0011";
          v.s                 := nf_sqrt7;
        else
          v.muli1             := r.muli1;
          v.muli1(1 downto 0) := "01";
          v.s                 := nf_sqrt5;
        end if;
        v.muli2               := v.muli1;

      when nf_sqrt5 =>
        -- Check for bits "10"
        v.muli1   := r.muli1;
        if r.mulo <= unsigned(r.res(59 downto 28)) then
          v.muli1 := r.muli1(13 downto 2) & "1011";
          v.res   := r.res(59 downto 0) & "0010";
          v.s     := nf_sqrt7;
        else
          v.s     := nf_sqrt6;
        end if;
        v.muli2   := v.muli1;

      when nf_sqrt6 =>
        -- Check for bits "01" or "00"
        v.muli1      := r.muli1(13 downto 2) & "0011";
        v.res        := r.res(59 downto 0) & "0000";
        if r.mulo <= unsigned(r.res(59 downto 28)) then
          v.muli1(2) := '1';
          v.res(0)   := '1';
        end if;
        v.muli2      := v.muli1;
        v.s          := nf_sqrt7;

      when nf_sqrt7 =>
        -- Continue multiplier pipeline
        v.muli1                    := r.muli1;
        v.muli1(1 downto 0)        := "10";
        v.muli2                    := v.muli1;
        v.s                        := nf_sqrt8;
        if r.op1.mant(55 downto 54) /= "00" then
          v.op1.mant(40 downto 39) := std_logic_vector(r.muli1(3 downto 2));
          v.s                      := nf_sqrt9;
          v.op1.mant(38)           := '1';
          v.sqrtctr                := to_unsigned(38, 6);
          v.res(38)                := '1';
          v.res(37 downto 0)       := (others => '0');
          v.mulctrlim              := "10";
          v.mulctr2                := v.mulctrlim;
          v.mulctr1                := v.mulctrlim;
        end if;
        v.mulsel2                  := '1';

      when nf_sqrt8 =>
        v.op1.mant(54 downto 39) := std_logic_vector(r.muli1(15 downto 0));
        v.op1.mant(38 downto 0)  := (others => '0');
        -- Continue multiplier pipeline
        v.muli1                  := r.muli1;
        v.muli1(1 downto 0)      := "01";
        v.muli2                  := r.muli1;
        -- Check for bits "11"
        if r.mulo <= unsigned(r.res(59 downto 28)) then
          v.muli1                := r.muli1(13 downto 2) & "1111";
          v.res                  := r.res(59 downto 0) & "0011";
          v.s                    := nf_sqrt7;
        else
          v.s                    := nf_sqrt5;
        end if;
        v.muli2                  := v.muli1;

      -- Since we are squaring numbers,
      -- "reverse" multiplications are unnecessary.
      -- Coming from nf_sqrt7    lim 2
      --   23 3 3
      --   22 3 3
      -- Coming from nf_sqrt11
      --   if r.sqrtctr > 27     lim 2
      --     23 3 3
      --     22 3 3
      --   elsif r.sqrtctr > 13  lim 1
      --     12 3 23 3 3
      --     11 1 22 3 3
      --   else                  lim 0
      --    01 2 13 23 23 3 3
      --    00 0 10 11 22 3 3
      when nf_sqrt9 =>
        -- Slower algorithm to find lower bits by testing one by one
        v.mulen       := '1';
        -- Run multiplier pipeline
        v.mulctr1     := r.mulctr1 - 1;
        v.mulctr2     := r.mulctr2 + 1;
        v.mulen       := '1';
        v.shftpl2     := '0';
        if r.mulctr1 = "00" and r.mulctr2 = "00" then
          v.mulctr1   := "01";
          v.mulctr2   := "00";
          v.shftpl2   := '1';
        elsif r.mulctr1 = "01" and r.mulctr2 = "00" then
          v.mulctr1   := "10";
          v.mulctr2   := "00";
          v.shftpl2   := '1';
        elsif r.mulctr1 = "01" and r.mulctr2 = "01" then
          if r.mulctrlim = "00" then
            v.mulctr1 := "11";
            v.mulctr2 := "00";
          else
            v.mulctr1 := "10";
            v.mulctr2 := "01";
          end if;
          v.shftpl2   := '1';
        elsif r.mulctr1 = "10" and r.mulctr2 = "01" then
          v.mulctr1   := "11";
          v.mulctr2   := "01";
          v.shftpl2   := '1';
        elsif r.mulctr1 = "10" and r.mulctr2 = "10" then
          v.mulctr1   := "11";
          v.mulctr2   := "10";
          v.shftpl2   := '1';
        elsif r.mulctr1 = "11" and r.mulctr2 = "10" then
          v.mulctr1   := "11";
          v.mulctr2   := "11";
          v.shftpl2   := '1';
        elsif r.mulctr1 = "11" and r.mulctr2 = "11" then
          v.mulctr1   := "11";
          v.mulctr2   := "11";
          v.s         := nf_sqrt10;
        end if;
        v.mulsel2     := '1';

      when nf_sqrt10 =>
        -- Finish multiplier pipeline (mirror of nf_mul5)
        v.mulen       := '0';
        v.shftpl2     := '0';
        if r.accen = '0' then
          assert r.acc(29 downto 28) = "00";
          -- Subtract input from mul result
          vtmpadd     := unsigned('0' & r.acclo) -
                         unsigned('0' & r.op2.mant(27 downto 0));
          v.divrem228 := vtmpadd(28);
          -- Exact match for low bits?
          v.divcmp2   := '0';
          if all_0(vtmpadd) then
            v.divcmp2 := '1';
          end if;
          vtmpadd     := unsigned('0' & r.acc(27 downto 0)) -
                         unsigned('0' & r.op2.mant(55 downto 28));
          v.divrem128 := vtmpadd(28);
          -- Exact match for high bits?
          v.divcmp1   := '0';
          if all_0(vtmpadd) then
            v.divcmp1 := '1';
          end if;
          v.s         := nf_sqrt11;
        end if;
        v.mulsel2     := '1';

      when nf_sqrt11 =>
        v.acc              := (others => '0');
        v.acclo            := (others => '0');
        v.acclo0           := (others => '0');
        v.accbot           := (others => '0');
        v.res(38 downto 0) := '0' & r.res(38 downto 1);
        if r.divcmp1 = '1' and r.divcmp2 = '1' then
          -- Exact match!
          v.sqrt           := '0';
          v.op2.mant       := r.op1.mant;
          v.s              := nf_idle;
        elsif r.res(0) = '1' or (rddp = '0' and r.res(29) = '1') then
          -- Remainder below mantissa > 0
          v.sqrt           := '0';
          v.op2.mant       := r.op1.mant;
          v.op2.mant(0)    := '1';
          v.s              := nf_idle;
        else
          if r.divrem128 = '0' and (r.divcmp1 = '0' or r.divrem228 = '0') then
            -- Mul result > input - tested bit should be 0
            v.op1.mant(38 downto 0) := r.op1.mant(38 downto 0) and not r.res(38 downto 0);
          end if;
          v.op1.mant(38 downto 0)   := v.op1.mant(38 downto 0) or v.res(38 downto 0);
          v.op1.mant(0)             := '0';
          if rddp = '0' then
            v.op1.mant(29)          := '0';
          end if;
          v.sqrtctr                 := r.sqrtctr - 1;
          v.s                       := nf_sqrt9;
          if r.sqrtctr > 27 then
            v.mulctrlim := "10";
          elsif r.sqrtctr > 13 then
            v.mulctrlim := "01";
          else
            v.mulctrlim := "00";
          end if;
          v.mulctr1     := v.mulctrlim;
          v.mulctr2     := v.mulctrlim;
          v.mulsel2     := '1';
        end if;

      when others => null;
    end case;

    if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)    = 0 and
       GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 0 then
      if rstn = '0' then
        v.s := RRES.s;
      end if;
    end if;

    -- Signal assignments
    rin <= v;

    -- Copy result into output
    -- Leading one could be in either bit 27 or 26 of accumulator.
    assert r.acc(29 downto 28) = "00";
    if r.sqrt = '1' and v.s = nf_idle then
      mant   <= v.op2.mant;
      bottom <= (others => '0');
      lo0    <= "0";
      done   <= '1';
    else
--      mant   <= std_logic_vector(r.acc(27 downto 0) & r.acclo);
--      bottom <= std_logic_vector(r.accbot);
--      lo0    <= std_logic_vector(r.acclo0);
--        mulres & "00" /= std_logic_vector(r.acc(27 downto 0) & r.acclo(r.acclo'high downto 1) & r.acclo0 & r.accbot)
      mant   <= r.mulres(r.mulres'high downto v.accbot'high + 4) & '0';
      bottom <= r.mulres(v.accbot'high + 2 downto 4) & "00";
      lo0    <= r.mulres(v.accbot'high + 3 downto v.accbot'high + 3);
      done   <= to_bit((r.s = nf_mul5 or r.s = nf_mulfast) and r.accen = '0');
    end if;

    data_d   <= r.mulres;
    state_d  <= std_logic_vector(to_unsigned(nanofpu_state'pos(v.s), state_d'length));
  end process;

  srstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 0 generate
    regs : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        --if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rstn = '0' then
        if rstn = '0' then
          r <= RRES;
        end if;
      end if;
    end process;
  end generate srstregs;

  arstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) /= 0 generate
    regs: process(clk, rstn)
    begin
      if rstn = '0' then
        r <= RRES;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;
  end generate arstregs;

end;
