
----------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2021 Cobham Gaisler
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
constant abits : integer := 8;
constant bytes : integer := 176;
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
    if ahbsi.endian = '0' then --big endian
      case conv_integer(romaddr) is
        when 16#00000# => romdata <= X"93000000130100009301000013020000";
        when 16#00001# => romdata <= X"93020000130300009303000013040000";
        when 16#00002# => romdata <= X"93040000130500009305000013060000";
        when 16#00003# => romdata <= X"93060000130700009307000013080000";
        when 16#00004# => romdata <= X"930800001309000093090000130a0000";
        when 16#00005# => romdata <= X"930a0000130b0000930b0000130c0000";
        when 16#00006# => romdata <= X"930c0000130d0000930d0000130e0000";
        when 16#00007# => romdata <= X"930e0000130f0000930f000037010100";
        when 16#00008# => romdata <= X"9702000093828202739052309302f01c";
        when 16#00009# => romdata <= X"7390127c732540f1930510006370b500";
        when 16#0000A# => romdata <= X"1304000067000400730010006ff0dfff";
        when 16#0000B# => romdata <= X"00000000000000000000000000000000";
        when others => romdata <= (others => '-');
      end case;
    else --little endian
      case conv_integer(romaddr) is
        when 16#00000# => romdata <= X"00000213000001930000011300000093";
        when 16#00001# => romdata <= X"00000413000003930000031300000293";
        when 16#00002# => romdata <= X"00000613000005930000051300000493";
        when 16#00003# => romdata <= X"00000813000007930000071300000693";
        when 16#00004# => romdata <= X"00000a13000009930000091300000893";
        when 16#00005# => romdata <= X"00000c1300000b9300000b1300000a93";
        when 16#00006# => romdata <= X"00000e1300000d9300000d1300000c93";
        when 16#00007# => romdata <= X"0001013700000f9300000f1300000e93";
        when 16#00008# => romdata <= X"1cf00293305290730282829300000297";
        when 16#00009# => romdata <= X"00b5706300100593f14025737c129073";
        when 16#0000A# => romdata <= X"ffdff06f001000730004006700000413";
        when 16#0000B# => romdata <= X"00000000000000000000000000000000";
           when others => romdata <= (others => '-');
        end case;
    end if; 
  end process;
-- pragma translate_off
  bootmsg : report_version
  generic map ("ahbrom128_" & tost(hindex) &
  ": 128-bit AHB ROM Module,  " & tost(bytes/(dbits/8)) & " words, " & tost(abits-log2(dbits/8)) & " address bits" );
  -- pragma translate_on
  end;
