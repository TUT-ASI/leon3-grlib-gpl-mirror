------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
use work.cfgmap.all;


entity noelvmp is

  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;
    SIMULATION              : integer := 0
    -- pragma translate_off
    ; ramfile               : string  := "ram.srec"
    ; romfile               : string  := "prom.srec"
    -- pragma translate_on
  );

  port (
    -- Clock and Reset
    reset       : in    std_ulogic;
    clk300p     : in    std_ulogic;  -- 300 MHz clock
    clk300n     : in    std_ulogic;  -- 300 MHz clock
--    clk         : in    std_ulogic;        -- old orig.

    -- GPIOs
--    gpio        : inout std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
    led         : out   std_logic_vector ( 1 downto 0 );

    -- UART
    -- uart_rx     : in    std_ulogic;
    -- uart_tx     : out   std_ulogic;
    -- uart_ctsn   : in    std_ulogic;
    -- uart_rtsn   : out   std_ulogic;

    -- Debug UART
    duart_rx    : in    std_ulogic;
    duart_tx    : out   std_ulogic

    -- Debug
    -- dmen        : in    std_ulogic;
    -- dmbreak     : in    std_ulogic;
    -- dmreset     : out   std_ulogic;
    -- cpu0errn    : out   std_ulogic

  );
end entity noelvmp;


architecture rtl of noelvmp is

  -- Versal CIPS and clock wizard Block Design
  component versal_bd
    port (
      BSCAN_USER1_capture : out STD_LOGIC;
      BSCAN_USER1_drck : out STD_LOGIC;
      BSCAN_USER1_reset : out STD_LOGIC;
      BSCAN_USER1_runtest : out STD_LOGIC;
      BSCAN_USER1_sel : out STD_LOGIC;
      BSCAN_USER1_shift : out STD_LOGIC;
      BSCAN_USER1_tck : out STD_LOGIC;
      BSCAN_USER1_tdi : out STD_LOGIC;
      BSCAN_USER1_tdo : in STD_LOGIC;
      BSCAN_USER1_tms : out STD_LOGIC;
      BSCAN_USER1_update : out STD_LOGIC;
      BSCAN_USER2_capture : out STD_LOGIC;
      BSCAN_USER2_drck : out STD_LOGIC;
      BSCAN_USER2_reset : out STD_LOGIC;
      BSCAN_USER2_runtest : out STD_LOGIC;
      BSCAN_USER2_sel : out STD_LOGIC;
      BSCAN_USER2_shift : out STD_LOGIC;
      BSCAN_USER2_tck : out STD_LOGIC;
      BSCAN_USER2_tdi : out STD_LOGIC;
      BSCAN_USER2_tdo : in STD_LOGIC;
      BSCAN_USER2_tms : out STD_LOGIC;
      BSCAN_USER2_update : out STD_LOGIC;
      pl0_ref_clk_0 : out STD_LOGIC;
      pl0_resetn : out STD_LOGIC
    );
  end component versal_bd;

  -----------------------------------------------------
  -- Constants ----------------------------------------
  -----------------------------------------------------

  constant OEPOL        : integer := padoen_polarity(padtech);

  constant BOARD_FREQ   : integer := 300000; -- input frequency in KHz
  constant CPU_FREQ     : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV; -- cpu frequency in KHz


  -------------------------------------

  -- Misc
  signal vcc            : std_ulogic;
  signal gnd            : std_ulogic;

  -- Clocks and Reset
  signal clkm           : std_ulogic
  -- pragma translate_off
  := '0'
  -- pragma translate_on
  ;

  signal resetn_2       : std_ulogic ; -- not orig
  signal rstn_2         : std_ulogic ; -- not orig
  signal rstraw         : std_ulogic ; -- not orig

  signal resetn         : std_ulogic;
  signal rstn           : std_ulogic;

  signal cgi            : clkgen_in_type;
  signal cgo            : clkgen_out_type;
  signal lock           : std_ulogic;
  signal lclk           : std_ulogic;

  -- UART
  signal luart_rx       : std_logic_vector(0 downto 0);
  signal luart_ctsn     : std_logic_vector(0 downto 0);
  signal luart_tx       : std_logic_vector(0 downto 0);
  signal luart_rtsn     : std_logic_vector(0 downto 0);
  signal lduart_rx      : std_ulogic;
  signal lduart_tx      : std_ulogic;

  -- GPIO
  signal gpio_i         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  signal gpio_o         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  signal gpio_oe        : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);

  -- JTAG
  signal tap_tck   : std_ulogic;
  signal tap_tckn  : std_ulogic;
  signal tap_tdi   : std_ulogic;
  signal tap_inst  : std_logic_vector(7 downto 0);
  signal tap_asel  : std_ulogic;
  signal tap_dsel  : std_ulogic;
  signal tap_reset : std_ulogic;
  signal tap_capt  : std_ulogic;
  signal tap_shift : std_ulogic;
  signal tap_upd   : std_ulogic;
  signal tap_en    : std_ulogic;
  signal tap_tdo   : std_ulogic;

  -- Ethernet
  signal ethi           : eth_in_type;
  signal etho           : eth_out_type;
  signal eth_apbi       : apb_slv_in_type;
  signal eth_apbo       : apb_slv_out_type := apb_none;

  -- Memory
  signal mem_aximi      : axi_somi_type;
  signal mem_aximo      : axi_mosi_type;
  signal mem_ahbsi0     : ahb_slv_in_type;
  signal mem_ahbso0     : ahb_slv_out_type;
  signal mem_apbi0      : apb_slv_in_type;
  signal mem_apbo0      : apb_slv_out_type;
  signal rom_ahbsi1     : ahb_slv_in_type;
  signal rom_ahbso1     : ahb_slv_out_type;

  signal ldmen          : std_logic;
  signal ldmbreak       : std_logic;
  signal ldmreset       : std_logic;
  signal lcpu0errn      : std_logic;

  -- CIPS

  signal BSCAN_USER1_capture : STD_LOGIC;
  signal BSCAN_USER1_drck    : STD_LOGIC;
  signal BSCAN_USER1_reset   : STD_LOGIC;
  signal BSCAN_USER1_runtest : STD_LOGIC;
  signal BSCAN_USER1_sel     : STD_LOGIC;
  signal BSCAN_USER1_shift   : STD_LOGIC;
  signal BSCAN_USER1_tck     : STD_LOGIC;
  signal BSCAN_USER1_tdi     : STD_LOGIC;
  signal BSCAN_USER1_tms     : STD_LOGIC;
  signal BSCAN_USER1_tdo     : STD_LOGIC;
  signal BSCAN_USER1_update  : STD_LOGIC;

  signal BSCAN_USER2_capture : STD_LOGIC;
  signal BSCAN_USER2_drck    : STD_LOGIC;
  signal BSCAN_USER2_reset   : STD_LOGIC;
  signal BSCAN_USER2_runtest : STD_LOGIC;
  signal BSCAN_USER2_sel     : STD_LOGIC;
  signal BSCAN_USER2_shift   : STD_LOGIC;
  signal BSCAN_USER2_tck     : STD_LOGIC;
  signal BSCAN_USER2_tdi     : STD_LOGIC;
  signal BSCAN_USER2_tms     : STD_LOGIC;
  signal BSCAN_USER2_tdo     : STD_LOGIC;
  signal BSCAN_USER2_update  : STD_LOGIC;

begin

  vcc         <= '1';
  gnd         <= '0';


  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------

  cgi.pllctrl <= "00";
  cgi.pllrst  <= resetn;

  cpu_rst_pad_sim : if ( simulation = 1 ) generate

    lock   <= cgo.clklock;

    clk_pad_ds : clkpad_ds
      generic map ( tech    => padtech,
                    level   => sstl,
                    voltage => x15v
                  )
      port map ( clk300p,
                 clk300n,
                 lclk
               );

   clkgen0 : clkgen        -- clock generator
      generic map ( tech      => clktech        ,
                    clk_mul   => 4              ,
                    clk_div   => 12             ,
                    sdramen   => CFG_MCTRL_SDEN ,
                    noclkfb   => CFG_CLK_NOFB   ,
                    pcien     => 0              ,
                    pcidll    => 0              ,
                    pcisysclk => 0              ,
                    freq      => BOARD_FREQ
                  )

      port map ( lclk,
                 lclk,
                 clkm,
                 open,
                 open,
                 open,
                 open,
                 cgi,
                 cgo,
                 open,
                 open,
                 open
               );


    reset_pad_org : inpad
      generic map (tech => padtech)
      port map ( reset,
                 resetn
               );


    reset_pad_new : inpad
      generic map ( tech    => padtech,
                    level   => cmos,
                    voltage => x18v
                  )
      port map ( reset,
                 resetn_2
               );


    rst0 : rstgen        -- reset generator
      generic map ( acthigh => 0,
                    syncin  => 0
                  )

      port map ( resetn_2 ,
                 clkm     ,
                 lock   ,
                 rstn   ,
                 rstraw
               );

  end generate cpu_rst_pad_sim;


  synth_BD : if ( simulation = 0 ) generate

    versal_bd_ints : versal_bd
      port map (
        pl0_ref_clk_0       => clkm,
        pl0_resetn          => rstn,

        BSCAN_USER1_capture => BSCAN_USER1_capture,
        BSCAN_USER1_drck    => BSCAN_USER1_drck,
        BSCAN_USER1_reset   => BSCAN_USER1_reset,
        BSCAN_USER1_runtest => BSCAN_USER1_runtest,
        BSCAN_USER1_sel     => BSCAN_USER1_sel,
        BSCAN_USER1_shift   => BSCAN_USER1_shift,
        BSCAN_USER1_tck     => BSCAN_USER1_tck,
        BSCAN_USER1_tdi     => BSCAN_USER1_tdi,
        BSCAN_USER1_tms     => BSCAN_USER1_tms,
        BSCAN_USER1_tdo     => BSCAN_USER1_tdo,
        BSCAN_USER1_update  => BSCAN_USER1_update,

        BSCAN_USER2_capture => BSCAN_USER2_capture,
        BSCAN_USER2_drck    => BSCAN_USER2_drck,
        BSCAN_USER2_reset   => BSCAN_USER2_reset,
        BSCAN_USER2_runtest => BSCAN_USER2_runtest,
        BSCAN_USER2_sel     => BSCAN_USER2_sel,
        BSCAN_USER2_shift   => BSCAN_USER2_shift,
        BSCAN_USER2_tck     => BSCAN_USER2_tck,
        BSCAN_USER2_tdi     => BSCAN_USER2_tdi,
        BSCAN_USER2_tms     => BSCAN_USER2_tms,
        BSCAN_USER2_tdo     => BSCAN_USER2_tdo,
        BSCAN_USER2_update  => BSCAN_USER2_update
        );

  end generate synth_BD;

  -- JTAG interface
  tap_tck         <= bscan_user1_tck;
  tap_tckn        <= not bscan_user1_tck;
  tap_tdi         <= bscan_user1_tdi     when bscan_user1_sel = '1' else bscan_user2_tdi;
  tap_inst        <= (others => '0');
  tap_asel        <= bscan_user1_sel;
  tap_dsel        <= bscan_user2_sel;
  tap_reset       <= bscan_user1_reset   when bscan_user1_sel = '1' else bscan_user2_reset;
  tap_capt        <= bscan_user1_capture when bscan_user1_sel = '1' else bscan_user2_capture;
  tap_shift       <= bscan_user1_shift   when bscan_user1_sel = '1' else bscan_user2_shift;
  tap_upd         <= bscan_user1_update  when bscan_user1_sel = '1' else bscan_user2_update;
  bscan_user1_tdo <= tap_tdo;
  bscan_user2_tdo <= tap_tdo;

  ----------------------------------------------------------------------
  ---  LEDs and BUTTONs ------------------------------------------------
  ----------------------------------------------------------------------

  dsuact_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map ( led(0),
               vcc );


  led1_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map ( led(1),
               gnd );

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
    devid       => NOELV_SOC,
    disas       => disas)
  port map (
    -- Clock & reset
    clkm        => clkm,
    resetn      => rstn,
    lock        => lock,
    rstno       => open,

    -- misc
    dmen        => '1'  ,
    dmbreak     => '0'  ,
    dmreset     => open ,
    cpu0errn    => open ,

    -- GPIO
    gpio_i      => gpio_i,
    gpio_o      => gpio_o,
    gpio_oe     => gpio_oe,

    -- UART
    uart_rx     => luart_rx,
    uart_ctsn   => luart_ctsn,
    uart_tx     => luart_tx,
    uart_rtsn   => luart_rtsn,

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
    eth_apbi    => eth_apbi,
    eth_apbo    => eth_apbo,

    -- Debug UART
    duart_rx    => lduart_rx,
    duart_tx    => lduart_tx,

    -- Debug JTAG
    tap_tck        => tap_tck,
    tap_tckn       => tap_tckn,
    tap_tdi        => tap_tdi,
    tap_inst       => tap_inst,
    tap_asel       => tap_asel,
    tap_dsel       => tap_dsel,
    tap_reset      => tap_reset,
    tap_capt       => tap_capt,
    tap_shift      => tap_shift,
    tap_upd        => tap_upd,
    tap_en         => tap_en,
    tap_tdo        => tap_tdo

  );


  -- dmen_pad : inpad
  --   generic map (tech => padtech)
  --   port map (dmen, ldmen);

  -- dmbreak_pad : inpad
  --   generic map (tech => padtech)
  --   port map (dmbreak, ldmbreak);

  -- dmreset_pad : outpad
  --   generic map (tech => padtech)
  --   port map (dmreset, ldmreset);

  -- errorn_pad : odpad
  --   generic map (tech => padtech, oepol => OEPOL)
  --   port map (cpu0errn, lcpu0errn);


  -----------------------------------------------------------------------------
  -- Debug UART / UART --------------------------------------------------------
  -----------------------------------------------------------------------------

  -- uart_rx_pad : inpad
  --   generic map (tech => padtech)
  --   port map (uart_rx, luart_rx(0));

  -- uart_tx_pad : outpad
  --   generic map (tech => padtech)
  --   port map (uart_tx, luart_tx(0));

  -- uart_ctsn_pad : inpad
  --   generic map (tech => padtech)
  --   port map (uart_ctsn, luart_ctsn(0));

  -- uart_rtsn_pad : outpad
  --   generic map (tech => padtech)
  --   port map (uart_rtsn, luart_rtsn(0));


  duart_rx_pad : inpad
    generic map (tech => padtech)
    port map (duart_rx, lduart_rx);

  duart_tx_pad : outpad
    generic map (tech => padtech)
    port map (duart_tx, lduart_tx);


  -----------------------------------------------------------------------------
  -- Memory Controller --------------------------------------------------------
  -----------------------------------------------------------------------------

  -- No APB interface on memory controller
  mem_apbo0    <= apb_none;


  -- On-chip memory
  mem_gen : if (SIMULATION = 0) generate

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
          kbytes      => 1024
        )

        port map (
          rstn,
          clkm,
          mem_ahbsi0,
          mem_ahbso0
        );

    end generate ahb_mem_gen;

  end generate mem_gen;


  -- Simulation module
  -- pragma translate_off
  sim_mem_gen : if (SIMULATION = 1) generate

    axi_mem_gen : if (CFG_L2_AXI = 1) generate

      mig_axiram : aximem
        generic map (
          fname   => ramfile,
          axibits => AXIDW,
          rstmode => 0
        )

        port map (
          clk   => clkm,
          rst   => rstn,
          axisi => mem_aximo,
          axiso => mem_aximi
        );

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
          fname    => ramfile
        )

        port map(
          rst     => rstn,
          clk     => clkm,
          ahbsi   => mem_ahbsi0,
          ahbso   => mem_ahbso0
        );

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
    end generate rom32;


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
    end generate rom64;


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
    end generate rom128;

  end generate prom_gen;


  -- pragma translate_off
  sim_prom_gen : if (SIMULATION = 1) generate

    mig_ahbram : ahbram_sim
      generic map (
        hindex   => 1,
        haddr    => ROM_HADDR,
        hmask    => ROM_HMASK,
        tech     => 0,
        kbytes   => 1024,
        pipe     => 0,
        maccsz   => AHBDW,
        fname    => romfile
      )

      port map(
        rst     => rstn,
        clk     => clkm,
        ahbsi   => rom_ahbsi1,
        ahbso   => rom_ahbso1);

  end generate sim_prom_gen;
  -- pragma translate_on


-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
    generic map(
      msg1    => "NOELV/GRLIB Generic Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
      );
-- pragma translate_on


end architecture rtl;
