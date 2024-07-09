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
-- Entity: 	various
-- File:    fifo_inferred.vhd
-- Authors: Pascal Trotta
--          Andrea Gianarro - Cobham Gaisler AB
-- Description:	Behavioural fifo generators
------------------------------------------------------------------------------

-- Note on fwft together with separate clocks:
--   With fwft=1, it will take (nsync+1) cycles for the data to come out,
--     because the read enable to the RAM is asserted only when the
--     write pointer has been synchronized over to the read domain. This is
--     to avoid read/write collisions on the RAM, and also to avoid any risk
--     of glitches on the RAM outputs causing timing violations downstream.
--   Another mode is supported, fwft=2 where the read-enable of the RAM is
--     asserted while the read-side is waiting for data. When the write
--     pointer has been synchronized over the data is instantly available
--     from the RAM saving one clock cycle. This is only 'safe' to use on
--     inferred tech (RAM in flip flops) or techs where read/write
--     collisions are not corrupting the RAM. In order to prevent the
--     glitch propagation issue, nand gates are added which need to be
--     preserved in synthesis.

library ieee;
library techmap;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use techmap.gencomp.all;
library grlib;
use grlib.config.all;
use grlib.config_types.all;
use grlib.stdlib.all;
use grlib.dftlib.trstmux;

entity generic_fifo is
  generic (
    tech  : integer := 0;   -- target technology
    abits : integer := 10;  -- fifo address bits (actual fifo depth = 2**abits)
    dbits : integer := 32;  -- fifo data width
    sepclk : integer := 1;  -- 1 = asynchrounous read/write clocks, 0 = synchronous read/write clocks
    afullwl : integer := 0; -- almost full min writes left until full (0 makes equal to full)
    aemptyrl : integer := 0; -- almost empty min reads left until empty (0 makes equal to empty)
    fwft : integer := 0;     -- 2 = FWFT minimal latency, 1 = first word fall trough mode, 0 = standard mode
    ft: integer := 0;
    custombits : integer := 1;
    rdhold : integer := 0;
    extrempty : integer := 0;
    scantest: integer := 0;
    arstr: integer := 0;
    arstw: integer := 0
  );
  port (
    rclk    : in std_logic;  -- read clock
    rrstn   : in std_logic;  -- read clock domain synchronous reset
    wrstn   : in std_logic;  -- write clock domain synchronous reset
    renable : in std_logic;  -- read enable
    rfull   : out std_logic; -- fifo full (synchronized in read clock domain)
    rempty  : out std_logic; -- fifo empty
    aempty  : out std_logic; -- fifo almost empty (depending on pempty threshold)
    rusedw  : out std_logic_vector(abits-1 downto 0);  -- fifo used words (synchronized in read clock domain)
    dataout : out std_logic_vector(dbits-1 downto 0);  -- fifo data output
    wclk    : in std_logic;  -- write clock
    write   : in std_logic;  -- write enable
    wfull   : out std_logic; -- fifo full
    afull   : out std_logic; -- fifo almost full (depending on pfull threshold)
    wempty  : out std_logic; -- fifo empty (synchronized in write clock domain)
    wusedw  : out std_logic_vector(abits-1 downto 0); -- fifo used words (synchronized in write clock domain)
    datain  : in std_logic_vector(dbits-1 downto 0); -- fifo data input
    dynsync : in std_ulogic;
    rextempty: in std_ulogic;           -- External empty signal from pipeline stage
    testin  : in std_logic_vector(TESTIN_WIDTH-1 downto 0) := testin_none;
    testrst : in std_ulogic := '0';
    error    : out std_logic_vector((((dbits+7)/8)-1)*(1-ft/4)+ft/4 downto 0); -- FT only
    errinj   : in std_logic_vector((((dbits + 7)/8)*2-1)*(1-ft/4)+(6*(ft/4)) downto 0) := (others => '0') -- FT only
    );
end;

architecture rtl_fifo of generic_fifo is

  constant fwft_minlat : boolean := (fwft=2 and syncram_2p_dest_rw_collision(tech)=0);

  -- Use rdhold for power saving in fwft mode either if it's available
  -- natively or if user requested it (avoid having to re-read to keep
  -- data). Will not affect the interface since the FWFT mode always
  -- holds the read data until it is "acked" with renable.
  constant fwft_rdhold : integer := boolean'pos(syncram_2p_readhold(tech)/=0 or rdhold/=0);

  type wr_fifo_type is record
    waddr : std_logic_vector(abits downto 0);
    waddr_gray : std_logic_vector(abits downto 0);
    waddr_ds1 : std_logic_vector(abits downto 0);
    full : std_logic;
  end record;

  type rd_fifo_type is record
    raddr : std_logic_vector(abits downto 0);
    raddr_gray : std_logic_vector(abits downto 0);
    raddr_ds1 : std_logic_vector(abits downto 0);
    empty : std_logic;
    waddr_ds1_del: std_logic_vector(abits downto 0);
    extempty: std_ulogic;
--pragma translate_off
    prev_renable: std_ulogic;
--pragma translate_on
  end record;

  signal wr_r, wr_rin : wr_fifo_type;
  signal rd_r, rd_rin : rd_fifo_type;
  signal wr_raddr_gray, rd_waddr_gray : std_logic_vector(abits downto 0);
  signal sepfwft_rden: std_ulogic;

  signal dataout_i, dataout_o, dataout_g : std_logic_vector(dbits-1 downto 0);
  signal error_i, error_o, error_g : std_logic_vector((((dbits+7)/8)-1)*(1-ft/4)+ft/4 downto 0);
  constant zero_error : std_logic_vector((((dbits+7)/8)-1)*(1-ft/4)+ft/4 downto 0) := (others => '0');

  signal wmaskempty, rmaskfull: std_ulogic;  -- mask wempty or rfull in case of recent reads/writes
                                             -- that have not yet been seen in
                                             -- other clock domain
  signal iwempty, irfull: std_ulogic;
  signal remptysel: std_ulogic;

--pragma translate_off
  signal dataout_valid: std_ulogic;
--pragma translate_on

  signal warstn, rarstn: std_ulogic;


begin

  ---------------------
  -- write clock domain
  ---------------------
  wr_comb: process(wr_r, write, wr_raddr_gray, wrstn, rd_r.raddr, rd_r.raddr_ds1, dynsync)
    variable wr_v : wr_fifo_type;
    variable v_wusedw : std_logic_vector(abits downto 0);
    variable v_raddr : std_logic_vector(abits downto 0);
  begin

    -- initialize fifo signals on write side
    wr_v := wr_r;
    wr_v.full := '0';
    afull <= '0';

    if sepclk = 1 then
      if dynsync='0' then
        v_raddr := gray_decoder(wr_raddr_gray);
      else
        v_raddr := rd_r.raddr_ds1;
      end if;
    else
      v_raddr := rd_r.raddr;
    end if;

    -- fifo full generation and compute wusedw
    -- decode read address coming from read clock domain
    v_wusedw := wr_r.waddr - v_raddr;
    wr_v.full := v_wusedw(abits);

    -- write fifo
    if write = '1' then
      wr_v.waddr := wr_r.waddr + 1;
    end if;

    if sepclk = 1 then
      wr_v.waddr_gray := gray_encoder(wr_v.waddr);
      wr_v.waddr_ds1 := wr_v.waddr;
      if dynsync='0' then wr_v.waddr_ds1 := (others => '0'); end if;
    end if;

    -- synchronous reset
    if wrstn = '0' then
      if arstw=0 then
        wr_v.waddr := (others =>'0');
        wr_v.waddr_gray := (others =>'0');
        wr_v.waddr_ds1 := (others => '0');
      end if;
      wr_v.full := '0';                 -- used combinatorially below
    end if;

    -- assign wusedw and almost full fifo output
    if notx(v_wusedw) then
      if unsigned(v_wusedw) > (2**abits-1-afullwl) then
        afull <= '1';
      end if;
    end if;

    if wr_r.waddr /= v_raddr then
      wmaskempty <= '1';
    else
      wmaskempty <= '0';
    end if;

    -- signal assignment
    wfull <= wr_v.full;
    wusedw <= v_wusedw(abits-1 downto 0);
    -- update fifo signals
    wr_rin <= wr_v;

  end process;

  wrsyncgen: if arstw=0 generate
    warstn <= '0';
    wr_sync: process(wclk)
    begin
      if rising_edge(wclk) then
        wr_r <= wr_rin;
      end if;
    end process;
  end generate;
  wrasyncgen: if arstw/=0 generate
    wtm0: trstmux
      generic map (scantest => scantest)
      port map (arsti => wrstn, testrst => testrst, testen => testin(TESTIN_WIDTH-1), arsto => warstn);
    wr_async: process(wclk,warstn)
    begin
      if warstn='0' then
        wr_r <= (waddr => (others => '0'),
                 waddr_gray => (others => '0'),
                 full => '0',
                 waddr_ds1 => (others => '0'));
      elsif rising_edge(wclk) then
        wr_r <= wr_rin;
      end if;
    end process;
  end generate;


  sync_reg: if sepclk = 1 generate
    -----------------------------------
    -- sync regs for dual clock FIFO --
    -----------------------------------
    -- transfer write address (encoded) in read clock domain
    -- transfer read address (encoded) in write clock domain
    -- transfer empty in write clock domain
    -- transfer full in read block domain
    -- Note: input d is already registered in the source clock domain
    syn_gen0: for i in 0 to abits generate  -- fifo addresses
      syncreg_inst0: syncreg generic map (tech => tech, stages => 2)
        port map(clk => rclk, d => wr_r.waddr_gray(i), q => rd_waddr_gray(i));

      syncreg_inst1: syncreg generic map (tech => tech, stages => 2)
        port map(clk => wclk, d => rd_r.raddr_gray(i), q => wr_raddr_gray(i));
    end generate;

    remptysel <= rd_r.empty when extrempty=0 else rd_r.extempty;
    syncreg_inst2: syncreg generic map (tech => tech, stages => 2)
      port map(clk => wclk, d => remptysel, q => iwempty);
    syncreg_inst3: syncreg generic map (tech => tech, stages => 2)
      port map(clk => rclk, d => wr_r.full, q => irfull);
    wempty <= iwempty and not wmaskempty;
    rfull <= irfull and not rmaskfull;
  end generate;

  no_sync_reg: if sepclk = 0 generate
    ---------------------------------------
    -- single clock FIFO logic (no sync) --
    ---------------------------------------
    wempty <= rd_r.empty and not wmaskempty;
    rfull <= wr_r.full and not rmaskfull;
  end generate;

  --------------------
  -- read clock domain
  --------------------
  rd_comb: process(rd_r, renable, rd_waddr_gray, rrstn, wr_r.waddr, wr_r.waddr_ds1, dynsync, rextempty)
    variable rd_v : rd_fifo_type;
    variable v_rusedw : std_logic_vector(abits downto 0);
    variable v_waddr : std_logic_vector(abits downto 0);
  begin

    -- initialize fifo signals on read side
    rd_v := rd_r;
    rd_v.empty := '0';
    aempty <= '0';

    if sepclk = 1 then
      if dynsync='0' then
        v_waddr := gray_decoder(rd_waddr_gray);
      else
        if fwft_minlat then
          -- need to delay 1 cycle in fwft_minlat case to match syncram_2p latency
          v_waddr := rd_r.waddr_ds1_del;
        else
          v_waddr := wr_r.waddr_ds1;
        end if;
      end if;
    else
      v_waddr := wr_r.waddr;
    end if;

    -- fifo empty generation and compute rusedw fifo output
    -- decode write address coming from write clock domain
    v_rusedw := v_waddr - rd_r.raddr;
    if conv_integer(v_rusedw) = 0 then  
      rd_v.empty := '1';
    end if;

    -- read fifo
    if renable = '1' then
      rd_v.raddr := rd_r.raddr + 1;
    end if;

    if (fwft/=0 and sepclk/=0 and not fwft_minlat) then
      rd_v.empty := '0';
      if v_waddr=rd_v.raddr then
        rd_v.empty := '1';
      end if;
    end if;

    if sepclk = 1 then
      rd_v.raddr_gray := gray_encoder(rd_v.raddr);
      rd_v.raddr_ds1 := rd_v.raddr;
      if dynsync='0' then rd_v.raddr_ds1 := (others => '0'); end if;
      rd_v.waddr_ds1_del := wr_r.waddr_ds1;
    end if;

    rd_v.extempty := rd_v.empty and rextempty;

    -- synchronous reset
    if rrstn = '0' then
      if arstr=0 then
        rd_v.raddr := (others =>'0');
        rd_v.raddr_gray := (others =>'0');
        rd_v.raddr_ds1 := (others => '0');
      end if;
      rd_v.empty := '1';  -- used combinatorially below
    end if;

    -- assign almost empty
    if notx(v_rusedw) then
      if unsigned(v_rusedw) < (aemptyrl+1) then
        aempty <= '1';
      end if;
    end if;

--pragma translate_off
    if fwft/=0 then
      if fwft_minlat or fwft=0 or sepclk=0 then
        dataout_valid <= not rd_v.empty;
      else
        dataout_valid <= not rd_r.empty;
      end if;
    else
      dataout_valid <= rd_r.prev_renable;
    end if;
    if rdhold = 0 then
      rd_v.prev_renable := renable;
    else
      rd_v.prev_renable := (rd_r.prev_renable or renable) and rrstn;
    end if;
--pragma translate_on

    -- signal assignment
    rempty <= rd_v.empty;
    rusedw <= v_rusedw(abits-1 downto 0);
    -- update fifo signals
    rd_rin <= rd_v;

    -- special case for fwft with separate clocks
    sepfwft_rden <= not rd_v.empty;
    if fwft_minlat then
      sepfwft_rden <= '1';
    end if;
    if fwft_rdhold/=0 and rd_r.empty='0' and renable='0' then
      sepfwft_rden <= '0';
    end if;
    if (fwft/=0 and sepclk/=0 and not fwft_minlat) then
      rempty <= rd_r.empty;
    end if;
    dataout_g <= (others => (not rd_v.empty));
    error_g <= (others => (not rd_v.empty));

    if v_waddr(abits-1 downto 0) /= rd_r.raddr(abits-1 downto 0) then
      rmaskfull <= '1';
    else
      rmaskfull <= '0';
    end if;
  end process;

  rdsyncgen: if arstr=0 generate
    rarstn <= '0';
    rd_sync: process(rclk)
    begin
      if rising_edge(rclk) then
        rd_r <= rd_rin;
      end if;
    end process;
  end generate;
  rdasyncgen: if arstr/=0 generate
    rtm0: trstmux
      generic map (scantest => scantest)
      port map (arsti => rrstn, testrst => testrst, testen => testin(TESTIN_WIDTH-1), arsto => rarstn);
    rd_async: process(rclk,rarstn)
    begin
      if rarstn='0' then
        rd_r <= (raddr => (others => '0'),
                 raddr_gray => (others => '0'),
                 raddr_ds1 => (others => '0'),
                 empty => '1',
                 waddr_ds1_del => (others => '0'),
                 extempty => '1'
--pragma translate_off
                 ,
                 prev_renable => '0'
--pragma translate_on
                 );
      elsif rising_edge(rclk) then
        rd_r <= rd_rin;
      end if;
    end process;
  end generate;

  -- memory instantiation
  nofwft_gen: if fwft = 0 and ft = 0 generate
    ram0 : syncram_2p generic map ( tech => tech, abits => abits, dbits => dbits, sepclk => sepclk, testen => scantest, custombits => custombits, rdhold => rdhold)
      port map (rclk => rclk, renable => renable, raddress => rd_r.raddr(abits-1 downto 0), dataout => dataout_i,
                wclk => wclk, write => write, waddress => wr_r.waddr(abits-1 downto 0), datain => datain,
                testin => testin
                );
  end generate;

  fwft_gen: if fwft /= 0 and sepclk = 0 and ft = 0 generate
    ram0 : syncram_2p generic map ( tech => tech, abits => abits, dbits => dbits, sepclk => sepclk, wrfst => 1, testen => scantest, custombits => custombits, rdhold => fwft_rdhold)
      port map (rclk => rclk, renable => '1', raddress => rd_rin.raddr(abits-1 downto 0), dataout => dataout_i,
                wclk => wclk, write => write, waddress => wr_r.waddr(abits-1 downto 0), datain => datain,
                testin => testin
                );
  end generate;

  fwftsep_gen: if fwft /= 0 and sepclk /= 0 and ft = 0 generate
    ram0 : syncram_2p generic map ( tech => tech, abits => abits, dbits => dbits, sepclk => sepclk, testen => scantest, custombits => custombits, rdhold => fwft_rdhold)
      port map (rclk => rclk, renable => sepfwft_rden, raddress => rd_rin.raddr(abits-1 downto 0), dataout => dataout_i,
                wclk => wclk, write => write, waddress => wr_r.waddr(abits-1 downto 0), datain => datain,
                testin => testin
                );
  end generate;



  gategen: if fwft_minlat generate
    dgates: for x in dbits-1 downto 0 generate
      g: grnand2 generic map (tech => tech) port map (i0 => dataout_i(x), i1 => dataout_g(x), q => dataout_o(x));
    end generate;
 --   dataout <= not dataout_o;
  end generate;

  nogategen: if not fwft_minlat generate
    dataout_o <= not dataout_i;
  end generate;

  dataout <=
--pragma translate_off
    (others => 'U') when dataout_valid='0' else
--pragma translate_on
    not dataout_o;

    error_i <= (others => '0');
    error_o <= not error_i;
  error <= zero_error
           ;

end;

