------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
-- Entity: 	mul_61x61
-- File:	mul_61x61.vhd
-- Author:	Edvin Catovic - Gaisler Research
-- Description:	61x61 multiplier
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity mul_61x61 is
  generic (multech : integer := 0;
           fabtech : integer := 0);
    port(NA      : in std_logic_vector(60 downto 0);
         NB      : in std_logic_vector(60 downto 0);
         EN      : in std_logic;
         CLK     : in std_logic;
         PRODUCT : out std_logic_vector(121 downto 0));
end;


architecture rtl of mul_61x61 is

component dw_mul_61x61 is
    port(A       : in std_logic_vector(60 downto 0);
         B       : in std_logic_vector(60 downto 0);
         CLK     : in std_logic;
         PRODUCT : out std_logic_vector(121 downto 0));
end component;

component gen_mul_61x61 is
    port(NA      : in std_logic_vector(60 downto 0);
         NB      : in std_logic_vector(60 downto 0);
         EN      : in std_logic;
         CLK     : in std_logic;
         PRODUCT : out std_logic_vector(121 downto 0));
end component;

component axcel_mul_61x61 is
    port(A       : in std_logic_vector(60 downto 0);
         B       : in std_logic_vector(60 downto 0);
         EN      : in std_logic;
         CLK     : in std_logic;
         PRODUCT : out std_logic_vector(121 downto 0));
end component;

component virtex4_mul_61x61
port(
  A : in std_logic_vector(60 downto 0);
  B : in std_logic_vector(60 downto 0);
  EN :  in std_logic;
  CLK :  in std_logic;
  PRODUCT : out std_logic_vector(121 downto 0));
end component;

component virtex6_mul_61x61
port(
  A : in std_logic_vector(60 downto 0);
  B : in std_logic_vector(60 downto 0);
  EN :  in std_logic;
  CLK :  in std_logic;
  PRODUCT : out std_logic_vector(121 downto 0));
end component;

component virtex7_mul_61x61
port(
  A : in std_logic_vector(60 downto 0);
  B : in std_logic_vector(60 downto 0);
  EN :  in std_logic;
  CLK :  in std_logic;
  PRODUCT : out std_logic_vector(121 downto 0));
end component;

component kintex7_mul_61x61
port(
  A : in std_logic_vector(60 downto 0);
  B : in std_logic_vector(60 downto 0);
  EN :  in std_logic;
  CLK :  in std_logic;
  PRODUCT : out std_logic_vector(121 downto 0));
end component;

component kintexu_mul_61x61
port(
  A : in std_logic_vector(60 downto 0);
  B : in std_logic_vector(60 downto 0);
  EN :  in std_logic;
  CLK :  in std_logic;
  PRODUCT : out std_logic_vector(121 downto 0));
end component;

component virtexup_mul_61x61
port(
  A : in std_logic_vector(60 downto 0);
  B : in std_logic_vector(60 downto 0);
  EN :  in std_logic;
  CLK :  in std_logic;
  PRODUCT : out std_logic_vector(121 downto 0));
end component;


signal A, B: std_logic_vector(60 downto 0);

constant use_gen_mul: boolean := (multech=0 or
                                  (multech=3 and fabtech/=axdsp and
                                   fabtech/=virtex5 and fabtech/=virtex6));
begin

  gen0 : if use_gen_mul generate
    mul0 : gen_mul_61x61 port map (NA, NB, EN, CLK, PRODUCT);
    A <= (others => '0');
    B <= (others => '0');
  end generate;

  preg: if not use_gen_mul generate
    p: process(CLK)
    begin
      if rising_edge(CLK) then
        A <= NA;
        B <= NB;
      end if;
    end process;
  end generate;

  dw0 : if multech = 1 generate
    mul0 : dw_mul_61x61 port map (A, B, CLK, PRODUCT);
  end generate;

  tech0 : if multech = 3 generate
    axd0 : if fabtech = axdsp generate
      mul0 : axcel_mul_61x61 port map (A, B, EN, CLK, PRODUCT);
    end generate;
    xc5v : if fabtech = virtex5 generate
      mul0 : virtex4_mul_61x61 port map (A, B, EN, CLK, PRODUCT);
    end generate;
    xc6v : if fabtech = virtex6 generate
      mul0 : virtex6_mul_61x61 port map (A, B, EN, CLK, PRODUCT);
    end generate;
  end generate;

end;

