------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2013, Aeroflex Gaisler
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
-- Entity: 	grgpio
-- File:	grgpio.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Description:	Scalable general-purpose I/O port
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.misc.all;
--pragma translate_off
use std.textio.all;
--pragma translate_on

entity grgpio is
  generic (
    pindex   : integer := 0;
    paddr    : integer := 0;
    pmask    : integer := 16#fff#;
    imask    : integer := 16#0000#;
    nbits    : integer := 16;			-- GPIO bits
    oepol    : integer := 0;                    -- Output enable polarity
    syncrst  : integer := 0;                    -- Only synchronous reset
    bypass   : integer := 16#0000#;
    scantest : integer := 0;
    bpdir    : integer := 16#0000#;
    pirq     : integer := 0;
    irqgen   : integer := 0
  );
  port (
    rst    : in  std_ulogic;
    clk    : in  std_ulogic;
    apbi   : in  apb_slv_in_type;
    apbo   : out apb_slv_out_type;
    gpioi  : in  gpio_in_type;
    gpioo  : out gpio_out_type
  );
end;

architecture rtl of grgpio is

constant REVISION : integer := 2;
constant PIMASK : std_logic_vector(31 downto 0) := '0' & conv_std_logic_vector(imask, 31);

constant BPMASK : std_logic_vector(31 downto 0) := conv_std_logic_vector(bypass, 32);
constant BPDIRM  : std_logic_vector(31 downto 0) := conv_std_logic_vector(bpdir, 32);

constant pconfig : apb_config_type := (
  0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_GPIO, 0, REVISION, pirq),
  1 => apb_iobar(paddr, pmask));

-- Prevent tools from issuing index errors for unused code
function calc_nirqmux return integer is
begin
  if irqgen = 0 then return 1; end if;
  return irqgen;
end;

constant NIRQMUX : integer := calc_nirqmux;

subtype irqmap_type is std_logic_vector(log2x(NIRQMUX)-1 downto 0);

type irqmap_array_type is array (natural range <>) of irqmap_type;

type registers is record
  din1  	:  std_logic_vector(nbits-1 downto 0);
  din2  	:  std_logic_vector(nbits-1 downto 0);
  dout   	:  std_logic_vector(nbits-1 downto 0);
  imask  	:  std_logic_vector(nbits-1 downto 0);
  level  	:  std_logic_vector(nbits-1 downto 0);
  edge   	:  std_logic_vector(nbits-1 downto 0);
  ilat   	:  std_logic_vector(nbits-1 downto 0);
  dir    	:  std_logic_vector(nbits-1 downto 0);
  bypass        :  std_logic_vector(nbits-1 downto 0);
  irqmap        :  irqmap_array_type(nbits-1 downto 0);
end record;

constant nbitszero : std_logic_vector(nbits-1 downto 0) := (others => '0');
constant irqmapzero : irqmap_array_type(nbits-1 downto 0) := (others => (others => '0'));
function dirzero_func return std_logic_vector is
  variable vres : std_logic_vector(nbits-1 downto 0);
begin
  vres := (others => '0');
  if oepol = 0 then vres := (others => '1'); end if;
  return vres;
end function dirzero_func;
constant dirzero : std_logic_vector(nbits-1 downto 0) := dirzero_func;

constant RESET_ALL : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
constant RES : registers := (
  din1 => nbitszero, din2 => nbitszero,  -- Sync. regs, not reset
  dout => nbitszero,imask => nbitszero, level => nbitszero, edge => nbitszero,
  ilat => nbitszero, dir => dirzero, bypass => nbitszero, irqmap => irqmapzero);


signal r, rin : registers;
signal arst     : std_ulogic;

begin

  arst <= apbi.testrst when (scantest = 1) and (apbi.testen = '1') else rst;
  
  
  comb : process(rst, r, apbi, gpioi)
  variable readdata, tmp2, dout, dir, pval, din : std_logic_vector(31 downto 0);
  variable v : registers;
  variable xirq : std_logic_vector(NAHBIRQ-1 downto 0);
  begin

    din := (others => '0');
    din(nbits-1 downto 0) := gpioi.din(nbits-1 downto 0);

    v := r; v.din2 := r.din1; v.din1 := din(nbits-1 downto 0);
    v.ilat := r.din2; dout := (others => '0'); dir := (others => '0');
    dir(nbits-1 downto 0) := r.dir(nbits-1 downto 0);
    if (syncrst = 1) and (rst = '0') then
      if oepol = 0 then dir(nbits-1 downto 0) := (others => '1');
      else dir(nbits-1 downto 0) := (others => '0'); end if;
    end if;
    dout(nbits-1 downto 0) := r.dout(nbits-1 downto 0);

-- read registers
    readdata := (others => '0');
    case apbi.paddr(5 downto 2) is
    when "0000" => readdata(nbits-1 downto 0) := r.din2;
    when "0001" => readdata(nbits-1 downto 0) := r.dout;
    when "0010" =>
      if oepol = 0 then readdata(nbits-1 downto 0) := not r.dir;
      else readdata(nbits-1 downto 0) := r.dir; end if;
    when "0011" =>
      if (imask /= 0) then
	readdata(nbits-1 downto 0) :=
	  r.imask(nbits-1 downto 0) and PIMASK(nbits-1 downto 0);
      end if;
    when "0100" =>
      if (imask /= 0) then
	readdata(nbits-1 downto 0) :=
	  r.level(nbits-1 downto 0) and PIMASK(nbits-1 downto 0);
      end if;
    when "0101" =>
      if (imask /= 0) then
	readdata(nbits-1 downto 0) :=
	  r.edge(nbits-1 downto 0) and PIMASK(nbits-1 downto 0);
      end if;
    when "0110" =>
      if (bypass /= 0) then
        readdata(nbits-1 downto 0) :=
          r.bypass(nbits-1 downto 0) and BPMASK(nbits-1 downto 0);
      end if;
    when "0111" =>
      readdata(12 downto 8) := conv_std_logic_vector(irqgen, 5);
      readdata(4 downto 0) := conv_std_logic_vector(nbits-1, 5);
    when others =>
      if irqgen > 1 then
        for i in 0 to (nbits+3)/4-1 loop
          if i = conv_integer(apbi.paddr(4 downto 2)) then
            for j in 0 to 3 loop
              if (j+i*4) > (nbits-1) then
                exit;
              end if;
              readdata((24+log2x(NIRQMUX)-1-j*8) downto (24-j*8)) := r.irqmap(i*4+j);
            end loop;
          end if;
        end loop;
      end if;
    end case;

-- write registers

    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
      case apbi.paddr(5 downto 2) is
      when "0000" => null;
      when "0001" => v.dout := apbi.pwdata(nbits-1 downto 0);
      when "0010" =>
        if oepol = 0 then v.dir  := not apbi.pwdata(nbits-1 downto 0);
        else v.dir := apbi.pwdata(nbits-1 downto 0); end if;
      when "0011" =>
        if (imask /= 0) then
	  v.imask := apbi.pwdata(nbits-1 downto 0) and PIMASK(nbits-1 downto 0);
        end if;
      when "0100" =>
        if (imask /= 0) then
	  v.level := apbi.pwdata(nbits-1 downto 0) and PIMASK(nbits-1 downto 0);
        end if;
      when "0101" =>
        if (imask /= 0) then
	  v.edge := apbi.pwdata(nbits-1 downto 0) and PIMASK(nbits-1 downto 0);
        end if;
      when "0110" =>
        if (bypass /= 0) then
	  v.bypass := apbi.pwdata(nbits-1 downto 0) and BPMASK(nbits-1 downto 0);
        end if;
      when "0111" => 
        null;
      when others =>
        if irqgen > 1 then
          for i in 0 to (nbits+3)/4-1 loop
            if i = conv_integer(apbi.paddr(4 downto 2)) then
              for j in 0 to 3 loop
                if (j+i*4) > (nbits-1) then
                  exit;
                end if;
                v.irqmap(i*4+j) := apbi.pwdata((24+log2x(NIRQMUX)-1-j*8) downto (24-j*8));
              end loop;
            end if;
          end loop;
        end if;
      end case;
    end if;

-- interrupt filtering and routing

    xirq := (others => '0'); tmp2 := (others => '0');
    if (imask /= 0) then
      tmp2(nbits-1 downto 0) := r.din2;
      for i in 0 to nbits-1 loop
        if (PIMASK(i) and r.imask(i)) = '1' then
	  if r.edge(i) = '1' then
	    if r.level(i) = '1' then tmp2(i) := r.din2(i) and not r.ilat(i);
            else tmp2(i) := not r.din2(i) and r.ilat(i); end if;
          else tmp2(i) := r.din2(i) xor not r.level(i); end if;
	else
	  tmp2(i) := '0';
        end if;
      end loop;

      for i in 0 to nbits-1 loop
        if irqgen = 0 then
          -- IRQ for line i = i + pirq
          if (i+pirq) > NAHBIRQ-1 then
            exit;
          end if;
          xirq(i+pirq) := tmp2(i);
        else
          -- IRQ for line i determined by irq select register i
          for j in 0 to NIRQMUX-1 loop
            if (j+pirq) > NAHBIRQ-1 then
              exit;
            end if;
            if (irqgen = 1) or (j = conv_integer(r.irqmap(i))) then
              xirq(j+pirq) := xirq(j+pirq) or tmp2(i);
            end if;
          end loop;
        end if;
      end loop;      
    end if;

-- drive filtered inputs on the output record

   pval := (others => '0');
   pval(nbits-1 downto 0) := r.din2;

-- Drive output with gpioi.sig_in for bypassed registers
   if bypass /= 0 then
       for i in 0 to nbits-1 loop
           if r.bypass(i) = '1' then
               dout(i) := gpioi.sig_in(i);
           end if;
       end loop;
   end if;

-- Drive output with gpioi.sig_in for bypassed registers
   if bpdir /= 0 then
       for i in 0 to nbits-1 loop
           if (BPDIRM(i) and gpioi.sig_en(i)) = '1'   then
               dout(i) := gpioi.sig_in(i);
               if oepol = 0 then dir(i) := '0'; else dir(i) := '1'; end if;
           end if;
       end loop;
   end if;
-- reset operation

    if (not RESET_ALL) and (rst = '0') then
      v.imask := RES.imask; v.bypass := RES.bypass;
      v.dir := RES.dir; v.dout := RES.dout;
      v.irqmap := RES.irqmap;
    end if;

    if irqgen < 2 then v.irqmap := (others => (others => '0')); end if;
    
    rin <= v;

    apbo.prdata <= readdata; 	-- drive apb read bus
    apbo.pirq <= xirq;

    if (scantest = 1) and (apbi.testen = '1') then
      dir := (others => apbi.testoen);
    elsif (syncrst = 1 ) and (rst = '0') then
      if oepol = 1 then dir := (others => '0');
      else dir := (others => '1'); end if;
    end if;
      
    gpioo.dout <= dout;
    gpioo.oen <= dir;
    gpioo.val <= pval;

-- non filtered input
    gpioo.sig_out <= din;

  end process;

  apbo.pindex <= pindex;
  apbo.pconfig <= pconfig;

-- registers

  regs : process(clk, arst)
  begin
    if rising_edge(clk) then
      r <= rin;
      if RESET_ALL and rst = '0' then
        r <= RES;
        -- Sync. registers din1 and din2 not reset
        r.din1 <= rin.din1;
        r.din2 <= rin.din2;
      end if;
    end if;
    if (syncrst = 0 ) and (arst = '0') then
      if oepol = 1 then r.dir <= (others => '0');
      else r.dir <= (others => '1'); end if;
    end if;
  end process;

-- boot message

-- pragma translate_off
    bootmsg : report_version
    generic map ("grgpio" & tost(pindex) &
	": " &  tost(nbits) & "-bit GPIO Unit rev " & tost(REVISION));
-- pragma translate_on

end;
