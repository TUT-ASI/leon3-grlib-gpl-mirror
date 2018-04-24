------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2018, Cobham Gaisler
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
--              AHB master on a full AHB system
------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--Currently do not support RETRY,SPLIT responses
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
    ahbmo_hburst : in  std_logic_vector(2 downto 0);  -- burst signals
    ahbmi_hready : out std_logic;
    ahbmi_hresp  : out std_logic_vector(1 downto 0);
    ahbmi_hrdata : out std_logic_vector(AHBDW-1 downto 0)
    );
end ahblitm2ahbm;


architecture rtl of ahblitm2ahbm is

  -- By default the device ID is set to AHB-AHB lite bridge
  -- However, different vendor and device IDs can be specified through generics
  constant hconfig : ahb_config_type := (
    0      => ahb_device_reg (venid, devid, 0, version, 0),
    others => (others => '0'));


  type state_type is (idle, init_latched, transaction);

  type reg_type is record
    htrans  : std_logic_vector(1 downto 0);
    haddr   : std_logic_vector(31 downto 0);
    hwrite  : std_ulogic;
    hsize   : std_logic_vector(2 downto 0);
    hburst  : std_logic_vector(2 downto 0);
    hprot   : std_logic_vector(3 downto 0);
    granted : std_logic;
    hready  : std_logic;
    state   : state_type;
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
    state   => idle);

  signal r, rin : reg_type;
  
begin  -- rtl


  comb : process(r, ahbmi, ahbmo_htrans, ahbmo_haddr, ahbmo_hwrite,
                 ahbmo_hsize, ahbmo_hwdata, ahbmo_hburst)
    variable v              : reg_type;
    variable bus_req        : std_logic;
    variable htrans_sample  : std_logic;
    variable ahbmi_hready_v : std_logic;
    variable ahbmo_htrans_v : std_logic_vector(1 downto 0);
    variable ahbmo_haddr_v  : std_logic_vector(31 downto 0);
    variable ahbmo_hwrite_v : std_logic;
    variable ahbmo_hsize_v  : std_logic_vector(2 downto 0);
    variable ahbmo_hburst_v : std_logic_vector(2 downto 0);
    variable ahbmo_hprot_v  : std_logic_vector(3 downto 0);
  begin
    bus_req       := '0';
    htrans_sample := '0';

    v := r;

    if ahbmi.hready = '1' then
      v.granted := ahbmi.hgrant(hindex);
    end if;

    case r.state is
      
      when idle =>

        v.hready := '1';

        if (ahbmo_htrans(1) = '1') then
          htrans_sample := '1';
          v.state       := init_latched;
          v.hready      := '0';
        end if;

      when init_latched =>

        bus_req  := '1';
        v.hready := '0';
        if r.granted = '1' and r.htrans(1) = '1' and ahbmi.hready = '1' then
          --first transaction is acknowledged
          v.state       := transaction;
          htrans_sample := '1';
        end if;

      when transaction =>

        bus_req := '1';

        if (ahbmo_htrans = HTRANS_IDLE) and (ahbmi.hready = '1') then
          v.state  := idle;
          v.hready := '1';
          bus_req  := '0';
          v.htrans := (others => '0');
        end if;

      when others => null;
    end case;

    if htrans_sample = '1' then
      v.htrans := ahbmo_htrans;
      v.haddr  := ahbmo_haddr;
      v.hwrite := ahbmo_hwrite;
      v.hsize  := ahbmo_hsize;
      v.hburst := ahbmo_hburst;
      --v.hprot := ahbmo_hprot;
      v.hprot  := (others => '0');
    end if;

    rin <= v;

    ahbmi_hready_v := r.hready;
    ahbmo_htrans_v := r.htrans;
    ahbmo_haddr_v  := r.haddr;
    ahbmo_hwrite_v := r.hwrite;
    ahbmo_hsize_v  := r.hsize;
    ahbmo_hburst_v := r.hburst;
    ahbmo_hprot_v  := r.hprot;
    if r.state = transaction then
      --transaction is granted 1-to-1 mapping from ahb-lite to AHB
      ahbmi_hready_v := ahbmi.hready;
      ahbmo_htrans_v := ahbmo_htrans;
      ahbmo_haddr_v  := ahbmo_haddr;
      ahbmo_hwrite_v := ahbmo_hwrite;
      ahbmo_hsize_v  := ahbmo_hsize;
      ahbmo_hburst_v := ahbmo_hburst;
      ahbmo_hprot_v  := (others => '0');
    end if;

    ahbmi_hready <= ahbmi_hready_v;
    ahbmo.htrans <= ahbmo_htrans_v;
    ahbmo.haddr  <= ahbmo_haddr_v;
    ahbmo.hwrite <= ahbmo_hwrite_v;
    ahbmo.hsize  <= ahbmo_hsize_v;
    ahbmo.hburst <= ahbmo_hburst_v;
    ahbmo.hprot  <= ahbmo_hprot_v;

    ahbmi_hresp  <= ahbmi.hresp;
    ahbmi_hrdata <= ahbmi.hrdata;

    ahbmo.hwdata  <= ahbmo_hwdata;
    ahbmo.hirq    <= (others => '0');
    ahbmo.hbusreq <= bus_req;
    ahbmo.hconfig <= hconfig;
    ahbmo.hindex  <= hindex;
    ahbmo.hlock   <= '0';               --MS added. No Locked accesses.

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
