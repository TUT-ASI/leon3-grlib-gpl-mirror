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
-- Entity:      grdmac2
-- File:        grdmac2.vhd
-- Author:      Krishna K R - Cobham Gaisler AB
-- Description: GRDMAC2 core entity.
------------------------------------------------------------------------------ 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.config_types.all;
use grlib.config.all;
use grlib.generic_bm_pkg.log_2;
library gaisler;
use gaisler.grdmac2_pkg.all;
library techmap;
use techmap.gencomp.all;


-----------------------------------------------------------------------------
-- GRDMAC2 core
-- This is the core layer which integrates GRDMAC2 modules like CTRL, M2B, B2M
-- and APB.
-----------------------------------------------------------------------------

entity grdmac2 is
  generic (
    tech     : integer range 0 to NTECH     := inferred; -- Target technology
    -- APB configuration  
    pindex   : integer                      := 0;        -- APB configuartion slave index
    paddr    : integer                      := 0;        -- APB configuartion slave address
    pmask    : integer                      := 16#FF8#;  -- APB configuartion slave mask
    pirq     : integer range 0 to NAHBIRQ-1 := 0;        -- APB configuartion slave irq
    -- Bus master configuration
    dbits    : integer range 32 to 128      := 32;       -- Data width of BM and FIFO    
    en_bm1   : integer                      := 0;        -- Enable Bus master interface index1       
    -- Internal FIFO configuration
    ft       : integer range 0 to 5         := 0;        -- Enable EDAC on RAMs (GRLIB-FT only, passed on to syncram_2pft)
    abits    : integer range 0 to 10        := 4;        -- FIFO address bits (actual fifo depth = 2**abits)
    -- M2B/B2M configuration
    en_timer : integer                      := 0;        -- Enable timeout mechanism
    en_acc   : integer range 0 to 4         := 0        
    );
  port (
    rstn    : in  std_ulogic;                    -- Reset
    clk     : in  std_ulogic;                    -- Clock
    -- APB interface signals
    apbi    : in  apb_slv_in_type;               -- APB slave input
    apbo    : out apb_slv_out_type;              -- APB slave output
    -- Bus master signals
    bm0_in  : out bm_in_type;                    -- Input to Bus master 0
    bm1_in  : out bm_in_type;                    -- Input to Bus master 1
    bm0_out : in  bm_out_type;                   -- Output from Bus master 0
    bm1_out : in  bm_out_type;                   -- Output from Bus master 1
    bm0_endian  : in std_logic;                      -- Endianness input from BM0 '0'-> BE,'1'-> LE 
    bm1_endian  : in std_logic;                      -- Endianness input from BM1 '0'-> BE,'1'-> LE 
    -- System interrupt
    trigger : in  std_logic_vector(63 downto 0)  -- Input trigger

  );
end entity grdmac2;

------------------------------------------------------------------------------
-- Architecture of grdmac2
------------------------------------------------------------------------------

architecture rtl of grdmac2 is
  -----------------------------------------------------------------------------
  -- Constant declaration
  -----------------------------------------------------------------------------

  attribute sync_set_reset         : string;
  attribute sync_set_reset of rstn : signal is "true";
  -- Constant for bit - byte manipulation
  constant SHIFT_BIT               : natural := 3;
  constant bm_bytes                : integer := to_integer(shift_right(unsigned(conv_std_logic_vector(dbits, 9)), SHIFT_BIT));
  constant pow2_bm_bytes           : integer := log_2(bm_bytes);
  constant buff_depth              : integer := 2**(abits);                -- Buffer depth
  constant buff_bytes              : integer := 2**(abits+pow2_bm_bytes);  -- Buffer size in bytes

  -----------------------------------------------------------------------------
  -- Records and types
  -----------------------------------------------------------------------------

  -- FIFO input/output records- 
  type buf_in_type is record
    clr_n : std_ulogic;                         -- Active low (FIFO reset input port)
    ren   : std_ulogic;                         -- FIFO read enable
    wen   : std_ulogic;                         -- FIFO write enable
    wdata : std_logic_vector(dbits-1 downto 0); -- FIFO write data
  end record;

  type buf_out_type is record
    full    : std_ulogic;                                                  -- FIFO full signal
    afull   : std_ulogic;                                                  -- FIFO almost full
    empty   : std_ulogic;                                                  -- FIFO empty
    aempty  : std_ulogic;                                                  -- FIFO almost empty
    rdata   : std_logic_vector(dbits-1 downto 0);                          -- FIFO read data
    error   : std_logic_vector((((dbits+7)/8)-1)*(1-ft/4)+ft/4 downto 0);  -- FIFO error signal
    rd_ptr  : std_logic_vector(abits-1 downto 0);                          -- FIFO read pointer
  end record;

  --Reset values for fifo signals
  constant BUF_IN_RST : buf_in_type := (
    clr_n => '0',
    ren   => '0',
    wen   => '0',
    wdata => (others => '0')
    );

  constant BUF_OUT_RST : buf_out_type := (
    full   => '0',
    afull  => '0',
    empty  => '0',
    aempty => '0',
    rdata  => (others => '0'),
    error  => (others => '0'),
    rd_ptr => (others => '0')
    );    
  -----------------------------------------------------------------------------
  -- Signal declaration
  -----------------------------------------------------------------------------  
  signal bm_num        : std_ulogic;
  signal endian        : std_logic;
    -- APB interface signals
  signal ctrl_reg      : grdmac2_ctrl_reg_type;
  signal trst_reg      : grdmac2_trst_reg_type;
  signal desc_ptr_reg  : grdmac2_desc_ptr_type;
  signal err_status    : std_ulogic;
  signal err_sts_data  : std_ulogic;
  signal status        : status_out_type;
  signal active        : std_ulogic;
  signal irqf_clr_sts : std_ulogic;
  -- M2B
  signal m2b_status    : d_ex_sts_out_type;
  signal m2b_start     : std_ulogic;
  signal m2b_resume    : std_ulogic;
  signal m2b_bmo       : bm_out_type;
  signal m2b_bmi       : bm_ctrl_reg_type;
  signal buf_in_m2b    : buf_in_type;
  --signal m2b_bmi       : bm_in_type ;  
  signal m2b_buf_out   : fifo_out_type;
  signal m2b_buf_in    : fifo_in_type;
  -- B2M
  signal b2m_status    : d_ex_sts_out_type;
  signal b2m_start     : std_ulogic;
  signal b2m_resume    : std_ulogic;
  signal buf_in_b2m    : buf_in_type;
  --signal b2m_bmi       : bm_in_type;
  signal b2m_bmi       : bm_ctrl_reg_type;
  signal b2m_bmo       : bm_out_type;
  signal b2m_buf_out   : fifo_out_type;
  signal b2m_buf_in    : fifo_in_type;
  -- ACC
  signal acc_status    : d_ex_sts_out_type;
  signal acc_start     : std_ulogic;
  signal acc_resume    : std_ulogic;
  signal acc_buf_in    : fifo_in_type;
  signal acc_buf_out   : fifo_out_type;
  signal buf_in_acc    : buf_in_type;
  --Control
  signal ctrl_rst      : std_ulogic;
  signal ctrl_bmo      : bm_out_type;
  signal ctrl_bmi      : bm_in_type;
  signal curr_desc     : curr_des_out_type;
  signal curr_desc_ptr : std_logic_vector(31 downto 0);
  signal data_desc     : data_dsc_strct_type;
  signal acc_desc      : acc_dsc_strct_type;
  signal irq_flag_sts  : std_ulogic;
  -- FIFO
  signal buf_in        : buf_in_type;
  signal buf_out       : buf_out_type;
  signal buf_err       : std_logic_vector((((dbits+7)/8)-1)*(1-ft/4)+ft/4 downto 0);
  signal fifo_rusedw   : std_logic_vector(abits-1 downto 0);

  -----------------------------------------------------------------------------
  -- Function/procedure declaration
  -----------------------------------------------------------------------------
  
begin  -- rtl

  -----------------
  -- Assignments --
  -----------------
  -----------------------------------------------------------------------------
  -- Glue logic - Signal assignments
  -----------------------------------------------------------------------------
   bm1_in                                    <= ctrl_bmi                                 when (en_bm1 /= 0 and bm_num = '1')                 else BM_IN_RST;
   bm0_in                                    <= ctrl_bmi                                 when (en_bm1 = 0 or (en_bm1 /= 0 and bm_num = '0')) else BM_IN_RST;
   ctrl_bmo                                  <= bm1_out                                  when (en_bm1 /= 0 and bm_num = '1')                 else bm0_out;
   endian                                    <= bm1_endian                               when (en_bm1 /= 0 and bm_num = '1')                 else bm0_endian;

   -- BUF_IN control logic differ according to which block is operating
   ---------------------------------------------------------------------------
   buf_in_m2b.clr_n                          <= '0';
   buf_in_b2m.clr_n                          <= b2m_buf_in.clr_n                         when (b2m_status.operation = '1')                   else m2b_buf_in.clr_n;
   buf_in_acc.clr_n                          <= acc_buf_in.clr_n                         when (acc_status.operation = '1')                   else '0';
   buf_in.clr_n                              <= buf_in_acc.clr_n                         when (acc_status.operation = '1')                   else buf_in_b2m.clr_n;
   buf_in_m2b.ren                            <= '0';
   buf_in_b2m.ren                            <= b2m_buf_in.ren                           when (b2m_status.operation = '1')                   else '0';
   buf_in_acc.ren                            <= acc_buf_in.ren                           when (acc_status.operation = '1')                   else '0';
   buf_in.ren                                <= buf_in_acc.ren                           when (acc_status.operation = '1')                   else buf_in_b2m.ren;
   buf_in_b2m.wen                            <= '0';
   buf_in_m2b.wen                            <= m2b_buf_in.wen                           when (m2b_status.operation = '1')                   else '0';
   buf_in_acc.wen                            <= acc_buf_in.wen                           when (acc_status.operation = '1')                   else '0';
   buf_in.wen                                <= buf_in_acc.wen                           when (acc_status.operation = '1')                   else buf_in_m2b.wen;
   buf_in_b2m.wdata                          <= (others => '0');
   buf_in_m2b.wdata                          <= m2b_buf_in.wdata(127 downto (128-dbits)) when (m2b_status.operation = '1')                   else (others => '0');
   buf_in_acc.wdata                          <= acc_buf_in.wdata(127 downto (128-dbits)) when (acc_status.operation = '1')                   else (others => '0');
   buf_in.wdata                              <= buf_in_acc.wdata                         when (acc_status.operation = '1')                   else buf_in_m2b.wdata;
   ---------------------------------------------------------------------------
   m2b_buf_out.full                          <= buf_out.full                             when (m2b_status.operation = '1')                   else '0';
   b2m_buf_out.full                          <= buf_out.full                             when (b2m_status.operation = '1')                   else '0';
   acc_buf_out.full                          <= buf_out.full                             when (acc_status.operation = '1')                   else '0';
   m2b_buf_out.afull                         <= buf_out.afull                            when (m2b_status.operation = '1')                   else '0';
   b2m_buf_out.afull                         <= buf_out.afull                            when (b2m_status.operation = '1')                   else '0';
   acc_buf_out.afull                         <= buf_out.afull                            when (acc_status.operation = '1')                   else '0';
   m2b_buf_out.empty                         <= buf_out.empty                            when (m2b_status.operation = '1')                   else '0';
   b2m_buf_out.empty                         <= buf_out.empty                            when (b2m_status.operation = '1')                   else '0';
   acc_buf_out.empty                         <= buf_out.empty                            when (acc_status.operation = '1')                   else '0';
   m2b_buf_out.aempty                        <= buf_out.aempty                           when (m2b_status.operation = '1')                   else '0';
   b2m_buf_out.aempty                        <= buf_out.aempty                           when (b2m_status.operation = '1')                   else '0';
   acc_buf_out.aempty                        <= buf_out.aempty                           when (acc_status.operation = '1')                   else '0';
   m2b_buf_out.rdata(127 downto (128-dbits)) <= buf_out.rdata                            when (m2b_status.operation = '1')                   else (others => '0');
   b2m_buf_out.rdata(127 downto (128-dbits)) <= buf_out.rdata                            when (b2m_status.operation = '1')                   else (others => '0');
   acc_buf_out.rdata(127 downto (128-dbits)) <= buf_out.rdata                            when (acc_status.operation = '1')                   else (others => '0');

   -- buffer signals for non zero ft generic values
   buf_err <= buf_out.error when ft /= 0 else (others => '0');
   fifo_rusedw  <= buf_out.rd_ptr when ft /= 0 else (others => '0');
  -----------------------------------------------------------------------------
  -- Component instantiation
  -----------------------------------------------------------------------------

  -- APB interface
  apb : grdmac2_apb
    generic map (
      pindex   => pindex,
      paddr    => paddr,
      pmask    => pmask,
      pirq     => pirq,
      en_bm1   => en_bm1,
      ft       => ft,
      abits    => abits,
      en_timer => en_timer,
      dbits    => dbits,
      en_acc   => en_acc)
    port map (
      rstn          => rstn,
      clk           => clk,
      apbi          => apbi,
      apbo          => apbo,
      ctrl_out      => ctrl_reg,
      trst_out      => trst_reg,
      desc_ptr_out  => desc_ptr_reg,
      active        => active,
      err_status    => err_status,
      irqf_clr_sts  => irqf_clr_sts,
      irq_flag_sts  => irq_flag_sts,
      curr_desc_in  => curr_desc,
      curr_desc_ptr => curr_desc_ptr,
      fifo_rusedw   => fifo_rusedw,
      sts_in        => status
      );

  -- M2B
  m2b : mem2buf
    generic map (
      dbits      => dbits,
      bm_bytes   => bm_bytes,
      buff_bytes => buff_bytes,
      buff_depth => buff_depth,
      abits      => abits
      )
    port map (
      rstn       => rstn,
      clk        => clk,
      ctrl_rst   => ctrl_rst,
      err_sts_in => err_sts_data,
      m2b_start  => m2b_start,
      m2b_resume => m2b_resume,
      d_des_in   => data_desc,
      acc_des_in => acc_desc,
      status_out => m2b_status,
      m2b_bmi    => m2b_bmo,
      m2b_bmo    => m2b_bmi,
      buf_in     => m2b_buf_out,
      buf_out    => m2b_buf_in,
      endian     => endian
      );  

  -- B2M
  b2m : buf2mem
    generic map (
      dbits      => dbits,
      bm_bytes   => bm_bytes,
      buff_bytes => buff_bytes,
      buff_depth => buff_depth,
      abits      => abits,
      ft         => ft
      )
    port map (
      rstn       => rstn,
      clk        => clk,
      ctrl_rst   => ctrl_rst,
      err_sts_in => err_sts_data,
      b2m_start  => b2m_start,
      b2m_resume => b2m_resume,
      d_des_in   => data_desc,
      status_out => b2m_status,
      b2m_bmi    => b2m_bmo,
      b2m_bmo    => b2m_bmi,
      buf_err    => buf_err,
      buf_in     => b2m_buf_out,
      buf_out    => b2m_buf_in
      );

  -- Control module
  ctrl : grdmac2_ctrl
    generic map (
      dbits => dbits
      )  
    port map (
      rstn          => rstn,
      clk           => clk,
      trigger       => trigger,
      ctrl          => ctrl_reg,
      des_ptr       => desc_ptr_reg,
      active        => active,
      trst          => trst_reg,
      err_status    => err_status,
      irqf_clr_sts  => irqf_clr_sts,
      curr_desc_out => curr_desc,
      curr_desc_ptr => curr_desc_ptr,
      status        => status,
      irq_flag_sts  => irq_flag_sts,
      bm_in         => ctrl_bmo,
      bm_out        => ctrl_bmi,
      bm_num        => bm_num,
      m2b_bm_in     => m2b_bmi,
      m2b_bm_out    => m2b_bmo,
      b2m_bm_in     => b2m_bmi,
      b2m_bm_out    => b2m_bmo,
      d_desc_out    => data_desc,
      ctrl_rst      => ctrl_rst,
      err_sts_out   => err_sts_data,
      m2b_start     => m2b_start,
      m2b_sts_in    => m2b_status,
      m2b_resume    => m2b_resume,
      b2m_sts_in    => b2m_status,
      b2m_start     => b2m_start,
      b2m_resume    => b2m_resume,
      acc_sts_in    => acc_status,
      acc_start     => acc_start,
      acc_resume    => acc_resume,
      acc_desc_out  => acc_desc
      );  

  -- FIFO - syncfifo_2p
  fifo : syncfifo_2p
    generic map (
      tech     => tech,
      abits    => abits,
      dbits    => dbits,
      sepclk   => 0,
      afullwl  => 0,
      aemptyrl => 0,
      ft       => ft,
      rdhold    => 1
     )
    port map (
      rclk    => clk,
      rrstn   => buf_in.clr_n,
      renable => buf_in.ren,
      rfull   => open,
      rempty  => buf_out.empty,
      aempty  => buf_out.aempty,
      rusedw  => buf_out.rd_ptr,
      dataout => buf_out.rdata,
      wclk    => clk,
      wrstn   => buf_in.clr_n,
      write   => buf_in.wen,
      wfull   => buf_out.full,
      afull   => buf_out.afull,
      wempty  => open,
      wusedw  => open,
      error   => buf_out.error,
      datain  => buf_in.wdata
    );  

  -- ACC - accelerator
  acc : grdmac2_acc
    generic map (
      dbits      => dbits,
      bm_bytes   => bm_bytes,
      buff_bytes => buff_bytes,
      buff_depth => buff_depth,
      abits      => abits,
      acc_enable => en_acc
      )  
    port map (
      rstn       => rstn,
      clk        => clk,
      ctrl_rst   => ctrl_rst,
      d_des_in   => data_desc,
      acc_des_in => acc_desc,
      acc_start  => acc_start,
      acc_resume => acc_resume,
      acc_status => acc_status,
      m2b_status => m2b_status,
      endian     => endian,
      buf_in     => acc_buf_out,
      buf_out    => acc_buf_in
      );  

end architecture rtl;
