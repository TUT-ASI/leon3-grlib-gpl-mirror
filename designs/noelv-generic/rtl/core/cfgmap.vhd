------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 

use work.config.all;
use work.config_local.all;

package cfgmap is

  -- AHB master index
  constant GRETH_HMINDEX    : integer := CFG_LOCAL_NCPU;
  constant NFC2_HMINDEX     : integer := CFG_LOCAL_NCPU + 1;
  constant CANFD0_HMINDEX    : integer := CFG_LOCAL_NCPU + 2;
  constant CANFD1_HMINDEX    : integer := CFG_LOCAL_NCPU + 3;
  constant HSSL0_HMINDEX     : integer := CFG_LOCAL_NCPU + 4;
  constant HSSL1_HMINDEX     : integer := CFG_LOCAL_NCPU + 5;
  constant SPW_HMINDEX       : integer := CFG_LOCAL_NCPU + 6;
  
  -- AHB slave index
  constant L2C_HSINDEX      : integer := 0;
  constant MEM_HSINDEX      : integer := 0;
  constant ROM_HSINDEX      : integer := 1;
  constant APB0_HSINDEX     : integer := 2;
  constant APB1_HSINDEX     : integer := 3;
  constant HSSL0_HSINDEX    : integer := 4;
  constant HSSL1_HSINDEX    : integer := 5;
  constant SPW_HSINDEX      : integer := 6;
  constant AHBREP_HSINDEX   : integer := 7;
  
  
  -- AHB slave address
  constant L2C_HADDR        : integer := 16#000#;
  constant L2C_HMASK        : integer := 16#800#;
  constant L2C_IOADDR       : integer := 16#FF0#;
  constant MEM_HADDR        : integer := 16#000#;
  constant MEM_HMASK        : integer := 16#800#;
  constant ROM_HADDR        : integer := 16#C00#;
  constant ROM_HMASK        : integer := 16#E00#;
  constant AHBREP_HADDR     : integer := 16#800#;
  constant AHBREP_HMASK     : integer := 16#FFF#;
  constant HSSL_HADDR       : integer := 16#C00#;
  constant HSSL_HMASK       : integer := 16#FF0#;
  -- AHB slave IO address
  constant SPW_HADDR        : integer := 16#800#;
  constant SPW_HMASK        : integer := 16#FF0#;
  
  -- APB slave index
  constant MEM_PINDEX       : integer := 0;
  constant GRVER_PINDEX     : integer := 1;
  constant AHBSTAT_PINDEX   : integer := 2;
  constant GRGPIO_PINDEX    : integer := 3;
  constant GRETH_PINDEX     : integer := 4;
  constant GRETH_PHY_PINDEX : integer := 5;
  constant AHBUART_PINDEX   : integer := 6;
  constant NFC2_PINDEX      : integer := 7;
  constant LOGAN0_PINDEX    : integer := 8;
  constant LOGAN1_PINDEX    : integer := 9;
  constant CANFD0_PINDEX    : integer := 10;
  constant CANFD1_PINDEX    : integer := 11;
  constant SPW_PINDEX       : integer := 12;

  -- APB slave address
  constant MEM_PADDR        : integer := 16#800#;
  constant MEM_PMASK        : integer := 16#FFF#;
  constant GRVER_PADDR      : integer := 16#810#;
  constant GRVER_PMASK      : integer := 16#FFF#;
  constant AHBSTAT_PADDR    : integer := 16#820#;
  constant AHBSTAT_PMASK    : integer := 16#FFF#;
  constant GRGPIO_PADDR     : integer := 16#830#;
  constant GRGPIO_PMASK     : integer := 16#FFF#;
  constant GRETH_PADDR      : integer := 16#840#;
  constant GRETH_PMASK      : integer := 16#FFF#;
  constant GRETH_PHY_PADDR  : integer := 16#850#;
  constant GRETH_PHY_PMASK  : integer := 16#FF0#;
  constant AHBUART_PADDR    : integer := 16#860#;
  constant AHBUART_PMASK    : integer := 16#FFF#;
  constant NFC2_PADDR       : integer := 16#870#;
  constant NFC2_PMASK       : integer := 16#FFE#;
  constant LOGAN0_PADDR     : integer := 16#D00#;
  constant LOGAN0_PMASK     : integer := 16#F00#;
  constant LOGAN1_PADDR     : integer := 16#E00#;
  constant LOGAN1_PMASK     : integer := 16#F00#;
  constant CANFD0_PADDR     : integer := 16#000#;
  constant CANFD0_PMASK     : integer := 16#FFC#;
  constant CANFD1_PADDR     : integer := 16#010#;
  constant CANFD1_PMASK     : integer := 16#FFC#;
  constant SPW_PADDR        : integer := 16#0D0#;
  constant SPW_PMASK        : integer := 16#FF0#;


  -- AHB master index (DEBUG)
  constant UART_DM_HMINDEX  : integer := 0;
  constant JTAG_DM_HMINDEX  : integer := 1;
  constant GRETH_DM_HMINDEX : integer := 2;
  constant CANFD0_DM_HMINDEX  : integer := 3;
  constant CANFD1_DM_HMINDEX  : integer := 4;
  constant JTAGRV0_DM_HMINDEX : integer := 5;
  constant JTAGRV1_DM_HMINDEX : integer := 6;
  constant AT_DM_HMINDEX    : integer := 7;


  -- IRQ
  constant AHBSTAT_PIRQ     : integer := 4;
  constant GRETH_PIRQ       : integer := 5;
  constant GRETH_PHY_PIRQ   : integer := 6;
  constant NFC2_PIRQ        : integer := 7;
  constant CANFD0_PIRQ      : integer := 8;
  constant CANFD1_PIRQ      : integer := 9;
  constant HSSL0_PIRQ       : integer := 10;
  constant HSSL1_PIRQ       : integer := 11;
  constant SPW_PIRQ         : integer := 11;

end; 
