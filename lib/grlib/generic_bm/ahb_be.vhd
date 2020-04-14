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
-- Entity:      ahb_be
-- File:        ahb_be.vhd
-- Company:     Cobham Gaisler AB
-- Description: AHB back-end controller for bus master
------------------------------------------------------------------------------ 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.generic_bm_pkg.all;


entity ahb_be is
  generic (
    async_reset           : boolean;
    hindex                : integer := 0;
    venid                 : integer := 0;
    devid                 : integer := 0;
    version               : integer := 0;
    max_burst_length_ptwo : integer;
    be_dw                 : integer;
    be_dw_int             : integer;
    lendian_en            : integer := 0;
    addr_width            : integer := 32);
  port (
    clk          : in  std_logic;
    rstn         : in  std_logic;
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
end ahb_be;


architecture rtl of ahb_be is

  constant max_burst_length : integer                      := max_burst_length_ptwo;
  constant zeros10          : std_logic_vector(9 downto 0) := (others => '0');

  type ahb_be_state is (idle, burst);

  type input_port is record
    wr_len      : std_logic_vector(log_2(max_burst_length)-1 downto 0);
    rd_len      : std_logic_vector(log_2(max_burst_length)-1 downto 0);
    wr_data     : std_logic_vector(be_dw_int-1 downto 0);
    wdata_valid : std_logic;
    rd_addr     : std_logic_vector(addr_width-1 downto 0);
    wr_addr     : std_logic_vector(addr_width-1 downto 0);
  end record;

  type reg_type is record
    state       : ahb_be_state;
    last_rd     : std_logic;
    haddr       : std_logic_vector(addr_width-1 downto 0);
    haddr_prev  : std_logic_vector(addr_width-1 downto 0);
    hwdata      : std_logic_vector(be_dw_int-1 downto 0);
    wr_pending  : std_logic;
    rd_pending  : std_logic;
    len_counter : integer range 0 to max_burst_length-1;
    burst_len   : integer range 0 to max_burst_length-1;
    burst_size  : std_logic_vector(2 downto 0);
    burst       : std_logic;
    rdata_valid : std_logic;
    rd_data     : std_logic_vector(be_dw_int-1 downto 0);
    rburst_done : std_logic;
    wburst_done : std_logic;
    retry_again : std_logic;
    --dma
    start       : std_logic;
    lock        : std_logic;
    error       : std_logic;
    rd_error    : std_logic;
  end record;


  constant RES_T : reg_type := (
    state       => idle,
    last_rd     => '0',
    haddr       => (others => '0'),
    haddr_prev  => (others => '0'),
    hwdata      => (others => '0'),
    wr_pending  => '0',
    rd_pending  => '0',
    len_counter => 0,
    burst_len   => 0,
    burst_size  => (others => '0'),
    burst       => '0',
    rdata_valid => '0',
    rd_data     => (others => '0'),
    rburst_done => '0',
    wburst_done => '0',
    retry_again => '0',
    start       => '0',
    lock        => '0',
    error       => '0',
    rd_error    => '0'
    );

  signal r, rin : reg_type;
  signal inp    : input_port;

  signal dmai : bmahb_dma_in_type;
  signal dmao : bmahb_dma_out_type;

  signal dma_addr : std_logic_vector(addr_width-1 downto 0);

  signal wdata : std_logic_vector(be_dw_int-1 downto 0);
  signal rdata : std_logic_vector(be_dw_int-1 downto 0);

begin


  ahbmst_inst : bmahbmst
    generic map (
      async_reset => async_reset,
      hindex      => hindex,
      be_dw       => be_dw,
      be_dw_int   => be_dw_int,
      lendian_en  => lendian_en,
      addr_width  => addr_width)
    port map (
      rst      => rstn,
      clk      => clk,
      dmai     => dmai,
      dmao     => dmao,
      dma_addr => dma_addr,
      wdata    => wdata,
      rdata    => rdata,
      ahbi     => ahbmi,
      ahbo     => ahbmo,
      hrdata   => hrdata,
      hwdata   => hwdata);

  inp.wr_len  <= wr_len;
  inp.rd_len  <= rd_len;
  inp.wr_data <= wr_data;
  inp.rd_addr <= rd_addr;
  inp.wr_addr <= wr_addr;

  comb : process (r, ahb_be_in, inp, dmao, rdata)
    variable vrd_gnt     : std_logic;
    variable vwr_gnt     : std_logic;
    variable wburst_done : std_logic;
    variable new_data    : std_logic;
    variable v           : reg_type;
  begin
    v := r;

    --Arbitration between read and write. If the last operation was a read and
    --both read and write is asserted then write will have priortiy. If the last
    --operation was write and read and write is asserted then read will have priority,
    vrd_gnt := (not(r.rd_pending or r.wr_pending)) and (not(r.last_rd and ahb_be_in.wr_req));
    vwr_gnt := (not(r.rd_pending or r.wr_pending)) and (not(not(r.last_rd) and ahb_be_in.rd_req));

    wburst_done := '0';

    new_data := '0';

    v.rdata_valid := '0';
    v.rd_error    := '0';
    v.rburst_done := '0';
    v.wburst_done := '0';

    case r.state is
      when idle =>

        v.error       := '0';
        v.retry_again := '0';
        v.rd_pending  := '0';
        v.wr_pending  := '0';
        v.start       := '0';

        if (vrd_gnt and ahb_be_in.rd_req) = '1' then
          --write request graned
          v.state      := burst;
          v.rd_pending := '1';
          v.start      := '1';
          if ahb_be_in.lock = '1' then
            --if it is an exclusive operation assert
            --the lock (only in AHB)
            v.lock := '1';
          else
            v.lock := '0';
          end if;
          v.len_counter := 0;
          v.last_rd     := '1';
          v.haddr       := inp.rd_addr;
          v.haddr_prev  := v.haddr;
          v.burst_len   := to_integer(unsigned(inp.rd_len));
          v.burst_size  := ahb_be_in.rd_size;
        end if;

        if (vwr_gnt and ahb_be_in.wr_req) = '1' then
          --read request is granted
          v.state       := burst;
          v.wr_pending  := '1';
          v.start       := '1';
          v.len_counter := 0;
          v.last_rd     := '0';
          v.haddr       := inp.wr_addr;
          v.haddr_prev  := v.haddr;
          v.burst_len   := to_integer(unsigned(inp.wr_len));
          v.burst_size  := ahb_be_in.wr_size;
          new_data      := '1';
        end if;

        if ahb_be_in.lock_remove = '1' then
          --nowrite is asserted during exclusive operation
          v.lock        := '0';
          v.wburst_done := '1';
        end if;

        if v.burst_len > 0 then
          --burst
          v.burst := '1';
        else
          --single access
          v.burst := '0';
        end if;


      when burst =>

        if (dmao.ready = '1') then

          if dmao.active = '1' and (r.len_counter /= r.burst_len) then
            --A data word is acknowledged in the burst (read or write)
            v.len_counter := r.len_counter+1;
          end if;

          if dmao.active = '1' and dmao.mexc = '1' then
            --error signaled, latch it. The burst is not
            --stopped on error.
            if r.last_rd = '1' then
              v.rd_error := '1';
            else
              v.error := '1';
            end if;

          end if;

          if ((r.len_counter = r.burst_len) or (r.burst_len = 0)) and dmao.active = '1' then
            --last data word in the burst is acknowledged
            --ready to accept a new burst go to idle
            v.start      := '0';
            v.state      := idle;
            v.wr_pending := '0';
            v.rd_pending := '0';
            if r.last_rd = '1' then
              v.rburst_done := '1';
            else
              v.wburst_done := '1';
              if r.lock = '1' then
                v.lock := '0';
              end if;
            end if;
          end if;

          if ((v.len_counter = (r.burst_len)) or (r.len_counter = (r.burst_len)) or (r.burst_len = 0)) and (dmao.grant = '1') then
            --the last word in the burst, remove the bus request
            v.start      := '0';
            v.haddr_prev := r.haddr;
          else
            --more words remaining in the burst keep the busreq and increment
            --the addreess
            if (r.start = '1') and (dmao.grant = '1') then
              v.haddr      := std_logic_vector(unsigned(r.haddr)+inc_v(r.burst_size));
              v.haddr_prev := r.haddr;
            end if;
          end if;
        end if;

        if (r.last_rd = '0') and (r.start = '1') and (r.len_counter /= r.burst_len) then
          --sample new data during write burst
          new_data := dmao.ready and dmao.active;
        end if;

        if (r.last_rd = '1' and dmao.active = '1' and dmao.ready = '1') then
          --a valid data is read during read burst
          v.rdata_valid := '1';
          v.rd_data     := rdata;
        end if;

        if (dmao.retry = '1') then
          --RETRY response recieved stop the burst
          --and try from the last address
          v.haddr       := r.haddr_prev;
          v.start       := '0';
          v.retry_again := '1';
        end if;

        if r.retry_again = '1' then
          --RESTART the burst after RETRY response
          v.retry_again := '0';
          v.start       := '1';
        end if;

      when others => null;
    end case;

    if new_data = '1' then
      --latch the data from the write channel fifo
      v.hwdata := inp.wr_data;
    end if;

    rin <= v;

    --port assignments
    dmai.start    <= r.start;
    dmai.write    <= r.wr_pending;
    wdata         <= r.hwdata;
    dma_addr      <= r.haddr;
    dmai.busy     <= '0';
    dmai.irq      <= '0';
    dmai.size     <= r.burst_size;
    dmai.burst    <= r.burst;
    dmai.lock_req <= r.lock;

    ahb_be_out.rd_gnt <= vrd_gnt;
    ahb_be_out.wr_gnt <= vwr_gnt;

    ahb_be_out.wr_done      <= r.wburst_done;
    ahb_be_out.rd_done      <= r.rburst_done;
    ahb_be_out.rd_done_comb <= v.rburst_done;

    ahb_be_out.wdata_ren        <= new_data;
    ahb_be_out.rdata_valid      <= r.rdata_valid;
    ahb_be_out.rdata_valid_comb <= v.rdata_valid;
    ahb_be_out.rd_error         <= r.rd_error;
    ahb_be_out.rd_error_comb    <= v.rd_error;
    ahb_be_out.wr_error         <= r.error;
    rd_data                     <= r.rd_data;
    rd_data_comb                <= v.rd_data;

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
