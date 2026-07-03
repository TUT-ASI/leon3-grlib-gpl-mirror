
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
constant abits : integer := 8;
constant bytes : integer := 172;
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
        when 16#00000# => romdata <= X"9300000013010000";
        when 16#00001# => romdata <= X"9301000013020000";
        when 16#00002# => romdata <= X"9302000013030000";
        when 16#00003# => romdata <= X"9303000013040000";
        when 16#00004# => romdata <= X"9304000013050000";
        when 16#00005# => romdata <= X"9305000013060000";
        when 16#00006# => romdata <= X"9306000013070000";
        when 16#00007# => romdata <= X"9307000013080000";
        when 16#00008# => romdata <= X"9308000013090000";
        when 16#00009# => romdata <= X"93090000130a0000";
        when 16#0000A# => romdata <= X"930a0000130b0000";
        when 16#0000B# => romdata <= X"930b0000130c0000";
        when 16#0000C# => romdata <= X"930c0000130d0000";
        when 16#0000D# => romdata <= X"930d0000130e0000";
        when 16#0000E# => romdata <= X"930e0000130f0000";
        when 16#0000F# => romdata <= X"930f000037010100";
        when 16#00010# => romdata <= X"9702000093824202";
        when 16#00011# => romdata <= X"739052300f100000";
        when 16#00012# => romdata <= X"732540f193051000";
        when 16#00013# => romdata <= X"6370b50013040000";
        when 16#00014# => romdata <= X"6700040073001000";
        when 16#00015# => romdata <= X"6ff0dfff00000000";
        when others => romdata <= (others => '-');
      end case;
    else --little endian
      case conv_integer(romaddr) is
        when 16#00000# => romdata <= X"0000011300000093";
        when 16#00001# => romdata <= X"0000021300000193";
        when 16#00002# => romdata <= X"0000031300000293";
        when 16#00003# => romdata <= X"0000041300000393";
        when 16#00004# => romdata <= X"0000051300000493";
        when 16#00005# => romdata <= X"0000061300000593";
        when 16#00006# => romdata <= X"0000071300000693";
        when 16#00007# => romdata <= X"0000081300000793";
        when 16#00008# => romdata <= X"0000091300000893";
        when 16#00009# => romdata <= X"00000a1300000993";
        when 16#0000A# => romdata <= X"00000b1300000a93";
        when 16#0000B# => romdata <= X"00000c1300000b93";
        when 16#0000C# => romdata <= X"00000d1300000c93";
        when 16#0000D# => romdata <= X"00000e1300000d93";
        when 16#0000E# => romdata <= X"00000f1300000e93";
        when 16#0000F# => romdata <= X"0001013700000f93";
        when 16#00010# => romdata <= X"0242829300000297";
        when 16#00011# => romdata <= X"0000100f30529073";
        when 16#00012# => romdata <= X"00100593f1402573";
        when 16#00013# => romdata <= X"0000041300b57063";
        when 16#00014# => romdata <= X"0010007300040067";
        when 16#00015# => romdata <= X"00000000ffdff06f";
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
