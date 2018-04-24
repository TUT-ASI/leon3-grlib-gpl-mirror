----------------------------------------------------------------------
-- Created by SmartDesign Wed Sep  7 19:52:17 2016
-- Version: v11.7 SP1 11.7.1.11
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library smartfusion2;
use smartfusion2.all;
----------------------------------------------------------------------
-- hpms_sb entity declaration
----------------------------------------------------------------------
entity hpms_sb is
    -- Port list
    port(
        -- Inputs
        DEVRST_N                    : in    std_logic;
        DMA_DMAREADY_FIC_0          : in    std_logic_vector(1 downto 0);
        DMA_DMAREADY_FIC_1          : in    std_logic_vector(1 downto 0);
        FAB_RESET_N                 : in    std_logic;
        FIC_0_AHB_M_HRDATA          : in    std_logic_vector(31 downto 0);
        FIC_0_AHB_M_HREADY          : in    std_logic;
        FIC_0_AHB_M_HRESP           : in    std_logic;
        FIC_0_AHB_S_HADDR           : in    std_logic_vector(31 downto 0);
        FIC_0_AHB_S_HMASTLOCK       : in    std_logic;
        FIC_0_AHB_S_HREADY          : in    std_logic;
        FIC_0_AHB_S_HSEL            : in    std_logic;
        FIC_0_AHB_S_HSIZE           : in    std_logic_vector(1 downto 0);
        FIC_0_AHB_S_HTRANS          : in    std_logic_vector(1 downto 0);
        FIC_0_AHB_S_HWDATA          : in    std_logic_vector(31 downto 0);
        FIC_0_AHB_S_HWRITE          : in    std_logic;
        MDDR_APB_S_PADDR            : in    std_logic_vector(10 downto 2);
        MDDR_APB_S_PCLK             : in    std_logic;
        MDDR_APB_S_PENABLE          : in    std_logic;
        MDDR_APB_S_PRESET_N         : in    std_logic;
        MDDR_APB_S_PSEL             : in    std_logic;
        MDDR_APB_S_PWDATA           : in    std_logic_vector(15 downto 0);
        MDDR_APB_S_PWRITE           : in    std_logic;
        MDDR_CORE_RESET_N           : in    std_logic;
        MDDR_DDR_AHB0_S_HADDR       : in    std_logic_vector(31 downto 0);
        MDDR_DDR_AHB0_S_HBURST      : in    std_logic_vector(2 downto 0);
        MDDR_DDR_AHB0_S_HMASTLOCK   : in    std_logic;
        MDDR_DDR_AHB0_S_HREADY      : in    std_logic;
        MDDR_DDR_AHB0_S_HSEL        : in    std_logic;
        MDDR_DDR_AHB0_S_HSIZE       : in    std_logic_vector(1 downto 0);
        MDDR_DDR_AHB0_S_HTRANS      : in    std_logic_vector(1 downto 0);
        MDDR_DDR_AHB0_S_HWDATA      : in    std_logic_vector(31 downto 0);
        MDDR_DDR_AHB0_S_HWRITE      : in    std_logic;
        MDDR_DQS_TMATCH_0_IN        : in    std_logic;
        SPI_0_DI                    : in    std_logic;
        -- Outputs
        COMM_BLK_INT                : out   std_logic;
        FIC_0_AHB_M_HADDR           : out   std_logic_vector(31 downto 0);
        FIC_0_AHB_M_HSIZE           : out   std_logic_vector(1 downto 0);
        FIC_0_AHB_M_HTRANS          : out   std_logic_vector(1 downto 0);
        FIC_0_AHB_M_HWDATA          : out   std_logic_vector(31 downto 0);
        FIC_0_AHB_M_HWRITE          : out   std_logic;
        FIC_0_AHB_S_HRDATA          : out   std_logic_vector(31 downto 0);
        FIC_0_AHB_S_HREADYOUT       : out   std_logic;
        FIC_0_AHB_S_HRESP           : out   std_logic;
        FIC_0_CLK                   : out   std_logic;
        FIC_0_LOCK                  : out   std_logic;
        HPMS_DDR_FIC_SUBSYSTEM_CLK  : out   std_logic;
        HPMS_DDR_FIC_SUBSYSTEM_LOCK : out   std_logic;
        HPMS_INT_M2F                : out   std_logic_vector(15 downto 0);
        HPMS_READY                  : out   std_logic;
        MDDR_ADDR                   : out   std_logic_vector(15 downto 0);
        MDDR_APB_S_PRDATA           : out   std_logic_vector(15 downto 0);
        MDDR_APB_S_PREADY           : out   std_logic;
        MDDR_APB_S_PSLVERR          : out   std_logic;
        MDDR_BA                     : out   std_logic_vector(2 downto 0);
        MDDR_CAS_N                  : out   std_logic;
        MDDR_CKE                    : out   std_logic;
        MDDR_CLK                    : out   std_logic;
        MDDR_CLK_N                  : out   std_logic;
        MDDR_CS_N                   : out   std_logic;
        MDDR_DDR_AHB0_S_HRDATA      : out   std_logic_vector(31 downto 0);
        MDDR_DDR_AHB0_S_HREADYOUT   : out   std_logic;
        MDDR_DDR_AHB0_S_HRESP       : out   std_logic;
        MDDR_DQS_TMATCH_0_OUT       : out   std_logic;
        MDDR_ODT                    : out   std_logic;
        MDDR_RAS_N                  : out   std_logic;
        MDDR_RESET_N                : out   std_logic;
        MDDR_WE_N                   : out   std_logic;
        POWER_ON_RESET_N            : out   std_logic;
        SPI_0_DO                    : out   std_logic;
        -- Inouts
        MDDR_DM_RDQS                : inout std_logic_vector(1 downto 0);
        MDDR_DQ                     : inout std_logic_vector(15 downto 0);
        MDDR_DQS                    : inout std_logic_vector(1 downto 0);
        SPI_0_CLK                   : inout std_logic;
        SPI_0_SS0                   : inout std_logic
        );
end hpms_sb;
----------------------------------------------------------------------
-- hpms_sb architecture body
----------------------------------------------------------------------
architecture RTL of hpms_sb is
----------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------
-- hpms_sb_CCC_0_FCCC   -   Actel:SgCore:FCCC:2.0.200
component hpms_sb_CCC_0_FCCC
    -- Port list
    port(
        -- Inputs
        RCOSC_25_50MHZ : in  std_logic;
        -- Outputs
        GL0            : out std_logic;
        GL2            : out std_logic;
        LOCK           : out std_logic
        );
end component;
-- CoreResetP   -   Actel:DirectCore:CoreResetP:7.1.100
component CoreResetP
    generic( 
        DDR_WAIT            : integer := 200 ;
        DEVICE_090          : integer := 0 ;
        DEVICE_VOLTAGE      : integer := 2 ;
        ENABLE_SOFT_RESETS  : integer := 0 ;
        EXT_RESET_CFG       : integer := 0 ;
        FDDR_IN_USE         : integer := 0 ;
        MDDR_IN_USE         : integer := 0 ;
        SDIF0_IN_USE        : integer := 0 ;
        SDIF0_PCIE          : integer := 0 ;
        SDIF0_PCIE_HOTRESET : integer := 1 ;
        SDIF0_PCIE_L2P2     : integer := 1 ;
        SDIF1_IN_USE        : integer := 0 ;
        SDIF1_PCIE          : integer := 0 ;
        SDIF1_PCIE_HOTRESET : integer := 1 ;
        SDIF1_PCIE_L2P2     : integer := 1 ;
        SDIF2_IN_USE        : integer := 0 ;
        SDIF2_PCIE          : integer := 0 ;
        SDIF2_PCIE_HOTRESET : integer := 1 ;
        SDIF2_PCIE_L2P2     : integer := 1 ;
        SDIF3_IN_USE        : integer := 0 ;
        SDIF3_PCIE          : integer := 0 ;
        SDIF3_PCIE_HOTRESET : integer := 1 ;
        SDIF3_PCIE_L2P2     : integer := 1 
        );
    -- Port list
    port(
        -- Inputs
        CLK_BASE                       : in  std_logic;
        CLK_LTSSM                      : in  std_logic;
        CONFIG1_DONE                   : in  std_logic;
        CONFIG2_DONE                   : in  std_logic;
        FAB_RESET_N                    : in  std_logic;
        FIC_2_APB_M_PRESET_N           : in  std_logic;
        FPLL_LOCK                      : in  std_logic;
        POWER_ON_RESET_N               : in  std_logic;
        RCOSC_25_50MHZ                 : in  std_logic;
        RESET_N_M2F                    : in  std_logic;
        SDIF0_PERST_N                  : in  std_logic;
        SDIF0_PRDATA                   : in  std_logic_vector(31 downto 0);
        SDIF0_PSEL                     : in  std_logic;
        SDIF0_PWRITE                   : in  std_logic;
        SDIF0_SPLL_LOCK                : in  std_logic;
        SDIF1_PERST_N                  : in  std_logic;
        SDIF1_PRDATA                   : in  std_logic_vector(31 downto 0);
        SDIF1_PSEL                     : in  std_logic;
        SDIF1_PWRITE                   : in  std_logic;
        SDIF1_SPLL_LOCK                : in  std_logic;
        SDIF2_PERST_N                  : in  std_logic;
        SDIF2_PRDATA                   : in  std_logic_vector(31 downto 0);
        SDIF2_PSEL                     : in  std_logic;
        SDIF2_PWRITE                   : in  std_logic;
        SDIF2_SPLL_LOCK                : in  std_logic;
        SDIF3_PERST_N                  : in  std_logic;
        SDIF3_PRDATA                   : in  std_logic_vector(31 downto 0);
        SDIF3_PSEL                     : in  std_logic;
        SDIF3_PWRITE                   : in  std_logic;
        SDIF3_SPLL_LOCK                : in  std_logic;
        SOFT_EXT_RESET_OUT             : in  std_logic;
        SOFT_FDDR_CORE_RESET           : in  std_logic;
        SOFT_M3_RESET                  : in  std_logic;
        SOFT_MDDR_DDR_AXI_S_CORE_RESET : in  std_logic;
        SOFT_RESET_F2M                 : in  std_logic;
        SOFT_SDIF0_0_CORE_RESET        : in  std_logic;
        SOFT_SDIF0_1_CORE_RESET        : in  std_logic;
        SOFT_SDIF0_CORE_RESET          : in  std_logic;
        SOFT_SDIF0_PHY_RESET           : in  std_logic;
        SOFT_SDIF1_CORE_RESET          : in  std_logic;
        SOFT_SDIF1_PHY_RESET           : in  std_logic;
        SOFT_SDIF2_CORE_RESET          : in  std_logic;
        SOFT_SDIF2_PHY_RESET           : in  std_logic;
        SOFT_SDIF3_CORE_RESET          : in  std_logic;
        SOFT_SDIF3_PHY_RESET           : in  std_logic;
        -- Outputs
        DDR_READY                      : out std_logic;
        EXT_RESET_OUT                  : out std_logic;
        FDDR_CORE_RESET_N              : out std_logic;
        INIT_DONE                      : out std_logic;
        M3_RESET_N                     : out std_logic;
        MDDR_DDR_AXI_S_CORE_RESET_N    : out std_logic;
        MSS_HPMS_READY                 : out std_logic;
        RESET_N_F2M                    : out std_logic;
        SDIF0_0_CORE_RESET_N           : out std_logic;
        SDIF0_1_CORE_RESET_N           : out std_logic;
        SDIF0_CORE_RESET_N             : out std_logic;
        SDIF0_PHY_RESET_N              : out std_logic;
        SDIF1_CORE_RESET_N             : out std_logic;
        SDIF1_PHY_RESET_N              : out std_logic;
        SDIF2_CORE_RESET_N             : out std_logic;
        SDIF2_PHY_RESET_N              : out std_logic;
        SDIF3_CORE_RESET_N             : out std_logic;
        SDIF3_PHY_RESET_N              : out std_logic;
        SDIF_READY                     : out std_logic;
        SDIF_RELEASED                  : out std_logic
        );
end component;
-- hpms_sb_FABOSC_0_OSC   -   Actel:SgCore:OSC:2.0.101
component hpms_sb_FABOSC_0_OSC
    -- Port list
    port(
        -- Inputs
        XTL                : in  std_logic;
        -- Outputs
        RCOSC_1MHZ_CCC     : out std_logic;
        RCOSC_1MHZ_O2F     : out std_logic;
        RCOSC_25_50MHZ_CCC : out std_logic;
        RCOSC_25_50MHZ_O2F : out std_logic;
        XTLOSC_CCC         : out std_logic;
        XTLOSC_O2F         : out std_logic
        );
end component;
-- hpms_sb_HPMS
component hpms_sb_HPMS
    -- Port list
    port(
        -- Inputs
        DMA_DMAREADY_FIC_0        : in    std_logic_vector(1 downto 0);
        DMA_DMAREADY_FIC_1        : in    std_logic_vector(1 downto 0);
        FIC_0_AHB_M_HRDATA        : in    std_logic_vector(31 downto 0);
        FIC_0_AHB_M_HREADY        : in    std_logic;
        FIC_0_AHB_M_HRESP         : in    std_logic;
        FIC_0_AHB_S_HADDR         : in    std_logic_vector(31 downto 0);
        FIC_0_AHB_S_HMASTLOCK     : in    std_logic;
        FIC_0_AHB_S_HREADY        : in    std_logic;
        FIC_0_AHB_S_HSEL          : in    std_logic;
        FIC_0_AHB_S_HSIZE         : in    std_logic_vector(1 downto 0);
        FIC_0_AHB_S_HTRANS        : in    std_logic_vector(1 downto 0);
        FIC_0_AHB_S_HWDATA        : in    std_logic_vector(31 downto 0);
        FIC_0_AHB_S_HWRITE        : in    std_logic;
        FIC_2_APB_M_PRDATA        : in    std_logic_vector(31 downto 0);
        FIC_2_APB_M_PREADY        : in    std_logic;
        FIC_2_APB_M_PSLVERR       : in    std_logic;
        M3_RESET_N                : in    std_logic;
        MCCC_CLK_BASE             : in    std_logic;
        MCCC_CLK_BASE_PLL_LOCK    : in    std_logic;
        MDDR_APB_S_PADDR          : in    std_logic_vector(10 downto 2);
        MDDR_APB_S_PCLK           : in    std_logic;
        MDDR_APB_S_PENABLE        : in    std_logic;
        MDDR_APB_S_PRESET_N       : in    std_logic;
        MDDR_APB_S_PSEL           : in    std_logic;
        MDDR_APB_S_PWDATA         : in    std_logic_vector(15 downto 0);
        MDDR_APB_S_PWRITE         : in    std_logic;
        MDDR_DDR_AHB0_S_HADDR     : in    std_logic_vector(31 downto 0);
        MDDR_DDR_AHB0_S_HBURST    : in    std_logic_vector(2 downto 0);
        MDDR_DDR_AHB0_S_HMASTLOCK : in    std_logic;
        MDDR_DDR_AHB0_S_HREADY    : in    std_logic;
        MDDR_DDR_AHB0_S_HSEL      : in    std_logic;
        MDDR_DDR_AHB0_S_HSIZE     : in    std_logic_vector(1 downto 0);
        MDDR_DDR_AHB0_S_HTRANS    : in    std_logic_vector(1 downto 0);
        MDDR_DDR_AHB0_S_HWDATA    : in    std_logic_vector(31 downto 0);
        MDDR_DDR_AHB0_S_HWRITE    : in    std_logic;
        MDDR_DDR_CORE_RESET_N     : in    std_logic;
        MDDR_DQS_TMATCH_0_IN      : in    std_logic;
        MSS_RESET_N_F2M           : in    std_logic;
        SPI_0_DI                  : in    std_logic;
        -- Outputs
        COMM_BLK_INT              : out   std_logic;
        FIC_0_AHB_M_HADDR         : out   std_logic_vector(31 downto 0);
        FIC_0_AHB_M_HSIZE         : out   std_logic_vector(1 downto 0);
        FIC_0_AHB_M_HTRANS        : out   std_logic_vector(1 downto 0);
        FIC_0_AHB_M_HWDATA        : out   std_logic_vector(31 downto 0);
        FIC_0_AHB_M_HWRITE        : out   std_logic;
        FIC_0_AHB_S_HRDATA        : out   std_logic_vector(31 downto 0);
        FIC_0_AHB_S_HREADYOUT     : out   std_logic;
        FIC_0_AHB_S_HRESP         : out   std_logic;
        FIC_2_APB_M_PADDR         : out   std_logic_vector(15 downto 2);
        FIC_2_APB_M_PCLK          : out   std_logic;
        FIC_2_APB_M_PENABLE       : out   std_logic;
        FIC_2_APB_M_PRESET_N      : out   std_logic;
        FIC_2_APB_M_PSEL          : out   std_logic;
        FIC_2_APB_M_PWDATA        : out   std_logic_vector(31 downto 0);
        FIC_2_APB_M_PWRITE        : out   std_logic;
        M3_NMI                    : out   std_logic;
        MDDR_ADDR                 : out   std_logic_vector(15 downto 0);
        MDDR_APB_S_PRDATA         : out   std_logic_vector(15 downto 0);
        MDDR_APB_S_PREADY         : out   std_logic;
        MDDR_APB_S_PSLVERR        : out   std_logic;
        MDDR_BA                   : out   std_logic_vector(2 downto 0);
        MDDR_CAS_N                : out   std_logic;
        MDDR_CKE                  : out   std_logic;
        MDDR_CLK                  : out   std_logic;
        MDDR_CLK_N                : out   std_logic;
        MDDR_CS_N                 : out   std_logic;
        MDDR_DDR_AHB0_S_HRDATA    : out   std_logic_vector(31 downto 0);
        MDDR_DDR_AHB0_S_HREADYOUT : out   std_logic;
        MDDR_DDR_AHB0_S_HRESP     : out   std_logic;
        MDDR_DQS_TMATCH_0_OUT     : out   std_logic;
        MDDR_ODT                  : out   std_logic;
        MDDR_RAS_N                : out   std_logic;
        MDDR_RESET_N              : out   std_logic;
        MDDR_WE_N                 : out   std_logic;
        MSS_INT_M2F               : out   std_logic_vector(15 downto 0);
        MSS_RESET_N_M2F           : out   std_logic;
        SPI_0_DO                  : out   std_logic;
        -- Inouts
        MDDR_DM_RDQS              : inout std_logic_vector(1 downto 0);
        MDDR_DQ                   : inout std_logic_vector(15 downto 0);
        MDDR_DQS                  : inout std_logic_vector(1 downto 0);
        SPI_0_CLK                 : inout std_logic;
        SPI_0_SS0                 : inout std_logic
        );
end component;
-- SYSRESET
component SYSRESET
    -- Port list
    port(
        -- Inputs
        DEVRST_N         : in  std_logic;
        -- Outputs
        POWER_ON_RESET_N : out std_logic
        );
end component;
----------------------------------------------------------------------
-- Signal declarations
----------------------------------------------------------------------
signal COMM_BLK_INT_net_0                                 : std_logic;
signal CORERESETP_0_RESET_N_F2M                           : std_logic;
signal FABOSC_0_RCOSC_25_50MHZ_CCC_OUT_RCOSC_25_50MHZ_CCC : std_logic;
signal FABOSC_0_RCOSC_25_50MHZ_O2F                        : std_logic;
signal FIC_0_AHB_MASTER_HADDR                             : std_logic_vector(31 downto 0);
signal FIC_0_AHB_MASTER_HSIZE                             : std_logic_vector(1 downto 0);
signal FIC_0_AHB_MASTER_HTRANS                            : std_logic_vector(1 downto 0);
signal FIC_0_AHB_MASTER_HWDATA                            : std_logic_vector(31 downto 0);
signal FIC_0_AHB_MASTER_HWRITE                            : std_logic;
signal FIC_0_AHB_SLAVE_HRDATA                             : std_logic_vector(31 downto 0);
signal FIC_0_AHB_SLAVE_HREADYOUT                          : std_logic;
signal FIC_0_AHB_SLAVE_HRESP                              : std_logic;
signal FIC_0_CLK_net_0                                    : std_logic;
signal HPMS_DDR_FIC_SUBSYSTEM_CLK_net_0                   : std_logic;
signal HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_0                  : std_logic;
signal HPMS_INT_M2F_net_0                                 : std_logic_vector(15 downto 0);
signal HPMS_READY_net_0                                   : std_logic;
signal hpms_sb_HPMS_TMP_0_FIC_2_APB_M_PRESET_N            : std_logic;
signal hpms_sb_HPMS_TMP_0_MSS_RESET_N_M2F                 : std_logic;
signal MDDR_ADDR_net_0                                    : std_logic_vector(15 downto 0);
signal MDDR_APB_SLAVE_PRDATA                              : std_logic_vector(15 downto 0);
signal MDDR_APB_SLAVE_PREADY                              : std_logic;
signal MDDR_APB_SLAVE_PSLVERR                             : std_logic;
signal MDDR_BA_net_0                                      : std_logic_vector(2 downto 0);
signal MDDR_CAS_N_net_0                                   : std_logic;
signal MDDR_CKE_net_0                                     : std_logic;
signal MDDR_CLK_net_0                                     : std_logic;
signal MDDR_CLK_N_net_0                                   : std_logic;
signal MDDR_CS_N_net_0                                    : std_logic;
signal MDDR_DDR_AHB0_SLAVE_HRDATA                         : std_logic_vector(31 downto 0);
signal MDDR_DDR_AHB0_SLAVE_HREADYOUT                      : std_logic;
signal MDDR_DDR_AHB0_SLAVE_HRESP                          : std_logic;
signal MDDR_DQS_TMATCH_0_OUT_net_0                        : std_logic;
signal MDDR_ODT_net_0                                     : std_logic;
signal MDDR_RAS_N_net_0                                   : std_logic;
signal MDDR_RESET_N_net_0                                 : std_logic;
signal MDDR_WE_N_net_0                                    : std_logic;
signal POWER_ON_RESET_N_net_0                             : std_logic;
signal SPI_0_DO_net_0                                     : std_logic;
signal SPI_0_DO_net_1                                     : std_logic;
signal MDDR_DQS_TMATCH_0_OUT_net_1                        : std_logic;
signal MDDR_CAS_N_net_1                                   : std_logic;
signal MDDR_CLK_net_1                                     : std_logic;
signal MDDR_CLK_N_net_1                                   : std_logic;
signal MDDR_CKE_net_1                                     : std_logic;
signal MDDR_CS_N_net_1                                    : std_logic;
signal MDDR_ODT_net_1                                     : std_logic;
signal MDDR_RAS_N_net_1                                   : std_logic;
signal MDDR_RESET_N_net_1                                 : std_logic;
signal MDDR_WE_N_net_1                                    : std_logic;
signal POWER_ON_RESET_N_net_1                             : std_logic;
signal HPMS_DDR_FIC_SUBSYSTEM_CLK_net_1                   : std_logic;
signal HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_1                  : std_logic;
signal FIC_0_CLK_net_1                                    : std_logic;
signal HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_2                  : std_logic;
signal HPMS_READY_net_1                                   : std_logic;
signal MDDR_APB_SLAVE_PREADY_net_0                        : std_logic;
signal MDDR_APB_SLAVE_PSLVERR_net_0                       : std_logic;
signal COMM_BLK_INT_net_1                                 : std_logic;
signal MDDR_ADDR_net_1                                    : std_logic_vector(15 downto 0);
signal MDDR_BA_net_1                                      : std_logic_vector(2 downto 0);
signal MDDR_APB_SLAVE_PRDATA_net_0                        : std_logic_vector(15 downto 0);
signal HPMS_INT_M2F_net_1                                 : std_logic_vector(15 downto 0);
signal FIC_0_AHB_MASTER_HADDR_net_0                       : std_logic_vector(31 downto 0);
signal FIC_0_AHB_MASTER_HTRANS_net_0                      : std_logic_vector(1 downto 0);
signal FIC_0_AHB_MASTER_HWRITE_net_0                      : std_logic;
signal FIC_0_AHB_MASTER_HSIZE_net_0                       : std_logic_vector(1 downto 0);
signal FIC_0_AHB_MASTER_HWDATA_net_0                      : std_logic_vector(31 downto 0);
signal FIC_0_AHB_SLAVE_HRDATA_net_0                       : std_logic_vector(31 downto 0);
signal FIC_0_AHB_SLAVE_HREADYOUT_net_0                    : std_logic;
signal FIC_0_AHB_SLAVE_HRESP_net_0                        : std_logic;
signal MDDR_DDR_AHB0_SLAVE_HRDATA_net_0                   : std_logic_vector(31 downto 0);
signal MDDR_DDR_AHB0_SLAVE_HREADYOUT_net_0                : std_logic;
signal MDDR_DDR_AHB0_SLAVE_HRESP_net_0                    : std_logic;
----------------------------------------------------------------------
-- TiedOff Signals
----------------------------------------------------------------------
signal VCC_net                                            : std_logic;
signal GND_net                                            : std_logic;
signal PADDR_const_net_0                                  : std_logic_vector(7 downto 2);
signal PWDATA_const_net_0                                 : std_logic_vector(7 downto 0);
signal SDIF0_PRDATA_const_net_0                           : std_logic_vector(31 downto 0);
signal SDIF1_PRDATA_const_net_0                           : std_logic_vector(31 downto 0);
signal SDIF2_PRDATA_const_net_0                           : std_logic_vector(31 downto 0);
signal SDIF3_PRDATA_const_net_0                           : std_logic_vector(31 downto 0);
signal FIC_2_APB_M_PRDATA_const_net_0                     : std_logic_vector(31 downto 0);

begin
----------------------------------------------------------------------
-- Constant assignments
----------------------------------------------------------------------
 VCC_net                        <= '1';
 GND_net                        <= '0';
 PADDR_const_net_0              <= B"000000";
 PWDATA_const_net_0             <= B"00000000";
 SDIF0_PRDATA_const_net_0       <= B"00000000000000000000000000000000";
 SDIF1_PRDATA_const_net_0       <= B"00000000000000000000000000000000";
 SDIF2_PRDATA_const_net_0       <= B"00000000000000000000000000000000";
 SDIF3_PRDATA_const_net_0       <= B"00000000000000000000000000000000";
 FIC_2_APB_M_PRDATA_const_net_0 <= B"00000000000000000000000000000000";
----------------------------------------------------------------------
-- Top level output port assignments
----------------------------------------------------------------------
 SPI_0_DO_net_1                      <= SPI_0_DO_net_0;
 SPI_0_DO                            <= SPI_0_DO_net_1;
 MDDR_DQS_TMATCH_0_OUT_net_1         <= MDDR_DQS_TMATCH_0_OUT_net_0;
 MDDR_DQS_TMATCH_0_OUT               <= MDDR_DQS_TMATCH_0_OUT_net_1;
 MDDR_CAS_N_net_1                    <= MDDR_CAS_N_net_0;
 MDDR_CAS_N                          <= MDDR_CAS_N_net_1;
 MDDR_CLK_net_1                      <= MDDR_CLK_net_0;
 MDDR_CLK                            <= MDDR_CLK_net_1;
 MDDR_CLK_N_net_1                    <= MDDR_CLK_N_net_0;
 MDDR_CLK_N                          <= MDDR_CLK_N_net_1;
 MDDR_CKE_net_1                      <= MDDR_CKE_net_0;
 MDDR_CKE                            <= MDDR_CKE_net_1;
 MDDR_CS_N_net_1                     <= MDDR_CS_N_net_0;
 MDDR_CS_N                           <= MDDR_CS_N_net_1;
 MDDR_ODT_net_1                      <= MDDR_ODT_net_0;
 MDDR_ODT                            <= MDDR_ODT_net_1;
 MDDR_RAS_N_net_1                    <= MDDR_RAS_N_net_0;
 MDDR_RAS_N                          <= MDDR_RAS_N_net_1;
 MDDR_RESET_N_net_1                  <= MDDR_RESET_N_net_0;
 MDDR_RESET_N                        <= MDDR_RESET_N_net_1;
 MDDR_WE_N_net_1                     <= MDDR_WE_N_net_0;
 MDDR_WE_N                           <= MDDR_WE_N_net_1;
 POWER_ON_RESET_N_net_1              <= POWER_ON_RESET_N_net_0;
 POWER_ON_RESET_N                    <= POWER_ON_RESET_N_net_1;
 HPMS_DDR_FIC_SUBSYSTEM_CLK_net_1    <= HPMS_DDR_FIC_SUBSYSTEM_CLK_net_0;
 HPMS_DDR_FIC_SUBSYSTEM_CLK          <= HPMS_DDR_FIC_SUBSYSTEM_CLK_net_1;
 HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_1   <= HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_0;
 HPMS_DDR_FIC_SUBSYSTEM_LOCK         <= HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_1;
 FIC_0_CLK_net_1                     <= FIC_0_CLK_net_0;
 FIC_0_CLK                           <= FIC_0_CLK_net_1;
 HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_2   <= HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_0;
 FIC_0_LOCK                          <= HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_2;
 HPMS_READY_net_1                    <= HPMS_READY_net_0;
 HPMS_READY                          <= HPMS_READY_net_1;
 MDDR_APB_SLAVE_PREADY_net_0         <= MDDR_APB_SLAVE_PREADY;
 MDDR_APB_S_PREADY                   <= MDDR_APB_SLAVE_PREADY_net_0;
 MDDR_APB_SLAVE_PSLVERR_net_0        <= MDDR_APB_SLAVE_PSLVERR;
 MDDR_APB_S_PSLVERR                  <= MDDR_APB_SLAVE_PSLVERR_net_0;
 COMM_BLK_INT_net_1                  <= COMM_BLK_INT_net_0;
 COMM_BLK_INT                        <= COMM_BLK_INT_net_1;
 MDDR_ADDR_net_1                     <= MDDR_ADDR_net_0;
 MDDR_ADDR(15 downto 0)              <= MDDR_ADDR_net_1;
 MDDR_BA_net_1                       <= MDDR_BA_net_0;
 MDDR_BA(2 downto 0)                 <= MDDR_BA_net_1;
 MDDR_APB_SLAVE_PRDATA_net_0         <= MDDR_APB_SLAVE_PRDATA;
 MDDR_APB_S_PRDATA(15 downto 0)      <= MDDR_APB_SLAVE_PRDATA_net_0;
 HPMS_INT_M2F_net_1                  <= HPMS_INT_M2F_net_0;
 HPMS_INT_M2F(15 downto 0)           <= HPMS_INT_M2F_net_1;
 FIC_0_AHB_MASTER_HADDR_net_0        <= FIC_0_AHB_MASTER_HADDR;
 FIC_0_AHB_M_HADDR(31 downto 0)      <= FIC_0_AHB_MASTER_HADDR_net_0;
 FIC_0_AHB_MASTER_HTRANS_net_0       <= FIC_0_AHB_MASTER_HTRANS;
 FIC_0_AHB_M_HTRANS(1 downto 0)      <= FIC_0_AHB_MASTER_HTRANS_net_0;
 FIC_0_AHB_MASTER_HWRITE_net_0       <= FIC_0_AHB_MASTER_HWRITE;
 FIC_0_AHB_M_HWRITE                  <= FIC_0_AHB_MASTER_HWRITE_net_0;
 FIC_0_AHB_MASTER_HSIZE_net_0        <= FIC_0_AHB_MASTER_HSIZE;
 FIC_0_AHB_M_HSIZE(1 downto 0)       <= FIC_0_AHB_MASTER_HSIZE_net_0;
 FIC_0_AHB_MASTER_HWDATA_net_0       <= FIC_0_AHB_MASTER_HWDATA;
 FIC_0_AHB_M_HWDATA(31 downto 0)     <= FIC_0_AHB_MASTER_HWDATA_net_0;
 FIC_0_AHB_SLAVE_HRDATA_net_0        <= FIC_0_AHB_SLAVE_HRDATA;
 FIC_0_AHB_S_HRDATA(31 downto 0)     <= FIC_0_AHB_SLAVE_HRDATA_net_0;
 FIC_0_AHB_SLAVE_HREADYOUT_net_0     <= FIC_0_AHB_SLAVE_HREADYOUT;
 FIC_0_AHB_S_HREADYOUT               <= FIC_0_AHB_SLAVE_HREADYOUT_net_0;
 FIC_0_AHB_SLAVE_HRESP_net_0         <= FIC_0_AHB_SLAVE_HRESP;
 FIC_0_AHB_S_HRESP                   <= FIC_0_AHB_SLAVE_HRESP_net_0;
 MDDR_DDR_AHB0_SLAVE_HRDATA_net_0    <= MDDR_DDR_AHB0_SLAVE_HRDATA;
 MDDR_DDR_AHB0_S_HRDATA(31 downto 0) <= MDDR_DDR_AHB0_SLAVE_HRDATA_net_0;
 MDDR_DDR_AHB0_SLAVE_HREADYOUT_net_0 <= MDDR_DDR_AHB0_SLAVE_HREADYOUT;
 MDDR_DDR_AHB0_S_HREADYOUT           <= MDDR_DDR_AHB0_SLAVE_HREADYOUT_net_0;
 MDDR_DDR_AHB0_SLAVE_HRESP_net_0     <= MDDR_DDR_AHB0_SLAVE_HRESP;
 MDDR_DDR_AHB0_S_HRESP               <= MDDR_DDR_AHB0_SLAVE_HRESP_net_0;
----------------------------------------------------------------------
-- Component instances
----------------------------------------------------------------------
-- CCC_0   -   Actel:SgCore:FCCC:2.0.200
CCC_0 : hpms_sb_CCC_0_FCCC
    port map( 
        -- Inputs
        RCOSC_25_50MHZ => FABOSC_0_RCOSC_25_50MHZ_CCC_OUT_RCOSC_25_50MHZ_CCC,
        -- Outputs
        GL0            => FIC_0_CLK_net_0,
        GL2            => HPMS_DDR_FIC_SUBSYSTEM_CLK_net_0,
        LOCK           => HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_0 
        );
-- CORERESETP_0   -   Actel:DirectCore:CoreResetP:7.1.100
CORERESETP_0 : CoreResetP
    generic map( 
        DDR_WAIT            => ( 200 ),
        DEVICE_090          => ( 0 ),
        DEVICE_VOLTAGE      => ( 2 ),
        ENABLE_SOFT_RESETS  => ( 0 ),
        EXT_RESET_CFG       => ( 0 ),
        FDDR_IN_USE         => ( 0 ),
        MDDR_IN_USE         => ( 0 ),
        SDIF0_IN_USE        => ( 0 ),
        SDIF0_PCIE          => ( 0 ),
        SDIF0_PCIE_HOTRESET => ( 1 ),
        SDIF0_PCIE_L2P2     => ( 1 ),
        SDIF1_IN_USE        => ( 0 ),
        SDIF1_PCIE          => ( 0 ),
        SDIF1_PCIE_HOTRESET => ( 1 ),
        SDIF1_PCIE_L2P2     => ( 1 ),
        SDIF2_IN_USE        => ( 0 ),
        SDIF2_PCIE          => ( 0 ),
        SDIF2_PCIE_HOTRESET => ( 1 ),
        SDIF2_PCIE_L2P2     => ( 1 ),
        SDIF3_IN_USE        => ( 0 ),
        SDIF3_PCIE          => ( 0 ),
        SDIF3_PCIE_HOTRESET => ( 1 ),
        SDIF3_PCIE_L2P2     => ( 1 )
        )
    port map( 
        -- Inputs
        RESET_N_M2F                    => hpms_sb_HPMS_TMP_0_MSS_RESET_N_M2F,
        FIC_2_APB_M_PRESET_N           => hpms_sb_HPMS_TMP_0_FIC_2_APB_M_PRESET_N,
        POWER_ON_RESET_N               => POWER_ON_RESET_N_net_0,
        FAB_RESET_N                    => FAB_RESET_N,
        RCOSC_25_50MHZ                 => FABOSC_0_RCOSC_25_50MHZ_O2F,
        CLK_BASE                       => FIC_0_CLK_net_0,
        CLK_LTSSM                      => GND_net, -- tied to '0' from definition
        FPLL_LOCK                      => VCC_net, -- tied to '1' from definition
        SDIF0_SPLL_LOCK                => VCC_net, -- tied to '1' from definition
        SDIF1_SPLL_LOCK                => VCC_net, -- tied to '1' from definition
        SDIF2_SPLL_LOCK                => VCC_net, -- tied to '1' from definition
        SDIF3_SPLL_LOCK                => VCC_net, -- tied to '1' from definition
        CONFIG1_DONE                   => VCC_net,
        CONFIG2_DONE                   => VCC_net,
        SDIF0_PERST_N                  => VCC_net, -- tied to '1' from definition
        SDIF1_PERST_N                  => VCC_net, -- tied to '1' from definition
        SDIF2_PERST_N                  => VCC_net, -- tied to '1' from definition
        SDIF3_PERST_N                  => VCC_net, -- tied to '1' from definition
        SDIF0_PSEL                     => GND_net, -- tied to '0' from definition
        SDIF0_PWRITE                   => VCC_net, -- tied to '1' from definition
        SDIF1_PSEL                     => GND_net, -- tied to '0' from definition
        SDIF1_PWRITE                   => VCC_net, -- tied to '1' from definition
        SDIF2_PSEL                     => GND_net, -- tied to '0' from definition
        SDIF2_PWRITE                   => VCC_net, -- tied to '1' from definition
        SDIF3_PSEL                     => GND_net, -- tied to '0' from definition
        SDIF3_PWRITE                   => VCC_net, -- tied to '1' from definition
        SOFT_EXT_RESET_OUT             => GND_net, -- tied to '0' from definition
        SOFT_RESET_F2M                 => GND_net, -- tied to '0' from definition
        SOFT_M3_RESET                  => GND_net, -- tied to '0' from definition
        SOFT_MDDR_DDR_AXI_S_CORE_RESET => GND_net, -- tied to '0' from definition
        SOFT_FDDR_CORE_RESET           => GND_net, -- tied to '0' from definition
        SOFT_SDIF0_PHY_RESET           => GND_net, -- tied to '0' from definition
        SOFT_SDIF0_CORE_RESET          => GND_net, -- tied to '0' from definition
        SOFT_SDIF0_0_CORE_RESET        => GND_net, -- tied to '0' from definition
        SOFT_SDIF0_1_CORE_RESET        => GND_net, -- tied to '0' from definition
        SOFT_SDIF1_PHY_RESET           => GND_net, -- tied to '0' from definition
        SOFT_SDIF1_CORE_RESET          => GND_net, -- tied to '0' from definition
        SOFT_SDIF2_PHY_RESET           => GND_net, -- tied to '0' from definition
        SOFT_SDIF2_CORE_RESET          => GND_net, -- tied to '0' from definition
        SOFT_SDIF3_PHY_RESET           => GND_net, -- tied to '0' from definition
        SOFT_SDIF3_CORE_RESET          => GND_net, -- tied to '0' from definition
        SDIF0_PRDATA                   => SDIF0_PRDATA_const_net_0, -- tied to X"0" from definition
        SDIF1_PRDATA                   => SDIF1_PRDATA_const_net_0, -- tied to X"0" from definition
        SDIF2_PRDATA                   => SDIF2_PRDATA_const_net_0, -- tied to X"0" from definition
        SDIF3_PRDATA                   => SDIF3_PRDATA_const_net_0, -- tied to X"0" from definition
        -- Outputs
        MSS_HPMS_READY                 => HPMS_READY_net_0,
        DDR_READY                      => OPEN,
        SDIF_READY                     => OPEN,
        RESET_N_F2M                    => CORERESETP_0_RESET_N_F2M,
        M3_RESET_N                     => OPEN,
        EXT_RESET_OUT                  => OPEN,
        MDDR_DDR_AXI_S_CORE_RESET_N    => OPEN,
        FDDR_CORE_RESET_N              => OPEN,
        SDIF0_CORE_RESET_N             => OPEN,
        SDIF0_0_CORE_RESET_N           => OPEN,
        SDIF0_1_CORE_RESET_N           => OPEN,
        SDIF0_PHY_RESET_N              => OPEN,
        SDIF1_CORE_RESET_N             => OPEN,
        SDIF1_PHY_RESET_N              => OPEN,
        SDIF2_CORE_RESET_N             => OPEN,
        SDIF2_PHY_RESET_N              => OPEN,
        SDIF3_CORE_RESET_N             => OPEN,
        SDIF3_PHY_RESET_N              => OPEN,
        SDIF_RELEASED                  => OPEN,
        INIT_DONE                      => OPEN 
        );
-- FABOSC_0   -   Actel:SgCore:OSC:2.0.101
FABOSC_0 : hpms_sb_FABOSC_0_OSC
    port map( 
        -- Inputs
        XTL                => GND_net, -- tied to '0' from definition
        -- Outputs
        RCOSC_25_50MHZ_CCC => FABOSC_0_RCOSC_25_50MHZ_CCC_OUT_RCOSC_25_50MHZ_CCC,
        RCOSC_25_50MHZ_O2F => FABOSC_0_RCOSC_25_50MHZ_O2F,
        RCOSC_1MHZ_CCC     => OPEN,
        RCOSC_1MHZ_O2F     => OPEN,
        XTLOSC_CCC         => OPEN,
        XTLOSC_O2F         => OPEN 
        );
-- hpms_sb_HPMS_0
hpms_sb_HPMS_0 : hpms_sb_HPMS
    port map( 
        -- Inputs
        SPI_0_DI                  => SPI_0_DI,
        MCCC_CLK_BASE             => FIC_0_CLK_net_0,
        MDDR_DQS_TMATCH_0_IN      => MDDR_DQS_TMATCH_0_IN,
        MCCC_CLK_BASE_PLL_LOCK    => HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_0,
        MSS_RESET_N_F2M           => CORERESETP_0_RESET_N_F2M,
        M3_RESET_N                => GND_net,
        MDDR_DDR_CORE_RESET_N     => MDDR_CORE_RESET_N,
        MDDR_DDR_AHB0_S_HSEL      => MDDR_DDR_AHB0_S_HSEL,
        MDDR_DDR_AHB0_S_HMASTLOCK => MDDR_DDR_AHB0_S_HMASTLOCK,
        MDDR_DDR_AHB0_S_HWRITE    => MDDR_DDR_AHB0_S_HWRITE,
        MDDR_DDR_AHB0_S_HREADY    => MDDR_DDR_AHB0_S_HREADY,
        FIC_0_AHB_S_HREADY        => FIC_0_AHB_S_HREADY,
        FIC_0_AHB_S_HWRITE        => FIC_0_AHB_S_HWRITE,
        FIC_0_AHB_S_HMASTLOCK     => FIC_0_AHB_S_HMASTLOCK,
        FIC_0_AHB_S_HSEL          => FIC_0_AHB_S_HSEL,
        FIC_0_AHB_M_HREADY        => FIC_0_AHB_M_HREADY,
        FIC_0_AHB_M_HRESP         => FIC_0_AHB_M_HRESP,
        MDDR_APB_S_PRESET_N       => MDDR_APB_S_PRESET_N,
        MDDR_APB_S_PCLK           => MDDR_APB_S_PCLK,
        FIC_2_APB_M_PREADY        => VCC_net, -- tied to '1' from definition
        FIC_2_APB_M_PSLVERR       => GND_net, -- tied to '0' from definition
        MDDR_APB_S_PWRITE         => MDDR_APB_S_PWRITE,
        MDDR_APB_S_PENABLE        => MDDR_APB_S_PENABLE,
        MDDR_APB_S_PSEL           => MDDR_APB_S_PSEL,
        MDDR_DDR_AHB0_S_HADDR     => MDDR_DDR_AHB0_S_HADDR,
        MDDR_DDR_AHB0_S_HBURST    => MDDR_DDR_AHB0_S_HBURST,
        MDDR_DDR_AHB0_S_HSIZE     => MDDR_DDR_AHB0_S_HSIZE,
        MDDR_DDR_AHB0_S_HTRANS    => MDDR_DDR_AHB0_S_HTRANS,
        MDDR_DDR_AHB0_S_HWDATA    => MDDR_DDR_AHB0_S_HWDATA,
        FIC_0_AHB_S_HADDR         => FIC_0_AHB_S_HADDR,
        FIC_0_AHB_S_HWDATA        => FIC_0_AHB_S_HWDATA,
        FIC_0_AHB_S_HSIZE         => FIC_0_AHB_S_HSIZE,
        FIC_0_AHB_S_HTRANS        => FIC_0_AHB_S_HTRANS,
        FIC_0_AHB_M_HRDATA        => FIC_0_AHB_M_HRDATA,
        FIC_2_APB_M_PRDATA        => FIC_2_APB_M_PRDATA_const_net_0, -- tied to X"0" from definition
        MDDR_APB_S_PWDATA         => MDDR_APB_S_PWDATA,
        MDDR_APB_S_PADDR          => MDDR_APB_S_PADDR,
        DMA_DMAREADY_FIC_0        => DMA_DMAREADY_FIC_0,
        DMA_DMAREADY_FIC_1        => DMA_DMAREADY_FIC_1,
        -- Outputs
        SPI_0_DO                  => SPI_0_DO_net_0,
        MDDR_DQS_TMATCH_0_OUT     => MDDR_DQS_TMATCH_0_OUT_net_0,
        MDDR_CAS_N                => MDDR_CAS_N_net_0,
        MDDR_CLK                  => MDDR_CLK_net_0,
        MDDR_CLK_N                => MDDR_CLK_N_net_0,
        MDDR_CKE                  => MDDR_CKE_net_0,
        MDDR_CS_N                 => MDDR_CS_N_net_0,
        MDDR_ODT                  => MDDR_ODT_net_0,
        MDDR_RAS_N                => MDDR_RAS_N_net_0,
        MDDR_RESET_N              => MDDR_RESET_N_net_0,
        MDDR_WE_N                 => MDDR_WE_N_net_0,
        MSS_RESET_N_M2F           => hpms_sb_HPMS_TMP_0_MSS_RESET_N_M2F,
        MDDR_DDR_AHB0_S_HREADYOUT => MDDR_DDR_AHB0_SLAVE_HREADYOUT,
        MDDR_DDR_AHB0_S_HRESP     => MDDR_DDR_AHB0_SLAVE_HRESP,
        FIC_0_AHB_S_HRESP         => FIC_0_AHB_SLAVE_HRESP,
        FIC_0_AHB_S_HREADYOUT     => FIC_0_AHB_SLAVE_HREADYOUT,
        FIC_0_AHB_M_HWRITE        => FIC_0_AHB_MASTER_HWRITE,
        FIC_2_APB_M_PRESET_N      => hpms_sb_HPMS_TMP_0_FIC_2_APB_M_PRESET_N,
        FIC_2_APB_M_PCLK          => OPEN,
        FIC_2_APB_M_PWRITE        => OPEN,
        FIC_2_APB_M_PENABLE       => OPEN,
        FIC_2_APB_M_PSEL          => OPEN,
        MDDR_APB_S_PREADY         => MDDR_APB_SLAVE_PREADY,
        MDDR_APB_S_PSLVERR        => MDDR_APB_SLAVE_PSLVERR,
        M3_NMI                    => OPEN,
        COMM_BLK_INT              => COMM_BLK_INT_net_0,
        MDDR_ADDR                 => MDDR_ADDR_net_0,
        MDDR_BA                   => MDDR_BA_net_0,
        MDDR_DDR_AHB0_S_HRDATA    => MDDR_DDR_AHB0_SLAVE_HRDATA,
        FIC_0_AHB_S_HRDATA        => FIC_0_AHB_SLAVE_HRDATA,
        FIC_0_AHB_M_HADDR         => FIC_0_AHB_MASTER_HADDR,
        FIC_0_AHB_M_HWDATA        => FIC_0_AHB_MASTER_HWDATA,
        FIC_0_AHB_M_HSIZE         => FIC_0_AHB_MASTER_HSIZE,
        FIC_0_AHB_M_HTRANS        => FIC_0_AHB_MASTER_HTRANS,
        FIC_2_APB_M_PADDR         => OPEN,
        FIC_2_APB_M_PWDATA        => OPEN,
        MDDR_APB_S_PRDATA         => MDDR_APB_SLAVE_PRDATA,
        MSS_INT_M2F               => HPMS_INT_M2F_net_0,
        -- Inouts
        SPI_0_CLK                 => SPI_0_CLK,
        SPI_0_SS0                 => SPI_0_SS0,
        MDDR_DM_RDQS              => MDDR_DM_RDQS,
        MDDR_DQ                   => MDDR_DQ,
        MDDR_DQS                  => MDDR_DQS 
        );
-- SYSRESET_POR
SYSRESET_POR : SYSRESET
    port map( 
        -- Inputs
        DEVRST_N         => DEVRST_N,
        -- Outputs
        POWER_ON_RESET_N => POWER_ON_RESET_N_net_0 
        );

end RTL;
