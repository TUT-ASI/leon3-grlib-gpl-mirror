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
-------------------------------------------------------------------------------
-- Entity: spi_flash
-- File:   spi_flash.vhd
-- Author: Jan Andersson - Aeroflex Gaisler AB
--         jan@gaisler.com
--
-- Description: 
--
--     SPI flash simulation models.
--
--     +--------------------------------------------------------+
--     | ftype  |  Memory device                                |
--     +--------+-----------------------------------------------+
--     | 1      |  SD card                                      |
--     +--------+-----------------------------------------------+
--     | 3      |  Simple SPI                                   |
--     +--------+-----------------------------------------------+
--     | 4      |  SPI memory device                            |
--     +--------+-----------------------------------------------+
--     | 5      |  Dynamic Simple SPI memory                    |
--     +--------+-----------------------------------------------+
--
-- For ftype => 4, the memoffset generic can be used to specify an address
-- offset that till be automatically be removed by the memory model. For
-- instance, memoffset => 16#1000# and an access to 0x1000 will read the
-- internal memory array at offset 0x0. This is a quick hack to support booting
-- from SPIMCTRL that has an offset specified and not having to modify the
-- SREC.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library grlib, gaisler;
use grlib.stdlib.all;
use grlib.stdio.all;
--use gaisler.sim.all;
use gaisler.spi.all;-- package with fake commands used in dynamic_flash_spi



entity spi_flash is
  
  generic (
    ftype      : integer := 0;               -- Flash type
    debug      : integer := 0;               -- Debug output
    fname      : string  := "prom.srec";     -- File to read from
    readcmd    : integer := 16#0B#;          -- SPI memory device read command
    dummybyte  : integer := 1;
    dualoutput : integer := 0;
    quadoutput : integer := 0;
    dualinput  : integer := 0;
    quadinput  : integer := 0;
    memoffset  : integer := 0);              -- Addr. offset automatically removed
                                             -- by Flash model
  port (
    sck : in    std_ulogic;
    di  : inout std_logic;
    do  : inout std_logic;
    csn : inout std_logic;
    io2 : inout std_logic;
    io3 : inout std_logic;
    -- Test control inputs
    sd_cmd_timeout  : in std_ulogic := '0';
    sd_data_timeout : in std_ulogic := '0'
    );

end spi_flash;

architecture sim of spi_flash is

  -- Description: Simple, incomplete, model of SD card
  procedure simple_sd_model (
    constant dbg : in integer;
    signal   sck : in  std_ulogic;
    signal   di  : in  std_ulogic;
    signal   do  : out std_ulogic;
    signal   csn : in  std_ulogic;
    -- Test control inputs
    signal cmd_to  : in std_ulogic;     -- force command response timeout
    signal data_to : in std_ulogic) is  -- force data token timeout

    type sd_state_type is (idle, wait_cmd55, wait_acmd41, wait_cmd16,
                           wait_cmd17); 
    type response_type is array (0 to 10) of std_logic_vector(7 downto 0);
    
    variable state            : sd_state_type := idle;
    variable received_command : std_ulogic := '0';
    variable respond          : std_ulogic := '0';
    variable response         : response_type;
    variable resp_size        : integer;
    variable indata           : std_logic_vector(7 downto 0);
    variable command          : std_logic_vector(47 downto 0);
    variable index            : integer;
    variable bcnt             : integer;
    
    constant CMD0   : std_logic_vector(5 downto 0) := "000000";
    constant CMD16  : std_logic_vector(5 downto 0) := "010000";
    constant CMD17  : std_logic_vector(5 downto 0) := "010001";
    constant CMD55  : std_logic_vector(5 downto 0) := "110111";
    constant ACMD41 : std_logic_vector(5 downto 0) := "101001";

    constant R1 : std_logic_vector(7 downto 0) := X"00";
    constant DATA_TOKEN : std_logic_vector(7 downto 0) := X"FE";
    constant DATA_ERR_TOKEN : std_logic_vector(7 downto 0) := X"01";
    
  begin  -- simple_sd_model
    
    loop
      if csn /= '0' then wait until csn = '0'; end if;
      
      index := 0; command := (others => '0');
      -- Receive data
      do <= '1';
      while received_command = '0' and csn = '0' loop
        wait until rising_edge(sck);
        indata := indata(6 downto 0) & di;
        index := index + 1;
        if index = 8 then           -- Received a byte
          command := command(39 downto 0) & indata;
          if dbg /= 0 then
            Print(time'image(now) & ": simple_sd_model: received byte: " &
                  tost(indata));
          end if;
          if (command(47 downto 46) = "01" and command(7 downto 0) = X"95") then
            received_command := '1';
          end if;
          index := 0;
        end if;
      end loop;

      if received_command = '1' then
        case state is
          when idle =>
            if command(45 downto 40) = CMD0 then
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received CMD0");
              end if;
              if cmd_to = '0' then
                state := wait_cmd55;
              end if;
              response(0) := R1;
              response(1) := (others => '1');
              resp_size := 2;
              respond := not cmd_to;
            else
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received unexpected CMD" &
                      tost(conv_integer(command(45 downto 40))));
              end if;
            end if;  

          when wait_cmd55 =>
            if command(45 downto 40) = CMD55 then
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received CMD55");
              end if;
              state := wait_acmd41;
              response(0) := R1;
              response(1) := (others => '1');
              resp_size := 2;
              respond := not cmd_to;
            else
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received unexpected CMD" &
                      tost(conv_integer(command(45 downto 40))));
              end if;
            end if;

          when wait_acmd41 =>
            if command(45 downto 40) = ACMD41 then
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received CMD41");
              end if;
              if cmd_to = '0' then
                state := wait_cmd16;
              else
                state := idle;
              end if;
              response(0) := R1;
              response(1) := (others => '1');
              resp_size := 2;
              respond := not cmd_to;
            else
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received unexpected CMD" &
                      tost(conv_integer(command(45 downto 40))));
              end if;
            end if;

          when wait_cmd16 =>
            if command(45 downto 40) = CMD16 then
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received CMD16");
                Print(time'image(now) & ": simple_sd_model: BLOCKLEN set to " &
                      tost(conv_integer(command(39 downto 8))));
              end if;
              state := wait_cmd17;
              response(0) := R1;
              response(1) := (others => '1');
              resp_size := 2;
              respond := not cmd_to;
            else
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received unexpected CMD" &
                      tost(conv_integer(command(45 downto 40))));
              end if;
            end if;

          when wait_cmd17 =>
            if command(45 downto 40) = CMD17 then
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received CMD17");
                Print(time'image(now) & ": simple_sd_model: Read from address " &
                      tost(conv_integer(command(39 downto 8))));
              end if;
              response(0) := R1;
              response(1) := (others => '1');
              response(2) := (others => '1');
              response(3) := DATA_TOKEN;
              -- Data response is address
              response(4) := command(39 downto 32);
              response(5) := command(31 downto 24);
              response(6) := command(23 downto 16);
              response(7) := command(15 downto 8);
              if data_to = '1' then
                resp_size := 1;
              else
                resp_size := 8;
              end if;
              respond := not cmd_to;
            elsif command(45 downto 40) = CMD0 then
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received CMD0");
              end if;
              if cmd_to = '0' then
                state := wait_cmd55;
              end if;
              response(0) := R1;
              response(1) := (others => '1');
              resp_size := 2;
              respond := not cmd_to;
            else
              if dbg /= 0 then
                Print(time'image(now) & ": simple_sd_model: received unexpected CMD" &
                      tost(conv_integer(command(45 downto 40))));
              end if;
            end if;
        end case;
        received_command := '0';
      end if;
      
      if respond = '1' then
        bcnt := 0;
        while resp_size > bcnt loop
          if dbg /= 0 then
            Print(time'image(now) & ": simple_sd_model: Responding with " &
                  tost(response(bcnt)));
          end if;
          index := 0;
          while index < 8 loop
            wait until falling_edge(sck);
            do <= response(bcnt)(7);
            response(bcnt)(7 downto 1) := response(bcnt)(6 downto 0);
            index := index + 1;
          end loop;
          bcnt := bcnt + 1;
        end loop;
        respond := '0';
        wait until rising_edge(sck);
      else
        do <= '1';
      end if;
    end loop;    
  end simple_sd_model;

  -- purpose: Simple, incomplete, model of SPI Flash device
  procedure simple_spi_flash_model (
    constant dbg        : in    integer;
    constant readcmd    : in    integer;
    constant dummybyte  : in    boolean;
    constant dualoutput : in    boolean;
    constant quadoutput : in    boolean;
    constant dualinput  : in    boolean;
    constant quadinput  : in    boolean;
    signal   sck        : in    std_ulogic;
    signal   di         : inout std_ulogic;
    signal   do         : inout std_ulogic;
    signal   io2        : inout std_ulogic;
    signal   io3        : inout std_ulogic;
    signal   csn        : in    std_ulogic) is

    constant readinst : std_logic_vector(7 downto 0) :=
      conv_std_logic_vector(readcmd, 8);
    
    variable received_command : std_ulogic := '0';
    variable respond          : std_ulogic := '0';

    variable response         : std_logic_vector(31 downto 0);
    variable indata           : std_logic_vector(7 downto 0);
    variable command          : std_logic_vector(31 downto 0);
    variable index            : integer;
    variable inputmode        : integer := 0;
    
    
  begin  -- simple_spi_flash_model
    di <= 'Z'; do <= 'Z'; io2 <= 'Z'; io3 <= 'Z';
    loop 
      if csn /= '0' then wait until csn = '0'; end if;

      index := 0; command := (others => '0'); inputmode := 0;
      while received_command = '0' and csn = '0' loop
        wait until rising_edge(sck);
        case inputmode is
          When 0 => -- Mono
            indata := indata(6 downto 0) & di;
            index := index + 1;
          When 1 => -- Dual
            indata := indata(5 downto 0) & do & di;
            index := index + 2;
          When others => -- Quad
            indata := indata(3 downto 0) & io3 & io2 & do & di;
            index := index + 4;
        end case;
        --DEBUG comment
        --print(tost(indata(7)) & " " & tost(indata(6)) & " " &tost(indata(5)) & " " &tost(indata(4)) & " " &tost(indata(3)) & " " &tost(indata(2)) & " " &tost(indata(1)) & " " &tost(indata(0)));
        if index = 8 then

          if indata = readinst then
            if dualinput then
              inputmode := 1;
            elsif quadinput then
              inputmode := 2;
            end if;
          end if;

          command := command(23 downto 0) & indata;
          print(tost(command));
          if dbg /= 0 then
            Print(time'image(now) & ": simple_spi_flash_model: received byte: " &
                  tost(indata));
          end if;
          if (command(31 downto 24) = readinst) then
            received_command := '1';
          end if;
          index := 0;
        end if;
      end loop;

      if received_command = '1' then
        print("RECEIVED COMMAND"); --DEBUG comment

        if dummybyte then
          if quadinput then
            for i in 0 to 9 loop
              wait until rising_edge(sck);
            end loop;
          else
            for i in 0 to 7 loop
              wait until rising_edge(sck);
            end loop;
          end if;
        end if;

        response := (others => '0');
        response(23 downto 0) := command(23 downto 0);
        index := 31 - conv_integer(response(1 downto 0)) * 8;
        response(1 downto 0) := (others => '0');
        print("Response: " & tost(response)); --DEBUG comment

        while csn = '0' loop
          while index >= 0 and csn = '0' loop
            wait until falling_edge(sck) or csn = '1';
            if quadoutput then
              io3 <= response(index);
              io2 <= response(index-1);
              do  <= response(index-2);
              di  <= response(index-3);
              index := index - 4;
            elsif dualoutput then
              do <= response(index);
              di <= response(index-1);
              index := index - 2;
            else
              do <= response(index);
              index := index - 1;
            end if;
          end loop;
          index := 31;
          response := response + 4;
        end loop;
        if dualoutput or quadoutput then
          di <= 'Z'; io2 <= 'Z'; io3 <= 'Z';
        end if;
        if dualinput or quadinput then
          do <= 'Z'; io2 <= 'Z'; io3 <= 'Z';
        end if;
        received_command := '0';
      else
        do <= '1';
      end if;
    end loop;
  end simple_spi_flash_model;

  
   -- purpose: SPI memory device that reads input from prom.srec
  procedure spi_memory_model (
    constant dbg        : in    integer;
    constant readcmd    : in    integer;
    constant dummybyte  : in    boolean;
    constant dualoutput : in    boolean;
    signal   sck        : in    std_ulogic;
    signal   di         : inout std_ulogic;
    signal   do         : inout std_ulogic;
    signal   csn        : in    std_ulogic) is

    constant readinst : std_logic_vector(7 downto 0) :=
      conv_std_logic_vector(readcmd, 8);
    
    variable received_command : std_ulogic := '0';
    variable respond          : std_ulogic := '0';

    variable response         : std_logic_vector(31 downto 0);
    variable address          : std_logic_vector(23 downto 0);
    variable indata           : std_logic_vector(7 downto 0);
    variable command          : std_logic_vector(39 downto 0);
    variable index            : integer;

    file fload : text open read_mode is fname;
    variable fline : line;
    variable fchar : character; 
    variable rtype : std_logic_vector(3 downto 0);
    variable raddr : std_logic_vector(31 downto 0);
    variable rlen  : std_logic_vector(7 downto 0);
    variable rdata : std_logic_vector(0 to 127);

    variable wordaddr : integer;
    
    type mem_type is array (0 to 8388607) of std_logic_vector(31 downto 0);
    variable mem : mem_type := (others => (others => '1'));
    
  begin  -- spi_memory_model
    di <= 'Z'; do <= 'Z';

    -- Load memory data from file
    while not endfile(fload) loop
      readline(fload, fline);
      read(fline, fchar);
      if fchar /= 'S' or fchar /= 's' then
        hread(fline, rtype);
        hread(fline, rlen);
        raddr := (others => '0');
        case rtype is 
          when "0001" =>
            hread(fline, raddr(15 downto 0));
          when "0010" =>
            hread(fline, raddr(23 downto 0));
          when "0011" =>
            hread(fline, raddr);
            raddr(31 downto 24) := (others => '0');
          when others => next;
        end case;

        hread(fline, rdata);
        for i in 0 to 3 loop
          mem(conv_integer(raddr(31 downto 2)+i)) :=
              rdata(i*32 to i*32+31);
        end loop;
      end if;
    end loop;
    
    loop 
      if csn /= '0' then wait until csn = '0'; end if;

      index := 0; command := (others => '0');
      while received_command = '0' and csn = '0' loop
        wait until sck'event and sck = '1';
        indata := indata(6 downto 0) & di;
        index := index + 1;
        if index = 8 then
          command := command(31 downto 0) & indata;
          if dbg /= 0 then
              Print(time'image(now) & ": spi_memory_model: received byte: " &
                  tost(indata));
          end if;
          if ((dummybyte and command(39 downto 32) = readinst) or
              (not dummybyte and command(31 downto 24) = readinst)) then
            received_command := '1';
          end if;
          index := 0;
        end if;
      end loop;

      if received_command = '1' then
        response := (others => '0');
        if dummybyte then
          address := command(31 downto 8);
        else
          address := command(23 downto 0);
        end if;

        if dbg /= 0 then
          Print(time'image(now) & ": spi_memory_model: received address: " &
                tost(address));
          if memoffset /= 0 then
            Print(time'image(now) & ": spi_memory_model: address after removed offset " &
                tost(address-memoffset));
          end if;
        end if;

        if memoffset /= 0 then
          address := address - memoffset;
        end if;
        
        index := 31 - conv_integer(address(1 downto 0)) * 8;
        while csn = '0' loop
          response := mem(conv_integer(address(23 downto 2)));
          if dbg /= 0 then
            Print(time'image(now) & ": spi_memory_model: responding with data: " &
                  tost(response(index downto 0)));
          end if;
          while index >= 0 and csn = '0' loop
            wait until (sck'event and sck = '0') or csn = '1';
            if dualoutput then
              do <= response(index);
              di <= response(index-1);
              index := index - 2;
            else
              do <= response(index);
              index := index - 1;
            end if;
          end loop;
          index := 31;
          address := address + 4;
        end loop;
        if dualoutput then
          di <= 'Z';
        end if;
        do <= 'Z';
        received_command := '0';
      else
        do <= 'Z';
      end if;
    end loop;
  end spi_memory_model;


    -- purpose: Simple, incomplete, model of SPI Flash device with a dynamic
    -- behaviour/mode based on the read command sent to it
  procedure dynamic_spi_flash_model (
    constant dbg        : in    integer;
    constant readcmd    : in    integer;
    constant dummybyte  : in    boolean;
    constant dualoutput : in    boolean;
    constant quadoutput : in    boolean;
    constant dualinput  : in    boolean;
    constant quadinput  : in    boolean;
    signal   sck        : in    std_ulogic;
    signal   di         : inout std_ulogic;
    signal   do         : inout std_ulogic;
    signal   io2        : inout std_ulogic;
    signal   io3        : inout std_ulogic;
    signal   csn        : in    std_ulogic) is

    

    variable received_command : std_ulogic := '0';
    variable respond          : std_ulogic := '0';

    variable response         : std_logic_vector(31 downto 0);
    variable indata           : std_logic_vector(7 downto 0);
    variable indataint        : integer;
    variable readinst         : std_logic_vector(7 downto 0);
    -- command now has 40 bits to be able to accept 4-byte addr
    variable command          : std_logic_vector(39 downto 0);
    variable index            : integer;
    variable inputmode        : integer := 0;
    variable cmdmode          : integer := 0;-- mode used for command
    variable addrmode         : integer := 0;-- mode used for address
    variable datamode         : integer := 0;-- mode used for data
    variable step             : integer := 0;-- 0 -> command part, 1+ others
    variable spi              : boolean := false;
    variable dpi              : boolean := false;
    variable qpi              : boolean := false;
    variable deltaaddr4b      : integer := 0;
    variable dummycycles      : integer := 0;
    variable fakestatusreg    : std_logic_vector(7 downto 0);
    variable readingstatusreg : boolean := false;
    variable writingstatusreg : boolean := false;


  begin  -- dynamic_spi_flash_model
    spi := true;
    dpi := false;
    qpi := false;
    deltaaddr4b := 0;
    addrmode := 0;
    datamode := 0;
    fakestatusreg := DEFAULTSTATUS;
    readingstatusreg := false;
    writingstatusreg := false;

    di <= 'Z'; do <= 'Z'; io2 <= 'Z'; io3 <= 'Z';
    loop
      if csn /= '0' then wait until csn = '0'; end if;

      readingstatusreg := false;
      writingstatusreg := false;

      if spi then
        cmdmode := 1; --(1,x,y)
        -- addrmode and datamode remain the same as they have been set
      elsif dpi then
        cmdmode := 2; --(2,2,2)
        addrmode := 2;
        datamode := 2;
      elsif qpi then
        cmdmode := 4; --(4,4,4)
        addrmode := 4;
        datamode := 4;
      else
        cmdmode := 1; --(1,x,x), to be decided based on read command
        addrmode := 0;
        datamode := 0;
      end if;

      index := 0; command := (others => '0');
      step := 0;
      indata := (others => '0');
      receiving: while received_command = '0' and csn = '0' loop
        -- loop to receive the whole message
        wait until rising_edge(sck);

        case step is
          when 0 => -- command phase
            inputmode := cmdmode;
          when others => -- address phase
            inputmode := addrmode;
        end case;

        case inputmode is
          When 1 => -- Mono (mosi)
            indata := indata(6 downto 0) & di;
            index := index + 1;
            --if step = 0 then Print("ESPI: " & tost(indata)); end if;
          When 2 => -- Dual (mosi miso)
            indata := indata(5 downto 0) & do & di;
            index := index + 2;
            --if step = 0 then Print("DSPI: " & tost(indata)); end if;
          When others => -- Quad (mosi miso io2 io3) -- value would be 4
            indata := indata(3 downto 0) & io3 & io2 & do & di;
            index := index + 4;
            --if step = 0 then Print("QSPI: " & tost(indata)); end if;
        end case;
        --print(tost(indata(7)) & " " & tost(indata(6)) & " " &tost(indata(5)) & " " &tost(indata(4)) & " " &tost(indata(3)) & " " &tost(indata(2)) & " " &tost(indata(1)) & " " &tost(indata(0)));
        if index = 8 then
          if step = 0 then
            step := step + 1;

            -- when we want to set the dummy cycles to a defined number and
            -- then we use readwithotherdummycycles command.
            -- only for a particular test in spimctrl_tb
            if indata(7 downto 4) = SETDUMMYCYCLES then
              dummycycles := to_integer(unsigned(indata(3 downto 0)));
              exit receiving;
            end if;

            case indata is
              when READSINGLE => -- (1,1,1)
                addrmode := 1;
                datamode := 1;
                dummycycles := 0;
                readinst := indata;
              when READFAST => -- (1,1,1) or (2,2,2) or (4,4,4)
                addrmode := cmdmode;
                datamode := cmdmode;
                if addrmode = 4 then
                  dummycycles := 10;
                else
                  dummycycles := 8;
                end if;
                readinst := indata;
              when READDUALO => -- (1,1,2) or (2,2,2)
                addrmode := cmdmode;
                datamode := 2;
                dummycycles := 8;
                readinst := indata;
              when READDUALIO => -- (1,2,2) or (2,2,2)
                addrmode := 2;
                datamode := 2;
                dummycycles := 8;
                readinst := indata;
              when READQUADO => --(1,1,4) or (4,4,4)
                addrmode := cmdmode;
                datamode := 4;
                if addrmode = 4 then
                  dummycycles := 10;
                else
                  dummycycles := 8;
                end if;
                readinst := indata;
              when READQUADIO => --(1,4,4) or (4,4,4)
                addrmode := 4;
                datamode := 4;
                dummycycles := 10;
                readinst := indata;
              when READWITHOTHERDUMMYCYCLES => -- (1,1,1), (2,2,2) or (4,4,4)
                addrmode := cmdmode;
                datamode := cmdmode;
                -- dummy cycles not set here
                readinst := indata;
              when WRITESTATUSREG =>
                addrmode := cmdmode;
                datamode := cmdmode;
                writingstatusreg := true;
                readinst := indata;
              when READSTATUSREG =>
                addrmode := cmdmode;
                datamode := cmdmode;
                readingstatusreg := true;
                received_command := '1';
                dummycycles := 0;
                exit receiving;
              when RESETREGSTATUS =>
                fakestatusreg := DEFAULTSTATUS;
                exit receiving;
              when GOTOESPI =>
                spi := true;
                dpi := false;
                qpi := false;
                exit receiving;
              when GOTODSPI =>
                spi := false;
                dpi := true;
                qpi := false;
                exit receiving;
              when GOTOQSPI =>
                spi := false;
                dpi := false;
                qpi := true;
                exit receiving;
              when GOTOEXTADDR =>
                deltaaddr4b := 8;
                exit receiving;
              when GOTONRMADDR =>
                deltaaddr4b := 0;
                exit receiving;
              when NOPCMD =>
                exit receiving;
              when others =>
                assert false report "Unsupported read command. CMD received:  " & tost(indata) severity warning;
            end case;
            -- Print(time'image(now) & ": dynamic_spi_flash_model: Mode (" &
            --       tost(cmdmode) & "," & tost(addrmode) & "," & tost(datamode) &
            --       ") and dummy cycles: " & tost(dummycycles));
          end if;

          command(31+deltaaddr4b downto 0) := command(23+deltaaddr4b downto 0) & indata;
        if dbg /= 0 then-- debug prints
          Print(time'image(now) & ": dynamic_spi_flash_model: received byte: " &
                tost(indata));
          Print(time'image(now) & ": dynamic_spi_flash_model: Message so far: " &
                tost(indata));
        end if;
        if writingstatusreg and command(15 downto 8) = readinst then
          fakestatusreg := command(7 downto 0);
          received_command := '0';
          exit receiving;
        elsif (command(31+deltaaddr4b downto 24+deltaaddr4b) = readinst) then
          received_command := '1';
          step := 0;
        end if;
        index := 0;
        step := step + 1;
      end if;
    end loop;

    if received_command = '1' then
      -- print("RECEIVED COMMAND");

      for i in 0 to dummycycles-1 loop
        wait until rising_edge(sck);
      end loop;

      response := (others => '0');
      if readingstatusreg then
        response(7 downto 0) := fakestatusreg;
        index := 7;
      else
        response(23+deltaaddr4b downto 0) := command(23+deltaaddr4b downto 0);
        index := 31 - conv_integer(response(1 downto 0)) * 8;
        response(1 downto 0) := (others => '0');
      end if;
      -- print("Response: " & tost(response));

      while csn = '0' loop
        while index >= 0 and csn = '0' loop
          wait until falling_edge(sck) or csn = '1';
          if datamode = 4 then -- quad output
            io3 <= response(index);
            io2 <= response(index-1);
            do  <= response(index-2);
            di  <= response(index-3);
            index := index - 4;
          elsif datamode = 2 then -- dual output
            do <= response(index);
            di <= response(index-1);
            index := index - 2;
          else -- single output
            do <= response(index);
            index := index - 1;
          end if;
        end loop;
        index := 31;
        response := response + 4;
      end loop;
      if datamode = 2 or datamode = 4 then
        di <= 'Z'; io2 <= 'Z'; io3 <= 'Z';
      end if;
      if addrmode = 2 or addrmode = 4 then
        do <= 'Z'; io2 <= 'Z'; io3 <= 'Z';
      end if;
      received_command := '0';
    else
      do <= 'Z';
    end if;
  end loop;
end dynamic_spi_flash_model;

  
  signal vdd : std_ulogic := '1';
  signal gnd : std_ulogic := '0';
  
begin  -- sim

--   ftype0: if ftype = 0 generate
--     csn <= 'Z';
--     di <= 'Z';
--     flash0 : s25fl064a
--       generic map (tdevice_PU => 1 us,
--                    TimingChecksOn => true,
--                    MsgOn => debug = 1,
--                    UserPreLoad => true)
--       port map (SCK => sck, SI => di, CSNeg => csn, HOLDNeg => vdd,
--                 WNeg => vdd, SO => do);
--   end generate ftype0;

  ftype1: if ftype = 1 generate
    csn <= 'H';
    di <= 'Z';
    simple_sd_model(debug, sck, di, do, csn, sd_cmd_timeout, sd_data_timeout);
  end generate ftype1;

--   ftype2: if ftype = 2 generate
--     csn <= 'Z';
--     di <= 'Z';
--     flash0 : m25p80
--       generic map (TimingChecksOn => false,
--                    MsgOn => debug = 1,
--                    UserPreLoad => true)
--       port map (C => sck, D => di, SNeg => csn, HOLDNeg => vdd,
--                 WNeg => vdd, Q => do);
--   end generate ftype2;

  ftype3: if ftype = 3 generate
    csn <= 'Z';
    simple_spi_flash_model (
      dbg        => debug,
      readcmd    => readcmd,
      dummybyte  => dummybyte /= 0,
      dualoutput => dualoutput /= 0,
      quadoutput => quadoutput /= 0,
      dualinput  => dualinput /= 0,
      quadinput  => quadinput /= 0,
      sck        => sck,
      di         => di,
      do         => do,
      io2        => io2,
      io3        => io3,
      csn        => csn);
  end generate ftype3;

  ftype4: if ftype = 4 generate
    spi_memory_model (
      dbg        => debug,
      readcmd    => readcmd,
      dummybyte  => dummybyte /= 0,
      dualoutput => dualoutput /= 0,
      sck        => sck,
      di         => di,
      do         => do,
      csn        => csn);
    csn <= 'Z';
  end generate ftype4;

  ftype5: if ftype = 5 generate
    csn <= 'Z';
    dynamic_spi_flash_model (
      dbg        => debug,
      readcmd    => readcmd,
      dummybyte  => dummybyte /= 0,
      dualoutput => dualoutput /= 0,
      quadoutput => quadoutput /= 0,
      dualinput  => dualinput /= 0,
      quadinput  => quadinput /= 0,
      sck        => sck,
      di         => di,
      do         => do,
      io2        => io2,
      io3        => io3,
      csn        => csn);
  end generate ftype5;
  
  notsupported: if ftype > 5 generate
    assert false report "spi_flash: no model" severity failure;
  end generate notsupported;
  
end sim;

