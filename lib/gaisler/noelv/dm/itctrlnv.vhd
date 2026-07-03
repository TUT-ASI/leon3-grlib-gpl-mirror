------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
-- Entity:      itctrl5
-- File:        itctrl5.vhd
-- Author:      Magnus Hjorth, Cobham Gaisler
-- Description: Instruction trace buffer control/interface logic for LEON5
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.l5nv_shared.all;
use gaisler.noelv.all;
use gaisler.dmnvint.all;

entity itctrlnv is
  generic (
    ncpu     : integer;
    entr     : integer;
    scantest : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    tpi      : in  nv_full_trace_vector(0 to NCPU-1);
    iti      : in  dev_reg_in_type;
    ito      : out dev_reg_out_type;
    d_i      : out itracebuf_in_type5_array(0 to ncpu-1);
    d_o      : in  itracebuf_out_type5_array(0 to ncpu-1);
    hartsel  : in  std_logic_vector(19 downto 0);
    rsten    : in  std_ulogic
    );
end;

architecture rtl of itctrlnv is
  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  constant l2entr  : integer := log2ext(entr);

  constant NBITS     : integer := log2x(ncpu);
  constant PROC_H    : integer := 22+NBITS-1;
  constant PROC_L    : integer := 22;

  subtype itbi_data_type is std_logic_vector(TRACE_WIDTH-1 downto 0);

  type it_reg_type is record
    trace_upd       : std_logic;
    enable          : std_logic;
    sample0         : itbi_data_type;
    sample1         : itbi_data_type;
    valid           : std_logic_vector(1 downto 0);
    -- +log2(NCPU) is used for instruction trace combining accross processors
    reg_acc         : std_ulogic;
    reg_wr          : std_ulogic;
    reg_wrdata      : std_logic_vector(31 downto 0);
    buf_read        : std_logic;
    buf_read2       : std_logic;
    buf_ready       : std_logic;
    buf_read_addr   : std_logic_vector(l2entr-1+5 downto 0);
    buf_rdata       : std_logic_vector(31 downto 0);
    pointer         : std_logic_vector(l2entr-1+log2(NCPU) downto 0);
    pointer_inc     : std_logic_vector(l2entr-1+log2(NCPU) downto 0);
    set_pointer_inc : std_logic;
  end record;
  constant it_reg_none: it_reg_type := (
    '0', '0',
    (others => '0'), (others => '0'),
    "00", '0', '0', (others => '0'), '0', '0', '0', (others => '0'), (others => '0'), (others => '0'), (others => '0'), '0'
    );

  type it_reg_array_type is array (0 to NCPU-1) of it_reg_type;

  type common_reg_type is record
    reg_addr_pipe  : std_logic_vector(31 downto 0);
    buf_rdy_pipe   : std_ulogic;
    buf_rdata_pipe : std_logic_vector(31 downto 0);
  end record;
  constant common_reg_none : common_reg_type := (
    (others => '0'), '0', (others => '0'));

  signal itr, nitr: it_reg_array_type;
  signal cr, ncr: common_reg_type;

  signal arst           : std_ulogic;
begin
  arst        <= iti.testrst when (ASYNC_RESET and scantest/=0 and iti.testen/='0') else
                 rstn when ASYNC_RESET else '1';

  comb: process(itr,cr,rstn,iti,d_o,rsten,tpi,hartsel) --,tcoack)
    variable v    : it_reg_array_type;
    variable cv   : common_reg_type;
    variable oito : dev_reg_out_type;
    variable odi  : itracebuf_in_type5_array(0 to ncpu-1);
    subtype itbi_address_add_type is std_logic_vector(l2entr+log2(NCPU) downto 0);
    type itbi_address_add_array_type is array (0 to NCPU-1) of itbi_address_add_type;
    variable vit_pointer     : itbi_address_add_array_type;
    variable vit_pointer_inc : itbi_address_add_array_type;

    procedure it_reg_access(regaddr: std_logic_vector(4 downto 0);
                            cpuidx: integer range 0 to NCPU-1;
                            wr: std_ulogic; wdata: std_logic_vector; rdata: out std_logic_vector) is
      variable vrd, vwd: std_logic_vector(31 downto 0);
    begin
      vwd := wdata;
      vrd := (others => '0');
      case regaddr is
        -- 0x180 - 0x1FC Instruction trace control
        when "00000" =>          -- 0x180 itrace pointer
          vrd := (others=>'0');
          vrd(l2entr-1 downto 0) := itr(cpuidx).pointer(l2entr-1 downto 0);
          if wr = '1' then
            v(cpuidx).pointer := vwd(l2entr-1+log2(NCPU) downto 0);
            v(cpuidx).set_pointer_inc := '1';
          end if;
        when "00001" =>         -- 0x184 itrace control-1
          vrd               := (others => '0');
          vrd(23)           := itr(cpuidx).enable;
          if wr = '1' and itr(cpuidx).trace_upd='0' then
            v(cpuidx).enable      := vwd(23);
          end if;
        when "00010" => null;         -- 0x188
        when "00011" => null;         -- 0x18C
        when "00100" => null;         -- 0x190
        when "00101" => null;         -- 0x194
        when "00110" => null;         -- 0x198
        when "00111" => null;         -- 0x19C
        when "01000" => null;         -- 0x1A0
        when "01001" => null;         -- 0x1A4
        when "01010" => null;         -- 0x1A8
        when "01011" => null;         -- 0x1AC
        when "01100" => null;         -- 0x1B0
        when "01101" => null;         -- 0x1B4
        when "01110" => null;         -- 0x1B8
        when "01111" => null;         -- 0x1BC
        when "10000" => null;         -- 0x1C0
        when "10001" => null;         -- 0x1C4
        when "10010" => null;         -- 0x1C8
        when "10011" => null;         -- 0x1CC
        when "10100" => null;         -- 0x1D0
        when "10101" => null;         -- 0x1D4
        when "10110" => null;         -- 0x1D8
        when "10111" => null;         -- 0x1DC
        when "11000" => null;         -- 0x1E0
        when "11001" => null;         -- 0x1E4
        when "11010" => null;         -- 0x1E8
        when "11011" => null;         -- 0x1EC
        when "11100" => null;         -- 0x1F0
        when "11101" => null;         -- 0x1F4
        when "11110" => null;         -- 0x1F8
        when others  => null;         -- 0x1FC
      end case;
      rdata := vrd;
    end it_reg_access;

  begin
    v := itr;
    cv := cr;
    oito := dev_reg_out_none;
    odi := (others => itracebuf_in_type5_none);


    --------------------------------------------------------------------------
    -- Core instruction trace logic
    --------------------------------------------------------------------------
    --by default lane0 (old instruction resides on 383 downto 192)

    for i in 0 to NCPU-1 loop
      vit_pointer(i) := std_logic_vector(unsigned('0'&itr(i).pointer)+1);
      vit_pointer_inc(i) := std_logic_vector(unsigned('0'&itr(i).pointer)+2);
      odi(i).enable := "00";
      odi(i).write  := "00";
      odi(i).addr0  := (others=>'0');
      odi(i).addr1  := (others=>'0');
    end loop;

    for i in 0 to NCPU-1 loop
      v(i).sample0 := tpi(i).tdata;
      if itr(i).set_pointer_inc = '1' then
        v(i).pointer_inc :=  vit_pointer(i)(l2entr-1+log2(NCPU) downto 0);
        v(i).set_pointer_inc := '0';
      end if;

      v(i).buf_ready := itr(i).buf_read2;
      v(i).buf_read2 := itr(i).buf_read or itr(i).reg_acc;
      if itr(i).buf_read = '0' and itr(i).reg_acc='0' then
        v(i).buf_ready := '0';
      end if;

      if itr(i).buf_read = '1' then
        v(i).buf_read2 := '1';
        odi(i).enable := "11";
        odi(i).write  := "00";
        odi(i).addr0(log2(entr/2)-1 downto 0) := itr(i).buf_read_addr(l2entr-1+5 downto 6);
        odi(i).addr1(log2(entr/2)-1 downto 0) := itr(i).buf_read_addr(l2entr-1+5 downto 6);
      end if;

      if itr(i).reg_acc='1' and itr(i).buf_read2='0' then
        -- it_reg_access call placed below trace pipeline code to avoid
        -- creating a long path with reg write updating v(i).pointer that
        -- then gets used in pipeline code.
        v(i).buf_read2 := '1';
      end if;

      if notx(itr(i).buf_read_addr) then
        for j in 0 to 15 loop
          if j = to_integer(unsigned(itr(i).buf_read_addr(5 downto 2))) and itr(i).reg_acc='0' then
          v(i).buf_rdata := d_o(i).data((j+1)*32-1 downto j*32);
          end if;
        end loop;
      else
        setx(v(i).buf_rdata);
      end if;

    end loop;

    for i in 0 to NCPU-1 loop
      if itr(i).enable = '1' then
        if itr(i).valid = "01" or itr(i).valid = "10" then
          v(i).pointer := vit_pointer(i)(l2entr-1+log2(NCPU) downto 0);
          v(i).pointer_inc := vit_pointer_inc(i)(l2entr-1+log2(NCPU) downto 0);
        elsif itr(i).valid = "11" then
          vit_pointer(i) := std_logic_vector(unsigned('0'&itr(i).pointer)+2);
          vit_pointer_inc(i) := std_logic_vector(unsigned('0'&itr(i).pointer)+3);
          v(i).pointer := vit_pointer(i)(l2entr-1+log2(NCPU) downto 0);
          v(i).pointer_inc := vit_pointer_inc(i)(l2entr-1+log2(NCPU) downto 0);
        end if;
      end if;
    end loop;

    for i in 0 to NCPU-1 loop
        v(i).valid := "00";
        if itr(i).enable = '1' then
          -- Valid1     = bit[383] Also needs to be one when FPU results (bit[12])
          -- Exception1 = bit[382]
          -- Valid0     = bit[127] Always needs to be 1 to include timestamp
          -- Exception0 = bit[126]
          if (itr(i).sample0(383) = '1' or itr(i).sample0(382) = '1' or itr(i).sample0(12) = '1') or -- and
             (itr(i).sample0(127) = '1' or itr(i).sample0(126) = '1') then
            if v(i).pointer(0) = '0' then
              v(i).sample1 := itr(i).sample0;
              v(i).valid := "11";
            end if;
          end if;
        end if;
    end loop;

    for i in 0 to NCPU-1 loop
      if itr(i).valid = "01" or itr(i).valid = "10" then
        odi(i).addr0(log2(entr/2)-1 downto 0) := itr(i).pointer(l2entr-1 downto 1);
        odi(i).addr1(log2(entr/2)-1 downto 0) := itr(i).pointer(l2entr-1 downto 1);
        if itr(i).pointer(0) = '0' then
          odi(i).enable(0) := '1';
          odi(i).write(0) := '1';
        else
          odi(i).enable(1) := '1';
          odi(i).write(1) := '1';
        end if;
      elsif itr(i).valid = "11" then
        odi(i).addr0(log2(entr/2)-1 downto 0) := itr(i).pointer(l2entr-1 downto 1);
        odi(i).addr1(log2(entr/2)-1 downto 0) := itr(i).pointer(l2entr-1 downto 1);
        odi(i).enable := "11";
        odi(i).write := "11";
        if itr(i).pointer(0) = '1' then
          odi(i).addr0(log2(entr/2)-1 downto 0) := itr(i).pointer_inc(l2entr-1 downto 1);
        end if;
      end if;
      odi(i).data0 := itr(i).sample1(255 downto 0);
      odi(i).data1 := itr(i).sample1(511 downto 256);
    end loop;

    --------------------------------------------------------------------------
    -- External register interface (via debug module)
    --------------------------------------------------------------------------

    if iti.sel/="0000" then oito.rdy := '1'; end if;
    oito.data := cr.buf_rdata_pipe;
    if iti.sel(0)='1' then
      oito.rdy := cr.buf_rdy_pipe;
    end if;
    if iti.sel(1)='1' then
      oito.rdy := cr.buf_rdy_pipe;
    end if;
    cv.buf_rdy_pipe := '0';
    for i in 0 to NCPU-1 loop
      if itr(i).reg_acc='1' and itr(i).buf_read2='0' then
        it_reg_access(itr(i).buf_read_addr(6 downto 2), i, itr(i).reg_wr, itr(i).reg_wrdata, v(i).buf_rdata);
      end if;
      v(i).buf_read := '0';
      v(i).buf_read_addr := iti.addr(l2entr-1+5 downto 2) & "00";
      v(i).reg_acc := '0';
      v(i).reg_wr := iti.wr;
      v(i).reg_wrdata := iti.data;
      if itr(i).buf_ready='1' then
        cv.buf_rdy_pipe := '1';
        cv.buf_rdata_pipe := itr(i).buf_rdata;
      end if;
      if hartsel(NBITS-1 downto 0)=std_logic_vector(to_unsigned(i,NBITS)) then
        if iti.sel(0)='1' then
          v(i).reg_acc := '1';
        end if;
        if iti.sel(1)='1' then
          v(i).buf_read := '1';
          -- TODO write into itrace?
        end if;
      end if;
    end loop;

    --------------------------------------------------------------------------
    -- Reset
    --------------------------------------------------------------------------
    if rstn='0' then
      for i in 0 to NCPU-1 loop
        v(i).trace_upd       := it_reg_none.trace_upd;
        v(i).valid           := it_reg_none.valid;
        v(i).pointer         := it_reg_none.pointer;
        v(i).pointer_inc     := it_reg_none.pointer_inc;
        v(i).buf_read        := it_reg_none.buf_read;
        v(i).buf_read2       := it_reg_none.buf_read2;
        v(i).buf_ready       := it_reg_none.buf_ready;
        v(i).set_pointer_inc := it_reg_none.set_pointer_inc;
        v(i).enable          := rsten;
      end loop;
    end if;

    nitr <= v;
    ncr <= cv;
    ito <= oito;
    d_i <= odi;
  end process;

  syncrregs : if not ASYNC_RESET generate
    regs: process(clk)
    begin
      if rising_edge(clk) then
        cr <= ncr;
        itr <= nitr;
      end if;
    end process;
  end generate;

  asyncrregs : if ASYNC_RESET generate
    regs: process(clk, arst)
    begin
      if arst = '0' then
        for i in 0 to NCPU-1 loop
          itr(i) <= it_reg_none;
        end loop;
        cr <= common_reg_none;
      elsif rising_edge(clk) then
        cr <= ncr;
        itr <= nitr;
      end if;
    end process;
  end generate;
end;
