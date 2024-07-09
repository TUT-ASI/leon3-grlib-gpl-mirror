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
  -- Signals ------------------------------------------
  -----------------------------------------------------

  signal clk            : std_ulogic := '0';
  signal system_rst     : std_ulogic;

  signal gnd            : std_ulogic := '0';
  signal vcc            : std_ulogic := '1';

  signal uart_tx        : std_ulogic;
  signal uart_rx        : std_ulogic := '1';
  signal uart_ctsn      : std_ulogic := '0';
  signal uart_rtsn      : std_ulogic := '0';

  signal duart_tx       : std_ulogic;
  signal duart_rx       : std_ulogic;

  signal gpio           : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);

  signal emdio          : std_logic;
  signal etx_clk        : std_ulogic;
  signal erx_clk        : std_ulogic;
  signal erxd           : std_logic_vector(3 downto 0);   
  signal erx_dv         : std_ulogic; 
  signal erx_er         : std_ulogic; 
  signal erx_col        : std_ulogic;
  signal erx_crs        : std_ulogic;
  signal etxd           : std_logic_vector(3 downto 0);   
  signal etx_en         : std_ulogic; 
  signal etx_er         : std_ulogic; 
  signal emdc           : std_ulogic;
  signal emdintn        : std_ulogic;
  signal gtx_clk        : std_logic := '0';
  signal erxd_tmp       : std_logic_vector(7 downto 0);   
  signal etxd_tmp       : std_logic_vector(7 downto 0);   

  signal dmen           : std_ulogic; 
  signal dmbreak        : std_ulogic; 
  signal dmreset        : std_ulogic; 
  signal cpu0errn       : std_logic; 


begin

  -----------------------------------------------------
  -- Clocks and Reset ---------------------------------
  -----------------------------------------------------

  clk         <= not clk after 5 ns;
  system_rst  <= '0', '1' after 200 ns;

  -----------------------------------------------------
  -- Misc ---------------------------------------------
  -----------------------------------------------------

  cpu0errn    <= 'H'; -- ERROR pull-up
  dmen        <= '1';

  -----------------------------------------------------
  -- Top ----------------------------------------------
  -----------------------------------------------------

  cpu : entity work.noelvmp
    generic map(
      fabtech           => fabtech,
      memtech           => memtech,
      padtech           => padtech,
      clktech           => clktech,
      disas             => disas,
      SIMULATION        => 1,
      romfile           => romfile,
      ramfile           => ramfile
      )
    port map(
      reset             => system_rst,
      clk               => clk,
      gpio              => gpio,
      emdio             => emdio,
      etx_clk           => etx_clk,
      erx_clk           => erx_clk,
      erxd              => erxd,
      erx_dv            => erx_dv,
      erx_er            => erx_er,
      erx_col           => erx_col,
      erx_crs           => erx_crs,
      etxd              => etxd,
      etx_en            => etx_en,
      etx_er            => etx_er,
      emdc              => emdc,
      emdintn           => emdintn,
      uart_rx           => uart_rx,
      uart_tx           => uart_tx,
      uart_ctsn         => uart_ctsn,
      uart_rtsn         => uart_rtsn,
      duart_rx          => duart_rx,
      duart_tx          => duart_tx,
      dmen              => dmen,
      dmbreak           => dmbreak,
      dmreset           => dmreset,
      cpu0errn          => cpu0errn
      );

  phy0 : if (CFG_GRETH = 1) generate
    emdio     <= 'H';
    erxd      <= erxd_tmp(3 downto 0);
    etxd_tmp  <= "0000" & etxd;
    
    p0: phy
      generic map(
        address       => 1,
        base1000_t_fd => 0,
        base1000_t_hd => 0)
      port map(system_rst, emdio, etx_clk, erx_clk, erxd_tmp, erx_dv,
      erx_er, erx_col, erx_crs, etxd_tmp, etx_en, etx_er, emdc, gtx_clk);
  end generate;

  -----------------------------------------------------
  -- Process ------------------------------------------
  -----------------------------------------------------

  iuerr : process
  begin
    wait for 5000 ns;
    if to_x01(cpu0errn) = '1' then
      wait on cpu0errn;
    end if;
    assert (to_x01(cpu0errn) = '1')
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
      constant txp        : time := 80 * 1 ns;
      constant lresp      : boolean := false;
    begin
      txc(dsutx, 16#55#, txp);      -- sync uart
      report "UART synced";
    end;

    procedure duart_dm_wait_busy(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32        : std_logic_vector(31 downto 0);
      variable w64        : std_logic_vector(63 downto 0);
      variable c8         : std_logic_vector(7 downto 0);
      constant txp        : time := 80 * 1 ns;
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
      constant txp        : time := 80 * 1 ns;
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
      constant txp        : time := 80 * 1 ns;
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
      constant txp        : time := 80 * 1 ns;
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
      constant txp        : time := 80 * 1 ns;
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
      constant txp        : time := 80 * 1 ns;
      constant lresp      : boolean := false;
    begin
      txc(dsutx, 16#80#, txp);
      txa(dsutx, 16#FE#, 16#00#, 16#00#, 16#44#, txp);
      rxi(dsurx, w32, txp, lresp);
      print("-- Debug Module Status: Read[0xFE000040]: " & tost(w32));
    end;

  begin
    dmbreak     <= '0';
    duart_rx    <= '1';
    if dm_ctrl /= 0 then

      -- Put the CPU in halt
      dmbreak     <= '1';
      wait until rising_edge(system_rst);
      for i in 0 to 10 loop
        wait until rising_edge(clk);
      end loop;
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

