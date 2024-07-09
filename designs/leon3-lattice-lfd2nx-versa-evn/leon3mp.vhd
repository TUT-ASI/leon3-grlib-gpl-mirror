------------------------------------------------------------------------------
--  LEON3 Demonstration design
--  Copyright (C) 2022 Cobham Gaisler
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
use gaisler.memctrl.all;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.jtag.all;
use gaisler.spi.all;
use gaisler.can.all;
use gaisler.subsys.all;
--pragma translate_off
use gaisler.sim.all;
library nexus_sim;
use nexus_sim.all;
--pragma translate_on
use work.config.all;


entity leon3mp is
  generic (
    fabtech    : integer := CFG_FABTECH;
    memtech    : integer := CFG_MEMTECH;
    padtech    : integer := CFG_PADTECH;
    ncpu       : integer := CFG_NCPU;
    disas      : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart    : integer := 1;--CFG_DUART;   -- Print UART on console
    pclow      : integer := CFG_PCLOW;
    simulation : boolean := false;
    ramfile    : string  := "ram.srec"
    );
  port (
    clk_in     : in    std_ulogic; -- FPGA main clock input: 12 MHz

    gsrn       : in    std_ulogic; -- Reset input

    led        : out   std_logic_vector(7 downto 0);
    -- PMOD0
    pmod0      : inout std_logic_vector(7 downto 0);
    -- Buttons SW3, SW5
    dip_sw     : in    std_logic_vector(3 downto 0);
    -- SPI FLASH
    spi_mclk   : out   std_logic;
    dq0_mosi   : inout   std_logic;
    dq1_miso   : inout    std_logic;
    csspin     : out   std_logic;
    dq2        : inout    std_logic;
    dq3        : inout    std_logic;
    -- UART
    rxduart    : in    std_logic;
    txduart    : out   std_logic;
    -- CAN interface
    can_tx       : out   std_logic;
    can_rx       : in    std_logic;
    can_en       : out   std_logic;
    -- Built-in JTAG interface
    -- No location constraint is necessary on these pins, though it is
    -- recommended for clarity. However, a clock constraint must be applied to
    -- tck. Note that if the Reveal debug inserter is to be used then these
    -- ports must be commented out and the AHBJTAG instantiation removed.
    tck : in std_logic;
    tms : in std_logic;
    tdi : in std_logic;
    tdo : out std_logic
  );
end;

architecture rtl of leon3mp is
  signal vcc : std_logic;
  signal gnd : std_logic;

  -- AMBA bus signals
  signal apbi  : apb_slv_in_type;
  signal apbo  : apb_slv_out_vector := (others => apb_none);
  signal ahbsi : ahb_slv_in_type;
  signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi : ahb_mst_in_type;
  signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);

  signal cgi : clkgen_in_type;
  signal cgo : clkgen_out_type;

  signal spmi : spimctrl_in_type;
  signal spmo : spimctrl_out_type;

  signal aramo : ahbram_out_type;

  signal u1i, dui : uart_in_type;
  signal u1o, duo : uart_out_type;

  signal irqi : irq_in_vector(0 to 0);
  signal irqo : irq_out_vector(0 to 0);

  signal sysi : leon_dsu_stat_base_in_type;
  signal syso : leon_dsu_stat_base_out_type;

  signal perf : l3stat_in_type;

  signal dsui : dsu_in_type;
  signal dsuo : dsu_out_type;
  signal ndsuact : std_ulogic;

  signal gpti : gptimer_in_type;

  --GRCAN
  signal ahbmi_can : ahb_mst_in_type;
  signal ahbmo_can : ahb_mst_out_type;
  signal cani : can_in_type;
  signal cano : can_out_type;

  --GRGPIO
  signal gpio0i : gpio_in_type;
  signal gpio0o : gpio_out_type;

  signal clkm, rstn         : std_ulogic;
  signal rstraw             : std_logic;
  signal lock               : std_logic;

  attribute keep                     : boolean;
  attribute keep of lock             : signal is true;
  attribute keep of clkm             : signal is true;

  constant clock_mult : integer := 10;      -- Clock multiplier
  constant clock_div  : integer := 20;      -- Clock divider
  constant BOARD_FREQ : integer := 100000;  -- CLK input frequency in KHz
  constant CPU_FREQ   : integer := BOARD_FREQ * clock_mult / clock_div;  -- CPU freq in KHz

    -- AMBA Bus indexes
  -- Masters
  constant hmidx_ahbuart    : integer := CFG_NCPU;--CFG_NCPU - 1 downto 0 is
                                                  --for leon3;
  constant hmidx_ahbjtag    : integer := hmidx_ahbuart + CFG_AHB_UART;
  constant hmidx_grcan      : integer := hmidx_ahbjtag + CFG_AHB_JTAG;
  constant maxahbm          : integer := hmidx_grcan + CFG_GRCAN;-- total number of ahbm, latest hmidx + 1

  -- Slaves
  constant hsidx_dsu        : integer := CFG_NCPU;--CFG_NCPU - 1 (see hmidx_ahbuart)
  constant hsidx_apbctrl    : integer := hsidx_dsu + 1; -- missing an enable constant for apbctrl
  constant hsidx_spimctrl   : integer := hsidx_apbctrl + 1;
  constant hsidx_ahbram     : integer := hsidx_spimctrl + CFG_SPIMCTRL;
  constant hsidx_ftahbram   : integer := hsidx_ahbram + CFG_AHBRAMEN;--CFG_FTAHBRAM_EN
  constant hsidx_ahbrep     : integer := hsidx_ftahbram
                                        --pragma translate_off
                                         + CFG_FTAHBRAM_EN
                                         --pragma translate_on
                                         ;
  constant maxahbs          : integer := hsidx_ahbrep + 1; -- total number of ahbs, latest hsidx + 1

  constant pidx_stat        : integer :=  CFG_NCPU;--CFG_NCPU - 1 (see hmidx_ahbuart)
  constant pidx_apbuart     : integer := pidx_stat + 1;
  constant pidx_irqmp       : integer := pidx_apbuart + CFG_UART1_ENABLE;
  constant pidx_gptimer     : integer := pidx_irqmp + CFG_IRQ3_ENABLE;
  constant pidx_ahbuart     : integer := pidx_gptimer + CFG_GPT_ENABLE;
  constant pidx_ftahbram    : integer := pidx_ahbuart + CFG_AHB_UART;
  constant pidx_grcan       : integer := pidx_ftahbram + CFG_FTAHBRAM_EN;
  constant pidx_grgpio      : integer := pidx_grcan + CFG_GRCAN;
  constant pidx_free        : integer := pidx_grgpio + CFG_GRGPIO_ENABLE;


  constant paddr_base       : integer :=  16#001#;  -- start position for addres allocation
  constant paddr_256byte    : integer :=  16#001#;  -- constant for 256 byte
  constant paddr_1kbyte     : integer :=  16#004#;  -- constant for 1k byte
  -- As per convention in leon designs:
  -- memctrl(ahb/apb bridge)->000, apbuart->100, irqmp->200, gptimer->300
  -- we don't use CFG_ flags as these indexes are "fixed" (as per convention)
  constant paddr_apbuart    : integer :=  paddr_base; -- requires 256byte
  constant paddr_irqmp      : integer :=  paddr_apbuart + paddr_256byte; -- requires 256byte CFG_UART1_ENABLE
  constant paddr_gptimer    : integer :=  paddr_irqmp + paddr_256byte; -- requires 256byte CFG_IRQ3_ENABLE
  constant paddr_ahbuart    : integer :=  paddr_gptimer + paddr_256byte;-- requires 256byte CFG_GPT_ENABLE
  constant paddr_ftahbram   : integer :=  paddr_ahbuart + CFG_AHB_UART*paddr_256byte; -- requires 256byte
  constant paddr_grgpio     : integer :=  paddr_ftahbram + CFG_FTAHBRAM_EN*paddr_256byte; -- requires 256byte
  constant paddr_grcan      : integer :=  (paddr_grgpio/paddr_1kbyte + 1)*paddr_1kbyte;-- requires 1kbyte, CFG_GRGPIO_ENABLE doesn't matter as we need to go to the next 400 slot anyway
  constant paddr_stat       : integer :=  (paddr_grcan/paddr_1kbyte + CFG_GRCAN)*paddr_1kbyte;-- requires 1kbyte
  --CFG_NCPU

  component GSR
    GENERIC (
      SYNCMODE : String := "ASYNC");
    PORT(
      GSR_N : IN std_logic;
      CLK : IN std_logic);
  end component;

  component pll_125i_50o is
    port(
        clki_i: in std_logic;
        rstn_i: in std_logic;
        clkop_o: out std_logic;
        clkos_o: out std_logic;
        clkos2_o: out std_logic;
        lock_o: out std_logic
        );
  end component;

begin

----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------

  vcc <= '1';
  gnd <= '0';

  cgi.pllctrl <= "00";
  cgi.pllrst <= rstraw;

  rst0 : gaisler.misc.rstgen generic map (acthigh => 0)
    port map (gsrn, clkm, lock, rstn, rstraw);
  lock <= cgo.clklock;

  --this instance is needed to provide the general reset in a lattice
  --simulation environment
  GSR_INST: GSR
    port map (GSR_N => gsrn,
              CLK => clkm);

  -- clock generator
  --FIXME
  --clkgen0 : clkgen
  --  generic map (fabtech, clock_mult, clock_div, 0, 0, 0, 0, 0, BOARD_FREQ, 0)
  --  port map (clk, gnd, clkm, open, open, open, open, cgi, cgo, open, open, open);

  clkgen_ip : pll_125i_50o port map(
    clki_i=>clk_in,
    rstn_i=>gsrn,
    clkop_o=>clkm,
    clkos_o=>open,
    clkos2_o=>open,
    lock_o=>cgo.clklock
    );


----------------------------------------------------------------------
---  AHB CONTROLLER --------------------------------------------------
----------------------------------------------------------------------

  ahb0 : ahbctrl
    generic map (ioen => 1, nahbm => maxahbm, nahbs => maxahbs, devid => LEON_LATTICE_NEXUS)
    port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);

----------------------------------------------------------------------
---  LEON3 processor and DSU -----------------------------------------
----------------------------------------------------------------------

    leon : leon_dsu_stat_base
    generic map (
      leon => CFG_LEON, ncpu => ncpu, fabtech => fabtech, memtech => memtech,
      memtechmod => CFG_LEON_MEMTECH,
      nwindows => CFG_NWIN, dsu => CFG_DSU, fpu => CFG_FPU, v8 => CFG_V8, cp => 0,
      mac => CFG_MAC, pclow => pclow, notag => 0, nwp => CFG_NWP, icen => CFG_ICEN,
      irepl => CFG_IREPL, isets => CFG_ISETS, ilinesize => CFG_ILINE,
      isetsize => CFG_ISETSZ, isetlock => CFG_ILOCK, dcen => CFG_DCEN,
      drepl => CFG_DREPL, dsets => CFG_DSETS, dlinesize => CFG_DLINE,
      dsetsize => CFG_DSETSZ, dsetlock => CFG_DLOCK, dsnoop => CFG_DSNOOP,
      ilram => CFG_ILRAMEN, ilramsize => CFG_ILRAMSZ, ilramstart => CFG_ILRAMADDR,
      dlram => CFG_DLRAMEN, dlramsize => CFG_DLRAMSZ, dlramstart => CFG_DLRAMADDR,
      mmuen => CFG_MMUEN, itlbnum => CFG_ITLBNUM, dtlbnum => CFG_DTLBNUM,
      tlb_type => CFG_TLB_TYPE, tlb_rep => CFG_TLB_REP, lddel => CFG_LDDEL,
      disas => disas, tbuf => CFG_ITBSZ, pwd => CFG_PWD, svt => CFG_SVT,
      rstaddr => CFG_RSTADDR, smp => ncpu-1, cached => CFG_DFIXED,
      wbmask => CFG_BWMASK, busw => CFG_CACHEBW, netlist => CFG_LEON_NETLIST,
      ft => CFG_LEONFT_EN, npasi => CFG_NP_ASI, pwrpsr => CFG_WRPSR,
      rex => CFG_REX, altwin => CFG_ALTWIN, mmupgsz => CFG_MMU_PAGE,
      grfpush => CFG_GRFPUSH,
      dsu_hindex => hsidx_dsu, dsu_haddr => 16#D00#, dsu_hmask => 16#F00#, atbsz => CFG_ATBSZ,
      stat => CFG_STAT_ENABLE, stat_pindex => pidx_stat, stat_paddr => paddr_stat,
      stat_pmask => 16#ffc#, stat_ncnt => CFG_STAT_CNT, stat_nmax => CFG_STAT_NMAX)
    port map (
      rstn => rstn, ahbclk => clkm, cpuclk => clkm, hclken => vcc,
      leon_ahbmi => ahbmi, leon_ahbmo => ahbmo(CFG_NCPU-1 downto 0),
      leon_ahbsi => ahbsi, leon_ahbso => ahbso,
      irqi => irqi, irqo => irqo,
      stat_apbi => apbi, stat_apbo => apbo(pidx_stat), stat_ahbsi => ahbsi,
      stati => perf,
      dsu_ahbsi => ahbsi, dsu_ahbso => ahbso(hsidx_dsu),
      dsu_tahbmi => ahbmi, dsu_tahbsi => ahbsi,
      sysi => sysi, syso => syso);

  sysi.dsu_enable <= '1';
  sysi.dsu_break <= '0';

  led(0) <= syso.proc_errorn;
  led(1) <= syso.dsu_active;

  -- Debug UART
  -- If jtag debug link is active, then the uart is not instantiated
  dcomgen0 : if CFG_AHB_UART = 1 and CFG_AHB_JTAG = 0 generate
    dcom0: ahbuart              -- Debug UART
      generic map (hindex => NCPU, pindex => pidx_ahbuart, paddr => paddr_ahbuart)
      port map (rstn, clkm, dui, duo, apbi, apbo(pidx_ahbuart), ahbmi, ahbmo(hmidx_ahbuart));
    dui.rxd    <= rxduart;
    dui.ctsn   <= '0';
    dui.extclk <= '0';
    txduart    <= duo.txd;
  end generate;
  nodcom0 : if CFG_AHB_UART = 0 generate
    duo.txd <= '0'; duo.rtsn <= '1';
  end generate;

  -- Debug JTAG
  dcomgen1 : if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => hmidx_ahbjtag)
      port map(rstn, clkm, tck, tms, tdi, tdo, ahbmi, ahbmo(hmidx_ahbjtag),
               open, open, open, open, open, open, open, gnd);
  end generate;

----------------------------------------------------------------------
---  Memory controllers ----------------------------------------------
----------------------------------------------------------------------
  -- SPI memory controller (boot memory)
  spi_gen: if CFG_SPIMCTRL = 1 generate
    spimctrl0 : spimctrl
      generic map (hindex => hsidx_spimctrl, hirq => 10, faddr => 0, fmask => 16#ff0#, --16 MByte
                   ioaddr => 16#000#, iomask => 16#fff#,
                   spliten => CFG_SPLIT,
                   sdcard => CFG_SPIMCTRL_SDCARD, readcmd => CFG_SPIMCTRL_READCMD,
                   dummybyte => CFG_SPIMCTRL_DUMMYBYTE,
                   dualoutput => CFG_SPIMCTRL_DUALOUTPUT, scaler => CFG_SPIMCTRL_SCALER,
                   altscaler => CFG_SPIMCTRL_ASCALER)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_spimctrl), spmi, spmo);

    spi_mosi_pad0 : iopad generic map (tech => padtech)
      port map (dq0_mosi, spmo.mosi, spmo.mosioen, spmi.mosi);
    spi_miso_pad0 : iopad generic map (tech => padtech)
      port map (dq1_miso, spmo.miso, spmo.misooen, spmi.miso);
    spi_slvsel0_pad0 : outpad generic map (tech => padtech)
      port map (csspin, spmo.csn);
    spi_clk_pad0 : outpad generic map (tech => padtech)
      port map (spi_mclk, spmo.sck);
    --for quad-mode
    spi_dq2_pad0: iopad generic map (tech => padtech)
      port map (dq2, spmo.io2, spmo.iooen, spmi.io2);
    spi_dq3_pad0: iopad generic map (tech => padtech)
      port map (dq3, spmo.io3, spmo.iooen, spmi.io3);
    spmi.cd <= '0';
  end generate;
  -- it shouldn't be needed anymore as we moved to indexes
  -- nospi: if CFG_SPIMCTRL = 0 generate
  --   ahbso(3) <= ahbs_none;
  -- end generate;

  -- On-chip RAM (volatile memory)
  ocram : if CFG_FTAHBRAM_EN = 0 and CFG_AHBRAMEN = 1 and simulation = false generate
    ahbram0 : ahbram
      generic map (hindex => hsidx_ahbram, haddr => CFG_AHBRADDR, tech => CFG_MEMTECH,
                   kbytes => CFG_AHBRSZ, pipe => CFG_AHBRPIPE)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbram));
    -- it shouldn't be needed anymore as we moved to indexes
    -- aramo <= ahbram_out_none;
    -- apbo(10) <= apb_none;
  end generate;

  ftocram : if CFG_FTAHBRAM_EN = 1 and simulation = false generate
    ftahbram0 : ftahbram
      generic map (
        hindex    => hsidx_ftahbram, haddr => CFG_FTAHBRAM_ADDR,
        tech      => CFG_MEMTECH, kbytes    => CFG_FTAHBRAM_SZ,
        pindex    => pidx_ftahbram,  paddr => paddr_ftahbram,
        edacen    => CFG_FTAHBRAM_EDAC, autoscrub => CFG_FTAHBRAM_SCRU,
        errcnten  => CFG_FTAHBRAM_ECNT, cntbits   => CFG_FTAHBRAM_EBIT,
        ahbpipe   => CFG_FTAHBRAM_PIPE)
      port map (
        rst   => rstn,
        clk   => clkm,
        ahbsi => ahbsi,
        ahbso => ahbso(hsidx_ftahbram),
        apbi  => apbi,
        apbo  => apbo(pidx_ftahbram),
        aramo => aramo);
  end generate;

  -- it shouldn't be needed anymore as we moved to indexes
  -- nram : if CFG_AHBRAMEN = 0 and CFG_FTAHBRAM_EN = 0 generate
  --   ahbso(4) <= ahbs_none; apbo(10) <= apb_none;
  --   aramo <= ahbram_out_none;
  -- end generate;

----------------------------------------------------------------------
---  APB Bridge and various periherals -------------------------------
----------------------------------------------------------------------

  apb0 : apbctrl       -- APB Bridge
    generic map (hindex => hsidx_apbctrl, haddr => 16#800#)
    port map (rstn, clkm, ahbsi, ahbso(hsidx_apbctrl), apbi, apbo);

  uart1gen: if CFG_UART1_ENABLE = 1 generate
    uart1 : apbuart      -- UART 1
      generic map (pindex   => pidx_apbuart, paddr => paddr_apbuart, pirq => 2, console => dbguart)
      port map (rstn, clkm, apbi, apbo(pidx_apbuart), u1i, u1o);
    u1i.rxd    <= rxduart;
    u1i.ctsn   <= '0';
    u1i.extclk <= '0';

    txduartpad: if CFG_AHB_UART = 0 or CFG_AHB_JTAG = 1 generate
      txduart    <= u1o.txd;
    end generate;
  end generate;

  irqctrlgen: if CFG_IRQ3_ENABLE = 1 generate
    irqctrl0 : irqmp     -- Interrupt controller
      generic map (pindex => pidx_irqmp, paddr => paddr_irqmp, ncpu => 1)
      port map (rstn, clkm, apbi, apbo(pidx_irqmp), irqo, irqi);
  end generate;

  timergen: if CFG_GPT_ENABLE = 1 generate
    timer0 : gptimer     -- Time Unit
      generic map (pindex => pidx_gptimer, paddr => paddr_gptimer, pirq => 8,
                   sepirq => 1, ntimers => 2)
      port map (rstn, clkm, apbi, apbo(pidx_gptimer), gpti, open);
    gpti <= gpti_dhalt_drive('0');--dsuo.tstop
  end generate;


  -----------------------------------------------------------------------------
  -- GRGPIO instantiation
  -----------------------------------------------------------------------------
  gpio0 : if CFG_GRGPIO_ENABLE = 1 generate
    -- all button and switches generate irq 4
    -- 0-3 LED4-7
    -- 4-11 PMOD0
    -- 12-13 SW3, SW5
    grgpio0: grgpio
      generic map(
        pindex    => pidx_grgpio, paddr => paddr_grgpio,
        nbits     => CFG_GRGPIO_WIDTH,
        imask     => CFG_GRGPIO_IMASK,
        pirq      => 4,
        irqgen    => 1,
        iflagreg  => 1
        )
      port map(rstn, clkm, apbi, apbo(pidx_grgpio), gpio0i, gpio0o);

    gpio_leds_pad : outpadv generic map (tech => padtech, width => 4)
      port map (led(7 downto 4), gpio0o.dout(3 downto 0));
    gpio_pmod_pads : iopadvv generic map (tech => padtech, width => 8)
      port map (pmod0, gpio0o.dout(11 downto 4), gpio0o.oen(11 downto 4), gpio0i.din(11 downto 4));
    gpio_dipsw_inpads : inpadv generic map (tech => padtech, width => 4)
      port map (dip_sw, gpio0i.din(15 downto 12));

  end generate;


  -----------------------------------------------------------------------------
  -- GRCAN instantiation
  -----------------------------------------------------------------------------
  grcangen : if CFG_GRCAN = 1 generate
    can_dut : grcan
      generic map(
        hindex         => hmidx_grcan,
        pindex         => pidx_grcan,
        paddr          => paddr_grcan,
        pmask          => 16#FFC#,
        pirq           => 1,
        singleirq      => 1,
        txchannels     => 1,
        rxchannels     => 1,
        ptrwidth       => 16)
      port map(
        clk            => clkm,
        rstn           => rstn,
        ahbi           => ahbmi_can,
        ahbo           => ahbmo_can,
        apbi           => apbi,
        apbo           => apbo(pidx_grcan),
        cani           => cani,
        cano           => cano
        );

    ahbmi_can <= ahbmi;
    ahbmo(hmidx_grcan)  <= ahbmo_can;
  end generate;

  nogrcangen1 : if CFG_GRCAN = 0 generate
    cano <= (tx => "11", en => "00");
    ahbmo_can <= ahbm_none;
  end generate;

  -- GRCAN pads
  cantx0_pad : outpad
    generic map (tech => padtech) port map (can_tx, cano.tx(0));
  canrx0_pad : inpad
    generic map (tech => padtech) port map (can_rx, cani.rx(0));
  canen0_pad : outpad
    generic map (tech => padtech) port map (can_en, gnd);


  -- AHBRAM for simulation purposes
  ahbsim_gen: if simulation = true generate

    -- pragma translate_off
    sim_ahbram : ahbram_sim
      generic map (
        hindex        => hsidx_ahbram,
        haddr         => 16#400#,
        hmask         => 16#C00#,
        tech          => 0,
        kbytes        => 1024,
        pipe          => 0,
        maccsz        => AHBDW,
        fname         => ramfile
        )
      port map(
        rst     => rstn,
        clk     => clkm,
        ahbsi   => ahbsi,
        ahbso   => ahbso(hsidx_ahbram)
        );
  -- pragma translate_on
  end generate ahbsim_gen;

-----------------------------------------------------------------------
--  Test report module, only used for simulation ----------------------
-----------------------------------------------------------------------

--pragma translate_off
  test0 : ahbrep generic map (hindex => hsidx_ahbrep, haddr => 16#200#)
    port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbrep));
--pragma translate_on


-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
    generic map (
      msg1 => "LEON3 Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel => 1
      );
-- pragma translate_on

end rtl;
