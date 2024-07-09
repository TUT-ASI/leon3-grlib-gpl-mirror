------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
-- Entity: 	rgmii
-- File:	rgmii.vhd
-- Author:	Fredrik Ringhage - Cobham Gaisler
-- Description: MII/GMII to RGMII interface for Xilinx Series 7
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library gaisler;
use gaisler.net.all;
use gaisler.misc.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;

library techmap;
use techmap.gencomp.all;
use techmap.allclkgen.all;

library eth;
use eth.grethpkg.all;

entity rgmii_series6 is
  generic (
    pindex         : integer := 0;
    paddr          : integer := 0;
    pmask          : integer := 16#fff#;
    tech           : integer := 0;
    gmii           : integer := 0;
    abits          : integer := 8;
    pirq           : integer := 0;
    base10_x       : integer := 0        -- Default no support for 10Mb
    );
  port (
    rstn     : in  std_ulogic;
    gmiii    : out eth_in_type;
    gmiio    : in  eth_out_type;
    rgmiii   : in  eth_in_type;
    rgmiio   : out eth_out_type;
    -- APB Status bus
    apb_clk  : in    std_logic;
    apb_rstn : in    std_logic;
    apbi     : in    apb_slv_in_type;
    apbo     : out   apb_slv_out_type;
    -- Debug Out
    debug_rgmii_phy_tx : out std_logic_vector(31 downto 0);
    debug_rgmii_phy_rx : out std_logic_vector(31 downto 0)
    );
end ;

architecture rtl of rgmii_series6 is

  constant REVISION : integer := 2;

  constant pconfig : apb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_RGMII, 0, REVISION, pirq),
    1 => apb_iobar(paddr, pmask));

  type status_vector_type is array(1 downto 0) of std_logic_vector(15 downto 0);

  type rgmiiregs is record
    irq                 :  std_logic_vector(15 downto 0); -- interrupt
    mask                :  std_logic_vector(15 downto 0); -- interrupt enable
    q1_sel              :  std_logic_vector(3 downto 0);
    clk_sel             :  std_logic_vector(3 downto 0);
    status_vector       :  status_vector_type;
  end record;

  signal r_clk_sel      : std_logic_vector(1 downto 0);

  -- Global signal
  signal vcc, gnd : std_ulogic;
  signal tx_en, tx_ctl : std_ulogic;
  signal tx_end : std_ulogic;
  signal txd : std_logic_vector(7 downto 0);
  signal rxd, rxd_pre, rxd_int,rxd_int_d : std_logic_vector(7 downto 0);
  signal rx_clk, rx_clkn : std_ulogic;
  signal rx_dv, rx_dv_pre, rx_dv_int, rx_dv_int_d, rx_ctl, rx_ctl_pre, rx_ctl_int, rx_ctl_int_d, rx_error : std_logic;
  signal tx_clk,tx_clko, tx_clkn, tx_clkon, clk10_100, clk10_100o : std_ulogic;
  signal rsttxclk: std_logic;

  -- RGMII Inband status signals
  signal inbandopt,inbandreq  : std_logic;
  signal link_status          : std_logic;
  signal clock_speed          : std_logic_vector(1 downto 0);
  signal duplex_status        : std_logic;
  signal false_carrier_ind    : std_logic;
  signal carrier_ext          : std_logic;
  signal carrier_ext_error    : std_logic;
  signal carrier_sense        : std_logic;

  -- Status signals and Clock domain crossing
  signal status_vector      : std_logic_vector(15 downto 0);
  signal status_vector_sync : std_logic_vector(15 downto 0);
  
  -- APB and RGMII control register
  constant RESET_ALL : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

  --  Series7 settings for KC705/VC707 Dev Board
  constant RES_series7 : rgmiiregs :=
  ( irq => (others => '0'), mask => (others => '0'), q1_sel => (others => '0'), clk_sel => "0101",
    status_vector => (others => (others => '0')));
  
  constant RES_spartan6 : rgmiiregs :=
  ( irq => (others => '0'), mask => (others => '0'), q1_sel => "0000", clk_sel => "0101",
    status_vector => (others => (others => '0')));

  signal r, rin : rgmiiregs;

  -- Internal clock gen
  signal counter :  unsigned(4 downto 0); 
  signal clk_int,clk_int2,tx_clk2_5 :  std_logic; 

begin  -- rtl

  vcc <= '1'; gnd <= '0';

  ---------------------------------------------------------------------------------------
  -- MDIO path
  ---------------------------------------------------------------------------------------

  debug_rgmii_phy_tx(31)           <= tx_clk;
  debug_rgmii_phy_tx(30 downto 10) <= (others => '0');
  debug_rgmii_phy_tx(9 downto 8)   <= tx_en & tx_ctl;
  debug_rgmii_phy_tx(7 downto 0)   <= txd;
  
  debug_rgmii_phy_rx(31)           <= rgmiii.rx_clk;
  debug_rgmii_phy_rx(30)           <= '0';
  debug_rgmii_phy_rx(29)           <= rx_ctl_int;
  debug_rgmii_phy_rx(28)           <= rx_ctl_int_d;
  debug_rgmii_phy_rx(27)           <= rx_dv_int;
  debug_rgmii_phy_rx(26)           <= rx_dv_int_d;
  debug_rgmii_phy_rx(25)           <= rx_error;
  debug_rgmii_phy_rx(24)           <= rx_dv;
  debug_rgmii_phy_rx(23 downto 16) <= rxd;
  debug_rgmii_phy_rx(15 downto 8)  <= rxd_int;
  debug_rgmii_phy_rx(7 downto 0)   <= rxd_int_d;
 
  ---------------------------------------------------------------------------------------
  -- MDIO path
  ---------------------------------------------------------------------------------------

  gmiii.mdint    <= rgmiii.mdint;
  gmiii.mdio_i   <= rgmiii.mdio_i;
  rgmiio.mdio_o  <= gmiio.mdio_o;
  rgmiio.mdio_oe <= gmiio.mdio_oe;
  rgmiio.mdc     <= gmiio.mdc;

  ---------------------------------------------------------------------------------------
  -- TX path
  ---------------------------------------------------------------------------------------

  -- Generate TX clocks.

  support10 : if base10_x = 1 generate
     -- Generate local TX clock for 10Mbit
     process (rstn,rgmiii.tx_clk_25)
     begin
       if (rstn = '0') then
         counter <= (others => '0');
         clk_int   <= '0';
         tx_clk2_5  <= '0';
       elsif rising_edge(rgmiii.tx_clk_25) then
         if (counter  >= 4) then
           counter   <= (others => '0');
           clk_int   <= not clk_int;
           tx_clk2_5 <= not clk_int;
         else
           counter   <= counter + 1;
           clk_int   <= clk_int;
           tx_clk2_5 <= clk_int;
         end if;
       end if;
     end process;
   
     -- Select transmit clock and GRETH clock
     clkmux10_100   : clkmux generic map (tech => tech) port map (tx_clk2_5,rgmiii.tx_clk_25,gmiio.speed,clk10_100,'1');  
     clkmux10_100_o : clkmux generic map (tech => tech) port map (tx_clk2_5,rgmiii.tx_clk_50,gmiio.speed,clk10_100o,'1');  
  end generate;

  no10support : if base10_x = 0 generate
     counter    <= (others => '0');
     clk_int    <= '0';
     clk_int2   <= '0';
     tx_clk2_5  <= '0';
     clk10_100  <=  rgmiii.tx_clk_25;   
     clk10_100o <=  rgmiii.tx_clk_50;   
  end generate;

  clkmux1000     : clkmux generic map (tech => tech) port map (clk10_100, rgmiii.gtx_clk  , gmiio.gbit, tx_clk ,'1');
  clkmux1000_o   : clkmux generic map (tech => tech) port map (clk10_100o,rgmiii.tx_clk_90, gmiio.gbit, tx_clko,'1');

  gmiii.gtx_clk <= rgmiii.gtx_clk;
  gmiii.tx_clk  <= clk10_100;
  gmiii.tx_dv   <= '1'; 

  -- Generate RGMII control signal and check data rate
  process (tx_clk,rstn)
  begin  -- process
    if (rstn = '0') then
      tx_en  <= '0';
      tx_end <= '0';
      tx_ctl <= '0';
      txd    <= (others => '0');
    elsif rising_edge(tx_clk) then
    tx_end <= gmiio.tx_en; 
     if (gmiio.tx_en = '1') and (tx_end = '0') then
      tx_en  <= gmiio.tx_en;
      tx_ctl <= gmiio.tx_en xor gmiio.tx_er;   
      txd    <= gmiio.txd;
     elsif (gmiio.tx_en = '0') and (tx_end = '0') then
      tx_en  <= '0';
      tx_ctl <= '0';   
      txd    <= (others => '0');     
     else
      tx_en  <= gmiio.tx_en;
      tx_ctl <= gmiio.tx_en xor gmiio.tx_er;   
       if (r.q1_sel(2) = '0') then
        txd <= gmiio.txd(3 downto 0) & gmiio.txd(7 downto 4);   
       else
        txd <= gmiio.txd;  
       end if;
     end if; 
    end if;
    end process;

  process (tx_clko)
    begin  -- process
    if gmiio.gbit = '1' then
      r_clk_sel <= r.clk_sel(1 downto 0);
    else
      r_clk_sel <= r.clk_sel(3 downto 2);
    end if;
  end process;

  -- Reset for Outputs
  rsttxclk <= not rstn;
  tx_clkn  <= not tx_clk;
  tx_clkon  <= not tx_clko;

   -- DDR outputs and local inverted clock
   -- TXC, TXD and TXCTL is sync'd to the generated TX clock     
   rgmii_txd : for i in 0 to 3 generate
       ddr_oreg0 : ddr_oreg generic map (tech, arch => 1)
         port map (q => rgmiio.txd(i), c1 => tx_clk, c2 => tx_clkn, ce => vcc,
                   d1 => txd(i+4), d2 => txd(i), r => rsttxclk, s => gnd);
   end generate;
   
   rgmii_tx_ctl : ddr_oreg generic map (tech, arch => 1)
         port map (q => rgmiio.tx_en, c1 => tx_clk, c2 => tx_clkn, ce => vcc,
                   d1 => tx_en, d2 => tx_ctl, r => rsttxclk, s => gnd);

  rgmii_tx_clk : ddr_oreg generic map (tech, arch => 1)
  port map (q => rgmiio.tx_clk, c1 => tx_clko, c2 => tx_clkon, ce => vcc,
            d1 => r_clk_sel(0), d2 => r_clk_sel(1), r => rsttxclk, s => gnd);

  rgmiio.tx_er  <= '0';
  rgmiio.reset  <= rstn;
  rgmiio.gbit   <= gmiio.gbit;
  rgmiio.speed  <= gmiio.speed when (gmii = 1) else '0';

  -- Not used in RGMII mode
  rgmiio.txd(7 downto 4) <= (others => '0');

  ---------------------------------------------------------------------------------------
  -- RX path
  ---------------------------------------------------------------------------------------

  -- Rx Clocks
  rx_clk <= rgmiii.rx_clk;
  rx_clkn <= not rgmiii.rx_clk;

  -- DDR inputs
  rgmii_rxd : for i in 0 to 3 generate
       ddr_ireg0 : ddr_ireg generic map (tech, arch => 1)
         Port map( Q1 => rxd_pre(i+0), Q2 => rxd_pre(i+4), C1 => rx_clk, C2 => rx_clkn, CE => vcc,
                   D => rgmiii.rxd(i), R => gnd, S => gnd);
  end generate;
  
   process (rx_clk,rstn)
     begin
       if rstn = '0' then
         rxd_int    <= (others => '0');        
         rxd_int_d  <= (others => '0');        
       elsif rising_edge(rx_clk) then
        rxd_int_d <= rxd_pre;
        if (r.q1_sel(3) = '1') then
            if (gmiio.gbit = '1') then
              rxd_int  <= rxd_pre(3 downto 0) & rxd_int_d(7 downto 4);
            else
              rxd_int  <= rxd_pre;
            end if;
          else
            rxd_int  <= rxd_pre;
          end if;  
       end if;
   end process;

  rxd(3 downto 0) <= rxd_int(3 downto 0) when (r.q1_sel(0) = '0') else rxd_int(7 downto 4);
  rxd(7 downto 4) <= rxd_int(7 downto 4) when (r.q1_sel(0) = '0') else rxd_int(3 downto 0);

  ddr_dv0 : ddr_ireg generic map (tech, arch => 1)
       Port map( Q1 => rx_ctl_pre, Q2 => rx_dv_pre, C1 => rx_clk, C2 => rx_clkn, CE => vcc,
                 D => rgmiii.rx_dv, R => gnd, S => gnd);
  
  process (rx_clk,rstn)
  begin
     if rstn = '0' then
       rx_ctl_int   <= '0';
       rx_dv_int    <= '0';      
       rx_ctl_int_d <= '0';
       rx_dv_int_d  <= '0';      
     elsif rising_edge(rx_clk) then
      rx_ctl_int_d  <= rx_ctl_pre;
      rx_dv_int_d   <= rx_dv_pre;
      if (r.q1_sel(3) = '1') then
        if (gmiio.gbit = '1') then
          rx_ctl_int  <= rx_dv_int_d;
          rx_dv_int   <= rx_ctl_pre;
        else
          rx_ctl_int  <= rx_ctl_pre;
          rx_dv_int   <= rx_dv_pre;          
        end if;
      else
        rx_ctl_int  <= rx_ctl_pre;
        rx_dv_int   <= rx_dv_pre;
      end if;  
    end if;
  end process;

  rx_dv  <= rx_dv_int   when (r.q1_sel(1) = '1') else rx_ctl_int;
  rx_ctl <= rx_ctl_int  when (r.q1_sel(1) = '1') else rx_dv_int;

  -- Decode GMII error signal
  rx_error <= rx_dv and not rx_ctl;

  -- Enable inband status registers during Interframe Gap
  inbandopt <= not ( rx_dv or rx_error );
  inbandreq <= rx_dv and not rx_dv;

  -- Sample RGMII inband information
  process (rx_clk,rstn)
   begin
    if rstn = '0' then
     link_status       <= '0';
     clock_speed       <= "00";
     duplex_status     <= '0';
     false_carrier_ind <= '0';
     carrier_ext_error <= '0';
     carrier_ext       <= '0';
     carrier_sense     <= '0';
    elsif rising_edge(rx_clk) then
      if (inbandopt = '1') then
         link_status   <= rxd(0);
         clock_speed   <= rxd(2 downto 1);
         duplex_status <= rxd(3);
      end if;
      if (inbandreq = '1') then
         if (rxd = x"0E") then false_carrier_ind <= '1'; else false_carrier_ind <= '0'; end if;
         if (rxd = x"0F") then carrier_ext       <= '1'; else carrier_ext       <= '0'; end if;
         if (rxd = x"1F") then carrier_ext_error <= '1'; else carrier_ext_error <= '0'; end if;
         if (rxd = x"FF") then carrier_sense     <= '1'; else carrier_sense     <= '0'; end if;
      end if;
    end if;
  end process;

  -- GMII output
  gmiii.rxd      <= rxd;
  gmiii.rx_dv    <= rx_dv;
  gmiii.rx_er    <= rx_error;
  gmiii.rx_clk   <= rx_clk;
  gmiii.rx_col   <= '0';
  gmiii.rx_crs   <= rx_dv;
  gmiii.rmii_clk <= '0';
  gmiii.rx_en    <= '1';

  -- GMII output controlled via generics
  gmiii.edclsepahb  <= '0';
  gmiii.edcldisable <= '0';
  gmiii.phyrstaddr  <= (others => '0');
  gmiii.edcladdr    <= (others => '0');

  ---------------------------------------------------------------------------------------
  -- APB Section
  ---------------------------------------------------------------------------------------

  apbo.pindex  <= pindex;
  apbo.pconfig <= pconfig;

  -- Status Register
  status_vector_sync(15) <= '0';
  status_vector_sync(14) <= '0';
  status_vector_sync(13) <= '1' when (gmii = 1      ) else '0';
  status_vector_sync(12 downto 10) <= (others => '0');
  status_vector_sync(9) <= gmiio.gbit;
  status_vector_sync(8) <= gmiio.speed;
  status_vector_sync(7) <= carrier_sense;
  status_vector_sync(6) <= carrier_ext_error;
  status_vector_sync(5) <= carrier_ext;
  status_vector_sync(4) <= false_carrier_ind;
  status_vector_sync(3) <= duplex_status;
  status_vector_sync(2) <= clock_speed(1);
  status_vector_sync(1) <= clock_speed(0);
  status_vector_sync(0) <= link_status;

  -- CDC clock domain crossing
  syncreg_status : for i in 0 to status_vector'length-1 generate
     syncreg3 : syncreg port map (tx_clk, status_vector_sync(i), status_vector(i));
  end generate;

  rgmiiapb : process(apb_rstn, r, apbi, status_vector )
  variable rdata    : std_logic_vector(31 downto 0);
  variable paddress : std_logic_vector(7 downto 2);
  variable v        : rgmiiregs;
  begin

    v := r;
    paddress := (others => '0');
    paddress(abits-1 downto 2) := apbi.paddr(abits-1 downto 2);
    rdata := (others => '0');

    v.status_vector(1) := r.status_vector(0);
    v.status_vector(0) := status_vector;

    -- read/write registers

    if (apbi.psel(pindex) and apbi.penable and (not apbi.pwrite)) = '1' then
      case paddress(7 downto 2) is
      when "000000" =>
      rdata(31 downto 16) := x"0406";
      rdata(15 downto 0)  := r.status_vector(0);
      when "000001" =>
        rdata(15 downto 0) := r.irq;
        v.irq := (others => '0');  -- Interrupt is clear on read
      when "000010" =>
        rdata(15 downto 0) := r.mask;
      when "000011" =>
         rdata(3 downto 0) := r.q1_sel(3 downto 0);
      when "000100" =>
         rdata(1 downto 0) := r.clk_sel(1 downto 0);
      when "000101" =>
         rdata(1 downto 0) := r.clk_sel(3 downto 2);
      when others =>
        null;
      end case;
    end if;

    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
      case paddress(7 downto 2) is
      when "000000" =>
         null;
      when "000001" =>
         null;
      when "000010" =>
         v.mask := apbi.pwdata(15 downto 0);
      when "000011" =>
         v.q1_sel   := apbi.pwdata(3 downto 0);
      when "000100" =>
         v.clk_sel(1 downto 0)  := apbi.pwdata(1 downto 0);
      when "000101" =>
         v.clk_sel(3 downto 2)  := apbi.pwdata(1 downto 0);
      when others =>
        null;
      end case;
    end if;

    -- Check interrupts
    for i in 0 to r.status_vector'length-1 loop
     if  ((r.status_vector(0)(i) xor r.status_vector(1)(i)) and r.mask(i)) = '1' then
       v.irq(i) :=  '1';
     end if;
    end loop;

    -- reset operation
    if (not RESET_ALL) and (apb_rstn = '0') then
      if (tech = spartan6) then
        v := RES_spartan6;
      else
        v := RES_series7;
      end if;  
    end if;

    -- update registers
    rin <= v;

    -- drive outputs
    apbo.prdata  <= rdata;
    apbo.pirq <= (others => '0');
    apbo.pirq(pirq) <=  orv(v.irq);

  end process;

    regs : process(apb_clk)
    begin
      if rising_edge(apb_clk) then
        r <= rin;
        if RESET_ALL and apb_rstn = '0' then
          if (tech = spartan6) then
            r <= RES_spartan6;
          else
            r <= RES_series7;
          end if;
        end if;
      end if;
    end process;

-- pragma translate_off
    bootmsg : report_version
    generic map ("rgmii" & tost(pindex) &
        ": RGMII rev " & tost(REVISION) & ", irq " & tost(pirq));
-- pragma translate_on

end rtl;

