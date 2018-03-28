------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2010, Aeroflex Gaisler
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
-- Entity: 	grspwc2_unisim
-- File:	grspwc2_unisim.vhd
-- Author:	Jiri Gaisler - Gaisler Research 
-- Description: tech wrapper for xilinx/unisim grspwc2 netlist
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.all;

entity grspwc2_unisim is
  generic(
    rmap         : integer range 0 to 1  := 0;
    rmapcrc      : integer range 0 to 1  := 0;
    fifosize1    : integer range 4 to 32 := 32;
    fifosize2    : integer range 16 to 64 := 64;
    rxunaligned  : integer range 0 to 1 := 0;
    rmapbufs     : integer range 2 to 8 := 4;
    scantest     : integer range 0 to 1 := 0;
    ports        : integer range 1 to 2 := 1;
    dmachan      : integer range 1 to 4 := 1;
    tech         : integer;
    input_type   : integer range 0 to 3 := 0;
    output_type  : integer range 0 to 2 := 0;
    rxtx_sameclk : integer range 0 to 1 := 0
  );
  port(
    rst          : in  std_ulogic;
    clk          : in  std_ulogic;
    rxclk        : in  std_logic_vector(1 downto 0);
    txclk        : in  std_ulogic;
    txclkn       : in  std_ulogic;
    --ahb mst in
    hgrant       : in  std_ulogic;
    hready       : in  std_ulogic;   
    hresp        : in  std_logic_vector(1 downto 0);
    hrdata       : in  std_logic_vector(31 downto 0); 
    --ahb mst out
    hbusreq      : out  std_ulogic;        
    hlock        : out  std_ulogic;
    htrans       : out  std_logic_vector(1 downto 0);
    haddr        : out  std_logic_vector(31 downto 0);
    hwrite       : out  std_ulogic;
    hsize        : out  std_logic_vector(2 downto 0);
    hburst       : out  std_logic_vector(2 downto 0);
    hprot        : out  std_logic_vector(3 downto 0);
    hwdata       : out  std_logic_vector(31 downto 0);
    --apb slv in 
    psel	 : in   std_ulogic;
    penable	 : in   std_ulogic;
    paddr	 : in   std_logic_vector(31 downto 0);
    pwrite	 : in   std_ulogic;
    pwdata	 : in   std_logic_vector(31 downto 0);
    --apb slv out
    prdata	 : out  std_logic_vector(31 downto 0);
    --spw in
    d            : in   std_logic_vector(3 downto 0);
    dv           : in   std_logic_vector(3 downto 0);
    dconnect     : in   std_logic_vector(3 downto 0);
    --spw out
    do           : out  std_logic_vector(3 downto 0);
    so           : out  std_logic_vector(3 downto 0);
    --time iface
    tickin       : in   std_ulogic;
    tickout      : out  std_ulogic;
    --irq
    irq          : out  std_logic;
    --misc     
    clkdiv10     : in   std_logic_vector(7 downto 0);
    dcrstval     : in   std_logic_vector(9 downto 0);
    timerrstval  : in   std_logic_vector(11 downto 0);
    --rmapen
    rmapen       : in   std_ulogic;
    --rx ahb fifo
    rxrenable    : out  std_ulogic;
    rxraddress   : out  std_logic_vector(4 downto 0);
    rxwrite      : out  std_ulogic;
    rxwdata      : out  std_logic_vector(31 downto 0);
    rxwaddress   : out  std_logic_vector(4 downto 0);
    rxrdata      : in   std_logic_vector(31 downto 0);    
    --tx ahb fifo
    txrenable    : out  std_ulogic;
    txraddress   : out  std_logic_vector(4 downto 0);
    txwrite      : out  std_ulogic;
    txwdata      : out  std_logic_vector(31 downto 0);
    txwaddress   : out  std_logic_vector(4 downto 0);
    txrdata      : in   std_logic_vector(31 downto 0);    
    --nchar fifo
    ncrenable    : out  std_ulogic;
    ncraddress   : out  std_logic_vector(5 downto 0);
    ncwrite      : out  std_ulogic;
    ncwdata      : out  std_logic_vector(9 downto 0);
    ncwaddress   : out  std_logic_vector(5 downto 0);
    ncrdata      : in   std_logic_vector(9 downto 0);
    --rmap buf
    rmrenable    : out  std_ulogic;
    rmraddress   : out  std_logic_vector(7 downto 0);
    rmwrite      : out  std_ulogic;
    rmwdata      : out  std_logic_vector(7 downto 0);
    rmwaddress   : out  std_logic_vector(7 downto 0);
    rmrdata      : in   std_logic_vector(7 downto 0);
    linkdis      : out  std_ulogic;
    testclk      : in   std_ulogic := '0';
    testrst      : in   std_ulogic := '0';
    testen       : in   std_ulogic := '0'
  );
end entity;

architecture rtl of grspwc2_unisim is

component grspwc2_unisim_rmap_16_16
port(
  rst :  in std_logic;
  clk :  in std_logic;
  rxclk : in std_logic_vector(1 downto 0);
  txclk :  in std_logic;
  txclkn :  in std_logic;
  hgrant :  in std_logic;
  hready :  in std_logic;
  hresp : in std_logic_vector(1 downto 0);
  hrdata : in std_logic_vector(31 downto 0);
  hbusreq :  out std_logic;
  hlock :  out std_logic;
  htrans : out std_logic_vector(1 downto 0);
  haddr : out std_logic_vector(31 downto 0);
  hwrite :  out std_logic;
  hsize : out std_logic_vector(2 downto 0);
  hburst : out std_logic_vector(2 downto 0);
  hprot : out std_logic_vector(3 downto 0);
  hwdata : out std_logic_vector(31 downto 0);
  psel :  in std_logic;
  penable :  in std_logic;
  paddr : in std_logic_vector(31 downto 0);
  pwrite :  in std_logic;
  pwdata : in std_logic_vector(31 downto 0);
  prdata : out std_logic_vector(31 downto 0);
  d : in std_logic_vector(3 downto 0);
  dv : in std_logic_vector(3 downto 0);
  dconnect : in std_logic_vector(3 downto 0);
  do : out std_logic_vector(3 downto 0);
  so : out std_logic_vector(3 downto 0);
  tickin :  in std_logic;
  tickout :  out std_logic;
  irq :  out std_logic;
  clkdiv10 : in std_logic_vector(7 downto 0);
  dcrstval : in std_logic_vector(9 downto 0);
  timerrstval : in std_logic_vector(11 downto 0);
  rmapen :  in std_logic;
  rxrenable :  out std_logic;
  rxraddress : out std_logic_vector(4 downto 0);
  rxwrite :  out std_logic;
  rxwdata : out std_logic_vector(31 downto 0);
  rxwaddress : out std_logic_vector(4 downto 0);
  rxrdata : in std_logic_vector(31 downto 0);
  txrenable :  out std_logic;
  txraddress : out std_logic_vector(4 downto 0);
  txwrite :  out std_logic;
  txwdata : out std_logic_vector(31 downto 0);
  txwaddress : out std_logic_vector(4 downto 0);
  txrdata : in std_logic_vector(31 downto 0);
  ncrenable :  out std_logic;
  ncraddress : out std_logic_vector(5 downto 0);
  ncwrite :  out std_logic;
  ncwdata : out std_logic_vector(9 downto 0);
  ncwaddress : out std_logic_vector(5 downto 0);
  ncrdata : in std_logic_vector(9 downto 0);
  rmrenable :  out std_logic;
  rmraddress : out std_logic_vector(7 downto 0);
  rmwrite :  out std_logic;
  rmwdata : out std_logic_vector(7 downto 0);
  rmwaddress : out std_logic_vector(7 downto 0);
  rmrdata : in std_logic_vector(7 downto 0);
  linkdis :  out std_logic;
  testclk :  in std_logic;
  testrst :  in std_logic;
  testen :  in std_logic);
end component;

begin

rmap_f16_16 : if (fifosize1 = 16) and (fifosize2 = 16) and (rmap /= 0) generate
    grspwc20 : grspwc2_unisim_rmap_16_16
    port map(
      rst          => rst,
      clk          => clk,
      rxclk        => rxclk,
      txclk        => txclk,
      txclkn       => txclkn,
      --ahb mst in
      hgrant       => hgrant,
      hready       => hready,   
      hresp        => hresp,
      hrdata       => hrdata,
      --ahb mst out
      hbusreq      => hbusreq,
      hlock        => hlock,
      htrans       => htrans,
      haddr        => haddr,
      hwrite       => hwrite,
      hsize        => hsize,
      hburst       => hburst,
      hprot        => hprot,
      hwdata       => hwdata,
      --apb slv in 
      psel	   => psel,
      penable	   => penable,
      paddr	   => paddr,
      pwrite	   => pwrite,
      pwdata	   => pwdata,
      --apb slv out
      prdata       => prdata,
      --spw in
      d            => d,
      dv           => dv,
      dconnect  => dconnect,
      --spw out
      do           => do,
      so           => so,
      --time iface
      tickin       => tickin,
      tickout      => tickout,
      --irq
      irq          => irq,
      --misc     
      clkdiv10     => clkdiv10,
      dcrstval     => dcrstval,
      timerrstval  => timerrstval,
      --rmapen    
      rmapen       => rmapen, 
      --rx ahb fifo
      rxrenable    => rxrenable,
      rxraddress   => rxraddress, 
      rxwrite      => rxwrite,
      rxwdata      => rxwdata, 
      rxwaddress   => rxwaddress,
      rxrdata      => rxrdata,  
      --tx ahb fifo
      txrenable    => txrenable,
      txraddress   => txraddress, 
      txwrite      => txwrite,
      txwdata      => txwdata, 
      txwaddress   => txwaddress,
      txrdata      => txrdata,  
      --nchar fifo
      ncrenable    => ncrenable,
      ncraddress   => ncraddress, 
      ncwrite      => ncwrite,
      ncwdata      => ncwdata, 
      ncwaddress   => ncwaddress,
      ncrdata      => ncrdata,  
      --rmap buf
      rmrenable    => rmrenable,
      rmraddress   => rmraddress, 
      rmwrite      => rmwrite,
      rmwdata      => rmwdata, 
      rmwaddress   => rmwaddress,
      rmrdata      => rmrdata,
      linkdis      => linkdis,
      testclk      => testclk,
      testrst      => testrst,
      testen       => testen
      );
end generate;

-- pragma translate_off

  err : process 
  begin
    assert (fifosize1 = 16) and (fifosize2 = 16) 
	report "ERROR : AHB and RX fifos must be 16!"
    severity failure;
    assert (input_type = 3) and (output_type = 0) and (rxtx_sameclk = 1) 
	report "ERROR : input type must be 3, output type 0, rxtx_sameclk 1!"
    severity failure;
    assert ((rmap = 1) and (rmapbufs = 4)) or (rmap = 0) report "ERROR : RMAP buffer size must be 128 bytes!"
    severity failure;
    assert (ports = 1) report "ERROR : Number of ports must be 1!"
    severity failure;
    wait;
  end process;

-- pragma translate_on

end architecture;
