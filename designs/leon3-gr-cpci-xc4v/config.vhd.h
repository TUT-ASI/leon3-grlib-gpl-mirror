-- Technology and synthesis options
  constant CFG_FABTECH 	: integer := CONFIG_SYN_TECH;
  constant CFG_MEMTECH  : integer := CFG_RAM_TECH;
  constant CFG_PADTECH 	: integer := CFG_PAD_TECH;
  constant CFG_TRANSTECH	: integer := CFG_TRANS_TECH;
  constant CFG_NOASYNC 	: integer := CONFIG_SYN_NO_ASYNC;
  constant CFG_SCAN 	: integer := CONFIG_SYN_SCAN;

-- Clock generator
  constant CFG_CLKTECH 	: integer := CFG_CLK_TECH;
  constant CFG_CLKMUL   : integer := CONFIG_CLK_MUL;
  constant CFG_CLKDIV   : integer := CONFIG_CLK_DIV;
  constant CFG_OCLKDIV  : integer := CONFIG_OCLK_DIV;
  constant CFG_OCLKBDIV : integer := CONFIG_OCLKB_DIV;
  constant CFG_OCLKCDIV : integer := CONFIG_OCLKC_DIV;
  constant CFG_PCIDLL   : integer := CONFIG_PCI_CLKDLL;
  constant CFG_PCISYSCLK: integer := CONFIG_PCI_SYSCLK;
  constant CFG_CLK_NOFB : integer := CONFIG_CLK_NOFB;

-- LEON processor core
  constant CFG_LEON  	: integer := CONFIG_LEON;
  constant CFG_NCPU 	: integer := CONFIG_PROC_NUM;
  constant CFG_NWIN 	: integer := CONFIG_IU_NWINDOWS;
  constant CFG_V8   	: integer := CFG_IU_V8 + 4*CFG_IU_MUL_STRUCT;
  constant CFG_MAC  	: integer := CONFIG_IU_MUL_MAC;
  constant CFG_SVT  	: integer := CONFIG_IU_SVT;
  constant CFG_RSTADDR 	: integer := 16#CONFIG_IU_RSTADDR#;
  constant CFG_LDDEL	: integer := CONFIG_IU_LDELAY;
  constant CFG_NWP  	: integer := CONFIG_IU_WATCHPOINTS;
  constant CFG_PWD 	: integer := CONFIG_PWD*2;
  constant CFG_FPU 	: integer := CONFIG_FPU + 16*CONFIG_FPU_NETLIST + 32*CONFIG_FPU_GRFPU_SHARED;
  constant CFG_GRFPUSH  : integer := CONFIG_FPU_GRFPU_SHARED;
  constant CFG_ICEN  	: integer := CONFIG_ICACHE_ENABLE;
  constant CFG_ISETS	: integer := CFG_IU_ISETS;
  constant CFG_ISETSZ	: integer := CFG_ICACHE_SZ;
  constant CFG_ILINE 	: integer := CFG_ILINE_SZ;
  constant CFG_IREPL 	: integer := CFG_ICACHE_ALGORND;
  constant CFG_ILOCK 	: integer := CONFIG_ICACHE_LOCK;
  constant CFG_ILRAMEN	: integer := CONFIG_ICACHE_LRAM;
  constant CFG_ILRAMADDR: integer := 16#CONFIG_ICACHE_LRSTART#;
  constant CFG_ILRAMSZ	: integer := CFG_ILRAM_SIZE;
  constant CFG_DCEN  	: integer := CONFIG_DCACHE_ENABLE;
  constant CFG_DSETS	: integer := CFG_IU_DSETS;
  constant CFG_DSETSZ	: integer := CFG_DCACHE_SZ;
  constant CFG_DLINE 	: integer := CFG_DLINE_SZ;
  constant CFG_DREPL 	: integer := CFG_DCACHE_ALGORND;
  constant CFG_DLOCK 	: integer := CONFIG_DCACHE_LOCK;
  constant CFG_DSNOOP	: integer := CONFIG_DCACHE_SNOOP*2 + 4*CONFIG_DCACHE_SNOOP_SEPTAG;
  constant CFG_DFIXED	: integer := 16#CONFIG_CACHE_FIXED#;
  constant CFG_BWMASK  	: integer := 16#CONFIG_BWMASK#;
  constant CFG_CACHEBW 	: integer := OFG_CBUSW;
  constant CFG_DLRAMEN	: integer := CONFIG_DCACHE_LRAM;
  constant CFG_DLRAMADDR: integer := 16#CONFIG_DCACHE_LRSTART#;
  constant CFG_DLRAMSZ	: integer := CFG_DLRAM_SIZE;
  constant CFG_MMUEN    : integer := CONFIG_MMUEN;
  constant CFG_ITLBNUM  : integer := CONFIG_ITLBNUM;
  constant CFG_DTLBNUM  : integer := CONFIG_DTLBNUM;
  constant CFG_TLB_TYPE : integer := CONFIG_TLB_TYPE + CFG_MMU_FASTWB*2;
  constant CFG_TLB_REP  : integer := CONFIG_TLB_REP;
  constant CFG_MMU_PAGE : integer := CONFIG_MMU_PAGE;
  constant CFG_DSU   	: integer := CONFIG_DSU_ENABLE;
  constant CFG_ITBSZ 	: integer := CFG_DSU_ITB + 64*CONFIG_DSU_ITRACE_2P;
  constant CFG_ATBSZ 	: integer := CFG_DSU_ATB;
  constant CFG_AHBPF    : integer := CFG_DSU_AHBPF;
  constant CFG_AHBWP    : integer := CFG_DSU_AHBWP;
  constant CFG_LEONFT_EN   : integer := CONFIG_IUFT_EN + (CONFIG_CACHE_FT_EN)*8;
  constant CFG_LEON_NETLIST : integer := CONFIG_LEON_NETLIST;	
  constant CFG_DISAS    : integer := CONFIG_IU_DISAS + CONFIG_IU_DISAS_NET;
  constant CFG_PCLOW    : integer := CFG_DEBUG_PC32;
  constant CFG_STAT_ENABLE   : integer := CONFIG_STAT_ENABLE;
  constant CFG_STAT_CNT      : integer := CONFIG_STAT_CNT;
  constant CFG_STAT_NMAX     : integer := CONFIG_STAT_NMAX;
  constant CFG_STAT_DSUEN    : integer := CONFIG_STAT_DSUEN;
  constant CFG_NP_ASI   : integer := CONFIG_NP_ASI;
  constant CFG_WRPSR   : integer := CONFIG_WRPSR;
  constant CFG_ALTWIN   : integer := CONFIG_ALTWIN;
  constant CFG_REX      : integer := CONFIG_REX;

-- AMBA settings
  constant CFG_DEFMST  	  : integer := CONFIG_AHB_DEFMST;
  constant CFG_RROBIN  	  : integer := CONFIG_AHB_RROBIN;
  constant CFG_SPLIT   	  : integer := CONFIG_AHB_SPLIT;
  constant CFG_FPNPEN  	  : integer := CONFIG_AHB_FPNPEN;
  constant CFG_AHBIO   	  : integer := 16#CONFIG_AHB_IOADDR#;
  constant CFG_APBADDR 	  : integer := 16#CONFIG_APB_HADDR#;
  constant CFG_AHB_MON 	  : integer := CONFIG_AHB_MON;
  constant CFG_AHB_MONERR : integer := CONFIG_AHB_MONERR;
  constant CFG_AHB_MONWAR : integer := CONFIG_AHB_MONWAR;
  constant CFG_AHB_DTRACE : integer := CONFIG_AHB_DTRACE;

-- DSU UART
  constant CFG_AHB_UART	: integer := CONFIG_DSU_UART;

-- JTAG based DSU interface
  constant CFG_AHB_JTAG	: integer := CONFIG_DSU_JTAG;

-- Ethernet DSU
  constant CFG_DSU_ETH	: integer := CONFIG_DSU_ETH + CONFIG_DSU_ETH_PROG + CONFIG_DSU_ETH_DIS;
  constant CFG_ETH_BUF 	: integer := CFG_DSU_ETHB;
  constant CFG_ETH_IPM 	: integer := 16#CONFIG_DSU_IPMSB#;
  constant CFG_ETH_IPL 	: integer := 16#CONFIG_DSU_IPLSB#;
  constant CFG_ETH_ENM 	: integer := 16#CONFIG_DSU_ETHMSB#;
  constant CFG_ETH_ENL 	: integer := 16#CONFIG_DSU_ETHLSB#;

-- LEON2 memory controller
  constant CFG_MCTRL_LEON2    : integer := CONFIG_MCTRL_LEON2;
  constant CFG_MCTRL_RAM8BIT  : integer := CONFIG_MCTRL_8BIT;
  constant CFG_MCTRL_RAM16BIT : integer := CONFIG_MCTRL_16BIT;
  constant CFG_MCTRL_5CS      : integer := CONFIG_MCTRL_5CS;
  constant CFG_MCTRL_SDEN     : integer := CONFIG_MCTRL_SDRAM;
  constant CFG_MCTRL_SEPBUS   : integer := CONFIG_MCTRL_SDRAM_SEPBUS;
  constant CFG_MCTRL_INVCLK   : integer := CONFIG_MCTRL_SDRAM_INVCLK;
  constant CFG_MCTRL_SD64     : integer := CONFIG_MCTRL_SDRAM_BUS64;
  constant CFG_MCTRL_PAGE     : integer := CONFIG_MCTRL_PAGE + CONFIG_MCTRL_PROGPAGE;

-- FTMCTRL memory controller
  constant CFG_MCTRLFT		: integer := CONFIG_MCTRLFT;
  constant CFG_MCTRLFT_RAM8BIT  : integer := CONFIG_MCTRLFT_8BIT;
  constant CFG_MCTRLFT_RAM16BIT : integer := CONFIG_MCTRLFT_16BIT;
  constant CFG_MCTRLFT_5CS      : integer := CONFIG_MCTRLFT_5CS;
  constant CFG_MCTRLFT_SDEN    	: integer := CONFIG_MCTRLFT_SDRAM;
  constant CFG_MCTRLFT_SEPBUS  	: integer := CONFIG_MCTRLFT_SDRAM_SEPBUS;
  constant CFG_MCTRLFT_INVCLK  	: integer := CONFIG_MCTRLFT_SDRAM_INVCLK;
  constant CFG_MCTRLFT_SD64     : integer := CONFIG_MCTRLFT_SDRAM_BUS64;
  constant CFG_MCTRLFT_EDAC    	: integer := CONFIG_MCTRLFT_EDAC + CONFIG_MCTRLFT_EDACPIPE + CONFIG_MCTRLFT_RSEDAC;
  constant CFG_MCTRLFT_PAGE    	: integer := CONFIG_MCTRLFT_PAGE + CONFIG_MCTRLFT_PROGPAGE;
  constant CFG_MCTRLFT_ROMASEL 	: integer := CFG_M_CTRLFT_ROMASEL;
  constant CFG_MCTRLFT_WFB 	: integer := CONFIG_MCTRLFT_WFB;
  constant CFG_MCTRLFT_NET 	: integer := CONFIG_MCTRLFT_NETLIST;

-- SDRAM controller
  constant CFG_SDCTRL  	: integer := CONFIG_SDCTRL;
  constant CFG_SDCTRL_INVCLK  	: integer := CONFIG_SDCTRL_INVCLK;
  constant CFG_SDCTRL_SD64    	: integer := CONFIG_SDCTRL_BUS64;
  constant CFG_SDCTRL_PAGE    	: integer := CONFIG_SDCTRL_PAGE + CONFIG_SDCTRL_PROGPAGE;

-- AHB status register
  constant CFG_AHBSTAT 	: integer := CONFIG_AHBSTAT_ENABLE;
  constant CFG_AHBSTATN	: integer := CONFIG_AHBSTAT_NFTSLV;

-- AHB RAM
  constant CFG_AHBRAMEN	: integer := CONFIG_AHBRAM_ENABLE;
  constant CFG_AHBRSZ	: integer := CFG_AHBRAMSZ;
  constant CFG_AHBRADDR	: integer := 16#CONFIG_AHBRAM_START#;
  constant CFG_AHBRPIPE : integer := CONFIG_AHBRAM_PIPE;

-- Gaisler Ethernet core
  constant CFG_GRETH   	    : integer := CONFIG_GRETH_ENABLE;
  constant CFG_GRETH1G	    : integer := CONFIG_GRETH_GIGA;
  constant CFG_ETH_FIFO     : integer := CFG_GRETH_FIFO;
#ifdef CONFIG_GRETH_SGMII_PRESENT
  constant CFG_GRETH_SGMII  : integer := CONFIG_GRETH_SGMII_MODE;
#endif
#ifdef CONFIG_LEON3FT_PRESENT
  constant CFG_GRETH_FT     : integer := CONFIG_GRETH_FT;
  constant CFG_GRETH_EDCLFT : integer := CONFIG_GRETH_EDCLFT;
#endif
-- CAN 2.0 interface
  constant CFG_CAN      : integer := CONFIG_CAN_ENABLE;
  constant CFG_CAN_NUM  : integer := CONFIG_CAN_NUM;
  constant CFG_CANIO    : integer := 16#CONFIG_CANIO#;
  constant CFG_CANIRQ   : integer := CONFIG_CANIRQ;
  constant CFG_CANSEPIRQ: integer := CONFIG_CANSEPIRQ;
  constant CFG_CAN_SYNCRST : integer := CONFIG_CAN_SYNCRST;
  constant CFG_CANFT    : integer := CONFIG_CAN_FT;

-- Spacewire interface
  constant CFG_SPW_EN      : integer := CONFIG_SPW_ENABLE;
  constant CFG_SPW_NUM     : integer := CONFIG_SPW_NUM;
  constant CFG_SPW_AHBFIFO : integer := CONFIG_SPW_AHBFIFO;
  constant CFG_SPW_RXFIFO  : integer := CONFIG_SPW_RXFIFO;
  constant CFG_SPW_RMAP    : integer := CONFIG_SPW_RMAP;
  constant CFG_SPW_RMAPBUF : integer := CONFIG_SPW_RMAPBUF;
  constant CFG_SPW_RMAPCRC : integer := CONFIG_SPW_RMAPCRC;
  constant CFG_SPW_NETLIST : integer := CONFIG_SPW_NETLIST;
  constant CFG_SPW_FT      : integer := CONFIG_SPW_FT;
  constant CFG_SPW_GRSPW   : integer := CONFIG_SPW_GRSPW;
  constant CFG_SPW_RXUNAL  : integer := CONFIG_SPW_RXUNAL;
  constant CFG_SPW_DMACHAN : integer := CONFIG_SPW_DMACHAN;
  constant CFG_SPW_PORTS   : integer := CONFIG_SPW_PORTS;
  constant CFG_SPW_INPUT   : integer := CONFIG_SPW_INPUT;
  constant CFG_SPW_OUTPUT  : integer := CONFIG_SPW_OUTPUT;
  constant CFG_SPW_RTSAME  : integer := CONFIG_SPW_RTSAME;

-- PCI interface
  constant CFG_PCI     	: integer := CFG_PCITYPE;
  constant CFG_PCIVID   : integer := 16#CONFIG_PCI_VENDORID#;
  constant CFG_PCIDID   : integer := 16#CONFIG_PCI_DEVICEID#;
  constant CFG_PCIDEPTH : integer := CFG_PCIFIFO;
  constant CFG_PCI_MTF  : integer := CFG_PCI_ENFIFO;

-- GRPCI2 interface
  constant CFG_GRPCI2_MASTER    : integer := CFG_GRPCI2_MASTEREN;
  constant CFG_GRPCI2_TARGET    : integer := CFG_GRPCI2_TARGETEN;
  constant CFG_GRPCI2_DMA       : integer := CFG_GRPCI2_DMAEN;
  constant CFG_GRPCI2_VID       : integer := 16#CONFIG_GRPCI2_VENDORID#;
  constant CFG_GRPCI2_DID       : integer := 16#CONFIG_GRPCI2_DEVICEID#;
  constant CFG_GRPCI2_CLASS     : integer := 16#CONFIG_GRPCI2_CLASS#;
  constant CFG_GRPCI2_RID       : integer := 16#CONFIG_GRPCI2_REVID#;
  constant CFG_GRPCI2_CAP       : integer := 16#CONFIG_GRPCI2_CAPPOINT#;
  constant CFG_GRPCI2_NCAP      : integer := 16#CONFIG_GRPCI2_NEXTCAPPOINT#;
  constant CFG_GRPCI2_BAR0      : integer := CONFIG_GRPCI2_BAR0;
  constant CFG_GRPCI2_BAR1      : integer := CONFIG_GRPCI2_BAR1;
  constant CFG_GRPCI2_BAR2      : integer := CONFIG_GRPCI2_BAR2;
  constant CFG_GRPCI2_BAR3      : integer := CONFIG_GRPCI2_BAR3;
  constant CFG_GRPCI2_BAR4      : integer := CONFIG_GRPCI2_BAR4;
  constant CFG_GRPCI2_BAR5      : integer := CONFIG_GRPCI2_BAR5;
  constant CFG_GRPCI2_FDEPTH    : integer := CFG_GRPCI2_FIFO;
  constant CFG_GRPCI2_FCOUNT    : integer := CFG_GRPCI2_FIFOCNT;
  constant CFG_GRPCI2_ENDIAN    : integer := CFG_GRPCI2_LENDIAN;
  constant CFG_GRPCI2_DEVINT    : integer := CFG_GRPCI2_DINT;
  constant CFG_GRPCI2_DEVINTMSK : integer := 16#CONFIG_GRPCI2_DINTMASK#;
  constant CFG_GRPCI2_HOSTINT   : integer := CFG_GRPCI2_HINT;
  constant CFG_GRPCI2_HOSTINTMSK: integer := 16#CONFIG_GRPCI2_HINTMASK#;
  constant CFG_GRPCI2_TRACE     : integer := CFG_GRPCI2_TRACEDEPTH;
  constant CFG_GRPCI2_TRACEAPB  : integer := CONFIG_GRPCI2_TRACEAPB;
  constant CFG_GRPCI2_BYPASS    : integer := CFG_GRPCI2_INBYPASS;
  constant CFG_GRPCI2_EXTCFG    : integer := CONFIG_GRPCI2_EXTCFG;

-- PCI arbiter
  constant CFG_PCI_ARB  : integer := CONFIG_PCI_ARBITER;
  constant CFG_PCI_ARBAPB : integer := CONFIG_PCI_ARBITER_APB;
  constant CFG_PCI_ARB_NGNT : integer := CONFIG_PCI_ARBITER_NREQ;

-- PCI trace buffer
  constant CFG_PCITBUFEN: integer := CONFIG_PCI_TRACE;
  constant CFG_PCITBUF  : integer := CFG_PCI_TRACEBUF;

-- UART 1
  constant CFG_UART1_ENABLE : integer := CONFIG_UART1_ENABLE;
  constant CFG_UART1_FIFO   : integer := CFG_UA1_FIFO;

-- UART 2
  constant CFG_UART2_ENABLE : integer := CONFIG_UART2_ENABLE;
  constant CFG_UART2_FIFO   : integer := CFG_UA2_FIFO;

-- LEON3 interrupt controller
  constant CFG_IRQ3_ENABLE  : integer := CONFIG_IRQ3_ENABLE;
  constant CFG_IRQ3_NSEC    : integer := CONFIG_IRQ3_NSEC;

-- Modular timer
  constant CFG_GPT_ENABLE   : integer := CONFIG_GPT_ENABLE;
  constant CFG_GPT_NTIM     : integer := CONFIG_GPT_NTIM;
  constant CFG_GPT_SW       : integer := CONFIG_GPT_SW;
  constant CFG_GPT_TW       : integer := CONFIG_GPT_TW;
  constant CFG_GPT_IRQ      : integer := CONFIG_GPT_IRQ;
  constant CFG_GPT_SEPIRQ   : integer := CONFIG_GPT_SEPIRQ;
  constant CFG_GPT_WDOGEN   : integer := CONFIG_GPT_WDOGEN;
  constant CFG_GPT_WDOG     : integer := 16#CONFIG_GPT_WDOG#;

-- GPIO port
  constant CFG_GRGPIO_ENABLE : integer := CONFIG_GRGPIO_ENABLE;
  constant CFG_GRGPIO_IMASK  : integer := 16#CONFIG_GRGPIO_IMASK#;
  constant CFG_GRGPIO_WIDTH  : integer := CONFIG_GRGPIO_WIDTH;

-- Dynamic Partial Reconfiguration
  constant CFG_PRC : integer := CONFIG_PARTIAL;
  constant CFG_CRC_EN : integer := CONFIG_CRC;
  constant CFG_EDAC_EN : integer := CONFIG_EDAC;
  constant CFG_WORDS_BLOCK : integer := CONFIG_BLOCK;
  constant CFG_DCM_FIFO : integer := CONFIG_DCM_FIFO;
  constant CFG_DPR_FIFO : integer := CFG_DPRFIFO;

-- GRLIB debugging
  constant CFG_DUART    : integer := CONFIG_DEBUG_UART;

