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
-- Entity:      dmnv_ic_ebp
-- File:        dmnv_ic_ebp.vhd
-- Author:      Nils Wessman
-- Description: NOEL-V debug module: interconnect structure
--              Version with external dmnv_ic_busport instantiations
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.devices.all;
use grlib.stdlib.all;
use grlib.amba.all;
library gaisler;
use gaisler.l5nv_shared.all;

entity dmnv_ic_ebp is
  generic (
    ndmamst   : integer;
    -- conv bus
    cbmidx    : integer;
    -- PnP
    dmhaddr   : integer;
    dmhmask   : integer;
    pnpaddrhi : integer;
    pnpaddrlo : integer;
    dmslvidx  : integer;
    dmmstidx  : integer
    -- pipelining 
    --; plmdata   : integer
    );
  port (
    clk     : in  std_ulogic;
    rstn    : in  std_ulogic;
    -- Debug-link interface
    dmami   : out ahb_mst_in_vector_type(ndmamst-1 downto 0);
    dmamo   : in  ahb_mst_out_vector_type(ndmamst-1 downto 0);
    -- Conventional AHB bus interface
    cbmi    : in  ahb_mst_in_type;
    cbmo    : out ahb_mst_out_type;
    -- Debug-module AHB bus interface
    dmmi    : in  ahb_mst_in_type;
    dmmo    : out ahb_mst_out_type;
    -- Plug'n'play record for debug module (patched into PnP)
    dmpnp   : in  ahb_config_type
    );
end;

architecture rtl of dmnv_ic_ebp is
  
  constant nbus : integer := 1+1 -- conventional + debug-module
                             ;
  constant CONV : integer := nbus-2;
  constant DM   : integer := nbus-1;
  constant addrw : integer := 32* (1
                             ) 
                             ;

  constant onev: std_logic_vector(7 downto 0) := (others => '1');

  type xbstate is (xbidle, xbconn1, xbconn2, xbconn3, xbconn, xbdis1);

  type dm_ic_reg_type is record
    xbs      : xbstate;
    actmst   : std_logic_vector(log2x(ndmamst)-1 downto 0);
    actbus   : std_logic_vector(log2x(nbus)-1 downto 0);
    buspl    : dmnv_ic_bus_dma_type;
    bustodma : dmnv_ic_bus_dma_vector(0 to ndmamst-1);
    dmapl    : dmnv_ic_dma_bus_type;
    dmatobus : dmnv_ic_dma_bus_vector(0 to nbus-1);
  end record;
  constant RES : dm_ic_reg_type := (
    xbs      => xbidle,
    actmst   => (others => '0'),
    actbus   => (others => '0'),
    buspl    => dmnv_ic_bus_dma_none,
    bustodma => (others => dmnv_ic_bus_dma_none),
    dmapl    => dmnv_ic_dma_bus_none,
    dmatobus => (others => dmnv_ic_dma_bus_none)
    );

  function rrarb16(req: std_logic_vector(0 to 15);
                   lastarb: std_logic_vector(3 downto 0))
    return std_logic_vector is
    variable vmask: std_logic_vector(0 to 15);
    variable vreq1: std_logic_vector(0 to 15);
    variable vreq2: std_logic_vector(0 to 31);
    variable vres: std_logic_vector(3 downto 0);
  begin
    -- Create 2xlength mask of request vreq2 taking round-robin state
    --   into account. The master to select then be found based on
    --   the first bit set to 1 in the mask.
    case lastarb is
      when "0000" => vmask := "0111111111111111";
      when "0001" => vmask := "0011111111111111";
      when "0010" => vmask := "0001111111111111";
      when "0011" => vmask := "0000111111111111";
      when "0100" => vmask := "0000011111111111";
      when "0101" => vmask := "0000001111111111";
      when "0110" => vmask := "0000000111111111";
      when "0111" => vmask := "0000000011111111";
      when "1000" => vmask := "0000000001111111";
      when "1001" => vmask := "0000000000111111";
      when "1010" => vmask := "0000000000011111";
      when "1011" => vmask := "0000000000001111";
      when "1100" => vmask := "0000000000000111";
      when "1101" => vmask := "0000000000000011";
      when "1110" => vmask := "0000000000000001";
      when others => vmask := "1111111111111111";
    end case;
    vreq2 := (req and vmask) & req(0 to 15);
    -- Binary search approach to find the index of the first 1 in the mask
    if vreq2(0 to 15)="0000000000000000" then
      vreq2(0 to 15) := vreq2(16 to 31);
    end if;
    vres := "0000";
    if vreq2(0 to 7)="00000000" then
      vres(3) := '1';
      vreq2(0 to 7) := vreq2(8 to 15);
    end if;
    if vreq2(0 to 3)="0000" then
      vres(2) := '1';
      vreq2(0 to 3) := vreq2(4 to 7);
    end if;
    if vreq2(0 to 1)="00" then
      vres(1) := '1';
      vreq2(0 to 1) := vreq2(2 to 3);
    end if;
    if vreq2(0)='0' then
      vres(0) := '1';
    end if;
    return vres;
  end rrarb16;

  constant burstlen : integer := 16;

  signal r, ri  : dm_ic_reg_type;

  signal icdb_dma : dmnv_ic_dma_bus_vector(0 to ndmamst-1);
  signal icbd_bus : dmnv_ic_bus_dma_vector(0 to nbus-1);

  signal mstpnp : ahb_config_array(0 to ndmamst-1);
  signal slvpnp : ahb_config_array(0 to 0);

begin

  ----------------------------------------------------------------------------
  -- DMA port logic
  ----------------------------------------------------------------------------
  dmaloop: for x in 0 to ndmamst-1 generate
    dpx: dmnv_ic_dmaport
      generic map (
        dmhaddr => dmhaddr,
        dmhmask => dmhmask,
        burstlen => burstlen
        )
      port map (
        clk     => clk,
        rstn    => rstn,
        dmami   => dmami(x),
        dmamo   => dmamo(x),
        icdb    => icdb_dma(x),
        icbd    => r.bustodma(x)
        );
  end generate;

  ----------------------------------------------------------------------------
  -- Bus port logic
  ----------------------------------------------------------------------------
  -- Debug port
  bpd: dmnv_ic_busport
    generic map (
      busid     => DM,
      abits     => 32,
      dbits     => 32,
      vdbits    => AHBDW,
      burstlen  => 1,
      lowd      => 0
      )
    port map (
      clk     => clk,
      rstn    => rstn,
      endian  => dmmi.endian,
      hready  => dmmi.hready,
      hbusreq => dmmo.hbusreq,
      hgrant  => '1',
      htrans  => dmmo.htrans,
      haddr   => dmmo.haddr,
      hwrite  => dmmo.hwrite,
      hsize   => dmmo.hsize,
      hburst0 => dmmo.hburst(0),
      hresp   => dmmi.hresp,
      hwdata  => dmmo.hwdata,
      hrdata  => dmmi.hrdata,
      icdb    => r.dmatobus(DM),
      icbd    => icbd_bus(DM)
      );
  dmmo.hlock <= '0';
  dmmo.hburst(2 downto 1) <= "00";
  dmmo.hprot <= "0000";
  dmmo.hirq <= (others => '0');
  dmmo.hconfig(0) <= dmpnp(0);
  dmmo.hconfig(1 to dmmo.hconfig'high) <= (others => (others => '0'));
  dmmo.hindex <= 0;

  -- Conventional AHB bus port
  -- TODO: Support bursts with wider accesses
  bpc: dmnv_ic_busport
    generic map (
      busid    => CONV,
      abits    => 32,
      dbits    => 32,
      vdbits   => AHBDW,
      burstlen => burstlen,
      lowd     => (1-grlib.amba.CORE_ACDM),
      pnpgen   => 1,
      pnpaddrhi => pnpaddrhi,
      pnpaddrlo => pnpaddrlo,
      pnpmpos   => dmmstidx,
      pnpnmst   => ndmamst,
      pnpspos   => dmslvidx,
      pnpnslv   => 1
      )
    port map (
      clk      => clk,
      rstn     => rstn,
      endian   => cbmi.endian,
      hready   => cbmi.hready,
      hbusreq  => cbmo.hbusreq,
      hgrant   => cbmi.hgrant(cbmidx),
      htrans   => cbmo.htrans,
      haddr    => cbmo.haddr,
      hwrite   => cbmo.hwrite,
      hsize    => cbmo.hsize,
      hburst0  => cbmo.hburst(0),
      hresp    => cbmi.hresp,
      hwdata   => cbmo.hwdata,
      hrdata   => cbmi.hrdata,
      icdb     => r.dmatobus(CONV),
      icbd     => icbd_bus(CONV),
      mstpnp   => mstpnp,
      slvpnp   => slvpnp
      );
  cbmo.hlock <= '0';
  cbmo.hburst(2 downto 1) <= "00";
  cbmo.hprot <= "0000";
  cbmo.hirq <= (others => '0');
  cbmo.hconfig(0) <= dmpnp(0);
  cbmo.hconfig(1 to dmmo.hconfig'high) <= (others => (others => '0'));
  cbmo.hindex <= cbmidx;

  mpnpgen: for x in 0 to ndmamst-1 generate
    mstpnp(x) <= dmamo(x).hconfig;
  end generate;
  slvpnp(0) <= dmpnp;


  ----------------------------------------------------------------------------
  -- Interconnect logic
  ----------------------------------------------------------------------------
  comb : process(r, icdb_dma, icbd_bus)
    variable v        : dm_ic_reg_type;
    variable vreq     : std_logic_vector(0 to 15);
    variable la       : std_logic_vector(3 downto 0);
    variable arbout   : std_logic_vector(3 downto 0);
  begin
    v := r;

    vreq := (others => '0');
    for m in 0 to ndmamst-1 loop
      if icdb_dma(m).req /= dmnv_ic_dma_bus_none.req then
        vreq(m) := '1';
      end if;
    end loop;
    la := (others => '0');
    la(log2x(ndmamst)-1 downto 0) := r.actmst;
    arbout := rrarb16(vreq,la);

    for x in 0 to ndmamst-1 loop
      v.bustodma(x) := r.buspl;
      v.bustodma(x).gnt := dmnv_ic_bus_dma_none.gnt;
      if r.xbs /= xbconn then
        v.bustodma(x).gnt := '0';
        v.bustodma(x).rddv := '0';
      end if;
    end loop;
    v.bustodma(to_integer(unsigned(r.actmst))).gnt := r.buspl.gnt;
    if notx(r.actbus) then
      v.buspl := icbd_bus(to_integer(unsigned(r.actbus)));
    else
      setx(v.buspl.gnt);
      setx(v.buspl.rddv);
      setx(v.buspl.rdaddr);
      setx(v.buspl.rddata);
    end if;
    for x in 0 to nbus-1 loop
      v.dmatobus(x) := r.dmapl;
      if r.xbs /= xbconn then
        v.dmatobus(x).req := (others => '0');
        v.dmatobus(x).wrdv := '0';
      end if;
    end loop;
    if notx(r.actmst) then
      v.dmapl := icdb_dma(to_integer(unsigned(r.actmst)));
    else
      setx(v.dmapl.req);
      setx(v.dmapl.addr);
      setx(v.dmapl.wr);
      setx(v.dmapl.size);
      setx(v.dmapl.burst);
      setx(v.dmapl.wrdv);
      setx(v.dmapl.wraddr);
      setx(v.dmapl.wrdata);
    end if;
    case r.xbs is
      when xbidle =>
        if vreq /= (vreq'range => '0') then
          v.actmst := arbout(log2x(ndmamst)-1 downto 0);
          v.xbs := xbconn1;
        end if;
      when xbconn1 =>
        -- r.actmst valid, r.dmapl valid next cycle
        v.xbs := xbconn2;
      when xbconn2 =>
        -- r.dmapl valid, check request and set actbus
        v.actbus := (others => '0');
        for x in 0 to nbus-1 loop
          if r.dmapl.req(x)='1' then
            v.actbus := std_logic_vector(to_unsigned(x,v.actbus'length));
          end if;
        end loop;
        v.xbs := xbconn3;
      when xbconn3 =>
        -- r.actbus valid, r.buspl valid next cycle
        v.xbs := xbconn;
      when xbconn =>
        -- Forward grant/request and strobes in this state
        -- Wait for request to go low
        if r.dmapl.req(to_integer(unsigned(r.actbus)))='0' then
          v.xbs := xbdis1;
        end if;
      when xbdis1 =>
        -- Wait for grant from bus port to go low
        if r.buspl.gnt='0' then
          v.xbs := xbidle;
        end if;
    end case;

    ri <= v;
  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= ri;

      if rstn = '0' then
        r.xbs    <= RES.xbs;
        r.actmst <= RES.actmst;
        r.actbus <= RES.actbus;
      end if;
    end if;
  end process;
end;

