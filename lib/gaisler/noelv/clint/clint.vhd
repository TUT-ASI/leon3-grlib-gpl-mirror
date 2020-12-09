------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-- Entity:      clint
-- File:        clint.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
-- Description: RISC-V Core Local Interrupt Controller
--
--              It includes a RISC-V privilege spec 1.11 (WIP) compatible timer
--              and handling mechanism for machine software interrupt (msip)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;

library gaisler;
use gaisler.noelv.all;

entity clint is
  generic (
    pindex      : integer range 0 to NAPBSLV-1  := 0;
    paddr       : integer range 0 to 16#FFF#    := 0;
    pmask       : integer range 0 to 16#FFF#    := 16#FFF#;
    ncpu        : integer range 0 to 4096       := 4
    );
  port (
    rst         : in  std_ulogic;
    clk         : in  std_ulogic;
    rtc         : in  std_ulogic;
    apbi        : in  apb_slv_in_type;
    apbo        : out apb_slv_out_type;
    halt        : in  std_ulogic;
    irqi        : in  std_logic_vector(ncpu*4-1 downto 0);
    irqo        : out nv_irq_in_vector(0 to ncpu-1)
    );
end clint;

architecture rtl of clint is

  constant REVISION : integer := 0;

  constant pconfig : apb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_CLINT, 0, REVISION, 0),
    1 => apb_iobar(paddr, pmask));

  constant MTIMEBITS    : integer := 64;
  constant zeros        : std_logic_vector(MTIMEBITS-1 downto 0) := (others => '0');

  type mtimecmp_type is array (0 to ncpu-1) of std_logic_vector(MTIMEBITS-1 downto 0);

  type reg_type is record
    rtcsync     : std_logic_vector(2 downto 0);
    mtime       : std_logic_vector(MTIMEBITS-1 downto 0);
    mtimecmp    : mtimecmp_type;
    msip        : std_logic_vector(ncpu-1 downto 0);
    mtip        : std_logic_vector(ncpu-1 downto 0);
  end record;

  constant RES_T : reg_type := (
    rtcsync     => (others => '0'),
    mtime       => (others => '0'),
    mtimecmp    => (others => (others => '0')),
    msip        => (others => '0'),
    mtip        => (others => '0')
    );

  constant ncpubits : integer := log2x(ncpu);

  signal r, rin     : reg_type;

begin

  comb : process (rst, rtc, r, apbi, irqi, halt)
    variable v          : reg_type;
    variable selcpu     : integer;
    variable selcmp     : integer;
    variable rdata      : std_logic_vector(31 downto 0);
  begin

    v := r;

    rdata       := (others => '0');
    
    ---------------------------------------------------
    -- Machine Timer
    ---------------------------------------------------

    -- Platforms provide a real-time counter, exposed as a memory-mapped
    -- machine-mode read-write register, mtime. mtime must run at constant frequency,
    -- and the platform must provide a mechanism for determining
    -- the timebase of mtime.

    -- The mtime register has a 64-bit precision on all RV32, RV64, and RV128 systems.

    -- 3-stage synchronizer
    v.rtcsync(0)        := rtc;
    v.rtcsync(1)        := r.rtcsync(0);
    v.rtcsync(2)        := r.rtcsync(1);

    if r.rtcsync(1) = '0' and r.rtcsync(2) = '1' and halt = '0' then
      v.mtime     := r.mtime + 1;
    end if;

    ---------------------------------------------------
    -- Interrupt Generation
    ---------------------------------------------------

    -- Platforms provide a 64-bit memory-mapped machine-mode timer compare register (mtimecmp),
    -- which causes a timer interrupt to be posted when the mtime register contains a value greater
    -- than or equal to the value in the mtimecmp register. The interrupt remains posted until it is
    -- cleared by writing the mtimecmp register. The interrupt will only be taken if interrupts are
    -- enabled and the MTIE bit is set in the mie register.

    for i in 0 to ncpu-1 loop
      
      if (r.mtime >= r.mtimecmp(i)) then
        v.mtip(i)       := '1';
      else
        v.mtip(i)       := '0';
      end if;

    end loop;

    ---------------------------------------------------
    -- Register Map
    ---------------------------------------------------

    -- Hart 0:
    -- msip             @ 0000
    -- mtimecmp lo      @ 4000
    -- mtimecmp hi      @ 4004

    -- Hart 1:
    -- msip             @ 0004
    -- mtimecmp lo      @ 4008
    -- mtimecmp hi      @ 400c
    
    -- ...
    
    -- bff8 mtime lo
    -- bffc mtime hi

    ---------------------------------------------------
    -- APB Interface
    ---------------------------------------------------

    selcpu      := to_integer(unsigned(apbi.paddr(ncpubits+1 downto 2)));
    selcmp      := to_integer(unsigned(apbi.paddr(ncpubits+2 downto 3)));

    -- APB Read Access
    if ((apbi.psel(pindex) and apbi.penable and (not apbi.pwrite)) = '1') then
      case apbi.paddr(15 downto 14) is
        when "00" =>
          if selcpu < ncpu then
            rdata(0)      := r.msip(selcpu);
          end if;

        when "01" =>
          if selcmp < ncpu then
            case apbi.paddr(2) is
              when '0' =>
                rdata     := r.mtimecmp(selcmp)(31 downto 0);
              when '1' =>
                rdata     := r.mtimecmp(selcmp)(63 downto 32);

              when others =>
            end case;
          end if;
          
        when "10" =>
          case apbi.paddr(2) is
            when '0' =>
              rdata     := r.mtime(31 downto 0);
            when '1' =>
              rdata     := r.mtime(63 downto 32);

            when others =>
          end case;

        when others =>
      end case;
    end if;

    -- APB Write Access
    if ((apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1') then
      case apbi.paddr(15 downto 14) is
        when "00" =>
          if selcpu < ncpu then
            v.msip(selcpu) := apbi.pwdata(0);
          end if;

        when "01" =>
          if selcmp < ncpu then
            case apbi.paddr(2) is
              when '0' =>
                v.mtimecmp(selcmp)(31 downto 0) := apbi.pwdata;
              when '1' =>
                v.mtimecmp(selcmp)(63 downto 32) := apbi.pwdata;

              when others =>
            end case;
          end if;

        when "10" =>
          case apbi.paddr(2) is
            when '0' =>
              v.mtime(31 downto 0) := apbi.pwdata;
            when '1' =>
              v.mtime(v.mtime'high downto 32) := apbi.pwdata;
            when others =>
          end case;

        when others =>
      end case;
    end if;

    rin <= v;

    -- APB Interface
    apbo.prdata         <= rdata;
    apbo.pirq           <= (others => '0');
    apbo.pconfig        <= pconfig;
    apbo.pindex         <= pindex;

    -- IRQ Interface
    for i in 0 to ncpu-1 loop
      irqo(i).msip           <= r.msip(i);
      irqo(i).mtip           <= r.mtip(i);
      irqo(i).meip           <= irqi(i*4);
      irqo(i).seip           <= irqi(i*4+1);
      irqo(i).ueip           <= irqi(i*4+2);
      irqo(i).heip           <= irqi(i*4+3);
    end loop;
    
  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if rst = '0' then
        r <= RES_T;
      end if;
    end if;
  end process;

end rtl;

