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
-- Package: 	allmem
-- File:	allmem.vhd
-- Author:	Jiri Gaisler Gaisler Research
-- Description:	All tech specific memories
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package allmem is

-- AX & RTAX family

  component axcel_syncram
  generic ( abits : integer := 10; dbits : integer := 8);
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component axcel_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer:= 0);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic);
  end component;

-- Proasic + Proasicplus family

  component proasic_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component proasic_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic);
  end component;

-- Proasic3 family

  component proasic3_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component proasic3_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic);
  end component;

  component proasic3_syncram_dp is
  generic ( abits : integer := 6; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component proasic3e_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component proasic3e_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic);
  end component;

  component proasic3e_syncram_dp is
  generic ( abits : integer := 6; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component proasic3l_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component proasic3l_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic);
  end component;

  component saed32_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic);
  end component;

  component rhs65_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic;
    scanen   : in std_ulogic;
    bypass   : in std_ulogic;
    mbtdi    : in std_ulogic;
    mbtdo    : out std_ulogic;
    mbshft   : in std_ulogic;
    mbcapt   : in std_ulogic;
    mbupd    : in std_ulogic;
    mbclk    : in std_ulogic;
    mbrstn   : in std_ulogic;
    mbcgate  : in std_ulogic;
    mbpres   : out std_ulogic;
    mbmuxo   : out std_logic_vector(5 downto 0)
   );
  end component;

  component rhs65_syncram_2p_bist is
    generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0);
    port (
      rclk  : in std_ulogic;
      rena  : in std_ulogic;
      raddr : in std_logic_vector (abits -1 downto 0);
      dout  : out std_logic_vector (dbits -1 downto 0);
      wclk  : in std_ulogic;
      waddr : in std_logic_vector (abits -1 downto 0);
      din   : in std_logic_vector (dbits -1 downto 0);
      write : in std_ulogic;
      scanen   : in std_ulogic;
      bypass   : in std_ulogic;
      mbctrl   : in std_logic_vector(47 downto 0);
      mbstat   : out std_logic_vector(47 downto 0);
      mbrstn   : in std_ulogic;
      mbcgate  : in std_ulogic
      );
  end component;

  component dare_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0);
  port (
    rclk     : in  std_ulogic;
    rena     : in  std_ulogic;
    raddr    : in  std_logic_vector (abits -1 downto 0);
    dout     : out std_logic_vector (dbits -1 downto 0);
    wclk     : in  std_ulogic;
    waddr    : in  std_logic_vector (abits -1 downto 0);
    din      : in  std_logic_vector (dbits -1 downto 0);
    write    : in  std_ulogic;
    mbist    : in  std_ulogic;
    fill0    : in  std_ulogic;
    enable   : out std_ulogic;
    error    : out std_ulogic;
    testen   : in  std_logic;
    testrst  : in  std_logic
    );
  end component;

  component dare65t_syncram_2p_mbist
    generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0);
    port (
      rclk  : in std_ulogic;
      rena  : in std_ulogic;
      raddr : in std_logic_vector (abits -1 downto 0);
      dout  : out std_logic_vector (dbits -1 downto 0);
      wclk  : in std_ulogic;
      waddr : in std_logic_vector (abits -1 downto 0);
      din   : in std_logic_vector (dbits -1 downto 0);
      write : in std_ulogic;
      --
      mbist    : in  std_ulogic;
      fill0    : in  std_ulogic;
      fill1    : in  std_ulogic;
      mpresent : out std_ulogic;
      menable  : out std_ulogic;
      merror   : out std_ulogic;
      bistrst  : in  std_ulogic;
      testen   : in  std_ulogic;
      testrst  :  in std_logic;
      sysclk   : in  std_logic;
      --
      awtb     : in  std_ulogic;
      memreset : in  std_ulogic
     );
    end component;

  component rhumc_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic);
  end component;

  component proasic3l_syncram_dp is
  generic ( abits : integer := 6; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component proasic3_from
    generic (
      TimingChecksOn:      boolean := True;
      InstancePath:        string  := "*";
      Xon:                 boolean := False;
      MsgOn:               boolean := True;
      DATA_X:              integer := 1;
      MEMORYFILE:          string  := "";
      ACT_PROGFILE:        string  := "");
    port(
       CLK   : in          std_logic := 'U';
       DO0   : out         std_logic;
       DO1   : out         std_logic;
       DO2   : out         std_logic;
       DO3   : out         std_logic;
       DO4   : out         std_logic;
       DO5   : out         std_logic;
       DO6   : out         std_logic;
       DO7   : out         std_logic;
       ADDR0 : in          std_logic := 'U';
       ADDR1 : in          std_logic := 'U';
       ADDR2 : in          std_logic := 'U';
       ADDR3 : in          std_logic := 'U';
       ADDR4 : in          std_logic := 'U';
       ADDR5 : in          std_logic := 'U';
       ADDR6 : in          std_logic := 'U');
  end component;

  component proasic3e_from
    generic (
      TimingChecksOn:      boolean := True;
      InstancePath:        string  := "*";
      Xon:                 boolean := False;
      MsgOn:               boolean := True;
      DATA_X:              integer := 1;
      MEMORYFILE:          string  := "";
      ACT_PROGFILE:        string  := "");
    port(
       CLK   : in          std_logic := 'U';
       DO0   : out         std_logic;
       DO1   : out         std_logic;
       DO2   : out         std_logic;
       DO3   : out         std_logic;
       DO4   : out         std_logic;
       DO5   : out         std_logic;
       DO6   : out         std_logic;
       DO7   : out         std_logic;
       ADDR0 : in          std_logic := 'U';
       ADDR1 : in          std_logic := 'U';
       ADDR2 : in          std_logic := 'U';
       ADDR3 : in          std_logic := 'U';
       ADDR4 : in          std_logic := 'U';
       ADDR5 : in          std_logic := 'U';
       ADDR6 : in          std_logic := 'U');
  end component;

  component proasic3l_from
    generic (
       TimingChecksOn:      boolean := True;
       InstancePath:        string  := "*";
       Xon:                 boolean := False;
       MsgOn:               boolean := True;
       DATA_X:              integer := 1;
       MEMORYFILE:          string  := "";
       ACT_PROGFILE:        string  := "");
    port(
       CLK   : in          std_logic := 'U';
       DO0   : out         std_logic;
       DO1   : out         std_logic;
       DO2   : out         std_logic;
       DO3   : out         std_logic;
       DO4   : out         std_logic;
       DO5   : out         std_logic;
       DO6   : out         std_logic;
       DO7   : out         std_logic;
       ADDR0 : in          std_logic := 'U';
       ADDR1 : in          std_logic := 'U';
       ADDR2 : in          std_logic := 'U';
       ADDR3 : in          std_logic := 'U';
       ADDR4 : in          std_logic := 'U';
       ADDR5 : in          std_logic := 'U';
       ADDR6 : in          std_logic := 'U');
  end component;

  component from is
    generic (
      tech:             integer := 0;
      timingcheckson:   boolean := True;
      instancepath:     string  := "*";
      xon:              boolean := False;
      msgon:            boolean := True;
      data_x:           integer := 1;
      memoryfile:       string  := "";
      progfile:         string  := "");
    port (
      clk:     in    std_ulogic;
      addr:    in    std_logic_vector(6 downto 0);
      data:    out   std_logic_vector(7 downto 0));
  end component;

-- IGLOO2
  component igloo2_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component igloo2_syncram_dp is
  generic ( abits : integer := 6; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component igloo2_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits-1) downto 0);
    dataout  : out std_logic_vector((dbits-1) downto 0);
    wclk     : in std_ulogic;
    waddress : in std_logic_vector((abits-1) downto 0);
    datain   : in std_logic_vector((dbits-1) downto 0);
    write    : in std_ulogic);
  end component;

  component igloo2_syncram_be
  generic (abits : integer := 6; dbits : integer := 8);
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_logic_vector (dbits/8-1 downto 0);
    write    : in std_logic_vector (dbits/8-1 downto 0));
  end component;

-- RTG4
  component rtg4_syncram
  generic ( abits : integer := 10; dbits : integer := 8; ecc : integer range 0 to 1 := 0;
            doutpipe : integer := 0; eccpipe : integer := 0);
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic;
    error    : out std_logic_vector(1 downto 0);
    errinj   : in  std_ulogic);
  end component;

  component rtg4_syncram_dp is
  generic ( abits : integer := 6; dbits : integer := 8; ecc : integer range 0 to 1 := 0;
            doutpipe : integer := 0; eccpipe : integer := 0);
  port (
    clk1     : in std_ulogic;
    address1 : in std_logic_vector((abits -1) downto 0);
    datain1  : in std_logic_vector((dbits -1) downto 0);
    dataout1 : out std_logic_vector((dbits -1) downto 0);
    enable1  : in std_ulogic;
    write1   : in std_ulogic;
    error1   : out std_logic_vector(1 downto 0);
    clk2     : in std_ulogic;
    address2 : in std_logic_vector((abits -1) downto 0);
    datain2  : in std_logic_vector((dbits -1) downto 0);
    dataout2 : out std_logic_vector((dbits -1) downto 0);
    enable2  : in std_ulogic;
    write2   : in std_ulogic;
    error2   : out std_logic_vector(1 downto 0);
    errinj   : in std_ulogic);
  end component;

  component rtg4_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0;
            ecc : integer range 0 to 1 := 0;
            doutpipe : integer := 0; eccpipe : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits-1) downto 0);
    dataout  : out std_logic_vector((dbits-1) downto 0);
    rerror   : out std_logic_vector(1 downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits-1) downto 0);
    datain   : in std_logic_vector((dbits-1) downto 0);
    errinj   : in std_ulogic);
  end component;

  component rtg4_syncram_be
  generic (abits : integer := 6; dbits : integer := 8; doutpipe : integer := 0);
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_logic_vector (dbits/8-1 downto 0);
    write    : in std_logic_vector (dbits/8-1 downto 0));
  end component;

-- polarfire
  component polarfire_syncram
  generic (abits : integer := 10; dbits : integer := 8;
           doutpipe : integer := 0; lramonly : integer := 0);
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    addressw : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic;
    dataloop : in std_logic_vector((dbits-1) downto 0) := (others => '0')
    );
  end component;

  component polarfire_syncram_dp is
  generic ( abits : integer := 6; dbits : integer := 8; doutpipe : integer := 0);
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
    write2   : in std_ulogic;
    loopr1w2 : in std_logic_vector((dbits-1) downto 0) := (others => '0')
    );
  end component;

  component polarfire_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; sepclk : integer := 0;
            doutpipe : integer := 0; lramonly : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits-1) downto 0);
    dataout  : out std_logic_vector((dbits-1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits-1) downto 0);
    datain   : in std_logic_vector((dbits-1) downto 0);
    dataloop : in std_logic_vector((dbits-1) downto 0) := (others => '0')
    );
  end component;

  component polarfire_syncram_be
  generic (abits : integer := 6; dbits : integer := 8; doutpipe : integer := 0;
           lramonly : integer := 0);
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_logic_vector (dbits/8-1 downto 0);
    write    : in std_logic_vector (dbits/8-1 downto 0));
  end component;

  component polarfire_syncram_2pbe is
  generic (abits : integer := 6; dbits : integer := 8; sepclk : integer := 0;
           doutpipe : integer := 0; lramonly : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_logic_vector((dbits/8-1) downto 0);
    raddress : in std_logic_vector((abits-1) downto 0);
    dataout  : out std_logic_vector((dbits-1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_logic_vector((dbits/8-1) downto 0);
    waddress : in std_logic_vector((abits-1) downto 0);
    datain   : in std_logic_vector((dbits-1) downto 0)
    );
  end component;

  component polarfire_syncram_ecc is
    generic(
      abits : integer;
      dbits : integer;
      doutpipe : integer;
      nodff : integer;
      nouram : integer;
      forcedis : integer;
      rdenall : integer
      );
    port (
      clk     : in std_ulogic;
      enable  : in std_ulogic;
      write   : in std_ulogic;
      address : in std_logic_vector((abits-1) downto 0);
      addressw: in std_logic_vector((abits-1) downto 0);
      datain  : in std_logic_vector((dbits-1) downto 0);
      dataout : out std_logic_vector((dbits-1) downto 0);
      error   : out std_logic_vector(1 downto 0);
      dataloop : in std_logic_vector((dbits-1) downto 0) := (others => '0')
      );
  end component;

  component polarfire_syncram_2p_ecc is
    generic(
      abits : integer;
      dbits : integer;
      sepclk : integer;
      doutpipe : integer;
      nodff : integer;
      nouram : integer;
      forcedis : integer;
      rdenall : integer
      );
    port (
      rclk     : in std_ulogic;
      renable  : in std_ulogic;
      raddress : in std_logic_vector((abits-1) downto 0);
      dataout  : out std_logic_vector((dbits-1) downto 0);
      rerror   : out std_logic_vector(1 downto 0);
      wclk     : in std_ulogic;
      write    : in std_ulogic;
      waddress : in std_logic_vector((abits-1) downto 0);
      datain   : in std_logic_vector((dbits-1) downto 0);
      dataloop : in std_logic_vector((dbits-1) downto 0) := (others => '0')
      );
  end component;

-- Fusion family

  component fusion_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component fusion_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic);
  end component;

  component fusion_syncram_dp is
  generic ( abits : integer := 6; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component fusion_from
    generic (
       TimingChecksOn:      boolean := True;
       InstancePath:        string  := "*";
       Xon:                 boolean := False;
       MsgOn:               boolean := True;
       DATA_X:              integer := 1;
       MEMORYFILE:          string  := "";
       ACT_PROGFILE:        string  := "");
    port(
       CLK   : in          std_logic := 'U';
       DO0   : out         std_logic;
       DO1   : out         std_logic;
       DO2   : out         std_logic;
       DO3   : out         std_logic;
       DO4   : out         std_logic;
       DO5   : out         std_logic;
       DO6   : out         std_logic;
       DO7   : out         std_logic;
       ADDR0 : in          std_logic := 'U';
       ADDR1 : in          std_logic := 'U';
       ADDR2 : in          std_logic := 'U';
       ADDR3 : in          std_logic := 'U';
       ADDR4 : in          std_logic := 'U';
       ADDR5 : in          std_logic := 'U';
       ADDR6 : in          std_logic := 'U');
  end component;

component altera_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
end component;

component altera_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
end component;

component altera_syncram_be
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_logic_vector((dbits/8)-1 downto 0);
    write    : in std_logic_vector((dbits/8)-1 downto 0)
   );
end component;

component altera_fifo_dp is
  generic (tech  : integer := 0; abits : integer := 4; dbits : integer := 32;
           sepclk : integer := 1; afullgw : integer := 0; aemptygr : integer := 0; fwft : integer := 0);
  port (
    rdclk   : in std_logic;
    rdreq   : in std_logic;
    rdfull  : out std_logic;
    rdempty : out std_logic;
    aempty  : out std_logic;
    rdusedw : out std_logic_vector(abits-1 downto 0);
    q       : out std_logic_vector(dbits-1 downto 0);
    wrclk   : in std_logic;
    wrreq   : in std_logic;
    wrfull  : out std_logic;
    afull   : out std_logic;
    wrempty : out std_logic;
    wrusedw : out std_logic_vector(abits-1 downto 0);
    data    : in std_logic_vector(dbits-1 downto 0);
    aclr    : in std_logic := '0');
end component;

component generic_syncram
  generic (abits : integer := 10; dbits : integer := 8; pipeline : integer := 0; rdhold : integer := 0; gatedwr: integer := 0 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    write    : in std_ulogic;
    enable   : in std_ulogic := '1'
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


component generic_syncram_reg
  generic (abits : integer := 10; dbits : integer := 8; pipeline : integer := 0 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    write    : in std_ulogic
   );
end component;

component generic_syncram_2p_reg
  generic (abits : integer := 8; dbits : integer := 32; sepclk : integer := 0;
           pipeline : integer := 0);
  port (
    rclk : in std_ulogic;
    wclk : in std_ulogic;
    rdaddress: in std_logic_vector (abits -1 downto 0);
    wraddress: in std_logic_vector (abits -1 downto 0);
    data: in std_logic_vector (dbits -1 downto 0);
    wren : in std_ulogic;
    q: out std_logic_vector (dbits -1 downto 0)
  );
end component;

-- synchronous 3-port regfile (2 read, 1 write port)

  component generic_regfile_3p
  generic (tech : integer := 0; abits : integer := 6; dbits : integer := 32;
           wrfst : integer := 0; numregs : integer := 40;
           delout: integer := 0);
  port (
    wclk   : in  std_ulogic;
    waddr  : in  std_logic_vector((abits -1) downto 0);
    wdata  : in  std_logic_vector((dbits -1) downto 0);
    we     : in  std_ulogic;
    rclk   : in  std_ulogic;
    raddr1 : in  std_logic_vector((abits -1) downto 0);
    re1    : in  std_ulogic;
    rdata1 : out std_logic_vector((dbits -1) downto 0);
    raddr2 : in  std_logic_vector((abits -1) downto 0);
    re2    : in  std_ulogic;
    rdata2 : out std_logic_vector((dbits -1) downto 0);
    pre1   : out std_ulogic;
    pre2   : out std_ulogic;
    prdata1 : out std_logic_vector((dbits -1) downto 0);
    prdata2 : out std_logic_vector((dbits -1) downto 0)
  );
  end component;

  component ihp25_syncram
    generic ( abits : integer := 10; dbits : integer := 8 );
    port (
      clk      : in std_logic;
      address  : in std_logic_vector(abits -1 downto 0);
      datain   : in std_logic_vector(dbits -1 downto 0);
      dataout  : out std_logic_vector(dbits -1 downto 0);
      enable   : in std_logic;
      write    : in std_logic
    );
  end component;

  component ec_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
  end component;

  component ec_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component rh_lib18t_syncram_2p
  generic (abits : integer := 6; dbits : integer := 8;
	sepclk : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    diagin   : in std_logic_vector(3 downto 0));
  end component;

  component rh_lib18t_syncram is
  generic (abits : integer := 6; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic;
    diagin   : in std_logic_vector(1 downto 0) := "00");
  end component;

  component umc_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component rhumc_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component saed32_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component saed32_syncram_dp is
  generic ( abits : integer := 6; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component rhs65_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic;
    scanen   : in std_ulogic;
    bypass   : in std_ulogic;
    mbtdi    : in std_ulogic;
    mbtdo    : out std_ulogic;
    mbshft   : in std_ulogic;
    mbcapt   : in std_ulogic;
    mbupd    : in std_ulogic;
    mbclk    : in std_ulogic;
    mbrstn   : in std_ulogic;
    mbcgate  : in std_ulogic;
    mbpres   : out std_ulogic;
    mbmuxo   : out std_logic_vector(5 downto 0)
    );
  end component;

  component rhs65_syncram_bist is
    generic ( abits : integer := 10; dbits : integer := 8);
    port (
      clk      : in std_ulogic;
      address  : in std_logic_vector(abits -1 downto 0);
      datain   : in std_logic_vector(dbits -1 downto 0);
      dataout  : out std_logic_vector(dbits -1 downto 0);
      enable   : in std_ulogic;
      write    : in std_ulogic;
      scanen   : in std_ulogic;
      bypass   : in std_ulogic;
      mbctrl   : in std_logic_vector(47 downto 0);
      mbstat   : out std_logic_vector(47 downto 0);
      mbrstn   : in std_ulogic;
      mbcgate  : in std_ulogic
      );
  end component;

  component rhs65_syncram_dp is
  generic ( abits : integer := 6; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component rhs65_syncram_dp_bist is
    generic ( abits : integer := 6; dbits : integer := 8 );
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
      write2   : in std_ulogic
      );
  end component;

  component dare65t_syncram_mbist
    generic ( abits : integer := 10; dbits : integer := 8 );
    port (
      clk      : in std_ulogic;
      address  : in std_logic_vector(abits -1 downto 0);
      datain   : in std_logic_vector(dbits -1 downto 0);
      dataout  : out std_logic_vector(dbits -1 downto 0);
      enable   : in std_ulogic;
      write    : in std_ulogic;
      --
      mbist    : in  std_ulogic;
      fill0    : in  std_ulogic;
      fill1    : in  std_ulogic;
      mpresent : out std_ulogic;
      menable  : out std_ulogic;
      merror   : out std_ulogic;
      bistrst  : in  std_ulogic;
      testen   : in  std_ulogic;
      testrst  : in  std_logic;
      sysclk   : in  std_logic;
      --
      awtb     : in  std_ulogic
      );
    end component;

  component dare_syncram_mbist
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic;
    --
    mbist    : in  std_ulogic;
    fill0    : in  std_ulogic;
    menable  : out std_ulogic;
    error    : out std_ulogic;
    testen   : in  std_logic;
    testrst  : in  std_logic);
  end component;

  component dare_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic;
    testen   : in std_logic);
  end component;

  component dare_syncram_dp_mbist is
  generic ( abits : integer := 6; dbits : integer := 8 );
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
    write2   : in std_ulogic;
    --
    mbist    : in  std_ulogic;
    fill0    : in  std_ulogic;
    enable   : out std_ulogic;
    error    : out std_ulogic;
    testen   : in  std_logic;
    testrst  : in  std_logic
   );
  end component;

  component dare_syncram_dp is
  generic ( abits : integer := 6; dbits : integer := 8 );
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
    write2   : in std_ulogic;
    testen   : in std_logic
   );
  end component;


  component virage_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component virage_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 8 );
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
  end component;

  component virage90_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component virtex_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
  end component;

  component virtex_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component unisim_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
  end component;

  component unisim_syncram_ecc
  generic ( abits : integer := 9; dbits : integer := 32);
  port (
    clk     : in std_ulogic;
    address : in std_logic_vector(abits-1 downto 0);
    datain  : in std_logic_vector(dbits-1 downto 0);
    dataout : out std_logic_vector(dbits-1 downto 0);
    enable  : in std_ulogic;
    write   : in std_ulogic;
    error   : out std_logic_vector(1 downto 0);
    errinj  : in  std_logic_vector(1 downto 0)
  );
  end component;

  component unisim_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component kintex7_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component kintex7_syncram_2p is
    generic (
      abits : integer := 4; dbits : integer := 32; sepclk : integer := 0 );
    port (
      clk1     : in std_ulogic;
      address1 : in std_logic_vector((abits -1) downto 0);
      datain1  : in std_logic_vector((dbits -1) downto 0);
      enable1  : in std_ulogic;
      write1   : in std_ulogic;
      clk2     : in std_ulogic;
      address2 : in std_logic_vector((abits -1) downto 0);
      dataout2 : out std_logic_vector((dbits -1) downto 0);
      enable2  : in std_ulogic
    );
  end component;

  component kintex7_syncram is
    generic (
      abits : integer := 4; dbits : integer := 32 );
    port (
      clk     : in std_ulogic;
      address : in std_logic_vector((abits -1) downto 0);
      datain  : in std_logic_vector((dbits -1) downto 0);
      enable  : in std_ulogic;
      write   : in std_ulogic;
      dataout : out std_logic_vector((dbits -1) downto 0));
  end component;

  component unisim_syncram64
  generic ( abits : integer := 9);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (63 downto 0);
    dataout : out std_logic_vector (63 downto 0);
    enable  : in  std_logic_vector (1 downto 0);
    write   : in  std_logic_vector (1 downto 0)
  );
  end component;

  component unisim_syncram_be
  generic ( abits : integer := 9; dbits : integer := 32; tech : integer := 0);
  port (
    clk     : in std_ulogic;
    address : in std_logic_vector (abits -1 downto 0);
    datain  : in std_logic_vector (dbits -1 downto 0);
    dataout : out std_logic_vector (dbits -1 downto 0);
    enable  : in std_logic_vector (dbits/8-1 downto 0);
    write   : in std_logic_vector(dbits/8-1 downto 0)
  );
  end component;

  component ultrascale_syncram is
    generic (
      abits : integer := 4; dbits : integer := 32 );
    port (
      clk     : in std_ulogic;
      address : in std_logic_vector((abits -1) downto 0);
      datain  : in std_logic_vector((dbits -1) downto 0);
      enable  : in std_ulogic;
      write   : in std_ulogic;
      dataout : out std_logic_vector((dbits -1) downto 0));
  end component;

  component ultrascale_syncram_ecc is
  generic ( abits : integer := 9; dbits : integer := 32; sepclk : integer := 0);
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
  end component;

  component ultrascale_syncram_2p is
    generic (
      abits : integer := 4; dbits : integer := 32; sepclk : integer := 0 );
    port (
      rclk     : in std_ulogic;
      renable  : in std_ulogic;
      raddress : in std_logic_vector((abits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      wclk     : in std_ulogic;
      write    : in std_ulogic;
      waddress : in std_logic_vector((abits -1) downto 0);
      datain   : in std_logic_vector((dbits -1) downto 0)
      );
  end component;

  component ultrascale_syncram_2p_ecc is
    generic (
      abits : integer := 4; dbits : integer := 32; sepclk : integer := 0);
    port (
      rclk     : in  std_ulogic;
      renable  : in  std_ulogic;
      raddress : in  std_logic_vector((abits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      wclk     : in  std_ulogic;
      write    : in  std_ulogic;
      waddress : in  std_logic_vector((abits -1) downto 0);
      datain   : in  std_logic_vector((dbits -1) downto 0);
      error    : out std_logic_vector(1 downto 0);
      errinj   : in  std_logic_vector(1 downto 0)
      );
  end component;

  component ultrascale_syncram_dp
    generic ( abits : integer := 10; dbits : integer := 8 );
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
      write2   : in std_ulogic
      );
  end component;

  component ultrascale_syncram64
    generic ( abits : integer := 9);
    port (
      clk     : in  std_ulogic;
      address : in  std_logic_vector (abits -1 downto 0);
      datain  : in  std_logic_vector (63 downto 0);
      dataout : out std_logic_vector (63 downto 0);
      enable  : in  std_logic_vector (1 downto 0);
      write   : in  std_logic_vector (1 downto 0)
      );
  end component;


  component versal_syncram is
    generic (
      abits : integer := 4; dbits : integer := 32 );
    port (
      clk     : in std_ulogic;
      address : in std_logic_vector((abits -1) downto 0);
      datain  : in std_logic_vector((dbits -1) downto 0);
      enable  : in std_ulogic;
      write   : in std_ulogic;
      dataout : out std_logic_vector((dbits -1) downto 0));
  end component versal_syncram;

  component versal_syncram_ecc is
  generic ( abits : integer := 9; dbits : integer := 32; sepclk : integer := 0);
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
  end component versal_syncram_ecc;

  component versal_syncram_2p is
    generic (
      abits : integer := 4; dbits : integer := 32; sepclk : integer := 0 );
    port (
      rclk     : in std_ulogic;
      renable  : in std_ulogic;
      raddress : in std_logic_vector((abits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      wclk     : in std_ulogic;
      write    : in std_ulogic;
      waddress : in std_logic_vector((abits -1) downto 0);
      datain   : in std_logic_vector((dbits -1) downto 0)
      );
  end component versal_syncram_2p;

  component versal_syncram_2p_ecc is
    generic (
      abits : integer := 4; dbits : integer := 32; sepclk : integer := 0 );
    port (
      rclk     : in  std_ulogic;
      renable  : in  std_ulogic;
      raddress : in  std_logic_vector((abits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      wclk     : in  std_ulogic;
      write    : in  std_ulogic;
      waddress : in  std_logic_vector((abits -1) downto 0);
      datain   : in  std_logic_vector((dbits -1) downto 0);
      error    : out std_logic_vector(1 downto 0);
      errinj   : in  std_logic_vector(1 downto 0)
      );
  end component versal_syncram_2p_ecc;

  component versal_syncram_dp is
    generic ( abits : integer := 10; dbits : integer := 8; sepclk : integer := 0 );
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
      write2   : in std_ulogic
      );
  end component versal_syncram_dp;

  component versal_syncram64 is
    generic ( abits : integer := 9);
    port (
      clk     : in  std_ulogic;
      address : in  std_logic_vector (abits -1 downto 0);
      datain  : in  std_logic_vector (63 downto 0);
      dataout : out std_logic_vector (63 downto 0);
      enable  : in  std_logic_vector (1 downto 0);
      write   : in  std_logic_vector (1 downto 0)
      );
  end component versal_syncram64;


  component virage90_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 8 );
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
    write2   : in std_ulogic
   );
  end component;

  component ut025crh_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
  end component;

  component ut025crh_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic);
  end component;

  component ut130hbd_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
  end component;

  component ut130hbd_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32; words : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

  component peregrine_regfile_3p
  generic (abits : integer := 6; dbits : integer := 32);
  port (
    wclk   : in  std_ulogic;
    waddr  : in  std_logic_vector((abits -1) downto 0);
    wdata  : in  std_logic_vector((dbits -1) downto 0);
    we     : in  std_ulogic;
    raddr1 : in  std_logic_vector((abits -1) downto 0);
    re1    : in  std_ulogic;
    rdata1 : out std_logic_vector((dbits -1) downto 0);
    raddr2 : in  std_logic_vector((abits -1) downto 0);
    re2    : in  std_ulogic;
    rdata2 : out std_logic_vector((dbits -1) downto 0));
  end component;

  component eclipse_syncram_2p is
  generic ( abits : integer := 8; dbits : integer := 32);
  port (
    rclk  : in std_ulogic;
    rena  : in std_ulogic;
    raddr : in std_logic_vector (abits -1 downto 0);
    dout  : out std_logic_vector (dbits -1 downto 0);
    wclk  : in std_ulogic;
    waddr : in std_logic_vector (abits -1 downto 0);
    din   : in std_logic_vector (dbits -1 downto 0);
    write : in std_ulogic);
  end component;

  component nextreme_syncram_2p is
  generic (abits : integer := 6; dbits : integer := 8);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

  component custom1_syncram_2p is
  generic ( abits : integer := 8; dbits : integer := 32);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

  component artisan_syncram_2p is
  generic ( abits : integer := 8; dbits : integer := 32);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

  component smic13_syncram_2p is
  generic ( abits : integer := 8; dbits : integer := 32);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

  component ihp25rh_syncram
    generic ( abits : integer := 10; dbits : integer := 8 );
    port (
      clk      : in std_logic;
      address  : in std_logic_vector(abits -1 downto 0);
      datain   : in std_logic_vector(dbits -1 downto 0);
      dataout  : out std_logic_vector(dbits -1 downto 0);
      enable   : in std_logic;
      write    : in std_logic);
  end component;

  component peregrine_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
  end component;

  component artisan_syncram
  generic ( abits : integer := 10; dbits : integer := 32 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
  end component;

  component smic13_syncram
  generic ( abits : integer := 10; dbits : integer := 32 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
  end component;

  component custom1_syncram
  generic ( abits : integer := 10; dbits : integer := 32 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
  end component;

  component nextreme_syncram
  generic (abits : integer := 6; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic);
  end component;

  component unisim_syncram_2p is
  generic (abits : integer := 6; dbits : integer := 8; sepclk : integer := 0;
	wrfst : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

  component virtex5_syncram_ecc is
    generic ( abits : integer := 9; dbits : integer := 32);
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
  end component;

  component virtex5_syncram_2p_ecc is
    generic (
      abits : integer := 4; dbits : integer := 32);
    port (
      rclk     : in  std_ulogic;
      renable  : in  std_ulogic;
      raddress : in  std_logic_vector((abits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      wclk     : in  std_ulogic;
      write    : in  std_ulogic;
      waddress : in  std_logic_vector((abits -1) downto 0);
      datain   : in  std_logic_vector((dbits -1) downto 0);
      error    : out std_logic_vector(1 downto 0);
      errinj   : in  std_logic_vector(1 downto 0)
      );
  end component;

  component virage_syncram_2p
  generic (abits : integer := 6; dbits : integer := 8;
	sepclk : integer := 0; wrfst : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

  component atc18rha_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic;
    testin   : in std_logic_vector(3 downto 0));
  end component;

  component atc18rha_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 8);
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
    write2   : in std_ulogic;
    testin   : in std_logic_vector(3 downto 0));
  end component;

  component atc18rha_syncram_2p
  generic ( abits : integer := 6; dbits : integer := 8;
	sepclk : integer := 0; wrfst : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    testin   : in std_logic_vector(3 downto 0));
  end component;

  component artisan_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 32 );
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
    write2   : in std_ulogic
   );
  end component;

  component smic13_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 32 );
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
    write2   : in std_ulogic
   );
  end component;

  component tm65gplus_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
  );
  end component;

  component tm65gplus_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 8);
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
    write2   : in std_ulogic
   );
  end component;

  component tm65gplus_syncram_2p
  generic ( abits : integer := 6; dbits : integer := 8;
	sepclk : integer := 0; wrfst : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

  component generic_regfile_4p
  generic (tech : integer := 0; abits : integer := 6; dbits : integer := 32;
           wrfst : integer := 0; numregs : integer := 40; g0addr: integer := 0;
           delout: integer := 0);
  port (
    wclk   : in  std_ulogic;
    waddr  : in  std_logic_vector((abits -1) downto 0);
    wdata  : in  std_logic_vector((dbits -1) downto 0);
    we     : in  std_ulogic;
    rclk   : in  std_ulogic;
    raddr1 : in  std_logic_vector((abits -1) downto 0);
    re1    : in  std_ulogic;
    rdata1 : out std_logic_vector((dbits -1) downto 0);
    raddr2 : in  std_logic_vector((abits -1) downto 0);
    re2    : in  std_ulogic;
    rdata2 : out std_logic_vector((dbits -1) downto 0);
    raddr3 : in  std_logic_vector((abits -1) downto 0);
    re3    : in  std_ulogic;
    rdata3 : out std_logic_vector((dbits -1) downto 0);
    pre1   : out std_ulogic;
    pre2   : out std_ulogic;
    pre3   : out std_ulogic;
    prdata1 : out std_logic_vector((dbits -1) downto 0);
    prdata2 : out std_logic_vector((dbits -1) downto 0);
    prdata3 : out std_logic_vector((dbits -1) downto 0)
  );
  end component;

  component cmos9sf_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector(abits -1 downto 0);
    datain   : in std_logic_vector(dbits -1 downto 0);
    dataout  : out std_logic_vector(dbits -1 downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
  );
  end component;

  component cmos9sf_syncram_2p
  generic ( abits : integer := 6; dbits : integer := 8);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

  -- eASIC Nextreme2
  component n2x_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic
   );
  end component;

  component n2x_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 8; sepclk : integer := 0 );
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
    write2   : in std_ulogic
   );
  end component;

  component n2x_syncram_2p is
  generic (abits : integer := 6; dbits : integer := 8; sepclk : integer := 0;
	wrfst : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0));
  end component;

  component n2x_syncram_we                -- syncram with 32-bit write strobes
  generic (
    abits   : integer := 6;
    dbits   : integer := 8);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector((abits-1) downto 0);
    datain  : in  std_logic_vector((dbits-1) downto 0);
    dataout : out std_logic_vector((dbits-1) downto 0);
    enable  : in  std_logic_vector((dbits/32)-1 downto 0);
    write   : in  std_logic_vector((dbits/32)-1 downto 0));
  end component;

  component n2x_syncram_be                -- syncram with 8-bit write strobes
  generic (
    abits   : integer := 6;
    dbits   : integer := 8);
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector((abits-1) downto 0);
    datain  : in  std_logic_vector((dbits-1) downto 0);
    dataout : out std_logic_vector((dbits-1) downto 0);
    enable  : in  std_logic_vector((dbits/8)-1 downto 0);
    write   : in  std_logic_vector((dbits/8)-1 downto 0)
  );
  end component;

  component n2x_syncram_dp_be
  generic (
    abits    : integer := 6;
    dbits    : integer := 8;
    sepclk   : integer := 1
  );
  port (
    clk1     : in  std_ulogic;
    address1 : in  std_logic_vector((abits-1) downto 0);
    datain1  : in  std_logic_vector((dbits-1) downto 0);
    dataout1 : out std_logic_vector((dbits-1) downto 0);
    enable1  : in  std_logic_vector((dbits/8-1) downto 0);
    write1   : in  std_logic_vector((dbits/8-1) downto 0);
    clk2     : in  std_ulogic;
    address2 : in  std_logic_vector((abits-1) downto 0);
    datain2  : in  std_logic_vector((dbits-1) downto 0);
    dataout2 : out std_logic_vector((dbits-1) downto 0);
    enable2  : in  std_logic_vector((dbits/8-1) downto 0);
    write2   : in  std_logic_vector((dbits/8-1) downto 0));
  end component;

  component n2x_syncram_2p_be
  generic (
    abits    : integer := 6;
    dbits    : integer := 8;
    sepclk   : integer := 0;
    wrfst    : integer := 0);
  port (
    rclk     : in  std_ulogic;
    renable  : in  std_logic_vector((dbits/8-1) downto 0);
    raddress : in  std_logic_vector((abits-1) downto 0);
    dataout  : out std_logic_vector((dbits-1) downto 0);
    wclk     : in  std_ulogic;
    write    : in  std_logic_vector((dbits/8-1) downto 0);
    waddress : in  std_logic_vector((abits-1) downto 0);
    datain   : in  std_logic_vector((dbits-1) downto 0));
  end component;

  component ut90nhbd_syncram
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic;
    tdbn     : in std_ulogic
   );
  end component;

  component ut90nhbd_syncram_2p
  generic ( abits : integer := 8; dbits : integer := 32);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    tdbn     : in std_ulogic);
  end component;

  component ut90nhbd_syncram_dp
  generic ( abits : integer := 10; dbits : integer := 32 );
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
    write2   : in std_ulogic;
    tdbn     : in std_ulogic
   );
  end component;

  component rh_lib13t_syncram_2p
  generic (abits : integer := 6; dbits : integer := 8;
	sepclk : integer := 0);
  port (
    rclk     : in std_ulogic;
    renable  : in std_ulogic;
    raddress : in std_logic_vector((abits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    wclk     : in std_ulogic;
    write    : in std_ulogic;
    waddress : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    diagin   : in std_logic_vector(3 downto 0));
  end component;

  component rh_lib13t_syncram is
  generic (abits : integer := 6; dbits : integer := 8 );
  port (
    clk      : in std_ulogic;
    address  : in std_logic_vector((abits -1) downto 0);
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_ulogic;
    write    : in std_ulogic;
    diagin   : in std_logic_vector(1 downto 0) := "00");
  end component;

  component nx_syncram is
  generic ( abits : integer    := 6;
            dbits : integer    := 8
            );
  port (
    clk     : in  std_ulogic;
    address : in  std_logic_vector (abits -1 downto 0);
    datain  : in  std_logic_vector (dbits -1 downto 0);
    dataout : out std_logic_vector (dbits -1 downto 0);
    enable  : in  std_ulogic;
    write   : in  std_ulogic
    );
  end component;

  component nx_syncram_dp is
    generic ( abits : integer    := 6;
              dbits : integer    := 8
              );
    port (
      clk1     : in  std_ulogic;
      address1 : in  std_logic_vector((abits -1) downto 0);
      datain1  : in  std_logic_vector((dbits -1) downto 0);
      dataout1 : out std_logic_vector((dbits -1) downto 0);
      enable1  : in  std_ulogic;
      write1   : in  std_ulogic;
      clk2     : in  std_ulogic;
      address2 : in  std_logic_vector((abits -1) downto 0);
      datain2  : in  std_logic_vector((dbits -1) downto 0);
      dataout2 : out std_logic_vector((dbits -1) downto 0);
      enable2  : in  std_ulogic;
      write2   : in  std_ulogic
      );
  end component;

  component nx_syncram_2p is
    generic (abits : integer := 6; dbits : integer := 8; sepclk : integer := 0;
             wrfst : integer := 0);
    port (
      rclk     : in  std_ulogic;
      renable  : in  std_ulogic;
      raddress : in  std_logic_vector((abits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      wclk     : in  std_ulogic;
      write    : in  std_ulogic;
      waddress : in  std_logic_vector((abits -1) downto 0);
      datain   : in  std_logic_vector((dbits -1) downto 0)
      );
  end component;

  component nx_syncram_be is
    generic ( abits : integer    := 6;
              dbits : integer    := 8
              );
    port (
      clk     : in  std_ulogic;
      address : in  std_logic_vector  (abits -1  downto 0);
      datain  : in  std_logic_vector  (dbits -1  downto 0);
      dataout : out std_logic_vector  (dbits -1  downto 0);
      enable  : in  std_logic_vector  (dbits/8-1 downto 0);
      write   : in  std_logic_vector  (dbits/8-1 downto 0)
      );
  end component;

  component gf22fdx_syncram is
    generic (
      abits: integer;
      dbits: integer
      );
    port (
      clk: in std_ulogic;
      address: in std_logic_vector(abits-1 downto 0);
      datain: in std_logic_vector(dbits-1 downto 0);
      dataout: out std_logic_vector(dbits-1 downto 0);
      enable: in std_ulogic;
      wr: in std_ulogic;
      tBist: in std_ulogic;
      tLogic: in std_ulogic;
      tStab: in std_ulogic;
      tWbt: in std_ulogic;
      resetFuse: in std_ulogic;
      s1d_ma: in std_logic_vector(7 downto 0);
      ch_bus_s1d: in std_logic_vector(11 downto 0);
      tck: in std_ulogic;
      eh_bus_s1d: in std_logic_vector(25 downto 0);
      eh_diagSel: in std_logic_vector(3 downto 0);
      eh_memEn: in std_logic_vector(3 downto 0);
      he_status: out std_logic_vector(3 downto 0);
      he_data: out std_logic_vector(3 downto 0);
      mempres: out std_logic_vector(3 downto 0);
      fShift: in std_ulogic;
      fDataIn: in std_ulogic;
      fBypass: in std_ulogic;
      fEnable: in std_ulogic;
      fDataOut: out std_ulogic
      );
  end component;

  component gf22fdx_syncram156bw is
    generic (
      abits: integer
      );
    port (
      clk: in std_ulogic;
      address: in std_logic_vector(abits-1 downto 0);
      datain: in std_logic_vector(155 downto 0);
      dataout: out std_logic_vector(155 downto 0);
      enable: in std_logic_vector(15 downto 0);
      wr: in std_logic_vector(15 downto 0);
      tBist: in std_ulogic;
      tLogic: in std_ulogic;
      tStab: in std_ulogic;
      tWbt: in std_ulogic;
      resetFuse: in std_ulogic;
      s1d_ma: in std_logic_vector(7 downto 0);
      ch_bus_s1d: in std_logic_vector(11 downto 0);
      tck: in std_ulogic;
      eh_bus_s1d: in std_logic_vector(25 downto 0);
      eh_diagSel: in std_logic_vector(3 downto 0);
      eh_memEn: in std_logic_vector(3 downto 0);
      he_status: out std_logic_vector(3 downto 0);
      he_data: out std_logic_vector(3 downto 0);
      mempres: out std_logic_vector(3 downto 0);
      fShift: in std_ulogic;
      fDataIn: in std_ulogic;
      fBypass: in std_ulogic;
      fEnable: in std_ulogic;
      fDataOut: out std_ulogic
      );
  end component;

  component gf22fdx_syncram_2p is
    generic (
      abits: integer;
      dbits: integer;
      sepclk: integer
      );
    port (
      rclk: in std_ulogic;
      renable: in std_ulogic;
      raddress: in std_logic_vector(abits-1 downto 0);
      dataout: out std_logic_vector(dbits-1 downto 0);
      wclk: in std_ulogic;
      waddress: in std_logic_vector(abits-1 downto 0);
      datain: in std_logic_vector(dbits-1 downto 0);
      wenable: in std_ulogic;
      tBist: in std_ulogic;
      tLogic: in std_ulogic;
      tScan: in std_ulogic;
      tStab: in std_ulogic;
      tWbt: in std_ulogic;
      resetFuse: in std_ulogic;
      smp_ma: in std_logic_vector(11 downto 0);
      r2p_ma: in std_logic_vector(8 downto 0);
      ch_bus_r2p: in std_logic_vector(11 downto 0);
      ch_bus_smp: in std_logic_vector(11 downto 0);
      tck: in std_ulogic;
      eh_bus_r2p: in std_logic_vector(43 downto 0);
      eh_bus_smp: in std_logic_vector(30 downto 0);
      eh_diagSel: in std_logic_vector(3 downto 0);
      eh_memEn: in std_logic_vector(3 downto 0);
      he_status: out std_logic_vector(3 downto 0);
      he_data: out std_logic_vector(3 downto 0);
      mempres: out std_logic_vector(3 downto 0);
      fShift: in std_ulogic;
      fDataIn: in std_ulogic;
      fBypass: in std_ulogic;
      fEnable: in std_ulogic;
      fDataOut: out std_ulogic
      );
  end component;

  component syncram_rhs28 is
    generic (
      abits : integer;
      dbits : integer;
      pipeline : integer
      );
    port (
      clk      : in std_ulogic;
      address  : in std_logic_vector((abits -1) downto 0);
      datain   : in std_logic_vector((dbits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      enable   : in std_ulogic;
      write    : in std_ulogic;
      initn    : in std_ulogic;
      testen   : in std_ulogic;
      scanen   : in std_ulogic
      );
  end component;

  component syncram_2p_rhs28 is
    generic (
      abits : integer;
      dbits : integer
      );
    port (
      rclk     : in std_ulogic;
      renable  : in std_ulogic;
      raddress : in std_logic_vector((abits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      wclk     : in std_ulogic;
      write    : in std_ulogic;
      waddress : in std_logic_vector((abits -1) downto 0);
      datain   : in std_logic_vector((dbits -1) downto 0);
      initn    : in std_ulogic;
      testen   : in std_ulogic;
      scanen   : in std_ulogic
      );
  end component;

  --NEXUS family
  component nexus_syncram is
    generic (abits : integer := 9;
             dbits : integer := 32
             );
    port (
      clk     : in std_ulogic;
      address : in std_logic_vector((abits -1) downto 0);
      datain  : in std_logic_vector((dbits -1) downto 0);
      dataout : out std_logic_vector((dbits -1) downto 0);
      enable  : in std_ulogic;
      write   : in std_ulogic
      );
  end component;


  component nexus_syncram_2p is
    generic (abits : integer := 6;
             dbits : integer := 8
             );
    port (
      rclk     : in std_ulogic;
      renable  : in std_ulogic;
      raddress : in std_logic_vector((abits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      wclk     : in std_ulogic;
      write    : in std_ulogic;
      waddress : in std_logic_vector((abits -1) downto 0);
      datain   : in std_logic_vector((dbits -1) downto 0)
      );
  end component;

  component nexus_syncram_dp is
    generic (abits : integer := 4;
             dbits : integer := 32
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
  end component;

  component nexus_syncram_2p_ecc is
    generic (abits : integer := 6;
             dbits : integer := 8);
    port (
      rclk     : in std_ulogic;
      renable  : in std_ulogic;
      raddress : in std_logic_vector((abits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      error    : out std_logic_vector(1 downto 0);
      wclk     : in std_ulogic;
      write    : in std_ulogic;
      waddress : in std_logic_vector((abits -1) downto 0);
      datain   : in std_logic_vector((dbits -1) downto 0)
      );
  end component;

  component nexus_syncram_ecc is
    generic (abits : integer := 9; dbits : integer := 32);
    port (
      clk     : in std_ulogic;
      address : in std_logic_vector((abits -1) downto 0);
      datain  : in std_logic_vector((dbits -1) downto 0);
      dataout : out std_logic_vector((dbits -1) downto 0);
      enable  : in std_ulogic;
      write   : in std_ulogic;
      error   : out std_logic_vector(1 downto 0));
  end component;
end;
