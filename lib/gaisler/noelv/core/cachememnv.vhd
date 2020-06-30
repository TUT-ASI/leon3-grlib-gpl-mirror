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
-- Entity:      cachemem5
-- File:        cachemem5.vhd
-- Author:      Magnus Hjorth - Cobham Gaisler
-- Description: Memory instantiations for both instruction and data caches
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.noelvint.all;
library techmap;
use techmap.gencomp.all;

entity cachememnv is
  generic (
    tech      : integer range 0 to NTECH;
    iways     : integer range 1 to 4;
    ilinesize : integer range 4 to 8;
    iidxwidth : integer range 1 to 10;
    itagwidth : integer range 1 to 32;
    dways     : integer range 1 to 4;
    dlinesize : integer range 4 to 8;
--    dwaysize  : integer range 1 to 256;
    didxwidth : integer range 1 to 10;
    dtagwidth : integer range 1 to 32;
    dtagconf  : integer range 0 to 2;
    dusebw    : integer range 0 to 1;
    testen    : integer range 0 to 1
  );
  port (
        rstn   : in  std_ulogic;
        clk    : in  std_ulogic;
        sclk   : in  std_ulogic;
        crami  : in  nv_cram_in_type;
        cramo  : out nv_cram_out_type;
        testin : in std_logic_vector(TESTIN_WIDTH - 1 downto 0)
  );


end;

architecture rtl of cachememnv is

  signal idataaddr : std_logic_vector(iidxwidth + log2(ilinesize) - 2 downto 0);
  signal ddataaddr : std_logic_vector(didxwidth + log2(dlinesize) - 2 downto 0);

  signal gndv      : std_logic_vector(dtagwidth - 1 downto 0);

  type denv_type  is array(0 to 3) of std_logic_vector(7 downto 0);
  signal denv      : denv_type;
  signal dwrv      : denv_type;

  signal itagwrv   : std_logic_vector(0 to 3);
  type ienv_type  is array(0 to 3) of std_logic_vector(1 downto 0);
  signal idatawrv  : ienv_type;
  signal dtswrv    : std_logic_vector(0 to 3);
  signal dtcuwrv   : std_logic_vector(0 to 3);

begin

  gndv <= (others => '0');

  -- Instruction cache tag RAMs

  -- Some RAM techmaps (inferred) handle enable=0,write=1 as write
  itagwrv  <= crami.itagen when crami.itagwrite = '1' else "0000";
  idatawrv <= (0 => (crami.idatawrite and (crami.idataen(0) & crami.idataen(0))),
               1 => (crami.idatawrite and (crami.idataen(1) & crami.idataen(1))),
               2 => (crami.idatawrite and (crami.idataen(2) & crami.idataen(2))),
               3 => (crami.idatawrite and (crami.idataen(3) & crami.idataen(3))));

  itagloop: for s in 0 to iways-1 generate
    itagmem: syncram
      generic map (
        tech       => tech,
        abits      => iidxwidth,
        dbits      => itagwidth,
        testen     => testen,
        custombits => 1,
        pipeline   => 0,
        rdhold     => 1
        )
      port map (
        clk     => clk,
        address => crami.iindex(iidxwidth - 1 downto 0),
        datain  => crami.itagdin(s)(itagwidth - 1 downto 0),
        dataout => cramo.itagdout(s)(itagwidth - 1 downto 0),
        enable  => crami.itagen(s),
        write   => itagwrv(s),
        testin  => testin
        );

    cramo.itagdout(s)(TAGMAX - 1 downto itagwidth) <= (others => '0');
  end generate;

  -- Instruction cache data RAMs
  idataaddr <= crami.iindex(iidxwidth - 1 downto 0) & crami.idataoffs(log2(ilinesize) - 2 downto 0);
  idataloop: for s in 0 to iways-1 generate
    idatamemh: syncram
      generic map (
        tech       => tech,
        abits      => iidxwidth + log2(ilinesize) - 1,
        dbits      => 32,
        testen     => testen,
        custombits => 1,
        pipeline   => 0,
        rdhold     => 1
        )
      port map (
        clk     => clk,
        address => idataaddr,
        datain  => crami.idatadin(63 downto 32),
        dataout => cramo.idatadout(s)(63 downto 32),
        enable  => crami.idataen(s),
        write   => idatawrv(s)(1),
        testin  => testin
        );

    idatameml: syncram
      generic map (
        tech       => tech,
        abits      => iidxwidth + log2(ilinesize) - 1,
        dbits      => 32,
        testen     => testen,
        custombits => 1,
        pipeline   => 0,
        rdhold     => 1
        )
      port map (
        clk     => clk,
        address => idataaddr,
        datain  => crami.idatadin(31 downto 0),
        dataout => cramo.idatadout(s)(31 downto 0),
        enable  => crami.idataen(s),
        write   => idatawrv(s)(0),
        testin  => testin
        );
  end generate;

  -- Data cache tag RAMs
  -- Some RAM techmaps (inferred) handle enable=0,write=1 as write
  dtswrv  <= crami.dtagsen  when crami.dtagswrite  = '1' else "0000";
  dtcuwrv <= crami.dtagcuen when crami.dtagcuwrite = '1' else "0000";

  dtagconf0: if dtagconf = 0 generate
    -- two memories (1x two-port, 1x one-port), valid bits in two-port memory
    dtagloop: for s in 0 to dways-1 generate
      -- Tag read for regular cache operation
      dtagcmem: syncram_2p
        generic map (
          tech     => tech,
          abits    => didxwidth,
          dbits    => dtagwidth,
          sepclk   => 2,
          wrfst    => 1,
          testen   => testen,
          words    => 0,
          pipeline => 0,
          rdhold   => 1
          )
        port map (
          rclk     => clk,
          renable  => crami.dtagcen(s),
          raddress => crami.dtagcindex(didxwidth - 1 downto 0),
          dataout  => cramo.dtagcdout(s)(dtagwidth - 1 downto 0),
          wclk     => sclk,
          write    => crami.dtaguwrite(s),
          waddress => crami.dtaguindex(didxwidth - 1 downto 0),
          datain   => crami.dtagudin(s)(dtagwidth - 1 downto 0),
          testin   => testin
          );

      -- Tag read for snooping
      dtagsmem: syncram
        generic map (
          tech     => tech,
          abits    => didxwidth,
          dbits    => dtagwidth - 1,
          testen   => testen,
          pipeline => 0,
          rdhold   => 1
          )
        port map (
          clk     => sclk,
          address => crami.dtagsindex(didxwidth - 1 downto 0),
          datain  => crami.dtagsdin(s)(dtagwidth - 1 downto 1),
          dataout => cramo.dtagsdout(s)(dtagwidth - 1 downto 1),
          enable  => crami.dtagsen(s),
          write   => dtswrv(s),
          testin  => testin
          );

      cramo.dtagcdout(s)(TAGMAX - 1 downto dtagwidth) <= (others => '0');
      cramo.dtagsdout(s)(TAGMAX - 1 downto dtagwidth) <= (others => '0');
      cramo.dtagsdout(s)(0)                           <= '1';
    end generate;
  end generate;

  dtagconf1: if dtagconf = 1 generate
    -- 1 x dual-port memory, valid bits in flip flops
    dtagloop: for s in 0 to dways-1 generate
      dtagmem: syncram_dp
        generic map (
          tech     => tech,
          abits    => didxwidth,
          dbits    => dtagwidth - 1,
          testen   => testen,
          sepclk   => 2,
          wrfst    => 1,
          pipeline => 0,
          rdhold   => 1
          )
        port map (
          -- Port 1, read for cache operation
          clk1     => clk,
          address1 => crami.dtagcindex(didxwidth - 1 downto 0),
          datain1  => gndv(dtagwidth - 1 downto 1),
          dataout1 => cramo.dtagcdout(s)(dtagwidth - 1 downto 1),
          enable1  => crami.dtagcen(s),
          write1   => gndv(0),
          -- Port 2, write for cache update, read for snooping
          clk2     => sclk,
          address2 => crami.dtagsindex(didxwidth - 1 downto 0),
          datain2  => crami.dtagsdin(s)(dtagwidth - 1 downto 1),
          dataout2 => cramo.dtagsdout(s)(dtagwidth - 1 downto 1),
          enable2  => crami.dtagsen(s),
          write2   => dtswrv(s),
          --
          testin   => testin
          );

      cramo.dtagcdout(s)(TAGMAX - 1 downto dtagwidth) <= (others => '0');
      cramo.dtagsdout(s)(TAGMAX - 1 downto dtagwidth) <= (others => '0');
      cramo.dtagcdout(s)(0)                           <= '1';
      cramo.dtagsdout(s)(0)                           <= '1';
    end generate;
  end generate;

  dtagconf2: if dtagconf = 2 generate
    -- 2 x single-port memory, valid bits in flip flops
    dtagloop: for s in 0 to dways-1 generate
      -- Tag read for regular cache operation
      dtagcmem: syncram
        generic map (
          tech     => tech,
          abits    => didxwidth,
          dbits    => dtagwidth - 1,
          testen   => testen,
          pipeline => 0,
          rdhold   => 1
          )
        port map (
          clk     => clk,
          address => crami.dtagcuindex(didxwidth - 1 downto 0),
          datain  => crami.dtagudin(s)(dtagwidth - 1 downto 1),
          dataout => cramo.dtagcdout(s)(dtagwidth - 1 downto 1),
          enable  => crami.dtagcuen(s),
          write   => dtcuwrv(s),
          testin  => testin
          );

      -- Tag read for snooping
      dtagsmem: syncram
        generic map (
          tech     => tech,
          abits    => didxwidth,
          dbits    => dtagwidth - 1,
          testen   => testen,
          pipeline => 0,
          rdhold   => 1
          )
        port map (
          clk     => sclk,
          address => crami.dtagsindex(didxwidth - 1 downto 0),
          datain  => crami.dtagsdin(s)(dtagwidth - 1 downto 1),
          dataout => cramo.dtagsdout(s)(dtagwidth - 1 downto 1),
          enable  => crami.dtagsen(s),
          write   => crami.dtagswrite,
          testin  => testin
          );

      cramo.dtagcdout(s)(TAGMAX - 1 downto dtagwidth) <= (others => '0');
      cramo.dtagsdout(s)(TAGMAX - 1 downto dtagwidth) <= (others => '0');
      cramo.dtagcdout(s)(0)                           <= '1';
      cramo.dtagsdout(s)(0)                           <= '1';
    end generate;
  end generate;

  -- Data cache data RAMs
  ddataaddr <= crami.ddataindex(didxwidth - 1 downto 0) & crami.ddataoffs(log2(dlinesize) - 2 downto 0);
  denv      <= (0 => (others => crami.ddataen(0)),
                1 => (others => crami.ddataen(1)),
                2 => (others => crami.ddataen(2)),
                3 => (others => crami.ddataen(3)));
  -- Some RAM techmaps (inferred) handle enable=0,write=1 as write
  dwrv      <= (0 => denv(0) and crami.ddatawrite,
                1 => denv(1) and crami.ddatawrite,
                2 => denv(2) and crami.ddatawrite,
                3 => denv(3) and crami.ddatawrite);

  ddusebw: if dusebw = 1 generate
    -- Memories with byte writes
    ddataloop: for s in 0 to dways-1 generate
      ddatamemh: syncrambw
        generic map (
          tech     => tech,
          abits    => didxwidth + log2(dlinesize) - 1,
          dbits    => 32,
          testen   => testen,
          pipeline => 0,
          rdhold   => 1
          )
        port map (
          clk      => clk,
          address  => ddataaddr,
          datain   => crami.ddatadin(s)(63 downto 32),
          dataout  => cramo.ddatadout(s)(63 downto 32),
          enable   => denv(s)(7 downto 4),
          write    => dwrv(s)(7 downto 4),
          testin   => testin
          );

      ddatameml: syncrambw
        generic map (
          tech     => tech,
          abits    => didxwidth + log2(dlinesize) - 1,
          dbits    => 32,
          testen   => testen,
          pipeline => 0,
          rdhold   => 1
          )
        port map (
          clk      => clk,
          address  => ddataaddr,
          datain   => crami.ddatadin(s)(31 downto 0),
          dataout  => cramo.ddatadout(s)(31 downto 0),
          enable   => denv(s)(3 downto 0),
          write    => dwrv(s)(3 downto 0),
          testin   => testin
          );
    end generate;
  end generate;

  ddnobw: if dusebw = 0 generate
    -- Memories without byte writes, data loopback in cache controller
    ddataloop: for s in 0 to dways-1 generate
      ddatamemh: syncram
        generic map (
          tech     => tech,
          abits    => didxwidth + log2(dlinesize) - 1,
          dbits    => 32,
          testen   => testen,
          pipeline => 0,
          rdhold   => 1
          )
        port map (
          clk     => clk,
          address => ddataaddr,
          datain  => crami.ddatadin(s)(63 downto 32),
          dataout => cramo.ddatadout(s)(63 downto 32),
          enable  => crami.ddataen(s),
          write   => dwrv(s)(7),
          testin  => testin
          );

      ddatameml: syncram
        generic map (
          tech     => tech,
          abits    => didxwidth + log2(dlinesize) - 1,
          dbits    => 32,
          testen   => testen,
          pipeline => 0,
          rdhold   => 1
          )
        port map (
          clk     => clk,
          address => ddataaddr,
          datain  => crami.ddatadin(s)(31 downto 0),
          dataout => cramo.ddatadout(s)(31 downto 0),
          enable  => crami.ddataen(s),
          write   => dwrv(s)(3),
          testin  => testin
          );
    end generate;
  end generate;

  unusediloop: for s in iways to 3 generate
    cramo.itagdout(s)  <= (others => '0');
    cramo.idatadout(s) <= (others => '0');
  end generate;

  unuseddloop: for s in dways to 3 generate
    cramo.dtagcdout(s) <= (others => '0');
    cramo.dtagsdout(s) <= (others => '0');
    cramo.ddatadout(s) <= (others => '0');
  end generate;

end;
