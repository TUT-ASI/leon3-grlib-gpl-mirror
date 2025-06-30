------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
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
-- Entity:      noelv
-- File:        noelv.vhd
-- Author:      Nils Wessman, Cobham Gaisler
-- Description: NOEL-V single processor core
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.noelv_cpu_cfg.all;

entity noelvcpu is
  generic (
    hindex   : integer;
    fabtech  : integer;
    memtech  : integer;
    cached   : integer;
    wbmask   : integer;
    busw     : integer;
    physaddr : integer range 32 to 56 := 32; -- Physical Addressing
    cmemconf : integer;
    rfconf   : integer;
    fpuconf  : integer;
    tcmconf  : integer;
    mulconf  : integer;
    intcconf : integer;
    mnintid  : integer;
    snintid  : integer;
    gnintid  : integer;
    disas    : integer;
    pbaddr   : integer;
    cfg      : integer;
    cgen     : integer := 0;
    asyncif  : integer := 0;
    scantest : integer
    );
  port (
    clk       : in  std_ulogic;
    gclk      : in  std_ulogic;
    rstn      : in  std_ulogic;
    ahbi      : in  ahb_mst_in_type;
    ahbo      : out ahb_mst_out_type;
    ahbsi     : in  ahb_slv_in_type;
    ahbso     : in  ahb_slv_out_vector;
    irqi      : in  nv_irq_in_type;
    irqo      : out nv_irq_out_type;
    dbgi      : in  nv_debug_in_type;
    dbgo      : out nv_debug_out_type;
    tpo       : out nv_full_trace_type;
    cnt       : out nv_counter_out_type;
    pwrd      : out std_ulogic
    );
end;

architecture hier of noelvcpu is
begin

  u0 : cpucorenv -- NOEL-V Core
    generic map (
      hindex              => hindex,
      fabtech             => fabtech,
      memtech             => memtech,
      cached              => cached,
      wbmask              => wbmask,
      busw                => busw,
      physaddr            => physaddr,
      cmemconf            => cmemconf,
      fpuconf             => fpuconf,
      rfconf              => rfconf,
      tcmconf             => tcmconf,
      mulconf             => mulconf,
      intcconf            => intcconf,
      cfg                 => cfg,
      disas               => disas,
      cgen                => cgen,
      asyncif             => asyncif,
      scantest            => scantest
      )
    port map (
      clk             => clk,
      gclk            => gclk,
      rstn            => rstn,
      ahbi            => ahbi,
      ahbo            => ahbo,
      ahbsi           => ahbsi,
      ahbso           => ahbso,
      irqi            => irqi,
      irqo            => irqo,
      dbgi            => dbgi,
      dbgo            => dbgo,
      tpo             => tpo,
      cnt             => cnt,
      pwrd            => pwrd
      );
end;
