-----------------------------------------------------------------------------
-- LEON3 Demonstration design test bench configuration
-- Copyright (C) 2009 Aeroflex Gaisler
------------------------------------------------------------------------------
library techmap;
use techmap.gencomp.all;
package config is
-- Technology and synthesis options
  constant CFG_FABTECH : integer := altera;
  constant CFG_MEMTECH : integer := altera;
  constant CFG_PADTECH : integer := altera;
  constant CFG_TRANSTECH : integer := TT_XGTP0;
  constant CFG_NOASYNC : integer := 0;
  constant CFG_SCAN : integer := 0;
--LEON5 processor system
  constant CFG_NCPU : integer := (1);
  constant CFG_FPUTYPE : integer := 0;
  constant CFG_AHBW : integer := 64;
  constant CFG_BWMASK : integer := 16#00f0#;
  constant CFG_DFIXED : integer := 16#0#;
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
  constant CFG_ETH_ENL : integer := 16#000000#;
-- SSRAM controller
  constant CFG_SSCTRL : integer := 0;
  constant CFG_SSCTRLP16 : integer := 0;
-- I2C master
  constant CFG_I2C_ENABLE : integer := 1;
-- AHB ROM
  constant CFG_AHBROMEN : integer := 1;
  constant CFG_AHBROPIP : integer := 0;
  constant CFG_AHBRODDR : integer := 16#000#;
  constant CFG_ROMADDR : integer := 16#100#;
  constant CFG_ROMMASK : integer := 16#E00# + 16#100#;
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
-- Gaisler Ethernet core
  constant CFG_GRETH2 : integer := 1;
  constant CFG_GRETH21G : integer := 0;
  constant CFG_ETH2_FIFO : integer := 8;
-- UART 1
  constant CFG_UART1_ENABLE : integer := 1;
  constant CFG_UART1_FIFO : integer := 8;
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
  constant CFG_GRGPIO_IMASK : integer := 16#000F#;
  constant CFG_GRGPIO_WIDTH : integer := (2);
-- LEON5 subsystem debugging
  constant CFG_DISAS : integer := 0;
  constant CFG_AHBTRACE: integer := 0;
end;
