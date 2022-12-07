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
-- Package:     jtag_rv
-- File:        jtag_rv.vhd
-- Author:      Nils Wessman - Gaisler Research
-- Description: JTAG test procedures for RISCV debug module
------------------------------------------------------------------------------

-- pragma translate_off

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
library grlib;
use grlib.stdlib.all;
use grlib.stdio.all;
use grlib.amba.all;
library gaisler;
use gaisler.jtagtst.all;


package jtag_rv is
  procedure jtag_rv_reset(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer);
  
  procedure jtag_rv_read_idcode(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer);

  procedure jtag_rv_bypass_0(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer;
                    il  : in integer := 5);
  
  procedure jtag_rv_bypass(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer;
                    il  : in integer := 5);

  procedure jtag_rv_idcode(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer;
                    il  : in integer := 5);
  
  procedure jtag_rv_dtmcs(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer;
                    ir  : in integer := 16;
                    il  : in integer := 5);
  
  procedure jtag_rv_dmi(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer;
                    ir  : in integer := 17;
                    il  : in integer := 5);
  
  procedure jtag_rv_data(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    datain  : in std_logic_vector;
                    dataout : out std_logic_vector;
                    cp  : in integer);
  
  function rb (vi : std_logic_vector) return std_logic_vector;

  procedure jtag_rv_dmi_dmactive(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer);

  procedure jtag_rv_dmi_halt(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer);

  procedure jtag_rv_dmi_resume(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer);

  procedure jtag_rv_dmi_set_pc(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    pc  : in std_logic_vector(31 downto 0);
                    cp  : in integer);

  procedure jtag_rv_dmi_get_pc(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer);

  procedure jtag_rv_dmi_step(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    enable  : in boolean;
                    cp  : in integer);

  procedure jtag_rv_dmi_read_dmctrl(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer);

  procedure jtag_rv_dmi_read_dmstatus(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer);
end;

package body jtag_rv is
  procedure jtag_rv_reset(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';
  
    print("JTAG TAP RESET");    
    for i in 1 to 5 loop     -- reset
      clkj('1', '0', dc, tck, tms, tdi, tdo, cp);
    end loop;        
    clkj('0', '0', dc, tck, tms, tdi, tdo, cp);
  end procedure;
  
  procedure jtag_rv_read_idcode(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    --read IDCODE
    wait for 10 * cp * 1 ns;
    shift(true, 32, conv_std_logic_vector(0, 32), dr, tck, tms, tdi, tdo, cp);        
    print("JTAG TAP ID:" & tost(dr(31 downto 0)));
  end procedure;

  procedure jtag_rv_bypass_0(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer;
                    il  : in integer := 5) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    shift(false, il, conv_std_logic_vector(0, il), dr, tck, tms, tdi, tdo, cp);    -- 0x00 BYPASS
  end procedure;
  
  procedure jtag_rv_bypass(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer;
                    il  : in integer := 5) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    shift(false, il, conv_std_logic_vector(31, il), dr, tck, tms, tdi, tdo, cp);    -- 0x1F BYPASS
  end procedure;

  procedure jtag_rv_idcode(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer;
                    il  : in integer := 5) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    shift(false, il, conv_std_logic_vector(1, il), dr, tck, tms, tdi, tdo, cp);    -- 0x01 IDCODE
  end procedure;
  
  procedure jtag_rv_dtmcs(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer;
                    ir  : in integer := 16;
                    il  : in integer := 5) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    shift(false, il, conv_std_logic_vector(ir, il), dr, tck, tms, tdi, tdo, cp);    -- 0x10 DTMCS
  end procedure;
  
  procedure jtag_rv_dmi(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer;
                    ir  : in integer := 17;
                    il  : in integer := 5) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    shift(false, il, conv_std_logic_vector(ir, il), dr, tck, tms, tdi, tdo, cp);    -- 0x11 DMI
  end procedure;
  
  procedure jtag_rv_data(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    datain  : in std_logic_vector;
                    dataout : out std_logic_vector;
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    --clkj('0', '0', dc, tck, tms, tdi, tdo, cp);
    --clkj('0', '0', dc, tck, tms, tdi, tdo, cp);

    --clkj('0', '0', dc, tck, tms, tdi, tdo, cp);
    --clkj('0', '0', dc, tck, tms, tdi, tdo, cp);
    --clkj('0', '0', dc, tck, tms, tdi, tdo, cp);

    --shift data through BYPASS reg
    shift(true, datain'length, datain, dataout,
          tck, tms, tdi, tdo, cp);                
  end procedure;
  
  function rb (vi : std_logic_vector) return std_logic_vector is
    variable vo : std_logic_vector(vi'range);
  begin
    for i in vi'range loop
      vo(vo'length-1-i) := vi(i);
    end loop;
    return vo;
  end function;

  procedure jtag_rv_dmi_dmactive(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
    variable tmp  : std_logic_vector(40 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    -- DMCONTROL
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010000" & x"00000001" & "10"), tmp(40 downto 0), cp);
    --print("JTAG(DMI): Addr: " & tost(tmp(40 downto 34)) & " Data: " & tost(tmp(33 downto 2)) & " OP: " & tost(tmp(1 downto 0)));
  end procedure;

  procedure jtag_rv_dmi_halt(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
    variable tmp  : std_logic_vector(40 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    -- DMCONTROL
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010000" & x"80000001" & "10"), tmp(40 downto 0), cp);
    --print("JTAG(DMI): Addr: " & tost(tmp(40 downto 34)) & " Data: " & tost(tmp(33 downto 2)) & " OP: " & tost(tmp(1 downto 0)));
  end procedure;

  procedure jtag_rv_dmi_resume(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
    variable tmp  : std_logic_vector(40 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    -- DMCONTROL
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010000" & x"40000001" & "10"), tmp(40 downto 0), cp);
    --print("JTAG(DMI): Addr: " & tost(tmp(40 downto 34)) & " Data: " & tost(tmp(33 downto 2)) & " OP: " & tost(tmp(1 downto 0)));
  end procedure;

  procedure jtag_rv_dmi_set_pc(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    pc  : in std_logic_vector(31 downto 0);
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
    variable tmp  : std_logic_vector(40 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    -- DM ABS DATA0
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000100" & pc & "10"), tmp(40 downto 0), cp);
    -- DM ABS DATA1
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000101" & x"00000000" & "10"), tmp(40 downto 0), cp);

    -- DM ABS CMD (set dpc)
    --jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"003307B1" & "10"), tmp(40 downto 0), cp);

    -- DM ABS CMD (set a4)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"0033100e" & "10"), tmp(40 downto 0), cp);

    -- DM ABS CMD (set progbuf0)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0100000" & x"7b171073" & "10"), tmp(40 downto 0), cp);
    -- DM ABS CMD (set progbuf1)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0100001" & x"00100073" & "10"), tmp(40 downto 0), cp);
    -- DM ABS CMD (set a4)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"0034100e" & "10"), tmp(40 downto 0), cp);

    -- DM ABS STATUS
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010110" & x"00000000" & "01"), tmp(40 downto 0), cp);
    tmp := (others => '0');
    jtag_rv_data(tdo, tck, tms, tdi, rb(tmp), tmp(40 downto 0), cp);
    --tmp := rb(tmp);
    print("JTAG(DMI ABS STATUS): Addr: " & tost(tmp(40 downto 34)) & " Data: " & tost(tmp(33 downto 2)) & " OP: " & tost(tmp(1 downto 0)));
  end procedure;

  procedure jtag_rv_dmi_get_pc(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
    variable tmp  : std_logic_vector(40 downto 0);
    variable pch,pcl  : std_logic_vector(31 downto 0);
    variable a4h,a4l  : std_logic_vector(31 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    -- Save A4 (reg 0xe)
    -- DM ABS CMD (get a4)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"0032100e" & "10"), tmp(40 downto 0), cp);
    -- DM ABS DATA0
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000100" & x"00000000" & "01"), tmp(40 downto 0), cp);
    -- DM ABS DATA1
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000101" & x"00000000" & "01"), tmp(40 downto 0), cp);
    a4l := tmp(33 downto 2);
    jtag_rv_data(tdo, tck, tms, tdi, rb(tmp), tmp(40 downto 0), cp);
    a4h := tmp(33 downto 2);


    -- DM ABS CMD (set progbuf0)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0100000" & x"7b102773" & "10"), tmp(40 downto 0), cp);
    -- DM ABS CMD (set progbuf1)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0100001" & x"00100073" & "10"), tmp(40 downto 0), cp);
    -- DM ABS CMD (exec)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"0034100e" & "10"), tmp(40 downto 0), cp);


    -- DM ABS DATA0
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000100" & x"00000000" & "10"), tmp(40 downto 0), cp);
    -- DM ABS DATA1
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000101" & x"00000000" & "10"), tmp(40 downto 0), cp);
    -- DM ABS CMD (get a4)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"0032100e" & "10"), tmp(40 downto 0), cp);

    -- DM ABS DATA0
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000100" & x"00000000" & "01"), tmp(40 downto 0), cp);
    -- DM ABS DATA1
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000101" & x"00000000" & "01"), tmp(40 downto 0), cp);
    pcl := tmp(33 downto 2);
    jtag_rv_data(tdo, tck, tms, tdi, rb(tmp), tmp(40 downto 0), cp);
    pch := tmp(33 downto 2);

    -- Restore A4
    -- DM ABS DATA0
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000100" & a4l & "10"), tmp(40 downto 0), cp);
    -- DM ABS DATA1
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000101" & a4h & "10"), tmp(40 downto 0), cp);
    a4l := tmp(33 downto 2);
    jtag_rv_data(tdo, tck, tms, tdi, rb(tmp), tmp(40 downto 0), cp);
    a4h := tmp(33 downto 2);
    -- DM ABS CMD (get a4)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"0033100e" & "10"), tmp(40 downto 0), cp);


    print("JTAG(DMI PC): " & tost(pch&pcl));

    -- DM ABS STATUS
    --jtag_rv_data(tdo, tck, tms, tdi, rb("0010110" & x"00000000" & "01"), tmp(40 downto 0), cp);
    --tmp := (others => '0');
    --jtag_rv_data(tdo, tck, tms, tdi, rb(tmp), tmp(40 downto 0), cp);
    ----tmp := rb(tmp);
    --print("JTAG(DMI ABS STATUS): Addr: " & tost(tmp(40 downto 34)) & " Data: " & tost(tmp(33 downto 2)) & " OP: " & tost(tmp(1 downto 0)));
  end procedure;

  procedure jtag_rv_dmi_step(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    enable  : in boolean;
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
    variable tmp  : std_logic_vector(40 downto 0);
    variable a4h,a4l  : std_logic_vector(31 downto 0);
    variable en : std_logic;
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    en := conv_std_logic(enable);
    
    -- Save A4 (reg 0xe)
    -- DM ABS CMD (get a4)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"0032100e" & "10"), tmp(40 downto 0), cp);
    -- DM ABS DATA0
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000100" & x"00000000" & "01"), tmp(40 downto 0), cp);
    -- DM ABS DATA1
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000101" & x"00000000" & "01"), tmp(40 downto 0), cp);
    a4l := tmp(33 downto 2);
    jtag_rv_data(tdo, tck, tms, tdi, rb(tmp), tmp(40 downto 0), cp);
    a4h := tmp(33 downto 2);
    print("JTAG Step a4: " & tost(a4h&a4l));

    -- Update A4 to set step bit
    -- DM ABS DATA0
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000100" & x"0000000" & '0' & en & "11" & "10"), tmp(40 downto 0), cp);
    -- DM ABS DATA1
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000101" & x"00000000" & "10"), tmp(40 downto 0), cp);
    -- DM ABS CMD (get a4)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"0033100e" & "10"), tmp(40 downto 0), cp);

    -- Set DCSR (step bit)
    -- (csrw rs, csr)
    -- command [expr {($csr << 20) | ($reg << 15) | (1 << 12) | (0 << 7) | 0x73} ]
    -- DM ABS CMD (set progbuf0)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0100000" & x"7b071073" & "10"), tmp(40 downto 0), cp);
    -- DM ABS CMD (set progbuf1)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0100001" & x"00100073" & "10"), tmp(40 downto 0), cp);
    -- DM ABS CMD (csrw rs, csr)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"0034100e" & "10"), tmp(40 downto 0), cp);

    -- Restore A4
    -- DM ABS DATA0
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000100" & a4l & "10"), tmp(40 downto 0), cp);
    -- DM ABS DATA1
    jtag_rv_data(tdo, tck, tms, tdi, rb("0000101" & a4h & "10"), tmp(40 downto 0), cp);
    -- DM ABS CMD (get a4)
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010111" & x"0033100e" & "10"), tmp(40 downto 0), cp);

    -- DM ABS STATUS
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010110" & x"00000000" & "01"), tmp(40 downto 0), cp);
    tmp := (others => '0');
    jtag_rv_data(tdo, tck, tms, tdi, rb(tmp), tmp(40 downto 0), cp);
    --tmp := rb(tmp);
    print("JTAG(DMI ABS STATUS): Addr: " & tost(tmp(40 downto 34)) & " Data: " & tost(tmp(33 downto 2)) & " OP: " & tost(tmp(1 downto 0)));
  end procedure;

  procedure jtag_rv_dmi_read_dmctrl(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
    variable tmp  : std_logic_vector(40 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    -- DMCONTROL
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010000" & x"00000000" & "01"), tmp(40 downto 0), cp);
    tmp := (others => '0');
    jtag_rv_data(tdo, tck, tms, tdi, rb(tmp), tmp(40 downto 0), cp);
    --tmp := rb(tmp);
    print("JTAG(DMI DMCTRL): Addr: " & tost(tmp(40 downto 34)) & " Data: " & tost(tmp(33 downto 2)) & " OP: " & tost(tmp(1 downto 0)));
  end procedure;

  procedure jtag_rv_dmi_read_dmstatus(signal tdo : in std_ulogic;
                    signal tck, tms, tdi : out std_ulogic;
                    cp  : in integer) is
    variable dc : std_ulogic;
    variable dr : std_logic_vector(32 downto 0);
    variable tmp  : std_logic_vector(40 downto 0);
  begin
  
    tck <= '0'; tms <= '0'; tdi <= '0';

    -- DMCONTROL
    jtag_rv_data(tdo, tck, tms, tdi, rb("0010001" & x"00000000" & "01"), tmp(40 downto 0), cp);
    tmp := (others => '0');
    jtag_rv_data(tdo, tck, tms, tdi, rb(tmp), tmp(40 downto 0), cp);
    --tmp := rb(tmp);
    print("JTAG(DMI DMSTATUS): Addr: " & tost(tmp(40 downto 34)) & " Data: " & tost(tmp(33 downto 2)) & " OP: " & tost(tmp(1 downto 0)));
  end procedure;

end;
-- pragma translate_on
