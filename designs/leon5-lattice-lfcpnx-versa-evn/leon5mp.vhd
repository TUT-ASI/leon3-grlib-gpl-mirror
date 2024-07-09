-----------------------------------------------------------------------------
--LEON5 Lattice CertusPRO Demonstration design
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

library grlib, techmap;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
use techmap.gencomp.all;
library gaisler;
use gaisler.memctrl.all;
use gaisler.leon3.all;
use gaisler.leon5.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.jtag.all;
use gaisler.subsys.all;

-- pragma translate_off
use gaisler.sim.all;
library nexus_sim;
use nexus_sim.all;
-- pragma translate_on


use work.config.all;

entity leon5mp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    disas                   : integer := CFG_DISAS;   -- Enable disassembly to console
    ahbtrace                : integer := CFG_AHBTRACE;
    simulation              : boolean := false;
    autonegotiation         : integer := 1
    );
  port (
    -- Clock and Reset
    reset       : in    std_ulogic;
    clk_in      : in    std_ulogic;
    -- Switches
    switch      : in    std_logic_vector(3 downto 0);
    -- LEDs
    led         : out   std_logic_vector(7 downto 0);
    -- GPIOs
    gpio        : inout std_logic_vector(15 downto 0);
    -- UART
    dsurx       : in    std_ulogic;
    dsutx       : out   std_ulogic;
    dsuctsn     : in    std_ulogic;
    dsurtsn     : out   std_ulogic;
    -- Push Buttons (Active High)
    button      : in    std_logic_vector(4 downto 0)
    );
end;


architecture rtl of leon5mp is

  -----------------------------------------------------
  -- Constants ----------------------------------------
  -----------------------------------------------------

  constant maxahbm      : integer := 16;
  constant maxahbs      : integer := 16;

  constant OEPOL        : integer := padoen_polarity(padtech);

  constant ramfile      : string := "ram.srec"; -- ram contents

  constant MEMAHB_IOADDR : integer := 16#FFE#;

  -----------------------------------------------------
  -- Signals ------------------------------------------
  -----------------------------------------------------

  signal irqi : irq_in_vector(0 to CFG_NCPU - 1);
  signal irqo : irq_out_vector(0 to CFG_NCPU - 1);

  signal sysi : leon_dsu_stat_base_in_type;
  signal syso : leon_dsu_stat_base_out_type;

  signal perf : l3stat_in_type;

  signal ndsuact : std_ulogic;

  -- Misc
  signal vcc            : std_ulogic;
  signal gnd            : std_ulogic;
  signal stati          : ahbstat_in_type;
  signal dsu_sel        : std_ulogic;

  -- Clocks and Reset
  signal clkm           : std_ulogic := '0';
  signal rstn           : std_ulogic;
  signal rstraw         : std_ulogic;
  signal cgi            : clkgen_in_type;
  signal cgo            : clkgen_out_type;

  attribute keep     : boolean;
  attribute keep of clkm : signal is true;

  signal lock           : std_ulogic;
  signal lclk           : std_ulogic;
  signal rst            : std_ulogic;

  -- APB UART
  signal u1i            : uart_in_type;
  signal u1o            : uart_out_type;

  -- AHB UART
  signal dui            : uart_in_type;
  signal duo            : uart_out_type;

  signal dsurx_int      : std_ulogic;
  signal dsutx_int      : std_ulogic;
  signal dsuctsn_int    : std_ulogic;
  signal dsurtsn_int    : std_ulogic;

  -- Timers
  signal gpti           : gptimer_in_type;
  signal gpto           : gptimer_out_type;

  -- GPIOs
  signal gpioi          : gpio_in_type;
  signal gpioo          : gpio_out_type;

  -- JTAG
  signal tck            : std_ulogic;
  signal tckn           : std_ulogic;
  signal tms            : std_ulogic;
  signal tdi            : std_ulogic;
  signal tdo            : std_ulogic;

  function max(x,y: integer) return integer is
  begin
    if x>y then return x; else return y; end if;
  end max;

  -- Bus indexes
  constant hmidx_cpu     : integer := 0;
  constant hmidx_free    : integer := hmidx_cpu + CFG_NCPU;
  constant l5sys_nextmst : integer := max(hmidx_free-CFG_NCPU, 1);

  constant hdidx_ahbuart : integer := 0;
  constant hdidx_ahbjtag : integer := hdidx_ahbuart + CFG_AHB_UART;
  constant hdidx_free    : integer := hdidx_ahbjtag + CFG_AHB_JTAG;
  constant l5sys_ndbgmst : integer := max(hdidx_free, 1);

  constant hsidx_ahbram    : integer := 0;
  constant hsidx_ahbrom    : integer := hsidx_ahbram  + CFG_AHBRAMEN;
  constant hsidx_ahbrep    : integer := hsidx_ahbrom  + CFG_AHBROMEN;
  constant hsidx_free      : integer := hsidx_ahbrep
--pragma translate_off
                                        + 1
--pragma translate_on
                                        ;
  constant l5sys_nextslv : integer := max(hsidx_free, 1);

  constant pidx_ahbuart  : integer := 0;
  constant pidx_gpio     : integer := pidx_ahbuart + CFG_AHB_UART;
  constant pidx_ahbstat  : integer := pidx_gpio    + CFG_GRGPIO_ENABLE;
  constant pidx_free     : integer := pidx_ahbstat + CFG_AHBSTAT;
  constant l5sys_nextapb : integer := pidx_free;

  -- AHB and  APB
  signal ahbmi: ahb_mst_in_type;
  signal ahbmo: ahb_mst_out_vector_type(CFG_NCPU+l5sys_nextmst-1 downto CFG_NCPU);
  signal ahbsi: ahb_slv_in_type;
  signal ahbso: ahb_slv_out_vector_type(l5sys_nextslv-1 downto 0);
  signal dbgmi: ahb_mst_in_vector_type(l5sys_ndbgmst-1 downto 0);
  signal dbgmo: ahb_mst_out_vector_type(l5sys_ndbgmst-1 downto 0);
  signal apbi : apb_slv_in_type;
  signal apbo : apb_slv_out_vector;

  signal dsuen, dsubreak: std_ulogic;
  signal cpu0errn: std_ulogic;

  component GSR
    GENERIC (
      SYNCMODE : String := "ASYNC");
    PORT(
      GSR_N : IN std_logic;
      CLK : IN std_logic);
  end component;

  component pll_125i_35o is
    port(
        clki_i: in std_logic;-- 12MHz
        rstn_i: in std_logic;
        clkop_o: out std_logic;-- 72MHz
        clkos_o: out std_logic;-- 96MHz
        clkos2_o: out std_logic;-- 192MHz
        lock_o: out std_logic
        );
  end component;

begin

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------

  vcc         <= '1';
  gnd         <= '0';
  cgi.pllctrl <= "00";
  cgi.pllrst  <= rstraw;


  reset_pad : inpad
    generic map (tech => padtech)
    port map (reset, rst);

  rst0 : gaisler.misc.rstgen        -- reset generator
    generic map (acthigh => 0)--, syncin => 0)
    port map (rst, clkm, lock, rstn, rstraw);
  lock <= cgo.clklock;

  --this instance is needed to provide the general reset in a lattice
  --simulation environment
  GSR_INST: GSR
    port map (GSR_N => rst,
              CLK => clkm);

  -- clock generator
  --FIXME
  --clkgen0 : clkgen
  --  generic map (fabtech, clock_mult, clock_div, 0, 0, 0, 0, 0, BOARD_FREQ, 0)
  --  port map (clk, gnd, clkm, open, open, open, open, cgi, cgo, open, open, open);

  clkgen_ip : pll_125i_35o port map(
    clki_i=>clk_in,
    rstn_i=>rst,
    clkop_o=>clkm,
    clkos_o=>open,
    clkos2_o=>open,
    lock_o=>cgo.clklock
    );

  ----------------------------------------------------------------------
  -- LEDs
  ----------------------------------------------------------------------

  dsusel_pad : outpad
    generic map (tech => padtech)
    port map (led(4), dsu_sel);
  led5_pad : outpad
    generic map (tech => padtech)
    port map (led(5), cpu0errn);
  led7_pad : outpad generic map (tech => padtech)
    port map (led(7), lock);

  ----------------------------------------------------------------------
  -- LEON5 processor system
  ----------------------------------------------------------------------

  l5sys : leon5sys
    generic map (
      fabtech  => fabtech,
      memtech  => memtech,
      ncpu     => CFG_NCPU,
      nextmst  => l5sys_nextmst,
      nextslv  => l5sys_nextslv,
      nextapb  => l5sys_nextapb,
      ndbgmst  => l5sys_ndbgmst,
      ahbsplit => 1,
      cached   => CFG_DFIXED,
      wbmask   => CFG_BWMASK,
      busw     => CFG_AHBW,
      fpuconf  => CFG_FPUTYPE,
      perfcfg  => 1,
      cmemconf => 0,
      rfconf   => 0,
      disas    => disas,
      ahbtrace => ahbtrace,
      devid    => LEON5_XILINX_KCU105
      )
    port map (
      clk      => clkm,
      rstn     => rstn,
      ahbmi    => ahbmi,
      ahbmo    => ahbmo(CFG_NCPU+l5sys_nextmst-1 downto CFG_NCPU),
      ahbsi    => ahbsi,
      ahbso    => ahbso(l5sys_nextslv-1 downto 0),
      dbgmi    => dbgmi,
      dbgmo    => dbgmo,
      apbi     => apbi,
      apbo     => apbo,
      dsuen    => '1',
      dsubreak => dsubreak,
      cpu0errn => cpu0errn,
      uarti    => u1i,
      uarto    => u1o
      );

  nomst: if hmidx_free=CFG_NCPU generate
    ahbmo(CFG_NCPU) <= ahbm_none;
  end generate;
  noslv: if hsidx_free=0 generate
    ahbso(0) <= ahbs_none;
  end generate;


  dsui_break_pad : inpad
    generic map (level => cmos)
    port map (button(4), open);
  dsubreak <= '0'
--pragma translate_off
              and '0'
--pragma translate_on
              ;

  -----------------------------------------------------------------------------
  -- Debug UART ---------------------------------------------------------------
  -----------------------------------------------------------------------------

  -- Debug UART
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map (hindex => hdidx_ahbuart, pindex => pidx_ahbuart, paddr => 0)
      port map (rstn, clkm, dui, duo, apbi, apbo(pidx_ahbuart), dbgmi(hdidx_ahbuart), dbgmo(hdidx_ahbuart));
    dui.extclk <= '0';
  end generate;

  nouah : if CFG_AHB_UART = 0 generate
    duo.txd <= '0';
    duo.rtsn <= '0';
    dui.extclk <= '0';
  end generate;

  -- sw4_pad : inpad
  --   generic map (tech => padtech, level => cmos, voltage => x12v)
  --   port map (switch(3), dsu_sel);
  dsu_sel <= '1';

  dsutx_int     <= duo.txd     when dsu_sel = '1' else u1o.txd;
  dui.rxd       <= dsurx_int   when dsu_sel = '1' else '1';
  dsurtsn_int   <= duo.rtsn    when dsu_sel = '1' else u1o.rtsn;
  dui.ctsn      <= dsuctsn_int when dsu_sel = '1' else '1';
  u1i.rxd       <= dsurx_int   when dsu_sel = '0' else '1';
  u1i.ctsn      <= dsuctsn_int when dsu_sel = '0' else '1';

  dsurx_pad   : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech) port map (dsurx, dsurx_int);
  dsutx_pad   : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech) port map (dsutx, dsutx_int);
  dsuctsn_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech) port map (dsuctsn, dsuctsn_int);
  dsurtsn_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech) port map (dsurtsn, dsurtsn_int);

  -----------------------------------------------------------------------------
  -- JTAG debug link ----------------------------------------------------------
  -----------------------------------------------------------------------------

  ahbjtaggen0 :if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => hdidx_ahbjtag)
      port map(rstn, clkm, tck, tms, tdi, tdo, dbgmi(hdidx_ahbjtag), dbgmo(hdidx_ahbjtag),
               open, open, open, open, open, open, open, gnd);
  end generate;

  -----------------------------------------------------------------------
  ---  AHB RAM ----------------------------------------------------------
  -----------------------------------------------------------------------

  ocram : if CFG_AHBRAMEN = 1 generate
    ahbram0 : ahbram
      generic map (hindex => hsidx_ahbram, haddr => CFG_AHBRADDR, tech => CFG_MEMTECH,
                   kbytes => CFG_AHBRSZ, pipe => CFG_AHBRPIPE)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbram));
  end generate;


-----------------------------------------------------------------------
---  AHB ROM ----------------------------------------------------------
-----------------------------------------------------------------------

--  bpromgen : if CFG_AHBROMEN /= 0 or (simulation = true) generate
  bpromgen : if CFG_AHBROMEN /= 0 generate
    brom : entity work.ahbrom128
      generic map (hindex => hsidx_ahbrom, haddr => CFG_AHBRODDR, pipe => CFG_AHBROPIP)
      port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbrom));
  end generate;


  ----------------------------------------------------------------------
  --- Various APB periherals --------------------------------
  ----------------------------------------------------------------------

  -- GPIO units
  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate

    grgpio_ledsw : grgpio
      generic map(
        pindex => pidx_gpio,
        paddr => 10,
        imask => CFG_GRGPIO_IMASK,
        nbits => CFG_GRGPIO_WIDTH)
      port map(
        rst   => rstn,
        clk   => clkm,
        apbi  => apbi,
        apbo  => apbo(pidx_gpio),
        gpioi => gpioi,
        gpioo => gpioo);

    -- Tie-off alternative output enable signals
    gpioi.sig_en        <= (others => '0');
    gpioi.sig_in        <= (others => '0');

    gpled_pads : for i in 0 to 3 generate
      gpled_pad : outpad
        generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (led(i), gpioo.dout(i+16));
    end generate gpled_pads;

    gpsw_pads : for i in 0 to 2 generate
      gpsw_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (switch(i), gpioi.din(i));
    end generate gpsw_pads;
    gpioi.din(3) <= dsu_sel;

    gpbut_pads : for i in 0 to 3 generate
      gpsw_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (button(i), gpioi.din(i+4));
    end generate gpbut_pads;

    pio_pads : for i in 0 to 7 generate
      gpio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x12v, strength => 8)
        port map (gpio(i), gpioo.dout(i+8), gpioo.oen(i+8), gpioi.din(i+8));
    end generate;

  end generate;

  -----------------------------------------------------------------------
  ---  AHB Status Register ----------------------------------------------
  -----------------------------------------------------------------------

  ahbs : if CFG_AHBSTAT = 1 generate
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat
      generic map (pindex => pidx_ahbstat, paddr => 15, pirq => 7,
                   nftslv => CFG_AHBSTATN)
      port map(rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(pidx_ahbstat));
  end generate;

  -----------------------------------------------------------------------
  ---  Test report module  ----------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  test0 : ahbrep
    generic map (hindex => hsidx_ahbrep, haddr => 16#200#)
    port map (rstn, clkm, ahbsi, ahbso(hsidx_ahbrep));
  -- pragma translate_on

  -----------------------------------------------------------------------
  ---  Boot message  ----------------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  x : report_design
    generic map (
      msg1    => "LEON5/GRLIB Lattice CertusPRO Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
      );
-- pragma translate_on
end;
