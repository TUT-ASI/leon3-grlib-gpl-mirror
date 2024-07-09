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
  constant CFG_TRANSTECH : integer := TT_XGTP0;
  constant CFG_NOASYNC : integer := 0;
  constant CFG_SCAN : integer := 0;
-- LEON processor core
  constant CFG_LEON : integer := 3;
  constant CFG_NCPU : integer := (1);
  constant CFG_NWIN : integer := (8);
  constant CFG_V8 : integer := 2 + 4*0;
  constant CFG_MAC : integer := 0;
  constant CFG_SVT : integer := 1;
  constant CFG_RSTADDR : integer := 16#00000#;
  constant CFG_LDDEL : integer := (1);
  constant CFG_NWP : integer := (2);
  constant CFG_PWD : integer := 1*2;
  constant CFG_FPU : integer := 0 + 16*0 + 32*0;
  constant CFG_GRFPUSH : integer := 0;
  constant CFG_ICEN : integer := 1;
  constant CFG_ISETS : integer := 2;
  constant CFG_ISETSZ : integer := 4;
  constant CFG_ILINE : integer := 4;
  constant CFG_IREPL : integer := 0;
  constant CFG_ILOCK : integer := 0;
  constant CFG_ILRAMEN : integer := 0;
  constant CFG_ILRAMADDR: integer := 16#8E#;
  constant CFG_ILRAMSZ : integer := 1;
  constant CFG_DCEN : integer := 1;
  constant CFG_DSETS : integer := 2;
  constant CFG_DSETSZ : integer := 4;
  constant CFG_DLINE : integer := 4;
  constant CFG_DREPL : integer := 0;
  constant CFG_DLOCK : integer := 0;
  constant CFG_DSNOOP : integer := 1*2 + 4*1;
  constant CFG_DFIXED : integer := 16#0#;
  constant CFG_BWMASK : integer := 16#0000#;
  constant CFG_CACHEBW : integer := 64;
  constant CFG_DLRAMEN : integer := 0;
  constant CFG_DLRAMADDR: integer := 16#8F#;
  constant CFG_DLRAMSZ : integer := 1;
  constant CFG_MMUEN : integer := 0;
  constant CFG_ITLBNUM : integer := 2;
  constant CFG_DTLBNUM : integer := 2;
  constant CFG_TLB_TYPE : integer := 1 + 0*2;
  constant CFG_TLB_REP : integer := 1;
  constant CFG_MMU_PAGE : integer := 0;
  constant CFG_DSU : integer := 1;
  constant CFG_ITBSZ : integer := 1 + 64*0;
  constant CFG_ATBSZ : integer := 0;
  constant CFG_LEONFT_EN : integer := 0 + (0)*8 + 0*2048;
  constant CFG_LEON_NETLIST : integer := 0;
  constant CFG_DISAS : integer := 0 + 0;
  constant CFG_PCLOW : integer := 2;
  constant CFG_STAT_ENABLE : integer := 1;
  constant CFG_STAT_CNT : integer := (4);
  constant CFG_STAT_NMAX : integer := (0);
  constant CFG_NP_ASI : integer := 1;
  constant CFG_WRPSR : integer := 0;
  constant CFG_ALTWIN : integer := 0;
  constant CFG_REX : integer := 0;
  constant CFG_LEON_MEMTECH : integer := (0*2**17 + 0*2**18 + 0*2**16);
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
-- DSU UART
  constant CFG_AHB_UART : integer := 1;
-- JTAG based DSU interface
  constant CFG_AHB_JTAG : integer := 1;
-- AHB RAM
  constant CFG_AHBRAMEN : integer := 1;
  constant CFG_AHBRSZ : integer := 64;
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
-- AHB status register
  constant CFG_AHBSTAT : integer := 1;
  constant CFG_AHBSTATN : integer := (1);
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
  constant CFG_SPIMCTRL_WRITECMD : integer := 16#02#;
  constant CFG_SPIMCTRL_ALLOWWRT : integer := 0;
  constant CFG_SPIMCTRL_XIPBYTE : integer := 0;
  constant CFG_SPIMCTRL_XIPPOL : integer := (1);
-- GRCAN 2.0 interface
  constant CFG_GRCAN : integer := 0;
  constant CFG_GRCANIRQ : integer := (13);
  constant CFG_GRCANSINGLE : integer := 0;
-- UART 1
  constant CFG_UART1_ENABLE : integer := 1;
  constant CFG_UART1_FIFO : integer := 4;
-- LEON3 interrupt controller
  constant CFG_IRQ3_ENABLE : integer := 1;
  constant CFG_IRQ3_NSEC : integer := 0;
-- Modular timer
  constant CFG_GPT_ENABLE : integer := 1;
  constant CFG_GPT_NTIM : integer := (2);
  constant CFG_GPT_SW : integer := (8);
  constant CFG_GPT_TW : integer := (32);
  constant CFG_GPT_IRQ : integer := (8);
  constant CFG_GPT_SEPIRQ : integer := 1;
  constant CFG_GPT_WDOGEN : integer := 0;
  constant CFG_GPT_WDOG : integer := 16#0#;
-- GPIO port
  constant CFG_GRGPIO_ENABLE : integer := 1;
  constant CFG_GRGPIO_IMASK : integer := 16#0000FFF0#;
  constant CFG_GRGPIO_WIDTH : integer := (16);
-- GRLIB debugging
  constant CFG_DUART : integer := 0;
end;
