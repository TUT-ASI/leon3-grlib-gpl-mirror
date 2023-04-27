------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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
-- Entity:      btb
-- File:        btb.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
--              Alen Bardizbanyan, Cobham Gaisler AB
-- Description: Branch target buffer
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.stdlib.all;
use grlib.config_types.all;
use grlib.config.all;

library gaisler;
use gaisler.leon5int.all;

entity btb is
  generic (
    nentries : integer range 8 to 128   -- Number of Entries
    );
  port (
    clk         : in  std_ulogic;
    rstn        : in  std_ulogic;
    btb_flush   : in  std_ulogic;
    btb_wen     : in  std_logic;
    btb_instpc  : in  std_logic_vector(31 downto 0);
    btb_indata  : in  std_logic_vector(31 downto 0);
    btb_pcread  : in  std_logic_vector(31 downto 0);
    btb_hit     : out std_logic;
    btb_outdata : out std_logic_vector(31 downto 0);
    diag_in     : in  l5_btb_diag_in_type;
    diag_out    : out l5_btb_diag_out_type
    );
end btb;

architecture rtl of btb is

  ----------------------------------------------------------------------------
  -- Functions
  ----------------------------------------------------------------------------

  ----------------------------------------------------------------------------
  -- Constants
  ----------------------------------------------------------------------------

  constant BTBTAG_HIGH : integer := 31;  -- TODO: Change with 39-bit addressing
  constant BTBTAG_LOW  : integer := 3+log2ext(NENTRIES);

  ----------------------------------------------------------------------------
  -- Types
  ----------------------------------------------------------------------------

  subtype data is std_logic_vector(31 downto 0);
  type    btbdata is array (0 to NENTRIES-1) of data;
  subtype tag is std_logic_vector(BTBTAG_HIGH-BTBTAG_LOW downto 0);
  type    btbtag is array (0 to NENTRIES-1) of tag;

  type reg_type is record
    valid     : std_logic_vector(NENTRIES-1 downto 0);
    datatable : btbdata;
    tagtable  : btbtag;
  end record;

  signal r, rin : reg_type;

begin  -- rtl

  comb : process(r, btb_wen, btb_instpc, btb_indata, btb_pcread, btb_flush, diag_in, rstn)
    variable v           : reg_type;
    variable windex      : std_logic_vector(log2ext(NENTRIES)-1 downto 0);
    variable rindex      : std_logic_vector(log2ext(NENTRIES)-1 downto 0);
    variable rtag        : std_logic_vector(31-BTBTAG_LOW+2 downto 0);
    variable btag        : std_logic_vector(31-BTBTAG_LOW+2 downto 0);
    variable hit         : std_ulogic;
    variable diag_rdatav : std_logic_vector(31 downto 0);
  begin

    v := r;

    windex := btb_instpc(log2ext(NENTRIES)+2 downto 3);
    rindex := btb_pcread(log2ext(NENTRIES)+2 downto 3);

    if btb_wen = '1' then
      v.datatable(to_integer(unsigned(windex))) := btb_indata;
      v.tagtable(to_integer(unsigned(windex)))  := btb_instpc(31 downto BTBTAG_LOW);
      v.valid(to_integer(unsigned(windex)))     := '1';
    end if;

    if notx(rindex) then
      btag := r.tagtable(to_integer(unsigned(rindex)))&r.valid(to_integer(unsigned(rindex)))&'0';
    else
      setx(btag);
    end if;
    rtag := btb_pcread(31 downto BTBTAG_LOW)&'1'&btb_pcread(2);

    hit := '0';
    if btag = rtag then
      hit := '1';
    end if;

    if btb_flush = '1' then
      v.valid := (others => '0');
    end if;


    --Diagnostic--
    diag_rdatav := (others => '0');
    if diag_in.en = '1' then
      diag_rdatav(31 downto BTBTAG_LOW) := r.tagtable(to_integer(unsigned(diag_in.addr(log2ext(NENTRIES)-1 downto 0))));
      diag_rdatav(0)                    := r.valid(to_integer(unsigned(diag_in.addr(log2ext(NENTRIES)-1 downto 0))));
      if diag_in.addr(8) = '1' then
        diag_rdatav := r.datatable((to_integer(unsigned(diag_in.addr(log2ext(NENTRIES)-1 downto 0)))));
      end if;
      if diag_in.wren = '1' then
        if diag_in.addr(8) = '0' then
          v.tagtable(to_integer(unsigned(diag_in.addr(log2ext(NENTRIES)-1 downto 0)))) := diag_in.wrdata(31 downto BTBTAG_LOW);
          v.valid(to_integer(unsigned(diag_in.addr(log2ext(NENTRIES)-1 downto 0))))    := diag_in.wrdata(0);
        else
          v.datatable(to_integer(unsigned(diag_in.addr(log2ext(NENTRIES)-1 downto 0)))) := diag_in.wrdata(31 downto 2)&"00";
        end if;
      end if;
    end if;
    -------------

    -- Reset
    if rstn = '0' then
      v.valid := (others => '0');
    end if;

    rin <= v;

    diag_out.rdata <= diag_rdatav;
    btb_hit <= hit;
    if notx(rindex) then
      btb_outdata <= r.datatable(to_integer(unsigned(rindex)));
    else
      btb_outdata <= (others => '0');
--pragma translate_off
      btb_outdata <= (others => 'X');
--pragma translate_on
    end if;

  end process;

  seq : process(clk, rstn)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;

  end process;

end rtl;
