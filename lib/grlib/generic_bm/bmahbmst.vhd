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
-- Entity:      bmahbmst
-- File:        bmahbmst.vhd
-- Company:     Cobham Gaisler AB
-- Description: Generic AHB master interface for bus master
------------------------------------------------------------------------------  

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.generic_bm_pkg.all;

entity bmahbmst is
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
    lendian_en  : integer := 0;
    addr_width  : integer := 32); 
  port (
    rst      : in  std_ulogic;
    clk      : in  std_ulogic;
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
end;

architecture rtl of bmahbmst is



  type reg_type is record
    start       : std_ulogic;
    retry       : std_ulogic;
    grant       : std_ulogic;
    active      : std_ulogic;
    lock_active : std_ulogic;
    lock_acked  : std_ulogic;
    haddr       : std_logic_vector(31 downto 0);
  end record;

  constant RES : reg_type := ('0', '0', '0', '0', '0', '0', (others=>'0'));

  signal r, rin : reg_type;

-- pragma translate_off
  signal haddr_c  : std_logic_vector(31 downto 0);
  signal htrans_c : std_logic_vector(1 downto 0);
-- pragma translate_on

begin

  comb : process(ahbi, dmai, rst, r, dma_addr, wdata, hrdata)
    variable v        : reg_type;
    variable ready    : std_ulogic;
    variable retry    : std_ulogic;
    variable mexc     : std_ulogic;
    variable inc      : std_logic_vector(5 downto 0);
    variable haddr    : std_logic_vector(31 downto 0);
    variable hwdata_v : std_logic_vector(be_dw-1 downto 0);
    variable hrdata_v : std_logic_vector(be_dw_int-1 downto 0);
    variable htrans   : std_logic_vector(1 downto 0);
    variable hwrite   : std_ulogic;
    variable hburst   : std_logic_vector(2 downto 0);
    variable newaddr  : std_logic_vector(9 downto 0);
    variable hbusreq  : std_ulogic;
    variable hprot    : std_logic_vector(3 downto 0);
  begin

    v     := r;
    ready := '0';
    mexc  := '0';
    retry := '0';
    inc   := (others => '0');
    hprot := std_logic_vector(to_unsigned(chprot, 4));  -- non-cached supervisor data

    haddr    := dma_addr;
    hbusreq  := dmai.start;
    for i in 0 to (be_dw/be_dw_int)-1 loop
      hwdata_v((i+1)*be_dw_int-1 downto i*be_dw_int) := wdata;
    end loop;
    newaddr  := dma_addr(9 downto 0);

    v.lock_active := dmai.lock_req;

    if r.lock_acked = '1' and dmai.lock_req = '0' then
      v.lock_acked := '0';
    end if;

    if dmai.burst = '0' then
      hburst := BMHBURST_SINGLE;
    else
      hburst := BMHBURST_INCR;
    end if;
    if dmai.start = '1' and (v.lock_active = '0' or r.lock_acked = '1') then
      --there is an active burst ongoing
      if (r.active and r.grant and dmai.burst and not r.retry) = '1' then
        --beats after he first beat in a burst change htrans to sequential
        htrans := BMHTRANS_SEQ;
        hburst := BMHBURST_INCR;
      else
        --first beat in a burst
        htrans := BMHTRANS_NONSEQ;
      end if;
    else
      --There is no active request or there is a locked operation
      --and the lock signal has not received the hready asserted
      --when granted
      htrans := BMHTRANS_IDLE;
    end if;

    --AHB responses
    if r.active = '1' or r.grant = '1' then
      if ahbi.hready = '1' then
        case ahbi.hresp is
          when BMHRESP_OKAY                  => ready := '1';
          when BMHRESP_RETRY | BMHRESP_SPLIT => retry := '1';
          when others                        => ready := '1';
                                                mexc := '1';
        end case;
      end if;
      if ((ahbi.hresp = BMHRESP_RETRY) or (ahbi.hresp = BMHRESP_SPLIT)) then
        v.retry := not ahbi.hready;
      else
        v.retry := '0';
      end if;
    end if;

    v.start := '0';
    if ahbi.hready = '1' then
      v.grant := ahbi.hgrant;
      if (htrans = BMHTRANS_NONSEQ) or (htrans = BMHTRANS_SEQ) or (htrans = BMHTRANS_BUSY)
        or (dmai.start = '1' and r.grant = '1' and (v.lock_active = '0' or r.lock_acked = '1')) then
        --burst become active when hrans is not idle and it was granted. For
        --locked accesses according to AHB protocol lock refers to the next
        --address hence there is one cycle IDLE before becoming active
        v.active := r.grant;
        v.start  := r.grant;
      else
        v.active := '0';
      end if;

      if (v.grant = '1' and r.lock_active = '1' and r.lock_acked = '0') then
        --next cycle bus will be granted and lock is asserted hence next
        --cycle lock will be acknowledged
        v.lock_acked := '1';
      end if;
    end if;

    if r.retry = '1' then
      htrans   := BMHTRANS_IDLE;
      v.active := '0';
    end if;

    if ahbi.hready = '1' and r.grant = '1' then
      v.haddr := haddr;
    end if;

    hrdata_v(be_dw_int-1 downto 0) := hrdata(be_dw_int-1 downto 0);
    if be_dw > be_dw_int then
      for i in 0 to (be_dw/be_dw_int)-1 loop
        if lendian_en = 0 then
          if i = unsigned(r.haddr(log_2((be_dw/16)) downto log_2(be_dw_int/8))) then
            hrdata_v := hrdata(((i+1)*be_dw_int)-1 downto i*be_dw_int);
          end if;
        end if;
       if lendian_en = 1 then
         if (be_dw/be_dw_int)-1-i = unsigned(r.haddr(log_2((be_dw/16)) downto log_2(be_dw_int/8))) then
            hrdata_v := hrdata(((i+1)*be_dw_int)-1 downto i*be_dw_int);
          end if;
        end if;
      end loop;
    end if;

    rin <= v;

    --port assignments
    ahbo.haddr   <= haddr;
    ahbo.htrans  <= htrans;
    --keep the bus request always high during locked accesses
    ahbo.hbusreq <= hbusreq or v.lock_active;
    hwdata       <= hwdata_v;
    ahbo.hlock   <= v.lock_active;
    ahbo.hwrite  <= dmai.write;
    ahbo.hsize   <= dmai.size;
    ahbo.hburst  <= hburst;
    ahbo.hprot   <= hprot;

    dmao.start  <= r.start;
    --during locked accesses the first beat is delayed one HREADY 
    dmao.grant  <= r.grant and (not(v.lock_active) or (r.lock_acked));
    dmao.active <= r.active;
    dmao.ready  <= ready;
    dmao.mexc   <= mexc;
    dmao.retry  <= retry;
    dmao.haddr  <= newaddr;
    rdata       <= hrdata_v;

    --pragma translate_off
    haddr_c  <= haddr;
    htrans_c <= htrans;
    --pragma translate_on
  end process;

  syncrst_regs : if not async_reset generate
    process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if rst = '0' then
          r <= RES;
        end if;

        --with the generic limitations on the generic_bm_ahb.vhd file the 1kB boundary
        --should never be crossed. This is an assertion in case something goes
        --wrong with a configuration is set wrongyl etc.

        --pragma translate_off
        if haddr_c(9 downto 0) = "0000000000" and htrans_c = BMHTRANS_SEQ then
          assert false report "Error:1kB boundary crossed!" severity failure;
        end if;
        --pragma translate_on
        
      end if;
    end process;
  end generate syncrst_regs;


  asyncrst_regs : if async_reset generate
    process(clk, rst)
    begin
      if rst = '0' then
        r <= RES;
      elsif rising_edge(clk) then
        r <= rin;

        --with the generic limitations on the generic_bm_ahb.vhd file the 1kB boundary
        --should never be crossed. This is an assertion in case something goes
        --wrong with a configuration is set wrongyl etc.

        --pragma translate_off
        if haddr_c(9 downto 0) = "0000000000" and htrans_c = BMHTRANS_SEQ then
          assert false report "Error:1kB boundary crossed!" severity failure;
        end if;
        --pragma translate_on
        
      end if;
    end process;
  end generate asyncrst_regs;

end;

