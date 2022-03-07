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
-- Entity: 	bhtnv
-- File:	bhtnv.vhd
-- Author:	Andrea Merlo, Cobham Gaisler AB
--              Alen Bardizbanyan, Cobham Gaisler AB
-- Description:	Branch History Table with configurable predictor
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
use gaisler.noelv.all;
use gaisler.noelvint.all;

entity bhtnv is
  generic (
    tech       : integer;
    nentries   : integer range 32 to 1024;  -- Number of Entries
    hlength    : integer range 2 to 10;     -- History Length
    predictor  : integer range 0 to 2;      -- Predictor
    ext_c      : integer range 0 to 1;      -- C Base Extension Set
    dissue     : integer range 0 to 1;      -- Dual issue
    testen     : integer
    );
  port (
    clk          : in  std_ulogic;
    rstn         : in  std_ulogic;
    holdn        : in  std_ulogic;
    bhti         : in  nv_bht_in_type;
    bhto         : out nv_bht_out_type;
    testin       : in std_logic_vector(TESTIN_WIDTH-1 downto 0)
    );
end bhtnv;

architecture rtl of bhtnv is

  ----------------------------------------------------------------------------
  -- Functions
  ----------------------------------------------------------------------------

  function phtgen (entries   : integer;
                   hlength   : integer;
                   predictor : integer) return integer is
    -- Non-constant
    variable ret : integer;
  begin

    ret         := entries;
    if predictor = 1 then
      ret       := 2 ** hlength;
    end if;

    return ret;
  end;

  function phtbit (hlength   : integer;
                   predictor : integer;
                   cbits     : integer) return integer is
    -- Non-constant
    variable ret : integer;
  begin

    ret         := cbits;
    if predictor = 2 then
      ret       := 2 ** hlength * cbits;
    end if;

    return ret;
  end;

  ----------------------------------------------------------------------------
  -- Constants
  ----------------------------------------------------------------------------

  constant OFFSET       : integer := 2 - ext_c * 1;
  constant BHTBITS      : integer := log2ext(nentries) + OFFSET;
  constant COUNTERBITS  : integer := 2;
  constant PHTENTRIES   : integer := phtgen(nentries, hlength, predictor);
  constant PHTBITS      : integer := phtbit(hlength, predictor, counterbits);

  --constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant RESET_ALL    : boolean := true;

  ----------------------------------------------------------------------------
  -- Types
  ----------------------------------------------------------------------------

  subtype bhthistory is std_logic_vector(HLENGTH - 1 downto 0);
  type    bht        is array (0 to NENTRIES - 1) of bhthistory;
  subtype phtcounter is std_logic_vector(PHTBITS - 1 downto 0);
  type    pht        is array (0 to PHTENTRIES - 1) of phtcounter;
  type    phto       is array (0 to 2 ** HLENGTH - 1) of std_logic_vector(COUNTERBITS - 1 downto 0);

  type reg_type is record
    taken            : std_logic_vector(nentries - 1 downto 0);
    valid            : std_logic_vector(nentries - 1 downto 0);
    bhttable         : bht;
    ren              : std_ulogic;
    rindex_reg       : std_logic_vector(log2ext(nentries) - 1 downto 0);
    rindex_bhist_reg : std_logic_vector(log2ext(nentries) - 1 downto 0);
    pht_rdata_hold   : std_logic_vector((2 ** hlength) * 2 - 1 downto 0);
    bhist_data_hold  : std_logic_vector(hlength - 1 downto 0);
    write_forwarded  : std_logic;
  end record;

  constant RES : reg_type := (
    taken            => (others => '0'),
    valid            => (others => '0'),
    bhttable         => (others => (others => '0')),
    ren              => '0',
    rindex_reg       => (others => '0'),
    rindex_bhist_reg => (others => '0'),
    pht_rdata_hold   => (others => '0'),
    bhist_data_hold  => (others => '0'),
    write_forwarded  => '0'
    );


  signal pht_re, pht_we       : std_logic;
  signal pht_raddr, pht_waddr : std_logic_vector(log2ext(nentries) - 1 downto 0);
  signal pht_rdata, pht_wdata : std_logic_vector((2 ** hlength) * 2 - 1 downto 0);

  signal r, rin : reg_type := RES;

begin  -- rtl

    phtable : syncram_2p generic map (tech, log2ext(nentries), (2 ** hlength) * 2, 0, 0, testen, 0, memtest_vlen)
    port map (clk, pht_re, pht_raddr, pht_rdata, clk, pht_we, pht_waddr, pht_wdata, testin
               );   

  comb : process(r, bhti, rstn, holdn, pht_rdata)
    variable v                     : reg_type;
    variable rindex                : std_logic_vector(BHTBITS - 1 downto OFFSET);
    variable windex                : std_logic_vector(BHTBITS - 1 downto OFFSET);
    variable history               : bhthistory;
    variable whistory              : bhthistory;
    variable rhistory0             : bhthistory;
    variable rhistory1             : bhthistory;
    variable rphthistory0          : std_logic_vector(PHTBITS - 1 downto 0);
    variable rphthistory1          : std_logic_vector(PHTBITS - 1 downto 0);
    variable rpht0                 : phto;
    variable rpht1                 : phto;
    variable pht0                  : std_logic_vector(MAX_PREDICTOR_BITS - 1 downto 0);
    variable pht1                  : std_logic_vector(MAX_PREDICTOR_BITS - 1 downto 0);
    variable wdata                 : std_logic_vector(COUNTERBITS - 1 downto 0);
    variable taken                 : std_logic_vector(3 downto 0);

    variable rindex_comb           : std_logic_vector(log2ext(nentries) - 1 downto 0);
    variable bhistory              : std_logic_vector(hlength - 1 downto 0);
    variable phistory              : std_logic_vector((2 ** hlength) * 2 - 1 downto 0);
    variable bwhistory             : std_logic_vector(hlength - 1 downto 0);
    variable bhto_bhistory         : std_logic_vector( 4 downto 0);
    variable bhto_phistory         : std_logic_vector(63 downto 0);
    variable bhti_wdata            : std_logic_vector( 1 downto 0);
    variable bhti_phistory_temp    : std_logic_vector((2 ** hlength) * 2 - 1 downto 0);
    variable bhistory_new          : std_logic_vector(hlength - 1 downto 0);
    variable pht_rev,pht_wev       : std_ulogic;
    variable pht_raddrv,pht_waddrv : std_logic_vector(log2ext(nentries) - 1 downto 0);
    variable pht_rdatav            : std_logic_vector((2 ** hlength) * 2 - 1 downto 0);
    variable pht_wdatav            : std_logic_vector((2 ** hlength) * 2 - 1 downto 0);
  begin

    v := r;

    -- Sample input signals
    windex              := bhti.waddr(BHTBITS - 1 downto OFFSET);
    rindex_comb         := bhti.raddr_comb(BHTBITS - 1 downto OFFSET);

    v.ren               := '0';
    if holdn = '1' and bhti.ren = '1' then
      v.ren             := '1';
      v.rindex_reg      := rindex_comb;
      v.write_forwarded := '0';
    end if;
    pht_rev             := v.ren;
    
    if bhti.iustall = '0' and holdn = '1' then
      v.rindex_bhist_reg := bhti.rindex_bhist(BHTBITS - 1 downto OFFSET);
    end if;

    pht_rdatav         := r.pht_rdata_hold;
    if r.ren = '1' and r.write_forwarded = '0' then
      pht_rdatav       := pht_rdata;
      if notx(r.rindex_reg) then
        if r.valid(to_integer(unsigned(r.rindex_reg))) = '0' then
          pht_rdatav   := (others => '0');
        end if;
      else
        setx(pht_rdatav);
      end if;
      v.pht_rdata_hold := pht_rdatav;
    end if;

    phistory := pht_rdatav;


    bhistory            := r.bhist_data_hold;
    if r.ren = '1' then
      bhistory          := r.bhttable(conv_integer(r.rindex_reg));

      if r.valid(to_integer(unsigned(r.rindex_reg))) = '0' then
        bhistory        := (others => '0');
      end if;
      v.bhist_data_hold := bhistory;
    end if;
    
    bhti_wdata := bhti.phistory(1 downto 0);
    if notx(bhti.bhistory) then
      for i in 0 to 2 ** hlength - 1 loop
        if i = unsigned(bhti.bhistory(hlength - 1 downto 0)) then
          bhti_wdata := bhti.phistory(i * 2 + 1 downto i * 2);
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
             
    bhti_phistory_temp := bhti.phistory((2 ** hlength) * 2 - 1 downto 0);

    pht_raddrv := rindex_comb;
    
    pht_wev     := '0';
    pht_waddrv  := windex;
    if bhti.wen = '1' then
      pht_wev   := '1';
      bwhistory := bhti.bhistory(hlength - 1 downto 0);
      for i in 0 to 2 ** hlength - 1 loop
        if i = unsigned(bwhistory) then
          bhti_phistory_temp(i * 2 + 1 downto i * 2) := wdata;
        end if;
      end loop;
      v.valid(to_integer(unsigned(pht_waddrv)))      := '1';

      if pht_waddrv = r.rindex_reg then
        -- Write forwarding
        v.pht_rdata_hold := bhti_phistory_temp;
      end if;

      v.write_forwarded   := '0';
      if pht_waddrv = pht_raddrv then
        v.write_forwarded := '1';
        v.pht_rdata_hold  := bhti_phistory_temp;
      end if;
      
    end if;

    pht_wdatav := bhti_phistory_temp;
    
    bhistory_new := bhti.taken & bhti.bhistory(hlength - 1 downto 1);
    if bhti.wen = '1' then
      v.bhttable(conv_integer(windex))(hlength - 1)          := bhti.taken;
      v.bhttable(conv_integer(windex))(hlength - 2 downto 0) := bhti.bhistory(hlength - 1 downto 1);

      -- Update btb taken for the upcoming history
      -- For "0000" and "1111", the next history might correspond to an updated value
      -- on this cycle, hence use the updated phistory.
      for i in 0 to 2 ** hlength - 1 loop
        if i = unsigned(bhistory_new) then
          v.taken(conv_integer(windex)) := bhti_phistory_temp(i * 2 + 1);
        end if;
      end loop;
      
    end if;                
          
    taken(0)   := r.taken(conv_integer(r.rindex_bhist_reg));
    taken(1)   := r.taken(conv_integer(r.rindex_bhist_reg(log2ext(nentries) - 1 downto 1) & '1'));
    taken(2)   := '0';
    taken(3)   := '0';
    if ext_c /= 0 and dissue /= 0 then
      taken(1) := r.taken(conv_integer(r.rindex_bhist_reg(log2ext(nentries) - 1 downto 2) & "01"));
      taken(2) := r.taken(conv_integer(r.rindex_bhist_reg(log2ext(nentries) - 1 downto 2) & "10"));
      taken(3) := r.taken(conv_integer(r.rindex_bhist_reg(log2ext(nentries) - 1 downto 2) & "11"));
    end if;
  
    if bhti.flush = '1' then
      v.valid := (others => '0');
    end if;

    bhto_bhistory(hlength - 1 downto 0)            := bhistory;
    bhto_phistory((2 ** hlength) * 2 - 1 downto 0) := phistory;

    -- Output Signals
    bhto.taken    <= taken;
    bhto.phistory <= bhto_phistory;
    bhto.bhistory <= bhto_bhistory;

    rin           <= v;

    pht_re        <= pht_rev;
    pht_we        <= pht_wev;
    pht_raddr     <= pht_raddrv;
    pht_waddr     <= pht_waddrv;
    pht_wdata     <= pht_wdatav;

  end process;

  seq : process(clk, rstn)
  begin
    if rising_edge(clk) then
      if rstn = '0' then
        r.pht_rdata_hold  <= (others => '0');
        r.bhist_data_hold <= (others => '0');
        r.valid           <= (others => '0');
        r.ren             <= '0';
        r.write_forwarded <= '0';
      else
        r <= rin;
      end if;
    end if;

  end process;

end rtl;
