-----------------------------------------------------------------------------
--  LEON3 Demonstration design test bench
--  Copyright (C) 2022 Cobham Gaisler
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
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.testlib.compare;
use grlib.testlib.check;
use grlib.testlib.synchronise;
use grlib.testlib.tinitialise;
use grlib.testlib.tintermediate;
use grlib.testlib.tterminate;
use grlib.testlib.gen_rand_int;
library gaisler;
use gaisler.jtagtst.all;
use gaisler.sim.all;
library techmap;
use techmap.gencomp.all;
library micron;
use micron.components.all;
use work.debug.all;
use work.config.all;

entity testbench is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    ncpu      : integer := CFG_NCPU;
    disas     : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart   : integer := CFG_DUART;   -- Print UART on console
    pclow     : integer := CFG_PCLOW);
end;

architecture behav of testbench is

  component nand_model 
    port (
      Ce2_n     : in  std_logic;
      Ce3_n     : in  std_logic;
      Ce4_n     : in  std_logic;
      Rb2_n     : out std_logic;
      Rb3_n     : out std_logic;
      Rb4_n     : out std_logic;
      Dq_Io2    : inout std_logic_vector(7 downto 0);
      Cle2      : in  std_logic;
      Ale2      : in  std_logic;
      Clk_We2_n : in  std_logic;
      Wr_Re2_n  : in  std_logic;
      Wp2_n     : in  std_logic;
      Dq_Io     : inout std_logic_vector(7 downto 0);
      Dqs       : inout std_logic;
      Cle       : in  std_logic;
      Ale       : in  std_logic;
      Ce_n      : in  std_logic;
      Clk_We_n  : in  std_logic;
      Wr_Re_n   : in  std_logic;
      Wp_n      : in  std_logic;
      Rb_n      : out std_logic;
      ENi       : in  std_logic;
      ENo       : out std_logic;
      Dqs_c     : inout std_logic;
      Re_c      : in  std_logic );
  end component;

  constant promfile        : string  := "prom.srec";  -- rom contents
  constant ramfile         : string  := "ram.srec";   -- sdram content

  -- The unit for the above quantities is 0.1 ps. Here we use ns as the
  -- unit instead, because that is what gaisler.sim.delay_wire uses.
  constant delay_mc2mem : real := 7.60;
  constant delay_mem2mc : real := 2.25;

  signal error             : std_logic;
  -- Clocks & reset
  signal fpga_pci_clk      : std_logic := '0';
  signal clk_in_125mhz     : std_logic := '0';
  signal CRn               : std_logic;
  signal gsrn              : std_logic := '0';
   
  -- UART
  signal debug_uart_rx     : std_logic;
  signal debug_uart_tx     : std_logic;
  signal eth_mdio : std_logic;
  signal eth_mdc : std_ulogic;

  -- DDR3
  signal ddr3_addr   : std_logic_vector(15 downto 0);
  signal ddr3_ba     : std_logic_vector(2 downto 0);
  signal ddr3_cke    : std_logic_vector(0 downto 0);
  signal ddr3_ck     : std_logic_vector(0 downto 0);
  signal ddr3_ckn    : std_logic;
  signal ddr3_csn    : std_logic_vector(0 downto 0);
  signal ddr3_odt    : std_logic_vector(0 downto 0);
  signal ddr3_casn   : std_logic;
  signal ddr3_rasn   : std_logic;
  signal ddr3_wen    : std_logic;
  signal ddr3_resetn : std_logic;

  -- The memory controller requires a propagation delay of about 7.5 ns
  -- between the control ines (synchronous to CK) and the data lines
  -- (DQ, DQS, and DM).
  signal ddr3_dq, ddr3_dq_del : std_logic_vector(7 downto 0);
  signal ddr3_dqs, ddr3_dqsn, ddr3_dqs_del, ddr3_dqsn_del : std_logic_vector(0 downto 0);
  signal ddr3_dm, ddr3_dm_del : std_logic_vector(0 downto 0);

  -- Ethernet
  signal eth_gtxclk       : std_logic;
  signal eth_txclk        : std_ulogic;
  signal eth_rxclk        : std_ulogic;
  signal eth_rxd          : std_logic_vector(7 downto 0);
  signal eth_rxdv         : std_ulogic;
  signal eth_rxer         : std_ulogic;
  signal eth_col          : std_ulogic;
  signal eth_crs          : std_ulogic;
  signal eth_txd          : std_logic_vector(7 downto 0);
  signal eth_txen         : std_ulogic;
  signal eth_txer         : std_ulogic;
  signal eth0_mdc	       : std_ulogic;
  signal eth0_mdint	     : std_ulogic;
  signal eth0_mdio	       : std_ulogic;
  -- GPIO
  signal fpga_led            : std_logic_vector(3 downto 0);  
  signal gr740_gpio2         : std_logic_vector(4 downto 0);
  -- I2C
  signal i2c_scl_fmc             : std_logic;
  signal i2c_sda_fmc             : std_logic;
  -- Nandflash
  signal Ce2_n             : std_logic;
  signal Ce3_n             : std_logic;
  signal Ce4_n             : std_logic;
  signal Rb2_n             : std_logic;
  signal Rb3_n             : std_logic;
  signal Rb4_n             : std_logic;
  signal Dq_Io2            : std_logic_vector(7 downto 0);
  signal Cle2              : std_logic;
  signal Ale2              : std_logic;
  signal Clk_We2_n         : std_logic;
  signal Wr_Re2_n          : std_logic;
  signal Wp2_n             : std_logic;
  signal Dq_Io             : std_logic_vector(7 downto 0);
  signal Cle               : std_logic;
  signal Ale               : std_logic;
  signal Ce_n              : std_logic;
  signal Clk_We_n          : std_logic;
  signal Wr_Re_n           : std_logic;
  signal Wp_n              : std_logic;
  signal Rb_n              : std_logic;
  signal ENi               : std_logic         := '1';
  signal ENo               : std_logic;
  signal Dqs, Dqs2         : std_logic         := 'Z';
  signal Re_c              : std_logic         := '0';
  signal spw_io_gnd        : std_logic;
  -- PCI arbiter
  signal pci_arb_req       : std_logic_vector(0 to 1);
  signal pci_arb_gnt       : std_logic_vector(0 to 1);
  -- JTAG
  signal tck               : std_logic;
  signal tms               : std_logic;
  signal tdi               : std_logic;
  signal tdo               : std_logic;
  -- SerDes
  signal SD0_TXDP        : std_logic;
  signal SD0_TXDN        : std_logic;
  signal SD2_TXDP        : std_logic;
  signal SD2_TXDN        : std_logic;
  signal SD6_TXDP        : std_logic;
  signal SD6_TXDN        : std_logic;
  signal SD7_TXDP        : std_logic;
  signal SD7_TXDN        : std_logic;
  signal sdq0_refclkp      : std_logic := '0';
  signal sdq0_refclkn      : std_logic := '1';
  signal sdq1_refclkp      : std_logic := '0';
  signal sdq1_refclkn      : std_logic := '1';
  signal sd_ext0_refclkp   : std_logic := '0';
  signal sd_ext0_refclkn   : std_logic := '1';
  signal sd_ext1_refclkp   : std_logic := '0';
  signal sd_ext1_refclkn   : std_logic := '1';

  signal oc_ram_addr       : std_logic_vector(31 downto 0) := X"00000000"; 
  signal apb_addr_0          : std_logic_vector(31 downto 0) := X"00000000"; 
  signal apb_addr_1        : std_logic_vector(31 downto 0) := X"00000000";
  signal apb_addr_2        : std_logic_vector(31 downto 0) := X"00000000";  
  signal ddr3_mem_addr     : std_logic_vector(31 downto 0) := X"00000000"; 
  signal spfi_addr         : std_logic_vector(31 downto 0) := X"00000000"; 
  
  function to_weak(d : std_logic) return std_logic is
    begin
    case d is
      when '1' =>
        return 'H';
      when '0' =>
        return 'L';
      when others =>
        return 'Z';
    end case;
  end function;

  function to_weak(d : std_logic_vector) return std_logic_vector is
    variable v : std_logic_vector(d'range);
    begin
    for i in d'range loop
      v(i) := to_weak(d(i));
    end loop;
    return v;
  end function;

  begin
  -- clock and reset
  gsrn            <= '0', '1' after 200 ns;
  fpga_pci_clk    <= not fpga_pci_clk after 7.576 ns;

  clk_in_125mhz   <= not clk_in_125mhz after 4 ns;
  sdq0_refclkp    <= not sdq0_refclkp after 3.2 ns;
  sdq0_refclkn    <= not sdq0_refclkn after 3.2 ns;
  sdq1_refclkp    <= not sdq1_refclkp after 3.2 ns;
  sdq1_refclkn    <= not sdq1_refclkn after 3.2 ns;
  sd_ext0_refclkp <= not sd_ext0_refclkp after 3.2 ns;
  sd_ext0_refclkn <= not sd_ext0_refclkn after 3.2 ns;
  sd_ext1_refclkp <= not sd_ext1_refclkp after 3.2 ns;
  sd_ext1_refclkn <= not sd_ext1_refclkn after 3.2 ns;

  ddr3_ckn <= not ddr3_ck(0);

  i2c_sda_fmc      <= 'H';
  i2c_scl_fmc      <= 'H';

  d3 : entity work.gr740_mini_board
  generic map (
    fabtech           => fabtech,
    memtech           => memtech,
    padtech           => padtech,
    dbguart           => CFG_DUART,
    simulation        => CFG_SIMULATION,
    ramfile           => ramfile)
  port map (
    clk_in_125mhz     => clk_in_125mhz,
    fpga_pci_clk      => fpga_pci_clk,
    gsrn              => gsrn,
    -- UART
    debug_uart_rx     => debug_uart_rx,
    debug_uart_tx     => debug_uart_tx,      
    -- PCI
    pci_idsel_config  => open,
    pci_ad 	          => open,
    pci_cbe 	        => open,
    pci_frame         => open,
    pci_irdy 	        => open,
    pci_trdy 	        => open,
    pci_devsel        => open,
    pci_stop          => open,
    pci_perr 	        => open,
    pci_par 	        => open,
    pci_serr          => open,  
    pci_host_config   => open,
    pci_66_config	    => open ,
    pci_int	          => open,
    pci_arb_req       => pci_arb_req,
    pci_arb_gnt       => open,
    -- DDR3
    ddr3_dq => ddr3_dq,
    ddr3_dqs => ddr3_dqs, 
    ddr3_dm => ddr3_dm,
    ddr3_addr => ddr3_addr, 
    ddr3_ba => ddr3_ba, 
    ddr3_cke => ddr3_cke, 
    ddr3_ck => ddr3_ck, 
    ddr3_csn => ddr3_csn, 
    ddr3_odt => ddr3_odt, 
    ddr3_casn => ddr3_casn, 
    ddr3_rasn => ddr3_rasn, 
    ddr3_wen => ddr3_wen, 
    ddr3_resetn => ddr3_resetn, 
    -- Ethernet
    eth_gtxclk   => eth_gtxclk,
    eth_txclk    => eth_txclk,
    eth_rxclk    => eth_rxclk,
    eth_rxd      => eth_rxd,
    eth_rxdv     => eth_rxdv,
    eth_rxer     => eth_rxer,
    eth_col      => eth_col,
    eth_crs      => eth_crs,
    eth_txd      => eth_txd,
    eth_txen     => eth_txen,
    eth_txer     => eth_txer,
    eth_mdio     => eth_mdio, 
    eth_mdc      => eth_mdc,
    eth0_mdc     => '0',
    eth0_mdint   => '0',
    eth0_mdio    => '0',
    -- SpaceWire gr740   
    spw_din_gr740_4   => spw_io_gnd,
    spw_sin_gr740_4   => spw_io_gnd,
    spw_dout_gr740_4  => open,
    spw_sout_gr740_4  => open,
    spw_din_gr740_5   => spw_io_gnd,
    spw_sin_gr740_5   => spw_io_gnd,
    spw_dout_gr740_5  => open,
    spw_sout_gr740_5  => open,
    spw_din_gr740_6   => spw_io_gnd,
    spw_sin_gr740_6   => spw_io_gnd,
    spw_dout_gr740_6  => open,
    spw_sout_gr740_6  => open,
    spw_din_gr740_7   => spw_io_gnd,
    spw_sin_gr740_7   => spw_io_gnd,
    spw_dout_gr740_7  => open,
    spw_sout_gr740_7  => open,
    -- SpaceWire gr740  
    spw_din_mez_1     => spw_io_gnd,
    spw_sin_mez_1     => spw_io_gnd,
    spw_dout_mez_1    => open,
    spw_sout_mez_1    => open,    
    spw_din_mez_2     => spw_io_gnd,
    spw_sin_mez_2     => spw_io_gnd,
    spw_dout_mez_2    => open,
    spw_sout_mez_2    => open,      
    spw_din_mez_3     => spw_io_gnd,
    spw_sin_mez_3     => spw_io_gnd,
    spw_dout_mez_3    => open,
    spw_sout_mez_3    => open,    
    spw_din_mez_4     => spw_io_gnd,
    spw_sin_mez_4     => spw_io_gnd,
    spw_dout_mez_4    => open,
    spw_sout_mez_4    => open,     
    -- GPIO
    fpga_led          => fpga_led, 
    gr740_gpio2       => gr740_gpio2,
    -- I2C
    i2c_scl_fmc       => i2c_scl_fmc, 
    i2c_sda_fmc       => i2c_sda_fmc,
    -- NAND flash
    Ce0_0_n          => Ce_n,
    Ce1_0_n          => Ce3_n,
    Ce0_1_n          => Ce2_n,
    Ce1_1_n          => Ce4_n,
    Dqs_t_0          => Dqs,
    Dq_Io_0          => Dq_Io,
    Cle_0            => Cle,
    Ale_0            => Ale,
    Clk_We_0_n       => Clk_We_n,
    Wr_Re_0_n        => Wr_Re_n,
    Wp_0_n           => Wp_n,
    Dqs_t_1          => Dqs2,
    Dq_Io_1          => Dq_Io2,
    Cle_1            => Cle2,
    Ale_1            => Ale2,
    Clk_We_1_n       => Clk_We2_n,
    Wr_Re_1_n        => Wr_Re2_n,
    Wp_1_n           => Wp2_n,
    Rb0_0_n          => Rb_n,
    Rb1_0_n          => Rb3_n,
    Rb0_1_n          => Rb2_n,
    Rb1_1_n          => Rb4_n,
    -- JTAG
    tck              => tck,
    tms              => tms,
    tdi              => tdi,
    tdo              => tdo,
    -- SerDes
    SD0_RXDP => SD0_TXDP,
    SD0_RXDN => SD0_TXDN, 
    SD2_RXDP => SD2_TXDP, 
    SD2_RXDN => SD2_TXDN, 
    SD6_RXDP => SD6_TXDP,
    SD6_RXDN => SD6_TXDN,
    SD7_RXDP => SD7_TXDP,
    SD7_RXDN => SD7_TXDN, 
    SD0_TXDP => SD0_TXDP,
    SD0_TXDN => SD0_TXDN, 
    SD2_TXDP => SD2_TXDP, 
    SD2_TXDN => SD2_TXDN, 
    SD6_TXDP => SD6_TXDP,
    SD6_TXDN => SD6_TXDN,
    SD7_TXDP => SD7_TXDP,
    SD7_TXDN => SD7_TXDN, 
    sdq0_refclkp     => sdq0_refclkp,
    sdq0_refclkn     => sdq0_refclkn,
    sd_ext0_refclkp  => sd_ext0_refclkp,
    sd_ext0_refclkn  => sd_ext0_refclkn,
    sdq1_refclkp     => sdq1_refclkp,
    sdq1_refclkn     => sdq1_refclkn,
    sd_ext1_refclkp  => sd_ext1_refclkp,
    sd_ext1_refclkn  => sd_ext1_refclkn);

    ic2_slave : if (CFG_I2C_FMC = 1) generate
      i1: i2c_slave_model
        port map (i2c_scl_fmc, i2c_sda_fmc);
    end generate;

  -- But on data pins the controller expects delay. In fact the delay
  -- is asymmetric. It is longer (7.60 ns) from MC to MEM compated to
  -- MEM to MC (2.25 ns). Unclear where these huge delays come from.
    board_delay_dq : delay_wire
      generic map(
        data_width => 8,
        delay_atob => delay_mc2mem,
        delay_btoa => delay_mem2mc)
      port map (
        a => ddr3_dq,
        b => ddr3_dq_del);

    board_delay_dqs : delay_wire
      generic map(
        data_width => 1,
        delay_atob => delay_mc2mem,
        delay_btoa => delay_mem2mc)
      port map (
        a => ddr3_dqs,
        b => ddr3_dqs_del);

    board_delay_dm : delay_wire
      generic map(
        data_width => 1,
        delay_atob => delay_mc2mem,
        delay_btoa => delay_mem2mc)
      port map (
        a => ddr3_dm,
        b => ddr3_dm_del);

    -- ram0: ddr3ram
    --   generic map (
    --     width => 8,
    --     abits => 16,
    --     colbits => 10,
    --     rowbits => 14,  -- Use less rowbits to save RAM
    --     implbanks => 8,
    --     fname => "ram.srec",
    --     speedbin => 12) 
    --    -- initbyte => 16#33#)
    --   port map (
    --     ck => ddr3_ck(0),
    --     ckn => ddr3_ckn,
    --     cke => ddr3_cke(0),
    --     csn => ddr3_csn(0),
    --     odt => ddr3_odt(0),
    --     rasn => ddr3_rasn,
    --     casn => ddr3_casn,
    --     wen => ddr3_wen,
    --     dm => ddr3_dm_del, -- delayed
    --     ba => ddr3_ba,
    --     a => ddr3_addr,
    --     resetn => ddr3_resetn,
    --     -- Delayed data signals (clock/control are not delayed)
    --     dq => ddr3_dq_del,
    --     dqs => ddr3_dqs_del,
    --     dqsn => ddr3_dqsn_del);

    nandflash : if ( CFG_NANDFCTRL2_EN = 1) generate
      nf0: nand_model -- nand_model_m73a
        port map(
          Ce2_n     => Ce2_n,
          Ce3_n     => Ce3_n,
          Ce4_n     => Ce4_n,
          Rb2_n     => Rb2_n,
          Rb3_n     => Rb3_n,
          Rb4_n     => Rb4_n,
          Dq_Io2    => Dq_Io2,
          Cle2      => Cle2,
          Ale2      => Ale2,
          Clk_We2_n => Clk_We2_n,
          Wr_Re2_n  => Wr_Re2_n,
          Wp2_n     => Wp2_n,
          Dq_Io    => Dq_Io,
          Dqs      => Dqs,
          Cle      => Cle,
          Ale      => Ale,
          Ce_n     => Ce_n,
          Clk_We_n => Clk_We_n,
          Wr_Re_n  => Wr_Re_n,
          Wp_n     => Wp_n,
          Rb_n     => Rb_n,
          ENi       => '1',
          ENo       => open,
          Re_c      => '0');
    end generate;   

    debug_uart_rx  <= debug_uart_tx;

    phy_rgmii1 : if ( CFG_GRETH = 1) generate
     eth_mdio <= 'H'; 
      p1: phy   -- RGMII PHY
        generic map (
          address       => CFG_ETH_PHY_ADD,
          aneg          => 1)-- PHY address
        port map (
          rstn     => gsrn, 
          mdio     => eth_mdio,
          tx_clk   => eth_txclk, 
          rx_clk   => eth_rxclk,
          rxd      => eth_rxd,  
          rx_dv    => eth_rxdv,  
          rx_er    => eth_rxer,   -- not used in rgmii mode
          rx_col   => eth_col,   -- not used in rgmii mode 
          rx_crs   => eth_crs,   -- not used in rgmii mode
          txd      => eth_txd,   
          tx_en    => eth_txen,
          tx_er    => eth_txer, 
          mdc      => eth_mdc, 
          gtx_clk  => eth_gtxclk, 
          extrxclk => '0');
    end generate;

    jtagproc : process
      variable i : integer; 
      variable data : std_logic_vector(31 downto 0);
      variable data_a : std_logic_vector(31 downto 0);
      variable data_b : std_logic_vector(31 downto 0);
      variable do : std_logic;
      variable baseaddr : std_logic_vector(31 downto 0);
      variable tp        : boolean := true;           -- test passed
      variable tpcounter : natural := 0;              -- test error counter

      procedure mem(
        constant addr : std_logic_vector(31 downto 0);
        variable data : out std_logic_vector(31 downto 0)) is
      begin
        jread(
          addr, "10", data, -- hsize = "10": 32-bit read ("01" would be 16-bit, "00" 8-bit)
          tck, tms, tdi, tdo,
          cp => 100,
          ainst => 16#32#, dinst => 16#38#, isize => 8);
      end procedure;

      procedure wmem(
        constant addr : std_logic_vector(31 downto 0);
        constant data : std_logic_vector(31 downto 0)) is
      begin
        jwrite( 
          addr, "10", data,  -- hsize = "10": 32-bit read ("01" would be 16-bit, "00" 8-bit)
          tck, tms, tdi, tdo,
          cp => 100,
          ainst => 16#32#, dinst => 16#38#, isize => 8);
      end procedure;

    begin

     oc_ram_addr(31 downto 20) <= std_logic_vector(to_unsigned(CFG_OC_RAM_ADDR, 12)); 
     apb_addr_0(31 downto 20)    <= std_logic_vector(to_unsigned(CFG_APBADDR_0, 12)); 
     apb_addr_1(31 downto 20)  <=  std_logic_vector(to_unsigned(CFG_APBADDR_1, 12));
     apb_addr_2(31 downto 20)  <=  std_logic_vector(to_unsigned(CFG_APBADDR_2, 12));  
     ddr3_mem_addr(31 downto 20)   <=  std_logic_vector(to_unsigned(CFG_DDR3_ADDR, 12));
     spfi_addr(31 downto 20)   <=  std_logic_vector(to_unsigned(CFG_AHBIO, 12));
     spfi_addr(19 downto 8)   <=  std_logic_vector(to_unsigned(CFG_SPFI_IOADDR, 12));

      tck <= '0'; tms <= '0'; tdi <= '0';

      wait until gsrn = '1';
      wait for 10 us;
      for i in 1 to 5 loop     -- reset
        clkj('1', '0', do, tck, tms, tdi, tdo, 100);
      end loop;
      clkj('0', '0', do, tck, tms, tdi, tdo, 100);

      wait for 900 us;
     
      tinitialise(tp, tpcounter);
    
      mem(X"affff000", data);
      print("Plug&Play info: " & tost(data));

      print(""); 
      print("Writing data to ON-CHIP RAM"); 
      wmem(oc_ram_addr, X"56789abc"); 
      wmem(oc_ram_addr + X"8", X"65342118"); 
      wmem(oc_ram_addr + X"C", X"00123456"); 
      wmem(oc_ram_addr + X"10", X"f0123456"); 
      wmem(oc_ram_addr + X"14", X"789abcde"); 
      wmem(oc_ram_addr + X"18", X"f0012345"); 
      wmem(oc_ram_addr + X"1c", X"67689abc"); 
      wmem(oc_ram_addr + X"20", X"def01234"); 
      wmem(oc_ram_addr + X"24", X"56789abc"); 
      wmem(oc_ram_addr + X"28", X"01234567"); 
      wmem(oc_ram_addr + X"2c", X"89abcdef"); 
      wmem(oc_ram_addr + X"30", X"f0123456"); 
      wmem(oc_ram_addr + X"34", X"789abcde"); 
      wmem(oc_ram_addr + X"38", X"f0012345"); 
      wmem(oc_ram_addr + X"3c", X"00123456"); 
      wmem(oc_ram_addr + X"40", X"789aabcd"); 
      wmem(oc_ram_addr + X"44", X"eef01234");

      -- NOTE: to simulate the nandflash, there is need to bulid the simulation model, use command : make sim_mem
      if CFG_NANDFCTRL2_EN = 1 then 
        print("");
        print("Enter <Nandflash read ID> test");
        -- SDR timing set-up
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"50", X"00030004");  -- Programmable timing 0 register
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"54", X"00010009");  -- Programmable timing 1 register
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"58", X"00090005");  -- Programmable timing 2 register
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"5c", X"00130019");  -- Programmable timing 3 register
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"60", X"00020002");  -- Programmable timing 4 register
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"64", X"00020002");  -- Programmable timing 5 register
        -- Configurate the descriptors
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"8", X"00000002"); -- 
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"164", X"0000000f"); -- Descriptor target select 0 register
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"168", X"00000000"); -- Descriptor target select 1 register
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"170", X"0000000f"); -- Descriptor ready/busy select register
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"16c", X"00000003"); -- Descriptor channel select register
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"24", X"000000ff");  -- Core status 1 register
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"160", X"00ff0001"); -- Descriptor command register
        -- Nandflash Read id
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"164", X"00000001"); --
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"168", X"00000000"); -- 
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"170", X"00000001"); -- 
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"16c", X"00000001"); -- 
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"24", X"000000ff"); -- 
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"160", X"00900e09"); --
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"174", X"00000020"); 
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"178", X"00050000"); 
        wmem(apb_addr_0 + 256*paddr_nandfctrl2 + X"8", X"00000002"); 
         mem(apb_addr_0 + 256*paddr_nandfctrl2 + X"24", data);
         mem(apb_addr_0 + 256*paddr_nandfctrl2 + X"1e0", data); 
          if (data /= X"4f4e4649") then
            print("Error: during <Nandflash read ID> test");
            tp := false;
          end if;
        print("End of <Nandflash read ID> test");
        tintermediate(tp, tpcounter);
      end if;  -- end nandflash test (read id) 

      if CFG_I2C_FMC = 1 then 
        print("");
        print("Enter <I2C port 1: write/read to external memory> test");
        mem(apb_addr_0 + 256*paddr_i2c + X"0", data);
        if (data /= X"0000FFFF") then
          print("ERROR: Prescale register has unexpected value");
        end if;
        wmem(apb_addr_0 + 256*paddr_i2c + X"0", X"0000000A");
        wmem(apb_addr_0 + 256*paddr_i2c + X"4", X"00000080"); -- Enable the I2C core
        wmem(apb_addr_0 + 256*paddr_i2c + X"8", X"000000a0"); -- Address for the external model, write mode
        wmem(apb_addr_0 + 256*paddr_i2c + X"c", X"00000090"); -- Enable start and write  
        wmem(apb_addr_0 + 256*paddr_i2c + X"8", X"00000000"); -- Sets memory address 00
        wmem(apb_addr_0 + 256*paddr_i2c + X"c", X"00000010"); -- Write
        wmem(apb_addr_0 + 256*paddr_i2c + X"8", X"00000066"); -- data
        wmem(apb_addr_0 + 256*paddr_i2c + X"c", X"00000050"); -- Write and stop
        -- Read back data  
        wmem(apb_addr_0 + 256*paddr_i2c + X"8", X"000000a0"); -- Address for the external model, write mode
        wmem(apb_addr_0 + 256*paddr_i2c + X"c", X"00000090"); -- Enable start and write
        wmem(apb_addr_0 + 256*paddr_i2c + X"8", X"00000000"); -- Sets memory address 00
        wmem(apb_addr_0 + 256*paddr_i2c + X"c", X"00000010"); -- write  
        wmem(apb_addr_0 + 256*paddr_i2c + X"8", X"000000a1"); -- Address for the external model, read mode
        wmem(apb_addr_0 + 256*paddr_i2c + X"c", X"00000090"); -- Enable start and write
        wmem(apb_addr_0 + 256*paddr_i2c + X"c", X"00000068"); -- read and stop
        mem(apb_addr_0 + 256*paddr_i2c + X"8", data); -- recive register    
        if (data /= X"00000066") then
           print("Error: during <I2C port 1: write/read to external memory> test : missmatch in write/read data");
           tp := false;
        end if;  
        print("End of <I2C port 1: write/read to external memory> test");
        tintermediate(tp, tpcounter);
      end if;

      if CFG_GRGPIO_EN = 1 then 
        print("");
        print("Enter <GPIO> test");
        -- Configure the GPIO port as output
        wmem(apb_addr_0 + 256*pidx_grgpio + X"8", X"FFFFFFFF"); -- Enable outputs
        data := X"89abcdef";
        data(CFG_GRGPIO_WIDTH-1) := '1';
        fpga_led <= (others => 'Z'); -- Tri-state I/Os
        gr740_gpio2 <= (others => 'Z'); -- Tri-state I/Os
        wmem(apb_addr_0 + 256*pidx_grgpio + X"4", data); -- Set GPIO data value
        wmem(apb_addr_0 + 256*pidx_grgpio + X"8", X"FFFFFFFF"); -- Enable outputs
        if (fpga_led(3) /= data(3)) then
          print("ERROR: during <GPIO> test : output value incorrect");
          tp := false;
        end if;
        if (gr740_gpio2(4) /= data(8)) then
          print("ERROR: during <GPIO> test : output value incorrect");
          tp := false;
        end if;
        -- Configure the GPIO port as input
        wmem(apb_addr_0 + 256*pidx_grgpio + X"8", X"00000000"); -- Disable outputs
        data := X"12345678";
        data(CFG_GRGPIO_WIDTH-1) := '1';
        data(0) := '1';
        fpga_led <= data(3 downto 0);
        gr740_gpio2 <= data(8 downto 4);
        mem(apb_addr_0 + 256*pidx_grgpio + X"0", data_a);
        if (data_a(3) /= data(3)) then
          print("EERROR: during <GPIO> test : input value incorrect");
          tp := false;
        end if;
        if (data_a(8) /= data(8)) then
          print("EERROR: during <GPIO> test : input value incorrect");
          tp := false;
        end if;
        print("End of <GPIO> test");
        tintermediate(tp, tpcounter);
      end if;

      -- The UART tests require the UART TX and RX signals to be connected in loopback
      if (CFG_UART_1_ENABLE = 1 and CFG_AHB_UART = 0) then
        print("");
        print("Enter <UART> test");
        for i in 0 to 2 loop
         if i = 0 and CFG_UART_1_ENABLE = 1 and CFG_AHB_UART = 0 then
           -- Test UART 1
           baseaddr := apb_addr_0 + 256*paddr_apbuart;
           print("Test UART 1");
         else
           next;
         end if;
          wmem(baseaddr + 256*paddr_apbuart + X"C", X"00000002"); -- Set scaler low
          mem(baseaddr + X"4", data); -- Read status
          if data(0) /= '0' then
            print("ERROR: during <UART> test : receiver not empty after reset");
            tp := false;
          else
            wmem(baseaddr + X"8", X"00000083"); -- Enable loopback
            if CFG_DUART > 0 then
              -- Everything will be echoed in the terminal, which limits the test
              -- Note that the test relies on the UART being faster than
              -- reading and writing through the debug link. No checks are made
              -- that the UART can receive more data before writing.
              wmem(baseaddr + X"0", X"00000047"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if data(2) = '0' then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;
              wmem(baseaddr + X"0", X"00000052"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;
              wmem(baseaddr + X"0", X"00000037"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;
              wmem(baseaddr + X"0", X"00000034"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;
              wmem(baseaddr + X"0", X"00000030"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;
              wmem(baseaddr + X"0", X"0000002D"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;
              wmem(baseaddr + X"0", X"0000004D"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;
              wmem(baseaddr + X"0", X"00000049"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;              
              wmem(baseaddr + X"0", X"0000004E"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;
              wmem(baseaddr + X"0", X"00000049"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if; 
              wmem(baseaddr + X"0", X"0000000D"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;
            else
              -- Loopback test
              -- Note that the test relies on the UART being faster than
              -- reading and writing through the debug link. No checks are made
              -- that the UART can receive more data before writing and data is
              -- assumed to arrive at the receiver before the next read.
              wmem(baseaddr + X"0", X"000000F6"); -- Send data
              mem(baseaddr + X"4", data); -- Read status
              if (data(2) = '0') then
                print("ERROR: during <UART> test : transmission error");
                tp := false;
              end if;
              if (data(0) = '0') then
                print("ERROR: during <UART> test : reception error");
                tp := false;
              else
                mem(baseaddr + X"0", data); -- Read status
                if data(7 downto 0) /= X"F6" then
                  print("ERROR: during <UART> test : Unexpected UART data received");
                  tp := false;
                end if;
              end if;
            end if;
          end if;
        end loop;
        print("End of <UART> test");
        tintermediate(tp, tpcounter);
      end if;

      if CFG_GRETH1G = 1 and CFG_ETH_MDIO = 0 then
        print("Enter <ETHERNET> 1000Mb test");
        print("  Enter MDIO-mode");
        mem(apb_addr_0 + 256*paddr_mdio, data); -- Status register
         wmem(apb_addr_0 + 256*paddr_mdio + X"8", X"610000a0"); -- NOTE: The address of the PHY is set by bit 10:6.  
        mem(apb_addr_0 + 256*paddr_mdio, data); -- Status register
        mem(apb_addr_0 + 256*paddr_mdio, data); -- Status register
        mem(apb_addr_0 + 256*paddr_mdio + X"8", data); -- NOTE: The address of the PHY is set by bit 10:
        mem(apb_addr_0 + 256*paddr_greth, data);  -- Check status 
        print("  Exiting MDIO-mode");
        wmem(oc_ram_addr + X"0", X"00001840"); -- Enables the TX descriptor
        wmem(oc_ram_addr + X"4", oc_ram_addr + X"8"); -- points where the data is
        wmem(apb_addr_0 + 256*paddr_greth + X"14", oc_ram_addr); -- sets where the TX descriptor is located 
        wmem(apb_addr_0 + 256*paddr_greth + X"18", oc_ram_addr + X"1000"); -- sets where the RX descriptor is located 
        wmem(oc_ram_addr + X"1000", X"00001840"); -- Enables the RX descriptor
        wmem(oc_ram_addr + X"1004", oc_ram_addr + X"1008"); -- Points where the data is stored
        wmem(apb_addr_0 + 256*paddr_greth, X"cd000133"); -- CTRL RX & TX enbale 10
        for i in 0 to 15 loop -- check received data with transmitted 
          mem(oc_ram_addr + X"8" + i*4, data_a) ;
          mem(oc_ram_addr + X"1008" + i*4, data_b); 
          if (data_a /= data_b) then
            print("Error: during <ETHERNET> 1000Mb test :  TX DATA /= RX DATA");
            tp := false;
          end if;
          wmem(oc_ram_addr + X"1008" + i*4, X"00000000"); -- clear rx data 
        end loop; 
        print("End of <ETHERNET> 1000Mb test");
        wmem(apb_addr_0 + 256*paddr_mdio, X"00000040"); -- reset core
        tintermediate(tp, tpcounter);
      end if;


      if CFG_HSSL_EN = 1 then 
        for i in 0 to CFG_HSSL_NUM-1 loop
          print("");
          print("Enter <SpaceFibre port> test");
          wmem(apb_addr_0 + 256*paddr_gp_register + X"10", X"00008006");  -- Enable spacefibre core
          wmem(spfi_addr + i*4096 + X"80c", X"00000001");  -- Enable spacefibre core
          wmem(spfi_addr + i*4096 + X"110", X"ffffffff");  -- Set which time-slots the core can transmit during (Only affects transmisison)
          wmem(spfi_addr + i*4096 + X"114", X"ffffffff");  -- Set which time-slots the core can transmit during (Only affects transmisison)
          wmem(spfi_addr + i*4096 + X"100", X"03000001");  -- Virtual Channel Control Register sets bandwidh
          wmem(spfi_addr + i*4096 + X"10c", X"0000ff00");  -- Set address mask to allow everything (defaddr is not used)
          wmem(spfi_addr + i*4096 + X"8", X"0000000c");    -- spacefibre 0: set to link start and reset       
          wmem(spfi_addr + i*4096 + X"B08", X"00000001");  -- Map virtual channel 0 to DMA0
          wmem(spfi_addr + i*4096 + X"B00", X"00000003");  -- Start transmission (0x2) and reception (0x1) on DMA0
          -- RX DESCRIPTORS
          wmem(spfi_addr + i*4096 + X"108", X"0000000c");  -- Set max number of bytes to receive
          wmem(spfi_addr + i*4096 + X"904", oc_ram_addr + X"100");  -- VC RX Descriptor Table Address
          wmem(oc_ram_addr + X"104" , oc_ram_addr + X"108");  -- points to where the data shall be located.
          wmem(oc_ram_addr + X"100" , X"0e000000");  -- enable descriptor
          wmem(spfi_addr + i*4096 + X"908", X"00000001");  -- New recieve descriptors available
          -- TX DESCRIPTORS
          wmem(oc_ram_addr + X"8" , X"0000000c");  -- data legnth
          wmem(oc_ram_addr + X"c" , oc_ram_addr + X"10");  -- points to where the data shall be located. 
          wmem(spfi_addr + i*4096 + X"900", oc_ram_addr);  -- VC TX Descriptor Table Address
          wmem(oc_ram_addr , X"00000100");  -- enable descriptor 
          wmem(spfi_addr + i*4096 + X"908", X"00000002");  -- New transmit descriptors available
          for j in 0 to 2 loop -- check received data with transmitted
            mem(oc_ram_addr + X"10" + j*4, data_a) ;
            mem(oc_ram_addr + X"108" + j*4, data_b); 
            if (data_a /= data_b) then
              print("Error: during <SpaceFibre port> test :  TX DATA /= RX DATA");
              tp := false;
            end if;  
            wmem(oc_ram_addr + X"108" + j*4, X"00000000"); -- clear rx data
          end loop; 
        end loop;   
          print("End of <SpaceFibre port> test");
          tintermediate(tp, tpcounter);
      end if; 

      tterminate(tp, tpcounter);
      
      assert false report "Testbench ended normally (not a failure)" severity failure;
      wait;
       
  end process;



end;
