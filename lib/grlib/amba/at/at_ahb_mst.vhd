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
use      grlib.stdlib."+";
use      grlib.stdlib.tost;
use      grlib.stdlib.conv_std_logic;
use      grlib.stdlib.zero32;
use      grlib.at_pkg.all;
use      grlib.at_ahb_mst_pkg.all;
use      grlib.testlib.compare;
use      grlib.testlib.print;

entity at_ahb_mst is
  generic(
    hindex:        in    Integer := 0;
    vendorid:      in    Integer := 0;
    deviceid:      in    Integer := 0;
    version:       in    Integer := 0);
  port(
    -- AMBA AHB system signals
    hclk:          in  std_ulogic;
    hresetn:       in  std_ulogic;
    
    --AHB Interface
    ahbi:          in  ahb_mst_in_type;
    ahbo:          out ahb_mst_out_type;

    --Operation Scheduling Interface
    atmi:           in  at_ahb_mst_in_type;
    atmo:           out at_ahb_mst_out_type
  );
end entity;

architecture beh of at_ahb_mst is
  constant hconfig: AHB_Config_Type := (
    0        => ahb_device_reg(vendorid, deviceid, 0, version, 0),
    others   => (others => '0'));
  
  constant nullop : at_ahb_mst_op_type := (0, (others => '0'),
     (others => '0'), false, false, 0, false, 0, false, false,
     (others => '0'), 0, false, (others => '0'), 0, 0,
     false, (others => '0'), false, false, false, 0, false);
  
  type op_state_type is (waiting_s, started_s, finished_s);
  type access_state_type is (grant_s, address_s, data_s);
    
  type list_object;
  type list_object_ptr is access list_object;
  
  type list_object is record
    op   : at_ahb_mst_op_type;
    prv  : list_object_ptr;
    nxt  : list_object_ptr;
  end record;

  signal grant          : std_ulogic;
  signal address_phase  : std_ulogic;
  signal data_phase     : std_ulogic;
  signal readdr_phase   : std_ulogic;
  signal redata_phase   : std_ulogic;
  signal event          : std_ulogic := '0';
  
begin
 
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
    variable tmp_op         : at_ahb_mst_op_type;
    variable gcnt           : integer;
    variable acnt           : integer;
    variable address        : std_logic_vector(31 downto 0);
    variable op_state       : op_state_type;
    variable grant_op       : list_object_ptr;
    variable addr_op        : list_object_ptr;
    variable data_op        : list_object_ptr;
    variable current        : list_object_ptr;
    variable len            : integer;
    variable TP             : boolean;
    variable found          : boolean;
    variable htrans         : std_logic_vector(1 downto 0);
    variable opcnt          : integer;
    variable addr_assigned  : time;
    variable cmpdata        : std_logic_vector(31 downto 0);
                  
    procedure add_op(
      variable head : inout list_object_ptr;
      variable op   : inout list_object_ptr) is
    begin
      head.nxt.prv := op;
      op.nxt       := head.nxt;
      op.prv       := head;
      head.nxt     := op;
    end procedure;

    procedure rebuild_burst(
      variable head     : list_object_ptr) is
      variable current  : list_object_ptr;
    begin
      current := head.nxt;
      if current.op.burst then
        current.op.first := true;
        current.op.wrap := false;
        current.op.beat := 1;
        current := current.nxt;
        while current.op.burst loop
          current.op.wrap := false;
          current.op.beat := 1;
          if current.op.address /=
            (current.prv.op.address + current.op.size/8) then
            current.op.burst := false;
          end if;
          current := current.nxt;
        end loop;
      end if;
    end procedure;
                  
  begin
    if hresetn /= '1' then
      grant_op           := null;
      addr_op            := null;
      data_op            := null;
      list_head.nxt      := list_tail;
      list_tail.prv      := list_head;
      done_list_tail.prv := done_list_head;
      done_list_head.nxt := done_list_tail;
      atmo.addack        <= '0';
      atmo.getack        <= '0';
      atmo.rdy           <= '0';
      id                 := 0;
      add_active         := false;
      get_active         := false;
      atmo.fin           <= '0';
      opcnt := 0;
    else
      --find next op in list and perform the operation
      --on bus
      --print("op: " & tost(opcnt));
      if (grant_op = null) and ( list_head.nxt /= list_tail ) then
        grant_op := list_head.nxt;
        list_head.nxt := list_head.nxt.nxt;
        list_head.nxt.prv := list_head;
        gcnt := 0;
        grant_op.op.retries := 0;
        grant_op.op.splits := 0;

      
        --decide if op should wait for grant or go directly to
        --address phase
        if (address_phase = '1') and not (
          (not grant_op.op.back2back) and (grant_op.op.wait_start /= 0)) and
          not grant_op.op.lock then
          if addr_op = null then
            addr_op := grant_op; acnt := 0;
            addr_assigned := now;
            grant_op := null;
          end if;
        end if;
      end if;
    end if;
      
    if hresetn /= '1' then
      TP                := false;
      --Init ahb signals
      ahbo.hbusreq	<= '0';
      ahbo.hlock	<= '0';
      ahbo.htrans	<=  HTRANS_IDLE;
      ahbo.haddr	<=  (others => '0');
      ahbo.hwrite	<=  '0';
      ahbo.hsize	<=  HSIZE_BYTE;
      ahbo.hburst	<=  HBURST_SINGLE;
      ahbo.hprot	<=  "0011"; --recommended default value in amba faq
      ahbo.hwdata	<=  (others => '0');
      ahbo.hirq   	<=  (others => '0');
      ahbo.hconfig 	<=  hconfig;
      ahbo.hindex  	<=  hindex;
    else

      atmo.fin <= '0';
      
      -- access waiting to finish data phase
      if data_op /= null then
        ahbo.hwdata <= data_op.op.data;
        --access finished
        if rising_edge(hclk) and (ahbi.hready = '1') then
          --error checking
          if data_op.op.compare then
            if (ahbi.hresp = HRESP_OKAY) and not data_op.op.store then
              cmpdata := data_op.op.cmpdata;
              case data_op.op.size is
                when 8 =>
                  case address(1 downto 0) is
                    when "00" =>
                      cmpdata(31 downto 8) := (others => '-');
                    when "01" =>
                      cmpdata(7 downto 0) := (others => '-');
                      cmpdata(31 downto 16) := (others => '-');
                    when "10" =>
                      cmpdata(15 downto 0) := (others => '-');
                      cmpdata(31 downto 24) := (others => '-');
                    when "11" =>
                      cmpdata(23 downto 0) := (others => '-');
                    when others =>
                      null;
                  end case;
                when 16 =>
                  if address(1) = '0' then
                    cmpdata(31 downto 16) := (others => '-');
                  else
                    cmpdata(15 downto 0) := (others => '-');
                  end if;
                when others =>
                  null;
              end case;
              if not compare(ahbi.hrdata, cmpdata) then
                if data_op.op.dbglevel /= 0 then
                  print("ERROR: Unexpected read data. Expected: " & tost(data_op.op.cmpdata) &
                        " Read[" & tost(data_op.op.address) & "]: " & tost(ahbi.hrdata));
                end if;
                atmo.error <= '1';
              else                                    -- added Read printout
                if data_op.op.dbglevel = 2 then
                  print(" Read[" & tost(data_op.op.address) & "]: " & tost(ahbi.hrdata));
                end if;
              end if;
            end if;
            if (ahbi.hresp = HRESP_ERROR and not data_op.op.erresp) or
               (ahbi.hresp = HRESP_OKAY and data_op.op.erresp) then
              if data_op.op.dbglevel /= 0 then
                if data_op.op.erresp then
                  print("ERROR: Unexpected response. Expected: HRESP_ERROR Got: HRESP_OKAY"); 
                else
                  print("ERROR: Unexpected response. Expected: HRESP_OKAY Got: HRESP_ERROR"); 
                end if;
              end if;
              atmo.error <= '1';
            end if;
            if (ahbi.hresp = HRESP_SPLIT and not data_op.op.split) then
              if data_op.op.dbglevel /= 0 then
                if data_op.op.erresp then
                  print("ERROR: Unexpected response. Expected: HRESP_ERROR Got: HRESP_SPLIT"); 
                else
                  print("ERROR: Unexpected response. Expected: HRESP_OKAY Got: HRESP_SPLIT"); 
                end if;
              end if;
              atmo.error <= '1';
            end if;
            if (ahbi.hresp = HRESP_RETRY and not data_op.op.retry) then
              if data_op.op.dbglevel /= 0 then
                if data_op.op.erresp then
                  print("ERROR: Unexpected response. Expected: HRESP_ERROR Got: HRESP_RETRY"); 
                else
                  print("ERROR: Unexpected response. Expected: HRESP_OKAY Got: HRESP_RETRY"); 
                end if;
              end if;
              atmo.error <= '1';
            end if;
          elsif (ahbi.hresp = HRESP_OKAY) and data_op.op.store then  -- added write printout
            if data_op.op.dbglevel = 2 then
              print(" Write[" & tost(data_op.op.address) & "]: " & tost(data_op.op.data));
            end if;
          end if;
          if (ahbi.hresp = HRESP_OKAY) or (ahbi.hresp = HRESP_ERROR) then
            if ahbi.hresp = HRESP_OKAY then
              data_op.op.response := "00";
              if not data_op.op.store then
                data_op.op.data := ahbi.hrdata;
              end if;
            else
              data_op.op.response := "01";
            end if;
            
            --remove finished ops from queue and add to finished queue

            atmo.fin <= '1';  

            --grlib.testlib.print("data");

            if not data_op.op.discard then
              data_op.prv := done_list_tail.prv;
              done_list_tail.prv.nxt := data_op;
              done_list_tail.prv := data_op;
              data_op.nxt := done_list_tail;
            end if;
            data_op := null;
            opcnt := opcnt - 1;
            
          else
            if ahbi.hresp = HRESP_RETRY then
              data_op.op.retries := data_op.op.retries + 1;
            else
              data_op.op.splits := data_op.op.splits + 1;
            end if;
            --split or retry, if ongoing burst rebuild it
            if grant_op /= null then
              add_op(list_head, grant_op);
            end if;
            if addr_op /= null then
              add_op(list_head, addr_op);
            end if;
            if data_op /= null then
              add_op(list_head, data_op);
            end if;
            grant_op := null;
            addr_op := null;
            data_op := null;
            rebuild_burst(list_head);
            event <= not event;
          end if;
        end if;
      end if;

      -- access waiting to finish address phase
      if (addr_op = null) or (address_phase = '0') then
        ahbo.htrans     <=  HTRANS_IDLE;
        ahbo.haddr	<=  (others => '0');
        ahbo.hwrite	<=  '0';
        ahbo.hsize	<=  HSIZE_BYTE;
        ahbo.hburst	<=  HBURST_SINGLE;
        ahbo.hprot	<=  "0011";
      else
        ahbo.haddr <= addr_op.op.address;
        case addr_op.op.size is
          when 8 =>
            ahbo.hsize <= HSIZE_BYTE;
          when 16 =>
            ahbo.hsize <= HSIZE_HWORD;
          when 32 =>
            ahbo.hsize <= HSIZE_WORD;
          when others =>
            assert false
            report "illegal hsize"
            severity warning;
            ahbo.hsize <= HSIZE_BYTE;
        end case;
        
        ahbo.hprot <= addr_op.op.prot;

        ahbo.hwrite <= conv_std_logic(addr_op.op.store);
      
        --HBURST
        if addr_op.op.burst then
          ahbo.hburst <= HBURST_INCR;
          if addr_op.op.wrap then
            case addr_op.op.beat is
              when 4 =>
                ahbo.hburst <= HBURST_WRAP4;
              when 8 =>
                ahbo.hburst <= HBURST_WRAP8;
              when 16 =>
                ahbo.hburst <= HBURST_WRAP16;
              when others =>
                assert false
                report "illegal hsize"
                severity warning;
                ahbo.hburst <= HBURST_WRAP4;
            end case;    
          else
            case addr_op.op.beat is
              when 1 =>
                ahbo.hburst <= HBURST_INCR;
              when 4 =>
                ahbo.hburst <= HBURST_INCR4;
              when 8 =>
                ahbo.hburst <= HBURST_INCR8;
              when 16 =>
                ahbo.hburst <= HBURST_INCR16;
              when others =>
                assert false
                report "illegal hsize"
                severity warning;
                ahbo.hburst <= HBURST_INCR;
            end case;
          end if;
        else
          ahbo.hburst <= HBURST_SINGLE;
        end if;

        
        --HTRANS
        if (not addr_op.op.burst) or
           (addr_op.op.burst and addr_op.op.first) or
           (addr_op.op.address(9 downto 0) = zero32(9 downto 0)) then
          htrans := HTRANS_NONSEQ;
        else
          if acnt < addr_op.op.wait_start then
            htrans := HTRANS_BUSY;
            if rising_edge(hclk) then
              acnt := acnt + 1;
            end if;
          else
            htrans := HTRANS_SEQ;
          end if;
        end if;

        ahbo.htrans <= htrans;

        if rising_edge(hclk) and (ahbi.hready = '1') and
           ((htrans = HTRANS_NONSEQ) or (htrans = HTRANS_SEQ)) and
           (addr_assigned /= now) then --if operation was added to queue
                                       --simultaenously with rising edge
                                       --then wait one more cycle
          acnt := 0;
          --grlib.testlib.print("address");
          if data_op /= null then
            assert false
            report "data phase did not end correctly"
            severity error;
          else
            data_op := addr_op;
            addr_op := null;
            event <= not event;
          end if;
        end if;
      end if;
        
      
      -- access waiting to get grant
      if grant_op /= null then
        --BUS REQUEST
        --always generate bus request if currently not granted or if next
        --transfer should be performed back2back with current one.
        if (not grant_op.op.back2back) and
           (gcnt < grant_op.op.wait_start) then
          ahbo.hbusreq <= '0';
          if rising_edge(hclk) then
            gcnt := gcnt + 1;
          end if;
        else
          --LOCK
          --always driven with the same timing as hbusreq
          ahbo.hlock <= conv_std_logic(grant_op.op.lock);
          ahbo.hbusreq <= '1';
          if rising_edge(hclk) and (grant = '1') then
            gcnt := 0;
            --grlib.testlib.print("grant");
            if (addr_op /= null) then
              if htrans /= HTRANS_BUSY then 
                assert false
                report "address phase did not end correctly"
                severity error;
              end if;
            else
              addr_op  := grant_op;
              addr_assigned := now;
              grant_op := null;
              event <= not event;
            end if;
          end if;
        end if;
      else
        ahbo.hbusreq <= '0'; ahbo.hlock <= '0';
      end if;
      
    end if;
              
    --add new operation to queue
    if rising_edge(atmi.add) and not add_active then
      --queue empty
      tmp := new list_object'(atmi.op, null, null);
      --list empty
      tmp.prv := list_tail.prv;
      list_tail.prv.nxt := tmp;
      list_tail.prv := tmp;
      tmp.nxt := list_tail;
      add_active := true;
      atmo.addack <= '1'; atmo.id <= id;
      tmp.op.id := id;
      if id < 2**16 then
        id := id + 1;
      else
        id := 0;
      end if;
    end if;
    
    if falling_edge(atmi.add) and add_active then
      --Print("Here");
      opcnt := opcnt + 1;
      atmo.addack <= '0'; add_active := false;
      event <= not event;
    end if;
    
    --get finished operation from queue
    if rising_edge(atmi.get) and not get_active then
      found := false;
      if atmi.useid = '0' then
        useid := false;
        current := null;
        if done_list_head.nxt /= done_list_tail then
          atmo.rdy <= '1'; current := done_list_head.nxt;
          atmo.op <= done_list_head.nxt.op; found := true;
        end if;
      else
        useid := true;
        if done_list_head.nxt /= done_list_tail then
          current := done_list_head.nxt;
          while (current /= done_list_tail) and current.op.id /= atmi.id loop
            current := current.nxt;
          end loop;
          if (current.op.id = atmi.id) and (current /= done_list_tail) then
            atmo.rdy <= '1'; 
            atmo.op <= current.op; found := true;
          end if;
        end if;  
      end if;
      get_active := true; atmo.getack <= '1'; 
    end if;
    
    if falling_edge(atmi.get) and get_active then
      if found then
        current.prv.nxt := current.nxt;
        current.nxt.prv := current.prv;
        deallocate(current);
      end if;
      get_active := false; atmo.rdy <= '0'; atmo.getack <= '0';
      event <= not event;
    end if;


    --AHB state
    --keeps track of if the master interface currently is granted,
    --has an ongoing address or data phase and reschedules addr
    --and data phases when split or retry occur

    grant <= ahbi.hready and ahbi.hgrant(hindex);
            
    if rising_edge(hclk) then

      if (ahbi.hready = '1') then
        address_phase <= ahbi.hgrant(hindex);
        data_phase    <= address_phase;
      else
        if (ahbi.hresp = HRESP_SPLIT or ahbi.hresp = HRESP_RETRY) and (data_phase = '1') then
          address_phase <= '0';
          data_phase    <= '0';
        end if;
      end if;
    end if;
    wait on hclk, atmi, ahbi, hresetn, grant, address_phase, data_phase, event;
  end process;

end architecture;


