------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003, Gaisler Research
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

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
library gaisler;
use gaisler.misc.all;
library techmap;
use techmap.gencomp.all;

package usb is
  type usb_memi_in_type is record
    wenable : std_ulogic;
    address : std_logic_vector(8 downto 0);
    din     : std_logic_vector(31 downto 0);
  end record;

  type usb_memo_in_type is record
    wenable : std_ulogic;
    address : std_logic_vector(8 downto 0);
    din     : std_logic_vector(31 downto 0);
  end record;
  
  type usb_in_type is record
    --utmi
    dinh       : std_logic_vector(7 downto 0);
    rxactive   : std_ulogic;
    rxvalid    : std_ulogic;
    rhvalid    : std_ulogic;
    rxerror    : std_ulogic;
    txready    : std_ulogic;
    linestate  : std_logic_vector(1 downto 0);
    --ulpi
    nxt        : std_ulogic;
    dir        : std_ulogic;
    --shared
    din        : std_logic_vector(7 downto 0);
    --misc
    vbus       : std_ulogic;
  end record;
  
  type usb_out_type is record
    --utmi
    douth             : std_logic_vector(7 downto 0);
    txvalid           : std_ulogic;
    thvalid           : std_ulogic;
    opmode            : std_logic_vector(1 downto 0);
    xcvrselect        : std_ulogic;
    termselect        : std_ulogic;
    suspend           : std_ulogic;
    reset             : std_ulogic;
    --ulpi            
    stp               : std_ulogic;
    --shared          
    dout              : std_logic_vector(7 downto 0);
    oen               : std_ulogic;
    --misc           
    dbus16_8          : std_ulogic;
    dppulldown        : std_ulogic;
    dmpulldown        : std_ulogic;
    idpullup          : std_ulogic;
    drvvbus           : std_ulogic;
    dischrgvbus       : std_ulogic;
    chrgvbus          : std_ulogic;
    txbitstuffenable  : std_ulogic;
    txbitstuffenableh : std_ulogic;
    fslsserialmode    : std_ulogic;
    txenablen         : std_ulogic;
    txdat             : std_ulogic;
    txse0             : std_ulogic;
    xcvrselect_1      : std_ulogic;
  end record;

  component usbdctrl is
    generic (
      hsindex  : integer range 0 to NAHBSLV-1 := 0;
      hirq     : integer range 0 to NAHBIRQ-1 := 0;
      haddr    : integer                      := 0;
      hmask    : integer                      := 16#FFF#;
      hmindex  : integer range 0 to NAHBMST-1 := 0;
      aiface   : integer range 0 to 1         := 0;
      memtech  : integer range 0 to NTECH     := DEFMEMTECH;
      uiface   : integer range 0 to 1         := 0;
      dwidth   : integer range 8 to 16        := 8;
      nepi     : integer range 1 to 16        := 1;
      nepo     : integer range 1 to 16        := 1;
      i0       : integer range 8 to 3072      := 1024;
      i1       : integer range 8 to 3072      := 1024;
      i2       : integer range 8 to 3072      := 1024;
      i3       : integer range 8 to 3072      := 1024;
      i4       : integer range 8 to 3072      := 1024;
      i5       : integer range 8 to 3072      := 1024;
      i6       : integer range 8 to 3072      := 1024;
      i7       : integer range 8 to 3072      := 1024;
      i8       : integer range 8 to 3072      := 1024;
      i9       : integer range 8 to 3072      := 1024;
      i10      : integer range 8 to 3072      := 1024;
      i11      : integer range 8 to 3072      := 1024;
      i12      : integer range 8 to 3072      := 1024;
      i13      : integer range 8 to 3072      := 1024;
      i14      : integer range 8 to 3072      := 1024;
      i15      : integer range 8 to 3072      := 1024;
      o0       : integer range 8 to 3072      := 1024;
      o1       : integer range 8 to 3072      := 1024;
      o2       : integer range 8 to 3072      := 1024;
      o3       : integer range 8 to 3072      := 1024;
      o4       : integer range 8 to 3072      := 1024;
      o5       : integer range 8 to 3072      := 1024;
      o6       : integer range 8 to 3072      := 1024;
      o7       : integer range 8 to 3072      := 1024;
      o8       : integer range 8 to 3072      := 1024;
      o9       : integer range 8 to 3072      := 1024;
      o10      : integer range 8 to 3072      := 1024;
      o11      : integer range 8 to 3072      := 1024;
      o12      : integer range 8 to 3072      := 1024;
      o13      : integer range 8 to 3072      := 1024;
      o14      : integer range 8 to 3072      := 1024;
      o15      : integer range 8 to 3072      := 1024;
      oepol    : integer range 0 to 1         := 0;
      syncprst : integer range 0 to 1         := 0;
      prsttime : integer range 0 to 512       := 0;
      sysfreq  : integer := 50000;
      keepclk  : integer range 0 to 1         := 0;
      sepirq   : integer range 0 to 1         := 0;
      irqi     : integer range 0 to NAHBIRQ-1 := 1;
      irqo     : integer range 0 to NAHBIRQ-1 := 2);
    port (
      uclk          : in  std_ulogic;
      usbi          : in  usb_in_type;
      usbo          : out usb_out_type;
      hclk          : in  std_ulogic;
      hrst          : in  std_ulogic;
      ahbmi         : in  ahb_mst_in_type;
      ahbmo         : out ahb_mst_out_type;
      ahbsi         : in  ahb_slv_in_type;
      ahbso         : out ahb_slv_out_type
    );
  end component;
    
  component usbdcl is
    generic (
      hindex   : integer                := 0;
      memtech  : integer                := DEFMEMTECH;
      uiface   : integer range 0 to 1   := 0;
      dwidth   : integer range 8 to 16  := 8;
      oepol    : integer range 0 to 1   := 0;
      syncprst : integer range 0 to 1   := 0;
      prsttime : integer range 0 to 512 := 0;
      sysfreq  : integer                := 50000;
      keepclk  : integer range 0 to 1   := 0
    );
    port (
      uclk     : in  std_ulogic;
      usbi     : in  usb_in_type;
      usbo     : out usb_out_type;
      hclk     : in  std_ulogic;
      hrst     : in  std_ulogic;
      ahbi     : in  ahb_mst_in_type;
      ahbo     : out ahb_mst_out_type
    );
  end component usbdcl;

  -- descriptor type
  type descriptor_type is array (natural range <>) of std_logic_vector(7 downto 0);
  
end usb;
