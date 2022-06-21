-----------------------------------------------------------------------------
--  LEON3 Demonstration design
--  Copyright (C) 2016 Cobham Gaisler
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
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;

library techmap;
use techmap.gencomp.all;

library gaisler;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.i2c.all;
use gaisler.spi.all;

--pragma translate_off
use gaisler.sim.all;
--pragma translate_on

use work.config.all;

entity leon3mp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;     -- Enable disassembly to console
    dbguart                 : integer := CFG_DUART;     -- Print UART on console
    pclow                   : integer := CFG_PCLOW;
    SIM_BYPASS_INIT_CAL     : string := "OFF";
    SIMULATION              : string := "FALSE";
    USE_MIG_INTERFACE_MODEL : boolean := false
    );
  port (
    CLK100MHZ          : in    std_ulogic;
    -- schematic LED{0,1,2,3}_{R,G,B}
    led0_r, led0_g, led0_b : out   std_logic;
    led1_r, led1_g, led1_b : out   std_logic;
    led2_r, led2_g, led2_b : out   std_logic;
    led3_r, led3_g, led3_b : out   std_logic;
    -- schematic LED4, LED5, LED6, LED7. 0: off, 1: on
    led                : out   std_logic_vector(3 downto 0);
    -- Red button with label "RESET"
    ck_rst             : in    std_ulogic;
    -- Buttons 0: not pressed, 1: pressed
    btn                : in    std_logic_vector(3 downto 0);
    -- Switches
    sw                 : in    std_logic_vector(3 downto 0);
    -- PMOD
    ja                 : inout std_logic_vector(7 downto 0);
    jb                 : inout std_logic_vector(7 downto 0);
    jc                 : inout std_logic_vector(7 downto 0);
    jd                 : inout std_logic_vector(7 downto 0);
    -- Arduino/ChipKit Outer Digital Header
    ck_io              : inout std_logic_vector(13 downto 0);
    -- Arduino/ChipKit Outer Analog Header - as Digital I/O
    ck_a               : inout std_logic_vector(5 downto 0);
    -- Arduino/ChipKit I2C
    ck_scl             : inout std_ulogic;
    ck_sda             : inout std_ulogic;
    -- Arduino/ChipKit SPI
    ck_miso            : in    std_ulogic;
    ck_mosi            : out   std_ulogic;
    ck_sck             : out   std_ulogic;
    ck_ss              : out   std_ulogic;
    -- USB-RS232 interface
    uart_txd_in        : in    std_ulogic;
    uart_rxd_out       : out   std_ulogic;
    -- QSPI
    qspi_sck          : out   std_ulogic;
    qspi_cs           : out   std_ulogic;
    qspi_dq           : inout std_logic_vector(1 downto 0);
    -- DDR3
    ddr3_dq           : inout std_logic_vector(15 downto 0);
    ddr3_dqs_p        : inout std_logic_vector(1 downto 0);
    ddr3_dqs_n        : inout std_logic_vector(1 downto 0);
    ddr3_addr         : out   std_logic_vector(13 downto 0);
    ddr3_ba           : out   std_logic_vector(2 downto 0);
    ddr3_ras_n        : out   std_logic;
    ddr3_cas_n        : out   std_logic;
    ddr3_we_n         : out   std_logic;
    ddr3_reset_n      : out   std_logic;
    ddr3_ck_p         : out   std_logic_vector(0 downto 0);
    ddr3_ck_n         : out   std_logic_vector(0 downto 0);
    ddr3_cke          : out   std_logic_vector(0 downto 0);
    ddr3_cs_n         : out   std_logic_vector(0 downto 0);
    ddr3_dm           : out   std_logic_vector(1 downto 0);
    ddr3_odt          : out   std_logic_vector(0 downto 0);

    -- Ethernet PHY, 10/100 Mbit, TI DP83848J
    eth_col            : in    std_ulogic;
    eth_crs            : in    std_ulogic;
    eth_mdc            : out   std_ulogic;
    eth_mdio           : inout std_ulogic;
    eth_ref_clk        : out   std_ulogic;
    eth_rstn           : out   std_ulogic;
    eth_rx_clk         : in    std_ulogic;
    eth_rx_dv          : in    std_ulogic;
    eth_rxd            : in    std_logic_vector(3 downto 0);
    eth_rxerr          : in    std_ulogic;
    eth_tx_clk         : in    std_ulogic;
    eth_tx_en          : out   std_ulogic;
    eth_txd            : out   std_logic_vector(3 downto 0)
  );
end;

architecture rtl of leon3mp is
  signal spmi : spimctrl_in_type;
  signal spmo : spimctrl_out_type;

  signal apbi  : apb_slv_in_type;
  signal apbo  : apb_slv_out_vector := (others => apb_none);
  signal ahbsi : ahb_slv_in_type;
  signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi : ahb_mst_in_type;
  signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);

  signal u1i, dui : uart_in_type;
  signal u1o, duo : uart_out_type;

  signal irqi : irq_in_vector(0 to CFG_NCPU-1);
  signal irqo : irq_out_vector(0 to CFG_NCPU-1);

  signal dbgi : l3_debug_in_vector(0 to CFG_NCPU-1);
  signal dbgo : l3_debug_out_vector(0 to CFG_NCPU-1);

  signal dsui : dsu_in_type;
  signal dsuo : dsu_out_type;

  signal ethi : eth_in_type;
  signal etho : eth_out_type;

  signal gpti : gptimer_in_type;
  signal i2ci : i2c_in_type;
  signal i2co : i2c_out_type;
  signal spii : spi_in_type;
  signal spio : spi_out_type;
  signal slvsel : std_logic_vector(0 downto 0);
  signal gpio0i, gpio1i, gpio2i : gpio_in_type;
  signal gpio0o, gpio1o, gpio2o : gpio_out_type;

  signal clkm : std_ulogic
  -- pragma translate_off 
  := '0'
  -- pragma translate_on
  ;
  
  signal rstn               : std_ulogic;
  signal tck, tms, tdi, tdo : std_ulogic;
  signal rstnraw            : std_logic;
  signal reset_button       : std_ulogic;
  signal lock        : std_logic;
  signal clkinmig           : std_logic;
  signal eth_ref_clki       : std_ulogic;
  signal clkref, calib_done, migrstn : std_logic;

  signal pll_locked         : std_ulogic;

  signal rxd1 : std_logic;
  signal txd1 : std_logic;

  signal swint  : std_logic_vector(sw'range);
  signal rgbled : std_logic_vector(4*3-1 downto 0);

  attribute keep                     : boolean;
  attribute syn_keep                 : boolean;
  attribute syn_preserve             : boolean;
  attribute syn_keep of lock         : signal is true;
  attribute syn_keep of clkm         : signal is true;
  attribute syn_preserve of clkm     : signal is true;
  attribute keep of lock             : signal is true;
  attribute keep of clkm             : signal is true;

  constant BOARD_FREQ : integer := 100000;                                -- CLK input frequency in KHz
  constant OEPOL : integer := padoen_polarity(padtech);

  -- cpu frequency in KHz
  function CPU_FREQ return integer is
  begin
    if CFG_MIG_7SERIES = 1 then
      return BOARD_FREQ * 10 / 6 / 2;
    end if;
    return BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;
  end;

begin

  swint_pad : inpadv generic map (tech => padtech, width => sw'length)
    port map (sw, swint);
----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------

  rst_pad : inpad generic map (tech => padtech)
    port map (ck_rst, reset_button);

  rst0 : rstgen
    port map (reset_button, clkm, lock, rstn, rstnraw);
  
  lock <= calib_done and pll_locked;

  rst1 : rstgen
    port map (reset_button, clkm, '1', migrstn, open);

  led(1) <= calib_done;
  led(0) <= lock;

----------------------------------------------------------------------
---  AHB CONTROLLER --------------------------------------------------
----------------------------------------------------------------------

  ahb0 : ahbctrl
    generic map (defmast => CFG_DEFMST, split => CFG_SPLIT,
                 rrobin  => CFG_RROBIN, ioaddr => CFG_AHBIO, ioen => 1,
                 nahbm => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+CFG_GRETH,
                 ahbtrace => CFG_AHB_DTRACE,
                 nahbs => 8)
    port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);

----------------------------------------------------------------------
---  LEON3 processor and DSU -----------------------------------------
----------------------------------------------------------------------

  -- LEON3 processor
  leon3nogen : if CFG_LEON3 = 0 generate
    led(3)  <= '0';
    led(2)  <= '0';
    ahbmo(0) <= ahbm_none;
  end generate;

  leon3gen : if CFG_LEON3 = 1 generate
    cpu : for i in 0 to CFG_NCPU-1 generate
      u0 : leon3s
        generic map (i, fabtech, memtech, CFG_NWIN, CFG_DSU, CFG_FPU, CFG_V8,
                     0, CFG_MAC, pclow, CFG_NOTAG, CFG_NWP, CFG_ICEN, CFG_IREPL, CFG_ISETS, CFG_ILINE,
                     CFG_ISETSZ, CFG_ILOCK, CFG_DCEN, CFG_DREPL, CFG_DSETS, CFG_DLINE, CFG_DSETSZ,
                     CFG_DLOCK, CFG_DSNOOP, CFG_ILRAMEN, CFG_ILRAMSZ, CFG_ILRAMADDR, CFG_DLRAMEN,
                     CFG_DLRAMSZ, CFG_DLRAMADDR, CFG_MMUEN, CFG_ITLBNUM, CFG_DTLBNUM, CFG_TLB_TYPE, CFG_TLB_REP,
                     CFG_LDDEL, disas, CFG_ITBSZ, CFG_PWD, CFG_SVT, CFG_RSTADDR,
                     CFG_NCPU-1, CFG_DFIXED, CFG_SCAN, CFG_MMU_PAGE, CFG_BP, CFG_NP_ASI, CFG_WRPSR,
                     CFG_REX, CFG_ALTWIN)
        port map (clkm, rstn, ahbmi, ahbmo(i), ahbsi, ahbso, irqi(i), irqo(i), dbgi(i), dbgo(i));
    end generate;

    led(3)  <= not dbgo(0).error;
    led(2)  <= dsuo.active;

    -- LEON3 Debug Support Unit
    dsugen : if CFG_DSU = 1 generate
      dsu0 : dsu3
        generic map (hindex => 2, haddr => 16#900#, hmask => 16#F00#, ahbpf => CFG_AHBPF,
                     ncpu   => CFG_NCPU, tbits => 30, tech => memtech, irq => 0, kbytes => CFG_ATBSZ)
        port map (rstn, clkm, ahbmi, ahbsi, ahbso(2), dbgo, dbgi, dsui, dsuo);

      dsui.enable <= swint(3);
      dsubre_pad : inpad generic map (tech => padtech) port map (btn(3), dsui.break);

    end generate;
  end generate;
  nodsu : if CFG_DSU = 0 generate
    ahbso(2) <= ahbs_none; dsuo.tstop <= '0'; dsuo.active <= '0';
  end generate;

  -- Debug UART
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map (hindex => CFG_NCPU, pindex => 7, paddr => 7)
      port map (rstn, clkm, dui, duo, apbi, apbo(7), ahbmi, ahbmo(CFG_NCPU));
    dsurx_pad : inpad generic map (tech  => padtech) port map (uart_txd_in, dui.rxd);
    dsutx_pad : outpad generic map (tech => padtech) port map (uart_rxd_out, duo.txd);
--    led(0) <= not dui.rxd;
--    led(1) <= not duo.txd;
  end generate;
  nouah : if CFG_AHB_UART = 0 generate apbo(7) <= apb_none; end generate;

  ahbjtaggen0 :if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => CFG_NCPU+CFG_AHB_UART)
      port map(rstn, clkm, tck, tms, tdi, tdo, ahbmi, ahbmo(CFG_NCPU+CFG_AHB_UART),
               open, open, open, open, open, open, open, '0');
  end generate;

----------------------------------------------------------------------
---  DDR3 Memory controller ------------------------------------------
----------------------------------------------------------------------

  mig_gen : if (CFG_MIG_7SERIES = 1) generate
    -- Generate 200 MHz, 166.7 MHz and 25 Mhz
    clockers0 : entity work.clockers_mig
    port map (
      rstn        => rstnraw,
      clkin       => CLK100MHZ,
      mig_clkref  => clkref,
      clkm        => clkinmig,
      eth_ref     => eth_ref_clki,
      locked      => pll_locked
    );

    gen_mig : if (USE_MIG_INTERFACE_MODEL /= true) generate
      ddrc : entity work.ahb2mig_arty_a7
        generic map (
          hindex => 5, haddr => 16#400#, hmask => 16#F00#, pindex => 5, paddr => 5,
          SIM_BYPASS_INIT_CAL => SIM_BYPASS_INIT_CAL, SIMULATION => SIMULATION,
          USE_MIG_INTERFACE_MODEL => USE_MIG_INTERFACE_MODEL)
        port map(
          ddr3_dq         => ddr3_dq,
          ddr3_dqs_p      => ddr3_dqs_p,
          ddr3_dqs_n      => ddr3_dqs_n,
          ddr3_addr       => ddr3_addr,
          ddr3_ba         => ddr3_ba,
          ddr3_ras_n      => ddr3_ras_n,
          ddr3_cas_n      => ddr3_cas_n,
          ddr3_we_n       => ddr3_we_n,
          ddr3_reset_n    => ddr3_reset_n,
          ddr3_ck_p       => ddr3_ck_p,
          ddr3_ck_n       => ddr3_ck_n,
          ddr3_cke        => ddr3_cke,
          ddr3_cs_n       => ddr3_cs_n,
          ddr3_dm         => ddr3_dm,
          ddr3_odt        => ddr3_odt,
          ahbsi           => ahbsi,
          ahbso           => ahbso(5),
          apbi            => apbi,
          apbo            => apbo(5),
          calib_done      => calib_done,
          rst_n_syn       => migrstn,
          rst_n_async     => rstnraw,
          clk_amba        => clkm,
          sys_clk_i       => clkinmig,
          clk_ref_i       => clkref,
          ui_clk          => clkm,
          ui_clk_sync_rst => open
          );
  
  end generate gen_mig;
  
  gen_mig_model : if (USE_MIG_INTERFACE_MODEL = true) generate
    -- pragma translate_off
  
    mig_ahbram : ahbram_sim
      generic map (
        hindex   => 5,
        haddr    => 16#400#,
        hmask    => 16#F80#,
        tech     => 0,
        kbytes   => 1000,
        pipe     => 0,
        maccsz   => AHBDW,
        fname    => "ram.srec"
        )
      port map(
        rst     => rstn,
        clk     => clkm,
        ahbsi   => ahbsi,
        ahbso   => ahbso(5)
        );
  
    ddr3_dq           <= (others => 'Z');
    ddr3_dqs_p        <= (others => 'Z');
    ddr3_dqs_n        <= (others => 'Z');
    ddr3_addr         <= (others => '0');
    ddr3_ba           <= (others => '0');
    ddr3_ras_n        <= '0';
    ddr3_cas_n        <= '0';
    ddr3_we_n         <= '0';
    ddr3_ck_p         <= (others => '0');
    ddr3_ck_n         <= (others => '0');
    ddr3_cke          <= (others => '0');
    ddr3_cs_n         <= (others => '1');
    ddr3_dm           <= (others => '0');
    ddr3_odt          <= (others => '0');
    ddr3_reset_n      <= '0';
  
    calib_done <= '1';
       
    clkm <= not clkm after 10.0 ns;
    -- pragma translate_on
  
  end generate gen_mig_model;    end generate;
  
  nomig : if (CFG_MIG_7SERIES = 0) generate
    -- Generate clkm and eth_ref_clk
    clockers0 : entity work.clockers_clkgen
    generic map (
      clktech     => clktech,
      freq        => BOARD_FREQ,
      mul         => CFG_CLKMUL,
      div         => CFG_CLKDIV
    )
    port map (
      rstn        => rstnraw,
      clkin       => CLK100MHZ,
      clkm        => clkm,
      eth_ref     => eth_ref_clki,
      locked      => pll_locked
    );
    calib_done <= '1';

   gen_ahbram : if (SIMULATION = "FALSE") generate
    mig_ahbram : ahbram
      generic map (
        hindex   => 5,
        haddr    => 16#400#,
        hmask    => 16#F80#,
        tech     => 0,
        kbytes   => 64,
        pipe     => 0
        )
      port map(
        rst     => rstn,
        clk     => clkm,
        ahbsi   => ahbsi,
        ahbso   => ahbso(5)
        );
   end generate;

   gen_ahbram_sim : if (SIMULATION = "TRUE") generate
    -- pragma translate_off
    mig_ahbram : ahbram_sim
      generic map (
        hindex   => 5,
        haddr    => 16#400#,
        hmask    => 16#F80#,
        tech     => 0,
        kbytes   => 1000,
        pipe     => 0,
        maccsz   => AHBDW,
        fname    => "ram.srec"
        )
      port map(
        rst     => rstn,
        clk     => clkm,
        ahbsi   => ahbsi,
        ahbso   => ahbso(5)
        );
    -- pragma translate_on
   end generate;
  end generate;

  spimctrl0: if CFG_SPIMCTRL /= 0 generate -- SPI Memory Controller
    spimc : spimctrl
      generic map (hindex => 0, hirq => 10, faddr => 16#000#, fmask  => 16#e00#,
                   ioaddr => 16#000#, iomask => 16#800#,
                   spliten => CFG_SPLIT, oepol => OEPOL,sdcard => CFG_SPIMCTRL_SDCARD,
                   readcmd => CFG_SPIMCTRL_READCMD, dummybyte => CFG_SPIMCTRL_DUMMYBYTE,
                   dualoutput => CFG_SPIMCTRL_DUALOUTPUT, scaler => CFG_SPIMCTRL_SCALER,
                   altscaler => CFG_SPIMCTRL_ASCALER, pwrupcnt => CFG_SPIMCTRL_PWRUPCNT,
                   offset => CFG_SPIMCTRL_OFFSET)
      port map (rstn, clkm, ahbsi, ahbso(0), spmi, spmo);
  end generate;
  nospimctrl0 : if CFG_SPIMCTRL = 0 generate spmo <= spimctrl_out_none; end generate;

  miso_pad : inpad generic map (tech => padtech)
    port map (qspi_dq(1), spmi.miso);
  mosi_pad : outpad generic map (tech => padtech)
    port map (qspi_dq(0), spmo.mosi);
  sck_pad  : outpad generic map (tech => padtech)
    port map (qspi_sck, spmo.sck);
  slvsel0_pad : outpad generic map (tech => padtech)
    port map (qspi_cs, spmo.csn);

----------------------------------------------------------------------
---  APB Bridge and various periherals -------------------------------
----------------------------------------------------------------------

  -- APB Bridge
  apb0 : apbctrl
    generic map (hindex => 1, haddr => CFG_APBADDR)
    port map (rstn, clkm, ahbsi, ahbso(1), apbi, apbo);

  -- Interrupt controller
  irqctrl : if CFG_IRQ3_ENABLE /= 0 generate
    irqctrl0 : irqmp
      generic map (pindex => 2, paddr => 2, ncpu => CFG_NCPU)
      port map (rstn, clkm, apbi, apbo(2), irqo, irqi);
  end generate;
  irq3 : if CFG_IRQ3_ENABLE = 0 generate
    x1 : for i in 0 to CFG_NCPU-1 generate
      irqi(i).irl <= "0000";
    end generate;
    apbo(2) <= apb_none;
  end generate;

  -- Timer Unit
  gpt : if CFG_GPT_ENABLE /= 0 generate
    timer0 : gptimer
      generic map (pindex => 3, paddr => 3, pirq => CFG_GPT_IRQ,
                   sepirq => CFG_GPT_SEPIRQ, sbits => CFG_GPT_SW,
                   ntimers => CFG_GPT_NTIM, nbits  => CFG_GPT_TW)
      port map (rstn, clkm, apbi, apbo(3), gpti, open);
    gpti <= gpti_dhalt_drive(dsuo.tstop);
  end generate;
  notim : if CFG_GPT_ENABLE = 0 generate apbo(3) <= apb_none; end generate;

  i2cm: if CFG_I2C_ENABLE = 1 generate  -- I2C master
    i2c0 : i2cmst
      generic map (pindex => 4, paddr => 4, pmask => 16#FFF#,
                   pirq => 3, filter => 5, dynfilt => 1)
      port map (rstn, clkm, apbi, apbo(4), i2ci, i2co);
  end generate;
  noi2cm: if CFG_I2C_ENABLE = 0 generate
    i2co.scloen <= '1'; i2co.sdaoen <= '1';
    i2co.scl <= '0'; i2co.sda <= '0';
  end generate;
  i2c_scl_pad : iopad generic map (tech => padtech)
    port map (ck_scl, i2co.scl, i2co.scloen, i2ci.scl);
  i2c_sda_pad : iopad generic map (tech => padtech)
    port map (ck_sda, i2co.sda, i2co.sdaoen, i2ci.sda);

  spic: if CFG_SPICTRL_ENABLE = 1 generate  -- SPI controller
    spi1 : spictrl
      generic map (pindex => 6, paddr  => 6, pmask  => 16#fff#, pirq => 5,
                   fdepth => CFG_SPICTRL_FIFO, slvselen => 1,
                   slvselsz => 1, odmode => 0,
                   twen => 0,
                   syncram => CFG_SPICTRL_SYNCRAM,
                   memtech => memtech
      )
      port map (rstn, clkm, apbi, apbo(6), spii, spio, slvsel);
    spii.spisel <= '1';                 -- Master only
    spii.astart <= '0';
    miso_pad : inpad generic map (tech => padtech)
      port map (ck_miso, spii.miso);
    mosi_pad : outpad generic map (tech => padtech)
      port map (ck_mosi, spio.mosi);
    sck_pad  : outpad generic map (tech => padtech)
      port map (ck_sck, spio.sck);
    slvsel_pad : outpad generic map (tech => padtech)
      port map (ck_ss, slvsel(0));
  end generate spic;

  ua1 : if CFG_UART1_ENABLE /= 0 generate
    uart1 : apbuart                     -- UART 1
      generic map (pindex   => 1, paddr => 1, pirq => 2, console => dbguart, fifosize => CFG_UART1_FIFO)
      port map (rstn, clkm, apbi, apbo(1), u1i, u1o);
    u1i.rxd    <= rxd1;
    u1i.ctsn   <= '0';
    u1i.extclk <= '0';
    txd1       <= u1o.txd;
      uartgen : if CFG_AHB_UART = 0 generate
        urx_pad : inpad  generic map (tech => padtech) port map (uart_txd_in,  rxd1);
        tx_pad  : outpad generic map (tech => padtech) port map (uart_rxd_out, txd1);
      end generate;
  end generate;
  noua0 : if CFG_UART1_ENABLE = 0 generate apbo(1) <= apb_none; end generate;

  gpio0 : if true generate
    -- all button and switches generate irq 4
    grgpio0: grgpio
      generic map(
        pindex    => 9, paddr => 9,
        nbits     => 4+4+12,
        imask     => 16#000FF000#,
        pirq      => 4,
        irqgen    => 1,
        iflagreg  => 1
      )
      port map( rstn, clkm, apbi, apbo(9), gpio0i, gpio0o);

    rgbled_pads : toutpadvv generic map (tech => padtech, width => 4*3)
      port map (
        pad => rgbled,
        i   => gpio0o.dout(11 downto 0),
        en  => gpio0o.oen(11 downto 0)
      );
      led3_r <= rgbled(11);
      led3_g <= rgbled(10);
      led3_b <= rgbled( 9);
      led2_r <= rgbled( 8);
      led2_g <= rgbled( 7);
      led2_b <= rgbled( 6);
      led1_r <= rgbled( 5);
      led1_g <= rgbled( 4);
      led1_b <= rgbled( 3);
      led0_r <= rgbled( 2);
      led0_g <= rgbled( 1);
      led0_b <= rgbled( 0);

    gpio_0_inpads : inpadv generic map (tech => padtech, width => 4)
      port map (btn, gpio0i.din(15 downto 12));

    gpio0i.din(19 downto 16) <= swint(3 downto 0);
  end generate;
  nogpio0: if false generate apbo(9) <= apb_none; end generate;

  gpio1 : if true generate
    -- PMOD with interrupt map registers to generate AHB interrupt 1..15
    grgpio1: grgpio
      generic map(
        pindex    => 10, paddr => 10,
        nbits     => 4*8,
        imask     => 16#7FFFFFFF#,
        pirq      => 6,
        irqgen    => 1,
        iflagreg  => 1
      )
      port map( rstn, clkm, apbi, apbo(10), gpio1i, gpio1o);
    gpio_ja_pads :  iopadvv generic map (tech => padtech, width => 8)
      port map (ja, gpio1o.dout( 7 downto  0), gpio1o.oen( 7 downto  0), gpio1i.din( 7 downto  0));
    gpio_jb_pads :  iopadvv generic map (tech => padtech, width => 8)
      port map (jb, gpio1o.dout(15 downto  8), gpio1o.oen(15 downto  8), gpio1i.din(15 downto  8));
    gpio_jc_pads :  iopadvv generic map (tech => padtech, width => 8)
      port map (jc, gpio1o.dout(23 downto 16), gpio1o.oen(23 downto 16), gpio1i.din(23 downto 16));
    gpio_jd_pads :  iopadvv generic map (tech => padtech, width => 8)
      port map (jd, gpio1o.dout(31 downto 24), gpio1o.oen(31 downto 24), gpio1i.din(31 downto 24));
  end generate;
  nogpio1: if false generate apbo(10) <= apb_none; end generate;

  gpio2 : if true generate
    -- "Arduino Shield Connector" with interrupt map registers to generate AHB interrupt 1..15
    grgpio2: grgpio
      generic map(
        pindex    => 11, paddr => 11,
        nbits     => 6 + 14,
        imask     => 16#000FFFFF#,
        pirq      => 7,
        irqgen    => 1,
        iflagreg  => 1
      )
      port map( rstn, clkm, apbi, apbo(11), gpio2i, gpio2o);
    gpio_ck_a_pads  :  iopadvv generic map (tech => padtech, width =>  6)
      port map (ck_a,  gpio2o.dout(19 downto 14), gpio2o.oen(19 downto 14), gpio2i.din(19 downto 14));
    gpio_ck_io_pads :  iopadvv generic map (tech => padtech, width => 14)
      port map (ck_io, gpio2o.dout(13 downto  0), gpio2o.oen(13 downto  0), gpio2i.din(13 downto  0));
  end generate;
  nogpio2: if false generate apbo(11) <= apb_none; end generate;

-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

  eth0 : if CFG_GRETH /= 0 generate -- Gaisler ethernet MAC

  pci_p_clk5_r_pad : outpad generic map (tech => padtech)
    port map (eth_ref_clk, eth_ref_clki);

    e1 : grethm
      generic map(hindex => CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG,
                  pindex => 15, paddr => 15, pirq => 12, memtech => memtech,
                  mdcscaler => CPU_FREQ/1000, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
                  nsync => 2, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF,
                  macaddrh => CFG_ETH_ENM, macaddrl => CFG_ETH_ENL, phyrstadr => 1,
                  ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_ETH_IPL, giga => CFG_GRETH1G)
      port map(rst => rstn, clk => clkm, ahbmi => ahbmi,
               ahbmo => ahbmo(CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG),
               apbi => apbi, apbo => apbo(15), ethi => ethi, etho => etho);
      eth_rstn<=rstn;

    ethi.edcladdr <= (others => '0');
    emdio_pad : iopad generic map (tech => padtech)
      port map (eth_mdio, etho.mdio_o, etho.mdio_oe, ethi.mdio_i);
    etxc_pad : clkpad generic map (tech => padtech, arch => 2)
      port map (eth_tx_clk, ethi.tx_clk);
    erxc_pad : clkpad generic map (tech => padtech, arch => 2)
      port map (eth_rx_clk, ethi.rx_clk);
    erxd_pad : inpadv generic map (tech => padtech, width => 4)
      port map (eth_rxd, ethi.rxd(3 downto 0));
    erxdv_pad : inpad generic map (tech => padtech)
      port map (eth_rx_dv, ethi.rx_dv);
    erxer_pad : inpad generic map (tech => padtech)
      port map (eth_rxerr, ethi.rx_er);
    erxco_pad : inpad generic map (tech => padtech)
      port map (eth_col, ethi.rx_col);
    erxcr_pad : inpad generic map (tech => padtech)
      port map (eth_crs, ethi.rx_crs);

    etxd_pad : outpadv generic map (tech => padtech, width => 4)
      port map (eth_txd, etho.txd(3 downto 0));
    etxen_pad : outpad generic map (tech => padtech)
      port map (eth_tx_en, etho.tx_en);
    emdc_pad : outpad generic map (tech => padtech)
      port map (eth_mdc, etho.mdc);
  end generate;

-----------------------------------------------------------------------
---  AHB ROM ----------------------------------------------------------
-----------------------------------------------------------------------

  bpromgen : if CFG_AHBROMEN /= 0 and CFG_SPIMCTRL = 0 generate
    brom : entity work.ahbrom
      generic map (hindex => 0, haddr => CFG_AHBRODDR, pipe => CFG_AHBROPIP)
      port map ( rstn, clkm, ahbsi, ahbso(6));
  end generate;
  nobpromgen : if CFG_AHBROMEN = 0 and CFG_SPIMCTRL = 0 generate
     ahbso(0) <= ahbs_none;
  end generate;

-----------------------------------------------------------------------
---  AHB RAM ----------------------------------------------------------
-----------------------------------------------------------------------

  ahbramgen : if CFG_AHBRAMEN = 1 generate
    ahbram0 : ahbram
      generic map (hindex => 3, haddr => CFG_AHBRADDR, tech => CFG_MEMTECH,
                   kbytes => CFG_AHBRSZ, pipe => CFG_AHBRPIPE)
      port map (rstn, clkm, ahbsi, ahbso(3));
  end generate;
  nram : if CFG_AHBRAMEN = 0 generate ahbso(3) <= ahbs_none; end generate;

-----------------------------------------------------------------------
--  Test report module, only used for simulation ----------------------
-----------------------------------------------------------------------

--pragma translate_off
  test0 : ahbrep generic map (hindex => 4, haddr => 16#200#)
    port map (rstn, clkm, ahbsi, ahbso(4));
--pragma translate_on

-----------------------------------------------------------------------
---  Drive unused bus elements  ---------------------------------------
-----------------------------------------------------------------------

  nam1 : for i in (CFG_NCPU+CFG_AHB_UART+CFG_AHB_JTAG+CFG_GRETH+1) to NAHBMST-1 generate
    ahbmo(i) <= ahbm_none;
  end generate;

-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
    generic map (
      msg1 => "LEON3 Demonstration design for Digilent Arty A7 board" &
      ", " & integer'image(CPU_FREQ / 1000) & " MHz",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel => 1
      );
-- pragma translate_on

end rtl;

