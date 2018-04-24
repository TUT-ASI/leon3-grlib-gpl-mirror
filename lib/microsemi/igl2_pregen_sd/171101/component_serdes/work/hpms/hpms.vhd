----------------------------------------------------------------------
-- Created by SmartDesign Wed Nov  1 13:13:56 2017
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
-- hpms entity declaration
----------------------------------------------------------------------
entity hpms is
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
        SPI_0_DO                    : out   std_logic;
        -- Inouts
        MDDR_DM_RDQS                : inout std_logic_vector(1 downto 0);
        MDDR_DQ                     : inout std_logic_vector(15 downto 0);
        MDDR_DQS                    : inout std_logic_vector(1 downto 0);
        SPI_0_CLK                   : inout std_logic;
        SPI_0_SS0                   : inout std_logic
        );
end hpms;
----------------------------------------------------------------------
-- hpms architecture body
----------------------------------------------------------------------
architecture RTL of hpms is
----------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------
-- hpms_sb
component hpms_sb
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
        FAB_CCC_GL3                 : out   std_logic;
        FAB_CCC_LOCK                : out   std_logic;
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
end component;
----------------------------------------------------------------------
-- Signal declarations
----------------------------------------------------------------------
signal COMM_BLK_INT_net_0                  : std_logic;
signal FIC_0_AHB_MASTER_HADDR              : std_logic_vector(31 downto 0);
signal FIC_0_AHB_MASTER_HSIZE              : std_logic_vector(1 downto 0);
signal FIC_0_AHB_MASTER_HTRANS             : std_logic_vector(1 downto 0);
signal FIC_0_AHB_MASTER_HWDATA             : std_logic_vector(31 downto 0);
signal FIC_0_AHB_MASTER_HWRITE             : std_logic;
signal FIC_0_AHB_SLAVE_HRDATA              : std_logic_vector(31 downto 0);
signal FIC_0_AHB_SLAVE_HREADYOUT           : std_logic;
signal FIC_0_AHB_SLAVE_HRESP               : std_logic;
signal FIC_0_CLK_net_0                     : std_logic;
signal FIC_0_LOCK_net_0                    : std_logic;
signal HPMS_DDR_FIC_SUBSYSTEM_CLK_net_0    : std_logic;
signal HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_0   : std_logic;
signal HPMS_INT_M2F_net_0                  : std_logic_vector(15 downto 0);
signal HPMS_READY_net_0                    : std_logic;
signal MDDR_ADDR_net_0                     : std_logic_vector(15 downto 0);
signal MDDR_APB_SLAVE_PRDATA               : std_logic_vector(15 downto 0);
signal MDDR_APB_SLAVE_PREADY               : std_logic;
signal MDDR_APB_SLAVE_PSLVERR              : std_logic;
signal MDDR_BA_net_0                       : std_logic_vector(2 downto 0);
signal MDDR_CAS_N_net_0                    : std_logic;
signal MDDR_CKE_net_0                      : std_logic;
signal MDDR_CLK_net_0                      : std_logic;
signal MDDR_CLK_N_net_0                    : std_logic;
signal MDDR_CS_N_net_0                     : std_logic;
signal MDDR_DDR_AHB0_SLAVE_HRDATA          : std_logic_vector(31 downto 0);
signal MDDR_DDR_AHB0_SLAVE_HREADYOUT       : std_logic;
signal MDDR_DDR_AHB0_SLAVE_HRESP           : std_logic;
signal MDDR_DQS_TMATCH_0_OUT_net_0         : std_logic;
signal MDDR_ODT_net_0                      : std_logic;
signal MDDR_RAS_N_net_0                    : std_logic;
signal MDDR_RESET_N_net_0                  : std_logic;
signal MDDR_WE_N_net_0                     : std_logic;
signal SPI_0_DO_net_0                      : std_logic;
signal SPI_0_DO_net_1                      : std_logic;
signal MDDR_DQS_TMATCH_0_OUT_net_1         : std_logic;
signal MDDR_CAS_N_net_1                    : std_logic;
signal MDDR_CLK_net_1                      : std_logic;
signal MDDR_CLK_N_net_1                    : std_logic;
signal MDDR_CKE_net_1                      : std_logic;
signal MDDR_CS_N_net_1                     : std_logic;
signal MDDR_ODT_net_1                      : std_logic;
signal MDDR_RAS_N_net_1                    : std_logic;
signal MDDR_RESET_N_net_1                  : std_logic;
signal MDDR_WE_N_net_1                     : std_logic;
signal MDDR_ADDR_net_1                     : std_logic_vector(15 downto 0);
signal MDDR_BA_net_1                       : std_logic_vector(2 downto 0);
signal HPMS_READY_net_1                    : std_logic;
signal HPMS_DDR_FIC_SUBSYSTEM_CLK_net_1    : std_logic;
signal HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_1   : std_logic;
signal FIC_0_AHB_SLAVE_HRDATA_net_0        : std_logic_vector(31 downto 0);
signal FIC_0_AHB_SLAVE_HREADYOUT_net_0     : std_logic;
signal FIC_0_AHB_SLAVE_HRESP_net_0         : std_logic;
signal COMM_BLK_INT_net_1                  : std_logic;
signal HPMS_INT_M2F_net_1                  : std_logic_vector(15 downto 0);
signal FIC_0_AHB_MASTER_HADDR_net_0        : std_logic_vector(31 downto 0);
signal FIC_0_AHB_MASTER_HTRANS_net_0       : std_logic_vector(1 downto 0);
signal FIC_0_AHB_MASTER_HWRITE_net_0       : std_logic;
signal FIC_0_AHB_MASTER_HSIZE_net_0        : std_logic_vector(1 downto 0);
signal FIC_0_AHB_MASTER_HWDATA_net_0       : std_logic_vector(31 downto 0);
signal MDDR_APB_SLAVE_PRDATA_net_0         : std_logic_vector(15 downto 0);
signal MDDR_APB_SLAVE_PREADY_net_0         : std_logic;
signal MDDR_APB_SLAVE_PSLVERR_net_0        : std_logic;
signal MDDR_DDR_AHB0_SLAVE_HRDATA_net_0    : std_logic_vector(31 downto 0);
signal MDDR_DDR_AHB0_SLAVE_HREADYOUT_net_0 : std_logic;
signal MDDR_DDR_AHB0_SLAVE_HRESP_net_0     : std_logic;
signal FIC_0_CLK_net_1                     : std_logic;
signal FIC_0_LOCK_net_1                    : std_logic;

begin
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
 MDDR_ADDR_net_1                     <= MDDR_ADDR_net_0;
 MDDR_ADDR(15 downto 0)              <= MDDR_ADDR_net_1;
 MDDR_BA_net_1                       <= MDDR_BA_net_0;
 MDDR_BA(2 downto 0)                 <= MDDR_BA_net_1;
 HPMS_READY_net_1                    <= HPMS_READY_net_0;
 HPMS_READY                          <= HPMS_READY_net_1;
 HPMS_DDR_FIC_SUBSYSTEM_CLK_net_1    <= HPMS_DDR_FIC_SUBSYSTEM_CLK_net_0;
 HPMS_DDR_FIC_SUBSYSTEM_CLK          <= HPMS_DDR_FIC_SUBSYSTEM_CLK_net_1;
 HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_1   <= HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_0;
 HPMS_DDR_FIC_SUBSYSTEM_LOCK         <= HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_1;
 FIC_0_AHB_SLAVE_HRDATA_net_0        <= FIC_0_AHB_SLAVE_HRDATA;
 FIC_0_AHB_S_HRDATA(31 downto 0)     <= FIC_0_AHB_SLAVE_HRDATA_net_0;
 FIC_0_AHB_SLAVE_HREADYOUT_net_0     <= FIC_0_AHB_SLAVE_HREADYOUT;
 FIC_0_AHB_S_HREADYOUT               <= FIC_0_AHB_SLAVE_HREADYOUT_net_0;
 FIC_0_AHB_SLAVE_HRESP_net_0         <= FIC_0_AHB_SLAVE_HRESP;
 FIC_0_AHB_S_HRESP                   <= FIC_0_AHB_SLAVE_HRESP_net_0;
 COMM_BLK_INT_net_1                  <= COMM_BLK_INT_net_0;
 COMM_BLK_INT                        <= COMM_BLK_INT_net_1;
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
 MDDR_APB_SLAVE_PRDATA_net_0         <= MDDR_APB_SLAVE_PRDATA;
 MDDR_APB_S_PRDATA(15 downto 0)      <= MDDR_APB_SLAVE_PRDATA_net_0;
 MDDR_APB_SLAVE_PREADY_net_0         <= MDDR_APB_SLAVE_PREADY;
 MDDR_APB_S_PREADY                   <= MDDR_APB_SLAVE_PREADY_net_0;
 MDDR_APB_SLAVE_PSLVERR_net_0        <= MDDR_APB_SLAVE_PSLVERR;
 MDDR_APB_S_PSLVERR                  <= MDDR_APB_SLAVE_PSLVERR_net_0;
 MDDR_DDR_AHB0_SLAVE_HRDATA_net_0    <= MDDR_DDR_AHB0_SLAVE_HRDATA;
 MDDR_DDR_AHB0_S_HRDATA(31 downto 0) <= MDDR_DDR_AHB0_SLAVE_HRDATA_net_0;
 MDDR_DDR_AHB0_SLAVE_HREADYOUT_net_0 <= MDDR_DDR_AHB0_SLAVE_HREADYOUT;
 MDDR_DDR_AHB0_S_HREADYOUT           <= MDDR_DDR_AHB0_SLAVE_HREADYOUT_net_0;
 MDDR_DDR_AHB0_SLAVE_HRESP_net_0     <= MDDR_DDR_AHB0_SLAVE_HRESP;
 MDDR_DDR_AHB0_S_HRESP               <= MDDR_DDR_AHB0_SLAVE_HRESP_net_0;
 FIC_0_CLK_net_1                     <= FIC_0_CLK_net_0;
 FIC_0_CLK                           <= FIC_0_CLK_net_1;
 FIC_0_LOCK_net_1                    <= FIC_0_LOCK_net_0;
 FIC_0_LOCK                          <= FIC_0_LOCK_net_1;
----------------------------------------------------------------------
-- Component instances
----------------------------------------------------------------------
-- hpms_sb_0
hpms_sb_0 : hpms_sb
    port map( 
        -- Inputs
        SPI_0_DI                    => SPI_0_DI,
        MDDR_DQS_TMATCH_0_IN        => MDDR_DQS_TMATCH_0_IN,
        FAB_RESET_N                 => FAB_RESET_N,
        MDDR_APB_S_PCLK             => MDDR_APB_S_PCLK,
        MDDR_APB_S_PRESET_N         => MDDR_APB_S_PRESET_N,
        MDDR_CORE_RESET_N           => MDDR_CORE_RESET_N,
        DEVRST_N                    => DEVRST_N,
        MDDR_APB_S_PSEL             => MDDR_APB_S_PSEL,
        MDDR_APB_S_PENABLE          => MDDR_APB_S_PENABLE,
        MDDR_APB_S_PWRITE           => MDDR_APB_S_PWRITE,
        MDDR_APB_S_PADDR            => MDDR_APB_S_PADDR,
        MDDR_APB_S_PWDATA           => MDDR_APB_S_PWDATA,
        DMA_DMAREADY_FIC_0          => DMA_DMAREADY_FIC_0,
        DMA_DMAREADY_FIC_1          => DMA_DMAREADY_FIC_1,
        FIC_0_AHB_S_HADDR           => FIC_0_AHB_S_HADDR,
        FIC_0_AHB_S_HTRANS          => FIC_0_AHB_S_HTRANS,
        FIC_0_AHB_S_HWRITE          => FIC_0_AHB_S_HWRITE,
        FIC_0_AHB_S_HSIZE           => FIC_0_AHB_S_HSIZE,
        FIC_0_AHB_S_HWDATA          => FIC_0_AHB_S_HWDATA,
        FIC_0_AHB_S_HSEL            => FIC_0_AHB_S_HSEL,
        FIC_0_AHB_S_HMASTLOCK       => FIC_0_AHB_S_HMASTLOCK,
        FIC_0_AHB_S_HREADY          => FIC_0_AHB_S_HREADY,
        MDDR_DDR_AHB0_S_HADDR       => MDDR_DDR_AHB0_S_HADDR,
        MDDR_DDR_AHB0_S_HTRANS      => MDDR_DDR_AHB0_S_HTRANS,
        MDDR_DDR_AHB0_S_HWRITE      => MDDR_DDR_AHB0_S_HWRITE,
        MDDR_DDR_AHB0_S_HSIZE       => MDDR_DDR_AHB0_S_HSIZE,
        MDDR_DDR_AHB0_S_HBURST      => MDDR_DDR_AHB0_S_HBURST,
        MDDR_DDR_AHB0_S_HWDATA      => MDDR_DDR_AHB0_S_HWDATA,
        MDDR_DDR_AHB0_S_HSEL        => MDDR_DDR_AHB0_S_HSEL,
        MDDR_DDR_AHB0_S_HMASTLOCK   => MDDR_DDR_AHB0_S_HMASTLOCK,
        MDDR_DDR_AHB0_S_HREADY      => MDDR_DDR_AHB0_S_HREADY,
        FIC_0_AHB_M_HRDATA          => FIC_0_AHB_M_HRDATA,
        FIC_0_AHB_M_HREADY          => FIC_0_AHB_M_HREADY,
        FIC_0_AHB_M_HRESP           => FIC_0_AHB_M_HRESP,
        -- Outputs
        SPI_0_DO                    => SPI_0_DO_net_0,
        MDDR_DQS_TMATCH_0_OUT       => MDDR_DQS_TMATCH_0_OUT_net_0,
        MDDR_CAS_N                  => MDDR_CAS_N_net_0,
        MDDR_CLK                    => MDDR_CLK_net_0,
        MDDR_CLK_N                  => MDDR_CLK_N_net_0,
        MDDR_CKE                    => MDDR_CKE_net_0,
        MDDR_CS_N                   => MDDR_CS_N_net_0,
        MDDR_ODT                    => MDDR_ODT_net_0,
        MDDR_RAS_N                  => MDDR_RAS_N_net_0,
        MDDR_RESET_N                => MDDR_RESET_N_net_0,
        MDDR_WE_N                   => MDDR_WE_N_net_0,
        POWER_ON_RESET_N            => OPEN,
        HPMS_DDR_FIC_SUBSYSTEM_CLK  => HPMS_DDR_FIC_SUBSYSTEM_CLK_net_0,
        HPMS_DDR_FIC_SUBSYSTEM_LOCK => HPMS_DDR_FIC_SUBSYSTEM_LOCK_net_0,
        FIC_0_CLK                   => FIC_0_CLK_net_0,
        FIC_0_LOCK                  => FIC_0_LOCK_net_0,
        FAB_CCC_GL3                 => OPEN,
        FAB_CCC_LOCK                => OPEN,
        HPMS_READY                  => HPMS_READY_net_0,
        MDDR_APB_S_PREADY           => MDDR_APB_SLAVE_PREADY,
        MDDR_APB_S_PSLVERR          => MDDR_APB_SLAVE_PSLVERR,
        COMM_BLK_INT                => COMM_BLK_INT_net_0,
        MDDR_ADDR                   => MDDR_ADDR_net_0,
        MDDR_BA                     => MDDR_BA_net_0,
        MDDR_APB_S_PRDATA           => MDDR_APB_SLAVE_PRDATA,
        HPMS_INT_M2F                => HPMS_INT_M2F_net_0,
        FIC_0_AHB_S_HRDATA          => FIC_0_AHB_SLAVE_HRDATA,
        FIC_0_AHB_S_HREADYOUT       => FIC_0_AHB_SLAVE_HREADYOUT,
        FIC_0_AHB_S_HRESP           => FIC_0_AHB_SLAVE_HRESP,
        MDDR_DDR_AHB0_S_HRDATA      => MDDR_DDR_AHB0_SLAVE_HRDATA,
        MDDR_DDR_AHB0_S_HREADYOUT   => MDDR_DDR_AHB0_SLAVE_HREADYOUT,
        MDDR_DDR_AHB0_S_HRESP       => MDDR_DDR_AHB0_SLAVE_HRESP,
        FIC_0_AHB_M_HADDR           => FIC_0_AHB_MASTER_HADDR,
        FIC_0_AHB_M_HTRANS          => FIC_0_AHB_MASTER_HTRANS,
        FIC_0_AHB_M_HWRITE          => FIC_0_AHB_MASTER_HWRITE,
        FIC_0_AHB_M_HSIZE           => FIC_0_AHB_MASTER_HSIZE,
        FIC_0_AHB_M_HWDATA          => FIC_0_AHB_MASTER_HWDATA,
        -- Inouts
        SPI_0_CLK                   => SPI_0_CLK,
        SPI_0_SS0                   => SPI_0_SS0,
        MDDR_DM_RDQS                => MDDR_DM_RDQS,
        MDDR_DQ                     => MDDR_DQ,
        MDDR_DQS                    => MDDR_DQS 
        );

end RTL;
