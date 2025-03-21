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

  constant REVISION : integer := 1;

-------------------------------------------------------------------------------
-- Types and records
-------------------------------------------------------------------------------

  type aes_in_type is record
    init      : std_logic;
    bn        : integer;
    size      : integer;
    key       : std_logic_vector(255 downto 0);
    plaintext : std_logic_vector(127 downto 0);
    iv        : std_logic_vector(127 downto 0);
  end record;

  type aes_out_type is record
    ciphertext : std_logic_vector(127 downto 0);
    done       : std_logic;
    brdy       : std_logic;
  end record;

  constant AES_OUT_RST : aes_out_type := (
    ciphertext => (others => '0'),
    done       => '0',
    brdy       => '0'
    );

  type sha_in_type is record
    init      : std_logic;
    new_block : std_logic;
    bn        : integer;
    size      : integer;
    inp       : std_logic_vector(511 downto 0);
  end record;

  type sha_out_type is record
    outp       : std_logic_vector(255 downto 0);
    finished   : std_logic;
    paused     : std_logic;
  end record;

  constant SHA_OUT_RST : sha_out_type := (
    outp       => (others => '0'),
    finished   => '0',
    paused   => '0'
    );

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

  -- ACC descriptor control 
  type acc_dsc_ctrl_type is record
    en           : std_ulogic;                    -- Enable descriptor 
    desc_type    : std_logic_vector(3 downto 0);  -- Type of descriptor. 5 for acc update
    write_back   : std_ulogic;                    -- Write back status to descriptor after completion
    src_bm_num   : std_ulogic;                    -- Bus master index for M2B
    irq_en       : std_ulogic;                    -- Interrupt enable on descriptor completion 
    src_fix_adr  : std_ulogic;                    -- Fetch data from fixed address
    size         : std_logic_vector(22 downto 0); -- Size of data to be transfered
  end record;

  -- Reset value for ACC descriptor control
  constant ACC_DSC_CTRL_RST : acc_dsc_ctrl_type := (
    en           => '0',
    desc_type    => (others => '0'),
    write_back   => '0',
    src_bm_num   => '0',
    irq_en       => '0',
    src_fix_adr  => '0',
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

  -- ACC descriptor structure 
  type acc_dsc_strct_type is record
    ctrl      : acc_dsc_ctrl_type;             -- ACC descriptor control
    nxt_des   : nxt_des_type;                   -- Next descriptor pointer
    src_addr  : std_logic_vector(31 downto 0);  -- Address from where data is to be fetched    
  end record;

  -- Reset value for ACC descriptor structure
  constant ACC_DSC_STRCT_RST : acc_dsc_strct_type := (
    ctrl      => ACC_DSC_CTRL_RST,
    nxt_des   => NXT_DES_RST,
    src_addr  => (others => '0')
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

  -- Miscellaneous internal registers
  type grdmac2_misc_type is record
    err_irq       : std_ulogic;  --Register to find rising edge of the error status signal
    cmp_irq       : std_ulogic;  --Register to find rising edge of the error status signal
    irq_sts_clrd  : std_ulogic;  --shows if the IRQ flag is cleared by writing 1 to 'irq_flag' status bits 
  end record;

  -- Reset value for Miscellaneous internal registers
  constant GRDMAC2_MISC_RST : grdmac2_misc_type := (
    err_irq => '0',
    cmp_irq => '0',
    irq_sts_clrd => '0'
    ); 

  -- GRDMAC combined register type
  type grdmac2_reg_type is record
    ctrl     : grdmac2_ctrl_reg_type;   -- Control register
    sts      : grdmac2_sts_reg_type;    -- Status register
    trst     : grdmac2_trst_reg_type;   -- Timer reset value register
    desc_ptr : grdmac2_desc_ptr_type;   -- Descriptor pointer
    misc     : grdmac2_misc_type;       -- Miscellaneous internal registers
  end record;

  -- Reset value for reg_type
  constant GRDMAC2_REG_RST : grdmac2_reg_type := (
    ctrl     => GRDMAC2_CTRL_REG_RST,
    sts      => GRDMAC2_STS_REG_RST,
    trst     => GRDMAC2_TRST_REG_RST,
    desc_ptr => GRDMAC2_DESC_PTR_RST,
    misc     => GRDMAC2_MISC_RST
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
  
  -- Word swap
  function bl_wrd_swap(
    constant data : std_logic_vector; 
    constant endian : std_ulogic; 
    constant dw : integer) 
  return std_logic_vector;

  -- Endianness signal generation
  function endian_decode(
    constant endian : integer
    ) return std_ulogic;

  -- Endianness check on both bus master interfaces
  function endian_check(
    signal bm0_endian : std_logic;
    signal bm1_endian : std_logic;
    constant en_bm1     : integer
    ) return boolean;
  
  function acc_generic_check(
    constant dbits      : integer;
    constant abits      : integer;
    constant en_acc     : integer
    ) return boolean;

  function padding(in_vector : std_logic_vector(511 downto 0);
                       burst_size : integer;
                       tot_size : integer
    ) return std_logic_vector;


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
      dbits    : integer range 32 to 128 := 32;
      en_acc   : integer range 0 to 4    := 0
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
      irqf_clr_sts      : out std_ulogic;
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
      irqf_clr_sts      : in std_ulogic;
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
      b2m_resume    : out std_ulogic;
      acc_sts_in    : in d_ex_sts_out_type;
      acc_start     : out std_ulogic;
      acc_resume    : out std_ulogic;
      acc_desc_out  : out acc_dsc_strct_type
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
      abits      : integer range 0 to 10    := 4;
      en_acc     : integer range 0 to 4     := 0
      );
    port (
      rstn       : in  std_ulogic;
      clk        : in  std_ulogic;
      ctrl_rst   : in  std_ulogic;
      err_sts_in : in  std_ulogic;
      m2b_start  : in  std_ulogic;
      m2b_resume : in  std_ulogic;
      d_des_in   : in  data_dsc_strct_type;
      acc_des_in : in  acc_dsc_strct_type;
      status_out : out d_ex_sts_out_type;
      m2b_bmi    : in  bm_out_type;
      m2b_bmo    : out bm_ctrl_reg_type;
      buf_in     : in  fifo_out_type;
      buf_out    : out fifo_in_type;
      endian     : in std_logic 
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
      en_timer : integer                      := 0;
      en_acc   : integer                      := 0
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
      bm0_endian  : in std_logic;
      bm1_endian  : in std_logic;
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
      en_timer         : integer                      := 0;
      en_acc           : integer                      := 0
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

  -- grdmac2_axi top level interface
  component grdmac2_axi is
    generic (
      tech             : integer range 0 to NTECH     := inferred;
      pindex           : integer                      := 0;
      paddr            : integer                      := 0;
      pmask            : integer                      := 16#FF8#;
      pirq             : integer range 0 to NAHBIRQ-1 := 0;
      dbits            : integer range 32 to 128      := 32;
      en_bm1           : integer                      := 0;
      max_burst_length : integer range 2 to 256       := 256;
      ft               : integer range 0 to 5         := 0;
      abits            : integer range 0 to 10        := 4;
      en_timer         : integer                      := 0;
      lendian_en       : integer                      := 0;
      en_acc           : integer range 0 to 4         := 0
      );
    port (
      rstn    : in  std_ulogic;
      clk     : in  std_ulogic;
      apbi    : in  apb_slv_in_type;
      apbo    : out apb_slv_out_type;
      aximi0  : in  axi_somi_type;
      aximo0  : out axi4_mosi_type;
      aximi1  : in  axi_somi_type;
      aximo1  : out axi4_mosi_type;
      trigger : in  std_logic_vector(63 downto 0)
    );
  end component;

  -- ACC
  component grdmac2_acc is
    generic (
      dbits      : integer range 32 to 128  := 32;
      bm_bytes   : integer range 4 to 16    := 4;
      buff_bytes : integer range 4 to 16384 := 64;
      buff_depth : integer range 1 to 1024  := 16;
      abits      : integer range 0 to 10    := 4;
      acc_enable : integer range 0 to 4     := 0
      );
    port (
      rstn        : in  std_ulogic;
      clk         : in  std_ulogic;
      ctrl_rst    : in  std_ulogic;
      d_des_in    : in  data_dsc_strct_type;
      acc_des_in  : in  acc_dsc_strct_type;
      acc_start   : in  std_ulogic;
      acc_resume  : in  std_ulogic;
      acc_status  : out d_ex_sts_out_type;
      m2b_status  : in d_ex_sts_out_type;
      endian      : in std_logic;
      buf_in      : in  fifo_out_type;
      buf_out     : out fifo_in_type
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

  -- Word swap
  function bl_wrd_swap(
    constant data : std_logic_vector; 
    constant endian : std_ulogic; 
    constant dw : integer
    ) return std_logic_vector is
    variable newdata : std_logic_vector(dw-1 downto 0);
    variable words_n : integer := 0;
    variable outdata : std_logic_vector(dw-1 downto 0);
  begin
    words_n := dw/32;

    if endian = '0' then
      outdata := data;
    else
      for i in 0 to (words_n -1) loop
        outdata((i*32)+31 downto i*32):= data( ((words_n - i)*32)-1 downto (words_n - (i + 1))*32 );
      end loop;
    end if;
    return outdata;
  end bl_wrd_swap; 

  -- Endianness signal generation
  function endian_decode(
    constant endian : integer
    ) return std_ulogic is
    variable endian_l : std_ulogic := '0';
  begin
    if endian = 1 then
      endian_l := '1';
    else
      endian_l := '0';
    end if;
    return endian_l;
  end endian_decode; 

  -- Endianness check on both bus master interfaces
  function endian_check(
    signal bm0_endian : std_logic;
    signal bm1_endian : std_logic;
    constant en_bm1     : integer
    ) return boolean is
  begin
    if en_bm1 = 0 then
      return true;
    elsif bm0_endian = bm1_endian then
      return true;
    else      
      return false;
    end if;
  end endian_check;

  -- Generics check when acc enabled
  function acc_generic_check(
    constant dbits    : integer;
    constant abits    : integer;
    constant en_acc   : integer
    ) return boolean is
  begin
    if (en_acc = 0) then
      return true;
    elsif (en_acc = 1 and dbits = 32 and abits >= 2) then
      return true;
    elsif (en_acc = 1 and dbits = 64 and abits >= 1) then
      return true;
    elsif (en_acc = 1 and dbits = 128) then
      return true;
    elsif ((en_acc = 2 or en_acc = 3) and dbits = 32 and abits >= 4) then
      return true;
    elsif ((en_acc = 2 or en_acc = 3) and dbits = 64 and abits >= 3) then
      return true;
    elsif ((en_acc = 2 or en_acc = 3) and dbits = 128 and abits >= 2) then
      return true;
    else
      return false;
    end if;
  end acc_generic_check;

  -- pad used in SHA
  function padding (
      in_vector : std_logic_vector(511 downto 0);
      burst_size : integer;
      tot_size : integer
    ) return std_logic_vector is
    variable ret : std_logic_vector(511 downto 0);
  begin
    case burst_size is
    when 1 => 
      ret(511 downto 504) := in_vector(511 downto 504);
      ret(503) := '1';
      ret(502 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 2 => 
      ret(511 downto 496) := in_vector(511 downto 496);
      ret(495) := '1';
      ret(494 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 3 => 
      ret(511 downto 488) := in_vector(511 downto 488);
      ret(487) := '1';
      ret(486 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 4 => 
      ret(511 downto 480) := in_vector(511 downto 480);
      ret(479) := '1';
      ret(478 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 5 => 
      ret(511 downto 472) := in_vector(511 downto 472);
      ret(471) := '1';
      ret(470 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 6 => 
      ret(511 downto 464) := in_vector(511 downto 464);
      ret(463) := '1';
      ret(462 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 7 => 
      ret(511 downto 456) := in_vector(511 downto 456);
      ret(455) := '1';
      ret(454 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 8 => 
      ret(511 downto 448) := in_vector(511 downto 448);
      ret(447) := '1';
      ret(446 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 9 => 
      ret(511 downto 440) := in_vector(511 downto 440);
      ret(439) := '1';
      ret(438 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 10 => 
      ret(511 downto 432) := in_vector(511 downto 432);
      ret(431) := '1';
      ret(430 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 11 => 
      ret(511 downto 424) := in_vector(511 downto 424);
      ret(423) := '1';
      ret(422 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 12 => 
      ret(511 downto 416) := in_vector(511 downto 416);
      ret(415) := '1';
      ret(414 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 13 => 
      ret(511 downto 408) := in_vector(511 downto 408);
      ret(407) := '1';
      ret(406 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 14 => 
      ret(511 downto 400) := in_vector(511 downto 400);
      ret(399) := '1';
      ret(398 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 15 => 
      ret(511 downto 392) := in_vector(511 downto 392);
      ret(391) := '1';
      ret(390 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 16 => 
      ret(511 downto 384) := in_vector(511 downto 384);
      ret(383) := '1';
      ret(382 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 17 => 
      ret(511 downto 376) := in_vector(511 downto 376);
      ret(375) := '1';
      ret(374 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 18 => 
      ret(511 downto 368) := in_vector(511 downto 368);
      ret(367) := '1';
      ret(366 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 19 => 
      ret(511 downto 360) := in_vector(511 downto 360);
      ret(359) := '1';
      ret(358 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 20 => 
      ret(511 downto 352) := in_vector(511 downto 352);
      ret(351) := '1';
      ret(350 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 21 => 
      ret(511 downto 344) := in_vector(511 downto 344);
      ret(343) := '1';
      ret(342 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 22 => 
      ret(511 downto 336) := in_vector(511 downto 336);
      ret(335) := '1';
      ret(334 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 23 => 
      ret(511 downto 328) := in_vector(511 downto 328);
      ret(327) := '1';
      ret(326 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 24 => 
      ret(511 downto 320) := in_vector(511 downto 320);
      ret(319) := '1';
      ret(318 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 25 => 
      ret(511 downto 312) := in_vector(511 downto 312);
      ret(311) := '1';
      ret(310 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 26 => 
      ret(511 downto 304) := in_vector(511 downto 304);
      ret(303) := '1';
      ret(302 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 27 => 
      ret(511 downto 296) := in_vector(511 downto 296);
      ret(295) := '1';
      ret(294 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 28 => 
      ret(511 downto 288) := in_vector(511 downto 288);
      ret(287) := '1';
      ret(286 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 29 => 
      ret(511 downto 280) := in_vector(511 downto 280);
      ret(279) := '1';
      ret(278 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 30 => 
      ret(511 downto 272) := in_vector(511 downto 272);
      ret(271) := '1';
      ret(370 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 31 => 
      ret(511 downto 264) := in_vector(511 downto 264);
      ret(263) := '1';
      ret(262 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 32 => 
      ret(511 downto 256) := in_vector(511 downto 256);
      ret(255) := '1';
      ret(254 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 33 => 
      ret(511 downto 248) := in_vector(511 downto 248);
      ret(247) := '1';
      ret(246 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 34 => 
      ret(511 downto 240) := in_vector(511 downto 240);
      ret(239) := '1';
      ret(238 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 35 => 
      ret(511 downto 232) := in_vector(511 downto 232);
      ret(231) := '1';
      ret(230 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 36 => 
      ret(511 downto 224) := in_vector(511 downto 224);
      ret(223) := '1';
      ret(222 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 37 => 
      ret(511 downto 216) := in_vector(511 downto 216);
      ret(215) := '1';
      ret(214 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 38 => 
      ret(511 downto 208) := in_vector(511 downto 208);
      ret(207) := '1';
      ret(206 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 39 => 
      ret(511 downto 200) := in_vector(511 downto 200);
      ret(199) := '1';
      ret(198 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 40 => 
      ret(511 downto 192) := in_vector(511 downto 192);
      ret(191) := '1';
      ret(190 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 41 => 
      ret(511 downto 184) := in_vector(511 downto 184);
      ret(183) := '1';
      ret(182 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 42 => 
      ret(511 downto 176) := in_vector(511 downto 176);
      ret(175) := '1';
      ret(174 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 43 => 
      ret(511 downto 168) := in_vector(511 downto 168);
      ret(167) := '1';
      ret(166 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 44 => 
      ret(511 downto 160) := in_vector(511 downto 160);
      ret(159) := '1';
      ret(158 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 45 => 
      ret(511 downto 152) := in_vector(511 downto 152);
      ret(151) := '1';
      ret(150 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 46 => 
      ret(511 downto 144) := in_vector(511 downto 144);
      ret(143) := '1';
      ret(142 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 47 => 
      ret(511 downto 136) := in_vector(511 downto 136);
      ret(135) := '1';
      ret(134 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 48 => 
      ret(511 downto 128) := in_vector(511 downto 128);
      ret(127) := '1';
      ret(126 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 49 => 
      ret(511 downto 120) := in_vector(511 downto 120);
      ret(119) := '1';
      ret(118 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 50 => 
      ret(511 downto 112) := in_vector(511 downto 112);
      ret(111) := '1';
      ret(110 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 51 => 
      ret(511 downto 104) := in_vector(511 downto 104);
      ret(103) := '1';
      ret(102 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 52 => 
      ret(511 downto 96) := in_vector(511 downto 96);
      ret(95) := '1';
      ret(94 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 53 => 
      ret(511 downto 88) := in_vector(511 downto 88);
      ret(87) := '1';
      ret(86 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 54 => 
      ret(511 downto 80) := in_vector(511 downto 80);
      ret(79) := '1';
      ret(78 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 55 => 
      ret(511 downto 72) := in_vector(511 downto 72);
      ret(71) := '1';
      ret(70 downto 64) := (others => '0');
      ret(63 downto 0) := std_logic_vector(to_unsigned(tot_size*8, 64));
    when 56 => 
      ret(511 downto 64) := in_vector(511 downto 64);
      ret(63) := '1';
      ret(62 downto 0) := (others => '0');
    when 57 => 
      ret(511 downto 56) := in_vector(511 downto 56);
      ret(55) := '1';
      ret(54 downto 0) := (others => '0');
    when 58 => 
      ret(511 downto 48) := in_vector(511 downto 48);
      ret(47) := '1';
      ret(46 downto 0) := (others => '0');
    when 59 => 
      ret(511 downto 40) := in_vector(511 downto 40);
      ret(39) := '1';
      ret(38 downto 0) := (others => '0');
    when 60 => 
      ret(511 downto 32) := in_vector(511 downto 32);
      ret(31) := '1';
      ret(30 downto 0) := (others => '0');
    when 61 => 
      ret(511 downto 24) := in_vector(511 downto 24);
      ret(23) := '1';
      ret(22 downto 0) := (others => '0');
    when 62 => 
      ret(511 downto 16) := in_vector(511 downto 16);
      ret(15) := '1';
      ret(14 downto 0) := (others => '0');
    when 63 => 
      ret(511 downto 8) := in_vector(511 downto 8);
      ret(7) := '1';
      ret(6 downto 0) := (others => '0');
    when others =>
      ret := in_vector;
    end case;
    return ret;
  end padding;

    

end package body grdmac2_pkg;
