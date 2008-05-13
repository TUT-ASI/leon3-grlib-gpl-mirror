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
-- Package:     grusbhc_pkg
-- File:        grusbhc_pkg.vhd
-- Author:      Jan Andersson, Jonas Ekergarn
-- Description: Package for GRUSBHC, the GRLIB wrapper for USBHC
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;

package grusbhc_pkg is

  constant UHC_REVISION   : amba_version_type := 0;
  constant EHC_REVISION   : amba_version_type := 0;
  
  -------------------------------------------------------------------------------
  -- IN and OUT signals from host controller top-level
  -------------------------------------------------------------------------------
  type usbhc_out_type is record
       -- UTMI+ signals
       xcvrsel  : std_logic_vector(1 downto 0);
       termsel  : std_ulogic;
       suspendm : std_ulogic;
       opmode   : std_logic_vector(1 downto 0);
       txvalid  : std_ulogic;
       drvvbus  : std_ulogic;
       dataho   : std_logic_vector(7 downto 0);
       validho  : std_ulogic;
       host     : std_ulogic;
       -- ULPI signals
       stp      : std_ulogic;
       -- Shared signals
       datao    : std_logic_vector(7 downto 0);
       utm_rst  : std_ulogic;
       dctrl    : std_ulogic;
  end record;
  type usbhc_out_vector is array (natural range <>) of usbhc_out_type;
  
  type usbhc_in_type is record
       -- UTMI+ signals
       linestate : std_logic_vector(1 downto 0);
       txready   : std_ulogic;
       rxvalid   : std_ulogic;
       rxactive  : std_ulogic;
       rxerror   : std_ulogic;
       vbusvalid : std_ulogic;
       datahi    : std_logic_vector(7 downto 0);
       validhi   : std_ulogic;
       hostdisc  : std_ulogic;
       -- ULPI signals
       nxt       : std_ulogic;
       dir       : std_ulogic;
       -- Shared signals
       datai     : std_logic_vector(7 downto 0);
  end record;
  type usbhc_in_vector is array (natural range <>) of usbhc_in_type;
  
  -- Complete controller
  component grusbhc is
    generic (
      ehchindex   : integer range 0 to NAHBMST-1 := 0;
      ehcpindex   : integer range 0 to NAPBSLV-1 := 0;
      ehcpaddr    : integer range 0 to 16#FFF# := 0;
      ehcpirq     : integer range 0 to NAHBIRQ-1 := 0;
      ehcpmask    : integer range 0 to 16#FFF# := 16#FFF#;
      uhchindex   : integer range 0 to NAHBMST-1 := 0;
      uhchsindex  : integer range 0 to NAHBSLV-1 := 0;
      uhchaddr    : integer range 0 to 16#FFF# := 0;
      uhchmask    : integer range 0 to 16#FFF# := 16#FFF#;
      uhchirq     : integer range 0 to NAHBIRQ-1 := 0;
      tech        : integer range 0 to NTECH := DEFFABTECH;
      memtech     : integer range 0 to NTECH := DEFMEMTECH;
      nports      : integer range 1 to 15 := 1;
      ehcgen      : integer range 0 to 1 := 1;
      uhcgen      : integer range 0 to 1 := 1;
      n_cc        : integer range 1 to 15 := 1;
      n_pcc       : integer range 1 to 15 := 1;
      prr         : integer range 0 to 1 := 0;
      portroute1  : integer := 0;
      portroute2  : integer := 0;
      endian_conv : integer range 0 to 1 := 1;
      be_regs     : integer range 0 to 1 := 0;
      be_desc     : integer range 0 to 1 := 0;
      uhcblo      : integer range 0 to 255 := 2;
      bwrd        : integer range 1 to 256 := 16;
      utm_type    : integer range 0 to 2 := 2;
      vbusconf    : integer := 0;
      netlist     : integer range 0 to 1 := 0;
      ramtest     : integer range 0 to 1 := 0;
      urst_time   : integer := 250;
      oepol       : integer range 0 to 1 := 0;
      scantest    : integer := 0);
    port (
      clk       : in std_ulogic;
      uclk      : in std_ulogic;
      rst       : in std_ulogic;
      ursti     : in std_ulogic;
      -- APB signals
      apbi      : in apb_slv_in_type;
      ehc_apbo  : out apb_slv_out_type;
      -- AHB signals
      ahbmi     : in ahb_mst_in_type;
      ahbsi     : in ahb_slv_in_type;
      ehc_ahbmo : out ahb_mst_out_type;
      uhc_ahbmo : out ahb_mst_out_vector_type(n_cc*uhcgen downto 1*uhcgen);
      uhc_ahbso : out ahb_slv_out_vector_type(n_cc*uhcgen downto 1*uhcgen);
      -- Signals to USB transceiver
      o         : out usbhc_out_vector((nports-1) downto 0);
      -- Signals from USB transceiver
      i         : in usbhc_in_vector((nports-1) downto 0));               
  end component;

  function uhc_mask_check (
    ramtest : integer range 0 to 1;
    mask    : integer)
    return boolean;

  function ehc_mask_check (
    ramtest : integer range 0 to 1;
    mask    : integer)
    return boolean;
  
end grusbhc_pkg;

package body grusbhc_pkg is
  
  -----------------------------------------------------------------------------
  -- Description: Returns true if the register area is large enough to
  -- accommodate UHC registers
  -----------------------------------------------------------------------------
  function uhc_mask_check (
    ramtest : integer range 0 to 1;
    mask    : integer)
    return boolean is
    variable vmask : std_logic_vector(11 downto 0);
  begin  -- uhc_mask_check
    vmask := conv_std_logic_vector(mask,12);
    -- If ramtest is not enabled the smallest possible area is enough,
    -- otherwise the controller needs 2 kiB:
    return (ramtest = 1 and vmask(2 downto 0) = "000") or ramtest = 0;    
  end uhc_mask_check;
  
  -----------------------------------------------------------------------------
  -- Description: Returns true if the register area is large enough to
  -- accomodate EHC registers
  -----------------------------------------------------------------------------
  function ehc_mask_check (
    ramtest : integer range 0 to 1;
    mask    : integer)
    return boolean is
    variable vmask : std_logic_vector(11 downto 0);
  begin  -- ehc_mask_check
    vmask := conv_std_logic_vector(mask,12);
    -- If ramtest is not enabled the smallest possible area is enough,
    -- otherwise the controller needs 8 kiB:
    return (ramtest = 1 and vmask(4 downto 0) = "00000") or ramtest = 0;    
  end ehc_mask_check;
  
end grusbhc_pkg;
