------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
-- Entity:      progbuf_ahb
-- File:        progbuf_ahb.vhd
-- Author:      Nils Wessman
-- Description: AHB interface to program buffer
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.zero32;
use grlib.stdlib."+";
use grlib.stdlib."-";
use grlib.stdlib.log2x;

library gaisler;
use gaisler.noelv.all;
use gaisler.dmnvint.all;
use gaisler.l5nv_shared.all;

entity progbuf_ahb is
  generic (
    hindex      : integer range 0 to NAHBSLV-1  := 0;
    haddr       : integer range 0 to 16#FFF#    := 0;
    hmask       : integer range 0 to 16#FFF#    := 16#FFF#;
    progbufsize : integer range 0 to 16         := 8;
    scantest    : integer := 0
    );
  port (
    rstn        : in  std_ulogic;
    clk         : in  std_ulogic;
    ahbi        : in  ahb_slv_in_type;
    ahbo        : out ahb_slv_out_type;
    pbi         : in  dev_reg_in_type;
    pbo         : out dev_reg_out_type
    );
end;

architecture rtl of progbuf_ahb is
  -- Offset
  -- 0x00 - 0x7c reserved
  -- 0x80 - 0xbc program buffer

  constant REVISION : integer := 0;

  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_RVDMEXT, 0, REVISION, 0),
    4 => ahb_membar(haddr, '0', '0', hmask),
    others => zero32);

  type reg_type is record
    -- AHB
    hsel        : std_logic_vector(1 downto 0);
    hready      : std_logic;
    hwrite      : std_logic;
    hsize       : std_logic_vector(2 downto 0);
    haddr       : std_logic_vector(31 downto 0);
    hresp       : std_logic_vector(1 downto 0);
    hwdata      : std_logic_vector(63 downto 0);
    hrdata      : std_logic_vector(63 downto 0);
  end record;

  constant RES_T : reg_type := (
    -- AHB
    hsel        => (others => '0'),
    hready      => '0',
    hwrite      => '0',
    hsize       => (others => '0'),
    haddr       => (others => '0'),
    hresp       => (others => '0'),
    hwdata      => (others => '0'),
    hrdata      => (others => '0')
    );

  -- Add register to improve timing paths. Adds one wait-state on
  -- Read and write accesses.
  constant pipe     : boolean := true;

  signal pbi_int   : nv_progbuf_in_type;
  signal pbo_int   : nv_progbuf_out_type;

  signal r, rin     : reg_type;
  signal arst           : std_ulogic;

  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

begin
  arst        <= ahbi.testrst when (ASYNC_RESET and scantest/=0 and ahbi.testen/='0') else
                 rstn when ASYNC_RESET else '1';

  comb : process (r, ahbi, pbi, pbo_int)
    variable v          : reg_type;
    variable hrdata     : std_logic_vector(63 downto 0);
    variable rdata      : std_logic_vector(63 downto 0);
    variable hwdata     : std_logic_vector(63 downto 0);
    variable wdata      : std_logic_vector(63 downto 0);
    variable offset     : std_logic_vector(6 downto 2);
  begin

    v := r;

    v.hsel    := (others => '0');
    v.hready  := '1';
    v.hresp   := HRESP_OKAY;

    rdata       := (others => '0');

    ---------------------------------------------------
    -- AHB Interface
    ---------------------------------------------------

    hwdata(63 downto 32) := ahbi.hwdata( 63 mod AHBDW downto 32 mod AHBDW);
    hwdata(31 downto  0) := ahbi.hwdata( 31           downto  0);

    -- Slave selected
    if (ahbi.hready and ahbi.hsel(hindex) and ahbi.htrans(1)) = '1' then
      v.hsel(0)  := '1';
      v.haddr    := ahbi.haddr;
      v.hsize    := ahbi.hsize;
      v.hwrite   := ahbi.hwrite;
      -- pipe
      if pipe then
        v.hready   := '0';
      end if;
    end if;

    -- Write data
    if pipe then
      if r.hsel(0) = '1' and r.hwrite = '1' then
        v.hwdata := hwdata;
      end if;
      wdata := r.hwdata;
      v.hsel(1) := r.hsel(0);
    else
      wdata := hwdata;
      v.hwdata := (others => '0');
      v.hsel(1) := v.hsel(0);
    end if;

    offset := r.haddr(offset'range);
    -- Read access
    if r.hsel(0) = '1' and r.haddr(19 downto 8) = x"000" and (r.hsize = "010" or r.hsize = "011") then
      if r.haddr(7) = '0' then
        case offset is
          when "00000" =>
          when "00001" =>
          when others =>
        end case;
      else                      -- program buffer
        rdata := pbo_int.edata; 
        if r.hsize = "010" then
          if r.haddr(2) = '0' then
            rdata(63 downto 32) := rdata(31 downto 0);
          else
            rdata(31 downto 0) := rdata(63 downto 32);
          end if;
        end if;
      end if;
      -- Replicate data for 32-bit access
      if r.hsize = "010" then
        rdata(63 downto 32) := rdata(31 downto 0);
      end if;
      v.hrdata := rdata;
    end if;

    -- Write access
    if r.hsel(1) = '1' and r.haddr(19 downto 8) = x"000" and r.hwrite = '1' and (r.hsize = "010" or r.hsize = "011") then
      if r.haddr(8) = '0' then -- program buffer Read-only
        case offset is
          when "00000" =>
          when "00001" =>
          when others =>
        end case;
      end if;
    end if;

    -- Error response (only support 32,64-bit accesses)
    if pipe then
      if r.hsel(0) = '1' then
        if r.hsize /= "011" and r.hsize /= "010" then
          v.hready := '0';
          v.hresp  := HRESP_ERROR;
        end if;
      end if;
    else
      if v.hsel(0) = '1' then
        if v.hsize /= "011" and v.hsize /= "010" then
          v.hready := '0';
          v.hresp  := HRESP_ERROR;
        end if;
      end if;
    end if;
    -- Second error response cycle
    if r.hready = '0' and r.hresp = HRESP_ERROR then
      v.hresp := HRESP_ERROR;
    end if;

    -- Read data
    if pipe then
      hrdata := r.hrdata;
    else
      hrdata := rdata;
      v.hrdata := (others => '0');
    end if;

    rin <= v;
    
    -- DM Interface
    -- Program read/write
    pbi_int.addr      <= pbi.addr(6 downto 2);
    pbi_int.write     <= pbi.wr and pbi.sel(0);
    pbi_int.data      <= pbi.data;
    pbo.data          <= pbo_int.data;
    pbo.rdy           <= '1';
    -- not used
    pbo.sbstart   <= '0';
    pbo.sbwr      <= '0';
    pbo.sbaddr    <= (others => '0');
    pbo.sbwdata   <= (others => '0');
    pbo.sbaccess  <= (others => '0');
    -- Program execution
    pbi_int.eaddr     <= r.haddr(6 downto 2);
    --
    pbi_int.testen    <= ahbi.testen;
    pbi_int.testrst   <= ahbi.testrst;

    -- AHB Interface
    ahbo                <= ahbs_none;
    ahbo.hready         <= r.hready;
    ahbo.hrdata         <= ahbdrivedata(hrdata);
    ahbo.hresp          <= r.hresp;
    ahbo.hsplit         <= (others => '0');
    ahbo.hirq           <= (others => '0');
    ahbo.hconfig        <= hconfig;
    ahbo.hindex         <= hindex;
  end process;

  syncrregs : if not ASYNC_RESET generate
    regs : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if rstn = '0' then
          r <= RES_T;
        end if;
      end if;
    end process;
  end generate;

  asyncrregs : if ASYNC_RESET generate
    regs : process(clk, arst)
    begin
      if arst = '0' then
        r <= RES_T;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;
  end generate;

  pb0 : progbuf
    generic map (
      size      => progbufsize,
      scantest  => scantest)
    port map (
      clk   => clk,
      rstn  => rstn,
      pbi   => pbi_int,
      pbo   => pbo_int);

end rtl;

