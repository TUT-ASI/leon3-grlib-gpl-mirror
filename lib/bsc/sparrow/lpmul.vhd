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
-- Entity:      lpmul
-- File:        lpmul.vhd
-- Author:      Marc Solé i Bonet, Barcelona Supercomputing Center
-- Description: SPARROW low-precision (8-bit) multiplier
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library bsc;
use bsc.vector_utils.all;

library grlib;
use grlib.stdlib.all;

entity lpmul is
    port(
            muli : in lpmul_in_type;
            mulo : out lpmul_out_type
        );
end;

architecture rtl of lpmul is

    function sign_invert(a : std_logic_vector) return std_logic_vector is
    begin
        return std_logic_vector(-signed(a));
    end;

    function product (a, b : vector_component) return high_prec_component is
        variable z : integer;
        variable aux: integer;
    begin
        z := 0; aux := to_integer(unsigned(a));
        for i in 0 to DLEN-1 loop
            if b(i) = '1' then
                z := aux + z;
            end if;
            aux := aux*2;
        end loop;

        return  std_logic_vector(to_unsigned(z,high_prec_component'length));
    end;

    function sat_mux (asign, bsign, rsign, sign, sat : std_logic;
    z2 : std_logic_vector) return std_logic_vector is
        variable sel : std_logic_vector(2 downto 0);
    begin
        sel := "000";                                           -- result as it is, no saturation
        if sat = '1' then
            if sign = '1' then
                if asign = bsign then                           -- result should be positive
                    if z2&rsign /= (z2'range => '0')&'0' then   -- overflow including sign bit
                        sel := "011";                           -- result is 7f signed max
                    end if;
                else                                            -- result should be negative
                    if z2&rsign /= (z2'range => '0')&'0' then   -- overflow
                        sel := "100";                           -- result is 80 signed min
                    else sel := "001";                          -- else result is 2s complement negative
                    end if;
                end if;
            else
                if z2 /= (z2'range => '0') then                 -- overflow
                    sel := "111";                               -- result is ff unsigned max
                end if;
            end if;
        elsif sign = '1' then                                   -- if no saturation but signed
            if asign /= bsign then                              -- and result should be negative
                sel := "001";                                   -- result is 2s complement negative
            end if;
        end if;

        return sel;
    end;

    procedure sat_sel (sel : in std_logic_vector(2 downto 0);
                       r, nr : in high_prec_component;
                       mulres : out high_prec_component) is
    begin
        case sel is
            when "000"  => mulres := r;
            when "001"  => mulres := nr;
            when "011"  => mulres := extend(SMAX_v, '1', mulres'length);
            when "100"  => mulres := extend(SMIN_v, '1', mulres'length);
            when "101"  => mulres := SMAXH_v;
            when "111"  => mulres := extend(UMAX_v, '0', mulres'length);
            when others => mulres := (others => '0');
        end case;
    end;

begin

    comb : process(muli)
        variable z : high_prec_component;
        variable r : high_prec_component;
        variable a, b : vector_component;
        variable signA, signB : std_logic;
        variable mux : std_logic_vector(2 downto 0);
    begin
        a := muli.opA; b := muli.opB;
        signA := (not muli.mix) and muli.opA(muli.opA'left);
        signB := muli.opB(muli.opB'left);

        -- have both operands as positive if signed and saturation
        if (muli.sign and signA) = '1' then
            a := sign_invert(muli.opA);
        end if;
        if (muli.sign and signB) = '1' then
            b := sign_invert(muli.opB);
        end if;
        -- low precision product
        z := product(a, b);
        -- select result with sign and saturation
        mux := sat_mux(signA, signB, z(vector_component'left), muli.sign, muli.sat, z(z'left downto vector_component'length));
        sat_sel(mux, z, sign_invert(z), r);
        mulo.mul_res <= r;
    end process;
end;
