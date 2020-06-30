------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-- Package:     riscv
-- File:        riscv.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
-- Description: RISC-V Types and Components
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library gaisler;
use gaisler.noelv.all;

library grlib;
use grlib.amba.all;

package riscv is

  ---------------------------------------------------
  -- Component declaration
  ---------------------------------------------------

  component clint is
    generic (
      pindex      : integer range 0 to NAPBSLV-1  := 0;
      paddr       : integer range 0 to 16#FFF#    := 0;
      pmask       : integer range 0 to 16#FFF#    := 16#FFF#;
      ncpu        : integer range 0 to 4096       := 4
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      rtc         : in  std_ulogic;
      apbi        : in  apb_slv_in_type;
      apbo        : out apb_slv_out_type;
      halt        : in  std_ulogic;
      irqi        : in  std_logic_vector(ncpu*4-1 downto 0);
      irqo        : out nv_irq_in_vector(0 to ncpu-1)
      );
  end component;

  component clint_ahb is
    generic (
      hindex      : integer range 0 to NAPBSLV-1  := 0;
      haddr       : integer range 0 to 16#FFF#    := 0;
      hmask       : integer range 0 to 16#FFF#    := 16#FFF#;
      ncpu        : integer range 0 to 4096       := 4
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      rtc         : in  std_ulogic;
      ahbi        : in  ahb_slv_in_type;
      ahbo        : out ahb_slv_out_type;
      halt        : in  std_ulogic;
      irqi        : in  std_logic_vector(ncpu*4-1 downto 0);
      irqo        : out nv_irq_in_vector(0 to ncpu-1)
      );
  end component;

end package;
