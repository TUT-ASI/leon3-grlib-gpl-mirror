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

-- NOEL-V processor core
  constant CFG_NOELV  	        : integer := CONFIG_NOELV;
  constant CFG_NOELV_XLEN       : integer := CONFIG_NOELV_XLEN;
  constant CFG_NCPU             : integer := CONFIG_PROC_NUM;
  constant CFG_CFG              : integer := CONFIG_PROC_TYP*256 + CONFIG_PROC_LITE*128 + CONFIG_PROC_NOFPU*2 + CONFIG_PROC_S;
  constant CFG_NODBUS           : integer := CONFIG_PROC_NODBUS;
  constant CFG_DISAS            : integer := 3*CONFIG_IU_DISAS;
-- Interrupts
  constant CFG_APLIC_NDOM       : integer := CONFIG_DOMAINS_NUM;
  constant CFG_NEIID            : integer := CONFIG_EIID_NUM;

-- L2 Cache
  constant CFG_L2_EN    : integer := CONFIG_L2_ENABLE;
  constant CFG_L2_LITE  : integer := CONFIG_L2_LITE;
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
  constant CFG_L2_AXI	: integer := CONFIG_L2_AXI;

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

-- AHB status register
  constant CFG_AHBSTAT 	: integer := CONFIG_AHBSTAT_ENABLE;
  constant CFG_AHBSTATN	: integer := CONFIG_AHBSTAT_NFTSLV;

-- NANDFCTRL2
  constant CFG_NFC2_EN            : integer := CONFIG_NANDFCTRL2_ENABLE;
  constant CFG_NFC2_NROFCE        : integer := CONFIG_NFC2_NROFCE;
  constant CFG_NFC2_NROFCH        : integer := CONFIG_NFC2_NROFCH;
  constant CFG_NFC2_NROFRB        : integer := CONFIG_NFC2_NROFRB;
  constant CFG_NFC2_NROFSEFI      : integer := CONFIG_NFC2_NROFSEFI;
  constant CFG_NFC2_RND           : integer := CONFIG_NFC2_RND;
  constant CFG_NFC2_MEM0_DATA     : integer := CONFIG_NFC2_MEM0_DATA;
  constant CFG_NFC2_MEM0_SPARE    : integer := CONFIG_NFC2_MEM0_SPARE;
  constant CFG_NFC2_MEM0_ECC_SEL  : integer := CONFIG_NFC2_MEM0_ECC_SEL;
  constant CFG_NFC2_MEM1_DATA     : integer := CONFIG_NFC2_MEM1_DATA;
  constant CFG_NFC2_MEM1_SPARE    : integer := CONFIG_NFC2_MEM1_SPARE;
  constant CFG_NFC2_MEM1_ECC_SEL  : integer := CONFIG_NFC2_MEM1_ECC_SEL;
  constant CFG_NFC2_MEM2_DATA     : integer := CONFIG_NFC2_MEM2_DATA;
  constant CFG_NFC2_MEM2_SPARE    : integer := CONFIG_NFC2_MEM2_SPARE;
  constant CFG_NFC2_MEM2_ECC_SEL  : integer := CONFIG_NFC2_MEM2_ECC_SEL;
  constant CFG_NFC2_ECC0_GFSIZE   : integer := CONFIG_NFC2_ECC0_GFSIZE;
  constant CFG_NFC2_ECC0_CHUNK    : integer := CONFIG_NFC2_ECC0_CHUNK;
  constant CFG_NFC2_ECC0_CAP      : integer := CONFIG_NFC2_ECC0_CAP;
  constant CFG_NFC2_ECC1_GFSIZE   : integer := CONFIG_NFC2_ECC1_GFSIZE;
  constant CFG_NFC2_ECC1_CHUNK    : integer := CONFIG_NFC2_ECC1_CHUNK;
  constant CFG_NFC2_ECC1_CAP      : integer := CONFIG_NFC2_ECC1_CAP;
  constant CFG_NFC2_RST_CYCLES    : integer := CONFIG_NFC2_RST_CYCLES;
  constant CFG_NFC2_TAG_SIZE      : integer := CONFIG_NFC2_TAG_SIZE;
  constant CFG_NFC2_FT            : integer := CONFIG_NFC2_FT;
-- Gaisler Ethernet core
  constant CFG_GRETH   	    : integer := CONFIG_GRETH_ENABLE;
  constant CFG_GRETH1G	    : integer := CONFIG_GRETH_GIGA;
  constant CFG_ETH_FIFO     : integer := CFG_GRETH_FIFO;
  constant CFG_GRETH_FMC    : integer := CONFIG_GRETH_FMC_MODE;
#ifdef CONFIG_GRETH_SGMII_PRESENT
  constant CFG_GRETH_SGMII  : integer := CONFIG_GRETH_SGMII_MODE;
#endif
#ifdef CONFIG_LEON3FT_PRESENT
  constant CFG_GRETH_FT     : integer := CONFIG_GRETH_FT;
  constant CFG_GRETH_EDCLFT : integer := CONFIG_GRETH_EDCLFT;
#endif
  constant CFG_ETH_PHY_ADDR : integer := CONFIG_GRETH_PHY_ADDR;
-- GPIO port
  constant CFG_GRGPIO_ENABLE : integer := CONFIG_GRGPIO_ENABLE;
  constant CFG_GRGPIO_IMASK  : integer := 16#CONFIG_GRGPIO_IMASK#;
  constant CFG_GRGPIO_WIDTH  : integer := CONFIG_GRGPIO_WIDTH;

-- Spacewire interface
  constant CFG_SPWRTR_ENABLE    : integer := CONFIG_SPWRTR_ENABLE;
  constant CFG_SPWRTR_INPUT     : integer := CONFIG_SPWRTR_INPUT;
  constant CFG_SPWRTR_OUTPUT    : integer := CONFIG_SPWRTR_OUTPUT;
  constant CFG_SPWRTR_RTSAME    : integer := CONFIG_SPWRTR_RTSAME;
  constant CFG_SPWRTR_RXFIFO    : integer := CONFIG_SPWRTR_RXFIFO;
  constant CFG_SPWRTR_TECHFIFO  : integer := CONFIG_SPWRTR_TECHFIFO;
  constant CFG_SPWRTR_FT        : integer := CONFIG_SPWRTR_FT;
  constant CFG_SPWRTR_SPWEN     : integer := CONFIG_SPWRTR_SPWEN;
  constant CFG_SPWRTR_AMBAEN    : integer := CONFIG_SPWRTR_AMBAEN;
  constant CFG_SPWRTR_FIFOEN    : integer := CONFIG_SPWRTR_FIFOEN;
  constant CFG_SPWRTR_SPWPORTS  : integer := CONFIG_SPWRTR_SPWPORTS;
  constant CFG_SPWRTR_AMBAPORTS : integer := CONFIG_SPWRTR_AMBAPORTS;
  constant CFG_SPWRTR_FIFOPORTS : integer := CONFIG_SPWRTR_FIFOPORTS;
  constant CFG_SPWRTR_ARB       : integer := CONFIG_SPWRTR_ARB;
  constant CFG_SPWRTR_RMAP      : integer := CONFIG_SPWRTR_RMAP;
  constant CFG_SPWRTR_RMAPCRC   : integer := CONFIG_SPWRTR_RMAPCRC;
  constant CFG_SPWRTR_FIFO2     : integer := CONFIG_SPWRTR_FIFO2;
  constant CFG_SPWRTR_ALMOST    : integer := CONFIG_SPWRTR_ALMOST;
  constant CFG_SPWRTR_RXUNAL    : integer := CONFIG_SPWRTR_RXUNAL;
  constant CFG_SPWRTR_RMAPBUF   : integer := CONFIG_SPWRTR_RMAPBUF;
  constant CFG_SPWRTR_DMACHAN   : integer := CONFIG_SPWRTR_DMACHAN;
  constant CFG_SPWRTR_AHBSLVEN  : integer := CONFIG_SPWRTR_AHBSLVEN;
  constant CFG_SPWRTR_TIMERBITS : integer := CONFIG_SPWRTR_TIMERBITS;
  constant CFG_SPWRTR_PNP       : integer := CONFIG_SPWRTR_PNP;
  constant CFG_SPWRTR_AUTOSCRUB : integer := CONFIG_SPWRTR_AUTOSCRUB;

-- GRCANFD interface
  constant CFG_GRCANFD       : integer := CONFIG_GRCANFD_ENABLE;
  constant CFG_GRCANFDIRQ    : integer := CONFIG_GRCANFDIRQ;
  constant CFG_GRCANFDSINGLE : integer := CONFIG_GRCANFDSINGLE;

-- High Speed Serial Links
  constant CFG_HSSL_EN   : integer := CONFIG_GRHSSL_ENABLE;
  constant CFG_HSSL_NUM  : integer := CONFIG_GRHSSL_NUM;
  constant CFG_HSSL_SPFI : integer := CONFIG_GRHSSL_SPFI;
  constant CFG_HSSL_WIZL : integer := CONFIG_GRHSSL_WIZL;
-- GRLIB debugging
  constant CFG_DUART    : integer := CONFIG_DEBUG_UART;

