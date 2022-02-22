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
-- Entity:      plic_target
-- File:        plic_target.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
-- Description: RISC-V PLIC Target Block
--
--              It includes a RISC-V privilege spec 1.11 (WIP) compatible
--              PLIC Target Block. Attention: this is a pure combinatorial IP block.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;

library gaisler;
use gaisler.plic.all;

entity plic_target is
  generic (
    prbits      : integer := 3;
    srcbits     : integer := 4
    );
  port (
    priority    : in  std_logic_vector(prbits-1 downto 0);
    threshold   : in  std_logic_vector(prbits-1 downto 0);
    irqreq      : out std_ulogic
    );
end plic_target;

architecture rtl of plic_target is

begin

  comb : process (priority, threshold)
    variable eip        : std_ulogic;
  begin

    ---------------------------------------------------
    -- Interrupt Notifications
    ---------------------------------------------------

    -- Each interrupt target has an external interrupt pending (EIP) bit in the PLIC core
    -- that indicates that the corresponding target has a pending interrupt waiting for service.
    -- The value in EIP can change as a result of changes to state in the PLIC core, brought on
    -- by interrupt sources, interrupt targets, or other agents manipulating register values in
    -- the PLIC. The value in EIP is communicated to the destination target as an interrupt
    -- notification. If the target is a RISC-V hart context, the interrupt notifications arrive
    -- on the meip/seip/ueip bits depending on the privilege level of the hart context.

    if (priority > threshold) then
      eip       := '1';
    else
      eip       := '0';
    end if;

    irqreq      <= eip;
    
  end process;

end rtl;

