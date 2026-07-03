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
-------------------------------------------------------------------------------
-- Entity:      dbgmst_ahb
-- File:        dbgmst_ahb.vhd
-- Author:      Axel Karlsson - Frontgrade Gaisler AB
--
-- Description: Debug block which exposes an generic_bm_ahb to an APB interface
-- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
use grlib.generic_bm_pkg.all;
library gaisler;
use gaisler.misc.all;

entity dbgmst_ahb is
  generic (
    dw         : integer range 32 to 128  := 32;  --bus master data width
    max_size   : integer range 32 to 256  := 256;
    pindex     : integer;
    paddr      : integer;
    pmask      : integer;
    hmindex    : integer
    );
  port (
    rstn    : in  std_ulogic;
    clk     : in  std_ulogic;
    apbsi   : in  apb_slv_in_type;
    apbso   : out apb_slv_out_type;
    ahbmi   : in  ahb_mst_in_type;
    ahbmo   : out ahb_mst_out_type;
    extaddr : out std_logic_vector(31 downto 0)
  );
end dbgmst_ahb;

architecture rtl of dbgmst_ahb is
  
  constant REVISION : integer := 0;
  
  constant hconfig : ahb_config_type := (
    0      => ahb_device_reg (VENDOR_GAISLER, GAISLER_DBGMST, 0, 0, 0),
    others => zero32);
  
  signal hwdata : std_logic_vector(dw - 1 downto 0);
  signal hrdata : std_logic_vector(dw - 1 downto 0);
    
  signal exe  : std_ulogic;
  signal priv : std_ulogic;
  
  
  signal bmsti : ahb_bmst_in_type;
  signal bmsto : ahb_bmst_out_type;

  signal bmrd_addr        :  std_logic_vector(31 downto 0);
  signal bmrd_size        :  std_logic_vector(log2(max_size)-1 downto 0);
  signal bmrd_req         :  std_logic;
  signal bmrd_req_granted :  std_logic;
  signal bmrd_data        :  std_logic_vector(dw-1 downto 0);
  signal bmrd_valid       :  std_logic;
  signal bmrd_done        :  std_logic;
  signal bmrd_error       :  std_logic;
  signal bmwr_addr        :  std_logic_vector(31 downto 0);
  signal bmwr_size        :  std_logic_vector(log2(max_size)-1 downto 0);
  signal bmwr_req         :  std_logic;
  signal bmwr_req_granted :  std_logic;
  signal bmwr_data        :  std_logic_vector(dw-1 downto 0);
  signal bmwr_full        :  std_logic;
  signal bmwr_done        :  std_logic;
  signal bmwr_error       :  std_logic;
begin
  
  
  be0 : dbgmst_be
    generic map (
      revision   => REVISION,
      bustype    => 0,
      max_size   => max_size,
      dw         => dw,
      addr_width => 32,
      pindex     => pindex,
      paddr      => paddr,
      pmask      => pmask
      )
    port map (
      rstn             => rstn,
      clk              => clk,
      apbsi            => apbsi,
      apbso            => apbso,
      --generic_bm signals
      --Read Channel
      bmrd_addr        => bmrd_addr,
      bmrd_size        => bmrd_size,
      bmrd_req         => bmrd_req,
      bmrd_req_granted => bmrd_req_granted,
      bmrd_data        => bmrd_data,
      bmrd_valid       => bmrd_valid,
      bmrd_done        => bmrd_done,
      bmrd_error       => bmrd_error,
      --Write Channel
      bmwr_addr        => bmwr_addr,
      bmwr_size        => bmwr_size,
      bmwr_req         => bmwr_req,
      bmwr_req_granted => bmwr_req_granted,
      bmwr_data        => bmwr_data,
      bmwr_full        => bmwr_full,
      bmwr_done        => bmwr_done,
      bmwr_error       => bmwr_error,
      -- Misc
      extaddr          => extaddr,
      exe              => exe,
      priv             => priv
    );
  
  -- Drive AHB Master signals
  bmsti.hgrant  <= ahbmi.hgrant(hmindex);
  bmsti.hready  <= ahbmi.hready;
  bmsti.hresp   <= ahbmi.hresp;
  bmsti.endian  <= ahbmi.endian;

  ahbmo.hbusreq  <= bmsto.hbusreq;
  ahbmo.hlock    <= bmsto.hlock;
  ahbmo.htrans   <= bmsto.htrans;
  ahbmo.haddr    <= bmsto.haddr;
  ahbmo.hwrite   <= bmsto.hwrite;
  ahbmo.hsize    <= bmsto.hsize;
  ahbmo.hburst   <= bmsto.hburst;
  ahbmo.hprot(0) <= not exe; 
  ahbmo.hprot(1) <= priv; 
  ahbmo.hprot(2) <= '0'; 
  ahbmo.hprot(3) <= '0'; 
  
  ahbmo.hwdata  <= ahbdrivedata(hwdata);
  hrdata        <= ahbselectdata(ahbmi.hrdata, bmsto.haddr(4 downto 2), conv_std_logic_vector(log2(dw)-3, 3), ahbmi.endian)(dw-1 downto 0);
  
  smb_bm0 : generic_bm_ahb
    generic map(
      bm_dw            => dw,
      be_dw            => dw,
      max_size         => max_size,
      max_burst_length => max_size,
      addr_width       => 32,
      excl_enabled     => false,
      hindex           => hmindex)
    port map (
      clk              => clk,
      rstn             => rstn,
      --AHB domain signals
      ahbmi            => bmsti,
      ahbmo            => bmsto,
      hrdata           => hrdata,
      hwdata           => hwdata,
      --Bus master domain signals
      --Read Channel (not used)
      bmrd_addr        => bmrd_addr,
      bmrd_size        => bmrd_size,
      bmrd_req         => bmrd_req,
      bmrd_req_granted => bmrd_req_granted,
      bmrd_data        => bmrd_data,
      bmrd_valid       => bmrd_valid,
      bmrd_done        => bmrd_done,
      bmrd_error       => bmrd_error,
      --Write Channel
      bmwr_addr        => bmwr_addr,
      bmwr_size        => bmwr_size,
      bmwr_req         => bmwr_req,
      bmwr_req_granted => bmwr_req_granted,
      bmwr_data        => bmwr_data,
      bmwr_full        => bmwr_full,
      bmwr_done        => bmwr_done,
      bmwr_error       => bmwr_error,
      --Endianess Output
      endian_out       => open,   --0->BE, 1->LE
      --Exclusive access
      excl_en          => '0',
      excl_nowrite     => '0',
      excl_done        => open,
      excl_err         => open
      );
    
end rtl;
