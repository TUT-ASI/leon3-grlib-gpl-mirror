------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-- Entity:      bht_pap
-- File:        bht_pap.vhd
-- Author:      Andrea Merlo, Cobham Gaisler AB
--              Alen Bardizbanyan, Cobham Gaisler AB
-- Description  Two level adaptive predictor (PAp)
--              (per entry branch history, per entry history table)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library techmap;
use techmap.gencomp.all;
use techmap.allmem.all;

library grlib;
use grlib.stdlib.all;
use grlib.config_types.all;
use grlib.config.all;

library gaisler;
use gaisler.leon5int.all;

entity bht_pap is
  generic (
    tech     : integer;
    nentries : integer range 32 to 1024;  -- Number of Entries
    hlength  : integer range 2 to 4;      -- History Length
    testen   : integer
    );
  port (
    clk      : in  std_logic;
    rstn     : in  std_logic;
    holdn    : in  std_logic;
    bhti     : in  l5_bht_in_type;
    bhto     : out l5_bht_out_type;
    diag_in     : in  l5_btb_diag_in_type;
    diag_out    : out l5_btb_diag_out_type;
    testin   : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
    );
end bht_pap;

architecture rtl of bht_pap is

  -- Total number of bits
  -- nentries*(hlength+2) + (2**hlength)*2

  ----------------------------------------------------------------------------
  -- Constants
  ----------------------------------------------------------------------------
  constant BHTINMSB  : integer := log2ext(nentries) + 3 - 1;
  constant RESET_ALL : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

  ----------------------------------------------------------------------------
  -- Types
  ----------------------------------------------------------------------------

  subtype bhtentry is std_logic_vector(hlength-1 downto 0);
  type    bht is array (0 to nentries-1) of bhtentry;
  subtype phtcounter is std_logic_vector((2**hlength)*2-1 downto 0);
  type    pht is array (0 to nentries-1) of phtcounter;

  type reg_type is record
    bhttable         : bht;
    btb_taken        : std_logic_vector(nentries-1 downto 0);
    valid            : std_logic_vector(nentries-1 downto 0);
    ren              : std_logic;
    rindex_reg       : std_logic_vector(log2ext(nentries)-1 downto 0);
    rindex_bhist_reg : std_logic_vector(log2ext(nentries)-1 downto 0);
    pht_rdata_hold   : std_logic_vector((2**hlength)*2-1 downto 0);
    write_forwarded  : std_logic;
  end record;

  constant RES : reg_type := (
    bhttable         => (others => (others => '0')),
    btb_taken        => (others => '0'),
    valid            => (others => '0'),
    ren              => '0',
    rindex_reg       => (others => '0'),
    rindex_bhist_reg => (others => '0'),
    pht_rdata_hold   => (others => '0'),
    write_forwarded  => '0'
    );

  signal r, rin : reg_type;

  signal pht_re, pht_we       : std_logic;
  signal pht_raddr, pht_waddr : std_logic_vector(log2ext(nentries)-1 downto 0);
  signal pht_rdata, pht_wdata : std_logic_vector((2**hlength)*2-1 downto 0);
  
begin  -- rtl

  phtable : syncram_2p generic map (tech, log2ext(nentries), (2**hlength)*2, 0, 0, testen, 0, memtest_vlen)
    port map (clk, pht_re, pht_raddr, pht_rdata, clk, pht_we, pht_waddr, pht_wdata, testin
               );   

  comb : process(r, bhti, rstn, pht_rdata, holdn, diag_in)
    variable v                      : reg_type;
    variable rindex_comb            : std_logic_vector(log2ext(nentries)-1 downto 0);
    variable windex                 : std_logic_vector(log2ext(nentries)-1 downto 0);
    variable bhistory               : std_logic_vector(hlength-1 downto 0);
    variable phistory               : std_logic_vector((2**hlength)*2-1 downto 0);
    variable phistory0              : std_logic_vector(2**hlength-1 downto 0);
    variable phistory1              : std_logic_vector(2**hlength-1 downto 0);
    variable bwhistory              : std_logic_vector(hlength-1 downto 0);
    variable pht0                   : std_logic_vector(MAX_PREDICTOR_BITS-1 downto 0);
    variable wdata                  : std_logic_vector(1 downto 0);
    variable taken                  : std_logic;
    variable btb_taken              : std_logic;
    variable bhto_bhistory          : std_logic_vector(4 downto 0);
    variable bhto_phistory          : std_logic_vector(31 downto 0);
    variable bhti_phistory_temp     : std_logic_vector((2**hlength)*2-1 downto 0);
    variable bhti_wdata             : std_logic_vector(1 downto 0);
    variable bhistory_new           : std_logic_vector(hlength-1 downto 0);
    variable pht_rev, pht_wev       : std_logic;
    variable pht_raddrv, pht_waddrv : std_logic_vector(log2ext(nentries)-1 downto 0);
    variable pht_wdatav             : std_logic_vector((2**hlength)*2-1 downto 0);
    variable pht_rdatav             : std_logic_vector((2**hlength)*2-1 downto 0);
    variable r_valid                : std_logic;
    variable diag_bht_out           : std_logic_vector(31 downto 0);
    variable diag_out_rdata         : std_logic_vector(31 downto 0);
  begin

    v := r;

    -- Sample input signals
    rindex_comb := bhti.raddr_comb(BHTINMSB downto 3);
    windex      := bhti.waddr(BHTINMSB downto 3);

    if diag_in.en = '1' then
      windex := diag_in.addr(log2ext(nentries)-1 downto 0);
    end if;

    pht_rdatav := r.pht_rdata_hold;
    v.ren      := '0';
    if holdn = '1' and bhti.ren = '1' then
      v.ren        := '1';
      v.rindex_reg := rindex_comb;
      v.write_forwarded := '0';
    end if;
    if bhti.iustall = '0' and holdn = '1' then
      v.rindex_bhist_reg := bhti.rindex_bhist(BHTINMSB downto 3);
    end if;
    ---------------------------------------------------------------------------
    --diagnostic
    if diag_in.en = '1' then
      v.rindex_bhist_reg := diag_in.addr(BHTINMSB-3 downto 0);
    end if;
    ---------------------------------------------------------------------------
    if r.ren = '1' and r.write_forwarded = '0' then
      pht_rdatav := pht_rdata;
      if notx(r.rindex_reg) then
        if r.valid(to_integer(unsigned(r.rindex_reg))) = '0' then
          pht_rdatav := (others => '0');
        end if;
      else
        setx(pht_rdatav);
      end if;
      v.pht_rdata_hold := pht_rdatav;
    end if;
    --diagnostic
    if diag_in.en = '1' then
      v.rindex_reg := diag_in.addr(BHTINMSB-3 downto 0);
    end if;
    --
    pht_raddrv := rindex_comb;
    pht_rev    := v.ren;
    --diagnostic
    if diag_in.en = '1' and diag_in.wren = '0' then
      pht_rev := '1';
    end if;
    if diag_in.en = '1' then
      pht_raddrv := r.rindex_reg;
    end if;
    --
    
    bhti_wdata := bhti.phistory(1 downto 0);
    if notx(bhti.bhistory) then
      for i in 0 to 2**hlength-1 loop
        if i = unsigned(bhti.bhistory(hlength-1 downto 0)) then
          bhti_wdata := bhti.phistory(i*2+1 downto i*2);
        end if;
      end loop;
    else
      setx(bhti_wdata);
    end if;

    if bhti.taken = '1' then
      case bhti_wdata is
        when "00"   => wdata := "01";
        when "01"   => wdata := "10";
        when "10"   => wdata := "11";
        when others => wdata := "11";
      end case;
    else
      case bhti_wdata is
        when "01"   => wdata := "00";
        when "10"   => wdata := "01";
        when "11"   => wdata := "10";
        when others => wdata := "00";
      end case;
    end if;

    if notx(r.rindex_bhist_reg) then
      r_valid :=  r.valid(to_integer(unsigned(r.rindex_bhist_reg)));
    else
      setx(r_valid);
    end if;
    --diag
    diag_bht_out := (others=>'0');
    diag_bht_out(0) := r_valid;
    --
    if notx(r.rindex_bhist_reg) then
      bhistory := r.bhttable(conv_integer(r.rindex_bhist_reg));
      --diag
      diag_bht_out(31 downto 31-hlength+1) := bhistory;
      --
      if r_valid = '0' then
        bhistory := (others => '0');
      end if;
    else
      setx(bhistory);
    end if;
    phistory := pht_rdatav;

    for i in 0 to 2**hlength-1 loop
      phistory1(i) := phistory((i*2)+1);
      phistory0(i) := phistory(i*2);
    end loop;

    pht0(1) := phistory1(conv_integer(bhistory));
    pht0(0) := phistory0(conv_integer(bhistory));

    taken := pht0(1);

    bhti_phistory_temp := bhti.phistory((2**hlength)*2-1 downto 0);

    pht_wev      := '0';
    pht_waddrv   := windex;
    if bhti.wen = '1'then
      pht_wev   := '1';
      bwhistory := bhti.bhistory(hlength-1 downto 0);
      for i in 0 to 2**hlength-1 loop
        if i = unsigned(bwhistory) then
          bhti_phistory_temp(i*2+1 downto i*2) := wdata;
        end if;
      end loop;
      v.valid(to_integer(unsigned(pht_waddrv))) := '1';

      if pht_waddrv = r.rindex_reg then
        --write forwarding
        v.pht_rdata_hold := bhti_phistory_temp;
      end if;

      v.write_forwarded := '0';
      if pht_waddrv = pht_raddrv then
        v.write_forwarded := '1';
        v.pht_rdata_hold := bhti_phistory_temp;
      end if;
      
    end if;

    --diag
    if diag_in.en = '1' and diag_in.wren = '1' and diag_in.addr(11) = '0' then
      v.valid(to_integer(unsigned(pht_waddrv))) := diag_in.wrdata(0);
    end if;
    --

    
    pht_wdatav := bhti_phistory_temp;
    --diag
    if diag_in.en = '1' and diag_in.wren = '1' and diag_in.addr(11) = '1' then
      pht_wev := '1';
      pht_wdatav :=  diag_in.wrdata(31 mod (2**hlength*2) downto 0);
    end if;
    --
    
    bhistory_new := bhti.bhistory(hlength-1 downto 0);
    if bhti.wen = '1' then
      v.bhttable(conv_integer(windex))(hlength-1)          := bhti.taken;
      v.bhttable(conv_integer(windex))(hlength-2 downto 0) := bhti.bhistory(hlength-1 downto 1);

      bhistory_new := bhti.taken & bhti.bhistory(hlength-1 downto 1);

      --update btb taken for the upcoming history
      --for "0000" and "1111" the next history might correspond to an updated value
      --on this cycle hence use the updated phistory
      for i in 0 to 2**hlength-1 loop
        if i = unsigned(bhistory_new) then
          v.btb_taken(conv_integer(windex)) := bhti_phistory_temp(i*2+1);
        end if;
      end loop;
      
    end if;

    --diag
    if diag_in.en = '1' and diag_in.wren = '1' and diag_in.addr(11) = '0' then
       v.btb_taken(conv_integer(windex)) := diag_in.wrdata(1);
       v.bhttable(conv_integer(windex)) := diag_in.wrdata(31 downto 31-hlength+1);
    end if;
    --

    btb_taken     := r.btb_taken(conv_integer(r.rindex_bhist_reg));
    bhto_bhistory := (others => '0');
    bhto_phistory := (others => '0');

    bhto_bhistory(hlength-1 downto 0)        := bhistory;
    bhto_phistory((2**hlength)*2-1 downto 0) := phistory;

    --diag
    diag_bht_out(1) := btb_taken;
    diag_out_rdata  := diag_bht_out;
    if diag_in.addr(11) = '1' then
      --pht table
      diag_out_rdata := (others=>'0');
      diag_out_rdata(31 mod (2**hlength)*2 downto 0) := pht_rdata(31 mod (2**hlength)*2 downto 0);
    end if;
    diag_out.rdata <= diag_out_rdata;
    --
    --SRAM control
    pht_re    <= pht_rev;
    pht_we    <= pht_wev;
    pht_raddr <= pht_raddrv;
    pht_waddr <= pht_waddrv;
    pht_wdata <= pht_wdatav;

    -- Output Signals
    bhto.taken     <= btb_taken;
    bhto.rdata     <= pht0;
    bhto.btb_taken <= btb_taken;
    bhto.phistory  <= bhto_phistory;
    bhto.bhistory  <= bhto_bhistory;

    if bhti.flush = '1' then
      v.valid := (others => '0');
    end if;

    rin <= v;

  end process;

  seq : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if rstn = '0' then
        r.btb_taken       <= (others => '0');
        r.valid           <= (others => '0');
        r.ren             <= '0';
        r.write_forwarded <= '0';
      end if;
    end if;
  end process;

end rtl;
