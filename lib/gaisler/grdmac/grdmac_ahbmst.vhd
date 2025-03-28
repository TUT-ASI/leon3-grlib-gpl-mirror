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
-- Entity:      grdmac_ahbmst
-- File:        grdmac_ahbmst.vhd
-- Author:      Jiri Gaisler - Gaisler Research
-- Modified:    Andrea Gianarro - Aeroflex Gaisler AB
-- Description: Generic AHB master interface with enhanced burst support
------------------------------------------------------------------------------  

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.grdmac_pkg.all;

entity grdmac_ahbmst is
  generic (
    hindex  : integer := 0;
    hirq    : integer := 0;
    venid   : integer := VENDOR_GAISLER;
    devid   : integer := 0;
    version : integer := 0;
    chprot  : integer := 3;
    incaddr : integer := 0); 
   port (
      rst  : in  std_ulogic;
      clk  : in  std_ulogic;
      dmai : in grdmac_ahb_dma_in_type;
      dmao : out grdmac_ahb_dma_out_type;
      ahbi : in  ahb_mst_in_type;
      ahbo : out ahb_mst_out_type 
      );
end;      

architecture rtl of grdmac_ahbmst is

constant hconfig : ahb_config_type := (
  0 => ahb_device_reg ( venid, devid, 0, version, hirq),
  others => zero32);

type reg_type is record
  start   : std_ulogic;
  retry   : std_ulogic;
  grant   : std_ulogic;
  active  : std_ulogic;
end record;

constant RESET_ALL : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
constant RES : reg_type := ('0', '0', '0', '0');

signal r, rin : reg_type;

begin

  comb : process(ahbi, dmai, rst, r)
  variable v       : reg_type;
  variable ready   : std_ulogic;
  variable retry   : std_ulogic;
  variable mexc    : std_ulogic;
  variable inc     : std_logic_vector(5 downto 0);    -- address increment

  variable haddr   : std_logic_vector(31 downto 0);   -- AHB address
  variable hwdata  : std_logic_vector(AHBDW-1 downto 0);   -- AHB write data
  variable htrans  : std_logic_vector(1 downto 0);    -- transfer type
  variable hwrite  : std_ulogic;                      -- read/write
  variable hburst  : std_logic_vector(2 downto 0);    -- burst type
  variable newaddr : std_logic_vector(9 downto 0); -- next sequential address
  variable hbusreq : std_ulogic;   -- bus request
  variable hprot   : std_logic_vector(3 downto 0);    -- transfer type 
  variable xhirq    : std_logic_vector(NAHBIRQ-1 downto 0); 
  begin

    v := r; ready := '0'; mexc := '0'; retry := '0'; inc := (others => '0');
    hprot := conv_std_logic_vector(chprot, 4); -- non-cached supervisor data
    xhirq := (others => '0'); xhirq(hirq) := dmai.irq;

    haddr := dmai.address; hbusreq := dmai.start and not dmai.idle;
    hwdata := dmai.wdata;
    newaddr := dmai.address(9 downto 0);
 
    if INCADDR > 0 then
      inc(conv_integer(dmai.size)) := '1';
      newaddr := haddr(9 downto 0) + inc;
    end if;

    if dmai.burst = '0' then hburst := HBURST_SINGLE;
    else hburst := HBURST_INCR; end if;

    if dmai.start = '1' then
      if dmai.idle = '1' then
        htrans := HTRANS_IDLE;
      elsif(r.active and dmai.burst and not r.retry) = '1' then
        haddr(9 downto 0) := newaddr;
        if dmai.busy = '1' then htrans := HTRANS_BUSY;
        else
          if dmai.first_beat = '1' then htrans := HTRANS_NONSEQ;
          else htrans := HTRANS_SEQ; end if;
        end if;
        hburst := HBURST_INCR;
      else htrans := HTRANS_NONSEQ; end if;
    else htrans := HTRANS_IDLE; end if;

    if r.active = '1' then
      if ahbi.hready = '1' then
        case ahbi.hresp is
        when HRESP_OKAY => ready := '1';
        when HRESP_RETRY | HRESP_SPLIT=> retry := '1';
        when others => ready := '1'; mexc := '1';
        end case;
      end if;
      if ((ahbi.hresp = HRESP_RETRY) or (ahbi.hresp = HRESP_SPLIT)) then
        v.retry := not ahbi.hready;
      else v.retry := '0'; end if;
    end if;

    if r.retry = '1' then htrans := HTRANS_IDLE; end if;

    v.start := '0';
    if ahbi.hready = '1' then
      v.grant := ahbi.hgrant(hindex);
      if (htrans = HTRANS_NONSEQ) or (htrans = HTRANS_SEQ) or (htrans = HTRANS_BUSY) then
        v.active := r.grant; v.start := r.grant;
      else
        v.active := '0';
      end if;
    end if;

    if (not RESET_ALL) and (rst = '0') then
      v.retry := RES.retry; v.active := RES.active;
    end if;

    rin <= v;

    ahbo.haddr   <= haddr;
    ahbo.htrans  <= htrans;
    ahbo.hbusreq <= hbusreq;
    ahbo.hwdata  <= hwdata;
    ahbo.hconfig <= hconfig;
    ahbo.hlock   <= '0';
    ahbo.hwrite  <= dmai.write;
    ahbo.hsize   <= dmai.size;
    ahbo.hburst  <= hburst;
    ahbo.hprot   <= hprot;
    ahbo.hirq    <= xhirq;
    ahbo.hindex  <= hindex;

    dmao.start   <= r.start;
    dmao.active  <= r.active;
    dmao.ready   <= ready;
    dmao.mexc    <= mexc;
    dmao.retry   <= retry;
    dmao.haddr   <= newaddr;
    dmao.rdata   <= ahbi.hrdata;

  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if RESET_ALL and rst = '0' then
        r <= RES;
      end if;
    end if;
  end process;

end;

