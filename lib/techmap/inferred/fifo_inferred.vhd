------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015, Cobham Gaisler
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
-- Entity: 	various
-- File:	fifo_inferred.vhd
-- Author:	Cobham Gaisler AB
-- Description:	Behavioural memory generators
------------------------------------------------------------------------------


library ieee;
library techmap;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.">";
use ieee.std_logic_unsigned."<";
use techmap.gencomp.all;
library grlib;
use grlib.config.all;
use grlib.config_types.all;
use grlib.stdlib.all;

entity generic_fifo is
  generic (
    tech  : integer := 0;   -- target technology
    abits : integer := 10;  -- fifo address bits (actual fifo depth = 2**abits)
    dbits : integer := 32;  -- fifo data width
    sepclk : integer := 1;  -- 1 = asynchrounous read/write clocks, 0 = synchronous read/write clocks
    pfull : integer := 100; -- almost full threshold (max 2**abits - 3)
    pempty : integer := 10; -- almost empty threshold (min 2)
    fwft : integer := 0     -- 1 = first word fall trough mode, 0 = standard mode
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
    datain  : in std_logic_vector(dbits-1 downto 0)); -- fifo data input
end;

architecture rtl_fifo of generic_fifo is

  procedure gray_encoder(variable idata : in std_logic_vector; variable odata : out std_logic_vector) is
  begin
    for i in 0 to (idata'left)-1 loop
      odata(i) := idata(i) xor idata(i+1);
    end loop;
    odata(odata'left) := idata(idata'left);
  end gray_encoder;

  procedure gray_decoder(signal idata : in std_logic_vector; constant size : integer; variable odata : out std_logic_vector) is
    variable vdata : std_logic_vector(size downto 0);
  begin
    vdata(vdata'left) := idata(idata'left);
    for i in (idata'left)-1 downto 0 loop
      vdata(i) := idata(i) xor vdata(i+1);
    end loop;
    odata := vdata;    
  end gray_decoder;

  type wfifo_type is record
    waddr : std_logic_vector(abits downto 0);
    waddr_gray : std_logic_vector(abits downto 0);
    full : std_logic;
  end record;

  type rfifo_type is record
    raddr : std_logic_vector(abits downto 0);
    raddr_gray : std_logic_vector(abits downto 0);
    empty : std_logic;
  end record;

  signal wregs, wregsin : wfifo_type;
  signal rregs, rregsin : rfifo_type;
  signal raddr_sync_encoded, waddr_sync_encoded : std_logic_vector(abits downto 0);
  signal empty_sync, full_sync : std_logic;

begin
    
  ---------------------
  -- write clock domain
  ---------------------
  wdomain_comb: process(wregs, write, raddr_sync_encoded, wrstn)
    variable vwregs : wfifo_type;
    variable vwusedw : std_logic_vector(abits-1 downto 0);
    variable raddr_sync_decoded : std_logic_vector(abits downto 0);
  begin

    -- initialize fifo signals on write side
    vwregs := wregs;
    vwregs.full := '0';
    afull <= '0';

    -- fifo full generation and compute wusedw
    gray_decoder(raddr_sync_encoded,abits,raddr_sync_decoded); -- decode read address coming from read clock domain
    if (vwregs.waddr(abits)=raddr_sync_decoded(abits)) then  
      vwusedw := vwregs.waddr(abits-1 downto 0)-raddr_sync_decoded(abits-1 downto 0);
      if (vwusedw > (2**abits-2)) then
        vwregs.full := '1';
      end if;
    else
      vwusedw := raddr_sync_decoded(abits-1 downto 0)-vwregs.waddr(abits-1 downto 0);
      if (vwusedw < 2) then
        vwregs.full := '1';
      end if;
      vwusedw := 2**abits - vwusedw;
    end if;

    -- write fifo
    if write = '1' then
      vwregs.waddr := vwregs.waddr + 1;
    end if;
    gray_encoder(vwregs.waddr,vwregs.waddr_gray);

    -- assign wusedw and almost full fifo output
    wusedw <= vwusedw;
    if vwusedw>pfull then
      afull <= '1';
    end if;

    -- synchronous reset
    if wrstn = '0' then
      vwregs.waddr := (others =>'0');
      vwregs.waddr_gray := (others =>'0');
      vwregs.full := '0';
    end if;

    -- update fifo signals
    wregsin <= vwregs;

  end process;

  wdomain_regs: process(wclk)
  begin
    if rising_edge(wclk) then
        wregs <= wregsin;
    end if;
  end process;

  ------------
  -- sync regs
  ------------
  -- transfer write address (encoded) in read clock domain
  -- transfer read address (encoded) in write clock domain
  -- transfer empty in write clock domain
  -- transfer full in read block domain
  -- Note: input d is already registered in the source clock domain
  syn_gen0: for i in 0 to abits generate  -- fifo addresses
    syncreg_inst0: syncreg generic map (tech => tech, stages => 2)
      port map(clk => rclk, d => wregs.waddr_gray(i), q => waddr_sync_encoded(i));

    syncreg_inst1: syncreg generic map (tech => tech, stages => 2)
      port map(clk => wclk, d => rregs.raddr_gray(i), q => raddr_sync_encoded(i));
  end generate;

  syncreg_inst2: syncreg generic map (tech => tech, stages => 2)
    port map(clk => wclk, d => rregs.empty, q => empty_sync);
  syncreg_inst3: syncreg generic map (tech => tech, stages => 2)
    port map(clk => rclk, d => wregs.full, q => full_sync);
  
  -- Assign synchronized empty/full to fifo outputs
  wempty <= empty_sync;
  rfull <= full_sync;
  wfull <= wregsin.full;
  rempty <= rregsin.empty;

  --------------------
  -- read clock domain
  --------------------
  rdomain_comb: process(rregs, renable, waddr_sync_encoded, rrstn)
    variable vrregs : rfifo_type;
    variable vrusedw : std_logic_vector(abits-1 downto 0);
    variable waddr_sync_decoded : std_logic_vector(abits downto 0);
  begin
  
    -- initialize fifo signals on read side
    vrregs := rregs;
    vrregs.empty := '0';
    aempty <= '0';

    -- fifo empty generation
    gray_encoder(vrregs.raddr,vrregs.raddr_gray);
    if (vrregs.raddr_gray=waddr_sync_encoded) then  
      vrregs.empty := '1';
    end if;

    -- compute and assign rusedw fifo output
    gray_decoder(waddr_sync_encoded,abits,waddr_sync_decoded);
    if (vrregs.raddr(abits)=waddr_sync_decoded(abits)) then  
      vrusedw := waddr_sync_decoded(abits-1 downto 0)-vrregs.raddr(abits-1 downto 0);
    else
      vrusedw := (2**abits) - (vrregs.raddr(abits-1 downto 0)-waddr_sync_decoded(abits-1 downto 0));
    end if;
    rusedw <= vrusedw;

    -- assign almost empty
    if vrusedw<pempty then
      aempty <= '1';
    end if;

    -- read fifo
    if renable = '1' then
      vrregs.raddr := vrregs.raddr + 1;
    end if;

    -- synchronous reset
    if rrstn = '0' then
      vrregs.raddr := (others =>'0');
      vrregs.raddr_gray := (others =>'0');
      vrregs.empty := '1';
    end if;

    -- update fifo signals
    rregsin <= vrregs;

  end process;

  rdomain_regs: process(rclk)
  begin
    if rising_edge(rclk) then
      rregs <= rregsin;
    end if;
  end process;

  -- memory instantiation
  nofwft_gen: if fwft = 0 generate
    ram0 : syncram_2p generic map ( tech => tech, abits => abits, dbits => dbits, sepclk => sepclk)
      port map (rclk, renable, rregsin.raddr(abits-1 downto 0), dataout, wclk, write, wregsin.waddr(abits-1 downto 0), datain);
  end generate;

  fwft_gen: if fwft = 1 generate
    ram0 : syncram_2p generic map ( tech => tech, abits => abits, dbits => dbits, sepclk => sepclk)
      port map (rclk, '1', rregsin.raddr(abits-1 downto 0), dataout, wclk, write, wregs.waddr(abits-1 downto 0), datain);
  end generate;

end;
