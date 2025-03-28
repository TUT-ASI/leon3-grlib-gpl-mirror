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
-- File:        memory_versal.vhd
-- Description: Memory generators for Xilinx Versal BRAMs
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


entity versal_syncram is
  generic (
    abits : integer :=  9;
    dbits : integer := 32
  );
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (dbits -1 downto 0);
    dataout : out std_logic_vector (dbits -1 downto 0);
    enable  : in  std_ulogic;
    write   : in  std_ulogic
  );
end entity versal_syncram;


architecture behav of versal_syncram is

  component generic_syncram is
    generic (
      abits    : integer := 10;
      dbits    : integer :=  8;
      pipeline : integer :=  0;
      rdhold   : integer :=  0
    );
    port (
      clk      : in  std_ulogic;
      address  : in  std_logic_vector (abits -1 downto 0);
      datain   : in  std_logic_vector (dbits -1 downto 0);
      dataout  : out std_logic_vector (dbits -1 downto 0);
      write    : in  std_ulogic;
      enable   : in  std_ulogic := '1'
    );
  end component generic_syncram;


  component versal_syncram_2p is
    generic (
      abits  : integer :=  4;
      dbits  : integer := 32;
      sepclk : integer :=  0
    );
    port (
      rclk     : in  std_ulogic;
      renable  : in  std_ulogic;
      raddress : in  std_logic_vector (abits - 1 downto 0);
      dataout  : out std_logic_vector (dbits - 1 downto 0);
      wclk     : in  std_ulogic;
      write    : in  std_ulogic;
      waddress : in  std_logic_vector (abits - 1 downto 0);
      datain   : in  std_logic_vector (dbits - 1 downto 0)
    );
  end component versal_syncram_2p;


begin -- entity versal_syncram   architecture behav

  sr_2p : if (abits <= 12) generate

    u5: versal_syncram_2p
      generic map (
        abits,
        dbits,
        sepclk => 0
      )
      port map (
        rclk     => clk,
        renable  => enable,
        raddress => address,
        dataout  => dataout,
        wclk     => clk,
        write    => write,
        waddress => address,
        datain   => datain
      );
  end generate sr_2p;


  gsr : if (abits > 12) generate
    x: generic_syncram
      generic map (abits, dbits)
      port map (clk, address, datain, dataout, write);
-- pragma translate_off
    msg : process
    begin
      assert false
        report  "memory_versal.versal_syncram : " &
        "Address depth larger than 12 not supported for versal_syncram. " &
        "A generic_syncram will be inferred"
        severity warning;
      wait;
    end process msg;
-- pragma translate_on
  end generate gsr;

end architecture behav; -- entity versal_syncram


-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;

library unisim;
use UNISIM.vcomponents.all;

library techmap;
use techmap.gencomp.all;


entity versal_syncram_dp is
  generic (
    abits  : integer :=  4;
    dbits  : integer := 32;
    sepclk : integer :=  1
  );
  port (
    clk1     : in  std_ulogic;
    address1 : in  std_logic_vector (abits -1 downto 0);
    datain1  : in  std_logic_vector (dbits -1 downto 0);
    dataout1 : out std_logic_vector (dbits -1 downto 0);
    enable1  : in  std_ulogic;
    write1   : in  std_ulogic;
    clk2     : in  std_ulogic;
    address2 : in  std_logic_vector (abits -1 downto 0);
    datain2  : in  std_logic_vector (dbits -1 downto 0);
    dataout2 : out std_logic_vector (dbits -1 downto 0);
    enable2  : in  std_ulogic;
    write2   : in  std_ulogic
  );
end entity versal_syncram_dp;


architecture behav of versal_syncram_dp is

  component RAMB18E5
    generic (
      CASCADE_ORDER_A : string := "NONE";
      CASCADE_ORDER_B : string := "NONE";
      CLOCK_DOMAINS : string := "INDEPENDENT";
      DOA_REG : integer := 1;
      DOB_REG : integer := 1;
      INITP_00 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_01 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_02 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_03 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_04 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_05 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_06 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_07 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
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
      READ_WIDTH_A : integer := 36;
      READ_WIDTH_B : integer := 18;
      RSTREG_PRIORITY_A : string := "RSTREG";
      RSTREG_PRIORITY_B : string := "RSTREG";
      RST_MODE_A : string := "SYNC";
      RST_MODE_B : string := "SYNC";
      SIM_COLLISION_CHECK : string := "ALL";
      SLEEP_ASYNC : string := "FALSE";
      SRVAL_A : std_logic_vector(17 downto 0) := "00" & X"0000";
      SRVAL_B : std_logic_vector(17 downto 0) := "00" & X"0000";
      WRITE_MODE_A : string := "NO_CHANGE";
      WRITE_MODE_B : string := "NO_CHANGE";
      WRITE_WIDTH_A : integer := 18;
      WRITE_WIDTH_B : integer := 36
    );
    port (
      CASDOUTA : out std_logic_vector(15 downto 0);
      CASDOUTB : out std_logic_vector(15 downto 0);
      CASDOUTPA : out std_logic_vector(1 downto 0);
      CASDOUTPB : out std_logic_vector(1 downto 0);
      DOUTADOUT : out std_logic_vector(15 downto 0);
      DOUTBDOUT : out std_logic_vector(15 downto 0);
      DOUTPADOUTP : out std_logic_vector(1 downto 0);
      DOUTPBDOUTP : out std_logic_vector(1 downto 0);
      ADDRARDADDR : in std_logic_vector(10 downto 0);
      ADDRBWRADDR : in std_logic_vector(10 downto 0);
      ARST_A : in std_ulogic;
      ARST_B : in std_ulogic;
      CASDINA : in std_logic_vector(15 downto 0);
      CASDINB : in std_logic_vector(15 downto 0);
      CASDINPA : in std_logic_vector(1 downto 0);
      CASDINPB : in std_logic_vector(1 downto 0);
      CASDOMUXA : in std_ulogic;
      CASDOMUXB : in std_ulogic;
      CASDOMUXEN_A : in std_ulogic;
      CASDOMUXEN_B : in std_ulogic;
      CASOREGIMUXA : in std_ulogic;
      CASOREGIMUXB : in std_ulogic;
      CASOREGIMUXEN_A : in std_ulogic;
      CASOREGIMUXEN_B : in std_ulogic;
      CLKARDCLK : in std_ulogic;
      CLKBWRCLK : in std_ulogic;
      DINADIN : in std_logic_vector(15 downto 0);
      DINBDIN : in std_logic_vector(15 downto 0);
      DINPADINP : in std_logic_vector(1 downto 0);
      DINPBDINP : in std_logic_vector(1 downto 0);
      ENARDEN : in std_ulogic;
      ENBWREN : in std_ulogic;
      REGCEAREGCE : in std_ulogic;
      REGCEB : in std_ulogic;
      RSTRAMARSTRAM : in std_ulogic;
      RSTRAMB : in std_ulogic;
      RSTREGARSTREG : in std_ulogic;
      RSTREGB : in std_ulogic;
      SLEEP : in std_ulogic;
      WEA : in std_logic_vector(1 downto 0);
      WEBWE : in std_logic_vector(3 downto 0)
    );
  end component RAMB18E5;


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

  -- This function returns the proper generic value to use for the port widths
  -- of the XILINX primitives:
  -- RAMB18E5 : 1K * 18
  --            2K *  9
  -- RAMB36E5 : 1K * 36
  --            2K * 18
  --            4K *  9
  function calc_gwidth (
    abits  : in integer;
    use_36 : in integer
    ) return integer is
    variable dwidth : integer := 36;
  begin
    if use_36 = 0 then
      if abits <= 10 then
        dwidth := 18; -- 1K x 18
      elsif abits = 11 then
        dwidth := 9; -- 2K x 9
      end if;
    else
      --Use the B36 primitive if you would need to use 4 or more of the B18
      if abits <= 10 then
        dwidth := 36; -- 1K x 36
      elsif abits = 11 then
        dwidth := 18; -- 2K x 18
      elsif abits = 12 then
        dwidth := 9; -- 4K x 9
      end if;
    end if;
    return dwidth;
  end function calc_gwidth;

  -- This function returns the effective data width provided by the XILINX primitive
  -- after excluding the parity bits, given the generic used for the port data width
  function data_width(
    port_width : in integer
    ) return integer is
    variable dwidth : integer := 36;
  begin
    if port_width = 9 then
      dwidth := 8;
    elsif port_width = 18 then
      dwidth := 16;
    elsif port_width = 36 then
      dwidth := 32;
    end if;
    return dwidth;
  end function data_width;

  function calc_startaddrbit (
    abits  : in integer;
    use_36 : in integer
    ) return integer is
    variable startbit : integer := 2;
  begin
    if abits <= 10 then
      startbit := 1;
    elsif abits = 11 then
      startbit  := 0;
    end if;
    -- Correction for the 36 Kb RAM
    if use_36 = 1 then
      if abits = 12 then
        startbit := 0;
      else
        startbit := startbit + 1;
      end if;
    end if;
    return startbit;
  end function calc_startaddrbit;

  function calc_clk (
    sepclk : in integer := 0
    ) return string is
  begin
    if sepclk = 0 then
      return "COMMON";
    else
      return "INDEPENDENT";
    end if;
  end function calc_clk;

  constant WRITE_MODE_WRITE_FIRST_c              : string := "WRITE_FIRST"    ;
  constant SIM_COLLISION_CHECK_GENERATE_X_ONLY_c : string := "GENERATE_X_ONLY";

  signal gnd : std_logic_vector (35 downto 0);
  signal vcc : std_ulogic;

  signal do1, do2, di1, di2 : std_logic_vector (dbits+36 downto 0);

  signal addr1 : std_logic_vector (11 downto 0) := (others => '0');
  signal addr2 : std_logic_vector (11 downto 0) := (others => '0');

  subtype datav is std_logic_vector(31 downto 0);
  type datavect is array (0 to 32) of datav;

  signal din1,dout1 : datavect;
  signal din2,dout2 : datavect;

  signal write1_t : std_logic_vector ( 8 downto 0 );
  signal write2_t : std_logic_vector ( 8 downto 0 );

  constant C_GWIDTH   : integer := calc_gwidth(abits, 0);
  constant C_DWIDTH   : integer := data_width(C_GWIDTH);
  constant C_START    : integer := calc_startaddrbit(abits, 0);

  constant C_GWIDTH36 : integer := calc_gwidth(abits, 1);
  constant C_DWIDTH36 : integer := data_width(C_GWIDTH36);
  constant C_START36  : integer := calc_startaddrbit(abits, 1);


begin -- entity versal_syncram_dp   architecture behav

  gnd <= (others =>'0');
  vcc <= '1';

  dataout1 <= do1 (dbits-1 downto 0);
  dataout2 <= do2 (dbits-1 downto 0);

  di1(dbits-1 downto 0)      <= datain1;
  di1(dbits+36 downto dbits) <= (others => '0');

  di2(dbits-1 downto 0)      <= datain2;
  di2(dbits+36 downto dbits) <= (others => '0');

  write1_t <= write1 & write1 & write1 & write1 & write1 &
              write1 & write1 & write1 & write1;
  write2_t <= write2 & write2 & write2 & write2 & write2 &
              write2 & write2 & write2 & write2;

  a8 : if (abits <= 11) generate

    min4: if (dbits/C_DWIDTH < 2) generate

      addr1(abits+(C_START-1) downto C_START) <= address1;
      addr2(abits+(C_START-1) downto C_START) <= address2;

      x : for i in 0 to ((dbits-1)/C_DWIDTH) generate

        do1((C_DWIDTH*(i+1))-1 downto i*C_DWIDTH) <= dout1(i)(C_DWIDTH-1 downto 0);
        do2((C_DWIDTH*(i+1))-1 downto i*C_DWIDTH) <= dout2(i)(C_DWIDTH-1 downto 0);

        din1(i)(C_DWIDTH-1 downto 0) <= di1((C_DWIDTH*(i+1))-1 downto i*C_DWIDTH);
        din2(i)(C_DWIDTH-1 downto 0) <= di2((C_DWIDTH*(i+1))-1 downto i*C_DWIDTH);

        r0 : RAMB18E5
          generic map (
            DOA_REG             => 0,
            DOB_REG             => 0,
            CLOCK_DOMAINS       => calc_clk (sepclk),
            READ_WIDTH_A        => C_GWIDTH,
            READ_WIDTH_B        => C_GWIDTH,
            WRITE_WIDTH_A       => C_GWIDTH,
            WRITE_WIDTH_B       => C_GWIDTH,
            WRITE_MODE_A        => WRITE_MODE_WRITE_FIRST_c,
            WRITE_MODE_B        => WRITE_MODE_WRITE_FIRST_c,
            SIM_COLLISION_CHECK => SIM_COLLISION_CHECK_GENERATE_X_ONLY_c
          )
          port map (
            CLKARDCLK       => clk1,
            CLKBWRCLK       => clk2,

            DOUTADOUT       => dout1 (i) (15 downto 0),
            DOUTBDOUT       => dout2 (i) (15 downto 0),
            DOUTPADOUTP     => open,
            DOUTPBDOUTP     => open,

            DINADIN         => din1 (i) (15 downto 0),
            DINBDIN         => din2 (i) (15 downto 0),
            DINPADINP       => gnd (1 downto 0),
            DINPBDINP       => gnd (1 downto 0),

            ADDRARDADDR     => addr1 (10 downto 0),
            ADDRBWRADDR     => addr2 (10 downto 0),

            ARST_A          => gnd (0),
            ARST_B          => gnd (0),

            ENARDEN         => enable1,
            ENBWREN         => enable2,

            WEA             => write1_t (1 downto 0),
            WEBWE           => write2_t (3 downto 0),

            CASDOUTA        => open,
            CASDOUTB        => open,
            CASDOUTPA       => open,
            CASDOUTPB       => open,
            CASDINA         => gnd (15 downto 0),
            CASDINB         => gnd (15 downto 0),
            CASDINPA        => gnd ( 1 downto 0),
            CASDINPB        => gnd ( 1 downto 0),
            CASDOMUXA       => gnd (0),
            CASDOMUXB       => gnd (0),
            CASDOMUXEN_A    => gnd (0),
            CASDOMUXEN_B    => gnd (0),
            CASOREGIMUXA    => gnd (0),
            CASOREGIMUXB    => gnd (0),
            CASOREGIMUXEN_A => gnd (0),
            CASOREGIMUXEN_B => gnd (0),
            REGCEAREGCE     => vcc,
            REGCEB          => vcc,
            RSTRAMARSTRAM   => gnd (0),
            RSTRAMB         => gnd (0),
            RSTREGARSTREG   => gnd (0),
            RSTREGB         => gnd (0),
            SLEEP           => gnd (0)
          );

      end generate x;

    end generate min4;

    --Use the B36 primitive if you would need to use 2x or more of the B18

    maj4: if (dbits/C_DWIDTH >= 2) generate

      addr1(abits+(C_START36-1) downto C_START36) <= address1;
      addr2(abits+(C_START36-1) downto C_START36) <= address2;

      x : for i in 0 to ((dbits-1)/C_DWIDTH36) generate

        do1((C_DWIDTH36*(i+1))-1 downto i*C_DWIDTH36) <= dout1(i)(C_DWIDTH36-1 downto 0);
        do2((C_DWIDTH36*(i+1))-1 downto i*C_DWIDTH36) <= dout2(i)(C_DWIDTH36-1 downto 0);

        din1(i)(C_DWIDTH36-1 downto 0) <=  di1((C_DWIDTH36*(i+1))-1 downto i*C_DWIDTH36);
        din2(i)(C_DWIDTH36-1 downto 0) <=  di2((C_DWIDTH36*(i+1))-1 downto i*C_DWIDTH36);

        r0 : RAMB36E5
          generic map (
            DOA_REG             => 0,
            DOB_REG             => 0,
            CLOCK_DOMAINS       => calc_clk(sepclk),
            READ_WIDTH_A        => C_GWIDTH36,
            READ_WIDTH_B        => C_GWIDTH36,
            WRITE_WIDTH_A       => C_GWIDTH36,
            WRITE_WIDTH_B       => C_GWIDTH36,
            WRITE_MODE_A        => WRITE_MODE_WRITE_FIRST_c,
            WRITE_MODE_B        => WRITE_MODE_WRITE_FIRST_c,
            SIM_COLLISION_CHECK => SIM_COLLISION_CHECK_GENERATE_X_ONLY_c
          )
          port map (
            CLKARDCLK       => clk1,
            CLKBWRCLK       => clk2,

            DOUTADOUT       => dout1 (i),
            DOUTBDOUT       => dout2 (i),
            DOUTPADOUTP     => open,
            DOUTPBDOUTP     => open,

            DINADIN         => din1 (i),
            DINBDIN         => din2 (i),
            DINPADINP       => gnd (3 downto 0),
            DINPBDINP       => gnd (3 downto 0),

            ADDRARDADDR     => addr1 (11 downto 0),
            ADDRBWRADDR     => addr2 (11 downto 0),

            ARST_A          => gnd (0),
            ARST_B          => gnd (0),

            ENARDEN         => enable1,
            ENBWREN         => enable2,

            WEA             => write1_t (3 downto 0),
            WEBWE           => write2_t (8 downto 0),

            CASDOUTA        => open,
            CASDOUTB        => open,
            CASDOUTPA       => open,
            CASDOUTPB       => open,
            CASDINA         => gnd (31 downto 0),
            CASDINB         => gnd (31 downto 0),
            CASDINPA        => gnd ( 3 downto 0),
            CASDINPB        => gnd ( 3 downto 0),
            CASINDBITERR    => gnd (0),
            CASINSBITERR    => gnd (0) ,
            ECCPIPECE       => gnd (0),
            INJECTDBITERR   => gnd (0),
            INJECTSBITERR   => gnd (0),
            CASDOMUXA       => gnd (0),
            CASDOMUXB       => gnd (0),
            CASDOMUXEN_A    => gnd (0),
            CASDOMUXEN_B    => gnd (0),
            CASOREGIMUXA    => gnd (0),
            CASOREGIMUXB    => gnd (0),
            CASOREGIMUXEN_A => gnd (0),
            CASOREGIMUXEN_B => gnd (0),
            REGCEAREGCE     => vcc,
            REGCEB          => vcc,
            RSTRAMARSTRAM   => gnd (0),
            RSTRAMB         => gnd (0),
            RSTREGARSTREG   => gnd (0),
            RSTREGB         => gnd (0),
            SLEEP           => gnd (0)
          );

      end generate x;

    end generate maj4;

  end generate a8;


  a12 : if (abits = 12) generate

    -- For this case, only the 36 kb RAM can be used, as 18 kB only supports up
    -- to 11 bits of address. The RAM is built by cascading blocks of 4K x 9

    addr1 (abits+(C_START36-1) downto C_START36) <= address1;
    addr2 (abits+(C_START36-1) downto C_START36) <= address2;

    x : for i in 0 to ((dbits-1)/C_DWIDTH36) generate

      do1((C_DWIDTH36*(i+1))-1 downto i*C_DWIDTH36) <= dout1(i)(C_DWIDTH36-1 downto 0);
      do2((C_DWIDTH36*(i+1))-1 downto i*C_DWIDTH36) <= dout2(i)(C_DWIDTH36-1 downto 0);

      din1(i)(C_DWIDTH36-1 downto 0) <= di1((C_DWIDTH36*(i+1))-1 downto i*C_DWIDTH36);
      din2(i)(C_DWIDTH36-1 downto 0) <= di2((C_DWIDTH36*(i+1))-1 downto i*C_DWIDTH36);

      r0 : RAMB36E5
        generic map (
          DOA_REG             => 0,
          DOB_REG             => 0,
          CLOCK_DOMAINS       => calc_clk (sepclk),
          READ_WIDTH_A        => C_GWIDTH36,
          READ_WIDTH_B        => C_GWIDTH36,
          WRITE_WIDTH_A       => C_GWIDTH36,
          WRITE_WIDTH_B       => C_GWIDTH36,
          WRITE_MODE_A        => WRITE_MODE_WRITE_FIRST_c,
          WRITE_MODE_B        => WRITE_MODE_WRITE_FIRST_c,
          SIM_COLLISION_CHECK => SIM_COLLISION_CHECK_GENERATE_X_ONLY_c
        )
        port map (
          CLKARDCLK       => clk1,
          CLKBWRCLK       => clk2,

          DOUTADOUT       => dout1 (i),
          DOUTBDOUT       => dout2 (i),
          DOUTPADOUTP     => open,
          DOUTPBDOUTP     => open,

          DINADIN         => din1 (i),
          DINBDIN         => din2 (i),
          DINPADINP       => gnd (3 downto 0),
          DINPBDINP       => gnd (3 downto 0),

          ADDRARDADDR     => addr1 (11 downto 0),
          ADDRBWRADDR     => addr2 (11 downto 0),

          ARST_A          => gnd (0),
          ARST_B          => gnd (0),

          ENARDEN         => enable1,
          ENBWREN         => enable2,

          WEA             => write1_t (3 downto 0),
          WEBWE           => write2_t (8 downto 0),

          CASDOUTA        => open,
          CASDOUTB        => open,
          CASDOUTPA       => open,
          CASDOUTPB       => open,
          CASDINA         => gnd (31 downto 0),
          CASDINB         => gnd (31 downto 0),
          CASDINPA        => gnd ( 3 downto 0),
          CASDINPB        => gnd ( 3 downto 0),
          CASINDBITERR    => gnd (0),
          CASINSBITERR    => gnd (0),
          ECCPIPECE       => gnd (0),
          INJECTDBITERR   => gnd (0),
          INJECTSBITERR   => gnd (0),
          CASDOMUXA       => gnd (0),
          CASDOMUXB       => gnd (0),
          CASDOMUXEN_A    => gnd (0),
          CASDOMUXEN_B    => gnd (0),
          CASOREGIMUXA    => gnd (0),
          CASOREGIMUXB    => gnd (0),
          CASOREGIMUXEN_A => gnd (0),
          CASOREGIMUXEN_B => gnd (0),
          REGCEAREGCE     => vcc,
          REGCEB          => vcc,
          RSTRAMARSTRAM   => gnd (0),
          RSTRAMB         => gnd (0),
          RSTREGARSTREG   => gnd (0),
          RSTREGB         => gnd (0),
          SLEEP           => gnd (0)
        );

    end generate x;

  end generate a12;

-- pragma translate_off
  abits_to_high : if abits > 12 generate
    msg : process
    begin
      assert false
        report  "memory_versal.versal_syncram_dp : " &
        "Address depth larger than 12 not supported for versal_syncram_dp"
        severity failure;
      wait;
    end process msg;
  end generate abits_to_high;
-- pragma translate_on

end architecture behav; -- entity versal_syncram_dp


-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;

library unisim;
use UNISIM.vcomponents.all;

library techmap;
use techmap.gencomp.all;


entity versal_syncram_2p is
  generic (
    abits  : integer := 6;
    dbits  : integer := 8;
    sepclk : integer := 0
  );
  port (
    rclk     : in  std_ulogic;
    renable  : in  std_ulogic;
    raddress : in  std_logic_vector (abits-1 downto 0);
    dataout  : out std_logic_vector (dbits-1 downto 0);
    wclk     : in  std_ulogic;
    write    : in  std_ulogic;
    waddress : in  std_logic_vector (abits-1 downto 0);
    datain   : in  std_logic_vector (dbits-1 downto 0)
  );
end entity versal_syncram_2p;


architecture behav of versal_syncram_2p is

  component RAMB18E5
    generic (
      CASCADE_ORDER_A : string := "NONE";
      CASCADE_ORDER_B : string := "NONE";
      CLOCK_DOMAINS : string := "INDEPENDENT";
      DOA_REG : integer := 1;
      DOB_REG : integer := 1;
      INITP_00 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_01 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_02 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_03 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_04 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_05 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_06 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_07 : std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000000";
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
      READ_WIDTH_A : integer := 36;
      READ_WIDTH_B : integer := 18;
      RSTREG_PRIORITY_A : string := "RSTREG";
      RSTREG_PRIORITY_B : string := "RSTREG";
      RST_MODE_A : string := "SYNC";
      RST_MODE_B : string := "SYNC";
      SIM_COLLISION_CHECK : string := "ALL";
      SLEEP_ASYNC : string := "FALSE";
      SRVAL_A : std_logic_vector(17 downto 0) := "00" & X"0000";
      SRVAL_B : std_logic_vector(17 downto 0) := "00" & X"0000";
      WRITE_MODE_A : string := "NO_CHANGE";
      WRITE_MODE_B : string := "NO_CHANGE";
      WRITE_WIDTH_A : integer := 18;
      WRITE_WIDTH_B : integer := 36
    );
    port (
      CASDOUTA : out std_logic_vector(15 downto 0);
      CASDOUTB : out std_logic_vector(15 downto 0);
      CASDOUTPA : out std_logic_vector(1 downto 0);
      CASDOUTPB : out std_logic_vector(1 downto 0);
      DOUTADOUT : out std_logic_vector(15 downto 0);
      DOUTBDOUT : out std_logic_vector(15 downto 0);
      DOUTPADOUTP : out std_logic_vector(1 downto 0);
      DOUTPBDOUTP : out std_logic_vector(1 downto 0);
      ADDRARDADDR : in std_logic_vector(10 downto 0);
      ADDRBWRADDR : in std_logic_vector(10 downto 0);
      ARST_A : in std_ulogic;
      ARST_B : in std_ulogic;
      CASDINA : in std_logic_vector(15 downto 0);
      CASDINB : in std_logic_vector(15 downto 0);
      CASDINPA : in std_logic_vector(1 downto 0);
      CASDINPB : in std_logic_vector(1 downto 0);
      CASDOMUXA : in std_ulogic;
      CASDOMUXB : in std_ulogic;
      CASDOMUXEN_A : in std_ulogic;
      CASDOMUXEN_B : in std_ulogic;
      CASOREGIMUXA : in std_ulogic;
      CASOREGIMUXB : in std_ulogic;
      CASOREGIMUXEN_A : in std_ulogic;
      CASOREGIMUXEN_B : in std_ulogic;
      CLKARDCLK : in std_ulogic;
      CLKBWRCLK : in std_ulogic;
      DINADIN : in std_logic_vector(15 downto 0);
      DINBDIN : in std_logic_vector(15 downto 0);
      DINPADINP : in std_logic_vector(1 downto 0);
      DINPBDINP : in std_logic_vector(1 downto 0);
      ENARDEN : in std_ulogic;
      ENBWREN : in std_ulogic;
      REGCEAREGCE : in std_ulogic;
      REGCEB : in std_ulogic;
      RSTRAMARSTRAM : in std_ulogic;
      RSTRAMB : in std_ulogic;
      RSTREGARSTREG : in std_ulogic;
      RSTREGB : in std_ulogic;
      SLEEP : in std_ulogic;
      WEA : in std_logic_vector(1 downto 0);
      WEBWE : in std_logic_vector(3 downto 0)
    );
  end component RAMB18E5;


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
    generic (
      abits    : integer := 8;
      dbits    : integer := 32;
      sepclk   : integer := 0;
      pipeline : integer := 0;
      rdhold   : integer := 0
    );
    port (
      rclk      : in  std_ulogic;
      wclk      : in  std_ulogic;
      rdaddress : in  std_logic_vector (abits -1 downto 0);
      wraddress : in  std_logic_vector (abits -1 downto 0);
      data      : in  std_logic_vector (dbits -1 downto 0);
      wren      : in  std_ulogic;
      q         : out std_logic_vector (dbits -1 downto 0);
      rden      : in  std_ulogic := '1'
      );
  end component;

  component versal_syncram_dp is
    generic (
      abits  : integer := 10;
      dbits  : integer :=  8;
      sepclk : integer :=  0
    );
    port (
      clk1     : in  std_ulogic;
      address1 : in  std_logic_vector (abits -1 downto 0);
      datain1  : in  std_logic_vector (dbits -1 downto 0);
      dataout1 : out std_logic_vector (dbits -1 downto 0);
      enable1  : in  std_ulogic;
      write1   : in  std_ulogic;
      clk2     : in  std_ulogic;
      address2 : in  std_logic_vector (abits -1 downto 0);
      datain2  : in  std_logic_vector (dbits -1 downto 0);
      dataout2 : out std_logic_vector (dbits -1 downto 0);
      enable2  : in  std_ulogic;
      write2   : in  std_ulogic
    );
  end component versal_syncram_dp;


  function calc_clk (
    sepclk : in integer := 0
    ) return string is
  begin
    if sepclk = 0 then
      return "COMMON";
    else
      return "INDEPENDENT";
    end if;
  end function calc_clk;


  constant WRITE_MODE_WRITE_FIRST_c              : string := "WRITE_FIRST"    ;
  constant SIM_COLLISION_CHECK_GENERATE_X_ONLY_c : string := "GENERATE_X_ONLY";

  signal gnd              : std_logic_vector (35 downto 0);
  signal vcc              : std_ulogic;

  signal write2, renable2 : std_ulogic;
  signal datain2          : std_logic_vector (dbits - 1 downto 0);

  signal do, di           : std_logic_vector (dbits + 72 downto 0);
  signal addrrd           : std_logic_vector (11 downto 0) := (others => '0');
  signal addrwr           : std_logic_vector (11 downto 0) := (others => '0');

  subtype datav is std_logic_vector(71 downto 0);
  type datavect is array (0 to 32) of datav;

  signal din,dout         : datavect;

  signal write_t          : std_logic_vector (8 downto 0);


begin -- entity versal_syncram_2p   architecture behav

  gnd <= (others => '0');
  vcc <= '1';

  RAMB : if (abits < 10) generate

    dataout                   <= do(dbits-1 downto 0);

    di(dbits-1 downto 0)      <= datain;
    di(dbits+36 downto dbits) <= (others => '0');

    write_t <= write & write & write & write & write &
               write & write & write & write;

    B18: if dbits <= 36 generate

      -- A single 18 kb block RAM can be used doubling the data width to 36 bits (SDP memory: 512 x 36)

      addrrd(abits + 1 downto 2) <= raddress;
      addrwr(abits + 1 downto 2) <= waddress;

      do(35 downto 0)     <= dout(0)(35 downto 0);
      din(0)(35 downto 0) <= di(35 downto 0);

      r0 : RAMB18E5
        generic map (
          DOA_REG             =>  0,
          DOB_REG             =>  0,
          CLOCK_DOMAINS       => calc_clk (sepclk),
          READ_WIDTH_A        => 36,
          READ_WIDTH_B        =>  0,
          WRITE_WIDTH_A       =>  0,
          WRITE_WIDTH_B       => 36,
          WRITE_MODE_A        => WRITE_MODE_WRITE_FIRST_c,
          WRITE_MODE_B        => WRITE_MODE_WRITE_FIRST_c,
          SIM_COLLISION_CHECK => SIM_COLLISION_CHECK_GENERATE_X_ONLY_c
        )
        port map (
          CLKARDCLK       => rclk,
          CLKBWRCLK       => wclk,

          DOUTADOUT       => dout(0)(15 downto  0),
          DOUTBDOUT       => dout(0)(31 downto 16),
          DOUTPADOUTP     => dout(0)(33 downto 32),
          DOUTPBDOUTP     => dout(0)(35 downto 34),

          DINADIN         => din(0)(15 downto  0),
          DINBDIN         => din(0)(31 downto 16),
          DINPADINP       => din(0)(33 downto 32),
          DINPBDINP       => din(0)(35 downto 34),

          ADDRARDADDR     => addrrd(10 downto 0),
          ADDRBWRADDR     => addrwr(10 downto 0),

          ARST_A          => gnd(0),
          ARST_B          => gnd(0),

          ENARDEN         => renable,
          ENBWREN         => write,

          WEA             => gnd (1 downto 0),
          WEBWE           => write_t (3 downto 0),

          --unused ports
          CASDOUTA        => open,
          CASDOUTB        => open,
          CASDOUTPA       => open,
          CASDOUTPB       => open,
          CASDINA         => gnd (15 downto 0),
          CASDINB         => gnd (15 downto 0),
          CASDINPA        => gnd ( 1 downto 0),
          CASDINPB        => gnd ( 1 downto 0),
          CASDOMUXA       => gnd (0),
          CASDOMUXB       => gnd (0),
          CASDOMUXEN_A    => gnd (0),
          CASDOMUXEN_B    => gnd (0),
          CASOREGIMUXA    => gnd (0),
          CASOREGIMUXB    => gnd (0),
          CASOREGIMUXEN_A => gnd (0),
          CASOREGIMUXEN_B => gnd (0),
          REGCEAREGCE     => vcc,
          REGCEB          => vcc,
          RSTRAMARSTRAM   => gnd (0),
          RSTRAMB         => gnd (0),
          RSTREGARSTREG   => gnd (0),
          RSTREGB         => gnd (0),
          SLEEP           => gnd (0)
        );

    end generate B18;

    B36: if dbits > 36 generate

      -- Use multiple 36 kb RAMs in SDP mode, thus doubling the data width (512 x 72)

      addrrd(abits + 2 downto 3) <= raddress;
      addrwr(abits + 2 downto 3) <= waddress;

      x : for i in 0 to ((dbits - 1) / 72) generate

        do((72*(i+1))-1 downto i*72) <= dout(i)(71 downto 0);
        din(i)(71 downto 0) <=  di((72*(i+1))-1 downto i*72);

        r0 : RAMB36E5
          generic map (
            DOA_REG             =>  0,
            DOB_REG             =>  0,
            CLOCK_DOMAINS       => calc_clk (sepclk),
            READ_WIDTH_A        => 72,
            READ_WIDTH_B        =>  0,
            WRITE_WIDTH_A       =>  0,
            WRITE_WIDTH_B       => 72,
            WRITE_MODE_A        => WRITE_MODE_WRITE_FIRST_c,
            WRITE_MODE_B        => WRITE_MODE_WRITE_FIRST_c,
            SIM_COLLISION_CHECK => SIM_COLLISION_CHECK_GENERATE_X_ONLY_c
          )
          port map (
            CLKARDCLK       => rclk,
            CLKBWRCLK       => wclk,

            DOUTADOUT       => dout(i)(31 downto  0),
            DOUTBDOUT       => dout(i)(63 downto 32),
            DOUTPADOUTP     => dout(i)(67 downto 64),
            DOUTPBDOUTP     => dout(i)(71 downto 68),

            DINADIN         => din(i)(31 downto  0),
            DINBDIN         => din(i)(63 downto 32),
            DINPADINP       => din(i)(67 downto 64),
            DINPBDINP       => din(i)(71 downto 68),

            ADDRARDADDR     => addrrd(11 downto 0),
            ADDRBWRADDR     => addrwr(11 downto 0),

            ARST_A          => gnd (0),
            ARST_B          => gnd (0),

            ENARDEN         => renable,
            ENBWREN         => write,

            WEA             => gnd (3 downto 0),
            WEBWE           => write_t (8 downto 0),

            --unused ports
            CASDOUTA        => open,
            CASDOUTB        => open,
            CASDOUTPA       => open,
            CASDOUTPB       => open,
            CASDINA         => gnd (31 downto 0),
            CASDINB         => gnd (31 downto 0),
            CASDINPA        => gnd ( 3 downto 0),
            CASDINPB        => gnd ( 3 downto 0),
            CASINDBITERR    => gnd (0),
            CASINSBITERR    => gnd (0),
            ECCPIPECE       => gnd (0),
            INJECTDBITERR   => gnd (0),
            INJECTSBITERR   => gnd (0),
            CASDOMUXA       => gnd (0),
            CASDOMUXB       => gnd (0),
            CASDOMUXEN_A    => gnd (0),
            CASDOMUXEN_B    => gnd (0),
            CASOREGIMUXA    => gnd (0),
            CASOREGIMUXB    => gnd (0),
            CASOREGIMUXEN_A => gnd (0),
            CASOREGIMUXEN_B => gnd (0),
            REGCEAREGCE     => vcc,
            REGCEB          => vcc,
            RSTRAMARSTRAM   => gnd (0),
            RSTRAMB         => gnd (0),
            RSTREGARSTREG   => gnd (0),
            RSTREGB         => gnd (0),
            SLEEP           => gnd (0)
          );

      end generate x;
    end generate B36;

  end generate RAMB;

  sr_dp : if abits >= 10 and abits <= 12 generate

    write2   <= '0';
    renable2 <= renable;
    datain2  <= (others => '0');

    x0 : versal_syncram_dp
      generic map (
        abits  => abits,
        dbits  => dbits,
        sepclk => sepclk
      )
      port map (
        clk1     => wclk,
        address1 => waddress,
        datain1  => datain,
        dataout1 => open,
        enable1  => write,
        write1   => write,
        clk2     => rclk,
        address2 => raddress,
        datain2  => datain2,
        dataout2 => dataout,
        enable2  => renable2,
        write2   => write2
      );

  end generate sr_dp;

  a13 : if abits > 12 generate
    x0 : generic_syncram_2p
      generic map (abits, dbits, sepclk)
      port map (rclk, wclk, raddress, waddress, datain, write, dataout, renable);
-- pragma translate_off
    x : process
    begin
      assert false
        report  "Address depth larger than 12 not supported for versal_syncram_2p. A generic_syncram_2p will be inferred"
        severity warning;
      wait;
    end process;
-- pragma translate_on
  end generate;

end architecture behav; -- entity versal_syncram_2p


-------------------------------------------------------------------------------
-- 64-bit syncronous 1-port ram with 32-bit write strobes
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;

library unisim;
use UNISIM.vcomponents.all;

library techmap;
use techmap.gencomp.all;


entity versal_syncram64 is
  generic (
    abits : integer := 9
  );
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (63 downto 0);
    dataout : out std_logic_vector (63 downto 0);
    enable  : in  std_logic_vector ( 1 downto 0);
    write   : in  std_logic_vector ( 1 downto 0)
  );
end entity versal_syncram64;


architecture behav of versal_syncram64 is

  component versal_syncram is
    generic (
      abits : integer :=  9;
      dbits : integer := 32
    );
    port (
      clk     : in  std_ulogic;
      address : in  std_logic_vector (abits -1 downto 0);
      datain  : in  std_logic_vector (dbits -1 downto 0);
      dataout : out std_logic_vector (dbits -1 downto 0);
      enable  : in  std_ulogic;
      write   : in  std_ulogic
    );
  end component versal_syncram;


begin -- entity versal_syncram64  architecture behav

  x1 : versal_syncram
    generic map (
      abits => abits,
      dbits => 32
    )
    port map (
      clk     => clk,
      address => address,
      datain  => datain  (63 downto 32),
      dataout => dataout (63 downto 32),
      enable  => enable (1),
      write   => write (1)
    );

  x2 : versal_syncram
    generic map (
      abits => abits,
      dbits => 32
    )
    port map (
      clk     => clk,
      address => address,
      datain  => datain  (31 downto 0),
      dataout => dataout (31 downto 0),
      enable  => enable (0),
      write   => write (0)
    );


end architecture behav; -- entity versal_syncram64


-------------------------------------------------------------------------------
-- 128-bit syncronous 1-port ram with 32-bit write strobes
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity versal_syncram128 is
  generic (
    abits : integer := 9
  );
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (127 downto 0);
    dataout : out std_logic_vector (127 downto 0);
    enable  : in  std_logic_vector (  3 downto 0);
    write   : in  std_logic_vector (  3 downto 0)
  );
end entity versal_syncram128;


architecture behav of versal_syncram128 is

  component versal_syncram64 is
    generic (
      abits : integer := 9
    );
    port (
      clk     : in  std_ulogic;
      address : in  std_logic_vector (abits -1 downto 0);
      datain  : in  std_logic_vector (63 downto 0);
      dataout : out std_logic_vector (63 downto 0);
      enable  : in  std_logic_vector ( 1 downto 0);
      write   : in  std_logic_vector ( 1 downto 0)
    );
  end component versal_syncram64;


begin -- entity versal_syncram128  architecture behav

  x0 : versal_syncram64
    generic map (
      abits => abits
    )
    port map (
      clk     => clk,
      address => address,
      datain  => datain  (127 downto 64),
      dataout => dataout (127 downto 64),
      enable  => enable  (  3 downto  2),
      write   => write   (  3 downto  2)
    );

  x1 : versal_syncram64
    generic map (
      abits => abits
    )
    port map (
      clk     => clk,
      address => address,
      datain  => datain  (63 downto 0),
      dataout => dataout (63 downto 0),
      enable  => enable  ( 1 downto 0),
      write   => write   ( 1 downto 0)
    );


end architecture behav; -- entity versal_syncram128


-------------------------------------------------------------------------------
-- 128-bit syncronous 1-port ram with 8-bit write strobes
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity versal_syncram128bw is
  generic (
    abits : integer := 9
  );
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (127 downto 0);
    dataout : out std_logic_vector (127 downto 0);
    enable  : in  std_logic_vector ( 15 downto 0);
    write   : in  std_logic_vector ( 15 downto 0)
  );
end entity versal_syncram128bw;


architecture behav of versal_syncram128bw is

  component versal_syncram is
    generic (
      abits : integer :=  9;
      dbits : integer := 32
    );
    port (
      clk     : in  std_ulogic;
      address : in  std_logic_vector (abits -1 downto 0);
      datain  : in  std_logic_vector (dbits -1 downto 0);
      dataout : out std_logic_vector (dbits -1 downto 0);
      enable  : in  std_ulogic;
      write   : in  std_ulogic
    );
  end component versal_syncram;


begin -- entity versal_syncram128bw   architecture behav

  x0 : for i in 0 to 15 generate

    x2 : versal_syncram
      generic map
      ( abits => abits,
        dbits => 8
      )
      port map (
        clk     => clk,
        address => address,
        datain  => datain  (i*8+7 downto i*8),
        dataout => dataout (i*8+7 downto i*8),
        enable  => enable  (i),
        write   => write   (i)
      );

  end generate x0;


end architecture behav; -- entity versal_syncram128bw
