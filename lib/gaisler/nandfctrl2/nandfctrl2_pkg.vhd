------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
-- Description: NAND flash memory controller 2 package
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.stdlib.all;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;

library techmap;
use techmap.gencomp.all;

library gaisler;

package nandfctrl2_pkg is

  -----------------------------------------------------------------------------
  -- Constant declarations.
  -----------------------------------------------------------------------------

  -- Maximum sizes for generics.
  constant MAX_CE       : integer := 64;
  constant MAX_CHANNELS : integer := 16;
  constant MAX_RB       : integer := 32;
  constant MAX_SEFI     : integer := 32;

  -- Timing parameters counter, 500ns for some parameters = 9 bits + 2 for 4 Ghz
  constant DCNT_BITS    : integer := 16;

  -----------------------------------------------------------------------------
  -- NANDFCTRL2 TO PHY INTERFACE
  -----------------------------------------------------------------------------

  type flash_data_8bits_bus_type  is array (max_channels-1 downto 0) of std_logic_vector(7 downto 0);
  type flash_data_16bits_bus_type is array (max_channels-1 downto 0) of std_logic_vector(15 downto 0);
  type skew_ctrl_tx_type is array (9 downto 0) of std_logic_vector(2 downto 0);
  type skew_ctrl_rx_type is array (8 downto 0) of std_logic_vector(2 downto 0);

  type ifsel_t is (
    sdr_e,
    ddr_e,
    ddr2_e,
    ddr3_e
  );

  type nf2_to_phy_in_type is record
    abort       : std_ulogic;
    testen      : std_ulogic;
    testrst     : std_ulogic;

    ifsel       : ifsel_t;
    t_dqsh      : std_logic_vector(DCNT_BITS - 1 downto 0);
    t_dqsl      : std_logic_vector(DCNT_BITS - 1 downto 0);
    t_reh       : std_logic_vector(DCNT_BITS - 1 downto 0);
    t_rp        : std_logic_vector(DCNT_BITS - 1 downto 0);

    skew_ctrl_rx : skew_ctrl_rx_type;
    skew_ctrl_tx : skew_ctrl_tx_type;

    ce_n        : std_logic_vector(MAX_CE-1 downto 0);

    ale         : std_logic_vector(MAX_CHANNELS-1 downto 0);
    cle         : std_logic_vector(MAX_CHANNELS-1 downto 0);
    datao       : flash_data_16bits_bus_type;
    dataoe      : std_logic_vector(MAX_CHANNELS-1 downto 0);
    ddr_mde     : std_logic_vector(MAX_CHANNELS-1 downto 0);
    ddr_valid   : std_logic_vector(MAX_CHANNELS-1 downto 0);
    dqso        : std_logic_vector(MAX_CHANNELS-1 downto 0);
    dqsoe       : std_logic_vector(MAX_CHANNELS-1 downto 0);
    re_n        : std_logic_vector(MAX_CHANNELS-1 downto 0);
    we_n        : std_logic_vector(MAX_CHANNELS-1 downto 0);
    wp_n        : std_logic_vector(MAX_CHANNELS-1 downto 0);

    sefi_flag   : std_logic_vector(MAX_RB-1 downto 0);
  end record;

  constant NF2_TO_PHY_IN_NONE : nf2_to_phy_in_type := (
    abort       => '0',
    testen      => '0',
    testrst     => '0',

    ifsel       => sdr_e,
    t_dqsh      => (others => '0'),
    t_dqsl      => (others => '0'),
    t_reh       => (others => '0'),
    t_rp        => (others => '0'),

    skew_ctrl_rx => (others => (others => '0')),
    skew_ctrl_tx => (others => (others => '0')),

    ce_n        => (others => '0'),

    ale         => (others => '0'),
    cle         => (others => '0'),
    datao       => (others => (others => '0')),
    dataoe      => (others => '0'),
    ddr_mde     => (others => '0'),
    ddr_valid   => (others => '0'),
    dqso        => (others => '0'),
    dqsoe       => (others => '0'),
    re_n        => (others => '0'),
    we_n        => (others => '0'),
    wp_n        => (others => '0'),

    sefi_flag   => (others => '0'));

  type nf2_to_phy_out_type is record
    phy_ready   : std_logic;

    datai       : flash_data_16bits_bus_type;
    datai_valid : std_logic_vector(max_channels-1 downto 0);
    dqsi        : std_logic_vector(max_channels-1 downto 0);

    rb_n        : std_logic_vector(max_rb-1 downto 0);
  end record;
  constant NF2_TO_PHY_OUT_NONE : nf2_to_phy_out_type := (
    phy_ready   => '0',
    datai       => (others => (others => '0')),
    datai_valid => (others => '0'),
    dqsi        => (others => '0'),
    rb_n        => (others => '0'));


  -----------------------------------------------------------------------------
  -- Types for phy to pads
  -----------------------------------------------------------------------------
  -- note that dq and dqs inouts are not included in these types.

  type from_nandf_pads_type is record
    rb_n      : std_logic_vector(MAX_RB-1 downto 0);
    dq        : flash_data_8bits_bus_type;
    dqs       : std_logic_vector(MAX_CHANNELS-1 downto 0);
  end record;

  type to_nandf_pads_type is record
    ce_n      : std_logic_vector(MAX_CE-1 downto 0);
    ale       : std_logic_vector(MAX_CHANNELS-1 downto 0);
    cle       : std_logic_vector(MAX_CHANNELS-1 downto 0);
    dq        : flash_data_8bits_bus_type;
    dq_oe     : std_logic_vector(MAX_CHANNELS-1 downto 0);
    dqs       : std_logic_vector(MAX_CHANNELS-1 downto 0);
    dqs_oe    : std_logic_vector(MAX_CHANNELS-1 downto 0);
    re_n      : std_logic_vector(MAX_CHANNELS-1 downto 0);
    we_n      : std_logic_vector(MAX_CHANNELS-1 downto 0);
    wp_n      : std_logic_vector(MAX_CHANNELS-1 downto 0);
    sefi_flag : std_logic_vector(MAX_SEFI-1 downto 0);
  end record;




  -----------------------------------------------------------------------------
  -- Component declarations.
  -----------------------------------------------------------------------------

  component nandfctrl2
    generic (
    hindex       : integer                         := 0;
    pindex       : integer                         := 0;
    pirq         : integer                         := 0;
    paddr        : integer                         := 0;
    pmask        : integer                         := 16#FFE#;
    ahbbits      : integer range 32 to 256         := AHBDW;

    memtech_uldl : integer range 0 to NTECH        := inferred;
    memtech_ecc0 : integer range 0 to NTECH        := inferred;
    memtech_ecc1 : integer range 0 to NTECH        := inferred;
    tech         : integer range 0 to NTECH        := inferred;

    nrofce       : integer range 1 to MAX_CE       :=     8;
    nrofch       : integer range 1 to MAX_CHANNELS :=     8;
    nrofrb       : integer range 1 to MAX_RB       :=     8;
    rnd          : integer range 0 to MAX_SEFI     :=     1;

    mem0_data    : integer range 0 to 32768        := 16384;
    mem0_spare   : integer range 0 to 8192         :=  2208;
    mem0_ecc_sel : integer range 0 to 1            :=     0;

    mem1_data    : integer range 0 to 32768        :=  8192;
    mem1_spare   : integer range 0 to 8192         :=   448;
    mem1_ecc_sel : integer range 0 to 1            :=     1;

    mem2_data    : integer range 0 to 32768        :=  4096;
    mem2_spare   : integer range 0 to 8192         :=   224;
    mem2_ecc_sel : integer range 0 to 1            :=     1;

    ecc0_gfsize  : integer range 0 to 31           :=    14;
    ecc0_chunk   : integer range 1 to 1024         :=  1024;
    ecc0_cap     : integer range 0 to 60           :=    60;

    ecc1_gfsize  : integer range 0 to 31           :=    13;
    ecc1_chunk   : integer range 1 to 1024         :=   512;
    ecc1_cap     : integer range 0 to 60           :=    16;

    rst_cycles   : integer range 0 to 200          :=    10;

    ft           : integer range 0 to 7            :=     0;
    scantest     : integer range 0 to 1            :=     0;

    oepol        : integer range 0 to 1            :=     0
    );

    port (
      rstn        : in  std_logic;
      clk_sys     : in  std_logic;

      core_rstn   : in std_ulogic;
      clk_core    : in std_ulogic;

      apbi        : in  apb_slv_in_type;
      apbo        : out apb_slv_out_type;

      ahbmi       : in  ahb_mst_in_type;
      ahbmo       : out ahb_mst_out_type;

      phyi        : in  nf2_to_phy_out_type;
      phyo        : out nf2_to_phy_in_type
    );
  end component;


  component nandfctrl2_nvddr2_phy_generic is
    generic(
      NROFCE       : integer range 1 to MAX_CE       := 8;
      NROFCH       : integer range 1 to MAX_CHANNELS := 8;
      NROFRB       : integer range 1 to MAX_RB       := 8;
      NROFSEFI     : integer range 0 to MAX_SEFI     := 1;
      SCANTEST     : integer range 0 to 1            := 0;
      SKEW_RX_MAX  : integer range 0 to 7            := 7;
      SKEW_TX_MAX  : integer range 0 to 7            := 7;
      SYNC_STAGES  : integer range 0 to 3            := 2
      );
    port(
      rstn_core : in  std_logic;
      rstn_phy  : in  std_logic;
      clk_core  : in  std_logic;
      clk_phy   : in  std_logic;

      -- nandfctrl2
      nf2i      : in  nf2_to_phy_in_type;
      nf2o      : out nf2_to_phy_out_type;

      -- nand flash memory
      nandfi    : in  from_nandf_pads_type;
      nandfo    : out to_nandf_pads_type
      );
  end component;


  component nandfctrl2_sdr_phy_generic is
    generic(
      NROFCE      : integer range 1 to MAX_CE       := 8;
      NROFCH      : integer range 1 to MAX_CHANNELS := 8;
      NROFRB      : integer range 1 to MAX_RB       := 8;
      NROFSEFI    : integer range 0 to MAX_SEFI     := 1;
      SCANTEST    : integer range 0 to 1            := 0;
      SYNC_STAGES : integer range 0 to 3            := 0
      );
    port(
      rstn_core : in  std_logic;
      clk_core  : in  std_logic;

      -- nandfctrl2
      nf2i      : in  nf2_to_phy_in_type;
      nf2o      : out nf2_to_phy_out_type;

      -- nand flash memory
      nandfi    : in  from_nandf_pads_type;
      nandfo    : out to_nandf_pads_type
      );
  end component;

end package nandfctrl2_pkg;


-------------------------------------------------------------------------------
-- Body
-------------------------------------------------------------------------------

package body nandfctrl2_pkg is

end package body nandfctrl2_pkg;
