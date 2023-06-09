-----------------------------------------------------------------------------
-- LEON5 Demonstration design test bench configuration
-- Copyright (C) 2021 Aeroflex Gaisler
------------------------------------------------------------------------------
library techmap;
use techmap.gencomp.all;
package config is
-- Technology and synthesis options
  constant CFG_FABTECH : integer := kintexu;
  constant CFG_MEMTECH : integer := kintexu;
  constant CFG_PADTECH : integer := kintexu;
  constant CFG_TRANSTECH : integer := TT_XGTP0;
  constant CFG_NOASYNC : integer := 0;
  constant CFG_SCAN : integer := 0;
-- Clock generator
  constant CFG_CLKTECH : integer := kintexu;
  constant CFG_CLKMUL : integer := (2);
  constant CFG_CLKDIV : integer := (6);
  constant CFG_OCLKDIV : integer := 1;
  constant CFG_OCLKBDIV : integer := 0;
  constant CFG_OCLKCDIV : integer := 0;
  constant CFG_PCIDLL : integer := 0;
  constant CFG_PCISYSCLK: integer := 0;
  constant CFG_CLK_NOFB : integer := 0;
--LEON5 processor system
  constant CFG_NCPU : integer := (1);
  constant CFG_FPUTYPE : integer := 0;
  constant CFG_PERFCFG : integer := (0);
  constant CFG_RFCONF : integer := (0) + (0);
  constant CFG_CMEMCONF : integer := (0) + (0) + (0);
  constant CFG_AHBW : integer := 128;
  constant CFG_BWMASK : integer := 16#00FF#;
  constant CFG_DFIXED : integer := 16#0#;
-- L2 Cache
  constant CFG_L2_EN : integer := 0;
  constant CFG_L2_SIZE : integer := 128;
  constant CFG_L2_WAYS : integer := 4;
  constant CFG_L2_HPROT : integer := 0;
  constant CFG_L2_PEN : integer := 0;
  constant CFG_L2_WT : integer := 0;
  constant CFG_L2_RAN : integer := 0;
  constant CFG_L2_SHARE : integer := 0;
  constant CFG_L2_LSZ : integer := 32;
  constant CFG_L2_MAP : integer := 16#00F0#;
  constant CFG_L2_MTRR : integer := (0);
  constant CFG_L2_EDAC : integer := 0;
  constant CFG_L2_AXI : integer := 1;
-- DSU UART
  constant CFG_AHB_UART : integer := 1;
-- JTAG based DSU interface
  constant CFG_AHB_JTAG : integer := 1;
-- Ethernet DSU
  constant CFG_DSU_ETH : integer := 1 + 0 + 0;
  constant CFG_ETH_BUF : integer := 2;
  constant CFG_ETH_IPM : integer := 16#C0A8#;
  constant CFG_ETH_IPL : integer := 16#0033#;
  constant CFG_ETH_ENM : integer := 16#020000#;
  constant CFG_ETH_ENL : integer := 16#000005#;
-- Xilinx MIG 7-Series
  constant CFG_MIG_7SERIES : integer := 1;
  constant CFG_MIG_7SERIES_MODEL : integer := 0;
-- AHB status register
  constant CFG_AHBSTAT : integer := 0;
  constant CFG_AHBSTATN : integer := 1;
-- AHB ROM
  constant CFG_AHBROMEN : integer := 0;
  constant CFG_AHBROPIP : integer := 0;
  constant CFG_AHBRODDR : integer := 16#000#;
  constant CFG_ROMADDR : integer := 16#000#;
  constant CFG_ROMMASK : integer := 16#E00# + 16#000#;
-- AHB RAM
  constant CFG_AHBRAMEN : integer := 0;
  constant CFG_AHBRSZ : integer := 1;
  constant CFG_AHBRADDR : integer := 16#A00#;
  constant CFG_AHBRPIPE : integer := 0;
-- Gaisler Ethernet core
  constant CFG_GRETH : integer := 1;
  constant CFG_GRETH1G : integer := 0;
  constant CFG_ETH_FIFO : integer := 8;
  constant CFG_GRETH_FMC : integer := 0;
  constant CFG_ETH_PHY_ADDR : integer := (1);
-- GPIO port
  constant CFG_GRGPIO_ENABLE : integer := 1;
  constant CFG_GRGPIO_IMASK : integer := 16#0000#;
  constant CFG_GRGPIO_WIDTH : integer := (20);
-- I2C master
  constant CFG_I2C_ENABLE : integer := 0;
-- LEON5 subsystem debugging
  constant CFG_DISAS : integer := 0;
  constant CFG_AHBTRACE: integer := 0;
end;
