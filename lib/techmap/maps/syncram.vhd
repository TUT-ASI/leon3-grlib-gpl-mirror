------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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

entity syncram is
  generic (tech : integer := 0; abits : integer := 6; dbits : integer := 8;
	testen : integer := 0; custombits: integer := 1;
        pipeline : integer range 0 to 15 := 0; rdhold: integer := 0;
        gatedwr : integer := 0);
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic;
    testin   : in std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
    );
end;

architecture rtl of syncram is

  constant genimpl: boolean :=
    (tech=inferred) or
    (abits < syncram_abits_min(tech) and GRLIB_CONFIG_ARRAY(grlib_techmap_strict_ram)=0);
  constant xtech: integer := tech*(1-boolean'pos(genimpl));

  constant xtechrdhold_b: boolean := syncram_readhold(tech)/=0 or genimpl;
  constant xtechrdhold: integer := boolean'pos(xtechrdhold_b);

  constant nctrl : integer := abits + (TESTIN_WIDTH-2) + 2;
  signal dataoutx, dataoutxx, dataoutxxx : std_logic_vector((dbits -1) downto 0);
  constant SCANTESTBP : boolean := (testen = 1) and syncram_add_scan_bypass(tech)=1 and (not genimpl);
  signal xenable, gwrite, xwrite: std_ulogic;

  signal gnd : std_ulogic;

  signal custominx,customoutx: std_logic_vector(syncram_customif_maxwidth downto 0);
  signal customclkx: std_ulogic;

  constant TIXW: integer := 100;
  signal testinx: std_logic_vector(TIXW-1 downto 0);

  signal preven, preven2: std_ulogic;
  signal prevdata: std_logic_vector((dbits-1) downto 0);

begin

  gnd <= '0';

  xenable <= enable and not testin(TESTIN_WIDTH-2) when testen/=0 else enable;
  gwrite <= (write and enable) when (gatedwr/=0 and syncram_wrignen(tech)/=0 and not genimpl) else
            write;
  xwrite <= gwrite and not testin(TESTIN_WIDTH-2) when testen/=0 else gwrite;

  testinx(TIXW-1 downto TIXW-TESTIN_WIDTH) <= testin;
  testinx(TIXW-TESTIN_WIDTH-1 downto 0) <= (others => '0');

  -- RAM bypass for scan (dataoutx -> dataoutxx)
  scanbp : if SCANTESTBP generate
    scanbpblck : block
      signal databp, testdata : std_logic_vector((dbits -1) downto 0);
    begin
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
    end block scanbpblck;
  end generate;

    custominx <= (others => '0');
    customclkx <= '0';

  nocust: if syncram_has_customif(tech)=0 or genimpl generate
    customoutx <= (others => '0');
  end generate;

  noscanbp : if not SCANTESTBP generate dataoutxx <= dataoutx; end generate;

  -- Read-hold emulation, if needed (dataoutxx -> dataoutxxx)
  rdholdgen: if rdhold /= 0 and xtechrdhold=0 and
               (has_sram_pipe(xtech)=0 or pipeline=0) generate
    hpreg: process(clk)
    begin
      if rising_edge(clk) then
        preven <= enable;
        if preven='1' then
          prevdata <= dataoutxx;
        end if;
      end if;
    end process;
    dataoutxxx <= dataoutxx when preven='1' else prevdata;
    preven2 <= '0';
  end generate;

  rdholdgen2: if rdhold /= 0 and xtechrdhold=0 and
                (has_sram_pipe(xtech)/=0 and pipeline/=0) generate
    hpreg: process(clk)
    begin
      if rising_edge(clk) then
        preven <= enable;
        preven2 <= preven;
        if preven2='1' then
          prevdata <= dataoutxx;
        end if;
      end if;
    end process;
    dataoutxxx <= dataoutxx when preven2='1' else prevdata;
  end generate;

  nordhold: if rdhold=0 or xtechrdhold/=0 generate
    preven <= '0';
    preven2 <= '0';
    prevdata <= (others => '0');
    dataoutxxx <= dataoutxx;
  end generate;

  -- Pipeline register (dataoutxxx -> dataout)
  combreg: if pipeline /= 0 and has_sram_pipe(xtech) = 0 and
             rdhold /= 0 and xtechrdhold=0
  generate
    -- special case where we can use the read-hold prevdata register as
    -- pipeline register
    dataout <= prevdata;
  end generate;

  gendoutreg : if pipeline /= 0 and has_sram_pipe(xtech) = 0 and not
                 (rdhold /= 0 and xtechrdhold=0)
  generate
    doutreg : process(clk)
    begin
      if rising_edge(clk) then
        dataout <= dataoutxxx;
      end if;
    end process;
  end generate;

  nogendoutreg : if pipeline = 0 or has_sram_pipe(xtech) = 1 generate
    dataout <= dataoutxxx;
  end generate;

  inf : if xtech=inferred generate
    x0 : generic_syncram generic map (abits, dbits, 0, rdhold, gatedwr)
         port map (clk, address, datain, dataoutx, write, enable);
  end generate;

  
  xcv : if (xtech = virtex) generate
    x0 : virtex_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  xc2v : if (is_unisim(xtech) = 1) and (xtech /= virtex) and
            (xtech /= kintex7) and (is_ultrascale(xtech) /= 1) and
            (xtech /= versal ) generate
    x0 : unisim_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  xk7 : if (xtech = kintex7) generate
    xk7_s : kintex7_syncram generic map (abits, dbits)
          port map (clk, address, datain, xenable, xwrite, dataoutx);
  end generate;

  xku : if (is_ultrascale(xtech) = 1)  generate
    xku_s : ultrascale_syncram generic map (abits, dbits)
      port map (clk, address, datain, xenable, xwrite, dataoutx);
  end generate;

  xversal : if (xtech = versal) generate
    xversal_s : versal_syncram generic map (abits, dbits)
          port map (clk, address, datain, xenable, xwrite, dataoutx);
  end generate;

  vir  : if xtech = memvirage generate
    x0 : virage_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  atrh : if xtech = atc18rha generate
    x0 : atc18rha_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite,
                   testin(TESTIN_WIDTH-1 downto TESTIN_WIDTH-4));
  end generate;

  axc  : if (xtech = axcel) or (xtech = axdsp) generate
    x0 : axcel_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  proa : if (xtech = proasic) generate
    x0 : proasic_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  igl2 : if (xtech = igloo2) generate
    x0 : igloo2_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  rt4 : if (xtech = rtg4) generate
    x0 : rtg4_syncram generic map (abits, dbits, 0, pipeline, 0)
         port map (clk, address, datain, dataoutx, xenable, xwrite,
                   open, gnd);
  end generate;

  pf : if (xtech = polarfire) generate
    x0 : polarfire_syncram generic map (abits, dbits, pipeline, 0)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  umc18  : if xtech = umc generate
    x0 : umc_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  rhu  : if xtech = rhumc generate
    x0 : rhumc_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  saed : if xtech = saed32 generate
    x0 : saed32_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  rhs : if xtech = rhs65 generate
    x0 : rhs65_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, enable, xwrite,
                   testinx(TIXW-8),testinx(TIXW-3),
                   custominx(0),customoutx(0),
                   testinx(TIXW-4),testinx(TIXW-5),testinx(TIXW-6),
                   customclkx,testinx(TIXW-7),'0',
                   customoutx(1), customoutx(7 downto 2));
    customoutx(customoutx'high downto 8) <= (others => '0');
  end generate;

  rhsb : if xtech = memrhs65b generate
    x0 : rhs65_syncram_bist generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, enable, write,
                   testinx(TIXW-3),testinx(TIXW-4),
                   custominx(47 downto 0),customoutx(47 downto 0),
                   testinx(TIXW-5),'0');
    customoutx(customoutx'high downto 48) <= (others => '0');
  end generate;

  dar  : if xtech = dare generate
    x0 : dare_syncram_mbist generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite,
		             custominx(0),custominx(1),
                 customoutx(0),customoutx(1),
                 testin(testin'high),custominx(2));
    customoutx(customoutx'high downto 2) <= (others => '0');
  end generate;

  dare65 : if xtech = dare65t generate
    x0 : dare65t_syncram_mbist generic map (abits, dbits)
         port map (
           clk => clk,
           address => address,
           datain => datain,
           dataout => dataoutx,
           enable => xenable,
           write => xwrite,
           mbist => custominx(0),
           fill0 => custominx(1),
           fill1 => custominx(2),
           mpresent => customoutx(0),
           menable => customoutx(1),
           merror => customoutx(2),
           bistrst => testinx(TIXW-4),
           testen => testinx(TIXW-1),
           testrst => testinx(TIXW-3),
           sysclk => customclkx,
           awtb => testinx(TIXW-5)
           );
    customoutx(customoutx'high downto 3) <= (others => '0');
  end generate;

  proa3 : if xtech = apa3 generate
    x0 : proasic3_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  proa3e : if xtech = apa3e generate
    x0 : proasic3e_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  proa3l : if xtech = apa3l generate
    x0 : proasic3l_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  fus : if xtech = actfus generate
    x0 : fusion_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  ihp : if xtech = ihp25 generate
    x0 : ihp25_syncram generic map(abits, dbits)
         port map(clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  ihprh : if xtech = ihp25rh generate
    x0 : ihp25rh_syncram generic map(abits, dbits)
         port map(clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  alt : if (xtech = altera) or (xtech = stratix1) or (xtech = stratix2) or
	(xtech = stratix3) or (xtech = stratix4) or (xtech = cyclone3) or
        (xtech = stratix5) generate
    x0 : altera_syncram generic map(abits, dbits)
         port map(clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  rht : if xtech = rhlib18t generate
    x0 : rh_lib18t_syncram generic map(abits, dbits)
         port map(clk, address, datain, dataoutx, xenable, xwrite, testin(TESTIN_WIDTH-3 downto TESTIN_WIDTH-4));
  end generate;

  lat : if xtech = lattice generate
    x0 : ec_syncram generic map(abits, dbits)
         port map(clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  ut025 : if xtech = ut25 generate
    x0 : ut025crh_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  ut09  : if xtech = ut90 generate
    x0 : ut90nhbd_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite, testin(TESTIN_WIDTH-3));
  end generate;

  ut13 : if xtech = ut130 generate
    x0 : ut130hbd_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  pere : if xtech = peregrine generate
    x0 : peregrine_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  arti : if xtech = memartisan generate
    x0 : artisan_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  cust1 : if xtech = custom1 generate
    x0 : custom1_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  ecl : if xtech = eclipse generate
    eclblk : block
      signal rena, wena : std_logic;
    begin
      rena <= xenable and not write;
      wena <= xenable and write;
      x0 : eclipse_syncram_2p generic map(abits, dbits)
        port map(clk, rena, address, dataoutx, clk, address,
                 datain, wena);
    end block eclblk;
  end generate;

  virage90 : if xtech = memvirage90 generate
    x0 : virage90_syncram generic map(abits, dbits)
      port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  nex : if xtech = easic90 generate
    x0 : nextreme_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  smic : if xtech = smic013 generate
    x0 : smic13_syncram generic map (abits, dbits)
         port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  tm65gplu  : if xtech = tm65gplus generate
    x0 : tm65gplus_syncram generic map (abits, dbits)
      port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  cmos9sfx  : if xtech = cmos9sf generate
    x0 : cmos9sf_syncram generic map (abits, dbits)
      port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  n2x  : if xtech = easic45 generate
    x0 : n2x_syncram generic map (abits, dbits)
      port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  rh13t : if xtech = rhlib13t generate
    x0 : rh_lib13t_syncram generic map(abits, dbits)
         port map(clk, address, datain, dataoutx, xenable, xwrite, testin(TESTIN_WIDTH-3 downto TESTIN_WIDTH-4));
  end generate;

  nanex : if xtech = nx generate
    x0 : nx_syncram generic map (abits, dbits)
      port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

  gf22x : if xtech = gf22 generate
    x0 : gf22fdx_syncram generic map (abits, dbits)
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

  rhs28x: if xtech=rhs28 generate
    x0: syncram_rhs28
      generic map (abits => abits, dbits => dbits, pipeline => pipeline)
      port map (
        clk => clk,
        address => address,
        datain => datain,
        dataout => dataoutx,
        enable => xenable,
        write => xwrite,
        initn => testin(TESTIN_WIDTH-3),
        testen => testin(TESTIN_WIDTH-1),
        scanen => testin(TESTIN_WIDTH-2)
        );
  end generate;

  nxs : if tech = nexus generate
    x0 : nexus_syncram generic map (abits, dbits)
      port map (clk, address, datain, dataoutx, xenable, xwrite);
  end generate;

-- pragma translate_off
  noram : if has_sram(xtech) = 0 generate
    x : process
    begin
      assert false report "syncram: technology " & tech_table(xtech) &
	" not supported"
      severity failure;
      wait;
    end process;
  end generate;
  dmsg : if GRLIB_CONFIG_ARRAY(grlib_debug_level) >= 2 generate
    x : process
    begin
      assert false report "syncram: " & tost(2**abits) & "x" & tost(dbits) &
       " (" & tech_table(tech) & ")"
      severity note;
      wait;
    end process;
  end generate;
  chk : if GRLIB_CONFIG_ARRAY(grlib_syncram_selftest_enable) /= 0 generate
    chkblk: block
      signal refdo: std_logic_vector(dbits-1 downto 0);
      signal pren: std_ulogic;
      signal paddr: std_logic_vector(abits-1 downto 0);
      signal refwrite: std_ulogic;
    begin
      refwrite <= write when gatedwr=0 else (write and enable);
      refram : generic_syncram generic map (abits, dbits)
        port map (clk, address, datain, refdo, refwrite);
      p: process(clk)
      begin
        if rising_edge(clk) then
          assert pren/='1' or refdo=dataoutx or is_x(refdo) or is_x(paddr)
            report "Read mismatch addr=" & tost(paddr) & " impl=" & tost(dataoutx) & " ref=" & tost(refdo)
            severity error;
          pren <= enable and not write;
          paddr <= address;
        end if;
      end process;
    end block;
  end generate;
-- pragma translate_on
end;

