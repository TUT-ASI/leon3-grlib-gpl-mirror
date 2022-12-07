------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity:      dfi_phy_sim_fr
-- File:        dfi_phy_sim_fr.vhd
-- Author:      Magnus Hjorth - Cobham Gaisler
-- Description: DDR2/3 generic DFI phy simulation model with 1:2 / 1:4 ratio
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dfi_phy_sim_fr is
  generic (
    freqratio               : integer range 1 to 4 := 1;
    -- Generics to dfi_phy_sim PHY model
    ddrtype     : integer range 2 to 3 := 2;
    dfi_lowfirst : integer range 0 to 1 := 1;
    dfi_addr_width          : integer := 13;
    dfi_bank_width          : integer := 3;
    dfi_cs_width            : integer := 1;
    dfi_data_width          : integer := 64;
    dfi_data_en_width       : integer := 1;
    dfi_rdata_valid_width   : integer := 1;
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
    dfi_address            : in    std_logic_vector(freqratio*dfi_addr_width-1 downto 0);
    dfi_bank               : in    std_logic_vector(freqratio*dfi_bank_width-1 downto 0);
    dfi_cas_n              : in    std_logic_vector(freqratio-1 downto 0);
    dfi_cke                : in    std_logic_vector(freqratio*dfi_cs_width-1 downto 0);
    dfi_cs_n               : in    std_logic_vector(freqratio*dfi_cs_width-1 downto 0);
    dfi_odt                : in    std_logic_vector(freqratio*dfi_cs_width-1 downto 0);
    dfi_ras_n              : in    std_logic_vector(freqratio-1 downto 0);
    dfi_reset_n            : in    std_logic_vector(freqratio*dfi_cs_width-1 downto 0);
    dfi_we_n               : in    std_logic_vector(freqratio-1 downto 0);
    --DFI write data interface
    dfi_wrdata             : in    std_logic_vector(freqratio*dfi_data_width-1 downto 0);
    dfi_wrdata_en          : in    std_logic_vector(freqratio*dfi_data_en_width-1 downto 0);
    dfi_wrdata_mask        : in    std_logic_vector(freqratio*(dfi_data_width/8)-1 downto 0);
    --DFI read data interface
    dfi_rddata_en          : in    std_logic_vector(freqratio*dfi_data_en_width-1 downto 0);
    dfi_rddata             : out   std_logic_vector(freqratio*dfi_data_width-1 downto 0);
    dfi_rddata_dnv         : out   std_logic_vector(freqratio*(dfi_data_width/8)-1 downto 0);  --LPDDR2 specific
    dfi_rddata_valid       : out   std_logic_vector(freqratio*dfi_rdata_valid_width-1 downto 0);
    --DFI update interface
    dfi_ctrlupd_req        : in    std_logic;
    dfi_ctrlupd_ack        : out   std_logic;
    dfi_phyupd_req         : out   std_logic;
    dfi_phyupd_type        : out   std_logic_vector(1 downto 0);
    dfi_phyupd_ack         : in    std_logic;
    --DFI status interface
    dfi_data_byte_disable  : in    std_logic_vector((dfi_data_width/16)-1 downto 0);
    dfi_dram_clk_disable   : in    std_logic_vector(dfi_cs_width-1 downto 0);
    dfi_freq_ratio         : in    std_logic_vector(1 downto 0);
    dfi_init_complete      : out   std_logic;
    dfi_init_start         : in    std_logic;
    --DDR2/3 ports
    ddr_ck                 : out   std_logic_vector(dfi_cs_width-1 downto 0);
    ddr_ckn                : out   std_logic_vector(dfi_cs_width-1 downto 0);
    ddr_cke                : out   std_logic_vector(dfi_cs_width-1 downto 0);
    ddr_csn                : out   std_logic_vector(dfi_cs_width-1 downto 0);
    ddr_odt                : out   std_logic_vector(dfi_cs_width-1 downto 0);
    ddr_rasn               : out   std_ulogic;
    ddr_casn               : out   std_ulogic;
    ddr_wen                : out   std_ulogic;
    ddr_dm                 : out   std_logic_vector((dfi_data_width/2)/8-1 downto 0);
    ddr_ba                 : out   std_logic_vector(dfi_bank_width-1 downto 0);
    ddr_a                  : out   std_logic_vector(dfi_addr_width-1 downto 0);
    ddr_resetn             : out   std_logic_vector(dfi_cs_width-1 downto 0);  --DDR3 specific
    ddr_dq                 : inout std_logic_vector((dfi_data_width/2)-1 downto 0);
    ddr_dqs                : inout std_logic_vector((dfi_data_width/2)/8-1 downto 0);
    ddr_dqsn               : inout std_logic_vector((dfi_data_width/2)/8-1 downto 0)
    );
end;

architecture sim of dfi_phy_sim_fr is

  signal clkper : time := 10 ns;

  signal phy_dfi_clk : std_ulogic;

  --DFI control
  signal phy_dfi_address            : std_logic_vector(dfi_addr_width-1 downto 0);
  signal phy_dfi_bank               : std_logic_vector(dfi_bank_width-1 downto 0);
  signal phy_dfi_cas_n              : std_ulogic;
  signal phy_dfi_cke                : std_logic_vector(dfi_cs_width-1 downto 0);
  signal phy_dfi_cs_n               : std_logic_vector(dfi_cs_width-1 downto 0);
  signal phy_dfi_odt                : std_logic_vector(dfi_cs_width-1 downto 0);
  signal phy_dfi_ras_n              : std_ulogic;
  signal phy_dfi_reset_n            : std_logic_vector(dfi_cs_width-1 downto 0);
  signal phy_dfi_we_n               : std_ulogic;
  --DFI write data interface
  signal phy_dfi_wrdata             : std_logic_vector(dfi_data_width-1 downto 0);
  signal phy_dfi_wrdata_en          : std_logic_vector(dfi_data_en_width-1 downto 0);
  signal phy_dfi_wrdata_mask        : std_logic_vector((dfi_data_width/8)-1 downto 0);
  --DFI read data interface
  signal phy_dfi_rddata_en          : std_logic_vector(dfi_data_en_width-1 downto 0);
  signal phy_dfi_rddata             : std_logic_vector(dfi_data_width-1 downto 0);
  signal phy_dfi_rddata_dnv         : std_logic_vector((dfi_data_width/8)-1 downto 0);  --LPDDR2 specific
  signal phy_dfi_rddata_valid       : std_logic_vector(dfi_rdata_valid_width-1 downto 0);

  signal phase: integer range 0 to freqratio-1 := 0;

begin

  -- Wrapped PHY running at 1:1 ratio
  phy0: entity work.dfi_phy_sim
    generic map (
      ddrtype                 => ddrtype,
      dfi_lowfirst            => dfi_lowfirst,
      dfi_addr_width          => dfi_addr_width,
      dfi_bank_width          => dfi_bank_width,
      dfi_cs_width            => dfi_cs_width,
      dfi_data_width          => dfi_data_width,
      dfi_data_en_width       => dfi_data_en_width,
      dfi_rdata_valid_width   => dfi_rdata_valid_width,
      tctrl_delay             => tctrl_delay,
      tphy_wrdata             => tphy_wrdata,
      tphy_wrlat              => tphy_wrlat,
      trddata_en              => trddata_en
      )
    port map (
      phy_resetn             => phy_resetn,
      dfi_clk                => phy_dfi_clk,
      dfi_address            => phy_dfi_address,
      dfi_bank               => phy_dfi_bank,
      dfi_cas_n              => phy_dfi_cas_n,
      dfi_cke                => phy_dfi_cke,
      dfi_cs_n               => phy_dfi_cs_n,
      dfi_odt                => phy_dfi_odt,
      dfi_ras_n              => phy_dfi_ras_n,
      dfi_reset_n            => phy_dfi_reset_n,
      dfi_we_n               => phy_dfi_we_n,
      dfi_wrdata             => phy_dfi_wrdata,
      dfi_wrdata_en          => phy_dfi_wrdata_en,
      dfi_wrdata_mask        => phy_dfi_wrdata_mask,
      dfi_rddata_en          => phy_dfi_rddata_en,
      dfi_rddata             => phy_dfi_rddata,
      dfi_rddata_dnv         => phy_dfi_rddata_dnv,
      dfi_rddata_valid       => phy_dfi_rddata_valid,
      dfi_ctrlupd_req        => dfi_ctrlupd_req,
      dfi_ctrlupd_ack        => dfi_ctrlupd_ack,
      dfi_phyupd_req         => dfi_phyupd_req,
      dfi_phyupd_type        => dfi_phyupd_type,
      dfi_phyupd_ack         => dfi_phyupd_ack,
      dfi_data_byte_disable  => dfi_data_byte_disable,
      dfi_dram_clk_disable   => dfi_dram_clk_disable,
      dfi_init_complete      => dfi_init_complete,
      dfi_init_start         => dfi_init_start,
      ddr_ck                 => ddr_ck,
      ddr_ckn                => ddr_ckn,
      ddr_cke                => ddr_cke,
      ddr_csn                => ddr_csn,
      ddr_odt                => ddr_odt,
      ddr_rasn               => ddr_rasn,
      ddr_casn               => ddr_casn,
      ddr_wen                => ddr_wen,
      ddr_dm                 => ddr_dm,
      ddr_ba                 => ddr_ba,
      ddr_a                  => ddr_a,
      ddr_resetn             => ddr_resetn,
      ddr_dq                 => ddr_dq,
      ddr_dqs                => ddr_dqs,
      ddr_dqsn               => ddr_dqsn
      );

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

  phyclkgen: process
  begin
    phase <= freqratio-1;
    phy_dfi_clk <= '0';
    if phy_resetn='0' then
      wait until phy_resetn /= '0';
    end if;
    if phy_resetn/='0' then
      wait until rising_edge(dfi_clk);
    end if;
    phy_dfi_clk <= '1';
    phase <= 0;
    if phy_resetn/='0' then
      wait for (clkper / (2*freqratio));
    end if;
    phy_dfi_clk <= '0';
    for x in 1 to freqratio-1 loop
      if phy_resetn/='0' then
        wait for (clkper / (2*freqratio));
      end if;
      phy_dfi_clk <= '1';
      phase <= x;
      if phy_resetn/='0' then
        wait for (clkper / (2*freqratio));
      end if;
      phy_dfi_clk <= '0';
    end loop;
  end process;

  frproc: process(phy_dfi_clk)
    variable rdphase: integer range 0 to freqratio-1 := 0;
    type rddata_slot is record
      data: std_logic_vector(dfi_data_width-1 downto 0);
      valid: std_ulogic;
    end record;
    type rddata_slot_array is array(0 to freqratio-1) of rddata_slot;
    variable rddata: rddata_slot_array;
    variable next_rddata: std_logic_vector(freqratio*dfi_data_width-1 downto 0);
    variable next_rddata_valid: std_logic_vector(freqratio*dfi_rdata_valid_width-1 downto 0) := (others => '0');
    variable pushrddata: boolean;
  begin
    if rising_edge(phy_dfi_clk) then
      rddata(rdphase).valid := phy_dfi_rddata_valid(0);
      rddata(rdphase).data := phy_dfi_rddata;
      if rddata(rdphase).valid='1' then
        rdphase := (rdphase + 1) mod freqratio;
      end if;
      -- if all slots are valid or if we're on last phase and valid is low, push to output
      pushrddata := true;
      for x in rddata'range loop
        if rddata(x).valid /= '1' then pushrddata:=false; end if;
      end loop;
      if phase=freqratio-1 and phy_dfi_rddata_valid(0)='0' and next_rddata_valid=(next_rddata_valid'range => '0') then
        pushrddata := true;
      end if;
      if pushrddata then
        for x in 0 to freqratio-1 loop
          next_rddata((x+1)*dfi_data_width-1 downto x*dfi_data_width) :=
            rddata(x).data;
          next_rddata_valid(x*dfi_rdata_valid_width) := rddata(x).valid;
          rddata(x).valid := '0';
        end loop;
      end if;
      if phase=freqratio-1 then
        dfi_rddata <= next_rddata;
        dfi_rddata_valid <= next_rddata_valid;
        next_rddata_valid := (others => '0');
      end if;
    end if;
  end process;

  phy_dfi_address     <= dfi_address    ((phase+1)*dfi_addr_width-1     downto phase*dfi_addr_width);
  phy_dfi_bank        <= dfi_bank       ((phase+1)*dfi_bank_width-1     downto phase*dfi_bank_width);
  phy_dfi_cas_n       <= dfi_cas_n      (phase);
  phy_dfi_cke         <= dfi_cke        ((phase+1)*dfi_cs_width-1       downto phase*dfi_cs_width);
  phy_dfi_cs_n        <= dfi_cs_n       ((phase+1)*dfi_cs_width-1       downto phase*dfi_cs_width);
  phy_dfi_odt         <= dfi_odt        ((phase+1)*dfi_cs_width-1       downto phase*dfi_cs_width);
  phy_dfi_ras_n       <= dfi_ras_n      (phase);
  phy_dfi_reset_n     <= dfi_reset_n    ((phase+1)*dfi_cs_width-1       downto phase*dfi_cs_width);
  phy_dfi_we_n        <= dfi_we_n       (phase);

  phy_dfi_wrdata      <= dfi_wrdata     ((phase+1)*dfi_data_width-1     downto phase*dfi_data_width);
  phy_dfi_wrdata_en   <= dfi_wrdata_en  ((phase+1)*dfi_data_en_width-1  downto phase*dfi_data_en_width);
  phy_dfi_wrdata_mask <= dfi_wrdata_mask((phase+1)*(dfi_data_width/8)-1 downto phase*(dfi_data_width/8));

  phy_dfi_rddata_en   <= dfi_rddata_en  ((phase+1)*dfi_data_en_width-1  downto phase*dfi_data_en_width);

  dfi_rddata_dnv <= (others => '0');
end;
