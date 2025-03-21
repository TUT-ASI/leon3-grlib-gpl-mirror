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
-- Entity:      dfi_phy_sim
-- File:        dfi_phy_sim.vhd
-- Author:      Magnus Hjorth, Cobham Gaisler
-- Description: DDR2/3 generic DFI phy simulation model
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.all;

entity dfi_phy_sim is
  generic (
    -- DDR type
    ddrtype     : integer range 2 to 3 := 2;
    -- For DDR vectors, if low or high half is taken first
    -- 1=low half first, 0=high half first
    dfi_lowfirst : integer range 0 to 1 := 1;
    -- DFI widths
    dfi_addr_width          : integer := 13;
    dfi_bank_width          : integer := 3;
    dfi_cs_width            : integer := 1;
    dfi_data_width          : integer := 64;
    dfi_data_en_width       : integer := 1;
    dfi_rdata_valid_width   : integer := 1;
    -- DFI timings
    -- Note: timings relative to CAS latency are given as 100+T
    tctrl_delay : integer := 2;
    tphy_wrdata : integer := 1;
    tphy_wrlat  : integer := 100-1;
    trddata_en  : integer := 100-2
    );
  port (
    -- Master reset for PHY
    phy_resetn : in std_ulogic;
    -- DFI clock
    dfi_clk    : in std_ulogic;
    --DFI control
    dfi_address            : in    std_logic_vector(dfi_addr_width-1 downto 0);
    dfi_bank               : in    std_logic_vector(dfi_bank_width-1 downto 0);
    dfi_cas_n              : in    std_ulogic;
    dfi_cke                : in    std_logic_vector(dfi_cs_width-1 downto 0);
    dfi_cs_n               : in    std_logic_vector(dfi_cs_width-1 downto 0);
    dfi_odt                : in    std_logic_vector(dfi_cs_width-1 downto 0);
    dfi_ras_n              : in    std_ulogic;
    dfi_reset_n            : in    std_logic_vector(dfi_cs_width-1 downto 0);
    dfi_we_n               : in    std_ulogic;
    --DFI write data interface
    dfi_wrdata             : in    std_logic_vector(dfi_data_width-1 downto 0);
    dfi_wrdata_en          : in    std_logic_vector(dfi_data_en_width-1 downto 0);
    dfi_wrdata_mask        : in    std_logic_vector((dfi_data_width/8)-1 downto 0);
    --DFI read data interface
    dfi_rddata_en          : in    std_logic_vector(dfi_data_en_width-1 downto 0);
    dfi_rddata             : out   std_logic_vector(dfi_data_width-1 downto 0);
    dfi_rddata_dnv         : out   std_logic_vector((dfi_data_width/8)-1 downto 0);  --LPDDR2 specific
    dfi_rddata_valid       : out   std_logic_vector(dfi_rdata_valid_width-1 downto 0);
    --DFI update interface
    dfi_ctrlupd_req        : in    std_ulogic;
    dfi_ctrlupd_ack        : out   std_ulogic;
    dfi_phyupd_req         : out   std_ulogic;
    dfi_phyupd_type        : out   std_logic_vector(1 downto 0);
    dfi_phyupd_ack         : in    std_ulogic;
    --DFI status interface
    dfi_data_byte_disable  : in    std_logic_vector((dfi_data_width/16)-1 downto 0);
    dfi_dram_clk_disable   : in    std_logic_vector(dfi_cs_width-1 downto 0);
    dfi_init_complete      : out   std_ulogic;
    dfi_init_start         : in    std_ulogic;
    --DDR2/3 ports
    ddr_ck                 : out   std_logic_vector(dfi_cs_width-1 downto 0);
    ddr_ckn                : out   std_logic_vector(dfi_cs_width-1 downto 0);
    ddr_cke                : out   std_logic_vector(dfi_cs_width-1 downto 0);
    ddr_csn                : out   std_logic_vector(dfi_cs_width-1 downto 0);
    ddr_odt                : out   std_logic_vector(dfi_cs_width-1 downto 0);
    ddr_rasn               : out   std_logic;
    ddr_casn               : out   std_logic;
    ddr_wen                : out   std_logic;
    ddr_dm                 : out   std_logic_vector((dfi_data_width/2)/8-1 downto 0);
    ddr_ba                 : out   std_logic_vector(dfi_bank_width-1 downto 0);
    ddr_a                  : out   std_logic_vector(dfi_addr_width-1 downto 0);
    ddr_resetn             : out   std_logic_vector(dfi_cs_width-1 downto 0);  --DDR3 specific
    ddr_dq                 : inout std_logic_vector((dfi_data_width/2)-1 downto 0);
    ddr_dqs                : inout std_logic_vector((dfi_data_width/2)/8-1 downto 0);
    ddr_dqsn               : inout std_logic_vector((dfi_data_width/2)/8-1 downto 0)
    );
end;

architecture sim of dfi_phy_sim is

  signal clkper: time := 10 ns;
  signal clk90: std_ulogic;

  type ctrl_type is record
    address: std_logic_vector(dfi_addr_width-1 downto 0);
    bank: std_logic_vector(dfi_bank_width-1 downto 0);
    cas_n: std_ulogic;
    cke: std_logic_vector(dfi_cs_width-1 downto 0);
    cs_n: std_logic_vector(dfi_cs_width-1 downto 0);
    odt: std_logic_vector(dfi_cs_width-1 downto 0);
    ras_n: std_ulogic;
    reset_n: std_logic_vector(dfi_cs_width-1 downto 0);
    we_n: std_ulogic;
    wrdata: std_logic_vector(dfi_data_width-1 downto 0);
    wrdata_en: std_ulogic;
    wrdata_mask: std_logic_vector((dfi_data_width/8)-1 downto 0);
    rddata_en: std_ulogic;
  end record;
  type ctrl_array_type is array(0 to 17) of ctrl_type;
  signal ctrl_pipe: ctrl_array_type;
  signal pwdqsctrl: ctrl_type;

  constant wdqsidx: integer := tctrl_delay-tphy_wrlat+100;
  constant pwdqsidx: integer range 0 to 17 := tctrl_delay-tphy_wrlat+99;
  constant wdqidx:  integer := tctrl_delay-tphy_wrlat+100-tphy_wrdata;

  signal dqs_gate_enable: std_logic_vector((dfi_data_width/2)/8-1 downto 0);
  signal dqs_gated: std_logic_vector((dfi_data_width/2)/8-1 downto 0);
  signal dqs_gated_del: std_logic_vector((dfi_data_width/2)/8-1 downto 0);
  signal dqs_gate_open1, dqs_gate_open2: std_ulogic;

  constant rgidx: integer := tctrl_delay-trddata_en+100;

  type fifo_byte_type is array(0 to 15) of std_logic_vector(15 downto 0);
  type fifo_data_type is array((dfi_data_width/2)/8-1 downto 0) of fifo_byte_type;
  type fifo_ptr_type is array((dfi_data_width/2)/8-1 downto 0) of integer range 0 to 15;
  signal fifo_data: fifo_data_type;
  signal fifo_wptr: fifo_ptr_type;
  signal fifo_rptr: integer range 0 to 15;
  signal wptr_resync: std_ulogic;

begin

  ----------------------------------------------------------------------------
  -- Internal
  ----------------------------------------------------------------------------
  clkmeas: process
    variable t1,t2: time;
  begin
    clkper <= 10 ns;
    wait until rising_edge(dfi_clk);
    t2 := now;
    loop
      wait until rising_edge(dfi_clk);
      t1 := t2;
      t2 := now;
      clkper <= t2-t1;
    end loop;
  end process;

  clk90 <= dfi_clk after clkper / 4;

  ----------------------------------------------------------------------------
  -- DDR clock
  ----------------------------------------------------------------------------
  ckproc: process(dfi_clk)
  begin
    if rising_edge(dfi_clk) then
      ddr_ck  <= (others => '0');
      ddr_ckn <= (others => '1');
    elsif falling_edge(dfi_clk) then
      ddr_ck  <= not dfi_dram_clk_disable;
      ddr_ckn <=     dfi_dram_clk_disable;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- Control signals
  ----------------------------------------------------------------------------
  ctrlpipe_proc: process(dfi_clk,phy_resetn)
  begin
    if rising_edge(dfi_clk) then
      ctrl_pipe(1 to ctrl_pipe'high) <= ctrl_pipe(0 to ctrl_pipe'high-1);
    end if;
    if phy_resetn='0' then
      ctrl_pipe(1 to ctrl_pipe'high) <= (others => (
        address     => (others => '0'),
        bank        => (others => '0'),
        cas_n       => '1',
        cke         => (others => '0'),
        cs_n        => (others => '1'),
        odt         => (others => '0'),
        ras_n       => '1',
        reset_n     => (others => '0'),
        we_n        => '1',
        wrdata_en   => '0',
        wrdata      => (others => '0'),
        wrdata_mask => (others => '0'),
        rddata_en   => '0'
        ) );
    end if;
  end process;
  ctrl_pipe(0) <= (
    address     => dfi_address,
    bank        => dfi_bank,
    cas_n       => dfi_cas_n,
    cke         => dfi_cke,
    cs_n        => dfi_cs_n,
    odt         => dfi_odt,
    ras_n       => dfi_ras_n,
    reset_n     => dfi_reset_n,
    we_n        => dfi_we_n,
    wrdata_en   => dfi_wrdata_en(0),
    wrdata      => dfi_wrdata,
    wrdata_mask => dfi_wrdata_mask,
    rddata_en   => dfi_rddata_en(0)
    );

  ddr_cke     <= ctrl_pipe(tctrl_delay).cke;
  ddr_csn     <= ctrl_pipe(tctrl_delay).cs_n;
  ddr_odt     <= ctrl_pipe(tctrl_delay).odt;
  ddr_rasn    <= ctrl_pipe(tctrl_delay).ras_n;
  ddr_casn    <= ctrl_pipe(tctrl_delay).cas_n;
  ddr_wen     <= ctrl_pipe(tctrl_delay).we_n;
  ddr_ba      <= ctrl_pipe(tctrl_delay).bank;
  ddr_a       <= ctrl_pipe(tctrl_delay).address;
  ddr_resetn  <= ctrl_pipe(tctrl_delay).reset_n;

  ----------------------------------------------------------------------------
  -- Write data
  ----------------------------------------------------------------------------
  pwdqsctrl <= ctrl_pipe(pwdqsidx);
  drvdqs: process(dfi_clk,phy_resetn)
    variable vdrv: integer range 0 to 2;
  begin
    vdrv := 2;
    if phy_resetn='0' then
      null;
    elsif rising_edge(dfi_clk) then
      if pwdqsctrl.wrdata_en='1' or
         ctrl_pipe(wdqsidx).wrdata_en='1' then
        vdrv := 0;
      end if;
    elsif falling_edge(dfi_clk) then
      if ctrl_pipe(wdqsidx).wrdata_en='1' then
        vdrv := 1;
      end if;
      if ddrtype=3 and pwdqsctrl.wrdata_en='1' then
        vdrv := 1;
      end if;
    end if;
    case vdrv is
      when 0 =>
        ddr_dqs  <= (others => '0');
        ddr_dqsn <= (others => '1');
      when 1 =>
        ddr_dqs  <= (others => '1');
        ddr_dqsn <= (others => '0');
      when 2 =>
        ddr_dqs  <= (others => 'Z');
        ddr_dqsn <= (others => 'Z');
    end case;
  end process;

  drvdata: process(clk90,phy_resetn)
    variable vdrv: integer range 0 to 2;
  begin
    vdrv := 2;
    if phy_resetn='0' then
      null;
    elsif rising_edge(clk90) then
      if ctrl_pipe(wdqsidx).wrdata_en='1' then
        vdrv := 0;
      end if;
    elsif falling_edge(clk90) then
      if ctrl_pipe(wdqsidx).wrdata_en='1' then
        vdrv := 1;
      end if;
    end if;
    if dfi_lowfirst=0 and vdrv<2 then
      vdrv := 1-vdrv;
    end if;
    case vdrv is
      when 0 =>
        ddr_dq <= ctrl_pipe(wdqidx).wrdata((dfi_data_width/2)-1 downto 0);
        ddr_dm <= ctrl_pipe(wdqidx).wrdata_mask((dfi_data_width/2)/8-1 downto 0);
      when 1 =>
        ddr_dq <= ctrl_pipe(wdqidx).wrdata(dfi_data_width-1 downto dfi_data_width/2);
        ddr_dm <= ctrl_pipe(wdqidx).wrdata_mask(dfi_data_width/8-1 downto (dfi_data_width/2)/8);
      when 2 =>
        ddr_dq <= (others => 'Z');
        ddr_dm <= (others => 'X');
    end case;
  end process;

  ----------------------------------------------------------------------------
  -- Read data
  ----------------------------------------------------------------------------
  -- The simulation model opens the gate at the middle of the preamble
  -- assuming ideal timing of the DDR memory. Can handle at most +/- 0.5 cycle
  -- deviation from ideal timing.

  -- assert not is_x(dqs_gated) report "X on DQS after gating" severity warning;

  dqs_gated <= ddr_dqs and dqs_gate_enable;

  gateopen1proc: process(dfi_clk,phy_resetn)
  begin
    if phy_resetn='0' then
      dqs_gate_open1 <= '0';
      dqs_gate_open2 <= '0';
    elsif rising_edge(dfi_clk) then
      dqs_gate_open1 <= ctrl_pipe(rgidx-1).rddata_en and ctrl_pipe(rgidx-2).rddata_en;
    elsif falling_edge(dfi_clk) then
      dqs_gate_open2 <= dqs_gate_open1;
    end if;
  end process;

  perbyte: for x in 0 to (dfi_data_width/2)/8-1 generate

    dqs_gated_del(x) <= dqs_gated(x) after clkper/4;

    gateenproc: process(phy_resetn,dqs_gated(x),dqs_gate_open1,dqs_gate_open2)
    begin
      if phy_resetn='0' then
        dqs_gate_enable(x) <= '0';
      elsif dqs_gate_open1='1' or dqs_gate_open2='1' then
        dqs_gate_enable(x) <= '1';
      elsif falling_edge(dqs_gated(x)) then
        dqs_gate_enable(x) <= '0';
      end if;
    end process;

    fifowproc: process(dqs_gated_del(x),phy_resetn,wptr_resync)
    begin
      if phy_resetn='0' then
        fifo_wptr(x) <= 0;
        fifo_data(x) <= (others => (others => '0'));
      elsif wptr_resync='1' then
        fifo_wptr(x) <= fifo_rptr;
      elsif rising_edge(dqs_gated_del(x)) then
        if dfi_lowfirst=1 then
          fifo_data(x)(fifo_wptr(x))(7 downto 0) <= ddr_dq(x*8+7 downto x*8);
        else
          fifo_data(x)(fifo_wptr(x))(15 downto 8) <= ddr_dq(x*8+7 downto x*8);
        end if;
      elsif falling_edge(dqs_gated_del(x)) then
        if dfi_lowfirst=1 then
          fifo_data(x)(fifo_wptr(x))(15 downto 8) <= ddr_dq(x*8+7 downto x*8);
        else
          fifo_data(x)(fifo_wptr(x))(7 downto 0) <= ddr_dq(x*8+7 downto x*8);
        end if;
        fifo_wptr(x) <= (fifo_wptr(x)+1) mod 16;
      end if;
    end process;
  end generate;

  fiforproc: process(dfi_clk,phy_resetn)
    variable vempty: boolean;
  begin
    if phy_resetn='0' then
      dfi_rddata_valid <= (others => '0');
      dfi_rddata <= (others => '0');
      fifo_rptr <= 0;
      wptr_resync <= '0';
    elsif rising_edge(dfi_clk) then
      wptr_resync <= '0';
      if ctrl_pipe(rgidx+3).rddata_en='1' then
        dfi_rddata_valid <= (others => '1');
        for x in 0 to (dfi_data_width/2)/8-1 loop
          dfi_rddata(dfi_data_width/2+x*8+7 downto dfi_data_width/2+x*8) <= fifo_data(x)(fifo_rptr)(15 downto 8);
          dfi_rddata(x*8+7 downto x*8) <= fifo_data(x)(fifo_rptr)(7 downto 0);
        end loop;
        fifo_rptr <= (fifo_rptr + 1) mod 16;
      else
        dfi_rddata_valid <= (others => '0');
        vempty := true;
        for x in ctrl_pipe'range loop
          if ctrl_pipe(x).rddata_en='1' then vempty := false; end if;
        end loop;
        if vempty then
          wptr_resync <= '1';
        end if;
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- Other
  ----------------------------------------------------------------------------
  dfi_rddata_dnv <= (others => '0');    -- Only applicable for LPDDR2
  dfi_ctrlupd_ack <= '0';
  dfi_phyupd_req <= '0';
  dfi_phyupd_type <= "00";
  dfi_init_complete <= '1';

end;
