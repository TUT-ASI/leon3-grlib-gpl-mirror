------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
use ieee.numeric_std.all;
use std.textio.all;
library gaisler;
use gaisler.libdcom.all;
use gaisler.sim.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.stdio.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;
library work;
use work.debug.all;
use work.config.all;

entity testbench is
  generic(
    fabtech : integer := CFG_FABTECH;
    memtech : integer := CFG_MEMTECH;
    padtech : integer := CFG_PADTECH;
    clktech : integer := CFG_CLKTECH;
    disas   : integer := CFG_DISAS;
    dm_ctrl : integer := 0;
    romfile : string := "prom.srec"; -- rom contents
    ramfile : string := "ram.srec"  -- ram contents
    );
end;

architecture behav of testbench is

  -----------------------------------------------------
  -- Components ---------------------------------------
  -----------------------------------------------------

  component ddr4ram
    generic(
      dq_bits             : natural := 8
      );
    port(
      ddr4_ck             : in    std_logic_vector(1 downto 0);
      ddr4_addr           : in    std_logic_vector(13 downto 0);
      ddr4_we_n           : in    std_logic;
      ddr4_cas_n          : in    std_logic;
      ddr4_ras_n          : in    std_logic;
      ddr4_alert_n        : out   std_logic;
      ddr4_parity         : in    std_logic;
      ddr4_reset_n        : in    std_logic;
      ddr4_ten            : in    std_logic;
      ddr4_ba             : in    std_logic_vector(1 downto 0);
      ddr4_cke            : in    std_logic;
      ddr4_cs_n           : in    std_logic;
      ddr4_dm_n           : inout std_logic_vector(7 downto 0);
      ddr4_dq             : inout std_logic_vector(63 downto 0);
      ddr4_dqs_c          : inout std_logic_vector(7 downto 0);
      ddr4_dqs_t          : inout std_logic_vector(7 downto 0);
      ddr4_odt            : in    std_logic;
      ddr4_bg             : in    std_logic_vector(0 downto 0);
      ddr4_act_n          : in    std_logic
      );
  end component ddr4ram; 

  -----------------------------------------------------
  -- Constant -----------------------------------------
  -----------------------------------------------------

  constant SIMULATION : integer := CFG_MIG_7SERIES_MODEL;

  -----------------------------------------------------
  -- Signals ------------------------------------------
  -----------------------------------------------------

  signal clk            : std_logic := '0';
  signal system_rst     : std_ulogic;

  signal gnd            : std_ulogic := '0';
  signal vcc            : std_ulogic := '1';
  signal nc             : std_ulogic := 'Z';

  signal clk300p        : std_ulogic := '0';
  signal clk300n        : std_ulogic := '1';
  signal clk125p        : std_ulogic := '0';
  signal clk125n        : std_ulogic := '1';

  signal txd1           : std_ulogic;
  signal rxd1           : std_ulogic;
  signal ctsn1          : std_ulogic;
  signal rtsn1          : std_ulogic;

  signal iic_scl        : std_ulogic;
  signal iic_sda        : std_ulogic;
  signal iic_mreset     : std_ulogic;

  signal switch         : std_logic_vector(3 downto 0);
  signal gpio           : std_logic_vector(15 downto 0);
  signal led            : std_logic_vector(7 downto 0);
  signal button         : std_logic_vector(4 downto 0);

  signal phy_mii_data   : std_logic;
  signal phy_tx_clk     : std_ulogic;
  signal phy_rx_clk     : std_ulogic;
  signal phy_rx_data    : std_logic_vector(7 downto 0);
  signal phy_dv         : std_ulogic;
  signal phy_rx_er      : std_ulogic;
  signal phy_col        : std_ulogic;
  signal phy_crs        : std_ulogic;
  signal phy_tx_data    : std_logic_vector(7 downto 0);
  signal phy_tx_en      : std_ulogic;
  signal phy_tx_er      : std_ulogic;
  signal phy_mii_clk    : std_ulogic;
  signal phy_rst_n      : std_ulogic;
  signal phy_gtx_clk    : std_ulogic;
  signal phy_mii_int_n  : std_ulogic;

  signal txp_eth        : std_ulogic;
  signal txn_eth        : std_ulogic;
  signal phy_mdio       : std_logic;
  signal phy_mdc        : std_ulogic;

  signal dmbreak        : std_ulogic;
  signal duart_tx       : std_ulogic;
  signal duart_rx       : std_ulogic;
  signal dsuctsn        : std_ulogic;
  signal dsurtsn        : std_ulogic;

  signal ddr4_ck        : std_logic_vector(1 downto 0);
  signal ddr4_dq        : std_logic_vector(63 downto 0);
  signal ddr4_dqs_c     : std_logic_vector(7 downto 0);
  signal ddr4_dqs_t     : std_logic_vector(7 downto 0);
  signal ddr4_addr      : std_logic_vector(13 downto 0);
  signal ddr4_ras_n     : std_logic;
  signal ddr4_cas_n     : std_logic;
  signal ddr4_we_n      : std_logic;
  signal ddr4_ba        : std_logic_vector(1 downto 0);
  signal ddr4_bg        : std_logic_vector(0 downto 0);
  signal ddr4_dm_n      : std_logic_vector(7 downto 0);
  signal ddr4_ck_c      : std_logic_vector(0 downto 0);
  signal ddr4_ck_t      : std_logic_vector(0 downto 0);
  signal ddr4_cke       : std_logic_vector(0 downto 0);
  signal ddr4_act_n     : std_logic;
  signal ddr4_alert_n   : std_logic;
  signal ddr4_odt       : std_logic_vector(0 downto 0);
  signal ddr4_par       : std_logic;
  signal ddr4_ten       : std_logic;
  signal ddr4_cs_n      : std_logic_vector(0 downto 0);
  signal ddr4_reset_n   : std_logic;

  -- Testbench Related Signals
  signal dsurst         : std_ulogic;
  signal errorn         : std_logic;


begin

  -----------------------------------------------------
  -- Clocks and Reset ---------------------------------
  -----------------------------------------------------

  clk300p <= not clk300p after 1.666 ns;
  clk300n <= not clk300n after 1.666 ns;
  clk125p <= not clk125p after 4 ns; -- clkethp
  clk125n <= not clk125p after 4 ns; -- clkethn

  system_rst    <= not dsurst;

  ddr4_ck       <= clk300n & clk300p;

  -----------------------------------------------------
  -- Misc ---------------------------------------------
  -----------------------------------------------------

  errorn        <= 'H'; -- ERROR pull-up
  switch(2 downto 0) <= (2 => '1', others => '0');
  button        <= (4 => dmbreak, others => '0');

  -----------------------------------------------------
  -- Top ----------------------------------------------
  -----------------------------------------------------

  cpu : entity work.noelvmp
    generic map(
      fabtech                 => fabtech,
      memtech                 => memtech,
      padtech                 => padtech,
      clktech                 => clktech,
      disas                   => disas,
      SIMULATION              => SIMULATION,
      romfile                 => romfile,
      ramfile                 => ramfile
      )
    port map(
      reset             => system_rst,
      clk300p           => clk300p,
      clk300n           => clk300n,
      switch            => switch,
      led               => led,
      gpio              => gpio,
      iic_scl           => iic_scl,
      iic_sda           => iic_sda,
      iic_mreset        => iic_mreset,
      gtrefclk_n        => clk125n,
      gtrefclk_p        => clk125p,
      txp               => txp_eth,
      txn               => txn_eth,
      rxp               => txp_eth,
      rxn               => txn_eth,
      emdio             => phy_mdio,
      emdc              => phy_mdc,
      eint              => '0',
      erst              => OPEN,
      dsurx             => duart_rx,
      dsutx             => duart_tx,
      dsuctsn           => dsuctsn,
      dsurtsn           => dsurtsn,
      button            => button,
      ddr4_dq           => ddr4_dq,
      ddr4_dqs_c        => ddr4_dqs_c,
      ddr4_dqs_t        => ddr4_dqs_t,
      ddr4_addr         => ddr4_addr,
      ddr4_ras_n        => ddr4_ras_n,
      ddr4_cas_n        => ddr4_cas_n,
      ddr4_we_n         => ddr4_we_n,
      ddr4_ba           => ddr4_ba,
      ddr4_bg           => ddr4_bg,
      ddr4_dm_n         => ddr4_dm_n,
      ddr4_ck_c         => ddr4_ck_c,
      ddr4_ck_t         => ddr4_ck_t,
      ddr4_cke          => ddr4_cke,
      ddr4_act_n        => ddr4_act_n,
      ddr4_alert_n      => ddr4_alert_n,
      ddr4_odt          => ddr4_odt,
      ddr4_par          => ddr4_par,
      ddr4_ten          => ddr4_ten, 
      ddr4_cs_n         => ddr4_cs_n, 
      ddr4_reset_n      => ddr4_reset_n
      );

  phy0 : if (CFG_GRETH = 1) generate
   -- Simulation model for SGMII PHY MDIO interface 
   phy_mdio <= 'H';
   p0: phy
    generic map (
             address       => 7,
             extended_regs => 1,
             aneg          => 1,
             base100_t4    => 1,
             base100_x_fd  => 1,
             base100_x_hd  => 1,
             fd_10         => 1,
             hd_10         => 1,
             base100_t2_fd => 1,
             base100_t2_hd => 1,
             base1000_x_fd => CFG_GRETH1G,
             base1000_x_hd => CFG_GRETH1G,
             base1000_t_fd => CFG_GRETH1G,
             base1000_t_hd => CFG_GRETH1G,
             rmii          => 0,
             rgmii         => 1
    )
    port map(dsurst, phy_mdio, OPEN , OPEN , OPEN ,
             OPEN , OPEN , OPEN , OPEN , "00000000",
             '0', '0', phy_mdc, clk125p); 

  end generate;

  -- Memory model instantiation
  ddr4mem : if (CFG_MIG_7SERIES = 1) generate
    u1 : ddr4ram
      generic map (
        dq_bits => 8)
      port map (
        ddr4_ck       => ddr4_ck,
        ddr4_act_n    => ddr4_act_n,
        ddr4_ras_n    => ddr4_ras_n,
        ddr4_cas_n    => ddr4_cas_n,
        ddr4_we_n     => ddr4_we_n,
        ddr4_alert_n  => ddr4_alert_n,
        ddr4_parity   => ddr4_par,
        ddr4_reset_n  => ddr4_reset_n,
        ddr4_ten      => ddr4_ten,
        ddr4_cs_n     => ddr4_cs_n(0),
        ddr4_cke      => ddr4_cke(0),
        ddr4_odt      => ddr4_odt(0),
        ddr4_bg       => ddr4_bg,
        ddr4_ba       => ddr4_ba,
        ddr4_addr     => ddr4_addr,
        ddr4_dm_n     => ddr4_dm_n,
        ddr4_dq       => ddr4_dq,
        ddr4_dqs_t    => ddr4_dqs_t,
        ddr4_dqs_c    => ddr4_dqs_c
        );
  end generate ddr4mem;

  -----------------------------------------------------
  -- Process ------------------------------------------
  -----------------------------------------------------

  iuerr : process
  begin
    wait for 5000 ns;
    if to_x01(errorn) = '1' then
      wait on errorn;
    end if;
    assert (to_x01(errorn) = '1')
      report "*** IU in error mode, simulation halted ***"
      severity failure;			-- this should be a failure
  end process;

  dsucom : process
    procedure read_srec(
    fname  : in string := "ram.srec";
    endian : in integer := 1;
    signal tx : out std_logic) is --return mem_type is
    file TCF : text open read_mode is fname;
    --variable mem      : mem_type;
    constant txp      : time := 160 * 1 ns;
    variable L1       : line;   
    variable CH       : character;
    variable ai       : integer := 0;
    variable len      : integer := 0;
    variable rectype  : std_logic_vector(3 downto 0);
    variable recaddr  : std_logic_vector(31 downto 0);
    variable reclen   : std_logic_vector(7 downto 0);
    variable recdata  : std_logic_vector(0 to 16*8-1);
    variable data     : std_logic_vector(31 downto 0);
    variable d        : integer := 1;
    variable wa       : std_logic_vector(31 downto 0);
    begin
      --mem := (others => (others => '0'));

      L1:= new string'("");
      while not endfile(TCF) loop
        readline(TCF,L1);
        if (L1'length /= 0) then  --'
          while (not (L1'length=0)) and (L1(L1'left) = ' ') loop
            std.textio.read(L1,CH);
          end loop;

          if L1'length > 0 then --'
            read(L1, ch);
            if (ch = 'S') or (ch = 's') then
              hread(L1, rectype);
              hread(L1, reclen);
              len := conv_integer(reclen)-1;
              recaddr := (others => '0');
              case rectype is 
                 when "0001" =>
                        hread(L1, recaddr(15 downto 0));
                 when "0010" =>
                        hread(L1, recaddr(23 downto 0));
                 when "0011" =>
                        hread(L1, recaddr);
                 when others => next;
              end case;
              hread(L1, recdata(0 to ((len-4)*8)-1));
              print("A: " & tost(recaddr) & " len: " & tost(len) & " rec: " & tost(recdata));
              --recaddr(31 downto abits+2) := (others => '0');
              ai := conv_integer(recaddr)/4;
              for i in 0 to ((len-4)/4)-1 loop
                if endian = 1 then
                  --mem(ai+i)
                  data      := recdata((i*32 + 24) to (i*32 + 31)) &
                               recdata((i*32 + 16) to (i*32 + 23)) &
                               recdata((i*32 +  8) to (i*32 + 15)) &
                               recdata((i*32 +  0) to (i*32 +  7));
                else
                  --mem(ai+i) 
                  data      := recdata((i*32) to (i*32+31));
                end if;
                print("A: " & tost(recaddr + i*4) & " D: " & tost(data));
                --at_write(recaddr + i*4, data, 32, true , false, 0, d, atmi, atmo);
                
                wa := recaddr + i*4;
                txc(tx, 16#c0#, txp);
                txa(tx, conv_integer(wa(31 downto 24)), conv_integer(wa(23 downto 16)), 
                        conv_integer(wa(15 downto 8)) , conv_integer(wa(7 downto 0)), txp);
                txa(tx, conv_integer(data(31 downto 24)), conv_integer(data(23 downto 16)), 
                        conv_integer(data(15 downto 8)) , conv_integer(data(7 downto 0)), txp);
              end loop;

              if ai = 0 then
                ai := 1;
              end if;
            end if;
          end if;
        end if;
      end loop;
      --return mem;
    end procedure;

    procedure duart_sync(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32        : std_logic_vector(31 downto 0);
      variable w64        : std_logic_vector(63 downto 0);
      variable c8         : std_logic_vector(7 downto 0);
      constant txp        : time := 160 * 1 ns;
      constant lresp      : boolean := false;
    begin
      txc(dsutx, 16#55#, txp);      -- sync uart
      report "UART synced";
    end;

    procedure duart_dm_wait_busy(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32        : std_logic_vector(31 downto 0);
      variable w64        : std_logic_vector(63 downto 0);
      variable c8         : std_logic_vector(7 downto 0);
      constant txp        : time := 160 * 1 ns;
      constant lresp      : boolean := false;
    begin
      txc(dsutx, 16#80#, txp);
      txa(dsutx, 16#FE#, 16#00#, 16#00#, 16#58#, txp);
      rxi(dsurx, w32, txp, lresp);
      while w32(12) = '1' loop
        txc(dsutx, 16#80#, txp);
        txa(dsutx, 16#90#, 16#00#, 16#00#, 16#58#, txp);
        rxi(dsurx, w32, txp, lresp);
      end loop;
    end;

    procedure duart_dm_enable(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32        : std_logic_vector(31 downto 0);
      variable w64        : std_logic_vector(63 downto 0);
      variable c8         : std_logic_vector(7 downto 0);
      constant txp        : time := 160 * 1 ns;
      constant lresp      : boolean := false;
    begin
      print("-- Activate the Debug Module");
      txc(dsutx, 16#c0#, txp);
      txa(dsutx, 16#FE#, 16#00#, 16#00#, 16#40#, txp);
      txa(dsutx, 16#00#, 16#00#, 16#00#, 16#01#, txp);
    end;

    procedure duart_dm_set_pc(constant pc : in std_logic_vector(31 downto 0); signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32        : std_logic_vector(31 downto 0);
      variable w64        : std_logic_vector(63 downto 0);
      variable c8         : std_logic_vector(7 downto 0);
      constant txp        : time := 160 * 1 ns;
      constant lresp      : boolean := false;
      constant pc3        : integer := conv_integer(pc(31 downto 24));
      constant pc2        : integer := conv_integer(pc(23 downto 16));
      constant pc1        : integer := conv_integer(pc(15 downto 8));
      constant pc0        : integer := conv_integer(pc(7 downto 0));
    begin
      print("-- Update PC for hart 0");
      txc(dsutx, 16#c0#, txp);
      txa(dsutx, 16#FE#, 16#00#, 16#00#, 16#10#, txp);
      txa(dsutx, pc3, pc2, pc1, pc0, txp);

      txc(dsutx, 16#c0#, txp);
      txa(dsutx, 16#FE#, 16#00#, 16#00#, 16#5C#, txp);
      txa(dsutx, 16#00#, 16#33#, 16#07#, 16#b1#, txp);
    end;

    procedure duart_dm_resume(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32        : std_logic_vector(31 downto 0);
      variable w64        : std_logic_vector(63 downto 0);
      variable c8         : std_logic_vector(7 downto 0);
      constant txp        : time := 160 * 1 ns;
      constant lresp      : boolean := false;
    begin
      print("-- Resume hart 0");
      txc(dsutx, 16#c0#, txp);
      txa(dsutx, 16#FE#, 16#00#, 16#00#, 16#40#, txp);
      txa(dsutx, 16#40#, 16#00#, 16#00#, 16#01#, txp);
    end;

    procedure duart_dm_halt(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32        : std_logic_vector(31 downto 0);
      variable w64        : std_logic_vector(63 downto 0);
      variable c8         : std_logic_vector(7 downto 0);
      constant txp        : time := 160 * 1 ns;
      constant lresp      : boolean := false;
    begin
      print("-- Halt hart 0");
      txc(dsutx, 16#c0#, txp);
      txa(dsutx, 16#FE#, 16#00#, 16#00#, 16#40#, txp);
      txa(dsutx, 16#80#, 16#00#, 16#00#, 16#01#, txp);
    end;

    procedure duart_dm_print_status(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32        : std_logic_vector(31 downto 0);
      variable w64        : std_logic_vector(63 downto 0);
      variable c8         : std_logic_vector(7 downto 0);
      constant txp        : time := 160 * 1 ns;
      constant lresp      : boolean := false;
    begin
      txc(dsutx, 16#80#, txp);
      txa(dsutx, 16#FE#, 16#00#, 16#00#, 16#44#, txp);
      rxi(dsurx, w32, txp, lresp);
      print("-- Debug Module Status: Read[0xFE000040]: " & tost(w32));
    end;

    procedure dsucfg(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32        : std_logic_vector(31 downto 0);
      variable w64        : std_logic_vector(63 downto 0);
      variable c8         : std_logic_vector(7 downto 0);

      constant txp : time := 160 * 1 ns;

    begin

      Print("dsucom process starts here");
      dsutx       <= '1';
      dsurst      <= '0';
      switch(3)   <= '0';
      
      if CFG_MIG_7SERIES = 1 and SIMULATION = 0 then
        wait for 10 us; -- This is for proper DDR4 behaviour durign init phase not needed durin simulation
      end if;

      wait for 1 us;
      print("Deassert global reset here");
      -- Deassert global reset
      dsurst      <= '1';
      switch(3)   <= '1';

      if CFG_MIG_7SERIES = 1 then
        if led(7) /= '1' then
          wait on led(7) until led(7) = '1';  -- Wait for DDR4 Memory Init ready
        end if;
      end if;

    end;

  begin
    dmbreak   <= '0';
    dsuctsn   <= '0';
    duart_rx  <= '1';
    if dm_ctrl /= 0 then
      -- Put the CPU in halt
      dmbreak     <= '1';
    end if;

    dsucfg(duart_tx, duart_rx);

    if dm_ctrl /= 0 then

      --wait until rising_edge(rst);
      --for i in 0 to 100 loop
      --  wait until rising_edge(clk);
      --end loop;
      wait for 5000 ns;
      dmbreak     <= '0';
      
      -- Synchronize UART debug interface
      duart_sync(duart_tx, duart_rx);

      -- Enabled Debug-Module
      duart_dm_enable(duart_tx, duart_rx);

      -- Load SREC file
      --read_srec("ram.srec", 1, duart_rx);

      -- Set PC
      duart_dm_set_pc(x"C0000000", duart_tx, duart_rx);
      
      -- Print Debug-Module status
      duart_dm_print_status(duart_tx, duart_rx);

      -- Resume execution
      duart_dm_resume(duart_tx, duart_rx);

    end if;
    wait;
  end process;
end;

