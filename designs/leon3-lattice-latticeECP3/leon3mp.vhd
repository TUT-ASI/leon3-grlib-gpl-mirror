------------------------------------------------------------------------------
--  LEON3 Demonstration design
--  Copyright (C) 2006 Jiri Gaisler, Gaisler Research
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
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
use ieee.numeric_std.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;
use techmap.allclkgen.all;
library gaisler;
use gaisler.memctrl.all;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.net.all;
use gaisler.jtag.all;
library esa;
use esa.memoryctrl.all;
use work.config.all;
-- pragma translate_off
use gaisler.sim.all;
-- pragma translate_on

entity leon3mp is
  generic (fabtech  : integer := CFG_FABTECH;
	   memtech  : integer := CFG_MEMTECH;
	   padtech  : integer := CFG_PADTECH;
	   disas    : integer := CFG_DISAS;						-- Enable disassembly to console
	   dbguart  : integer := CFG_DUART;						-- Print UART on console
	   pclow    : integer := CFG_PCLOW
    );
  port (reset_n		: in std_ulogic;
	clk_in		: in std_ulogic;						-- 100 MHz main clock
--	dip_switch	: in std_logic_vector (7 downto 0);
	errorn		: out std_ulogic;

--only for running tests!!!
	address		: out std_logic_vector(19 downto 2);
	data		: inout std_logic_vector(31 downto 0);
	ramsn		: out std_logic_vector(1 downto 0);
	mben		: out std_logic_vector(3 downto 0);
	oen		: out std_ulogic;
	writen		: out std_ulogic;

	-- Debug Support Unit
	dsubre		: in    std_ulogic;						-- Debug Unit break (connect to button)
	dsuact		: out 	std_ulogic;

	-- DSU AHB UART interface
	dsurx  		: in    std_ulogic;
	dsutx  		: out   std_ulogic;

	-- Console UART1 interface
	rxd1            : in  std_ulogic;  						-- UART1 rx data
	txd1            : out std_ulogic; 						-- UART1 tx data

	-- Ethernet interface #1 signals
	rstn		: out std_ulogic;
	mdio		: inout std_logic;
	mdc		: out std_ulogic;
	rxc		: in std_ulogic;
	rx_er		: in std_ulogic;
	rx_dv		: in std_ulogic; 
	rx_d		: in std_logic_vector(7 downto 0);
	txc		: in std_ulogic;
	tx_en		: out std_ulogic;
	tx_er		: out std_ulogic;
	tx_d		: out std_logic_vector(7 downto 0);
	gtxclk		: out std_logic;
	crs		: in std_ulogic;
	col		: in std_ulogic;
	clk125		: in std_ulogic;
--	emdint    		: in std_ulogic;

	-- Output signals to LEDs
	led    		: out std_logic_vector(7 downto 0);
	seg14_led_out	: out std_logic_vector(14 downto 0)
    );
end;


architecture rtl of leon3mp is

  signal vcc				: std_logic;
  signal gnd				: std_logic;

  signal memi				: memory_in_type;
  signal memo				: memory_out_type;
  signal wpo				: wprot_out_type;

  signal sdi				: sdctrl_in_type;
  signal sdo				: sdram_out_type;

  signal apbi				: apb_slv_in_type;
  signal apbo				: apb_slv_out_vector := (others => apb_none);
  signal ahbsi				: ahb_slv_in_type;
  signal ahbso				: ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi				: ahb_mst_in_type;
  signal ahbmo				: ahb_mst_out_vector := (others => ahbm_none);

  signal dui				: uart_in_type;
  signal duo				: uart_out_type;

  signal irqi				: irq_in_vector(0 to CFG_NCPU-1);
  signal irqo				: irq_out_vector(0 to CFG_NCPU-1);

  signal dbgi				: l3_debug_in_vector(0 to CFG_NCPU-1);
  signal dbgo				: l3_debug_out_vector(0 to CFG_NCPU-1);

  signal dsui				: dsu_in_type;
  signal dsuo				: dsu_out_type;

  signal ethi				: eth_in_type;
  signal etho				: eth_out_type;
  signal egtx_clk			: std_ulogic;

  signal gpti				: gptimer_in_type;
  signal gpto				: gptimer_out_type;

  signal lclk, clk_ddr			: std_ulogic;

  signal rst_pad_n			: std_logic;
  signal gen_rst_n			: std_ulogic;
  signal rstraw				: std_logic;

  signal clkm				: std_ulogic;
  signal clkml				: std_ulogic;

  signal lock				: std_logic;
  signal errorn_s			: std_logic;

  signal cgi				: clkgen_in_type;
  signal cgo				: clkgen_out_type;
  signal cgi1				: clkgen_in_type;
  signal cgo1				: clkgen_out_type;

  signal tb_rst				: std_logic;
  signal tb_clk				: std_logic;
  signal phy_init_done			: std_logic;

  -- Console UART1
  signal uart1i				: uart_in_type;
  signal uart1o				: uart_out_type;

  attribute keep			: boolean;
  attribute syn_keep    		: boolean;
  attribute syn_preserve 		: boolean;

  attribute syn_keep of clkm 		: signal is true;
  attribute syn_preserve of clkm 	: signal is true;
  attribute syn_keep of egtx_clk 	: signal is true;
  attribute syn_preserve of egtx_clk 	: signal is true;

  attribute keep of clkm 		: signal is true;
  attribute keep of egtx_clk 		: signal is true;

  constant BOARD_FREQ			: integer := 100000;						-- input frequency in KHz
--  constant CPU_FREQ			: integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;  		-- CPU frequency in KHz
--TEMPORARY!!!
  constant CPU_FREQ			: integer := BOARD_FREQ * 8 / 10;  				-- CPU frequency in KHz
  constant IOAEN			: integer := 0;

begin
----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------
  vcc <= '1';
  gnd <= '0';

--  pllref_pad : clkpad generic map (tech => padtech) 
--		      port map (pllref, cgi.pllref);

  clk_pad : clkpad generic map (tech => padtech) port map (pad => clk_in, o => lclk);
  -- system clock generator
  clkgen0 : clkgen generic map (tech => padtech	, clk_mul => CFG_CLKMUL, clk_div => CFG_CLKDIV, sdramen => CFG_MCTRL_SDEN, noclkfb => CFG_CLK_NOFB, pcien => 0, pcidll => 0, pcisysclk => 0, 
				freq => BOARD_FREQ, clk2xen => 0)
		   port map (clkin => lclk, pciclkin => lclk, clk => clkm, clkn => open, clk2x => open, sdclk => open, pciclk => open, cgi => cgi, cgo => cgo);
  cgi.pllctrl <= "00";
  cgi.pllrst <= rstraw;
  led(0) <= not cgo.clklock;

  -- Ethernet 1G PHY clock generator (125MHz)
--  clkgen1 : clkgen generic map (tech => padtech, clk_mul => 5, clk_div => 4, sdramen => 0, noclkfb => 0, pcien => 0, pcidll => 0, pcisysclk => 0, 
--				freq => BOARD_FREQ, clk2xen => 0)
--		   port map (clkin => lclk, pciclkin => gnd, clk => egtx_clk, clkn => open, clk2x => open, sdclk => open, pciclk => open, cgi => cgi2, cgo => cgo2);
--TEMPORARY!!!
  clkgen1 : clkgen generic map (tech => padtech, clk_mul => 1, clk_div => 1, sdramen => 0, noclkfb => 0, pcien => 0, pcidll => 0, pcisysclk => 0, 
				freq => 125000, clk2xen => 0)
		   port map (clkin => clk125, pciclkin => gnd, clk => egtx_clk, clkn => open, clk2x => open, sdclk => open, pciclk => open, cgi => cgi1, cgo => cgo1);
  cgi1.pllctrl <= "00";
  cgi1.pllrst <= rstraw;
--cgi1.pllref <= egtx_clk_fb;
  led(1) <= not cgo1.clklock;

  gtxclk_pad : outpad generic map (tech => padtech)
	 	      port map (pad => gtxclk, i => egtx_clk);

  -- Glitch free reset that can be used for the Eth Phy and flash memory
  resetn_pad : inpad generic map (tech => padtech) port map (reset_n, rst_pad_n);
  -- reset generator
  rst0 : rstgen generic map (acthigh => 0)
		port map (rstin => rst_pad_n, clk => clkm, clklock => cgo.clklock, rstout => gen_rst_n, rstoutraw => rstraw);


---------------------------------------------------------------------- 
---  AHB CONTROLLER --------------------------------------------------
----------------------------------------------------------------------
  ahb0 : ahbctrl generic map (defmast => CFG_DEFMST, split => CFG_SPLIT, rrobin => CFG_RROBIN, ioaddr => CFG_AHBIO, ioen => IOAEN, nahbm => CFG_NCPU + CFG_GRETH + CFG_AHB_UART, nahbs => 8)
		 port map (rst => gen_rst_n, clk => clkm, msti => ahbmi, msto => ahbmo, slvi => ahbsi, slvo => ahbso);


----------------------------------------------------------------------
---  LEON3 processor and DSU -----------------------------------------
----------------------------------------------------------------------
  l3 : if CFG_LEON3 = 1 generate
	cpu : for i in 0 to CFG_NCPU - 1 generate
		-- LEON3 processor
      		u0 : leon3s generic map (i, fabtech, memtech, CFG_NWIN, CFG_DSU, CFG_FPU, CFG_V8, 
  					 0, CFG_MAC, pclow, 0, CFG_NWP, CFG_ICEN, CFG_IREPL, CFG_ISETS, CFG_ILINE, 
				   	 CFG_ISETSZ, CFG_ILOCK, CFG_DCEN, CFG_DREPL, CFG_DSETS, CFG_DLINE, CFG_DSETSZ,
  					 CFG_DLOCK, CFG_DSNOOP, CFG_ILRAMEN, CFG_ILRAMSZ, CFG_ILRAMADDR, CFG_DLRAMEN,
          				 CFG_DLRAMSZ, CFG_DLRAMADDR, CFG_MMUEN, CFG_ITLBNUM, CFG_DTLBNUM, CFG_TLB_TYPE, CFG_TLB_REP, 
          				 CFG_LDDEL, disas, CFG_ITBSZ, CFG_PWD, CFG_SVT, CFG_RSTADDR, CFG_NCPU - 1)
      			    port map (clkm, gen_rst_n, ahbmi, ahbmo(i), ahbsi, ahbso, irqi(i), irqo(i), dbgi(i), dbgo(i));
	end generate;

	errorn_s <= dbgo(0).error; 		-- active low
	led(2) <= errorn_s;
	error_pad : outpad generic map (tech => padtech) port map (pad => errorn, i => errorn_s);
    
	dsugen : if CFG_DSU = 1 generate
		-- LEON3 Debug Support Unit
		dsu0 : dsu3 generic map (hindex => 2, haddr => 16#900#, hmask => 16#F00#, ncpu => CFG_NCPU, tbits => 30, tech => memtech, irq => 0, kbytes => CFG_ATBSZ)
			    port map (gen_rst_n, clkm, ahbmi, ahbsi, ahbso(2), dbgo, dbgi, dsui, dsuo);
		dsui.enable <= '1'; 
		led(4) <= not dsuo.active;
		dsubre_pad : inpad generic map (tech => padtech) port map (dsubre, dsui.break); 
		dsuact_pad : outpad generic map (tech => padtech) port map (dsuact, dsuo.active);
	end generate;
  end generate;
  nodsu : if CFG_DSU = 0 generate 
	dsuo.tstop <= '0';
	dsuo.active <= '0';
  end generate;

  dcomgen : if CFG_AHB_UART = 1 generate
	-- Debug UART
	dcom0: ahbuart generic map (hindex => CFG_NCPU, pindex => 7, paddr => 7)
		       port map (gen_rst_n, clkm, dui, duo, apbi, apbo(7), ahbmi, ahbmo(CFG_NCPU));
	dui.extclk <= '0';
	led(6) <= not dui.rxd;
	led(7) <= not duo.txd;
	dsurx_pad : inpad generic map (tech => padtech) port map (dsurx, dui.rxd); 
	dsutx_pad : outpad generic map (tech => padtech) port map (dsutx, duo.txd);
  end generate;
  nouah : if CFG_AHB_UART = 0 generate 
	apbo(7) <= apb_none; 
  end generate;


----------------------------------------------------------------------
---  Memory controllers ----------------------------------------------
----------------------------------------------------------------------
  memi.writen <= '1';
  memi.wrn <= "1111";
  memi.bwidth <= "00";

  mctrl0 : mctrl generic map (hindex => 0, pindex => 0, rommask => 16#000#, iomask => 16#000#, paddr => 0, srbanks => 1, ram8 => CFG_MCTRL_RAM8BIT, 
			      ram16 => CFG_MCTRL_RAM16BIT, sden => CFG_MCTRL_SDEN, invclk => CFG_CLK_NOFB, sepbus => CFG_MCTRL_SEPBUS)
		 port map (gen_rst_n, clkm, memi, memo, ahbsi, ahbso(0), apbi, apbo(0), wpo, sdo);

  addr_pad : outpadv generic map (width => 18, tech => padtech) 
		     port map (address, memo.address(19 downto 2));
  ramsa_pad : outpad generic map (tech => padtech) 
		     port map (ramsn(0), memo.ramsn(0)); 
  ramsb_pad : outpad generic map (tech => padtech) 
		     port map (ramsn(1), memo.ramsn(0)); 
  oen_pad  : outpad generic map (tech => padtech) 
		    port map (oen, memo.oen);
  wri_pad  : outpad generic map (tech => padtech) 
		    port map (writen, memo.writen);
  mben_pads : outpadv generic map (tech => padtech, width => 4)
		      port map (mben, memo.mben);

  data_pads : iopadvv generic map (tech => padtech, width => 32)
		      port map (data, memo.data(31 downto 0), memo.vbdrive(31 downto 0), memi.data(31 downto 0));


----------------------------------------------------------------------
---  APB Bridge and various periherals -------------------------------
----------------------------------------------------------------------
  -- APB Bridge
  apb0 : apbctrl generic map (hindex => 1, haddr => CFG_APBADDR, nslaves => 16)
		 port map (gen_rst_n, clkm, ahbsi, ahbso(1), apbi, apbo);

  uart1 : if CFG_UART1_ENABLE /= 0 generate
		-- Console UART1
		uart1 : apbuart generic map (pindex => 1, paddr => 1,  pirq => 2, console => dbguart, fifosize => CFG_UART1_FIFO)
				port map (gen_rst_n, clkm, apbi, apbo(1), uart1i, uart1o);
		uart1i.extclk <= '0'; 
		uart1i.ctsn <= '0';
--commented because using inpad/outpad
--		uart1i.rxd <= rxd1;
--		txd1 <= uart1o.txd;
		uart1_rx_pad : inpad generic map (tech  => padtech) port map (pad => rxd1, o => uart1i.rxd);
		uart1_tx_pad : outpad generic map (tech => padtech) port map (pad => txd1, i => uart1o.txd);
		--shared with GRETH signals tx_en, tx_er
--		led(6) <= not uart1i.rxd;
--		led(7) <= not uart1o.txd;
  end generate;
  noua0 : if CFG_UART1_ENABLE = 0 generate
	apbo(1) <= apb_none;
  end generate;

  -- Interrupt controller
  irqctrl : if CFG_IRQ3_ENABLE /= 0 generate
	irqctrl0 : irqmp generic map (pindex => 2, paddr => 2, ncpu => CFG_NCPU)
			 port map (gen_rst_n, clkm, apbi, apbo(2), irqo, irqi);
  end generate;
  irq3 : if CFG_IRQ3_ENABLE = 0 generate
	x : for i in 0 to (CFG_NCPU - 1) generate
		irqi(i).irl <= "0000";
	end generate;
	apbo(2) <= apb_none;
  end generate;

  -- Time Unit
  gpt : if CFG_GPT_ENABLE /= 0 generate
	timer0 : gptimer generic map (pindex => 3, paddr => 3, pirq => CFG_GPT_IRQ, sepirq => CFG_GPT_SEPIRQ, sbits => CFG_GPT_SW, ntimers => CFG_GPT_NTIM, nbits  => CFG_GPT_TW)
			 port map (gen_rst_n, clkm, apbi, apbo(3), gpti, gpto);
	gpti.dhalt  <= dsuo.tstop;
	gpti.extclk <= '0';
	led(5) <= not gpto.wdog;
  end generate;
  notim : if CFG_GPT_ENABLE = 0 generate
	apbo(3) <= apb_none; 
  end generate;

  -- GPIO Unit
--  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate
--    grgpio0: grgpio
--      generic map(pindex => 11, paddr => 11, imask => CFG_GRGPIO_IMASK, nbits => 12)
--      port map(gen_rst_n, clkm, apbi, apbo(11), gpioi, gpioo);
--  end generate;


-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------
  eth1 : if (CFG_GRETH = 1) generate -- Gaisler Ethernet Interface #1
	e1 : grethm generic map (hindex => CFG_NCPU + CFG_AHB_UART, pindex => 15, paddr => 15, pirq => 12, memtech => memtech,
				 mdcscaler => CPU_FREQ / 1000, enable_mdio => 1, fifosize => CFG_ETH_FIFO, nsync => 1, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF,
				 macaddrh => CFG_ETH_ENM, macaddrl => CFG_ETH_ENL, phyrstadr => 0, ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_ETH_IPL, giga => CFG_GRETH1G)--,	enable_mdint => 1)
		    port map (rst => gen_rst_n, clk => clkm, ahbmi => ahbmi, ahbmo => ahbmo(CFG_NCPU + CFG_AHB_UART), apbi => apbi, apbo => apbo(15), ethi => ethi, etho => etho);
--	led(6) <= not etho.tx_en;
--	led(7) <= not etho.tx_er;
  end generate;

  ethpads1 : if (CFG_GRETH = 1) generate -- GRETH #1 pads
	emdio_pad : iopad generic map (tech => padtech) 
			  port map (pad => mdio,
				    i => etho.mdio_o,
				    en => etho.mdio_oe,
				    o => ethi.mdio_i);

	etxc_pad : clkpad generic map (tech => padtech)
			  port map (pad => txc, 
				    o => ethi.tx_clk);
	erxc_pad : clkpad generic map (tech => padtech)
			  port map (pad => rxc, 
				    o => ethi.rx_clk);
	erxd_pad : inpadv generic map (tech => padtech, width => 8)
			  port map (pad => rx_d(7 downto 0),
				    o => ethi.rxd(7 downto 0));
	erxdv_pad : inpad generic map (tech => padtech) 
			  port map (pad => rx_dv, 
				    o => ethi.rx_dv);
	erxer_pad : inpad generic map (tech => padtech) 
			  port map (pad => rx_er, 
				    o => ethi.rx_er);
	erxco_pad : inpad generic map (tech => padtech) 
			  port map (pad => col, 
				    o => ethi.rx_col);
	erxcr_pad : inpad generic map (tech => padtech) 
			  port map (pad => crs, 
				    o => ethi.rx_crs);

	etxd_pad : outpadv generic map (tech => padtech, width => 8)
			   port map (pad => tx_d(7 downto 0),
				     i => etho.txd(7 downto 0));

	etxen_pad : outpad generic map (tech => padtech) 
			   port map (pad => tx_en, 
				     i => etho.tx_en);
	tx_er <= '0';							-- not present in Marvel 88E1119R Gigabit Ethernet transceiver device
--	etxer_pad : outpad generic map (tech => padtech)
--			   port map (pad => tx_er, 
--				     i => etho.tx_er);
	emdc_pad : outpad generic map (tech => padtech) 
			  port map (pad => mdc, 
				    i => etho.mdc);
	erst_pad : outpad generic map (tech => padtech) 
			  port map (pad => rstn, 
--				    i => etho.reset);
				    i => gen_rst_n);

	ethi.gtx_clk <= egtx_clk;
  end generate;


-----------------------------------------------------------------------
---  14-SEGMENT ALPHA-NUMERIC LED DISPLAY -----------------------------
-----------------------------------------------------------------------
  seg14_led_out <= (others => '0');


-----------------------------------------------------------------------
---  AHB ROM ----------------------------------------------------------
-----------------------------------------------------------------------
  bpromgen : if CFG_AHBROMEN /= 0 generate
	brom : entity work.ahbrom generic map (hindex => 6, haddr => CFG_AHBRODDR, pipe => CFG_AHBROPIP)
				  port map (gen_rst_n, clkm, ahbsi, ahbso(6));
  end generate;

  nobpromgen : if CFG_AHBROMEN = 0 generate
	ahbso(6) <= ahbs_none;
  end generate;


-----------------------------------------------------------------------
---  AHB RAM ----------------------------------------------------------
-----------------------------------------------------------------------
  ahbramgen : if CFG_AHBRAMEN = 1 generate
	ahbram0 : ahbram generic map (hindex => 3, haddr => CFG_AHBRADDR, tech => CFG_MEMTECH, kbytes => CFG_AHBRSZ)
			 port map (gen_rst_n, clkm, ahbsi, ahbso(3));
  end generate;

  nram : if CFG_AHBRAMEN = 0 generate 
	ahbso(3) <= ahbs_none; 
  end generate;


-----------------------------------------------------------------------
---  Test report module  ----------------------------------------------
-----------------------------------------------------------------------
-- pragma translate_off
  test0 : ahbrep generic map (hindex => 4, haddr => 16#200#)
		 port map (gen_rst_n, clkm, ahbsi, ahbso(4));
-- pragma translate_on


-----------------------------------------------------------------------
---  Drive unused bus elements  ---------------------------------------
-----------------------------------------------------------------------
  nam1 : for i in (CFG_NCPU + CFG_GRETH + CFG_AHB_UART + 1) to (NAHBMST - 1) generate
	ahbmo(i) <= ahbm_none;
  end generate;


-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------
-- pragma translate_off
  x : report_version generic map (msg1 => "LEON3 Demonstration design for LatticeECP3 Versa Evaluation Board",
				  msg2 => "GRLIB Version " & tost(LIBVHDL_VERSION/1000) & "." & tost((LIBVHDL_VERSION mod 1000)/100) & "." & tost(LIBVHDL_VERSION mod 100) & ", build " & tost(LIBVHDL_BUILD),
				  msg3 => "Target technology: " & tech_table(fabtech) & ",  memory library: " & tech_table(memtech),
				  mdel => 1);
-- pragma translate_on

end rtl;

