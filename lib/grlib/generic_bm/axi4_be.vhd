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
-- Entity:      axi4_be
-- File:        axi4_be.vhd
-- Company:     Cobham Gaisler AB
-- Description: AXI4 back-end controller for bus master
------------------------------------------------------------------------------ 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.generic_bm_pkg.all;


entity axi4_be is
  generic (
    async_reset           : boolean;
    axi_bm_id_width       : integer;
    addr_width            : integer := 32;
    max_burst_length_ptwo : integer;
    be_dw                 : integer);
  port (
    clk          : in  std_logic;
    rstn         : in  std_logic;
    endian       : in  std_logic;       --0-> BE, 1-> LE
    ahb_be_in    : in  ahb_be_in_type;
    ahb_be_out   : out ahb_be_out_type;
    rd_addr      : in  std_logic_vector(addr_width-1 downto 0);
    wr_addr      : in  std_logic_vector(addr_width-1 downto 0);
    wr_len       : in  std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0);
    rd_len       : in  std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0);
    wr_data      : in  std_logic_vector(be_dw-1 downto 0);
    rd_data      : out std_logic_vector(be_dw-1 downto 0);
    rd_data_comb : out std_logic_vector(be_dw-1 downto 0);
    --AXI4 signals--
    --write address channel
    axi_aw_id    : out std_logic_vector(axi_bm_id_width-1 downto 0);
    axi_aw_addr  : out std_logic_vector(addr_width-1 downto 0);
    axi_aw_len   : out std_logic_vector(7 downto 0);
    axi_aw_size  : out std_logic_vector(2 downto 0);
    axi_aw_burst : out std_logic_vector(1 downto 0);
    axi_aw_lock  : out std_logic;
    axi_aw_cache : out std_logic_vector(3 downto 0);
    axi_aw_prot  : out std_logic_vector(2 downto 0);
    axi_aw_valid : out std_logic;
    axi_aw_qos   : out std_logic_vector(3 downto 0);
    axi_aw_ready : in  std_logic;
    --write data channel
    axi_w_data   : out std_logic_vector(be_dw-1 downto 0);
    axi_w_strb   : out std_logic_vector((be_dw/8)-1 downto 0);
    axi_w_last   : out std_logic;
    axi_w_valid  : out std_logic;
    axi_w_ready  : in  std_logic;
    --write response channel
    axi_b_ready  : out std_logic;
    axi_b_id     : in  std_logic_vector(axi_bm_id_width-1 downto 0);
    axi_b_resp   : in  std_logic_vector(1 downto 0);
    axi_b_valid  : in  std_logic;
    --read address channel
    axi_ar_id    : out std_logic_vector(axi_bm_id_width-1 downto 0);
    axi_ar_addr  : out std_logic_vector(addr_width-1 downto 0);
    axi_ar_len   : out std_logic_vector(7 downto 0);
    axi_ar_size  : out std_logic_vector(2 downto 0);
    axi_ar_burst : out std_logic_vector(1 downto 0);
    axi_ar_lock  : out std_logic;
    axi_ar_cache : out std_logic_vector(3 downto 0);
    axi_ar_prot  : out std_logic_vector(2 downto 0);
    axi_ar_valid : out std_logic;
    axi_ar_qos   : out std_logic_vector(3 downto 0);
    axi_ar_ready : in  std_logic;
    --read data channel
    axi_r_ready  : out std_logic;
    axi_r_id     : in  std_logic_vector(axi_bm_id_width-1 downto 0);
    axi_r_data   : in  std_logic_vector(be_dw-1 downto 0);
    axi_r_resp   : in  std_logic_vector(1 downto 0);
    axi_r_last   : in  std_logic;
    axi_r_valid  : in  std_logic
    );
end axi4_be;



architecture rtl of axi4_be is


  type axi_bm_aw_mosi_type is record
    id    : std_logic_vector(axi_bm_id_width-1 downto 0);
    addr  : std_logic_vector(addr_width-1 downto 0);
    len   : std_logic_vector(7 downto 0);
    size  : std_logic_vector(2 downto 0);
    burst : std_logic_vector(1 downto 0);
    lock  : std_logic;
    cache : std_logic_vector(3 downto 0);
    prot  : std_logic_vector(2 downto 0);
    valid : std_logic;
    qos   : std_logic_vector(3 downto 0);
  end record;

  type axi_bm_aw_somi_type is record
    ready : std_logic;
  end record;

  type axi_bm_w_mosi_type is record
    data  : std_logic_vector(be_dw-1 downto 0);
    strb  : std_logic_vector((be_dw/8)-1 downto 0);
    last  : std_logic;
    valid : std_logic;
  end record;

  type axi_bm_w_somi_type is record
    ready : std_logic;
  end record;

  type axi_bm_ar_mosi_type is record
    id    : std_logic_vector(axi_bm_id_width-1 downto 0);
    addr  : std_logic_vector(addr_width-1 downto 0);
    len   : std_logic_vector(7 downto 0);
    size  : std_logic_vector(2 downto 0);
    burst : std_logic_vector(1 downto 0);
    lock  : std_logic;
    cache : std_logic_vector(3 downto 0);
    prot  : std_logic_vector(2 downto 0);
    valid : std_logic;
    qos   : std_logic_vector(3 downto 0);
  end record;

  type axi_bm_ar_somi_type is record
    ready : std_logic;
  end record;

  type axi_bm_r_mosi_type is record
    ready : std_logic;
  end record;

  type axi_bm_r_somi_type is record
    id    : std_logic_vector(axi_bm_id_width-1 downto 0);
    data  : std_logic_vector(be_dw-1 downto 0);
    resp  : std_logic_vector(1 downto 0);
    last  : std_logic;
    valid : std_logic;
  end record;

  type axi_bm_b_mosi_type is record
    ready : std_logic;
  end record;

  type axi_bm_b_somi_type is record
    id    : std_logic_vector(axi_bm_id_width-1 downto 0);
    resp  : std_logic_vector(1 downto 0);
    valid : std_logic;
  end record;

  type axi_bm_mosi_type is record
    aw : axi_bm_aw_mosi_type;
    w  : axi_bm_w_mosi_type;
    b  : axi_bm_b_mosi_type;
    ar : axi_bm_ar_mosi_type;
    r  : axi_bm_r_mosi_type;
  end record;

  type axi_bm_somi_type is record
    aw : axi_bm_aw_somi_type;
    w  : axi_bm_w_somi_type;
    b  : axi_bm_b_somi_type;
    ar : axi_bm_ar_somi_type;
    r  : axi_bm_r_somi_type;
  end record;

  type axi_read_state is (idle, burst);
  type axi_write_state is (idle, burst);

  type reg_type is record
    aximo           : axi_bm_mosi_type;
    rdstate         : axi_read_state;
    wrstate         : axi_write_state;
    rd_gnt          : std_logic;
    wr_gnt          : std_logic;
    rdata_valid     : std_logic;
    rburst_done     : std_logic;
    wburst_done     : std_logic;
    wr_counter      : unsigned(7 downto 0);
    rd_error        : std_logic;
    wr_error        : std_logic;
    excl_error      : std_logic;
    rd_data         : std_logic_vector(be_dw-1 downto 0);
    block_validated : std_logic;
  end record;

  type input_ports is record
    wr_len          : std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0);
    rd_len          : std_logic_vector(log_2(max_burst_length_ptwo)-1 downto 0);
    wr_data         : std_logic_vector(be_dw-1 downto 0);
    rd_addr         : std_logic_vector(addr_width-1 downto 0);
    wr_addr         : std_logic_vector(addr_width-1 downto 0);
    wr_addr_unalign : std_logic_vector(log_2(be_dw/8)-1 downto 0);
  end record;

  constant rac_reset : axi_bm_ar_mosi_type := (id    => (others => '0'), addr => (others => '0'),
                                               len   => (others => '0'), size => (others => '0'),
                                               burst => (others => '0'), lock => '0',
                                               cache => (others => '0'), prot => (others => '0'),
                                               valid => '0', qos => (others => '0'));

  constant rdc_reset : axi_bm_r_mosi_type := (ready => '0');

  constant wac_reset : axi_bm_aw_mosi_type := (id    => (others => '0'), addr => (others => '0'),
                                               len   => (others => '0'), size => (others => '0'),
                                               burst => (others => '0'), lock => '0',
                                               cache => (others => '0'), prot => (others => '0'),
                                               valid => '0', qos => (others => '0'));

  constant wdc_reset : axi_bm_w_mosi_type := (data  => (others => '0'),
                                              strb  => (others => '0'), last => '0',
                                              valid => '0');

  constant wrc_reset : axi_bm_b_mosi_type := (ready => '0');

  constant aximout_res_t : axi_bm_mosi_type := (
    aw => wac_reset,
    w  => wdc_reset,
    b  => wrc_reset,
    ar => rac_reset,
    r  => rdc_reset);

  constant RES_T : reg_type := (
    aximo           => aximout_res_t,
    rdstate         => idle,
    wrstate         => idle,
    rd_gnt          => '0',
    wr_gnt          => '0',
    rdata_valid     => '0',
    rburst_done     => '0',
    wburst_done     => '0',
    wr_counter      => (others => '0'),
    rd_error        => '0',
    wr_error        => '0',
    excl_error      => '0',
    rd_data         => (others => '0'),
    block_validated => '0');


  function wstrobe_generate(
    addr : in std_logic_vector(log_2(be_dw/8)-1 downto 0);
    size : in std_logic_vector(2 downto 0)
    ) return std_logic_vector is
    variable mask      : std_logic_vector(be_dw/8-1 downto 0);
    variable mask_temp : std_logic_vector(be_dw/8-1 downto 0);
  begin
    mask_temp := (others => '0');

    --create strb bits depending on the size aligned to the lsb
    for i in 0 to (be_dw/8)-1 loop
      if i <= (2**(to_integer(unsigned(size))))-1 then
        mask_temp(i) := '1';
      end if;
    end loop;
    --shift the generated strb depending on the addr to align it with correct
    --byte lanes
    mask := std_logic_vector(shift_left(unsigned(mask_temp), to_integer(unsigned(addr))));

    return mask;
  end wstrobe_generate;

  signal inp    : input_ports;
  signal aximi  : axi_bm_somi_type;
  signal r, rin : reg_type;

begin

  --input port assignments
  aximi.aw.ready <= axi_aw_ready;
  aximi.w.ready  <= axi_w_ready;
  aximi.b.id     <= axi_b_id;
  aximi.b.resp   <= axi_b_resp;
  aximi.b.valid  <= axi_b_valid;
  aximi.ar.ready <= axi_ar_ready;
  aximi.r.id     <= axi_r_id;
  aximi.r.data   <= byte_swap(axi_r_data) when endian = '0' else axi_r_data;
  aximi.r.resp   <= axi_r_resp;
  aximi.r.last   <= axi_r_last;
  aximi.r.valid  <= axi_r_valid;

  inp.wr_len  <= wr_len;
  inp.rd_len  <= rd_len;
  inp.wr_data <= wr_data;
  inp.rd_addr <= rd_addr;
  inp.wr_addr <= wr_addr;

  comb : process(r, aximi, ahb_be_in, inp)
    variable rd_sample  : std_logic;
    variable rd_len_tmp : std_logic_vector(7 downto 0);
    variable wr_sample  : std_logic;
    variable wr_len_tmp : std_logic_vector(7 downto 0);
    variable new_data   : std_logic;
    variable v          : reg_type;
    variable axi_w_data_endian : std_logic_vector(be_dw-1 downto 0);
  begin
    v := r;

    --read channel state machine
    rd_sample       := '0';
    v.rdata_valid   := '0';
    v.rd_error      := '0';
    v.rburst_done   := '0';
    v.wburst_done   := '0';
    v.aximo.r.ready := '1';
    case r.rdstate is
      when idle =>
        v.rd_gnt         := '1';
        v.aximo.ar.valid := '0';
        --wait for read request from middle-end
        if (ahb_be_in.rd_req = '1') then
          --read request arrived from middle-end
          --propagate the corresponding AXI transaction
          --from the read address channel and go to
          --burst state
          v.rd_gnt  := '0';
          v.rdstate := burst;
          rd_sample := '1';
        end if;

      when burst =>

        if aximi.ar.ready = '1' then
          --request on the read address chanel is
          --validated
          v.aximo.ar.valid := '0';
        end if;

        if aximi.r.valid = '1' then
          --data word arrived from the read data channel
          v.rdata_valid := '1';
          v.rd_data     := aximi.r.data;

          if aximi.r.last = '1' then
            --last word arrived from the read data channel
            --go to idle state and wait for a new read
            --request from the middle-end
            v.rdstate     := idle;
            v.rd_gnt      := '1';
            v.rburst_done := '1';
          end if;

          if aximi.r.resp = BMXRESP_SLVERR or aximi.r.resp = BMXRESP_DECERR then
            --error is signaled for a data beat on the read data,
            --propagate it to the middl-end
            v.rd_error := '1';
          end if;
          
        end if;
        
    end case;

    --write channel state machine
    wr_sample := '0';
    new_data  := '0';
    case r.wrstate is
      when idle =>
        v.wr_gnt          := '1';
        v.aximo.aw.valid  := '0';
        v.aximo.w.valid   := '0';
        v.aximo.w.last    := '0';
        v.wr_error        := '0';
        v.excl_error      := '0';
        v.wr_counter      := (others => '0');
        v.block_validated := '0';
        v.aximo.b.ready   := '0';
        --wait for write request from
        --middle-end
        if (ahb_be_in.wr_req = '1') then
          --write request arrived from middle-end
          --propagate the corresponding AXI transaction
          --from the write address channel and go to
          --burst state
          new_data  := '1';
          wr_sample := '1';
          v.wrstate := burst;
        end if;
        
      when burst =>

        if aximi.aw.ready = '1' then
          --request on the write address chanel is
          --validated
          v.aximo.aw.valid := '0';
        end if;

        if aximi.w.ready = '1' then
          --write word on data channel is validated
          if r.aximo.aw.len = "00000000" then
            --this was a single beat AXI transaction
            v.aximo.w.valid := '0';
            v.aximo.w.last  := '0';
          else
            if r.wr_counter = unsigned(r.aximo.aw.len)-1 then
              --last word in the write transaction
              --set the last indication on the write data channel
              --set the write validation channel ready
              v.aximo.w.last  := '1';
              v.aximo.b.ready := '1';
            end if;

            if r.wr_counter = unsigned(r.aximo.aw.len) then
              --last word in the write transaction is
              --acknowledged
              v.aximo.w.last  := '0';
              v.aximo.w.valid := '0';
            else
              --go to the next word that is going
              --to be written
              v.wr_counter   := r.wr_counter+1;
              v.aximo.w.data := inp.wr_data;
              new_data       := '1';
            end if;
          end if;
        end if;

        if aximi.b.valid = '1' and r.aximo.b.ready = '1' then
          --write transaction is validated
          v.block_validated := '1';
        end if;

        --address channel validated, last write acknowledged and block valid arrived
        --go to the idle state
        if r.aximo.aw.valid = '0' and r.aximo.w.valid = '0' and v.block_validated = '1' then
          v.wrstate       := idle;
          v.wburst_done   := '1';
          v.aximo.b.ready := '0';

          if aximi.b.resp = BMXRESP_SLVERR or aximi.b.resp = BMXRESP_DECERR then
            --error is signaled for write transaction propagate to the middle-end
            v.wr_error := '1';
          end if;

          if aximi.b.resp = BMXRESP_SLVERR then
            --distinguish slave error in order to handle exclusive acceesses
            v.excl_error := '1';
          end if;
          
        end if;
    end case;

    rd_len_tmp                                          := (others => '0');
    rd_len_tmp(log_2(max_burst_length_ptwo)-1 downto 0) := inp.rd_len;
    if rd_sample = '1' then
      --samples the read address channel signals
      v.aximo.ar.id    := (others => '0');
      v.aximo.ar.addr  := inp.rd_addr;
      v.aximo.ar.len   := rd_len_tmp;
      v.aximo.ar.size  := ahb_be_in.rd_size;
      v.aximo.ar.burst := "01";
      v.aximo.ar.lock  := '0';
      v.aximo.ar.cache := "0011";
      v.aximo.ar.prot  := "001";
      v.aximo.ar.valid := '1';
      v.aximo.ar.qos   := (others => '0');
    end if;

    wr_len_tmp                                          := (others => '0');
    wr_len_tmp(log_2(max_burst_length_ptwo)-1 downto 0) := inp.wr_len;
    if wr_sample = '1' then
      --samples the write address channel signals
      v.aximo.aw.id    := (others => '0');
      v.aximo.aw.addr  := inp.wr_addr;
      v.aximo.aw.len   := wr_len_tmp;
      v.aximo.aw.size  := ahb_be_in.wr_size;
      v.aximo.aw.burst := "01";
      v.aximo.aw.lock  := '0';
      v.aximo.aw.cache := "0011";
      v.aximo.aw.prot  := "001";
      v.aximo.aw.valid := '1';
      v.aximo.aw.qos   := (others => '0');
      --samples the first word for the write data channel
      v.aximo.w.data   := inp.wr_data;
      v.aximo.w.strb := wstrobe_generate(inp.wr_addr(log_2(be_dw/8)-1 downto 0),
                                         ahb_be_in.wr_size);

      if wr_len_tmp = "00000000" then
        --if the length of the transaction is 1 assert the
        --wlast already
        v.aximo.w.last  := '1';
        v.aximo.b.ready := '1';
      else
        v.aximo.w.last := '0';
        v.aximo.w.strb := (others => '1');
      end if;

      v.aximo.w.valid := '1';
    end if;

    rin <= v;

    --port assignments
    ahb_be_out.rd_gnt           <= r.rd_gnt;
    ahb_be_out.wr_gnt           <= r.wr_gnt;
    ahb_be_out.rdata_valid      <= r.rdata_valid;
    ahb_be_out.rdata_valid_comb <= v.rdata_valid;
    ahb_be_out.rd_error         <= r.rd_error;
    ahb_be_out.rd_error_comb    <= v.rd_error;
    ahb_be_out.rd_done          <= r.rburst_done;
    ahb_be_out.rd_done_comb     <= v.rburst_done;
    rd_data                     <= r.rd_data;
    rd_data_comb                <= v.rd_data;

    ahb_be_out.wdata_ren  <= new_data;
    ahb_be_out.wr_error   <= r.wr_error;
    ahb_be_out.excl_error <= r.excl_error;
    ahb_be_out.wr_done    <= r.wburst_done;

    --write address channel
    axi_aw_id    <= r.aximo.aw.id;
    axi_aw_addr  <= r.aximo.aw.addr;
    axi_aw_len   <= r.aximo.aw.len;
    axi_aw_size  <= r.aximo.aw.size;
    axi_aw_burst <= r.aximo.aw.burst;
    axi_aw_lock  <= r.aximo.aw.lock;
    axi_aw_cache <= r.aximo.aw.cache;
    axi_aw_prot  <= r.aximo.aw.prot;
    axi_aw_valid <= r.aximo.aw.valid;
    axi_aw_qos   <= r.aximo.aw.qos;
    --write data channel
    axi_w_data_endian := byte_swap(r.aximo.w.data);
    if endian /= '0' then
      axi_w_data_endian := r.aximo.w.data;
    end if;
    axi_w_data   <= axi_w_data_endian;
    axi_w_strb   <= r.aximo.w.strb;
    axi_w_last   <= r.aximo.w.last;
    axi_w_valid  <= r.aximo.w.valid;
    --write response channel
    axi_b_ready  <= r.aximo.b.ready;
    --read address channel
    axi_ar_id    <= r.aximo.ar.id;
    axi_ar_addr  <= r.aximo.ar.addr;
    axi_ar_len   <= r.aximo.ar.len;
    axi_ar_size  <= r.aximo.ar.size;
    axi_ar_burst <= r.aximo.ar.burst;
    axi_ar_lock  <= r.aximo.ar.lock;
    axi_ar_cache <= r.aximo.ar.cache;
    axi_ar_prot  <= r.aximo.ar.prot;
    axi_ar_valid <= r.aximo.ar.valid;
    axi_ar_qos   <= r.aximo.ar.qos;
    --read data channel
    axi_r_ready  <= r.aximo.r.ready;
    
  end process;


  syncregs : if not async_reset generate
    regs : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if rstn = '0' then
          r <= RES_T;
        end if;

        --with the generic limitations on the generic_bm_axi.vhd file the 4kB boundary
        --should never be crossed. This is an assertion in case something goes
        --wrong with a configuration is set wrongyl etc.
        --pragma translate_off
        if r.aximo.ar.valid = '1' and (to_integer(unsigned(r.aximo.ar.addr(11 downto 0))) + inc_v(r.aximo.ar.size)*to_integer(unsigned(r.aximo.ar.len))) > 4096 then
          assert false report "Error!! 4kB boundary crossed" severity failure;
        end if;

        if r.aximo.aw.valid = '1' and (to_integer(unsigned(r.aximo.aw.addr(11 downto 0))) + inc_v(r.aximo.aw.size)*to_integer(unsigned(r.aximo.aw.len))) > 4096 then
          assert false report "Error!! 4kB boundary crossed" severity failure;
        end if;
        --pragma translate_on
      end if;
    end process;
  end generate;

  asyncregs : if async_reset generate
    regs : process(rstn, clk)
    begin
      if rstn = '0' then
        r <= RES_T;
      elsif rising_edge(clk) then
        r <= rin;

        --with the generic limitations on the generic_bm_axi.vhd file the 4kB boundary
        --should never be crossed. This is an assertion in case something goes
        --wrong with a configuration is set wrongyl etc.
        --pragma translate_off
        if r.aximo.ar.valid = '1' and (to_integer(unsigned(r.aximo.ar.addr(11 downto 0))) + inc_v(r.aximo.ar.size)*to_integer(unsigned(r.aximo.ar.len))) > 4096 then
          assert false report "Error!! 4kB boundary crossed" severity failure;
        end if;

        if r.aximo.aw.valid = '1' and (to_integer(unsigned(r.aximo.aw.addr(11 downto 0))) + inc_v(r.aximo.aw.size)*to_integer(unsigned(r.aximo.aw.len))) > 4096 then
          assert false report "Error!! 4kB boundary crossed" severity failure;
        end if;
        --pragma translate_on
      end if;
    end process;
  end generate;
  
end rtl;
