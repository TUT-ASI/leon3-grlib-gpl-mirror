-----------------------------------------------------------------------------
--  LEON3 Demonstration design
--  Copyright (C) 2004 Jiri Gaisler, Gaisler Research
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
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use work.config.all;
library techmap;
use techmap.gencomp.all;
use techmap.allclkgen.all;

entity leon3mp is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    clktech   : integer := CFG_CLKTECH;
    disas     : integer := CFG_DISAS;	-- Enable disassembly to console
    dbguart   : integer := CFG_DUART;	-- Print UART on console
    pclow     : integer := CFG_PCLOW
  );
  port (
    resetn	: in  std_ulogic;
    clk		: in  std_ulogic;
    errorn	: inout std_ulogic;
    wdogn  	: inout std_ulogic;

    address 	: out   std_logic_vector(27 downto 0);
    data	: inout std_logic_vector(31 downto 0);
    cb   	: inout std_logic_vector(7 downto 0);

    sdclk  	: out std_ulogic;
    sdcke  	: out std_logic_vector (1 downto 0);    -- sdram chip select
    sdcsn  	: out std_logic_vector (1 downto 0);    -- sdram chip select
    sdwen  	: out std_ulogic;                       -- sdram write enable
    sdrasn  	: out std_ulogic;                       -- sdram ras
    sdcasn  	: out std_ulogic;                       -- sdram cas
    sddqm   	: out std_logic_vector (3 downto 0);    -- sdram dqm
    dsutx  	: out std_ulogic; 			-- DSU tx data / scanout
    dsurx  	: in  std_ulogic;  			-- DSU rx data / scanin
    dsuen   	: in std_ulogic;
    dsubre  	: in std_ulogic;			-- DSU break / scanen
    dsuact  	: out std_ulogic;			-- DSU active / NT
    txd1   	: out std_ulogic; 			-- UART1 tx data
    rxd1   	: in  std_ulogic;  			-- UART1 rx data

    ramsn  	: out std_logic_vector (4 downto 0);
    ramoen 	: out std_logic_vector (4 downto 0);
    rwen   	: out std_logic_vector (3 downto 0);
    oen    	: out std_ulogic;
    writen 	: inout std_ulogic;
    read   	: out std_ulogic;
    iosn   	: out std_ulogic;
    romsn  	: out std_logic_vector (1 downto 0);
    brdyn  	: in  std_ulogic;
    bexcn  	: in  std_ulogic;
    gpio        : inout std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0); 	-- I/O port

    emdio     	: inout std_logic;		-- ethernet PHY interface
    etx_clk 	: in std_ulogic;
    erx_clk 	: in std_ulogic;
    erxd    	: in std_logic_vector(3 downto 0);   
    erx_dv  	: in std_ulogic; 
    erx_er  	: in std_ulogic; 
    erx_col 	: in std_ulogic;
    erx_crs 	: in std_ulogic;
    etxd 	: out std_logic_vector(3 downto 0);   
    etx_en 	: out std_ulogic; 
    etx_er 	: out std_ulogic; 
    emdc 	: out std_ulogic;

    pci_rst     : in std_ulogic;		-- PCI bus
    pci_clk 	: in std_ulogic;
    pci_gnt     : in std_ulogic;
    pci_idsel   : in std_ulogic; 
    pci_ad 	: inout std_logic_vector(31 downto 0);
    pci_cbe 	: inout std_logic_vector(3 downto 0);
    pci_frame   : inout std_ulogic;
    pci_irdy 	: inout std_ulogic;
    pci_trdy 	: inout std_ulogic;
    pci_devsel  : inout std_ulogic;
    pci_stop 	: inout std_ulogic;
    pci_perr 	: inout std_ulogic;
    pci_par 	: inout std_ulogic;    
    pci_req 	: out std_ulogic;
    pci_host   	: in std_ulogic;

    pci_arb_req	: in  std_logic_vector(0 to CFG_PCI_ARB_NGNT-1);
    pci_arb_gnt	: out std_logic_vector(0 to CFG_PCI_ARB_NGNT-1);

    can_txd	: out std_logic_vector(0 to CFG_CAN_NUM-1);
    can_rxd	: in  std_logic_vector(0 to CFG_CAN_NUM-1);

--    spw_clk	: in  std_ulogic;
--    spw_rxd     : in  std_logic_vector(0 to CFG_SPW_NUM-1);
--    spw_rxs     : in  std_logic_vector(0 to CFG_SPW_NUM-1);
--    spw_txd     : out std_logic_vector(0 to CFG_SPW_NUM-1);
--    spw_txs     : out std_logic_vector(0 to CFG_SPW_NUM-1);

--    tck         : in std_ulogic;
--    tms         : in std_ulogic;
--    tdi         : in std_ulogic;
--    tdo         : out std_ulogic;

--    test       	: in  std_ulogic

    spw_clkp	  : in  std_ulogic;
    spw_clkn	  : in  std_ulogic;
    spw_rxdp      : in  std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_rxdn      : in  std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_rxsp      : in  std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_rxsn      : in  std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_txdp      : out std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_txdn      : out std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_txsp      : out std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_txsn      : out std_logic_vector(0 to CFG_SPW_NUM-1);
    pllref   	  : in  std_ulogic
	);
end;

architecture rtl of leon3mp is

signal lresetn	: std_ulogic;
signal lclk	: std_ulogic;
signal lerrorn	: std_ulogic;
signal laddress : std_logic_vector(27 downto 0);
signal datain	: std_logic_vector(31 downto 0);
signal dataout	: std_logic_vector(31 downto 0);
signal dataen 	: std_logic_vector(31 downto 0);
signal cbin   	: std_logic_vector(7 downto 0);
signal cbout   	: std_logic_vector(7 downto 0);
signal cben   	: std_logic_vector(7 downto 0);
signal lsdclk  	: std_ulogic;
--signal sdclk  	: std_ulogic;
signal lsdcsn  	: std_logic_vector (1 downto 0);    -- sdram chip select
signal lsdwen  	: std_ulogic;                       -- sdram write enable
signal lsdrasn  : std_ulogic;                       -- sdram ras
signal lsdcasn  : std_ulogic;                       -- sdram cas
signal lsddqm   : std_logic_vector (3 downto 0);    -- sdram dqm
signal ldsutx  	: std_ulogic; 			-- DSU tx data
signal ldsurx  	: std_ulogic;  			-- DSU rx data
signal ldsuen   : std_ulogic;
signal ldsubre  : std_ulogic;
signal ldsuact  : std_ulogic;
signal ltxd1   	: std_ulogic; 			-- UART1 tx data
signal lrxd1   	: std_ulogic;  			-- UART1 rx data
signal lramsn  	: std_logic_vector (4 downto 0);
signal lramoen 	: std_logic_vector (4 downto 0);
signal lrwen   	: std_logic_vector (3 downto 0);
signal loen    	: std_ulogic;
signal lwriten 	: std_ulogic;
signal lread   	: std_ulogic;
signal liosn   	: std_ulogic;
signal lromsn  	: std_logic_vector (1 downto 0);
signal lbrdyn  	: std_ulogic;
signal lbexcn  	: std_ulogic;
signal lwdogn  	: std_ulogic;
signal gpioin   : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0); 	-- I/O port
signal gpioout  : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0); 	-- I/O port
signal gpioen   : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0); 	-- I/O port

signal can_lrx, can_ltx   : std_logic_vector(0 to CFG_CAN_NUM-1);

signal lspw_clk	: std_ulogic;
signal spw_clkl	: std_ulogic;
signal lspw_rxd  : std_logic_vector(0 to CFG_SPW_NUM-1);
signal lspw_rxs  : std_logic_vector(0 to CFG_SPW_NUM-1);
signal lspw_txd  : std_logic_vector(0 to CFG_SPW_NUM-1);
signal lspw_txs  : std_logic_vector(0 to CFG_SPW_NUM-1);
signal lspw_ten  : std_logic_vector(0 to CFG_SPW_NUM-1);

signal ltest 	: std_ulogic;
constant OEPOL 	: integer := padoen_polarity(padtech);

signal lpciclk 	: std_ulogic;
signal pcii_rst 	: std_ulogic;
signal pcii_gnt 	: std_ulogic;
signal pcii_idsel 	: std_ulogic;
signal pcii_ad 	: std_logic_vector(31 downto 0);
signal pcii_cbe 	: std_logic_vector(3 downto 0);
signal pcii_frame	: std_ulogic;
signal pcii_irdy   : std_ulogic;
signal pcii_trdy   : std_ulogic;
signal pcii_devsel : std_ulogic;
signal pcii_stop   : std_ulogic;
signal pcii_perr   : std_ulogic;
signal pcii_par 	: std_ulogic;
signal pcii_host   : std_ulogic;
signal pcio_vaden   : std_logic_vector(31 downto 0);
signal pcio_cbeen   : std_logic_vector(3 downto 0);
signal pcio_frameen : std_ulogic;
signal pcio_irdyen  : std_ulogic;
signal pcio_trdyen  : std_ulogic;
signal pcio_devselen:  std_ulogic;
signal pcio_stopen : std_ulogic;
signal pcio_perren : std_ulogic;
signal pcio_paren 	: std_ulogic;
signal pcio_reqen	: std_ulogic;
signal pcio_locken : std_ulogic;
signal pcio_req    : std_ulogic;
signal pcio_ad 	: std_logic_vector(31 downto 0);
signal pcio_cbe : std_logic_vector(3 downto 0);
signal pcio_frame  : std_ulogic;
signal pcio_irdy   : std_ulogic;
signal pcio_trdy   : std_ulogic;
signal pcio_devsel : std_ulogic;
signal pcio_stop   : std_ulogic;
signal pcio_perr   : std_ulogic;
signal pcio_par    : std_ulogic;
signal pcii_arb_req: std_logic_vector(0 to CFG_PCI_ARB_NGNT-1);
signal pcio_arb_gnt: std_logic_vector(0 to CFG_PCI_ARB_NGNT-1);

signal ethi_mdio_i : std_logic;		-- ethernet PHY interface
signal etho_mdio_o : std_logic;
signal etho_mdio_oe: std_logic;
signal ethi_tx_clk : std_ulogic;
signal ethi_rx_clk : std_ulogic;
signal ethi_rxd    : std_logic_vector(3 downto 0);   
signal ethi_rx_dv  : std_ulogic; 
signal ethi_rx_er  : std_ulogic; 
signal ethi_rx_col : std_ulogic;
signal ethi_rx_crs : std_ulogic;
signal etho_txd    : std_logic_vector(3 downto 0);   
signal etho_tx_en  : std_ulogic; 
signal etho_tx_er  : std_ulogic; 
signal etho_mdc    : std_ulogic;
signal gnd         : std_logic_vector(3 downto 0);   

signal ltck, ltms, ltdi, ltrst, ltdo : std_ulogic;
signal lwritefb : std_ulogic;

begin

  gnd <= (others => '0');
  sdcke <= (others => '1');
  pads0 : entity work.pads
    generic map (padtech)
    port map (
      resetn, clk, errorn, address, data, cb, sdclk, sdcsn, 
      sdwen, sdrasn, sdcasn, sddqm, dsutx, dsurx, 
      dsuen, dsubre, dsuact, txd1, rxd1,
      ramsn, ramoen, rwen, oen, writen, read, iosn,
      romsn, brdyn, bexcn, wdogn, gpio, 
      emdio, etx_clk, erx_clk, erxd, erx_dv, erx_er,
      erx_col, erx_crs, etxd, etx_en, etx_er, emdc,

      pci_rst, pci_clk, pci_gnt, pci_idsel, pci_ad, pci_cbe,
      pci_frame, pci_irdy, pci_trdy, pci_devsel, pci_stop, pci_perr,
      pci_par, pci_req, pci_host, pci_arb_req, pci_arb_gnt,
      can_txd, can_rxd,
--      spw_clk, spw_rxd, spw_rxs, spw_txd, spw_txs, 
      gnd(0), gnd(CFG_SPW_NUM-1 downto 0), gnd(CFG_SPW_NUM-1 downto 0), open, open, 
--      tck, tms, tdi, tdo, trst, test,
      gnd(0), gnd(0), gnd(0), gnd(0), gnd(0), gnd(0),
      lresetn, lclk, lerrorn, laddress, datain,
      dataout, dataen, cbin, cbout, cben, lsdclk, lsdcsn, 
      lsdwen, lsdrasn, lsdcasn, lsddqm, ldsutx, ldsurx, 
      ldsuen, ldsubre, ldsuact, ltxd1, lrxd1,
      lramsn, lramoen, lrwen, loen, lwriten, lread, liosn,
      lromsn, lbrdyn, lbexcn, lwdogn, gpioin, gpioout, gpioen, lwritefb,


      ethi_mdio_i, etho_mdio_o, etho_mdio_oe, ethi_tx_clk, ethi_rx_clk, ethi_rxd,
      ethi_rx_dv, ethi_rx_er, ethi_rx_col, ethi_rx_crs, etho_txd, etho_tx_en,
      etho_tx_er, etho_mdc,

      lpciclk, pcii_rst, pcii_gnt, pcii_idsel, pcii_ad, pcii_cbe, pcii_frame,
      pcii_irdy, pcii_trdy, pcii_devsel, pcii_stop, pcii_perr, pcii_par, pcii_host,
      pcio_vaden, pcio_cbeen, pcio_frameen, pcio_irdyen, pcio_trdyen, pcio_devselen,
      pcio_stopen, pcio_perren, pcio_paren, pcio_reqen, pcio_locken, pcio_req,
      pcio_ad, pcio_cbe, pcio_frame, pcio_irdy, pcio_trdy, pcio_devsel, pcio_stop,
      pcio_perr, pcio_par, pcii_arb_req, pcio_arb_gnt, can_ltx, can_lrx,
--      lspw_clk, lspw_rxd, lspw_rxs, lspw_txd, lspw_txs, 
      open, open, open, gnd(CFG_SPW_NUM-1 downto 0), gnd(CFG_SPW_NUM-1 downto 0), 
--      ltck, ltms, ltdi, ltdo, ltest);
      open, open, open, gnd(0), open, open);

  core0 : entity work.core
    generic map (fabtech, memtech, padtech, clktech, disas, dbguart, pclow)
    port map (lresetn, lclk, lerrorn, laddress, datain,
      dataout, dataen, cbin, cbout, cben, lsdclk, lsdcsn, 
      lsdwen, lsdrasn, lsdcasn, lsddqm, ldsutx, ldsurx, 
      ldsuen, ldsubre, ldsuact, ltxd1, lrxd1,
      lramsn, lramoen, lrwen, loen, lwriten, lread, liosn,
      lromsn, lbrdyn, lbexcn, lwdogn, gpioin, gpioout, gpioen, lwritefb,


      ethi_mdio_i, etho_mdio_o, etho_mdio_oe, ethi_tx_clk, ethi_rx_clk, ethi_rxd,
      ethi_rx_dv, ethi_rx_er, ethi_rx_col, ethi_rx_crs, etho_txd, etho_tx_en,
      etho_tx_er, etho_mdc,

      lpciclk, pcii_rst, pcii_gnt, pcii_idsel, pcii_ad, pcii_cbe, pcii_frame,
      pcii_irdy, pcii_trdy, pcii_devsel, pcii_stop, pcii_perr, pcii_par, pcii_host,
      pcio_vaden, pcio_cbeen, pcio_frameen, pcio_irdyen, pcio_trdyen, pcio_devselen,
      pcio_stopen, pcio_perren, pcio_paren, pcio_reqen, pcio_locken, pcio_req,
      pcio_ad, pcio_cbe, pcio_frame, pcio_irdy, pcio_trdy, pcio_devsel, pcio_stop,
      pcio_perr, pcio_par, pcii_arb_req, pcio_arb_gnt, can_ltx, can_lrx,
      spw_clkl, --lspw_clk, 
      lspw_rxd, lspw_rxs, lspw_txd, lspw_txs, lspw_ten,
      ltck, ltms, ltdi, ltdo, ltrst, ltest, pllref);

  spw : if CFG_SPW_EN > 0 generate
   spw_clk_pad : clkpad_ds generic map (padtech, lvds, x25v)
	port map (spw_clkp, spw_clkn, spw_clkl); 
   swloop : for i in 0 to CFG_SPW_NUM-1 generate
     spw_rxd_pad : inpad_ds generic map (padtech, lvds, x25v)
	 port map (spw_rxdp(i), spw_rxdn(i), lspw_rxd(i));
     spw_rxs_pad : inpad_ds generic map (padtech, lvds, x25v)
	 port map (spw_rxsp(i), spw_rxsn(i), lspw_rxs(i));
     spw_txd_pad : outpad_ds generic map (padtech, lvds, x25v)
	 port map (spw_txdp(i), spw_txdn(i), lspw_txd(i), gnd(0));
     spw_txs_pad : outpad_ds generic map (padtech, lvds, x25v)
	 port map (spw_txsp(i), spw_txsn(i), lspw_txs(i), gnd(0));
   end generate;
--   spw_clk_gen: clkmul_virtex2 generic map (4, 2)
--   port map (lresetn, spw_clkl, lspw_clk, open);
  end generate;

end;
