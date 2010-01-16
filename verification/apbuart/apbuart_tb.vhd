library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.uart.all;
library grlib;
use grlib.stdlib.conv_std_logic_vector;
use grlib.stdlib.conv_integer;
use grlib.stdlib.conv_std_logic;
use grlib.stdlib.tost;
use grlib.stdlib."+";
use grlib.testlib.print;
use grlib.testlib.tinitialise;
use grlib.testlib.tintermediate;
use grlib.testlib.tterminate;
use grlib.amba.all;
use grlib.at_pkg.all;
use grlib.at_ahb_mst_pkg.all;
use work.apbuart_testpackage.all;

------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2010, Aeroflex Gaisler
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
entity apbuart_tb is
   generic(
     sysperiod_g : integer := 20; --systemperiod in ns
     apbaddr_g   : integer := 16#800#;
     pindex      : integer := 0;
     paddr       : integer := 0;
     pmask       : integer := 16#fff#;
     console     : integer := 0;
     pirq        : integer := 0;
     parity      : integer := 1;
     flow        : integer := 1;
     fifosize    : integer range 1 to 32 := 32;
     abits       : integer := 8
 );
end entity apbuart_tb;

architecture behavioural of apbuart_tb is
  -----------------------------------------------------------------------------
  -- Misc constants
  -----------------------------------------------------------------------------
  constant vmode       : boolean := false;
  constant sysperiod_c : time := sysperiod_g * 1 ns;
  constant apbaddr_c   : std_logic_vector(31 downto 0) :=
    conv_std_logic_vector(apbaddr_g, 12) & X"00000";
  constant uartaddr_c  : std_logic_vector(31 downto 0) :=
    apbaddr_c + (conv_std_logic_vector(paddr, 12) and conv_std_logic_vector(pmask, 12));

  constant datareg_c   : std_logic_vector(31 downto 0) := uartaddr_c;
  constant statusreg_c : std_logic_vector(31 downto 0) := uartaddr_c + 4;
  constant ctrlreg_c   : std_logic_vector(31 downto 0) := uartaddr_c + 8;
  constant scalerreg_c : std_logic_vector(31 downto 0) := uartaddr_c + 12;
  constant fifodbgreg_c: std_logic_vector(31 downto 0) := uartaddr_c + 16;
   
  -----------------------------------------------------------------------------
  -- Signal declarations
  -----------------------------------------------------------------------------
  signal rstn          : std_ulogic := '0';
  signal clk           : std_ulogic := '0';
                       
  signal apbi          : apb_slv_in_type;
  signal apbo          : apb_slv_out_vector := (others => apb_none);
  signal ahbmi         : ahb_mst_in_type;
  signal ahbmo         : ahb_mst_out_vector := (others => ahbm_none);
  signal ahbsi         : ahb_slv_in_type;
  signal ahbso         : ahb_slv_out_vector := (others => ahbs_none);
  signal atmi          : at_ahb_mst_in_type;
  signal atmo          : at_ahb_mst_out_type;
                       
  signal uarti         : uart_in_type;
  signal uarto         : uart_out_type;
  signal uarti2        : uart_in_type;
  signal uarto2        : uart_out_type;
  signal dbgi          : uart_dbg_in_type;
  signal dbgo          : uart_dbg_out_type;
  
  signal enablemon     : std_ulogic;
  signal irqdetected   : std_ulogic;
  signal clearirq      : std_ulogic;
begin
  -----------------------------------------------------------------------------
  -- clk generation
  -----------------------------------------------------------------------------
  clk <= not clk after (sysperiod_c/2);

  -----------------------------------------------------------------------------
  -- AMBA infrastructure
  -----------------------------------------------------------------------------
  ahb0 : at_ahb_ctrl 		-- AHB arbiter/multiplexer
  generic map (defmast => 0, split => 1, enebterm => 1, ebprob => 1,
               rrobin => 1, ioaddr => 16#FFF#, hmstdisable => 16#4000#,
               ioen => 1, nahbm => 3, nahbs => 2, hslvdisable => 16#600#,
               enbusmon => 0, assertwarn => 1, asserterr => 1)
  port map (rstn, clk, ahbmi, ahbmo, ahbsi, ahbso);
   
  apb0 : apbctrl				-- AHB/APB bridge
  generic map (hindex => 0, haddr => apbaddr_g, enbusmon => 0,
               asserterr => 1, assertwarn => 1, pslvdisable => 1, nslaves => 1)
  port map (rstn, clk, ahbsi, ahbso(0), apbi, apbo);

  dma1 :  at_ahb_mst
    generic map(
      hindex         => 0,
      vendorid       => 0,
      deviceid       => 0,
      version        => 0)
    port map(
      -- AMBA AHB system signals
      hclk           => clk,
      hresetn        => rstn,
      
      -- Direct Memory Access Interface
      atmi           => atmi,
      atmo           => atmo,
      
      -- AMBA AHB Master Interface
      ahbi           => ahbmi,
      ahbo           => ahbmo(0));
  
  -----------------------------------------------------------------------------
  -- Component instantiation
  -----------------------------------------------------------------------------
  uarti2.rxd  <= uarto.txd;
  uarti2.ctsn <= uarto.rtsn;

  uarti.rxd   <= uarto2.txd;
  uarti.ctsn  <= uarto2.rtsn;
  
  simuart0 : simuart 
    port map(
      dbgi  => dbgi,
      dbgo  => dbgo,
      uarti => uarti2,
      uarto => uarto2);

  uart0 : apbuart
  generic map(
    pindex   => pindex,
    paddr    => paddr,
    pmask    => pmask,
    console  => console,
    pirq     => pirq,
    parity   => parity,
    flow     => flow,
    fifosize => fifosize,
    abits    => abits)
  port map(
    rst      => rstn,
    clk      => clk,
    apbi     => apbi,
    apbo     => apbo(pindex),
    uarti    => uarti,
    uarto    => uarto);

  mon_p : process is
  begin
    if (dbgo.stopbiterr and enablemon) = '1' then
      assert false
      report "Stop-bit error detected"
      severity error;
    end if;
    if (dbgo.txfifoerr and enablemon) = '1' then
      assert false
      report "Sim Uart tx fifo error detected"
      severity error;
    end if;
    if (dbgo.rxfifoerr and enablemon) = '1' then
      assert false
      report "Sim Uart rx fifo error detected"
      severity error;
    end if;
    wait on dbgo, enablemon;
  end process;

  irqdetect_p : process is
  begin
    irqdetected <= '0';
    loop
      if apbo(pindex).pirq(pirq) = '1' then
        irqdetected <= '1';
      end if;
      if rising_edge(clearirq) then
        irqdetected <= '0';
      end if;
      wait on apbo(pindex).pirq, clearirq;
    end loop;
  end process;
  
  test_p : process is
    variable tp        : boolean;
    variable tpcounter : integer;
    variable d         : std_logic_vector(31 downto 0);
    variable c         : std_logic_vector(31 downto 0);
    variable time0     : time;
    variable time1     : time;

    variable rate      : integer;
    variable scaler    : integer;
    variable tolerance : integer;
    variable halffull  : integer;

    procedure treset is
    begin
      print("--=========================================================--");
      print(" Reset the testbench  ---------------------------------------");
      print("--=========================================================--");
      rstn          <= '0';
      at_init(atmi);
      uarti.extclk  <= '0';
      clearirq      <= '0';
      dbgi.baudrate <= 262144;
      dbgi.readchar <= '0';
      dbgi.paren    <= '0';
      dbgi.parsel   <= '0';
      dbgi.rdfifo   <= '0';
      dbgi.wrfifo   <= '0';
      dbgi.sndbreak <= '0';
      enablemon     <= '0';
      wait for sysperiod_c*5;
      rstn      <= '1';
      Print("End of reset ------------------------------------------------");
    end treset;
                
    procedure tregisterresetvalues is
    begin
      print("--=========================================================--");
      print(" Check register reset values  -------------------------------");
      print("--=========================================================--");
      print("");
      print(" -------- Status register -----------------------------------");
      print("");
      if (fifosize > 1) then
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      
      print("");
      print(" -------- Control register ----------------------------------");
      print("");
      if (fifosize > 1) then
        c := '1' &                          -- fifos available
             X"0000" &                      -- unused
             '-' &                          -- transmitter shift register irq enable
             '-' &                          -- delay irq enable
             '-' &                          -- break irq enable
             '-' &                          -- debug enable
             '-' &                          -- receiver fifo irq enable
             '-' &                          -- transmitter fifo irq enable
             '0' &                          -- external clock enable
             '-' &                          -- loopback enable
             '0' &                          -- flow control enable
             '-' &                          -- parity enable
             '-' &                          -- parity select
             '-' &                          -- transmit irq enable
             '-' &                          -- receive irq enable
             '0' &                          -- transmit enable
             '0';                           -- receive enable
      else
        c := '0' &                          -- fifos available
             X"0000" &                      -- unused
             '-' &                          -- transmitter shift register irq enable  
             '-' &                          -- delay irq enable
             '-' &                          -- break irq enable
             '-' &                          -- debug enable
             '0' &                          -- receiver fifo irq enable
             '0' &                          -- transmitter fifo irq enable
             '0' &                          -- external clock enable
             '-' &                          -- loopback enable
             '0' &                          -- flow control enable
             '-' &                          -- parity enable
             '-' &                          -- parity select
             '-' &                          -- transmit irq enable
             '-' &                          -- receive irq enable
             '0' &                          -- transmit enable
             '0';                           -- receive enable
      end if;
      at_comp_32(ctrlreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      
      print("");
      print(" -------- Scaler register ----------------------------------");
      print("");
      c := X"00000" &        -- Unused
           "------------";   -- Scaler reload value
      at_comp_32(scalerreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      
      tintermediate(tp, tpcounter);
    end tregisterresetvalues;

    procedure tbaudrategeneration is
    begin
      print("--=========================================================--");
      print(" Check that correct baudrate is generated from scaler value -");
      print("--=========================================================--");
      rate := 2400; 
      while rate < 256000 loop
        print("Rate: " & tost(rate));
        scaler := 1000000000/(rate*8*sysperiod_g);
        c := X"00000" & conv_std_logic_vector(scaler, 12);
        at_write_32(scalerreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
        at_comp_32(scalerreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
        
        c := '0' &                          -- fifos available
             X"0000" & '0' &                -- unused
             '0' &                          -- delay irq enable
             '0' &                          -- break irq enable
             '0' &                          -- debug enable
             '0' &                          -- receiver fifo irq enable
             '0' &                          -- transmitter fifo irq enable
             '0' &                          -- external clock enable
             '0' &                          -- loopback enable
             '0' &                          -- flow control enable
             '0' &                          -- parity enable
             '0' &                          -- parity select
             '0' &                          -- transmit irq enable
             '0' &                          -- receive irq enable
             '1' &                          -- transmit enable
             '0';                           -- receive enable
        at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
        d := X"000000" & "01010101";
        at_write_32(datareg_c, d, 0, false, "0011", true, vmode, atmi, atmo);
        wait until uarto.txd = '0';
        wait until uarto.txd = '1';
        time0 := now;
        wait until uarto.txd = '0';
        time1 := now;
        if rate < 19200 then
          tolerance := 200;
        else
          tolerance := 100;
        end if;
        if (time1 - time0) > ((1000000000/rate)+tolerance)*1 ns then
          print("Error: Baudrate too low");
          print("Expected period: " & tost(1000000000/rate) & " Got: " & tost((time1-time0)/1 ns));
          tp := false;
        end if;
        if (time1 - time0) < ((1000000000/rate)-tolerance)*1 ns then
          print("Error: Baudrate too high");
          print("Expected period: " & tost(1000000000/rate) & " Got: " & tost((time1-time0)/1 ns));
          tp := false;
        end if;
        while uarto.txd'last_event < (2000000000/rate)*1 ns loop
          wait on uarto.txd for (2000000000/rate)*1 ns;
        end loop;
        rate := rate * 2;
      end loop;
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '0' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '0';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
      tintermediate(tp, tpcounter);
    end tbaudrategeneration;

    procedure ttransmitteroperation is
    begin
      print("--=========================================================--");
      print(" Test standard transmitter operation  -----------------------");
      print("--=========================================================--");
      enablemon <= '1';
      rate := 262144;
      dbgi.baudrate <= rate; dbgi.rxen <= '1';
      scaler := 1000000000/(rate*8*sysperiod_g);
      c := X"00000" & conv_std_logic_vector(scaler, 12);
      at_write_32(scalerreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
      at_comp_32(scalerreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);

      c := "000000" &      -- receiver fifo count
           "000000" &      -- transmitter fifo count
           "000000000" &   -- unused
           '0' &           -- receiver fifo full
           '0' &           -- transmitter fifo full
           '0' &           -- receiver fifo half-full
           '1' &           -- transmitter fifo half-full
           '0' &           -- frame received
           '0' &           -- parity error
           '0' &           -- overflow
           '0' &           -- break received
           '1' &           -- transmitter holding register empty
           '1' &           -- transmitter shift register empty
           '0';            -- received data available

      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      for i in 1 to fifosize loop
        d := X"000000" & conv_std_logic_vector(i, 8);
        at_write_32(datareg_c, d, 0, false, "0011", true, vmode, atmi, atmo);
        if fifosize > 1 then
          if i >= fifosize/2 then
            halffull := 0;
          else
            halffull := 1;
          end if;
          c := "000000" &                     -- receiver fifo count
               conv_std_logic_vector(i, 6) &  -- transmitter fifo count
               "000000000" &                  -- unused
               '0' &                          -- receiver fifo full
               conv_std_logic(fifosize = i) & -- transmitter fifo full
               '0' &                          -- receiver fifo half-full
               conv_std_logic(halffull = 1) & -- transmitter fifo half-full
               '0' &                          -- frame received
               '0' &                          -- parity error
               '0' &                          -- overflow
               '0' &                          -- break received
               '0' &                          -- transmitter holding register empty
               '1' &                          -- transmitter shift register empty
               '0';                           -- received data available
        else
          c := "000000" &      -- receiver fifo count
               "000000" &      -- transmitter fifo count
               "000000000" &   -- unused
               '0' &           -- receiver fifo full
               '0' &           -- transmitter fifo full
               '0' &           -- receiver fifo half-full
               '0' &           -- transmitter fifo half-full
               '0' &           -- frame received
               '0' &           -- parity error
               '0' &           -- overflow
               '0' &           -- break received
               '0' &           -- transmitter holding register empty
               '0' &           -- transmitter shift register empty
               '0';            -- received data available
        end if;
        at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      end loop;
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '0' &                          -- receive irq enable
           '1' &                          -- transmit enable
           '0';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
      for i in fifosize-1 downto 0 loop
        wait until dbgo.gotchar = '1';
        wait until dbgo.gotchar = '0';
        if i = 0 then
          wait for (1500000000/rate)*1 ns; 
        end if;
        if fifosize > 1 then
          if i >= fifosize/2 then
            halffull := 0;
          else
            halffull := 1;
          end if;
          c := "000000" &                     -- receiver fifo count
               conv_std_logic_vector(i, 6) &  -- transmitter fifo count
               "000000000" &                  -- unused
               '0' &                          -- receiver fifo full
               conv_std_logic(i = fifosize) & -- transmitter fifo full
               '0' &                          -- receiver fifo half-full
               conv_std_logic(halffull = 1) & -- transmitter fifo half-full
               '0' &                          -- frame received
               '0' &                          -- parity error
               '0' &                          -- overflow
               '0' &                          -- break received
               conv_std_logic(i = 0) &        -- transmitter holding register empty
               conv_std_logic(i = 0) &        -- transmitter shift register empty
               '0';                           -- received data available
        else
          c := "000000" &      -- receiver fifo count
               "000000" &      -- transmitter fifo count
               "000000000" &   -- unused
               '0' &           -- receiver fifo full
               '0' &           -- transmitter fifo full
               '0' &           -- receiver fifo half-full
               '0' &           -- transmitter fifo half-full
               '0' &           -- frame received
               '0' &           -- parity error
               '0' &           -- overflow
               '0' &           -- break received
               '1' &           -- transmitter holding register empty
               '1' &           -- transmitter shift register empty
               '0';            -- received data available
        end if;
        at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
        dbgi.rdfifo <= '1';
        wait until dbgo.rdack = '1';
        if conv_integer(dbgo.rxchar) /= fifosize-i then
          print("ERROR: Wrong character received. Expected: " & tost(fifosize-i) & " Got: " & tost(dbgo.rxchar));
          tp := false;
        end if;
        if dbgo.parerr = '1' then
          print("ERROR: Parity error detected in received character");
          tp := false;
        end if;
        dbgi.rdfifo <= '0'; 
        wait until dbgo.rdack = '0';
      end loop;
      dbgi.rxen <= '0';
      tintermediate(tp, tpcounter);
    end ttransmitteroperation;

    procedure treceiverinterrupts is
    begin
      print("--=========================================================--");
      print(" Test receiver interrupt operation  -------------------------");
      print("--=========================================================--");
          
      print("");
      print("---------- Interrupts disabled receive one character -----------");
      print("");
      
      if fifosize > 1 then
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '0' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
      dbgi.txchar <= X"01";
      dbgi.wrfifo <= '1';
      wait until dbgo.wrack = '1';
      dbgi.wrfifo <= '0';
      wait until dbgo.wrack = '0';
      wait until dbgo.txdone = '1';
      wait for (1000000000/rate)*1 ns;

      if fifosize > 1 then
        c := conv_std_logic_vector(1, 6) &  -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             conv_std_logic(fifosize = 2) & -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '1';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '1';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c := X"00000001";
      at_comp_32(datareg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);

      if fifosize > 1 then
        c := conv_std_logic_vector(0, 6) &  -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      
      if irqdetected = '1' then
        print("ERROR: Interrupt generated when disabled");
        tp := false;
      end if;

      print("");
      print("---------- Interrupts enabled receive one character -----------");
      print("");
           
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '1' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
      
      dbgi.txchar <= X"02";
      dbgi.wrfifo <= '1';
      wait until dbgo.wrack = '1';
      dbgi.wrfifo <= '0';
      wait until dbgo.wrack = '0';
      wait until dbgo.txdone = '1';
      time0 := now;
      wait until apbo(pindex).pirq(pirq) = '1';
      time1 := now;

      if (time1-time0) > (1000000000/rate)*1 ns then
        print("ERROR: interrupt was generated too late");
        tp := false;
      end if;
      
      wait for (1000000000/rate)*1 ns;

      if fifosize > 1 then
        c := conv_std_logic_vector(1, 6) &  -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             conv_std_logic(fifosize = 2) & -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '1';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '1';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c := X"00000002";
      at_comp_32(datareg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);

      if fifosize > 1 then
        c := conv_std_logic_vector(0, 6) &  -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      
      if irqdetected = '0' then
        print("ERROR: Interrupt not generated when enabled");
        tp := false;
      end if;

      print("");
      print("---------- Interrupts enabled with delayed irq receive one character -----------");
      print("");
           
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '1' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '1' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
      
      dbgi.txchar <= X"03";
      dbgi.wrfifo <= '1';
      wait until dbgo.wrack = '1';
      dbgi.wrfifo <= '0';
      wait until dbgo.wrack = '0';
      wait until dbgo.txdone = '1';
      time0 := now;
      wait until apbo(pindex).pirq(pirq) = '1';
      time1 := now;

      if (time1-time0) < 47*(1000000000/rate)*1 ns then
        print("ERROR: interrupt was generated too early");
        tp := false;
      end if;
            
      if fifosize > 1 then
        c := conv_std_logic_vector(1, 6) &  -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             conv_std_logic(fifosize = 2) & -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '1';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '1';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c := X"00000003";
      at_comp_32(datareg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);

      if fifosize > 1 then
        c := conv_std_logic_vector(0, 6) &  -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '0' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      
      if irqdetected = '0' then
        print("ERROR: Interrupt not generated when enabled");
        tp := false;
      end if;

      print("");
      print("---------- Interrupts enabled with delayed irq, send many ----------");
      print("---------- consecutive characters and check that only --------------");
      print("---------- one interrupt is generated ------------------------------");
      print("");
           
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '1' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '1' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';

      for i in 1 to 32 loop
        dbgi.txchar <= conv_std_logic_vector(i, 8);
        dbgi.wrfifo <= '1';
        wait until dbgo.wrack = '1';
        dbgi.wrfifo <= '0';
        wait until dbgo.wrack = '0';
        wait until dbgo.txdone = '1';
        d(0) := '0';
        while d(0) = '0' loop
          at_read_32(statusreg_c, 0, false, "0011", true, vmode, d, atmi, atmo);
        end loop;
        
        c := X"000000" & conv_std_logic_vector(i, 8);
        at_comp_32(datareg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      end loop;

      if irqdetected = '1' then
        print("ERROR: interrupt generated with delayed irq enabled and more characters incoming");
        tp := false;
      end if;

      time0 := now;
      wait until apbo(pindex).pirq(pirq) = '1';
      time1 := now;

      if (time1-time0) < 46*(1000000000/rate)*1 ns then
        print("ERROR: interrupt was generated too early");
        tp := false;
      end if;

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';

      print("");
      print("---------- Interrupts enabled with delayed irq, fill fifo ----------");
      print("---------- and check that only one interrupt is generated ----------");
      print("");
           
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '1' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '1' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';

      for i in 1 to fifosize loop
        dbgi.txchar <= conv_std_logic_vector(i+10, 8);
        dbgi.wrfifo <= '1';
        wait until dbgo.wrack = '1';
        dbgi.wrfifo <= '0';
        wait until dbgo.wrack = '0';
        wait until dbgo.txdone = '1';

        wait for 12*(1000000000/rate)*1 ns;
      end loop;

      time0 := now;
            
      if irqdetected = '1' then
        print("ERROR: interrupt generated with delayed irq enabled and more characters incoming");
        tp := false;
      end if;

      wait until apbo(pindex).pirq(pirq) = '1' for 40*(1000000000/rate)*1 ns;

      time1 := now;

      if apbo(pindex).pirq(pirq) /= '1' then
        print("ERROR: interrupt not generated on time with delayed irq");
        tp := false;
      end if;
      
      if (time1-time0) < 35*(1000000000/rate)*1 ns then
        print("ERROR: delayed interrupt was generated too early");
        tp := false;
      end if;

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';

      for i in 1 to fifosize loop
        c := X"000000" & conv_std_logic_vector(i+10, 8);
        at_comp_32(datareg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      end loop;

      if fifosize > 1 then
        print("");
        print("---- Interrupts enabled with delayed irq and halffull irq, ----");
        print("---- fill fifo and check that only one interrupt is generated -");
        print("");
           
        c := '0' &                          -- fifos available
             X"0000" & '0' &                -- unused
             '1' &                          -- delay irq enable
             '0' &                          -- break irq enable
             '0' &                          -- debug enable
             '1' &                          -- receiver fifo irq enable
             '0' &                          -- transmitter fifo irq enable
             '0' &                          -- external clock enable
             '0' &                          -- loopback enable
             '0' &                          -- flow control enable
             '0' &                          -- parity enable
             '0' &                          -- parity select
             '0' &                          -- transmit irq enable
             '1' &                          -- receive irq enable
             '0' &                          -- transmit enable
             '1';                           -- receive enable
        at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
        
        clearirq <= '1';
        while irqdetected = '1' loop
          wait on irqdetected;
        end loop;
        clearirq <= '0';

        for i in 1 to fifosize loop
          dbgi.txchar <= conv_std_logic_vector(i+40, 8);
          dbgi.wrfifo <= '1';
          wait until dbgo.wrack = '1';
          dbgi.wrfifo <= '0';
          wait until dbgo.wrack = '0';
          wait until dbgo.txdone = '1';
          
          wait for 12*(1000000000/rate)*1 ns;

          if (i < fifosize/2) then
            if irqdetected = '1' then
              print("ERROR: interrupt generated with delayed irq enabled and more characters incoming");
              tp := false;
            end if;
          else
            if apbo(pindex).pirq(pirq) /= '1' then
              print("ERROR: interrupt not set when fifo halffull and halffull irq is enabled");
              tp := false;
            end if;
          end if;
        end loop;

        for i in fifosize-1 downto 0 loop
          c := X"000000" & conv_std_logic_vector(fifosize-i+40, 8);
          at_comp_32(datareg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);

          if (i >= fifosize/2) then
            if irqdetected = '0' then
              print("ERROR: interrupt not generated when fifo half-full");
              tp := false;
            end if;
          else
            if i = fifosize/2-1 then
              clearirq <= '1';
              while irqdetected = '1' loop
                wait on irqdetected;
              end loop;
              clearirq <= '0';
            end if;
            if apbo(pindex).pirq(pirq) /= '0' then
              print("ERROR: interrupt set when fifo not halffull");
              tp := false;
            end if;
          end if;
        end loop;
        
        wait for 48*(1000000000/rate)*1 ns;
        
        if irqdetected = '1' then
          print("ERROR: interrupt set when fifo not halffull");
          tp := false;
        end if;
      end if;

      print("");
      print("---- Interrupts enabled with halffull irq but no delayed irq,--");
      print("---- fill fifo and check that interrupts are generated for each");
      print("---- char -----------------------------------------------------");
      print("");
      
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '1' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '1' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
        
      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';
      
      for i in 1 to fifosize loop
        dbgi.txchar <= conv_std_logic_vector(i+40, 8);
        dbgi.wrfifo <= '1';
        wait until dbgo.wrack = '1';
        dbgi.wrfifo <= '0';
        wait until dbgo.wrack = '0';
        wait until dbgo.txdone = '1';
        
        if (i < fifosize/2) then
          wait until apbo(pindex).pirq(pirq) = '1' for 12*(1000000000/rate)*1 ns;
          if apbo(pindex).pirq(pirq) /= '1' then
            print("ERROR: interrupt not generated for each character without delayed irq");
            tp := false;
          end if;
        elsif fifosize > 1 then
          wait for 2*sysperiod_c+(2*(1000000000/rate))*1 ns;
          if apbo(pindex).pirq(pirq) /= '1' then
            print("ERROR: interrupt not set when fifo halffull and halffull irq is enabled");
            tp := false;
          end if;
        end if;
      end loop;
      
      wait for 48*(1000000000/rate)*1 ns;
      
      if fifosize = 1 then
        if apbo(pindex).pirq(pirq) = '1' then
          print("ERROR: interrupt continuosly set without rx fifos");
          tp := false;
        end if;  
      end if;


      for i in fifosize-1 downto 0 loop
        c := X"000000" & conv_std_logic_vector(fifosize-i+40, 8);
        at_comp_32(datareg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      end loop;


      print("");
      print("---- Check break interrupts--");
      print("");
      
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '0' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
        
      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';
      
      dbgi.sndbreak <= '1';
      wait until dbgo.breakack = '1';
      dbgi.sndbreak <= '0';
      wait until dbgo.breakack = '0';
      wait until dbgo.txdone = '1';
        
      wait for 2*(1000000000/rate)*1 ns;

      if irqdetected = '1' then
        print("ERROR: interrupt generated for break character when not enabled");
        tp := false;
      end if;

      if fifosize > 1 then
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c(3) := '0';
      at_write_32(statusreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '1' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';
      
      dbgi.sndbreak <= '1';
      wait until dbgo.breakack = '1';
      dbgi.sndbreak <= '0';
      wait until dbgo.breakack = '0';
      wait until dbgo.txdone = '1';
        
      wait for 2*(1000000000/rate)*1 ns;

      if irqdetected = '0' then
        print("ERROR: interrupt not generated for break character when enabled");
        tp := false;
      end if;

      if fifosize > 1 then
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c(3) := '0';
      at_write_32(statusreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);


      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '1' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '0' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';
      
      dbgi.sndbreak <= '1';
      wait until dbgo.breakack = '1';
      dbgi.sndbreak <= '0';
      wait until dbgo.breakack = '0';
      wait until dbgo.txdone = '1';
        
      wait for 2*(1000000000/rate)*1 ns;

      if irqdetected = '0' then
        print("ERROR: interrupt not generated for break character when enabled");
        tp := false;
      end if;

      if fifosize > 1 then
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c(3) := '0';
      at_write_32(statusreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);


      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '1' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '1' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';
      
      dbgi.sndbreak <= '1';
      wait until dbgo.breakack = '1';
      dbgi.sndbreak <= '0';
      wait until dbgo.breakack = '0';
      wait until dbgo.txdone = '1';
        
      wait for 2*(1000000000/rate)*1 ns;

      if irqdetected = '0' then
        print("ERROR: interrupt not generated for break character when enabled");
        tp := false;
      end if;

      if fifosize > 1 then
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c(3) := '0';
      at_write_32(statusreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);


      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '1' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '0' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';
      
      dbgi.sndbreak <= '1';
      wait until dbgo.breakack = '1';
      dbgi.sndbreak <= '0';
      wait until dbgo.breakack = '0';
      wait until dbgo.txdone = '1';
        
      wait for 2*(1000000000/rate)*1 ns;

      if irqdetected = '1' then
        print("ERROR: interrupt generated for break character when not enabled");
        tp := false;
      end if;

      if fifosize > 1 then
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c(3) := '0';
      at_write_32(statusreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);


      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '1' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '1' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';
      
      dbgi.sndbreak <= '1';
      wait until dbgo.breakack = '1';
      dbgi.sndbreak <= '0';
      wait until dbgo.breakack = '0';
      wait until dbgo.txdone = '1';
        
      wait for 50*(1000000000/rate)*1 ns;

      if irqdetected = '1' then
        print("ERROR: interrupt generated for break character when not enabled");
        tp := false;
      end if;

      if fifosize > 1 then
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c(3) := '0';
      at_write_32(statusreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);


      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '1' &                          -- delay irq enable
           '1' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '1' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';
      
      dbgi.sndbreak <= '1';
      wait until dbgo.breakack = '1';
      dbgi.sndbreak <= '0';
      wait until dbgo.breakack = '0';
      wait until dbgo.txdone = '1';
        
      wait for (1000000000/rate)*1 ns;

      if irqdetected = '0' then
        print("ERROR: interrupt not generated for break character when enabled");
        tp := false;
      end if;

      if fifosize > 1 then
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c(3) := '0';
      at_write_32(statusreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);


      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '1' &                          -- delay irq enable
           '1' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '0' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '1';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';
      
      dbgi.sndbreak <= '1';
      wait until dbgo.breakack = '1';
      dbgi.sndbreak <= '0';
      wait until dbgo.breakack = '0';
      wait until dbgo.txdone = '1';
        
      wait for (1000000000/rate)*1 ns;

      if irqdetected = '0' then
        print("ERROR: interrupt not generated for break character when enabled");
        tp := false;
      end if;

      if fifosize > 1 then
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '1' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      else
        c := "000000" &      -- receiver fifo count
             "000000" &      -- transmitter fifo count
             "000000000" &   -- unused
             '0' &           -- receiver fifo full
             '0' &           -- transmitter fifo full
             '0' &           -- receiver fifo half-full
             '0' &           -- transmitter fifo half-full
             '0' &           -- frame received
             '0' &           -- parity error
             '0' &           -- overflow
             '1' &           -- break received
             '1' &           -- transmitter holding register empty
             '1' &           -- transmitter shift register empty
             '0';            -- received data available
      end if;
      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
      c(3) := '0';
      at_write_32(statusreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

      tintermediate(tp, tpcounter);
    end treceiverinterrupts;

    procedure ttransmittershiftregisterinterrupt is
    begin
      print("--=========================================================--");
      print(" Test transmitter shift register empty interrupt operation --");
      print("--=========================================================--");
      rate := 262144;
      dbgi.baudrate <= rate; dbgi.rxen <= '1';
      scaler := 1000000000/(rate*8*sysperiod_g);
      c := X"00000" & conv_std_logic_vector(scaler, 12);
      at_write_32(scalerreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
      at_comp_32(scalerreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);

      c := "000000" &      -- receiver fifo count
           "000000" &      -- transmitter fifo count
           "000000000" &   -- unused
           '0' &           -- receiver fifo full
           '0' &           -- transmitter fifo full
           '0' &           -- receiver fifo half-full
           '1' &           -- transmitter fifo half-full
           '0' &           -- frame received
           '0' &           -- parity error
           '0' &           -- overflow
           '0' &           -- break received
           '1' &           -- transmitter holding register empty
           '1' &           -- transmitter shift register empty
           '0';            -- received data available

      at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);

      clearirq <= '1';
      while irqdetected = '1' loop
        wait on irqdetected;
      end loop;
      clearirq <= '0';

      d := X"000000" & conv_std_logic_vector(5, 8);
      at_write_32(datareg_c, d, 0, false, "0011", true, vmode, atmi, atmo);
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '0' &                          -- receive irq enable
           '1' &                          -- transmit enable
           '0';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
      wait until dbgo.gotchar = '1';
      wait until dbgo.gotchar = '0';
      dbgi.rdfifo <= '1';
      wait until dbgo.rdack = '1';
      dbgi.rdfifo <= '0';
      wait until dbgo.rdack = '0';

      if irqdetected = '1' then
        print("ERROR: Irq detected when not enabled");
        tp := false;
      end if;
      
      wait for (1500000000/rate)*1 ns;
      
      c := '0' &                          -- fifos available
           X"0000" & '0' &                -- unused
           '0' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '0' &                          -- receive irq enable
           '0' &                          -- transmit enable
           '0';                           -- receive enable
      at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
      
      for i in 1 to fifosize loop
        print("iteration: " & tost(i));
        clearirq <= '1';
        while irqdetected = '1' loop
          wait on irqdetected;
        end loop;
        clearirq <= '0';
        print("transmit");
        for j in 0 to i-1 loop
          d := X"000000" & conv_std_logic_vector(j, 8);
          at_write_32(datareg_c, d, 0, false, "0011", true, vmode, atmi, atmo);
        end loop;
        if fifosize > 1 then
          if i >= fifosize/2 then
            halffull := 0;
          else
            halffull := 1;
          end if;
          c := "000000" &                     -- receiver fifo count
               conv_std_logic_vector(i, 6) &  -- transmitter fifo count
               "000000000" &                  -- unused
               '0' &                          -- receiver fifo full
               conv_std_logic(fifosize = i) & -- transmitter fifo full
               '0' &                          -- receiver fifo half-full
               conv_std_logic(halffull = 1) & -- transmitter fifo half-full
               '0' &                          -- frame received
               '0' &                          -- parity error
               '0' &                          -- overflow
               '0' &                          -- break received
               '0' &                          -- transmitter holding register empty
               '1' &                          -- transmitter shift register empty
               '0';                           -- received data available
        else
          c := "000000" &      -- receiver fifo count
               "000000" &      -- transmitter fifo count
               "000000000" &   -- unused
               '0' &           -- receiver fifo full
               '0' &           -- transmitter fifo full
               '0' &           -- receiver fifo half-full
               '0' &           -- transmitter fifo half-full
               '0' &           -- frame received
               '0' &           -- parity error
               '0' &           -- overflow
               '0' &           -- break received
               '0' &           -- transmitter holding register empty
               '1' &           -- transmitter shift register empty
               '0';            -- received data available
        end if;
        at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
        c := '0' &                          -- fifos available
           X"0000" &                      -- unused
           '1' &                          -- transmitter shift register empty irq enable
           '0' &                          -- delay irq enable
           '0' &                          -- break irq enable
           '0' &                          -- debug enable
           '0' &                          -- receiver fifo irq enable
           '0' &                          -- transmitter fifo irq enable
           '0' &                          -- external clock enable
           '0' &                          -- loopback enable
           '0' &                          -- flow control enable
           '0' &                          -- parity enable
           '0' &                          -- parity select
           '0' &                          -- transmit irq enable
           '0' &                          -- receive irq enable
           '1' &                          -- transmit enable
           '0';                           -- receive enable
        at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);

        print("read");
        for j in i-1 downto 0 loop
          wait until dbgo.gotchar = '1';
          wait until dbgo.gotchar = '0';
          if j = 0 then
            wait for (1500000000/rate)*1 ns; 
          end if;
          if fifosize > 1 then
            if j >= fifosize/2 then
              halffull := 0;
            else
              halffull := 1;
            end if;
            c := "000000" &                   -- receiver fifo count
               conv_std_logic_vector(j, 6) &  -- transmitter fifo count
               "000000000" &                  -- unused
               '0' &                          -- receiver fifo full
               conv_std_logic(j = fifosize) & -- transmitter fifo full
               '0' &                          -- receiver fifo half-full
               conv_std_logic(halffull = 1) & -- transmitter fifo half-full
               '0' &                          -- frame received
               '0' &                          -- parity error
               '0' &                          -- overflow
               '0' &                          -- break received
               conv_std_logic(j = 0) &        -- transmitter holding register empty
               conv_std_logic(j = 0) &        -- transmitter shift register empty
               '0';                           -- received data available
          else
            c := "000000" &      -- receiver fifo count
                 "000000" &      -- transmitter fifo count
                 "000000000" &   -- unused
                 '0' &           -- receiver fifo full
                 '0' &           -- transmitter fifo full
                 '0' &           -- receiver fifo half-full
                 '0' &           -- transmitter fifo half-full
                 '0' &           -- frame received
                 '0' &           -- parity error
                 '0' &           -- overflow
                 '0' &           -- break received
                 '1' &           -- transmitter holding register empty
                 '1' &           -- transmitter shift register empty
                 '0';            -- received data available
          end if;
          at_comp_32(statusreg_c, c, 0, false, "0011", true, vmode, tp, d, atmi, atmo);
          if j > 0 then
            if irqdetected = '1' then
              print("ERROR: Interrupt detected when shift register should not be empty");
              tp := false;
            end if;
          else
            if irqdetected = '0' then
              print("ERROR: Interrupt not detected when shift register should be empty");
              tp := false;
            end if;
          end if;
          dbgi.rdfifo <= '1';
          wait until dbgo.rdack = '1';
          if conv_integer(dbgo.rxchar) /= i-1-j then
            print("ERROR: Wrong character received. Expected: " & tost(i-1-j) & " Got: " & tost(dbgo.rxchar));
            tp := false;
          end if;
          if dbgo.parerr = '1' then
            print("ERROR: Parity error detected in received character");
            tp := false;
          end if;
          dbgi.rdfifo <= '0'; 
          wait until dbgo.rdack = '0';
        end loop;
        c := '0' &                          -- fifos available
              X"0000" &                      -- unused
              '1' &                          -- transmitter shift register empty irq enable
              '0' &                          -- delay irq enable
              '0' &                          -- break irq enable
              '0' &                          -- debug enable
              '0' &                          -- receiver fifo irq enable
              '0' &                          -- transmitter fifo irq enable
              '0' &                          -- external clock enable
              '0' &                          -- loopback enable
              '0' &                          -- flow control enable
              '0' &                          -- parity enable
              '0' &                          -- parity select
              '0' &                          -- transmit irq enable
              '0' &                          -- receive irq enable
              '0' &                          -- transmit enable
              '0';                           -- receive enable
        at_write_32(ctrlreg_c, c, 0, false, "0011", true, vmode, atmi, atmo);
        print("");
      end loop;
            
      dbgi.rxen <= '0';
      tintermediate(tp, tpcounter);
    end ttransmittershiftregisterinterrupt;
     
  begin
    tinitialise(tp, tpcounter);
    treset;
    tregisterresetvalues;
    tbaudrategeneration;
    ttransmitteroperation;
    treceiverinterrupts;
    ttransmittershiftregisterinterrupt;
    tterminate(tp, tpcounter);
  end process;
  
end architecture;
 
