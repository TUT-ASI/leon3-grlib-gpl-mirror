-----------------------------------------------------------------------------
-- Demonstration design test bench configuration
-- Copyright (C) 2018 Cobham Gaisler AB
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
-- Clock generator
  constant CFG_CLKTECH : integer := inferred;
  constant CFG_CLKMUL : integer := 2;
  constant CFG_CLKDIV : integer := 2;
  constant CFG_OCLKDIV : integer := 1;
  constant CFG_OCLKBDIV : integer := 0;
  constant CFG_OCLKCDIV : integer := 0;
  constant CFG_PCIDLL : integer := 0;
  constant CFG_PCISYSCLK: integer := 0;
  constant CFG_CLK_NOFB : integer := 0;
-- NOEL-V processor core
  constant CFG_NOELV : integer := 1;
  constant CFG_NOELV_XLEN : integer := (64);
  constant CFG_NCPU : integer := (1);
  constant CFG_CFG : integer := (2)*256 + (0)*128 + (0)*2 + (1);
  constant CFG_NODBUS : integer := 1;
  constant CFG_DISAS : integer := 3*0;
-- Interrupts
  constant CFG_APLIC_NDOM : integer := 4;
  constant CFG_NEIID : integer := 63;
-- L2 Cache
  constant CFG_L2_EN : integer := 0;
  constant CFG_L2_LITE : integer := 0;
  constant CFG_L2_SIZE : integer := 64;
  constant CFG_L2_WAYS : integer := 4;
  constant CFG_L2_HPROT : integer := 0;
  constant CFG_L2_PEN : integer := 0;
  constant CFG_L2_WT : integer := 0;
  constant CFG_L2_RAN : integer := 0;
  constant CFG_L2_SHARE : integer := 0;
  constant CFG_L2_LSZ : integer := 32;
  constant CFG_L2_MAP : integer := 16#00FF#;
  constant CFG_L2_MTRR : integer := (0);
  constant CFG_L2_EDAC : integer := 0;
  constant CFG_L2_AXI : integer := 0;
-- AMBA settings
  constant CFG_DEFMST : integer := (0);
  constant CFG_RROBIN : integer := 1;
  constant CFG_SPLIT : integer := 1;
  constant CFG_FPNPEN : integer := 1;
  constant CFG_AHBIO : integer := 16#FFF#;
  constant CFG_APBADDR : integer := 16#800#;
  constant CFG_AHB_MON : integer := 0;
  constant CFG_AHB_MONERR : integer := 0;
  constant CFG_AHB_MONWAR : integer := 0;
  constant CFG_AHB_DTRACE : integer := 0;
-- DSU UART
  constant CFG_AHB_UART : integer := 1;
-- JTAG based DSU interface
  constant CFG_AHB_JTAG : integer := 0;
-- Ethernet DSU
  constant CFG_DSU_ETH : integer := 0 + 0 + 0;
  constant CFG_ETH_BUF : integer := 1;
  constant CFG_ETH_IPM : integer := 16#C0A8#;
  constant CFG_ETH_IPL : integer := 16#0033#;
  constant CFG_ETH_ENM : integer := 16#020000#;
  constant CFG_ETH_ENL : integer := 16#000009#;
-- AHB status register
  constant CFG_AHBSTAT : integer := 1;
  constant CFG_AHBSTATN : integer := (1);
-- NANDFCTRL2
  constant CFG_NFC2_EN : integer := 0;
  constant CFG_NFC2_NROFCE : integer := 0;
  constant CFG_NFC2_NROFCH : integer := 0;
  constant CFG_NFC2_NROFRB : integer := 0;
  constant CFG_NFC2_NROFSEFI : integer := 0;
  constant CFG_NFC2_RND : integer := 0;
  constant CFG_NFC2_MEM0_DATA : integer := 0;
  constant CFG_NFC2_MEM0_SPARE : integer := 0;
  constant CFG_NFC2_MEM0_ECC_SEL : integer := 0;
  constant CFG_NFC2_MEM1_DATA : integer := 0;
  constant CFG_NFC2_MEM1_SPARE : integer := 0;
  constant CFG_NFC2_MEM1_ECC_SEL : integer := 0;
  constant CFG_NFC2_MEM2_DATA : integer := 0;
  constant CFG_NFC2_MEM2_SPARE : integer := 0;
  constant CFG_NFC2_MEM2_ECC_SEL : integer := 0;
  constant CFG_NFC2_ECC0_GFSIZE : integer := 0;
  constant CFG_NFC2_ECC0_CHUNK : integer := 0;
  constant CFG_NFC2_ECC0_CAP : integer := 0;
  constant CFG_NFC2_ECC1_GFSIZE : integer := 0;
  constant CFG_NFC2_ECC1_CHUNK : integer := 0;
  constant CFG_NFC2_ECC1_CAP : integer := 0;
  constant CFG_NFC2_RST_CYCLES : integer := 10;
  constant CFG_NFC2_TAG_SIZE : integer := 0;
  constant CFG_NFC2_FT : integer := 0;
-- Gaisler Ethernet core
  constant CFG_GRETH : integer := 0;
  constant CFG_GRETH1G : integer := 0;
  constant CFG_ETH_FIFO : integer := 8;
  constant CFG_GRETH_FMC : integer := 0;
  constant CFG_ETH_PHY_ADDR : integer := 1;
-- GPIO port
  constant CFG_GRGPIO_ENABLE : integer := 1;
  constant CFG_GRGPIO_IMASK : integer := 16#FFFE#;
  constant CFG_GRGPIO_WIDTH : integer := (20);
-- Spacewire interface
  constant CFG_SPWRTR_ENABLE : integer := 0;
  constant CFG_SPWRTR_INPUT : integer := 2;
  constant CFG_SPWRTR_OUTPUT : integer := 0;
  constant CFG_SPWRTR_RTSAME : integer := 0;
  constant CFG_SPWRTR_RXFIFO : integer := 64;
  constant CFG_SPWRTR_TECHFIFO : integer := 1;
  constant CFG_SPWRTR_FT : integer := 0;
  constant CFG_SPWRTR_SPWEN : integer := 0;
  constant CFG_SPWRTR_AMBAEN : integer := 0;
  constant CFG_SPWRTR_FIFOEN : integer := 0;
  constant CFG_SPWRTR_SPWPORTS : integer := 2;
  constant CFG_SPWRTR_AMBAPORTS : integer := 0;
  constant CFG_SPWRTR_FIFOPORTS : integer := 0;
  constant CFG_SPWRTR_ARB : integer := 0;
  constant CFG_SPWRTR_RMAP : integer := 0;
  constant CFG_SPWRTR_RMAPCRC : integer := 0;
  constant CFG_SPWRTR_FIFO2 : integer := 4;
  constant CFG_SPWRTR_ALMOST : integer := 8;
  constant CFG_SPWRTR_RXUNAL : integer := 0;
  constant CFG_SPWRTR_RMAPBUF : integer := 4;
  constant CFG_SPWRTR_DMACHAN : integer := 1;
  constant CFG_SPWRTR_AHBSLVEN : integer := 1;
  constant CFG_SPWRTR_TIMERBITS : integer := 0;
  constant CFG_SPWRTR_PNP : integer := 1;
  constant CFG_SPWRTR_AUTOSCRUB : integer := 1;
-- GRCANFD interface
  constant CFG_GRCANFD : integer := 0;
  constant CFG_GRCANFDIRQ : integer := 0;
  constant CFG_GRCANFDSINGLE : integer := 0;
-- High Speed Serial Links
  constant CFG_HSSL_EN : integer := 0;
  constant CFG_HSSL_NUM : integer := 1;
  constant CFG_HSSL_SPFI : integer := 1;
  constant CFG_HSSL_WIZL : integer := 0;
-- GRLIB debugging
  constant CFG_DUART : integer := 1;
end;
