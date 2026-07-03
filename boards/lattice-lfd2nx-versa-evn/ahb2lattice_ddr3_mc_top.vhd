library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;

library gaisler;
use gaisler.misc.all;

library techmap;
use techmap.gencomp.all;

--pragma translate_off
use gaisler.sim.all;
library nexus_sim;
use nexus_sim.all;
--pragma translate_on


entity ahb2lattice_ddr3_mc_top is
    generic (
    hindex : integer := 0;
    haddr  : integer := 16#400#;
    hmask  : integer := 16#F80#;
    addr_w : integer := 26;
    core_data_w : integer := 128);
  port(
    refclk   : in std_logic;
    resetin  : in std_logic;

    clkm     : in std_logic; -- clock from the top level
    ddr_sclk : out std_logic; -- DDR mc sclk
    rstn_ddr : in std_logic;
    clocking_good_pll : out std_logic;

    init_done : out std_logic;
    init_err  : out std_logic;

    ahbsi : in  ahb_slv_in_type;
    ahbso : out ahb_slv_out_type;

    -- Note that differential signals (such as DQS) are represented as a single
    -- logical signal. (Which is very reasonable.)
    -- DDR3 data
    ddr3_dq   : inout std_logic_vector(15 downto 0);
    ddr3_dqs  : inout std_logic_vector(1 downto 0);
    ddr3_dm   : out   std_logic_vector(1 downto 0);
    --ddr3_nu -- not used because TDQS is disabled

    -- DDR3 address/control
    ddr3_resetn : out   std_logic;
    ddr3_ck     : out   std_logic_vector(0 downto 0);
    ddr3_cke    : out   std_logic_vector(0 downto 0);
    ddr3_rasn   : out   std_logic;
    ddr3_casn   : out   std_logic;
    ddr3_wen    : out   std_logic;
    ddr3_csn    : out   std_logic_vector(0 downto 0);
    ddr3_odt    : out   std_logic_vector(0 downto 0);
    ddr3_addr   : out   std_logic_vector(12 downto 0);
    ddr3_ba     : out   std_logic_vector(2 downto 0)
  );
end ahb2lattice_ddr3_mc_top;

architecture rtl of ahb2lattice_ddr3_mc_top is

  constant data_mask_w : integer := core_data_w/8;

  signal mem_rst_n        : std_logic;
  signal init_start       : std_logic;
  signal cmd              : std_logic_vector(3 downto 0);
  signal addr             : std_logic_vector(addr_w - 1 downto 0);
  signal cmd_burst_cnt    : std_logic_vector(4 downto 0);
  signal cmd_valid        : std_logic;
  signal write_data       : std_logic_vector(core_data_w - 1 downto 0);
  signal data_mask        : std_logic_vector(data_mask_w - 1 downto 0);
  signal cmd_rdy          : std_logic;
  signal datain_rdy       : std_logic;
  signal init_done_core   : std_logic;
  signal rt_err           : std_logic;
  signal wl_err           : std_logic;
  signal read_data        : std_logic_vector(core_data_w - 1 downto 0);
  signal read_data_valid  : std_logic;
  signal sclk             : std_logic;
  signal clocking_good    : std_logic;

  signal ahbso_no : ahb_slv_out_vector;

  -- AHB2AHB + AHB CONTROLLER part
  signal bus_ddr_ahbsi : ahb_slv_in_type;
  signal bus_ddr_ahbso : ahb_slv_out_vector := (others => ahbs_none);
  signal bus_ddr_ahbmi : ahb_mst_in_type;
  signal bus_ddr_ahbmo : ahb_mst_out_vector := (others => ahbm_none);

  component lattice_ddr3c is
    port(
      clk_i: in std_logic;
      rst_n_i: in std_logic;
      --inputs from ahb core
      mem_rst_n_i: in std_logic;
      init_start_i: in std_logic;
      cmd_i: in std_logic_vector(3 downto 0);
      addr_i: in std_logic_vector(25 downto 0);
      cmd_burst_cnt_i: in std_logic_vector(4 downto 0);
      cmd_valid_i: in std_logic;
      write_data_i: in std_logic_vector(127 downto 0);
      data_mask_i: in std_logic_vector(15 downto 0);
      -- outputs to ahb core
      cmd_rdy_o: out std_logic;
      datain_rdy_o: out std_logic;
      init_done_o: out std_logic;
      rt_err_o: out std_logic;
      wl_err_o: out std_logic;
      read_data_o: out std_logic_vector(127 downto 0);
      read_data_valid_o: out std_logic;
      sclk_o: out std_logic;
      clocking_good_o: out std_logic;
      em_ddr_data_io: inout std_logic_vector(15 downto 0);
      em_ddr_reset_n_o: out std_logic;
      em_ddr_dqs_io: inout std_logic_vector(1 downto 0);
      em_ddr_dm_o: out std_logic_vector(1 downto 0);
      em_ddr_clk_o: out std_logic_vector(0 to 0);
      em_ddr_cke_o: out std_logic_vector(0 to 0);
      em_ddr_ras_n_o: out std_logic;
      em_ddr_cas_n_o: out std_logic;
      em_ddr_we_n_o: out std_logic;
      em_ddr_cs_n_o: out std_logic_vector(0 to 0);
      em_ddr_odt_o: out std_logic_vector(0 to 0);
      em_ddr_addr_o: out std_logic_vector(12 downto 0);
      em_ddr_ba_o: out std_logic_vector(2 downto 0)
      );
  end component;

  component ahb2lattice_ddr3_mc is
    generic (
      hindex : integer := 0;
      haddr  : integer := 16#400#;
      hmask  : integer := 16#c00#;
      addr_w : integer := 26;
      core_data_w : integer := 128);
    port(
      rstn : in std_logic;

      ahbsi : in  ahb_slv_in_type;
      ahbso : out ahb_slv_out_type;

      -- signals to ddr3_mc
      rst_n_o : out std_logic;
      mem_rst_n_o : out std_logic;
      init_start_o : out std_logic;
      cmd_o : out std_logic_vector(3 downto 0);
      addr_o : out std_logic_vector(addr_w - 1 downto 0);
      cmd_burst_cnt_o : out std_logic_vector(4 downto 0);
      cmd_valid_o : out std_logic;
      write_data_o : out std_logic_vector(core_data_w - 1 downto 0);
      data_mask_o : out std_logic_vector(core_data_w/8 - 1 downto 0);

      -- signals from ddr3_mc
      cmd_rdy_i         : in std_logic;
      datain_rdy_i      : in std_logic;
      init_done_i       : in std_logic;
      rt_err_i          : in std_logic;
      wl_err_i          : in std_logic;
      read_data_i       : in std_logic_vector(core_data_w - 1 downto 0);
      read_data_valid_i : in std_logic;
      sclk_i            : in std_logic;
      clocking_good_i   : in std_logic;

      -- Debug signals
      init_done : out std_logic;
      init_err  : out std_logic
      );
  end component;


begin

  ddr_sclk <= sclk;
  clocking_good_pll <= clocking_good;

  ahb2ddr: ahb2lattice_ddr3_mc
    generic map (
      hindex => 0,--hindex,
      haddr  => haddr,
      hmask  => hmask,
      addr_w => addr_w,
      core_data_w => core_data_w)
    port map (
      rstn   => resetin,

      ahbsi  => bus_ddr_ahbsi,
      ahbso  => bus_ddr_ahbso(0),

      -- signals to ddr3_mc
      rst_n_o => open,
      mem_rst_n_o => mem_rst_n,
      init_start_o => init_start,
      cmd_o => cmd,
      addr_o => addr,
      cmd_burst_cnt_o => cmd_burst_cnt,
      cmd_valid_o => cmd_valid,
      write_data_o =>  write_data,
      data_mask_o => data_mask,

      -- signals from ddr3_mc
      cmd_rdy_i         => cmd_rdy,
      datain_rdy_i      => datain_rdy,
      init_done_i       => init_done_core,
      rt_err_i          => rt_err,
      wl_err_i          => wl_err,
      read_data_i       => read_data,
      read_data_valid_i => read_data_valid,
      sclk_i            => sclk,
      clocking_good_i   => clocking_good,

      -- Debug signals
      init_done => init_done,
      init_err  => init_err
      );

  -- Generated DDR3 memory controller. IP from Lattice.
  -- Can be programmed into hardware with an evaluation license, but will
  -- only run for 2-4 hours (enforced using encrypted bitstream commands an
  -- a hardware timer inside the FPGA).
  ddr3c : lattice_ddr3c
    port map(
      -- Inputs from core
      clk_i             => refclk,
      rst_n_i           => rstn_ddr,-- GSRN
      mem_rst_n_i       => mem_rst_n,
      init_start_i      => init_start,
      cmd_i             => cmd,
      addr_i            => addr,
      cmd_burst_cnt_i   => cmd_burst_cnt,
      cmd_valid_i       => cmd_valid,
      write_data_i      => write_data,
      data_mask_i       => data_mask,
      -- Outputs to core
      cmd_rdy_o         => cmd_rdy,
      datain_rdy_o      => datain_rdy,
      init_done_o       => init_done_core,
      rt_err_o          => rt_err,
      wl_err_o          => wl_err,
      read_data_o       => read_data,
      read_data_valid_o => read_data_valid,
      sclk_o            => sclk,
      clocking_good_o   => clocking_good,
      -- Signals to PCB
      em_ddr_data_io    => ddr3_dq,
      em_ddr_reset_n_o  => ddr3_resetn,
      em_ddr_dqs_io     => ddr3_dqs,
      em_ddr_dm_o       => ddr3_dm,
      em_ddr_clk_o      => ddr3_ck,
      em_ddr_cke_o      => ddr3_cke,
      em_ddr_ras_n_o    => ddr3_rasn,
      em_ddr_cas_n_o    => ddr3_casn,
      em_ddr_we_n_o     => ddr3_wen,
      em_ddr_cs_n_o     => ddr3_csn,
      em_ddr_odt_o      => ddr3_odt,
      em_ddr_addr_o     => ddr3_addr,
      em_ddr_ba_o       => ddr3_ba);

  -- ahb2ahb bridge used for handling different clocks
  ahb2ahb0: ahb2ahb
    generic map (
      memtech     => nexus,
      hsindex     => hindex,
      hmindex     => 0,
      slv         => 0,
      dir         => 1,
      ffact       => 2,
      pfen        => 1,
      wburst      => 2,--BURSTLEN,
      -- Default system burst length
      --constant BURSTLEN : integer := 8;
      iburst      => 4,--CFG_ILINE,
      rburst      => 4,--BURSTLEN,
      irqsync     => 0,
      bar0        => ahb2ahb_membar(haddr, '1', '1', hmask),
      bar1        => ahb2ahb_membar(16#FFB#, '0', '0', 16#FFF#),
      --bar1        => ahb2ahb_membar(16#200#, '0', '0', 16#F00#),
      --bar2        => ahb2ahb_membar(16#400#, '1', '1', 16#C00#),
      --bar3        => ahb2ahb_membar(16#FFE#, '0', '0', 16#FFF#),
      sbus        => 0,
      mbus        => 1,
      ioarea      => 16#FFB#,--CFG_BUS1_AHBIO,
      ibrsten     => 0,
      lckdac      => 2,
      slvmaccsz   => 32,
      mstmaccsz   => 32,
      rdcomb      => 0,
      wrcomb      => 0,
      combmask    => 0,
      allbrst     => 0,
      ifctrlen    => 0,
      fcfs        => 0,--(CFG_NCPU+CFG_AHB_UART+1)*CFG_SPLIT, -- FCFS requires SPLIT support
      fcfsmtech   => 0,
      scantest    => 0,--CFG_SCAN,
      split       => 0,--CFG_SPLIT,
      pipe        => 128--AHB2AHB_PIPE
      )
    port map (
      rstn        => resetin,
      hclkm       => sclk,
      hclks       => clkm,
      ahbsi       => ahbsi,--bus_0_ahbsi,
      ahbso       => ahbso,--bus_0_ahbso(0),
      ahbmi       => bus_ddr_ahbmi,--bus_1_ahbmi,
      ahbmo       => bus_ddr_ahbmo(0),--bus_1_ahbmo(0),
      ahbso2      => bus_ddr_ahbso,
      lcki        => ahb2ahb_ctrl_none,--"000",--nolock,
      lcko        => open,
      ifctrl      => ahb2ahb_ifctrl_none--noifctrl
      );

  -- nolock <= ahb2ahb_ctrl_none;
  -- noifctrl <= ahb2ahb_ifctrl_none;

  ----------------------------------------------------------------------
  ---  AHB CONTROLLER --------------------------------------------------
  ----------------------------------------------------------------------
  ahb_int : ahbctrl                -- AHB arbiter/multiplexer
    generic map (defmast => 0, split => 0,--CFG_DEFMST,CFG_SPLIT,
                 rrobin => 1, ioaddr => 16#ffb#, ioen => 0,--constant CFG_BUS1_AHBIO : integer := 16#ffe#;--ioaddr
                 --rrobin => CFG_RROBIN, ioaddr => CFG_BUS1_AHBIO, ioen => 0,
                 nahbm => 1, nahbs => 1, fpnpen => 1)
    port map (resetin, sclk, bus_ddr_ahbmi, bus_ddr_ahbmo, bus_ddr_ahbsi, bus_ddr_ahbso);

end rtl;
