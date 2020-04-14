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
------------------------------------------------------------------------------
-- Package:     grdmac2_pkg
-- File:        grdmac2_pkg.vhd
-- Author:      Krishna K R - Cobham Gaisler AB
-- Description: Internal package for GRDMAC2
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
library techmap;
use techmap.gencomp.all;


package grdmac2_pkg is

-------------------------------------------------------------------------------
-- Types and records
-------------------------------------------------------------------------------

  -- BM specific types
  type bm_out_type is record  --Input to grdmac2_ctrl from bus master interface output
    -- Read channel
    rd_data      : std_logic_vector(127 downto 0);
    rd_req_grant : std_logic;
    rd_valid     : std_logic;
    rd_done      : std_logic;
    rd_err       : std_logic;
    -- Write channel
    wr_req_grant : std_logic;
    wr_full      : std_logic;
    wr_done      : std_logic;
    wr_err       : std_logic;
  end record;

  type bm_in_type is record  --Output from grdmac2_ctrl to bus master interface input
    -- Read channel
    rd_addr : std_logic_vector(31 downto 0);
    rd_size : std_logic_vector(9 downto 0);
    rd_req  : std_logic;
    -- Write channel
    wr_addr : std_logic_vector(31 downto 0);
    wr_size : std_logic_vector(9 downto 0);
    wr_req  : std_logic;
    wr_data : std_logic_vector(127 downto 0);
  end record;

  -- Reset value for Bus Master interface signals
  constant BM_OUT_RST : bm_out_type := (
    rd_data      => (others => '0'),
    rd_req_grant => '0',
    rd_valid     => '0',
    rd_done      => '0',
    rd_err       => '0',
    -- Write channel
    wr_req_grant => '0',
    wr_full      => '0',
    wr_done      => '0',
    wr_err       => '0'
    );

  constant BM_IN_RST : bm_in_type := (
    -- Read channel
    rd_addr => (others => '0'),
    rd_size => (others => '0'),
    rd_req  => '0',
    -- Write channel
    wr_addr => (others => '0'),
    wr_size => (others => '0'),
    wr_req  => '0',
    wr_data => (others => '0')
    );  

  -- Bus master control registers
  type bm_ctrl_reg_type is record
    -- Read access
    rd_addr : std_logic_vector(31 downto 0);
    rd_size : std_logic_vector(9 downto 0);
    rd_req  : std_logic;
    -- Write channel
    wr_addr : std_logic_vector(31 downto 0);
    wr_size : std_logic_vector(9 downto 0);
    wr_req  : std_logic;
    wr_data : std_logic_vector(127 downto 0);
  end record;

  -- Reset value for Bus Master control registers
  constant BM_CTRL_REG_RST : bm_ctrl_reg_type := (
    rd_addr => (others => '0'),
    rd_size => (others => '0'),
    rd_req  => '0',
    wr_addr => (others => '0'),
    wr_size => (others => '0'),
    wr_req  => '0',
    wr_data => (others => '0')
    );

  -- FIFO input/output 
  type fifo_in_type is record
    clr_n : std_ulogic;       
    ren   : std_ulogic;
    wen   : std_ulogic;
    wdata : std_logic_vector(127 downto 0);
  end record;

  type fifo_out_type is record
    full   : std_ulogic;
    afull  : std_ulogic;
    empty  : std_ulogic;
    aempty : std_ulogic;
    rdata  : std_logic_vector(127 downto 0);
  end record;

  --Reset values for fifo registers
  constant FIFO_IN_RST : fifo_in_type := (
    clr_n => '0',
    ren   => '0',
    wen   => '0',
    wdata => (others => '0')
    );

  constant FIFO_OUT_RST : fifo_out_type := (
    full   => '0',
    afull  => '0',
    empty  => '0',
    aempty => '0',
    rdata  => (others => '0')
    );  

  -- status out type 
  type status_out_type is record
    err             : std_ulogic;       -- General error status.Assered along with other errors
    decode_desc_err : std_ulogic;       -- Error while decoding descriptor 
    rd_desc_err     : std_ulogic;       -- Error while reading desc from BM IF
    rd_data_err     : std_ulogic;       -- Error while reading data from BM IF
    wr_data_err     : std_ulogic;       -- Error while writing data to BM IF
    pol_err         : std_ulogic;       -- Error on conditional polling 
    trig_err        : std_ulogic;       -- Error on conditional trigger
    state           : std_logic_vector(4 downto 0);  -- Current operating state of DMA              
    timeout         : std_ulogic;       -- Timeout error
    wb_err          : std_ulogic;       -- Descriptor Write back error
    ongoing         : std_ulogic;       -- Ongoing DMA operation
    desc_comp       : std_ulogic;       -- Descriptor completed flag
    paused          : std_ulogic;       -- DMA is paused
    kick            : std_ulogic;       -- Kick flag
    restart         : std_ulogic;       -- Restart flag
    rd_nxt_ptr_err  : std_ulogic;       -- Error during re-reading des.nxt_ptr field on a kick request
    comp            : std_ulogic;       -- all desc are completed
    fifo_err        : std_ulogic;       -- Error signal from fifo
    
  end record;

   -- reset value for status out type
  constant STATUS_OUT_RST : status_out_type := (
    err             => '0',
    decode_desc_err => '0',
    rd_desc_err     => '0',
    rd_data_err     => '0',
    wr_data_err     => '0',
    pol_err         => '0',
    trig_err        => '0',
    state           => (others => '0'),
    timeout         => '0',
    wb_err          => '0',
    ongoing         => '0',
    desc_comp       => '0',
    paused          => '0',
    kick            => '0',
    restart         => '0',
    rd_nxt_ptr_err  => '0',
    comp            => '0',
    fifo_err        => '0'
    );

  -- Data execution status out type 
  type d_ex_sts_out_type is record
    m2b_err   : std_ulogic;                    -- Error while reading data from BM IF
    b2m_err   : std_ulogic;                    -- Error while writing data to BM IF
    state     : std_logic_vector(4 downto 0);  -- Current state of data execution in M2B/B2M      
    paused    : std_ulogic;                    -- Paused due to buffer full/empty
    operation : std_ulogic;                    -- Ongoing execution
    comp      : std_ulogic;                    -- M2B operation completed
    fifo_err  : std_ulogic;                    -- Error signal from fifo
  end record;

   -- reset value for status out type
  constant D_EX_STS_RST : d_ex_sts_out_type := (
    m2b_err   => '0',
    b2m_err   => '0',
    state     => (others => '0'),
    paused    => '0',
    operation => '0',
    comp      => '0',
    fifo_err  => '0'
    );  

  -- Current descriptor out type
  type curr_des_out_type is record
    dbg_ctrl     : std_logic_vector (31 downto 0);  -- Current descriptor ctrl field
    dbg_nxt      : std_logic_vector (31 downto 0);  -- Next_desc pointer of current descriptor
    dbg_fnxt     : std_logic_vector (31 downto 0);  -- c_des:f_nxt_des, d_des:dest_addr
    dbg_cnd_addr : std_logic_vector (31 downto 0);  -- c_des:cond_addr, d_des:src_addr
    dbg_sts      : std_logic_vector (31 downto 0);  -- c_des:status, d_des:status
    dbg_cnd_data : std_logic_vector (31 downto 0);  -- c_des:cond data, d_des:Null
    dbg_msk      : std_logic_vector (31 downto 0);  -- c_des: Mask,d_des : Null
  end record;

  -- Reset value for M2B/B2M current descriptor out type
  constant CUR_DES_OUT_RST : curr_des_out_type := (
    dbg_ctrl     => (others => '0'),
    dbg_nxt      => (others => '0'),
    dbg_fnxt     => (others => '0'),
    dbg_cnd_addr => (others => '0'),
    dbg_sts      => (others => '0'),
    dbg_cnd_data => (others => '0'),
    dbg_msk      => (others => '0')
    );

  -----------------------------------------------------------------------------
  -- GRDMAC2 descriptor types
  -----------------------------------------------------------------------------

   -- Next descriptor structure
  type nxt_des_type is record
    ptr  : std_logic_vector(31 downto 0);  -- Next descriptor pointer 
    last : std_ulogic;                     -- Last descriptor
  end record;

  -- Reset value for next descriptor structure
  constant NXT_DES_RST : nxt_des_type := (
    ptr  => (others => '0'),
    last => '0'
    );  

  -- Data descriptor control 
  type data_dsc_ctrl_type is record
    en           : std_ulogic;                    -- Enable descriptor 
    desc_type    : std_logic_vector(3 downto 0);  -- Type of descriptor. 0 for data 
    write_back   : std_ulogic;                    -- Write back status to descriptor after completion
    src_bm_num   : std_ulogic;                    -- Bus master index for M2B
    dest_bm_num  : std_ulogic;                    -- Bus master index for B2M
    irq_en       : std_ulogic;                    -- Interrupt enable on descriptor completion 
    src_fix_adr  : std_ulogic;                    -- Fetch data from fixed address
    dest_fix_adr : std_ulogic;                    -- Write data to fixed address
    size         : std_logic_vector(20 downto 0); -- Size of data to be transfered
  end record;

  -- Reset value for data descriptor control
  constant DATA_DSC_CTRL_RST : data_dsc_ctrl_type := (
    en           => '0',
    desc_type    => (others => '0'),
    write_back   => '0',
    src_bm_num   => '0',
    dest_bm_num  => '0',
    irq_en       => '0',
    src_fix_adr  => '0',
    dest_fix_adr => '0',
    size         => (others => '0')
    );

  -- Data descriptor status
  --type data_dsc_sts_type is record
    --done : std_ulogic;                         -- Done executing descriptor
    --err  : std_ulogic;                         -- Error during descriptor execution 
  --end record;

  -- Reset value for data descriptor
  --constant DATA_DSC_STS_RST : data_dsc_sts_type := (
    --done => '0',
    --err  => '0'
    --);

  -- Data descriptor structure 
  type data_dsc_strct_type is record
    ctrl      : data_dsc_ctrl_type;             -- Data descriptor control
    nxt_des   : nxt_des_type;                   -- Next descriptor pointer
    dest_addr : std_logic_vector(31 downto 0);  -- Address where data is to be written
    src_addr  : std_logic_vector(31 downto 0);  -- Address from where data is to be fetched    
  end record;

  -- Reset value for data descriptor structure
  constant DATA_DSC_STRCT_RST : data_dsc_strct_type := (
    ctrl      => DATA_DSC_CTRL_RST,
    nxt_des   => NXT_DES_RST,
    dest_addr => (others => '0'),
    src_addr  => (others => '0')
    );

  -- Conditional descriptor control
  type cond_dsc_ctrl_type is record
    en           : std_ulogic;                    -- Enabled conditional descriptor
    desc_type    : std_logic_vector(3 downto 0);  -- Type of descriptor. 1-polling,2-triggering,3- poll on irq
    write_back   : std_ulogic;                    -- Write back status to descriptor after completion
    bm_num       : std_ulogic;                    -- Bus master interface index for polling accesses
    irqn         : std_logic_vector(5 downto 0);  -- IRQ line number to be monitored
    err_to       : std_ulogic;                    --Error on timeout. 0- timeout is a failed condition. 1- timeout is an error
    irq_en       : std_ulogic;                    -- IRQ enable on descriptor completion
    trig_type    : std_ulogic;                    -- Trigger type- 0- edge triggered, 1- level triggered
    pol_interval : std_logic_vector(7 downto 0);  -- Interval between each polling 
    cond_count   : std_logic_vector(7 downto 0);  -- Number of times the condition check to be executed before failure
  end record;

  -- Reset value for conditional desc control
  constant COND_DSC_CTRL_RST : cond_dsc_ctrl_type := (
    en           => '0',
    desc_type    => (others => '0'),
    write_back   => '0',
    bm_num       => '0',
    irqn         => (others => '0'),
    err_to       => '0',
    irq_en       => '0',
    trig_type    => '0',
    pol_interval => (others => '0'),
    cond_count   => (others => '0')
    );

   -- Next descriptor on faliure condition 
  type f_nxt_des_type is record
    ptr  : std_logic_vector(31 downto 0);  -- Next descriptor pointer on condition failure
    last : std_ulogic;                     -- Last descriptor
  end record;

  -- Reset value for f_nxt descriptor structure
  constant F_NXT_DES_RST : f_nxt_des_type := (
    ptr  => (others => '0'),
    last => '0'
    );

   -- conditional address field 
  type cond_addr_type is record
    ptr      : std_logic_vector(31 downto 0);  -- Address to be polled
    trig_val : std_ulogic;                     -- Expected trigger value. If edge triggered: 0- rising edge, 1- Falling edge.
                                               -- If level triggered: 0- level high, 1- Level low
  end record;

  -- Reset value for conditional address field
  constant COND_ADDR_RST : cond_addr_type := (
    ptr      => (others => '0'),
    trig_val => '0'
    );  

   -- Conditional descriptor status
  --type cond_dsc_sts_type is record
    --done      : std_ulogic; -- Done executing descriptor
    --err       : std_ulogic; -- Error during descriptor execution
    --cond_pass : std_ulogic; -- Status of condition check. 1- Successful condition check 2- Failed condition check. Based on this user can know which next descriptor pointer has been selected
  --end record;

  -- Reset value for data descriptor
  --constant COND_DSC_STS_RST : cond_dsc_sts_type := (
    --done     => '0',
    --err      => '0',
    --cond_sts => '0'
    --);

  -- Conditional descriptor structure
  type cond_dsc_strct_type is record
    ctrl      : cond_dsc_ctrl_type;             -- Conditional descriptor control
    nxt_des   : nxt_des_type;                   -- Next descriptor pointer on success
    f_nxt_des : f_nxt_des_type;                 -- Next descriptor pointer on failure    
    cond_addr : cond_addr_type;                 -- Address to be polled and expected trigger value
    cond_data : std_logic_vector(31 downto 0);  -- Expected data
    cond_mask : std_logic_vector(31 downto 0);  -- Conditional mask
  end record;

  -- Reset value for conditional descriptor structure
  constant COND_DSC_STRCT_RST : cond_dsc_strct_type := (
    ctrl      => COND_DSC_CTRL_RST,
    nxt_des   => NXT_DES_RST,
    f_nxt_des => F_NXT_DES_RST,
    cond_addr => COND_ADDR_RST,
    cond_data => (others => '0'),
    cond_mask => (others => '0')
    );



  -----------------------------------------------------------------------------
  -- GRDMAC2 register types
  -----------------------------------------------------------------------------

  -- GRDMAC2 control register
  type grdmac2_ctrl_reg_type is record
    en      : std_ulogic;  -- GRDMAC2 core enable
    rst     : std_ulogic;  -- GRDMAC2 core reset
    kick    : std_ulogic;  -- Kick DMA
    restart : std_ulogic;  -- Restart DMA operation    
    irq_en  : std_ulogic;  -- Global Interrupt enable
    irq_msk : std_ulogic;  -- Interrupt mask bit
    irq_err : std_ulogic;  -- Enable interrupt on errors
    te      : std_ulogic;  -- Timer enable to handle timeout error while conditional     
  end record;

  -- Reset value for GRDMAC2 control register
  constant GRDMAC2_CTRL_REG_RST : grdmac2_ctrl_reg_type := (
    en      => '0',
    rst     => '0',
    kick    => '0',
    restart => '0',
    irq_en  => '0',
    irq_msk => '0',
    irq_err => '0',
    te      => '0'
    );

  -- GRDMAC2 status register : 
  type grdmac2_sts_reg_type is record
    comp            : std_ulogic;                    -- Completed all descriptors successfully
    err             : std_ulogic;                    -- Error on channel    
    ongoing         : std_ulogic;                    -- Ongoing DMA operation
    paused          : std_ulogic;                    -- Paused DMA operation
    irq_flag        : std_ulogic;                    -- Interrupt flag            
    decode_err      : std_ulogic;                    -- M2B error during desc decoding
    rd_desc_err     : std_ulogic;                    -- Error from m2b BMI during desc reading
    pol_err         : std_ulogic;                    -- Error on m2b conditional polling 
    trig_err        : std_ulogic;                    -- Error on m2b conditional trigger
    wb_err          : std_ulogic;                    -- Error during m2b desc writeback
    state           : std_logic_vector(4 downto 0);  -- M2b state in which error captured
    timeout         : std_ulogic;                    -- Timeout while condition check
    m2b_rd_data_err : std_ulogic;                    -- Error from m2b BMI during data fetching         
    b2m_wr_data_err : std_ulogic;                    -- Error from b2m BMI during data writing
    restart_pend    : std_ulogic;                    -- Pending restart request flag
    kick_pend       : std_ulogic;                    -- Pending Kick request flag
    rd_nxt_ptr_err  : std_ulogic;                    -- Error during re-reading des.nxt_ptr field on a kick request
    fifo_err        : std_ulogic;                    -- FIFO error
    active          : std_ulogic;                    -- Core enabled after reset
  end record;

  -- Reset value for GRDMAC2 status register
  constant GRDMAC2_STS_REG_RST : grdmac2_sts_reg_type := (
    comp            => '0',
    err             => '0',
    ongoing         => '0',
    paused          => '0',
    irq_flag        => '0',
    decode_err      => '0',
    rd_desc_err     => '0',
    pol_err         => '0',
    trig_err        => '0',
    wb_err          => '0',
    state           => (others => '0'),
    timeout         => '0',
    m2b_rd_data_err => '0',
    b2m_wr_data_err => '0',
    restart_pend    => '0',
    kick_pend       => '0',
    rd_nxt_ptr_err  => '0',
    fifo_err        => '0',
    active          => '0'
    );

  -- GRDMAC2 Timer reset value register 
  type grdmac2_trst_reg_type is record
    trst_val : std_logic_vector(31 downto 0);  -- Timer reset value 
  end record;

   -- Reset value for GRDMAC2 Timer reset value register
  constant GRDMAC2_TRST_REG_RST : grdmac2_trst_reg_type := (
    trst_val => (others => '0')
    );

  -- GRDMAC2 capability register (read only)

  --ver          : std_ulogic;                   -- Version of GRDMAC
  --en_bm1       : std_ulogic;                   -- Second bus master 
  --ft           : std_logic_vector(1 downto 0); -- Fault tolerant buffer
  --te           : std_ulogic;                   -- Timout timer enabled
  --abits        : std_logic_vector(15 downto 0);-- Binary logarthm of buffer size
  --dbits        : std_logic_vector(15 downto 0);-- Binary logarthm of data width

  -- GRDMAC2 descriptor pointer register
  -- This register points to the first descriptor. 
  type grdmac2_desc_ptr_type is record
    ptr : std_logic_vector(31 downto 0);  -- Descriptor pointer  
  end record;

  -- Reset value for GRDMAC2 descriptor pointer register
  constant GRDMAC2_DESC_PTR_RST : grdmac2_desc_ptr_type := (
    ptr => (others => '0')
    );

  -- Current descriptor control field for debug. 
  type cur_desc_ctrl_type is record
    ctrl : std_logic_vector(31 downto 0);
  end record;

  -- Reset value for current descriptor control field
  constant CUR_DESC_CTRL_RST : cur_desc_ctrl_type := (
    ctrl => (others => '0')
    );

  -- Current descriptor's nxt_des_ptr field for debug. 
  type cur_nxt_des_type is record
    ptr : std_logic_vector(31 downto 0);
  end record;

  -- Reset value for current descriptor's nxt_des_ptr field 
  constant CUR_NXT_DES_RST : cur_nxt_des_type := (
    ptr => (others => '0')
    );

  -- Current descriptor's f_nxt_des_ptr field for debug. 
  -- c_des:f_nxt_des, d_des:dest_addr
  type cur_fnxt_des_type is record
    ptr : std_logic_vector(31 downto 0);
  end record;

  -- Reset value for current descriptor's f_nxt_des_ptr field 
  constant CUR_FNXT_DES_RST : cur_fnxt_des_type := (
    ptr => (others => '0')
    );  

  -- Current descriptor's conditional address field for debug. 
  -- c_des:cond_addr, d_des:src_addr
  type cur_cond_addr_type is record
    addr : std_logic_vector(31 downto 0);
  end record;

  -- Reset value for current descriptor's address field 
  constant CUR_COND_ADR_RST : cur_cond_addr_type := (
    addr => (others => '0')
    );

  -- Current descriptor's status field for debug. 
  type cur_desc_sts_type is record
    sts : std_logic_vector(31 downto 0);
  end record;

  -- Reset value for current descriptor's sts field 
  constant CUR_DESC_STS_RST : cur_desc_sts_type := (
    sts => (others => '0')
    );   

  -- Current descriptor's conditional data field for debug.
  -- c_des:cond data, d_des:Null  
  type cur_cond_data_type is record
    data : std_logic_vector(31 downto 0);
  end record;

  -- Reset value for current descriptor's sts field 
  constant CUR_COND_DATA_RST : cur_cond_data_type := (
    data => (others => '0')
    ); 

  -- Current descriptor's conditional mask field for debug.
  -- c_des: Mask,d_des : Null 
  type cur_cond_msk_type is record
    mask : std_logic_vector(31 downto 0);
  end record;

  -- Reset value for current descriptor's sts field 
  constant CUR_COND_MSK_RST : cur_cond_msk_type := (
    mask => (others => '0')
    );

  -- Current descriptor pointer for debug.
  type cur_desc_ptr_type is record
    ptr : std_logic_vector(31 downto 0);
  end record;

  -- Reset value for current descriptor's sts field 
  constant CUR_DESC_PTR_RST : cur_desc_ptr_type := (
    ptr => (others => '0')
    ); 

  -- GRDMAC combined register type
  type grdmac2_reg_type is record
    ctrl     : grdmac2_ctrl_reg_type;   -- Control register
    sts      : grdmac2_sts_reg_type;    -- Status register
    trst     : grdmac2_trst_reg_type;   -- Timer reset value register
    desc_ptr : grdmac2_desc_ptr_type;   -- Descriptor pointer
  end record;

  -- Reset value for reg_type
  constant GRDMAC2_REG_RST : grdmac2_reg_type := (
    ctrl     => GRDMAC2_CTRL_REG_RST,
    sts      => GRDMAC2_STS_REG_RST,
    trst     => GRDMAC2_TRST_REG_RST,
    desc_ptr => GRDMAC2_DESC_PTR_RST
    );

  -------------------------------------------------------------------------------
  -- Subprograms
  -------------------------------------------------------------------------------
  function find_burst_size(src_fixed_addr  : std_ulogic;
                           dest_fixed_addr : std_ulogic;
                           max_bsize       : integer;
                           total_size      : std_logic_vector(20 downto 0);
                           buff_size       : integer
                           )
  return std_logic_vector;

  -------------------------------------------------------------------------------
  -- Components
  -------------------------------------------------------------------------------
  -- GRDMAC2 APB interface
  component grdmac2_apb is
    generic (
      pindex   : integer                 := 0;
      paddr    : integer                 := 0;
      pmask    : integer                 := 16#FF8#;
      pirq     : integer                 := 0;
      en_bm1   : integer                 := 0;
      ft       : integer range 0 to 5    := 0;
      abits    : integer range 0 to 10   := 4;
      en_timer : integer                 := 0;
      dbits    : integer range 32 to 128 := 32
      );
    port (
      rstn          : in  std_ulogic;
      clk           : in  std_ulogic;
      apbi          : in  apb_slv_in_type;
      apbo          : out apb_slv_out_type;
      ctrl_out      : out grdmac2_ctrl_reg_type;
      trst_out      : out grdmac2_trst_reg_type;
      desc_ptr_out  : out grdmac2_desc_ptr_type;
      active        : out std_ulogic;
      err_status    : out std_ulogic;
      irq_flag_sts  : in  std_ulogic;
      curr_desc_in  : in  curr_des_out_type;
      curr_desc_ptr : in  std_logic_vector(31 downto 0);
      fifo_rusedw   : in std_logic_vector(abits-1 downto 0);
      sts_in        : in  status_out_type
          );
  end component;

  -- Control Module
  component grdmac2_ctrl is
    generic (
      dbits : integer range 32 to 128 := 32);
    port (
      rstn          : in  std_ulogic;
      clk           : in  std_ulogic;
      trigger       : in  std_logic_vector(63 downto 0);
      ctrl          : in  grdmac2_ctrl_reg_type;
      des_ptr       : in  grdmac2_desc_ptr_type;
      active        : in  std_ulogic;
      trst          : in  grdmac2_trst_reg_type;
      err_status    : in  std_ulogic;
      curr_desc_out : out curr_des_out_type;
      curr_desc_ptr : out std_logic_vector(31 downto 0);
      status        : out status_out_type;
      irq_flag_sts  : out std_ulogic;
      bm_in         : in  bm_out_type;
      bm_out        : out bm_in_type;
      bm_num        : out std_ulogic;
      m2b_bm_in     : in  bm_ctrl_reg_type;
      m2b_bm_out    : out bm_out_type;
      b2m_bm_in     : in  bm_ctrl_reg_type;
      b2m_bm_out    : out bm_out_type;
      d_desc_out    : out data_dsc_strct_type;
      ctrl_rst      : out std_ulogic;
      err_sts_out   : out std_ulogic;
      m2b_start     : out std_ulogic;
      m2b_sts_in    : in  d_ex_sts_out_type;
      m2b_resume    : out std_ulogic;
      b2m_sts_in    : in  d_ex_sts_out_type;
      b2m_start     : out std_logic;
      b2m_resume    : out std_ulogic
          );
  end component;

  -- B2M
  component buf2mem is
    generic (
      dbits      : integer range 32 to 128  := 32;
      bm_bytes   : integer range 4 to 16    := 4;
      buff_bytes : integer range 4 to 16384 := 64;
      buff_depth : integer range 1 to 1024  := 16;
      abits      : integer range 0 to 10    := 4;
      ft         : integer range 0 to 5     := 0
      );
    port (
      rstn       : in  std_ulogic;
      clk        : in  std_ulogic;
      ctrl_rst   : in  std_ulogic;
      err_sts_in : in  std_ulogic;
      b2m_start  : in  std_ulogic;
      b2m_resume : in  std_ulogic;
      d_des_in   : in  data_dsc_strct_type;
      status_out : out d_ex_sts_out_type;
      b2m_bmi    : in  bm_out_type;
      b2m_bmo    : out bm_ctrl_reg_type;
      buf_err    : in std_logic_vector((((dbits+7)/8)-1)*(1-ft/4)+ft/4 downto 0);
      buf_in     : in  fifo_out_type;
      buf_out    : out fifo_in_type
          );
   end component;

   -- M2B
  component mem2buf is
    generic (
      dbits      : integer range 32 to 128  := 32;
      bm_bytes   : integer range 4 to 16    := 4;
      buff_bytes : integer range 4 to 16384 := 64;
      buff_depth : integer range 1 to 1024  := 16;
      abits      : integer range 0 to 10    := 4
      );
    port (
      rstn       : in  std_ulogic;
      clk        : in  std_ulogic;
      ctrl_rst   : in  std_ulogic;
      err_sts_in : in  std_ulogic;
      m2b_start  : in  std_ulogic;
      m2b_resume : in  std_ulogic;
      d_des_in   : in  data_dsc_strct_type;
      status_out : out d_ex_sts_out_type;
      m2b_bmi    : in  bm_out_type;
      m2b_bmo    : out bm_ctrl_reg_type;
      buf_in     : in  fifo_out_type;
      buf_out    : out fifo_in_type
          );
  end component;

  --GRDMAC2 core
  component grdmac2 is
    generic (
      tech     : integer range 0 to NTECH     := inferred;
      pindex   : integer                      := 0;
      paddr    : integer                      := 0;
      pmask    : integer                      := 16#FF8#;
      pirq     : integer range 0 to NAHBIRQ-1 := 0;
      dbits    : integer range 32 to 128      := 32;
      en_bm1   : integer                      := 0;
      ft       : integer range 0 to 5         := 0;
      abits    : integer range 0 to 22        := 4;
      en_timer : integer                      := 0
      );
    port (
      rstn    : in  std_ulogic;
      clk     : in  std_ulogic;
      apbi    : in  apb_slv_in_type;
      apbo    : out apb_slv_out_type;
      bm0_in  : out bm_in_type;
      bm1_in  : out bm_in_type;
      bm0_out : in  bm_out_type;
      bm1_out : in  bm_out_type;
      trigger : in  std_logic_vector(63 downto 0));
  end component;

  -- grdmac2_ahb top level interface
  component grdmac2_ahb is
    generic (
      tech             : integer range 0 to NTECH     := inferred;
      pindex           : integer                      := 0;
      paddr            : integer                      := 0;
      pmask            : integer                      := 16#FF8#;
      pirq             : integer range 0 to NAHBIRQ-1 := 0;
      dbits            : integer range 32 to 128      := 32;
      en_bm1           : integer                      := 0;
      hindex0          : integer                      := 0;
      hindex1          : integer                      := 1;
      max_burst_length : integer range 2 to 256       := 256;
      ft               : integer range 0 to 5         := 0;
      abits            : integer range 0 to 22        := 4;
      en_timer         : integer                      := 0
      );
    port (
      rstn    : in  std_ulogic;
      clk     : in  std_ulogic;
      apbi    : in  apb_slv_in_type;
      apbo    : out apb_slv_out_type;
      ahbmi0  : in  ahb_mst_in_type;
      ahbmo0  : out ahb_mst_out_type;
      ahbmi1  : in  ahb_mst_in_type;
      ahbmo1  : out ahb_mst_out_type;
      trigger : in  std_logic_vector(63 downto 0)
      );
  end component;
  
end package grdmac2_pkg;

package body grdmac2_pkg is
  -- Function to determine the burst size based on maximum burst limit
  function find_burst_size (
    src_fixed_addr  : std_ulogic;
    dest_fixed_addr : std_ulogic;
    max_bsize       : integer;
    total_size      : std_logic_vector(20 downto 0);
    buff_size       : integer
    )
    return std_logic_vector is
    variable temp       : integer;
    variable burst_size : std_logic_vector(10 downto 0);
    variable total_int  : integer;
  begin
    total_int := conv_integer(total_size);
    -- Limit the burst burst size by maximum burst length
    if (src_fixed_addr or dest_fixed_addr) = '1' then
      if total_int < 4 then             -- less than 4 bytes
        temp := total_int;
      else
        temp := 4;
      end if;
    elsif (total_int > max_bsize) then
      temp := max_bsize;
    else
      temp := total_int;
    end if;
    -- Limit the burst size by fifo size
    if temp > buff_size then
      burst_size := conv_std_logic_vector(buff_size, 11);
    else
      burst_size := conv_std_logic_vector(temp, 11);
    end if;
    return burst_size;
  end find_burst_size;
    

end package body grdmac2_pkg;
