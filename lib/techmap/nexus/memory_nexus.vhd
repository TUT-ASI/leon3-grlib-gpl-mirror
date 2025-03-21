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
-- Entity: 	various
-- File:	memory_nexus.vhd
-- Author:	CAES Gaisler AB
-- Description:	Memory generators for Lattice Nexus family rams
------------------------------------------------------------------------------


-- parametrisable sync ram generator using EBR blocks


------------------- NEXUS SYNCRAM -------------------
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;

library techmap;
use techmap.gencomp.all;

--pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on

entity nexus_syncram is
  generic (abits : integer := 9; dbits : integer := 32
           );
  port (
    clk     : in std_ulogic;
    address : in std_logic_vector((abits -1) downto 0);
    datain  : in std_logic_vector((dbits -1) downto 0);
    dataout : out std_logic_vector((dbits -1) downto 0);
    enable  : in std_ulogic;
    write   : in std_ulogic);
end;

architecture behav of nexus_syncram is

  component generic_syncram
    generic ( abits : integer := 10; dbits : integer := 8; pipeline : integer := 0; rdhold : integer := 0 );
    port (
      clk      : in std_ulogic;
      address  : in std_logic_vector((abits -1) downto 0);
      datain   : in std_logic_vector((dbits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      write    : in std_ulogic;
      enable   : in std_ulogic := '1');
  end component;

  component SP16K
    GENERIC (
      DATA_WIDTH : String := "X18";
      OUTREG : String := "BYPASSED";
      RESETMODE : String := "SYNC";
      GSR : String := "ENABLED";
      INITVAL_00 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_01 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_02 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_03 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_04 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_05 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_06 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_07 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_08 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_09 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_10 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_11 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_12 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_13 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_14 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_15 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_16 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_17 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_18 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_19 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_20 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_21 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_22 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_23 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_24 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_25 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_26 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_27 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_28 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_29 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_30 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_31 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_32 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_33 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_34 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_35 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_36 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_37 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_38 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_39 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      CSDECODE : String := "000";
      ASYNC_RST_RELEASE : String := "SYNC";
      INIT_DATA : String := "STATIC");
    port(
      DI : IN std_logic_vector(17 downto 0);
      AD : IN std_logic_vector(13 downto 0);
      CLK : IN std_logic;
      CE : IN std_logic;
      WE : IN std_logic;
      CS : IN std_logic_vector(2 downto 0);
      RST : IN std_logic;
      DO : OUT std_logic_vector(17 downto 0));
    end component;

  -- This function, given abits bits, returns the maximum data width that can
  -- be used in the LATTICE primitive.
  function calc_max_dwidth(
    abits  : in integer
    ) return integer is
    variable dwidth : integer := 36;
  begin

    if abits <= 10 then
      dwidth := 18;
    elsif abits = 11 then
      dwidth := 9;
    elsif abits = 12 then
      dwidth := 4;
    elsif abits = 13 then
      dwidth := 2;
    elsif abits >= 14 then
      dwidth := 1;
    end if;

    return dwidth;

  end function calc_max_dwidth;

  -- This function returns the least multiple of max_width
  -- that can accommodate the input data
  function calc_min_mult(
    data_width : in integer;
    max_width  : in integer
    ) return integer is
    variable min_mult : integer := 32;
  begin

    min_mult := (data_width + max_width - 1) / max_width;
    return min_mult;
  end function calc_min_mult;

  -- This function returns the low starting bit for the address input used by
  -- the Lattice component
  function calc_startaddrbit(
    abits  : in integer
    ) return integer is
    variable startbit : integer := 5;
  begin

    if abits <= 10 then
      startbit := 4;
    elsif abits = 11 then
      startbit  := 3;
    elsif abits = 12 then
      startbit  := 2;
    elsif abits = 13 then
      startbit  := 1;
    else
      startbit  := 0;
    end if;

    return startbit;

  end function calc_startaddrbit;

  -- This function returns the mask as string to be applied to CSDECODE
  -- when abits > 14, to implement memory cascade
  function get_csmask(
    j_index     : in integer
    ) return string is
    variable csmask : string (3 downto 1) := "111";
  begin
    if (j_index = 0) then
      csmask := "111";-- cs = 000
    elsif (j_index = 1) then
      csmask := "110";-- cs = 001
    elsif (j_index = 2) then
      csmask := "101";-- cs = 010
    elsif (j_index = 3) then
      csmask := "100";-- cs = 011
    elsif (j_index = 4) then
      csmask := "011";-- cs = 100
    elsif (j_index = 5) then
      csmask := "010";-- cs = 101
    elsif (j_index = 6) then
      csmask := "001";-- cs = 110
    elsif (j_index = 7) then
      csmask := "000";-- cs = 111
    end if;
    return csmask;
  end function get_csmask;

  -- This function returns the max value that j can get in the looping for
  -- cascading memories. If abits <= 14, then there's no need for cascading =>
  -- j_max = 0
  function get_jmax(
    abits     : in integer;
    addr_w    : in integer
    ) return integer is
    variable jmax : integer := 0;
  begin
    if abits <= 14 then
      jmax := 0;
    else
      jmax := 2**(abits-addr_w) - 1;
    end if;
    return jmax;
  end function;

  constant PORT_WIDTH : integer := 18;-- data port width of an instance
  constant ADDR_WIDTH : integer := 14;-- address port width of an instance

  signal addr    : std_logic_vector(ADDR_WIDTH-1 downto 0);

  signal clk_en     : std_ulogic;
  signal wenable    : std_ulogic;
  signal cs, cs_sel_out : std_logic_vector (2 downto 0);

  constant MAX_WIDTH  : integer := calc_max_dwidth(abits);-- max data width
                                                          -- given abits
  constant MIN_MULT   : integer := calc_min_mult(dbits, MAX_WIDTH);
  constant ADDR_START : integer := calc_startaddrbit(abits);--get the starting
                                                            --bit for address

  -- "data signal-flow":
  -- datain -> di   -> din -> DI
  -- DO     -> dout_cascade -> dout -> do  -> dataout
  -- no need for din_cascade as CS and CSDECODE will take care of it
  signal do,di  : std_logic_vector(dbits-1 downto 0);
  subtype datav is std_logic_vector(PORT_WIDTH-1 downto 0);
  type datavect is array (0 to MIN_MULT-1) of datav;
  signal din,dout : datavect;
  -- data_cascade should be 2**(abits-addr'LENGTH) long, but this would imply
  -- more complicate code to handle all the 8 cases of the mux
  type data_cascade is array (0 to 7) of datavect;
  signal dout_cascade : data_cascade;

begin

  clk_en <= enable or write;
  wenable <= write;

  dataout <= do(dbits-1 downto 0);

  di(dbits-1 downto 0) <= datain;

  -- when reading out data, and when CS is changing value, we want to delay
  -- the CS that goes to select the dout_cascade (only that one, not all CS
  -- signal, as it's needed at the right time for writing), by 1 by clock
  -- cycle, to allow the last data to be read correctly, otherwise the change
  -- in CS value would read out another address
  delay_cs_out : process(clk) is
  begin
    if rising_edge(clk) then
      cs_sel_out <= cs;
    end if;
  end process;

  a14 : if (abits <= 17) generate

    min4: for i in 0 to ((dbits-1)/MAX_WIDTH) generate

      a14plus : if (abits > 14) generate
        addr <= address(addr'LEFT downto 0);
        cs(abits - addr'LENGTH - 1 downto 0) <= address(abits-1 downto addr'LENGTH);
        cs(cs'LEFT downto abits - addr'LENGTH) <= (others => '0');
      end generate;

      a14max : if (abits <= 14) generate
        addr(addr'LEFT downto addr'LEFT-abits+1) <= address;
        addr(addr'LEFT-abits downto 0) <= (others => '1');
        cs <= (others =>'0');
      end generate;

      -- OUT flow
      last_i_out : if (i = (dbits/MAX_WIDTH)) generate
        do(dbits-1 downto i*MAX_WIDTH) <= dout(i)(dbits-i*MAX_WIDTH-1 downto 0);
      end generate;

      not_last_i_out : if (i /= (dbits/MAX_WIDTH)) generate
        do((MAX_WIDTH*(i+1))-1 downto i*MAX_WIDTH) <= dout(i)(MAX_WIDTH-1 downto 0);
      end generate;


      -- IN flow
      not_last_bits_in : if ((dbits-1) > ((i+1)*MAX_WIDTH-1) ) generate
        din(i)(MAX_WIDTH-1 downto 0) <= di((i+1)*MAX_WIDTH-1 downto i*MAX_WIDTH);
        din(i)(PORT_WIDTH-1 downto MAX_WIDTH) <= (others => '0');
      end generate;

      last_bits_in: if ((dbits-1) <= ((i+1)*MAX_WIDTH-1) ) generate
        din(i)(dbits-i*MAX_WIDTH-1 downto 0) <= di(dbits-1 downto i*MAX_WIDTH);
        din(i)(PORT_WIDTH-1 downto (dbits-i*MAX_WIDTH)) <= (others => '0');
      end generate;

      -- selecting the output data from the cascade of DP16K check the
      -- function get_csmask to understand the reasoning behind the
      -- assignments. Think dout_cascade1(0..7) like dout_cascade1(j_index) in
      -- the get_csmask function
      with cs_sel_out select
        dout(i) <= dout_cascade(0)(i) when "000",-- think like dout_cascade(j)
        dout_cascade(1)(i) when "001",
        dout_cascade(2)(i) when "010",
        dout_cascade(3)(i) when "011",
        dout_cascade(4)(i) when "100",
        dout_cascade(5)(i) when "101",
        dout_cascade(6)(i) when "110",
        dout_cascade(7)(i) when "111",
        (others =>'0') when others;

      sp16gen: for j in 0 to get_jmax(abits, addr'LENGTH) generate
        -- LIFCL single port component
        r0 : SP16K
          generic map (
            DATA_WIDTH => "X" & integer'image(MAX_WIDTH),
            OUTREG => "BYPASSED",
            RESETMODE => "SYNC",
            GSR => "DISABLED",
            CSDECODE => get_csmask(j),
            ASYNC_RST_RELEASE => "SYNC",
            INIT_DATA => "STATIC")
          port map(
            DI  => din(i),
            AD  => addr,
            CLK => clk,
            CE  => clk_en,
            WE  => wenable,
            CS  => cs,
            RST => '0',
            DO  => dout_cascade(j)(i)
            );

      end generate;--sp16gen
    end generate;
  end generate;

  a18 : if abits >= 18 generate
    x: generic_syncram generic map (abits, dbits)
      port map (clk, address, datain, dataout, write);
  end generate;


  -- pragma translate_off
  a_to_high : if abits >= 18 generate
    x : process
    begin
      assert false
        report  "Address depth larger than 18 not supported for nexus_syncram. A generic_syncram will be inferred"
        severity failure;
      wait;
    end process;
  end generate;
  -- pragma translate_on

end;


------------------- NEXUS SYNCRAM 2P -------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;

library techmap;
use techmap.gencomp.all;

--pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on

entity nexus_syncram_2p is
  generic (abits : integer := 6; dbits : integer := 8
           );
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
end;

architecture behav of nexus_syncram_2p is

  component nexus_syncram_dp
    generic (abits : integer := 4; dbits : integer := 32
             );
    port(
      clk1     : in std_ulogic;
      address1 : in std_logic_vector((abits -1) downto 0);
      datain1  : in std_logic_vector((dbits -1) downto 0);
      dataout1 : out std_logic_vector((dbits -1) downto 0);
      enable1  : in std_ulogic;
      write1   : in std_ulogic;
      clk2     : in std_ulogic;
      address2 : in std_logic_vector((abits -1) downto 0);
      datain2  : in std_logic_vector((dbits -1) downto 0);
      dataout2 : out std_logic_vector((dbits -1) downto 0);
      enable2  : in std_ulogic;
      write2   : in std_ulogic);
  end component;

  signal datain2 : std_logic_vector(dbits-1 downto 0);

begin

  datain2 <= (others => '0');

  -- port1 is only for writing
  -- port2 is only for reading
  sr_dp : nexus_syncram_dp
    generic map (abits => abits,
                 dbits => dbits)
    port map (
      clk1     => wclk,
      address1 => waddress,
      datain1  => datain,
      dataout1 => open,
      enable1  => '0',
      write1   => write,
      clk2     => rclk,
      address2 => raddress,
      datain2  => datain2,
      dataout2 => dataout,
      enable2  => renable,
      write2   => '0'
      );

end;


------------------- NEXUS SYNCRAM DP -------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;

library techmap;
use techmap.gencomp.all;

--pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on

entity nexus_syncram_dp is
  generic (abits : integer := 4; dbits : integer := 32
           );
  port (
    clk1     : in std_ulogic;
    address1 : in std_logic_vector((abits -1) downto 0);
    datain1  : in std_logic_vector((dbits -1) downto 0);
    dataout1 : out std_logic_vector((dbits -1) downto 0);
    enable1  : in std_ulogic;
    write1   : in std_ulogic;
    clk2     : in std_ulogic;
    address2 : in std_logic_vector((abits -1) downto 0);
    datain2  : in std_logic_vector((dbits -1) downto 0);
    dataout2 : out std_logic_vector((dbits -1) downto 0);
    enable2  : in std_ulogic;
    write2   : in std_ulogic);
end;

architecture behav of nexus_syncram_dp is

  component DP16K
    GENERIC (
      DATA_WIDTH_A : String := "X18";
      DATA_WIDTH_B : String := "X18";
      OUTREG_A : String := "BYPASSED";
      OUTREG_B : String := "BYPASSED";
      GSR : String := "ENABLED";
      RESETMODE_A : String := "SYNC";
      RESETMODE_B : String := "SYNC";
      INITVAL_00 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_01 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_02 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_03 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_04 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_05 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_06 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_07 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_08 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_09 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_10 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_11 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_12 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_13 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_14 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_15 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_16 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_17 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_18 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_19 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_20 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_21 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_22 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_23 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_24 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_25 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_26 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_27 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_28 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_29 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_30 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_31 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_32 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_33 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_34 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_35 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_36 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_37 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_38 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_39 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      CSDECODE_A : String := "000";
      CSDECODE_B : String := "000";
      ASYNC_RST_RELEASE_A : String := "SYNC";
      ASYNC_RST_RELEASE_B : String := "SYNC";
      INIT_DATA : String := "STATIC");
    port(
      DIA : IN std_logic_vector(17 downto 0);
      DIB : IN std_logic_vector(17 downto 0);
      ADA : IN std_logic_vector(13 downto 0);
      ADB : IN std_logic_vector(13 downto 0);
      CLKA : IN std_logic;
      CLKB : IN std_logic;
      CEA : IN std_logic;
      CEB : IN std_logic;
      WEA : IN std_logic;
      WEB : IN std_logic;
      CSA : IN std_logic_vector(2 downto 0);
      CSB : IN std_logic_vector(2 downto 0);
      RSTA : IN std_logic;
      RSTB : IN std_logic;
      DOA : OUT std_logic_vector(17 downto 0);
      DOB : OUT std_logic_vector(17 downto 0));
  end component;


  -- This function, given abits bits, returns the maximum data width that can
  -- be used in the LATTICE primitive.
  function calc_max_dwidth(
    abits  : in integer
    ) return integer is
    variable dwidth : integer := 36;
  begin

    if abits <= 10 then
      dwidth := 18;
    elsif abits = 11 then
      dwidth := 9;
    elsif abits = 12 then
      dwidth := 4;
    elsif abits = 13 then
      dwidth := 2;
    elsif abits >= 14 then
      dwidth := 1;
    end if;

    return dwidth;

  end function calc_max_dwidth;

  -- This function returns the least multiple of max_width
  -- that can accommodate the input data
  function calc_min_mult(
    data_width : in integer;
    max_width  : in integer
    ) return integer is
    variable min_mult : integer := 32;
  begin

    min_mult := (data_width + max_width - 1) / max_width;
    return min_mult;
  end function calc_min_mult;

  -- This function returns the low starting bit for the address input used by
  -- the Lattice component
  function calc_startaddrbit(
    abits  : in integer
    ) return integer is
    variable startbit : integer := 5;
  begin

    if abits <= 10 then
      startbit := 4;
    elsif abits = 11 then
      startbit  := 3;
    elsif abits = 12 then
      startbit  := 2;
    elsif abits = 13 then
      startbit  := 1;
    else
      startbit  := 0;
    end if;

    return startbit;

  end function calc_startaddrbit;

  -- This function returns the mask as string to be applied to CSDECODE
  -- when abits > 14, to implement memory cascade
  function get_csmask(
    j_index     : in integer
    ) return string is
    variable csmask : string (3 downto 1) := "111";
  begin
    if (j_index = 0) then
      csmask := "111";-- cs = 000
    elsif (j_index = 1) then
      csmask := "110";-- cs = 001
    elsif (j_index = 2) then
      csmask := "101";-- cs = 010
    elsif (j_index = 3) then
      csmask := "100";-- cs = 011
    elsif (j_index = 4) then
      csmask := "011";-- cs = 100
    elsif (j_index = 5) then
      csmask := "010";-- cs = 101
    elsif (j_index = 6) then
      csmask := "001";-- cs = 110
    elsif (j_index = 7) then
      csmask := "000";-- cs = 111
    end if;
    return csmask;
  end function get_csmask;

  -- This function returns the max value that j can get in the looping for
  -- cascading memories. If abits <= 14, then there's no need for cascading =>
  -- j_max = 0
  function get_jmax(
    abits     : in integer;
    addr_w    : in integer
    ) return integer is
    variable jmax : integer := 0;
  begin
    if abits <= 14 then
      jmax := 0;
    else
      jmax := 2**(abits-addr_w) - 1;
    end if;
    return jmax;
  end function;

  constant PORT_WIDTH : integer := 18;-- data port width of an instance
  constant ADDR_WIDTH : integer := 14;-- address port width of an instance

  signal addr1    : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal addr2    : std_logic_vector(ADDR_WIDTH-1 downto 0);

  signal not_clk2 : std_ulogic;
  signal clk_en1  : std_ulogic;
  signal clk_en2  : std_ulogic;
  signal wenable1 : std_ulogic;
  signal wenable2 : std_ulogic;

  signal cs1, cs_sel_out1 : std_logic_vector (2 downto 0);
  signal cs2, cs_sel_out2 : std_logic_vector (2 downto 0);

  constant MAX_WIDTH  : integer := calc_max_dwidth(abits);-- max data width
                                                          -- given abits
  constant MIN_MULT   : integer := calc_min_mult(dbits, MAX_WIDTH);
  constant ADDR_START : integer := calc_startaddrbit(abits);--get the starting
                                                            --bit for address

  -- "data signal-flow":
  -- datain -> di   -> din -> DI
  -- DO     -> dout_cascade -> dout -> do  -> dataout
  -- no need for din_cascade as CS and CSDECODE will take care of it
  signal do1,di1  : std_logic_vector(dbits-1 downto 0);
  signal do2,di2  : std_logic_vector(dbits-1 downto 0);
  subtype datav is std_logic_vector(PORT_WIDTH-1 downto 0);
  type datavect is array (0 to MIN_MULT-1) of datav;
  signal din1,dout1 : datavect;
  signal din2,dout2 : datavect;
  type data_cascade is array (0 to 7) of datavect;
  signal dout_cascade1, dout_cascade2 : data_cascade;

begin

  not_clk2 <= clk2;
  clk_en1 <= enable1 or write1;
  clk_en2 <= enable2 or write2;
  wenable1 <= write1;
  wenable2 <= write2;

  dataout1 <= do1(dbits-1 downto 0);
  dataout2 <= do2(dbits-1 downto 0);

  di1(dbits-1 downto 0) <= datain1;
  di2(dbits-1 downto 0) <= datain2;

  -- when reading out data, and when CS is changing value, we want to delay
  -- the CS that goes to select the dout_cascade (only that one, not all CS
  -- signal, as it's needed at the right time for writing), by 1 by clock
  -- cycle, to allow the last data to be read correctly, otherwise the change
  -- in CS value would read out another address
  delay_cs_out1 : process(clk1) is
  begin
    if rising_edge(clk1) then
      cs_sel_out1 <= cs1;
    end if;
  end process;

  delay_cs_out2 : process(clk2) is
  begin
    if rising_edge(clk2) then
      cs_sel_out2 <= cs2;
    end if;
  end process;

  a17 : if (abits <= 17) generate

    min4: for i in 0 to ((dbits-1)/MAX_WIDTH) generate

      a14plus : if (abits > 14) generate
        addr1 <= address1(addr1'LEFT downto 0);
        cs1(abits - addr1'LENGTH - 1 downto 0) <= address1(abits-1 downto addr1'LENGTH);
        cs1(cs1'LEFT downto abits - addr1'LENGTH) <= (others => '0');

        addr2 <= address2(addr2'LEFT downto 0);
        cs2(abits - addr2'LENGTH - 1 downto 0) <= address2(abits-1 downto addr2'LENGTH);
        cs2(cs2'LEFT downto abits - addr2'LENGTH) <= (others => '0');
      end generate;

      a14max : if (abits <= 14) generate
        addr1(addr1'LEFT downto addr1'LEFT-abits+1) <= address1;
        addr1(addr1'LEFT-abits downto 0) <= (others => '1');

        addr2(addr2'LEFT downto addr2'LEFT-abits+1) <= address2;
        addr2(addr2'LEFT-abits downto 0) <= (others => '1');

        cs1 <= (others =>'0');
        cs2 <= (others =>'0');
      end generate;

      -- OUT flow
      last_i_out : if (i = (dbits/MAX_WIDTH)) generate
        do1(dbits-1 downto i*MAX_WIDTH) <= dout1(i)(dbits-i*MAX_WIDTH-1 downto 0);
        do2(dbits-1 downto i*MAX_WIDTH) <= dout2(i)(dbits-i*MAX_WIDTH-1 downto 0);
      end generate;

      not_last_i_out : if (i /= (dbits/MAX_WIDTH)) generate
        do1((MAX_WIDTH*(i+1))-1 downto i*MAX_WIDTH) <= dout1(i)(MAX_WIDTH-1 downto 0);
        do2((MAX_WIDTH*(i+1))-1 downto i*MAX_WIDTH) <= dout2(i)(MAX_WIDTH-1 downto 0);
      end generate;

      -- IN flow
      not_last_bits_in : if ((dbits-1) > ((i+1)*MAX_WIDTH-1) ) generate
        din1(i)(MAX_WIDTH-1 downto 0) <= di1((i+1)*MAX_WIDTH-1 downto i*MAX_WIDTH);
        din1(i)(PORT_WIDTH-1 downto MAX_WIDTH) <= (others => '0');
        din2(i)(MAX_WIDTH-1 downto 0) <= di2((i+1)*MAX_WIDTH-1 downto i*MAX_WIDTH);
        din2(i)(PORT_WIDTH-1 downto MAX_WIDTH) <= (others => '0');
      end generate;

      last_bits_in: if ((dbits-1) <= ((i+1)*MAX_WIDTH-1) ) generate
        din1(i)(dbits-i*MAX_WIDTH-1 downto 0) <= di1(dbits-1 downto i*MAX_WIDTH);
        din1(i)(PORT_WIDTH-1 downto (dbits-i*MAX_WIDTH)) <= (others => '0');
        din2(i)(dbits-i*MAX_WIDTH-1 downto 0) <= di2(dbits-1 downto i*MAX_WIDTH);
        din2(i)(PORT_WIDTH-1 downto (dbits-i*MAX_WIDTH)) <= (others => '0');
      end generate;

      -- selecting the output data from the cascade of DP16K check the
      -- function get_csmask to understand the reasoning behind the
      -- assignments. Think dout_cascade1(0..7) like dout_cascade1(j_index) in
      -- the get_csmask function
      with cs_sel_out1 select
        dout1(i) <= dout_cascade1(0)(i) when "000",
        dout_cascade1(1)(i) when "001",
        dout_cascade1(2)(i) when "010",
        dout_cascade1(3)(i) when "011",
        dout_cascade1(4)(i) when "100",
        dout_cascade1(5)(i) when "101",
        dout_cascade1(6)(i) when "110",
        dout_cascade1(7)(i) when "111",
        (others =>'0') when others;

      with cs_sel_out2 select
        dout2(i) <= dout_cascade2(0)(i) when "000",--think like dout_cascade2(j)
        dout_cascade2(1)(i) when "001",
        dout_cascade2(2)(i) when "010",
        dout_cascade2(3)(i) when "011",
        dout_cascade2(4)(i) when "100",
        dout_cascade2(5)(i) when "101",
        dout_cascade2(6)(i) when "110",
        dout_cascade2(7)(i) when "111",
        (others =>'0') when others;

      dp16gen: for j in 0 to get_jmax(abits, addr1'LENGTH) generate
        --addr1 and addr2 are the same size
        -- LIFCL dual port component
        rdp0 : DP16K
          generic map (
            DATA_WIDTH_A => "X" & integer'image(MAX_WIDTH),
            DATA_WIDTH_B => "X" & integer'image(MAX_WIDTH),
            OUTREG_A => "BYPASSED",
            OUTREG_B => "BYPASSED",
            GSR => "DISABLED",
            RESETMODE_A => "SYNC",
            RESETMODE_B => "SYNC",
            CSDECODE_A => get_csmask(j),
            CSDECODE_B => get_csmask(j),
            ASYNC_RST_RELEASE_A => "SYNC",
            ASYNC_RST_RELEASE_B => "SYNC",
            INIT_DATA => "STATIC")
          port map (
            DIA  => din1(i),
            DIB  => din2(i),
            ADA  => addr1,
            ADB  => addr2,
            CLKA => clk1,
            CLKB => not_clk2,
            CEA  => clk_en1,
            CEB  => clk_en2,
            WEA  => wenable1,
            WEB  => wenable2,
            CSA  => cs1,
            CSB  => cs2,
            RSTA => '0',
            RSTB => '0',
            DOA  => dout_cascade1(j)(i),
            DOB  => dout_cascade2(j)(i)
            );
      end generate;--dp16gen

    end generate;
  end generate;


  -- pragma translate_off
  a_to_high : if abits >= 18 generate
    x : process
    begin
      assert false
        report  "Address depth larger than 18 not supported by LATTICE primitives"
        severity failure;
      wait;
    end process;
  end generate;
  -- pragma translate_on

end;



------------------- NEXUS SYNCRAM 2P FT -------------------
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;

library techmap;
use techmap.gencomp.all;

--pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on

entity nexus_syncram_2p_ecc is
  generic (abits : integer := 9; dbits : integer := 32);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    error    : out std_logic_vector(1 downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
end;

architecture behav of nexus_syncram_2p_ecc is

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

  component PDP16K
    generic (
      DATA_WIDTH_W : String := "X36";
      DATA_WIDTH_R : String := "X36";
      OUTREG : String := "BYPASSED";
      RESETMODE : String := "SYNC";
      GSR : String := "ENABLED";
      ECC : String := "DISABLED";
      INITVAL_00 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_01 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_02 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_03 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_04 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_05 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_06 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_07 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_08 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_09 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_0F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_10 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_11 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_12 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_13 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_14 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_15 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_16 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_17 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_18 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_19 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_1F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_20 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_21 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_22 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_23 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_24 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_25 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_26 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_27 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_28 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_29 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_2F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_30 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_31 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_32 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_33 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_34 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_35 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_36 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_37 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_38 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_39 : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3A : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3B : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3C : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3D : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3E : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      INITVAL_3F : String := "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
      CSDECODE_W : String := "000";
      CSDECODE_R : String := "000";
      ASYNC_RST_RELEASE : String := "SYNC";
      INIT_DATA : String := "STATIC");
    port(
      DI : in std_logic_vector(35 downto 0);
      ADW : in std_logic_vector(13 downto 0);
      ADR : in std_logic_vector(13 downto 0);
      CLKW : in std_logic := 'X';
      CLKR : in std_logic := 'X';
      CEW : in std_logic := 'X';
      CER : in std_logic := 'X';
      CSW : in std_logic_vector(2 downto 0);
      CSR : in std_logic_vector(2 downto 0);
      RST : in std_logic := 'X';
      DO : out std_logic_vector(35 downto 0);
      ONEBITERR : out std_logic := 'X';
      TWOBITERR : out std_logic := 'X');
  end component;

  -- This function returns the least multiple of max_width
  -- that can accommodate the input data
  function calc_min_mult(
    data_width : in integer;
    max_width  : in integer
    ) return integer is
    variable min_mult : integer := 32;
  begin

    min_mult := (data_width + max_width - 1) / max_width;
    return min_mult;
  end function calc_min_mult;

  -- This function returns the mask as string to be applied to CSDECODE
  -- when abits > 9, to implement memory cascade
  function get_csmask(
    j_index     : in integer
    ) return string is
    variable csmask : string (3 downto 1) := "111";
  begin
    if (j_index = 0) then
      csmask := "111";-- cs = 000
    elsif (j_index = 1) then
      csmask := "110";-- cs = 001
    elsif (j_index = 2) then
      csmask := "101";-- cs = 010
    elsif (j_index = 3) then
      csmask := "100";-- cs = 011
    elsif (j_index = 4) then
      csmask := "011";-- cs = 100
    elsif (j_index = 5) then
      csmask := "010";-- cs = 101
    elsif (j_index = 6) then
      csmask := "001";-- cs = 110
    elsif (j_index = 7) then
      csmask := "000";-- cs = 111
    end if;
    return csmask;
  end function get_csmask;

  -- This function returns the max value that j can get in the looping for
  -- cascading memories. If abits <= 10, then there's no need for cascading =>
  -- j_max = 0
  function get_jmax(
    abits     : in integer;
    addr_w    : in integer
    ) return integer is
    variable jmax : integer := 0;
  begin
    if abits <= 9 then
      jmax := 0;
    else
      jmax := 2**(abits-addr_w) - 1;
    end if;
    return jmax;
  end function;

  constant PORT_WIDTH : integer := 36;-- data port width of an instance
  constant ADDR_WIDTH : integer := 14;-- address port width of an instance

  signal waddr_port, raddr_port : std_logic_vector(ADDR_WIDTH-1 downto 0);

  signal clk_en_w, clk_en_r : std_ulogic;
  signal cs_w               : std_logic_vector (2 downto 0);
  signal cs_r, cs_sel_r     : std_logic_vector (2 downto 0);

  constant MAX_WIDTH  : integer := 32;
  constant MIN_MULT   : integer := calc_min_mult(dbits, MAX_WIDTH);

  -- "data signal-flow":
  -- datain -> di   -> din -> DI
  -- DO     -> dout_cascade -> dout -> do  -> dataout
  -- no need for din_cascade as CS and CSDECODE will take care of it
  signal do,di  : std_logic_vector(dbits-1 downto 0);
  subtype datav is std_logic_vector(PORT_WIDTH-1 downto 0);
  type datavect is array (0 to MIN_MULT-1) of datav;
  signal din,dout : datavect;
  -- data_cascade should be 2**(abits-addr'LENGTH) long, but this would imply
  -- more complicate code to handle all the 8 cases of the mux
  type data_cascade is array (0 to 7) of datavect;
  signal dout_cascade : data_cascade;

begin

  clk_en_w <= write ;
  clk_en_r <= renable;

  dataout <= do(dbits-1 downto 0);

  di(dbits-1 downto 0) <= datain;

  -- when reading out data, and when CS is changing value, we want to delay
  -- the CS that goes to select the dout_cascade (only that one, not all CS
  -- signal, as cs_w is needed at the right time for writing), by 1 by clock
  -- cycle, to allow the last data to be read correctly, otherwise the change
  -- in CS value would read out another address
  delay_cs_r : process(rclk) is
  begin
    if rising_edge(rclk) then
      cs_sel_r <= cs_r;
    end if;
  end process;

  a17 : if (abits <= 12) generate

    -- To be able to use the ONE/TWOBITTERR of the PDP16K, we need to use ONLY
    -- the 512x36 configuration, i.e. data_width = 36 bits, address_width = 9
    -- bits. This configuration is "better" documented in "Memory User Guide
    -- for Nexus Platform" FPGA-TN-02094
    min4: for i in 0 to ((dbits-1)/MAX_WIDTH) generate
      a14plus : if (abits >= 10 ) generate

        -- waddr_port 9 MSB bits
        waddr_port(waddr_port'high downto waddr_port'high-9+1) <= waddress(8 downto 0);
        raddr_port(raddr_port'high downto raddr_port'high-9+1) <= raddress(8 downto 0);

        -- waddr_port 5 LSB bits set to '1', as per documentation
        waddr_port(waddr_port'high-9 downto 0) <= (others => '1');
        raddr_port(raddr_port'high-9 downto 0) <= (others => '1');

        -- bits of waddress above the 9th one go inside chip-select
        cs_w(abits - 9 - 1 downto 0) <= waddress(abits-1 downto 9);
        cs_w(cs_w'LEFT downto abits - 9) <= (others => '0');

        -- bits of raddress above the 9th one go inside chip-select
        cs_r(abits - 9 - 1 downto 0) <= raddress(abits-1 downto 9);
        cs_r(cs_r'LEFT downto abits - 9) <= (others => '0');
      end generate;

      a14max : if (abits < 10) generate

        -- load w/raddress inside MSB bits of w/raddr
        waddr_port(waddr_port'left downto waddr_port'left-abits+1) <= waddress;
        raddr_port(raddr_port'left downto raddr_port'left-abits+1) <= raddress;

        -- the remaining LSB bits of w/raddr are set to 1, as per documentation
        waddr_port(waddr_port'left-abits downto 0) <= (others => '1');
        raddr_port(raddr_port'left-abits downto 0) <= (others => '1');

        -- chip-select bits all set to 0
        cs_w <= (others =>'0');
        cs_r <= (others =>'0');
      end generate;


      -- OUT flow
      last_i_dout : if (i = (dbits/MAX_WIDTH)) generate
        -- consuming the last bits from the PDP16K
        dout_gen: for p in 0 to (do'length - MAX_WIDTH*(dbits/MAX_WIDTH))/8 - 1 generate
          -- 8, 17, 26 and 35 are parity bits and ignored
          do(i*32 + p*8+7 downto i*32 + p*8) <= dout(i)(p*9+7 downto p*9);
        end generate;
      end generate;

      not_last_i_out : if (i /= (dbits/MAX_WIDTH)) generate
        -- 8, 17, 26 and 35 are parity bits and ignored
        do(i*32 + 7 downto i*32 + 0) <= dout(i)(7 downto 0);
        do(i*32 + 15 downto i*32 + 8) <= dout(i)(16 downto 9);
        do(i*32 + 23 downto i*32 + 16) <= dout(i)(25 downto 18);
        do(i*32 + 31 downto i*32 + 24) <= dout(i)(34 downto 27);
      end generate;


      -- IN flow
      last_bits_din : if (i = (dbits/MAX_WIDTH)) generate
        -- consuming the last bits from the input
        din_gen: for k in 0 to (di'length - MAX_WIDTH*(dbits/MAX_WIDTH))/8 - 1 generate
          din(i)(k*9+7 downto k*9) <= di(i*32 + k*8+7 downto i*32 + k*8);
          din(i)(k*9+8) <= '1';-- 8, 17, 26 and 35 are parity bits and just set to 1
          remaining_to_one : if (k = (di'length - MAX_WIDTH*(dbits/MAX_WIDTH))/8 - 1) generate
            -- remaining bits are set to '1', as per documentation
            din(i)(din(i)'high downto k*9+8+1) <= (others => '1');
          end generate;
        end generate;
      end generate;

      not_last_bits_in : if (i /= (dbits/MAX_WIDTH)) generate
        din(i)(7 downto 0) <= di(i*32 + 7 downto i*32 + 0);
        din(i)(8) <= '1';
        din(i)(16 downto 9) <= di(i*32 + 15 downto i*32 + 8);
        din(i)(17) <= '1';
        din(i)(25 downto 18) <= di(i*32 + 23 downto i*32 + 16);
        din(i)(26) <= '1';
        din(i)(34 downto 27) <= di(i*32 + 31 downto i*32 + 24);
        din(i)(35) <= '1';
      end generate;


      -- selecting the output data from the cascade of PDP16K. Check the
      -- function get_csmask to understand the reasoning behind the
      -- assignments. Think dout_cascade1(0..7) like dout_cascade1(j_index) in
      -- the get_csmask function
      with cs_sel_r select
        dout(i) <= dout_cascade(0)(i) when "000",-- think like dout_cascade(j)
        dout_cascade(1)(i) when "001",
        dout_cascade(2)(i) when "010",
        dout_cascade(3)(i) when "011",
        dout_cascade(4)(i) when "100",
        dout_cascade(5)(i) when "101",
        dout_cascade(6)(i) when "110",
        dout_cascade(7)(i) when "111",
        (others =>'0') when others;

      pdp16gen: for j in 0 to get_jmax(abits, 9) generate
        -- LIFCL/LFCPNX pseudo dual port component
        rpdp0 : PDP16K
          generic map (
            DATA_WIDTH_W => "X32",
            DATA_WIDTH_R => "X32",
            OUTREG => "BYPASSED",
            RESETMODE => "SYNC",
            GSR => "DISABLED",
            ECC => "ENABLED",
            CSDECODE_W => get_csmask(j),
            CSDECODE_R => get_csmask(j),
            ASYNC_RST_RELEASE => "SYNC",
            INIT_DATA => "STATIC")
          port map(
            DI  => din(i),
            ADW  => waddr_port,
            ADR  => raddr_port,
            CLKW => wclk,
            CLKR => rclk,
            CEW  => clk_en_w,
            CER  => clk_en_r,
            CSW  => cs_w,
            CSR  => cs_r,
            RST => '0',
            DO  => dout_cascade(j)(i),
            ONEBITERR => error(0),
            TWOBITERR => error(1)
            );

      end generate;--pdp16gen
    end generate;
  end generate;

  a18 : if abits >= 13 generate
    x: generic_syncram_2p generic map (abits, dbits)
      port map (rclk , wclk , raddress(abits -1 downto 0), waddress(abits -1 downto 0), datain(dbits -1 downto 0), write, dataout(dbits -1 downto 0), renable);
  end generate;


  -- pragma translate_off
  a_to_high : if abits >= 13 generate
    x : process
    begin
      assert false
        report  "Address depth larger than 12 not supported for nexus_syncram_2p_ecc. A generic_syncram_2p will be inferred"
        severity failure;
      wait;
    end process;
  end generate;
  -- pragma translate_on

end;



------------------- NEXUS SYNCRAM FT -------------------
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;

library techmap;
use techmap.gencomp.all;

--pragma translate_off
library nexus_sim;
use nexus_sim.all;
--pragma translate_on

entity nexus_syncram_ecc is
  generic (abits : integer := 9; dbits : integer := 32);
  port (
    clk     : in std_ulogic;
    address : in std_logic_vector((abits -1) downto 0);
    datain  : in std_logic_vector((dbits -1) downto 0);
    dataout : out std_logic_vector((dbits -1) downto 0);
    enable  : in std_ulogic;
    write   : in std_ulogic;
    error   : out std_logic_vector(1 downto 0));
end;

architecture behav of nexus_syncram_ecc is

  component nexus_syncram_2p_ecc is
    generic (abits : integer := 9; dbits : integer := 32);
    port (
      rclk     : in std_ulogic;
      renable  : in std_ulogic;
      raddress : in std_logic_vector((abits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      error    : out std_logic_vector(1 downto 0);
      wclk     : in std_ulogic;
      write    : in std_ulogic;
      waddress : in std_logic_vector((abits -1) downto 0);
      datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

begin

  nxs_2pft: nexus_syncram_2p_ecc
    generic map (abits => abits,
                 dbits => dbits)
    port map (
      rclk     => clk,
      renable  => enable,
      raddress => address,
      dataout  => dataout,
      error    => error,
      wclk     => clk,
      write    => write,
      waddress => address,
      datain   => datain
      );

end;
