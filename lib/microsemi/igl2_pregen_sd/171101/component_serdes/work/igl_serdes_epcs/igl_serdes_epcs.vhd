----------------------------------------------------------------------
-- Created by SmartDesign Wed Nov  1 13:15:06 2017
-- Version: v11.8 11.8.0.26
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library smartfusion2;
use smartfusion2.all;
----------------------------------------------------------------------
-- igl_serdes_epcs entity declaration
----------------------------------------------------------------------
entity igl_serdes_epcs is
    -- Port list
    port(
        -- Inputs
        APB_S_PADDR          : in  std_logic_vector(13 downto 2);
        APB_S_PCLK           : in  std_logic;
        APB_S_PENABLE        : in  std_logic;
        APB_S_PRESET_N       : in  std_logic;
        APB_S_PSEL           : in  std_logic;
        APB_S_PWDATA         : in  std_logic_vector(31 downto 0);
        APB_S_PWRITE         : in  std_logic;
        EPCS_3_RESET_N       : in  std_logic;
        EPCS_3_TX_DATA       : in  std_logic_vector(19 downto 0);
        REFCLK1_N            : in  std_logic;
        REFCLK1_P            : in  std_logic;
        RXD0_N               : in  std_logic;
        RXD0_P               : in  std_logic;
        RXD1_N               : in  std_logic;
        RXD1_P               : in  std_logic;
        RXD2_N               : in  std_logic;
        RXD2_P               : in  std_logic;
        RXD3_N               : in  std_logic;
        RXD3_P               : in  std_logic;
        -- Outputs
        APB_S_PRDATA         : out std_logic_vector(31 downto 0);
        APB_S_PREADY         : out std_logic;
        APB_S_PSLVERR        : out std_logic;
        EPCS_3_READY         : out std_logic;
        EPCS_3_RX_CLK        : out std_logic;
        EPCS_3_RX_DATA       : out std_logic_vector(19 downto 0);
        EPCS_3_RX_IDLE       : out std_logic;
        EPCS_3_RX_RESET_N    : out std_logic;
        EPCS_3_RX_VAL        : out std_logic;
        EPCS_3_TX_CLK        : out std_logic;
        EPCS_3_TX_CLK_STABLE : out std_logic;
        EPCS_3_TX_RESET_N    : out std_logic;
        REFCLK1_OUT          : out std_logic;
        TXD0_N               : out std_logic;
        TXD0_P               : out std_logic;
        TXD1_N               : out std_logic;
        TXD1_P               : out std_logic;
        TXD2_N               : out std_logic;
        TXD2_P               : out std_logic;
        TXD3_N               : out std_logic;
        TXD3_P               : out std_logic
        );
end igl_serdes_epcs;
----------------------------------------------------------------------
-- igl_serdes_epcs architecture body
----------------------------------------------------------------------
architecture RTL of igl_serdes_epcs is
----------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------
-- igl_serdes_epcs_SERDES_IF_0_SERDES_IF   -   Actel:SgCore:SERDES_IF:1.2.210
component igl_serdes_epcs_SERDES_IF_0_SERDES_IF
    -- Port list
    port(
        -- Inputs
        APB_S_PADDR          : in  std_logic_vector(13 downto 2);
        APB_S_PCLK           : in  std_logic;
        APB_S_PENABLE        : in  std_logic;
        APB_S_PRESET_N       : in  std_logic;
        APB_S_PSEL           : in  std_logic;
        APB_S_PWDATA         : in  std_logic_vector(31 downto 0);
        APB_S_PWRITE         : in  std_logic;
        EPCS_3_PWRDN         : in  std_logic;
        EPCS_3_RESET_N       : in  std_logic;
        EPCS_3_RX_ERR        : in  std_logic;
        EPCS_3_TX_DATA       : in  std_logic_vector(19 downto 0);
        EPCS_3_TX_OOB        : in  std_logic;
        EPCS_3_TX_VAL        : in  std_logic;
        REFCLK1_N            : in  std_logic;
        REFCLK1_P            : in  std_logic;
        RXD0_N               : in  std_logic;
        RXD0_P               : in  std_logic;
        RXD1_N               : in  std_logic;
        RXD1_P               : in  std_logic;
        RXD2_N               : in  std_logic;
        RXD2_P               : in  std_logic;
        RXD3_N               : in  std_logic;
        RXD3_P               : in  std_logic;
        -- Outputs
        APB_S_PRDATA         : out std_logic_vector(31 downto 0);
        APB_S_PREADY         : out std_logic;
        APB_S_PSLVERR        : out std_logic;
        EPCS_3_READY         : out std_logic;
        EPCS_3_RX_CLK        : out std_logic;
        EPCS_3_RX_DATA       : out std_logic_vector(19 downto 0);
        EPCS_3_RX_IDLE       : out std_logic;
        EPCS_3_RX_RESET_N    : out std_logic;
        EPCS_3_RX_VAL        : out std_logic;
        EPCS_3_TX_CLK        : out std_logic;
        EPCS_3_TX_CLK_STABLE : out std_logic;
        EPCS_3_TX_RESET_N    : out std_logic;
        REFCLK1_OUT          : out std_logic;
        TXD0_N               : out std_logic;
        TXD0_P               : out std_logic;
        TXD1_N               : out std_logic;
        TXD1_P               : out std_logic;
        TXD2_N               : out std_logic;
        TXD2_P               : out std_logic;
        TXD3_N               : out std_logic;
        TXD3_P               : out std_logic
        );
end component;
----------------------------------------------------------------------
-- Signal declarations
----------------------------------------------------------------------
signal APB_SLAVE_PRDATA           : std_logic_vector(31 downto 0);
signal APB_SLAVE_PREADY           : std_logic;
signal APB_SLAVE_PSLVERR          : std_logic;
signal EPCS_3_READY_net_0         : std_logic;
signal EPCS_3_RX_CLK_net_0        : std_logic;
signal EPCS_3_RX_DATA_net_0       : std_logic_vector(19 downto 0);
signal EPCS_3_RX_IDLE_net_0       : std_logic;
signal EPCS_3_RX_RESET_N_net_0    : std_logic;
signal EPCS_3_RX_VAL_net_0        : std_logic;
signal EPCS_3_TX_CLK_net_0        : std_logic;
signal EPCS_3_TX_CLK_STABLE_net_0 : std_logic;
signal EPCS_3_TX_RESET_N_net_0    : std_logic;
signal REFCLK1_OUT_net_0          : std_logic;
signal TXD0_N_net_0               : std_logic;
signal TXD0_P_net_0               : std_logic;
signal TXD1_N_net_0               : std_logic;
signal TXD1_P_net_0               : std_logic;
signal TXD2_N_net_0               : std_logic;
signal TXD2_P_net_0               : std_logic;
signal TXD3_N_net_0               : std_logic;
signal TXD3_P_net_0               : std_logic;
signal TXD0_P_net_1               : std_logic;
signal TXD0_N_net_1               : std_logic;
signal TXD1_P_net_1               : std_logic;
signal TXD1_N_net_1               : std_logic;
signal TXD2_P_net_1               : std_logic;
signal TXD2_N_net_1               : std_logic;
signal TXD3_P_net_1               : std_logic;
signal TXD3_N_net_1               : std_logic;
signal REFCLK1_OUT_net_1          : std_logic;
signal EPCS_3_READY_net_1         : std_logic;
signal EPCS_3_RX_DATA_net_1       : std_logic_vector(19 downto 0);
signal EPCS_3_RX_VAL_net_1        : std_logic;
signal EPCS_3_RX_IDLE_net_1       : std_logic;
signal EPCS_3_TX_CLK_STABLE_net_1 : std_logic;
signal EPCS_3_RX_RESET_N_net_1    : std_logic;
signal EPCS_3_TX_RESET_N_net_1    : std_logic;
signal EPCS_3_RX_CLK_net_1        : std_logic;
signal EPCS_3_TX_CLK_net_1        : std_logic;
signal APB_SLAVE_PREADY_net_0     : std_logic;
signal APB_SLAVE_PRDATA_net_0     : std_logic_vector(31 downto 0);
signal APB_SLAVE_PSLVERR_net_0    : std_logic;
----------------------------------------------------------------------
-- TiedOff Signals
----------------------------------------------------------------------
signal GND_net                    : std_logic;
signal VCC_net                    : std_logic;
signal EPCS_0_TX_DATA_const_net_0 : std_logic_vector(19 downto 0);
signal EPCS_1_TX_DATA_const_net_0 : std_logic_vector(19 downto 0);
signal EPCS_2_TX_DATA_const_net_0 : std_logic_vector(19 downto 0);
signal SGMII_TX_DATA_const_net_0  : std_logic_vector(9 downto 0);
signal AXI_M_BID_const_net_0      : std_logic_vector(3 downto 0);
signal AXI_M_BRESP_const_net_0    : std_logic_vector(1 downto 0);
signal AXI_M_RID_const_net_0      : std_logic_vector(3 downto 0);
signal AXI_M_RDATA_const_net_0    : std_logic_vector(63 downto 0);
signal AXI_M_RRESP_const_net_0    : std_logic_vector(1 downto 0);
signal AXI_S_AWID_const_net_0     : std_logic_vector(3 downto 0);
signal AXI_S_AWADDR_const_net_0   : std_logic_vector(31 downto 0);
signal AXI_S_AWLEN_const_net_0    : std_logic_vector(3 downto 0);
signal AXI_S_AWSIZE_const_net_0   : std_logic_vector(1 downto 0);
signal AXI_S_AWBURST_const_net_0  : std_logic_vector(1 downto 0);
signal AXI_S_AWLOCK_const_net_0   : std_logic_vector(1 downto 0);
signal AXI_S_WID_const_net_0      : std_logic_vector(3 downto 0);
signal AXI_S_WSTRB_const_net_0    : std_logic_vector(7 downto 0);
signal AXI_S_WDATA_const_net_0    : std_logic_vector(63 downto 0);
signal AXI_S_ARID_const_net_0     : std_logic_vector(3 downto 0);
signal AXI_S_ARADDR_const_net_0   : std_logic_vector(31 downto 0);
signal AXI_S_ARLEN_const_net_0    : std_logic_vector(3 downto 0);
signal AXI_S_ARSIZE_const_net_0   : std_logic_vector(1 downto 0);
signal AXI_S_ARBURST_const_net_0  : std_logic_vector(1 downto 0);
signal AXI_S_ARLOCK_const_net_0   : std_logic_vector(1 downto 0);
signal AHB_M_HRDATA_const_net_0   : std_logic_vector(31 downto 0);
signal AHB_S_HADDR_const_net_0    : std_logic_vector(31 downto 0);
signal AHB_S_HBURST_const_net_0   : std_logic_vector(2 downto 0);
signal AHB_S_HSIZE_const_net_0    : std_logic_vector(1 downto 0);
signal AHB_S_HTRANS_const_net_0   : std_logic_vector(1 downto 0);
signal AHB_S_HWDATA_const_net_0   : std_logic_vector(31 downto 0);
signal XAUI_MMD_PRTAD_const_net_0 : std_logic_vector(4 downto 0);
signal XAUI_MMD_DEVID_const_net_0 : std_logic_vector(4 downto 0);
signal XAUI_TXD_const_net_0       : std_logic_vector(63 downto 0);
signal XAUI_TXC_const_net_0       : std_logic_vector(7 downto 0);
signal PCIE_INTERRUPT_const_net_0 : std_logic_vector(3 downto 0);

begin
----------------------------------------------------------------------
-- Constant assignments
----------------------------------------------------------------------
 GND_net                    <= '0';
 VCC_net                    <= '1';
 EPCS_0_TX_DATA_const_net_0 <= B"00000000000000000000";
 EPCS_1_TX_DATA_const_net_0 <= B"00000000000000000000";
 EPCS_2_TX_DATA_const_net_0 <= B"00000000000000000000";
 SGMII_TX_DATA_const_net_0  <= B"0000000000";
 AXI_M_BID_const_net_0      <= B"0000";
 AXI_M_BRESP_const_net_0    <= B"00";
 AXI_M_RID_const_net_0      <= B"0000";
 AXI_M_RDATA_const_net_0    <= B"0000000000000000000000000000000000000000000000000000000000000000";
 AXI_M_RRESP_const_net_0    <= B"00";
 AXI_S_AWID_const_net_0     <= B"0000";
 AXI_S_AWADDR_const_net_0   <= B"00000000000000000000000000000000";
 AXI_S_AWLEN_const_net_0    <= B"0000";
 AXI_S_AWSIZE_const_net_0   <= B"00";
 AXI_S_AWBURST_const_net_0  <= B"00";
 AXI_S_AWLOCK_const_net_0   <= B"00";
 AXI_S_WID_const_net_0      <= B"0000";
 AXI_S_WSTRB_const_net_0    <= B"00000000";
 AXI_S_WDATA_const_net_0    <= B"0000000000000000000000000000000000000000000000000000000000000000";
 AXI_S_ARID_const_net_0     <= B"0000";
 AXI_S_ARADDR_const_net_0   <= B"00000000000000000000000000000000";
 AXI_S_ARLEN_const_net_0    <= B"0000";
 AXI_S_ARSIZE_const_net_0   <= B"00";
 AXI_S_ARBURST_const_net_0  <= B"00";
 AXI_S_ARLOCK_const_net_0   <= B"00";
 AHB_M_HRDATA_const_net_0   <= B"00000000000000000000000000000000";
 AHB_S_HADDR_const_net_0    <= B"00000000000000000000000000000000";
 AHB_S_HBURST_const_net_0   <= B"000";
 AHB_S_HSIZE_const_net_0    <= B"00";
 AHB_S_HTRANS_const_net_0   <= B"00";
 AHB_S_HWDATA_const_net_0   <= B"00000000000000000000000000000000";
 XAUI_MMD_PRTAD_const_net_0 <= B"00000";
 XAUI_MMD_DEVID_const_net_0 <= B"00000";
 XAUI_TXD_const_net_0       <= B"0000000000000000000000000000000000000000000000000000000000000000";
 XAUI_TXC_const_net_0       <= B"00000000";
 PCIE_INTERRUPT_const_net_0 <= B"0000";
----------------------------------------------------------------------
-- Top level output port assignments
----------------------------------------------------------------------
 TXD0_P_net_1                <= TXD0_P_net_0;
 TXD0_P                      <= TXD0_P_net_1;
 TXD0_N_net_1                <= TXD0_N_net_0;
 TXD0_N                      <= TXD0_N_net_1;
 TXD1_P_net_1                <= TXD1_P_net_0;
 TXD1_P                      <= TXD1_P_net_1;
 TXD1_N_net_1                <= TXD1_N_net_0;
 TXD1_N                      <= TXD1_N_net_1;
 TXD2_P_net_1                <= TXD2_P_net_0;
 TXD2_P                      <= TXD2_P_net_1;
 TXD2_N_net_1                <= TXD2_N_net_0;
 TXD2_N                      <= TXD2_N_net_1;
 TXD3_P_net_1                <= TXD3_P_net_0;
 TXD3_P                      <= TXD3_P_net_1;
 TXD3_N_net_1                <= TXD3_N_net_0;
 TXD3_N                      <= TXD3_N_net_1;
 REFCLK1_OUT_net_1           <= REFCLK1_OUT_net_0;
 REFCLK1_OUT                 <= REFCLK1_OUT_net_1;
 EPCS_3_READY_net_1          <= EPCS_3_READY_net_0;
 EPCS_3_READY                <= EPCS_3_READY_net_1;
 EPCS_3_RX_DATA_net_1        <= EPCS_3_RX_DATA_net_0;
 EPCS_3_RX_DATA(19 downto 0) <= EPCS_3_RX_DATA_net_1;
 EPCS_3_RX_VAL_net_1         <= EPCS_3_RX_VAL_net_0;
 EPCS_3_RX_VAL               <= EPCS_3_RX_VAL_net_1;
 EPCS_3_RX_IDLE_net_1        <= EPCS_3_RX_IDLE_net_0;
 EPCS_3_RX_IDLE              <= EPCS_3_RX_IDLE_net_1;
 EPCS_3_TX_CLK_STABLE_net_1  <= EPCS_3_TX_CLK_STABLE_net_0;
 EPCS_3_TX_CLK_STABLE        <= EPCS_3_TX_CLK_STABLE_net_1;
 EPCS_3_RX_RESET_N_net_1     <= EPCS_3_RX_RESET_N_net_0;
 EPCS_3_RX_RESET_N           <= EPCS_3_RX_RESET_N_net_1;
 EPCS_3_TX_RESET_N_net_1     <= EPCS_3_TX_RESET_N_net_0;
 EPCS_3_TX_RESET_N           <= EPCS_3_TX_RESET_N_net_1;
 EPCS_3_RX_CLK_net_1         <= EPCS_3_RX_CLK_net_0;
 EPCS_3_RX_CLK               <= EPCS_3_RX_CLK_net_1;
 EPCS_3_TX_CLK_net_1         <= EPCS_3_TX_CLK_net_0;
 EPCS_3_TX_CLK               <= EPCS_3_TX_CLK_net_1;
 APB_SLAVE_PREADY_net_0      <= APB_SLAVE_PREADY;
 APB_S_PREADY                <= APB_SLAVE_PREADY_net_0;
 APB_SLAVE_PRDATA_net_0      <= APB_SLAVE_PRDATA;
 APB_S_PRDATA(31 downto 0)   <= APB_SLAVE_PRDATA_net_0;
 APB_SLAVE_PSLVERR_net_0     <= APB_SLAVE_PSLVERR;
 APB_S_PSLVERR               <= APB_SLAVE_PSLVERR_net_0;
----------------------------------------------------------------------
-- Component instances
----------------------------------------------------------------------
-- SERDES_IF_0   -   Actel:SgCore:SERDES_IF:1.2.210
SERDES_IF_0 : igl_serdes_epcs_SERDES_IF_0_SERDES_IF
    port map( 
        -- Inputs
        EPCS_3_TX_DATA       => EPCS_3_TX_DATA,
        EPCS_3_PWRDN         => GND_net,
        EPCS_3_TX_VAL        => VCC_net,
        EPCS_3_TX_OOB        => GND_net,
        EPCS_3_RX_ERR        => GND_net,
        EPCS_3_RESET_N       => EPCS_3_RESET_N,
        APB_S_PADDR          => APB_S_PADDR,
        APB_S_PENABLE        => APB_S_PENABLE,
        APB_S_PSEL           => APB_S_PSEL,
        APB_S_PWDATA         => APB_S_PWDATA,
        APB_S_PWRITE         => APB_S_PWRITE,
        APB_S_PRESET_N       => APB_S_PRESET_N,
        APB_S_PCLK           => APB_S_PCLK,
        REFCLK1_P            => REFCLK1_P,
        REFCLK1_N            => REFCLK1_N,
        RXD0_P               => RXD0_P,
        RXD0_N               => RXD0_N,
        RXD1_P               => RXD1_P,
        RXD1_N               => RXD1_N,
        RXD2_P               => RXD2_P,
        RXD2_N               => RXD2_N,
        RXD3_P               => RXD3_P,
        RXD3_N               => RXD3_N,
        -- Outputs
        EPCS_3_READY         => EPCS_3_READY_net_0,
        EPCS_3_RX_DATA       => EPCS_3_RX_DATA_net_0,
        EPCS_3_RX_VAL        => EPCS_3_RX_VAL_net_0,
        EPCS_3_RX_IDLE       => EPCS_3_RX_IDLE_net_0,
        EPCS_3_TX_CLK_STABLE => EPCS_3_TX_CLK_STABLE_net_0,
        EPCS_3_RX_RESET_N    => EPCS_3_RX_RESET_N_net_0,
        EPCS_3_TX_RESET_N    => EPCS_3_TX_RESET_N_net_0,
        EPCS_3_RX_CLK        => EPCS_3_RX_CLK_net_0,
        EPCS_3_TX_CLK        => EPCS_3_TX_CLK_net_0,
        APB_S_PRDATA         => APB_SLAVE_PRDATA,
        APB_S_PREADY         => APB_SLAVE_PREADY,
        APB_S_PSLVERR        => APB_SLAVE_PSLVERR,
        REFCLK1_OUT          => REFCLK1_OUT_net_0,
        TXD0_P               => TXD0_P_net_0,
        TXD0_N               => TXD0_N_net_0,
        TXD1_P               => TXD1_P_net_0,
        TXD1_N               => TXD1_N_net_0,
        TXD2_P               => TXD2_P_net_0,
        TXD2_N               => TXD2_N_net_0,
        TXD3_P               => TXD3_P_net_0,
        TXD3_N               => TXD3_N_net_0 
        );

end RTL;
