------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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
------------------------------------------------------------------------------
-- Package:     canfd
-- File:	canfd.vhd
-- Author:      Joaquin Espana Navarro - Cobham Gaisler AB
-- Description: Package for GRCANFD and GRCANFD_CODEC
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
library techmap;
use techmap.gencomp.all;

package canfd is

  -------------------------------------------------------------------------------
  -- Types and records
  -------------------------------------------------------------------------------

  type canfd_in_type is record
    rx : std_logic_vector(1 downto 0);  -- RX bit (2 lines)
  end record;

  type canfd_out_type is record
    tx : std_logic_vector(1 downto 0);  -- TX bit (2 lines)
    en : std_logic_vector(1 downto 0);  -- TX lines enable
  end record;

  type grcanfd_defcfg_type is record
    -- General configuration
    en_codec   : std_ulogic;                    -- Enable CAN-FD codec
    line_sel   : std_ulogic;                    -- CAN bus selection
    en_out0    : std_ulogic;                    -- TX output 0 enable (external transceiver)
    en_out1    : std_ulogic;                    -- TX output 1 enable (external transceiver)
    -- CAN nominal bit time parameters
    nom_presc  : std_logic_vector(7 downto 0);  -- Prescaler
    nom_ph1    : std_logic_vector(5 downto 0);  -- Prop + Ph1 segments
    nom_ph2    : std_logic_vector(4 downto 0);  -- Ph2 segment
    nom_sjw    : std_logic_vector(4 downto 0);  -- Synchronization Jump Width
    -- CANOpen parameters
    en_canopen : std_ulogic;                    -- Enable CANOpen mode
    node_id    : std_logic_vector(6 downto 0);  -- Node ID for CANOpen communication
  end record;

  constant GRCANFD_CFG_NULL : grcanfd_defcfg_type := (
    line_sel   => '0',
    en_out0    => '0',
    en_out1    => '0',
    en_codec   => '0',
    nom_presc  => (others => '0'),
    nom_ph1    => (others => '0'),
    nom_ph2    => (others => '0'),
    nom_sjw    => (others => '0'),
    en_canopen => '0',
    node_id    => (others => '1')
    );

  type grcanfd_bm_in_type is record
    -- Read channel
    rd_data      : std_logic_vector(127 downto 0);
    rd_req_grant : std_logic;
    rd_valid     : std_logic;
    rd_done      : std_logic;
    rd_err       : std_logic;
    -- Write channel
    wr_req_grant : std_logic;
    wr_full      : std_logic;
    wr_done      : std_logic;
    wr_err       : std_logic;
    -- Endianness
    endian       : std_logic;
  end record;

  type grcanfd_bm_out_type is record
    -- Read channel
    rd_addr : std_logic_vector(31 downto 0);
    rd_size : std_logic_vector(4 downto 0);
    rd_req  : std_logic;
    -- Write channel
    wr_addr : std_logic_vector(31 downto 0);
    wr_size : std_logic_vector(4 downto 0);
    wr_req  : std_logic;
    wr_data : std_logic_vector(127 downto 0);
  end record;

  type grcanfd_bm_in_vector_type is array (natural range <>) of grcanfd_bm_in_type;
  type grcanfd_bm_out_vector_type is array (natural range <>) of grcanfd_bm_out_type;

  type grcanfd_int_msg_type is record
    start      : std_ulogic;
    id         : std_logic_vector(28 downto 0);
    ide        : std_ulogic;
    rtr        : std_ulogic;
    fdf        : std_ulogic;
    brs        : std_ulogic;
    dlc        : std_logic_vector(3 downto 0);
    data       : std_logic_vector(7 downto 0);  -- Exchange at byte-level
    data_valid : std_ulogic;
  end record;

  constant GRCANFD_INT_MSG_RST : grcanfd_int_msg_type := (
    start      => '0',
    id         => (others => '1'),      -- The lowest priority
    ide        => '0',                  -- Base Format
    rtr        => '0',                  -- No Remote Frame
    fdf        => '0',                  -- Classical Frame
    brs        => '0',                  -- Don't switch to data bit-rate
    dlc        => (others => '0'),      -- No data bytes
    data       => (others => '0'),
    data_valid => '0'
    );


  -------------------------------------------------------------------------------
  -- Components
  -------------------------------------------------------------------------------

  component grcanfd_codec is
    generic (
      scantest : integer range 0 to 1 := 0);
    port (
      clk               : in  std_ulogic;
      rstn              : in  std_ulogic;
      ---- Configuration/control interface ----
      -- Nominal bit rate (FD enabled)
      nom_presc_quant   : in  std_logic_vector(7 downto 0);
      nom_prop_ph1_seg  : in  std_logic_vector(5 downto 0);
      nom_ph2_seg       : in  std_logic_vector(4 downto 0);
      nom_sync_jmp_wdt  : in  std_logic_vector(4 downto 0);
      -- Data bit rate (FD enabled)
      data_presc_quant  : in  std_logic_vector(7 downto 0);
      data_prop_ph1_seg : in  std_logic_vector(3 downto 0);
      data_ph2_seg      : in  std_logic_vector(3 downto 0);
      data_sync_jmp_wdt : in  std_logic_vector(3 downto 0);
      -- Transmitter delay compensation (FD only)
      txdelcomp_en      : in  std_ulogic;
      txdelcomp_val     : in  std_logic_vector(5 downto 0);
      -- Loopback mode
      loopback          : in  std_ulogic;
      -- Restart operation (bus-off)
      restart_req       : in  std_ulogic;
      -- Flow control
      overload_req      : in  std_ulogic;
      ---- Internal message interface ----
      -- TX
      tx_msg            : in  grcanfd_int_msg_type;
      next_data_req     : out std_ulogic;
      tx_busy           : out std_ulogic;
      tx_complete       : out std_ulogic;
      -- RX
      rx_msg            : out grcanfd_int_msg_type;
      rx_complete       : out std_ulogic;
      ---- Status interface ----
      arb_lost          : out std_ulogic;
      bus_off           : out std_ulogic;
      err_passive       : out std_ulogic;
      tx_err_cnt        : out std_logic_vector(7 downto 0);
      rx_err_cnt        : out std_logic_vector(7 downto 0);
      ---- CAN interface ----
      can_sp            : out std_ulogic;
      can_tx_bit        : out std_ulogic;
      can_rx_bit        : in  std_ulogic;
      ---- Scan test ----
      testen            : in  std_ulogic := '0';
      testrst           : in  std_ulogic := '0'
      );
  end component grcanfd_codec;

  component grcanfd
    generic (
      tech      : integer := inferred;
      pindex    : integer := 0;
      paddr     : integer := 0;
      pmask     : integer := 16#FFC#;
      pirq      : integer := 1;
      singleirq : integer := 0;
      txbufsize : integer := 2;
      rxbufsize : integer := 2;
      ft        : integer := 0;
      scantest  : integer := 0;
      canopen   : integer := 0;
      sepbus    : integer := 0);
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      -- Generic bus master interface
      bmi      : in  grcanfd_bm_in_vector_type(canopen*sepbus downto 0);
      bmo      : out grcanfd_bm_out_vector_type(canopen*sepbus downto 0);
      -- APB interface
      apbi     : in  apb_slv_in_type;
      apbo     : out apb_slv_out_type;
      -- CAN interface
      cani     : in  canfd_in_type;
      cano     : out canfd_out_type;
      -- Default IP configuration
      cfg      : in  grcanfd_defcfg_type
      );
  end component grcanfd;

  component grcanfd_ahb
    generic (
      tech        : integer := inferred;
      hindex      : integer := 0;
      pindex      : integer := 0;
      paddr       : integer := 0;
      pmask       : integer := 16#FFC#;
      pirq        : integer := 1;
      singleirq   : integer := 0;
      txbufsize   : integer := 2;
      rxbufsize   : integer := 2;
      ft          : integer := 0;
      scantest    : integer := 0;
      canopen     : integer := 0;
      sepbus      : integer := 0;
      hindexcopen : integer := 0;
      ahbbits     : integer := AHBDW);
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      ahbmi    : in  ahb_mst_in_vector_type(canopen*sepbus downto 0);
      ahbmo    : out ahb_mst_out_vector_type(canopen*sepbus downto 0);
      apbi     : in  apb_slv_in_type;
      apbo     : out apb_slv_out_type;
      cani     : in  canfd_in_type;
      cano     : out canfd_out_type;
      cfg      : in  grcanfd_defcfg_type
      );
  end component grcanfd_ahb;

end package canfd;
