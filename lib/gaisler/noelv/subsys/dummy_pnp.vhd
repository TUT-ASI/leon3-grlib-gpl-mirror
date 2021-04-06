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
-- Entity:      dummy_pnp
-- File:        dummy_pnp.vhd
-- Author:      Nils Wessman, Cobham Gaisler
-- Description: Dummy pnp for the debug bus.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.config_types.all;
use grlib.config.all;
use grlib.devices.all;
library gaisler;
use gaisler.misc.all;

entity dummy_pnp is
  generic (
    hindex  : integer;
    ioarea  : integer;
    devid   : integer
  );
  port (
    ahbsi    : in  ahb_slv_in_type;
    ahbso    : out ahb_slv_out_type);
end;

architecture rtl of dummy_pnp is
  -- Core version
  constant AHB2AHB_VER  : amba_version_type := 2;

begin
  comb : process(ahbsi)
    variable slvcfg   : ahb_config_type;
    variable tbar     : std_logic_vector(29 downto 0);
  begin
    -- slave configuration info
    slvcfg := (others => (others => '0'));
    slvcfg(0) := ahb_device_reg(VENDOR_GAISLER, GAISLER_AHB2AHB, 0, AHB2AHB_VER, 0);
    slvcfg(1)(8) := conv_std_logic(true); -- UP
    slvcfg(1)(7 downto 4) := conv_std_logic_vector(1, 4); -- ffact
    slvcfg(1)(3 downto 2) := conv_std_logic_vector(1 mod 4, 2); -- mbus
    slvcfg(1)(1 downto 0) := conv_std_logic_vector(0 mod 4, 2); -- sbus
    slvcfg(2)(31 downto 20) := conv_std_logic_vector(ioarea, 12);
    tbar := conv_std_logic_vector(ahb2ahb_membar(ioarea, '0', '0', 16#FFF#), 30);
    slvcfg(4)(31 downto 20) := tbar(29 downto 18); slvcfg(4)(17 downto 0) := tbar(17 downto 0);
    
    ahbso.hready  <= '1';
    ahbso.hresp   <= "00";
    ahbso.hrdata  <= (others => '0');
    ahbso.hconfig <= slvcfg;
    ahbso.hindex  <= hindex;
  end process;

end;
