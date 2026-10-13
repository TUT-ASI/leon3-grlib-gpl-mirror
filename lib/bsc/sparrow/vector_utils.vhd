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
-- Entity:      vector_utils
-- File:        vector_utils.vhd
-- Author:      Marc Solé i Bonet, Barcelona Supercomputing Center
-- Modified by: Johan Klockars, Frongrade Gaisler AB
-- Description: Vector related types and functions
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;

package vector_utils is

    ---------------------------------------------------------------
    -- CONSTANTS --
    --------------------------------------------------------------
    constant SPRW_VLEN : integer := 64; -- Temporal until find how to set parameter
    constant VLEN : integer := SPRW_VLEN; -- Vector length
    constant DLEN : integer := 8; -- Data length
    constant WAYS : integer := VLEN/DLEN;     -- Number of ways (parallel computations)
    constant WBIT : integer := log2(WAYS);    -- Number of bits to represent WAYS

    constant UMAX : integer := 2 ** DLEN - 1;
    constant SMIN : integer := - 2 ** (DLEN - 1);
    constant SMAX : integer := 2 ** (DLEN - 1) - 1;

    constant DLENH : integer := 16;
    constant WAYSH : integer := VLEN / DLENH;
    constant UMAXH : integer := 2 ** DLENH - 1;
    constant SMINH : integer := -2 ** (DLENH - 1);
    constant SMAXH : integer := 2 ** (DLENH - 1) - 1;

    constant UMIN_v  : std_logic_vector := std_logic_vector(to_unsigned(0, DLEN));
    constant UMAX_v  : std_logic_vector := std_logic_vector(to_unsigned(UMAX, DLEN));
    constant SMIN_v  : std_logic_vector := std_logic_vector(to_signed(SMIN, DLEN));
    constant SMAX_v  : std_logic_vector := std_logic_vector(to_signed(SMAX, DLEN));
    constant UMINH_v : std_logic_vector := std_logic_vector(to_unsigned(0, DLENH));
    constant UMAXH_v : std_logic_vector := std_logic_vector(to_unsigned(UMAXH, DLENH));
    constant SMINH_v : std_logic_vector := std_logic_vector(to_signed(SMINH, DLENH));
    constant SMAXH_v : std_logic_vector := std_logic_vector(to_signed(SMAXH, DLENH));

    ---------------------------------------------------------------
    -- TYPES DEFINITION --
    --------------------------------------------------------------
    --vector register type
    subtype vector_component is std_logic_vector(DLEN-1 downto 0);
    type vector_reg_type is array (0 to WAYS-1) of vector_component;
    subtype vector_hcomponent is std_logic_vector(DLENH - 1 downto 0);
    type vector_hreg_type is array (0 to WAYSH - 1) of vector_hcomponent;
      
    --interstage vector register type (high precision);
    subtype high_prec_component is std_logic_vector(2*DLEN-1 downto 0);
    type inter_reg_type is array (0 to WAYS-1) of high_prec_component;
    subtype high_prec_hcomponent is std_logic_vector(2 * DLENH - 1 downto 0);
    type inter_hreg_type is array (0 to WAYSH - 1) of high_prec_hcomponent;

    subtype wordv is std_logic_vector(VLEN-1 downto 0);
    ---------------------------------------------------------------
    -- MULTIPLICATION UNIT IN/OUT --
    --------------------------------------------------------------
    type lpmul_in_type is record
        opA  : vector_component;
        opB  : vector_component;
        sign : std_logic;
        mix  : std_logic;
        sat  : std_logic;
--        sat  : std_logic_vector(1 downto 0);
    end record;

    type lpmul_out_type is record
        mul_res : high_prec_component;
    end record;

    ---------------------------------------------------------------
    -- MULTIPLICATION COMPONENT --
    --------------------------------------------------------------
    component lpmul is
    port(
            muli : in lpmul_in_type;
            mulo : out lpmul_out_type
        );
    end component;
    ---------------------------------------------------------------
    -- FUNCTIONS DEFINITION --
    --------------------------------------------------------------
    -- returns a wordv data as vector
    function to_vector(data : wordv) return vector_reg_type;
    -- returns a wordv data as intermediate vector
    function to_vector(data : wordv; sign : std_logic) return inter_reg_type;
    function to_vectorh(data : wordv) return vector_hreg_type;
    function to_vectorh(data : inter_reg_type) return inter_hreg_type;

    -- returns a vector vec as wordv
    function to_word(vec : vector_reg_type) return wordv;
    -- returns an intermediate vector vec as wordv
    function to_word(vec : inter_reg_type) return wordv;
    function to_word_hi(vec : inter_reg_type) return wordv;
    function to_word_q(vec : inter_reg_type) return wordv;
    function to_wordh(vec : inter_reg_type) return wordv;
    function to_wordh(vec : vector_hreg_type) return wordv;
    function to_wordh(vec : inter_hreg_type) return wordv;
    function to_wordh_hi(vec : inter_hreg_type) return wordv;
    function to_wordh_q(vec : inter_hreg_type) return wordv;

    -- returns the closer integer to value within max_val and min_val
    function clipping (value, max_val, min_val : integer) return integer;
    function signed_clipping (value, max_val, min_val : signed) return signed;
    function unsigned_clipping (value, max_val, min_val : unsigned) return unsigned;
    -- returns the value sign extended if set, to size length
    function extend(value : std_logic_vector; sign : std_logic; size : integer) return std_logic_vector;
    -- returns a saturated as signed if sat with length leng
    function signed_sat(a, leng : integer; sat : std_logic) return std_logic_vector;
    -- returns a saturated as unsigned if sat with length leng
    function unsigned_sat(a, leng : integer; sat : std_logic) return std_logic_vector;
    function signed_sat(a : std_logic_vector; sat : std_logic;
                        max_v : std_logic_vector; min_v : std_logic_vector) return std_logic_vector;
    function unsigned_sat(a : std_logic_vector; sat : std_logic;
                          max_v : std_logic_vector; min_v : std_logic_vector) return std_logic_vector;
    -- replicates a vector component in a vector
    function replicate(data : vector_component) return vector_reg_type;
    function replicate(data : vector_hcomponent) return vector_hreg_type;

end package;
package body vector_utils is
    ---------------------------------------------------------------
    -- FUNCTIONS
    --------------------------------------------------------------
    function to_vector(data : wordv) return vector_reg_type is
        variable vec : vector_reg_type;
    begin
        for i in vec'range loop
            vec(i) := data(DLEN*i+DLEN-1 downto DLEN*i);
        end loop;

        return vec;
    end;

    function to_vector(data : wordv; sign : std_logic) return inter_reg_type is
        variable vec : inter_reg_type;
    begin
        for i in vec'range loop
            vec(i) := extend(data(DLEN*i+DLEN-1 downto DLEN*i), sign, high_prec_component'length);
        end loop;

        return vec;
    end;

    function to_word(vec : vector_reg_type) return wordv is
        variable data : wordv;
    begin
        for i in vec'range loop
            data(DLEN*i+DLEN-1 downto DLEN*i) := vec(i);
        end loop;

        return data;
    end;

    function to_word(vec : inter_reg_type) return wordv is
        variable data : wordv;
    begin
        for i in vec'range loop
            data(DLEN*i+DLEN-1 downto DLEN*i) := vec(i)(vector_component'range);
        end loop;

        return data;
    end;

    function to_word_hi(vec : inter_reg_type) return wordv is
      -- Non-constant
      variable data : wordv;
    begin
      for i in vec'range loop
        data(DLEN * i + DLEN - 1 downto DLEN * i) := vec(i)(vec(0)'high downto vector_component'length);
      end loop;

      return data;
    end;

    function to_word_q(vec : inter_reg_type) return wordv is
      variable zero : vector_component := (others => '0');
      -- Non-constant
      variable data : wordv;
      variable v    : vector_component;
    begin
      for i in vec'range loop
        v := vec(i)(vec(0)'high - 1 downto vector_component'length - 1);
        if vec(i)(vec(0)'high) = '1' and v = zero then
          v := SMAX_v;
        end if;
        data(DLEN * i + DLEN - 1 downto DLEN * i) := v;
      end loop;

      return data;
    end;

    function to_vectorh(data : wordv) return vector_hreg_type is
      variable vec : vector_hreg_type;
    begin
      for i in vec'range loop
        vec(i) := data(DLENH * i + DLENH - 1 downto DLENH * i);
      end loop;

      return vec;
    end;

    function to_vectorh(data : inter_reg_type) return inter_hreg_type is
      variable vec : inter_hreg_type;
    begin
      for i in vec'range loop
        vec(i) := data(i * 2 + 1) & data(i * 2);
      end loop;

      return vec;
    end;

    function to_wordh(vec : inter_reg_type) return wordv is
      variable data : wordv;
    begin
      for i in 0 to WAYSH - 1 loop
        data(DLENH * i + DLENH - 1 downto DLENH * i) := vec(i * 2);
      end loop;

      return data;
    end;

    function to_wordh(vec : vector_hreg_type) return wordv is
      variable data : wordv;
    begin
      for i in vec'range loop
        data(DLENH * i + DLENH - 1 downto DLENH * i) := vec(i);
      end loop;

      return data;
    end;

    function to_wordh(vec : inter_hreg_type) return wordv is
      variable data : wordv;
    begin
      for i in vec'range loop
        data(DLENH * i + DLENH - 1 downto DLENH * i) := vec(i)(vector_hcomponent'range);
      end loop;

      return data;
    end;

    function to_wordh_hi(vec : inter_hreg_type) return wordv is
      variable data : wordv;
    begin
      for i in vec'range loop
        data(DLENH * i + DLENH - 1 downto DLENH * i) := vec(i)(vec(0)'high downto vector_hcomponent'length);
      end loop;

      return data;
    end;

    function to_wordh_q(vec : inter_hreg_type) return wordv is
      variable zero : vector_hcomponent := (others => '0');
      -- Non-constant
      variable data : wordv;
      variable v    : vector_hcomponent;
    begin
      for i in vec'range loop
        v := vec(i)(vec(0)'high - 1 downto vector_hcomponent'length - 1);
        if vec(i)(vec(0)'high) = '1' and v = zero then
          v := SMAXH_v;
        end if;
        data(DLENH * i + DLENH - 1 downto DLENH * i) := v;
      end loop;

      return data;
    end;

    ---------------------------------------------------------------
    -- SATURATION FUNCTIONS
    --------------------------------------------------------------
    function clipping (value, max_val, min_val : integer) return integer is
    begin
        if value > max_val then return max_val;
        elsif value < min_val then return min_val;
        else return value;
        end if;
    end;

    function signed_clipping (value, max_val, min_val : signed) return signed is
    begin
        if value > max_val then return max_val;
        elsif value < min_val then return min_val;
        else return value;
        end if;
    end;

    function unsigned_clipping (value, max_val, min_val : unsigned) return unsigned is
    begin
        if value > max_val then return max_val;
        elsif value < min_val then return min_val;
        else return value;
        end if;
    end;

    function extend(value : std_logic_vector; sign : std_logic; size : integer) return std_logic_vector is
    begin
        if sign = '1' then
            return std_logic_vector(resize(signed(value), size));
        else
            return std_logic_vector(resize(unsigned(value), size));
        end if;
    end;

    function signed_sat(a, leng : integer; sat : std_logic) return std_logic_vector is
    begin
        if sat = '1' then
          if leng = 32 then
            return  std_logic_vector(to_signed(clipping(a, SMAXH, SMINH), leng));
          else
            return  std_logic_vector(to_signed(clipping(a, SMAX, SMIN), leng));
          end if;
        else return std_logic_vector(to_signed(a, leng));
        end if;
    end;

    function unsigned_sat(a, leng : integer; sat : std_logic) return std_logic_vector is
    begin
        if sat = '1' then
          if leng = 32 then
            return std_logic_vector(to_unsigned(clipping(a, UMAXH, 0), leng));
          else
            return std_logic_vector(to_unsigned(clipping(a, UMAX, 0), leng));
          end if;
        else return std_logic_vector(to_signed(a, leng));
        end if;
    end;

    function signed_sat(a : std_logic_vector; sat : std_logic;
                        max_v : std_logic_vector; min_v : std_logic_vector) return std_logic_vector is
      variable ax : signed(a'length - 1 downto 0) := signed(a);
    begin
      if sat = '1' then
        return std_logic_vector(signed_clipping(ax,
                                                signed(extend(max_v, '1', ax'length)),
                                                signed(extend(min_v, '1', ax'length))
                                               ));
      else
        return std_logic_vector(ax);
      end if;
    end;

    function unsigned_sat(a : std_logic_vector; sat : std_logic;
                          max_v : std_logic_vector; min_v : std_logic_vector) return std_logic_vector is
      variable ax : unsigned(a'length - 1 downto 0) := unsigned(a);
    begin
      if sat = '1' then
        return std_logic_vector(unsigned_clipping(ax,
                                                  unsigned(extend(max_v, '0', ax'length)),
                                                  unsigned(extend(min_v, '0', ax'length))
                                                 ));
      else
        return std_logic_vector(ax);
      end if;
    end;

    function replicate(data : vector_component) return vector_reg_type is
        variable vec : vector_reg_type;
    begin
        vec := (others => data);
        return vec;
    end;

    function replicate(data : vector_hcomponent) return vector_hreg_type is
      variable vec : vector_hreg_type := (others => data);
    begin
      return vec;
    end;
end package body;
