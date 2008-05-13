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
-- Entity: 	cmp7grlib
-- File:	cmp7grlib.vhd
-- Author:	Fredrik Brunnhede
--              Mikael Brunnhede
-- Modified by  Jan Andersson, Gaisler Research
-- Description:	CoreMP7 with GRLIB bridge 
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.coremp7.all;
use gaisler.leon3.all;
library techmap;

entity cmp7grlib is
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
end;

architecture rtl of cmp7grlib is
       
  signal ABORT_s                  : std_logic;
  signal CLK_s                    : std_logic; 
  signal CLKEN_s                  : std_logic;
  signal DBGTCKEN_s               : std_logic;
  signal DBGTDI_s                 : std_logic; 
  signal DBGTMS_s                 : std_logic;
  signal DBGnTRST_s               : std_logic;
  signal DBGTDO_s                 : std_logic;
  signal RDATA_s                  : std_logic_vector(31 downto 0);
  signal nFIQ_bridgeMP7_s         : std_logic;
  signal nIRQ_bridgeMP7_s         : std_logic;
  signal nFIQ_wrapBridge_s        : std_logic;
  signal nIRQ_wrapBridge_s        : std_logic;
  signal nRESET_s                 : std_logic;
  signal ADDR_s                   : std_logic_vector(31 downto 0);
  signal DBGnTDOEN_s              : std_logic;
  signal LOCK_s                   : std_logic;
  signal PROT_s                   : std_logic_vector(1 downto 0);
  signal SIZE_s                   : std_logic_vector(1 downto 0);
  signal TRANS_s                  : std_logic_vector(1 downto 0);
  signal WDATA_s                  : std_logic_vector(31 downto 0);
  signal WRITE_s                  : std_logic;
  signal wrapper_ahb_outputs_s    : ahb_mst_in_type;
  signal wrapper_ahb_inputs_s     : ahb_mst_out_type;
  signal HRESETn_s                : std_logic;
  signal HGRANT_s                 : std_logic;
  signal nFIQ_in_s                : std_logic;
  signal nIRQ_in_s                : std_logic;
  
   
  -- A7S (CoreMP7)
  component A7S
    port(
      ABORT            : in std_logic;
      CFGBIGEND        : in std_logic;
      CLK              : in std_logic;
      CLKEN            : in std_logic;
      CPA              : in std_logic;
      CPB              : in std_logic;
      DBGBREAK         : in std_logic;
      DBGEN            : in std_logic;
      DBGEXT           : in std_logic_vector(1 downto 0);
      DBGRQ            : in std_logic;
      DBGTCKEN         : in std_logic;
      DBGTDI           : in std_logic;
      DBGTMS           : in std_logic;
      DBGnTRST         : in std_logic;
      RDATA            : in std_logic_vector(31 downto 0);
      nFIQ             : in std_logic;
      nIRQ             : in std_logic;
      nRESET           : in std_logic;
      ADDR             : out std_logic_vector(31 downto 0);
      CPSEQ            : out std_logic;
      CPTBIT           : out std_logic;
      CPnI             : out std_logic;
      CPnMREQ          : out std_logic;
      CPnOPC           : out std_logic;
      CPnTRANS         : out std_logic;
      DBGACK           : out std_logic;
      DBGCOMMRX        : out std_logic;
      DBGCOMMTX        : out std_logic;
      DBGINSTRVALID    : out std_logic;
      DBGRNG           : out std_logic_vector(1 downto 0);
      DBGTDO           : out std_logic;
      DBGnEXEC         : out std_logic;
      DBGnTDOEN        : out std_logic;
      DMORE            : out std_logic;
      LOCK             : out std_logic;
      PROT             : out std_logic_vector(1 downto 0);
      SIZE             : out std_logic_vector(1 downto 0);
      TRANS            : out std_logic_vector(1 downto 0);
      WDATA            : out std_logic_vector(31 downto 0);
      WRITE            : out std_logic
      );
  end component;
   
   
  -- CoreMP7Bridge
  component CoreMP7Bridge
    generic(
      DEBUG          : integer := 2;
      SYNCFIQ        : integer := 0;
      SYNCIRQ        : integer := 0
      );
    port(
      ADDR           : in std_logic_vector(31 downto 0);
      DBGTDO         : in std_logic;
      DBGnTDOEN      : in std_logic;
      HGRANT         : in std_logic;
      HRDATA         : in std_logic_vector(31 downto 0);
      HREADY         : in std_logic;
      HRESP          : in std_logic_vector(1 downto 0);
      LOCK           : in std_logic;
      NSYSRESET      : in std_logic;
      PROT           : in std_logic_vector(1 downto 0);
      RV_TCK         : in std_logic;
      RV_TDI         : in std_logic;
      RV_TMS         : in std_logic;
      RV_nSRST_IN    : in std_logic;
      RV_nTRST       : in std_logic;
      SIZE           : in std_logic_vector(1 downto 0);
      SYSCLK         : in std_logic;
      TRANS          : in std_logic_vector(1 downto 0);
      UJTAG_TCK      : in std_logic;
      UJTAG_TDI      : in std_logic;
      UJTAG_TMS      : in std_logic;
      UJTAG_TRSTB    : in std_logic;
      WDATA          : in std_logic_vector(31 downto 0);
      WDOGRES        : in std_logic;
      WRITE          : in std_logic;
      nFIQ_in        : in std_logic;
      nIRQ_in        : in std_logic;
      ABORT          : out std_logic;
      CLK            : out std_logic;
      CLKEN          : out std_logic;
      DBGTCKEN       : out std_logic;
      DBGTDI         : out std_logic;
      DBGTMS         : out std_logic;
      DBGnTRST       : out std_logic;
      HADDR          : out std_logic_vector(31 downto 0);
      HBURST         : out std_logic_vector(2 downto 0);
      HBUSREQ        : out std_logic;
      HLOCK          : out std_logic;
      HPROT          : out std_logic_vector(3 downto 0);
      HRESETn        : out std_logic;
      HSIZE          : out std_logic_vector(2 downto 0);
      HTRANS         : out std_logic_vector(1 downto 0);
      HWDATA         : out std_logic_vector(31 downto 0);
      HWRITE         : out std_logic;
      RDATA          : out std_logic_vector(31 downto 0);
      RV_RTCK        : out std_logic;
      RV_TDOUT       : out std_logic;
      RV_nTDOEN      : out std_logic;
      UJTAG_TDO      : out std_logic;
      WDOGRESn       : out std_logic;
      nFIQ           : out std_logic;
      nIRQ           : out std_logic;
      nRESET         : out std_logic
      );
   end component;
  
begin
    
  --CoreMP7 instantiation 
   
  CoreMP7 : A7S
    port map (ABORT          => ABORT_s,
              CFGBIGEND      => CFGBIGEND,
              CLK            => CLK_s,
              CLKEN          => CLKEN_s,
              CPA            => CPA,
              CPB            => CPB,
              DBGBREAK       => DBGBREAK,
              DBGEN          => DBGEN,
              DBGEXT         => DBGEXT,
              DBGRQ          => DBGRQ,
              DBGTCKEN       => DBGTCKEN_s,
              DBGTDI         => DBGTDI_s,
              DBGTMS         => DBGTMS_s,
              DBGnTRST       => DBGnTRST_s,
              RDATA          => RDATA_s,
              nFIQ           => nFIQ_bridgeMP7_s,
              nIRQ           => nIRQ_bridgeMP7_s,
              nRESET         => nRESET_s,
              ADDR           => ADDR_s,
              CPSEQ          => CPSEQ,
              CPTBIT         => CPTBIT,
              CPnI           => CPnI,
              CPnMREQ        => CPnMREQ,
              CPnOPC         => CPnOPC,
              CPnTRANS       => CPnTRANS,
              DBGACK         => DBGACK,
              DBGCOMMRX      => DBGCOMMRX,
              DBGCOMMTX      => DBGCOMMTX,
              DBGINSTRVALID  => DBGINSTRVALID,
              DBGRNG         => DBGRNG,
              DBGTDO         => DBGTDO_s,
              DBGnEXEC       => DBGnEXEC,
              DBGnTDOEN      => DBGnTDOEN_s,
              DMORE          => DMORE,
              LOCK           => LOCK_s,
              PROT           => PROT_s,
              SIZE           => SIZE_s,
              TRANS          => TRANS_s,
              WDATA          => WDATA_s,
              WRITE          => WRITE_s);
  
  --Bridge instantiation    
  
  Bridge : CoreMP7Bridge
    generic map(DEBUG          => DEBUG,
                SYNCFIQ        => SYNCFIQ,
                SYNCIRQ        => SYNCIRQ
                )
    port map (ADDR           => ADDR_s,
              DBGTDO         => DBGTDO_s,
              DBGnTDOEN      => DBGnTDOEN_s,
              HGRANT         => HGRANT_s,
              HRDATA         => wrapper_ahb_outputs_s.HRDATA,
              HREADY         => wrapper_ahb_outputs_s.HREADY,
              HRESP          => wrapper_ahb_outputs_s.HRESP,
              LOCK           => LOCK_s,
              NSYSRESET      => rst,
              PROT           => PROT_s,
              RV_TCK         => ICE_TCK,
              RV_TDI         => ICE_TDI,
              RV_TMS         => ICE_TMS,
              RV_nSRST_IN    => ICE_nSRST,
              RV_nTRST       => ICE_nTRST,
              SIZE           => SIZE_s,
              SYSCLK         => clk,
              TRANS          => TRANS_s,
              UJTAG_TCK      => UJTAG_TCK,
              UJTAG_TDI      => UJTAG_TDI,
              UJTAG_TMS      => UJTAG_TMS,
              UJTAG_TRSTB    => UJTAG_TRSTB,
              WDATA          => WDATA_s,
              WDOGRES        => WDOGRES,
              WRITE          => WRITE_s,
              nFIQ_in        => nFIQ_wrapBridge_s,
              nIRQ_in        => nIRQ_wrapBridge_s,
              ABORT          => ABORT_s,
              CLK            => CLK_s,
              CLKEN          => CLKEN_s,
              DBGTCKEN       => DBGTCKEN_s,
              DBGTDI         => DBGTDI_s,
              DBGTMS         => DBGTMS_s,
              DBGnTRST       => DBGnTRST_s,
              HADDR          => wrapper_ahb_inputs_s.HADDR,
              HBURST         => wrapper_ahb_inputs_s.HBURST,
              HBUSREQ        => wrapper_ahb_inputs_s.HBUSREQ,
              HLOCK          => wrapper_ahb_inputs_s.HLOCK,
              HPROT          => wrapper_ahb_inputs_s.HPROT,
              HRESETn        => HRESETn_s,
              HSIZE          => wrapper_ahb_inputs_s.HSIZE,
              HTRANS         => wrapper_ahb_inputs_s.HTRANS,
              HWDATA         => wrapper_ahb_inputs_s.HWDATA,
              HWRITE         => wrapper_ahb_inputs_s.HWRITE,
              RDATA          => RDATA_s,
              RV_RTCK        => ICE_RTCK,
              RV_TDOUT       => ICE_TDOUT,
              RV_nTDOEN      => ICE_nTDOEN,
              UJTAG_TDO      => UJTAG_TDO,
              WDOGRESn       => WDOGRESn,
              nFIQ           => nFIQ_bridgeMP7_s,
              nIRQ           => nIRQ_bridgeMP7_s,
              nRESET         => nRESET_s);
  
      --Wrapper instantiation                                                                   
      Wrapper : cmp7wrap
        generic map(hindex     => hindex,
                    pindex     => pindex,
                    paddr      => paddr,
                    pmask      => pmask
                    )
        port map(rst        => rst,
                 clk        => clk,
                 ahbmi      => ahbmi,
                 ahbmo      => ahbmo,
                 apbi       => apbi,
                 apbo       => apbo,
                 irqi       => irqi,
                 irqo       => irqo,
                 nirq       => nIRQ_wrapBridge_s,
                 nfiq       => nFIQ_wrapBridge_s,
                 bigend     => CFGBIGEND,
                 -- From wrapper to MP7Bridge
                 HGRANT     => HGRANT_s,
                 HRDATA     => wrapper_ahb_outputs_s.HRDATA,
                 HREADY     => wrapper_ahb_outputs_s.HREADY,
                 HRESP      => wrapper_ahb_outputs_s.HRESP,
                 -- To wrapper from MP7Bridge
                 HADDR      => wrapper_ahb_inputs_s.HADDR,
                 HBURST     => wrapper_ahb_inputs_s.HBURST,
                 HBUSREQ    => wrapper_ahb_inputs_s.HBUSREQ,
                 HLOCK      => wrapper_ahb_inputs_s.HLOCK,
                 HPROT      => wrapper_ahb_inputs_s.HPROT,
                 HRESETn    => HRESETn_s,
                 HSIZE      => wrapper_ahb_inputs_s.HSIZE,
                 HTRANS     => wrapper_ahb_inputs_s.HTRANS,
                 HWDATA     => wrapper_ahb_inputs_s.HWDATA,
                 HWRITE     => wrapper_ahb_inputs_s.HWRITE);
end;
