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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
use gaisler.l2cache.all;
use gaisler.l2c_lite.all;
use gaisler.noelv.all;
use gaisler.nandfctrl2_pkg.all;
use gaisler.canfd.all;
use gaisler.hssl.all;
use gaisler.spacewire.all;

--pragma translate_off
use gaisler.sim.all;
--pragma translate_on

use work.config.all;
use work.config_local.all;
use work.rev.REVISION;
use work.cfgmap.all;

entity noelvcore is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    cpu_freq                : integer := 10000;
    oepol                   : integer := padoen_polarity(CFG_PADTECH);
    devid                   : integer := NOELV_SOC;
    disas                   : integer := CFG_LOCAL_DISAS    -- Enable disassembly to console
    );
  port (
    -- Clock & reset
    clkm          : in  std_ulogic;
    resetn        : in  std_ulogic;
    lock          : in  std_ulogic;
    rstno         : out std_ulogic;
    -- misc
    dmen          : in  std_ulogic;
    dmbreak       : in  std_ulogic;
    dmreset       : out std_ulogic;
    cpu0errn      : out std_ulogic;
    -- GPIO
    gpio_i        : in  std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
    gpio_o        : out std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
    gpio_oe       : out std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
    -- UART
    uart_rx       : in  std_logic_vector(0 downto 0);
    uart_ctsn     : in  std_logic_vector(0 downto 0);
    uart_tx       : out std_logic_vector(0 downto 0);
    uart_rtsn     : out std_logic_vector(0 downto 0);
    -- Memory controller
    mem_aximi     : in  axi_somi_type;
    mem_aximo     : out axi_mosi_type;
    mem_ahbsi0    : out ahb_slv_in_type;
    mem_ahbso0    : in  ahb_slv_out_type;
    mem_apbi0     : out apb_slv_in_type;
    mem_apbo0     : in  apb_slv_out_type;
    -- PROM controller
    rom_ahbsi1    : out ahb_slv_in_type;
    rom_ahbso1    : in  ahb_slv_out_type;
    -- Ethernet PHY
    ethi          : in  eth_in_type;
    etho          : out eth_out_type;
    eth_apbi      : out apb_slv_in_type;
    eth_apbo      : in  apb_slv_out_type;
    -- NANDFCTRL
    nf2_core_clk  : in  std_ulogic          := '0';
    nf2_core_rstn : in  std_ulogic          := '0';
    nf2_phyi      : in  nf2_to_phy_out_type := NF2_TO_PHY_OUT_NONE;
    nf2_phyo      : out nf2_to_phy_in_type;
    -- Debug UART
    duart_rx      : in  std_ulogic;
    duart_tx      : out std_ulogic;
    -- CANFD
    can0_tx       : out   std_logic;
    can0_rx       : in    std_logic := '0';
    can1_tx       : out   std_logic;
    can1_rx       : in    std_logic := '0';
    -- HSSL
    hssl_clk      : in std_ulogic := '0';
    hssl_rstn     : in std_ulogic := '0';
    hssli         : in grhssl_in_type_vector(1 downto 0) := (others => GRHSSL_IN_NULL);
    hsslo         : out grhssl_out_type_vector(1 downto 0);
    --SpaceWire
    spw_txd          : out std_logic_vector(CFG_SPWRTR_SPWPORTS-1 downto 0);
    spw_txs          : out std_logic_vector(CFG_SPWRTR_SPWPORTS-1 downto 0);
    spw_rxd          : in std_logic_vector(CFG_SPWRTR_SPWPORTS-1 downto 0) := (others => '0');
    spw_rxs          : in std_logic_vector(CFG_SPWRTR_SPWPORTS-1 downto 0) := (others => '0');
    -- Debug JTAG
    trst          : in std_ulogic           := '1';
    tck           : in std_ulogic;
    tms           : in std_ulogic;
    tdi           : in std_ulogic;
    tdo           : out std_ulogic;
    -- RISC-V JTAG
    jtag_rv_tck   : in std_ulogic           := '0';
    jtag_rv_tms   : in std_ulogic           := '0';
    jtag_rv_tdi   : in std_ulogic           := '0';
    jtag_rv_tdo   : out std_ulogic
  );
end;

architecture rtl of noelvcore is

  -- Constants ------------------------

  constant ncpu     : integer := CFG_LOCAL_NCPU;

  constant nextmst  : integer := ncpu + 6;

  constant nextslv  : integer := 8
-- pragma translate_off
  + 1
-- pragma translate_on
  ;

  constant ndbgmst  : integer := 7
  ;

  constant mig_hindex : integer := 7
-- pragma translate_off
  + 1
-- pragma translate_on
  ;


  constant mig_hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
    4 => ahb_membar(L2C_HADDR, '1', '1', L2C_HMASK),
    others => zero32);

  -- SpaceWire TX CLK frequency in KHz
  constant SPW_CLKFREQ : integer := 200000;
  
  -- SPW clock divisor value used during initialisation and as reset value
  -- for for the clock divisor register. The tx clock frequency is:
  -- (input spw clock) / (clock divisor value + 1)
  constant SPW_CLKDIV10 : std_logic_vector(7 downto 0) :=
    conv_std_logic_vector(SPW_CLKFREQ/10000 - 1, 8);
  constant SPWINSTID : integer := 0;
  -- Signals --------------------------

  -- Misc
  signal vcc        : std_ulogic;
  signal gnd        : std_ulogic;
  signal rstn       : std_ulogic;
  signal rstnraw    : std_logic;
  signal stati      : ahbstat_in_type;
  signal gclk       : std_logic_vector(ncpu-1 downto 0);

  -- APB
  signal apbi       : apb_slv_in_type;
  signal apbo       : apb_slv_out_vector := (others => apb_none);

  -- AHB
  signal ahbsi      : ahb_slv_in_type;
  signal ahbso      : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi      : ahb_mst_in_type;
  signal ahbmi_none : ahb_mst_in_type;
  signal ahbmo      : ahb_mst_out_vector := (others => ahbm_none);
  signal dbgmi      : ahb_mst_in_vector_type(ndbgmst-1 downto 0);
  signal dbgmo      : ahb_mst_out_vector_type(ndbgmst-1 downto 0);
  -- AHB memory bus
  signal mem_ahbsi  : ahb_slv_in_type;
  signal mem_ahbso  : ahb_slv_out_vector := (others => ahbs_none);
  signal mem_ahbmi  : ahb_mst_in_type;
  signal mem_ahbmo  : ahb_mst_out_vector := (others => ahbm_none);
  -- APB buses
  signal apb0i            : apb_slv_in_type;
  signal apb0o            : apb_slv_out_vector;
  signal apb1i            : apb_slv_in_type;
  signal apb1o            : apb_slv_out_vector;

  -- Memory
  signal axi3_aximo : axi3_mosi_type;

  signal u1i, dui   : uart_in_type;
  signal u1o, duo   : uart_out_type;

  -- GPIOs
  signal gpioi      : gpio_in_type;
  signal gpioo      : gpio_out_type;

  -- Ethernet
  signal ethi_int   : eth_in_type;

  --GRCANFD
  signal ahbmi_canfd0     : ahb_mst_in_vector_type  (1 downto 0);
  signal ahbmo_canfd0     : ahb_mst_out_vector_type (1 downto 0);
  signal ahbmi_canfd1     : ahb_mst_in_vector_type  (1 downto 0);
  signal ahbmo_canfd1     : ahb_mst_out_vector_type (1 downto 0);
  signal cani0            : canfd_in_type;
  signal cano0            : canfd_out_type;
  signal cani1            : canfd_in_type;
  signal cano1            : canfd_out_type;
  signal grcanfd0_cfg     : grcanfd_defcfg_type;
  signal grcanfd1_cfg     : grcanfd_defcfg_type;

  type grcanfd_bit_time_reg_type is record
    nom_presc  : std_logic_vector(7 downto 0);  -- Prescaler
    nom_ph1    : std_logic_vector(5 downto 0);  -- Prop + Ph1 segments
    nom_ph2    : std_logic_vector(4 downto 0);  -- Ph2 segment
    nom_sjw    : std_logic_vector(4 downto 0);  -- Synchronization Jump Width
  end record;

  type grcanfd_bit_time_arr_type is array (3 downto 0) of grcanfd_bit_time_reg_type;

  constant GRCANFD_BIT_TIME_DEF : grcanfd_bit_time_arr_type := (("00000001","000001","00001","00001"),  -- bit rate 125kpbs ---TODO
                                                              ("00000001","000001","00001","00001"),
                                                              ("00000001","000001","00001","00001"),
                                                              ("00000001","000001","00001","00001"));  -- bit rate 1Mbps ---TODO

  signal bit_time_aux_index : std_logic_vector ( 1 downto 0);
  signal grcanfd_inputcfg0, grcanfd_inputcfg1 : grcanfd_defcfg_type;
  signal grcanfd_bit_time_aux: grcanfd_bit_time_reg_type;

  -- HSSL
  signal ahbmi_vct : ahb_mst_in_vector_type(0 downto 0);

  -- SpaceWire clocks
  signal spw_clkl        : std_ulogic;
  signal spw_clkln       : std_ulogic;
  
  -- SpaceWire router
  signal sahbmo           : spw_ahb_mst_out_vector(0 to CFG_SPWRTR_AMBAPORTS-CFG_SPWRTR_AMBAEN);
  signal sahbmi           : spw_ahb_mst_in_vector(0 to CFG_SPWRTR_AMBAPORTS-CFG_SPWRTR_AMBAEN);
  signal sapbo            : spw_apb_slv_out_vector(0 to CFG_SPWRTR_AMBAPORTS-CFG_SPWRTR_AMBAEN);
  signal dtmp             : std_logic_vector(CFG_SPWRTR_SPWPORTS-CFG_SPWRTR_SPWEN downto 0);
  signal stmp             : std_logic_vector(CFG_SPWRTR_SPWPORTS-CFG_SPWRTR_SPWEN downto 0);
  signal di               : std_logic_vector(CFG_SPWRTR_SPWPORTS*2-CFG_SPWRTR_SPWEN downto 0);
  signal dvi              : std_logic_vector(CFG_SPWRTR_SPWPORTS*2-CFG_SPWRTR_SPWEN downto 0);
  signal dconnect         : std_logic_vector(CFG_SPWRTR_SPWPORTS*2-CFG_SPWRTR_SPWEN downto 0);
  signal dconnect2        : std_logic_vector(CFG_SPWRTR_SPWPORTS*2-CFG_SPWRTR_SPWEN downto 0);
  signal dconnect3        : std_logic_vector(CFG_SPWRTR_SPWPORTS*2-CFG_SPWRTR_SPWEN downto 0);
  signal do               : std_logic_vector(CFG_SPWRTR_SPWPORTS*2-CFG_SPWRTR_SPWEN downto 0);
  signal so               : std_logic_vector(CFG_SPWRTR_SPWPORTS*2-CFG_SPWRTR_SPWEN downto 0);
  signal rxclko           : std_logic_vector(CFG_SPWRTR_SPWPORTS-CFG_SPWRTR_SPWEN downto 0);
  signal txclk_array      : std_logic_vector(CFG_SPWRTR_SPWPORTS-CFG_SPWRTR_SPWEN downto 0);
  signal txclkn_array     : std_logic_vector(CFG_SPWRTR_SPWPORTS-CFG_SPWRTR_SPWEN downto 0);
  signal ri               : grspw_router_in_type;
  signal ro               : grspw_router_out_type;
  

  -- Attributes -----------------------

  attribute keep                     : boolean;
  attribute syn_keep                 : boolean;
  attribute syn_preserve             : boolean;
  attribute syn_keep of lock         : signal is true;
  attribute syn_keep of clkm         : signal is true;
  attribute syn_preserve of clkm     : signal is true;
  attribute keep of lock             : signal is true;
  attribute keep of clkm             : signal is true;

begin
  vcc         <= '1';
  gnd         <= '0';

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------

  rst0 : rstgen
    generic map(acthigh => 0)
    port map (resetn, clkm, lock, rstn, rstnraw);

    rstno <= rstn;

  gen_gclk: for i in 0 to ncpu-1 generate
    gclk(i) <= clkm;
  end generate;

  ----------------------------------------------------------------------
  ---  NOEL-V SUBSYSTEM ------------------------------------------------
  ----------------------------------------------------------------------

  noelv0 : noelvsys
    generic map (
      fabtech   => fabtech,
      memtech   => memtech,
      ncpu      => ncpu,
      nextmst   => nextmst,
      nextslv   => nextslv,
      nextapb   => 10,
      ndbgmst   => ndbgmst,
      nintdom   => CFG_APLIC_NDOM,
      neiid     => CFG_NEIID,
      cached    => 0,
      wbmask    => CFG_LOCAL_WBMASK,
      busw      => AHBDW,
      cmemconf  => CFG_LOCAL_CMEMCONF,
      fpuconf   => CFG_LOCAL_FPUCONF,
      rfconf    => CFG_LOCAL_RFCONF,
      --tcmconf   => CFG_LOCAL_TCMCONF,
      mulconf   => CFG_LOCAL_MULCONF,
      intcconf   => CFG_LOCAL_INTCCONF,
      disas     => disas,
      ahbtrace  => 0,
      cfg       => CFG_LOCAL_CFG,
      devid     => devid,
      nodbus    => CFG_LOCAL_NODBUS
      )
    port map(
      clk       => clkm, -- : in  std_ulogic;
      gclk      => gclk, -- : in  std_logic_vector(CFG_NCPU-1 downto 0)
      rstn      => rstn, -- : in  std_ulogic;
      -- Power down mode
      pwrd      => open, -- : out std_logic_vector(ncpu-1 downto 0);
      -- AHB bus interface for other masters (DMA units)
      ahbmi     => ahbmi, -- : out ahb_mst_in_type;
      ahbmo     => ahbmo(ncpu+nextmst-1 downto ncpu), -- : in  ahb_mst_out_vector_type(ncpu+nextmst-1 downto ncpu);
      -- AHB bus interface for slaves (memory controllers, etc)
      ahbsi     => ahbsi, -- : out ahb_slv_in_type;
      ahbso     => ahbso(nextslv-1 downto 0), -- : in  ahb_slv_out_vector_type(nextslv-1 downto 0);
      -- AHB master interface for debug links
      dbgmi     => dbgmi, -- : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
      dbgmo     => dbgmo, -- : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
      -- APB interface for external APB slaves
      apbi      => apbi, -- : out apb_slv_in_type;
      apbo      => apbo, -- : in  apb_slv_out_vector;
      -- Bootstrap signals
      dsuen     => dmen, -- : in  std_ulogic;
      dsubreak  => dmbreak, -- : in  std_ulogic;
      cpu0errn  => cpu0errn, -- : out std_ulogic;
      --dmreset   => dmreset,
      -- UART connection
      uarti     => u1i, -- : in  uart_in_type;
      uarto     => u1o  -- : out uart_out_type
      );

  uart_rtsn(0)  <= u1o.rtsn;
  uart_tx(0)    <= u1o.txd;
  u1i.ctsn      <= uart_ctsn(0);
  u1i.rxd       <= uart_rx(0);

  -----------------------------------------------------------------------------
  -- Debug UART ---------------------------------------------------------------
  -----------------------------------------------------------------------------

  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map(
        hindex => UART_DM_HMINDEX,
        pindex => AHBUART_PINDEX,
        paddr => AHBUART_PADDR,
        pmask => AHBUART_PMASK)
      port map(
        rstn,
        clkm,
        dui,
        duo,
        apbi,
        apbo(AHBUART_PINDEX),
        dbgmi(UART_DM_HMINDEX),
        dbgmo(UART_DM_HMINDEX));
    dui.extclk <= '0';
  end generate;

  nouah : if CFG_AHB_UART = 0 generate
    apbo(AHBUART_PINDEX)    <= apb_none;
    duo.txd    <= '0';
    duo.rtsn   <= '0';
    dui.extclk <= '0';
  end generate;

  duart_tx  <= duo.txd;
  dui.rxd   <= duart_rx;

  -----------------------------------------------------------------------------
  -- JTAG debug link ----------------------------------------------------------
  -----------------------------------------------------------------------------

  ahbjtaggen0 : if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag
      generic map(
        tech    => fabtech,
        nsync   => CFG_LOCAL_JTAG_NSYNC,
        versel  => CFG_LOCAL_JTAG_VERSEL,
        hindex  => JTAG_DM_HMINDEX,
        ainst   => CFG_LOCAL_JTAG_AINST,
        dinst   => CFG_LOCAL_JTAG_DINST)
      port map(rstn, clkm, tck, tms, tdi, tdo,
               dbgmi(JTAG_DM_HMINDEX), dbgmo(JTAG_DM_HMINDEX),
               open, open, open, open, open, open, open, gnd, trst, open,
               gnd, open, open, open);
  end generate;

  -----------------------------------------------------------------------------
  -- RISC-V JTAG debug link ---------------------------------------------------
  -----------------------------------------------------------------------------

  ahbjtagrvgen0 : if CFG_LOCAL_AHB_JTAG_RV = 1 generate
    ahbjtag0 : ahbjtagrv
      generic map(
        tech      => fabtech,
        dtm_sel   => 1,
        tapopt    => 1,
        hindex_gr => JTAGRV0_DM_HMINDEX,
        hindex_rv => JTAGRV1_DM_HMINDEX,
        idcode    => 9,
        ainst_gr  => 2,
        dinst_gr  => 3,
        ainst_rv  => 16,
        dinst_rv  => 17)
      port map(
        rst       => rstn,
        clk       => clkm,
        tck       => jtag_rv_tck,
        tms       => jtag_rv_tms,
        tdi       => jtag_rv_tdi,
        tdo       => jtag_rv_tdo,
        ahbi_gr   => dbgmi(JTAGRV0_DM_HMINDEX),
        ahbo_gr   => dbgmo(JTAGRV0_DM_HMINDEX),
        ahbi_rv   => dbgmi(JTAGRV1_DM_HMINDEX),
        ahbo_rv   => dbgmo(JTAGRV1_DM_HMINDEX),
        tapo_tck  => open,
        tapo_tdi  => open,
        tapo_inst => open,
        tapo_rst  => open,
        tapo_capt => open,
        tapo_shft => open,
        tapo_upd  => open,
        tapi_tdo  => gnd,
        trst      => rstn,
        tdoen     => open,
        tckn      => open,
        tapo_tckn => open,
        tapo_ninst=> open,
        tapo_iupd => open);
  end generate;
  no_ahbjtagrvgen0 : if CFG_LOCAL_AHB_JTAG_RV = 0 generate
    jtag_rv_tdo <= '0';
    -- pragma translate_off
    dbgmo(JTAGRV0_DM_HMINDEX) <= ahbm_none;
    dbgmo(JTAGRV1_DM_HMINDEX) <= ahbm_none;
    -- pragma translate_on
  end generate;

  -----------------------------------------------------------------------
  ---  AT AHB MST -------------------------------------------------------
  -----------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Memory Controller (AXI or (hindex = 0 abd pindex = 0)) -------------------
  -----------------------------------------------------------------------------

  axi_gen : if (CFG_L2_AXI = 1) generate
    gen_l2c : if CFG_L2_EN /= 0 generate
      l2_std : if CFG_L2_LITE = 0 generate
        l2c0 : l2c_axi_be
          generic map (
            hslvidx   => L2C_HSINDEX,
            axiid     => 0,
            cen       => CFG_L2_PEN,
            haddr     => L2C_HADDR,
            hmask     => L2C_HMASK,
            ioaddr    => L2C_IOADDR,
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
            ahbso => ahbso(L2C_HSINDEX),
            aximi => mem_aximi,
            aximo => mem_aximo,
            sto   => open);
      end generate;
      l2_lite : if CFG_L2_LITE = 1 generate
        l2c_lite0 : l2c_lite_axi3
        generic map(
          tech     => memtech,
          hmindex  => 0,
          hsindex  => L2C_HSINDEX,
          ways     => CFG_L2_WAYS,
          waysize  => CFG_L2_SIZE,
          linesize => CFG_L2_LSZ,
          repl     => 0,
          haddr    => L2C_HADDR,
          hmask    => L2C_HMASK,
          ioaddr   => L2C_IOADDR,
          cached   => CFG_L2_MAP,
          be_dw    => AHBDW)
        port map(
          rstn     => rstn,
          clk      => clkm,
          ahbsi    => ahbsi,
          ahbso    => ahbso(L2C_HSINDEX),
          aximi    => mem_aximi,
          aximo    => mem_aximo);
      end generate;
    end generate;
    nogen_l2c : if CFG_L2_EN = 0 generate
      bridge: ahb2axi3b
        generic map (
          hindex          => L2C_HSINDEX,
          aximid          => 0,
          wbuffer_num     => 8,
          rprefetch_num   => 8,
          endianness_mode => 0,
          narrow_acc_mode => 0,
          vendor          => VENDOR_GAISLER,
          device          => GAISLER_MIG_7SERIES,
          bar0            => ahb2ahb_membar(L2C_HADDR, '1', '1', L2C_HMASK)
          )
        port map (
          rstn  => rstn,
          clk   => clkm,
          ahbsi => ahbsi,
          ahbso => ahbso(L2C_HSINDEX),
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

    mem_ahbsi0  <= ahbs_in_none;
    mem_apbi0   <= apb_slv_in_none;
    -- No APB interface on memory controller
    apbo(MEM_PINDEX)  <= apb_none;
  end generate;
  noaxi_gen : if (CFG_L2_AXI = 0) generate
    gen_l2c : if CFG_L2_EN /= 0 generate
      l2_std : if CFG_L2_LITE = 0 generate
        l2c0 : l2c
          generic map (
            hslvidx   => L2C_HSINDEX,
            hmstidx   => 0,
            cen       => CFG_L2_PEN,
            haddr     => L2C_HADDR,
            hmask     => L2C_HMASK,
            ioaddr    => L2C_IOADDR,
            cached    => CFG_L2_MAP,
            repl      => CFG_L2_RAN,
            ways      => CFG_L2_WAYS,
            linesize  => CFG_L2_LSZ,
            waysize   => CFG_L2_SIZE,
            memtech   => memtech,
            bbuswidth => CFG_LOCAL_L2C_BBWIDTH,
            bioaddr   => 16#FFD#,
            biomask   => 16#fff#,
            sbus      => 0,
            mbus      => 1,
            arch      => CFG_L2_SHARE,
            ft        => CFG_L2_EDAC)
          port map(
            rst     => rstn,
            clk     => clkm,
            ahbsi   => ahbsi,
            ahbso   => ahbso(L2C_HSINDEX),
            ahbmi   => mem_ahbmi,
            ahbmo   => mem_ahbmo(0),
            ahbsov  => mem_ahbso);
      end generate;
      l2_lite : if CFG_L2_LITE = 1 generate
        l2c_lite0 : l2c_lite_ahb
          generic map(
            tech     => memtech,
            hmindex  => 0,
            hsindex  => L2C_HSINDEX,
            ways     => CFG_L2_WAYS,
            waysize  => CFG_L2_SIZE,
            linesize => CFG_L2_LSZ,
            repl     => 0,
            haddr    => L2C_HADDR,
            hmask    => L2C_HMASK,
            ioaddr   => L2C_IOADDR,
            bioaddr  => 16#FFD#,
            biomask  => 16#fff#,
            cached   => CFG_L2_MAP,
            be_dw    => AHBDW)
          port map(
            rstn     => rstn,
            clk      => clkm,
            ahbsi    => ahbsi,
            ahbso    => ahbso(L2C_HSINDEX),
            ahbmi    => mem_ahbmi,
            ahbmo    => mem_ahbmo(0) );
      end generate;

      ahb_men : ahbctrl                -- AHB arbiter/multiplexer
        generic map (
          defmast => CFG_DEFMST,
          split   => CFG_SPLIT,
          rrobin  => CFG_RROBIN,
          ioaddr  => 16#FFD#,
          ioen    => 1,
          nahbm   => 1, nahbs => 1,
          fpnpen  => CFG_FPNPEN,
          ahbendian => 0)
        port map (
          rstn,
          clkm,
          mem_ahbmi,
          mem_ahbmo,
          mem_ahbsi,
          mem_ahbso);

      mem_ahbmo(NAHBMST-1 downto 1) <= (others => ahbm_none);
      mem_ahbso(NAHBMST-1 downto 1) <= (others => ahbs_none);
      mem_ahbsi0              <= mem_ahbsi;
      mem_ahbso(MEM_HSINDEX)  <= mem_ahbso0;
    end generate;
    nogen_l2c : if CFG_L2_EN = 0 generate
      mem_ahbsi0          <= ahbsi;
      ahbso(L2C_HSINDEX)  <= mem_ahbso0;
    end generate;
    mem_apbi0         <= apbi;
    apbo(MEM_PINDEX)  <= mem_apbo0;
  end generate;

  -----------------------------------------------------------------------
  ---  AHB ROM (slave hindex = 1)
  -----------------------------------------------------------------------
      rom_ahbsi1          <= ahbsi;
      ahbso(ROM_HSINDEX)  <= rom_ahbso1;

  ----------------------------------------------------------------------
  --- APB Bridge and various periherals --------------------------------
  ----------------------------------------------------------------------

  --  AHB Status Register
  ahbs : if CFG_AHBSTAT = 1 generate
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat
      generic map(
        pindex  => AHBSTAT_PINDEX,
        paddr   => AHBSTAT_PADDR,
        pmask   => AHBSTAT_PMASK,
        pirq    => AHBSTAT_PIRQ,
        nftslv  => CFG_AHBSTATN)
      port map(
        rstn,
        clkm,
        ahbmi,
        ahbsi,
        stati,
        apbi,
        apbo(AHBSTAT_PINDEX));
  end generate;

  -- GPIO units
  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate

    grgpio_ledsw : grgpio
      generic map(
        pindex  => GRGPIO_PINDEX,
        paddr   => GRGPIO_PADDR,
        pmask   => GRGPIO_PMASK,
        imask   => CFG_GRGPIO_IMASK,
        nbits   => CFG_GRGPIO_WIDTH)
      port map(
        rst   => rstn,
        clk   => clkm,
        apbi  => apbi,
        apbo  => apbo(GRGPIO_PINDEX),
        gpioi => gpioi,
        gpioo => gpioo);

    -- Tie-off alternative output enable signals
    gpioi.sig_en        <= (others => '0');
    gpioi.sig_in        <= (others => '0');

    gpio_o  <= gpioo.dout(CFG_GRGPIO_WIDTH-1 downto 0);
    gpio_oe <= gpioo.oen(CFG_GRGPIO_WIDTH-1 downto 0);
    gpioi.din(CFG_GRGPIO_WIDTH-1 downto 0)  <= gpio_i;
  end generate;

  -- Version
  grver0 : grversion
    generic map(
      pindex      => GRVER_PINDEX,
      paddr       => GRVER_PADDR,
      pmask       => GRVER_PMASK,
      versionnr   => CFG_LOCAL_CFG,
      revisionnr  => work.rev.REVISION)
    port map(
      rstn  => rstn,
      clk   => clkm,
      apbi  => apbi,
      apbo  => apbo(GRVER_PINDEX));


-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

  eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC
    e1 : grethm_mb
      generic map(
        hindex => GRETH_HMINDEX, ehindex => GRETH_DM_HMINDEX,
        pindex => GRETH_PINDEX, paddr => GRETH_PADDR, pmask => GRETH_PMASK, pirq => GRETH_PIRQ,
        memtech => memtech,
        mdcscaler => CPU_FREQ/1000, rmii => 0, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
        nsync => 2, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF, phyrstadr => CFG_ETH_PHY_ADDR,
        macaddrh => CFG_ETH_ENM, macaddrl => CFG_LOCAL_ETH_ENL, enable_mdint => 1,
        ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_LOCAL_ETH_IPL,
        giga => CFG_GRETH1G, ramdebug => 0, gmiimode => CFG_LOCAL_ETH_GMII,
        edclsepahb => 1)
      port map( rst => rstn, clk => clkm,
                ahbmi => ahbmi, ahbmo => ahbmo(GRETH_HMINDEX),
                ahbmi2 => dbgmi(GRETH_DM_HMINDEX), ahbmo2 => dbgmo(GRETH_DM_HMINDEX),
                apbi => apbi, apbo => apbo(GRETH_PINDEX), ethi => ethi_int, etho => etho);

    eth_in_sig : process (ethi)
    begin
      ethi_int <= ethi;
      ethi_int.edclsepahb <= '1';
    end process;

    -- ETH PHY interface
    eth_apbi  <= apbi;
    apbo(GRETH_PHY_PINDEX)  <= eth_apbo;

  end generate;

  noeth0 : if CFG_GRETH = 0 generate
    -- TODO:
  end generate;

  -----------------------------------------------------------------------
  --  NANDFCTRL2
  -----------------------------------------------------------------------

  nfc0 : if CFG_NFC2_EN = 1 generate
    nandfctrl_1 : nandfctrl2
      generic map (
        hindex       => NFC2_HMINDEX,
        pindex       => NFC2_PINDEX,
        pirq         => NFC2_PIRQ,
        paddr        => NFC2_PADDR,
        pmask        => NFC2_PMASK,
        ahbbits      => AHBDW,

        memtech_uldl => memtech,
        memtech_ecc0 => memtech,
        memtech_ecc1 => memtech,
        tech         => memtech,

        nrofce       => CFG_NFC2_NROFCE,
        nrofch       => CFG_NFC2_NROFCH,
        nrofrb       => CFG_NFC2_NROFRB,
        rnd          => CFG_NFC2_RND,

        mem0_data    => CFG_NFC2_MEM0_DATA,
        mem0_spare   => CFG_NFC2_MEM0_SPARE,
        mem0_ecc_sel => CFG_NFC2_MEM0_ECC_SEL,

        mem1_data    => CFG_NFC2_MEM1_DATA,
        mem1_spare   => CFG_NFC2_MEM1_SPARE,
        mem1_ecc_sel => CFG_NFC2_MEM1_ECC_SEL,

        mem2_data    => CFG_NFC2_MEM2_DATA,
        mem2_spare   => CFG_NFC2_MEM2_SPARE,
        mem2_ecc_sel => CFG_NFC2_MEM2_ECC_SEL,

        ecc0_gfsize  => CFG_NFC2_ECC0_GFSIZE,
        ecc0_chunk   => CFG_NFC2_ECC0_CHUNK,
        ecc0_cap     => CFG_NFC2_ECC0_CAP,

        ecc1_gfsize  => CFG_NFC2_ECC1_GFSIZE,
        ecc1_chunk   => CFG_NFC2_ECC1_CHUNK,
        ecc1_cap     => CFG_NFC2_ECC1_CAP,

        rst_cycles   => CFG_NFC2_RST_CYCLES,
        tag_size     => CFG_NFC2_TAG_SIZE,

        ft           => CFG_NFC2_FT,
        scantest     => 0,

        oepol        => oepol
        )
      port map (
        rstn      => rstn, -- apb/ahb reset and clock.
        clk_sys   => clkm,

        core_rstn => nf2_core_rstn, -- nandfctrl2 core reset and clock.
        clk_core  => nf2_core_clk,

        apbi      => apbi,
        apbo      => apbo(NFC2_PINDEX),

        ahbmi     => ahbmi,
        ahbmo     => ahbmo(NFC2_HMINDEX),

        phyi      => nf2_phyi,
        phyo      => nf2_phyo
        );
    end generate;

    nonfc0 : if CFG_NFC2_EN = 0 generate
      apbo(NFC2_PINDEX)   <= apb_none;
      ahbmo(NFC2_HMINDEX) <= ahbm_none;
      nf2_phyo            <= NF2_TO_PHY_IN_NONE;
    end generate;

  -----------------------------------------------------------------------
  ---  Fake MIG PNP -----------------------------------------------------
  -----------------------------------------------------------------------

  fake_mig_gen : if (CFG_L2_AXI /= 0) and (CFG_L2_EN /= 0) generate
    ahbso(mig_hindex).hindex  <= mig_hindex;
    ahbso(mig_hindex).hconfig <= mig_hconfig;
    ahbso(mig_hindex).hready  <= '1';
    ahbso(mig_hindex).hresp   <= "00";
    ahbso(mig_hindex).hirq    <= (others => '0');
    ahbso(mig_hindex).hrdata  <= (others => '0');
  end generate;
  no_fake_mig_gen : if (CFG_L2_AXI = 0) or (CFG_L2_EN = 0) generate
    ahbso(mig_hindex) <= ahbs_none;
  end generate;

  -----------------------------------------------------------------------
  ---  Test report module  ----------------------------------------------
  -----------------------------------------------------------------------

-- pragma translate_off
  test0 : ahbrep
    generic map(
      hindex => AHBREP_HSINDEX,
      haddr => AHBREP_HADDR,
      hmask => AHBREP_HMASK)
    port map(
      rstn,
      clkm,
      ahbsi,
      ahbso(AHBREP_HSINDEX));
-- pragma translate_on


  -----------------------------------------------------------------------
  ---  APB/AHB Bridges  -------------------------------------------------
  -----------------------------------------------------------------------
  apb0 : apbctrl                       
    generic map (
      hindex      => APB0_HSINDEX,
      haddr       => 16#FF4#,
      hmask       => 16#fff#,
      nslaves     => 2,
      debug       => 2,
      icheck      => 1,
      enbusmon    => 0,
      asserterr   => 0,
      assertwarn  => 0,
      pslvdisable => 0,
      mcheck      => 1,
      ccheck      => 1)
    port map (
      rst         => rstn,
      clk         => clkm,
      ahbi        => ahbsi,
      ahbo        => ahbso(APB0_HSINDEX),
      apbi        => apb0i,
      apbo        => apb0o);

  unused_apb0 : for i in CFG_LOCAL_GRCANFD0 + CFG_LOCAL_GRCANFD1  to NAPBSLV-1 generate
    apb0o(i) <= apb_none;
  end generate;

  apb1 : apbctrl                        -- AHB/APB bridge 4
    generic map (
      hindex      => APB1_HSINDEX,
      haddr       => 16#FF5#,
      hmask       => 16#fff#,
      nslaves     => 2,
      debug       => 2,
      icheck      => 1,
      enbusmon    => 0,
      asserterr   => 0,
      assertwarn  => 0,
      pslvdisable => 0,
      mcheck      => 1,
      ccheck      => 1)
    port map (
      rst         => rstn,
      clk         => clkm,
      ahbi        => ahbsi,
      ahbo        => ahbso(APB1_HSINDEX),
      apbi        => apb1i,
      apbo        => apb1o);

  unused_apb1 : for i in CFG_SPWRTR_AMBAPORTS*CFG_SPWRTR_AMBAEN  to NAPBSLV-1 generate
    apb1o(i) <= apb_none;
  end generate;

  -----------------------------------------------------------------------
  ---  GRCANFD ----------------------------------------------------------
  -----------------------------------------------------------------------
  can0: if CFG_LOCAL_GRCANFD0 = 1  generate

    ahbmi_canfd0(0)      <= ahbmi;
    ahbmo(CANFD0_HMINDEX)  <= ahbmo_canfd0(0);
    ahbmi_canfd0(1)      <= dbgmi(CANFD0_DM_HMINDEX);
    dbgmo(CANFD0_DM_HMINDEX)  <= ahbmo_canfd0(1);

    grcanfd0_cfg <= GRCANFD_CFG_NULL;
    
    grcanfd0 : grcanfd_ahb
      generic map(
        hindex         => CANFD0_HMINDEX,
        pindex         => 0,
        paddr          => CANFD0_PADDR,
        pmask          => CANFD0_PMASK,
        canopen        => 1,
        sepbus         => 1,
        hindexcopen    => CANFD0_DM_HMINDEX,
        pirq           => CANFD0_PIRQ,
        singleirq      => 1,
        txbufsize      => 2,
        rxbufsize      => 2)
      port map(
        clk            => clkm,
        rstn           => rstn,
        ahbmi          => ahbmi_canfd0,
        ahbmo          => ahbmo_canfd0,
        apbi           => apb0i,
        apbo           => apb0o(0),
        cani           => cani0,
        cano           => cano0,
        cfg            => grcanfd_inputcfg0
        );

    can0_tx     <= cano0.tx(0) ;
    cani0.rx    <= can0_rx & can0_rx;

  end generate can0;

  nocan0 : if CFG_LOCAL_GRCANFD0 = 0 generate
    cano0 <= (tx => "11", en => "00");
    can0_tx <= '1';
    ahbmo(CANFD0_HMINDEX)     <= ahbm_none;
    dbgmo(CANFD0_DM_HMINDEX)  <= ahbm_none;
  end generate; 

  can1: if CFG_LOCAL_GRCANFD1 = 1  generate

    ahbmi_canfd1(0)      <= ahbmi;
    ahbmo(CANFD1_HMINDEX)  <= ahbmo_canfd1(0) ;
    ahbmi_canfd1(1)      <= dbgmi(CANFD1_DM_HMINDEX);
    dbgmo(CANFD1_DM_HMINDEX)  <= ahbmo_canfd1(1);

    grcanfd1_cfg <= GRCANFD_CFG_NULL;
    
    grcanfd1 : grcanfd_ahb
      generic map(
        hindex         => CANFD1_HMINDEX,
        pindex         => 1,
        paddr          => CANFD1_PADDR,
        pmask          => CANFD1_PMASK,
        pirq           => CANFD1_PIRQ,
        canopen        => 1,
        sepbus         => 1,
        hindexcopen    => CANFD1_DM_HMINDEX,
        singleirq      => 1,
        txbufsize      => 2,
        rxbufsize      => 2)
      port map(
        clk            => clkm,
        rstn           => rstn,
        ahbmi          => ahbmi_canfd1,
        ahbmo          => ahbmo_canfd1,
        apbi           => apb0i,
        apbo           => apb0o(1),
        cani           => cani1,
        cano           => cano1,
        cfg            => grcanfd_inputcfg1
        );

    can1_tx     <= cano1.tx(0) ;
    cani1.rx    <= can1_rx & can1_rx;
    
  end generate can1;
  
  nocan1 : if CFG_LOCAL_GRCANFD1 = 0 generate
    cano1 <= (tx => "11", en => "00");
    can1_tx <= '1';
    ahbmo(CANFD1_HMINDEX)     <= ahbm_none;
    dbgmo(CANFD1_DM_HMINDEX)  <= ahbm_none;
  end generate;

    grcanfd_inputcfg0.en_codec   <=     '0';
    grcanfd_inputcfg0.en_canopen <=     '1';
    grcanfd_inputcfg0.node_id(6 downto 0)    <= "0000000";
    grcanfd_inputcfg0.line_sel <= '0';
    grcanfd_inputcfg0.en_out0  <= '1';
    grcanfd_inputcfg0.en_out1  <= '1';

    bit_time_aux_index <= "00";

    grcanfd_bit_time_aux         <= GRCANFD_BIT_TIME_DEF(to_integer(unsigned(bit_time_aux_index)));

    grcanfd_inputcfg0.nom_presc  <= grcanfd_bit_time_aux.nom_presc;
    grcanfd_inputcfg0.nom_ph1    <= grcanfd_bit_time_aux.nom_ph1;
    grcanfd_inputcfg0.nom_ph2    <= grcanfd_bit_time_aux.nom_ph2;
    grcanfd_inputcfg0.nom_sjw    <= grcanfd_bit_time_aux.nom_sjw;

    grcanfd_inputcfg1.en_codec   <=     '0';
    grcanfd_inputcfg1.en_canopen <=     '1';
    grcanfd_inputcfg1.node_id(6 downto 0)    <= "0000001";
    grcanfd_inputcfg1.line_sel <= '0';
    grcanfd_inputcfg1.en_out0  <= '1';
    grcanfd_inputcfg1.en_out1  <= '1';

    bit_time_aux_index <= "00";

    grcanfd_bit_time_aux         <= GRCANFD_BIT_TIME_DEF(to_integer(unsigned(bit_time_aux_index)));

    grcanfd_inputcfg1.nom_presc  <= grcanfd_bit_time_aux.nom_presc;
    grcanfd_inputcfg1.nom_ph1    <= grcanfd_bit_time_aux.nom_ph1;
    grcanfd_inputcfg1.nom_ph2    <= grcanfd_bit_time_aux.nom_ph2;
    grcanfd_inputcfg1.nom_sjw    <= grcanfd_bit_time_aux.nom_sjw;

  ----------------------------------------------------------------------
  --- High Speed Serial Link -------------------------------------------
  ----------------------------------------------------------------------

  hssl0 : if CFG_HSSL_EN = 1 generate

    gen_hssl_core : for i in 0 to 1 generate
      

      -- HSSL IP
      hssl_core : grspfi_ahb
        generic map (
          tech               => memtech,
          hmindex            => HSSL0_HMINDEX+i,
          hsindex            => HSSL0_HSINDEX+i,
          haddr              => HSSL_HADDR + i*16#010#,
          hmask              => HSSL_HMASK,
          hirq               => HSSL0_PIRQ + i,
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
          ahbmo      => ahbmo(HSSL0_HMINDEX+i downto HSSL0_HMINDEX+i),
          ahbsi      => ahbsi,
          ahbso      => ahbso(HSSL0_HSINDEX+i),
          -- Serdes interface
          spfii      => hssli(i),
          spfio      => hsslo(i)
          );

    end generate;

    ahbmi_vct(0) <= ahbmi;

  end generate;


  -----------------------------------------------------------------------------
  -- SpaceWire Router ---------------------------------------------------------
  -----------------------------------------------------------------------------

  --Since the resets and clockgate are generated internally in the wrapper,
  --the only element from TXCLK and TXCLKN to be used is the bit '0' (spw_clk).
  --The others remain unconnected
  
  txclk_array(0)                            <= clkm;
  spw_clkl                                  <= clkm;
  txclkn_array(0)                           <= '0';
  txclk_array(CFG_SPWRTR_SPWPORTS-1 downto 1)  <= (others => '0');
  txclkn_array(CFG_SPWRTR_SPWPORTS-1 downto 1) <= (others => '0');

  

  spwrtr : if CFG_SPWRTR_ENABLE /= 0 generate
    -- Physical layer
    phy_loop : for i in 0 to CFG_SPWRTR_SPWPORTS-1 generate
      spw_phy0 : grspw2_phy 
        generic map(
          scantest     => 0,
          tech         => fabtech,
          input_type   => CFG_SPWRTR_INPUT,
          rxclkbuftype => 1)
        port map(
          rstn       => rstn,
          rxclki     => spw_clkl,
          rxclkin    => spw_clkln,
          nrxclki    => spw_clkl,
          di         => dtmp(i),
          si         => stmp(i),
          do         => di(2*i+1 downto 2*i),
          dov        => dvi(2*i+1 downto 2*i),
          dconnect   => dconnect(2*i+1 downto 2*i),
          dconnect2  => dconnect2(2*i+1 downto 2*i),
          dconnect3  => dconnect3(2*i+1 downto 2*i),
          rxclko     => rxclko(i),
          testrst    => '0',
          testen     => '0');
      noloopb : if CFG_LOCAL_SPWRTR_LOOP_BACK = 0 generate
        dtmp(i)    <= spw_rxd(i);
        stmp(i)    <= spw_rxs(i);
        spw_txd(i) <= do(2*i);
        spw_txs(i) <= so(2*i);
      end generate noloopb;
      loopb : if CFG_LOCAL_SPWRTR_LOOP_BACK /= 0 generate
        dtmp(CFG_SPWRTR_SPWPORTS-1-i) <= do(2*i);
        stmp(CFG_SPWRTR_SPWPORTS-1-i) <= so(2*i);
        spw_txd(i) <= '0';
        spw_txs(i) <= '0';
      end generate loopb;
      
    end generate phy_loop;
    
    
    router0 : grspwrouterm
      generic map (
        input_type   => CFG_SPWRTR_INPUT,
        output_type  => CFG_SPWRTR_OUTPUT,
        rxtx_sameclk => CFG_SPWRTR_RTSAME,
        fifosize     => CFG_SPWRTR_RXFIFO,
        tech         => memtech,
        scantest     => 0,
        techfifo     => CFG_SPWRTR_TECHFIFO,
        ft           => CFG_SPWRTR_FT,
        spwen        => 1,              -- Enable spacewire ports
        ambaen       => 1,              -- Enable AMBA interfaces
        fifoen       => 0,              -- Disable FIFO interfaces
        spwports     => CFG_SPWRTR_SPWPORTS,
        ambaports    => CFG_SPWRTR_AMBAPORTS,  -- Number of AMBA ports
        fifoports    => 0,              -- Number of FIFO ports
        arbitration  => CFG_SPWRTR_ARB,
        rmap         => CFG_SPWRTR_RMAP,
        rmapcrc      => CFG_SPWRTR_RMAPCRC,
        fifosize2    => CFG_SPWRTR_FIFO2,
        almostsize   => 1,              -- Only used for FIFO ports
        rxunaligned  => CFG_SPWRTR_RXUNAL,
        rmapbufs     => CFG_SPWRTR_RMAPBUF,
        dmachan      => CFG_SPWRTR_DMACHAN,
        hindex       => SPW_HMINDEX,              -- Starting index
        pindex       => 0,             -- Starting index
        paddr        => SPW_PADDR,-- Starting base address
        pmask        => SPW_PMASK,
        pirq         => SPW_PIRQ, -- Starting IRQ
        ahbslven     => 1,              -- Disabled AMBA port
        cfghindex    => SPW_HSINDEX,
        cfghaddr     => SPW_HADDR,
        cfghmask     => SPW_HMASK,
        timerbits    => CFG_SPWRTR_TIMERBITS,
        pnp          => CFG_SPWRTR_PNP,
        autoscrub    => CFG_SPWRTR_AUTOSCRUB,
        sim          => 0,              -- Simulation mode, not used
        dualport     => 0,
        charcntbits  => 0,              -- Character counters disabled
        pktcntbits   => 0,              -- Packet counters disabled
        prescalermin => 250,            -- Minimum value for writes to reload reg
        spacewired   => 1,
        interruptdist => 2,
        apbctrl      => 0,
        rmapmaxsize  => 4,
        gpolbits     => 0,
        gpopbits     => 0,
        gpibits      => 0,
        customport   => 0,
        codecclkgate => 0,
        inputtest    => 0,
        spwpnpvendid => 3,
        spwpnpprodid => 16#060#,
        porttimerbits => CFG_SPWRTR_TIMERBITS,
        irqtimerbits => CFG_SPWRTR_TIMERBITS,
        auxtimeen    => 1,
        num_txdesc   => 64,
        num_rxdesc   => 128,
        auxasync     => 0)
      port map(
        rst          => rstn,
        clk          => clkm,
        rst_codec    => (others => '0'), -- Resets generated internally
        clk_codec    => (others => '0'), -- Clockgate generated internally
        rxasyncrst   => (others => '0'), -- Resets generated internally
        rxsyncrst    => (others => '0'), -- Resets generated internally
        rxclk        => rxclko,
        txsyncrst    => (others => '0'), -- Resets generated internally
        txclk        => txclk_array,     -- Only the element 0 will be used (spw_clkl)
        txclkn       => txclkn_array,    -- Only the element 0 will be used (spw_clkln)
        testen       => '0',
        testrst      => '0',
        scanen       => '0',
        testoen      => '0',
        di           => di, 
        dvi          => dvi,
        dconnect     => dconnect,
        dconnect2    => dconnect2,
        dconnect3    => dconnect3,
        do           => do,
        so           => so,
        ahbmi        => sahbmi,
        ahbmo        => sahbmo,
        apbi         => apb1i,
        apbo         => sapbo,
        ahbsi        => ahbsi,
        ahbso        => ahbso(SPW_HSINDEX),
        ri           => ri,
        ro           => ro
        );

    sahbmi <= (others => ahbmi);

    ahbspw: for i in 0 to CFG_SPWRTR_AMBAPORTS-CFG_SPWRTR_AMBAEN generate
      ahbmo(SPW_HMINDEX+i)  <= sahbmo(i);
      apb1o(i)    <= sapbo(i);
    end generate;
    
    -- grspwrouter is configured at implementation time by the VHDL generic
    -- settings above, some configuration is also made via signals:
    -- RMAP is always enabled after reset:
    ri.rmapen       <= (others => '1');
    -- Initialization divisor value for the SpaceWire links:
    ri.idivisor     <= SPW_CLKDIV10;
    -- Drive FIFO interface signals:
    ri.txwrite      <= (others => '0');
    ri.txchar       <= (others => (others => '0'));
    ri.rxread       <= (others => '0');
    -- Per-port tick inputs are not used
    ri.tickin       <= (others => '0');
    ri.timein       <= (others => (others => '0'));
    -- Prescaler default reload value, needs to
    -- be initialized by external entity:
    ri.reload       <= (others => '1');
    -- Individual time default reload value:
    ri.reloadn      <= (others => '1');
    ri.timeren      <= '1';
    -- Enable time-code functionality:
    ri.timecodeen   <= '1';
    -- Lock configuration port accesses from all ports except port 1:
    ri.cfglock      <= '0';
    -- Reset value for selfaddren register bit:
    ri.selfaddren   <= '0';
    -- Reset value for the linkstarteq register bit
    ri.linkstartreq <= (others => '0');
    -- Resetvalue for the autodconnect register bit
    ri.autodconnect <= (others => '0');
    -- Instance ID
    ri.instanceid(7 downto 2) <= conv_std_logic_vector(SPWINSTID, 6);
    ri.instanceid(1) <= '0';
    ri.instanceid(0) <= '0';
    --
    ri.enbridge     <= (others => '0');
    ri.enexttime    <= (others => '0');
    ri.auxtickin        <= '0';
    ri.auxtimeinen      <= '0';
    ri.auxtimein        <= (others => '0');
    ri.irqtimeoutreload <= (others => '1');
    ri.ahbso            <= ahbs_none;
    ri.interruptcodeen  <= '0';
    ri.pnpen            <= '1';
    ri.timecodefilt     <= '0';
    ri.interruptfwd     <= '0';
    ri.spillifnrdy      <= (others => '0');
    ri.timecoderegen    <= '1';
    ri.gpi              <= (others => '0');
    ri.staticrouteen    <= '1';
    ri.spwclklock       <= '1';
    ri.irqgenreload     <= (others => '0');
    ri.interruptmode    <= '0';
    -- input timing testing
    ri.testd            <= (others => '0');
    ri.tests            <= (others => '0');
    ri.testinput        <= '0';
  end generate spwrtr;




end rtl;
