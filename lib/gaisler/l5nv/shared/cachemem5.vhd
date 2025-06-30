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
-- Entity:      cachemem5
-- File:        cachemem5.vhd
-- Author:      Magnus Hjorth - Cobham Gaisler
-- Description: Memory instantiations for both instruction and data caches
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.l5nv_shared.all;
library techmap;
use techmap.gencomp.all;

entity cachemem5 is
  generic (
    hindex    : integer range 0 to 15;
    tech      : integer range 0 to NTECH;
    iways     : integer range 1 to 4;
    ilinesize : integer range 4 to 8;
    iidxwidth : integer range 1 to 10;
    itagwidth : integer range 1 to 32;
    itcmen    : integer range 0 to 1;
    itcmabits : integer range 1 to 20;
    itcmfrac  : integer range 0 to 7;
    dways     : integer range 1 to 4;
    dlinesize : integer range 4 to 8;
    didxwidth : integer range 1 to 10;
    dtagwidth : integer range 1 to 32;
    dtagconf  : integer range 0 to 2;
    mbmode    : integer range 0 to 1;
    dusebw    : integer range 0 to 1;
    dtcmen    : integer range 0 to 1;
    dtcmabits : integer range 1 to 20;
    dtcmfrac  : integer range 0 to 7;
    testen    : integer range 0 to 1
  );
  port (
    rstn  : in  std_ulogic;
    clk   : in  std_ulogic;
    sclk  : in  std_ulogic;
    crami : in  cram_in_type5;
    cramo : out cram_out_type5;
    sni   : in  snoopram_in_type5;
    sno   : out snoopram_out_type5;
    testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
    );


end;

architecture rtl of cachemem5 is

  signal idataaddr: std_logic_vector(iidxwidth+log2(ilinesize)-2 downto 0);
  signal ddataaddr: std_logic_vector(didxwidth+log2(dlinesize)-2 downto 0);

  signal gndv: std_logic_vector(dtagwidth-1 downto 0);

  type denv_type is array(0 to 3) of std_logic_vector(7 downto 0);
  signal denv: denv_type;
  signal denvtcm: std_logic_vector(7 downto 0);

  signal dloopb: std_logic_vector(63 downto 0);

  signal itcmoor: std_ulogic;
  signal dtcmoor: std_ulogic;


  function expand8(v: std_logic_vector) return std_logic_vector is
    variable vx: std_logic_vector(v'length-1 downto 0);
    variable b: std_logic_vector(7 downto 0);
    variable r: std_logic_vector(v'length*8-1 downto 0);
  begin
    vx := v;
    r := (others => '0');
    b := (others => '0');
    for x in vx'range loop
      b := (others => vx(x));
      r(x*8+7 downto x*8) := b;
    end loop;
    return r;
  end expand8;

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

begin

  gndv <= (others => '0');

  dloopb <= expand8(crami.ddataloop);

  -- Instruction cache tag RAMs

  itagloop: for s in 0 to iways-1 generate
    itagmem: syncram
      generic map (
        tech       => tech,
        abits      => iidxwidth,
        dbits      => itagwidth,
        testen     => testen,
        custombits => memtest_vlen,
        pipeline   => 0,
        rdhold     => 1,
        gatedwr    => 1
        )
      port map (
        clk     => clk,
        address => crami.iindex(iidxwidth-1 downto 0),
        datain  => crami.itagdin(s)(itagwidth-1 downto 0),
        dataout => cramo.itagdout(s)(itagwidth-1 downto 0),
        enable  => crami.itagen(s),
        write   => crami.itagwrite,
        testin  => testin
        );
    cramo.itagdout(s)(TAGMAX-1 downto itagwidth) <= (others => '0');
  end generate;

  -- Instruction cache data RAMs
  idataaddr <= crami.iindex(iidxwidth-1 downto 0) & crami.idataoffs(log2(ilinesize)-2 downto 0);
  idataloop: for s in 0 to iways-1 generate
    idatamemh: syncram
      generic map (
        tech       => tech,
        abits      => iidxwidth+log2(ilinesize)-1,
        dbits      => 32,
        testen     => testen,
        custombits => memtest_vlen,
        pipeline   => 0,
        rdhold     => 1,
        gatedwr    => 1
        )
      port map (
        clk     => clk,
        address => idataaddr,
        datain  => crami.idatadin(63 downto 32),
        dataout => cramo.idatadout(s)(63 downto 32),
        enable  => crami.idataen(s),
        write   => crami.idatawrite(1),
        testin  => testin
        );
    idatameml: syncram
      generic map (
        tech       => tech,
        abits      => iidxwidth+log2(ilinesize)-1,
        dbits      => 32,
        testen     => testen,
        custombits => memtest_vlen,
        pipeline   => 0,
        rdhold     => 1,
        gatedwr    => 1
        )
      port map (
        clk     => clk,
        address => idataaddr,
        datain  => crami.idatadin(31 downto 0),
        dataout => cramo.idatadout(s)(31 downto 0),
        enable  => crami.idataen(s),
        write   => crami.idatawrite(0),
        testin  => testin
        );
  end generate;

  -- Instruction cache tightly coupled memory
  itcm0: if itcmen /= 0 generate
    itcmmem: tcmwrap5
      generic map (
        tech       => tech,
        abits      => itcmabits,
        afrac      => itcmfrac,
        dbits      => 32,
        bw         => 0,
        testen     => testen,
        mtwidth    => 8,
        dloopen    => 1 -- for separate waddress support
        )
      port map (
        clk      => clk,
        address  => crami.ifulladdr(2+itcmabits downto 3),
        addressw => crami.ifulladdrw(2+itcmabits downto 3),
        datainh  => crami.itcmdin(63 downto 32),
        datainl  => crami.itcmdin(31 downto 0),
        dataouth => cramo.itcmdout(63 downto 32),
        dataoutl => cramo.itcmdout(31 downto 0),
        enable   => crami.itcmen,
        writeh   => crami.itcmwrite(1),
        writel   => crami.itcmwrite(0),
        oor      => itcmoor,
        testin   => testin
        );
  end generate;

  -- Data cache tag RAMs

  dtagconf0: if dtagconf=0 generate
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
          rdhold   => 1,
          custombits => memtest_vlen
          )
        port map (
          rclk     => clk,
          renable  => crami.dtagcen(s),
          raddress => crami.dtagcindex(didxwidth-1 downto 0),
          dataout  => cramo.dtagcdout(s)(dtagwidth-1 downto 0),
          wclk     => sclk,
          write    => crami.dtaguwrite(s),
          waddress => crami.dtaguindex(didxwidth-1 downto 0),
          datain   => crami.dtagudin(s)(dtagwidth-1 downto 0),
          testin   => testin
          );
    -- Tag read for snooping
      -- moved to snoopmem5
      cramo.dtagcdout(s)(TAGMAX-1 downto dtagwidth) <= (others => '0');
      sno.dtagsdout(s) <= (others => '0');
    end generate;
  end generate;
  dtagconf1: if dtagconf=1 and mbmode=0 generate
    -- 1 x dual-port memory, valid bits in flip flops
    dtagloop: for s in 0 to dways-1 generate
      dtagmem: syncram_dp
        generic map (
          tech     => tech,
          abits    => didxwidth,
          dbits    => dtagwidth-1,
          testen   => testen,
          sepclk   => 2,
          wrfst    => 1,
          pipeline => 0,
          rdhold   => 1,
          gatedwr  => 1,
          custombits => memtest_vlen
          )
        port map (
          -- Port 1, read for cache operation
          clk1     => clk,
          address1 => crami.dtagcindex(didxwidth-1 downto 0),
          datain1  => gndv(dtagwidth-1 downto 1),
          dataout1 => cramo.dtagcdout(s)(dtagwidth-1 downto 1),
          enable1  => crami.dtagcen(s),
          write1   => gndv(0),
          -- Port 2, write for cache update, read for snooping
          clk2     => sclk,
          address2 => sni.dtagsindex(didxwidth-1 downto 0),
          datain2  => sni.dtagsdin(s)(dtagwidth-1 downto 1),
          dataout2 => sno.dtagsdout(s)(dtagwidth-1 downto 1),
          enable2  => sni.dtagsen(s),
          write2   => sni.dtagswrite,
          --
          testin   => testin
          );
      cramo.dtagcdout(s)(TAGMAX-1 downto dtagwidth) <= (others => '0');
      sno.dtagsdout(s)(TAGMAX-1 downto dtagwidth) <= (others => '0');
      cramo.dtagcdout(s)(0) <= '1';
      sno.dtagsdout(s)(0) <= '1';
    end generate;
  end generate;
  dtagconf1mb: if dtagconf=1 and mbmode=1 generate
    -- 1 x dual-port memory, valid bits in flip flops
    --
    -- For use with advanced subssystem.
    -- Because we have potentially cacheable areas on the conventional bus,
    -- we can not let the snoop side do the cache update but have to let the
    -- cache-side port do the writing via the combined cache/update signals

    -- TODO: We don't really need write-first emulation here, it would be enough
    --   giving a flag to the reader (the snoop pipeline) that a collision happened.
    --   This would only happen when we are snooping on a tag that are just in the
    --   middle of fetching so can't be a snoop hit in that state.

    dtagloop: for s in 0 to dways-1 generate
      dtagmem: syncram_dp
        generic map (
          tech     => tech,
          abits    => didxwidth,
          dbits    => dtagwidth-1,
          testen   => testen,
          sepclk   => 2,
          wrfst    => 1,
          pipeline => 0,
          rdhold   => 1,
          gatedwr  => 1,
          custombits => memtest_vlen
          )
        port map (
          -- Port 1, read for cache operation, write for cache update
          clk1     => clk,
          address1 => crami.dtagcuindex(didxwidth-1 downto 0),
          datain1  => crami.dtagudin(s)(dtagwidth-1 downto 1),
          dataout1 => cramo.dtagcdout(s)(dtagwidth-1 downto 1),
          enable1  => crami.dtagcuen(s),
          write1   => crami.dtagcuwrite,
          -- Port 2, read for snooping, stripe #0
          clk2     => sclk,
          address2 => sni.dtagsindex(didxwidth-1 downto 0),
          datain2  => gndv(dtagwidth-1 downto 1),
          dataout2 => sno.dtagsdout(s)(dtagwidth-1 downto 1),
          enable2  => sni.dtagsen(s),
          write2   => gndv(0),
          --
          testin   => testin
          );
      cramo.dtagcdout(s)(TAGMAX-1 downto dtagwidth) <= (others => '0');
      sno.dtagsdout(s)(TAGMAX-1 downto dtagwidth) <= (others => '0');
      cramo.dtagcdout(s)(0) <= '1';
      sno.dtagsdout(s)(0) <= '1';
    end generate;
  end generate;
  dtagconf2: if dtagconf=2 generate
    -- 2 x single-port memory, valid bits in flip flops
    dtagloop: for s in 0 to dways-1 generate
      -- Tag read for regular cache operation
      dtagcmem: syncram
        generic map (
          tech     => tech,
          abits    => didxwidth,
          dbits    => dtagwidth-1,
          testen   => testen,
          pipeline => 0,
          rdhold   => 1,
          gatedwr  => 1,
          custombits => memtest_vlen
          )
        port map (
          clk      => clk,
          address  => crami.dtagcuindex(didxwidth-1 downto 0),
          datain   => crami.dtagudin(s)(dtagwidth-1 downto 1),
          dataout  => cramo.dtagcdout(s)(dtagwidth-1 downto 1),
          enable   => crami.dtagcuen(s),
          write    => crami.dtagcuwrite,
          testin   => testin
          );
    -- Tag read for snooping
      -- moved to snoopram5
      cramo.dtagcdout(s)(TAGMAX-1 downto dtagwidth) <= (others => '0');
      cramo.dtagcdout(s)(0) <= '1';
      sno.dtagsdout(s) <= (others => '0');
    end generate;
  end generate;

  -- Data cache data RAMs
  ddataaddr <= crami.ddataindex(didxwidth-1 downto 0) & crami.ddataoffs(log2(dlinesize)-2 downto 0);
  denv <= (0 => (others => crami.ddataen(0)),
           1 => (others => crami.ddataen(1)),
           2 => (others => crami.ddataen(2)),
           3 => (others => crami.ddataen(3)));
  denvtcm <= (others => crami.dtcmen);
  ddusebw: if dusebw=1 generate
    -- Memories with byte writes
    ddataloop: for s in 0 to dways-1 generate
      ddatamemh: syncrambw
        generic map (
          tech => tech,
          abits => didxwidth+log2(dlinesize)-1,
          dbits => 32,
          testen => testen,
          pipeline => 0,
          rdhold => 1,
          gatedwr => 1,
          custombits => memtest_vlen
          )
        port map (
          clk => clk,
          address => ddataaddr,
          datain => crami.ddatadin(s)(63 downto 32),
          dataout => cramo.ddatadout(s)(63 downto 32),
          enable => denv(s)(7 downto 4),
          write => crami.ddatawrite(7 downto 4),
          testin => testin
          );
      ddatameml: syncrambw
        generic map (
          tech => tech,
          abits => didxwidth+log2(dlinesize)-1,
          dbits => 32,
          testen => testen,
          pipeline => 0,
          rdhold => 1,
          gatedwr => 1,
          custombits => memtest_vlen
          )
        port map (
          clk => clk,
          address => ddataaddr,
          datain => crami.ddatadin(s)(31 downto 0),
          dataout => cramo.ddatadout(s)(31 downto 0),
          enable => denv(s)(3 downto 0),
          write => crami.ddatawrite(3 downto 0),
          testin => testin
          );
    end generate;
  end generate;
  ddnobw: if dusebw=0 generate
    -- Memories without byte writes, data loopback in syncram wrapper
    ddataloop: for s in 0 to dways-1 generate
      ddatamemh: syncramlb
        generic map (
          tech => tech,
          abits => didxwidth+log2(dlinesize)-1,
          dbits => 32,
          testen => testen,
          rdhold => 1,
          gatedwr => 1,
          custombits => memtest_vlen
          )
        port map (
          clk => clk,
          address => ddataaddr,
          addressw => ddataaddr,
          datain => crami.ddatadin(s)(63 downto 32),
          dataout => cramo.ddatadout(s)(63 downto 32),
          dataloop => dloopb(63 downto 32),
          enable => crami.ddataen(s),
          write => crami.ddatawrite(7),
          testin => testin
          );
      ddatameml: syncramlb
        generic map (
          tech => tech,
          abits => didxwidth+log2(dlinesize)-1,
          dbits => 32,
          testen => testen,
          rdhold => 1,
          gatedwr => 1,
          custombits => memtest_vlen
          )
        port map (
          clk => clk,
          address => ddataaddr,
          addressw => ddataaddr,
          datain => crami.ddatadin(s)(31 downto 0),
          dataout => cramo.ddatadout(s)(31 downto 0),
          dataloop => dloopb(31 downto 0),
          enable => crami.ddataen(s),
          write => crami.ddatawrite(3),
          testin => testin
          );
    end generate;
  end generate;

  -- Data cache tightly coupled memory
  dtcm0 : if dtcmen /= 0 generate
    dtcmmem: tcmwrap5
      generic map (
        tech => tech,
        abits => dtcmabits,
        afrac => dtcmfrac,
        dbits => 32,
        bw    => dusebw,
        dloopen => (1-dusebw),
        testen => testen,
        mtwidth => 32
        )
      port map (
        clk => clk,
        address  => crami.ddatafulladdr(2+dtcmabits downto 3),
        addressw => crami.ddatafulladdrw(2+dtcmabits downto 3),
        datainh  => crami.dtcmdin(63 downto 32),
        datainl  => crami.dtcmdin(31 downto 0),
        dataouth => cramo.dtcmdout(63 downto 32),
        dataoutl => cramo.dtcmdout(31 downto 0),
        enable   => crami.dtcmen,
        writeh   => crami.dtcmwrite(7),
        writel   => crami.dtcmwrite(3),
        writebw  => crami.dtcmwrite,
        dataloop => crami.ddataloop,
        oor      => dtcmoor,
        testin   => testin
        );
  end generate;


  unusediloop: for s in iways to 3 generate
    cramo.itagdout(s) <= (others => '0');
    cramo.idatadout(s) <= (others => '0');
  end generate;
  unuseddloop: for s in dways to 3 generate
    cramo.dtagcdout(s) <= (others => '0');
    sno.dtagsdout(s) <= (others => '0');
    cramo.ddatadout(s) <= (others => '0');
  end generate;

  noitcm: if itcmen=0 generate
    cramo.itcmdout <= (others => '0');
    itcmoor <= '0';
  end generate;

  nodtcm: if dtcmen=0 generate
    cramo.dtcmdout <= (others => '0');
    dtcmoor <= '0';
  end generate;

--pragma translate_off
  tagmon: process(sclk)
    subtype itag_type is std_logic_vector(itagwidth-1 downto 0);
    type itagset_type is array(0 to iways-1) of itag_type;
    type itags_type is array(0 to 2**iidxwidth-1) of itagset_type;
    variable itags: itags_type;
    subtype dctag_type is std_logic_vector(dtagwidth-1 downto 0);
    subtype dstag_type is std_logic_vector(dtagwidth-1 downto 1);
    type dctagset_type is array(0 to iways-1) of dctag_type;
    type dstagset_type is array(0 to iways-1) of dstag_type;
    type dctags_type is array(0 to 2**iidxwidth-1) of dctagset_type;
    type dstags_type is array(0 to 2**iidxwidth-1) of dstagset_type;
    variable dctags: dctags_type;
    variable dstags: dstags_type;
    variable idx, cidx: integer;
    variable tagupd: boolean;
    type boolarr is array(natural range <>) of boolean;
    variable ctagupd: boolarr(0 to DWAYS-1);
  begin
    if rising_edge(sclk) then
      tagupd := false;
      for w in 0 to IWAYS-1 loop
        if crami.itagen(w)='1' and crami.itagwrite='1' then
          idx := to_integer(unsigned(crami.iindex(iidxwidth-1 downto 0)));
          if notx(itags(idx)(w)) then tagupd := true; end if;
          itags(idx)(w) := crami.itagdin(w)(itagwidth-1 downto 0);
          assert notx(crami.itagdin(w)) report "Writing X into Itag!" severity failure;
        end if;
      end loop;
      if tagupd then
        for w1 in 0 to IWAYS-2 loop
          for w2 in w1+1 to IWAYS-1 loop
            assert itags(idx)(w1)(itagwidth-1 downto 1) /= itags(idx)(w2)(itagwidth-1 downto 1)
              report "Duplicated Itag written" severity failure;
          end loop;
        end loop;
      end if;
      tagupd := false;
      ctagupd := (others => false);
      for w in 0 to DWAYS-1 loop
        if dtagconf=0 and crami.dtaguwrite(w)='1' then
          cidx := to_integer(unsigned(crami.dtaguindex(didxwidth-1 downto 0)));
          if notx(dctags(cidx)(w)) then
            tagupd := true;
            ctagupd(w) := true;
          end if;
          dctags(cidx)(w) := crami.dtagudin(w)(dtagwidth-1 downto 0);
          assert notx(crami.dtagudin(w)) report "Writing X into Dtag!" severity failure;
        end if;
        if dtagconf /= 0 and crami.dtagcuen(w)='1' and crami.dtagcuwrite='1' then
          cidx := to_integer(unsigned(crami.dtagcuindex(didxwidth-1 downto 0)));
          if notx(dctags(cidx)(w)) then
            tagupd := true;
            ctagupd(w) := true;
          end if;
          dctags(cidx)(w) := crami.dtagudin(w)(dtagwidth-1 downto 0);
          assert notx(crami.dtagudin(w)) report "Writing X into Dtag!" severity failure;
        end if;
        if sni.dtagsen(w)='1' and sni.dtagswrite='1' then
          idx := to_integer(unsigned(sni.dtagsindex(didxwidth-1 downto 0)));
          if notx(dstags(idx)(w)) then
            tagupd := true;
          end if;
          dstags(idx)(w) := sni.dtagsdin(w)(dtagwidth-1 downto 1);
          assert notx(sni.dtagsdin(w)) report "Writing X into Dstag!" severity failure;
        end if;
      end loop;
      if tagupd then
        for w1 in 0 to DWAYS-2 loop
          for w2 in w1+1 to DWAYS-1 loop
            -- NW FIXME: should this be cidx
            --assert dctags(idx)(w1)(dtagwidth-1 downto 1) /= dctags(idx)(w2)(dtagwidth-1 downto 1)
            assert dctags(cidx)(w1)(dtagwidth-1 downto 1) /= dctags(cidx)(w2)(dtagwidth-1 downto 1)
              report "Duplicated dtag written" severity failure;
            assert 
              dstags(idx)(w1)(dtagwidth-1 downto 1) /= dstags(idx)(w2)(dtagwidth-1 downto 1)
              or (dtagconf=0 and (dctags(idx)(w1)(0)='0' or dctags(idx)(w2)(0)='0'))
              report "Duplicated snoop-dtag written" severity failure;
          end loop;
        end loop;
        for w in 0 to DWAYS-1 loop
          if ctagupd(w) and mbmode=0 then
            assert dctags(cidx)(w)(dtagwidth-1 downto 1)=dstags(cidx)(w) or dctags(cidx)(w)(0)='0'
              report "Snoop and regular tag mismatch" severity failure;
          end if;
        end loop;
      end if;
    end if;
  end process;
--pragma translate_on
end;
