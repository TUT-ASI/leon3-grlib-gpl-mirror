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
-- Entity: 	regfile64l5
-- File:	regfile64l5.vhd
-- Author:	Andrea Merlo, Cobham Gaisler AB
-- Description:	4-read ports and 2-write ports regfile
------------------------------------------------------------------------------

library ieee;
library techmap;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use techmap.gencomp.all;
use techmap.allmem.all;

library grlib;
use grlib.stdlib.all;

library gaisler;
use gaisler.noelv.all;

entity regfile64sramnv is
  generic (
    tech        : integer;
    abits       : integer;
    dbits       : integer;
    wrfst       : integer;
    numregs     : integer;
    reg0write   : integer := 0;
    testen      : integer;
    rfreadhold  : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    waddr1   : in  std_logic_vector((abits -1) downto 0);
    wdata1   : in  std_logic_vector((dbits -1) downto 0);
    we1      : in  std_ulogic;
    waddr2   : in  std_logic_vector((abits -1) downto 0);
    wdata2   : in  std_logic_vector((dbits -1) downto 0);
    we2      : in  std_ulogic;
    raddr1   : in  std_logic_vector((abits -1) downto 0);
    re1      : in  std_ulogic;
    rdata1   : out std_logic_vector((dbits -1) downto 0);
    raddr2   : in  std_logic_vector((abits -1) downto 0);
    re2      : in  std_ulogic;
    rdata2   : out std_logic_vector((dbits -1) downto 0);
    raddr3   : in  std_logic_vector((abits -1) downto 0);
    re3      : in  std_ulogic;
    rdata3   : out std_logic_vector((dbits -1) downto 0);
    raddr4   : in  std_logic_vector((abits -1) downto 0);
    re4      : in  std_ulogic;
    rdata4   : out std_logic_vector((dbits -1) downto 0);
    testin   : in  std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
    );
end regfile64sramnv;

architecture rtl of regfile64sramnv is

  constant RPORTS : integer := 4;
  constant WPORTS : integer := 2;

  type lwrite is array (0 to 2**abits-1) of std_logic_vector(log2x(WPORTS)-1 downto 0);

  type reg_type is record
    raddr1  : std_logic_vector((abits - 1) downto 0);
    raddr2  : std_logic_vector((abits - 1) downto 0);
    raddr3  : std_logic_vector((abits - 1) downto 0);
    raddr4  : std_logic_vector((abits - 1) downto 0);
    lwrite1 : lwrite;
    lwrite2 : lwrite;
    lwrite3 : lwrite;
    lwrite4 : lwrite;
  end record;

  constant reg_type_rst : reg_type := (
    raddr1      => (others => '0'),
    raddr2      => (others => '0'),
    raddr3      => (others => '0'),
    raddr4      => (others => '0'),
    lwrite1     => (others => (others => '0')),
    lwrite2     => (others => (others => '0')),
    lwrite3     => (others => (others => '0')),
    lwrite4     => (others => (others => '0'))
  );

  signal rdata10, rdata11 : std_logic_vector(dbits - 1 downto 0);
  signal rdata20, rdata21 : std_logic_vector(dbits - 1 downto 0);
  signal rdata30, rdata31 : std_logic_vector(dbits - 1 downto 0);
  signal rdata40, rdata41 : std_logic_vector(dbits - 1 downto 0);

  signal r, rin : reg_type;

begin  -- rtl

  -- Syncrams (WPORTS for each RPORTS)

  -- PORT1
  x0 : syncram_2p generic map (tech, abits, dbits, 0, wrfst, testen, 0, memtest_vlen, 0, rfreadhold)
    port map (clk, re1, raddr1, rdata10, clk, we1, waddr1, wdata1, testin
              );

  x1 : syncram_2p generic map (tech, abits, dbits, 0, wrfst, testen, 0, memtest_vlen, 0, rfreadhold)
    port map (clk, re1, raddr1, rdata11, clk, we2, waddr2, wdata2, testin
              );

  -- PORT2
  x2 : syncram_2p generic map (tech, abits, dbits, 0, wrfst, testen, 0, memtest_vlen, 0, rfreadhold)
    port map (clk, re1, raddr2, rdata20, clk, we1, waddr1, wdata1, testin
              );

  x3 : syncram_2p generic map (tech, abits, dbits, 0, wrfst, testen, 0, memtest_vlen, 0, rfreadhold)
    port map (clk, re1, raddr2, rdata21, clk, we2, waddr2, wdata2, testin
              );

  -- PORT3
  x4 : syncram_2p generic map (tech, abits, dbits, 0, wrfst, testen, 0, memtest_vlen, 0, rfreadhold)
    port map (clk, re1, raddr3, rdata30, clk, we1, waddr1, wdata1, testin
              );

  x5 : syncram_2p generic map (tech, abits, dbits, 0, wrfst, testen, 0, memtest_vlen, 0, rfreadhold)
    port map (clk, re1, raddr3, rdata31, clk, we2, waddr2, wdata2, testin
              );

  -- PORT4
  x6 : syncram_2p generic map (tech, abits, dbits, 0, wrfst, testen, 0, memtest_vlen, 0, rfreadhold)
    port map (clk, re1, raddr4, rdata40, clk, we1, waddr1, wdata1, testin
              );

  x7 : syncram_2p generic map (tech, abits, dbits, 0, wrfst, testen, 0, memtest_vlen, 0, rfreadhold)
    port map (clk, re1, raddr4, rdata41, clk, we2, waddr2, wdata2, testin
              );

  comb : process(r, rstn, waddr1, we1, waddr2, we2, re1, raddr1, re2, raddr2, re3, raddr3, re4, raddr4, rdata10, rdata11, rdata20, rdata21, rdata30, rdata31, rdata40, rdata41)
    variable v       : reg_type;
    variable rdata1v : std_logic_vector(dbits-1 downto 0);
    variable rdata2v : std_logic_vector(dbits-1 downto 0);
    variable rdata3v : std_logic_vector(dbits-1 downto 0);
    variable rdata4v : std_logic_vector(dbits-1 downto 0);
  begin

    v := r;

    -- Register Input Address
    if re1 = '1' then
      v.raddr1  := raddr1;
    end if;

    if re2 = '1' then
      v.raddr2  := raddr2;
    end if;

    if re3 = '1' then
      v.raddr3  := raddr3;
    end if;

    if re4 = '1' then
      v.raddr4  := raddr4;
    end if;

    -- Store most recent valid value

    -- PORT1
    if we1 = '1' then
      v.lwrite1(to_integer(unsigned(waddr1))) := "0";
    end if;

    if we2 = '1' then
      v.lwrite1(to_integer(unsigned(waddr2))) := "1";
    end if;

    -- PORT2
    if we1 = '1' then
      v.lwrite2(to_integer(unsigned(waddr1))) := "0";
    end if;

    if we2 = '1' then
      v.lwrite2(to_integer(unsigned(waddr2))) := "1";
    end if;

    -- PORT3
    if we1 = '1' then
      v.lwrite3(to_integer(unsigned(waddr1))) := "0";
    end if;

    if we2 = '1' then
      v.lwrite3(to_integer(unsigned(waddr2))) := "1";
    end if;

    -- PORT4
    if we1 = '1' then
      v.lwrite4(to_integer(unsigned(waddr1))) := "0";
    end if;

    if we2 = '1' then
      v.lwrite4(to_integer(unsigned(waddr2))) := "1";
    end if;

    rdata1v := (others => '0');
    if r.raddr1 /= "00000" or reg0write = 1 then
      rdata1v := rdata10;
      if r.lwrite1(to_integer(unsigned(r.raddr1))) = "1" then
        rdata1v := rdata11;
      end if;
    end if;

    rdata2v := (others => '0');
    if r.raddr2 /= "00000" or reg0write = 1 then
      rdata2v := rdata20;
      if r.lwrite2(to_integer(unsigned(r.raddr2))) = "1" then
        rdata2v := rdata21;
      end if;
    end if;

    rdata3v := (others => '0');
    if r.raddr3 /= "00000" or reg0write = 1 then
      rdata3v := rdata30;
      if r.lwrite3(to_integer(unsigned(r.raddr3))) = "1" then
        rdata3v := rdata31;
      end if;
    end if;

    rdata4v := (others => '0');
    if r.raddr4 /= "00000" or reg0write = 1 then
      rdata4v := rdata40;
      if r.lwrite4(to_integer(unsigned(r.raddr4))) = "1" then
        rdata4v := rdata41;
      end if;
    end if;

    -- Reset
    if rstn = '0' then
      v         := reg_type_rst;
    end if;

    -- Output Signals
    rdata1 <= rdata1v;
    rdata2 <= rdata2v;
    rdata3 <= rdata3v;
    rdata4 <= rdata4v;
    rin    <= v;

  end process;

  seq : process(clk, rstn)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;

  end process;


end rtl;
