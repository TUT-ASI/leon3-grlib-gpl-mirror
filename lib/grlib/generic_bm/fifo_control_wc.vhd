------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-- Entity:      fifo_control_wc
-- File:        fifo_control_wc.vhd
-- Company:     Cobham Gaisler AB
-- Description: Generic FIFO data read interface, support
--              for unaligned addresses (write channel)
------------------------------------------------------------------------------ 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.generic_bm_pkg.all;

entity fifo_control_wc is
  generic (
    async_reset : boolean;
    lendian_en  : integer := 0;
    be_dw       : integer := 32);
  port (
    clk         : in  std_logic;
    rstn        : in  std_logic;
    fifo_wc_in  : in  fifo_wc_in_type;
    fifo_wc_out : out fifo_wc_out_type;
    fe_wdata    : in  std_logic_vector(be_dw-1 downto 0);
    be_rdata    : out std_logic_vector(be_dw-1 downto 0)
    );
end fifo_control_wc;


architecture rtl of fifo_control_wc is

  type input_port is record
    fe_wdata  : std_logic_vector(be_dw-1 downto 0);
  end record;

  type reg_type is record
    data_word : std_logic_vector((2*be_dw)-1 downto 0);
    valid     : std_logic_vector(1 downto 0);
    mux_pos   : integer range 0 to (be_dw/8)-1;
  end record;

  constant RES_T : reg_type := (
    data_word => (others => '0'),
    valid     => (others => '0'),
    mux_pos   => 0);

  signal r, rin : reg_type;
  signal inp    : input_port;

begin  -- rtl

  inp.fe_wdata <= byte_swap(fe_wdata) when lendian_en = 0 else fe_wdata;

  comb : process(r, fifo_wc_in, inp)
    variable v          : reg_type;
    variable shift_data : std_logic;
    variable read_data  : std_logic_vector(be_dw-1 downto 0);
    variable fe_ren_v   : std_logic;
    variable be_rdata_endian : std_logic_vector(be_dw-1 downto 0);
  begin

    v          := r;
    shift_data := '0';
    fe_ren_v   := '0';
    read_data  := r.data_word(be_dw-1 downto 0);

    if fifo_wc_in.rreset = '1' then
      v.mux_pos := 0;
      v.valid   := (others => '0');
    elsif fifo_wc_in.be_ren = '1' then
      --if the current access consumes the current word entirely
      --shift a new data
      if (r.mux_pos + inc_v(fifo_wc_in.be_rsize)) >= be_dw/8 then
        shift_data := '1';
      end if;

      --if the access is narrower than the dw
      --change the mux position for the upcoming accesses
      --(increment by the size that was read)
      if (r.mux_pos + inc_v(fifo_wc_in.be_rsize)) < (be_dw/8) then
        v.mux_pos := r.mux_pos + inc_v(fifo_wc_in.be_rsize);
      else
        --wrap around (full be_dw size was read)
        v.mux_pos := inc_v(fifo_wc_in.be_rsize) - (be_dw/8 - r.mux_pos);
      end if;
   
    end if;

    if shift_data = '1' then
      v.data_word(be_dw-1 downto 0)         := r.data_word(2*be_dw-1 downto be_dw);
      v.data_word((2*be_dw)-1 downto be_dw) := inp.fe_wdata;
      v.valid(0)                            := r.valid(1);
      v.valid(1)                            := fifo_wc_in.fe_rvalid;
      fe_ren_v                              := '1';
    end if;

    if r.valid(1) = '1' and r.valid(0) = '0' then
      --initial case during unoptimized cases data is read to the first
      --register, and should be shifted to start the write
      v.data_word(be_dw-1 downto 0)         := r.data_word(2*be_dw-1 downto be_dw);
      v.data_word((2*be_dw)-1 downto be_dw) := inp.fe_wdata;
      v.valid(0)                            := r.valid(1);
      v.valid(1)                            := fifo_wc_in.fe_rvalid;
      fe_ren_v                              := '1';
    end if;

    if fifo_wc_in.be_no_align = '0' then
      fe_ren_v                              := '0';
    end if;
    if fifo_wc_in.be_no_align = '0' and fifo_wc_in.be_ren = '1' then
      --if address is aligned and size is multiple of be_dw
      --data is directly latched at the second register to
      --reduce latency
      fe_ren_v                      := '1';
      v.data_word(be_dw-1 downto 0) := inp.fe_wdata;
      v.valid(0)                    := '1';
    end if;

    if fifo_wc_in.fe_fwrite = '1' then
      --sample the first word with the burst grant
      v.valid(1)                            := fifo_wc_in.fe_rvalid;
      v.data_word((2*be_dw)-1 downto be_dw) := inp.fe_wdata;
      --for aligned access optimization
      v.data_word(be_dw-1 downto 0)         := inp.fe_wdata;
      if fifo_wc_in.be_no_align = '0' then
        v.valid(0) := fifo_wc_in.fe_rvalid;
      end if;
    end if;

    rin <= v;

    --read multiplexer
    for i in 0 to (be_dw/8)-1 loop
      for j in i to i+(be_dw/8)-1 loop
        if ((j-i) = r.mux_pos) then
          read_data(((i+1)*8)-1 downto i*8) := r.data_word(((j+1)*8)-1 downto j*8);
        end if;
      end loop;
    end loop;
    
    --be_rdata <= byte_swap(write_byte_align(read_data, fifo_wc_in.be_rsize, be_dw));
    be_rdata_endian := byte_swap(write_byte_align(read_data, fifo_wc_in.be_rsize, be_dw));
    if lendian_en /= 0 then
      be_rdata_endian :=write_byte_align(read_data, fifo_wc_in.be_rsize, be_dw);
    end if;

    be_rdata <= be_rdata_endian;
    
    fifo_wc_out.fifo_valid_wc <= r.valid;
    fifo_wc_out.fe_ren        <= fe_ren_v;
    
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
