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
-- Entity: 	grethm
-- File:	grethm.vhd
-- Author:	Jiri Gaisler
-- Description:	Module to select between greth and greth1g
------------------------------------------------------------------------------
library ieee;
library grlib;
library gaisler; 
use ieee.std_logic_1164.all;
use grlib.stdlib.all;
use grlib.amba.all;
library techmap;
use techmap.gencomp.all;
use gaisler.net.all;

entity grethm is
  generic(
    hindex         : integer := 0;
    pindex         : integer := 0;
    paddr          : integer := 0;
    pmask          : integer := 16#FFF#;
    pirq           : integer := 0;
    memtech        : integer := 0;
    ifg_gap        : integer := 24; 
    attempt_limit  : integer := 16;
    backoff_limit  : integer := 10;
    slot_time      : integer := 128;
    mdcscaler      : integer range 0 to 255 := 25; 
    enable_mdio    : integer range 0 to 1 := 0;
    fifosize       : integer range 4 to 64 := 8;
    nsync          : integer range 1 to 2 := 2;
    edcl           : integer range 0 to 3 := 0;
    edclbufsz      : integer range 1 to 64 := 1;
    burstlength    : integer range 4 to 128 := 32;
    macaddrh       : integer := 16#00005E#;
    macaddrl       : integer := 16#000000#;
    ipaddrh        : integer := 16#c0a8#;
    ipaddrl        : integer := 16#0035#;
    phyrstadr      : integer range 0 to 32 := 0;
    rmii           : integer range 0 to 1 := 0;
    sim            : integer range 0 to 1 := 0;
    giga           : integer range 0 to 1  := 0;
    oepol          : integer range 0 to 1  := 0;
    scanen         : integer range 0 to 1  := 0;
    ft             : integer range 0 to 2  := 0;
    edclft         : integer range 0 to 2  := 0;
    mdint_pol      : integer range 0 to 1  := 0;
    enable_mdint   : integer range 0 to 1  := 0;
    multicast      : integer range 0 to 1  := 0;
    ramdebug       : integer range 0 to 2  := 0;
    mdiohold       : integer := 1;
    maxsize        : integer := 1500;
    rgmiimode      : integer range 0 to 1  := 0;
    gmiimode       : integer range 0 to 1  := 0;
    num_desc       : integer range 128 to 65536 := 128;
    timestamps     : integer range 0 to 1 := 0; -- Only for gbit
    external_mdio_ctrl : integer range 0 to 1 := 0 -- Only for gbit
    );
  port(
    rst            : in  std_ulogic;
    clk            : in  std_ulogic;
    ahbmi          : in  ahb_mst_in_type;
    ahbmo          : out ahb_mst_out_type;
    apbi           : in  apb_slv_in_type;
    apbo           : out apb_slv_out_type;
    ethi           : in  eth_in_type;
    etho           : out eth_out_type;
    -- Debug Interface
    debug_rx       : out std_logic_vector(63 downto 0);
    debug_tx       : out std_logic_vector(63 downto 0);
    debug_gtx      : out std_logic_vector(63 downto 0);
    -- Timestamping, only for GBIT
    timestamp      : in  std_logic_vector(63 downto 0) := (others => '0');
    -- External MDIO inputs, tie to 0 if external_mdio_ctrl = 0. Only for GBIT.
    phy_aneg_valid  : in  std_ulogic := '0';
    -- Index 0: 100, 1: gbit, 2: fduplex
    phy_aneg_result : in  std_logic_vector(2 downto 0) := (others => '0')
  );
end entity;

architecture rtl of grethm is
begin

  m100 : if giga = 0 generate
    u0 : greth
      generic map (
        hindex         => hindex,
        pindex         => pindex,
        paddr          => paddr,
        pmask          => pmask,
        pirq           => pirq,
        memtech        => memtech,
        ifg_gap        => ifg_gap,
        attempt_limit  => attempt_limit,
        backoff_limit  => backoff_limit,
        slot_time      => slot_time,
        mdcscaler      => mdcscaler,
        enable_mdio    => enable_mdio,
        fifosize       => fifosize,
        nsync          => nsync,
        edcl           => edcl,
        edclbufsz      => edclbufsz,
        macaddrh       => macaddrh,
        macaddrl       => macaddrl,
        ipaddrh        => ipaddrh,
        ipaddrl        => ipaddrl,
        phyrstadr      => phyrstadr,
        rmii           => rmii,
        oepol          => oepol,
        scanen         => scanen,
        ft             => ft,
        edclft         => edclft,
        mdint_pol      => mdint_pol,
        enable_mdint   => enable_mdint,
        multicast      => multicast,
        ramdebug       => ramdebug,
        mdiohold       => mdiohold,
        maxsize        => maxsize,
        gmiimode       => gmiimode,
        num_desc       => num_desc
        )
      port map (
        rst            => rst,
        clk            => clk,
        ahbmi          => ahbmi,
        ahbmo          => ahbmo,
        apbi           => apbi,
        apbo           => apbo,
        ethi           => ethi,
        etho           => etho
        );

        debug_rx <= (others => '0');
        debug_tx <= (others => '0');
        debug_gtx <= (others => '0');

  end generate;

  m1000 : if giga = 1 generate
    u0 : greth_gbit
      generic map (
        hindex         => hindex,
        pindex         => pindex,
        paddr          => paddr,
        pmask          => pmask,
        pirq           => pirq,
        memtech        => memtech,
        ifg_gap        => ifg_gap,
        attempt_limit  => attempt_limit,
        backoff_limit  => backoff_limit,
        slot_time      => slot_time,
        mdcscaler      => mdcscaler,
        nsync          => nsync,
        edcl           => edcl,
        edclbufsz      => edclbufsz,
        burstlength    => burstlength,
        macaddrh       => macaddrh,
        macaddrl       => macaddrl,
        ipaddrh        => ipaddrh,
        ipaddrl        => ipaddrl,
        phyrstadr      => phyrstadr,
        sim            => sim,
        oepol          => oepol,
        scanen         => scanen,
        ft             => ft,
        edclft         => edclft,
        mdint_pol      => mdint_pol,
        enable_mdint   => enable_mdint,
        multicast      => multicast,
        ramdebug       => ramdebug,
        mdiohold       => mdiohold,
        rgmiimode      => rgmiimode,
        gmiimode       => gmiimode,
        timestamps     => timestamps,
        external_mdio_ctrl => external_mdio_ctrl
        )
      port map (
        rst            => rst,
        clk            => clk,
        ahbmi          => ahbmi,
        ahbmo          => ahbmo,
        apbi           => apbi,
        apbo           => apbo,
        ethi           => ethi,
        etho           => etho
        , debug_rx    => debug_rx,
        debug_tx      => debug_tx,
        debug_gtx     => debug_gtx,
        timestamp     => timestamp,
        phy_aneg_valid  => phy_aneg_valid,
        phy_aneg_result => phy_aneg_result
        );
  end generate;

end architecture;

