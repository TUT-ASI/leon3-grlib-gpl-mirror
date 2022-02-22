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
-- Entity:      ahblitm2ahbm
-- File:        ahblitm2ahbm.vhd
-- Author:      Alen Bardizbanyan - Cobham Gaisler AB
-- Description: Adapter between AHB-Lite interface system and
--              an AHB master connected to ahbctrl
------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--Currently do not support WRAPPED accesses
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;

entity ahblitm2ahbm is
  generic(
    hindex    : integer := 0;
    venid     : integer := VENDOR_GAISLER;
    devid     : integer := GAISLER_AHBLM2AHB;
    version   : integer := 0);
  port(
    clk          : in  std_logic;
    rstn         : in  std_logic;
    ahbmi        : in  ahb_mst_in_type;
    ahbmo        : out ahb_mst_out_type;
    --ahblite ports
    ahbmo_htrans : in  std_logic_vector(1 downto 0);
    ahbmo_haddr  : in  std_logic_vector(31 downto 0);
    ahbmo_hwrite : in  std_logic;
    ahbmo_hsize  : in  std_logic_vector(2 downto 0);
    ahbmo_hwdata : in  std_logic_vector(AHBDW-1 downto 0);
    ahbmo_hburst : in  std_logic_vector(2 downto 0); 
    ahbmo_hprot  : in  std_logic_vector(3 downto 0);
    ahbmi_hready : out std_logic;
    ahbmi_hresp  : out std_logic;
    ahbmi_hrdata : out std_logic_vector(AHBDW-1 downto 0)
    );
end ahblitm2ahbm;


architecture rtl of ahblitm2ahbm is

  -- By default the device ID is set to AHB-AHB lite bridge
  -- However, different vendor and device IDs can be specified through generics
  constant hconfig : ahb_config_type := (
    0      => ahb_device_reg (venid, devid, 0, version, 0),
    others => (others => '0'));


  type state_type is (idle, init_latched, transaction, retsplit_idle);

  type reg_type is record
    htrans  : std_logic_vector(1 downto 0);
    haddr   : std_logic_vector(31 downto 0);
    hwrite  : std_ulogic;
    hsize   : std_logic_vector(2 downto 0);
    hburst  : std_logic_vector(2 downto 0);
    hprot   : std_logic_vector(3 downto 0);
    granted : std_logic;
    hready  : std_logic;
    hwdata  : std_logic_vector(AHBDW-1 downto 0);
    state   : state_type;
    hburst_mask : std_logic;
  end record;


  constant RES_T : reg_type := (
    htrans  => (others => '0'),
    haddr   => (others => '0'),
    hwrite  => '0',
    hsize   => (others => '0'),
    hburst  => (others => '0'),
    hprot   => (others => '0'),
    granted => '0',
    hready  => '1',
    state   => idle,
    hwdata  => (others => '0'),
    hburst_mask => '0');

  signal r, rin : reg_type;
  
begin  -- rtl


  comb : process(r, ahbmi, ahbmo_htrans, ahbmo_haddr, ahbmo_hwrite,
                 ahbmo_hsize, ahbmo_hwdata, ahbmo_hburst, ahbmo_hprot)
    variable v              : reg_type;
    variable bus_req        : std_logic;
    variable hburst_mask_release : std_logic;
    variable htrans_sample  : std_logic;
    variable ahbmi_hready_v : std_logic;
    variable ahbmo_htrans_v : std_logic_vector(1 downto 0);
    variable ahbmo_haddr_v  : std_logic_vector(31 downto 0);
    variable ahbmo_hwrite_v : std_logic;
    variable ahbmo_hsize_v  : std_logic_vector(2 downto 0);
    variable ahbmo_hburst_v : std_logic_vector(2 downto 0);
    variable ahbmo_hprot_v  : std_logic_vector(3 downto 0);
    variable ahbmo_hwdata_v : std_logic_vector(AHBDW-1 downto 0);
    variable ahbmi_hresp_v : std_logic;
  begin
    bus_req       := '0';
    htrans_sample := '0';
    hburst_mask_release := '1';
    ahbmi_hresp_v := '0';

    v := r;

    if ahbmi.hready = '1' then
      v.granted := ahbmi.hgrant(hindex);
    end if;

    case r.state is
      
      when idle =>

        v.hready := '1';
        v.hburst_mask := '0';

        if (ahbmo_htrans(1) = '1') then
          bus_req       := '1';
          htrans_sample := '1';
          v.state       := init_latched;
          v.hready      := '0';
          if r.granted = '1' and ahbmi.hready = '1' then
            v.state := transaction;
          end if;
        end if;

      when init_latched =>

        bus_req  := '1';
        v.hready := '0';
        if r.granted = '1' and r.htrans(1) = '1' and ahbmi.hready = '1' then
          --first transaction is acknowledged
          v.state       := transaction;
        end if;

      when transaction =>

        bus_req := '1';

        if ahbmo_htrans = HTRANS_IDLE then
          bus_req := '0';
        end if;
        
        if ahbmi.hready = '1' then
          htrans_sample := '1';
        end if;

        if r.granted = '0' and ahbmo_htrans /= HTRANS_IDLE and ahbmi.hready = '1' then
          --lost the grant can happen at the beginning of fixed length bursts (SINGLE,INCR4,INCR8,INC16)
          v.state := init_latched;
          v.hready := '0';
        end if;
        
        if (ahbmo_htrans = HTRANS_IDLE) and (ahbmi.hready = '1') then
          v.state := idle;
          v.hready := '1';
          v.htrans := HTRANS_IDLE;
          v.hwrite := '0';
        end if;

        if ahbmo_htrans = HTRANS_NONSEQ and r.hburst_mask = '1' then
          --hburst mask has to be released if a new burst is coming otherwise
          --b2b fixed burst can keep the bus blocked until htrans_idle is arrived
          v.hburst_mask := '0';
          hburst_mask_release := '1';
        end if;

        if (ahbmi.hresp = HRESP_RETRY or ahbmi.hresp = HRESP_SPLIT) and ahbmi.hready = '0' then
           v.htrans := HTRANS_IDLE;
           v.hready := '0';
           v.state  := retsplit_idle;
           if r.htrans = HTRANS_SEQ and r.hburst /= "000" and r.hburst /= "001" then
             --if RETRY or SPLIT arrives in the middle of a fixed length burst
             --it has to be converted to be an incremental burst
             v.hburst_mask := '1';
           end if;
        end if;

      when retsplit_idle =>

        bus_req := '1';
        v.state := init_latched;
        v.htrans := HTRANS_NONSEQ;
        v.hready := '0';
                
      when others => null;
    end case;

    if htrans_sample = '1' then
      v.htrans := ahbmo_htrans;
      v.haddr  := ahbmo_haddr;
      v.hwrite := ahbmo_hwrite;
      v.hsize  := ahbmo_hsize;
      v.hburst := ahbmo_hburst;
      v.hprot  := ahbmo_hprot;
    end if;

    rin <= v;
    
    ahbmi_hready_v := ahbmi.hready;
    ahbmo_htrans_v := ahbmo_htrans;
    ahbmo_haddr_v  := ahbmo_haddr;
    ahbmo_hwrite_v := ahbmo_hwrite;
    ahbmo_hsize_v  := ahbmo_hsize;
    ahbmo_hburst_v := ahbmo_hburst;
    ahbmo_hwdata_v := ahbmo_hwdata;
    ahbmo_hprot_v  := (others=>'0');
    
    if r.state = init_latched or r.state = retsplit_idle then
      ahbmo_htrans_v := r.htrans;
      ahbmo_haddr_v  := r.haddr;
      ahbmo_hwrite_v := r.hwrite;
      ahbmo_hsize_v  := r.hsize;
      ahbmo_hburst_v := r.hburst;
      ahbmo_hprot_v  := r.hprot;
    end if;

    if r.state = idle or r.state = init_latched or r.state = retsplit_idle then
      ahbmi_hready_v := r.hready;
    end if;

    if r.hburst_mask = '1' and hburst_mask_release = '0' then
      --force hburst to HBURST_INCR
      ahbmo_hburst_v := "001";
    end if;

    ahbmi_hresp_v := '0';
    if ahbmi.hresp = HRESP_ERROR then
      ahbmi_hresp_v := '1';
    end if;
              
    ahbmi_hready <= ahbmi_hready_v;
    ahbmo.htrans <= ahbmo_htrans_v;
    ahbmo.haddr  <= ahbmo_haddr_v;
    ahbmo.hwrite <= ahbmo_hwrite_v;
    ahbmo.hsize  <= ahbmo_hsize_v;
    ahbmo.hburst <= ahbmo_hburst_v;
    ahbmo.hprot  <= ahbmo_hprot_v;

    ahbmi_hresp  <= ahbmi_hresp_v;
    ahbmi_hrdata <= ahbmi.hrdata;

    ahbmo.hwdata  <= ahbmo_hwdata_v;
    ahbmo.hirq    <= (others => '0');
    ahbmo.hbusreq <= bus_req;
    ahbmo.hconfig <= hconfig;
    ahbmo.hindex  <= hindex;
    ahbmo.hlock   <= '0';          

  end process;

  
  seq : process (clk)
  begin
    
    if rising_edge(clk) then
      if rstn = '0' then
        r <= RES_T;
      else
        r <= rin;
      end if;
    end if;
    
  end process seq;

end rtl;
