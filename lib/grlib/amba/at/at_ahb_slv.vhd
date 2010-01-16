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
-- Package:     at_ahb_slv
-- File:        at_ahb_slv.vhd
-- Author:      Jan Andersson, Aeroflex Gaisler
-- Description: AMBA Test Framework - AHB slave
-------------------------------------------------------------------------------
-- The ATF AHB slave has the following architecture:
--
--        +--------------------------------------+
--        |   +-----------+     +------------+   |
--  AHB <-+-> | AHB slave | <-> | Core proc. | <-+-> Debug
--        |   +-----------+     +------------+   |
--        +--------------------------------------+
--
-- [Overview]
-- 
-- The test slave is a memory model that can be configured to allow access to
-- up to four banks. Each bank can be configured to present it self as an
-- AHB memory bank or an AHB I/O bank with settings for cacheability,
-- prefetchability and default number of wait states. An SREC file containing
-- initial memory data for each bank can also be specified.
--
-- In normal operation the slave will use the default values and behave like
-- a normal memory accessed via AMBA AHB. The memory in the slave can also be
-- accessed via the debug port. The debug port does not depend on the system
-- clock and allows fast access to the slaves memory contents. The debug port
-- can also be used to insert special responses, such as ERROR, RETRY and SPLIT
-- with a configurable number of waitstates, for a specified address range.
--
-- [AHB accesses to the slave]
--  
-- When the AHB slave interface receives a request it checks if there is a
-- response queued for the request. If there is a response queued the core
-- will act accordingly to the response. It may issue an OK, SPLIT, RETRY or
-- ERROR response, with configurable waistates. The access may modify the
-- memory array if the 'accmem' member of the response has been set. If the
-- response is allowed to access the memory array the access will be made
-- regardless of the response type. Please see the arguments to the
-- ahbslv_response(..) procedure to see the full list of parameters for
-- customized responses.
--
-- If no response has been queued for the address (range) the core will respond
-- with OK and the default wait states setting. Both writes and reads will
-- access the models memory array.
--
-- The slave can also be put in an interactive mode where a testbench can see
-- and reply to accesses in real time. See the ahbslv_interactive_* procedures
-- in the ahb slave test package.
--
-- [Debug port accesses]
--
-- Debug port accesses are used for fast accesses to the slave's memory array,
-- for slave configuration and for insertion of customized responses.
--
-- Accesses to the debug port are not clocked and rely on a handshaking
-- protocol. To prevent the simulator's delta limit from being reached the slave
-- has a counter that keeps track of how many accesses that has been made while
-- simulation time has not progressed. If SLAVE_DELTA_LIMIT (defined in at_pkg)
-- is reached, the slave will wait 1 ps before continuing.
--
-- [Violations of AMBA protocol]
--
-- The slave assumes that the master and arbiter behave correctly. To detect
-- violations of the AMBA protocol an external bus monitor should be used.
--
-- [Debug level settings]
--
-- The amount of debug output from the slave is controlled by setting a
-- debug output level. A group of messages have a specific level and a
-- message is printed if msglevel <= debuglevel. The debug levels are:
--
-- 5 - Prints information about AHB accesses to AHB slave
-- 6 - Prints information about AHB accesses and DBG port accesses
--
-- TODO:
-- * An unnecessary large amount of memory is allocated for the memory array.
--   Segment it/adjust per bank.

library ieee;
use ieee.math_real.uniform;
use ieee.std_logic_1164.all;

library std;
use std.textio.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.at_pkg.all;
use grlib.at_ahb_slv_pkg.all;
use grlib.stdio.all;
use grlib.stdlib.all;
use grlib.testlib.all;

entity at_ahb_slv is
  
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

end at_ahb_slv;

architecture sim of at_ahb_slv is

  -----------------------------------------------------------------------------
  -- Configuration
  -----------------------------------------------------------------------------
  
  constant NUM_OF_BANKS : integer := 4;  -- Number of banks
  
  constant SEED_VALUE1 : positive := 3583523;    -- Seed value for rng
  constant SEED_VALUE2 : positive := 572352524;  -- Seed value for rng

  constant DFL_SPLITCNT : integer := 10; -- Default number of cycles before un-SPLIT
  
  -- Description: Returns the maximum memory bank size required, in words
  function max_memsize
    return integer is
    type int_array is array (0 to 3) of integer;
    variable btypes : int_array := (bank0type, bank1type, bank2type, bank3type);
    variable masks : int_array := (bank0mask, bank1mask, bank2mask, bank3mask);
    variable curr, max : integer := 0;
  begin  -- max_memsize
    for i in 0 to 3 loop
      if btypes(i) = AT_AHBSLV_IO then
        curr := ahb_iobar_size(masks(i))/4;
      elsif masks(i) /= 0 then
        curr := ahb_membar_size(masks(i))/4;
      else
        curr := 0;
      end if;
      if curr > max then
        max := curr;
      end if;
    end loop;  -- i
    return max;    
  end max_memsize;
 
  -----------------------------------------------------------------------------
  -- Types
  -----------------------------------------------------------------------------

  type string_array is array (0 to (NUM_OF_BANKS-1)) of string(1 to 31);

  type slv_to_core_type is record
    req    : std_ulogic;              -- Request
    -- Address phase query
    avalid  : std_ulogic;
    wr      : std_ulogic;              -- Write
    addr    : std_logic_vector(ADDR_R);
    bank    : std_logic_vector(BANK_R);
    size    : std_logic_vector(SIZE_R);
    mst     : integer range 0 to NAHBMST-1;
    trans   : std_logic_vector(1 downto 0);
    mstlock : std_ulogic;
    -- Data phase transfer
    dvalid  : std_ulogic;
    waddr   : std_logic_vector(ADDR_R);
    wdata   : std_logic_vector(DATA_R);
    wbank   : std_logic_vector(BANK_R);
    wsize   : std_logic_vector(SIZE_R);
    -- Locked access status
    locked  : std_ulogic;
    lockid  : integer;
    -- Transfer finished
    doneid  : integer;
    done    : std_ulogic;
  end record;

  type core_to_slv_type is record
    ack    : std_ulogic;                -- Acknowledge
    id     : integer;
    resp   : slv_resp_type;
    wantda : boolean;                   -- Want data
    lastac : boolean;                   -- Last access, callback on completion
    unlock : std_ulogic;
  end record;

  type bank_config_type is record
    addr         : integer;         -- Bank address
    mask         : integer;         -- Bank mask
    btype        : integer;         -- Bank type
    cacheable    : integer;         -- Bank is cacheable
    prefetchable : integer;         -- Bank is prefetchable
    ws           : integer;         -- Default number of wait states
    rws          : integer;         -- Randomize number of wait states
    rsplit       : real;            -- Probability of receiving random SPLIT responses
    rretry       : real;            --        - || -                   RETRY
    splitcnt     : integer;         -- Number of cycles before un-SPLIT
    rsplitcnt    : integer;         -- Randomize number of cycles before un-SPLIT
    dataload     : integer;         -- Load data from file
    interactive  : boolean;         -- Interactive mode 
  end record;

  type bank_config_array is array (0 to (NUM_OF_BANKS-1)) of bank_config_type;
  
  -- Slave memory types
  subtype memory_word_type is std_logic_vector(31 downto 0);

  type word_ptr is access memory_word_type;

  type memory_array is array (0 to max_memsize-1) of word_ptr;

  type bank_ptr is access memory_array;
  
  type mem_type is array (0 to (NUM_OF_BANKS-1)) of bank_ptr;
  
  -- Linked list with responses
  type response_element_type;

  type response_element_ptr is access response_element_type;

  type response_element_ptr_array is array (0 to (NUM_OF_BANKS-1)) of response_element_ptr;
  
  type response_element_type is record
      id   : integer;
      resp : at_slv_resp_type;
      nxt  : response_element_ptr;
  end record;

  type ahb_access_state_type is (ok, unsplit, two_cycle0, two_cycle1);
  
  type access_state_type is record
        active     : boolean;
        checktrans : boolean;
        id         : integer;
        state      : ahb_access_state_type;
        resp       : slv_resp_type;
        callback   : boolean;
        count      : integer;
  end record;

  type access_state_array is array (0 to (NAHBMST-1)) of access_state_type;
  
  -----------------------------------------------------------------------------
  -- Subprograms
  -----------------------------------------------------------------------------
  -- Description: Returns plug'n'play bar based on btype. 
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
    if cache /= 0 then c := '1'; end if;
    if prefetch /= 0 then p := '1'; end if;
    return ahb_membar(addr, c, p, mask);
  end gen_pnp_bar;

  -- Description: Masks appropriate part of address depending on bank type and
  -- bank mask.
  function maskadd (
    signal   addr     : std_logic_vector(ADDR_R);
    constant bank_cfg : bank_config_type)
    return std_logic_vector is
    variable raddr : std_logic_vector(ADDR_R) := (others => '0');
    variable msb : integer;
    variable mask : std_logic_vector(11 downto 0);
  begin  -- maskadd
    mask := conv_std_logic_vector(bank_cfg.mask, mask'length);
    if bank_cfg.btype = AT_AHBSLV_MEM then msb := 19;
    else msb := 7; end if;
    for i in mask'range loop
      if mask(i) = '0' then
        msb := msb + 1;
      end if;
    end loop;  -- i
    raddr(msb downto 0) := addr(msb downto 0);
    return raddr;
  end maskadd;
  
  -- Description: Copy from Gaisler simulation library
  procedure char2hex(C: character; result: out bit_vector(3 downto 0);
            good: out boolean; report_error: in boolean) is
  begin
    good := true;
    case C is
      when '0' => result :=  x"0"; 
      when '1' => result :=  x"1"; 
      when '2' => result :=  X"2"; 
      when '3' => result :=  X"3"; 
      when '4' => result :=  X"4"; 
      when '5' => result :=  X"5"; 
      when '6' => result :=  X"6"; 
      when '7' => result :=  X"7"; 
      when '8' => result :=  X"8"; 
      when '9' => result :=  X"9"; 
      when 'A' => result :=  X"A"; 
      when 'B' => result :=  X"B"; 
      when 'C' => result :=  X"C"; 
      when 'D' => result :=  X"D"; 
      when 'E' => result :=  X"E"; 
      when 'F' => result :=  X"F"; 

      when 'a' => result :=  X"A"; 
      when 'b' => result :=  X"B"; 
      when 'c' => result :=  X"C"; 
      when 'd' => result :=  X"D"; 
      when 'e' => result :=  X"E"; 
      when 'f' => result :=  X"F"; 
      when others =>
        if report_error then
          assert false report 
            "hexread error: read a '" & C & "', expected a hex character (0-F).";
        end if;
        good := false;
    end case;
  end;

  -- Description: Copy from Gaisler simulation library
  procedure hexread(L:inout line; value:out bit_vector)  is
    variable OK: boolean;
    variable C:  character;
    constant NE: integer := value'length/4;	--'
    variable BV: bit_vector(0 to value'length-1);	--'
    variable S:  string(1 to NE-1);
  begin
    if value'length mod 4 /= 0 then	--'
      assert false report
        "hexread Error: Trying to read vector " &
        "with an odd (non multiple of 4) length";
      return;
    end if;
    
    loop                                    -- skip white space
      read(L,C);
      exit when ((C /= ' ') and (C /= CR) and (C /= HT));
    end loop;
 
    char2hex(C, BV(0 to 3), OK, false);
    if not OK then
      return;
    end if;
 
    read(L, S, OK);
--    if not OK then
--      assert false report "hexread Error: Failed to read the STRING";
--      return;
--    end if;
 
    for I in 1 to NE-1 loop
      char2hex(S(I), BV(4*I to 4*I+3), OK, false);
      if not OK then
        return;
      end if;
    end loop;
    value := BV;
  end hexread;

  -- Description: Copy from Gaisler simulation library
  procedure hexread(L:inout line; value:out std_ulogic_vector) is
    variable tmp: bit_vector(value'length-1 downto 0);	--'
  begin
    hexread(L, tmp);
    value := TO_X01(tmp);
  end hexread;

  -- Description: Copy from Gaisler simulation library
  procedure hexread(L:inout line; value:out std_logic_vector) is
    variable tmp: std_ulogic_vector(value'length-1 downto 0);	--'
  begin
    hexread(L, tmp);
    value := std_logic_vector(tmp);
  end hexread;

  
  -- Description: Reads data from SREC file 'fname' to mem_array 'mem'
  procedure loadmem (
    constant fname : in    string;
    variable mem   : inout bank_ptr) is
    file     fload : text open read_mode is fname;
    variable fline : line;
    variable fchar : character;
    variable rtype : std_logic_vector(3 downto 0);
    variable raddr : std_logic_vector(31 downto 0);
    variable rlen  : std_logic_vector(7 downto 0);
    variable rdata : std_logic_vector(0 to 16*8-1);
    variable addr  : integer;
  begin  -- loadmem
    
    while not endfile(fload) loop
      readline(fload, fline);
      read(fline, fchar);
      if fchar /= 'S' or fchar /= 's' then
        hexread(fline, rtype);
        hexread(fline, rlen);
        case rtype is 
          when "0001" =>
            hexread(fline, raddr(15 downto 0));
            raddr(31 downto 16) := (others => '0');
          when "0010" =>
            hexread(fline, raddr(23 downto 0));
            raddr(31 downto 24) := (others => '0');
          when "0011" =>
            hexread(fline, raddr);
            raddr(31 downto 24) := (others => '0');
          when others => next;
        end case;
        
        hexread(fline, rdata);
        addr := conv_integer(raddr(31 downto 2));
        
        for i in 0 to 3 loop
          if mem(addr+i) = NULL then
            mem(addr+i) := new memory_word_type'(rdata(i*32 to i*32+31));
          end if; 
        end loop; -- i
      end if;
    end loop;
  end loadmem;

  -- Description: Write data into memory array
  procedure writemem (
    variable mem  : inout bank_ptr;
    constant addr : in    std_logic_vector(ADDR_R);
    constant data : in    std_logic_vector(DATA_R);
    constant size : in    std_logic_vector(SIZE_R)) is
    variable a : integer;
    variable lsize : std_logic_vector(2 downto 0) := (others => '0');
  begin  -- writemem
    a := conv_integer(addr(ADDR_R'left downto 2));
    
    assert DATA_R'left = 31
      report "writemem needs to be adjusted for new data bus width"
      severity failure;
    
    if mem(a) = NULL then
      mem(a) := new memory_word_type'(others => 'U');
    end if;

    lsize(size'range) := size;
    case lsize is
      when HSIZE_BYTE =>
        case addr(1 downto 0) is
          when "00" => mem(a).all(31 downto 24) := data(7 downto 0);
          when "01" => mem(a).all(23 downto 16) := data(7 downto 0);
          when "10" => mem(a).all(15 downto 8) := data(7 downto 0);
          when others => mem(a).all(7 downto 0) := data(7 downto 0);
        end case;
      when HSIZE_HWORD =>
          if addr(1) = '0' then mem(a).all(31 downto 16) := data(15 downto 0);
          else mem(a).all(15 downto 0) := data(15 downto 0); end if;
      when HSIZE_WORD => mem(a).all := data;
      when others =>
        assert false
          report "writemem needs to be updated for this system"
          severity failure;
    end case;
  end writemem;

  -- Description: Read data from memory array
  --              This function returns 'U' on unselected bytes and
  --              unassigned memory addresses
  procedure readmem (
    variable mem  : inout bank_ptr;
    constant addr : in    std_logic_vector(ADDR_R);
    signal   data : out   std_logic_vector(DATA_R);
    constant size : in    std_logic_vector(SIZE_R)) is
    variable lsize : std_logic_vector(2 downto 0) := (others => '0');
  begin  -- readmem
    
    assert DATA_R'left = 31
      report "readmem needs to be adjusted for new data bus width"
      severity failure;
    
    if mem(conv_integer(addr(ADDR_R'left downto 2))) = NULL then
      data <= (others => 'U');
    else
      data <= mem(conv_integer(addr(ADDR'left downto 2))).all;
      
      lsize(size'range) := size;
      case lsize is
        when HSIZE_BYTE =>
          if addr(1) = '0' then
            data(15 downto 0) <= (others => 'U');
            if addr(0) = '0' then data(23 downto 16) <= (others => 'U');
            else data(31 downto 24) <= (others => 'U'); end if;
          else
            data(31 downto 16) <= (others => 'U');
            if addr(0) = '0' then data(7 downto 0) <= (others => 'U');
            else data(15 downto 8) <= (others => 'U'); end if;
          end if;
        when HSIZE_HWORD =>
          if addr(1) = '0' then data(15 downto 0) <= (others => 'U');
          else data(31 downto 16) <= (others => 'U'); end if;
        when HSIZE_WORD => null;
        when others =>
          assert false
            report "readmem needs to be updated for this system"
            severity failure;
      end case;
    end if;
  end readmem;
  
  -- Description: Insert a response into the linked list of responses
  procedure insert_resp (
    constant id        : in    integer;
    variable resp_root : inout response_element_ptr;
    signal   resp      : in    at_slv_resp_type) is
    variable elem : response_element_ptr;
  begin  -- insert_resp
    elem := resp_root;
    if elem /= NULL then
      while elem.nxt /= NULL loop elem := elem.nxt; end loop;
      elem.nxt := new response_element_type'(id, resp, NULL);
    else
      resp_root := new response_element_type'(id, resp, NULL);
    end if;
  end insert_resp;
  
  -- Description: Searches the list for a response to a particular address.
  -- If a response is found the response is returned via 'resp' and 'found'
  -- is set to true, otherwise 'found' is set to false.
  procedure get_resp (
    variable resp_root : inout response_element_ptr;
    signal   req       : in    slv_to_core_type;
    signal   resp      : out   slv_resp_type;
    signal   wantda    : out   boolean;
    signal   id        : out   integer;
    signal   lastac    : out   boolean;
    variable found     : out   boolean;
    variable accmem    : out   boolean) is
    variable elem, prev : response_element_ptr;
    variable lfound : boolean := false;
  begin  -- get_resp
    prev := resp_root;
    elem := resp_root;
    while elem /= NULL and not lfound loop
      -- Check if response is a match for address range, read/write and master
      if (req.addr >= elem.resp.addr1 and req.addr <= elem.resp.addr2 and
          ((elem.resp.read and req.wr = '0') or
           (elem.resp.write and req.wr = '1')) and
          (elem.resp.anymst or (elem.resp.mst = req.mst))) then
        if elem.resp.delay = 0 then
          id <= elem.id;
          resp <= elem.resp.resp;
          accmem := elem.resp.accmem;
          wantda  <= elem.resp.accmem and req.wr = '1';
          if elem.resp.count = 1 then
            if prev = resp_root then
              resp_root := elem.nxt;
            else
              prev.nxt := elem.nxt;
            end if;
            deallocate(elem);
            lastac <= true;
          else
            elem.resp.count := elem.resp.count - 1;
            lastac <= false;
          end if;
          lfound := true;
        else
          elem.resp.delay := elem.resp.delay - 1;
        end if;
      end if;
      if not lfound then
        prev := elem;
        elem := elem.nxt;
      end if;
    end loop;
    if lfound then found := true;
    else
      found := false; accmem := false; wantda <= req.wr = '1';
      id <= RESERVED_RESP_ID; lastac <= false;
    end if;
  end get_resp;

  -- Description: Searches the list for a response with a particular id.
  -- If a response is found the response is returned via 'resp' the id
  -- will match the input id
  procedure get_resp (
    variable resp_root : inout response_element_ptr_array;
    constant asa       : in    access_state_array;
    constant id        : in    integer;
    signal   resp      : out   at_slv_resp_type;
    signal   respid    : out   integer) is
    variable elem, prev : response_element_ptr;
    variable lfound : boolean := false;
    variable i : integer := 0;
  begin  -- get_resp
    while i < response_element_ptr_array'length and not lfound loop
      prev := resp_root(i);
      elem := resp_root(i);
      while elem /= NULL and not lfound loop
        if id = elem.id then
          resp <= elem.resp;
          lfound := true;
        else
          prev := elem;
          elem := elem.nxt;
        end if;
      end loop;
      i := i + 1;
    end loop;
    if not lfound then
      for i in asa'range loop 
        if asa(i).id = id and asa(i).active then
          -- We don't have the entie resp record available here.
          -- count is the only member used by outside layers, so we
          -- cheat... 
          resp.count <= 1;
          lfound := true;
        end if;
      end loop;                     
    end if;
    if lfound then respid <= id;
    else respid <= id+1; end if;
  end get_resp;

  -- Description: Searches the list for a response with a particular id.
  -- If a response is found the response is removed and the id
  -- will match the input id. 
  procedure rm_resp (
    variable resp_root : inout response_element_ptr_array;
    constant id        : in    integer;
    signal   respid    : out   integer) is
    variable elem, prev : response_element_ptr;
    variable lfound : boolean := false;
    variable i : integer := 0;
  begin  -- rm_resp
    while i < response_element_ptr_array'length and not lfound loop
      prev := resp_root(i);
      elem := resp_root(i);
      while elem /= NULL and not lfound loop
        if id = elem.id then
          if prev = resp_root(i) then
            resp_root(i) := elem.nxt;
          else
            prev.nxt := elem.nxt;
          end if;
          deallocate(elem);
          lfound := true;
        else
          prev := elem;
          elem := elem.nxt;
        end if;
      end loop;
      i := i + 1;
    end loop;
    if lfound then respid <= id;
    else respid <= id+1; end if;
  end rm_resp;

  -- Description: Removes all responses in list
  procedure rm_all_resp (
    variable resp_root : inout response_element_ptr) is
    variable elem, curr : response_element_ptr;
    variable lfound : boolean := false;
  begin  -- rm_all_resp
    curr := resp_root;
    elem := resp_root;
    while elem /= NULL loop
      curr := elem;
      elem := elem.nxt;
      deallocate(curr);
    end loop;
    resp_root := NULL;
  end rm_all_resp;

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------
  constant REVISION : integer := 0;
  
  constant HCONFIG : ahb_config_type := (
    0 => ahb_device_reg(VENDOR_GAISLER, GAISLER_ATAHBSLV, 0, REVISION, 0),
    4 => gen_pnp_bar(bank0addr, bank0mask, bank0type, bank0cache, bank0prefetch),
    5 => gen_pnp_bar(bank1addr, bank1mask, bank1type, bank1cache, bank1prefetch),
    6 => gen_pnp_bar(bank2addr, bank2mask, bank2type, bank2cache, bank2prefetch),
    7 => gen_pnp_bar(bank3addr, bank3mask, bank3type, bank3cache, bank3prefetch),
    others => zero32);  

  -- Debug levels

  constant DBGACC_DBGLVL : integer := 6;
  constant AHBACC_DBGLVL : integer := 5;
  
  constant QUIET_DBGLVL  : integer := 0;
  
  constant INITIAL_DBGLVL : integer := QUIET_DBGLVL;
  
  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  signal bank_cfg : bank_config_array :=
    ((bank0addr, bank0mask, bank0type, bank0cache,
      bank0prefetch, bank0ws, bank0rws, 0.0, 0.0, DFL_SPLITCNT,
      0, bank0dataload, false),
     (bank1addr, bank1mask, bank1type, bank1cache,
      bank1prefetch, bank1ws, bank1rws, 0.0, 0.0, DFL_SPLITCNT,
      0, bank1dataload, false),
     (bank2addr, bank2mask, bank2type, bank2cache,
      bank2prefetch, bank2ws, bank2rws, 0.0, 0.0, DFL_SPLITCNT,
      0, bank2dataload, false),
     (bank3addr, bank3mask, bank3type, bank3cache,
      bank3prefetch, bank3ws, bank3rws, 0.0, 0.0, DFL_SPLITCNT,
      0, bank3dataload, false));
  
  signal initialized : boolean := false;
  signal dbglvl      : integer := INITIAL_DBGLVL;
  
  signal asa         : access_state_array;

  signal slv_to_core : slv_to_core_type;
  signal core_to_slv : core_to_slv_type;
    
begin  -- sim

  core: process
    variable mem           : mem_type := (others => NULL);
    variable id            : integer := 0;
    variable resp_root     : response_element_ptr_array := (others => NULL);
    variable success       : boolean;
    variable accmem        : boolean;
    variable seed1         : positive := SEED_VALUE1;
    variable seed2         : positive := SEED_VALUE2;
    variable rand          : real;
    variable bank          : integer;
    variable last_dbg_time : time;
    variable deltacount    : integer := 0;
    variable interactive   : boolean := false;
    variable dinteractive  : boolean := false;
  begin  -- process core

    ---------------------------------------------------------------------------
    -- Initialize memory
    ---------------------------------------------------------------------------
    if not initialized then
      for i in 0 to (NUM_OF_BANKS-1) loop
        if bank_cfg(i).mask /= 0 or bank_cfg(i).btype = AT_AHBSLV_IO then
          mem(i):= new memory_array;
        end if;
        if bank_cfg(i).dataload /= 0 then
          case i is
            when 0 => loadmem(bank0datafile, mem(i));
            when 1 => loadmem(bank1datafile, mem(i));
            when 2 => loadmem(bank2datafile, mem(i));
            when others => loadmem(bank3datafile, mem(i));
          end case;
        end if;
      end loop;  -- i
      initialized <= true;
    end if;
    
    if dbgi.req /= '1' and slv_to_core.req /= '1' then
      wait until dbgi.req = '1' or slv_to_core.req = '1';
    end if;

    ---------------------------------------------------------------------------
    -- Debug port access
    ---------------------------------------------------------------------------
    if dbgi.req = '1' then
      bank := log2(conv_integer(reverse(dbgi.bank)));
      case dbgi.acc is
        when d =>
          -- Access is to memory array
          if dbgi.wr = '1' then
            print("DBG memory array write to bank " & tost(bank) &
                  " address " & tost(dbgi.addr) & " size " & tost(dbgi.size) &
                  " data " & tost(dbgi.data), note, DBGACC_DBGLVL <= dbglvl);
            writemem(mem(bank), maskadd(dbgi.addr, bank_cfg(bank)),
                     dbgi.data, dbgi.size);
          else
            print("DBG memory array read on bank " & tost(bank) &
                  " address " & tost(dbgi.addr) & " size " & tost(dbgi.size),
                  note, DBGACC_DBGLVL <= dbglvl);
            readmem(mem(bank), maskadd(dbgi.addr, bank_cfg(bank)),
                    dbgo.data, dbgi.size);
          end if;
        when ri =>
          -- Insert customized response
          print("DBG insertion of response on bank " & tost(bank),
                note, DBGACC_DBGLVL <= dbglvl);

          insert_resp(id, resp_root(bank), dbgi.resp);
          dbgo.id <= id;
          id := (id + 1) mod RESERVED_RESP_ID;

          print(" => Address range start: " & tost(dbgi.resp.addr1),
                note, DBGACC_DBGLVL <= dbglvl);
          print(" => Address range stop: " & tost(dbgi.resp.addr2),
                note, DBGACC_DBGLVL <= dbglvl);
          if dbgi.resp.read then
            print(" => Valid for read access",
                  note, DBGACC_DBGLVL <= dbglvl);
          end if;
          if dbgi.resp.write then
            print(" => Valid for write access",
                  note, DBGACC_DBGLVL <= dbglvl);
          end if;
          if dbgi.resp.accmem then
            print(" => Allows access to memory array",
                  note, DBGACC_DBGLVL <= dbglvl);
          else
            print(" => Response data is " & tost(dbgi.resp.resp.data),
                  note, DBGACC_DBGLVL <= dbglvl);
          end if;
          print(" => HRESP is " & tost(dbgi.resp.resp.resp),
                note, DBGACC_DBGLVL <= dbglvl);
          print(" => Number of waitstates: " & tost(dbgi.resp.resp.ws),
                note, DBGACC_DBGLVL <= dbglvl);
          if dbgi.resp.resp.lock then
            print(" => Response will lock", note, DBGACC_DBGLVL <= dbglvl);
          end if;
          print(" => Repeat: " & tost(dbgi.resp.resp.repeat),
                note, DBGACC_DBGLVL <= dbglvl);
          if dbgi.resp.resp.resp = HRESP_SPLIT then
            print(" => Number of cycles before unsplit: " &
                  tost(dbgi.resp.resp.splitcnt), note, DBGACC_DBGLVL <= dbglvl);
          end if;
          print(" => # accesses that response is valid: " &
                tost(dbgi.resp.count), note, DBGACC_DBGLVL <= dbglvl);
          if dbgi.resp.anymst then
            print(" => Response is valid for any master",
                  note, DBGACC_DBGLVL <= dbglvl);
          else
            print(" => Response is valid for master " & tost(dbgi.resp.mst),
                  note, DBGACC_DBGLVL <= dbglvl);
          end if;
        when rc =>
          -- Check status of response
          print("DBG statuc check access to bank " & tost(bank),
                note, DBGACC_DBGLVL <= dbglvl);
          -- If the response is found, it is returned with the correct ID.
          -- Otherwise the ID will not match
          get_resp(resp_root, asa, dbgi.id, dbgo.resp, dbgo.id);
        when ru =>
          -- Unlock response
          print("DBG unlock access to bank " & tost(bank),
                note, DBGACC_DBGLVL <= dbglvl);
          dbgo.id <= dbgi.id + 1;
          if slv_to_core.locked = '1' then
            if slv_to_core.lockid = dbgi.id then
              core_to_slv.unlock <= '1';
              wait until slv_to_core.locked = '0';
              core_to_slv.unlock <= '0';
              dbgo.id <= dbgi.id;
            end if;
          end if;
        when rr => 
          -- Remove response
          -- If a response was successfully removed, the ID will match,
          -- otherwise a valid pending response was not found
          print("DBG remove response access to bank " & tost(bank),
                note, DBGACC_DBGLVL <= dbglvl);
          rm_resp(resp_root, dbgi.id, dbgo.id);
        when rar =>
          -- Remove all responses queued for a bank
          rm_all_resp(resp_root(bank));
        when c =>
          print("DBG configuration access to bank " & tost(bank),
                note, DBGACC_DBGLVL <= dbglvl);
          -- Slave config
          if dbgi.wr = '1' then
            bank_cfg(bank).ws <= dbgi.ws;
            bank_cfg(bank).rws <= dbgi.rws;
            bank_cfg(bank).rsplit <= dbgi.rsplit;
            bank_cfg(bank).rretry <= dbgi.rretry;
            bank_cfg(bank).splitcnt <= dbgi.splcnt;
            bank_cfg(bank).rsplitcnt <= dbgi.rsplcnt;
            bank_cfg(bank).interactive <= dbgi.iactiv;
            dbglvl <= dbgi.dbglvl;
          else
            dbgo.ws <= bank_cfg(bank).ws;
            dbgo.rws <= bank_cfg(bank).rws;
            dbgo.rsplit <= bank_cfg(bank).rsplit;
            dbgo.rretry <= bank_cfg(bank).rretry;
            dbgo.splcnt <= bank_cfg(bank).splitcnt;
            dbgo.rsplcnt <= bank_cfg(bank).rsplitcnt;
            dbgo.iactiv <= bank_cfg(bank).interactive;
            dbgo.dbglvl <= dbglvl;
          end if;
      end case;
      
      -- Prevent iteration limit from being reached
      if last_dbg_time = now then
        deltacount := deltacount + 1;
        if deltacount >= SLAVE_DELTA_LIMIT then
          wait for 1 ps; deltacount := 0;
        end if;
      else
        deltacount := 0;
      end if;
      last_dbg_time := now;
      
      dbgo.ack <= '1';
      wait until dbgi.req = '0';
      dbgo.ack <= '0';
    end if;

    ---------------------------------------------------------------------------
    -- Access from AHB slave interface
    ---------------------------------------------------------------------------
    if slv_to_core.req = '1' then
      bank := log2(conv_integer(reverse(slv_to_core.bank)));
      
      print("AMBA access to bank " & tost(bank) & " address " &
            tost(slv_to_core.addr), note,
            AHBACC_DBGLVL <= dbglvl and slv_to_core.avalid = '1');

      -- Handle done callback
      if slv_to_core.done = '1' then
        dbgo.compid <= slv_to_core.doneid;
      end if;

      dinteractive := interactive;
      -- Handle interactive accesses
      if bank_cfg(bank).interactive then
        dbgo.avalid <= slv_to_core.avalid;
        dbgo.wr     <= slv_to_core.wr;
        dbgo.addr   <= slv_to_core.addr;
        dbgo.bank   <= slv_to_core.bank;
        dbgo.size   <= slv_to_core.size;
        dbgo.mst    <= slv_to_core.mst;
        dbgo.trans  <= slv_to_core.trans;
        dbgo.locked <= slv_to_core.mstlock;
        dbgo.dvalid <= slv_to_core.dvalid;
        dbgo.waddr  <= slv_to_core.waddr;
        dbgo.wdata  <= slv_to_core.wdata;
        dbgo.wbank  <= slv_to_core.wbank;
        dbgo.wsize  <= slv_to_core.wsize;
        dbgo.ireq   <= '1';
        
        wait until dbgi.iack = '1';
        core_to_slv.id  <= dbgi.id;
        core_to_slv.resp <= dbgi.resp.resp;
        core_to_slv.wantda <= dbgi.iwdata;
        core_to_slv.lastac <= dbgi.icompid;
        interactive := not dbgi.idflt; -- May use normal response
        dbgo.ireq <= '0';
        wait until dbgi.iack = '0';
      else
        -- Normal response
        interactive := false;
      end if;
      
      -- Handle address stage
      if slv_to_core.avalid = '1' and not interactive then
        -- Check if there is a response queued for this access
        get_resp(resp_root(bank), slv_to_core, core_to_slv.resp, core_to_slv.wantda,
                 core_to_slv.id, core_to_slv.lastac, success, accmem);
        if (not success or accmem) and slv_to_core.avalid = '1' then
          -- No response queued or response may access memory.
          print(" => access to memory array", note, AHBACC_DBGLVL <= dbglvl);
          if slv_to_core.wr = '0' then
            readmem(mem(bank), maskadd(slv_to_core.addr, bank_cfg(bank)),
                    core_to_slv.resp.data, slv_to_core.size);
          end if;
          if not success then
            -- Default response
            core_to_slv.resp.resp <= HRESP_OKAY;
            print(" => default response", note,
                  AHBACC_DBGLVL <= dbglvl and slv_to_core.avalid = '1');
            -- Check if we should insert random RETRY
            if bank_cfg(bank).rretry /= 0.0 then
              uniform(seed1, seed2, rand);
              if rand <= bank_cfg(bank).rretry then
                print(" => inserting random RETRY response", note,
                      AHBACC_DBGLVL <= dbglvl and slv_to_core.avalid = '1');
                core_to_slv.resp.resp <= HRESP_RETRY;
              end if;
            end if;
            -- Check if we should insert random SPLIT (overrides random RETRY)
            if bank_cfg(bank).rsplit /= 0.0 then
              uniform(seed1, seed2, rand);
              if rand <= bank_cfg(bank).rsplit then
                print(" => inserting random SPLIT response", note,
                      AHBACC_DBGLVL <= dbglvl and slv_to_core.avalid = '1');
                core_to_slv.resp.resp <= HRESP_SPLIT;
                -- Check if we should randomize the number of cycles before un-SPLIT
                if bank_cfg(bank).rsplitcnt /= 0 then
                  uniform(seed1, seed2, rand);
                  core_to_slv.resp.splitcnt <= natural(rand * real(bank_cfg(bank).splitcnt));
                  print(" => number of cycles before unsplit set to " &
                        tost(natural(rand * real(bank_cfg(bank).splitcnt))),
                        note, AHBACC_DBGLVL <= dbglvl);
                else
                  core_to_slv.resp.splitcnt <= bank_cfg(bank).splitcnt;
                  print(" => number of cycles before unsplit set to " &
                        tost(bank_cfg(bank).splitcnt), note,
                        AHBACC_DBGLVL <= dbglvl and slv_to_core.avalid = '1');
                end if;
              end if;
            end if;
            -- Set number of waitstates
            if bank_cfg(bank).rws = 0 then
              core_to_slv.resp.ws <= bank_cfg(bank).ws;
              print(" => number of wait states set to " & tost(bank_cfg(bank).ws),
                    note, AHBACC_DBGLVL <= dbglvl and slv_to_core.avalid = '1');
            else
              uniform(seed1, seed2, rand);
              core_to_slv.resp.ws <= natural(rand * real(bank_cfg(bank).ws));
              print(" => number of wait states set to " &
                    tost(natural(rand * real(bank_cfg(bank).ws))),
                    note, AHBACC_DBGLVL <= dbglvl and slv_to_core.avalid = '1');
            end if;        
            --
            core_to_slv.resp.lock <= false;
            core_to_slv.resp.repeat <= 1;
          else
            print(" => using queued response", note,
                  AHBACC_DBGLVL <= dbglvl and slv_to_core.avalid = '1');
          end if;
        end if;
      end if;
      
      -- Handle data write
      if slv_to_core.dvalid = '1' and not dinteractive then
        bank := log2(conv_integer(reverse(slv_to_core.wbank)));
        print("AMBA data phase: wrote " & tost(slv_to_core.wdata) &
              " to bank " & tost(bank) & " address " &
              tost(slv_to_core.waddr) & " size " & tost(slv_to_core.wsize),
              note, AHBACC_DBGLVL <= dbglvl);
        writemem(mem(bank), maskadd(slv_to_core.waddr, bank_cfg(bank)),
                 slv_to_core.wdata, slv_to_core.wsize);
      end if;
      
      core_to_slv.ack <= '1';
      wait until slv_to_core.req = '0';
      core_to_slv.ack <= '0';
    end if;
  end process core;

  -----------------------------------------------------------------------------
  -- AMBA interface
  -----------------------------------------------------------------------------
  ahbslv: process
    -- purpose: Synchronizes with core process
    procedure sync_with_core is
    begin  -- sync_with_core
      slv_to_core.req <= '1';
      wait until core_to_slv.ack = '1';
      slv_to_core.req <= '0';
      wait until core_to_slv.ack = '0';
    end sync_with_core;

    variable ahb_access   : access_state_array;
    variable handle_write : boolean := false;
    variable sync         : boolean := false;
    variable master       : integer range 0 to NAHBMST-1;
    variable index        : integer range 0 to 24;
    variable htrans       : std_logic_vector(ahbsi.htrans'range);
  begin
    
    ahbso.hconfig  <= HCONFIG;
    ahbso.hindex   <= hindex;
    ahbso.hcache   <= '0';
    
    if rstn = '0' then
      ahbso.hready  <= '1';
      ahbso.hsplit   <= (others => '0');
      ahbso.hresp   <= HRESP_OKAY;
      ahbso.hrdata  <= (others => '0');      
    elsif rising_edge(clk) then
      -- Handle data phase of write cycle
      if handle_write then
        slv_to_core.dvalid <= '1';
        slv_to_core.waddr  <= slv_to_core.addr;
        slv_to_core.wbank  <= slv_to_core.bank;
        slv_to_core.wsize  <= slv_to_core.size;
        case slv_to_core.size is
          when HSIZE8 =>
            index := conv_integer(slv_to_core.addr(1 downto 0))*8;
            slv_to_core.wdata(7 downto 0) <= ahbsi.hwdata(31-index downto 24-index);
          when HSIZE16 =>
            index := conv_integer(slv_to_core.addr(1 downto 0))*8;
            slv_to_core.wdata(15 downto 0) <= ahbsi.hwdata(31-index downto 16-index);
          when others => 
            slv_to_core.wdata <= ahbsi.hwdata;
        end case;
        handle_write := false; sync := true;
      else
        slv_to_core.dvalid <= '0';
      end if;
       
      -- Handle address phase of AMBA access
      slv_to_core.avalid <= '0';
      if ahbsi.hready = '1' then
        htrans := HTRANS_IDLE;
        if (ahbsi.hsel(hindex) and ahbsi.htrans(1)) = '1' then
          -- Ask core what to do with the access
          master := conv_integer(ahbsi.hmaster);
          htrans := ahbsi.htrans;
          ahbso.hready <= '0';
          if not ahb_access(master).active then
            slv_to_core.avalid  <= '1';
            slv_to_core.wr      <= ahbsi.hwrite;
            slv_to_core.addr    <= ahbsi.haddr(ADDR_R);
            slv_to_core.bank    <= ahbsi.hmbsel(BANK_R);
            slv_to_core.size    <= ahbsi.hsize(SIZE_R);
            slv_to_core.trans   <= ahbsi.htrans;
            slv_to_core.mstlock <= ahbsi.hmastlock;
            slv_to_core.mst     <= master;
            sync_with_core; sync := false;
            ahb_access(master).active     := true;
            ahb_access(master).checktrans := false;
            ahb_access(master).id         := core_to_slv.id;
            ahb_access(master).resp       := core_to_slv.resp;
            ahb_access(master).callback   := core_to_slv.lastac;
            handle_write                  := core_to_slv.wantda;
            if core_to_slv.resp.lock then ahb_access(master).count := 0;
            else ahb_access(master).count := core_to_slv.resp.ws; end if;
            case core_to_slv.resp.resp is
              when HRESP_OKAY => ahb_access(master).state := ok;
              when others => ahb_access(master).state := two_cycle0;
            end case;
          end if;
        end if;
      end if;
      
      if sync then sync_with_core; sync := false; end if;
      
      -- Default values
      slv_to_core.done <= '0';
      ahbso.hresp <= HRESP_OKAY;
      ahbso.hsplit <= (others => '0');

      -- See if there are any pending responses
      for i in access_state_array'range loop 
        if ahb_access(i).active then
          if ahb_access(i).resp.lock then
            slv_to_core.locked <= '1';
            slv_to_core.lockid <= ahb_access(i).id;
            if core_to_slv.unlock = '1' then
              ahb_access(i).resp.lock := false;
              slv_to_core.locked <= '0';
              wait until core_to_slv.unlock = '0';
            end if;
          elsif ahb_access(i).count = 0 then
            case ahb_access(i).state is
              when ok =>
                if (not ahb_access(i).checktrans or
                    (master = i and htrans(1) = '1')) then 
                  ahbso.hresp <= HRESP_OKAY;
                  ahbso.hready <= '1';
                  ahbso.hrdata <= ahb_access(i).resp.data;
                  ahb_access(i).active := false;
                end if;
              when unsplit =>
                -- Unsplit master
                ahbso.hsplit(i) <= '1';
                if ahb_access(i).resp.repeat = 1 then
                  ahb_access(i).state := ok;
                else
                  -- If repeat is 0 we repeat forever
                  if ahb_access(i).resp.repeat /= 0 then
                    ahb_access(i).resp.repeat := ahb_access(i).resp.repeat - 1;
                  end if;
                  ahb_access(i).state := two_cycle0;
                end if;
                ahb_access(i).checktrans := true;
                ahb_access(i).count := ahb_access(i).resp.ws;              
              when two_cycle0 =>
                if (not ahb_access(i).checktrans or
                    (master = i and htrans(1) = '1')) then 
                  ahbso.hready <= '0';
                  ahbso.hresp <= ahb_access(i).resp.resp;
                  ahb_access(i).state := two_cycle1;
                  ahb_access(i).checktrans := false;
                end if;
              when two_cycle1 =>
                if ahb_access(i).resp.resp = HRESP_SPLIT then
                  ahb_access(i).state := unsplit;
                  ahb_access(i).count := ahb_access(i).resp.splitcnt;
                elsif ahb_access(i).resp.resp = HRESP_RETRY then
                  if ahb_access(i).resp.repeat = 1 then
                    ahb_access(i).state := ok;
                  else
                    ahb_access(i).count := ahb_access(master).resp.ws;
                    ahb_access(i).state := two_cycle0;
                    -- If repeat is 0 we repeat forever
                    if ahb_access(i).resp.repeat /= 0 then
                      ahb_access(i).resp.repeat := ahb_access(i).resp.repeat - 1;
                    end if;
                  end if;
                  ahb_access(i).checktrans := true;
                else
                  ahb_access(i).active := false;
                end if;
                ahbso.hrdata <= ahb_access(i).resp.data;
                ahbso.hresp <= ahb_access(i).resp.resp;
                ahbso.hready <= '1';
            end case;
            if not ahb_access(i).active and ahb_access(i).callback then
              -- Transfer finished, sync in next cycle
              slv_to_core.doneid <= ahb_access(i).id;
              slv_to_core.done <= '1'; sync := true;
            end if;
          elsif ahb_access(i).state = unsplit or (htrans(1) = '1' and master = i) then
            ahb_access(i).count := ahb_access(i).count - 1;
          end if;
        end if;
      end loop;
      asa <= ahb_access;
    end if;
      
    wait on clk, rstn;
  end process ahbslv;
  
end sim;
