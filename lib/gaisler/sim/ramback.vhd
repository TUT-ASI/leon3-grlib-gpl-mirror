------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity: 	ramback
-- File:	ramback.vhd
-- Author:	Magnus Hjorth - Aeroflex Gaisler
-- Description:	Generic backend for RAM simulation models
------------------------------------------------------------------------------

--pragma translate_off

use std.textio.all;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdio.hread;
use grlib.stdlib.print;
use grlib.stdlib.tost;
use grlib.stdlib.notx;
library gaisler;
use gaisler.sim.all;

entity ramback is
  generic (
    abits: integer := 16;
    dbits: integer := 32;
    fname: string := "dummy";
    autoload: integer := 0;
    pagesize: integer := 4096;
    listsize: integer := 128;
    rstmode: integer := 0; -- 0: return U, 1: return rstdata
    rstdatah: integer := 16#DEAD#;
    rstdatal: integer := 16#BEEF#;
    nports: integer := 4;
    offset_addr : std_logic_vector(31 downto 0) := x"00000000";  -- Address offset to subtract to SREC addresses
    swap_halfw : integer := 0;                                    -- Half-word (16-bit) swapping during SREC load
    endian : integer := 0               -- endianness - 0=big-endian 1=little-endian(byte-invariant)
    );
  port (
    bein: in ramback_in_array(1 to nports);
    beout: out ramback_out_array(1 to nports)
    );
end;

architecture sim of ramback is

  constant rstdatas: std_logic_vector(31 downto 0) :=
    std_logic_vector(to_unsigned(rstdatah,16)) &
    std_logic_vector(to_unsigned(rstdatal,16));
  
  function xlog2(i: integer) return integer is
    variable r,y: integer;
  begin
    r:=0; y:=1;
    while y<i loop r:=r+1; y:=y+y; end loop;
    return r;
  end xlog2;

  function tost_hex(i: integer) return string is
    variable sl: std_logic_vector(31 downto 0);
  begin
    sl := std_logic_vector(to_unsigned(i,32));
    if i < 65536 then
      return tost(sl(15 downto 0));
    else
      return tost(sl(31 downto 0));
    end if;
  end tost_hex;
  
  constant pagepos: integer := xlog2(pagesize);
  
  -- If we're lucky the simulator will store this efficiently
  -- Each hwint stores 2 bytes, always big-endian so MSB is byte N+0, LSB is byte N+1
  subtype hwint is integer range 0 to 65535;
  constant mempage_length: integer := pagesize/2+(1-rstmode)*pagesize/16;
  type mempage is array(0 to mempage_length-1) of hwint;
  type mempage_ptr is access mempage;  
  type mempage_ptr_array is array(natural range <>) of mempage_ptr;
  
  type addr_array is array(natural range <>) of integer;
  
  type pagelist;
  type pagelist_ptr is access pagelist;
  -- Order inside pagelist is ascending but not across whole linked list.
  type pagelist is record
    l: natural;                         -- Number of used positions
    a: addr_array(0 to listsize-1);     -- Ascending order, multiply by pagesize
    p: mempage_ptr_array(0 to listsize-1);  -- Each element corr to a element
    n: pagelist_ptr;
  end record;

  constant rpro_workaround: boolean := true;
begin

  p: process(bein)

    variable trace_en: boolean := false;
 
    ---------------------------------------------------------------------------
    -- Page list and subprocesses for managing it
    ---------------------------------------------------------------------------

    variable pl: pagelist_ptr;    
    
    procedure clear_all is
      variable n: pagelist_ptr;
    begin
      while pl /= null loop
        for i in 0 to pl.l-1 loop
          deallocate(pl.p(i));
        end loop;
        n := pl.n;
        deallocate(pl);
        pl := n;
      end loop;
    end clear_all;

    procedure get_mempage_in_list(
      lp: inout pagelist_ptr; pageno: integer; alloc: boolean;
      mp: inout mempage_ptr; pageloc: out integer) is
      variable k: integer;
    begin
      -- print("get_mempage_in_list pageno=" & tost(pageno) & " alloc=" & tost(alloc) & " len=" & tost(lp.l));
      -- Search for existing page
      -- TODO do binary search instead of linear
      k := 0;
      while k<lp.l and pageno > lp.a(k) loop
        -- print("Skipping k=" & tost(k) & " with pageno " & tost(lp.a(k)));
        k := k+1;
      end loop;
      pageloc := k;
      if k<lp.l and pageno=lp.a(k) then mp := lp.p(k); return; end if;
      -- Allocate new page
      if alloc and lp.l < listsize then
        if trace_en then
          print("RAMBACK: get_mempage_in_list allocating new page on position " & tost(k) & " pageno " & tost(pageno));
        end if;
        if k < lp.l then
          if rpro_workaround then
            for z in lp.l downto k+1 loop
              lp.p(z) := lp.p(z-1);
              lp.a(z) := lp.a(z-1);
            end loop;
          else
            lp.p(k+1 to lp.l) := lp.p(k to lp.l-1);
            lp.a(k+1 to lp.l) := lp.a(k to lp.l-1);
          end if;
        end if;
        lp.l := lp.l+1;
        mp := new mempage;
        lp.p(k) := mp;
        lp.a(k) := pageno;
        -- Fill page with default data
        if rstmode/=0 then
          for x in 0 to pagesize/4-1 loop
            mp(2*x)   := rstdatah;
            mp(2*x+1) := rstdatal;
          end loop;
        end if;
        return;
      end if;
      -- None found
      mp := null;
    end get_mempage_in_list;
    
    impure function get_mempage(pageno: integer; alloc: boolean) return mempage_ptr is
      variable plp: pagelist_ptr;
      variable mpp: mempage_ptr;
      variable i,j: integer := 0;
    begin
      if trace_en then
        print("RAMBACK: get_mempage pageno=" & tost(pageno) & " alloc=" & tost(alloc));
      end if;
      if pl=null then
        if not alloc then return null; end if;
        pl := new pagelist;        
        get_mempage_in_list(pl, pageno, true, mpp, j);
        return mpp;
      else
        plp := pl;
        loop
          if trace_en then
            print("RAMBACK:  (get_mempage) testing pagelist #" & tost(i) & " len " & tost(plp.l));
            for j in 0 to plp.l-1 loop
              print("  " & tost(j) & ":" & tost(plp.a(j)));
            end loop;
            i := i+1;
          end if;
          get_mempage_in_list(plp, pageno, alloc and plp.l<listsize, mpp, j);
          if mpp /= null then
            if trace_en then
              print("RAMBACK:  (get_mempage) page found on position " & tost(j));
            end if;
            return mpp;
          end if;
          if trace_en then
            print("RAMBACK:  (get_mempage) page not found, searched up to pos " & tost(j));
          end if;
          assert plp.l=listsize or (not alloc and plp.n=null);
          if plp.n = null then
            if not alloc then return null; end if;
            plp.n := new pagelist;
          end if;
          plp := plp.n;
        end loop;
      end if;
      return null;
    end get_mempage;
    
    -- SREC loader, mostly copied from sram.vhd
    procedure load_srec is
      file TCF : text open read_mode is fname;
      variable L1: line;
      variable CH : character;
      variable rectype : std_logic_vector(3 downto 0);
      variable recaddr : std_logic_vector(31 downto 0);
      variable reclen  : std_logic_vector(7 downto 0);
      variable recdata : std_logic_vector(0 to 16*8-1);
      variable opn: integer := -1;
      variable pn: integer;
      variable m: mempage_ptr;
      variable i: integer;
      variable len: integer;
    begin
      L1:= new string'("");	--'
      while not endfile(TCF) loop
        readline(TCF,L1);
        if (L1'length /= 0) then	--'
          while (not (L1'length=0)) and (L1(L1'left) = ' ') loop
            std.textio.read(L1,CH);
          end loop;

          if L1'length > 0 then	--'
            read(L1, ch);
            if (ch = 'S') or (ch = 's') then
              hread(L1, rectype);
              hread(L1, reclen);
	      len := to_integer(unsigned(reclen))-1;
	      recaddr := (others => '0');
	      case rectype is 
		when "0001" =>
                  hread(L1, recaddr(15 downto 0));
                  len := len - 2;
		when "0010" =>
                  hread(L1, recaddr(23 downto 0));
                  len := len - 3;
		when "0011" =>
                  hread(L1, recaddr);
                  len := len - 4;
		when others => next;
	      end case;
              hread(L1, recdata(0 to len*8-1));
              recaddr := std_logic_vector( unsigned(recaddr) - unsigned(offset_addr) );
              pn := to_integer(unsigned(recaddr(31 downto pagepos)));
              -- print("recaddr: " & tost(recaddr) & " pn: " & tost(pn));
              if pn /= opn then
                m := get_mempage(pn, true);
                opn := pn;
              end if;
              i := to_integer(unsigned(recaddr(pagepos-1 downto 1)));
              
              if (swap_halfw = 0) then
                for x in 0 to 7 loop
                  m(i+x) := to_integer(unsigned(recdata(16*x to 16*x+15)));
                end loop;
              else
                for x in 0 to 3 loop
                  m(i+2*x+1) := to_integer(unsigned(recdata(16*2*x to 16*2*x+15)));
                  m(i+2*x) := to_integer(unsigned(recdata(16*(2*x+1) to 16*(2*x+1)+15)));
                end loop;
              end if;

              if rstmode=0 then
                m(pagesize/2 + i/8) := 16#FFFF# - (2**(16-len)-1);
              end if;
              
            end if;
          end if;
        end if;
      end loop;
      
    end load_srec;

    ---------------------------------------------------------------------------
    -- Port state and related subprocedures
    ---------------------------------------------------------------------------
    type portdata is record
      page: mempage_ptr;
      pageno: integer;
      wordno: integer;
      addrlsb: std_logic;
      validmask: unsigned(dbits/8-1 downto 0);
    end record;
    type portdata_array is array(natural range <>) of portdata;
    
    procedure portdata_clear(pd: inout portdata) is
    begin
      pd.page := null;
      pd.pageno := -1;
    end portdata_clear;

    procedure port_get_validmask(pd: inout portdata) is
      variable i: integer;
      variable vw,vwp,mp: integer;
      variable d: unsigned(15 downto 0);
    begin
      i := pd.wordno;
      if rstmode=0 and pd.page/=null then
        vw := pagesize/2 + i/8;
        vwp := (i mod 8)*2;
        if dbits < 16 and pd.addrlsb='1' then vwp:=vwp+1; end if;
        mp := 0;
        while mp < dbits/8 loop
          d := to_unsigned(pd.page(vw),16);
          i := 16-vwp;
          if i > dbits/8-mp then i:=dbits/8-mp; end if;
          pd.validmask(dbits/8-1-mp downto dbits/8-i-mp) :=
            d(15-vwp downto 16-i-vwp);
          mp := mp + i;
          vwp := 0;
          vw := vw + 1;        
        end loop;
      elsif rstmode=0 then
        pd.validmask := (others => '0');
      else
        if trace_en then
          print("RAMBACK: --> port_get_validmask setting to 1");
        end if;
        pd.validmask := (others => '1');
      end if;
    end port_get_validmask;

    procedure port_set_validmask(pd: inout portdata) is
      variable vw,vwp,mp,i: integer;
      variable d: unsigned(15 downto 0);
    begin
      if rstmode=0 and pd.page/=null then
        vw := pagesize/2 + pd.wordno/8;
        vwp := (pd.wordno mod 8)*2;
        if dbits < 16 and pd.addrlsb='1' then vwp:=vwp+1; end if;
        mp := 0;
        while mp < dbits/8 loop
          d := to_unsigned(pd.page(vw),16);
          i := 16-vwp;
          if i > dbits/8-mp then i:=dbits/8-mp; end if;
          d(15-vwp downto 16-i-vwp) := 
            pd.validmask(dbits/8-1-mp downto dbits/8-i-mp);
          pd.page(vw) := to_integer(d);
          mp := mp + i;
          vwp := 0;
          vw := vw + 1;
        end loop;
      end if;
    end port_set_validmask;
    
    procedure port_addr(pd: inout portdata; addr: std_logic_vector) is
      variable i: integer;
    begin
      i := to_integer(unsigned(addr(abits-1 downto pagepos-xlog2(dbits/8))));
      if trace_en then
        print("RAMBACK: port_addr addr=" & tost(addr) & " pageno=" & tost(i) & " curpage:" & tost(pd.pageno));
        if pd.page=null then print("RAMBACK:  pd.page=null"); end if;
      end if;
      if i /= pd.pageno then
        pd.pageno := i;
        pd.page := get_mempage(i,false);
      end if;
      if dbits < 16 then
        i := to_integer(unsigned(addr(pagepos-xlog2(dbits/8)-1 downto 1)));
      else
        i := to_integer(unsigned(addr(pagepos-xlog2(dbits/8)-1 downto 0))) * (dbits/16);
      end if;
      pd.wordno := i;
      pd.addrlsb := addr(0);            -- for 8-bit access
      port_get_validmask(pd);
      if trace_en then
        print("RAMBACK:   --> (port_addr) pageno:" & tost(pd.pageno)
              & " wordno:" & tost(pd.wordno)
              & " page-allocd:" & tost(boolean'(pd.page/=null))
              & " validmask:" & tost(std_logic_vector(pd.validmask)));
      end if;
    end port_addr;

    procedure port_write(pd: inout portdata; wr: std_logic_vector; data: std_logic_vector) is
      variable d,n: hwint;
      variable w: unsigned(7 downto 0);
    begin
      if trace_en then
        print("RAMBACK: port_write: wr=" & tost(wr) & " data=" & tost(data));
      end if;
      if pd.page=null then
        -- Call get_mempage with alloc=true to allocate page or to refresh in
        -- case another port just allocated it.
        pd.page := get_mempage(pd.pageno,true);
        port_get_validmask(pd);
      end if;
      if dbits<16 then
        assert wr'length=1;
        if wr(0)='1' then
          d := pd.page(pd.wordno);
          if pd.addrlsb='1' then
            d := (d/256)*256 + to_integer(unsigned(data));
          else
            d := (to_integer(unsigned(data)) * 256) + (d mod 256);
          end if;
          pd.page(pd.wordno) := d;
        end if;
      else
        for x in 0 to dbits/16-1 loop
          if wr(dbits/8-1-2*x)='1' or wr(dbits/8-2-2*x)='1' then
            d := pd.page(pd.wordno+x);
            if wr(dbits/8-1-2*x)='1' then
              w := unsigned(data(dbits-1-16*x downto dbits-8-16*x));
              d := (to_integer(w) * 256) + (d mod 256);
            end if;
            if wr(dbits/8-2-2*x)='1' then
              w := unsigned(data(dbits-9-16*x downto dbits-16-16*x));
              -- print("data:" & tost(data) & " w:" & tost(to_integer(w)));
              d := (d/256)*256 + to_integer(w);
            end if;
            pd.page(pd.wordno+x) := d;
          end if;
        end loop;
      end if;
      pd.validmask := pd.validmask or unsigned(wr);
      port_set_validmask(pd);
    end port_write;

    procedure port_read(pd: inout portdata; addr: std_logic_vector; dout: out std_logic_vector) is
      variable r: std_logic_vector(dbits-1 downto 0);
      variable w: std_logic_vector(15 downto 0);
      variable astat: std_logic_vector(1 downto 0);
    begin
      if trace_en then
        print("RAMBACK: port_read: addr=" & tost(addr));
      end if;
      astat := addr(1 downto 0);
      if pd.page=null or pd.wordno < 0 then
        if rstmode /= 0 then
          if dbits < 16 then
            case astat is
              when "00"   => r := rstdatas(31 downto 24);
              when "01"   => r := rstdatas(23 downto 16);
              when "10"   => r := rstdatas(15 downto 8);
              when others => r := rstdatas(7 downto 0);
            end case;
          elsif dbits < 32 then
            if addr(0)='1' then
              r := rstdatas(15 downto 0);
            else
              r := rstdatas(31 downto 16);            
            end if;
          else
            for x in 0 to dbits/32-1 loop
              r(x*32+31 downto x*32) := rstdatas;
            end loop;
          end if;
        else
          r := (others => 'U');
        end if;
      else  
        if dbits < 16 then
          w := std_logic_vector(to_unsigned(pd.page(pd.wordno),16));
          if pd.addrlsb='0' then r:=w(15 downto 8); else r:=w(7 downto 0); end if;
        else
          for x in 0 to dbits/16-1 loop
            w := std_logic_vector(to_unsigned(pd.page(pd.wordno+x),16));
            r(dbits-16*x-1 downto dbits-16*x-16) := w;                    
          end loop;
        end if;
      end if;
      -- print("port read addr=" & tost(addr) & "->" & "wordno:" & tost(pd.wordno) & " w=" & tost(w) & " -> " & tost(r));
      -- Check if data has been written on addr
        for x in 0 to dbits/8-1 loop
          if pd.validmask(x)='0' then
            r(8*x+7 downto 8*x) := "UUUUUUUU";
          end if;
        end loop;

      if trace_en then
        print("RAMBACK:  --> (port_read) " & "wordno:" & tost(pd.wordno) & "w=" & tost(w) & " -> " & tost(r));
      end if;
      dout := r;
    end port_read;

    variable first: boolean := true;
    variable loaded: boolean := false;
    variable pda: portdata_array(1 to nports);
    -- variable port1,port2,port3,port4: portdata;
    variable i: integer;
    variable d: hwint;
    variable repad: boolean;

    variable xxx: pagelist_ptr;
    variable b: boolean;
    variable rdata,wdata: std_logic_vector(dbits-1 downto 0);
    variable wmask: std_logic_vector(dbits/8-1 downto 0);

    function byteswap(x: std_logic_vector) return std_logic_vector is
      variable xv,r: std_logic_vector(x'length-1 downto 0);
    begin
      xv := x;
      for i in 0 to x'length/8-1 loop
        r(i*8+7 downto i*8) := xv(x'length-i*8-1 downto x'length-i*8-8);
      end loop;
      return r;
    end byteswap;
    function maskswap(m: std_logic_vector) return std_logic_vector is
      variable mv,r: std_logic_vector(m'length-1 downto 0);
    begin
      mv := m;
      for i in 0 to m'length-1 loop
        r(i) := mv(m'length-i-1);
      end loop;
      return r;
    end maskswap;

  begin
--    print("events: addr1: " & tost(addr1'event) & " wr1:" & tost(wr1'event) & " din1:" & tost(din1'event) &
--          " addr2:" & tost(addr2'event) & " wr2:" & tost(wr2'event) & " din2:" & tost(din2'event) &
--          " clear:" & tost(clear'event) & " reload:" & tost(reload'event));
    repad := false;
    
    if first then
      first := false;
      for x in 1 to nports loop
        portdata_clear(pda(x));
      end loop;
      clear_all;
    end if;

    beout <= (others => ramback_out_none);
    
    -- Handle file loading
    b := (autoload/=0 and not loaded);
    for x in 1 to nports loop
      if bein(x).reload='1' then
        b := true;
        beout(x).cmdack <= '1';
      end if;
    end loop;
    if b then
        print("Loading " & fname);
        load_srec;
        loaded := true;
        for x in 1 to nports loop
          portdata_clear(pda(x));
        end loop;
    end if;
    -- Handle clearing
    b := false;
    for x in 1 to nports loop
      if bein(x).clear='1' then
        b := true;
        beout(x).cmdack <= '1';
      end if;
    end loop;
    if b then      
      print("clear");
      for x in 1 to nports loop
        portdata_clear(pda(x));
      end loop;
      clear_all;
    end if;
    -- Find-page / write
    repad := false;
    for x in 1 to nports loop
      if notx(bein(x).addr(abits-1 downto 0)) then
        port_addr(pda(x), bein(x).addr(abits-1 downto 0));
      end if;
      if notx(bein(x).wr(dbits/8-1 downto 0)) and notx(bein(x).addr(abits-1 downto 0)) and
        bein(x).wr(dbits/8-1 downto 0) /= (dbits/8-1 downto 0 => '0') then
        if pda(x).page=null then repad:=true; end if;
        wdata := bein(x).din(dbits-1 downto 0);
        wmask := bein(x).wr(dbits/8-1 downto 0);
        if endian /= 0 then wdata:=byteswap(wdata); wmask:=maskswap(wmask); end if;
        port_write(pda(x), wmask, wdata);
        beout(x).cmdack <= '1';
      end if;
    end loop;
    if repad then
      for x in 1 to nports loop
        if pda(x).page=null and notx(bein(x).addr(abits-1 downto 0)) then
          port_addr(pda(x),bein(x).addr(abits-1 downto 0));
        end if;
      end loop;
    end if;
    -- Port read after all ports written
    for x in 1 to nports loop
      if notx(bein(x).addr(abits-1 downto 0)) then
        -- Repeat find-page in special case (write through + new page)
        if repad then
          port_addr(pda(x),bein(x).addr(abits-1 downto 0));
        end if;
        port_read(pda(x),bein(x).addr(abits-1 downto 0),rdata);
        if endian /= 0 then rdata := byteswap(rdata); end if;
        beout(x).dout(dbits-1 downto 0) <= rdata;
        beout(x).addr <= bein(x).addr;
      end if;
    end loop;
    -- Debugging
    for x in 1 to nports loop
      if bein(x).dbgdump='1' then
        print("----  ramback dump -------");
        i := 0;
        xxx := pl;
        while xxx /= null loop
          i := i+1;
          print("  pagelist #" & tost(i) & " length=" & tost(xxx.l));
          for q in 0 to xxx.l-1 loop
            print("    page addr=" & tost(xxx.a(q)) & " first data="
                  & tost_hex(xxx.p(q).all(0)) & " " & tost_hex(xxx.p(q).all(1)) & " "
                  & tost_hex(xxx.p(q).all(2)) & " " & tost_hex(xxx.p(q).all(3)) & " "
                  );
          end loop;
          xxx := xxx.n;
        end loop;        
      end if;
    end loop;
  end process;
  
end;

--pragma translate_on

