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
-------------------------------------------------------------------------------
-- Entity:      ddr4ram
-- File:        ddr4ram.vhd
-- Author:      Andrea Merlo - Cobham Gaisler AB
-- Description: DDR4 System Verilog Model Wrapper.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.all;

entity ddr4ram is
  generic(
    dq_bits             : natural := 8
    );
  port(
    ddr4_ck             : in    std_logic_vector(1 downto 0);
    ddr4_addr           : in    std_logic_vector(13 downto 0);
    ddr4_we_n           : in    std_logic;
    ddr4_cas_n          : in    std_logic;
    ddr4_ras_n          : in    std_logic;
    ddr4_alert_n        : out   std_logic;
    ddr4_parity         : in    std_logic;
    ddr4_reset_n        : in    std_logic;
    ddr4_ten            : in    std_logic;
    ddr4_ba             : in    std_logic_vector(1 downto 0);
    ddr4_cke            : in    std_logic;
    ddr4_cs_n           : in    std_logic;
    ddr4_dm_n           : inout std_logic_vector(7 downto 0);
    ddr4_dq             : inout std_logic_vector(63 downto 0);
    ddr4_dqs_c          : inout std_logic_vector(7 downto 0);
    ddr4_dqs_t          : inout std_logic_vector(7 downto 0);
    ddr4_odt            : in    std_logic;
    ddr4_bg             : in    std_logic_vector(0 downto 0);
    ddr4_act_n          : in    std_logic
    );
end; 

architecture rtl of ddr4ram is

  component DDR4_if
    generic(
      CONFIGURED_DQ_BITS  : natural
      );
    port(
      CK        : in    std_logic_vector(1 downto 0);
      ACT_n     : in    std_logic;
      RAS_n_A16 : in    std_logic;
      CAS_n_A15 : in    std_logic;
      WE_n_A14  : in    std_logic;
      ALERT_n   : out   std_logic;
      PARITY    : in    std_logic;
      RESET_n   : in    std_logic;
      TEN       : in    std_logic;
      CS_n      : in    std_logic;
      CKE       : in    std_logic;
      ODT       : in    std_logic;
      C         : in    std_logic_vector(2 downto 0);
      BG        : in    std_logic_vector(0 downto 0);
      BA        : in    std_logic_vector(1 downto 0);
      ADDR      : in    std_logic_vector(13 downto 0);
      ADDR_17   : in    std_logic;
      DM_n      : in    std_logic_vector(7 downto 0);
      DQ        : inout std_logic_vector(63 downto 0);
      DQS_t     : inout std_logic_vector(7 downto 0);
      DQS_c     : inout std_logic_vector(7 downto 0);
      ZQ        : in    std_logic;
      PWR       : in    std_logic;
      VREF_CA   : in    std_logic;
      VREF_DQ   : in    std_logic
      );  
  end component DDR4_if;

begin

  ddr4_interface : DDR4_IF
    generic map (
      CONFIGURED_DQ_BITS        => 8
      )
    port map (
    ck          => ddr4_ck,
    act_n       => ddr4_act_n,
    ras_n_a16   => ddr4_ras_n,
    cas_n_a15   => ddr4_cas_n,
    we_n_a14    => ddr4_we_n,
    alert_n     => ddr4_alert_n,
    parity      => ddr4_parity,
    reset_n     => ddr4_reset_n,
    ten         => ddr4_ten,
    cs_n        => ddr4_cs_n,
    cke         => ddr4_cke,
    odt         => ddr4_odt,
    c           => "000",
    bg          => ddr4_bg,
    ba          => ddr4_ba,
    addr        => ddr4_addr,
    addr_17     => '0',
    dm_n        => ddr4_dm_n,
    dq          => ddr4_dq,
    dqs_t       => ddr4_dqs_t,
    dqs_c       => ddr4_dqs_c,
    zq          => '0',
    pwr         => '0',
    vref_ca     => '0',
    vref_dq     => '0'
    );
  
end;
