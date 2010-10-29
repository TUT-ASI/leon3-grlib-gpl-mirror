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
-------------------------------------------------------------------------------
-- Package:     at_pkg
-- File:        at_pkg.vhd
-- Author:      Jan Andersson, Aeroflex Gaisler
--              Marko Isomaki, Aeroflex Gaisler
-- Description: AMBA Test Framework - Main package
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.testlib.all;

package at_pkg is

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------

  -- Ranges
  subtype ADDR_R is natural range 31 downto 0;
  subtype DATA_R is natural range (AHBDW-1) downto 0;
  subtype BANK_R is natural range 0 to 3;
  subtype SIZE_R is natural range 2 downto 0;
  subtype BEAT_R is natural range 1 downto 0;

  -- constants for HBURST definition (used with at_mst_in_type.Beat)
  constant HINCR:      Std_Logic_Vector(BEAT_R) := "00";
  constant HINCR4:     Std_Logic_Vector(BEAT_R) := "01";
  constant HINCR8:     Std_Logic_Vector(BEAT_R) := "10";
  constant HINCR16:    Std_Logic_Vector(BEAT_R) := "11";

  -- Config for AHB Slave model generics
  constant AT_AHBSLV_MEM          : integer := 0;
  constant AT_AHBSLV_IO           : integer := 1;
  constant AT_AHBSLV_FIXED_WS     : integer := 0;
  constant AT_AHBSLV_RANDOM_WS    : integer := 1;

  -- Accesses to the AHB slave's debug port are not clocked and rely on a
  -- handshake protocol. To prevent the simulator's delta limit from being
  -- reached, the slave has a counter that keeps track of how many accesses
  -- that has been made while simulation time has not progressed. If
  -- SLAVE_DELTA_LIMIT the slave will wait 1 ps before continuing.
  constant SLAVE_DELTA_LIMIT : integer := 1024;
  
  -----------------------------------------------------------------------------
  -- Constants for comparison
  -----------------------------------------------------------------------------
  constant DontCare32:    Std_Logic_Vector(31 downto 0) := (others => '-');
  constant DontCare24:    Std_Logic_Vector(23 downto 0) := (others => '-');
  constant DontCare16:    Std_Logic_Vector(15 downto 0) := (others => '-');
  constant DontCare8:     Std_Logic_Vector( 7 downto 0) := (others => '-');

  ----------------------------------------------------------------------------
  -- Constant for calculating burst lengths
  ----------------------------------------------------------------------------
  constant WordSize: integer := 32;
   
  -----------------------------------------------------------------------------
  -- Types for AHB master
  -----------------------------------------------------------------------------

--AHB master operation type
--------------------------------------------------------------------------------
--     id           use to keep track of the access. Finished operations can be 
--                  collected out of order
--     address      ahb address used for the access
--     data         must contain write data for write accesses. Read data is 
--                  returned here for read accesses
--     burst        
--     first        first access in a burst. only used if burst is true. 
--     beat:        burst length, 1=unspec length, 4, 8, 16 beats
--     wrap:        wrapping or incrementing
--     size:        byte=8, hw=16, w=32
--     store:       write=true, read=false
--     lock:        request locked transfer
--     prot:        sets the hprot field
--     wait_start:  number of cycles to wait after previous
--                  op until current is started. not applicable in
--                  middle of burst and when back2back
--     back2back:   start address phase during data phase of prev
--                  transfer
--     response:    ahb response for the final access. This means it can only be
--                  an error or okay response. returned with the op when the
--                  access has finished
--     retries:     contains the number of retry reponses received for the access
--     splits:      contains the number of split reponses received for the access
--     compare:     do comparison of returned data and response. Error output
--                  will be asserted if an error is detected
--     cmpdata:     expected data used for comparison (only applicable for reads)
--     erresp:      error response or ok response expected
--     split:       split allowed for this access (error is asserted if this is
--                  false and a split is received
--     retry:       retry allowed for this access (error is asserted if this is
--                  false and a retry is received
--     dbglevel:    enables different levels of debug printouts
--     discard:     when true do not move the operation to the finished queue. 
--                  Instead it is thrown away.

 
  type at_ahb_mst_op_type is record
    id:          integer;
    address:     std_logic_vector(ADDR_R);  
    data:        std_logic_vector(DATA_R);  
    burst:       boolean; 
    first:       boolean; 
    beat:        integer; 
    wrap:        boolean; 
    size:        integer; 
    store:       boolean; 
    lock:        boolean; 
    prot:        std_logic_vector(3 downto 0); 
    wait_start:  integer; 
    back2back:   boolean; 
    response:    std_logic_vector(1 downto 0);
    retries:     integer;
    splits:      integer;
    compare:     boolean;
    cmpdata:     std_logic_vector(DATA_R);
    erresp:      boolean;
    split:       boolean;
    retry:       boolean;
    dbglevel:    integer;
    discard:     boolean;
  end record;

--AHB master input type
--------------------------------------------------------------------------------
--     add          should initially be '0'. A rising_edge will add a new op to
--                  the queue. Should return to '0' when a rising edge has been
--                  detected on addack in the master output record. A new rising
--                  edge should not be driven until addack has returned to '0'.
--     op           operation that will be added to the queue using add
--     get          should initially be '0'. A rising_edge will fetch an
--                  operation from the list of finished accessed. Should return
--                  to '0' when a rising edge has been detected on getack in the
--                  master output record. A new rising edge should not be driven
--                  until getack has returned to '0'.
--     useid        if '1' use the id field in this record to specify the 
--                  operation to be fetched 
--     id           identification number of the access that should be fetched
--                  with get if useid is '1'.

  type at_ahb_mst_in_type is record
    add:         std_ulogic;
    op:          at_ahb_mst_op_type;
    get:         std_ulogic;
    useid:       std_ulogic;
    id:          integer;                                 
  end record;

--AHB master output type
--------------------------------------------------------------------------------
--     addack       Is initially '0'. A rising_edge will occur following a
--                  rising_edge on add when an operation is ready. Returns
--                  to '0' after add returns to '0'.
--     id           id number assigned to the latesto peration added to the
--                  queue.
--     getack       Is initially '0'. A rising_edge will occur following a
--                  rising_edge on get when an operation is ready. Returns
--                  to '0' after get returns to '0'.
--     rdy          Is set to '1' when getack is '1' and the requested operation
--                  is ready. Otherwise it is '0'.
--     fin          A rising_edge occurs on this signal each time an operation
--                  is added to the finished list
--     op           the operation fetched from the ready list using get.
--                  valid when getack is '1'.
--     error        Set to '1' when an error has been detected in the internal
--                  checks. 

  type at_ahb_mst_out_type is record
    addack:      std_ulogic;
    id:          integer;
    getack:      std_ulogic;
    rdy:         std_ulogic;
    fin:         std_ulogic;
    op:          at_ahb_mst_op_type;
    error:       std_ulogic;
  end record;

  type at_ahb_mst_in_vector is array (natural range <>) of at_ahb_mst_in_type;
  type at_ahb_mst_out_vector is array (natural range <>) of at_ahb_mst_out_type;
   
  -----------------------------------------------------------------------------
  -- Types for AHB slave
  -----------------------------------------------------------------------------
  
  type dbg_access_type is (d, ri, rc, ru, rr, rar, c);
  
  type slv_resp_type is record
    data      : std_logic_vector(DATA_R);
    resp      : std_logic_vector(1 downto 0);
    ws        : integer;        -- Wait states
    lock      : boolean;        -- Insert wait states until slave is instructed to abort
    repeat    : integer;        -- # times to repeat response
    splitcnt  : integer;        -- # of cycles to wait before unsplit
  end record;
  
  type at_slv_resp_type is record
    addr1    : std_logic_vector(ADDR_R);     -- Address range start
    addr2    : std_logic_vector(ADDR_R);     -- Address range stop
    read     : boolean;                      -- Response is valid for read
    write    : boolean;                      -- Response is valid for write
    accmem   : boolean;                      -- Access memory array
    resp     : slv_resp_type;                -- See above
    count    : integer;                      -- # accesses that response is valid
    anymst   : boolean;                      -- Response is valid for any master
    mst      : integer range 0 to NAHBMST-1; -- Master response is valid for
    delay    : integer;                      -- # accesses before response is valid
    anyhprot : boolean;                      -- Response is valid for any hprot
    hprot    : std_logic_vector(3 downto 0); -- HPROT response is valid for 
  end record;
  
  -- Debug port
  type at_slv_dbg_in_type is record
    req     : std_ulogic;                -- Request
    acc     : dbg_access_type;           -- Type of request 
    wr      : std_ulogic;                -- Write/Read
    addr    : std_logic_vector(ADDR_R);  -- Address
    data    : std_logic_vector(DATA_R);  -- Data
    bank    : std_logic_vector(BANK_R);  -- Bank 
    size    : std_logic_vector(SIZE_R);
    --
    id      : integer;                   -- Response ID
    resp    : at_slv_resp_type;          -- Customized response
    -- Default behavior and slave config
    ws      : integer;                   -- Waitstates
    rws     : integer;                   -- Randomize waitstates
    rsplit  : real;                      -- Probability of receiving random SPLIT responses
    rretry  : real;                      -- Probability of receiving random RETRY responses
    splcnt  : integer;                   -- Number of cycles before unsplit
    rsplcnt : integer;                   -- Randomize number of cycles before unsplit
    iactiv  : boolean;                   -- Interactive
    dbglvl  : integer;                   -- Debug print out level
    -- Interactive mode
    idflt   : boolean;                   -- Use default response
    iwdata  : boolean;                   -- Want data from data phase
    icompid : boolean;                   -- Update id on completion
    iack    : std_ulogic;
  end record;

  type at_slv_dbg_in_vec is array (natural range <>) of at_slv_dbg_in_type;
  
  type at_slv_dbg_out_type is record
    ack     : std_ulogic;                -- Acknowledge
    data    : std_logic_vector(DATA_R);  -- Read data
    --
    id      : integer;                   
    resp    : at_slv_resp_type;          -- Customized response
    -- Model characteristics
    ws      : integer;                   -- Waitstates
    rws     : integer;                   -- Randomize waitstates
    rsplit  : real;                      -- Probability of receiving random SPLIT responses
    rretry  : real;                      -- Probability of receiving random RETRY responses
    splcnt  : integer;                   -- Number of cycles before unsplit
    rsplcnt : integer;                   -- Randomize number of cycles before unsplit
    iactiv  : boolean;                   -- Interactive 
    dbglvl  : integer;                   -- Debug print out level
    -- Callback for completed responses
    compid  : integer;                   -- ID of completed response
    -- Interactive mode
    ireq    : std_ulogic;
    avalid  : std_ulogic;
    wr      : std_ulogic;              -- Write
    addr    : std_logic_vector(ADDR_R);
    bank    : std_logic_vector(BANK_R);
    size    : std_logic_vector(SIZE_R);
    mst     : integer range 0 to NAHBMST-1;
    trans   : std_logic_vector(1 downto 0);
    locked  : std_ulogic;
    -- Data phase transfer
    dvalid  : std_ulogic;
    waddr   : std_logic_vector(ADDR_R);
    wdata   : std_logic_vector(DATA_R);
    wbank   : std_logic_vector(BANK_R);
    wsize   : std_logic_vector(SIZE_R);
  end record;

  type at_slv_dbg_out_vec is array (natural range <>) of at_slv_dbg_out_type;
  
  -----------------------------------------------------------------------------
  -- Component declarations
  -----------------------------------------------------------------------------

  component at_ahb_mst is
    generic(
      hindex:        in    Integer := 0;
      vendorid:      in    Integer := 0;
      deviceid:      in    Integer := 0;
      version:       in    Integer := 0);
    port(
      -- AMBA AHB system signals
      hclk:          in    std_ulogic;
      hresetn:       in    std_ulogic;
       
      --AHB Interface
      ahbi:          in    ahb_mst_in_type;
      ahbo:          out   ahb_mst_out_type;

      --Operation Scheduling Interface
      atmi:          in  at_ahb_mst_in_type;
      atmo:          out at_ahb_mst_out_type
     );
   end component;

   component at_ahb_ctrl is
     generic (
       defmast     : integer := 0;		-- default master
       split       : integer := 0;		-- split support
       rrobin      : integer := 0;		-- round-robin arbitration
       timeout     : integer range 0 to 255 := 0;  -- HREADY timeout
       ioaddr      : ahb_addr_type := 16#fff#;  -- I/O area MSB address
       iomask      : ahb_addr_type := 16#fff#;  -- I/O area address mask
       cfgaddr     : ahb_addr_type := 16#ff0#;  -- config area MSB address
       cfgmask     : ahb_addr_type := 16#ff0#;  -- config area address mask
       nahbm       : integer range 1 to NAHBMST := NAHBMST; -- number of masters
       nahbs       : integer range 1 to NAHBSLV := NAHBSLV; -- number of slaves
       ioen        : integer range 0 to 15 := 1;    -- enable I/O area
       disirq      : integer range 0 to 1 := 0;     -- disable interrupt routing
       fixbrst     : integer range 0 to 1 := 0;     -- support fix-length bursts
       debug       : integer range 0 to 2 := 2;     -- report cores to console
       fpnpen      : integer range 0 to 1 := 0; -- full PnP configuration decoding
       icheck      : integer range 0 to 1 := 1;
       devid       : integer := 0;		     -- unique device ID
       enbusmon    : integer range 0 to 1 := 0; --enable bus monitor
       assertwarn  : integer range 0 to 1 := 0; --enable assertions for warnings 
       asserterr   : integer range 0 to 1 := 0; --enable assertions for errors
       hmstdisable : integer := 0; --disable master checks           
       hslvdisable : integer := 0; --disable slave checks
       arbdisable  : integer := 0; --disable arbiter checks
       mprio       : integer := 0; --master with highest priority
       mcheck      : integer := 1; --check memory map for intersects
       enebterm    : integer := 0; --enable early burst termination
       ebprob      : integer := 10; --probability of early bursttermination, lower value ->higher probability
       ccheck      : integer range 0 to 1 := 1;  --perform sanity checks on pnp config
       acdm        : integer := 0  --AMBA compliant data muxing (for hsize > word) 
       );
     port (
       rst     : in  std_ulogic;
       clk     : in  std_ulogic;
       msti    : out ahb_mst_in_type;
       msto    : in  ahb_mst_out_vector;
       slvi    : out ahb_slv_in_type;
       slvo    : in  ahb_slv_out_vector;
       testen  : in  std_ulogic := '0';
       testrst : in  std_ulogic := '1';
       scanen  : in  std_ulogic := '0';
       testoen : in  std_ulogic := '1';
       doarb   : in  std_ulogic := '0'
     );
   end component;

  component at_ahb_slv is
   generic (
     hindex        : integer := 0;       -- Slave index    
     bank0addr     : integer := 0;
     bank0mask     : integer := 0;
     bank0type     : integer := 0;       -- 0: memory area 1: I/O area
     bank0cache    : integer := 0;       -- Cachable
     bank0prefetch : integer := 0;       -- Prefetchable
     bank0ws       : integer := 0;       -- Waitstates
     bank0rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
     bank0dataload : integer := 0;       -- Load data from file
     bank0datafile : string  := "none";  -- Initial data for bank
     bank1addr     : integer := 0;
     bank1mask     : integer := 0;
     bank1type     : integer := 0;       -- 0: memory area 1: I/O area
     bank1cache    : integer := 0;       -- Cachable
     bank1prefetch : integer := 0;       -- Prefetchable
     bank1ws       : integer := 0;       -- Waitstates
     bank1rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
     bank1dataload : integer := 0;       -- Load data from file
     bank1datafile : string  := "none";  -- Initial data for bank
     bank2addr     : integer := 0;
     bank2mask     : integer := 0;
     bank2type     : integer := 0;       -- 0: memory area 1: I/O area
     bank2cache    : integer := 0;       -- Cachable
     bank2prefetch : integer := 0;       -- Prefetchable
     bank2ws       : integer := 0;       -- Waitstates
     bank2rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
     bank2dataload : integer := 0;       -- Load data from file
     bank2datafile : string  := "none";  -- Initial data for bank
     bank3addr     : integer := 0;
     bank3mask     : integer := 0;
     bank3type     : integer := 0;       -- 0: memory area 1: I/O area
     bank3cache    : integer := 0;       -- Cachable
     bank3prefetch : integer := 0;       -- Prefetchable
     bank3ws       : integer := 0;       -- Waitstates
     bank3rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
     bank3dataload : integer := 0;       -- Load data from file
     bank3datafile : string  := "none"   -- Initial data for bank
    );
   port (
     rstn  : in  std_ulogic;
     clk   : in  std_ulogic;
     ahbsi : in  ahb_slv_in_type;
     ahbso : out ahb_slv_out_type;
     dbgi  : in  at_slv_dbg_in_type;
     dbgo  : out at_slv_dbg_out_type
   );
  end component;

  component at_ahbs is
   generic (
     hindex        : integer := 0;       -- Slave index    
     bank0addr     : integer := 0;
     bank0mask     : integer := 0;
     bank0type     : integer := 0;       -- 0: memory area 1: I/O area
     bank0cache    : integer := 0;       -- Cachable
     bank0prefetch : integer := 0;       -- Prefetchable
     bank0ws       : integer := 0;       -- Waitstates
     bank0rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
     bank0dataload : integer := 0;       -- Load data from file
     bank0datafile : string  := "none";  -- Initial data for bank
     bank1addr     : integer := 0;
     bank1mask     : integer := 0;
     bank1type     : integer := 0;       -- 0: memory area 1: I/O area
     bank1cache    : integer := 0;       -- Cachable
     bank1prefetch : integer := 0;       -- Prefetchable
     bank1ws       : integer := 0;       -- Waitstates
     bank1rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
     bank1dataload : integer := 0;       -- Load data from file
     bank1datafile : string  := "none";  -- Initial data for bank
     bank2addr     : integer := 0;
     bank2mask     : integer := 0;
     bank2type     : integer := 0;       -- 0: memory area 1: I/O area
     bank2cache    : integer := 0;       -- Cachable
     bank2prefetch : integer := 0;       -- Prefetchable
     bank2ws       : integer := 0;       -- Waitstates
     bank2rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
     bank2dataload : integer := 0;       -- Load data from file
     bank2datafile : string  := "none";  -- Initial data for bank
     bank3addr     : integer := 0;
     bank3mask     : integer := 0;
     bank3type     : integer := 0;       -- 0: memory area 1: I/O area
     bank3cache    : integer := 0;       -- Cachable
     bank3prefetch : integer := 0;       -- Prefetchable
     bank3ws       : integer := 0;       -- Waitstates
     bank3rws      : integer := 0;       -- Random wait states 'ws' is the maxmimum
     bank3dataload : integer := 0;       -- Load data from file
     bank3datafile : string  := "none"   -- Initial data for bank
    );
   port (
     rstn  : in  std_ulogic;
     clk   : in  std_ulogic;
     ahbsi : in  ahb_slv_in_type;
     ahbso : out ahb_slv_out_type
   );
  end component;

  
  
end at_pkg;

  
