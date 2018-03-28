------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2010, Aeroflex Gaisler
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
-- Entity:  memctrl
-- File: memctrl.vhd
-- Author:  Jiri Gaisler - Gaisler Research
-- Description:   Memory controller package
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.log2;
library techmap;
use techmap.gencomp.all;

package memctrl is

type memory_in_type is record
  data          : std_logic_vector(31 downto 0); -- Data bus address
  brdyn         : std_logic;
  bexcn         : std_logic;
  writen        : std_logic;
  wrn           : std_logic_vector(3 downto 0);
  bwidth        : std_logic_vector(1 downto 0);
  sd            : std_logic_vector(63 downto 0);
  cb            : std_logic_vector(15 downto 0);
  scb           : std_logic_vector(15 downto 0);
  edac          : std_logic;
end record;

constant memory_in_none : memory_in_type :=
  ((others => '0'), '0', '0', '0', (others => '0'), (others => '0'),
   (others => '0'), (others => '0'), (others => '0'), '0');

type memory_out_type is record
  address       : std_logic_vector(31 downto 0);
  data          : std_logic_vector(31 downto 0);
  sddata        : std_logic_vector(63 downto 0);
  ramsn         : std_logic_vector(7 downto 0);
  ramoen        : std_logic_vector(7 downto 0);
  ramn          : std_ulogic;
  romn          : std_ulogic;
  mben          : std_logic_vector(3 downto 0);
  iosn          : std_logic;
  romsn         : std_logic_vector(7 downto 0);
  oen           : std_logic;
  writen        : std_logic;
  wrn           : std_logic_vector(3 downto 0);
  bdrive        : std_logic_vector(3 downto 0);
  vbdrive       : std_logic_vector(31 downto 0); --vector bus drive
  svbdrive      : std_logic_vector(63 downto 0); --vector bus drive sdram
  read          : std_logic;
  sa            : std_logic_vector(14 downto 0);
  cb            : std_logic_vector(15 downto 0);
  scb           : std_logic_vector(15 downto 0);
  vcdrive       : std_logic_vector(15 downto 0); --vector bus drive cb
  svcdrive      : std_logic_vector(15 downto 0); --vector bus drive cb sdram
  ce            : std_ulogic;
  sdram_en      : std_ulogic;                      -- SDRAM enabled
  rs_edac_en    : std_ulogic;                      -- Reed-Solomon enabled
end record;

constant memory_out_none : memory_out_type :=
  ((others => '0'), (others => '0'), (others => '0'), (others => '1'),
   (others => '1'), '1', '1', (others => '1'), '1', (others => '1'),
   '1', '1', (others => '1'), (others => '1'), (others => '1'),
   (others => '1'), '0', (others => '0'), (others => '1'), (others => '1'),
   (others => '1'), (others => '1'), '0', '0', '0');

type sdctrl_in_type is record
  wprot     : std_ulogic;
  data      : std_logic_vector (127 downto 0);  -- data in
  cb        : std_logic_vector(63 downto 0);  
  regrdata  : std_logic_vector(63 downto 0);  -- PHY-specific reg in
end record;

constant sdctrl_in_none : sdctrl_in_type :=
  ('0', (others => '0'), (others => '0'), (others => '0'));

type sdctrl_out_type is record
  sdcke     : std_logic_vector ( 1 downto 0);  -- clk en
  sdcsn     : std_logic_vector ( 1 downto 0);  -- chip sel
  sdwen     : std_ulogic;                       -- write en
  rasn      : std_ulogic;                       -- row addr stb
  casn      : std_ulogic;                       -- col addr stb
  dqm       : std_logic_vector ( 15 downto 0);  -- data i/o mask
  bdrive    : std_ulogic;                       -- bus drive
  qdrive    : std_ulogic;                       -- bus drive
  vbdrive   : std_logic_vector(63 downto 0);   -- vector bus drive
  address   : std_logic_vector (16 downto 2);  -- address out
  data      : std_logic_vector (127 downto 0);  -- data out
  cb        : std_logic_vector(63 downto 0);
  ce        : std_ulogic;
  ba        : std_logic_vector (2 downto 0);  -- bank address
  sdck      : std_logic_vector(2 downto 0);
  moben     : std_logic;                       -- Mobile support
  cal_en    : std_logic_vector(7 downto 0); -- enable delay calibration
  cal_inc   : std_logic_vector(7 downto 0); -- inc/dec delay
  cal_pll   : std_logic_vector(1 downto 0); -- (enable,inc/dec) pll phase
  cal_rst   : std_logic;                    -- calibration reset
  odt       : std_logic_vector(1 downto 0); -- In Die Termination
  conf      : std_logic_vector(63 downto 0);
  oct       : std_logic;                    -- On Chip Termination
  vcbdrive  : std_logic_vector(31 downto 0);   -- cb vector bus drive
  cbdqm     : std_logic_vector(7 downto 0);
  cbcal_en  : std_logic_vector(3 downto 0);
  cbcal_inc : std_logic_vector(3 downto 0);
  read_pend : std_logic_vector(7 downto 0);  -- Read pending within 7...0
                                             -- cycles (not including phy delays)
  -- PHY-specific register interface
  regwdata  : std_logic_vector(63 downto 0);
  regwrite  : std_logic_vector(1 downto 0);
end record;

constant sdctrl_out_none : sdctrl_out_type :=
  ((others => '0'), (others => '0'), '0', '0', '0', (others => '0'),
   '0', '0', (others => '0'), (others => '0'), (others => '0'),
   (others => '0'), '0', (others => '0'), (others => '0'), '0',
   (others => '0'), (others => '0'), (others => '0'), '0',
   (others => '0'), (others => '0'), '0', (others => '0'),
   (others => '0'), (others => '0'), (others => '0'), "00000000",
   (others => '0'), "00");

type sdram_out_type is record
  sdcke     : std_logic_vector ( 1 downto 0);  -- clk en
  sdcsn     : std_logic_vector ( 1 downto 0);  -- chip sel
  sdwen     : std_ulogic;                       -- write en
  rasn      : std_ulogic;                       -- row addr stb
  casn      : std_ulogic;                       -- col addr stb
  dqm       : std_logic_vector ( 7 downto 0);  -- data i/o mask
end record;

component sdctrl
  generic (
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#f00#;
    ioaddr  : integer := 16#000#;
    iomask  : integer := 16#fff#;
    wprot   : integer := 0;
    invclk  : integer := 0;
    fast    : integer := 0;
    pwron   : integer := 0;
    sdbits  : integer := 32;
    oepol   : integer := 0;
    pageburst : integer := 0;
    mobile  : integer := 0
  );
  port (
    rst    : in  std_ulogic;
    clk    : in  std_ulogic;
    ahbsi  : in  ahb_slv_in_type;
    ahbso  : out ahb_slv_out_type;
    sdi    : in  sdctrl_in_type;
    sdo    : out sdctrl_out_type
  );
end component;

component sdctrl64
  generic (
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#f00#;
    ioaddr  : integer := 16#000#;
    iomask  : integer := 16#fff#;
    wprot   : integer := 0;
    invclk  : integer := 0;
    fast    : integer := 0;
    pwron   : integer := 0;
    oepol   : integer := 0;
    pageburst : integer := 0;
    mobile  : integer := 0
  );
  port (
    rst    : in  std_ulogic;
    clk    : in  std_ulogic;
    ahbsi  : in  ahb_slv_in_type;
    ahbso  : out ahb_slv_out_type;
    sdi    : in  sdctrl_in_type;
    sdo    : out sdctrl_out_type
  );
end component;

component ftsdctrl is
  generic (
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#f00#;
    ioaddr  : integer := 16#000#;
    iomask  : integer := 16#fff#;
    wprot   : integer := 0;
    invclk  : integer := 0;
    fast    : integer := 0;
    pwron   : integer := 0;
    sdbits  : integer := 32;
    edacen  : integer := 1;
    errcnt  : integer := 0;
    cntbits : integer range 1 to 8 := 1;
    oepol   : integer := 0;
    pageburst : integer := 0
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    sdi     : in  sdctrl_in_type;
    sdo     : out sdctrl_out_type
  );
end component;

component ftsdctrl64
  generic (
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#f00#;
    ioaddr  : integer := 16#000#;
    iomask  : integer := 16#fff#;
    wprot   : integer := 0;
    invclk  : integer := 0;
    fast    : integer := 0;
    pwron   : integer := 0;
    oepol   : integer := 0;
    pageburst : integer := 0;
    mobile  : integer := 0;
    edac    : integer := 0
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    sdi     : in  sdctrl_in_type;
    sdo     : out sdctrl_out_type
  );
end component;

component srctrl
  generic (
    hindex  : integer := 0;
    romaddr : integer := 0;
    rommask : integer := 16#ff0#;
    ramaddr : integer := 16#400#;
    rammask : integer := 16#ff0#;
    ioaddr  : integer := 16#200#;
    iomask  : integer := 16#ff0#;
    ramws   : integer := 0;
    romws   : integer := 2;
    iows    : integer := 2;
    rmw     : integer := 0;
    prom8en : integer := 0;
    oepol   : integer := 0;
    srbanks : integer range 1 to 5 := 1;
    banksz  : integer range 0 to 13 := 13;
    romasel : integer range 0 to 28 := 19
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    sri     : in  memory_in_type;
    sro     : out memory_out_type;
    sdo     : out sdctrl_out_type
  );
end component;

component ftsrctrl is
  generic (
    hindex       : integer := 0;
    romaddr      : integer := 0;
    rommask      : integer := 16#ff0#;
    ramaddr      : integer := 16#400#;
    rammask      : integer := 16#ff0#;
    ioaddr       : integer := 16#200#;
    iomask       : integer := 16#ff0#;
    ramws        : integer := 0;
    romws        : integer := 2;
    iows         : integer := 2;
    rmw          : integer := 0;
    srbanks      : integer range 1 to 8  := 1;
    banksz       : integer range 0 to 15 := 15;
    rombanks     : integer range 1 to 8  := 1;
    rombanksz    : integer range 0 to 15 := 15;
    rombankszdef : integer range 0 to 15 := 15;
    pindex       : integer := 0;
    paddr        : integer := 0;
    pmask        : integer := 16#fff#;
    edacen       : integer range 0 to 1 := 1;
    errcnt       : integer range 0 to 1 := 0;   
    cntbits      : integer range 1 to 8 := 1;
    wsreg        : integer := 0;
    oepol        : integer := 0;
    prom8en      : integer := 0;
    netlist      : integer := 0;
    tech         : integer := 0
  );
  port (
    rst          : in  std_ulogic;
    clk          : in  std_ulogic;
    ahbsi        : in  ahb_slv_in_type;
    ahbso        : out ahb_slv_out_type;
    apbi         : in  apb_slv_in_type;
    apbo         : out apb_slv_out_type;
    sri          : in  memory_in_type;
    sro          : out memory_out_type;
    sdo          : out sdctrl_out_type
  );
end component; 

type sdram_in_type is record
  haddr         : std_logic_vector(31 downto 0);  -- memory address
  rhaddr        : std_logic_vector(31 downto 0);  -- latched memory address
  hready        : std_ulogic;
  hsize         : std_logic_vector(1 downto 0);
  hsel          : std_ulogic;
  hwrite        : std_ulogic;
  htrans        : std_logic_vector(1 downto 0);
  rhtrans       : std_logic_vector(1 downto 0);
  nhtrans       : std_logic_vector(1 downto 0);
  idle      : std_ulogic;
  enable    : std_ulogic;
  error     : std_ulogic;
  merror    : std_ulogic;
  brmw      : std_ulogic;
  edac      : std_ulogic;
  srdis         : std_logic;
end record;

type sdram_mctrl_out_type is record
  address       : std_logic_vector(16 downto 2);
  busy          : std_ulogic;
  aload         : std_ulogic;
  bdrive        : std_ulogic;
  hready        : std_ulogic;
  hsel          : std_ulogic;
  bsel          : std_ulogic;
  hresp     	: std_logic_vector (1 downto 0);
  vhready       : std_ulogic;
  prdata    	: std_logic_vector (31 downto 0);
end record;

type wprot_out_type is record
  wprothit      : std_ulogic;
end record;

component sdmctrl
  generic (
    pindex  : integer := 0;
    invclk  : integer := 0;
    fast    : integer := 0;
    wprot   : integer := 0;
    sdbits  : integer := 32;
    pageburst : integer := 0;
    mobile  : integer := 0
  );
  port (
    rst    : in  std_ulogic;
    clk    : in  std_ulogic;
    sdi    : in  sdram_in_type;
    sdo    : out sdram_out_type;
    apbi   : in  apb_slv_in_type;
    wpo    : in  wprot_out_type;
    sdmo   : out sdram_mctrl_out_type
  );
end component;

component ftsdmctrl
  generic (
    pindex  : integer := 0;
    invclk  : integer := 0;
    fast    : integer := 0;
    wprot   : integer := 0;
    sdbits  : integer := 32;
    syncrst : integer := 0;
    pageburst : integer := 0
  );
  port (
    rst    : in  std_ulogic;
    clk    : in  std_ulogic;
    sdi    : in  sdram_in_type;
    sdo    : out sdram_out_type;
    apbi   : in  apb_slv_in_type;
    wpo    : in  wprot_out_type;
    sdmo   : out sdram_mctrl_out_type
  );
end component;

component ftmctrl
  generic (
    hindex    : integer := 0;
    pindex    : integer := 0;
    romaddr   : integer := 16#000#;
    rommask   : integer := 16#E00#;
    ioaddr    : integer := 16#200#;
    iomask    : integer := 16#E00#;
    ramaddr   : integer := 16#400#;
    rammask   : integer := 16#C00#;
    paddr     : integer := 0;
    pmask     : integer := 16#fff#;
    wprot     : integer := 0;
    invclk    : integer := 0;
    fast      : integer := 0;
    romasel   : integer := 28;
    sdrasel   : integer := 29;
    srbanks   : integer := 4;
    ram8      : integer := 0;
    ram16     : integer := 0;
    sden      : integer := 0;
    sepbus    : integer := 0;
    sdbits    : integer := 32;
    sdlsb     : integer := 2;          -- set to 12 for the GE-HPE board
    oepol     : integer := 0;
    edac      : integer := 0;
    syncrst   : integer := 0;
    pageburst : integer := 0;
    scantest  : integer := 0;
    writefb   : integer := 0;
    netlist   : integer := 0;
    tech      : integer := 0
  );
  port (
    rst       : in  std_ulogic;
    clk       : in  std_ulogic;
    memi      : in  memory_in_type;
    memo      : out memory_out_type;
    ahbsi     : in  ahb_slv_in_type;
    ahbso     : out ahb_slv_out_type;
    apbi      : in  apb_slv_in_type;
    apbo      : out apb_slv_out_type;
    wpo       : in  wprot_out_type;
    sdo       : out sdram_out_type
  );
end component;

component ssrctrl
  generic (
    hindex  : integer := 0;
    pindex  : integer := 0;
    romaddr : integer := 0;
    rommask : integer := 16#ff0#;
    ramaddr : integer := 16#400#;
    rammask : integer := 16#ff0#;
    ioaddr  : integer := 16#200#;
    iomask  : integer := 16#ff0#;
    paddr   : integer := 0;
    pmask   : integer := 16#fff#;
    oepol   : integer := 0;
    bus16   : integer := 0
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    apbi    : in  apb_slv_in_type;
    apbo    : out apb_slv_out_type;
    sri     : in  memory_in_type;
    sro     : out memory_out_type

  );
end component;

 type ddrmem_in_type is record
    cke        : std_ulogic;
    cs         : std_logic_vector(1 downto 0);
    control    : std_logic_vector(2 downto 0);  --RAS,CAS,WE
    ba         : std_logic_vector(1 downto 0);
    adr        : std_logic_vector(13 downto 0);
    dq         : std_logic_vector(63 downto 0);
    dm         : std_logic_vector(15 downto 0);
    dqs        : std_logic_vector(15 downto 0);
    dq_oe      : std_logic_vector(63 downto 0);
    dqs_oe     : std_logic_vector(15 downto 0);
 end record;

 type ddrmem_out_type is record
    dq         : std_logic_vector(63 downto 0);
    dqs        : std_logic_vector(15 downto 0);
 end record;

component ddrctrl
  generic (
    hindex1    :     integer := 0;
    haddr1     :     integer := 0;
    hmask1     :     integer := 16#f80#;
    hindex2    :     integer := 0;
    haddr2     :     integer := 0;
    hmask2     :     integer := 16#f80#;
    pindex     :     integer := 3;
    paddr      :     integer := 0;
    numahb     :     integer := 1;       -- Allowed: 1, 2
    ahb1sepclk :     integer := 0;       -- Allowed: 0, 1
    ahb2sepclk :     integer := 0;       -- Allowed: 0, 1
    modbanks   :     integer := 1;       -- Allowed: 1, 2
    numchips   :     integer := 8;       -- Allowed: 1, 2, 4, 8, 16
    chipbits   :     integer := 8;       -- Allowed: 4, 8, 16
    chipsize   :     integer := 128;     -- Allowed: 64, 128, 256, 512, 1024 (MB)
    plldelay   :     integer := 0;       -- Allowed: 0, 1 (Use 200us start up delay)
    tech       :     integer := 0;
    clkperiod  :     integer := 10);     -- 100 Mhz
  port (
    rst       : in  std_ulogic;
    clk0      : in  std_ulogic;
    clk90     : in  std_ulogic;
    clk180    : in  std_ulogic;
    clk270    : in  std_ulogic;
    hclk1     : in  std_ulogic;
    hclk2     : in  std_ulogic;
    pclk      : in  std_ulogic;
    ahb1si    : in  ahb_slv_in_type;
    ahb1so    : out ahb_slv_out_type;
    ahb2si    : in  ahb_slv_in_type;
    ahb2so    : out ahb_slv_out_type;
    apbsi     : in  apb_slv_in_type;
    apbso     : out apb_slv_out_type;
--    dapbso    : out apb_slv_out_type;
    ddsi      : out ddrmem_in_type;
    ddso      : in  ddrmem_out_type);
end component;

component ftsrctrl_v1
  generic (
      hindex:                 Integer := 1;
      romaddr:                Integer := 16#000#;
      rommask:                Integer := 16#ff0#;
      ramaddr:                Integer := 16#400#;
      rammask:                Integer := 16#ff0#;
      ioaddr:                 Integer := 16#200#;
      iomask:                 Integer := 16#ff0#;
      ramws:                  Integer := 0;
      romws:                  Integer := 0;
      iows:                   Integer := 0;
      rmw:                    Integer := 1;
      srbanks:                Integer range 1 to 8  := 8;
      banksz:                 Integer range 0 to 13 := 0;
      rombanks:               Integer range 1 to 8  := 8;
      rombanksz:              Integer range 0 to 13 := 0;
      rombankszdef:           Integer range 0 to 13 := 6;
      romasel:                Integer range 0 to 28 := 0;
      pindex:                 Integer := 0;
      paddr:                  Integer := 16#000#;
      pmask:                  Integer := 16#fff#;
      edacen:                 Integer range 0 to 1 := 1;
      errcnt:                 Integer range 0 to 1 := 0;
      cntbits:                Integer range 1 to 8 := 1;
      wsreg:                  Integer := 1;
      oepol:                  Integer := 0);
  port (
    rst    : in  std_ulogic;
    clk    : in  std_ulogic;
    ahbsi  : in  ahb_slv_in_type;
    ahbso  : out ahb_slv_out_type;
    apbi   : in  apb_slv_in_type;
    apbo   : out apb_slv_out_type;
    sri    : in  memory_in_type;
    sro    : out memory_out_type;
    sdo    : out sdctrl_out_type
  );
end component;

component ddrsp
  generic (
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#f00#;
    ioaddr  : integer := 16#000#;
    iomask  : integer := 16#fff#;
    MHz     : integer := 100;
    col     : integer := 9; 
    Mbit    : integer := 256; 
    fast    : integer := 0; 
    pwron   : integer := 0;
    oepol   : integer := 0
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    sdi     : in  sdctrl_in_type;
    sdo     : out sdctrl_out_type
  );
end component; 

component ddrsp64a
  generic (
    memtech : integer := 0;
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#f00#;
    ioaddr  : integer := 16#000#;
    iomask  : integer := 16#fff#;
    MHz     : integer := 100;
    col     : integer := 9; 
    Mbyte   : integer := 16; 
    fast    : integer := 0; 
    pwron   : integer := 0;
    oepol   : integer := 0;
    mobile  : integer := 0;
    confapi : integer := 0;
    conf0   : integer := 0;
    conf1   : integer := 0;
    regoutput : integer := 0
  );
  port (
    rst     : in  std_ulogic;
    clk_ddr : in  std_ulogic;
    clk_ahb : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    sdi     : in  sdctrl_in_type;
    sdo     : out sdctrl_out_type
  );
end component;

component ddrsp32a 
  generic (
    memtech : integer := 0;
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#f00#;
    ioaddr  : integer := 16#000#;
    iomask  : integer := 16#fff#;
    MHz     : integer := 100;
    col     : integer := 9; 
    Mbyte   : integer := 16; 
    fast    : integer := 0; 
    pwron   : integer := 0;
    oepol   : integer := 0;
    mobile  : integer := 0;
    confapi : integer := 0;
    conf0   : integer := 0;
    conf1   : integer := 0;
    regoutput : integer := 0
  );
  port (
    rst     : in  std_ulogic;
    clk_ddr : in  std_ulogic;
    clk_ahb : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    sdi     : in  sdctrl_in_type;
    sdo     : out sdctrl_out_type
  );
end component; 

component ddrsp16a 
  generic (
    memtech : integer := 0;
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#f00#;
    ioaddr  : integer := 16#000#;
    iomask  : integer := 16#fff#;
    MHz     : integer := 100;
    col     : integer := 9; 
    Mbyte   : integer := 16; 
    fast    : integer := 0; 
    pwron   : integer := 0;
    oepol   : integer := 0;
    mobile  : integer := 0;
    confapi : integer := 0;
    conf0   : integer := 0;
    conf1   : integer := 0;
    regoutput : integer := 0
  );
  port (
    rst     : in  std_ulogic;
    clk_ddr : in  std_ulogic;
    clk_ahb : in  std_ulogic;
    clkread : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    sdi     : in  sdctrl_in_type;
    sdo     : out sdctrl_out_type
  );
end component; 
  
  component ddrspa
  generic (
    fabtech : integer := 0;
    memtech : integer := 0;
    rskew   : integer := 0;
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#f00#;
    ioaddr  : integer := 16#000#;
    iomask  : integer := 16#fff#;
    MHz     : integer := 100;
    clkmul  : integer := 2; 
    clkdiv  : integer := 2; 
    col     : integer := 9; 
    Mbyte   : integer := 16; 
    rstdel  : integer := 200; 
    pwron   : integer := 0;
    oepol   : integer := 0;
    ddrbits : integer := 16;
    ahbfreq : integer := 50;
    mobile  : integer := 0;
    confapi : integer := 0;
    conf0   : integer := 0;
    conf1   : integer := 0;
    regoutput : integer  range 0 to 1 := 0
  );
  port (
    rst_ddr : in  std_ulogic;
    rst_ahb : in  std_ulogic;
    clk_ddr : in  std_ulogic;
    clk_ahb : in  std_ulogic;
    lock    : out std_ulogic;			-- DCM locked
    clkddro : out std_ulogic;			-- DCM locked
    clkddri : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    ddr_clk 	: out std_logic_vector(2 downto 0);
    ddr_clkb	: out std_logic_vector(2 downto 0);
    ddr_clk_fb_out  : out std_logic;
    ddr_clk_fb  : in std_logic;
    ddr_cke  	: out std_logic_vector(1 downto 0);
    ddr_csb  	: out std_logic_vector(1 downto 0);
    ddr_web  	: out std_ulogic;                       -- ddr write enable
    ddr_rasb  	: out std_ulogic;                       -- ddr ras
    ddr_casb  	: out std_ulogic;                       -- ddr cas
    ddr_dm   	: out std_logic_vector (ddrbits/8-1 downto 0);    -- ddr dm
    ddr_dqs  	: inout std_logic_vector (ddrbits/8-1 downto 0);    -- ddr dqs
    ddr_ad      : out std_logic_vector (13 downto 0);   -- ddr address
    ddr_ba      : out std_logic_vector (1 downto 0);    -- ddr bank address
    ddr_dq    	: inout  std_logic_vector (ddrbits-1 downto 0) -- ddr data

  );
  end component; 

component ddr2buf is
  generic (tech : integer := 0; wabits : integer := 6; wdbits : integer := 8;
  rabits : integer := 6; rdbits : integer := 8;
  sepclk : integer := 0; wrfst : integer := 0; testen : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((rabits -1) downto 0);
    dataout  : out std_logic_vector((rdbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    writebig : in std_ulogic;
    waddress : in std_logic_vector((wabits -1) downto 0);
    datain   : in std_logic_vector((wdbits -1) downto 0);
    testin   : in std_logic_vector(3 downto 0) := "0000");
end component;

type ddr_request_type is record
  startaddr : std_logic_vector(31 downto 0);
  endaddr   : std_logic_vector(9 downto 0);
  hsize     : std_logic_vector(2 downto 0);
  hwrite    : std_ulogic;
  hio       : std_ulogic;
  maskdata  : std_ulogic;
  maskcb    : std_ulogic;
end record;

component ddr2spax_ahb is
   generic (
      hindex     : integer := 0;
      haddr      : integer := 0;
      hmask      : integer := 16#f00#;
      ioaddr     : integer := 16#000#;
      iomask     : integer := 16#fff#;
      burstlen   : integer := 8;
      nosync     : integer := 0;
      ahbbits    : integer := ahbdw
   );
   port (
      rst       : in  std_ulogic;
      clk_ahb   : in  std_ulogic;
      ahbsi     : in  ahb_slv_in_type;
      ahbso     : out ahb_slv_out_type;
      request   : out ddr_request_type;
      start_tog : out std_logic;
      done_tog  : in std_logic;
      wbwaddr   : out std_logic_vector(log2(burstlen) downto 0);
      wbwdata   : out std_logic_vector(ahbdw-1 downto 0);
      wbwrite   : out std_logic;
      wbwritebig: out std_logic;
      rbraddr   : out std_logic_vector(log2(burstlen*32/ahbdw)-1 downto 0);
      rbrdata   : in std_logic_vector(ahbdw-1 downto 0)
   );  
end component;

component ft_ddr2spax_ahb is
   generic (
      hindex     : integer := 0;
      haddr      : integer := 0;
      hmask      : integer := 16#f00#;
      ioaddr     : integer := 16#000#;
      iomask     : integer := 16#fff#;
      burstlen   : integer := 8;
      nosync     : integer := 0;
      ahbbits    : integer := 64;
      bufbits    : integer := 96;
      ddrbits    : integer := 16;
      hwidthen   : integer := 0
   );
   port (
      rst       : in  std_ulogic;
      clk_ahb   : in  std_ulogic;
      ahbsi     : in  ahb_slv_in_type;
      ahbso     : out ahb_slv_out_type;
      ce        : out std_logic;
      request   : out ddr_request_type;
      start_tog : out std_logic;
      done_tog  : in std_logic;
      wbwaddr   : out std_logic_vector(log2(burstlen)-2 downto 0);
      wbwdata   : out std_logic_vector(bufbits-1 downto 0);
      wbwrite   : out std_logic;
      wbwritebig: out std_logic;
      rbraddr   : out std_logic_vector(log2(burstlen*32/ahbbits)-1 downto 0);
      rbrdata   : in std_logic_vector(bufbits-1 downto 0);
      hwidth    : in std_logic
   );  
end component;

component ddr2spax_ddr is
   generic (
      ddrbits    : integer := 32;
      burstlen   : integer := 8;
      MHz        : integer := 100;
      TRFC       : integer := 130;
      col        : integer := 9;
      Mbyte      : integer := 8;
      fastahb    : integer := 0;
      pwron      : integer := 0;
      oepol      : integer := 0;
      readdly    : integer := 1;
      odten      : integer := 0;
      octen      : integer := 0;
      dqsgating  : integer := 0;
      nosync     : integer := 0;
      eightbanks : integer range 0 to 1 := 0; -- Set to 1 if 8 banks instead of 4
      dqsse      : integer range 0 to 1 := 0;  -- single ended DQS
      ddr_syncrst: integer range 0 to 1 := 0;
      chkbits    : integer := 0;
      bigmem     : integer range 0 to 1 := 0;
      raspipe    : integer range 0 to 1 := 0;
      hwidthen   : integer range 0 to 1 := 0
   );
   port (
      ddr_rst  : in  std_ulogic;
      clk_ddr  : in  std_ulogic;
      request  : in ddr_request_type;
      start_tog: in std_logic;
      done_tog : out std_logic;
      sdi      : in  sdctrl_in_type;
      sdo      : out sdctrl_out_type;
      wbraddr  : out std_logic_vector(log2((16*burstlen)/ddrbits) downto 0);
      wbrdata  : in std_logic_vector(2*(ddrbits+chkbits)-1 downto 0);
      rbwaddr  : out std_logic_vector(log2((16*burstlen)/ddrbits)-1 downto 0);
      rbwdata  : out std_logic_vector(2*(ddrbits+chkbits)-1 downto 0);
      rbwrite  : out std_logic;
      hwidth   : in std_ulogic
   );  
end component;

component ddr2spax is
   generic (
      memtech    : integer := 0;
      hindex     : integer := 0;
      haddr      : integer := 0;
      hmask      : integer := 16#f00#;
      ioaddr     : integer := 16#000#;
      iomask     : integer := 16#fff#;
      ddrbits    : integer := 32;
      burstlen   : integer := 8;
      MHz        : integer := 100;
      TRFC       : integer := 130;
      col        : integer := 9;
      Mbyte      : integer := 8;
      fastahb    : integer := 0;
      pwron      : integer := 0;
      oepol      : integer := 0;
      readdly    : integer := 1;
      odten      : integer := 0;
      octen      : integer := 0;
      dqsgating  : integer := 0;
      nosync     : integer := 0;
      eightbanks : integer range 0 to 1 := 0; -- Set to 1 if 8 banks instead of 4
      dqsse      : integer range 0 to 1 := 0;  -- single ended DQS
      ddr_syncrst: integer range 0 to 1 := 0;
      ahbbits    : integer := ahbdw;
      ft         : integer range 0 to 1 := 0;
      bigmem     : integer range 0 to 1 := 0;
      raspipe    : integer range 0 to 1 := 0;
      hwidthen   : integer range 0 to 1 := 0
   );
   port (
      ddr_rst : in  std_ulogic;
      ahb_rst : in  std_ulogic;
      clk_ddr : in  std_ulogic;
      clk_ahb : in  std_ulogic;
      ahbsi   : in  ahb_slv_in_type;
      ahbso   : out ahb_slv_out_type;
      sdi     : in  sdctrl_in_type;
      sdo     : out sdctrl_out_type;
      hwidth  : in  std_ulogic
   );  
end component;

component ddr2spa
  generic (
    fabtech : integer := 0;
    memtech : integer := 0;
    rskew   : integer := 0;
    hindex  : integer := 0;
    haddr   : integer := 0;
    hmask   : integer := 16#f00#;
    ioaddr  : integer := 16#000#;
    iomask  : integer := 16#fff#;
    MHz     : integer := 100;
    TRFC    : integer := 130;
    clkmul  : integer := 2; 
    clkdiv  : integer := 2; 
    col     : integer := 9; 
    Mbyte   : integer := 16; 
    rstdel  : integer := 200; 
    pwron   : integer := 0;
    oepol   : integer := 0;
    ddrbits : integer := 16;
    ahbfreq : integer := 50;
    readdly : integer := 1;
    ddelayb0 : integer := 0;
    ddelayb1 : integer := 0;
    ddelayb2 : integer := 0;
    ddelayb3 : integer := 0;
    ddelayb4 : integer := 0;
    ddelayb5 : integer := 0;
    ddelayb6 : integer := 0;
    ddelayb7 : integer := 0;
    cbdelayb0 : integer := 0;
    cbdelayb1 : integer := 0;
    cbdelayb2 : integer := 0;
    cbdelayb3 : integer := 0;
    numidelctrl : integer := 4; 
    norefclk : integer := 0;
    odten    : integer := 0;
    octen    : integer := 0;
    dqsgating : integer := 0;
    nosync    : integer := 0;
    eightbanks : integer := 0;
    dqsse      : integer range 0 to 1 := 0;
    burstlen : integer range 4 to 128 := 8;
    ahbbits    : integer := ahbdw;
    ft : integer range 0 to 1 := 0;
    ftbits : integer := 0;
    bigmem : integer range 0 to 1 := 0;
    raspipe : integer range 0 to 1 := 0
  );
  port (
    rst_ddr    : in  std_ulogic;
    rst_ahb    : in  std_ulogic;
    clk_ddr    : in  std_ulogic;
    clk_ahb    : in  std_ulogic;
    clkref200  : in  std_ulogic;
    lock       : out std_ulogic;			-- DCM locked
    clkddro    : out std_ulogic;			-- DCM locked
    clkddri    : in  std_ulogic;
    ahbsi      : in  ahb_slv_in_type;
    ahbso      : out ahb_slv_out_type;
    ddr_clk 	: out std_logic_vector(2 downto 0);
    ddr_clkb	: out std_logic_vector(2 downto 0);
    ddr_clk_fb_out  : out std_logic;
    ddr_clk_fb  : in std_logic;
    ddr_cke  	: out std_logic_vector(1 downto 0);
    ddr_csb  	: out std_logic_vector(1 downto 0);
    ddr_web  	: out std_ulogic;                       -- ddr write enable
    ddr_rasb  	: out std_ulogic;                       -- ddr ras
    ddr_casb  	: out std_ulogic;                       -- ddr cas
    ddr_dm   	: out std_logic_vector ((ddrbits+ftbits)/8-1 downto 0);   -- ddr dm
    ddr_dqs  	: inout std_logic_vector ((ddrbits+ftbits)/8-1 downto 0); -- ddr dqs
    ddr_dqsn  	: inout std_logic_vector ((ddrbits+ftbits)/8-1 downto 0); -- ddr dqsn
    ddr_ad      : out std_logic_vector (13 downto 0);                     -- ddr address
    ddr_ba      : out std_logic_vector (1+eightbanks downto 0);           -- ddr bank address
    ddr_dq    	: inout  std_logic_vector (ddrbits+ftbits-1 downto 0);    -- ddr data
    ddr_odt	: out std_logic_vector(1 downto 0);
    ce          : out std_logic
  );
  end component; 
  
  component ddrphy_wrap
  generic (tech : integer := virtex2; MHz : integer := 100; 
	rstdelay : integer := 200; dbits : integer := 16; 
	clk_mul : integer := 2 ; clk_div : integer := 2;
	rskew : integer := 0; mobile : integer := 0);
  port (
    rst       : in  std_ulogic;
    clk       : in  std_logic;          	-- input clock
    clkout    : out std_ulogic;			-- system clock
    clkread   : out std_ulogic;			-- system clock
    lock      : out std_ulogic;			-- DCM locked
    ddr_clk 	: out std_logic_vector(2 downto 0);
    ddr_clkb	: out std_logic_vector(2 downto 0);
    ddr_clk_fb_out  : out std_logic;
    ddr_clk_fb  : in std_logic;
    ddr_cke  	: out std_logic_vector(1 downto 0);
    ddr_csb  	: out std_logic_vector(1 downto 0);
    ddr_web  	: out std_ulogic;                       -- ddr write enable
    ddr_rasb  	: out std_ulogic;                       -- ddr ras
    ddr_casb  	: out std_ulogic;                       -- ddr cas
    ddr_dm   	: out std_logic_vector (dbits/8-1 downto 0);    -- ddr dm
    ddr_dqs  	: inout std_logic_vector (dbits/8-1 downto 0);    -- ddr dqs
    ddr_ad      : out std_logic_vector (13 downto 0);   -- ddr address
    ddr_ba      : out std_logic_vector (1 downto 0);    -- ddr bank address
    ddr_dq    	: inout  std_logic_vector (dbits-1 downto 0); -- ddr data
 
    sdi         : out sdctrl_in_type;
    sdo         : in  sdctrl_out_type);
  end component;

  component ddr2phy_wrap
    generic (
      tech        : integer := virtex2;    MHz      : integer := 100;
      rstdelay    : integer := 200;        dbits    : integer := 16;    padbits  : integer := 0;
      clk_mul     : integer := 2;          clk_div  : integer := 2;
      ddelayb0    : integer := 0;          ddelayb1 : integer := 0;     ddelayb2 : integer := 0;
      ddelayb3    : integer := 0;          ddelayb4 : integer := 0;     ddelayb5 : integer := 0;
      ddelayb6    : integer := 0;          ddelayb7 : integer := 0;
      cbdelayb0   : integer := 0;          cbdelayb1: integer := 0;     cbdelayb2: integer := 0;
      cbdelayb3   : integer := 0;
      numidelctrl : integer := 4;          norefclk : integer := 0;     rskew    : integer := 0;
      eightbanks  : integer range 0 to 1 := 0; dqsse : integer range 0 to 1 := 0;
      abits       : integer := 14;         nclk     : integer := 3;     ncs      : integer := 2;
      cben        : integer := 0;          chkbits  : integer := 8;     ctrl2en  : integer := 0);
    port (
      rst            : in    std_ulogic;
      clk            : in    std_logic;   -- input clock
      clkref200      : in    std_logic;   -- input 200MHz clock
      clkout         : out   std_ulogic;  -- system clock
      lock           : out   std_ulogic;  -- DCM locked

      ddr_clk        : out   std_logic_vector(nclk-1 downto 0);
      ddr_clkb       : out   std_logic_vector(nclk-1 downto 0);
      ddr_clk_fb_out : out   std_logic;
      ddr_clk_fb     : in    std_logic;
      ddr_cke        : out   std_logic_vector(ncs-1 downto 0);
      ddr_csb        : out   std_logic_vector(ncs-1 downto 0);
      ddr_web        : out   std_ulogic;                               -- ddr write enable
      ddr_rasb       : out   std_ulogic;                               -- ddr ras
      ddr_casb       : out   std_ulogic;                               -- ddr cas
      ddr_dm         : out   std_logic_vector ((dbits+padbits)/8-1 downto 0);    -- ddr dm
      ddr_dqs        : inout std_logic_vector ((dbits+padbits)/8-1 downto 0);    -- ddr dqs
      ddr_dqsn       : inout std_logic_vector ((dbits+padbits)/8-1 downto 0);    -- ddr dqs
      ddr_ad         : out   std_logic_vector (abits-1 downto 0);           -- ddr address
      ddr_ba         : out   std_logic_vector (1+eightbanks downto 0); -- ddr bank address
      ddr_dq         : inout std_logic_vector (dbits+padbits-1 downto 0);      -- ddr data
      ddr_odt        : out   std_logic_vector(ncs-1 downto 0);
      ddr_cbdm       : out   std_logic_vector(chkbits/8-1 downto 0);
      ddr_cbdqs      : inout std_logic_vector(chkbits/8-1 downto 0);
      ddr_cbdqsn     : inout std_logic_vector(chkbits/8-1 downto 0);
      ddr_cbdq       : inout std_logic_vector(chkbits-1 downto 0);
      ddr_web2       : out   std_ulogic;                               -- ddr write enable
      ddr_rasb2      : out   std_ulogic;                               -- ddr ras
      ddr_casb2      : out   std_ulogic;                               -- ddr cas
      ddr_ad2        : out   std_logic_vector (abits-1 downto 0);      -- ddr address
      ddr_ba2        : out   std_logic_vector (1+eightbanks downto 0); -- ddr bank address
      
      sdi            : out   sdctrl_in_type;
      sdo            : in    sdctrl_out_type
      );
  end component;

  component ddr2phy_wrap_cbd is
    generic (tech     : integer := virtex2; MHz        : integer := 100; 
    rstdelay    : integer := 200;     dbits      : integer := 16;  padbits  : integer := 0;
    clk_mul     : integer := 2 ;      clk_div    : integer := 2;
    ddelayb0    : integer := 0;       ddelayb1   : integer := 0;   ddelayb2 : integer := 0;
    ddelayb3    : integer := 0;       ddelayb4   : integer := 0;   ddelayb5 : integer := 0;
    ddelayb6    : integer := 0;       ddelayb7   : integer := 0;
    cbdelayb0   : integer := 0;       cbdelayb1: integer := 0;     cbdelayb2: integer := 0;
    cbdelayb3   : integer := 0;
    numidelctrl : integer := 4;       norefclk   : integer := 0;   odten    : integer := 0;
    rskew       : integer := 0;       eightbanks : integer range 0 to 1 := 0;
    dqsse       : integer range 0 to 1 := 0;
    abits       : integer := 14;      nclk     : integer := 3;     ncs      : integer := 2;
    chkbits  : integer := 0;          ctrl2en  : integer := 0);
    port (
      rst            : in    std_ulogic;
      clk            : in    std_logic;   -- input clock
      clkref200      : in    std_logic;   -- input 200MHz clock
      clkout         : out   std_ulogic;  -- system clock
      lock           : out   std_ulogic;  -- DCM locked

      ddr_clk        : out   std_logic_vector(nclk-1 downto 0);
      ddr_clkb       : out   std_logic_vector(nclk-1 downto 0);
      ddr_clk_fb_out : out   std_logic;
      ddr_clk_fb     : in    std_logic;
      ddr_cke        : out   std_logic_vector(ncs-1 downto 0);
      ddr_csb        : out   std_logic_vector(ncs-1 downto 0);
      ddr_web        : out   std_ulogic;                               -- ddr write enable
      ddr_rasb       : out   std_ulogic;                               -- ddr ras
      ddr_casb       : out   std_ulogic;                               -- ddr cas
      ddr_dm         : out   std_logic_vector ((dbits+padbits+chkbits)/8-1 downto 0);    -- ddr dm
      ddr_dqs        : inout std_logic_vector ((dbits+padbits+chkbits)/8-1 downto 0);    -- ddr dqs
      ddr_dqsn       : inout std_logic_vector ((dbits+padbits+chkbits)/8-1 downto 0);    -- ddr dqs
      ddr_ad         : out   std_logic_vector (abits-1 downto 0);           -- ddr address
      ddr_ba         : out   std_logic_vector (1+eightbanks downto 0); -- ddr bank address
      ddr_dq         : inout std_logic_vector (dbits+padbits+chkbits-1 downto 0);      -- ddr data
      ddr_odt        : out   std_logic_vector(ncs-1 downto 0);
      
      ddr_web2       : out   std_ulogic;                               -- ddr write enable
      ddr_rasb2      : out   std_ulogic;                               -- ddr ras
      ddr_casb2      : out   std_ulogic;                               -- ddr cas
      ddr_ad2        : out   std_logic_vector (abits-1 downto 0);      -- ddr address
      ddr_ba2        : out   std_logic_vector (1+eightbanks downto 0); -- ddr bank address
      
      sdi            : out   sdctrl_in_type;
      sdo            : in    sdctrl_out_type
      );
  end component;
  
  component ftsrctrl8 is
  generic (
    hindex       : integer := 0;
    ramaddr      : integer := 16#400#;
    rammask      : integer := 16#ff0#;
    ioaddr       : integer := 16#200#;
    iomask       : integer := 16#ff0#;
    ramws        : integer := 0;
    iows         : integer := 2;
    srbanks      : integer range 1 to 8  := 1;
    banksz       : integer range 0 to 15 := 15;
    pindex       : integer := 0;
    paddr        : integer := 0;
    pmask        : integer := 16#fff#;
    edacen       : integer range 0 to 1 := 1;
    errcnt       : integer range 0 to 1 := 1;   
    cntbits      : integer range 1 to 8 := 1;
    wsreg        : integer := 0;
    oepol        : integer := 0
    
  );
  port (
    rst          : in  std_ulogic;
    clk          : in  std_ulogic;
    ahbsi        : in  ahb_slv_in_type;
    ahbso        : out ahb_slv_out_type;
    apbi         : in  apb_slv_in_type;
    apbo         : out apb_slv_out_type;
    sri          : in  memory_in_type;
    sro          : out memory_out_type
  );
  end component; 

  type spimctrl_in_type is record
    miso        : std_ulogic;
    mosi        : std_ulogic;
    cd          : std_ulogic;
  end record;

  type spimctrl_out_type is record
    mosi        : std_ulogic;
    mosioen     : std_ulogic;
    sck         : std_ulogic;
    csn         : std_ulogic;
    cdcsnoen    : std_ulogic;
    errorn      : std_ulogic;
    ready       : std_ulogic;
    initialized : std_ulogic;
  end record;

  component spimctrl
    generic (
      hindex      : integer := 0;
      hirq        : integer := 0;
      faddr       : integer := 16#000#;
      fmask       : integer := 16#fff#;
      ioaddr      : integer := 16#000#;
      iomask      : integer := 16#fff#;
      spliten     : integer := 0;
      oepol       : integer := 0;
      sdcard      : integer range 0 to 1   := 0;
      readcmd     : integer range 0 to 255 := 16#0B#;
      dummybyte   : integer range 0 to 1   := 1;
      dualoutput  : integer range 0 to 1   := 0;
      scaler      : integer range 1 to 512 := 1;
      altscaler   : integer range 1 to 512 := 1;
      pwrupcnt    : integer := 0;
      maxahbaccsz : integer range 0 to 256 := AHBDW
      );
    port (
      rstn    : in  std_ulogic;
      clk     : in  std_ulogic;
      ahbsi   : in  ahb_slv_in_type;
      ahbso   : out ahb_slv_out_type;
      spii    : in  spimctrl_in_type;
      spio    : out spimctrl_out_type
    );
  end component;

end;
