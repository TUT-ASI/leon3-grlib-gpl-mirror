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
-- Entity:      sprw_opcodes
-- File:        sprw_opcodes.vhd
-- Author:      Marc Solé i Bonet, Barcelona Supercomputing Center
-- Description: List of opcodes for SPARROW operations
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package sprw_opcodes is
    ---------------------------------------------------------------
    -- CONSTANTS FOR OPERATIONS --
    --------------------------------------------------------------
    constant S1_NOP   : std_logic_vector(4 downto 0) := "00000"; -- Pass ra to second stage (no mask/swizzling)
    constant S1_ADD   : std_logic_vector(4 downto 0) := "00001"; -- Addition
    constant S1_SUB   : std_logic_vector(4 downto 0) := "00010"; -- Subtraction
    constant S1_MUL   : std_logic_vector(4 downto 0) := "00011"; -- Multiplication
    constant S1_SLRA  : std_logic_vector(4 downto 0) := "00100"; -- Shift Left/Right Arithmetic (signed)
    constant S1_MAX   : std_logic_vector(4 downto 0) := "00101"; -- Maximum
    constant S1_MIN   : std_logic_vector(4 downto 0) := "00110"; -- Minimum
    constant S1_MERG  : std_logic_vector(4 downto 0) := "00111"; -- Merge (pass rb)
    constant S1_AND   : std_logic_vector(4 downto 0) := "01000"; -- Logic AND
    constant S1_OR    : std_logic_vector(4 downto 0) := "01001"; -- Logic OR
    constant S1_XOR   : std_logic_vector(4 downto 0) := "01010"; -- Logic XOR
    constant S1_MMUL  : std_logic_vector(4 downto 0) := "01011"; -- Mixed (singed/unsigned) multiplication
    constant S1_LT    : std_logic_vector(4 downto 0) := "01100"; -- Less than
    constant S1_LE    : std_logic_vector(4 downto 0) := "01101"; -- Less than or equal
    constant S1_EQ    : std_logic_vector(4 downto 0) := "01110"; -- Equal
    constant S1_CLIP  : std_logic_vector(4 downto 0) := "01111"; -- Clip a WORD
    constant S1_UNOP  : std_logic_vector(4 downto 0) := "10000"; -- Pass unsigned ra to second stage (no mask/swizzling)
    constant S1_UADD  : std_logic_vector(4 downto 0) := "10001"; -- Unsigned Addition
    constant S1_USUB  : std_logic_vector(4 downto 0) := "10010"; -- Unsigned Subtraction
    constant S1_UMUL  : std_logic_vector(4 downto 0) := "10011"; -- Unsigned Multiplication
    constant S1_SLRL  : std_logic_vector(4 downto 0) := "10100"; -- Shift Left/Right Logic (unsigned)
    constant S1_UMAX  : std_logic_vector(4 downto 0) := "10101"; -- Unsigned Maximum
    constant S1_UMIN  : std_logic_vector(4 downto 0) := "10110"; -- Unsigned Minimum
    constant S1_UMERG : std_logic_vector(4 downto 0) := "10111"; -- Unsigned Merge (pass b)
    constant S1_NAND  : std_logic_vector(4 downto 0) := "11000"; -- Logic NAND
    constant S1_NOR   : std_logic_vector(4 downto 0) := "11001"; -- Logic NOR
    constant S1_XNOR  : std_logic_vector(4 downto 0) := "11010"; -- Logic XNOR
    constant S1_27    : std_logic_vector(4 downto 0) := "11011"; -- FREE
    constant S1_LTU   : std_logic_vector(4 downto 0) := "11100"; -- Unsigned less than
    constant S1_LEU   : std_logic_vector(4 downto 0) := "11101"; -- Unsigned less than or equal
    constant S1_30    : std_logic_vector(4 downto 0) := "11110"; -- FREE
    constant S1_UCLIP : std_logic_vector(4 downto 0) := "11111"; -- Clip an unsigned WORD

    constant S2_NOP : std_logic_vector (2 downto 0) := "000"; -- No Operation
    constant S2_SUM : std_logic_vector (2 downto 0) := "001"; -- Summation
    constant S2_MAX : std_logic_vector (2 downto 0) := "010"; -- Maximum
    constant S2_MIN : std_logic_vector (2 downto 0) := "011"; -- Minimum
    constant S2_SAT : std_logic_vector (2 downto 0) := "100"; -- Saturated no Operation
    constant S2_SSUM: std_logic_vector (2 downto 0) := "101"; -- Saturated Summation
    constant S2_XOR : std_logic_vector (2 downto 0) := "110"; -- XOR
    constant S2_2MSK: std_logic_vector (2 downto 0) := "111"; -- To Mask

end package;
