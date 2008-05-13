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
-------------------------------------------------------------------------------
-- Entity:      grusbhc
-- File:        grusbhc.vhd
-- Author:      Jonas Ekergarn - Gaisler Research
-- Description: GRLIB wrapper for usbhc core
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;
use techmap.netcomp.all;
library gaisler;
use gaisler.grusbhc_pkg.all;
library usbhc;
use usbhc.usbhc_comp.all;

entity grusbhc is
  generic (
    ehchindex   : integer range 0 to NAHBMST-1 := 0;
    ehcpindex   : integer range 0 to NAPBSLV-1 := 0;
    ehcpaddr    : integer range 0 to 16#FFF# := 0;
    ehcpirq     : integer range 0 to NAHBIRQ-1 := 0;
    ehcpmask    : integer range 0 to 16#FFF# := 16#FFF#;
    uhchindex   : integer range 0 to NAHBMST-1 := 0;
    uhchsindex  : integer range 0 to NAHBSLV-1 := 0;
    uhchaddr    : integer range 0 to 16#FFF# := 0;
    uhchmask    : integer range 0 to 16#FFF# := 16#FFF#;
    uhchirq     : integer range 0 to NAHBIRQ-1 := 0;
    tech        : integer range 0 to NTECH := DEFFABTECH;
    memtech     : integer range 0 to NTECH := DEFMEMTECH;
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
    vbusconf    : integer range 0 to 3 := 0;
    netlist     : integer range 0 to 1 := 0;
    ramtest     : integer range 0 to 1 := 0;
    urst_time   : integer := 250;
    oepol       : integer range 0 to 1 := 0;
    scantest    : integer := 0);
  port (
    clk       : in std_ulogic;
    uclk      : in std_ulogic;
    rst       : in std_ulogic;
    ursti     : in std_ulogic;
    -- APB signals
    apbi      : in apb_slv_in_type;
    ehc_apbo  : out apb_slv_out_type;
    -- AHB signals
    ahbmi     : in ahb_mst_in_type;
    ahbsi     : in ahb_slv_in_type;
    ehc_ahbmo : out ahb_mst_out_type;
    uhc_ahbmo : out ahb_mst_out_vector_type(n_cc*uhcgen downto 1*uhcgen);
    uhc_ahbso : out ahb_slv_out_vector_type(n_cc*uhcgen downto 1*uhcgen); 
    -- Signals to USB transceiver
    o         : out usbhc_out_vector((nports-1) downto 0);
    -- Signals from USB transceiver
    i         : in usbhc_in_vector((nports-1) downto 0));
end grusbhc;

architecture rtl of grusbhc is

  -- AMBA configuration words. The UHCs ahb slave config word is calculated
  -- below since it is not constant
  constant EHC_PCONFIG : apb_config_type := (
    0 => ahb_device_reg(VENDOR_GAISLER, GAISLER_EHCI, 0, EHC_REVISION, ehcpirq),
    1 => apb_iobar(ehcpaddr, ehcpmask));
  constant EHC_HCONFIG : ahb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_EHCI, 0, EHC_REVISION, 0),
    others => zero32);
  constant UHC_HCONFIG : ahb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_UHCI, 0, EHC_REVISION, 0),
    others => zero32);

  signal ehc_apbso_pirq : std_ulogic;
  signal uhc_ahbslvo_hirq : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
  signal ahbmsti_hgrant : std_logic_vector(n_cc*uhcgen downto 0);
  signal ahbslvi_hsel : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);

  type hirq_array is array (1*uhcgen to n_cc*uhcgen) of
    std_logic_vector(NAHBIRQ-1 downto 0);
  signal uhc_ahbslvo_hirq_int : hirq_array;
  
  -- ahb_mst_out_type_vector unwrapped
  signal hbusreq  : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
  signal hlock    : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
  signal htrans   : std_logic_vector((n_cc*2)*uhcgen downto 1*uhcgen);
  signal haddr    : std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
  signal hwrite   : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
  signal hsize    : std_logic_vector((n_cc*3)*uhcgen downto 1*uhcgen);
  signal hburst   : std_logic_vector((n_cc*3)*uhcgen downto 1*uhcgen);
  signal hprot    : std_logic_vector((n_cc*4)*uhcgen downto 1*uhcgen);
  signal hwdata   : std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);

  -- ahb_slv_out_type_vector unwrapped
  signal hready   : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
  signal hresp    : std_logic_vector((n_cc*2)*uhcgen downto 1*uhcgen);
  signal hrdata   : std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
  signal hsplit   : std_logic_vector((n_cc*16)*uhcgen downto 1*uhcgen);
  signal hcache   : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);

  -- usbhc_out_type_vector unwrapped
  signal xcvrsel  : std_logic_vector(((nports*2)-1) downto 0);
  signal termsel  : std_logic_vector((nports-1) downto 0);
  signal suspendm : std_logic_vector((nports-1) downto 0);
  signal opmode   : std_logic_vector(((nports*2)-1) downto 0);
  signal txvalid  : std_logic_vector((nports-1) downto 0);
  signal drvvbus  : std_logic_vector((nports-1) downto 0);
  signal dataho   : std_logic_vector(((nports*8)-1) downto 0);
  signal validho  : std_logic_vector((nports-1) downto 0);
  signal host     : std_logic_vector((nports-1) downto 0);
  signal stp      : std_logic_vector((nports-1) downto 0);
  signal datao    : std_logic_vector(((nports*8)-1) downto 0);
  signal utm_rst  : std_logic_vector((nports-1) downto 0);
  signal dctrlo   : std_logic_vector((nports-1) downto 0);

  -- usbhc_in_type_vector unwrapped
  signal linestate : std_logic_vector(((nports*2)-1) downto 0);
  signal txready   : std_logic_vector((nports-1) downto 0);
  signal rxvalid   : std_logic_vector((nports-1) downto 0);
  signal rxactive  : std_logic_vector((nports-1) downto 0);
  signal rxerror   : std_logic_vector((nports-1) downto 0);
  signal vbusvalid : std_logic_vector((nports-1) downto 0);
  signal datahi    : std_logic_vector(((nports*8)-1) downto 0);
  signal validhi   : std_logic_vector((nports-1) downto 0);
  signal hostdisc  : std_logic_vector((nports-1) downto 0);
  signal nxt       : std_logic_vector((nports-1) downto 0);
  signal dir       : std_logic_vector((nports-1) downto 0);
  signal datai     : std_logic_vector(((nports*8)-1) downto 0);

  -- EHC transaction buffer signals
  signal mbc20_tb_addr : std_logic_vector(8 downto 0);
  signal mbc20_tb_data : std_logic_vector(31 downto 0);
  signal mbc20_tb_en   : std_ulogic;
  signal mbc20_tb_wel  : std_ulogic;
  signal mbc20_tb_weh  : std_ulogic;
  signal tb_mbc20_data : std_logic_vector(31 downto 0);
  signal pe20_tb_addr  : std_logic_vector(8 downto 0);
  signal pe20_tb_data  : std_logic_vector(31 downto 0);
  signal pe20_tb_en    : std_ulogic;
  signal pe20_tb_wel   : std_ulogic;
  signal pe20_tb_weh   : std_ulogic;
  signal tb_pe20_data  : std_logic_vector(31 downto 0);
  
  -- EHC packet buffer signals
  signal mbc20_pb_addr : std_logic_vector(8 downto 0);
  signal mbc20_pb_data : std_logic_vector(31 downto 0);
  signal mbc20_pb_en   : std_ulogic;
  signal mbc20_pb_we   : std_ulogic;
  signal pb_mbc20_data : std_logic_vector(31 downto 0);
  signal sie20_pb_addr : std_logic_vector(8 downto 0);
  signal sie20_pb_data : std_logic_vector(31 downto 0);
  signal sie20_pb_en   : std_ulogic;
  signal sie20_pb_we   : std_ulogic;
  signal pb_sie20_data : std_logic_vector(31 downto 0);

  -- UHC packet buffer signals
  signal sie11_pb_addr : std_logic_vector((n_cc*9)*uhcgen downto 1*uhcgen);
  signal sie11_pb_data : std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
  signal sie11_pb_en   : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
  signal sie11_pb_we   : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
  signal pb_sie11_data : std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
  signal mbc11_pb_addr : std_logic_vector((n_cc*9)*uhcgen downto 1*uhcgen);
  signal mbc11_pb_data : std_logic_vector((n_cc*32)*uhcgen downto 1*uhcgen);
  signal mbc11_pb_en   : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
  signal mbc11_pb_we   : std_logic_vector(n_cc*uhcgen downto 1*uhcgen);
  signal pb_mbc11_data : std_logic_vector((n_cc*32*uhcgen) downto 1*uhcgen);

  -- combined (for special case when EHC and UHC share PB)
  signal mbc_pb_addr : std_logic_vector(8 downto 0);
  signal mbc_pb_data : std_logic_vector(31 downto 0);
  signal mbc_pb_en   : std_ulogic;
  signal mbc_pb_we   : std_ulogic;
  signal pb_mbc_data : std_logic_vector(31 downto 0);
  signal sie_pb_addr : std_logic_vector(8 downto 0);
  signal sie_pb_data : std_logic_vector(31 downto 0);
  signal sie_pb_en   : std_ulogic;
  signal sie_pb_we   : std_ulogic;
  signal pb_sie_data : std_logic_vector(31 downto 0);
  signal bufsel : std_ulogic;
  
begin

  -----------------------------------------------------------------------------
  -- AHB / APB configuration
  -----------------------------------------------------------------------------
  ehc_amba: if ehcgen = 1 generate
    ehc_apbo.pconfig <= EHC_PCONFIG;
    ehc_apbo.pindex  <= ehcpindex;
    ehc_ahbmo.hconfig <= EHC_HCONFIG;
    ehc_ahbmo.hindex <= ehchindex;
    ahbmsti_hgrant(0) <= ahbmi.hgrant(ehchindex);

    ehc_pirq_process: process (ehc_apbso_pirq)
    begin
      ehc_apbo.pirq <= (others=>'0');
      ehc_apbo.pirq(ehcpirq) <= ehc_apbso_pirq;
    end process ehc_pirq_process;
  
    -- Boot message
    -- pragma translate_off
    bootmsg : report_version 
      generic map (
        "grehc" & tost(ehcpindex) & ": USB Enhanced Host Controller rev " &
        tost(EHC_REVISION) & ", irq " & tost(ehcpirq));
    -- pragma translate_on

    ---------------------------------------------------------------------------
    -- Check that the mask has an appropriate value if ramtest is enabled
    ---------------------------------------------------------------------------
    -- pragma translate off
    assert ehc_mask_check(ramtest, ehcpmask) report
      "ramtest is 1 and ehchpmask results in a register area that is too " &
      "small to accommodate the buffer mapping" severity failure;
    -- pragma translate on
  end generate ehc_amba;

  noehc_amba: if ehcgen = 0 generate
    ehc_apbo.pconfig  <= (others=>zx);
    ehc_apbo.pindex   <= 0;
    ehc_apbo.pirq <= (others=>'0');
    ehc_ahbmo.hconfig <= (others=>zx);
    ehc_ahbmo.hindex  <= 0;
    ahbmsti_hgrant(0) <= '0';
  end generate noehc_amba;

  ehc_ahbmo.hirq <= (others=>'0');

  uhc_ahb: if uhcgen = 1 generate
    uhc_hirq_process: process (uhc_ahbslvo_hirq)
    begin
      for j in 1 to n_cc loop
        uhc_ahbslvo_hirq_int(j)              <= (others=>'0');
        uhc_ahbslvo_hirq_int(j)(uhchirq+j-1) <= uhc_ahbslvo_hirq(j);
      end loop;    
    end process uhc_hirq_process;
    
    uhc_ahb_loop: for j in 1 to n_cc generate      
      uhc_ahbmo(j).hbusreq <= hbusreq(j);
      uhc_ahbmo(j).hlock   <= hlock(j);
      uhc_ahbmo(j).htrans  <= htrans(2*j downto (2*j)-1);
      uhc_ahbmo(j).haddr   <= haddr(32*j downto (32*j)-31);
      uhc_ahbmo(j).hwrite  <= hwrite(j);
      uhc_ahbmo(j).hsize   <= hsize(3*j downto (3*j)-2);
      uhc_ahbmo(j).hburst  <= hburst(3*j downto (3*j)-2);
      uhc_ahbmo(j).hprot   <= hprot(4*j downto (4*j)-3);
      uhc_ahbmo(j).hwdata  <= hwdata(32*j downto (32*j)-31);
      uhc_ahbmo(j).hirq    <= (others=>'0');
      uhc_ahbmo(j).hconfig <= UHC_HCONFIG;
      uhc_ahbmo(j).hindex  <= uhchindex+j-1;
      
      uhc_ahbso(j).hready  <= hready(j);
      uhc_ahbso(j).hresp   <= hresp(2*j downto (2*j)-1);
      uhc_ahbso(j).hrdata  <= hrdata(32*j downto (32*j)-31);
      uhc_ahbso(j).hsplit  <= hsplit(16*j downto (16*j)-15);
      uhc_ahbso(j).hcache  <= hcache(j);
      uhc_ahbso(j).hconfig <= (
        0 => ahb_device_reg(VENDOR_GAISLER, GAISLER_UHCI, 0, UHC_REVISION,
                            uhchirq+j-1),
        4 => ahb_iobar(uhchaddr+j-1, uhchmask),
        others => zero32);
      uhc_ahbso(j).hindex  <= uhchsindex+j-1;
      uhc_ahbso(j).hirq    <= uhc_ahbslvo_hirq_int(j);
                  
      ahbmsti_hgrant(j) <= ahbmi.hgrant(uhchindex+j-1);
      ahbslvi_hsel(j)   <= ahbsi.hsel(uhchsindex+j-1);
      -- Boot message
      -- pragma translate_off
      bootmsg : report_version 
        generic map (
          "gruhc" & tost(uhchsindex+j-1) & ": USB Universal Host Controller rev " &
          tost(UHC_REVISION) & ", irq " & tost(uhchirq+j-1));
      -- pragma translate_on

      -------------------------------------------------------------------------
      -- Check that the mask has an appropriate value if ramtest is enabled
      -------------------------------------------------------------------------
      -- pragma translate off
      assert uhc_mask_check(ramtest, uhchmask) report
        "ramtest is 1 and uhchmask results in a register area that is too " &
        "small to accommodate the buffer mapping" severity failure;
      -- pragma translate on
    end generate uhc_ahb_loop;
  end generate uhc_ahb;    
  
  nouhc_ahb: if uhcgen = 0 generate
    uhc_ahbslvo_hirq_int <= (others=>(others=>'0'));
    uhc_ahbso(0) <= ahbs_none;
    ahbslvi_hsel(0) <= '0';
    uhc_ahbmo(0) <= ahbm_none;
  end generate nouhc_ahb;    
  
  port_loop: for j in 0 to (nports-1) generate
    o(j).xcvrsel  <= xcvrsel((2*j)+1 downto 2*j);
    o(j).termsel  <= termsel(j);
    o(j).suspendm <= suspendm(j);
    o(j).opmode   <= opmode((2*j)+1 downto 2*j);
    o(j).txvalid  <= txvalid(j);
    o(j).drvvbus  <= drvvbus(j);
    o(j).dataho   <= dataho((8*j)+7 downto 8*j);
    o(j).validho  <= validho(j);
    o(j).host     <= host(j);
    o(j).stp      <= stp(j);
    o(j).datao    <= datao((8*j)+7 downto 8*j);
    o(j).utm_rst  <= utm_rst(j);
    o(j).dctrl    <= dctrlo(j);
    
    datai((8*j)+7 downto 8*j) <= i(j).datai;
    utm0: if utm_type = 0 generate
      datahi((8*j)+7 downto 8*j) <= i(j).datahi;
      validhi(j)                 <= i(j).validhi;
    end generate utm0;
    not_utm0: if utm_type /= 0 generate
      datahi((8*j)+7 downto 8*j) <= (others=>'0');
      validhi(j)                 <= '0';
    end generate not_utm0;
    utm2: if utm_type = 2 generate
      linestate((2*j)+1 downto 2*j) <= (others=>'0');
      txready(j)                    <= '0';
      rxvalid(j)                    <= '0';
      rxactive(j)                   <= '0';
      rxerror(j)                    <= '0';
      vbusvalid(j)                  <= '0';
      hostdisc(j)                   <= '0';
      nxt(j)                        <= i(j).nxt;
      dir(j)                        <= i(j).dir;
    end generate utm2;
    not_utm2: if utm_type /= 2 generate
      linestate((2*j)+1 downto 2*j) <= i(j).linestate;
      txready(j)                    <= i(j).txready;
      rxvalid(j)                    <= i(j).rxvalid;
      rxactive(j)                   <= i(j).rxactive;
      rxerror(j)                    <= i(j).rxerror;
      vbusvalid(j)                  <= i(j).vbusvalid;
      hostdisc(j)                   <= i(j).hostdisc;
      nxt(j)                        <= '0';
      dir(j)                        <= '0';
    end generate not_utm2;
  end generate port_loop;      
    
  rtl_model : if netlist = 0 generate
    usbhc0 : usbhc_top
      generic map(
        nports      => nports,
        ehcgen      => ehcgen,
        uhcgen      => uhcgen,
        n_cc        => n_cc,
        n_pcc       => n_pcc,
        prr         => prr,
        portroute1  => portroute1,
        portroute2  => portroute2,
        endian_conv => endian_conv,
        be_regs     => be_regs,
        be_desc     => be_desc,
        uhcblo      => uhcblo,
        bwrd        => bwrd,
        utm_type    => utm_type,
        vbusconf    => vbusconf,
        ramtest     => ramtest,
        urst_time   => urst_time,
        oepol       => oepol,
        scantest    => scantest,
        memtech     => memtech)
      port map(
        clk => clk,
        uclk => uclk,
        rst => rst,
        ursti => ursti,
        -- EHC apb_slv_in_type unwrapped
        ehc_apbsi_psel => apbi.psel(ehcpindex),
        ehc_apbsi_penable => apbi.penable,
        ehc_apbsi_paddr => apbi.paddr,
        ehc_apbsi_pwrite => apbi.pwrite,
        ehc_apbsi_pwdata => apbi.pwdata,
        ehc_apbsi_testen => apbi.testen,
        ehc_apbsi_testrst => apbi.testrst,
        ehc_apbsi_scanen => apbi.scanen,
        -- EHC apb_slv_out_type unwrapped
        ehc_apbso_prdata => ehc_apbo.prdata,
        ehc_apbso_pirq => ehc_apbso_pirq,
        -- EHC/UHC ahb_mst_in_type unwrapped
        ahbmi_hgrant => ahbmsti_hgrant,
        ahbmi_hready => ahbmi.hready,
        ahbmi_hresp => ahbmi.hresp,
        ahbmi_hrdata => ahbmi.hrdata,
        ahbmi_hcache => ahbmi.hcache,
        ahbmi_testen => ahbmi.testen,
        ahbmi_testrst => ahbmi.testrst,
        ahbmi_scanen => ahbmi.scanen,
        -- UHC ahb_slv_in_type unwrapped
        uhc_ahbsi_hsel => ahbslvi_hsel,
        uhc_ahbsi_haddr => ahbsi.haddr,
        uhc_ahbsi_hwrite => ahbsi.hwrite,
        uhc_ahbsi_htrans => ahbsi.htrans,
        uhc_ahbsi_hsize => ahbsi.hsize,
        uhc_ahbsi_hwdata => ahbsi.hwdata,
        uhc_ahbsi_hready => ahbsi.hready,
        uhc_ahbsi_testen => ahbsi.testen,
        uhc_ahbsi_testrst => ahbsi.testrst,
        uhc_ahbsi_scanen => ahbsi.scanen,
        -- EHC ahb_mst_out_type_unwrapped 
        ehc_ahbmo_hbusreq => ehc_ahbmo.hbusreq,
        ehc_ahbmo_hlock => ehc_ahbmo.hlock,
        ehc_ahbmo_htrans => ehc_ahbmo.htrans,
        ehc_ahbmo_haddr => ehc_ahbmo.haddr,
        ehc_ahbmo_hwrite => ehc_ahbmo.hwrite,
        ehc_ahbmo_hsize => ehc_ahbmo.hsize,
        ehc_ahbmo_hburst => ehc_ahbmo.hburst,
        ehc_ahbmo_hprot => ehc_ahbmo.hprot,
        ehc_ahbmo_hwdata => ehc_ahbmo.hwdata,
        -- UHC ahb_mst_out_vector_type unwrapped
        uhc_ahbmo_hbusreq => hbusreq,
        uhc_ahbmo_hlock => hlock,
        uhc_ahbmo_htrans => htrans,
        uhc_ahbmo_haddr => haddr,
        uhc_ahbmo_hwrite => hwrite,
        uhc_ahbmo_hsize => hsize,
        uhc_ahbmo_hburst => hburst,
        uhc_ahbmo_hprot => hprot,
        uhc_ahbmo_hwdata => hwdata,
        -- UHC ahb_slv_out_vector_type unwrapped
        uhc_ahbso_hready => hready,
        uhc_ahbso_hresp => hresp,
        uhc_ahbso_hrdata => hrdata,
        uhc_ahbso_hsplit => hsplit,
        uhc_ahbso_hcache => hcache,
        uhc_ahbso_hirq => uhc_ahbslvo_hirq,
        -- usbhc_out_type_vector unwrapped
        xcvrsel => xcvrsel,
        termsel => termsel,
        suspendm => suspendm,
        opmode => opmode,
        txvalid => txvalid,
        drvvbus => drvvbus,
        dataho => dataho, 
        validho => validho, 
        host => host,     
        stp => stp,     
        datao => datao,   
        utm_rst => utm_rst,
        dctrlo => dctrlo,
        -- usbhc_in_type_vector unwrapped
        linestate => linestate,
        txready => txready,
        rxvalid => rxvalid,
        rxactive => rxactive, 
        rxerror => rxerror, 
        vbusvalid => vbusvalid,
        datahi => datahi,
        validhi => validhi,  
        hostdisc => hostdisc,
        nxt => nxt,
        dir => dir,
        datai => datai,
        -- EHC transaction buffer signals
        mbc20_tb_addr => mbc20_tb_addr,
        mbc20_tb_data => mbc20_tb_data,
        mbc20_tb_en => mbc20_tb_en,
        mbc20_tb_wel => mbc20_tb_wel,
        mbc20_tb_weh => mbc20_tb_weh,
        tb_mbc20_data => tb_mbc20_data,
        pe20_tb_addr => pe20_tb_addr, 
        pe20_tb_data => pe20_tb_data,
        pe20_tb_en => pe20_tb_en,
        pe20_tb_wel => pe20_tb_wel,
        pe20_tb_weh => pe20_tb_weh,
        tb_pe20_data => tb_pe20_data,
        -- EHC packet buffer signals
        mbc20_pb_addr => mbc20_pb_addr,
        mbc20_pb_data => mbc20_pb_data,
        mbc20_pb_en => mbc20_pb_en,
        mbc20_pb_we => mbc20_pb_we,
        pb_mbc20_data => pb_mbc20_data,
        sie20_pb_addr => sie20_pb_addr,
        sie20_pb_data => sie20_pb_data,
        sie20_pb_en => sie20_pb_en,
        sie20_pb_we => sie20_pb_we,
        pb_sie20_data => pb_sie20_data,
        -- UHC packet buffer signals
        sie11_pb_addr => sie11_pb_addr,
        sie11_pb_data => sie11_pb_data,
        sie11_pb_en => sie11_pb_en,
        sie11_pb_we => sie11_pb_we,
        pb_sie11_data => pb_sie11_data,
        mbc11_pb_addr => mbc11_pb_addr,
        mbc11_pb_data => mbc11_pb_data,
        mbc11_pb_en => mbc11_pb_en,
        mbc11_pb_we => mbc11_pb_we,
        pb_mbc11_data => pb_mbc11_data,
        bufsel => bufsel);
  end generate rtl_model;  

  net_model : if netlist = 1 generate
    usbhc0 : usbhc_net
      generic map(
        tech        => tech,
        nports      => nports,
        ehcgen      => ehcgen,
        uhcgen      => uhcgen,
        n_cc        => n_cc,
        n_pcc       => n_pcc,
        prr         => prr,
        portroute1  => portroute1,
        portroute2  => portroute2,
        endian_conv => endian_conv,
        be_regs     => be_regs,
        be_desc     => be_desc,
        uhcblo      => uhcblo,
        bwrd        => bwrd,
        utm_type    => utm_type,
        vbusconf    => vbusconf,
        ramtest     => ramtest,
        urst_time   => urst_time,
        oepol       => oepol,
        scantest    => scantest,
        memtech     => memtech)
      port map(
        clk => clk,
        uclk => uclk,
        rst => rst,
        ursti => ursti,
        -- EHC apb_slv_in_type unwrapped
        ehc_apbsi_psel => apbi.psel(ehcpindex),
        ehc_apbsi_penable => apbi.penable,
        ehc_apbsi_paddr => apbi.paddr,
        ehc_apbsi_pwrite => apbi.pwrite,
        ehc_apbsi_pwdata => apbi.pwdata,
        ehc_apbsi_testen => apbi.testen,
        ehc_apbsi_testrst => apbi.testrst,
        ehc_apbsi_scanen => apbi.scanen,
        -- EHC apb_slv_out_type unwrapped
        ehc_apbso_prdata => ehc_apbo.prdata,
        ehc_apbso_pirq => ehc_apbso_pirq,
        -- EHC/UHC ahb_mst_in_type unwrapped
        ahbmi_hgrant => ahbmsti_hgrant,
        ahbmi_hready => ahbmi.hready,
        ahbmi_hresp => ahbmi.hresp,
        ahbmi_hrdata => ahbmi.hrdata,
        ahbmi_hcache => ahbmi.hcache,
        ahbmi_testen => ahbmi.testen,
        ahbmi_testrst => ahbmi.testrst,
        ahbmi_scanen => ahbmi.scanen,
        -- UHC ahb_slv_in_type unwrapped
        uhc_ahbsi_hsel => ahbslvi_hsel,
        uhc_ahbsi_haddr => ahbsi.haddr,
        uhc_ahbsi_hwrite => ahbsi.hwrite,
        uhc_ahbsi_htrans => ahbsi.htrans,
        uhc_ahbsi_hsize => ahbsi.hsize,
        uhc_ahbsi_hwdata => ahbsi.hwdata,
        uhc_ahbsi_hready => ahbsi.hready,
        uhc_ahbsi_testen => ahbsi.testen,
        uhc_ahbsi_testrst => ahbsi.testrst,
        uhc_ahbsi_scanen => ahbsi.scanen,
        -- EHC ahb_mst_out_type_unwrapped 
        ehc_ahbmo_hbusreq => ehc_ahbmo.hbusreq,
        ehc_ahbmo_hlock => ehc_ahbmo.hlock,
        ehc_ahbmo_htrans => ehc_ahbmo.htrans,
        ehc_ahbmo_haddr => ehc_ahbmo.haddr,
        ehc_ahbmo_hwrite => ehc_ahbmo.hwrite,
        ehc_ahbmo_hsize => ehc_ahbmo.hsize,
        ehc_ahbmo_hburst => ehc_ahbmo.hburst,
        ehc_ahbmo_hprot => ehc_ahbmo.hprot,
        ehc_ahbmo_hwdata => ehc_ahbmo.hwdata,
        -- UHC ahb_mst_out_vector_type unwrapped
        uhc_ahbmo_hbusreq => hbusreq,
        uhc_ahbmo_hlock => hlock,
        uhc_ahbmo_htrans => htrans,
        uhc_ahbmo_haddr => haddr,
        uhc_ahbmo_hwrite => hwrite,
        uhc_ahbmo_hsize => hsize,
        uhc_ahbmo_hburst => hburst,
        uhc_ahbmo_hprot => hprot,
        uhc_ahbmo_hwdata => hwdata,
        -- UHC ahb_slv_out_vector_type unwrapped
        uhc_ahbso_hready => hready,
        uhc_ahbso_hresp => hresp,
        uhc_ahbso_hrdata => hrdata,
        uhc_ahbso_hsplit => hsplit,
        uhc_ahbso_hcache => hcache,
        uhc_ahbso_hirq => uhc_ahbslvo_hirq,
        -- usbhc_out_type_vector unwrapped
        xcvrsel => xcvrsel,
        termsel => termsel,
        suspendm => suspendm,
        opmode => opmode,
        txvalid => txvalid,
        drvvbus => drvvbus,
        dataho => dataho, 
        validho => validho, 
        host => host,     
        stp => stp,     
        datao => datao,   
        utm_rst => utm_rst,
        dctrlo => dctrlo,
        -- usbhc_in_type_vector unwrapped
        linestate => linestate,
        txready => txready,
        rxvalid => rxvalid,
        rxactive => rxactive, 
        rxerror => rxerror, 
        vbusvalid => vbusvalid,
        datahi => datahi,
        validhi => validhi,  
        hostdisc => hostdisc,
        nxt => nxt,
        dir => dir,
        datai => datai,
        -- EHC transaction buffer signals
        mbc20_tb_addr => mbc20_tb_addr,
        mbc20_tb_data => mbc20_tb_data,
        mbc20_tb_en => mbc20_tb_en,
        mbc20_tb_wel => mbc20_tb_wel,
        mbc20_tb_weh => mbc20_tb_weh,
        tb_mbc20_data => tb_mbc20_data,
        pe20_tb_addr => pe20_tb_addr, 
        pe20_tb_data => pe20_tb_data,
        pe20_tb_en => pe20_tb_en,
        pe20_tb_wel => pe20_tb_wel,
        pe20_tb_weh => pe20_tb_weh,
        tb_pe20_data => tb_pe20_data,
        -- EHC packet buffer signals
        mbc20_pb_addr => mbc20_pb_addr,
        mbc20_pb_data => mbc20_pb_data,
        mbc20_pb_en => mbc20_pb_en,
        mbc20_pb_we => mbc20_pb_we,
        pb_mbc20_data => pb_mbc20_data,
        sie20_pb_addr => sie20_pb_addr,
        sie20_pb_data => sie20_pb_data,
        sie20_pb_en => sie20_pb_en,
        sie20_pb_we => sie20_pb_we,
        pb_sie20_data => pb_sie20_data,
        -- UHC packet buffer signals
        sie11_pb_addr => sie11_pb_addr,
        sie11_pb_data => sie11_pb_data,
        sie11_pb_en => sie11_pb_en,
        sie11_pb_we => sie11_pb_we,
        pb_sie11_data => pb_sie11_data,
        mbc11_pb_addr => mbc11_pb_addr,
        mbc11_pb_data => mbc11_pb_data,
        mbc11_pb_en => mbc11_pb_en,
        mbc11_pb_we => mbc11_pb_we,
        pb_mbc11_data => pb_mbc11_data,
        bufsel => bufsel);
  end generate net_model;
    
  -----------------------------------------------------------------------------
  -- Transaction Buffer
  -- If EHC is present a 2048 B transaction buffer is generated otherwise the
  -- transaction buffer is skipped
  -----------------------------------------------------------------------------
  ehc_tb : if ehcgen = 1 generate
    tbhigh : syncram_dp
      generic map(
        tech      => memtech,         
        abits     => 9,
        dbits     => 16)
      port map(
        clk1      => clk,
        address1  => mbc20_tb_addr,
        datain1   => mbc20_tb_data(31 downto 16),
        dataout1  => tb_mbc20_data(31 downto 16),
        enable1   => mbc20_tb_en,
        write1    => mbc20_tb_weh,
        clk2      => uclk,
        address2  => pe20_tb_addr,
        datain2   => pe20_tb_data(31 downto 16),
        dataout2  => tb_pe20_data(31 downto 16),
        enable2   => pe20_tb_en,
        write2    => pe20_tb_weh);
    
    tblow : syncram_dp
      generic map(
        tech      => memtech,         
        abits     => 9,
        dbits     => 16)
      port map(
        clk1      => clk,
        address1  => mbc20_tb_addr,
        datain1   => mbc20_tb_data(15 downto 0),
        dataout1  => tb_mbc20_data(15 downto 0),
        enable1   => mbc20_tb_en,
        write1    => mbc20_tb_wel,
        clk2      => uclk,
        address2  => pe20_tb_addr,
        datain2   => pe20_tb_data(15 downto 0),
        dataout2  => tb_pe20_data(15 downto 0),
        enable2   => pe20_tb_en,
        write2    => pe20_tb_wel);
  end generate ehc_tb;

  ehc_notb: if ehcgen = 0 generate
    tb_mbc20_data <= (others=>'0');
    tb_pe20_data  <= (others=>'0');
  end generate ehc_notb;

  -----------------------------------------------------------------------------
  -- Packet Buffer
  -- Three cases exist:
  -- 1. One port and no EHC => One 1024 B buffer is generated
  -- 2. One port and EHC => One 2048 B buffer which is shared with possible CC
  --                        is generated
  -- 3. Several ports => If EHC is present a 2048 packet buffer is generated.
  --                     Also, independent of EHC presence, one 1024 B buffer
  --                     for each CC is generated
  -----------------------------------------------------------------------------
  ONEPORT: if nports = 1 generate
    -- Case 1
    uhc_pb: if uhcgen = 1 and ehcgen = 0 generate
      p0 : syncram_dp
        generic map(
          tech      => memtech,         
          abits     => 8,
          dbits     => 32)
        port map(
          clk1      => clk,
          address1  => mbc11_pb_addr(8 downto 1),
          datain1   => mbc11_pb_data,
          dataout1  => pb_mbc11_data,
          enable1   => mbc11_pb_en(1),
          write1    => mbc11_pb_we(1),
          clk2      => uclk,
          address2  => sie11_pb_addr(8 downto 1),
          datain2   => sie11_pb_data,
          dataout2  => pb_sie11_data,
          enable2   => sie11_pb_en(1),
          write2    => sie11_pb_we(1));

      pb_sie20_data <= (others=>'0');
      pb_mbc20_data <= (others=>'0');
    end generate uhc_pb;

    -- Case 2
    comb_pb: if ehcgen = 1 generate
      p0 : syncram_dp
        generic map(
          tech      => memtech,         
          abits     => 9,
          dbits     => 32)
        port map(
          clk1      => clk,
          address1  => mbc_pb_addr,
          datain1   => mbc_pb_data,
          dataout1  => pb_mbc_data,
          enable1   => mbc_pb_en,
          write1    => mbc_pb_we,
          clk2      => uclk,
          address2  => sie_pb_addr,
          datain2   => sie_pb_data,
          dataout2  => pb_sie_data,
          enable2   => sie_pb_en,
          write2    => sie_pb_we);      

      uhc_connect: if uhcgen = 1 generate
        -- companion controller present, share buffer
        sie_pb_addr <= sie20_pb_addr when bufsel = '1' else sie11_pb_addr;
        sie_pb_data <= sie20_pb_data when bufsel = '1' else sie11_pb_data;
        sie_pb_en   <= sie20_pb_en when bufsel = '1' else sie11_pb_en(1);
        sie_pb_we   <= sie20_pb_we when bufsel = '1' else sie11_pb_we(1);

        mbc_pb_addr <= mbc20_pb_addr when bufsel = '1' else mbc11_pb_addr;
        mbc_pb_data <= mbc20_pb_data when bufsel = '1' else mbc11_pb_data;
        mbc_pb_en   <= mbc20_pb_en when bufsel = '1' else mbc11_pb_en(1);
        mbc_pb_we   <= mbc20_pb_we when bufsel = '1' else mbc11_pb_we(1);

        pb_sie11_data <= pb_sie_data;
        pb_mbc11_data <= pb_mbc_data;
      end generate uhc_connect;

      uhc_noconnect: if uhcgen = 0 generate
        -- no companion controller present, EHC owns buffer
        sie_pb_addr <= sie20_pb_addr;
        sie_pb_data <= sie20_pb_data;
        sie_pb_en   <= sie20_pb_en;
        sie_pb_we   <= sie20_pb_we;
        
        mbc_pb_addr <= mbc20_pb_addr;
        mbc_pb_data <= mbc20_pb_data;
        mbc_pb_en   <= mbc20_pb_en;
        mbc_pb_we   <= mbc20_pb_we;

        pb_sie11_data <= (others=>'0');
        pb_mbc11_data <= (others=>'0');
      end generate uhc_noconnect;
      
      pb_sie20_data <= pb_sie_data;
      pb_mbc20_data <= pb_mbc_data;
    end generate comb_pb;
  end generate ONEPORT;

  -- Case 3
  MULTIPORT: if nports > 1 generate
    ehc_pb: if ehcgen = 1 generate
      p0 : syncram_dp
        generic map(
          tech      => memtech,         
          abits     => 9,
          dbits     => 32)
        port map(
          clk1      => clk,
          address1  => mbc20_pb_addr,
          datain1   => mbc20_pb_data,
          dataout1  => pb_mbc20_data,
          enable1   => mbc20_pb_en,
          write1    => mbc20_pb_we,
          clk2      => uclk,
          address2  => sie20_pb_addr,
          datain2   => sie20_pb_data,
          dataout2  => pb_sie20_data,
          enable2   => sie20_pb_en,
          write2    => sie20_pb_we);

    end generate ehc_pb;

    noehc_pb: if ehcgen = 0 generate
      pb_sie20_data <= (others=>'0');
      pb_mbc20_data <= (others=>'0');
    end generate noehc_pb;
  
    uhc_pb: if uhcgen = 1 generate
      pbs: for j in 1 to n_cc generate
        p0 : syncram_dp
          generic map(
            tech      => memtech,         
            abits     => 8,
            dbits     => 32)
          port map(
            clk1      => clk,
            address1  => mbc11_pb_addr((9*j)-1 downto (9*(j-1)+1)),
            datain1   => mbc11_pb_data(32*j downto (32*(j-1)+1)),
            dataout1  => pb_mbc11_data(32*j downto (32*(j-1)+1)),
            enable1   => mbc11_pb_en(j),
            write1    => mbc11_pb_we(j),
            clk2      => uclk,
            address2  => sie11_pb_addr((9*j)-1 downto (9*(j-1)+1)),
            datain2   => sie11_pb_data(32*j downto (32*(j-1)+1)),
            dataout2  => pb_sie11_data(32*j downto (32*(j-1)+1)),
            enable2   => sie11_pb_en(j),
            write2    => sie11_pb_we(j));
      end generate;
    end generate uhc_pb;

    nouhc_pb: if uhcgen = 0 generate
      pb_sie11_data <= (others=>'0');
      pb_mbc11_data <= (others=>'0');
    end generate nouhc_pb;

    -- Only used in one-port configuraton
    mbc_pb_addr <= (others=>'0');
    mbc_pb_data <= (others=>'0');
    mbc_pb_en   <= '0';
    mbc_pb_we   <= '0';
    pb_mbc_data <= (others=>'0');
    sie_pb_addr <= (others=>'0');
    sie_pb_data <= (others=>'0');
    sie_pb_en   <= '0';
    sie_pb_we   <= '0';
    pb_sie_data <= (others=>'0');
  end generate MULTIPORT;        
end rtl;
