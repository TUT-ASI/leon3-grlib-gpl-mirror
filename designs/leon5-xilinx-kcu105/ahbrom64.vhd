
----------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2021 Cobham Gaisler
----------------------------------------------------------------------------
-- Entity:      ahbrom64
-- File:        ahbrom64.vhd
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

entity ahbrom64 is
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

architecture rtl of ahbrom64 is
constant abits : integer := 10;
constant bytes : integer := 592;
constant dbits : integer := 64;

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
    if ahbsi.endian = '0' then --big endian
      case conv_integer(romaddr) is
        when 16#00000# => romdata <= X"81d8200003000004";
        when 16#00001# => romdata <= X"821060e081880001";
        when 16#00002# => romdata <= X"8190000081980000";
        when 16#00003# => romdata <= X"81800000a1800000";
        when 16#00004# => romdata <= X"0100000003002040";
        when 16#00005# => romdata <= X"8210600fc2a00040";
        when 16#00006# => romdata <= X"8410000001000000";
        when 16#00007# => romdata <= X"0100000001000000";
        when 16#00008# => romdata <= X"0100000001000000";
        when 16#00009# => romdata <= X"8010800201000000";
        when 16#0000A# => romdata <= X"0100000001000000";
        when 16#0000B# => romdata <= X"0100000001000000";
        when 16#0000C# => romdata <= X"874440008608e01f";
        when 16#0000D# => romdata <= X"881000008a100000";
        when 16#0000E# => romdata <= X"8c1000008e100000";
        when 16#0000F# => romdata <= X"a0100000a2100000";
        when 16#00010# => romdata <= X"a4100000a6100000";
        when 16#00011# => romdata <= X"a8100000aa100000";
        when 16#00012# => romdata <= X"ac100000ae100000";
        when 16#00013# => romdata <= X"9010000092100000";
        when 16#00014# => romdata <= X"9410000096100000";
        when 16#00015# => romdata <= X"981000009a100000";
        when 16#00016# => romdata <= X"9c1000009e100000";
        when 16#00017# => romdata <= X"86a0e00116bfffef";
        when 16#00018# => romdata <= X"81e0000082102002";
        when 16#00019# => romdata <= X"8190000103000004";
        when 16#0001A# => romdata <= X"821060e081880001";
        when 16#0001B# => romdata <= X"0100000001000000";
        when 16#0001C# => romdata <= X"0100000083480000";
        when 16#0001D# => romdata <= X"8330600c80886001";
        when 16#0001E# => romdata <= X"0280002401000000";
        when 16#0001F# => romdata <= X"070000008610e178";
        when 16#00020# => romdata <= X"c108c000c118c000";
        when 16#00021# => romdata <= X"c518c000c918c000";
        when 16#00022# => romdata <= X"cd18c000d118c000";
        when 16#00023# => romdata <= X"d518c000d918c000";
        when 16#00024# => romdata <= X"dd18c000e118c000";
        when 16#00025# => romdata <= X"e518c000e918c000";
        when 16#00026# => romdata <= X"ed18c000f118c000";
        when 16#00027# => romdata <= X"f518c000f918c000";
        when 16#00028# => romdata <= X"fd18c00001000000";
        when 16#00029# => romdata <= X"0100000001000000";
        when 16#0002A# => romdata <= X"0100000001000000";
        when 16#0002B# => romdata <= X"89a0084201000000";
        when 16#0002C# => romdata <= X"0100000001000000";
        when 16#0002D# => romdata <= X"0100000010800005";
        when 16#0002E# => romdata <= X"0100000001000000";
        when 16#0002F# => romdata <= X"0000000000000000";
        when 16#00030# => romdata <= X"874440008730e01c";
        when 16#00031# => romdata <= X"8688e00f1280001a";
        when 16#00032# => romdata <= X"0320000005040e00";
        when 16#00033# => romdata <= X"8410a033c4204000";
        when 16#00034# => romdata <= X"0539ae138410a260";
        when 16#00035# => romdata <= X"c4206004050003fc";
        when 16#00036# => romdata <= X"c420600803200000";
        when 16#00037# => romdata <= X"82106100c020600c";
        when 16#00038# => romdata <= X"84102003c4206008";
        when 16#00039# => romdata <= X"82103860c4004000";
        when 16#0003A# => romdata <= X"8530a00c03000004";
        when 16#0003B# => romdata <= X"8210600980a04002";
        when 16#0003C# => romdata <= X"1280000503200000";
        when 16#0003D# => romdata <= X"0539a81b8410a260";
        when 16#0003E# => romdata <= X"c420400005000080";
        when 16#0003F# => romdata <= X"8210000080a0e000";
        when 16#00040# => romdata <= X"0280000501000000";
        when 16#00041# => romdata <= X"8200400210bffffc";
        when 16#00042# => romdata <= X"8620e0013d1003ff";
        when 16#00043# => romdata <= X"bc17a3e0bc278001";
        when 16#00044# => romdata <= X"9c27a06003100000";
        when 16#00045# => romdata <= X"81c0400001000000";
        when 16#00046# => romdata <= X"0100000001000000";
        when 16#00047# => romdata <= X"0100000001000000";
        when 16#00048# => romdata <= X"0000000000000000";
        when 16#00049# => romdata <= X"0000000000000000";
        when 16#0004A# => romdata <= X"0000000000000000";
        when others => romdata <= (others => '-');
      end case;
    else --little endian
      case conv_integer(romaddr) is
        when 16#00000# => romdata <= X"040000030020d881";
        when 16#00001# => romdata <= X"01008881e0601082";
        when 16#00002# => romdata <= X"0000988100009081";
        when 16#00003# => romdata <= X"000080a100008081";
        when 16#00004# => romdata <= X"4020000300000001";
        when 16#00005# => romdata <= X"4000a0c20f601082";
        when 16#00006# => romdata <= X"0000000100001084";
        when 16#00007# => romdata <= X"0000000100000001";
        when 16#00008# => romdata <= X"0000000100000001";
        when 16#00009# => romdata <= X"0000000102801080";
        when 16#0000A# => romdata <= X"0000000100000001";
        when 16#0000B# => romdata <= X"0000000100000001";
        when 16#0000C# => romdata <= X"1fe0088600404487";
        when 16#0000D# => romdata <= X"0000108a00001088";
        when 16#0000E# => romdata <= X"0000108e0000108c";
        when 16#0000F# => romdata <= X"000010a2000010a0";
        when 16#00010# => romdata <= X"000010a6000010a4";
        when 16#00011# => romdata <= X"000010aa000010a8";
        when 16#00012# => romdata <= X"000010ae000010ac";
        when 16#00013# => romdata <= X"0000109200001090";
        when 16#00014# => romdata <= X"0000109600001094";
        when 16#00015# => romdata <= X"0000109a00001098";
        when 16#00016# => romdata <= X"0000109e0000109c";
        when 16#00017# => romdata <= X"efffbf1601e0a086";
        when 16#00018# => romdata <= X"022010820000e081";
        when 16#00019# => romdata <= X"0400000301009081";
        when 16#0001A# => romdata <= X"01008881e0601082";
        when 16#0001B# => romdata <= X"0000000100000001";
        when 16#0001C# => romdata <= X"0000488300000001";
        when 16#0001D# => romdata <= X"016088800c603083";
        when 16#0001E# => romdata <= X"0000000124008002";
        when 16#0001F# => romdata <= X"78e1108600000007";
        when 16#00020# => romdata <= X"00c018c100c008c1";
        when 16#00021# => romdata <= X"00c018c900c018c5";
        when 16#00022# => romdata <= X"00c018d100c018cd";
        when 16#00023# => romdata <= X"00c018d900c018d5";
        when 16#00024# => romdata <= X"00c018e100c018dd";
        when 16#00025# => romdata <= X"00c018e900c018e5";
        when 16#00026# => romdata <= X"00c018f100c018ed";
        when 16#00027# => romdata <= X"00c018f900c018f5";
        when 16#00028# => romdata <= X"0000000100c018fd";
        when 16#00029# => romdata <= X"0000000100000001";
        when 16#0002A# => romdata <= X"0000000100000001";
        when 16#0002B# => romdata <= X"000000014208a089";
        when 16#0002C# => romdata <= X"0000000100000001";
        when 16#0002D# => romdata <= X"0500801000000001";
        when 16#0002E# => romdata <= X"0000000100000001";
        when 16#0002F# => romdata <= X"0000000000000000";
        when 16#00030# => romdata <= X"1ce0308700404487";
        when 16#00031# => romdata <= X"1a0080120fe08886";
        when 16#00032# => romdata <= X"000e040500002003";
        when 16#00033# => romdata <= X"004020c433a01084";
        when 16#00034# => romdata <= X"60a2108413ae3905";
        when 16#00035# => romdata <= X"fc030005046020c4";
        when 16#00036# => romdata <= X"00002003086020c4";
        when 16#00037# => romdata <= X"0c6020c000611082";
        when 16#00038# => romdata <= X"086020c403201084";
        when 16#00039# => romdata <= X"004000c460381082";
        when 16#0003A# => romdata <= X"040000030ca03085";
        when 16#0003B# => romdata <= X"0240a08009601082";
        when 16#0003C# => romdata <= X"0000200305008012";
        when 16#0003D# => romdata <= X"60a210841ba83905";
        when 16#0003E# => romdata <= X"80000005004020c4";
        when 16#0003F# => romdata <= X"00e0a08000001082";
        when 16#00040# => romdata <= X"0000000105008002";
        when 16#00041# => romdata <= X"fcffbf1002400082";
        when 16#00042# => romdata <= X"ff03103d01e02086";
        when 16#00043# => romdata <= X"018027bce0a317bc";
        when 16#00044# => romdata <= X"0000100360a0279c";
        when 16#00045# => romdata <= X"000000010040c081";
        when 16#00046# => romdata <= X"0000000100000001";
        when 16#00047# => romdata <= X"0000000100000001";
        when 16#00048# => romdata <= X"0000000000000000";
        when 16#00049# => romdata <= X"0000000000000000";
        when 16#0004A# => romdata <= X"0000000000000000";
           when others => romdata <= (others => '-');
        end case;
    end if; 
  end process;
-- pragma translate_off
  bootmsg : report_version
  generic map ("ahbrom64_" & tost(hindex) &
  ": 64-bit AHB ROM Module,  " & tost(bytes/(dbits/8)) & " words, " & tost(abits-log2(dbits/8)) & " address bits" );
  -- pragma translate_on
  end;
