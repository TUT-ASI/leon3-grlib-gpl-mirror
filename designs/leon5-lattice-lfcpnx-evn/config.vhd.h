-- Technology and synthesis options
  constant CFG_FABTECH 	: integer := CONFIG_SYN_TECH;
  constant CFG_MEMTECH  : integer := CFG_RAM_TECH;
  constant CFG_PADTECH 	: integer := CFG_PAD_TECH;
  constant CFG_TRANSTECH	: integer := CFG_TRANS_TECH;
  constant CFG_NOASYNC 	: integer := CONFIG_SYN_NO_ASYNC;
  constant CFG_SCAN 	: integer := CONFIG_SYN_SCAN;

--LEON5 processor system
  constant CFG_NCPU     : integer := CONFIG_PROC_NUM;
  constant CFG_FPUTYPE  : integer := CONFIG_FPU;
  constant CFG_PERFCFG  : integer := CONFIG_LEON5_PERFCFG;
  constant CFG_RFCONF   : integer := CONFIG_LEON5_RFCFG + CONFIG_LEON5_RF_FTCFG;
  constant CFG_CMEMCONF : integer := CONFIG_LEON5_CMCFG_TAG + CONFIG_LEON5_CMCFG_DATA + CONFIG_LEON5_CACHE_FTCFG;
  constant CFG_TCMCONF  : integer := CONFIG_LEON5_DTCMCFG + 256*CONFIG_LEON5_ITCMCFG;
  constant CFG_AHBW     : integer := CONFIG_AHBW;
  constant CFG_BWMASK   : integer := 16#CONFIG_BWMASK#;
  constant CFG_DFIXED   : integer := 16#CONFIG_CACHE_FIXED#;

-- DSU UART
  constant CFG_AHB_UART	: integer := CONFIG_DSU_UART;

-- JTAG based DSU interface
  constant CFG_AHB_JTAG	: integer := CONFIG_DSU_JTAG;

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

-- GPIO port
  constant CFG_GRGPIO_ENABLE : integer := CONFIG_GRGPIO_ENABLE;
  constant CFG_GRGPIO_IMASK  : integer := 16#CONFIG_GRGPIO_IMASK#;
  constant CFG_GRGPIO_WIDTH  : integer := CONFIG_GRGPIO_WIDTH;

-- LEON5 subsystem debugging
  constant CFG_DISAS   : integer := CONFIG_IU_DISAS;
  constant CFG_AHBTRACE: integer := CONFIG_AHB_DTRACE;
