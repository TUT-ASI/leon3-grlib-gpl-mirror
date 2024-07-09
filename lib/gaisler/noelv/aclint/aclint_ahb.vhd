------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
-- Entity:      aclint_ahb
-- File:        aclint_ahb.vhd
-- Author:      Andrea Merlo, Nils Wessman, Francisco Bas, Cobham Gaisler AB
-- Description: RISC-V Core Local Interrupt Controller
--
--              It includes a RISC-V privilege spec 1.11 (WIP) compatible timer
--              and handling mechanism for machine software interrupt (msip)
--              With AHB AMBA interface to support 64-bit accesses.
------------------------------------------------------------------------------

-- Hart 0:
-- msip             @ 0000
-- mtimecmp lo      @ 4000
-- mtimecmp hi      @ 4004
-- setssip          @ c000

-- Hart 1:
-- msip             @ 0004
-- mtimecmp lo      @ 4008
-- mtimecmp hi      @ 400c
-- setssip          @ c004

-- ...

-- bff8 mtime lo
-- bffc mtime hi


-- 10000 watchdog

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.zero32;
use grlib.stdlib."+";
use grlib.stdlib."-";
use grlib.stdlib.log2x;

library gaisler;
use gaisler.noelv.all;

entity aclint_ahb is
  generic (
    hindex      : integer range 0 to NAHBSLV-1  := 0;
    haddr       : integer range 0 to 16#FFF#    := 0;
    hmask       : integer range 0 to 16#FFF#    := 16#FFF#;
    hirq1       : integer range 0 to NAHBSLV-1  := 0;
    hirq2       : integer range 0 to NAHBSLV-1  := 0;
    ncpu        : integer range 0 to 4096       := 4;
    mswi        : integer range 0 to 1          := 1;  -- Enables MSWI ACLINT's device (machine software interrupts)
    mtimer      : integer range 0 to 1          := 1;  -- Enables MTIMER ACLINT's device (machine timer interrupts)
    sswi        : integer range 0 to 1          := 1;  -- Enables SSWI ACLINT's device (supervisor software interrupts)
    watchdog    : integer range 0 to 1          := 1;  -- Enables watchdog
    wdtickbit   : integer range 0 to 63         := 4   -- MTIME bit used for the watchdog tick
    );
  port (
    rst         : in  std_ulogic;
    clk         : in  std_ulogic;
    rtc         : in  std_ulogic;
    ahbi        : in  ahb_slv_in_type;
    ahbo        : out ahb_slv_out_type;
    halt        : in  std_ulogic;
    irqi        : in  nv_irq_in_vector(0 to ncpu-1);
    irqo        : out nv_irq_in_vector(0 to ncpu-1)
    );
end;

architecture rtl of aclint_ahb is

  constant REVISION : integer := 0;

  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_ACLINT, 0, REVISION, 0),
    4 => ahb_membar(haddr, '0', '0', hmask),
    others => zero32);

  constant MTIMEBITS    : integer := 64;
  constant zeros        : std_logic_vector(MTIMEBITS-1 downto 0) := (others => '0');

  type mtimecmp_type is array (0 to ncpu-1) of std_logic_vector(MTIMEBITS-1 downto 0);

  type reg_type is record
    -- ACLINT
    rtcsync     : std_logic_vector(2 downto 0);
    mtime       : std_logic_vector(MTIMEBITS-1 downto 0);
    mtimecmp    : mtimecmp_type;
    msip        : std_logic_vector(ncpu-1 downto 0);
    mtip        : std_logic_vector(ncpu-1 downto 0);
    -- Watchdog
    wden     : std_ulogic;
    s1wto    : std_ulogic;
    s2wto    : std_ulogic;
    wtocnt   : std_logic_vector(9 downto 0);
    cnt      : std_logic_vector(9 downto 0);
    -- AHB
    hsel        : std_logic_vector(1 downto 0);
    hready      : std_logic;
    hwrite      : std_logic;
    hsize       : std_logic_vector(2 downto 0);
    haddr       : std_logic_vector(31 downto 0);
    hresp       : std_logic_vector(1 downto 0);
    hwdata      : std_logic_vector(63 downto 0);
    hrdata      : std_logic_vector(63 downto 0);
  end record;

  constant RES_T : reg_type := (
    -- ACLINT
    rtcsync     => (others => '0'),
    mtime       => (others => '0'),
    mtimecmp    => (others => (others => '1')),
    msip        => (others => '0'),
    mtip        => (others => '0'),
    -- Watchdog
    wden    => '0',
    s1wto   => '0',
    s2wto   => '0',
    wtocnt  => (others => '0'),
    cnt     => (others => '1'),
    -- AHB
    hsel        => (others => '0'),
    hready      => '0',
    hwrite      => '0',
    hsize       => (others => '0'),
    haddr       => (others => '0'),
    hresp       => (others => '0'),
    hwdata      => (others => '0'),
    hrdata      => (others => '0')
    );

  constant ncpubits : integer := log2x(ncpu);
  -- Add register to improve timing paths. Adds one wait-state on
  -- Read and write accesses.
  constant pipe     : boolean := true;

  signal r, rin     : reg_type;

begin

  comb : process (rst, rtc, r, ahbi, irqi, halt)
    variable v          : reg_type;
    variable ssip       : std_logic_vector(ncpu-1 downto 0);
    variable selcpu     : integer;
    variable selcmp     : integer;
    variable hrdata     : std_logic_vector(63 downto 0);
    variable rdata      : std_logic_vector(63 downto 0);
    variable hwdata     : std_logic_vector(63 downto 0);
    variable wdata      : std_logic_vector(63 downto 0);
    variable offset     : std_logic_vector(16 downto 14);
    variable stime      : std_logic_vector(63 downto 0);
  begin

    v := r;

    v.hsel    := (others => '0');
    v.hready  := '1';
    v.hresp   := HRESP_OKAY;

    rdata       := (others => '0');

    ssip := (others => '0');


    ---------------------------------------------------
    -- Machine Timer
    ---------------------------------------------------

    -- Platforms provide a real-time counter, exposed as a memory-mapped
    -- machine-mode read-write register, mtime. mtime must run at constant frequency,
    -- and the platform must provide a mechanism for determining
    -- the timebase of mtime.

    -- The mtime register has a 64-bit precision on all RV32, RV64, and RV128 systems.

    stime := (others => '0');
    if mtimer = 1 then
      -- 3-stage synchronizer
      v.rtcsync(0)        := rtc;
      v.rtcsync(1)        := r.rtcsync(0);
      v.rtcsync(2)        := r.rtcsync(1);

      if r.rtcsync(1) = '0' and r.rtcsync(2) = '1' and halt = '0' then
        v.mtime     := r.mtime + 1;
      end if;
      stime(MTIMEBITS-1 downto 0) := r.mtime;
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

      if (unsigned(r.mtime) >= unsigned(r.mtimecmp(i))) then
        v.mtip(i)       := '1';
      else
        v.mtip(i)       := '0';
      end if;

    end loop;



    ---------------------------------------------------
    -- Watchdog logic
    ---------------------------------------------------
    if watchdog = 1 then

      if v.mtime(wdtickbit) = '1' and r.mtime(wdtickbit) = '0' and r.wden = '1' then
        v.cnt := r.cnt - 1;
      end if;

      if unsigned(r.cnt) = 0 and r.wden = '1' then
        if r.s1wto = '0' then
          v.s1wto := '1';
          v.cnt := r.wtocnt;
        else
          v.s2wto := '1';
        end if;
      end if;
    end if;




    ---------------------------------------------------
    -- AHB Interface
    ---------------------------------------------------

    selcpu      := to_integer(unsigned(r.haddr(13 downto 2)));
    selcmp      := to_integer(unsigned(r.haddr(15) & r.haddr(13 downto 3)));
    --selcmp      := to_integer(unsigned(r.haddr(15) & r.haddr(ncpubits+1 downto 3)));
    --selcmp      := to_integer(unsigned(r.haddr(ncpubits+2 downto 3)));

    hwdata(63 downto 32) := ahbi.hwdata( 63 mod AHBDW downto 32 mod AHBDW);
    hwdata(31 downto  0) := ahbi.hwdata( 31           downto  0);

    -- Slave selected
    if (ahbi.hready and ahbi.hsel(hindex) and ahbi.htrans(1)) = '1' then
      v.hsel(0)  := '1';
      v.haddr    := ahbi.haddr;
      v.hsize    := ahbi.hsize;
      v.hwrite   := ahbi.hwrite;
      -- pipe
      if pipe then
        v.hready   := '0';
      end if;
    end if;

    -- Write data
    if pipe then
      if r.hsel(0) = '1' and r.hwrite = '1' then
        v.hwdata := hwdata;
      end if;
      wdata := r.hwdata;
      v.hsel(1) := r.hsel(0);
    else
      wdata := hwdata;
      v.hwdata := (others => '0');
      v.hsel(1) := v.hsel(0);
    end if;

    offset := r.haddr(offset'range);
    -- Read access
    if r.hsel(0) = '1' and r.haddr(19 downto 17) = "000" and (r.hsize = "010" or r.hsize = "011") then
      case offset is
        when "000" => -- MSIP
          if mswi = 1 then
            if selcpu < ncpu then
               --r.haddr(13 downto ncpubits+2) = zero32(13 downto ncpubits+2) then
              rdata(0)      := r.msip(selcpu);
            end if;
          end if;
        when "001" | "010" => -- MTIMECMP | MTIME
          if mtimer = 1 then
            if r.haddr(15 downto 3) = (x"bff" & '1')  then -- MTIME: 0xBFF8 - 0xBFFC
              rdata := r.mtime;
            else -- MTIMECMP
              if selcmp < ncpu then
               --r.haddr(13 downto ncpubits+3) = zero32(13 downto ncpubits+3) then
                rdata := r.mtimecmp(selcmp);
              end if;
            end if;
          end if;
          -- Replicate data for 32-bit access either the low
          -- or the high part of the register
          if r.hsize = "010" then
            if r.haddr(2) = '0' then
              rdata(63 downto 32) := rdata(31 downto 0);
            else
              rdata(31 downto 0) := rdata(63 downto 32);
            end if;
          end if;
        when "011" => -- (SETSSIP)
          -- Read-only zero
        when "100" => -- Watchdog
          if watchdog = 1 then
            rdata(0) := r.wden;
            rdata(2) := r.s1wto;
            rdata(3) := r.s2wto;
            rdata(13 downto 4) := r.wtocnt;
          end if;
        when others =>
      end case;
      -- Replicate data for 32-bit access
      if r.hsize = "010" then
        rdata(63 downto 32) := rdata(31 downto 0);
      end if;
      v.hrdata := rdata;
    end if;

    -- Write access
    if r.hsel(1) = '1' and r.haddr(19 downto 17) = "000" and r.hwrite = '1' and (r.hsize = "010" or r.hsize = "011") then
      case offset is
        when "000" => -- MSIP
          if mswi = 1 then
            if selcpu < ncpu then
              v.msip(selcpu) := wdata(0);
            end if;
          end if;
        when "001" | "010" => -- MTIMECMP | MTIME
          if mtimer = 1 then
            if r.haddr(15 downto 3) = (x"bff" & '1')  then -- MTIME: 0xBFF8 - 0xBFFC
              if r.hsize = "011" then -- 64-bit
                v.mtime := wdata;
              else -- r.hsize = "010" (32-bit)
                if r.haddr(2) = '0' then
                  v.mtime(31 downto 0) := wdata(31 downto 0);
                else
                  v.mtime(63 downto 32) := wdata(63 downto 32);
                end if;
              end if;
            else -- MTIMECMP
              if selcmp < ncpu then
                if r.hsize = "011" then -- 64-bit
                  v.mtimecmp(selcmp) := wdata;
                else -- r.hsize = "010" (32-bit)
                  if r.haddr(2) = '0' then
                    v.mtimecmp(selcmp)(31 downto 0) := wdata(31 downto 0);
                  else
                    v.mtimecmp(selcmp)(63 downto 32) := wdata(63 downto 32);
                  end if;
                end if;
              end if;
            end if;
          end if;
        when "011" => -- (SETSSIP)
          if sswi = 1 then
            if selcpu < ncpu then
              ssip(selcpu) := wdata(0);
            end if;
          end if;
        when "100" => -- Watchdog
          if watchdog = 1 then
            v.wden   := wdata(0);
            v.s1wto  := wdata(2);
            v.s2wto  := wdata(3);
            v.wtocnt := wdata(13 downto 4);
            v.cnt := v.wtocnt;
          end if;
        when others =>
      end case;
    end if;

    -- Error response (only support 32,64-bit accesses)
    if pipe then
      if r.hsel(0) = '1' then
        if r.hsize /= "011" and r.hsize /= "010" then
          v.hready := '0';
          v.hresp  := HRESP_ERROR;
        end if;
      end if;
    else
      if v.hsel(0) = '1' then
        if v.hsize /= "011" and v.hsize /= "010" then
          v.hready := '0';
          v.hresp  := HRESP_ERROR;
        end if;
      end if;
    end if;
    -- Second error response cycle
    if r.hready = '0' and r.hresp = HRESP_ERROR then
      v.hresp := HRESP_ERROR;
    end if;

    -- Read data
    if pipe then
      hrdata := r.hrdata;
    else
      hrdata := rdata;
      v.hrdata := (others => '0');
    end if;

    rin <= v;

    -- AHB Interface
    ahbo                <= ahbs_none;
    ahbo.hready         <= r.hready;
    ahbo.hrdata         <= ahbdrivedata(hrdata);
    ahbo.hresp          <= r.hresp;
    ahbo.hsplit         <= (others => '0');
    ahbo.hirq           <= (others => '0');
    ahbo.hconfig        <= hconfig;
    ahbo.hindex         <= hindex;

    if watchdog = 1 then
      if r.wden = '1' then
        ahbo.hirq(hirq1) <= r.s1wto;
        ahbo.hirq(hirq2) <= r.s2wto;
      end if;
    end if;

    -- IRQ Interface
    irqo              <= (others => nv_irq_in_none);
    for i in 0 to ncpu-1 loop
      irqo(i).mtip    <= '0';
      irqo(i).msip    <= '0';
      irqo(i).ssip    <= '0';
      irqo(i).meip    <= irqi(i).meip;
      irqo(i).seip    <= irqi(i).seip;
      irqo(i).ueip    <= irqi(i).ueip;
      irqo(i).heip    <= irqi(i).heip;
      irqo(i).hgeip   <= irqi(i).hgeip;
      irqo(i).stime   <= stime;
    end loop;

    if mswi = 1 then
      for i in 0 to ncpu-1 loop
        irqo(i).msip           <= r.msip(i);
      end loop;
    end if;
    if mtimer = 1 then
      for i in 0 to ncpu-1 loop
        irqo(i).mtip           <= r.mtip(i);
      end loop;
    end if;
    if sswi = 1 then
      for i in 0 to ncpu-1 loop
        irqo(i).ssip           <= ssip(i);
      end loop;
    end if;

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
