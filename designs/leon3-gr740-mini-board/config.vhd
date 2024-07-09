-----------------------------------------------------------------------------
-- LEON3 Demonstration design test bench configuration
-- Copyright (C) 2009 Aeroflex Gaisler
------------------------------------------------------------------------------
library techmap;
use techmap.gencomp.all;
package config is
-- Technology and synthesis options
  constant CFG_FABTECH : integer := nexus;
  constant CFG_MEMTECH : integer := nexus;
  constant CFG_PADTECH : integer := nexus;
  constant CFG_CLKTECH : integer := nexus;
  constant CFG_TRANSTECH : integer := TT_XGTP0;
  constant CFG_NOASYNC : integer := 0;
  constant CFG_SCAN : integer := 0;

-- AMBA settings
  constant CFG_DEFMST : integer := (0);
  constant CFG_RROBIN : integer := 1;
  constant CFG_SPLIT : integer := 0;
  constant CFG_FPNPEN : integer := 0;
  constant CFG_AHBIO : integer := 16#FFF#;
  constant CFG_APBADDR : integer := 16#800#;
  constant CFG_AHB_MON : integer := 0;
  constant CFG_AHB_MONERR : integer := 0;
  constant CFG_AHB_MONWAR : integer := 0;
  constant CFG_AHB_DTRACE : integer := 0;

-- AHB status register
  constant CFG_AHBSTAT               : integer := 1;
  constant CFG_AHBSTATN              : integer := (1);

-- LEON processor core
  constant CFG_LEON                 : integer := 3;
  constant CFG_NCPU                 : integer := (1);
  constant CFG_NWIN                 : integer := (8);
  constant CFG_V8                   : integer := 2 + 4*0;
  constant CFG_MAC                  : integer := 0;
  constant CFG_SVT                  : integer := 1;
  constant CFG_RSTADDR              : integer := 16#00000#;
  constant CFG_LDDEL                : integer := (1);
  constant CFG_NWP                  : integer := (2);
  constant CFG_PWD                  : integer := 1*2;
  constant CFG_FPU                  : integer := 0 + 16*0 + 32*0;
  constant CFG_GRFPUSH              : integer := 0;
  constant CFG_ICEN                 : integer := 1;
  constant CFG_ISETS                : integer := 2;
  constant CFG_ISETSZ               : integer := 4;
  constant CFG_ILINE                : integer := 4;
  constant CFG_IREPL                : integer := 0;
  constant CFG_ILOCK                : integer := 0;
  constant CFG_ILRAMEN              : integer := 0;
  constant CFG_ILRAMADDR            : integer := 16#8E#;
  constant CFG_ILRAMSZ              : integer := 1;
  constant CFG_DCEN                 : integer := 1;
  constant CFG_DSETS                : integer := 2;
  constant CFG_DSETSZ               : integer := 4;
  constant CFG_DLINE                : integer := 4;
  constant CFG_DREPL                : integer := 0;
  constant CFG_DLOCK                : integer := 0;
  constant CFG_DSNOOP               : integer := 1*2 + 4*1;
  constant CFG_DFIXED               : integer := 16#0#;
  constant CFG_BWMASK               : integer := 16#0000#;
  constant CFG_CACHEBW              : integer := 64;
  constant CFG_DLRAMEN              : integer := 0;
  constant CFG_DLRAMADDR            : integer := 16#8F#;
  constant CFG_DLRAMSZ              : integer := 1;
  constant CFG_MMUEN                : integer := 0;
  constant CFG_ITLBNUM              : integer := 2;
  constant CFG_DTLBNUM              : integer := 2;
  constant CFG_TLB_TYPE             : integer := 1 + 0*2;
  constant CFG_TLB_REP              : integer := 1;
  constant CFG_MMU_PAGE             : integer := 0;
  constant CFG_DSU                  : integer := 1;
  constant CFG_ITBSZ                : integer := 1 + 64*0;
  constant CFG_ATBSZ                : integer := 0;
  constant CFG_LEONFT_EN            : integer := 0 + (0)*8 + 0*2048;
  constant CFG_LEON_NETLIST         : integer := 0;
  constant CFG_DISAS                : integer := 0;
  constant CFG_PCLOW                : integer := 2;
  constant CFG_STAT_ENABLE          : integer := 1;
  constant CFG_STAT_CNT             : integer := (4);
  constant CFG_STAT_NMAX            : integer := (0);
  constant CFG_NP_ASI               : integer := 1;
  constant CFG_WRPSR                : integer := 0;
  constant CFG_ALTWIN               : integer := 0;
  constant CFG_REX                  : integer := 0;
  constant CFG_LEON_MEMTECH         : integer := (0*2**17 + 0*2**18 + 0*2**16);

  ---- LEON3 interrupt controller
  constant CFG_IRQ3_ENABLE : integer := 1;
  constant CFG_IRQ3_NSEC : integer := 0;

-- Clock generator
  constant CFG_CLKMUL : integer := (4);
  constant CFG_CLKDIV : integer := (5);
  constant CFG_OCLKDIV : integer := 1;
  constant CFG_OCLKBDIV : integer := 0;
  constant CFG_OCLKCDIV : integer := 0;
  constant CFG_PCIDLL : integer := 0;
  constant CFG_PCISYSCLK: integer := 0;
  constant CFG_CLK_NOFB : integer := 0;

---- GRGPIO port
  constant CFG_GRGPIO_EN           : integer := 1;
  constant CFG_GRGPIO_WIDTH        : integer := (7);
  constant CFG_GRGPIO_IMASK        : integer := 16#0000007C#;

-- DSU UART
  constant CFG_AHB_UART : integer := 1;
-- JTAG based DSU interface
  constant CFG_AHB_JTAG : integer := 1;
-- AHB RAM
  constant CFG_AHBRAMEN : integer := 1;
  constant CFG_AHBRSZ : integer := 128;
  constant CFG_AHBRADDR : integer := 16#400#;
  constant CFG_AHBRPIPE : integer := 0;
-- FT AHB RAM
  constant CFG_FTAHBRAM_EN : integer := 0;
  constant CFG_FTAHBRAM_SZ : integer := 4;
  constant CFG_FTAHBRAM_ADDR : integer := 16#400#;
  constant CFG_FTAHBRAM_PIPE : integer := 0;
  constant CFG_FTAHBRAM_EDAC : integer := 0;
  constant CFG_FTAHBRAM_SCRU : integer := 0;
  constant CFG_FTAHBRAM_ECNT : integer := 0;
  constant CFG_FTAHBRAM_EBIT : integer := (2);
-- SPI memory controller
  constant CFG_SPIMCTRL : integer := 1;
  constant CFG_SPIMCTRL_SDCARD : integer := 0;
  constant CFG_SPIMCTRL_READCMD : integer := 16#3B#;
  constant CFG_SPIMCTRL_DUMMYBYTE : integer := 1;
  constant CFG_SPIMCTRL_DUALOUTPUT : integer := 1;
  constant CFG_SPIMCTRL_QUADOUTPUT : integer := 0;
  constant CFG_SPIMCTRL_DUALINPUT : integer := 0;
  constant CFG_SPIMCTRL_QUADINPUT : integer := 0;
  constant CFG_SPIMCTRL_DSPI : integer := 0;
  constant CFG_SPIMCTRL_QSPI : integer := 0;
  constant CFG_SPIMCTRL_DUMMYCYCLES : integer := (0);
  constant CFG_SPIMCTRL_EXTADDR : integer := 0;
  constant CFG_SPIMCTRL_RECONF : integer := 0;
  constant CFG_SPIMCTRL_SCALER : integer := (3);
  constant CFG_SPIMCTRL_ASCALER : integer := (8);
  constant CFG_SPIMCTRL_PWRUPCNT : integer := 0;
  constant CFG_SPIMCTRL_OFFSET : integer := 16#0#;
-- UART 1
  constant CFG_UART1_ENABLE : integer := 1;
  constant CFG_UART1_FIFO : integer := 4;

-- Modular timer
  constant CFG_GPT_ENABLE : integer := 1;
  constant CFG_GPT_NTIM : integer := (2);
  constant CFG_GPT_SW : integer := (8);
  constant CFG_GPT_TW : integer := (32);
  constant CFG_GPT_IRQ : integer := (8);
  constant CFG_GPT_SEPIRQ : integer := 1;
  constant CFG_GPT_WDOGEN : integer := 0;
  constant CFG_GPT_WDOG : integer := 16#0#;

-- PCI arbiter
  constant CFG_PCI_ARB : integer := 1;
  constant CFG_PCI_ARBAPB : integer := 1;
  constant CFG_PCI_ARB_NGNT : integer :=(2);

-- GRPCI2 interface
  constant CFG_FGPA_HOST : integer := 0; -- 0: GR740 is host, 1: FPGA is host
  constant CFG_GRPCI2_MASTER : integer := 1;
  constant CFG_GRPCI2_TARGET : integer := 1;
  constant CFG_GRPCI2_DMA : integer := 0;
  constant CFG_GRPCI2_VID : integer := 16#1AC8#;
  constant CFG_GRPCI2_DID : integer := 16#0055#;
  constant CFG_GRPCI2_CLASS : integer := 16#FF0000#;
  constant CFG_GRPCI2_RID : integer := 16#00#;
  constant CFG_GRPCI2_CAP : integer := 16#40#;
  constant CFG_GRPCI2_NCAP : integer := 16#00#;
  constant CFG_GRPCI2_BAR0 : integer := (26);
  constant CFG_GRPCI2_BAR1 : integer := (20);
  constant CFG_GRPCI2_BAR2 : integer := (0);
  constant CFG_GRPCI2_BAR3 : integer := (0);
  constant CFG_GRPCI2_BAR4 : integer := (0);
  constant CFG_GRPCI2_BAR5 : integer := (0);
  constant CFG_GRPCI2_FDEPTH : integer := 4;
  constant CFG_GRPCI2_FCOUNT : integer := 2;
  constant CFG_GRPCI2_ENDIAN : integer := 0;
  constant CFG_GRPCI2_DEVINT : integer := 0;
  constant CFG_GRPCI2_DEVINTMSK : integer := 16#0#;
  constant CFG_GRPCI2_HOSTINT : integer := 0;
  constant CFG_GRPCI2_HOSTINTMSK: integer := 16#0#;
  constant CFG_GRPCI2_TRACE : integer := 1;
  constant CFG_GRPCI2_BYPASS : integer := 0;
  constant CFG_GRPCI2_EXTCFG : integer := (0);

-- GRLIB debugging
  constant CFG_DUART : integer := 1;

-- Spacewire router
  constant CFG_SPW_EN           : integer := 0;
  constant CFG_SPW_LOOP_BACK    : integer := 0;  -- Loopback, prevents pad instantiation
  constant CFG_SPW_PADS         : integer := 1;  -- Instantiate pads
  constant CFG_SPW_INPUT_TYPE   : integer := 3;  -- Receiver type: DDR(3), SDR(2) or XOR (0)
  constant CFG_SPW_OUTPUT_TYPE  : integer := 0;  -- Transmitter type 0 = SDR
  constant CFG_SPW_RXTX_SAMECLK : integer := 1;  -- 1 = same clock for rx and tx
  constant CFG_SPW_FIFOSIZE     : integer := 16;        -- # N-char FIFO
  constant CFG_SPW_TECH         : integer := CFG_MEMTECH;
  constant CFG_SPW_TECHFIFO     : integer := 1;  -- Use RAM cells for FIFOs
  constant CFG_SPW_FT           : integer := 0;  -- Fault-tolerance
  constant CFG_SPW_SPWPORTS     : integer := 1;
  constant CFG_SPW_AMBAPORTS    : integer := 1;
  constant CFG_SPW_FIFOPORTS    : integer := 1;
  constant CFG_SPW_ARBITRATION  : integer := 0;  -- Unused
  constant CFG_SPW_RMAP         : integer := 16#FFFF#;  -- Hardware RMAP target
  constant CFG_SPW_RMAPCRC      : integer := 16#FFFF#;  -- Covered by CFG_SPW_RMAP
  constant CFG_SPW_FIFOSIZE2    : integer := 16;
  constant CFG_SPW_RXUNALIGNED  : integer := 16#FFFF#;  -- Covered by CFG_SPW_RMAP
  constant CFG_SPW_RMAPBUFS     : integer := 4;  -- # buffers to hold RMAP replies
  constant CFG_SPW_DMACHAN      : integer := 1;  -- # DMA channels
  constant CFG_SPW_TIMERBITS    : integer := 16;
  constant CFG_SPW_PNP          : integer := 0;  -- Specification not done
  constant CFG_SPW_AUTOSCRUB    : integer := 0;  -- Automatic scrub of table
  -- SpaceWire Router instance ID, CFG_SPWINSTID will be present on bits
  -- 7:2 in the SpaceWire router instance ID.
  constant CFG_SPWINSTID        : integer := 00;  -- Will start at 0x40



  -- HSSL/SpaceFibre
  constant CFG_HSSL_EN : integer := 0;
  constant CFG_HSSL_EN_SD0 : integer := 0; -- FMC DP3
  constant CFG_HSSL_EN_SD2 : integer := 0; -- FMC DP1
  constant CFG_HSSL_EN_SD6 : integer := 0; -- FMC DP2
  constant CFG_HSSL_EN_SD7 : integer := 1; -- FMC DP0

  -- Reference clock selection for the two quads.
  -- 0: Use quad-local reference clock
  -- 1: Use quad 0 external reference clock (FMC GBTCLK1)
  -- 2: Use quad 1 external reference clock (FMC GBTCLK0)
  --
  -- The quad-local clock references are taken from on-board HCSL
  -- oscillators. For quad 0 the frequency is 156.25MHz while for quad 1
  -- it is 100.00MHz. The names on the schematic are inverted. I.e.
  -- SDQ1_REFCLK is connected to quad 0 while SDQ0_REFCLK is connected to
  -- quad 1. This design uses the FPGA signal names instead of the
  -- schematic signal names.
  --
  -- Using a reference clock from a fabric PLL is possible in principle,
  -- but is not supported by this design.
  --
  -- In principle, dynamic frequency switching is supported by the SerDes,
  -- but this design has no support for it. When changing the reference
  -- clock settings make sure to update the corresponding serdes_channel_*
  -- IP configuration so that its frequency matches.
  constant CFG_HSSL_SDQ0_REFCLK : integer := 0; -- refclk for SD0 and SD2
  constant CFG_HSSL_SDQ1_REFCLK : integer := 0; -- refclk for SD6 and SD7

  constant CFG_HSSL_NUM : integer :=
    CFG_HSSL_EN_SD0 + CFG_HSSL_EN_SD2 + CFG_HSSL_EN_SD6 + CFG_HSSL_EN_SD7;
  constant CFG_GRHSSL_VC        : integer := 1;
  constant CFG_GRHSSL_RMAP      : integer := 1;


-- Ethernet
  constant CFG_GRETH : integer := 1;
  constant CFG_GRETH1G : integer := 0;
  constant CFG_ETH_FIFO : integer := 8;

-- Ethernet DSU
  constant CFG_DSU_ETH : integer := 1 + 0 + 0;
  constant CFG_ETH_BUF : integer := 16;
  constant CFG_ETH_IPM : integer := 16#C0A8#;
  constant CFG_ETH_IPL : integer := 16#0033#;
  constant CFG_ETH_ENM : integer := 16#0050c2#; -- MAC address within range globally
  constant CFG_ETH_ENL : integer := 16#75a339#; -- reserved by Gaisler


end;
