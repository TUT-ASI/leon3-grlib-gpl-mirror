-----------------------------------------------------------------------------
--  LEON3 Demonstration design
--  Copyright (C) 2004 Jiri Gaisler, Gaisler Research
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2013, Aeroflex Gaisler
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
library grlib, techmap;
use grlib.amba.all;
use grlib.stdlib.all;
use techmap.gencomp.all;
library gaisler;
use gaisler.memctrl.all;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.can.all;
use gaisler.pci.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.spacewire.all;

library esa;
use esa.memoryctrl.all;
use esa.pcicomp.all;
use work.config.all;

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
    resetn	: in  std_logic;
    clk		: in  std_logic;
    pllref 	: in  std_logic; 
    errorn	: out std_logic;
    wdogn  	: out std_logic;

    address 	: out std_logic_vector(27 downto 0);
    data	: inout std_logic_vector(31 downto 0);
    sa      	: out std_logic_vector(14 downto 0);
    sd   	: inout std_logic_vector(63 downto 0);

    sdclk  	: out std_logic;
    sdcke  	: out std_logic_vector (1 downto 0);    -- sdram clock enable
    sdcsn  	: out std_logic_vector (1 downto 0);    -- sdram chip select
    sdwen  	: out std_logic;                       -- sdram write enable
    sdrasn  	: out std_logic;                       -- sdram ras
    sdcasn  	: out std_logic;                       -- sdram cas
    sddqm   	: out std_logic_vector (7 downto 0);    -- sdram dqm
    dsutx  	: out std_logic; 			-- DSU tx data
    dsurx  	: in  std_logic;  			-- DSU rx data
    dsuen   	: in std_logic;
    dsubre  	: in std_logic;
    dsuact  	: out std_logic;
    txd1   	: out std_logic; 			-- UART1 tx data
    rxd1   	: in  std_logic;  			-- UART1 rx data
    txd2   	: out std_logic; 			-- UART2 tx data
    rxd2   	: in  std_logic;  			-- UART2 rx data
    ramsn  	: out std_logic_vector (4 downto 0);
    ramoen 	: out std_logic_vector (4 downto 0);
    rwen   	: out std_logic_vector (3 downto 0);
    oen    	: out std_logic;
    writen 	: out std_logic;
    read   	: out std_logic;
    iosn   	: out std_logic;
    romsn  	: out std_logic_vector (1 downto 0);
    brdyn  	: in  std_logic;  			-- bus ready
    bexcn  	: in  std_logic;  			-- bus exception

    gpio        : inout std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0); 	-- I/O port

    emdio     	: inout std_logic;		-- ethernet PHY interface
    etx_clk 	: in std_logic;
    erx_clk 	: in std_logic;
    erxd    	: in std_logic_vector(3 downto 0);   
    erx_dv  	: in std_logic; 
    erx_er  	: in std_logic; 
    erx_col 	: in std_logic;
    erx_crs 	: in std_logic;
    etxd 	: out std_logic_vector(3 downto 0);   
    etx_en 	: out std_logic; 
    etx_er 	: out std_logic; 
    emdc 	: out std_logic;

    pci_rst     : inout std_logic;		-- PCI bus
    pci_clk 	: in std_logic;
    pci_gnt     : in std_logic;
    pci_idsel   : in std_logic; 
    pci_lock    : inout std_logic;
    pci_ad 	: inout std_logic_vector(31 downto 0);
    pci_cbe 	: inout std_logic_vector(3 downto 0);
    pci_frame   : inout std_logic;
    pci_irdy 	: inout std_logic;
    pci_trdy 	: inout std_logic;
    pci_devsel  : inout std_logic;
    pci_stop 	: inout std_logic;
    pci_perr 	: inout std_logic;
    pci_par 	: inout std_logic;    
    pci_req 	: inout std_logic;
    pci_serr    : inout std_logic;
    pci_host   	: in std_logic;
    pci_int 	: inout std_logic_vector(3 downto 0);
    pci_66	: in std_logic;
    pci_arb_req	: in  std_logic_vector(0 to 3);
    pci_arb_gnt	: out std_logic_vector(0 to 3);

    can_txd	: out std_logic_vector(0 to CFG_CAN_NUM-1);
    can_rxd	: in  std_logic_vector(0 to CFG_CAN_NUM-1);
--    can_stb	: out std_logic_vector(0 to CFG_CAN_NUM-1)

    spw_clk	  : in  std_logic;
    spw_rxdp      : in  std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_rxdn      : in  std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_rxsp      : in  std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_rxsn      : in  std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_txdp      : out std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_txdn      : out std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_txsp      : out std_logic_vector(0 to CFG_SPW_NUM-1);
    spw_txsn      : out std_logic_vector(0 to CFG_SPW_NUM-1)

	);
end;

architecture rtl of leon3mp is

constant blength : integer := 12;
constant fifodepth : integer := 8;

signal vcc, gnd   : std_logic_vector(4 downto 0);
signal memi  : memory_in_type;
signal memo  : memory_out_type;
signal wpo   : wprot_out_type;
signal sdi   : sdctrl_in_type;
signal sdo   : sdram_out_type;

signal apbi  : apb_slv_in_type;
signal apbo  : apb_slv_out_vector := (others => apb_none);
signal ahbsi : ahb_slv_in_type;
signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
signal ahbmi : ahb_mst_in_type;
signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);

signal clkm, rstn, rstraw, pciclk, sdclkl : std_logic;
signal cgi   : clkgen_in_type;
signal cgo   : clkgen_out_type;
signal u1i, u2i, dui : uart_in_type;
signal u1o, u2o, duo : uart_out_type;

signal irqi : irq_in_vector(0 to CFG_NCPU-1);
signal irqo : irq_out_vector(0 to CFG_NCPU-1);

signal dbgi : l3_debug_in_vector(0 to CFG_NCPU-1);
signal dbgo : l3_debug_out_vector(0 to CFG_NCPU-1);

signal dsui : dsu_in_type;
signal dsuo : dsu_out_type; 

signal pcii : pci_in_type;
signal pcio : pci_out_type;

signal spwi : grspw_in_type_vector(0 to CFG_SPW_NUM-1);
signal spwo : grspw_out_type_vector(0 to CFG_SPW_NUM-1);
signal spw_rxclk : std_logic_vector(0 to CFG_SPW_NUM-1);
signal dtmp : std_logic_vector(0 to CFG_SPW_NUM-1);
signal stmp : std_logic_vector(0 to CFG_SPW_NUM-1);
signal spw_rxtxclk : std_ulogic;
signal spw_rxclkn  : std_ulogic;
signal spw_clkl   : std_logic;

signal stati : ahbstat_in_type;

signal ethi, ethi1, ethi2 : eth_in_type;
signal etho, etho1, etho2 : eth_out_type;

signal gpti : gptimer_in_type;
signal gpto : gptimer_out_type;
signal wdog : std_logic;

signal gpioi : gpio_in_type;
signal gpioo : gpio_out_type;

signal can_lrx, can_ltx   : std_logic_vector(0 to 7);
signal lclk, pci_lclk : std_logic;
signal pci_arb_req_n, pci_arb_gnt_n   : std_logic_vector(0 to 3);
signal pci_dirq : std_logic_vector(3 downto 0);

signal tck, tms, tdi, tdo : std_logic;

signal fpi : grfpu_in_vector_type;
signal fpo : grfpu_out_vector_type;


constant BOARD_FREQ : integer := 50000;	-- Board frequency in KHz
constant CPU_FREQ : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;  -- cpu frequency in KHz
constant IOAEN : integer := CFG_CAN + CFG_PCI + CFG_GRPCI2_MASTER;
constant CFG_SDEN : integer := CFG_MCTRL_SDEN;
constant CFG_INVCLK : integer := CFG_MCTRL_INVCLK;
constant OEPOL : integer := padoen_polarity(padtech);

begin

----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------
  
  vcc <= (others => '1'); gnd <= (others => '0');
  cgi.pllctrl <= "00"; cgi.pllrst <= rstraw;

  pllref_pad : clkpad generic map (tech => padtech) port map (pllref, cgi.pllref); 
  clk_pad : clkpad generic map (tech => padtech) port map (clk, lclk); 
  pci_clk_pad : clkpad generic map (tech => padtech, level => pci33) 
	    port map (pci_clk, pci_lclk); 
  clkgen0 : clkgen  		-- clock generator
    generic map (clktech, CFG_CLKMUL, CFG_CLKDIV, CFG_SDEN, 
	CFG_INVCLK, CFG_PCI+CFG_GRPCI2_MASTER+CFG_GRPCI2_TARGET, CFG_PCIDLL, CFG_PCISYSCLK, BOARD_FREQ)
    port map (lclk, pci_lclk, clkm, open, open, sdclkl, pciclk, cgi, cgo);
  sdclk_pad : outpad generic map (tech => padtech) 
	port map (sdclk, sdclkl);

  rst0 : rstgen			-- reset generator
  port map (resetn, clkm, cgo.clklock, rstn, rstraw);

----------------------------------------------------------------------
---  AHB CONTROLLER --------------------------------------------------
----------------------------------------------------------------------

  ahb0 : ahbctrl 		-- AHB arbiter/multiplexer
  generic map (defmast => CFG_DEFMST, split => CFG_SPLIT, 
	rrobin => CFG_RROBIN, ioaddr => CFG_AHBIO, ioen => IOAEN,
	nahbm => CFG_NCPU+CFG_AHB_UART+CFG_GRPCI2_TARGET+CFG_GRPCI2_DMA+log2x(CFG_PCI)+CFG_AHB_JTAG+CFG_GRETH+CFG_SPW_NUM, 
	nahbs => 8)
  port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);

----------------------------------------------------------------------
---  LEON3 processor and DSU -----------------------------------------
----------------------------------------------------------------------

  cpu : for i in 0 to CFG_NCPU-1 generate
    nosh : if CFG_GRFPUSH = 0 generate    
      u0 : leon3s 		-- LEON3 processor      
      generic map (i, fabtech, memtech, CFG_NWIN, CFG_DSU, CFG_FPU*(1-CFG_GRFPUSH), CFG_V8, 
	0, CFG_MAC, pclow, CFG_NOTAG, CFG_NWP, CFG_ICEN, CFG_IREPL, CFG_ISETS, CFG_ILINE, 
	CFG_ISETSZ, CFG_ILOCK, CFG_DCEN, CFG_DREPL, CFG_DSETS, CFG_DLINE, CFG_DSETSZ,
	CFG_DLOCK, CFG_DSNOOP, CFG_ILRAMEN, CFG_ILRAMSZ, CFG_ILRAMADDR, CFG_DLRAMEN,
        CFG_DLRAMSZ, CFG_DLRAMADDR, CFG_MMUEN, CFG_ITLBNUM, CFG_DTLBNUM, CFG_TLB_TYPE, CFG_TLB_REP, 
        CFG_LDDEL, disas, CFG_ITBSZ, CFG_PWD, CFG_SVT, CFG_RSTADDR, CFG_NCPU-1,
	0, 0, CFG_MMU_PAGE, CFG_BP)
      port map (clkm, rstn, ahbmi, ahbmo(i), ahbsi, ahbso, 
    		irqi(i), irqo(i), dbgi(i), dbgo(i));
    end generate;
  end generate;

  sh : if CFG_GRFPUSH = 1 generate
    cpu : for i in 0 to CFG_NCPU-1 generate
      u0 : leon3sh 		-- LEON3 processor      
      generic map (i, fabtech, memtech, CFG_NWIN, CFG_DSU, CFG_FPU, CFG_V8, 
	0, CFG_MAC, pclow, CFG_NOTAG, CFG_NWP, CFG_ICEN, CFG_IREPL, CFG_ISETS, CFG_ILINE, 
	CFG_ISETSZ, CFG_ILOCK, CFG_DCEN, CFG_DREPL, CFG_DSETS, CFG_DLINE, CFG_DSETSZ,
	CFG_DLOCK, CFG_DSNOOP, CFG_ILRAMEN, CFG_ILRAMSZ, CFG_ILRAMADDR, CFG_DLRAMEN,
        CFG_DLRAMSZ, CFG_DLRAMADDR, CFG_MMUEN, CFG_ITLBNUM, CFG_DTLBNUM, CFG_TLB_TYPE, CFG_TLB_REP, 
        CFG_LDDEL, disas, CFG_ITBSZ, CFG_PWD, CFG_SVT, CFG_RSTADDR, CFG_NCPU-1,
	0, 0, CFG_MMU_PAGE, CFG_BP)
      port map (clkm, rstn, ahbmi, ahbmo(i), ahbsi, ahbso, 
    		irqi(i), irqo(i), dbgi(i), dbgo(i), fpi(i), fpo(i));
    end generate;

    grfpush0 : grfpushwx generic map ((CFG_FPU-1), CFG_NCPU, fabtech)
      port map (clkm, rstn, fpi, fpo);
    
  end generate;
    
  errorn_pad : odpad generic map (tech => padtech) port map (errorn, dbgo(0).error);
  
  dsugen : if CFG_DSU = 1 generate
    dsu0 : dsu3			-- LEON3 Debug Support Unit
    generic map (hindex => 2, haddr => 16#900#, hmask => 16#F00#, 
       ncpu => CFG_NCPU, tbits => 30, tech => memtech, irq => 0, kbytes => CFG_ATBSZ)
    port map (rstn, clkm, ahbmi, ahbsi, ahbso(2), dbgo, dbgi, dsui, dsuo);
    dsuen_pad : inpad generic map (tech => padtech) port map (dsuen, dsui.enable); 
    dsubre_pad : inpad generic map (tech => padtech) port map (dsubre, dsui.break); 
    dsuact_pad : outpad generic map (tech => padtech) port map (dsuact, dsuo.active);
  end generate;
  nodsu : if CFG_DSU = 0 generate 
    ahbso(2) <= ahbs_none; dsuo.tstop <= '0'; dsuo.active <= '0';
  end generate;

  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0: ahbuart		-- Debug UART
    generic map (hindex => CFG_NCPU, pindex => 7, paddr => 7)
    port map (rstn, clkm, dui, duo, apbi, apbo(7), ahbmi, ahbmo(CFG_NCPU));
    dsurx_pad : inpad generic map (tech => padtech) port map (dsurx, dui.rxd); 
    dsutx_pad : outpad generic map (tech => padtech) port map (dsutx, duo.txd);
  end generate;
--  nouah : if CFG_AHB_UART = 0 generate apbo(7) <= apb_none; end generate;

  ahbjtaggen0 :if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => CFG_NCPU+CFG_AHB_UART)
      port map(rstn, clkm, tck, tms, tdi, tdo, ahbmi, ahbmo(CFG_NCPU+CFG_AHB_UART),
               open, open, open, open, open, open, open, gnd(0));
  end generate;
  
----------------------------------------------------------------------
---  Memory controllers ----------------------------------------------
----------------------------------------------------------------------

  memi.edac <= gpioo.val(2); memi.bwidth <= gpioo.val(1 downto 0);

  mctrl0 : if CFG_MCTRL_LEON2 = 1 generate 	-- LEON2 memory controller
    sr1 : mctrl generic map (hindex => 0, pindex => 0, paddr => 0, 
	srbanks => 4, sden => CFG_MCTRL_SDEN, ram8 => CFG_MCTRL_RAM8BIT, 
	ram16 => CFG_MCTRL_RAM16BIT, invclk => CFG_MCTRL_INVCLK, 
	sepbus => CFG_MCTRL_SEPBUS, oepol => OEPOL, 
	sdbits => 32 + 32*CFG_MCTRL_SD64, pageburst => CFG_MCTRL_PAGE)
    port map (rstn, clkm, memi, memo, ahbsi, ahbso(0), apbi, apbo(0), wpo, sdo);

    addr_pad : outpadv generic map (width => 28, tech => padtech) 
	port map (address, memo.address(27 downto 0)); 
    rams_pad : outpadv generic map (width => 5, tech => padtech) 
	port map (ramsn, memo.ramsn(4 downto 0)); 
    roms_pad : outpadv generic map (width => 2, tech => padtech) 
	port map (romsn, memo.romsn(1 downto 0)); 
    oen_pad  : outpad generic map (tech => padtech) 
	port map (oen, memo.oen);
    rwen_pad : outpadv generic map (width => 4, tech => padtech) 
	port map (rwen, memo.wrn); 
    roen_pad : outpadv generic map (width => 5, tech => padtech) 
	port map (ramoen, memo.ramoen(4 downto 0));
    wri_pad  : outpad generic map (tech => padtech) 
	port map (writen, memo.writen);
    read_pad : outpad generic map (tech => padtech) 
	port map (read, memo.read); 
    iosn_pad : outpad generic map (tech => padtech) 
	port map (iosn, memo.iosn);
    data_pad : iopadvv generic map (tech => padtech, width => 32, oepol => OEPOL)
      port map (data, memo.data, memo.vbdrive, memi.data);
    brdyn_pad : inpad generic map (tech => padtech) port map (brdyn, memi.brdyn); 
    bexcn_pad : inpad generic map (tech => padtech) port map (bexcn, memi.bexcn); 
    memi.writen <= '1'; memi.wrn <= "1111";

    sdpads : if CFG_MCTRL_SDEN = 1 generate 		-- SDRAM controller
      sd2 : if CFG_MCTRL_SEPBUS = 1 generate
        sa_pad : outpadv generic map (width => 15) port map (sa, memo.sa);
          sd_pad : iopadvv generic map (tech => padtech, width => 32, oepol => OEPOL)
          port map (sd(31 downto 0), memo.sddata(31 downto 0),
		memo.svbdrive(31 downto 0), memi.sd(31 downto 0));
          sd2 : if CFG_MCTRL_SD64 = 1 generate
            sd_pad2 : iopadvv generic map (tech => padtech, width => 32)
            port map (sd(63 downto 32), memo.data(31 downto 0),
		memo.svbdrive(63 downto 32), memi.sd(63 downto 32));
        end generate;
      end generate;
      sdwen_pad : outpad generic map (tech => padtech) 
	   port map (sdwen, sdo.sdwen);
      sdras_pad : outpad generic map (tech => padtech) 
	   port map (sdrasn, sdo.rasn);
      sdcas_pad : outpad generic map (tech => padtech) 
	   port map (sdcasn, sdo.casn);
      sddqm_pad : outpadv generic map (width => 8, tech => padtech) 
	   port map (sddqm, sdo.dqm);
      sdcke_pad : outpadv generic map (width => 2, tech => padtech) 
	   port map (sdcke, sdo.sdcke); 
      sdcsn_pad : outpadv generic map (width => 2, tech => padtech) 
	   port map (sdcsn, sdo.sdcsn); 
    end generate;
  end generate;

  nosd0 : if (CFG_SDEN = 0) generate 		-- no SDRAM controller
      sdcke_pad : outpadv generic map (width =>2, tech => padtech) 
	   port map (sdcke, vcc(1 downto 0)); 
      sdcsn_pad : outpadv generic map (width =>2, tech => padtech) 
	   port map (sdcsn, vcc(1 downto 0)); 
  end generate;


  mg0 : if CFG_MCTRL_LEON2 = 0 generate	-- No PROM/SRAM controller
    apbo(0) <= apb_none; ahbso(0) <= ahbs_none;
    rams_pad : outpadv generic map (width => 5, tech => padtech) 
	port map (ramsn, vcc); 
    roms_pad : outpadv generic map (width => 2, tech => padtech) 
	port map (romsn, vcc(1 downto 0)); 
  end generate;


----------------------------------------------------------------------
---  APB Bridge and various periherals -------------------------------
----------------------------------------------------------------------

  apb0 : apbctrl				-- AHB/APB bridge
  generic map (hindex => 1, haddr => CFG_APBADDR)
  port map (rstn, clkm, ahbsi, ahbso(1), apbi, apbo );

  ua1 : if CFG_UART1_ENABLE /= 0 generate
    uart1 : apbuart			-- UART 1
    generic map (pindex => 1, paddr => 1,  pirq => 2, console => dbguart,
	fifosize => CFG_UART1_FIFO)
    port map (rstn, clkm, apbi, apbo(1), u1i, u1o);
    u1i.rxd <= rxd1; u1i.ctsn <= '0'; u1i.extclk <= '0'; txd1 <= u1o.txd;
  end generate;
  noua0 : if CFG_UART1_ENABLE = 0 generate apbo(1) <= apb_none; end generate;

  ua2 : if CFG_UART2_ENABLE /= 0 generate
    uart2 : apbuart			-- UART 2
    generic map (pindex => 9, paddr => 9,  pirq => 3, fifosize => CFG_UART2_FIFO)
    port map (rstn, clkm, apbi, apbo(9), u2i, u2o);
    u2i.rxd <= rxd2; u2i.ctsn <= '0'; u2i.extclk <= '0'; txd2 <= u2o.txd;
  end generate;
  noua1 : if CFG_UART2_ENABLE = 0 generate apbo(9) <= apb_none; end generate;

  irqctrl : if CFG_IRQ3_ENABLE /= 0 generate
    irqctrl0 : irqmp			-- interrupt controller
    generic map (pindex => 2, paddr => 2, ncpu => CFG_NCPU)
    port map (rstn, clkm, apbi, apbo(2), irqo, irqi);
  end generate;
  irq3 : if CFG_IRQ3_ENABLE = 0 generate
    x : for i in 0 to CFG_NCPU-1 generate
      irqi(i).irl <= "0000";
    end generate;
--    apbo(2) <= apb_none;
  end generate;
  pci_dirq(3 downto 1) <= (others => '0');
  pci_dirq(0) <= orv(irqi(0).irl);

  gpt : if CFG_GPT_ENABLE /= 0 generate
    timer0 : gptimer 			-- timer unit
    generic map (pindex => 3, paddr => 3, pirq => CFG_GPT_IRQ, 
	sepirq => CFG_GPT_SEPIRQ, sbits => CFG_GPT_SW, ntimers => CFG_GPT_NTIM, 
	nbits => CFG_GPT_TW)
    port map (rstn, clkm, apbi, apbo(3), gpti, gpto);
    gpti.dhalt <= dsuo.tstop; gpti.extclk <= '0';
    wdog <= gpto.wdogn when OEPOL = 0 else gpto.wdog;
    wdogn_pad : odpad generic map (tech => padtech, oepol => OEPOL) port map (wdogn, wdog);
  end generate;
--  notim : if CFG_GPT_ENABLE = 0 generate apbo(3) <= apb_none; end generate;

  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate     -- GR GPIO unit
    grgpio0: grgpio
      generic map( pindex => 6, paddr => 6, imask => CFG_GRGPIO_IMASK, 
	nbits => CFG_GRGPIO_WIDTH)
      port map( rstn, clkm, apbi, apbo(6), gpioi, gpioo);

      pio_pads : for i in 0 to CFG_GRGPIO_WIDTH-1 generate
        pio_pad : iopad generic map (tech => padtech)
            port map (gpio(i), gpioo.dout(i), gpioo.oen(i), gpioi.din(i));
      end generate;
   end generate;

  ahbs : if CFG_AHBSTAT = 1 generate	-- AHB status register
    stati.cerror(0) <= memo.ce;
    ahbstat0 : ahbstat generic map (pindex => 15, paddr => 15, pirq => 1,
	nftslv => CFG_AHBSTATN)
      port map (rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(15));
  end generate;
  nop2 : if CFG_AHBSTAT = 0 generate apbo(15) <= apb_none; end generate;

-----------------------------------------------------------------------
---  PCI   ------------------------------------------------------------
-----------------------------------------------------------------------
  pci : if (CFG_GRPCI2_MASTER+CFG_GRPCI2_TARGET) /= 0 or CFG_PCI /= 0 generate

    grpci2x : if (CFG_GRPCI2_MASTER+CFG_GRPCI2_TARGET) /= 0 and CFG_PCI = 0 generate
      pci0 : grpci2 
        generic map (
          memtech => memtech,
          oepol => OEPOL,
          hmindex => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG,
          hdmindex => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+1,
          hsindex => 4,
          haddr => 16#C00#,
          hmask => 16#E00#,
          ioaddr => 16#000#,
          pindex => 4,
          paddr => 4,
          irq => 4,
          irqmode => 0,
          master => CFG_GRPCI2_MASTER,
          target => CFG_GRPCI2_TARGET,
          dma => CFG_GRPCI2_DMA,
          tracebuffer => CFG_GRPCI2_TRACE,
          vendorid => CFG_GRPCI2_VID,
          deviceid => CFG_GRPCI2_DID,
          classcode => CFG_GRPCI2_CLASS,
          revisionid => CFG_GRPCI2_RID,
          cap_pointer => CFG_GRPCI2_CAP,
          ext_cap_pointer => CFG_GRPCI2_NCAP,
          iobase => CFG_AHBIO,
          extcfg => CFG_GRPCI2_EXTCFG,
          bar0 => CFG_GRPCI2_BAR0,
          bar1 => CFG_GRPCI2_BAR1,
          bar2 => CFG_GRPCI2_BAR2,
          bar3 => CFG_GRPCI2_BAR3,
          bar4 => CFG_GRPCI2_BAR4,
          bar5 => CFG_GRPCI2_BAR5,
          fifo_depth => CFG_GRPCI2_FDEPTH,
          fifo_count => CFG_GRPCI2_FCOUNT,
          conv_endian => CFG_GRPCI2_ENDIAN,
          deviceirq => CFG_GRPCI2_DEVINT,
          deviceirqmask => CFG_GRPCI2_DEVINTMSK,
          hostirq => CFG_GRPCI2_HOSTINT,
          hostirqmask => CFG_GRPCI2_HOSTINTMSK,
          nsync => 2,
          hostrst => 1,
          bypass => CFG_GRPCI2_BYPASS,
          debug => 0,
          tbapben => 0,
          tbpindex => 5,
          tbpaddr => 16#400#,
          tbpmask => 16#C00#
          )
        port map (
          rstn,
          clkm,
          pciclk,
          pci_dirq,
          pcii,
          pcio,
          apbi,
          apbo(4),
          ahbsi,
          ahbso(4),
          ahbmi,
          ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG),
          ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+1),
          open,
          open,
          open,
          open);

    end generate;

    grpci1x : if (CFG_GRPCI2_MASTER+CFG_GRPCI2_TARGET) = 0 and CFG_PCI /= 0 generate

    pci_gr0 : if CFG_PCI = 1 generate	-- simple target-only
      pci0 : pci_target generic map (hindex => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG,
	device_id => CFG_PCIDID, vendor_id => CFG_PCIVID)
      port map (rstn, clkm, pciclk, pcii, pcio, ahbmi, ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG));
    end generate;

    pci_mtf0 : if CFG_PCI = 2 generate	-- master/target with fifo
      pci0 : pci_mtf generic map (memtech => memtech, hmstndx => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG, 
	  fifodepth => log2(CFG_PCIDEPTH), device_id => CFG_PCIDID, vendor_id => CFG_PCIVID,
	  hslvndx => 4, pindex => 4, paddr => 4, haddr => 16#E00#,
	  ioaddr => 16#400#, nsync => 2, hostrst => 1)
      port map (rstn, clkm, pciclk, pcii, pcio, apbi, apbo(4),
	ahbmi, ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG), ahbsi, ahbso(4));
    end generate;

    pci_mtf1 : if CFG_PCI = 3 generate	-- master/target with fifo and DMA
      dma : pcidma generic map (memtech => memtech, dmstndx => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+1, 
	  dapbndx => 5, dapbaddr => 5, blength => blength, mstndx => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG,
	  fifodepth => log2(fifodepth), device_id => CFG_PCIDID, vendor_id => CFG_PCIVID,
	  slvndx => 4, apbndx => 4, apbaddr => 4, haddr => 16#E00#, ioaddr => 16#800#, 
	  nsync => 2, hostrst => 1)
      	port map (rstn, clkm, pciclk, pcii, pcio, apbo(5),  ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+1), 
 	  apbi, apbo(4), ahbmi, ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG), ahbsi, ahbso(4));
    end generate;
    end generate;

    pci_trc0 : if CFG_PCITBUFEN /= 0 generate	-- PCI trace buffer
      pt0 : pcitrace generic map (depth => (6 + log2(CFG_PCITBUF/256)), 
	memtech => memtech, pindex  => 13, paddr => 16#100#, pmask => 16#f00#)
        port map ( rstn, clkm, pciclk, pcii, apbi, apbo(13));
    end generate;

    pcia0 : if CFG_PCI_ARB = 1 generate	-- PCI arbiter
      pciarb0 : pciarb generic map (pindex => 8, paddr => 8, 
				    apb_en => CFG_PCI_ARBAPB)
       port map ( clk => pciclk, rst_n => pcii.rst,
         req_n => pci_arb_req_n, frame_n => pcii.frame,
         gnt_n => pci_arb_gnt_n, pclk => clkm, 
         prst_n => rstn, apbi => apbi, apbo => apbo(8)
       );
      pgnt_pad : outpadv generic map (tech => padtech, width => 4) 
	port map (pci_arb_gnt, pci_arb_gnt_n);
      preq_pad : inpadv generic map (tech => padtech, width => 4) 
	port map (pci_arb_req, pci_arb_req_n);
    end generate;

    pcipads0 : pcipads generic map (padtech => padtech, host => 1, oepol => OEPOL,
                                    noreset => 0, drivereset => 0, int => 10)	-- PCI pads
    port map ( pci_rst, pci_gnt, pci_idsel, pci_lock, pci_ad, pci_cbe,
      pci_frame, pci_irdy, pci_trdy, pci_devsel, pci_stop, pci_perr,
      pci_par, pci_req, pci_serr, pci_host, pci_66, pcii, pcio, pci_int);

  end generate;

--  nop1 : if CFG_PCI <= 1 generate apbo(4) <= apb_none; end generate;
--  nop2 : if CFG_PCI <= 2 generate apbo(5) <= apb_none; end generate;
--  nop3 : if CFG_PCI <= 1 generate ahbso(4) <= ahbs_none; end generate;
--  notrc : if CFG_PCITBUFEN = 0 generate apbo(8) <= apb_none; end generate;
--  noarb : if CFG_PCI_ARB = 0 generate apbo(10) <= apb_none; end generate;


-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

  eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC
      e1 : greth generic map(hindex => CFG_NCPU+CFG_AHB_UART+CFG_GRPCI2_TARGET+CFG_GRPCI2_DMA+log2x(CFG_PCI)+CFG_AHB_JTAG,
	pindex => 14, paddr => 14, pirq => 12, memtech => memtech,
        mdcscaler => CPU_FREQ/1000, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
        nsync => 1, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF,
        macaddrh => CFG_ETH_ENM, macaddrl => CFG_ETH_ENL, 
	ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_ETH_IPL)
     port map( rst => rstn, clk => clkm, ahbmi => ahbmi,
       ahbmo => ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_GRPCI2_TARGET+CFG_GRPCI2_DMA+log2x(CFG_PCI)+CFG_AHB_JTAG), apbi => apbi,
       apbo => apbo(14), ethi => ethi, etho => etho); 

      emdio_pad : iopad generic map (tech => padtech) 
      port map (emdio, etho.mdio_o, etho.mdio_oe, ethi.mdio_i);
      etxc_pad : inpad generic map (tech => padtech) 
	port map (etx_clk, ethi.tx_clk);
      erxc_pad : inpad generic map (tech => padtech) 
	port map (erx_clk, ethi.rx_clk);
      erxd_pad : inpadv generic map (tech => padtech, width => 4) 
	port map (erxd, ethi.rxd(3 downto 0));
      erxdv_pad : inpad generic map (tech => padtech) 
	port map (erx_dv, ethi.rx_dv);
      erxer_pad : inpad generic map (tech => padtech) 
	port map (erx_er, ethi.rx_er);
      erxco_pad : inpad generic map (tech => padtech) 
	port map (erx_col, ethi.rx_col);
      erxcr_pad : inpad generic map (tech => padtech) 
	port map (erx_crs, ethi.rx_crs);

      etxd_pad : outpadv generic map (tech => padtech, width => 4) 
	port map (etxd, etho.txd(3 downto 0));
      etxen_pad : outpad generic map (tech => padtech) 
	port map ( etx_en, etho.tx_en);
      etxer_pad : outpad generic map (tech => padtech) 
	port map (etx_er, etho.tx_er);
      emdc_pad : outpad generic map (tech => padtech) 
	port map (emdc, etho.mdc);

--      emdis_pad : outpad generic map (tech => padtech) 
--	port map (emddis, vcc(0));
--      eepwrdwn_pad : outpad generic map (tech => padtech) 
--	port map (epwrdwn, gnd(0));
--      esleep_pad : outpad generic map (tech => padtech) 
--	port map (esleep, gnd(0));
--      epause_pad : outpad generic map (tech => padtech) 
--	port map (epause, gnd(0));
--      ereset_pad : outpad generic map (tech => padtech) 
--	port map (ereset, gnd(0));

    end generate;

-----------------------------------------------------------------------
---  CAN --------------------------------------------------------------
-----------------------------------------------------------------------

   can0 : if CFG_CAN = 1 generate 
     can0 : can_mc generic map (slvndx => 6, ioaddr => CFG_CANIO,
    	iomask => 16#FF0#, irq => CFG_CANIRQ, memtech => memtech,
	ncores => CFG_CAN_NUM, sepirq => CFG_CANSEPIRQ)
        port map (rstn, clkm, ahbsi, ahbso(6), can_lrx, can_ltx );

     can_pads : for i in 0 to CFG_CAN_NUM-1 generate
         can_tx_pad : outpad generic map (tech => padtech)
            port map (can_txd(i), can_ltx(i));
         can_rx_pad : inpad generic map (tech => padtech)
            port map (can_rxd(i), can_lrx(i));
     end generate;
   end generate;

--   can_stb <= '0';   -- no standby
   ncan : if CFG_CAN = 0 generate ahbso(6) <= ahbs_none; end generate;

-----------------------------------------------------------------------
---  AHB RAM ----------------------------------------------------------
-----------------------------------------------------------------------

--  ocram : if CFG_AHBRAMEN = 1 generate 
--    ahbram0 : ftahbram generic map (hindex => 7, haddr => CFG_AHBRADDR, 
--	tech => CFG_MEMTECH, kbytes => CFG_AHBRSZ, pindex => 6,
--	paddr => 6, edacen => CFG_AHBRAEDAC, autoscrub => CFG_AHBRASCRU,
--	errcnten => CFG_AHBRAECNT, cntbits => CFG_AHBRAEBIT)
--    port map ( rstn, clkm, ahbsi, ahbso(7), apbi, apbo(6), open);
--  end generate;
--
--  nram : if CFG_AHBRAMEN = 0 generate ahbso(7) <= ahbs_none; end generate;

-----------------------------------------------------------------------
---  SPACEWIRE  -------------------------------------------------------
-----------------------------------------------------------------------
  spw : if CFG_SPW_EN > 0 generate
    spw_clk_pad : clkpad generic map (tech => padtech) port map (spw_clk, spw_clkl); 
--   spw_clkl <= pciclk;
    spw_rxtxclk <= spw_clkl;
    spw_rxclkn <= not spw_rxtxclk;
    
   swloop : for i in 0 to CFG_SPW_NUM-1 generate
     -- GRSPW2 PHY
     spw2_input : if CFG_SPW_GRSPW = 2 generate
       spw_phy0 : grspw2_phy
         generic map(
           scantest   => 0,
           tech       => fabtech,
           input_type => CFG_SPW_INPUT)
         port map(
           rstn       => rstn,
           rxclki     => spw_rxtxclk,
           rxclkin    => spw_rxclkn,
           nrxclki    => spw_rxtxclk,
           di         => dtmp(i),
           si         => stmp(i),
           do         => spwi(i).d(1 downto 0),
           dov        => spwi(i).dv(1 downto 0),
           dconnect   => spwi(i).dconnect(1 downto 0),
           rxclko     => spw_rxclk(i));
       spwi(i).nd <= (others => '0');  -- Only used in GRSPW
       spwi(i).dv(3 downto 2) <= "00";  -- For second port
     end generate spw2_input;
     
     -- GRSPW PHY
     spw1_input: if CFG_SPW_GRSPW = 1 generate
       spw_phy0 : grspw_phy
         generic map(
           tech         => fabtech,
           rxclkbuftype => 1,
           scantest     => 0)
         port map(
           rxrst      => spwo(i).rxrst,
           di         => dtmp(i),
           si         => stmp(i),
           rxclko     => spw_rxclk(i),
           do         => spwi(i).d(0),
           ndo        => spwi(i).nd(4 downto 0),
           dconnect   => spwi(i).dconnect(1 downto 0));
       spwi(i).d(1) <= '0';
       spwi(i).dv <= (others => '0');  -- Only used in GRSPW2
       spwi(i).nd(9 downto 5) <= "00000";  -- For second port
     end generate spw1_input;

     spwi(i).d(3 downto 2) <= "00";   -- For second port
     spwi(i).dconnect(3 downto 2) <= "00";  -- For second port     
     spwi(i).s(1 downto 0) <= "00";  -- Only used in PHY
     
   sw0 : grspwm generic map(tech => fabtech,
     hindex => CFG_NCPU+CFG_AHB_UART+CFG_GRPCI2_TARGET+CFG_GRPCI2_DMA+log2x(CFG_PCI)+CFG_AHB_JTAG+CFG_GRETH+i,
     pindex => 10+i, paddr => 10+i, pirq => 5+i, 
     sysfreq => CPU_FREQ, nsync => 1, rmap => CFG_SPW_RMAP, 
     rmapcrc => CFG_SPW_RMAPCRC, fifosize1 => CFG_SPW_AHBFIFO, 
     fifosize2 => CFG_SPW_RXFIFO, rxclkbuftype => 1, memtech => memtech,
     rmapbufs => CFG_SPW_RMAPBUF,ft => CFG_SPW_FT, ports => 1,
     dmachan => CFG_SPW_DMACHAN, netlist => CFG_SPW_NETLIST, spwcore => CFG_SPW_GRSPW,
     input_type => CFG_SPW_INPUT, output_type => CFG_SPW_OUTPUT,
     rxtx_sameclk => CFG_SPW_RTSAME, rxunaligned => CFG_SPW_RXUNAL)
     port map(rstn, clkm, spw_rxclk(i), spw_rxclk(i), spw_rxtxclk, spw_rxtxclk,
              ahbmi,
              ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_GRPCI2_TARGET+CFG_GRPCI2_DMA+log2x(CFG_PCI)+CFG_AHB_JTAG+CFG_GRETH+i),
              apbi, apbo(10+i), spwi(i), spwo(i));
     spwi(i).tickin <= '0'; spwi(i).rmapen <= '0';
     spwi(i).clkdiv10 <= conv_std_logic_vector(CPU_FREQ/10000-1, 8);
     spwi(i).dcrstval <= (others => '0');
     spwi(i).timerrstval <= (others => '0');
     spw_rxd_pad : inpad_ds generic map (padtech, lvds, x25v)
	 port map (spw_rxdp(i), spw_rxdn(i), dtmp(i));
     spw_rxs_pad : inpad_ds generic map (padtech, lvds, x25v)
	 port map (spw_rxsp(i), spw_rxsn(i), stmp(i));
     spw_txd_pad : outpad_ds generic map (padtech, lvds, x25v)
	 port map (spw_txdp(i), spw_txdn(i), spwo(i).d(0), gnd(0));
     spw_txs_pad : outpad_ds generic map (padtech, lvds, x25v)
	 port map (spw_txsp(i), spw_txsn(i), spwo(i).s(0), gnd(0));
   end generate;
  end generate;

-----------------------------------------------------------------------
---  Drive unused bus elements  ---------------------------------------
-----------------------------------------------------------------------

--  nam1 : for i in (CFG_NCPU+CFG_AHB_UART+log2x(CFG_PCI)+CFG_AHB_JTAG) to NAHBMST-1 generate
--    ahbmo(i) <= ahbm_none;
--  end generate;
--  nam2 : if CFG_PCI > 1 generate
--    ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+log2x(CFG_PCI)-1) <= ahbm_none;
--  end generate;
--  nap0 : for i in 11 to NAPBSLV-1 generate apbo(i) <= apb_none; end generate;
--  apbo(6) <= apb_none;

-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
  generic map (
   msg1 => "LEON3FT GR-CPCI-XC4V Demonstration design",
   fabtech => tech_table(fabtech), memtech => tech_table(memtech),
   mdel => 1
  );
-- pragma translate_on
end;
