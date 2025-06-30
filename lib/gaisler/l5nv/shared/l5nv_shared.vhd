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
-- Package:     l5nv_shared
-- File:        l5nv_shared.vhd
-- Description: Shared sub-blocks between LEON5 and NOELV processor
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
library gaisler;
use gaisler.busif5_types.all;

package l5nv_shared is

  ----------------------------------------------------------------------------
  -- Types and constants
  ----------------------------------------------------------------------------
  constant REGW : integer := 32;

  type zfudge_type is array(0 to 8) of integer;
  constant zfudge: zfudge_type := (
    0 => 1,
    others => 0
    );

  type dev_reg_in_type is record
    sel      : std_logic_vector(3 downto 0);
    addr     : std_logic_vector(31 downto 0);
    data     : std_logic_vector(REGW-1 downto 0);
    wr       : std_ulogic;
    -- System Bus Access
    sbfinish : std_ulogic;
    sbrdata  : std_logic_vector(31 downto 0);
    sbdvalid : std_ulogic;
    sberror  : std_ulogic;
    -- Test support
    testen   : std_ulogic;
    testrst  : std_ulogic;
  end record;
  constant dev_reg_in_none : dev_reg_in_type := (
    sel      => (others => '0'),
    addr     => (others => '0'),
    data     => (others => '0'),
    wr       => '0',
    sbfinish => '0',
    sbrdata  => (others => '0'),   
    sbdvalid => '0',
    sberror  => '0',
    testen   => '0',
    testrst  => '0');
  type dev_reg_in_vector is array(natural range <>) of dev_reg_in_type;
  type dev_reg_out_type is record
    rdy      : std_ulogic;
    data     : std_logic_vector(REGW-1 downto 0);
    -- System Bus Access
    sbstart  : std_ulogic;
    sbwdata  : std_logic_vector(31 downto 0);
    sbwr     : std_ulogic;
    sbaccess : std_logic_vector(2 downto 0);
    sbaddr   : std_logic_vector(31 downto 0);
  end record;
  constant dev_reg_out_none : dev_reg_out_type := (
    rdy   => '0',
    data  => (others => '0'),
    sbstart  => '0',
    sbwdata  => (others => '0'),
    sbwr     => '0',
    sbaccess => (others => '0'),
    sbaddr   => (others => '0'));
  constant dev_reg_out_none1 : dev_reg_out_type := (
    rdy   => '1',
    data  => (others => '0'),
    sbstart  => '0',
    sbwdata  => (others => '0'),
    sbwr     => '0',
    sbaccess => (others => '0'),
    sbaddr   => (others => '0'));
  type dev_reg_out_vector is array(natural range <>) of dev_reg_out_type;

  type tracebuf_mbus_in_type is record
    addr             : std_logic_vector(11 downto 0);
    data             : std_logic_vector(223 downto 0);
    enable           : std_logic;
    write            : std_logic_vector(6 downto 0);
  end record;
  type tracebuf_mbus_out_type is record
    data             : std_logic_vector(223 downto 0);
  end record;
  type tracebuf_mbus_in_array is array(0 to 4) of tracebuf_mbus_in_type;
  type tracebuf_mbus_out_array is array(0 to 4) of tracebuf_mbus_out_type; 
  constant tracebuf_mbus_in_type_none : tracebuf_mbus_in_type := (
    addr    => (others => '0'),
    data    => (others => '0'),
    enable  => '0',
    write   => (others => '0')
    );
  constant tracebuf_mbus_out_type_none : tracebuf_mbus_out_type :=
    (data => (others => '0'));

  -- L1-cache and busif
  constant TAGMAX: integer := 32;
  constant IDXMAX: integer := 16;
  type cdatatype5 is array (0 to 3) of std_logic_vector(63 downto 0);
  type cdatatype5s is array (0 to 3) of std_logic_vector(31 downto 0);
  type cmasktype5 is array (0 to 3) of std_logic_vector(7 downto 0);

  type cram_tags is array(0 to 3) of std_logic_vector(TAGMAX-1 downto 0);

  type cram_in_type5 is record
    iindex     : std_logic_vector(IDXMAX-1 downto 0);
    itagen     : std_logic_vector(0 to 3);
    itagwrite  : std_ulogic;
    itagdin    : cram_tags;
    idataoffs  : std_logic_vector(1 downto 0);
    idataen    : std_logic_vector(0 to 3);
    idatawrite : std_logic_vector(1 downto 0);
    idatadin   : std_logic_vector(63 downto 0);
    ifulladdr  : std_logic_vector(31 downto 0);
    -- version of ifulladdr only valid on i-data writes
    -- with less logic going into it.
    ifulladdrw : std_logic_vector(31 downto 0);
    itcmen     : std_ulogic;
    itcmwrite  : std_logic_vector(1 downto 0);
    itcmdin    : std_logic_vector(63 downto 0);
    -- Cache read port
    dtagcindex : std_logic_vector(IDXMAX-1 downto 0);
    dtagcen    : std_logic_vector(0 to 3);
    -- Cache update and snoop hit port
    dtaguindex : std_logic_vector(IDXMAX-1 downto 0);
    dtaguwrite : std_logic_vector(0 to 3);
    dtagudin   : cram_tags;
    -- Combined read/update port (without snoop hit)
    dtagcuindex: std_logic_vector(IDXMAX-1 downto 0);
    dtagcuen   : std_logic_vector(0 to 3);
    dtagcuwrite: std_ulogic;
    -- DCache data
    ddataindex : std_logic_vector(IDXMAX-1 downto 0);
    ddataoffs  : std_logic_vector(1 downto 0);
    ddataen    : std_logic_vector(0 to 3);
    ddatawrite : std_logic_vector(7 downto 0);
    ddataloop  : std_logic_vector(7 downto 0);
    ddatadin   : cdatatype5;
    ddatafulladdr : std_logic_vector(31 downto 0);
    ddatafulladdrw: std_logic_vector(31 downto 0);
    dtcmen     : std_ulogic;
    dtcmdin    : std_logic_vector(63 downto 0);
    dtcmwrite : std_logic_vector(7 downto 0);
  end record;

  constant cram_in_none : cram_in_type5 := (
    iindex     => (others => '0'),
    itagen     => (others => '0'),
    itagwrite  => '0',
    itagdin    => (others => (others => '0')),
    idataoffs  => (others => '0'),
    idataen    => (others => '0'),
    idatawrite => (others => '0'),
    idatadin   => (others => '0'),
    ifulladdr  => (others => '0'),
    -- version of ifulladdr only valid on i-data writes
    -- with less logic going into it.
    ifulladdrw => (others => '0'),
    itcmen     => '0',
    itcmwrite  => (others => '0'),
    itcmdin    => (others => '0'),
    -- Cache read port
    dtagcindex => (others => '0'),
    dtagcen    => (others => '0'),
    -- Cache update and snoop hit port
    dtaguindex => (others => '0'),
    dtaguwrite => (others => '0'),
    dtagudin   => (others => (others => '0')),
    -- Combined read/update port (without snoop hit)
    dtagcuindex=> (others => '0'),
    dtagcuen   => (others => '0'),
    dtagcuwrite=> '0',
    -- DCache data
    ddataindex => (others => '0'),
    ddataoffs  => (others => '0'),
    ddataen    => (others => '0'),
    ddatawrite => (others => '0'),
    ddataloop  => (others => '0'),
    ddatadin => (others => (others => '0')),
    ddatafulladdr => (others => '0'),
    ddatafulladdrw=> (others => '0'),
    dtcmen     => '0',
    dtcmdin    => (others => '0'),
    dtcmwrite => (others => '0')
  );

  type cram_out_type5 is record
    itagdout: cram_tags;
    idatadout: cdatatype5;
    itcmdout: std_logic_vector(63 downto 0);
    dtagcdout: cram_tags;
    ddatadout: cdatatype5;
    dtcmdout: std_logic_vector(63 downto 0);
  end record;

  constant cram_out_none : cram_out_type5 := (
    itagdout  => (others => (others => '0')),
    idatadout => (others => (others => '0')),
    itcmdout  => (others => '0'),
    dtagcdout => (others => (others => '0')),
    ddatadout => (others => (others => '0')),
    dtcmdout  => (others => '0')
  );


  type snoopram_in_type5 is record
    -- Snoop tag read and write
    dtagsindex : std_logic_vector(IDXMAX-1 downto 0);
    dtagsen    : std_logic_vector(0 to 3);
    dtagswrite : std_ulogic;
    dtagsdin   : cram_tags;
  end record;

  type snoopram_in_vector is array(natural range <>) of snoopram_in_type5;

  type snoopram_out_type5 is record
    dtagsdout: cram_tags;
  end record;

  constant snoopram_in5_none: snoopram_in_type5 := (
    (others => '0'), "0000", '0', (others => (others => '0'))
    );

  constant snoopram_out5_none: snoopram_out_type5 := (
    dtagsdout => (others => (others => '0'))
    );
  
  type snoopram_out_vector is array(natural range <>) of snoopram_out_type5;


  type l5_intreg_mosi_type is record
    accen: std_ulogic;
    addr: std_logic_vector(21 downto 0);
    accwr: std_ulogic;
    wrdata: std_logic_vector(31 downto 0);
  end record;

  type l5_intreg_miso_type is record
    accrdy: std_ulogic;
    rddata: std_logic_vector(31 downto 0);
  end record;

  constant l5_intreg_mosi_none: l5_intreg_mosi_type := ('0', (others => '0'), '0', (others => '0'));
  constant l5_intreg_miso_none: l5_intreg_miso_type := ('1', (others => '0'));

  type l5_intreg_miso_array is array(natural range <>) of l5_intreg_miso_type;
  type l5_intreg_mosi_array is array(natural range <>) of l5_intreg_mosi_type;


  type dmnv_ic_dma_bus_type is record
    req : std_logic_vector(0 to 5);
    addr : std_logic_vector(47 downto 0);
    wr : std_ulogic;
    size : std_logic_vector(1 downto 0);
    burst : std_ulogic;
    wrdv : std_ulogic;
    wraddr : std_logic_vector(5 downto 2);
    wrdata : std_logic_vector(31 downto 0);
  end record;
  constant dmnv_ic_dma_bus_none : dmnv_ic_dma_bus_type := (
    req => (others => '0'), addr => (others => '0'), wr => '0',
    size => "00", burst => '0',
    wrdv => '0', wraddr => (others => '0'), wrdata => (others => '0')
    );

  type dmnv_ic_bus_dma_type is record
    gnt : std_ulogic;
    rddv : std_ulogic;
    rdaddr : std_logic_vector(5 downto 2);
    rddata : std_logic_vector(31 downto 0);
  end record;
  constant dmnv_ic_bus_dma_none : dmnv_ic_bus_dma_type := (
    gnt => '0', rddv => '0', rdaddr => (others => '0'), rddata => (others => '0')
    );

  type dmnv_ic_dma_bus_vector is array(natural range <>) of dmnv_ic_dma_bus_type;
  type dmnv_ic_bus_dma_vector is array(natural range <>) of dmnv_ic_bus_dma_type;

  type l5_tsc_async_type is record
    -- Synchronous part for managing low bits
    -- 00=freeze, 01=inc, 11=inc+wrap, 10=clear
    loupd   : std_logic_vector(1 downto 0);
    -- increment amount minus one, used for frequency ratio operation
    incval  : std_logic_vector(2 downto 0);
    -- Timer update, async, with update flag
    tschi   : std_logic_vector(62 downto 8);
    tsclo   : std_logic_vector(7 downto 0);
    strobeh : std_ulogic;
    strobel : std_ulogic;
  end record;

  constant l5_tsc_async_none : l5_tsc_async_type := (
    "00","000",(others => '0'),"00000000",'0','0'
    );

  type l5_tsc_async_vector is array(natural range <>) of l5_tsc_async_type;

  type l5_tsc_ctrl_type is record
    freeze : std_ulogic;
    set    : std_ulogic;
    setval : std_logic_vector(62 downto 0);
  end record;

  constant l5_tsc_ctrl_none : l5_tsc_ctrl_type := ('0', '0', (others => '0'));


  ----------------------------------------------------------------------------
  -- Components
  ----------------------------------------------------------------------------

  component dmnv_ic_dmaport
    generic (
      dmhaddr   : integer;
      dmhmask   : integer;
      burstlen  : integer
      );
    port (
      clk   : in  std_ulogic;
      rstn  : in  std_ulogic;
      -- Debug-link interface
      dmami : out ahb_mst_in_type;
      dmamo : in  ahb_mst_out_type;
      -- Interface to interconnect
      icdb  : out dmnv_ic_dma_bus_type;
      icbd  : in  dmnv_ic_bus_dma_type
      );
  end component;

  component dmnv_ic_busport
    generic (
      busid    : integer;
      abits    : integer;
      dbits    : integer;
      vdbits   : integer;
      burstlen : integer;
      lowd     : integer;
      pnpgen   : integer := 0;
      pnpaddrhi: integer := 0;
      pnpaddrlo: integer := 0;
      pnpmpos  : integer := 0;
      pnpnmst  : integer := 1;
      pnpspos  : integer := 0;
      pnpnslv  : integer := 1
      );
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      -- AHB interface
      endian   : in  std_ulogic;
      hready   : in  std_ulogic;
      hbusreq  : out std_ulogic;
      hgrant   : in  std_ulogic;
      htrans   : out std_logic_vector(1 downto 0);
      haddr    : out std_logic_vector(abits-1 downto 0);
      hwrite   : out std_ulogic;
      hsize    : out std_logic_vector(2 downto 0);
      hburst0  : out std_ulogic;
      hresp    : in  std_logic_vector(1 downto 0);
      hwdata   : out std_logic_vector(vdbits-1 downto 0);
      hrdata   : in  std_logic_vector(vdbits-1 downto 0);
      -- Interface to interconnect
      icdb     : in  dmnv_ic_dma_bus_type;
      icbd     : out dmnv_ic_bus_dma_type;
      -- Signals for AMBA PnP patching
      mstpnp   : in  ahb_config_array(0 to pnpnmst-1) := (others => (others => (others => '0')));
      slvpnp   : in  ahb_config_array(0 to pnpnslv-1) := (others => (others => (others => '0')))
      );
  end component;

  component dmnv_ic_ebp is
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
      -- Debug-module AHB bus interface
      dmmi    : in  ahb_mst_in_type;
      dmmo    : out ahb_mst_out_type;
      -- Plug'n'play record for debug module (patched into PnP)
      dmpnp   : in  ahb_config_type
      );
  end component;

  component dmnv_ic is
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
      dmpnp   : in  ahb_config_type
      );
  end component;

  component dmnv_ahbs is
    generic (
      hindex    : integer range 0  to 15  := 0;   -- bus index
      hmindex   : integer range 0  to 15  := 0;   -- master bus index
      haddr     : integer                 := 16#900#;
      hmask     : integer                 := 16#f00#
      );
    port (
      clk     : in  std_ulogic;
      rstn    : in  std_ulogic;
      ahbsi   : in  ahb_slv_in_type;
      ahbso   : out ahb_slv_out_type;
      ahbmi   : in  ahb_mst_in_type;
      ahbmo   : out ahb_mst_out_type;
      -- DM interface
      dmi     : out dev_reg_in_type;
      dmo     : in  dev_reg_out_type := dev_reg_out_none;
      dmi2    : out dev_reg_in_type;
      dmo2    : in  dev_reg_out_type := dev_reg_out_none;
      -- Trace interface
      tri     : out dev_reg_in_type;
      tro     : in  dev_reg_out_type;
      -- LEON5 mode
      l5mode  : in  std_ulogic := '0';
      -- LEON5 itrace buffer
      l5iti   : out dev_reg_in_type;
      l5ito   : in  dev_reg_out_type := dev_reg_out_none;
      -- LEON5 iu reg access
      l5iui   : out dev_reg_in_type;
      l5iuo   : in  dev_reg_out_type := dev_reg_out_none
      );
  end component;

  component dmnv_trace is
    generic (
      fabtech   : integer;
      memtech   : integer;
      cbusw     : integer;
      addrbits  : integer                 := 6;
      ahbwp     : integer                 := 2;
      tbits     : integer                 := 30;
      scantest  : integer                 := 0
      );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      tri         : in  dev_reg_in_type;
      tro         : out dev_reg_out_type;
      cbmi        : in  ahb_mst_in_type;
      cbsi        : in  ahb_slv_in_type;
      rsten       : in  std_ulogic       := '0';
      timer       : in  std_logic_vector(tbits-1 downto 0)
      );
  end component;

  component dmnv_trace_ahb is
    generic (
      fabtech   : integer;
      memtech   : integer;
      hindex    : integer range 0  to 15  := 0;   -- bus index
      haddr     : integer                 := 16#000#;
      hmask     : integer                 := 16#000#;
      addrbits  : integer                 := 6;
      ahbwp     : integer                 := 2;
      tbits     : integer                 := 30;
      scantest  : integer                 := 0
      );
    port (
      clk         : in  std_ulogic;
      rstn        : in  std_ulogic;
      ahbsi       : in  ahb_slv_in_type;
      ahbso       : out ahb_slv_out_type;
      cbmi        : in  ahb_mst_in_type;
      cbsi        : in  ahb_slv_in_type;
      timer       : in  std_logic_vector(tbits-1 downto 0)
      );
  end component;

  component tbufmemnv_mbus is
    generic (
      tech     : integer := 0;
      addrbits : integer := 6;
      dwidth   : integer := 64; -- AHB data width
      nbus     : integer := 4;
      proc     : integer := 0;
      testen   : integer := 0
      );
    port (
      clk : in std_ulogic;
      trace_in  : in tracebuf_mbus_in_array;
      trace_out  : out tracebuf_mbus_out_array;
      testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
      );
  end component;

  component tcmwrap5 is
    generic (
      tech : integer;
      abits : integer;
      afrac : integer range 0 to 7;
      dbits : integer;
      bw : integer;
      dloopen: integer := 0;
      testen : integer;
      mtwidth : integer;
      rdenall : integer := 0
      );
    port (
      clk      : in std_ulogic;
      address  : in std_logic_vector((abits -1) downto 0);
      addressw : in std_logic_vector((abits -1) downto 0);
      datainh  : in std_logic_vector((dbits -1) downto 0);
      datainl  : in std_logic_vector((dbits -1) downto 0);
      dataouth : out std_logic_vector((dbits -1) downto 0);
      dataoutl : out std_logic_vector((dbits -1) downto 0);
      enable   : in std_ulogic;
      writeh   : in std_ulogic;
      writel   : in std_ulogic;
      writebw  : in std_logic_vector(7 downto 0) := "00000000";
      dataloop : in std_logic_vector(7 downto 0) := (others => '0');
      oor      : out std_ulogic;
      testin   : in std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
      );
  end component;

  component cachemem5 is
    generic (
      hindex    : integer range 0 to 15 := 0;
      tech      : integer range 0 to NTECH;
      iways     : integer range 1 to 4;
      ilinesize : integer range 4 to 8;
      iidxwidth : integer range 1 to 10;
      itagwidth : integer range 1 to 32;
      itcmen    : integer range 0 to 1;
      itcmabits : integer range 1 to 20;
      itcmfrac  : integer range 0 to 7;
      dways     : integer range 1 to 4;
      dlinesize : integer range 4 to 8;
      didxwidth : integer range 1 to 10;
      dtagwidth : integer range 1 to 32;
      dtagconf  : integer range 0 to 2;
      mbmode    : integer range 0 to 1 := 0;
      dusebw    : integer range 0 to 1;
      dtcmen    : integer range 0 to 1;
      dtcmabits : integer range 1 to 20;
      dtcmfrac  : integer range 0 to 7;
      testen    : integer range 0 to 1
      );
    port (
      rstn  : in  std_ulogic;
      clk   : in  std_ulogic;
      sclk  : in  std_ulogic;
      crami : in  cram_in_type5;
      cramo : out cram_out_type5;
      sni : in  snoopram_in_type5;
      sno : out snoopram_out_type5;
      testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
      );
  end component;

  component snoopmem5 is
    generic (
      tech      : integer range 0 to NTECH;
      dways     : integer range 1 to 4;
      didxwidth : integer range 1 to 10;
      dtagwidth : integer range 1 to 32;
      dtagconf  : integer range 0 to 2;
      testen    : integer range 0 to 1
      );
    port (
      rstn  : in  std_ulogic;
      sclk  : in  std_ulogic;
      sni   : in  snoopram_in_type5;
      sno   : out snoopram_out_type5;
      testin : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
      );
  end component;

  ----------------------------------------------------------------------------
  -- Bus interface module
  ----------------------------------------------------------------------------
  component busif5x is
    generic (
      hindex    : integer range 0 to 15 := 0;
      ilinesize : integer range 4 to 8;
      dways     : integer range 1 to 4;
      dlinesize : integer range 4 to 8;
      dwaysize  : integer range 1 to 256;
      busw      : integer;                -- AHB data bus width
      rbusw     : integer;                -- AHB data bus width for rddata muxing
      sigbusw   : integer;                -- Data bus width of signals, can be set >=rbusw for convenience
      abitso     : integer;               -- AHB address out bus width
      abitsi    : integer;                -- AHB address in bus width (normally same as abitso)
      sigaw     : integer;                -- Signal width >= abitso,abitsi for convenience
      ibusw     : integer;                -- Bus if width for read data
      hburstw   : integer                 -- For convenience
--pragma translate_off
      ; biftrace : integer := 0;
      busid : string := "bus0"
--pragma translate_on
      );
    port (
      clk            : in  std_ulogic;
      rstn           : in  std_ulogic;
      -- Endianness control
      endian         : in  std_ulogic;
      -- AHB master port
      ahbi_hready    : in std_ulogic;
      ahbi_hgrant    : in std_ulogic;
      ahbi_hrdata    : in std_logic_vector(sigbusw-1 downto 0);
      ahbi_hresp     : in std_logic_vector(1 downto 0);
      ahbo_hbusreq   : out std_ulogic;
      ahbo_hlock     : out std_ulogic;
      ahbo_htrans    : out std_logic_vector(1 downto 0);
      ahbo_haddr     : out std_logic_vector(sigaw-1 downto 0);
      ahbo_hwrite    : out std_ulogic;
      ahbo_hsize     : out std_logic_vector(2 downto 0);
      ahbo_hburst    : out std_logic_vector(hburstw-1 downto 0);
      ahbo_hprot     : out std_logic_vector(3 downto 0);
      ahbo_hwdata    : out std_logic_vector(sigbusw-1 downto 0);
      -- AHB snoop port
      ahbsi_htrans   : in std_logic_vector(1 downto 0);
      ahbsi_haddr    : in std_logic_vector(sigaw-1 downto 0);
      ahbsi_hwrite   : in std_ulogic;
      ahbsi_hsize    : in std_logic_vector(2 downto 0);
      ahbsi_hmaster  : in std_logic_vector(3 downto 0);
      -- Cache controller interface
      bifi_bifop     : in  std_logic_vector(3 downto 0);
      bifi_busaddr   : in  std_logic_vector(abitso-1 downto 0);
      bifi_widebus   : in  std_ulogic;
      bifi_size      : in  std_logic_vector(1 downto 0);
      bifi_stdata    : in  std_logic_vector(63 downto 0);
      bifi_nosnoop   : in  std_ulogic;
      bifi_su        : in  std_ulogic;
      bifi_mmuacc    : in  std_ulogic;          -- 0=regular, 1=PTE
      bifi_maskwerr  : in  std_logic_vector(1 downto 0);
      bifi_wcomb     : in  std_ulogic;          -- potential write combining
      bifi_dlfway    : in  std_logic_vector(0 to 3);
      bifi_snoopen   : in  std_ulogic;
      bifi_lr_set    : in  std_ulogic := '0';
      bifi_lr_clr    : in  std_ulogic := '0';
      --bifi_lr_addr   : in std_logic_vector(sigaw-1 downto 0) := (others => '0');
      keeplock       : in  std_ulogic := '0';
      rdbufw         : out std_logic_vector(15 downto 0);
      rdbufwd        : out std_logic_vector(127 downto 0);
      rdbufe         : out std_logic_vector(15 downto 0);
      nrddone        : out std_ulogic;
      nrdstarted     : out std_ulogic;
      errclr         : out std_logic_vector(1 downto 0);
      bifo_ready     : out std_ulogic;
      bifo_idle      : out std_ulogic;
      bifo_sterr     : out std_logic_vector(3 downto 0);
      bifo_locked    : out std_ulogic;
      bifo_dtagupd   : out std_logic_vector(0 to 3);
      bifo_dtaguval  : out std_logic_vector(TAGMAX-3 downto 0);
      bifo_dtagumsb  : out std_logic_vector(7 downto 0);
      bifo_dtaguidx  : out std_logic_vector(IDXMAX-1 downto 0);
      bifo_dtagutype : out std_logic_vector(1 downto 0);  -- 00=snoop, 01=flush, 10=dline fetch, 11=dtag wrte
      bifo_lr_valid  : out std_ulogic;
      bifo_stpend    : out std_logic_vector(1 downto 0);
      -- Snoop RAM interface
      dtagsindex     : out std_logic_vector(IDXMAX-1 downto 0);
      dtagsen        : out std_logic_vector(0 to 3);
      dtagswrite     : out std_ulogic;
      dtagsdin       : out cram_tags;
      dtagsdout      : in cram_tags;
      maprindex      : out std_logic_vector(IDXMAX-1 downto 0);
      mapout         : in  std_logic_vector(0 to DWAYS-1) := (others => '1')
      );
  end component;

  component busif5rdb is
    generic (
      linesize : integer;
      wdwidth  : integer;
      nports   : integer
      );
    port (
      clk  : in  std_ulogic;
      clr  : in  std_ulogic;
      ubuf : in  busif_rdbufu_array_type(0 to nports-1);
      rbuf : out busif_rdbufr_type5
      );
  end component;

  component busif5 is
    generic (
      hindex    : integer := 0;
      device    : integer;
      version   : integer;
      ilinesize : integer range 4 to 8;
      dways     : integer range 1 to 4;
      dlinesize : integer range 4 to 8;
      dwaysize  : integer range 1 to 256;
      wbmask    : integer;
      busw      : integer
      );
    port (
      clk   : in  std_ulogic;
      rstn  : in  std_ulogic;
      ahbi  : in  ahb_mst_in_type;
      ahbo  : out ahb_mst_out_type;
      ahbsi : in  ahb_slv_in_type;
      bifi  : in  busif_in_type5;
      bifo  : out busif_out_type5;
      sni   : out snoopram_in_type5;
      sno   : in  snoopram_out_type5
      );
  end component;


  ----------------------------------------------------------------------------
  -- Cycle timer distribution
  ----------------------------------------------------------------------------
  component l5tscgen is
    generic (
      tech     : integer;
      nsync    : integer;
      nsinks   : integer;
      npipe    : integer;
      asyncset : integer
      );
    port (
      clk      : in  std_ulogic;
      rstn     : in  std_ulogic;
      ctrl     : in  l5_tsc_ctrl_type;
      tssetack : out std_ulogic;
      tsc      : out l5_tsc_async_vector(0 to nsinks-1)
      );
  end component;

  component l5tscsink is
    generic (
      tech   : integer;
      nsync  : integer;
      tbits  : integer := 63
      );
    port (
      clk    : in std_ulogic;
      rstn   : in std_ulogic;
      tsc    : in l5_tsc_async_type;
      timer  : out std_logic_vector(tbits-1 downto 0)
      );
  end component;

  ----------------------------------------------------------------------------
  -- Functions
  ----------------------------------------------------------------------------
end package;

package body l5nv_shared is

end package body;
