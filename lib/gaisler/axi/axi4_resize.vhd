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
-- Entity:      axi4_resize
-- File:        axi4_resize.vhd
-- Author:      Carl Ehrenstrahle - Frontgrade Gaisler AB
-- Description: AXI4 Transaction width reducer
-- Performs transaction level resizing to facilitate data width changes.
-- Only changes by a factor of 2^x is supported.
-- Upscaling is not supported nor recommended due to overrun issues.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.log2;

entity axi4_resize is
  generic (
    wl_s_data : positive := 128;
    wl_m_data : positive := 32;
    wl_user : natural := 0;
    wl_id : natural := 0
  );
  port (
    clk : in std_logic;
    rst : in std_logic; -- Active low reset

    -- Slave ports
    s_axi4_awvalid : in std_logic;
    s_axi4_awaddr : in std_logic_vector(31 downto 0);
    s_axi4_awsize : in std_logic_vector(2 downto 0);
    s_axi4_awburst : in std_logic_vector(1 downto 0);
    s_axi4_awlen : in std_logic_vector(7 downto 0);
    s_axi4_awcache : in std_logic_vector(3 downto 0);
    s_axi4_awregion : in std_logic_vector(3 downto 0);
    s_axi4_awqos : in std_logic_vector(3 downto 0);
    s_axi4_awprot : in std_logic_vector(2 downto 0);
    s_axi4_awlock : in std_logic_vector(1 downto 0);
    s_axi4_awid : in std_logic_vector(wl_id - 1 downto 0);
    s_axi4_awuser : in std_logic_vector(wl_user - 1 downto 0);
    s_axi4_awready : out std_logic;

    s_axi4_wdata : in std_logic_vector(wl_s_data - 1 downto 0);
    s_axi4_wstrb : in std_logic_vector(wl_s_data/8 - 1 downto 0);
    s_axi4_wlast : in std_logic;
    s_axi4_wvalid : in std_logic;
    s_axi4_wready : out std_logic;

    s_axi4_bvalid : out std_logic;
    s_axi4_bresp : out std_logic_vector(1 downto 0);
    s_axi4_bid : out std_logic_vector(wl_id - 1 downto 0);
    s_axi4_buser : out std_logic_vector(wl_user - 1 downto 0);
    s_axi4_bready : in std_logic;

    s_axi4_arvalid : in std_logic;
    s_axi4_araddr : in std_logic_vector(31 downto 0);
    s_axi4_arsize : in std_logic_vector(2 downto 0);
    s_axi4_arburst : in std_logic_vector(1 downto 0);
    s_axi4_arlen : in std_logic_vector(7 downto 0);
    s_axi4_arcache : in std_logic_vector(3 downto 0);
    s_axi4_arregion : in std_logic_vector(3 downto 0);
    s_axi4_arqos : in std_logic_vector(3 downto 0);
    s_axi4_arprot : in std_logic_vector(2 downto 0);
    s_axi4_arlock : in std_logic_vector(1 downto 0);
    s_axi4_arid : in std_logic_vector(wl_id - 1 downto 0);
    s_axi4_aruser : in std_logic_vector(wl_user - 1 downto 0);
    s_axi4_arready : out std_logic;

    s_axi4_rdata : out std_logic_vector(wl_s_data - 1 downto 0);
    s_axi4_rresp : out std_logic_vector(1 downto 0);
    s_axi4_rid : out std_logic_vector(wl_id - 1 downto 0);
    s_axi4_rlast : out std_logic;
    s_axi4_rvalid : out std_logic;
    s_axi4_rready : in std_logic;

    -- Master ports
    m_axi4_awvalid : out std_logic;
    m_axi4_awaddr : out std_logic_vector(31 downto 0);
    m_axi4_awsize : out std_logic_vector(2 downto 0);
    m_axi4_awburst : out std_logic_vector(1 downto 0);
    m_axi4_awlen : out std_logic_vector(7 downto 0);
    m_axi4_awcache : out std_logic_vector(3 downto 0);
    m_axi4_awregion : out std_logic_vector(3 downto 0);
    m_axi4_awqos : out std_logic_vector(3 downto 0);
    m_axi4_awprot : out std_logic_vector(2 downto 0);
    m_axi4_awlock : out std_logic_vector(1 downto 0);
    m_axi4_awid : out std_logic_vector(wl_id - 1 downto 0);
    m_axi4_awuser : out std_logic_vector(wl_user - 1 downto 0);
    m_axi4_awready : in std_logic;

    m_axi4_wdata : out std_logic_vector(wl_m_data - 1 downto 0);
    m_axi4_wstrb : out std_logic_vector(wl_m_data/8 - 1 downto 0);
    m_axi4_wlast : out std_logic;
    m_axi4_wvalid : out std_logic;
    m_axi4_wready : in std_logic;

    m_axi4_bvalid : in std_logic;
    m_axi4_bresp : in std_logic_vector(1 downto 0);
    m_axi4_bid : in std_logic_vector(wl_id - 1 downto 0);
    m_axi4_buser : in std_logic_vector(wl_user - 1 downto 0);
    m_axi4_bready : out std_logic;

    m_axi4_arvalid : out std_logic;
    m_axi4_araddr : out std_logic_vector(31 downto 0);
    m_axi4_arsize : out std_logic_vector(2 downto 0);
    m_axi4_arburst : out std_logic_vector(1 downto 0);
    m_axi4_arlen : out std_logic_vector(7 downto 0);
    m_axi4_arcache : out std_logic_vector(3 downto 0);
    m_axi4_arregion : out std_logic_vector(3 downto 0);
    m_axi4_arqos : out std_logic_vector(3 downto 0);
    m_axi4_arprot : out std_logic_vector(2 downto 0);
    m_axi4_arlock : out std_logic_vector(1 downto 0);
    m_axi4_arid : out std_logic_vector(wl_id - 1 downto 0);
    m_axi4_aruser : out std_logic_vector(wl_user - 1 downto 0);
    m_axi4_arready : in std_logic;

    m_axi4_rdata : in std_logic_vector(wl_m_data - 1 downto 0);
    m_axi4_rresp : in std_logic_vector(1 downto 0);
    m_axi4_rid : in std_logic_vector(wl_id - 1 downto 0);
    m_axi4_rlast : in std_logic;
    m_axi4_rvalid : in std_logic;
    m_axi4_rready : out std_logic
  );
end entity;

architecture rtl of axi4_resize is
  -- Returns the bit offset of the strobe matching the size and address offset.
  function get_strobe_offset(address : std_logic_vector;
                             size : std_logic_vector;
                             strb_width : positive) return natural is
    variable t : unsigned(log2(strb_width) - 1 downto 0);
  begin
    -- The intra-word width is decided by bus data width - the size.
    t := resize(unsigned(address(log2(strb_width) - 1 downto
                                 to_integer(unsigned(size)))),
                t'length);
    return to_integer(shift_left(t, to_integer(unsigned(size))));
  end function;

  constant ASYNC_RESET : boolean :=
    GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
begin
  -- In case of upscaling the transaction, an odd number of beats can become even.
  --       This will require masking of the strobe bits to not accidentally overflow the
  --       last write.
  --       Read transactions can never be scaled up due to the effect of reading too much.
  --       A 1 byte read upscaled will potentially overrun the target buffer.
  -- Conclusion: Never upscale, don't use a module to upscale, just connect the busses.
  s_eq_m : if wl_s_data = wl_m_data generate
  begin
    s_axi4_awready <= m_axi4_awready;
    s_axi4_wready <= m_axi4_wready;

    s_axi4_bvalid <= m_axi4_bvalid;
    s_axi4_bresp <= m_axi4_bresp;
    s_axi4_bid <= m_axi4_bid;
    s_axi4_buser <= m_axi4_buser;

    s_axi4_arready <= m_axi4_arready;

    s_axi4_rdata <= m_axi4_rdata;
    s_axi4_rresp <= m_axi4_rresp;
    s_axi4_rid <= m_axi4_rid;
    s_axi4_rlast <= m_axi4_rlast;
    s_axi4_rvalid <= m_axi4_rvalid;

    -- Master ports
    m_axi4_awvalid <= s_axi4_awvalid;
    m_axi4_awaddr <= s_axi4_awaddr;
    m_axi4_awsize <= s_axi4_awsize;
    m_axi4_awburst <= s_axi4_awburst;
    m_axi4_awlen <= s_axi4_awlen;
    m_axi4_awcache <= s_axi4_awcache;
    m_axi4_awregion <= s_axi4_awregion;
    m_axi4_awqos <= s_axi4_awqos;
    m_axi4_awprot <= s_axi4_awprot;
    m_axi4_awlock <= s_axi4_awlock;
    m_axi4_awid <= s_axi4_awid;
    m_axi4_awuser <= s_axi4_awuser;

    m_axi4_wdata <= s_axi4_wdata;
    m_axi4_wstrb <= s_axi4_wstrb;
    m_axi4_wlast <= s_axi4_wlast;
    m_axi4_wvalid <= s_axi4_wvalid;

    m_axi4_bready <= s_axi4_bready;

    m_axi4_arvalid <= s_axi4_arvalid;
    m_axi4_araddr <= s_axi4_araddr;
    m_axi4_arsize <= s_axi4_arsize;
    m_axi4_arburst <= s_axi4_arburst;
    m_axi4_arlen <= s_axi4_arlen;
    m_axi4_arcache <= s_axi4_arcache;
    m_axi4_arregion <= s_axi4_arregion;
    m_axi4_arqos <= s_axi4_arqos;
    m_axi4_arprot <= s_axi4_arprot;
    m_axi4_arlock <= s_axi4_arlock;
    m_axi4_arid <= s_axi4_arid;
    m_axi4_aruser <= s_axi4_aruser;

    m_axi4_rready <= s_axi4_rready;
  end generate;

  s_lt_m : if wl_s_data < wl_m_data generate
    type reg_t is record
      w_offset : integer range 0 to wl_m_data/wl_s_data - 1; -- Block offset inside vector
      w_beats_per_block : integer range 0 to (wl_s_data / 8) - 1;
      w_beat_counter: integer range 0 to (wl_s_data / 8) - 1;
      w_allow : std_logic;
      r_offset : integer range 0 to wl_m_data/wl_s_data - 1; -- Block offset inside vector
      r_beats_per_block : integer range 0 to (wl_s_data / 8) - 1;
      r_beat_counter: integer range 0 to (wl_s_data / 8) - 1;
      r_allow : std_logic;
    end record;

    constant reg_reset_c : reg_t := (
      w_offset => 0,
      w_beats_per_block => 0,
      w_beat_counter => 0,
      w_allow => '0',
      r_offset => 0,
      r_beats_per_block => 0,
      r_beat_counter => 0,
      r_allow => '0'
    );

    signal r, rin : reg_t;
  begin
    comb_p : process(r,
                     s_axi4_awvalid, s_axi4_awaddr, s_axi4_awsize, m_axi4_awready,
                     s_axi4_wvalid, s_axi4_wdata, s_axi4_wstrb, m_axi4_wready,
                     s_axi4_arvalid, s_axi4_araddr, s_axi4_arsize, m_axi4_arready,
                     s_axi4_rready, m_axi4_rvalid, m_axi4_rdata
                   )

      function get_block_offset(addr : std_logic_vector;
                                wl_s : integer; wl_m : positive) return natural is
      begin
        -- wl_s < wl_m
        return to_integer(unsigned(addr(log2(wl_m/8) - 1 downto log2(wl_s/8))));
      end function;

      variable v : reg_t;
    begin
      v := r;

      -- Writing
      ----------
      s_axi4_awready <= m_axi4_awready and not r.w_allow;
      m_axi4_awvalid <= s_axi4_awvalid and not r.w_allow;
      s_axi4_wready <= m_axi4_wready and r.w_allow;
      m_axi4_wvalid <= s_axi4_wvalid and r.w_allow;

      -- Replicate write data across vector, this is fine thanks to strobe.
      for i in 0 to (wl_m_data / wl_s_data) - 1 loop
        m_axi4_wdata((i + 1) * wl_s_data - 1 downto i * wl_s_data) <= s_axi4_wdata;
      end loop;

      -- Move strobe to correct block.
      m_axi4_wstrb <= (others => '0'); -- Make sure that vector is clean.
      m_axi4_wstrb((r.w_offset + 1) * (wl_s_data / 8) - 1 downto
                   r.w_offset * (wl_s_data / 8)) <= s_axi4_wstrb;

      if s_axi4_awvalid = '1' and m_axi4_awready = '1' and r.w_allow = '0' then
        v.w_beats_per_block := log2(wl_s_data / 8) - to_integer(unsigned(s_axi4_awsize));
        v.w_offset := get_block_offset(s_axi4_awaddr, wl_s_data, wl_m_data);
        v.w_beat_counter := v.w_beats_per_block -
          (get_strobe_offset(s_axi4_awaddr, s_axi4_awsize,
                             wl_s_data / 8) / 2**to_integer(unsigned(s_axi4_awsize)));
        v.w_allow := '1';
      end if;

      if s_axi4_wvalid = '1' and m_axi4_wready = '1' and r.w_allow = '1' then
        if r.w_beat_counter = 0 then
          v.w_offset := (r.w_offset + 1) mod (wl_m_data/wl_s_data);
          v.w_beat_counter := r.w_beats_per_block;
        else
          v.w_beat_counter := r.w_beat_counter - 1;
        end if;

        if s_axi4_wlast = '1' then
          v.w_allow := '0';
        end if;
      end if;

      -- Reading
      ----------
      s_axi4_arready <= m_axi4_arready and not r.r_allow;
      m_axi4_arvalid <= s_axi4_arvalid and not r.r_allow;
      m_axi4_rready <= s_axi4_rready and r.r_allow;
      s_axi4_rvalid <= m_axi4_rvalid and r.r_allow;

      -- Move read data from correct block.
      s_axi4_rdata <= m_axi4_rdata((r.r_offset + 1) * wl_s_data - 1 downto
                                   r.r_offset * wl_s_data);

      if s_axi4_arvalid = '1' and m_axi4_arready = '1' and r.r_allow = '0' then
        v.r_beats_per_block := log2(wl_s_data / 8) - to_integer(unsigned(s_axi4_arsize));
        v.r_offset := get_block_offset(s_axi4_araddr, wl_s_data, wl_m_data);
        v.r_beat_counter := v.r_beats_per_block -
          (get_strobe_offset(s_axi4_araddr, s_axi4_arsize,
                             wl_s_data / 8) / 2**to_integer(unsigned(s_axi4_arsize)));
        v.r_allow := '1';
      end if;

      if m_axi4_rvalid = '1' and s_axi4_rready = '1' and r.r_allow = '1' then
        if r.r_beat_counter = 0 then
          v.r_offset := (r.r_offset + 1) mod (wl_m_data/wl_s_data);
          v.r_beat_counter := r.r_beats_per_block;
        else
          v.r_beat_counter := r.r_beat_counter - 1;
        end if;

        if m_axi4_rlast = '1' then
          v.r_allow := '0';
        end if;
      end if;

      -- Propagate next state
      ----------
      rin <= v;
    end process;

    --==================
    -- Clocked process
    --==================
    syncregs : if not ASYNC_RESET generate
      regs_p : process(clk)
      begin
        if rising_edge(clk) then
          r <= rin;
          if rst = '0' then
            r <= reg_reset_c;
          end if;
        end if;
      end process;
    end generate;

    asyncregs : if ASYNC_RESET generate
      regs_p : process(rst, clk)
      begin
        if rst = '0' then
          r <= reg_reset_c;
        elsif rising_edge(clk) then
          r <= rin;
        end if;
      end process;
    end generate;

    s_axi4_awready <= m_axi4_awready;
    s_axi4_wready <= m_axi4_wready;

    s_axi4_bvalid <= m_axi4_bvalid;
    s_axi4_bresp <= m_axi4_bresp;
    s_axi4_bid <= m_axi4_bid;
    s_axi4_buser <= m_axi4_buser;

    s_axi4_arready <= m_axi4_arready;
    s_axi4_rresp <= m_axi4_rresp;
    s_axi4_rid <= m_axi4_rid;
    s_axi4_rlast <= m_axi4_rlast;
    s_axi4_rvalid <= m_axi4_rvalid;

    -- Master ports
    m_axi4_awvalid <= s_axi4_awvalid;
    m_axi4_awaddr <= s_axi4_awaddr;
    m_axi4_awsize <= s_axi4_awsize;
    m_axi4_awburst <= s_axi4_awburst;
    m_axi4_awlen <= s_axi4_awlen;
    m_axi4_awcache <= s_axi4_awcache;
    m_axi4_awregion <= s_axi4_awregion;
    m_axi4_awqos <= s_axi4_awqos;
    m_axi4_awprot <= s_axi4_awprot;
    m_axi4_awlock <= s_axi4_awlock;
    m_axi4_awid <= s_axi4_awid;
    m_axi4_awuser <= s_axi4_awuser;
    m_axi4_wlast <= s_axi4_wlast;
    m_axi4_wvalid <= s_axi4_wvalid;

    m_axi4_bready <= s_axi4_bready;

    m_axi4_arvalid <= s_axi4_arvalid;
    m_axi4_araddr <= s_axi4_araddr;
    m_axi4_arsize <= s_axi4_arsize;
    m_axi4_arburst <= s_axi4_arburst;
    m_axi4_arlen <= s_axi4_arlen;
    m_axi4_arcache <= s_axi4_arcache;
    m_axi4_arregion <= s_axi4_arregion;
    m_axi4_arqos <= s_axi4_arqos;
    m_axi4_arprot <= s_axi4_arprot;
    m_axi4_arlock <= s_axi4_arlock;
    m_axi4_arid <= s_axi4_arid;
    m_axi4_aruser <= s_axi4_aruser;

    m_axi4_rready <= s_axi4_rready;
  end generate;

  s_gt_m : if wl_s_data > wl_m_data generate
    function to_sl(a : boolean) return std_logic is
    begin
      if a then return '1'; else return '0'; end if;
    end function;

    type state_t is (IDLE, RUNNING);

    type reg_t is record
      -- write
      wstate : state_t;
      n_wbeats : unsigned(15 downto 0);
      n_wtrans : integer range 0 to 255;
      outstanding_wtrans : boolean;
      wbeat_count : integer range 0 to 255;
      suppress_write_output : std_logic;
      inject_wlast : std_logic;
      woutputs_per_input : integer range 0 to 255;
      woutput_count : integer range 0 to 255; -- outputs - 1
      beat_bytes_exp : integer range 0 to log2(wl_m_data/8); -- bytes exponent per output beat
      wbuf_offset : integer range 0 to (wl_s_data / 8) - 1; -- Byte offset inside buffer
      wbuf_data : std_logic_vector(wl_s_data - 1 downto 0);
      wbuf_strb : std_logic_vector(wl_s_data / 8 - 1 downto 0);
      wbuf_dv : std_logic;
      wbuf_last : std_logic;
      -- read
      rstate : state_t;
      n_rbeats : unsigned(15 downto 0);
      n_rtrans : integer range 0 to 255;
      rinput_bytes_exp : integer range 0 to log2(wl_m_data/8); -- Bytes exponent per input beat
      rinputs_per_output : integer range 0 to 255;
      rinput_count : integer range 0 to 255; -- inputs - 1
      rbuf_offset : integer range 0 to (wl_s_data / 8) - 1; -- Byte offset inside buffer
      -- Output registers
      ---- slave write
      s_axi4_awready : std_logic;
      s_axi4_bvalid : std_logic;
      s_axi4_bresp : std_logic_vector(1 downto 0);
      s_axi4_bid : std_logic_vector(wl_id - 1 downto 0);
      s_axi4_buser : std_logic_vector(wl_user - 1 downto 0);
      ---- master write
      m_axi4_awvalid : std_logic;
      m_axi4_awaddr : std_logic_vector(31 downto 0);
      m_axi4_awsize : std_logic_vector(2 downto 0);
      m_axi4_awburst : std_logic_vector(1 downto 0);
      m_axi4_awlen : std_logic_vector(7 downto 0);
      m_axi4_awcache : std_logic_vector(3 downto 0);
      m_axi4_awregion : std_logic_vector(3 downto 0);
      m_axi4_awqos : std_logic_vector(3 downto 0);
      m_axi4_awprot : std_logic_vector(2 downto 0);
      m_axi4_awlock : std_logic_vector(1 downto 0);
      m_axi4_awid : std_logic_vector(wl_id - 1 downto 0);
      m_axi4_awuser : std_logic_vector(wl_user - 1 downto 0);
      m_axi4_wvalid : std_logic;
      m_axi4_wdata : std_logic_vector(wl_m_data - 1 downto 0);
      m_axi4_wstrb : std_logic_vector(wl_m_data / 8 - 1 downto 0);
      m_axi4_wlast : std_logic;
      -- slave read
      s_axi4_arready : std_logic;
      s_axi4_rvalid : std_logic;
      s_axi4_rdata : std_logic_vector(wl_s_data - 1 downto 0);
      s_axi4_rlast : std_logic;
      s_axi4_rresp : std_logic_vector(1 downto 0);
      s_axi4_rid : std_logic_vector(wl_id - 1 downto 0);
      ---- Master read
      m_axi4_arvalid : std_logic;
      m_axi4_araddr : std_logic_vector(31 downto 0);
      m_axi4_arsize : std_logic_vector(2 downto 0);
      m_axi4_arburst : std_logic_vector(1 downto 0);
      m_axi4_arlen : std_logic_vector(7 downto 0);
      m_axi4_arcache : std_logic_vector(3 downto 0);
      m_axi4_arregion : std_logic_vector(3 downto 0);
      m_axi4_arqos : std_logic_vector(3 downto 0);
      m_axi4_arprot : std_logic_vector(2 downto 0);
      m_axi4_arlock : std_logic_vector(1 downto 0);
      m_axi4_arid : std_logic_vector(wl_id - 1 downto 0);
      m_axi4_aruser : std_logic_vector(wl_user - 1 downto 0);
    end record;

    constant reg_reset_c : reg_t := (
      -- Writing
      wstate => IDLE,
      n_wbeats => (others => '0'),
      n_wtrans => 0,
      outstanding_wtrans => false,
      wbeat_count => 0,
      suppress_write_output => '1',
      inject_wlast => '0',
      woutputs_per_input => 0,
      woutput_count => 0,
      beat_bytes_exp => 0,
      wbuf_offset => 0,
      wbuf_data => (others => '0'),
      wbuf_strb => (others => '0'),
      wbuf_dv => '0',
      wbuf_last => '0',
      -- Reading
      rstate => IDLE,
      n_rbeats => (others => '0'),
      n_rtrans => 0,
      rinput_bytes_exp => 0,
      rinputs_per_output => 0,
      rinput_count => 0,
      rbuf_offset => 0,
      -- Output registers
      ---- slave write
      s_axi4_awready => '0',
      s_axi4_bvalid => '0',
      s_axi4_bresp => (others => '0'),
      s_axi4_bid => (others => '0'),
      s_axi4_buser => (others => '0'),
      ---- master write
      m_axi4_awvalid => '0',
      m_axi4_awaddr => (others => '0'),
      m_axi4_awsize => (others => '0'),
      m_axi4_awburst => (others => '0'),
      m_axi4_awlen => (others => '0'),
      m_axi4_awcache => (others => '0'),
      m_axi4_awregion => (others => '0'),
      m_axi4_awqos => (others => '0'),
      m_axi4_awprot => (others => '0'),
      m_axi4_awlock => (others => '0'),
      m_axi4_awid => (others => '0'),
      m_axi4_awuser => (others => '0'),
      m_axi4_wvalid => '0',
      m_axi4_wdata => (others => '0'),
      m_axi4_wstrb => (others => '0'),
      m_axi4_wlast => '0',
      ---- slave read
      s_axi4_arready => '0',
      s_axi4_rvalid => '0',
      s_axi4_rdata => (others => '0'),
      s_axi4_rlast => '0',
      s_axi4_rresp => (others => '0'),
      s_axi4_rid => (others => '0'),
      ---- master read
      m_axi4_arvalid => '0',
      m_axi4_araddr => (others => '0'),
      m_axi4_arsize => (others => '0'),
      m_axi4_arburst => (others => '0'),
      m_axi4_arlen => (others => '0'),
      m_axi4_arcache => (others => '0'),
      m_axi4_arregion => (others => '0'),
      m_axi4_arqos => (others => '0'),
      m_axi4_arprot => (others => '0'),
      m_axi4_arlock => (others => '0'),
      m_axi4_arid => (others => '0'),
      m_axi4_aruser => (others => '0')
    );

    signal r, rin : reg_t;
  begin

    --==================
    -- Combinatorial
    --==================
    comb_p : process(r, s_axi4_awvalid, s_axi4_awaddr,
                     s_axi4_awsize, s_axi4_awburst, s_axi4_awlen,
                     s_axi4_awcache, s_axi4_awregion, s_axi4_awqos,
                     s_axi4_awprot, s_axi4_awlock, s_axi4_awid,
                     s_axi4_awuser,
                     s_axi4_wvalid, s_axi4_wdata, s_axi4_wstrb, s_axi4_wlast,
                     s_axi4_bready,
                     m_axi4_awready, m_axi4_wready,
                     m_axi4_bvalid, m_axi4_bresp, m_axi4_bid, m_axi4_buser,
                     s_axi4_arvalid, s_axi4_araddr,
                     s_axi4_arsize, s_axi4_arburst, s_axi4_arlen,
                     s_axi4_arcache, s_axi4_arregion, s_axi4_arqos,
                     s_axi4_arprot, s_axi4_arlock, s_axi4_arid,
                     s_axi4_aruser, s_axi4_rready,
                     m_axi4_arready, m_axi4_rdata, m_axi4_rresp,
                     m_axi4_rid, m_axi4_rlast, m_axi4_rvalid
                   )

      -- Decode AxSIZE to number of bytes per beat.
      function axsize_to_bytes(axsize : std_logic_vector(2 downto 0)) return positive is
      begin
        return 2**to_integer(unsigned(axsize));
      end function;

      -- Encode number of bytes per beat to AxSIZE.
      -- Essentially a limited log2 table.
      function bytes_to_axsize(n_bytes : positive) return std_logic_vector is
      begin
        case n_bytes is
          when 1 => return "000";
          when 2 => return "001";
          when 4 => return "010";
          when 8 => return "011";
          when 16 => return "100";
          when 32 => return "101";
          when 64 => return "110";
          when others => return "111";
        end case;
      end function;

      function transform_axsize(wl_in : positive; wl_out : positive;
                                axsize : std_logic_vector(2 downto 0))
        return std_logic_vector is

          variable out_exp : unsigned(2 downto 0);
      begin
        -- AxSIZE is encoded as the exponent of 2.
        -- Work in this domain since divisions become subtractions there.
        out_exp := to_unsigned(log2(wl_out / 8), 3);
        if unsigned(axsize) > out_exp then
          -- Fit the transaction into the output size.
          return std_logic_vector(out_exp);
        -- No need to transform an already small enough transaction.
        else
          return axsize;
        end if;
      end function;

      -- Returns the transaction transformation factor (as exponent of 2)
      -- 0 is unchanged (2^0 = 1).
      function data_width_factor(wl_in : positive; wl_out : positive;
                                axsize : std_logic_vector(2 downto 0))
        return natural is

          variable out_exp : unsigned(2 downto 0);
          variable diff_factor : unsigned(2 downto 0);
      begin
        if wl_in = wl_out then
          return 0;
        end if;

        -- AxSIZE is encoded as the exponent of 2.
        -- Work in this domain since divisions become subtractions there.
        out_exp := unsigned(bytes_to_axsize(wl_out / 8));
        if wl_in > wl_out then
          if unsigned(axsize) > out_exp then
            diff_factor := unsigned(axsize) - out_exp;
          else
            diff_factor := "000";
          end if;
        else -- wl_in < wl_out
          if unsigned(axsize) < out_exp then
            diff_factor := out_exp - unsigned(axsize);
          else
            diff_factor := "000"; -- Shouldn't happen.
          end if;
        end if;

        return to_integer(diff_factor);
      end function;

      variable v : reg_t;

      variable wready_input_i : std_logic;
      variable wready_output_i : std_logic;
      variable rready_i : std_logic;
      variable n_wbeats : unsigned(15 downto 0);
      variable n_rbeats : unsigned(15 downto 0);
    begin
      v := r; -- Copy current state.

      wready_input_i := '0';
      wready_output_i := '0';
      rready_i := '0';

      --------------------
      -- Write Management
      --------------------
      case r.wstate is
        when IDLE =>
          v.s_axi4_awready := '1';

          v.wbuf_last := '0';
          v.wbuf_dv := '0';
          v.m_axi4_wvalid := '0';

          if (m_axi4_awready = '1' or r.m_axi4_awvalid = '0') and
            r.s_axi4_awready = '1' then

            v.wbuf_offset := get_strobe_offset(s_axi4_awaddr, s_axi4_awsize,
                                               wl_s_data / 8);
            v.beat_bytes_exp :=
              to_integer(unsigned(transform_axsize(wl_s_data,
                                                   wl_m_data, s_axi4_awsize)));
            v.woutputs_per_input := 2**data_width_factor(wl_s_data, wl_m_data,
                                                         s_axi4_awsize) - 1;
            v.woutput_count := v.woutputs_per_input;

            n_wbeats := shift_left((resize(unsigned(s_axi4_awlen),
                                          n_wbeats'length)
                                    +
                                    to_unsigned(1, n_wbeats'length)),
                                   data_width_factor(wl_s_data, wl_m_data,
                                                         s_axi4_awsize));

            if n_wbeats > to_unsigned(2**8, 16) then
              -- Extra transactions needed.
              v.m_axi4_awlen := (others => '1');
              v.n_wbeats := n_wbeats - to_unsigned(2**8, n_wbeats'length);
              -- 256 transfers is max -> asr8
              v.n_wtrans := ((to_integer(n_wbeats) + 255) / (2**8)) - 1;
              v.outstanding_wtrans := true;
            else
              v.m_axi4_awlen := std_logic_vector(resize((n_wbeats - to_unsigned(1, n_wbeats'length)),
                                                 m_axi4_awlen'length));
              v.n_wbeats := to_unsigned(0, v.n_wbeats'length);
              v.n_wtrans := 0;
              v.outstanding_wtrans := false;
            end if;

            -- Copy input to output.
            v.m_axi4_awvalid := s_axi4_awvalid;
            v.m_axi4_awaddr := s_axi4_awaddr;
            v.m_axi4_awsize := transform_axsize(wl_s_data, wl_m_data, s_axi4_awsize);
            v.m_axi4_awburst := s_axi4_awburst;
            v.m_axi4_awcache := s_axi4_awcache;
            v.m_axi4_awregion := s_axi4_awregion;
            v.m_axi4_awqos := s_axi4_awqos;
            v.m_axi4_awprot := s_axi4_awprot;
            v.m_axi4_awlock := s_axi4_awlock;
            v.m_axi4_awid := s_axi4_awid;
            v.m_axi4_awuser := s_axi4_awuser;

            v.s_axi4_bresp := (others => '0'); -- OKAY

            if s_axi4_awvalid = '1' then
              v.wstate := RUNNING;
              v.s_axi4_awready := '0';
              v.suppress_write_output := '0';
            end if;
          end if;

        when RUNNING =>
          if r.m_axi4_awvalid = '1' and m_axi4_awready = '1' then
            v.wbeat_count := to_integer(unsigned(r.m_axi4_awlen));
            v.m_axi4_awvalid := '0';
            v.suppress_write_output := '0';
          end if;

          -- Handle incoming write responses.
          if m_axi4_bvalid = '1' and (s_axi4_bready or not r.s_axi4_bvalid) = '1' then
            v.s_axi4_bresp := r.s_axi4_bresp or m_axi4_bresp;

            if r.n_wtrans = 0 then
              v.s_axi4_bvalid := '1';
              v.s_axi4_bid := m_axi4_bid;
              v.s_axi4_buser := m_axi4_buser;
            else
              v.n_wtrans := r.n_wtrans - 1;
            end if;

            v.outstanding_wtrans := r.n_wtrans /= 0;
          end if;

          -- Handle accepted outgoing write response.
          if r.s_axi4_bvalid = '1' and s_axi4_bready = '1' then
            v.s_axi4_bvalid := '0';
            v.wstate := IDLE;
            v.s_axi4_awready := '1';
          end if;

          -- Only present new transactions when the previous has finished.
          -- This is done to be able to correctly sample the output beats based on the
          -- master AWLEN output, otherwise a FIFO must be implemented to keep
          -- the AWLEN outputs.
          if r.n_wbeats > 0 and (r.suppress_write_output = '1' and
                                 r.m_axi4_awvalid = '0') then
            if m_axi4_awready = '1' or r.m_axi4_awvalid = '0' then
              v.m_axi4_awvalid := '1';
              -- Assume that any eventual WRAP burst has the wrap boundary within
              -- the maximum output size * len.
              if r.m_axi4_awburst = "01" then -- INCR
                v.m_axi4_awaddr := std_logic_vector(unsigned(r.m_axi4_awaddr) +
                  to_unsigned((to_integer(unsigned(r.m_axi4_awlen)) + 1) *
                               axsize_to_bytes(r.m_axi4_awsize), m_axi4_awaddr'length));
              end if;

              if r.n_wbeats >= to_unsigned(2**8, 16) then
                -- Extra transactions needed.
                v.m_axi4_awlen := (others => '1');
                v.n_wbeats := r.n_wbeats - to_unsigned(2**8, n_wbeats'length);
              else
                v.m_axi4_awlen :=
                  std_logic_vector(resize((r.n_wbeats -
                                           to_unsigned(1, m_axi4_awlen'length)),
                                          m_axi4_awlen'length));
                v.n_wbeats := to_unsigned(0, v.n_wbeats'length);
              end if;
            end if;
          end if;

          -- Add injection of last to the transaction that has been split up.
          if r.outstanding_wtrans then
            if r.m_axi4_wvalid = '1' and m_axi4_wready = '1' then
              if r.wbeat_count > 0 then
                v.wbeat_count := r.wbeat_count - 1;
              end if;
              if r.wbeat_count = 2 then
                v.inject_wlast := '1';
              else
                v.inject_wlast := '0';
              end if;
            end if;
          end if;

          -- Remove injection if last has been seen.
          -- Suppress output until it can be cleared.
          if r.m_axi4_wvalid = '1' and m_axi4_wready = '1' then
            if r.m_axi4_wlast = '1' then
              v.suppress_write_output := '1';
            end if;
          end if;

        wready_output_i := (not r.m_axi4_wvalid or m_axi4_wready) and
          not r.suppress_write_output;
        wready_input_i := ((not r.wbuf_dv) or
          (wready_output_i and to_sl(r.woutput_count = 0))) and not r.wbuf_last;
      end case;

      -- Data gearbox buffers
      --------------------
      if wready_input_i = '1' then
        v.wbuf_data := s_axi4_wdata;
        v.wbuf_strb := s_axi4_wstrb;
        v.wbuf_dv := s_axi4_wvalid;
        v.wbuf_last := s_axi4_wlast;
      end if;

      -- Data output
      --------------------
      if wready_output_i = '1' then
        v.m_axi4_wdata(8*((r.wbuf_offset mod (wl_m_data / 8)) +
                          2**r.beat_bytes_exp) - 1 downto
                       8*(r.wbuf_offset mod (wl_m_data / 8))) :=
          r.wbuf_data(8*(r.wbuf_offset + 2**r.beat_bytes_exp) - 1 downto
                      8*(r.wbuf_offset));
        v.m_axi4_wstrb := (others => '0'); -- Clear old strobes.
        v.m_axi4_wstrb(((r.wbuf_offset mod (wl_m_data / 8)) +
                        2**r.beat_bytes_exp) - 1 downto
                       (r.wbuf_offset mod (wl_m_data / 8))) :=
          r.wbuf_strb((r.wbuf_offset + 2**r.beat_bytes_exp) - 1 downto
                      (r.wbuf_offset));
        v.m_axi4_wvalid := r.wbuf_dv;
        v.m_axi4_wlast := (to_sl(r.woutput_count = 0) and r.wbuf_last) or
                          r.inject_wlast;

        if r.wbuf_dv = '1' then
          v.wbuf_offset := (r.wbuf_offset + 2**r.beat_bytes_exp) mod (wl_s_data / 8);

          if r.woutput_count = 0 then
            v.woutput_count := r.woutputs_per_input;
          else
            v.woutput_count := r.woutput_count - 1;
          end if;
        end if;
      end if;

      --------------------
      -- Read Management
      --------------------
      case r.rstate is
        when IDLE =>
          v.s_axi4_arready := '1';

          if (m_axi4_arready = '1' or r.m_axi4_arvalid = '0') and r.s_axi4_arready = '1' then
            n_rbeats := shift_left(resize(unsigned(s_axi4_arlen), n_rbeats'length) +
                                          to_unsigned(1, n_rbeats'length),
                                          data_width_factor(wl_s_data, wl_m_data, s_axi4_arsize));
            v.rbuf_offset := get_strobe_offset(s_axi4_araddr, s_axi4_arsize,
                                               wl_s_data / 8);
            v.rinput_bytes_exp :=
              to_integer(unsigned(transform_axsize(wl_s_data,
                                                   wl_m_data, s_axi4_arsize)));
            v.rinputs_per_output := 2**data_width_factor(wl_s_data, wl_m_data,
                                                         s_axi4_arsize) - 1;
            v.rinput_count := v.rinputs_per_output;

            if n_rbeats > to_unsigned(2**8, 16) then
              -- Extra transactions needed.
              v.m_axi4_arlen := (others => '1');
              v.n_rbeats := n_rbeats - to_unsigned(2**8, n_rbeats'length);
              -- 256 transfers is max -> asr8
              v.n_rtrans := ((to_integer(n_rbeats) + 255) / (2**8)) - 1;
            else
              v.m_axi4_arlen := std_logic_vector(resize((n_rbeats -
                                                         to_unsigned(1, n_rbeats'length)),
                                                 m_axi4_arlen'length));
              v.n_rbeats := to_unsigned(0, v.n_rbeats'length);
              v.n_rtrans := 0;
            end if;

            -- Copy input to output.
            v.m_axi4_arvalid := s_axi4_arvalid;
            v.m_axi4_araddr := s_axi4_araddr;
            v.m_axi4_arsize := transform_axsize(wl_s_data, wl_m_data, s_axi4_arsize);
            v.m_axi4_arburst := s_axi4_arburst;
            v.m_axi4_arcache := s_axi4_arcache;
            v.m_axi4_arregion := s_axi4_arregion;
            v.m_axi4_arqos := s_axi4_arqos;
            v.m_axi4_arprot := s_axi4_arprot;
            v.m_axi4_arlock := s_axi4_arlock;
            v.m_axi4_arid := s_axi4_arid;
            v.m_axi4_aruser := s_axi4_aruser;

            if s_axi4_arvalid = '1' then
              v.rstate := RUNNING;
              v.s_axi4_arready := '0';
            end if;
          end if;

        when RUNNING =>
          if r.m_axi4_arvalid = '1' and m_axi4_arready = '1' then
            v.m_axi4_arvalid := '0';
          end if;

          rready_i := not r.s_axi4_rvalid or s_axi4_rready;

          -- Handle last transaction.
          if r.s_axi4_rvalid = '1' and s_axi4_rready = '1' and r.s_axi4_rlast = '1' and
            r.n_rtrans = 0 then

            v.rstate := IDLE;
            v.s_axi4_arready := '1';
          end if;

          if m_axi4_rvalid = '1' and rready_i = '1' and m_axi4_rlast = '1' and
            r.n_rtrans > 0 then

            if m_axi4_arready = '1' or r.m_axi4_arvalid = '0' then
              v.m_axi4_arvalid := '1';
              v.m_axi4_araddr := std_logic_vector(unsigned(r.m_axi4_araddr) +
                to_unsigned((to_integer(unsigned(r.m_axi4_arlen)) + 1) *
                            2**r.rinput_bytes_exp, m_axi4_araddr'length));

              if r.n_rbeats > to_unsigned((2**8) - 1, 16) then
                -- Extra transactions needed.
                v.m_axi4_arlen := (others => '1');
                v.n_rbeats := r.n_rbeats - to_unsigned(2**8, n_rbeats'length);
              else
                v.m_axi4_arlen := std_logic_vector(resize((r.n_rbeats - to_unsigned(1, m_axi4_arlen'length)),
                                                   m_axi4_arlen'length));
                v.n_rbeats := to_unsigned(0, v.n_rbeats'length);
              end if;

              v.n_rtrans := r.n_rtrans - 1;
            end if;
          end if;
      end case;

      -- Read data gearbox
      --------------------
      if rready_i = '1' then
        v.s_axi4_rvalid := m_axi4_rvalid and to_sl(r.rinput_count = 0);
        v.s_axi4_rlast := m_axi4_rlast and to_sl(r.n_rtrans = 0);
        v.s_axi4_rdata(8*(r.rbuf_offset + 2**r.rinput_bytes_exp) - 1 downto
                       8*r.rbuf_offset) :=
          m_axi4_rdata(8*(r.rbuf_offset mod (wl_m_data / 8) +
                          2**r.rinput_bytes_exp) - 1 downto
                      8*(r.rbuf_offset mod (wl_m_data / 8)));

        -- Present last valid input read id as the read id for the data.
        -- This holds unless the read data streams has interleaved ids.
        -- The ids should not be interleaved since the bridge only issues
        -- one transaction at a time.
        v.s_axi4_rid := m_axi4_rid;

        if m_axi4_rvalid = '1' then
          v.rbuf_offset := (r.rbuf_offset + 2**r.rinput_bytes_exp) mod (wl_s_data / 8);

          -- Sample the first response, while keeping any non-okay response sticky.
          if m_axi4_rresp /= "00" or r.rinput_count = r.rinputs_per_output then
            v.s_axi4_rresp := m_axi4_rresp;
          end if;

          if r.rinput_count = 0 then
            v.rinput_count := r.rinputs_per_output;
          else
            v.rinput_count := r.rinput_count - 1;
          end if;
        end if;

      end if;

      rin <= v; -- Commit next state.

      -- Output --
      ---- Write
      s_axi4_awready <= r.s_axi4_awready;
      s_axi4_wready <= wready_input_i;
      s_axi4_bvalid <= r.s_axi4_bvalid;
      s_axi4_bresp <= r.s_axi4_bresp;
      s_axi4_bid <= r.s_axi4_bid;
      s_axi4_buser <= r.s_axi4_buser;
      m_axi4_awvalid <= r.m_axi4_awvalid;
      m_axi4_awaddr <= r.m_axi4_awaddr;
      m_axi4_awsize <= r.m_axi4_awsize;
      m_axi4_awlen <= r.m_axi4_awlen;
      m_axi4_awburst <= r.m_axi4_awburst;
      m_axi4_awcache <= r.m_axi4_awcache;
      m_axi4_awregion <= r.m_axi4_awregion;
      m_axi4_awqos <= r.m_axi4_awqos;
      m_axi4_awprot <= r.m_axi4_awprot;
      m_axi4_awlock <= r.m_axi4_awlock;
      m_axi4_awid <= r.m_axi4_awid;
      m_axi4_awuser <= r.m_axi4_awuser;
      m_axi4_wlast <= r.m_axi4_wlast;
      m_axi4_wvalid <= r.m_axi4_wvalid and not r.suppress_write_output;
      m_axi4_wdata <= r.m_axi4_wdata;
      m_axi4_wstrb <= r.m_axi4_wstrb;
      m_axi4_bready <= s_axi4_bready or not r.s_axi4_bvalid;
      ---- Read
      s_axi4_arready <= r.s_axi4_arready;
      s_axi4_rvalid <= r.s_axi4_rvalid;
      s_axi4_rdata <= r.s_axi4_rdata;
      s_axi4_rlast <= r.s_axi4_rlast;
      s_axi4_rid <= r.s_axi4_rid;
      s_axi4_rresp <= r.s_axi4_rresp;
      m_axi4_arvalid <= r.m_axi4_arvalid;
      m_axi4_araddr <= r.m_axi4_araddr;
      m_axi4_arsize <= r.m_axi4_arsize;
      m_axi4_arlen <= r.m_axi4_arlen;
      m_axi4_arburst <= r.m_axi4_arburst;
      m_axi4_arcache <= r.m_axi4_arcache;
      m_axi4_arregion <= r.m_axi4_arregion;
      m_axi4_arqos <= r.m_axi4_arqos;
      m_axi4_arprot <= r.m_axi4_arprot;
      m_axi4_arlock <= r.m_axi4_arlock;
      m_axi4_arid <= r.m_axi4_arid;
      m_axi4_aruser <= r.m_axi4_aruser;
      m_axi4_rready <= rready_i;
    end process;

    --==================
    -- Clocked process
    --==================
    syncregs : if not ASYNC_RESET generate
      regs_p : process(clk)
      begin
        if rising_edge(clk) then
          r <= rin;
          if rst = '0' then
            r <= reg_reset_c;
          end if;
        end if;
      end process;
    end generate;

    asyncregs : if ASYNC_RESET generate
      regs_p : process(rst, clk)
      begin
        if rst = '0' then
          r <= reg_reset_c;
        elsif rising_edge(clk) then
          r <= rin;
        end if;
      end process;
    end generate;
  end generate;
end architecture;
