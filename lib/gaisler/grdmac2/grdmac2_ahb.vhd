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
-- Entity:      grdmac2_ahb
-- File:        grdmac2_ahb.vhd
-- Author:      Krishna K R - Cobham Gaisler AB
-- Description: GRDMAC2 top level entity.
------------------------------------------------------------------------------ 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.generic_bm_pkg.all;
library gaisler;
use gaisler.grdmac2_pkg.all;
library techmap;
use techmap.gencomp.all;


-----------------------------------------------------------------------------
-- Top level entity for GRDMAC2.
-- This is a wrapper which integrates GRDMAC2 core to the
-- AHB master - generic bus master bridge
-----------------------------------------------------------------------------

entity grdmac2_ahb is
  generic (
    tech             : integer range 0 to NTECH     := inferred;  -- Target technology
    -- APB configuration  
    pindex           : integer                      := 0;         -- APB configuartion slave index
    paddr            : integer                      := 0;         -- APB configuartion slave address
    pmask            : integer                      := 16#FF8#;   -- APB configuartion slave mask
    pirq             : integer range 0 to NAHBIRQ-1 := 0;         -- APB configuartion slave irq
    -- Bus master configuration
    dbits            : integer range 32 to 128      := 32;        -- Data width of BM and FIFO    
    en_bm1           : integer                      := 0;         -- Enable Bus master interface index1
    hindex0          : integer                      := 0;         -- AHB master index 0
    hindex1          : integer                      := 1;         -- AHB master index 1
    max_burst_length : integer range 2 to 256       := 256;       -- BM backend burst length in words. Total burst of 'Max_size'bytes, is split in to bursts of 'max_burst_length' bytes by the BMIF
    -- Buffer configuration
    ft               : integer range 0 to 5         := 0;         -- enable EDAC on RAMs (GRLIB-FT only, passed on to syncram_2pft)
                                                                  -- Valid values of 'ft' : 0 to 5 for dbits =32 (ft=5 is target technology specific); 0 to 4 for dbits = 64 and 128
    abits            : integer range 0 to 10        := 4;         -- FIFO address bits (actual fifo depth = 2**abits)
    -- M2B/B2M configuration
    en_timer         : integer                      := 0;         -- Enable timeout mechanism
    en_acc           : integer range 0 to 4         := 0
    );
  port (
    rstn    : in  std_ulogic;                    -- Reset
    clk     : in  std_ulogic;                    -- Clock
    -- APB interface signals
    apbi    : in  apb_slv_in_type;               -- APB slave input
    apbo    : out apb_slv_out_type;              -- APB slave output
    -- AHB interface signals
    ahbmi0  : in  ahb_mst_in_type;               -- AHB master 0 input
    ahbmo0  : out ahb_mst_out_type;              -- AHB master 0 output
    ahbmi1  : in  ahb_mst_in_type;               -- AHB master 1 input
    ahbmo1  : out ahb_mst_out_type;              -- AHB master 1 output
    -- System interrupt
    trigger : in  std_logic_vector(63 downto 0)  -- Input trigger

  );
end entity grdmac2_ahb;

------------------------------------------------------------------------------
-- Architecture of grdmac2
------------------------------------------------------------------------------

architecture rtl of grdmac2_ahb is
  -----------------------------------------------------------------------------
  -- Constant declaration
  -----------------------------------------------------------------------------
  attribute sync_set_reset         : string;
  attribute sync_set_reset of rstn : signal is "true";

  -- Reset configuration

  constant ASYNC_RST : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  -- Plug and Play Information (AHB master interface)

  constant hconfig : ahb_config_type := (
    0      => ahb_device_reg (VENDOR_GAISLER, GAISLER_GRDMAC2, 0, REVISION, 0),
    others => zero32);

  -- Bus master interface burst chop mask
  constant burst_chop_mask : integer := (max_burst_length*(log_2(AHBDW)-1));

  -----------------------------------------------------------------------------
  -- Records and types
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Signal declaration
  -----------------------------------------------------------------------------
  signal ahb_bmsti0 : ahb_bmst_in_type;
  signal ahb_bmsto0 : ahb_bmst_out_type;
  signal ahb_bmsti1 : ahb_bmst_in_type;
  signal ahb_bmsto1 : ahb_bmst_out_type;
  signal bm0_in     : bm_in_type;
  signal bm0_out    : bm_out_type;
  signal bm1_in     : bm_in_type;
  signal bm1_out    : bm_out_type;
  signal bm0_endian : std_logic;
  signal bm1_endian : std_logic;
  signal bm0_rd_data : std_logic_vector(dbits-1 downto 0);
  signal bm1_rd_data : std_logic_vector(dbits-1 downto 0);
  signal bm0_wr_data : std_logic_vector(dbits-1 downto 0);
  signal bm1_wr_data : std_logic_vector(dbits-1 downto 0);
  signal bm0_wr_data_temp : std_logic_vector(dbits-1 downto 0);
  signal bm1_wr_data_temp : std_logic_vector(dbits-1 downto 0);
  -----------------------------------------------------------------------------
  -- Function/procedure declaration
  -----------------------------------------------------------------------------
  
begin  -- rtl

  -----------------
  -- Assignments --
  -----------------
  bm1_dis : if en_bm1 = 0 generate
    ahb_bmsti1.hgrant <= '0';
    ahb_bmsti1.hready <= '0';
    ahb_bmsti1.hresp  <= (others => '0');
    ahb_bmsti1.endian <= '0';
    ahbmo1            <= ahbm_none;
    bm1_out           <= BM_OUT_RST;
  end generate;
  ahb_bmsti0.hgrant <= ahbmi0.hgrant(hindex0);
  ahb_bmsti0.hready <= ahbmi0.hready;
  ahb_bmsti0.hresp  <= ahbmi0.hresp;
  ahb_bmsti0.endian <= ahbmi0.endian;

  ahbmo0.hbusreq    <= ahb_bmsto0.hbusreq;
  ahbmo0.hlock      <= ahb_bmsto0.hlock;
  ahbmo0.htrans     <= ahb_bmsto0.htrans;
  ahbmo0.haddr      <= ahb_bmsto0.haddr;
  ahbmo0.hwrite     <= ahb_bmsto0.hwrite;
  ahbmo0.hsize      <= ahb_bmsto0.hsize;
  ahbmo0.hburst     <= ahb_bmsto0.hburst;
  ahbmo0.hprot      <= ahb_bmsto0.hprot;
  ahbmo0.hirq       <= (others => '0');
  ahbmo0.hconfig    <= hconfig;
  ahbmo0.hindex     <= hindex0;
  bm1_en : if en_bm1 = 1 generate
    ahb_bmsti1.hgrant <= ahbmi1.hgrant(hindex1);
    ahb_bmsti1.hready <= ahbmi1.hready;
    ahb_bmsti1.hresp  <= ahbmi1.hresp;
    ahb_bmsti1.endian <= ahbmi1.endian;
  
    ahbmo1.hbusreq <= ahb_bmsto1.hbusreq;
    ahbmo1.hlock   <= ahb_bmsto1.hlock;
    ahbmo1.htrans  <= ahb_bmsto1.htrans;
    ahbmo1.haddr   <= ahb_bmsto1.haddr;
    ahbmo1.hwrite  <= ahb_bmsto1.hwrite;
    ahbmo1.hsize   <= ahb_bmsto1.hsize;
    ahbmo1.hburst  <= ahb_bmsto1.hburst;
    ahbmo1.hprot   <= ahb_bmsto1.hprot;
    ahbmo1.hirq    <= (others => '0');
    ahbmo1.hconfig <= hconfig;
    ahbmo1.hindex  <= hindex1;

    -- LE data manipulation
    bm1_out.rd_data(127 downto 128-dbits) <= bl_wrd_swap(bm1_rd_data,bm1_endian,dbits);
    bm1_wr_data_temp <= bm1_in.wr_data(127 downto 128-dbits);
    bm1_wr_data <= bl_wrd_swap(bm1_wr_data_temp,ahbmi1.endian,dbits);
  end generate;

  -- LE data manipulation
  bm0_out.rd_data(127 downto 128-dbits) <= bl_wrd_swap(bm0_rd_data,bm0_endian,dbits);
  bm0_wr_data_temp <= bm0_in.wr_data(127 downto 128-dbits);
  bm0_wr_data <= bl_wrd_swap(bm0_wr_data_temp,ahbmi0.endian,dbits);

  -----------------------------------------------------------------------------
  -- Component instantiation
  -----------------------------------------------------------------------------

  -- grdmac2 core
  core : grdmac2
    generic map (
      tech     => tech,
      pindex   => pindex,
      paddr    => paddr,
      pmask    => pmask,
      pirq     => pirq,
      dbits    => dbits,
      en_bm1   => en_bm1,
      ft       => ft,
      abits    => abits,
      en_timer => en_timer,
      en_acc   => en_acc
      )
    port map (
      rstn    => rstn,
      clk     => clk,
      apbi    => apbi,
      apbo    => apbo,
      bm0_in  => bm0_in,
      bm1_in  => bm1_in,
      bm0_out => bm0_out,
      bm1_out => bm1_out,
      bm0_endian  => bm0_endian,
      bm1_endian  => bm1_endian,
      trigger => trigger
      );


  -- BM0
  bm0 : generic_bm_ahb
    generic map(
      async_reset      => ASYNC_RST,
      bm_dw            => dbits,
      be_dw            => AHBDW,
      be_rd_pipe       => 0,
      max_size         => 1024,
      max_burst_length => max_burst_length,
      burst_chop_mask  => burst_chop_mask,
      bm_info_print    => 1,
      hindex           => hindex0
      )        
    port map (
      clk              => clk,
      rstn             => rstn,
      ahbmi            => ahb_bmsti0,
      ahbmo            => ahb_bmsto0,
      hrdata           => ahbmi0.hrdata,
      hwdata           => ahbmo0.hwdata,
      bmrd_addr        => bm0_in.rd_addr,
      bmrd_size        => bm0_in.rd_size,
      bmrd_req         => bm0_in.rd_req,
      bmrd_req_granted => bm0_out.rd_req_grant,
      bmrd_data        => bm0_rd_data,
      bmrd_valid       => bm0_out.rd_valid,
      bmrd_done        => bm0_out.rd_done,
      bmrd_error       => bm0_out.rd_err,
      bmwr_addr        => bm0_in.wr_addr,
      bmwr_size        => bm0_in.wr_size,
      bmwr_req         => bm0_in.wr_req,
      bmwr_req_granted => bm0_out.wr_req_grant,
      bmwr_data        => bm0_wr_data,
      bmwr_full        => bm0_out.wr_full,
      bmwr_done        => bm0_out.wr_done,
      bmwr_error       => bm0_out.wr_err,
      endian_out       => bm0_endian,   --0->BE, 1->LE
      excl_en          => '0',
      excl_nowrite     => '0',
      excl_done        => open,
      excl_err         => open
      );

  -- BM1
  bm1_gen : if en_bm1 /= 0 generate
    bm1 : generic_bm_ahb
      generic map (
        async_reset      => ASYNC_RST,
        bm_dw            => dbits,
        be_dw            => AHBDW,
        be_rd_pipe       => 0,
        max_size         => 1024,
        max_burst_length => max_burst_length,
        burst_chop_mask  => burst_chop_mask,
        bm_info_print    => 1,
        hindex           => hindex1
        )          
      port map (
        clk              => clk,
        rstn             => rstn,
        ahbmi            => ahb_bmsti1,
        ahbmo            => ahb_bmsto1,
        hrdata           => ahbmi1.hrdata,
        hwdata           => ahbmo1.hwdata,
        bmrd_addr        => bm1_in.rd_addr,
        bmrd_size        => bm1_in.rd_size,
        bmrd_req         => bm1_in.rd_req,
        bmrd_req_granted => bm1_out.rd_req_grant,
        bmrd_data        => bm1_rd_data,
        bmrd_valid       => bm1_out.rd_valid,
        bmrd_done        => bm1_out.rd_done,
        bmrd_error       => bm1_out.rd_err,
        bmwr_addr        => bm1_in.wr_addr,
        bmwr_size        => bm1_in.wr_size,
        bmwr_req         => bm1_in.wr_req,
        bmwr_req_granted => bm1_out.wr_req_grant,
        bmwr_data        => bm1_wr_data,
        bmwr_full        => bm1_out.wr_full,
        bmwr_done        => bm1_out.wr_done,
        bmwr_error       => bm1_out.wr_err,
        endian_out       => bm1_endian,   --0->BE, 1->LE
        excl_en          => '0',
        excl_nowrite     => '0',
        excl_done        => open,
        excl_err         => open
        );
  end generate;
  
  
-- pragma translate_off
  tb : process
  begin
    wait for 1 ns;
    assert endian_check(bm0_endian,bm1_endian,en_bm1)
      report "grdmac2: Both busmaster interfaces must have same endianness!"
      severity error;
  end process tb;
-- pragma translate_on
  
end architecture rtl;



