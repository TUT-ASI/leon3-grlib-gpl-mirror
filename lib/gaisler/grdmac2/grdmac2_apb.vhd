------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
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
-- Entity:      grdmac2_apb
-- File:        grdmac2_apb.vhd
-- Author:      Krishna K R - Cobham Gaisler AB
-- Description: APB register interface for GRDMAC2.
------------------------------------------------------------------------------ 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;
library gaisler;
use gaisler.grdmac2_pkg.all;
library techmap;
use techmap.gencomp.all;


-----------------------------------------------------------------------------
-- Entity to read and write APB registers for GRDMAC2.
-----------------------------------------------------------------------------

entity grdmac2_apb is
  generic (
    pindex   : integer                      := 0;        --APB configuartion slave index
    paddr    : integer                      := 0;        -- APB configuartion slave address
    pmask    : integer                      := 16#FF8#;  -- APB configuartion slave mask
    pirq     : integer range 0 to NAHBIRQ-1 := 0;        -- APB configuartion slave irq
    en_bm1   : integer                      := 0;        -- Enable Bus master interface index1
    ft       : integer range 0 to 5         := 0;        -- enable EDAC on RAMs (GRLIB-FT only, passed on to syncram_2pft)
                                                         -- Valid values of 'ft' : 0 to 5 for dbits =32 (ft=5 is target technology specific); 0 to 4 for dbits = 64 and 128
    abits    : integer range 0 to 10        := 4;        -- FIFO address bits (actual fifo depth = 2**abits)
    en_timer : integer                      := 0;        -- Enable timeout mechanism
    dbits    : integer range 32 to 128      := 32;       -- Data width of BM and FIFO
    en_acc   : integer range 0  to 4        := 4         -- Enable accelerators
    );
  port (
    rstn             : in  std_ulogic;                        -- Reset
    clk              : in  std_ulogic;                        -- Clock
    apbi             : in  apb_slv_in_type;                   -- APB slave input
    apbo             : out apb_slv_out_type;                  -- APB slave output
    ctrl_out         : out grdmac2_ctrl_reg_type;             -- Control configuration signals
    trst_out         : out grdmac2_trst_reg_type;             -- Timeout counter reset value
    desc_ptr_out     : out grdmac2_desc_ptr_type;             -- First descriptor pointer
    active           : out std_ulogic;                        -- GRDMAC2 enabled after reset, status
    err_status       : out std_ulogic;                        -- Core error status in APB status register
    irqf_clr_sts         : out std_ulogic;                        -- IRQ flag clear status when no error and desc completed
    irq_flag_sts     : in std_ulogic;                         -- IRQ flag     
    curr_desc_in     : in curr_des_out_type;                  -- Current descriptor fields for debug display
    curr_desc_ptr    : in std_logic_vector(31 downto 0);      -- Current descriptor pointer for debug display
    fifo_rusedw      : in std_logic_vector(abits-1 downto 0); -- FIFO read pointer
    sts_in           : in status_out_type                     -- Status flags from control module
    );
end entity grdmac2_apb;

------------------------------------------------------------------------------
-- Architecture of grdmac2_apb
------------------------------------------------------------------------------

architecture rtl of grdmac2_apb is
  attribute sync_set_reset : string;
  attribute sync_set_reset of rstn : signal is "true"; 
  -----------------------------------------------------------------------------
  -- Constant declaration
  -----------------------------------------------------------------------------

  -- Reset configuration

  constant ASYNC_RST : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  -- Plug and Play Information (APB interface)
  constant pconfig  : apb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_GRDMAC2, 0, REVISION, to_integer(to_unsigned(pirq,8))), 
    1 => apb_iobar(paddr, pmask));

  -----------------------------------------------------------------------------
  -- Signal declaration
  -----------------------------------------------------------------------------

  signal r, rin : grdmac2_reg_type;

  -----------------------------------------------------------------------------
  -- Function/procedure declaration
  -----------------------------------------------------------------------------
  
begin -- rtl

  -----------------------------------------------------------------------------
  -- Assignments
  -----------------------------------------------------------------------------
  
  apbo.pindex  <= pindex;
  apbo.pconfig <= pconfig;
  
  -----------------------------------------------------------------------------
  -- Combinational process
  -----------------------------------------------------------------------------
  
  comb : process ( apbi, r, sts_in, curr_desc_in, curr_desc_ptr, irq_flag_sts, fifo_rusedw)

    variable v      : grdmac2_reg_type;
    variable prdata : std_logic_vector (31 downto 0);
    
  begin
    -- Initialization
    v      := r;
    prdata := (others => '0');

    ----------------------
    -- core status logic
    ----------------------

    -- Core Status update
    v.sts.comp     := sts_in.comp;
    v.sts.ongoing  := sts_in.ongoing;
    v.sts.paused   := sts_in.paused;
    v.sts.timeout  := sts_in.timeout;
    v.misc.err_irq := sts_in.err;
    v.misc.cmp_irq := sts_in.desc_comp;

    -- Error updates
    if sts_in.err = '1' then
      v.sts.err := '1';
    end if;
    if sts_in.decode_desc_err = '1' then
      v.sts.decode_err := '1';
    end if;
    if sts_in.rd_desc_err = '1' then
      v.sts.rd_desc_err := '1';
    end if;
    if sts_in.pol_err = '1' then
      v.sts.pol_err := '1';
    end if;
    if sts_in.trig_err = '1' then
      v.sts.trig_err := '1';
    end if;
    if sts_in.wb_err = '1' then
      v.sts.wb_err := '1';
    end if;
    if sts_in.rd_data_err = '1' then
      v.sts.m2b_rd_data_err := '1';
    end if;
    if sts_in.wr_data_err = '1' then
      v.sts.b2m_wr_data_err := '1';
    end if;
    if sts_in.rd_nxt_ptr_err = '1' then
      v.sts.rd_nxt_ptr_err := '1';
    end if;
    if sts_in.fifo_err = '1' then
      v.sts.fifo_err := '1';
    end if;
      
    -- Set the active bit in status register when DMA is enabled after reset
    if r.ctrl.en = '1' then
      v.sts.active := '1';
    end if;

    -- Interrupt flag on descriptor completion or error
    v.sts.irq_flag := irq_flag_sts;

    -- Clear kick bit once kick status signal from grdmac_ctrl becomes zero.
    v.ctrl.kick     := '0';
    v.sts.kick_pend := sts_in.kick or r.ctrl.kick;

    -- Clear kick bit once restart status signal from grdmac_ctrl becomes zero.
    v.ctrl.restart     := '0';
    v.sts.restart_pend := sts_in.restart or r.ctrl.restart;


    ----------------------  
    -- APB address decode  
    ----------------------
    ---- Read accesses ----
    if (apbi.psel(pindex) and apbi.penable and not apbi.pwrite) = '1' then
      case apbi.paddr(7 downto 2) is
        when "000000" =>                --0x00 GRDMAC2 control register
          prdata(0) := r.ctrl.en;
          prdata(1) := r.ctrl.rst;
          prdata(2) := r.ctrl.kick;
          prdata(3) := r.ctrl.restart;
          prdata(4) := r.ctrl.irq_en;
          prdata(5) := r.ctrl.irq_msk;
          prdata(6) := r.ctrl.irq_err;
          prdata(7) := r.ctrl.te;
        when "000001" => --0x04 GRDMAC2 status register. 
          prdata(0)  := r.sts.comp;
          prdata(1)  := r.sts.err;
          prdata(2)  := r.sts.ongoing;
          prdata(3)  := r.sts.paused;
          prdata(4)  := r.sts.irq_flag;
          prdata(5)  := r.sts.restart_pend;
          prdata(6)  := r.sts.kick_pend;
          prdata(7)  := r.sts.decode_err;
          prdata(8)  := r.sts.rd_desc_err;
          prdata(9)  := r.sts.pol_err;
          prdata(10) := r.sts.trig_err;
          prdata(11) := r.sts.wb_err;
          prdata(12) := r.sts.timeout;
          prdata(13) := r.sts.m2b_rd_data_err;
          prdata(14) := r.sts.b2m_wr_data_err;
          prdata(15) := r.sts.rd_nxt_ptr_err;
          if ft /= 0 then
            prdata(16) := r.sts.fifo_err;
            if r.sts.fifo_err = '1' then
              prdata((17+abits-1) downto 17) := fifo_rusedw;
            else
              prdata((17+abits-1) downto 17) := (others => '0');
            end if;
          else
            prdata(16)                     := '0';
            prdata((17+abits-1) downto 17) := (others => '0');
          end if;
          prdata(31 downto 27) := sts_in.state;
        when "000010" => --0x08 GRDMAC2 Timer reset value register
          prdata(31 downto 0) := r.trst.trst_val;
        when "000011" => --0x0C GRDMAC2 capability register :TODO update
          prdata(3 downto 0) := conv_std_logic_vector(REVISION, 4);
          if en_bm1 = 0 then
            prdata(4) := '0';
          else
            prdata(4) := '1';            
          end if;
          prdata(7 downto 5) := conv_std_logic_vector(ft, 3);          
          if en_timer = 0 then 
            prdata(8) := '0';
          else
            prdata(8) := '1';
          end if;
          case dbits is
            when 128 =>
              prdata(11 downto 9) := "111";
            when 64 =>
              prdata(11 downto 9) := "110";
            when others => -- 32 bits
              prdata(11 downto 9) := "101";
          end case; 
          prdata(15 downto 12) := conv_std_logic_vector(en_acc,4);
          prdata(31 downto 28) := conv_std_logic_vector(abits, 4);
        when "000100" => --0x10 GRDMAC2 descriptor pointer register
          prdata(31 downto 0) := r.desc_ptr.ptr;
        when "000101" => --0x14 Current descriptor control field for debug.
          prdata(31 downto 0) := curr_desc_in.dbg_ctrl;
        when "000110" => --0x18 Current descriptor's nxt_des_ptr field for debug.
          prdata(31 downto 0) := curr_desc_in.dbg_nxt;
        when "000111" => --0x1C c_des:f_nxt_des, d_des:dest_addr
          prdata(31 downto 0) := curr_desc_in.dbg_fnxt;
        when "001000" => --0x20 c_des:cond_addr, d_des:src_addr
          prdata(31 downto 0) := curr_desc_in.dbg_cnd_addr;
        when "001001" => --0x24 c_des:status, d_des:status
          prdata(31 downto 0) :=  curr_desc_in.dbg_sts;
        when "001010" => --0x28 c_des:cond data, d_des:Null
          prdata(31 downto 0) := curr_desc_in.dbg_cnd_data;
        when "001011" => --0x2C c_des: Mask,d_des : Null
          prdata(31 downto 0) := curr_desc_in.dbg_msk;
        when "001100" => --0x30 Current descriptor pointer field for debug
          prdata(31 downto 0) := curr_desc_ptr;
        when others => 
          null;
      end case;
    end if;
    
    ---- Write accesses ----
    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite ) = '1' then
      case apbi.paddr(7 downto 2) is
        when "000000" => --0x00 GRDMAC2 control register
          v.ctrl.en      := apbi.pwdata(0);
          v.ctrl.rst     := apbi.pwdata(1);
          v.ctrl.kick    := apbi.pwdata(2);
          v.ctrl.restart := apbi.pwdata(3);
          v.ctrl.irq_en  := apbi.pwdata(4);
          v.ctrl.irq_msk := apbi.pwdata(5);
          v.ctrl.irq_err := apbi.pwdata(6);		  
          if en_timer = 1 then
           v.ctrl.te     := apbi.pwdata(7); --TODO check
          else
           v.ctrl.te     := '0'; 
          end if;
          -- If kicked or restarted, the irq_sts_clrd register bit is reset.  
          if (apbi.pwdata(2)= '1' or apbi.pwdata(3) = '1') then
            v.misc.irq_sts_clrd := '0';
          end if;  
        when "000001" => --0x04 GRDMAC2 status register. Errors are cleared on write
          v.sts.err             := r.sts.err and not(apbi.pwdata(2));		  
          v.sts.irq_flag        := r.sts.irq_flag and not(apbi.pwdata(4));
          v.sts.decode_err      := r.sts.decode_err and not(apbi.pwdata(7));
          v.sts.rd_desc_err     := r.sts.rd_desc_err and not(apbi.pwdata(8));
          v.sts.pol_err         := r.sts.pol_err and not(apbi.pwdata(9));
          v.sts.trig_err        := r.sts.trig_err and not(apbi.pwdata(10));
          v.sts.wb_err          := r.sts.wb_err and not(apbi.pwdata(11));            
          v.sts.m2b_rd_data_err := r.sts.m2b_rd_data_err and not(apbi.pwdata(13));
          v.sts.b2m_wr_data_err := r.sts.b2m_wr_data_err and not(apbi.pwdata(14));
          v.sts.rd_nxt_ptr_err  := r.sts.rd_nxt_ptr_err and not(apbi.pwdata(15));
          if ft /= 0 then
            v.sts.fifo_err := r.sts.fifo_err and not(apbi.pwdata(16));
          end if;
          -- If irq_flag status bit is cleared by user, by writing 1 to it, the irq_sts_clrd register bit is set.  
          v.misc.irq_sts_clrd := apbi.pwdata(4);
        when "000010" => --0x08 GRDMAC2 Timer reset value register
          v.trst.trst_val := apbi.pwdata(31 downto 0);
        when "000100" => --0x10 GRDMAC2 descriptor pointer register
          v.desc_ptr.ptr := apbi.pwdata(31 downto 0); 		  
        when others =>
          null;
      end case;
    end if;

    ----------------------
    -- Signal update --
    ----------------------
    if r.ctrl.rst = '1' then
      v := GRDMAC2_REG_RST;
    end if;
    rin             <= v;
    apbo.prdata     <= prdata;
    apbo.pirq       <= (others => '0');
    -- IRQ pulse generation
    -- Generating IRQ pulse only on the rising edge of the error status signal and descriptor complete signal because 
    -- the error status stays until cleared and the desc complete status stays once the last desc is completed.
    if r.misc.err_irq = '0' and sts_in.err = '1' then
      apbo.pirq(to_integer(to_unsigned(pirq,8))) <= r.ctrl.irq_en and r.ctrl.irq_err;
    elsif  r.misc.cmp_irq = '0' and sts_in.desc_comp = '1' then
      if orv(curr_desc_in.dbg_ctrl(4 downto 1))= '0' then
        apbo.pirq(to_integer(to_unsigned(pirq,8))) <= curr_desc_in.dbg_ctrl(8) and r.ctrl.irq_en and (not r.ctrl.irq_msk);
      else
        apbo.pirq(to_integer(to_unsigned(pirq,8))) <= curr_desc_in.dbg_ctrl(14) and r.ctrl.irq_en and (not r.ctrl.irq_msk);
      end if;
    end if;
    --  control signals
    ctrl_out        <= r.ctrl;
    trst_out        <= r.trst;
    desc_ptr_out    <= r.desc_ptr;
    err_status      <= r.sts.err or r.sts.decode_err or r.sts.rd_desc_err or
                       r.sts.pol_err or r.sts.trig_err or r.sts.wb_err or
                       r.sts.m2b_rd_data_err or r.sts.b2m_wr_data_err or
                       r.sts.rd_nxt_ptr_err or r.sts.fifo_err;
    irqf_clr_sts    <= r.misc.irq_sts_clrd ;
    active          <= r.sts.active;
    
  end process comb;
  
  -----------------------------------------------------------------------------
  -- Sequential process
  -----------------------------------------------------------------------------
  
  seq : process (clk, rstn)
  begin
    if (rstn = '0' and ASYNC_RST) then -- Asynchronous reset
      r <= GRDMAC2_REG_RST; 
    elsif rising_edge(clk) then
      if rstn = '0' or r.ctrl.rst = '1' then
        r <= GRDMAC2_REG_RST;
      else
        r <= rin;
      end if;
    end if;
  end process seq;
  
  -----------------------------------------------------------------------------
  -- Component instantiation
  -----------------------------------------------------------------------------

end architecture rtl;



