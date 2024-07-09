------------------------------------------------------------------------------
--  Wrapper for SerDes (MPCS) IP instantiations for the CertusPro on the
--  GR740-MINI board.
--  Copyright (C) 2023 Frontgrade Gaisler
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
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;

library gaisler;
use gaisler.hssl.all;
use gaisler.misc.rstgen;

entity serdes_wrapper is
  generic (
    -- See config.vhd for details about these parameters
    EN_SD0 : integer range 0 to 1;
    EN_SD2 : integer range 0 to 1;
    EN_SD6 : integer range 0 to 1;
    EN_SD7 : integer range 0 to 1;
    SDQ0_REFCLK : integer range 0 to 2;
    SDQ1_REFCLK : integer range 0 to 2);
  port ( 
   clk : in std_ulogic;
   rstn : in std_ulogic;
   hssl_clk : out std_ulogic_vector(0 to EN_SD0+EN_SD2+EN_SD6+EN_SD7-1);
   hssl_rstn : out std_ulogic_vector(0 to EN_SD0+EN_SD2+EN_SD6+EN_SD7-1);
   hssli : out grhssl_in_type_vector(0 to EN_SD0+EN_SD2+EN_SD6+EN_SD7-1);
   hsslo : in grhssl_out_type_vector(0 to EN_SD0+EN_SD2+EN_SD6+EN_SD7-1);
   --
   --en_sdq0_refclk : out std_ulogic;
   --en_sdq1_refclk : out std_ulogic

   sdq0_use_refmux  : in std_logic;
   sdq0_extsel      : in std_logic;
   sdq1_use_refmux  : in std_logic;
   sdq1_extsel      : in std_logic
   --pragma translate_off
   ;
   --- Quad 0 ---
   -- Quad-local reference clock
   SDQ0_REFCLKP  : in std_logic; -- connects to SDQ1_REFCLK on board.
   SDQ0_REFCLKN  : in std_logic; -- HCSL, 156.25MHz. Enabled by en_sdq0
   -- channel 0
   SD0_TXDP : out std_logic; -- FMC_FPGA.SD.DP3_C2M_P/N
   SD0_TXDN : out std_logic;
   SD0_RXDP : in  std_logic; -- FMC_FPGA.SD.DP3_M2C_P/N
   SD0_RXDN : in  std_logic;
   -- channel 1 unused
   -- channel 2
   SD2_TXDP : out std_logic; -- FMC_FPGA.SD.DP1_C2M_P/N
   SD2_TXDN : out std_logic;
   SD2_RXDP : in  std_logic; -- FMC_FPGA.SD.DP1_M2C_P/N
   SD2_RXDN : in  std_logic;
   -- channel 3 unused
   -- Distributable reference clock from quad 0
   SD_EXT0_REFCLKP : in std_logic; -- FMC_FPGA_SD.GBTCLK1_M2C_P/N
   SD_EXT0_REFCLKN : in std_logic; -- driven by FMC

   SDQ1_REFCLKP  : in std_logic; -- connects to SDQ1_REFCLK on board.
   SDQ1_REFCLKN  : in std_logic; -- HCSL, 156.25MHz. Enabled by en_sdq0
   -- channels 4 and 5 unused
   -- channel 6
   SD6_TXDP : out std_logic; -- FMC_FPGA.SD.DP2_C2M_P/N
   SD6_TXDN : out std_logic;
   SD6_RXDP : in  std_logic; -- FMC_FPGA.SD.DP2_M2C_P/N
   SD6_RXDN : in  std_logic;
   -- channel 7
   SD7_TXDP : out std_logic; -- FMC_FPGA.SD.DP0_C2M_P/N
   SD7_TXDN : out std_logic;
   SD7_RXDP : in  std_logic; -- FMC_FPGA.SD.DP0_M2C_P/N
   SD7_RXDN : in  std_logic;
   -- Distributable reference clock from quad 1
   SD_EXT1_REFCLKP : in std_logic; -- FMC_FPGA_SD.GBTCLK0_M2C_P/N
   SD_EXT1_REFCLKN : in std_logic  -- driven by FMC
   --pragma translate_on
   );
end;

architecture rtl of serdes_wrapper is

  constant IDX_SD0 : integer := -1      + EN_SD0;
  constant IDX_SD2 : integer := IDX_SD0 + EN_SD2;
  constant IDX_SD6 : integer := IDX_SD2 + EN_SD6;
  constant IDX_SD7 : integer := IDX_SD6 + EN_SD7;
  constant NUM_CHANNELS : integer := IDX_SD7 + 1;

  constant IS_SIMULATION : integer := 0
  --pragma translate_off
                                      +1
  --pragma translate_on
                                      ;
  -- HSSL SerDes
  type epcs_if_type is record
    txclk  : std_logic;
    rxclk  : std_logic;
    txdata : std_logic_vector(79 downto 0);
    rxdata : std_logic_vector(79 downto 0);
    txval  : std_logic;
    rxval  : std_logic;
    phyrdy : std_logic;
    ready  : std_logic;
  end record;
  
  type epcs_if_arr_type is array (natural range <>) of epcs_if_type;

  signal epcs            : epcs_if_arr_type(0 to NUM_CHANNELS-1);
  signal sd_ext_0_refclk : std_logic;
  signal sd_ext_1_refclk : std_logic;

  -- Reference clock selection
  --signal sdq0_use_refmux : std_logic;
  --signal sdq0_extsel     : std_logic;
  --signal sdq1_use_refmux : std_logic;
  --signal sdq1_extsel     : std_logic;

  signal lsdq0_refclkp : std_logic;
  signal lsdq0_refclkn : std_logic;
  signal lsd0_txdp : std_logic;
  signal lsd0_txdn : std_logic;
  signal lsd0_rxdp : std_logic;
  signal lsd0_rxdn : std_logic;
  signal lsd2_txdp : std_logic;
  signal lsd2_txdn : std_logic;
  signal lsd2_rxdp : std_logic;
  signal lsd2_rxdn : std_logic;
  signal lsd_ext0_refclkp : std_logic;
  signal lsd_ext0_refclkn : std_logic;
  signal lsdq1_refclkp  : std_logic;
  signal lsdq1_refclkn  : std_logic;
  signal lsd6_txdp : std_logic;
  signal lsd6_txdn : std_logic;
  signal lsd6_rxdp : std_logic;
  signal lsd6_rxdn : std_logic;
  signal lsd7_txdp : std_logic;
  signal lsd7_txdn : std_logic;
  signal lsd7_rxdp : std_logic;
  signal lsd7_rxdn : std_logic;
  signal lsd_ext1_refclkp : std_logic;
  signal lsd_ext1_refclkn : std_logic;
  
  
  component DIFFCLKIO is
    generic (
      TERM_RD   : string := "ENABLED";
      WEAK_BIAS : string := "DISABLED");
    port (
      CLKIN0_P : in  std_logic;
      CLKIN0_N : in  std_logic;
      CLKIN1_P : in  std_logic;
      CLKIN1_N : in  std_logic;
      CLKOUT0  : out std_logic;
      CLKOUT1  : out std_logic
      );
  end component;

  component serdes_channel_0 is
    port(
        use_refmux_i: in std_logic;
        diffioclksel_i: in std_logic;
        clksel_i: in std_logic_vector(1 downto 0);
        sdq_refclkp_q0_i: in std_logic;
        sdq_refclkn_q0_i: in std_logic;
        sdq_refclkp_q1_i: in std_logic;
        sdq_refclkn_q1_i: in std_logic;
        sd_ext_0_refclk_i: in std_logic;
        sd_ext_1_refclk_i: in std_logic;
        pll_0_refclk_i: in std_logic;
        pll_1_refclk_i: in std_logic;
        sd_pll_refclk_i: in std_logic;
        acjtag_mode_i: in std_logic;
        acjtag_enable_i_0: in std_logic;
        acjtag_acmode_i_0: in std_logic;
        acjtag_drive1_i_0: in std_logic;
        acjtag_highz_i_0: in std_logic;
        acjtagpout_o_0: out std_logic;
        acjtagnout_o_0: out std_logic;
        lmmi_clk_i_0: in std_logic;
        lmmi_resetn_i_0: in std_logic;
        lmmi_request_i_0: in std_logic;
        lmmi_wr_rdn_i_0: in std_logic;
        lmmi_offset_i_0: in std_logic_vector(8 downto 0);
        lmmi_wdata_i_0: in std_logic_vector(7 downto 0);
        lmmi_rdata_valid_o_0: out std_logic;
        lmmi_ready_o_0: out std_logic;
        lmmi_rdata_o_0: out std_logic_vector(7 downto 0);
        sd0rxp_i: in std_logic;
        sd0rxn_i: in std_logic;
        sd0txp_o: out std_logic;
        sd0txn_o: out std_logic;
        sd0_rext_i: in std_logic;
        sd0_refret_i: in std_logic;
        epcs_rx_usr_clk_i_0: in std_logic;
        epcs_tx_usr_clk_i_0: in std_logic;
        epcs_tx_pcs_rstn_i_0: in std_logic;
        epcs_rx_pcs_rstn_i_0: in std_logic;
        epcs_rstn_i_0: in std_logic;
        epcs_rxclk_o_0: out std_logic;
        epcs_txclk_o_0: out std_logic;
        epcs_txdata_i_0: in std_logic_vector(79 downto 0);
        epcs_rxdata_o_0: out std_logic_vector(79 downto 0);
        epcs_clkin_i_0: in std_logic;
        epcs_pwrdn_i_0: in std_logic_vector(1 downto 0);
        epcs_txhiz_i_0: in std_logic;
        epcs_rxidle_o_0: out std_logic;
        epcs_rxerr_i_0: in std_logic;
        epcs_fomreq_i_0: in std_logic;
        epcs_fomack_o_0: out std_logic;
        epcs_fomrslt_o_0: out std_logic_vector(7 downto 0);
        epcs_rate_i_0: in std_logic_vector(1 downto 0);
        epcs_speed_o_0: out std_logic_vector(1 downto 0);
        epcs_txval_i_0: in std_logic;
        epcs_phyrdy_o_0: out std_logic;
        epcs_ready_o_0: out std_logic;
        epcs_rxoob_i_0: in std_logic;
        epcs_txdeemp_i_0: in std_logic;
        epcs_pwrst_o_0: out std_logic_vector(1 downto 0);
        epcs_skipbit_i_0: in std_logic;
        epcs_rxval_o_0: out std_logic
    );
  end component;

  component serdes_channel_2 is
    port(
        use_refmux_i: in std_logic;
        diffioclksel_i: in std_logic;
        clksel_i: in std_logic_vector(1 downto 0);
        sdq_refclkp_q0_i: in std_logic;
        sdq_refclkn_q0_i: in std_logic;
        sdq_refclkp_q1_i: in std_logic;
        sdq_refclkn_q1_i: in std_logic;
        sd_ext_0_refclk_i: in std_logic;
        sd_ext_1_refclk_i: in std_logic;
        pll_0_refclk_i: in std_logic;
        pll_1_refclk_i: in std_logic;
        sd_pll_refclk_i: in std_logic;
        acjtag_mode_i: in std_logic;
        acjtag_enable_i_0: in std_logic;
        acjtag_acmode_i_0: in std_logic;
        acjtag_drive1_i_0: in std_logic;
        acjtag_highz_i_0: in std_logic;
        acjtagpout_o_0: out std_logic;
        acjtagnout_o_0: out std_logic;
        lmmi_clk_i_0: in std_logic;
        lmmi_resetn_i_0: in std_logic;
        lmmi_request_i_0: in std_logic;
        lmmi_wr_rdn_i_0: in std_logic;
        lmmi_offset_i_0: in std_logic_vector(8 downto 0);
        lmmi_wdata_i_0: in std_logic_vector(7 downto 0);
        lmmi_rdata_valid_o_0: out std_logic;
        lmmi_ready_o_0: out std_logic;
        lmmi_rdata_o_0: out std_logic_vector(7 downto 0);
        sd0rxp_i: in std_logic;
        sd0rxn_i: in std_logic;
        sd0txp_o: out std_logic;
        sd0txn_o: out std_logic;
        sd0_rext_i: in std_logic;
        sd0_refret_i: in std_logic;
        epcs_rx_usr_clk_i_0: in std_logic;
        epcs_tx_usr_clk_i_0: in std_logic;
        epcs_tx_pcs_rstn_i_0: in std_logic;
        epcs_rx_pcs_rstn_i_0: in std_logic;
        epcs_rstn_i_0: in std_logic;
        epcs_rxclk_o_0: out std_logic;
        epcs_txclk_o_0: out std_logic;
        epcs_txdata_i_0: in std_logic_vector(79 downto 0);
        epcs_rxdata_o_0: out std_logic_vector(79 downto 0);
        epcs_clkin_i_0: in std_logic;
        epcs_pwrdn_i_0: in std_logic_vector(1 downto 0);
        epcs_txhiz_i_0: in std_logic;
        epcs_rxidle_o_0: out std_logic;
        epcs_rxerr_i_0: in std_logic;
        epcs_fomreq_i_0: in std_logic;
        epcs_fomack_o_0: out std_logic;
        epcs_fomrslt_o_0: out std_logic_vector(7 downto 0);
        epcs_rate_i_0: in std_logic_vector(1 downto 0);
        epcs_speed_o_0: out std_logic_vector(1 downto 0);
        epcs_txval_i_0: in std_logic;
        epcs_phyrdy_o_0: out std_logic;
        epcs_ready_o_0: out std_logic;
        epcs_rxoob_i_0: in std_logic;
        epcs_txdeemp_i_0: in std_logic;
        epcs_pwrst_o_0: out std_logic_vector(1 downto 0);
        epcs_skipbit_i_0: in std_logic;
        epcs_rxval_o_0: out std_logic
    );
  end component;

  component serdes_channel_6 is
    port(
        use_refmux_i: in std_logic;
        diffioclksel_i: in std_logic;
        clksel_i: in std_logic_vector(1 downto 0);
        sdq_refclkp_q0_i: in std_logic;
        sdq_refclkn_q0_i: in std_logic;
        sdq_refclkp_q1_i: in std_logic;
        sdq_refclkn_q1_i: in std_logic;
        sd_ext_0_refclk_i: in std_logic;
        sd_ext_1_refclk_i: in std_logic;
        pll_0_refclk_i: in std_logic;
        pll_1_refclk_i: in std_logic;
        sd_pll_refclk_i: in std_logic;
        acjtag_mode_i: in std_logic;
        acjtag_enable_i_0: in std_logic;
        acjtag_acmode_i_0: in std_logic;
        acjtag_drive1_i_0: in std_logic;
        acjtag_highz_i_0: in std_logic;
        acjtagpout_o_0: out std_logic;
        acjtagnout_o_0: out std_logic;
        lmmi_clk_i_0: in std_logic;
        lmmi_resetn_i_0: in std_logic;
        lmmi_request_i_0: in std_logic;
        lmmi_wr_rdn_i_0: in std_logic;
        lmmi_offset_i_0: in std_logic_vector(8 downto 0);
        lmmi_wdata_i_0: in std_logic_vector(7 downto 0);
        lmmi_rdata_valid_o_0: out std_logic;
        lmmi_ready_o_0: out std_logic;
        lmmi_rdata_o_0: out std_logic_vector(7 downto 0);
        sd0rxp_i: in std_logic;
        sd0rxn_i: in std_logic;
        sd0txp_o: out std_logic;
        sd0txn_o: out std_logic;
        sd0_rext_i: in std_logic;
        sd0_refret_i: in std_logic;
        epcs_rx_usr_clk_i_0: in std_logic;
        epcs_tx_usr_clk_i_0: in std_logic;
        epcs_tx_pcs_rstn_i_0: in std_logic;
        epcs_rx_pcs_rstn_i_0: in std_logic;
        epcs_rstn_i_0: in std_logic;
        epcs_rxclk_o_0: out std_logic;
        epcs_txclk_o_0: out std_logic;
        epcs_txdata_i_0: in std_logic_vector(79 downto 0);
        epcs_rxdata_o_0: out std_logic_vector(79 downto 0);
        epcs_clkin_i_0: in std_logic;
        epcs_pwrdn_i_0: in std_logic_vector(1 downto 0);
        epcs_txhiz_i_0: in std_logic;
        epcs_rxidle_o_0: out std_logic;
        epcs_rxerr_i_0: in std_logic;
        epcs_fomreq_i_0: in std_logic;
        epcs_fomack_o_0: out std_logic;
        epcs_fomrslt_o_0: out std_logic_vector(7 downto 0);
        epcs_rate_i_0: in std_logic_vector(1 downto 0);
        epcs_speed_o_0: out std_logic_vector(1 downto 0);
        epcs_txval_i_0: in std_logic;
        epcs_phyrdy_o_0: out std_logic;
        epcs_ready_o_0: out std_logic;
        epcs_rxoob_i_0: in std_logic;
        epcs_txdeemp_i_0: in std_logic;
        epcs_pwrst_o_0: out std_logic_vector(1 downto 0);
        epcs_skipbit_i_0: in std_logic;
        epcs_rxval_o_0: out std_logic
    );
  end component;

  component serdes_channel_7 is
    port(
        use_refmux_i: in std_logic;
        diffioclksel_i: in std_logic;
        clksel_i: in std_logic_vector(1 downto 0);
        sdq_refclkp_q0_i: in std_logic;
        sdq_refclkn_q0_i: in std_logic;
        sdq_refclkp_q1_i: in std_logic;
        sdq_refclkn_q1_i: in std_logic;
        sd_ext_0_refclk_i: in std_logic;
        sd_ext_1_refclk_i: in std_logic;
        pll_0_refclk_i: in std_logic;
        pll_1_refclk_i: in std_logic;
        sd_pll_refclk_i: in std_logic;
        acjtag_mode_i: in std_logic;
        acjtag_enable_i_0: in std_logic;
        acjtag_acmode_i_0: in std_logic;
        acjtag_drive1_i_0: in std_logic;
        acjtag_highz_i_0: in std_logic;
        acjtagpout_o_0: out std_logic;
        acjtagnout_o_0: out std_logic;
        lmmi_clk_i_0: in std_logic;
        lmmi_resetn_i_0: in std_logic;
        lmmi_request_i_0: in std_logic;
        lmmi_wr_rdn_i_0: in std_logic;
        lmmi_offset_i_0: in std_logic_vector(8 downto 0);
        lmmi_wdata_i_0: in std_logic_vector(7 downto 0);
        lmmi_rdata_valid_o_0: out std_logic;
        lmmi_ready_o_0: out std_logic;
        lmmi_rdata_o_0: out std_logic_vector(7 downto 0);
        sd0rxp_i: in std_logic;
        sd0rxn_i: in std_logic;
        sd0txp_o: out std_logic;
        sd0txn_o: out std_logic;
        sd0_rext_i: in std_logic;
        sd0_refret_i: in std_logic;
        epcs_rx_usr_clk_i_0: in std_logic;
        epcs_tx_usr_clk_i_0: in std_logic;
        epcs_tx_pcs_rstn_i_0: in std_logic;
        epcs_rx_pcs_rstn_i_0: in std_logic;
        epcs_rstn_i_0: in std_logic;
        epcs_rxclk_o_0: out std_logic;
        epcs_txclk_o_0: out std_logic;
        epcs_txdata_i_0: in std_logic_vector(79 downto 0);
        epcs_rxdata_o_0: out std_logic_vector(79 downto 0);
        epcs_clkin_i_0: in std_logic;
        epcs_pwrdn_i_0: in std_logic_vector(1 downto 0);
        epcs_txhiz_i_0: in std_logic;
        epcs_rxidle_o_0: out std_logic;
        epcs_rxerr_i_0: in std_logic;
        epcs_fomreq_i_0: in std_logic;
        epcs_fomack_o_0: out std_logic;
        epcs_fomrslt_o_0: out std_logic_vector(7 downto 0);
        epcs_rate_i_0: in std_logic_vector(1 downto 0);
        epcs_speed_o_0: out std_logic_vector(1 downto 0);
        epcs_txval_i_0: in std_logic;
        epcs_phyrdy_o_0: out std_logic;
        epcs_ready_o_0: out std_logic;
        epcs_rxoob_i_0: in std_logic;
        epcs_txdeemp_i_0: in std_logic;
        epcs_pwrst_o_0: out std_logic_vector(1 downto 0);
        epcs_skipbit_i_0: in std_logic;
        epcs_rxval_o_0: out std_logic
    );
  end component;
  
begin
  -- Reference clock selection for each quad
  -- NOTE: extsel is DONTCARE when use_refmux=0.
  --sdq0_use_refmux <= '0' when SDQ0_REFCLK = 0 else '1';
  --sdq0_extsel <= '1' when SDQ0_REFCLK = 2 else '0';
  --en_sdq0_refclk <= '1';-- when (SDQ0_REFCLK = 0) and (EN_SD0 + EN_SD2 /= 0) else '0';
  
  --sdq1_use_refmux <= '0' when SDQ1_REFCLK = 0 else '1';
  --sdq1_extsel <= '1' when SDQ1_REFCLK = 2 else '0';
  --en_sdq1_refclk <= '1';-- when (SDQ1_REFCLK = 0) and (EN_SD6 + EN_SD7 /= 0) else '0';
  
  -- connection between spacefibre and the serdes
  epcsmap : for i in 0 to NUM_CHANNELS-1 generate
    hssli(i).rx_clk    <= epcs(i).rxclk;
    hssli(i).rx_data   <= epcs(i).rxdata(39 downto 0);
    hssli(i).rx_kflags <= (others => '0');  -- unused (8b10b encoding in the ip)
    hssli(i).rx_serror <= (others => '0');  -- unused
    hssli(i).no_signal <= not (epcs(i).ready and epcs(i).rxval);

    epcs(i).txdata <= zero128(79 downto 40) & hsslo(i).tx_data;
    epcs(i).txval  <= epcs(i).ready;

    -- Drive out TX clock for each channel (drives much of the GRSPFI
    -- IP core)
    hssl_clk(i) <= epcs(i).txclk;
    -- Generate synchronous reset for the HSSL TX clock domain
    rst_hssl : rstgen
      generic map (acthigh => 0)
      port map (
        rstin => rstn,
        clk => epcs(i).txclk,
        clklock => epcs(i).phyrdy,
        rstout => hssl_rstn(i),
        rstoutraw => open);
  end generate;

  --pragma translate_off
  sim_gen : if IS_SIMULATION /= 0 generate
    lsdq0_refclkp <= SDQ0_REFCLKP;
    lsdq0_refclkn <= SDQ0_REFCLKN;
    SD0_TXDP <= lsd0_txdp;
    SD0_TXDN <= lsd0_txdn;
    lsd0_rxdp <= SD0_RXDP;
    lsd0_rxdn <= SD0_RXDN;
    SD2_TXDP <= lsd2_txdp;
    SD2_TXDN <= lsd2_txdn;
    lsd2_rxdp <= SD2_RXDP;
    lsd2_rxdn <= SD2_RXDN;
    lsd_ext0_refclkp <= SD_EXT0_REFCLKP;
    lsd_ext0_refclkn <= SD_EXT0_REFCLKN;

    lsdq1_refclkp <= SDQ1_REFCLKP;
    lsdq1_refclkn <= SDQ1_REFCLKN;
    SD6_TXDP <= lsd6_txdp;
    SD6_TXDN <= lsd6_txdn;
    lsd6_rxdp <= SD6_RXDP;
    lsd6_rxdn <= SD6_RXDN;
    SD7_TXDP <= lsd7_txdp;
    SD7_TXDN <= lsd7_txdn;
    lsd7_rxdp <= SD7_RXDP;
    lsd7_rxdn <= SD7_RXDN;
    lsd_ext1_refclkp <= SD_EXT1_REFCLKP;
    lsd_ext1_refclkn <= SD_EXT1_REFCLKN;
  end generate;
  --pragma translate_on

  nosim_gen : if IS_SIMULATION = 0 generate
    lsdq0_refclkp <= '0';
    lsdq0_refclkn <= '0';
    lsd0_rxdp <= '0';
    lsd0_rxdn <= '0';
    lsd2_rxdp <= '0';
    lsd2_rxdn <= '0';
    lsd_ext0_refclkp <= '0';
    lsd_ext0_refclkn <= '0';
    lsdq1_refclkp <= '0';
    lsdq1_refclkn <= '0';
    lsd6_rxdp <= '0';
    lsd6_rxdn <= '0';
    lsd7_rxdp <= '0';
    lsd7_rxdn <= '0';
    lsd_ext1_refclkp <= '0';
    lsd_ext1_refclkn <= '0';    
  end generate;
  
  -- serdes external reference clock pads
  -- Refer to section 6.6 "Reference Clock" in the SerDes/PCS user guide. See also section
  -- 5.5. "Reference Clock Architecture".
  refclk : diffclkio
    port map (
      clkin0_p => lsd_ext0_refclkp,
      clkin0_n => lsd_ext0_refclkn,
      clkin1_p => lsd_ext1_refclkp,
      clkin1_n => lsd_ext1_refclkn,
      clkout0  => sd_ext_0_refclk,
      clkout1  => sd_ext_1_refclk);

  -- certuspro serdes
  hssl_sd0_gen : if EN_SD0 /= 0 generate
    hssl_sd0 : serdes_channel_0
      port map( 
        -- NOTE: The clock source is individually configurable for each quad
        --       but all channels in a quad must use the same clock.
        use_refmux_i => sdq0_use_refmux, -- use quad-local clock or refmux
        diffioclksel_i => sdq0_extsel,  -- select between sdq0_ext and sdq1_ext
        clksel_i => "10", -- refmux source is external refclk
        -- Clock connections are the same for all channels. They must be because each serdes channel
        -- instantiation references all clock inputs of all quads.
        sdq_refclkp_q0_i     => lsdq0_refclkp, -- quad 0 local refclk input
        sdq_refclkn_q0_i     => lsdq0_refclkn,
        sdq_refclkp_q1_i     => lsdq1_refclkp, -- quad 1 local refclk input
        sdq_refclkn_q1_i     => lsdq1_refclkn,
        sd_ext_0_refclk_i    => sd_ext_0_refclk, -- quad 0 global refclk input
        sd_ext_1_refclk_i    => sd_ext_1_refclk, -- quad 1 global refclk input
        pll_0_refclk_i       => '0', -- input for clock from GPLL0. unused
        pll_1_refclk_i       => '0', -- input for clock from GPLL1. unused
        sd_pll_refclk_i      => '0', -- input for fabric clock (only for test). unused
        -- 
        acjtag_mode_i        => '0',  -- acjtag controller not used and kept in reset
        acjtag_enable_i_0    => '0',
        acjtag_acmode_i_0    => '0',
        acjtag_drive1_i_0    => '0',
        acjtag_highz_i_0     => '0',
        acjtagpout_o_0       => open,
        acjtagnout_o_0       => open,
        
        -- TODO: Connect diagnostic readout/reconfiguration port (APB?)
        -- This is a per-lane/channel interface.
        lmmi_clk_i_0         => '0',  -- register interface not used (static configuration)
        lmmi_resetn_i_0      => '0',  -- register interface kept in reset
        lmmi_request_i_0     => '0',
        lmmi_wr_rdn_i_0      => '0',
        lmmi_offset_i_0      => (others => '0'),
        lmmi_wdata_i_0       => (others => '0'),
        lmmi_rdata_valid_o_0 => open,
        lmmi_ready_o_0       => open,
        lmmi_rdata_o_0       => open,

        -- Only for simulation?
        sd0rxp_i             => lsd0_rxdp,
        sd0rxn_i             => lsd0_rxdn,
        sd0txp_o             => lsd0_txdp,
        sd0txn_o             => lsd0_txdn,
        sd0_rext_i           => '0', -- shouldn't these be connected?
        sd0_refret_i         => '0',
        
        --
        epcs_rx_usr_clk_i_0  => epcs(IDX_SD0).rxclk,
        epcs_tx_usr_clk_i_0  => epcs(IDX_SD0).txclk,
        epcs_tx_pcs_rstn_i_0 => rstn,
        epcs_rx_pcs_rstn_i_0 => rstn,
        epcs_rstn_i_0        => rstn,
        epcs_rxclk_o_0       => epcs(IDX_SD0).rxclk,
        epcs_txclk_o_0       => epcs(IDX_SD0).txclk,
        epcs_txdata_i_0      => epcs(IDX_SD0).txdata,
        epcs_rxdata_o_0      => epcs(IDX_SD0).rxdata,
        epcs_clkin_i_0       => clk, -- slow speed clock (100-300 mhz) to drive the calibration
        epcs_pwrdn_i_0       => "00", -- powerdown never enabled
        epcs_txhiz_i_0       => '0',
        epcs_rxidle_o_0      => open,
        epcs_rxerr_i_0       => '0',
        epcs_fomreq_i_0      => '0',
        epcs_fomack_o_0      => open,
        epcs_fomrslt_o_0     => open,
        epcs_rate_i_0        => "00", -- fixed rate
        epcs_speed_o_0       => open,
        epcs_txval_i_0       => epcs(IDX_SD0).txval,
        epcs_phyrdy_o_0      => epcs(IDX_SD0).phyrdy,
        epcs_ready_o_0       => epcs(IDX_SD0).ready,
        epcs_rxoob_i_0       => '0',
        epcs_txdeemp_i_0     => '0',
        epcs_pwrst_o_0       => open,
        epcs_skipbit_i_0     => '0',
        epcs_rxval_o_0       => epcs(IDX_SD0).rxval);
  end generate;

  hssl_sd2_gen : if EN_SD2 /= 0 generate
    hssl_sd2 : serdes_channel_2
      port map( 
        -- NOTE: The clock source is individually configurable for each quad
        --       but all channels in a quad must use the same clock.
        use_refmux_i => sdq0_use_refmux, -- use quad-local clock or refmux
        diffioclksel_i => sdq0_extsel,  -- select between sdq0_ext and sdq1_ext
        clksel_i => "10", -- refmux source is external refclk
        -- Clock connections are the same for all channels. They must be because each serdes channel
        -- instantiation references all clock inputs of all quads.
        sdq_refclkp_q0_i     => lsdq0_refclkp, -- quad 0 local refclk input
        sdq_refclkn_q0_i     => lsdq0_refclkn,
        sdq_refclkp_q1_i     => lsdq1_refclkp, -- quad 1 local refclk input
        sdq_refclkn_q1_i     => lsdq1_refclkn,
        sd_ext_0_refclk_i    => sd_ext_0_refclk, -- quad 0 global refclk input
        sd_ext_1_refclk_i    => sd_ext_1_refclk, -- quad 1 global refclk input
        pll_0_refclk_i       => '0', -- input for clock from GPLL0. unused
        pll_1_refclk_i       => '0', -- input for clock from GPLL1. unused
        sd_pll_refclk_i      => '0', -- input for fabric clock (only for test). unused
        -- 
        acjtag_mode_i        => '0',  -- acjtag controller not used and kept in reset
        acjtag_enable_i_0    => '0',
        acjtag_acmode_i_0    => '0',
        acjtag_drive1_i_0    => '0',
        acjtag_highz_i_0     => '0',
        acjtagpout_o_0       => open,
        acjtagnout_o_0       => open,
        
        -- TODO: Connect diagnostic readout/reconfiguration port (APB?)
        -- This is a per-lane/channel interface.
        lmmi_clk_i_0         => '0',  -- register interface not used (static configuration)
        lmmi_resetn_i_0      => '0',  -- register interface kept in reset
        lmmi_request_i_0     => '0',
        lmmi_wr_rdn_i_0      => '0',
        lmmi_offset_i_0      => (others => '0'),
        lmmi_wdata_i_0       => (others => '0'),
        lmmi_rdata_valid_o_0 => open,
        lmmi_ready_o_0       => open,
        lmmi_rdata_o_0       => open,
        
        -- Only for simulation?
        sd0rxp_i             => lsd2_rxdp,
        sd0rxn_i             => lsd2_rxdn,
        sd0txp_o             => lsd2_txdp,
        sd0txn_o             => lsd2_txdn,
        sd0_rext_i           => '0', -- shouldn't these be connected?
        sd0_refret_i         => '0',
        
        --
        epcs_rx_usr_clk_i_0  => epcs(IDX_SD2).rxclk,
        epcs_tx_usr_clk_i_0  => epcs(IDX_SD2).txclk,
        epcs_tx_pcs_rstn_i_0 => rstn,
        epcs_rx_pcs_rstn_i_0 => rstn,
        epcs_rstn_i_0        => rstn,
        epcs_rxclk_o_0       => epcs(IDX_SD2).rxclk,
        epcs_txclk_o_0       => epcs(IDX_SD2).txclk,
        epcs_txdata_i_0      => epcs(IDX_SD2).txdata,
        epcs_rxdata_o_0      => epcs(IDX_SD2).rxdata,
        epcs_clkin_i_0       => clk, -- slow speed clock (100-300 mhz) to drive the calibration
        epcs_pwrdn_i_0       => "00", -- powerdown never enabled
        epcs_txhiz_i_0       => '0',
        epcs_rxidle_o_0      => open,
        epcs_rxerr_i_0       => '0',
        epcs_fomreq_i_0      => '0',
        epcs_fomack_o_0      => open,
        epcs_fomrslt_o_0     => open,
        epcs_rate_i_0        => "00", -- fixed rate
        epcs_speed_o_0       => open,
        epcs_txval_i_0       => epcs(IDX_SD2).txval,
        epcs_phyrdy_o_0      => epcs(IDX_SD2).phyrdy,
        epcs_ready_o_0       => epcs(IDX_SD2).ready,
        epcs_rxoob_i_0       => '0',
        epcs_txdeemp_i_0     => '0',
        epcs_pwrst_o_0       => open,
        epcs_skipbit_i_0     => '0',
        epcs_rxval_o_0       => epcs(IDX_SD2).rxval);
  end generate;

  hssl_sd6_gen : if EN_SD6 /= 0 generate
    hssl_sd6 : serdes_channel_6
      port map( 
        -- NOTE: The clock source is individually configurable for each quad
        --       but all channels in a quad must use the same clock.
        use_refmux_i => sdq1_use_refmux, -- use quad-local clock or refmux
        diffioclksel_i => sdq1_extsel,  -- select between sdq0_ext and sdq1_ext
        clksel_i => "10", -- refmux source is external refclk
        -- Clock connections are the same for all channels. They must be because each serdes channel
        -- instantiation references all clock inputs of all quads.
        sdq_refclkp_q0_i     => lsdq0_refclkp, -- quad 0 local refclk input
        sdq_refclkn_q0_i     => lsdq0_refclkn,
        sdq_refclkp_q1_i     => lsdq1_refclkp, -- quad 1 local refclk input
        sdq_refclkn_q1_i     => lsdq1_refclkn,
        sd_ext_0_refclk_i    => sd_ext_0_refclk, -- quad 0 global refclk input
        sd_ext_1_refclk_i    => sd_ext_1_refclk, -- quad 1 global refclk input
        pll_0_refclk_i       => '0', -- input for clock from GPLL0. unused
        pll_1_refclk_i       => '0', -- input for clock from GPLL1. unused
        sd_pll_refclk_i      => '0', -- input for fabric clock (only for test). unused
        -- 
        acjtag_mode_i        => '0',  -- acjtag controller not used and kept in reset
        acjtag_enable_i_0    => '0',
        acjtag_acmode_i_0    => '0',
        acjtag_drive1_i_0    => '0',
        acjtag_highz_i_0     => '0',
        acjtagpout_o_0       => open,
        acjtagnout_o_0       => open,
        
        -- TODO: Connect diagnostic readout/reconfiguration port (APB?)
        -- This is a per-lane/channel interface.
        lmmi_clk_i_0         => '0',  -- register interface not used (static configuration)
        lmmi_resetn_i_0      => '0',  -- register interface kept in reset
        lmmi_request_i_0     => '0',
        lmmi_wr_rdn_i_0      => '0',
        lmmi_offset_i_0      => (others => '0'),
        lmmi_wdata_i_0       => (others => '0'),
        lmmi_rdata_valid_o_0 => open,
        lmmi_ready_o_0       => open,
        lmmi_rdata_o_0       => open,
        
        -- Only for simulation?
        sd0rxp_i             => lsd6_rxdp,
        sd0rxn_i             => lsd6_rxdn,
        sd0txp_o             => lsd6_txdp,
        sd0txn_o             => lsd6_txdn,
        sd0_rext_i           => '0', -- shouldn't these be connected?
        sd0_refret_i         => '0',
        
        --
        epcs_rx_usr_clk_i_0  => epcs(IDX_SD6).rxclk,
        epcs_tx_usr_clk_i_0  => epcs(IDX_SD6).txclk,
        epcs_tx_pcs_rstn_i_0 => rstn,
        epcs_rx_pcs_rstn_i_0 => rstn,
        epcs_rstn_i_0        => rstn,
        epcs_rxclk_o_0       => epcs(IDX_SD6).rxclk,
        epcs_txclk_o_0       => epcs(IDX_SD6).txclk,
        epcs_txdata_i_0      => epcs(IDX_SD6).txdata,
        epcs_rxdata_o_0      => epcs(IDX_SD6).rxdata,
        epcs_clkin_i_0       => clk, -- slow speed clock (100-300 mhz) to drive the calibration
        epcs_pwrdn_i_0       => "00", -- powerdown never enabled
        epcs_txhiz_i_0       => '0',
        epcs_rxidle_o_0      => open,
        epcs_rxerr_i_0       => '0',
        epcs_fomreq_i_0      => '0',
        epcs_fomack_o_0      => open,
        epcs_fomrslt_o_0     => open,
        epcs_rate_i_0        => "00", -- fixed rate
        epcs_speed_o_0       => open,
        epcs_txval_i_0       => epcs(IDX_SD6).txval,
        epcs_phyrdy_o_0      => epcs(IDX_SD6).phyrdy,
        epcs_ready_o_0       => epcs(IDX_SD6).ready,
        epcs_rxoob_i_0       => '0',
        epcs_txdeemp_i_0     => '0',
        epcs_pwrst_o_0       => open,
        epcs_skipbit_i_0     => '0',
        epcs_rxval_o_0       => epcs(IDX_SD6).rxval);
  end generate;

  hssl_sd7_gen : if EN_SD7 /= 0 generate
    hssl_ch7 : serdes_channel_7
      port map( 
        -- NOTE: The clock source is individually configurable for each quad
        --       but all channels in a quad must use the same clock.
        use_refmux_i => sdq1_use_refmux, -- use quad-local clock or refmux
        diffioclksel_i => sdq1_extsel,  -- select between sdq0_ext and sdq1_ext
        clksel_i => "10", -- refmux source is external refclk
        -- Clock connections are the same for all channels. They must be because each serdes channel
        -- instantiation references all clock inputs of all quads.
        sdq_refclkp_q0_i     => lsdq0_refclkp, -- quad 0 local refclk input
        sdq_refclkn_q0_i     => lsdq0_refclkn,
        sdq_refclkp_q1_i     => lsdq1_refclkp, -- quad 1 local refclk input
        sdq_refclkn_q1_i     => lsdq1_refclkn,
        sd_ext_0_refclk_i    => sd_ext_0_refclk, -- quad 0 global refclk input
        sd_ext_1_refclk_i    => sd_ext_1_refclk, -- quad 1 global refclk input
        pll_0_refclk_i       => '0', -- input for clock from GPLL0. unused
        pll_1_refclk_i       => '0', -- input for clock from GPLL1. unused
        sd_pll_refclk_i      => '0', -- input for fabric clock (only for test). unused
        -- 
        acjtag_mode_i        => '0',  -- acjtag controller not used and kept in reset
        acjtag_enable_i_0    => '0',
        acjtag_acmode_i_0    => '0',
        acjtag_drive1_i_0    => '0',
        acjtag_highz_i_0     => '0',
        acjtagpout_o_0       => open,
        acjtagnout_o_0       => open,
        
        -- TODO: Connect diagnostic readout/reconfiguration port (APB?)
        -- This is a per-lane/channel interface.
        lmmi_clk_i_0         => '0',  -- register interface not used (static configuration)
        lmmi_resetn_i_0      => '0',  -- register interface kept in reset
        lmmi_request_i_0     => '0',
        lmmi_wr_rdn_i_0      => '0',
        lmmi_offset_i_0      => (others => '0'),
        lmmi_wdata_i_0       => (others => '0'),
        lmmi_rdata_valid_o_0 => open,
        lmmi_ready_o_0       => open,
        lmmi_rdata_o_0       => open,
        
        -- Only for simulation?
        sd0rxp_i             => lsd7_rxdp,
        sd0rxn_i             => lsd7_rxdn,
        sd0txp_o             => lsd7_txdp,
        sd0txn_o             => lsd7_txdn,
        sd0_rext_i           => '0', -- shouldn't these be connected?
        sd0_refret_i         => '0',
        
        --
        epcs_rx_usr_clk_i_0  => epcs(IDX_SD7).rxclk,
        epcs_tx_usr_clk_i_0  => epcs(IDX_SD7).txclk,
        epcs_tx_pcs_rstn_i_0 => rstn,
        epcs_rx_pcs_rstn_i_0 => rstn,
        epcs_rstn_i_0        => rstn,
        epcs_rxclk_o_0       => epcs(IDX_SD7).rxclk,
        epcs_txclk_o_0       => epcs(IDX_SD7).txclk,
        epcs_txdata_i_0      => epcs(IDX_SD7).txdata,
        epcs_rxdata_o_0      => epcs(IDX_SD7).rxdata,
        epcs_clkin_i_0       => clk, -- slow speed clock (100-300 mhz) to drive the calibration
        epcs_pwrdn_i_0       => "00", -- powerdown never enabled
        epcs_txhiz_i_0       => '0',
        epcs_rxidle_o_0      => open,
        epcs_rxerr_i_0       => '0',
        epcs_fomreq_i_0      => '0',
        epcs_fomack_o_0      => open,
        epcs_fomrslt_o_0     => open,
        epcs_rate_i_0        => "00", -- fixed rate
        epcs_speed_o_0       => open,
        epcs_txval_i_0       => epcs(IDX_SD7).txval,
        epcs_phyrdy_o_0      => epcs(IDX_SD7).phyrdy,
        epcs_ready_o_0       => epcs(IDX_SD7).ready,
        epcs_rxoob_i_0       => '0',
        epcs_txdeemp_i_0     => '0',
        epcs_pwrst_o_0       => open,
        epcs_skipbit_i_0     => '0',
        epcs_rxval_o_0       => epcs(IDX_SD7).rxval);
    end generate;
	 
end rtl;
