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
-- Entity:      axi4demux
-- File:        axi4demux.vhd
-- Author:      Martin Caous George - Frontgrade Gaisler AB
-- Description: AXI demultiplexer
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
use grlib.amba.all;
library gaisler;
use gaisler.axi.all;

entity axi4demux is
  generic (
    nmanports   : integer;
    maxtrans    : integer range 1 to 32;
    awidth      : integer range 1 to 64;
    dwidth      : integer;
    idwidth     : integer range 0 to 2*AXI_ID_WIDTH;
    regionwidth : integer range 0 to 4 := 0
  );
  port (
    aclk    : in  std_ulogic;
    aresetn : in  std_ulogic;
    -- AXI Subordinate port
    awsel   : in  std_logic_vector(log2x(nmanports)-1 downto 0);
    arsel   : in  std_logic_vector(log2x(nmanports)-1 downto 0);
    axisi   : in  axi4_mosi_type;
    axixsi  : in  extaxi_mosi_type := extaxi_mosi_none;
    axiso   : out axi_somi_type;
    axixso  : out extaxi_miso_type;
    -- AXI manager ports
    aximo   : out axi4_mosi_vector_type(0 to nmanports-1);
    axixmo  : out extaxi_mosi_vector_type(0 to nmanports-1);
    aximi   : in  axi_somi_vector_type(0 to nmanports-1);
    axixmi  : in  extaxi_miso_vector_type(0 to nmanports-1) := (others => extaxi_miso_none)
  );
end entity;

architecture rtl of axi4demux is

  constant ASYNC_RST  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant RESET_ALL  : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

  constant nidcnt : integer := 2**idwidth;
  constant nidw   : integer := log2x(nidcnt);
  constant cw     : integer := log2x(maxtrans)+1;
  constant selw   : integer := log2x(nmanports);

  function cond(expr : boolean; a, b : std_logic) return std_logic is
  begin
    if expr then return a; else return b; end if;
  end function;

  function cond(expr : boolean; a, b : std_logic_vector) return std_logic_vector is
  begin
    if expr then return a; else return b; end if;
  end function;

  type axidparam_type is record
    sel   : std_logic_vector(selw-1 downto 0);
    count : unsigned(cw-1 downto 0);
    empty : std_logic;
  end record;
  type axidparam_array_type is array(0 to nidcnt-1) of axidparam_type;

  constant axidparam_reset : axidparam_type := (
    sel   => (others => '0'),
    count => (others => '0'),
    empty => '1'
  );

  type reg_type is record
    awidparam     : axidparam_array_type;
    wcount        : unsigned(cw-1 downto 0);
    wselect       : std_logic_vector(selw-1 downto 0);
    wselect_valid : std_logic;
    aridparam     : axidparam_array_type;
  end record;

  constant RST : reg_type := (
    awidparam     => (others => axidparam_reset),
    wcount        => (others => '0'),
    wselect       => (others => '0'),
    wselect_valid => '0',
    aridparam     => (others => axidparam_reset)
  );

  signal r, rin : reg_type;

  signal aximo_reg   : axi4_mosi_type;
  signal axixmo_reg  : extaxi_mosi_type;
  signal aximi_reg   : axi_somi_type;
  signal axixmi_reg  : extaxi_miso_type;

  signal awsel_reg  : std_logic_vector(log2x(nmanports)-1 downto 0);
  signal arsel_reg  : std_logic_vector(log2x(nmanports)-1 downto 0);

  signal bmo  : axi_b_mosi_vector_type(0 to nmanports-1);
  signal bmi  : axi_b_somi_vector_type(0 to nmanports-1);
  signal bxmi : extaxi_x_vector_type(0 to nmanports-1);

  signal rmo  : axi_r_mosi_vector_type(0 to nmanports-1);
  signal rmi  : axi_r_somi_vector_type(0 to nmanports-1);
  signal rxmi : extaxi_x_vector_type(0 to nmanports-1);

begin

  axi_slice : axi4_register_slice
    generic map (
      awidth      => awidth,
      dwidth      => dwidth,
      idwidth     => idwidth,
      regionwidth => regionwidth,
      awdirection => 0,
      wdirection  => 0,
      bdirection  => 1,
      ardirection => 0,
      rdirection  => 1
    )
    port map (
      aclk    => aclk,
      aresetn => aresetn,

      axisi   => axisi,
      axixsi  => axixsi,
      axiso   => axiso,
      axixso  => axixso,
      aximo   => aximo_reg,
      axixmo  => axixmo_reg,
      aximi   => aximi_reg,
      axixmi  => axixmi_reg
    );

  awsel_slice : register_slice
    generic map (
      dwidth    => selw,
      bypass    => 0
    )
    port map (
      clk       => aclk,
      rstn      => aresetn,

      s_xdata   => awsel,
      s_xvalid  => axisi.aw.valid,
      s_xready  => open,

      m_xdata   => awsel_reg,
      m_xvalid  => open,
      m_xready  => aximi_reg.aw.ready
    );

  arsel_slice : register_slice
    generic map (
      dwidth    => selw,
      bypass    => 0
    )
    port map (
      clk       => aclk,
      rstn      => aresetn,

      s_xdata   => arsel,
      s_xvalid  => axisi.ar.valid,
      s_xready  => open,

      m_xdata   => arsel_reg,
      m_xvalid  => open,
      m_xready  => aximi_reg.ar.ready
    );

  p_comb : process(r, aresetn, aximi, aximo_reg, axixmo_reg, aximi_reg, axixmi_reg, awsel_reg, arsel_reg)
    procedure pr_idcounters(
      axsel   : in  std_logic_vector(selw-1 downto 0);
      push_id : in  std_logic_vector(nidw-1 downto 0);
      push    : in  std_logic;
      pop_id  : in  std_logic_vector(nidw-1 downto 0);
      pop     : in  std_logic;
      param_i : in  axidparam_array_type;
      param_o : out axidparam_array_type
    ) is
      variable vpush  : std_logic;
      variable vpop   : std_logic;
      variable vparam : axidparam_array_type;
    begin
      param_o := param_i;
      for i in 0 to nidcnt-1 loop
        vpush := cond(notx(push_id) and i = unsigned(push_id), push, '0');
        vpop  := cond(notx(pop_id) and i = unsigned(pop_id), pop, '0');
        if vpush = '1' and param_i(i).empty = '1' then
          param_o(i).sel := axsel;
        end if;
        if vpush = '1' and vpop = '0' then
          param_o(i).count := param_i(i).count + 1;
          param_o(i).empty := '0';
        elsif vpush = '0' and vpop = '1' then
          if param_i(i).empty = '0' then
            param_o(i).count := param_i(i).count - 1;
            if param_i(i).count = 1 then
              param_o(i).empty := '1';
            end if;
          end if;
        end if;
      end loop;
    end procedure;

    procedure pr_idsel(
      axid  : in  std_logic_vector(nidw-1 downto 0);
      axsel : in  std_logic_vector(selw-1 downto 0);
      param : in  axidparam_array_type;
      match : out std_logic
    ) is
    begin
      match := '0';
      for i in 0 to nidcnt-1 loop
        if notx(axid) and unsigned(axid) = i then
          if (axsel = param(i).sel and param(i).count(cw-1) = '0') or param(i).empty = '1' then
            -- ID is a match and counter is not full, or the counter is empty (unused)
            match := '1';
          end if;
        end if;
      end loop;
    end procedure;

    variable v          : reg_type;
    variable awid       : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
    variable awvalid    : std_logic;
    variable awenable   : std_logic;
    variable awready    : std_logic;
    variable awmatch    : std_logic;
    variable awpush     : std_logic;
    variable wselect    : std_logic_vector(selw-1 downto 0);
    variable wfull      : std_logic;
    variable wvalid     : std_logic;
    variable wenable    : std_logic;
    variable wready     : std_logic;
    variable bid        : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
    variable arid       : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
    variable arvalid    : std_logic;
    variable arready    : std_logic;
    variable arenable   : std_logic;
    variable arpush     : std_logic;
    variable rid        : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
    variable wpop       : std_logic;
    variable bpop       : std_logic;
    variable rpop       : std_logic;
  begin
    v := r;

    awid  := axixmo_reg.aw.id & aximo_reg.aw.id;
    bid   := axixmi_reg.b.id & aximi_reg.b.id;
    arid  := axixmo_reg.ar.id & aximo_reg.ar.id;
    rid   := axixmi_reg.r.id & aximi_reg.r.id;

    -- Any AW ID may only have in flight transfers to a single port at the time to
    -- maintain AXI ordering. Check if current ID matches the current selection or if
    -- its counter is empty.
    pr_idsel(awid(nidw-1 downto 0), awsel_reg, r.awidparam, awmatch);

    -- Enable AW if ID had a match and the write channel is idle or using the same select
    awenable := '0';
    if (r.wselect_valid = '0' or r.wselect = awsel_reg) and awmatch = '1' then
      awenable := '1';
    end if;

    awvalid := aximo_reg.aw.valid and awenable;
    awready := '0';
    for i in 0 to nmanports-1 loop
      if notx(awsel_reg) and i = unsigned(awsel_reg) then
        awready := aximi(i).aw.ready;
      end if;
    end loop;

    if awvalid = '1' then
      -- Update W select register if AW is valid and enabled
      v.wselect := awsel_reg;
    end if;
    -- Push in flight counters
    awpush := awvalid and awready;

    -- Enable W on AW transfer or if the current W select is valid
    wenable := awpush or r.wselect_valid;
    wvalid  := aximo_reg.w.valid and wenable;
    wselect := cond(r.wselect_valid = '1', r.wselect, awsel_reg);
    wready  := '0';
    for i in 0 to nmanports-1 loop
      if notx(wselect) and i = unsigned(wselect) then
        wready := aximi(i).w.ready;
      end if;
    end loop;

    wpop := wvalid and wready and aximo_reg.w.last;
    -- Count up W counter on AW transfer, count down on completed W transfer
    if awpush = '1' and wpop = '0' then
      v.wcount        := r.wcount + 1;
      v.wselect_valid := '1';
    elsif awpush = '0' and wpop = '1' then
      v.wcount := r.wcount - 1;
      if r.wcount = 1 then
        v.wselect_valid := '0';
      end if;
    end if;

    -- Pop in flight write transfer on write response
    bpop := aximi_reg.b.valid and aximo_reg.b.ready;

    -- In flight transfer counters per ID for write transfers
    pr_idcounters(awsel_reg, awid(nidw-1 downto 0), awpush, bid(nidw-1 downto 0), bpop, r.awidparam, v.awidparam);

    -- Any AR ID may only have in flight transfers to a single port at the time to
    -- maintain AXI ordering. Check if current ID matches the current selection or if
    -- its counter is empty.
    pr_idsel(arid(nidw-1 downto 0), arsel_reg, r.aridparam, arenable);

    -- AR is enabled if ID had a match
    arvalid := aximo_reg.ar.valid and arenable;
    arready := '0';
    for i in 0 to nmanports-1 loop
      if notx(arsel_reg) and i = unsigned(arsel_reg) then
        arready := aximi(i).ar.ready;
      end if;
    end loop;
    -- Push to in flight counters on transfer
    arpush := arvalid and arready;

    -- Pop from in flight counters on last read response
    rpop := aximi_reg.r.valid and aximo_reg.r.ready and aximi_reg.r.last;

    -- In flight transfer counters per ID for read transfers
    pr_idcounters(arsel_reg, arid(nidw-1 downto 0), arpush, rid(nidw-1 downto 0), rpop, r.aridparam, v.aridparam);

    if not ASYNC_RST and aresetn = '0' then
      v := RST;
    end if;

    rin <= v;

    aximi_reg.aw.ready  <= awready and awenable;
    aximi_reg.w.ready   <= wready and wenable;
    aximi_reg.ar.ready  <= arready and arenable;

    -- Demux AW, W and AR. Serialize B and R
    for i in 0 to nmanports-1 loop
      -- AW
      aximo(i).aw   <= aximo_reg.aw;
      axixmo(i).aw  <= axixmo_reg.aw;
      -- W
      aximo(i).w    <= aximo_reg.w;
      -- B
      bmi(i)        <= aximi(i).b;
      bxmi(i)       <= axixmi(i).b;
      aximo(i).b    <= bmo(i);
      -- AR
      aximo(i).ar   <= aximo_reg.ar;
      axixmo(i).ar  <= axixmo_reg.ar;
      -- R
      rmi(i)        <= aximi(i).r;
      rxmi(i)       <= axixmi(i).r;
      aximo(i).r    <= rmo(i);

      -- Only propagate valid to selected port
      aximo(i).aw.valid <= '0';
      aximo(i).w.valid  <= '0';
      aximo(i).ar.valid <= '0';
      if notx(awsel_reg) and i = unsigned(awsel_reg) then
        aximo(i).aw.valid <= awvalid;
      end if;
      if notx(wselect) and i = unsigned(wselect) then
        aximo(i).w.valid  <= wvalid;
      end if;
      if notx(arsel_reg) and i = unsigned(arsel_reg) then
        aximo(i).ar.valid <= arvalid;
      end if;
    end loop;
  end process;

  p_reg : process(aclk, aresetn)
  begin
    if ASYNC_RST and aresetn = '0' then
      r <= RST;
    elsif rising_edge(aclk) then
      r <= rin;
    end if;
  end process;

  barbiter : axi4_barbiter
    generic map (
      nsub      => nmanports,
      idwidth   => idwidth,
      arb_prio  => 2,
      arb_lock  => 1
    )
    port map (
      aclk    => aclk,
      aresetn => aresetn,
      bmi     => bmi,
      bxmi    => bxmi,
      bmo     => bmo,
      bselso  => open,
      bso     => aximi_reg.b,
      bxso    => axixmi_reg.b,
      bsi     => aximo_reg.b
    );

  rarbiter : axi4_rarbiter
    generic map (
      nsub      => nmanports,
      idwidth   => idwidth,
      dwidth    => dwidth,
      arb_prio  => 2,
      arb_lock  => 1
    )
    port map (
      aclk    => aclk,
      aresetn => aresetn,
      rmi     => rmi,
      rxmi    => rxmi,
      rmo     => rmo,
      rselso  => open,
      rso     => aximi_reg.r,
      rxso    => axixmi_reg.r,
      rsi     => aximo_reg.r
    );

end architecture;