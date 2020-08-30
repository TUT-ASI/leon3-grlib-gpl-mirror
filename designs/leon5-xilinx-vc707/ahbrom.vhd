
----------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2020 Cobham Gaisler
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
constant abits : integer := 10;
constant bytes : integer := 560;
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
    case conv_integer(romaddr) is
    when 16#00000# => romdata <= X"81d82000";
    when 16#00001# => romdata <= X"03000004";
    when 16#00002# => romdata <= X"821060e0";
    when 16#00003# => romdata <= X"81880001";
    when 16#00004# => romdata <= X"81900000";
    when 16#00005# => romdata <= X"81980000";
    when 16#00006# => romdata <= X"81800000";
    when 16#00007# => romdata <= X"a1800000";
    when 16#00008# => romdata <= X"01000000";
    when 16#00009# => romdata <= X"03002040";
    when 16#0000A# => romdata <= X"8210600f";
    when 16#0000B# => romdata <= X"c2a00040";
    when 16#0000C# => romdata <= X"84100000";
    when 16#0000D# => romdata <= X"01000000";
    when 16#0000E# => romdata <= X"01000000";
    when 16#0000F# => romdata <= X"01000000";
    when 16#00010# => romdata <= X"01000000";
    when 16#00011# => romdata <= X"01000000";
    when 16#00012# => romdata <= X"80108002";
    when 16#00013# => romdata <= X"01000000";
    when 16#00014# => romdata <= X"01000000";
    when 16#00015# => romdata <= X"01000000";
    when 16#00016# => romdata <= X"01000000";
    when 16#00017# => romdata <= X"01000000";
    when 16#00018# => romdata <= X"87444000";
    when 16#00019# => romdata <= X"8608e01f";
    when 16#0001A# => romdata <= X"88100000";
    when 16#0001B# => romdata <= X"8a100000";
    when 16#0001C# => romdata <= X"8c100000";
    when 16#0001D# => romdata <= X"8e100000";
    when 16#0001E# => romdata <= X"a0100000";
    when 16#0001F# => romdata <= X"a2100000";
    when 16#00020# => romdata <= X"a4100000";
    when 16#00021# => romdata <= X"a6100000";
    when 16#00022# => romdata <= X"a8100000";
    when 16#00023# => romdata <= X"aa100000";
    when 16#00024# => romdata <= X"ac100000";
    when 16#00025# => romdata <= X"ae100000";
    when 16#00026# => romdata <= X"90100000";
    when 16#00027# => romdata <= X"92100000";
    when 16#00028# => romdata <= X"94100000";
    when 16#00029# => romdata <= X"96100000";
    when 16#0002A# => romdata <= X"98100000";
    when 16#0002B# => romdata <= X"9a100000";
    when 16#0002C# => romdata <= X"9c100000";
    when 16#0002D# => romdata <= X"9e100000";
    when 16#0002E# => romdata <= X"86a0e001";
    when 16#0002F# => romdata <= X"16bfffef";
    when 16#00030# => romdata <= X"81e00000";
    when 16#00031# => romdata <= X"82102002";
    when 16#00032# => romdata <= X"81900001";
    when 16#00033# => romdata <= X"03000004";
    when 16#00034# => romdata <= X"821060e0";
    when 16#00035# => romdata <= X"81880001";
    when 16#00036# => romdata <= X"01000000";
    when 16#00037# => romdata <= X"01000000";
    when 16#00038# => romdata <= X"01000000";
    when 16#00039# => romdata <= X"83480000";
    when 16#0003A# => romdata <= X"8330600c";
    when 16#0003B# => romdata <= X"80886001";
    when 16#0003C# => romdata <= X"02800024";
    when 16#0003D# => romdata <= X"01000000";
    when 16#0003E# => romdata <= X"07000000";
    when 16#0003F# => romdata <= X"8610e178";
    when 16#00040# => romdata <= X"c108c000";
    when 16#00041# => romdata <= X"c118c000";
    when 16#00042# => romdata <= X"c518c000";
    when 16#00043# => romdata <= X"c918c000";
    when 16#00044# => romdata <= X"cd18c000";
    when 16#00045# => romdata <= X"d118c000";
    when 16#00046# => romdata <= X"d518c000";
    when 16#00047# => romdata <= X"d918c000";
    when 16#00048# => romdata <= X"dd18c000";
    when 16#00049# => romdata <= X"e118c000";
    when 16#0004A# => romdata <= X"e518c000";
    when 16#0004B# => romdata <= X"e918c000";
    when 16#0004C# => romdata <= X"ed18c000";
    when 16#0004D# => romdata <= X"f118c000";
    when 16#0004E# => romdata <= X"f518c000";
    when 16#0004F# => romdata <= X"f918c000";
    when 16#00050# => romdata <= X"fd18c000";
    when 16#00051# => romdata <= X"01000000";
    when 16#00052# => romdata <= X"01000000";
    when 16#00053# => romdata <= X"01000000";
    when 16#00054# => romdata <= X"01000000";
    when 16#00055# => romdata <= X"01000000";
    when 16#00056# => romdata <= X"89a00842";
    when 16#00057# => romdata <= X"01000000";
    when 16#00058# => romdata <= X"01000000";
    when 16#00059# => romdata <= X"01000000";
    when 16#0005A# => romdata <= X"01000000";
    when 16#0005B# => romdata <= X"10800005";
    when 16#0005C# => romdata <= X"01000000";
    when 16#0005D# => romdata <= X"01000000";
    when 16#0005E# => romdata <= X"00000000";
    when 16#0005F# => romdata <= X"00000000";
    when 16#00060# => romdata <= X"87444000";
    when 16#00061# => romdata <= X"8730e01c";
    when 16#00062# => romdata <= X"8688e00f";
    when 16#00063# => romdata <= X"12800016";
    when 16#00064# => romdata <= X"01000000";
    when 16#00065# => romdata <= X"03200000";
    when 16#00066# => romdata <= X"05040e00";
    when 16#00067# => romdata <= X"8410a133";
    when 16#00068# => romdata <= X"c4204000";
    when 16#00069# => romdata <= X"0539ae1b";
    when 16#0006A# => romdata <= X"8410a260";
    when 16#0006B# => romdata <= X"c4206004";
    when 16#0006C# => romdata <= X"050003fc";
    when 16#0006D# => romdata <= X"c4206008";
    when 16#0006E# => romdata <= X"82103860";
    when 16#0006F# => romdata <= X"c4004000";
    when 16#00070# => romdata <= X"8530a00c";
    when 16#00071# => romdata <= X"03000004";
    when 16#00072# => romdata <= X"82106009";
    when 16#00073# => romdata <= X"80a04002";
    when 16#00074# => romdata <= X"12800005";
    when 16#00075# => romdata <= X"03200000";
    when 16#00076# => romdata <= X"0539a81b";
    when 16#00077# => romdata <= X"8410a260";
    when 16#00078# => romdata <= X"c4204000";
    when 16#00079# => romdata <= X"05000080";
    when 16#0007A# => romdata <= X"82100000";
    when 16#0007B# => romdata <= X"80a0e000";
    when 16#0007C# => romdata <= X"02800005";
    when 16#0007D# => romdata <= X"01000000";
    when 16#0007E# => romdata <= X"82004002";
    when 16#0007F# => romdata <= X"10bffffc";
    when 16#00080# => romdata <= X"8620e001";
    when 16#00081# => romdata <= X"3d1003ff";
    when 16#00082# => romdata <= X"bc17a3e0";
    when 16#00083# => romdata <= X"bc278001";
    when 16#00084# => romdata <= X"9c27a060";
    when 16#00085# => romdata <= X"03100000";
    when 16#00086# => romdata <= X"81c04000";
    when 16#00087# => romdata <= X"01000000";
    when 16#00088# => romdata <= X"00000000";
    when 16#00089# => romdata <= X"00000000";
    when 16#0008A# => romdata <= X"00000000";
    when 16#0008B# => romdata <= X"00000000";
    when 16#0008C# => romdata <= X"00000000";
    when others => romdata <= (others => '-');
    end case;
  end process;
  -- pragma translate_off
  bootmsg : report_version
  generic map ("ahbrom" & tost(hindex) &
  ": 32-bit AHB ROM Module,  " & tost(bytes/(dbits/8)) & " words, " & tost(abits-log2(dbits/8)) & " address bits" );
  -- pragma translate_on
  -- pragma translate_off
   assert GRLIB_CONFIG_ARRAY(grlib_little_endian) = 0
      report "ahbrom: little endian systems not supported"
      severity error;
  -- pragma translate_on
  end;
