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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library gaisler;
use gaisler.l2c_lite.all;

library grlib;
use grlib.stdlib.all;
use grlib.stdlib."+";
use grlib.amba.all;
use grlib.devices.all;

library techmap;
use techmap.gencomp.all;

entity l2c_lite_core is
  generic (
    hsindex  : integer;
    tech     : integer;
    haddr    : integer;
    hmask    : integer;
    ioaddr   : integer;
    waysize  : integer;
    linesize : integer;
    cached   : integer;
    repl     : integer;
    ways     : integer;
    bm_dw_l  : integer range 32 to 512 := 128; -- To support CHI
    addr_width  : integer range 32 to 52 := 32);  -- To support CHI
  port (
    rstn   : in std_ulogic;
    clk    : in std_ulogic;
    ahbsi  : in ahb_slv_in_type;
    ahbso  : out ahb_slv_out_type;
    --Bus master domain signals
    --Read Channel
    bmrd_addr        : out std_logic_vector(addr_width-1 downto 0);
    bmrd_size        : out std_logic_vector(log2ext(max_size)-1 downto 0);
    bmrd_req         : out std_logic;
    bmrd_req_granted : in std_logic;
    bmrd_data        : in std_logic_vector(bm_dw_l-1 downto 0);
    bmrd_valid       : in std_logic;
    bmrd_done        : in std_logic;
    bmrd_error       : in std_logic;
    --Write Channel
    bmwr_addr        : out std_logic_vector(addr_width-1 downto 0);
    bmwr_size        : out std_logic_vector(log2ext(max_size)-1 downto 0);
    bmwr_req         : out std_logic;
    bmwr_req_granted : in std_logic;
    bmwr_data        : out std_logic_vector(bm_dw_l-1 downto 0);
    bmwr_full        : in std_logic;
    bmwr_done        : in std_logic;
    bmwr_error       : in std_logic );

end entity l2c_lite_core;

architecture rtl of l2c_lite_core is

  constant addr_depth : integer := log2ext(waysize * (2 ** 10) / linesize);
  constant tag_len    : integer := 32 - addr_depth - log2ext(linesize);
  constant tag_dbits  : integer := tag_len + 2;

  -- RANGES -- 
  subtype TAG_R is natural range 31 downto addr_depth + log2ext(linesize);
  subtype TAG_DATA_R is natural range tag_dbits - 1 downto 2;
  subtype INDEX_R is natural range (addr_depth + log2ext(linesize) - 1) downto log2ext(linesize);
  subtype TAG_INDEX_R is natural range 31 downto log2ext(linesize);
  subtype OFFSET_R is natural range log2ext(linesize) - 1 downto 0;

  constant offset_len : integer := log2ext(linesize) - 1;

  type plru_data_t is array (0 to 2 ** addr_depth - 1) of std_logic_vector(0 to ways - 2);
  type tag_data_t is array (0 to ways - 1) of std_logic_vector(tag_dbits - 1 downto 0);
  type cache_data_t is array (0 to ways - 1) of std_logic_vector(linesize * 8 - 1 downto 0);

  type obm_out_type is record

    -- READ SIGNALS
    bmrd_req_granted : std_logic;
    bmrd_data        : std_logic_vector(bm_dw_l - 1 downto 0);
    bmrd_valid       : std_logic;
    bmrd_done        : std_logic;
    bmrd_error       : std_logic;

    -- WRITE SIGNALS
    bmwr_full        : std_logic;
    bmwr_done        : std_logic;
    bmwr_error       : std_logic;
    bmwr_req_granted : std_logic;

  end record;

  type obm_in_type is record

    -- READ SIGNALS
    bmrd_addr : std_logic_vector(addr_width - 1 downto 0);
    bmrd_size : std_logic_vector(log2ext(max_size) - 1 downto 0);
    bmrd_req  : std_logic;

    -- WRITE SIGNALS
    bmwr_addr : std_logic_vector(addr_width - 1 downto 0);
    bmwr_size : std_logic_vector(log2ext(max_size) - 1 downto 0);
    bmwr_req  : std_logic;
    bmwr_data : std_logic_vector(bm_dw_l - 1 downto 0);

  end record;
  
  type tag_match_ret_type is record
    index : integer range 0 to ways - 1;
    hit   : std_ulogic;
  end record;

  type cache_ctrl_type is record
    en   : std_ulogic;
    repl : std_ulogic;
  end record;

  type diag_type is record
    read_index : std_logic_vector(15 downto 0); -- 16 bit max
    read_way   : std_logic_vector(4 downto 0);  -- 32 ways max
    pending    : std_ulogic;                    -- pending readout
    write      : std_ulogic;
    ram_r      : std_logic_vector(2 downto 0);

    v : std_ulogic; -- Data in diag interface is valid

    cl  : std_logic_vector(linesize * 8 - 1 downto 0);
    tag : std_logic_vector(31 downto 0);
  end record;
  constant DIAG_RES : diag_type := ((others => '0'), (others => '0'), '0', '0', (others => '0'), '0', (others => '0'), (others => '0'));

  type flush_ctrl_type is record
    tag   : std_logic_vector(TAG_R);
    index : std_logic_vector(INDEX_R);
    mode  : std_logic_vector(2 downto 0); -- 000 = flush, 001 = flush-invalidate, 010 = invalidate, 011 = flush addr, 100 = flush addr + invalidate
    en    : std_ulogic;
  end record;

  type flush_type is record
    way       : std_logic_vector(log2ext(ways) - 1 downto 0);
    index     : std_logic_vector(INDEX_R);
    ram_r     : std_logic_vector(2 downto 0);
    buf_valid : std_ulogic;
    tag_valid : std_ulogic;
  end record;

  constant FLUSH_RES : flush_ctrl_type := ((others => '0'), (others => '0'), "000", '0');

  type evict_type is record
    buf  : std_logic_vector(linesize * 8 - 1 downto 0);
    addr : std_logic_vector(31 downto 0);
    size : std_logic_vector(bmrd_size'length - 1 downto 0);
    v    : std_ulogic;
  end record;

  type io_reg_type is record
    acc_cnt    : std_logic_vector(31 downto 0);
    miss_cnt   : std_logic_vector(31 downto 0);
    flush_ctrl : flush_ctrl_type;
    ctrl       : cache_ctrl_type;
  end record;

  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_L2CL, 0, 1, 0),
    4 => gen_pnp_bar(haddr, hmask, 2, 1, 1),
    5 => gen_pnp_bar(ioaddr, IO_ADDR_MASK, 1, 0, 0),

    others => zero32
  );

  type reg_type is record
    control_state : state_type;
    bw_state      : bw_state_type;
    hsel          : std_logic_vector(0 to NAHBSLV - 1);
    haddr         : std_logic_vector(31 downto 0);
    hready        : std_ulogic;
    hrdata        : std_logic_vector(127 downto 0);
    hwdata        : std_logic_vector(AHBDW - 1 downto 0);
    hwrite        : std_ulogic;
    htrans        : std_logic_vector(1 downto 0);
    hsize         : std_logic_vector(2 downto 0);
    hburst        : std_logic_vector(2 downto 0);
    hmbsel        : std_logic_vector(0 to 3);
    hresp         : std_logic_vector(1 downto 0);

    ram_addr     : std_logic_vector(INDEX_R);
    wb_mask      : std_logic_vector(0 to linesize - 1);
    write_buffer : std_logic_vector(linesize * 8 - 1 downto 0);
    tdatain      : std_logic_vector(TAG_R);
    cl_status    : std_logic_vector(1 downto 0);
    cdatain      : std_logic_vector(linesize * 8 - 1 downto 0);
    cl_buffer    : cache_data_t;
    tl_buffer    : tag_data_t;
    bm_counter   : std_logic_vector(log2ext(linesize * 8/bm_dw_l) - 1 downto 0);
    evict        : evict_type;
    bp_acc       : std_ulogic;
    reg          : io_reg_type;
    flush        : flush_type;
    diag         : diag_type;
    fstage       : std_ulogic;
    pr_counter   : integer range 0 to ways;
    rep_index    : integer range 0 to ways - 1;

    plru_data : plru_data_t;

    w_en      : std_logic_vector(0 to ways - 1);
    tag_match : tag_match_ret_type;
  end record;

  ----------------------- FUNCTIONS -------------------------------

  ---- FUNCTION DESCRIPTION:
  --          Compares incomming accesses tag and compares to what is present in the memory at that address index. If there is a match,
  --          and the valid bit is set to '1' we return the match index and a hit flag.
  function tag_match (tag_ways : tag_data_t; tag_request : std_logic_vector(tag_len - 1 downto 0)) return tag_match_ret_type is
    variable temp : tag_match_ret_type := (0, '0');
  begin
    for i in 0 to ways - 1 loop
      if tag_ways(i)(TAG_DATA_R) = tag_request and tag_ways(i)(VALID_BIT) = '1' then
        temp.index := i; -- HIT
        temp.hit   := '1';
        return(temp);
      end if;
    end loop;
    return(temp);
  end;

  function data_mux(cacheline : std_logic_vector(linesize * 8 - 1 downto 0); addr : std_logic_vector(31 downto 0); size : std_logic_vector(2 downto 0)) return std_logic_vector is
    variable hrdata : std_logic_vector(127 downto 0);
    variable temp   : std_logic_vector(127 downto 0);
  begin
    temp   := (others => '0');
    hrdata := (others => '0');

    if linesize = 64 then
      case addr(5 downto 4) is
        when "00"   => temp   := cacheline(511 downto 384);
        when "01"   => temp   := cacheline(383 downto 256);
        when "10"   => temp   := cacheline(255 downto 128);
        when others => temp := cacheline(127 downto 0);
      end case;
    else
      if addr(4) = '0' then
        temp := cacheline(255 downto 128);
      else
        temp := cacheline(127 downto 0);
      end if;
    end if;

    if size = "100" then -- 128-bit 
      hrdata := temp(127 downto 0);
    elsif size = "011" then -- 64-bit 
      if addr(3) = '0' then
        hrdata := temp(127 downto 64) & temp(127 downto 64);
      else
        hrdata := temp(63 downto 0) & temp(63 downto 0);
      end if;
    else -- 32/16/8-bit
      case addr(3 downto 2) is
        when "00"   => hrdata   := temp(127 downto 96) & temp(127 downto 96) & temp(127 downto 96) & temp(127 downto 96);
        when "01"   => hrdata   := temp(95 downto 64) & temp(95 downto 64) & temp(95 downto 64) & temp(95 downto 64);
        when "10"   => hrdata   := temp(63 downto 32) & temp(63 downto 32) & temp(63 downto 32) & temp(63 downto 32);
        when others => hrdata := temp(31 downto 0) & temp(31 downto 0) & temp(31 downto 0) & temp(31 downto 0);
      end case;
    end if;

    return(hrdata);
  end; -- data_mux

  function direct_read_data_mux(cacheline : std_logic_vector(linesize * 8 - 1 downto 0); size : std_logic_vector(2 downto 0)) return std_logic_vector is
    variable hrdata : std_logic_vector(127 downto 0);
    variable temp   : std_logic_vector(127 downto 0);
  begin
    case size is
      when "000" => -- B
        for i in 0 to AHBDW/8 - 1 loop
          hrdata(AHBDW - (8 * i) - 1 downto AHBDW - (8 * (i + 1))) := cacheline(linesize * 8 - 1 downto linesize * 8 - 8);
        end loop;
      when "001" => -- 2B
        for i in 0 to AHBDW/16 - 1 loop
          hrdata(AHBDW - (16 * i) - 1 downto AHBDW - (16 * (i + 1))) := cacheline(linesize * 8 - 1 downto linesize * 8 - 16);
        end loop;
      when "010" => -- 4B
        for i in 0 to AHBDW/32 - 1 loop
          hrdata(AHBDW - (32 * i) - 1 downto AHBDW - (32 * (i + 1))) := cacheline(linesize * 8 - 1 downto linesize * 8 - 32);
        end loop;
      when "011" => -- 8B
        if AHBDW > 32 then
          hrdata := cacheline(linesize * 8 - 1 downto linesize * 8 - 64) & cacheline(linesize * 8 - 1 downto linesize * 8 - 64);
        end if;
      when others => -- 16B
        if AHBDW > 64 then
          hrdata := cacheline(linesize * 8 - 1 downto linesize * 8 - 128);
        end if;
    end case;

    return(hrdata);
  end; -- data_mux

  function plru_update (iplru : std_logic_vector(0 to ways - 2); hit_index : integer) return std_logic_vector is
    variable index : integer range 0 to ways - 1;
    variable oplru : std_logic_vector(0 to ways - 2);
  begin
    oplru := iplru;
    index := hit_index / 2 + (ways/2 - 1);
    oplru(index) := conv_std_logic((hit_index rem 2) = 1);
    for i in 1 to log2ext(ways - 1) loop
      oplru(index) := conv_std_logic((index rem 2) = 0);
      if (index rem 2) = 0 then
        index := index/2 - 1;
      else
        index := index/2;
      end if;
    end loop;
    return oplru;
  end plru_update;

  function plru_evict(plru_data : std_logic_vector(0 to ways - 2)) return integer is
    variable index  : integer range 0 to ways - 1;
  begin
    index := 0;
    for i in 1 to log2ext(ways - 1) loop
      index := 2 * index + 1 + to_integer(unsigned(not plru_data(index to index)));
    end loop;
    return 2 * (index - (ways/2 - 1)) + to_integer(unsigned(not plru_data(index to index)));
  end plru_evict;

  signal w_en : std_logic_vector(0 to ways - 1);
  signal r_en : std_ulogic;

  signal rwaddr : std_logic_vector(addr_depth - 1 downto 0);

  signal tagdatain    : std_logic_vector(tag_dbits - 1 downto 0);
  signal cachedatain  : std_logic_vector(linesize * 8 - 1 downto 0);
  signal tagdataout   : tag_data_t;
  signal cachedataout : cache_data_t;

  signal r, rin : reg_type;
  signal obm_out : obm_out_type;

begin

  ---- GENERATE SYNCRAM FOR TAG DATA ----
  tag_ram_gen : for i in 0 to ways - 1 generate
    tag_ram : syncram_2p
    generic map(
      tech     => tech,
      abits    => addr_depth,
      dbits    => tag_dbits,
      sepclk   => 0,
      wrfst    => 0,
      testen   => 0,
      pipeline => 0)
    port map(
      rclk     => clk,
      renable  => r_en,
      raddress => rwaddr,
      dataout  => tagdataout(i),
      wclk     => clk,
      write    => w_en(i),
      waddress => rwaddr,
      datain   => tagdatain);
  end generate;

  ---- GENERATE SYNCRAM FOR CACHE DATA ----
  cache_ram_gen : for i in 0 to ways - 1 generate
    cache_ram : syncram_2p
    generic map(
      tech     => tech,
      abits    => addr_depth,
      dbits    => linesize * 8,
      sepclk   => 0,
      wrfst    => 0,
      testen   => 0,
      pipeline => 0)
    port map(
      rclk     => clk,
      renable  => r_en,
      raddress => rwaddr,
      dataout  => cachedataout(i),
      wclk     => clk,
      write    => w_en(i),
      waddress => rwaddr,
      datain   => cachedatain);
  end generate;

  -- signal assignments
  -- READ SIGNALS
  obm_out.bmrd_req_granted <= bmrd_req_granted;
  obm_out.bmrd_data        <= bmrd_data;
  obm_out.bmrd_valid       <= bmrd_valid;
  obm_out.bmrd_done        <= bmrd_done;
  obm_out.bmrd_error       <= bmrd_error;
  -- WRITE SIGNALS
  obm_out.bmwr_full        <= bmwr_full;
  obm_out.bmwr_done        <= bmwr_done;
  obm_out.bmwr_error       <= bmwr_error;
  obm_out.bmwr_req_granted <= bmwr_req_granted;
  
  comb : process (r, ahbsi, rstn, obm_out, tagdataout, cachedataout)
    variable v                            : reg_type;
    variable access_trigger, miss_trigger : std_ulogic;
    variable oahbso                       : ahb_slv_out_type;
    variable obm_in                       : obm_in_type;
    variable counter                      : integer range 0 to AHBDW/8;
    variable c_offset                     : integer range 0 to linesize - 1;
    variable haddr_incr                   : std_logic_vector(31 downto 0);
    variable data                         : std_logic_vector(31 downto 0);
    variable hwdata                       : std_logic_vector(AHBDW - 1 downto 0);
    variable writeback                    : std_ulogic;
    variable cachemiss                    : std_ulogic;
    variable way                          : integer range 0 to ways - 1;

  procedure update_reg(addr : std_logic_vector(7 downto 2);
                      wr    : std_ulogic;
                      wdata : std_logic_vector;
                      rdata : out std_logic_vector(127 downto 0)) is
    variable ordata : std_logic_vector(31 downto 0);
  begin

    ordata := (others => '0');
    case addr(7 downto 2) is
      when "000000" => -- Config 
        ordata := conv_std_logic_vector(repl, 2) & "00" & conv_std_logic_vector(ways - 1, 8) &
                  conv_std_logic_vector(log2ext(linesize) - 4, 4) & "00" & conv_std_logic_vector(waysize, 14);
      when "000001" => -- Ctrl 
        ordata(0) := r.reg.ctrl.en;
        ordata(1) := r.reg.ctrl.repl;
        if r.hwrite = '1' then
          v.reg.ctrl.en   := wdata(0);
          if repl = 1 then 
            v.reg.ctrl.repl := wdata(1);
          end if;
        end if;
      when "000010" => -- flush
        ordata(0)          := r.reg.flush_ctrl.en;
        ordata(3 downto 1) := r.reg.flush_ctrl.mode;
        ordata(INDEX_R)    := r.reg.flush_ctrl.index;
        ordata(TAG_R)      := r.reg.flush_ctrl.tag;
        if r.hwrite = '1' then
          v.reg.flush_ctrl.en    := wdata(0);
          v.reg.flush_ctrl.mode  := wdata(3 downto 1);
          v.reg.flush_ctrl.index := wdata(INDEX_R);
          v.reg.flush_ctrl.tag   := wdata(TAG_R);
        end if;
      when "000011" => -- Access counter
        ordata := r.reg.acc_cnt;
        if r.hwrite = '1' then
          v.reg.acc_cnt := wdata(31 downto 0);
        end if;
      when "000100" => -- Miss counter
        ordata := r.reg.miss_cnt;
        if r.hwrite = '1' then
          v.reg.miss_cnt := wdata(31 downto 0);
        end if;
      when "000101" => -- Diagnostics Control
        ordata(31 downto 16) := r.diag.read_index;
        ordata(12 downto 8)  := r.diag.read_way;
        ordata(2)            := r.diag.write;
        ordata(1)            := r.diag.pending;
        ordata(0)            := r.diag.v;
        if r.hwrite = '1' then
          v.diag.read_index := wdata(31 downto 16);
          v.diag.read_way   := wdata(12 downto 8);
          v.diag.write      := wdata(2);
          v.diag.pending    := wdata(1);
          v.diag.v          := '0';
        end if;
      when "010000" | "010001" | "010010" | "010011" |
           "010100" | "010101" | "010110" | "010111" |
           "011000" | "011001" | "011010" | "011011" |
           "011100" | "011101" | "011110" | "011111" => -- Diagnostics Data
        for i in 0 to 8 * (linesize/32) - 1 loop
          if to_integer(unsigned(addr(5 downto 2))) = i then
            ordata := r.diag.cl(32 * (i + 1) - 1 downto 32 * i);
          end if;
        end loop;
        if r.hwrite = '1' then
          for i in 0 to 8 * (linesize/32) - 1 loop
            if to_integer(unsigned(addr(5 downto 2))) = i then
              v.diag.cl(32 * (i + 1) - 1 downto 32 * i) := wdata(31 downto 0);
            end if;
          end loop;
        end if;

      when "100000" => -- Diagnostics Tag
        ordata := r.diag.tag;
        if r.hwrite = '1' then
          v.diag.tag := wdata(31 downto 0);
        end if;
      when others => null;
    end case;
    rdata := ordata & ordata & ordata & ordata;
  end update_reg;

begin
  v := r;
  ---- SAMPLE FRONTEND BUS ----

  oahbso.hconfig := hconfig;
  oahbso.hindex  := hsindex;
  oahbso.hirq    := (others => '0');
  oahbso.hsplit  := (others => '0');
  oahbso.hresp   := r.hresp;
  oahbso.hready  := r.hready;
  oahbso.hrdata  := ahbdrivedata(r.hrdata);
  ---- BACKEND ----
  obm_in.bmrd_req  := '0';
  obm_in.bmrd_addr := (others => '0');
  obm_in.bmrd_size := (others => '0');
  obm_in.bmwr_req  := '0';
  obm_in.bmwr_addr := (others => '0');
  obm_in.bmwr_size := (others => '0');
  obm_in.bmwr_data := (others => '0');

  v.w_en := (others => '0');
  r_en <= '0';
  data           := (others => '0');
  v.fstage       := '0';
  way            := 0;
  cachemiss      := '0';
  writeback      := '0';
  access_trigger := '0';
  miss_trigger   := '0';
  counter        := 0;

  if ahbsi.hready = '1' then
    v.htrans := ahbsi.htrans;
    v.haddr  := ahbsi.haddr;
    v.hsize  := ahbsi.hsize;
    v.hwrite := ahbsi.hwrite;
    v.hburst := ahbsi.hburst;
    v.hmbsel := ahbsi.hmbsel;
    if (ahbsi.htrans(1) and ahbsi.hsel(hsindex)) = '1' then
      v.hready := '0';
      v.hresp  := "00";
    end if;
  end if;
  hwdata := ahbsi.hwdata;

  case r.control_state is
    when IDLE_S =>
      v.ram_addr := v.haddr(INDEX_R);
      v.wb_mask  := (others => '0');
      v.bp_acc   := '0';

      if r.hready = '0' then
        if r.w_en = zero32(ways - 1 downto 0) and r.hmbsel(0) = '1' then
          r_en <= '1';
          if is_cachable(r.haddr(31 downto 28), conv_std_logic_vector(cached, 16)) and r.reg.ctrl.en = '1' then
            v.control_state := TAG_MATCH_1_S;
          else ---- ADDRESS NOT CACHABLE ----
            v.bp_acc := '1';
            if r.hwrite = '0' then
              v.control_state := BACKEND_READ_S;
              v.evict.size    := conv_std_logic_vector(size_vector_to_int(r.hsize) - 1, bmrd_size'length);
            else
              v.control_state := DIRECT_WRITE_S;
              v.hwdata        := ahbsi.hwdata;
            end if;
          end if;
        elsif r.hmbsel(1) = '1' then -- Register interface    
          v.hready := '1';
          case r.haddr(7 downto 2) is
            when "000000" => -- Config 
              data := conv_std_logic_vector(repl, 2) & "00" & conv_std_logic_vector(ways - 1, 8) &
                conv_std_logic_vector(log2ext(linesize) - 4, 4) & "00" & conv_std_logic_vector(waysize, 14);
            when "000001" => -- Ctrl 
              data(0) := r.reg.ctrl.en;
              data(1) := r.reg.ctrl.repl;
              if r.hwrite = '1' then
                v.reg.ctrl.en   := hwdata(0);
                if repl = 1 then 
                  v.reg.ctrl.repl := hwdata(1);
                end if;
              end if;
            when "000010" => -- flush
              data(0)          := r.reg.flush_ctrl.en;
              data(3 downto 1) := r.reg.flush_ctrl.mode;
              data(INDEX_R)    := r.reg.flush_ctrl.index;
              data(TAG_R)      := r.reg.flush_ctrl.tag;
              if r.hwrite = '1' then
                v.reg.flush_ctrl.en    := hwdata(0);
                v.reg.flush_ctrl.mode  := hwdata(3 downto 1);
                v.reg.flush_ctrl.index := hwdata(INDEX_R);
                v.reg.flush_ctrl.tag   := hwdata(TAG_R);
              end if;
            when "000011" => -- Access counter
              data := r.reg.acc_cnt;
              if r.hwrite = '1' then
                v.reg.acc_cnt := hwdata(31 downto 0);
              end if;
            when "000100" => -- Miss counter
              data := r.reg.miss_cnt;
              if r.hwrite = '1' then
                v.reg.miss_cnt := hwdata(31 downto 0);
              end if;
            when "000101" => -- Diagnostics Control
              data(31 downto 16) := r.diag.read_index;
              data(12 downto 8)  := r.diag.read_way;
              data(2)            := r.diag.write;
              data(1)            := r.diag.pending;
              data(0)            := r.diag.v;
              if r.hwrite = '1' then
                v.diag.read_index := hwdata(31 downto 16);
                v.diag.read_way   := hwdata(12 downto 8);
                v.diag.write      := hwdata(2);
                v.diag.pending    := hwdata(1);
                v.diag.v          := '0';
              end if;
            when "010000" | "010001" | "010010" | "010011" |
                 "010100" | "010101" | "010110" | "010111" |
                 "011000" | "011001" | "011010" | "011011" |
                 "011100" | "011101" | "011110" | "011111" => -- Diagnostics Data
              for i in 0 to 8 * (linesize/32) - 1 loop
                if to_integer(unsigned(r.haddr(5 downto 2))) = (linesize/32)*8 - 1 - i then
                  data := r.diag.cl(32 * (i + 1) - 1 downto 32 * i);
                end if;
              end loop;
              if r.hwrite = '1' then
                for i in 0 to 8 * (linesize/32) - 1 loop
                  if to_integer(unsigned(r.haddr(5 downto 2))) = (linesize/32)*8 - 1 - i then
                    v.diag.cl(32 * (i + 1) - 1 downto 32 * i) := hwdata(31 downto 0);
                  end if;
                end loop;
              end if;

            when "100000" => -- Diagnostics Tag
              data := r.diag.tag;
              if r.hwrite = '1' then
                v.diag.tag := hwdata(31 downto 0);
              end if;
            when others => null;
          end case;
          v.hrdata := data & data & data & data;
          --synth bug
          --update_reg(r.haddr(7 downto 2), r.hwrite, hwdata(31 downto 0), v.hrdata);
        end if;
      elsif r.reg.flush_ctrl.en = '1' then
        v.control_state   := FLUSH_S;
        v.flush.way       := (others => '0');
        v.flush.index     := (others => '0');
        v.flush.tag_valid := '0';
        v.flush.ram_r     := "000";
      elsif r.diag.pending = '1' then
        v.ram_addr      := r.diag.read_index(addr_depth - 1 downto 0);
        v.control_state := DIAG_S;
        if r.diag.write = '1' then
          v.diag.ram_r := "111";
        else
          v.diag.ram_r := "001";
        end if;
      end if;

    when TAG_MATCH_1_S =>
      v.control_state := TAG_MATCH_2_S;
    when TAG_MATCH_2_S =>
      v.tag_match := tag_match(tagdataout, r.haddr(TAG_R));
      v.cl_buffer := cachedataout;
      v.tl_buffer := tagdataout;
      v.fstage    := '1';
      if r.hwrite = '0' then
        v.control_state := READ_S;
      else
        v.control_state := WRITE_S;
      end if;

    when READ_S =>
      if r.tag_match.hit = '1' then -- Cache hit

        if repl = 1 and r.reg.ctrl.repl = '1' then
          v.plru_data(to_integer(unsigned(r.haddr(INDEX_R)))) := 
            plru_update(r.plru_data(to_integer(unsigned(r.haddr(INDEX_R)))), r.tag_match.index);
        end if;

        v.hready := '1';
        -- Mux out the correct data from cacheline
        v.hrdata := data_mux(r.cl_buffer(r.tag_match.index), r.haddr, r.hsize);
        if endianess = 1 then
          v.hrdata := reversedata(v.hrdata, 8);
        end if;

        haddr_incr := r.haddr + size_vector_to_int(r.hsize);
        if ahbsi.htrans = "11" then -- Check if last in cacheline
          if (haddr_incr(INDEX_R) = r.haddr(INDEX_R)) then
            v.haddr := haddr_incr;
          else -- Cacheline restart 
            v.control_state := IDLE_S;
          end if;
        elsif ahbsi.htrans = "10" then
          -- Detect if the next access is within the same cacheline, otherwise it is a B2B access,
          -- And we need to update htrans to handle it correctly.
          if ahbsi.haddr(31 downto INDEX_R'right) /= r.haddr(31 downto INDEX_R'right) then
            v.htrans := ahbsi.htrans;
          end if;
          -- If the first access in a burst is a 1KB crossing, 
          -- we still need to drive hready high
          if r.htrans = "11" then
            v.hready := '0';
          end if;
          v.control_state := IDLE_S;
          access_trigger  := '1';
        else
          v.control_state := IDLE_S;
          access_trigger  := '1';
        end if;
      else
        cachemiss := '1';
      end if;

    when WRITE_S =>
      if r.tag_match.hit = '1' then -- Cache hit

        if repl = 1 and r.reg.ctrl.repl = '1' then
          v.plru_data(to_integer(unsigned(r.haddr(INDEX_R)))) := 
            plru_update(r.plru_data(to_integer(unsigned(r.haddr(INDEX_R)))), r.tag_match.index);
        end if;

        v.hready := '1';
        if endianess = 1 then
          hwdata := reversedata(hwdata, 8);
        end if;

        c_offset := to_integer(unsigned(r.haddr(OFFSET_R)));
        for i in 0 to linesize - 1 loop
          if (i > (c_offset - 1)) and (i < (c_offset + size_vector_to_int(r.hsize))) then
            v.write_buffer(linesize * 8 - 8 * i - 1 downto linesize * 8 - 8 * (i + 1))
            := hwdata(AHBDW - 8 * counter - 1 downto AHBDW - 8 * (counter + 1));
            counter      := counter + 1;
            v.wb_mask(i) := '1';
          end if;
        end loop;

        haddr_incr := r.haddr + size_vector_to_int(r.hsize);

        if ahbsi.htrans = "11" then
          if (haddr_incr(INDEX_R) = r.haddr(INDEX_R)) then
            if r.fstage = '0' then
              v.haddr := haddr_incr;
            end if;
          else -- Cacheline restart 
            writeback := '1';
            -- If the first access in a burst is a cacheline restart or 1KB crossing, 
            -- we still need to drive hready high
            if r.htrans = "11" then
              v.hready := '0';
            end if;
          end if;
        elsif ahbsi.htrans = "10" then -- 1KB crossing or B2B
          -- Detect if the next access is within the same cacheline, otherwise it is a B2B access,
          -- And we need to update htrans to handle it correctly.
          if ahbsi.haddr(31 downto INDEX_R'right) /= r.haddr(31 downto INDEX_R'right) then
            v.htrans := ahbsi.htrans;
          end if;
          -- If the first access in a burst is a 1KB crossing, 
          -- we still need to drive hready high
          if r.htrans = "11" then
            v.hready := '0';
          end if;
          access_trigger := '1';
          writeback      := '1';
        else
          access_trigger := '1';
          writeback      := '1';
        end if;

        if writeback = '1' then
          v.cdatain := r.cl_buffer(r.tag_match.index);
          for i in 0 to linesize - 1 loop
            if v.wb_mask(i) = '1' then
              v.cdatain(linesize * 8 - 8 * i - 1 downto linesize * 8 - 8 * (i + 1)) :=
              v.write_buffer(linesize * 8 - 8 * i - 1 downto linesize * 8 - 8 * (i + 1));
            end if;
          end loop;

          v.tdatain                 := r.haddr(TAG_R);
          v.cl_status(DIRTY_BIT)    := '1';
          v.cl_status(VALID_BIT)    := '1';
          v.w_en(r.tag_match.index) := '1';
          v.control_state           := IDLE_S;
        end if;

      else -- Cache miss
        cachemiss := '1';
      end if;

    when BACKEND_READ_S =>

      if obm_out.bmrd_req_granted = '1' then
        obm_in.bmrd_req  := '1';
        obm_in.bmrd_size := r.evict.size;
        obm_in.bmrd_addr := r.haddr;
        if r.bp_acc = '0' then
          obm_in.bmrd_addr(OFFSET_R) := (others => '0');
        end if;
        v.bm_counter := (others => '0');
      elsif obm_out.bmrd_valid = '1' then

        if linesize*8 <= bm_dw_l then 
          v.cdatain := obm_out.bmrd_data(bm_dw_l - 1 downto bm_dw_l - linesize*8);
        else 
          v.cdatain(linesize * 8 - bm_dw_l * to_integer(unsigned(r.bm_counter)) - 1
          downto linesize * 8 - bm_dw_l * (1 + to_integer(unsigned(r.bm_counter)))) := obm_out.bmrd_data;
        end if;

        if obm_out.bmrd_done = '0' then
          v.bm_counter := r.bm_counter + 1;
        else
          if r.bp_acc = '0' then
            v.w_en(r.rep_index) := '1';
            v.control_state     := IDLE_S;
          else
            v.control_state := DIRECT_READ_S;
          end if;
        end if;
      end if;

    when DIRECT_READ_S =>
      v.hrdata := direct_read_data_mux(r.cdatain, r.hsize);
      if endianess = 1 then
        v.hrdata := reversedata(v.hrdata, 8);
      end if;
      v.hready        := '1';
      v.control_state := IDLE_S;

    when DIRECT_WRITE_S =>
      if endianess = 1 then
        hwdata := reversedata(hwdata, 8);
      end if;
      if r.bw_state = IDLE_S then
        for i in 0 to 128/AHBDW - 1 loop
          v.evict.buf(linesize * 8 - 1 - AHBDW * i downto linesize * 8 - AHBDW * (i + 1)) := hwdata;
        end loop;

        v.evict.addr    := r.haddr;
        v.evict.size    := conv_std_logic_vector(size_vector_to_int(r.hsize) - 1, bmrd_size'length);
        v.evict.v       := '1';
        v.hready        := '1';
        v.control_state := IDLE_S;
      end if;

    when FLUSH_S =>
      case r.reg.flush_ctrl.mode is
        when "000" | "001" => -- Flush/Flush-Invalidate
          if r.flush.ram_r = "000" then
            v.control_state := FLUSH_READ_S;
            v.ram_addr      := r.flush.index;
            v.flush.ram_r   := "001";
            v.flush.way     := (others => '0');
          end if;

          way := to_integer(unsigned(r.flush.way));
          if (r.flush.buf_valid and not r.evict.v) = '1' then
            if r.tl_buffer(way)(1) = '1' then -- Valid and Dirty, flush the line
              v.evict.addr          := (others => '0');
              v.evict.addr(INDEX_R) := r.flush.index;
              v.evict.addr(TAG_R)   := r.tl_buffer(way)(TAG_DATA_R);
              v.evict.buf           := r.cl_buffer(way);
              v.evict.size          := conv_std_logic_vector(linesize - 1, bmrd_size'length);
              v.evict.v             := r.tl_buffer(way)(0);

              v.cdatain              := r.cl_buffer(way);
              v.tdatain              := r.tl_buffer(way)(TAG_DATA_R);
              v.cl_status(VALID_BIT) := not r.reg.flush_ctrl.mode(0);
              v.cl_status(DIRTY_BIT) := '0';
              v.w_en(way)            := '1';
            end if;

            -- increment way counter
            v.flush.way := std_logic_vector(unsigned(r.flush.way) + 1);
            if v.flush.way = zero32(log2ext(ways) - 1 downto 0) then
              v.flush.buf_valid := '0';
              v.flush.ram_r     := "000";
              v.flush.index     := std_logic_vector(unsigned(r.flush.index) + 1);
            end if;

            -- Exit flush
            if v.flush.index = zero32(INDEX_R) and r.flush.index /= zero32(INDEX_R) then
              v.control_state     := IDLE_S;
              v.reg.flush_ctrl.en := '0';
            end if;
          end if;

        when "010"                        => -- Invalidate
          v.w_en                 := (others => '1');
          v.ram_addr             := r.flush.index;
          v.cl_status(VALID_BIT) := '0';
          v.flush.index          := std_logic_vector(unsigned(r.flush.index) + 1);
          if v.flush.index = zero32(INDEX_R) and r.flush.index /= zero32(INDEX_R) then
            v.control_state     := IDLE_S;
            v.reg.flush_ctrl.en := '0';
          end if;

        when "011" | "100" => -- Flush-Address / Flush-Address + invalidate
          if r.flush.ram_r = "000" then
            v.ram_addr      := r.reg.flush_ctrl.index;
            v.flush.ram_r   := "001";
            v.control_state := FLUSH_READ_S;
          end if;

          if r.flush.buf_valid = '1' then
            v.tag_match       := tag_match(tagdataout, r.reg.flush_ctrl.tag);
            v.flush.tag_valid := '1';
            v.flush.buf_valid := '0';
          end if;

          if (not r.evict.v and r.flush.tag_valid) = '1' then
            if r.tag_match.hit = '1' then
              v.cdatain              := r.cl_buffer(r.tag_match.index);
              v.tdatain              := r.tl_buffer(r.tag_match.index)(TAG_DATA_R);
              v.cl_status(VALID_BIT) := not r.reg.flush_ctrl.mode(2);
              v.cl_status(DIRTY_BIT) := '0';

              v.w_en(r.tag_match.index) := '1';

              if r.tl_buffer(r.tag_match.index)(1) = '1' then
                v.evict.addr          := (others => '0');
                v.evict.addr(INDEX_R) := r.reg.flush_ctrl.index;
                v.evict.addr(TAG_R)   := r.reg.flush_ctrl.tag;
                v.evict.buf           := r.cl_buffer(r.tag_match.index);
                v.evict.size          := conv_std_logic_vector(linesize - 1, bmrd_size'length);
                v.evict.v             := r.tl_buffer(r.tag_match.index)(0);
              end if;
            end if;
            v.control_state     := IDLE_S;
            v.reg.flush_ctrl.en := '0';
          end if;
        when others =>
          v.reg.flush_ctrl.en := '0';
          v.control_state     := IDLE_S;
      end case;

    when FLUSH_READ_S =>
      -- set read_en
      v.flush.ram_r(2 downto 1) := r.flush.ram_r(1 downto 0);
      if r.flush.ram_r = "001" then
        r_en <= '1';
      end if;

      if r.flush.ram_r(2) = '1' then
        v.cl_buffer       := cachedataout;
        v.tl_buffer       := tagdataout;
        v.flush.buf_valid := '1';
        v.control_state   := FLUSH_S;
      end if;

    when DIAG_S =>
      v.diag.ram_r(2 downto 1) := r.diag.ram_r(1 downto 0);
      way             := to_integer(unsigned(r.diag.read_way(log2ext(ways) - 1 downto 0)));
      if r.diag.ram_r = "001" then 
        r_en <= '1';
      end if;
      if r.diag.ram_r = "111" then
        if r.diag.write = '1' then
          v.cdatain   := r.diag.cl;
          v.tdatain   := r.diag.tag(tag_dbits - 1 downto 2);
          v.cl_status := r.diag.tag(1 downto 0);
          v.w_en(way) := '1';
        else
          v.diag.cl                          := cachedataout(way);
          v.diag.tag(tag_dbits - 1 downto 0) := tagdataout(way);
          v.diag.v                           := '1';
        end if;
        v.diag.pending  := '0';
        v.control_state := IDLE_S;
      end if;

    when others => null;
  end case;
  ---- BACKEND EVICTION INTERFACE ----
  case r.bw_state is
    when IDLE_S =>

      if (r.evict.v = '1' and r.control_state /= BACKEND_READ_S) then
        v.bw_state := BACKEND_WRITE_S;
      end if;

    when BACKEND_WRITE_S =>
      if obm_out.bmwr_req_granted = '1' then
        obm_in.bmwr_req  := '1';
        obm_in.bmwr_addr := r.evict.addr;
        obm_in.bmwr_size := r.evict.size;
        v.bm_counter     := (others => '0');
      end if;
      if obm_out.bmwr_full = '0' then
        v.bm_counter := r.bm_counter + 1;
      end if;

      if linesize*8 <= bm_dw_l then 
        obm_in.bmwr_data(bm_dw_l - 1 downto bm_dw_l - linesize*8) := r.evict.buf;
      else 
        obm_in.bmwr_data := r.evict.buf(linesize * 8 - bm_dw_l * to_integer(unsigned(v.bm_counter)) - 1
        downto linesize * 8 - bm_dw_l * (1 + to_integer(unsigned(v.bm_counter))));
      end if;

      if obm_out.bmwr_done = '1' then
        v.bw_state := IDLE_S;
        v.evict.v  := '0';
      end if;

    when others => null;
  end case;

  -- Cache miss triggered in READ & WRITE state
  if r.bw_state = IDLE_S and cachemiss = '1' then
    if repl = 1 and r.reg.ctrl.repl = '1' then ---- Plru ----
      v.rep_index := plru_evict(r.plru_data(to_integer(unsigned(r.haddr(INDEX_R)))));
    else ---- P_RANDOM ----
      v.rep_index := r.pr_counter;
    end if;
    v.tdatain              := r.haddr(TAG_R);
    v.cl_status(DIRTY_BIT) := '0';
    v.cl_status(VALID_BIT) := '1';

    if r.tl_buffer(v.rep_index)(1 downto 0) = "11" then
      v.evict.buf           := r.cl_buffer(v.rep_index);
      v.evict.addr          := (others => '0');
      v.evict.addr(TAG_R)   := r.tl_buffer(v.rep_index)(TAG_DATA_R);
      v.evict.addr(INDEX_R) := r.haddr(INDEX_R);
      v.evict.v             := '1';
    end if;

    v.control_state := BACKEND_READ_S;
    v.evict.size    := conv_std_logic_vector(linesize - 1, bmrd_size'length);
    miss_trigger    := '1';
  end if;

  ---- counters ----
  if access_trigger = '1' then
    v.reg.acc_cnt     := std_logic_vector(unsigned(r.reg.acc_cnt) + 1);
    v.reg.acc_cnt(31) := v.reg.acc_cnt(31) or r.reg.acc_cnt(31);
  end if;
  if miss_trigger = '1' then
    v.reg.miss_cnt    := std_logic_vector(unsigned(r.reg.miss_cnt) + 1);
    v.reg.acc_cnt(31) := v.reg.acc_cnt(31) or r.reg.acc_cnt(31);
  end if;

  -- Invalidate data in diag interface if a write is made to the cacheline
  if r.ram_addr = r.diag.read_index and
    r.w_en(to_integer(unsigned(r.diag.read_way(log2ext(ways) - 1 downto 0)))) = '1'
    then
    v.diag.v := '0';
  end if;

  ---- PSEUDO RANDOM COUNTER ----
  v.pr_counter := r.pr_counter + 1;
  if r.pr_counter = ways - 1 then
    v.pr_counter := 0;
  end if;

  if repl = 0 then
    v.plru_data := (others => (others => '0'));
  end if;

  -- RAM address & Data inputs
  tagdatain(1 downto 0) <= r.cl_status;
  tagdatain(TAG_DATA_R) <= r.tdatain;
  cachedatain           <= r.cdatain;
  rwaddr                <= r.ram_addr;

  w_en <= r.w_en;

  --------  OUTPUTS  --------
  bmrd_req  <= obm_in.bmrd_req;
  bmrd_addr <=  obm_in.bmrd_addr;
  bmrd_size <= obm_in.bmrd_size;
  bmwr_req  <= obm_in.bmwr_req;
  bmwr_addr <= obm_in.bmwr_addr;
  bmwr_size <= obm_in.bmwr_size;
  bmwr_data <=  obm_in.bmwr_data;  
  ahbso <= oahbso;

  rin <= v;

end process;

regs : process (clk, rstn)
begin
  if rising_edge(clk) then
    if rstn = '0' then
      r.hready        <= '1';
      r.reg.ctrl.en   <= '1';
      r.reg.ctrl.repl <= '1';
      r.plru_data     <= (others => (others => '0'));

      r.diag           <= DIAG_RES;
      r.reg.flush_ctrl <= FLUSH_RES;
      r.control_state  <= IDLE_S;
      r.bw_state       <= IDLE_S;
      r.bp_acc         <= '0';
      r.evict.v        <= '0';
      r.reg.acc_cnt    <= (others => '0');
      r.reg.miss_cnt   <= (others => '0');
    else
      r <= rin;
    end if;
  end if;
end process;

end architecture rtl;
