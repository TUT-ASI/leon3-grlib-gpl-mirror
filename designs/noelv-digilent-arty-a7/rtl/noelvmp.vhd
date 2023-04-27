------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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
use gaisler.noelv.all;

--pragma translate_off
use gaisler.sim.all;
--pragma translate_on

use work.config.all;
use work.config_local.all;
use work.rev.REVISION;
use work.cfgmap.all;

entity noelvmp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;     -- Enable disassembly to console
    SIMULATION              : integer := 0
    -- pragma translate_off 
    + CFG_MIG_7SERIES_MODEL
    ; ramfile               : string  := "ram.srec"
    ; romfile               : string  := "prom.srec"
    -- pragma translate_on
    );
  port (
    CLK100MHZ          : in    std_ulogic;
    -- LEDs. 0: off, 1: on
    led                : out   std_logic_vector(3 downto 0);
    -- Buttons 0: not pressed, 1: pressed
    btn                : in    std_logic_vector(3 downto 0);
    -- Switches
    sw                 : in    std_logic_vector(3 downto 0);
    -- PMOD-JA
    ja                 : inout std_logic_vector(7 downto 0);
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
  constant BOARD_FREQ : integer := 100000;                                -- CLK input frequency in KHz
  -- cpu frequency in KHz
  function CPU_FREQ return integer is
  begin
    if CFG_MIG_7SERIES = 1 then
      return BOARD_FREQ * 10 / 6 / 2;
    end if;
    return BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;
  end;
  constant OEPOL  : integer := padoen_polarity(padtech);
  constant oeon   : std_logic := conv_std_logic_vector(OEPOL,1)(0);
  constant oeoff  : std_logic := not conv_std_logic_vector(OEPOL,1)(0);

  -------------------------------------
  -- Misc
  signal vcc            : std_ulogic;
  signal gnd            : std_ulogic;
  signal stati          : ahbstat_in_type;
  -- Clock & Reaset
  signal rstn               : std_ulogic;
  signal resetn             : std_ulogic;
  signal reset_button       : std_ulogic;
  signal lock        : std_logic;
  signal pll_locked         : std_ulogic;
  signal mmcm_locked        : std_ulogic;
  signal clkinmig           : std_logic;
  signal ui_clk         : std_ulogic;
  signal eth_ref_clki       : std_ulogic;
  signal clkref, calib_done, migrstn : std_logic;
  signal clkm_gen, clkm_mig : std_ulogic;
  signal clkm : std_ulogic
  -- pragma translate_off 
  := '0'
  -- pragma translate_on
  ;

  -- UART
  signal dsu_sel        : std_ulogic;
  signal uart_rx    : std_logic_vector(0 downto 0);
  signal uart_ctsn  : std_logic_vector(0 downto 0);
  signal uart_tx    : std_logic_vector(0 downto 0);
  signal uart_rtsn  : std_logic_vector(0 downto 0);
  signal duart_rx   : std_ulogic;
  signal duart_tx   : std_ulogic;
  -- GPIO
  signal gpio_i         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  signal gpio_o         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  signal gpio_oe        : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  -- JTAG
  signal tck, tms, tdi, tdo : std_ulogic;
  -- RISC-V JTAG
  signal jtag_rv_tck    : std_ulogic := '0';
  signal jtag_rv_tms    : std_ulogic := '0';
  signal jtag_rv_tdi    : std_ulogic := '0';
  signal jtag_rv_tdo    : std_ulogic;
  -- Ethernet
  signal ethi : eth_in_type;
  signal etho : eth_out_type;

  -- Memory
  signal mem_aximi      : axi_somi_type;
  signal mem_aximo      : axi_mosi_type;
  signal mem_ahbsi0     : ahb_slv_in_type;
  signal mem_ahbso0     : ahb_slv_out_type;
  signal mem_apbi0      : apb_slv_in_type;
  signal mem_apbo0      : apb_slv_out_type;
  signal rom_ahbsi1     : ahb_slv_in_type;
  signal rom_ahbso1     : ahb_slv_out_type;

  signal uart_rx_int    : std_ulogic; 
  signal uart_tx_int    : std_ulogic; 
  signal uart_ctsn_int  : std_ulogic;
  signal uart_rtsn_int  : std_ulogic;

  signal dmen           : std_logic;
  signal dmbreak        : std_logic;
  signal dmreset        : std_logic;
  signal cpu0errn       : std_logic;
begin

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------
  vcc         <= '1';
  gnd         <= '0';

  rst_pad : inpad generic map (tech => padtech)
    port map (btn(0), reset_button);

  -- Reset button is active high
  resetn <= not reset_button;

  rst1 : rstgen
    --port map (resetn, clkm, '1', migrstn, open);
    port map (resetn, clkm, pll_locked, migrstn, open);

  clockers0 : entity work.clockers_mig
  port map (
    rstn        => resetn,  --rstnraw,
    clkin       => CLK100MHZ,
    mig_clkref  => clkref,
    mig_clk     => clkinmig,
    eth_ref     => eth_ref_clki,
    clkm        => clkm_gen,
    locked      => pll_locked
  );
  
  --lock <= calib_done and pll_locked and mmcm_locked;
  lock <= calib_done and pll_locked;

  --led(4) <= calib_done;
  --led(5) <= lock;
  --led(6) <= reset_button;
  --led(7) <= rstn;

  ----------------------------------------------------------------------
  ---  NOEL-V SUBSYSTEM ------------------------------------------------
  ----------------------------------------------------------------------

  core0 : entity work.noelvcore
  generic map (
    fabtech     => CFG_FABTECH,
    memtech     => CFG_MEMTECH,
    padtech     => CFG_PADTECH,
    clktech     => CFG_CLKTECH,
    cpu_freq    => CPU_FREQ,
    devid       => NOELV_DIGILENT_ARTY,
    disas       => disas)
  port map (
    -- Clock & reset
    clkm        => clkm, 
    resetn      => resetn,
    lock        => lock,
    rstno       => rstn,
    -- misc
    dmen        => dmen,
    dmbreak     => dmbreak,
    dmreset     => dmreset,
    cpu0errn    => cpu0errn,
    -- GPIO
    gpio_i      => gpio_i,
    gpio_o      => gpio_o,
    gpio_oe     => gpio_oe,
    -- UART
    uart_rx     => uart_rx,
    uart_ctsn   => uart_ctsn,
    uart_tx     => uart_tx,
    uart_rtsn   => uart_rtsn,
    -- Memory controller
    mem_aximi   => mem_aximi,
    mem_aximo   => mem_aximo,
    mem_ahbsi0  => mem_ahbsi0,
    mem_ahbso0  => mem_ahbso0,
    mem_apbi0   => mem_apbi0, 
    mem_apbo0   => mem_apbo0, 
    -- PROM controller
    rom_ahbsi1  => rom_ahbsi1,
    rom_ahbso1  => rom_ahbso1,
    -- Ethernet PHY
    ethi        => ethi,
    etho        => etho,
    eth_apbi    => open,
    eth_apbo    => apb_none,
    -- Debug UART
    duart_rx    => duart_rx,
    duart_tx    => duart_tx,
    -- Debug JTAG
    tck         => tck,
    tms         => tms,
    tdi         => tdi,
    tdo         => tdo,
    -- RISC-V JTAG
    jtag_rv_tck => jtag_rv_tck,
    jtag_rv_tms => jtag_rv_tms,
    jtag_rv_tdi => jtag_rv_tdi,
    jtag_rv_tdo => jtag_rv_tdo
  );

  --errorn_pad : odpad
  --  generic map (tech => padtech, oepol => OEPOL)
  --  port map (errorn, cpu0errn);

  --dsuen_pad : inpad
  --  generic map (tech => padtech, level => cmos, voltage => x12v)
  --  port map (switch(2), dmen);
  dmen <= '1';

  -- Button 2,3,4 are still to be assigned
  --dsubre_pad : inpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (button(4), dmbreak);
  dmbreak <= '0';

  --ndreset_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(4), dsuo.ndmreset);

  --dmactive_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(5), dsuo.dmactive);

  -----------------------------------------------------------------------------
  -- Debug UART / UART --------------------------------------------------------
  -----------------------------------------------------------------------------
  sw4_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x12v)
    port map (sw(3), dsu_sel);

  uart_tx_int     <= duart_tx       when dsu_sel = '1' else uart_tx(0);
  uart_rtsn_int   <= '1'            when dsu_sel = '1' else uart_rtsn(0);  
  uart_rx(0)      <= uart_rx_int    when dsu_sel = '0' else '1';
  uart_ctsn(0)    <= uart_ctsn_int  when dsu_sel = '0' else '1';
  duart_rx        <= uart_rx_int    when dsu_sel = '1' else '1';
  
  dsurx_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (uart_txd_in, uart_rx_int);
  dsutx_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (uart_rxd_out, uart_tx_int);

  -----------------------------------------------------------------------------
  -- DDR4 Memory Controller (MIG) ---------------------------------------------
  -----------------------------------------------------------------------------
  mig_gen : if (CFG_MIG_7SERIES = 1) and (SIMULATION = 0) and (CFG_L2_AXI = 1) generate
    -- No APB interface on memory controller  
    mem_apbo0    <= apb_none;

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
        amba_rstn       => rstn,
        amba_clk        => clkm
        );
    clkm <= clkm_gen;
  end generate mig_gen;
  
  mig_ahb_gen : if (CFG_MIG_7SERIES = 1) and (SIMULATION = 0) and (CFG_L2_AXI /= 1) generate
    ddrc:  entity work.ahb2axi_mig3_arty_a7
        generic map (
          hindex    => MEM_HSINDEX,
          haddr     => MEM_HADDR,
          hmask     => MEM_HMASK,
          pindex    => MEM_PINDEX,
          paddr     => MEM_PADDR,
          ahbendian => 1-CFG_L2_EN)
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
          ahbsi           => mem_ahbsi0,
          ahbso           => mem_ahbso0,
          apbi            => mem_apbi0,
          apbo            => mem_apbo0,
          calib_done      => calib_done,
          rst_n_syn       => migrstn,
          amba_rstn       => rstn,
          clk_amba        => clkm_gen,
          sys_clk_i       => clkinmig,
          clk_ref_i       => clkref,
          ui_clk          => clkm_mig,
          ui_clk_sync_rst => open
          );
    clkm <= clkm_gen;
  end generate;

  no_mig_gen : if (CFG_MIG_7SERIES = 0) generate  
    -- Tie-Off DDR4 Signals
    --ddr3_addr       <= (others => '0');
    --ddr3_we_n       <= '0';
    --ddr3_cas_n      <= '0';
    --ddr3_ras_n      <= '0';
    --ddr3_ba         <= (others => '0');
    --ddr3_cke        <= (others => '0');
    ----ddr3_cs_n       <= (others => '0');
    --ddr3_dm         <= (others => 'Z');
    --ddr3_dq         <= (others => 'Z');
    --ddr3_dqs_p      <= (others => 'Z');
    --ddr3_dqs_n      <= (others => 'Z');
    --ddr3_odt        <= (others => '0');
    --ddr3_reset_n    <= '1';
    --ddr3_ck_p       <= (others => '0');
    --ddr3_ck_n       <= (others => '0');
    
    calib_done  <= '1';
    mmcm_locked <= '1';

    --ddr3_ck_outpad : outpad_ds
    --  generic map (tech => padtech, level => sstl12_dci, voltage => x12v)
    --  port map (ddr3_ck_n(0), ddr3_ck_p(0), gnd, gnd);

    -- Seems impossible to get Vivado to accept outpad_ds as a differential 
    -- clock output. Instantiate a dummy mig.
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
        ui_clk          => open,
        ui_clk_sync_rst => open,
        --
        aximi           => open,
        aximo           => mem_aximo,
        --
        calib_done      => open,
        mmcm_locked     => open,
        sys_clk_i       => clkinmig,
        clk_ref_i       => clkref,
        rst_n_syn       => migrstn,
        amba_rstn       => rstn,
        amba_clk        => clkm
        );

    clkm      <= clkm_gen;
  end generate no_mig_gen;
  
  -- AHBRAM
  no_mig_mem_gen : if (CFG_MIG_7SERIES = 0) generate
    -- No APB interface on memory controller  
    mem_apbo0    <= apb_none;

    axi_mem_gen : if (CFG_L2_AXI = 1) generate
      mem_ahbso0 <= ahbs_none;
    end generate axi_mem_gen;

    ahb_mem_gen : if (CFG_L2_AXI = 0) generate
      ahbram1 : ahbram 
        generic map (
          hindex      => 0,
          haddr       => L2C_HADDR,
          hmask       => L2C_HMASK,
          tech        => CFG_MEMTECH,
          kbytes      => 256)
        port map (
          rstn,
          clkm,
          mem_ahbsi0,
          mem_ahbso0);
    end generate ahb_mem_gen;
  end generate no_mig_mem_gen;

  -- Simulation module
  -- pragma translate_off
  sim_mem_gen : if (CFG_MIG_7SERIES = 1) and (SIMULATION = 1) generate
    -- No APB interface on memory controller  
    mem_apbo0    <= apb_none;

    calib_done  <= '1';
    mmcm_locked <= '1';
    clkm        <= clkm_gen;

    axi_mem_gen : if (CFG_L2_AXI = 1) generate
      mig_axiram : aximem
        generic map (
          fname   => ramfile,
          axibits => AXIDW,
          rstmode => 0)
        port map (
          clk   => clkm,
          rst   => rstn,
          axisi => mem_aximo,
          axiso => mem_aximi);

      mem_ahbso0 <= ahbs_none;
    end generate axi_mem_gen;

    ahb_mem_gen : if (CFG_L2_AXI = 0) generate
      mig_ahbram : ahbram_sim
        generic map (
          hindex   => 0,
          haddr    => L2C_HADDR,
          hmask    => L2C_HMASK,
          tech     => 0,
          kbytes   => 1024,
          pipe     => 0,
          maccsz   => AHBDW,
          fname    => ramfile)
        port map(
          rst     => rstn,
          clk     => clkm,
          ahbsi   => mem_ahbsi0,
          ahbso   => mem_ahbso0);
    end generate ahb_mem_gen;
  end generate sim_mem_gen;
  -- pragma translate_on

  -----------------------------------------------------------------------
  --  PROM
  -----------------------------------------------------------------------

  prom_gen : if (SIMULATION = 0) generate
    rom32 : if CFG_AHBDW = 32 generate
      brom : entity work.ahbrom
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi1,
          ahbso   => rom_ahbso1);
    end generate;
    rom64 : if CFG_AHBDW = 64 generate
      brom : entity work.ahbrom64
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi1,
          ahbso   => rom_ahbso1);
    end generate;
    rom128 : if CFG_AHBDW = 128 generate
      brom : entity work.ahbrom128
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi1,
          ahbso   => rom_ahbso1);
    end generate;
  end generate prom_gen;

  -- pragma translate_off
  sim_prom_gen : if (SIMULATION /= 0) generate
    mig_ahbram : ahbram_sim
      generic map (
        hindex   => 1,
        haddr    => ROM_HADDR,
        hmask    => ROM_HMASK,
        tech     => 0,
        kbytes   => 1024,
        pipe     => 0,
        maccsz   => AHBDW,
        fname    => romfile)
      port map(
        rst     => rstn,
        clk     => clkm,
        ahbsi   => rom_ahbsi1,
        ahbso   => rom_ahbso1);
  end generate sim_prom_gen;
  -- pragma translate_on

-----------------------------------------------------------------------
-- GPIO                                                                
-----------------------------------------------------------------------
  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate

    gpled_pads : for i in 0 to 3 generate
      gpled_pad : outpad
        generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (led(i), gpio_o(i+16));
    end generate gpled_pads;

    gpsw_pads : for i in 0 to 2 generate
      gpsw_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (sw(i), gpio_i(i));
    end generate gpsw_pads;
    gpio_i(3) <= dsu_sel;

    gpb_pads : for i in 1 to 3 generate
      gpb_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (btn(i), gpio_i(i+4));
    end generate gpb_pads;

    --pio_pads : for i in 0 to 7 generate
    --  gpio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x12v, strength => 8)
    --    port map (gpio(i), gpioo.dout(i+8), gpioo.oen(i+8), gpioi.din(i+8));
    --end generate;

  end generate;

-----------------------------------------------------------------------
-- ETHERNET PHY
-----------------------------------------------------------------------

  eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC

    pci_p_clk5_r_pad : outpad generic map (tech => padtech)
      port map (eth_ref_clk, eth_ref_clki);

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

    noeth0 : if CFG_GRETH = 0 generate
      -- TODO:
    end generate;
-----------------------------------------------------------------------
-- RISC-V JTAG
-----------------------------------------------------------------------
  --     PMOD-JA
  -------------------
  -- TDO  1 |  7  TDI
  -- NC   2 |  8  TMS
  -- TCK  3 |  9  NC
  -- NC   4 | 10  NC
  -- GND  5 | 11  GND
  -- VCC  6 | 12  VCC
  -------------------

  rvjtag : if CFG_LOCAL_AHB_JTAG_RV = 1 generate
    --tdo_pad : iopad generic map (tech => padtech)
    --  port map (ja(0), jtag_rv_tdo, oeon, open);
    tdo_pad : outpad generic map (tech => padtech)
        port map (ja(0), jtag_rv_tdo);
    
    --ntrst_pad : iopad generic map (tech => padtech)
    --  port map (ja(1), gnd, oeoff, open);
    
    --tck_pad : iopad generic map (tech => padtech)
    --  port map (ja(2), gnd, oeoff, jtag_rv_tck);
    tck_pad : clkpad generic map (tech => padtech, arch => 2)
      port map (ja(2), jtag_rv_tck);
    
    --nc3_pad : iopad generic map (tech => padtech)
    --  port map (ja(3), gnd, oeoff, open);
    
    tdi_pad : iopad generic map (tech => padtech)
      port map (ja(4), gnd, oeoff, jtag_rv_tdi);
    tms_pad : iopad generic map (tech => padtech)
      port map (ja(5), gnd, oeoff, jtag_rv_tms);
    
      --nrst_pad : iopad generic map (tech => padtech)
    --  port map (ja(6), gnd, oeoff, open);
    --nc7_pad : iopad generic map (tech => padtech)
    --  port map (ja(7), gnd, oeoff, open);

  end generate;

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


