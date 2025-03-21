------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
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
-- Author:      Francisco Bas, Frontgrade Gaisler AB
-- Description: RISC-V APLIC Priority Encoder
--
--              For a particular hart, given the array of IP bits and their 
--              related priority, it outputs the priority and the ID of the 
--              highest ones. If it is the case that two or more ID sources 
--              have the same priority and their IP bits set to 1, the output 
--              priority and ID would be the ones from the lowest ID source.
--
--              To compute the max ID identifier and max Priority output 
--              a 2-stages pipeline is employed.
-- 
--              Notice the number of sources and priority bits highly affect the
--              length of the combinational paths.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;


entity aplic_encoder is
  generic (
    nsources        : integer := 32;
    srcbits         : integer := 6;
    prbits          : integer := 4
    );
  port (
    rstn    : in  std_ulogic;
    clk     : in  std_ulogic;
    ip      : in  std_logic_vector(nsources-1 downto 0);             -- IP bit for every source                                           
    pr_in   : in  std_logic_vector((prbits*nsources)-1 downto 0);    -- Each source's priority
    enable  : in  std_logic_vector(nsources-1 downto 0);             -- Source enable signal 
    id      : out std_logic_vector(srcbits-1 downto 0);              -- Identity of the hart interrupt with the highest priority
    ip_out  : out std_logic;                                         -- 1 when there is an interrupt pending and enable for the hart
    pr_out  : out std_logic_vector(prbits-1 downto 0)                -- Highest priority enable and pending interrupt                 
    );
end aplic_encoder;

architecture rtl of aplic_encoder is

  -- To shorten the combinotional path the highest priority interrupt is caculated in two stages.
  -- The interrupt sources are set together in groups of 'lane_srcs' sources. The highest interrupt
  -- priority of each group is computed and the results are stored in intermediate registers.
  -- In the second stage of the pipeline the highest interrupt priorities from the previous stage
  -- are are fed to another priority encoder to compute the highest prioirity source.

  -- NOTICE the number of interrupt sources and number of priority bits can highly affect the lenght
  -- of the combionational pahts. To improve timing the biggest number of interrupt sources feed
  -- to a priority enconder in any of the pipeline stages should be reduced. This could be achieved
  -- increasing the lanes or paralell priority encoders and possibly adding a third pipeline stage.

  constant lane_srcs : integer := 6;
  constant lanes     : integer := ceil_div(nsources, lane_srcs);


  type priority_vector is array (natural range <>) of std_logic_vector(prbits-1 downto 0);
  type identity_vector is array (natural range <>) of std_logic_vector(srcbits-1 downto 0);

  -- Register type to store intermediate results
  type reg_type is record
    intpr  : priority_vector(lanes-1 downto 0);
    intid  : identity_vector(lanes-1 downto 0);
    ip_out : std_logic;
  end record;
  constant RES_T : reg_type := (
    intpr  => (others => (others => '0')),
    intid  => (others => (others => '0')),
    ip_out => '0'
  ); 


  -- From a input priority vector it computes the highest priority
  -- source identity and priority (being the lowest one the highest one)
  procedure PriorityEncoder (
    pr_in    : in  priority_vector;
    id_out   : out std_logic_vector(srcbits-1 downto 0);
    pr_out   : out std_logic_vector(prbits-1 downto 0)
  ) is
    variable temp_pr : std_logic_vector(prbits-1 downto 0);
  begin
    temp_pr := (others => '1');
    id_out  := (others => '0');
    for i in pr_in'range loop
      if unsigned(pr_in(i)) <= unsigned(temp_pr) then
        temp_pr := pr_in(i);
        id_out  := conv_std_logic_vector(i, srcbits);
      end if;
    end loop;
    pr_out := temp_pr;
  end PriorityEncoder;

  signal r, rin : reg_type;

begin


  comb : process (r, ip, pr_in, enable)
    variable v          : reg_type;
    variable pr_ip_mask : priority_vector(nsources-1 downto 0);
    variable highest_pri : std_logic_vector(prbits-1 downto 0);
    variable temp_id    : std_logic_vector(srcbits-1 downto 0);
  begin

    v := r;
    
    ---------------------------------------------------
    -- Interrupt Encoding Scheme
    ---------------------------------------------------

    -- If there is no pending and enable interrupt 
    -- store that info in the ip_out register
    if (ip and enable) = (ip'range => '0') then
      v.ip_out    := '0';
    else
      v.ip_out    := '1';
    end if;


    -- Build the priority mask
    -- src_priority     if ip = 1
    -- lowest priority  if ip = 0
    for i in nsources-1 downto 0 loop
      if (ip(i) and enable(i)) = '1' then
        pr_ip_mask(i)   := pr_in((i+1)*prbits-1 downto i*prbits);
      else
        pr_ip_mask(i)   := (others => '1');
      end if;
    end loop;


    -- First pipeline stage priority encoders
    for i in 0 to lanes-1 loop
      if i /= lanes-1 then
        PriorityEncoder(pr_ip_mask((i+1)*lane_srcs-1 downto i*lane_srcs),  -- in  : Priorities
                        v.intid(i),                                        -- out : Intermediate identity
                        v.intpr(i));                                       -- out : Intermediate priority
      else 
        PriorityEncoder(pr_ip_mask(nsources-1 downto i*lane_srcs),         -- in  : Priorities
                        v.intid(i),                                        -- out : Intermediate identity
                        v.intpr(i));                                       -- out : Intermediate priority
      end if;
    end loop;


    -- Second pipeline stage priority encoder
    PriorityEncoder(r.intpr,      -- in  : Priorities
                    temp_id,      -- out : Intermediate identity
                    highest_pri); -- out : Intermediate priority

    
    
    -- Outpus:
    ip_out      <= r.ip_out;
    pr_out      <= highest_pri;
    id          <= r.intid(conv_integer(temp_id))+1;


    rin <= v;

  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if rstn = '0' then
        r <= RES_T;
      end if;
    end if;
  end process;

end rtl;

