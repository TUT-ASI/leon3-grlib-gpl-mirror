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
-- Package:     amba
-- File:        amba.vhd
-- Author:      Jiri Gaisler, Gaisler Research
-- Modified by: Jan Andersson, Aeroflex Gaisler
-- Description: AMBA 2.0 bus signal definitions + support for plug&play
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- pragma translate_off
use std.textio.all;
-- pragma translate_on
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;

package amba is

-------------------------------------------------------------------------------
-- AMBA configuration
-------------------------------------------------------------------------------

-- AHBDW - AHB data with
--
-- Valid values are 32, 64, 128 and 256
--
-- The value here sets the width of the AMBA AHB and AXI data vectors for all
-- cores in the library.
--
constant AHBDW        : integer := CFG_AHBDW;
constant AXIDW        : integer := CFG_AHBDW;
constant AXI_ID_WIDTH : integer := 4;

-- GRLIB_ENDIAN - Default endianness of the system
-- This value is configured in the GRLIB_CONFIG_ARRAY
--
constant GRLIB_ENDIAN : integer := GRLIB_CONFIG_ARRAY(grlib_little_endian);

-- CORE_ACDM - Enable AMBA Compliant Data Muxing in cores
--
-- Valid values are 0 and 1
--
-- 0: All GRLIB cores that use the ahbread* programs defined in this package
--    will read their data from the low part of the AHB data vector.
--
-- 1: All GRLIB cores that use the ahbread* programs defined in this package
--    will select valid data, as defined in the AMBA AHB standard, from the
--    AHB data vectors based on the address input. If a core uses a function
--    that does not have the address input, a failure will be asserted.
--
constant CORE_ACDM : integer := CFG_AHB_ACDM; 

constant NAHBMST   : integer := 16;  -- maximum AHB masters
constant NAHBSLV   : integer := 16;  -- maximum AHB slaves
constant NAPBSLV   : integer := 16; -- maximum APB slaves
constant NAHBIRQ   : integer := 32 + 32*GRLIB_CONFIG_ARRAY(grlib_amba_inc_nirq); -- maximum interrupts
constant NAHBAMR   : integer := 4;  -- maximum address mapping registers
constant NAHBIR    : integer := 4;  -- maximum AHB identification registers
constant NAHBCFG   : integer := NAHBIR + NAHBAMR;  -- words in AHB config block
constant NAPBIR    : integer := 1;  -- maximum APB configuration words
constant NAPBAMR   : integer := 1;  -- maximum APB configuration words
constant NAPBCFG   : integer := NAPBIR + NAPBAMR;  -- words in APB config block
constant NBUS      : integer := 4;

-- Number of test vector bits
constant NTESTINBITS : integer := 4+GRLIB_CONFIG_ARRAY(grlib_techmap_testin_extra);

-- Default system AHB endianness
constant AHBENDIAN    : integer range 0 to 1 := GRLIB_CONFIG_ARRAY(grlib_little_endian);

-------------------------------------------------------------------------------
-- AMBA interface type declarations and constant
-------------------------------------------------------------------------------

subtype amba_config_word is std_logic_vector(31 downto 0);
type ahb_config_type is array (0 to NAHBCFG-1) of amba_config_word;
type apb_config_type is array (0 to NAPBCFG-1) of amba_config_word;
type ahb_config_array is array(natural range <>) of ahb_config_type;

-- AHB master inputs
  type ahb_mst_in_type is record
    hgrant      : std_logic_vector(0 to NAHBMST-1);     -- bus grant
    hready      : std_ulogic;                           -- transfer done
    hresp       : std_logic_vector(1 downto 0);         -- response type
    hrdata      : std_logic_vector(AHBDW-1 downto 0);   -- read data bus
    hirq        : std_logic_vector(NAHBIRQ-1 downto 0); -- interrupt result bus
    testen      : std_ulogic;                           -- scan test enable
    testrst     : std_ulogic;                           -- scan test reset
    scanen      : std_ulogic;                           -- scan enable
    testoen     : std_ulogic;                           -- test output enable
    testin      : std_logic_vector(NTESTINBITS-1 downto 0);         -- test vector for syncrams
    endian      : std_ulogic;                           -- endianness of bus
  end record;

-- AHB master outputs
  type ahb_mst_out_type is record
    hbusreq     : std_ulogic;                           -- bus request
    hlock       : std_ulogic;                           -- lock request
    htrans      : std_logic_vector(1 downto 0);         -- transfer type
    haddr       : std_logic_vector(31 downto 0);        -- address bus (byte)
    hwrite      : std_ulogic;                           -- read/write
    hsize       : std_logic_vector(2 downto 0);         -- transfer size
    hburst      : std_logic_vector(2 downto 0);         -- burst type
    hprot       : std_logic_vector(3 downto 0);         -- protection control
    hwdata      : std_logic_vector(AHBDW-1 downto 0);   -- write data bus
    hirq        : std_logic_vector(NAHBIRQ-1 downto 0); -- interrupt bus
    hconfig     : ahb_config_type;                      -- memory access reg.
    hindex      : integer range 0 to NAHBMST-1;         -- diagnostic use only
  end record;

-- AHB slave inputs
  type ahb_slv_in_type is record
    hsel        : std_logic_vector(0 to NAHBSLV-1);     -- slave select
    haddr       : std_logic_vector(31 downto 0);        -- address bus (byte)
    hwrite      : std_ulogic;                           -- read/write
    htrans      : std_logic_vector(1 downto 0);         -- transfer type
    hsize       : std_logic_vector(2 downto 0);         -- transfer size
    hburst      : std_logic_vector(2 downto 0);         -- burst type
    hwdata      : std_logic_vector(AHBDW-1 downto 0);   -- write data bus
    hprot       : std_logic_vector(3 downto 0);         -- protection control
    hready      : std_ulogic;                           -- transfer done
    hmaster     : std_logic_vector(3 downto 0);         -- current master
    hmastlock   : std_ulogic;                           -- locked access
    hmbsel      : std_logic_vector(0 to NAHBAMR-1);     -- memory bank select
    hirq        : std_logic_vector(NAHBIRQ-1 downto 0); -- interrupt result bus
    testen      : std_ulogic;                           -- scan test enable
    testrst     : std_ulogic;                           -- scan test reset
    scanen      : std_ulogic;                           -- scan enable
    testoen     : std_ulogic;                           -- test output enable 
    testin      : std_logic_vector(NTESTINBITS-1 downto 0);         -- test vector for syncrams
    endian      : std_ulogic;                           -- endianness of bus
  end record;

-- AHB slave outputs
  type ahb_slv_out_type is record
    hready      : std_ulogic;                           -- transfer done
    hresp       : std_logic_vector(1 downto 0);         -- response type
    hrdata      : std_logic_vector(AHBDW-1 downto 0);   -- read data bus
    hsplit      : std_logic_vector(NAHBMST-1 downto 0); -- split completion
    hirq        : std_logic_vector(NAHBIRQ-1 downto 0); -- interrupt bus
    hconfig     : ahb_config_type;                      -- memory access reg.
    hindex      : integer range 0 to NAHBSLV-1;         -- diagnostic use only
  end record;

-- array types
  type ahb_mst_out_vector_type is array (natural range <>) of ahb_mst_out_type;
  type ahb_mst_in_vector_type is array (natural range <>) of ahb_mst_in_type;
  type ahb_slv_out_vector_type is array (natural range <>) of ahb_slv_out_type;
  type ahb_slv_in_vector_type is array (natural range <>) of ahb_slv_in_type;
  subtype ahb_mst_out_vector is ahb_mst_out_vector_type(NAHBMST-1 downto 0);
  subtype ahb_slv_out_vector is ahb_slv_out_vector_type(NAHBSLV-1 downto 0);
  subtype ahb_mst_in_vector is ahb_mst_in_vector_type(NAHBMST-1 downto 0);
  subtype ahb_slv_in_vector is ahb_slv_in_vector_type(NAHBSLV-1 downto 0);
  type ahb_mst_out_bus_vector is array (0 to NBUS-1) of ahb_mst_out_vector;
  type ahb_slv_out_bus_vector is array (0 to NBUS-1) of ahb_slv_out_vector;

  type amba_stat_type is record
    idle   : std_ulogic;                    -- HTRANS_IDLE
    busy   : std_ulogic;                    -- HTRANS_BUSY
    nseq   : std_ulogic;                    -- HTRANS_NONSEQ
    seq    : std_ulogic;                    -- HTRANS_SEQ 
    read   : std_ulogic;                    -- Read access
    write  : std_ulogic;                    -- Write access
    hsize  : std_logic_vector(5 downto 0);  -- 8WORD downto BYTE
    ws     : std_ulogic;                    -- Wait state
--    req    : std_ulogic;                    -- Req without gnt
    retry  : std_ulogic;                    -- RETRY response
    split  : std_ulogic;                    -- SPLIT response
    spdel  : std_ulogic;                    -- Wait after SPLIT
    locked : std_ulogic;                    -- Locked access
    hmaster: std_logic_vector(3 downto 0);  -- master
  end record;

-- constants
  constant HTRANS_IDLE:   std_logic_vector(1 downto 0) := "00";
  constant HTRANS_BUSY:   std_logic_vector(1 downto 0) := "01";
  constant HTRANS_NONSEQ: std_logic_vector(1 downto 0) := "10";
  constant HTRANS_SEQ:    std_logic_vector(1 downto 0) := "11";

  constant HBURST_SINGLE: std_logic_vector(2 downto 0) := "000";
  constant HBURST_INCR:   std_logic_vector(2 downto 0) := "001";
  constant HBURST_WRAP4:  std_logic_vector(2 downto 0) := "010";
  constant HBURST_INCR4:  std_logic_vector(2 downto 0) := "011";
  constant HBURST_WRAP8:  std_logic_vector(2 downto 0) := "100";
  constant HBURST_INCR8:  std_logic_vector(2 downto 0) := "101";
  constant HBURST_WRAP16: std_logic_vector(2 downto 0) := "110";
  constant HBURST_INCR16: std_logic_vector(2 downto 0) := "111";

  constant HSIZE_BYTE:    std_logic_vector(2 downto 0) := "000";
  constant HSIZE_HWORD:   std_logic_vector(2 downto 0) := "001";
  constant HSIZE_WORD:    std_logic_vector(2 downto 0) := "010";
  constant HSIZE_DWORD:   std_logic_vector(2 downto 0) := "011";
  constant HSIZE_4WORD:   std_logic_vector(2 downto 0) := "100";
  constant HSIZE_8WORD:   std_logic_vector(2 downto 0) := "101";
  constant HSIZE_16WORD:  std_logic_vector(2 downto 0) := "110";
  constant HSIZE_32WORD:  std_logic_vector(2 downto 0) := "111";

  constant HRESP_OKAY:    std_logic_vector(1 downto 0) := "00";
  constant HRESP_ERROR:   std_logic_vector(1 downto 0) := "01";
  constant HRESP_RETRY:   std_logic_vector(1 downto 0) := "10";
  constant HRESP_SPLIT:   std_logic_vector(1 downto 0) := "11";

-- APB slave inputs
  type apb_slv_in_type is record
    psel        : std_logic_vector(0 to NAPBSLV-1);     -- slave select
    penable     : std_ulogic;                           -- strobe
    paddr       : std_logic_vector(31 downto 0);        -- address bus (byte)
    pwrite      : std_ulogic;                           -- write
    pwdata      : std_logic_vector(31 downto 0);        -- write data bus
    pirq        : std_logic_vector(NAHBIRQ-1 downto 0); -- interrupt result bus
    testen      : std_ulogic;                           -- scan test enable
    testrst     : std_ulogic;                           -- scan test reset
    scanen      : std_ulogic;                           -- scan enable
    testoen     : std_ulogic;                           -- test output enable
    testin      : std_logic_vector(NTESTINBITS-1 downto 0);         -- test vector for syncrams
  end record;

  type apb3_slv_in_type is record
    psel        : std_logic_vector(0 to NAPBSLV-1);     -- slave select
    penable     : std_ulogic;                           -- strobe
    paddr       : std_logic_vector(31 downto 0);        -- address bus (byte)
    pwrite      : std_ulogic;                           -- write
    pwdata      : std_logic_vector(31 downto 0);        -- write data bus
    pirq        : std_logic_vector(NAHBIRQ-1 downto 0); -- interrupt result bus
    testen      : std_ulogic;                           -- scan test enable
    testrst     : std_ulogic;                           -- scan test reset
    scanen      : std_ulogic;                           -- scan enable
    testoen     : std_ulogic;                           -- test output enable
    testin      : std_logic_vector(NTESTINBITS-1 downto 0);         -- test vector for syncrams
  end record;

-- APB slave outputs
  type apb_slv_out_type is record
    prdata      : std_logic_vector(31 downto 0);        -- read data bus
    pirq        : std_logic_vector(NAHBIRQ-1 downto 0); -- interrupt bus
    pconfig     : apb_config_type;                      -- memory access reg.
    pindex      : integer range 0 to NAPBSLV -1;        -- diag use only
  end record;

  type apb3_slv_out_type is record
    prdata      : std_logic_vector(31 downto 0);        -- read data bus
    pready      : std_logic;                            -- ready
    pslverr     : std_logic;                            -- transfer failure
    pirq        : std_logic_vector(NAHBIRQ-1 downto 0); -- interrupt bus
    pconfig     : apb_config_type;                      -- memory access reg.
    pindex      : integer range 0 to NAPBSLV -1;        -- diag use only
  end record;

-- array types
  type apb_slv_in_vector_type is array (natural range <>) of apb_slv_in_type;
  subtype apb_slv_in_vector is apb_slv_in_vector_type(0 to NAPBSLV-1);
  type apb_slv_out_vector_type is array (natural range <>) of apb_slv_out_type;
  subtype apb_slv_out_vector is apb_slv_out_vector_type(0 to NAPBSLV-1);
  type apb_slv_out_bus_vector is array (natural range <>) of apb_slv_out_vector;
  type apb3_slv_out_vector_type is array (natural range <>) of apb3_slv_out_type;
  subtype apb3_slv_out_vector is apb3_slv_out_vector_type(0 to NAPBSLV-1);

-- AXI Write Address channel signals
  type axi_aw_mosi_type is record -- Master Output Slave Input
    id     : std_logic_vector (AXI_ID_WIDTH-1 downto 0);  -- awid
    addr   : std_logic_vector (31 downto 0);              -- awaddr
    len    : std_logic_vector (3 downto 0);               -- awlen
    size   : std_logic_vector (2 downto 0);               -- awsize
    burst  : std_logic_vector (1 downto 0);               -- awburst
    lock   : std_logic_vector (1 downto 0);               -- awlock
    cache  : std_logic_vector (3 downto 0);               -- awcache
    prot   : std_logic_vector (2 downto 0);               -- awprot
    valid  : std_logic;                                   -- awvalid
--  awqos    : std_logic_vector (3 downto 0);
  end record;
  type axi_aw_somi_type is record -- Slave Output Master Input
    ready  : std_logic;                                 -- awready
  end record;

-- AXI Write Data channel signals
  type axi_w_mosi_type is record -- Master Output Slave Input
    id      : std_logic_vector (AXI_ID_WIDTH-1 downto 0);  -- wid
    data    : std_logic_vector (AXIDW-1 downto 0);         -- wdata
    strb    : std_logic_vector (AXIDW/8-1 downto 0);       -- wstrb
    last    : std_logic;                                   -- wlast
    valid   : std_logic;                                   -- wvalid
  end record;
  type axi_w_somi_type is record -- Slave Output Master Input
    ready   : std_logic;                                -- wready
  end record;

-- AXI Write Response channel signals
  type axi_b_mosi_type is record -- Master Output Slave Input
    ready   : std_logic;                                -- bready
  end record;
  type axi_b_somi_type is record -- Slave Output Master Input
    id      : std_logic_vector (AXI_ID_WIDTH-1 downto 0); -- bid
    resp    : std_logic_vector (1 downto 0);              -- bresp
    valid   : std_logic;                                  -- bvalid
  end record;

-- AXI Read Address channel signals
  type axi_ar_mosi_type is record -- Master Output Slave Input
    id     : std_logic_vector (AXI_ID_WIDTH-1 downto 0);  -- arid
    addr   : std_logic_vector (31 downto 0);            -- araddr
    len    : std_logic_vector (3 downto 0);             -- arlen
    size   : std_logic_vector (2 downto 0);             -- arsize
    burst  : std_logic_vector (1 downto 0);             -- arburst
    lock   : std_logic_vector (1 downto 0);             -- arlock
    cache  : std_logic_vector (3 downto 0);             -- arcache
    prot   : std_logic_vector (2 downto 0);             -- arprot
    valid  : std_logic;                                 -- arvalid
--  arqos    : std_logic_vector (3 downto 0);
  end record;
  type axi_ar_somi_type is record -- Slave Output Master Input
    ready  : std_logic;                                 -- arready
  end record;

-- AXI Read Data channel signals
  type axi_r_mosi_type is record -- Master Output Slave Input
    ready   : std_logic;                                -- rready
  end record;
  type axi_r_somi_type is record -- Slave Output Master Input
    id      : std_logic_vector (AXI_ID_WIDTH-1 downto 0); -- rid
    data    : std_logic_vector (AXIDW-1 downto 0);        -- rdata
    resp    : std_logic_vector (1 downto 0);              -- rresp
    last    : std_logic;                                  -- rlast
    valid   : std_logic;                                  -- rvalid
  end record;

-- AXI interfaces
  type axi_mosi_type is record -- Master Output Slave Input
    aw  : axi_aw_mosi_type;
    w   : axi_w_mosi_type;
    b   : axi_b_mosi_type;
    ar  : axi_ar_mosi_type;
    r   : axi_r_mosi_type;
  end record;
  type axi_somi_type is record -- Slave Output Master Input
    aw  : axi_aw_somi_type;
    w   : axi_w_somi_type;
    b   : axi_b_somi_type;
    ar  : axi_ar_somi_type;
    r   : axi_r_somi_type;
  end record;

-- AXI Write Address channel signals (Combined AXI3/4)
  type axix_aw_mosi_type is record -- Master Output Slave Input
    id     : std_logic_vector (AXI_ID_WIDTH-1 downto 0);  -- awid
    addr   : std_logic_vector (31 downto 0);              -- awaddr
    len    : std_logic_vector (7 downto 0);               -- awlen
    size   : std_logic_vector (2 downto 0);               -- awsize
    burst  : std_logic_vector (1 downto 0);               -- awburst
    lock   : std_logic_vector (1 downto 0);               -- awlock
    cache  : std_logic_vector (3 downto 0);               -- awcache
    prot   : std_logic_vector (2 downto 0);               -- awprot
    valid  : std_logic;                                   -- awvalid
    qos    : std_logic_vector (3 downto 0);  
  end record;

-- AXI Write Address channel signals (Dedicated AXI3)
  type axi3_aw_mosi_type is record -- Master Output Slave Input
    id     : std_logic_vector (AXI_ID_WIDTH-1 downto 0);  -- awid
    addr   : std_logic_vector (31 downto 0);              -- awaddr
    len    : std_logic_vector (3 downto 0);               -- awlen
    size   : std_logic_vector (2 downto 0);               -- awsize
    burst  : std_logic_vector (1 downto 0);               -- awburst
    lock   : std_logic_vector (1 downto 0);               -- awlock
    cache  : std_logic_vector (3 downto 0);               -- awcache
    prot   : std_logic_vector (2 downto 0);               -- awprot
    valid  : std_logic;                                   -- awvalid
  end record;

-- AXI Write Address channel signals (Dedicated AXI4)
  type axi4_aw_mosi_type is record -- Master Output Slave Input
    id     : std_logic_vector (AXI_ID_WIDTH-1 downto 0); -- awid
    addr   : std_logic_vector (31 downto 0);             -- awaddr
    len    : std_logic_vector (7 downto 0);              -- awlen
    size   : std_logic_vector (2 downto 0);              -- awsize
    burst  : std_logic_vector (1 downto 0);              -- awburst
    lock   : std_logic;                                  -- awlock
    cache  : std_logic_vector (3 downto 0);              -- awcache
    prot   : std_logic_vector (2 downto 0);              -- awprot
    valid  : std_logic;                                  -- awvalid
    qos    : std_logic_vector (3 downto 0);              -- awqos
  end record;

-- AXI Write Data channel signals (Dedicated AXI4)
  type axi4_w_mosi_type is record -- Master Output Slave Input
    data    : std_logic_vector (AXIDW-1 downto 0);      -- wdata
    strb    : std_logic_vector (AXIDW/8-1 downto 0);    -- wstrb
    last    : std_logic;                                -- wlast
    valid   : std_logic;                                -- wvalid
  end record;

-- AXI Read Address channel signals  (Combined AXI3/4)
  type axix_ar_mosi_type is record -- Master Output Slave Input
    id     : std_logic_vector (AXI_ID_WIDTH-1 downto 0); -- arid
    addr   : std_logic_vector (31 downto 0);             -- araddr
    len    : std_logic_vector (7 downto 0);              -- arlen
    size   : std_logic_vector (2 downto 0);              -- arsize
    burst  : std_logic_vector (1 downto 0);              -- arburst
    lock   : std_logic_vector (1 downto 0);              -- arlock
    cache  : std_logic_vector (3 downto 0);              -- arcache
    prot   : std_logic_vector (2 downto 0);              -- arprot
    valid  : std_logic;                                  -- arvalid
    qos    : std_logic_vector (3 downto 0);              -- arqos 
  end record;

-- AXI Read Address channel signals  (Dedicated AXI3)
  type axi3_ar_mosi_type is record -- Master Output Slave Input
    id     : std_logic_vector (AXI_ID_WIDTH-1 downto 0);  -- arid
    addr   : std_logic_vector (31 downto 0);              -- araddr
    len    : std_logic_vector (3 downto 0);               -- arlen
    size   : std_logic_vector (2 downto 0);               -- arsize
    burst  : std_logic_vector (1 downto 0);               -- arburst
    lock   : std_logic_vector (1 downto 0);               -- arlock
    cache  : std_logic_vector (3 downto 0);               -- arcache
    prot   : std_logic_vector (2 downto 0);               -- arprot
    valid  : std_logic;                                   -- arvalid
  end record;

-- AXI Read Address channel signals  (Dedicated AXI4)
  type axi4_ar_mosi_type is record -- Master Output Slave Input
    id     : std_logic_vector (AXI_ID_WIDTH-1 downto 0); -- arid
    addr   : std_logic_vector (31 downto 0);             -- araddr
    len    : std_logic_vector (7 downto 0);              -- arlen
    size   : std_logic_vector (2 downto 0);              -- arsize
    burst  : std_logic_vector (1 downto 0);              -- arburst
    lock   : std_logic;                                  -- arlock
    cache  : std_logic_vector (3 downto 0);              -- arcache
    prot   : std_logic_vector (2 downto 0);              -- arprot
    valid  : std_logic;                                  -- arvalid
    qos    : std_logic_vector (3 downto 0);              -- arqos 
  end record;

-- AXI interfaces (Combined AXI3/4)
  type axix_mosi_type is record -- Master Output Slave Input
    aw  : axix_aw_mosi_type;
    w   : axi_w_mosi_type;
    b   : axi_b_mosi_type;
    ar  : axix_ar_mosi_type;
    r   : axi_r_mosi_type;
  end record;

  type axi_mosi_vec is array(0 to 5) of axix_mosi_type;

-- AXI interfaces (Dedicated AXI3)
  type axi3_mosi_type is record -- Master Output Slave Input
    aw  : axi3_aw_mosi_type;
    w   : axi_w_mosi_type;
    b   : axi_b_mosi_type;
    ar  : axi3_ar_mosi_type;
    r   : axi_r_mosi_type;
  end record;

-- AXI interfaces (Dedicated AXI4)
  type axi4_mosi_type is record -- Master Output Slave Input
    aw  : axi4_aw_mosi_type;
    w   : axi4_w_mosi_type;
    b   : axi_b_mosi_type;
    ar  : axi4_ar_mosi_type;
    r   : axi_r_mosi_type;
  end record;

-- array types
  type axi_mosi_vector_type is array (natural range <>) of axi_mosi_type;
  type axi_somi_vector_type is array (natural range <>) of axi_somi_type;
  type axix_mosi_vector_type is array (natural range <>) of axix_mosi_type;
  type axi3_mosi_vector_type is array (natural range <>) of axi3_mosi_type;
  type axi4_mosi_vector_type is array (natural range <>) of axi4_mosi_type;

-- AXI constants
  constant XBURST_FIXED:          std_logic_vector(1 downto 0) := "00";
  constant XBURST_INCR:           std_logic_vector(1 downto 0) := "01";
  constant XBURST_WRAP:           std_logic_vector(1 downto 0) := "10";

  constant XCACHE_BUFFERABLE:     std_logic_vector(3 downto 0) := "0001";
  constant XCACHE_CACHEABLE:      std_logic_vector(3 downto 0) := "0010";
  constant XCACHE_READ_ALLOC:     std_logic_vector(3 downto 0) := "0100";
  constant XCACHE_WRITE_ALLOC:    std_logic_vector(3 downto 0) := "1000";

  constant XPROT_PRIV:            std_logic_vector(2 downto 0) := "001";
  constant XPROT_NONSEC:          std_logic_vector(2 downto 0) := "010";
  constant XPROT_INSTR:           std_logic_vector(2 downto 0) := "100";

  constant XRESP_OKAY:            std_logic_vector(1 downto 0) := "00";
  constant XRESP_EXOKAY:          std_logic_vector(1 downto 0) := "01";
  constant XRESP_SLVERR:          std_logic_vector(1 downto 0) := "10";
  constant XRESP_DECERR:          std_logic_vector(1 downto 0) := "11";

-- support for plug&play configuration

  constant AMBA_CONFIG_VER0  : std_logic_vector(1 downto 0) := "00";

  subtype amba_vendor_type  is integer range 0 to  16#ff#;
  subtype amba_device_type  is integer range 0 to 16#3ff#;
  subtype amba_version_type is integer range 0 to  16#3f#;
  subtype amba_cfgver_type  is integer range 0 to      3;
  subtype amba_irq_type     is integer range 0 to NAHBIRQ-1;
  subtype ahb_addr_type     is integer range 0 to 16#fff#;
  constant zx : std_logic_vector(31 downto 0) := (others => '0');
  constant zahbdw : std_logic_vector(AHBDW-1 downto 0) := (others => '0');
  constant zxirq : std_logic_vector(NAHBIRQ-1 downto 0) := (others => '0');
  constant zy : std_logic_vector(0 to 31) := (others => '0');
  constant ztestin : std_logic_vector(NTESTINBITS-1 downto 0) := (others => '0');

  constant apb_none : apb_slv_out_type :=
    (zx, zxirq(NAHBIRQ-1 downto 0), (others => zx), 0);
  constant apb3_none : apb3_slv_out_type :=
    (zx, '1', '0', zxirq(NAHBIRQ-1 downto 0), (others => zx), 0);
  constant ahbm_none : ahb_mst_out_type := ( '0', '0', "00", zx,
   '0', "000", "000", "0000", zahbdw, zxirq(NAHBIRQ-1 downto 0), (others => zx), 0);
  constant ahbm_in_none : ahb_mst_in_type := ((others => '0'), '0', (others => '0'),
   zahbdw, zxirq(NAHBIRQ-1 downto 0), '0', '0', '0', '0', ztestin, '0');
  constant ahbs_none : ahb_slv_out_type := (
   '1', "00", zahbdw, zx(NAHBMST-1 downto 0), zxirq(NAHBIRQ-1 downto 0), (others => zx), 0);
  constant ahbs_in_none : ahb_slv_in_type := (
   zy(0 to NAHBSLV-1), zx, '0', "00", "000", "000", zahbdw,
   "0000", '1', "0000", '0', zy(0 to NAHBAMR-1), zxirq(NAHBIRQ-1 downto 0),
   '0', '0', '0', '0', ztestin, '0');

  constant ahbsv_none : ahb_slv_out_vector := (others => ahbs_none);

  constant apb_slv_in_none : apb_slv_in_type := ((others => '0'), '0', (others => '0'),
                                                 '0', (others => '0'), zxirq(NAHBIRQ-1 downto 0),
                                                 '0', '0', '0', '0', ztestin);
  constant amba_stat_none : amba_stat_type :=
    ('0', '0', '0', '0', '0', '0', (others => '0'),
     '0', '0', '0', '0', '0', (others => '0'));

-------------------------------------------------------------------------------
-- Subprograms
-------------------------------------------------------------------------------

  function ahb_device_reg(vendor : amba_vendor_type; device : amba_device_type;
        cfgver : amba_cfgver_type; version : amba_version_type;
        interrupt : amba_irq_type)
  return std_logic_vector;

  function ahb_membar(memaddr : ahb_addr_type; prefetch, cache : std_ulogic;
        addrmask : ahb_addr_type)
  return std_logic_vector;

  function ahb_membar_opt(memaddr : ahb_addr_type; prefetch, cache : std_ulogic;
        addrmask : ahb_addr_type; enable : integer)
  return std_logic_vector;

  function ahb_iobar(memaddr : ahb_addr_type; addrmask : ahb_addr_type)
  return std_logic_vector;

  function apb_iobar(memaddr : ahb_addr_type; addrmask : ahb_addr_type)
  return std_logic_vector;

  function ahb_slv_dec_cache(haddr : std_logic_vector(31 downto 0);
                             ahbso : ahb_slv_out_vector; cached : integer)
  return std_ulogic;

  function dec_cache_fixed( haddr : std_logic_vector(31 downto 0); cached : integer)
  return std_ulogic;

  function dec_wbmask_fixed( haddr : std_logic_vector(31 downto 2); wbmask : integer)
  return std_ulogic;

  function ahb_slv_dec_pfetch(haddr : std_logic_vector(31 downto 0);
                             ahbso : ahb_slv_out_vector)
  return std_ulogic;

  function ahb_membar_size (addrmask : ahb_addr_type) return integer;

  function ahb_iobar_size (addrmask : ahb_addr_type) return integer;

  function apb_membar_size (addrmask : ahb_addr_type) return integer;

  function ahbdrivedata (hdata : std_logic_vector) return std_logic_vector;

  function ahbselectdatabe (hdata : std_logic_vector(AHBDW-1 downto 0);
                          haddr : std_logic_vector(4 downto 2); hsize : std_logic_vector(2 downto 0))
    return std_logic_vector;

  function ahbselectdatale (hdata : std_logic_vector(AHBDW-1 downto 0);
                          haddr : std_logic_vector(4 downto 2); hsize : std_logic_vector(2 downto 0))
    return std_logic_vector;

  function ahbselectdata (hdata : std_logic_vector(AHBDW-1 downto 0);
                          haddr : std_logic_vector(4 downto 2); hsize : std_logic_vector(2 downto 0);
                          endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector;

  function ahbreadword (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector;

  procedure ahbreadword (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    haddr : in  std_logic_vector(4 downto 2);
    data  : out std_logic_vector(31 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN);

  function ahbreadword (
    hdata : std_logic_vector(AHBDW-1 downto 0))
    return std_logic_vector;

  procedure ahbreadword (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    data  : out std_logic_vector(31 downto 0));

  function ahbreaddword (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector;

  procedure ahbreaddword (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    haddr : in  std_logic_vector(4 downto 2);
    data  : out std_logic_vector(63 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN);

  function ahbreaddword (
    hdata : std_logic_vector(AHBDW-1 downto 0))
    return std_logic_vector;

  procedure ahbreaddword (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    data  : out std_logic_vector(63 downto 0));

  function ahbread4word (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector;

  procedure ahbread4word (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    haddr : in  std_logic_vector(4 downto 2);
    data  : out std_logic_vector(127 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN);

  function ahbread4word (
    hdata : std_logic_vector(AHBDW-1 downto 0))
    return std_logic_vector;

  procedure ahbread4word (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    data  : out std_logic_vector(127 downto 0));

  function ahbread8word (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector;

  procedure ahbread8word (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    haddr : in  std_logic_vector(4 downto 2);
    data  : out std_logic_vector(255 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN);

  function ahbread8word (
    hdata : std_logic_vector(AHBDW-1 downto 0))
    return std_logic_vector;

  procedure ahbread8word (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    data  : out std_logic_vector(255 downto 0));

  function ahbreaddata (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    hsize : std_logic_vector(2 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector;

  function ahbreaddata (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    hsize : std_logic_vector(2 downto 0))
    return std_logic_vector;

  procedure ahbmomux (
    signal ai  : in  ahb_mst_out_type;
    signal ao  : out ahb_mst_out_type;
    signal en  : in  std_ulogic);

  procedure ahbsomux (
    signal ai  : in  ahb_slv_out_type;
    signal ao  : out ahb_slv_out_type;
    signal en  : in  std_ulogic);

  procedure apbsomux (
    signal ai  : in  apb_slv_out_type;
    signal ao  : out apb_slv_out_type;
    signal en  : in  std_ulogic);

  function apb32i(i: apb3_slv_in_type) return apb_slv_in_type;
  function apb23o(o: apb_slv_out_type) return apb3_slv_out_type;
  function apb23ov(o: apb_slv_out_vector) return apb3_slv_out_vector;

-------------------------------------------------------------------------------
-- Components
-------------------------------------------------------------------------------

  component ahbctrl
  generic (
    defmast : integer := 0;             -- default master
    split   : integer := 0;             -- split support
    rrobin  : integer := 0;             -- round-robin arbitration
    timeout : integer range 0 to 255 := 0;  -- HREADY timeout
    ioaddr  : ahb_addr_type := 16#fff#;  -- I/O area MSB address
    iomask  : ahb_addr_type := 16#fff#;  -- I/O area address mask
    cfgaddr : ahb_addr_type := 16#ff0#;  -- config area MSB address
    cfgmask : ahb_addr_type := 16#ff0#;  -- config area address mask
    nahbm   : integer range 1 to NAHBMST := NAHBMST; -- number of masters
    nahbs   : integer range 1 to NAHBSLV := NAHBSLV; -- number of slaves
    ioen    : integer range 0 to 15 := 1; -- enable I/O area
    disirq  : integer range 0 to 1 := 0;  -- disable interrupt routing
    fixbrst : integer range 0 to 1 := 0;  -- support fix-length bursts
    debug   : integer range 0 to 2 := 2;  -- print config to console
    fpnpen  : integer range 0 to 1 := 0;  -- full PnP configuration decoding
    icheck  : integer range 0 to 1 := 1;
    devid   : integer := 0;               -- unique device ID
    enbusmon    : integer range 0 to 1 := 0; --enable bus monitor
    assertwarn  : integer range 0 to 1 := 0; --enable assertions for warnings 
    asserterr   : integer range 0 to 1 := 0; --enable assertions for errors
    hmstdisable : integer := 0; --disable master checks           
    hslvdisable : integer := 0; --disable slave checks
    arbdisable  : integer := 0; --disable arbiter checks
    mprio       : integer := 0; --master with highest priority
    mcheck      : integer range 0 to 2 := 1;  --check memory map for intersects
    ccheck      : integer range 0 to 1 := 1;  --perform sanity checks on pnp config
    acdm        : integer := 0;  --AMBA compliant data muxing (for hsize > word)
    index       : integer := 0;  --index for trace print-out
    ahbtrace    : integer := 0;  --AHB trace enable
    hwdebug     : integer := 0;
    fourgslv    : integer := 0;
    shadow      : integer range 0 to 1 := 0;  -- Allow overlapping memory areas
    unmapslv    : integer := 0;
    ahbendian   : integer := GRLIB_ENDIAN
-- pragma translate_off
    ;
    dbgtag      : string := "" -- Prefix for AHB trace printout
-- pragma translate_on
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    msti    : out ahb_mst_in_type;
    msto    : in  ahb_mst_out_vector;
    slvi    : out ahb_slv_in_type;
    slvo    : in  ahb_slv_out_vector;
    endian  : in  std_ulogic := '0';
    testen  : in  std_ulogic := '0';
    testrst : in  std_ulogic := '1';
    scanen  : in  std_ulogic := '0';
    testoen : in  std_ulogic := '1';
    testsig : in  std_logic_vector(1+GRLIB_CONFIG_ARRAY(grlib_techmap_testin_extra) downto 0) := (others => '0')
  );
  end component;

component ahbxb is
        generic(
    defmast     : integer                     := 0; -- default master
    timeout     : integer range 0 to 255      := 0; -- HREADY timeout
    ioaddr      : ahb_addr_type               := 16#fff#; -- I/O area MSB address
    iomask      : ahb_addr_type               := 16#fff#; -- I/O area address mask
    cfgaddr     : ahb_addr_type               := 16#ff0#; -- config area MSB address
    cfgmask     : ahb_addr_type               := 16#ff0#; -- config area address mask
    nahbm       : integer range 1 to NAHBMST  := NAHBMST; -- number of masters
    nahbs       : integer range 1 to NAHBSLV  := NAHBSLV; -- number of slaves
    ioen        : integer range 0 to 15       := 1; -- enable I/O area
    disirq      : integer range 0 to 1        := 0; -- disable interrupt routing
    fixbrst     : integer range 0 to 1        := 0; -- support fix-length bursts
    debug       : integer range 0 to 2        := 2; -- report cores to console
    fpnpen      : integer range 0 to 1        := 0; -- full PnP configuration decoding
    icheck      : integer range 0 to 1        := 1;
    devid       : integer                     := 0; -- unique device ID
    enbusmon    : integer range 0 to 1        := 0; --enable bus monitor
    assertwarn  : integer range 0 to 1        := 0; --enable assertions for warnings 
    asserterr   : integer range 0 to 1        := 0; --enable assertions for errors
    hmstdisable : integer                     := 0; --disable master checks           
    hslvdisable : integer                     := 0; --disable slave checks
    arbdisable  : integer                     := 0; --disable arbiter checks
    mprio       : integer                     := 0; --master with highest priority
    mcheck      : integer range 0 to 2        := 1; --check memory map for intersects
    ccheck      : integer range 0 to 1        := 1; --perform sanity checks on pnp config
    index       : integer                     := 0; --Index for trace print-out
    ahbtrace    : integer                     := 0; --AHB trace enable
    hwdebug     : integer                     := 0; --Hardware debug
    fourgslv    : integer                     := 0; --1=Single slave with single 4 GB bar
    l2en        : integer                     := 0; --enable l2 cache multiport decoding
    l2bhindex   : integer range 0 to NAHBSLV  := 0; --base index for the l2 cache slaves
    l2num       : integer                     := 4; --number of l2 caches in system
    l2linesize  : integer                     := 32;--number of bytes in an l2 cache line
    l2hmbsel    : integer                     := 0  --index of L2 memory back
        );
        port(
                rst     : in  std_ulogic;
                clk     : in  std_ulogic;
                msti    : out ahb_mst_in_vector;
                msto    : in  ahb_mst_out_vector;
                slvi    : out ahb_slv_in_vector;
                slvo    : in  ahb_slv_out_vector;
                testen  : in  std_ulogic := '0';
                testrst : in  std_ulogic := '1';
                scanen  : in  std_ulogic := '0';
                testoen : in  std_ulogic := '1';
    testsig : in  std_logic_vector(1+GRLIB_CONFIG_ARRAY(grlib_techmap_testin_extra) downto 0) := (others => '0')
        );
        end component;

  component ambaprot
  generic (
    pindex    : integer := 0;
    paddr     : integer := 0;
    pmask     : integer := 16#fff#;
    maskwidth : integer := 16;
    segments  : integer := 8;
    mstrules  : integer := 0;
    sgm       : integer := 0 -- Enable hardcoded SGM function. Requires Master Rules.
  );
  port (
    rst       : in  std_ulogic;
    clk       : in  std_ulogic;
    ahbsi     : in  ahb_slv_in_type;
    apbi      : in  apb_slv_in_type;
    apbo      : out apb_slv_out_type;
    wpo       : out std_ulogic;
    pmwprt1   : in  std_ulogic; -- PM Write Protect SGM Area 1 on AMBAPROT Segment 0
    pmwprt2   : in  std_ulogic; -- PM Write Protect SGM Area 2 on AMBAPROT Segment 1
    pmwprt3   : in  std_ulogic; -- PM Write Protect SGM Area 1 on AMBAPROT Segment 0
    pmwprt4   : in  std_ulogic; -- PM Write Protect SGM Area 2 on AMBAPROT Segment 1
    gndwprt1  : in  std_ulogic; -- Ground Write Protect SGM Area 1
    gndwprt2  : in  std_ulogic;  -- Ground Write Protect SGM Area 2
    isredundant : in  std_ulogic -- Set if redundant unit
  );
  end component;

  component apbctrl
  generic (
    hindex      : integer := 0;
    haddr       : integer := 0;
    hmask       : integer := 16#fff#;
    nslaves     : integer range 1 to NAPBSLV := NAPBSLV;
    debug       : integer range 0 to 2 := 2;   -- print config to console
    icheck      : integer range 0 to 1 := 1;
    enbusmon    : integer range 0 to 1 := 0;
    asserterr   : integer range 0 to 1 := 0;
    assertwarn  : integer range 0 to 1 := 0;
    pslvdisable : integer := 0;
    mcheck      : integer range 0 to 1 := 1;
    ccheck      : integer range 0 to 1 := 1
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbi    : in  ahb_slv_in_type;
    ahbo    : out ahb_slv_out_type;
    apbi    : out apb_slv_in_type;
    apbo    : in  apb_slv_out_vector
  );
  end component;

  component apbctrl_piped
  generic (
    hindex      : integer := 0;
    haddr       : integer := 0;
    hmask       : integer := 16#fff#;
    nslaves     : integer range 1 to NAPBSLV := NAPBSLV;
    debug       : integer range 0 to 2 := 2;   -- print config to console
    icheck      : integer range 0 to 1 := 1;
    enbusmon    : integer range 0 to 1 := 0;
    asserterr   : integer range 0 to 1 := 0;
    assertwarn  : integer range 0 to 1 := 0;
    pslvdisable : integer := 0;
    mcheck      : integer range 0 to 1 := 1;
    ccheck      : integer range 0 to 1 := 1
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbi    : in  ahb_slv_in_type;
    ahbo    : out ahb_slv_out_type;
    apbi    : out apb_slv_in_vector_type(0 to nslaves-1);
    apbo    : in  apb_slv_out_vector
  );
  end component;

  component apbctrlx
  generic (
    hindex0     : integer := 0;
    haddr0      : integer := 0;
    hmask0      : integer := 16#fff#;
    hindex1     : integer := 0;
    haddr1      : integer := 0;
    hmask1      : integer := 16#fff#;
    hindex2     : integer := 0;
    haddr2      : integer := 0;
    hmask2      : integer := 16#fff#;
    hindex3     : integer := 0;
    haddr3      : integer := 0;
    hmask3      : integer := 16#fff#;
    nslaves     : integer range 1 to NAPBSLV := NAPBSLV;
    nports      : integer range 1 to 4 := 2;
    wprot       : integer range 0 to 2 := 0;
    debug       : integer range 0 to 2 := 2;   -- print config to console
    icheck      : integer range 0 to 1 := 1;
    enbusmon    : integer range 0 to 1 := 0;
    asserterr   : integer range 0 to 1 := 0;
    assertwarn  : integer range 0 to 1 := 0;
    pslvdisable : integer := 0;
    mcheck      : integer range 0 to 1 := 1;
    ccheck      : integer range 0 to 1 := 1
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbi    : in  ahb_slv_in_vector_type(0 to nports-1);
    ahbo    : out ahb_slv_out_vector_type(0 to nports-1);
    apbi    : out apb_slv_in_vector;
    apbo    : in  apb_slv_out_vector;
    wp      : in  std_logic_vector(0 to nports-1) := (others => '0');
    wpv     : in  std_logic_vector((256*nports)-1 downto 0) := (others => '0')
  );
  end component;

  component apbctrldp
  generic (
    hindex0     : integer := 0;
    haddr0      : integer := 0;
    hmask0      : integer := 16#fff#;
    hindex1     : integer := 0;
    haddr1      : integer := 0;
    hmask1      : integer := 16#fff#;
    nslaves     : integer range 1 to NAPBSLV := NAPBSLV;
    wprot       : integer range 0 to 2 := 0;
    debug       : integer range 0 to 2 := 2;   -- print config to console
    icheck      : integer range 0 to 1 := 1;
    enbusmon    : integer range 0 to 1 := 0;
    asserterr   : integer range 0 to 1 := 0;
    assertwarn  : integer range 0 to 1 := 0;
    pslvdisable : integer := 0;
    mcheck      : integer range 0 to 1 := 1;
    ccheck      : integer range 0 to 1 := 1
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahb0i   : in  ahb_slv_in_type;
    ahb0o   : out ahb_slv_out_type;
    ahb1i   : in  ahb_slv_in_type;
    ahb1o   : out ahb_slv_out_type;
    apbi    : out apb_slv_in_vector;
    apbo    : in  apb_slv_out_vector;
    wp      : in  std_logic_vector(0 to 1) := (others => '0');
    wpv     : in  std_logic_vector((256*2)-1 downto 0) := (others => '0')
  );
  end component;

  component apbctrlsp
  generic (
    hindex      : integer := 0;
    haddr       : integer := 0;
    hmask       : integer := 16#fff#;
    nslaves     : integer range 1 to NAPBSLV := NAPBSLV;
    debug       : integer range 0 to 2 := 2;   -- print config to console
    wprot       : integer range 0 to 2 := 0;
    icheck      : integer range 0 to 1 := 1;
    enbusmon    : integer range 0 to 1 := 0;
    asserterr   : integer range 0 to 1 := 0;
    assertwarn  : integer range 0 to 1 := 0;
    pslvdisable : integer := 0;
    mcheck      : integer range 0 to 1 := 1;
    ccheck      : integer range 0 to 1 := 1
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbi    : in  ahb_slv_in_type;
    ahbo    : out ahb_slv_out_type;
    apbi    : out apb_slv_in_type;
    apbo    : in  apb_slv_out_vector;
    wp      : in  std_logic := '0';
    wpv     : in  std_logic_vector((256*1)-1 downto 0) := (others => '0')
  );
  end component;

  component apbctrl3p
  generic (
    hindex0     : integer := 0;
    haddr0      : integer := 0;
    hmask0      : integer := 16#fff#;
    hindex1     : integer := 0;
    haddr1      : integer := 0;
    hmask1      : integer := 16#fff#;
    nslaves     : integer range 1 to NAPBSLV := NAPBSLV;
    wprot       : integer range 0 to 2 := 0;
    debug       : integer range 0 to 2 := 2;   -- print config to console
    icheck      : integer range 0 to 1 := 1;
    enbusmon    : integer range 0 to 1 := 0;
    asserterr   : integer range 0 to 1 := 0;
    assertwarn  : integer range 0 to 1 := 0;
    pslvdisable : integer := 0;
    mcheck      : integer range 0 to 1 := 1;
    ccheck      : integer range 0 to 1 := 1
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahb0i   : in  ahb_slv_in_type;
    ahb0o   : out ahb_slv_out_type;
    ahb1i   : in  ahb_slv_in_type;
    ahb1o   : out ahb_slv_out_type;
    ahb2i   : in  ahb_slv_in_type;
    ahb2o   : out ahb_slv_out_type;
    apbi    : out apb_slv_in_vector;
    apbo    : in  apb_slv_out_vector;
    wp      : in  std_logic_vector(0 to 2) := (others => '0');
    wpv     : in  std_logic_vector((256*3)-1 downto 0) := (others => '0')
  );
  end component;

  component apbctrl4p
    generic (
      hindex0     : integer := 0;
      haddr0      : integer := 0;
      hmask0      : integer := 16#fff#;
      hindex1     : integer := 0;
      haddr1      : integer := 0;
      hmask1      : integer := 16#fff#;
      hindex2     : integer := 0;
      haddr2      : integer := 0;
      hmask2      : integer := 16#fff#;
      hindex3     : integer := 0;
      haddr3      : integer := 0;
      hmask3      : integer := 16#fff#;
      nslaves     : integer range 1 to NAPBSLV := NAPBSLV;
      wprot       : integer range 0 to 2 := 0;
      debug       : integer range 0 to 2 := 2;
      icheck      : integer range 0 to 1 := 1;
      enbusmon    : integer range 0 to 1 := 0;
      asserterr   : integer range 0 to 1 := 0;
      assertwarn  : integer range 0 to 1 := 0;
      pslvdisable : integer := 0;
      mcheck      : integer range 0 to 1 := 1;
      ccheck      : integer range 0 to 1 := 1
      );
    port (
      rst     : in  std_ulogic;
      clk     : in  std_ulogic;
      ahb0i   : in  ahb_slv_in_type;
      ahb0o   : out ahb_slv_out_type;
      ahb1i   : in  ahb_slv_in_type;
      ahb1o   : out ahb_slv_out_type;
      ahb2i   : in  ahb_slv_in_type;
      ahb2o   : out ahb_slv_out_type;
      ahb3i   : in  ahb_slv_in_type;
      ahb3o   : out ahb_slv_out_type;
      apbi    : out apb_slv_in_vector;
      apbo    : in  apb_slv_out_vector;
      wp      : in  std_logic_vector(0 to 3) := (others => '0');
      wpv     : in  std_logic_vector((256*4)-1 downto 0) := (others => '0')
    );
  end component;
  
  component apb3ctrl
  generic (
    hindex      : integer := 0;
    haddr       : integer := 0;
    hmask       : integer := 16#fff#;
    nslaves     : integer range 1 to NAPBSLV := NAPBSLV;
    debug       : integer range 0 to 2 := 2;
    icheck      : integer range 0 to 1 := 1;
    enbusmon    : integer range 0 to 1 := 0;
    asserterr   : integer range 0 to 1 := 0;
    assertwarn  : integer range 0 to 1 := 0;
    pslvdisable : integer := 0;
    mcheck      : integer range 0 to 1 := 1;
    ccheck      : integer range 0 to 1 := 1;
    hidepnp     : integer range 0 to 1 := 0
    );
  port (
    rst      : in  std_ulogic;
    clk      : in  std_ulogic;
    ahbi     : in  ahb_slv_in_type;
    ahbo     : out ahb_slv_out_type;
    apb3i    : out apb3_slv_in_type;
    apb3o    : in  apb3_slv_out_vector
  );
  end component;

  component ahbctrl_mb
  generic (
    defmast     : integer := 0;         -- default master
    split       : integer := 0;         -- split support
    rrobin      : integer := 0;         -- round-robin arbitration
    timeout     : integer range 0 to 255 := 0;  -- HREADY timeout
    ioaddr      : ahb_addr_type := 16#fff#;  -- I/O area MSB address
    iomask      : ahb_addr_type := 16#fff#;  -- I/O area address mask
    cfgaddr     : ahb_addr_type := 16#ff0#;  -- config area MSB address
    cfgmask     : ahb_addr_type := 16#ff0#;   -- config area address mask
    nahbm       : integer range 1 to NAHBMST := NAHBMST; -- number of masters
    nahbs       : integer range 1 to NAHBSLV := NAHBSLV; -- number of slaves
    ioen        : integer range 0 to 15 := 1;   -- enable I/O area
    disirq      : integer range 0 to 1 := 0;   -- disable interrupt routing
    fixbrst     : integer range 0 to 1 := 0;   -- support fix-length bursts
    debug       : integer range 0 to 2 := 2;   -- report cores to console
    fpnpen      : integer range 0 to 1 := 0;   -- full PnP configuration decoding
    busndx      : integer range 0 to 3 := 0;
    icheck      : integer range 0 to 1 := 1;    
    devid       : integer := 0;            -- unique device ID
    enbusmon    : integer range 0 to 1 := 0; --enable bus monitor
    assertwarn  : integer range 0 to 1 := 0; --enable assertions for warnings 
    asserterr   : integer range 0 to 1 := 0; --enable assertions for errors
    hmstdisable : integer := 0; --disable master checks           
    hslvdisable : integer := 0; --disable slave checks
    arbdisable  : integer := 0; --disable arbiter checks
    mprio       : integer := 0; --master with highest priority
    mcheck      : integer range 0 to 2 := 1;  --check memory map for intersect
    ccheck      : integer range 0 to 1 := 1;  --perform sanity checks on pnp config
    acdm        : integer := 0  --AMBA compliant data muxing (for hsize > word)
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    msti    : out ahb_mst_in_type;
    msto    : in  ahb_mst_out_bus_vector;
    slvi    : out ahb_slv_in_type;
    slvo    : in  ahb_slv_out_bus_vector;
    testen  : in  std_ulogic := '0';
    testrst : in  std_ulogic := '1';
    scanen  : in  std_ulogic := '0';
    testoen : in  std_ulogic := '1'
    );
  end component;
  
  component ahbdefmst
    generic ( hindex : integer range 0 to NAHBMST-1 := 0);
    port ( ahbmo  : out ahb_mst_out_type);
  end component;

  component ahblitm2ahbm 
    generic(
      hindex    : integer := 0;
      venid     : integer := 16#01#;    --VENDOR_GAISLER
      devid     : integer := 16#0A9#;--GAISLER_AHBLM2AHB;
      version   : integer := 0);
  port(
      clk          : in  std_logic;
      rstn         : in  std_logic;
      ahbmi        : in  ahb_mst_in_type;
      ahbmo        : out ahb_mst_out_type;
      --ahblite ports
      ahbmo_htrans : in  std_logic_vector(1 downto 0);
      ahbmo_haddr  : in  std_logic_vector(31 downto 0);
      ahbmo_hwrite : in  std_logic;
      ahbmo_hsize  : in  std_logic_vector(2 downto 0);
      ahbmo_hwdata : in  std_logic_vector(AHBDW-1 downto 0);
      ahbmo_hburst : in  std_logic_vector(2 downto 0); 
      ahbmo_hprot  : in  std_logic_vector(3 downto 0);
      ahbmi_hready : out std_logic;
      ahbmi_hresp  : out std_logic;
      ahbmi_hrdata : out std_logic_vector(AHBDW-1 downto 0)
    );
  end component;


  type ahb_dma_in_type is record
    address         : std_logic_vector(31 downto 0);
    wdata           : std_logic_vector(AHBDW-1 downto 0);
    start           : std_ulogic;
    burst           : std_ulogic;
    write           : std_ulogic;
    busy            : std_ulogic;
    irq             : std_ulogic;
    size            : std_logic_vector(2 downto 0);
  end record;

  type ahb_dma_out_type is record
    start           : std_ulogic;
    active          : std_ulogic;
    ready           : std_ulogic;
    retry           : std_ulogic;
    mexc            : std_ulogic;
    haddr           : std_logic_vector(9 downto 0);
    rdata           : std_logic_vector(AHBDW-1 downto 0);
  end record;

  component ahbmst
  generic (
    hindex  : integer := 0;
    hirq    : integer := 0;
    venid   : integer := 1;
    devid   : integer := 0;
    version : integer := 0;
    chprot  : integer := 3;
    incaddr : integer := 0);
   port (
      rst  : in  std_ulogic;
      clk  : in  std_ulogic;
      dmai : in ahb_dma_in_type;
      dmao : out ahb_dma_out_type;
      ahbi : in  ahb_mst_in_type;
      ahbo : out ahb_mst_out_type
      );
  end component;

-- pragma translate_off

  component ahbmon is
  generic(
    asserterr   : integer range 0 to 1 := 1;
    assertwarn  : integer range 0 to 1 := 1;
    hmstdisable : integer := 0;
    hslvdisable : integer := 0;
    arbdisable  : integer := 0;
    nahbm       : integer range 0 to NAHBMST := NAHBMST;
    nahbs       : integer range 0 to NAHBSLV := NAHBSLV;
    ebterm      : integer range 0 to 1 := 0
  );
  port(
    rst         : in std_ulogic;
    clk         : in std_ulogic;
    ahbmi       : in ahb_mst_in_type;
    ahbmo       : in ahb_mst_out_vector;
    ahbsi       : in ahb_slv_in_type;
    ahbso       : in ahb_slv_out_vector;
    err         : out std_ulogic);
  end component;

  component apbmon is
  generic(
    asserterr   : integer range 0 to 1 := 1;
    assertwarn  : integer range 0 to 1 := 1;
    pslvdisable : integer := 0;
    napb        : integer range 0 to NAPBSLV := NAPBSLV
  );
  port(
    rst         : in std_ulogic;
    clk         : in std_ulogic;
    apbi        : in apb_slv_in_type;
    apbo        : in apb_slv_out_vector;
    err         : out std_ulogic);
  end component;

  component apb3mon is
  generic(
    asserterr   : integer range 0 to 1 := 1;
    assertwarn  : integer range 0 to 1 := 1;
    pslvdisable : integer := 0;
    napb        : integer range 0 to NAPBSLV := NAPBSLV
  );
  port(
    rst         : in std_ulogic;
    clk         : in std_ulogic;
    apb3i       : in apb3_slv_in_type;
    apb3o       : in apb3_slv_out_vector;
    err         : out std_ulogic);
  end component;
  
  component ambamon is
    generic(
      asserterr   : integer range 0 to 1 := 1;
      assertwarn  : integer range 0 to 1 := 1;
      hmstdisable : integer := 0;
      hslvdisable : integer := 0;
      pslvdisable : integer := 0;
      arbdisable  : integer := 0;
      nahbm       : integer range 0 to NAHBMST := NAHBMST;
      nahbs       : integer range 0 to NAHBSLV := NAHBSLV;
      napb        : integer range 0 to NAPBSLV := NAPBSLV;
      ebterm      : integer range 0 to 1 := 0
    );
    port(
      rst        : in std_ulogic;
      clk        : in std_ulogic;
      ahbmi      : in ahb_mst_in_type;
      ahbmo      : in ahb_mst_out_vector;
      ahbsi      : in ahb_slv_in_type;
      ahbso      : in ahb_slv_out_vector;
      apbi       : in apb_slv_in_type;
      apbo       : in apb_slv_out_vector;
      err        : out std_ulogic);
  end component;
  
  subtype vendor_description is string(1 to 24);
  subtype device_description is string(1 to 32);
  type device_table_type is array (0 to 1023) of device_description;
  type vendor_library_type is record
    vendorid     : amba_vendor_type;
    vendordesc   : vendor_description;
    device_table : device_table_type;
  end record;
  type device_array is array (0 to 255) of vendor_library_type;

-- pragma translate_on

end;

package body amba is

  function ahb_device_reg(vendor : amba_vendor_type; device : amba_device_type;
        cfgver : amba_cfgver_type; version : amba_version_type;
        interrupt : amba_irq_type)
  return std_logic_vector is
  variable cfg : std_logic_vector(31 downto 0);
  variable int : std_logic_vector(6 downto 0);
  begin
    int := std_logic_vector(to_unsigned(interrupt, 7));
    case cfgver is
    when 0 =>
      cfg(31 downto 24) := std_logic_vector(to_unsigned(vendor, 8));
      cfg(23 downto 12) := std_logic_vector(to_unsigned(device, 12));
      cfg(11 downto 10) := int(6 downto 5);
      cfg( 9 downto  5) := std_logic_vector(to_unsigned(version, 5));
      cfg( 4 downto  0) := int(4 downto 0);
    when others => cfg := (others => '0');
    end case;
    return(cfg);
  end;

  function ahb_membar(memaddr : ahb_addr_type; prefetch, cache : std_ulogic;
        addrmask : ahb_addr_type)
  return std_logic_vector is
  variable cfg : std_logic_vector(31 downto 0);
  begin
    cfg(31 downto 20) := std_logic_vector(to_unsigned(memaddr, 12));
    cfg(19 downto 16) := "00" & prefetch & cache;
    cfg(15 downto  4) := std_logic_vector(to_unsigned(addrmask, 12));
    cfg( 3 downto  0) := "0010";
    return(cfg);
  end;

  function ahb_membar_opt(memaddr : ahb_addr_type; prefetch, cache : std_ulogic;
        addrmask : ahb_addr_type; enable : integer)
  return std_logic_vector is
  variable cfg : std_logic_vector(31 downto 0);
  begin
    cfg := (others => '0');
    if enable /= 0 then
      return (ahb_membar(memaddr, prefetch, cache, addrmask));
    else return(cfg); end if;
  end;

  function ahb_iobar(memaddr : ahb_addr_type; addrmask : ahb_addr_type)
  return std_logic_vector is
  variable cfg : std_logic_vector(31 downto 0);
  begin
    cfg(31 downto 20) := std_logic_vector(to_unsigned(memaddr, 12));
    cfg(19 downto 16) := "0000";
    cfg(15 downto  4) := std_logic_vector(to_unsigned(addrmask, 12));
    cfg( 3 downto  0) := "0011";
    return(cfg);
  end;

  function apb_iobar(memaddr : ahb_addr_type; addrmask : ahb_addr_type)
  return std_logic_vector is
  variable cfg : std_logic_vector(31 downto 0);
  begin
    cfg(31 downto 20) := std_logic_vector(to_unsigned(memaddr, 12));
    cfg(19 downto 16) := "0000";
    cfg(15 downto  4) := std_logic_vector(to_unsigned(addrmask, 12));
    cfg( 3 downto  0) := "0001";
    return(cfg);
  end;

  function ahb_slv_dec_cache(haddr : std_logic_vector(31 downto 0);
                             ahbso : ahb_slv_out_vector; cached : integer)
  return std_ulogic is
    variable hcache : std_ulogic;
    variable ctbl : std_logic_vector(15 downto 0);
  begin
    hcache := '0'; ctbl := (others => '0');
    if cached = 0 then
      for i in 0 to NAHBSLV-1 loop
        for j in NAHBAMR to NAHBCFG-1 loop
          if (ahbso(i).hconfig(j)(16) = '1') and 
                (ahbso(i).hconfig(j)(15 downto 4) /= "000000000000")
          then
            if (haddr(31 downto 20) and ahbso(i).hconfig(j)(15 downto 4)) =
              (ahbso(i).hconfig(j)(31 downto 20) and ahbso(i).hconfig(j)(15 downto 4)) then
              hcache := '1';
            end if;
          end if;
        end loop;
      end loop;
    else
      ctbl := conv_std_logic_vector(cached, 16);
      hcache := ctbl(conv_integer(haddr(31 downto 28)));
    end if;
    return(hcache);
  end;

  function dec_cache_fixed( haddr : std_logic_vector(31 downto 0); cached : integer) return std_ulogic is
    variable ctbl : std_logic_vector(15 downto 0);
  begin
    ctbl := conv_std_logic_vector(cached, 16);
    if (cached /= 0) then return ctbl(conv_integer(haddr(31 downto 28)));
    else return('1'); end if;
  end;

  function dec_wbmask_fixed( haddr : std_logic_vector(31 downto 2); wbmask : integer) return std_ulogic is
    variable wtbl : std_logic_vector(15 downto 0);
  begin
    wtbl := conv_std_logic_vector(wbmask, 16);
    return wtbl(conv_integer(haddr(31 downto 28)));
  end;

  function ahb_slv_dec_pfetch(haddr : std_logic_vector(31 downto 0);
                             ahbso : ahb_slv_out_vector)
  return std_ulogic is
    variable pfetch : std_ulogic;
  begin
    pfetch := '0';
    for i in 0 to NAHBSLV-1 loop
      for j in NAHBAMR to NAHBCFG-1 loop
        if ((ahbso(i).hconfig(j)(17) = '1') and
            (ahbso(i).hconfig(j)(15 downto 4) /= "000000000000"))
        then
          if (haddr(31 downto 20) and ahbso(i).hconfig(j)(15 downto 4)) =
            (ahbso(i).hconfig(j)(31 downto 20) and ahbso(i).hconfig(j)(15 downto 4)) then
            pfetch := '1';
          end if;
        end if;
      end loop;
    end loop;
    return(pfetch);
  end;

  function ahb_membar_size (addrmask : ahb_addr_type) return integer is
  begin
    if addrmask = 0 then return 0; end if;
    return (4096 - addrmask) * 1024 * 1024;
  end;

  function ahb_iobar_size (addrmask : ahb_addr_type) return integer is
  begin
    return (4096 - addrmask) * 256;
  end;

  function apb_membar_size (addrmask : ahb_addr_type) return integer is
  begin
    return ahb_iobar_size(addrmask);
  end;
  
  -- purpose: Duplicates 'hdata' to suite AHB data width. If the input vector's
  -- length exceeds AHBDW the low part is returned. 
  function ahbdrivedata (
    hdata : std_logic_vector)
    return std_logic_vector is
    variable data : std_logic_vector(AHBDW-1 downto 0);
  begin  -- ahbdrivedata
    if AHBDW < hdata'length then
      data := hdata(AHBDW+hdata'low-1 downto hdata'low);
    else
      for i in 0 to AHBDW/hdata'length-1 loop
        data(hdata'length-1+hdata'length*i downto  hdata'length*i) := hdata; 
      end loop;
    end if;
    return data;
  end ahbdrivedata;

  -- Takes in AHB data vector 'hdata' and returns valid data on the full
  -- data vector output based on 'haddr' and 'hsize' inputs together with
  -- GRLIB AHB bus width. The function works down to word granularity.
  -- Big-endian version

  function ahbselectdatabe (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    hsize : std_logic_vector(2 downto 0))
    return std_logic_vector is
    variable ret   : std_logic_vector(AHBDW-1 downto 0);
  begin  -- ahbselectdatabe
    ret := hdata;
    case hsize is
    when HSIZE_8WORD =>
      if AHBDW = 256 then ret := hdata; end if;
    when HSIZE_4WORD =>
      if AHBDW = 256 then
        if haddr(4) = '0' then ret := ahbdrivedata(hdata(AHBDW-1 downto AHBDW/2));
        else ret := ahbdrivedata(hdata(AHBDW/2-1 downto 0)); end if;
      end if;
    when HSIZE_DWORD =>
      if AHBDW = 256 then
        case haddr(4 downto 3) is
          when "00" =>   ret := ahbdrivedata(hdata(4*(AHBDW/4)-1 downto 3*(AHBDW/4)));
          when "01" =>   ret := ahbdrivedata(hdata(3*(AHBDW/4)-1 downto 2*(AHBDW/4)));
          when "10" =>   ret := ahbdrivedata(hdata(2*(AHBDW/4)-1 downto 1*(AHBDW/4)));
          when others => ret := ahbdrivedata(hdata(1*(AHBDW/4)-1 downto 0*(AHBDW/4)));
        end case;
      elsif AHBDW = 128 then
        if haddr(3) = '0' then ret := ahbdrivedata(hdata(AHBDW-1 downto AHBDW/2));
        else ret := ahbdrivedata(hdata(AHBDW/2-1 downto 0)); end if;
      end if;
    when others =>
      if AHBDW = 256 then
        case haddr(4 downto 2) is
          when "000" => ret  := ahbdrivedata(hdata(8*(AHBDW/8)-1 downto 7*(AHBDW/8)));
          when "001" => ret  := ahbdrivedata(hdata(7*(AHBDW/8)-1 downto 6*(AHBDW/8)));
          when "010" => ret  := ahbdrivedata(hdata(6*(AHBDW/8)-1 downto 5*(AHBDW/8)));
          when "011" => ret  := ahbdrivedata(hdata(5*(AHBDW/8)-1 downto 4*(AHBDW/8)));
          when "100" => ret  := ahbdrivedata(hdata(4*(AHBDW/8)-1 downto 3*(AHBDW/8)));
          when "101" => ret  := ahbdrivedata(hdata(3*(AHBDW/8)-1 downto 2*(AHBDW/8)));
          when "110" => ret  := ahbdrivedata(hdata(2*(AHBDW/8)-1 downto 1*(AHBDW/8)));
          when others => ret := ahbdrivedata(hdata(1*(AHBDW/8)-1 downto 0*(AHBDW/8)));
        end case;
      elsif AHBDW = 128 then
        case haddr(3 downto 2) is
          when "00" =>   ret := ahbdrivedata(hdata(4*(AHBDW/4)-1 downto 3*(AHBDW/4)));
          when "01" =>   ret := ahbdrivedata(hdata(3*(AHBDW/4)-1 downto 2*(AHBDW/4)));
          when "10" =>   ret := ahbdrivedata(hdata(2*(AHBDW/4)-1 downto 1*(AHBDW/4)));
          when others => ret := ahbdrivedata(hdata(1*(AHBDW/4)-1 downto 0*(AHBDW/4)));
        end case;
      elsif AHBDW = 64 then
        if haddr(2) = '0' then ret := ahbdrivedata(hdata(AHBDW-1 downto AHBDW/2));
        else ret := ahbdrivedata(hdata(AHBDW/2-1 downto 0)); end if;
      end if;
    end case;
    return ret;
  end ahbselectdatabe;

  -- Takes in AHB data vector 'hdata' and returns valid data on the full
  -- data vector output based on 'haddr' and 'hsize' inputs together with
  -- GRLIB AHB bus width. The function works down to word granularity.
  -- Little-endian version

  function ahbselectdatale (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    hsize : std_logic_vector(2 downto 0))
    return std_logic_vector is
    variable ret   : std_logic_vector(AHBDW-1 downto 0);
  begin  -- ahbselectdatale
    ret := hdata;
    case hsize is
    when HSIZE_8WORD =>
      if AHBDW = 256 then ret := hdata; end if;
    when HSIZE_4WORD =>
      if AHBDW = 256 then
        if haddr(4) = '1' then ret := ahbdrivedata(hdata(AHBDW-1 downto AHBDW/2));
        else ret := ahbdrivedata(hdata(AHBDW/2-1 downto 0)); end if;
      end if;
    when HSIZE_DWORD =>
      if AHBDW = 256 then
        case haddr(4 downto 3) is
          when "11" =>   ret := ahbdrivedata(hdata(4*(AHBDW/4)-1 downto 3*(AHBDW/4)));
          when "10" =>   ret := ahbdrivedata(hdata(3*(AHBDW/4)-1 downto 2*(AHBDW/4)));
          when "01" =>   ret := ahbdrivedata(hdata(2*(AHBDW/4)-1 downto 1*(AHBDW/4)));
          when others => ret := ahbdrivedata(hdata(1*(AHBDW/4)-1 downto 0*(AHBDW/4)));
        end case;
      elsif AHBDW = 128 then
        if haddr(3) = '1' then ret := ahbdrivedata(hdata(AHBDW-1 downto AHBDW/2));
        else ret := ahbdrivedata(hdata(AHBDW/2-1 downto 0)); end if;
      end if;
    when others =>
      if AHBDW = 256 then
        case haddr(4 downto 2) is
          when "111" => ret  := ahbdrivedata(hdata(8*(AHBDW/8)-1 downto 7*(AHBDW/8)));
          when "110" => ret  := ahbdrivedata(hdata(7*(AHBDW/8)-1 downto 6*(AHBDW/8)));
          when "101" => ret  := ahbdrivedata(hdata(6*(AHBDW/8)-1 downto 5*(AHBDW/8)));
          when "100" => ret  := ahbdrivedata(hdata(5*(AHBDW/8)-1 downto 4*(AHBDW/8)));
          when "011" => ret  := ahbdrivedata(hdata(4*(AHBDW/8)-1 downto 3*(AHBDW/8)));
          when "010" => ret  := ahbdrivedata(hdata(3*(AHBDW/8)-1 downto 2*(AHBDW/8)));
          when "001" => ret  := ahbdrivedata(hdata(2*(AHBDW/8)-1 downto 1*(AHBDW/8)));
          when others => ret := ahbdrivedata(hdata(1*(AHBDW/8)-1 downto 0*(AHBDW/8)));
        end case;
      elsif AHBDW = 128 then
        case haddr(3 downto 2) is
          when "11" =>   ret := ahbdrivedata(hdata(4*(AHBDW/4)-1 downto 3*(AHBDW/4)));
          when "10" =>   ret := ahbdrivedata(hdata(3*(AHBDW/4)-1 downto 2*(AHBDW/4)));
          when "01" =>   ret := ahbdrivedata(hdata(2*(AHBDW/4)-1 downto 1*(AHBDW/4)));
          when others => ret := ahbdrivedata(hdata(1*(AHBDW/4)-1 downto 0*(AHBDW/4)));
        end case;
      elsif AHBDW = 64 then
        if haddr(2) = '1' then ret := ahbdrivedata(hdata(AHBDW-1 downto AHBDW/2));
        else ret := ahbdrivedata(hdata(AHBDW/2-1 downto 0)); end if;
      end if;
    end case;
    return ret;
  end ahbselectdatale;

  -- Takes in AHB data vector 'hdata' and returns valid data on the full
  -- data vector output based on 'haddr' and 'hsize' inputs together with
  -- GRLIB AHB bus width. The function works down to word granularity.
  -- Generic version, select BE or LE

  function ahbselectdata (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    hsize : std_logic_vector(2 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector is
    variable ret   : std_logic_vector(AHBDW-1 downto 0);
  begin  -- ahbselectdata
    if endian /= 0 then
      return ahbselectdatale(hdata,haddr,hsize);
    else
      return ahbselectdatabe(hdata,haddr,hsize);
    end if;
  end ahbselectdata;

  -- Description of ahbread* functions and procedures.
  --
  -- The ahbread* subprograms with an 'haddr' input selects the valid slice of
  -- data from the AHB data vector, 'hdata', based on the 'haddr' input if
  -- CORE_ACDM is set to 1 (see top of this package). Otherwise the low part of
  -- the AHB data vector will be returned.
  --
  -- The ahbread* subprograms that do not have a 'haddr' input will always
  -- return the low slice of the 'hdata' input. These subprograms will assert a
  -- failure if CORE_ACDM is set to 1.
  --
  function ahbreadword (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector is
    variable data : std_logic_vector(31 downto 0);
  begin 
    if CORE_ACDM = 1 then data := ahbselectdata(hdata, haddr, HSIZE_WORD, endian)(31 downto 0);
    else data := hdata(31 downto 0); end if;
    return data;
  end ahbreadword;

  procedure ahbreadword (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    haddr : in  std_logic_vector(4 downto 2);
    data  : out std_logic_vector(31 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN) is
  begin
    data := ahbreadword(hdata, haddr, endian);
  end ahbreadword;

  function ahbreadword (
    hdata : std_logic_vector(AHBDW-1 downto 0))
    return std_logic_vector is
    variable data : std_logic_vector(31 downto 0);
  begin
-- pragma translate_off
    assert CORE_ACDM = 0
      report "ahbreadword without address input used when CORE_ACDM /= 0"
      severity failure;
-- pragma translate_on
    data := hdata(31 downto 0);
    return data;
  end ahbreadword;

  procedure ahbreadword (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    data  : out std_logic_vector(31 downto 0)) is
  begin
    data := ahbreadword(hdata);
  end ahbreadword;

  function ahbreaddword (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector is
    variable data : std_logic_vector(255 downto 0);
  begin 
-- pragma translate_off
    assert AHBDW > 32
      report "ahbreaddword can not be used in system with AHB data width < 64"
      severity failure;
-- pragma translate_on
    if AHBDW = 256 then
      if CORE_ACDM = 1 then
        data(AHBDW/4-1 downto 0) :=
             ahbselectdata(hdata, haddr, HSIZE_DWORD, endian)(AHBDW/4-1 downto 0);
      else
        data(AHBDW/4-1 downto 0) := hdata(AHBDW/4-1 downto 0);
      end if;
    elsif AHBDW = 128 then
      if CORE_ACDM = 1 then
        data(AHBDW/2-1 downto 0) :=
          ahbselectdata(hdata, haddr, HSIZE_DWORD, endian)(AHBDW/2-1 downto 0);
      else
        data(AHBDW/2-1 downto 0) := hdata(AHBDW/2-1 downto 0);
      end if;
    elsif AHBDW = 64 then
      if CORE_ACDM = 1 then
        data(AHBDW-1 downto 0) :=
             ahbselectdata(hdata, haddr, HSIZE_DWORD, endian)(AHBDW-1 downto 0);
      else
        data(AHBDW-1 downto 0) := hdata(AHBDW-1 downto 0);
      end if;
    end if;
    return data(63 downto 0);
  end ahbreaddword;

  procedure ahbreaddword (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    haddr : in  std_logic_vector(4 downto 2);
    data  : out std_logic_vector(63 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN) is
  begin 
    data := ahbreaddword(hdata, haddr, endian);
  end ahbreaddword;

  function ahbreaddword (
    hdata : std_logic_vector(AHBDW-1 downto 0))
    return std_logic_vector is
    variable data : std_logic_vector(255 downto 0);
  begin 
-- pragma translate_off
    assert AHBDW > 32
      report "ahbreaddword can not be used in system with AHB data width < 64"
      severity failure;
    assert CORE_ACDM = 0
      report "ahbreaddword without address input used when CORE_ACDM /= 0"
      severity failure;
-- pragma translate_on
    if AHBDW = 256 then
      data(AHBDW/4-1 downto 0) := hdata(AHBDW/4-1 downto 0);
    elsif AHBDW = 128 then
      data(AHBDW/2-1 downto 0) := hdata(AHBDW/2-1 downto 0);
    elsif AHBDW = 64 then
      data(AHBDW-1 downto 0) := hdata(AHBDW-1 downto 0);
    end if;
    return data(63 downto 0);
  end ahbreaddword;

  procedure ahbreaddword (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    data  : out std_logic_vector(63 downto 0)) is
  begin 
    data := ahbreaddword(hdata);
  end ahbreaddword;

  function ahbread4word (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector is
    variable data : std_logic_vector(255 downto 0);
  begin
-- pragma translate_off
    assert AHBDW > 64
      report "ahbread4word can not be used in system with AHB data width < 128 bits"
      severity failure;
-- pragma translate_on
    if AHBDW = 256 then
       if CORE_ACDM = 1 then
         data(AHBDW/2-1 downto 0) :=
           ahbselectdata(hdata, haddr, HSIZE_4WORD, endian)(AHBDW/2-1 downto 0);
       else
         data(AHBDW/2-1 downto 0) := hdata(AHBDW/2-1 downto 0);
       end if;
    elsif AHBDW = 128 then
      if CORE_ACDM = 1 then
        data(AHBDW-1 downto 0) :=
          ahbselectdata(hdata, haddr, HSIZE_4WORD, endian)(AHBDW-1 downto 0);
      else
        data(AHBDW-1 downto 0) := hdata(AHBDW-1 downto 0);
      end if;
    end if;
    return data(127 downto 0);
  end ahbread4word;

  procedure ahbread4word (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    haddr : in  std_logic_vector(4 downto 2);
    data  : out std_logic_vector(127 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN) is
  begin 
    data := ahbread4word(hdata, haddr, endian);
  end ahbread4word;
  
  function ahbread4word (
    hdata : std_logic_vector(AHBDW-1 downto 0))
    return std_logic_vector is
    variable data : std_logic_vector(255 downto 0);
  begin
-- pragma translate_off
    assert AHBDW > 64
      report "ahbread4word can not be used in system with AHB data width < 128 bits"
      severity failure;
    assert CORE_ACDM = 0
      report "ahbread4word without address input used when CORE_ACDM /= 0"
      severity failure;
-- pragma translate_on
    if AHBDW = 256 then
      data(AHBDW/2-1 downto 0) := hdata(AHBDW/2-1 downto 0);
    elsif AHBDW = 128 then
      data(AHBDW-1 downto 0) := hdata(AHBDW-1 downto 0);
    end if;
    return data(127 downto 0);
  end ahbread4word;

  procedure ahbread4word (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    data  : out std_logic_vector(127 downto 0)) is
  begin 
    data := ahbread4word(hdata);
  end ahbread4word;
  
  function ahbread8word (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector is
    variable data : std_logic_vector(AHBDW-1 downto 0);
  begin
-- pragma translate_off
    assert AHBDW > 128
      report "ahbread8word can not be used in system with AHB data width < 256 bits"
      severity failure;
-- pragma translate_on
    if CORE_ACDM = 1 then
      data(AHBDW-1 downto 0) := ahbselectdata(hdata, haddr, HSIZE_8WORD)(AHBDW-1 downto 0);
    else
      data(AHBDW-1 downto 0) := hdata(AHBDW-1 downto 0);
    end if;
    return data;
  end ahbread8word;

  procedure ahbread8word (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    haddr : in  std_logic_vector(4 downto 2);
    data  : out std_logic_vector(255 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN) is
  begin 
    data := ahbread8word(hdata, haddr);
  end ahbread8word;

  function ahbread8word (
    hdata : std_logic_vector(AHBDW-1 downto 0))
    return std_logic_vector is
    variable data : std_logic_vector(AHBDW-1 downto 0);
  begin
-- pragma translate_off
    assert AHBDW > 128
      report "ahbread8word can not be used in system with AHB data width < 256 bits"
      severity failure;
    assert CORE_ACDM = 0
      report "ahbread8word without address input used when CORE_ACDM /= 0"
      severity failure;
-- pragma translate_on
    data(AHBDW-1 downto 0) := hdata(AHBDW-1 downto 0);
    return data;
  end ahbread8word;

  procedure ahbread8word (
    hdata : in  std_logic_vector(AHBDW-1 downto 0);
    data  : out std_logic_vector(255 downto 0)) is
  begin 
    data := ahbread8word(hdata);
  end ahbread8word;
  
  function ahbreaddata (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    haddr : std_logic_vector(4 downto 2);
    hsize : std_logic_vector(2 downto 0);
    endian : integer range 0 to 1 := AHBENDIAN)
    return std_logic_vector is
  begin
    case hsize is
      when HSIZE_8WORD =>
        return ahbread8word(hdata, haddr, endian);
      when HSIZE_4WORD =>
        return ahbread4word(hdata, haddr, endian);
      when HSIZE_DWORD =>
        return ahbreaddword(hdata, haddr, endian);
      when others => null;
    end case;
    return ahbreadword(hdata, haddr, endian);
  end ahbreaddata;

  function ahbreaddata (
    hdata : std_logic_vector(AHBDW-1 downto 0);
    hsize : std_logic_vector(2 downto 0))
    return std_logic_vector is
  begin
    case hsize is
      when HSIZE_8WORD =>
        return ahbread8word(hdata);
      when HSIZE_4WORD =>
        return ahbread4word(hdata);
      when HSIZE_DWORD =>
        return ahbreaddword(hdata);
      when others => null;
    end case;
    return ahbreadword(hdata);
  end ahbreaddata;

  -- a*mux below drives their amba output records with the amba input record if
  -- the en input is '1'. Otherwise the amba output record is driven to an idle
  -- state. Plug'n'play information is kept constant.
  procedure ahbmomux (
    signal ai  : in  ahb_mst_out_type;
    signal ao  : out ahb_mst_out_type;
    signal en  : in  std_ulogic) is
  begin
    if en = '1' then ao <= ai;
    else ao <= ahbm_none; end if;
    ao.haddr   <= ai.haddr;
    ao.hwrite  <= ai.hwrite;
    ao.hsize   <= ai.hsize;
    ao.hprot   <= ai.hprot;
    ao.hwdata  <= ai.hwdata;
    ao.hconfig <= ai.hconfig;
    ao.hindex  <= ai.hindex;
  end ahbmomux;

  procedure ahbsomux (
    signal ai  : in  ahb_slv_out_type;
    signal ao  : out ahb_slv_out_type;
    signal en  : in  std_ulogic) is
  begin
    if en = '1' then ao <= ai;
    else ao <= ahbs_none; end if;
    ao.hrdata  <= ai.hrdata;
    ao.hconfig <= ai.hconfig;
    ao.hindex  <= ai.hindex;
  end ahbsomux;

  procedure apbsomux (
    signal ai  : in  apb_slv_out_type;
    signal ao  : out apb_slv_out_type;
    signal en  : in  std_ulogic) is
  begin
    if en = '1' then ao <= ai;
    else ao <= apb_none; end if;
    ao.prdata  <= ai.prdata;
    ao.pconfig <= ai.pconfig;
    ao.pindex  <= ai.pindex;
  end apbsomux;

  function apb32i(i: apb3_slv_in_type) return apb_slv_in_type is
    variable r: apb_slv_in_type;
  begin
    r := (psel => i.psel, penable => i.penable, paddr => i.paddr,
          pwrite => i.pwrite, pwdata => i.pwdata, pirq => i.pirq,
          testen => i.testen, testrst => i.testrst, scanen => i.scanen,
          testoen => i.testoen, testin => i.testin);
    return r;
  end apb32i;

  function apb23o(o: apb_slv_out_type) return apb3_slv_out_type is
    variable r: apb3_slv_out_type;
  begin
    r := (prdata => o.prdata, pready => '1', pslverr => '0', pirq => o.pirq,
          pconfig => o.pconfig, pindex => o.pindex);
    return r;
  end apb23o;

  function apb23ov(o: apb_slv_out_vector) return apb3_slv_out_vector is
    variable r: apb3_slv_out_vector;
  begin
    for i in r'range loop
      r(i) := apb23o(o(i));
    end loop;
    return r;
  end apb23ov;

end;

