------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
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
-- Entity: 	grlfpw
-- File:	grlfpw.vhd
-- Author:	Edvin Catovic - Gaisler Research
-- Description:	GRFPU LITE / GRLFPC wrapper
------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use work.gencomp.all;

entity grlfpw_net is
  generic (tech     : integer := 0;
           pclow    : integer range 0 to 2 := 2;
           dsu      : integer range 0 to 1 := 1;
           disas    : integer range 0 to 1 := 0;
           pipe     : integer range 0 to 2 := 0
           );
  port (
    rst    : in  std_ulogic;			-- Reset
    clk    : in  std_ulogic;
    holdn  : in  std_ulogic;			-- pipeline hold
    cpi_flush  	: in std_ulogic;			  -- pipeline flush
    cpi_exack    	: in std_ulogic;			  -- FP exception acknowledge
    cpi_a_rs1  	: in std_logic_vector(4 downto 0);
    cpi_d_pc    : in std_logic_vector(31 downto 0);
    cpi_d_inst  : in std_logic_vector(31 downto 0);
    cpi_d_cnt   : in std_logic_vector(1 downto 0);
    cpi_d_trap  : in std_ulogic;
    cpi_d_annul : in std_ulogic;
    cpi_d_pv    : in std_ulogic;
    cpi_a_pc    : in std_logic_vector(31 downto 0);
    cpi_a_inst  : in std_logic_vector(31 downto 0);
    cpi_a_cnt   : in std_logic_vector(1 downto 0);
    cpi_a_trap  : in std_ulogic;
    cpi_a_annul : in std_ulogic;
    cpi_a_pv    : in std_ulogic;
    cpi_e_pc    : in std_logic_vector(31 downto 0);
    cpi_e_inst  : in std_logic_vector(31 downto 0);
    cpi_e_cnt   : in std_logic_vector(1 downto 0);
    cpi_e_trap  : in std_ulogic;
    cpi_e_annul : in std_ulogic;
    cpi_e_pv    : in std_ulogic;
    cpi_m_pc    : in std_logic_vector(31 downto 0);
    cpi_m_inst  : in std_logic_vector(31 downto 0);
    cpi_m_cnt   : in std_logic_vector(1 downto 0);
    cpi_m_trap  : in std_ulogic;
    cpi_m_annul : in std_ulogic;
    cpi_m_pv    : in std_ulogic;
    cpi_x_pc    : in std_logic_vector(31 downto 0);
    cpi_x_inst  : in std_logic_vector(31 downto 0);
    cpi_x_cnt   : in std_logic_vector(1 downto 0);
    cpi_x_trap  : in std_ulogic;
    cpi_x_annul : in std_ulogic;
    cpi_x_pv    : in std_ulogic;
    cpi_lddata        : in std_logic_vector(31 downto 0);     -- load data
    cpi_dbg_enable : in std_ulogic;
    cpi_dbg_write  : in std_ulogic;
    cpi_dbg_fsr    : in std_ulogic;                            -- FSR access
    cpi_dbg_addr   : in std_logic_vector(4 downto 0);
    cpi_dbg_data   : in std_logic_vector(31 downto 0);

    cpo_data          : out std_logic_vector(31 downto 0); -- store data
    cpo_exc  	        : out std_logic;			 -- FP exception
    cpo_cc           : out std_logic_vector(1 downto 0);  -- FP condition codes
    cpo_ccv  	       : out std_ulogic;			 -- FP condition codes valid
    cpo_ldlock       : out std_logic;			 -- FP pipeline hold
    cpo_holdn         : out std_ulogic;
    cpo_dbg_data     : out std_logic_vector(31 downto 0);

    rfi1_rd1addr 	: out std_logic_vector(3 downto 0);
    rfi1_rd2addr 	: out std_logic_vector(3 downto 0);
    rfi1_wraddr 	: out std_logic_vector(3 downto 0);
    rfi1_wrdata 	: out std_logic_vector(31 downto 0);
    rfi1_ren1        : out std_ulogic;
    rfi1_ren2        : out std_ulogic;
    rfi1_wren        : out std_ulogic;

    rfi2_rd1addr 	: out std_logic_vector(3 downto 0);
    rfi2_rd2addr 	: out std_logic_vector(3 downto 0);
    rfi2_wraddr 	: out std_logic_vector(3 downto 0);
    rfi2_wrdata 	: out std_logic_vector(31 downto 0);
    rfi2_ren1        : out std_ulogic;
    rfi2_ren2        : out std_ulogic;
    rfi2_wren        : out std_ulogic;

    rfo1_data1    	: in std_logic_vector(31 downto 0);
    rfo1_data2    	: in std_logic_vector(31 downto 0);
    rfo2_data1    	: in std_logic_vector(31 downto 0);
    rfo2_data2    	: in std_logic_vector(31 downto 0)
    );
end;


architecture rtl of grlfpw_net is

component grlfpw_0_axcelerator is
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector (4 downto 0);
  cpi_d_pc : in std_logic_vector (31 downto 0);
  cpi_d_inst : in std_logic_vector (31 downto 0);
  cpi_d_cnt : in std_logic_vector (1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector (31 downto 0);
  cpi_a_inst : in std_logic_vector (31 downto 0);
  cpi_a_cnt : in std_logic_vector (1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector (31 downto 0);
  cpi_e_inst : in std_logic_vector (31 downto 0);
  cpi_e_cnt : in std_logic_vector (1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector (31 downto 0);
  cpi_m_inst : in std_logic_vector (31 downto 0);
  cpi_m_cnt : in std_logic_vector (1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector (31 downto 0);
  cpi_x_inst : in std_logic_vector (31 downto 0);
  cpi_x_cnt : in std_logic_vector (1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector (31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector (4 downto 0);
  cpi_dbg_data : in std_logic_vector (31 downto 0);
  cpo_data : out std_logic_vector (31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector (1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_dbg_data : out std_logic_vector (31 downto 0);
  rfi1_rd1addr : out std_logic_vector (3 downto 0);
  rfi1_rd2addr : out std_logic_vector (3 downto 0);
  rfi1_wraddr : out std_logic_vector (3 downto 0);
  rfi1_wrdata : out std_logic_vector (31 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi2_rd1addr : out std_logic_vector (3 downto 0);
  rfi2_rd2addr : out std_logic_vector (3 downto 0);
  rfi2_wraddr : out std_logic_vector (3 downto 0);
  rfi2_wrdata : out std_logic_vector (31 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfo1_data1 : in std_logic_vector (31 downto 0);
  rfo1_data2 : in std_logic_vector (31 downto 0);
  rfo2_data1 : in std_logic_vector (31 downto 0);
  rfo2_data2 : in std_logic_vector (31 downto 0));
end component;

component grlfpw_0_proasic3 is
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector (4 downto 0);
  cpi_d_pc : in std_logic_vector (31 downto 0);
  cpi_d_inst : in std_logic_vector (31 downto 0);
  cpi_d_cnt : in std_logic_vector (1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector (31 downto 0);
  cpi_a_inst : in std_logic_vector (31 downto 0);
  cpi_a_cnt : in std_logic_vector (1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector (31 downto 0);
  cpi_e_inst : in std_logic_vector (31 downto 0);
  cpi_e_cnt : in std_logic_vector (1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector (31 downto 0);
  cpi_m_inst : in std_logic_vector (31 downto 0);
  cpi_m_cnt : in std_logic_vector (1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector (31 downto 0);
  cpi_x_inst : in std_logic_vector (31 downto 0);
  cpi_x_cnt : in std_logic_vector (1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector (31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector (4 downto 0);
  cpi_dbg_data : in std_logic_vector (31 downto 0);
  cpo_data : out std_logic_vector (31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector (1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_dbg_data : out std_logic_vector (31 downto 0);
  rfi1_rd1addr : out std_logic_vector (3 downto 0);
  rfi1_rd2addr : out std_logic_vector (3 downto 0);
  rfi1_wraddr : out std_logic_vector (3 downto 0);
  rfi1_wrdata : out std_logic_vector (31 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi2_rd1addr : out std_logic_vector (3 downto 0);
  rfi2_rd2addr : out std_logic_vector (3 downto 0);
  rfi2_wraddr : out std_logic_vector (3 downto 0);
  rfi2_wrdata : out std_logic_vector (31 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfo1_data1 : in std_logic_vector (31 downto 0);
  rfo1_data2 : in std_logic_vector (31 downto 0);
  rfo2_data1 : in std_logic_vector (31 downto 0);
  rfo2_data2 : in std_logic_vector (31 downto 0));
end component;

component grlfpw_0_unisim
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector (4 downto 0);
  cpi_d_pc : in std_logic_vector (31 downto 0);
  cpi_d_inst : in std_logic_vector (31 downto 0);
  cpi_d_cnt : in std_logic_vector (1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector (31 downto 0);
  cpi_a_inst : in std_logic_vector (31 downto 0);
  cpi_a_cnt : in std_logic_vector (1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector (31 downto 0);
  cpi_e_inst : in std_logic_vector (31 downto 0);
  cpi_e_cnt : in std_logic_vector (1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector (31 downto 0);
  cpi_m_inst : in std_logic_vector (31 downto 0);
  cpi_m_cnt : in std_logic_vector (1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector (31 downto 0);
  cpi_x_inst : in std_logic_vector (31 downto 0);
  cpi_x_cnt : in std_logic_vector (1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector (31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector (4 downto 0);
  cpi_dbg_data : in std_logic_vector (31 downto 0);
  cpo_data : out std_logic_vector (31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector (1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_dbg_data : out std_logic_vector (31 downto 0);
  rfi1_rd1addr : out std_logic_vector (3 downto 0);
  rfi1_rd2addr : out std_logic_vector (3 downto 0);
  rfi1_wraddr : out std_logic_vector (3 downto 0);
  rfi1_wrdata : out std_logic_vector (31 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi2_rd1addr : out std_logic_vector (3 downto 0);
  rfi2_rd2addr : out std_logic_vector (3 downto 0);
  rfi2_wraddr : out std_logic_vector (3 downto 0);
  rfi2_wrdata : out std_logic_vector (31 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfo1_data1 : in std_logic_vector (31 downto 0);
  rfo1_data2 : in std_logic_vector (31 downto 0);
  rfo2_data1 : in std_logic_vector (31 downto 0);
  rfo2_data2 : in std_logic_vector (31 downto 0));
end component;


component grlfpw_p0_unisim
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector(4 downto 0);
  cpi_d_pc : in std_logic_vector(31 downto 0);
  cpi_d_inst : in std_logic_vector(31 downto 0);
  cpi_d_cnt : in std_logic_vector(1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector(31 downto 0);
  cpi_a_inst : in std_logic_vector(31 downto 0);
  cpi_a_cnt : in std_logic_vector(1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector(31 downto 0);
  cpi_e_inst : in std_logic_vector(31 downto 0);
  cpi_e_cnt : in std_logic_vector(1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector(31 downto 0);
  cpi_m_inst : in std_logic_vector(31 downto 0);
  cpi_m_cnt : in std_logic_vector(1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector(31 downto 0);
  cpi_x_inst : in std_logic_vector(31 downto 0);
  cpi_x_cnt : in std_logic_vector(1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector(31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector(4 downto 0);
  cpi_dbg_data : in std_logic_vector(31 downto 0);
  cpi_ft_dis :  in std_logic;
  cpi_ft_ten :  in std_logic;
  cpi_ft_cb : in std_logic_vector(7 downto 0);
  cpi_ft_dpsel :  in std_logic;
  cpo_data : out std_logic_vector(31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector(1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_restart :  out std_logic;
  cpo_dbg_data : out std_logic_vector(31 downto 0);
  cpo_dbg_par : out std_logic_vector(7 downto 0);
  rfi1_rd1addr : out std_logic_vector(3 downto 0);
  rfi1_rd2addr : out std_logic_vector(3 downto 0);
  rfi1_wraddr : out std_logic_vector(3 downto 0);
  rfi1_wrdata : out std_logic_vector(31 downto 0);
  rfi1_wecb : out std_logic_vector(7 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi1_inhw1 :  out std_logic;
  rfi1_inhw2 :  out std_logic;
  rfi1_einj1 :  out std_logic;
  rfi1_einj2 :  out std_logic;
  rfi2_rd1addr : out std_logic_vector(3 downto 0);
  rfi2_rd2addr : out std_logic_vector(3 downto 0);
  rfi2_wraddr : out std_logic_vector(3 downto 0);
  rfi2_wrdata : out std_logic_vector(31 downto 0);
  rfi2_wecb : out std_logic_vector(7 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfi2_inhw1 :  out std_logic;
  rfi2_inhw2 :  out std_logic;
  rfi2_einj1 :  out std_logic;
  rfi2_einj2 :  out std_logic;
  rfo1_data1 : in std_logic_vector(31 downto 0);
  rfo1_data2 : in std_logic_vector(31 downto 0);
  rfo1_decb1 : in std_logic_vector(7 downto 0);
  rfo1_decb2 : in std_logic_vector(7 downto 0);
  rfo2_data1 : in std_logic_vector(31 downto 0);
  rfo2_data2 : in std_logic_vector(31 downto 0);
  rfo2_decb1 : in std_logic_vector(7 downto 0);
  rfo2_decb2 : in std_logic_vector(7 downto 0));
end component;

component grlfpw_p1_unisim
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector(4 downto 0);
  cpi_d_pc : in std_logic_vector(31 downto 0);
  cpi_d_inst : in std_logic_vector(31 downto 0);
  cpi_d_cnt : in std_logic_vector(1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector(31 downto 0);
  cpi_a_inst : in std_logic_vector(31 downto 0);
  cpi_a_cnt : in std_logic_vector(1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector(31 downto 0);
  cpi_e_inst : in std_logic_vector(31 downto 0);
  cpi_e_cnt : in std_logic_vector(1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector(31 downto 0);
  cpi_m_inst : in std_logic_vector(31 downto 0);
  cpi_m_cnt : in std_logic_vector(1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector(31 downto 0);
  cpi_x_inst : in std_logic_vector(31 downto 0);
  cpi_x_cnt : in std_logic_vector(1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector(31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector(4 downto 0);
  cpi_dbg_data : in std_logic_vector(31 downto 0);
  cpi_ft_dis :  in std_logic;
  cpi_ft_ten :  in std_logic;
  cpi_ft_cb : in std_logic_vector(7 downto 0);
  cpi_ft_dpsel :  in std_logic;
  cpo_data : out std_logic_vector(31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector(1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_restart :  out std_logic;
  cpo_dbg_data : out std_logic_vector(31 downto 0);
  cpo_dbg_par : out std_logic_vector(7 downto 0);
  rfi1_rd1addr : out std_logic_vector(3 downto 0);
  rfi1_rd2addr : out std_logic_vector(3 downto 0);
  rfi1_wraddr : out std_logic_vector(3 downto 0);
  rfi1_wrdata : out std_logic_vector(31 downto 0);
  rfi1_wecb : out std_logic_vector(7 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi1_inhw1 :  out std_logic;
  rfi1_inhw2 :  out std_logic;
  rfi1_einj1 :  out std_logic;
  rfi1_einj2 :  out std_logic;
  rfi2_rd1addr : out std_logic_vector(3 downto 0);
  rfi2_rd2addr : out std_logic_vector(3 downto 0);
  rfi2_wraddr : out std_logic_vector(3 downto 0);
  rfi2_wrdata : out std_logic_vector(31 downto 0);
  rfi2_wecb : out std_logic_vector(7 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfi2_inhw1 :  out std_logic;
  rfi2_inhw2 :  out std_logic;
  rfi2_einj1 :  out std_logic;
  rfi2_einj2 :  out std_logic;
  rfo1_data1 : in std_logic_vector(31 downto 0);
  rfo1_data2 : in std_logic_vector(31 downto 0);
  rfo1_decb1 : in std_logic_vector(7 downto 0);
  rfo1_decb2 : in std_logic_vector(7 downto 0);
  rfo2_data1 : in std_logic_vector(31 downto 0);
  rfo2_data2 : in std_logic_vector(31 downto 0);
  rfo2_decb1 : in std_logic_vector(7 downto 0);
  rfo2_decb2 : in std_logic_vector(7 downto 0));
end component;


component grlfpw_p2_unisim
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector(4 downto 0);
  cpi_d_pc : in std_logic_vector(31 downto 0);
  cpi_d_inst : in std_logic_vector(31 downto 0);
  cpi_d_cnt : in std_logic_vector(1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector(31 downto 0);
  cpi_a_inst : in std_logic_vector(31 downto 0);
  cpi_a_cnt : in std_logic_vector(1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector(31 downto 0);
  cpi_e_inst : in std_logic_vector(31 downto 0);
  cpi_e_cnt : in std_logic_vector(1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector(31 downto 0);
  cpi_m_inst : in std_logic_vector(31 downto 0);
  cpi_m_cnt : in std_logic_vector(1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector(31 downto 0);
  cpi_x_inst : in std_logic_vector(31 downto 0);
  cpi_x_cnt : in std_logic_vector(1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector(31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector(4 downto 0);
  cpi_dbg_data : in std_logic_vector(31 downto 0);
  cpi_ft_dis :  in std_logic;
  cpi_ft_ten :  in std_logic;
  cpi_ft_cb : in std_logic_vector(7 downto 0);
  cpi_ft_dpsel :  in std_logic;
  cpo_data : out std_logic_vector(31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector(1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_restart :  out std_logic;
  cpo_dbg_data : out std_logic_vector(31 downto 0);
  cpo_dbg_par : out std_logic_vector(7 downto 0);
  rfi1_rd1addr : out std_logic_vector(3 downto 0);
  rfi1_rd2addr : out std_logic_vector(3 downto 0);
  rfi1_wraddr : out std_logic_vector(3 downto 0);
  rfi1_wrdata : out std_logic_vector(31 downto 0);
  rfi1_wecb : out std_logic_vector(7 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi1_inhw1 :  out std_logic;
  rfi1_inhw2 :  out std_logic;
  rfi1_einj1 :  out std_logic;
  rfi1_einj2 :  out std_logic;
  rfi2_rd1addr : out std_logic_vector(3 downto 0);
  rfi2_rd2addr : out std_logic_vector(3 downto 0);
  rfi2_wraddr : out std_logic_vector(3 downto 0);
  rfi2_wrdata : out std_logic_vector(31 downto 0);
  rfi2_wecb : out std_logic_vector(7 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfi2_inhw1 :  out std_logic;
  rfi2_inhw2 :  out std_logic;
  rfi2_einj1 :  out std_logic;
  rfi2_einj2 :  out std_logic;
  rfo1_data1 : in std_logic_vector(31 downto 0);
  rfo1_data2 : in std_logic_vector(31 downto 0);
  rfo1_decb1 : in std_logic_vector(7 downto 0);
  rfo1_decb2 : in std_logic_vector(7 downto 0);
  rfo2_data1 : in std_logic_vector(31 downto 0);
  rfo2_data2 : in std_logic_vector(31 downto 0);
  rfo2_decb1 : in std_logic_vector(7 downto 0);
  rfo2_decb2 : in std_logic_vector(7 downto 0));
end component;

component grlfpw_0_altera
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector (4 downto 0);
  cpi_d_pc : in std_logic_vector (31 downto 0);
  cpi_d_inst : in std_logic_vector (31 downto 0);
  cpi_d_cnt : in std_logic_vector (1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector (31 downto 0);
  cpi_a_inst : in std_logic_vector (31 downto 0);
  cpi_a_cnt : in std_logic_vector (1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector (31 downto 0);
  cpi_e_inst : in std_logic_vector (31 downto 0);
  cpi_e_cnt : in std_logic_vector (1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector (31 downto 0);
  cpi_m_inst : in std_logic_vector (31 downto 0);
  cpi_m_cnt : in std_logic_vector (1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector (31 downto 0);
  cpi_x_inst : in std_logic_vector (31 downto 0);
  cpi_x_cnt : in std_logic_vector (1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector (31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector (4 downto 0);
  cpi_dbg_data : in std_logic_vector (31 downto 0);
  cpo_data : out std_logic_vector (31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector (1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_dbg_data : out std_logic_vector (31 downto 0);
  rfi1_rd1addr : out std_logic_vector (3 downto 0);
  rfi1_rd2addr : out std_logic_vector (3 downto 0);
  rfi1_wraddr : out std_logic_vector (3 downto 0);
  rfi1_wrdata : out std_logic_vector (31 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi2_rd1addr : out std_logic_vector (3 downto 0);
  rfi2_rd2addr : out std_logic_vector (3 downto 0);
  rfi2_wraddr : out std_logic_vector (3 downto 0);
  rfi2_wrdata : out std_logic_vector (31 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfo1_data1 : in std_logic_vector (31 downto 0);
  rfo1_data2 : in std_logic_vector (31 downto 0);
  rfo2_data1 : in std_logic_vector (31 downto 0);
  rfo2_data2 : in std_logic_vector (31 downto 0));
end component;

component grlfpw_0_stratixii
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector (4 downto 0);
  cpi_d_pc : in std_logic_vector (31 downto 0);
  cpi_d_inst : in std_logic_vector (31 downto 0);
  cpi_d_cnt : in std_logic_vector (1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector (31 downto 0);
  cpi_a_inst : in std_logic_vector (31 downto 0);
  cpi_a_cnt : in std_logic_vector (1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector (31 downto 0);
  cpi_e_inst : in std_logic_vector (31 downto 0);
  cpi_e_cnt : in std_logic_vector (1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector (31 downto 0);
  cpi_m_inst : in std_logic_vector (31 downto 0);
  cpi_m_cnt : in std_logic_vector (1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector (31 downto 0);
  cpi_x_inst : in std_logic_vector (31 downto 0);
  cpi_x_cnt : in std_logic_vector (1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector (31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector (4 downto 0);
  cpi_dbg_data : in std_logic_vector (31 downto 0);
  cpo_data : out std_logic_vector (31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector (1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_dbg_data : out std_logic_vector (31 downto 0);
  rfi1_rd1addr : out std_logic_vector (3 downto 0);
  rfi1_rd2addr : out std_logic_vector (3 downto 0);
  rfi1_wraddr : out std_logic_vector (3 downto 0);
  rfi1_wrdata : out std_logic_vector (31 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi2_rd1addr : out std_logic_vector (3 downto 0);
  rfi2_rd2addr : out std_logic_vector (3 downto 0);
  rfi2_wraddr : out std_logic_vector (3 downto 0);
  rfi2_wrdata : out std_logic_vector (31 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfo1_data1 : in std_logic_vector (31 downto 0);
  rfo1_data2 : in std_logic_vector (31 downto 0);
  rfo2_data1 : in std_logic_vector (31 downto 0);
  rfo2_data2 : in std_logic_vector (31 downto 0));
end component;

component grlfpw_0_stratixiii
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector (4 downto 0);
  cpi_d_pc : in std_logic_vector (31 downto 0);
  cpi_d_inst : in std_logic_vector (31 downto 0);
  cpi_d_cnt : in std_logic_vector (1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector (31 downto 0);
  cpi_a_inst : in std_logic_vector (31 downto 0);
  cpi_a_cnt : in std_logic_vector (1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector (31 downto 0);
  cpi_e_inst : in std_logic_vector (31 downto 0);
  cpi_e_cnt : in std_logic_vector (1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector (31 downto 0);
  cpi_m_inst : in std_logic_vector (31 downto 0);
  cpi_m_cnt : in std_logic_vector (1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector (31 downto 0);
  cpi_x_inst : in std_logic_vector (31 downto 0);
  cpi_x_cnt : in std_logic_vector (1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector (31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector (4 downto 0);
  cpi_dbg_data : in std_logic_vector (31 downto 0);
  cpo_data : out std_logic_vector (31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector (1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_dbg_data : out std_logic_vector (31 downto 0);
  rfi1_rd1addr : out std_logic_vector (3 downto 0);
  rfi1_rd2addr : out std_logic_vector (3 downto 0);
  rfi1_wraddr : out std_logic_vector (3 downto 0);
  rfi1_wrdata : out std_logic_vector (31 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi2_rd1addr : out std_logic_vector (3 downto 0);
  rfi2_rd2addr : out std_logic_vector (3 downto 0);
  rfi2_wraddr : out std_logic_vector (3 downto 0);
  rfi2_wrdata : out std_logic_vector (31 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfo1_data1 : in std_logic_vector (31 downto 0);
  rfo1_data2 : in std_logic_vector (31 downto 0);
  rfo2_data1 : in std_logic_vector (31 downto 0);
  rfo2_data2 : in std_logic_vector (31 downto 0));
end component;

component grlfpw_0_cycloneiii
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector (4 downto 0);
  cpi_d_pc : in std_logic_vector (31 downto 0);
  cpi_d_inst : in std_logic_vector (31 downto 0);
  cpi_d_cnt : in std_logic_vector (1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector (31 downto 0);
  cpi_a_inst : in std_logic_vector (31 downto 0);
  cpi_a_cnt : in std_logic_vector (1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector (31 downto 0);
  cpi_e_inst : in std_logic_vector (31 downto 0);
  cpi_e_cnt : in std_logic_vector (1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector (31 downto 0);
  cpi_m_inst : in std_logic_vector (31 downto 0);
  cpi_m_cnt : in std_logic_vector (1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector (31 downto 0);
  cpi_x_inst : in std_logic_vector (31 downto 0);
  cpi_x_cnt : in std_logic_vector (1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector (31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector (4 downto 0);
  cpi_dbg_data : in std_logic_vector (31 downto 0);
  cpo_data : out std_logic_vector (31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector (1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_dbg_data : out std_logic_vector (31 downto 0);
  rfi1_rd1addr : out std_logic_vector (3 downto 0);
  rfi1_rd2addr : out std_logic_vector (3 downto 0);
  rfi1_wraddr : out std_logic_vector (3 downto 0);
  rfi1_wrdata : out std_logic_vector (31 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi2_rd1addr : out std_logic_vector (3 downto 0);
  rfi2_rd2addr : out std_logic_vector (3 downto 0);
  rfi2_wraddr : out std_logic_vector (3 downto 0);
  rfi2_wrdata : out std_logic_vector (31 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfo1_data1 : in std_logic_vector (31 downto 0);
  rfo1_data2 : in std_logic_vector (31 downto 0);
  rfo2_data1 : in std_logic_vector (31 downto 0);
  rfo2_data2 : in std_logic_vector (31 downto 0));
end component;

component grlfpw_0_actfus is
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector (4 downto 0);
  cpi_d_pc : in std_logic_vector (31 downto 0);
  cpi_d_inst : in std_logic_vector (31 downto 0);
  cpi_d_cnt : in std_logic_vector (1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector (31 downto 0);
  cpi_a_inst : in std_logic_vector (31 downto 0);
  cpi_a_cnt : in std_logic_vector (1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector (31 downto 0);
  cpi_e_inst : in std_logic_vector (31 downto 0);
  cpi_e_cnt : in std_logic_vector (1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector (31 downto 0);
  cpi_m_inst : in std_logic_vector (31 downto 0);
  cpi_m_cnt : in std_logic_vector (1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector (31 downto 0);
  cpi_x_inst : in std_logic_vector (31 downto 0);
  cpi_x_cnt : in std_logic_vector (1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector (31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector (4 downto 0);
  cpi_dbg_data : in std_logic_vector (31 downto 0);
  cpo_data : out std_logic_vector (31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector (1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_dbg_data : out std_logic_vector (31 downto 0);
  rfi1_rd1addr : out std_logic_vector (3 downto 0);
  rfi1_rd2addr : out std_logic_vector (3 downto 0);
  rfi1_wraddr : out std_logic_vector (3 downto 0);
  rfi1_wrdata : out std_logic_vector (31 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi2_rd1addr : out std_logic_vector (3 downto 0);
  rfi2_rd2addr : out std_logic_vector (3 downto 0);
  rfi2_wraddr : out std_logic_vector (3 downto 0);
  rfi2_wrdata : out std_logic_vector (31 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfo1_data1 : in std_logic_vector (31 downto 0);
  rfo1_data2 : in std_logic_vector (31 downto 0);
  rfo2_data1 : in std_logic_vector (31 downto 0);
  rfo2_data2 : in std_logic_vector (31 downto 0));
end component;

component grlfpw_0_proasic3e is
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector (4 downto 0);
  cpi_d_pc : in std_logic_vector (31 downto 0);
  cpi_d_inst : in std_logic_vector (31 downto 0);
  cpi_d_cnt : in std_logic_vector (1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector (31 downto 0);
  cpi_a_inst : in std_logic_vector (31 downto 0);
  cpi_a_cnt : in std_logic_vector (1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector (31 downto 0);
  cpi_e_inst : in std_logic_vector (31 downto 0);
  cpi_e_cnt : in std_logic_vector (1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector (31 downto 0);
  cpi_m_inst : in std_logic_vector (31 downto 0);
  cpi_m_cnt : in std_logic_vector (1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector (31 downto 0);
  cpi_x_inst : in std_logic_vector (31 downto 0);
  cpi_x_cnt : in std_logic_vector (1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector (31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector (4 downto 0);
  cpi_dbg_data : in std_logic_vector (31 downto 0);
  cpo_data : out std_logic_vector (31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector (1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_dbg_data : out std_logic_vector (31 downto 0);
  rfi1_rd1addr : out std_logic_vector (3 downto 0);
  rfi1_rd2addr : out std_logic_vector (3 downto 0);
  rfi1_wraddr : out std_logic_vector (3 downto 0);
  rfi1_wrdata : out std_logic_vector (31 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi2_rd1addr : out std_logic_vector (3 downto 0);
  rfi2_rd2addr : out std_logic_vector (3 downto 0);
  rfi2_wraddr : out std_logic_vector (3 downto 0);
  rfi2_wrdata : out std_logic_vector (31 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfo1_data1 : in std_logic_vector (31 downto 0);
  rfo1_data2 : in std_logic_vector (31 downto 0);
  rfo2_data1 : in std_logic_vector (31 downto 0);
  rfo2_data2 : in std_logic_vector (31 downto 0));
end component;

component grlfpw_0_proasic3l is
port(
  rst :  in std_logic;
  clk :  in std_logic;
  holdn :  in std_logic;
  cpi_flush :  in std_logic;
  cpi_exack :  in std_logic;
  cpi_a_rs1 : in std_logic_vector (4 downto 0);
  cpi_d_pc : in std_logic_vector (31 downto 0);
  cpi_d_inst : in std_logic_vector (31 downto 0);
  cpi_d_cnt : in std_logic_vector (1 downto 0);
  cpi_d_trap :  in std_logic;
  cpi_d_annul :  in std_logic;
  cpi_d_pv :  in std_logic;
  cpi_a_pc : in std_logic_vector (31 downto 0);
  cpi_a_inst : in std_logic_vector (31 downto 0);
  cpi_a_cnt : in std_logic_vector (1 downto 0);
  cpi_a_trap :  in std_logic;
  cpi_a_annul :  in std_logic;
  cpi_a_pv :  in std_logic;
  cpi_e_pc : in std_logic_vector (31 downto 0);
  cpi_e_inst : in std_logic_vector (31 downto 0);
  cpi_e_cnt : in std_logic_vector (1 downto 0);
  cpi_e_trap :  in std_logic;
  cpi_e_annul :  in std_logic;
  cpi_e_pv :  in std_logic;
  cpi_m_pc : in std_logic_vector (31 downto 0);
  cpi_m_inst : in std_logic_vector (31 downto 0);
  cpi_m_cnt : in std_logic_vector (1 downto 0);
  cpi_m_trap :  in std_logic;
  cpi_m_annul :  in std_logic;
  cpi_m_pv :  in std_logic;
  cpi_x_pc : in std_logic_vector (31 downto 0);
  cpi_x_inst : in std_logic_vector (31 downto 0);
  cpi_x_cnt : in std_logic_vector (1 downto 0);
  cpi_x_trap :  in std_logic;
  cpi_x_annul :  in std_logic;
  cpi_x_pv :  in std_logic;
  cpi_lddata : in std_logic_vector (31 downto 0);
  cpi_dbg_enable :  in std_logic;
  cpi_dbg_write :  in std_logic;
  cpi_dbg_fsr :  in std_logic;
  cpi_dbg_addr : in std_logic_vector (4 downto 0);
  cpi_dbg_data : in std_logic_vector (31 downto 0);
  cpo_data : out std_logic_vector (31 downto 0);
  cpo_exc :  out std_logic;
  cpo_cc : out std_logic_vector (1 downto 0);
  cpo_ccv :  out std_logic;
  cpo_ldlock :  out std_logic;
  cpo_holdn :  out std_logic;
  cpo_dbg_data : out std_logic_vector (31 downto 0);
  rfi1_rd1addr : out std_logic_vector (3 downto 0);
  rfi1_rd2addr : out std_logic_vector (3 downto 0);
  rfi1_wraddr : out std_logic_vector (3 downto 0);
  rfi1_wrdata : out std_logic_vector (31 downto 0);
  rfi1_ren1 :  out std_logic;
  rfi1_ren2 :  out std_logic;
  rfi1_wren :  out std_logic;
  rfi2_rd1addr : out std_logic_vector (3 downto 0);
  rfi2_rd2addr : out std_logic_vector (3 downto 0);
  rfi2_wraddr : out std_logic_vector (3 downto 0);
  rfi2_wrdata : out std_logic_vector (31 downto 0);
  rfi2_ren1 :  out std_logic;
  rfi2_ren2 :  out std_logic;
  rfi2_wren :  out std_logic;
  rfo1_data1 : in std_logic_vector (31 downto 0);
  rfo1_data2 : in std_logic_vector (31 downto 0);
  rfo2_data1 : in std_logic_vector (31 downto 0);
  rfo2_data2 : in std_logic_vector (31 downto 0));
end component;

signal vgnd : std_logic_vector(31 downto 0);

begin

 vgnd <= (others => '0');
  
 alt : if (tech = altera) generate  -- Cyclone, Cyclone V
    grlfpw0 : grlfpw_0_altera
      port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
    	cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
    	cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
    	cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
    	cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
    	cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
    	cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
    	cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn, cpo_dbg_data,
    	rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, rfi1_ren1,
    	rfi1_ren2, rfi1_wren, rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr,
    	rfi2_wrdata, rfi2_ren1, rfi2_ren2, rfi2_wren, rfo1_data1,
    	rfo1_data2, rfo2_data1, rfo2_data2 );
  end generate;

  strtx : if (tech = stratix1) or (tech = stratix2) generate
    grlfpw0 : grlfpw_0_stratixii
      port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
    	cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
    	cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
    	cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
    	cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
    	cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
    	cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
    	cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn, cpo_dbg_data,
    	rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, rfi1_ren1,
    	rfi1_ren2, rfi1_wren, rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr,
    	rfi2_wrdata, rfi2_ren1, rfi2_ren2, rfi2_wren, rfo1_data1,
    	rfo1_data2, rfo2_data1, rfo2_data2 );
  end generate;
    
  strtxiii : if (tech = stratix3) or (tech = stratix4) or (tech = stratix5) generate
    grlfpw40 : grlfpw_0_stratixiii
      port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
    	cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
    	cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
    	cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
    	cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
    	cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
    	cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
    	cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn, cpo_dbg_data,
    	rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, rfi1_ren1,
    	rfi1_ren2, rfi1_wren, rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr,
    	rfi2_wrdata, rfi2_ren1, rfi2_ren2, rfi2_wren, rfo1_data1,
    	rfo1_data2, rfo2_data1, rfo2_data2 );
  end generate;
    
  cyc3 : if (tech = cyclone3) generate
    grlfpw40 : grlfpw_0_cycloneiii
      port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
    	cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
    	cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
    	cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
    	cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
    	cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
    	cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
    	cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn, cpo_dbg_data,
    	rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, rfi1_ren1,
    	rfi1_ren2, rfi1_wren, rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr,
    	rfi2_wrdata, rfi2_ren1, rfi2_ren2, rfi2_wren, rfo1_data1,
    	rfo1_data2, rfo2_data1, rfo2_data2 );
  end generate;  
    
  ax : if (tech = axcel) or (tech = axdsp) generate
    grlfpw0 : grlfpw_0_axcelerator
      port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
    	cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
    	cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
    	cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
    	cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
    	cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
    	cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
    	cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn, cpo_dbg_data,
    	rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, rfi1_ren1,
    	rfi1_ren2, rfi1_wren, rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr,
    	rfi2_wrdata, rfi2_ren1, rfi2_ren2, rfi2_wren, rfo1_data1,
    	rfo1_data2, rfo2_data1, rfo2_data2 );
  end generate;

  fus : if (tech = actfus) generate
    grlfpw0 : grlfpw_0_actfus
      port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
    	cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
    	cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
    	cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
    	cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
    	cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
    	cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
    	cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn, cpo_dbg_data,
    	rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, rfi1_ren1,
    	rfi1_ren2, rfi1_wren, rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr,
    	rfi2_wrdata, rfi2_ren1, rfi2_ren2, rfi2_wren, rfo1_data1,
    	rfo1_data2, rfo2_data1, rfo2_data2 );
  end generate;

  pa3 : if (tech = apa3) generate
    grlfpw0 : grlfpw_0_proasic3
      port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
    	cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
    	cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
    	cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
    	cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
    	cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
    	cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
    	cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn, cpo_dbg_data,
    	rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, rfi1_ren1,
    	rfi1_ren2, rfi1_wren, rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr,
    	rfi2_wrdata, rfi2_ren1, rfi2_ren2, rfi2_wren, rfo1_data1,
    	rfo1_data2, rfo2_data1, rfo2_data2 );
  end generate;

  pa3l : if (tech = apa3l) generate
    grlfpw0 : grlfpw_0_proasic3l
      port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
    	cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
    	cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
    	cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
    	cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
    	cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
    	cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
    	cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn, cpo_dbg_data,
    	rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, rfi1_ren1,
    	rfi1_ren2, rfi1_wren, rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr,
    	rfi2_wrdata, rfi2_ren1, rfi2_ren2, rfi2_wren, rfo1_data1,
    	rfo1_data2, rfo2_data1, rfo2_data2 );
  end generate;

  pa3e : if (tech = apa3e) generate
    grlfpw0 : grlfpw_0_proasic3e
      port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
    	cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
    	cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
    	cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
    	cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
    	cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
    	cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
    	cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn, cpo_dbg_data,
    	rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, rfi1_ren1,
    	rfi1_ren2, rfi1_wren, rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr,
    	rfi2_wrdata, rfi2_ren1, rfi2_ren2, rfi2_wren, rfo1_data1,
    	rfo1_data2, rfo2_data1, rfo2_data2 );
  end generate;

  uni : if (is_unisim(tech) = 1) generate
    dfl : if tech /= virtex5 generate
      grlfpw0 : grlfpw_0_unisim
        port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
                  cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
                  cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
                  cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
                  cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
                  cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
                  cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
                  cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn, cpo_dbg_data,
                  rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, rfi1_ren1,
                  rfi1_ren2, rfi1_wren, rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr,
                  rfi2_wrdata, rfi2_ren1, rfi2_ren2, rfi2_wren, rfo1_data1,
                  rfo1_data2, rfo2_data1, rfo2_data2 );
    end generate;
    v5 : if tech = virtex5 generate
      pipe0 : if pipe = 0 generate
        grlfpw0 : grlfpw_p0_unisim
          port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
                    cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
                    cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
                    cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
                    cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
                    cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
                    cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
                    vgnd(0), vgnd(0), vgnd(7 downto 0), vgnd(0),
                    cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn,
                    open, cpo_dbg_data, open,
                    rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, open,
                    rfi1_ren1, rfi1_ren2, rfi1_wren, open, open, open, open,
                    rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr, rfi2_wrdata, open,
                    rfi2_ren1, rfi2_ren2, rfi2_wren, open, open, open, open,
                    rfo1_data1, rfo1_data2, vgnd(7 downto 0), vgnd(7 downto 0),
                    rfo2_data1, rfo2_data2, vgnd(7 downto 0), vgnd(7 downto 0));
      end generate;
      pipe1 : if pipe = 1 generate
        grlfpw0 : grlfpw_p1_unisim
          port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
                    cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
                    cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
                    cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
                    cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
                    cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
                    cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
                    vgnd(0), vgnd(0), vgnd(7 downto 0), vgnd(0),
                    cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn,
                    open, cpo_dbg_data, open,
                    rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, open,
                    rfi1_ren1, rfi1_ren2, rfi1_wren, open, open, open, open,
                    rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr, rfi2_wrdata, open,
                    rfi2_ren1, rfi2_ren2, rfi2_wren, open, open, open, open,
                    rfo1_data1, rfo1_data2, vgnd(7 downto 0), vgnd(7 downto 0),
                    rfo2_data1, rfo2_data2, vgnd(7 downto 0), vgnd(7 downto 0));
      end generate;
      pipe2 : if pipe = 2 generate
        grlfpw0 : grlfpw_p2_unisim
          port map (rst, clk, holdn, cpi_flush, cpi_exack, cpi_a_rs1, cpi_d_pc,
                    cpi_d_inst, cpi_d_cnt, cpi_d_trap, cpi_d_annul, cpi_d_pv, cpi_a_pc,
                    cpi_a_inst, cpi_a_cnt, cpi_a_trap, cpi_a_annul, cpi_a_pv, cpi_e_pc,
                    cpi_e_inst, cpi_e_cnt, cpi_e_trap, cpi_e_annul, cpi_e_pv, cpi_m_pc,
                    cpi_m_inst, cpi_m_cnt, cpi_m_trap, cpi_m_annul, cpi_m_pv, cpi_x_pc,
                    cpi_x_inst, cpi_x_cnt, cpi_x_trap, cpi_x_annul, cpi_x_pv, cpi_lddata,
                    cpi_dbg_enable, cpi_dbg_write, cpi_dbg_fsr, cpi_dbg_addr, cpi_dbg_data,
                    vgnd(0), vgnd(0), vgnd(7 downto 0), vgnd(0),
                    cpo_data, cpo_exc, cpo_cc, cpo_ccv, cpo_ldlock, cpo_holdn,
                    open, cpo_dbg_data, open,
                    rfi1_rd1addr, rfi1_rd2addr, rfi1_wraddr, rfi1_wrdata, open,
                    rfi1_ren1, rfi1_ren2, rfi1_wren, open, open, open, open,
                    rfi2_rd1addr, rfi2_rd2addr, rfi2_wraddr, rfi2_wrdata, open,
                    rfi2_ren1, rfi2_ren2, rfi2_wren, open, open, open, open,
                    rfo1_data1, rfo1_data2, vgnd(7 downto 0), vgnd(7 downto 0),
                    rfo2_data1, rfo2_data2, vgnd(7 downto 0), vgnd(7 downto 0));
      end generate;
    end generate;
  end generate;
    

end;

