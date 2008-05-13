-----------------------------------------------------------------------------
--  LEON3 Demonstration design test bench
--  Copyright (C) 2004 Jiri Gaisler, Gaisler Research
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
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.sim.all;
library micron;
use micron.components.all;

use work.config.all;	-- configuration

entity testbench is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    clktech   : integer := CFG_CLKTECH;
    clkperiod : integer := 12;		-- system clock period
    ddrbits    : integer := 16;
    mobile     : integer := 2;
    debug      : integer := 0
  );
end; 

architecture behav of testbench is

constant sdramfile : string := "sdram.srec"; -- sdram contents

signal sys_clk : std_logic := '0';
signal sys_rst_in : std_logic := '0';			-- Reset
constant ct : integer := clkperiod/2;
constant freq : integer := 1000000/clkperiod;

signal ddr_clk    : std_logic;
signal ddr_clkb   : std_logic;
signal ddr_clk_fb : std_logic;
signal ddr_cke    : std_logic;
signal ddr_csb    : std_logic;
signal ddr_web    : std_ulogic;                       -- ddr write enable
signal ddr_rasb   : std_ulogic;                       -- ddr ras
signal ddr_casb   : std_ulogic;                       -- ddr cas
signal ddr_dm     : std_logic_vector (ddrbits/8-1 downto 0);    -- ddr dm
signal ddr_dqs    : std_logic_vector (ddrbits/8-1 downto 0);    -- ddr dqs
signal ddr_ad     : std_logic_vector (12 downto 0);   -- ddr address
signal ddr_ba     : std_logic_vector (1 downto 0);    -- ddr bank address
signal ddr_dq     : std_logic_vector (ddrbits-1 downto 0) := (others => 'H');   -- ddr data
signal ddr_dq2     : std_logic_vector (ddrbits-1 downto 0) := (others => 'H');   -- ddr data
signal sdclk      : std_ulogic;
signal sdcke      : std_logic_vector ( 1 downto 0);  -- clk en
signal sdcsn      : std_logic_vector ( 1 downto 0);  -- chip sel
signal sdwen      : std_ulogic;                      -- write en
signal sdrasn     : std_ulogic;                      -- row addr stb
signal sdcasn     : std_ulogic;                      -- col addr stb
signal sddqm      : std_logic_vector ( 7 downto 0);  -- data i/o mask
signal sa         : std_logic_vector(14 downto 0);
signal sd         : std_logic_vector(63 downto 0);

signal GND      : std_ulogic := '0';
signal VCC      : std_ulogic := '1';
begin

  -- clock and reset
  sys_clk <= not sys_clk after ct * 1 ns;
  sys_rst_in <= '0', '1' after 1100 ns;
  ddr_clk_fb <= ddr_clk;

  cpu : entity work.leon3mp
    generic map ( fabtech, memtech, padtech, ddrbits, mobile, freq)
    port map ( sys_rst_in, sys_clk, 
      ddr_clk, ddr_clkb, ddr_clk_fb, ddr_cke, ddr_csb, ddr_web, ddr_rasb, 
      ddr_casb, ddr_dm, ddr_dqs, ddr_ad, ddr_ba, ddr_dq, 
      sa, sd, sdclk, sdcke, sdcsn, sdwen, sdrasn, sdcasn, sddqm
    );

--  ddr2delay : entity work.delay_wire 
--    generic map(data_width => ddrbits, delay_atob => 0.0, delay_btoa => 0.0)
--    port map(a => ddr_dq(ddrbits-1 downto 0), b => ddr_dq2(ddrbits-1 downto 0));

mobile0 : if mobile >1 generate
  
  d16 : if ddrbits >= 16 generate
    u1 : mobile_ddr 
     generic map (bbits => ddrbits)
     PORT MAP(
       Dq => ddr_dq(15 downto 0), Dqs => ddr_dqs(1 downto 0), Addr => ddr_ad(12 downto 0),
       Ba => ddr_ba, Clk => ddr_clk,  Clk_n => ddr_clkb, Cke => ddr_cke,
       Cs_n => ddr_csb, Ras_n => ddr_rasb, Cas_n => ddr_casb, We_n => ddr_web,
       Dm => ddr_dm(1 downto 0));
  end generate;
  
  d32 : if ddrbits >= 32 generate
    u2 : mobile_ddr 
      generic map (bbits => ddrbits)
      PORT MAP(
        Dq => ddr_dq(31 downto 16), Dqs => ddr_dqs(3 downto 2), Addr => ddr_ad(12 downto 0),
        Ba => ddr_ba, Clk => ddr_clk,  Clk_n => ddr_clkb, Cke => ddr_cke,
        Cs_n => ddr_csb, Ras_n => ddr_rasb, Cas_n => ddr_casb, We_n => ddr_web,
        Dm => ddr_dm(3 downto 2));
  end generate;

  d64 : if ddrbits = 64 generate
    u3 : mobile_ddr 
      generic map (bbits => ddrbits)
      PORT MAP(
        Dq => ddr_dq(47 downto 32), Dqs => ddr_dqs(5 downto 4), Addr => ddr_ad(12 downto 0),
        Ba => ddr_ba, Clk => ddr_clk,  Clk_n => ddr_clkb, Cke => ddr_cke,
        Cs_n => ddr_csb, Ras_n => ddr_rasb, Cas_n => ddr_casb, We_n => ddr_web,
        Dm => ddr_dm(5 downto 4));
    u4 : mobile_ddr 
      generic map (bbits => ddrbits)
      PORT MAP(
        Dq => ddr_dq(63 downto 48), Dqs => ddr_dqs(7 downto 6), Addr => ddr_ad(12 downto 0),
        Ba => ddr_ba, Clk => ddr_clk,  Clk_n => ddr_clkb, Cke => ddr_cke,
        Cs_n => ddr_csb, Ras_n => ddr_rasb, Cas_n => ddr_casb, We_n => ddr_web,
        Dm => ddr_dm(7 downto 6));
  end generate;
end generate;

nomobile0 : if mobile <= 1 generate

  d16 : if ddrbits >= 16 generate
    u1 : mt46v16m16 
      generic map (index => 1, fname => sdramfile, bbits => 32)
      PORT MAP(
        Dq => ddr_dq(15 downto 0), Dqs => ddr_dqs(1 downto 0), Addr => ddr_ad(12 downto 0),
        Ba => ddr_ba, Clk => ddr_clk,  Clk_n => ddr_clkb, Cke => ddr_cke,
        Cs_n => ddr_csb, Ras_n => ddr_rasb, Cas_n => ddr_casb, We_n => ddr_web,
        Dm => ddr_dm(1 downto 0));
  end generate;

  d32 : if ddrbits >= 32 generate
    u2 : mt46v16m16 
      generic map (index => 0, fname => sdramfile, bbits => 32)
      PORT MAP(
        Dq => ddr_dq(31 downto 16), Dqs => ddr_dqs(3 downto 2), Addr => ddr_ad(12 downto 0),
        Ba => ddr_ba, Clk => ddr_clk,  Clk_n => ddr_clkb, Cke => ddr_cke,
        Cs_n => ddr_csb, Ras_n => ddr_rasb, Cas_n => ddr_casb, We_n => ddr_web,
        Dm => ddr_dm(3 downto 2));
  end generate;

  d64 : if ddrbits = 64 generate
    u3 : mt46v16m16 
      generic map (index => 1, fname => sdramfile, bbits => 32)
      PORT MAP(
        Dq => ddr_dq(47 downto 32), Dqs => ddr_dqs(5 downto 4), Addr => ddr_ad(12 downto 0),
        Ba => ddr_ba, Clk => ddr_clk,  Clk_n => ddr_clkb, Cke => ddr_cke,
        Cs_n => ddr_csb, Ras_n => ddr_rasb, Cas_n => ddr_casb, We_n => ddr_web,
        Dm => ddr_dm(5 downto 4));
    u4 : mt46v16m16 
      generic map (index => 0, fname => sdramfile, bbits => 32)
      PORT MAP(
        Dq => ddr_dq(63 downto 48), Dqs => ddr_dqs(7 downto 6), Addr => ddr_ad(12 downto 0),
        Ba => ddr_ba, Clk => ddr_clk,  Clk_n => ddr_clkb, Cke => ddr_cke,
        Cs_n => ddr_csb, Ras_n => ddr_rasb, Cas_n => ddr_casb, We_n => ddr_web,
        Dm => ddr_dm(7 downto 6));
  end generate;
end generate;

sd1 : if (CFG_SDCTRL = 1) generate
  mobileSD0 : if mobile >= 1 generate
    sd32 : if (CFG_SDCTRL_SD64 = 0) or (CFG_SDCTRL_SD64 = 1) generate
      u0: mobile_sdr generic map (DEBUG => debug)
      PORT MAP(
          Dq => sd(31 downto 16), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(0), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(3 downto 2));
      u1: mobile_sdr generic map (DEBUG => debug)
        PORT MAP(
          Dq => sd(15 downto 0), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(0), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(1 downto 0));
      u2: mobile_sdr generic map (DEBUG => debug)
        PORT MAP(
          Dq => sd(31 downto 16), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(1), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(3 downto 2));
      u3: mobile_sdr generic map (DEBUG => debug)
        PORT MAP(
          Dq => sd(15 downto 0), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(1), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(1 downto 0));
    end generate;
    sd64 : if (CFG_SDCTRL_SD64 = 1) generate
      u4: mobile_sdr generic map (DEBUG => debug)
        PORT MAP(
          Dq => sd(63 downto 48), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(0), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(7 downto 6));
      u5: mobile_sdr generic map (DEBUG => debug)
        PORT MAP(
          Dq => sd(47 downto 32), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(0), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(5 downto 4));
      u6: mobile_sdr generic map (DEBUG => debug)
        PORT MAP(
          Dq => sd(63 downto 48), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(1), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(7 downto 6));
      u7: mobile_sdr generic map (DEBUG => debug)
        PORT MAP(
          Dq => sd(47 downto 32), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(1), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(5 downto 4));
    end generate;
  end generate;
  
  nomobileSD0 : if mobile <= 1 generate
    sd32 : if (CFG_SDCTRL_SD64 = 0) or (CFG_SDCTRL_SD64 = 1) generate
      u0: mt48lc16m16a2 generic map (index => 0, fname => sdramfile)
        PORT MAP(
          Dq => sd(31 downto 16), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(0), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(3 downto 2));
      u1: mt48lc16m16a2 generic map (index => 16, fname => sdramfile)
        PORT MAP(
          Dq => sd(15 downto 0), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(0), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(1 downto 0));
      u2: mt48lc16m16a2 generic map (index => 0, fname => sdramfile)
        PORT MAP(
          Dq => sd(31 downto 16), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(1), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(3 downto 2));
      u3: mt48lc16m16a2 generic map (index => 16, fname => sdramfile)
        PORT MAP(
          Dq => sd(15 downto 0), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(1), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(1 downto 0));
    end generate;
    sd64 : if (CFG_SDCTRL_SD64 > 1) generate
      u4: mt48lc16m16a2 generic map (index => 0, fname => sdramfile)
        PORT MAP(
          Dq => sd(63 downto 48), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(0), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(7 downto 6));
      u5: mt48lc16m16a2 generic map (index => 16, fname => sdramfile)
        PORT MAP(
          Dq => sd(47 downto 32), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(0), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(5 downto 4));
      u6: mt48lc16m16a2 generic map (index => 0, fname => sdramfile)
        PORT MAP(
          Dq => sd(63 downto 48), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(1), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(7 downto 6));
      u7: mt48lc16m16a2 generic map (index => 16, fname => sdramfile)
        PORT MAP(
          Dq => sd(47 downto 32), Addr => sa(12 downto 0),
          Ba => sa(14 downto 13), Clk => sdclk, Cke => sdcke(0),
          Cs_n => sdcsn(1), Ras_n => sdrasn, Cas_n => sdcasn, We_n => sdwen,
          Dqm => sddqm(5 downto 4));
    end generate;
  end generate;
end generate;

  ddr_dq <= buskeep(ddr_dq), (others => 'H') after 250 ns;
  ddr_dqs <= buskeep(ddr_dqs), (others => 'L') after 250 ns;
  sd <= buskeep(sd), (others => 'H') after 250 ns;

end ;

