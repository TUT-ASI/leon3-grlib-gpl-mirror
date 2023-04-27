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
-- Package:     generic_bm_pkg
-- File:        generic_bm_pkg.vhd
-- Company:     Cobham Gaisler AB
-- Description: Generic Bus Master signal definitions
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package generic_bm_pkg is

  --AHB related constants
  constant BMHTRANS_IDLE   : std_logic_vector(1 downto 0) := "00";
  constant BMHTRANS_BUSY   : std_logic_vector(1 downto 0) := "01";
  constant BMHTRANS_NONSEQ : std_logic_vector(1 downto 0) := "10";
  constant BMHTRANS_SEQ    : std_logic_vector(1 downto 0) := "11";

  constant BMHBURST_SINGLE : std_logic_vector(2 downto 0) := "000";
  constant BMHBURST_INCR   : std_logic_vector(2 downto 0) := "001";
  constant BMHBURST_WRAP4  : std_logic_vector(2 downto 0) := "010";
  constant BMHBURST_INCR4  : std_logic_vector(2 downto 0) := "011";
  constant BMHBURST_WRAP8  : std_logic_vector(2 downto 0) := "100";
  constant BMHBURST_INCR8  : std_logic_vector(2 downto 0) := "101";
  constant BMHBURST_WRAP16 : std_logic_vector(2 downto 0) := "110";
  constant BMHBURST_INCR16 : std_logic_vector(2 downto 0) := "111";

  constant BMHSIZE_BYTE   : std_logic_vector(2 downto 0) := "000";
  constant BMHSIZE_HWORD  : std_logic_vector(2 downto 0) := "001";
  constant BMHSIZE_WORD   : std_logic_vector(2 downto 0) := "010";
  constant BMHSIZE_DWORD  : std_logic_vector(2 downto 0) := "011";
  constant BMHSIZE_4WORD  : std_logic_vector(2 downto 0) := "100";
  constant BMHSIZE_8WORD  : std_logic_vector(2 downto 0) := "101";
  constant BMHSIZE_16WORD : std_logic_vector(2 downto 0) := "110";
  constant BMHSIZE_32WORD : std_logic_vector(2 downto 0) := "111";

  constant BMHRESP_OKAY  : std_logic_vector(1 downto 0) := "00";
  constant BMHRESP_ERROR : std_logic_vector(1 downto 0) := "01";
  constant BMHRESP_RETRY : std_logic_vector(1 downto 0) := "10";
  constant BMHRESP_SPLIT : std_logic_vector(1 downto 0) := "11";

  -- AXI constants
  constant BMXBURST_FIXED : std_logic_vector(1 downto 0) := "00";
  constant BMXBURST_INCR  : std_logic_vector(1 downto 0) := "01";
  constant BMXBURST_WRAP  : std_logic_vector(1 downto 0) := "10";

  constant BMXCACHE_BUFFERABLE  : std_logic_vector(3 downto 0) := "0001";
  constant BMXCACHE_CACHEABLE   : std_logic_vector(3 downto 0) := "0010";
  constant BMXCACHE_READ_ALLOC  : std_logic_vector(3 downto 0) := "0100";
  constant BMXCACHE_WRITE_ALLOC : std_logic_vector(3 downto 0) := "1000";

  constant BMXPROT_PRIV   : std_logic_vector(2 downto 0) := "001";
  constant BMXPROT_NONSEC : std_logic_vector(2 downto 0) := "010";
  constant BMXPROT_INSTR  : std_logic_vector(2 downto 0) := "100";

  constant BMXRESP_OKAY   : std_logic_vector(1 downto 0) := "00";
  constant BMXRESP_EXOKAY : std_logic_vector(1 downto 0) := "01";
  constant BMXRESP_SLVERR : std_logic_vector(1 downto 0) := "10";
  constant BMXRESP_DECERR : std_logic_vector(1 downto 0) := "11";


  function log_2(number : integer range 0 to 1048576)
    return integer;

  type ahb_bmst_in_type is record
    hgrant : std_logic;                     -- bus grant
    hready : std_ulogic;                    -- transfer done
    hresp  : std_logic_vector(1 downto 0);  -- response type
    endian : std_ulogic;                    -- 0->BE, 1->LE
  end record;

  -- AHB master outputs
  type ahb_bmst_out_type is record
    hbusreq : std_ulogic;                     -- bus request
    hlock   : std_ulogic;                     -- lock request
    htrans  : std_logic_vector(1 downto 0);   -- transfer type
    haddr   : std_logic_vector(31 downto 0);  -- address bus (byte)
    hwrite  : std_ulogic;                     -- read/write
    hsize   : std_logic_vector(2 downto 0);   -- transfer size
    hburst  : std_logic_vector(2 downto 0);   -- burst type
    hprot   : std_logic_vector(3 downto 0);   -- protection control
  end record;

  type ahb_be_in_type is record
    wr_req        : std_logic;
    rd_req        : std_logic;
    wr_size       : std_logic_vector(2 downto 0);
    rd_size       : std_logic_vector(2 downto 0);
    --  wr_addr     : std_logic_vector(31 downto 0);
    --  rd_addr     : std_logic_vector(31 downto 0);
    wdata_valid   : std_logic;
    lock          : std_logic;
    lock_remove   : std_logic;
  end record;

  type ahb_be_out_type is record
    rd_gnt           : std_logic;
    wr_gnt           : std_logic;
    wdata_ren        : std_logic;
    rdata_valid      : std_logic;
    wr_done          : std_logic;
    rd_done          : std_logic;
    wr_error         : std_logic;
    excl_error       : std_logic;
    rd_error         : std_logic;
    rdata_valid_comb : std_logic;
    rd_done_comb     : std_logic;
    rd_error_comb    : std_logic;
  end record;

  type bm_fre_in_type is record
    bmrd_req     : std_logic;
    bmwr_req     : std_logic;
    fe_ren       : std_logic;
    fe_rvalid_rc : std_logic;
    fe_rlast     : std_logic;
    wc_done      : std_logic;
    excl_en      : std_logic;
    excl_nowrite : std_logic;
    rd_error     : std_logic;
  end record;

  type bm_fre_out_type is record
    bmrd_req_granted : std_logic;
    bmrd_valid       : std_logic;
    bmrd_done        : std_logic;
    bmrd_error       : std_logic;
    bmwr_req_granted : std_logic;
    bmwr_full        : std_logic;
    fe_rvalid_wc     : std_logic;
    fe_fwrite        : std_logic;
    wc_start         : std_logic;
    rc_start         : std_logic;
    lock             : std_logic;
    excl_done        : std_logic;
    lock_remove      : std_logic;
  end record;


  type fifo_wc_in_type is record
    -- me <-> be
    be_ren        : std_logic;
    be_rsize      : std_logic_vector(2 downto 0);
    addr          : std_logic_vector(4 downto 0);
    be_no_align   : std_logic;
    --state machine
    rreset        : std_logic;
    -- fifo <-> fe
    fe_rvalid     : std_logic;
    fe_fwrite     : std_logic;          --(grant and breq)
  end record;

  type fifo_wc_out_type is record
    fe_ren        : std_logic;
    fifo_valid_wc : std_logic_vector(1 downto 0);
  end record;

  type fifo_rc_in_type is record
    -- me <-> be
    be_rsize        : std_logic_vector(2 downto 0);
    be_no_align     : std_logic;
    be_wvalid       : std_logic;
    be_wvalid_comb  : std_logic;
    be_rlast        : std_logic;
    addr            : std_logic_vector(4 downto 0);
    error           : std_logic;
    error_comb      : std_logic;
    --state machine
    rreset          : std_logic;
    --
    unaligned_burst : std_logic;
  end record;

  type fifo_rc_out_type is record
    -- fifo <-> fe
    fe_rvalid : std_logic;
    fe_rlast  : std_logic;
    error     : std_logic;
  end record;

  type bm_me_wc_in_type is record
    start      : std_logic;
    --  start_address : std_logic_vector(31 downto 0);
    fifo_valid : std_logic_vector(1 downto 0);
    grant      : std_logic;
    burst_done : std_logic;
    error      : std_logic;
    excl_error : std_logic;
  end record;

  type bm_me_wc_out_type is record
    request       : std_logic;
    burst_last    : std_logic;
    rsize         : std_logic_vector(2 downto 0);
    addr          : std_logic_vector(4 downto 0);
    active        : std_logic;
    fe_burst_done : std_logic;
    error         : std_logic;
    be_no_align   : std_logic;
    excl_error    : std_logic;
  end record;


  type bm_me_rc_in_type is record
    start           : std_logic;
    lock            : std_logic;
    grant           : std_logic;
    burst_done      : std_logic;
    burst_done_comb : std_logic;
  end record;

  type bm_me_rc_out_type is record
    be_rlast        : std_logic;
    request         : std_logic;
    burst_last      : std_logic;
    rsize           : std_logic_vector(2 downto 0);
    addr            : std_logic_vector(4 downto 0);
    active          : std_logic;
    fe_burst_done   : std_logic;
    lock            : std_logic;
    be_no_align     : std_logic;
    unaligned_burst : std_logic;
  end record;


  type bmahb_dma_in_type is record
    start    : std_ulogic;
    burst    : std_ulogic;
    write    : std_ulogic;
    lock_req : std_ulogic;
    busy     : std_ulogic;
    irq      : std_ulogic;
    size     : std_logic_vector(2 downto 0);
  end record;

  type bmahb_dma_out_type is record
    start  : std_ulogic;
    active : std_ulogic;
    grant  : std_ulogic;
    ready  : std_ulogic;
    retry  : std_ulogic;
    mexc   : std_ulogic;
    haddr  : std_logic_vector(9 downto 0);
  end record;

  component bm_fr_end
    generic (
      async_reset  : boolean;
      bm_dw        : integer;
      be_dw        : integer;
      max_size     : integer;
      excl_enabled : boolean;
      addr_width   : integer := 32);
    port(
      clk       : in  std_logic;
      rstn      : in  std_logic;
      endian    : in  std_logic := '0';  --0->BE, 1->LE
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
  end component bm_fr_end;

  component fifo_control_wc
    generic (
      async_reset             : boolean;
      be_dw                   : integer :=32);
    port (
      clk         : in  std_logic;
      rstn        : in  std_logic;
      endian      : in  std_logic := '0';   --0->BE, 1->LE
      fifo_wc_in  : in  fifo_wc_in_type;
      fifo_wc_out : out fifo_wc_out_type;
      fe_wdata    : in  std_logic_vector(be_dw-1 downto 0);
      be_rdata    : out std_logic_vector(be_dw-1 downto 0)
      );
  end component fifo_control_wc;

  component fifo_control_rc is
    generic (
      async_reset      : boolean;
      be_dw            : integer := 32;
      be_rd_pipe       : integer := 1;
      unalign_load_opt : integer := 0
      );
    port (
      clk           : in  std_logic;
      rstn          : in  std_logic;
      endian        : in  std_logic := '0';  --0->BE, 1->LE
      fifo_rc_in    : in  fifo_rc_in_type;
      fifo_rc_out   : out fifo_rc_out_type;
      be_wdata      : in  std_logic_vector(be_dw-1 downto 0);
      be_wdata_comb : in  std_logic_vector(be_dw-1 downto 0);
      fe_rdata      : out std_logic_vector(be_dw-1 downto 0)
      );
  end component fifo_control_rc;

  component bm_me_wc
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
  end component bm_me_wc;

  component bm_me_rc is
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
  end component bm_me_rc;

  component ahb_be
    generic (
      async_reset           : boolean;
      hindex                : integer := 0;
      venid                 : integer := 0;
      devid                 : integer := 0;
      version               : integer := 0;
      max_burst_length_ptwo : integer;
      be_dw                 : integer;
      be_dw_int             : integer;
      addr_width            : integer := 32);
    port (
      clk          : in  std_logic;
      rstn         : in  std_logic;
      endian       : in  std_logic := '0';   --0->BE, 1->LE
      ahb_be_in    : in  ahb_be_in_type;
      ahb_be_out   : out ahb_be_out_type;
      rd_addr      : in  std_logic_vector(addr_width-1 downto 0);
      wr_addr      : in  std_logic_vector(addr_width-1 downto 0);
      wr_len       : in  std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0);
      rd_len       : in  std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0);
      wr_data      : in  std_logic_vector(be_dw_int-1 downto 0);
      rd_data      : out std_logic_vector(be_dw_int-1 downto 0);
      rd_data_comb : out std_logic_vector(be_dw_int-1 downto 0);
      ahbmi        : in  ahb_bmst_in_type;
      ahbmo        : out ahb_bmst_out_type;
      hrdata       : in  std_logic_vector(be_dw-1 downto 0);
      hwdata       : out std_logic_vector(be_dw-1 downto 0)
      );
  end component ahb_be;

  component axi4_be
    generic (
      async_reset             : boolean;
      axi_bm_id_width         : integer;
      addr_width              : integer := 32;
      max_burst_length_ptwo   : integer;
      be_dw                   : integer);
    port (
      clk             : in  std_logic;
      rstn            : in  std_logic;
      endian          : in  std_logic := '0';   --0->BE, 1->LE
      ahb_be_in       : in  ahb_be_in_type;
      ahb_be_out      : out ahb_be_out_type;
      rd_addr         : in  std_logic_vector(addr_width-1 downto 0);
      wr_addr         : in  std_logic_vector(addr_width-1 downto 0);
      wr_len          : in  std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0);
      rd_len          : in  std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0);
      wr_data         : in  std_logic_vector(be_dw-1 downto 0);
      rd_data         : out std_logic_vector(be_dw-1 downto 0);
      rd_data_comb    : out std_logic_vector(be_dw-1 downto 0);
      --AXI4 signals--
      --write address channel
      axi_aw_id       : out std_logic_vector(axi_bm_id_width-1 downto 0);
      axi_aw_addr     : out std_logic_vector(addr_width-1 downto 0);
      axi_aw_len      : out std_logic_vector(7 downto 0);
      axi_aw_size     : out std_logic_vector(2 downto 0);
      axi_aw_burst    : out std_logic_vector(1 downto 0);
      axi_aw_lock     : out std_logic;
      axi_aw_cache    : out std_logic_vector(3 downto 0);
      axi_aw_prot     : out std_logic_vector(2 downto 0);
      axi_aw_valid    : out std_logic;
      axi_aw_qos      : out std_logic_vector(3 downto 0);
      axi_aw_ready    : in  std_logic;
      --write data channel
      axi_w_data      : out std_logic_vector(be_dw-1 downto 0);
      axi_w_strb      : out std_logic_vector((be_dw/8)-1 downto 0);
      axi_w_last      : out std_logic;
      axi_w_valid     : out std_logic;
      axi_w_ready     : in  std_logic;
      --write response channel
      axi_b_ready     : out std_logic;
      axi_b_id        : in  std_logic_vector(axi_bm_id_width-1 downto 0);
      axi_b_resp      : in  std_logic_vector(1 downto 0);
      axi_b_valid     : in  std_logic;
      --read address channel
      axi_ar_id       : out std_logic_vector(axi_bm_id_width-1 downto 0);
      axi_ar_addr     : out std_logic_vector(addr_width-1 downto 0);
      axi_ar_len      : out std_logic_vector(7 downto 0);
      axi_ar_size     : out std_logic_vector(2 downto 0);
      axi_ar_burst    : out std_logic_vector(1 downto 0);
      axi_ar_lock     : out std_logic;
      axi_ar_cache    : out std_logic_vector(3 downto 0);
      axi_ar_prot     : out std_logic_vector(2 downto 0);
      axi_ar_valid    : out std_logic;
      axi_ar_qos      : out std_logic_vector(3 downto 0);
      axi_ar_ready    : in  std_logic;
      --read data channel
      axi_r_ready     : out std_logic;
      axi_r_id        : in  std_logic_vector(axi_bm_id_width-1 downto 0);
      axi_r_data      : in  std_logic_vector(be_dw-1 downto 0);
      axi_r_resp      : in  std_logic_vector(1 downto 0);
      axi_r_last      : in  std_logic;
      axi_r_valid     : in  std_logic
      );
  end component axi4_be;

  component generic_bm_ahb
    generic(
      async_reset      : boolean                  := false;
      bm_dw            : integer range 32 to 128  := 128;  --bus master data width
      be_dw            : integer range 32 to 256  := 32;  --back-end data width
      be_rd_pipe       : integer range 0 to 1     := 1;
      unalign_load_opt : integer range 0 to 1     := 0;
      addr_width       : integer                  := 32;
      max_size         : integer range 32 to 1024 := 256;
      --back-end burst length
      --it does not make sense to go above 1K boundary since
      --AHB transaction must restart
      max_burst_length : integer range 2 to 256   := 256;
      --determines the address boundary in which a batch of burst must finish
      --in terms of bytes
      burst_chop_mask  : integer range 8 to 1024  := 1024;
      bm_info_print    : integer                  := 0;
      excl_enabled     : boolean                  := true;
      hindex           : integer                  := 0;
      venid            : integer                  := 0;
      devid            : integer                  := 0;
      version          : integer                  := 0);
    port (
      clk              : in  std_logic;
      rstn             : in  std_logic;
      --AHB domain signals
      ahbmi            : in  ahb_bmst_in_type;
      ahbmo            : out ahb_bmst_out_type;
      hrdata           : in  std_logic_vector(be_dw-1 downto 0);
      hwdata           : out std_logic_vector(be_dw-1 downto 0);
      --Bus master domain signals
      --Read Channel
      bmrd_addr        : in  std_logic_vector(addr_width-1 downto 0);
      bmrd_size        : in  std_logic_vector(log_2(max_size)-1 downto 0);
      bmrd_req         : in  std_logic;
      bmrd_req_granted : out std_logic;
      bmrd_data        : out std_logic_vector(bm_dw-1 downto 0);
      bmrd_valid       : out std_logic;
      bmrd_done        : out std_logic;
      bmrd_error       : out std_logic;
      --Write Channel
      bmwr_addr        : in  std_logic_vector(addr_width-1 downto 0);
      bmwr_size        : in  std_logic_vector(log_2(max_size)-1 downto 0);
      bmwr_req         : in  std_logic;
      bmwr_req_granted : out std_logic;
      bmwr_data        : in  std_logic_vector(bm_dw-1 downto 0);
      bmwr_full        : out std_logic;
      bmwr_done        : out std_logic;
      bmwr_error       : out std_logic;
      --Endianess Output
      endian_out       : out std_logic;   --0->BE, 1->LE    
      --Exclusive access
      excl_en          : in  std_logic;
      excl_nowrite     : in  std_logic;
      excl_done        : out std_logic;
      excl_err         : out std_logic_vector(1 downto 0)
      );
  end component generic_bm_ahb;


  component generic_bm_axi
    generic(
      async_reset             : boolean                  := false;
      bm_dw                   : integer range 32 to 128  := 128;  --bus master data width
      be_dw                   : integer range 32 to 128  := 32;  --back-end data width
      be_rd_pipe              : integer range 0 to 1     := 1;
      unalign_load_opt        : integer range 0 to 1     := 0;
      max_size                : integer range 32 to 4096 := 256;
      --back-end burst length
      max_burst_length        : integer range 2 to 256   := 256;
      --determines the address boundary in which a batch of burst must finish
      --in terms of bytes
      burst_chop_mask         : integer range 8 to 4096  := 4096;
      bm_info_print           : integer                  := 0;
      axi_bm_id_width         : integer                  := 5;
      lendian_en              : integer                  := 0;
      addr_width              : integer range 32 to 64   := 32);
    port (
      clk              : in  std_logic;
      rstn             : in  std_logic;
      --AXI4 signals--
      --write address channel
      axi_aw_id        : out std_logic_vector(axi_bm_id_width-1 downto 0);
      axi_aw_addr      : out std_logic_vector(addr_width-1 downto 0);
      axi_aw_len       : out std_logic_vector(7 downto 0);
      axi_aw_size      : out std_logic_vector(2 downto 0);
      axi_aw_burst     : out std_logic_vector(1 downto 0);
      axi_aw_lock      : out std_logic;
      axi_aw_cache     : out std_logic_vector(3 downto 0);
      axi_aw_prot      : out std_logic_vector(2 downto 0);
      axi_aw_valid     : out std_logic;
      axi_aw_qos       : out std_logic_vector(3 downto 0);
      axi_aw_ready     : in  std_logic;
      --write data channel 
      axi_w_data       : out std_logic_vector(be_dw-1 downto 0);
      axi_w_strb       : out std_logic_vector((be_dw/8)-1 downto 0);
      axi_w_last       : out std_logic;
      axi_w_valid      : out std_logic;
      axi_w_ready      : in  std_logic;
      --write response channel
      axi_b_ready      : out std_logic;
      axi_b_id         : in  std_logic_vector(axi_bm_id_width-1 downto 0);
      axi_b_resp       : in  std_logic_vector(1 downto 0);
      axi_b_valid      : in  std_logic;
      --read address channel
      axi_ar_id        : out std_logic_vector(axi_bm_id_width-1 downto 0);
      axi_ar_addr      : out std_logic_vector(addr_width-1 downto 0);
      axi_ar_len       : out std_logic_vector(7 downto 0);
      axi_ar_size      : out std_logic_vector(2 downto 0);
      axi_ar_burst     : out std_logic_vector(1 downto 0);
      axi_ar_lock      : out std_logic;
      axi_ar_cache     : out std_logic_vector(3 downto 0);
      axi_ar_prot      : out std_logic_vector(2 downto 0);
      axi_ar_valid     : out std_logic;
      axi_ar_qos       : out std_logic_vector(3 downto 0);
      axi_ar_ready     : in  std_logic;
      --read data channel
      axi_r_ready      : out std_logic;
      axi_r_id         : in  std_logic_vector(axi_bm_id_width-1 downto 0);
      axi_r_data       : in  std_logic_vector(be_dw-1 downto 0);
      axi_r_resp       : in  std_logic_vector(1 downto 0);
      axi_r_last       : in  std_logic;
      axi_r_valid      : in  std_logic;
      --Bus master domain signals
      --Read Channel
      bmrd_addr        : in  std_logic_vector(31 downto 0);
      bmrd_size        : in  std_logic_vector(log_2(max_size)-1 downto 0);
      bmrd_req         : in  std_logic;
      bmrd_req_granted : out std_logic;
      bmrd_data        : out std_logic_vector(bm_dw-1 downto 0);
      bmrd_valid       : out std_logic;
      bmrd_done        : out std_logic;
      bmrd_error       : out std_logic;
      --Write Channel
      bmwr_addr        : in  std_logic_vector(31 downto 0);
      bmwr_size        : in  std_logic_vector(log_2(max_size)-1 downto 0);
      bmwr_req         : in  std_logic;
      bmwr_req_granted : out std_logic;
      bmwr_data        : in  std_logic_vector(bm_dw-1 downto 0);
      bmwr_full        : out std_logic;
      bmwr_done        : out std_logic;
      bmwr_error       : out std_logic;
      --Endianess Output
      endian_out       : out std_logic   --0->BE, 1->LE
      --Exclusive access
      );
  end component generic_bm_axi;

  component bmahbmst
    generic (
      async_reset : boolean;
      hindex      : integer := 0;
      hirq        : integer := 0;
      venid       : integer := 0;
      devid       : integer := 0;
      version     : integer := 0;
      chprot      : integer := 3;
      incaddr     : integer := 0;
      be_dw       : integer := 32;
      be_dw_int   : integer := 32;
      addr_width  : integer := 32);
    port (
      rst      : in  std_ulogic;
      clk      : in  std_ulogic;
      endian   : in  std_ulogic := '0';  --0->BE, 1->LE
      dmai     : in  bmahb_dma_in_type;
      dmao     : out bmahb_dma_out_type;
      dma_addr : in  std_logic_vector(addr_width-1 downto 0);
      wdata    : in  std_logic_vector(be_dw_int-1 downto 0);
      rdata    : out std_logic_vector(be_dw_int-1 downto 0);
      ahbi     : in  ahb_bmst_in_type;
      ahbo     : out ahb_bmst_out_type;
      hrdata   : in  std_logic_vector(be_dw-1 downto 0);
      hwdata   : out std_logic_vector(be_dw-1 downto 0)
      );
  end component bmahbmst;


  function endianess (data_in : in std_logic_vector)
    return std_logic_vector;

  function one_detect(data_in : in std_logic_vector)
    return std_logic;

  function size_translate(data_width : in integer range 0 to 128)
    return std_logic_vector;

  function size_detect_begin(data_in : in std_logic_vector(6 downto 0))
    return std_logic_vector;

  function size_detect_end(data_in : in std_logic_vector(7 downto 0); size_left : in unsigned)
    return std_logic_vector;

  function inc_v(data_in : in std_logic_vector(2 downto 0))
    return integer;

  function byte_swap (data_in : std_logic_vector)
    return std_logic_vector;

  function power_of_two(number : integer range 0 to 1048576)
    return integer;

  function chop_mask_sel(chop_mask : integer; burst_length : integer; be_dw : integer)
    return integer;

  function calc_chop_index(chop_mask : integer; maxsize : integer)
    return integer;

  function write_byte_align (
    data_in : std_logic_vector; size : std_logic_vector(2 downto 0); width : integer)
    return std_logic_vector;

  function load_byte_align (
    data_in : std_logic_vector; size : std_logic_vector(2 downto 0); addr : std_logic_vector(4 downto 0);
    width   : integer) return std_logic_vector;

  function max_burst_length_cor(max_burst_length : integer; max_size : integer; be_dw : integer)
    return integer;

  function back_end_width(bm_dw : integer; be_dw: integer)
    return integer;
  
end;

package body generic_bm_pkg is



  --function to map big endian correctly to the back-end
  function endianess (
    data_in : in std_logic_vector
    ) return std_logic_vector is
    variable data_out : std_logic_vector(data_in'range);
  begin
    for i in 0 to (data_in'left+1)/8 loop
      data_out(((i+1)*8)-1 downto i*8) := data_in(data_in'left-(i*8) downto data_in'left+1-(i+1)*8);
    end loop;
    return data_out;

  end endianess;

  --returns logic '1' if the input vector contains
  --logic '1'
  function one_detect(
    data_in : in std_logic_vector
    ) return std_logic is
    variable one : std_logic;
  begin
    one := '0';
    for i in 0 to data_in'left loop
      if data_in(i) = '1' then
        one := '1';
      end if;
    end loop;
    return one;
  end one_detect;

  --integer to SIZE (std_logic_vector) translation
  --works both for AHB and AXI
  function size_translate(
    data_width : in integer range 0 to 128
    ) return std_logic_vector is
    variable size : std_logic_vector(2 downto 0);
  begin

    size := "000";
    if data_width = 2 then
      size := "001";
    end if;
    if data_width = 4 then
      size := "010";
    end if;
    if data_width = 8 then
      size := "011";
    end if;
    if data_width = 16 then
      size := "100";
    end if;
    if data_width = 32 then
      size := "101";
    end if;
    if data_width = 64 then
      size := "110";
    end if;
    if data_width = 128 then
      size := "111";
    end if;

    return size;

  end size_translate;

  --detects the first '1' from the LSB
  --check bm_me_rc.vhd and bm_me_wc.vhd for more detail
  function size_detect_begin(
    data_in : in std_logic_vector(6 downto 0)
    ) return std_logic_vector is
    variable size : std_logic_vector(2 downto 0);
  begin
    size := "000";

    if data_in(0) = '1' then
      size := "000";                    --1 byte
    elsif data_in(1) = '1' then
      size := "001";                    --2 bytes
    elsif data_in(2) = '1' then
      size := "010";                    --4 bytes
    elsif data_in(3) = '1' then
      size := "011";                    --8 bytes
    elsif data_in(4) = '1' then
      size := "100";                    --16 bytes
    elsif data_in(5) = '1' then
      size := "101";                    --32 bytes
    elsif data_in(6) = '1' then
      size := "110";                    --64 bytes
    end if;

    return size;
  end size_detect_begin;

  --check bm_me_rc.vhd and bm_me_wc.vhd for more detail
  function size_detect_end(
    data_in   : in std_logic_vector(7 downto 0);
    size_left : in unsigned
    ) return std_logic_vector is
    variable size : std_logic_vector(2 downto 0);
  begin

    size := "000";
    if size_left >= 2 then
      size := "001";
    end if;
    if size_left >= 4 then
      size := "010";
    end if;
    if size_left >= 8 then
      size := "011";
    end if;
    if size_left >= 16 then
      size := "100";
    end if;
    if size_left >= 32 then
      size := "101";
    end if;
    if size_left >= 64 then
      size := "110";
    end if;

    --1 byte selection is not used in the
    --if cases because if nothing is selected
    --the default is 1 byte
    if data_in(0) = '1' then
      size := "000";
    elsif data_in(1) = '1' then
      if size_left >= 2 then
        size := "001";
      end if;
    elsif data_in(2) = '1' then
      if size_left >= 4 then
        size := "010";
      elsif size_left >= 2 then
        size := "001";
      end if;
    elsif data_in(3) = '1' then
      if size_left >= 8 then
        size := "011";
      elsif size_left >= 4 then
        size := "010";
      elsif size_left >= 2 then
        size := "001";
      end if;
    elsif data_in(4) = '1' then
      if size_left >= 16 then
        size := "100";
      elsif size_left >= 8 then
        size := "011";
      elsif size_left >= 4 then
        size := "010";
      elsif size_left >= 2 then
        size := "001";
      end if;
    elsif data_in(5) = '1' then
      if size_left >= 32 then
        size := "101";
      elsif size_left >= 16 then
        size := "100";
      elsif size_left >= 8 then
        size := "011";
      elsif size_left >= 4 then
        size := "010";
      elsif size_left >= 2 then
        size := "001";
      end if;
    elsif data_in(6) = '1' or data_in(7) = '1' then
      if size_left >= 64 then
        size := "110";
      elsif size_left >= 32 then
        size := "101";
      elsif size_left >= 16 then
        size := "100";
      elsif size_left >= 8 then
        size := "011";
      elsif size_left >= 4 then
        size := "010";
      elsif size_left >= 2 then
        size := "001";
      end if;
    end if;

    return size;

  end size_detect_end;

  --takes size (std_logic_vector) as input
  --and returns it as integer
  --works for both AHB and AXI
  function inc_v(
    data_in : in std_logic_vector(2 downto 0)
    ) return integer is
    variable size : integer;
  begin

    case data_in is
      when "000" =>
        size := 1;
      when "001" =>
        size := 2;
      when "010" =>
        size := 4;
      when "011" =>
        size := 8;
      when "100" =>
        size := 16;
      when "101" =>
        size := 32;
      when "110" =>
        size := 64;
      when "111" =>
        size := 128;

      when others => null;
    end case;

    return size;
  end inc_v;

  --copies a byte to all byte positions in a word
  function byte_duplicate(
    data_in : std_logic_vector(7 downto 0);
    width   : integer)
    return std_logic_vector is
    variable data : std_logic_vector(width-1 downto 0);
  begin
    for i in 0 to (width/8)-1 loop
      data((i+1)*8-1 downto i*8) := data_in;
    end loop;  -- i
    return data;
  end byte_duplicate;

  --copies 2bytes to all byte positions in a word
  function hword_duplicate(
    data_in : std_logic_vector(15 downto 0);
    width   : integer)
    return std_logic_vector is
    variable data : std_logic_vector(width-1 downto 0);
  begin
    for i in 0 to (width/16)-1 loop
      data((i+1)*16-1 downto i*16) := data_in;
    end loop;  -- i
    return data;
  end hword_duplicate;

  --copies 4bytes to all byte positions in a word
  function word_duplicate(
    data_in : std_logic_vector(31 downto 0);
    width   : integer)
    return std_logic_vector is
    variable data : std_logic_vector(width-1 downto 0);
  begin
    for i in 0 to (width/32)-1 loop
      data((i+1)*32-1 downto i*32) := data_in;
    end loop;  -- i
    return data;
  end word_duplicate;

  --copies 8bytes to all byte positions in a word
  function dword_duplicate(
    data_in : std_logic_vector(63 downto 0);
    width   : integer)
    return std_logic_vector is
    variable data : std_logic_vector(width-1 downto 0);
  begin
    for i in 0 to (width/64)-1 loop
      data((i+1)*64-1 downto i*64) := data_in;
    end loop;  -- i
    return data;
  end dword_duplicate;

  --copies 16bytes to all byte positions in a word
  function qword_duplicate(
    data_in : std_logic_vector(127 downto 0);
    width   : integer)
    return std_logic_vector is
    variable data : std_logic_vector(width-1 downto 0);
  begin
    for i in 0 to (width/128)-1 loop
      data((i+1)*128-1 downto i*128) := data_in;
    end loop;  -- i
    return data;
  end qword_duplicate;

  --takes a data word and size and automatically
  --replicates the data word with the previously
  --defined functions
  function write_byte_align (
    data_in : std_logic_vector;
    size    : std_logic_vector(2 downto 0);
    width   : integer)
    return std_logic_vector is
    variable data  : std_logic_vector(data_in'range);
    variable shift : integer range 0 to width-1;
  begin  

    data := data_in;
    if inc_v(size) /= width/8 then

      case size is
        when "000" =>
          data := byte_duplicate(data(7 downto 0), width);
        when "001" =>
          data := hword_duplicate(data(15 downto 0), width);
        when "010" =>
          if width > 32 then
            data := word_duplicate(data(31 downto 0), width);
          end if;
        when "011" =>
          if width > 64 then
            data := dword_duplicate(data(63 downto 0), width);
          end if;
        when "100" =>
          if width > 128 then
            data := qword_duplicate(data(127 downto 0), width);
          end if;
        when others => null;
      end case;
    end if;

    return data;
  end write_byte_align;

  --puts the data in the correct position during reads
  --with respect to the address and size
  function load_byte_align (
    data_in : std_logic_vector;
    size    : std_logic_vector(2 downto 0);
    addr    : std_logic_vector(4 downto 0);
    width   : integer)
    return std_logic_vector is
    variable data  : std_logic_vector(data_in'range);
    variable shift : integer range 0 to width/8;
  begin  -- ahbdrivedata

    shift := to_integer(unsigned(addr(log_2(width/8)-1 downto 0)));
    data  := data_in;
    if inc_v(size) /= width/8 then
      for i in 0 to (width/8)-1 loop
        for j in i to (width/8)-1 loop
          if (j-i) = shift then
            data((i+1)*8-1 downto i*8) := data_in((j+1)*8-1 downto j*8);
          end if;
        end loop;  -- j
      end loop;  -- i
    end if;

    return data;

  end load_byte_align;

  --swap the bytes in a word
  function byte_swap (
    data_in : std_logic_vector)
    return std_logic_vector is
    variable data : std_logic_vector(data_in'range);
  begin
    for i in 0 to (data_in'length/8)-1 loop
      data((i+1)*8-1 downto i*8) := data_in(data_in'left-(i*8) downto data_in'length-((i+1)*8));
    end loop;  -- i
    return data;
  end byte_swap;


  --return the nearest power of two (max 1048576)
  function power_of_two(
    number : integer range 0 to 1048576)
    return integer is
    variable ret : integer;
  begin

    ret := 1;

    for i in 20 downto 0 loop
      if number >= 2**i then
        ret := 2**i;
        exit;
      end if;
    end loop;

    return ret;
    
  end power_of_two;

  --log2 function (max input 1048576)
  function log_2(
    number : integer range 0 to 1048576)
    return integer is
    variable ret : integer;
  begin
    ret := 0;
    for i in 20 downto 0 loop
      if number >= 2**i then
        ret := i;
        exit;
      end if;
    end loop;  -- i
    return ret;
    
  end log_2;

  function chop_mask_sel(
    chop_mask    : integer;
    burst_length : integer;
    be_dw        : integer)
    return integer is
  begin

    if chop_mask < (burst_length)*(be_dw/8) then
      return burst_length*(be_dw/8);
    else
      return chop_mask;
    end if;

  end chop_mask_sel;

  function calc_chop_index(
    chop_mask : integer;
    maxsize   : integer)
    return integer is
  begin

    if maxsize >= chop_mask then
      return log_2(chop_mask)-1;
    else
      return log_2(maxsize);
    end if;

  end calc_chop_index;

  --functions that limits the
  --max_burst_length parameter with
  --respect to the be_dw and max_size
  --in case it sets wrongly
  function max_burst_length_cor(
    max_burst_length : integer;
    max_size         : integer;
    be_dw            : integer)
    return integer is
  begin

    if max_size > 1024 then
      if max_burst_length > 256/(be_dw/8) then
        return 256/(be_dw/8);
      else
        return max_burst_length;
      end if;
    else
      if max_burst_length > max_size/(be_dw/8) then
        return max_size/(be_dw/8);
      else
        return max_burst_length;
      end if;
    end if;

  end max_burst_length_cor;

  function back_end_width(
    bm_dw : integer;
    be_dw : integer)
    return integer is
  begin

    if be_dw > bm_dw then
      return bm_dw;
    else
      return be_dw;
    end if;

  end back_end_width;

  

end generic_bm_pkg;
