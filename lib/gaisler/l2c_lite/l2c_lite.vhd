------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;

library techmap;
use techmap.gencomp.all;

package l2c_lite is

  constant bm_dw        : integer := 128;
  constant max_linesize : integer := 256;
  constant endianess    : integer := GRLIB_CONFIG_ARRAY(grlib_little_endian);
  constant IO_ADDR_MASK : integer := 16#FFC#;  -- 1 KiB

  -- Generic bus master
  constant async_reset      : boolean := false;
  constant be_rd_pipe       : integer := 1;
  constant unalign_load_opt : integer := 0;
  constant addr_width       : integer := 32;
  constant max_size         : integer := 256;

  constant DIRTY_BIT : integer := 0;
  constant VALID_BIT : integer := 1;
  -- STATE MACHINES -- 
  type state_type is (READ_S, IDLE_S, WRITE_S, R_INCR_S, W_INCR_S, BACKEND_READ_S, DIRECT_READ_S, DIRECT_WRITE_S, FLUSH_S, FLUSH_READ_S, TAG_MATCH_1_S, TAG_MATCH_2_S, DIAG_S);
  type bw_state_type is (BACKEND_WRITE_S, IDLE_S);

  ---- FUNCTION DESCRIPTION:
  --          Checks whether or not data should be cached. Returns "true" if the address is cacheable.
  function is_cachable(constant address : std_logic_vector;
    constant address_mask               : std_logic_vector
  ) return boolean;

  ---- FUNCTION DESCRIPTION:
  --          Reverses data, used for little endian implementations. 
  --          Ex: input - AB 01 03 C0 ; output - 0C 03 01 AB;
  function reversedata(data : std_logic_vector; step : integer
  ) return std_logic_vector;

  ---- FUNCTION DESCRIPTION:
  --          Converts from HSIZE constants to integers.
  function size_vector_to_int (size : std_logic_vector(2 downto 0)) return integer;

  ---- FUNCTION DESCRIPTION:
  --          Generates P&P bar for hconfig.
  function gen_pnp_bar (
    constant addr     : integer;
    constant mask     : integer;
    constant btype    : integer;
    constant cache    : integer;
    constant prefetch : integer
  ) return amba_config_word;

  component l2c_lite_ahb
    generic (
      tech     :    integer := 0;
      hmindex  :    integer := 0;
      hsindex  :    integer := 0;
      ways     :    integer := 2;
      waysize  :    integer := 64;
      linesize :    integer := 32;
      repl     :    integer := 0;
      haddr    :    integer := 16#000#;
      hmask    :    integer := 16#000#;
      ioaddr   :    integer := 16#000#;
      cached   :    integer := 16#FFFF#;
      be_dw    :    integer := 32);
    port (
      rstn     : in std_ulogic;
      clk      : in std_ulogic;

      ---- CACHE FRONTEND ----
      ahbsi : in  ahb_slv_in_type;
      ahbso : out ahb_slv_out_type;

      ---- CACHE BACKEND ----
      ahbmi : in  ahb_mst_in_type;
      ahbmo : out ahb_mst_out_type

    );

  end component;

  component l2c_lite_axi4
    generic (
      tech     :    integer := 0;
      hmindex  :    integer := 0;
      hsindex  :    integer := 0;
      ways     :    integer := 2;
      waysize  :    integer := 64;
      linesize :    integer := 32;
      repl     :    integer := 0;
      haddr    :    integer := 16#000#;
      hmask    :    integer := 16#000#;
      ioaddr   :    integer := 16#000#;
      cached   :    integer := 16#FFFF#;
      be_dw    :    integer := 32);
    port (
      rstn     : in std_ulogic;
      clk      : in std_ulogic;

      ---- CACHE FRONTEND ----
      ahbsi : in  ahb_slv_in_type;
      ahbso : out ahb_slv_out_type;

      ---- CACHE BACKEND ----
      aximi : in  axi_somi_type;
      aximo : out axi4_mosi_type
    );

  end component;

  component l2c_lite_axi3
    generic (
      tech     :    integer := 0;
      hmindex  :    integer := 0;
      hsindex  :    integer := 0;
      ways     :    integer := 2;
      waysize  :    integer := 64;
      linesize :    integer := 32;
      repl     :    integer := 0;
      haddr    :    integer := 16#000#;
      hmask    :    integer := 16#000#;
      ioaddr   :    integer := 16#000#;
      cached   :    integer := 16#FFFF#;
      be_dw    :    integer := 32);
    port (
      rstn     : in std_ulogic;
      clk      : in std_ulogic;

      ---- CACHE FRONTEND ----
      ahbsi : in  ahb_slv_in_type;
      ahbso : out ahb_slv_out_type;

      ---- CACHE BACKEND ----
      aximi : in  axi_somi_type;
      aximo : out axi_mosi_type
    );

  end component;

  component l2c_lite_core
    generic (
      hsindex          :     integer;
      tech             :     integer;
      haddr            :     integer;
      hmask            :     integer;
      ioaddr           :     integer;
      waysize          :     integer;
      linesize         :     integer;
      cached           :     integer;
      repl             :     integer;
      ways             :     integer;
      bm_dw_l          :     integer range 32 to 512 := 128;
      addr_width       :     integer range 32 to 52  := 32);
    port (
      rstn             : in  std_ulogic;
      clk              : in  std_ulogic;
      ahbsi            : in  ahb_slv_in_type;
      ahbso            : out ahb_slv_out_type;
      --Read Channel
      bmrd_addr        : out std_logic_vector(addr_width-1 downto 0);
      bmrd_size        : out std_logic_vector(log2ext(max_size)-1 downto 0);
      bmrd_req         : out std_logic;
      bmrd_req_granted : in std_logic;
      bmrd_data        : in std_logic_vector(bm_dw_l-1 downto 0);
      bmrd_valid       : in std_logic;
      bmrd_done        : in std_logic;
      bmrd_error       : in std_logic;
      --Write Channel
      bmwr_addr        : out std_logic_vector(addr_width-1 downto 0);
      bmwr_size        : out std_logic_vector(log2ext(max_size)-1 downto 0);
      bmwr_req         : out std_logic;
      bmwr_req_granted : in std_logic;
      bmwr_data        : out std_logic_vector(bm_dw_l-1 downto 0);
      bmwr_full        : in std_logic;
      bmwr_done        : in std_logic;
      bmwr_error       : in std_logic );
    end component;

end package;

package body l2c_lite is

  function size_vector_to_int (size : std_logic_vector(2 downto 0)) return integer is
    variable size_int                 : integer range 0 to 128;
  begin
    case size is
      when HSIZE_BYTE   => size_int := 1;
      when HSIZE_HWORD  => size_int := 2;
      when HSIZE_WORD   => size_int := 4;
      when HSIZE_DWORD  => size_int := 8;
      when HSIZE_4WORD  => size_int := 16;
      when HSIZE_8WORD  => size_int := 32;
      when HSIZE_16WORD => size_int := 64;
      when HSIZE_32WORD => size_int := 128;
      when others       => null;
    end case;
    return size_int;
  end size_vector_to_int;

  function is_cachable(constant address : std_logic_vector;
    constant address_mask                 : std_logic_vector) return boolean is
  begin
    if address_mask(to_integer(unsigned(address))) = '1' then
      return true;
    end if;
    return false;
  end is_cachable;

  function reversedata(data : std_logic_vector; step : integer)
    return std_logic_vector is
    variable rdata : std_logic_vector(data'length - 1 downto 0);
  begin
    for i in 0 to (data'length/step - 1) loop
      rdata(i * step + step - 1 downto i * step) := data(data'length - i * step - 1 downto data'length - i * step - step);
    end loop;
    return rdata;
  end function reversedata;

  function gen_pnp_bar (
    constant addr     : integer;
    constant mask     : integer;
    constant btype    : integer;
    constant cache    : integer;
    constant prefetch : integer)
    return amba_config_word is
    variable c, p : std_ulogic;
  begin
    if btype = 1 then
      return ahb_iobar(addr, mask);
    end if;
    if cache /= 0 then
      c := '1';
    else
      c := '0';
    end if;
    if prefetch /= 0 then
      p := '1';
    else
      p := '0';
    end if;
    return ahb_membar(addr, c, p, mask);
  end gen_pnp_bar;

end package body;
