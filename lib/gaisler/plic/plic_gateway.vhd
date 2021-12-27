------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
-- Entity:      plic_gateway
-- File:        plic_gateway.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
-- Description: RISC-V PLIC Interrupt Gateway
--
--              It includes a RISC-V privilege spec 1.11 (WIP) compatible
--              PLIC Interrupt Gateway 
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

entity plic_gateway is
  generic (
    pendingbuff : integer range 0 to 32 := 8;
    irqtype     : integer range 0 to 1 := 0 -- 0 for level, 1 for edge
    );
  port (
    rst         : in  std_ulogic;
    clk         : in  std_ulogic;
    irqi        : in  std_ulogic;
    ip          : out std_ulogic;
    claim       : in  std_ulogic;
    complete    : in  std_ulogic
    );
end plic_gateway;

architecture rtl of plic_gateway is

  constant REVISION : integer := 0;

  constant buffbits     : integer := log2x(pendingbuff);
  constant max_pending  : integer := 32;
  constant zeros        : std_logic_vector(buffbits-1 downto 0) := (others => '0');
  constant max          : std_logic_vector(buffbits-1 downto 0) := conv_std_logic_vector(max_pending-1, buffbits);

  type reg_type is record
    irqsync     : std_ulogic;
    pending     : std_logic_vector(buffbits-1 downto 0);
    claimed     : std_ulogic;
    decr        : std_ulogic;
    irqo        : std_ulogic;
  end record;

  constant RES_T : reg_type := (
    irqsync     => '0',
    pending     => (others => '0'),
    claimed     => '0',
    decr        => '0',
    irqo        => '0'
  );

  signal r, rin         : reg_type;

begin

  comb : process (rst, r, irqi, claim, complete)
    variable v          : reg_type;
  begin

    v := r;

    ---------------------------------------------------
    -- Interrupt Detection
    ---------------------------------------------------

    -- If the global interrupt source uses level-sensitive interrupts, the gateway
    -- will convert the first assertion of the interrupt level into an interrupt request,
    -- but thereafter the gateway will not forward an additional interrupt request until
    -- it receives an interrupt completion message. On receiving an interrupt completion message,
    -- if the interrupt is level-triggered and the interrupt is still asserted,
    -- a new interrupt request will be forwarded to the PLIC core.
    -- The gateway does not have the facility to retract an interrupt request once forwarded to
    -- the PLIC core. If a level-sensitive interrupt source deasserts the interrupt after
    -- the PLIC core accepts the request and before the interrupt is serviced,
    -- the interrupt request remains present in the IP bit of the PLIC core and will be
    -- serviced by a handler, which will then have to determine that the interrupt device
    -- no longer requires service.

    -- If the global interrupt source was edge-triggered, the gateway will convert the
    -- first matching signal edge into an interrupt request. Depending on the design of
    -- the device and the interrupt handler, inbetween sending an interrupt request and
    -- receiving notice of its handler’s completion, the gateway might either ignore additional
    -- matching edges or increment a counter of pending interrupts. In either case, the next
    -- interrupt request will not be forwarded to the PLIC core until the
    -- previous completion message has been received. If the gateway has a pending interrupt
    -- counter, the counter will be decremented when the interrupt request is accepted by the
    -- PLIC core.

    -- Irq edge detection
    v.irqsync           := irqi;

    -- Irq pending counter with edge-triggered interrupts
    if r.irqsync = '0' and irqi = '1' then
      if r.pending /= max then
        v.pending       := r.pending + 1;
      end if;
    end if;

    if (r.decr = '1' and r.pending /= zeros) then
      v.pending       := r.pending - 1;
    end if;
    
    ---------------------------------------------------
    -- Interrupt Generation
    ---------------------------------------------------

    -- The interrupt gateways are responsible for converting global interrupt signals
    -- into a common interrupt request format, and for controlling the flow of interrupt
    -- requests to the PLIC core. At most one interrupt request per interrupt source can be
    -- pending in the PLIC core at any time, indicated by setting the source’s IP bit.
    -- The gateway only forwards a new interrupt request to the PLIC core after receiving
    -- notification that the interrupt handler servicing the previous interrupt request
    -- from the same source has completed.

    v.decr              := '0';

    -- Wait for interrupt request
    if (r.irqo = '0' and r.claimed = '0') then

      if (v.pending /= zeros and irqtype = 1) or (irqi = '1' and irqtype = 0) then
        v.irqo          := '1';
      end if;

    -- Wait for claim
    elsif (r.irqo = '1' and r.claimed = '0') then
      if claim = '1' then
        v.claimed       := '1';
        v.irqo          := '0';
        v.decr          := '1';
      end if;

    -- Wait for complete
    elsif (r.irqo = '0' and r.claimed = '1') then
      if complete = '1' then
        v.claimed     := '0';
      end if;

    end if;

    rin <= v;

    -- Interrupt Output
    ip  <= r.irqo;
    
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

