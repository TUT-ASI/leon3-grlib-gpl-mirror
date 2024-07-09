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
-- Entity: 	syncram
-- File:	syncram.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Description:	syncronous 1-port ram with tech selection
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config.all;
use grlib.config_types.all;
use grlib.stdlib.all;
use work.gencomp.all;
use work.allmem.all;

entity syncramlb is
  generic (tech : integer := 0; abits : integer := 6; dbits : integer := 8;
	testen : integer := 0; custombits: integer := 1;
        rdhold: integer := 0;
        gatedwr : integer := 0);
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    addressw : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    dataloop : in std_logic_vector((dbits-1) downto 0);    
    enable   : in std_ulogic;
    write    : in std_ulogic;
    testin   : in std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
    );
end;

architecture rtl of syncramlb is

  constant force_gen: boolean :=
    (abits < syncram_abits_min(tech) and GRLIB_CONFIG_ARRAY(grlib_techmap_strict_ram)=0);
  constant pf_impl: boolean := tech=polarfire and not force_gen;
  constant use_genimpl: boolean := not pf_impl;

  function vmux(v0,v1,m: std_logic_vector) return std_logic_vector is
    variable v0x: std_logic_vector(v0'length-1 downto 0);
    variable v1x: std_logic_vector(v1'length-1 downto 0);
    variable mx: std_logic_vector(m'length-1 downto 0);
    variable r: std_logic_vector(m'length-1 downto 0);
  begin
   v0x := v0;
   v1x := v1;
   mx := m;
   r := (others => '0');
   for x in r'range loop
     if mx(x)/='0' then r(x) := v1x(x); else r(x) := v0x(x); end if;
   end loop;
   return r;
  end vmux;

  signal datainx, dataoutx, dataoutxx, dataloopx: std_logic_vector(dbits-1 downto 0);

  signal preven: std_ulogic;
  signal holddata: std_logic_vector(dbits-1 downto 0);

begin

  dataout <= dataoutx;

  genpf: if pf_impl generate
    s0: polarfire_syncram
      generic map (
        abits => abits,
        dbits => dbits,
        doutpipe => 0,
        lramonly => 0
        )
      port map (
        clk => clk,
        address => address,
        addressw => addressw,
        datain => datainx,
        dataout => dataoutxx,
        enable => enable,
        write => write,
        dataloop => dataloopx
        );
    -- Read-hold emulation
    datainx   <= vmux(datain,holddata,dataloop) when (rdhold/=0 and preven='0') else datain;
    dataloopx <= (others => '0')                when (rdhold/=0 and preven='0') else dataloop;
    dataoutx  <= holddata                       when (rdhold/=0 and preven='0') else dataoutxx;
    p: process(clk)
    begin
      if rising_edge(clk) then
        preven <= enable;
        if preven /= '0' then
          holddata <= dataoutxx;
        end if;
      end if;
    end process;
  end generate;

  genimpl: if use_genimpl generate
    lbgen: for x in dbits-1 downto 0 generate
      datainx(x) <= datain(x) when dataloop(x)='0' else dataoutx(x);
    end generate;
    s0: syncram
      generic map (
        tech => tech,
        abits => abits,
        dbits => dbits,
        testen => testen,
        custombits => custombits,
        pipeline => 0,
        rdhold => rdhold,
        gatedwr => gatedwr
        )
      port map (
        clk => clk,
        address => address,
        datain => datainx,
        dataout => dataoutx,
        enable => enable,
        write => write,
        testin => testin
        );
    dataloopx <= (others => '0');
    dataoutxx <= (others => '0');
    preven <= '0';
    holddata <= (others => '0');
  end generate;

end;
