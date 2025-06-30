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
-------------------------------------------------------------------------------
-- Entity:      axi2ahb
-- File:        axi2ahb.vhd
-- Author:      Carl Ehrenstrahle
-- Description: AMBA AXI4 to AHB bridge
-------------------------------------------------------------------------------

-- Fixed and Wrapped burst operations are not supported

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;

library techmap;
use techmap.gencomp.all;

library gaisler;
use gaisler.axi.all;

entity axi2ahb is
  generic(
    memtech     : integer               := 0;
    hindex      : integer               := 0;
    dbuffer     : integer range 4 to 256 := 4; -- Read data buffer depth
    wordsize    : integer               := AHBDW; -- Actual bus data width
    axi_endian  : integer range 0 to 1  := 0; -- 0: BE, 1: LE
    -- "Inverts" the addresses of accesses that are narrower than the bus width.
    -- E.g. a 16-bit access on a 32-bit bus. The address provided via AXI is 0x0.
    -- The resulting address would in this case become 0x2. This can be useful on big endian systems.
    sub_bus_width_address_inversion : integer range 0 to 1 := 0;
    mask        : integer               := 16#000#;
    vendorid    : integer               := VENDOR_GAISLER;
    deviceid    : integer               := GAISLER_AXI2AHB;
    scantest    : integer               := 0;
    memory_ft   : integer               := 0 -- Memory fault tolerance
  );
  port(
    resetn  : in  std_ulogic;
    clk     : in  std_ulogic;
    axisi   : in  axi4_mosi_type;
    axiso   : out axi_somi_type;
    ahbmi   : in  ahb_mst_in_type;
    ahbmo   : out ahb_mst_out_type
  );
end entity;

architecture rtl of axi2ahb is
  constant RRESP_OKAY   : std_logic_vector(1 downto 0) := "00";
  constant RRESP_EXOKAY : std_logic_vector(1 downto 0) := "01";
  constant RRESP_SLVERR : std_logic_vector(1 downto 0) := "10";
  constant RRESP_DECERR : std_logic_vector(1 downto 0) := "11";

  function to_sl(a : natural) return std_logic is
  begin
    if a > 0 then return '1'; else return '0'; end if;
  end function;

  function to_sl(a : boolean) return std_logic is
  begin
    if a then return '1'; else return '0'; end if;
  end function;

  function min(a, b : std_logic_vector) return std_logic_vector is
  begin
    if unsigned(a) < unsigned(b) then return a; else return b; end if;
  end function;

  function find_first_one(a : std_logic_vector) return integer is
    variable r : integer := -1;
  begin
    for i in a'low to a'high loop
      if a(i) = '1' then
        r := i;
        exit;
      end if;
    end loop;
    return r;
  end function;

  -- Function that swaps the byte positions for a given vector
  function byte_swap (
    data_in : std_logic_vector)
    return std_logic_vector is
    variable data       : std_logic_vector(data_in'high-data_in'low downto 0);
    variable data_align : std_logic_vector(data_in'high-data_in'low downto 0);
  begin
    data_align := data_in(data_in'high downto data_in'low);

    for i in 0 to (data_align'length/8)-1 loop
      data((i+1)*8-1 downto i*8) :=
        data_align(data_align'left-(i*8) downto data_align'length-((i+1)*8));
    end loop;  -- i

    return data;
  end byte_swap;

  function mirror_vector(a : std_logic_vector) return std_logic_vector is
    variable r : std_logic_vector(a'length - 1 downto 0);
  begin
    for i in 0 to a'length - 1 loop
      r(i) := a(a'high - i);
    end loop;
    return r;
  end function;

  -- Finds the start of the next group of ones in a vector.
  -- 0 means no more clusters.
  function find_next_cluster(a : std_logic_vector) return natural is
    variable r : natural;
    variable in_cluster : boolean;
  begin
    r := 0;
    -- Are we starting off in a cluster of ones?
    in_cluster := a(a'low) = '1';
    -- assume downto
    for i in a'low to a'high loop
      if a(i) = '1' then
        if in_cluster then
          r := r + 1;
        else
          return r;
        end if;
      else
        in_cluster := false;
        r := r + 1;
      end if;
    end loop;
    return 0;
  end function;

  function get_cluster_length(a : std_logic_vector; offset : natural) return natural is
    variable r : natural := 0;
  begin
    -- assume downto and starting at cluster
    for i in a'low to a'high loop
      if i >= a'low + offset then
        if a(i) = '1' then
          r := r + 1;
        else
          exit;
        end if;
      end if;
    end loop;
    return r;
  end function;

  -- Returns the bit offset of the strobe matching the size and address offset.
  function get_strobe_offset(address : std_logic_vector;
                             strb_width : positive) return natural is
  begin
    -- The size - 1 bits of the address must be 0, according to spec.
    -- The intra-word width is decided by bus data width - the size.
    -- A more elaborate way of writing would be slicing downto size and shifting left by size.
    return to_integer(unsigned(address(log2(strb_width) - 1 downto 0)));
  end function;

  -- Convert cluster length to exponent of power of 2, i.e. Ax/H-SIZE encoding.
  -- Since a cluster can be of "odd" length, the maximum whole size is needed.
  -- E.g. 3 bytes can only be sent as 2 + 1 bytes to avoid overwriting data.
  function bytes_to_size(n_bytes : natural; n_result_bits : natural) return
    std_logic_vector is

    variable t : integer range 0 to 511;
    variable r : unsigned(n_result_bits - 1 downto 0);
  begin
    t := 1;
    r := (others => '0');
    while (t < 2**8) and (t < n_bytes) loop
      t := t * 2;
      if t <= n_bytes then
        r := r + to_unsigned(1, r'length);
      end if;
    end loop;
    return std_logic_vector(r);
  end function;

  -- How large can the transaction be to not violate addressing rules?
  function calc_hsize(axsize : std_logic_vector; n_bytes : natural;
                      addr : std_logic_vector; max_bytes : natural) return std_logic_vector is
    variable ff1 : integer range -1 to max_bytes;
  begin
    -- The amount of bytes written must be placed in an even offset.
    -- This means that the number of bytes must fit within the first 0-segment
    -- of the address.
    ff1 := find_first_one(addr(log2(max_bytes) - 1 downto 0));
    if ff1 >= 0 then
      return min(bytes_to_size(2**ff1, axsize'length),
                 bytes_to_size(n_bytes, axsize'length));
    else
      return bytes_to_size(n_bytes, axsize'length);
    end if;
  end function;

  function hresp_to_resp (
    hresp : std_logic_vector)
    return std_logic is
  begin
    if hresp = HRESP_OKAY then
      return '0';
    else
      return '1';
    end if;
  end function;

  function resp_to_rresp (
    resp : std_logic)
    return std_logic_vector is

    variable r : std_logic_vector(1 downto 0);
  begin
    if resp = '1' then
      r := XRESP_SLVERR;
    else
      r := XRESP_OKAY;
    end if;
    return r;
  end function;

  function replicate_data(d : std_logic_vector;
                          hsize : std_logic_vector(2 downto 0)) return
    std_logic_vector is

      variable r : std_logic_vector(wordsize - 1 downto 0) := (others => '0');
  begin
    -- Hsize encodes number of bytes as the exponent of 2.
    -- Assume that the data vector has the correct data in the lower bits.
    -- Code replication due to loop limits being dynamic (hsize).
    case hsize is
      when "000" =>
        for i in 0 to (wordsize/8)/(2**0) - 1 loop
          r((i+1) * (2**0) * 8 - 1 downto i * (2**0) * 8) := d((2**0) * 8 - 1 downto 0);
        end loop;
      when "001" =>
        for i in 0 to (wordsize/8)/(2**1) - 1 loop
          r((i+1) * (2**1) * 8 - 1 downto i * (2**1) * 8) := d((2**1) * 8 - 1 downto 0);
        end loop;
      when "010" =>
        for i in 0 to (wordsize/8)/(2**2) - 1 loop
          r((i+1) * (2**2) * 8 - 1 downto i * (2**2) * 8) := d((2**2) * 8 - 1 downto 0);
        end loop;
      when "011" =>
        for i in 0 to (wordsize/8)/(2**3) - 1 loop
          r((i+1) * (2**3) * 8 - 1 downto i * (2**3) * 8) := d((2**3) * 8 - 1 downto 0);
        end loop;
      when "100" =>
        for i in 0 to (wordsize/8)/(2**4) - 1 loop
          r((i+1) * (2**4) * 8 - 1 downto i * (2**4) * 8) := d((2**4) * 8 - 1 downto 0);
        end loop;
      when "101" =>
        for i in 0 to (wordsize/8)/(2**5) - 1 loop
          r((i+1) * (2**5) * 8 - 1 downto i * (2**5) * 8) := d((2**5) * 8 - 1 downto 0);
        end loop;
      when "110" =>
        for i in 0 to (wordsize/8)/(2**6) - 1 loop
          r((i+1) * (2**6) * 8 - 1 downto i * (2**6) * 8) := d((2**6) * 8 - 1 downto 0);
        end loop;
      when "111" =>
        for i in 0 to (wordsize/8)/(2**7) - 1 loop
          r((i+1) * (2**7) * 8 - 1 downto i * (2**7) * 8) := d((2**7) * 8 - 1 downto 0);
        end loop;
      when others => null;
    end case;

    return r;
  end function;

  function abits(
    wbufn : in integer)
    return integer is
    variable ret_val : integer;
  begin
    ret_val := 1;

    if wbufn > 2 then
      ret_val := log2(wbufn);
    end if;
    return ret_val;
  end abits;

  -- Calculates the number of available beats until the next 1k boundary.
  function get_1k_burst_length (addr : std_logic_vector; hsize : std_logic_vector) return unsigned is
    constant addr_1k : unsigned(10 downto 0) := unsigned('0' & addr(9 downto 0));
    constant one_k : unsigned(10 downto 0) := "100" & x"00";

    variable r : unsigned(10 downto 0);
  begin
    r := shift_right(one_k - addr_1k, to_integer(unsigned(hsize)));
    -- Saturate to longest burst length (256).
    if r > unsigned'("100000000") then
      return unsigned'("100000000");
    else
      return r(8 downto 0);
    end if;
  end function;

  constant dw : integer := wordsize;
  constant mask_addr : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(mask, 12)) & (31-12 downto 0 => '0');

  constant hconfig : ahb_config_type := (
    0      => ahb_device_reg (vendorid, deviceid, 0, 0, 0),
    others => zero32);

  type state_type is (idle, write_transaction, read_start_burst, rdrivedata,
                      unsupported_write, unsupported_read);

  type resp_type is array (dbuffer-1 downto 0) of std_logic_vector(1 downto 0);

  type write_pipe_type is record
    wbuf_dv         : std_ulogic;
    wbuf            : std_logic_vector(dw - 1 downto 0); -- Data
    wstrb           : std_logic_vector(dw/8 - 1 downto 0); -- Strobe
    wlast           : std_ulogic;
    tag             : std_ulogic;
    cluster_len     : natural range 0 to dw/8;
    last_cluster    : std_ulogic;
    remaining_len   : natural range 0 to (2**8)-1;
    force_end       : std_ulogic;
    addr            : std_logic_vector(ahbmo.haddr'length - 1 downto 0);
  end record;

  type read_pipe_type is record
    addr : std_logic_vector(ahbmo.haddr'length - 1 downto 0);
    len : unsigned(axisi.ar.len'length downto 0);
  end record;

  type reg_type is record
    -- Bridge System State
    state : state_type;
    -- Bridge System Signals
    wp0             : write_pipe_type; -- pipeline stage 0
    wp1             : write_pipe_type; -- pipeline stage 1
    wp2             : write_pipe_type; -- pipeline stage 2
    sidebuf         : write_pipe_type; -- Split buffer
    next_tag        : std_ulogic;
    hvalid          : std_ulogic;
    hvalid_p1       : std_ulogic;
    hlast           : std_ulogic;
    hlast_p1        : std_ulogic;
    rp0             : read_pipe_type;
    rp1             : read_pipe_type;
    rp2             : read_pipe_type;
    last_burst_beat : std_ulogic;
    last_burst_beat_p1 : std_ulogic;
    -- AXI4 Slave Interface Signals
    id          : std_logic_vector(AXI_ID_WIDTH-1 downto 0);
    addr        : std_logic_vector(31 downto 0);
    len         : unsigned(8 downto 0); -- AxLEN + 1
    size        : std_logic_vector(2 downto 0);
    burst       : std_logic_vector(1 downto 0);
    bresp       : std_logic_vector(1 downto 0);
    bvalid      : std_ulogic;
    -- AHB Master Interface Signals
    hwdata      : std_logic_vector(dw - 1 downto 0);
    hwdata_p1   : std_logic_vector(dw - 1 downto 0);
    hbusreq     : std_ulogic;                       -- bus request
    hlock       : std_ulogic;                       -- lock request
    htrans      : std_logic_vector(1 downto 0);     -- transfer type
    haddr       : std_logic_vector(31 downto 0);    -- address bus (byte)
    hwrite      : std_ulogic;                       -- read/write
    hsize       : std_logic_vector(2 downto 0);     -- transfer size
    hburst      : std_logic_vector(2 downto 0);     -- burst type
    hresp       : std_logic_vector(1 downto 0);
  end record;

  constant write_pipe_reset_c : write_pipe_type := (
    wbuf_dv         => '0',
    wbuf            => (others => '0'),
    wstrb           => (others => '0'),
    wlast           => '0',
    tag             => '0',
    cluster_len     => 0,
    last_cluster    => '0',
    remaining_len   => 0,
    force_end       => '0',
    addr            => (others => '0')
  );

  constant read_pipe_reset_c : read_pipe_type := (
    addr => (others => '0'),
    len => (others => '0')
  );

  constant RES_T : reg_type := (
    -- Bridge System State
    state        => idle,
    -- Bridge System Signals
    wp0             => write_pipe_reset_c,
    wp1             => write_pipe_reset_c,
    wp2             => write_pipe_reset_c,
    sidebuf         => write_pipe_reset_c,
    next_tag        => '0',
    hvalid          => '0',
    hvalid_p1       => '0',
    hlast           => '0',
    hlast_p1        => '0',
    rp0             => read_pipe_reset_c,
    rp1             => read_pipe_reset_c,
    rp2             => read_pipe_reset_c,
    last_burst_beat => '0',
    last_burst_beat_p1 => '0',
    -- AXI4 Signals
    id              => (others => '0'),
    addr            => (others => '0'),
    len             => (others => '0'),
    size            => (others => '0'),
    burst           => (others => '0'),
    bresp           => (others => '0'),
    bvalid          => '0',
    -- AHB Signals
    hwdata          => (others => '0'),
    hwdata_p1       => (others => '0'),
    hbusreq         => '0',
    hlock           => '0',
    htrans          => (others => '0'),
    haddr           => (others => '0'),
    hwrite          => '0',
    hsize           => (others => '0'),
    hburst          => (others => '0'),
    hresp           => (others => '0')
    );

  signal r, rin                 : reg_type;
  signal mem_ren, mem_wen       : std_logic;
  signal mem_din, mem_dout      : std_logic_vector(1 + 1 + dw - 1 downto 0);
  signal mem_afull              : std_logic;
  signal mem_empty              : std_logic;
  signal wready : std_logic;
begin

  mem_ren <= (not mem_empty) and axisi.r.ready;

  rbuffer_syncfifo_2p_i : syncfifo_2p
    generic map(
      tech  => memtech,
      abits => abits(dbuffer),
      dbits => mem_din'length, -- Response + last + data
      sepclk => 0, -- Not separate clocks
      afullwl => 2, -- Almost full
      aemptyrl => 0, -- No need to consider almost empty.
      fwft => 1, -- first word fall-through
      piperead => 0, -- output pipeline stage
      ft => memory_ft, -- fault tolerance?
      custombits => memtest_vlen,
      rdhold => 0, -- Don't hold read value after pop.
      scantest => scantest,
      arstr => 0, -- synchronous reset
      arstw => 0 -- synchronous reset
    )
    port map(
      rclk    => clk,
      rrstn   => resetn,
      wrstn   => resetn,
      renable => mem_ren,
      rfull   => open,
      rempty  => mem_empty,
      aempty  => open,
      rusedw  => open,
      dataout => mem_dout,
      wclk    => clk,
      write   => mem_wen,
      wfull   => open,
      afull   => mem_afull,
      wempty  => open,
      wusedw  => open,
      datain  => mem_din,
      dynsync => '0',
      error    => open
    );

  comb : process(r, axisi, ahbmi, mem_afull, mem_empty, mem_dout, wready)
    -- Procedure to swap data based on size. Work-around for synthesis.
    procedure size_based_swap(data_in : in std_logic_vector(dw - 1 downto 0);
                              strb_in : in std_logic_vector(dw/8 - 1 downto 0);
                              variable data_out : inout std_logic_vector(dw - 1 downto 0);
                              variable strb_out : inout std_logic_vector(dw/8 - 1 downto 0);
                              size : in std_logic_vector(2 downto 0);
                              in_offset : in natural) is
    begin
      case size is
        when "000" =>
          data_out(8*(2**0) - 1 downto 0) :=
            byte_swap(data_in(8*(2**0 + in_offset) - 1 downto 8*in_offset));
          strb_out((2**0) - 1 downto 0) :=
            mirror_vector(strb_in((2**0 + in_offset) - 1 downto in_offset));
        when "001" =>
          if dw >= ((2**1) * 8) then
            data_out(8*(2**1) - 1 downto 0) :=
              byte_swap(data_in(8*(2**1 + in_offset) - 1 downto 8*in_offset));
            strb_out((2**1) - 1 downto 0) :=
              mirror_vector(strb_in((2**1 + in_offset) - 1 downto in_offset));
          end if;
        when "010" =>
          if dw >= ((2**2) * 8) then
            data_out(8*(2**2) - 1 downto 0) :=
              byte_swap(data_in(8*(2**2 + in_offset) - 1 downto 8*in_offset));
            strb_out((2**2) - 1 downto 0) :=
              mirror_vector(strb_in((2**2 + in_offset) - 1 downto in_offset));
          end if;
        when "011" =>
          if dw >= ((2**3) * 8) then
            data_out(8*(2**3) - 1 downto 0) :=
              byte_swap(data_in(8*(2**3 + in_offset) - 1 downto 8*in_offset));
            strb_out((2**3) - 1 downto 0) :=
              mirror_vector(strb_in((2**3 + in_offset) - 1 downto in_offset));
          end if;
        when "100" =>
          if dw >= ((2**4) * 8) then
            data_out(8*(2**4) - 1 downto 0) :=
              byte_swap(data_in(8*(2**4 + in_offset) - 1 downto 8*in_offset));
            strb_out((2**4) - 1 downto 0) :=
              mirror_vector(strb_in((2**4 + in_offset) - 1 downto in_offset));
          end if;
        when "101" =>
          if dw >= ((2**5) * 8) then
            data_out(8*(2**5) - 1 downto 0) :=
              byte_swap(data_in(8*(2**5 + in_offset) - 1 downto 8*in_offset));
            strb_out((2**5) - 1 downto 0) :=
              mirror_vector(strb_in((2**5 + in_offset) - 1 downto in_offset));
          end if;
        when "110" =>
          if dw >= ((2**6) * 8) then
            data_out(8*(2**6) - 1 downto 0) :=
              byte_swap(data_in(8*(2**6 + in_offset) - 1 downto 8*in_offset));
            strb_out((2**6) - 1 downto 0) :=
              mirror_vector(strb_in((2**6 + in_offset) - 1 downto in_offset));
          end if;
        when "111" =>
          if dw >= ((2**7) * 8) then
            data_out(8*(2**7) - 1 downto 0) :=
              byte_swap(data_in(8*(2**7 + in_offset) - 1 downto 8*in_offset));
            strb_out((2**7) - 1 downto 0) :=
              mirror_vector(strb_in((2**7 + in_offset) - 1 downto in_offset));
          end if;
        when others => null; -- To cover all other possible sl values...
      end case;
    end procedure;

    variable v : reg_type;
    variable addr_incr : unsigned(7 downto 0);
    variable next_cluster : natural range 0 to dw/8;
    variable strobe_offset : natural;
    variable burst_length : unsigned(8 downto 0);
    variable wready_i : std_ulogic;
    variable dummy : std_logic_vector(dw/8 - 1 downto 0);
    variable awready : std_ulogic;
    variable arready : std_ulogic;
  begin
    v := r;

    wready <= '0'; -- Avoid latches.
    mem_wen <= '0';

    next_cluster := 0;
    strobe_offset := 0;
    burst_length := (others => '0');
    wready_i := '0';
    awready := '0';
    arready := '0';
    -- Avoid reset glitches causing to_integer metavalue warnings in simulation with pragmas.
    -- pragma translate_off
    if r.state /= idle then
    -- pragma translate_on
      addr_incr := shift_left(to_unsigned(1, addr_incr'length), to_integer(unsigned(r.size)));
    -- pragma translate_off
    end if;
    -- pragma translate_on

    -- State machine
    case r.state is
      when idle =>
        -- AXI4 signals
        awready         := '1';
        arready         := not axisi.aw.valid; -- Prioritize writes.
        v.bvalid        := '0';
        v.bresp         := (others => '0');
        -- Bridge control signals
        v.hlast := '0';
        v.hlast_p1 := '0';
        v.hvalid := '0';
        v.hvalid_p1 := '0';
        --  AHB Control Signals
        v.htrans        := HTRANS_IDLE;
        v.hbusreq       := '0';
        v.hwrite        := '0';
        v.hlock         := '0';
        -- Check for a read
        if axisi.ar.valid = '1' then
          -- AXI4 Signals
          v.id          := axisi.ar.id;
          v.len         := unsigned(axisi.ar.len) + to_unsigned(1, r.len'length);
          v.size        := axisi.ar.size;
          v.burst       := axisi.ar.burst;
          -- Mask MSB of the address
          v.rp0.addr    := axisi.ar.addr xor mask_addr;
          -- AHB Signals
          v.hlock       := '0';
          v.hwrite      := '0';
          -- Bridge Signals
          if axisi.ar.burst = XBURST_INCR then
            v.hbusreq := '1';
            v.state := read_start_burst;
          else
            v.state := unsupported_read;
          end if;
        end if;
        -- Check for a write
        if axisi.aw.valid = '1' then
          -- AXI4 signals
          v.bresp       := XRESP_OKAY;
          -- Sample AXI control signals
          v.id          := axisi.aw.id;
          v.wp0.remaining_len := to_integer(unsigned(axisi.aw.len));
          v.size        := axisi.aw.size;
          v.burst       := axisi.aw.burst;
          -- Mask MSB of the address
          v.wp0.addr    := axisi.aw.addr xor mask_addr;
          -- AHB Signals
          v.hlock       := '0';
          v.hwrite      := '1';
          -- Bridge Signals
          if axisi.aw.burst = XBURST_INCR then
            v.hbusreq := '1';
            v.state := write_transaction;
          else
            v.state := unsupported_write;
          end if;
          v.wp0.force_end := '0';
        end if;

      when write_transaction =>
        -- Variable needed to avoid deltacycle propagation issues of the wready signal.
        wready_i := ((not r.wp0.wbuf_dv) or
                     (ahbmi.hready and to_sl(2**to_integer(unsigned(r.size)) =
                                             get_cluster_length(axisi.w.strb(dw/8 - 1 downto 0),
                                                                get_strobe_offset(r.wp0.addr,
                                                                                  dw/8)))))
                    and not r.wp0.wlast and not r.sidebuf.wbuf_dv;
        wready <= wready_i;

        -- Sample new input.
        if wready_i = '1' then
          -- Store last to preserve the capability to go back to idle.
          v.wp0.wlast := axisi.w.last;
          v.wp0.wbuf_dv := axisi.w.valid;
          v.wp0.tag := r.next_tag;

          if axisi.w.valid = '1' then
            v.next_tag := not r.next_tag;
          end if;

          strobe_offset := get_strobe_offset(r.wp0.addr, dw/8);

          -- Swap endianess.
          v.wp0.wstrb := (others => '0');
          if to_sl(axi_endian) /= ahbmi.endian then
            size_based_swap(data_in => axisi.w.data(dw - 1 downto 0),
                            data_out => v.wp0.wbuf,
                            strb_in => axisi.w.strb(dw/8 - 1 downto 0),
                            strb_out => v.wp0.wstrb,
                            size => r.size, in_offset => strobe_offset);
          else
            v.wp0.wbuf := axisi.w.data(dw - 1 downto 0);
            v.wp0.wstrb := axisi.w.strb(dw/8 - 1 downto 0);

            v.wp0.wbuf := std_logic_vector(shift_right(unsigned(v.wp0.wbuf),
                                                       8*strobe_offset)); -- cluster in bytes
            v.wp0.wstrb := std_logic_vector(shift_right(unsigned(v.wp0.wstrb),
                                                        strobe_offset));
          end if;

          -- The core maps bytes to address in a little endian fashion.
          -- In the case of big endian the data will become shuffled if a transaction
          -- of lesser size is created.
          -- This is solved in two steps, this is the first one.
          -- By byte swapping the relevant part of the data and strobe, the position
          -- of each subword becomes globally corrected. The equivalent would be counting
          -- the address backwards.
          -- But this byte swap needs to be corrected for since the data is now in a little endian
          -- format. This is done on an AHB transaction basis, thus performed later.
          if ahbmi.endian = '0' and
            2**to_integer(unsigned(r.size)) > get_cluster_length(v.wp0.wstrb, 0) then

            size_based_swap(data_in => v.wp0.wbuf, data_out => v.wp0.wbuf,
                            strb_in => v.wp0.wstrb, strb_out => v.wp0.wstrb,
                            size => r.size, in_offset => 0);
          end if;

          -- Data needs to be qualified to act on it, since state (addr) is modified.
          if axisi.w.valid = '1' then
            -- Instant adjustment needed due to bubbles.
            -- Keep in mind that everything has been shifted by the strobe offset already.
            if v.wp0.wstrb(0) = '0' then
              next_cluster := find_next_cluster(v.wp0.wstrb);

              v.wp0.wbuf := std_logic_vector(shift_right(unsigned(v.wp0.wbuf),
                                                         8*next_cluster));
              v.wp0.wstrb := std_logic_vector(shift_right(unsigned(v.wp0.wstrb),
                                                          next_cluster));

              -- There is a cluster somewhere, so a transaction has to happen.
              if next_cluster > 0 then
                -- If there is a bubble within the word, the address needs to be
                -- adjustment for the sub-word transaction that will happen.
                v.wp0.addr := std_logic_vector(unsigned(r.wp0.addr) +
                                               to_unsigned(next_cluster,
                                                           r.wp0.addr'length));
              -- No clusters found, the transaction must be skipped.
              else
                v.wp0.addr := std_logic_vector(unsigned(r.wp0.addr) +
                                               shift_left(to_unsigned(1, r.wp0.addr'length),
                                                          to_integer(unsigned(r.size))));
                v.wp0.wbuf_dv := '0';
                -- Last beat of the transaction, end it.
                if r.wp0.remaining_len = 0 then
                  v.wp0.force_end := '1';
                else
                  v.wp0.remaining_len := v.wp0.remaining_len - 1;
                end if;
              end if;
            end if;
            v.wp0.cluster_len := get_cluster_length(v.wp0.wstrb, 0);
          end if;
        end if;

        -- Create AHB transactions based on the write data metadata.
        if ahbmi.hready = '1' then
          if ahbmi.hgrant(hindex) = '1' then
            -- Keep the old pipeline data to be re-used in case of RETRY/SPLIT.
            v.wp1 := r.wp0;
            v.wp2 := r.wp1;
          end if;

          if ahbmi.hgrant(hindex) = '1' and r.wp0.wbuf_dv = '1' then
            -- Since the hsize parameter might vary due to strobe bubbles,
            -- every transfer must be a its own burst of length 1.
            if r.wp0.cluster_len /= 0 then
              v.htrans := HTRANS_NONSEQ;
            else
              v.htrans := HTRANS_IDLE;
            end if;

            v.haddr := r.wp0.addr;

            -- The size depends on how well the address is aligned and how big the
            -- current cluster is.
            v.hsize := calc_hsize(r.size, r.wp0.cluster_len, r.wp0.addr, r.wp0.wstrb'length);
            -- Since strobes can have bubbles, there is no way to know how many
            -- actual beats there will be. Thus each burst will have to be
            -- of undefined length.
            v.hburst := HBURST_SINGLE;

            -- Do address conversion for access if requested.
            if sub_bus_width_address_inversion = 1 then
              v.haddr(log2(dw/8)-1 downto 0) :=
                be_to_le_address(dw, r.wp0.addr(log2(dw/8)-1 downto 0), v.hsize);
            end if;

            -- Update metadata.
            if (2**to_integer(unsigned(v.hsize))) = r.wp0.cluster_len then
              next_cluster := find_next_cluster(r.wp0.wstrb);

              if next_cluster = 0 then
                if r.wp0.remaining_len > 0 then
                  v.wp0.remaining_len := r.wp0.remaining_len - 1;
                end if;
                v.wp0.wbuf_dv := wready_i and axisi.w.valid;
                if (wready_i and axisi.w.valid) = '0' then
                  v.wp0.cluster_len := 0;
                end if;
                v.hlast := r.wp0.wlast;
                -- Since there are no more clusters, the address should go to the next "even" address.
                v.wp0.addr := std_logic_vector(unsigned(r.wp0.addr) +
                          shift_left(to_unsigned(1, r.wp0.addr'length), to_integer(unsigned(r.size))));
                v.wp0.addr(to_integer(unsigned(r.size)) - 1 downto 0) := (others => '0');
              else
                v.wp0.cluster_len := get_cluster_length(r.wp0.wstrb, next_cluster);
                v.wp0.addr := std_logic_vector(
                  unsigned(r.wp0.addr) +
                  to_unsigned(next_cluster, r.wp0.addr'length));
                v.wp0.wstrb := std_logic_vector(shift_right(unsigned(r.wp0.wstrb),
                                                            next_cluster));
                v.wp0.wbuf := std_logic_vector(shift_right(unsigned(r.wp0.wbuf),
                                                           8*next_cluster));
              end if;
            else
              v.wp0.addr := std_logic_vector(
                unsigned(r.wp0.addr) +
                shift_left(to_unsigned(1, r.wp0.addr'length),
                           to_integer(unsigned(v.hsize))));
              v.wp0.cluster_len := r.wp0.cluster_len - (2**to_integer(unsigned(v.hsize)));
              v.wp0.wstrb := std_logic_vector(shift_right(unsigned(r.wp0.wstrb),
                                                          2**to_integer(unsigned(v.hsize))));
              v.wp0.wbuf := std_logic_vector(shift_right(unsigned(r.wp0.wbuf),
                                                         8*(2**to_integer(unsigned(v.hsize)))));
            end if;

          else
            v.htrans := HTRANS_IDLE;
          end if; -- Valid data and bus access
        else
          if ahbmi.hresp = HRESP_SPLIT or ahbmi.hresp = HRESP_RETRY then
            -- Force the bus back to idle in preparation of transaction restart.
            v.htrans := HTRANS_IDLE;
            v.hvalid := '0';
            -- Reset write pipeline state back to before the halted transaction.
            v.wp0 := r.wp2;

            -- The last transaction of an AXI beat might be split. If that happens when a new AXI beat
            -- has been accepted, then the new beat must also be restored from the pipeline.
            -- Due to the tic-toc nature of the ready, the new beat will be in wp0 during this scenario.
            if r.wp0.wbuf_dv = '1' and r.wp0.tag /= r.wp2.tag then
              v.sidebuf := r.wp0;
            end if;
          end if;
        end if; -- bus can move

        if ahbmi.hready = '1' or r.hvalid_p1 = '0' then
          v.hvalid := r.wp0.wbuf_dv;
          -- If the data was swapped earlier due to holes in the strobe (hsize < awsize),
          -- then it must be restored to the big endian order. This is done by swapping back
          -- the relevant part of the data buffer.
          if ahbmi.endian = '0' and
            2**to_integer(unsigned(r.size)) > get_cluster_length(r.wp0.wstrb, 0) then

            size_based_swap(data_in => r.wp0.wbuf, data_out => v.hwdata,
                            strb_in => dummy, strb_out => dummy,
                            size => v.hsize, in_offset => 0);
          else
            v.hwdata := r.wp0.wbuf;
          end if;

          -- One cycle after addressing.
          v.hlast_p1 := r.hlast;
          -- Replicate the data across the output vector to match address offset.
          v.hwdata_p1 := replicate_data(r.hwdata, r.hsize);
          v.hvalid_p1 := r.hvalid;
        end if;

        -- Check response on the AHB side
        if r.hvalid_p1 = '1' and ahbmi.hready = '1' then -- Write data is active
          if ahbmi.hresp = HRESP_ERROR then
            v.bresp := XRESP_SLVERR;
          end if;

          if r.sidebuf.wbuf_dv = '1' and (ahbmi.hresp = HRESP_ERROR or ahbmi.hresp = HRESP_OKAY) then
            v.wp0 := r.sidebuf;
            v.sidebuf.wbuf_dv := '0';
          end if;

          -- Either the pipeline naturally terminates as the last data beat is pushed through.
          -- OR it will have to be forcefully terminated when flushed, since the last flag
          -- will never be asserted due to the last AXI beat not having any writable data.
          -- The handling of the forcing must be outside this scope since it requires a flushed pipe.
          if r.hlast_p1 = '1' and (ahbmi.hresp = HRESP_OKAY or ahbmi.hresp = HRESP_ERROR) then
            v.hbusreq := '0';
            v.bvalid := '1';
          end if;
        end if;

        -- Handle the forced ending due to missing last flag.
        -- A flushed pipeline ensures that no data is unwritten.
        if r.wp0.force_end = '1' and r.hvalid = '0' and
          ((r.hvalid_p1 = '1' and ahbmi.hready = '1') or r.hvalid_p1 = '0') then

          v.hbusreq := '0';
          v.bvalid := '1';
        end if;

        if r.bvalid = '1' and axisi.b.ready = '1' then
          v.bvalid := '0';
          v.wp0.wlast := '0';
          v.state := idle;
        end if;

      when read_start_burst =>
        mem_wen <= ahbmi.hready and r.hvalid_p1 and -- Can have a read from previous burst coming in.
                   to_sl(ahbmi.hresp /= HRESP_SPLIT and ahbmi.hresp /= HRESP_RETRY);

        -- Move pipelines.
        v.hvalid_p1 := r.hvalid;
        v.hlast_p1 := r.hlast;
        v.rp1 := r.rp0;
        v.rp2 := r.rp1;

        if ahbmi.hgrant(hindex) = '1' then
          v.htrans      := HTRANS_NONSEQ;
          v.hsize       := r.size;
          v.hvalid      := '1';
          v.rp0.addr    := std_logic_vector(unsigned(r.rp0.addr) +
                                            shift_left(to_unsigned(1, r.rp0.addr'length),
                                                       to_integer(unsigned(r.size))));
          -- Planned burst length.
          burst_length := get_1k_burst_length(r.rp0.addr, r.size);
          burst_length := unsigned(min(std_logic_vector(burst_length), std_logic_vector(r.len)));
          -- Remaining length not scheduled for the coming burst.
          v.len := unsigned(r.len) - burst_length;
          v.rp0.len := burst_length;
          case v.rp0.len is
            when "000000001"   => v.hburst := HBURST_SINGLE;
            when "000000100"   => v.hburst := HBURST_INCR4;
            when "000001000"   => v.hburst := HBURST_INCR8;
            when "000010000"   => v.hburst := HBURST_INCR16;
            when others       => v.hburst := HBURST_INCR;
          end case;

          -- Update according to the calculated burst length.
          if v.rp0.len > to_unsigned(1, v.rp0.len'length) then
            v.last_burst_beat := '0';
          else
            v.last_burst_beat := '1';
          end if;

          if v.rp0.len = to_unsigned(1, v.rp0.len'length) and v.len = to_unsigned(0, v.len'length) then
            v.hlast := '1';
          else
            v.hlast := '0';
          end if;
          v.rp1.len := burst_length; -- Copy the non-incremented state into the first pipe.
          v.rp0.len := v.rp0.len - to_unsigned(1, v.rp0.len'length);

          if sub_bus_width_address_inversion = 1 then
            v.haddr(log2(dw/8)-1 downto 0) := be_to_le_address(dw, r.rp0.addr(log2(dw/8)-1 downto 0),
                                                               r.size);
            v.haddr(31 downto log2(dw/8)) := r.rp0.addr(31 downto log2(dw/8));
          else
            v.haddr := r.rp0.addr;
          end if;
        end if;

        v.state := rdrivedata;

      when rdrivedata =>
        mem_wen <= ahbmi.hready and r.hvalid_p1 and
                   to_sl(ahbmi.hresp /= HRESP_SPLIT and ahbmi.hresp /= HRESP_RETRY);

        -- AHB Interface
        if ahbmi.hready = '1' then
          v.hvalid_p1 := r.hvalid;
          v.hlast_p1 := r.hlast;
          v.last_burst_beat_p1 := r.last_burst_beat;

          if ahbmi.hgrant(hindex) = '1' then
            -- Keep the old pipeline data to be re-used in case of RETRY/SPLIT.
            v.rp1 := r.rp0;
            v.rp2 := r.rp1;

            -- Bus can be stalled when there is a risk for FIFO overflow.
            -- The bus contains the next transaction, so only htrans needs an update.
            if r.htrans = HTRANS_BUSY then
              -- FIFO is no longer at risk, actualize the current transaction.
              if mem_afull = '0' then
                v.htrans := HTRANS_SEQ;
                v.hvalid := '1';

                -- Regenerate lost last flag.
                -- Worst case is length has already been decremented to 0.
                if r.rp0.len <= to_unsigned(1, r.rp0.len'length) then
                  v.last_burst_beat := '1';
                else
                  v.last_burst_beat := '0';
                end if;

                if r.rp0.len <= to_unsigned(1, r.rp0.len'length) and
                  r.len = to_unsigned(0, r.len'length) then

                  v.hlast := '1';
                else
                  v.hlast := '0';
                end if;
              end if;
            else
              if r.htrans /= HTRANS_IDLE and r.last_burst_beat = '0' then
                v.rp0.addr := std_logic_vector(unsigned(r.rp0.addr) + addr_incr);
              end if;

              v.hvalid := '1';

              -- Do address conversion.
              if sub_bus_width_address_inversion = 1 then
                v.haddr(log2(dw/8)-1 downto 0) := be_to_le_address(dw, r.rp0.addr(log2(dw/8)-1 downto 0),
                                                                   r.size);
                v.haddr(31 downto log2(dw/8)) := r.rp0.addr(31 downto log2(dw/8));
              else
                v.haddr := r.rp0.addr;
              end if;

              if r.rp0.len > to_unsigned(0, r.rp0.len'length) then
                v.rp0.len := unsigned(r.rp0.len) - to_unsigned(1, r.rp0.len'length);
              end if;

              -- Keep track of the last beat of the current AHB transaction.
              -- Intended to be used to handle 1k crossings.
              if r.rp0.len = to_unsigned(1, r.rp0.len'length) then
                v.last_burst_beat := '1';
              else
                v.last_burst_beat := '0';
              end if;

              -- Keep track of the last beat of the current AXI transaction.
              -- Intended to be used to generate rlast and leave the reading state.
              if r.rp0.len = to_unsigned(1, r.rp0.len'length) and r.len = to_unsigned(0, r.len'length) then
                v.hlast := '1';
              else
                v.hlast := '0';
              end if;

              -- Handle end of AHB burst.
              if r.last_burst_beat = '1' and r.hvalid = '1' then
                v.htrans := HTRANS_IDLE;
                v.hvalid := '0';
              elsif r.htrans /= HTRANS_IDLE then
                v.htrans := HTRANS_SEQ;
              end if;

              -- FIFO almost full, stall the transfer.
              if mem_afull = '1' then
                v.htrans := HTRANS_BUSY;
                v.hvalid := '0';
              end if;
            end if; -- Active Transaction Type

            -- Last beat of the AHB burst, is superceded by the last beat of the AXI burst.
            if r.hvalid_p1 = '1' and r.last_burst_beat_p1 = '1' and
              ahbmi.hresp /= HRESP_SPLIT and ahbmi.hresp /= HRESP_RETRY then

              v.hvalid := '0';
              v.state := read_start_burst;
              v.htrans := HTRANS_IDLE;
            end if;

            -- Last read data is entering the FIFO.
            -- Needs to be at the end to overwrite hvalid and htrans.
            if r.hvalid_p1 = '1' and r.hlast_p1 = '1' and
              ahbmi.hresp /= HRESP_SPLIT and ahbmi.hresp /= HRESP_RETRY then

              v.hvalid := '0';

              v.state := idle;
              v.hbusreq := '0';
            end if;
          -- Lost bus access
          else
            v.state := read_start_burst;
            v.htrans := HTRANS_IDLE;
            v.len := r.len + r.rp0.len;
            v.hvalid := '0';
          end if;
        else -- not hready
          if ahbmi.hresp = HRESP_SPLIT or ahbmi.hresp = HRESP_RETRY then
            v.htrans := HTRANS_IDLE;
            v.hvalid := '0';
            -- Rewind state.
            v.state := read_start_burst;
            v.rp0 := r.rp2;
            v.len := r.len + r.rp2.len;
          end if;
        end if;

      when unsupported_write =>
        wready <= not r.bvalid;

        v.bresp := XRESP_SLVERR;

        if wready = '1' and axisi.w.valid = '1' then
          if r.wp0.remaining_len > 0 then
            v.wp0.remaining_len := r.wp0.remaining_len - 1;
          else
            v.bvalid := '1';
          end if;
        end if;

        if r.bvalid = '1' and axisi.b.ready = '1' then
          v.bvalid := '0';
          v.state := idle;
        end if;

      when unsupported_read =>
        axiso.r.resp <= XRESP_SLVERR;
        axiso.r.valid <= '1';
        axiso.r.data <= (others => '0');

        if axisi.r.ready = '1' then
          if r.len > 1 then
            axiso.r.last <= '0';
          else
            axiso.r.last <= '1';
          end if;

          if r.len > 0 then
            v.len := r.len - to_unsigned(1, r.len'length);
          end if;
        end if;

        if r.len = 0 then
          axiso.r.valid <= '0';
          v.state := idle;
        end if;
      when others => null;
    end case;

    -- Propagate next state.
    rin <= v;

    -- AHB Master Interface Signals
    ahbmo.hconfig         <= hconfig;
    ahbmo.hindex          <= hindex;
    ahbmo.hirq            <= (others => '0');

    ahbmo.haddr           <= r.haddr;
    ahbmo.htrans          <= r.htrans;
    ahbmo.hprot           <= "0011";
    ahbmo.hburst          <= r.hburst;
    ahbmo.hbusreq         <= r.hbusreq;
    ahbmo.hwrite          <= r.hwrite;
    ahbmo.hwdata(dw - 1 downto 0) <= r.hwdata_p1;
    ahbmo.hlock           <= r.hlock;
    ahbmo.hsize           <= r.hsize;

    axiso.b.id            <= r.id;
    axiso.r.id            <= r.id;
    if r.state /= unsupported_read then
      axiso.r.last          <= mem_dout(mem_dout'high - 1);
      axiso.r.resp          <= resp_to_rresp(mem_dout(mem_dout'high));
      axiso.r.valid         <= not mem_empty;
      axiso.r.data(dw - 1 downto 0) <= mem_dout(dw - 1 downto 0);
    end if;
    axiso.ar.ready        <= arready;
    axiso.aw.ready        <= awready;
    axiso.b.resp          <= r.bresp;
    axiso.b.valid         <= r.bvalid;
    axiso.w.ready         <= wready;

    -- FIFO
    if to_sl(axi_endian) /= ahbmi.endian then
      mem_din <= hresp_to_resp(ahbmi.hresp) & r.hlast_p1 & byte_swap(ahbmi.hrdata(dw - 1 downto 0));
    else
      mem_din <= hresp_to_resp(ahbmi.hresp) & r.hlast_p1 & ahbmi.hrdata(dw - 1 downto 0);
    end if;
  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if resetn = '0' then
        r <= RES_T;
      end if;
    end if;
  end process;
end architecture;
