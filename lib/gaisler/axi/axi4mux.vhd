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
-- Entity:      axi4mux
-- File:        axi4mux.vhd
-- Author:      Martin Caous George - Frontgrade Gaisler AB
-- Description: AXI multiplexer
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
library techmap;
use techmap.gencomp.all;

entity axi4mux is
  generic (
    memtech     : integer := 0;
    nsubports   : integer;
    maxtrans    : integer range 1 to 32;
    awidth      : integer range 1 to 64;
    dwidth      : integer;
    idwidth     : integer range 0 to 2*AXI_ID_WIDTH;
    regionwidth : integer range 0 to 4 := 0
  );
  port (
    aclk        : in  std_ulogic;
    aresetn     : in  std_ulogic;
    -- AXI Subordinate ports
    axisi       : in  axi4_mosi_vector_type(0 to nsubports-1);
    axixsi      : in  extaxi_mosi_vector_type(0 to nsubports-1) := (others => extaxi_mosi_none);
    axiso       : out axi_somi_vector_type(0 to nsubports-1);
    axixso      : out extaxi_miso_vector_type(0 to nsubports-1);
    -- AXI manager port
    aximo       : out axi4_mosi_type;
    axixmo      : out extaxi_mosi_type;
    aximi       : in  axi_somi_type;
    axixmi      : in  extaxi_miso_type := extaxi_miso_none
  );
end;

architecture rtl of axi4mux is

  constant ASYNC_RST  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;
  constant RESET_ALL  : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

  constant selwidth   : integer := log2x(nsubports);
  constant midwidth   : integer := selwidth+idwidth;
  subtype selrange is integer range midwidth-1 downto idwidth;

  constant axwidth    : integer := idwidth+awidth+8+3+2+1+4+3+4+regionwidth;
  constant wwidth     : integer := dwidth+dwidth/8+1;

  signal awmo  : axi4_aw_mosi_vector_type(0 to nsubports-1);
  signal awxmo : extaxi_ax_vector_type(0 to nsubports-1);
  signal awmi  : axi_aw_somi_vector_type(0 to nsubports-1);
  signal wmo   : axi4_w_mosi_vector_type(0 to nsubports-1);
  signal wmi   : axi_w_somi_vector_type(0 to nsubports-1);
  signal bmo   : axi_b_mosi_vector_type(0 to nsubports-1);
  signal bmi   : axi_b_somi_vector_type(0 to nsubports-1);
  signal bxmi  : extaxi_x_vector_type(0 to nsubports-1);
  signal armo  : axi4_ar_mosi_vector_type(0 to nsubports-1);
  signal arxmo : extaxi_ax_vector_type(0 to nsubports-1);
  signal armi  : axi_ar_somi_vector_type(0 to nsubports-1);
  signal rmo   : axi_r_mosi_vector_type(0 to nsubports-1);
  signal rmi   : axi_r_somi_vector_type(0 to nsubports-1);
  signal rxmi  : extaxi_x_vector_type(0 to nsubports-1);

  signal awarbo  : axi4_aw_mosi_type;
  signal awxarbo : extaxi_ax_type;
  signal awarbi  : axi_aw_somi_type;

  signal awsel          : std_logic_vector(selwidth-1 downto 0);
  signal wfull, wempty  : std_ulogic;
  signal wpush, wpop    : std_ulogic;
  signal wsel           : std_logic_vector(selwidth-1 downto 0);
  signal arsel          : std_logic_vector(selwidth-1 downto 0);

  signal ararbo  : axi4_ar_mosi_type;
  signal arxarbo : extaxi_ax_type;

  signal axisi_reg  : axi4_mosi_type;
  signal axixsi_reg : extaxi_mosi_type;
  signal axiso_reg  : axi_somi_type;
  signal axixso_reg : extaxi_miso_type;

  -- Manager pipe

begin

  p_remap : process(awmi, wmi, bmi, bxmi, armi, rmi, rxmi, axisi, axixsi)
  begin
    for i in 0 to nsubports-1 loop
      awmo(i)     <= axisi(i).aw;
      awxmo(i)    <= axixsi(i).aw;
      axiso(i).aw <= awmi(i);

      wmo(i)      <= axisi(i).w;
      axiso(i).w  <= wmi(i);

      bmo(i)      <= axisi(i).b;
      axiso(i).b  <= bmi(i);
      axixso(i).b <= bxmi(i);

      armo(i)     <= axisi(i).ar;
      arxmo(i)    <= axixsi(i).ar;
      axiso(i).ar <= armi(i);

      rmo(i)      <= axisi(i).r;
      axiso(i).r  <= rmi(i);
      axixso(i).r <= rxmi(i);
    end loop;
  end process;

  awarbiter : axi4_awarbiter
    generic map (
      nsub        => nsubports,
      idwidth     => idwidth,
      awidth      => awidth,
      regionwidth => regionwidth,
      arb_prio    => 2,
      arb_lock    => 1
    )
    port map (
      aclk    => aclk,
      aresetn => aresetn,
      awsi    => awmo,
      awxsi   => awxmo,
      awso    => awmi,
      awselmo => awsel,
      awmo    => awarbo,
      awxmo   => awxarbo,
      awmi    => awarbi
    );

  p_awarb2reg : process(awarbo, awxarbo, axiso_reg.aw, awsel, wfull)
    variable awid : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
  begin
    axisi_reg.aw  <= awarbo;
    axixsi_reg.aw <= awxarbo;
    awarbi        <= axiso_reg.aw;

    axisi_reg.aw.valid  <= awarbo.valid and not wfull;
    awarbi.ready        <= axiso_reg.aw.ready and not wfull;

    -- Extend AWID
    awid := awxarbo.id & awarbo.id;
    awid(selrange) := awsel;
    axisi_reg.aw.id  <= awid(AXI_ID_WIDTH-1 downto 0);
    axixsi_reg.aw.id <= awid(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH);
  end process;

  wpush <= awarbo.valid and axiso_reg.aw.ready and not wfull;

  no_wsel : if nsubports <= 1 generate
    wsel      <= (others => '0');
    wfull     <= '0';
    wempty    <= '0';
    customout <= (others => '0');
  end generate;

  gen_wsel : if nsubports > 1 generate
    wselfifo : syncfifo_2p
      generic map(
        tech  => memtech,
        abits => log2x(maxtrans),
        dbits => selwidth, -- Response + last + data
        sepclk => 0, -- Not separate clocks
        afullwl => 0, -- Almost full
        aemptyrl => 0, -- No need to consider almost empty.
        fwft => 1, -- first word fall-through
        piperead => 1, -- output pipeline stage
        ft => 0,
        custombits => memtest_vlen,
        rdhold => 1
      )
      port map(
        rclk    => aclk,
        rrstn   => aresetn,
        wrstn   => aresetn,
        renable => wpop,
        rfull   => open,
        rempty  => wempty,
        aempty  => open,
        rusedw  => open,
        dataout => wsel,
        wclk    => aclk,
        write   => wpush,
        wfull   => open,
        afull   => wfull,
        wempty  => open,
        wusedw  => open,
        datain  => awsel,
        dynsync => '0',
        error    => open
      );
  end generate;

  wmux : process(wsel, wempty, wmo, axiso_reg.w)
  begin
    axisi_reg.w <= (
      data => (others => '0'),
      strb => (others => '0'),
      last => '0',
      valid => '0'
    );

    wpop <= '0';
    for i in 0 to nsubports-1 loop
      wmi(i).ready <= '0';
      if notx(wsel) and i = unsigned(wsel) then
        -- Default
        axisi_reg.w <= wmo(i);

        -- Mask valid and ready
        axisi_reg.w.valid <= wmo(i).valid and not wempty;
        wmi(i).ready      <= axiso_reg.w.ready and not wempty;

        -- Pop on last
        wpop <= wmo(i).valid and
                axiso_reg.w.ready and
                wmo(i).last and
                not wempty;
      end if;
    end loop;
  end process;

  bdemux : process(axiso_reg.b, axixso_reg.b, bmo)
    variable bidso : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
    variable bidmi : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
  begin
    bidso := axixso_reg.b.id & axiso_reg.b.id;
    bidmi := (others => '0');
    if idwidth > 0 then
      -- remove unused IDs
      bidmi(idwidth-1 downto 0) := bidso(idwidth-1 downto 0);
    end if;
    bmi <= (others => axiso_reg.b);
    axisi_reg.b.ready <= '0';
    for i in 0 to nsubports-1 loop
      bmi(i).valid <= '0';
      bmi(i).id  <= bidmi(AXI_ID_WIDTH-1 downto 0);
      bxmi(i).id <= bidmi(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH);
      if notx(bidso(selrange)) and i = unsigned(bidso(selrange)) then
        bmi(i).valid      <= axiso_reg.b.valid;
        axisi_reg.b.ready <= bmo(i).ready;
      end if;
    end loop;
  end process;

  -- AR

  ararbiter : axi4_ararbiter
    generic map (
      nsub        => nsubports,
      idwidth     => idwidth,
      awidth      => awidth,
      regionwidth => regionwidth,
      arb_prio    => 2,
      arb_lock    => 1
    )
    port map (
      aclk    => aclk,
      aresetn => aresetn,
      arsi    => armo,
      arxsi   => arxmo,
      arso    => armi,
      arselmo => arsel,
      armo    => ararbo,
      arxmo   => arxarbo,
      armi    => axiso_reg.ar
    );

  p_ararb2reg : process(ararbo, arxarbo, arsel)
    variable arid : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
  begin
    axisi_reg.ar  <= ararbo;
    axixsi_reg.ar <= arxarbo;

    -- Extend ARID
    arid := arxarbo.id & ararbo.id;
    arid(selrange) := arsel;
    axisi_reg.ar.id  <= arid(AXI_ID_WIDTH-1 downto 0);
    axixsi_reg.ar.id <= arid(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH);
  end process;

  rdemux : process(axiso_reg.r, axixso_reg.r, rmo)
    variable ridso : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
    variable ridmi : std_logic_vector(2*AXI_ID_WIDTH-1 downto 0);
  begin
    ridso := axixso_reg.r.id & axiso_reg.r.id;
    ridmi := (others => '0');
    if idwidth > 0 then
      -- remove unused IDs
      ridmi(idwidth-1 downto 0) := ridso(idwidth-1 downto 0);
    end if;
    rmi <= (others => axiso_reg.r);
    axisi_reg.r.ready <= '0';
    for i in 0 to nsubports-1 loop
      rmi(i).valid <= '0';
      rmi(i).id    <= ridmi(AXI_ID_WIDTH-1 downto 0);
      rxmi(i).id   <= ridmi(2*AXI_ID_WIDTH-1 downto AXI_ID_WIDTH);
      if notx(ridso(selrange)) and i = unsigned(ridso(selrange)) then
        rmi(i).valid      <= axiso_reg.r.valid;
        axisi_reg.r.ready <= rmo(i).ready;
      end if;
    end loop;
  end process;

  axi_slice : axi4_register_slice
    generic map (
      awidth      => awidth,
      dwidth      => dwidth,
      idwidth     => midwidth,
      regionwidth => regionwidth,
      awdirection => 1,
      wdirection  => 1,
      bdirection  => 0,
      ardirection => 1,
      rdirection  => 0
    )
    port map (
      aclk    => aclk,
      aresetn => aresetn,

      axisi   => axisi_reg,
      axixsi  => axixsi_reg,
      axiso   => axiso_reg,
      axixso  => axixso_reg,
      aximo   => aximo,
      axixmo  => axixmo,
      aximi   => aximi,
      axixmi  => axixmi
    );



end;