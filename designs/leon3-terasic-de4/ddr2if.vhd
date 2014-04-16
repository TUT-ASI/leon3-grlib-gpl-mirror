------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
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

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
library gaisler;
use gaisler.ddrpkg.all;

entity ddr2if is
  generic (
    hindex: integer;
    haddr: integer := 16#400#;
    hmask: integer := 16#000#;
    ahbbits: integer := ahbdw;
    burstlen: integer := 8
    );
  port (
    pll_ref_clk     : in std_ulogic;
    global_reset_n  : in std_ulogic;
    mem_a              : out   std_logic_vector(13 downto 0);
    mem_ba             : out   std_logic_vector(2 downto 0);
    mem_ck             : out   std_logic_vector(1 downto 0);
    mem_ck_n           : out   std_logic_vector(1 downto 0);
    mem_cke            : out   std_logic;
    mem_cs_n           : out   std_logic;
    mem_dm             : out   std_logic_vector(7 downto 0);
    mem_ras_n          : out   std_logic;
    mem_cas_n          : out   std_logic;
    mem_we_n           : out   std_logic;
    mem_dq             : inout std_logic_vector(63 downto 0);
    mem_dqs            : inout std_logic_vector(7 downto 0);
    mem_dqs_n          : inout std_logic_vector(7 downto 0);
    mem_odt            : out   std_logic;
    ahb_clk         : in std_ulogic;
    ahb_rst         : in std_ulogic;
    ahbsi           : in ahb_slv_in_type;
    ahbso           : out ahb_slv_out_type;
    oct_rdn            : in    std_logic;
    oct_rup            : in    std_logic
    );
end;

architecture rtl of ddr2if is

  component ddr2ctrl is
    port (
      pll_ref_clk        : in    std_logic                      := '0';             --      pll_ref_clk.clk
      global_reset_n     : in    std_logic                      := '0';             --     global_reset.reset_n
      soft_reset_n       : in    std_logic                      := '0';             --       soft_reset.reset_n
      afi_clk            : out   std_logic;                                         --          afi_clk.clk
      afi_half_clk       : out   std_logic;                                         --     afi_half_clk.clk
      afi_reset_n        : out   std_logic;                                         --        afi_reset.reset_n
      afi_reset_export_n : out   std_logic;                                         -- afi_reset_export.reset_n
      mem_a              : out   std_logic_vector(13 downto 0);                     --           memory.mem_a
      mem_ba             : out   std_logic_vector(2 downto 0);                      --                 .mem_ba
      mem_ck             : out   std_logic_vector(1 downto 0);                      --                 .mem_ck
      mem_ck_n           : out   std_logic_vector(1 downto 0);                      --                 .mem_ck_n
      mem_cke            : out   std_logic_vector(0 downto 0);                      --                 .mem_cke
      mem_cs_n           : out   std_logic_vector(0 downto 0);                      --                 .mem_cs_n
      mem_dm             : out   std_logic_vector(7 downto 0);                      --                 .mem_dm
      mem_ras_n          : out   std_logic_vector(0 downto 0);                      --                 .mem_ras_n
      mem_cas_n          : out   std_logic_vector(0 downto 0);                      --                 .mem_cas_n
      mem_we_n           : out   std_logic_vector(0 downto 0);                      --                 .mem_we_n
      mem_dq             : inout std_logic_vector(63 downto 0)  := (others => '0'); --                 .mem_dq
      mem_dqs            : inout std_logic_vector(7 downto 0)   := (others => '0'); --                 .mem_dqs
      mem_dqs_n          : inout std_logic_vector(7 downto 0)   := (others => '0'); --                 .mem_dqs_n
      mem_odt            : out   std_logic_vector(0 downto 0);                      --                 .mem_odt
      avl_ready          : out   std_logic;                                         --              avl.waitrequest_n
      avl_burstbegin     : in    std_logic                      := '0';             --                 .beginbursttransfer
      avl_addr           : in    std_logic_vector(24 downto 0)  := (others => '0'); --                 .address
      avl_rdata_valid    : out   std_logic;                                         --                 .readdatavalid
      avl_rdata          : out   std_logic_vector(255 downto 0);                    --                 .readdata
      avl_wdata          : in    std_logic_vector(255 downto 0) := (others => '0'); --                 .writedata
      avl_be             : in    std_logic_vector(31 downto 0)  := (others => '0'); --                 .byteenable
      avl_read_req       : in    std_logic                      := '0';             --                 .read
      avl_write_req      : in    std_logic                      := '0';             --                 .write
      avl_size           : in    std_logic_vector(3 downto 0)   := (others => '0'); --                 .burstcount
      local_init_done    : out   std_logic;                                         --           status.local_init_done
      local_cal_success  : out   std_logic;                                         --                 .local_cal_success
      local_cal_fail     : out   std_logic;                                         --                 .local_cal_fail
      oct_rdn            : in    std_logic                      := '0';             --              oct.rdn
      oct_rup            : in    std_logic                      := '0'              --                 .rup
    );
  end component ddr2ctrl;

  signal vcc: std_ulogic;

  signal afi_clk, afi_half_clk, afi_reset_n: std_ulogic;
  signal local_init_done, local_cal_success, local_cal_fail: std_ulogic;

  signal ck_p_arr, ck_n_arr : std_logic_vector(1 downto 0);
  signal ras_n_arr, cas_n_arr, we_n_arr, odt_arr, cke_arr, cs_arr: std_logic_vector(0 downto 0);

  signal avlsi: ddravl_slv_in_type;
  signal avlso: ddravl_slv_out_type;

  signal rdata, wdata : std_logic_vector(255 downto 0);
  signal be: std_logic_vector(31 downto 0);
begin

  vcc <= '1';
  mem_ras_n <= ras_n_arr(0);
  mem_cas_n <= cas_n_arr(0);
  mem_we_n <= we_n_arr(0);
  mem_ck   <= ck_p_arr;
  mem_ck_n <= ck_n_arr;
  mem_cke <= cke_arr(0);
  mem_cs_n <= cs_arr(0);
  mem_odt <= odt_arr(0);

  avlso.rdata(255 downto 0) <= rdata(255 downto 0);
  wdata <= avlsi.wdata(255 downto 0);
  be <= avlsi.be(31 downto 0);

  ctrl0: ddr2ctrl
    port map (
      pll_ref_clk         => pll_ref_clk,
      global_reset_n      => global_reset_n,
      soft_reset_n        => vcc,
      afi_clk             => afi_clk,
      afi_half_clk        => afi_half_clk,
      afi_reset_n         => afi_reset_n,
      afi_reset_export_n  => open,
      mem_a               => mem_a,
      mem_ba              => mem_ba,
      mem_ck              => ck_p_arr,
      mem_ck_n            => ck_n_arr,
      mem_cke             => cke_arr,
      mem_cs_n            => cs_arr,
      mem_dm              => mem_dm,
      mem_ras_n           => ras_n_arr,
      mem_cas_n           => cas_n_arr,
      mem_we_n            => we_n_arr,
      mem_dq              => mem_dq,
      mem_dqs             => mem_dqs,
      mem_dqs_n           => mem_dqs_n,
      mem_odt             => odt_arr,
      avl_ready           => avlso.ready,
      avl_burstbegin      => avlsi.burstbegin,
      avl_addr            => avlsi.addr(24 downto 0),
      avl_rdata_valid     => avlso.rdata_valid,
      avl_rdata           => rdata,
      avl_wdata           => wdata,
      avl_be              => be,
      avl_read_req        => avlsi.read_req,
      avl_write_req       => avlsi.write_req,
      avl_size            => avlsi.size,
      local_init_done     => local_init_done,
      local_cal_success   => local_cal_success,
      local_cal_fail      => local_cal_fail,
      oct_rdn             => oct_rdn,
      oct_rup             => oct_rup
      );

  avlso.rdata(avlso.rdata'high downto 256) <= (others => '0');

  ahb2avl0: ahb2avl_async
    generic map (
      hindex => hindex,
      haddr => haddr,
      hmask => hmask,
      burstlen => burstlen,
      nosync => 0,
      ahbbits => ahbbits,
      avldbits => 256,
      avlabits => 25
      )
    port map (
      rst_ahb => ahb_rst,
      clk_ahb => ahb_clk,
      ahbsi => ahbsi,
      ahbso => ahbso,
      rst_avl => afi_reset_n,
      clk_avl => afi_clk,
      avlsi => avlsi,
      avlso => avlso
      );
end;
