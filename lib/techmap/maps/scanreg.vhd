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
-- Entity: 	scanregi, scanrego, scanregio
-- File:	scanreg.vhd
-- Author:	Magnus Hjorth - Aeroflex Gaisler
-- Description:	Technology wrapper for boundary scan registers
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.alltap.all;

entity scanregi is
  generic (
    tech : integer := 0
    );
  port (
    pad     : in std_ulogic;
    core    : out std_ulogic;
    tck     : in std_ulogic;
    tdi     : in std_ulogic;
    tdo     : out std_ulogic;
    bsshft  : in std_ulogic;
    bscapt  : in std_ulogic;
    bsupd   : in std_ulogic;
    bsdrive : in std_ulogic;
    bshighz : in std_ulogic
    );
end;

architecture tmap of scanregi is
begin

  gen0: if true generate
    x: scanregi_inf port map (pad,core,tck,tdi,tdo,bsshft,bscapt,bsupd,bsdrive,bshighz);
  end generate;
  
end;
  
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.alltap.all;

entity scanrego is
  generic (
    tech : integer := 0
    );
  port (
    pad     : out std_ulogic;
    core    : in std_ulogic;
    samp    : in std_ulogic;
    tck     : in std_ulogic;
    tdi     : in std_ulogic;
    tdo     : out std_ulogic;
    bsshft  : in std_ulogic;
    bscapt  : in std_ulogic;
    bsupd   : in std_ulogic;
    bsdrive : in std_ulogic
    );
end;

architecture tmap of scanrego is
begin

  gen0: if true generate
    x: scanrego_inf port map (pad,core,samp,tck,tdi,tdo,bsshft,bscapt,bsupd,bsdrive);
  end generate;
  
end;

-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.alltap.all;

entity scanregio is
  generic (
    tech : integer := 0;
    hzsup: integer range 0 to 1 := 1
    );
  port (
    pado    : out std_ulogic;
    padoen  : out std_ulogic;
    padi    : in std_ulogic;
    coreo   : in std_ulogic;
    coreoen : in std_ulogic;
    corei   : out std_ulogic;
    tck     : in std_ulogic;
    tdi     : in std_ulogic;
    tdo     : out std_ulogic;
    bsshft  : in std_ulogic;
    bscapt  : in std_ulogic;
    bsupdi  : in std_ulogic;
    bsupdo  : in std_ulogic;
    bsdrive : in std_ulogic;
    bshighz : in std_ulogic
    );
end;

architecture tmap of scanregio is
begin

  gen0: if true generate
    x: scanregio_inf
      generic map (hzsup)
      port map (pado,padoen,padi,coreo,coreoen,corei,tck,tdi,tdo,
                bsshft,bscapt,bsupdi,bsupdo,bsdrive,bshighz);
  end generate;
  
end;

