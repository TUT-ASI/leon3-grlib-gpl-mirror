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
-- Package:     at_ahb_slv_pkg
-- File:        at_ahb_slv_pkg.vhd
-- Author:      Jan Andersson, Aeroflex Gaisler
-- Description: AMBA Test Framework - Test slave package
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.textio.all;

library grlib;
use grlib.amba.all;
use grlib.at_pkg.all;
use grlib.stdio.all;
use grlib.stdlib.all;
use grlib.testlib.all;

package at_ahb_slv_pkg is

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------
  constant RESERVED_RESP_ID : integer := 30000;
  
  -----------------------------------------------------------------------------
  -- Subprograms for interacting with test slave
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Debug port accesses to slave memory array
  -----------------------------------------------------------------------------
  
  -- Subprogram: ahbslv_write
  -- Description: Write data to slave memory. The input address is masked and
  --              only the valid bits are used. This means that the full AMBA
  --              address can be used and the caller does not have to subtract
  --              the bank start address.
  procedure ahbslv_write (
    constant address : in  std_logic_vector(ADDR_R);
    constant data    : in  std_logic_vector;
    constant bank    : in  integer;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_read
  -- Description: Read data from slave memory. The input address is masked and
  --              only the valid bits are used. This means that the full AMBA
  --              address can be used and the caller does not have to subtract
  --              the bank start address.
  procedure ahbslv_read (
    constant address : in  std_logic_vector(ADDR_R);
    variable data    : out std_logic_vector;
    constant bank    : in  integer;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type);

  -----------------------------------------------------------------------------
  -- Customized response
  -----------------------------------------------------------------------------
  
  -- Subprogram: ahbslv_response
  --
  -- Parameters:
  --    address_start   Address range start (inclusive)
  --
  --    address_stop    Address range stop  (inclusive)
  --
  --    bank            Bank that response is valid for
  --
  --    response        AMBA HRESP value
  --
  --    data            AMBA data that will be delivered if mem_access is false
  --
  --    master          Master that response is valid for
  --
  --    anymst          Response is valid for any master
  --
  --    id              ID assigned to response
  --
  --    dbgi            dbgi signal of slave
  --    dbgo            dbgo signal of slave
  --
  --    ws              Number of waitstates
  --
  --    repeat          Number of times to repeat response. This value is only
  --                    used for SPLIT and RETRY responses. 0 repeats forever.
  --
  --    count           The number of accesses the response is valid for. In the
  --                    case of RETRY and SPLIT the core will respond with
  --                    'repeat' SPLIT/RETRYs before the transfer completes and
  --                    the response will be active for 'count' transfers. If
  --                    count is 0, the response is valid forever.
  --
  --    splitcnt        The number of cycles before un-SPLIT
  --
  --    mem_access      Access memory array
  --
  --    read_response   Response is valid for reads
  --
  --    write_response  Response is valid for writes
  --
  --    locked          Lock response. Useful for generating endless amount of
  --                    wait states. Currently only usabled for waitstates
  --                    followed by the specified reponse. 'locked' will not result
  --                    in endless RETRY, SPLIT or ERROR responses.
  --
  --    delay           Wait for 'delay' accesses before returning response. If
  --                    set to x the slave model will reply with the default response
  --                    for x accesses and the return the customized response.
  --
  -- Description: Inserts a customized response into the AHB slave's response
  --              queue. The address parameters contain the complete AMBA address.
  --              They are not relative to the bank start.
  procedure ahbslv_response (
    constant address_start  : in  std_logic_vector(ADDR_R);
    constant address_stop   : in  std_logic_vector(ADDR_R);
    constant bank           : in  integer;
    constant response       : in  std_logic_vector(1 downto 0);
    constant data           : in  std_logic_vector(DATA_R);
    constant master         : in  integer range 0 to NAHBMST-1;
    constant anymst         : in  boolean;
    variable id             : out integer;
    signal   dbgi           : out at_slv_dbg_in_type;
    signal   dbgo           : in  at_slv_dbg_out_type;
    constant ws             : in  integer := 0;
    constant repeat         : in  integer := 1;
    constant count          : in  integer := 1;
    constant splitcnt       : in  integer := 5;
    constant mem_access     : in  boolean := false;
    constant read_response  : in  boolean := true;
    constant write_response : in  boolean := true;
    constant lock           : in  boolean := false;
    constant delay          : in  integer := 0);

   procedure ahbslv_response (
    constant address_start  : in  std_logic_vector(ADDR_R);
    constant address_stop   : in  std_logic_vector(ADDR_R);
    constant bank           : in  integer;
    constant response       : in  std_logic_vector(1 downto 0);
    constant data           : in  std_logic_vector(DATA_R);
    constant master         : in  integer range 0 to NAHBMST-1;
    variable id             : out integer;
    signal   dbgi           : out at_slv_dbg_in_type;
    signal   dbgo           : in  at_slv_dbg_out_type;
    constant ws             : in  integer := 0;
    constant repeat         : in  integer := 1;
    constant count          : in  integer := 1;
    constant splitcnt       : in  integer := 5;
    constant mem_access     : in  boolean := false;
    constant read_response  : in  boolean := true;
    constant write_response : in  boolean := true;
    constant lock           : in  boolean := false;
    constant delay          : in  integer := 0);

  procedure ahbslv_response (
    constant address_start  : in  std_logic_vector(ADDR_R);
    constant address_stop   : in  std_logic_vector(ADDR_R);
    constant bank           : in  integer;
    constant response       : in  std_logic_vector(1 downto 0);
    constant data           : in  std_logic_vector(DATA_R);
    variable id             : out integer;
    signal   dbgi           : out at_slv_dbg_in_type;
    signal   dbgo           : in  at_slv_dbg_out_type;
    constant ws             : in  integer := 0;
    constant repeat         : in  integer := 1;
    constant count          : in  integer := 1;
    constant splitcnt       : in  integer := 5;
    constant mem_access     : in  boolean := false;
    constant read_response  : in  boolean := true;
    constant write_response : in  boolean := true;
    constant lock           : in  boolean := false;
    constant delay          : in  integer := 0);
  
  -- Subprogram: ahbslv_response_status
  -- Description: If a response with ID 'id' exists in the response queue
  --              'valid' will be set to true and count will be set to the
  --              value of the response's valid count. Otherwise 'valid' will
  --              be set to false;
  procedure ahbslv_response_status (
    constant id    : in  integer;
    variable valid : out boolean;
    variable count : out integer;
    signal   dbgi  : out at_slv_dbg_in_type;
    signal   dbgo  : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_response_remove
  -- Description: If a response with ID 'id' exists in the response queue
  --              'success' will be set to true and the response will be removed
  --              from the queue. Otherwise 'success' will be set to false;
  procedure ahbslv_response_remove (
    constant id      : in  integer;
    variable success : out boolean;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type);

  procedure ahbslv_response_remove (
    constant id      : in  integer;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_response_clear
  -- Description: Clears all queued responses in AHB slave
  procedure ahbslv_response_clear (
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_response_clear
  -- Description: Clears all queued responses on bank 'bank' in AHB slave
  procedure ahbslv_response_clear (
    constant bank    : in integer;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type);
  
  -- Subprogram: ahbslv_response_unlock
  -- Description: If a response with ID 'id' exists has locked the slave
  --              'success' will be set to true and the slave will be unlocked.
  --              Otherwise 'success' will be set to false;
  procedure ahbslv_response_unlock (
    constant id      : in  integer;
    variable success : out boolean;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type);

  procedure ahbslv_response_unlock (
    constant id      : in  integer;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_waitforaccess
  -- Description: This procedure will block until the master has made an access
  --              to the memory range defined by 'address_start' and
  --              'address_stop' on bank 'bank'. This is accomplished by
  --              inserting a customized OKAY response that that allows access
  --              to the memory array. The subprogram then waits for the
  --              customized response to be completed. In other words the
  --              procedure may not be what is wanted if another response exists
  --              for the address range. In that case ahvslv_waitforcomplete(..)
  --              on an existing response may be a better option. 
  procedure ahbslv_waitforaccess (
    constant address_start  : in  std_logic_vector(ADDR_R);
    constant address_stop   : in  std_logic_vector(ADDR_R);
    constant bank           : in  integer;
    signal   dbgi           : out at_slv_dbg_in_type;
    signal   dbgo           : in  at_slv_dbg_out_type;
    constant read_response  : in  boolean := true;
    constant write_response : in  boolean := true;
    constant master         : in  integer := 0;
    constant anymst         : in  boolean := true);

  -- Subprogram: ahbslv_waitforcomplete
  -- Description: This procedure will wait until the response with ID 'id' has
  -- completed. Note that if the response has count > 1 this procedure will block
  -- until the last response has been performed.
  procedure ahbslv_waitforcomplete (
    constant id   : in  integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type);

  -----------------------------------------------------------------------------
  -- Slave configuration
  -----------------------------------------------------------------------------
  
  -- Subprogram: ahbslv_setconfig
  -- Description: Change default response behavior of AHB slave model bank
  procedure ahbslv_setconfig (
    constant bank        : in integer;
    constant ws          : in integer;
    constant rws         : in integer;
    constant retry_prob  : in real;
    constant split_prob  : in real;
    constant splitcnt    : in integer;
    constant rsplitcnt   : in integer;
    constant interactive : in boolean;
    constant dbglvl      : in integer;
    signal   dbgi        : out at_slv_dbg_in_type;
    signal   dbgo        : in  at_slv_dbg_out_type);

  procedure ahbslv_setconfig (
    constant bank        : in integer;
    constant ws          : in integer;
    constant rws         : in integer;
    constant retry_prob  : in real;
    constant split_prob  : in real;
    constant splitcnt    : in integer;
    constant rsplitcnt   : in integer;
    constant dbglvl      : in integer;
    signal   dbgi        : out at_slv_dbg_in_type;
    signal   dbgo        : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_getconfig
  -- Description: Get default response behavior of AHB slave model bank
  procedure ahbslv_getconfig (
    constant bank        : in  integer;
    variable ws          : out integer;
    variable rws         : out integer;
    variable retry_prob  : out real;
    variable split_prob  : out real;
    variable splitcnt    : out integer;
    variable rsplitcnt   : out integer;
    variable interactive : out boolean;
    variable dbglvl      : out integer;
    signal   dbgi        : out at_slv_dbg_in_type;
    signal   dbgo        : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_enable_split
  -- Description: Enable AMBA SPLIT responses with a 50 % probability for bank 'bank'
  procedure ahbslv_enable_split (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type);
  
  -- Description: Enable AMBA SPLIT responses with a 'prob' probability for bank 'bank'
  procedure ahbslv_enable_split (
    constant bank     : in integer;
    constant prob     : in real;
    signal   dbgi     : out at_slv_dbg_in_type;
    signal   dbgo     : in  at_slv_dbg_out_type);

  -- Description: Enable AMBA SPLIT responses with a 'prob' probability and 'splitcnt'
  --              cycles before un-SPLIT for bank 'bank'. If 'rsplitcnt' is set
  --              to a non-zero value, the number of cycles before un-split is
  --              randomized.
  procedure ahbslv_enable_split (
    constant bank      : in integer;
    constant prob      : in real;
    constant splitcnt  : in integer;
    constant rsplitcnt : in integer;
    signal   dbgi      : out at_slv_dbg_in_type;
    signal   dbgo      : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_disable_split
  -- Description: Disable AMBA SPLIT responses for bank 'bank'
  procedure ahbslv_disable_split (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_enable_retry
  -- Description: Enable AMBA RETRY responses with a 50 % probability for bank 'bank'
  procedure ahbslv_enable_retry (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type);

  -- Description: Enable AMBA RETRY responses with a 'prob' probability for bank 'bank'
  procedure ahbslv_enable_retry (
    constant bank : in integer;
    constant prob : in real;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type);
  
  -- Description: Disable AMBA RETRY responses for bank 'bank'
  procedure ahbslv_disable_retry (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type);


  -- Subprogram: ahbslv_enable_interactive
  -- Description: Enable interactive mode for bank 'bank'
  procedure ahbslv_enable_interactive (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_disable_interactive
  -- Description: Disable interactive mode for bank 'bank'
  procedure ahbslv_disable_interactive (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_set_ws
  -- Description: Sets the number of waitstates (ws) for a bank
  procedure ahbslv_set_ws (
    constant bank : in integer;
    constant ws   : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_get_ws
  -- Description: Gets the number of waitstates (ws) for a bank
  procedure ahbslv_get_ws (
    constant bank : in  integer;
    variable ws   : out integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type);

  -----------------------------------------------------------------------------
  -- Interactive accesses
  -----------------------------------------------------------------------------

  -- Subprogram: ahbslv_interactive_wait
  --
  -- Parameters:
  --
  --    avalid   Valid address phase
  --    wr       AMBA hwrite            (address phase)
  --    addr     AMBA addr              (address phase)
  --    bank     Selected bank          (address phase)
  --    size     AMBA hsize(1 downto 0) (address phase)
  --    mst      Access from master     (address phase)
  --    trans    AMBA htrans            (address phase)
  --    locked   AMBA hlock             (address phase)
  --
  --    dvalid   Valid data phase
  --    waddr    AMBA addr              (data phase)
  --    wdata    AMBA hwdata            (data phase)
  --    wbank    Selected bank          (data phase)
  --    wsize    AMBA hsize(1 downto 0) (data phase)
  --
  --    dbgi     ahbslv debug connection
  --    dbgo     ahbslv debug connection
  --
  -- Description: Blocks until an access is made to the AHB slave. When the
  --              slave model is accessed the procedure will return with the
  --              access characteristics and the caller can use
  --              ahbslv_interactive_response(..) to respond to the access.
  --
  --              Note that there should not be any delays between the return
  --              of this procedure and the call of ahbslv_interactive_response.
  --              No other calls to the AHB slave's debug port are allowed
  --              between these two procedure calls!
  --              The core must be placed in interactive mode before this
  --              procedure is called or the call may never return.
  --
  --              Note that dvalid may be asserted during the data phase of an
  --              access even if 'default' was set to
  --              ahbslv_interactive_response during the address phase.
  --
  procedure ahbslv_interactive_wait (
    -- Address phase information
    variable avalid   : out std_ulogic;
    variable wr       : out std_ulogic;
    variable addr     : out std_logic_vector(ADDR_R);
    variable bank     : out integer;
    variable size     : out std_logic_vector(SIZE_R);
    variable mst      : out integer range 0 to NAHBMST-1;
    variable trans    : out std_logic_vector(1 downto 0);
    variable locked   : out std_ulogic;
    -- Data phase information
    variable dvalid   : out std_ulogic;
    variable waddr    : out std_logic_vector(ADDR_R);
    variable wdata    : out std_logic_vector(DATA_R);
    variable wbank    : out std_logic_vector(BANK_R);
    variable wsize    : out std_logic_vector(SIZE_R);
    signal   dbgi     : out at_slv_dbg_in_type;
    signal   dbgo     : in  at_slv_dbg_out_type);

  -- Subprogram: ahbslv_interactive_response
  --
  -- Parameters
  --
  --    default    Respond with slave's default response
  --    data       AMBA hrdata
  --    resp       AMBA hresp
  --
  --    dbgi       ahbslv debug connection
  --    dbgo       ahbslv debug connection
  --
  --    ws         Number of waitstates
  --    lock       Lock transfer
  --    repeat     Repeat response # times
  --    splitcnt   Number of cycles before unsplit
  --
  -- Description: Inserts a response to an interactive request from the AHB
  --              slave model. If 'default' is set to true the slave will
  --              respond with it's default data.
  --
  procedure ahbslv_interactive_response (
    constant default  : in boolean;
    constant data     : in std_logic_vector(DATA_R);
    constant resp     : in std_logic_vector(1 downto 0);
    signal   dbgi     : out at_slv_dbg_in_type;
    signal   dbgo     : in  at_slv_dbg_out_type;
    constant ws       : in integer := 1;
    constant lock     : in boolean := false;
    constant repeat   : in integer := 1;
    constant splitcnt : in integer := 2);
  
end at_ahb_slv_pkg;

package body at_ahb_slv_pkg is

  -----------------------------------------------------------------------------
  -- Subprogram bodies
  -----------------------------------------------------------------------------
  
  procedure ahbslv_write (
    constant address : in  std_logic_vector(ADDR_R);
    constant data    : in  std_logic_vector;
    constant bank    : in  integer;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type) is
    variable lbank : std_logic_vector(BANK_R) := (others => '0');
  begin  -- ahbslv_write
    case data'length is
      when 32 =>
        dbgi.size <= HSIZE32;
        assert address(1 downto 0) = "00"
          report "ahbslv_wmem: Unaligned word access to address " & tost(address)
          severity error;
      when 16 =>
        dbgi.size <= HSIZE16;
        assert address(0) = '0'
          report "ahbslv_wmem: Unaligned halfword access to address " & tost(address)
          severity error;
      when 8 => dbgi.size <= HSIZE8;
      when others =>
        assert false
          report "ahbslv_wmem: Illegal data length! on write to address " & tost(address)
          severity error;
    end case;

    dbgi.acc <= d;
    dbgi.wr <= '1';
    dbgi.addr <= address;
    dbgi.data((data'length-1) downto 0) <= data;
    lbank(bank) := '1';
    dbgi.bank <= lbank;
    dbgi.req <= '1';
    wait until dbgo.ack = '1';
    dbgi.req <= '0';
    wait until dbgo.ack = '0';

  end ahbslv_write;

  procedure ahbslv_read (
    constant address : in  std_logic_vector(ADDR_R);
    variable data    : out std_logic_vector;
    constant bank    : in  integer;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type) is
    variable lbank : std_logic_vector(BANK_R) := (others => '0');
    variable lsize : std_logic_vector(SIZE_R);
    variable index : integer;
  begin  -- ahbslv_read
    case data'length is
      when 32 =>
        assert address(1 downto 0) = "00"
          report "ahbslv_wmem: Unaligned word access to address " & tost(address)
          severity error;
        lsize := HSIZE32;
      when 16 =>
        assert address(0) = '0'
          report "ahbslv_wmem: Unaligned halfword access to address " & tost(address)
          severity error;
        lsize := HSIZE16;
      when 8 => lsize := HSIZE8;
      when others =>
        assert false
          report "ahbslv_wmem: Illegal data length! on write to address " & tost(address)
          severity error;
    end case;
    dbgi.acc <= d;
    dbgi.wr <= '0';
    dbgi.addr <= address;
    lbank(bank) := '1';
    dbgi.bank <= lbank;
    dbgi.size <= lsize;
    dbgi.req <= '1';
    wait until dbgo.ack = '1';
    index := conv_integer(address(1 downto 0))*8;
    case lsize is
      when HSIZE8  => data := dbgo.data((31-index) downto (24-index));
      when HSIZE16 => data := dbgo.data((31-index) downto (16-index));
      when HSIZE32 => data := dbgo.data;
      when others =>
        assert false
          report "ahbslv_read needs to be updated for access size"
          severity error;
    end case;
    dbgi.req <= '0';
    wait until dbgo.ack = '0';
  end ahbslv_read;

  procedure ahbslv_response (
    constant address_start  : in  std_logic_vector(ADDR_R);
    constant address_stop   : in  std_logic_vector(ADDR_R);
    constant bank           : in  integer;
    constant response       : in  std_logic_vector(1 downto 0);
    constant data           : in  std_logic_vector(DATA_R);
    constant master         : in  integer range 0 to NAHBMST-1;
    constant anymst         : in  boolean;
    variable id             : out integer;
    signal   dbgi           : out at_slv_dbg_in_type;
    signal   dbgo           : in  at_slv_dbg_out_type;
    constant ws             : in  integer := 0;
    constant repeat         : in  integer := 1;
    constant count          : in  integer := 1;
    constant splitcnt       : in  integer := 5;
    constant mem_access     : in  boolean := false;
    constant read_response  : in  boolean := true;
    constant write_response : in  boolean := true;
    constant lock           : in  boolean := false;
    constant delay          : in  integer := 0) is
    variable lbank : std_logic_vector(BANK_R) := (others => '0');
  begin  -- ahbslv_response
    lbank(bank) := '1';
    
    dbgi.acc                 <= ri;
    dbgi.bank                <= lbank;
    dbgi.resp.addr1          <= address_start;
    dbgi.resp.addr2          <= address_stop;
    dbgi.resp.resp.data      <= data;
    dbgi.resp.resp.resp      <= response;
    dbgi.resp.resp.ws        <= ws;
    dbgi.resp.resp.lock      <= lock;
    dbgi.resp.resp.repeat    <= repeat;
    dbgi.resp.resp.splitcnt  <= splitcnt;
    dbgi.resp.accmem         <= mem_access;
    dbgi.resp.read           <= read_response;
    dbgi.resp.write          <= write_response;
    dbgi.resp.count          <= count;
    dbgi.resp.anymst         <= anymst;
    dbgi.resp.mst            <= master;
    dbgi.resp.delay          <= delay;
    
    dbgi.req <= '1';
    wait until dbgo.ack = '1';
    id := dbgo.id;
    dbgi.req <= '0';
    wait until dbgo.ack = '0';
  end ahbslv_response;

  procedure ahbslv_response (
    constant address_start  : in  std_logic_vector(ADDR_R);
    constant address_stop   : in  std_logic_vector(ADDR_R);
    constant bank           : in  integer;
    constant response       : in  std_logic_vector(1 downto 0);
    constant data           : in  std_logic_vector(DATA_R);
    constant master         : in  integer range 0 to NAHBMST-1;
    variable id             : out integer;
    signal   dbgi           : out at_slv_dbg_in_type;
    signal   dbgo           : in  at_slv_dbg_out_type;
    constant ws             : in  integer := 0;
    constant repeat         : in  integer := 1;
    constant count          : in  integer := 1;
    constant splitcnt       : in  integer := 5;
    constant mem_access     : in  boolean := false;
    constant read_response  : in  boolean := true;
    constant write_response : in  boolean := true;
    constant lock           : in  boolean := false;
    constant delay          : in  integer := 0) is
  begin  -- ahbslv_response
    ahbslv_response(
      address_start  => address_start,
      address_stop   => address_stop,
      bank           => bank,
      response       => response,     
      data           => data,
      master         => master,
      anymst         => false,
      id             => id,
      dbgi           => dbgi,
      dbgo           => dbgo,
      ws             => ws,
      repeat         => repeat,
      count          => count,
      splitcnt       => splitcnt,
      mem_access     => mem_access,
      read_response  => read_response,
      write_response => write_response,
      lock           => lock,
      delay          => delay);
  end ahbslv_response;

   procedure ahbslv_response (
    constant address_start  : in  std_logic_vector(ADDR_R);
    constant address_stop   : in  std_logic_vector(ADDR_R);
    constant bank           : in  integer;
    constant response       : in  std_logic_vector(1 downto 0);
    constant data           : in  std_logic_vector(DATA_R);
    variable id             : out integer;
    signal   dbgi           : out at_slv_dbg_in_type;
    signal   dbgo           : in  at_slv_dbg_out_type;
    constant ws             : in  integer := 0;
    constant repeat         : in  integer := 1;
    constant count          : in  integer := 1;
    constant splitcnt       : in  integer := 5;
    constant mem_access     : in  boolean := false;
    constant read_response  : in  boolean := true;
    constant write_response : in  boolean := true;
    constant lock           : in  boolean := false;
    constant delay          : in  integer := 0) is
  begin  -- ahbslv_response
    ahbslv_response(
      address_start  => address_start,
      address_stop   => address_stop,
      bank           => bank,
      response       => response,
      data           => data,
      master         => 0,
      anymst         => true,
      id             => id,
      dbgi           => dbgi,
      dbgo           => dbgo,
      ws             => ws,
      repeat         => repeat,
      count          => count,
      splitcnt       => splitcnt,
      mem_access     => mem_access,
      read_response  => read_response,
      write_response => write_response,
      lock           => lock,
      delay          => delay);
  end ahbslv_response;
  
  procedure ahbslv_response_status (
    constant id    : in  integer;
    variable valid : out boolean;
    variable count : out integer;
    signal   dbgi  : out at_slv_dbg_in_type;
    signal   dbgo  : in  at_slv_dbg_out_type) is
  begin  -- ahbslv_response_status
    dbgi.acc <= rc;
    dbgi.id  <= id;
    dbgi.req <= '1';
    wait until dbgo.ack = '1';
    valid := id = dbgo.id;
    count := dbgo.resp.count;
    dbgi.req <= '0';
    wait until dbgo.ack = '0';
  end ahbslv_response_status;

  procedure ahbslv_response_remove (
    constant id      : in  integer;
    variable success : out boolean;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type) is
  begin  -- ahbslv_response_remove
    dbgi.acc <= rr;
    dbgi.id  <= id;
    dbgi.req <= '1';
    wait until dbgo.ack = '1';
    success := id = dbgo.id;
    dbgi.req <= '0';
    wait until dbgo.ack = '0';
  end ahbslv_response_remove;

  procedure ahbslv_response_remove (
    constant id      : in  integer;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type) is
    variable lsuccess : boolean;
  begin  -- ahbslv_response_remove
    ahbslv_response_remove(id, lsuccess, dbgi, dbgo);
  end ahbslv_response_remove;

  procedure ahbslv_response_clear (
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type) is
  begin  -- ahbslv_response_clear
    for i in 0 to 3 loop
      ahbslv_response_clear(i, dbgi, dbgo);
    end loop;  -- i
  end ahbslv_response_clear;

  procedure ahbslv_response_clear (
    constant bank    : in integer;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type) is
    variable lbank : std_logic_vector(BANK_R) := (others => '0');
  begin  -- ahbslv_response_clear
    lbank(bank) := '1';
    dbgi.acc  <= rar;
    dbgi.bank <= lbank;
    dbgi.req  <= '1';
    wait until dbgo.ack = '1';
    dbgi.req <= '0';
    wait until dbgo.ack = '0';
  end ahbslv_response_clear;

  procedure ahbslv_response_unlock (
    constant id      : in  integer;
    variable success : out boolean;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type) is
  begin  -- ahbslv_response_unlock
    dbgi.acc <= ru;
    dbgi.id  <= id;
    dbgi.req <= '1';
    wait until dbgo.ack = '1';
    success := id = dbgo.id;
    dbgi.req <= '0';
    wait until dbgo.ack = '0';
  end ahbslv_response_unlock;

  procedure ahbslv_response_unlock (
    constant id      : in  integer;
    signal   dbgi    : out at_slv_dbg_in_type;
    signal   dbgo    : in  at_slv_dbg_out_type) is
    variable lsuccess : boolean;
  begin  -- ahbslv_response_unlock
    ahbslv_response_unlock(id, lsuccess, dbgi, dbgo);
  end ahbslv_response_unlock;

  procedure ahbslv_waitforaccess (
    constant address_start  : in  std_logic_vector(ADDR_R);
    constant address_stop   : in  std_logic_vector(ADDR_R);
    constant bank           : in  integer;
    signal   dbgi           : out at_slv_dbg_in_type;
    signal   dbgo           : in  at_slv_dbg_out_type;
    constant read_response  : in  boolean := true;
    constant write_response : in  boolean := true;
    constant master         : in  integer := 0;
    constant anymst         : in  boolean := true) is
    variable ws, rws, splitcnt, rsplitcnt, dbglvl, id : integer;
    variable retry_prob, split_prob : real;
    variable iv : boolean;
  begin  -- ahbslv_waitforaccess
    -- Get number of waitstates
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob,
                     splitcnt, rsplitcnt, iv, dbglvl, dbgi, dbgo);
    -- Insert OK response that makes access to memory
    ahbslv_response(
      address_start  => address_start,
      address_stop   => address_stop,
      bank           => bank,
      response       => HRESP_OKAY,
      data           => (others => '0'),
      master         => master,
      anymst         => anymst,
      id             => id,
      dbgi           => dbgi,
      dbgo           => dbgo,
      ws             => ws,
      repeat         => 1,
      count          => 1,
      splitcnt       => 0,
      mem_access     => true,
      read_response  => read_response,
      write_response => write_response,
      lock           => false,
      delay          => 0);
    -- Wait for complete
    ahbslv_waitforcomplete(id, dbgi, dbgo);
  end ahbslv_waitforaccess;
  
  procedure ahbslv_waitforcomplete (
    constant id   : in  integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable valid : boolean;
    variable count : integer;
  begin  -- ahbslv_waitforcomplete
    ahbslv_response_status(id, valid, count, dbgi, dbgo);
    if dbgo.compid /= id and valid then
      wait until dbgo.compid = id;
    end if;
  end ahbslv_waitforcomplete;
  
  procedure ahbslv_setconfig (
    constant bank        : in integer;
    constant ws          : in integer;
    constant rws         : in integer;
    constant retry_prob  : in real;
    constant split_prob  : in real;
    constant splitcnt    : in integer;
    constant rsplitcnt   : in integer;
    constant interactive : in boolean;
    constant dbglvl      : in integer;
    signal   dbgi        : out at_slv_dbg_in_type;
    signal   dbgo        : in  at_slv_dbg_out_type) is
    variable lbank : std_logic_vector(BANK_R) := (others => '0');
  begin  -- ahbslv_setconfig
    lbank(bank) := '1';
    dbgi.acc     <= c;
    dbgi.bank    <= lbank;
    dbgi.wr      <= '1';
    dbgi.ws      <= ws;
    dbgi.rws     <= rws;
    dbgi.rretry  <= retry_prob;
    dbgi.rsplit  <= split_prob;
    dbgi.splcnt  <= splitcnt;
    dbgi.rsplcnt <= rsplitcnt;
    dbgi.iactiv  <= interactive;
    dbgi.dbglvl  <= dbglvl;
    dbgi.req <= '1';
    wait until dbgo.ack = '1';
    dbgi.req <= '0';
    wait until dbgo.ack = '0';
  end ahbslv_setconfig;

  procedure ahbslv_setconfig (
    constant bank        : in integer;
    constant ws          : in integer;
    constant rws         : in integer;
    constant retry_prob  : in real;
    constant split_prob  : in real;
    constant splitcnt    : in integer;
    constant rsplitcnt   : in integer;
    constant dbglvl      : in integer;
    signal   dbgi        : out at_slv_dbg_in_type;
    signal   dbgo        : in  at_slv_dbg_out_type) is
  begin
    ahbslv_setconfig(bank, ws, rws, retry_prob, split_prob, splitcnt,
      rsplitcnt, false, dbglvl, dbgi, dbgo);
  end procedure;
  
  procedure ahbslv_getconfig (
    constant bank        : in  integer;
    variable ws          : out integer;
    variable rws         : out integer;
    variable retry_prob  : out real;
    variable split_prob  : out real;
    variable splitcnt    : out integer;
    variable rsplitcnt   : out integer;
    variable interactive : out boolean;
    variable dbglvl      : out integer;
    signal   dbgi        : out at_slv_dbg_in_type;
    signal   dbgo        : in  at_slv_dbg_out_type) is
    variable lbank : std_logic_vector(BANK_R) := (others => '0');
  begin  -- ahbslv_getconfig
    lbank(bank) := '1';
    dbgi.acc  <= c;
    dbgi.bank <= lbank;
    dbgi.wr   <= '0';
    dbgi.req  <= '1';
    wait until dbgo.ack = '1';
    ws          := dbgo.ws;
    rws         := dbgo.rws;
    retry_prob  := dbgo.rretry;
    split_prob  := dbgo.rsplit;
    splitcnt    := dbgo.splcnt;
    rsplitcnt   := dbgo.rsplcnt;
    interactive := dbgo.iactiv;
    dbglvl      := dbgo.dbglvl;
    dbgi.req <= '0';
    wait until dbgo.ack = '0';
  end ahbslv_getconfig;  

  procedure ahbslv_enable_split (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable ws, rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable iv : boolean;
    variable prob : real := 0.5;
  begin  -- ahbslv_enable_split
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
    ahbslv_setconfig(bank, ws, rws, retry_prob, prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
  end ahbslv_enable_split;
  
  procedure ahbslv_enable_split (
    constant bank : in integer;
    constant prob : in real;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable ws, rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable iv : boolean;
  begin  -- ahbslv_enable_split
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
    ahbslv_setconfig(bank, ws, rws, retry_prob, prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
  end ahbslv_enable_split;

  procedure ahbslv_enable_split (
    constant bank      : in integer;
    constant prob      : in real;
    constant splitcnt  : in integer;
    constant rsplitcnt : in integer;
    signal   dbgi      : out at_slv_dbg_in_type;
    signal   dbgo      : in  at_slv_dbg_out_type) is
    variable ws, rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable iv : boolean;
  begin  -- ahbslv_enable_split
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
    ahbslv_setconfig(bank, ws, rws, retry_prob, prob, splitcnt, rsplitcnt,
                     iv, dbglvl, dbgi, dbgo);
  end ahbslv_enable_split;  

  procedure ahbslv_disable_split (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable ws, rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable prob : real := 0.0;
    variable iv : boolean;
  begin  -- ahbslv_disable_split
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
    ahbslv_setconfig(bank, ws, rws, retry_prob, prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
  end ahbslv_disable_split;

  procedure ahbslv_enable_retry (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable ws, rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable prob : real := 0.5;
    variable iv : boolean;
  begin  -- ahbslv_enable_retry
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
    ahbslv_setconfig(bank, ws, rws, prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
  end ahbslv_enable_retry;
  
  procedure ahbslv_enable_retry (
    constant bank : in integer;
    constant prob : in real;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable ws, rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable iv : boolean;
  begin  -- ahbslv_enable_retry
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
    ahbslv_setconfig(bank, ws, rws, prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
  end ahbslv_enable_retry;
  
  procedure ahbslv_disable_retry (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable ws, rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable prob : real := 0.0;
    variable iv : boolean;
  begin  -- ahbslv_disable_retry
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
    ahbslv_setconfig(bank, ws, rws, prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
  end ahbslv_disable_retry;

  procedure ahbslv_enable_interactive (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable ws, rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable iv : boolean;
  begin  -- ahbslv_enable_interactive
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
    ahbslv_setconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     true, dbglvl, dbgi, dbgo);
  end ahbslv_enable_interactive;

  procedure ahbslv_disable_interactive (
    constant bank : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable ws, rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable iv : boolean;
  begin  -- ahbslv_disable_interactive
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
    ahbslv_setconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     false, dbglvl, dbgi, dbgo);
  end ahbslv_disable_interactive;

  procedure ahbslv_set_ws (
    constant bank : in integer;
    constant ws   : in integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable tws, rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable iv : boolean;
  begin  -- ahbslv_set_ws
    ahbslv_getconfig(bank, tws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
    ahbslv_setconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
  end ahbslv_set_ws;

  procedure ahbslv_get_ws (
    constant bank : in integer;
    variable ws   : out integer;
    signal   dbgi : out at_slv_dbg_in_type;
    signal   dbgo : in  at_slv_dbg_out_type) is
    variable rws, sc, rsc, dbglvl : integer;
    variable retry_prob : real;
    variable split_prob : real;
    variable iv : boolean;
  begin  -- ahbslv_get_ws
    ahbslv_getconfig(bank, ws, rws, retry_prob, split_prob, sc, rsc,
                     iv, dbglvl, dbgi, dbgo);
  end ahbslv_get_ws;
  
  procedure ahbslv_interactive_wait (
    -- Address phase information
    variable avalid   : out std_ulogic;
    variable wr       : out std_ulogic;
    variable addr     : out std_logic_vector(ADDR_R);
    variable bank     : out integer;
    variable size     : out std_logic_vector(SIZE_R);
    variable mst      : out integer range 0 to NAHBMST-1;
    variable trans    : out std_logic_vector(1 downto 0);
    variable locked   : out std_ulogic;
    -- Data phase information
    variable dvalid   : out std_ulogic;
    variable waddr    : out std_logic_vector(ADDR_R);
    variable wdata    : out std_logic_vector(DATA_R);
    variable wbank    : out std_logic_vector(BANK_R);
    variable wsize    : out std_logic_vector(SIZE_R);
    signal   dbgi     : out at_slv_dbg_in_type;
    signal   dbgo     : in  at_slv_dbg_out_type) is
  begin  -- ahbslv_interactive_wait
    if dbgo.ireq /= '1' then
      wait until dbgo.ireq = '1';
    end if;
    avalid := dbgo.avalid;
    wr     := dbgo.wr;
    addr   := dbgo.addr;
    bank   := log2(conv_integer(reverse(dbgo.bank)));
    size   := dbgo.size;
    mst    := dbgo.mst;
    trans  := dbgo.trans;
    locked := dbgo.locked;
    dvalid := dbgo.dvalid;
    waddr  := dbgo.waddr;
    wdata  := dbgo.wdata;
    wbank  := dbgo.wbank;
    wsize  := dbgo.wsize;
  end ahbslv_interactive_wait;
    
  procedure ahbslv_interactive_response (
    constant default  : in boolean;
    constant data     : in std_logic_vector(DATA_R);
    constant resp     : in std_logic_vector(1 downto 0);
    signal   dbgi     : out at_slv_dbg_in_type;
    signal   dbgo     : in  at_slv_dbg_out_type;
    constant ws       : in integer := 1;
    constant lock     : in boolean := false;
    constant repeat   : in integer := 1;
    constant splitcnt : in integer := 2) is
  begin  -- ahbslv_interactive_response
    -- Some signals are not exposed to the caller at this stage
    dbgi.id                 <= RESERVED_RESP_ID;
    dbgi.iwdata             <= dbgo.wr = '1';
    dbgi.icompid            <= false;
    --
    dbgi.idflt              <= default;
    dbgi.resp.resp.data     <= data;
    dbgi.resp.resp.resp     <= resp;
    dbgi.resp.resp.ws       <= ws;
    dbgi.resp.resp.lock     <= lock;
    dbgi.resp.resp.repeat   <= repeat;
    dbgi.resp.resp.splitcnt <= splitcnt;
    dbgi.iack <= '1';
    wait until dbgo.ireq = '0';
    dbgi.iack <= '0';
  end ahbslv_interactive_response;

end at_ahb_slv_pkg;
