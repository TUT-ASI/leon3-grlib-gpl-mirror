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
-- Entity:      axi2apb
-- File:        axi2apb.vhd
-- Authors:     Martin Caous George - Frontgrade Gaisler
-- Description: AXI4 to APB bridge
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.axi.all;

entity axi2apb is
  generic (
    nslaves   : integer range 1 to NAPBSLV := NAPBSLV;
    idwidth   : integer range 0 to 2*AXI_ID_WIDTH := AXI_ID_WIDTH;
    dwidth    : integer range 32 to AXIDW := AXIDW
  );
  port (
    aclk      : in  std_ulogic;
    aresetn   : in  std_ulogic;
    -- AXI slave port
    axisi     : in  axi4_mosi_type;
    axixsi    : in  extaxi_mosi_type;
    axiso     : out axi_somi_type;
    axixso    : out extaxi_miso_type;
    -- APB
    apbi      : out apb_slv_in_vector;
    apbo      : in  apb_slv_out_vector;
    apbendian : in  std_ulogic := '0' -- '0' big endian, '1' little endian
  );
end;

architecture rtl of axi2apb is

  signal apb3i : apb3_slv_in_type;
  signal apb3o : apb3_slv_out_vector;

begin

   axi2apbx : axi2apb3
    generic map (
      nslaves   => nslaves,
      idwidth   => idwidth,
      dwidth    => dwidth
    )
    port map (
      aclk      => aclk,
      aresetn   => aresetn,
      -- AXI slave port
      axisi     => axisi,
      axixsi    => axixsi,
      axiso     => axiso,
      axixso    => axixso,
      -- APB
      apbi      => apb3i,
      apbo      => apb3o,
      apbendian => apbendian
    );

  p_comb: process(apb3i, apbo)
  begin
    for i in 0 to NAPBSLV-1 loop
      apbi(i) <= (
        psel    => apb3i.psel,
        penable => apb3i.penable,
        paddr   => apb3i.paddr,
        pwrite  => apb3i.pwrite,
        pwdata  => apb3i.pwdata,
        pirq    => apb3i.pirq,
        testen  => apb3i.testen,
        testrst => apb3i.testrst,
        scanen  => apb3i.scanen,
        testoen => apb3i.testoen,
        testin  => apb3i.testin
      );

      apb3o(i) <= (
        prdata  => apbo(i).prdata,
        pready  => '1',
        pslverr => '0',
        pirq    => apbo(i).pirq,
        pconfig => apbo(i).pconfig,
        pindex  => apbo(i).pindex
      );
    end loop;
  end process;

end;