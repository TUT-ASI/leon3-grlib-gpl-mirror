------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2019, Cobham Gaisler
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
-- Entity: 	syncrambw
-- File:	syncrambw.vhd
-- Author:	Jan Andersson - Aeroflex Gaisler
-- Description:	Synchronous 1-port ram with 8-bit write strobes
--		and tech selection
------------------------------------------------------------------------------

library ieee;
library techmap;
use ieee.std_logic_1164.all;
use techmap.gencomp.all;
use techmap.allmem.all;
library grlib;
use grlib.config.all;
use grlib.config_types.all;
use grlib.stdlib.all;

entity syncrambw is
  generic (tech : integer := 0; abits : integer := 6; dbits : integer := 8;
    testen : integer := 0; custombits: integer := 1;
    pipeline : integer range 0 to 15 := 0; rdhold : integer := 0);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits-1 downto 0);
    datain  : in  std_logic_vector (dbits-1 downto 0);
    dataout : out std_logic_vector (dbits-1 downto 0);
    enable  : in  std_logic_vector (dbits/8-1 downto 0);
    write   : in  std_logic_vector (dbits/8-1 downto 0);
    testin  : in  std_logic_vector (TESTIN_WIDTH-1 downto 0) := testin_none
    );
end;

architecture rtl of syncrambw is

  constant techrdhold : integer := syncram_readhold(tech);

  constant nctrl : integer := abits + (TESTIN_WIDTH-2) + 2*dbits/8;
  signal dataoutx, dataoutxx, dataoutxxx, databp, testdata : std_logic_vector((dbits -1) downto 0);
  constant SCANTESTBP : boolean := (testen = 1) and syncram_add_scan_bypass(tech)=1;

  signal xenable, xwrite : std_logic_vector(dbits/8-1 downto 0);
  signal custominx,customoutx: std_logic_vector(syncram_customif_maxwidth downto 0);

  signal preven, preven2: std_ulogic;
  signal prevdata: std_logic_vector((dbits-1) downto 0);

begin

  xenable <= enable when testen=0 or testin(TESTIN_WIDTH-2)='0' else (others => '0');
  xwrite <= write when testen=0 or testin(TESTIN_WIDTH-2)='0' else (others => '0');

  sbw : if has_srambw(tech) >= abits generate
    -- RAM bypass for scan
    scanbp : if SCANTESTBP generate
      comb : process (address, datain, enable, write, testin)
        variable tmp : std_logic_vector((dbits -1) downto 0);
        variable ctrlsigs : std_logic_vector((nctrl -1) downto 0);
      begin
        ctrlsigs := testin(TESTIN_WIDTH-3 downto 0) & write & enable & address;
        tmp := datain;
        for i in 0 to nctrl-1 loop
          tmp(i mod dbits) := tmp(i mod dbits) xor ctrlsigs(i);
        end loop;
        testdata <= tmp;
      end process;

      reg : process (clk)
      begin
        if rising_edge(clk) then
          databp <= testdata;
        end if;
      end process;
      dmuxout : for i in 0 to dbits-1 generate
        x0: grmux2 generic map (tech)
          port map (dataoutx(i), databp(i), testin(TESTIN_WIDTH-1), dataoutxx(i));
      end generate;
    end generate;

    noscanbp : if not SCANTESTBP generate dataoutxx <= dataoutx; end generate;

    -- Read-hold emulation, if needed (dataoutxx -> dataoutxxx)
    rdholdgen: if rdhold /= 0 and techrdhold=0 and
                 (has_sram_pipe(tech)=0 or pipeline=0) generate
      hpreg: process(clk)
      begin
        if rising_edge(clk) then
          preven <= orv(enable);
          if preven='1' then
            prevdata <= dataoutxx;
          end if;
        end if;
      end process;
      dataoutxxx <= dataoutxx when preven='1' else prevdata;
      preven2 <= '0';
    end generate;

    rdholdgen2: if rdhold /= 0 and techrdhold=0 and
                  (has_sram_pipe(tech)/=0 and pipeline/=0) generate
      hpreg: process(clk)
      begin
        if rising_edge(clk) then
          preven <= orv(enable);
          preven2 <= preven;
          if preven2='1' then
            prevdata <= dataoutxx;
          end if;
        end if;
      end process;
      dataoutxxx <= dataoutxx when preven2='1' else prevdata;
    end generate;

    nordhold: if rdhold=0 or techrdhold/=0 generate
      preven <= '0';
      preven2 <= '0';
      prevdata <= (others => '0');
      dataoutxxx <= dataoutxx;
    end generate;

    -- Pipeline register (dataoutxxx -> dataout)
    combreg: if pipeline /= 0 and has_sram_pipe(tech) = 0 and
               rdhold /= 0 and techrdhold=0
    generate
      -- special case where we can use the read-hold prevdata register as
      -- pipeline register
      dataout <= prevdata;
    end generate;

    gendoutreg : if pipeline /= 0 and has_sram_pipe(tech) = 0 generate
      doutreg : process(clk)
      begin
        if rising_edge(clk) then
          dataout <= dataoutxxx;
        end if;
      end process;
    end generate;

    nogendoutreg : if pipeline = 0 or has_sram_pipe(tech) = 1 generate
      dataout <= dataoutxxx;
    end generate;
    
    n2x : if tech = easic45 generate 
      x0 : n2x_syncram_be generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
    end generate;

    uni : if is_unisim(tech) = 1 generate 
      x0 : unisim_syncram_be generic map (abits, dbits, tech)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
    end generate;

    rt4 : if tech = rtg4 generate 
      x0 : rtg4_syncram_be generic map (abits, dbits, pipeline)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
    end generate;

    pf : if tech = polarfire generate 
      x0 : polarfire_syncram_be generic map (abits, dbits, pipeline)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
    end generate;

    igl2 : if (tech = igloo2) or (tech = smartfusion2) generate 
      x0 : igloo2_syncram_be generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
    end generate;

    alt : if tech=stratix5 generate
      x0: altera_syncram_be generic map (abits => abits, dbits => dbits)
        port map (clk => clk, address => address, datain => datain,
                  dataout => dataoutx, enable => xenable, write => xwrite);
    end generate;

    nanex : if tech=nx generate
      x0: nx_syncram_be generic map (abits => abits, dbits => dbits)
        port map (clk => clk, address => address, datain => datain,
                  dataout => dataoutx, enable => xenable, write => xwrite);
    end generate;

    
-- pragma translate_off
    dmsg : if GRLIB_CONFIG_ARRAY(grlib_debug_level) >= 2 generate
      x : process
      begin
        assert false report "syncrambw: " & tost(2**abits) & "x" & tost(dbits) &
         " (" & tech_table(tech) & ")"
        severity note;
        wait;
      end process;
    end generate;
-- pragma translate_on
  end generate;

  nosbw : if has_srambw(tech) < abits generate
    rx : for i in 0 to dbits/8-1 generate
      x0 : syncram generic map (tech, abits, 8, testen, custombits, pipeline, rdhold)
         port map (clk, address, datain(i*8+7 downto i*8), 
	    dataoutx(i*8+7 downto i*8), enable(i), write(i), testin
                   );
    end generate;
    dataout <= dataoutx;
    dataoutxx <= (others => '0');
    dataoutxxx <= (others => '0');
    preven <= '0';
    preven2 <= '0';
    prevdata <= (others => '0');
    databp <= (others => '0');
    testdata <= (others => '0');
  end generate;

    custominx <= (others => '0');

  nocust: if has_srambw(tech) < abits or syncram_has_customif(tech)=0 generate
    customoutx <= (others => '0');
  end generate;
  
end;

