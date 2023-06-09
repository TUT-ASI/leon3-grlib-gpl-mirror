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
-----------------------------------------------------------------------------
-- Entity:      dmnv_ic
-- File:        dmnv_ic.vhd
-- Author:      Nils Wessman
-- Description: NOEL-V debug module: interconnect structure
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.devices.all;
use grlib.stdlib.all;
use grlib.amba.all;
--GAISLER_COM_END
--GRLIB_INTERNAL_END
--use grlib.ahbstripe.all;
--GAISLER_COM_END
--GRLIB_INTERNAL_END

entity dmnv_ic is
  generic (
    ndmamst   : integer;
    -- conv bus
    cbmidx    : integer;
    -- PnP
    dmhaddr   : integer;
    dmhmask   : integer;
    pnpaddrhi : integer;
    pnpaddrlo : integer;
    dmslvidx  : integer;
    dmmstidx  : integer
    -- pipelining 
    --; plmdata   : integer
    );
  port (
    clk     : in  std_ulogic;
    rstn    : in  std_ulogic;
    -- Debug-link interface
    dmami   : out ahb_mst_in_vector_type(ndmamst-1 downto 0);
    dmamo   : in  ahb_mst_out_vector_type(ndmamst-1 downto 0);
    -- Conventional AHB bus interface
    cbmi    : in  ahb_mst_in_type;
    cbmo    : out ahb_mst_out_type;
    cbsi    : in  ahb_slv_in_type;
    -- Debug-module AHB bus interface
    dmmi    : in  ahb_mst_in_type;
    dmmo    : out ahb_mst_out_type
    );
end;

architecture rtl of dmnv_ic is
  
  constant nbus : integer := 1+1 -- conventional + debug-module
                             ;
  constant CONV : integer := nbus-2;
  constant DM   : integer := nbus-1;
  constant busw : integer := 64* (1
                             ) 
                             ;
  constant addrw : integer := 32* (1
                             ) 
                             ;

  -- NW FIXME:
  constant RVDM_VERSION : integer := 2;
  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_RVDM, 0, RVDM_VERSION, 0),
    4 => ahb_membar(dmhaddr, '0', '0', dmhmask),
    others => zero32);
  constant onev: std_logic_vector(7 downto 0) := (others => '1');

  type dm_ic_bif_mst_in_type is record
    hgrant  : std_logic_vector(0 to 15);
    hready  : std_ulogic;
    hresp   : std_logic_vector(1 downto 0);
    hrdata  : std_logic_vector(127 downto 0);
  end record;
  type dm_ic_bif_mst_in_vector is array (nbus-1 downto 0) of dm_ic_bif_mst_in_type;

  type dm_ic_dma_state is (dsidle, dsreq, dswtfr, dsrtfr);
  type dm_ic_dma_type is record
    ds         : dm_ic_dma_state;
    hready     : std_ulogic;
    htrans     : std_logic_vector(1 downto 0);
    haddr      : std_logic_vector(31 downto 0);
    hsize      : std_logic_vector(2 downto 0);
    hwrite     : std_ulogic;
    hburst0    : std_ulogic;
    mhdata     : std_logic_vector(31 downto 0);
    bifreq     : std_logic_vector(0 to nbus-1);
    bifaddr    : std_logic_vector(addrw-1 downto 0);
    bifwen     : std_ulogic;
    phready    : std_ulogic;
  end record;
  type dm_ic_dma_vector is array(ndmamst-1 downto 0) of dm_ic_dma_type;
  constant RES_DM_IC_DMA : dm_ic_dma_type := (
    ds         => dsidle,
    hready     => '1',
    htrans     => "00",
    haddr      => (others => '0'),
    hsize      => "000",
    hwrite     => '0',
    hburst0    => '0',
    mhdata     => (others => '0'),
    bifreq     => (others => '0'),
    bifaddr    => (others => '0'),
    bifwen     => '0',
    phready    => '0'
    );


  type dm_ic_bif_state is (bsidle, bstfr1, bstfr2, bstfr3, bspartwr1);
  type dm_ic_bif_databuf is array(0 to 15) of std_logic_vector(31 downto 0);
  type dm_ic_bif_type is record
    bs      : dm_ic_bif_state;
    hbusreq : std_ulogic;
    htrans  : std_logic_vector(1 downto 0);
    haddr   : std_logic_vector(addrw-1 downto 0);
    hwrite  : std_ulogic;
    hsize   : std_logic_vector(2 downto 0);
    hburst0 : std_ulogic;
    granted : std_ulogic;
    inacc   : std_ulogic;
    mstgnt  : std_ulogic;
    arbmst  : std_logic_vector(3 downto 0);
    -- NW FIXME: maybe only one buffer...
    --databuf : std_logic_vector(31 downto 0);
    databuf : dm_ic_bif_databuf;
    wvalid  : std_logic_vector(0 to 15);
    inaccpw : std_ulogic;
  end record;
  type dm_ic_bif_vector is array(nbus-1 downto 0) of dm_ic_bif_type;
  constant RES_DM_IC_BIF : dm_ic_bif_type := (
    bs      => bsidle,
    hbusreq => '0',
    htrans  => "00",
    haddr   => (others => '0'),
    hwrite  => '0',
    hsize   => "000",
    hburst0 => '0',
    granted => '0',
    inacc   => '0',
    mstgnt  => '0',
    arbmst  => (others => '0'),
    databuf => (others => (others => '0')),
    wvalid  => (others => '0'),
    inaccpw => '0');
  
  type dm_ic_reg_type is record
    dma : dm_ic_dma_vector;
    bif : dm_ic_bif_vector;
  end record;
  constant RES : dm_ic_reg_type := (
    dma => (others => RES_DM_IC_DMA),
    bif => (others => RES_DM_IC_BIF));

  function rrarb16(req: std_logic_vector(0 to 15);
                   lastarb: std_logic_vector(3 downto 0))
    return std_logic_vector is
    variable vmask: std_logic_vector(0 to 15);
    variable vreq1: std_logic_vector(0 to 15);
    variable vreq2: std_logic_vector(0 to 31);
    variable vres: std_logic_vector(3 downto 0);
  begin
    -- Create 2xlength mask of request vreq2 taking round-robin state
    --   into account. The master to select then be found based on
    --   the first bit set to 1 in the mask.
    case lastarb is
      when "0000" => vmask := "0111111111111111";
      when "0001" => vmask := "0011111111111111";
      when "0010" => vmask := "0001111111111111";
      when "0011" => vmask := "0000111111111111";
      when "0100" => vmask := "0000011111111111";
      when "0101" => vmask := "0000001111111111";
      when "0110" => vmask := "0000000111111111";
      when "0111" => vmask := "0000000011111111";
      when "1000" => vmask := "0000000001111111";
      when "1001" => vmask := "0000000000111111";
      when "1010" => vmask := "0000000000011111";
      when "1011" => vmask := "0000000000001111";
      when "1100" => vmask := "0000000000000111";
      when "1101" => vmask := "0000000000000011";
      when "1110" => vmask := "0000000000000001";
      when others => vmask := "1111111111111111";
    end case;
    vreq2 := (req and vmask) & req(0 to 15);
    -- Binary search approach to find the index of the first 1 in the mask
    if vreq2(0 to 15)="0000000000000000" then
      vreq2(0 to 15) := vreq2(16 to 31);
    end if;
    vres := "0000";
    if vreq2(0 to 7)="00000000" then
      vres(3) := '1';
      vreq2(0 to 7) := vreq2(8 to 15);
    end if;
    if vreq2(0 to 3)="0000" then
      vres(2) := '1';
      vreq2(0 to 3) := vreq2(4 to 7);
    end if;
    if vreq2(0 to 1)="00" then
      vres(1) := '1';
      vreq2(0 to 1) := vreq2(2 to 3);
    end if;
    if vreq2(0)='0' then
      vres(0) := '1';
    end if;
    return vres;
  end rrarb16;

  function maskmatch(addrbits: std_logic_vector; haddr, hmask: integer) return std_ulogic is
    variable haddrv : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(haddr,12));
    variable hmaskv : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(hmask,12));
  begin
    if (addrbits and hmaskv) = (haddrv and hmaskv) then return '1'; else return '0'; end if;
  end;

  -- NW FIXME: ???
  function is_conv(addr : std_logic_vector) return boolean is
  begin
    return true;
  end function;

  function is_dm(addr: std_logic_vector; haddr, hmask: integer) return boolean is
  begin
    return maskmatch(addr, haddr, hmask) = '1';
  end function;

  function rep_data(d : std_logic_vector; w : integer) return std_logic_vector is
    variable data : std_logic_vector(w-1 downto 0);
  begin
    for i in 0 to w/d'length-1 loop
      data(d'length-1+i*d'length downto i*d'length) := d;
    end loop;
    return data;
  end function;

  signal r, ri  : dm_ic_reg_type;
begin
  comb : process(r, dmamo, cbmi, cbsi,
                 dmmi)
    variable v        : dm_ic_reg_type;
    variable odmami   : ahb_mst_in_vector_type(ndmamst-1 downto 0);
    variable ocbmo    : ahb_mst_out_type;
    variable odmmo    : ahb_mst_out_type;
    variable bifmi    : dm_ic_bif_mst_in_vector;
    variable vsmreq   : std_logic_vector(0 to 15);
    variable vmbifcon : std_logic_vector(0 to nbus-1);
    variable vmdone, vmcopyrd : std_ulogic;
    variable vmst     : unsigned(5 downto 0);

    variable l_endian : boolean;
  begin
    --------------------------------------------------------------------------
    -- Default
    --------------------------------------------------------------------------

    v := r;

    l_endian := (cbmi.endian = '1');

    odmami := (others => cbmi);
    for i in ndmamst-1 downto 0 loop
      odmami(i).hgrant := (others => '1');
      odmami(i).hready := r.dma(i).hready;
      -- NW FIXME: support error response ???
      odmami(i).hresp := "00";
      odmami(i).hrdata := ahbdrivedata(r.dma(i).mhdata);
    end loop;
    
    ocbmo := ahbm_none;
    ocbmo.hbusreq     := r.bif(CONV).hbusreq;
    ocbmo.htrans      := r.bif(CONV).htrans;
    ocbmo.haddr       := r.bif(CONV).haddr(31 downto 0);
    ocbmo.hwrite      := r.bif(CONV).hwrite;
    ocbmo.hsize       := r.bif(CONV).hsize;
    ocbmo.hburst      := "000";
    ocbmo.hprot       := "0000";
    ocbmo.hwdata      := ahbdrivedata(r.bif(CONV).databuf(0));
    ocbmo.hconfig(0)  := hconfig(0);
    -- NW FIXME: missing master index
    ocbmo.hindex      := cbmidx;

    odmmo := ahbm_none;
    odmmo.hbusreq     := r.bif(DM).hbusreq;
    odmmo.htrans      := r.bif(DM).htrans;
    odmmo.haddr       := r.bif(DM).haddr(31 downto 0);
    odmmo.hwrite      := r.bif(DM).hwrite;
    odmmo.hsize       := r.bif(DM).hsize;
    odmmo.hburst      := "000";
    odmmo.hprot       := "0000";
    odmmo.hwdata      := ahbdrivedata(r.bif(DM).databuf(0));
    odmmo.hconfig(0)  := hconfig(0);
    -- NW FIXME: missing master index
    odmmo.hindex      := cbmidx;

    --
    bifmi(CONV).hgrant := cbmi.hgrant;
    bifmi(CONV).hready := cbmi.hready;
    bifmi(CONV).hresp  := cbmi.hresp;
    bifmi(CONV).hrdata := rep_data(cbmi.hrdata, 128);

    -- Add PnP for debug masters and debug-module
    --if bifmi(CONV).hready='1' then -- I/O bus handling
      if r.bif(CONV).inacc='1' then
        if ( maskmatch(r.bif(CONV).haddr(31 downto 20), pnpaddrhi, 16#fff#)='1' and
            maskmatch(r.bif(CONV).haddr(19 downto  8), pnpaddrlo, 16#ff0#)='1' and
            r.bif(CONV).haddr(11)='1' and r.bif(CONV).haddr(10 downto 5)=
            std_logic_vector(to_unsigned(dmslvidx,6))) then
          bifmi(CONV).hrdata := rep_data(hconfig(to_integer(unsigned(r.bif(CONV).haddr(4 downto 2)))), 128);
        elsif ( maskmatch(r.bif(CONV).haddr(31 downto 20), pnpaddrhi, 16#fff#)='1' and
            maskmatch(r.bif(CONV).haddr(19 downto  8), pnpaddrlo, 16#ff0#)='1' and
            r.bif(CONV).haddr(11)='0' and
            unsigned(r.bif(CONV).haddr(10 downto 5))>=to_unsigned(dmmstidx,6) ) then
          vmst := unsigned(r.bif(CONV).haddr(10 downto 5))-dmmstidx;
          if vmst >= ndmamst then
            bifmi(CONV).hrdata := (others => '0');
          else
            bifmi(CONV).hrdata := rep_data(dmamo(to_integer(unsigned(vmst))).hconfig(to_integer(unsigned(r.bif(CONV).haddr(4 downto 2)))), 128);
          end if;
        --elsif r.bif(CONV).hwrite='0' then
        --  bifmi(CONV).hrdata := ahbreadword(cbmi.hrdata, r.mst_haddr(4 downto 2));
        end if;
      end if;
    --end if;

    --
    bifmi(DM).hgrant := dmmi.hgrant;
    bifmi(DM).hready := dmmi.hready;
    bifmi(DM).hresp  := dmmi.hresp;
    bifmi(DM).hrdata := rep_data(dmmi.hrdata, 128);


    --------------------------------------------------------------------------
    -- DMA master port logic
    --------------------------------------------------------------------------
    for i in ndmamst-1 downto 0 loop
      vmbifcon := (others => '0');
      for b in 0 to nbus-1 loop
        if r.bif(b).mstgnt='1' and r.bif(b).arbmst=std_logic_vector(to_unsigned(i,4)) then
          vmbifcon(b) := '1';
        end if;
      end loop;

      v.dma(i).phready := r.dma(i).hready;
      if r.dma(i).hready='1' then
        v.dma(i).htrans := dmamo(i).htrans;
        v.dma(i).haddr := dmamo(i).haddr;
        v.dma(i).hsize := dmamo(i).hsize;
        v.dma(i).hwrite := dmamo(i).hwrite;
        v.dma(i).hburst0 := dmamo(i).hburst(0);
        if dmamo(i).htrans(1) /= '0' then
          v.dma(i).hready := '0';
        end if;
        if r.dma(i).hwrite='1' then
          v.dma(i).mhdata := dmamo(i).hwdata(31 downto 0);
        end if;
      end if;
      if r.dma(i).phready='1' or r.dma(i).hready = '1' then
        if r.dma(i).hwrite='1' then
          v.dma(i).mhdata := dmamo(i).hwdata(31 downto 0);
        end if;
      end if;

      vmcopyrd := '0';
      case r.dma(i).ds is
        when dsidle => -- Default idle state
          v.dma(i).bifreq := (others => '0');
          -- Check that we are *not* connected to a stripe in this state to
          -- make sure we don't get confused by a previous access that has
          -- not yet completed on the stripe side
          vmdone := '1';
          if vmbifcon /= (vmbifcon'range => '0') then vmdone := '0'; end if;
          if r.dma(i).hready='0' and vmdone='1' then
            -- Translate address and go to request state
            v.dma(i).ds := dsreq;
            if is_dm(r.dma(i).haddr(31 downto 20), dmhaddr, dmhmask) then
              -- Debug-module area
              v.dma(i).bifreq(DM) := '1';
              v.dma(i).bifaddr := (others => '0');
              v.dma(i).bifaddr(31 downto 0) := r.dma(i).haddr(31 downto 0);
              v.dma(i).hburst0 := '0';  -- break down bursts to debug-module to single accesses
            elsif is_conv(r.dma(i).haddr) then
              -- Conventional area
              v.dma(i).bifreq(CONV) := '1';
              v.dma(i).bifaddr := (others => '0');
              v.dma(i).bifaddr(31 downto 0) := r.dma(i).haddr(31 downto 0);
              v.dma(i).hburst0 := '0';  -- break down bursts to conv area to single accesses
            end if;
          end if;
        when dsreq => -- Request access to stripe
          if r.dma(i).bifreq=vmbifcon then
            if r.dma(i).hwrite='1' then
              v.dma(i).hready := '1';
              v.dma(i).ds := dswtfr;
              -- NW FIXME: remove this to transfer the first data word correctly (delay transfer)
              --v.dma(i).bifwen := '1';
            else
              v.dma(i).ds := dsrtfr;
              v.dma(i).hready := '1';
            end if;
          end if;
          if r.dma(i).hwrite='0' then
            vmcopyrd := '1';
          end if;
        when dswtfr => -- Transfer write data
          -- Here we only manage the hready and bifwen signals, the copying
          -- from hwdata -> r.dma(i).mhdata is managed above and copying from
          -- r.dma(i).hwdata -> r.bif(s).databuf is managed inside bus-interface (stripe) FSM
          v.dma(i).bifwen := r.dma(i).hready and r.dma(i).htrans(1);
          if r.dma(i).hready='1' and dmamo(i).htrans="11" and r.dma(i).haddr(5 downto 2)/="1111" and r.dma(i).hburst0='1' then
            v.dma(i).hready := '1';
          end if;
          if r.dma(i).bifwen='1' then
            v.dma(i).bifaddr(5 downto 2) := std_logic_vector(unsigned(r.dma(i).bifaddr(5 downto 2))+1);
          end if;
          if (r.dma(i).hready='0' or r.dma(i).htrans="00") then
            v.dma(i).bifreq := (others => '0');
            v.dma(i).ds := dsidle;
          end if;
        when dsrtfr => -- Transfer read data
          vmcopyrd := '1';
          if r.dma(i).hready='1' and dmamo(i).htrans="11" and r.dma(i).haddr(5 downto 2)/="1111" and r.dma(i).hburst0 = '1' then
            v.dma(i).hready := '1';
            v.dma(i).bifaddr(5 downto 2) := std_logic_vector(unsigned(r.dma(i).bifaddr(5 downto 2))+1);
          end if;
          if (r.dma(i).hready='0' or r.dma(i).htrans="00") then
            v.dma(i).bifreq := (others => '0');
            v.dma(i).ds := dsidle;
          end if;
      end case;
      if vmcopyrd='1' then
        for b in 0 to nbus-1 loop
          if r.dma(i).bifreq(b)='1' then
            -- NW FIXME: changed to use v.dma... to select correct read data
            v.dma(i).mhdata := r.bif(b).databuf(to_integer(unsigned(v.dma(i).bifaddr(5 downto 2))));
          end if;
        end loop;
      end if;
    end loop;

    --------------------------------------------------------------------------
    -- Bus-side logic
    --------------------------------------------------------------------------
    for b in 0 to nbus-1 loop
      if bifmi(b).hready='1' then
        v.bif(b).inacc := r.bif(b).granted and r.bif(b).htrans(1);
        v.bif(b).granted := bifmi(b).hgrant(cbmidx);
      end if;
      vsmreq := (others => '0');
      for i in ndmamst-1 downto 0 loop
        vsmreq(i) := r.dma(i).bifreq(b);
      end loop;
      case r.bif(b).bs is
        when bsidle =>
          v.bif(b).hbusreq := '0';
          v.bif(b).htrans := "00";
          v.bif(b).mstgnt := '0';
          v.bif(b).wvalid := (others => '0');
          if vsmreq /= (vsmreq'range => '0') then
            v.bif(b).arbmst := rrarb16(vsmreq, r.bif(b).arbmst);
            v.bif(b).bs := bstfr1;
          end if;
          v.bif(b).haddr   := r.dma(to_integer(unsigned(v.bif(b).arbmst))).bifaddr;
          v.bif(b).hwrite  := r.dma(to_integer(unsigned(v.bif(b).arbmst))).hwrite;
          v.bif(b).hsize   := r.dma(to_integer(unsigned(v.bif(b).arbmst))).hsize;
          v.bif(b).hburst0 := r.dma(to_integer(unsigned(v.bif(b).arbmst))).hburst0;
          v.bif(b).inaccpw := '0';
        when bstfr1 =>
          v.bif(b).hbusreq := '0';
          v.bif(b).htrans := "00";
          if r.dma(to_integer(unsigned(r.bif(b).arbmst))).bifwen='1' then
            if r.bif(b).hburst0='1' then
              v.bif(b).databuf(to_integer(unsigned(v.bif(b).haddr(5 downto 2)))) :=
                r.dma(to_integer(unsigned(r.bif(b).arbmst))).mhdata;
              v.bif(b).wvalid(to_integer(unsigned(v.bif(b).haddr(5 downto 2)))) := '1';
              -- NW FIXME: need to increment databuf/wvalid pointer (haddr)
              v.bif(b).haddr(5 downto 2) :=
                std_logic_vector(unsigned(r.bif(b).haddr(5 downto 2))+1);
            else
              v.bif(b).databuf := (others => r.dma(to_integer(unsigned(r.bif(b).arbmst))).mhdata);
            end if;
          end if;
          -- For writes, raise grant to let master transfer write data
          -- For reads, we do the read first and then raise the grant
          v.bif(b).mstgnt := '0';
          if r.bif(b).hwrite='1' then
            if r.dma(to_integer(unsigned(r.bif(b).arbmst))).bifreq(b)='0' then
              if r.bif(b).hburst0='1' and r.bif(b).wvalid /= (r.bif(b).wvalid'range => '1') then
                -- Partial burst, handle in separate state
                v.bif(b).bs := bspartwr1;
                v.bif(b).haddr(5 downto 0) := "000000";
                v.bif(b).htrans(1) := r.bif(b).wvalid(0);
              else
                v.bif(b).bs := bstfr2;
                v.bif(b).hbusreq := '1';
                v.bif(b).htrans := "10";
                if r.bif(b).hburst0='1' then
                  v.bif(b).haddr(5 downto 0) := "000000";
                  -- NW FIXME: need to set size = bus width for reads and full-buffer writes
                  if busw = 64 then 
                    v.bif(b).hsize := "011";
                  elsif busw = 128 then
                    v.bif(b).hsize := "100";
                  end if;
                end if;
              end if;
            else
              v.bif(b).mstgnt := '1';
            end if;
          else
            v.bif(b).bs := bstfr2;
            v.bif(b).hbusreq := '1';
            v.bif(b).htrans := "10";
            if r.bif(b).hburst0='1' then
              v.bif(b).haddr(5 downto 0) := "000000";
              -- NW FIXME: need to set size = bus width for reads and full-buffer writes
              if busw = 64 then 
                v.bif(b).hsize := "011";
              elsif busw = 128 then
                v.bif(b).hsize := "100";
              end if;
            end if;
          end if;
          v.bif(b).inaccpw := '0';
        when bstfr2 =>
          v.bif(b).mstgnt := '0';
          -- Data handling
          if bifmi(b).hready='1' and r.bif(b).inacc='1' and bifmi(b).hresp(1)='0' then
            -- For bursts, we use the data buffer as a shift register where hwdata goes
            -- out in the front and hrdata goes into the back. This avoids
            -- having to add muxing logic on hwdata/hrdata to the striped bus.
            -- For single access, we replicate data everywhere in the buffer
            -- to allow the same muxing logic to be used in the dma master side
            if r.bif(b).hburst0='1' then
              v.bif(b).databuf(0 to 15-(busw/32)) := r.bif(b).databuf((busw/32) to 15);
              for x in 0 to busw/32 - 1 loop
                if not l_endian then
                  v.bif(b).databuf(15-(busw/32)+x+1) := bifmi(b).hrdata(busw-x*32-1 downto busw-x*32-32);
                else
                  v.bif(b).databuf(15-(busw/32)+x+1) := bifmi(b).hrdata(32+x*32-1 downto x*32);
                end if;
              end loop;
            else
              for x in 0 to 15 loop
                if not l_endian then
                  v.bif(b).databuf(x) := bifmi(b).hrdata(busw-(x*32 mod busw)-1 downto busw-(x*32 mod busw)-32);
                else
                  v.bif(b).databuf(x) := bifmi(b).hrdata(32+(x*32 mod busw)-1 downto (x*32 mod busw));
                end if;
              end loop;
            end if;
          end if;
          -- Address/control handling
          if bifmi(b).hready='1' and r.bif(b).inacc='1' and bifmi(b).hresp(1)='0' and r.bif(b).htrans(1)='0' then
            -- All done!
            if r.bif(b).hwrite='0' then
              v.bif(b).mstgnt := '1';
              v.bif(b).bs := bstfr3;
            else
              v.bif(b).bs := bsidle;
            end if;
          elsif bifmi(b).hready='1' and r.bif(b).inacc='1' and bifmi(b).hresp(1)='1' then
            -- retry/split second phase
            v.bif(b).htrans := "10";
            v.bif(b).hbusreq := '1';
          elsif bifmi(b).hready='0' and r.bif(b).inacc='1' and bifmi(b).hresp(1)='1' then
            -- retry/split first phase, back off from bus to restart access
            v.bif(b).htrans := "00";
            if r.bif(b).hburst0 = '1' then
              v.bif(b).haddr(5 downto log2(busw/8)) :=
                std_logic_vector(unsigned(r.bif(b).haddr(5 downto log2(busw/8)))-1);
            end if;
            v.bif(b).hbusreq := '1';
          elsif bifmi(b).hready='1' and r.bif(b).granted='1' and r.bif(b).htrans(1)='1' then
            -- advance burst
            if r.bif(b).hburst0 = '1' then
              v.bif(b).haddr(5 downto log2(busw/8)) :=
                std_logic_vector(unsigned(r.bif(b).haddr(5 downto log2(busw/8)))+1);
            end if;
            v.bif(b).htrans := "11";
            if r.bif(b).hburst0='0' or r.bif(b).haddr(5 downto log2(busw/8))=onev(5 downto log2(busw/8)) then
              v.bif(b).htrans := "00";
            end if;
          end if;
          v.bif(b).inaccpw := '0';
        when bstfr3 =>
          -- For read, wait for request to go low so we know the read data
          -- has been consumed
          v.bif(b).mstgnt := '1';
          if r.dma(to_integer(unsigned(r.bif(b).arbmst))).bifreq(b)='0' then
            v.bif(b).mstgnt := '0';
            v.bif(b).bs := bsidle;
          end if;
          v.bif(b).inaccpw := '0';
        when bspartwr1 =>
          -- Handle a partial write burst from a master
          -- This is done in a quite inefficient way, by "walking" through the
          -- wvalid mask and creating single 32-bit accesses for the ones that
          -- are set and idle transfers for the ones that are not set.
          if bifmi(b).hready='1' and r.bif(b).inaccpw='1' then
            v.bif(b).databuf(0 to 15-(busw/32)) := r.bif(b).databuf((busw/32) to 15);
            if r.bif(b).wvalid=(r.bif(b).wvalid'range => '0') then
              v.bif(b).bs := bsidle;
            end if;
          end if;
          if bifmi(b).hready='1' then
            v.bif(b).inaccpw := '0';
          end if;
          if bifmi(b).hready='1' and ((r.bif(b).granted='1' and r.bif(b).htrans(1)='1') or r.bif(b).htrans(1)='0') then
            v.bif(b).haddr(5 downto 2) :=
              std_logic_vector(unsigned(r.bif(b).haddr(5 downto 2))+1);
            v.bif(b).wvalid := r.bif(b).wvalid(1 to 15) & '0';
            -- NW FIXME: correct offset, when to shift data buffer
            --if (busw=64 and r.bif(b).haddr(3 downto 2)="11") or (busw=128 and r.bif(b).haddr(4 downto 2)="111") then
            if (busw=64 and r.bif(b).haddr(2)='1') or (busw=128 and r.bif(b).haddr(3 downto 2)="11") then
              v.bif(b).inaccpw := '1';
            end if;
          end if;
          v.bif(b).htrans(1) := v.bif(b).wvalid(0);
          v.bif(b).hbusreq := v.bif(b).htrans(1);
      end case;
    end loop;

    --------------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------------
  
    ri <= v;
    dmami <= odmami;
    cbmo  <= ocbmo;
    dmmo  <= odmmo;

  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= ri;

      if rstn = '0' then
        for i in 0 to ndmamst-1 loop
          r.dma(i).ds     <= RES.dma(i).ds;
          r.dma(i).hready <= RES.dma(i).hready;
        end loop;
        for i in 0 to nbus-1 loop
          r.bif(i).bs       <= RES.bif(i).bs;
          r.bif(i).hbusreq  <= RES.bif(i).hbusreq;
          r.bif(i).htrans   <= RES.bif(i).htrans;
          r.bif(i).arbmst   <= RES.bif(i).arbmst;
        end loop;
      end if;
    end if;
  end process;
end;

