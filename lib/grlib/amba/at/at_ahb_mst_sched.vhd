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
-- Package:     at_ahb_mst_sched
-- File:        at_ahb_mst_sched.vhd
-- Author:      Marko Isomaki, Aeroflex Gaisler
-- Description: AMBA Test Framework - AHB master scheduler
-------------------------------------------------------------------------------

library  ieee;
use      ieee.std_logic_1164.all;

library  grlib;
use      grlib.amba.all;
use      grlib.stdlib.all;
use      grlib.at_pkg.all;
use      grlib.at_ahb_mst_sched_pkg.all;

entity at_ahb_mst_scheduler is
  generic(
    hindex:        in    Integer := 0;
    vendorid:      in    Integer := 0;
    deviceid:      in    Integer := 0;
    version:       in    Integer := 0;
    syncrst:       in    Integer := 1;
    boundary:      in    Integer := 1);
  port(
    -- AMBA AHB system signals
    hclk:          in  std_ulogic;
    hresetn:       in  std_ulogic;
    
    --AHB Interface
    ahbin:         in  ahb_mst_in_type;
    ahbout:        out ahb_mst_out_type;

    --Operation Scheduling Interface
    opi:           in  at_ahb_sched_in_type;
    opo:           out at_ahb_sched_out_type
  );
end entity;

architecture beh of at_ahb_mst_scheduler is
  constant nullop : at_ahb_mst_sched_op_type := (0, (others => '0'),
     (others => '0'), false, 0, false, 0, false, false, (others => '0'),
     0, false, (others => '0'));
  
  type op_state_type is (waiting, started, finished);
  type access_state_type is (start, data);
    
  type list_object;
  type list_object_ptr is access list_object;
  
  type list_object is record
    op   : at_ahb_mst_sched_op_type;
    prv  : list_object_ptr;
    nxt  : list_object_ptr;
  end record;
    
  signal atmin  : at_ahb_mst_in_type;
  signal atmout : at_ahb_mst_out_type;
begin

  --DMA2AHB interface instantiation
  dma0 : at_ahb_mst
    generic map(
      hindex        => hindex,
      vendorid      => vendorid,
      deviceid      => deviceid,
      version       => version,
      syncrst       => syncrst,
      boundary      => boundary)
    port map(
      -- AMBA AHB system signals
      hclk          => hclk,
      hresetn       => hresetn,

      -- Direct Memory Access Interface
      atmin         => atmin,
      atmout        => atmout,
      
      -- AMBA AHB Master Interface
      ahbin         => ahbin,
      ahbout        => ahbout);
 
  sched : process is
    variable id             : integer := 0;
    variable list_head      : list_object_ptr := new list_object'(nullop, null, null);
    variable list_tail      : list_object_ptr := new list_object'(nullop, null, null);
    variable tmp            : list_object_ptr;
    variable done_list_head : list_object_ptr := new list_object'(nullop, null, null);
    variable done_list_tail : list_object_ptr := new list_object'(nullop, null, null);
    variable add_active     : boolean := false;
    variable get_active     : boolean := false;
    variable useid          : boolean;
    variable tmp_op         : at_ahb_mst_sched_op_type;
    variable cnt            : integer;
    variable address        : std_logic_vector(31 downto 0);
    variable op_state       : op_state_type;
    variable current        : list_object_ptr;
    variable len            : integer;
    variable TP             : boolean;
    variable found          : boolean;
    variable access_state   : access_state_type;
  begin
    --if rising_edge(hclk) then
      if hresetn = '0' then
        list_head.nxt  := list_tail;
        list_tail.prv  := list_head;
        done_list_tail.prv := done_list_head;
        done_list_head.nxt := done_list_tail;
        opo.addack     <= '0';
        opo.getack     <= '0';
        opo.rdy        <= '0';
        id             := 0;
        add_active     := false;
        get_active     := false;
        op_state       := waiting;
        opo.fin        <= '0';
      else
        --find next op in list and perform the operation
        --on bus
        if (list_tail.prv /= list_head and (op_state = waiting)) then
          --wait specified number of clk cycles before starting
          --current operation
          current := list_tail.prv;
          if not current.op.back2back then
            cnt := 0;
            while cnt < current.op.wait_start loop
              cnt := cnt + 1; 
            end loop;
          end if;
          op_state := started; 
        end if;
      end if;
    --end if;

    if hresetn = '0' then
      TP             := false;
      access_state   := start;
      --Init dma signals
      atmin.reset     <= '0';
      atmin.address   <= (others => '0');
      atmin.request   <= '0';
      atmin.burst     <= '0';
      atmin.beat      <= (others => '0');
      atmin.store     <= '0';
      atmin.data      <= (others => '0');
      atmin.size      <= "10";
      atmin.lock      <= '0';
      atmin.wrap      <= '0';
    else
      --perform accesses
      if op_state = started then
        --single access
        case access_state is
          when start =>
            atmin.reset     <= '0';
            atmin.address   <= current.op.address;
            atmin.request   <= '1';
            atmin.burst     <= conv_std_logic(current.op.burst);
            case current.op.beat is
              when 1 =>
                atmin.beat  <= "00";
              when 4 =>
                atmin.beat  <= "01";
              when 8 =>
                atmin.beat  <= "10";
              when 16 =>
                atmin.beat  <= "11";
              when others =>
                atmin.beat  <= "00";
            end case;
            atmin.store     <= conv_std_logic(current.op.store);
            atmin.data      <= current.op.data;
            atmin.lock      <= conv_std_logic(current.op.lock);
            if rising_edge(hclk) and (atmout.grant = '1') then
              access_state := data;
              if (current.nxt /= list_tail) and (current.nxt.op.back2back) then
                atmin.reset     <= '0';
                atmin.address   <= current.nxt.op.address;
                atmin.request   <= '1';
                atmin.burst     <= conv_std_logic(current.nxt.op.burst);
                case current.nxt.op.beat is
                  when 1 =>
                    atmin.beat  <= "00";
                  when 4 =>
                    atmin.beat  <= "01";
                  when 8 =>
                    atmin.beat  <= "10";
                  when 16 =>
                    atmin.beat  <= "11";
                  when others =>
                    atmin.beat  <= "00";
                end case;
                atmin.store     <= conv_std_logic(current.nxt.op.store);
                atmin.data      <= current.nxt.op.data;
                atmin.lock      <= conv_std_logic(current.nxt.op.lock);
              else
                atmin.reset     <= '0';
                atmin.address   <= (others => '0');
                atmin.request   <= '0';
                atmin.burst     <= '0';
                atmin.beat      <= (others => '0');
                atmin.store     <= '0';
                atmin.lock      <= '0';
              end if;
            end if;
          when data =>
            if rising_edge(hclk) then
              if atmout.ready = '1' then
                current.op.response := "00";
                op_state := finished; access_state := start;
                if not current.op.store then
                  current.op.data := atmout.data;
                end if;
              elsif atmout.retry = '1' then
                current.op.response := "10";
                op_state := finished; access_state := start;
              elsif atmout.fault = '1' then
                current.op.response := "01";
                op_state := finished; access_state := start;
              end if;
            end if;
          when others =>
            null;
        end case;
      end if;
    end if;
        
    opo.fin <= '0';
    --remove finished ops from queue and add to finished queue
    if op_state = finished then
      list_head.nxt := current.nxt;
      list_tail.prv := current.prv;
      current.nxt := done_list_head.nxt;
      done_list_head.nxt := current;
      current.prv := done_list_tail.prv;
      done_list_tail.prv := current;
      opo.fin <= '1'; 
      op_state := waiting;
    end if;
                
    --add new operation to queue
    if rising_edge(opi.add) and not add_active then
      --queue empty
      tmp := new list_object'(opi.op, null, null);
      --list empty
      tmp.nxt := list_head.nxt;
      if list_head.nxt = list_tail then
        list_tail.prv := tmp;
      end if;
      list_head.nxt := tmp;
      tmp.prv := list_head;
      add_active := true;
      opo.addack <= '1'; opo.id <= id;
      tmp.op.id := id;
      if id < 2**16 then
        id := id + 1;
      else
        id := 0;
      end if;
    end if;
    if falling_edge(opi.add) and add_active then
      opo.addack <= '0'; add_active := false; 
    end if;
    --get finished operation from queue
    if rising_edge(opi.get) and not get_active then
      found := false;
      if opi.useid = '0' then
        useid := false;
        current := null;
        if done_list_tail.prv /= done_list_head then
          opo.rdy <= '1'; current := done_list_tail.prv;
          opo.op <= done_list_tail.prv.op; found := true;
        end if;
      else
        useid := true;
        if done_list_tail.prv /= done_list_head then
          current := done_list_tail.prv;
          while (current /= done_list_head) and current.op.id /= opi.id loop
            current := current.prv;
          end loop;
          if current.op.id = opi.id then
            opo.rdy <= '1'; 
            opo.op <= current.op; found := true;
          end if;
        end if;  
      end if;
      get_active := true; opo.getack <= '1'; 
    end if;
    if falling_edge(opi.get) and get_active then
      if found then
        tmp := current.prv;
        tmp.nxt := current.nxt;
        tmp := current.nxt;
        tmp.prv := current.prv;
        deallocate(current);
      end if;
      get_active := false; opo.rdy <= '0'; opo.getack <= '0';
    end if;
    wait on hclk, opi, atmout, hresetn;
  end process;

end architecture;


