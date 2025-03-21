
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
-- Entity:      aplic
-- File:        aplic.vhd
-- Author:      Francisco Bas, Cobham Gaisler AB
-- Description: APLIC types and components
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.amba.all;

package aplic is
  
  ----------------------------------------------------------------------------
  -- Constant definition
  ----------------------------------------------------------------------------
  constant MAX_DOMAINS : integer := 32;    
  constant MAX_HARTS   : integer := 32;    -- According to the APLIC specs 16383. However, a maximum of 512 harts 
                                           -- is considered enough and assigning 32 KiB per domain eases the design
  constant MAX_SOURCES : integer := 1023;  -- According to the APLIC specs

  -- Source Mode (SM) constatns
  constant inactive : std_logic_vector(2 downto 0) := "000"; -- 0
  constant detached : std_logic_vector(2 downto 0) := "001"; -- 1
  constant edge1    : std_logic_vector(2 downto 0) := "100"; -- 4
  constant edge0    : std_logic_vector(2 downto 0) := "101"; -- 5
  constant level1   : std_logic_vector(2 downto 0) := "110"; -- 6
  constant level0   : std_logic_vector(2 downto 0) := "111"; -- 7


  ----------------------------------------------------------------------------
  -- Type definition
  ----------------------------------------------------------------------------
  -- These type has the biggest possible indexis. However, not all of them are use
  type preset_active_harts_type is array (0 to MAX_DOMAINS-1) of std_logic_vector(MAX_HARTS-1 downto 0);

  type domaincfg_type is record
    IE  : std_ulogic;
    DM  : std_ulogic;
    BE  : std_ulogic;
  end record;
  type domaincfg_vector is array (natural range <>) of domaincfg_type;

  type mmsiaddrcfg_type is record
    base_ppn  : std_logic_vector(43 downto 0);
    L         : std_ulogic;
    HHXS      : std_logic_vector(4 downto 0);
    LHXS      : std_logic_vector(2 downto 0);
    HHXW      : std_logic_vector(2 downto 0);
    LHXW      : std_logic_vector(3 downto 0);
  end record;

  type smsiaddrcfg_type is record
    base_ppn  : std_logic_vector(43 downto 0);
    LHXS      : std_logic_vector(2 downto 0);
  end record;

  
  ----------------------------------------------------------------------------
  -- Function declaration
  ----------------------------------------------------------------------------
  function bits2hmask(addr_bits : integer) return integer;
  function calc_upperLimit(addr_bits : integer) return integer;
  function is_leaf(domain : integer; doms_per_branch : integer) return boolean;
  function is_head(domain : integer; doms_per_branch : integer) return boolean;
  function get_branch(domain : integer; doms_per_branch : integer) return integer;
  function set_leaf_doms(in_vec          : std_logic_vector;
                         branches        : integer;
                         doms_per_branch : integer) return std_logic_vector;

  ----------------------------------------------------------------------------
  -- Component declaration
  ----------------------------------------------------------------------------
  component aplic_encoder
    generic (
      nsources        : integer := 32;
      srcbits         : integer := 6;
      prbits          : integer := 4
      );
    port (
      rstn    : in  std_ulogic;
      clk     : in  std_ulogic;
      ip      : in  std_logic_vector(nsources-1 downto 0);
      pr_in   : in  std_logic_vector((prbits*nsources)-1 downto 0);
      enable  : in  std_logic_vector(nsources-1 downto 0);
      id      : out std_logic_vector(srcbits-1 downto 0);
      ip_out  : out std_logic;
      pr_out  : out std_logic_vector(prbits-1 downto 0)
      );
  end component;


  component graplic_ahb 
    generic (
      hmindex             : integer range 0 to NAHBMST-1   := 0;
      hsindex             : integer range 0 to NAHBSLV-1   := 0;
      haddr               : integer range 0 to 16#FFF#     := 0;
      nsources            : integer range 1 to MAX_SOURCES := 1023;
      ncpu                : integer range 0 to MAX_HARTS   := 8;
      --ndomains            : integer range 0 to MAX_DOMAINS := 3;
      branches            : integer range 0 to 10          := 1; 
      doms_per_branch     : integer range 0 to MAX_DOMAINS := 3; 
      endianness          : integer range 0 to 2           := 1; 
      S_EN                : integer range 0 to 1           := 1; 
      H_EN                : integer range 0 to 1           := 1; 
      GEILEN              : integer                        := 6; 
      grouped_harts       : integer range 0 to 1           := 0; 
      mmsiaddrcfg_fixed   : integer range 0 to 1           := 1;
      mbase_PPN           : std_logic_vector(31 downto 0)  := x"00000000"; 
      sbase_PPN           : std_logic_vector(31 downto 0)  := x"00000000"; 
      mLHXS               : integer                        := 0; 
      sLHXS               : integer                        := 0; 
      HHXS                : integer                        := 0; 
      LHXW                : integer                        := 0; 
      HHXW                : integer                        := 0; 
      direct_delivery     : integer range 0 to 1           := 0; 
      IPRIOLEN            : integer range 1 to 8           := 8; 
      nEIID               : integer range 1 to 2047        := 2047;
    leaf_domains          : std_logic_vector(MAX_DOMAINS-1 downto 0) := (others => '0'); -- Configures the leaf domains
      preset_active_harts : preset_active_harts_type
      );
    port (
      rstn        : in  std_ulogic;
      clk         : in  std_ulogic;
      ahbmi       : in  ahb_mst_in_type;
      ahbmo       : out ahb_mst_out_type;
      ahbsi       : in  ahb_slv_in_type;
      ahbso       : out ahb_slv_out_type;
      meip        : out std_logic_vector(0 to ncpu-1);
      seip        : out std_logic_vector(0 to ncpu-1)
      );
  end component;
end aplic;


package body aplic is
  -- Returns the proper hmask parameter for a slave address range of
  -- "addr_bits" bits. 
  function bits2hmask(addr_bits : integer) return integer is
    variable mask_bits   : integer;
    variable mask : unsigned(11 downto 0);
  begin 
    if addr_bits < 21 then
      return 16#FFF#;
    else
      mask_bits := addr_bits - 20;
    end if;

    for i in 0 to 11 loop
      if i < mask_bits then
        mask(i) := '0';
      else
        mask(i) := '1';
      end if;
    end loop;

    return to_integer(mask);
  end function;

  function calc_upperLimit(addr_bits : integer) return integer is
  begin 
    if addr_bits < 21 then
      return 20;
    else
      return addr_bits;
    end if;
  end function;

  -- Returns true when the domain is a leaf domain
  function is_leaf(domain : integer; doms_per_branch : integer) return boolean is
  begin 
    if domain mod doms_per_branch = 0 and domain /= 0 then
      return true;
    else 
      return false;
    end if;
  end;

  -- Returns true when the domain is child of the root domain (the first of the branch)
  function is_head(domain : integer; doms_per_branch : integer) return boolean is
  begin
    if domain mod doms_per_branch = 1 then
      return true;
    else 
      return false;
    end if;
  end;

  -- Returns the branch to which the domain belongs
  function get_branch(domain : integer; doms_per_branch : integer) return integer is
  begin
    return (domain-1)/doms_per_branch;
  end;

  -- This function set which domains are the leaf domains of the branch
  -- By defect the last fomain of each branch is the leaf branch unless it is
  -- especified different in the generic leaf_doms
  function set_leaf_doms(in_vec          : std_logic_vector;
                         branches        : integer;
                         doms_per_branch : integer) return std_logic_vector is 
    constant ndomains : integer := branches*doms_per_branch+1;
    variable leaf_domains : std_logic_vector(ndomains-1 downto 0) := (others => '0');
    variable branch_leaf_dom_set : boolean;
  begin
    for i in 0 to branches-1 loop
      branch_leaf_dom_set := false;
      for j in 0 to doms_per_branch-1 loop
        if not(branch_leaf_dom_set) then
          if in_vec(1+i*doms_per_branch+j) = '1' then
            leaf_domains(1+i*doms_per_branch+j) := '1';
            branch_leaf_dom_set := true;
          elsif not(branch_leaf_dom_set) and j = doms_per_branch-1 then
            -- If no leaf domain is set in the generic for the branch
            -- the last domain of the branch is set as the leaf domain
            leaf_domains(1+i*doms_per_branch+j) := '1';
          end if;
        end if;
      end loop;
    end loop;

    return leaf_domains;
  end function;

end;