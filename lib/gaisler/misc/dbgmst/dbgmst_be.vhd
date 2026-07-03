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
-------------------------------------------------------------------------------
-- Entity:      dbgmst_be
-- File:        dbgmst_be.vhd
-- Author:      Axel Karlsson - Frontgrade Gaisler AB
--
-- Description: Debug master backend. Contains APB register interface and
--              signals to communicate with an generic_bm.
-- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;

entity dbgmst_be is
  generic (
      revision   : integer := 0;
      bustype    : integer := 0; --0 = AHB, 1 = AXI (TODO)
      max_size   : integer range 32 to 256  := 256;
      dw         : integer range 32 to 128  := 32;  --bus master data width
      addr_width : integer range 32 to 64   := 32;
      pindex     : integer;
      paddr      : integer;
      pmask      : integer
      );
    port (
      rstn             : in  std_ulogic;
      clk              : in  std_ulogic;
      apbsi            : in  apb_slv_in_type;
      apbso            : out apb_slv_out_type;
      --generic_bm signals
      --Read Channel
      bmrd_addr        : out std_logic_vector(addr_width-1 downto 0);
      bmrd_size        : out std_logic_vector(log2(max_size)-1 downto 0);
      bmrd_req         : out std_logic;
      bmrd_req_granted : in  std_logic;
      bmrd_data        : in  std_logic_vector(dw-1 downto 0);
      bmrd_valid       : in  std_logic;
      bmrd_done        : in  std_logic;
      bmrd_error       : in  std_logic;
      --Write Channel
      bmwr_addr        : out std_logic_vector(addr_width-1 downto 0);
      bmwr_size        : out std_logic_vector(log2(max_size)-1 downto 0);
      bmwr_req         : out std_logic;
      bmwr_req_granted : in  std_logic;
      bmwr_data        : out std_logic_vector(dw-1 downto 0);
      bmwr_full        : in  std_logic;
      bmwr_done        : in  std_logic;
      bmwr_error       : in  std_logic;
      -- Misc
      extaddr          : out std_logic_vector(31 downto 0);
      exe              : out std_ulogic;
      priv             : out std_ulogic
  );
end dbgmst_be;

architecture rtl of dbgmst_be is
  
  constant pconfig : apb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_DBGMST, 0, revision, 0),
    1 => apb_iobar(paddr,pmask)
    );

  type reg_type is record
    go           : std_ulogic;
    granted      : std_ulogic;
    error        : std_ulogic;
    priv         : std_ulogic;
    exe          : std_ulogic;
    reg_write    : std_logic_vector(31 downto 0);
    reg_read     : std_logic_vector(31 downto 0);
    irq          : std_logic_vector(31 downto 0);
    size         : std_logic_vector(log2(max_size)-1 downto 0);
    rw           : std_ulogic;
    addr         : std_logic_vector(63 downto 0);
    data_ptr     : std_logic_vector(log2(max_size/dw)-1 downto 0);
    data         : std_logic_vector(max_size-1 downto 0);
  end record;
  

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  
  signal r, rin : reg_type;
  
begin  -- rtl
  
  comb: process (r, rstn, apbsi, bmrd_req_granted, bmrd_data, bmrd_valid, bmrd_done, 
                 bmrd_error, bmwr_req_granted, bmwr_full, bmwr_done, bmwr_error)
    variable v            : reg_type;
    variable vrd, vwd     : std_logic_vector(31 downto 0);
    variable oapbso       : apb_slv_out_type;
    variable index        : integer;
    variable acc_done     : std_ulogic;
    variable obmrd_req    : std_logic;
    variable obmwr_req    : std_logic;
    variable obmwr_data   : std_logic_vector(dw-1 downto 0);
  begin  -- process comb

    v := r;
    -- apb
    oapbso            := apb_none;
    oapbso.pconfig    := pconfig;
    oapbso.pindex     := pindex;
    -- generic bm
    obmrd_req         := '0';
    obmwr_req         := '0';
    obmwr_data        := (others => '0');
    -- misc
    index             := 0;
    acc_done          := '0';
    v.irq := (others => '0');
    
    
    -- Control logic  -----------------------------

    -- Driving of write data
    index :=  to_integer(unsigned(r.data_ptr));
    for i in 0 to 256/dw-1 loop
      if index=i and i*dw < max_size then
        obmwr_data := r.data(dw*(i+1)-1 downto dw*i);
      end if;
    end loop;
    
    -- Main "state machine"
    if r.go = '1' then
      if r.granted = '0' then -- Request phase
        if r.rw = '0' then -- READ
          obmrd_req := '1';
          if bmrd_req_granted = '1' then
            v.granted := '1';
          end if;
        else              -- WRITE
          obmwr_req := '1';
          if bmwr_req_granted = '1' then
            v.granted := '1';
          end if;
        end if;
      else -- Data phase
        if r.rw = '0' then -- READ
          if bmrd_valid = '1' then
            v.data_ptr := r.data_ptr + '1';
            index := to_integer(unsigned(r.data_ptr));
            for i in 0 to 256/dw-1 loop
              if index=i and i*dw < max_size then
                v.data(dw*(i+1)-1 downto dw*i) := bmrd_data;
              end if;
            end loop;
            if bmrd_error = '1' then
              v.error := '1';
            end if;
            if bmrd_done = '1' then
              acc_done := '1';
            end if;
          end if;
        else               -- WRITE
          if bmwr_full = '0' then
            v.data_ptr := r.data_ptr + '1';
          end if;
          if bmwr_error = '1' then
            v.error := '1';
          end if;
          if bmwr_done = '1' then
            acc_done := '1';
          end if;
        end if;
      end if;
    end if;
    
    if acc_done = '1' then
      v.go       := '0';
      v.granted  := '0';
      v.data_ptr := (others => '0');
    end if;
    
    -- APB register interface ---------------------
    if apbsi.psel(pindex) = '1' then
      v.reg_write := apbsi.pwdata;
      if apbsi.penable = '1' or apbsi.pwrite = '0' then 
        vrd := (others => '0');
        vwd := apbsi.pwdata;
        case apbsi.paddr(4 downto 2) is
          when "000" => -- 0x00 STATUS
            if bustype = 1 then vrd(0) := '1'; end if; 
          when "001" => -- 0x04 CTRL
            vrd(0)                          := r.go;
            vrd(1)                          := r.rw;
            vrd(2)                          := r.exe;
            vrd(3)                          := r.priv;
            vrd(4)                          := r.error;
            vrd(15+r.size'length downto 16) := r.size;
            if apbsi.pwrite = '1' then
              if vwd(0) = '1' then v.go := '1'; end if;
              v.rw   := vwd(1);
              v.exe  := vwd(2);
              v.priv := vwd(3);
              v.error := r.error and not vwd(4);
              v.size := vwd(15+r.size'length downto 16);
            end if;
          when "010" => -- 0x08 ADDR_L
            vrd := r.addr(31 downto 0);
            if apbsi.pwrite = '1' then
              v.addr(31 downto 0) := vwd;
            end if;
          when "011" => -- 0x0C ADDR_H
            vrd := r.addr(63 downto 32);
            if apbsi.pwrite = '1' then
              v.addr(63 downto 32) := vwd;
            end if;
          when "100" => -- 0x10 IRQ
            if apbsi.pwrite = '1' then
              v.irq := vwd;
            end if;
          when others => null;
        end case;
        -- 0x40-0x80 DATA register
        if apbsi.paddr(6 downto 2) = "10000" then
          index := to_integer(unsigned(apbsi.paddr(5 downto 2)));
          for i in 0 to 256/32-1 loop
            if index=i and i*32 < max_size then
              vrd := r.data(32*(i+1)-1 downto  32*i);
              if apbsi.pwrite = '1' then
                v.data(32*(i+1)-1 downto  32*i) := vwd;
              end if;
            end if;
          end loop;
        end if;
        v.reg_read := vrd;
        oapbso.prdata := r.reg_read;
      end if;
    end if;
    
    
    -- Reset
    if rstn = '0' then
      v.go        := '0';
      v.rw        := '0';
      v.exe       := '0';
      v.priv      := '0';
      v.granted   := '0';
      v.error     := '0';
      v.reg_write := (others => '0');
      v.reg_read  := (others => '0');
      v.irq       := (others => '0');
      v.size      := (others => '0');
      v.addr      := (others => '0');
      v.data_ptr  := (others => '0');
      v.data      := (others => '0');
    end if;
    
    ---------------------------------------------------------------------------
    -- Signal assignments
    ---------------------------------------------------------------------------
    
    -- Core registers
    rin <= v;
    -- APB
    apbso <= oapbso;
    -- generic bm
    bmrd_addr <= r.addr(addr_width-1 downto 0);
    bmrd_size <= r.size;
    bmrd_req  <= obmrd_req;
    bmwr_addr <= r.addr(addr_width-1 downto 0);
    bmwr_size <= r.size;
    bmwr_req  <= obmwr_req;
    bmwr_data <= obmwr_data;
    -- misc
    extaddr   <= r.addr(63 downto 32);
    priv      <= r.priv;
    exe       <= r.exe;

  end process comb;

  reg: process (clk)
  begin  -- process reg
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process reg;

end rtl;
