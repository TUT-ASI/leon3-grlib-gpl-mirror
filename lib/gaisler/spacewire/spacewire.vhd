------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2010, Aeroflex Gaisler
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
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
library techmap;
use techmap.gencomp.all;

package spacewire is
  type grspw_in_type is record
    d           : std_logic_vector(3 downto 0);
    dv          : std_logic_vector(3 downto 0);
    s           : std_logic_vector(1 downto 0);
    dconnect    : std_logic_vector(3 downto 0);
    tickin      : std_ulogic;
    clkdiv10    : std_logic_vector(7 downto 0);
    rmapen      : std_ulogic;
    dcrstval    : std_logic_vector(9 downto 0);
    timerrstval : std_logic_vector(11 downto 0);
  end record;

  type grspw_out_type is record
    d           : std_logic_vector(3 downto 0);
    s           : std_logic_vector(3 downto 0);
    tickout     : std_ulogic;
    linkdis     : std_ulogic;
    rmapact     : std_ulogic;
  end record;

  type grspw_codec_in_type is record
    --spw                                     
    d            : std_logic_vector(3 downto 0);
    dv           : std_logic_vector(3 downto 0);
    dconnect     : std_logic_vector(3 downto 0);
    --link fsm
    linkdisabled : std_ulogic;
    linkstart    : std_ulogic;
    autostart    : std_ulogic;
    portsel      : std_ulogic;
    noportforce  : std_ulogic;
    rdivisor     : std_logic_vector(7 downto 0);
    idivisor     : std_logic_vector(7 downto 0);
    --rx iface
    rxiread      : std_ulogic;
    --tx iface
    txiwrite     : std_ulogic;
    txichar      : std_logic_vector(8 downto 0);
    txiflush     : std_ulogic;
    --time iface
    tickin       : std_ulogic;
    timectrlin   : std_logic_vector(1 downto 0);
    timein       : std_logic_vector(5 downto 0);
  end record;

  type grspw_codec_out_type is record
    --spw
    do           : std_logic_vector(3 downto 0);
    so           : std_logic_vector(3 downto 0);
    --link fsm
    state        : std_logic_vector(2 downto 0);
    actport      : std_ulogic;
    dconnecterr  : std_ulogic;
    crederr      : std_ulogic;
    escerr       : std_ulogic;
    parerr       : std_ulogic;
    --rx iface
    rxicharav    : std_ulogic;
    rxicharcnt   : std_logic_vector(6 downto 0);
    rxichar      : std_logic_vector(8 downto 0);
    --tx iface
    txicharcnt   : std_logic_vector(6 downto 0);
    txifull      : std_ulogic;
    --time iface
    tickin_done  : std_ulogic;
    tickout      : std_ulogic;
    timeout      : std_logic_vector(5 downto 0);
    timectrlout  : std_logic_vector(1 downto 0);
  end record;

  component grspw2_phy is
    generic(
      scantest   : integer;
      tech       : integer;
      input_type : integer --0=xor, 1=sample sdr, 2=sample ddr, 3=aeroflex phy
      );
    port(
      rstn     : in std_ulogic;
      rxclki   : in std_ulogic;
      rxclkin  : in std_ulogic;
      nrxclki  : in std_ulogic;
      di       : in std_ulogic;
      si       : in std_ulogic;  --used as df when input_type=3
      do       : out std_logic_vector(1 downto 0);
      dov      : out std_logic_vector(1 downto 0);
      dconnect : out std_logic_vector(1 downto 0);
      rxclko   : out std_ulogic;
      testrst  : in  std_ulogic := '0';
      testen   : in  std_ulogic := '0'
      );
  end component;

  component grspw2 is
    generic(
      tech         : integer range 0 to NTECH     := inferred;
      hindex       : integer range 0 to NAHBMST-1 := 0;
      pindex       : integer range 0 to NAPBSLV-1 := 0;
      paddr        : integer range 0 to 16#FFF#   := 0;
      pmask        : integer range 0 to 16#FFF#   := 16#FFF#;
      pirq         : integer range 0 to NAHBIRQ-1 := 0;
      rmap         : integer range 0 to 1  := 0;
      rmapcrc      : integer range 0 to 1  := 0;
      fifosize1    : integer range 4 to 32 := 32;
      fifosize2    : integer range 16 to 64 := 64;
      rxclkbuftype : integer range 0 to 2 := 0;
      rxunaligned  : integer range 0 to 1 := 0;
      rmapbufs     : integer range 2 to 8 := 4;
      ft           : integer range 0 to 2 := 0;
      scantest     : integer range 0 to 1 := 0;
      techfifo     : integer range 0 to 1 := 1;
      ports        : integer range 1 to 2 := 1;
      dmachan      : integer range 1 to 4 := 1;
      memtech      : integer range 0 to NTECH := DEFMEMTECH;
      input_type   : integer range 0 to 3 := 0;
      output_type  : integer range 0 to 2 := 0;
      rxtx_sameclk : integer range 0 to 1 := 0;
      netlist      : integer range 0 to 1 := 0
    );
    port(
      rst        : in  std_ulogic;
      clk        : in  std_ulogic;
      rxclk0     : in  std_ulogic;
      rxclk1     : in  std_ulogic;
      txclk      : in  std_ulogic;
      txclkn     : in  std_ulogic;
      ahbmi      : in  ahb_mst_in_type;
      ahbmo      : out ahb_mst_out_type;
      apbi       : in  apb_slv_in_type;
      apbo       : out apb_slv_out_type;
      swni       : in  grspw_in_type;
      swno       : out grspw_out_type
    );
  end component;

  component grspw is
    generic(
      tech         : integer range 0 to NTECH := DEFFABTECH;
      hindex       : integer range 0 to NAHBMST-1 := 0;
      pindex       : integer range 0 to NAPBSLV-1 := 0;
      paddr        : integer range 0 to 16#FFF#   := 0;
      pmask        : integer range 0 to 16#FFF#   := 16#FFF#;
      pirq         : integer range 0 to NAHBIRQ-1 := 0;
      sysfreq      : integer := 10000;
      usegen       : integer range 0 to 1  := 1;
      nsync        : integer range 1 to 2  := 1; 
      rmap         : integer range 0 to 2  := 0;
      rmapcrc      : integer range 0 to 1  := 0;
      fifosize1    : integer range 4 to 32 := 32;
      fifosize2    : integer range 16 to 64 := 64;
      rxclkbuftype : integer range 0 to 2 := 0;
      rxunaligned  : integer range 0 to 1 := 0;
      rmapbufs     : integer range 2 to 8 := 4;
      ft           : integer range 0 to 2 := 0;
      scantest     : integer range 0 to 1 := 0;
      techfifo     : integer range 0 to 1 := 1;
      netlist      : integer range 0 to 1 := 0;
      ports        : integer range 1 to 2 := 1;
      memtech      : integer range 0 to NTECH := DEFMEMTECH;
      nodeaddr     : integer range 0 to 255 := 254;
      destkey      : integer range 0 to 255 := 0
    );
    port(
      rst        : in  std_ulogic;
      clk        : in  std_ulogic;
      txclk      : in  std_ulogic;
      ahbmi      : in  ahb_mst_in_type;
      ahbmo      : out ahb_mst_out_type;
      apbi       : in  apb_slv_in_type;
      apbo       : out apb_slv_out_type;
      swni       : in  grspw_in_type;
      swno       : out grspw_out_type);
  end component;

  type grspw_in_type_vector is array (natural range <>) of grspw_in_type;
  type grspw_out_type_vector is array (natural range <>) of grspw_out_type;

  component grspwm is
    generic(
      tech         : integer range 0 to NTECH := DEFFABTECH;
      hindex       : integer range 0 to NAHBMST-1 := 0;
      pindex       : integer range 0 to NAPBSLV-1 := 0;
      paddr        : integer range 0 to 16#FFF#   := 0;
      pmask        : integer range 0 to 16#FFF#   := 16#FFF#;
      pirq         : integer range 0 to NAHBIRQ-1 := 0;
      sysfreq      : integer := 10000;
      usegen       : integer range 0 to 1  := 1;
      nsync        : integer range 1 to 2  := 1; 
      rmap         : integer range 0 to 2  := 0;
      rmapcrc      : integer range 0 to 1  := 0;
      fifosize1    : integer range 4 to 32 := 32;
      fifosize2    : integer range 16 to 64 := 64;
      rxclkbuftype : integer range 0 to 2 := 0;
      rxunaligned  : integer range 0 to 1 := 0;
      rmapbufs     : integer range 2 to 8 := 4;
      ft           : integer range 0 to 2 := 0;
      scantest     : integer range 0 to 1 := 0;
      techfifo     : integer range 0 to 1 := 1;
      netlist      : integer range 0 to 1 := 0;
      ports        : integer range 1 to 2 := 1;
      dmachan      : integer range 1 to 4 := 1;
      memtech      : integer range 0 to NTECH := DEFMEMTECH;
      spwcore      : integer range 1 to 2 := 2;
      input_type   : integer range 0 to 3 := 0;                 
      output_type  : integer range 0 to 2 := 0;                 
      rxtx_sameclk : integer range 0 to 1 := 0
    ); 
    port(
      rst        : in  std_ulogic;
      clk        : in  std_ulogic;
      rxclk0     : in  std_ulogic;
      rxclk1     : in  std_ulogic;
      txclk      : in  std_ulogic;
      txclkn     : in  std_ulogic;
      ahbmi      : in  ahb_mst_in_type;
      ahbmo      : out ahb_mst_out_type;
      apbi       : in  apb_slv_in_type;
      apbo       : out apb_slv_out_type;
      swni       : in  grspw_in_type;
      swno       : out grspw_out_type
    );
  end component;

  component grspw_codec is
  generic(
    ports        : integer range 1 to 2 := 1;
    input_type   : integer range 0 to 3 := 0;
    output_type  : integer range 0 to 2 := 0;
    rxtx_sameclk : integer range 0 to 1 := 0;
    fifosize     : integer range 16 to 64 := 64;
    tech         : integer;
    scantest     : integer range 0 to 1 := 0;
    techfifo     : integer range 0 to 1 := 0;
    ft           : integer range 0 to 2 := 0
    );
  port(
    rst          : in  std_ulogic;
    clk          : in  std_ulogic;
    rxclk0       : in  std_ulogic;
    rxclk1       : in  std_ulogic;
    txclk        : in  std_ulogic;
    txclkn       : in  std_ulogic;
    testen       : in  std_ulogic;
    testrst      : in  std_ulogic;
    lii          : in  grspw_codec_in_type;
    lio          : out grspw_codec_out_type
  );
  end component;

  component grspwrouter is
    generic(
      input_type   : integer range 0 to 3 := 0;
      output_type  : integer range 0 to 2 := 0;
      rxtx_sameclk : integer range 0 to 1 := 0;
      fifosize     : integer range 16 to 64 := 64;
      tech         : integer;
      scantest     : integer range 0 to 1 := 0;
      techfifo     : integer range 0 to 1 := 0;
      ft           : integer range 0 to 2 := 0;
      ports        : integer range 2 to 31 := 2;
      arbitration  : integer range 0 to 1 := 0 --0=rrobin, 1=priority 
      );
    port(
      rst          : in std_ulogic;
      clk          : in std_ulogic;
      rxclk0       : in std_ulogic;
      txclk        : in std_ulogic;
      txclkn       : in std_ulogic;
      testen       : in std_ulogic;
      testrst      : in std_ulogic;
      testin       : in std_ulogic;
      di           : in  std_logic_vector(61 downto 0);
      dvi          : in  std_logic_vector(61 downto 0);
      dconnect     : in  std_logic_vector(61 downto 0);
      do           : out std_logic_vector(61 downto 0);
      so           : out std_logic_vector(61 downto 0)
      );
  end component grspwrouter;

end package;
