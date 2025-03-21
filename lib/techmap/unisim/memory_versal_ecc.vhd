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
-- Entity:      various
-- File:        memory_versal_ecc.vhd
-- Description: Memory generators for Xilinx RAMs with ECC
-- Note: The read operation does not correct the error in the memory array,
-- it only presents corrected data on DOUT.
-- error(0)-> Single bit error corrected.
-- error(1)-> Double bit error detected
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;

library unisim;
use UNISIM.vcomponents.all;

library techmap;
use techmap.gencomp.all;

entity versal_syncram_ecc is
  generic (
    abits  : integer :=  9;
    dbits  : integer := 32;
    sepclk : integer :=  0
  );
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (dbits -1 downto 0);
    dataout : out std_logic_vector (dbits -1 downto 0);
    enable  : in  std_ulogic;
    write   : in  std_ulogic;
    error   : out std_logic_vector (1 downto 0);
    errinj  : in  std_logic_vector (1 downto 0)
    );
end entity versal_syncram_ecc;


architecture behav of versal_syncram_ecc is

  component versal_syncram_2p_ecc is
    generic (
      abits  : integer :=  4;
      dbits  : integer := 32;
      sepclk : integer :=  0
    );
    port (
      rclk     : in  std_ulogic;
      renable  : in  std_ulogic;
      raddress : in  std_logic_vector (abits -1 downto 0);
      dataout  : out std_logic_vector (dbits -1 downto 0);
      wclk     : in  std_ulogic;
      write    : in  std_ulogic;
      waddress : in  std_logic_vector (abits -1 downto 0);
      datain   : in  std_logic_vector (dbits -1 downto 0);
      error    : out std_logic_vector (1 downto 0);
      errinj   : in  std_logic_vector (1 downto 0)
      );
  end component;

  component generic_syncram_2p
    generic (abits : integer := 8; dbits : integer := 32; sepclk : integer := 0;
             pipeline : integer := 0; rdhold : integer := 0);
    port (
      rclk : in std_ulogic;
      wclk : in std_ulogic;
      rdaddress: in std_logic_vector (abits -1 downto 0);
      wraddress: in std_logic_vector (abits -1 downto 0);
      data: in std_logic_vector (dbits -1 downto 0);
      wren : in std_ulogic;
      q: out std_logic_vector (dbits -1 downto 0);
      rden : in std_ulogic := '1'
      );
  end component;

  signal rden : std_ulogic;

begin

  a9 : if (abits <= 10) generate
    xu: versal_syncram_2p_ecc
      generic map (
        abits  => abits,
        dbits  => dbits,
        sepclk => sepclk
      )
      port map (
        rclk     => clk,
        renable  => enable,
        raddress => address,
        dataout  => dataout,
        wclk     => clk,
        write    => write,
        waddress => address,
        datain   => datain,
        error    => error,
        errinj   => errinj
      );
  end generate a9;


  a_to_high : if abits > 10 generate
    x: generic_syncram_2p generic map (abits => abits, dbits => dbits, sepclk => sepclk, pipeline => 0, rdhold => 1)
      port map (clk , clk , address(abits -1 downto 0), address(abits -1 downto 0), datain(dbits -1 downto 0), write, dataout(dbits -1 downto 0), enable);
--pragma translate_off
    err_process : process
    begin
      assert false
        report  "Address depth larger than 10 not supported for versal_syncram_ecc. A generic_syncram_2p will be inferred"
        severity warning;
      wait;
    end process;
--pragma translate_on
  end generate a_to_high;


end architecture behav;


------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;

library techmap;
use techmap.gencomp.all;

library unisim;
use UNISIM.vcomponents.all;

entity versal_syncram_2p_ecc is
  generic (
    abits  : integer :=  4;
    dbits  : integer := 32;
    sepclk : integer :=  0
  );
  port (
    rclk     : in  std_ulogic;
    renable  : in  std_ulogic;
    raddress : in  std_logic_vector (abits -1 downto 0);
    dataout  : out std_logic_vector (dbits -1 downto 0);
    wclk     : in  std_ulogic;
    write    : in  std_ulogic;
    waddress : in  std_logic_vector (abits -1 downto 0);
    datain   : in  std_logic_vector (dbits -1 downto 0);
    error    : out std_logic_vector (1 downto 0);
    errinj   : in  std_logic_vector (1 downto 0)
  );
end entity versal_syncram_2p_ecc;


architecture behav of versal_syncram_2p_ecc is

  component RAMB36E5
    generic (
      BWE_MODE_B : string := "PARITY_INTERLEAVED";
      CASCADE_ORDER_A : string := "NONE";
      CASCADE_ORDER_B : string := "NONE";
      CLOCK_DOMAINS : string := "INDEPENDENT";
      DOA_REG : integer := 1;
      DOB_REG : integer := 1;
      EN_ECC_PIPE : string := "FALSE";
      EN_ECC_READ : string := "FALSE";
      EN_ECC_WRITE : string := "FALSE";
      INITP_00 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_01 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_02 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_03 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_04 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_05 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_06 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_07 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_08 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_09 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_0A : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_0B : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_0C : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_0D : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_0E : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_0F : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_00 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_01 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_02 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_03 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_04 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_05 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_06 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_07 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_08 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_09 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_0A : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_0B : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_0C : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_0D : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_0E : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_0F : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_10 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_11 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_12 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_13 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_14 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_15 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_16 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_17 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_18 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_19 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_1A : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_1B : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_1C : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_1D : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_1E : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_1F : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_20 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_21 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_22 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_23 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_24 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_25 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_26 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_27 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_28 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_29 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_2A : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_2B : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_2C : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_2D : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_2E : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_2F : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_30 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_31 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_32 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_33 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_34 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_35 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_36 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_37 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_38 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_39 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_3A : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_3B : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_3C : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_3D : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_3E : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_3F : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_40 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_41 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_42 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_43 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_44 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_45 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_46 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_47 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_48 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_49 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_4A : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_4B : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_4C : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_4D : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_4E : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_4F : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_50 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_51 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_52 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_53 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_54 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_55 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_56 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_57 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_58 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_59 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_5A : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_5B : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_5C : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_5D : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_5E : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_5F : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_60 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_61 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_62 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_63 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_64 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_65 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_66 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_67 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_68 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_69 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_6A : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_6B : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_6C : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_6D : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_6E : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_6F : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_70 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_71 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_72 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_73 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_74 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_75 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_76 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_77 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_78 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_79 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_7A : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_7B : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_7C : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_7D : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_7E : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_7F : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INIT_FILE : string := "NONE";
      IS_ARST_A_INVERTED : bit := '0';
      IS_ARST_B_INVERTED : bit := '0';
      IS_CLKARDCLK_INVERTED : bit := '0';
      IS_CLKBWRCLK_INVERTED : bit := '0';
      IS_ENARDEN_INVERTED : bit := '0';
      IS_ENBWREN_INVERTED : bit := '0';
      IS_RSTRAMARSTRAM_INVERTED : bit := '0';
      IS_RSTRAMB_INVERTED : bit := '0';
      IS_RSTREGARSTREG_INVERTED : bit := '0';
      IS_RSTREGB_INVERTED : bit := '0';
      PR_SAVE_DATA : string := "FALSE";
      READ_WIDTH_A : integer := 72;
      READ_WIDTH_B : integer := 36;
      RSTREG_PRIORITY_A : string := "RSTREG";
      RSTREG_PRIORITY_B : string := "RSTREG";
      RST_MODE_A : string := "SYNC";
      RST_MODE_B : string := "SYNC";
      SIM_COLLISION_CHECK : string := "ALL";
      SLEEP_ASYNC : string := "FALSE";
      SRVAL_A : std_logic_vector(35 downto 0) := X"000000000";
      SRVAL_B : std_logic_vector(35 downto 0) := X"000000000";
      WRITE_MODE_A : string := "NO_CHANGE";
      WRITE_MODE_B : string := "NO_CHANGE";
      WRITE_WIDTH_A : integer := 36;
      WRITE_WIDTH_B : integer := 72
    );

    port (
      CASDOUTA : out std_logic_vector(31 downto 0);
      CASDOUTB : out std_logic_vector(31 downto 0);
      CASDOUTPA : out std_logic_vector(3 downto 0);
      CASDOUTPB : out std_logic_vector(3 downto 0);
      CASOUTDBITERR : out std_ulogic;
      CASOUTSBITERR : out std_ulogic;
      DBITERR : out std_ulogic;
      DOUTADOUT : out std_logic_vector(31 downto 0);
      DOUTBDOUT : out std_logic_vector(31 downto 0);
      DOUTPADOUTP : out std_logic_vector(3 downto 0);
      DOUTPBDOUTP : out std_logic_vector(3 downto 0);
      SBITERR : out std_ulogic;
      ADDRARDADDR : in std_logic_vector(11 downto 0);
      ADDRBWRADDR : in std_logic_vector(11 downto 0);
      ARST_A : in std_ulogic;
      ARST_B : in std_ulogic;
      CASDINA : in std_logic_vector(31 downto 0);
      CASDINB : in std_logic_vector(31 downto 0);
      CASDINPA : in std_logic_vector(3 downto 0);
      CASDINPB : in std_logic_vector(3 downto 0);
      CASDOMUXA : in std_ulogic;
      CASDOMUXB : in std_ulogic;
      CASDOMUXEN_A : in std_ulogic;
      CASDOMUXEN_B : in std_ulogic;
      CASINDBITERR : in std_ulogic;
      CASINSBITERR : in std_ulogic;
      CASOREGIMUXA : in std_ulogic;
      CASOREGIMUXB : in std_ulogic;
      CASOREGIMUXEN_A : in std_ulogic;
      CASOREGIMUXEN_B : in std_ulogic;
      CLKARDCLK : in std_ulogic;
      CLKBWRCLK : in std_ulogic;
      DINADIN : in std_logic_vector(31 downto 0);
      DINBDIN : in std_logic_vector(31 downto 0);
      DINPADINP : in std_logic_vector(3 downto 0);
      DINPBDINP : in std_logic_vector(3 downto 0);
      ECCPIPECE : in std_ulogic;
      ENARDEN : in std_ulogic;
      ENBWREN : in std_ulogic;
      INJECTDBITERR : in std_ulogic;
      INJECTSBITERR : in std_ulogic;
      REGCEAREGCE : in std_ulogic;
      REGCEB : in std_ulogic;
      RSTRAMARSTRAM : in std_ulogic;
      RSTRAMB : in std_ulogic;
      RSTREGARSTREG : in std_ulogic;
      RSTREGB : in std_ulogic;
      SLEEP : in std_ulogic;
      WEA : in std_logic_vector(3 downto 0);
      WEBWE : in std_logic_vector(8 downto 0)
    );
  end component RAMB36E5;


  component generic_syncram_2p
    generic (abits : integer := 8; dbits : integer := 32; sepclk : integer := 0;
             pipeline : integer := 0; rdhold : integer := 1);
    port (
      rclk : in std_ulogic;
      wclk : in std_ulogic;
      rdaddress: in std_logic_vector (abits -1 downto 0);
      wraddress: in std_logic_vector (abits -1 downto 0);
      data: in std_logic_vector (dbits -1 downto 0);
      wren : in std_ulogic;
      q: out std_logic_vector (dbits -1 downto 0);
      rden : in std_ulogic := '1'
      );
  end component;


  function calc_clk_type(
    sepclk  : in integer
    ) return string is
  begin
    if sepclk = 0 then
      return "COMMON";
    else
      return "INDEPENDENT";
    end if;
  end function calc_clk_type;

  signal gnd, vcc : std_logic_vector(31 downto 0);
  signal do, di : std_logic_vector(dbits+64 downto 0);
  signal addrrd, addrwr : std_logic_vector(19 downto 0);


  signal sbiterr, dbiterr : std_logic_vector (0 to ((dbits-1)/64));

  type datavect  is array (1 downto 0) of std_logic_vector (dbits+64 downto 0);
  type injvect   is array (1 downto 0) of std_logic_vector (1 downto 0);
  type errorvect is array (1 downto 0) of std_logic_vector (0 to ((dbits-1)/64));

  signal do_vect      : datavect;
  signal sbiterr_vect : errorvect;
  signal dbiterr_vect : errorvect;
  signal inj_vect     : injvect;
  signal rd_en        : std_logic_vector (1 downto 0);
  signal wr_en        : std_logic_vector (1 downto 0);
  signal sel_reg      : std_ulogic;
  signal err_mask     : std_ulogic;
  signal errorx       : std_logic_vector (1 downto 0);

begin

  gnd <= (others => '0'); vcc <= (others => '1');

  addrrd(2 downto 0)        <= (others => '0');
  addrrd(abits+2 downto 3)  <= raddress;
  addrrd(19 downto abits+3) <= (others => '0');

  addrwr(2 downto 0)        <= (others => '0');
  addrwr(abits+2 downto 3)  <= waddress;
  addrwr(19 downto abits+3) <= (others => '0');

  --RW collision is not supported so error signal is asserted by RAMB36E2
  --during a collision. Mask the error in that case.
  process (rclk) is
  begin
    if rising_edge(rclk) then
      if addrrd=addrwr and write='1' and renable ='1' then
        err_mask <='1';
      else
        err_mask <= '0';
      end if;
    end if;
  end process;


  a9 : if (abits <= 9) generate

    di(dbits-1 downto 0) <= datain;
    di(dbits +64 downto dbits) <= (others =>'0');

    dataout <=do(dbits-1 downto 0);

    error(1) <= '0' when err_mask = '1' else orv(dbiterr);
    error(0) <= '0' when err_mask = '1' else orv(sbiterr);

    x0 : for i in 0 to ((dbits-1)/64) generate

      r0 : RAMB36E5
        generic map (
          DOA_REG => 0, DOB_REG => 0,
          CLOCK_DOMAINS => calc_clk_type(sepclk),
          EN_ECC_READ => "TRUE", EN_ECC_WRITE => "TRUE",
          READ_WIDTH_A  => 72,  READ_WIDTH_B => 0,
          WRITE_WIDTH_A => 0, WRITE_WIDTH_B => 72,
          WRITE_MODE_A => "WRITE_FIRST", WRITE_MODE_B => "WRITE_FIRST",
          SIM_COLLISION_CHECK => "GENERATE_X_ONLY")
        port map (
          CLKARDCLK => rclk,
          CLKBWRCLK => wclk,

          DINADIN    => di(64*i+31 downto 64*i+0),
          DINBDIN    => di(64*i+63 downto 64*i+32),

          DOUTADOUT   => do(64*i+31 downto 64*i+0),
          DOUTBDOUT   => do(64*i+63 downto 64*i+32),
          SBITERR => sbiterr(i), DBITERR => dbiterr(i),

          ADDRARDADDR => addrrd(11 downto 0),
          ADDRBWRADDR => addrwr(11 downto 0),

          ARST_A => gnd(0), ARST_B => gnd(0),
          WEA   => gnd(3 downto 0), -- not used in SDP mode
          WEBWE => vcc(8 downto 0),

          ENARDEN => renable,
          ENBWREN => write,

          INJECTSBITERR => errinj(0), INJECTDBITERR => errinj(1),

          --unused ports
          DINPADINP  => gnd(3 downto 0),  DINPBDINP  => gnd(3 downto 0),
          DOUTPADOUTP => open,
          DOUTPBDOUTP => open,

          CASDOUTA => open,   CASDOUTB    => open,
          CASDOUTPA => open,   CASDOUTPB   => open,
          CASDINA => gnd(31 downto 0),
          CASDINB => gnd(31 downto 0),
          CASDINPA => gnd(3 downto 0),
          CASDINPB => gnd(3 downto 0),
          CASINDBITERR => gnd(0), CASINSBITERR =>gnd(0),
          ECCPIPECE => gnd(0),

          CASDOMUXA => gnd(0), CASDOMUXB => gnd(0),
          CASDOMUXEN_A => gnd(0), CASDOMUXEN_B => gnd(0),
          CASOREGIMUXA => gnd(0), CASOREGIMUXB => gnd(0),
          CASOREGIMUXEN_A => gnd(0), CASOREGIMUXEN_B => gnd(0),
          REGCEAREGCE => vcc(0),REGCEB => vcc(0),
          RSTRAMARSTRAM => gnd(0),
          RSTRAMB => gnd(0),
          RSTREGARSTREG => gnd(0),
          RSTREGB => gnd(0),
          SLEEP => gnd(0)
          );

    end generate x0;

  end generate a9;


  a10 : if (abits = 10) generate

    di(dbits-1 downto 0) <= datain;
    di(dbits +64 downto dbits) <= (others =>'0');

    rd_en(0) <= renable and (not raddress(9));
    rd_en(1) <= renable and raddress(9);

    wr_en(0)  <= write and (not waddress(9));
    wr_en(1)  <= write and waddress(9);


    inj_vect(0) <= errinj when waddress(9) = '0' else "00";
    inj_vect(1) <= errinj when waddress(9) = '1' else "00";


    process (rclk) is
    begin
      if rising_edge(rclk) then
        sel_reg <= (write and waddress(9)) or (renable and raddress(9));
      end if;
    end process;


    dataout <= do_vect(0)(dbits-1 downto 0) when sel_reg = '0' else do_vect(1)(dbits-1 downto 0);

    error    <= (others => '0') when err_mask = '1' else errorx;

    errorx(1) <= orv(dbiterr);
    errorx(0) <= orv(sbiterr);

    dbiterr <= dbiterr_vect(0) when sel_reg = '0' else dbiterr_vect(1);
    sbiterr <= sbiterr_vect(0) when sel_reg = '0' else sbiterr_vect(1);


    y0: for j in 0 to 1 generate

      x0 : for i in 0 to ((dbits-1)/64) generate

      r0 : RAMB36E5
        generic map (
          DOA_REG => 0, DOB_REG => 0,
          CLOCK_DOMAINS => calc_clk_type(sepclk),
          EN_ECC_READ => "TRUE", EN_ECC_WRITE => "TRUE",
          READ_WIDTH_A  => 72,  READ_WIDTH_B => 0,
          WRITE_WIDTH_A => 0, WRITE_WIDTH_B => 72,
          WRITE_MODE_A => "WRITE_FIRST", WRITE_MODE_B => "WRITE_FIRST",
          SIM_COLLISION_CHECK => "GENERATE_X_ONLY")
        port map (
          CLKARDCLK => rclk,
          CLKBWRCLK => wclk,

          DINADIN    => di(64*i+31 downto 64*i+0),
          DINBDIN    => di(64*i+63 downto 64*i+32),

          DOUTADOUT   => do_vect(j)(64*i+31 downto 64*i+0),
          DOUTBDOUT   => do_vect(j)(64*i+63 downto 64*i+32),

          SBITERR => sbiterr_vect(j)(i), DBITERR => dbiterr_vect(j)(i),

          ADDRARDADDR => addrrd(11 downto 0),
          ADDRBWRADDR => addrwr(11 downto 0),

          ARST_A => gnd(0), ARST_B => gnd(0),
          WEA   => gnd(3 downto 0), -- not used in SDP mode
          WEBWE => vcc(8 downto 0),

          ENARDEN => rd_en(j),
          ENBWREN => wr_en(j),

          INJECTSBITERR => inj_vect(j)(0), INJECTDBITERR => inj_vect(j)(1),

          --unused ports
          DINPADINP  => gnd(3 downto 0),  DINPBDINP  => gnd(3 downto 0),
          DOUTPADOUTP => open,
          DOUTPBDOUTP => open,

          CASDOUTA => open,   CASDOUTB    => open,
          CASDOUTPA => open,   CASDOUTPB   => open,
          CASDINA => gnd(31 downto 0),
          CASDINB => gnd(31 downto 0),
          CASDINPA => gnd(3 downto 0),
          CASDINPB => gnd(3 downto 0),
          CASINDBITERR => gnd(0), CASINSBITERR =>gnd(0),
          ECCPIPECE => gnd(0),

          CASDOMUXA => gnd(0), CASDOMUXB => gnd(0),
          CASDOMUXEN_A => gnd(0), CASDOMUXEN_B => gnd(0),
          CASOREGIMUXA => gnd(0), CASOREGIMUXB => gnd(0),
          CASOREGIMUXEN_A => gnd(0), CASOREGIMUXEN_B => gnd(0),
          REGCEAREGCE => vcc(0),REGCEB => vcc(0),
          RSTRAMARSTRAM => gnd(0),
          RSTRAMB => gnd(0),
          RSTREGARSTREG => gnd(0),
          RSTREGB => gnd(0),
          SLEEP => gnd(0)
          );

      end generate x0;

    end generate y0;

  end generate a10 ;




  a_to_high : if abits > 10 generate
    x: generic_syncram_2p generic map (abits => abits, dbits => dbits, pipeline => 0, sepclk => sepclk, rdhold => 1 )
      port map (wclk => wclk , rclk => rclk , rdaddress => raddress(abits -1 downto 0), wraddress =>  waddress(abits -1 downto 0), data => datain(dbits -1 downto 0), wren => write, q => dataout(dbits -1 downto 0), rden => renable);
--pragma translate_off

    err_process : process
    begin
      assert false
        report  "Address depth larger than 10 not supported for versal_syncram_2p_ecc. A generic_syncram_2p will be inferred"
        severity warning;
      wait;
    end process;
--pragma translate_on
  end generate a_to_high;



end architecture behav;
