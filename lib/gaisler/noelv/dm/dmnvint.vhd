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
-- Package:     dmnvint
-- File:        dmnvint.vhd
-- Description: Internal components and types for NOEL-V debug module
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.config.all;
use grlib.config_types.all;
use grlib.stdlib.all;

package dmnvint is

  -- Program buffer --------------------------------------------------------------
  type nv_progbuf_in_type is record
    addr      : std_logic_vector(4 downto 0);
    eaddr     : std_logic_vector(4 downto 0);
    write     : std_logic;
    data      : std_logic_vector(31 downto 0);
  end record;
  constant nv_progbuf_in_none : nv_progbuf_in_type := (
    addr      => (others => '0'),
    eaddr     => (others => '0'),
    write     => '0',
    data      => (others => '0')
  );

  type nv_progbuf_out_type is record
    edata      : std_logic_vector(63 downto 0);
    data       : std_logic_vector(31 downto 0);
  end record;
  constant nv_progbuf_out_none : nv_progbuf_out_type := (
    edata     => (others => '0'),
    data      => (others => '0')
  );

  -- AMBA trace-buffer -----------------------------------------------------------
  type nv_progbuf_in_vector  is array (natural range <>) of nv_progbuf_in_type;
  type nv_progbuf_out_vector is array (natural range <>) of nv_progbuf_out_type;

  -----------------------------------------------------------------------------
  -- Components
  -----------------------------------------------------------------------------
  component progbuf
    generic (
      size : integer range 0 to 16
    );
    port (
      clk   : in  std_ulogic;
      rstn  : in  std_ulogic;
      pbi   : in  nv_progbuf_in_type;
      pbo   : out nv_progbuf_out_type
    );
  end component;

end package;

package body dmnvint is

end package body;

