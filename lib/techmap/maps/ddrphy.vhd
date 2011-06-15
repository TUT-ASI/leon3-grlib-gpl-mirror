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
-----------------------------------------------------------------------------
-- Entity: 	ddrphy
-- File:	ddrphy.vhd
-- Author:	Jiri Gaisler, Gaisler Research
-- Description:	DDR PHY with tech mapping
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;
use techmap.allddr.all;

------------------------------------------------------------------
-- DDR PHY with tech mapping  ------------------------------------
------------------------------------------------------------------

entity ddrphy is
  generic (tech : integer := virtex2; MHz : integer := 100; 
	rstdelay : integer := 200; dbits : integer := 16; 
	clk_mul : integer := 2 ; clk_div : integer := 2;
	rskew : integer :=0; mobile : integer := 0);
  port (
    rst       : in  std_ulogic;
    clk       : in  std_logic;          	-- input clock
    clkout    : out std_ulogic;			-- system clock
    clkread   : out std_ulogic;			-- read clock
    lock      : out std_ulogic;			-- DCM locked

    ddr_clk 	: out std_logic_vector(2 downto 0);
    ddr_clkb	: out std_logic_vector(2 downto 0);
    ddr_clk_fb_out  : out std_logic;
    ddr_clk_fb  : in std_logic;
    ddr_cke  	: out std_logic_vector(1 downto 0);
    ddr_csb  	: out std_logic_vector(1 downto 0);
    ddr_web  	: out std_ulogic;                       -- ddr write enable
    ddr_rasb  	: out std_ulogic;                       -- ddr ras
    ddr_casb  	: out std_ulogic;                       -- ddr cas
    ddr_dm   	: out std_logic_vector (dbits/8-1 downto 0);    -- ddr dm
    ddr_dqs  	: inout std_logic_vector (dbits/8-1 downto 0);    -- ddr dqs
    ddr_ad      : out std_logic_vector (13 downto 0);   -- ddr address
    ddr_ba      : out std_logic_vector (1 downto 0);    -- ddr bank address
    ddr_dq    	: inout  std_logic_vector (dbits-1 downto 0); -- ddr data
 
    addr  	: in  std_logic_vector (13 downto 0); -- data mask
    ba    	: in  std_logic_vector ( 1 downto 0); -- data mask
    dqin  	: out std_logic_vector (dbits*2-1 downto 0); -- ddr input data
    dqout 	: in  std_logic_vector (dbits*2-1 downto 0); -- ddr input data
    dm    	: in  std_logic_vector (dbits/4-1 downto 0); -- data mask
    oen       	: in  std_ulogic;
    dqs       	: in  std_ulogic;
    dqsoen     	: in  std_ulogic;
    rasn      	: in  std_ulogic;
    casn      	: in  std_ulogic;
    wen       	: in  std_ulogic;
    csn       	: in  std_logic_vector(1 downto 0);
    cke       	: in  std_logic_vector(1 downto 0);
    ck          : in  std_logic_vector(2 downto 0);
    moben       : in  std_logic
  );
end;

architecture rtl of ddrphy is

begin

  inf : if (tech = inferred) generate
    ddr_phy0 : generic_ddr_phy
     generic map (MHz => MHz, rstdelay => rstdelay
-- reduce 200 us start-up delay during simulation
-- pragma translate_off
        / 200
-- pragma translate_on
        , clk_mul => clk_mul, clk_div => clk_div, dbits => dbits, rskew => rskew, mobile => mobile
        )
     port map (
        rst, clk, clkout, lock,
        ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
        ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
        ddr_dm, ddr_dqs, ddr_ad, ddr_ba, ddr_dq,
        addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
        rasn, casn, wen, csn, cke, ck, moben);
  end generate;


  strat2 : if (tech = stratix2) generate

    ddr_phy0 : stratixii_ddr_phy 
     generic map (MHz => MHz, rstdelay => rstdelay
-- reduce 200 us start-up delay during simulation
-- pragma translate_off
	/ 200
-- pragma translate_on
	, clk_mul => clk_mul, clk_div => clk_div, dbits => dbits
	)
     port map (
	rst, clk, clkout, lock,
	ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_ad, ddr_ba, ddr_dq,
	addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
	rasn, casn, wen, csn, cke);

  end generate;

  cyc3 : if (tech = cyclone3) generate

    ddr_phy0 : cycloneiii_ddr_phy 
     generic map (MHz => MHz, rstdelay => rstdelay
-- reduce 200 us start-up delay during simulation
-- pragma translate_off
	/ 200
-- pragma translate_on
	, clk_mul => clk_mul, clk_div => clk_div, dbits => dbits, rskew => rskew
  )
     port map (
	rst, clk, clkout, lock,
	ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_ad, ddr_ba, ddr_dq,
	addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
	rasn, casn, wen, csn, cke);

  end generate;

  xc2v : if (tech = virtex2) or (tech = spartan3) generate

    ddr_phy0 : virtex2_ddr_phy 
     generic map (MHz => MHz, rstdelay => rstdelay
-- reduce 200 us start-up delay during simulation
-- pragma translate_off
	/ 200
-- pragma translate_on
	, clk_mul => clk_mul, clk_div => clk_div, dbits => dbits, rskew => rskew
	)
     port map (
	rst, clk, clkout, lock,
	ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_ad, ddr_ba, ddr_dq,
	addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
	rasn, casn, wen, csn, cke);

  end generate;

  xc4v : if (tech = virtex4) or (tech = virtex5) or (tech = virtex6) generate

    ddr_phy0 : virtex4_ddr_phy 
     generic map (MHz => MHz, rstdelay => rstdelay
-- reduce 200 us start-up delay during simulation
-- pragma translate_off
	/ 200
-- pragma translate_on
	, clk_mul => clk_mul, clk_div => clk_div, dbits => dbits, rskew => rskew
	)
     port map (
	rst, clk, clkout, lock,
	ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_ad, ddr_ba, ddr_dq,
	addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
	rasn, casn, wen, csn, cke, ck);

  end generate;

  xc3se : if (tech = spartan3e) or  (tech = spartan6) generate

    ddr_phy0 : spartan3e_ddr_phy 
     generic map (MHz => MHz, rstdelay => rstdelay
-- reduce 200 us start-up delay during simulation
-- pragma translate_off
	/ 200
-- pragma translate_on
	, clk_mul => clk_mul, clk_div => clk_div, dbits => dbits, rskew => rskew
	)
     port map (
	rst, clk, clkout, clkread, lock,
	ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_ad, ddr_ba, ddr_dq,
	addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
	rasn, casn, wen, csn, cke);

  end generate;

end;


library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;
use techmap.allddr.all;

------------------------------------------------------------------
-- DDR2 PHY with tech mapping  ------------------------------------
------------------------------------------------------------------

entity ddr2phy is
  generic (tech : integer := virtex5; MHz : integer := 100; 
	rstdelay : integer := 200; dbits : integer := 16; 
	clk_mul : integer := 2; clk_div : integer := 2;
	ddelayb0 : integer := 0; ddelayb1 : integer := 0; ddelayb2 : integer := 0;
	ddelayb3 : integer := 0; ddelayb4 : integer := 0; ddelayb5 : integer := 0;
	ddelayb6 : integer := 0; ddelayb7 : integer := 0;
        cbdelayb0: integer := 0;
	cbdelayb1: integer := 0; cbdelayb2: integer := 0; cbdelayb3: integer := 0;        
        numidelctrl : integer := 4; norefclk : integer := 0; rskew : integer := 0;
        eightbanks  : integer  range 0 to 1 := 0; dqsse : integer range 0 to 1 := 0;
        abits       : integer := 14;   nclk: integer := 3; ncs: integer := 2;
        cben: integer := 0; chkbits: integer := 8; ctrl2en: integer := 0);
  port (
    rst            : in    std_ulogic;
    clk            : in    std_logic;   -- input clock
    clkref         : in    std_logic;   -- input 200MHz clock
    clkout         : out   std_ulogic;  -- system clock
    lock           : out   std_ulogic;  -- DCM locked

    ddr_clk        : out   std_logic_vector(nclk-1 downto 0);
    ddr_clkb       : out   std_logic_vector(nclk-1 downto 0);
    ddr_clk_fb_out : out   std_logic;
    ddr_clk_fb     : in    std_logic;
    ddr_cke        : out   std_logic_vector(ncs-1 downto 0);
    ddr_csb        : out   std_logic_vector(ncs-1 downto 0);
    ddr_web        : out   std_ulogic;  -- ddr write enable
    ddr_rasb       : out   std_ulogic;  -- ddr ras
    ddr_casb       : out   std_ulogic;  -- ddr cas
    ddr_dm         : out   std_logic_vector (dbits/8-1 downto 0);    -- ddr dm
    ddr_dqs        : inout std_logic_vector (dbits/8-1 downto 0);    -- ddr dqs
    ddr_dqsn       : inout std_logic_vector (dbits/8-1 downto 0);    -- ddr dqsn
    ddr_ad         : out   std_logic_vector (abits-1 downto 0);           -- ddr address
    ddr_ba         : out   std_logic_vector (1+eightbanks downto 0); -- ddr bank address
    ddr_dq         : inout std_logic_vector (dbits-1 downto 0);      -- ddr data
    ddr_odt        : out   std_logic_vector(ncs-1 downto 0);

    addr           : in    std_logic_vector (abits-1 downto 0);
    ba             : in    std_logic_vector ( 2 downto 0);
    dqin           : out   std_logic_vector (dbits*2-1 downto 0);  -- ddr output data
    dqout          : in    std_logic_vector (dbits*2-1 downto 0);  -- ddr input data
    dm             : in    std_logic_vector (dbits/4-1 downto 0);  -- data mask
    oen            : in    std_ulogic;
    dqs            : in    std_ulogic;
    dqsoen         : in    std_ulogic;
    rasn           : in    std_ulogic;
    casn           : in    std_ulogic;
    wen            : in    std_ulogic;
    csn            : in    std_logic_vector(ncs-1 downto 0);
    cke            : in    std_logic_vector(ncs-1 downto 0);
    cal_en         : in    std_logic_vector(dbits/8-1 downto 0);
    cal_inc        : in    std_logic_vector(dbits/8-1 downto 0);
    cal_pll        : in    std_logic_vector(1 downto 0);
    cal_rst        : in    std_logic;
    odt            : in    std_logic_vector(ncs-1 downto 0);
    oct            : in    std_logic;
    read_pend      : in    std_logic_vector(7 downto 0);
    regwdata       : in    std_logic_vector(63 downto 0);
    regwrite       : in    std_logic_vector(1 downto 0);
    regrdata       : out   std_logic_vector(63 downto 0);

    ddr_cbdm   : out std_logic_vector(chkbits/8-1 downto 0);
    ddr_cbdqs  : inout std_logic_vector(chkbits/8-1 downto 0);
    ddr_cbdqsn : inout std_logic_vector(chkbits/8-1 downto 0);
    ddr_cbdq   : inout std_logic_vector(chkbits-1 downto 0);
    cbdqin     : out std_logic_vector(chkbits*2-1 downto 0);
    cbdqout    : in std_logic_vector(chkbits*2-1 downto 0);
    cbdm       : in std_logic_vector(chkbits/4-1 downto 0);
    cbcal_en   : in std_logic_vector(chkbits/8-1 downto 0);
    cbcal_inc  : in std_logic_vector(chkbits/8-1 downto 0);

    -- Copy of control signals for 2nd DIMM
    ddr_web2    : out std_ulogic;                               -- ddr write enable
    ddr_rasb2   : out std_ulogic;                               -- ddr ras
    ddr_casb2   : out std_ulogic;                               -- ddr cas
    ddr_ad2     : out std_logic_vector (abits-1 downto 0);           -- ddr address
    ddr_ba2     : out std_logic_vector (1+eightbanks downto 0)  -- ddr bank address        
    );
end;

architecture rtl of ddr2phy is
begin

  -- For technologies without PHY-specific registers
  nreggen: if ddr2phy_has_reg(tech)=0 generate
    regrdata <= x"0000000000000000";
  end generate;

  -- For technologies without checkbit support
  ncbgen: if ddr2phy_has_cb(tech)=0 generate
    ddr_cbdm <= (others => '0');
    cbdqin <= (others => '0');
  end generate;
  
  inf : if (has_ddr2phy(tech) = 0) generate
    ddr_phy0 : generic_ddr2_phy
     generic map (MHz => MHz, rstdelay => rstdelay
-- reduce 200 us start-up delay during simulation
-- pragma translate_off
        / 200
-- pragma translate_on
        , clk_mul => clk_mul, clk_div => clk_div, dbits => dbits, rskew => rskew,
        eightbanks => eightbanks, abits => abits, cben => cben, chkbits => chkbits
        )
     port map (
        rst, clk, clkout, lock,
        ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
        ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
        ddr_dm, ddr_dqs, ddr_ad, ddr_ba, ddr_dq, ddr_odt,
        addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
        rasn, casn, wen, csn, cke, "111", odt,
        ddr_cbdm, ddr_cbdqs, ddr_cbdqsn, ddr_cbdq, cbdqin, cbdqout, cbdm
        );
  end generate;
  
  xc4v : if (tech = virtex4) or (tech = virtex5) or (tech = virtex6) generate

    ddr_phy0 : virtex5_ddr2_phy 
     generic map (MHz => MHz, rstdelay => rstdelay,
	clk_mul => clk_mul, clk_div => clk_div, dbits => dbits,
	ddelayb0 => ddelayb0, ddelayb1 => ddelayb1, ddelayb2 => ddelayb2, 
	ddelayb3 => ddelayb3, ddelayb4 => ddelayb4, ddelayb5 => ddelayb5, 
	ddelayb6 => ddelayb6, ddelayb7 => ddelayb7, cbdelayb0 => cbdelayb0,
	cbdelayb1 => cbdelayb1, cbdelayb2 => cbdelayb2, cbdelayb3 => cbdelayb3,
        numidelctrl => numidelctrl, norefclk => norefclk, 
        tech => tech, eightbanks => eightbanks, dqsse => dqsse,
        abits => abits, nclk => nclk, ncs => ncs,
        cben => cben, chkbits => chkbits, ctrl2en => ctrl2en
	)
     port map (
	rst, clk, clkref, clkout, lock,
	ddr_clk, ddr_clkb,
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_dqsn, ddr_ad, ddr_ba, ddr_dq, ddr_odt,
	addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
	rasn, casn, wen, csn, cke, cal_en, cal_inc, cal_rst, odt,
        ddr_cbdm, ddr_cbdqs, ddr_cbdqsn, ddr_cbdq,
        cbdqin, cbdqout, cbdm, cbcal_en, cbcal_inc,
        ddr_web2,ddr_rasb2,ddr_casb2,ddr_ad2,ddr_ba2);

  end generate;

  stra2 : if (tech = stratix2) generate

      ddr_phy0 : stratixii_ddr2_phy
      generic map (MHz => MHz, rstdelay => rstdelay,
        clk_mul => clk_mul, clk_div => clk_div, dbits => dbits
      )
      port map (
        rst, clk, clkout, lock, ddr_clk, ddr_clkb,
        ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb,
        ddr_dm, ddr_dqs, ddr_ad, ddr_ba, ddr_dq, ddr_odt,
        addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
        rasn, casn, wen, csn, cke, cal_en, cal_inc, cal_rst, odt);
                                                                                  
  end generate;

  stra3 : if (tech = stratix3) generate

    ddr_phy0 : stratixiii_ddr2_phy 
     generic map (MHz => MHz, rstdelay => rstdelay,
	clk_mul => clk_mul, clk_div => clk_div, dbits => dbits,
	ddelayb0 => ddelayb0, ddelayb1 => ddelayb1, ddelayb2 => ddelayb2, 
	ddelayb3 => ddelayb3, ddelayb4 => ddelayb4, ddelayb5 => ddelayb5, 
	ddelayb6 => ddelayb6, ddelayb7 => ddelayb7,
        numidelctrl => numidelctrl, norefclk => norefclk, 
        tech => tech, rskew => rskew, eightbanks => eightbanks
	)
     port map (
	rst, clk, clkref, clkout, lock,
	ddr_clk, ddr_clkb, 
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_dqsn, ddr_ad, ddr_ba, ddr_dq, ddr_odt,
	addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
	rasn, casn, wen, csn, cke, cal_en, cal_inc, cal_pll, cal_rst, odt, oct);

  end generate;

  sp3a : if (tech = spartan3) generate
    ddr_phy0 : spartan3a_ddr2_phy 
     generic map (MHz => MHz, rstdelay => rstdelay,
                  clk_mul => clk_mul, clk_div => clk_div, dbits => dbits, tech => tech, rskew => rskew,
                  eightbanks => eightbanks)
     port map (   rst, clk, clkout, lock, ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
                  ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
                  ddr_dm, ddr_dqs, ddr_dqsn, ddr_ad, ddr_ba, ddr_dq, ddr_odt,
                  addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
                  rasn, casn, wen, csn, cke, cal_pll, odt);
  end generate;

  nextreme : if (tech = easic90) generate
    ddr_phy0 : easic90_ddr2_phy
      generic map (
        tech       => tech,
        MHz        => MHz,
        clk_mul    => clk_mul,
        clk_div    => clk_div,
        dbits      => dbits,
        rstdelay   => rstdelay,
        eightbanks => eightbanks)
     port map (
	rst, clk, clkout, lock, ddr_clk, ddr_clkb, ddr_clk_fb_out,
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_dqsn, ddr_ad, ddr_ba, ddr_dq, ddr_odt,
	addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
	rasn, casn, wen, csn, cke, odt, '1');
  end generate;

  sp6 : if  (tech = spartan6) generate
--    ddr_phy0 : spartan6_ddr2_phy 
    ddr_phy0 : spartan3a_ddr2_phy 
     generic map (MHz => MHz, rstdelay => rstdelay,
                  clk_mul => clk_mul, clk_div => clk_div, dbits => dbits, tech => tech, rskew => rskew,
                  eightbanks => eightbanks)
     port map (   rst, clk, clkout, lock, ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
                  ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
                  ddr_dm, ddr_dqs, ddr_dqsn, ddr_ad, ddr_ba, ddr_dq, ddr_odt,
                  addr, ba, dqin, dqout, dm, oen, dqs, dqsoen,
                  rasn, casn, wen, csn, cke, cal_pll, odt);
  end generate;

  nextreme2 : if (tech = easic45) generate
    ddr_phy0 :  n2x_ddr2_phy
      generic map (
        MHz => MHz, rstdelay => rstdelay,
        dbits => dbits, clk_mul => clk_mul, clk_div => clk_div, norefclk => norefclk,
        eightbanks => eightbanks, dqsse => dqsse, abits => abits,
        nclk => nclk, ncs => ncs, ctrl2en => ctrl2en )
      port map (
        rst => rst, clk => clk, clk270d => clkref, clkout => clkout, lock => lock,
        ddr_clk => ddr_clk, ddr_clkb => ddr_clkb, ddr_cke => ddr_cke,
        ddr_csb => ddr_csb, ddr_web => ddr_web, ddr_rasb => ddr_rasb, ddr_casb => ddr_casb,
        ddr_dm => ddr_dm, ddr_dqs => ddr_dqs, ddr_dqsn => ddr_dqsn, ddr_ad => ddr_ad, ddr_ba => ddr_ba,
        ddr_dq => ddr_dq, ddr_odt => ddr_odt,
        addr => addr, ba => ba, dqin => dqin, dqout => dqout, dm => dm,
        oen => oen, dqs => dqs, dqsoen => dqsoen,
        rasn => rasn, casn => casn, wen => wen, csn => csn, cke => cke,
        odt => odt, read_pend => read_pend,
        regwdata => regwdata, regwrite => regwrite, regrdata => regrdata,
        ddr_web2 => ddr_web2, ddr_rasb2 => ddr_rasb2, ddr_casb2 => ddr_casb2,
        ddr_ad2 => ddr_ad2, ddr_ba2 => ddr_ba2
        );
    ddr_clk_fb_out <= '0';
  end generate;
  
end;
