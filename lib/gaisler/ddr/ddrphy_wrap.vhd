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
-- Entity: 	ddr_phy
-- File:	ddr_phy.vhd
-- Author:	Jiri Gaisler, Gaisler Research
-- Description:	Wrapper entities for techmap ddrphy/ddr2phy
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.memctrl.all;

------------------------------------------------------------------
-- DDR1 PHY wrapper -------------------------------------------------------
------------------------------------------------------------------

entity ddrphy_wrap is
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
 
    sdi         : out sdctrl_in_type;
    sdo         : in  sdctrl_out_type);
end;

architecture rtl of ddrphy_wrap is

begin

    ddr_phy0 : ddrphy 
     generic map (tech => tech, MHz => MHz, rstdelay => rstdelay
-- reduce 200 us start-up delay during simulation
-- pragma translate_off
	/ 200
-- pragma translate_on
	, dbits => dbits, clk_mul => clk_mul, clk_div => clk_div, 
	rskew => rskew, mobile => mobile)
     port map (
	rst, clk, clkout, clkread, lock,
	ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_ad, ddr_ba, ddr_dq,
	sdo.address(15 downto 2), sdo.ba(1 downto 0),
	sdi.data(dbits*2-1 downto 0), sdo.data(dbits*2-1 downto 0), 
	sdo.dqm(dbits/4-1 downto 0), sdo.bdrive, sdo.bdrive, sdo.qdrive, 
	sdo.rasn, sdo.casn, sdo.sdwen, sdo.sdcsn, sdo.sdcke, sdo.sdck(2 downto 0), sdo.moben);

end;

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.memctrl.all;

------------------------------------------------------------------
-- DDR2 PHY wrapper -----------------------------------------------
------------------------------------------------------------------

entity ddr2phy_wrap is
  generic (tech     : integer := virtex2; MHz        : integer := 100; 
	rstdelay    : integer := 200;     dbits      : integer := 16;  padbits  : integer := 0;
	clk_mul     : integer := 2 ;      clk_div    : integer := 2;
	ddelayb0    : integer := 0;       ddelayb1   : integer := 0;   ddelayb2 : integer := 0;
	ddelayb3    : integer := 0;       ddelayb4   : integer := 0;   ddelayb5 : integer := 0;
	ddelayb6    : integer := 0;       ddelayb7   : integer := 0;
        cbdelayb0   : integer := 0;       cbdelayb1: integer := 0;     cbdelayb2: integer := 0;
        cbdelayb3   : integer := 0;
        numidelctrl : integer := 4;       norefclk   : integer := 0;   odten    : integer := 0;
        rskew       : integer := 0;       eightbanks : integer range 0 to 1 := 0;
        dqsse       : integer range 0 to 1 := 0;
        abits       : integer := 14;      nclk     : integer := 3;     ncs      : integer := 2;
        cben        : integer := 0;       chkbits  : integer := 8;     ctrl2en  : integer := 0);
  port (
    rst            : in    std_ulogic;
    clk            : in    std_logic;   -- input clock
    clkref200      : in    std_logic;   -- input 200MHz clock
    clkout         : out   std_ulogic;  -- system clock
    lock           : out   std_ulogic;  -- DCM locked

    ddr_clk        : out   std_logic_vector(nclk-1 downto 0);
    ddr_clkb       : out   std_logic_vector(nclk-1 downto 0);
    ddr_clk_fb_out : out   std_logic;
    ddr_clk_fb     : in    std_logic;
    ddr_cke        : out   std_logic_vector(ncs-1 downto 0);
    ddr_csb        : out   std_logic_vector(ncs-1 downto 0);
    ddr_web        : out   std_ulogic;                               -- ddr write enable
    ddr_rasb       : out   std_ulogic;                               -- ddr ras
    ddr_casb       : out   std_ulogic;                               -- ddr cas
    ddr_dm         : out   std_logic_vector ((dbits+padbits)/8-1 downto 0);    -- ddr dm
    ddr_dqs        : inout std_logic_vector ((dbits+padbits)/8-1 downto 0);    -- ddr dqs
    ddr_dqsn       : inout std_logic_vector ((dbits+padbits)/8-1 downto 0);    -- ddr dqs
    ddr_ad         : out   std_logic_vector (abits-1 downto 0);           -- ddr address
    ddr_ba         : out   std_logic_vector (1+eightbanks downto 0); -- ddr bank address
    ddr_dq         : inout std_logic_vector ((dbits+padbits)-1 downto 0);      -- ddr data
    ddr_odt        : out   std_logic_vector(ncs-1 downto 0);
    ddr_cbdm       : out   std_logic_vector(chkbits/8-1 downto 0);
    ddr_cbdqs      : inout std_logic_vector(chkbits/8-1 downto 0);
    ddr_cbdqsn     : inout std_logic_vector(chkbits/8-1 downto 0);
    ddr_cbdq       : inout std_logic_vector(chkbits-1 downto 0);
    ddr_web2       : out   std_ulogic;                               -- ddr write enable
    ddr_rasb2      : out   std_ulogic;                               -- ddr ras
    ddr_casb2      : out   std_ulogic;                               -- ddr cas
    ddr_ad2        : out   std_logic_vector (abits-1 downto 0);      -- ddr address
    ddr_ba2        : out   std_logic_vector (1+eightbanks downto 0); -- ddr bank address
    
    sdi            : out   sdctrl_in_type;
    sdo            : in    sdctrl_out_type
    );
end;

architecture rtl of ddr2phy_wrap is

  function ddr_widthconv(x: std_logic_vector; ow: integer) return std_logic_vector is
    variable r: std_logic_vector(2*ow-1 downto 0);
    constant iw: integer := x'length/2;
  begin
    r := (others => '0');
    if iw <= ow then
      r(iw+ow-1 downto ow) := x(2*iw-1 downto iw);
      r(iw-1 downto 0) := x(iw-1 downto 0);
    else
      r := x(iw+ow-1 downto iw) & x(ow-1 downto 0);
    end if;
    return r;
  end;

  function sdr_widthconv(x: std_logic_vector; ow: integer) return std_logic_vector is
    variable r: std_logic_vector(ow-1 downto 0);
    constant iw: integer := x'length;
  begin
    r := (others => '0');
    if iw >= ow then
      r := x(ow-1 downto 0);
    else
      r(iw-1 downto 0) := x;
    end if;
    return r;
  end;

  signal din,dout: std_logic_vector(2*(dbits+padbits)-1 downto 0);
  signal cbin: std_logic_vector(2*chkbits-1 downto 0);
  signal cbout: std_logic_vector(2*chkbits-1 downto 0);
  signal cbdmout: std_logic_vector(chkbits/4-1 downto 0);
  signal cbcal_en_out: std_logic_vector(chkbits/8-1 downto 0);
  signal cbcal_inc_out: std_logic_vector(chkbits/8-1 downto 0);

  signal odt,csn,cke: std_logic_vector(ncs-1 downto 0);
  
begin

  -- Width conversion for data and checkbits
  dout          <= ddr_widthconv(sdo.data(2*dbits-1 downto 0), dbits+padbits);  
  cbout         <= ddr_widthconv(sdo.cb(dbits-1 downto 0), chkbits);
  cbdmout       <= ddr_widthconv(sdo.cbdqm(dbits/8-1 downto 0), chkbits/8);
  cbcal_en_out  <= sdr_widthconv(sdo.cbcal_en(dbits/16-1 downto 0), chkbits/8);
  cbcal_inc_out <= sdr_widthconv(sdo.cbcal_inc(dbits/16-1 downto 0), chkbits/8);
  sdi.data(2*dbits-1 downto 0) <= ddr_widthconv(din, dbits);
  sdi.cb(dbits-1 downto 0) <= ddr_widthconv(cbin, dbits/2);

  comb: process(sdo,din,cbin)
    variable vcsn,vodt,vcke: std_logic_vector(ncs-1 downto 0);
  begin
    vcsn := (others => '1');
    for x in 0 to ncs-1 loop
      if x<2 then
        vcsn(x) := sdo.sdcsn(x);
      end if;
      vodt(x) := sdo.odt(x mod 2);
      vcke(x) := sdo.sdcke(x mod 2);
    end loop;
    csn <= vcsn;
    odt <= vodt;
    cke <= vcke;    
  end process;
  
  -- Phy instantiation
    ddr_phy0 : ddr2phy 
     generic map (tech => tech, MHz => MHz, rstdelay => rstdelay
-- reduce 200 us start-up delay during simulation
-- pragma translate_off
	/ 200
-- pragma translate_on
	, dbits     => dbits+padbits,clk_mul  => clk_mul,  clk_div  => clk_div, 
	ddelayb0    => ddelayb0,    ddelayb1 => ddelayb1, ddelayb2 => ddelayb2,
	ddelayb3    => ddelayb3,    ddelayb4 => ddelayb4, ddelayb5 => ddelayb5,
	ddelayb6    => ddelayb6,    ddelayb7 => ddelayb7,
        numidelctrl => numidelctrl, norefclk => norefclk, rskew    => rskew,
        eightbanks  => eightbanks,  dqsse => dqsse,
        abits       => abits,       nclk    => nclk,      ncs      => ncs,
        cben        => cben,        chkbits => chkbits,   ctrl2en  => ctrl2en)
     port map (
	rst, clk, clkref200, clkout, lock,
	ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_dqsn, ddr_ad, ddr_ba, ddr_dq, ddr_odt,
        
	sdo.address(1+abits downto 2), sdo.ba,
	din, dout, 
	sdo.dqm(dbits/4-1 downto 0), sdo.bdrive, sdo.bdrive, sdo.qdrive, 
	sdo.rasn, sdo.casn, sdo.sdwen, csn, cke,
	sdo.cal_en(dbits/8-1 downto 0), sdo.cal_inc(dbits/8-1 downto 0), 
        sdo.cal_pll, sdo.cal_rst, odt, sdo.oct, sdo.read_pend,
        sdo.regwdata, sdo.regwrite, sdi.regrdata,
        
        ddr_cbdm, ddr_cbdqs, ddr_cbdqsn, ddr_cbdq,
        cbin, cbout, cbdmout, cbcal_en_out, cbcal_inc_out,

        ddr_web2, ddr_rasb2, ddr_casb2, ddr_ad2, ddr_ba2
        );
end;

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.memctrl.all;

------------------------------------------------------------------
-- DDR2 PHY with checkbits merged on data bus --------------------
------------------------------------------------------------------

entity ddr2phy_wrap_cbd is
  generic (tech     : integer := virtex2; MHz        : integer := 100; 
	rstdelay    : integer := 200;     dbits      : integer := 16;  padbits  : integer := 0;
	clk_mul     : integer := 2 ;      clk_div    : integer := 2;
	ddelayb0    : integer := 0;       ddelayb1   : integer := 0;   ddelayb2 : integer := 0;
	ddelayb3    : integer := 0;       ddelayb4   : integer := 0;   ddelayb5 : integer := 0;
	ddelayb6    : integer := 0;       ddelayb7   : integer := 0;
        cbdelayb0   : integer := 0;       cbdelayb1: integer := 0;     cbdelayb2: integer := 0;
        cbdelayb3   : integer := 0;
        numidelctrl : integer := 4;       norefclk   : integer := 0;   odten    : integer := 0;
        rskew       : integer := 0;       eightbanks : integer range 0 to 1 := 0;
        dqsse       : integer range 0 to 1 := 0;
        abits       : integer := 14;      nclk     : integer := 3;     ncs      : integer := 2;
        chkbits  : integer := 0;          ctrl2en  : integer := 0);
  port (
    rst            : in    std_ulogic;
    clk            : in    std_logic;   -- input clock
    clkref200      : in    std_logic;   -- input 200MHz clock
    clkout         : out   std_ulogic;  -- system clock
    lock           : out   std_ulogic;  -- DCM locked

    ddr_clk        : out   std_logic_vector(nclk-1 downto 0);
    ddr_clkb       : out   std_logic_vector(nclk-1 downto 0);
    ddr_clk_fb_out : out   std_logic;
    ddr_clk_fb     : in    std_logic;
    ddr_cke        : out   std_logic_vector(ncs-1 downto 0);
    ddr_csb        : out   std_logic_vector(ncs-1 downto 0);
    ddr_web        : out   std_ulogic;                               -- ddr write enable
    ddr_rasb       : out   std_ulogic;                               -- ddr ras
    ddr_casb       : out   std_ulogic;                               -- ddr cas
    ddr_dm         : out   std_logic_vector ((dbits+padbits+chkbits)/8-1 downto 0);    -- ddr dm
    ddr_dqs        : inout std_logic_vector ((dbits+padbits+chkbits)/8-1 downto 0);    -- ddr dqs
    ddr_dqsn       : inout std_logic_vector ((dbits+padbits+chkbits)/8-1 downto 0);    -- ddr dqs
    ddr_ad         : out   std_logic_vector (abits-1 downto 0);           -- ddr address
    ddr_ba         : out   std_logic_vector (1+eightbanks downto 0); -- ddr bank address
    ddr_dq         : inout std_logic_vector (dbits+padbits+chkbits-1 downto 0);      -- ddr data
    ddr_odt        : out   std_logic_vector(ncs-1 downto 0);
    ddr_web2       : out   std_ulogic;                               -- ddr write enable
    ddr_rasb2      : out   std_ulogic;                               -- ddr ras
    ddr_casb2      : out   std_ulogic;                               -- ddr cas
    ddr_ad2        : out   std_logic_vector (abits-1 downto 0);      -- ddr address
    ddr_ba2        : out   std_logic_vector (1+eightbanks downto 0); -- ddr bank address
    
    sdi            : out   sdctrl_in_type;
    sdo            : in    sdctrl_out_type
    );
end;

architecture rtl of ddr2phy_wrap_cbd is

  function ddr_widthconv(x: std_logic_vector; ow: integer) return std_logic_vector is
    variable r: std_logic_vector(2*ow-1 downto 0);
    constant iw: integer := x'length/2;
  begin
    r := (others => '0');
    if iw <= ow then
      r(iw+ow-1 downto ow) := x(2*iw-1 downto iw);
      r(iw-1 downto 0) := x(iw-1 downto 0);
    else
      r := x(iw+ow-1 downto iw) & x(ow-1 downto 0);
    end if;
    return r;
  end;

  function sdr_widthconv(x: std_logic_vector; ow: integer) return std_logic_vector is
    variable r: std_logic_vector(ow-1 downto 0);
    constant iw: integer := x'length;
    variable xd : std_logic_vector(iw-1 downto 0);
  begin
    r := (others => '0'); xd := x;
    if iw >= ow then
      r := xd(ow-1 downto 0);
    else
      r(iw-1 downto 0) := xd;
    end if;
    return r;
  end;

  function ddrmerge(a,b: std_logic_vector) return std_logic_vector is
    constant aw: integer := a'length/2;
    constant bw: integer := b'length/2;
  begin
    return a(2*aw-1 downto aw) & b(2*bw-1 downto bw) & a(aw-1 downto 0) & b(bw-1 downto 0);
  end;

  signal dqin: std_logic_vector(2*(chkbits+dbits+padbits)-1 downto 0);
  signal dqout: std_logic_vector(2*(chkbits+dbits+padbits)-1 downto 0);
  signal dqm: std_logic_vector((chkbits+dbits+padbits)/4-1 downto 0);
  signal cal_en: std_logic_vector((chkbits+dbits+padbits)/8-1 downto 0);
  signal cal_inc: std_logic_vector((chkbits+dbits+padbits)/8-1 downto 0);

  signal dummy_ddr_cbdqs, dummy_ddr_cbdqsn: std_logic_vector(0 downto 0);
  signal dummy_ddr_cbdq: std_logic_vector(7 downto 0);
  signal dummy_cbdqout: std_logic_vector(15 downto 0);
  signal dummy_cbdm: std_logic_vector(1 downto 0);
  signal dummy_cbcal_en,dummy_cbcal_inc: std_logic_vector(0 downto 0);
  
  signal odt,csn,cke: std_logic_vector(ncs-1 downto 0);
  
begin

  dummy_ddr_cbdqs <= (others => '0');
  dummy_ddr_cbdqsn <= (others => '0');
  dummy_ddr_cbdq <= (others => '0');
  dummy_cbdqout <= (others => '0');
  dummy_cbdm <= (others => '0');
  dummy_cbcal_en <= (others => '0');
  dummy_cbcal_inc <= (others => '0');  
  
  -- Merge checkbit and data buses
  comb: process(sdo,dqin)
    variable dq: std_logic_vector(2*dbits-1 downto 0);
    variable dqpad: std_logic_vector(2*(dbits+padbits)-1 downto 0);
    variable cb: std_logic_vector(dbits-1 downto 0);
    variable cbpad: std_logic_vector(2*chkbits downto 0);  -- Extra bit to handle chkbits=0
    variable dqcb: std_logic_vector(2*(dbits+padbits+chkbits)-1 downto 0);
    variable dm: std_logic_vector(dbits/4-1 downto 0);
    variable dmpad: std_logic_vector((dbits+padbits)/4-1 downto 0);
    variable cbdm: std_logic_vector(dbits/8-1 downto 0);
    variable cbdmpad: std_logic_vector(chkbits/4 downto 0);
    variable dqcbdm: std_logic_vector((dbits+padbits+chkbits)/4-1 downto 0);
    variable vcsn,vodt,vcke: std_logic_vector(ncs-1 downto 0);
  begin

    dq := sdo.data(2*dbits-1 downto 0);
    dqpad := ddr_widthconv(dq, dbits+padbits );
    if chkbits > 0 then
      cb    := sdo.cb(dbits-1 downto 0);
      cbpad := '0' & ddr_widthconv(cb, chkbits);
      dqcb  := ddrmerge(cbpad(2*chkbits-1 downto 0), dqpad);
    else
      dqcb  := dqpad;
    end if;
    dqout <= dqcb;

    dqcb := dqin;
    if chkbits > 0 then
      cbpad := '0' & dqin(2*(chkbits+dbits+padbits)-1 downto 2*(dbits+padbits)+chkbits) &
               dqin(chkbits+dbits+padbits-1 downto dbits+padbits);
      cb := ddr_widthconv(cbpad(2*chkbits-1 downto 0), dbits/2);
    else
      cb := (others => '0');
    end if;
    dq := dqcb(2*dbits+chkbits+padbits-1 downto dbits+chkbits+padbits) &
          dqcb(dbits-1 downto 0);    
    sdi.cb(dbits-1 downto 0) <= cb;
    sdi.data(2*dbits-1 downto 0) <= dq;
    if sdi.cb'length > dbits then
      sdi.cb(sdi.cb'length-1 downto dbits) <= (others => '0');
    end if;
    if sdi.data'length > 2*dbits then
      sdi.data(sdi.data'length-1 downto 2*dbits) <= (others => '0');
    end if;
    
    dm := sdo.dqm(dbits/4-1 downto 0);
    dmpad := ddr_widthconv(dm, (dbits+padbits)/8);
    if chkbits > 0 then
      cbdm := sdo.cbdqm(dbits/8-1 downto 0);
      cbdmpad := '0' & ddr_widthconv(cbdm(dbits/8-1 downto 0), chkbits/8);
      dqcbdm := ddrmerge(cbdmpad(chkbits/4-1 downto 0), dmpad);
    else
      dqcbdm := dmpad;
    end if;
    dqm <= dqcbdm;

    cal_en  <= sdr_widthconv(sdo.cbcal_en (dbits/16-1 downto 0) &
                             sdo.cal_en (dbits/8-1 downto 0), (dbits+padbits+chkbits)/8 );
    cal_inc <= sdr_widthconv(sdo.cbcal_inc(dbits/16-1 downto 0) &
                             sdo.cal_inc(dbits/8-1 downto 0), (dbits+padbits+chkbits)/8 );
        
    vcsn := (others => '1');
    for x in 0 to ncs-1 loop
      if x<2 then
        vcsn(x) := sdo.sdcsn(x);
      end if;
      vodt(x) := sdo.odt(x mod 2);
      vcke(x) := sdo.sdcke(x mod 2);
    end loop;
    csn <= vcsn;
    odt <= vodt;
    cke <= vcke;
    
  end process;
  
  -- Phy instantiation
    ddr_phy0 : ddr2phy 
     generic map (tech => tech, MHz => MHz, rstdelay => rstdelay
-- reduce 200 us start-up delay during simulation
-- pragma translate_off
	/ 200
-- pragma translate_on
	, dbits     => dbits+padbits+chkbits,clk_mul  => clk_mul,  clk_div  => clk_div, 
	ddelayb0    => ddelayb0,    ddelayb1 => ddelayb1, ddelayb2 => ddelayb2,
	ddelayb3    => ddelayb3,    ddelayb4 => ddelayb4, ddelayb5 => ddelayb5,
	ddelayb6    => ddelayb6,    ddelayb7 => ddelayb7,
        numidelctrl => numidelctrl, norefclk => norefclk, rskew    => rskew,
        eightbanks  => eightbanks,  dqsse => dqsse,
        abits       => abits,       nclk    => nclk,      ncs      => ncs,
        cben        => 0,           chkbits => 8,         ctrl2en  => ctrl2en)
     port map (
	rst, clk, clkref200, clkout, lock,
	ddr_clk, ddr_clkb, ddr_clk_fb_out, ddr_clk_fb,
	ddr_cke, ddr_csb, ddr_web, ddr_rasb, ddr_casb, 
	ddr_dm, ddr_dqs, ddr_dqsn, ddr_ad, ddr_ba, ddr_dq, ddr_odt,
        
	sdo.address(1+abits downto 2), sdo.ba,
	dqin, dqout, 
	dqm, sdo.bdrive, sdo.bdrive, sdo.qdrive, 
	sdo.rasn, sdo.casn, sdo.sdwen, csn, cke, 
	cal_en, cal_inc, 
        sdo.cal_pll, sdo.cal_rst, odt, sdo.oct, sdo.read_pend,
        sdo.regwdata, sdo.regwrite, sdi.regrdata,
        
        open, dummy_ddr_cbdqs, dummy_ddr_cbdqsn, dummy_ddr_cbdq, open,
        dummy_cbdqout, dummy_cbdm, dummy_cbcal_en, dummy_cbcal_inc,

        ddr_web2, ddr_rasb2, ddr_casb2, ddr_ad2, ddr_ba2
        );
end;

