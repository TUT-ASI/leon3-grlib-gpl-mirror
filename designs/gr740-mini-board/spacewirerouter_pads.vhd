------------------------------------------------------------------------------
--  Wrapper for SerDes (MPCS) IP instantiations for the CertusPro on the
--  GR740-MINI board.
--  Copyright (C) 2023 Frontgrade Gaisler
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;

library techmap;
use techmap.gencomp.all;
use techmap.allclkgen.all;

entity spacewirerouter_pads is
  generic (
    padtech : integer;
    CFG_SPW_EN_GR740_4 : integer range 0 to 1;
    CFG_SPW_EN_GR740_5 : integer range 0 to 1;
    CFG_SPW_EN_GR740_6 : integer range 0 to 1;
    CFG_SPW_EN_GR740_7 : integer range 0 to 1; 
    CFG_SPW_EN_MEZ_1 : integer range 0 to 1;
    CFG_SPW_EN_MEZ_2 : integer range 0 to 1;
    CFG_SPW_EN_MEZ_3 : integer range 0 to 1;
    CFG_SPW_EN_MEZ_4 : integer range 0 to 1); 
  port ( 
    dtmp : out std_logic_vector((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2 + CFG_SPW_EN_MEZ_3 + CFG_SPW_EN_MEZ_4 -1) downto 0);
    stmp : out std_logic_vector((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2 + CFG_SPW_EN_MEZ_3 + CFG_SPW_EN_MEZ_4 -1) downto 0);
    do   : in std_logic_vector((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2 + CFG_SPW_EN_MEZ_3 + CFG_SPW_EN_MEZ_4)*2-1 downto 0);
    so   : in std_logic_vector((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2 + CFG_SPW_EN_MEZ_3 + CFG_SPW_EN_MEZ_4)*2-1 downto 0);
    spw_din_gr740_4   : in    std_logic;
    spw_sin_gr740_4   : in    std_logic;
    spw_dout_gr740_4  : out   std_logic;
    spw_sout_gr740_4  : out   std_logic;
    spw_din_gr740_5   : in    std_logic;
    spw_sin_gr740_5   : in    std_logic;
    spw_dout_gr740_5  : out   std_logic;
    spw_sout_gr740_5  : out   std_logic;
    spw_din_gr740_6   : in    std_logic;
    spw_sin_gr740_6   : in    std_logic;
    spw_dout_gr740_6  : out   std_logic;
    spw_sout_gr740_6  : out   std_logic;
    spw_din_gr740_7   : in    std_logic;
    spw_sin_gr740_7   : in    std_logic;
    spw_dout_gr740_7  : out   std_logic;
    spw_sout_gr740_7  : out   std_logic; 
    spw_din_mez_1     : in    std_logic;
    spw_sin_mez_1     : in    std_logic;
    spw_dout_mez_1    : out   std_logic;
    spw_sout_mez_1    : out   std_logic;  
    spw_din_mez_2     : in    std_logic;
    spw_sin_mez_2     : in    std_logic;
    spw_dout_mez_2    : out   std_logic;
    spw_sout_mez_2    : out   std_logic;
    spw_din_mez_3     : in    std_logic;
    spw_sin_mez_3     : in    std_logic;
    spw_dout_mez_3    : out   std_logic;
    spw_sout_mez_3    : out   std_logic;  
    spw_din_mez_4     : in    std_logic;
    spw_sin_mez_4     : in    std_logic;
    spw_dout_mez_4    : out   std_logic;
    spw_sout_mez_4    : out   std_logic);  
   
end;

architecture rtl of spacewirerouter_pads is


  
begin

     spw_gr740_4 : if CFG_SPW_EN_GR740_4 /= 0 generate
       spw_txd_pad : outpad generic map (padtech, lvds, x33v)
         port map (spw_dout_gr740_4, do(2*0));
       spw_txs_pad : outpad generic map (padtech, lvds, x33v)
         port map (spw_sout_gr740_4, so(2*0));
       spwr_rxd_pad : inpad generic map (tech => padtech)
         port map (spw_din_gr740_4, dtmp(0));
       spwr_rxs_pad : inpad generic map (tech => padtech)
         port map (spw_sin_gr740_4, stmp(0));
    end generate spw_gr740_4; 
    
    no_spw_gr740_4 : if CFG_SPW_EN_GR740_4 = 0 generate
      spwr_txd_pad : outpad generic map (padtech)
        port map (spw_dout_gr740_4, '0');
      spwr_txs_pad : outpad generic map (padtech)
        port map (spw_sout_gr740_4, '0');
    end generate no_spw_gr740_4;

    spw_gr740_5 : if CFG_SPW_EN_GR740_5 /= 0 generate
      spw_txd_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_dout_gr740_5, do(2*CFG_SPW_EN_GR740_4));
      spw_txs_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_sout_gr740_5, so(2*CFG_SPW_EN_GR740_4));
      spwr_rxd_pad : inpad generic map (tech => padtech)
        port map (spw_din_gr740_5, dtmp(CFG_SPW_EN_GR740_4));
      spwr_rxs_pad : inpad generic map (tech => padtech)
        port map (spw_sin_gr740_5, stmp(CFG_SPW_EN_GR740_4));
    end generate spw_gr740_5; 

    no_spw_gr740_5 : if CFG_SPW_EN_GR740_5 = 0 generate
      spwr_txd_pad : outpad generic map (padtech)
        port map (spw_dout_gr740_5, '0');
      spwr_txs_pad : outpad generic map (padtech)
        port map (spw_sout_gr740_5, '0');
    end generate no_spw_gr740_5;

    spw_gr740_6 : if CFG_SPW_EN_GR740_6 /= 0 generate
      spw_txd_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_dout_gr740_6, do(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5)));
      spw_txs_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_sout_gr740_6, so(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5)));
      spwr_rxd_pad : inpad generic map (tech => padtech)
        port map (spw_din_gr740_6, dtmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5)));
      spwr_rxs_pad : inpad generic map (tech => padtech)
        port map (spw_sin_gr740_6, stmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5)));
    end generate spw_gr740_6;

    no_spw_gr740_6 : if CFG_SPW_EN_GR740_6 = 0 generate
      spwr_txd_pad : outpad generic map (padtech)
        port map (spw_dout_gr740_6, '0');
      spwr_txs_pad : outpad generic map (padtech)
        port map (spw_sout_gr740_6, '0');
    end generate no_spw_gr740_6;

    spw_gr740_7 : if CFG_SPW_EN_GR740_7 /= 0 generate
      spw_txd_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_dout_gr740_7, do(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6)));
      spw_txs_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_sout_gr740_7, so(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6)));
      spwr_rxd_pad : inpad generic map (tech => padtech)
        port map (spw_din_gr740_7, dtmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6)));
      spwr_rxs_pad : inpad generic map (tech => padtech)
        port map (spw_sin_gr740_7, stmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6)));
    end generate spw_gr740_7;

    no_spw_gr740_7 : if CFG_SPW_EN_GR740_7 = 0 generate
      spwr_txd_pad : outpad generic map (padtech)
        port map (spw_dout_gr740_7, '0');
      spwr_txs_pad : outpad generic map (padtech)
        port map (spw_sout_gr740_7, '0');
    end generate no_spw_gr740_7;

    spw_mez_1 : if CFG_SPW_EN_MEZ_1 /= 0 generate
      spw_txd_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_dout_mez_1, do(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7)));
      spw_txs_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_sout_mez_1, so(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7)));
      spwr_rxd_pad : inpad generic map (tech => padtech)
        port map (spw_din_mez_1, dtmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7)));
      spwr_rxs_pad : inpad generic map (tech => padtech)
        port map (spw_sin_mez_1, stmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7)));
    end generate spw_mez_1;

    spw_mez_2 : if CFG_SPW_EN_MEZ_2 /= 0 generate
      spw_txd_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_dout_mez_2, do(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1)));
      spw_txs_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_sout_mez_2, so(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1)));
      spwr_rxd_pad : inpad generic map (tech => padtech)
        port map (spw_din_mez_2, dtmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1)));
      spwr_rxs_pad : inpad generic map (tech => padtech)
        port map (spw_sin_mez_2, stmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1)));
    end generate spw_mez_2;

    spw_mez_3 : if CFG_SPW_EN_MEZ_3 /= 0 generate
      spw_txd_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_dout_mez_3, do(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2)));
      spw_txs_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_sout_mez_3, so(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2)));
      spwr_rxd_pad : inpad generic map (tech => padtech)
        port map (spw_din_mez_3, dtmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2)));
      spwr_rxs_pad : inpad generic map (tech => padtech)
        port map (spw_sin_mez_3, stmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2)));
    end generate spw_mez_3;

    spw_mez_4 : if CFG_SPW_EN_MEZ_4 /= 0 generate
      spw_txd_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_dout_mez_4, do(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2 + CFG_SPW_EN_MEZ_3)));
      spw_txs_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_sout_mez_4, so(2*(CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2 + CFG_SPW_EN_MEZ_3)));
      spwr_rxd_pad : inpad generic map (tech => padtech)
        port map (spw_din_mez_4, dtmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2 + CFG_SPW_EN_MEZ_3)));
      spwr_rxs_pad : inpad generic map (tech => padtech)
        port map (spw_sin_mez_4, stmp((CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2 + CFG_SPW_EN_MEZ_3)));
    end generate spw_mez_4;
	 
end rtl;
