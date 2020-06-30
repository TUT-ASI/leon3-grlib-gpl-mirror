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
use grlib.config.all;
use grlib.config_types.all;

library techmap;
use techmap.gencomp.all;

library gaisler;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.axi.all;
use gaisler.plic.all;
use gaisler.riscv.all;
use gaisler.l2cache.all;
use gaisler.noelv.all;

--pragma translate_off
use gaisler.sim.all;
--pragma translate_on

use work.config.all;

entity noelvmp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;     -- Enable disassembly to console
    USE_MIG_INTERFACE_MODEL : boolean := false
    );
  port (
    CLK100MHZ          : in    std_ulogic;
    -- LEDs. 0: off, 1: on
    led                : out   std_logic_vector(3 downto 0);
    -- Buttons 0: not pressed, 1: pressed
    btn                : in    std_logic_vector(3 downto 0);
    -- Switches
    sw                 : in    std_logic_vector(3 downto 0);
    -- USB-RS232 interface
    uart_txd_in        : in    std_ulogic;
    uart_rxd_out       : out   std_ulogic;
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

architecture rtl of noelvmp is
  constant ramfile      : string := "ram.srec"; -- ram contents
  -- Misc
  signal vcc            : std_ulogic;
  signal gnd            : std_ulogic;
  signal stati          : ahbstat_in_type;
  signal dsu_sel        : std_ulogic;

  -- APB
  signal apbi           : apb_slv_in_vector;
  signal apbo           : apb_slv_out_vector := (others => apb_none);

  -- AHB
  signal ahbsi          : ahb_slv_in_type;
  signal ahbso          : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi          : ahb_mst_in_type;
  signal ahbmo          : ahb_mst_out_vector := (others => ahbm_none);

  signal u1i, dui : uart_in_type;
  signal u1o, duo : uart_out_type;

  signal ethi : eth_in_type;
  signal etho : eth_out_type;

  -- GPIOs
  signal gpioi          : gpio_in_type;
  signal gpioo          : gpio_out_type;

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
  signal mmcm_locked        : std_ulogic;

  signal rxd1 : std_logic;
  signal txd1 : std_logic;

  signal swint  : std_logic_vector(sw'range);

  attribute keep                     : boolean;
  attribute syn_keep                 : boolean;
  attribute syn_preserve             : boolean;
  attribute syn_keep of lock         : signal is true;
  attribute syn_keep of clkm         : signal is true;
  attribute syn_preserve of clkm     : signal is true;
  attribute keep of lock             : signal is true;
  attribute keep of clkm             : signal is true;

  constant BOARD_FREQ : integer := 100000;                                -- CLK input frequency in KHz

  -- cpu frequency in KHz
  function CPU_FREQ return integer is
  begin
    if CFG_MIG_7SERIES = 1 then
      return BOARD_FREQ * 10 / 6 / 2;
    end if;
    return BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;
  end;

  -------------------------------------
  signal ui_clk         : std_ulogic;

  -- Memory
  signal mem_aximi      : axi_somi_type;
  signal mem_aximo      : axi_mosi_type;
  signal axi3_aximo     : axi3_mosi_type;

  signal dsurx_int      : std_ulogic; 
  signal dsutx_int      : std_ulogic; 
  signal dsuctsn_int    : std_ulogic;
  signal dsurtsn_int    : std_ulogic;

  constant ncpu     : integer := 1;
  constant nextslv  : integer := 3
-- pragma translate_off
  + 1
-- pragma translate_on
  ;
  constant ndbgmst  : integer := 3
  ;
  signal ldsuen     : std_logic;
  signal ldsubreak  : std_logic;
  signal lcpu0errn  : std_logic;
  signal dbgmi      : ahb_mst_in_vector_type(ndbgmst-1 downto 0);
  signal dbgmo      : ahb_mst_out_vector_type(ndbgmst-1 downto 0);


  constant mig_hindex : integer := 2
-- pragma translate_off
  + 1
-- pragma translate_on
  ;

  constant mig_hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
    4 => ahb_membar(16#400#, '1', '1', 16#C00#),
    others => zero32);

begin

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------
  vcc         <= '1';
  gnd         <= '0';

  rst_pad : inpad generic map (tech => padtech)
    port map (btn(0), reset_button);

  rst0 : rstgen
    generic map(acthigh => 1)
    port map (reset_button, clkm, lock, rstn, rstnraw);
  
  lock <= calib_done and pll_locked;

  rst1 : rstgen
    generic map(acthigh => 1)
    port map (reset_button, clkm, '1', migrstn, open);

  --led(1) <= calib_done;
  --led(0) <= lock;

  clockers0 : entity work.clockers_mig
  port map (
    rstn        => rstnraw,
    clkin       => CLK100MHZ,
    mig_clkref  => clkref,
    mig_clk     => clkinmig,
    eth_ref     => eth_ref_clki,
    clkm        => clkm,
    locked      => pll_locked
  );

  ----------------------------------------------------------------------
  ---  NOEL-V SUBSYSTEM ------------------------------------------------
  ----------------------------------------------------------------------

  noelv0 : noelvsys 
    generic map (
      fabtech   => fabtech,
      memtech   => memtech,
      ncpu      => ncpu,
      nextmst   => 1,--2,
      nextslv   => nextslv,
      nextapb   => 5,
      ndbgmst   => ndbgmst,
      cached    => 0,
      wbmask    => 16#40FF#,
      busw      => 128,
      cmemconf  => 0,
      fpuconf   => 0,
      disas     => disas,
      ahbtrace  => 0,
      cfg       => CFG_CFG,
      devid     => NOELV_XILINX_KCU105,
      version   => 3,
      revision  => 0,
      nodbus    => CFG_NODBUS
      )
    port map(
      clk       => clkm,
      rstn      => rstn,
      -- AHB bus interface for other masters (DMA units)
      ahbmi     => ahbmi,                     -- : out ahb_mst_in_type;
      ahbmo     => ahbmo(ncpu downto ncpu),   -- : in  ahb_mst_out_vector_type(ncpu+nextmst-1 downto ncpu);
      -- AHB bus interface for slaves (memory controllers, etc)
      ahbsi     => ahbsi,                     -- : out ahb_slv_in_type;
      ahbso     => ahbso(nextslv-1 downto 0), -- : in  ahb_slv_out_vector_type(nextslv-1 downto 0);
      -- AHB master interface for debug links
      dbgmi     => dbgmi,                     -- : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
      dbgmo     => dbgmo,                     -- : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
      -- APB interface for external APB slaves
      apbi      => apbi,                      -- : out apb_slv_in_type;
      apbo      => apbo,                      -- : in  apb_slv_out_vector;
      -- Bootstrap signals
      dsuen     => ldsuen,
      dsubreak  => ldsubreak,
      cpu0errn  => lcpu0errn,
      -- UART connection
      uarti     => u1i,
      uarto     => u1o
      );

  --errorn_pad : odpad
  --  generic map (tech => padtech, oepol => OEPOL)
  --  port map (errorn, lcpu0errn);

  --dsuen_pad : inpad
  --  generic map (tech => padtech, level => cmos, voltage => x12v)
  --  port map (switch(2), ldsuen);
  ldsuen <= '1';

  -- Button 2,3,4 are still to be assigned
  --dsubre_pad : inpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (button(4), ldsubreak);
  ldsubreak <= '0';

  --ndreset_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(4), dsuo.ndmreset);

  --dmactive_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(5), dsuo.dmactive);

  -----------------------------------------------------------------------------
  -- Debug UART ---------------------------------------------------------------
  -----------------------------------------------------------------------------
  
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map(
        hindex => 0,
        pindex => 1,
        paddr => 14)
      port map(
        rstn,
        clkm,
        dui,
        duo,
        apbi(1),
        apbo(1),
        dbgmi(0),
        dbgmo(0));
    dui.extclk <= '0';
  end generate;

  nouah : if CFG_AHB_UART = 0 generate
    apbo(1)    <= apb_none;
    duo.txd    <= '0';
    duo.rtsn   <= '0';
    dui.extclk <= '0';
  end generate;

  sw4_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x12v)
    port map (sw(3), dsu_sel);

  dsutx_int     <= duo.txd when dsu_sel = '1' else u1o.txd;
  dui.rxd       <= dsurx_int when dsu_sel = '1' else '1';
  dsurtsn_int   <= duo.rtsn when dsu_sel = '1' else u1o.rtsn;  
  dui.ctsn      <= dsuctsn_int when dsu_sel = '1' else '1';
  u1i.rxd       <= dsurx_int when dsu_sel = '0' else '1';
  u1i.ctsn      <= dsuctsn_int when dsu_sel = '0' else '1';
  
  dsurx_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (uart_txd_in, dsurx_int);
  dsutx_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (uart_rxd_out, dsutx_int);
  --dsuctsn_pad : inpad
  --  generic map (level => cmos, voltage => x18v, tech => padtech)
  --  port map (dsuctsn, dsuctsn_int);
  --dsurtsn_pad : outpad
  --  generic map (level => cmos, voltage => x18v, tech => padtech)
  --  port map (dsurtsn, dsurtsn_int);

  --dsusel_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(4), dsu_sel);

  -----------------------------------------------------------------------------
  -- JTAG debug link ----------------------------------------------------------
  -----------------------------------------------------------------------------
  
  ahbjtaggen0 : if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag
      generic map(tech => fabtech, hindex => 1)
      port map(rstn, clkm, tck, tms, tdi, tdo, dbgmi(1), dbgmo(1),
               open, open, open, open, open, open, open, gnd);
  end generate;


  -----------------------------------------------------------------------------
  -- DDR4 Memory Controller (MIG) ---------------------------------------------
  -----------------------------------------------------------------------------
  -- No APB interface on memory controller  
  apbo(0)    <= apb_none;

  mig_gen : if (CFG_MIG_7SERIES = 1) generate

    gen_ddr3c : if (USE_MIG_INTERFACE_MODEL = false) generate
      gen_l2c : if CFG_L2_EN /= 0 generate
        l2c0 : l2c_axi_be
          generic map (
            hslvidx   => 0,
            axiid     => 0,
            cen       => CFG_L2_PEN,
            haddr     => 16#400#,
            hmask     => 16#c00#,
            ioaddr    => 16#FF0#,
            cached    => CFG_L2_MAP,
            repl      => CFG_L2_RAN,
            ways      => CFG_L2_WAYS, 
            linesize  => CFG_L2_LSZ,
            waysize   => CFG_L2_SIZE,
            memtech   => memtech,
            sbus      => 0,
            mbus      => 0,
            arch      => CFG_L2_SHARE,
            ft        => CFG_L2_EDAC,
            stat      => 2)
          port map(
            rst   => rstn,
            clk   => clkm,
            ahbsi => ahbsi,
            ahbso => ahbso(0),
            aximi => mem_aximi,
            aximo => mem_aximo,
            sto   => open);
      end generate;
      nogen_l2c : if CFG_L2_EN = 0 generate
        bridge: ahb2axi3b
          generic map (
            hindex          => 0,
            aximid          => 0,
            wbuffer_num     => 8,
            rprefetch_num   => 8,
            endianness_mode => 0,
            narrow_acc_mode => 0,
            vendor          => VENDOR_GAISLER,
            device          => GAISLER_MIG_7SERIES,
            bar0            => ahb2ahb_membar(16#400#, '1', '1', 16#c00#)
            )
          port map (
            rstn  => rstn,
            clk   => clkm,
            ahbsi => ahbsi,
            ahbso => ahbso(0),
            aximi => mem_aximi,
            aximo => axi3_aximo);
            
            mem_aximo.aw.id     <= axi3_aximo.aw.id;
            mem_aximo.aw.addr   <= axi3_aximo.aw.addr;
            mem_aximo.aw.len    <= axi3_aximo.aw.len;
            mem_aximo.aw.size   <= axi3_aximo.aw.size;
            mem_aximo.aw.burst  <= axi3_aximo.aw.burst;
            mem_aximo.aw.lock   <= axi3_aximo.aw.lock;
            mem_aximo.aw.cache  <= axi3_aximo.aw.cache;
            mem_aximo.aw.prot   <= axi3_aximo.aw.prot;
            mem_aximo.aw.valid  <= axi3_aximo.aw.valid;
            mem_aximo.w         <= axi3_aximo.w;
            mem_aximo.b         <= axi3_aximo.b;
            mem_aximo.ar.id     <= axi3_aximo.ar.id;
            mem_aximo.ar.addr   <= axi3_aximo.ar.addr;
            mem_aximo.ar.len    <= axi3_aximo.ar.len;
            mem_aximo.ar.size   <= axi3_aximo.ar.size;
            mem_aximo.ar.burst  <= axi3_aximo.ar.burst;
            mem_aximo.ar.lock   <= axi3_aximo.ar.lock;
            mem_aximo.ar.cache  <= axi3_aximo.ar.cache;
            mem_aximo.ar.prot   <= axi3_aximo.ar.prot;
            mem_aximo.ar.valid  <= axi3_aximo.ar.valid;
            mem_aximo.r         <= axi3_aximo.r;
      end generate;

      ddr3c: entity work.axi_mig3_7series
        port map (
          ddr3_addr       => ddr3_addr,
          ddr3_we_n       => ddr3_we_n,
          ddr3_cas_n      => ddr3_cas_n,
          ddr3_ras_n      => ddr3_ras_n,
          ddr3_ba         => ddr3_ba,
          ddr3_cke        => ddr3_cke,
          ddr3_cs_n       => ddr3_cs_n,
          ddr3_dm         => ddr3_dm,
          ddr3_dq         => ddr3_dq,
          ddr3_dqs_p      => ddr3_dqs_p,
          ddr3_dqs_n      => ddr3_dqs_n,
          ddr3_odt        => ddr3_odt,
          ddr3_reset_n    => ddr3_reset_n,
          ddr3_ck_p       => ddr3_ck_p,
          ddr3_ck_n       => ddr3_ck_n,
          --
          ui_clk          => ui_clk,
          ui_clk_sync_rst => open,
          --
          aximi           => mem_aximi,
          aximo           => mem_aximo,
          --
          calib_done      => calib_done,
          mmcm_locked     => mmcm_locked,
          sys_clk_i       => clkinmig,
          clk_ref_i       => clkref,
          rst_n_syn       => migrstn,
          rst_n_async     => rstnraw,
          amba_clk        => clkm
          );
    end generate gen_ddr3c;

    gen_mig_model : if (USE_MIG_INTERFACE_MODEL = true) generate
      -- pragma translate_off
      mig_ahbram : ahbram_sim
        generic map (
          hindex   => 0,
          haddr    => 16#400#,
          hmask    => 16#C00#,
          tech     => 0,
          kbytes   => 1000,
          pipe     => 0,
          maccsz   => AHBDW,
          endianness  => GRLIB_CONFIG_ARRAY(grlib_little_endian),
          fname    => ramfile
          )
        port map(
          rst     => rstn,
          clk     => clkm,
          ahbsi   => ahbsi,
          ahbso   => ahbso(0)
          );

      -- Tie-Off DDR4 Signals
      ddr3_addr       <= (others => '0');
      ddr3_we_n       <= '0';
      ddr3_cas_n      <= '0';
      ddr3_ras_n      <= '0';
      ddr3_ba         <= (others => '0');
      ddr3_cke        <= (others => '0');
      ddr3_cs_n       <= (others => '0');
      ddr3_dm         <= (others => 'Z');
      ddr3_dq         <= (others => 'Z');
      ddr3_dqs_p      <= (others => 'Z');
      ddr3_dqs_n      <= (others => 'Z');
      ddr3_odt        <= (others => '0');
      ddr3_reset_n    <= '1';
      ddr3_ck_p       <= (others => '0');
      ddr3_ck_n       <= (others => '0');
      
      calib_done  <= '1';
      mmcm_locked <= '1';
      
      --clkm <= not clkm after 5.0 ns;
    -- pragma translate_on
    end generate gen_mig_model;
    
  end generate mig_gen;

  no_mig_gen : if (CFG_MIG_7SERIES = 0) generate  

    ahbram1 : ahbram 
      generic map (
        hindex      => 0,
        haddr       => 16#400#,
        tech        => CFG_MEMTECH,
        kbytes      => 1024,
        endianness  => GRLIB_CONFIG_ARRAY(grlib_little_endian))
      port map (
        rstn,
        clkm,
        ahbsi,
        ahbso(0));

    -- Tie-Off DDR4 Signals
    ddr3_addr       <= (others => '0');
    ddr3_we_n       <= '0';
    ddr3_cas_n      <= '0';
    ddr3_ras_n      <= '0';
    ddr3_ba         <= (others => '0');
    ddr3_cke        <= (others => '0');
    ddr3_cs_n       <= (others => '0');
    ddr3_dm         <= (others => 'Z');
    ddr3_dq         <= (others => 'Z');
    ddr3_dqs_p      <= (others => 'Z');
    ddr3_dqs_n      <= (others => 'Z');
    ddr3_odt        <= (others => '0');
    ddr3_reset_n    <= '1';
    ddr3_ck_p       <= (others => '0');
    ddr3_ck_n       <= (others => '0');
    
    calib_done  <= '1';
    mmcm_locked <= '1';

    ddr3_ck_outpad : outpad_ds
      generic map (tech => padtech, level => sstl12_dci, voltage => x12v)
      port map (ddr3_ck_n(0), ddr3_ck_p(0), gnd, gnd);
  end generate no_mig_gen;

  -----------------------------------------------------------------------
  ---  AHB ROM ----------------------------------------------------------
  -----------------------------------------------------------------------

  brom : entity work.ahbrom
    generic map (
      hindex  => 1,
      haddr   => 16#000#,
      pipe    => 0)
    port map (
      rst     => rstn,
      clk     => clkm,
      ahbsi   => ahbsi,
      ahbso   => ahbso(1));

  ----------------------------------------------------------------------
  --- APB Bridge and various periherals --------------------------------
  ----------------------------------------------------------------------

  --  AHB Status Register
  ahbs : if CFG_AHBSTAT = 1 generate  
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat
      generic map(pindex  => 2,
                  paddr   => 15,
                  pirq    => 4,
                  nftslv  => CFG_AHBSTATN)
      port map(
        rstn,
        clkm,
        ahbmi,
        ahbsi,
        stati,
        apbi(2),
        apbo(2));
  end generate;

  -- GPIO units
  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate

    grgpio_ledsw : grgpio
      generic map(
        pindex => 3,
        paddr => 4,
        imask => CFG_GRGPIO_IMASK,
        nbits => CFG_GRGPIO_WIDTH)
      port map(
        rst   => rstn,
        clk   => clkm,
        apbi  => apbi(3),
        apbo  => apbo(3),
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
        port map (sw(i), gpioi.din(i));
    end generate gpsw_pads;
    gpioi.din(3) <= dsu_sel;

    gpb_pads : for i in 1 to 3 generate
      gpb_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (btn(i), gpioi.din(i+4));
    end generate gpb_pads;

    --pio_pads : for i in 0 to 7 generate
    --  gpio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x12v, strength => 8)
    --    port map (gpio(i), gpioo.dout(i+8), gpioo.oen(i+8), gpioi.din(i+8));
    --end generate;

  end generate;

-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

  eth0 : if CFG_GRETH /= 0 generate -- Gaisler ethernet MAC

  pci_p_clk5_r_pad : outpad generic map (tech => padtech)
    port map (eth_ref_clk, eth_ref_clki);

    e1 : grethm_mb
      generic map(hindex => ncpu, ehindex => 2,
                  pindex => 4, paddr => 5, pirq => 5, memtech => memtech,
                  mdcscaler => CPU_FREQ/1000, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
                  nsync => 2, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF,
                  macaddrh => CFG_ETH_ENM, macaddrl => CFG_ETH_ENL, phyrstadr => 1,
                  ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_ETH_IPL, giga => CFG_GRETH1G,
                  edclsepahb => 1)
      port map(rst => rstn, clk => clkm,
               ahbmi => ahbmi, ahbmo => ahbmo(ncpu),
               ahbmi2 => dbgmi(2), ahbmo2 => dbgmo(2),
               apbi => apbi(4), apbo => apbo(4), ethi => ethi, etho => etho);
      eth_rstn<=rstn;

    ethi.edclsepahb <= '1';

    -- sw[2:0] selects 3 LSB of EDCL IP
    --ethi.edcladdr <= '1' & swint(2 downto 0);
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
  ---  Fake MIG PNP -----------------------------------------------------
  -----------------------------------------------------------------------

  fake_mig_gen : if CFG_L2_EN /= 0 generate
    ahbso(mig_hindex).hindex  <= mig_hindex;
    ahbso(mig_hindex).hconfig <= mig_hconfig;
    ahbso(mig_hindex).hready  <= '1';
    ahbso(mig_hindex).hresp   <= "00";
    ahbso(mig_hindex).hirq    <= (others => '0');
    ahbso(mig_hindex).hrdata  <= (others => '0');
  end generate;
  no_fake_mig_gen : if CFG_L2_EN = 0 generate
    ahbso(mig_hindex) <= ahbs_none;
  end generate;

  -----------------------------------------------------------------------
  ---  Test report module  ----------------------------------------------
  -----------------------------------------------------------------------

-- pragma translate_off
  test0 : ahbrep
    generic map(
      hindex => 2,
      haddr => 16#200#)
    port map(
      rstn,
      clkm,
      ahbsi,
      ahbso(2));
-- pragma translate_on

-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
    generic map (
      msg1 => "NOEL-V Demonstration design for Digilent Arty A7 board" &
      ", " & integer'image(CPU_FREQ / 1000) & " MHz",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel => 1
      );
-- pragma translate_on

end rtl;

