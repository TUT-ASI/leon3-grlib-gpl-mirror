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
-- Package: 	cpu_disas
-- File:	cpu_disas.vhd
-- Author:	Andrea Merlo, Gaisler Research AB
-- Description:	RISC-V disassembler according to:

--              RISC-V Instruction Set Manual Volume I: User-Level ISA 2.3 (WIP)
--              RISC-V Instruction Set Manual Volume II: Privileged
--              Architecture 1.11 (WIP)
------------------------------------------------------------------------------

-- pragma translate_off

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.all;
use grlib.riscv.all;
use grlib.riscv_disas.all;

entity cpu_disas is
generic (
  disasg : in integer range 0 to 3 := 1
  );
port (
  clk           : in  std_ulogic;
  rstn          : in  std_ulogic;
  dummy         : out std_ulogic;
  index         : in  std_logic_vector(3 downto 0);     -- Hart Index
  way           : in  std_logic_vector(2 downto 0);     -- Way Index
  ivalid        : in  std_ulogic;                       -- Valid Instruction
  inst          : in  std_logic_vector(31 downto 0);    -- Instruction
  cinst         : in  std_logic_vector(15 downto 0);    -- Copressed Instruction
  comp          : in  std_ulogic;                       -- Compressed Flag
  pc            : in  std_logic_vector;                 -- PC
  wregen        : in  std_ulogic;                       -- Regfile Write Enable
  wregdata      : in  std_logic_vector;                 -- Regfile Write Data
  fsd           : in  std_ulogic;                       -- RV32 and fsd
  fsd_hi        : in  std_logic_vector;                 -- High half of fsd on RV32
  wregen_f      : in  std_ulogic;                       -- FPU Regfile Write Enable
  wcsren        : in  std_ulogic;                       -- CSR Write Enable
  wcsrdata      : in  std_logic_vector;                 -- CSR Write Data
  prv           : in  std_logic_vector(1 downto 0);     -- Privileged Level
  v             : in  std_ulogic;                       -- Virtualization mode
  trap          : in  std_ulogic;                       -- Exception
  trap_taken    : in  std_ulogic;
  cause         : in  std_logic_vector;                 -- Exception Cause
  tval          : in  std_logic_vector;                 -- Exception Value
  cycle         : in  std_logic_vector(63 downto 0);    -- Cycle Counter
  instret       : in  std_logic_vector(63 downto 0);    -- Inst Committed
  dual          : in  std_logic_vector(63 downto 0);    -- Dual Instruction Counter
  disas         : in  std_ulogic);                      -- Disassembly Enabled
end;

architecture behav of cpu_disas is

  signal clk_counter    : integer := 0;

begin

  dummy <= '1';

  trc : process(clk)
    variable rd         : gpr_type;
    variable csr        : csratype;
    variable iindex     : integer;
    variable iway       : integer;
  begin
    iindex      := conv_integer(index);
    iway        := conv_integer(way);
    csr         := (others => '0');

    rd          := inst(11 downto 7);

    if (wcsren and ivalid) = '1' then
      csr       := inst(31 downto 20);
    end if;

    if disasg = 1 then
      if rising_edge(clk) and (rstn = '1') then
        print_insn(
          iindex,                 -- Hart Index
          iway,                   -- Way Index
          conv_integer(cycle),    -- Clock Cycles
          conv_integer(instret),  -- Instruction Committed
          conv_integer(dual),     -- Dual Issued Instruction Counter
          ivalid,                 -- Valid Instruction
          pc,                     -- Program Counter
          rd,                     -- Destination Register
          csr,                    -- CSR Register
          wregdata,               -- Regfile Write Data
          fsd,                    -- RV32 and fsd?
          fsd_hi,                 -- High half of fsd on RV32
          wregen,                 -- Regfile Write Enable
          wregen_f,               -- FPU Regfile Write Enable
          wcsrdata,               -- CSR Write Data
          wcsren,                 -- CSR Write Enable
          inst,                   -- Instruction
          cinst,                  -- Compressed Instruction
          comp,                   -- Compressed Flag
          prv,                    -- Privileged Level
          trap,                   -- Exception
          cause,                  -- Exception Cuase
          tval                    -- Exception Value
          );

        clk_counter <= clk_counter + 1;

      end if;
    end if;

    if disasg = 2 then
      if rising_edge(clk) and (rstn = '1') then
        print_spike_special(
          valid => ivalid,
          pc => pc,
          csr => csr,
          wrdata => wregdata,
          fsd => fsd,
          fsd_hi => fsd_hi,
          wren => wregen,
          wren_f => wregen_f,
          wcen => wcsren,
          wcdata => wcsrdata,
          inst => inst,
          cinst => cinst,
          comp => comp,
          prv => prv,
          trap => trap,
          trap_taken => trap_taken,
          cause => cause,
          tval => tval);
      end if;
    end if;

    if disasg = 3 then
      if rising_edge(clk) and (rstn = '1') then
        if disas = '1' then
          print_insn3(
            hndx    => iindex,                 -- Hart Index
            way     => iway,                   -- Way Index
            cycle   => conv_integer(cycle),    -- Clock Cycles
            instret => conv_integer(instret),  -- Instruction Committed
            cdual   => conv_integer(dual),     -- Dual Issued Instruction Counter
            valid   => ivalid,                 -- Valid Instruction
            pc      => pc,                     -- Program Counter
            rd      => rd,                     -- Destination Register
            csr     => csr,                    -- CSR Register
            wrdata  => wregdata,               -- Regfile Write Data
            fsd     => fsd,                    -- RV32 and fsd?
            fsd_hi  => fsd_hi,                 -- High half of fsd on RV32
            wren    => wregen,                 -- Regfile Write Enable
            wren_f  => wregen_f,               -- FPU Regfile Write Enable
            wcdata  => wcsrdata,               -- CSR Write Data
            wcen    => wcsren,                 -- CSR Write Enable
            inst    => inst,                   -- Instruction
            cinst   => cinst,                  -- Compressed Instruction
            comp    => comp,                   -- Compressed Flag
            prv     => prv,                    -- Privileged Level
            v       => v,                      -- Virtualization mode
            trap    => trap,                   -- Exception
            cause   => cause,                  -- Exception Cuase
            tval    => tval                    -- Exception Value
          );
        end if;
      end if;
    end if;

  end process;

end;

-- pragma translate_on
