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
-----------------------------------------------------------------------------
-- Package:     sim
-- File:        sim.vhd
-- Author:      Jiri Gaisler - Gaisler Research
-- Description: Simulation models and functions declarations
------------------------------------------------------------------------------

-- pragma translate_off

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
library grlib;
use grlib.stdlib.all;
use grlib.stdio.all;
use grlib.amba.all;
use grlib.devices.all;
library gaisler;

package sim is

  component sram
      generic (index : integer := 0;		-- Byte lane (0 - 3)
	Abits: Positive := 10;		-- Default 10 address bits (1 Kbyte)
	tacc : integer := 10;		-- access time (ns)
    	fname : string := "ram.dat";	-- File to read from
    	clear : integer := 0);	-- Clear memory
      port (  
        a : in std_logic_vector(abits-1 downto 0);
        D : inout std_logic_vector(7 downto 0);
        CE1 : in std_logic;
        WE : in std_logic;
        OE : in std_logic);
  end component;  

  component sram16
  generic (
    index : integer := 0;		-- Byte lane (0 - 3)
    abits: Positive := 10;		-- Default 10 address bits (1 Kbyte)
    echk : integer := 0;		-- Generate EDAC checksum
    tacc : integer := 10;		-- access time (ns)
    fname : string := "ram.dat");	-- File to read from
  port (  
    a : in std_logic_vector(abits-1 downto 0);
    d : inout std_logic_vector(15 downto 0);
    lb : in std_logic;
    ub : in std_logic;
    ce : in std_logic;
    we : in std_ulogic;
    oe : in std_ulogic);
  end component;     

  component sramft
      generic (index : integer := 0;		-- Byte lane (0 - 3)
	       Abits: Positive := 10;		-- Default 10 address bits (1 Kbyte)
	       tacc : integer := 10;		-- access time (ns)
	       fname : string := "ram.dat");	-- File to read from
      port (  
        a : in std_logic_vector(abits-1 downto 0);
        D : inout std_logic_vector(7 downto 0);
        CE1 : in std_logic;
        WE : in std_logic;
        OE : in std_logic);
  end component;  

  procedure hexread(L : inout line; value:out bit_vector);
  procedure hexread(L : inout line; value:out std_logic_vector);
  function ishex(c : character) return boolean;
  function buskeep(signal v : in std_logic_vector) return std_logic_vector;
  function buskeep(signal c : in std_logic) return std_logic;

  component phy is
    generic(
      address       : integer range 0 to 31 := 0;
      extended_regs : integer range 0 to 1  := 1;
      aneg          : integer range 0 to 1  := 1;
      base100_t4    : integer range 0 to 1  := 0;
      base100_x_fd  : integer range 0 to 1  := 1;
      base100_x_hd  : integer range 0 to 1  := 1;
      fd_10         : integer range 0 to 1  := 1;
      hd_10         : integer range 0 to 1  := 1;
      base100_t2_fd : integer range 0 to 1  := 1;
      base100_t2_hd : integer range 0 to 1  := 1;
      base1000_x_fd : integer range 0 to 1  := 0;
      base1000_x_hd : integer range 0 to 1  := 0;
      base1000_t_fd : integer range 0 to 1  := 1;
      base1000_t_hd : integer range 0 to 1  := 1;
      rmii          : integer range 0 to 1  := 0
      );
    port(
      rstn     : in std_logic;
      mdio     : inout std_logic;
      tx_clk   : out std_logic;
      rx_clk   : out std_logic;
      rxd      : out std_logic_vector(7 downto 0);   
      rx_dv    : out std_logic; 
      rx_er    : out std_logic; 
      rx_col   : out std_logic;
      rx_crs   : out std_logic;
      txd      : in std_logic_vector(7 downto 0);   
      tx_en    : in std_logic; 
      tx_er    : in std_logic; 
      mdc      : in std_logic;
      gtx_clk  : in std_logic
      );
  end component;

  type ata_in_type is record 			--signals from host to device
    csel : std_logic;				--cable select
    cs   : std_logic_vector(1 downto 0); 		--chip select
    --dd   : std_logic_vector(15 downto 0);		--data bus
    dasp : std_logic;				--Device active / slave present
    da   : std_logic_vector(2 downto 0); 	        --device adress
    dmack: std_logic;				--DMA acknowledge
    dior : std_logic;				--I/O read strobe
    diow : std_logic;				--I/O write strobe
    reset: std_logic;				--Reset
  end record;

  constant ATAI_RESET_VECTOR : ata_in_type := ('0',(others=>'0'),'0',
    (others=>'0'),'0','0','0','0');

  type ata_out_type is record 			--signals from device to host
    dmarq: std_logic;				--DMA request
    intrq: std_logic;				--Interrupt request
    iordy: std_logic;				--I/O ready
    pdiag: std_logic;				--Passed diagnostics
  end record;

  constant ATAO_RESET_VECTOR : ata_out_type := ('0','0','1','0');

  component ata_device is
  generic(sector_length: integer :=512; --in bytes
        disk_size: integer :=32; --in sectors
        log2_size : integer :=14; --Log2(sector_length*disk_size), abits
        Tlr : time := 35 ns;
        sramfile : string := "disk.srec"
        );
  port(
  --for convinience, not part of ATA interface
    clk   : in std_logic;
    rst   : in std_logic;
  --interface to host bus adapter
    d     : inout std_logic_vector(15 downto 0) := (others=>'Z');
    atai  : in  ata_in_type := ATAI_RESET_VECTOR;
    atao  : out ata_out_type:= ATAO_RESET_VECTOR);
  end component;

  procedure leon3_subtest(subtest : integer);
  procedure mctrl_subtest(subtest : integer);
  procedure gptimer_subtest(subtest : integer);
  procedure dsu3_subtest(subtest : integer);
  procedure spw_subtest(subtest : integer);
  procedure spictrl_subtest(subtest : integer);
  procedure i2cmst_subtest(subtest : integer);
  procedure uhc_subtest(subtest : integer);
  procedure ehc_subtest(subtest : integer);
  procedure irqmp_subtest(subtest : integer);
  procedure spimctrl_subtest(subtest : integer);
  procedure svgactrl_subtest(subtest : integer);
  procedure apbps2_subtest(subtest : integer);
  procedure i2cslv_subtest(subtest : integer);
  procedure grpwm_subtest(subtest : integer);
  procedure grgpio_subtest(subtest : integer);
  procedure griommu_subtest(subtest : integer);
  procedure l4stat_subtest(subtest : integer);

  procedure call_subtest(vendorid, deviceid, subtest : integer);
  
  component ahbrep
  generic (
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#fff#;
    halt    : integer := 1); 
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type
  );
  end component;

  component i2c_slave_model
    port (
      scl : inout std_logic;
      sda : inout std_logic
      );
  end component;

  component grusbdcsim
    generic (
      functm  : integer range 0 to 1 := 0;
      keepclk : integer range 0 to 1 := 0);
    port (
      rst     : in    std_ulogic;
      clk     : out   std_ulogic;
      d       : inout std_logic_vector(7 downto 0);
      nxt     : out   std_ulogic;
      stp     : in    std_ulogic;
      dir     : out   std_ulogic
    );
  end component;

  type grusb_dcl_debug_data is array (0 to 503) of std_logic_vector(7 downto 0);
  
  component grusb_dclsim
    generic (
      functm  : integer range 0 to 1 := 0;
      keepclk : integer range 0 to 1 := 0);
    port (
      rst    : in    std_ulogic;
      clk    : out   std_ulogic;
      d      : inout std_logic_vector(7 downto 0);
      nxt    : out   std_ulogic;
      stp    : in    std_ulogic;
      dir    : out   std_ulogic;
      delay  : in    std_ulogic := '0';
      dstart : in    std_ulogic;
      drw    : in    std_ulogic;
      daddr  : in    std_logic_vector(31 downto 0);
      dlen   : in    std_logic_vector(14 downto 0);
      ddi    : in    grusb_dcl_debug_data;
      ddone  : out   std_ulogic;
      ddo    : out   grusb_dcl_debug_data);
  end component;
  
  component ulpi
    generic (
      LSDEV      : boolean := false -- Low-Speed device attached
      );
    port (
      clkout  : out   std_ulogic;
      d       : inout std_logic_vector(7 downto 0);
      nxt     : out   std_ulogic;
      stp     : in    std_ulogic;
      dir     : out   std_ulogic;
      resetn  : in    std_ulogic
    );
  end component;

  component utmi
    generic (
      LSDEV      : boolean := false;  -- Low-Speed device attached
      utmi_dw8   : integer            -- Interface data width
      );
    port (
      uclk      : out std_ulogic;
      xcvrsel   : in  std_logic_vector(1 downto 0);
      termsel   : in  std_ulogic;
      suspendm  : in  std_ulogic;
      opmode    : in  std_logic_vector(1 downto 0);
      txvalid   : in  std_ulogic;
      drvvbus   : in  std_ulogic;
      validho   : in  std_ulogic;
      host      : in  std_ulogic;
      utm_rst   : in  std_ulogic;
      linestate : out std_logic_vector(1 downto 0);
      txready   : out std_ulogic;
      rxvalid   : out std_ulogic;
      rxactive  : out std_ulogic;
      rxerror   : out std_ulogic;
      vbusvalid : out std_ulogic;
      validhi   : out std_ulogic;
      hostdisc  : out std_ulogic;
      datah     : inout std_logic_vector(7 downto 0);
      data      : inout std_logic_vector(7 downto 0)
      );
  end component;

  component delay_wire
    generic(
      data_width  : integer := 1;
      delay_atob  : real := 0.0;
      delay_btoa  : real := 0.0
      );
    port(
      a : inout std_logic_vector(data_width-1 downto 0);
      b : inout std_logic_vector(data_width-1 downto 0)
      );
  end component;

  component spi_flash
    generic (
      ftype      : integer := 0;               -- Flash type
      debug      : integer := 0;               -- Debug output
      fname      : string  := "prom.srec";     -- File to read from
      readcmd    : integer := 16#0B#;          -- SPI memory device read command
      dummybyte  : integer := 1;
      dualoutput : integer := 0);
    port (
      sck : in    std_ulogic;
      di  : inout std_logic;
      do  : inout std_logic;
      csn : inout std_logic;
      -- Test control inputs
      sd_cmd_timeout  : in std_ulogic := '0';
      sd_data_timeout : in std_ulogic := '0'
      );
  end component;

  component pwm_check
    port (
      clk     : in    std_ulogic;
      address : in    std_logic_vector(21 downto 2);
      data    : inout std_logic_vector(31 downto 0);
      iosn    : in    std_ulogic;
      oen     : in    std_ulogic;
      writen  : in    std_ulogic;
      pwm     : in    std_logic_vector(15 downto 0)
      );
  end component;

  procedure ps2_device (
    signal clk      : inout std_logic;
    signal data     : inout std_logic;
    -- Configuration
    constant DELAY  : in time := 40 us
    );

  procedure grusb_dcl_read (
    signal   clk   : in  std_ulogic;
    signal   rw    : out std_ulogic;
    signal   start : out std_ulogic;
    signal   done  : in  std_ulogic
    );
  
  procedure grusb_dcl_write (
    signal   clk   : in  std_ulogic;
    signal   rw    : out std_ulogic;
    signal   start : out std_ulogic;
    signal   done  : in  std_ulogic
    );
  
end;

package body sim is

  -----------------------------------------------------------------------------
  -- Helper functions
  -----------------------------------------------------------------------------
  function to_xlhz(i : std_logic) return std_logic is
  begin
    case to_X01Z(i) is
    when 'Z' => return('Z');
    when '0' => return('L');
    when '1' => return('H');
    when others => return('X');
    end case;
  end;

  type logic_xlhz_table IS ARRAY (std_logic'LOW TO std_logic'HIGH) OF std_logic;

  constant cvt_to_xlhz : logic_xlhz_table := (
                         'Z',  -- 'U'
                         'Z',  -- 'X'
                         'L',  -- '0'
                         'H',  -- '1'
                         'Z',  -- 'Z'
                         'Z',  -- 'W'
                         'L',  -- 'L'
                         'H',  -- 'H'
                         'Z'   -- '-'
                        );
  function buskeep (signal v : in std_logic_vector) return std_logic_vector is
  variable res : std_logic_vector(v'range);
  begin
    for i in v'range loop res(i) := cvt_to_xlhz(v(i)); end loop;
    return(res);
  end;

  function buskeep (signal c : in std_logic) return std_logic is
  begin
    return(cvt_to_xlhz(c));
  end;

  procedure char2hex(C: character; result: out bit_vector(3 downto 0);
            good: out boolean; report_error: in boolean) is
  begin
    good := true;
    case C is
    when '0' => result :=  x"0"; 
    when '1' => result :=  x"1"; 
    when '2' => result :=  X"2"; 
    when '3' => result :=  X"3"; 
    when '4' => result :=  X"4"; 
    when '5' => result :=  X"5"; 
    when '6' => result :=  X"6"; 
    when '7' => result :=  X"7"; 
    when '8' => result :=  X"8"; 
    when '9' => result :=  X"9"; 
    when 'A' => result :=  X"A"; 
    when 'B' => result :=  X"B"; 
    when 'C' => result :=  X"C"; 
    when 'D' => result :=  X"D"; 
    when 'E' => result :=  X"E"; 
    when 'F' => result :=  X"F"; 

    when 'a' => result :=  X"A"; 
    when 'b' => result :=  X"B"; 
    when 'c' => result :=  X"C"; 
    when 'd' => result :=  X"D"; 
    when 'e' => result :=  X"E"; 
    when 'f' => result :=  X"F"; 
    when others =>
      if report_error then
        assert false report 
	  "hexread error: read a '" & C & "', expected a hex character (0-F).";
      end if;
      good := false;
    end case;
  end;

  procedure hexread(L:inout line; value:out bit_vector)  is
                variable OK: boolean;
                variable C:  character;
                constant NE: integer := value'length/4;	--'
                variable BV: bit_vector(0 to value'length-1);	--'
                variable S:  string(1 to NE-1);
  begin
    if value'length mod 4 /= 0 then	--'
      assert false report
        "hexread Error: Trying to read vector " &
        "with an odd (non multiple of 4) length";
      return;
    end if;
 
    loop                                    -- skip white space
      read(L,C);
      exit when ((C /= ' ') and (C /= CR) and (C /= HT));
    end loop;
 
    char2hex(C, BV(0 to 3), OK, false);
    if not OK then
      return;
    end if;
 
    read(L, S, OK);
--    if not OK then
--      assert false report "hexread Error: Failed to read the STRING";
--      return;
--    end if;
 
    for I in 1 to NE-1 loop
      char2hex(S(I), BV(4*I to 4*I+3), OK, false);
      if not OK then
        return;
      end if;
    end loop;
    value := BV;
  end hexread;

  procedure hexread(L:inout line; value:out std_ulogic_vector) is
    variable tmp: bit_vector(value'length-1 downto 0);	--'
  begin
    hexread(L, tmp);
    value := TO_X01(tmp);
  end hexread;

  procedure hexread(L:inout line; value:out std_logic_vector) is
    variable tmp: std_ulogic_vector(value'length-1 downto 0);	--'
  begin
    hexread(L, tmp);
    value := std_logic_vector(tmp);
  end hexread;

  function ishex(c:character) return boolean is
  variable tmp : bit_vector(3 downto 0);
  variable OK : boolean;
  begin
    char2hex(C, tmp, OK, false);
    return OK;
  end ishex;

  -----------------------------------------------------------------------------
  -- Subtest print out
  -----------------------------------------------------------------------------
  procedure gptimer_subtest(subtest : integer) is
  begin

    case subtest is
    when 0 | 1 | 2 | 3 | 4 | 5 | 6  => print("  timer " & tost(subtest+1));
    when 8  => print("  chain mode");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure leon3_subtest(subtest : integer) is
  begin

    case (subtest mod 16) is
    when 3 => print("  CPU#" & (tost(subtest/16)) & " register file");
    when 4 => print("  CPU#" & (tost(subtest/16)) & " multiplier");
    when 5 => print("  CPU#" & (tost(subtest/16)) & " radix-2 divider");
    when 6 => print("  CPU#" & (tost(subtest/16)) & " cache system");
    when 7 => print("  CPU#" & (tost(subtest/16)) & " multi-processing");
    when 8 => print("  CPU#" & (tost(subtest/16)) & " floating-point unit");
    when 9 => print("  CPU#" & (tost(subtest/16)) & " itag cache ram");
    when 10 => print("  CPU#" & (tost(subtest/16)) & " dtag cache ram");
    when 11 => print("  CPU#" & (tost(subtest/16)) & " idata cache ram");
    when 12 => print("  CPU#" & (tost(subtest/16)) & " ddata cache ram");
    when 13 => print("  CPU#" & (tost(subtest/16)) & " GRFPU test");
    when 14 => print("  CPU#" & (tost(subtest/16)) & " memory management unit");
    when 15 => print("  CPU#" & (tost(subtest/16)) & " CASA");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure mctrl_subtest(subtest : integer) is
  begin

    case subtest is
    when 3 => print("  sub-word write");
    when 4 => print("  EDAC");
    when 5 => print("  write protection");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure dsu3_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  AHB trace buffer memory (0x55555555)");
    when 2 => print("  AHB trace buffer memory (0xAAAAAAAA)");
    when 3 => print("  AHB trace buffer addressing");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure spw_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  Nominal operation, snooping enabled");
    when 2 => print("  Nominal operation, snooping disabled");
    when 3 => print("  RMAP packet reception");
    when 4 => print("  Time functionality");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure spictrl_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  APB interface reset values");
    when 2 => print("  Loopback mode");
    when 3 => print("  AM Loopback mode");
    when 4 => print("  External device test");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure i2cmst_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  APB interface reset values");
    when 2 => print("  Data transfer");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure uhc_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  I/O register reset values");
    when 2 => print("  Host Controller Reset");
    when 3 => print("  Isochronous IN and OUT");
    when 4 => print("  Control OUT, Bulk IN");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;
  
  procedure ehc_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  Register reset values");
    when 2 => print("  Host Controller Reset");
    when 3 => print("  Periodic schedule");
    when 4 => print("  Asynchronous schedule");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;
  procedure irqmp_subtest(subtest : integer) is
  begin

    case subtest is
    when 0 to 15 => print("  Testing internal controller " & tost(subtest));
    when 16 =>  print("  Testing timestamping using GPIO port");
    when 17 =>  print("  Testing watchdog functionality");
    when others => print("  sub-system test " & tost(subtest));
    end case;
    
  end;

  procedure spimctrl_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  Initial values");
    when 2 => print("  User mode transfer");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure svgactrl_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  Check available clocks");
    when 2 => print("  Draw screen");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;
  
  procedure apbps2_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  Transmit test");
    when 2 => print("  Receive test");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure i2cslv_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  Register interface");
    when 2 => print("  Combined I2CMST/I2CSLV test"); 
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure grpwm_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  Asymmetric PWM test");
    when 2 => print("  Symmetric PWM test");
    when 3 => print("  Waveform PWM test (asymmetric)");
    when 4 => print("  Waveform PWM test (symmetric)");
    when others =>
      -- 247 - 255 if used for configuring pwm_check
      if subtest < 247 then
        print("  sub-system test " & tost(subtest));
      end if;
    end case;

  end;

  procedure grgpio_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  IN, OUT and DIR registers");
    when 2 => print("  Interrupt generation"); 
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure griommu_subtest(subtest : integer) is
  begin

    case subtest is
    when 1 => print("  Register interface");
    when 2 => print("  Cache flush");
    when 3 => print("  Diagnostic cache accesses");
    when 4 => print("  Fault tolerance");
    when others => print("  sub-system test " & tost(subtest));
    end case;

  end;

  procedure l4stat_subtest(subtest : integer) is
  begin

    print("  testing counter " & tost(subtest));

  end;

  procedure call_subtest(vendorid, deviceid, subtest : integer) is
  begin
    if vendorid = VENDOR_GAISLER then
      case deviceid is
        when GAISLER_LEON3 | GAISLER_LEON4 | GAISLER_L2CACHE=> leon3_subtest(subtest);
        when GAISLER_FTMCTRL => mctrl_subtest(subtest);
        when GAISLER_GPTIMER => gptimer_subtest(subtest);
        when GAISLER_LEON3DSU => dsu3_subtest(subtest);
        when GAISLER_SPW => spw_subtest(subtest);
        when GAISLER_SPICTRL => spictrl_subtest(subtest); 
        when GAISLER_I2CMST => i2cmst_subtest(subtest);
        when GAISLER_UHCI => uhc_subtest(subtest);
        when GAISLER_EHCI => ehc_subtest(subtest);                    
        when GAISLER_IRQMP => irqmp_subtest(subtest);                    
        when GAISLER_SPIMCTRL => spimctrl_subtest(subtest);                      
        when GAISLER_SVGACTRL => svgactrl_subtest(subtest);
        when GAISLER_APBPS2 => apbps2_subtest(subtest);
        when GAISLER_I2CSLV => i2cslv_subtest(subtest);
        when GAISLER_PWM => grpwm_subtest(subtest);
        when GAISLER_GPIO => grgpio_subtest(subtest);
        when GAISLER_GRIOMMU => griommu_subtest(subtest);
        when GAISLER_L4STAT => l4stat_subtest(subtest);
        when others =>
          print ("  subtest " & tost(subtest));
      end case;
    elsif vendorid = VENDOR_ESA then
      case deviceid is
        when ESA_LEON2 => leon3_subtest(subtest);
        when ESA_MCTRL => mctrl_subtest(subtest);
        when ESA_TIMER => gptimer_subtest(subtest);
        when others =>
          print ("subtest " & tost(subtest));
      end case;
    else
      print ("subtest " & tost(subtest));
    end if;
  end;

  
  -----------------------------------------------------------------------------
  -- Simple simulation models
  -----------------------------------------------------------------------------
  
  -- Description: Simple "PS/2" device. When the device receives the data
  --              0xAA it will respond with the bytes 0x5A, 0xA5.
  --              The argument DELAY is the PS/2 clock period / 2
  procedure ps2_device (
    signal   clk    : inout std_logic;
    signal   data   : inout std_logic;
    -- Configuration
    constant DELAY  : in time := 40 us) is
    variable d : std_logic_vector(9 downto 0);
  begin  -- ps2_device
    clk <= 'Z'; data <= 'Z';
    
    loop
      -- Wait for host request-to-send
      wait until clk = '0';
      wait until data = '0';
      wait until clk /= '0';
      wait for DELAY;
      
      -- Generate clock and shift in data
      for i in 0 to 9 loop
        wait for DELAY/2;
        clk <= '0';
        wait for DELAY;
        clk <= 'Z';
        d(i) := data;
        wait for DELAY/2;
      end loop;  -- i = 0
      
      -- Acknowledge data
      data <= '0';
      wait for DELAY/2;
      clk <= '0'; 
      wait for DELAY;
      clk <= 'Z'; data <= 'Z';

      -- Check parity
      assert xorv(d(7 downto 0)) /= d(8)
        report "Wrong parity on PS/2 bus" severity warning;

      -- Continue if data is not 0xAA
      if d(7 downto 0) /= conv_std_logic_vector(16#AA#, 8) then next; end if;

      wait for 2*DELAY;
      
      -- Transmit two byte response
      d(8) := '1'; d(7 downto 0) := conv_std_logic_vector(16#A5#, 8); 
      for i in 0 to 1 loop
        d(7 downto 0) := d(3 downto 0) & d(7 downto 4);
        
        data <= '0'; clk <= '0';
        wait for DELAY;
        clk <= 'Z';
        
        for j in 0 to 8 loop
          wait for DELAY/2;
          data <= d(j);
          wait for DELAY/2;
          clk <= '0';
          wait for DELAY;
          clk <= 'Z';
        end loop;  -- j

        -- Stop bit
        wait for DELAY/2;
        data <= 'Z';
        wait for DELAY/2;
        clk <= '0';
        wait for DELAY;
        clk <= 'Z';

        -- Insert delay between transmissions
        if i = 0 then wait for 2*DELAY; end if;
      end loop;  -- i
    end loop;
  end ps2_device;

  
  procedure grusb_dcl_read (
    signal   clk   : in  std_ulogic;
    signal   rw    : out std_ulogic;
    signal   start : out std_ulogic;
    signal   done  : in  std_ulogic) is
  begin
    rw <= '0';
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(done);
    start <= '0';
    wait until falling_edge(done);
  end grusb_dcl_read;

  procedure grusb_dcl_write (
    signal   clk   : in  std_ulogic;
    signal   rw    : out std_ulogic;
    signal   start : out std_ulogic;
    signal   done  : in  std_ulogic) is
  begin
    rw <= '1';
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(done);
    start <= '0';
    wait until falling_edge(done);
  end grusb_dcl_write;
  
end;
-- pragma translate_on
