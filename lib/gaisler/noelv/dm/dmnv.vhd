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
-----------------------------------------------------------------------------
-- Entity:      dmnv
-- File:        dmnv.vhd
-- Author:      Nils Wessman
-- Description: NOEL-V debug module
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.dmnvint.all;
use gaisler.l5nv_shared.all;
library techmap;
use techmap.gencomp.all;

entity dmnv is
  generic (
    fabtech   : integer;
    memtech   : integer;
    ncpu      : integer;
    ndbgmst   : integer;
    -- Conventional bus
    cbmidx    : integer;
    -- PnP
    dmhaddr   : integer;
    dmhmask   : integer;
    pnpaddrhi : integer;
    pnpaddrlo : integer;
    dmslvidx  : integer;
    dmmstidx  : integer;
    -- Program buffer
    pbslvidx  : integer;
    pbhaddr   : integer;
    pbhmask   : integer;
    -- trace
    tbits     : integer;
    itentr    : integer;
    tentr     : integer;
    --
    scantest  : integer;
    -- Pipelining
    plmdata   : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    tsc      : in  l5_tsc_async_type;
    -- Debug-link interface
    dbgmi    : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
    dbgmo    : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
    -- Conventional AHB bus interface
    cbmi    : in  ahb_mst_in_type;
    cbmo    : out ahb_mst_out_type;
    cbsi    : in  ahb_slv_in_type;
    pbsi    : in  ahb_slv_in_type;
    pbso    : out ahb_slv_out_type;
    -- 
    tpi    : in  nv_full_trace_vector(0 to NCPU-1);
    dbgi   : in  nv_debug_out_vector(0 to ncpu-1);
    dbgo   : out nv_debug_in_vector(0 to ncpu-1);
    dsui   : in  nv_dm_in_type;
    dsuo   : out nv_dm_out_type
    );
end;

architecture rtl of dmnv is
  constant ntrace : integer := 1
  ;

  signal dmmi : ahb_mst_in_type;
  signal dmmo : ahb_mst_out_type;
  signal dmsi : ahb_slv_in_type;
  signal dmso : ahb_slv_out_type;

  signal dmi  : dev_reg_in_type;
  signal dmo  : dev_reg_out_type;
  signal tri  : dev_reg_in_type;
  signal tro  : dev_reg_out_type;
  signal iti  : dev_reg_in_type;
  signal ito  : dev_reg_out_type;
  signal pbi  : dev_reg_in_type;
  signal pbo  : dev_reg_out_type;
  
  signal dbgmiv : ahb_mst_in_vector_type(ndbgmst downto 0);
  signal dbgmov : ahb_mst_out_vector_type(ndbgmst downto 0);
  signal extaddrs : ahb_mst_extaddr_vector(ndbgmst downto 0);

  signal cb_slvo : ahbstripe_slv_out_slice;
  signal cb_slvi : ahbstripe_slv_in_slice;


  signal it_di : itracebuf_in_type5_array(0 to ncpu-1);
  signal it_do : itracebuf_out_type5_array(0 to ncpu-1);
  signal reg_tracei : dmstr_trace_m2s_array_type(0 to ntrace-1);
  signal reg_traceo : dmstr_trace_s2m_array_type(0 to ntrace-1);

  signal ldsui   : nv_dm_in_type;
  signal hartsel : std_logic_vector(19 downto 0);

  -- Time Stamp
  signal timer     : std_logic_vector(62 downto 0);

begin

  -- Last master in debug subsystem bus (nbdgmst) is always
  -- the debug module (dmnv_ahbs)
  dbgmi <= dbgmiv(ndbgmst-1 downto 0);
  dbgmov(ndbgmst-1 downto 0) <= dbgmo;
  extaddrs(ndbgmst-1 downto 0) <= (others => (others => '0')); -- Bus width extended to 64 bits

  intercnct : dmnv_ic
    generic map (
      ndmamst   => ndbgmst+1,
      -- conv bus
      cbmidx    => cbmidx,
      -- PnP
      dmhaddr   => dmhaddr,
      dmhmask   => dmhmask,
      pnpaddrhi => pnpaddrhi,
      pnpaddrlo => pnpaddrlo,
      dmslvidx  => dmslvidx,
      dmmstidx  => dmmstidx
      -- pipelining 
      --, plmdata   => plmdata
    )
    port map(
      clk     => clk,
      rstn    => rstn,
      -- Debug-link interface
      dmami   => dbgmiv,
      dmamo   => dbgmov,
      extaddrs => extaddrs,
      -- Conventional AHB bus interface
      cbmi    => cbmi,
      cbmo    => cbmo,
      cbsi    => cbsi,
      -- Debug-module AHB bus interface
      dmmi    => dmmi,
      dmmo    => dmmo,
      dmpnp   => dmso.hconfig
    );

  con_dm : process(dmso, dmmo)
  begin
    dmmi        <= ahbm_in_none;
    dmmi.hgrant <= (others => '1');
    dmmi.hready <= dmso.hready;
    dmmi.hresp  <= dmso.hresp;
    dmmi.hrdata <= dmso.hrdata;

    dmsi          <= ahbs_in_none;
    dmsi.hsel(0) <= dmmo.htrans(1);
    dmsi.haddr    <= dmmo.haddr;
    dmsi.hwrite   <= dmmo.hwrite;
    dmsi.htrans   <= dmmo.htrans;
    dmsi.hsize    <= dmmo.hsize;
    dmsi.hburst   <= dmmo.hburst;
    dmsi.hwdata   <= dmmo.hwdata;
    dmsi.hready   <= dmso.hready;
  end process;

  ahbs_if : dmnv_ahbs
    generic map(
      hindex   => 0,
      hmindex  => ndbgmst,
      haddr    => dmhaddr,
      hmask    => dmhmask,
      ntrace   => ntrace
      )
    port map(
      clk     => clk,
      rstn    => rstn,
      ahbsi   => dmsi,
      ahbso   => dmso,
      ahbmi   => dbgmiv(ndbgmst),
      ahbmo   => dbgmov(ndbgmst),
      extaddrs => extaddrs(ndbgmst),
      -- DM interface
      dmi2    => dmi,
      dmo2    => dmo,
      -- Trace interface
      tri     => tri,
      tro     => tro,
      -- Striped traces master ports
      traceo  => reg_tracei,
      tracei  => reg_traceo,
      -- itrace buffer
      l5iti   => iti,
      l5ito   => ito);

  debug_module : entity work.dmnvx
    generic map(
      nharts          => ncpu,
      datacount       => 4,
      nscratch        => 2,
      unavailtimeout  => 64,
      progbufsize     => 8,
      scantest        => scantest
    )
    port map(
      clk    => clk,
      rstn   => rstn,
      dmi    => dmi,
      dmo    => dmo,
      pbi    => pbi,
      pbo    => pbo,
      dbgi   => dbgi,
      dbgo   => dbgo,
      dsui   => ldsui,
      dsuo   => dsuo,
      hartsel => hartsel
    );

  pb0 : entity work.progbuf_ahb
    generic map(
      hindex      => pbslvidx,
      haddr       => pbhaddr,
      hmask       => pbhmask,
      progbufsize => 8)
    port map(
      rstn        => rstn,
      clk         => clk,
      ahbi        => pbsi,
      ahbo        => pbso,
      pbi         => pbi,
      pbo         => pbo);
  

  ----------------------------------------------------------------------------
  -- Bus Trace Time Stamp sink
  ----------------------------------------------------------------------------
  btsink: l5tscsink
    generic map (
      tech      => fabtech,
      nsync     => 2,
      tbits     => 63
      )
    port map (
      clk       => clk,
      rstn      => rstn,
      tsc       => tsc,
      timer     => timer
      );

  atgen : if tentr /= 0 generate
    atrace0 : dmstr_trace
      generic map(
        memtech                 => memtech,
        buffer_depth            => tentr,
        striped_bus_data_width  => AHBDW,
        scantest                => scantest,
        dbg_master_trace_reset  => cbmidx
      )
      port map(
        clk               => clk,
        rstn              => rstn,
        timer             => timer,
        -- Register interface
        reg_slvi          => reg_tracei(ntrace-1),
        reg_slvo          => reg_traceo(ntrace-1),
        testin            => cbmi.testin,
        -- Striped bus to be traced
        sb_slvo           => cb_slvo,
        sb_slvi           => cb_slvi,
        sb_endian         => '1'
      );
      -- Convert regular AHB slaves into stripes.
      cb_slvi <= ahbsi_to_stripe(cbsi);
      cb_slvo.hready <= cbmi.hready;
      cb_slvo.hresp  <= cbmi.hresp;
      cb_slvo.hrdata <= hdata_sizeconv(cbmi.hrdata, 128);
      cb_slvo.hsplit <= (others => '0');
  
    
    gen_trac_wp : process(dsui, reg_traceo)
      variable vtrace_bp : std_logic;
    begin
      vtrace_bp := '0';
      ldsui     <= dsui;
      for i in reg_traceo'range loop
        vtrace_bp := vtrace_bp or reg_traceo(i).breakpoint_hit;
      end loop;
      ldsui.break <= dsui.break xor vtrace_bp;
    end process;
  end generate;
  no_atgen : if tentr = 0 generate
    ldsui <= dsui;
  end generate;

  itgen: if itentr /= 0 generate
    itc0: entity work.itctrlnv
      generic map (
        ncpu    => ncpu,
        entr    => itentr,
        scantest=> scantest
        )
      port map (
        clk     => clk,
        rstn    => rstn,
        tpi     => tpi,
        --tco     => tco_dd,
        --tcoack  => tcoack,
        iti     => iti,
        ito     => ito,
        d_i     => it_di,
        d_o     => it_do,
        hartsel => hartsel,
        rsten   => dsui.enable
        );
    mcpu: for i in 0 to NCPU-1 generate
      itmem0 : entity work.itbufmemnv
        generic map(
          tech     => memtech,
          entry    => itentr,
          testen   => scantest
          )
        port map(
          clk      => clk,
          d_i      => it_di(i),
          d_o      => it_do(i),
          testin   => cbmi.testin
          );
    end generate;
  end generate;

end;
