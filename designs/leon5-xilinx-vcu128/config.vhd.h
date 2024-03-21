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

--LEON5 processor system
  constant CFG_NCPU    : integer := CONFIG_PROC_NUM;
  constant CFG_FPUTYPE : integer := CONFIG_FPU;
  constant CFG_AHBW    : integer := CONFIG_AHBW;
  constant CFG_BWMASK  : integer := 16#CONFIG_BWMASK#;
  constant CFG_DFIXED  : integer := 16#CONFIG_CACHE_FIXED#;

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

-- Ethernet DSU
  constant CFG_DSU_ETH	: integer := CONFIG_DSU_ETH + CONFIG_DSU_ETH_PROG + CONFIG_DSU_ETH_DIS;
  constant CFG_ETH_BUF 	: integer := CFG_DSU_ETHB;
  constant CFG_ETH_IPM 	: integer := 16#CONFIG_DSU_IPMSB#;
  constant CFG_ETH_IPL 	: integer := 16#CONFIG_DSU_IPLSB#;
  constant CFG_ETH_ENM 	: integer := 16#CONFIG_DSU_ETHMSB#;
  constant CFG_ETH_ENL 	: integer := 16#CONFIG_DSU_ETHLSB#;

-- Xilinx MIG 7-Series
  constant CFG_MIG_7SERIES    : integer := CONFIG_MIG_7SERIES;
  constant CFG_MIG_7SERIES_MODEL    : integer := CONFIG_MIG_7SERIES_MODEL;

-- AHB status register
  constant CFG_AHBSTAT 	: integer := CONFIG_AHBSTAT_ENABLE;
  constant CFG_AHBSTATN	: integer := CONFIG_AHBSTAT_NFTSLV;

-- AHB ROM
  constant CFG_AHBROMEN	: integer := CONFIG_AHBROM_ENABLE;
  constant CFG_AHBROPIP	: integer := CONFIG_AHBROM_PIPE;
  constant CFG_AHBRODDR	: integer := 16#CONFIG_AHBROM_START#;
  constant CFG_ROMADDR	: integer := 16#CONFIG_ROM_START#;
  constant CFG_ROMMASK	: integer := 16#E00# + 16#CONFIG_ROM_START#;

-- AHB RAM
  constant CFG_AHBRAMEN	: integer := CONFIG_AHBRAM_ENABLE;
  constant CFG_AHBRSZ	: integer := CFG_AHBRAMSZ;
  constant CFG_AHBRADDR	: integer := 16#CONFIG_AHBRAM_START#;
  constant CFG_AHBRPIPE : integer := CONFIG_AHBRAM_PIPE;

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

-- High Speed Serial Links
  constant CFG_GRHSSL : integer := CONFIG_GRHSSL_ENABLE;
-- GPIO port
  constant CFG_GRGPIO_ENABLE : integer := CONFIG_GRGPIO_ENABLE;
  constant CFG_GRGPIO_IMASK  : integer := 16#CONFIG_GRGPIO_IMASK#;
  constant CFG_GRGPIO_WIDTH  : integer := CONFIG_GRGPIO_WIDTH;

-- I2C master
  constant CFG_I2C_ENABLE : integer := CONFIG_I2C_ENABLE;

-- LEON5 subsystem debugging
  constant CFG_DISAS   : integer := CONFIG_IU_DISAS;
  constant CFG_AHBTRACE: integer := CONFIG_AHB_DTRACE;
