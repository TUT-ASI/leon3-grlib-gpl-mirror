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
-- Entity: 	regfile64l5
-- File:	regfile64l5.vhd
-- Author:	Andrea Merlo, Cobham Gaisler AB
-- Description:	4-read ports and 2-write ports regfile
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
use techmap.allmem.all;
library grlib;
use grlib.stdlib.log2x;
use grlib.riscv.reg_t;
library gaisler;
use gaisler.utilnv.u2i;
use gaisler.utilnv.b2i;

entity regfile64sramnv is
  generic (
    tech        : integer;
    reg0write   : integer := 0;
    dissue      : integer := 1;
    testen      : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    rdhold   : in  std_ulogic;
    waddr1   : in  reg_t;
    wdata1   : in  std_logic_vector;
    we1      : in  std_ulogic;
    waddr2   : in  reg_t;
    wdata2   : in  std_logic_vector;
    we2      : in  std_ulogic;
    raddr1   : in  reg_t;
    re1      : in  std_ulogic;
    rdata1   : out std_logic_vector;
    raddr2   : in  reg_t;
    re2      : in  std_ulogic;
    rdata2   : out std_logic_vector;
    raddr3   : in  reg_t;
    re3      : in  std_ulogic;
    rdata3   : out std_logic_vector;
    raddr4   : in  reg_t;
    re4      : in  std_ulogic;
    rdata4   : out std_logic_vector;
    testin   : in  std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none
    );
begin
end regfile64sramnv;

architecture rtl of regfile64sramnv is


  constant abits : integer := reg_t'length;
  constant dbits : integer := wdata1'length;
  
  subtype  data_t is std_logic_vector(dbits - 1 downto 0);

  constant RPORTS : integer := 4;
  constant WPORTS : integer := 2;
  constant DB32   : integer := 2 - data_t'length / 32;

  type lwrite is array (0 to 2 ** reg_t'length - 1) of std_logic_vector(log2x(WPORTS) - 1 downto 0);

  type reg_type is record
    raddr1    : reg_t;
    raddr2    : reg_t;
    raddr3    : reg_t;
    raddr4    : reg_t;
    port1wf   : std_logic;
    port2wf   : std_logic;
    port3wf   : std_logic;
    port4wf   : std_logic;
    holddata1 : data_t;
    holddata2 : data_t;
    holddata3 : data_t;
    holddata4 : data_t;
    lwrite1   : lwrite;
    lwrite2   : lwrite;
    lwrite3   : lwrite;
    lwrite4   : lwrite;
  end record;

  constant reg_type_rst : reg_type := (
    raddr1      => (others => '0'),
    raddr2      => (others => '0'),
    raddr3      => (others => '0'),
    raddr4      => (others => '0'),
    port1wf     => '0',
    port2wf     => '0',
    port3wf     => '0',
    port4wf     => '0',
    holddata1   => (others => '0'),
    holddata2   => (others => '0'),
    holddata3   => (others => '0'),
    holddata4   => (others => '0'),
    lwrite1     => (others => (others => '0')),
    lwrite2     => (others => (others => '0')),
    lwrite3     => (others => (others => '0')),
    lwrite4     => (others => (others => '0'))
    
  );

  signal rdata10, rdata11 : data_t;
  signal rdata20, rdata21 : data_t;
  signal rdata30, rdata31 : data_t;
  signal rdata40, rdata41 : data_t;
  signal re1_masked       : std_logic;
  signal re2_masked       : std_logic;
  signal re3_masked       : std_logic;
  signal re4_masked       : std_logic;

  signal r, rin : reg_type;

begin  -- rtl

  -- Syncrams (WPORTS for each RPORTS)


    -- PORT1
    x0 : syncram_2p generic map (tech, abits, dbits, 0, 0, testen, 0, memtest_vlen, 0, 1)
      port map (clk, re1_masked, raddr1, rdata10, clk, we1, waddr1, wdata1, testin
                );

    x1 : syncram_2p generic map (tech, abits, dbits, 0, 0, testen, 0, memtest_vlen, 0, 1)
      port map (clk, re1_masked, raddr1, rdata11, clk, we2, waddr2, wdata2, testin
                );

    -- PORT2
    p2d: if dissue /= 0 generate
      x2 : syncram_2p generic map (tech, abits, dbits, 0, 0, testen, 0, memtest_vlen, 0, 1)
        port map (clk, re2_masked, raddr2, rdata20, clk, we1, waddr1, wdata1, testin
                  );

      x3 : syncram_2p generic map (tech, abits, dbits, 0, 0, testen, 0, memtest_vlen, 0, 1)
        port map (clk, re2_masked, raddr2, rdata21, clk, we2, waddr2, wdata2, testin
                  );
    end generate;

    -- PORT3
    x4 : syncram_2p generic map (tech, abits, dbits, 0, 0, testen, 0, memtest_vlen, 0, 1)
      port map (clk, re3_masked, raddr3, rdata30, clk, we1, waddr1, wdata1, testin
                );

    x5 : syncram_2p generic map (tech, abits, dbits, 0, 0, testen, 0, memtest_vlen, 0, 1)
      port map (clk, re3_masked, raddr3, rdata31, clk, we2, waddr2, wdata2, testin
                );

    -- PORT4
    p4d : if dissue /= 0 generate
      x6 : syncram_2p generic map (tech, abits, dbits, 0, 0, testen, 0, memtest_vlen, 0, 1)
        port map (clk, re4_masked, raddr4, rdata40, clk, we1, waddr1, wdata1, testin
                  );

      x7 : syncram_2p generic map (tech, abits, dbits, 0, 0, testen, 0, memtest_vlen, 0, 1)
        port map (clk, re4_masked, raddr4, rdata41, clk, we2, waddr2, wdata2, testin
                  );
    end generate;



  comb : process(r, rstn, waddr1, we1, wdata1, waddr2, we2, wdata2, re1, raddr1, re2, raddr2, re3, raddr3, re4, raddr4, rdata10, rdata11, rdata20, rdata21, rdata30, rdata31, rdata40, rdata41, rdhold
)
    variable v         : reg_type;
    variable rdata1v   : data_t;
    variable rdata2v   : data_t;
    variable rdata3v   : data_t;
    variable rdata4v   : data_t;
    variable rdzp1     : std_ulogic;
    variable rdzp2     : std_ulogic;
    variable rdzp3     : std_ulogic;
    variable rdzp4     : std_ulogic;
    variable forw_sel1 : std_ulogic;
    variable forw_sel2 : std_ulogic;
    variable forw_sel3 : std_ulogic;
    variable forw_sel4 : std_ulogic;
  begin

    v := r;

    -- Register Input Address
    if rdhold = '0' then
      v.port1wf := '0';
      v.port2wf := '0';
      v.port3wf := '0';
      v.port4wf := '0';
      if re1 = '1' then
        v.raddr1  := raddr1;
      end if;

      if re2 = '1' then
        v.raddr2  := raddr2;
      end if;

      if re3 = '1' then
        v.raddr3  := raddr3;
      end if;

      if re4 = '1' then
        v.raddr4  := raddr4;
      end if;


      
    end if;

    -- Store most recent valid value

    -- PORT1
    if we1 = '1' then
      v.lwrite1(u2i(waddr1)) := "0";
    end if;

    if we2 = '1' then
      v.lwrite1(u2i(waddr2)) := "1";
    end if;

    -- PORT2
    if we1 = '1' then
      v.lwrite2(u2i(waddr1)) := "0";
    end if;

    if we2 = '1' then
      v.lwrite2(u2i(waddr2)) := "1";
    end if;

    -- PORT3
    if we1 = '1' then
      v.lwrite3(u2i(waddr1)) := "0";
    end if;

    if we2 = '1' then
      v.lwrite3(u2i(waddr2)) := "1";
    end if;

    -- PORT4
    if we1 = '1' then
      v.lwrite4(u2i(waddr1)) := "0";
    end if;

    if we2 = '1' then
      v.lwrite4(u2i(waddr2)) := "1";
    end if;

    
    -- PORT1
    if we1 = '1' and rdhold = '0' then
      if waddr1 = raddr1 then
        v.port1wf   := '1';
        v.holddata1 := wdata1;
      end if;
    end if;
    if we1 = '1' and rdhold = '1' then
      if waddr1 = r.raddr1 then
        v.port1wf   := '1';
        v.holddata1 := wdata1;
      end if;
    end if;
    if we2 = '1' and rdhold = '0' then
      if waddr2 = raddr1 then
        v.port1wf   := '1';
        v.holddata1 := wdata2;
      end if;
    end if;
    if we2 = '1' and rdhold = '1' then
      if waddr2 = r.raddr1 then
        v.port1wf   := '1';
        v.holddata1 := wdata2;
      end if;
    end if;

    -- PORT2
    if we1 = '1' and rdhold = '0' then
      if waddr1 = raddr2 then
        v.port2wf   := '1';
        v.holddata2 := wdata1;
      end if;
    end if;
    if we1 = '1' and rdhold = '1' then
      if waddr1 = r.raddr2 then
        v.port2wf   := '1';
        v.holddata2 := wdata1;
      end if;
    end if;
    if we2 = '1' and rdhold = '0' then
      if waddr2 = raddr2 then
        v.port2wf   := '1';
        v.holddata2 := wdata2;
      end if;
    end if;
    if we2 = '1' and rdhold = '1' then
      if waddr2 = r.raddr2 then
        v.port2wf   := '1';
        v.holddata2 := wdata2;
      end if;
    end if;

    -- PORT3
    if we1 = '1' and rdhold = '0' then
      if waddr1 = raddr3 then
        v.port3wf   := '1';
        v.holddata3 := wdata1;
      end if;
    end if;
    if we1 = '1' and rdhold = '1' then
      if waddr1 = r.raddr3 then
        v.port3wf   := '1';
        v.holddata3 := wdata1;
      end if;
    end if;
    if we2 = '1' and rdhold = '0' then
      if waddr2 = raddr3 then
        v.port3wf   := '1';
        v.holddata3 := wdata2;
      end if;
    end if;
    if we2 = '1' and rdhold = '1' then
      if waddr2 = r.raddr3 then
        v.port3wf   := '1';
        v.holddata3 := wdata2;
      end if;
    end if;

    -- PORT4
    if we1 = '1' and rdhold = '0' then
      if waddr1 = raddr4 then
        v.port4wf   := '1';
        v.holddata4 := wdata1;
      end if;
    end if;
    if we1 = '1' and rdhold = '1' then
      if waddr1 = r.raddr4 then
        v.port4wf   := '1';
        v.holddata4 := wdata1;
      end if;
    end if;
    if we2 = '1' and rdhold = '0' then
      if waddr2 = raddr4 then
        v.port4wf   := '1';
        v.holddata4 := wdata2;
      end if;
    end if;
    if we2 = '1' and rdhold = '1' then
      if waddr2 = r.raddr4 then
        v.port4wf   := '1';
        v.holddata4 := wdata2;
      end if;
    end if;

    
    rdata1v := (others => '0');
    rdzp1   := '1';
    if r.raddr1 /= "00000" or reg0write = 1 then
      rdzp1   := '0';
      rdata1v := rdata10;
      if r.lwrite1(u2i(r.raddr1)) = "1" then
        rdata1v := rdata11;
      end if;
    end if;

    rdata2v := (others => '0');
    rdzp2   := '1';
    if r.raddr2 /= "00000" or reg0write = 1 then
      rdzp2   := '0';
      rdata2v := rdata20;
      if r.lwrite2(u2i(r.raddr2)) = "1" then
        rdata2v := rdata21;
      end if;
    end if;

    rdata3v := (others => '0');
    rdzp3   := '1';
    if r.raddr3 /= "00000" or reg0write = 1 then
      rdzp3   := '0';
      rdata3v := rdata30;
      if r.lwrite3(u2i(r.raddr3)) = "1" then
        rdata3v := rdata31;
      end if;
    end if;

    rdata4v := (others => '0');
    rdzp4   := '1';
    if r.raddr4 /= "00000" or reg0write = 1 then
      rdzp4   := '0';
      rdata4v := rdata40;
      if r.lwrite4(u2i(r.raddr4)) = "1" then
        rdata4v := rdata41;
      end if;
    end if;

    forw_sel1 := '0';
    forw_sel2 := '0';
    forw_sel3 := '0';
    forw_sel4 := '0';
    if rdzp1 = '0' and r.port1wf = '1' then
      rdata1v   := r.holddata1;
      forw_sel1 := '1';
    end if;
    if rdzp2 = '0' and r.port2wf = '1' then
      rdata2v   := r.holddata2;
      forw_sel2 := '1';
    end if;
    if rdzp3 = '0' and r.port3wf = '1' then
      rdata3v   := r.holddata3;
      forw_sel3 := '1';
    end if;
    if rdzp4 = '0' and r.port4wf = '1' then
      rdata4v   := r.holddata4;
      forw_sel4 := '1';
    end if;

    if we1 = '1' and waddr1 = r.raddr1 and rdzp1 = '0' then
      rdata1v   := wdata1;
      forw_sel1 := '1';
    end if;
    if we2 = '1' and waddr2 = r.raddr1 and rdzp1 = '0' then
      rdata1v   := wdata2;
      forw_sel1 := '1';
    end if;
    if we1 = '1' and waddr1 = r.raddr2 and rdzp2 = '0' then
      rdata2v   := wdata1;
      forw_sel2 := '1';
    end if;
    if we2 = '1' and waddr2 = r.raddr2 and rdzp2 = '0' then
      rdata2v   := wdata2;
      forw_sel2 := '1';
    end if;
    if we1 = '1' and waddr1 = r.raddr3 and rdzp3 = '0' then
      rdata3v   := wdata1;
      forw_sel3 := '1';
    end if;
    if we2 = '1' and waddr2 = r.raddr3 and rdzp3 = '0' then
      rdata3v   := wdata2;
      forw_sel3 := '1';
    end if;
    if we1 = '1' and waddr1 = r.raddr4 and rdzp4 = '0' then
      rdata4v   := wdata1;
      forw_sel4 := '1';
    end if;
    if we2 = '1' and waddr2 = r.raddr4 and rdzp4 = '0' then
      rdata4v   := wdata2;
      forw_sel4 := '1';
    end if;

    
    -- Reset
    if rstn = '0' then
      v         := reg_type_rst;
    end if;


    re1_masked <= re1 and not(rdhold);
    re2_masked <= re2 and not(rdhold);
    re3_masked <= re3 and not(rdhold);
    re4_masked <= re4 and not(rdhold);

    -- Output Signals
    rdata1 <= rdata1v;
    rdata2 <= rdata2v;
    rdata3 <= rdata3v;
    rdata4 <= rdata4v;
    rin    <= v;

  end process;

  seq : process(clk, rstn)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;

  end process;


end rtl;
