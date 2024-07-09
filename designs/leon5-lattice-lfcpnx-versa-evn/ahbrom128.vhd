
----------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2020 Cobham Gaisler
----------------------------------------------------------------------------
-- Entity:      ahbrom128
-- File:        ahbrom128.vhd
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

entity ahbrom128 is
  generic (
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#fff#;
    pipe    : integer := 0;
    tech    : integer := 0;
    kbytes  : integer := 1;
    wideonly: integer := 0);
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type
  );
end;

architecture rtl of ahbrom128 is
constant abits : integer := 10;
constant bytes : integer := 592;
constant dbits : integer := 128;

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
  romdatas <= ahbdrivedata(romdata) when wideonly/=0 or CORE_ACDM=1 else 
    ahbselectdata(ahbdrivedata(romdata),addr(4 downto 2),hsize);

  comb : process (romaddr)
  begin
    case conv_integer(romaddr) is
    when 16#00000# => romdata <= X"81d8200003000004821060e081880001";
    when 16#00001# => romdata <= X"819000008198000081800000a1800000";
    when 16#00002# => romdata <= X"01000000030020408210600fc2a00040";
    when 16#00003# => romdata <= X"84100000010000000100000001000000";
    when 16#00004# => romdata <= X"01000000010000008010800201000000";
    when 16#00005# => romdata <= X"01000000010000000100000001000000";
    when 16#00006# => romdata <= X"874440008608e01f881000008a100000";
    when 16#00007# => romdata <= X"8c1000008e100000a0100000a2100000";
    when 16#00008# => romdata <= X"a4100000a6100000a8100000aa100000";
    when 16#00009# => romdata <= X"ac100000ae1000009010000092100000";
    when 16#0000A# => romdata <= X"9410000096100000981000009a100000";
    when 16#0000B# => romdata <= X"9c1000009e10000086a0e00116bfffef";
    when 16#0000C# => romdata <= X"81e00000821020028190000103000004";
    when 16#0000D# => romdata <= X"821060e0818800010100000001000000";
    when 16#0000E# => romdata <= X"01000000834800008330600c80886001";
    when 16#0000F# => romdata <= X"0280002401000000070000008610e178";
    when 16#00010# => romdata <= X"c108c000c118c000c518c000c918c000";
    when 16#00011# => romdata <= X"cd18c000d118c000d518c000d918c000";
    when 16#00012# => romdata <= X"dd18c000e118c000e518c000e918c000";
    when 16#00013# => romdata <= X"ed18c000f118c000f518c000f918c000";
    when 16#00014# => romdata <= X"fd18c000010000000100000001000000";
    when 16#00015# => romdata <= X"010000000100000089a0084201000000";
    when 16#00016# => romdata <= X"01000000010000000100000010800005";
    when 16#00017# => romdata <= X"01000000010000000000000000000000";
    when 16#00018# => romdata <= X"874440008730e01c8688e00f1280001b";
    when 16#00019# => romdata <= X"010000000320000005040e008410a033";
    when 16#0001A# => romdata <= X"c42040000539ae138410a260c4206004";
    when 16#0001B# => romdata <= X"050003fcc42060080320000082106100";
    when 16#0001C# => romdata <= X"c020600c84102003c420600882103860";
    when 16#0001D# => romdata <= X"c40040008530a00c0300000482106009";
    when 16#0001E# => romdata <= X"80a0400212800005032000000539a81b";
    when 16#0001F# => romdata <= X"8410a260c42040000500008082100000";
    when 16#00020# => romdata <= X"80a0e000028000050100000082004002";
    when 16#00021# => romdata <= X"10bffffc8620e0013d1003ffbc17a3e0";
    when 16#00022# => romdata <= X"bc2780019c27a0600310000081c04000";
    when 16#00023# => romdata <= X"01000000010000000100000001000000";
    when 16#00024# => romdata <= X"00000000000000000000000000000000";
    when 16#00025# => romdata <= X"00000000000000000000000000000000";
    when others => romdata <= (others => '-');
    end case;
  end process;
  -- pragma translate_off
  bootmsg : report_version
  generic map ("ahbrom128_" & tost(hindex) &
  ": 128-bit AHB ROM Module,  " & tost(bytes/(dbits/8)) & " words, " & tost(abits-log2(dbits/8)) & " address bits" );
  -- pragma translate_on
  end;
