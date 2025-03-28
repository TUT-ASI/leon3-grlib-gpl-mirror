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
-- Entity:      ahb2mig_7series_cpci_xc7k
-- File:        ahb2mig_7series_cpci_xc7k.vhd
-- Based on:    ahb2mig_7series_ddr2_dq16_ad13_ba3.vhd
--
--  Notes: - works only with 32-bit bus
--         - does not replicate output data
--         - does not support MIG interface model
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library gaisler;
use gaisler.all;
use gaisler.ahb2mig_7series_pkg.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;
library std;
use std.textio.all;

entity ahb2mig_7series_cpci_xc7k is
  generic(
    hindex                  : integer := 0;
    haddr                   : integer := 0;
    hmask                   : integer := 16#f00#;
    pindex                  : integer := 0;
    paddr                   : integer := 0;
    pmask                   : integer := 16#fff#;
    maxwriteburst           : integer := 8;
    maxreadburst            : integer := 8;
    SIM_BYPASS_INIT_CAL     : string  := "OFF";
    SIMULATION              : string  := "FALSE";
    USE_MIG_INTERFACE_MODEL : boolean := false
  );
  port(
    ddr3_dq           : inout std_logic_vector(15 downto 0);
    ddr3_dqs_p        : inout std_logic_vector(1 downto 0);
    ddr3_dqs_n        : inout std_logic_vector(1 downto 0);
    ddr3_addr         : out   std_logic_vector(14 downto 0);
    ddr3_ba           : out   std_logic_vector(2 downto 0);
    ddr3_ras_n        : out   std_logic;
    ddr3_cas_n        : out   std_logic;
    ddr3_we_n         : out   std_logic;
    ddr3_reset_n      : out   std_logic;
    ddr3_ck_p         : out   std_logic_vector(0 downto 0);
    ddr3_ck_n         : out   std_logic_vector(0 downto 0);
    ddr3_cke          : out   std_logic_vector(0 downto 0);
    ddr3_dm           : out   std_logic_vector(1 downto 0);
    ddr3_odt          : out   std_logic_vector(0 downto 0);
    ddr3_cs_n         : out   std_logic_vector(0 downto 0);
    ahbso             : out   ahb_slv_out_type;
    ahbsi             : in    ahb_slv_in_type;
    apbi              : in    apb_slv_in_type;
    apbo              : out   apb_slv_out_type;
    calib_done        : out   std_logic;
    rst_n_syn         : in    std_logic;
    rst_n_async       : in    std_logic;
    clk_amba          : in    std_logic;
    sys_clk_i         : in    std_logic;
    clk_ref_i         : in    std_logic;
    ui_clk            : out   std_logic;
    ui_clk_sync_rst   : out   std_logic
   );
end ;
 
architecture rtl of ahb2mig_7series_cpci_xc7k is

type bstate_type is (idle, start, read_cmd, read_data, read_wait, read_output, write_cmd, write_burst);

constant maxburst    : integer := 8;
constant maxmigcmds  : integer := 3;
constant wrsteps     : integer := log2(32);
constant wrmask      : integer := log2(32/8);

constant hconfig : ahb_config_type := (
   0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
   4 => ahb_membar(haddr, '1', '1', hmask),
   others => zero32);

constant pconfig : apb_config_type := (
  0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
  1 => apb_iobar(paddr, pmask));

type reg_type is record
  bstate          : bstate_type;
  cmd             : std_logic_vector(2 downto 0);
  cmd_en          : std_logic;
  wr_en           : std_logic;
  wr_end          : std_logic;
  cmd_count       : unsigned(31 downto 0);
  wr_count        : unsigned(31 downto 0);
  rd_count        : unsigned(31 downto 0);
  hready          : std_logic;
  hwrite          : std_logic;
  hwdata_burst    : std_logic_vector(128*maxmigcmds-1 downto 0);
  mask_burst      : std_logic_vector(16*maxmigcmds-1 downto 0);
  htrans          : std_logic_vector(1 downto 0);
  hburst          : std_logic_vector(2 downto 0);
  hsize           : std_logic_vector(2 downto 0);
  hrdata          : std_logic_vector(AHBDW-1 downto 0);
  haddr           : std_logic_vector(31 downto 0);
  haddr_start     : std_logic_vector(31 downto 0);
  haddr_offset    : std_logic_vector(31 downto 0);
  hmaster         : std_logic_vector(3 downto 0);
  int_buffer      : unsigned(128*maxmigcmds-1 downto 0);
  rd_buffer       : unsigned(128*maxmigcmds-1 downto 0);
  wdf_data_buffer : std_logic_vector(127 downto 0);
  wdf_mask_buffer : std_logic_vector(15 downto 0);
  migcommands     : integer;
  nxt            : std_logic;
  maxrburst       : integer;
end record;

type mig_in_type is record
  app_addr        : std_logic_vector(28 downto 0);
  app_cmd         : std_logic_vector(2 downto 0);
  app_en          : std_logic;
  app_wdf_data    : std_logic_vector(127 downto 0);
  app_wdf_end     : std_logic;
  app_wdf_mask    : std_logic_vector(15 downto 0);
  app_wdf_wren    : std_logic;
end record;

type mig_out_type is record
  app_rd_data       : std_logic_vector(127 downto 0);
  app_rd_data_end   : std_logic;
  app_rd_data_valid : std_logic;
  app_rdy           : std_logic;
  app_wdf_rdy       : std_logic;
end record;

signal rin, r, rnxt, rnxtin      : reg_type;
signal migin            : mig_in_type;
signal migout,migoutraw : mig_out_type;

 component mig is
   port (
    ddr3_dq              : inout std_logic_vector(15 downto 0);
    ddr3_addr            : out   std_logic_vector(14 downto 0);
    ddr3_ba              : out   std_logic_vector(2 downto 0);
    ddr3_ras_n           : out   std_logic;
    ddr3_cas_n           : out   std_logic;
    ddr3_we_n            : out   std_logic;
    ddr3_reset_n         : out   std_logic;
    ddr3_dqs_n           : inout std_logic_vector(1 downto 0);
    ddr3_dqs_p           : inout std_logic_vector(1 downto 0);
    ddr3_ck_p            : out   std_logic_vector(0 downto 0);
    ddr3_ck_n            : out   std_logic_vector(0 downto 0);
    ddr3_cke             : out   std_logic_vector(0 downto 0);
    ddr3_cs_n            : out   std_logic_vector(0 downto 0);
    ddr3_dm              : out   std_logic_vector(1 downto 0);
    ddr3_odt             : out   std_logic_vector(0 downto 0);
    sys_clk_i            : in    std_logic;
    clk_ref_i            : in    std_logic;
    app_addr             : in    std_logic_vector(28 downto 0);
    app_cmd              : in    std_logic_vector(2 downto 0);
    app_en               : in    std_logic;
    app_wdf_data         : in    std_logic_vector(127 downto 0);
    app_wdf_end          : in    std_logic;
    app_wdf_mask         : in    std_logic_vector(15 downto 0);
    app_wdf_wren         : in    std_logic;
    app_rd_data          : out   std_logic_vector(127 downto 0);
    app_rd_data_end      : out   std_logic;
    app_rd_data_valid    : out   std_logic;
    app_rdy              : out   std_logic;
    app_wdf_rdy          : out   std_logic;
    app_sr_req           : in    std_logic;
    app_ref_req          : in    std_logic;
    app_zq_req           : in    std_logic;
    app_sr_active        : out   std_logic;
    app_ref_ack          : out   std_logic;
    app_zq_ack           : out   std_logic;
    ui_clk               : out   std_logic;
    ui_clk_sync_rst      : out   std_logic;
    init_calib_complete  : out   std_logic;
    sys_rst              : in    std_logic
    );
 end component mig;

begin

  comb: process( rst_n_syn, r, rin, ahbsi, migout )

  -- Design temp variables
  variable v,vnxt                : reg_type;
  variable writedata              : std_logic_vector(255 downto 0);
  variable wmask                  : std_logic_vector(AHBDW/4-1 downto 0);
  variable shift_steps            : natural;
  variable hrdata_shift_steps     : natural;
  variable steps_write            : unsigned(31 downto 0);
  variable shift_steps_write      : natural;
  variable shift_steps_write_mask : natural;
  variable startaddress           : unsigned(v.haddr'length-1 downto 0);
  variable start_address          : std_logic_vector(v.haddr'length-1 downto 0);
  variable step_offset            : unsigned(steps_write'length-1 downto 0);
  variable haddr_offset           : unsigned(steps_write'length-1 downto 0);

  begin   

    -- Make all register visible for the statemachine
    v := r; vnxt := rnxt;

    -- workout the start address in AHB2MIG buffer based upon
    startaddress := resize(unsigned(unsigned(ahbsi.haddr(ahbsi.haddr'left-5 downto 4)) & "000"),startaddress'length);

    -- Adjust offset in memory buffer    
    start_address := std_logic_vector(startaddress);

    -- Workout local offset to be able to adust for warp-around
    haddr_offset := unsigned(r.haddr_start) - unsigned(unsigned(r.haddr_offset(r.haddr_offset'length-1 downto 4))&"0000");
    
    step_offset := resize(unsigned(haddr_offset(5 downto 4)&"00"),step_offset'length);

    -- Fetch AMBA Commands
    if (( ahbsi.hsel(hindex) and ahbsi.htrans(1) and ahbsi.hready and not ahbsi.htrans(0)) = '1'
       and (ahbsi.hwrite = '0' or ahbsi.hwrite = '1' )) then

      vnxt.cmd_count:= (others => '0');
      vnxt.wr_count := (others => '0');
      vnxt.rd_count := (others => '0');
      vnxt.hrdata   := (others => '0');

      -- Clear old pointers and MIG command signals
      vnxt.cmd          := (others => '0');
      vnxt.cmd_en       := '0';
      vnxt.wr_en        := '0';
      vnxt.wr_end       := '0';
      vnxt.hwrite       := '0';
      vnxt.hwdata_burst := (others => '0');
      vnxt.mask_burst   := (others => '0');

      -- Hold info regarding transaction and execute
      vnxt.hburst          := ahbsi.hburst;
      vnxt.hwrite          := ahbsi.hwrite;
      vnxt.hsize           := ahbsi.hsize;
      vnxt.hmaster         := ahbsi.hmaster;
      vnxt.hready          := '0';
      vnxt.htrans          := ahbsi.htrans;
      vnxt.bstate          := start;
      vnxt.haddr           := start_address;
      vnxt.haddr_start     := ahbsi.haddr;
      vnxt.haddr_offset    := ahbsi.haddr;
      vnxt.cmd(2 downto 0) := (others => '0');
      vnxt.cmd(0)          := not ahbsi.hwrite;
      if (r.bstate = idle) then vnxt.nxt := '0'; else vnxt.nxt := '1'; end if;
      
      -- Clear some old stuff
      vnxt.int_buffer      := (others => '0');
      vnxt.rd_buffer       := (others => '0');
      vnxt.wdf_data_buffer := (others => '0');
      vnxt.wdf_mask_buffer := (others => '0');
      
    end if;

    case r.bstate is
    when idle =>
      -- Clear old pointers and MIG command signals
      v.cmd      := (others => '0');
      v.cmd_en   := '0';
      v.wr_en    := '0';
      v.wr_end   := '0';
      v.hready   := '1';
      v.hwrite   := '0';
      v.hwdata_burst := (others => '0');
      v.mask_burst := (others => '0');
      v.rd_count := (others => '0');

      vnxt.cmd      := (others => '0');
      vnxt.cmd_en   := '0';
      vnxt.wr_en    := '0';
      vnxt.wr_end   := '0';
      vnxt.hready   := '1';
      vnxt.hwrite   := '0';
      vnxt.hwdata_burst := (others => '0');
      vnxt.mask_burst := (others => '0');
      vnxt.rd_count := (others => '0');
      vnxt.wr_count := (others => '0');
      vnxt.cmd_count := (others => '0');

      -- Check if this is a single or burst transfer (and not a BUSY transfer)
      if (( ahbsi.hsel(hindex) and ahbsi.htrans(1) and ahbsi.hready) = '1'
         and (ahbsi.hwrite = '0' or ahbsi.hwrite = '1' )) then

        -- Hold info regarding transaction and execute
        v.hburst      := ahbsi.hburst;
        v.hwrite      := ahbsi.hwrite;
        v.hsize       := ahbsi.hsize;
        v.hmaster     := ahbsi.hmaster;
        v.hready      := '0';
        v.htrans      := ahbsi.htrans;
        v.bstate      := start;
        v.haddr       := start_address;
        v.haddr_start := ahbsi.haddr;
        v.haddr_offset := ahbsi.haddr;
        v.cmd         := (others => '0');
        v.cmd(0)      := not ahbsi.hwrite;
      end if;

    when start =>
      v.migcommands := nbrmigcmds16(r.hwrite,r.hsize,ahbsi.htrans,step_offset,AHBDW);

      -- Check if a write command shall be issued to the DDR3 memory
      if r.hwrite = '1' then

         wmask     := (others => '0');
         writedata := (others => '0');

         if ((ahbsi.htrans /= HTRANS_SEQ) or ((ahbsi.htrans = HTRANS_SEQ) and (r.rd_count > 0) and (r.rd_count <= maxburst))) then
             -- work out how many steps we need to shift the input
             steps_write := ahbselectdatanoreplicastep16(r.haddr_start(7 downto 2),r.hsize(2 downto 0)) + step_offset;
             shift_steps_write := to_integer(shift_left(steps_write,wrsteps));
             shift_steps_write_mask := to_integer(shift_left(steps_write,wrmask));

             -- generate mask for complete burst (only need to use addr[3:0])
             wmask := ahbselectdatanoreplicamask(r.haddr_start(6 downto 0),r.hsize(2 downto 0));
             v.mask_burst := r.mask_burst or std_logic_vector(shift_left(resize(unsigned(wmask), r.mask_burst'length),shift_steps_write_mask));

             -- fetch all wdata before write to memory can begin (only supports upto 128bits i.e. addr[4:0]
             writedata(AHBDW-1 downto 0) := ahbselectdatanoreplica(ahbsi.hwdata(AHBDW-1 downto 0),r.haddr_start(4 downto 0),r.hsize(2 downto 0));
             v.hwdata_burst := r.hwdata_burst or std_logic_vector(shift_left(resize(unsigned(writedata),v.hwdata_burst'length),shift_steps_write));

             v.haddr_start := ahbsi.haddr;
         end if;

         -- Check if this is a cont burst longer than internal buffer
         if (ahbsi.htrans = HTRANS_SEQ) then
            if (r.rd_count < maxburst-1) then
               v.hready := '1';
            else
               v.hready := '0';
            end if;
            if (r.rd_count >= maxburst) then
                 if (r.htrans = HTRANS_SEQ) then
                   v.bstate   := write_cmd;
                 end if;
               v.htrans   := ahbsi.htrans;
            end if;
         else
            v.bstate   := write_cmd;
            v.htrans   := ahbsi.htrans;
         end if;

      -- Else issue a read command when ready
      else
        if migout.app_rdy = '1' and migout.app_wdf_rdy = '1' then
           v.cmd := "001";
           v.bstate := read_cmd;
           v.htrans := ahbsi.htrans;
           v.cmd_count := to_unsigned(0,v.cmd_count'length);
        end if;
      end if;

    when write_cmd =>

      -- Check if burst has ended due to max size burst
      if (ahbsi.htrans /= HTRANS_SEQ) then
         v.htrans := (others => '0');
      end if;

      -- Stop when addr and write command is accepted by mig
      if (r.wr_count >= r.migcommands) and (r.cmd_count >= r.migcommands) then
          if (r.htrans /= HTRANS_SEQ) then
             -- Check if we have a pending transaction
             if (vnxt.nxt = '1') then
                v := vnxt;
                vnxt.nxt := '0'; 
             else
                v.bstate      := idle;
             end if;
          else -- Cont burst and work out new offset for next write command
             v.bstate      := write_burst;
             v.hready := '1';
          end if;
      end if;

    when write_burst =>
       v.bstate       := start;
       v.hready       := '0';
       v.hwdata_burst := (others => '0');
       v.mask_burst   := (others => '0');
       v.haddr        := start_address;
       v.haddr_offset := ahbsi.haddr;

       -- Check if we have a pending transaction
       if (vnxt.nxt = '1') then
          v := vnxt;
          vnxt.nxt := '0'; 
       end if;

    when read_cmd =>
      v.hready   := '0';
      v.rd_count := (others => '0');
      -- stop when read command is accepted ny mig.
      if (r.cmd_count >= r.migcommands) then
          v.bstate := read_data;
          --v.int_buffer := (others => '0');
      end if;

    when read_data =>
      -- We are not ready yet so issue a read command to the memory controller
      v.hready := '0';

      -- If read data is valid store data in buffers
      if (migout.app_rd_data_valid = '1') then
           v.rd_count   := r.rd_count + 1;
           -- Viviado seems to misinterpet the following shift construct and
           -- therefore changed to a if-else statement
           --v.int_buffer := r.int_buffer or shift_left( resize(unsigned(migout.app_rd_data),r.int_buffer'length),
           --                                           to_integer(shift_left(r.rd_count,9)));
           if (r.rd_count = 0) then
              v.int_buffer(127 downto 0) := unsigned(migout.app_rd_data);
           elsif (r.rd_count = 1) then
              v.int_buffer(255 downto 128) := unsigned(migout.app_rd_data);
           end if;
      end if;

      if (r.rd_count >= r.migcommands) then
         v.rd_buffer := r.int_buffer;
         v.bstate := read_output;
         v.rd_count := to_unsigned(0,v.rd_count'length);
      end if;

    when read_output =>

      -- Data is fetched from memory and ready to be transfered
      v.hready := '1';

      -- uses the "wr_count" signal to keep track of number of bytes output'd to AHB
      -- Select correct 32bit output
      v.hrdata := ahbselectdatanoreplicaoutput16(r.haddr_start(7 downto 0),r.wr_count,r.hsize,r.rd_buffer,r.wr_count,false);

      -- Count number of bytes send
      v.wr_count := r.wr_count + 1;

      -- Set maximum read burst depending on the starting address offset
      case r.haddr_start(3 downto 2) is
        when "01" => v.maxrburst := 7;
        when "10" => v.maxrburst := 6;
        when "11" => v.maxrburst := 5;
        when others => v.maxrburst := 8;
      end case;

      -- Check if this was the last transaction
      if (r.wr_count >= v.maxrburst-1) then
         v.bstate := read_wait;
      end if;

      -- Check if transfer was interrupted or no burst
      if (ahbsi.htrans = HTRANS_IDLE) or ((ahbsi.htrans = HTRANS_NONSEQ) and (r.wr_count < maxburst)) then
         v.bstate := read_wait;
         v.wr_count := (others => '0');
         v.rd_count := (others => '0');
         v.cmd_count := (others => '0');

         -- Check if we have a pending transaction
         if (vnxt.nxt = '1') then
            v := vnxt;
            vnxt.nxt := '0'; 
            v.bstate   := start;
         end if;
      end if;

    when read_wait =>
      if ((r.wr_count >= v.maxrburst) and (ahbsi.htrans = HTRANS_SEQ)) then
         v.hready       := '0';
         v.bstate       := start;
         v.haddr_start  := ahbsi.haddr;
         v.haddr        := start_address;
         v.haddr_offset := ahbsi.haddr;
      else
         -- Check if we have a pending transaction
         if (vnxt.nxt = '1') then
            v := vnxt;
            vnxt.nxt := '0'; 
            v.bstate   := start;
         else
            v.bstate := idle;
            v.hready := '1';
         end if;
      end if;

    when others =>
      v.bstate := idle;
    end case;

    if ((ahbsi.htrans /= HTRANS_SEQ) and (r.bstate = start)) then
       v.hready  := '0';
    end if;

    if rst_n_syn = '0' then
      v.bstate := idle; v.hready := '1'; v.cmd_en := '0'; v.wr_en := '0'; v.wr_end := '0'; v.maxrburst := maxburst;
    end if;

    rin <= v;
    rnxtin <= vnxt;

  end process;

  ahbso.hready  <= r.hready;
  ahbso.hresp   <= "00";
  ahbso.hrdata  <= ahbdrivedata(r.hrdata);

  migin.app_addr <= r.haddr(28 downto 2) & "00";
  migin.app_cmd  <= r.cmd;
  migin.app_en   <= r.cmd_en;

  migin.app_wdf_data  <= r.wdf_data_buffer;
  migin.app_wdf_end   <= r.wr_end;
  migin.app_wdf_mask  <= r.wdf_mask_buffer;
  migin.app_wdf_wren  <= r.wr_en;

  ahbso.hconfig <= hconfig;
  ahbso.hirq    <= (others => '0');
  ahbso.hindex  <= hindex;
  ahbso.hsplit  <= (others => '0');

  apbo.pindex  <= pindex;
  apbo.pconfig <= pconfig;
  apbo.pirq    <= (others => '0');
  apbo.prdata  <= (others => '0');

  regs : process(clk_amba)
  begin
    if rising_edge(clk_amba) then

      -- Copy variables into registers (Default values)
      r <= rin;
      rnxt <= rnxtin;

      -- add extra pipe-stage for read data
      migout <= migoutraw;

      -- IDLE Clear
      if ((r.bstate = idle) or (r.bstate = read_wait)) then
         r.cmd_count <= (others => '0');
         r.wr_count <= (others => '0');
         r.rd_count <= (others => '0');
      end if;

     if (r.bstate = write_burst) then
         r.cmd_count <= (others => '0');
         r.wr_count <= (others => '0');
         r.rd_count <= to_unsigned(1,r.rd_count'length);
      end if;

      -- Read AHB write data
      if (r.bstate = start) and (r.hwrite = '1') then
         r.rd_count <= r.rd_count + 1;
      end if;

      -- Write command repsonse
      if r.bstate = write_cmd then

          if (r.cmd_count < 1) then
             r.cmd_en   <= '1';
          end if;
          if (migoutraw.app_rdy = '1') and (r.cmd_en = '1' ) then
             r.cmd_count <= r.cmd_count + 1;
             if (r.cmd_count < r.migcommands-1 ) then
                r.haddr <= r.haddr + 8;
             end if;
             if (r.cmd_count >= r.migcommands-1) then
                r.cmd_en   <= '0';
             end if;
          end if;

          if (r.wr_count < 1 ) then
             r.wr_en    <= '1';
             r.wr_end   <= '1';
             r.wdf_mask_buffer <= not r.mask_burst(15 downto 0);
             r.wdf_data_buffer <= r.hwdata_burst(127 downto 0);
          end if;
          if (migoutraw.app_wdf_rdy = '1') and (r.wr_en = '1' ) then
                if (r.wr_count = 0) then
                   r.wdf_mask_buffer <= not r.mask_burst(31 downto 16);
                   r.wdf_data_buffer <= r.hwdata_burst(255 downto 128);
                elsif (r.wr_count = 1) then --to support 3 migcmds
                   r.wdf_mask_buffer <= not r.mask_burst(47 downto 32);
                   r.wdf_data_buffer <= r.hwdata_burst(383 downto 256);
                else
                   r.wdf_mask_buffer <= not r.mask_burst(31 downto 16);
                   r.wdf_data_buffer <= r.hwdata_burst(255 downto 128);
                end if;

                r.wr_count <= r.wr_count + 1;
                if (r.wr_count >= r.migcommands - 1) then
                   r.wr_en    <= '0';
                   r.wr_end   <= '0';
                end if;
           end if;
      end if;

      -- Burst Write Wait
      if r.bstate = write_burst then
         r.cmd_count <= (others => '0');
         r.wr_count <= (others => '0');
         r.rd_count <= (others => '0');
      end if;

      -- Read command repsonse
      if r.bstate = read_cmd then
         if (r.cmd_count < 1) then
            r.cmd_en   <= '1';
         end if;
         if (migoutraw.app_rdy = '1')  and (r.cmd_en = '1' ) then
            r.cmd_count <= r.cmd_count + 1;
            if (r.cmd_count < r.migcommands-1 ) then
               r.haddr <= r.haddr + 8;
            end if;
            if (r.cmd_count >= r.migcommands-1) then
               r.cmd_en   <= '0';
            end if;
         end if;

      end if;
    end if;
  end process;

  MCB_inst : mig
  port map (
   ddr3_dq              => ddr3_dq,
   ddr3_dqs_p           => ddr3_dqs_p,
   ddr3_dqs_n           => ddr3_dqs_n,
   ddr3_addr            => ddr3_addr,
   ddr3_ba              => ddr3_ba,
   ddr3_ras_n           => ddr3_ras_n,
   ddr3_cas_n           => ddr3_cas_n,
   ddr3_we_n            => ddr3_we_n,
   ddr3_reset_n         => ddr3_reset_n,
   ddr3_ck_p            => ddr3_ck_p,
   ddr3_ck_n            => ddr3_ck_n,
   ddr3_cke             => ddr3_cke,
   ddr3_cs_n            => ddr3_cs_n,
   ddr3_dm              => ddr3_dm,
   ddr3_odt             => ddr3_odt,
   sys_clk_i            => sys_clk_i,
   clk_ref_i            => clk_ref_i,
   app_addr             => migin.app_addr,
   app_cmd              => migin.app_cmd,
   app_en               => migin.app_en,
   app_rdy              => migoutraw.app_rdy,
   app_wdf_data         => migin.app_wdf_data,
   app_wdf_end          => migin.app_wdf_end,
   app_wdf_mask         => migin.app_wdf_mask,
   app_wdf_wren         => migin.app_wdf_wren,
   app_wdf_rdy          => migoutraw.app_wdf_rdy,
   app_rd_data          => migoutraw.app_rd_data,
   app_rd_data_end      => migoutraw.app_rd_data_end,
   app_rd_data_valid    => migoutraw.app_rd_data_valid,
   app_sr_req           => '0',
   app_ref_req          => '0',
   app_zq_req           => '0',
   app_sr_active        => open,
   app_ref_ack          => open,
   app_zq_ack           => open,
   ui_clk               => ui_clk,
   ui_clk_sync_rst      => ui_clk_sync_rst,
   init_calib_complete  => calib_done,
   sys_rst              => rst_n_async
   );

end;

