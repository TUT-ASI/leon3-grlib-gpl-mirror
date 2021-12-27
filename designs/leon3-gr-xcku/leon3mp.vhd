-----------------------------------------------------------------------------
--  LEON3 XCKU demonstration design
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib, techmap;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
use techmap.gencomp.all;
use techmap.allclkgen.all;
library gaisler;
use gaisler.memctrl.all;
use gaisler.leon3.all;
use gaisler.leon4.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.spi.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.l2cache.all;
use gaisler.subsys.all;
-- pragma translate_off
use gaisler.sim.all;
library unisim;
use unisim.all;
-- pragma translate_on
library esa;
use esa.memoryctrl.all;

use work.config.all;

entity leon3mp is
  generic(
    fabtech : integer := CFG_FABTECH;
    memtech : integer := CFG_MEMTECH;
    padtech : integer := CFG_PADTECH;
    clktech : integer := CFG_CLKTECH;
    disas   : integer := CFG_DISAS; -- Enable disassembly to console
    dbguart : integer := CFG_DUART; -- Print UART on console
    pclow   : integer := CFG_PCLOW);
  port(
    reset        : in    std_ulogic;
    CLK_EXT_XTAL : in    std_ulogic; -- 50 MHz onboard clock
    sr_add       : out   std_logic_vector(21 downto 0);
    sr_data      : inout std_logic_vector(31 downto 0);
    rom_oen      : out   std_ulogic;
    rom_wen      : out   std_ulogic;
    rom_csn      : out   std_logic;
    sr_csn0      : out   std_logic;
    sr_oen       : out   std_logic;
    sr_wen       : out   std_logic;
    sd_add       : out   std_logic_vector(12 downto 0);
    sd_data      : inout std_logic_vector(31 downto 0);
    sd_ba        : out   std_logic_vector(1 downto 0);
    sd_csn       : out   std_ulogic;
    sd_casn      : out   std_ulogic;
    sd_rasn      : out   std_ulogic;
    sd_wen       : out   std_ulogic;
    sd_dqm       : out   std_logic_vector(3 downto 0);
    sd_cke       : out   std_ulogic;
    sd_clk       : out   std_logic_vector(2 downto 0);
    sd_clkfb     : in    std_logic_vector(2 downto 0);
    dsu_in       : in    std_ulogic;
    dsu_out      : out   std_ulogic;
    uart_in      : in    std_ulogic;
    uart_ou      : out   std_ulogic;
    spi_miso     : in    std_ulogic;
    spi_mosi     : out   std_ulogic;
    spi_sel      : out   std_logic_vector(2 downto 0);
    spi_sck      : out   std_ulogic;
    gpio         : inout std_logic_vector(15 downto 0);
    led          : out   std_logic_vector(9 downto 0);
    switch       : in    std_logic_vector(7 downto 0));
end;

architecture rtl of leon3mp is

  constant maxahbm : integer := 16;
  constant maxahbs : integer := 16;
  constant maxapbs : integer := CFG_IRQ3_ENABLE + CFG_GPT_ENABLE + CFG_GRGPIO_ENABLE + CFG_AHBSTAT + CFG_AHBSTAT;

  signal vcc, gnd : std_logic;
  signal memi     : memory_in_type;
  signal memo     : memory_out_type;
  signal wpo      : wprot_out_type;
  signal sdo      : sdram_out_type;

  signal apbi  : apb_slv_in_type;
  signal apbo  : apb_slv_out_vector := (others => apb_none);
  signal ahbsi : ahb_slv_in_type;
  signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi : ahb_mst_in_type;
  signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);

  signal sysi : leon_dsu_stat_base_in_type;
  signal syso : leon_dsu_stat_base_out_type;

  signal perf : l3stat_in_type;

  signal ui_clk             : std_ulogic;
  signal clkm               : std_ulogic := '0';
  signal rstn, rstraw       : std_ulogic;
  signal clk_200            : std_ulogic;
  signal sd_clks, sd_clkfbs : std_logic;
  signal ndsuact, nerror    : std_logic;
  signal cgi                : clkgen_in_type;
  signal cgo                : clkgen_out_type;
  signal u1i, dui           : uart_in_type;
  signal u1o, duo           : uart_out_type;

  signal irqi : irq_in_vector(0 to CFG_NCPU - 1);
  signal irqo : irq_out_vector(0 to CFG_NCPU - 1);

  signal rxd1 : std_logic;
  signal txd1 : std_logic;

  signal gpti : gptimer_in_type;
  signal gpto : gptimer_out_type;

  signal gpioi,gpioi1 : gpio_in_type;
  signal gpioo,gpioo1 : gpio_out_type;

  signal clklock : std_ulogic;

  signal lock, lclk, rst : std_ulogic;
  signal tck, tckn, tms, tdi, tdo  : std_ulogic;

  constant BOARD_FREQ : integer := 50000; -- input frequency in KHz
  constant CPU_FREQ   : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV; -- cpu frequency in KHz

  signal stati : ahbstat_in_type;

  signal dsurx_int : std_logic;
  signal dsutx_int : std_logic;

  signal wen : std_logic;

  signal clkref : std_logic;

  signal spii : spi_in_type;
  signal spio : spi_out_type;
  signal slvsel : std_logic_vector(CFG_SPICTRL_SLVS-1 downto 0);

begin

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------

  vcc         <= '1';
  gnd         <= '0';
  cgi.pllctrl <= "00";
  cgi.pllrst  <= rstraw;

  clk_pad : clkpad
    generic map(tech => padtech, level => cmos, voltage => x18v)
    port map(CLK_EXT_XTAL, lclk);
  sd_clk_gen : if CFG_MCTRL_SDEN /= 0 generate
    sd_clk_pad_gen : for i in 0 to 2 generate
      sdclk_pad : clkpad
        generic map(tech => padtech, level => cmos, voltage => x18v)
        port map(sd_clks, sd_clk(i));
    end generate sd_clk_pad_gen;
  end generate sd_clk_gen;

  clkgen0 : clkgen    -- clock generator
    generic map(clktech, CFG_CLKMUL, CFG_CLKDIV, CFG_MCTRL_SDEN, CFG_CLK_NOFB, 0, 0, 0, BOARD_FREQ)
    port map(lclk, lclk, clkm, open, open, sd_clks, open, cgi, cgo);

  reset_pad : inpad
    generic map(tech => padtech, level => cmos, voltage => x18v)
    port map(reset, rst);

  rst0 : rstgen           -- reset generator
    generic map(acthigh => 1, syncin => 1)
    port map(rst, clkm, lock, rstn, rstraw);
  lock <= cgo.clklock;

  ----------------------------------------------------------------------
  ---  AHB CONTROLLER --------------------------------------------------
  ----------------------------------------------------------------------

  ahb0 : ahbctrl          -- AHB arbiter/multiplexer
    generic map(defmast => CFG_DEFMST, split => CFG_SPLIT,
          rrobin  => CFG_RROBIN, ioaddr => CFG_AHBIO, fpnpen => CFG_FPNPEN,
          nahbm   => maxahbm, nahbs => maxahbs, devid => XILINX_KC705)
    port map(rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);

  ----------------------------------------------------------------------
  ---  LEON processor, DSU and performance counters --------------------
  ----------------------------------------------------------------------

  leon : leon_dsu_stat_base
    generic map(
      leon  => CFG_LEON, ncpu => CFG_NCPU, fabtech => fabtech, memtech => memtech,
      memtechmod  => CFG_LEON_MEMTECH,
      nwindows    => CFG_NWIN, dsu => CFG_DSU, fpu => CFG_FPU, v8 => CFG_V8, cp => 0,
      mac   => CFG_MAC, pclow => pclow, notag => 0, nwp => CFG_NWP, icen => CFG_ICEN,
      irepl       => CFG_IREPL, isets => CFG_ISETS, ilinesize => CFG_ILINE,
      isetsize    => CFG_ISETSZ, isetlock => CFG_ILOCK, dcen => CFG_DCEN,
      drepl       => CFG_DREPL, dsets => CFG_DSETS, dlinesize => CFG_DLINE,
      dsetsize    => CFG_DSETSZ, dsetlock => CFG_DLOCK, dsnoop => CFG_DSNOOP,
      ilram       => CFG_ILRAMEN, ilramsize => CFG_ILRAMSZ, ilramstart => CFG_ILRAMADDR,
      dlram       => CFG_DLRAMEN, dlramsize => CFG_DLRAMSZ, dlramstart => CFG_DLRAMADDR,
      mmuen       => CFG_MMUEN, itlbnum => CFG_ITLBNUM, dtlbnum => CFG_DTLBNUM,
      tlb_type    => CFG_TLB_TYPE, tlb_rep => CFG_TLB_REP, lddel => CFG_LDDEL,
      disas       => disas, tbuf => CFG_ITBSZ, pwd => CFG_PWD, svt => CFG_SVT,
      rstaddr     => CFG_RSTADDR, smp => CFG_NCPU - 1, cached => CFG_DFIXED,
      wbmask      => CFG_BWMASK, busw => CFG_CACHEBW, netlist => CFG_LEON_NETLIST,
      ft    => CFG_LEONFT_EN, npasi => CFG_NP_ASI, pwrpsr => CFG_WRPSR,
      rex   => CFG_REX, altwin => CFG_ALTWIN, mmupgsz => CFG_MMU_PAGE,
      grfpush     => CFG_GRFPUSH,
      dsu_hindex  => 2, dsu_haddr => 16#D00#, dsu_hmask => 16#F00#, atbsz => CFG_ATBSZ,
      stat  => CFG_STAT_ENABLE, stat_pindex => 13, stat_paddr => 16#100#,
      stat_pmask  => 16#ffc#, stat_ncnt => CFG_STAT_CNT, stat_nmax => CFG_STAT_NMAX)
    port map(
      rstn       => rstn, ahbclk => clkm, cpuclk => clkm, hclken => vcc,
      leon_ahbmi => ahbmi, leon_ahbmo => ahbmo(CFG_NCPU-1 downto 0),
      leon_ahbsi => ahbsi, leon_ahbso => ahbso,
      irqi       => irqi, irqo => irqo,
      stat_apbi  => apbi, stat_apbo => apbo(13), stat_ahbsi => ahbsi,
      stati      => perf,
      dsu_ahbsi  => ahbsi, dsu_ahbso => ahbso(2),
      dsu_tahbmi => ahbmi, dsu_tahbsi => ahbsi,
      sysi       => sysi, syso => syso);

  sysi.dsu_enable <= '1';

  nerror <= not (syso.proc_error);
  error_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(8), nerror);

  ndsuact <= syso.dsu_active;
  dsuact_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(9), ndsuact);
  
  -----------------------------------------------------------------------------
  -- Debug UART
  -----------------------------------------------------------------------------
  -- And multiplexing with APBUART
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map(hindex => CFG_NCPU, pindex => 7, paddr => 7)
      port map(rstn, clkm, dui, duo, apbi, apbo(7), ahbmi, ahbmo(CFG_NCPU));
    dui.extclk <= '0';
  end generate;

  nouah : if CFG_AHB_UART = 0 generate
    apbo(7)    <= apb_none;
    duo.txd    <= '0';
    duo.rtsn   <= '0';
    dui.extclk <= '0';
  end generate;

  dsutx_int <= duo.txd;
  dui.rxd   <= dsurx_int;

  dsurx_pad : inpad
    generic map(level => cmos, voltage => x18v, tech => padtech)
    port map(dsu_in, dsurx_int);
  dsutx_pad : outpad
    generic map(level => cmos, voltage => x18v, tech => padtech, slew => 2) 
    port map(dsu_out, dsutx_int);

  -----------------------------------------------------------------------------
  -- JTAG debug link
  -----------------------------------------------------------------------------
  ahbjtaggen0 : if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag
      generic map(tech => fabtech, hindex => CFG_NCPU + CFG_AHB_UART)
      port map(rstn, clkm, tck, tms, tdi, tdo, ahbmi, ahbmo(CFG_NCPU+CFG_AHB_UART),
         open, open, open, open, open, open, open, gnd);
  end generate;

  nojtag : if CFG_AHB_JTAG = 0 generate
    ahbmo(CFG_NCPU+CFG_AHB_UART) <= ahbm_none;
  end generate;

  ----------------------------------------------------------------------
  ---  Memory controllers ----------------------------------------------
  ----------------------------------------------------------------------

  memi.writen <= '1';
  memi.wrn    <= "1111";
  memi.bwidth <= "10";
  memi.brdyn  <= '0';
  memi.bexcn  <= '1';

  mctrl_gen : if CFG_MCTRL_LEON2 /= 0 generate
    mctrl0 : mctrl
      generic map(hindex    => 0, pindex => 0,
            paddr     => 0, srbanks => 1, ram8 => CFG_MCTRL_RAM8BIT,
            ram16     => CFG_MCTRL_RAM16BIT, sden => CFG_MCTRL_SDEN,
            invclk    => CFG_MCTRL_INVCLK, sepbus => CFG_MCTRL_SEPBUS,
            pageburst => CFG_MCTRL_PAGE, rammask => 16#C00#, ramaddr => 16#400#,
            iomask    => 0)
      port map(rstn, clkm, memi, memo, ahbsi, ahbso(0), apbi, apbo(0), wpo, sdo);

    addr_pad : outpadv
      generic map(width => 22, tech => padtech, level => cmos, voltage => x18v)
      port map(sr_add(21 downto 0), memo.address(23 downto 2));
    roms_pad : outpad
      generic map(tech => padtech, level => cmos, voltage => x18v)
      port map(rom_csn, memo.romsn(0));
    oen_pad : outpad
      generic map(tech => padtech, level => cmos, voltage => x18v)
      port map(rom_oen, memo.oen);
      --        adv_pad : outpad
      --          generic map(tech => padtech, level => cmos, voltage => x18v)
      --          port map(adv, '0');
    wri_pad : outpad
      generic map(tech => padtech, level => cmos, voltage => x18v)
      port map(rom_wen, memo.writen);
    data_pad : iopadvv
      generic map(tech => padtech, width => 32, level => cmos, voltage => x18v)
      port map(sr_data(31 downto 0), memo.data(31 downto 0),
         memo.vbdrive(31 downto 0), memi.data(31 downto 0));

      -----------SRAM ------
    sr_csn_pad : outpad
      generic map(tech => padtech, level => cmos, voltage => x18v)
      port map(sr_csn0, memo.ramsn(0));

    sr_oen_pad : outpad
      generic map(tech => padtech, level => cmos, voltage => x18v)
      port map(sr_oen, memo.ramoen(0));
    sr_wen_pad : outpad
      generic map(tech => padtech, level => cmos, voltage => x18v)
      port map(sr_wen, memo.writen);

      -------------------SDRAM--------------------------------------------------
    sdpads : if CFG_MCTRL_SDEN = 1 generate -- SDRAM controller
      sd2 : if CFG_MCTRL_SEPBUS = 1 generate
        sa_pad : outpadv generic map(width => 13) port map(sd_add, memo.sa(12 downto 0));
        sd_pad : iopadvv
          generic map(tech => padtech, width => 32, level => cmos, voltage => x18v)
          port map(sd_data(31 downto 0), memo.sddata(31 downto 0),
             memo.svbdrive(31 downto 0), memi.sd(31 downto 0));
      end generate;

      sdwen_pad : outpad
        generic map(tech => padtech, level => cmos, voltage => x18v)
        port map(sd_wen, sdo.sdwen);
      sdras_pad : outpad
        generic map(tech => padtech, level => cmos, voltage => x18v)
        port map(sd_rasn, sdo.rasn);
      sdcas_pad : outpad
        generic map(tech => padtech, level => cmos, voltage => x18v)
        port map(sd_casn, sdo.casn);
      sddqm_pad : outpadv
        generic map(width => 4, tech => padtech, level => cmos, voltage => x18v)
        port map(sd_dqm, sdo.dqm(3 downto 0));
      sdcke_pad : outpad
        generic map(tech => padtech, level => cmos, voltage => x18v)
        port map(sd_cke, sdo.sdcke(0));
      sdcsn_pad : outpad
        generic map(tech => padtech, level => cmos, voltage => x18v)
        port map(sd_csn, sdo.sdcsn(0));
      sdba_pad : outpadv
        generic map(width => 2, tech => padtech, level => cmos, voltage => x18v)
        port map(sd_ba, memo.sa(14 downto 13));
    end generate;
    ----------------------------------------------------------------------------- 

  end generate;


  ----------------------------------------------------------------------
  ---  APB Bridge and various periherals -------------------------------
  ----------------------------------------------------------------------

  apb0 : apbctrl          -- AHB/APB bridge
    generic map(hindex => 1, haddr => CFG_APBADDR, nslaves => 16, debug => 2)
    port map(rstn, clkm, ahbsi, ahbso(1), apbi, apbo);

  irqctrl : if CFG_IRQ3_ENABLE /= 0 generate
    irqctrl0 : irqmp    -- interrupt controller
      generic map(pindex => 2, paddr => 2, ncpu => CFG_NCPU)
      port map(rstn, clkm, apbi, apbo(2), irqo, irqi);
  end generate;
  irq3 : if CFG_IRQ3_ENABLE = 0 generate
    x : for i in 0 to CFG_NCPU - 1 generate
      irqi(i).irl <= "0000";
    end generate;
    apbo(2) <= apb_none;
  end generate;

  gpt : if CFG_GPT_ENABLE /= 0 generate
    timer0 : gptimer    -- timer unit
      generic map(pindex  => 3, paddr => 3, pirq => CFG_GPT_IRQ,
            sepirq  => CFG_GPT_SEPIRQ, sbits => CFG_GPT_SW, ntimers => CFG_GPT_NTIM,
            nbits   => CFG_GPT_TW, wdog => CFG_GPT_WDOGEN*CFG_GPT_WDOG)
      port map(rstn, clkm, apbi, apbo(3), gpti, gpto);
    gpti <= gpti_dhalt_drive(syso.dsu_tstop);
  end generate;

  nogpt : if CFG_GPT_ENABLE = 0 generate
    apbo(3) <= apb_none;
  end generate;

  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate  -- GPIO unit
    grgpio_ledsw : grgpio
      generic map(pindex => 10, paddr => 10, imask => CFG_GRGPIO_IMASK, nbits => 8)
      port map(rst   => rstn, clk => clkm, apbi => apbi, apbo => apbo(10),
         gpioi => gpioi, gpioo => gpioo);

    gpled_pads : for i in 0 to 7 generate
      gpled_pad : outpad
        generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (led(i), gpioo.dout(i));
    end generate gpled_pads;

    gpsw_pads : for i in 0 to 7 generate
      gpsw_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (switch(i), gpioi.din(i));
    end generate gpsw_pads;


    grgpio_hd : grgpio
      generic map(pindex => 11, paddr => 11, imask => CFG_GRGPIO_IMASK, nbits => 16)
      port map(rst   => rstn, clk => clkm, apbi => apbi, apbo => apbo(11),
         gpioi => gpioi1, gpioo => gpioo1);

    pio_pads1 : for i in 0 to 15 generate
      gpio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (gpio(i), gpioo1.dout(i), gpioo1.oen(i), gpioi1.din(i));
    end generate;
  end generate;

  ua1 : if CFG_UART1_ENABLE /= 0 generate
    uart1 : apbuart     -- UART 1
      generic map(pindex   => 1, paddr => 1, pirq => 2, console => dbguart,
            fifosize => CFG_UART1_FIFO)
      port map(rstn, clkm, apbi, apbo(1), u1i, u1o);
    u1i.extclk <= '0';
    u1i.ctsn   <= '0';
    uart_ou    <= u1o.txd;
    u1i.rxd    <= uart_in;
  end generate;

  noua0 : if CFG_UART1_ENABLE = 0 generate
    apbo(1) <= apb_none;
  end generate;

  spic : if CFG_SPICTRL_ENABLE = 1 generate  -- SPI controller
    spi1 : spictrl
      generic map (pindex   => 12, paddr => 12, pmask => 16#fff#, pirq => 12,
       fdepth   => CFG_SPICTRL_FIFO, slvselen => CFG_SPICTRL_SLVREG,
       slvselsz => CFG_SPICTRL_SLVS, odmode => 0, netlist => 0,
       syncram  => CFG_SPICTRL_SYNCRAM, ft => CFG_SPICTRL_FT)
      port map (rstn, clkm, apbi, apbo(12), spii, spio, slvsel);
    spii.spisel <= '1';          -- Master only
    miso_pad : inpad generic map (level => cmos, voltage => x18v, tech => padtech)
      port map (spi_miso, spii.miso);
    mosi_pad : outpad generic map (level => cmos, voltage => x18v, tech => padtech)
      port map (spi_mosi, spio.mosi);
    sck_pad : outpad generic map (level => cmos, voltage => x18v, tech => padtech)
      port map (spi_sck, spio.sck);
    slvsel_pads : for i in 0 to CFG_SPICTRL_SLVS-1 generate
      slvsel_pad : outpad generic map (level => cmos, voltage => x18v, tech => padtech)
        port map (spi_sel(i), slvsel(i));
    end generate slvsel_pads;
  end generate spic;

  nospi : if CFG_SPICTRL_ENABLE = 0 generate
    miso_pad : inpad generic map (level => cmos, voltage => x18v, tech => padtech)
      port map (spi_miso, spii.miso);
    mosi_pad : outpad generic map (level => cmos, voltage => x18v, tech => padtech)
      port map (spi_mosi, vcc);
    sck_pad : outpad generic map (level => cmos, voltage => x18v, tech => padtech)
      port map (spi_sck, gnd);

    slvsel_pads : for i in 0 to CFG_SPICTRL_SLVS-1 generate
      slvsel_pad : outpad generic map (level => cmos, voltage => x18v, tech => padtech)
        port map (spi_sel(i), vcc);
    end generate slvsel_pads;

  end generate;

  ahbs : if CFG_AHBSTAT = 1 generate  -- AHB status register
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat
      generic map(pindex => 15, paddr => 15, pirq => 7,
            nftslv => CFG_AHBSTATN)
      port map(rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(15));
  end generate;

  -----------------------------------------------------------------------
  ---  AHB ROM ----------------------------------------------------------
  -----------------------------------------------------------------------

  bpromgen : if CFG_AHBROMEN /= 0 generate
    brom : entity work.ahbrom
      generic map(hindex => 7, haddr => CFG_AHBRODDR, pipe => CFG_AHBROPIP)
      port map(rstn, clkm, ahbsi, ahbso(7));
  end generate;

  -----------------------------------------------------------------------
  ---  AHB RAM ----------------------------------------------------------
  -----------------------------------------------------------------------

  ocram : if CFG_AHBRAMEN = 1 generate
    ahbram0 : ahbram
      generic map(hindex => 5, haddr => CFG_AHBRADDR,
            tech   => CFG_MEMTECH, kbytes => CFG_AHBRSZ, pipe => CFG_AHBRPIPE)
      port map(rstn, clkm, ahbsi, ahbso(5));
  end generate;

  -----------------------------------------------------------------------
  ---  Test report module  ----------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  test0 : ahbrep
    generic map(hindex => 3, haddr => 16#200#)
    port map(rstn, clkm, ahbsi, ahbso(3));
    -- pragma translate_on

  -----------------------------------------------------------------------
  ---  Drive unused bus elements  ---------------------------------------
  -----------------------------------------------------------------------

  nam1 : for i in (CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG) to NAHBMST-1 generate
    ahbmo(i) <= ahbm_none;
  end generate;

  -----------------------------------------------------------------------
  ---  Boot message  ----------------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  x : report_design
    generic map(
      msg1    => "LEON/GRLIB GR-XCKU Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
    );
    -- pragma translate_on

end;
