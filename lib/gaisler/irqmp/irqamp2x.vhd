------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
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
-- Entity: 	irqamp2x
-- File:	irqamp2x.vhd
-- Author:	Edvin Catovic - Gaisler Research
-- Description:	Multi-processor APB interrupt controller wrapper for use  
--		in multifrequency designs. 
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.leon3.all;

entity irqamp2x is
  generic (
    pindex     : integer := 0;
    paddr      : integer := 0;
    pmask      : integer := 16#fff#;
    ncpu       : integer := 1;
    eirq       : integer := 0;
    nctrl      : integer range 1 to 16 := 1;
    tstamp     : integer range 0 to 16 := 0;
    wdogen     : integer range 0 to 1 := 0;
    nwdog      : integer range 1 to 16 := 1;
    dynrstaddr : integer range 0 to 1 := 0;
    rstaddr    : integer range 0 to 16#fffff# := 0;
    extrun     : integer range 0 to 1 := 0;
    clkfact    : integer := 2
  );
  port (
    rst    : in  std_ulogic;
    hclk   : in  std_ulogic;
    cpuclk : in  std_ulogic;
    apbi   : in  apb_slv_in_type;
    apbo   : out apb_slv_out_type;
    irqi   : in  irq_out_vector(0 to ncpu-1);
    irqo   : out irq_in_vector(0 to ncpu-1);
    wdog   : in  std_logic_vector(nwdog-1 downto 0) := (others => '0');
    cpurun : in  std_logic_vector(ncpu-1 downto 0) := (others => '0');
    hclken : in  std_ulogic
  );
end;

architecture rtl of irqamp2x is

  type irl_type is array (0 to ncpu-1) of std_logic_vector(3 downto 0);
  
  type hclk_reg_type is record 
    intack : std_logic_vector(0 to ncpu-1);
    irl    : irl_type;
    pwd    : std_logic_vector(0 to ncpu-1);
  end record;

  type cpuclk_reg_type is record 
    intack_acc : std_logic_vector(0 to ncpu-1);
    irl_capt   : irl_type;
    hclken2     : std_ulogic;    
  end record;                           

  signal irqi2    : irq_out_vector(0 to ncpu-1);    
  
  begin
    sync : if clkfact /= 0 generate
      syncblock : block
        signal r, rin   : hclk_reg_type;
        signal r2, r2in : cpuclk_reg_type;
      begin
        comb : process(rst, irqi, hclken, r, r2)
          variable v  : hclk_reg_type;
          variable v2 : cpuclk_reg_type;
        begin
          v2.hclken2 := hclken; 
          for i in 0 to ncpu-1 loop
            v.pwd(i) := irqi(i).pwd;
            v2.intack_acc(i) := not hclken and irqi(i).intack;
            if (clkfact > 2) then
              v2.intack_acc(i) := v2.intack_acc(i) or (not (hclken or r2.hclken2) and r2.intack_acc(i));
            end if;
            v.intack(i) := irqi(i).intack or r2.intack_acc(i);

            v2.irl_capt(i) := irqi(i).irl;
            if (clkfact > 2) then
              if (irqi(i).intack and not r2.intack_acc(i)) = '0' then
                v2.irl_capt(i) := r2.irl_capt(i);
              end if;
            end if;

            if r2.intack_acc(i) = '1' then
              v.irl(i) := r2.irl_capt(i);
            else
              v.irl(i) := irqi(i).irl;
            end if;

            irqi2(i).irl    <= r.irl(i);
            irqi2(i).intack <= r.intack(i);
            irqi2(i).pwd    <= irqi(i).pwd; --r.pwd(i);
            irqi2(i).fpen   <= irqi(i).fpen;
            irqi2(i).idle   <= irqi(i).idle;
        
          end loop;

          if rst = '0' then
            v.intack := (others => '0'); v2.intack_acc := (others => '0');
          end if;

          rin <= v; r2in <= v2;      
        end process;

        reg1 : process(hclk)
        begin
          if rising_edge(hclk) then
            r <= rin;
          end if;
        end process;

        reg2 : process(cpuclk)
        begin
          if rising_edge(cpuclk) then
            r2 <= r2in;
          end if;
        end process;          
      end block syncblock;
    end generate;
    nosync : if clkfact = 0 generate
      irqi2 <= irqi;
    end generate;
    
    irqamp0 : irqamp
      generic map (pindex, paddr, pmask, ncpu, eirq, nctrl, tstamp, wdogen,
                   nwdog, dynrstaddr, rstaddr, extrun)
      port map (rst, hclk, apbi, apbo, irqi2, irqo, wdog, cpurun);

end;

