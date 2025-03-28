------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
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
-- Entity:      libcache
-- File:        libcache.vhd
-- Author:      Jiri Gaisler, Edvin Catovic, Gaisler Research
-- Description: Cache-related types and components
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.libiu.all;
use gaisler.mmuconfig.all;
use gaisler.mmuiface.all;

package libcache is

  constant TAG_HIGH     : integer := 31;
  constant CTAG_LRRPOS  : integer := 9;
  constant CTAG_LOCKPOS : integer := 8;
  constant MAXSETS      : integer := 4;

  -- 3-way set permutations
  -- s012 => set 0 - least recently used
  --         set 2 - most recently used
  constant s012 : std_logic_vector(2 downto 0) := "000";
  constant s021 : std_logic_vector(2 downto 0) := "001";
  constant s102 : std_logic_vector(2 downto 0) := "010";
  constant s120 : std_logic_vector(2 downto 0) := "011";
  constant s201 : std_logic_vector(2 downto 0) := "100";
  constant s210 : std_logic_vector(2 downto 0) := "101";


  -- 4-way set permutations
  -- s0123 => set 0 - least recently used
  --          set 3 - most recently used
  -- bits assigned so bits 4:3 is LRU and 1:0 is MRU
  -- middle bit is 0 for 01 02 03 12 13 23, 1 for 10 20 30 21 31 32
  constant s0123 : std_logic_vector(4 downto 0) := "00011";
  constant s0132 : std_logic_vector(4 downto 0) := "00010";
  constant s0213 : std_logic_vector(4 downto 0) := "00111";
  constant s0231 : std_logic_vector(4 downto 0) := "00001";
  constant s0312 : std_logic_vector(4 downto 0) := "00110";
  constant s0321 : std_logic_vector(4 downto 0) := "00101";
  constant s1023 : std_logic_vector(4 downto 0) := "01011";
  constant s1032 : std_logic_vector(4 downto 0) := "01010";
  constant s1203 : std_logic_vector(4 downto 0) := "01111";
  constant s1230 : std_logic_vector(4 downto 0) := "01000";
  constant s1302 : std_logic_vector(4 downto 0) := "01110";
  constant s1320 : std_logic_vector(4 downto 0) := "01100";
  constant s2013 : std_logic_vector(4 downto 0) := "10011";
  constant s2031 : std_logic_vector(4 downto 0) := "10001";
  constant s2103 : std_logic_vector(4 downto 0) := "10111";
  constant s2130 : std_logic_vector(4 downto 0) := "10000";
  constant s2301 : std_logic_vector(4 downto 0) := "10101";
  constant s2310 : std_logic_vector(4 downto 0) := "10100";
  constant s3012 : std_logic_vector(4 downto 0) := "11010";
  constant s3021 : std_logic_vector(4 downto 0) := "11001";
  constant s3102 : std_logic_vector(4 downto 0) := "11110";
  constant s3120 : std_logic_vector(4 downto 0) := "11000";
  constant s3201 : std_logic_vector(4 downto 0) := "11101";
  constant s3210 : std_logic_vector(4 downto 0) := "11100";

  type lru_3set_table_vector_type is array(0 to 2) of std_logic_vector(2 downto 0);
  type lru_3set_table_type is array (0 to 7) of lru_3set_table_vector_type;

  constant lru_3set_table : lru_3set_table_type :=
    ( (s120, s021, s012),                   -- s012
      (s210, s021, s012),                   -- s021
      (s120, s021, s102),                   -- s102
      (s120, s201, s102),                   -- s120
      (s210, s201, s012),                   -- s201
      (s210, s201, s102),                   -- s210
      (s210, s201, s102),                   -- dummy
      (s210, s201, s102)                    -- dummy
      );
  
  type lru_4set_table_vector_type is array(0 to 3) of std_logic_vector(4 downto 0);
  type lru_4set_table_type is array(0 to 31) of lru_4set_table_vector_type;

  constant lru_4set_table : lru_4set_table_type :=
    ( (s2310, s0231, s0312, s0213),       -- "00000" (s0231/reset)
      (s2310, s0231, s0312, s0213),       -- "00001" s0231
      (s1320, s0321, s0132, s0123),       -- "00010" s0132
      (s1230, s0231, s0132, s0123),       -- "00011" s0123
      (s3210, s0321, s0312, s0213),       -- "00100" (s0321)
      (s3210, s0321, s0312, s0213),       -- "00101" s0321
      (s3120, s0321, s0312, s0123),       -- "00110" s0312
      (s2130, s0231, s0132, s0213),       -- "00111" s0213
      (s1230, s2301, s1302, s1203),       -- "01000" s1230
      (s1230, s2301, s1302, s1203),       -- "01001" (s1230)
      (s1320, s0321, s1032, s1023),       -- "01010" s1032
      (s1230, s0231, s1032, s1023),       -- "01011" s1023
      (s1320, s3201, s1302, s1203),       -- "01100" s1320
      (s1320, s3201, s1302, s1203),       -- "01101" (s1320)
      (s1320, s3021, s1302, s1023),       -- "01110" s1302
      (s1230, s2031, s1032, s1203),       -- "01111" s1203
      (s2130, s2301, s1302, s2103),       -- "10000" s2130
      (s2310, s2031, s0312, s2013),       -- "10001" s2031
      (s2130, s2031, s0132, s2013),       -- "10010" (s2013)
      (s2130, s2031, s0132, s2013),       -- "10011" s2013
      (s2310, s2301, s3102, s2103),       -- "10100" s2310
      (s2310, s2301, s3012, s2013),       -- "10101" s2301
      (s2130, s2031, s1032, s2103),       -- "10110" (s2103)
      (s2130, s2031, s1032, s2103),       -- "10111" s2103
      (s3120, s3201, s3102, s1203),       -- "11000" s3120
      (s3210, s3021, s3012, s0213),       -- "11001" s3021
      (s3120, s3021, s3012, s0123),       -- "11010" s3012
      (s3120, s3021, s3012, s0123),       -- "11011" (s3012)
      (s3210, s3201, s3102, s2103),       -- "11100" s3210
      (s3210, s3201, s3012, s2013),       -- "11101" s3201
      (s3120, s3021, s3102, s1023),       -- "11110" s3102
      (s3120, s3021, s3102, s1023)        -- "11111" (s3102)
      );

  type lru3_repl_table_single_type is array(0 to 2) of integer range 0 to 2;
  type lru3_repl_table_type is array(0 to 7) of lru3_repl_table_single_type;

  constant lru3_repl_table : lru3_repl_table_type :=
    ( (0, 1, 2),      -- s012
      (0, 2, 2),      -- s021
      (1, 1, 2),      -- s102
      (1, 1, 2),      -- s120
      (2, 2, 2),      -- s201
      (2, 2, 2),      -- s210
      (2, 2, 2),      -- dummy
      (2, 2, 2)       -- dummy
      );

  type lru4_repl_table_single_type is array(0 to 3) of integer range 0 to 3;
  type lru4_repl_table_type is array(0 to 31) of lru4_repl_table_single_type;

  constant lru4_repl_table : lru4_repl_table_type :=
    ( (0, 2, 2, 3), -- (s0231/reset)
      (0, 2, 2, 3), -- s0231
      (0, 1, 3, 3), -- s0132
      (0, 1, 2, 3), -- s0123
      (0, 3, 3, 3), -- (s0321)
      (0, 3, 3, 3), -- s0321
      (0, 3, 3, 3), -- s0312
      (0, 2, 2, 3), -- s0213
      (1, 1, 2, 3), -- s1230
      (1, 1, 2, 3), -- (s1230)
      (1, 1, 3, 3), -- s1032
      (1, 1, 2, 3), -- s1023
      (1, 1, 3, 3), -- s1320
      (1, 1, 3, 3), -- (s1320)
      (1, 1, 3, 3), -- s1302
      (1, 1, 2, 3), -- s1203
      (2, 2, 2, 3), -- s2130
      (2, 2, 2, 3), -- s2031
      (2, 2, 2, 3), -- (s2013)
      (2, 2, 2, 3), -- s2013
      (2, 2, 2, 3), -- s2310
      (2, 2, 2, 3), -- s2301
      (2, 2, 2, 3), -- (s2103)
      (2, 2, 2, 3), -- s2103
      (3, 3, 3, 3), -- s3120
      (3, 3, 3, 3), -- s3021
      (3, 3, 3, 3), -- s3012
      (3, 3, 3, 3), -- (s3012)
      (3, 3, 3, 3), -- s3210
      (3, 3, 3, 3), -- s3201
      (3, 3, 3, 3), -- s3102
      (3, 3, 3, 3)  -- (s3102)
      );

  type ildram_in_type is record
     enable        : std_ulogic;
     read          : std_ulogic;
     write         : std_ulogic;
     address       : std_logic_vector(19 downto 0);
  end record;

  subtype ctxword is std_logic_vector(M_CTX_SZ-1 downto 0);
  type ctxdatatype is array (0 to 3) of ctxword;

  type icram_in_type is record
     address       : std_logic_vector(19 downto 0);
     tag           : cdatatype;
     subit         : std_logic;
     twrite        : std_logic_vector(0 to 3);
     tenable       : std_logic_vector(0 to 3);
     flush         : std_ulogic;
     data          : std_logic_vector(31 downto 0);
     denable       : std_logic_vector(0 to 3);
     dwrite        : std_logic_vector(0 to 3);
     ldramin       : ildram_in_type;
     ctx           : std_logic_vector(M_CTX_SZ-1 downto 0);
  end record;

  type icram_out_type is record
     tag           : cdatatype;
     data          : cdatatype;
     ctx           : ctxdatatype;
     subit         : std_logic_vector(0 to 3);
  end record;

  type ldram_in_type is record
     address       : std_logic_vector(23 downto 2);
     enable        : std_ulogic;
     read          : std_ulogic;
     write         : std_ulogic;
  end record;

  type dcram_in_type is record
     address       : std_logic_vector(19 downto 0);
     tag           : cdatatype; --std_logic_vector(31  downto 0);
     ptag          : cdatatype; --std_logic_vector(31  downto 0);
     subit         : std_logic;
     twrite        : std_logic_vector(0 to 3);
     tpwrite       : std_logic_vector(0 to 3);
     tenable       : std_logic_vector(0 to 3);
     flush         : std_logic_vector(0 to 3);
     data          : cdatatype;
     denable       : std_logic_vector(0 to 3);
     dwrite        : std_logic_vector(0 to 3);
     senable       : std_logic_vector(0 to 3);
     swrite        : std_logic_vector(0 to 3);
     saddress      : std_logic_vector(19 downto 0);
     faddress      : std_logic_vector(19 downto 0);
     ldramin       : ldram_in_type;
     ctx           : ctxdatatype;
     snhit         : std_logic_vector(0 to 3);
     snhitaddr     : std_logic_vector(19 downto 0);
     flushall      : std_ulogic;
     bwdata        : cdatatype;
     bwmask        : cbwmasktype;
  end record;

  type dcram_out_type is record
     tag           : cdatatype;
     data          : cdatatype;
     stag          : cdatatype;
     ctx           : ctxdatatype;
     subit         : std_logic_vector(0 to 3);
  end record;

  type cram_in_type is record
     icramin       : icram_in_type;
     dcramin       : dcram_in_type;
  end record;

  type cram_out_type is record
     icramo        : icram_out_type;
     dcramo        : dcram_out_type;
  end record;

  type memory_ic_in_type is record
     address          : std_logic_vector(31 downto 0); -- memory address
     burst            : std_ulogic;                        -- burst request
     req              : std_ulogic;                        -- memory cycle request
     su               : std_ulogic;                        -- supervisor address space
     flush            : std_ulogic;                        -- flush in progress
     -- next cycle value (for re-timing)
     next_address     : std_logic_vector(31 downto 0);
     next_burst       : std_ulogic;
     next_req         : std_ulogic;
     next_su          : std_ulogic;
  end record;

  type memory_ic_out_type is record
     data             : std_logic_vector(31 downto 0); -- memory data
     ready            : std_ulogic;                            -- cycle ready
     grant            : std_ulogic;                            -- 
     retry            : std_ulogic;                            -- 
     mexc             : std_ulogic;                            -- memory exception
     cache            : std_ulogic;                -- cacheable data
  end record;

  type memory_dc_in_type is record
     address          : std_logic_vector(31 downto 0); 
     data             : std_logic_vector(31 downto 0);
     asi              : std_logic_vector(3 downto 0); -- ASI for load/store
     size             : std_logic_vector(1 downto 0);
     burst            : std_ulogic;
     read             : std_ulogic;
     req              : std_ulogic;
     lock             : std_ulogic;
     cache            : std_ulogic;
     lock_hold        : std_ulogic;
     -- next cycle value (for re-timing)
     next_address     : std_logic_vector(31 downto 0);
     next_data        : std_logic_vector(31 downto 0);
     next_asi         : std_logic_vector(3 downto 0);
     next_size        : std_logic_vector(1 downto 0);
     next_burst       : std_ulogic;
     next_read        : std_ulogic;
     next_req         : std_ulogic;
     next_lock        : std_ulogic;
     next_cache       : std_ulogic;
     next_lock_hold   : std_ulogic;
  end record;

  type memory_dc_out_type is record
     data             : std_logic_vector(31 downto 0); -- memory data
     ready            : std_ulogic;                -- cycle ready
     grant            : std_ulogic;
     retry            : std_ulogic;
     mexc             : std_ulogic;                -- memory exception
     werr             : std_ulogic;                -- memory write error
     cache            : std_ulogic;                -- cacheable data
     ba               : std_ulogic;                -- bus active (used for snooping)
     bg               : std_ulogic;                -- bus grant  (used for snooping)
  end record;

  constant dir          : integer                := 3;
  constant rnd          : integer                := 2;
  constant lrr          : integer                := 1;
  constant lru          : integer                := 0;
  type cache_replalgbits_type is array (0 to 3) of integer;
  constant creplalg_tbl : cache_replalgbits_type := (0, 1, 0, 0);
  type lru_bits_type is array(1 to 4) of integer;
  constant lru_table    : lru_bits_type          := (1,1,3,5);

  component cachemem
    generic (
      tech      : integer range 0 to NTECH := 0;
      icen      : integer range 0 to 1     := 0;
      irepl     : integer range 0 to 3     := 0;
      isets     : integer range 1 to 4     := 1;
      ilinesize : integer range 4 to 8     := 4;
      isetsize  : integer range 1 to 256   := 1;
      isetlock  : integer range 0 to 1     := 0;
      dcen      : integer range 0 to 1     := 0;
      drepl     : integer range 0 to 3     := 0;
      dsets     : integer range 1 to 4     := 1;
      dlinesize : integer range 4 to 8     := 4;
      dsetsize  : integer range 1 to 256   := 1;
      dsetlock  : integer range 0 to 1     := 0;
      dsnoop    : integer range 0 to 7     := 0;
      ilram     : integer range 0 to 2     := 0;
      ilramsize : integer range 1 to 512   := 1;
      dlram     : integer range 0 to 2     := 0;
      dlramsize : integer range 1 to 512   := 1;
      mmuen     : integer range 0 to 2     := 0;
      testen    : integer range 0 to 3     := 0;
      icreadhold: integer range 0 to 1     := 0;
      dcreadhold: integer range 0 to 1     := 0
      );
    port (
        clk   : in  std_ulogic;
        crami : in  cram_in_type;
        cramo : out cram_out_type;
        sclk  : in  std_ulogic;
        testin: in  std_logic_vector(TESTIN_WIDTH-1 downto 0)
  );
  end component;

  component cmvalidbits is
    generic (
      abits : integer;
      nways : integer range 1 to 4
      );
    port (
      clk     : in std_ulogic;
      caddr   : in std_logic_vector(abits-1 downto 0);
      cenable : in std_logic_vector(0 to nways-1);
      cwrite  : in std_logic_vector(0 to nways-1);
      cwdata  : in std_logic_vector(0 to nways-1);
      crdata  : out std_logic_vector(0 to nways-1);
      saddr   : in std_logic_vector(abits-1 downto 0);
      sclear  : in std_logic_vector(0 to nways-1);
      flush   : in std_ulogic
      );
  end component;

  -- mmu versions
  component mmu_acache
    generic (
      hindex    :     integer range 0 to NAHBMST-1 := 0;
      ilinesize :     integer range 4 to 8         := 4;
      cached    :     integer                      := 0;
      clk2x     :     integer                      := 0;
      scantest  :     integer                      := 0
      );
    port (
      rst       : in  std_logic;
      clk       : in  std_logic;
      mcii      : in  memory_ic_in_type;
      mcio      : out memory_ic_out_type;
      mcdi      : in  memory_dc_in_type;
      mcdo      : out memory_dc_out_type;
      mcmmi     : in  memory_mm_in_type;
      mcmmo     : out memory_mm_out_type;
      ahbi      : in  ahb_mst_in_type;
      ahbo      : out ahb_mst_out_type;
      ahbso     : in  ahb_slv_out_vector;
      hclken    : in  std_ulogic
      );
  end component;

  component mmu_icache
    generic (
      fabtech   :     integer                := 0;
      icen      :     integer range 0 to 1   := 0;
      irepl     :     integer range 0 to 3   := 0;
      isets     :     integer range 1 to 4   := 1;
      ilinesize :     integer range 4 to 8   := 4;
      isetsize  :     integer range 1 to 256 := 1;
      isetlock  :     integer range 0 to 1   := 0;
      lram      :     integer range 0 to 2   := 0;
      lramsize  :     integer range 1 to 512 := 1;
      lramstart :     integer range 0 to 255 := 16#8e#;
      mmuen     :     integer range 0 to 2   := 0;
      memtech   :     integer                := 0;
      icreadhold :    integer range 0 to 1   := 0
      );
    port (
      rst       : in  std_logic;
      clk       : in  std_logic;
      ici       : in  icache_in_type;
      ico       : out icache_out_type;
      dci       : in  dcache_in_type;
      dco       : in  dcache_out_type;
      mcii      : out memory_ic_in_type;
      mcio      : in  memory_ic_out_type;
      icrami    : out icram_in_type;
      icramo    : in  icram_out_type;
      fpuholdn  : in  std_logic;
      mmudci    : in  mmudc_in_type;
      mmuici    : out mmuic_in_type;
      mmuico    : in  mmuic_out_type
      );
  end component;

  component mmu_dcache
    generic (
      dsu        :     integer range 0 to 1     := 0;
      dcen       :     integer range 0 to 1     := 0;
      drepl      :     integer range 0 to 3     := 0;
      dsets      :     integer range 1 to 4     := 1;
      dlinesize  :     integer range 4 to 8     := 4;
      dsetsize   :     integer range 1 to 256   := 1;
      dsetlock   :     integer range 0 to 1     := 0;
      dsnoop     :     integer range 0 to 7     := 0;
      dlram      :     integer range 0 to 2     := 0;
      dlramsize  :     integer range 1 to 512   := 1;
      dlramstart :     integer range 0 to 255   := 16#8f#;
      ilram      :     integer range 0 to 2     := 0;
      ilramstart :     integer range 0 to 255   := 16#8e#;
      itlbnum    :     integer range 2 to 64    := 8;
      dtlbnum    :     integer range 2 to 64    := 8;
      tlb_type   :     integer range 0 to 3     := 1;
      memtech    :     integer range 0 to NTECH := 0;
      cached     :     integer                  := 0;
      mmupgsz    :     integer range 0 to 5     := 0;
      smp        :     integer                  := 0;
      mmuen      :     integer range 0 to 2     := 0;
      icen       :     integer range 0 to 1     := 0;
      irqlat     :     integer range 0 to 1     := 0;
      dcreadhold :     integer range 0 to 1     := 0
      );
    port (
      rst        : in  std_logic;
      clk        : in  std_logic;
      dci        : in  dcache_in_type;
      dco        : out dcache_out_type;
      ico        : in  icache_out_type;
      mcdi       : out memory_dc_in_type;
      mcdo       : in  memory_dc_out_type;
      ahbsi      : in  ahb_slv_in_type;
      dcrami     : out dcram_in_type;
      dcramo     : in  dcram_out_type;
      fpuholdn   : in  std_logic;
      mmudci     : out mmudc_in_type;
      mmudco     : in  mmudc_out_type;
      sclk       : in  std_ulogic;
      ahbso      : in  ahb_slv_out_vector
      );
  end component;

  component mmu_cache
    generic (
      hindex     :     integer                  := 0;
      fabtech    :     integer                  := 0;
      memtech    :     integer                  := 0;
      dsu        :     integer range 0 to 1     := 0;
      icen       :     integer range 0 to 1     := 0;
      irepl      :     integer range 0 to 3     := 0;
      isets      :     integer range 1 to 4     := 1;
      ilinesize  :     integer range 4 to 8     := 4;
      isetsize   :     integer range 1 to 256   := 1;
      isetlock   :     integer range 0 to 1     := 0;
      dcen       :     integer range 0 to 1     := 0;
      drepl      :     integer range 0 to 3     := 0;
      dsets      :     integer range 1 to 4     := 1;
      dlinesize  :     integer range 4 to 8     := 4;
      dsetsize   :     integer range 1 to 256   := 1;
      dsetlock   :     integer range 0 to 1     := 0;
      dsnoop     :     integer range 0 to 7     := 0;
      ilram      :     integer range 0 to 2     := 0;
      ilramsize  :     integer range 1 to 512   := 1;
      ilramstart :     integer range 0 to 255   := 16#8e#;
      dlram      :     integer range 0 to 2     := 0;
      dlramsize  :     integer range 1 to 512   := 1;
      dlramstart :     integer range 0 to 255   := 16#8f#;
      itlbnum    :     integer range 2 to 64    := 8;
      dtlbnum    :     integer range 2 to 64    := 8;
      tlb_type   :     integer range 0 to 3     := 1;
      tlb_rep    :     integer range 0 to 1     := 0;
      cached     :     integer                  := 0;
      clk2x      :     integer                  := 0;
      scantest   :     integer                  := 0;
      mmupgsz    :     integer range 0 to 5     := 0;
      smp        :     integer                  := 0;
      mmuen      :     integer range 0 to 2     := 0;
      irqlat     :     integer range 0 to 1     := 0;
      dcreadhold :     integer range 0 to 1     := 0;
      icreadhold :     integer range 0 to 1     := 0
      );
    port (
      rst        : in  std_ulogic;
      clk        : in  std_ulogic;
      ici        : in  icache_in_type;
      ico        : out icache_out_type;
      dci        : in  dcache_in_type;
      dco        : out dcache_out_type;
      ahbi       : in  ahb_mst_in_type;
      ahbo       : out ahb_mst_out_type;
      ahbsi      : in  ahb_slv_in_type;
      ahbso      : in  ahb_slv_out_vector;
      crami      : out cram_in_type;
      cramo      : in  cram_out_type;
      fpuholdn   : in  std_ulogic;
      hclk, sclk : in  std_ulogic;
      hclken     : in  std_ulogic
      );
  end component;

  component clk2xqual
    port (
      rst   : in  std_ulogic;
      clk   : in  std_ulogic;
      clk2  : in  std_ulogic;
      clken : out std_ulogic);
  end component;

  component clk2xsync
    generic (
      hindex        :     integer := 0;
      clk2x         :     integer := 1);
    port (
      rst           : in  std_ulogic;
      hclk          : in  std_ulogic;
      clk           : in  std_ulogic;
      ahbi          : in  ahb_mst_in_type;
      ahbi2         : out ahb_mst_in_type;
      ahbo          : in  ahb_mst_out_type;
      ahbo2         : out ahb_mst_out_type;
      ahbsi         : in  ahb_slv_in_type;
      ahbsi2        : out ahb_slv_in_type;
      mcii          : in  memory_ic_in_type;
      mcdi          : in  memory_dc_in_type;
      mcdo          : in  memory_dc_out_type;
      mmreq         : in  std_ulogic;
      mmgrant       : in  std_ulogic;    
      hclken        : in std_ulogic
      );
  end component;
  
  function cache_cfg(repl, sets, linesize, setsize, lock, snoop,
    lram, lramsize, lramstart, mmuen, subiten : integer) return std_logic_vector;
  function mmuen_set(mmuen : integer) return integer;
  function subit_set(mmuen : integer) return integer;
  
end;

package body libcache is

  function cache_cfg(repl, sets, linesize, setsize, lock, snoop,
                     lram, lramsize, lramstart, mmuen, subiten : integer)
    return std_logic_vector is 
    variable cfg : std_logic_vector(31 downto 0);
  begin
    cfg := (others => '0');
    cfg(31 downto 31) := conv_std_logic_vector(lock, 1);
    if sets /= 1 then
      cfg(30 downto 28) := conv_std_logic_vector(repl+1, 3);
    end if;
    if snoop /= 0 then cfg(27) := '1'; end if;
    cfg(26 downto 24) := conv_std_logic_vector(sets-1, 3);
    cfg(23 downto 20) := conv_std_logic_vector(log2(setsize), 4);
    cfg(19 downto 19) := conv_std_logic_vector(lram, 1);
    cfg(18 downto 16) := conv_std_logic_vector(log2(linesize), 3);
    cfg(15 downto 12) := conv_std_logic_vector(log2(lramsize), 4);
    cfg(11 downto  4) := conv_std_logic_vector(lramstart, 8);
    cfg(3  downto  3) := conv_std_logic_vector(mmuen, 1);
    cfg(2  downto  2) := conv_std_logic_vector(subiten, 1);
    return(cfg);
  end;

  function mmuen_set(mmuen : integer)
    return integer is
    variable ret : integer;
  begin

    ret := 0;

    if mmuen > 0 then
      ret := 1;
    end if;

    return ret;

  end ;

  function subit_set(mmuen : integer)
    return integer is
    variable ret : integer;
  begin

    ret := 0;

    if mmuen = 2 then
      ret := 1;
    end if;

    return ret;

  end ;

  
end;

