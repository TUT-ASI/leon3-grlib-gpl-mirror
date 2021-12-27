------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
----------------------------------------------------------------------------
-- Entity: 	ahbrom
-- File:	ahbrom.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Modify:	Nils Wessman - Cobham Gaisler
-- Description:	AHB rom. 0/1-waitstate read
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config.all;
use grlib.config_types.all;

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
constant abits : integer := 17; 
constant bytes : integer := 560;

constant hconfig : ahb_config_type := (
  0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_AHBROM, 0, 0, 0),
  4 => ahb_membar(haddr, '1', '1', hmask), others => zero32);

signal hrdata : std_logic_vector(AHBDW-1 downto 0);
signal addr : std_logic_vector(abits-1 downto 2);
signal hsel, hready : std_ulogic;
signal hsize : std_logic_vector(2 downto 0);

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
    end if;
  end process;

  p0 : if pipe = 0 generate
    ahbso.hrdata        <= ahbselectdata(hrdata, addr(4 downto 2), hsize); 
    ahbso.hready        <= '1';
  end generate;

  p1 : if pipe = 1 generate
    reg2 : process (clk)
    begin
      if rising_edge(clk) then
	hsel <= ahbsi.hsel(hindex) and ahbsi.htrans(1);
	hready <= ahbsi.hready;
	ahbso.hready <=  (not rst) or (hsel and hready) or
	  (ahbsi.hsel(hindex) and not ahbsi.htrans(1) and ahbsi.hready);
        ahbso.hrdata <= ahbselectdata(hrdata, addr(4 downto 2), ahbsi.hsize); 
      end if;
    end process;
  end generate;

-- c0000000 <_boot>:
-- c0000000:	00000093          	li	ra,0
-- c0000004:	00000113          	li	sp,0
-- c0000008:	00000193          	li	gp,0
-- c000000c:	00000213          	li	tp,0
-- c0000010:	00000293          	li	t0,0
-- c0000014:	00000313          	li	t1,0
-- c0000018:	00000393          	li	t2,0
-- c000001c:	00000413          	li	s0,0
-- c0000020:	00000493          	li	s1,0
-- c0000024:	00000513          	li	a0,0
-- c0000028:	00000593          	li	a1,0
-- c000002c:	00000613          	li	a2,0
-- c0000030:	00000693          	li	a3,0
-- c0000034:	00000713          	li	a4,0
-- c0000038:	00000793          	li	a5,0
-- c000003c:	00000813          	li	a6,0
-- c0000040:	00000893          	li	a7,0
-- c0000044:	00000913          	li	s2,0
-- c0000048:	00000993          	li	s3,0
-- c000004c:	00000a13          	li	s4,0
-- c0000050:	00000a93          	li	s5,0
-- c0000054:	00000b13          	li	s6,0
-- c0000058:	00000b93          	li	s7,0
-- c000005c:	00000c13          	li	s8,0
-- c0000060:	00000c93          	li	s9,0
-- c0000064:	00000d13          	li	s10,0
-- c0000068:	00000d93          	li	s11,0
-- c000006c:	00000e13          	li	t3,0
-- c0000070:	00000e93          	li	t4,0
-- c0000074:	00000f13          	li	t5,0
-- c0000078:	00000f93          	li	t6,0
-- c000007c:	00010137          	lui	sp,0x10
-- c0000080:	00000297          	auipc	t0,0x0
-- c0000084:	02428293          	addi	t0,t0,36 # c00000a4 <default_trap>
-- c0000088:	30529073          	csrw	mtvec,t0
-- c000008c:	0000100f          	fence.i
-- c0000090:	f1402573          	csrr	a0,mhartid
-- c0000094:	00100593          	li	a1,1
-- c0000098:	00b57063          	bgeu	a0,a1,c0000098 <_boot+0x98>
-- c000009c:	00000413          	li	s0,0
-- c00000a0:	00040067          	jr	s0
-- 
-- c00000a4 <default_trap>:
-- c00000a4:	00100073          	ebreak
-- c00000a8:	ffdff06f          	j	c00000a4 <default_trap>

  comb : process (addr)
    variable romdata : std_logic_vector(127 downto 0);
  begin
    case conv_integer(addr(abits-1 downto 4)) is
      when 16#00000# => romdata := x"00000213000001930000011300000093";
      when 16#00001# => romdata := x"00000413000003930000031300000293";
      when 16#00002# => romdata := x"00000613000005930000051300000493";
      when 16#00003# => romdata := x"00000813000007930000071300000693";
      when 16#00004# => romdata := x"00000A13000009930000091300000893";
      when 16#00005# => romdata := x"00000C1300000B9300000B1300000A93";
      when 16#00006# => romdata := x"00000E1300000D9300000D1300000C93";
      when 16#00007# => romdata := x"0001013700000F9300000F1300000E93";
      when 16#00008# => romdata := x"0000100F305290730242829300000297";
      when 16#00009# => romdata := x"0000041300B5706300100593F1402573";
      when 16#0000A# => romdata := x"00000013FFDFF06F0010007300040067";
      when 16#0000B# => romdata := x"00000013000000130000001300000013";
      when others    => romdata := (others => '-');
    end case;
    case AHBDW is
      when 128 => 
        hrdata <= romdata(AHBDW-1 downto 0);
      when 64  =>
        if addr(3) = '0' then
          hrdata <= romdata(1*AHBDW-1 downto 0*AHBDW);
        else
          hrdata <= romdata(2*AHBDW-1 downto 1*AHBDW);
        end if;
      when 32  =>
        if addr(3 downto 2) = "00" then
          hrdata <= romdata(1*AHBDW-1 downto 0*AHBDW);
        elsif addr(3 downto 2) = "01" then
          hrdata <= romdata(2*AHBDW-1 downto 1*AHBDW);
        elsif addr(3 downto 2) = "11" then
          hrdata <= romdata(3*AHBDW-1 downto 2*AHBDW);
        else --if addr(3 downto 2) = "11" then
          hrdata <= romdata(4*AHBDW-1 downto 3*AHBDW);
        end if;
      when others =>
    end case;

  end process;
  -- pragma translate_off
  bootmsg : report_version 
  generic map ("ahbrom" & tost(hindex) &
  ": NOEL-V AHB ROM Module,  " & tost(bytes/4) & " words, " & tost(abits-2) & " address bits" );
  -- pragma translate_on
  end;

