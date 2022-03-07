------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity: 	syncram128bw
-- File:    syncram128bw.vhd
-- Author:	Nils-Johan Wessman - Aeroflex Gaisler AB
-- Description:	128-bit data + 28-bit edac syncronous 1-port ram with
--              16-bit write strobes and tech selection
--    
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

entity syncram156bw is
  generic (tech : integer := 0; abits : integer := 6; testen : integer := 0;
           custombits: integer := 1; pipeline : integer range 0 to 15 := 0);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (155 downto 0);
    dataout : out std_logic_vector (155 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0);
    testin  : in  std_logic_vector (TESTIN_WIDTH-1 downto 0) := testin_none
    );
end;

architecture rtl of syncram156bw is

--  component unisim_syncram128bw
--  generic ( abits : integer := 9);
--  port (
--    clk     : in  std_ulogic;
--    address : in  std_logic_vector (abits -1 downto 0);
--    datain  : in  std_logic_vector (127 downto 0);
--    dataout : out std_logic_vector (127 downto 0);
--    enable  : in  std_logic_vector (15 downto 0);
--    write   : in  std_logic_vector (15 downto 0)
--  );
--  end component;
--
--  component altera_syncram128bw
--  generic ( abits : integer := 9);
--  port (
--    clk     : in std_ulogic;
--    address : in std_logic_vector (abits -1 downto 0);
--    datain  : in std_logic_vector (127 downto 0);
--    dataout : out std_logic_vector (127 downto 0);
--    enable  : in  std_logic_vector (15 downto 0);
--    write   : in  std_logic_vector (15 downto 0)
--  );
--  end component;
--
  component cust1_syncram156bw
  generic ( abits : integer := 14; testen : integer := 0);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (155 downto 0);
    dataout : out std_logic_vector (155 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0);
    testin  : in  std_logic_vector (3 downto 0) := "0000"
  );
  end component;

  component ut90nhbd_syncram156bw
  generic (abits : integer := 14);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (155 downto 0);
    dataout : out std_logic_vector (155 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0);
    tdbn    : in  std_ulogic);
  end component;

  component rhs65_syncram156bw
  generic (abits : integer := 14);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (155 downto 0);
    dataout : out std_logic_vector (155 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0);
    scanen   : in std_ulogic;
    bypass   : in std_ulogic;
    mbtdi    : in std_ulogic;
    mbtdo    : out std_ulogic;
    mbshft   : in std_ulogic;
    mbcapt   : in std_ulogic;
    mbupd    : in std_ulogic;
    mbclk    : in std_ulogic;
    mbrstn   : in std_ulogic;
    mbcgate  : in std_ulogic;
    mbpres   : out std_ulogic;
    mbmuxo   : out std_logic_vector(5 downto 0)
    );
  end component;

  component rhs65_syncram156bw_bist is
    generic (
      abits: integer
      );
    port (
      clk     : in  std_ulogic;
      address : in  std_logic_vector (abits -1 downto 0);
      datain  : in  std_logic_vector (155 downto 0);
      dataout : out std_logic_vector (155 downto 0);
      enable  : in  std_logic_vector (15 downto 0);
      write   : in  std_logic_vector (15 downto 0);
      scanen   : in std_ulogic;
      bypass   : in std_ulogic;
      mbctrl   : in std_logic_vector(47 downto 0);
      mbstat   : out std_logic_vector(47 downto 0);
      mbrstn   : in std_ulogic;
      mbcgate  : in std_ulogic
      );
  end component;

  component dare65t_syncram156bw_mbist
  generic (abits : integer := 14);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (155 downto 0);
    dataout : out std_logic_vector (155 downto 0);
    enable  : in  std_logic_vector (15 downto 0);
    write   : in  std_logic_vector (15 downto 0);
    --
    mbist    : in  std_ulogic;
    fill0    : in  std_ulogic;
    fill1    : in  std_ulogic;
    mpresent : out std_ulogic;
    menable  : out std_ulogic;
    error    : out std_ulogic;
    bistrst  : in  std_ulogic;
    testen   : in  std_ulogic;
    testrst  : in  std_ulogic;
    sysclk   : in  std_ulogic;
    --
    awtb     : in  std_ulogic
    );
  end component;

  signal xenable, xwrite : std_logic_vector(15 downto 0);
  signal custominx,customoutx: std_logic_vector(syncram_customif_maxwidth downto 0);
  signal customclkx: std_ulogic;
  signal dataoutx: std_logic_vector(155 downto 0);
  constant TIXW: integer := 100;
  signal testinx: std_logic_vector(TIXW-1 downto 0);

begin

  xenable <= enable when testen=0 or testin(TESTIN_WIDTH-2)='0' else (others => '0');
  xwrite <= write when testen=0 or testin(TESTIN_WIDTH-2)='0' else (others => '0');

    custominx <= (others => '0');
    customclkx <= '0';
  testinx(TIXW-1 downto TIXW-TESTIN_WIDTH) <= testin;
  testinx(TIXW-TESTIN_WIDTH-1 downto 0) <= (others => '0');

  nocust: if syncram_has_customif(tech)=0 or has_sram156bw(tech)=0 generate
    customoutx <= (others => '0');
  end generate;
  
  s156 : if has_sram156bw(tech) = 1 generate
--    xc2v : if (is_unisim(tech) = 1) generate 
--      x0 : unisim_syncram128bw generic map (abits)
--         port map (clk, address, datain, dataout, enable, write);
--    end generate;
--    alt : if (tech = stratix2) or (tech = stratix3) or 
--             (tech = cyclone3) or (tech = altera) generate
--      x0 : altera_syncram128bw generic map (abits)
--         port map (clk, address, datain, dataout, enable, write);
--    end generate;
    cust1u : if tech = custom1 generate
      x0 : cust1_syncram156bw generic map (abits, testen)
         port map (clk, address, datain, dataoutx, xenable, xwrite, testin);
    end generate;
    ut90u : if tech = ut90 generate
      x0 : ut90nhbd_syncram156bw generic map (abits)
         port map (clk, address, datain, dataoutx, xenable, xwrite, testin(TESTIN_WIDTH-3));
    end generate;
    rhs65u : if tech = rhs65 generate
      x0 : rhs65_syncram156bw generic map (abits)
        port map (clk, address, datain, dataoutx, enable, write,
                  testinx(TIXW-8), testinx(TIXW-3),
                  custominx(0),customoutx(0),
                  testinx(TIXW-4), testinx(TIXW-5), testinx(TIXW-6),
                  customclkx,
                  testinx(TIXW-7),'0',
                  customoutx(1), customoutx(7 downto 2));
      customoutx(customoutx'high downto 8) <= (others => '0');
    end generate;
    rhs65ub : if tech = memrhs65b generate
      x0 : rhs65_syncram156bw_bist generic map (abits)
        port map (clk, address, datain, dataoutx, enable, write,
                  testinx(TIXW-3), testinx(TIXW-4),
                  custominx(47 downto 0),customoutx(47 downto 0),
                  testinx(TIXW-5), '0');
      customoutx(customoutx'high downto 48) <= (others => '0');
    end generate;
    dare65u : if tech = dare65t generate
      x0 : dare65t_syncram156bw_mbist generic map (abits)
        port map (clk, address, datain, dataoutx, xenable, write,
                  custominx(0),custominx(1),custominx(2),
                  customoutx(0),customoutx(1),customoutx(2),
                  testinx(TIXW-4),
                  testinx(TIXW-1),
                  testinx(TIXW-3),
                  customclkx,
                  testinx(TIXW-5)
                  );
        customoutx(customoutx'high downto 3) <= (others => '0');
    end generate;
    xgf22: if tech = gf22 generate
      x0 : gf22fdx_syncram156bw
        generic map (abits)
        port map (
          clk        => clk,
          address    => address,
          datain     => datain,
          dataout    => dataoutx,
          enable     => xenable,
          wr         => xwrite,
          tBist      => testinx(TIXW-3),
          tLogic     => testinx(TIXW-4),
          tStab      => testinx(TIXW-5),
          tWbt       => testinx(TIXW-6),
          resetFuse  => testinx(TIXW-7),
          -- tScan      => testinx(TIXW-8),
          s1d_ma     => testinx(TIXW-12 downto TIXW-19),
          -- smp_ma     => testinx(TIXW-20 downto TIXW-31),
          -- r2p_ma     => testinx(TIXW-32 downto TIXW-40),
          ch_bus_s1d => testinx(TIXW-41 downto TIXW-52),
--        ch_bus_r2p => testinx(TIXW-53 downto TIXW-64),
--        ch_bus_smp => testinx(TIXW-65 downto TIXW-76),
          tck        => customclkx,
          eh_bus_s1d => custominx(34 downto 9),
          eh_diagSel => custominx(7 downto 4),
          eh_memEn   => custominx(3 downto 0),
          he_status  => customoutx(11 downto 8),
          he_data    => customoutx(7 downto 4),
          mempres    => customoutx(3 downto 0),
          fShift     => testinx(TIXW-9),
          fDataIn    => custominx(8),
          fBypass    => testinx(TIXW-10),
          fEnable    => testinx(TIXW-11),
          fDataOut   => customoutx(12)
          );
      customoutx(customoutx'high downto 13) <= (others => '0');
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
        assert false report "syncram156bw: " & tost(2**abits) & "x156" &
         " (" & tech_table(tech) & ")"
        severity note;
        wait;
      end process;
    end generate;
    chk : if GRLIB_CONFIG_ARRAY(grlib_syncram_selftest_enable) /= 0 generate
      chkblk: block
        signal refdo: std_logic_vector(155 downto 0);
        signal pren: std_ulogic;
        signal prmask: std_logic_vector(15 downto 0);
        signal paddr: std_logic_vector(abits-1 downto 0);
      begin
        rx : for i in 0 to 15 generate
          x0 : generic_syncram generic map (abits, 8)
            port map (clk, address, datain(i*8+7 downto i*8),
                      refdo(i*8+7 downto i*8), write(i));
          c0 : if i mod 4 = 0 generate
            x0 : generic_syncram generic map (abits, 7)
              port map (clk, address, datain(i/4*7+128+6 downto i/4*7+128),
                        refdo(i/4*7+128+6 downto i/4*7+128), write(i));
          end generate;                 -- c0
        end generate;                   -- rx
        p: process(clk)
        begin
          if rising_edge(clk) then
            for x in 15 downto 0 loop
              assert pren/='1' or prmask(x)/='1' or
                (refdo(8*x+7 downto 8*x)=dataoutx(8*x+7 downto 8*x) and
                 refdo(128+(x/4)*7+6 downto 128+(x/4)*7)=dataoutx(128+(x/4)*7+6 downto 128+(x/4)*7)) or
                is_x(refdo) or is_x(paddr);
            end loop;
            pren <= not orv(write);
            prmask <= enable;
            paddr <= address;
          end if;
        end process;
      end block;                        -- chkblk
    end generate;                       -- chk
-- pragma translate_on
  end generate;

  nos156 : if has_sram156bw(tech) = 0 generate
    rx : for i in 0 to 15 generate
      x0 : syncram generic map (tech, abits, 8, testen, custombits, pipeline)
        port map (clk, address, datain(i*8+7 downto i*8),
          dataoutx(i*8+7 downto i*8), enable(i), write(i), testin
                  );
      c0 : if i mod 4 = 0 generate
        x0 : syncram generic map (tech, abits, 7, testen, custombits, pipeline)
          port map (clk, address, datain(i/4*7+128+6 downto i/4*7+128),
            dataoutx(i/4*7+128+6 downto i/4*7+128), enable(i), write(i), testin
                    );
        end generate;
    end generate;
    dataout <= dataoutx;
  end generate;

end;

