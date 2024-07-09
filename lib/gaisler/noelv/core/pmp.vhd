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
-- Entity:      pmp
-- File:        pmp.vhd
-- Author:      Cobham Gaisler AB
-- Description: 
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.riscv.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.noelvint.all;
use gaisler.mmucacheconfig.csrtype;
use gaisler.utilnv.get_lo;

entity pmp is
  generic (
    pmp_check    : integer range 0  to 1   := 1;        -- Actually do PMP check?
    pmp_no_tor   : integer range 0  to 1   := 1;        -- Disable PMP TOR
    pmp_entries  : integer range 0  to 16  := 16;       -- Implemented PMP registers
    pmp_g        : integer range 0  to 10  := 1;        -- PMP grain is 2^(pmp_g + 2) bytes
    pmp_msb      : integer range 15 to 55  := 31        -- High bit for PMP checks
  );
  port (
    clk300p     : in  std_ulogic;       -- clk
    rstn        : in  std_ulogic;       -- active low reset

    -- PMP check
    address     : in  std_logic_vector(pmp_msb downto 0);
    size        : in  std_logic_vector(1 downto 0);
    acc         : in  std_logic_vector(1 downto 0);
    prv         : in  std_logic_vector(1 downto 0);
    valid       : in  std_logic;
    ok          : out std_logic := '0';

    -- PMP setup
    csr_address : in  std_logic_vector(11 downto 0);
    wen         : in  std_logic;
    wdata       : in  word64;
    ren         : in  std_logic;
    rdata       : out word64 := (others => '0')
  );  
end;

architecture rtl of pmp is
  function pmpcfg(csr : csr_reg_type; n : integer) return std_logic_vector is
    variable cfg : std_logic_vector(7 downto 0);
  begin
    if n < 8 then
      cfg := csr.pmpcfg0(n * 8 + 7 downto n * 8);
    else
      cfg := csr.pmpcfg2((n - 8) * 8 + 7 downto (n - 8) * 8);
    end if;

    return cfg;
  end function;

  function pmp_locked(csr : csr_reg_type; n : integer) return std_logic is
  begin
    if n >= pmp_entries then
      return '1';
    end if;

    return pmpcfg(csr, n)(7);
  end function;

  -- CSR Read
  procedure csr_read(csr_file  : in  csr_reg_type;
                     csra_in   : in  csratype;
                     csrv_in   : in  std_ulogic;
                     data_out  : out word64) is
    variable csr        : word64 := zerow64;
    constant csra_high  : csratype := csra_in(csra_in'high downto 4) & "0000";
    constant csra_low   : unsigned(3 downto 0) := unsigned(csra_in(3 downto 0));
  begin
    if csrv_in = '1' then
      case csra_in is
        --  Machine Trap Setup
        when CSR_MSTATUS        => csr := to_mstatus(csr_file.mstatus);
        -- Machine Protection and Translation
        when CSR_PMPCFG0        => csr := csr_file.pmpcfg0;
        when CSR_PMPCFG2        => csr := csr_file.pmpcfg2;
        when others =>
          case csra_high is
            -- According to the RISC-V documentation, the value read back from
            -- CSR_PMPADDR<x> will depend on pmpcfg<x> setting under some circumstances.
            when CSR_PMPADDR0 =>
              if csra_low < pmp_entries then
                csr := zerow64(XLEN - 1 downto pmp_msb - 2 + 1) &
                       csr_file.pmpaddr(to_integer(csra_low))(pmp_msb - 2 downto 0);
                if pmpcfg(csr_file, to_integer(csra_low))(4) = '1' then  -- NA4/NAPOT
                  csr(pmp_g - 2 downto 0) := (others => '1');
                else                                                     -- OFF/TOR
                  csr(pmp_g - 1 downto 0) := (others => '0');
                end if;
              end if;
            when others =>
          end case;
      end case;
    end if;

    data_out := csr;
  end procedure;

  procedure csr_write(csr_file  : in  csr_reg_type;
                      csra_in   : in  csratype;
                      wcsr_in   : in  word64;
                      csrv_in   : in  std_ulogic;
                      csr_out   : out csr_reg_type) is
    variable csr        : csr_reg_type;
    variable mstatus    : csr_status_type;
    variable flush      : std_ulogic;
    variable a          : pmpcfg_access_type;
    variable mask       : std_logic_vector(csr.pmplow(0)'high + 2 downto 0);
    constant csra_high  : csratype := csra_in(csra_in'high downto 4) & "0000";
    constant csra_low   : unsigned(3 downto 0) := unsigned(csra_in(3 downto 0));
  begin

    csr         := csr_file;
    flush       := '0';

    -- Pre-calculation should be fine.
    -- Can only be set in machine mode. For instruction fetch it is
    -- then either not used, or it will not be used until locked.
    -- The lock write must flush the pipeline.
    -- When MPRV/MPP is being used to force load/store as S/U mode,
    -- changes to those (and indeed PMPADDR/PMPCFG) must be in effect
    -- before a following load/store. When the MMU is enabled, changes
    -- to PMPADDR/PMPCFG may require an sfence.vma to be visible. But
    -- even then, changes to MPRV/MPP must take effect "immediately".

    for i in 0 to pmp_entries - 1 loop
      a(i) := pmpcfg(csr, i)(4 downto 3);

      -- Concatenate PMP type for mask creation. It contains a zero for
      -- TOR/NA4 and thus the used mask will then equal the input.
      -- For NAPOT it is 11, and thus the addition will propagate up to
      -- the marker zero. Which will be set and everything below cleared.
      -- and thus will work in the mask calculation.
      mask             := csr.pmpaddr(i) & a(i);
      -- Make sure pmp_g aligns the mask properly. Low bits should not matter!
      mask(pmp_g - 2 + 2 downto 2) := (others => '1');
      mask             := mask + 1;
      csr.pmplow(i)    := csr.pmpaddr(i) and mask(mask'high downto 2);
      if pmp_no_tor = 1 then
        -- No actual TOR support, so provide mask (high bits set) instead.
        csr.pmphigh(i) := not (csr.pmpaddr(i) xor mask(mask'high downto 2));
        -- Make sure pmp_g clears the mask properly. Low bits should not matter!
        csr.pmphigh(i)(pmp_g - 2 downto 0) := (others => '0');
      else
        csr.pmphigh(i) := csr.pmpaddr(i) or mask(mask'high downto 2);

        if a(i) = PMP_TOR then
          -- Bottom address for PMP_TOR.
          csr.pmplow(i)   := pmpaddrzero;
          if i /= 0 then
            csr.pmplow(i) := csr.pmpaddr(i - 1);
          end if;
          -- Make sure pmp_g aligns low/high properly. Low bits should not matter!
          csr.pmplow(i)(pmp_g - 1 downto 0)  := (others => '0');
          csr.pmphigh(i)(pmp_g - 1 downto 0) := (others => '0');
          -- Compensate so that we can use the same comparator.
          csr.pmphigh(i) := csr.pmpaddr(i) - 1;
        end if;
      end if;
    end loop;

    if csrv_in = '1' then
      case csra_in is
        -- Machine Trap Setup
        when CSR_MSTATUS        =>
          mstatus               := to_mstatus(wcsr_in);
          mstatus.fs            := "00";
          mstatus.uie           := '0';
          mstatus.upie          := '0';
          csr.mstatus           := mstatus;
        -- Machine Protection and Translation
        when CSR_PMPCFG0        =>
          -- Should flush pipeline if (at least new) lock bit is set, since that
          -- should "take" immediately and might invalidate instruction fetches.
          for i in 0 to 7 loop
            if pmp_locked(csr, i) = '0' then
              csr.pmpcfg0(i * 8 + 7 downto i * 8)       := wcsr_in(i * 8 + 7 downto i * 8);
              if pmp_g > 0 then
                -- NA4 not possible!
                if pmpcfg(csr, i)(4 downto 3) = "10" then
                  csr.pmpcfg0(i * 8 + 4) := '0';           -- Clear to OFF
                end if;
              end if;
              if pmp_no_tor = 1 then
                -- TOR not possible!
                if pmpcfg(csr, i)(4 downto 3) = "01" then
                  csr.pmpcfg0(i * 8 + 3) := '0';           -- Clear to OFF
                end if;
              end if;
              flush := flush or pmp_locked(csr, i);
            end if;
          end loop;
        when CSR_PMPCFG2        =>
          for i in 0 to 7 loop
            if pmp_locked(csr, i + 8) = '0' then
              csr.pmpcfg2(i * 8 + 7 downto i * 8)       := wcsr_in(i * 8 + 7 downto i * 8);
              if pmp_g > 0 then
                -- NA4 not possible!
                if pmpcfg(csr, i + 8)(4 downto 3) = "10" then
                  csr.pmpcfg2(i * 8 + 4) := '0';           -- Clear to OFF
                end if;
              end if;
              if pmp_no_tor = 1 then
                -- TOR not possible!
                if pmpcfg(csr, i + 8)(4 downto 3) = "01" then
                  csr.pmpcfg2(i * 8 + 3) := '0';           -- Clear to OFF
                end if;
              end if;
              flush := flush or pmp_locked(csr, i + 8);
            end if;
          end loop;
          csr.dfeaturesen.dualen        := wcsr_in(0);
        when others =>
          case csra_high is
            when CSR_PMPADDR0   =>
              if pmp_locked(csr, to_integer(csra_low)) = '0' then
                csr.pmpaddr(to_integer(csra_low)) := get_lo(wcsr_in, csr.pmpaddr(0));
                csr.pmpaddr(to_integer(csra_low))(csr.pmpaddr(0)'high downto pmp_msb - 2 + 1) :=
                                                      (others => '0');
              end if;
            when others =>
          end case;
      end case;
    end if;

    csr_out := csr;
  end procedure;


  signal csr : csr_reg_type := CSRRES;

begin

  process (clk300p)
    variable wb_csr : csr_reg_type;
    variable ra_csr : word64;
    variable xc     : std_logic;
    variable cause  : word64;
    variable tval   : word64;
  begin
    if rising_edge(clk300p) then
      csr_write(csr,                -- in  : CSR File In
                csr_address,        -- in  : CSR Register Address
                wdata,              -- in  : Write Data
                wen,                -- in  : Valid/Write Enable In
                wb_csr);            -- out : CSR Regfile Out

      csr_read(csr,                 -- in  : CSR File
               csr_address,         -- in  : CSR Register Address
               ren,                 -- in  : Valid/Read enable
               ra_csr);             -- out : CSR Register Value

      if pmp_check = 1 then
        pmp_unit(prv, csr.pmplow, csr.pmphigh, csr.pmpcfg0, csr.pmpcfg2,
                 csr.mstatus.mprv, csr.mstatus.mpp,
                 address, address, size, acc, valid,
                 xc, cause, tval,
                 pmp_entries, pmp_no_tor, pmp_g, pmp_msb);
      end if;

      csr   <= wb_csr;
      ok    <= not xc;
      rdata <= ra_csr;

      if rstn = '0' then
        csr   <= CSRRES;
        ok    <= '0';
        rdata <= (others => '0');
      end if;
    end if;
  end process;

end rtl;


