------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015, Cobham Gaisler
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
-- Entity:      word_aligner
-- File:        word_aligner.vhd
-- Author:      Pascal Trotta
-- Description: generic SGMII comma detector and word aligner for serdes
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity word_aligner is
  generic(
    comma : std_logic_vector(9 downto 3) := "0011111");
  port(
    clk   : in std_logic;                      -- rx clock
    rstn  : in std_logic;                      -- asynchronous reset
    rx_in : in std_logic_vector(9 downto 0);   -- Data in
    val_in : in std_logic;                     -- Data in valid
    rx_out : out std_logic_vector(9 downto 0); -- Data out
    val_out : out std_logic;                   -- Data out valid
    aligned : out std_logic);                  -- Data aligned
end entity;

architecture word_arch of word_aligner is

  type state_type is (idle, fill_second, find_align, fix_align);
  type mux_sel is (S0,S1,S2,S3,S4,S5,S6,S7,S8,S9);

  type reg is record
    val : std_logic;
    state : state_type;
    alignment_sel : mux_sel;
    q0 : std_logic_vector(9 downto 0);
    q1 : std_logic_vector(9 downto 0);
  end record;

  type out_sig is record
    rx_out : std_logic_vector(9 downto 0);
    val_out : std_logic;
    aligned : std_logic;
  end record;

  signal regs, regin : reg;

begin
  
  combp: process(regs, rx_in, val_in)
    variable regv : reg;
    variable outv : out_sig;
    variable q1q0 : std_logic_vector(19 downto 0);
  begin

    regv := regs;
    outv.aligned := '0';
    outv.rx_out := rx_in;--(9 downto 0);

    q1q0 := regv.q1 & regv.q0;

    case regv.state is
      when idle =>
        if val_in = '1' then
          regv.state := fill_second; --when first data valid wait another clock cycle to fill the second register q1
        end if;

      when fill_second => 
        regv.state := find_align;

      when find_align =>
        regv.state := fix_align;
        if q1q0(18 downto 12) = comma then
          regv.alignment_sel:=S0;
        elsif q1q0(17 downto 11) = comma then
          regv.alignment_sel:=S1;
        elsif q1q0(16 downto 10) = comma then
          regv.alignment_sel:=S2;
        elsif q1q0(15 downto 9) = comma then
          regv.alignment_sel:=S3;
        elsif q1q0(14 downto 8) = comma then
          regv.alignment_sel:=S4;
        elsif q1q0(13 downto 7) = comma then
          regv.alignment_sel:=S5;
        elsif q1q0(12 downto 6) = comma then
          regv.alignment_sel:=S6;
        elsif q1q0(11 downto 5) = comma then
          regv.alignment_sel:=S7;
        elsif q1q0(10 downto 4) = comma then
          regv.alignment_sel:=S8;
        elsif q1q0(9 downto 3) = comma then
          regv.alignment_sel:=S9;
        else
          regv.state := find_align;   -- comma not found and still not aligned
        end if;

      when fix_align => -- fix the alignment until rstn
        regv.state := fix_align;
        outv.aligned := '1';
        case regv.alignment_sel is
          when S0 =>
            outv.rx_out := q1q0(18 downto 9);
          when S1 =>
            outv.rx_out := q1q0(17 downto 8);
          when S2 =>
            outv.rx_out := q1q0(16 downto 7);
          when S3 =>
            outv.rx_out := q1q0(15 downto 6);
          when S4 =>
            outv.rx_out := q1q0(14 downto 5);
          when S5 =>
            outv.rx_out := q1q0(13 downto 4);
          when S6 =>
            outv.rx_out := q1q0(12 downto 3);
          when S7 =>
            outv.rx_out := q1q0(11 downto 2);
          when S8 =>
            outv.rx_out := q1q0(10 downto 1);
          when S9 =>
            outv.rx_out := q1q0(9 downto 0);
         end case;
    end case;

    outv.val_out := outv.aligned and regv.val;

    regv.val := val_in;
    regv.q1 := regv.q0;
    regv.q0 := rx_in;

    -- internal registers and outputs assignments
    regin <= regv;
    aligned <= outv.aligned;
    val_out <= outv.val_out;
    rx_out <= outv.rx_out;

  end process;

  regp: process(clk, rstn)
  begin
    if rstn = '0' then
      regs.val <= '0';
      regs.state <= idle;
      regs.alignment_sel <= S0;
      regs.q0 <= (others =>'0');
      regs.q1 <= (others =>'0');
    elsif rising_edge(clk) then
      regs <= regin;
    end if;   
  end process;

end architecture;
