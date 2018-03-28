------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003, Gaisler Research
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
-- Entity: 	usbhc_axcelerator
-- File:	usbhc_axcelerator.vhd
-- Author:	Jonas Ekergarn - Gaisler Research 
-- Description: tech wrapper for axcelerator usbhc netlist
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library axcelerator;
use axcelerator.all;
library techmap;
use techmap.usbhc_axceleratorpkg.all;
use techmap.gencomp.all;

entity usbhc_axcelerator is
  generic (
    nports      : integer range 1 to 15 := 1;
    ehcgen      : integer range 0 to 1 := 1;
    uhcgen      : integer range 0 to 1 := 1;
    n_cc        : integer range 1 to 15 := 1;
    n_pcc       : integer range 1 to 15 := 1;
    prr         : integer range 0 to 1 := 0;
    portroute1  : integer := 0;
    portroute2  : integer := 0;
    endian_conv : integer range 0 to 1 := 1;
    be_regs     : integer range 0 to 1 := 0;
    be_desc     : integer range 0 to 1 := 0;
    uhcblo      : integer range 0 to 255 := 2;
    bwrd        : integer range 1 to 256 := 16;
    utm_type    : integer range 0 to 2 := 2;
    vbusconf    : integer range 0 to 3 := 3;
    ramtest     : integer range 0 to 1 := 0;
    urst_time   : integer := 250;
    oepol       : integer range 0 to 1 := 0;
    scantest    : integer := 0;
    memtech     : integer range 0 to NTECH := DEFMEMTECH
    );
  port (
    clk : in std_ulogic;
    uclk : in std_ulogic;
    rst : in std_ulogic;
    ursti : in std_ulogic;
    -- EHC apb_slv_in_type unwrapped
    ehc_apbsi_psel : in std_ulogic;
    ehc_apbsi_penable : in std_ulogic;
    ehc_apbsi_paddr : in std_logic_vector(31 downto 0);
    ehc_apbsi_pwrite : in std_ulogic;
    ehc_apbsi_pwdata : in std_logic_vector(31 downto 0);
    ehc_apbsi_testen : in std_ulogic;
    ehc_apbsi_testrst : in std_ulogic;
    ehc_apbsi_scanen : in std_ulogic;
    -- EHC apb_slv_out_type unwrapped
    ehc_apbso_prdata : out std_logic_vector(31 downto 0);
    ehc_apbso_pirq : out std_ulogic;
    -- EHC/UHC ahb_mst_in_type unwrapped
    ahbmi_hgrant : in std_logic_vector(n_cc*uhcgen downto 0);
    ahbmi_hready : in std_ulogic;
    ahbmi_hresp : in std_logic_vector(1 downto 0);
    ahbmi_hrdata : in std_logic_vector(31 downto 0);
    ahbmi_hcache : in std_ulogic;
    ahbmi_testen : in std_ulogic;
    ahbmi_testrst : in std_ulogic;
    ahbmi_scanen : in std_ulogic;
    -- UHC ahb_slv_in_type unwrapped
    uhc_ahbsi_hsel : in std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    uhc_ahbsi_haddr : in std_logic_vector(31 downto 0);
    uhc_ahbsi_hwrite : in std_ulogic;
    uhc_ahbsi_htrans : in std_logic_vector(1 downto 0);
    uhc_ahbsi_hsize : in std_logic_vector(2 downto 0);
    uhc_ahbsi_hwdata : in std_logic_vector(31 downto 0);
    uhc_ahbsi_hready : in std_ulogic;
    uhc_ahbsi_testen : in std_ulogic;
    uhc_ahbsi_testrst : in std_ulogic;
    uhc_ahbsi_scanen : in std_ulogic;
    -- EHC ahb_mst_out_type_unwrapped 
    ehc_ahbmo_hbusreq : out std_ulogic;
    ehc_ahbmo_hlock : out std_ulogic;
    ehc_ahbmo_htrans : out std_logic_vector(1 downto 0);
    ehc_ahbmo_haddr : out std_logic_vector(31 downto 0);
    ehc_ahbmo_hwrite : out std_ulogic;
    ehc_ahbmo_hsize : out std_logic_vector(2 downto 0);
    ehc_ahbmo_hburst : out std_logic_vector(2 downto 0);
    ehc_ahbmo_hprot : out std_logic_vector(3 downto 0);
    ehc_ahbmo_hwdata : out std_logic_vector(31 downto 0);
    -- UHC ahb_mst_out_vector_type unwrapped
    uhc_ahbmo_hbusreq : out std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    uhc_ahbmo_hlock : out std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    uhc_ahbmo_htrans : out std_logic_vector((n_cc*2)*uhcgen downto 1*uhcgen);
    uhc_ahbmo_haddr : out std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
    uhc_ahbmo_hwrite : out std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    uhc_ahbmo_hsize : out std_logic_vector((n_cc*3)*uhcgen downto 1*uhcgen);
    uhc_ahbmo_hburst : out std_logic_vector((n_cc*3)*uhcgen downto 1*uhcgen);
    uhc_ahbmo_hprot : out std_logic_vector((n_cc*4)*uhcgen downto 1*uhcgen);
    uhc_ahbmo_hwdata : out std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
    -- UHC ahb_slv_out_vector_type unwrapped
    uhc_ahbso_hready : out std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    uhc_ahbso_hresp : out std_logic_vector((n_cc*2)*uhcgen downto 1*uhcgen);
    uhc_ahbso_hrdata : out std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
    uhc_ahbso_hsplit : out std_logic_vector((n_cc*16)*uhcgen downto 1*uhcgen);
    uhc_ahbso_hcache : out std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    uhc_ahbso_hirq : out std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    -- usbhc_out_type_vector unwrapped
    xcvrsel : out std_logic_vector(((nports*2)-1) downto 0);
    termsel : out std_logic_vector((nports-1) downto 0);
    suspendm : out std_logic_vector((nports-1) downto 0);
    opmode : out std_logic_vector(((nports*2)-1) downto 0);
    txvalid : out std_logic_vector((nports-1) downto 0);
    drvvbus : out std_logic_vector((nports-1) downto 0);
    dataho : out std_logic_vector(((nports*8)-1) downto 0); 
    validho : out std_logic_vector((nports-1) downto 0);
    host : out std_logic_vector((nports-1) downto 0);
    stp : out std_logic_vector((nports-1) downto 0);
    datao : out std_logic_vector(((nports*8)-1) downto 0);   
    utm_rst : out std_logic_vector((nports-1) downto 0);
    dctrlo : out std_logic_vector((nports-1) downto 0);
    -- usbhc_in_type_vector unwrapped
    linestate : in std_logic_vector(((nports*2)-1) downto 0);
    txready : in std_logic_vector((nports-1) downto 0);
    rxvalid : in std_logic_vector((nports-1) downto 0);
    rxactive : in std_logic_vector((nports-1) downto 0);
    rxerror : in std_logic_vector((nports-1) downto 0);
    vbusvalid : in std_logic_vector((nports-1) downto 0);
    datahi : in std_logic_vector(((nports*8)-1) downto 0);
    validhi : in std_logic_vector((nports-1) downto 0);
    hostdisc : in std_logic_vector((nports-1) downto 0);
    nxt : in std_logic_vector((nports-1) downto 0);
    dir : in std_logic_vector((nports-1) downto 0);
    datai : in std_logic_vector(((nports*8)-1) downto 0);
    -- EHC transaction buffer signals
    mbc20_tb_addr : out std_logic_vector(8 downto 0);
    mbc20_tb_data : out std_logic_vector(31 downto 0);
    mbc20_tb_en   : out std_ulogic;
    mbc20_tb_wel  : out std_ulogic;
    mbc20_tb_weh  : out std_ulogic;
    tb_mbc20_data : in std_logic_vector(31 downto 0);
    pe20_tb_addr  : out std_logic_vector(8 downto 0);
    pe20_tb_data  : out std_logic_vector(31 downto 0);
    pe20_tb_en    : out std_ulogic;
    pe20_tb_wel   : out std_ulogic;
    pe20_tb_weh   : out std_ulogic;
    tb_pe20_data  : in std_logic_vector(31 downto 0);
    -- EHC packet buffer signals
    mbc20_pb_addr : out std_logic_vector(8 downto 0);
    mbc20_pb_data : out std_logic_vector(31 downto 0);
    mbc20_pb_en   : out std_ulogic;
    mbc20_pb_we   : out std_ulogic;
    pb_mbc20_data : in std_logic_vector(31 downto 0);
    sie20_pb_addr : out std_logic_vector(8 downto 0);
    sie20_pb_data : out std_logic_vector(31 downto 0);
    sie20_pb_en   : out std_ulogic;
    sie20_pb_we   : out std_ulogic;
    pb_sie20_data : in std_logic_vector(31 downto 0);
    -- UHC packet buffer signals
    sie11_pb_addr : out std_logic_vector((n_cc*9)*uhcgen downto 1*uhcgen);
    sie11_pb_data : out std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
    sie11_pb_en   : out std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    sie11_pb_we   : out std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    pb_sie11_data : in std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
    mbc11_pb_addr : out std_logic_vector((n_cc*9)*uhcgen downto 1*uhcgen);
    mbc11_pb_data : out std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
    mbc11_pb_en   : out std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    mbc11_pb_we   : out std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
    pb_mbc11_data : in std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
    bufsel        : out std_ulogic);
end usbhc_axcelerator;

architecture rtl of usbhc_axcelerator is
    
begin

  -----------------------------------------------------------------------------
  -- Howto add netlist maps:
  -- First check the different combination of generics below. If your
  -- configuration is not available then add a new one named comb<X+1> (where
  -- X is the value of the last combination defined below) by simply copy
  -- pasting one exicisting combination and changing the generics and component
  -- name. Then add a component decleration for that configuration in the file
  -- usbhc_axceleratorpkg.vhd by simply copy pasting the port decleration from
  -- the entity above and replacing n_cc, uhcgen, and nports with their actual
  -- values. Also add the combination of genercis as valid in the function
  -- valid_comb at the bottom of the file usbhc_axceleratorpkg.vhd
  -----------------------------------------------------------------------------
  
  comb0 : if nports     = 1 and
            ehcgen      = 0 and
            uhcgen      = 1 and
            n_cc        = 1 and
            n_pcc       = 1 and
            prr         = 0 and
            portroute1  = 0 and
            portroute2  = 0 and
            endian_conv = 1 and
            be_regs     = 0 and
            be_desc     = 0 and
            uhcblo      = 2 and
            bwrd        = 16 and
            utm_type    = 2 and
            vbusconf    = 3 and
            ramtest     = 0 and
            urst_time   = 250 and
            oepol       = 0 and
            scantest    = 0 generate
    usbhc0 : usbhc_axcelerator_comb0
      port map(
        clk,uclk,rst,ursti,ehc_apbsi_psel,ehc_apbsi_penable,ehc_apbsi_paddr,
        ehc_apbsi_pwrite,ehc_apbsi_pwdata,ehc_apbsi_testen,ehc_apbsi_testrst,
        ehc_apbsi_scanen,ehc_apbso_prdata,ehc_apbso_pirq,ahbmi_hgrant,
        ahbmi_hready,ahbmi_hresp,ahbmi_hrdata,ahbmi_hcache,ahbmi_testen,
        ahbmi_testrst,ahbmi_scanen,uhc_ahbsi_hsel,uhc_ahbsi_haddr,
        uhc_ahbsi_hwrite,uhc_ahbsi_htrans,uhc_ahbsi_hsize,uhc_ahbsi_hwdata,
        uhc_ahbsi_hready,uhc_ahbsi_testen,uhc_ahbsi_testrst,uhc_ahbsi_scanen,
        ehc_ahbmo_hbusreq,ehc_ahbmo_hlock,ehc_ahbmo_htrans,ehc_ahbmo_haddr,
        ehc_ahbmo_hwrite,ehc_ahbmo_hsize,ehc_ahbmo_hburst,ehc_ahbmo_hprot,
        ehc_ahbmo_hwdata,uhc_ahbmo_hbusreq,uhc_ahbmo_hlock,uhc_ahbmo_htrans,
        uhc_ahbmo_haddr,uhc_ahbmo_hwrite,uhc_ahbmo_hsize,uhc_ahbmo_hburst,
        uhc_ahbmo_hprot,uhc_ahbmo_hwdata,uhc_ahbso_hready,uhc_ahbso_hresp,
        uhc_ahbso_hrdata,uhc_ahbso_hsplit,uhc_ahbso_hcache,uhc_ahbso_hirq,
        xcvrsel,termsel,suspendm,opmode,txvalid,drvvbus,dataho,validho,host,
        stp,datao,utm_rst,dctrlo,linestate,txready,rxvalid,rxactive,rxerror,
        vbusvalid,datahi,validhi,hostdisc,nxt,dir,datai,mbc20_tb_addr,
        mbc20_tb_data,mbc20_tb_en,mbc20_tb_wel,mbc20_tb_weh,tb_mbc20_data,
        pe20_tb_addr,pe20_tb_data,pe20_tb_en,pe20_tb_wel,pe20_tb_weh,
        tb_pe20_data,mbc20_pb_addr,mbc20_pb_data,mbc20_pb_en,mbc20_pb_we,
        pb_mbc20_data,sie20_pb_addr,sie20_pb_data,sie20_pb_en,sie20_pb_we,
        pb_sie20_data,sie11_pb_addr,sie11_pb_data,sie11_pb_en,sie11_pb_we,
        pb_sie11_data,mbc11_pb_addr,mbc11_pb_data,mbc11_pb_en,mbc11_pb_we,
        pb_mbc11_data,bufsel);
  end generate comb0;

  comb1 : if nports     = 1 and
            ehcgen      = 1 and
            uhcgen      = 0 and
            n_cc        = 1 and
            n_pcc       = 1 and
            prr         = 0 and
            portroute1  = 0 and
            portroute2  = 0 and
            endian_conv = 1 and
            be_regs     = 0 and
            be_desc     = 0 and
            uhcblo      = 2 and
            bwrd        = 16 and
            utm_type    = 2 and
            vbusconf    = 3 and
            ramtest     = 0 and
            urst_time   = 250 and
            oepol       = 0 and
            scantest    = 0 generate
    usbhc0 : usbhc_axcelerator_comb1
      port map(
        clk,uclk,rst,ursti,ehc_apbsi_psel,ehc_apbsi_penable,ehc_apbsi_paddr,
        ehc_apbsi_pwrite,ehc_apbsi_pwdata,ehc_apbsi_testen,ehc_apbsi_testrst,
        ehc_apbsi_scanen,ehc_apbso_prdata,ehc_apbso_pirq,ahbmi_hgrant,
        ahbmi_hready,ahbmi_hresp,ahbmi_hrdata,ahbmi_hcache,ahbmi_testen,
        ahbmi_testrst,ahbmi_scanen,uhc_ahbsi_hsel,uhc_ahbsi_haddr,
        uhc_ahbsi_hwrite,uhc_ahbsi_htrans,uhc_ahbsi_hsize,uhc_ahbsi_hwdata,
        uhc_ahbsi_hready,uhc_ahbsi_testen,uhc_ahbsi_testrst,uhc_ahbsi_scanen,
        ehc_ahbmo_hbusreq,ehc_ahbmo_hlock,ehc_ahbmo_htrans,ehc_ahbmo_haddr,
        ehc_ahbmo_hwrite,ehc_ahbmo_hsize,ehc_ahbmo_hburst,ehc_ahbmo_hprot,
        ehc_ahbmo_hwdata,uhc_ahbmo_hbusreq,uhc_ahbmo_hlock,uhc_ahbmo_htrans,
        uhc_ahbmo_haddr,uhc_ahbmo_hwrite,uhc_ahbmo_hsize,uhc_ahbmo_hburst,
        uhc_ahbmo_hprot,uhc_ahbmo_hwdata,uhc_ahbso_hready,uhc_ahbso_hresp,
        uhc_ahbso_hrdata,uhc_ahbso_hsplit,uhc_ahbso_hcache,uhc_ahbso_hirq,
        xcvrsel,termsel,suspendm,opmode,txvalid,drvvbus,dataho,validho,host,
        stp,datao,utm_rst,dctrlo,linestate,txready,rxvalid,rxactive,rxerror,
        vbusvalid,datahi,validhi,hostdisc,nxt,dir,datai,mbc20_tb_addr,
        mbc20_tb_data,mbc20_tb_en,mbc20_tb_wel,mbc20_tb_weh,tb_mbc20_data,
        pe20_tb_addr,pe20_tb_data,pe20_tb_en,pe20_tb_wel,pe20_tb_weh,
        tb_pe20_data,mbc20_pb_addr,mbc20_pb_data,mbc20_pb_en,mbc20_pb_we,
        pb_mbc20_data,sie20_pb_addr,sie20_pb_data,sie20_pb_en,sie20_pb_we,
        pb_sie20_data,sie11_pb_addr,sie11_pb_data,sie11_pb_en,sie11_pb_we,
        pb_sie11_data,mbc11_pb_addr,mbc11_pb_data,mbc11_pb_en,mbc11_pb_we,
        pb_mbc11_data,bufsel);
  end generate comb1;

  comb2 : if nports     = 1 and
            ehcgen      = 1 and
            uhcgen      = 1 and
            n_cc        = 1 and
            n_pcc       = 1 and
            prr         = 0 and
            portroute1  = 0 and
            portroute2  = 0 and
            endian_conv = 1 and
            be_regs     = 0 and
            be_desc     = 0 and
            uhcblo      = 2 and
            bwrd        = 16 and
            utm_type    = 2 and
            vbusconf    = 3 and
            ramtest     = 0 and
            urst_time   = 250 and
            oepol       = 0 and
            scantest    = 0 generate
    usbhc0 : usbhc_axcelerator_comb2
      port map(
        clk,uclk,rst,ursti,ehc_apbsi_psel,ehc_apbsi_penable,ehc_apbsi_paddr,
        ehc_apbsi_pwrite,ehc_apbsi_pwdata,ehc_apbsi_testen,ehc_apbsi_testrst,
        ehc_apbsi_scanen,ehc_apbso_prdata,ehc_apbso_pirq,ahbmi_hgrant,
        ahbmi_hready,ahbmi_hresp,ahbmi_hrdata,ahbmi_hcache,ahbmi_testen,
        ahbmi_testrst,ahbmi_scanen,uhc_ahbsi_hsel,uhc_ahbsi_haddr,
        uhc_ahbsi_hwrite,uhc_ahbsi_htrans,uhc_ahbsi_hsize,uhc_ahbsi_hwdata,
        uhc_ahbsi_hready,uhc_ahbsi_testen,uhc_ahbsi_testrst,uhc_ahbsi_scanen,
        ehc_ahbmo_hbusreq,ehc_ahbmo_hlock,ehc_ahbmo_htrans,ehc_ahbmo_haddr,
        ehc_ahbmo_hwrite,ehc_ahbmo_hsize,ehc_ahbmo_hburst,ehc_ahbmo_hprot,
        ehc_ahbmo_hwdata,uhc_ahbmo_hbusreq,uhc_ahbmo_hlock,uhc_ahbmo_htrans,
        uhc_ahbmo_haddr,uhc_ahbmo_hwrite,uhc_ahbmo_hsize,uhc_ahbmo_hburst,
        uhc_ahbmo_hprot,uhc_ahbmo_hwdata,uhc_ahbso_hready,uhc_ahbso_hresp,
        uhc_ahbso_hrdata,uhc_ahbso_hsplit,uhc_ahbso_hcache,uhc_ahbso_hirq,
        xcvrsel,termsel,suspendm,opmode,txvalid,drvvbus,dataho,validho,host,
        stp,datao,utm_rst,dctrlo,linestate,txready,rxvalid,rxactive,rxerror,
        vbusvalid,datahi,validhi,hostdisc,nxt,dir,datai,mbc20_tb_addr,
        mbc20_tb_data,mbc20_tb_en,mbc20_tb_wel,mbc20_tb_weh,tb_mbc20_data,
        pe20_tb_addr,pe20_tb_data,pe20_tb_en,pe20_tb_wel,pe20_tb_weh,
        tb_pe20_data,mbc20_pb_addr,mbc20_pb_data,mbc20_pb_en,mbc20_pb_we,
        pb_mbc20_data,sie20_pb_addr,sie20_pb_data,sie20_pb_en,sie20_pb_we,
        pb_sie20_data,sie11_pb_addr,sie11_pb_data,sie11_pb_en,sie11_pb_we,
        pb_sie11_data,mbc11_pb_addr,mbc11_pb_data,mbc11_pb_en,mbc11_pb_we,
        pb_mbc11_data,bufsel);    
  end generate comb2;

  comb3 : if nports     = 2 and
            ehcgen      = 1 and
            uhcgen      = 1 and
            n_cc        = 1 and
            n_pcc       = 2 and
            prr         = 0 and
            portroute1  = 0 and
            portroute2  = 0 and
            endian_conv = 1 and
            be_regs     = 0 and
            be_desc     = 0 and
            uhcblo      = 2 and
            bwrd        = 16 and
            utm_type    = 2 and
            vbusconf    = 3 and
            ramtest     = 0 and
            urst_time   = 250 and
            oepol       = 0 and
            scantest    = 0 generate
    usbhc0 : usbhc_axcelerator_comb3
      port map(
        clk,uclk,rst,ursti,ehc_apbsi_psel,ehc_apbsi_penable,ehc_apbsi_paddr,
        ehc_apbsi_pwrite,ehc_apbsi_pwdata,ehc_apbsi_testen,ehc_apbsi_testrst,
        ehc_apbsi_scanen,ehc_apbso_prdata,ehc_apbso_pirq,ahbmi_hgrant,
        ahbmi_hready,ahbmi_hresp,ahbmi_hrdata,ahbmi_hcache,ahbmi_testen,
        ahbmi_testrst,ahbmi_scanen,uhc_ahbsi_hsel,uhc_ahbsi_haddr,
        uhc_ahbsi_hwrite,uhc_ahbsi_htrans,uhc_ahbsi_hsize,uhc_ahbsi_hwdata,
        uhc_ahbsi_hready,uhc_ahbsi_testen,uhc_ahbsi_testrst,uhc_ahbsi_scanen,
        ehc_ahbmo_hbusreq,ehc_ahbmo_hlock,ehc_ahbmo_htrans,ehc_ahbmo_haddr,
        ehc_ahbmo_hwrite,ehc_ahbmo_hsize,ehc_ahbmo_hburst,ehc_ahbmo_hprot,
        ehc_ahbmo_hwdata,uhc_ahbmo_hbusreq,uhc_ahbmo_hlock,uhc_ahbmo_htrans,
        uhc_ahbmo_haddr,uhc_ahbmo_hwrite,uhc_ahbmo_hsize,uhc_ahbmo_hburst,
        uhc_ahbmo_hprot,uhc_ahbmo_hwdata,uhc_ahbso_hready,uhc_ahbso_hresp,
        uhc_ahbso_hrdata,uhc_ahbso_hsplit,uhc_ahbso_hcache,uhc_ahbso_hirq,
        xcvrsel,termsel,suspendm,opmode,txvalid,drvvbus,dataho,validho,host,
        stp,datao,utm_rst,dctrlo,linestate,txready,rxvalid,rxactive,rxerror,
        vbusvalid,datahi,validhi,hostdisc,nxt,dir,datai,mbc20_tb_addr,
        mbc20_tb_data,mbc20_tb_en,mbc20_tb_wel,mbc20_tb_weh,tb_mbc20_data,
        pe20_tb_addr,pe20_tb_data,pe20_tb_en,pe20_tb_wel,pe20_tb_weh,
        tb_pe20_data,mbc20_pb_addr,mbc20_pb_data,mbc20_pb_en,mbc20_pb_we,
        pb_mbc20_data,sie20_pb_addr,sie20_pb_data,sie20_pb_en,sie20_pb_we,
        pb_sie20_data,sie11_pb_addr,sie11_pb_data,sie11_pb_en,sie11_pb_we,
        pb_sie11_data,mbc11_pb_addr,mbc11_pb_data,mbc11_pb_en,mbc11_pb_we,
        pb_mbc11_data,bufsel);
  end generate comb3;
  
-- pragma translate_off
  nomap : if not valid_comb(nports,ehcgen,uhcgen,n_cc,n_pcc,prr,portroute1,
                            portroute2,endian_conv,be_regs,be_desc,uhcblo,bwrd,
                            utm_type,vbusconf,ramtest,urst_time,oepol,scantest)
  generate
    err : process 
    begin
      assert false report "ERROR : Can't map a netlist for this combination" &
        "of generics"
        severity failure;
      wait;
    end process;
  end generate;
-- pragma translate_on
  
end rtl;
