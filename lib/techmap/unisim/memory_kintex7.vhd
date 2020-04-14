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
-- Entity:      various
-- File:        kintex7_unisim.vhd
-- Author:      Jiri Gaisler - Cobham Gaisler
-- Description: Memory generators for Xilinx Kintex7 RAMs
------------------------------------------------------------------------------
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
-- Entity:      various
-- File:        kintex7_unisim.vhd
-- Author:      Jiri Gaisler - Cobham Gaisler
-- Description: Memory generators for Xilinx Kintex7 RAMs
------------------------------------------------------------------------------
LIBRARY ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.conv_integer;
use ieee.numeric_std.all;

entity kintex7_syncram_dp is
  generic (
    abits : integer := 4; dbits : integer := 32
  );
  port (
    clk1     : in std_ulogic;
    address1 : in std_logic_vector((abits -1) downto 0);
    datain1  : in std_logic_vector((dbits -1) downto 0);
    dataout1 : out std_logic_vector((dbits -1) downto 0);
    enable1  : in std_ulogic;
    write1   : in std_ulogic;
    clk2     : in std_ulogic;
    address2 : in std_logic_vector((abits -1) downto 0);
    datain2  : in std_logic_vector((dbits -1) downto 0);
    dataout2 : out std_logic_vector((dbits -1) downto 0);
    enable2  : in std_ulogic;
    write2   : in std_ulogic);
end;

architecture behav of kintex7_syncram_dp is
    type ram_type is array ((2**abits - 1) downto 0) of std_logic_vector((dbits -1) downto 0);
    shared variable RAM : ram_type;

begin
  process(clk1)
  begin
   if rising_edge(clk1) then
    if enable1 = '1' then
        dataout1 <= RAM(to_integer(unsigned(address1)));
       if write1 = '1' then
        RAM(to_integer(unsigned(address1))) := datain1;
       end if;
      end if;
     end if;
   end process;
  
   process(clk2)
    begin
     if rising_edge(clk2) then
      if enable2 = '1' then
        dataout2 <= RAM(to_integer(unsigned(address2)));
       if write2 = '1' then
        RAM(to_integer(unsigned(address2))) := datain2;
       end if;
      end if;
     end if;
   end process;
end;


LIBRARY ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.conv_integer;
use ieee.numeric_std.all;

entity kintex7_syncram_2p is
    generic (
      abits : integer := 4; dbits : integer := 32; sepclk : integer := 0
    );
    port (
      clk1     : in std_ulogic;
      address1 : in std_logic_vector((abits -1) downto 0);
      datain1  : in std_logic_vector((dbits -1) downto 0);
      enable1  : in std_ulogic;
      write1   : in std_ulogic;
      clk2     : in std_ulogic;
      address2 : in std_logic_vector((abits -1) downto 0);
      dataout2 : out std_logic_vector((dbits -1) downto 0);
      enable2  : in std_ulogic);
  end;
  
  architecture behav of kintex7_syncram_2p is
      type ram_type is array ((2**abits - 1) downto 0) of std_logic_vector((dbits -1) downto 0);
      shared variable RAM : ram_type;
  
  begin
    process(clk1)
    begin
     if rising_edge(clk1) then
      if enable1 = '1' then
         if write1 = '1' then
          RAM(to_integer(unsigned(address1))) := datain1;
         end if;
        end if;
       end if;
     end process;
    
     k7sep : if (sepclk = 1) generate
       process(clk2)
        begin
         if rising_edge(clk2) then
          if enable2 = '1' then
            dataout2 <= RAM(to_integer(unsigned(address2)));
          end if;
         end if;
       end process;
     end generate;

     k7nosep : if (sepclk = 0) generate
       process(clk1)
        begin
         if rising_edge(clk1) then
          if enable2 = '1' then
            dataout2 <= RAM(to_integer(unsigned(address2)));
          end if;
         end if;
       end process;
     end generate;

  end;

  LIBRARY ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.conv_integer;
use ieee.numeric_std.all;

entity kintex7_syncram is
    generic (
      abits : integer := 4; dbits : integer := 32
    );
    port (
      clk     : in std_ulogic;
      address : in std_logic_vector((abits -1) downto 0);
      datain  : in std_logic_vector((dbits -1) downto 0);
      enable  : in std_ulogic;
      write   : in std_ulogic;
      dataout : out std_logic_vector((dbits -1) downto 0));
  end;
  
  architecture behav of kintex7_syncram is
      type ram_type is array ((2**abits - 1) downto 0) of std_logic_vector((dbits -1) downto 0);
      shared variable RAM : ram_type;
  
  begin
    process(clk)
    begin
     if rising_edge(clk) then
      if enable = '1' then
         if write = '1' then
          RAM(to_integer(unsigned(address))) := datain;
         else
          dataout <= RAM(to_integer(unsigned(address)));
         end if;
        end if;
       end if;
     end process;

  end;