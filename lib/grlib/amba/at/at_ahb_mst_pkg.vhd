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
-- Package:     at_ahb_mst_pkg
-- File:        at_ahb_mst_pkg.vhd
-- Author:      Marko Isomaki, Aeroflex Gaisler
-- Description: AMBA Test Framework - AHB master test package
-------------------------------------------------------------------------------
library  ieee;
use      ieee.std_logic_1164.all;
use      ieee.numeric_std.all;

library  std;
use      std.standard.all;
use      std.textio.all;

library  grlib;
use      grlib.amba.all;
use      grlib.at_pkg.all;
use      grlib.stdio.all;
use      grlib.stdlib.tost;
use      grlib.stdlib.zero32;
use      grlib.stdlib."+";
use      grlib.stdlib."-";
use      grlib.testlib.compare;
use      grlib.testlib.data_vector;
use      grlib.testlib.print;


--The parameters are mostly the same for every procedure so they are only explained
--at one place.

package at_ahb_mst_pkg is
   type response_vector is array (natural range <>) of boolean;
   type id_vector is array (natural range <>) of integer;
   type busy_cycle_vector is array (natural range <>) of integer;
         
   -----------------------------------------------------------------------------
   -- Init at master interface
   -----------------------------------------------------------------------------
   --Initialises the signals in the interface to the AMBA test AHB master. This
   --is a single master version with only a single master in record. should be
   --called immediately at the beginning of a simulation
   procedure at_init(
     signal   atmi:           out  at_ahb_mst_in_type);

   --Initialises the signals in the interface to the AMBA test AHB master. This
   --initialises the master with index "master" in an array . should be
   --called immediately at the beginning of a simulation
   procedure at_init(
     constant master:         in   integer := 0;
     signal   atmi:           out  at_ahb_mst_in_vector);

   -----------------------------------------------------------------------------
   -- 32-bit Non-blocking write access 
   -----------------------------------------------------------------------------
   --Initiate write
   
   --address:       Address of the write
   --data:          Data to be written
   --waitcycles:    Number cycles to wait before starting the access if
   --               back2back is false
   --lock:          perform a locked access
   --hprot:         this value is driven to the hprot field
   --back2back:     perform an back2back access which means that
   --               this access' address phase starts on the data
   --               phase of the previous access if possible.
   --screenoutput:  print information on console about the access
   --id:            identification number assigned to the operation
   procedure at_write_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   --Check write has finished and get results

   --id:            Identification number of the operation
   --wait_for_op:   When set to true the call blocks until the operation
   --               is ready. Otherwise it completes immediately
   --screenoutput:  print information on console about the access
   --ready:         When wait_for_op is false ready is set to true
   --               if the operation is finished and false otherwise.
   --               When wait_for_op is set to true ready is always
   --               true when the call completes
   --erresp:        set to true if the operation ended with an error response
   --               and false if ended with okay. 
   procedure at_write_32_nb_fin(
     constant id:            in    integer := 0;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_write_32_nb_fin(
     constant id:            in    integer := 0;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
     
   -----------------------------------------------------------------------------
   -- 32-bit Non-blocking read access 
   -----------------------------------------------------------------------------
   --initiate read
   --address:       Address of the write
   --waitcycles:    Number cycles to wait before starting the access if
   --               back2back is false
   --lock:          perform a locked access
   --hprot:         this value is driven to the hprot field
   --back2back:     perform an back2back access which means that
   --               this access' address phase starts on the data
   --               phase of the previous access if possible.
   --screenoutput:  print information on console about the access
   --id:            identification number assigned to the operation
   procedure at_read_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -- master:     Selected master
   procedure at_read_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector);
   
   --check if read has finished and get results
   --id:            Identification number of the operation
   --wait_for_op:   When set to true the call blocks until the operation
   --               is ready. Otherwise it completes immediately
   --screenoutput:  print information on console about the access
   --ready:         When wait_for_op is false ready is set to true
   --               if the operation is finished and false otherwise.
   --               When wait_for_op is set to true ready is always
   --               true when the call completes
   --data:          read data
   --erresp:        set to true if the operation ended with an error response
   --               and false if ended with okay.
   procedure at_read_32_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -- master       Selected master
   procedure at_read_32_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector);
   
   procedure at_read_32_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   -----------------------------------------------------------------------------
   -- Blocking 8-bit write access 
   -----------------------------------------------------------------------------
   procedure at_write_8(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(7 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable errorresp:     out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   procedure at_write_8(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(7 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -----------------------------------------------------------------------------
   -- Blocking 16-bit write access 
   -----------------------------------------------------------------------------
   procedure at_write_16(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(15 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable errorresp:     out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   procedure at_write_16(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(15 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
     
   -----------------------------------------------------------------------------
   -- Blocking 32-bit write access 
   -----------------------------------------------------------------------------
   procedure at_write_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable errorresp:     out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_write_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_write_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   -----------------------------------------------------------------------------
   -- Blocking write access (selectable size, max 32-bits)
   -----------------------------------------------------------------------------
   --uses a 32-bit data vector but only drives the byte lanes corresponding
   --to the address and size. unaligned accesses are not supported
   procedure at_write(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   -- idlecycles: number of added idlecycles before access
   procedure at_write(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant size:          in    integer := 32;
     constant first:         in    boolean := false;
     constant burst:         in    boolean := false;
     constant idlecycles:    in    integer := 0;
     constant dbglevel:      in    integer := 1;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -----------------------------------------------------------------------------
   -- Non-blocking write access (selectable size, max 32-bits)
   -----------------------------------------------------------------------------
   -- Initiate write
   procedure at_write_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant dbglevel:      in    integer := 0;
     constant discard:       in    boolean := false;
     constant size:          in    integer := 32;
     constant first:         in    boolean := false;
     constant burst:         in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_write_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   -- idlecycles: number of added idlecycles before access
   procedure at_write_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant size:          in    integer := 32;
     constant first:         in    boolean := false;
     constant burst:         in    boolean := false;
     constant idlecycles:    in    integer := 0;
     constant dbglevel:      in    integer := 1;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   --check write has finished and get results
   --check write has finished and get results
   procedure at_write_nb_fin(
     constant id:            in    integer := 0;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   procedure at_write_nb_fin(
     constant id:            in    integer := 0;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   -----------------------------------------------------------------------------
   -- Blocking 32-bit incrementing write burst
   -----------------------------------------------------------------------------
   --address:       Address of the write
   --data:          data vector to be written. The number of 32-bit elements
   --               determines the length of the burst. Must match the beat
   --               parameter for fixed length bursts
   --beat:          determines the length of a burst. 1 =incr, 4=4 beats,
   --               8=8 beats, 16=16 beats
   --wrap:          when set to true a wrapping burst will be perfomed with
   --               the number of beats specified with beat. beat=1 is illegal
   --               in this case
   --waitcycles:    Number cycles to wait before starting the access if
   --               back2back is false. 
   --lock:          perform a locked access
   --hprot:         this value is driven to the hprot field
   --back2back:     perform an back2back access which means that
   --               this access' address phase starts on the data
   --               phase of the previous access if possible.
   --screenoutput:  print information on console about the access
   --erresp:        set to true for each access that ended with an error response
   --               must be of the same length as the data vector. index 0 corresponds
   --               to the first access.
   --id:            identification number assigned to the operation
   procedure at_write_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   --starts a burst for the master with index "master". has an vector
   --of master in and out records as the argument
   procedure at_write_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector);

   procedure at_write_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_write_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
      
   -----------------------------------------------------------------------------
   -- Non-blocking 32-bit incrementing write burst
   -----------------------------------------------------------------------------
   --Initiate write
   procedure at_write_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_write_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector);

   procedure at_write_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant busy:          in    busy_cycle_vector;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   --check write has finished and get results
   procedure at_write_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_write_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_write_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable ready:         out   boolean;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector);

   -----------------------------------------------------------------------------
   -- Blocking 8-bit read access 
   -----------------------------------------------------------------------------
   procedure at_read_8(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(7 downto 0);
     variable errorresp:     out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_read_8(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(7 downto 0);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -----------------------------------------------------------------------------
   -- Blocking 16-bit read access 
   -----------------------------------------------------------------------------
   procedure at_read_16(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(15 downto 0);
     variable errorresp:     out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   procedure at_read_16(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(15 downto 0);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
    
   -----------------------------------------------------------------------------
   -- Blocking 32-bit read access 
   -----------------------------------------------------------------------------
   procedure at_read_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(DATA_R);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_read_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_read_32(
     constant address:       in    std_logic_vector(ADDR_R);
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -----------------------------------------------------------------------------
   -- Blocking read access (selectable size 8-, 16- and 32-bits)
   -----------------------------------------------------------------------------
   --always uses a 32-bit data vector regardless of size. Only the byte lane(-s)
   --corresponding to the address and size will be updated. Unaligned transfers
   --are not supported
   procedure at_read(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     variable data:          inout std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -----------------------------------------------------------------------------
   -- Non-blocking read access (selectable size 8-, 16- and 32-bits)
   -----------------------------------------------------------------------------
   --initiate read
   procedure at_read_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   --check if read has finished and get results
   procedure at_read_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_read_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
      
   -----------------------------------------------------------------------------
   -- Blocking 32-bit read burst access 
   -----------------------------------------------------------------------------
   procedure at_read_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   data_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   --data:    read data. index 0 corresponds to the first access
   --erresp:  set to true if an access ended with an error response.
   --         index 0 corresponds to the first access. must be of the same length
   --         as data.
   
   procedure at_read_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   data_vector;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_read_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable data:          out   data_vector;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector);

   -----------------------------------------------------------------------------
   -- Non-blocking 32-bit read burst access 
   -----------------------------------------------------------------------------
   --Initiate read
   --The id for each individual access in the burst is returned in the id vector
   --The first access corresponds to index 0. Length must the number of accesses
   --and be the same as beat for fixed length bursts. The id vector must also be
   --the same length as length.
   procedure at_read_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant length:        in    integer;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -- master       Selected master
   procedure at_read_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant length:        in    integer;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector);
   
   procedure at_read_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant length:        in    integer;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant busy:          in    busy_cycle_vector;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   --check read has finished and get results
   --id vector contains the identification numbers of the
   --operations with the first one at index 0
   procedure at_read_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   data_vector;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_read_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable ready:         out   boolean;
     variable data:          out   data_vector;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector);

   procedure at_read_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   data_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   -----------------------------------------------------------------------------
   -- Blocking 32-bit compare access 
   -----------------------------------------------------------------------------
   --reads data and compares with cdata. tp is set to false if data does not
   --match
   procedure at_comp_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_comp_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   std_logic_vector(DATA_R);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -----------------------------------------------------------------------------
   -- Blocking compare access (selectable size 8-, 16- and 32-bits)
   -----------------------------------------------------------------------------
   procedure at_comp_16(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    std_logic_vector(15 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   std_logic_vector(15 downto 0);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_comp_8(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    std_logic_vector(7 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   std_logic_vector(7 downto 0);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   procedure at_comp(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     variable tp:            inout boolean;
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
  
   -- idlecycles: number of added idlecycles before access
   procedure at_comp(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cmpdata:       in    std_logic_vector(DATA_R);
     constant size:          in    integer := 32;
     constant first:         in    boolean := false;
     constant burst:         in    boolean := false;
     constant idlecycles:    in    integer := 0;
     constant dbglevel:      in    integer := 1;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
   
   -----------------------------------------------------------------------------
   -- Non-Blocking compare access (selectable size 8-, 16- and 32-bits)
   -----------------------------------------------------------------------------
   procedure at_comp_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     constant burst:         in    boolean := false;
     constant first:         in    boolean := false;
     constant compare:       in    boolean := false;
     constant cmpdata:       in    std_logic_vector(DATA_R);
     constant erresp:        in    boolean := false;
     constant split:         in    boolean := false;      
     constant retry:         in    boolean := false;      
     constant dbglevel:      in    integer := 0;
     constant discard:       in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_comp_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     constant compare:       in    boolean := false;
     constant cmpdata:       in    std_logic_vector(DATA_R);
     constant erresp:        in    boolean := false;
     constant split:         in    boolean := false;      
     constant retry:         in    boolean := false;      
     constant dbglevel:      in    integer := 0;
     constant discard:       in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -- idlecycles: number of added idlecycles before access
   procedure at_comp_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cmpdata:       in    std_logic_vector(DATA_R);
     constant size:          in    integer := 32;
     constant first:         in    boolean := false;
     constant burst:         in    boolean := false;
     constant idlecycles:    in    integer := 0;
     constant dbglevel:      in    integer := 1;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   -----------------------------------------------------------------------------
   -- Blocking 32-bit burst compare access 
   -----------------------------------------------------------------------------
   procedure at_comp_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   data_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);

   procedure at_comp_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   data_vector;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type);
      
end package at_ahb_mst_pkg; --===============================================--


package body at_ahb_mst_pkg is
   function resp_to_str(
     constant resp : in std_logic_vector(1 downto 0))
     return string is
     
   begin
     case resp is
       when "00" =>
         return "OKAY";
       when "01" =>
         return "ERROR";
       when "10" =>
         return "SPLIT/RETRY";
       when others =>
         return "Illegal";
     end case;
   end function;
  
   procedure at_init(
     signal   atmi:          out   at_ahb_mst_in_type) is
   begin
     atmi.add   <= '0';
     atmi.get   <= '0';
     atmi.useid <= '0';
     atmi.id    <= 0;
     atmi.op    <= (0, (others => '0'), (others => '0'), false, false, 1, false,
                    32, false, false, (others => '0'), 0, false,
                    (others => '0'), 0, 0, false, (others => '0'), false,
                    false, false, 0, false);
   end procedure;

   procedure at_init(
     constant master:         in   integer := 0;
     signal   atmi:           out  at_ahb_mst_in_vector) is
   begin
     atmi(master).add   <= '0';
     atmi(master).get   <= '0';
     atmi(master).useid <= '0';
     atmi(master).id    <= 0;
     atmi(master).op    <= (0, (others => '0'), (others => '0'), false, false, 1, false,
                    32, false, false, (others => '0'), 0, false,
                    (others => '0'), 0, 0, false, (others => '0'), false,
                    false, false, 0, false);
   end procedure;

   --Initiate write
   procedure at_write_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
   begin
     op.id := 0;
     op.address := address; 
     op.data := data;
     op.burst := false; 
     op.beat := 1;
     op.first := false;
     op.wrap := false;
     op.size := 32;        
     op.store := true;
     op.lock := lock;
     op.prot := hprot;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     if screenoutput then
       Print("32-bit non-blocking write initiated, Address:  " & tost(address) &
             " Data: " & tost(data));
     end if;
   end procedure at_write_32_nb;

   procedure at_write_32_nb_fin(
     constant id:            in    integer := 0;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable vready:              boolean;
   begin
     vready := false;
     atmi.useid <= '1';
     atmi.id    <= id;
     atmi.get   <= '1';
     wait until atmo.getack = '1';
     if atmo.rdy = '1' then
       vready := true;
     else
       while wait_for_op loop
         atmi.get <= '0';
         wait until atmo.getack = '0';
         while atmo.fin /= '1' loop
           wait until atmo.fin = '1';
         end loop;
         atmi.get   <= '1';
         wait until atmo.getack = '1';
         if atmo.rdy = '1' then
           vready := true;
           exit;
         end if;
       end loop;
     end if;
     ready := vready; erresp := false;
     if vready then
       if atmo.op.response /= "00" then
         erresp := true;
       end if;
     end if;
     if (atmo.rdy = '1') and screenoutput then
       Print("32-bit non-blocking write finished, Address: " &
              tost(atmo.op.address) & " Data: " & tost(atmo.op.data) &
              " Resp: " & resp_to_str(atmo.op.response));
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
     wait until atmo.getack = '0';
   end procedure;

   procedure at_write_32_nb_fin(
     constant id:            in    integer := 0;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable erresp:              boolean;
   begin
     at_write_32_nb_fin(id, wait_for_op, screenoutput,
                        ready, erresp, atmi, atmo);
   end procedure;

   procedure at_write_8(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(7 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable errorresp:     out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
     variable id:                  integer;
   begin
     op.id := 0;
     op.address := address;
     case address(1 downto 0) is
       when "00" =>
         op.data(31 downto 24) := data;
         op.data(23 downto 0) := (others => '0');
       when "01" =>
         op.data(31 downto 24) := (others => '0');
         op.data(23 downto 16) := data;
         op.data(15 downto 0) := (others => '0');
       when "10" =>
         op.data(31 downto 16) := (others => '0');
         op.data(15 downto 8) := data;
         op.data(7 downto 0) := (others => '0');
       when "11" =>
         op.data(31 downto 8) := (others => '0');
         op.data(7 downto 0) := data;
       when others =>
         null;
     end case;
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := 8;        
     op.store := true;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     while true loop
       while atmo.fin /= '1' loop
         wait until atmo.fin = '1';
       end loop;
       atmi.useid <= '1';
       atmi.id <= id;
       atmi.get <= '1';
       wait until atmo.getack = '1';
       if atmo.rdy = '1' then
         exit;
       end if;
       atmi.useid <= '0'; atmi.get <= '0';
       wait until atmo.getack = '0';
     end loop;
     if screenoutput then
       Print("8-bit write, Address: " &
              tost(atmo.op.address) & " Data: " & tost(atmo.op.data) &
              " Resp: " & resp_to_str(atmo.op.response));
     end if;
     if atmo.op.response = "00" then
       errorresp := false;
     else
       errorresp := true;
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
   end procedure;

   procedure at_write_8(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(7 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable errorresp:           boolean;
   begin
     at_write_8(address, data, waitcycles, lock, hprot, back2back, screenoutput,
       errorresp, atmi, atmo);
   end procedure;
   
   procedure at_write_16(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(15 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable errorresp:     out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
     variable id:                  integer;
   begin
     op.id := 0;
     op.address := address;
     case address(1 downto 0) is
       when "00" =>
         op.data(31 downto 16) := data;
         op.data(15 downto 0) := (others => '0');
       when "10" =>
         op.data(31 downto 16) := (others => '0');
         op.data(15 downto 0) := data;
       when others =>
         assert false
         report "invalid address aligment"
         severity error;
     end case;
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := 16;        
     op.store := true;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     while true loop
       while atmo.fin /= '1' loop
         wait until atmo.fin = '1';
       end loop;
       atmi.useid <= '1';
       atmi.id <= id;
       atmi.get <= '1';
       wait until atmo.getack = '1';
       if atmo.rdy = '1' then
         exit;
       end if;
       atmi.useid <= '0'; atmi.get <= '0';
       wait until atmo.getack = '0';
     end loop;
     if screenoutput then
       Print("16-bit write, Address: " &
              tost(atmo.op.address) & " Data: " & tost(atmo.op.data) &
              " Resp: " & resp_to_str(atmo.op.response));
     end if;
     if atmo.op.response = "00" then
       errorresp := false;
     else
       errorresp := true;
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
   end procedure;

   procedure at_write_16(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(15 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable errorresp:           boolean;
   begin
     at_write_16(address, data, waitcycles, lock, hprot, back2back, screenoutput,
       errorresp, atmi, atmo);
   end procedure;

   procedure at_write_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable errorresp:     out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:           in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
     variable id:                  integer;
   begin
     op.id := 0;
     op.address := address; 
     op.data := data;
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := 32;        
     op.store := true;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     while true loop
       while atmo.fin /= '1' loop
         wait until atmo.fin = '1';
       end loop;
       atmi.useid <= '1';
       atmi.id <= id;
       atmi.get <= '1';
       wait until atmo.getack = '1';
       if atmo.rdy = '1' then
         exit;
       end if;
       atmi.useid <= '0'; atmi.get <= '0';
       wait until atmo.getack = '0';
     end loop;
     if screenoutput then
       Print("32-bit write, Address: " &
              tost(atmo.op.address) & " Data: " & tost(atmo.op.data) &
              " Resp: " & resp_to_str(atmo.op.response));
     end if;
     if atmo.op.response = "00" then
       errorresp := false;
     else
       errorresp := true;
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
     wait until atmo.getack = '0';
   end procedure at_write_32;

   procedure at_write_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable err:                 boolean;
   begin
     at_write_32(address, data, waitcycles, lock, hprot, back2back,
                 screenoutput, err, atmi, atmo);
   end procedure;
   
   procedure at_write_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable err:                 boolean;
   begin
     at_write_32(address, data, 0, false, "0011", true, false, err, atmi, atmo);
   end procedure;
   
   -----------------------------------------------------------------------------
   -- Blocking write access (selectable size, max 32-bits)
   -----------------------------------------------------------------------------
   procedure at_write(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
     variable id:                  integer;
   begin
     op.id := 0;
     op.address := address;
     case address(1 downto 0) is
       when "00" =>
         case size is
           when 32 =>
             op.data(31 downto 0) := data;
           when 16 =>
             op.data(31 downto 16) := data(31 downto 16);
             op.data(15 downto 0) := (others => '0');
           when 8 =>
             op.data(31 downto 24) := data(31 downto 24);
             op.data(23 downto 0) := (others => '0');
           when others =>
             assert false
             report "invalid address aligment"
             severity error;
         end case;
       when "01" =>
         case size is
           when 8 =>
             op.data := (others => '0');
             op.data(23 downto 16) := data(23 downto 16);
           when others =>
             assert false
             report "invalid address aligment"
             severity error;
         end case;
       when "10" =>
         case size is
           when 16 =>
             op.data := (others => '0');
             op.data(15 downto 0) := data(15 downto 0);
           when 8 =>
             op.data := (others => '0');
             op.data(15 downto 8) := data(15 downto 8);
           when others =>
             assert false
             report "invalid address aligment"
             severity error;
         end case;
         op.data(31 downto 16) := (others => '0');
         op.data(15 downto 0) := data(15 downto 0);
       when "11" =>
         case size is
           when 8 =>
             op.data := (others => '0');
             op.data(7 downto 0) := data(7 downto 0);
           when others =>
             assert false
             report "invalid address aligment"
             severity error;
         end case;
       when others =>
         assert false
         report "invalid address aligment"
         severity error;
     end case;
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := size;        
     op.store := true;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     while true loop
       while atmo.fin /= '1' loop
         wait until atmo.fin = '1';
       end loop;
       atmi.useid <= '1';
       atmi.id <= id;
       atmi.get <= '1';
       wait until atmo.getack = '1';
       if atmo.rdy = '1' then
         exit;
       end if;
       atmi.useid <= '0'; atmi.get <= '0';
       wait until atmo.getack = '0';
     end loop;
     if screenoutput then
       Print(tost(size) & "-bit write, Address: " &
              tost(address) & " Data: " & tost(data) &
              " Resp: " & resp_to_str(atmo.op.response));
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
   end procedure;

   -- idlecycles: number of added idlecycles before access
   procedure at_write(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant size:          in    integer := 32;
     constant first:         in    boolean := false;
     constant burst:         in    boolean := false;
     constant idlecycles:    in    integer := 0;
     constant dbglevel:      in    integer := 1;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable id:                  integer;
     variable ready:               boolean;
     variable back2back:           boolean;
   begin
     if idlecycles /= 0 then back2back := false; else back2back := true; end if;
     at_write_nb(address => address, data => data, waitcycles => idlecycles,
                 lock => false, hprot => "0011", back2back => back2back, 
                 screenoutput => false, dbglevel => dbglevel,
                 discard => false, size => size, first => first, 
                 burst => burst, id => id, atmi => atmi, atmo => atmo);
     at_write_nb_fin(id => id, wait_for_op => true, screenoutput => false,
                     ready => ready, atmi => atmi, atmo => atmo);
   end procedure;

   -----------------------------------------------------------------------------
   -- Non-Blocking write access (selectable size, max 32-bits)
   -----------------------------------------------------------------------------
   -- Initiate write
   procedure at_write_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant dbglevel:      in    integer := 0;
     constant discard:       in    boolean := false;
     constant size:          in    integer := 32;
     constant first:         in    boolean := false;
     constant burst:         in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
   begin
     op.id := 0;
     op.address := address;
     case address(1 downto 0) is
       when "00" =>
         case size is
           when 32 =>
             op.data(31 downto 0) := data;
           when 16 =>
             op.data(31 downto 16) := data(31 downto 16);
             op.data(15 downto 0) := (others => '0');
           when 8 =>
             op.data(31 downto 24) := data(31 downto 24);
             op.data(23 downto 0) := (others => '0');
           when others =>
             assert false
             report "invalid address aligment"
             severity error;
         end case;
       when "01" =>
         case size is
           when 8 =>
             op.data := (others => '0');
             op.data(23 downto 16) := data(23 downto 16);
           when others =>
             assert false
             report "invalid address aligment"
             severity error;
         end case;
       when "10" =>
         case size is
           when 16 =>
             op.data := (others => '0');
             op.data(15 downto 0) := data(15 downto 0);
           when 8 =>
             op.data := (others => '0');
             op.data(15 downto 8) := data(15 downto 8);
           when others =>
             assert false
             report "invalid address aligment"
             severity error;
         end case;
         op.data(31 downto 16) := (others => '0');
         op.data(15 downto 0) := data(15 downto 0);
       when "11" =>
         case size is
           when 8 =>
             op.data := (others => '0');
             op.data(7 downto 0) := data(7 downto 0);
           when others =>
             assert false
             report "invalid address aligment"
             severity error;
         end case;
       when others =>
         assert false
         report "invalid address aligment"
         severity error;
     end case;
     op.burst := burst; 
     op.beat := 1;
     op.wrap := false;
     op.size := size;        
     op.store := true;
     op.lock := lock;
     op.prot := hprot;
     op.first := first;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := dbglevel;
     op.discard := discard;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     if screenoutput then
       Print(tost(size) & "-bit non-blocking write initiated, Address: " &
             tost(address) & " Data: " & tost(data) & " ID: " & tost(atmo.id));
     end if;
   end procedure;
   
   procedure at_write_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
   begin
     at_write_nb(address => address, data => data, waitcycles => waitcycles,
                 lock => lock, hprot => hprot, back2back => back2back, 
                 screenoutput => screenoutput, dbglevel => 0, discard => false,
                 size => size, first => false, burst => false, 
                 id => id, atmi => atmi, atmo => atmo);
   end procedure;

   -- idlecycles: number of added idlecycles before access
   procedure at_write_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant size:          in    integer := 32;
     constant first:         in    boolean := false;
     constant burst:         in    boolean := false;
     constant idlecycles:    in    integer := 0;
     constant dbglevel:      in    integer := 1;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable id:                  integer;
     variable back2back:           boolean;
   begin
     if idlecycles /= 0 then back2back := false; else back2back := true; end if;
     at_write_nb(address => address, data => data, waitcycles => idlecycles,
                 lock => false, hprot => "0011", back2back => back2back, 
                 screenoutput => false, dbglevel => dbglevel,
                 discard => true, size => size, first => first, 
                 burst => burst, id => id, atmi => atmi, atmo => atmo);
   end procedure;

   --check write has finished and get results
   procedure at_write_nb_fin(
     constant id:            in    integer := 0;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable vready:              boolean;
   begin
     vready := false;
     atmi.useid <= '1';
     atmi.id    <= id;
     atmi.get   <= '1';
     wait until atmo.getack = '1';
     if atmo.rdy = '1' then
       vready := true;
     else
       while wait_for_op loop
         atmi.get <= '0';
         wait until atmo.getack = '0';
         while atmo.fin /= '1' loop
           wait until atmo.fin = '1';
         end loop;
         atmi.get   <= '1';
         wait until atmo.getack = '1';
         if atmo.rdy = '1' then
           vready := true;
           exit;
         end if;
       end loop;
     end if;
     ready := vready; erresp := false;
     if vready then
       if atmo.op.response /= "00" then
         erresp := true;
       end if;
     end if;
     if (atmo.rdy = '1') and screenoutput then
       Print(tost(atmo.op.size) & "-bit non-blocking write finished Address: " &
             tost(atmo.op.address) & " Data: " & tost(atmo.op.data) &
             " Resp: " & resp_to_str(atmo.op.response) &
             " ID: " & tost(atmo.op.id));
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
     wait until atmo.getack = '0';
   end procedure;

   procedure at_write_nb_fin(
     constant id:            in    integer := 0;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable erresp:              boolean;
   begin
     at_write_nb_fin(id, wait_for_op, screenoutput, ready, erresp, atmi, atmo);
   end procedure;
      
   procedure at_write_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable addr:                std_logic_vector(ADDR_R);
     variable id:                  id_vector(data'range);
     variable i:                   integer;
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     if (beat /= 1) and (beat /= data'length) then
       assert false
       report "data vector and beat lengths do not match. ending operation"
       severity error;
     else  
       for i in data'range loop
         --print("add");
         op.id := 0;
         op.address := addr; 
         op.data := data(i);
         op.burst := true; 
         op.beat := beat;
         op.wrap := wrap;
         op.size := 32;        
         op.store := true;
         op.lock := lock;
         op.prot := hprot;
         op.compare := false;     
         op.cmpdata := (others => '0');    
         op.erresp := false;     
         op.split := false;      
         op.retry := false;      
         op.dbglevel := 0;
         op.discard := false;
         if i = data'low then
           op.first := true;
           op.wait_start := waitcycles;
           op.back2back := back2back;
         else
           op.first := false;
           op.wait_start := 0;
           op.back2back := true;
         end if;
         atmi.op  <= op;
         atmi.add <= '1';
         wait until atmo.addack = '1';
         id(i) := atmo.id;
         atmi.add <= '0';
         wait until atmo.addack = '0';
         addr := addr + 4;
         if wrap then
           case beat is
             when 4 =>
               if addr(3 downto 0) = zero32(3 downto 0) then
                 addr(addr'high downto 4) := addr(addr'high downto 4) - 1;
               end if;
             when 8 =>
               if addr(4 downto 0) = zero32(4 downto 0) then
                 addr(addr'high downto 5) := addr(addr'high downto 5) - 1;
               end if;
             when 16 =>
               if addr(5 downto 0) = zero32(5 downto 0) then
                 addr(addr'high downto 6) := addr(addr'high downto 6) - 1;
               end if;
             when others =>
               null;
           end case;
         end if;
       end loop;
       i := 0;
       while i < data'length loop
         while atmo.fin /= '1' loop
           wait until atmo.fin = '1';
         end loop;
         while atmo.fin /= '0' loop
           wait until atmo.fin = '0';
         end loop;
         i := i + 1;
       end loop;
       addr := address;
       for i in data'range loop
         while true loop
           atmi.useid <= '1';
           atmi.id <= id(i);
           atmi.get <= '1';
           wait until atmo.getack = '1';
           if atmo.rdy = '1' then
             if atmo.op.response /= "00" then
               erresp(i) := true;
             else
               erresp(i) := false;
             end if;
             exit;
           end if;
           atmi.useid <= '0'; atmi.get <= '0';
           wait until atmo.getack = '0';
         end loop;
         atmi.useid <= '0'; atmi.get <= '0';
         if atmo.getack = '1' then
           wait until atmo.getack = '0';
         end if;
         if screenoutput then
           Print("32-bit write burst Address: " & tost(addr) & " Data: " &
                 tost(data(i)) & " Resp: " & resp_to_str(atmo.op.response));
         end if;
         addr := addr + 4;
       end loop;     
       atmi.useid <= '0'; atmi.get <= '0';
     end if;
   end procedure;
   
   procedure at_write_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable addr:                std_logic_vector(ADDR_R);
     variable erresp:              response_vector(data'range);
   begin
     at_write_burst_32(address, data, beat, wrap, waitcycles, lock, hprot,
                       back2back, screenoutput, erresp, atmi, atmo);
   end procedure;

   procedure at_write_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable addr:                std_logic_vector(ADDR_R);
     variable erresp:              response_vector(data'range);
   begin
     at_write_burst_32(address, data, beat, wrap, 0, false, "0011",
                       true, false, erresp, atmi, atmo);
   end procedure;

   procedure at_write_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector) is
     variable addr:                std_logic_vector(ADDR_R);
     variable id:                  id_vector(data'range);
     variable i:                   integer;
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     if (beat /= 1) and (beat /= data'length) then
       assert false
       report "data vector and beat lengths do not match. ending operation"
       severity error;
     else  
       for i in data'range loop
         --print("add");
         op.id := 0;
         op.address := addr; 
         op.data := data(i);
         op.burst := true; 
         op.beat := beat;
         op.wrap := wrap;
         op.size := 32;        
         op.store := true;
         op.lock := lock;
         op.prot := hprot;
         op.compare := false;     
         op.cmpdata := (others => '0');    
         op.erresp := false;     
         op.split := false;      
         op.retry := false;      
         op.dbglevel := 0;
         op.discard := false;
         if i = data'low then
           op.first := true;
           op.wait_start := waitcycles;
           op.back2back := back2back;
         else
           op.first := false;
           op.wait_start := 0;
           op.back2back := true;
         end if;
         atmi(master).op  <= op;
         atmi(master).add <= '1';
         wait until atmo(master).addack = '1';
         id(i) := atmo(master).id;
         atmi(master).add <= '0';
         wait until atmo(master).addack = '0';
         addr := addr + 4;
         if wrap then
           case beat is
             when 4 =>
               if addr(3 downto 0) = zero32(3 downto 0) then
                 addr(addr'high downto 4) := addr(addr'high downto 4) - 1;
               end if;
             when 8 =>
               if addr(4 downto 0) = zero32(4 downto 0) then
                 addr(addr'high downto 5) := addr(addr'high downto 5) - 1;
               end if;
             when 16 =>
               if addr(5 downto 0) = zero32(5 downto 0) then
                 addr(addr'high downto 6) := addr(addr'high downto 6) - 1;
               end if;
             when others =>
               null;
           end case;
         end if;
       end loop;
       i := 0;
       while i < data'length loop
         while atmo(master).fin /= '1' loop
           wait until atmo(master).fin = '1';
         end loop;
         while atmo(master).fin /= '0' loop
           wait until atmo(master).fin = '0';
         end loop;
         i := i + 1;
       end loop;
       addr := address;
       for i in data'range loop
         while true loop
           atmi(master).useid <= '1';
           atmi(master).id <= id(i);
           atmi(master).get <= '1';
           wait until atmo(master).getack = '1';
           if atmo(master).rdy = '1' then
             if atmo(master).op.response /= "00" then
               erresp(i) := true;
             else
               erresp(i) := false;
             end if;
             exit;
           end if;
           atmi(master).useid <= '0'; atmi(master).get <= '0';
           wait until atmo(master).getack = '0';
         end loop;
         atmi(master).useid <= '0'; atmi(master).get <= '0';
         if atmo(master).getack = '1' then
           wait until atmo(master).getack = '0';
         end if;
         if screenoutput then
           Print("32-bit write burst Address: " & tost(addr) & " Data: " &
                 tost(data(i)) & " Resp: " & resp_to_str(atmo(master).op.response));
         end if;
         addr := addr + 4;
       end loop;     
       atmi(master).useid <= '0'; atmi(master).get <= '0';
     end if;
   end procedure;

   procedure at_write_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable vid:                 id_vector(data'range);
     variable addr:                std_logic_vector(ADDR_R);
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     for i in data'range loop
       --print("add");
       op.id := 0;
       op.address := addr; 
       op.data := data(i);
       op.burst := true; 
       op.beat := beat;
       op.wrap := wrap;
       op.size := 32;        
       op.store := true;
       op.lock := lock;
       op.prot := hprot;
       op.compare := false;     
       op.cmpdata := (others => '0');    
       op.erresp := false;     
       op.split := false;      
       op.retry := false;      
       op.dbglevel := 0;
       op.discard := false;
       if i = data'low then
         op.first := true;
         op.wait_start := waitcycles;
         op.back2back := back2back;
       else
         op.first := false;
         op.wait_start := 0;
         op.back2back := true;
       end if;
       atmi.op  <= op;
       atmi.add <= '1';
       wait until atmo.addack = '1';
       vid(i) := atmo.id;
       atmi.add <= '0';
       wait until atmo.addack = '0';
       if screenoutput then
         Print("32-bit write burst non-blocking initiated, Address: " & tost(addr) &
               " Data: " & tost(data(i)) &
               " ID : " & tost(atmo.id)); 
       end if;
       addr := addr + 4;
     end loop;
     id := vid;
   end procedure;

   procedure at_write_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector) is
     variable vid:                 id_vector(data'range);
     variable addr:                std_logic_vector(ADDR_R);
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     for i in data'range loop
       --print("add");
       op.id := 0;
       op.address := addr; 
       op.data := data(i);
       op.burst := true; 
       op.beat := beat;
       op.wrap := wrap;
       op.size := 32;        
       op.store := true;
       op.lock := lock;
       op.prot := hprot;
       op.compare := false;     
       op.cmpdata := (others => '0');    
       op.erresp := false;     
       op.split := false;      
       op.retry := false;      
       op.dbglevel := 0;
       op.discard := false;
       if i = data'low then
         op.first := true;
         op.wait_start := waitcycles;
         op.back2back := back2back;
       else
         op.first := false;
         op.wait_start := 0;
         op.back2back := true;
       end if;
       atmi(master).op  <= op;
       atmi(master).add <= '1';
       wait until atmo(master).addack = '1';
       vid(i) := atmo(master).id;
       atmi(master).add <= '0';
       wait until atmo(master).addack = '0';
       if screenoutput then
         Print("32-bit write burst non-blocking initiated, Address: " & tost(addr) &
               " Data: " & tost(data(i)) &
               " ID : " & tost(atmo(master).id)); 
       end if;
       addr := addr + 4;
     end loop;
     id := vid;
   end procedure;

   --standard non-blocking write burst procedure but with the
   --ability to insert busy cycles
   procedure at_write_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant busy:          in    busy_cycle_vector;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable vid:                 id_vector(data'range);
     variable addr:                std_logic_vector(ADDR_R);
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     for i in data'range loop
       --print("add");
       op.id := 0;
       op.address := addr; 
       op.data := data(i);
       op.burst := true; 
       op.beat := beat;
       op.wrap := wrap;
       op.size := 32;        
       op.store := true;
       op.lock := lock;
       op.prot := hprot;
       op.compare := false;     
       op.cmpdata := (others => '0');    
       op.erresp := false;     
       op.split := false;      
       op.retry := false;      
       op.dbglevel := 0;
       op.discard := false;
       if i = data'low then
         op.first := true;
         op.wait_start := waitcycles;
         op.back2back := back2back;
       else
         op.first := false;
         op.wait_start := busy(i);
         op.back2back := true;
       end if;
       atmi.op  <= op;
       atmi.add <= '1';
       wait until atmo.addack = '1';
       vid(i) := atmo.id;
       atmi.add <= '0';
       wait until atmo.addack = '0';
       if screenoutput then
         Print("32-bit write burst non-blocking initiated, Address: " & tost(addr) &
               " Data: " & tost(data(i)) &
               " ID : " & tost(atmo.id)); 
       end if;
       addr := addr + 4;
     end loop;
     id := vid;
   end procedure;
   
   procedure at_write_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable last_op:             at_ahb_mst_op_type;
     variable vready:              boolean;
   begin
     vready := false;
     for i in erresp'range loop
       erresp(i) := false;
     end loop;
     if id'length = erresp'length then
       atmi.useid <= '1';
       atmi.id <= id(id'high);
       atmi.get <= '1';
       wait until atmo.getack = '1';
       if atmo.rdy = '1' then
         vready := true;
         last_op := atmo.op;
         atmi.useid <= '0'; atmi.get <= '0';
         wait until atmo.getack = '0';
       else
         atmi.useid <= '0'; atmi.get <= '0';
         wait until atmo.getack = '0';
         while wait_for_op loop
           while atmo.fin /= '1' loop
             wait until atmo.fin = '1';
           end loop;
           while atmo.fin /= '0' loop
             wait until atmo.fin = '0';
           end loop;
           atmi.useid <= '1';
           atmi.id <= id(id'high);
           atmi.get <= '1';
           wait until atmo.getack = '1';
           if atmo.rdy = '1' then
             vready := true;
           end if;
           last_op := atmo.op;
           atmi.useid <= '0'; atmi.get <= '0';
           wait until atmo.getack = '0';
           if vready then
             exit;
           end if;
         end loop;
       end if;
       
       if vready then
         for i in 0 to id'length-1 loop
           atmi.useid <= '1';
           atmi.id <= id(id'low+i);
           atmi.get <= '1';
           wait until atmo.getack = '1';
           atmi.useid <= '0'; atmi.get <= '0';
           wait until atmo.getack = '0';
           atmi.useid <= '0'; atmi.get <= '0';
           if atmo.getack = '1' then
             wait until atmo.getack = '0';
           end if;
           if atmo.op.response /= "00" then
             erresp(erresp'low+i) := true;
           else
             erresp(erresp'low+i) := false;
           end if;
           if screenoutput then
             Print("32-bit write burst finished, Address: " & tost(atmo.op.address) &
                   " Data: " & tost(atmo.op.data) &
                   " Resp: " & resp_to_str(atmo.op.response) &
                   " ID :  " & tost(atmo.op.id)); 
           end if;
         end loop;
         if last_op.response /= "00" then
           erresp(erresp'high) := true;
         else
           erresp(erresp'high) := false;
         end if;
         if screenoutput then
           Print("32-bit write burst finished, Address: " & tost(last_op.address) &
                 " Data: " & tost(last_op.data) &
                 " Resp: " & resp_to_str(last_op.response) &
                 " ID:   " & tost(last_op.id)); 
         end if;
       end if;
       ready := vready;
     else
       Print("ERROR: vector lengths do not match");
     end if;
   end procedure;

   procedure at_write_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable erresp:              response_vector(id'range);
   begin
     at_write_burst_32_nb_fin(id, wait_for_op, screenoutput, ready, erresp,
                              atmi, atmo);
   end procedure;

   procedure at_write_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable ready:         out   boolean;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector) is
     variable last_op:             at_ahb_mst_op_type;
     variable vready:              boolean;
   begin
     vready := false; ready := false;
     for i in erresp'range loop
       erresp(i) := false;
     end loop;
     if id'length = erresp'length then
       atmi(master).useid <= '1';
       atmi(master).id <= id(id'high);
       atmi(master).get <= '1';
       wait until atmo(master).getack = '1';
       if atmo(master).rdy = '1' then
         vready := true;
         last_op := atmo(master).op;
         atmi(master).useid <= '0'; atmi(master).get <= '0';
         wait until atmo(master).getack = '0';
       else
         atmi(master).useid <= '0'; atmi(master).get <= '0';
         wait until atmo(master).getack = '0';
         while wait_for_op loop
           while atmo(master).fin /= '1' loop
             wait until atmo(master).fin = '1';
           end loop;
           while atmo(master).fin /= '0' loop
             wait until atmo(master).fin = '0';
           end loop;
           atmi(master).useid <= '1';
           atmi(master).id <= id(id'high);
           atmi(master).get <= '1';
           wait until atmo(master).getack = '1';
           if atmo(master).rdy = '1' then
             vready := true;
           end if;
           last_op := atmo(master).op;
           atmi(master).useid <= '0'; atmi(master).get <= '0';
           wait until atmo(master).getack = '0';
           if vready then
             exit;
           end if;
         end loop;
       end if;
       
       if vready then
         for i in 0 to id'length-1 loop
           atmi(master).useid <= '1';
           atmi(master).id <= id(id'low+i);
           atmi(master).get <= '1';
           wait until atmo(master).getack = '1';
           atmi(master).useid <= '0'; atmi(master).get <= '0';
           wait until atmo(master).getack = '0';
           atmi(master).useid <= '0'; atmi(master).get <= '0';
           if atmo(master).getack = '1' then
             wait until atmo(master).getack = '0';
           end if;
           if atmo(master).op.response /= "00" then
             erresp(erresp'low+i) := true;
           else
             erresp(erresp'low+i) := false;
           end if;
           if screenoutput then
             Print("32-bit write burst finished, Address: " & tost(atmo(master).op.address) &
                   " Data: " & tost(atmo(master).op.data) &
                   " Resp: " & resp_to_str(atmo(master).op.response)); 
           end if;
         end loop;
         if last_op.response /= "00" then
           erresp(erresp'high) := true;
         else
           erresp(erresp'high) := false;
         end if;
           if screenoutput then
             Print("32-bit write burst finished, Address: " & tost(last_op.address) &
                   " Data: " & tost(last_op.data) &
                   " Resp: " & resp_to_str(last_op.response)); 
           end if;
       end if;
       ready := vready;
     else
       Print("ERROR: vector lengths do not match");
     end if;
   end procedure;

   procedure at_read_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
   begin
     op.id := 0;
     op.address := address; 
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := 32;        
     op.store := false;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi.op <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     if screenoutput then
       Print("32-bit non_blocking read initiated Address:" & tost(address));
     end if;
   end procedure at_read_32_nb;

   procedure at_read_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector) is
     variable op : at_ahb_mst_op_type;
   begin
     op.id := 0;
     op.address := address; 
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := 32;        
     op.store := false;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi(master).op <= op;
     atmi(master).add <= '1';
     wait until atmo(master).addack = '1';
     id := atmo(master).id;
     atmi(master).add <= '0';
     wait until atmo(master).addack = '0';
     if screenoutput then
       Print("32-bit non_blocking read initiated Address:" & tost(address));
     end if;
   end procedure at_read_32_nb;
     
   
   --check if read has finished and get results
   procedure at_read_32_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
     variable vready:              boolean;
   begin
     vready := false; erresp := false;
     atmi.useid <= '1';
     atmi.id    <= id;
     atmi.get   <= '1';
     wait until atmo.getack = '1';
     if atmo.rdy = '1' then
       vready := true;
     else
       while wait_for_op loop
         atmi.get <= '0';
         wait until atmo.getack = '0';
         while atmo.fin /= '1' loop
           wait until atmo.fin = '1';
         end loop;
         atmi.get   <= '1';
         wait until atmo.getack = '1';
         if atmo.rdy = '1' then
           vready := true;
           exit;
         end if;
       end loop;
     end if;
     ready := vready; erresp := false;
     if vready then
       op := atmo.op;
       data := atmo.op.data;
       if atmo.op.response /= "00" then
         erresp := true;
       end if;
     end if;
     if (atmo.rdy = '1') and screenoutput then
       Print("32-bit non_blocking read finished Address: " & tost(atmo.op.address) &
             " Data: " & tost(atmo.op.data) & " " & resp_to_str(atmo.op.response));
     end if;
     atmi.useid <= '0';
     atmi.get <= '0';
     wait until atmo.getack = '0';
   end procedure at_read_32_nb_fin;

   procedure at_read_32_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector) is
     variable op:                  at_ahb_mst_op_type;
     variable vready:              boolean;
   begin
     vready := false; erresp := false;
     atmi(master).useid <= '1';
     atmi(master).id    <= id;
     atmi(master).get   <= '1';
     wait until atmo(master).getack = '1';
     if atmo(master).rdy = '1' then
       vready := true;
     else
       while wait_for_op loop
         atmi(master).get <= '0';
         wait until atmo(master).getack = '0';
         while atmo(master).fin /= '1' loop
           wait until atmo(master).fin = '1';
         end loop;
         atmi(master).get   <= '1';
         wait until atmo(master).getack = '1';
         if atmo(master).rdy = '1' then
           vready := true;
           exit;
         end if;
       end loop;
     end if;
     ready := vready; erresp := false;
     if vready then
       op := atmo(master).op;
       data := atmo(master).op.data;
       if atmo(master).op.response /= "00" then
         erresp := true;
       end if;
     end if;
     if (atmo(master).rdy = '1') and screenoutput then
       Print("32-bit non_blocking read finished Address: " & tost(atmo(master).op.address) &
             " Data: " & tost(atmo(master).op.data) & " " & resp_to_str(atmo(master).op.response));
     end if;
     atmi(master).useid <= '0'; atmi(master).get <= '0';
     wait until atmo(master).getack = '0';
   end procedure at_read_32_nb_fin;

   procedure at_read_32_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable erresp:              boolean;
   begin
     at_read_32_nb_fin(id, wait_for_op, screenoutput, ready, data,
                       erresp, atmi, atmo);
   end procedure at_read_32_nb_fin;

   -----------------------------------------------------------------------------
   -- Blocking 8-bit read access 
   -----------------------------------------------------------------------------
   procedure at_read_8(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(7 downto 0);
     variable errorresp:     out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
     variable id:                  integer;
     variable vdata:               std_logic_vector(7 downto 0);
   begin
     op.id := 0;
     op.address := address; 
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := 8;        
     op.store := false;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     while true loop
       while atmo.fin /= '1' loop
         wait until atmo.fin = '1';
       end loop;
       atmi.useid <= '1';
       atmi.id    <= id;
       atmi.get   <= '1';
       wait until atmo.getack = '1';
       if atmo.rdy = '1' then
         op := atmo.op;
         case address(1 downto 0) is
           when "00" =>
             vdata := atmo.op.data(31 downto 24);
           when "01" =>
             vdata := atmo.op.data(23 downto 16);
           when "10" =>
             vdata := atmo.op.data(15 downto 8);
           when "11" =>
             vdata := atmo.op.data(7 downto 0);
           when others =>
             null;
         end case;
         if atmo.op.response /= "00" then
           errorresp := true;
         else
           errorresp := false;
         end if;
         exit;
       end if;
       atmi.useid <= '0'; atmi.get <= '0';
       wait until atmo.getack = '0';
     end loop;
     data := vdata;
     if screenoutput then
       Print("8-bit read, Address: " & tost(atmo.op.address) & " Data: " &
             tost(vdata) & " Resp: " & " " & resp_to_str(atmo.op.response));
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
   end procedure;

   procedure at_read_8(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(7 downto 0);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable errorresp:           boolean;
   begin
     at_read_8(address, waitcycles, lock, hprot, back2back, screenoutput,
       data, errorresp, atmi, atmo);
   end procedure;

   -----------------------------------------------------------------------------
   -- Blocking 16-bit read access 
   -----------------------------------------------------------------------------
   procedure at_read_16(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(15 downto 0);
     variable errorresp:     out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
     variable id:                  integer;
     variable vdata:               std_logic_vector(15 downto 0);
   begin
     op.id := 0;
     op.address := address; 
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := 16;        
     op.store := false;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     while true loop
       while atmo.fin /= '1' loop
         wait until atmo.fin = '1';
       end loop;
       atmi.useid <= '1';
       atmi.id    <= id;
       atmi.get   <= '1';
       wait until atmo.getack = '1';
       if atmo.rdy = '1' then
         op := atmo.op;
         case address(1 downto 0) is
           when "00" =>
             vdata := atmo.op.data(31 downto 16);
           when "10" =>
             vdata := atmo.op.data(15 downto 0);
           when others =>
             assert false
             report "illegal address alignment"
             severity error;
             null;
         end case;
         if atmo.op.response /= "00" then
           errorresp := true;
         else
           errorresp := false;
         end if;
         exit;
       end if;
       atmi.useid <= '0'; atmi.get <= '0';
       wait until atmo.getack = '0';
     end loop;
     data := vdata;
     if screenoutput then
       Print("16-bit read, Address: " & tost(atmo.op.address) & " Data: " &
             tost(vdata) & " Resp: " & resp_to_str(atmo.op.response));
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
   end procedure;

   procedure at_read_16(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(15 downto 0);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable errorresp:           boolean;
   begin
     at_read_16(address, waitcycles, lock, hprot, back2back, screenoutput,
       data, errorresp, atmi, atmo);
   end procedure;
   
   procedure at_read_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(DATA_R);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
     variable id:                  integer;
   begin
     op.id := 0;
     op.address := address; 
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := 32;        
     op.store := false;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     while true loop
       while atmo.fin /= '1' loop
         wait until atmo.fin = '1';
       end loop;
       atmi.useid <= '1';
       atmi.id    <= id;
       atmi.get   <= '1';
       wait until atmo.getack = '1';
       if atmo.rdy = '1' then
         op := atmo.op;
         data := atmo.op.data;
         if atmo.op.response /= "00" then
           erresp := true;
         else
           erresp := false;
         end if;
         exit;
       end if;
       atmi.useid <= '0'; atmi.get <= '0';
       wait until atmo.getack = '0';
     end loop;
     if screenoutput then
       Print("32-bit read, Address: " & tost(atmo.op.address) & " Data: " &
             tost(atmo.op.data) & " Resp: " & resp_to_str(atmo.op.response));
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
   end procedure at_read_32;


   procedure at_read_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable erresp:              boolean;
   begin
     at_read_32(address, waitcycles, lock, hprot, back2back, screenoutput,
                data, erresp, atmi, atmo);
   end procedure at_read_32;

   procedure at_read_32(
     constant address:       in    std_logic_vector(ADDR_R);
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable erresp:              boolean;
   begin
     at_read_32(address, 0, false, "0011", true, false,
                data, erresp, atmi, atmo);
   end procedure;
   
   -----------------------------------------------------------------------------
   -- Blocking read access (selectable size 8-, 16- and 32-bits)
   -----------------------------------------------------------------------------
   --reads the number of bits specified in size at the address specified in address
   --if the aligment is illegal data will not be returned (the data variable is
   --untouched) and an error message is printed.
   --only the number of bits specified in size will be modified in data although
   --it is 32-bits wide. The range is determined by address. For example:
   --address X"00000003" size=8 will modify data(7 downto 0)
   
   procedure at_read(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     variable data:          inout std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
     variable id:                  integer;
   begin
     op.id := 0;
     op.address := address; 
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := size;        
     op.store := false;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;
     op.dbglevel := 0;
     op.discard := false;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     while true loop
       while atmo.fin /= '1' loop
         wait until atmo.fin = '1';
       end loop;
       atmi.useid <= '1';
       atmi.id    <= id;
       atmi.get   <= '1';
       wait until atmo.getack = '1';
       if atmo.rdy = '1' then
         op := atmo.op;
         case address(1 downto 0) is
           when "00" =>
             case size is
               when 32 =>
                 data := atmo.op.data;
               when 16 =>
                 data(31 downto 16) := atmo.op.data(31 downto 16);
               when 8 =>
                 data(31 downto 24) := atmo.op.data(31 downto 24);
               when others =>
                 null;
             end case;
           when "01" =>
             case size is
               when 8 =>
                 data(23 downto 16) := atmo.op.data(23 downto 16);
               when others =>
                 assert false
                 report "illegal alignment"
                 severity error;
             end case;
           when "10" =>
             case size is
               when 16 =>
                 data(15 downto 0) := atmo.op.data(15 downto 0);
               when 8 =>
                 data(15 downto 8) := atmo.op.data(15 downto 8);
               when others =>
                 assert false
                 report "illegal alignment"
                 severity error;
             end case;
           when "11" =>
             case size is
               when 8 =>
                 data(7 downto 0) := atmo.op.data(7 downto 0);
               when others =>
                 assert false
                 report "illegal alignment"
                 severity error;
             end case;
           when others =>
             null;
         end case;
         exit;
       end if;
       atmi.useid <= '0'; atmi.get <= '0';
       wait until atmo.getack = '0';
     end loop;
     if screenoutput then
       Print(tost(size) & "-bit read, Address: " & tost(atmo.op.address) & 
             " Data: " & tost(atmo.op.data) & " Resp: " & resp_to_str(atmo.op.response));
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
   end procedure;

   -----------------------------------------------------------------------------
   -- Non-blocking read access (selectable size 8-, 16- and 32-bits)
   -----------------------------------------------------------------------------
   --initiate read
   procedure at_read_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
   begin
     op.id := 0;
     op.address := address; 
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := size;        
     op.store := false;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := false;     
     op.cmpdata := (others => '0');    
     op.erresp := false;     
     op.split := false;      
     op.retry := false;      
     op.dbglevel := 0;
     op.discard := false;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     if screenoutput then
       Print(tost(size) & "-bit read initiated, Address:  " &
             tost(address) & " ID: " & tost(atmo.id));
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
   end procedure;

   --check if read has finished and get results
   procedure at_read_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable vready:              boolean;
     variable hi, li:              integer;
   begin
     vready := false; erresp := false;
     atmi.useid <= '1';
     atmi.id    <= id;
     atmi.get   <= '1';
     wait until atmo.getack = '1';
     if atmo.rdy = '1' then
       vready := true;
     else
       while wait_for_op loop
         atmi.get <= '0';
         wait until atmo.getack = '0';
         while atmo.fin /= '1' loop
           wait until atmo.fin = '1';
         end loop;
         atmi.get   <= '1';
         wait until atmo.getack = '1';
         if atmo.rdy = '1' then
           vready := true;
           exit;
         end if;
       end loop;
     end if;
     ready := vready; erresp := false;
     if vready then
       case atmo.op.address(1 downto 0) is
         when "00" =>
           case atmo.op.size is
             when 32 =>
               data := atmo.op.data;
               hi := 31; li := 0;
             when 16 =>
               data(31 downto 16) := atmo.op.data(31 downto 16);
               hi := 31; li := 16;
             when 8 =>
               data(31 downto 24) := atmo.op.data(31 downto 24);
               hi := 7; li := 0;
             when others =>
               null;
           end case;
         when "01" =>
           case atmo.op.size is
             when 8 =>
               data(23 downto 16) := atmo.op.data(23 downto 16);
               hi := 23; li := 16;
             when others =>
               assert false
               report "illegal alignment"
               severity error;
           end case;
         when "10" =>
           case atmo.op.size is
             when 16 =>
               data(15 downto 0) := atmo.op.data(15 downto 0);
               hi := 15; li := 0;
             when 8 =>
               data(15 downto 8) := atmo.op.data(15 downto 8);
               hi := 15; li := 8;
             when others =>
               assert false
               report "illegal alignment"
               severity error;
           end case;
         when "11" =>
           case atmo.op.size is
             when 8 =>
               data(7 downto 0) := atmo.op.data(7 downto 0);
               hi := 7; li := 0;
             when others =>
               assert false
               report "illegal alignment"
               severity error;
           end case;
         when others =>
           null;
       end case;
       data := atmo.op.data;
       if atmo.op.response /= "00" then
         erresp := true;
       end if;
     end if;
     if (atmo.rdy = '1') and screenoutput then
       Print(tost(atmo.op.size) & "-bit read, Address: " & tost(atmo.op.address) & 
             " Data: " & tost(atmo.op.data(hi downto li)) & " Resp: " & resp_to_str(atmo.op.response) &
             " ID: " & tost(atmo.op.id));
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
     wait until atmo.getack = '0';
   end procedure;

   procedure at_read_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable erresp:              boolean;
   begin
     at_read_nb_fin(id, wait_for_op, screenoutput, ready, data, erresp,
                    atmi, atmo);
   end procedure;
   
   procedure at_read_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   data_vector;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable addr:                std_logic_vector(ADDR_R);
     variable id:                  id_vector(data'range);
     variable i:                   integer;
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     for i in data'range loop
       op.id := 0;
       op.address := addr; 
       op.burst := true; 
       op.beat := beat;
       op.wrap := wrap;
       op.size := 32;        
       op.store := false;
       op.lock := lock;
       op.prot := hprot;
       op.compare := false;     
       op.cmpdata := (others => '0');    
       op.erresp := false;     
       op.split := false;      
       op.retry := false;      
       op.dbglevel := 0;
       op.discard := false;
       if i = data'low then
         op.first := true;
         op.wait_start := waitcycles;
         op.back2back := back2back;
       else
         op.first := false;
         op.wait_start := 0;
         op.back2back := true;
       end if;
       atmi.op  <= op;
       atmi.add <= '1';
       wait until atmo.addack = '1';
       id(i) := atmo.id;
       atmi.add <= '0';
       wait until atmo.addack = '0';
       addr := addr + 4;
       if wrap then
         case beat is
           when 4 =>
             if addr(3 downto 0) = zero32(3 downto 0) then
               addr(addr'high downto 4) := addr(addr'high downto 4) - 1;
             end if;
           when 8 =>
             if addr(4 downto 0) = zero32(4 downto 0) then
               addr(addr'high downto 5) := addr(addr'high downto 5) - 1;
             end if;
           when 16 =>
             if addr(5 downto 0) = zero32(5 downto 0) then
                 addr(addr'high downto 6) := addr(addr'high downto 6) - 1;
             end if;
           when others =>
             null;
         end case;
       end if;
     end loop;

     i := 0;
     while i < data'length loop
       while atmo.fin /= '1' loop
         wait until atmo.fin = '1';
       end loop;
       while atmo.fin /= '0' loop
         wait until atmo.fin = '0';
       end loop;
       i := i + 1;
     end loop;
     addr := address;
     for i in data'range loop
       while true loop
         atmi.useid <= '1';
         atmi.id <= id(i);
         atmi.get <= '1';
         wait until atmo.getack = '1';
         if atmo.rdy = '1' then
           if atmo.op.response /= "00" then
             erresp(i) := true;
           else
             erresp(i) := false;
           end if;
           exit;
         end if;
         atmi.useid <= '0'; atmi.get <= '0';
         wait until atmo.getack = '0';
       end loop;
       atmi.useid <= '0'; atmi.get <= '0';
       op := atmo.op;
       if atmo.getack = '1' then
         wait until atmo.getack = '0';
       end if;
       data(i) := atmo.op.data;
       if screenoutput then
         Print("32-bit read burst, Address: " & tost(addr) & 
               " Data: " & tost(atmo.op.data) & " Resp: " &
               resp_to_str(op.response));
       end if;
       addr := addr + 4;
     end loop;     
     atmi.useid <= '0'; atmi.get <= '0';
   end procedure;
   
   procedure at_read_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   data_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable erresp:              response_vector(data'range);
   begin
     at_read_burst_32(address, beat, wrap, waitcycles, lock, hprot, 
       back2back, screenoutput, data, erresp, atmi, atmo);
   end procedure;

   procedure at_read_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable data:          out   data_vector;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector) is
     variable addr:                std_logic_vector(ADDR_R);
     variable id:                  id_vector(data'range);
     variable i:                   integer;
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     for i in data'range loop
       op.id := 0;
       op.address := addr; 
       op.burst := true; 
       op.beat := beat;
       op.wrap := wrap;
       op.size := 32;        
       op.store := false;
       op.lock := lock;
       op.prot := hprot;
       op.compare := false;     
       op.cmpdata := (others => '0');    
       op.erresp := false;     
       op.split := false;      
       op.retry := false;      
       op.dbglevel := 0;
       op.discard := false;
       if i = data'low then
         op.first := true;
         op.wait_start := waitcycles;
         op.back2back := back2back;
       else
         op.first := false;
         op.wait_start := 0;
         op.back2back := true;
       end if;
       atmi(master).op  <= op;
       atmi(master).add <= '1';
       wait until atmo(master).addack = '1';
       id(i) := atmo(master).id;
       atmi(master).add <= '0';
       wait until atmo(master).addack = '0';
       addr := addr + 4;
       if wrap then
         case beat is
           when 4 =>
             if addr(3 downto 0) = zero32(3 downto 0) then
               addr(addr'high downto 4) := addr(addr'high downto 4) - 1;
             end if;
           when 8 =>
             if addr(4 downto 0) = zero32(4 downto 0) then
               addr(addr'high downto 5) := addr(addr'high downto 5) - 1;
             end if;
           when 16 =>
             if addr(5 downto 0) = zero32(5 downto 0) then
                 addr(addr'high downto 6) := addr(addr'high downto 6) - 1;
             end if;
           when others =>
             null;
         end case;
       end if;
     end loop;

     i := 0;
     while i < data'length loop
       while atmo(master).fin /= '1' loop
         wait until atmo(master).fin = '1';
       end loop;
       while atmo(master).fin /= '0' loop
         wait until atmo(master).fin = '0';
       end loop;
       i := i + 1;
     end loop;
     addr := address;
     for i in data'range loop
       while true loop
         atmi(master).useid <= '1';
         atmi(master).id <= id(i);
         atmi(master).get <= '1';
         wait until atmo(master).getack = '1';
         if atmo(master).rdy = '1' then
           if atmo(master).op.response /= "00" then
             erresp(i) := true;
           else
             erresp(i) := false;
           end if;
           exit;
         end if;
         atmi(master).useid <= '0'; atmi(master).get <= '0';
         wait until atmo(master).getack = '0';
       end loop;
       atmi(master).useid <= '0'; atmi(master).get <= '0';
       op := atmo(master).op;
       if atmo(master).getack = '1' then
         wait until atmo(master).getack = '0';
       end if;
       data(i) := atmo(master).op.data;
       if screenoutput then
         Print("32-bit read burst, Address: " & tost(addr) & 
               " Data: " & tost(atmo(master).op.data) & " Resp: " &
               resp_to_str(op.response));
       end if;
       addr := addr + 4;
     end loop;     
     atmi(master).useid <= '0'; atmi(master).get <= '0';
   end procedure;
   
   procedure at_read_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant length:        in    integer;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable addr:                std_logic_vector(ADDR_R);
     variable i:                   integer;
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     for i in 0 to length-1 loop
       op.id := 0;
       op.address := addr; 
       op.burst := true; 
       op.beat := beat;
       op.wrap := wrap;
       op.size := 32;        
       op.store := false;
       op.lock := lock;
       op.prot := hprot;
       op.compare := false;     
       op.cmpdata := (others => '0');    
       op.erresp := false;     
       op.split := false;      
       op.retry := false;      
       op.dbglevel := 0;
       op.discard := false;
       if i = 0 then
         op.first := true;
         op.wait_start := waitcycles;
         op.back2back := back2back;
       else
         op.first := false;
         op.wait_start := 0;
         op.back2back := true;
       end if;
       atmi.op  <= op;
       atmi.add <= '1';
       wait until atmo.addack = '1';
       id(i+id'low) := atmo.id;
       atmi.add <= '0';
       wait until atmo.addack = '0';
       if screenoutput then
         Print("32-bit read burst non-blocking, Address: " & tost(addr) &
               " ID: " & tost(atmo.id));
       end if;
       addr := addr + 4;
       if wrap then
         case beat is
           when 4 =>
             if addr(3 downto 0) = zero32(3 downto 0) then
               addr(addr'high downto 4) := addr(addr'high downto 4) - 1;
             end if;
           when 8 =>
             if addr(4 downto 0) = zero32(4 downto 0) then
               addr(addr'high downto 5) := addr(addr'high downto 5) - 1;
             end if;
           when 16 =>
             if addr(5 downto 0) = zero32(5 downto 0) then
                 addr(addr'high downto 6) := addr(addr'high downto 6) - 1;
             end if;
           when others =>
             null;
         end case;
       end if;
     end loop;
   end procedure;

   procedure at_read_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant length:        in    integer;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector) is
     variable addr:                std_logic_vector(ADDR_R);
     variable i:                   integer;
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     for i in 0 to length-1 loop
       op.id := 0;
       op.address := addr; 
       op.burst := true; 
       op.beat := beat;
       op.wrap := wrap;
       op.size := 32;        
       op.store := false;
       op.lock := lock;
       op.prot := hprot;
       op.compare := false;     
       op.cmpdata := (others => '0');    
       op.erresp := false;     
       op.split := false;      
       op.retry := false;      
       op.dbglevel := 0;
       op.discard := false;
       if i = 0 then
         op.first := true;
         op.wait_start := waitcycles;
         op.back2back := back2back;
       else
         op.first := false;
         op.wait_start := 0;
         op.back2back := true;
       end if;
       atmi(master).op  <= op;
       atmi(master).add <= '1';
       wait until atmo(master).addack = '1';
       id(i+id'low) := atmo(master).id;
       atmi(master).add <= '0';
       wait until atmo(master).addack = '0';
       if screenoutput then
         Print("32-bit read burst non-blocking, Address: " & tost(addr) &
               " ID: " & tost(atmo(master).id));
       end if;
       addr := addr + 4;
       if wrap then
         case beat is
           when 4 =>
             if addr(3 downto 0) = zero32(3 downto 0) then
               addr(addr'high downto 4) := addr(addr'high downto 4) - 1;
             end if;
           when 8 =>
             if addr(4 downto 0) = zero32(4 downto 0) then
               addr(addr'high downto 5) := addr(addr'high downto 5) - 1;
             end if;
           when 16 =>
             if addr(5 downto 0) = zero32(5 downto 0) then
                 addr(addr'high downto 6) := addr(addr'high downto 6) - 1;
             end if;
           when others =>
             null;
         end case;
       end if;
     end loop;
   end procedure;

   procedure at_read_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant length:        in    integer;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant busy:          in    busy_cycle_vector;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable addr:                std_logic_vector(ADDR_R);
     variable i:                   integer;
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     for i in 0 to length-1 loop
       op.id := 0;
       op.address := addr; 
       op.burst := true; 
       op.beat := beat;
       op.wrap := wrap;
       op.size := 32;        
       op.store := false;
       op.lock := lock;
       op.prot := hprot;
       op.compare := false;     
       op.cmpdata := (others => '0');    
       op.erresp := false;     
       op.split := false;      
       op.retry := false;      
       op.dbglevel := 0;
       op.discard := false;
       if i = 0 then
         op.first := true;
         op.wait_start := waitcycles;
         op.back2back := back2back;
       else
         op.first := false;
         op.wait_start := busy(i);
         op.back2back := true;
       end if;
       atmi.op  <= op;
       atmi.add <= '1';
       wait until atmo.addack = '1';
       id(i+id'low) := atmo.id;
       atmi.add <= '0';
       wait until atmo.addack = '0';
       if screenoutput then
         Print("32-bit read burst non-blocking initiated, Address: " & tost(addr) &
               " ID: " & tost(atmo.id));
       end if;
       addr := addr + 4;
       if wrap then
         case beat is
           when 4 =>
             if addr(3 downto 0) = zero32(3 downto 0) then
               addr(addr'high downto 4) := addr(addr'high downto 4) - 1;
             end if;
           when 8 =>
             if addr(4 downto 0) = zero32(4 downto 0) then
               addr(addr'high downto 5) := addr(addr'high downto 5) - 1;
             end if;
           when 16 =>
             if addr(5 downto 0) = zero32(5 downto 0) then
                 addr(addr'high downto 6) := addr(addr'high downto 6) - 1;
             end if;
           when others =>
             null;
         end case;
       end if;
     end loop;
   end procedure;
   
   procedure at_read_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   data_vector;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable last_op:             at_ahb_mst_op_type;
     variable vready:              boolean;
   begin
     vready := false;
     for i in erresp'range loop
       erresp(i) := false;
     end loop;
     if (id'length = erresp'length) and (id'length = data'length) then
       atmi.useid <= '1';
       atmi.id <= id(id'high);
       atmi.get <= '1';
       wait until atmo.getack = '1';
       if atmo.rdy = '1' then
         vready := true;
         last_op := atmo.op;
         atmi.useid <= '0'; atmi.get <= '0';
         wait until atmo.getack = '0';
       else
         atmi.useid <= '0';
         atmi.get <= '0';
         wait until atmo.getack = '0';
         while wait_for_op loop
           while atmo.fin /= '1' loop
             wait until atmo.fin = '1';
           end loop;
           while atmo.fin /= '0' loop
             wait until atmo.fin = '0';
           end loop;
           atmi.useid <= '1';
           atmi.id <= id(id'high);
           atmi.get <= '1';
           wait until atmo.getack = '1';
           if atmo.rdy = '1' then
             vready := true;
           end if;
           last_op := atmo.op;
           atmi.useid <= '0'; atmi.get <= '0';
           wait until atmo.getack = '0';
           if vready then
             exit;
           end if;
         end loop;
       end if;
       
       if vready then
         for i in 0 to id'length-2 loop
           atmi.useid <= '1';
           atmi.id <= id(id'low+i);
           atmi.get <= '1';
           wait until atmo.getack = '1';
           atmi.useid <= '0'; atmi.get <= '0';
           wait until atmo.getack = '0';
           atmi.useid <= '0'; atmi.get <= '0';
           if atmo.getack = '1' then
             wait until atmo.getack = '0';
           end if;
           if atmo.op.response /= "00" then
             erresp(erresp'low+i) := true;
           else
             erresp(erresp'low+i) := false;
           end if;
           data(data'low+i) := atmo.op.data;
           if screenoutput then
             Print("32-bit read burst finished, Address: " & tost(atmo.op.address) &
                   " Data: " & tost(atmo.op.data) &
                   " Resp: " & resp_to_str(atmo.op.response) &
                   " Id:   " & tost(atmo.op.id));
           end if;
         end loop;
         if last_op.response /= "00" then
           erresp(erresp'high) := true;
         else
           erresp(erresp'high) := false;
         end if;
         data(data'high) := last_op.data;
         if screenoutput then
           Print("32-bit read burst finished, Address: " & tost(last_op.address) &
                 " Data: " & tost(last_op.data) &
                 " Resp: " & resp_to_str(last_op.response) &
                 " Id:   " & tost(last_op.id));
         end if;
       end if;
       ready := vready;
     else
       Print("ERROR: vector lengths do not match");
     end if;
   end procedure;

   procedure at_read_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant master:        in    integer := 0;
     variable ready:         out   boolean;
     variable data:          out   data_vector;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_vector;
     signal   atmo:          in    at_ahb_mst_out_vector) is
     variable last_op:             at_ahb_mst_op_type;
     variable vready:              boolean;
   begin
     vready := false;
     for i in erresp'range loop
       erresp(i) := false;
     end loop;
     if (id'length = erresp'length) and (id'length = data'length) then
       atmi(master).useid <= '1';
       atmi(master).id <= id(id'high);
       atmi(master).get <= '1';
       wait until atmo(master).getack = '1';
       if atmo(master).rdy = '1' then
         vready := true;
         last_op := atmo(master).op;
         atmi(master).useid <= '0'; atmi(master).get <= '0';
         wait until atmo(master).getack = '0';
       else
         atmi(master).useid <= '0'; atmi(master).get <= '0';
         wait until atmo(master).getack = '0';
         while wait_for_op loop
           while atmo(master).fin /= '1' loop
             wait until atmo(master).fin = '1';
           end loop;
           while atmo(master).fin /= '0' loop
             wait until atmo(master).fin = '0';
           end loop;
           atmi(master).useid <= '1';
           atmi(master).id <= id(id'high);
           atmi(master).get <= '1';
           wait until atmo(master).getack = '1';
           if atmo(master).rdy = '1' then
             vready := true;
           end if;
           last_op := atmo(master).op;
           atmi(master).useid <= '0'; atmi(master).get <= '0';
           wait until atmo(master).getack = '0';
           if vready then
             exit;
           end if;
         end loop;
       end if;
       
       if vready then
         for i in 0 to id'length-2 loop
           atmi(master).useid <= '1';
           atmi(master).id <= id(id'low+i);
           atmi(master).get <= '1';
           wait until atmo(master).getack = '1';
           atmi(master).useid <= '0'; atmi(master).get <= '0';
           wait until atmo(master).getack = '0';
           atmi(master).useid <= '0'; atmi(master).get <= '0';
           if atmo(master).getack = '1' then
             wait until atmo(master).getack = '0';
           end if;
           if atmo(master).op.response /= "00" then
             erresp(erresp'low+i) := true;
           else
             erresp(erresp'low+i) := false;
           end if;
           data(data'low+i) := atmo(master).op.data;
           if screenoutput then
             Print("32-bit read burst finished, Address: " & tost(atmo(master).op.address) &
                   " Data: " & tost(atmo(master).op.data) &
                   " Resp: " & resp_to_str(atmo(master).op.response) &
                   " Id:   " & tost(atmo(master).op.id));
           end if;
         end loop;
         if last_op.response /= "00" then
           erresp(erresp'high) := true;
         else
           erresp(erresp'high) := false;
         end if;
         data(data'high) := last_op.data;
         if screenoutput then
           Print("32-bit read burst finished, Address: " & tost(last_op.address) &
                 " Data: " & tost(last_op.data) &
                 " Resp: " & resp_to_str(last_op.response) &
                 " Id:   " & tost(last_op.id));
         end if;
       end if;
       ready := vready;
     else
       Print("ERROR: vector lengths do not match");
     end if;
   end procedure;
   
   procedure at_read_burst_32_nb_fin(
     constant id:            in    id_vector;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   data_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable erresp:              response_vector(id'range);
   begin
     at_read_burst_32_nb_fin(id, wait_for_op, screenoutput, ready, data, erresp,
                             atmi, atmo);
   end procedure;
   
   procedure at_comp_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable tmp:                 std_logic_vector(DATA_R);
   begin
     at_read_32(address, waitcycles, lock, hprot, back2back, screenoutput, tmp, atmi, atmo);
     if screenoutput then
       print("32-bit compare");
       print("Address:  " & tost(address));
     end if;
     if not compare(tmp, cdata) then
       print("ERROR. Read data does not match expected, Address: " &
             tost(address) & " Expected: " & tost(cdata) &
             " Read: " & tost(tmp));
       tp := false;
     end if;
     data := tmp;
   end procedure;

   procedure at_comp_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   std_logic_vector(DATA_R);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable tmp:                 std_logic_vector(DATA_R);
   begin
     at_read_32(address, waitcycles, lock, hprot, back2back, screenoutput, tmp, erresp, atmi, atmo);
     if screenoutput then
       print("32-bit compare");
       print("Address:  " & tost(address));
     end if;
     if not compare(tmp, cdata) then
       print("ERROR. Read data does not match expected, Address: " &
             tost(address) & " Expected: " & tost(cdata) &
             " Read: " & tost(tmp));
       tp := false;
     end if;
     data := tmp;
   end procedure;

   procedure at_comp_16(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    std_logic_vector(15 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   std_logic_vector(15 downto 0);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable tmp:                 std_logic_vector(15 downto 0);
   begin
     at_read_16(address, waitcycles, lock, hprot, back2back, screenoutput, tmp, erresp, atmi, atmo);
     if screenoutput then
       print("16-bit compare");
       print("Address:  " & tost(address));
     end if;
     if not compare(tmp, cdata) then
       print("ERROR. Read data does not match expected, Address: " &
             tost(address) & " Expected: " & tost(cdata) &
             " Read: " & tost(tmp));
       tp := false;
     end if;
     data := tmp;
   end procedure;

   procedure at_comp_8(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    std_logic_vector(7 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   std_logic_vector(7 downto 0);
     variable erresp:        out   boolean;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable tmp:                 std_logic_vector(7 downto 0);
   begin
     at_read_8(address, waitcycles, lock, hprot, back2back, screenoutput, tmp, erresp, atmi, atmo);
     if screenoutput then
       print("8-bit compare");
       print("Address:  " & tost(address));
     end if;
     if not compare(tmp, cdata) then
       print("ERROR. Read data does not match expected, Address: " &
             tost(address) & " Expected: " & tost(cdata) &
             " Read: " & tost(tmp));
       tp := false;
     end if;
     data := tmp;
   end procedure;
   
   procedure at_comp_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant compare:       in    boolean := false;
     constant cmpdata:       in    std_logic_vector(DATA_R);
     constant erresp:        in    boolean := false;
     constant split:         in    boolean := false;      
     constant retry:         in    boolean := false;      
     constant dbglevel:      in    integer := 0;
     constant discard:       in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
   begin
     op.id := 0;
     op.address := address; 
     op.burst := false; 
     op.beat := 1;
     op.wrap := false;
     op.size := 32;        
     op.store := false;
     op.lock := lock;
     op.prot := hprot;
     op.first := false;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := compare;     
     op.cmpdata := cmpdata;
     op.erresp := erresp;  
     op.split := split;    
     op.retry := retry;
     op.dbglevel := dbglevel;
     op.discard := discard;
     atmi.op <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     if screenoutput then
       Print("32-bit non_blocking read initiated Address:" & tost(address));
     end if;
   end procedure at_comp_32_nb;
   
   -----------------------------------------------------------------------------
   -- Blocking compare access (selectable size 8-, 16- and 32-bits)
   -----------------------------------------------------------------------------
   procedure at_comp(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     variable tp:            inout boolean;
     variable data:          out   std_logic_vector(DATA_R);
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable tmp:                 std_logic_vector(DATA_R);
     variable hi:                  integer;
     variable li:                  integer;
     variable comp:                boolean;
   begin
     at_read(address, waitcycles, lock, hprot, back2back, screenoutput, size, tmp, atmi, atmo);
     if screenoutput then
       print("32-bit compare");
       print("Address:  " & tost(address));
     end if;
     hi := 0; li := 0; comp := false;
     case address(1 downto 0) is
       when "00" =>
         case size is
           when 32 =>
             data := tmp;
             hi := 31; li := 0; comp := true;
           when 16 =>
             data(31 downto 16) := tmp(31 downto 16);
             hi := 31; li := 16; comp := true;
           when 8 =>
             data(31 downto 24) := tmp(31 downto 24);
             hi := 31; li := 24; comp := true;
           when others =>
             null;
         end case;
       when "01" =>
         case size is
           when 8 =>
             data(23 downto 16) := tmp(23 downto 16);
             hi := 23; li := 16; comp := true;
           when others =>
             assert false
             report "illegal alignment"
             severity error;
         end case;
       when "10" =>
         case size is
           when 16 =>
             data(15 downto 0) := tmp(15 downto 0);
             hi := 15; li := 0; comp := true;
           when 8 =>
             data(15 downto 8) := tmp(15 downto 8);
             hi := 15; li := 8; comp := true;
           when others =>
             assert false
             report "illegal alignment"
             severity error;
         end case;
       when "11" =>
         case size is
           when 8 =>
             data(7 downto 0) := tmp(7 downto 0);
             hi := 7; li := 0; comp := true;
           when others =>
             assert false
             report "illegal alignment"
             severity error;
         end case;
       when others =>
         null;
     end case;
     if (not compare(tmp(hi downto li), cdata(hi downto li))) and comp then
       print("ERROR. Read data does not match expected, Address: " &
             tost(address) & " Expected: " & tost(cdata(hi downto li)) &
             " Read: " & tost(tmp(hi downto li)));
       tp := false;
     end if;
   end procedure;
  
   -- idlecycles: number of added idlecycles before access
   procedure at_comp(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cmpdata:       in    std_logic_vector(DATA_R);
     constant size:          in    integer := 32;
     constant first:         in    boolean := false;
     constant burst:         in    boolean := false;
     constant idlecycles:    in    integer := 0;
     constant dbglevel:      in    integer := 1;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable id:                  integer;
     variable ready:               boolean;
     variable data:                std_logic_vector(DATA_R);
     variable back2back:           boolean;
   begin
     if idlecycles /= 0 then back2back := false; else back2back := true; end if;
     at_comp_nb(address => address, waitcycles => idlecycles, lock => false, hprot => "0011",
                back2back => back2back, screenoutput => false, size => size,
                burst => burst, first => first, compare => true, cmpdata => cmpdata,
                erresp => false, split => true, retry => true, dbglevel => dbglevel,
                discard => false, id => id, atmi => atmi, atmo => atmo);

     at_read_32_nb_fin(id => id, wait_for_op => true, screenoutput => false,
                       ready => ready, data => data, atmi => atmi, atmo => atmo);
   end procedure at_comp;

   -----------------------------------------------------------------------------
   -- Non-Blocking compare access (selectable size 8-, 16- and 32-bits)
   -----------------------------------------------------------------------------
   procedure at_comp_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     constant burst:         in    boolean := false;
     constant first:         in    boolean := false;
     constant compare:       in    boolean := false;
     constant cmpdata:       in    std_logic_vector(DATA_R);
     constant erresp:        in    boolean := false;
     constant split:         in    boolean := false;      
     constant retry:         in    boolean := false;      
     constant dbglevel:      in    integer := 0;
     constant discard:       in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
   begin
     op.id := 0;
     op.address := address; 
     op.burst := burst; 
     op.beat := 1;
     op.wrap := false;
     op.size := size;        
     op.store := false;
     op.lock := lock;
     op.prot := hprot;
     op.first := first;
     op.wait_start := waitcycles;
     op.back2back := back2back;
     op.compare := compare;     
     op.cmpdata := cmpdata;
     op.erresp := erresp;  
     op.split := split;    
     op.retry := retry;      
     op.dbglevel := dbglevel;
     op.discard := discard;
     atmi.op  <= op;
     atmi.add <= '1';
     wait until atmo.addack = '1';
     id := atmo.id;
     atmi.add <= '0';
     wait until atmo.addack = '0';
     if screenoutput then
       Print(tost(size) & "-bit compare initiated");
       Print("Address:  " & tost(atmo.op.address));
     end if;
     atmi.useid <= '0'; atmi.get <= '0';
   end procedure;
   
   procedure at_comp_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant size:          in    integer := 32;
     constant compare:       in    boolean := false;
     constant cmpdata:       in    std_logic_vector(DATA_R);
     constant erresp:        in    boolean := false;
     constant split:         in    boolean := false;      
     constant retry:         in    boolean := false;      
     constant dbglevel:      in    integer := 0;
     constant discard:       in    boolean := false;
     variable id:            out   integer;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable op:                  at_ahb_mst_op_type;
   begin
    at_comp_nb(address, waitcycles, lock, hprot, back2back, screenoutput, size, false,
               false, compare, cmpdata, erresp, split, retry, dbglevel, discard, id, 
               atmi, atmo);
  end procedure at_comp_nb;
   
  -- idlecycles: number of added idlecycles before access
  procedure at_comp_nb(
    constant address:       in    std_logic_vector(ADDR_R);
    constant cmpdata:       in    std_logic_vector(DATA_R);
    constant size:          in    integer := 32;
    constant first:         in    boolean := false;
    constant burst:         in    boolean := false;
    constant idlecycles:    in    integer := 0;
    constant dbglevel:      in    integer := 1;
    signal   atmi:          out   at_ahb_mst_in_type;
    signal   atmo:          in    at_ahb_mst_out_type) is
    variable id:                  integer;
    variable back2back:           boolean;
  begin
    if idlecycles /= 0 then back2back := false; else back2back := true; end if;
    at_comp_nb(address => address, waitcycles => idlecycles, lock => false, hprot => "0011",
               back2back => back2back, screenoutput => false, size => size,
               burst => burst, first => first, compare => true, cmpdata => cmpdata,
               erresp => false, split => true, retry => true, dbglevel => dbglevel,
               discard => true, id => id, atmi => atmi, atmo => atmo);
  end procedure at_comp_nb;

   -----------------------------------------------------------------------------
   -- Blocking 32-bit burst compare access 
   -----------------------------------------------------------------------------
   procedure at_comp_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   data_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable tmp:                 data_vector(cdata'range);
     variable addr:                std_logic_vector(ADDR_R);
   begin
     at_read_burst_32(address, beat, wrap, waitcycles, lock, hprot, back2back, screenoutput, tmp, atmi, atmo);
     addr := address;
     for i in cdata'range loop
       if screenoutput then
         print("32-bit compare");
         print("Address:  " & tost(addr));
       end if;
       if not compare(tmp(i), cdata(i)) then
         print("ERROR. Read data does not match expected, Address: " &
               tost(address) & " Expected: " & tost(cdata(i)) & " Read: " & tost(tmp(i)));
         tp := false;
       end if;
       addr := addr + 4; 
     end loop;
     data := tmp;
   end procedure;

   -----------------------------------------------------------------------------
   -- Blocking 32-bit burst compare access 
   -----------------------------------------------------------------------------
   procedure at_comp_burst_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant cdata:         in    data_vector;
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable tp:            inout boolean;
     variable data:          out   data_vector;
     variable erresp:        out   response_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable tmp:                 data_vector(cdata'range);
     variable addr:                std_logic_vector(ADDR_R);
   begin
     at_read_burst_32(address, beat, wrap, waitcycles, lock, hprot, back2back, screenoutput, tmp, erresp, atmi, atmo);
     addr := address;
     for i in cdata'range loop
       if screenoutput then
         print("32-bit compare");
         print("Address:  " & tost(addr));
       end if;
       if not compare(tmp(i), cdata(i)) then
         print("ERROR. Read data does not match expected, Address: " &
               tost(address) & " Expected: " & tost(cdata(i)) & " Read: " & tost(tmp(i)));
         tp := false;
       end if;
       addr := addr + 4; 
     end loop;
     data := tmp;
   end procedure;

   procedure at_comp_burst_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant beat:          in    integer := 1;
     constant wrap:          in    boolean := false;
     constant length:        in    integer;
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     constant compare:       in    boolean := false;
     constant cmpdata:       in    data_vector;
     constant erresp:        in    boolean := false;
     constant split:         in    boolean := false;      
     constant retry:         in    boolean := false;      
     constant dbglevel:      in    integer := 0;
     constant discard:       in    boolean := false;
     variable id:            out   id_vector;
     signal   atmi:          out   at_ahb_mst_in_type;
     signal   atmo:          in    at_ahb_mst_out_type) is
     variable addr:                std_logic_vector(ADDR_R);
     variable i:                   integer;
     variable op:                  at_ahb_mst_op_type;
   begin
     addr := address;
     for i in 0 to length-1 loop
       op.id := 0;
       op.address := addr; 
       op.burst := true; 
       op.beat := beat;
       op.wrap := wrap;
       op.size := 32;        
       op.store := false;
       op.lock := lock;
       op.prot := hprot;
       op.compare := false;     
       op.cmpdata := cmpdata(i);
       op.erresp := erresp;  
       op.split := split;    
       op.retry := retry;      
       op.dbglevel := dbglevel;
       op.discard := discard;
       if i = 0 then
         op.first := true;
         op.wait_start := waitcycles;
         op.back2back := back2back;
       else
         op.first := false;
         op.wait_start := 0;
         op.back2back := true;
       end if;
       atmi.op  <= op;
       atmi.add <= '1';
       wait until atmo.addack = '1';
       id(i+id'low) := atmo.id;
       atmi.add <= '0';
       wait until atmo.addack = '0';
       addr := addr + 4;
     end loop;
   end procedure;

end package body at_ahb_mst_pkg;
