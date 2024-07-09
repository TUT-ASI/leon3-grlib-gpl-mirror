-----------------------------------------------------------------------------
-- LEON5 Demonstration design test bench configuration
-- Copyright (C) 2021 Aeroflex Gaisler
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
--LEON5 processor system
  constant CFG_NCPU : integer := (1);
  constant CFG_FPUTYPE : integer := 0;
  constant CFG_PERFCFG : integer := (0);
  constant CFG_RFCONF : integer := (0) + (0);
  constant CFG_CMEMCONF : integer := (0) + (0) + (0);
  constant CFG_TCMCONF : integer := (0) + 256*(0);
  constant CFG_AHBW : integer := 128;
  constant CFG_BWMASK : integer := 16#00FF#;
  constant CFG_DFIXED : integer := 16#0#;
-- DSU UART
  constant CFG_AHB_UART : integer := 1;
-- JTAG based DSU interface
  constant CFG_AHB_JTAG : integer := 0;
-- AHB status register
  constant CFG_AHBSTAT : integer := 1;
  constant CFG_AHBSTATN : integer := (1);
-- AHB ROM
  constant CFG_AHBROMEN : integer := 0;
  constant CFG_AHBROPIP : integer := 0;
  constant CFG_AHBRODDR : integer := 16#000#;
  constant CFG_ROMADDR : integer := 16#000#;
  constant CFG_ROMMASK : integer := 16#E00# + 16#000#;
-- AHB RAM
  constant CFG_AHBRAMEN : integer := 1;
  constant CFG_AHBRSZ : integer := 128;
  constant CFG_AHBRADDR : integer := 16#400#;
  constant CFG_AHBRPIPE : integer := 0;
-- GPIO port
  constant CFG_GRGPIO_ENABLE : integer := 0;
  constant CFG_GRGPIO_IMASK : integer := 16#0000#;
  constant CFG_GRGPIO_WIDTH : integer := 1;
-- LEON5 subsystem debugging
  constant CFG_DISAS : integer := 0;
  constant CFG_AHBTRACE: integer := 0;
end;
