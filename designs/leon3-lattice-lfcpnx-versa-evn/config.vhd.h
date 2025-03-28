-- Technology and synthesis options
  constant CFG_FABTECH 	: integer := CONFIG_SYN_TECH;
  constant CFG_MEMTECH  : integer := CFG_RAM_TECH;
  constant CFG_PADTECH 	: integer := CFG_PAD_TECH;
  constant CFG_TRANSTECH	: integer := CFG_TRANS_TECH;
  constant CFG_NOASYNC 	: integer := CONFIG_SYN_NO_ASYNC;
  constant CFG_SCAN 	: integer := CONFIG_SYN_SCAN;

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
  constant CFG_LEONFT_EN   : integer := CONFIG_IUFT_EN + (CONFIG_CACHE_FT_EN)*8 + CONFIG_FPUFT*2048;
  constant CFG_LEON_NETLIST : integer := CONFIG_LEON_NETLIST;	
  constant CFG_DISAS    : integer := CONFIG_IU_DISAS + CONFIG_IU_DISAS_NET;
  constant CFG_PCLOW    : integer := CFG_DEBUG_PC32;
  constant CFG_STAT_ENABLE   : integer := CONFIG_STAT_ENABLE;
  constant CFG_STAT_CNT      : integer := CONFIG_STAT_CNT;
  constant CFG_STAT_NMAX     : integer := CONFIG_STAT_NMAX;
  constant CFG_NP_ASI   : integer := CONFIG_NP_ASI;
  constant CFG_WRPSR   : integer := CONFIG_WRPSR;
  constant CFG_ALTWIN   : integer := CONFIG_ALTWIN;
  constant CFG_REX      : integer := CONFIG_REX;
  constant CFG_LEON_MEMTECH : integer := (CONFIG_IU_RFINF*2**17 + CONFIG_FPU_RFINF*2**18 + CONFIG_MMU_INF*2**16);

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

-- L2 Cache
  constant CFG_L2_EN    : integer := CONFIG_L2_ENABLE;
  constant CFG_L2_SIZE	: integer := CFG_L2_SZ;
  constant CFG_L2_WAYS	: integer := CFG_L2_ASSO;
  constant CFG_L2_HPROT	: integer := CONFIG_L2_HPROT;
  constant CFG_L2_PEN  	: integer := CONFIG_L2_PEN;
  constant CFG_L2_WT   	: integer := CONFIG_L2_WT;
  constant CFG_L2_RAN  	: integer := CONFIG_L2_RAN;
  constant CFG_L2_SHARE	: integer := CONFIG_L2_SHARE;
  constant CFG_L2_LSZ  	: integer := CFG_L2_LINE;
  constant CFG_L2_MAP  	: integer := 16#CONFIG_L2_MAP#;
  constant CFG_L2_MTRR 	: integer := CONFIG_L2_MTRR;
  constant CFG_L2_EDAC	: integer := CONFIG_L2_EDAC;
  constant CFG_L2_AXI	  : integer := CONFIG_L2_AXI;

-- DSU UART
  constant CFG_AHB_UART	: integer := CONFIG_DSU_UART;

-- JTAG based DSU interface
  constant CFG_AHB_JTAG	: integer := CONFIG_DSU_JTAG;

-- AHB RAM
  constant CFG_AHBRAMEN	: integer := CONFIG_AHBRAM_ENABLE;
  constant CFG_AHBRSZ	: integer := CFG_AHBRAMSZ;
  constant CFG_AHBRADDR	: integer := 16#CONFIG_AHBRAM_START#;
  constant CFG_AHBRPIPE : integer := CONFIG_AHBRAM_PIPE;

-- FT AHB RAM
  constant CFG_FTAHBRAM_EN       : integer := CONFIG_FTAHBRAM_ENABLE;
  constant CFG_FTAHBRAM_SZ       : integer := CONFIG_FTAHBRAM_SZ;
  constant CFG_FTAHBRAM_ADDR     : integer := 16#CONFIG_FTAHBRAM_START#;
  constant CFG_FTAHBRAM_PIPE     : integer := CONFIG_FTAHBRAM_PIPE;
  constant CFG_FTAHBRAM_EDAC     : integer := CONFIG_FTAHBRAM_EDAC;
  constant CFG_FTAHBRAM_SCRU     : integer := CONFIG_FTAHBRAM_AUTOSCRUB;
  constant CFG_FTAHBRAM_ECNT     : integer := CONFIG_FTAHBRAM_ERRORCNTR;
  constant CFG_FTAHBRAM_EBIT     : integer := CONFIG_FTAHBRAM_CNTBITS;

-- AHB status register
  constant CFG_AHBSTAT 	: integer := CONFIG_AHBSTAT_ENABLE;
  constant CFG_AHBSTATN	: integer := CONFIG_AHBSTAT_NFTSLV;

-- SPI memory controller
  constant CFG_SPIMCTRL             : integer := CONFIG_SPIMCTRL;
  constant CFG_SPIMCTRL_SDCARD      : integer := 0;
  constant CFG_SPIMCTRL_READCMD     : integer := 16#CONFIG_SPIMCTRL_READCMD#;
  constant CFG_SPIMCTRL_DUMMYBYTE   : integer := CONFIG_SPIMCTRL_DUMMYBYTE;
  constant CFG_SPIMCTRL_DUALOUTPUT  : integer := CONFIG_SPIMCTRL_DUALOUTPUT;
  constant CFG_SPIMCTRL_QUADOUTPUT  : integer := CONFIG_SPIMCTRL_QUADOUTPUT;
  constant CFG_SPIMCTRL_DUALINPUT   : integer := CONFIG_SPIMCTRL_DUALINPUT;
  constant CFG_SPIMCTRL_QUADINPUT   : integer := CONFIG_SPIMCTRL_QUADINPUT;
  constant CFG_SPIMCTRL_DSPI        : integer := CONFIG_SPIMCTRL_DSPI;
  constant CFG_SPIMCTRL_QSPI        : integer := CONFIG_SPIMCTRL_QSPI;
  constant CFG_SPIMCTRL_DUMMYCYCLES : integer := CONFIG_SPIMCTRL_DUMMYCYCLES;
  constant CFG_SPIMCTRL_EXTADDR     : integer := CONFIG_SPIMCTRL_EXTADDR;
  constant CFG_SPIMCTRL_RECONF      : integer := CONFIG_SPIMCTRL_RECONF;
  constant CFG_SPIMCTRL_SCALER      : integer := CONFIG_SPIMCTRL_SCALER;
  constant CFG_SPIMCTRL_ASCALER     : integer := CONFIG_SPIMCTRL_ASCALER;
  constant CFG_SPIMCTRL_PWRUPCNT    : integer := CONFIG_SPIMCTRL_PWRUPCNT;
  constant CFG_SPIMCTRL_OFFSET      : integer := 16#CONFIG_SPIMCTRL_OFFSET#;
-- UART 1
  constant CFG_UART1_ENABLE : integer := CONFIG_UART1_ENABLE;
  constant CFG_UART1_FIFO   : integer := CFG_UA1_FIFO;

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

-- GRLIB debugging
  constant CFG_DUART    : integer := CONFIG_DEBUG_UART;

