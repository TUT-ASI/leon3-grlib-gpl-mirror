------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2019, Cobham Gaisler
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
-- Entity:      bm_me_wc
-- File:        bm_me_wc.vhd
-- Company:     Cobham Gaisler AB
-- Description: Bus muster middle end controller (Write Channel)
------------------------------------------------------------------------------ 

--middle-end controller handles the burst calculation and boudary crossings
--and generates standard commands to the back-end controller.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.generic_bm_pkg.all;


entity bm_me_wc is
  generic (
    async_reset             : boolean;
    be_dw                   : integer;
    maxsize                 : integer;
    max_burst_length_ptwo   : integer;
    burst_chop_mask_ptwo    : integer;
    addr_width              : integer := 32
    );
  port (
    clk           : in  std_logic;
    rstn          : in  std_logic;
    bm_me_wc_in   : in  bm_me_wc_in_type;
    bm_me_wc_out  : out bm_me_wc_out_type;
    start_address : in  std_logic_vector(addr_width-1 downto 0);
    burst_addr    : out std_logic_vector(addr_width-1 downto 0);
    size          : in  std_logic_vector(log_2(maxsize)-1 downto 0);
    burst_length  : out std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0)
    );
end bm_me_wc;


architecture rtl of bm_me_wc is

  constant max_burst_length : integer := max_burst_length_ptwo;
  constant burst_chop_mask  : integer := burst_chop_mask_ptwo;
  
  type bm_me_state is (idle, burst_calculate, stream);

  constant byte_offset_start   : integer                                      := log_2(be_dw/8)-1;
  constant boffset_zeros       : std_logic_vector(byte_offset_start downto 0) := (others => '0');
  constant size_max_chop_index : integer                                      := calc_chop_index(burst_chop_mask, maxsize);

  constant max_burst_length_unsigned       : unsigned(log_2(max_burst_length) downto 0)                     := to_unsigned(max_burst_length, log_2(max_burst_length)+1);
  constant max_burst_length_unsigned_bytes : unsigned(log_2(max_burst_length)+byte_offset_start+1 downto 0) := max_burst_length_unsigned & unsigned(boffset_zeros);

  type input_port is record
    size : std_logic_vector(log_2(maxsize)-1 downto 0);
    start_address : std_logic_vector(addr_width-1 downto 0);
  end record;

  type output_port is record
    burst_last   : std_logic;
    burst_length : std_logic_vector(log_2(max_burst_length)-1 downto 0);
  end record;

  type reg_type is record
    size_left         : unsigned(log_2(maxsize) downto 0);
    cur_address       : std_logic_vector(addr_width-1 downto 0);
    finished          : std_logic;
    state             : bm_me_state;
    burst_beat_size   : std_logic_vector(2 downto 0);
    total_burst_size  : unsigned(log_2(maxsize) downto 0);
    active            : std_logic;
    adrsize_aligned   : std_logic;
    init              : std_logic;
    fe_burst_done     : std_logic;
    delay             : std_logic;
    error             : std_logic;
  end record;

  constant RES_T : reg_type := (
    size_left        => (others => '0'),
    cur_address      => (others => '0'),
    finished         => '0',
    state            => idle,
    burst_beat_size  => (others => '0'),
    total_burst_size => (others => '0'),
    active           => '0',
    adrsize_aligned  => '0',
    init             => '0',
    fe_burst_done    => '0',
    delay            => '0',
    error            => '0'
    );

  signal r, rin : reg_type;
  signal inp    : input_port;

begin  -- rtl

  inp.size          <= size;
  inp.start_address <= start_address;

  comb : process (r, bm_me_wc_in, inp)
    variable bleft_eow                          : unsigned(byte_offset_start+1 downto 0);
    variable bleft_eow_comb                     : unsigned(byte_offset_start+1 downto 0);
    variable bleft_beow_comb                    : unsigned(byte_offset_start downto 0);
    variable byte_offset                        : std_logic_vector(byte_offset_start downto 0);
    variable byte_offset_comb                   : std_logic_vector(byte_offset_start downto 0);
    variable byte_offset_size                   : std_logic_vector(byte_offset_start downto 0);
    variable byte_offset_ext                    : std_logic_vector(byte_offset_start+1 downto 0);
    variable be_w_size                          : unsigned(byte_offset_start+1 downto 0);
    variable size_left_burst                    : unsigned(log_2(maxsize)-byte_offset_start-1 downto 0);
    variable size_left_burst_aligned            : unsigned(log_2(maxsize) downto 0);
    variable size_encoding_begin                : std_logic_vector(6 downto 0);
    variable size_encoding_end                  : std_logic_vector(7 downto 0);
    variable burst_request                      : std_logic;
    variable size_left_temp                     : unsigned(log_2(maxsize) downto 0);
    variable burst_chop_mask_v                  : unsigned(log_2(burst_chop_mask) downto 0);
    variable burst_chop_mask_v_mone             : unsigned(log_2(burst_chop_mask) downto 0);
    variable cur_addr_chop                      : unsigned(log_2(burst_chop_mask) downto 0);
    variable size_max_chop_temp                 : unsigned(log_2(burst_chop_mask) downto 0);
    variable size_max_chop_temp_mone            : unsigned(log_2(burst_chop_mask) downto 0);
    variable size_max_chop                      : unsigned(log_2(maxsize)-byte_offset_start-1 downto 0);
    variable size_max_chop_mone                 : unsigned(log_2(maxsize)-byte_offset_start-1 downto 0);
    variable chop_boundary_crossed              : std_logic;
    variable chop_boundary_crossed_temp_smaxlen : std_logic;
    variable chop_boundary_crossed_temp_bmaxlen : std_logic;
    variable v                                  : reg_type;
    variable outp                               : output_port;
  begin

    v := r;

    be_w_size                      := (others => '0');
    be_w_size(byte_offset_start+1) := '1';
    size_left_temp                 := (others => '0');
    
    bleft_eow               := be_w_size-unsigned(r.cur_address(byte_offset_start downto 0));
    bleft_eow_comb          := be_w_size-unsigned(inp.start_address(byte_offset_start downto 0));
    bleft_beow_comb         := unsigned(inp.start_address(byte_offset_start downto 0));
    byte_offset             := r.cur_address(byte_offset_start downto 0);
    byte_offset_comb        := inp.start_address(byte_offset_start downto 0);
    byte_offset_size        := std_logic_vector(r.size_left(byte_offset_start downto 0));
    byte_offset_ext         := r.cur_address(byte_offset_start+1 downto 0);
    --burst size left in terms of number of be words (size of back-end bus)
    size_left_burst         := r.size_left(log_2(maxsize) downto byte_offset_start+1);
    --burst size left in terms of bytes (always aligned to the back-end bus width)
    size_left_burst_aligned := size_left_burst & unsigned(boffset_zeros);

    size_encoding_begin                             := (others => '0');
    size_encoding_begin(byte_offset_start downto 0) := byte_offset;
    size_encoding_end                               := (others => '0');
    size_encoding_end(byte_offset_start+1 downto 0) := byte_offset_ext;

    burst_request     := '0';
    v.finished        := '0';
    v.fe_burst_done   := '0';

    outp.burst_last   := '0';
    outp.burst_length := (others => '0');


    burst_chop_mask_v                                                           := (others => '0');
    burst_chop_mask_v(log_2(burst_chop_mask))                                   := '1';
    --burst length-1 is needed for output, subtracting 1 with a constant to
    --eliminate instantiating another adder
    burst_chop_mask_v_mone                                                      := (others => '0');
    burst_chop_mask_v_mone(log_2(burst_chop_mask)-1 downto byte_offset_start+1) := (others => '1');
    cur_addr_chop                                                               := unsigned(r.cur_address(log_2(burst_chop_mask) downto 0));
    cur_addr_chop(log_2(burst_chop_mask))                                       := '0';

    chop_boundary_crossed              := '0';
    chop_boundary_crossed_temp_smaxlen := '0';
    chop_boundary_crossed_temp_bmaxlen := '0';

    if (cur_addr_chop + size_left_burst_aligned) > burst_chop_mask_v then
      --with the remaining burst size the boundary set by the generic will
      --be crossed
      chop_boundary_crossed_temp_smaxlen := '1';
    end if;

    if (cur_addr_chop + max_burst_length_unsigned_bytes > burst_chop_mask_v) then
      --if max available size for a burst is used the boundary will be crossed
      chop_boundary_crossed_temp_bmaxlen := '1';
    end if;

    --depending on the burst size that is going to be used decide
    --if the boundary is going to be crossed
    if size_left_burst < max_burst_length then
      chop_boundary_crossed := chop_boundary_crossed_temp_smaxlen;
    else
      chop_boundary_crossed := chop_boundary_crossed_temp_bmaxlen;
    end if;

    --if the boundary is going to be crossed calculate the maximum size
    --that can be used for the current access
    size_max_chop_temp      := burst_chop_mask_v - cur_addr_chop;
    size_max_chop_temp_mone := burst_chop_mask_v_mone - cur_addr_chop;

    size_max_chop := (others => '0');
    size_max_chop(size_max_chop_index-byte_offset_start-1 downto 0)
 := size_max_chop_temp(size_max_chop_index downto byte_offset_start+1);

    size_max_chop_mone := (others => '0');
    size_max_chop_mone(size_max_chop_index-byte_offset_start-1 downto 0)
 := size_max_chop_temp_mone(size_max_chop_index downto byte_offset_start+1);
    
    case r.state is
      when idle =>

        v.error := '0';

        if bm_me_wc_in.start = '1' then
          v.cur_address     := inp.start_address;
          v.size_left       := unsigned('0'&inp.size)+1;
          v.state           := burst_calculate;
          v.delay           := '0';
          --set the default size to back-end word for optimization
          v.burst_beat_size := size_translate(be_dw/8);
          v.active          := '1';
          v.init            := '1';
          v.adrsize_aligned := '0';
          --optimization to reduce the start latency
          --by one for aligned bursts
          if one_detect(byte_offset_comb) = '0' and one_detect(std_logic_vector(v.size_left(byte_offset_start downto 0))) = '0' then
              v.adrsize_aligned := '1';
          end if;          
        end if;

        if bm_me_wc_in.burst_done = '1' then
          --this can happen on exclusive accesses if nowrite is asserted
          --(only for AHB back-end)
          v.fe_burst_done := '1';
        end if;

      when burst_calculate =>
        --state machine will turn back to here as soon as there are
        --untrasffered bytes left in the burst

        if (one_detect(byte_offset) = '1' and r.size_left >= bleft_eow) then
          --address is unalgined and there is enough bytes to the end of the word
          --try to reach to the end of word (detect the first '1' from lsb that
          --determines the size
          v.burst_beat_size                              := size_detect_begin(size_encoding_begin);
          v.total_burst_size                             := (others => '0');
          v.total_burst_size(byte_offset_start downto 0) := to_unsigned(inc_v(v.burst_beat_size), byte_offset_start+1);
        elsif (r.size_left < bleft_eow) then
          --*address is unaligned and there is not enough bytes to the end of
          --find the first '1' from lsb, if <= size_left then use it
          --else go backwards find the first slot that is <= size_left
          --*OR address is aligned and less than one word left
          v.burst_beat_size                              := size_detect_end(size_encoding_end, r.size_left);
          v.total_burst_size                             := (others => '0');
          v.total_burst_size(byte_offset_start downto 0) := to_unsigned(inc_v(v.burst_beat_size), byte_offset_start+1);
        else
          --address is aligned and size left is >= bleft_eow which means
          --a burst can be made including a full single word access
          --size_left_burst is calculated by removing the byte offset
          --with respect to the back-end bust width
          v.burst_beat_size := size_translate(be_dw/8);
          if (size_left_burst >= 2) then
            --burst with more than one word
            if chop_boundary_crossed = '1' then
              --max available size for burst will cross the boundary
              --use the maximum possible available size that will not
              --cross the boundary
              v.total_burst_size := size_max_chop & unsigned(boffset_zeros);
              outp.burst_length  := std_logic_vector(size_max_chop_mone(log_2(max_burst_length)-1 downto 0));
            elsif size_left_burst < max_burst_length then
              --size left is smaller than the maximum possible burst length
              v.total_burst_size := unsigned((std_logic_vector(size_left_burst)) & boffset_zeros);
              outp.burst_length  := std_logic_vector(size_left_burst(log_2(max_burst_length)-1 downto 0)-1);
            else
              --size left is exactly equal to the maximum possible burst length
              v.total_burst_size := unsigned(std_logic_vector(to_unsigned(max_burst_length, log_2(maxsize)-byte_offset_start)) & boffset_zeros);
              outp.burst_length  := std_logic_vector(to_unsigned(max_burst_length-1, log_2(max_burst_length)));
            end if;
          else
            --do a single word
            v.total_burst_size := to_unsigned(be_dw/8, log_2(maxsize)+1);
          end if;
        end if;

        if r.delay = '0' then
          --delay is used when the mux position in the fifo can change
          --after each stream. One cycle is needed before the data
          --can be forwarded
          v.delay := '1';
        end if;

        if bm_me_wc_in.fifo_valid(0) = '1' and r.delay = '1' then
          --data is ready and delay requirement is met, make a
          --burst request to the back-end
          burst_request := '1';
        end if;

        if bm_me_wc_in.fifo_valid(0) = '1' and bm_me_wc_in.grant = '1' and r.delay = '1' then
          --burst request is acknowledged (without optimization)
          v.delay := '0';
          v.state := stream; 
        end if;

        if r.adrsize_aligned = '1' then
          --address is aligend and size is a multiple of back-end bus
          --burst request can be made directly
          burst_request := '1';
        end if;

        if r.adrsize_aligned = '1' and bm_me_wc_in.grant = '1' then
          --burst request is acknowledged (optimized case)
          v.state := stream;
          v.delay := '0';
        end if;

      when stream =>

        --a burst operation is ongoing on the back-end bus
        --wait it to finish

        size_left_temp := r.size_left - r.total_burst_size;
        if size_left_temp = 0 then
          outp.burst_last := '1';
        end if;

        if bm_me_wc_in.burst_done = '1' then
          --current burst in the back-end bus is finished
          --calculate the remaining size
          v.size_left   := size_left_temp;
          v.cur_address := std_logic_vector(unsigned(r.cur_address)+r.total_burst_size);
          v.state       := burst_calculate;

          if bm_me_wc_in.error = '1' then
          --for write operations a write error is propagated at the
          --very end. 
            v.error := '1';
          end if;

          if size_left_temp = 0 then
            v.state         := idle;
            v.fe_burst_done := '1';
            v.active        := '0';
          end if;
        end if;

    end case;

    rin <= v;

    --port assignments
    bm_me_wc_out.rsize         <= r.burst_beat_size;
    bm_me_wc_out.active        <= r.active;
    bm_me_wc_out.request       <= burst_request;
    burst_addr    <= r.cur_address;
    bm_me_wc_out.fe_burst_done <= r.fe_burst_done;
    bm_me_wc_out.addr          <= r.cur_address(4 downto 0);
    bm_me_wc_out.burst_last    <= outp.burst_last;
    bm_me_wc_out.error         <= r.error and r.fe_burst_done;
    bm_me_wc_out.be_no_align   <= not(v.adrsize_aligned);
    burst_length               <= outp.burst_length;

    
  end process comb;

 --synchronous reset
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

  --asynchronous reset
  asyncrst_regs : if async_reset generate
    process(clk,rstn)
    begin
      if rstn = '0' then
        r <= RES_T;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;
  end generate asyncrst_regs;
  

end rtl;
