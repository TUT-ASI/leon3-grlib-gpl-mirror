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
-- Entity:      dmnv_ic
-- File:        dmnv_ic.vhd
-- Author:      Nils Wessman
-- Description: NOEL-V debug module: interconnect structure
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.devices.all;
use grlib.stdlib.all;
use grlib.amba.all;
library gaisler;
use gaisler.l5nv_shared.all;

entity dmnv_ic is
  generic (
    ndmamst   : integer;
    -- conv bus
    cbmidx    : integer;
    -- PnP
    dmhaddr   : integer;
    dmhmask   : integer;
    pnpaddrhi : integer;
    pnpaddrlo : integer;
    dmslvidx  : integer;
    dmmstidx  : integer
    -- pipelining 
    --; plmdata   : integer
    );
  port (
    clk     : in  std_ulogic;
    rstn    : in  std_ulogic;
    -- Debug-link interface
    dmami   : out ahb_mst_in_vector_type(ndmamst-1 downto 0);
    dmamo   : in  ahb_mst_out_vector_type(ndmamst-1 downto 0);
    -- Conventional AHB bus interface
    cbmi    : in  ahb_mst_in_type;
    cbmo    : out ahb_mst_out_type;
    cbsi    : in  ahb_slv_in_type;
    -- Debug-module AHB bus interface
    dmmi    : in  ahb_mst_in_type;
    dmmo    : out ahb_mst_out_type;
    -- Plug'n'play record for debug module (patched into PnP)
    dmpnp   : in  ahb_config_type
    );
end;

architecture rtl of dmnv_ic is

begin

  ----------------------------------------------------------------------------
  -- Core
  ----------------------------------------------------------------------------
  core0: dmnv_ic_ebp
    generic map (
      ndmamst   => ndmamst   ,
      -- conv bus
      cbmidx    => cbmidx    ,
      -- PnP
      dmhaddr   => dmhaddr   ,
      dmhmask   => dmhmask   ,
      pnpaddrhi => pnpaddrhi ,
      pnpaddrlo => pnpaddrlo ,
      dmslvidx  => dmslvidx  ,
      dmmstidx  => dmmstidx
      )
    port map (
      clk     => clk     ,
      rstn    => rstn    ,
      -- Debug-link interface
      dmami   => dmami   ,
      dmamo   => dmamo   ,
      -- Conventional AHB bus interface
      cbmi    => cbmi    ,
      cbmo    => cbmo    ,
      -- Debug-module AHB bus interface
      dmmi    => dmmi    ,
      dmmo    => dmmo    ,
      -- Plug'n'play record for debug module (patched into PnP)
      dmpnp   => dmpnp
      );

end;

