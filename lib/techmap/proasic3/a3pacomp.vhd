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
-- Package: 	components
-- File:	components.vhd
-- Author:	Jiri Gaisler, Gaisler Research
-- Modified:    Jonas Ekergarn, Aeroflex Gaisler
-- Description:	Actel proasic3 I/0 and RAM component declarations
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package a3pacomp is

-------------------------------------------------------------------------------
-- Combinational macros
-------------------------------------------------------------------------------
  component AND2 port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AND2A port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AND3 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AO13 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AO16 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AO18 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AO1 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AO1A port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AO1B port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AO1C port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;  
  component AO1D port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AOI1 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;  
  component AOI5 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;  
  component AOI1A port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AOI1B port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AX1 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component CLKINT port(A : in std_ulogic; Y :out std_ulogic); end component;
  component INV port(A : in std_ulogic; Y :out std_ulogic); end component;
  component GND port(Y :out std_ulogic); end component;
  component MX2 port(A, S, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component MX2A port(A, S, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component MX2B port(A, S, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component MX2C port(A, S, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component NAND2 port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component NOR2 port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component NOR2A port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component NOR2B port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component NOR3 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component NOR3A port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component NOR3B port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component NOR3C port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component OA1 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;  
  component OA1A port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component OA1B port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component OA1C port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component OAI1 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;  
  component OR2 port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component OR2A port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component OR2B port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component OR3 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component OR3A port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component OR3B port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component OR3C port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component VCC port(Y :out std_ulogic); end component;
  component XOR2 port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XOR3 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XNOR2 port(A, B : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XNOR3 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XAI1 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XAI1A port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AX1A port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AX1B port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AX1C port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AX1D port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AX1E port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXO1 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXO2 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXO3 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXO4 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXO5 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXO6 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXO7 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XA1 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XA1A port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XA1B port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XA1C port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component MAJ3 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component MIN3 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XO1 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component XO1A port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component ZOR3 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXOI1 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXOI2 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXOI3 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXOI4 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;
  component AXOI5 port(A, B, C : in STD_ULOGIC; Y : out STD_ULOGIC); end component;

-------------------------------------------------------------------------------
-- Sequential macros
-------------------------------------------------------------------------------
  component DFN1 port(CLK, D : in STD_ULOGIC; Q : out STD_ULOGIC); end component;
  component DFN1C0 port(CLR, CLK, D : in STD_ULOGIC; Q : out STD_ULOGIC); end component;
  component DFN1E0 port(E, CLK, D : in STD_ULOGIC; Q : out STD_ULOGIC); end component;
  component DFN1E1 port(E, CLK, D : in STD_ULOGIC; Q : out STD_ULOGIC); end component;
  
------------------------------------------------------------------------------
-- I/O macros
-------------------------------------------------------------------------------
  component clkbuf port(pad : in std_ulogic; y : in std_ulogic); end component;
  component clkbuf_pci port(pad : in std_ulogic; y : in std_ulogic); end component;
  component clkbuf_lvds port(padp, padn : in std_ulogic; y : out std_ulogic); end component;
  component clkbuf_lvpecl port(padp, padn : in std_ulogic; y : out std_ulogic); end component;

  component inbuf port(pad : in std_ulogic; y : out std_ulogic); end component;
  component inbuf_pci port(pad : in std_ulogic; y : out std_ulogic); end component;
  component inbuf_lvds port(padp, padn : in std_ulogic; y : out std_ulogic); end component;
  component inbuf_lvpecl port(padp, padn : in std_ulogic; y : out std_ulogic); end component;

  component bibuf port(d, e : in std_ulogic; pad : inout std_ulogic; y : out std_ulogic); end component;
  component bibuf_pci port(d, e : in std_ulogic; pad : inout std_ulogic; y : out std_ulogic); end component;
  component bibuf_lvds port(d, e : in std_ulogic; padp, padn : inout std_ulogic; y : out std_ulogic); end component;
  component bibuf_lvpecl port(d, e : in std_ulogic; padp, padn : inout std_ulogic; y : out std_ulogic); end component;

  component outbuf port(d : in std_ulogic; pad : out std_ulogic); end component;
  component outbuf_pci port(d : in std_ulogic; pad : out std_ulogic); end component;
  component outbuf_lvds port(d : in std_ulogic; padp, padn : out std_ulogic); end component;
  component outbuf_lvpecl port(d : in std_ulogic; padp, padn : out std_ulogic); end component;

  component tribuff port(d, e : in std_ulogic; pad : out std_ulogic); end component;
  component tribuff_pci port(d, e : in std_ulogic; pad : out std_ulogic); end component;
  component tribuff_lvds port(d, e : in std_ulogic; padp, padn : out std_ulogic); end component;
  component tribuff_lvpecl port(d, e : in std_ulogic; padp, padn : out std_ulogic); end component;

  component ddr_out port(clr, clk, dr, df : in std_ulogic; q : out std_ulogic); end component;
  component ddr_reg port(clr, clk, d: in std_ulogic; qf, qr: out std_ulogic); end component;
   
  component PLLINT port(A : in std_ulogic; Y :out std_ulogic); end component;

  component PLL
  generic(
     VCOFREQUENCY      :  Real    := 0.0;
     f_CLKA_LOCK       :  Integer := 3; -- Number of CLKA pulses after which LOCK is raised

     TimingChecksOn    :  Boolean          := True;
     InstancePath      :  String           := "*";
     Xon               :  Boolean          := False;
     MsgOn             :  Boolean          := True
  );
  port (
     CLKA         :  in    STD_ULOGIC;
     EXTFB        :  in    STD_ULOGIC;
     POWERDOWN    :  in    STD_ULOGIC;
     OADIV0       :  in    STD_ULOGIC;
     OADIV1       :  in    STD_ULOGIC;
     OADIV2       :  in    STD_ULOGIC;
     OADIV3       :  in    STD_ULOGIC;
     OADIV4       :  in    STD_ULOGIC;
     OAMUX0       :  in    STD_ULOGIC;
     OAMUX1       :  in    STD_ULOGIC;
     OAMUX2       :  in    STD_ULOGIC;
     DLYGLA0      :  in    STD_ULOGIC;
     DLYGLA1      :  in    STD_ULOGIC;
     DLYGLA2      :  in    STD_ULOGIC;
     DLYGLA3      :  in    STD_ULOGIC;
     DLYGLA4      :  in    STD_ULOGIC;
     OBDIV0       :  in    STD_ULOGIC;
     OBDIV1       :  in    STD_ULOGIC;
     OBDIV2       :  in    STD_ULOGIC;
     OBDIV3       :  in    STD_ULOGIC;
     OBDIV4       :  in    STD_ULOGIC;
     OBMUX0       :  in    STD_ULOGIC;
     OBMUX1       :  in    STD_ULOGIC;
     OBMUX2       :  in    STD_ULOGIC;
     DLYYB0       :  in    STD_ULOGIC;
     DLYYB1       :  in    STD_ULOGIC;
     DLYYB2       :  in    STD_ULOGIC;
     DLYYB3       :  in    STD_ULOGIC;
     DLYYB4       :  in    STD_ULOGIC;
     DLYGLB0      :  in    STD_ULOGIC;
     DLYGLB1      :  in    STD_ULOGIC;
     DLYGLB2      :  in    STD_ULOGIC;
     DLYGLB3      :  in    STD_ULOGIC;
     DLYGLB4      :  in    STD_ULOGIC;
     OCDIV0       :  in    STD_ULOGIC;
     OCDIV1       :  in    STD_ULOGIC;
     OCDIV2       :  in    STD_ULOGIC;
     OCDIV3       :  in    STD_ULOGIC;
     OCDIV4       :  in    STD_ULOGIC;
     OCMUX0       :  in    STD_ULOGIC;
     OCMUX1       :  in    STD_ULOGIC;
     OCMUX2       :  in    STD_ULOGIC;
     DLYYC0       :  in    STD_ULOGIC;
     DLYYC1       :  in    STD_ULOGIC;
     DLYYC2       :  in    STD_ULOGIC;
     DLYYC3       :  in    STD_ULOGIC;
     DLYYC4       :  in    STD_ULOGIC;
     DLYGLC0      :  in    STD_ULOGIC;
     DLYGLC1      :  in    STD_ULOGIC;
     DLYGLC2      :  in    STD_ULOGIC;
     DLYGLC3      :  in    STD_ULOGIC;
     DLYGLC4      :  in    STD_ULOGIC;
     FINDIV0      :  in    STD_ULOGIC;
     FINDIV1      :  in    STD_ULOGIC;
     FINDIV2      :  in    STD_ULOGIC;
     FINDIV3      :  in    STD_ULOGIC;
     FINDIV4      :  in    STD_ULOGIC;
     FINDIV5      :  in    STD_ULOGIC;
     FINDIV6      :  in    STD_ULOGIC;
     FBDIV0       :  in    STD_ULOGIC;
     FBDIV1       :  in    STD_ULOGIC;
     FBDIV2       :  in    STD_ULOGIC;
     FBDIV3       :  in    STD_ULOGIC;
     FBDIV4       :  in    STD_ULOGIC;
     FBDIV5       :  in    STD_ULOGIC;
     FBDIV6       :  in    STD_ULOGIC;
     FBDLY0       :  in    STD_ULOGIC;
     FBDLY1       :  in    STD_ULOGIC;
     FBDLY2       :  in    STD_ULOGIC;
     FBDLY3       :  in    STD_ULOGIC;
     FBDLY4       :  in    STD_ULOGIC;
     FBSEL0       :  in    STD_ULOGIC;
     FBSEL1       :  in    STD_ULOGIC;
     XDLYSEL      :  in    STD_ULOGIC;
     VCOSEL0      :  in    STD_ULOGIC;
     VCOSEL1      :  in    STD_ULOGIC;
     VCOSEL2      :  in    STD_ULOGIC;
     GLA          :  out   STD_ULOGIC;
     LOCK         :  out   STD_ULOGIC;
     GLB          :  out   STD_ULOGIC;
     YB           :  out   STD_ULOGIC;
     GLC          :  out   STD_ULOGIC;
     YC           :  out   STD_ULOGIC);
  end component;    

  component UJTAG
    port(
      UTDO           :  in    STD_ULOGIC;
      TMS            :  in    STD_ULOGIC;
      TDI            :  in    STD_ULOGIC;
      TCK            :  in    STD_ULOGIC;
      TRSTB          :  in    STD_ULOGIC;
      UIREG0         :  out   STD_ULOGIC;
      UIREG1         :  out   STD_ULOGIC;
      UIREG2         :  out   STD_ULOGIC;
      UIREG3         :  out   STD_ULOGIC;
      UIREG4         :  out   STD_ULOGIC;
      UIREG5         :  out   STD_ULOGIC;
      UIREG6         :  out   STD_ULOGIC;
      UIREG7         :  out   STD_ULOGIC;
      UTDI           :  out   STD_ULOGIC;
      URSTB          :  out   STD_ULOGIC;
      UDRCK          :  out   STD_ULOGIC;
      UDRCAP         :  out   STD_ULOGIC;
      UDRSH          :  out   STD_ULOGIC;
      UDRUPD         :  out   STD_ULOGIC;
      TDO            :  out   STD_ULOGIC);
  end component;

-------------------------------------------------------------------------------  
-- RAM macros
-------------------------------------------------------------------------------
  component RAM4K9
--    generic (abits : integer range 9 to 12 := 9);
    port(
	ADDRA0, ADDRA1, ADDRA2, ADDRA3, ADDRA4, ADDRA5, ADDRA6, ADDRA7,
	ADDRA8, ADDRA9, ADDRA10, ADDRA11 : in std_ulogic;
	ADDRB0, ADDRB1, ADDRB2, ADDRB3, ADDRB4, ADDRB5, ADDRB6, ADDRB7,
	ADDRB8, ADDRB9, ADDRB10, ADDRB11 : in std_ulogic;
	BLKA, WENA, PIPEA, WMODEA, WIDTHA0, WIDTHA1, WENB, BLKB,
	PIPEB, WMODEB, WIDTHB1, WIDTHB0 : in std_ulogic;
	DINA0, DINA1, DINA2, DINA3, DINA4, DINA5, DINA6, DINA7, DINA8 : in std_ulogic;
	DINB0, DINB1, DINB2, DINB3, DINB4, DINB5, DINB6, DINB7, DINB8 : in std_ulogic;
	RESET, CLKA, CLKB : in std_ulogic; 
	DOUTA0, DOUTA1, DOUTA2, DOUTA3, DOUTA4, DOUTA5, DOUTA6, DOUTA7, DOUTA8 : out std_ulogic;
	DOUTB0, DOUTB1, DOUTB2, DOUTB3, DOUTB4, DOUTB5, DOUTB6, DOUTB7, DOUTB8 : out std_ulogic
    );
  end component;

  component RAM512X18
    port(
      RADDR8, RADDR7, RADDR6, RADDR5, RADDR4, RADDR3, RADDR2, RADDR1, RADDR0 : in std_ulogic;
      WADDR8, WADDR7, WADDR6, WADDR5, WADDR4, WADDR3, WADDR2, WADDR1, WADDR0 : in std_ulogic;
      WD17, WD16, WD15, WD14, WD13, WD12, WD11, WD10, WD9, 
      WD8, WD7, WD6, WD5, WD4, WD3, WD2, WD1, WD0 : in std_ulogic;
      REN, WEN, RESET, RW0, RW1, WW1, WW0, PIPE, RCLK, WCLK : in std_ulogic;
      RD17, RD16, RD15, RD14, RD13, RD12, RD11, RD10, RD9, 
      RD8, RD7, RD6, RD5, RD4, RD3, RD2, RD1, RD0 : out std_ulogic
    );
  end component;  
end;
