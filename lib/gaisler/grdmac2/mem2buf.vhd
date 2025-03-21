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
-- Entity:      mem2buf
-- File:        mem2buf.vhd
-- Author:      Krishna K R - Cobham Gaisler AB
-- Description: Read engine to read data from memory through a generic bus
-- master interface and fill in syncfifo_2p.
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


-----------------------------------------------------------------------------------------
-- Entity to perform memory to buffer data transfer
-----------------------------------------------------------------------------------------
-- M2B module deals with data fetch from memory to buffer. Data descriptor
-- fields are passed from grdmac2_ctrl module. m2b_start or m2b_resume signals
-- are asserted only for enabled data descriptors. Once the FIFO is filled with
-- data from source memory, M2B operation pauses and goes back to main control
-- state machine in grdmac2_ctrl and switches to B2M state to empty the FIFO.
-- Once the FIFO is empty, M2B operation is resumed. This continues until data
-- of size specified in d_des.ctrl.size field, is completely transferred.
------------------------------------------------------------------------------------------

entity mem2buf is
  generic (
    dbits      : integer range 32 to 128  := 32;  -- Bus master front end data
                                                  -- width and FIFO width
    bm_bytes   : integer range 4 to 16    := 4;   -- bus master data width in bytes
    buff_bytes : integer range 4 to 16384 := 64;  -- FIFO size in bytes
    buff_depth : integer range 1 to 1024  := 16;  -- FIFO depth
    abits      : integer range 0 to 10    := 4;   -- FIFO address bits (actual fifo depth = 2**abits)
    en_acc     : integer range 0 to 4     := 0
    );
  port (
    rstn       : in  std_ulogic;           -- Active low reset
    clk        : in  std_ulogic;           -- Clock
    -- Signals to and from grdmac2_ctrl
    ctrl_rst   : in  std_ulogic;           -- Reset signal from APB interface through grdmac_ctrl
    err_sts_in : in  std_ulogic;           -- Core error status from APB status register 
    m2b_start  : in  std_ulogic;           -- Start control signal
    m2b_resume : in  std_ulogic;           -- Resume control signal
    d_des_in   : in  data_dsc_strct_type;  -- Data descriptor needs to executed
    acc_des_in : in  acc_dsc_strct_type;
    status_out : out d_ex_sts_out_type;    -- M2b status out signals 
    -- Generic bus master interface
    m2b_bmi    : in  bm_out_type;          -- BM interface signals to M2B,through crontrol module
    m2b_bmo    : out bm_ctrl_reg_type;     -- Signals from M2B to BM IF throgh control module
    --FIFO signals
    buf_in     : in  fifo_out_type;        -- FIFO output signals
    buf_out    : out fifo_in_type;          -- Input to FIFO
    endian     : in std_logic               -- Endianness input '0'-> BE,'1'-> LE 
    );
end entity mem2buf;

------------------------------------------------------------------------------
-- Architecture of mem2buf
------------------------------------------------------------------------------

architecture rtl of mem2buf is
  attribute sync_set_reset         : string;
  attribute sync_set_reset of rstn : signal is "true";
  -----------------------------------------------------------------------------
  -- Constant declaration
  -----------------------------------------------------------------------------

  -- Reset configuration
  constant ASYNC_RST : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  -- Constants for mem2buf present state
  constant M2B_IDLE  : std_logic_vector(4 downto 0) := "00111";  -- 0x07
  constant M2B_EXEC  : std_logic_vector(4 downto 0) := "01000";  -- 0x08
  constant DATA_READ : std_logic_vector(4 downto 0) := "01001";  -- 0x09

  -- Constant for bit - byte manipulation
  constant SHIFT_BIT : natural := 3;
  -- Bus master interface front end width in bytes := dbits/8
  constant MAX_BSIZE : integer := 1024;  -- Maximum BM fe interface data size
                                         -- in single burst is 1024 bytes
  constant zeros : std_logic_vector(127 downto 0) := (others => '0');

  -----------------------------------------------------------------------------
  -- Type and record 
  -----------------------------------------------------------------------------

  -- M2B states --
  -- idle =>
  -- Starting state. Waits for 'm2b_start_in' signal to proceed.
  -- Decides on size of the current burst to be transferred
  --
  -- exec_data_desc =>
  -- Initiates bus master interface burst read transfer from source address.
  --
  -- read_data =>
  -- Reads each data word from bus master interface output and writes to FIFO
  -- unitl the buffer is full or the total data is transferred.

  type m2b_state_type is (idle, exec_data_desc, read_data);

  --M2B reg type
  type m2b_reg_type is record
    m2b_state    : m2b_state_type;                 -- M2B states
    sts          : d_ex_sts_out_type;              -- M2b status signals 
    tot_size     : std_logic_vector(20 downto 0);  -- Total size of data to read
    curr_size    : std_logic_vector(10 downto 0);  -- Remaining size in the burst, to be read
    inc          : integer range 0 to 2097152;     -- Index register for source address increment
    index        : integer range 0 to buff_bytes;  -- Index to check if buffer is full or not
    bmst_rd_busy : std_ulogic;                     -- bus master read busy
    bmst_rd_err  : std_ulogic;                     -- bus master read error
    err_state    : std_logic_vector(4 downto 0);   -- Error state
  end record;

  -- Reset value for M2B reg type
  constant M2B_REG_RES : m2b_reg_type := (
    m2b_state    => idle,
    sts          => D_EX_STS_RST,
    tot_size     => (others => '0'),
    curr_size    => (others => '0'),
    inc          => 0,
    index        => 0,
    bmst_rd_busy => '0',
    bmst_rd_err  => '0',
    err_state    => (others => '0')
    );

  -----------------------------------------------------------------------------
  -- Signal declaration
  -----------------------------------------------------------------------------
  signal r, rin : m2b_reg_type;
  
begin
  -----------------------------------------------------------------------------
  -- Assignments
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Combinational process
  -----------------------------------------------------------------------------
  
  comb : process (m2b_bmi, r, acc_des_in, d_des_in, buf_in, m2b_start, m2b_resume, err_sts_in)

    variable v             : m2b_reg_type;
    variable remaining     : std_logic_vector(20 downto 0);  -- Remaining size to be read after each burst
    variable buffer_out    : fifo_in_type;                   -- variable for holding output to buffer
    variable wr_bytes      : integer range 0 to 1024;        -- Number of bytes to be written in the current burst                                                           
    variable fix_buff_size : integer range 4 to 4096;        -- Buffer size when fixed source address configuration
    variable bmst_rd_req   : std_ulogic;                     -- bus master read request variable
    variable rem_bits      : integer range 0 to 120;         -- bits to fetch when current size is less than bm_bytes
  begin

    -- Default values 
    v                := r;
    buffer_out.clr_n := '1';
    buffer_out.ren   := '0';
    buffer_out.wen   := '0';
    buffer_out.wdata := (others => '0');
    remaining        := (others => '0');
    wr_bytes         := 0;
    -- During fixed source address configuration, buffer size used is (2**abits)* 4 bytes
    fix_buff_size    := to_integer(shift_left(to_unsigned(buff_depth, 22), 2));
    bmst_rd_req      := '0';
    m2b_bmo          <= BM_CTRL_REG_RST;
    rem_bits         := 0;

    -- M2B state machine
    case r.m2b_state is
      when idle =>
        -- Default values
        v.sts.operation := '0';
        v.index         := 0;
        v.curr_size     := (others => '0');
        v.sts.m2b_err   := '0';
        v.bmst_rd_busy  := '0';

        -- Operation starts when start/resume signal from control block arrives and no errors are present
        if m2b_start = '1' and err_sts_in = '0' then

          -- Logic for ACC descriptor -------------------------------
          if (d_des_in.ctrl.desc_type = X"5") then
            v.tot_size     := acc_des_in.ctrl.size(20 downto 0);
          else
            v.tot_size     := d_des_in.ctrl.size;
          end if;
          -----------------------------------------------------------

          v.err_state  := (others => '0');
          buffer_out.clr_n := '0';
          v.sts.operation  := '1';
          v.sts.comp       := '0';
          v.inc            := 0;
          v.bmst_rd_err    := '0';
          if orv(d_des_in.ctrl.size) = '0' then
            v.sts.comp := '1';
          end if;
          v.m2b_state := exec_data_desc;

          -- Logic for ACC descriptor --------------------------------------
          if (d_des_in.ctrl.desc_type = X"5") then
            v.curr_size := find_burst_size(src_fixed_addr       => d_des_in.ctrl.src_fix_adr,
                                                dest_fixed_addr => '0',
                                                max_bsize       => MAX_BSIZE,
                                                total_size      => acc_des_in.ctrl.size(20 downto 0),
                                                buff_size       => buff_bytes
                                                );
          else
            v.curr_size := find_burst_size(src_fixed_addr         => d_des_in.ctrl.src_fix_adr,
                                                dest_fixed_addr => d_des_in.ctrl.dest_fix_adr,
                                                max_bsize       => MAX_BSIZE,
                                                total_size      => d_des_in.ctrl.size,
                                                buff_size       => buff_bytes
                                                );
          end if;
          -------------------------------------------------------------------

        elsif m2b_resume = '1' and err_sts_in = '0' then  -- M2B restaring.
          v.err_state  := (others => '0');
          buffer_out.clr_n := '0';
          v.sts.m2b_err    := '0';
          v.sts.paused     := '0';
          v.sts.operation  := '1';
          v.sts.comp       := '0';
          v.bmst_rd_err    := '0';
          v.curr_size := find_burst_size(src_fixed_addr      => d_des_in.ctrl.src_fix_adr,
                                             dest_fixed_addr => d_des_in.ctrl.dest_fix_adr,
                                             max_bsize       => MAX_BSIZE,
                                             total_size      => r.tot_size,
                                             buff_size       => buff_bytes
                                             );          
          v.m2b_state := exec_data_desc;
        end if;
        ----------     
        
      when exec_data_desc =>
        if orv(r.curr_size) /= '0' then  -- More data remaining to be fetched
          if r.bmst_rd_busy = '0' then

            -- Logic for ACC descriptor ----------------------------------------------------
            if d_des_in.ctrl.src_fix_adr = '1' and d_des_in.ctrl.desc_type /= X"5" then
              -- Fixed address implementation
              -- If souce address is fixed, data is read in a looped manner from same source address. Single access. No burst              
              m2b_bmo.rd_addr <= d_des_in.src_addr;
            elsif acc_des_in.ctrl.src_fix_adr = '1' and d_des_in.ctrl.desc_type = X"5" then
              m2b_bmo.rd_addr <= acc_des_in.src_addr;
            elsif d_des_in.ctrl.desc_type = X"5" then
              m2b_bmo.rd_addr <= acc_des_in.src_addr + r.inc;
            else
             -- If souce address is not fixed, data is read as a burst. source address is incremented between bursts.
              m2b_bmo.rd_addr <= d_des_in.src_addr + r.inc;
            end if;
            --------------------------------------------------------------------------------

            m2b_bmo.rd_size <= conv_std_logic_vector(conv_integer(r.curr_size)-1, 10);
            bmst_rd_req     := '1';
            if bmst_rd_req = '1' and m2b_bmi.rd_req_grant = '1' then
              v.bmst_rd_busy := '1';
              v.m2b_state    := read_data;
            end if;
          end if;
        else                             -- Data fetch completed
          v.sts.comp      := '1';
          v.sts.operation := '0';
          v.m2b_state     := idle;
        end if;
      ----------
        
      when read_data =>
        -- If rd_valid is asserted and if there are no errors, data is valid.
        -- On each valid, dbits number of bits fetched through Bus master interface
        if m2b_bmi.rd_valid = '1' then
          if m2b_bmi.rd_err = '1' then
            v.bmst_rd_err := '1';
          elsif r.bmst_rd_err = '0' then
            if conv_integer(r.curr_size) >= bm_bytes then
              v.curr_size    := r.curr_size - bm_bytes;
              v.inc          := r.inc + bm_bytes;
              v.index        := r.index + bm_bytes;
              remaining      := r.tot_size - bm_bytes;
              wr_bytes       := bm_bytes;
              buffer_out.wen := '1';
              v.tot_size     := remaining;
            else                        --curr_size is less than bm_bytes
              v.curr_size    := (others => '0');
              v.inc          := r.inc + conv_integer(r.curr_size);
              v.index        := r.index + conv_integer(r.curr_size);
              remaining      := r.tot_size - r.curr_size;
              wr_bytes       := conv_integer(r.curr_size);
              buffer_out.wen := '1';
              v.tot_size     := remaining;
            end if;
          end if;

          -- Check if read burst is done
          if m2b_bmi.rd_done = '1' then
            if v.bmst_rd_err = '0' then  -- no bus master error                    
              if orv(remaining) /= '0' then
                v.curr_size := find_burst_size(src_fixed_addr   => d_des_in.ctrl.src_fix_adr,
                                                dest_fixed_addr => d_des_in.ctrl.dest_fix_adr,
                                                max_bsize       => MAX_BSIZE,
                                                total_size      => remaining,
                                                buff_size       => buff_bytes
                                                );
                if (d_des_in.ctrl.src_fix_adr or d_des_in.ctrl.dest_fix_adr) = '1' then -- Fixed address
                  if (r.index + wr_bytes) = fix_buff_size then  -- Fifo Full
                    v.sts.paused    := '1';  -- Buffer full. M2B is paused.
                    v.sts.operation := '0';
                    v.bmst_rd_busy  := '0';
                    v.index         := 0;
                    v.m2b_state     := idle;
                  else
                    v.m2b_state := exec_data_desc;
                  end if;
                else           
                  if (r.index + wr_bytes) = buff_bytes then
                    v.sts.paused    := '1';  -- Buffer full. M2B is paused.
                    v.sts.operation := '0';
                    v.bmst_rd_busy  := '0';
                    v.index         := 0;
                    v.m2b_state     := idle;
                  else
                    v.m2b_state := exec_data_desc;
                  end if;
                end if;
              else                      -- Data fetch completed
                v.m2b_state     := idle;
                v.sts.operation := '0';
                v.bmst_rd_busy  := '0';
                v.sts.comp      := '1';
              end if;
            else                        --bus master error
              v.bmst_rd_err := '1';
              v.sts.m2b_err := '1';
              v.err_state   := DATA_READ;
              v.m2b_state   := idle;
            end if;
            v.bmst_rd_busy := '0';
          end if;
        end if;
        ----------
      when others =>
        v.m2b_state := idle;
        ----------         
    end case;  --M2B state machine
    ----------------------
    -- Signal update --
    ----------------------
    -- Data write to buffer output
    buffer_out.wdata(127 downto (128-dbits)) := m2b_bmi.rd_data(127 downto (128-dbits));
    -- State decoding for status display
    if r.sts.m2b_err = '1' then
      status_out.state <= r.err_state;
    else
      case r.m2b_state is
        when exec_data_desc =>
          status_out.state <= M2B_EXEC;
        when read_data =>
          status_out.state <= DATA_READ;
        when others =>
          status_out.state <= M2B_IDLE;
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
    m2b_bmo.rd_req       <= bmst_rd_req;
     
  end process comb;

  -----------------------------------------------------------------------------
  -- Sequential Process
  -----------------------------------------------------------------------------

  seq : process (clk, rstn)
  begin
    if (rstn = '0' and ASYNC_RST) then
      r <= M2B_REG_RES;
    elsif rising_edge(clk) then
      if rstn = '0' or ctrl_rst = '1' then
        r <= M2B_REG_RES;
      else
        r <= rin;
      end if;
    end if;
  end process seq;
-----------------------------------------------------------------------------  
-- Component instantiation
-----------------------------------------------------------------------------
  
end architecture rtl;
