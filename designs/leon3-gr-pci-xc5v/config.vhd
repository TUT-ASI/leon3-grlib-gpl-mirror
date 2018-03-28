



-----------------------------------------------------------------------------
-- LEON3 Demonstration design test bench configuration
-- Copyright (C) 2009 Aeroflex Gaisler
------------------------------------------------------------------------------


library techmap;
use techmap.gencomp.all;

package config is
-- Technology and synthesis options
  constant CFG_FABTECH : integer := virtex5;
  constant CFG_MEMTECH : integer := virtex5;
  constant CFG_PADTECH : integer := virtex5;
  constant CFG_NOASYNC : integer := 0;
  constant CFG_SCAN : integer := 0;
-- Clock generator
  constant CFG_CLKTECH : integer := virtex5;
  constant CFG_CLKMUL : integer := (6);
  constant CFG_CLKDIV : integer := (5);
  constant CFG_OCLKDIV : integer := 1;
  constant CFG_OCLKBDIV : integer := 0;
  constant CFG_OCLKCDIV : integer := 0;
  constant CFG_PCIDLL : integer := 0;
  constant CFG_PCISYSCLK: integer := 0;
  constant CFG_CLK_NOFB : integer := 0;
-- LEON3 processor core
  constant CFG_LEON3 : integer := 1;
  constant CFG_NCPU : integer := (1);
  constant CFG_NWIN : integer := (8);
  constant CFG_V8 : integer := 2 + 4*0;
  constant CFG_MAC : integer := 0;
  constant CFG_BP : integer := 0;
  constant CFG_SVT : integer := 1;
  constant CFG_RSTADDR : integer := 16#00000#;
  constant CFG_LDDEL : integer := (1);
  constant CFG_NOTAG : integer := 0;
  constant CFG_NWP : integer := (2);
  constant CFG_PWD : integer := 1*2;
  constant CFG_FPU : integer := 0 + 16*0 + 32*0;
  constant CFG_GRFPUSH : integer := 0;
  constant CFG_ICEN : integer := 1;
  constant CFG_ISETS : integer := 2;
  constant CFG_ISETSZ : integer := 8;
  constant CFG_ILINE : integer := 8;
  constant CFG_IREPL : integer := 1;
  constant CFG_ILOCK : integer := 0;
  constant CFG_ILRAMEN : integer := 0;
  constant CFG_ILRAMADDR: integer := 16#8E#;
  constant CFG_ILRAMSZ : integer := 1;
  constant CFG_DCEN : integer := 1;
  constant CFG_DSETS : integer := 2;
  constant CFG_DSETSZ : integer := 4;
  constant CFG_DLINE : integer := 4;
  constant CFG_DREPL : integer := 1;
  constant CFG_DLOCK : integer := 0;
  constant CFG_DSNOOP : integer := 1*2 + 4*0;
  constant CFG_DFIXED : integer := 16#0#;
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
  constant CFG_ITBSZ : integer := 2;
  constant CFG_ATBSZ : integer := 2;
  constant CFG_LEON3FT_EN : integer := 0;
  constant CFG_IUFT_EN : integer := 0;
  constant CFG_FPUFT_EN : integer := 0;
  constant CFG_RF_ERRINJ : integer := 0;
  constant CFG_CACHE_FT_EN : integer := 0;
  constant CFG_CACHE_ERRINJ : integer := 0;
  constant CFG_LEON3_NETLIST: integer := 0;
  constant CFG_DISAS : integer := 0 + 0;
  constant CFG_PCLOW : integer := 2;
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
-- USB DSU
  constant CFG_GRUSB_DCL : integer := 0;
  constant CFG_GRUSB_DCL_UIFACE : integer := 1;
  constant CFG_GRUSB_DCL_DW : integer := 8;
-- Ethernet DSU
  constant CFG_DSU_ETH : integer := 1 + 0 + 0;
  constant CFG_ETH_BUF : integer := 2;
  constant CFG_ETH_IPM : integer := 16#C0A8#;
  constant CFG_ETH_IPL : integer := 16#0033#;
  constant CFG_ETH_ENM : integer := 16#020000#;
  constant CFG_ETH_ENL : integer := 16#0d0007#;
-- LEON2 memory controller
  constant CFG_MCTRL_LEON2 : integer := 1;
  constant CFG_MCTRL_RAM8BIT : integer := 0;
  constant CFG_MCTRL_RAM16BIT : integer := 0;
  constant CFG_MCTRL_5CS : integer := 0;
  constant CFG_MCTRL_SDEN : integer := 1;
  constant CFG_MCTRL_SEPBUS : integer := 1;
  constant CFG_MCTRL_INVCLK : integer := 0;
  constant CFG_MCTRL_SD64 : integer := 1;
  constant CFG_MCTRL_PAGE : integer := 0 + 0;
-- AHB status register
  constant CFG_AHBSTAT : integer := 1;
  constant CFG_AHBSTATN : integer := (1);
-- AHB RAM
  constant CFG_AHBRAMEN : integer := 0;
  constant CFG_AHBRSZ : integer := 1;
  constant CFG_AHBRADDR : integer := 16#A00#;
  constant CFG_AHBRPIPE : integer := 0;
-- Gaisler Ethernet core
  constant CFG_GRETH : integer := 1;
  constant CFG_GRETH1G : integer := 0;
  constant CFG_ETH_FIFO : integer := 32;


-- CAN 2.0 interface
  constant CFG_CAN : integer := 0;
  constant CFG_CAN_NUM : integer := 1;
  constant CFG_CANIO : integer := 16#0#;
  constant CFG_CANIRQ : integer := 0;
  constant CFG_CANSEPIRQ: integer := 0;
  constant CFG_CAN_SYNCRST : integer := 0;
  constant CFG_CANFT : integer := 0;

-- Spacewire interface
  constant CFG_SPW_EN : integer := 0;
  constant CFG_SPW_NUM : integer := 1;
  constant CFG_SPW_AHBFIFO : integer := 4;
  constant CFG_SPW_RXFIFO : integer := 16;
  constant CFG_SPW_RMAP : integer := 0;
  constant CFG_SPW_RMAPBUF : integer := 4;
  constant CFG_SPW_RMAPCRC : integer := 0;
  constant CFG_SPW_NETLIST : integer := 0;
  constant CFG_SPW_FT : integer := 0;
  constant CFG_SPW_GRSPW : integer := 2;
  constant CFG_SPW_RXUNAL : integer := 0;
  constant CFG_SPW_DMACHAN : integer := 1;
  constant CFG_SPW_PORTS : integer := 1;
  constant CFG_SPW_INPUT : integer := 2;
  constant CFG_SPW_OUTPUT : integer := 0;
  constant CFG_SPW_RTSAME : integer := 0;
-- PCI interface
  constant CFG_PCI : integer := 2;
  constant CFG_PCIVID : integer := 16#1AC8#;
  constant CFG_PCIDID : integer := 16#0054#;
  constant CFG_PCIDEPTH : integer := 16;
  constant CFG_PCI_MTF : integer := 1;

-- PCI arbiter
  constant CFG_PCI_ARB : integer := 0;
  constant CFG_PCI_ARBAPB : integer := 0;
  constant CFG_PCI_ARB_NGNT : integer := 4;

-- PCI trace buffer
  constant CFG_PCITBUFEN: integer := 0;
  constant CFG_PCITBUF : integer := 256;

-- USB Host Controller
  constant CFG_GRUSBHC : integer := 0;
  constant CFG_GRUSBHC_NPORTS : integer := 1;
  constant CFG_GRUSBHC_EHC : integer := 0;
  constant CFG_GRUSBHC_UHC : integer := 0;
  constant CFG_GRUSBHC_NCC : integer := 1;
  constant CFG_GRUSBHC_NPCC : integer := 1;
  constant CFG_GRUSBHC_PRR : integer := 0;
  constant CFG_GRUSBHC_PR1 : integer := 0*2**26 + 0*2**22 + 0*2**18 + 0*2**14 + 0*2**10 + 0*2**6 + 0*2**2 + (1/4);
  constant CFG_GRUSBHC_PR2 : integer := 0*2**26 + 0*2**22 + 0*2**18 + 0*2**14 + 0*2**10 + 0*2**6 + 0*2**2 + (1 mod 4);
  constant CFG_GRUSBHC_ENDIAN : integer := 1;
  constant CFG_GRUSBHC_BEREGS : integer := 0;
  constant CFG_GRUSBHC_BEDESC : integer := 0;
  constant CFG_GRUSBHC_BLO : integer := 3;
  constant CFG_GRUSBHC_BWRD : integer := 16;
  constant CFG_GRUSBHC_UTM : integer := 2;
  constant CFG_GRUSBHC_VBUSCONF : integer := 1;

-- GR USB 2.0 Device Controller
  constant CFG_GRUSBDC : integer := 0;
  constant CFG_GRUSBDC_AIFACE : integer := 0;
  constant CFG_GRUSBDC_UIFACE : integer := 1;
  constant CFG_GRUSBDC_DW : integer := 8;
  constant CFG_GRUSBDC_NEPI : integer := 1;
  constant CFG_GRUSBDC_NEPO : integer := 1;
  constant CFG_GRUSBDC_I0 : integer := 1024;
  constant CFG_GRUSBDC_I1 : integer := 1024;
  constant CFG_GRUSBDC_I2 : integer := 1024;
  constant CFG_GRUSBDC_I3 : integer := 1024;
  constant CFG_GRUSBDC_I4 : integer := 1024;
  constant CFG_GRUSBDC_I5 : integer := 1024;
  constant CFG_GRUSBDC_I6 : integer := 1024;
  constant CFG_GRUSBDC_I7 : integer := 1024;
  constant CFG_GRUSBDC_I8 : integer := 1024;
  constant CFG_GRUSBDC_I9 : integer := 1024;
  constant CFG_GRUSBDC_I10 : integer := 1024;
  constant CFG_GRUSBDC_I11 : integer := 1024;
  constant CFG_GRUSBDC_I12 : integer := 1024;
  constant CFG_GRUSBDC_I13 : integer := 1024;
  constant CFG_GRUSBDC_I14 : integer := 1024;
  constant CFG_GRUSBDC_I15 : integer := 1024;
  constant CFG_GRUSBDC_O0 : integer := 1024;
  constant CFG_GRUSBDC_O1 : integer := 1024;
  constant CFG_GRUSBDC_O2 : integer := 1024;
  constant CFG_GRUSBDC_O3 : integer := 1024;
  constant CFG_GRUSBDC_O4 : integer := 1024;
  constant CFG_GRUSBDC_O5 : integer := 1024;
  constant CFG_GRUSBDC_O6 : integer := 1024;
  constant CFG_GRUSBDC_O7 : integer := 1024;
  constant CFG_GRUSBDC_O8 : integer := 1024;
  constant CFG_GRUSBDC_O9 : integer := 1024;
  constant CFG_GRUSBDC_O10 : integer := 1024;
  constant CFG_GRUSBDC_O11 : integer := 1024;
  constant CFG_GRUSBDC_O12 : integer := 1024;
  constant CFG_GRUSBDC_O13 : integer := 1024;
  constant CFG_GRUSBDC_O14 : integer := 1024;
  constant CFG_GRUSBDC_O15 : integer := 1024;
-- UART 1
  constant CFG_UART1_ENABLE : integer := 1;
  constant CFG_UART1_FIFO : integer := 4;

-- UART 2
  constant CFG_UART2_ENABLE : integer := 1;
  constant CFG_UART2_FIFO : integer := 4;

-- LEON3 interrupt controller
  constant CFG_IRQ3_ENABLE : integer := 1;
  constant CFG_IRQ3_NSEC : integer := 0;

-- Modular timer
  constant CFG_GPT_ENABLE : integer := 1;
  constant CFG_GPT_NTIM : integer := (2);
  constant CFG_GPT_SW : integer := (16);
  constant CFG_GPT_TW : integer := (32);
  constant CFG_GPT_IRQ : integer := (8);
  constant CFG_GPT_SEPIRQ : integer := 1;
  constant CFG_GPT_WDOGEN : integer := 0;
  constant CFG_GPT_WDOG : integer := 16#0#;

-- GPIO port
  constant CFG_GRGPIO_ENABLE : integer := 1;
  constant CFG_GRGPIO_IMASK : integer := 16#fe#;
  constant CFG_GRGPIO_WIDTH : integer := (8);

-- GRLIB debugging
  constant CFG_DUART : integer := 0;
end;
