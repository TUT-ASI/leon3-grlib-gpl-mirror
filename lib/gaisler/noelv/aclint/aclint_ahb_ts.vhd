------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
-- Entity:      aclint_ahb_ts
-- File:        aclint_ahb_ts.vhd
-- Author:      Andrea Merlo, Nils Wessman, Francisco Bas, Cobham Gaisler AB
-- Description: RISC-V Core Local Interrupt Controller
--
--              It includes a RISC-V privilege spec 1.11 (WIP) compatible timer
--              and handling mechanism for machine software interrupt (msip)
--              With AHB AMBA interface to support 64-bit accesses.
------------------------------------------------------------------------------

-- ACLINT -----------------------
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

-- mtime lo         @ bff8
-- mtime hi         @ bffc

---------------------------------

-- 0x14000 watchdog

---------------------------------

-- Interrupt controllers:
-- 0x18000:  Interrupt Capability Low
-- 0x18004:  Interrupt Capability High
-- 0x18008:  APLIC/PLIC Softreset
-- ...       RESERVED
-- 0x18100:  PLIC IRQ Trigger Type sources 0-31
-- 0x18104:  PLIC IRQ Trigger Type sources 32-63
-- ...
-- 0x1817c:  PLIC IRQ Trigger Type sources 992-1023

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.zero32;
use grlib.stdlib."+";
use grlib.stdlib."-";
use grlib.stdlib.log2x;

library gaisler;
use gaisler.noelv.all;
use gaisler.l5nv_shared.l5_tsc_ctrl_type;
use gaisler.l5nv_shared.l5_tsc_ctrl_none;

entity aclint_ahb_ts is
  generic (
    hbaren      : integer range 0 to 1          := 0;  -- When set to 1 aclint is part of an ahb slave with several mem bars
    hindex      : integer range 0 to NAHBSLV-1  := 0;
    haddr       : integer range 0 to 16#FFF#    := 0;
    hbar        : integer range 0 to 3          := 0;
    hmask       : integer range 0 to 16#FFF#    := 16#FFF#;
    hirq1       : integer range 0 to NAHBSLV-1  := 0;
    hirq2       : integer range 0 to NAHBSLV-1  := 0;
    ncpu        : integer range 0 to 4096       := 4;
    mswi        : integer range 0 to 1          := 1;  -- Enables MSWI ACLINT's device (machine software interrupts)
    mtimer      : integer range 0 to 1          := 1;  -- Enables MTIMER ACLINT's device (machine timer interrupts)
    mtimebits   : integer range 33 to 64        := 63; -- mtime number of bits
    asyncset    : integer range 0 to 1;
    sswi        : integer range 0 to 1          := 1;  -- Enables SSWI ACLINT's device (supervisor software interrupts)
    watchdog    : integer range 0 to 1          := 1;  -- Enables watchdog
    wdtickbit   : integer range 0 to 63         := 4;  -- MTIME bit used for the watchdog tick
    plicirqtreg : integer                       := 0;  -- Enable PLIC IRQ Type registers
    plicrstreg  : integer                       := 0;  -- Enable PLIC reset bit
    aplicrstreg : integer                       := 0;  -- Enable APLIC bit in softreset register
    nsources    : integer range 0 to 1024       := 0;  -- Number of interrupt sources
    plicirqtrst : integer range 0 to 1          := 0;  -- PLIC irq trigger type reste values (0 => level; 1 => edge)
    scantest    : integer                       := 0
    );
  port (
    rst       : in  std_ulogic;
    clk       : in  std_ulogic;
    timer     : in  std_logic_vector(mtimebits-1 downto 0);
    ahbi      : in  ahb_slv_in_type;
    ahbo      : out ahb_slv_out_type;
    irqo      : out nv_irq_in_vector(0 to ncpu-1);
    ack       : in  std_ulogic;
    ctrl      : out l5_tsc_ctrl_type;
    intcap    : in  std_logic_vector(63 downto 0) := (others => '0');
    plicirqt  : out std_logic_vector(nsources-1 downto 0);
    plicrstn  : out std_ulogic;
    aplicrstn : out std_ulogic
    );
end;

architecture rtl of aclint_ahb_ts is

  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  constant REVISION : integer := 1;

  -- If hbaren is set to 1 this output will be ignored
  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_ACLINT, 0, REVISION, 0),
    4 => ahb_membar(haddr, '0', '0', hmask),
    others => zero32);

  constant zeros        : std_logic_vector(mtimebits-1 downto 0) := (others => '0');

  type mtimecmp_type is array (0 to ncpu-1) of std_logic_vector(63 downto 0);

  type reg_type is record
    -- ACLINT
    rtcsync     : std_logic_vector(2 downto 0);
    mtime       : std_logic_vector(mtimebits-1 downto 0);
    mtimecmp    : mtimecmp_type;
    msip        : std_logic_vector(ncpu-1 downto 0);
    mtip        : std_logic_vector(ncpu-1 downto 0);
    tsctrl      : l5_tsc_ctrl_type;
    ack         : std_ulogic;
    unsynced    : std_ulogic;
    timebuf     : std_logic_vector(mtimebits-1 downto 0);
    -- Watchdog
    wden     : std_ulogic;
    s1wto    : std_ulogic;
    s2wto    : std_ulogic;
    wtocnt   : std_logic_vector(9 downto 0);
    cnt      : std_logic_vector(9 downto 0);
    -- PLIC control
    plicirqt : std_logic_vector(nsources-1 downto 0);
    plicrst  : std_ulogic;
    aplicrst : std_ulogic;
    -- AHB
    busy        : std_ulogic;
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
    tsctrl      => l5_tsc_ctrl_none,
    ack         => '0',
    unsynced    => '0',
    timebuf     => (others => '0'),
    -- Watchdog
    wden    => '0',
    s1wto   => '0',
    s2wto   => '0',
    wtocnt  => (others => '0'),
    cnt     => (others => '1'),
    -- PLIC Control
    plicirqt => (others => to_unsigned(plicirqtrst, 1)(0)),
    plicrst  => '0',
    aplicrst => '0',
    -- AHB
    busy        => '0',
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

  signal r, rin     : reg_type;
  signal arst       : std_ulogic;

begin
  arst        <= ahbi.testrst when (ASYNC_RESET and scantest/=0 and ahbi.testen/='0') else
                 rst when ASYNC_RESET else '1';

  comb : process (rst, timer, r, ahbi, ack)
    variable v          : reg_type;
    variable ssip       : std_logic_vector(ncpu-1 downto 0);
    variable selcpu     : integer;
    variable selcmp     : integer;
    variable selpcfgreg : integer;

    variable hsel       : std_ulogic;
    variable hrdata     : std_logic_vector(63 downto 0);
    variable rdata      : std_logic_vector(63 downto 0);
    variable hwdata     : std_logic_vector(63 downto 0);
    variable wdata      : std_logic_vector(63 downto 0);
    variable offset     : std_logic_vector(16 downto 14);
    variable mtime      : std_logic_vector(mtimebits-1 downto 0);
  begin

    v := r;

    v.hsel    := (others => '0');
    v.hready  := '1';
    v.hresp   := HRESP_OKAY;

    v.plicrst  := '0';
    v.aplicrst := '0';

    v.ack     := ack;

    rdata     := (others => '0');

    ssip      := (others => '0');


    ---------------------------------------------------
    -- Machine Timer
    ---------------------------------------------------
    v.mtime := timer; -- Only used by the watchdog

    -- l5tscgen raises strobe for high bits when timer[7:6]=10 or timer[7:6]=01
    -- Hence, it could take a while to update time. We keep a local copy of the
    -- updated value until timer is updated.
    if r.unsynced = '0' then
      mtime := timer;
    else
      mtime := r.timebuf(mtimebits-1 downto 8) & timer(7 downto 0);
    end if;

    if r.timebuf(mtimebits-1 downto 8) + 1 = timer(mtimebits-1 downto 8) then
      -- timer is synced again
       v.unsynced := '0';
    end if;

    if asyncset = 0 or (not r.ack and v.ack) = '1' then
      v.tsctrl.set := '0';
      v.busy       := '0';
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

      if (unsigned(mtime) >= unsigned(r.mtimecmp(i))) then
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
    selpcfgreg  := to_integer(unsigned(r.haddr(7 downto 2)));

    hwdata(63 downto 32) := ahbi.hwdata( 63 mod AHBDW downto 32 mod AHBDW);
    hwdata(31 downto  0) := ahbi.hwdata( 31           downto  0);

    -- cycle 1: A new transaction is sampled if the bus is not busy
    -- cycle 2: hready=0, we check if we are writing to mtime.
    --          If so, we set busy and hready to 0 the next cycle.
    -- if not busy
    --   * cycle 3/4: The transaction is completed normailly, hready=1
    -- if busy:
    --   * While transaction is ongoing, r.busy = 1 and r.hready = 0.
    --     New transactions are not sampled anymore.
    --   * When transaction is completed, the next cycle busy is set to 0,
    --     hready to 1, and the the next cycle the new transaction will be
    --     sampled.

    -- Slave selected
    -- If it belongs to a AHB slave with several memory bars we need to  check
    -- it the memory bar is selected
    if hbaren = 0 then
      hsel :=  ahbi.hsel(hindex);
    else
      hsel :=  ahbi.hsel(hindex) and ahbi.hmbsel(hbar);
    end if;
    if (ahbi.hready and hsel and ahbi.htrans(1)) = '1' then
      v.hsel(0)  := '1';
      v.haddr    := ahbi.haddr;
      v.hsize    := ahbi.hsize;
      v.hwrite   := ahbi.hwrite;
      -- pipe
      v.hready   := '0';
    end if;

    -- If busy with a write to mtime
    -- we don't accept new trnasactions
    if r.busy = '1' then
      v.hsel(0) := '0';
    end if;

    -- Write data
    if r.hsel(0) = '1' and r.hwrite = '1' then
      v.hwdata := hwdata;
    end if;
    wdata := r.hwdata;
    v.hsel(1) := r.hsel(0);
    if r.hsel(0) = '1' and r.haddr(19 downto 3) = (x"0" & x"bff" & '1') and r.hwrite = '1' and
       (r.hsize = "011" or r.hsize = "010") then
      -- If we write mtime the transaction will take several cycles to complete
      v.busy := '1';
    end if;

    -- While busy we clear hready
    if v.busy = '1' then
      v.hready := '0';
    end if;

    offset := r.haddr(offset'range);
    -- Read access
    if r.hsel(0) = '1' and r.haddr(19 downto 17) = "000" and (r.hsize = "010" or r.hsize = "011") then
      case offset is
        when "000" => -- MSIP
          if mswi = 1 then
            if selcpu < ncpu then
              rdata(0)      := r.msip(selcpu);
            end if;
          end if;
        when "001" | "010" => -- MTIMECMP | MTIME
          if mtimer = 1 then
            if r.haddr(15 downto 3) = (x"bff" & '1')  then -- MTIME: 0xBFF8 - 0xBFFC
              rdata(mtimebits-1 downto 0) := mtime;
            else -- MTIMECMP
              if selcmp < ncpu then
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
        when "101" => -- Watchdog
          if watchdog = 1 then
            rdata(0) := r.wden;
            rdata(2) := r.s1wto;
            rdata(3) := r.s2wto;
            rdata(13 downto 4) := r.wtocnt;
          end if;
        when "110" => -- Interrupt Controller Registers
          if r.haddr(13 downto 9) = zero32(13 downto 9) then
            if r.haddr(8) = '0' then
              if r.haddr(7 downto 6) = "00" then
                case r.haddr(5 downto 2) is
                  when x"0" | x"1" =>  -- (0x18000) Interrupt Capability Register
                    rdata := intcap;
                    -- Replicate data for 32-bit access either the low
                    -- or the high part of the register
                    if r.hsize = "010" then
                      if r.haddr(2) = '0' then  -- 0x18000 (Low)
                        rdata(63 downto 32) := intcap(31 downto 0);
                      else                      -- 0x18000 (High)
                        rdata(31 downto 0) := intcap(63 downto 32);
                      end if;
                    end if;
                  when others =>
                end case;
              end if;
            else -- (0x18100) PLIC Interrupt Trigger configuration registers
              if plicirqtreg /= 0 then
                for i in 0 to (nsources/32)-1 loop
                  if i = selpcfgreg then
                    rdata(31 downto 0)   := r.plicirqt((i+1)*32-1 downto i*32);
                  end if;
                end loop;
              end if;
            end if;
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
                v.tsctrl.setval := wdata(mtimebits-1 downto 0);
                v.tsctrl.set    := '1';
                v.timebuf       := wdata(mtimebits-1 downto 0);
                v.unsynced      := '1';
              else -- r.hsize = "010" (32-bit)
                if r.haddr(2) = '0' then
                  v.tsctrl.setval := mtime(mtimebits-1 downto 32) & wdata(mtimebits-32 downto 0);
                  v.timebuf       := mtime(mtimebits-1 downto 32) & wdata(mtimebits-32 downto 0);
                else
                  v.tsctrl.setval := wdata(mtimebits-1 downto 32) & mtime(mtimebits-32 downto 0);
                  v.timebuf       := wdata(mtimebits-1 downto 32) & mtime(mtimebits-32 downto 0);
                end if;
                v.tsctrl.set := '1';
                v.unsynced   := '1';
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
        when "101" => -- Watchdog
          if watchdog = 1 then
            v.wden   := wdata(0);
            v.s1wto  := wdata(2);
            v.s2wto  := wdata(3);
            v.wtocnt := wdata(13 downto 4);
            v.cnt := v.wtocnt;
          end if;
        when "110" => -- Interrupt Controller Registers
          if r.haddr(14 downto 9) = zero32(14 downto 9) then
            if r.haddr(8) = '0' then
              if r.haddr(7 downto 6) = "00" then
                case r.haddr(5 downto 2) is
                  when x"2" => -- (0x18008) PLIC Reset Register
                    if plicrstreg /= 0 then
                      v.plicrst  := wdata(0);
                    end if;
                    if aplicrstreg /= 0 then
                      v.aplicrst := wdata(1);
                    end if;
                  when others =>
                end case;
              end if;
            else -- (0x18100-0x187c) PLIC Interrupt Trigger configuration registers
              for i in 0 to (nsources/32)-1 loop
                if i = selpcfgreg then
                  v.plicirqt((i+1)*32-1 downto i*32) := wdata(31 downto 0);
                end if;
              end loop;
            end if;
          end if;
        when others =>
      end case;
    end if;

    -- Error response (only support 32,64-bit accesses)
    if r.hsel(0) = '1' then
      if r.hsize /= "011" and r.hsize /= "010" then
        v.hready := '0';
        v.hresp  := HRESP_ERROR;
      end if;
    end if;
    -- Second error response cycle
    if r.hready = '0' and r.hresp = HRESP_ERROR then
      v.hresp := HRESP_ERROR;
    end if;

    -- Read data
    hrdata := r.hrdata;

    if r.plicrst = '1' then
      v.plicirqt := (others => to_unsigned(plicirqtrst, 1)(0));
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

    -- PLIC/APLIC reset and config signals
    plicirqt  <= r.plicirqt;
    plicrstn  <= not(r.plicrst);
    aplicrstn <= not(r.aplicrst);

    -- tsc interface
    ctrl    <= r.tsctrl;

  end process;

  -- Synch reset
  syncrregs : if not ASYNC_RESET generate
    synch_regs : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if rst = '0' then
          r <= RES_T;
        end if;
      end if;
    end process;
  end generate;

  -- Asynch reset
  asyncrregs : if ASYNC_RESET generate
    asynch_regs : process(clk, arst)
    begin
      if arst = '0' then
        r <= RES_T;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;
  end generate;

end rtl;
