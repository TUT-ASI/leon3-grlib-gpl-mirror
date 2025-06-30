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
-----------------------------------------------------------------------------
-- Entity:      noelvcfgmap
-- File:        noelvcfgmap.vhd
-- Author:      Nils Wessman Frongrade Gaisler
-- Description: NOEL-V sybsystem configuration and memory map
------------------------------------------------------------------------------

package noelvcfgmap is

  -- AHB slave address
  constant CLINT_HADDR_B    : integer := 16#E00#; -- Base address for all CLINTs
  constant CLINT_HMASK      : integer := 16#FFF#;
  constant CLINT_HADDR_O    : integer := 16#001#; -- Offset between the CLINTs
  constant L2C_HADDR        : integer := 16#000#;
  constant L2C_HMASK        : integer := 16#800#;
  constant L2C_CFG_HADDR_B  : integer := 16#F00#; -- Base address for all L2C cfg-area
  constant L2C_CFG_HMASK    : integer := 16#FF0#;
  constant L2C_CFG_HADDR_O  : integer := 16#010#; -- Offseet between the L2C cfg-area
  constant PLIC_HADDR       : integer := 16#F80#;
  constant PLIC_HMASK       : integer := 16#FC0#;
  constant DM_HADDR         : integer := 16#FE0#;
  constant DM_HMASK         : integer := 16#FF0#;
  constant AHBC_IOADDR      : integer := 16#FFF#;
  constant APBC_HADDR       : integer := 16#FC0#;
  constant APBC_HMASK       : integer := 16#FFF#;
  constant IOMMU_HADDR      : integer := 16#000#;
  constant IOMMU_HMASK      : integer := 16#FE0#;
  constant IOPMP_HADDR      : integer := 16#100#;
  constant IOPMP_HMASK      : integer := 16#F80#;
  constant IOBRIDGE_HADDR   : integer := 16#200#;
  constant IOBRIDGE_HMASK   : integer := 16#FE0#;
  constant DUMMY_HADDR      : integer := 16#FFE#;
  -- APB slave address
  constant GPTIME_PADDR     : integer := 16#000#;
  constant GPTIME_PMASK     : integer := 16#FFF#;
  constant APBUART_PADDR    : integer := 16#010#;
  constant APBUART_PMASK    : integer := 16#FFF#;
  constant ETRACE_PADDR     : integer := 16#030#;
  constant ETRACE_PMASK     : integer := 16#FF0#;
  constant IOPMP_PADDR      : integer := 16#100#;
  constant IOPMP_PMASK      : integer := 16#F80#;

  -- IRQ
  constant APBUART_PIRQ     : integer := 1;
  constant GPTIME_PIRQ      : integer := 2; -- , 3
  --constant GPTIME_PIRQ2     : integer := 3;
  constant ETRACE_PIRQ      : integer := 4;
end; 
