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
-- Entity:      bm_fr_end
-- File:        bm_fr_end.vhd
-- Company:     Cobham Gaisler AB
-- Description: Bus Master front end controller
------------------------------------------------------------------------------ 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.generic_bm_pkg.all;

entity bm_fr_end is
  generic (
    async_reset  : boolean;
    bm_dw        : integer;
    be_dw        : integer;
    max_size     : integer;
    excl_enabled : boolean;
    lendian_en   : integer := 0;
    addr_width   : integer := 32);
  port(
    clk       : in  std_logic;
    rstn      : in  std_logic;
    bmfre_in  : in  bm_fre_in_type;
    bmfre_out : out bm_fre_out_type;
    bmrd_size : in  std_logic_vector(log_2(max_size)-1 downto 0);
    bmwr_size : in  std_logic_vector(log_2(max_size)-1 downto 0);
    bmwr_data : in  std_logic_vector(bm_dw-1 downto 0);
    bmrd_data : out std_logic_vector(bm_dw-1 downto 0);
    bmrd_addr : in  std_logic_vector(addr_width-1 downto 0);
    excl_size : out std_logic_vector(log_2(max_size)-1 downto 0);
    excl_addr : out std_logic_vector(addr_width-1 downto 0);
    fe_rdata  : in  std_logic_vector(be_dw-1 downto 0);
    fe_wdata  : out std_logic_vector(be_dw-1 downto 0)
    );
end bm_fr_end;


architecture rtl of bm_fr_end is
  
  constant BMDW_size   : integer := bm_dw/8;
  constant bmbedw_rate : integer := bm_dw/be_dw;

  type excl_state_type is (idle, pending, read_ongoing, write_ongoing);

  type input_port is record
    bmrd_size : std_logic_vector(log_2(max_size)-1 downto 0);
    bmwr_size : std_logic_vector(log_2(max_size)-1 downto 0);
    bmwr_data : std_logic_vector(bm_dw-1 downto 0);
    fe_rdata  : std_logic_vector(be_dw-1 downto 0);
    bmrd_addr : std_logic_vector(addr_width-1 downto 0);
  end record;

  type output_port is record
    wc_start   : std_logic;
    rc_start   : std_logic;
    fe_fwrite  : std_logic;
    bmrd_valid : std_logic;
    bmrd_data  : std_logic_vector(bm_dw-1 downto 0);
    bmrd_done  : std_logic;
    lock       : std_logic;
    bmrd_error : std_logic;
  end record;

  type reg_type is record
    read_pending      : std_logic;
    write_pending     : std_logic;
    wr_byte_ctr       : integer range 0 to max_size;
    bmwr_req_granted  : std_logic;
    bmrd_req_granted  : std_logic;
    bmwr_size         : unsigned(log_2(max_size) downto 0);
    full_mask         : std_logic;
    bmwr_data_pos     : std_logic_vector(bmbedw_rate-1 downto 0);
    bmwr_data_latched : std_logic_vector(bm_dw-1 downto 0);
    bmrd_data_pos     : std_logic_vector(bmbedw_rate-1 downto 0);
    bmrd_data_latched : std_logic_vector(bm_dw-1 downto 0);
    excl_state        : excl_state_type;
    excl_addr         : std_logic_vector(addr_width-1 downto 0);
    excl_size         : std_logic_vector(log_2(max_size)-1 downto 0);
    excl_done         : std_logic;
    lock_remove       : std_logic;
    rd_error          : std_logic;
  end record;

  constant RES_T : reg_type := (
    read_pending      => '0',
    write_pending     => '0',
    wr_byte_ctr       => 0,
    bmwr_req_granted  => '1',
    bmrd_req_granted  => '1',
    bmwr_size         => (others => '0'),
    full_mask         => '0',
    bmwr_data_pos     => (others => '0'),
    bmwr_data_latched => (others => '0'),
    bmrd_data_pos     => (others => '0'),
    bmrd_data_latched => (others => '0'),
    excl_state        => idle,
    excl_addr         => (others => '0'),
    excl_size         => (others => '0'),
    excl_done         => '0',
    lock_remove       => '0',
    rd_error          => '0'
    );

  signal r, rin : reg_type;
  signal inp    : input_port;

begin  -- rtl


  inp.bmrd_size <= bmrd_size;
  inp.bmwr_size <= bmwr_size;
  inp.fe_rdata  <= fe_rdata;
  inp.bmwr_data <= bmwr_data;
  inp.bmrd_addr <= bmrd_addr;


  comb : process (r, bmfre_in, inp)
    variable v               : reg_type;
    variable outp            : output_port;
    variable bmwr_data_muxed : std_logic_vector(be_dw-1 downto 0);
    variable bmwr_pos_mask   : std_logic;
    variable excl_pending    : std_logic;
    variable bmrd_data_v     : std_logic_vector(bm_dw-1 downto 0);
  begin  -- process comb
    
    v := r;

    outp.wc_start  := '0';
    outp.rc_start  := '0';
    outp.fe_fwrite := '0';
    outp.lock      := '0';

    outp.bmrd_valid := '0';
    outp.bmrd_done  := '0';
    outp.bmrd_error := '0';

    if bm_dw = be_dw then
      --if bus master and back-end data width is equal the data
      --is directly forwarded
      outp.bmrd_data := inp.fe_rdata;
    else
      --if the back-end data-widh is smaller then the bus master
      --data width, the last data is not latched and forwarded
      --immediately to reduce the latency
      outp.bmrd_data(bm_dw-1 downto bm_dw-be_dw) := inp.fe_rdata;
                                                    
      for i in 0 to bmbedw_rate-2 loop
        if r.bmrd_data_pos(i) = '1' then
            outp.bmrd_data((i+1)*be_dw-1 downto i*be_dw) := inp.fe_rdata;
        else
            outp.bmrd_data((i+1)*be_dw-1 downto i*be_dw) := r.bmrd_data_latched((i+1)*be_dw-1 downto i*be_dw);
        end if;
      end loop;  -- i
    end if;

    --One read operation and one write operation
    --can always be acknowledged, independent
    --from the back-end protocol
    v.bmwr_req_granted := '1';
    v.bmrd_req_granted := '1';

    excl_pending  := '0';
    v.excl_done   := '0';
    v.lock_remove := '0';

    --sample only when the request is granted (read)
    if bmfre_in.bmrd_req = '1' and r.bmrd_req_granted = '1' then
      outp.rc_start      := '1';
      v.read_pending     := '1';
      v.bmrd_req_granted := '0';
      v.bmrd_data_pos(0) := '1';
      v.rd_error         := '0';
    end if;

    if excl_enabled = true then

      --exclusive access is acknowledged (only for AHB)
      if bmfre_in.bmrd_req = '1' and r.bmrd_req_granted = '1' and bmfre_in.excl_en = '1' then
        outp.rc_start      := '0';
        v.read_pending     := '0';
        excl_pending       := '1';
        v.bmrd_req_granted := '0';
        v.bmrd_data_pos(0) := '1';
        v.bmwr_req_granted := '0';
        v.excl_addr        := inp.bmrd_addr;
        v.excl_size        := bmrd_size;
      end if;

    else

      v.excl_addr := (others => '0');
      v.excl_size := (others => '0');
      
    end if;

    --sample only when the request is granted (write)
    if bmfre_in.bmwr_req = '1' and r.bmwr_req_granted = '1' and (excl_enabled = false or bmfre_in.excl_nowrite = '0') then
      outp.wc_start      := '1';
      outp.fe_fwrite     := '1';
      v.write_pending    := '1';
      v.wr_byte_ctr      := bm_dw/8;
      v.bmwr_req_granted := '0';
      --actual size is size+1
      v.bmwr_size        := unsigned('0' & inp.bmwr_size)+1;

      --there is a counter for writes to accept number of words
      --determined by the size and the first word is always
      --accepted at the same time with the write request.
      --For read accesses this counter is not needed
      --since it is handled by the middle and back-end
      v.wr_byte_ctr := r.wr_byte_ctr + BMDW_size;

      if v.bmwr_size <= bm_dw/8 then
        --if the total size of the write is smaller or equal
        --to the data-width of front-end then the only word
        --is latched so assert the write full flag
        v.full_mask := '1';
      else
        v.full_mask := '0';
      end if;

      if bm_dw > be_dw then
        --if bus master data-width is larged than back-end
        --datawidth latch the word
        v.bmwr_data_latched := inp.bmwr_data;
        v.bmwr_data_pos     := (others => '0');
        v.bmwr_data_pos(1)  := '1';
      end if;
    end if;

    if r.read_pending = '1' then
      --A read operation is acknowledged and ongoing
      v.bmrd_req_granted := '0';

      if bm_dw = be_dw then
        --if bus master data width is equal to back-end
        --data width directly propagate the data and control
        --signals from the middle-end
        outp.bmrd_valid := bmfre_in.fe_rvalid_rc;
        outp.bmrd_error := bmfre_in.rd_error;
      end if;

      if bm_dw > be_dw then

        --if bus master data width is larged than back-end
        --data width latch the words until a full-word is
        --latched or the last beat in the entire read operation
        --is read

        if bmfre_in.fe_rvalid_rc = '1' then

          if bmfre_in.rd_error = '1' then
            --propagate error for the data-word if any of the
            --beat recieves an error
            v.rd_error := '1';
          end if;

          for i in 0 to bmbedw_rate-2 loop
            if r.bmrd_data_pos(i) = '1' then
                v.bmrd_data_latched((i+1)*be_dw-1 downto i*be_dw) := inp.fe_rdata;
            end if;
          end loop;  -- i

          --shift the position for the upcoming beat in the word
          v.bmrd_data_pos(0) := r.bmrd_data_pos(bmbedw_rate-1);

          for i in 1 to bmbedw_rate-1 loop
            v.bmrd_data_pos(i) := r.bmrd_data_pos(i-1);
          end loop;  -- i

          --full word is about to be latched so can be forwarded or the
          --last beat in the entire read operation is read so the word can be
          --forwarded
          if r.bmrd_data_pos(bmbedw_rate-1) = '1' or bmfre_in.fe_rlast = '1' then
            outp.bmrd_valid := '1';
            outp.bmrd_error := v.rd_error;
            v.rd_error      := '0';
          end if;
          
        end if;
        
      end if;

      if bmfre_in.fe_rlast = '1' then
        --last beat in the entire read operation is read
        --a new read can be accepted next cycle
        outp.bmrd_done     := '1';
        v.bmrd_req_granted := '1';
        v.read_pending     := '0';
        if bm_dw > be_dw then
          v.bmrd_data_pos := (others => '0');
        end if;
      end if;
      
    end if;

    if r.write_pending = '1' then
      --A write operation is acknowledged and ongoing
      v.bmwr_req_granted := '0';

      if (r.wr_byte_ctr + (bm_dw/8) >= r.bmwr_size) then
        --last word in the write is being latched
        if (bmfre_in.fe_ren = '1') then
          if (bm_dw = be_dw) then
            --if front-end width is equal to back-end width 
            --assert the write full flag
            v.full_mask := '1';
          else                          
            if r.bmwr_data_pos(0) = '1' then
              --if front-end width is larged than back-end width
              --asert the write full flag when the last beat is
              --writen
              v.full_mask := '1';
            end if;
          end if;
        end if;
      else
        if (bmfre_in.fe_ren = '1') then
          if bm_dw = be_dw then
            v.wr_byte_ctr := r.wr_byte_ctr + BMDW_size;
          else                          --bmdw_bedw
            if r.bmwr_data_pos(0) = '1' then
              v.wr_byte_ctr := r.wr_byte_ctr + BMDW_size;
            end if;
          end if;
        end if;
      end if;



      if bm_dw > be_dw then
        if bmfre_in.fe_ren = '1' then
          --shift the multiplexer position
          v.bmwr_data_pos(0) := r.bmwr_data_pos((bm_dw/be_dw)-1);
          for i in 1 to (bm_dw/be_dw)-1 loop
            v.bmwr_data_pos(i) := r.bmwr_data_pos(i-1);
          end loop;  -- i

          --latch the new word after wraparound
          if r.bmwr_data_pos(0) = '1' then
            v.bmwr_data_latched := inp.bmwr_data;
          end if;
        end if;
      end if;

      if bmfre_in.wc_done = '1' then
        --last beat in the entire write operation is written
        --and acknowledged, a new write can be accepted next cycle
        v.bmwr_req_granted := '1';
        v.write_pending    := '0';
        v.full_mask        := '0';
        v.wr_byte_ctr      := 0;

        if bm_dw > be_dw then
          v.bmwr_data_pos := (others => '0');
        end if;
      end if;
      
    end if;

    bmwr_data_muxed := inp.bmwr_data(bm_dw-1 downto bm_dw-be_dw);
    if lendian_en /= 0 then
      bmwr_data_muxed := inp.bmwr_data(be_dw-1 downto 0);
    end if;
    bmwr_pos_mask   := '0';
    if bm_dw > be_dw then
      for i in 1 to (bm_dw/be_dw)-1 loop
        if r.bmwr_data_pos(i) = '1' then
          bmwr_pos_mask   := '1';
          if lendian_en = 0 then
            bmwr_data_muxed := r.bmwr_data_latched(bm_dw-(i*(be_dw))-1 downto bm_dw-(i+1)*be_dw);
          end if;
          if lendian_en /= 0 then
            bmwr_data_muxed := r.bmwr_data_latched((i+1)*be_dw-1 downto i*be_dw);
          end if;
        end if;
      end loop;  -- i
    end if;

    if (bm_dw = be_dw) then
      fe_wdata <= inp.bmwr_data;
    else
      --if the front-end data width is larged than
      --back-end data width use the narrow-width multiplexer
      --to propagate the data
      fe_wdata <= bmwr_data_muxed;
    end if;

    --write full flag 
    if bm_dw = be_dw then
      --if front-end width is equal to back-end width full mask
      --is always asserted when all the bytes are written or the middle-end
      --do not request a new data
      bmfre_out.bmwr_full <= r.full_mask or not(bmfre_in.fe_ren);
    else
      --if front-end width is larged than back-end width full mask
      --is always asserted when all the bytes are written or the middle-end
      --do not request a new data or it requests a data but data is already
      --latched
      bmfre_out.bmwr_full <= r.full_mask or not(bmfre_in.fe_ren) or bmwr_pos_mask;
    end if;


    --locked access state machine (only for AHB back-end)
    --locked access rules
    --A read opeartion must be followed by a write operation
    --and the transaction parameters (like address, size)
    --must be identical. It is possible to skip the write
    --operation by asserting the excl_nowrite signal
    if excl_enabled = true then
      case r.excl_state is
        when idle =>
          if excl_pending = '1' then
            --exclusive request recieved
            v.excl_state := pending;
          end if;
        when pending =>
          --exclusive operation starts only when
          --write channel is free
          v.bmwr_req_granted := '0';
          v.bmrd_req_granted := '0';
          if r.write_pending = '0' then
            --start the read operation and lock the bus
            outp.rc_start  := '1';
            outp.lock      := '1';
            v.excl_state   := read_ongoing;
            v.read_pending := '1';
          end if;

        when read_ongoing =>
          v.bmrd_req_granted := '0';

          if bmfre_in.fe_rlast = '1' then
            --read operation is finished move to the write operation
            v.excl_state := write_ongoing;
          else
            v.bmwr_req_granted := '0';
          end if;

        when write_ongoing =>
          v.bmrd_req_granted := '0';

          if bmfre_in.excl_nowrite = '1' and r.bmwr_req_granted = '1' then
            --write operation is going to be skipped in this case
            --it will go to idle state when the lock is removed from the bus
            v.bmwr_req_granted := '0';
            v.lock_remove      := '1';
          end if;

          if bmfre_in.wc_done = '1' then
            --lock is removed go to idle state
            v.bmrd_req_granted := '1';
            v.excl_state       := idle;
            v.excl_done        := '1';
          end if;

        when others => null;
      end case;
    else
      v.excl_state := idle;
      outp.lock    := '0';
    end if;

    rin <= v;

    --port assignments
    bmfre_out.wc_start         <= outp.wc_start;
    bmfre_out.rc_start         <= outp.rc_start;
    bmfre_out.bmwr_req_granted <= r.bmwr_req_granted;
    bmfre_out.bmrd_req_granted <= r.bmrd_req_granted;
    bmfre_out.fe_fwrite        <= outp.fe_fwrite;
    bmfre_out.bmrd_valid       <= outp.bmrd_valid;
    bmfre_out.bmrd_done        <= outp.bmrd_done;
    bmfre_out.lock             <= outp.lock;
    excl_addr                  <= r.excl_addr;
    bmfre_out.lock_remove      <= r.lock_remove;
    excl_size                  <= r.excl_size;
    bmfre_out.excl_done        <= r.excl_done;
    bmfre_out.bmrd_error       <= outp.bmrd_error;

    if lendian_en = 0 then
      for i in 0 to (bm_dw/8)-1 loop
        bmrd_data_v(((i+1)*8)-1 downto i*8) := outp.bmrd_data((bm_dw-1)-(i*8) downto bm_dw-((i+1)*8));
      end loop;
    end if;
    
    if lendian_en /= 0 then
      for i in 0 to (bm_dw/8)-1 loop
        bmrd_data_v := outp.bmrd_data;
      end loop;
    end if;

    bmrd_data <= bmrd_data_v;

    bmfre_out.fe_rvalid_wc <= '1';
    
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
