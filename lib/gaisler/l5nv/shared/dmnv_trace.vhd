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
-- Entity:      dmnv_trace
-- File:        dmnv_trace.vhd
-- Author:      Nils Wessman
-- Description: AHB trace module
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.l5nv_shared.all;

entity dmnv_trace is
  generic (
    fabtech   : integer;
    memtech   : integer;
    cbusw     : integer;
    addrbits  : integer                 := 6;
    ahbwp     : integer                 := 2;
    tbits     : integer                 := 30;
    api       : integer                 := 1;
    scantest  : integer                 := 0
    );
  port (
    clk         : in  std_ulogic;
    rstn        : in  std_ulogic;
    tri         : in  dev_reg_in_type;
    tro         : out dev_reg_out_type;
    cbmi        : in  ahb_mst_in_type;
    cbsi        : in  ahb_slv_in_type;
    rsten       : in  std_ulogic;
    timer       : in  std_logic_vector(tbits-1 downto 0)
    );
end;

architecture rtl of dmnv_trace is
  -- Constants --------------------------------------------------------------

  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant AREA_H       : integer := 21;
  constant AREA_L       : integer := 19;

  constant TRACEN       : boolean := (addrbits /= 0);
  constant AHBWATCH     : boolean := TRACEN and (ahbwp /= 0);
  constant TBUFABITS    : integer := 6;

  constant nbus : integer := 1  -- conventional
                             ;
  constant CONV : integer := nbus-1;

  constant maxbusw      : integer := cbusw
                                     ;
  type rd_array_type is array (0 to nbus-1) of std_logic_vector(AHBDW-1 downto 0);
  type resp_array_type is array (0 to nbus-1) of std_logic_vector(1 downto 0);

  function ahbwp_nz return integer is
  begin
    if (ahbwp /= 0) and (addrbits /= 0) then return 1; end if;
    return 0;
  end function ahbwp_nz;

  type trace_break_reg is record
    addr          : std_logic_vector(31 downto 2);
    mask          : std_logic_vector(31 downto 2);
    read          : std_logic;
    write         : std_logic;
  end record;
  constant trace_break_reg_none: trace_break_reg := (
    (others => '0'), (others => '0'), '0', '0' );

  type trace_break_reg_vector is array (1 to 2) of trace_break_reg;

  type trace_reg_type is record
    s2haddr       : std_logic_vector(31 downto 0);
    s2hwrite      : std_logic;
    s2htrans      : std_logic_vector(1 downto 0);
    s2hsize       : std_logic_vector(2 downto 0);
    s2hburst      : std_logic_vector(2 downto 0);
    s2hmaster     : std_logic_vector(3 downto 0);
    s2hmastlock   : std_logic;
    s2hresp       : std_logic_vector(1 downto 0);
    s2data        : std_logic_vector(maxbusw-1 downto 0);
    s1haddr       : std_logic_vector(31 downto 0);
    s1hwrite      : std_logic;
    s1htrans      : std_logic_vector(1 downto 0);
    s1hsize       : std_logic_vector(2 downto 0);
    s1hburst      : std_logic_vector(2 downto 0);
    s1hmaster     : std_logic_vector(3 downto 0);
    s1hmastlock   : std_logic;
    aindex        : std_logic_vector(TBUFABITS - 1 downto 0); -- buffer index
    buf_ptr       : integer range 0 to 7;
  end record;

  constant trace_reg_none: trace_reg_type := (
    s2haddr       => x"00000000",
    s2hwrite      => '0',
    s2htrans      => "00",
    s2hsize       => "000",
    s2hburst      => "000",
    s2hmaster     => "0000",
    s2hmastlock   => '0',
    s2hresp       => "00",
    s2data        => (others => '0'),
    s1haddr       => x"00000000",
    s1hwrite      => '0',
    s1htrans      => "00",
    s1hsize       => "000",
    s1hburst      => "000",
    s1hmaster     => "0000",
    s1hmastlock   => '0',
    aindex        => (others => '0'),
    buf_ptr       => 0
    );
    
  type trace_reg_array is array(0 to nbus-1) of trace_reg_type;

  type trace_ctrl_type is record
    buf_ptr       : integer range 0 to 7;
    aindex        : std_logic_vector(TBUFABITS - 1 downto 0); -- buffer index
    enable        : std_logic;  -- trace enable
    buf_out       : integer range 0 to 7; -- buffer muxed to output
    bphit         : std_logic;  -- AHB breakpoint hit
    bphit2        : std_logic;  -- delayed bphit
    dcnten        : std_logic;  -- delay counter enable
    delaycnt      : std_logic_vector(15 downto 0); -- delay counter
    tbreg         : trace_break_reg_vector;    -- AHB breakpoint 1 and 2
    tbwr          : std_logic;  -- trace buffer write enable
    break         : std_logic;  -- break CPU when AHB tracing stops
    tforce        : std_logic;  -- Force AHB trace
    timeren       : std_logic;  -- Keep timer enabled
    sample        : std_logic;  -- Force sample
    edbgmtf       : std_logic;  -- Enable debug mode timer freeze
  end record;

  constant trace_ctrl_none: trace_ctrl_type := (
    buf_ptr       => 0,
    aindex        => (others => '0'),
    enable        => '0',
    buf_out       => 0,
    bphit         => '0',
    bphit2        => '0',
    dcnten        => '0',
    delaycnt      => (others => '0'),
    tbreg         => (others => trace_break_reg_none),
    tbwr          => '0',
    break         => '0',
    tforce        => '0',
    timeren       => '0',
    sample        => '0',
    edbgmtf       => '0'
    );

  type trace_data_break_match_reg is record
    data          : std_logic_vector((maxbusw-1)*ahbwp_nz downto 0);
    mask          : std_logic_vector((maxbusw-1)*ahbwp_nz downto 0);
    en            : std_ulogic;
    couple        : std_ulogic;
    inv           : std_ulogic;
  end record;
  constant trace_data_break_match_reg_none: trace_data_break_match_reg := (
    (others => '0'), (others => '0'), '0', '0', '0'
    );

  type trace_data_break_match_reg_vector is array (1 to 2) of trace_data_break_match_reg;

  function ahbwp_pipe return integer is
  begin
    if (ahbwp = 2) and (addrbits /= 0) then return 1; end if;
    return 0;
  end function ahbwp_pipe;

   type trace_data_break_pipe_reg is record
    data    : std_logic_vector((maxbusw-1)*ahbwp_pipe downto 0);
    wpcheck : std_logic_vector(trace_data_break_match_reg_vector'range);
    hready  : std_ulogic;
    wphit   : std_logic_vector(trace_data_break_match_reg_vector'range);
   end record;
  constant trace_data_break_pipe_reg_none : trace_data_break_pipe_reg := (
    (others => '0'), (others => '0'), '0', (others => '0')
    );

  type watch_reg_type is record
    reg  : trace_data_break_match_reg_vector;
    pipe : trace_data_break_pipe_reg;
  end record;
  constant watch_reg_none : watch_reg_type := (
    reg => (others => trace_data_break_match_reg_none),
    pipe => trace_data_break_pipe_reg_none
    );

  type reg_type is record
    -- Registers for tracing
    tr      : trace_reg_array;
    tr_ctrl : trace_ctrl_type;
    twr     : watch_reg_type;
    hold    : std_ulogic;
  end record;

  constant RES_T : reg_type := (
    tr      => (others => trace_reg_none),
    tr_ctrl => trace_ctrl_none,
    twr     => watch_reg_none,
    hold    => '0');

  -- Signals ----------------------------------------------------------------
  signal r, rin         : reg_type;
  signal arst           : std_ulogic;

  signal tbi  :  tracebuf_mbus_in_array;
  signal tbo  :  tracebuf_mbus_out_array;

begin
  arst        <= tri.testrst when (ASYNC_RESET and scantest/=0 and tri.testen/='0') else
                 rstn when ASYNC_RESET else '1';

  comb : process (r, tri, cbmi, cbsi, timer,
                  tbo)
    variable v                  : reg_type;
    variable otro           : dev_reg_out_type;
    -- trace
    variable otbi           : tracebuf_mbus_in_array;
    variable tr_buses       : ahb_slv_in_vector_type(0 to nbus);
    variable rd_array       : rd_array_type;
    variable resp_array     : resp_array_type;
    variable buf_ptr        : integer range 0 to 7 := 0;
    variable aindex         : std_logic_vector(TBUFABITS - 1 downto 0); 
    variable indexwr        : std_ulogic;
    variable buf_out_index  : integer range 0 to 7 := 0;
    variable tr_hit         : std_ulogic;

    procedure trace_reg_access(
      addr    : in  std_logic_vector(31 downto 0);
      wr      : in  std_ulogic;
      wdata   : in  std_logic_vector;
      rdata   : out std_logic_vector;
      indexwr : out std_ulogic) is
      variable vrd     : std_logic_vector(31 downto 0);
      variable vwd     : std_logic_vector(wdata'length - 1 downto 0);
      variable hasel2  : std_logic_vector(8 downto 2) := addr(8 downto 2);
    begin
      vwd := wdata;
      vrd := (others => '0');
      indexwr := '0';
      case hasel2 is
        -- 0x100 - 0x17C AHB trace control
        when "1000000" =>               -- 0x100
          if TRACEN then
            vrd(31 downto 16) := r.tr_ctrl.delaycnt;
            vrd(9) := r.tr_ctrl.bphit;
            vrd(8) := r.tr_ctrl.edbgmtf;
            vrd(6 downto 5) := r.tr_ctrl.timeren & r.tr_ctrl.tforce;
            vrd(4 downto 0) := conv_std_logic_vector(log2(maxbusw/32), 2) & r.tr_ctrl.break & r.tr_ctrl.dcnten & r.tr_ctrl.enable;
            if wr = '1' then
              v.tr_ctrl.delaycnt := vwd(31 downto 16);
              v.tr_ctrl.bphit    := vwd(9);
              v.tr_ctrl.edbgmtf  := vwd(8);
              v.tr_ctrl.sample   := vwd(7);
              v.tr_ctrl.timeren  := vwd(6);
              v.tr_ctrl.tforce   := vwd(5);
              v.tr_ctrl.break    := vwd(2);
              v.tr_ctrl.dcnten   := vwd(1);
              v.tr_ctrl.enable   := vwd(0);
            end if;
          end if;
        when "1000001" =>               -- 0x104
          if TRACEN then
            vrd((TBUFABITS - 1 + 0) downto 0) := r.tr_ctrl.aindex;
            vrd(18 downto 16) := conv_std_logic_vector(r.tr_ctrl.buf_ptr, 3);
            vrd(26 downto 24) := conv_std_logic_vector(r.tr_ctrl.buf_out, 3);
            if wr = '1' then
              v.tr_ctrl.aindex := vwd((TBUFABITS - 1 + 0) downto 0);
              v.tr_ctrl.buf_ptr := to_integer(unsigned(vwd(18 downto 16)));
              v.tr_ctrl.buf_out := to_integer(unsigned(vwd(26 downto 24)));
              indexwr := '1';
            end if;
          end if;
        when "1000010" =>               -- 0x108 
          if TRACEN then
            vrd(31 downto 28) := conv_std_logic_vector(nbus, 4);
            vrd(27 downto 24) := conv_std_logic_vector(TBUFABITS-1, 4);
            vrd(21 downto 20) := conv_std_logic_vector(log2(cbusw/32), 2);
            vrd(2 downto 0) := conv_std_logic_vector(r.tr_ctrl.buf_ptr, 3);
            if wr = '1' then
              v.tr_ctrl.buf_out := to_integer(unsigned(vwd(2 downto 0)));
            end if;
          end if;

        when "1000011" =>               -- 0x10C
          if AHBWATCH then
            vrd(7 downto 0) := '0' & r.twr.reg(2).inv & r.twr.reg(2).couple & r.twr.reg(2).en &
                                  '0' & r.twr.reg(1).inv & r.twr.reg(1).couple & r.twr.reg(1).en;
            if wr = '1' then
              v.twr.reg(2).inv    := vwd(6);
              v.twr.reg(2).couple := vwd(5);
              v.twr.reg(2).en     := vwd(4);
              v.twr.reg(1).inv    := vwd(2);
              v.twr.reg(1).couple := vwd(1);
              v.twr.reg(1).en     := vwd(0);
            end if;
          end if;
        when "1000100" =>               -- 0x110
          if TRACEN then
            vrd(31 downto 2) := r.tr_ctrl.tbreg(1).addr;
            if wr = '1' then
              v.tr_ctrl.tbreg(1).addr := vwd(31 downto 2);
            end if;
          end if;
        when "1000101" =>               -- 0x114
          if TRACEN then
            vrd := r.tr_ctrl.tbreg(1).mask & r.tr_ctrl.tbreg(1).read & r.tr_ctrl.tbreg(1).write;
            if wr = '1' then
              v.tr_ctrl.tbreg(1).mask := vwd(31 downto 2);
              v.tr_ctrl.tbreg(1).read := vwd(1);
              v.tr_ctrl.tbreg(1).write := vwd(0);
            end if;
          end if;
        when "1000110" =>               -- 0x118
          if TRACEN then
            vrd(31 downto 2) := r.tr_ctrl.tbreg(2).addr;
            if wr = '1' then
              v.tr_ctrl.tbreg(2).addr := vwd(31 downto 2);
            end if;
          end if;
        when "1000111" =>               -- 0x11C
          if TRACEN then
            vrd := r.tr_ctrl.tbreg(2).mask & r.tr_ctrl.tbreg(2).read & r.tr_ctrl.tbreg(2).write;
            if wr = '1' then
              v.tr_ctrl.tbreg(2).mask := vwd(31 downto 2);
              v.tr_ctrl.tbreg(2).read := vwd(1);
              v.tr_ctrl.tbreg(2).write := vwd(0);
            end if;
          end if;
        when "1001000" | "1001001" | "1001010" | "1001011" =>  --  0x120-0x12C
          if AHBWATCH then
            for i in 0 to 3 loop
              if i = conv_integer(hasel2(3 downto 2)) then
                vrd(31*ahbwp_nz downto 0) :=
                  r.twr.reg(1).data(((127-i*32) mod maxbusw)*ahbwp_nz downto ((96*i-32) mod maxbusw)*ahbwp_nz);
                if wr = '1' then
                  v.twr.reg(1).data(((127-i*32) mod maxbusw)*ahbwp_nz downto ((96*i-32) mod maxbusw)*ahbwp_nz) :=
                    vwd(31*ahbwp_nz downto 0);
                end if;
              end if;
            end loop;
          end if;
        when "1001100" | "1001101" | "1001110" | "1001111" =>  -- 0x130-0x13C
          if AHBWATCH then
            for i in 0 to 3 loop
              if i = conv_integer(hasel2(3 downto 2)) then
                vrd(31*ahbwp_nz downto 0) :=
                  r.twr.reg(1).mask(((127-i*32) mod maxbusw)*ahbwp_nz downto ((96*i-32) mod maxbusw)*ahbwp_nz);
                if wr = '1' then
                  v.twr.reg(1).mask(((127-i*32) mod maxbusw)*ahbwp_nz downto ((96*i-32) mod maxbusw)*ahbwp_nz) :=
                    vwd(31*ahbwp_nz downto 0);
                end if;
              end if;
            end loop;
          end if;
        when "1010000" | "1010001" | "1010010" | "1010011" =>  -- 0x140-0x14C
          if AHBWATCH then
            for i in 0 to 3 loop
              if i = conv_integer(hasel2(3 downto 2)) then
                vrd(31*ahbwp_nz downto 0) :=
                  r.twr.reg(2).data(((127-i*32) mod maxbusw)*ahbwp_nz downto ((96*i-32) mod maxbusw)*ahbwp_nz);
                if wr = '1' then
                  v.twr.reg(2).data(((127-i*32) mod maxbusw)*ahbwp_nz downto ((96*i-32) mod maxbusw)*ahbwp_nz) :=
                    vwd(31*ahbwp_nz downto 0);
                end if;
              end if;
            end loop;
          end if;
        when "1010100" | "1010101" | "1010110" | "1010111" =>  -- 0x150-0x15C
          if AHBWATCH then
            for i in 0 to 3 loop
              if i = conv_integer(hasel2(3 downto 2)) then
                vrd(31*ahbwp_nz downto 0) :=
                  r.twr.reg(2).mask(((127-i*32) mod maxbusw)*ahbwp_nz downto ((96*i-32) mod maxbusw)*ahbwp_nz);
                if wr = '1' then
                  v.twr.reg(2).mask(((127-i*32) mod maxbusw)*ahbwp_nz downto ((96*i-32) mod maxbusw)*ahbwp_nz) :=
                    vwd(31*ahbwp_nz downto 0);
                end if;
              end if;
            end loop;
          end if;
        when "1011000" => null;         -- 0x160
        when "1011001" => null;         -- 0x164
        when "1011010" => null;         -- 0x168
        when "1011011" => null;         -- 0x16C
        when "1011100" => null;         -- 0x170
        when "1011101" => null;         -- 0x174
        when "1011110" => null;         -- 0x178
        when "1011111" => null;         -- 0x17C
        when others =>
          null;
      end case;
      rdata := vrd;
    end trace_reg_access;

    procedure trace_data_access(
      addr    : in  std_logic_vector(31 downto 0);
      wr      : in  std_ulogic;
      hold    : in  std_ulogic;
      wdata   : in  std_logic_vector;
      rdata   : out std_logic_vector) is
      variable vrd     : std_logic_vector(31 downto 0);
      variable vwd     : std_logic_vector(wdata'length - 1 downto 0);
      variable first   : std_ulogic;
      variable hasel3  : std_logic_vector(4 downto 2) := addr(4 downto 2);
    begin
      vwd := wdata;
      vrd := (others => '0');
      first := not hold;

      buf_out_index := r.tr_ctrl.buf_out;
      if maxbusw=32 then
        otbi(buf_out_index).addr := addr(otbi(0).addr'length+3 downto 4);
        hasel3(4) := '0';
      else
        otbi(buf_out_index).addr := addr(otbi(0).addr'length+4 downto 5);
      end if;

      for x in 0 to otbi(0).data'length/32-1 loop
        otbi(buf_out_index).data(x*32+31 downto x*32) := vwd;
      end loop;
      if TRACEN then
        if first = '1' then otbi(buf_out_index).enable := '1'; end if;
        case hasel3 is
          when "000" =>
            vrd := tbo(buf_out_index).data(31 downto 0);
            if wr = '1' and first = '1' then
              otbi(buf_out_index).write(0) := '1';
            end if;
          when "001" =>
            vrd := tbo(buf_out_index).data(63 downto 32);
            if wr = '1' and first = '1' then
              otbi(buf_out_index).write(1) := '1';
            end if;
          when "010" =>
            vrd := tbo(buf_out_index).data(95 downto 64);
            if wr = '1' and first = '1' then
              otbi(buf_out_index).write(2) := '1';
            end if;
          when "011" =>
            vrd := tbo(buf_out_index).data(127 downto 96);
            if wr = '1' and first = '1' then
              otbi(buf_out_index).write(3) := '1';
            end if;
          when "100" =>
            vrd := tbo(buf_out_index).data(159 downto 128);
            if wr = '1' and first = '1' then
              otbi(buf_out_index).write(4) := '1';
            end if;
          when "101" =>
              if maxbusw > 64 then
                vrd := tbo(buf_out_index).data(191 downto 160);
                if wr = '1' and first = '1' then
                  otbi(buf_out_index).write(5) := '1';
                end if;
              else vrd := zero32; end if;
          when "110" =>
              if maxbusw > 64 then
                vrd := tbo(buf_out_index).data(223 downto 192);
                if wr = '1' and first = '1' then
                  otbi(buf_out_index).write(6) := '1';
                end if;
              else vrd := zero32; end if;
          when others =>
              vrd := zero32;
        end case;
        rdata := vrd;
      end if;
    end trace_data_access;
  begin

    ---------------------------------------------------------------------------------
    -- Defaults
    ---------------------------------------------------------------------------------
    v := r;

    otbi      := (others => tracebuf_mbus_in_type_none);
    tr_buses  := (others => ahbs_in_none);


    -- join cpusi and all stripes into common ahb_slv_in vector, used by ahb tracer
    tr_buses(CONV) := cbsi;
    for x in 0 to AHBDW/32 - 1 loop
      rd_array(CONV)(x*32 + 31 downto x*32) := cbmi.hrdata((x*32 mod cbusw)+31 downto (x*32 mod cbusw));
    end loop;
    resp_array(CONV) := cbmi.hresp;

    ---------------------------------------------------------------------------------
    -- REG Interface
    ---------------------------------------------------------------------------------
    otro := dev_reg_out_none;

    v.hold := '0';
    indexwr := '0';
    if tri.sel(0) = '1' then
      trace_reg_access(tri.addr, tri.wr, tri.data, otro.data, indexwr);
      otro.rdy := '1';
    elsif tri.sel(1) = '1' then
      trace_data_access(tri.addr, tri.wr, r.hold, tri.data, otro.data);
      v.hold := '1';
      if tri.wr='1' or r.hold='1' then
        otro.rdy := '1';
        v.hold := '0';
      end if;
    elsif tri.sel /= dev_reg_in_none.sel then
      otro.rdy := '1';
    end if;

    tro       <= otro;

    ---------------------------------------------------------------------------
    -- AHB trace buffer pipeline
    ---------------------------------------------------------------------------
    buf_ptr := r.tr_ctrl.buf_ptr;
    aindex := r.tr_ctrl.aindex; -- master index

    for b in 0 to nbus-1 loop
      -- Stage 3 - act if watchpoint hit
      -- TODO
      
      -- Stage 2 - write into TB, evaluate watchpoint conditions
      tr_hit := '0';
      if (((r.tr_ctrl.tbreg(1).addr xor r.tr(b).s2haddr(31 downto 2)) and r.tr_ctrl.tbreg(1).mask) = zero32(29 downto 0) and   
         ((r.tr_ctrl.tbreg(1).read and r.tr(b).s2hwrite) or (r.tr_ctrl.tbreg(1).write and r.tr(b).s2hwrite)) = '1')
         or 
         (((r.tr_ctrl.tbreg(2).addr xor r.tr(b).s2haddr(31 downto 2)) and r.tr_ctrl.tbreg(2).mask) = zero32(29 downto 0) and 
         ((r.tr_ctrl.tbreg(2).read and r.tr(b).s2hwrite) or (r.tr_ctrl.tbreg(2).write and r.tr(b).s2hwrite))= '1') then
        tr_hit := '1';
        v.tr_ctrl.bphit  := '1';
      end if; 

      if r.tr(b).s2htrans(1) = '1' then
        if api=0 then
          -- Legacy LEON layout
          otbi(buf_ptr).data(127) := '0'; -- orv(bphit) or orv(wphit);
          otbi(buf_ptr).data(96+tbits-1 downto 96) := timer(tbits-1 downto 0);
          otbi(buf_ptr).data(94 downto 80) := (others => '0'); --ahbmipl.hirq(15 downto 1);
          otbi(buf_ptr).data(79) := r.tr(b).s2hwrite;
          otbi(buf_ptr).data(78 downto 77) := r.tr(b).s2htrans;
          otbi(buf_ptr).data(76 downto 74) := r.tr(b).s2hsize;
          otbi(buf_ptr).data(73 downto 71) := r.tr(b).s2hburst;
          otbi(buf_ptr).data(70 downto 67) := r.tr(b).s2hmaster;
          otbi(buf_ptr).data(66) := r.tr(b).s2hmastlock;
          otbi(buf_ptr).data(65 downto 64) := r.tr(b).s2hresp;
          otbi(buf_ptr).data(63 downto 32) := r.tr(b).s2data(31 downto 0);
          for x in 1 to 3 loop
            otbi(buf_ptr).data(x*32+127 downto x*32+96) := r.tr(b).s2data((x*32 mod maxbusw)+31 downto (x*32 mod maxbusw));
          end loop;
          otbi(buf_ptr).data(31 downto 0) := r.tr(b).s2haddr;
        else
          -- New layout
          for x in 0 to 3 loop
            otbi(buf_ptr).data(x*32+127 downto x*32+96) := r.tr(b).s2data((x*32 mod maxbusw)+31 downto (x*32 mod maxbusw));
          end loop;
          otbi(buf_ptr).data(95 downto 64) := r.tr(b).s2haddr;
          otbi(buf_ptr).data(63) := tr_hit and r.tr_ctrl.enable; 
          otbi(buf_ptr).data(32+tbits-1 downto 32) := timer(tbits-1 downto 0);
          otbi(buf_ptr).data(31 downto 16) := (others => '0'); -- Interrupt ???
          otbi(buf_ptr).data(15) := r.tr(b).s2hwrite;
          otbi(buf_ptr).data(14 downto 13) := r.tr(b).s2htrans;
          otbi(buf_ptr).data(12 downto 10) := r.tr(b).s2hsize;
          otbi(buf_ptr).data(9 downto 7) := r.tr(b).s2hburst;
          otbi(buf_ptr).data(6 downto 3) := r.tr(b).s2hmaster;
          otbi(buf_ptr).data(2) := r.tr(b).s2hmastlock;
          otbi(buf_ptr).data(1 downto 0) := r.tr(b).s2hresp;
        end if;
        otbi(buf_ptr).addr(TBUFABITS-1 downto 0) := aindex;
        otbi(buf_ptr).enable := '1';
        otbi(buf_ptr).write := "1111111";

        if buf_ptr = nbus-1 then -- Reset buffer pointer and increment trace RAM address
          aindex := add(aindex, 1);
          buf_ptr := 0;
        else 
          buf_ptr := buf_ptr + 1;
        end if;
        
        -- If filters are enabled, a hit is registered and trigger delay is not set
        if (r.tr_ctrl.enable and tr_hit and not r.tr_ctrl.timeren) = '1' then 
          v.tr_ctrl.enable := '0';  
          v.tr_ctrl.bphit  := '0';  
          v.tr_ctrl.break  := '1';
        end if;
      end if;

      if (r.tr_ctrl.bphit and r.tr_ctrl.timeren) = '1' then 
        v.tr_ctrl.delaycnt := std_logic_vector(unsigned(r.tr_ctrl.delaycnt)-1);
        if r.tr_ctrl.delaycnt = zero32(15 downto 0) then
          v.tr_ctrl.enable  := '0';  
          v.tr_ctrl.timeren := '0';
          v.tr_ctrl.bphit   := '0';
          v.tr_ctrl.break   := '1';
        end if;
      end if;

      -- Stage 1 - sample AHB access data phase
      v.tr(b).s2htrans := "00"; -- htrans used as "valid bit" in stage 2
      if (tr_buses(b).hready='1') and (r.tr_ctrl.break = '0') then
        v.tr(b).s2htrans := r.tr(b).s1htrans;
      end if;
      v.tr(b).s2haddr := r.tr(b).s1haddr;
      v.tr(b).s2hwrite := r.tr(b).s1hwrite;
      v.tr(b).s2hsize :=  r.tr(b).s1hsize;
      v.tr(b).s2hburst := r.tr(b).s1hburst;
      v.tr(b).s2hmaster := r.tr(b).s1hmaster;
      v.tr(b).s2hmastlock := r.tr(b).s1hmastlock;
      v.tr(b).s2hresp := resp_array(b);
      if r.tr(b).s1hwrite='1' then
        v.tr(b).s2data := tr_buses(b).hwdata;
      else
        v.tr(b).s2data := rd_array(b); -- hrdata from cpumi & strmi
      end if;

      -- Stage 0 - sample AHB access address phase(0)
      if tr_buses(b).hready='1' then
        v.tr(b).s1haddr :=  tr_buses(b).haddr;
        v.tr(b).s1hwrite := tr_buses(b).hwrite;
        v.tr(b).s1htrans := tr_buses(b).htrans;
        v.tr(b).s1hsize := tr_buses(b).hsize;
        v.tr(b).s1hburst := tr_buses(b).hburst;
        v.tr(b).s1hmaster := tr_buses(b).hmaster;
        v.tr(b).s1hmastlock := tr_buses(b).hmastlock;
      end if;

    end loop;

    v.tr_ctrl.buf_ptr := buf_ptr;
    if indexwr='0' then
      v.tr_ctrl.aindex := aindex;
    end if;

    ---------------------------------------------------------------------------------
    -- Signals
    ---------------------------------------------------------------------------------
    rin           <= v;
    tbi           <= otbi;    

  end process;


  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if rstn = '0' then
        r <= RES_T;
        r.tr_ctrl.enable <= rsten;        
      end if;
    end if;
  end process;

  tb0 : if TRACEN generate
    atmem0 : entity work.tbufmemnv_mbus generic map (tech => memtech, addrbits => addrbits, dwidth => maxbusw, nbus => nbus-1, proc => 0, testen => scantest)
      port map (clk, tbi, tbo, cbsi.testin
                );
    end generate; 
end;
