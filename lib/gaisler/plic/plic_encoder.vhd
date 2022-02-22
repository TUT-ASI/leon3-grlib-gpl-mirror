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
-- Entity:      plic_encoder
-- File:        plic_encoder.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
-- Description: RISC-V PLIC Encoder
--
--              Given the array of IP bits and their related priority, it outputs
--              the priority and the ID of the highest ones. If it is the case
--              that two or more ID sources has the same priority and their IP
--              bits set to 1, the output priority and ID would be the ones
--              from the lowest ID source.
--
--              The max ID identifier and max Priority output are computed in a
--              combinatorial way.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;

library gaisler;
use gaisler.plic.all;

entity plic_encoder is
  generic (
    nsources        : integer := 32;
    ntargets        : integer := 4;
    srcbits         : integer := 6;
    prbits          : integer := 4
    );
  port (
    ip      : in  std_logic_vector(nsources-1 downto 0);
    pr_in   : in  std_logic_vector((prbits*nsources)-1 downto 0);
    enable  : in  std_logic_vector(nsources-1 downto 0);
    id      : out std_logic_vector(srcbits-1 downto 0);
    pr_out  : out std_logic_vector(prbits-1 downto 0)
    );
end plic_encoder;

architecture rtl of plic_encoder is

  type priority_in_type is array (0 to nsources-1) of std_logic_vector(prbits-1 downto 0);

  --constant ncomps       : integer := nsources * (nsources - 1) / 2;
  constant ncomps       : integer := nsources * nsources;
  constant priorities   : integer := 2 ** prbits;
  constant zero         : std_logic_vector(nsources-1 downto 0) := (others => '0');

  function prioritize(b : std_logic_vector; priorities : integer) return std_logic_vector is
    constant zeros : std_logic_vector(srcbits-1 downto 0) := (others => '0');
    variable a : std_logic_vector(b'length-1 downto 0);
    variable irl : std_logic_vector(srcbits-1 downto 0);
    variable level : integer range 0 to nsources-1; --priorities;
  begin
    irl := zeros; level := 0; a := b;
    for i in 0 to b'length-1 loop
      level := i;
      if a(i) = '1' then exit; end if;
    end loop;
    irl := conv_std_logic_vector(level, srcbits);
    return(irl);
  end;

  function and_reduce(b : std_logic_vector) return std_ulogic is
    variable result: std_ulogic;
  begin
    for i in b'range loop
      if i = b'left then
        result := b(i);
      else
        result := result and b(i);
      end if;
      exit when result = '0';
    end loop;
    return result;
  end and_reduce;

begin

  comb : process (ip, pr_in, enable)
    variable pr_ip_mask : priority_in_type;
    variable comps_out  : std_logic_vector(ncomps-1 downto 0);
    variable and_out    : std_logic_vector(nsources-1 downto 0);
    variable and_en     : std_logic_vector(nsources-1 downto 0);
    variable max_id     : std_logic_vector(srcbits-1 downto 0);
    variable prout      : std_logic_vector(prbits-1 downto 0);
  begin

    -- All the comparators would be fix at high values in order to be
    -- transaprent as inputs to the AND structure
    comps_out   := (others => '1');
    
    ---------------------------------------------------
    -- Interrupt Encoding Scheme
    ---------------------------------------------------

    -- On receiving a claim message, the PLIC core will atomically determine the ID of the
    -- highest-priority pending interrupt for the target and then clear down the corresponding
    -- source’s IP bit. The PLIC core will then return the ID to the target. The PLIC core will
    -- return an ID of zero, if there were no pending interrupts for the target when the claim
    -- was serviced.

    -- Build the priority mask
    -- src_priority     if ip = 1
    -- 0                if ip = 0
    for i in 0 to nsources-1 loop
      if ip(i) = '1' then
        pr_ip_mask(i)   := pr_in((i+1)*prbits-1 downto i*prbits);
      else
        pr_ip_mask(i)   := (others => '0');
      end if;
    end loop;

    -- Build the comparator structure
    -- Index for the comparators
    for i in 0 to nsources-1 loop
      for j in 0 to nsources-1 loop
        if (pr_ip_mask(i) >= pr_ip_mask(j)) then
          comps_out(i*nsources+j)   := '1';
        else
          comps_out(i*nsources+j)   := '0';
        end if;
      end loop;
    end loop;

    -- Build the AND structure
    for i in 0 to nsources-1 loop
      and_out(i)        := and_reduce(comps_out((i+1)*nsources-1 downto i*nsources));
    end loop;
      
    -- Mask the output with the enable bits and input into the priority encoder
    and_en      := and_out and enable and ip;
    max_id      := prioritize(and_en, priorities);
    
    -- Mask ID if prioritize give highest ID but there is no interrupt pending
    if max_id = conv_std_logic_vector(nsources-1, srcbits) and (ip(nsources-1) and enable(nsources-1)) = '0' then
      max_id    := (others => '0');
    end if;
    
    prout       := pr_ip_mask(to_integer(unsigned(max_id)));
    
    id          <= max_id;
    pr_out      <= prout;

  end process;

end rtl;

