------------------------------------------------------------------------------
--  LEON3 Demonstration design
--  Copyright (C) 2022 Cobham Gaisler
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
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
use gaisler.canfd.all;
use gaisler.subsys.all;
use gaisler.hssl.all;
use gaisler.spacewire.all;
use gaisler.grlsedc_pkg.all;
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
    clk_in     : in    std_ulogic; -- FPGA main clock input: 125 MHz

    gsrn       : in    std_ulogic; -- Reset input

    led        : out   std_logic_vector(7 downto 0);

    --PMOD1
    pmod1      : inout std_logic_vector(7 downto 0);
    --PMOD2
    pmod2      : inout std_logic_vector(7 downto 0);

    spi_mclk   : out   std_logic;
    dq0_mosi   : inout   std_logic;
    dq1_miso   : inout    std_logic;
    csspin     : out   std_logic;
    dq2        : inout    std_logic;
    dq3        : inout    std_logic;

    rxduart    : in    std_logic;
    txduart    : out   std_logic;

    -- SpaceWire & SpaceFibre (via Star-Dundee FMC SpW/SpFi Mk3 board)
    -- For differential pins, we just need to connect the signal to
    -- the positive pin, set the LVDS constraint and Radiant will do the rest
    gbtclk0_p    : in    std_ulogic;    -- SerDes clock
    gbtclk0_n    : in    std_ulogic;    -- SerDes clock
    hssl_rxp     : in    std_logic_vector(1 downto 0);
    hssl_rxn     : in    std_logic_vector(1 downto 0);
    hssl_txp     : out   std_logic_vector(1 downto 0);
    hssl_txn     : out   std_logic_vector(1 downto 0);
    spw_din_p    : in    std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    spw_sin_p    : in    std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    spw_dout_p   : out   std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);
    spw_sout_p   : out   std_logic_vector(1 to CFG_SPW_PORTS * CFG_SPW_NUM);

    -- CANFD interface
    canfd_tx     : out   std_logic;
    canfd_rx     : in    std_logic;
    canfd_en     : out   std_logic;
    -- CAN interface
    can_tx       : out   std_logic;
    can_rx       : in    std_logic;
    can_en       : out   std_logic;
    -- Built-in JTAG interface
    -- No location constraint is necessary on these pins, though it is
    -- recommended for clarity. However, a clock constraint must be applied to
    -- tck. Note that if the Reveal debug inserter is to be used then these
    -- ports must be commented out and the AHBJTAG instantiation removed.
    -- config.vhd must also be renamed.
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

  signal ahbmi_vct : ahb_mst_in_vector_type(0 downto 0);

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

  --AHBSTAT
  signal stati : ahbstat_in_type;

  --GRGPIO
  signal gpio0i : gpio_in_type;
  signal gpio0o : gpio_out_type;

  --GRCANFD
  signal ahbmi_canfd : ahb_mst_in_vector_type (0 downto 0);
  signal ahbmo_canfd : ahb_mst_out_vector_type (0 downto 0);
  signal canfdi : canfd_in_type;
  signal canfdo : canfd_out_type;

  --GRCAN
  signal ahbmi_can : ahb_mst_in_type;
  signal ahbmo_can : ahb_mst_out_type;
  signal cani : can_in_type;
  signal cano : can_out_type;

  signal clkm, clk100, rstn, reset_in : std_ulogic;
  signal rstraw             : std_logic;
  signal lock               : std_logic;

  signal cram_ue : std_ulogic;
  signal ext_rstn : std_ulogic := '1';

  attribute keep                     : boolean;
  attribute keep of lock             : signal is true;
  attribute keep of clkm             : signal is true;

  constant clock_mult : integer := 10;     -- Clock multiplier - not used
  constant clock_div  : integer := 20;     -- Clock divider - not used
  constant BOARD_FREQ : integer := 100000; -- CLK input frequency in KHz-unused
  constant CPU_FREQ   : integer := 60000;  -- CPU freq in KHz, used only in SpW
  --BOARD_FREQ * clock_mult / clock_div;

  -- SpaceWire
  signal spwi        : grspw_in_type_vector(0 to CFG_SPW_NUM - 1);
  signal spwo        : grspw_out_type_vector(0 to CFG_SPW_NUM - 1);
  signal spw_rxclk0  : std_logic_vector(0 to CFG_SPW_NUM - 1);
  signal spw_rxclk1  : std_logic_vector(0 to CFG_SPW_NUM - 1);
  signal dtmp        : std_logic_vector(0 to CFG_SPW_PORTS * CFG_SPW_NUM - 1);
  signal stmp        : std_logic_vector(0 to CFG_SPW_PORTS * CFG_SPW_NUM - 1);
  signal spw_rxclkiv : std_logic_vector(0 to CFG_SPW_PORTS * CFG_SPW_NUM - 1);
  signal spw_rxclkin : std_ulogic;
  signal spw_txclk   : std_ulogic;

  -- HSSL
  signal hssl_clk  : std_ulogic;
  signal hssl_rstn : std_ulogic;
  signal hssl_lock : std_ulogic;
  signal hssli     : grhssl_in_type_vector(0 to 1);
  signal hsslo     : grhssl_out_type_vector(0 to 1);

  -- HSSL SerDes

  type epcs_if_type is record
    txclk  : std_logic;
    rxclk  : std_logic;
    txdata : std_logic_vector(79 downto 0);
    rxdata : std_logic_vector(79 downto 0);
    txval  : std_logic;
    rxval  : std_logic;
    phyrdy : std_logic;
    ready  : std_logic;
  end record;

  type epcs_if_arr_type is array (natural range <>) of epcs_if_type;

  signal sd_ext_0_refclk : std_logic;
  signal sd_ext_1_refclk : std_logic;
  signal epcs            : epcs_if_arr_type(0 to 1);

  -- AMBA Bus indexes
  -- Masters
  constant hmidx_ahbuart    : integer := CFG_NCPU;--CFG_NCPU - 1 downto 0 is
                                                  --for leon3;
  constant hmidx_ahbjtag    : integer := hmidx_ahbuart + CFG_AHB_UART;
  constant hmidx_grspw2     : integer := hmidx_ahbjtag + CFG_AHB_JTAG;
  constant hmidx_grhssl     : integer := hmidx_grspw2  + CFG_SPW_EN*CFG_SPW_NUM;
  constant hmidx_grcan      : integer := hmidx_grhssl  + CFG_HSSL_EN*CFG_HSSL_NUM;
  constant hmidx_grcanfd    : integer := hmidx_grcan + CFG_GRCAN;
  constant maxahbm          : integer := hmidx_grcanfd + CFG_GRCANFD;-- total number of ahbm, latest hmidx + 1

  -- Slaves
  constant hsidx_dsu        : integer := CFG_NCPU;--CFG_NCPU - 1 (see hmidx_ahbuart)
  constant hsidx_apbctrl    : integer := hsidx_dsu + 1; -- missing an enable constant for apbctrl
  constant hsidx_spimctrl   : integer := hsidx_apbctrl + 1;
  constant hsidx_grhssl     : integer := hsidx_spimctrl + CFG_SPIMCTRL;
  constant hsidx_ahbram     : integer := hsidx_grhssl + CFG_HSSL_EN*CFG_HSSL_NUM;
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
  constant pidx_grgpio      : integer := pidx_ftahbram + CFG_FTAHBRAM_EN;
  constant pidx_ahbstat     : integer := pidx_grgpio + CFG_GRGPIO_ENABLE;
  constant pidx_grspw2      : integer := pidx_ahbstat + CFG_AHBSTAT;
  constant pidx_grcan       : integer := pidx_grspw2 + CFG_SPW_EN*CFG_SPW_NUM;
  constant pidx_grcanfd     : integer := pidx_grcan + CFG_GRCAN;
  constant pidx_grlsedc     : integer := pidx_grcanfd + CFG_GRCANFD;
  constant pidx_free        : integer := pidx_grlsedc + CFG_GRLSEDC;


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
  constant paddr_grspw2     : integer :=  paddr_ahbuart + CFG_AHB_UART*paddr_256byte; -- requires 256byte
  constant paddr_ftahbram   : integer :=  paddr_grspw2 + paddr_256byte*CFG_SPW_EN*CFG_SPW_NUM;-- requires 256byte
  constant paddr_grgpio     : integer :=  paddr_ftahbram + CFG_FTAHBRAM_EN*paddr_256byte; -- requires 256byte
  constant paddr_ahbstat     : integer :=  paddr_grgpio + CFG_GRGPIO_ENABLE*paddr_256byte; -- requires 256byte CFG_AHBSTAT
  constant paddr_grcan      : integer :=  (paddr_ahbstat/paddr_1kbyte + 1)*paddr_1kbyte;-- requires 1kbyte, CFG_GRGPIO_ENABLE doesn't matter as we need to go to the next 400 slot anyway
  constant paddr_grcanfd    : integer :=  (paddr_grcan/paddr_1kbyte + CFG_GRCAN)*paddr_1kbyte;-- requires 1kbyte
  constant paddr_grlsedc    : integer :=  paddr_grcanfd + CFG_GRCANFD*paddr_256byte; --- requires 256byte
  constant paddr_stat       : integer :=  (paddr_grlsedc/paddr_1kbyte + CFG_GRLSEDC)*paddr_1kbyte; -- requires 1kbyte
  --CFG_NCPU

  component GSR
    GENERIC (
      SYNCMODE : String := "ASYNC");
    PORT(
      GSR_N : IN std_logic;
      CLK : IN std_logic);
  end component;

  component DIFFCLKIO is
    generic (
      TERM_RD   : string := "ENABLED";
      WEAK_BIAS : string := "DISABLED");
    port (
      CLKIN0_P : in  std_logic;
      CLKIN0_N : in  std_logic;
      CLKIN1_P : in  std_logic;
      CLKIN1_N : in  std_logic;
      CLKOUT0  : out std_logic;
      CLKOUT1  : out std_logic
      );
  end component;

  component pll_125i_50o is
    port(
      clki_i   : in  std_logic;
      rstn_i   : in  std_logic;
      clkop_o  : out std_logic;
      clkos_o  : out std_logic;
      clkos2_o : out std_logic;
      lock_o   : out std_logic
      );
  end component;

  component hssl_serdes_x2 is
    port (
      use_refmux_i         : in  std_logic;
      diffioclksel_i       : in  std_logic;
      clksel_i             : in  std_logic_vector(1 downto 0);
      sdq_refclkp_q0_i     : in  std_logic;
      sdq_refclkn_q0_i     : in  std_logic;
      sdq_refclkp_q1_i     : in  std_logic;
      sdq_refclkn_q1_i     : in  std_logic;
      sd_ext_0_refclk_i    : in  std_logic;
      sd_ext_1_refclk_i    : in  std_logic;
      pll_0_refclk_i       : in  std_logic;
      pll_1_refclk_i       : in  std_logic;
      sd_pll_refclk_i      : in  std_logic;
      acjtag_mode_i        : in  std_logic;
      acjtag_enable_i_1    : in  std_logic;
      acjtag_enable_i_0    : in  std_logic;
      acjtag_acmode_i_1    : in  std_logic;
      acjtag_acmode_i_0    : in  std_logic;
      acjtag_drive1_i_1    : in  std_logic;
      acjtag_drive1_i_0    : in  std_logic;
      acjtag_highz_i_1     : in  std_logic;
      acjtag_highz_i_0     : in  std_logic;
      acjtagpout_o_1       : out std_logic;
      acjtagpout_o_0       : out std_logic;
      acjtagnout_o_1       : out std_logic;
      acjtagnout_o_0       : out std_logic;
      lmmi_clk_i_0         : in  std_logic;
      lmmi_resetn_i_0      : in  std_logic;
      lmmi_request_i_0     : in  std_logic;
      lmmi_wr_rdn_i_0      : in  std_logic;
      lmmi_offset_i_0      : in  std_logic_vector(8 downto 0);
      lmmi_wdata_i_0       : in  std_logic_vector(7 downto 0);
      lmmi_rdata_valid_o_0 : out std_logic;
      lmmi_ready_o_0       : out std_logic;
      lmmi_rdata_o_0       : out std_logic_vector(7 downto 0);
      lmmi_clk_i_1         : in  std_logic;
      lmmi_resetn_i_1      : in  std_logic;
      lmmi_request_i_1     : in  std_logic;
      lmmi_wr_rdn_i_1      : in  std_logic;
      lmmi_offset_i_1      : in  std_logic_vector(8 downto 0);
      lmmi_wdata_i_1       : in  std_logic_vector(7 downto 0);
      lmmi_rdata_valid_o_1 : out std_logic;
      lmmi_ready_o_1       : out std_logic;
      lmmi_rdata_o_1       : out std_logic_vector(7 downto 0);
      sd0rxp_i             : in  std_logic;
      sd0rxn_i             : in  std_logic;
      sd0txp_o             : out std_logic;
      sd0txn_o             : out std_logic;
      sd0_rext_i           : in  std_logic;
      sd0_refret_i         : in  std_logic;
      sd1rxp_i             : in  std_logic;
      sd1rxn_i             : in  std_logic;
      sd1txp_o             : out std_logic;
      sd1txn_o             : out std_logic;
      sd1_rext_i           : in  std_logic;
      sd1_refret_i         : in  std_logic;
      epcs_rx_usr_clk_i_1  : in  std_logic;
      epcs_rx_usr_clk_i_0  : in  std_logic;
      epcs_tx_usr_clk_i_1  : in  std_logic;
      epcs_tx_usr_clk_i_0  : in  std_logic;
      epcs_tx_pcs_rstn_i_1 : in  std_logic;
      epcs_tx_pcs_rstn_i_0 : in  std_logic;
      epcs_rx_pcs_rstn_i_1 : in  std_logic;
      epcs_rx_pcs_rstn_i_0 : in  std_logic;
      epcs_rstn_i_1        : in  std_logic;
      epcs_rstn_i_0        : in  std_logic;
      epcs_rxclk_o_1       : out std_logic;
      epcs_rxclk_o_0       : out std_logic;
      epcs_txclk_o_1       : out std_logic;
      epcs_txclk_o_0       : out std_logic;
      epcs_txdata_i_1      : in  std_logic_vector(79 downto 0);
      epcs_txdata_i_0      : in  std_logic_vector(79 downto 0);
      epcs_rxdata_o_1      : out std_logic_vector(79 downto 0);
      epcs_rxdata_o_0      : out std_logic_vector(79 downto 0);
      epcs_clkin_i_1       : in  std_logic;
      epcs_clkin_i_0       : in  std_logic;
      epcs_pwrdn_i_1       : in  std_logic_vector(1 downto 0);
      epcs_pwrdn_i_0       : in  std_logic_vector(1 downto 0);
      epcs_txhiz_i_1       : in  std_logic;
      epcs_txhiz_i_0       : in  std_logic;
      epcs_rxidle_o_1      : out std_logic;
      epcs_rxidle_o_0      : out std_logic;
      epcs_rxerr_i_1       : in  std_logic;
      epcs_rxerr_i_0       : in  std_logic;
      epcs_fomreq_i_1      : in  std_logic;
      epcs_fomreq_i_0      : in  std_logic;
      epcs_fomack_o_1      : out std_logic;
      epcs_fomack_o_0      : out std_logic;
      epcs_fomrslt_o_1     : out std_logic_vector(7 downto 0);
      epcs_fomrslt_o_0     : out std_logic_vector(7 downto 0);
      epcs_rate_i_1        : in  std_logic_vector(1 downto 0);
      epcs_rate_i_0        : in  std_logic_vector(1 downto 0);
      epcs_speed_o_1       : out std_logic_vector(1 downto 0);
      epcs_speed_o_0       : out std_logic_vector(1 downto 0);
      epcs_txval_i_1       : in  std_logic;
      epcs_txval_i_0       : in  std_logic;
      epcs_phyrdy_o_1      : out std_logic;
      epcs_phyrdy_o_0      : out std_logic;
      epcs_ready_o_1       : out std_logic;
      epcs_ready_o_0       : out std_logic;
      epcs_rxoob_i_1       : in  std_logic;
      epcs_rxoob_i_0       : in  std_logic;
      epcs_txdeemp_i_1     : in  std_logic;
      epcs_txdeemp_i_0     : in  std_logic;
      epcs_pwrst_o_1       : out std_logic_vector(1 downto 0);
      epcs_pwrst_o_0       : out std_logic_vector(1 downto 0);
      epcs_skipbit_i_1     : in  std_logic;
      epcs_skipbit_i_0     : in  std_logic;
      epcs_rxval_o_1       : out std_logic;
      epcs_rxval_o_0       : out std_logic
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

  reset_in <= gsrn;

  rst0 : gaisler.misc.rstgen generic map (acthigh => 0)
    port map (reset_in, clkm, lock, rstn, rstraw);
  lock <= cgo.clklock;

  --this instance is needed to provide the general reset in a lattice
  --simulation environment
  GSR_INST: GSR
    port map (GSR_N => reset_in,
              CLK => clkm);

  -- clock generator
  --FIXME
  --clkgen0 : clkgen
  --  generic map (fabtech, clock_mult, clock_div, 0, 0, 0, 0, 0, BOARD_FREQ, 0)
  --  port map (clk, gnd, clkm, open, open, open, open, cgi, cgo, open, open, open);

  clkgen_ip : pll_125i_50o
    port map(
      clki_i   => clk_in,
      rstn_i   => reset_in,
      clkop_o  => clkm,
      clkos_o  => clk100,
      clkos2_o => open,
      lock_o   => cgo.clklock
      );


----------------------------------------------------------------------
---  AHB CONTROLLER --------------------------------------------------
----------------------------------------------------------------------

  ahb0 : ahbctrl
    generic map (ioen => 1, nahbm => maxahbm, nahbs => maxahbs)
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
      generic map (hindex => hmidx_ahbuart, pindex => pidx_ahbuart, paddr => paddr_ahbuart)
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

  --AHBSTAT
  ahbs : if CFG_AHBSTAT = 1 generate -- AHB status register
    ahbstat0 : ahbstat generic map (pindex => pidx_ahbstat,
                                    paddr => paddr_ahbstat, pirq => 10,
                                    nftslv => CFG_AHBSTATN)
      port map (rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(pidx_ahbstat));
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
    ast_cerr: if CFG_AHBSTAT = 1 generate
      stati.cerror(0) <= aramo.ce;
    end generate;
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
    -- all pmod2 inout generate irq 6
    -- 0-7 PMOD2
    grgpio0: grgpio
      generic map(
        pindex    => pidx_grgpio, paddr => paddr_grgpio,
        nbits     => CFG_GRGPIO_WIDTH,
        imask     => CFG_GRGPIO_IMASK,
        pirq      => 7,
        irqgen    => 1,
        iflagreg  => 1
        )
      port map(rstn, clkm, apbi, apbo(pidx_grgpio), gpio0i, gpio0o);

    gpio_pmod_pads : iopadvv generic map (tech => padtech, width => 8)
      port map (pmod2, gpio0o.dout(7 downto 0), gpio0o.oen(7 downto 0), gpio0i.din(7 downto 0));

  end generate;


  ----------------------------------------------------------------------
  --- SpaceWire --------------------------------------------------------
  ----------------------------------------------------------------------
  -- rxclkin and nrxclki are unused
  spw_rxclkin <= '0';

  -- SpaceWire Transmitter clock should be clocked at 100 MHz
  spw_txclk <= clk100;

  no_spw : if CFG_SPW_EN = 0 generate

    spwloop : for i in 0 to CFG_SPW_NUM - 1 generate

      spwports : for j in 1 to CFG_SPW_PORTS generate

        spwr_txd_pad : outpad generic map (padtech)
          port map (spw_dout_p(i * CFG_SPW_PORTS + j), gnd);

        spwr_txs_pad : outpad generic map (padtech)
          port map (spw_sout_p(i * CFG_SPW_PORTS + j), gnd);

      end generate spwports;

    end generate spwloop;

  end generate;

  spw : if CFG_SPW_EN /= 0 generate

    spwloop : for i in 0 to CFG_SPW_NUM - 1 generate

      -- For self-clock implementations we reuse the strobe input,
      --otherwise we sample with the txclk
      spw_rxclkiv(i) <= stmp(i) when (CFG_SPW_INPUT /= 2 and
                                      CFG_SPW_INPUT /= 3 and
                                      CFG_SPW_INPUT /= 4)
                        else spw_txclk;

      -- GRSPW2 PHY
      spw2_input : if CFG_SPW_GRSPW = 2 generate

        spw_phy0 : grspw2_phy
          generic map (
            scantest     => 0,
            tech         => fabtech,
            input_type   => CFG_SPW_INPUT,
            rxclkbuftype => 1)
          port map (
            rstn      => rstn,
            rxclki    => spw_rxclkiv(i),                -- Receiver Clock Input
            rxclkin   => spw_rxclkin,
            nrxclki   => spw_rxclkin,
            di        => dtmp(i),       -- SpaceWire Data Input (from Pads)
            si        => stmp(i),       -- SpaceWire Strobe Input (from Pads)
            do        => spwi(i).d(1 downto 0),         -- Recovered Data
            dov       => spwi(i).dv(1 downto 0),        -- Data Valid
            dconnect  => spwi(i).dconnect(1 downto 0),  -- Disconnect
            dconnect2 => spwi(i).dconnect2(1 downto 0),
            dconnect3 => spwi(i).dconnect3(1 downto 0),
            rxclko    => spw_rxclk0(i)  -- Receiver Clock Output
            );

        spwi(i).nd <= (others => '0');  -- Only used in GRSPW

      end generate spw2_input;

      -- Single Port PHY
      singleportphy : if CFG_SPW_PORTS = 1 generate

        spwi(i).d(3 downto 2)         <= "00";  -- For second port
        spwi(i).dv(3 downto 2)        <= "00";  -- For second port
        spwi(i).dconnect(3 downto 2)  <= "00";  -- For second port
        spwi(i).dconnect2(3 downto 2) <= "00";  -- For second port
        spwi(i).dconnect3(3 downto 2) <= "00";  -- For second port
        spwi(i).s(1 downto 0)         <= "00";  -- Only used in PHY

      end generate singleportphy;

      -- Dual Port PHY
      dualportphy : if CFG_SPW_PORTS = 2 generate

        spw_rxclkiv(i * 2 + 1) <= stmp(i * 2 + 1) when (CFG_SPW_INPUT /= 2 and
                                                        CFG_SPW_INPUT /= 3 and
                                                        CFG_SPW_INPUT /= 4)
                                  else spw_txclk;

        spw_phy1 : grspw2_phy
          generic map (
            scantest     => 0,
            tech         => fabtech,
            input_type   => CFG_SPW_INPUT,
            rxclkbuftype => 1)
          port map (
            rstn      => rstn,
            rxclki    => spw_rxclkiv(i * 2 + 1),
            rxclkin   => spw_rxclkin,
            nrxclki   => spw_rxclkin,
            di        => dtmp(i * 2 + 1),
            si        => stmp(i * 2 + 1),
            do        => spwi(i).d(3 downto 2),
            dov       => spwi(i).dv(3 downto 2),
            dconnect  => spwi(i).dconnect(3 downto 2),
            dconnect2 => spwi(i).dconnect2(3 downto 2),
            dconnect3 => spwi(i).dconnect3(3 downto 2),
            rxclko    => spw_rxclk1(i)
            );

      end generate dualportphy;

      -- GRSPW Codec
      sw0 : grspwm
        generic map (
          tech           => fabtech,
          hindex         => hmidx_grspw2 + i,
          pindex         => pidx_grspw2 + i,
          paddr          => paddr_grspw2 + i,
          pirq           => 3 + i,
          sysfreq        => CPU_FREQ,
          nsync          => 1,
          rmap           => CFG_SPW_RMAP,
          rmapcrc        => CFG_SPW_RMAPCRC,
          fifosize1      => CFG_SPW_AHBFIFO,
          fifosize2      => CFG_SPW_RXFIFO,
          rxclkbuftype   => 1,
          memtech        => memtech,
          rmapbufs       => CFG_SPW_RMAPBUF,
          ft             => CFG_SPW_FT,
          ports          => CFG_SPW_PORTS,
          dmachan        => CFG_SPW_DMACHAN,
          netlist        => CFG_SPW_NETLIST,
          spwcore        => CFG_SPW_GRSPW,
          input_type     => CFG_SPW_INPUT,
          output_type    => CFG_SPW_OUTPUT,
          rxtx_sameclk   => CFG_SPW_RTSAME,
          rxunaligned    => CFG_SPW_RXUNAL,
          internalrstgen => 1)
        port map (
          rst        => rstn,
          clk        => clkm,
          rxasyncrst => gnd,
          rxsyncrst0 => gnd,
          rxclk0     => spw_rxclk0(i),  -- Receiver Clock for Port 0
          rxsyncrst1 => gnd,
          rxclk1     => spw_rxclk1(i),  -- Receiver Clock for Port 1
          txsyncrst  => gnd,
          txclk      => spw_txclk,      -- Transmitter default run-state clock
          txclkn     => spw_txclk,  -- Transmitter inverted default run-state clock
          ahbmi      => ahbmi,
          ahbmo      => ahbmo(hmidx_grspw2 + i),
          apbi       => apbi,
          apbo       => apbo(pidx_grspw2 + i),
          swni       => spwi(i),        -- SpaceWire Input
          swno       => spwo(i)         -- SpaceWire Output
          );

      spwi(i).tickin       <= '0';
      spwi(i).rmapen       <= '0';
      spwi(i).clkdiv10     <= conv_std_logic_vector(CPU_FREQ / 10000 - 1, 8);
      spwi(i).dcrstval     <= (others => '0');
      spwi(i).timerrstval  <= (others => '0');
      spwi(i).pnpusn       <= (others => '0');
      spwi(i).pnpuprodid   <= (others => '0');
      spwi(i).pnpuvendid   <= (others => '0');
      spwi(i).pnpen        <= '0';
      spwi(i).irqtxdefault <= (others => '0');
      spwi(i).intcreload   <= (others => '0');
      spwi(i).intiareload  <= (others => '0');
      spwi(i).intpreload   <= (others => '0');
      spwi(i).rmapnodeaddr <= (others => '0');
      spwi(i).timein       <= (others => '0');
      spwi(i).tickinraw    <= '0';

       -- SpaceWire Pads
      -- Outputs
      spw_txd_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_dout_p(i * CFG_SPW_PORTS + 1), spwo(i).d(0));

      spw_txs_pad : outpad generic map (padtech, lvds, x33v)
        port map (spw_sout_p(i * CFG_SPW_PORTS + 1), spwo(i).s(0));

      -- Inputs
      spwr_rxd_pad : inpad generic map (tech => padtech)
        port map (spw_din_p(i * CFG_SPW_PORTS + 1),
                  dtmp(i * CFG_SPW_PORTS));

      spwr_rxs_pad : inpad generic map (tech => padtech)
        port map (spw_sin_p(i * CFG_SPW_PORTS + 1),
                  stmp(i * CFG_SPW_PORTS));

      -- In case of dual port
      dualport : if CFG_SPW_PORTS = 2 generate
        -- Outputs
        spwr_txd_pad : outpad generic map (tech => padtech)
          port map (spw_dout_p(i * CFG_SPW_PORTS + 2), spwo(i).d(1));

        spwr_txs_pad : outpad generic map (tech => padtech)
          port map (spw_sout_p(i * CFG_SPW_PORTS + 2), spwo(i).s(1));

        -- Inputs
        spwr_rxd_pad : inpad generic map (tech => padtech)
          port map (spw_din_p(i * CFG_SPW_PORTS + 2),
                    dtmp(i * CFG_SPW_PORTS + 1));

        spwr_rxs_pad : inpad generic map (tech => padtech)
          port map (spw_sin_p(i * CFG_SPW_PORTS + 2),
                    stmp(i * CFG_SPW_PORTS + 1));

      end generate dualport;

    end generate spwloop;

  end generate spw;


  ----------------------------------------------------------------------
  --- High Speed Serial Link -------------------------------------------
  ----------------------------------------------------------------------

  hssl0 : if CFG_HSSL_EN /= 0 generate

    hssl_loop : for i in 0 to CFG_HSSL_NUM-1 generate

      -- SpaceFibre codec
      spfi_i : grspfi_ahb
        generic map (
          tech               => memtech,
          hmindex            => hmidx_grhssl+i,
          hsindex            => hsidx_grhssl+i,
          haddr              => 16#100# + i*16#010#,
          hmask              => 16#FF0#,
          hirq               => 5 + i,
          use_8b10b          => 1,
          use_sep_txclk      => 0,
          sel_16_20_bit_mode => 0,
          ticks_2us          => 125,
          tx_skip_freq       => 5000,
          prbs_init1         => 1,
          depth_rbuf_data    => 8,
          depth_rbuf_fct     => 4,
          depth_rbuf_bc      => 4,
          num_vc             => 2,
          fct_multiplier     => 1,
          depth_vc_rx_buf    => 10,
          depth_vc_tx_buf    => 10,
          remote_fct_cnt_max => 9,
          width_bw_credit    => 20,
          min_bw_credit      => 52428,
          idle_time_limit    => 62500,
          num_dmach          => 1,
          num_txdesc         => 256,
          num_rxdesc         => 512,
          depth_dma_fifo     => 32,
          depth_bc_fifo      => 4,
          use_async_rxrst    => 1)
        port map (
          clk        => clkm,
          rstn       => rstn,
          spfi_clk   => hssl_clk,
          spfi_rstn  => hssl_rstn,
          spfi_txclk => '0', -- unused (40-bit SerDes interface)
          -- AHB interface
          ahbmi      => ahbmi_vct,
          ahbmo      => ahbmo(hmidx_grhssl+i downto hmidx_grhssl+i),
          ahbsi      => ahbsi,
          ahbso      => ahbso(hsidx_grhssl+i),
          -- Serdes interface
          spfii      => hssli(i),
          spfio      => hsslo(i)
          );

      -- Connection between SpaceFibre and the SerDes

      hssli(i).rx_clk    <= epcs(i).rxclk;
      hssli(i).rx_data   <= epcs(i).rxdata(39 downto 0);
      hssli(i).rx_kflags <= (others => '0');  -- Unused (8b10b encoding in the IP)
      hssli(i).rx_serror <= (others => '0');  -- Unused
      hssli(i).no_signal <= not (epcs(i).ready and epcs(i).rxval);

      epcs(i).txdata <= zero128(79 downto 40) & hsslo(i).tx_data;
      epcs(i).txval  <= epcs(i).ready;

    end generate hssl_loop;

    ahbmi_vct(0) <= ahbmi;

    -- EPCS 0 is used as the master channel to drive the HSSL TX clock
    hssl_clk  <= epcs(0).txclk;
    hssl_lock <= epcs(0).phyrdy;

    -- GRHSSL reset generator
    rst_hssl : gaisler.misc.rstgen generic map (acthigh => 0)
      port map (reset_in, hssl_clk, hssl_lock, hssl_rstn, open);

  end generate hssl0;

  -- The SerDes is always instantiated to avoid errors while parsing the physical constraints

  -- SerDes external reference clock
  refclk : DIFFCLKIO
    port map (
      CLKIN0_P => gbtclk0_p,
      CLKIN0_N => gbtclk0_n,
      CLKIN1_P => '0',
      CLKIN1_N => '1',
      CLKOUT0  => sd_ext_0_refclk,
      CLKOUT1  => sd_ext_1_refclk
      );

  -- CertusPro SerDes
  hssl_serdes0 : hssl_serdes_x2
    port map(
      use_refmux_i         => '1',    -- select the clock from the mux
      diffioclksel_i       => '0',    -- select sd_ext_0_refclk
      clksel_i             => "10",   -- select external reference clock (output from DIFFCLKIO)
      sdq_refclkp_q0_i     => '0',
      sdq_refclkn_q0_i     => '1',
      sdq_refclkp_q1_i     => '0',
      sdq_refclkn_q1_i     => '1',
      sd_ext_0_refclk_i    => sd_ext_0_refclk,
      sd_ext_1_refclk_i    => sd_ext_1_refclk,
      pll_0_refclk_i       => '0',
      pll_1_refclk_i       => '0',
      sd_pll_refclk_i      => '0',
      acjtag_mode_i        => '0',  -- ACJTAG controller not used and kept in reset
      acjtag_enable_i_1    => '0',
      acjtag_enable_i_0    => '0',
      acjtag_acmode_i_1    => '0',
      acjtag_acmode_i_0    => '0',
      acjtag_drive1_i_1    => '0',
      acjtag_drive1_i_0    => '0',
      acjtag_highz_i_1     => '0',
      acjtag_highz_i_0     => '0',
      acjtagpout_o_1       => open,
      acjtagpout_o_0       => open,
      acjtagnout_o_1       => open,
      acjtagnout_o_0       => open,
      lmmi_clk_i_0         => '0',  -- register interface not used (static configuration)
      lmmi_resetn_i_0      => '0',  -- register interface kept in reset
      lmmi_request_i_0     => '0',
      lmmi_wr_rdn_i_0      => '0',
      lmmi_offset_i_0      => (others => '0'),
      lmmi_wdata_i_0       => (others => '0'),
      lmmi_rdata_valid_o_0 => open,
      lmmi_ready_o_0       => open,
      lmmi_rdata_o_0       => open,
      lmmi_clk_i_1         => '0',  -- register interface not used (static configuration)
      lmmi_resetn_i_1      => '0',  -- register interface kept in reset
      lmmi_request_i_1     => '0',
      lmmi_wr_rdn_i_1      => '0',
      lmmi_offset_i_1      => (others => '0'),
      lmmi_wdata_i_1       => (others => '0'),
      lmmi_rdata_valid_o_1 => open,
      lmmi_ready_o_1       => open,
      lmmi_rdata_o_1       => open,
      sd0rxp_i             => hssl_rxp(0),
      sd0rxn_i             => hssl_rxn(0),
      sd0txp_o             => hssl_txp(0),
      sd0txn_o             => hssl_txn(0),
      sd0_rext_i           => '0',
      sd0_refret_i         => '0',
      sd1rxp_i             => hssl_rxp(1),
      sd1rxn_i             => hssl_rxn(1),
      sd1txp_o             => hssl_txp(1),
      sd1txn_o             => hssl_txn(1),
      sd1_rext_i           => '0',
      sd1_refret_i         => '0',
      epcs_rx_usr_clk_i_1  => epcs(1).rxclk,
      epcs_rx_usr_clk_i_0  => epcs(0).rxclk,
      epcs_tx_usr_clk_i_1  => hssl_clk,
      epcs_tx_usr_clk_i_0  => hssl_clk,
      epcs_tx_pcs_rstn_i_1 => rstn,
      epcs_tx_pcs_rstn_i_0 => rstn,
      epcs_rx_pcs_rstn_i_1 => rstn,
      epcs_rx_pcs_rstn_i_0 => rstn,
      epcs_rstn_i_1        => rstn,
      epcs_rstn_i_0        => rstn,
      epcs_rxclk_o_1       => epcs(1).rxclk,
      epcs_rxclk_o_0       => epcs(0).rxclk,
      epcs_txclk_o_1       => epcs(1).txclk,
      epcs_txclk_o_0       => epcs(0).txclk,
      epcs_txdata_i_1      => epcs(1).txdata,
      epcs_txdata_i_0      => epcs(0).txdata,
      epcs_rxdata_o_1      => epcs(1).rxdata,
      epcs_rxdata_o_0      => epcs(0).rxdata,
      epcs_clkin_i_1       => clk_in, -- Slow speed clock (100-300 MHz) to drive the calibration
      epcs_clkin_i_0       => clk_in, -- Slow speed clock (100-300 MHz) to drive the calibration
      epcs_pwrdn_i_1       => "00", -- Powerdown never enabled
      epcs_pwrdn_i_0       => "00", -- Powerdown never enabled
      epcs_txhiz_i_1       => '0',
      epcs_txhiz_i_0       => '0',
      epcs_rxidle_o_1      => open,
      epcs_rxidle_o_0      => open,
      epcs_rxerr_i_1       => '0',
      epcs_rxerr_i_0       => '0',
      epcs_fomreq_i_1      => '0',
      epcs_fomreq_i_0      => '0',
      epcs_fomack_o_1      => open,
      epcs_fomack_o_0      => open,
      epcs_fomrslt_o_1     => open,
      epcs_fomrslt_o_0     => open,
      epcs_rate_i_1        => "00", -- Fixed rate
      epcs_rate_i_0        => "00", -- Fixed rate
      epcs_speed_o_1       => open,
      epcs_speed_o_0       => open,
      epcs_txval_i_1       => epcs(1).txval,
      epcs_txval_i_0       => epcs(0).txval,
      epcs_phyrdy_o_1      => epcs(1).phyrdy,
      epcs_phyrdy_o_0      => epcs(0).phyrdy,
      epcs_ready_o_1       => epcs(1).ready,
      epcs_ready_o_0       => epcs(0).ready,
      epcs_rxoob_i_1       => '0',
      epcs_rxoob_i_0       => '0',
      epcs_txdeemp_i_1     => '0',
      epcs_txdeemp_i_0     => '0',
      epcs_pwrst_o_1       => open,
      epcs_pwrst_o_0       => open,
      epcs_skipbit_i_1     => '0',
      epcs_skipbit_i_0     => '0',
      epcs_rxval_o_1       => epcs(1).rxval,
      epcs_rxval_o_0       => epcs(0).rxval
      );


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


  -----------------------------------------------------------------------------
  -- GRCANFD instantiation
  -----------------------------------------------------------------------------
  grcanfdgen : if CFG_GRCANFD = 1 generate
    canfd_dut : grcanfd_ahb
      generic map(
        tech           => memtech,
        hindex         => hmidx_grcanfd,
        pindex         => pidx_grcanfd,
        paddr          => paddr_grcanfd,
        pmask          => 16#FFC#,
        pirq           => 1,
        singleirq      => 1,
        txbufsize      => 2,
        rxbufsize      => 2,
        canopen        => 0,
        sepbus         => 0,
        hindexcopen    => 0)
      port map(
        clk            => clkm,
        rstn           => rstn,
        ahbmi          => ahbmi_canfd,
        ahbmo          => ahbmo_canfd,
        apbi           => apbi,
        apbo           => apbo(pidx_grcanfd),
        cani           => canfdi,
        cano           => canfdo,
        cfg            => GRCANFD_CFG_NULL
        );

    ahbmi_canfd(0) <= ahbmi;
    ahbmo(hmidx_grcanfd)       <= ahbmo_canfd(0);
  end generate;

  ----------------------------------------------------
  -- GRLSEDC instantiation
  ----------------------------------------------------
  grlsedcgen: if CFG_GRLSEDC = 1 generate
    grlsedc0: grlsedc
      generic map(
        pindex => pidx_grlsedc,
        paddr  => paddr_grlsedc,
        pmask  => 16#FFF#)
      port map(
        clk      => clkm,
        rstn     => rstn,
        ext_rstn => ext_rstn,
        apbi     => apbi,
        apbo     => apbo(pidx_grlsedc),
        cram_ue  => cram_ue);
  end generate;

  nogrcanfdgen1 : if CFG_GRCANFD = 0 generate
    canfdo <= (tx => "11", en => "00");
    ahbmo_canfd(0) <= ahbm_none;
  end generate;

  -- GRCANFD pads
  canfdtx0_pad : outpad
    generic map (tech => padtech) port map (canfd_tx, canfdo.tx(0));
  canfdrx0_pad : inpad
    generic map (tech => padtech) port map (canfd_rx, canfdi.rx(0));
  canfden0_pad : outpad
    generic map (tech => padtech) port map (canfd_en, gnd);
  -- we don't connect the second canfd from the component as we want to
  -- include also a plain can ip with the CAN-FD-FMC-PCB board


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
