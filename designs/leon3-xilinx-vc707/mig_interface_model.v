
/*****************************************************************************
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
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
-------------------------------------------------------------------------------
-- Entity:      mig_interface_model
-- File:        mig_interface_model.v
-- Author:      Fredrik Ringhage - Aeroflex Gaisler AB
--
--  This is a interface model for Xilinx Virtex-7 MIG used on eval board
--  VC707 and KC705.
--
-------------------------------------------------------------------------------
*****************************************************************************/

`timescale 1ps/1ps

module mig_interface_model
 (
   // user interface signals
   input         [27:0]    app_addr,
   input          [2:0]    app_cmd,
   input                   app_en,
   input        [511:0]    app_wdf_data,
   input                   app_wdf_end,
   input         [63:0]    app_wdf_mask,
   input                   app_wdf_wren,
   output  wire [511:0]    app_rd_data,
   output  wire            app_rd_data_end,
   output  wire            app_rd_data_valid,
   output  wire            app_rdy,
   output  wire            app_wdf_rdy,
   output  reg             ui_clk,
   output  reg             ui_clk_sync_rst,
   output  reg             init_calib_complete,
   input                   sys_rst
   );

   parameter AddressSize = 28 - 12;
   parameter WordSize    = 512;
   parameter MEM_SIZE    = (1<<AddressSize);

   reg         app_rd_data_end_r;
   reg         app_rd_data_valid_r;
   reg         app_rdy_r;
   reg         app_wdf_rdy_r;
   reg         app_en_r;
   reg         app_wdf_wren_r;
   reg         app_wdf_end_r;
   reg [27:0]  app_addr_r;
   reg [27:0]  app_addr_r1;
   reg [27:0]  app_addr_r2;
   reg [511:0] mask;
   reg [WordSize-1:0] Mem [0:MEM_SIZE];
   integer k;
   wire [511:0] app_rd_data_hi_data;
   wire [511:0] app_rd_data_hi;
   wire [511:0] app_rd_data_lo;
   wire         test;

   assign #100 app_rd_data_end   = app_rd_data_end_r;
   assign #100 app_rdy           = app_rdy_r;
   assign #100 app_wdf_rdy       = app_wdf_rdy_r;
   assign app_rd_data_valid      = app_rd_data_valid_r;

   assign #100 app_rd_data = Mem[app_addr_r >> 3];

   // Clear memory
   initial
   begin
     for (k = 0; k < MEM_SIZE ; k = k + 1)
     begin
         Mem[k] = 512'd0;
     end
   end

   initial
   begin
     app_rd_data_valid_r = 1'b0;
     app_rd_data_end_r = 1'b0;
     app_rdy_r = 1'b1;
     app_wdf_rdy_r = 1'b1;
     init_calib_complete = 1'b0;
     ui_clk_sync_rst = 1'b0;
     ui_clk = 1'b0;
   end

   // Generate clocks
   always
   begin
     forever begin
      #5000;
      ui_clk = ~ui_clk;
     end
   end

   // Release reset and calibration
   initial
   begin
      #10000;
      $display("Reset release of simulation time is %d",$time);
      @(posedge ui_clk) ui_clk_sync_rst = 1'b1;
      #1000;
      $display("Calibration release of simulation time is %d",$time);
      @(posedge ui_clk) init_calib_complete = 1'b1;
   end

   // Write Process
   always@(posedge app_wdf_wren)
   begin
        #100;
        for (k = 0; k < 511 ; k = k + 1)
        begin
            mask[k] = ~ app_wdf_mask[k >> 3];
        end
         Mem[app_addr >> 3] = (app_wdf_data & mask) | (Mem[app_addr >> 3] & (~ mask) );
         #10000;
        if (app_wdf_wren) begin
           #100;
           for (k = 0; k < 512 ; k = k + 1)
           begin
               mask[k] = ~ app_wdf_mask[k >> 3];
           end
           Mem[app_addr >> 3] = (app_wdf_data & mask) | (Mem[app_addr >> 3] & (~ mask) );
        end
   end

   // Read Process
   always@(posedge app_en)
   begin
     #100;
     if (app_cmd == 3'd1) begin
        app_addr_r1 = app_addr;
        #10000;
        app_addr_r2 = app_addr;
        #40000;
        app_addr_r = app_addr_r1;
        #100;
        app_rd_data_valid_r = 1'b1;
        #10000;
        app_addr_r = app_addr_r2;
        #10000;
        app_rd_data_valid_r = 1'b0;
        #10000;
      end
   end
endmodule
