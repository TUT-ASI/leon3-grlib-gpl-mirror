------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
-- Entity:      axi2apb3
-- File:        axi2apb3.vhd
-- Authors:     Martin Caous George - Frontgrade Gaisler
-- Description: AXI4 to APB3 bridge
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.axi.all;

entity axi2apb3 is
  generic (
    nslaves   : integer range 1 to NAPBSLV := NAPBSLV;
    idwidth   : integer range 0 to 2*AXI_ID_WIDTH := AXI_ID_WIDTH;
    dwidth    : integer range 32 to AXIDW := AXIDW
  );
  port (
    aclk      : in  std_ulogic;
    aresetn   : in  std_ulogic;
    -- AXI slave port
    axisi     : in  axi4_mosi_type;
    axixsi    : in  extaxi_mosi_type;
    axiso     : out axi_somi_type;
    axixso    : out extaxi_miso_type;
    -- APB
    apbi      : out apb3_slv_in_type;
    apbo      : in  apb3_slv_out_vector;
    apbendian : in  std_ulogic := '0' -- '0' big endian, '1' little endian
  );
end;

architecture rtl of axi2apb3 is

  constant ASYNC_RST  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant RESET_ALL  : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

  constant axwidth    : integer := idwidth+20+8+3+2+1+4+3+4;
  constant wwidth     : integer := dwidth+dwidth/8+1;
  constant bwidth     : integer := idwidth+2;
  constant rwidth     : integer := idwidth+dwidth+2+1;

  function align_addr(addr, size : std_logic_vector) return std_logic_vector is
    variable shft : integer range 0 to 7;
  begin
    shft := to_integer(unsigned(size));
    return std_logic_vector(shift_left(shift_right(unsigned(addr), shft), shft));
  end function;

  function paddr_incr(paddr, psize : std_logic_vector) return std_logic_vector is
    variable addr : unsigned(paddr'length-1 downto 0);
    variable shft : integer range 0 to 7;
    variable incr : unsigned(7 downto 0);
  begin
    shft := to_integer(unsigned(psize));
    incr := shift_left(to_unsigned(1,8), shft);
    addr := shift_left(shift_right(unsigned(paddr), shft), shft);
    return std_logic_vector(addr + incr);
  end function;

  function cond(expr : boolean; a, b : std_ulogic) return std_ulogic is
  begin
    if expr then return a; else return b; end if;
  end function;

  function cond(expr : boolean; a, b : std_logic_vector) return std_logic_vector is
  begin
    if expr then return a; else return b; end if;
  end function;

  function cond(expr : boolean; a, b : integer) return integer is
  begin
    if expr then return a; else return b; end if;
  end function;

  type reg_type is record
    -- AXI
    xid         : std_logic_vector(idwidth-1 downto 0);
    wready      : std_ulogic;
    xerror      : std_ulogic;
    bvalid      : std_ulogic;
    w           : axi4_w_mosi_type;
    w_spill     : axi4_w_mosi_type;
    wsubvalid   : std_logic_vector(dwidth/32-1 downto 0);
    rdata       : std_logic_vector(dwidth-1 downto 0);
    rlast       : std_ulogic;
    rvalid      : std_ulogic;
    -- APB
    pactive     : std_ulogic;
    plen        : unsigned(7 downto 0);
    psize       : std_logic_vector(2 downto 0);
    pratio      : unsigned(log2x(dwidth/32)-1 downto 0);
    psublen     : unsigned(log2x(dwidth/32)-1 downto 0);
    penable     : std_ulogic;
    psel        : std_ulogic;
    paddr       : std_logic_vector(31 downto 0);
    pwrite      : std_ulogic;
    pindex      : std_logic_vector(log2x(nslaves)-1 downto 0);
    pmask       : std_logic_vector(0 to nslaves-1);
  end record;

  constant RST : reg_type := (
    -- AXI
    xid       => (others => '0'),
    xerror    => '0',
    wready    => '0',
    bvalid    => '0',
    w         => (data => (others => '0'),
                  strb => (others => '0'),
                  last => '0',
                  valid => '0'),
    w_spill   => (data => (others => '0'),
                  strb => (others => '0'),
                  last => '0',
                  valid => '0'),
    wsubvalid => (others => '0'),
    rdata     => (others => '0'),
    rlast     => '0',
    rvalid    => '0',
    -- APB
    pactive   => '0',
    plen      => (others => '0'),
    psize     => (others => '0'),
    pratio    => (others => '0'),
    psublen   => (others => '0'),
    penable   => '0',
    psel      => '0',
    paddr     => (others => '0'),
    pwrite    => '0',
    pindex    => (others => '0'),
    pmask     => (others => '0')
  );

  type data_vector_type is array(0 to dwidth/32-1) of std_logic_vector(31 downto 0);
  type strb_vector_type is array(0 to dwidth/32-1) of std_logic_vector(3 downto 0);

  signal s_ax         : std_logic_vector(2*axwidth-1 downto 0);
  signal s_axvalid    : std_logic_vector(1 downto 0);
  signal s_axready    : std_logic_vector(1 downto 0);
  signal arb_ax       : std_logic_vector(axwidth downto 0);
  signal arb_axvalid  : std_ulogic;
  signal arb_axready  : std_ulogic;
  signal m_ax         : std_logic_vector(axwidth downto 0);
  signal m_axvalid    : std_ulogic;
  signal m_axready    : std_ulogic;
  signal axwrite      : std_ulogic;

  signal s_w, m_w     : std_logic_vector(wwidth-1 downto 0);
  signal m_wvalid     : std_ulogic;

  signal m_b, s_b     : std_logic_vector(bwidth-1 downto 0);
  signal s_bvalid     : std_ulogic;

  signal m_r, s_r     : std_logic_vector(rwidth-1 downto 0);
  signal s_rvalid     : std_ulogic;

  signal axisi_r      : axi4_mosi_type;
  signal axixsi_r     : extaxi_mosi_type;
  signal axiso_r      : axi_somi_type;
  signal axixso_r     : extaxi_miso_type;

  signal r, rin       : reg_type;

begin

  s_ax <= aw_pack(axisi.aw, axixsi.aw, 20, idwidth) &
          ar_pack(axisi.ar, axixsi.ar, 20, idwidth);
  s_axvalid <= axisi.aw.valid & axisi.ar.valid;
  axiso.ar.ready <= s_axready(0);
  axiso.aw.ready <= s_axready(1);

  -- AW, AR arbiter
  axarbiter : arbiter_tree
    generic map (
      nreq      => 2,
      dwidth    => axwidth,
      arb_prio  => 2,
      arb_lock  => 0
    )
    port map (
      clk   => aclk,
      rstn  => aresetn,
      sdata => s_ax,
      sreq  => s_axvalid,
      sgnt  => s_axready,
      msel  => arb_ax(axwidth downto axwidth),
      mdata => arb_ax(axwidth-1 downto 0),
      mreq  => arb_axvalid,
      mgnt  => arb_axready
    );

  ax_slice : register_slice
  generic map (
    dwidth    => axwidth+1,
    direction => 1,
    bypass    => 0
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,
    s_xdata   => arb_ax,
    s_xvalid  => arb_axvalid,
    s_xready  => arb_axready,
    m_xdata   => m_ax,
    m_xvalid  => m_axvalid,
    m_xready  => axiso_r.aw.ready
  );
  axwrite <= m_ax(axwidth);
  aw_unpack(idwidth, 20, m_ax(axwidth-1 downto 0), m_axvalid, axisi_r.aw, axixsi_r.aw);

  -- W
  -- Slice is handled internally
  axisi_r.w <= axisi.w;
  axiso.w   <= axiso_r.w;

  -- B

  m_b <= b_pack(axiso_r.b, axixso_r.b, idwidth);
  b_slice : register_slice
  generic map (
    dwidth    => bwidth,
    direction => 0,
    bypass    => 0
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => m_b,
    s_xvalid  => axiso_r.b.valid,
    s_xready  => axisi_r.b.ready,

    m_xdata   => s_b,
    m_xvalid  => s_bvalid,
    m_xready  => axisi.b.ready
  );
  b_unpack(idwidth, s_b, s_bvalid, axiso.b, axixso.b);

  -- R

  m_r <= r_pack(axiso_r.r, axixso_r.r, idwidth, dwidth);
  r_slice : register_slice
  generic map (
    dwidth    => rwidth,
    direction => 0,
    bypass    => 0
  )
  port map (
    clk       => aclk,
    rstn      => aresetn,

    s_xdata   => m_r,
    s_xvalid  => axiso_r.r.valid,
    s_xready  => axisi_r.r.ready,

    m_xdata   => s_r,
    m_xvalid  => s_rvalid,
    m_xready  => axisi.r.ready
  );
  r_unpack(idwidth, dwidth, s_r, s_rvalid, axiso.r, axixso.r);

  p_comb : process(r, aresetn, axisi_r, axixsi_r, axwrite, apbo)
    variable v          : reg_type;
    variable vaxid      : std_logic_vector(idwidth-1 downto 0);
    variable vxid       : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
    variable vaxready   : std_ulogic;
    variable vwready    : std_ulogic;
    variable vbready    : std_ulogic;
    variable vawaddr    : std_logic_vector(19 downto 0);
    variable varaddr    : std_logic_vector(19 downto 0);
    variable vrready    : std_ulogic;
    variable vpslvsel   : std_logic_vector(0 to nslaves-1);
    variable vpenable   : std_ulogic;
    variable vpwvalid   : std_ulogic;
    variable vpwdata    : std_logic_vector(31 downto 0);
    variable vprdata    : std_logic_vector(31 downto 0);
    variable vpready    : std_ulogic;
    variable vpslverr   : std_ulogic;
    variable vpsel      : std_logic_vector(0 to NAPBSLV-1);
    variable vplast     : std_ulogic;
    variable vpaddrnxt  : std_logic_vector(31 downto 0);
  begin
    v := r;

    vaxid     := std_logic_vector(resize(unsigned(axixsi_r.aw.id) & unsigned(axisi_r.aw.id), idwidth));
    vxid      := (others => '0'); vxid(idwidth-1 downto 0) := r.xid;
    vawaddr   := axisi_r.aw.addr(19 downto log2(dwidth/8)) & ctz(r.w.strb(dwidth/8-1 downto 0));
    vbready   := axisi_r.b.ready;
    varaddr   := align_addr(axisi_r.aw.addr(19 downto 0), axisi_r.aw.size);
    vrready   := axisi_r.r.ready;
    vpaddrnxt := paddr_incr(r.paddr, r.psize);

    -- Decode APB slave
    vpslvsel := (others => '0');
    for i in 0 to nslaves-1 loop
      if ((apbo(i).pconfig(1)(1 downto 0) = "01") and
        ((apbo(i).pconfig(1)(31 downto 20) and apbo(i).pconfig(1)(15 downto 4)) =
        (axisi_r.aw.addr(19 downto  8) and apbo(i).pconfig(1)(15 downto 4))))
      then
        vpslvsel(i) := '1';
      end if;
    end loop;

    if vbready = '1' then
      v.bvalid := '0';
    end if;

    if r.w.valid = '1' and r.wready = '1' and r.w.last = '1' then
      -- Drain of W completed
      v.wready := '0';
      v.bvalid := '1';
    end if;

    -- AXI read response handling
    if r.rvalid = '1' and vrready = '1' then
      v.rvalid := r.xerror;
      if r.rlast = '1' then
        v.rvalid  := '0';
        v.rlast   := '0';
      elsif r.xerror = '1' then
        v.plen := r.plen - 1;
        if r.plen = 1 then
          v.rlast := '1';
        end if;
      end if;
    end if;

    -- Select pwdata and mask out any sparse writes
    vplast := '0';
    vpwvalid := '0';
    if dwidth = 32 then
      vpwvalid := r.wsubvalid(0);
      if apbendian = '1' then
        vpwdata := r.w.data(31 downto 0);
      else
        vpwdata := byte_swap(r.w.data(31 downto 0));
      end if;
    else
      for i in 0 to dwidth/32-1 loop
        if unsigned(r.paddr(log2(dwidth/8)-1 downto 2)) = i then
          vpwvalid := r.wsubvalid(i);
          if apbendian = '1' then
            vpwdata := r.w.data(i*32+31 downto i*32);
          else
            vpwdata := byte_swap(r.w.data(i*32+31 downto i*32));
          end if;
        end if;
      end loop;
      if shift_right(unsigned(r.wsubvalid), to_integer(unsigned(vpaddrnxt(log2(dwidth/8)-1 downto 2)))) = 0 then
        vplast := '1';
      end if;
    end if;

    -- Select prdata
    vprdata := apbo(to_integer(unsigned(r.pindex))).prdata;
    if apbendian = '0' then
      vprdata := byte_swap(apbo(to_integer(unsigned(r.pindex))).prdata);
    end if;
    vpready   := apbo(to_integer(unsigned(r.pindex))).pready;
    vpslverr  := apbo(to_integer(unsigned(r.pindex))).pslverr;

    -- APB control
    if r.pactive = '1' then
      if r.psel = '1' and r.penable = '1' then
        if vpready = '1' then
          v.xerror  := r.xerror or vpslverr;
          v.wready  := '0';
          v.penable := '0';
          if r.pwrite = '0' then
            if dwidth = 32 then
              v.rdata := vprdata;
            else
              for i in 0 to dwidth/32-1 loop
                if unsigned(r.paddr(log2(dwidth/8)-1 downto 2)) = i then
                  v.rdata(i*32+31 downto i*32) := vprdata;
                end if;
              end loop;
            end if;
          end if;
          if r.plen /= 0 or r.psublen /= 0 then
            v.paddr := vpaddrnxt;
            if r.psublen /= 0 then
              v.psublen := r.psublen - 1;
            else
              v.plen    := r.plen - 1;
              v.psublen := r.pratio;
            end if;
          end if;
          if (r.psublen = 0 or (r.pwrite = '1' and vplast = '1')) and
             (r.plen = 0 or r.xerror = '1' or vpslverr = '1') then
            -- All done or slave error received
            v.pactive := '0';
            v.psel    := '0';
            v.rvalid  := not r.pwrite;
            if r.plen /= 0 then
              -- Abort remaining on slave error
              v.wready := r.pwrite;
            end if;
            if r.plen = 0 then
              v.rlast := not r.pwrite;
            end if;
          elsif r.psublen = 0 then
            -- AXI beat done
            v.psel    := not r.pwrite or r.w_spill.valid or axisi_r.w.valid;
            v.rvalid  := not r.pwrite;
          end if;
        end if;
      else
        v.psel    := not r.pwrite or r.w.valid or r.w_spill.valid or axisi_r.w.valid;
        v.penable := r.psel and (not r.rvalid or vrready);
        if r.psublen = 0 or (r.pwrite = '1' and vplast = '1' and r.plen = 0) then
          v.wready  := r.psel and r.pwrite;
        end if;
      end if;
    end if;

    -- W slice
    vwready := r.wready and (not r.pactive or vpready);

    if axisi_r.w.valid = '1' and r.w_spill.valid = '0' and r.w.valid = '1' and vwready = '0' then
      v.w_spill.valid := '1';
    elsif vwready = '1' then
      v.w_spill.valid := '0';
    end if;

    if r.w_spill.valid = '0' then
      v.w_spill.data(dwidth-1 downto 0)   := axisi_r.w.data(dwidth-1 downto 0);
      v.w_spill.strb(dwidth/8-1 downto 0) := axisi_r.w.strb(dwidth/8-1 downto 0);
      v.w_spill.last                      := axisi_r.w.last;
    end if;

    if r.w.valid = '0' or vwready = '1' then
      v.w.valid := axisi_r.w.valid or r.w_spill.valid;
      if r.w_spill.valid = '1' then
        v.w.data(dwidth-1 downto 0)   := r.w_spill.data(dwidth-1 downto 0);
        v.w.strb(dwidth/8-1 downto 0) := r.w_spill.strb(dwidth/8-1 downto 0);
        v.w.last                      := r.w_spill.last;
      else
        v.w.data(dwidth-1 downto 0)   := axisi_r.w.data(dwidth-1 downto 0);
        v.w.strb(dwidth/8-1 downto 0) := axisi_r.w.strb(dwidth/8-1 downto 0);
        v.w.last                      := axisi_r.w.last;
      end if;
      v.wsubvalid := (others => v.w.valid);
      for i in 0 to dwidth/8-1 loop
        v.wsubvalid(i/4) := v.wsubvalid(i/4) and v.w.strb(i);
      end loop;
    end if;

    -- AX

    vaxready  := axisi_r.aw.valid and                         -- Wait for AX valid
                 (not axwrite or r.w.valid) and               -- Wait for write data if write
                 not r.wready and                             -- Wait for write buffer drain
                 (not r.bvalid or vbready) and                -- Wait for acceptance of write response
                 (not r.rvalid or (vrready and r.rlast)) and  -- Wait for acceptance of last read response
                 not r.pactive;                               -- Wait for APB

    if vaxready = '1' then
      v.xid     := vaxid;
      v.xerror  := '0';
      v.pwrite  := axwrite;
      v.paddr   := (others => '0');
      v.plen    := unsigned(axisi_r.aw.len);
      v.psize   := axisi_r.aw.size;
      v.pratio  := (others => '0');
      v.psublen := (others => '0');
      v.pindex  := (others => '0');
      if nslaves > 1 then
        v.pindex  := ctz(vpslvsel(0 to nslaves-1));
      end if;
      v.pmask   := vpslvsel(0 to nslaves-1);
      if dwidth > 32 and unsigned(axisi_r.aw.size) > "010" then
        v.psize   := "010";
        v.pratio  := shift_left(to_unsigned(1, r.pratio'length), to_integer(unsigned(axisi_r.aw.size) - 2)) - 1;
        v.psublen := shift_left(to_unsigned(1, r.psublen'length), to_integer(unsigned(axisi_r.aw.size) - 2)) - 1;
        if axwrite = '1' then
          v.psublen := v.psublen - unsigned(vawaddr(log2(dwidth/8)-1 downto 2));
        end if;
      end if;
      if axwrite = '1' then
        v.paddr(19 downto 0) := vawaddr;
        -- Only accept incrementing bursts of 32 bits or bus size
        if axisi_r.aw.burst = XBURST_INCR and
           unsigned(axisi_r.aw.size) >= "010" and unsigned(axisi_r.aw.size) <= log2(dwidth/8) then
          -- Accept
          v.pactive := '1';
          v.psel    := '1';
        else
          -- Deny
          -- Write is the wrong burst type or an invalid size
          v.xerror := '1';
          -- Drain write buffer
          v.wready := '1';
        end if;
      else
        v.paddr(19 downto 0) := varaddr;
        -- Using AW record for arbitrated AW/AR
        -- Only accept inrementing bursts
        if axisi_r.aw.burst = XBURST_INCR and unsigned(axisi_r.aw.size) <= log2(dwidth/8) then
          -- Accept
          v.pactive := '1';
          v.psel    := '1';
        else
          -- Deny
          v.xerror  := '1';
          v.rvalid  := '1';
        end if;
      end if;
    end if;

    if not ASYNC_RST and aresetn = '0' then
      if RESET_ALL then
        v := RST;
      else
        v.wready        := RST.wready;
        v.w.valid       := RST.w.valid;
        v.w_spill.valid := RST.w_spill.valid;
        v.bvalid        := RST.bvalid;
        v.rvalid        := RST.rvalid;
-- pragma translate_off
        v.rdata         := RST.rdata;
-- pragma translate_on
        v.rlast         := RST.rlast;
        v.pactive       := RST.pactive;
        v.penable       := RST.penable;
        v.psel          := RST.psel;
      end if;
    end if;

    rin <= v;

    -- Output assignments
    axiso_r <= (
      aw  => (ready => vaxready),
      w   => (ready => not r.w_spill.valid),
      b   => (id    => vxid(AXI_ID_WIDTH-1 downto 0),
              resp  => (r.xerror & '0'),
              valid => r.bvalid),
      ar  => (ready => '0'), -- unused
      r   => (id    => vxid(AXI_ID_WIDTH-1 downto 0),
              data  => r.rdata,
              resp  => (r.xerror & '0'),
              last  => r.rlast,
              valid => r.rvalid)
    );
    axixso_r <= (
      b   => (id    => vxid(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH)),
      r   => (id    => vxid(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH))
    );

    vpsel := (others => '0');
    for i in 0 to nslaves-1 loop
      vpsel(i) := r.pmask(i) and r.psel and (not r.pwrite or vpwvalid);
    end loop;
    vpenable := r.penable and (not r.pwrite or vpwvalid);
    apbi <= (
      psel    => vpsel,
      penable => vpenable,
      paddr   => r.paddr(31 downto 2) & "00",
      pwrite  => r.pwrite,
      pwdata  => vpwdata,
      pirq    => (others => '0'),
      testen  => '0',
      testrst => '0',
      scanen  => '0',
      testoen => '0',
      testin  => (others => '0')
    );
  end process;

  p_reg : process(aclk, aresetn)
  begin
    if rising_edge(aclk) then
      r <= rin;
    end if;
    if ASYNC_RST and aresetn = '0' then
      if RESET_ALL then
        r <= RST;
      else
        r.wready        <= RST.wready;
        r.w.valid       <= RST.w.valid;
        r.w_spill.valid <= RST.w_spill.valid;
        r.bvalid        <= RST.bvalid;
        r.rvalid        <= RST.rvalid;
-- pragma translate_off
        r.rdata         <= RST.rdata;
-- pragma translate_on
        r.rlast         <= RST.rlast;
        r.pactive       <= RST.pactive;
        r.penable       <= RST.penable;
        r.psel          <= RST.psel;
      end if;
    end if;
  end process;

end;
