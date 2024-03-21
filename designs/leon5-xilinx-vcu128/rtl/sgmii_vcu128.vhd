------------------------------------------------------------------------------
-- ANY USE OR REDISTRIBUTION IN PART OR IN WHOLE MUST BE HANDLED IN
-- ACCORDANCE WITH THE GAISLER LICENSE AGREEMENT AND MUST BE APPROVED
-- IN ADVANCE IN WRITING.
-----------------------------------------------------------------------------
-- Description: SGMII wrapper
------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Description: This is the top level vhdl example design for the
--              Ethernet 1000BASE-X PCS/PMA core.
--
--
--              This design example instantiates IOB flip-flops
--              and input/output buffers on the GMII.
--
--              A Transmitter Elastic Buffer is instantiated on the Tx
--              GMII path to perform clock compenstation between the
--              core and the external MAC driving the Tx GMII.
--
--              This design example can be synthesised.
--
--
--
--    ----------------------------------------------------------------
--    |                             Example Design                   |
--    |                                                              |
--    |             ----------------------------------------------   |
--    |             |           Core Block (wrapper)             |   |
--    |             |                                            |   |
--    |             |   --------------          --------------   |   |
--    |             |   |    Core    |          | tranceiver |   |   |
--    |             |   |            |          |            |   |   |
--    |  ---------  |   |            |          |            |   |   |
--    |  |       |  |   |            |          |            |   |   |
--    |  |  Tx   |  |   |            |          |            |   |   |
--  ---->|Elastic|----->| GMII       |--------->|        TXP |--------->
--    |  |Buffer |  |   | Tx         |          |        TXN |   |   |
--    |  |       |  |   |            |          |            |   |   |
--    |  ---------  |   |            |tranceiver|            |   |   |
--    | GMII        |   |            |    I/F   |            |   |   |
--    | IOBs        |   |            |          |            |   |   |
--    |             |   |            |          |            |   |   |
--    |             |   | GMII       |          |        RXP |   |   |
--  <-------------------| Rx         |<---------|        RXN |<---------
--    |             |   |            |          |            |   |   |
--    |             |   --------------          --------------   |   |
--    |             |                                            |   |
--    |             ----------------------------------------------   |
--    |                                                              |
--    ----------------------------------------------------------------
--
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library gaisler;
use gaisler.net.all;
use gaisler.misc.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;

library techmap;
use techmap.gencomp.all;
use techmap.allclkgen.all;

library eth;
use eth.grethpkg.all;

library unisim;
use unisim.vcomponents.all;

library work;

--------------------------------------------------------------------------------
-- The entity declaration for the example design
--------------------------------------------------------------------------------

entity sgmii_vcu128 is
  generic(
    pindex          : integer := 0;
    paddr           : integer := 0;
    pmask           : integer := 16#fff#;
    abits           : integer := 8;
    autonegotiation : integer := 1;
    pirq            : integer := 0;
    debugmem        : integer := 0;
    tech            : integer := 0;
    simulation      : integer := 0
    );
  port(
    -- Tranceiver Interface
    sgmiii   : in  eth_sgmii_in_type;
    sgmiio   : out eth_sgmii_out_type;
    dummy_nc : in  std_logic;
    -- GMII Interface (client MAC <=> PCS)
    gmiii    : out eth_in_type;
    gmiio    : in  eth_out_type;
    -- Asynchronous reset for entire core.
    reset    : in  std_logic;
    clkout0o : out std_logic;
    clkout1o : out std_logic;
    clkout2o : out std_logic;
    -- APB Status bus
    apb_clk  : in  std_logic;
    apb_rstn : in  std_logic;
    apbi     : in  apb_slv_in_type;
    apbo     : out apb_slv_out_type
    );
end sgmii_vcu128;

architecture top_level of sgmii_vcu128 is

  ------------------------------------------------------------------------------
  -- Component Declaration for the Core Block (core wrapper).
  ------------------------------------------------------------------------------

  COMPONENT sgmii
    PORT (
      sgmii_clk_r_0          : OUT STD_LOGIC;
      sgmii_clk_f_0          : OUT STD_LOGIC;
      sgmii_clk_en_0         : OUT STD_LOGIC;
      clk125_out             : OUT STD_LOGIC;
      clk312_out             : OUT STD_LOGIC;
      rst_125_out            : OUT STD_LOGIC;
      refclk625_n            : IN  STD_LOGIC;
      refclk625_p            : IN  STD_LOGIC;
      speed_is_10_100_0      : IN  STD_LOGIC;
      speed_is_100_0         : IN  STD_LOGIC;
      reset                  : IN  STD_LOGIC;
      txn_0                  : OUT STD_LOGIC;
      rxn_0                  : IN  STD_LOGIC;
      gmii_txd_0             : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
      gmii_rxd_0             : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      txp_0                  : OUT STD_LOGIC;
      gmii_rx_dv_0           : OUT STD_LOGIC;
      gmii_rx_er_0           : OUT STD_LOGIC;
      gmii_isolate_0         : OUT STD_LOGIC;
      rxp_0                  : IN  STD_LOGIC;
      signal_detect_0        : IN  STD_LOGIC;
      gmii_tx_en_0           : IN  STD_LOGIC;
      gmii_tx_er_0           : IN  STD_LOGIC;
      configuration_vector_0 : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
      status_vector_0        : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      an_adv_config_vector_0 : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      an_restart_config_0    : IN  STD_LOGIC;
      an_interrupt_0         : OUT STD_LOGIC;
      tx_dly_rdy_1           : IN  STD_LOGIC;
      rx_dly_rdy_1           : IN  STD_LOGIC;
      tx_vtc_rdy_1           : IN  STD_LOGIC;
      rx_vtc_rdy_1           : IN  STD_LOGIC;
      tx_dly_rdy_2           : IN  STD_LOGIC;
      rx_dly_rdy_2           : IN  STD_LOGIC;
      tx_vtc_rdy_2           : IN  STD_LOGIC;
      rx_vtc_rdy_2           : IN  STD_LOGIC;
      tx_dly_rdy_3           : IN  STD_LOGIC;
      rx_dly_rdy_3           : IN  STD_LOGIC;
      tx_vtc_rdy_3           : IN  STD_LOGIC;
      rx_vtc_rdy_3           : IN  STD_LOGIC;
      tx_logic_reset         : OUT STD_LOGIC;
      rx_logic_reset         : OUT STD_LOGIC;
      rx_locked              : OUT STD_LOGIC;
      tx_locked              : OUT STD_LOGIC;
      tx_bsc_rst_out         : OUT STD_LOGIC;
      rx_bsc_rst_out         : OUT STD_LOGIC;
      tx_bs_rst_out          : OUT STD_LOGIC;
      rx_bs_rst_out          : OUT STD_LOGIC;
      tx_rst_dly_out         : OUT STD_LOGIC;
      rx_rst_dly_out         : OUT STD_LOGIC;
      tx_bsc_en_vtc_out      : OUT STD_LOGIC;
      rx_bsc_en_vtc_out      : OUT STD_LOGIC;
      tx_bs_en_vtc_out       : OUT STD_LOGIC;
      rx_bs_en_vtc_out       : OUT STD_LOGIC;
      riu_clk_out            : OUT STD_LOGIC;
      riu_wr_en_out          : OUT STD_LOGIC;
      tx_pll_clk_out         : OUT STD_LOGIC;
      rx_pll_clk_out         : OUT STD_LOGIC;
      tx_rdclk_out           : OUT STD_LOGIC;
      riu_addr_out           : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      riu_wr_data_out        : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      riu_nibble_sel_out     : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      rx_btval_1             : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
      rx_btval_2             : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
      rx_btval_3             : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
      riu_valid_3            : IN  STD_LOGIC;
      riu_valid_2            : IN  STD_LOGIC;
      riu_valid_1            : IN  STD_LOGIC;
      riu_prsnt_1            : IN  STD_LOGIC;
      riu_prsnt_2            : IN  STD_LOGIC;
      riu_prsnt_3            : IN  STD_LOGIC;
      riu_rddata_3           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      riu_rddata_1           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      riu_rddata_2           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      dummy_port_in          : IN  STD_LOGIC
      );
  END COMPONENT;

----- component IBUFDS_GTE3 -----
  component IBUFDS_GTE3
    port (
      O     : out std_ulogic;
      ODIV2 : out std_ulogic;
      CEB   : in  std_ulogic;
      I     : in  std_ulogic;
      IB    : in  std_ulogic
      );
  end component;

----- component BUFGMUX -----
  component BUFGMUX
    generic (
      CLK_SEL_TYPE : string := "ASYNC"
      );
    port (
      O  : out std_ulogic := '0';
      I0 : in  std_ulogic := '0';
      I1 : in  std_ulogic := '0';
      S  : in  std_ulogic := '0'
      );
  end component;

  constant REVISION : integer := 1;

  constant pconfig : apb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_SGMII, 0, REVISION, pirq),
    1 => apb_iobar(paddr, pmask));

  type sgmiiregs is record
    irq                  : std_logic_vector(31 downto 0);  -- interrupt
    mask                 : std_logic_vector(31 downto 0);  -- interrupt enable
    configuration_vector : std_logic_vector(4 downto 0);
    an_adv_config_vector : std_logic_vector(15 downto 0);
  end record;

  -- APB and SGMII control register
  constant RESET_ALL : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

  constant RES_configuration_vector : std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(autonegotiation, 1)) & "0000";

  constant RES : sgmiiregs :=
    (irq                   => (others => '0'), mask => (others => '0'),
      configuration_vector => RES_configuration_vector, an_adv_config_vector => "0001100000000001");

  type rxregs is record
    gmii_rxd     : std_logic_vector(7 downto 0);
    gmii_rxd_int : std_logic_vector(7 downto 0);
    gmii_rx_dv   : std_logic;
    gmii_rx_er   : std_logic;
    count        : integer;
    gmii_dv      : std_logic;
    keepalive    : integer;
  end record;

  constant RESRX : rxregs :=
    (gmii_rxd    => (others => '0'), gmii_rxd_int => (others => '0'),
      gmii_rx_dv => '0', gmii_rx_er => '0',
      count      => 0, gmii_dv => '0', keepalive => 0
      );

  type txregs is record
    gmii_txd       : std_logic_vector(7 downto 0);
    gmii_txd_int   : std_logic_vector(7 downto 0);
    gmii_tx_en     : std_logic;
    gmii_tx_en_int : std_logic;
    gmii_tx_er     : std_logic;
    count          : integer;
    cnt_en         : std_logic;
    keepalive      : integer;
  end record;

  constant RESTX : txregs :=
    (gmii_txd    => (others => '0'), gmii_txd_int => (others => '0'),
      gmii_tx_en => '0', gmii_tx_en_int => '0', gmii_tx_er => '0',
      count      => 0, cnt_en => '0', keepalive => 0
      );

  ------------------------------------------------------------------------------
  -- internal signals used in this top level example design.
  ------------------------------------------------------------------------------

  -- clock generation signals for tranceiver
  signal gtrefclk    : std_logic;
  --signal txoutclk              : std_logic;
  signal rxoutclk    : std_logic;
  signal resetdone   : std_logic;
  signal mmcm_locked : std_logic;
  signal mmcm_reset  : std_logic;
  signal clkfbout    : std_logic;
  signal clkout0     : std_logic;
  signal clkout1     : std_logic;
  signal userclk     : std_logic;
  signal userclk2    : std_logic;
  signal rxuserclk   : std_logic;

  -- PMA reset generation signals for tranceiver
  signal pma_reset_pipe : std_logic_vector(3 downto 0);
  signal pma_reset      : std_logic;

  -- clock generation signals for SGMII clock
  signal sgmii_clk_r  : std_logic;
  signal sgmii_clk_f  : std_logic;
  signal sgmii_clk_en : std_logic;

  -- GMII signals
  signal gmii_txd     : std_logic_vector(7 downto 0);
  signal gmii_tx_en   : std_logic;
  signal gmii_tx_er   : std_logic;
  signal gmii_rxd     : std_logic_vector(7 downto 0);
  signal gmii_rx_dv   : std_logic;
  signal gmii_rx_er   : std_logic;
  signal gmii_isolate : std_logic;

  -- Internal GMII signals from Xilinx SGMII block
  signal gmii_rxd_int   : std_logic_vector(7 downto 0);
  signal gmii_rx_dv_int : std_logic;
  signal gmii_rx_er_int : std_logic;

  -- Extra registers to ease IOB placement
  signal status_vector_int  : std_logic_vector(15 downto 0);
  signal status_vector_apb  : std_logic_vector(15 downto 0);
  signal status_vector_apb1 : std_logic_vector(31 downto 0);
  signal status_vector_apb2 : std_logic_vector(31 downto 0);

  -- These attributes will stop timing errors being reported in back annotated
  -- SDF simulation.
  attribute ASYNC_REG                   : string;
  attribute ASYNC_REG of pma_reset_pipe : signal is "TRUE";

  -- Configuration register

  signal speed_is_10_100 : std_logic;
  signal speed_is_100    : std_logic;

  signal configuration_vector : std_logic_vector(4 downto 0);

  signal an_interrupt         : std_logic;
  signal an_adv_config_vector : std_logic_vector(15 downto 0);
  signal an_restart_config    : std_logic;

  signal synchronization_done : std_logic;
  signal linkup               : std_logic;
  signal signal_detect        : std_logic;

  -- Route gtrefclk through an IBUFG.
  signal gtrefclk_buf_i : std_logic;

  signal r, rin     : sgmiiregs;
  signal rrx, rinrx : rxregs;
  signal rtx, rintx : txregs;

  signal cnt_en : std_logic;

  signal usr2rstn : std_logic;

  -- debug signal
  signal WMemRgmiioData : std_logic_vector(15 downto 0);
  signal RMemRgmiioData : std_logic_vector(15 downto 0);
  signal RMemRgmiioAddr : std_logic_vector(9 downto 0);
  signal WMemRgmiioAddr : std_logic_vector(9 downto 0);
  signal WMemRgmiioWrEn : std_logic;
  signal WMemRgmiiiData : std_logic_vector(15 downto 0);
  signal RMemRgmiiiData : std_logic_vector(15 downto 0);
  signal RMemRgmiiiAddr : std_logic_vector(9 downto 0);
  signal WMemRgmiiiAddr : std_logic_vector(9 downto 0);
  signal WMemRgmiiiWrEn : std_logic;
  signal RMemRgmiiiRead : std_logic;
  signal RMemRgmiioRead : std_logic;

begin
  -----------------------------------------------------------------------------
  -- Adopted for the vcu128 (Based on the default for the VC707)
  -----------------------------------------------------------------------------

  -- Remove AN during simulation i.e. "00000"
  configuration_vector(4) <= '1';       -- autonegotiation enable
  --configuration_vector(4) <= '0'; -- autonegotiation enable
  configuration_vector(3) <= '0';       -- isolate
  configuration_vector(2) <= '0';       -- power down
  configuration_vector(1) <= '0';       -- loopback enable
  configuration_vector(0) <= '0';       -- unidirectional enable

  -- Configuration for Xilinx SGMII IP. See doc for SGMII IP for more information
  an_adv_config_vector(15)           <= '1';   -- SGMII link status
  an_adv_config_vector(14)           <= '1';   -- SGMII Acknowledge
  an_adv_config_vector(13 downto 12) <= "01";  -- full duplex
  an_adv_config_vector(11 downto 10) <= "10";  -- SGMII speed
  an_adv_config_vector(9)            <= '0';   -- reserved
  an_adv_config_vector(8 downto 7)   <= "00";  -- pause frames - SGMII reserved
  an_adv_config_vector(6)            <= '0';   -- reserved
  an_adv_config_vector(5)            <= '0';   -- full duplex - SGMII reserved
  an_adv_config_vector(4 downto 1)   <= "0000";  -- reserved
  an_adv_config_vector(0)            <= '1';   -- SGMII

  an_restart_config <= '0';

  --  Core Status vector outputs
  synchronization_done <= status_vector_int(1);
  linkup               <= status_vector_int(0);
  signal_detect        <= '1';

  gmiii.gtx_clk  <= userclk2;
  gmiii.tx_clk   <= userclk2;
  gmiii.rx_clk   <= userclk2;
  gmiii.rmii_clk <= userclk2;
  gmiii.rxd      <= gmii_rxd;
  gmiii.rx_dv    <= gmii_rx_dv;
  gmiii.rx_er    <= gmii_rx_er;
  gmiii.rx_en    <= gmii_rx_dv or sgmii_clk_en;

  --gmiii.tx_dv <= '1';
  gmiii.tx_dv <= cnt_en when gmiio.tx_en = '1' else '1';

  -- GMII output controlled via generics
  gmiii.edclsepahb  <= '1';
  gmiii.edcldisable <= '0';
  gmiii.phyrstaddr  <= (others => '0');
  gmiii.edcladdr    <= (others => '0');

  -- Not used
  gmiii.rx_col    <= '0';
  gmiii.rx_crs    <= '0';
  gmiii.tx_clk_90 <= '0';

  -- GMII Ref Clocks Not Used
  -- Note: 50Mhz clock used for 10Mb mode only
  gmiii.tx_clk_100 <= '0';
  gmiii.tx_clk_50  <= '0';
  gmiii.tx_clk_25  <= '0';

  sgmiio.mdio_o  <= gmiio.mdio_o;
  sgmiio.mdio_oe <= gmiio.mdio_oe;
  gmiii.mdio_i   <= sgmiii.mdio_i;
  sgmiio.mdc     <= gmiio.mdc;
  gmiii.mdint    <= sgmiii.mdint;
  sgmiio.reset   <= apb_rstn;

  -----------------------------------------------------------------------------
  -- Transceiver Clock Management
  -----------------------------------------------------------------------------
  -- N/A

  -----------------------------------------------------------------------------
  -- Sync Reset for user clock
  -----------------------------------------------------------------------------

  userclk2_rst : rstgen
    generic map(syncin => 1, syncrst => 1)
    port map(apb_rstn, userclk2, '1', usr2rstn, open);

  -----------------------------------------------------------------------------
  -- Transceiver PMA reset circuitry
  -----------------------------------------------------------------------------

  -- Create a reset pulse of a decent length
  process(reset, apb_clk)
  begin
    if (reset = '1') then
      pma_reset_pipe <= "1111";
    elsif apb_clk'event and apb_clk = '1' then
      pma_reset_pipe <= pma_reset_pipe(2 downto 0) & reset;
    end if;
  end process;

  pma_reset <= pma_reset_pipe(3);

  ------------------------------------------------------------------------------
  -- GMII (Aeroflex Gaisler) to GMII (Xilinx) style
  ------------------------------------------------------------------------------

  -- 10/100Mbit TX Loic
  process (usr2rstn, rtx, gmiio)
    variable v : txregs;
  begin
    v                := rtx;
    v.cnt_en         := '0';
    v.gmii_tx_en_int := gmiio.tx_en;

    if (gmiio.tx_en = '1' and rtx.gmii_tx_en_int = '0') then
      v.count := 0;
    elsif (v.count >= 9) and gmiio.speed = '1' then
      v.count := 0;
    elsif (v.count >= 99) and gmiio.speed = '0' then
      v.count := 0;
    else
      v.count := rtx.count + 1;
    end if;

    case v.count is
      when 0 =>
        v.gmii_txd_int(3 downto 0) := gmiio.txd(3 downto 0);
        v.cnt_en                   := '1';

      when 5 =>
        if gmiio.speed = '1' then
          v.gmii_txd_int(7 downto 4) := gmiio.txd(3 downto 0);
          v.cnt_en                   := '1';
        end if;

      when 50=>
        if gmiio.speed = '0' then
          v.gmii_txd_int(7 downto 4) := gmiio.txd(3 downto 0);
          v.cnt_en                   := '1';
        end if;


      when 9 =>
        if gmiio.speed = '1' then
          v.gmii_txd                              := v.gmii_txd_int;
          v.gmii_tx_en                            := '1';
          v.gmii_tx_er                            := gmiio.tx_er;
          if (gmiio.tx_en = '0' and rtx.keepalive <= 1) then v.gmii_tx_en := '0'; end if;
          if (rtx.keepalive > 0) then v.keepalive := rtx.keepalive - 1; end if;
        end if;

      when 99 =>
        if gmiio.speed = '0' then
          v.gmii_txd                              := v.gmii_txd_int;
          v.gmii_tx_en                            := '1';
          v.gmii_tx_er                            := gmiio.tx_er;
          if (gmiio.tx_en = '0' and rtx.keepalive <= 1) then v.gmii_tx_en := '0'; end if;
          if (rtx.keepalive > 0) then v.keepalive := rtx.keepalive - 1; end if;
        end if;

      when others =>
        null;

    end case;

    if (gmiio.tx_en = '0' and rtx.gmii_tx_en_int = '1') then
      v.keepalive := 2;
    end if;

    if (gmiio.tx_en = '0' and rtx.gmii_tx_en_int = '0' and rtx.keepalive = 0) then
      v := RESTX;
    end if;

    -- reset operation
    if (not RESET_ALL) and (usr2rstn = '0') then
      v := RESTX;
    end if;

    -- update registers
    rintx <= v;
  end process;

  txegs : process(userclk2)
  begin
    if rising_edge(userclk2) then
      rtx <= rintx;
      if RESET_ALL and usr2rstn = '0' then
        rtx <= RESTX;
      end if;
    end if;
  end process;

  -- 1000Mbit TX Logic (Bypass)
  -- n/a

  -- TX Mux Select
  cnt_en <= '1' when (gmiio.gbit = '1') else rtx.cnt_en;

  gmii_txd   <= gmiio.txd   when (gmiio.gbit = '1') else rtx.gmii_txd;
  gmii_tx_en <= gmiio.tx_en when (gmiio.gbit = '1') else rtx.gmii_tx_en;
  gmii_tx_er <= gmiio.tx_er when (gmiio.gbit = '1') else rtx.gmii_tx_er;

  ------------------------------------------------------------------------------
  -- Instantiate the Core Block (core wrapper).
  ------------------------------------------------------------------------------

  speed_is_10_100 <= not gmiio.gbit;
  speed_is_100    <= gmiio.speed;
  --speed_is_10_100 <= '0';
  --speed_is_100    <= '0';

  core_wrapper : sgmii
    port map (
      -- MAC clocking control
      sgmii_clk_r_0          => sgmii_clk_r,
      sgmii_clk_f_0          => sgmii_clk_f,
      sgmii_clk_en_0         => sgmii_clk_en,
      clk125_out             => userclk2,
      clk312_out             => open,
      rst_125_out            => open,
      -- 125 MHz differential reference clock to IBUFDS
      refclk625_n            => sgmiii.clkn,
      refclk625_p            => sgmiii.clkp,
      -- SGMII
      txp_0                  => sgmiio.txp,
      txn_0                  => sgmiio.txn,
      rxp_0                  => sgmiii.rxp,
      rxn_0                  => sgmiii.rxn,
      --
      reset                  => reset,  -- Synced to 125MHz
      -- GMII
      gmii_txd_0             => gmii_txd,
      gmii_rxd_0             => gmii_rxd_int,
      gmii_rx_dv_0           => gmii_rx_dv_int,
      gmii_rx_er_0           => gmii_rx_er_int,
      gmii_isolate_0         => gmii_isolate,
      gmii_tx_en_0           => gmii_tx_en,
      gmii_tx_er_0           => gmii_tx_er,
      -- Configuration
      configuration_vector_0 => configuration_vector,
      an_adv_config_vector_0 => an_adv_config_vector,
      an_restart_config_0    => an_restart_config,
      an_interrupt_0         => an_interrupt,
      -- Speed control
      speed_is_10_100_0      => speed_is_10_100,
      speed_is_100_0         => speed_is_100,
      -- Status
      signal_detect_0        => signal_detect,
      status_vector_0        => status_vector_int,
      tx_dly_rdy_1           => '1',
      rx_dly_rdy_1           => '1',
      tx_vtc_rdy_1           => '1',
      rx_vtc_rdy_1           => '1',
      tx_dly_rdy_2           => '1',
      rx_dly_rdy_2           => '1',
      tx_vtc_rdy_2           => '1',
      rx_vtc_rdy_2           => '1',
      tx_dly_rdy_3           => '1',
      rx_dly_rdy_3           => '1',
      tx_vtc_rdy_3           => '1',
      rx_vtc_rdy_3           => '1',
      tx_logic_reset         => open,
      rx_logic_reset         => open,
      rx_locked              => open,
      tx_locked              => open,
      tx_bsc_rst_out         => open,
      rx_bsc_rst_out         => open,
      tx_bs_rst_out          => open,
      rx_bs_rst_out          => open,
      tx_rst_dly_out         => open,
      rx_rst_dly_out         => open,
      tx_bsc_en_vtc_out      => open,
      rx_bsc_en_vtc_out      => open,
      tx_bs_en_vtc_out       => open,
      rx_bs_en_vtc_out       => open,
      riu_clk_out            => open,
      riu_wr_en_out          => open,
      tx_pll_clk_out         => open,
      rx_pll_clk_out         => open,
      tx_rdclk_out           => open,
      riu_addr_out           => open,
      riu_wr_data_out        => open,
      riu_nibble_sel_out     => open,
      rx_btval_1             => open,
      rx_btval_2             => open,
      rx_btval_3             => open,
      riu_valid_3            => '0',
      riu_valid_2            => '0',
      riu_valid_1            => '0',
      riu_prsnt_1            => '0',
      riu_prsnt_2            => '0',
      riu_prsnt_3            => '0',
      riu_rddata_3           => (others => '0'),
      riu_rddata_1           => (others => '0'),
      riu_rddata_2           => (others => '0'),
      dummy_port_in          => dummy_nc
      );

  ------------------------------------------------------------------------------
  -- GMII (Xilinx) to GMII (Aeroflex Gailers) style
  ------------------------------------------------------------------------------

  ---- 10/100Mbit RX Loic
  process (usr2rstn, rrx, gmii_rx_dv_int, gmii_rxd_int, gmii_rx_er_int, sgmii_clk_en)
    variable v : rxregs;
  begin
    v := rrx;

    if (gmii_rx_dv_int = '1' and sgmii_clk_en = '1') then
      v.count        := 0;
      v.gmii_rxd_int := gmii_rxd_int;
      v.gmii_dv      := '1';
      v.keepalive    := 1;
    elsif (v.count >= 9) and gmiio.speed = '1' then
      v.count     := 0;
      v.keepalive := rrx.keepalive - 1;
    elsif (v.count >= 99) and gmiio.speed = '0' then
      v.count     := 0;
      v.keepalive := rrx.keepalive - 1;
    else
      v.count := rrx.count + 1;
    end if;

    case v.count is
      when 0 =>
        v.gmii_rxd   := v.gmii_rxd_int(3 downto 0) & v.gmii_rxd_int(3 downto 0);
        v.gmii_rx_dv := v.gmii_dv;
      when 5 =>
        if gmiio.speed = '1' then
          v.gmii_rxd   := v.gmii_rxd_int(7 downto 4) & v.gmii_rxd_int(7 downto 4);
          v.gmii_rx_dv := v.gmii_dv;
          v.gmii_dv    := '0';
        end if;
      when 50 =>
        if gmiio.speed = '0' then
          v.gmii_rxd   := v.gmii_rxd_int(7 downto 4) & v.gmii_rxd_int(7 downto 4);
          v.gmii_rx_dv := v.gmii_dv;
          v.gmii_dv    := '0';
        end if;
      when others =>
        v.gmii_rxd   := v.gmii_rxd;
        v.gmii_rx_dv := '0';
    end case;

    v.gmii_rx_er := gmii_rx_er_int;

    if (rrx.keepalive = 0 and gmii_rx_dv_int = '0') then
      v := RESRX;
    end if;

    -- reset operation
    if (not RESET_ALL) and (usr2rstn = '0') then
      v := RESRX;
    end if;

    -- update registers
    rinrx <= v;
  end process;

  rx100regs : process(userclk2)
  begin
    if rising_edge(userclk2) then
      rrx <= rinrx;
      if RESET_ALL and usr2rstn = '0' then
        rrx <= RESRX;
      end if;
    end if;
  end process;

  ---- 1000Mbit RX Logic (Bypass)
  -- n/a

  ---- RX Mux Select
  gmii_rxd   <= gmii_rxd_int   when (gmiio.gbit = '1') else rinrx.gmii_rxd;
  gmii_rx_dv <= gmii_rx_dv_int when (gmiio.gbit = '1') else rinrx.gmii_rx_dv;
  gmii_rx_er <= gmii_rx_er_int when (gmiio.gbit = '1') else rinrx.gmii_rx_er;

--  -----------------------------------------------------------------------------
--  -- Extra registers to ease CDC placement
--  -----------------------------------------------------------------------------
--  process (apb_clk)
--  begin
--    if apb_clk'event and apb_clk = '1' then
--      status_vector_apb <= status_vector_int;
--    end if;
--  end process;
--
--  ---------------------------------------------------------------------------------------
--  -- APB Section
--  ---------------------------------------------------------------------------------------
--
  apbo.pindex  <= pindex;
  apbo.pconfig <= pconfig;
  apbo.prdata  <= (others => '0');
  apbo.pirq    <= (others => '0');
--
--  -- Extra registers to ease CDC placement
--  process (apb_clk)
--  begin
--    if apb_clk'event and apb_clk = '1' then
--      status_vector_apb1 <= (others => '0');
--      status_vector_apb2 <= (others => '0');
--      -- Register to detect a speed change
--      status_vector_apb1(15 downto 0) <= status_vector_apb;
--      status_vector_apb2 <= status_vector_apb1;
--    end if;
--  end process;
--
--  rgmiiapb : process(apb_rstn, r, apbi, status_vector_apb1, status_vector_apb2, RMemRgmiiiData, RMemRgmiiiRead, RMemRgmiioRead )
--    variable rdata    : std_logic_vector(31 downto 0);
--    variable paddress : std_logic_vector(7 downto 2);
--    variable v        : sgmiiregs;
--  begin
--
--    v := r;
--    paddress := (others => '0');
--    paddress(abits-1 downto 2) := apbi.paddr(abits-1 downto 2);
--    rdata := (others => '0');
--
--    -- read/write registers
--
--    if (apbi.psel(pindex) and apbi.penable and (not apbi.pwrite)) = '1' then
--      case paddress(7 downto 2) is
--        when "000000" =>
--          rdata(31 downto 0) := status_vector_apb2;
--        when "000001" =>
--          rdata(31 downto 0) := r.irq;
--          v.irq := (others => '0');  -- Interrupt is clear on read
--        when "000010" =>
--          rdata(31 downto 0) := r.mask;
--        when "000011" =>
--          rdata(4 downto 0) := r.configuration_vector;
--        when "000100" =>
--          rdata(15 downto 0) := r.an_adv_config_vector;
--        when "000101" =>
--          if (autonegotiation /= 0) then rdata(0) := '1'; else rdata(0) := '0'; end if;
--          if (debugmem /= 0)        then rdata(1) := '1'; else rdata(1) := '0'; end if;
--        when others =>
--          null;
--      end case;
--    end if;
--
--    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
--      case paddress(7 downto 2) is
--        when "000000" =>
--          null;
--        when "000001" =>
--          null;
--        when "000010" =>
--          v.mask := apbi.pwdata(31 downto 0);
--        when "000011" =>
--          v.configuration_vector := apbi.pwdata(4 downto 0);
--        when "000100" =>
--          v.an_adv_config_vector := apbi.pwdata(15 downto 0);
--        when "000101" =>
--          null;
--        when others =>
--          null;
--      end case;
--    end if;
--
--    -- Check interrupts
--    for i in 0 to status_vector_apb2'length-1 loop
--      if  ((status_vector_apb1(i) xor status_vector_apb2(i)) and v.mask(i)) = '1' then
--        v.irq(i) :=  '1';
--      end if;
--    end loop;
--
--    -- reset operation
--    if (not RESET_ALL) and (apb_rstn = '0') then
--      v := RES;
--    end if;
--
--    -- update registers
--    rin <= v;
--
--    -- drive outputs
--    if apbi.psel(pindex) = '0' then
--      apbo.prdata  <= (others => '0');
--    elsif RMemRgmiiiRead = '1' then
--      apbo.prdata(31 downto 16)  <= (others => '0');
--      apbo.prdata(15 downto 0)   <= RMemRgmiiiData;
--    elsif RMemRgmiioRead = '1' then
--      apbo.prdata(31 downto 16)  <= (others => '0');
--      apbo.prdata(15 downto 0)   <= RMemRgmiioData;
--    else
--      apbo.prdata  <= rdata;
--    end if;
--
--    apbo.pirq <= (others => '0');
--    apbo.pirq(pirq) <=  orv(v.irq);
--
--  end process;
--
--  regs : process(apb_clk)
--  begin
--    if rising_edge(apb_clk) then
--      r <= rin;
--      if RESET_ALL and apb_rstn = '0' then
--        r <= RES;
--      end if;
--    end if;
--  end process;
--
--  ---------------------------------------------------------------------------------------
--  --  Debug Mem
--  ---------------------------------------------------------------------------------------
--
--  debugmem1 : if (debugmem /= 0) generate
--
--    -- Write GMII IN data
--    process (userclk2)
--    begin  -- process
--      if rising_edge(userclk2) then
--        WMemRgmiioData(15 downto 0) <= '0' & '0' & '0' & sgmii_clk_en & '0' & '0' & gmii_tx_er & gmii_tx_en & gmii_txd;
--        if (gmii_tx_en = '1') and ((WMemRgmiioAddr < "0111111110") or (WMemRgmiioAddr = "1111111111")) then
--          WMemRgmiioAddr <= WMemRgmiioAddr + 1;
--          WMemRgmiioWrEn <= '1';
--        else
--          if (gmii_tx_en = '0') then
--            WMemRgmiioAddr <= (others => '1');
--          else
--            WMemRgmiioAddr <= WMemRgmiioAddr;
--          end if;
--          WMemRgmiioWrEn <= '0';
--        end if;
--
--        if usr2rstn = '0' then
--          WMemRgmiioAddr <= (others => '0');
--          WMemRgmiioWrEn <= '0';
--        end if;
--
--      end if;
--    end process;
--
--    -- Read
--    RMemRgmiioRead <= apbi.paddr(10) and apbi.psel(pindex);
--    RMemRgmiioAddr <= "00" & apbi.paddr(10-1 downto 2);
--
--    gmiii0 : syncram_2p generic map (tech, 10, 16, 1, 0, 0) port map(
--      apb_clk, RMemRgmiioRead, RMemRgmiioAddr, RMemRgmiioData,
--      userclk2, WMemRgmiioWrEn, WMemRgmiioAddr(10-1 downto 0), WMemRgmiioData);
--
--    -- Write GMII IN data
--    process (userclk2)
--    begin  -- process
--      if rising_edge(userclk2) then
--
--        if (gmii_rx_dv = '1') then
--          WMemRgmiiiData(15 downto 0) <= '0' & '0' & '0' &sgmii_clk_en & "00" & gmii_rx_er & gmii_rx_dv & gmii_rxd;
--        elsif (gmii_rx_dv_int = '0') then
--          WMemRgmiiiData(15 downto 0) <= (others => '0');
--        else
--          WMemRgmiiiData <= WMemRgmiiiData;
--        end if;
--
--        if (gmii_rx_dv = '1') and ((WMemRgmiiiAddr < "0111111110") or (WMemRgmiiiAddr = "1111111111")) then
--          WMemRgmiiiAddr <= WMemRgmiiiAddr + 1;
--          WMemRgmiiiWrEn <= '1';
--        else
--          if (gmii_rx_dv_int = '0') then
--            WMemRgmiiiAddr <= (others => '1');
--            WMemRgmiiiWrEn <= '0';
--          else
--            WMemRgmiiiAddr <= WMemRgmiiiAddr;
--            WMemRgmiiiWrEn <= '0';
--          end if;
--        end if;
--
--        if usr2rstn = '0' then
--          WMemRgmiiiAddr <= (others => '0');
--          WMemRgmiiiWrEn <= '0';
--        end if;
--
--      end if;
--    end process;
--
--    -- Read
--    RMemRgmiiiRead <= apbi.paddr(11) and apbi.psel(pindex);
--    RMemRgmiiiAddr <= "00" & apbi.paddr(10-1 downto 2);
--
--    rgmiii0 : syncram_2p generic map (tech, 10, 16, 1, 0, 0) port map(
--      apb_clk, RMemRgmiiiRead, RMemRgmiiiAddr, RMemRgmiiiData,
--      userclk2, WMemRgmiiiWrEn, WMemRgmiiiAddr(10-1 downto 0), WMemRgmiiiData);
--
--  end generate;

  clkout0o <= userclk;
  clkout1o <= rxuserclk;
  clkout2o <= userclk2;

-- pragma translate_off
  bootmsg : report_version
    generic map ("sgmii" & tost(pindex) &
                 ": SGMII rev " & tost(REVISION) & ", irq " & tost(pirq));
-- pragma translate_on

end top_level;
