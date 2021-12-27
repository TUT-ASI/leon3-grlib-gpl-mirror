------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
-- Package:     leon5
-- File:        leon5.vhd
-- Description: Public components and types for LEON5
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.config.all;
use grlib.config_types.all;
library gaisler;
use gaisler.uart.all;
library techmap;
use techmap.gencomp.all;

package leon5 is


  type ahb_config_array is array(NAHBSLV-1 downto 0) of ahb_config_type;

  component leon5sys is
    generic (
      fabtech  : integer;
      memtech  : integer;
      ncpu     : integer;
      nextmst  : integer;
      nextslv  : integer;
      nextapb  : integer;
      ndbgmst  : integer;
      cached   : integer;
      wbmask   : integer;
      busw     : integer;
      memmap   : integer := 0;
      ahbsplit : integer := 0;
      cmemconf : integer := 0;
      rfconf   : integer := 0;
      fpuconf  : integer;
      tcmconf  : integer := 0;
      perfcfg  : integer := 0;
      mulimpl  : integer := 0;
      statcfg  : integer := 0;
      disas    : integer;
      ahbtrace : integer;
      devid    : integer := 0;
      cgen     : integer := 0;
      scantest : integer := 0
      );
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      -- Clock gating support (used only if cgen generic is set)
      gclk     : in  std_logic_vector(0 to ncpu-1) := (others => '0');
      gclken   : out std_logic_vector(0 to ncpu-1);
      -- AHB bus interface for other masters (DMA units)
      ahbmi    : out ahb_mst_in_type;
      ahbmo    : in  ahb_mst_out_vector_type(ncpu+nextmst-1 downto ncpu);
      -- AHB bus interface for slaves (memory controllers, etc)
      ahbsi    : out ahb_slv_in_type;
      ahbso    : in  ahb_slv_out_vector_type(nextslv-1 downto 0);
      ahbpnp   : out ahb_config_array;
      -- AHB master interface for debug links
      dbgmi    : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
      dbgmo    : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
      -- APB interface for external APB slaves
      apbi     : out apb_slv_in_type;
      apbo     : in  apb_slv_out_vector;
      -- Bootstrap signals
      dsuen    : in  std_ulogic;
      dsubreak : in  std_ulogic;
      cpu0errn : out std_ulogic;
      -- UART connection
      uarti    : in  uart_in_type;
      uarto    : out uart_out_type;
      testen   : in  std_ulogic := '0';
      testrst  : in  std_ulogic := '1';
      scanen   : in  std_ulogic := '0';
      testoen  : in  std_ulogic := '1';
      testsig  : in  std_logic_vector(1+GRLIB_CONFIG_ARRAY(grlib_techmap_testin_extra) downto 0) := (others => '0')
      );
  end component;

end package;
