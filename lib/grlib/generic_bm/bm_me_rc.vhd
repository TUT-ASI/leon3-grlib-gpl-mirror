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
-- Entity:      bm_me_rc
-- File:        bm_me_rc.vhd
-- Company:     Cobham Gaisler AB
-- Description: Bus muster middle end controller (Read Channel)
------------------------------------------------------------------------------ 

--middle-end controller handles the burst calculation and boudary crossings
--and generates standard commands to the back-end controller.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.generic_bm_pkg.all;


entity bm_me_rc is
  generic (
    async_reset           : boolean;
    be_dw                 : integer;
    maxsize               : integer;
    max_burst_length_ptwo : integer;
    burst_chop_mask_ptwo  : integer;
    addr_width            : integer := 32;
    be_rd_pipe            : integer := 1;
    unalign_load_opt      : integer := 0);
  port (
    clk           : in  std_logic;
    rstn          : in  std_logic;
    bm_me_rc_in   : in  bm_me_rc_in_type;
    bm_me_rc_out  : out bm_me_rc_out_type;
    start_address : in  std_logic_vector(addr_width-1 downto 0);
    excl_address  : in  std_logic_vector(addr_width-1 downto 0);
    burst_addr    : out std_logic_vector(addr_width-1 downto 0);
    size          : in  std_logic_vector(log_2(maxsize)-1 downto 0);
    excl_size     : in  std_logic_vector(log_2(maxsize)-1 downto 0);
    burst_length  : out std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0)
    );
end bm_me_rc;


architecture rtl of bm_me_rc is

  constant max_burst_length : integer := max_burst_length_ptwo;
  constant burst_chop_mask  : integer := burst_chop_mask_ptwo;

  type bm_me_state is (idle, burst_calculate, stream);

  constant byte_offset_start   : integer                                      := log_2(be_dw/8)-1;
  constant boffset_zeros       : std_logic_vector(byte_offset_start downto 0) := (others => '0');
  constant size_max_chop_index : integer                                      := calc_chop_index(burst_chop_mask, maxsize);

  constant max_burst_length_unsigned       : unsigned(log_2(max_burst_length) downto 0) := to_unsigned(max_burst_length, log_2(max_burst_length)+1);
  constant max_burst_length_unsigned_bytes : unsigned(log_2(max_burst_length)+byte_offset_start+1 downto 0) := max_burst_length_unsigned & unsigned(boffset_zeros);

  type input_port is record
    size          : std_logic_vector(log_2(maxsize)-1 downto 0);
    excl_size     : std_logic_vector(log_2(maxsize)-1 downto 0);
    start_address : std_logic_vector(addr_width-1 downto 0);
    excl_address  : std_logic_vector(addr_width-1 downto 0);
  end record;

  type output_port is record
    burst_last   : std_logic;
    be_rlast     : std_logic;
    burst_length : std_logic_vector(log_2(max_burst_length)-1 downto 0);
  end record;

  type reg_type is record
    size_left        : unsigned(log_2(maxsize) downto 0);
    size_left_unopt  : unsigned(log_2(maxsize) downto 0);
    unopt_allowed    : std_logic;
    unaligned_burst  : std_logic;
    cur_address      : std_logic_vector(addr_width-1 downto 0);
    error            : std_logic;
    finished         : std_logic;
    state            : bm_me_state;
    burst_beat_size  : std_logic_vector(2 downto 0);
    total_burst_size : unsigned(log_2(maxsize) downto 0);
    active           : std_logic;
    adrsize_aligned  : std_logic;
    init             : std_logic;
    fe_burst_done    : std_logic;
    byte_ctr         : integer range 0 to maxsize;
    delay            : std_logic;
    lock             : std_logic;
    mux_pos          : unsigned(log_2(be_dw/8) downto 0);
  end record;

  constant RES_T : reg_type := (
    size_left        => (others => '0'),
    size_left_unopt  => (others => '0'),
    unopt_allowed    => '0',
    unaligned_burst  => '0',
    cur_address      => (others => '0'),
    error            => '0',
    finished         => '0',
    state            => idle,
    burst_beat_size  => (others => '0'),
    total_burst_size => (others => '0'),
    active           => '0',
    adrsize_aligned  => '0',
    init             => '0',
    fe_burst_done    => '0',
    byte_ctr         => 0,
    delay            => '0',
    lock             => '0',
    mux_pos          => (others => '0')
    );

  signal r, rin : reg_type;
  signal inp    : input_port;
  
begin  -- rtl

  inp.size          <= size;
  inp.excl_size     <= excl_size;
  inp.start_address <= start_address;
  inp.excl_address  <= excl_address;

  comb : process (r, bm_me_rc_in, inp)
    variable bleft_eow                          : unsigned(byte_offset_start+1 downto 0);
    variable byte_offset                        : std_logic_vector(byte_offset_start downto 0);
    variable byte_offset_size                   : std_logic_vector(byte_offset_start downto 0);
    variable byte_offset_ext                    : std_logic_vector(byte_offset_start+1 downto 0);
    variable be_w_size                          : unsigned(byte_offset_start+1 downto 0);
    variable size_left_burst                    : unsigned(log_2(maxsize)-byte_offset_start-1 downto 0);
    variable size_left_burst_aligned            : unsigned(log_2(maxsize) downto 0);
    variable size_left_offset                   : unsigned(byte_offset_start downto 0);
    variable size_left_unaligned                : std_logic;
    variable size_left_burst_new                : unsigned(log_2(maxsize)-byte_offset_start-1 downto 0);
    variable unaligned_acc                      : std_logic;
    variable size_encoding_begin                : std_logic_vector(6 downto 0);
    variable size_encoding_end                  : std_logic_vector(7 downto 0);
    variable burst_request                      : std_logic;  --
    variable size_left_temp                     : unsigned(log_2(maxsize) downto 0);
    variable size_left_unopt_temp               : unsigned(log_2(maxsize) downto 0);
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
    variable burst_done                         : std_logic;
    variable be_dw_unsigned                     : unsigned(log_2(be_dw/8) downto 0);
  begin

    v := r;

    burst_done                     := '0';
    be_w_size                      := (others => '0');
    be_w_size(byte_offset_start+1) := '1';
    size_left_temp                 := (others => '0');
    size_left_unopt_temp           := (others => '0');
    be_dw_unsigned                 := (others => '0');
    be_dw_unsigned(log_2(be_dw/8)) := '1';

    bleft_eow               := be_w_size-unsigned(r.cur_address(byte_offset_start downto 0));
    byte_offset             := r.cur_address(byte_offset_start downto 0);
    byte_offset_size        := std_logic_vector(r.size_left(byte_offset_start downto 0));
    byte_offset_ext         := r.cur_address(byte_offset_start+1 downto 0);
    --burst size left in terms of number of be words (size of back-end bus)
    size_left_burst         := r.size_left(log_2(maxsize) downto byte_offset_start+1);
    --burst size left in terms of bytes (always aligned to the back-end bus width)
    size_left_burst_aligned := size_left_burst & unsigned(boffset_zeros);

    size_left_unaligned := '0';
    unaligned_acc       := '0';
    size_left_burst_new := r.size_left_unopt(log_2(maxsize) downto byte_offset_start+1);
    size_left_offset    := r.size_left(byte_offset_start downto 0);
    if unalign_load_opt /= 0 then
      for i in 0 to byte_offset_start loop
        if size_left_offset(i) = '1' then
          --detect if the remaining burst size is aligned to the back-end
          --bus width, used for unaligned load optimization
          size_left_unaligned := '1';
        end if;
      end loop;

      if size_left_unaligned = '1' and r.unopt_allowed = '1'then
        --if the remaining size is unaligned and unaligned load optimizatin is
        --enabled the last word will be read as a full word in the burst and partly
        --used in order not to generate additional narrow single accesses at the end
        unaligned_acc           := '1';
        size_left_burst         := size_left_burst_new(log_2(maxsize)-byte_offset_start-1 downto 0);
        size_left_burst_aligned := size_left_burst & unsigned(boffset_zeros);
      end if;
      
    end if;

    size_encoding_begin                             := (others => '0');
    size_encoding_begin(byte_offset_start downto 0) := byte_offset;
    size_encoding_end                               := (others => '0');
    size_encoding_end(byte_offset_start+1 downto 0) := byte_offset_ext;

    burst_request   := '0';
    v.finished      := '0';
    v.fe_burst_done := '0';

    outp.burst_last   := '0';
    outp.burst_length := (others => '0');
    outp.be_rlast     := '0';

    burst_chop_mask_v                                                           := (others => '0');
    burst_chop_mask_v(log_2(burst_chop_mask))                                   := '1';
    --burst length-1 is needed for output, subtracting 1 with a constant to
    --eliminate instantiating another adder
    burst_chop_mask_v_mone                                                      := (others => '0');
    burst_chop_mask_v_mone(log_2(burst_chop_mask)-1 downto byte_offset_start+1) := (others => '1');
    cur_addr_chop                                                               := unsigned(r.cur_address(log_2(burst_chop_mask) downto 0));
    cur_addr_chop(log_2(burst_chop_mask))                                       := '0';

    --boundary crossing checks
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

        if bm_me_rc_in.start = '1' then
          --if there is an exclusive access (only for AHB) set the lock bit.
          --if unaligned load optimization is enabled calculate the burst size
          --with assuming that the last beat will read the entire word (even though
          --part of tht will be used). Also make sure that unaligned load optimization
          --will not generate a burst that can exceed the max_size generic (can happen
          --if the access size is equal to max_size and it is unaligned).
          if bm_me_rc_in.lock = '0' then
            v.cur_address := inp.start_address;
            v.size_left   := unsigned('0'&inp.size)+1;
            if unalign_load_opt /= 0 then
              v.size_left_unopt := unsigned('0'&inp.size)+1+(be_dw/8);
              if unsigned(v.size_left_unopt(log_2(maxsize) downto byte_offset_start+1)) <= max_burst_length then
                v.unopt_allowed := '1';
              else
                v.unopt_allowed := '0';
              end if;
            end if;
            v.lock := '0';
          else
            v.cur_address := inp.excl_address;
            v.size_left   := unsigned('0'&inp.excl_size)+1;
            if unalign_load_opt /= 0 then
              v.size_left_unopt := unsigned('0'&inp.excl_size)+1+(be_dw/8);
              if unsigned(v.size_left_unopt(log_2(maxsize) downto byte_offset_start+1)) <= max_burst_length then
                v.unopt_allowed := '1';
              else
                v.unopt_allowed := '0';
              end if;
            end if;
            v.lock := '1';
          end if;

          if unalign_load_opt /= 0 then
            --initial mux position during unaligned burst optimization, later
            --used to detect if the last word in the fifo is entirely not used
            v.mux_pos := be_dw_unsigned-unsigned(v.cur_address(log_2(be_dw/8)-1 downto 0));
            if unsigned(v.cur_address(log_2(be_dw/8)-1 downto 0)) = 0 then
              v.mux_pos := (others => '0');
            end if;
          end if;

          v.state           := burst_calculate;
          v.burst_beat_size := size_translate(be_dw/8);
          v.active          := '1';
          v.init            := '1';
          v.byte_ctr        := 0;
        end if;

        if unalign_load_opt /= 0 then
          v.unaligned_burst := '0';
        end if;
        
      when burst_calculate =>
        --state machine will turn back to here as soon as there are
        --untrasffered bytes left in the burst

        if unalign_load_opt /= 0 then
          v.unaligned_burst := '0';
        end if;

        --address and size aligned check is only done at the very beginning
        --to decide on opimization
        if r.init = '1' then
          v.init := '0';
          if one_detect(byte_offset) = '0' and one_detect(byte_offset_size) = '0' then
            --address and size is aligned
            v.adrsize_aligned := '1';
          else
            v.adrsize_aligned := '0';
          end if;
        end if;

        if (one_detect(byte_offset) = '1' and r.size_left >= bleft_eow) then
          --address is unalgined and there is enough bytes to the end of the word
          --try to reach to the end of word (detect the first '1' from lsb that
          --determines the size
          v.burst_beat_size                              := size_detect_begin(size_encoding_begin);
          v.total_burst_size                             := (others => '0');
          v.total_burst_size(byte_offset_start downto 0) := to_unsigned(inc_v(v.burst_beat_size), byte_offset_start+1);
        elsif (r.size_left < bleft_eow) then
          --*address is unaligned and there is not enough bytes to the end of word
          --find the first '1' from lsb, if <= size_left then use it
          --else go backwards find the first slot that is <= size_left
          --*or address is aligned and less than one word left
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

          if unalign_load_opt /= 0 then
            if chop_boundary_crossed = '0' and unaligned_acc = '1' then
              v.total_burst_size := r.size_left;

              if (r.size_left(log_2(be_dw/8)-1 downto 0) + r.mux_pos <= be_dw/8) then
                --this signals fifo_rc_control that last entry
                --will be invalid because that is not needed
                v.unaligned_burst := '1';
              end if;
              
            end if;
          end if;
        end if;

        --burst request to the back-end
        burst_request := '1';

        if bm_me_rc_in.grant = '1' then
          --burst request to the back-end is acknowledged
          v.state := stream;
          v.delay := '0';
        end if;

      when stream =>

        --a burst operation is ongoing on the back-end bus
        --wait it to finish

        if unalign_load_opt /= 0 then
          size_left_unopt_temp := r.size_left_unopt - r.total_burst_size;
        end if;

        size_left_temp := r.size_left - r.total_burst_size;
        if size_left_temp = 0 then
          outp.burst_last := '1';
        end if;

        if unalign_load_opt /= 0 then
          --unaligned load optimization check
          --make sure that unaligned load optimization
          --will not generate a burst that can exceed the max_size generic 
          if size_left_unopt_temp(log_2(maxsize) downto byte_offset_start+1) <= max_burst_length then
            v.unopt_allowed := '1';
          else
            v.unopt_allowed := '0';
          end if;
        end if;

        if be_rd_pipe = 0 then
          --if back-end pipe parameter is set to 0 and
          --address, size was aligned one pipeline stage
          --is skipped to reduce the read latency
          if r.adrsize_aligned = '1' then
            burst_done := bm_me_rc_in.burst_done_comb;
          else
            burst_done := bm_me_rc_in.burst_done;
          end if;
        else
          burst_done := bm_me_rc_in.burst_done;
        end if;

        if burst_done = '1' then
          --current burst in the back-end bus is finished
          --calculate the remaining size
          v.size_left       := size_left_temp;
          v.size_left_unopt := size_left_unopt_temp;

          v.cur_address := std_logic_vector(unsigned(r.cur_address)+r.total_burst_size);
          v.state       := burst_calculate;

          if size_left_temp = 0 then
            --if no byte transfer to left return to idle
            --and wait for another read request
            v.state         := idle;
            v.fe_burst_done := '1';
            v.active        := '0';

            outp.be_rlast := '1';

            if unalign_load_opt /= 0 then
              v.unaligned_burst := '0';
            end if;
            
            
          end if;
        end if;
        
    end case;

    rin <= v;

    --port assignments
    bm_me_rc_out.rsize           <= v.burst_beat_size;
    bm_me_rc_out.active          <= r.active;
    bm_me_rc_out.request         <= burst_request;
    burst_addr                   <= r.cur_address;
    bm_me_rc_out.fe_burst_done   <= r.fe_burst_done;
    bm_me_rc_out.addr            <= r.cur_address(4 downto 0);
    bm_me_rc_out.burst_last      <= outp.burst_last;
    bm_me_rc_out.be_rlast        <= outp.be_rlast;
    bm_me_rc_out.lock            <= r.lock;
    bm_me_rc_out.be_no_align     <= not(r.adrsize_aligned);
    bm_me_rc_out.unaligned_burst <= r.unaligned_burst;
    burst_length                 <= outp.burst_length;
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
