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
-- Entity:      busif5
-- File:        bufis5.vhd
-- Author:      Magnus Hjorth, Frontgrade Gaisler
-- Description: AHB bus interface for LEON5 including store buffer and snoop
--              pipeline
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.l5nv_shared.all;
use gaisler.busif5_types.all;

entity busif5 is
  generic (
    hindex    : integer;
    device    : integer;
    version   : integer;
    ilinesize : integer range 4 to 8;
    dways     : integer range 1 to 4;
    dlinesize : integer range 4 to 8;
    dwaysize  : integer range 1 to 256;
    wbmask    : integer;
    busw      : integer
    );
  port (
    clk   : in  std_ulogic;
    rstn  : in  std_ulogic;
    ahbi  : in  ahb_mst_in_type;
    ahbo  : out ahb_mst_out_type;
    ahbsi : in  ahb_slv_in_type;
    bifi  : in  busif_in_type5;
    bifo  : out busif_out_type5;
    sni   : out snoopram_in_type5;
    sno   : in  snoopram_out_type5
    );
end;

architecture rtl of busif5 is

  function max(x,y: integer) return integer is
  begin
    if x>y then return x; else return y; end if;
  end max;

  function pick(b: boolean; tv,fv: integer) return integer is
  begin
    if b then return tv; else return fv; end if;
  end pick;

  constant maxlinesize: integer := max(dlinesize, ilinesize);

  -- If either wbmask=0 or busw=32, we have a 32-bit only system
  --  create modified constants xwbmask=0 and xbusw=32 for
  --  this case to make the code consistent.
  constant xwbmask : integer := pick(busw=32 or wbmask=0, 0,  wbmask);
  constant xbusw   : integer := pick(busw=32 or wbmask=0, 32, busw);
  -- Bus width to use in the read data logic, this is the same as
  -- xbusw above except in the special case of a wide bus with only
  -- narrow slaves but where AMBA compliant data muxing is enabled in
  -- the config package. For that case, we still need to pick the
  -- right 32-bit slice even though all accesses are 32-bit only.
  constant xdbusw: integer := pick((busw=32 or wbmask=0) and CORE_ACDM=0, 32, busw);

  -- ahb_hwdata register always 64 bit to handle pass-through case
  constant wdw : integer := max(xbusw, 64);

  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, device, 0, version, 0),
    others => zero32);

  signal ubufv : busif_rdbufu_array_type(0 to 0);

begin

  x0: busif5x
    generic map (
      hindex    => hindex,
      ilinesize => ilinesize,
      dways     => dways,
      dlinesize => dlinesize,
      dwaysize  => dwaysize,
      busw      => xbusw,
      rbusw     => xdbusw,
      sigbusw   => AHBDW,
      abitso    => 32,
      abitsi    => 32,
      sigaw     => 32,
      ibusw     => wdw,
      hburstw   => 3
      )
    port map (
      clk            => clk,
      rstn           => rstn,
      endian         => ahbi.endian,
      ahbi_hready    => ahbi.hready,
      ahbi_hgrant    => ahbi.hgrant(hindex),
      ahbi_hrdata    => ahbi.hrdata,
      ahbi_hresp     => ahbi.hresp,
      ahbo_hbusreq   => ahbo.hbusreq,
      ahbo_hlock     => ahbo.hlock,
      ahbo_htrans    => ahbo.htrans,
      ahbo_haddr     => ahbo.haddr,
      ahbo_hwrite    => ahbo.hwrite,
      ahbo_hsize     => ahbo.hsize,
      ahbo_hburst    => ahbo.hburst,
      ahbo_hprot     => ahbo.hprot,
      ahbo_hwdata    => ahbo.hwdata,
      ahbsi_htrans   => ahbsi.htrans,
      ahbsi_haddr    => ahbsi.haddr,
      ahbsi_hwrite   => ahbsi.hwrite,
      ahbsi_hsize    => ahbsi.hsize,
      ahbsi_hmaster  => ahbsi.hmaster,
      bifi_bifop     => bifi.bifop,
      bifi_busaddr   => bifi.busaddr(31 downto 0),
      bifi_widebus   => bifi.widebus,
      bifi_size      => bifi.size,
      bifi_stdata    => bifi.stdata,
      bifi_nosnoop   => bifi.nosnoop,
      bifi_su        => bifi.su,
      bifi_mmuacc    => bifi.mmuacc,
      bifi_maskwerr  => bifi.maskwerr,
      bifi_wcomb     => bifi.wcomb,
      bifi_dlfway    => bifi.dlfway,
      bifi_snoopen   => bifi.snoopen,
      bifi_lr_set    => bifi.lr_set,
      bifi_lr_clr    => bifi.lr_clr,
      --bifi_lr_addr   => bifi.lr_addr(31 downto 0),
      rdbufw         => ubufv(0).bufw,
      rdbufwd        => ubufv(0).bufwd,
      rdbufe         => ubufv(0).sete,
      nrddone        => ubufv(0).setdone,
      nrdstarted     => ubufv(0).setstarted,
      errclr         => ubufv(0).errclr,
      bifo_ready     => bifo.stat.ready,
      bifo_idle      => bifo.stat.idle,
      bifo_sterr     => bifo.stat.sterr,
      bifo_locked    => bifo.stat.locked,
      bifo_dtagupd   => bifo.dtu.upd,
      bifo_dtaguval  => bifo.dtu.uval,
      bifo_dtagumsb  => bifo.dtu.umsb,
      bifo_dtaguidx  => bifo.dtu.uidx,
      bifo_dtagutype => bifo.dtu.utype,
      bifo_lr_valid  => bifo.stat.lr_valid,
      dtagsindex     => sni.dtagsindex,
      dtagsen        => sni.dtagsen,
      dtagswrite     => sni.dtagswrite,
      dtagsdin       => sni.dtagsdin,
      dtagsdout      => sno.dtagsdout
      );

  rdb0: busif5rdb
    generic map (
      linesize => maxlinesize,
      wdwidth  => wdw,
      nports   => 1
      )
    port map (
      clk    => clk,
      clr    => bifi.clrrdbuf,
      ubuf   => ubufv,
      rbuf   => bifo.rdb
      );

  ahbo.hirq    <= (others => '0');
  ahbo.hconfig <= hconfig;
  ahbo.hindex  <= hindex;


end;
