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
-- Entity:      imsic
-- File:        imsic.vhd
-- Author:      Francisco Bas, Cobham Gaisler AB
-- Description: IMSIC interrupt file 
--
--              It implements an interrupt file register and the indirectly 
--              accessed interrupt-file registers interface described in the
--              AIA specs. The register seteipnum is modified by AHB 32-bit 
--              writes whose interface is implemented in the layer above.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library gaisler;
use gaisler.noelv.xlen;

library grlib;
use grlib.stdlib.log2x;

entity interrupt_file is
  generic (
    sources     : integer range 0 to 2047   := 2047; -- It must be a multiple of 64 -1: from 63 to 2047 
    plic        : integer range 0 to 1      := 1 
    );
  port (
    rst         : in  std_ulogic;
    clk         : in  std_ulogic;
    -- AHB interface
    ahbw        : in  std_ulogic;
    seteipnum   : in  std_logic_vector(31 downto 0);
    -- Interface with CSRs
    ireg_w      : in  std_ulogic;
    iselect     : in  std_logic_vector(XLEN-1 downto 0);
    iregi       : in  std_logic_vector(XLEN-1 downto 0);
    irego       : out std_logic_vector(XLEN-1 downto 0);
    topei_w     : in  std_ulogic;
    topei       : out std_logic_vector(XLEN-1 downto 0);
    plic_eip    : in  std_ulogic;
    eipo        : out std_ulogic
    );
end;

architecture rtl of interrupt_file is

  constant zerox : std_logic_vector(XLEN-1 downto 0) := (others => '0');

  constant SOURCEREGS : integer := (sources+1)/XLEN; 
  type interrupt_registers is array (0 to SOURCEREGS-1) of std_logic_vector(XLEN-1 downto 0); 
  constant srcbits : integer := log2x(sources+1);


  function eidelivery_res(XLEN : integer) return std_logic_vector is
    variable eidelivery : std_logic_vector(XLEN-1 downto 0) := (others => '0'); 
  begin
    -- If there is no PLIC reset value is unespecified according to AIA specs
    eidelivery := (others => '0');
    if plic = 1 then
      eidelivery(31 downto 28) := x"4";
    end if;
    return eidelivery;
  end function;

  type reg_type is record
    -- Interrupt file registers
    eie         : interrupt_registers;
    eip         : interrupt_registers;
    eidelivery  : std_logic_vector(XLEN-1 downto 0); 
    eithreshold : std_logic_vector(XLEN-1 downto 0); 
    -- Outputs
    topei       : std_logic_vector(XLEN-1 downto 0);
    eipo        : std_ulogic;
  end record;


  constant RES_T : reg_type := (
    eie         => (others => (others => '0')),
    eip         => (others => (others => '0')),
    eidelivery  => eidelivery_res(XLEN),
    eithreshold => (others => '0'),
    topei       => (others => '0'),
    eipo        => '0'
    );

    signal r, rin : reg_type;

begin

  comb : process (r, seteipnum, ireg_w, iselect, iregi, topei_w, ahbw, plic_eip)
    variable v             : reg_type;
    variable topei_value   : std_logic_vector(10 downto 0);
    variable maxprior_pend : natural; 
    variable seteipnum_int : natural;
    variable iereg         : natural;
    variable iebit         : natural;
    variable offset        : std_logic_vector(7 downto 6);
    variable selreg        : natural;
    variable selreg64      : natural;
  begin

    v := r;

    v.topei := (others => '0');
    v.eipo  := '0';
    maxprior_pend := 0;


    -- It determines the biggest priority source (lower ID) 
    -- which is pending and enable 
    for i in sources downto 1 loop
      iereg := i/XLEN;
      iebit := i mod XLEN;
      if r.eie(iereg)(iebit) = '1' and r.eip(iereg)(iebit) = '1' then
        maxprior_pend := i;
      end if;
    end loop;

    -- The value of a *topei CSR (mtopei, stopei, or vstopei) indicates 
    -- the interrupt file’s current highest-priority pending-and-enabled 
    -- interrupt that also exceeds the priority threshold specified by its 
    -- eithreshold register
    if maxprior_pend < unsigned(r.eithreshold) or r.eithreshold = zerox then
        topei_value := std_logic_vector(to_unsigned(maxprior_pend, 11));
        v.topei := (others => '0');

        v.topei(26 downto 16) := topei_value;
        v.topei(10 downto 0) := topei_value; 
    end if;

    -- When interrupt delivery is disabled by an interrupt file’s eidelivery 
    -- register (eidelivery = 0), the interrupt signal from the interrupt file 
    -- is held de-asserted (false). When interrupt delivery from an interrupt 
    -- file is enabled (eidelivery = 1), its interrupt signal is asserted if and 
    -- only if the interrupt file has a pending-and-enabled interrupt that also 
    -- exceeds the priority threshold specified by eithreshold, if not zero.
    if r.topei /= zerox and r.eidelivery(0) = '1' then 
      v.eipo := '1';
    end if;

    -- when a *topei CSR is written, if the register value has interrupt 
    -- identity i in bits 26:16, then the interrupt file’s pending bit for 
    -- interrupt i is cleared.
    if topei_w = '1' then
      iereg := to_integer(unsigned(r.topei(26 downto 16)))/XLEN;
      iebit := to_integer(unsigned(r.topei(26 downto 16))) mod XLEN;
      v.eip(iereg)(iebit) := '0';
    end if;
      

    ------------------------------------------------------------------------------
    -- Indirectly accessed interrupt-file registers interface
    ------------------------------------------------------------------------------

    -- A value of the *iselect CSR (miselect, siselect, or vsiselect) in the 
    -- range 0x70–0xFF selects a register of the corresponding IMSIC interrupt

    -- Register numbers 0x71 and 0x73–0x7F are reserved. When a *iselect CSR has 
    -- one of these values, reads from the matching *ireg CSR (mireg, sireg, or 
    -- vsireg) return zero, and writes to the *ireg CSR are ignored.

    -- Register Map

    --  0x70   eidelivery
    --  0x72   eithreshold

    --  0x80   eip0
    --  0x81   eip1
    --  ...    ...
    --  0xBF   eip63

    --  0xC0   eie0
    --  0xC1   eie1
    --  ...    ...
    --  0xFF   eie63      

    irego   <= (others => '0');

    offset := iselect(offset'range);
    selreg := to_integer(unsigned(iselect(5 downto 0)));
    selreg64 := selreg/2;
    case offset is
      when "01" => -- eidelivery/eithreshold
        if iselect(5 downto 0) = "11" & x"0" then -- 0x70 eidelivery (WARL)
          irego <= r.eidelivery;
          if ireg_w = '1' then
            if iregi(31 downto 28) = x"4" then
              v.eidelivery := (others => '0');
              v.eidelivery(31 downto 28) := x"4";
            else
              v.eidelivery := (others => '0');
              v.eidelivery(0) := iregi(0);
            end if;
          end if;
        elsif iselect(5 downto 0) = "11" & x"2" then -- 0x72 eithreshold (WLRL) 
          irego <= r.eithreshold;
          if ireg_w = '1' then
            v.eithreshold(srcbits-1 downto 0) := iregi(srcbits-1 downto 0);
          end if;
        end if;
      when "10" => -- eip
        if XLEN = 64 then
          -- When the interrupt file’s registers are 64 bits, the odd-numbered 
          -- registers eip1, eip3, . . . eip63 do not exist.
          if selreg64 < v.eip'length then
            irego <= r.eip(selreg64);
            if ireg_w = '1' then
              v.eip(selreg64) := iregi;
            end if;
          end if;
        elsif XLEN =32 then
          if selreg < v.eip'length then
            irego <= r.eip(selreg);
            if ireg_w = '1' then
              v.eip(selreg) := iregi;
            end if;
          end if;
        end if;
        --if selreg = 0 or selreg64 = 0 then
        --  v.eip(0)(0) := '0'; -- Read-only zero bit
        --end if;
      when "11" => -- eie
        if XLEN = 64 then
          -- When the interrupt file’s registers are 64 bits, the odd-numbered 
          -- registers eie1, eie3, . . . eie63 do not exist.
          if selreg64 < v.eie'length then
            irego <= r.eie(selreg64);
            if ireg_w = '1' then
              v.eie(selreg64) := iregi;
            end if;
          end if;
        elsif XLEN =32 then
          if selreg < v.eie'length then
            irego <= r.eie(selreg);
            if ireg_w = '1' then
              v.eie(selreg) := iregi;
            end if;
          end if;
        end if;
      when others =>
    end case;
    v.eie(0)(0) := '0'; -- Read-only zero bit
    v.eip(0)(0) := '0'; -- Read-only zero bit


    -- AHB write
    seteipnum_int := to_integer(unsigned(seteipnum));
    if ahbw = '1' and seteipnum_int /= 0 then
      iereg := seteipnum_int/XLEN;
      iebit := seteipnum_int mod XLEN;
      v.eip(iereg)(iebit) := '1';
    end if;
    
    -- Outputs to the CPU
    -- If eidelivery is set to 0x40000000, the eip bit
    -- is forwarded from APLIC/PLIC
    if r.eidelivery(31 downto 28) = x"4" and plic = 1 then
      eipo  <= plic_eip;
    else
      eipo  <= v.eipo;
    end if;
    topei <= r.topei;


    rin <= v;

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

end;
