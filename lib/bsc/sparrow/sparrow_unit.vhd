------------------------------------------------------------------------------
-- Copyright 2024, Barcelona Supercomputing Center
-- (Marc Solé i Bonet, Leonidas Kosmidis)
--
-- SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
--
-- Licensed under the Solderpad Hardware License v 2.1 (the “License”);
-- you may not use this file except in compliance with the License, or,
-- at your option, the Apache License version 2.0.
-- You may obtain a copy of the License at
--
-- https://solderpad.org/licenses/SHL-2.1/
--
-- Unless required by applicable law or agreed to in writing,
-- any work distributed under the License is distributed on
-- an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
-- either express or implied. See the License for the specific language
-- governing permissions and limitations under the License.
------------------------------------------------------------------------------
-- Entity:      sparrow_unit
-- File:        sparrow_unit.vhd
-- Author:      Marc Solé i Bonet, Barcelona Supercomputing Center
-- Modified by: Johan Klockars, Frongrade Gaisler AB
-- Description: SPARROW module pipeline
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.stdlib.all;

library bsc;
use bsc.sparrow.all;
use bsc.vector_utils.all;
use bsc.sprw_opcodes.all;

-- Note that sdi contains some things that arrive before the clock to EX,
-- and some things that are forwarded after the EX clock!

entity sparrow_unit is
    generic(
      addsub1 : boolean := true;
      minmax1 : boolean := true;
      cmp_en  : boolean := true;
      sh8_en  : boolean := true;
      e16_en  : boolean := true;
      sh16_en : boolean := true;
      idx_en  : boolean := true;
      hi_en   : boolean := true;
      fix_en  : boolean := true
    );
    port(
            clk   : in  std_ulogic;
            rstn  : in  std_ulogic;
            holdn : in  std_ulogic;
            sdi   : in  sprw_in_type;
            sdo   : out sprw_out_type
        );
end;

architecture rtl of sparrow_unit is
    ---------------------------------------------------------------
    -- REGISTER TYPES DEFINITION --
    --------------------------------------------------------------
    type lpmul_in_array is array (0 to WAYS-1) of lpmul_in_type;
    type lpmul_out_array is array (0 to WAYS-1) of lpmul_out_type;

    type l1_sum_array is array (0 to WAYS/2) of std_logic_vector(DLEN downto 0);
    type l2_sum_array is array (0 to WAYS/4) of std_logic_vector(DLEN+1 downto 0);

    -- Stage1 entry register
    type s1_reg_type is record
        ra   : vector_reg_type;
        rb   : vector_reg_type;
        opx  : std_logic;
        imm  : std_logic;
        op1  : std_logic_vector(4 downto 0);
        op2  : std_logic_vector(2 downto 0);
        ctrl : sprw_ctrl_reg_type;
        en   : std_logic;
    end record;

    -- Stage2 entry register
    type s2_reg_type is record
        ra   :  inter_reg_type;
        opx  : std_logic;
        op1  :  std_logic_vector(4 downto 0);
        op2  :  std_logic_vector(2 downto 0);
        sign : std_logic;
        e16  : std_logic;
        fix  : std_logic;
        en :  std_logic;
    end record;

    -- Stage3 entry register
    type s3_reg_type is record
        rc : wordv;
    end record;


    -- Group of pipeline registers
    type registers is record
        s1 : s1_reg_type;
        s2 : s2_reg_type;
        s3 : s3_reg_type;
    end record;

    ---------------------------------------------------------------
    -- CONSTANTS FOR PIPELINE REGISTERS RESET --
    --------------------------------------------------------------
    constant vector_reg_res : vector_reg_type := (others => (others => '0'));
    constant inter_reg_res : inter_reg_type := (others => (others => '0'));

    -- set the 1st stage registers reset
    constant s1_reg_res : s1_reg_type := (
        ra   => vector_reg_res,
        rb   => vector_reg_res,
        opx  => '0',
        imm  => '0',
        op1  => (others => '0'),
        op2  => (others => '0'),
        ctrl => sprw_ctrl_reg_none,
        en   => '0'
    );

    -- set the 2nd stage registers reset
    constant s2_reg_res : s2_reg_type := (
        ra   => inter_reg_res,
        opx  => '1',
        op1  => (others => '0'),
        op2  => (others => '0'),
        sign => '0',
        fix  => '0',
        e16  => '0',
        en   => '0'
    );

    -- set the 3rd stage registers reset
    constant s3_reg_res : s3_reg_type := (
        rc => (others => '0')
    );


    -- reset all registers
    constant RRES : registers := (
        s1 => s1_reg_res,
        s2 => s2_reg_res,
        s3 => s3_reg_res
    );

    ---------------------------------------------------------------
    -- SIGNALS DEFINITIONS
    --------------------------------------------------------------
    -- signals for the registers r -> current, rin -> next
    signal r, rin: registers;

    signal lpmuli : lpmul_in_array;
    signal lpmulo : lpmul_out_array;

    ---------------------------------------------------------------
    -- SWIZZLING FUNCTION --
    --------------------------------------------------------------
    function swizzling(data : vector_reg_type; sz : swizzling_reg_type) return vector_reg_type is
        variable result : vector_reg_type;
    begin
        for i in result'range loop
            result(i) := data(sz(i));
        end loop;
        return result;
    end;

    ---------------------------------------------------------------
    -- MASK FUNCTION --
    --------------------------------------------------------------
    procedure mask(vector, original : in inter_reg_type;
                   msk : in std_logic_vector(WAYS-1 downto 0);
                   pas_ra : in std_logic;
                   msk_res : out inter_reg_type) is
    begin
        if pas_ra = '1' then
            msk_res := original;
        else
            msk_res := (others => (others => '0'));
        end if;
        for i in msk'range loop
            if msk(i) = '1' then
                msk_res(i) := vector(i);
            end if;
        end loop;
    end;

    ---------------------------------------------------------------
    -- TWO OPERANDS OPERATIONS (S1) --
    --------------------------------------------------------------

    -- s1 result multiplexor and sign setter
    procedure s1_mux(op : in std_logic_vector(4 downto 0);
                     sel: out std_logic_vector(2 downto 0);
                     sign: out std_logic) is
    begin
        case op is
            when S1_AND | S1_OR | S1_XOR | S1_NAND | S1_NOR | S1_XNOR =>
                sel := "000";
                sign := '0';
            when S1_LT  | S1_LE | S1_EQ  | S1_LTU  | S1_LEU =>
                sel := "101";  -- Use min/max
                sign := not op(4);
            when others =>
              sel := op(2 downto 0);
              sign := not op(4);
        end case;
    end;

    procedure s1_select(sel: in std_logic_vector(2 downto 0);
                        rs2, add_res, sub_res, max_res, min_res, logic_res, shift_res, mul_res : in inter_reg_type;
                        s1_res : out inter_reg_type) is
    begin
        case sel is
            when "001" => s1_res := add_res;
            when "010" => if addsub1 then s1_res := add_res; else s1_res := sub_res; end if;
            when "011" => s1_res := mul_res;
            when "100" => s1_res := shift_res;
            when "101" => s1_res := max_res;
            when "110" => if minmax1 then s1_res := max_res; else s1_res := min_res; end if;
            when "111" => s1_res := rs2;
            when others => s1_res := logic_res;
        end case;
    end;

    function add(a, b : std_logic_vector;
                 sign, sat : std_logic) return std_logic_vector is
        variable z : integer;
    begin
        if sign = '1' then
            z := to_integer(signed(a)) + to_integer(signed(b));
            return signed_sat(z, 2 * a'length, sat);
        else
            z := to_integer(unsigned(a)) + to_integer(unsigned(b));
            return unsigned_sat(z, 2 * a'length, sat);
        end if;
    end;


    function sub(a, b : std_logic_vector;
                 sign, sat : std_logic) return std_logic_vector is
        variable z : integer;
    begin
        if sign = '1' then
            z := to_integer(signed(a)) - to_integer(signed(b));
            return signed_sat(z, 2 * a'length, sat);
        else
            z := to_integer(unsigned(a)) - to_integer(unsigned(b));
            return unsigned_sat(z, 2 * a'length, sat);
        end if;
    end;

 
    function addsub(a, b : std_logic_vector;
                    sub : boolean; sign, sat : std_logic) return std_logic_vector is
      -- Non-constant
      variable ax : signed(a'length downto 0) := signed((sign and a(a'left)) & a);
      variable bx : signed(b'length downto 0) := signed((sign and b(b'left)) & b);
      variable z  : integer;
    begin
      if sub then
        z := to_integer(ax) - to_integer(bx);
      else
        z := to_integer(ax) + to_integer(bx);
      end if;
      if sign = '1' then
        return signed_sat(z, 2 * a'length, sat);
      else
        return unsigned_sat(z, 2 * a'length, sat);
      end if;
    end;


    -- max function
    function max(a, b : std_logic_vector;
                 sign : std_logic) return std_logic_vector is
        variable z : std_logic_vector(a'range);
    begin
        if sign = '1' then
            if signed(a) > signed(b) then z := a;
            else z := b;
            end if;
        else
            if unsigned(a) > unsigned(b) then z := a;
            else z := b;
            end if;
        end if;

        return extend(z, sign, 2 * a'length);
    end;


    -- min function
    function min(a, b : std_logic_vector;
                 sign : std_logic) return std_logic_vector is
        variable z : std_logic_vector(a'range);
    begin
        if sign = '1' then
            if signed(a) > signed(b) then z := b;
            else z := a;
            end if;
        else
            if unsigned(a) > unsigned(b) then z := b;
            else z := a;
            end if;
        end if;

        return extend(z, sign, 2 * a'length);
    end;

    -- Min/max function
    function minmax(a, b : std_logic_vector;
                    do_max : boolean; sign : std_logic;
                    cmp_op : std_logic_vector(1 downto 0)) return std_logic_vector is
      -- Non-constant
      variable ai : integer := to_integer(signed((sign and a(a'left)) & a));
      variable bi : integer := to_integer(signed((sign and b(b'left)) & b));
      variable lt : boolean := ai < bi;
      variable eq : boolean := a = b;
      variable z  : std_logic_vector(a'range);
    begin
      if lt xor do_max then
        z := a;
      else
        z := b;
      end if;

      if cmp_en and cmp_op /= "11" then
        z := (others => '0');
        case cmp_op is
        when "00"   => if lt       then z := (others => '1'); end if;
        when "01"   => if lt or eq then z := (others => '1'); end if;
        when others => if eq       then z := (others => '1'); end if;
        end case;
      end if;

      return extend(z, sign, 2 * a'length);
    end;


    -- Logic operations
    function logic_op(a, b : std_logic_vector;
                      op : std_logic_vector(2 downto 0)) return std_logic_vector is
        variable z : std_logic_vector(a'range);
    begin
        case op is
            when "000" => z := a and b;
            when "001" => z := a or b;
            when "010" => z := a xor b;
            when "100" => z := a nand b;
            when "101" => z := a nor b;
            when "110" => z := a xnor b;
            when others => z := (others => '0');
        end case;

        return extend(z, '0', 2 * a'length);
    end;

    function shift(a, b : std_logic_vector; sign, sat : std_logic) return std_logic_vector is
        variable z : integer;
        variable i : integer;
        variable logic : std_logic;
        variable c : std_logic_vector(2 * a'length - 1 downto 0);
        variable cx : unsigned(3 * a'length - 1 downto 0);
    begin
        logic := not sign;
        i := to_integer(signed(b(b'left downto 0)));
        c := (a'range => (sign and a(a'left))) & a;
        if (i < 0) then
            -- Ensure that shift is as small as can be. (qqq Special case -8?)
            if i < -a'length then i := -a'length; end if;
            if logic = '0' then -- arithmetic
                cx := (others => c(c'high));
                cx(c'range) := unsigned(c);
                return std_logic_vector(shift_right(cx, -i)(c'range));
            else
                return std_logic_vector(shift_right(unsigned(c), -i));
            end if;
        else
            -- Ensure that shift is as small as can be. (qqq Special case 16?)
            if i > 2 * a'length then i := 2 * a'length; end if;
            -- Negative numbers must stay so when shifted left
            if logic = '0' then -- arithmetic
                z := to_integer(shift_left(signed(c), i));
            else
                z := to_integer(shift_left(unsigned(c), i));
            end if;
            if sign = '1' then -- signed
                return signed_sat(z, 2 * a'length, sat);
            else
                return unsigned_sat(z, 2 * a'length, sat);
            end if;
        end if;
    end;

    -- Works with words, a and b. Clips a to 0,b if unsigned and to -b,b if signed
    -- b is always unsigned
    function clip(a, b : wordv; sign : std_logic) return wordv is
        variable z, w : signed(wordv'length downto 0);
        variable zu, wu : unsigned(wordv'range);
        variable zero : unsigned(wordv'range) := (others => '0');
    begin
        if sign = '1' then
            z := signed(a(a'left)&a);
            w := signed('0'&b);
            return std_logic_vector(signed_clipping(z, w, -w)(wordv'range));
        else
            zu := unsigned(a);
            wu := unsigned(b);
            return std_logic_vector(unsigned_clipping(zu, wu, zero));
        end if;
    end;

    ---------------------------------------------------------------
    -- REDUCTION OPERATIONS (S2) --
    --------------------------------------------------------------
    procedure s2_select(sel : in std_logic_vector(2 downto 0);
                        ra, sum_res,
                        min_res, xor_res, msk_res : in wordv;
                        rc : out wordv) is
    begin
        case sel is
            when S2_NOP |
                 S2_SAT  => rc := ra;
            when S2_SUM |
                 S2_SSUM => rc := sum_res;
            when S2_MAX |
                 S2_MIN  => rc := min_res;
            when S2_XOR  => rc := xor_res;
            when S2_2MSK => rc := msk_res;
            when others  => rc := ra;
        end case;
    end;

    -- set ith bit to 1 if the ith compoenent is not zero
    function to_mask(a : inter_reg_type) return wordv is
        variable c : wordv := (others => '0');
    begin
        for i in 0 to WAYS-1 loop
            if a(i) /= (a(i)'range => '0') then
                c(i) := '1';
            end if;
        end loop;
        return c;
    end;

    function to_maskh(a : inter_hreg_type) return wordv is
      variable c : wordv := (others => '0');
    begin
      for i in 0 to WAYSH - 1 loop
        if a(i) /= (a(i)'range => '0') then
          c(i) := '1';
        end if;
      end loop;

      return c;
    end;

    function sum(a : inter_reg_type; sign, sat : std_logic) return wordv is
      variable acc : signed(a(0)'length + log2x(a'length) downto 0) := (others => '0');
      variable ax  : signed(acc'range);
      variable ret : std_logic_vector(acc'range);
    begin
      for i in 0 to WAYS - 1 loop
        ax  := signed(extend(a(i), sign, acc'length));
        acc := acc + ax;
      end loop;
      if sign = '1' then
        ret := signed_sat(std_logic_vector(acc), sat, SMAX_v, SMIN_v);
      else
        ret := unsigned_sat(std_logic_vector(acc), sat, UMAX_v, UMIN_v);
      end if;

      return extend(ret, sign, wordv'length);
    end;

    function sum(a : inter_hreg_type; sign, sat : std_logic) return wordv is
      variable acc : signed(a(0)'length + log2x(a'length) downto 0) := (others => '0');
      variable ax  : signed(acc'range);
      variable ret : std_logic_vector(acc'range);
    begin
      for i in 0 to WAYSH - 1 loop
        ax  := signed(extend(a(i), sign, acc'length));
        acc := acc + ax;
      end loop;
      if sign = '1' then
        ret := signed_sat(std_logic_vector(acc), sat, SMAXH_v, SMINH_v);
--        report "sum signed_sat " & tost(std_logic_vector(acc)) & " " & tost(sat) & " " & tost(SMINH_v);
      else
        ret := unsigned_sat(std_logic_vector(acc), sat, UMAXH_v, UMINH_v);
      end if;

      return extend(ret, sign, wordv'length);
    end;


    type int_arr is array (integer range <>) of integer;


    -- Min/max reduction function
    function xminmax_red(a : inter_reg_type; do_max, do_idx : boolean; sign : std_logic) return wordv is
      -- Non-constant
      variable accs : int_arr(WAYS - 1 downto 0);
      variable pos  : int_arr(WAYS / 2 - 1 downto 0);
    begin
--      report "Values";
      for i in 0 to WAYS - 1 loop
        accs(i) := to_integer(signed((sign and a(i)(a(0)'left)) & a(i)));
--        report tost(i) & ": " & tost(accs(i));
      end loop;
      for i in 0 to WAYS / 2 - 1 loop
--        report "first " & tost(i) & " " & tost(accs(i * 2)) & " vs " & tost(accs(i * 2 + 1));
        pos(i)     := 0;
        if (accs(i * 2) < accs(i * 2 + 1)) xor do_max then
          accs(i)  := accs(i * 2);
        else
          if accs(i * 2) /= accs(i * 2 + 1) then
            pos(i) := 1;
          end if;
          accs(i)  := accs(i * 2 + 1);
        end if;
--        report " -> " & tost(pos(i));
      end loop;
      for i in 0 to WAYS / 4 - 1 loop
--        report "second " & tost(i) & " " & tost(accs(i * 2)) & " vs " & tost(accs(i * 2 + 1));
        if (accs(i * 2) < accs(i * 2 + 1)) xor do_max then
          accs(i)  := accs(i * 2);
          pos(i)   := pos(i * 2);
        else
          pos(i)   := pos(i * 2 + 1);
          if accs(i * 2) /= accs(i * 2 + 1) then
            pos(i) := pos(i) + 2;
          end if;
          accs(i)  := accs(i * 2 + 1);
        end if;
--        report " -> " & tost(pos(i));
      end loop;
      for i in 0 to WAYS / 8 - 1 loop
--        report "third " & tost(i) & " " & tost(accs(i * 2)) & " vs " & tost(accs(i * 2 + 1));
        if (accs(i * 2) < accs(i * 2 + 1)) xor do_max then
          accs(i)  := accs(i * 2);
          pos(i)   := pos(i * 2);
        else
          pos(i)   := pos(i * 2 + 1);
          if accs(i * 2) /= accs(i * 2 + 1) then
            pos(i) := pos(i) + 4;
          end if;
          accs(i)  := accs(i * 2 + 1);
        end if;
--        report " -> " & tost(pos(i));
      end loop;

      if idx_en and do_idx then
        return unsigned_sat(pos(0), wordv'length, '0');
      else
        return unsigned_sat(accs(0), wordv'length, '0');
      end if;
    end;

    function xminmax_red(a : inter_hreg_type; do_max, do_idx : boolean; sign : std_logic) return wordv is
      -- Non-constant
      subtype acc_t is signed(a(0)'length downto 0);
      type acc_arr  is array (integer range <>) of acc_t;
      variable accs  : acc_arr(WAYSH - 1 downto 0) := (others => (others => '0'));
      variable pos  : int_arr(WAYSH / 2 - 1 downto 0);
    begin
      for i in 0 to WAYSH - 1 loop
        accs(i) := signed((sign and a(i)(a(0)'left)) & a(i));
      end loop;
      for i in 0 to WAYSH / 2 - 1 loop
        pos(i)     := 0;
        if (accs(i * 2) < accs(i * 2 + 1)) xor do_max then
          accs(i)  := accs(i * 2);
        else
          if accs(i * 2) /= accs(i * 2 + 1) then
            pos(i) := 1;
          end if;
          accs(i)  := accs(i * 2 + 1);
        end if;
      end loop;
      for i in 0 to WAYSH / 4 - 1 loop
        if (accs(i * 2) < accs(i * 2 + 1)) xor do_max then
          accs(i) := accs(i * 2);
          pos(i)  := pos(i * 2);
        else
          pos(i)  := pos(i * 2 + 1);
          if accs(i * 2) /= accs(i * 2 + 1) then
            pos(i) := pos(i) + 2;
          end if;
          accs(i) := accs(i * 2 + 1);
        end if;
      end loop;

      if idx_en and do_idx then
        return unsigned_sat(pos(0), wordv'length, '0');
      else
        return extend(std_logic_vector(accs(0)), sign, wordv'length);
      end if;
    end;

    function xxor_red(a : inter_reg_type) return wordv is
      -- Non-constant
      variable accs : inter_reg_type := a;
    begin
      for i in 0 to WAYS / 2 - 1 loop
        accs(i) := accs(i * 2) xor accs(i * 2 + 1);
      end loop;
      for i in 0 to WAYS / 4 - 1 loop
        accs(i) := accs(i * 2) xor accs(i * 2 + 1);
      end loop;
      for i in 0 to WAYS / 8 - 1 loop
        accs(i) := accs(i * 2) xor accs(i * 2 + 1);
      end loop;

      return std_logic_vector(resize(unsigned(accs(0)), wordv'length));
    end;

    function low_h(v_in : std_logic_vector) return std_logic_vector is
      variable v : std_logic_vector(v_in'length - 1 downto 0) := v_in;
    begin
      return v(v'length / 2 - 1 downto 0);
    end;

    function hi_h(v_in : std_logic_vector) return std_logic_vector is
      variable v : std_logic_vector(v_in'length - 1 downto 0) := v_in;
    begin
      return v(v'length - 1 downto v'length / 2);
    end;


begin
    ---------------------------------------------------------------
    -- MAIN BODY --
    --------------------------------------------------------------
    genmul : for i in 0 to VLEN/DLEN-1 generate
        mul : lpmul
            port map(lpmuli(i), lpmulo(i));
        end generate genmul;


    comb: process(r, sdi, lpmulo, holdn)
        variable v : registers;
        variable op1, op2 : vector_reg_type;
        variable rs1, rs2 : vector_reg_type;
        variable s1_res : inter_reg_type;
        variable s1_msk_res : inter_reg_type;
        variable rs1_res, rs2_res, clip_wrd, nop_res, add_res, sub_res, mul_res, max_res, min_res, logic_res, shift_res: inter_reg_type;
        variable s1_alusel : std_logic_vector(2 downto 0);
        variable log_mux : std_logic_vector(2 downto 0);
        variable s2_sum_res, s2_minmax_res, s2_xor_res, s2_msk_res: wordv;

        variable s1_sign, s1_sat, s2_sign, s2_sat : std_logic;
        variable s2_res : wordv;
        variable sdi_ctrl : sprw_ctrl_reg_type;
        variable r_s2_ra        : inter_hreg_type;
        variable rs1_16, rs2_16 : std_logic_vector(15 downto 0);
        variable res_16         : std_logic_vector(31 downto 0);
        variable res_33         : std_logic_vector(32 downto 0);
        variable cmp_op         : std_logic_vector(1 downto 0);
        variable do_max2        : boolean;
        variable do_idx2        : boolean;
        variable sel2           : std_logic_vector(2 downto 0);
        variable r_s2_ra_wordv  : wordv;
        variable wide_sat       : std_logic;
        variable do_hi          : boolean;
        variable r_s1_ctrl_mk   : mask_reg_type;
        variable sdi_rb         : vector_reg_type;
    begin
        v := r;

        sdi_ctrl := to_scr(sdi.ctrl);
        sdi_rb   := to_vector(sdi.rb);

        -- Clear out high byte of immediate if 16 bit
        if e16_en and r.s1.ctrl.e16 = '1' and r.s1.imm = '1' then
          for i in 0 to 3 loop
            sdi_rb(i * 2 + 1) := (others => sdi_rb(i * 2)(7));
          end loop;
        end if;

        -- S2 TO S3 --

        -- Sign type set
        s2_sign := r.s2.sign;
        -- Saturation type set
        s2_sat  := r.s2.op2(2);

        do_max2 := r.s2.op2 = S2_MAX;
        do_idx2 := false;
        if idx_en then
          do_max2 := r.s2.op2 = S2_MAX or r.s2.op2 = S2_XOR;
          do_idx2 := r.s2.op2 = S2_XOR or r.s2.op2 = S2_2MSK;
        end if;
        do_hi   := false;
        if hi_en then
          do_hi :=(r.s2.op1 = S1_MUL or r.s2.op1 = S1_MMUL or r.s2.op1 = S1_UMUL) and r.s2.op2 = S2_2MSK;
        end if;

        if hi_en and do_hi then
          if fix_en and r.s2.fix = '1' then
            r_s2_ra_wordv := to_word_q(r.s2.ra);
          else
            r_s2_ra_wordv := to_word_hi(r.s2.ra);
          end if;
        else
          r_s2_ra_wordv   := to_word(r.s2.ra);
        end if;
        s2_msk_res := to_mask(r.s2.ra);
        s2_sum_res := sum(r.s2.ra, s2_sign, s2_sat);
        s2_minmax_res := xminmax_red(r.s2.ra, do_max2, do_idx2, s2_sign);
        s2_xor_res := xxor_red(r.s2.ra);
        r_s2_ra := to_vectorh(r.s2.ra);
        if e16_en and r.s2.e16 = '1' then
          s2_msk_res := to_maskh(r_s2_ra);
          if hi_en and do_hi then
            if fix_en and r.s2.fix = '1' then
              r_s2_ra_wordv := to_wordh_q(r_s2_ra);
            else
              r_s2_ra_wordv := to_wordh_hi(r_s2_ra);
            end if;
          else
            r_s2_ra_wordv   := to_wordh(r_s2_ra);
          end if;
          s2_sum_res    := sum(r_s2_ra, s2_sign, s2_sat);
          s2_minmax_res := xminmax_red(r_s2_ra, do_max2, do_idx2, s2_sign);
        end if;

        sel2 := r.s2.op2;
        -- For s1 min/max, s2 xor/2msk are repurposed to report min/max index rather than value.
        if idx_en and (r.s2.op1 = S1_MAX or r.s2.op1 = S1_MIN) then
          if r.s2.op2 = S2_XOR then
            sel2 := S2_MAX;
          elsif r.s2.op2 = S2_2MSK then
            sel2 := S2_MIN;
          end if;
        end if;
        -- For s1 mul/mmul/umul, s2 2msk is repurposed to half/Q7/Q15 down shift.
        if hi_en and do_hi then
          sel2 := S2_NOP;
        end if;
        s2_select(sel2, r_s2_ra_wordv, s2_sum_res, s2_minmax_res, s2_xor_res, s2_msk_res, s2_res);
        -- NOP on meaningless operation
        -- qqq Better handled in IU, perhaps? Separate instruction for clip/uclip?
        if r.s2.op1 = S1_CLIP or r.s2.op1 = S1_UCLIP or
           (r.s2.op1 /= S1_XOR and sel2 = S2_XOR) then
          if e16_en and r.s2.e16 = '1' then
            s2_res := to_wordh(r_s2_ra);
          else
            s2_res := to_word(r.s2.ra);
          end if;
        end if;
        -- Dependency on .en and holdn
       if v.s2.en = '1' and holdn = '1' then
         v.s3.rc := s2_res;
       end if;


        -- S1 TO S2 --

        -- MUX BP from memory
        op1 := to_vector(sdi.ra);
        op2 := sdi_rb;

        --Swizzling
        rs1 := swizzling(op1, r.s1.ctrl.sa);
        rs2 := swizzling(op2, r.s1.ctrl.sb);

        -- MUX result from computing units
        -- Sign type set
        s1_mux(r.s1.op1, s1_alusel, s1_sign);


        -- Saturation type set
        s1_sat  := r.s1.op2(2);
        -- Logic MUX
        log_mux := r.s1.op1(4) & r.s1.op1(1 downto 0);

        -- To lpmul
        for i in vector_reg_type'range loop
            lpmuli(i).opA  <= rs1(i);
            lpmuli(i).opB  <= rs2(i);
            lpmuli(i).sign <= s1_sign;
            lpmuli(i).mix  <= r.s1.op1(3);
            lpmuli(i).sat  <= s1_sat;
--            lpmuli(i).sat <= wide_sat & s1_sat;
        end loop;

--        report "rs1 " & tost(rs1(0)) & tost(rs1(1)) & tost(rs1(2)) & tost(rs1(3)) & tost(rs1(4)) & tost(rs1(5)) & tost(rs1(6)) & tost(rs1(7));
        -- Get result of computing units
        cmp_op := "11";
        if cmp_en and (r.s1.op1 = S1_LT  or r.s1.op1 = S1_LE or r.s1.op1 = S1_EQ or
                       r.s1.op1 = S1_LTU or r.s1.op1 = S1_LEU) then
          cmp_op := r.s1.op1(1 downto 0);
        end if;
        for i in vector_reg_type'range loop
            if addsub1 then
              add_res(i) := addsub(rs1(i), rs2(i), r.s1.op1 = S1_SUB or r.s1.op1 = S1_USUB, s1_sign, s1_sat);
              sub_res(i) := (others => '0');
            else
              add_res(i) := add(rs1(i), rs2(i), s1_sign, s1_sat);
              sub_res(i) := sub(rs1(i), rs2(i), s1_sign, s1_sat);
            end if;
            mul_res(i) := lpmulo(i).mul_res;
            if minmax1 then
              max_res(i) := minmax(rs1(i), rs2(i), r.s1.op1 = S1_MAX or r.s1.op1 = S1_UMAX, s1_sign, cmp_op);
              min_res(i) := (others => '0');
            else
              max_res(i) := max(rs1(i), rs2(i), s1_sign);
              min_res(i) := min(rs1(i), rs2(i), s1_sign);
            end if;
            if sh8_en then
              shift_res(i) := shift(rs1(i), rs2(i), s1_sign, s1_sat);
            else
              shift_res(i) := (others => '0');
            end if;
            logic_res(i) := logic_op(rs1(i), rs2(i), log_mux);
            nop_res(i)   := extend(op1(i), s1_sign, high_prec_component'length);
            rs1_res(i)   := extend(rs1(i), s1_sign, high_prec_component'length);
            rs2_res(i)   := extend(rs2(i), s1_sign, high_prec_component'length);
        end loop;

        if e16_en and r.s1.ctrl.e16 = '1' then
          for i in vector_hreg_type'range loop
            -- Do not allow swizzling for 16 bit operations, to begin with.
            rs1_16               := op1(i * 2 + 1) & op1(i * 2);
            rs2_16               := op2(i * 2 + 1) & op2(i * 2);
            if addsub1 then
              res_16             := addsub(rs1_16, rs2_16, r.s1.op1 = S1_SUB or r.s1.op1 = S1_USUB, s1_sign, s1_sat);
            else
              res_16             := add(rs1_16, rs2_16, s1_sign, s1_sat);
            end if;
            add_res(i * 2)       := low_h(res_16);
            add_res(i * 2 + 1)   := hi_h(res_16);
--            report tost(i) & ": " & tost(rs1_16) & " - " & tost(rs2_16) & " = " & tost(res_16);
            if addsub1 then
              res_16             := (others => '0');
            else
              res_16             := sub(rs1_16, rs2_16, s1_sign, s1_sat);
            end if;
            sub_res(i * 2)       := low_h(res_16);
            sub_res(i * 2 + 1)   := hi_h(res_16);
            if r.s1.op1 = S1_UMUL then
              res_16             := std_logic_vector(unsigned(rs1_16) * unsigned(rs2_16));
            elsif r.s1.op1 = S1_MUL then
              res_16             := std_logic_vector(signed(rs1_16) * signed(rs2_16));
            else
              res_33             := std_logic_vector(signed('0' & rs1_16) * signed(rs2_16));
              res_16             := res_33(res_16'range);
--              report "mmul " & tost(to_integer(unsigned(rs1_16))) & " * " & tost(to_integer(signed(rs2_16))) & " -> " & tost(res_33);
            end if;
            mul_res(i * 2)       := low_h(res_16);
            mul_res(i * 2 + 1)   := hi_h(res_16);
            if minmax1 then
              res_16             := minmax(rs1_16, rs2_16, r.s1.op1 = S1_MAX or r.s1.op1 = S1_UMAX, s1_sign, cmp_op);
            else
              res_16             := max(rs1_16, rs2_16, s1_sign);
            end if;
            max_res(i * 2)       := low_h(res_16);
            max_res(i * 2 + 1)   := hi_h(res_16);
            if minmax1 then
              res_16             := (others => '0');
            else
              res_16             := min(rs1_16, rs2_16, s1_sign);
            end if;
            min_res(i * 2)       := low_h(res_16);
            min_res(i * 2 + 1)   := hi_h(res_16);
            if sh16_en then
              res_16             := shift(rs1_16, rs2_16, s1_sign, s1_sat);
            else
              res_16             := (others => '0');
            end if;
            shift_res(i * 2)     := low_h(res_16);
            shift_res(i * 2 + 1) := hi_h(res_16);
            -- No logic ops for 16 bit!
            logic_res(i * 2)     := (others => '0');
            logic_res(i * 2 + 1) := (others => '0');
            res_16               := extend(rs1_16, s1_sign, res_16'length);
            rs1_res(i * 2)       := low_h(res_16);
            rs1_res(i * 2 + 1)   := hi_h(res_16);
            nop_res              := rs1_res;
            res_16               := extend(rs2_16, s1_sign, res_16'length);
            rs2_res(i * 2)       := low_h(res_16);
            rs2_res(i * 2 + 1)   := hi_h(res_16);
          end loop;
        end if;

        clip_wrd := to_vector(clip(to_word(op1), to_word(op2), s1_sign), s1_sign);

        s1_select(s1_alusel, rs2_res, add_res, sub_res, max_res,
                  min_res, logic_res, shift_res, mul_res, s1_res);

--        report "s1_res " & tost(s1_res(0)) & tost(s1_res(1)) & tost(s1_res(2)) & tost(s1_res(3)) & tost(s1_res(4)) & tost(s1_res(5)) & tost(s1_res(6)) & tost(s1_res(7));
--        report "rs1_res " & tost(rs1_res(0)) & tost(rs1_res(1)) & tost(rs1_res(2)) & tost(rs1_res(3)) & tost(rs1_res(4)) & tost(rs1_res(5)) & tost(rs1_res(6)) & tost(rs1_res(7));

        r_s1_ctrl_mk := r.s1.ctrl.mk;
        if e16_en and r.s1.ctrl.e16 = '1' then
          r_s1_ctrl_mk := (others => '0');
          for i in WAYSH - 1 downto 0 loop
            if r.s1.ctrl.mk(i) = '1' then
              r_s1_ctrl_mk(i * 2 + 1 downto i * 2) := "11";
            end if;
          end loop;
        end if;
        mask(s1_res, rs1_res, r_s1_ctrl_mk, r.s1.ctrl.ms, s1_msk_res);
--        report "s1_msk_res " & tost_bits(r_s1_ctrl_mk) & " " & tost(s1_msk_res(0)) & " " & tost(s1_msk_res(1)) & " " & tost(s1_msk_res(2)) & " " & tost(s1_msk_res(3)) & " " & tost(s1_msk_res(4)) & " " & tost(s1_msk_res(5)) & " " & tost(s1_msk_res(6)) & " " & tost(s1_msk_res(7));

        -- Dependency on .en and holdn
       if r.s1.en = '1' and holdn = '1' then
        if (r.s1.op1 = S1_NOP) or (r.s1.op1 = S1_UNOP) then
            v.s2.ra := nop_res;
        elsif (r.s1.op1 = S1_CLIP) or (r.s1.op1 = S1_UCLIP) then
            v.s2.ra := clip_wrd;
        else
            v.s2.ra := s1_msk_res;
        end if;

        v.s2.opx := r.s1.opx;
        v.s2.op1 := r.s1.op1;
        v.s2.op2 := r.s1.op2;
        v.s2.sign := s1_sign;
        v.s2.e16 := r.s1.ctrl.e16;
        v.s2.fix := r.s1.ctrl.fix;
        v.s2.en := r.s1.en;
       end if;


        -- INPUT TO S1 --
        -- Only update when actual instruction
        if holdn = '1' then
          -- These are registered when the instruction reaches EX
          v.s1.en   := sdi.rc_we;
        end if;
        if v.s1.en = '1' and holdn = '1' then
          v.s1.opx  := sdi.opx;
          v.s1.imm  := sdi.imm;
          v.s1.op1  := sdi.op1;
          v.s1.op2  := sdi.op2;
          v.s1.ctrl := sdi_ctrl;
          v.s1.ra   := to_vector(sdi.ra);
          v.s1.rb   := sdi_rb;
        end if;


        -- S3 TO OUTPUT --
        sdo        <= sprw_out_none;

        if e16_en and r.s1.ctrl.e16 = '1' then
          sdo.s1bp <= to_wordh(v.s2.ra);
        else
          sdo.s1bp <= to_word(v.s2.ra);
        end if;
        sdo.s2bp   <= v.s3.rc;

        -- Outputs
        rin <= v;
    end process;

    ---------------------------------------------------------------
    -- DEBUG --
    --------------------------------------------------------------
-- pragma translate_off
--    dbg : process (clk)
--    begin
--        if falling_edge(clk) then
--        -- Debug S2
--            if (r.s2.en = '1') then
--                report " ---- STAGE 2 ---- ";
--                report "op: " & tost(r.s2.op2);
--                for i in vector_reg_type'range loop
--                    report "reg(" & tost(i) & "): " & tost(r.s2.ra(i));
--                end loop;
--                report "res: " & tost(rin.s3.rc);
--            end if;
--        -- Debug S1
--            if (r.s1.en = '1') then
--                report "";
--                report " New SPARROW instruction: ";
--                report " ---- STAGE 1 ---- ";
--                report "op: " & tost(r.s1.op1);
--                report "rs1: " & tost(to_word(r.s1.ra));
--                report "rs2: " & tost(to_word(r.s1.rb));
--                report "res: " & tost(to_word(rin.s2.ra));
--            end if;
--        end if;
--    end process;
-- pragma translate_on

    ---------------------------------------------------------------
    -- REGISTER UPDATING --
    --------------------------------------------------------------
    reg : process (clk)
    begin
        if rising_edge(clk) then
            r <= rin;
            if (rstn = '0') then
                r <= RRES;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------
    -- PRINT SPARROW VERSION --
    --------------------------------------------------------------
-- pragma translate_off
    x : process
    begin
        wait for 5 * 1 ns;
        print("sparrow: SPARROW SIMD module version " & sprw_version & ", precision: " & integer'image(DLEN) & "-bit, ways: " & integer'image(WAYS));
--        print("UMAX: " & integer'image(UMAX) & " SMAX: " & integer'image(SMAX) & " SMIN: " & integer'image(SMIN) & " BITS LOG: " & integer'image(WBIT));
        wait;
    end process;
-- pragma translate_on

end; 
