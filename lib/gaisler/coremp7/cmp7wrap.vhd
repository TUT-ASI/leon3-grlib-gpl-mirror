------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003, Gaisler Research
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
-- Entity: 	cmp7wrap
-- File:	cmp7wrap.vhd
-- Author:	Fredrik Brunnhede
--              Mikael Brunnhede
-- Modified by: Jan Andersson, Gaisler Research
-- Description:	CoreMP7 GRLIB wrapper
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.leon3.all;

entity cmp7wrap is
   generic (
      hindex  : integer := 0;
      pindex  : integer := 0;
      paddr   : integer := 16#000#;
      pmask   : integer := 16#fff#
   );
   port (
      rst     : in  std_ulogic;
      clk     : in  std_ulogic;
      ahbmi   : in  ahb_mst_in_type;
      ahbmo   : out ahb_mst_out_type;
      apbi    : in  apb_slv_in_type;
      apbo    : out apb_slv_out_type;
      irqi    : in  l3_irq_in_type;
      irqo    : out l3_irq_out_type;
      bigend  : in std_ulogic;
      -- From wrapper to MP7Bridge
      nirq    : out std_ulogic;
      nfiq    : out std_ulogic;
      HGRANT  : out std_logic;
      HRDATA  : out std_logic_vector(31 downto 0);
      HREADY  : out std_logic;
      HRESP   : out std_logic_vector(1 downto 0);
      -- To wrapper from MP7Bridge
      HADDR   : in std_logic_vector(31 downto 0);
      HBURST  : in std_logic_vector(2 downto 0);
      HBUSREQ : in std_logic;
      HLOCK   : in std_logic;
      HPROT   : in std_logic_vector(3 downto 0);
      HRESETn : in std_logic;
      HSIZE   : in std_logic_vector(2 downto 0);
      HTRANS  : in std_logic_vector(1 downto 0);
      HWDATA  : in std_logic_vector(31 downto 0);
      HWRITE  : in std_logic
   );
end;

architecture rtl of cmp7wrap is

constant REVISION  : integer := 1;

constant hconfig : ahb_config_type := (
   0 => ahb_device_reg ( VENDOR_ACTEL, ACTEL_COREMP7, 0, REVISION, 0),
   others => zero32);

constant pconfig : apb_config_type := (
  0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MP7WRAP, 0, REVISION, 0),
  1 => apb_iobar(paddr, pmask));
   
type cmp7wrap_regs is record
   nirq        : std_ulogic;                      -- Active low interrupt signal
   nfiq        : std_ulogic;                      -- Active low fast interrupt signal
   irl_reg     : std_logic_vector(3 downto 0);    -- Holds the priority of the currently served interrupt
   intack      : std_ulogic;                      -- Set 'high' (from software) to acknowledge interrupt to IRQMP
   fiq_mask    : std_logic_vector(15 downto 0);   -- Used to determine if an interrupt should be forwarded as an IRQ or FIQ
   irq_served  : std_ulogic;                      -- Used to disable the registration of new interrupts in the wrapper until
                                                  -- the current one has been acknowledged
end record;

signal r, rin : cmp7wrap_regs;

begin
   
   comb : process(rst, r, irqi, apbi)
   variable tmpirq : std_logic_vector(15 downto 0);
   variable fiq    : std_logic_vector(15 downto 0);
   variable v      : cmp7wrap_regs;
   begin
      
      v := r;
      
      -- Handles updating of the "nirq" and "nfiq" signals connected to the MP7Bridge
      if (v.irq_served = '0') then
         v.nirq := '1';
         v.nfiq := '1';
         if (irqi.irl /= "0000") then
            tmpirq := decode(irqi.irl);
            fiq := tmpirq and v.fiq_mask;
            if (fiq /= "0000000000000000") then
               v.nfiq := '0';
            else
               v.nirq := '0';
            end if;
            v.irl_reg := irqi.irl;           -- Save the interrupt level (used when acknowledging the interrupt)
            v.irq_served := '1';
         end if;
      end if;
      
      -- If the processor has acknowledged an interrupt to the IRQMP controller
      if (v.intack = '1') then
         v.intack := '0';
         v.irq_served := '0';
      end if;
      
      -- register read
      
      apbo.prdata <= (others => '0');
      case apbi.paddr(7 downto 2) is
      when "000000" => apbo.prdata(15 downto 1) <= v.fiq_mask(15 downto 1);
      when "000001" => apbo.prdata(3 downto 0) <= v.irl_reg;
      when others =>
      end case;
      
      -- register write

      if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
         case apbi.paddr(7 downto 2) is
         when "000000" => v.fiq_mask(15 downto 1) := apbi.pwdata(15 downto 1);
         when "000010" => v.intack := apbi.pwdata(0);
         when others =>
         end case;
      end if;
      
      --reset
      
      if rst = '0' then
         v.nirq := '1';
         v.nfiq := '1';
         v.irl_reg := (others=>'0');
         v.intack := '0';
         v.fiq_mask := (others=>'0');
         v.irq_served := '0';
      end if;
      
      nirq <= v.nirq;
      nfiq <= v.nfiq;
      irqo.irl    <= v.irl_reg;
      irqo.intack <= v.intack;
      
      rin <= v;
      
   end process;
   
   regs : process(clk)
   begin if rising_edge(clk) then r <= rin; end if; end process;
     
   -- To IRQMP:
   irqo.pwd    <= '0';
   
   -- APB slave outputs:
   apbo.pindex    <= pindex;
   apbo.pconfig   <= pconfig;
   apbo.pirq      <= (others => '0');
   
   -- CoreMP7 AHB master interface
   -- Inputs:
   HGRANT  <= ahbmi.HGRANT(hindex);
   HRDATA  <= ahbmi.HRDATA;
   HREADY  <= ahbmi.HREADY;
   HRESP   <= ahbmi.HRESP;
   -- Outputs:
   ahbmo.HCONFIG <= hconfig;
   ahbmo.HINDEX  <= hindex;
   ahbmo.HADDR(31 downto 2) <= HADDR (31 downto 2);

   --This rearranges the memory bank select signals to account for
   --endianess effects, since GRLIB is designed for the big-endian
   --LEON3 and the CoreMP7 is little-endian. Only byte and halfword
   --load/store instructions are affected.
   ahbmo.HADDR(1 downto 0) <= not HADDR(1 downto 0) when (HSIZE="000" and bigend='0') else 
                              not HADDR(1) & '0' when (HSIZE="001" and bigend='0') else 
                              HADDR(1 downto 0);                            
   ahbmo.HBURST  <= HBURST;
   ahbmo.HBUSREQ <= HBUSREQ;
   ahbmo.HLOCK   <= HLOCK;
   ahbmo.HPROT   <= HPROT;
   ahbmo.HSIZE   <= HSIZE;
   ahbmo.HTRANS  <= HTRANS;
   ahbmo.HWDATA  <= HWDATA;
   ahbmo.HWRITE  <= HWRITE;
   ahbmo.HIRQ    <= (others => '0');
      
end;
