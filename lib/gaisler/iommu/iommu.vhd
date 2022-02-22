------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Package: 	iommu
-- File:	iommu.vhd
-- Author:	Jan Andersson - Aeroflex Gaisler
-- Contact:     support@gaisler.com
-- Description:	IOMMU package
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
library gaisler;
use gaisler.misc.all;
library techmap;
use techmap.gencomp.all;

package iommu is

  type griommu_stat_type is record
    hit    : std_ulogic;
    miss   : std_ulogic;
    pass   : std_ulogic;
    accok  : std_ulogic;
    accerr : std_ulogic;
    walk   : std_ulogic;
    lookup : std_ulogic;
    perr   : std_ulogic;
  end record;

  constant griommu_stat_none : griommu_stat_type :=
    ('0', '0', '0', '0', '0', '0', '0', '0');
  
  type griommu_stat_vector is array (natural range <>) of griommu_stat_type;

  subtype griommu_ctrl_type is ahb2ahb_ctrl_type;

  constant griommu_ctrl_none : griommu_ctrl_type := ahb2ahb_ctrl_none;

  subtype griommu_ifctrl_type is ahb2ahb_ifctrl_type;
    
  constant griommu_ifctrl_none : griommu_ifctrl_type := ahb2ahb_ifctrl_none;
  
  component griommu
    generic(
      memtech     : integer := 0;
      iohsindex   : integer := 0;
      syshmindex  : integer := 0;
      syshsindex  : integer := 0;
      syshaddr    : integer := 0;
      syshmask    : integer := 16#FFF#;
      syshirq     : integer range 1 to NAHBIRQ-1 := 1;
      slv         : integer range 0 to 1 := 0;
      dir         : integer range 0 to 1 := 0;   -- 0 - down, 1 - up
      ffact       : integer range 0 to 15:= 2;
      pfen        : integer range 0 to 1 := 0;
      wburst      : integer range 2 to 32 := 8;
      iburst      : integer range 4 to 8 :=  8;
      rburst      : integer range 2 to 32 := 8;
      irqsync     : integer range 0 to 2 := 0;
      bar0        : integer range 0 to 1073741823 := 0;
      bar1        : integer range 0 to 1073741823 := 0;
      bar2        : integer range 0 to 1073741823 := 0;
      bar3        : integer range 0 to 1073741823 := 0;
      sbus        : integer := 0;
      mbus        : integer := 0;
      ioarea      : integer := 0;
      ibrsten     : integer := 0;
      lckdac      : integer range 0 to 2 := 0;
      slvmaccsz   : integer range 32 to 256 := 32;
      mstmaccsz   : integer range 32 to 256 := 32;
      rdcomb      : integer range 0 to 2 := 0;
      wrcomb      : integer range 0 to 2 := 0;
      combmask    : integer := 16#ffff#;
      allbrst     : integer range 0 to 1 := 0;
      ifctrlen    : integer range 0 to 1 := 0;
      fcfs        : integer range 0 to NAHBMST := 0;
      fcfsmtech   : integer range 0 to NTECH := inferred;
      scantest    : integer range 0 to 1 := 0;
      split       : integer range 0 to 1 := 1;
      dynsplit    : integer range 0 to 1 := 0;
      nummst      : integer range 1 to NAHBMST-1 := 1;
      numgrp      : integer range 1 to NAHBMST-1 := 1;
      stat        : integer range 0 to 1 := 0;  -- Enable statistics output
      apv         : integer range 0 to 1 := 1;  -- Access Protection Vector
      apvc_en     : integer range 0 to 1 := 0;  -- APV cache enable
      apvc_ways   : integer range 1 to 1 := 1;  -- APV cache ways
      apvc_lines  : integer := 16;        -- APV cache lines
      apvc_tech   : integer := 0;         -- APV cache technology
      apvc_gseta  : integer range 0 to 1 := 0;  -- APV group set addressing
      apvc_caddr  : integer := 0;   -- APV Cacheable area base addr
      apvc_cmask  : integer := 0;         -- APV Cacheable area mask
      apvc_pipe   : integer range 0 to 1 := 0;  -- APV cache pipelining
      iommu       : integer range 0 to 1 := 0;  -- IOMMU
      iommutype   : integer range 0 to 1 := 0;
      tlb_num     : integer := 0;
      tlb_type    : integer range 0 to 1 := 0;
      tlb_tech    : integer := 0;
      tlb_gseta   : integer range 0 to 1 := 0;
      tlb_pipe    : integer range 0 to 1 := 0;
      tmask       : integer range 0 to 255 := 16#ff#;
      tbw_accsz   : integer range 0 to 256 := 32;  -- Table walk access size
      dpagesz     : integer range 0 to 1 := 0;
      ft          : integer range 0 to 1 := 0;
      narb        : integer range 0 to 15 := 0
      );
    port (
      rstn        : in  std_ulogic;
      hclksys     : in  std_ulogic;
      hclkio      : in  std_ulogic;
      -- Slave interface, connect to io bus
      io_ahbsi    : in  ahb_slv_in_type;
      io_ahbso    : out ahb_slv_out_type;
      io_ahbpnp   : in  ahb_mst_out_vector_type(nummst-1 downto 0);
      -- Master interface, connect to system bus
      sys_ahbmi   : in  ahb_mst_in_type;
      sys_ahbmo   : out ahb_mst_out_type;
      -- Slave output vectors on system bus
      sys_ahbpnp  : in  ahb_slv_out_vector;
      -- Slave interface for register i/f on system bus
      sys_ahbsi   : in  ahb_slv_in_type;
      sys_ahbso   : out ahb_slv_out_type;
      -- Lock interface for bidirectional configurations
      lcki        : in  griommu_ctrl_type;
      lcko        : out griommu_ctrl_type;
      -- Statistics
      stato       : out griommu_stat_type;
      -- Interface control, for clock gating
      ifctrl      : in  griommu_ifctrl_type := griommu_ifctrl_none
      );
  end component;

  component griommu_mb
    generic(
      memtech     : integer := 0;
      iohsindex   : integer := 0;
      syshmindex  : integer := 0;
      syshmindex2 : integer := 0;
      syshsindex  : integer := 0;
      syshaddr    : integer := 0;
      syshmask    : integer := 16#FFF#;
      syshirq     : integer range 1 to NAHBIRQ-1 := 1;
      slv         : integer range 0 to 1 := 0;
      dir         : integer range 0 to 1 := 0;   -- 0 - down, 1 - up
      ffact       : integer range 0 to 15:= 2;
      pfen        : integer range 0 to 1 := 0;
      wburst      : integer range 2 to 32 := 8;
      iburst      : integer range 4 to 8 :=  8;
      rburst      : integer range 2 to 32 := 8;
      irqsync     : integer range 0 to 2 := 0;
      bar0        : integer range 0 to 1073741823 := 0;
      bar1        : integer range 0 to 1073741823 := 0;
      bar2        : integer range 0 to 1073741823 := 0;
      bar3        : integer range 0 to 1073741823 := 0;
      sbus        : integer := 0;
      mbus        : integer := 0;
      ioarea      : integer := 0;
      ibrsten     : integer := 0;
      lckdac      : integer range 0 to 2 := 0;
      slvmaccsz   : integer range 32 to 256 := 32;
      mstmaccsz   : integer range 32 to 256 := 32;
      rdcomb      : integer range 0 to 2 := 0;
      wrcomb      : integer range 0 to 2 := 0;
      combmask    : integer := 16#ffff#;
      allbrst     : integer range 0 to 1 := 0;
      ifctrlen    : integer range 0 to 1 := 0;
      fcfs        : integer range 0 to NAHBMST := 0;
      fcfsmtech   : integer range 0 to NTECH := inferred;
      scantest    : integer range 0 to 1 := 0;
      split       : integer range 0 to 1 := 1;
      dynsplit    : integer range 0 to 1 := 0;
      nummst      : integer range 1 to NAHBMST-1 := 1;
      numgrp      : integer range 1 to NAHBMST-1 := 1;
      stat        : integer range 0 to 1 := 0;  -- Enable statistics output
      apv         : integer range 0 to 1 := 1;  -- Access Protection Vector
      apvc_en     : integer range 0 to 1 := 0;  -- APV cache enable
      apvc_ways   : integer range 1 to 1 := 1;  -- APV cache ways
      apvc_lines  : integer := 16;        -- APV cache lines
      apvc_tech   : integer := 0;         -- APV cache technology
      apvc_gseta  : integer range 0 to 1 := 0;  -- APV group set addressing
      apvc_caddr  : integer := 0;   -- APV Cacheable area base addr
      apvc_cmask  : integer := 0;         -- APV Cacheable area mask
      apvc_pipe   : integer range 0 to 1 := 0;  -- APV cache pipelining
      iommu       : integer range 0 to 1 := 0;  -- IOMMU
      iommutype   : integer range 0 to 1 := 0;
      tlb_num     : integer := 0;
      tlb_type    : integer range 0 to 1 := 0;
      tlb_tech    : integer := 0;
      tlb_gseta   : integer range 0 to 1 := 0;
      tlb_pipe    : integer range 0 to 1 := 0;
      tmask       : integer range 0 to 255 := 16#ff#;
      tbw_accsz   : integer range 0 to 256 := 32;  -- Table walk access size
      dpagesz     : integer range 0 to 1 := 0;
      ft          : integer range 0 to 1 := 0;
      narb        : integer range 0 to 15 := 0;
      multiirq    : integer range 0 to 1 := 0
      );
    port (
      rstn        : in  std_ulogic;
      hclksys     : in  std_ulogic;
      hclkio      : in  std_ulogic;
      -- Slave interface, connect to io bus
      io_ahbsi    : in  ahb_slv_in_type;
      io_ahbso    : out ahb_slv_out_type;
      io_ahbpnp   : in  ahb_mst_out_vector_type(nummst-1 downto 0);
      -- Master interface, connect to system bus 0
      sys_ahbmi   : in  ahb_mst_in_type;
      sys_ahbmo   : out ahb_mst_out_type;
      -- Slave output vectors on system bus 0
      sys_ahbpnp  : in  ahb_slv_out_vector;
      -- Master interface, connect to system bus 1
      sys_ahbmi2  : in  ahb_mst_in_type;
      sys_ahbmo2  : out ahb_mst_out_type;
      -- Slave output vectors on system bus 1
      sys_ahbpnp2 : in  ahb_slv_out_vector;
      -- Slave interface for register i/f on system bus
      sys_ahbsi   : in  ahb_slv_in_type;
      sys_ahbso   : out ahb_slv_out_type;
      -- Lock interface for bidirectional configurations
      lcki        : in  griommu_ctrl_type;
      lcko        : out griommu_ctrl_type;
      -- Statistics
      stato       : out griommu_stat_type;
      -- Interface control, for clock gating
      ifctrl      : in  griommu_ifctrl_type := griommu_ifctrl_none
      );
  end component;

  component griommux
    generic(
      memtech     : integer := 0;
      iohsindex   : integer := 0;
      syshmindex  : integer := 0;
      syshmindex2 : integer := 0;
      syshsindex  : integer := 0;
      syshaddr    : integer := 0;
      syshmask    : integer := 16#FFF#;
      syshirq     : integer range 1 to NAHBIRQ-1 := 1;
      slv         : integer range 0 to 1 := 0;
      dir         : integer range 0 to 1 := 0;   -- 0 - down, 1 - up
      ffact       : integer range 0 to 15:= 2;
      pfen        : integer range 0 to 1 := 0;
      wburst      : integer range 2 to 32 := 8;
      iburst      : integer range 4 to 8 :=  8;
      rburst      : integer range 2 to 32 := 8;
      irqsync     : integer range 0 to 2 := 0;
      bar0        : integer range 0 to 1073741823 := 0;
      bar1        : integer range 0 to 1073741823 := 0;
      bar2        : integer range 0 to 1073741823 := 0;
      bar3        : integer range 0 to 1073741823 := 0;
      sbus        : integer := 0;
      mbus        : integer := 0;
      ioarea      : integer := 0;
      ibrsten     : integer := 0;
      lckdac      : integer range 0 to 2 := 0;
      slvmaccsz   : integer range 32 to 256 := 32;
      mstmaccsz   : integer range 32 to 256 := 32;
      rdcomb      : integer range 0 to 2 := 0;
      wrcomb      : integer range 0 to 2 := 0;
      combmask    : integer := 16#ffff#;
      allbrst     : integer range 0 to 1 := 0;
      ifctrlen    : integer range 0 to 1 := 0;
      fcfs        : integer range 0 to NAHBMST := 0;
      fcfsmtech   : integer range 0 to NTECH := inferred;
      scantest    : integer range 0 to 1 := 0;
      split       : integer range 0 to 1 := 1;
      dynsplit    : integer range 0 to 1 := 0;
      nummst      : integer range 1 to NAHBMST-1 := 1;
      numgrp      : integer range 1 to NAHBMST-1 := 1;
      stat        : integer range 0 to 1 := 0;
      apv         : integer range 0 to 1 := 1;
      apvc_en     : integer range 0 to 1 := 0;
      apvc_ways   : integer range 1 to 1 := 1;
      apvc_lines  : integer := 16;
      apvc_tech   : integer := 0;
      apvc_gseta  : integer range 0 to 1 := 0;
      apvc_caddr  : integer := 0;
      apvc_cmask  : integer := 0;
      apvc_pipe   : integer range 0 to 1 := 0;
      iommu       : integer range 0 to 1 := 0;
      iommutype   : integer range 0 to 1 := 0;
      tlb_num     : integer := 0;
      tlb_type    : integer range 0 to 1 := 0;
      tlb_tech    : integer := 0;
      tlb_gseta   : integer range 0 to 1 := 0;
      tlb_pipe    : integer range 0 to 1 := 0;
      tmask       : integer range 0 to 255 := 16#ff#;
      tbw_accsz   : integer range 0 to 256 := 32;
      dpagesz     : integer range 0 to 1 := 0;
      ft          : integer range 0 to 1 := 0;
      narb        : integer range 0 to 15 := 0;
      multibus    : integer range 0 to 1 := 0;
      multiirq    : integer range 0 to 1 := 0
      );
    port (
      rstn        : in  std_ulogic;
      hclksys     : in  std_ulogic;
      hclkio      : in  std_ulogic;
      -- Slave interface, connect to io bus
      io_ahbsi    : in  ahb_slv_in_type;
      io_ahbso    : out ahb_slv_out_type;
      io_ahbpnp   : in  ahb_mst_out_vector_type(nummst-1 downto 0);
      -- Master interface, connect to system bus
      sys_ahbmi   : in  ahb_mst_in_type;
      sys_ahbmo   : out ahb_mst_out_type;
      -- Slave output vectors on system bus
      sys_ahbpnp  : in  ahb_slv_out_vector;
      -- Master interface, connect to system bus 1 (if available)
      sys_ahbmi2  : in  ahb_mst_in_type;
      sys_ahbmo2  : out ahb_mst_out_type;
      -- Slave output vectors on system bus 1 (if available)
      sys_ahbpnp2 : in  ahb_slv_out_vector_type((NAHBMST-1)*multibus downto 0);
      -- Slave interface for register i/f on system bus
      sys_ahbsi   : in  ahb_slv_in_type;
      sys_ahbso   : out ahb_slv_out_type;
      -- Lock interface for bidirectional configurations
      lcki        : in  griommu_ctrl_type;
      lcko        : out griommu_ctrl_type;
      -- Statistics
      stato       : out griommu_stat_type;
      -- Interface control, for clock gating
      ifctrl      : in  griommu_ifctrl_type := griommu_ifctrl_none
      );
  end component;


  
  function griommu_membar(memaddr : ahb_addr_type; prefetch, cache : std_ulogic;
                          addrmask : ahb_addr_type)
  return integer;

  function griommu_iobar(memaddr : ahb_addr_type; addrmask : ahb_addr_type)
  return integer;

  ----------------------------------------------------------------------------
  -- Functions for data manipulation in little endian systems
  ----------------------------------------------------------------------------
  function be_le_conv(
    constant data : std_logic_vector; 
    constant endian : std_ulogic; 
    constant ahb_dw : integer ) 
  return std_logic_vector;

  function bl_wrd_swap(
    constant data : std_logic_vector; 
    constant endian : std_ulogic; 
    constant dw : integer) 
  return std_logic_vector;
  
end;

package body iommu is

  
  function griommu_membar(memaddr : ahb_addr_type; prefetch, cache : std_ulogic;
                          addrmask : ahb_addr_type)
  return integer is
  begin
    return ahb2ahb_membar(memaddr, prefetch, cache, addrmask);
  end;

  function griommu_iobar(memaddr : ahb_addr_type; addrmask : ahb_addr_type)
  return integer is
  begin
    return ahb2ahb_iobar(memaddr, addrmask);
  end;

  -- Byte swap
  function be_le_conv(
    constant data : std_logic_vector; 
    constant endian : std_ulogic; 
    constant ahb_dw : integer
    ) return std_logic_vector is
    variable newdata : std_logic_vector(ahb_dw-1 downto 0);
    variable data_l : std_logic_vector(ahb_dw-1 downto 0);
    variable bytes_n : integer := 0;
    variable outdata : std_logic_vector(data'high downto data'low);
    constant zero_vec : std_logic_vector(ahb_dw-1 downto 0):= (others => '0');
  begin
    bytes_n := ahb_dw/8;
    newdata := zero_vec;
    data_l := zero_vec;

    if endian = '0' then
      outdata := data;
    else
      if data'length < ahb_dw then
        data_l := zero_vec(ahb_dw-1 downto data'high+1) & data;
      else
        data_l := data;
      end if;
      for i in 0 to (bytes_n -1) loop
        newdata((i*8+7) downto i*8):= data_l(((bytes_n - i)*8)-1 downto ((bytes_n - (i + 1))*8));
      end loop;
      outdata := newdata(ahb_dw-1 downto ahb_dw - data'length);
    end if;
    return outdata;
  end be_le_conv;
 
  -- Word swap
  function bl_wrd_swap(
    constant data : std_logic_vector; 
    constant endian : std_ulogic; 
    constant dw : integer
    ) return std_logic_vector is
    variable newdata : std_logic_vector(dw-1 downto 0);
    variable words_n : integer := 0;
    variable outdata : std_logic_vector(dw-1 downto 0);
  begin
    words_n := dw/32;

    if endian = '0' then
      outdata := data;
    else
      for i in 0 to (words_n -1) loop
        outdata((i*32)+31 downto i*32):= data( ((words_n - i)*32)-1 downto (words_n - (i + 1))*32 );
      end loop;
    end if;
    return outdata;
  end bl_wrd_swap; 


end;

