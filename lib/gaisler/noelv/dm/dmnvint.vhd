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

  ----------------------------------------------------------------------------
  -- Types and constants
  ----------------------------------------------------------------------------
  constant REGW : integer := 32;

  type dev_reg_in_type is record
    sel     : std_logic_vector(3 downto 0);
    addr    : std_logic_vector(31 downto 0);
    data    : std_logic_vector(REGW-1 downto 0);
    wr      : std_ulogic;
    -- System Bus Access
    sbfinish : std_ulogic;
    sbrdata  : std_logic_vector(31 downto 0);
    sbdvalid : std_ulogic;
    sberror  : std_ulogic;
    -- Test support
    testen  : std_ulogic;
    testrst : std_ulogic;
  end record;
  constant dev_reg_in_none : dev_reg_in_type := (
    sel      => (others => '0'),
    addr     => (others => '0'),
    data     => (others => '0'),
    wr       => '0',
    sbfinish => '0',
    sbrdata  => (others => '0'),   
    sbdvalid => '0',
    sberror  => '0',
    testen   => '0',
    testrst  => '0');
  type dev_reg_out_type is record
    rdy   : std_ulogic;
    data  : std_logic_vector(REGW-1 downto 0);
    -- System Bus Access
    sbstart  : std_ulogic;
    sbwdata  : std_logic_vector(31 downto 0);
    sbwr     : std_ulogic;
    sbaccess : std_logic_vector(2 downto 0);
    sbaddr   : std_logic_vector(31 downto 0);
  end record;
  constant dev_reg_out_none : dev_reg_out_type := (
    rdy   => '0',
    data  => (others => '0'),
    sbstart  => '0',
    sbwdata  => (others => '0'),
    sbwr     => '0',
    sbaccess => (others => '0'),
    sbaddr   => (others => '0')
    );

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
  type tracebuf_mbus_in_type is record
    addr             : std_logic_vector(11 downto 0);
    data             : std_logic_vector(223 downto 0);
    enable           : std_logic;
    write            : std_logic_vector(6 downto 0);
  end record;
  type tracebuf_mbus_out_type is record
    data             : std_logic_vector(223 downto 0);
  end record;
  type tracebuf_mbus_in_array is array(0 to 4) of tracebuf_mbus_in_type;
  type tracebuf_mbus_out_array is array(0 to 4) of tracebuf_mbus_out_type; 
  constant tracebuf_mbus_in_type_none : tracebuf_mbus_in_type := (
    addr    => (others => '0'),
    data    => (others => '0'),
    enable  => '0',
    write   => (others => '0')
    );
  constant tracebuf_mbus_out_type_none : tracebuf_mbus_out_type :=
    (data => (others => '0'));

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

