-- Version: v11.8 11.8.0.26

library ieee;
use ieee.std_logic_1164.all;
library smartfusion2;
use smartfusion2.all;

entity igl_serdes_epcs_SERDES_IF_0_SERDES_IF is

    port( RXD0_P               : in    std_logic;
          RXD0_N               : in    std_logic;
          RXD1_P               : in    std_logic;
          RXD1_N               : in    std_logic;
          RXD2_P               : in    std_logic;
          RXD2_N               : in    std_logic;
          RXD3_P               : in    std_logic;
          RXD3_N               : in    std_logic;
          TXD0_P               : out   std_logic;
          TXD0_N               : out   std_logic;
          TXD1_P               : out   std_logic;
          TXD1_N               : out   std_logic;
          TXD2_P               : out   std_logic;
          TXD2_N               : out   std_logic;
          TXD3_P               : out   std_logic;
          TXD3_N               : out   std_logic;
          APB_S_PRDATA         : out   std_logic_vector(31 downto 0);
          APB_S_PREADY         : out   std_logic;
          APB_S_PSLVERR        : out   std_logic;
          APB_S_PADDR          : in    std_logic_vector(13 downto 2);
          APB_S_PENABLE        : in    std_logic;
          APB_S_PSEL           : in    std_logic;
          APB_S_PWDATA         : in    std_logic_vector(31 downto 0);
          APB_S_PWRITE         : in    std_logic;
          APB_S_PCLK           : in    std_logic;
          APB_S_PRESET_N       : in    std_logic;
          REFCLK1_P            : in    std_logic;
          REFCLK1_N            : in    std_logic;
          REFCLK1_OUT          : out   std_logic;
          EPCS_3_READY         : out   std_logic;
          EPCS_3_TX_CLK_STABLE : out   std_logic;
          EPCS_3_TX_CLK        : out   std_logic;
          EPCS_3_RX_CLK        : out   std_logic;
          EPCS_3_PWRDN         : in    std_logic;
          EPCS_3_TX_VAL        : in    std_logic;
          EPCS_3_TX_OOB        : in    std_logic;
          EPCS_3_RX_ERR        : in    std_logic;
          EPCS_3_RX_VAL        : out   std_logic;
          EPCS_3_RX_IDLE       : out   std_logic;
          EPCS_3_RESET_N       : in    std_logic;
          EPCS_3_TX_RESET_N    : out   std_logic;
          EPCS_3_RX_RESET_N    : out   std_logic;
          EPCS_3_RX_DATA       : out   std_logic_vector(19 downto 0);
          EPCS_3_TX_DATA       : in    std_logic_vector(19 downto 0)
        );

end igl_serdes_epcs_SERDES_IF_0_SERDES_IF;

architecture DEF_ARCH of igl_serdes_epcs_SERDES_IF_0_SERDES_IF is 

  component INBUF_DIFF
    generic (IOSTD:string := "");

    port( PADP : in    std_logic := 'U';
          PADN : in    std_logic := 'U';
          Y    : out   std_logic
        );
  end component;

  component VCC
    port( Y : out   std_logic
        );
  end component;

  component GND
    port( Y : out   std_logic
        );
  end component;

  component SERDESIF_0

            generic (INIT:std_logic_vector(609 downto 0) := "00" & x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"; 
        ACT_CONFIG:string := ""; ACT_SIM:integer := 0);

    port( APB_PRDATA            : out   std_logic_vector(31 downto 0);
          APB_PREADY            : out   std_logic;
          APB_PSLVERR           : out   std_logic;
          ATXCLKSTABLE          : out   std_logic_vector(1 downto 0);
          EPCS_READY            : out   std_logic_vector(1 downto 0);
          EPCS_RXCLK            : out   std_logic_vector(1 downto 0);
          EPCS_RXCLK_0          : out   std_logic;
          EPCS_RXCLK_1          : out   std_logic;
          EPCS_RXDATA           : out   std_logic_vector(39 downto 0);
          EPCS_RXIDLE           : out   std_logic_vector(1 downto 0);
          EPCS_RXRSTN           : out   std_logic_vector(1 downto 0);
          EPCS_RXVAL            : out   std_logic_vector(1 downto 0);
          EPCS_TXCLK            : out   std_logic_vector(1 downto 0);
          EPCS_TXCLK_0          : out   std_logic;
          EPCS_TXCLK_1          : out   std_logic;
          EPCS_TXRSTN           : out   std_logic_vector(1 downto 0);
          FATC_RESET_N          : out   std_logic;
          H2FCALIB0             : out   std_logic;
          H2FCALIB1             : out   std_logic;
          M_ARADDR              : out   std_logic_vector(31 downto 0);
          M_ARBURST             : out   std_logic_vector(1 downto 0);
          M_ARID                : out   std_logic_vector(3 downto 0);
          M_ARLEN               : out   std_logic_vector(3 downto 0);
          M_ARSIZE              : out   std_logic_vector(1 downto 0);
          M_ARVALID             : out   std_logic;
          M_AWADDR_HADDR        : out   std_logic_vector(31 downto 0);
          M_AWBURST_HTRANS      : out   std_logic_vector(1 downto 0);
          M_AWID                : out   std_logic_vector(3 downto 0);
          M_AWLEN_HBURST        : out   std_logic_vector(3 downto 0);
          M_AWSIZE_HSIZE        : out   std_logic_vector(1 downto 0);
          M_AWVALID_HWRITE      : out   std_logic;
          M_BREADY              : out   std_logic;
          M_RREADY              : out   std_logic;
          M_WDATA_HWDATA        : out   std_logic_vector(63 downto 0);
          M_WID                 : out   std_logic_vector(3 downto 0);
          M_WLAST               : out   std_logic;
          M_WSTRB               : out   std_logic_vector(7 downto 0);
          M_WVALID              : out   std_logic;
          PCIE_SYSTEM_INT       : out   std_logic;
          PLL_LOCK_INT          : out   std_logic;
          PLL_LOCKLOST_INT      : out   std_logic;
          S_ARREADY             : out   std_logic;
          S_AWREADY             : out   std_logic;
          S_BID                 : out   std_logic_vector(3 downto 0);
          S_BRESP_HRESP         : out   std_logic_vector(1 downto 0);
          S_BVALID              : out   std_logic;
          S_RDATA_HRDATA        : out   std_logic_vector(63 downto 0);
          S_RID                 : out   std_logic_vector(3 downto 0);
          S_RLAST               : out   std_logic;
          S_RRESP               : out   std_logic_vector(1 downto 0);
          S_RVALID              : out   std_logic;
          S_WREADY_HREADYOUT    : out   std_logic;
          SPLL_LOCK             : out   std_logic;
          WAKE_N                : out   std_logic;
          XAUI_OUT_CLK          : out   std_logic;
          APB_CLK               : in    std_logic := 'U';
          APB_PADDR             : in    std_logic_vector(13 downto 2) := (others => 'U');
          APB_PENABLE           : in    std_logic := 'U';
          APB_PSEL              : in    std_logic := 'U';
          APB_PWDATA            : in    std_logic_vector(31 downto 0) := (others => 'U');
          APB_PWRITE            : in    std_logic := 'U';
          APB_RSTN              : in    std_logic := 'U';
          CLK_BASE              : in    std_logic := 'U';
          EPCS_PWRDN            : in    std_logic_vector(1 downto 0) := (others => 'U');
          EPCS_RSTN             : in    std_logic_vector(1 downto 0) := (others => 'U');
          EPCS_RXERR            : in    std_logic_vector(1 downto 0) := (others => 'U');
          EPCS_TXDATA           : in    std_logic_vector(39 downto 0) := (others => 'U');
          EPCS_TXOOB            : in    std_logic_vector(1 downto 0) := (others => 'U');
          EPCS_TXVAL            : in    std_logic_vector(1 downto 0) := (others => 'U');
          F2HCALIB0             : in    std_logic := 'U';
          F2HCALIB1             : in    std_logic := 'U';
          FAB_PLL_LOCK          : in    std_logic := 'U';
          FAB_REF_CLK           : in    std_logic := 'U';
          M_ARREADY             : in    std_logic := 'U';
          M_AWREADY             : in    std_logic := 'U';
          M_BID                 : in    std_logic_vector(3 downto 0) := (others => 'U');
          M_BRESP_HRESP         : in    std_logic_vector(1 downto 0) := (others => 'U');
          M_BVALID              : in    std_logic := 'U';
          M_RDATA_HRDATA        : in    std_logic_vector(63 downto 0) := (others => 'U');
          M_RID                 : in    std_logic_vector(3 downto 0) := (others => 'U');
          M_RLAST               : in    std_logic := 'U';
          M_RRESP               : in    std_logic_vector(1 downto 0) := (others => 'U');
          M_RVALID              : in    std_logic := 'U';
          M_WREADY_HREADY       : in    std_logic := 'U';
          PCIE_INTERRUPT        : in    std_logic_vector(3 downto 0) := (others => 'U');
          PERST_N               : in    std_logic := 'U';
          S_ARADDR              : in    std_logic_vector(31 downto 0) := (others => 'U');
          S_ARBURST             : in    std_logic_vector(1 downto 0) := (others => 'U');
          S_ARID                : in    std_logic_vector(3 downto 0) := (others => 'U');
          S_ARLEN               : in    std_logic_vector(3 downto 0) := (others => 'U');
          S_ARLOCK              : in    std_logic_vector(1 downto 0) := (others => 'U');
          S_ARSIZE              : in    std_logic_vector(1 downto 0) := (others => 'U');
          S_ARVALID             : in    std_logic := 'U';
          S_AWADDR_HADDR        : in    std_logic_vector(31 downto 0) := (others => 'U');
          S_AWBURST_HTRANS      : in    std_logic_vector(1 downto 0) := (others => 'U');
          S_AWID_HSEL           : in    std_logic_vector(3 downto 0) := (others => 'U');
          S_AWLEN_HBURST        : in    std_logic_vector(3 downto 0) := (others => 'U');
          S_AWLOCK              : in    std_logic_vector(1 downto 0) := (others => 'U');
          S_AWSIZE_HSIZE        : in    std_logic_vector(1 downto 0) := (others => 'U');
          S_AWVALID_HWRITE      : in    std_logic := 'U';
          S_BREADY_HREADY       : in    std_logic := 'U';
          S_RREADY              : in    std_logic := 'U';
          S_WDATA_HWDATA        : in    std_logic_vector(63 downto 0) := (others => 'U');
          S_WID                 : in    std_logic_vector(3 downto 0) := (others => 'U');
          S_WLAST               : in    std_logic := 'U';
          S_WSTRB               : in    std_logic_vector(7 downto 0) := (others => 'U');
          S_WVALID              : in    std_logic := 'U';
          SERDESIF_CORE_RESET_N : in    std_logic := 'U';
          SERDESIF_PHY_RESET_N  : in    std_logic := 'U';
          WAKE_REQ              : in    std_logic := 'U';
          XAUI_FB_CLK           : in    std_logic := 'U';
          RXD3_P                : in    std_logic := 'U';
          RXD2_P                : in    std_logic := 'U';
          RXD1_P                : in    std_logic := 'U';
          RXD0_P                : in    std_logic := 'U';
          RXD3_N                : in    std_logic := 'U';
          RXD2_N                : in    std_logic := 'U';
          RXD1_N                : in    std_logic := 'U';
          RXD0_N                : in    std_logic := 'U';
          TXD3_P                : out   std_logic;
          TXD2_P                : out   std_logic;
          TXD1_P                : out   std_logic;
          TXD0_P                : out   std_logic;
          TXD3_N                : out   std_logic;
          TXD2_N                : out   std_logic;
          TXD1_N                : out   std_logic;
          TXD0_N                : out   std_logic;
          REFCLK0               : in    std_logic := 'U';
          REFCLK1               : in    std_logic := 'U'
        );
  end component;

    signal gnd_net, vcc_net, REFCLK1_net : std_logic;
    signal nc228, nc203, nc265, nc216, nc194, nc151, nc23, nc175, 
        nc250, nc58, nc116, nc74, nc133, nc238, nc167, nc84, nc39, 
        nc72, nc256, nc212, nc205, nc82, nc145, nc181, nc160, 
        nc57, nc156, nc280, nc125, nc211, nc73, nc107, nc66, nc83, 
        nc9, nc252, nc171, nc54, nc286, nc135, nc41, nc100, nc270, 
        nc52, nc251, nc186, nc29, nc269, nc118, nc60, nc141, 
        nc276, nc193, nc214, nc282, nc240, nc45, nc53, nc121, 
        nc176, nc220, nc158, nc281, nc209, nc246, nc162, nc11, 
        nc272, nc131, nc254, nc267, nc96, nc79, nc226, nc146, 
        nc230, nc89, nc119, nc48, nc271, nc213, nc126, nc195, 
        nc188, nc242, nc15, nc236, nc102, nc3, nc207, nc47, nc90, 
        nc284, nc222, nc159, nc136, nc241, nc253, nc178, nc215, 
        nc59, nc221, nc232, nc274, nc18, nc44, nc117, nc189, 
        nc164, nc148, nc42, nc231, nc191, nc255, nc283, nc17, nc2, 
        nc110, nc128, nc244, nc43, nc179, nc157, nc36, nc224, 
        nc273, nc61, nc104, nc138, nc14, nc285, nc150, nc196, 
        nc234, nc149, nc12, nc219, nc30, nc243, nc187, nc65, nc7, 
        nc129, nc275, nc8, nc223, nc13, nc180, nc26, nc177, nc139, 
        nc259, nc245, nc233, nc163, nc268, nc112, nc68, nc49, 
        nc217, nc170, nc91, nc225, nc5, nc20, nc198, nc147, nc67, 
        nc152, nc127, nc103, nc235, nc76, nc208, nc140, nc257, 
        nc86, nc95, nc120, nc165, nc279, nc137, nc64, nc19, nc70, 
        nc182, nc62, nc199, nc80, nc130, nc287, nc98, nc249, 
        nc114, nc56, nc105, nc63, nc172, nc229, nc277, nc97, 
        nc161, nc31, nc154, nc50, nc260, nc239, nc142, nc247, 
        nc94, nc197, nc122, nc266, nc35, nc4, nc227, nc92, nc101, 
        nc184, nc200, nc190, nc166, nc132, nc21, nc237, nc93, 
        nc262, nc69, nc206, nc174, nc38, nc113, nc218, nc106, 
        nc261, nc25, nc1, nc37, nc202, nc144, nc153, nc46, nc258, 
        nc71, nc124, nc81, nc201, nc168, nc34, nc28, nc115, nc264, 
        nc192, nc134, nc32, nc40, nc99, nc75, nc183, nc288, nc85, 
        nc27, nc108, nc16, nc155, nc51, nc33, nc204, nc173, nc278, 
        nc169, nc78, nc263, nc24, nc88, nc111, nc55, nc10, nc22, 
        nc210, nc185, nc143, nc248, nc77, nc6, nc109, nc87, nc123
         : std_logic;

begin 

    REFCLK1_OUT <= REFCLK1_net;

    refclk1_inbuf_diff : INBUF_DIFF
      port map(PADP => REFCLK1_P, PADN => REFCLK1_N, Y => 
        REFCLK1_net);
    
    vcc_inst : VCC
      port map(Y => vcc_net);
    
    gnd_inst : GND
      port map(Y => gnd_net);
    
    SERDESIF_INST : SERDESIF_0

              generic map(INIT => "00" & x"000000000000000000000000000000000000000000000000000000003780A0000000000000000000000000000000000000022787AFFF800000000007C3F9D64A0081FFFFFFFFFEFFFFFFFFFF",
         ACT_CONFIG => "SERDESIF_0", ACT_SIM => 2)

      port map(APB_PRDATA(31) => APB_S_PRDATA(31), APB_PRDATA(30)
         => APB_S_PRDATA(30), APB_PRDATA(29) => APB_S_PRDATA(29), 
        APB_PRDATA(28) => APB_S_PRDATA(28), APB_PRDATA(27) => 
        APB_S_PRDATA(27), APB_PRDATA(26) => APB_S_PRDATA(26), 
        APB_PRDATA(25) => APB_S_PRDATA(25), APB_PRDATA(24) => 
        APB_S_PRDATA(24), APB_PRDATA(23) => APB_S_PRDATA(23), 
        APB_PRDATA(22) => APB_S_PRDATA(22), APB_PRDATA(21) => 
        APB_S_PRDATA(21), APB_PRDATA(20) => APB_S_PRDATA(20), 
        APB_PRDATA(19) => APB_S_PRDATA(19), APB_PRDATA(18) => 
        APB_S_PRDATA(18), APB_PRDATA(17) => APB_S_PRDATA(17), 
        APB_PRDATA(16) => APB_S_PRDATA(16), APB_PRDATA(15) => 
        APB_S_PRDATA(15), APB_PRDATA(14) => APB_S_PRDATA(14), 
        APB_PRDATA(13) => APB_S_PRDATA(13), APB_PRDATA(12) => 
        APB_S_PRDATA(12), APB_PRDATA(11) => APB_S_PRDATA(11), 
        APB_PRDATA(10) => APB_S_PRDATA(10), APB_PRDATA(9) => 
        APB_S_PRDATA(9), APB_PRDATA(8) => APB_S_PRDATA(8), 
        APB_PRDATA(7) => APB_S_PRDATA(7), APB_PRDATA(6) => 
        APB_S_PRDATA(6), APB_PRDATA(5) => APB_S_PRDATA(5), 
        APB_PRDATA(4) => APB_S_PRDATA(4), APB_PRDATA(3) => 
        APB_S_PRDATA(3), APB_PRDATA(2) => APB_S_PRDATA(2), 
        APB_PRDATA(1) => APB_S_PRDATA(1), APB_PRDATA(0) => 
        APB_S_PRDATA(0), APB_PREADY => APB_S_PREADY, APB_PSLVERR
         => APB_S_PSLVERR, ATXCLKSTABLE(1) => 
        EPCS_3_TX_CLK_STABLE, ATXCLKSTABLE(0) => nc228, 
        EPCS_READY(1) => EPCS_3_READY, EPCS_READY(0) => nc203, 
        EPCS_RXCLK(1) => EPCS_3_RX_CLK, EPCS_RXCLK(0) => nc265, 
        EPCS_RXCLK_0 => OPEN, EPCS_RXCLK_1 => OPEN, 
        EPCS_RXDATA(39) => EPCS_3_RX_DATA(19), EPCS_RXDATA(38)
         => EPCS_3_RX_DATA(18), EPCS_RXDATA(37) => 
        EPCS_3_RX_DATA(17), EPCS_RXDATA(36) => EPCS_3_RX_DATA(16), 
        EPCS_RXDATA(35) => EPCS_3_RX_DATA(15), EPCS_RXDATA(34)
         => EPCS_3_RX_DATA(14), EPCS_RXDATA(33) => 
        EPCS_3_RX_DATA(13), EPCS_RXDATA(32) => EPCS_3_RX_DATA(12), 
        EPCS_RXDATA(31) => EPCS_3_RX_DATA(11), EPCS_RXDATA(30)
         => EPCS_3_RX_DATA(10), EPCS_RXDATA(29) => 
        EPCS_3_RX_DATA(9), EPCS_RXDATA(28) => EPCS_3_RX_DATA(8), 
        EPCS_RXDATA(27) => EPCS_3_RX_DATA(7), EPCS_RXDATA(26) => 
        EPCS_3_RX_DATA(6), EPCS_RXDATA(25) => EPCS_3_RX_DATA(5), 
        EPCS_RXDATA(24) => EPCS_3_RX_DATA(4), EPCS_RXDATA(23) => 
        EPCS_3_RX_DATA(3), EPCS_RXDATA(22) => EPCS_3_RX_DATA(2), 
        EPCS_RXDATA(21) => EPCS_3_RX_DATA(1), EPCS_RXDATA(20) => 
        EPCS_3_RX_DATA(0), EPCS_RXDATA(19) => nc216, 
        EPCS_RXDATA(18) => nc194, EPCS_RXDATA(17) => nc151, 
        EPCS_RXDATA(16) => nc23, EPCS_RXDATA(15) => nc175, 
        EPCS_RXDATA(14) => nc250, EPCS_RXDATA(13) => nc58, 
        EPCS_RXDATA(12) => nc116, EPCS_RXDATA(11) => nc74, 
        EPCS_RXDATA(10) => nc133, EPCS_RXDATA(9) => nc238, 
        EPCS_RXDATA(8) => nc167, EPCS_RXDATA(7) => nc84, 
        EPCS_RXDATA(6) => nc39, EPCS_RXDATA(5) => nc72, 
        EPCS_RXDATA(4) => nc256, EPCS_RXDATA(3) => nc212, 
        EPCS_RXDATA(2) => nc205, EPCS_RXDATA(1) => nc82, 
        EPCS_RXDATA(0) => nc145, EPCS_RXIDLE(1) => EPCS_3_RX_IDLE, 
        EPCS_RXIDLE(0) => nc181, EPCS_RXRSTN(1) => 
        EPCS_3_RX_RESET_N, EPCS_RXRSTN(0) => nc160, EPCS_RXVAL(1)
         => EPCS_3_RX_VAL, EPCS_RXVAL(0) => nc57, EPCS_TXCLK(1)
         => EPCS_3_TX_CLK, EPCS_TXCLK(0) => nc156, EPCS_TXCLK_0
         => OPEN, EPCS_TXCLK_1 => OPEN, EPCS_TXRSTN(1) => 
        EPCS_3_TX_RESET_N, EPCS_TXRSTN(0) => nc280, FATC_RESET_N
         => OPEN, H2FCALIB0 => OPEN, H2FCALIB1 => OPEN, 
        M_ARADDR(31) => nc125, M_ARADDR(30) => nc211, 
        M_ARADDR(29) => nc73, M_ARADDR(28) => nc107, M_ARADDR(27)
         => nc66, M_ARADDR(26) => nc83, M_ARADDR(25) => nc9, 
        M_ARADDR(24) => nc252, M_ARADDR(23) => nc171, 
        M_ARADDR(22) => nc54, M_ARADDR(21) => nc286, M_ARADDR(20)
         => nc135, M_ARADDR(19) => nc41, M_ARADDR(18) => nc100, 
        M_ARADDR(17) => nc270, M_ARADDR(16) => nc52, M_ARADDR(15)
         => nc251, M_ARADDR(14) => nc186, M_ARADDR(13) => nc29, 
        M_ARADDR(12) => nc269, M_ARADDR(11) => nc118, 
        M_ARADDR(10) => nc60, M_ARADDR(9) => nc141, M_ARADDR(8)
         => nc276, M_ARADDR(7) => nc193, M_ARADDR(6) => nc214, 
        M_ARADDR(5) => nc282, M_ARADDR(4) => nc240, M_ARADDR(3)
         => nc45, M_ARADDR(2) => nc53, M_ARADDR(1) => nc121, 
        M_ARADDR(0) => nc176, M_ARBURST(1) => nc220, M_ARBURST(0)
         => nc158, M_ARID(3) => nc281, M_ARID(2) => nc209, 
        M_ARID(1) => nc246, M_ARID(0) => nc162, M_ARLEN(3) => 
        nc11, M_ARLEN(2) => nc272, M_ARLEN(1) => nc131, 
        M_ARLEN(0) => nc254, M_ARSIZE(1) => nc267, M_ARSIZE(0)
         => nc96, M_ARVALID => OPEN, M_AWADDR_HADDR(31) => nc79, 
        M_AWADDR_HADDR(30) => nc226, M_AWADDR_HADDR(29) => nc146, 
        M_AWADDR_HADDR(28) => nc230, M_AWADDR_HADDR(27) => nc89, 
        M_AWADDR_HADDR(26) => nc119, M_AWADDR_HADDR(25) => nc48, 
        M_AWADDR_HADDR(24) => nc271, M_AWADDR_HADDR(23) => nc213, 
        M_AWADDR_HADDR(22) => nc126, M_AWADDR_HADDR(21) => nc195, 
        M_AWADDR_HADDR(20) => nc188, M_AWADDR_HADDR(19) => nc242, 
        M_AWADDR_HADDR(18) => nc15, M_AWADDR_HADDR(17) => nc236, 
        M_AWADDR_HADDR(16) => nc102, M_AWADDR_HADDR(15) => nc3, 
        M_AWADDR_HADDR(14) => nc207, M_AWADDR_HADDR(13) => nc47, 
        M_AWADDR_HADDR(12) => nc90, M_AWADDR_HADDR(11) => nc284, 
        M_AWADDR_HADDR(10) => nc222, M_AWADDR_HADDR(9) => nc159, 
        M_AWADDR_HADDR(8) => nc136, M_AWADDR_HADDR(7) => nc241, 
        M_AWADDR_HADDR(6) => nc253, M_AWADDR_HADDR(5) => nc178, 
        M_AWADDR_HADDR(4) => nc215, M_AWADDR_HADDR(3) => nc59, 
        M_AWADDR_HADDR(2) => nc221, M_AWADDR_HADDR(1) => nc232, 
        M_AWADDR_HADDR(0) => nc274, M_AWBURST_HTRANS(1) => nc18, 
        M_AWBURST_HTRANS(0) => nc44, M_AWID(3) => nc117, 
        M_AWID(2) => nc189, M_AWID(1) => nc164, M_AWID(0) => 
        nc148, M_AWLEN_HBURST(3) => nc42, M_AWLEN_HBURST(2) => 
        nc231, M_AWLEN_HBURST(1) => nc191, M_AWLEN_HBURST(0) => 
        nc255, M_AWSIZE_HSIZE(1) => nc283, M_AWSIZE_HSIZE(0) => 
        nc17, M_AWVALID_HWRITE => OPEN, M_BREADY => OPEN, 
        M_RREADY => OPEN, M_WDATA_HWDATA(63) => nc2, 
        M_WDATA_HWDATA(62) => nc110, M_WDATA_HWDATA(61) => nc128, 
        M_WDATA_HWDATA(60) => nc244, M_WDATA_HWDATA(59) => nc43, 
        M_WDATA_HWDATA(58) => nc179, M_WDATA_HWDATA(57) => nc157, 
        M_WDATA_HWDATA(56) => nc36, M_WDATA_HWDATA(55) => nc224, 
        M_WDATA_HWDATA(54) => nc273, M_WDATA_HWDATA(53) => nc61, 
        M_WDATA_HWDATA(52) => nc104, M_WDATA_HWDATA(51) => nc138, 
        M_WDATA_HWDATA(50) => nc14, M_WDATA_HWDATA(49) => nc285, 
        M_WDATA_HWDATA(48) => nc150, M_WDATA_HWDATA(47) => nc196, 
        M_WDATA_HWDATA(46) => nc234, M_WDATA_HWDATA(45) => nc149, 
        M_WDATA_HWDATA(44) => nc12, M_WDATA_HWDATA(43) => nc219, 
        M_WDATA_HWDATA(42) => nc30, M_WDATA_HWDATA(41) => nc243, 
        M_WDATA_HWDATA(40) => nc187, M_WDATA_HWDATA(39) => nc65, 
        M_WDATA_HWDATA(38) => nc7, M_WDATA_HWDATA(37) => nc129, 
        M_WDATA_HWDATA(36) => nc275, M_WDATA_HWDATA(35) => nc8, 
        M_WDATA_HWDATA(34) => nc223, M_WDATA_HWDATA(33) => nc13, 
        M_WDATA_HWDATA(32) => nc180, M_WDATA_HWDATA(31) => nc26, 
        M_WDATA_HWDATA(30) => nc177, M_WDATA_HWDATA(29) => nc139, 
        M_WDATA_HWDATA(28) => nc259, M_WDATA_HWDATA(27) => nc245, 
        M_WDATA_HWDATA(26) => nc233, M_WDATA_HWDATA(25) => nc163, 
        M_WDATA_HWDATA(24) => nc268, M_WDATA_HWDATA(23) => nc112, 
        M_WDATA_HWDATA(22) => nc68, M_WDATA_HWDATA(21) => nc49, 
        M_WDATA_HWDATA(20) => nc217, M_WDATA_HWDATA(19) => nc170, 
        M_WDATA_HWDATA(18) => nc91, M_WDATA_HWDATA(17) => nc225, 
        M_WDATA_HWDATA(16) => nc5, M_WDATA_HWDATA(15) => nc20, 
        M_WDATA_HWDATA(14) => nc198, M_WDATA_HWDATA(13) => nc147, 
        M_WDATA_HWDATA(12) => nc67, M_WDATA_HWDATA(11) => nc152, 
        M_WDATA_HWDATA(10) => nc127, M_WDATA_HWDATA(9) => nc103, 
        M_WDATA_HWDATA(8) => nc235, M_WDATA_HWDATA(7) => nc76, 
        M_WDATA_HWDATA(6) => nc208, M_WDATA_HWDATA(5) => nc140, 
        M_WDATA_HWDATA(4) => nc257, M_WDATA_HWDATA(3) => nc86, 
        M_WDATA_HWDATA(2) => nc95, M_WDATA_HWDATA(1) => nc120, 
        M_WDATA_HWDATA(0) => nc165, M_WID(3) => nc279, M_WID(2)
         => nc137, M_WID(1) => nc64, M_WID(0) => nc19, M_WLAST
         => OPEN, M_WSTRB(7) => nc70, M_WSTRB(6) => nc182, 
        M_WSTRB(5) => nc62, M_WSTRB(4) => nc199, M_WSTRB(3) => 
        nc80, M_WSTRB(2) => nc130, M_WSTRB(1) => nc287, 
        M_WSTRB(0) => nc98, M_WVALID => OPEN, PCIE_SYSTEM_INT => 
        OPEN, PLL_LOCK_INT => OPEN, PLL_LOCKLOST_INT => OPEN, 
        S_ARREADY => OPEN, S_AWREADY => OPEN, S_BID(3) => nc249, 
        S_BID(2) => nc114, S_BID(1) => nc56, S_BID(0) => nc105, 
        S_BRESP_HRESP(1) => nc63, S_BRESP_HRESP(0) => nc172, 
        S_BVALID => OPEN, S_RDATA_HRDATA(63) => nc229, 
        S_RDATA_HRDATA(62) => nc277, S_RDATA_HRDATA(61) => nc97, 
        S_RDATA_HRDATA(60) => nc161, S_RDATA_HRDATA(59) => nc31, 
        S_RDATA_HRDATA(58) => nc154, S_RDATA_HRDATA(57) => nc50, 
        S_RDATA_HRDATA(56) => nc260, S_RDATA_HRDATA(55) => nc239, 
        S_RDATA_HRDATA(54) => nc142, S_RDATA_HRDATA(53) => nc247, 
        S_RDATA_HRDATA(52) => nc94, S_RDATA_HRDATA(51) => nc197, 
        S_RDATA_HRDATA(50) => nc122, S_RDATA_HRDATA(49) => nc266, 
        S_RDATA_HRDATA(48) => nc35, S_RDATA_HRDATA(47) => nc4, 
        S_RDATA_HRDATA(46) => nc227, S_RDATA_HRDATA(45) => nc92, 
        S_RDATA_HRDATA(44) => nc101, S_RDATA_HRDATA(43) => nc184, 
        S_RDATA_HRDATA(42) => nc200, S_RDATA_HRDATA(41) => nc190, 
        S_RDATA_HRDATA(40) => nc166, S_RDATA_HRDATA(39) => nc132, 
        S_RDATA_HRDATA(38) => nc21, S_RDATA_HRDATA(37) => nc237, 
        S_RDATA_HRDATA(36) => nc93, S_RDATA_HRDATA(35) => nc262, 
        S_RDATA_HRDATA(34) => nc69, S_RDATA_HRDATA(33) => nc206, 
        S_RDATA_HRDATA(32) => nc174, S_RDATA_HRDATA(31) => nc38, 
        S_RDATA_HRDATA(30) => nc113, S_RDATA_HRDATA(29) => nc218, 
        S_RDATA_HRDATA(28) => nc106, S_RDATA_HRDATA(27) => nc261, 
        S_RDATA_HRDATA(26) => nc25, S_RDATA_HRDATA(25) => nc1, 
        S_RDATA_HRDATA(24) => nc37, S_RDATA_HRDATA(23) => nc202, 
        S_RDATA_HRDATA(22) => nc144, S_RDATA_HRDATA(21) => nc153, 
        S_RDATA_HRDATA(20) => nc46, S_RDATA_HRDATA(19) => nc258, 
        S_RDATA_HRDATA(18) => nc71, S_RDATA_HRDATA(17) => nc124, 
        S_RDATA_HRDATA(16) => nc81, S_RDATA_HRDATA(15) => nc201, 
        S_RDATA_HRDATA(14) => nc168, S_RDATA_HRDATA(13) => nc34, 
        S_RDATA_HRDATA(12) => nc28, S_RDATA_HRDATA(11) => nc115, 
        S_RDATA_HRDATA(10) => nc264, S_RDATA_HRDATA(9) => nc192, 
        S_RDATA_HRDATA(8) => nc134, S_RDATA_HRDATA(7) => nc32, 
        S_RDATA_HRDATA(6) => nc40, S_RDATA_HRDATA(5) => nc99, 
        S_RDATA_HRDATA(4) => nc75, S_RDATA_HRDATA(3) => nc183, 
        S_RDATA_HRDATA(2) => nc288, S_RDATA_HRDATA(1) => nc85, 
        S_RDATA_HRDATA(0) => nc27, S_RID(3) => nc108, S_RID(2)
         => nc16, S_RID(1) => nc155, S_RID(0) => nc51, S_RLAST
         => OPEN, S_RRESP(1) => nc33, S_RRESP(0) => nc204, 
        S_RVALID => OPEN, S_WREADY_HREADYOUT => OPEN, SPLL_LOCK
         => OPEN, WAKE_N => OPEN, XAUI_OUT_CLK => OPEN, APB_CLK
         => APB_S_PCLK, APB_PADDR(13) => APB_S_PADDR(13), 
        APB_PADDR(12) => APB_S_PADDR(12), APB_PADDR(11) => 
        APB_S_PADDR(11), APB_PADDR(10) => APB_S_PADDR(10), 
        APB_PADDR(9) => APB_S_PADDR(9), APB_PADDR(8) => 
        APB_S_PADDR(8), APB_PADDR(7) => APB_S_PADDR(7), 
        APB_PADDR(6) => APB_S_PADDR(6), APB_PADDR(5) => 
        APB_S_PADDR(5), APB_PADDR(4) => APB_S_PADDR(4), 
        APB_PADDR(3) => APB_S_PADDR(3), APB_PADDR(2) => 
        APB_S_PADDR(2), APB_PENABLE => APB_S_PENABLE, APB_PSEL
         => APB_S_PSEL, APB_PWDATA(31) => APB_S_PWDATA(31), 
        APB_PWDATA(30) => APB_S_PWDATA(30), APB_PWDATA(29) => 
        APB_S_PWDATA(29), APB_PWDATA(28) => APB_S_PWDATA(28), 
        APB_PWDATA(27) => APB_S_PWDATA(27), APB_PWDATA(26) => 
        APB_S_PWDATA(26), APB_PWDATA(25) => APB_S_PWDATA(25), 
        APB_PWDATA(24) => APB_S_PWDATA(24), APB_PWDATA(23) => 
        APB_S_PWDATA(23), APB_PWDATA(22) => APB_S_PWDATA(22), 
        APB_PWDATA(21) => APB_S_PWDATA(21), APB_PWDATA(20) => 
        APB_S_PWDATA(20), APB_PWDATA(19) => APB_S_PWDATA(19), 
        APB_PWDATA(18) => APB_S_PWDATA(18), APB_PWDATA(17) => 
        APB_S_PWDATA(17), APB_PWDATA(16) => APB_S_PWDATA(16), 
        APB_PWDATA(15) => APB_S_PWDATA(15), APB_PWDATA(14) => 
        APB_S_PWDATA(14), APB_PWDATA(13) => APB_S_PWDATA(13), 
        APB_PWDATA(12) => APB_S_PWDATA(12), APB_PWDATA(11) => 
        APB_S_PWDATA(11), APB_PWDATA(10) => APB_S_PWDATA(10), 
        APB_PWDATA(9) => APB_S_PWDATA(9), APB_PWDATA(8) => 
        APB_S_PWDATA(8), APB_PWDATA(7) => APB_S_PWDATA(7), 
        APB_PWDATA(6) => APB_S_PWDATA(6), APB_PWDATA(5) => 
        APB_S_PWDATA(5), APB_PWDATA(4) => APB_S_PWDATA(4), 
        APB_PWDATA(3) => APB_S_PWDATA(3), APB_PWDATA(2) => 
        APB_S_PWDATA(2), APB_PWDATA(1) => APB_S_PWDATA(1), 
        APB_PWDATA(0) => APB_S_PWDATA(0), APB_PWRITE => 
        APB_S_PWRITE, APB_RSTN => APB_S_PRESET_N, CLK_BASE => 
        vcc_net, EPCS_PWRDN(1) => EPCS_3_PWRDN, EPCS_PWRDN(0) => 
        vcc_net, EPCS_RSTN(1) => EPCS_3_RESET_N, EPCS_RSTN(0) => 
        vcc_net, EPCS_RXERR(1) => EPCS_3_RX_ERR, EPCS_RXERR(0)
         => vcc_net, EPCS_TXDATA(39) => EPCS_3_TX_DATA(19), 
        EPCS_TXDATA(38) => EPCS_3_TX_DATA(18), EPCS_TXDATA(37)
         => EPCS_3_TX_DATA(17), EPCS_TXDATA(36) => 
        EPCS_3_TX_DATA(16), EPCS_TXDATA(35) => EPCS_3_TX_DATA(15), 
        EPCS_TXDATA(34) => EPCS_3_TX_DATA(14), EPCS_TXDATA(33)
         => EPCS_3_TX_DATA(13), EPCS_TXDATA(32) => 
        EPCS_3_TX_DATA(12), EPCS_TXDATA(31) => EPCS_3_TX_DATA(11), 
        EPCS_TXDATA(30) => EPCS_3_TX_DATA(10), EPCS_TXDATA(29)
         => EPCS_3_TX_DATA(9), EPCS_TXDATA(28) => 
        EPCS_3_TX_DATA(8), EPCS_TXDATA(27) => EPCS_3_TX_DATA(7), 
        EPCS_TXDATA(26) => EPCS_3_TX_DATA(6), EPCS_TXDATA(25) => 
        EPCS_3_TX_DATA(5), EPCS_TXDATA(24) => EPCS_3_TX_DATA(4), 
        EPCS_TXDATA(23) => EPCS_3_TX_DATA(3), EPCS_TXDATA(22) => 
        EPCS_3_TX_DATA(2), EPCS_TXDATA(21) => EPCS_3_TX_DATA(1), 
        EPCS_TXDATA(20) => EPCS_3_TX_DATA(0), EPCS_TXDATA(19) => 
        gnd_net, EPCS_TXDATA(18) => gnd_net, EPCS_TXDATA(17) => 
        gnd_net, EPCS_TXDATA(16) => gnd_net, EPCS_TXDATA(15) => 
        gnd_net, EPCS_TXDATA(14) => gnd_net, EPCS_TXDATA(13) => 
        gnd_net, EPCS_TXDATA(12) => gnd_net, EPCS_TXDATA(11) => 
        gnd_net, EPCS_TXDATA(10) => gnd_net, EPCS_TXDATA(9) => 
        gnd_net, EPCS_TXDATA(8) => gnd_net, EPCS_TXDATA(7) => 
        gnd_net, EPCS_TXDATA(6) => gnd_net, EPCS_TXDATA(5) => 
        gnd_net, EPCS_TXDATA(4) => gnd_net, EPCS_TXDATA(3) => 
        gnd_net, EPCS_TXDATA(2) => gnd_net, EPCS_TXDATA(1) => 
        gnd_net, EPCS_TXDATA(0) => gnd_net, EPCS_TXOOB(1) => 
        EPCS_3_TX_OOB, EPCS_TXOOB(0) => vcc_net, EPCS_TXVAL(1)
         => EPCS_3_TX_VAL, EPCS_TXVAL(0) => vcc_net, F2HCALIB0
         => vcc_net, F2HCALIB1 => vcc_net, FAB_PLL_LOCK => 
        gnd_net, FAB_REF_CLK => vcc_net, M_ARREADY => gnd_net, 
        M_AWREADY => gnd_net, M_BID(3) => vcc_net, M_BID(2) => 
        vcc_net, M_BID(1) => vcc_net, M_BID(0) => vcc_net, 
        M_BRESP_HRESP(1) => gnd_net, M_BRESP_HRESP(0) => gnd_net, 
        M_BVALID => gnd_net, M_RDATA_HRDATA(63) => gnd_net, 
        M_RDATA_HRDATA(62) => gnd_net, M_RDATA_HRDATA(61) => 
        gnd_net, M_RDATA_HRDATA(60) => gnd_net, 
        M_RDATA_HRDATA(59) => gnd_net, M_RDATA_HRDATA(58) => 
        gnd_net, M_RDATA_HRDATA(57) => gnd_net, 
        M_RDATA_HRDATA(56) => gnd_net, M_RDATA_HRDATA(55) => 
        gnd_net, M_RDATA_HRDATA(54) => gnd_net, 
        M_RDATA_HRDATA(53) => gnd_net, M_RDATA_HRDATA(52) => 
        gnd_net, M_RDATA_HRDATA(51) => nc173, M_RDATA_HRDATA(50)
         => nc278, M_RDATA_HRDATA(49) => nc169, 
        M_RDATA_HRDATA(48) => nc78, M_RDATA_HRDATA(47) => nc263, 
        M_RDATA_HRDATA(46) => nc24, M_RDATA_HRDATA(45) => nc88, 
        M_RDATA_HRDATA(44) => nc111, M_RDATA_HRDATA(43) => nc55, 
        M_RDATA_HRDATA(42) => nc10, M_RDATA_HRDATA(41) => nc22, 
        M_RDATA_HRDATA(40) => nc210, M_RDATA_HRDATA(39) => nc185, 
        M_RDATA_HRDATA(38) => nc143, M_RDATA_HRDATA(37) => nc248, 
        M_RDATA_HRDATA(36) => nc77, M_RDATA_HRDATA(35) => nc6, 
        M_RDATA_HRDATA(34) => nc109, M_RDATA_HRDATA(33) => nc87, 
        M_RDATA_HRDATA(32) => nc123, M_RDATA_HRDATA(31) => 
        gnd_net, M_RDATA_HRDATA(30) => gnd_net, 
        M_RDATA_HRDATA(29) => gnd_net, M_RDATA_HRDATA(28) => 
        gnd_net, M_RDATA_HRDATA(27) => gnd_net, 
        M_RDATA_HRDATA(26) => gnd_net, M_RDATA_HRDATA(25) => 
        gnd_net, M_RDATA_HRDATA(24) => gnd_net, 
        M_RDATA_HRDATA(23) => gnd_net, M_RDATA_HRDATA(22) => 
        gnd_net, M_RDATA_HRDATA(21) => gnd_net, 
        M_RDATA_HRDATA(20) => gnd_net, M_RDATA_HRDATA(19) => 
        gnd_net, M_RDATA_HRDATA(18) => gnd_net, 
        M_RDATA_HRDATA(17) => gnd_net, M_RDATA_HRDATA(16) => 
        gnd_net, M_RDATA_HRDATA(15) => gnd_net, 
        M_RDATA_HRDATA(14) => gnd_net, M_RDATA_HRDATA(13) => 
        gnd_net, M_RDATA_HRDATA(12) => gnd_net, 
        M_RDATA_HRDATA(11) => gnd_net, M_RDATA_HRDATA(10) => 
        gnd_net, M_RDATA_HRDATA(9) => gnd_net, M_RDATA_HRDATA(8)
         => gnd_net, M_RDATA_HRDATA(7) => gnd_net, 
        M_RDATA_HRDATA(6) => gnd_net, M_RDATA_HRDATA(5) => 
        gnd_net, M_RDATA_HRDATA(4) => gnd_net, M_RDATA_HRDATA(3)
         => gnd_net, M_RDATA_HRDATA(2) => gnd_net, 
        M_RDATA_HRDATA(1) => gnd_net, M_RDATA_HRDATA(0) => 
        gnd_net, M_RID(3) => gnd_net, M_RID(2) => gnd_net, 
        M_RID(1) => gnd_net, M_RID(0) => gnd_net, M_RLAST => 
        gnd_net, M_RRESP(1) => gnd_net, M_RRESP(0) => gnd_net, 
        M_RVALID => gnd_net, M_WREADY_HREADY => gnd_net, 
        PCIE_INTERRUPT(3) => gnd_net, PCIE_INTERRUPT(2) => 
        gnd_net, PCIE_INTERRUPT(1) => gnd_net, PCIE_INTERRUPT(0)
         => gnd_net, PERST_N => gnd_net, S_ARADDR(31) => gnd_net, 
        S_ARADDR(30) => gnd_net, S_ARADDR(29) => gnd_net, 
        S_ARADDR(28) => gnd_net, S_ARADDR(27) => gnd_net, 
        S_ARADDR(26) => gnd_net, S_ARADDR(25) => gnd_net, 
        S_ARADDR(24) => gnd_net, S_ARADDR(23) => gnd_net, 
        S_ARADDR(22) => gnd_net, S_ARADDR(21) => gnd_net, 
        S_ARADDR(20) => gnd_net, S_ARADDR(19) => gnd_net, 
        S_ARADDR(18) => gnd_net, S_ARADDR(17) => gnd_net, 
        S_ARADDR(16) => gnd_net, S_ARADDR(15) => gnd_net, 
        S_ARADDR(14) => gnd_net, S_ARADDR(13) => gnd_net, 
        S_ARADDR(12) => gnd_net, S_ARADDR(11) => gnd_net, 
        S_ARADDR(10) => gnd_net, S_ARADDR(9) => gnd_net, 
        S_ARADDR(8) => gnd_net, S_ARADDR(7) => gnd_net, 
        S_ARADDR(6) => gnd_net, S_ARADDR(5) => gnd_net, 
        S_ARADDR(4) => gnd_net, S_ARADDR(3) => gnd_net, 
        S_ARADDR(2) => gnd_net, S_ARADDR(1) => gnd_net, 
        S_ARADDR(0) => gnd_net, S_ARBURST(1) => gnd_net, 
        S_ARBURST(0) => gnd_net, S_ARID(3) => gnd_net, S_ARID(2)
         => gnd_net, S_ARID(1) => gnd_net, S_ARID(0) => gnd_net, 
        S_ARLEN(3) => gnd_net, S_ARLEN(2) => gnd_net, S_ARLEN(1)
         => gnd_net, S_ARLEN(0) => gnd_net, S_ARLOCK(1) => 
        gnd_net, S_ARLOCK(0) => gnd_net, S_ARSIZE(1) => gnd_net, 
        S_ARSIZE(0) => gnd_net, S_ARVALID => gnd_net, 
        S_AWADDR_HADDR(31) => gnd_net, S_AWADDR_HADDR(30) => 
        gnd_net, S_AWADDR_HADDR(29) => gnd_net, 
        S_AWADDR_HADDR(28) => gnd_net, S_AWADDR_HADDR(27) => 
        gnd_net, S_AWADDR_HADDR(26) => gnd_net, 
        S_AWADDR_HADDR(25) => gnd_net, S_AWADDR_HADDR(24) => 
        gnd_net, S_AWADDR_HADDR(23) => gnd_net, 
        S_AWADDR_HADDR(22) => gnd_net, S_AWADDR_HADDR(21) => 
        gnd_net, S_AWADDR_HADDR(20) => gnd_net, 
        S_AWADDR_HADDR(19) => gnd_net, S_AWADDR_HADDR(18) => 
        gnd_net, S_AWADDR_HADDR(17) => gnd_net, 
        S_AWADDR_HADDR(16) => gnd_net, S_AWADDR_HADDR(15) => 
        gnd_net, S_AWADDR_HADDR(14) => gnd_net, 
        S_AWADDR_HADDR(13) => gnd_net, S_AWADDR_HADDR(12) => 
        gnd_net, S_AWADDR_HADDR(11) => gnd_net, 
        S_AWADDR_HADDR(10) => gnd_net, S_AWADDR_HADDR(9) => 
        gnd_net, S_AWADDR_HADDR(8) => gnd_net, S_AWADDR_HADDR(7)
         => gnd_net, S_AWADDR_HADDR(6) => gnd_net, 
        S_AWADDR_HADDR(5) => gnd_net, S_AWADDR_HADDR(4) => 
        gnd_net, S_AWADDR_HADDR(3) => gnd_net, S_AWADDR_HADDR(2)
         => gnd_net, S_AWADDR_HADDR(1) => gnd_net, 
        S_AWADDR_HADDR(0) => gnd_net, S_AWBURST_HTRANS(1) => 
        gnd_net, S_AWBURST_HTRANS(0) => gnd_net, S_AWID_HSEL(3)
         => gnd_net, S_AWID_HSEL(2) => gnd_net, S_AWID_HSEL(1)
         => gnd_net, S_AWID_HSEL(0) => gnd_net, S_AWLEN_HBURST(3)
         => gnd_net, S_AWLEN_HBURST(2) => gnd_net, 
        S_AWLEN_HBURST(1) => gnd_net, S_AWLEN_HBURST(0) => 
        gnd_net, S_AWLOCK(1) => gnd_net, S_AWLOCK(0) => gnd_net, 
        S_AWSIZE_HSIZE(1) => gnd_net, S_AWSIZE_HSIZE(0) => 
        gnd_net, S_AWVALID_HWRITE => gnd_net, S_BREADY_HREADY => 
        gnd_net, S_RREADY => gnd_net, S_WDATA_HWDATA(63) => 
        gnd_net, S_WDATA_HWDATA(62) => gnd_net, 
        S_WDATA_HWDATA(61) => gnd_net, S_WDATA_HWDATA(60) => 
        gnd_net, S_WDATA_HWDATA(59) => gnd_net, 
        S_WDATA_HWDATA(58) => gnd_net, S_WDATA_HWDATA(57) => 
        gnd_net, S_WDATA_HWDATA(56) => gnd_net, 
        S_WDATA_HWDATA(55) => gnd_net, S_WDATA_HWDATA(54) => 
        gnd_net, S_WDATA_HWDATA(53) => gnd_net, 
        S_WDATA_HWDATA(52) => gnd_net, S_WDATA_HWDATA(51) => 
        gnd_net, S_WDATA_HWDATA(50) => gnd_net, 
        S_WDATA_HWDATA(49) => gnd_net, S_WDATA_HWDATA(48) => 
        gnd_net, S_WDATA_HWDATA(47) => gnd_net, 
        S_WDATA_HWDATA(46) => gnd_net, S_WDATA_HWDATA(45) => 
        gnd_net, S_WDATA_HWDATA(44) => gnd_net, 
        S_WDATA_HWDATA(43) => gnd_net, S_WDATA_HWDATA(42) => 
        gnd_net, S_WDATA_HWDATA(41) => gnd_net, 
        S_WDATA_HWDATA(40) => gnd_net, S_WDATA_HWDATA(39) => 
        gnd_net, S_WDATA_HWDATA(38) => gnd_net, 
        S_WDATA_HWDATA(37) => gnd_net, S_WDATA_HWDATA(36) => 
        gnd_net, S_WDATA_HWDATA(35) => gnd_net, 
        S_WDATA_HWDATA(34) => gnd_net, S_WDATA_HWDATA(33) => 
        gnd_net, S_WDATA_HWDATA(32) => gnd_net, 
        S_WDATA_HWDATA(31) => gnd_net, S_WDATA_HWDATA(30) => 
        gnd_net, S_WDATA_HWDATA(29) => gnd_net, 
        S_WDATA_HWDATA(28) => gnd_net, S_WDATA_HWDATA(27) => 
        gnd_net, S_WDATA_HWDATA(26) => gnd_net, 
        S_WDATA_HWDATA(25) => gnd_net, S_WDATA_HWDATA(24) => 
        gnd_net, S_WDATA_HWDATA(23) => gnd_net, 
        S_WDATA_HWDATA(22) => gnd_net, S_WDATA_HWDATA(21) => 
        gnd_net, S_WDATA_HWDATA(20) => gnd_net, 
        S_WDATA_HWDATA(19) => gnd_net, S_WDATA_HWDATA(18) => 
        gnd_net, S_WDATA_HWDATA(17) => gnd_net, 
        S_WDATA_HWDATA(16) => gnd_net, S_WDATA_HWDATA(15) => 
        gnd_net, S_WDATA_HWDATA(14) => gnd_net, 
        S_WDATA_HWDATA(13) => gnd_net, S_WDATA_HWDATA(12) => 
        gnd_net, S_WDATA_HWDATA(11) => gnd_net, 
        S_WDATA_HWDATA(10) => gnd_net, S_WDATA_HWDATA(9) => 
        gnd_net, S_WDATA_HWDATA(8) => gnd_net, S_WDATA_HWDATA(7)
         => gnd_net, S_WDATA_HWDATA(6) => gnd_net, 
        S_WDATA_HWDATA(5) => gnd_net, S_WDATA_HWDATA(4) => 
        gnd_net, S_WDATA_HWDATA(3) => gnd_net, S_WDATA_HWDATA(2)
         => gnd_net, S_WDATA_HWDATA(1) => gnd_net, 
        S_WDATA_HWDATA(0) => gnd_net, S_WID(3) => gnd_net, 
        S_WID(2) => gnd_net, S_WID(1) => gnd_net, S_WID(0) => 
        gnd_net, S_WLAST => gnd_net, S_WSTRB(7) => gnd_net, 
        S_WSTRB(6) => gnd_net, S_WSTRB(5) => gnd_net, S_WSTRB(4)
         => gnd_net, S_WSTRB(3) => gnd_net, S_WSTRB(2) => gnd_net, 
        S_WSTRB(1) => gnd_net, S_WSTRB(0) => gnd_net, S_WVALID
         => gnd_net, SERDESIF_CORE_RESET_N => vcc_net, 
        SERDESIF_PHY_RESET_N => gnd_net, WAKE_REQ => vcc_net, 
        XAUI_FB_CLK => vcc_net, RXD3_P => RXD3_P, RXD2_P => 
        RXD2_P, RXD1_P => RXD1_P, RXD0_P => RXD0_P, RXD3_N => 
        RXD3_N, RXD2_N => RXD2_N, RXD1_N => RXD1_N, RXD0_N => 
        RXD0_N, TXD3_P => TXD3_P, TXD2_P => TXD2_P, TXD1_P => 
        TXD1_P, TXD0_P => TXD0_P, TXD3_N => TXD3_N, TXD2_N => 
        TXD2_N, TXD1_N => TXD1_N, TXD0_N => TXD0_N, REFCLK0 => 
        vcc_net, REFCLK1 => REFCLK1_net);
    

end DEF_ARCH; 
