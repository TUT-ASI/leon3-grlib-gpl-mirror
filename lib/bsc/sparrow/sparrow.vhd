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
-- Entity:      sparrow
-- File:        sparrow.vhd
-- Author:      Marc Solé i Bonet, Barcelona Supercomputing Center
-- Modified by: Johan Klockars, Frongrade Gaisler AB
-- Description: SPARROW interface package with utilities for integration with
--              the pipeline
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;

library bsc;
use bsc.vector_utils.all;
use bsc.sprw_opcodes.all;

package sparrow is

    ---------------------------------------------------------------
    -- CONSTANTS --
    --------------------------------------------------------------
    constant sprw_version : string := "2.0";
    constant SWZ_LENGTH : integer := WAYS * WBIT;
    constant SCR_BIT : integer := WAYS               -- MASK
                                  + 1                -- Mask selector
                                  + SWZ_LENGTH * 2;  -- Swizzling

    constant IBITS : integer := 5;  --Immediate bits



    ------------------------------------------------------------
    -- SPARROW CONTROL REGISTER --
    ------------------------------------------------------------
    -- mask registers (predicate)
    subtype mask_reg_type is std_logic_vector(WAYS-1 downto 0);

    -- swizzling registers (reordering)
    subtype log_length is integer range 0 to WAYS-1;
    type swizzling_reg_type is array (0 to WAYS-1) of log_length;

    subtype swizzling_data_a is std_logic_vector(SWZ_LENGTH + WAYS downto WAYS+1);
    subtype swizzling_data_b is std_logic_vector(SCR_BIT-1 downto SWZ_LENGTH + WAYS+1);

    type sprw_ctrl_reg_type is record
        e16 : std_logic;     -- 16 bit elements
        fix : std_logic;     -- Fixed point
        mk  : mask_reg_type;      -- mask value
        ms  : std_logic;          -- mask selection (ra or 0)
        sa  : swizzling_reg_type; -- swizzling ra
        sb  : swizzling_reg_type; -- swizzling rb
    end record;

    ------------------------------------------------------------
    -- SPARROW IN/OUT REGISTERS --
    ------------------------------------------------------------
    type sprw_in_type is record
        ra          : wordv;                          -- operand 1 data
        rb          : wordv;                          -- operand 2 data
        wb_valid    : std_logic;                      -- Instruction valid in WB
        rd_zero     : std_logic;                      -- No destination
        rs2_zero    : std_logic;                      -- No second source
        opx         : std_logic;                      -- Extra op bit on RISC-V.
        imm         : std_logic;                      -- Immediate value used
        op1         : std_logic_vector (4 downto 0);  -- operation code stage1
        op2         : std_logic_vector (2 downto 0);  -- operation code stage2
        rc_we       : std_logic;                      -- we on destination (work)
        ctrl        : wordv;                          -- special register to control the module behaviour
    end record;

    type sprw_out_type is record
        s1bp        : wordv; -- s1 bypass output data
        s2bp        : wordv; -- s2 bp output data
        ctrl        : wordv;
    end record;

    type sprw_in_vec  is array (0 to 1) of sprw_in_type;
    type sprw_out_vec  is array (0 to 1) of sprw_out_type;

    ---------------------------------------------------------------
    -- SPARROW MODULE --
    --------------------------------------------------------------
    component sparrow_unit is
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
    end component;


    ---------------------------------------------------------------
    -- FUNCTIONS DECLARATION --
    --------------------------------------------------------------
    function swizzling_init return swizzling_reg_type;
    function swizzling_set(sz_i : std_logic_vector(WAYS*WBIT-1 downto 0)) return swizzling_reg_type;
    function swizzling_get(sz : swizzling_reg_type) return std_logic_vector;
    function to_word(reg : sprw_ctrl_reg_type) return wordv;
    function to_scr(data : wordv) return sprw_ctrl_reg_type;
    function imm_sprw (s1, imm_bits : std_logic_vector(4 downto 0)) return wordv;

    ---------------------------------------------------------------
    -- CONSTANTS DECLARATION --
    --------------------------------------------------------------
    constant sprw_ctrl_reg_res : sprw_ctrl_reg_type;
    constant sprw_ctrl_reg_none : sprw_ctrl_reg_type;
    constant sprw_ctrl_reg_word_res : wordv;
    constant sprw_in_none   : sprw_in_type;
    constant sprw_out_none   : sprw_out_type;
      

end package;
package body sparrow is
    ---------------------------------------------------------------
    -- SCR FUNCTIONS --
    --------------------------------------------------------------
    function swizzling_init return swizzling_reg_type is
        variable res_val : swizzling_reg_type;
    begin
        for i in 0 to (VLEN/DLEN)-1 loop
            res_val(i) := i;
        end loop;

        return res_val;
    end;

    function swizzling_set(sz_i : std_logic_vector(WAYS*WBIT-1 downto 0)) return swizzling_reg_type is
        variable res_val : swizzling_reg_type;
    begin
        for i in 0 to (VLEN/DLEN)-1 loop
            res_val(i) := to_integer(unsigned(sz_i(i*WBIT+WBIT-1 downto i*WBIT)));
        end loop;

        return res_val;
    end;

    function swizzling_get(sz : swizzling_reg_type) return std_logic_vector is
        variable data : std_logic_vector(WAYS*WBIT-1 downto 0);
    begin
        for i in 0 to WAYS-1 loop
            data(WBIT*i+WBIT-1 downto WBIT*i) := std_logic_vector(to_unsigned(sz(i), WBIT));
        end loop;

        return data;
    end;

    function to_word(reg : sprw_ctrl_reg_type) return wordv is
    begin
        return reg.e16 & reg.fix & (wordv'left - 2 downto SCR_BIT => '0') & swizzling_get(reg.sb) & swizzling_get(reg.sa) & reg.ms & reg.mk;
    end;


    function to_scr(data : wordv) return sprw_ctrl_reg_type is
        variable reg : sprw_ctrl_reg_type;
    begin
        reg.e16 := data(data'high);
        reg.fix := data(data'high - 1);
        reg.mk  := data(mask_reg_type'range);
        reg.ms  := data(mask_reg_type'length);
        reg.sa  := swizzling_set(data(swizzling_data_a'range));
        reg.sb  := swizzling_set(data(swizzling_data_b'range));

        return reg;
    end;

    ---------------------------------------------------------------
    -- IMMEDIATE ENCODING --
    --------------------------------------------------------------
    function imm_sprw (s1, imm_bits : std_logic_vector(4 downto 0)) return wordv is
        variable imm : std_logic_vector(IBITS-1 downto 0);
        variable immediate_data : vector_component;
        variable rhzeros : integer range 0 to DLEN-1;
        variable ret : wordv;
    begin
        immediate_data := (others => '0');
        imm := imm_bits;
        ret := (others => '0');
        rhzeros := to_integer(unsigned(imm(IBITS-2 downto 1))); --number of right hand 0s, for pow2
        case s1 is
            when  S1_SLRA | S1_SLRL =>  -- [-16, 15]
                immediate_data := (DLEN-1 downto IBITS => imm(IBITS-1)) & imm(IBITS-1 downto 0);
                ret := to_word(replicate(immediate_data));
            when S1_AND | S1_OR | S1_XOR | S1_NAND | S1_NOR | S1_XNOR => -- [-16, 15]
                immediate_data := (DLEN-1 downto IBITS => imm(IBITS-1)) & imm(IBITS-1 downto 0);
		ret := to_word(replicate(immediate_data));
            when S1_CLIP | S1_UCLIP => --2^imm(4 downto 1) - imm(0) [0, 2^15]
                ret(to_integer(unsigned(imm(IBITS-1 downto 1)))) := '1';
                ret := ret + (ret'range => imm(0));
            when others => -- 2^imm(3 downto 1) - imm(0) [0, 128]
                immediate_data(rhzeros) := '1';
                immediate_data := immediate_data + (immediate_data'range => imm(0));
                if imm(IBITS-1) = '1' then
                    if (s1(4) = '0') then --signed *(-1) [-128, 128]
                        immediate_data := not(immediate_data) + "00000001";
                    else --unsigned +2 [0,130]
                        immediate_data := immediate_data + "10";
                    end if;
                end if;
		ret := to_word(replicate(immediate_data));
        end case;

        return ret;
    end;



    ---------------------------------------------------------------
    -- CONSTANTS VALUES --
    --------------------------------------------------------------
    constant sprw_ctrl_reg_res : sprw_ctrl_reg_type := (
        e16 => '0',
        fix => '0',
        mk  => (others => '1'),
        ms  => '1',
        sa  => swizzling_init,
        sb  => swizzling_init
    );

    constant sprw_ctrl_reg_none : sprw_ctrl_reg_type := (
        e16 => '0',
        fix => '0',
        mk  => (others => '0'),
        ms  => '0',
        sa  => (others => 0),
        sb  => (others => 0)
    );

    constant sprw_ctrl_reg_word_res : wordv := to_word(sprw_ctrl_reg_res);

    constant sprw_in_none   : sprw_in_type := (
        ra          => (others => '0'),
        rb          => (others => '0'),
        wb_valid    => '0',
        rd_zero     => '0',
        rs2_zero    => '0',
        opx         => '0',
        imm         => '0',
        op1         => (others => '0'),
        op2         => (others => '0'),
        rc_we       => '0',
        ctrl        => (others => '0')
    );
    constant sprw_out_none   : sprw_out_type := (
        s1bp        => (others => '0'),
        s2bp        => (others => '0'),
        ctrl        => (others => '0')
    );

end package body;
