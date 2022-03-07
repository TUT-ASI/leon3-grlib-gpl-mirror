------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-- Entity:      grdmac2_acc
-- File:        grdmac2_acc.vhd
-- Author:      Sarah Sundberg - Cobham Gaisler AB
-- Description: Interface between GRDMAC2 and accelerator.
------------------------------------------------------------------------------ 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.grdmac2_pkg.all;
library techmap;
use techmap.gencomp.all;

entity grdmac2_acc is
  generic (
    dbits      : integer range 32 to 128  := 32;  -- Bus master front end data
                                                  -- width and FIFO width
    bm_bytes   : integer range 4 to 16    := 4;   -- bus master data width in bytes
    buff_bytes : integer range 4 to 16384 := 32;  -- FIFO size in bytes
    buff_depth : integer range 1 to 1024  := 16;  -- FIFO depth
    abits      : integer range 0 to 10    := 4;   -- FIFO address bits (actual fifo depth = 2**abits))
    acc_enable : integer range 0 to 4     := 0
    );
  port (
    rstn        : in  std_ulogic;           -- Active low reset
    clk         : in  std_ulogic;           -- Clock
    ctrl_rst    : in  std_ulogic;
    d_des_in    : in  data_dsc_strct_type;  -- Data descriptor needs to executed
    acc_des_in  : in  acc_dsc_strct_type;
    acc_start   : in  std_ulogic;           -- Start control signal
    acc_resume  : in  std_ulogic;           -- Resume control signal
    acc_status  : out d_ex_sts_out_type;
    m2b_status  : in  d_ex_sts_out_type;
    endian      : in  std_logic;
    -- Error signal from FIFO
    buf_in      : in  fifo_out_type;        -- FIFO output signals
    buf_out     : out fifo_in_type          -- Input to FIFO
  );
end entity grdmac2_acc;

architecture rtl of grdmac2_acc is

  -- AES_256_ACC
  component aes256_top is
    generic (
      dbits      : integer range 32 to 128  := 32;
      buff_bytes : integer range 4 to 16384 := 32
      );
    port (
      rstn        : in  std_ulogic;
      clk         : in  std_ulogic;
      ctrl_rst    : in  std_ulogic;
      d_des_in    : in  data_dsc_strct_type;
      acc_des_in  : in  acc_dsc_strct_type;
      acc_start   : in  std_ulogic;
      acc_resume  : in  std_ulogic;
      acc_status  : out d_ex_sts_out_type;
      m2b_status  : in  d_ex_sts_out_type;
      endian      : in  std_logic;
      buf_in      : in  fifo_out_type;
      buf_out     : out fifo_in_type
          );
  end component;

  -- SHA_256_ACC
  component sha256_top is
    generic (
      dbits      : integer range 32 to 128  := 32;
      buff_bytes : integer range 4 to 16384 := 32
      );
    port (
      rstn        : in  std_ulogic;
      clk         : in  std_ulogic;
      ctrl_rst    : in  std_ulogic;
      d_des_in    : in  data_dsc_strct_type;
      acc_des_in  : in  acc_dsc_strct_type;
      acc_start   : in  std_ulogic;
      acc_resume  : in  std_ulogic;
      acc_status  : out d_ex_sts_out_type;
      m2b_status  : in  d_ex_sts_out_type;
      endian      : in  std_logic;
      buf_in      : in  fifo_out_type;
      buf_out     : out fifo_in_type
          );
  end component;

  signal aes_status : d_ex_sts_out_type;
  signal aes_buf_out : fifo_in_type;
  
  signal sha_status : d_ex_sts_out_type;
  signal sha_buf_out : fifo_in_type;

  signal temp_status : d_ex_sts_out_type;
  signal temp_buf_out : fifo_in_type;

begin

  -- binding logic
  temp_status.m2b_err   <= aes_status.m2b_err when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else '0';
  temp_status.b2m_err   <= aes_status.b2m_err when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else '0';
  temp_status.state     <= aes_status.state when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else (others => '0');
  temp_status.paused    <= aes_status.paused when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else '0';
  temp_status.operation <= aes_status.operation when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else '0';
  temp_status.comp      <= aes_status.comp when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else '0';
  temp_status.fifo_err  <= aes_status.fifo_err when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else '0';
  temp_buf_out.clr_n    <= aes_buf_out.clr_n when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else '0';
  temp_buf_out.ren      <= aes_buf_out.ren when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else '0';
  temp_buf_out.wen      <= aes_buf_out.wen when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else '0';
  temp_buf_out.wdata    <= aes_buf_out.wdata when ((acc_enable = 1) or (acc_enable = 3 and (d_des_in.ctrl.desc_type = X"4" or d_des_in.ctrl.desc_type = X"5"))) else (others => '0');

  acc_status.m2b_err    <= sha_status.m2b_err when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_status.m2b_err;
  acc_status.b2m_err    <= sha_status.b2m_err when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_status.b2m_err;
  acc_status.state      <= sha_status.state when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_status.state;
  acc_status.paused     <= sha_status.paused when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_status.paused;
  acc_status.operation  <= sha_status.operation when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_status.operation;
  acc_status.comp       <= sha_status.comp when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_status.comp;
  acc_status.fifo_err   <= sha_status.fifo_err when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_status.fifo_err;
  buf_out.clr_n         <= sha_buf_out.clr_n when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_buf_out.clr_n ;
  buf_out.ren           <= sha_buf_out.ren when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_buf_out.ren;
  buf_out.wen           <= sha_buf_out.wen when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_buf_out.wen;
  buf_out.wdata         <= sha_buf_out.wdata when ((acc_enable = 2) or (acc_enable = 3 and d_des_in.ctrl.desc_type = X"6")) else temp_buf_out.wdata;

  generate_aes256_acc: if (acc_enable = 1 or acc_enable = 3) generate
  -- AES256 ACCELERATOR
  aes256_acc : aes256_top
  generic map (
    dbits => dbits,
    buff_bytes => buff_bytes
  )
  port map (
    rstn => rstn,
    clk => clk,
    ctrl_rst => ctrl_rst,
    d_des_in => d_des_in,
    acc_des_in => acc_des_in,
    acc_start => acc_start,
    acc_resume => acc_resume,
    acc_status => aes_status,
    m2b_status => m2b_status,
    endian => endian,
    buf_in => buf_in,
    buf_out => aes_buf_out
  );
  end generate generate_aes256_acc;

  generate_sha256_acc: if (acc_enable = 2 or acc_enable = 3) generate
  -- SHA256 ACCELERATOR
  sha256_acc : sha256_top
  generic map (
    dbits => dbits,
    buff_bytes => buff_bytes
  )
  port map (
    rstn => rstn,
    clk => clk,
    ctrl_rst => ctrl_rst,
    d_des_in => d_des_in,
    acc_des_in => acc_des_in,
    acc_start => acc_start,
    acc_resume => acc_resume,
    acc_status => sha_status,
    m2b_status => m2b_status,
    endian => endian,
    buf_in => buf_in,
    buf_out => sha_buf_out
  );
  end generate generate_sha256_acc;



-- pragma translate_off
     assert acc_generic_check(dbits,abits,acc_enable)
        report "grdmac2: buffer width must be 128 bits or larger when acc_en = 1, and must be 512 bits or larger when acc_en = 2 or acc_en = 3!"
        severity failure;
-- pragma translate_on

  
end architecture rtl;
