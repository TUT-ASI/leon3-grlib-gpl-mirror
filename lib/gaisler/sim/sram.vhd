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
-- Entity: 	sram
-- File:	sram.vhd
-- Author:	Jiri Gaisler Gaisler Research
-- Description:	Simulation model of generic async SRAM
------------------------------------------------------------------------------

-- pragma translate_off

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

library grlib;
use grlib.stdlib.all;
use grlib.stdio.all;

entity sram is
  generic (
    index : integer := 0;		-- Byte lane (0 - 3)
    abits: Positive := 10;		-- Default 10 address bits (1 Kbyte)
    tacc : integer := 10;		-- access time (ns)
    fname : string := "ram.dat";	-- File to read from
    clear : integer := 0);	-- Clear memory
  port (  
    a : in std_logic_vector(abits-1 downto 0);
    d : inout std_logic_vector(7 downto 0);
    ce1 : in std_logic;
    we : in std_ulogic;
    oe : in std_ulogic);
end;     


architecture sim of sram is

  subtype BYTE is std_logic_vector(7 downto 0);
  type MEM is array(0 to ((2**Abits)-1)) of BYTE;
  signal DINT,DI,DO : BYTE;

  constant ahigh : integer := abits - 1;
  signal wrpre : std_ulogic;

  function Vpar(vec : std_logic_vector) return std_ulogic is
  variable par : std_ulogic := '1';
  begin
    for i in vec'range loop	--'
      par := par xor vec(i);
    end loop;
    return par;
  end;

begin

  RAM : process(CE1,WE,DI,A,OE,D)
  variable MEMA : MEM;
  variable L1 : line;
  variable FIRST : boolean := true;
  variable ADR : std_logic_vector(19 downto 0);
  variable BUF : std_logic_vector(31 downto 0);
  variable CH : character;
  variable ai : integer := 0;
  variable len : integer := 0;
  file TCF : text open read_mode is fname;
  variable rectype : std_logic_vector(3 downto 0);
  variable recaddr : std_logic_vector(31 downto 0);
  variable reclen  : std_logic_vector(7 downto 0);
  variable recdata : std_logic_vector(0 to 16*8-1);

  begin
    if FIRST then

      if clear = 1 then MEMA := (others => X"00"); end if;
      L1:= new string'("");	--'
      while not endfile(TCF) loop
        readline(TCF,L1);
        if (L1'length /= 0) then	--'
          while (not (L1'length=0)) and (L1(L1'left) = ' ') loop
            std.textio.read(L1,CH);
          end loop;

          if L1'length > 0 then	--'
            read(L1, ch);
            if (ch = 'S') or (ch = 's') then
              hread(L1, rectype);
              hread(L1, reclen);
	      len := conv_integer(reclen)-1;
	      recaddr := (others => '0');
	      case rectype is 
		when "0001" =>
                  hread(L1, recaddr(15 downto 0));
                  len := len - 2;
		when "0010" =>
                  hread(L1, recaddr(23 downto 0));
                  len := len - 3;
		when "0011" =>
                  hread(L1, recaddr);
                  len := len - 4;
		when others => next;
	      end case;
              if L1.all'length*4 < recdata'length then
                hread(L1, recdata(0 to L1.all'length*4-1));
              else
                hread(L1, recdata);
              end if;
              if index = 6 then
	        recaddr(31 downto abits) := (others => '0');
	        ai := conv_integer(recaddr);
 	        for i in 0 to 15 loop
                  MEMA(ai+i) := recdata((i*8) to (i*8+7));
	        end loop;
              elsif (index = 4) or (index = 5) then
	        recaddr(31 downto abits+1) := (others => '0');
	        ai := conv_integer(recaddr)/2;
 	        for i in 0 to 7 loop
                  MEMA(ai+i) := recdata((i*16+(index-4)*8) to (i*16+(index-4)*8+7));
	        end loop;
              else 
	        recaddr(31 downto abits+2) := (others => '0');
	        ai := conv_integer(recaddr)/4;
 	        for i in 0 to 3 loop
                  MEMA(ai+i) := recdata((i*32+index*8) to (i*32+index*8+7));
	        end loop;
              end if;
	      if ai = 0 then
		ai := 1;
	      end if;
            end if;
          end if;
        end if;
      end loop;

      FIRST := false;

    else
      if (TO_X01(not CE1) = '1') then
        if not is_x(a) then ai := conv_integer(A(abits-1 downto 0)); else ai := 0; end if;
        dint <= mema(ai);
      end if;
      if (TO_X01(CE1 or WE) = '1') then
        if wrpre = '1' then
          mema(ai) := to_x01(std_logic_vector(DI));
        end if;
      end if;
    end if;
    wrpre <= TO_X01((not CE1) and (not WE));
    DI <= D;
  end process;
 
  BUFS : process(CE1,WE,DINT,OE)
  variable DRIVEB : std_logic;
  begin
    DRIVEB := TO_X01((not CE1) and (not OE) and WE);
    case DRIVEB is
      when '1' => D <= DINT after tacc * 1 ns;
      when '0' => D <= "ZZZZZZZZ" after 8 ns;
      when others => D <= "XXXXXXXX";
    end case;
  end process;

end sim;
-- pragma translate_on

