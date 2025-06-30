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
-- Package:     plic
-- File:        plic.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
-- Description: RISC-V PLIC types and components
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;

package plic is

  ---------------------------------------------------
  -- GRPLIC Constants
  ---------------------------------------------------

  constant MAX_HARTS            : integer := 4096;
  constant RISCV_SOURCES        : integer := 1024;
  constant RISCV_CONTEXTS       : integer := 15872;
  
  ---------------------------------------------------
  -- Component Declaration
  ---------------------------------------------------

  component grplic 
    generic (
      pindex      : integer range 0 to NAPBSLV-1  := 0;
      paddr       : integer range 0 to 16#FFF#    := 0;
      pmask       : integer range 0 to 16#FFF#    := 16#FFF#;
      nsources    : integer range 0 to 32         := NAHBIRQ;
      ncpu        : integer range 0 to 4096       := 4;
      priorities  : integer range 0 to 32         := 8;
      pendingbuff : integer range 0 to 32         := 1;
      irqtype     : integer range 0 to 1          := 1;
      thrshld     : integer range 0 to 1          := 1
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      apbi        : in  apb_slv_in_type;
      apbo        : out apb_slv_out_type;
      irqo        : out std_logic_vector(ncpu*4-1 downto 0)
      );
  end component;

  component grplic_ahb
    generic (
      hindex      : integer range 0 to NAPBSLV-1      := 0;
      haddr       : integer range 0 to 16#FFF#        := 0;
      hmask       : integer range 0 to 16#FFC#        := 16#FFC#;
      nsources    : integer range 0 to RISCV_SOURCES  := NAHBIRQ;
      ncpu        : integer range 0 to 4096           := 4;
      priorities  : integer range 0 to 128            := 8;
      pendingbuff : integer range 0 to 128            := 1;
      irqtype     : integer range 0 to 1              := 1;
      thrshld     : integer range 0 to 1              := 1
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      ahbi        : in  ahb_slv_in_type;
      ahbo        : out ahb_slv_out_type;
      irqo        : out std_logic_vector(ncpu*4-1 downto 0)
      );
  end component;

  component plic_gateway
    generic (
      pendingbuff       : integer range 0 to 32 := 8;
      irqtype           : integer range 0 to 1 := 0
      );
    port (
      rst       : in  std_ulogic;
      clk       : in  std_ulogic;
      irqi      : in  std_ulogic;
      ip        : out std_ulogic;
      complete  : in  std_ulogic;
      claim     : in  std_ulogic
      );
  end component;

  component plic_encoder
      generic (
        nsources        : integer := 32;
        ntargets        : integer := 4;
        srcbits         : integer := 6;
        prbits          : integer := 4
        );
      port (
        ip      : in  std_logic_vector(nsources-1 downto 0);
        pr_in   : in  std_logic_vector((prbits*nsources)-1 downto 0);
        enable  : in  std_logic_vector(nsources-1 downto 0);
        id      : out std_logic_vector(srcbits-1 downto 0);
        pr_out  : out std_logic_vector(prbits-1 downto 0)
        );
  end component;

  component plic_target
    generic (
      prbits          : integer := 3;
      srcbits         : integer := 4
      );
    port (
      prio      : in  std_logic_vector(prbits-1 downto 0);
      threshold : in  std_logic_vector(prbits-1 downto 0);
      irqreq    : out std_ulogic
      );
  end component;

end package;
