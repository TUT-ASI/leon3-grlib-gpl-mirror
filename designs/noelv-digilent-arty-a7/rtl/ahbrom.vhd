
----------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2021 Cobham Gaisler
----------------------------------------------------------------------------
-- Entity:      ahbrom
-- File:        ahbrom.vhd
-- Author:      Jiri Gaisler - Gaisler Research
-- Modified     Alen Bardizbanyan - Cobham Gaisler (pipelined impl.)
-- Description: AHB rom. 0/1-waitstate read
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;

entity ahbrom is
  generic (
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#fff#;
    pipe    : integer := 0;
    tech    : integer := 0;
    kbytes  : integer := 1); 
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type
  );
end;

architecture rtl of ahbrom is
constant abits : integer := 8;
constant bytes : integer := 172;
constant dbits : integer := 32;

constant hconfig : ahb_config_type := (
  0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_AHBROM, 0, 0, 0),
  4 => ahb_membar(haddr, '1', '1', hmask), others => zero32);

signal romdata : std_logic_vector(dbits-1 downto 0);
signal romdatas : std_logic_vector(AHBDW-1 downto 0);
signal addr : std_logic_vector(abits-1 downto 2);
signal hsize : std_logic_vector(2 downto 0);
signal romaddr : std_logic_vector(abits-1 downto log2(dbits/8));
signal hready, active : std_ulogic;

constant RESET_ALL : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

begin

  ahbso.hresp   <= "00";
  ahbso.hsplit  <= (others => '0');
  ahbso.hirq    <= (others => '0');
  ahbso.hconfig <= hconfig;
  ahbso.hindex  <= hindex;

  reg : process (clk)
  begin
    if rising_edge(clk) then
      addr <= ahbsi.haddr(abits-1 downto 2);
      hsize <= ahbsi.hsize;
      if RESET_ALL and rst='0' then addr <= (others => '0'); hsize <= "000"; end if;
    end if;
  end process;

  p0 : if pipe = 0 generate
    ahbso.hrdata  <= romdatas;
    ahbso.hready  <= '1';
    hready <= '0';
  end generate;

  active <= ahbsi.hsel(hindex) and ahbsi.htrans(1) and ahbsi.hready;
  p1 : if pipe = 1 generate
    ahbso.hready <= hready;
    reg2 : process (clk)
    begin
      if rising_edge(clk) then
        hready <= (not rst) or (not active) or (not(hready));
        ahbso.hrdata <= romdatas;
        if RESET_ALL and rst='0' then hready <= '1'; ahbso.hrdata <= (others => '0'); end if;
      end if;
    end process;
  end generate;

  romaddr <= addr(abits-1 downto log2(dbits/8));
  romdatas <= ahbdrivedata(romdata);
  comb : process (romaddr)
  begin
    if ahbsi.endian = '0' then --big endian
      case conv_integer(romaddr) is
        when 16#00000# => romdata <= X"93000000";
        when 16#00001# => romdata <= X"13010000";
        when 16#00002# => romdata <= X"93010000";
        when 16#00003# => romdata <= X"13020000";
        when 16#00004# => romdata <= X"93020000";
        when 16#00005# => romdata <= X"13030000";
        when 16#00006# => romdata <= X"93030000";
        when 16#00007# => romdata <= X"13040000";
        when 16#00008# => romdata <= X"93040000";
        when 16#00009# => romdata <= X"13050000";
        when 16#0000A# => romdata <= X"93050000";
        when 16#0000B# => romdata <= X"13060000";
        when 16#0000C# => romdata <= X"93060000";
        when 16#0000D# => romdata <= X"13070000";
        when 16#0000E# => romdata <= X"93070000";
        when 16#0000F# => romdata <= X"13080000";
        when 16#00010# => romdata <= X"93080000";
        when 16#00011# => romdata <= X"13090000";
        when 16#00012# => romdata <= X"93090000";
        when 16#00013# => romdata <= X"130a0000";
        when 16#00014# => romdata <= X"930a0000";
        when 16#00015# => romdata <= X"130b0000";
        when 16#00016# => romdata <= X"930b0000";
        when 16#00017# => romdata <= X"130c0000";
        when 16#00018# => romdata <= X"930c0000";
        when 16#00019# => romdata <= X"130d0000";
        when 16#0001A# => romdata <= X"930d0000";
        when 16#0001B# => romdata <= X"130e0000";
        when 16#0001C# => romdata <= X"930e0000";
        when 16#0001D# => romdata <= X"130f0000";
        when 16#0001E# => romdata <= X"930f0000";
        when 16#0001F# => romdata <= X"37010100";
        when 16#00020# => romdata <= X"97020000";
        when 16#00021# => romdata <= X"93824202";
        when 16#00022# => romdata <= X"73905230";
        when 16#00023# => romdata <= X"0f100000";
        when 16#00024# => romdata <= X"732540f1";
        when 16#00025# => romdata <= X"93051000";
        when 16#00026# => romdata <= X"6370b500";
        when 16#00027# => romdata <= X"13040000";
        when 16#00028# => romdata <= X"67000400";
        when 16#00029# => romdata <= X"73001000";
        when 16#0002A# => romdata <= X"6ff0dfff";
        when 16#0002B# => romdata <= X"00000000";
        when others => romdata <= (others => '-');
      end case;
    else --little endian
      case conv_integer(romaddr) is
        when 16#00000# => romdata <= X"00000093";
        when 16#00001# => romdata <= X"00000113";
        when 16#00002# => romdata <= X"00000193";
        when 16#00003# => romdata <= X"00000213";
        when 16#00004# => romdata <= X"00000293";
        when 16#00005# => romdata <= X"00000313";
        when 16#00006# => romdata <= X"00000393";
        when 16#00007# => romdata <= X"00000413";
        when 16#00008# => romdata <= X"00000493";
        when 16#00009# => romdata <= X"00000513";
        when 16#0000A# => romdata <= X"00000593";
        when 16#0000B# => romdata <= X"00000613";
        when 16#0000C# => romdata <= X"00000693";
        when 16#0000D# => romdata <= X"00000713";
        when 16#0000E# => romdata <= X"00000793";
        when 16#0000F# => romdata <= X"00000813";
        when 16#00010# => romdata <= X"00000893";
        when 16#00011# => romdata <= X"00000913";
        when 16#00012# => romdata <= X"00000993";
        when 16#00013# => romdata <= X"00000a13";
        when 16#00014# => romdata <= X"00000a93";
        when 16#00015# => romdata <= X"00000b13";
        when 16#00016# => romdata <= X"00000b93";
        when 16#00017# => romdata <= X"00000c13";
        when 16#00018# => romdata <= X"00000c93";
        when 16#00019# => romdata <= X"00000d13";
        when 16#0001A# => romdata <= X"00000d93";
        when 16#0001B# => romdata <= X"00000e13";
        when 16#0001C# => romdata <= X"00000e93";
        when 16#0001D# => romdata <= X"00000f13";
        when 16#0001E# => romdata <= X"00000f93";
        when 16#0001F# => romdata <= X"00010137";
        when 16#00020# => romdata <= X"00000297";
        when 16#00021# => romdata <= X"02428293";
        when 16#00022# => romdata <= X"30529073";
        when 16#00023# => romdata <= X"0000100f";
        when 16#00024# => romdata <= X"f1402573";
        when 16#00025# => romdata <= X"00100593";
        when 16#00026# => romdata <= X"00b57063";
        when 16#00027# => romdata <= X"00000413";
        when 16#00028# => romdata <= X"00040067";
        when 16#00029# => romdata <= X"00100073";
        when 16#0002A# => romdata <= X"ffdff06f";
        when 16#0002B# => romdata <= X"00000000";
           when others => romdata <= (others => '-');
        end case;
    end if; 
  end process;
-- pragma translate_off
  bootmsg : report_version
  generic map ("ahbrom" & tost(hindex) &
  ": 32-bit AHB ROM Module,  " & tost(bytes/(dbits/8)) & " words, " & tost(abits-log2(dbits/8)) & " address bits" );
  -- pragma translate_on
  end;
