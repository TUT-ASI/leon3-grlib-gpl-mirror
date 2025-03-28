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
-- Entity:      mmuiface
-- File:        mmuiface.vhd
-- Author:      Konrad Eisele, Jiri Gaisler - Gaisler Research
-- Description: MMU interface types
------------------------------------------------------------------------------  

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.mmuconfig.all;
library techmap;
use techmap.gencomp.all;

package mmuiface is

type mmutlbcam_in_type is record
  mmctrl   : mmctrl_type1;
  tagin    : tlbcam_tfp;
  tagwrite : tlbcam_reg;
  trans_op : std_logic;
  flush_op : std_logic;
  write_op : std_logic;
  wb_op    : std_logic;
  mmuen    : std_logic;
  mset     : std_logic;
end record;
type mmutlbcami_a is array (natural range <>) of mmutlbcam_in_type;

type mmutlbcam_out_type is record
  pteout   : std_logic_vector(31 downto 0);
  LVL      : std_logic_vector(1 downto 0);    -- level in pth
  hit      : std_logic;
  ctx      : std_logic_vector(M_CTX_SZ-1 downto 0);    -- for diagnostic access
  valid    : std_logic;                                -- for diagnostic access
  vaddr    : std_logic_vector(31 downto 0);            -- for diagnostic access
  NEEDSYNC : std_logic;
  WBNEEDSYNC : std_logic;
end record;
type mmutlbcamo_a is array (natural range <>) of mmutlbcam_out_type;

-- mmu i/o

type mmuidc_data_in_type is record
  data             : std_logic_vector(31 downto 0);
  su               : std_logic;
  read             : std_logic;
  isid             : mmu_idcache;
  wb_data          : std_logic_vector(31 downto 0);
end record;

type mmuidc_data_out_type is record
  finish           : std_logic;
  data             : std_logic_vector(31 downto 0);
  cache            : std_logic;
  accexc           : std_logic;
  subit            : std_logic;
end record;

constant mmuidco_zero : mmuidc_data_out_type := ('0', zero32, '0', '0', '0');

type mmudc_in_type is record
  trans_op         : std_logic; 
  transdata        : mmuidc_data_in_type;
  
  -- dcache extra signals
  flush_op         : std_logic;
  diag_op          : std_logic;
  wb_op            : std_logic;

  fsread           : std_logic;
  mmctrl1          : mmctrl_type1;
end record;

type mmudc_out_type is record
  grant            : std_logic;
  transdata        : mmuidc_data_out_type;
  -- dcache extra signals
  mmctrl2          : mmctrl_type2;
  -- writebuffer out
  wbtransdata      : mmuidc_data_out_type;
  tlbmiss          : std_logic;
end record;

type mmuic_in_type is record
  trans_op         : std_logic; 
  transdata        : mmuidc_data_in_type;
end record;

type mmuic_out_type is record
  grant            : std_logic;
  transdata        : mmuidc_data_out_type;
  tlbmiss          : std_logic;
end record;

constant mmudco_zero : mmudc_out_type := ('0', mmuidco_zero,
	mmctrl2_zero, mmuidco_zero, '0');

constant mmuico_zero : mmuic_out_type := ('0', mmuidco_zero, '0');

--#lrue i/o
type mmulrue_in_type is record
  touch        : std_logic;
  pos          : std_logic_vector(M_ENT_MAX_LOG-1 downto 0);
  clear        : std_logic;
  flush        : std_logic;
  
  left         : std_logic_vector(M_ENT_MAX_LOG-1 downto 0);
  fromleft     : std_logic;
  right        : std_logic_vector(M_ENT_MAX_LOG-1 downto 0);
  fromright    : std_logic;
end record;
type mmulruei_a is array (natural range <>) of mmulrue_in_type;

type mmulrue_out_type is record
  pos          : std_logic_vector(M_ENT_MAX_LOG-1 downto 0);
  movetop      : std_logic;
end record;
constant mmulrue_out_none : mmulrue_out_type := (zero32(M_ENT_MAX_LOG-1 downto 0), '0');
type mmulrueo_a is array (natural range <>) of mmulrue_out_type;

--#lru i/o
type mmulru_in_type is record
  touch     : std_logic;
  touchmin  : std_logic;
  flush     : std_logic;
  pos       : std_logic_vector(M_ENT_MAX_LOG-1 downto 0);
  mmctrl1   : mmctrl_type1;
end record;

type mmulru_out_type is record
  pos      : std_logic_vector(M_ENT_MAX_LOG-1 downto 0);
end record;

--#mmu: tw i/o
type memory_mm_in_type is record
  address          : std_logic_vector(31 downto 0); 
  data             : std_logic_vector(31 downto 0);
  size             : std_logic_vector(1 downto 0);
  burst            : std_logic;
  read             : std_logic;
  req              : std_logic;
  lock             : std_logic;
  -- next cycle value (for retiming)
  next_address     : std_logic_vector(31 downto 0);
  next_data        : std_logic_vector(31 downto 0);
  next_size        : std_logic_vector(1 downto 0);
  next_burst       : std_logic;
  next_read        : std_logic;
  next_req         : std_logic;
  next_lock        : std_logic;
end record;

constant mci_zero : memory_mm_in_type := (
  X"00000000", X"00000000", "00", '0', '0', '0', '0',
  X"00000000", X"00000000", "00", '0', '0', '0', '0');

type memory_mm_out_type is record
  data             : std_logic_vector(31 downto 0); -- memory data
  ready            : std_logic;			    -- cycle ready
  grant            : std_logic;			    -- 
  retry            : std_logic;			    -- 
  mexc             : std_logic;			    -- memory exception
  werr             : std_logic;			    -- memory write error
  cache            : std_logic;		            -- cacheable data
end record;

type mmutw_in_type is record
  walk_op_ur       : std_logic;
  areq_ur          : std_logic;
  tlbmiss          : std_logic;
  data             : std_logic_vector(31 downto 0);
  adata            : std_logic_vector(31 downto 0);
  aaddr            : std_logic_vector(31 downto 0);
end record;
type mmutwi_a is array (natural range <>) of mmutw_in_type;

type mmutw_out_type is record
  finish           : std_logic;
  data             : std_logic_vector(31 downto 0);
  addr             : std_logic_vector(31 downto 0);
  lvl              : std_logic_vector(1 downto 0);
  fault_mexc       : std_logic;
  fault_trans      : std_logic;
  fault_inv        : std_logic;
  fault_lvl        : std_logic_vector(1 downto 0);
end record;
type mmutwo_a is array (natural range <>) of mmutw_out_type;

-- mmu tlb i/o

type mmutlb_in_type is record
  flush_op    : std_logic;
  wb_op       : std_logic;
  
  trans_op    : std_logic;
  transdata   : mmuidc_data_in_type;
  s2valid     : std_logic;
  
  mmctrl1     : mmctrl_type1;
end record;
type mmutlbi_a is array (natural range <>) of mmutlb_in_type;

type mmutlbfault_out_type is record
  fault_pro   : std_logic;
  fault_pri   : std_logic;
  fault_access     : std_logic; 
  fault_mexc       : std_logic;
  fault_trans      : std_logic;
  fault_inv        : std_logic;
  fault_lvl        : std_logic_vector(1 downto 0);
  fault_su         : std_logic;
  fault_read       : std_logic;
  fault_isid       : mmu_idcache;
  fault_addr       : std_logic_vector(31 downto 0);
end record;

constant mmutlbfault_out_zero : mmutlbfault_out_type := (
  fault_pro    => '0',
  fault_pri    => '0',
  fault_access => '0',
  fault_mexc   => '0',
  fault_trans  => '0',
  fault_inv    => '0',
  fault_lvl    => (others => '0'),
  fault_su     => '0',
  fault_read   => '0',
  fault_isid   => id_icache,
  fault_addr   => (others => '0'));

type mmutlb_out_type is record
  transdata   : mmuidc_data_out_type;
  fault       : mmutlbfault_out_type;
  nexttrans   : std_logic;
  s1finished  : std_logic;
  
  -- writebuffer out
  wbtransdata      : mmuidc_data_out_type;
end record; 
type mmutlbo_a is array (natural range <>) of mmutlb_out_type;

function mmu_subit_set(acc : std_logic_vector(2 downto 0)) return std_logic;

end;

package body mmuiface is

  function mmu_subit_set(acc : std_logic_vector(2 downto 0))
    return std_logic is
    variable ret : std_logic;
  begin

    ret := '0';

    if ( acc = "110" or acc = "111" ) then
      ret := '1';
    end if;

    return ret;

  end ;

end mmuiface;

