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
-- Entity:      tcmwrap5
-- File:        tcmwrap5.vhd
-- Author:      Magnus Hjorth - Frontgrade Gaisler
-- Description: Wrapper around syncram to provide support for non power-of-two
--              sizes (for use in LEON5 TCM)
------------------------------------------------------------------------------

-- afrac encodes the desired size between 2^(abits-1) and 2^(abits), in steps
-- of (2^abits)/16. afrac=0 is a special case giving a depts of 2^abits
-- (as for standard syncram). Other values of afrac gives a depth
-- of (2^abits)*((8+afrac)/16)
--
-- The wrapper will puzzle together the desired size with the smallest number
-- of syncrams possible for that size. Worst case is afrac=7 where 4 memories
-- are needed (abits-1, abits-2, abits-3, abits-4)
--
--  Example for abits=10:
--    afrac=0 --> 2^10 = 1024
--    afrac=1 --> 2^10*(9/16) = 576  (512+64)
--    afrac=2 --> 2^10*(10/16) = 640 (512+128)
--    afrac=3 --> 2^10*(11/16) = 704 (512+128+64)
--    afrac=4 --> 2^10*(12/16) = 768 (512+256)
--    afrac=5 --> 2^10*(13/16) = 832 (512+256+64)
--    afrac=6 --> 2^10*(14/16) = 896 (512+256+128)
--    afrac=7 --> 2^10*(15/16) = 960 (512+256+128+64)
--

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity tcmwrap5 is
  generic (
    tech : integer;
    abits : integer;
    afrac : integer range 0 to 7;
    dbits : integer;
    bw : integer;
    dloopen : integer;
    testen : integer;
    mtwidth : integer;
    rdenall : integer
    );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    addressw : in std_logic_vector((abits -1) downto 0);
    datainh  : in std_logic_vector((dbits -1) downto 0);
    datainl  : in std_logic_vector((dbits -1) downto 0);
    dataouth : out std_logic_vector((dbits -1) downto 0);
    dataoutl : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    writeh   : in std_ulogic;
    writel   : in std_ulogic;
    writebw  : in std_logic_vector(7 downto 0);
    dataloop : in std_logic_vector(7 downto 0);
    oor      : out std_ulogic;
    testin   : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
    );
end;

architecture rtl of tcmwrap5 is

  -- Number of RAMs needed to implement memory size depends on the number of
  -- bits that are 1 in afrac(when viewed as binary number)
  type afrac_table_type is array(0 to 7) of integer;
  constant nramtab : afrac_table_type :=
    (0 => 1, 1 => 2, 2 => 2, 3 => 3,
     4 => 2, 5 => 3, 6 => 3, 7 => 4);
  -- Size of each of the implemented rams, (note only array indices up to
  -- nrams hold valid values)
  constant asize1tab : afrac_table_type := (0 => abits, others => abits-1);
  constant asize2tab : afrac_table_type := (1 => abits-4, 2 => abits-3, 3 => abits-3,
                                         others => abits-2);
  constant asize3tab : afrac_table_type := (3 => abits-4, 5 => abits-4, others => abits-3);
  constant asize4tab : afrac_table_type := (others => abits-4);
  constant nrams : integer := nramtab(afrac);
  constant asize1 : integer := asize1tab(afrac);
  constant asize2 : integer := asize2tab(afrac);
  constant asize3 : integer := asize3tab(afrac);
  constant asize4 : integer := asize4tab(afrac);
  type asize_array_type is array(1 to 4) of integer;
  constant asize : asize_array_type := (asize1, asize2, asize3, asize4);

  constant ramtype : integer :=
    dloopen*1 + bw*2;

  signal enabledec, penabledec: std_logic_vector(1 to nrams);

  type ram_output_type is record
    dataout: std_logic_vector((dbits-1) downto 0);
  end record;
  type ram_output_array is array(1 to nrams) of ram_output_type;

  signal ramouth, ramoutl: ram_output_array;

  signal dloopb: std_logic_vector(2*dbits-1 downto 0);

begin

  dloopbgen: for x in 0 to 2*dbits-1 generate
    dloopb(x) <= dataloop((x/8) mod 8);
  end generate;

  decproc: process(enable, address)
    variable o: std_logic_vector(1 to nrams);
    variable ax: std_logic_vector(abits-1 downto abits-4);
  begin
    o := (others => '0');
    ax := (others => '0');
    if afrac /= 0 then
      for r in 1 to nrams loop
        if address(abits-1 downto asize(r))=ax(abits-1 downto asize(r)) then
          o(r) := '1';
        end if;
        ax(asize(r)) := '1';
      end loop;
    else
      o(1) := '1';
    end if;
    if enable='0' then
      o := (others => '0');
    end if;
    enabledec <= o;
  end process;

  pdecproc: process(clk)
  begin
    if rising_edge(clk) then
      if enable /= '0' then
        penabledec <= enabledec;
      end if;
    end if;
  end process;
  oor <= '1' when nrams>1 and penabledec=(penabledec'range => '0') else '0';

  dataouth <=
    ramouth(1+(3 mod nrams)).dataout when nrams>3 and penabledec(1+(3 mod nrams))='1' else
    ramouth(1+(2 mod nrams)).dataout when nrams>2 and penabledec(1+(2 mod nrams))='1' else
    ramouth(1+(1 mod nrams)).dataout when nrams>1 and penabledec(1+(1 mod nrams))='1' else
    ramouth(1).dataout;

  dataoutl <=
    ramoutl(1+(3 mod nrams)).dataout when nrams>3 and penabledec(1+(3 mod nrams))='1' else
    ramoutl(1+(2 mod nrams)).dataout when nrams>2 and penabledec(1+(2 mod nrams))='1' else
    ramoutl(1+(1 mod nrams)).dataout when nrams>1 and penabledec(1+(1 mod nrams))='1' else
    ramoutl(1).dataout;

  ----------------------------------------------------------------------------
  -- Memories
  ----------------------------------------------------------------------------
  -- Syncram
  ram0gen: if ramtype=0 generate
    ramloop: for r in 1 to nrams generate
      memh: syncram
        generic map (
          tech       => tech,
          abits      => asize(r),
          dbits      => dbits,
          testen     => testen,
          custombits => memtest_vlen,
          pipeline   => 0,
          rdhold     => 1,
          gatedwr    => 1
          )
        port map (
          clk     => clk,
          address => address(asize(r)-1 downto 0),
          datain  => datainh,
          dataout => ramouth(r).dataout,
          enable  => enabledec(r),
          write   => writeh,
          testin  => testin
          );
      meml: syncram
        generic map (
          tech       => tech,
          abits      => asize(r),
          dbits      => dbits,
          testen     => testen,
          custombits => memtest_vlen,
          pipeline   => 0,
          rdhold     => 1,
          gatedwr    => 1
          )
        port map (
          clk     => clk,
          address => address(asize(r)-1 downto 0),
          datain  => datainl,
          dataout => ramoutl(r).dataout,
          enable  => enabledec(r),
          write   => writel,
          testin  => testin
          );
    end generate;
  end generate;

  -- Syncram with data loopback
  ram1gen: if ramtype=1 generate
    ramloop: for r in 1 to nrams generate
      memh: syncramlb
        generic map (
          tech       => tech,
          abits      => asize(r),
          dbits      => dbits,
          testen     => testen,
          custombits => memtest_vlen,
          rdhold     => 1,
          gatedwr    => 1
          )
        port map (
          clk     => clk,
          address => address(asize(r)-1 downto 0),
          addressw => addressw(asize(r)-1 downto 0),
          datain  => datainh,
          dataout => ramouth(r).dataout,
          dataloop => dloopb(2*dbits-1 downto dbits),
          enable  => enabledec(r),
          write   => writeh,
          testin  => testin
          );
      meml: syncramlb
        generic map (
          tech       => tech,
          abits      => asize(r),
          dbits      => dbits,
          testen     => testen,
          custombits => memtest_vlen,
          rdhold     => 1,
          gatedwr    => 1
          )
        port map (
          clk     => clk,
          address => address(asize(r)-1 downto 0),
          addressw => addressw(asize(r)-1 downto 0),
          datain  => datainl,
          dataout => ramoutl(r).dataout,
          dataloop => dloopb(dbits-1 downto 0),
          enable  => enabledec(r),
          write   => writel,
          testin  => testin
          );
    end generate;
  end generate;

  -- Syncram-BW
  ram2gen: if ramtype=2 generate
    ramloop: for r in 1 to nrams generate
      memh: syncrambw
        generic map (
          tech => tech,
          abits => asize(r),
          dbits => 32,
          testen => testen,
          pipeline => 0,
          rdhold => 1,
          gatedwr => 1,
          custombits => memtest_vlen
          )
        port map (
          clk => clk,
          address => address(asize(r)-1 downto 0),
          datain => datainh,
          dataout => ramouth(r).dataout,
          enable(3) => enabledec(r),
          enable(2) => enabledec(r),
          enable(1) => enabledec(r),
          enable(0) => enabledec(r),
          write => writebw(7 downto 4),
          testin => testin
          );
      meml: syncrambw
        generic map (
          tech => tech,
          abits => asize(r),
          dbits => 32,
          testen => testen,
          pipeline => 0,
          rdhold => 1,
          gatedwr => 1,
          custombits => memtest_vlen
          )
        port map (
          clk => clk,
          address => address(asize(r)-1 downto 0),
          datain => datainl,
          dataout => ramoutl(r).dataout,
          enable(3) => enabledec(r),
          enable(2) => enabledec(r),
          enable(1) => enabledec(r),
          enable(0) => enabledec(r),
          write => writebw(3 downto 0),
          testin => testin
          );
    end generate;
  end generate;

end;
