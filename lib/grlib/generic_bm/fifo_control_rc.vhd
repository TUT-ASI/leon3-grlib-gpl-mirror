------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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
-- Entity:      fifo_control_rc
-- File:        fifo_control_rc.vhd
-- Company:     Cobham Gaisler AB
-- Description: Generic FIFO data read interface, support
--              for unaligned addresses
------------------------------------------------------------------------------ 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.generic_bm_pkg.all;

entity fifo_control_rc is
  generic (
    async_reset      : boolean;
    be_dw            : integer := 32;
    be_rd_pipe       : integer := 1;
    unalign_load_opt : integer := 0
    );
  port (
    clk           : in  std_logic;
    rstn          : in  std_logic;
    endian        : in  std_logic;  --0->BE, 1->LE
    fifo_rc_in    : in  fifo_rc_in_type;
    fifo_rc_out   : out fifo_rc_out_type;
    be_wdata      : in  std_logic_vector(be_dw-1 downto 0);
    be_wdata_comb : in  std_logic_vector(be_dw-1 downto 0);
    fe_rdata      : out std_logic_vector(be_dw-1 downto 0));
end fifo_control_rc;


architecture rtl of fifo_control_rc is

  type input_port is record
    be_wdata      : std_logic_vector(be_dw-1 downto 0);
    be_wdata_comb : std_logic_vector(be_dw-1 downto 0);
  end record;

  type output_port is record
    fe_rvalid : std_logic;
    fe_rlast  : std_logic;
  end record;

  type reg_type is record
    data_word     : std_logic_vector((2*be_dw)-1 downto 0);
    data_word_err : std_logic_vector(2*(be_dw/8)-1 downto 0);
    valid         : std_logic_vector(1 downto 0);
    mux_pos       : integer range 0 to (be_dw/8)-1;
    shift_data    : std_logic;
    read_last     : std_logic;
    rlast_delayed : std_logic;
  end record;

  constant RES_T : reg_type := (
    data_word     => (others => '0'),
    data_word_err => (others => '0'),
    valid         => (others => '0'),
    mux_pos       => 0 ,
    shift_data    => '0',
    read_last     => '0',
    rlast_delayed => '0'
    );

  signal r, rin : reg_type;
  signal inp    : input_port;

  
begin  -- rtl

  inp.be_wdata      <= be_wdata;
  inp.be_wdata_comb <= be_wdata_comb;

  comb : process(r, fifo_rc_in, inp, endian )
    variable v                 : reg_type;
    variable inp_data_shifted  : std_logic_vector(be_dw-1 downto 0);
    variable outp              : output_port;
    variable rdata_endian      : std_logic_vector(be_dw-1 downto 0);
    variable rdata_endian_comb : std_logic_vector(be_dw-1 downto 0);
    variable be_rlast_masked   : std_logic;
    variable fe_rdata_v        : std_logic_vector(be_dw-1 downto 0);
    variable fe_rvalid_v       : std_logic;
    variable fe_rlast_v        : std_logic;
    variable error_or          : std_logic;
    variable error_v           : std_logic;
  begin

    v              := r;
    v.shift_data   := '0';
    v.read_last    := '0';
    outp.fe_rvalid := '0';
    outp.fe_rlast  := '0';

    be_rlast_masked := fifo_rc_in.be_rlast;
    if (r.mux_pos + inc_v(fifo_rc_in.be_rsize)) > be_dw/8 and fifo_rc_in.be_rlast = '1' then
      --only if address is not aligned or size is not multiple of be_dw
      if fifo_rc_in.be_no_align /= '0' then
        --last data still needs to be read
        be_rlast_masked := '0';
        v.rlast_delayed := '1';
        if unalign_load_opt /= 0 then
          if fifo_rc_in.unaligned_burst = '1' then
            --during unaligned load optimization the last data
            --word might be unnecessary
            v.read_last := '1';
            v.rlast_delayed := '0';
          end if;
        end if;
      end if;
    end if;

    if r.rlast_delayed = '1' then
      be_rlast_masked := '1';
      v.read_last     := '1';
      v.shift_data    := '1';
      v.rlast_delayed := '0';
    end if;

    if fifo_rc_in.rreset = '1' then
      v.mux_pos       := 0;
      v.data_word_err := (others => '0');
    elsif fifo_rc_in.be_wvalid = '1' and fifo_rc_in.be_no_align /= '0' then
      --only if address is not aligned or size is not multiple of be_dw
      --if the current access consumes the current word entirely
      --push the data to fe on the next cycle
      if ((r.mux_pos + inc_v(fifo_rc_in.be_rsize)) >= be_dw/8) or be_rlast_masked = '1' then
        v.shift_data := '1';
        if be_rlast_masked = '1' then
          v.read_last := '1';
        end if;
      end if;

      --if the access is narrower than the dw
      --change the mux position for the upcoming accesses
      --(increment by the size that was read)
      if (r.mux_pos + inc_v(fifo_rc_in.be_rsize)) < (be_dw/8) then
        v.mux_pos := r.mux_pos + inc_v(fifo_rc_in.be_rsize);
      else
        --wrap around (full be_dw size was read)
        v.mux_pos := inc_v(fifo_rc_in.be_rsize) - (be_dw/8 - r.mux_pos);
      end if;
    end if;

    if r.shift_data = '1' then
      --shift data between two registers and accept a new data
      outp.fe_rvalid                      := '1';
      outp.fe_rlast                       := r.read_last;
      v.data_word(be_dw-1 downto 0)       := r.data_word(2*be_dw-1 downto be_dw);
      v.data_word_err(be_dw/8-1 downto 0) := r.data_word_err(2*(be_dw/8)-1 downto be_dw/8);
    end if;

    rdata_endian      := byte_swap(inp.be_wdata);
    rdata_endian_comb := byte_swap(inp.be_wdata_comb);
    inp_data_shifted  := load_byte_align(rdata_endian, fifo_rc_in.be_rsize, fifo_rc_in.addr, be_dw);
    if endian /= '0' then
      rdata_endian := inp.be_wdata;
      rdata_endian_comb := inp.be_wdata_comb;
      inp_data_shifted := load_byte_align(rdata_endian, fifo_rc_in.be_rsize, fifo_rc_in.addr, be_dw);
    end if;
      

    if fifo_rc_in.be_wvalid = '1' then
      --read multiplexer
      for i in 0 to (be_dw/8)-1 loop
        for j in i to i+(be_dw/8)-1 loop
          if ((j-i) = r.mux_pos) and (i < inc_v(fifo_rc_in.be_rsize)) then
            v.data_word(((j+1)*8)-1 downto j*8) := inp_data_shifted(((i+1)*8)-1 downto i*8);
            if fifo_rc_in.error = '1' then
              v.data_word_err(j) := '1';
            else
              v.data_word_err(j) := '0';
            end if;
          end if;
        end loop;
      end loop;
    end if;

    error_or := '0';
    for i in 0 to (be_dw/8)-1 loop
      --when there is unaligned access, part of the
      --word can be erroneous
      if r.data_word_err(i) = '1' then
        error_or := '1';
      end if;
    end loop;  -- i

    if outp.fe_rlast = '1' then
      v.data_word_err := (others => '0');
    end if;

    rin <= v;

    fe_rdata_v  := r.data_word(be_dw-1 downto 0);
    fe_rvalid_v := outp.fe_rvalid;
    fe_rlast_v  := outp.fe_rlast;
    error_v     := error_or and outp.fe_rvalid;
    if fifo_rc_in.be_no_align = '0' then
      --if both the address is algined and size is multiple
      --of back-end bus width the unaligned mux scheme is
      --not used data is directly forwarded
      fe_rlast_v := fifo_rc_in.be_rlast;
      if be_rd_pipe /= 0 then
        fe_rvalid_v := fifo_rc_in.be_wvalid;
        error_v     := fifo_rc_in.error;
        fe_rdata_v  := rdata_endian;
      else
        fe_rvalid_v := fifo_rc_in.be_wvalid_comb;
        error_v     := fifo_rc_in.error_comb;
        fe_rdata_v  := rdata_endian_comb;
      end if;
    end if;

    fe_rdata              <= fe_rdata_v;
    fifo_rc_out.fe_rvalid <= fe_rvalid_v;
    fifo_rc_out.fe_rlast  <= fe_rlast_v;
    fifo_rc_out.error     <= error_v;

  end process comb;

  syncrst_regs : if not async_reset generate
    process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if rstn = '0' then
          r <= RES_T;
        end if;
      end if;
    end process;
  end generate syncrst_regs;


  asyncrst_regs : if async_reset generate
    process(clk, rstn)
    begin
      if rstn = '0' then
        r <= RES_T;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;
  end generate asyncrst_regs;

  
end rtl;
