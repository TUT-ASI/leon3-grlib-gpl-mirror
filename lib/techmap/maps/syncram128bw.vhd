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
-- Entity: 	syncram128bw
-- File:	syncram128bw.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Description:	128-bit syncronous 1-port ram with 8-bit write strobes
--		and tech selection
------------------------------------------------------------------------------

library ieee;
library techmap;
use ieee.std_logic_1164.all;
use techmap.gencomp.all;
library grlib;
use grlib.config.all;
use grlib.config_types.all;
use grlib.stdlib.all;

entity syncram128bw is
  generic (tech : integer := 0; abits : integer := 6; testen : integer := 0;
           custombits: integer := 1; pipeline : integer range 0 to 15 := 0);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (127 downto 0);
    dataout : out std_logic_vector (127 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0);
    testin  : in  std_logic_vector (TESTIN_WIDTH-1 downto 0) := testin_none
    );
end;

architecture rtl of syncram128bw is

  component unisim_syncram128bw
  generic ( abits : integer := 9);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (127 downto 0);
    dataout : out std_logic_vector (127 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0)
  );
  end component;

  component ultrascale_syncram128bw
  generic ( abits : integer := 9);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (127 downto 0);
    dataout : out std_logic_vector (127 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0)
  );
  end component;


  component versal_syncram128bw
  generic ( abits : integer := 9);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (127 downto 0);
    dataout : out std_logic_vector (127 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0)
  );
  end component;


  component altera_syncram128bw
  generic ( abits : integer := 9);
  port (
    clk     : in std_ulogic;
    address : in std_logic_vector (abits -1 downto 0);
    datain  : in std_logic_vector (127 downto 0);
    dataout : out std_logic_vector (127 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0)
  );
  end component;

  component tm65gplus_syncram128bw
  generic ( abits : integer := 9);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (127 downto 0);
    dataout : out std_logic_vector (127 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0);
    testin  : in  std_logic_vector (3 downto 0) := "0000"
  );
  end component;

  component ut90nhbd_syncram128bw
  generic ( abits : integer := 9);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (127 downto 0);
    dataout : out std_logic_vector (127 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0);
    tdbn    : in  std_ulogic
  );
  end component;

  signal xenable, xwrite : std_logic_vector(15 downto 0);
  signal custominx,customoutx: std_logic_vector(syncram_customif_maxwidth downto 0);
  signal dataoutx : std_logic_vector(127 downto 0);

begin

  xenable <= enable when testen=0 or testin(TESTIN_WIDTH-2)='0' else (others => '0');
  xwrite <= write when testen=0 or testin(TESTIN_WIDTH-2)='0' else (others => '0');

    custominx <= (others => '0');

  nocust: if syncram_has_customif(tech)=0 or has_sram128bw(tech)=0 generate
    customoutx <= (others => '0');
  end generate;
  
  s64 : if has_sram128bw(tech) = 1 generate
    xc2v : if (is_unisim(tech) = 1)  and (is_ultrascale(tech) = 0) and (tech /= versal) generate 
      x0 : unisim_syncram128bw generic map (abits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
    end generate;
    xu : if (is_unisim(tech) = 1)  and (is_ultrascale(tech) = 1) and (tech /= versal) generate 
      x0 : ultrascale_syncram128bw generic map (abits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
    end generate;
    xversal : if (tech = versal) generate
      x0 : ultrascale_syncram128bw generic map (abits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
    end generate;
    alt : if (tech = stratix2) or (tech = stratix3) or (tech = stratix4) or 
	(tech = cyclone3) or (tech = altera) or (tech = stratix5) generate
      x0 : altera_syncram128bw generic map (abits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
    end generate;
    tm65: if tech = tm65gplus generate
      x0 : tm65gplus_syncram128bw generic map (abits)
         port map (clk, address, datain, dataoutx, xenable, xwrite, testin(TESTIN_WIDTH-1 downto TESTIN_WIDTH-4));
    end generate;
    ut09: if tech = ut90 generate
      x0 : ut90nhbd_syncram128bw generic map (abits)
         port map (clk, address, datain, dataoutx, xenable, xwrite, testin(TESTIN_WIDTH-3));
    end generate;
    nogenreg : if pipeline = 0 generate
      dataout <= dataoutx;
    end generate;
    genreg : if pipeline /= 0 generate
      dreg : process(clk)
      begin
        if rising_edge(clk) then
          dataout <= dataoutx;
        end if;
      end process;
    end generate;


-- pragma translate_off
    dmsg : if GRLIB_CONFIG_ARRAY(grlib_debug_level) >= 2 generate
      x : process
      begin
        assert false report "syncram128bw: " & tost(2**abits) & "x128" &
         " (" & tech_table(tech) & ")"
        severity note;
        wait;
      end process;
    end generate;
-- pragma translate_on
  end generate;

  nos64 : if has_sram128bw(tech) = 0 generate
    rx : for i in 0 to 15 generate
      x0 : syncram generic map (tech, abits, 8, testen, custombits, pipeline)
         port map (clk, address, datain(i*8+7 downto i*8), 
	    dataout(i*8+7 downto i*8), enable(i), write(i), testin
                   );
    end generate;
  end generate;

end;

