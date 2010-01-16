------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2010, Aeroflex Gaisler
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
--============================================================================--
-- Design unit  : spacewire_testpackage (Package and body declarations)
--
-- File name    : apbuart_tp.vhd
--
-- Purpose      : Procedures for APBUART testbench
--
-- Library      : {independent}
--
-- Authors      : Marko Isomaki
--
-- Contact      : mailto:marko@gaisler.com
--                http://www.gaisler.com
--
-- Disclaimer   : All information is provided "as is", there is no warranty that
--                the information is correct or suitable for any purpose,
--                neither implicit nor explicit.
--
--------------------------------------------------------------------------------
-- Version  Author   Date           Changes
-- 0.1      MI       21 Okt 2009    New package
--------------------------------------------------------------------------------
library  IEEE;
use      IEEE.Std_Logic_1164.all;
library  gaisler;
use      gaisler.uart.all;

package apbuart_testpackage is
  type uart_dbg_in_type is record
    baudrate   : integer; 
    readchar   : std_ulogic;
    paren      : std_ulogic;
    parsel     : std_ulogic;
    rdfifo     : std_ulogic;
    rxen       : std_ulogic;
    wrfifo     : std_ulogic;
    txchar     : std_logic_vector(7 downto 0);
    sndbreak   : std_ulogic;
  end record;

  type uart_dbg_out_type is record
    dataav     : std_ulogic;
    rxchar     : std_logic_vector(7 downto 0);
    rdack      : std_ulogic;
    parerr     : std_ulogic;
    stopbiterr : std_ulogic;
    txfifoerr  : std_ulogic;
    rxfifoerr  : std_ulogic;
    gotchar    : std_ulogic;
    wrack      : std_ulogic;
    txdone     : std_ulogic;
    breakack   : std_ulogic;
  end record;

  component simuart is
  port(
    dbgi  : in  uart_dbg_in_type;
    dbgo  : out uart_dbg_out_type;
    uarti : in  uart_in_type;
    uarto : out uart_out_type);
  end component;
end package apbuart_testpackage;


