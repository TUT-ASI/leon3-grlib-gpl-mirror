------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003, Gaisler Research
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
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
-- Package: 	coremp7
-- File:	coremp7.vhd
-- Author:	Jan Andersson - Gaisler Research
-- Description:	Package containing components for CoreMP7 GRLIB bridge and
--              CoreMP7 GRLIB wrapper
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;

library gaisler;
use gaisler.leon3.all;

package coremp7 is

  component cmp7grlib
    generic(
      -- Generics passed to CoreMP7Bridge
      DEBUG   : integer := 2;
      SYNCFIQ : integer := 0;
      SYNCIRQ : integer := 0;
      -- Generics passed to CoreMP7Wrapper
      hindex  : integer := 0;
      pindex  : integer := 0;
      paddr   : integer := 16#000#;
      pmask   : integer := 16#fff#
      );
    port (
      rst             : in  std_ulogic;
      clk             : in  std_ulogic;
      --{AHB master interface (to wrapper)}
      ahbmi           : in  ahb_mst_in_type;
      ahbmo           : out ahb_mst_out_type;
      --{APB interface (to wrapper)}
      apbi            : in apb_slv_in_type;
      apbo            : out apb_slv_out_type;
      --{IRQ signals from IRQMP (to wrapper)}
      irqi            : in  l3_irq_in_type;
      irqo            : out l3_irq_out_type;
      --{Watchdog signals (to MP7Bridge)}
      WDOGRES         : in std_logic;
      WDOGRESn        : out std_logic;
      --{RVJTAG interface (to MP7Bridge)}
      ICE_nTRST       : in  std_logic;                    -- RealView ICE JTAG Reset
      ICE_TCK         : in  std_logic;                    -- RealView ICE JTAG Clock Enable
      ICE_TDI         : in  std_logic;                    -- RealView ICE JTAG Data In
      ICE_TMS         : in  std_logic;                    -- RealView ICE JTAG Mode Select
      ICE_VTref       : out std_logic;                    -- RealView ICE Target Reference Voltage
      ICE_TDO         : out std_logic;                    -- RealView ICE JTAG Data Out
      ICE_RTCK        : out std_logic;                    -- RealView ICE RTCK (Used for Adaptive Clocking)
      ICE_nSRST       : inout std_logic;                  -- RealView ICE JTAG System Reset
      ICE_DBGACK      : out std_logic;                    -- RealView ICE Debug Acknowledge (Not Used)
      ICE_DBGRQ       : out std_logic;                    -- RealView ICE Debut Request (Not Used)
      ICE_TDOUT       : out std_logic;
      ICE_nTDOEN      : out std_logic;
      --{JTAG interface (to MP7Bridge)}
      UJTAG_TCK       : in std_logic;
      UJTAG_TDI       : in std_logic;
      UJTAG_TMS       : in std_logic;
      UJTAG_TRSTB     : in std_logic;
      UJTAG_TDO       : out std_logic;
      --{Below are misc CMP7 signals (not connected through MP7Bridge)}
      --CoProcIf (Co-processor interface signals. Usually not used.)
      CPA             : in std_logic;
      CPB             : in std_logic;
      CPSEQ           : out std_logic;
      CPTBIT          : out std_logic;
      CPnI            : out std_logic;
      CPnMREQ         : out std_logic;
      CPnOPC          : out std_logic;
      CPnTRANS        : out std_logic;
      --ETMIf (Embedded Trace Macrocell (ETM) Interface. Usually not used.)
      DBGBREAK        : in std_logic;
      DBGEXT          : in std_logic_vector(1 downto 0);
      DBGRQ           : in std_logic;
      DBGACK          : out std_logic;
      DBGCOMMRX       : out std_logic;
      DBGCOMMTX       : out std_logic;
      DBGINSTRVALID   : out std_logic;
      DBGRNG          : out std_logic_vector(1 downto 0);
      DBGnEXEC        : out std_logic;
      --CFGBIGEND (When asserted (high) this input configures the CoreMP7 in bigendian mode.)
      CFGBIGEND       : in std_logic;
      --DMORE (Output which is asserted (high) during LDM and STM instructions. Normally left unconnected.)
      DMORE           : out std_logic;
      --DBGEN (Should always be tied to high.)
      DBGEN           : in std_logic
      );
  end component;

  component cmp7wrap
    generic (
      hindex  : integer := 0;
      pindex  : integer := 0;
      paddr   : integer := 16#000#;
      pmask   : integer := 16#fff#
      );     
    port (
      rst     : in  std_ulogic;
      clk     : in  std_ulogic;
      ahbmi   : in  ahb_mst_in_type;
      ahbmo   : out ahb_mst_out_type;
      apbi    : in  apb_slv_in_type;
      apbo    : out apb_slv_out_type;
      irqi    : in  l3_irq_in_type;
      irqo    : out l3_irq_out_type;
      nirq    : out std_ulogic;
      nfiq    : out std_ulogic;
      bigend  : in std_ulogic;
      -- From wrapper to MP7Bridge
      HGRANT  : out std_logic;
      HRDATA  : out std_logic_vector(31 downto 0);
      HREADY  : out std_logic;
      HRESP   : out std_logic_vector(1 downto 0);
      -- To wrapper from MP7Bridge
      HADDR   : in std_logic_vector(31 downto 0);
      HBURST  : in std_logic_vector(2 downto 0);
      HBUSREQ : in std_logic;
      HLOCK   : in std_logic;
      HPROT   : in std_logic_vector(3 downto 0);
      HRESETn : in std_logic;
      HSIZE   : in std_logic_vector(2 downto 0);
      HTRANS  : in std_logic_vector(1 downto 0);
      HWDATA  : in std_logic_vector(31 downto 0);
      HWRITE  : in std_logic
      );
  end component;
  
end coremp7;
