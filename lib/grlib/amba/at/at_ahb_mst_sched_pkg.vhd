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
-- Package:     at_ahb_mst_sched_pkg
-- File:        at_ahb_mst_sched_pkg.vhd
-- Author:      Marko Isomaki, Aeroflex Gaisler
-- Description: AMBA Test Framework - AHB master scheduler test package
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
use      grlib.stdlib.all;

package at_ahb_mst_sched_pkg is
   -----------------------------------------------------------------------------
   -- Init at master interface
   -----------------------------------------------------------------------------
   procedure at_init(
     signal   opi:           out  at_ahb_sched_in_type);

   -----------------------------------------------------------------------------
   -- Non-blocking write access 
   -----------------------------------------------------------------------------
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
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type);

   --check write has finished and get results
   procedure at_write_32_nb_fin(
     constant id:            in    integer := 0;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type);
     
   -----------------------------------------------------------------------------
   -- Non-blocking read access 
   -----------------------------------------------------------------------------
   --initiate read
   procedure at_read_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable id:            out   integer;
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type);

   --check if read has finished and get results
   procedure at_read_32_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type);
     
   -----------------------------------------------------------------------------
   -- Blocking write access 
   -----------------------------------------------------------------------------
   procedure at_write_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant data:          in    std_logic_vector(DATA_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type);
 
   -----------------------------------------------------------------------------
   -- Blocking read access 
   -----------------------------------------------------------------------------
   procedure at_read_32(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(DATA_R);
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type);
      
end package at_ahb_mst_sched_pkg; --===============================================--


package body at_ahb_mst_sched_pkg is
   procedure at_init(
     signal   opi:           out   at_ahb_sched_in_type) is
   begin
     opi.add   <= '0';
     opi.get   <= '0';
     opi.useid <= '0';
     opi.id    <= 0;
     opi.op    <= (0, (others => '0'), (others => '0'), false, 1, false, 32,
                 false, false, (others => '0'), 0, false, (others => '0'));
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
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type) is
     variable op:                  at_ahb_mst_sched_op_type;
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
     op.wait_start := waitcycles;
     op.back2back := back2back;
     opi.op  <= op;
     opi.add <= '1';
     wait until opo.addack = '1';
     id := opo.id;
     opi.add <= '0';
     if screenoutput then
       Print("32-bit non-blocking write initiated");
       Print("Address:  " & tost(address));
       Print("Data:     " & tost(data));
     end if;
   end procedure at_write_32_nb;

   procedure at_write_32_nb_fin(
     constant id:            in    integer := 0;
     constant wait_for_op:   in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type) is
   begin
     ready := false;
     while wait_for_op loop
       if wait_for_op then
         while opo.fin /= '1' loop
           wait until opo.fin = '1';
         end loop;
       end if;
       opi.useid <= '1';
       opi.id    <= id;
       opi.get   <= '1';
       wait until opo.getack = '1';
       if opo.rdy = '1' then
         ready := true;
         exit;
       end if;
       opi.useid <= '0'; opi.get <= '0';
     end loop;
     if (opo.rdy = '1') and screenoutput then
       Print("32-bit non-blocking write finished");
       Print("Address:  " & tost(opo.op.address));
       Print("Data:     " & tost(opo.op.data));
       case opo.op.response is
         when "00" =>
           Print("Response: OKAY");
         when "01" =>
           Print("Response: ERROR");
         when "10" =>
           Print("Response: SPLIT/RETRY");
         when others =>
           null;
       end case;
     end if;
     opi.useid <= '0'; opi.get <= '0';
   end procedure;

   procedure at_write_32(
     constant address:       in    std_logic_vector(31 downto 0);
     constant data:          in    std_logic_vector(31 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type) is
     variable op:                  at_ahb_mst_sched_op_type;
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
     op.wait_start := waitcycles;
     op.back2back := back2back;
     opi.op  <= op;
     opi.add <= '1';
     wait until opo.addack = '1';
     id := opo.id;
     opi.add <= '0';
     while true loop
       while opo.fin /= '1' loop
         wait until opo.fin = '1';
       end loop;
       opi.useid <= '1';
       opi.id <= id;
       opi.get <= '1';
       wait until opo.getack = '1';
       if opo.rdy = '1' then
         exit;
       end if;
       opi.useid <= '0'; opi.get <= '0';
     end loop;
     if screenoutput then
       Print("32-bit write");
       Print("Address:  " & tost(address));
       Print("Data:     " & tost(data));
       case opo.op.response is
         when "00" =>
           Print("Response: OKAY");
         when "01" =>
           Print("Response: ERROR");
         when "10" =>
           Print("Response: SPLIT/RETRY");
         when others =>
           null;
       end case;
     end if;
     opi.useid <= '0'; opi.get <= '0';
   end procedure at_write_32;

   procedure at_read_32_nb(
     constant address:       in    std_logic_vector(ADDR_R);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable id:            out   integer;
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type) is
     variable op:                  at_ahb_mst_sched_op_type;
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
     op.wait_start := waitcycles;
     op.back2back := back2back;
     opi.op <= op;
     opi.add <= '1';
     wait until opo.addack = '1';
     id := opo.id;
     opi.add <= '0';
     if screenoutput then
       Print("32-bit non_blovcking read initiated");
       Print("Address:  " & tost(address));
     end if;
   end procedure at_read_32_nb;

   --check if read has finished and get results
   procedure at_read_32_nb_fin(
     constant id:            in    integer;
     constant wait_for_op:   in    boolean;     
     constant screenoutput:  in    boolean := false;
     variable ready:         out   boolean;
     variable data:          out   std_logic_vector(DATA_R);
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type) is
     variable op:                  at_ahb_mst_sched_op_type;
   begin
     ready := false;
     while wait_for_op loop
       if wait_for_op then
         while opo.fin /= '1' loop
           wait until opo.fin = '1';
         end loop;
       end if;
       opi.useid <= '1';
       opi.id    <= id;
       opi.get   <= '1';
       wait until opo.getack = '1';
       if opo.rdy = '1' then
         op := opo.op;
         data := opo.op.data;
         ready := true;
         exit;
       end if;
       opi.useid <= '0'; opi.get <= '0';
     end loop;
     if (opo.rdy = '1') and screenoutput then
       Print("32-bit read");
       Print("Address:  " & tost(opo.op.address));
       Print("Data:     " & tost(opo.op.data));
       case opo.op.response is
         when "00" =>
           Print("Response: OKAY");
         when "01" =>
           Print("Response: ERROR");
         when "10" =>
           Print("Response: SPLIT/RETRY");
         when others =>
           null;
       end case;
     end if;
     opi.useid <= '0'; opi.get <= '0';
   end procedure at_read_32_nb_fin;
   
   procedure at_read_32(
     constant address:       in    std_logic_vector(31 downto 0);
     constant waitcycles:    in    integer := 0;     
     constant lock:          in    boolean := false;
     constant hprot:         in    std_logic_vector(3 downto 0);
     constant back2back:     in    boolean := false;
     constant screenoutput:  in    boolean := false;
     variable data:          out   std_logic_vector(31 downto 0);
     signal   opi:           out   at_ahb_sched_in_type;
     signal   opo:           in    at_ahb_sched_out_type) is
     variable op:                  at_ahb_mst_sched_op_type;
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
     op.wait_start := waitcycles;
     op.back2back := back2back;
     opi.op  <= op;
     opi.add <= '1';
     wait until opo.addack = '1';
     id := opo.id;
     opi.add <= '0';
     while true loop
       while opo.fin /= '1' loop
         wait until opo.fin = '1';
       end loop;
       opi.useid <= '1';
       opi.id    <= id;
       opi.get   <= '1';
       wait until opo.getack = '1';
       if opo.rdy = '1' then
         op := opo.op;
         data := opo.op.data;
         exit;
       end if;
       opi.useid <= '0'; opi.get <= '0';
     end loop;
     if screenoutput then
       Print("32-bit read");
       Print("Address:  " & tost(opo.op.address));
       Print("Data:     " & tost(opo.op.data));
       case opo.op.response is
         when "00" =>
           Print("Response: OKAY");
         when "01" =>
           Print("Response: ERROR");
         when "10" =>
           Print("Response: SPLIT/RETRY");
         when others =>
           null;
       end case;
     end if;
     opi.useid <= '0'; opi.get <= '0';
   end procedure at_read_32;

end package body at_ahb_mst_sched_pkg;
