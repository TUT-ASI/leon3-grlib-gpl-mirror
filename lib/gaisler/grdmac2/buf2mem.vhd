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
-- Entity:      buf2mem
-- File:        buf2mem.vhd
-- Author:      Krishna K R - Cobham Gaisler AB
-- Description: Write engine to read data from buffer to memory through a generic bus
-- master interface.
------------------------------------------------------------------------------ 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.grdmac2_pkg.all;


-----------------------------------------------------------------------------
-- Entity to perform buffer to memory data transfer
-----------------------------------------------------------------------------------------
-- B2M module deals with data write from internal FIFO to memory. Data descriptor
-- fields are passed from grdmac2_ctrl module. b2m_start or b2m_resume signals
-- are asserted only for enabled data descriptors. Once the data from FIFO is
-- transferred to memory, execution pauses B2M operation and goes back to main control
-- state machine in grdmac2_ctrl and switches to M2B operation. Once the FIFO is full
-- or all data is fetched by M2B, B2M operation is resumed. This continues until data
-- of size specified in d_des.ctrl.size field, is completely transferred.
-- If FT is configured as a non zero value, fifo error status is monitoed for
-- any uncorrectable errors. Correctable errors are ignored. Uncorrectable
-- errors are reported.
------------------------------------------------------------------------------------------

entity buf2mem is
  generic (
    dbits      : integer range 32 to 128  := 32;  -- Bus master front end data
                                                  -- width and FIFO width
    bm_bytes   : integer range 4 to 16    := 4;   -- bus master data width in bytes
    buff_bytes : integer range 4 to 16384 := 32;  -- FIFO size in bytes
    buff_depth : integer range 1 to 1024  := 16;  -- FIFO depth
    abits      : integer range 0 to 10    := 4;   -- FIFO address bits (actual fifo depth = 2**abits)
    ft         : integer range 0 to 5     := 0    -- Enable EDAC on RAMs (GRLIB-FT only, passed on to syncram_2pft)
    );
  port (
    rstn        : in  std_ulogic;           -- Active low reset
    clk         : in  std_ulogic;           -- Clock
    -- Control input from grdmac2_ctrl
    ctrl_rst    : in  std_ulogic;           -- Reset signal from APB interface through grdmac_ctrl
    err_sts_in  : in  std_ulogic;           -- Core error status from APB status register 
    b2m_start   : in  std_ulogic;           -- Start control signal
    b2m_resume  : in  std_ulogic;           -- Resume control signal
    d_des_in    : in  data_dsc_strct_type;  -- Data descriptor needs to executed
    status_out  : out d_ex_sts_out_type;    -- M2b status out signals 
    -- Generic bus master interface
    b2m_bmi     : in  bm_out_type;          -- BM interface signals to B2M,through crontrol module 
    b2m_bmo     : out bm_ctrl_reg_type;     -- Signals from B2M to BM IF throgh control module
    --FIFO signals
    buf_err     : in std_logic_vector((((dbits+7)/8)-1)*(1-ft/4)+ft/4 downto 0);
    -- Error signal from FIFO
    buf_in      : in  fifo_out_type;        -- FIFO output signals
    buf_out     : out fifo_in_type          -- Input to FIFO
  );
end entity buf2mem;

------------------------------------------------------------------------------
-- Architecture of buf2mem
------------------------------------------------------------------------------

architecture rtl of buf2mem is
  attribute sync_set_reset         : string;
  attribute sync_set_reset of rstn : signal is "true";

  -----------------------------------------------------------------------------
  -- Constant declaration
  -----------------------------------------------------------------------------

  -- Reset configuration
  constant ASYNC_RST : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  -- Constants for buf2mem present state
  constant B2M_IDLE        : std_logic_vector(4 downto 0) := "01010";  -- 0x0A
  constant START_FIFO_READ : std_logic_vector(4 downto 0) := "01011";  -- 0x0B
  constant FIRST_WORD_WR   : std_logic_vector(4 downto 0) := "01100";  -- 0x0C 
  constant BURST           : std_logic_vector(4 downto 0) := "01101";  -- 0x0D
  constant WRITE_CHK       : std_logic_vector(4 downto 0) := "01110";  -- 0x0E

  -- Constant for bit - byte manipulation
  constant SHIFT_BIT : natural := 3;
  constant MAX_BSIZE : integer := 1024;  -- Maximum BM fe interface data size
                                         -- in single burst is 1024 bytes

  -----------------------------------------------------------------------------
  -- Type and record 
  -----------------------------------------------------------------------------

  -- B2M states --
  -- idle             : Starting state. Waits for 'b2m_start' or 'b2m_resume' signal to proceed
  -- exec_data_desc   : Execute data descriptor.
  -- write_init       : Initiate write and latch first data
  -- write_sec_data   : Latch second data and deassert write request
  -- write_burst      : Continue data write in the burst untill done
  -- write_data_check : Check if data burst write was successful.


  type b2m_state_type is (idle, first_word, write_burst, write_data_check, init_fifo_read);

  --B2M reg type
  type b2m_reg_type is record
    b2m_state    : b2m_state_type;                      -- B2M states
    sts          : d_ex_sts_out_type;                   -- B2M status signals
    tot_size     : std_logic_vector(20 downto 0);       -- Total size of data to write 
    curr_size    : std_logic_vector(10 downto 0);       -- Remaining size in the burst, to be written
    inc          : integer range 0 to 2097152;          -- For data destination address increment
    buf_rd_en    : std_ulogic;                          -- Registered fifo read ren
    buf_latched  : std_ulogic;                          -- FIFO output data latched flag
    buf_rd_data  : std_logic_vector(dbits-1 downto 0);  -- buffering rd_data
    d_grant      : std_ulogic;                          -- Delayed grant signal flag
    index        : integer range 0 to buff_bytes;       -- Index to check if buffer is empty
    bmst_wr_busy : std_ulogic;                          -- bus master write busy
    err_state    : std_logic_vector(4 downto 0);        -- Error state
  end record;

  -- Reset value for B2M reg type
  constant B2M_REG_RES : b2m_reg_type := (
    b2m_state    => idle,
    sts          => D_EX_STS_RST,
    tot_size     => (others => '0'),
    curr_size    => (others => '0'),
    inc          => 0,
    buf_rd_en    => '0',
    buf_latched  => '0',
    buf_rd_data  => (others => '0'),
    d_grant      => '0',
    index        => 0,
    bmst_wr_busy => '0',
    err_state    => (others => '0')
    );

  -----------------------------------------------------------------------------
  -- Signal declaration
  -----------------------------------------------------------------------------
  signal r, rin : b2m_reg_type;
  -----------------------------------------------------------------------------
  -- Function/procedure declaration
  -----------------------------------------------------------------------------
  function geterr (ft: integer; dbits: integer; errval: std_logic_vector) return std_logic_vector is
    variable r: std_logic_vector(2 downto 0);
    variable errvalx: std_logic_vector(errval'length-1 downto 0);
  begin
    errvalx := errval;
    r := "000";
    case ft is
      when 0 | 2 => null;               -- None / TMR
      when 1 =>                         -- Parity DMR
        r(2) := '1';
        if errvalx /= (errvalx'range => '0') then
          r(0) := '1';
        end if;
      when 3 =>                         -- Parity, no DMR
        r(2) := '1';
        if errvalx /= (errvalx'range => '0') then
          r(1) := '1';
        end if;
      when others =>                     -- SECDED
        r(2) := '1';
        r(1) := errvalx(1);
        r(0) := errvalx(0);
     end case;
    return r;
  end geterr;
  
begin
  -----------------------------------------------------------------------------
  -- Assignments
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Combinational process
  -----------------------------------------------------------------------------
  
  comb : process (b2m_bmi, r, d_des_in, buf_in, b2m_start, b2m_resume, err_sts_in, buf_err)
    variable v             : b2m_reg_type;
    variable sz_aftr_write : std_logic_vector(10 downto 0);  -- Index for data
                                                             -- remaing to be transferred
    variable buffer_out    : fifo_in_type;                   -- variable for holding output to buffer
    variable fix_buff_size : integer range 4 to 4096;        -- Buffer size when fixed source address configuration
    variable err           : std_logic_vector(2 downto 0);   -- error variable
    
  begin
    
    -- Default values
    v                := r;
    buffer_out.clr_n := '1';
    buffer_out.ren   := '0';
    buffer_out.wen   := '0';
    buffer_out.wdata := (others => '0');
    sz_aftr_write    := (others => '0');
    err              := (others => '0');
    -- During fixed source address configuration, buffer size used is (2**abits)* 4 bytes
    fix_buff_size    := to_integer(shift_left(to_unsigned(buff_depth, 22), 2));
    b2m_bmo          <= BM_CTRL_REG_RST;

    -- B2M state machine
    case r.b2m_state is
      when idle =>
        -- Default values
        v.sts.operation := '0';
        v.sts.comp      := '0';
        v.curr_size     := (others => '0');
        v.d_grant       := '0';
        v.sts.b2m_err   := '0';
        v.sts.fifo_err  := '0';
        v.bmst_wr_busy  := '0';
        -- Operation starts when start/resume signal from control block arrives and no errors are present
        if b2m_start = '1' and err_sts_in = '0' then
          v.err_state  := (others => '0');          
          v.sts.operation := '1';
          v.sts.comp      := '0';
          v.tot_size      := d_des_in.ctrl.size;
          v.inc           := 0;
          if orv(d_des_in.ctrl.size) = '0' then
            v.sts.comp := '1';
          end if;
          v.curr_size := find_burst_size(src_fixed_addr       => d_des_in.ctrl.src_fix_adr,
                                              dest_fixed_addr => d_des_in.ctrl.dest_fix_adr,
                                              max_bsize       => MAX_BSIZE,
                                              total_size      => d_des_in.ctrl.size,
                                              buff_size       => buff_bytes
                                              );
          v.b2m_state := init_fifo_read;
        elsif b2m_resume = '1' and err_sts_in = '0' then  -- B2M restaring.
          v.err_state  := (others => '0');
          v.sts.b2m_err   := '0';
          v.sts.paused    := '0';
          v.sts.operation := '1';
          v.sts.comp      := '0';
          v.curr_size := find_burst_size(src_fixed_addr      => d_des_in.ctrl.src_fix_adr,
                                             dest_fixed_addr => d_des_in.ctrl.dest_fix_adr,
                                             max_bsize       => MAX_BSIZE,
                                             total_size      => r.tot_size,
                                             buff_size       => buff_bytes
                                            );  
          v.b2m_state := init_fifo_read;
        end if;
        ----------

      when init_fifo_read =>
        if orv(r.curr_size) /= '0' then
          buffer_out.ren := '1';
          v.b2m_state    := first_word;
        else
          v.sts.comp  := '1';
          v.b2m_state := idle;
        end if;
        ----------
        
      when first_word =>  -- First data passed with write initiation
        if d_des_in.ctrl.dest_fix_adr = '1' then
          b2m_bmo.wr_addr <= d_des_in.dest_addr;
        else
          b2m_bmo.wr_addr <= d_des_in.dest_addr + r.inc;
        end if;
        if r.bmst_wr_busy = '0' then
          b2m_bmo.wr_size <= conv_std_logic_vector(conv_integer(r.curr_size)-1, 10);
          b2m_bmo.wr_req  <= '1';
          if b2m_bmi.wr_req_grant = '1' then
            v.bmst_wr_busy := '1';
            if conv_integer(r.curr_size) >= bm_bytes then
              sz_aftr_write := r.curr_size - bm_bytes;
              v.curr_size   := r.curr_size - bm_bytes;  -- Size pending, after writing first data
              v.inc         := r.inc + bm_bytes;
              v.index       := r.index + bm_bytes;
              v.tot_size    := r.tot_size - bm_bytes;
              if orv(sz_aftr_write) /= '0' then
                buffer_out.ren := '1';
                v.b2m_state    := write_burst;
              else
                v.b2m_state := write_data_check;
              end if;
            else
              v.curr_size := (others => '0');  -- Size pending, after writing first data
              v.inc       := r.inc + conv_integer(r.curr_size);
              v.index     := r.index + conv_integer(r.curr_size);
              v.tot_size  := r.tot_size - r.curr_size;
              v.b2m_state := write_data_check;
            end if;
          end if;
        end if;
        ----------
        
      when write_burst =>
        b2m_bmo.wr_req <= '0';
        if b2m_bmi.wr_full = '0' then
        -- r.curr_size is the remaining data size to be processed after writing second
        -- data or any of the data writes that comes after second data.
        -- Control reaches in write_burst state only if d_des_in.ctrl.size >=
        -- two words with bm_bytes size each.
            if conv_integer(r.curr_size) >= bm_bytes then
              sz_aftr_write := r.curr_size - bm_bytes;
              if orv(sz_aftr_write) /= '0' and buf_in.empty = '0' then  -- more data to be writen after current data write
                buffer_out.ren := '1';
              else
                v.b2m_state := write_data_check;
              end if;
                v.curr_size := r.curr_size - bm_bytes;
                v.inc       := r.inc + bm_bytes;
                v.index     := r.index + bm_bytes;
                v.tot_size  := r.tot_size - bm_bytes;
            else
              v.curr_size := (others => '0');  -- No more data pending, after writing 2nd data
              v.inc       := r.inc + conv_integer(r.curr_size);
              v.index     := r.index + conv_integer(r.curr_size);
              v.tot_size  := r.tot_size - conv_integer(r.curr_size);
              v.b2m_state := write_data_check;
            end if;
        end if;
      ----------      
        
      when write_data_check =>
        -- Evaluate if burst has finished
        if b2m_bmi.wr_done = '1' then
          v.bmst_wr_busy := '0';
          if b2m_bmi.wr_err = '0' then
            if orv(r.tot_size) /= '0' then
              v.curr_size := find_burst_size(src_fixed_addr   => d_des_in.ctrl.src_fix_adr,
                                              dest_fixed_addr => d_des_in.ctrl.dest_fix_adr,
                                              max_bsize       => MAX_BSIZE,
                                              total_size      => r.tot_size,
                                              buff_size       => buff_bytes
                                              );
              if (d_des_in.ctrl.src_fix_adr or d_des_in.ctrl.dest_fix_adr) = '1' and r.index = fix_buff_size then
                v.sts.paused    := '1';  -- Buffer empty. B2M is paused.
                v.sts.operation := '0';
                v.index         := 0;
                v.b2m_state     := idle;
              elsif r.index = buff_bytes then
                v.sts.paused    := '1';  -- Buffer empty. B2M is paused.
                v.sts.operation := '0';
                v.index         := 0;
                v.b2m_state     := idle;
              else
                v.b2m_state := init_fifo_read;
              end if;
            else
              v.index         := 0;
              v.bmst_wr_busy  := '0';
              v.sts.comp      := '1';
              v.sts.operation := '0';
              v.b2m_state     := idle;
            end if;
          else
            v.sts.b2m_err := '1';
            v.err_state   := WRITE_CHK;
            v.b2m_state   := idle;
          end if;
        end if;
        ----------
          
      when others =>
        v.b2m_state := idle;
        ----------         
    end case;  --B2M state machine
    ----------------------
    -- Signal update --
    ----------------------
    -- Bus master data write from FIFO. syncfifo_2p does not provide read_hold
    -- signal of syncram_2p. Logic below helps to register FIFO output data and
    -- writes correct data to the destination memory without missing any data.
    --if buffer_out.ren = '0' and r.buf_latched = '0' then
      --v.buf_rd_data := buf_in.rdata(127 downto (128-dbits));
    --end if;
      v.buf_rd_data := buf_in.rdata(127 downto (128-dbits));

    v.buf_rd_en := '0';
    if buffer_out.ren = '1' then
      v.buf_rd_en := '1';
    end if;

    --if r.buf_rd_en = '1' and b2m_bmi.wr_full = '1' then
      --v.buf_latched := '1';
    --end if;

    --if buffer_out.ren = '1' or r.b2m_state = idle then
      --v.buf_latched := '0';
    --end if;

    b2m_bmo.wr_data <= buf_in.rdata(127 downto (128-dbits)) & zero128(127-dbits downto 0);
    --if r.buf_latched = '1' then
      --b2m_bmo.wr_data <= r.buf_rd_data & zero128(127-dbits downto 0);
    --end if;

    -- FIFO error monitoring for uncorrectable errors
    if r.buf_rd_en = '1' then
      err := geterr(ft, dbits, buf_err);
      if ft /= 0 and err(1) = '1' then
        v.sts.fifo_err := '1';
        case r.b2m_state is
          when first_word =>
            v.err_state := FIRST_WORD_WR;
          when others =>
            v.err_state := BURST;
        end case;
        v.b2m_state    := idle;
      end if;
    end if;

    -- State decoding display
    if r.sts.b2m_err = '1' or r.sts.fifo_err = '1' then
      status_out.state <= r.err_state;
    else
      case r.b2m_state is
        when init_fifo_read =>
          status_out.state <= START_FIFO_READ;
        when first_word =>
          status_out.state <= FIRST_WORD_WR;
        when write_burst =>
          status_out.state <= BURST;
        when write_data_check =>
          status_out.state <= WRITE_CHK;
        when others =>
          status_out.state <= B2M_IDLE;
      end case;
    end if;
    rin                  <= v;
    status_out.m2b_err   <= r.sts.m2b_err;
    status_out.b2m_err   <= r.sts.b2m_err;
    status_out.paused    <= r.sts.paused;
    status_out.operation <= r.sts.operation;
    status_out.comp      <= r.sts.comp;
    status_out.fifo_err  <= r.sts.fifo_err;
    buf_out              <= buffer_out;
  end process comb;

  -----------------------------------------------------------------------------
  -- Sequential Process
  -----------------------------------------------------------------------------

  seq : process (clk, rstn)
  begin
    if (rstn = '0' and ASYNC_RST) then
      r <= B2M_REG_RES;
    elsif rising_edge(clk) then
      if rstn = '0' or ctrl_rst = '1' then
        r <= B2M_REG_RES;
      else
        r <= rin;
      end if;
    end if;
  end process seq;
-----------------------------------------------------------------------------  
-- Component instantiation
-----------------------------------------------------------------------------
  
end architecture rtl;



