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
-- Entity:      generic_bm_axi
-- File:        generic_bm_axi.vhd
-- Company:     Cobham Gaisler AB
-- Description: Generic Bus Master with AXI interface
------------------------------------------------------------------------------ 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.generic_bm_pkg.all;


entity generic_bm_axi is
  generic(
    async_reset             : boolean                  := false;
    bm_dw                   : integer range 32 to 128  := 128;  --bus master data width
    be_dw                   : integer range 32 to 128  := 32;  --back-end data width
    be_rd_pipe              : integer range 0 to 1     := 1;
    unalign_load_opt        : integer range 0 to 1     := 0;
    addr_width              : integer                  := 32;
    max_size                : integer range 32 to 4096 := 256;
    --back-end burst length
    max_burst_length        : integer range 2 to 256   := 256;
    --determines the address boundary in which a batch of burst must finish
    --in terms of bytes
    burst_chop_mask         : integer range 8 to 4096  := 4096;
    bm_info_print           : integer                  := 0;
    lendian_en              : integer                  := 0;
    axi_bm_id_width         : integer                  := 5);
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
end generic_bm_axi;



architecture rtl of generic_bm_axi is
  
  constant excl_enabled          : boolean := false;
  constant max_burst_length_ptwo : integer := max_burst_length_cor(power_of_two(max_burst_length), power_of_two(max_size), be_dw);
  constant burst_chop_mask_ptwo  : integer := chop_mask_sel(power_of_two(burst_chop_mask), max_burst_length_ptwo, be_dw);

  signal fe_wdata     : std_logic_vector(be_dw-1 downto 0);
  signal fe_rdata     : std_logic_vector(be_dw-1 downto 0);

  signal wr_len       : std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0);
  signal rd_len       : std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0);
  signal wr_data      : std_logic_vector(be_dw-1 downto 0);
  signal rd_data      : std_logic_vector(be_dw-1 downto 0);
  signal rd_data_comb : std_logic_vector(be_dw-1 downto 0);

  signal bm_me_rc_out_burst_addr : std_logic_vector(addr_width-1 downto 0);
  signal bm_me_wc_out_burst_addr : std_logic_vector(addr_width-1 downto 0);
  signal fre_out_excl_addr       : std_logic_vector(addr_width-1 downto 0);

  signal bmfre_in     : bm_fre_in_type;
  signal bmfre_out    : bm_fre_out_type;
  signal fifo_wc_in   : fifo_wc_in_type;
  signal fifo_wc_out  : fifo_wc_out_type;
  signal fifo_rc_in   : fifo_rc_in_type;
  signal fifo_rc_out  : fifo_rc_out_type;
  signal bm_me_wc_in  : bm_me_wc_in_type;
  signal bm_me_wc_out : bm_me_wc_out_type;
  signal bm_me_rc_in  : bm_me_rc_in_type;
  signal bm_me_rc_out : bm_me_rc_out_type;
  signal ahb_be_in    : ahb_be_in_type;
  signal ahb_be_out   : ahb_be_out_type;

  signal excl_size : std_logic_vector(log_2(max_size)-1 downto 0);

  signal endian : std_logic;

  signal excl_en      : std_logic;
  signal excl_nowrite : std_logic;
  signal excl_done    : std_logic;
  signal excl_err     : std_logic_vector(1 downto 0);


begin

  excl_en      <= '0';
  excl_nowrite <= '0';

  endian <= '0' when lendian_en = 0 else '1';

  -- pragma translate_off
  DW_check : if be_dw > bm_dw generate
    assert false report "Error: back end data-width can not be wider than bus master data width" severity failure;
  end generate DW_check;

  MS_check : if max_burst_length_ptwo * (be_dw/8) > max_size generate
    assert false report "Error: max_burst_length can not exceed max_size in terms of bytes" severity failure;
  end generate MS_check;

  diag : process
  begin
    wait for 1 ns;
    if bm_info_print /= 0 then
      report "Bus master id: "&integer'image(bm_info_print)&"; front-end bus-width: "&integer'image(bm_dw)&"; back-end bus-width: "&integer'image(be_dw)&"; max burst length (BYTES): " & integer'image(max_burst_length_ptwo * (be_dw/8))&"; burst chop mask (BYTES): "&integer'image(burst_chop_mask_ptwo);
    end if;
    wait;
  end process;
  -- pragma translate_on

  bm_fr_ctrl : bm_fr_end
    generic map(
      async_reset  => async_reset,
      bm_dw        => bm_dw,
      be_dw        => be_dw,
      max_size     => max_size,
      excl_enabled => excl_enabled,
      addr_width   => addr_width)
    port map(
      clk       => clk,
      rstn      => rstn,
      endian    => endian,
      bmfre_in  => bmfre_in,
      bmfre_out => bmfre_out,
      bmrd_size => bmrd_size,
      bmrd_data => bmrd_data,
      bmwr_size => bmwr_size,
      bmwr_data => bmwr_data,
      bmrd_addr => bmrd_addr,
      excl_size => excl_size,
      excl_addr => fre_out_excl_addr,
      fe_wdata  => fe_wdata,
      fe_rdata  => fe_rdata
      );

  fifo_wc : fifo_control_wc
    generic map (
      async_reset             => async_reset,
      be_dw                   => be_dw)
    port map (
      clk         => clk,
      rstn        => rstn,
      endian      => endian,
      fifo_wc_in  => fifo_wc_in,
      fifo_wc_out => fifo_wc_out,
      fe_wdata    => fe_wdata,
      be_rdata    => wr_data);

  fifo_rc : fifo_control_rc
    generic map(
      async_reset      => async_reset,
      be_dw            => be_dw,
      be_rd_pipe       => be_rd_pipe,
      unalign_load_opt => unalign_load_opt)
    port map(
      clk           => clk,
      rstn          => rstn,
      endian        => endian,
      fifo_rc_in    => fifo_rc_in,
      fifo_rc_out   => fifo_rc_out,
      be_wdata      => rd_data,
      be_wdata_comb => rd_data_comb,
      fe_rdata      => fe_rdata
      );

  me_wc : bm_me_wc
    generic map(
      async_reset             => async_reset,
      be_dw                   => be_dw,
      maxsize                 => max_size,
      max_burst_length_ptwo   => max_burst_length_ptwo,
      burst_chop_mask_ptwo    => burst_chop_mask_ptwo,
      addr_width              => addr_width
      )
    port map(
      clk           => clk,
      rstn          => rstn,
      bm_me_wc_in   => bm_me_wc_in,
      bm_me_wc_out  => bm_me_wc_out,
      burst_addr    => bm_me_wc_out_burst_addr,
      start_address => bmwr_addr,
      size          => bmwr_size,
      burst_length  => wr_len
      );

  me_rc : bm_me_rc
    generic map(
      async_reset           => async_reset,
      be_dw                 => be_dw,
      maxsize               => max_size,
      max_burst_length_ptwo => max_burst_length_ptwo,
      burst_chop_mask_ptwo  => burst_chop_mask_ptwo,
      addr_width            => addr_width,
      be_rd_pipe            => be_rd_pipe,
      unalign_load_opt      => unalign_load_opt)
    port map(
      clk           => clk,
      rstn          => rstn,
      bm_me_rc_in   => bm_me_rc_in,
      bm_me_rc_out  => bm_me_rc_out,
      burst_addr    => bm_me_rc_out_burst_addr,
      start_address => bmrd_addr,
      excl_address  => fre_out_excl_addr,
      size          => bmrd_size,
      excl_size     => excl_size,
      burst_length  => rd_len
      );

  back_end : axi4_be
    generic map(
      async_reset           => async_reset,
      axi_bm_id_width       => axi_bm_id_width,
      addr_width            => addr_width,
      max_burst_length_ptwo => max_burst_length_ptwo,
      be_dw                 => be_dw
      )
    port map(
      clk             => clk,
      rstn            => rstn,
      endian          => endian,
      ahb_be_in       => ahb_be_in,
      ahb_be_out      => ahb_be_out,
      rd_addr         => bm_me_rc_out_burst_addr,
      wr_addr         => bm_me_wc_out_burst_addr,
      wr_len          => wr_len,
      rd_len          => rd_len,
      wr_data         => wr_data,
      rd_data         => rd_data,
      rd_data_comb    => rd_data_comb,
      --AXI4 signals--
      --write address channel
      axi_aw_id       => axi_aw_id,
      axi_aw_addr     => axi_aw_addr,
      axi_aw_len      => axi_aw_len,
      axi_aw_size     => axi_aw_size,
      axi_aw_burst    => axi_aw_burst,
      axi_aw_lock     => axi_aw_lock,
      axi_aw_cache    => axi_aw_cache,
      axi_aw_prot     => axi_aw_prot,
      axi_aw_valid    => axi_aw_valid,
      axi_aw_qos      => axi_aw_qos,
      axi_aw_ready    => axi_aw_ready,
      --write data channel     
      axi_w_data      => axi_w_data,
      axi_w_strb      => axi_w_strb,
      axi_w_last      => axi_w_last,
      axi_w_valid     => axi_w_valid,
      axi_w_ready     => axi_w_ready,
      --write response channel
      axi_b_ready     => axi_b_ready,
      axi_b_id        => axi_b_id,
      axi_b_resp      => axi_b_resp,
      axi_b_valid     => axi_b_valid,
      --read address channel
      axi_ar_id       => axi_ar_id,
      axi_ar_addr     => axi_ar_addr,
      axi_ar_len      => axi_ar_len,
      axi_ar_size     => axi_ar_size,
      axi_ar_burst    => axi_ar_burst,
      axi_ar_lock     => axi_ar_lock,
      axi_ar_cache    => axi_ar_cache,
      axi_ar_prot     => axi_ar_prot,
      axi_ar_valid    => axi_ar_valid,
      axi_ar_qos      => axi_ar_qos,
      axi_ar_ready    => axi_ar_ready,
      --read data channel
      axi_r_ready     => axi_r_ready,
      axi_r_id        => axi_r_id,
      axi_r_data      => axi_r_data,
      axi_r_resp      => axi_r_resp,
      axi_r_last      => axi_r_last,
      axi_r_valid     => axi_r_valid
      );

  ahb_be_in.wr_req        <= bm_me_wc_out.request;
  ahb_be_in.rd_req        <= bm_me_rc_out.request;
  ahb_be_in.wr_size       <= bm_me_wc_out.rsize;
  ahb_be_in.rd_size       <= bm_me_rc_out.rsize;
  ahb_be_in.lock          <= bm_me_rc_out.lock;
  ahb_be_in.lock_remove   <= bmfre_out.lock_remove;

  bmfre_in.bmrd_req     <= bmrd_req;
  bmfre_in.bmwr_req     <= bmwr_req;
  bmfre_in.rd_error     <= fifo_rc_out.error;
  bmfre_in.fe_ren       <= fifo_wc_out.fe_ren;
  bmfre_in.fe_rvalid_rc <= fifo_rc_out.fe_rvalid;
  bmfre_in.fe_rlast     <= fifo_rc_out.fe_rlast;
  bmfre_in.wc_done      <= bm_me_wc_out.fe_burst_done;
  bmfre_in.excl_en      <= excl_en;
  bmfre_in.excl_nowrite <= excl_nowrite;

  fifo_wc_in.be_ren        <= ahb_be_out.wdata_ren;
  fifo_wc_in.be_rsize      <= bm_me_wc_out.rsize;
  fifo_wc_in.addr          <= bm_me_wc_out.addr;
  fifo_wc_in.be_no_align   <= bm_me_wc_out.be_no_align;
  fifo_wc_in.rreset        <= bm_me_wc_out.fe_burst_done;
  fifo_wc_in.fe_rvalid     <= bmfre_out.fe_rvalid_wc;
  fifo_wc_in.fe_fwrite     <= bmfre_out.fe_fwrite;

  fifo_rc_in.be_rsize        <= bm_me_rc_out.rsize;
  fifo_rc_in.be_no_align     <= bm_me_rc_out.be_no_align;
  fifo_rc_in.be_wvalid       <= ahb_be_out.rdata_valid;
  fifo_rc_in.be_wvalid_comb  <= ahb_be_out.rdata_valid_comb;
  fifo_rc_in.be_rlast        <= bm_me_rc_out.be_rlast;
  fifo_rc_in.addr            <= bm_me_rc_out.addr;
  fifo_rc_in.rreset          <= fifo_rc_out.fe_rlast;
  fifo_rc_in.error           <= ahb_be_out.rd_error;
  fifo_rc_in.error_comb      <= ahb_be_out.rd_error_comb;
  fifo_rc_in.unaligned_burst <= bm_me_rc_out.unaligned_burst;

  bm_me_wc_in.start      <= bmfre_out.wc_start;
  bm_me_wc_in.fifo_valid <= fifo_wc_out.fifo_valid_wc;
  bm_me_wc_in.grant      <= ahb_be_out.wr_gnt;
  bm_me_wc_in.burst_done <= ahb_be_out.wr_done;
  bm_me_wc_in.error      <= ahb_be_out.wr_error;
  bm_me_wc_in.excl_error <= ahb_be_out.excl_error;

  bm_me_rc_in.start           <= bmfre_out.rc_start;
  bm_me_rc_in.grant           <= ahb_be_out.rd_gnt;
  bm_me_rc_in.burst_done      <= ahb_be_out.rd_done;
  bm_me_rc_in.burst_done_comb <= ahb_be_out.rd_done_comb;
  bm_me_rc_in.lock            <= bmfre_out.lock;

  bmrd_done        <= bmfre_out.bmrd_done;
  bmrd_error       <= bmfre_out.bmrd_error;
  bmrd_valid       <= bmfre_out.bmrd_valid;
  bmrd_req_granted <= bmfre_out.bmrd_req_granted;

  bmwr_done        <= bm_me_wc_out.fe_burst_done;
  bmwr_full        <= bmfre_out.bmwr_full;
  bmwr_req_granted <= bmfre_out.bmwr_req_granted;
  bmwr_error       <= bm_me_wc_out.error;

  endian_out       <= endian;

  excl_done <= bmfre_out.excl_done;
  excl_err  <= "0" & bm_me_wc_out.excl_error;



end rtl;
