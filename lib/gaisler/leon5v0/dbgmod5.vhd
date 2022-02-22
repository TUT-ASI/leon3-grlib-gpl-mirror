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
-- Entity:      dbgmod5
-- File:        dbgmod5.vhd
-- Author:      Magnus Hjorth, Cobham Gaisler
-- Description: LEON5 debug and trace module
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config.all;
use grlib.config_types.all;
library gaisler;
use gaisler.leon5int.all;
use gaisler.leon5.leon5_bretry_in_type;
use gaisler.leon5.leon5_bretry_out_type;
use gaisler.uart.all;
library techmap;
use techmap.gencomp.all;

entity dbgmod5 is
  generic (
    fabtech   : integer;
    memtech   : integer;
    ncpu      : integer;
    ndbgmst   : integer;
    busw      : integer;
    cpumidx   : integer;
    dsuhaddr  : integer;
    dsuhmask  : integer;
    pnpaddrhi : integer;
    pnpaddrlo : integer;
    dsuslvidx : integer;
    dsumstidx : integer;
    bretryen  : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    bretclk  : in  std_ulogic;
    bretrstn : in  std_ulogic;
    rstreqn  : out std_ulogic;
    cpurstn  : out std_logic_vector(0 to ncpu-1);
    dbgmi    : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
    dbgmo    : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
    cpumi    : in  ahb_mst_in_type;
    cpumo    : out ahb_mst_out_type;
    cpusi    : in  ahb_slv_in_type;
    dsuen    : in  std_ulogic;
    dsubreak : in  std_ulogic;
    dbgi     : out l5_debug_in_vector(0 to ncpu-1);
    dbgo     : in  l5_debug_out_vector(0 to ncpu-1);
    itod     : in  l5_irq_dbg_vector(0 to ncpu-1);
    dtoi     : out l5_dbg_irq_vector(0 to ncpu-1);
    tpi      : in  trace_port_in_vector(0 to NCPU-1);
    tco      : out trace_control_out_vector(0 to NCPU-1);
    tstop    : out std_ulogic;
    dbgtime  : out std_logic_vector(31 downto 0);
    maskerrn : out std_logic_vector(0 to NCPU-1);
    uartie   : in  uart_in_type;
    uartoe   : out uart_out_type;
    uartii   : out uart_in_type;
    uartoi   : in  uart_out_type;
    sysstat  : in  std_logic_vector(15 downto 0);
    bretin   : in  leon5_bretry_in_type;
    bretout  : out leon5_bretry_out_type
    );
end;

architecture rtl of dbgmod5 is

  function min(i,j: integer) return integer is
  begin
    if i<j then return i; else return j; end if;
  end min;

  constant nsess : integer := min(ncpu,4);

  constant NBITS     : integer := log2x(ncpu);
  constant PROC_H    : integer := 22+NBITS-1;
  constant PROC_L    : integer := 22;
  constant AREA_H    : integer := 21;
  constant AREA_L    : integer := 19;
  constant kbytes    : integer := 4;
  constant itentr    : integer := 256;
  constant TBUFABITS : integer := log2(kbytes mod 16#10000#) + 6 - 10*(kbytes/16#10000#);
  constant TRACEN    : boolean := (kbytes /= 0);
  constant ITRACEN   : boolean := (itentr /= 0);
  constant ahbwp     : integer := 2;
  constant AHBWATCH  : boolean := TRACEN and (ahbwp /= 0);
  constant tbits     : integer := 32;
  constant ittbits   : integer := min(tbits,30);
  constant scantest  : integer := 0;      -- temp

  constant DSU5_VERSION : integer := 3;
  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_LEON5DSU, 0, DSU5_VERSION, 0),
    4 => ahb_membar(dsuhaddr, '0', '0', dsuhmask),
    others => zero32);

  type dbgmst_state is record
    hready  : std_ulogic;
    haddr   : std_logic_vector(31 downto 0);
    hsize   : std_logic_vector(2 downto 0);
    hwrite  : std_ulogic;
    hburst0 : std_ulogic;
  end record;
  constant dbgmst_state_none: dbgmst_state := ('1',x"00000000","000",'0','0');
  type dbgmst_state_vector is array(ndbgmst-1 downto 0) of dbgmst_state;

  type dbgmod5_state is (dmrstwait, dmidle, dmsingle, dmdsu1, dmdsu2, dmbootreq1, dmbootreq2, dmbootreq3);

  subtype word30 is std_logic_vector(29 downto 0);
  type nword30 is array (0 to NCPU-1) of word30;
  subtype wordtm is std_logic_vector(tbits-1 downto 0);
  type nwordtm is array (0 to NCPU-1) of wordtm;

  subtype cpu_cmd_type is std_logic_vector(2 downto 0);
  type cpu_cmd_array is array(natural range <>) of cpu_cmd_type;

  subtype cpu_bit_array is std_logic_vector(ncpu-1 downto 0);
  type cpu_bit_matrix is array(0 to ncpu-1) of cpu_bit_array;
  constant cpu_bit_matrix_zero: cpu_bit_matrix  := (others => (others => '0'));

  subtype boot_word_type is std_logic_vector(31 downto 0);
  type boot_word_array is array(0 to ncpu-1) of boot_word_type;

  function get_ctlmat_default return cpu_bit_matrix is
    variable r: cpu_bit_matrix;
  begin
    r := (others => (others => '0'));
    if ncpu>1 then r(0)(ncpu-1 downto 1) := (others => '1'); end if;
    return r;
  end get_ctlmat_default;
  constant ctlmat_default: cpu_bit_matrix := get_ctlmat_default;

  type dsu_reg_type is record
    -- Sampled state
    plstate        : std_logic_vector(2*NCPU-1 downto 0);
    prevstate      : std_logic_vector(2*NCPU-1 downto 0);
    statechg       : std_logic_vector(2*NCPU-1 downto 0);
    plidle         : std_logic_vector(NCPU-1 downto 0);
    forcedstop     : std_logic_vector(NCPU-1 downto 0);
    -- Control signals going to CPU
    cpu_cmd        : cpu_cmd_array(0 to NCPU-1);
    te             : std_logic_vector(0 to NCPU-1);
    be             : std_logic_vector(0 to NCPU-1);
    bw             : std_logic_vector(0 to NCPU-1);
    bs             : std_logic_vector(0 to NCPU-1);
    bx             : std_logic_vector(0 to NCPU-1);
    bz             : std_logic_vector(0 to NCPU-1);
    pushpc         : std_logic_vector(0 to NCPU-1);
    pcin           : std_logic_vector(31 downto 2);
    -- Control signals from debug module
    dbg_cmd        : cpu_cmd_array(0 to NCPU-1);
    -- Control signals from user/system
    usr_wakeup     : std_logic_vector(0 to NCPU-1);
    usr_break      : std_logic_vector(0 to NCPU-1);
    usr_start      : std_logic_vector(0 to NCPU-1);
    boot_word      : boot_word_array;
    -- Block signals from user
    blockusr       : std_logic_vector(0 to NCPU-1);
    -- Break, Control and delegation matrices
    brkmat         : cpu_bit_matrix;
    ctlmat         : cpu_bit_matrix;
    delegmat       : cpu_bit_matrix;
    -- Effective control matrix considering delegation
    effctl         : cpu_bit_matrix;
    effctl_new     : cpu_bit_matrix;
    effctl_clr     : std_ulogic;
    effctl_stab    : std_logic_vector(0 to NCPU-1);
    effctl_allstab : std_ulogic;
    -- Main timer stop
    tstopcfg       : std_logic_vector(NCPU-1 downto 0);
    tstop          : std_ulogic;
    -- Cycle timer
    timer          : std_logic_vector(tbits-1 downto 0);
    timerrep       : nwordtm;
  end record;
  constant dsu_reg_none: dsu_reg_type := (
    plstate        => (others => '0'),
    prevstate      => (others => '0'),
    statechg       => (others => '0'),
    plidle         => (others => '0'),
    forcedstop     => (others => '0'),
    cpu_cmd        => (others => CPUCMD_NONE),
    te             => (others => '0'),
    be             => (others => '0'),
    bw             => (others => '0'),
    bs             => (others => '0'),
    bx             => (others => '0'),
    bz             => (others => '0'),
    pushpc         => (others => '0'),
    pcin           => (others => '0'),
    dbg_cmd        => (others => CPUCMD_NONE),
    usr_wakeup     => (others => '0'),
    usr_break      => (others => '0'),
    usr_start      => (others => '0'),
    boot_word      => (others => (others => '0')),
    blockusr       => (others => '0'),
    brkmat         => cpu_bit_matrix_zero,
    ctlmat         => ctlmat_default,
    delegmat       => cpu_bit_matrix_zero,
    effctl         => cpu_bit_matrix_zero,
    effctl_new     => cpu_bit_matrix_zero,
    effctl_clr     => '1',
    effctl_stab    => (others => '0'),
    effctl_allstab => '0',
    tstopcfg       => (others => '1'),
    tstop          => '0',
    timer          => (others => '0'),
    timerrep       => (others => (others => '0'))
    );

  type dsu_session_reg_type is record
    claimed   : std_ulogic;
    pending   : std_ulogic;
    claimcpu  : std_logic_vector(NCPU-1 downto 0);
    claimres  : std_logic_vector(0 downto 0);  -- 0=UART
    sampstate : std_ulogic;
    docmd     : std_ulogic;
    dbuf      : std_logic_vector(6*32-1 downto 0);
    tstamp    : std_logic_vector(15 downto 0);
    statechg  : std_logic_vector(3 downto 0);
    uartcapt  : std_ulogic;
    uartval   : std_logic_vector(7 downto 0);
    uartor    : std_ulogic;
  end record;

  constant dsu_session_reg_none: dsu_session_reg_type := (
    '0','0',(others => '0'),(others => '0'),'0','0',(others => '0'),(others => '0'),
    "0000",'0',"00000000",'0');

  type dsu_session_reg_vector is array(natural range <>) of dsu_session_reg_type;

  type boot_request_reg_type is record
    bcpu     : unsigned(log2x(NCPU)-1 downto 0);
    baddr    : std_logic_vector(31 downto 3);
    ben      : std_ulogic;
    bact     : std_ulogic;
    bdone    : std_ulogic;
    bfail    : std_ulogic;
    bcancel  : std_ulogic;
    maystart : std_ulogic;
    permchk  : std_ulogic;
  end record;

  constant boot_request_reg_none: boot_request_reg_type := (
    (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '0', '0');

  type boot_request_array is array(natural range <>) of boot_request_reg_type;

  function ahbwp_nz return integer is
  begin
    if (ahbwp /= 0) and (kbytes /= 0) then return 1; end if;
    return 0;
  end function ahbwp_nz;

  type trace_break_reg is record
    addr          : std_logic_vector(31 downto 2);
    mask          : std_logic_vector(31 downto 2);
    read          : std_logic;
    write         : std_logic;
  end record;
  constant trace_break_reg_none: trace_break_reg := (
    (others => '0'), (others => '0'), '0', '0' );

  type trace_break_reg_vector is array (1 to 2) of trace_break_reg;

  type trace_reg_type is record
    s2haddr       : std_logic_vector(31 downto 0);
    s2hwrite      : std_logic;
    s2htrans      : std_logic_vector(1 downto 0);
    s2hsize       : std_logic_vector(2 downto 0);
    s2hburst      : std_logic_vector(2 downto 0);
    s2hmaster     : std_logic_vector(3 downto 0);
    s2hmastlock   : std_logic;
    s2hresp       : std_logic_vector(1 downto 0);
    s2data        : std_logic_vector(busw-1 downto 0);
    s1haddr       : std_logic_vector(31 downto 0);
    s1hwrite      : std_logic;
    s1htrans      : std_logic_vector(1 downto 0);
    s1hsize       : std_logic_vector(2 downto 0);
    s1hburst      : std_logic_vector(2 downto 0);
    s1hmaster     : std_logic_vector(3 downto 0);
    s1hmastlock   : std_logic;
    ahbactive     : std_logic;
    aindex        : std_logic_vector(TBUFABITS - 1 downto 0); -- buffer index
    enable        : std_logic;  -- trace enable
    bphit         : std_logic;  -- AHB breakpoint hit
    bphit2        : std_logic;  -- delayed bphit
    dcnten        : std_logic;  -- delay counter enable
    delaycnt      : std_logic_vector(TBUFABITS - 1 downto 0); -- delay counter
    tbreg         : trace_break_reg_vector;    -- AHB breakpoint 1 and 2
    tbwr          : std_logic;  -- trace buffer write enable
    break         : std_logic;  -- break CPU when AHB tracing stops
    tforce        : std_logic;  -- Force AHB trace
    timeren       : std_logic;  -- Keep timer enabled
    sample        : std_logic;  -- Force sample
    edbgmtf       : std_logic;  -- Enable debug mode timer freeze
  end record;

  constant trace_reg_none: trace_reg_type := (
    s2haddr       => x"00000000",
    s2hwrite      => '0',
    s2htrans      => "00",
    s2hsize       => "000",
    s2hburst      => "000",
    s2hmaster     => "0000",
    s2hmastlock   => '0',
    s2hresp       => "00",
    s2data        => (others => '0'),
    s1haddr       => x"00000000",
    s1hwrite      => '0',
    s1htrans      => "00",
    s1hsize       => "000",
    s1hburst      => "000",
    s1hmaster     => "0000",
    s1hmastlock   => '0',
    ahbactive     => '0',
    aindex        => (others => '0'),
    enable        => '0',
    bphit         => '0',
    bphit2        => '0',
    dcnten        => '0',
    delaycnt      => (others => '0'),
    tbreg         => (others => trace_break_reg_none),
    tbwr          => '0',
    break         => '0',
    tforce        => '0',
    timeren       => '0',
    sample        => '0',
    edbgmtf       => '0'
    );

  type trace_data_break_match_reg is record
    data          : std_logic_vector((AHBDW-1)*ahbwp_nz downto 0);
    mask          : std_logic_vector((AHBDW-1)*ahbwp_nz downto 0);
    en            : std_ulogic;
    couple        : std_ulogic;
    inv           : std_ulogic;
  end record;
  constant trace_data_break_match_reg_none: trace_data_break_match_reg := (
    (others => '0'), (others => '0'), '0', '0', '0'
    );

  type trace_data_break_match_reg_vector is array (1 to 2) of trace_data_break_match_reg;

  function ahbwp_pipe return integer is
  begin
    if (ahbwp = 2) and (kbytes /= 0) then return 1; end if;
    return 0;
  end function ahbwp_pipe;

   type trace_data_break_pipe_reg is record
    data    : std_logic_vector((AHBDW-1)*ahbwp_pipe downto 0);
    wpcheck : std_logic_vector(trace_data_break_match_reg_vector'range);
    hready  : std_ulogic;
    wphit   : std_logic_vector(trace_data_break_match_reg_vector'range);
   end record;
  constant trace_data_break_pipe_reg_none : trace_data_break_pipe_reg := (
    (others => '0'), (others => '0'), '0', (others => '0')
    );

  type watch_reg_type is record
    reg  : trace_data_break_match_reg_vector;
    pipe : trace_data_break_pipe_reg;
  end record;
  constant watch_reg_none : watch_reg_type := (
    reg => (others => trace_data_break_match_reg_none),
    pipe => trace_data_break_pipe_reg_none
    );

  subtype itbi_data_type is std_logic_vector(383 downto 0);

  type it_reg_type is record
    trace_upd       : std_logic;
    enable          : std_logic;
    addr_f          : std_logic_vector(3 downto 0);  --address filter
    addr_f_p        : std_logic_vector(3 downto 0);  --address filter polarity
    inst_filter     : std_logic_vector(3 downto 0);  --instruction filter type
    sample0         : itbi_data_type;
    sample1         : itbi_data_type;
    valid           : std_logic_vector(1 downto 0);
    -- +log2(NCPU) is used for instruction trace combining accross processors
    buf_read        : std_logic;
    buf_read2       : std_logic;
    buf_ready       : std_logic;
    buf_read_addr   : std_logic_vector(log2(itentr)-1+5 downto 0);
    buf_rdata       : std_logic_vector(31 downto 0);
    pointer         : std_logic_vector(log2(itentr)-1+log2(NCPU) downto 0);
    pointer_inc     : std_logic_vector(log2(itentr)-1+log2(NCPU) downto 0);
    set_pointer_inc : std_logic;
  end record;
  constant it_reg_none: it_reg_type := (
    '0', '0', (others=>'0'), (others=>'0'), (others=>'0'), (others => '0'), (others => '0'),
    "00", '0', '0', '0', (others => '0'), (others => '0'), (others => '0'), (others => '0'), '0'
    );

  type it_reg_array_type is array (0 to NCPU-1) of it_reg_type;

  type itbi_data_array_type is array (0 to NCPU-1) of itracebuf_in_type5;
  type itbo_data_array_type is array (0 to NCPU-1) of itracebuf_out_type5;

  type byte_array is array(natural range <>) of std_logic_vector(7 downto 0);

  type uart_reg_type is record
    -- shift registers and status
    captb       : byte_array(0 to 1);
    captwp      : unsigned(0 downto 0);
    captrp      : unsigned(0 downto 0);
    captfull    : std_ulogic;
    captoverrun : std_ulogic;
    captsreg    : std_logic_vector(9 downto 0);
    insreg      : std_logic_vector(9 downto 0);
    inoverrun   : std_ulogic;
    -- config
    outblock    : std_ulogic;
    outflow     : std_ulogic;
    inblock     : std_ulogic;
    inflow      : std_ulogic;
  end record;
  constant uart_reg_none: uart_reg_type := (
    (others => (others => '0')), (others => '0'), (others => '0'),
    '0','0',(others => '1'),(others => '1'),'0','0','0','0','0'
    );

  type smp_reg_type is record
    -- IPI broadcast within SMP group
    ipien   : std_ulogic;
    ipiirq  : std_logic_vector(4 downto 0);
    ipiout  : std_ulogic;
    ipiin   : std_ulogic;
    -- TLB flush broadcast within SMP group
    tlbfen  : std_ulogic;
    tlbfout : std_ulogic;
    tlbfin  : std_ulogic;
    -- Icache flush broadcast within SMP group
    icfen   : std_ulogic;
    icfout  : std_ulogic;
    icfin   : std_ulogic;
  end record;
  constant smp_reg_none: smp_reg_type :=
    ('0',"00000",'0','0','0','0','0','0','0','0');
  type smp_reg_array is array(natural range <>) of smp_reg_type;

  type dbgmod5_regs is record
    -- Reset control for processors
    cpurstn           : std_logic_vector(0 to ncpu-1);
    tstop             : std_ulogic;
    -- Processor bus output registers
    mst_hbusreq       : std_ulogic;
    mst_htrans        : std_logic_vector(1 downto 0);
    mst_haddr         : std_logic_vector(31 downto 0);
    mst_hwrite        : std_ulogic;
    mst_hsize         : std_logic_vector(2 downto 0);
    mst_hburst        : std_logic_vector(2 downto 0);
    -- Processor bus AHB state
    mst_granted       : std_ulogic;
    mst_inacc         : std_ulogic;
    -- Debug port state
    dsu_htrans1       : std_ulogic;
    hdata             :  std_logic_vector(31 downto 0);
    dbgmst            : dbgmst_state_vector;
    selmst            : unsigned(log2x(ndbgmst)-1 downto 0);
    -- Main dbgmod FSM state
    s                 : dbgmod5_state;
    ctr               : std_logic_vector(11 downto 0);
    -- Registers for processor control
    dsu               : dsu_reg_type;
    sess              : dsu_session_reg_vector(0 to nsess-1);
    selsess           : unsigned(log2x(nsess)-1 downto 0);
    sesscmd           : std_ulogic;
    c2c_miso          : l5_intreg_miso_array(0 to NCPU-1);
    bootreq           : boot_request_array(0 to NCPU-1);
    selboot           : unsigned(log2x(ncpu)-1 downto 0);
    selbootcpu        : unsigned(log2x(ncpu)-1 downto 0);
    nolegacy          : std_ulogic;
    -- SMP group matrix and registers for broadcasts
    smpgroup          : cpu_bit_matrix;
    smp               : smp_reg_array(0 to NCPU-1);
    -- Registers for tracing
    tr                : trace_reg_type;
    twr               : watch_reg_type;
    it                : it_reg_array_type;
    -- Registers for UART debug
    uart              : uart_reg_type;
    -- Registers for status / reset via debug master
    hready_pipe       : std_ulogic;
    rstreqn           : std_ulogic;
    -- Diagnostic registers
    deadlock_hit      :  std_ulogic;
    deadlock_addr     : std_logic_vector(31 downto 0);
    deadlock_hwrite   : std_ulogic;
    deadlock_hsize    : std_logic_vector(2 downto 0);
    deadlock_cpustate : std_logic_vector(ncpu*2-1 downto 0);
    deadlock_multi    : std_ulogic;
  end record;

  constant RRES: dbgmod5_regs := (
    cpurstn           => (others => '0'),
    tstop             => '0',
    mst_hbusreq       => '0',
    mst_htrans        => "00",
    mst_haddr         => (others => '0'),
    mst_hwrite        => '0',
    mst_hsize         => "000",
    mst_hburst        => "000",
    mst_granted       => '0',
    mst_inacc         => '0',
    dsu_htrans1       => '0',
    hdata             => x"00000000",
    dbgmst            => (others => dbgmst_state_none),
    selmst            => (others => '0'),
    s                 => dmrstwait,
    ctr               => (others => '1'),
    dsu               => dsu_reg_none,
    sess              => (others => dsu_session_reg_none),
    selsess           => (others => '0'),
    sesscmd           => '0',
    c2c_miso          => (others => l5_intreg_miso_none),
    bootreq           => (others => boot_request_reg_none),
    selboot           => (others => '0'),
    selbootcpu        => (others => '0'),
    nolegacy          => '0',
    smpgroup          => cpu_bit_matrix_zero,
    smp               => (others => smp_reg_none),
    tr                => trace_reg_none,
    twr               => watch_reg_none,
    it                => (others => it_reg_none),
    uart              => uart_reg_none,
    hready_pipe       => '0',
    rstreqn           => '1',
    deadlock_hit      => '0',
    deadlock_addr     => x"00000000",
    deadlock_hwrite   => '0',
    deadlock_hsize    => "000",
    deadlock_cpustate => (others => '0'),
    deadlock_multi    => '0'
    );

  type bret_reg_type is record
    rstn_prev: std_ulogic;
    curent: std_logic_vector(2 downto 0);
    bootctr: std_logic_vector(3 downto 0);
  end record;

  constant BRRES: bret_reg_type := (
    rstn_prev => '0',
    curent   => "000",
    bootctr  => "0000"
    );

  signal r,nr: dbgmod5_regs;

--  signal dsui: dsu5_in_type;
--  signal dsuo: dsu5_out_type;

  signal tbi  : tracebuf_in_type5;
  signal tbo  : tracebuf_out_type5;

  signal it_di : itbi_data_array_type;
  signal it_do : itbo_data_array_type;

  signal psrstn: std_logic_vector(2 downto 0);
  signal rstn_sync: std_ulogic;
  signal br,nbr: bret_reg_type;

begin

  comb: process(rstn,r,dbgo,itod,dbgmo,cpumi,uartie,uartoi,tpi,it_do,cpusi,dsubreak,
                dsuen,tbo,br,bretin)
    variable v: dbgmod5_regs;
    variable odbgmi: ahb_mst_in_vector_type(ndbgmst-1 downto 0);
    variable ocpumo: ahb_mst_out_type;
    variable odbgi: l5_debug_in_vector(0 to ncpu-1);
    variable odtoi: l5_dbg_irq_vector(0 to ncpu-1);
    variable otco : trace_control_out_vector(0 to ncpu-1);
    variable otbi : tracebuf_in_type5;
    variable oit_di : itbi_data_array_type;
    variable ouartoe: uart_out_type;
    variable ouartii: uart_in_type;
    variable otstop: std_ulogic;
    variable vfound, vfound2: std_ulogic;
    variable vmst: unsigned(5 downto 0);
    variable hasel1 : std_logic_vector(AREA_H downto AREA_L);
    variable hasel2 : std_logic_vector(8 downto 2);
    variable hasel3 : std_logic_vector(4 downto 2);
    variable hwdata : std_logic_vector(31 downto 0);
    variable hrdata : std_logic_vector(31 downto 0);
    variable rawindex : integer range 0 to (2**NBITS)-1;
    variable index : natural range 0 to NCPU-1;
    subtype itbi_address_add_type is std_logic_vector(log2(itentr)+log2(NCPU) downto 0);
    type itbi_address_add_array_type is array (0 to NCPU-1) of itbi_address_add_type;
    variable vit_pointer : itbi_address_add_array_type;
    variable vit_pointer_inc : itbi_address_add_array_type;
    variable itbuf_read : std_logic_vector(0 to NCPU-1);
    variable dbgmode : std_ulogic;
    variable vresall: std_logic_vector(0 downto 0);
    variable vcpubrk, vcpuall: std_logic_vector(NCPU-1 downto 0);
    variable vsessbuf, vsessmask: std_logic_vector(6*32-1 downto 0);
    variable vsessbusy: std_ulogic;
    variable vc2caddr: std_logic_vector(7 downto 0);
    variable vc2cahi2: std_logic_vector(7 downto 6);
    variable vc2calo6: std_logic_vector(5 downto 0);
    variable vc2cwr: std_ulogic;
    variable vc2cwd, vc2crd: std_logic_vector(31 downto 0);
    variable veffclr: std_ulogic;
    variable vregbits: std_logic_vector(63 downto 0);
    variable vregbits2: std_logic_vector(15 downto 0);
    variable vdelchk: std_ulogic;
    variable plstate2: std_logic_vector(4*NCPU-1 downto 0);
    variable vstate: std_logic_vector(1 downto 0);
    variable vgrphit: std_logic_vector(2 downto 0);

    function maskmatch(addrbits: std_logic_vector; haddr, hmask: integer) return std_ulogic is
      variable haddrv : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(haddr,12));
      variable hmaskv : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(hmask,12));
    begin
      if (addrbits and hmaskv) = (haddrv and hmaskv) then return '1'; else return '0'; end if;
    end;

    function getvec_zeropad(v: std_logic_vector; hidx, lidx: integer) return std_logic_vector is
      variable r: std_logic_vector(hidx downto lidx);
      variable hx,lx: integer;
    begin
      r := (others => '0');
      hx := hidx; if hx > v'high then hx := v'high; end if;
      lx := lidx; if lx < v'low  then lx := v'low;  end if;
      if hx >= lx then
        r(hx downto lx) := v(hx downto lx);
      end if;
      return r;
    end getvec_zeropad;

    function update_vec(vin: std_logic_vector; vnew: std_logic_Vector; lidx: integer) return std_logic_vector is
      variable r: std_logic_vector(vin'range);
    begin
      r := vin;
      for x in 0 to vnew'length-1 loop
        if lidx+x <= r'high then
          r(lidx+x) := vnew(vnew'low+x);
        end if;
      end loop;
      return r;
    end update_vec;

    procedure dsu_reg_access(regaddr: std_logic_vector(6 downto 0);
                             cpuidx: integer range 0 to NCPU-1;
                             sessidx: integer range 0 to NSESS-1;
                             wr: std_ulogic; wdata: std_logic_vector; rdata: out std_logic_vector) is
      variable vrd, vwd: std_logic_vector(31 downto 0);
      variable vsess_stamp: std_ulogic;
    begin
      vwd := wdata;
      vrd := (others => '0');
      vsess_stamp := '0';
      if regaddr(6 downto 4)="011" and wr='1' then vsess_stamp:='1'; end if;
      case regaddr is
        -- 0x00 - 0x7C  global
        when "0000000" =>               -- 0x00 global status
          vrd(31 downto 26) := std_logic_vector(to_unsigned(ncpu-1,6));
          vrd(25 downto 22) := std_logic_vector(to_unsigned(nsess-1,4));
          vrd(21 downto 16) := "000000";  -- Reserved
          vrd(5 downto 3) := r.deadlock_hsize;
          vrd(2) := r.deadlock_hwrite;
          vrd(1) := r.deadlock_multi;
          vrd(0) := r.deadlock_hit;
          if wr='1' then
            if vwd(1)='1' then v.deadlock_multi := '0'; end if;
            if vwd(0)='1' then v.deadlock_hit:='0'; end if;
          end if;
        when "0000001" =>               -- 0x04 cycle timer for trace buffers and CPUs
          if wr = '1' then
            v.dsu.timer(tbits-1 downto 0) := vwd(tbits-1 downto 0);
          end if;
          vrd(tbits-1 downto 0) := r.dsu.timer(tbits-1 downto 0);
        when "0000010" =>  -- 0x08 Timer stop configuration CPU0-31
          if wr='1' then
            v.dsu.tstopcfg := update_vec(v.dsu.tstopcfg, vwd, 0);
          end if;
          vrd := getvec_zeropad(r.dsu.tstopcfg, 31, 0);
        when "0000011" =>  -- 0x0C Timer stop configuration CPU32-63
          if wr='1' then
            v.dsu.tstopcfg := update_vec(v.dsu.tstopcfg, vwd, 32);
          end if;
          vrd := getvec_zeropad(r.dsu.tstopcfg, 63, 32);
        when "0000100" =>               --  0x10 cpu state CPU0-15
          vrd := getvec_zeropad(r.dsu.plstate, 31, 0);
        when "0000101" =>              --  0x14 cpu state CPU16-31
          vrd := getvec_zeropad(r.dsu.plstate, 63, 32);
        when "0000110" =>               -- 0x18 cpu state CPU32-47
          vrd := getvec_zeropad(r.dsu.plstate, 95, 64);
        when "0000111" =>               -- 0x1C cpu state CPU48-63
          vrd := getvec_zeropad(r.dsu.plstate, 127, 96);
        when "0001000" => null;         -- 0x20
        when "0001001" => null;         -- 0x24
        when "0001010" =>  -- 0x28 UART loopback control/status
          if wr='1' then
            -- note vwd(8) code above vwd(9) to allow clearing inovverrun and writing
            -- new byte (possibly setting inoverrun) with same write
            if vwd(8)='1' then
              v.uart.inoverrun := '0';
            end if;
            if vwd(9)='1' then
              if r.uart.insreg="1111111111" then
                v.uart.insreg := "1" & vwd(23 downto 16) & "0";
              else
                v.uart.inoverrun := '1';
              end if;
            end if;
            if vwd(10)='1' then
              v.uart.captfull := '0';
              v.uart.captrp := r.uart.captrp + 1;
            end if;
            if vwd(5)='1' then
              v.uart.captoverrun := '0';
            end if;
            if vwd(15)='1' then
              v.uart.captwp := "0";
              v.uart.captrp := "0";
              v.uart.captfull := '0';
              v.uart.captoverrun := '0';
              v.uart.captsreg := (others => '1');
              v.uart.insreg := (others => '1');
              v.uart.inoverrun := '0';
            end if;
            v.uart.outblock := vwd(3);
            v.uart.outflow := vwd(2);
            v.uart.inblock := vwd(1);
            v.uart.inflow := vwd(0);
          end if;
          vrd(23 downto 16) := r.uart.captb(to_integer(r.uart.captrp));
          vrd(8) := r.uart.inoverrun;
          vrd(7) := r.uart.captwp(0);
          vrd(6) := r.uart.captrp(0);
          vrd(5) := r.uart.captoverrun;
          vrd(4) := r.uart.captfull;
          vrd(3) := r.uart.outblock;
          vrd(2) := r.uart.outflow;
          vrd(1) := r.uart.inblock;
          vrd(0) := r.uart.inflow;
        when "0001011" =>  --  0x2C deadlock addr
          vrd := r.deadlock_addr;
        when "0001100" =>               -- 0x30 deadlock cpustate CPU0-15
          vrd := getvec_zeropad(r.deadlock_cpustate, 31, 0);
        when "0001101" =>               -- 0x34 deadlock cpustate CPU16-31
          vrd := getvec_zeropad(r.deadlock_cpustate, 63, 32);
        when "0001110" =>               -- 0x38 deadlock cpustate CPU32-47
          vrd := getvec_zeropad(r.deadlock_cpustate, 95, 64);
        when "0001111" =>               -- 0x3C deadlock cpustate CPU48-63
          vrd := getvec_zeropad(r.deadlock_cpustate, 127, 96);
        when "0010000" => null;         -- 0x40
        when "0010001" => null;         -- 0x44
        when "0010010" => null;         -- 0x48
        when "0010011" => null;         -- 0x4C
        when "0010100" => null;         -- 0x50
        when "0010101" => null;         -- 0x54
        when "0010110" => null;         -- 0x58
        when "0010111" => null;         -- 0x5C
        when "0011000" => null;         -- 0x60
        when "0011001" => null;         -- 0x64
        when "0011010" => null;         -- 0x68
        when "0011011" => null;         -- 0x6C
        when "0011100" => null;         -- 0x70
        when "0011101" => null;         -- 0x74
        when "0011110" => null;         -- 0x78
        when "0011111" => null;         -- 0x7C
          -- 0x80 - 0xBC per CPU
        when "0100000" =>          -- 0x80 CPU status/control register
          if wr = '1' then
            if vwd(21)='1' then
              v.dsu.forcedstop(cpuidx) := RRES.dsu.forcedstop(cpuidx);
              v.dsu.prevstate(2*cpuidx+1) := RRES.dsu.prevstate(2*cpuidx+1);
              v.dsu.prevstate(2*cpuidx+0) := RRES.dsu.prevstate(2*cpuidx+0);
            end if;
            if cpuidx=0 then
              v.nolegacy := vwd(20);
            end if;
            v.dsu.blockusr(cpuidx) := vwd(19);
            if vwd(17)='1' then
              v.dsu.usr_wakeup(cpuidx) := v.dsu.usr_wakeup(cpuidx) or vwd(16);
              v.dsu.usr_break(cpuidx) := v.dsu.usr_break(cpuidx) or vwd(15);
              v.dsu.usr_start(cpuidx) := v.dsu.usr_start(cpuidx) or vwd(14);
            else
              v.dsu.usr_wakeup(cpuidx) := v.dsu.usr_wakeup(cpuidx) and not vwd(16);
              v.dsu.usr_break(cpuidx) := v.dsu.usr_break(cpuidx) and not vwd(15);
              v.dsu.usr_start(cpuidx) := v.dsu.usr_start(cpuidx) and not vwd(14);
            end if;
            if vwd(13)='1' then
              v.dsu.dbg_cmd(cpuidx) := vwd(12 downto 10);
            end if;
            v.dsu.bz(cpuidx) := vwd(5);
            v.dsu.bx(cpuidx) := vwd(4);
            v.dsu.bs(cpuidx) := vwd(3);
            v.dsu.bw(cpuidx) := vwd(2);
            v.dsu.be(cpuidx) := vwd(1);
            v.dsu.te(cpuidx) := vwd(0);
          end if;
          vrd(21) := r.dsu.forcedstop(cpuidx);
          if cpuidx=0 then
            vrd(20) := r.nolegacy;
          end if;
          vrd(19) := r.dsu.blockusr(cpuidx);
          vrd(18) := dbgo(cpuidx).idle;
          vrd(17) := '0';               -- or pending bits
          vrd(16) := r.dsu.usr_wakeup(cpuidx);
          vrd(15) := r.dsu.usr_break(cpuidx);
          vrd(14) := r.dsu.usr_start(cpuidx);
          vrd(13) := '0';               -- write cmd bit
          vrd(12 downto 10) := r.dsu.dbg_cmd(cpuidx);
          vrd(9) := r.dsu.prevstate(2*cpuidx+1);
          vrd(8) := r.dsu.prevstate(2*cpuidx);
          vrd(7) := r.dsu.plstate(2*cpuidx+1);
          vrd(6) := r.dsu.plstate(2*cpuidx);
          vrd(5) := r.dsu.bz(cpuidx);
          vrd(4) := r.dsu.bx(cpuidx);
          vrd(3) := r.dsu.bs(cpuidx);
          vrd(2) := r.dsu.bw(cpuidx);
          vrd(1) := r.dsu.be(cpuidx);
          vrd(0) := r.dsu.te(cpuidx);
        when "0100001" => -- 0x84 CPU boot word
          if wr='1' then
            v.dsu.boot_word(cpuidx) := vwd;
          end if;
          vrd := r.dsu.boot_word(cpuidx);
        when "0100010" => -- 0x88 CPU break matrix [cpuidx][31:0]
          if wr='1' then
            v.dsu.brkmat(cpuidx) := update_vec(v.dsu.brkmat(cpuidx), vwd, 0);
          end if;
          vrd := getvec_zeropad(r.dsu.brkmat(cpuidx), 31, 0);
        when "0100011" => -- 0x8C CPU break matrix [cpuidx][63:32]
          if wr='1' then
            v.dsu.brkmat(cpuidx) := update_vec(v.dsu.brkmat(cpuidx), vwd, 32);
          end if;
          vrd := getvec_zeropad(r.dsu.brkmat(cpuidx), 63, 32);
        when "0100100" => -- 0x90 CPU control matrix [cpuidx][31:0]
          if wr='1' then
            v.dsu.ctlmat(cpuidx) := update_vec(v.dsu.ctlmat(cpuidx), vwd, 0);
          end if;
          vrd := getvec_zeropad(r.dsu.ctlmat(cpuidx), 31, 0);
        when "0100101" => -- 0x94 CPU control matrix [cpuidx][63:32]
          if wr='1' then
            v.dsu.ctlmat(cpuidx) := update_vec(v.dsu.ctlmat(cpuidx), vwd, 32);
          end if;
          vrd := getvec_zeropad(r.dsu.ctlmat(cpuidx), 63, 32);
        when "0100110" => -- 0x98 CPU delegation matrix [cpuidx][31:0]
          if wr='1' then
            v.dsu.delegmat(cpuidx) := update_vec(v.dsu.delegmat(cpuidx), vwd, 0);
          end if;
          vrd := getvec_zeropad(r.dsu.delegmat(cpuidx), 31, 0);
        when "0100111" => -- 0x9C CPU delegation matrix [cpuidx][63:32]
          if wr='1' then
            v.dsu.delegmat(cpuidx) := update_vec(v.dsu.delegmat(cpuidx), vwd, 32);
          end if;
          vrd := getvec_zeropad(r.dsu.delegmat(cpuidx), 63, 32);
        when "0101000" => null;         -- 0xA0
        when "0101001" => null;         -- 0xA4
        when "0101010" => null;         -- 0xA8
        when "0101011" => null;         -- 0xAC
        when "0101100" => null;         -- 0xB0
        when "0101101" => null;         -- 0xB4
        when "0101110" => null;         -- 0xB8
        when "0101111" => null;         -- 0xBC
        -- 0xC0-0xFC per session
        when "0110000" =>   -- 0xC0 session claim
          if wr='1' then
            if vwd(31)='1' then
              v.sess(sessidx).claimed := '0';
            end if;
            if r.sess(sessidx).claimed='0' then
              v.sess(sessidx).pending := vwd(30);
            end if;
            v.sess(sessidx).docmd := vwd(17);
            v.sess(sessidx).sampstate := vwd(16);
          else
            -- side effects on read to allow allocation protocol without races
            -- write  pending='1', read back and if you see both pending='1' and
            -- claimed='1' in the readout you won the session
            v.sess(sessidx).pending := '0';
            v.sess(sessidx).claimed := v.sess(sessidx).claimed or r.sess(sessidx).pending;
          end if;
          vrd(31) := r.sess(sessidx).claimed or r.sess(sessidx).pending;
          vrd(30) := r.sess(sessidx).pending;
          vrd(17) := r.sess(sessidx).docmd;
          vrd(16) := r.sess(sessidx).sampstate;
          vrd(15 downto 0):= r.sess(sessidx).tstamp;
        when "0110001" =>  -- 0xC4 session resource mask
          if wr='1' then
            v.sess(sessidx).claimres := vwd(0 downto 0);
          end if;
          vrd(0 downto 0) := r.sess(sessidx).claimres;
        when "0110010" => -- 0xC8 session CPU mask 31:0
          if wr='1' then
            v.sess(sessidx).claimcpu := update_vec(v.sess(sessidx).claimcpu, vwd, 0);
          end if;
          vrd := getvec_zeropad(r.sess(sessidx).claimcpu, 31, 0);
        when "0110011" =>   -- 0xCC session CPU mask 63:32
          if wr='1' then
            v.sess(sessidx).claimcpu := update_vec(v.sess(sessidx).claimcpu, vwd, 32);
          end if;
          vrd := getvec_zeropad(r.sess(sessidx).claimcpu, 63, 32);
        when "0110100" =>   -- 0xD0 session buffer 1
          if wr='1' then
            v.sess(sessidx).dbuf(31 downto 0) := vwd;
          end if;
          vrd := r.sess(sessidx).dbuf(31 downto 0);
        when "0110101" =>   -- 0xD4 session buffer 2
          if wr='1' then
            v.sess(sessidx).dbuf(63 downto 32) := vwd;
          end if;
          vrd := r.sess(sessidx).dbuf(63 downto 32);
        when "0110110" => null;  -- 0xD8 session buffer 3
          if wr='1' then
            v.sess(sessidx).dbuf(95 downto 64) := vwd;
          end if;
          vrd := r.sess(sessidx).dbuf(95 downto 64);
        when "0110111" => null;  -- 0xDC session buffer 4
          if wr='1' then
            v.sess(sessidx).dbuf(127 downto 96) := vwd;
          end if;
          vrd := r.sess(sessidx).dbuf(127 downto 96);
        when "0111000" =>  -- 0xE0 session buffer 5
          if wr='1' then
            v.sess(sessidx).dbuf(159 downto 128) := vwd;
          end if;
          vrd := r.sess(sessidx).dbuf(159 downto 128);
        when "0111001" =>  -- 0xE4  session buffer 6
          if wr='1' then
            v.sess(sessidx).dbuf(191 downto 160) := vwd;
          end if;
          vrd := r.sess(sessidx).dbuf(191 downto 160);
        when "0111010" => null;  -- 0xE8
        when "0111011" => null;  -- 0xEC
        when "0111100" => -- 0xF0 session poll register
          -- read side effect - update time stamp
          vsess_stamp := '1';
          -- read and advance UART capture
          vrd(31 downto 24) := r.uart.captb(to_integer(r.uart.captrp));
          if r.sess(sessidx).claimres(0)='1' then
            if r.uart.captwp /= r.uart.captrp or r.uart.captfull='1' then
              vrd(4) := '1';
              v.uart.captrp := r.uart.captrp + 1;
              v.uart.captfull := '0';
            end if;
            if r.uart.captoverrun='1' then
              vrd(5) := '1';
              v.uart.captoverrun := '0';
            end if;
          end if;
          -- read and clear state change flags
          v.sess(sessidx).statechg := "0000";
          vrd(3 downto 0) := r.sess(sessidx).statechg;
        when "0111101" => null; -- 0xF4
        when "0111110" => null;  -- 0xF8
        when "0111111" => null;  -- 0xFC
        -- 0x100 - 0x17C AHB trace control
        when "1000000" =>               -- 0x100
          if TRACEN then
            vrd((TBUFABITS + 15) downto 16) := r.tr.delaycnt;
            vrd(8) := r.tr.edbgmtf;
            vrd(6 downto 5) := r.tr.timeren & r.tr.tforce;
            vrd(4 downto 0) := conv_std_logic_vector(log2(busw/32), 2) & r.tr.break & r.tr.dcnten & r.tr.enable;
            if wr = '1' then
              v.tr.delaycnt := vwd((TBUFABITS+ 15) downto 16);
              v.tr.edbgmtf := vwd(8);
              v.tr.sample := vwd(7);
              v.tr.timeren := vwd(6);
              v.tr.tforce := vwd(5);
              v.tr.break  := vwd(2);
              v.tr.dcnten := vwd(1);
              v.tr.enable := vwd(0);
            end if;
          end if;
        when "1000001" =>               -- 0x104
          if TRACEN then
            vrd((TBUFABITS - 1 + 4) downto 4) := r.tr.aindex;
            if wr = '1' then
              v.tr.aindex := vwd((TBUFABITS - 1 + 4) downto 4);
            end if;
          end if;
        when "1000010" =>               -- 0x108
        when "1000011" =>               -- 0x10C
          if AHBWATCH then
            vrd(7 downto 0) := '0' & r.twr.reg(2).inv & r.twr.reg(2).couple & r.twr.reg(2).en &
                                  '0' & r.twr.reg(1).inv & r.twr.reg(1).couple & r.twr.reg(1).en;
            if wr = '1' then
              v.twr.reg(2).inv    := vwd(6);
              v.twr.reg(2).couple := vwd(5);
              v.twr.reg(2).en     := vwd(4);
              v.twr.reg(1).inv    := vwd(2);
              v.twr.reg(1).couple := vwd(1);
              v.twr.reg(1).en     := vwd(0);
            end if;
          end if;
        when "1000100" =>               -- 0x110
          if TRACEN then
            vrd(31 downto 2) := r.tr.tbreg(1).addr;
            if wr = '1' then
              v.tr.tbreg(1).addr := vwd(31 downto 2);
            end if;
          end if;
        when "1000101" =>               -- 0x114
          if TRACEN then
            vrd := r.tr.tbreg(1).mask & r.tr.tbreg(1).read & r.tr.tbreg(1).write;
            if wr = '1' then
              v.tr.tbreg(1).mask := vwd(31 downto 2);
              v.tr.tbreg(1).read := vwd(1);
              v.tr.tbreg(1).write := vwd(0);
            end if;
          end if;
        when "1000110" =>               -- 0x118
          if TRACEN then
            vrd(31 downto 2) := r.tr.tbreg(2).addr;
            if wr = '1' then
              v.tr.tbreg(2).addr := vwd(31 downto 2);
            end if;
          end if;
        when "1000111" =>               -- 0x11C
          if TRACEN then
            vrd := r.tr.tbreg(2).mask & r.tr.tbreg(2).read & r.tr.tbreg(2).write;
            if wr = '1' then
              v.tr.tbreg(2).mask := vwd(31 downto 2);
              v.tr.tbreg(2).read := vwd(1);
              v.tr.tbreg(2).write := vwd(0);
            end if;
          end if;
        when "1001000" | "1001001" | "1001010" | "1001011" =>  --  0x120-0x12C
          if AHBWATCH then
            for i in 0 to 3 loop
              if i = conv_integer(hasel2(3 downto 2)) then
                vrd(31*ahbwp_nz downto 0) :=
                  r.twr.reg(1).data(((127-i*32) mod AHBDW)*ahbwp_nz downto ((96*i-32) mod AHBDW)*ahbwp_nz);
                if wr = '1' then
                  v.twr.reg(1).data(((127-i*32) mod AHBDW)*ahbwp_nz downto ((96*i-32) mod AHBDW)*ahbwp_nz) :=
                    vwd(31*ahbwp_nz downto 0);
                end if;
              end if;
            end loop;
          end if;
        when "1001100" | "1001101" | "1001110" | "1001111" =>  -- 0x130-0x13C
          if AHBWATCH then
            for i in 0 to 3 loop
              if i = conv_integer(hasel2(3 downto 2)) then
                vrd(31*ahbwp_nz downto 0) :=
                  r.twr.reg(1).mask(((127-i*32) mod AHBDW)*ahbwp_nz downto ((96*i-32) mod AHBDW)*ahbwp_nz);
                if wr = '1' then
                  v.twr.reg(1).mask(((127-i*32) mod AHBDW)*ahbwp_nz downto ((96*i-32) mod AHBDW)*ahbwp_nz) :=
                    vwd(31*ahbwp_nz downto 0);
                end if;
              end if;
            end loop;
          end if;
        when "1010000" | "1010001" | "1010010" | "1010011" =>  -- 0x140-0x14C
          if AHBWATCH then
            for i in 0 to 3 loop
              if i = conv_integer(hasel2(3 downto 2)) then
                vrd(31*ahbwp_nz downto 0) :=
                  r.twr.reg(2).data(((127-i*32) mod AHBDW)*ahbwp_nz downto ((96*i-32) mod AHBDW)*ahbwp_nz);
                if wr = '1' then
                  v.twr.reg(2).data(((127-i*32) mod AHBDW)*ahbwp_nz downto ((96*i-32) mod AHBDW)*ahbwp_nz) :=
                    vwd(31*ahbwp_nz downto 0);
                end if;
              end if;
            end loop;
          end if;
        when "1010100" | "1010101" | "1010110" | "1010111" =>  -- 0x150-0x15C
          if AHBWATCH then
            for i in 0 to 3 loop
              if i = conv_integer(hasel2(3 downto 2)) then
                vrd(31*ahbwp_nz downto 0) :=
                  r.twr.reg(2).mask(((127-i*32) mod AHBDW)*ahbwp_nz downto ((96*i-32) mod AHBDW)*ahbwp_nz);
                if wr = '1' then
                  v.twr.reg(2).mask(((127-i*32) mod AHBDW)*ahbwp_nz downto ((96*i-32) mod AHBDW)*ahbwp_nz) :=
                    vwd(31*ahbwp_nz downto 0);
                end if;
              end if;
            end loop;
          end if;
        when "1011000" => null;         -- 0x160
        when "1011001" => null;         -- 0x164
        when "1011010" => null;         -- 0x168
        when "1011011" => null;         -- 0x16C
        when "1011100" => null;         -- 0x170
        when "1011101" => null;         -- 0x174
        when "1011110" => null;         -- 0x178
        when "1011111" => null;         -- 0x17C
        -- 0x180 - 0x1FC Instruction trace control
        when "1100000" =>          -- 0x180 itrace pointer
          vrd := (others=>'0');
          vrd(log2(itentr)-1 downto 0) := r.it(cpuidx).pointer(log2(itentr)-1 downto 0);
          if wr = '1' then
            v.it(cpuidx).pointer := vwd(log2(itentr)-1+log2(NCPU) downto 0);
            v.it(cpuidx).set_pointer_inc := '1';
          end if;
        when "1100001" =>         -- 0x184 itrace control-1
          vrd               := (others => '0');
          vrd(23)           := r.it(cpuidx).enable;
          vrd(31 downto 28) := r.it(cpuidx).addr_f;
          vrd(27 downto 24) := r.it(cpuidx).addr_f_p;
          vrd(22 downto 19) := r.it(cpuidx).inst_filter;
          if wr = '1' then
            v.it(cpuidx).trace_upd   := '1';
            v.it(cpuidx).enable      := vwd(23);
            v.it(cpuidx).addr_f      := vwd(31 downto 28);
            v.it(cpuidx).addr_f_p    := vwd(27 downto 24);
            v.it(cpuidx).inst_filter := vwd(22 downto 19);
          end if;
        when "1100010" => null;         -- 0x188
        when "1100011" => null;         -- 0x18C
        when "1100100" => null;         -- 0x190
        when "1100101" => null;         -- 0x194
        when "1100110" => null;         -- 0x198
        when "1100111" => null;         -- 0x19C
        when "1101000" => null;         -- 0x1A0
        when "1101001" => null;         -- 0x1A4
        when "1101010" => null;         -- 0x1A8
        when "1101011" => null;         -- 0x1AC
        when "1101100" => null;         -- 0x1B0
        when "1101101" => null;         -- 0x1B4
        when "1101110" => null;         -- 0x1B8
        when "1101111" => null;         -- 0x1BC
        when "1110000" => null;         -- 0x1C0
        when "1110001" => null;         -- 0x1C4
        when "1110010" => null;         -- 0x1C8
        when "1110011" => null;         -- 0x1CC
        when "1110100" => null;         -- 0x1D0
        when "1110101" => null;         -- 0x1D4
        when "1110110" => null;         -- 0x1D8
        when "1110111" => null;         -- 0x1DC
        when "1111000" => null;         -- 0x1E0
        when "1111001" => null;         -- 0x1E4
        when "1111010" => null;         -- 0x1E8
        when "1111011" => null;         -- 0x1EC
        when "1111100" => null;         -- 0x1F0
        when "1111101" => null;         -- 0x1F4
        when "1111110" => null;         -- 0x1F8
        when "1111111" => null;         -- 0x1FC
        when others =>
      end case;
      rdata := vrd;
      if vsess_stamp='1' then
        v.sess(sessidx).tstamp := r.dsu.timer(29 downto 14);
      end if;
    end dsu_reg_access;

  begin
    ---------------------------------------------------------------------------
    -- Init variables
    ---------------------------------------------------------------------------
    v := r;
    odbgi := (others => l5_dbgi_none);
    odtoi := (others => (irqvec => (others => '0')));
    odbgmi := (others => ahbm_in_none);
    ocpumo := ahbm_none;
    otbi := tracebuf_in_type5_none;

    ---------------------------------------------------------------------------
    -- Debug AHB port handling logic (main part inside FSM)
    ---------------------------------------------------------------------------
    v.rstreqn := '1';
    v.hready_pipe := cpumi.hready;
    for m in 0 to ndbgmst-1 loop
      odbgmi(m).hgrant := (others => '1');
      odbgmi(m).hready := r.dbgmst(m).hready;
      odbgmi(m).hresp := "00";
      odbgmi(m).hrdata := ahbdrivedata(r.hdata);
      if r.dbgmst(m).hready='1' then
        v.dbgmst(m).haddr := dbgmo(m).haddr;
        v.dbgmst(m).hsize := dbgmo(m).hsize;
        v.dbgmst(m).hwrite := dbgmo(m).hwrite;
        v.dbgmst(m).hburst0 := dbgmo(m).hburst(0);
        if dbgmo(m).htrans(1) /= '0' then
          v.dbgmst(m).hready := '0';
        end if;
      end if;
      -- Low-level debug register accessible even if AHB bus or debug module
      -- FSM has locked up.
      -- Located on area 000 (DSU registers) with address bit 18 high
      -- Writing 0x99 causes reset (if implemented in SoC)
      -- Reading returns system status signal
      if dsuen='1' then
        if maskmatch(r.dbgmst(m).haddr(31 downto 20), dsuhaddr, dsuhmask)='1' and
          r.dbgmst(m).haddr(21 downto 18)="0001" then
          hrdata := (others => '0');
          hrdata(31 downto 16) := sysstat;
          hrdata(1) := r.deadlock_hit;
          hrdata(0) := r.hready_pipe;
          odbgmi(m).hrdata := ahbdrivedata(sysstat & "0000000000000000");
          if r.dbgmst(m).hwrite='1' and r.dbgmst(m).hready='0' and
            dbgmo(m).hwdata(7 downto 0)=x"99" then
            v.rstreqn := '0';
          end if;
        end if;
      end if;
      -- Forward DFT signals
      odbgmi(m).testen  := cpumi.testen;
      odbgmi(m).testrst := cpumi.testrst;
      odbgmi(m).scanen  := cpumi.scanen;
      odbgmi(m).testoen := cpumi.testoen;
      odbgmi(m).testin  := cpumi.testin;
    end loop;

    ---------------------------------------------------------------------------
    -- Processor bus master logic and AHB PnP generation for debug masters
    ---------------------------------------------------------------------------
    ocpumo.hbusreq := r.mst_hbusreq;
    ocpumo.htrans := r.mst_htrans;
    ocpumo.haddr := r.mst_haddr;
    ocpumo.hwrite := r.mst_hwrite;
    ocpumo.hsize := r.mst_hsize;
    ocpumo.hburst := r.mst_hburst;
    -- For now re-use the DSU5 PnP ID for the master
    ocpumo.hconfig(0) := hconfig(0);
    ocpumo.hindex := cpumidx;
    ocpumo.hwdata := ahbdrivedata(r.hdata);
    hwdata := r.hdata;
    if cpumi.hready='1' then
      v.mst_granted := cpumi.hgrant(cpumidx);
      v.mst_inacc := r.mst_granted and r.mst_htrans(1);
      if r.mst_inacc='1' then
        if ( maskmatch(r.mst_haddr(31 downto 20), pnpaddrhi, 16#fff#)='1' and
             maskmatch(r.mst_haddr(19 downto  8), pnpaddrlo, 16#ff0#)='1' and
             r.mst_haddr(11)='1' and
             r.mst_haddr(10 downto 5)=std_logic_vector(to_unsigned(dsuslvidx,6)) ) then
          v.hdata := hconfig(to_integer(unsigned(r.mst_haddr(4 downto 2))));
        elsif ( maskmatch(r.mst_haddr(31 downto 20), pnpaddrhi, 16#fff#)='1' and
             maskmatch(r.mst_haddr(19 downto  8), pnpaddrlo, 16#ff0#)='1' and
             r.mst_haddr(11)='0' and
             unsigned(r.mst_haddr(10 downto 5))>=to_unsigned(dsumstidx,6) ) then
          vmst := unsigned(r.mst_haddr(10 downto 5))-dsumstidx;
          if vmst >= ndbgmst then
            v.hdata := (others => '0');
          else
            v.hdata := dbgmo(to_integer(vmst)).hconfig(to_integer(unsigned(r.mst_haddr(4 downto 2))));
          end if;
        elsif r.mst_hwrite='0' then
          v.hdata := ahbreadword(cpumi.hrdata, r.mst_haddr(4 downto 2));
        end if;
      end if;
    end if;

    ---------------------------------------------------------------------------
    -- Processor control
    ---------------------------------------------------------------------------
    for i in 0 to NCPU-1 loop
      odbgi(i).dynid := std_logic_vector(to_unsigned(i,4));
      odbgi(i).cmd   := r.dsu.cpu_cmd(i);
      odbgi(i).freeze := '0';
      odbgi(i).pushpc := r.dsu.pushpc(i);
      odbgi(i).pcin := r.dsu.pcin;
      -- accen set in FSM state
      odbgi(i).mosi.addr := r.mst_haddr(23 downto 2);
      odbgi(i).mosi.accwr := r.mst_hwrite;
      odbgi(i).mosi.wrdata := hwdata;
      odbgi(i).bsoft := r.dsu.bs(i);
      odbgi(i).bwatch := r.dsu.bw(i);
      odbgi(i).btrapa := r.dsu.bx(i);
      odbgi(i).btrape := r.dsu.bz(i);
      odbgi(i).timer(tbits-1 downto 0) := r.dsu.timerrep(i);
      odbgi(i).boot_word := r.dsu.boot_word(i);
      odbgi(i).smpflush := r.smp(i).icfin & r.smp(i).tlbfin;
    end loop;

    --wake up command from processor
    for i in 0 to NCPU-1 loop
      if dbgo(i).wakeup_req = '1' then
        v.dsu.usr_wakeup(i) := '1';
      end if;
    end loop;

    for i in 0 to NCPU-1 loop
      -- Forward debug command
      v.dsu.cpu_cmd(i) := r.dsu.dbg_cmd(i);
      -- Clear dbg_cmd when reached desired state (wakeup/start cleared instantly)
      if r.dsu.dbg_cmd(i)=CPUCMD_START or r.dsu.dbg_cmd(i)=CPUCMD_WAKEUP then
        v.dsu.dbg_cmd(i) := CPUCMD_NONE;
      end if;
      if r.dsu.dbg_cmd(i)=CPUCMD_BREAK and r.dsu.plstate(2*i+1 downto 2*i)=CPUSTATE_STOPPED then
        v.dsu.dbg_cmd(i) := CPUCMD_NONE;
      end if;
      if r.dsu.dbg_cmd(i)(2)='1' and r.dsu.dbg_cmd(i)(1 downto 0)=r.dsu.plstate(2*i+1 downto 2*i) then
        v.dsu.dbg_cmd(i) := CPUCMD_NONE;
      end if;
      -- Forward commands requested by user, clear pending commands when processor
      -- reached desired state
      if r.dsu.blockusr(i)='0' then
        if r.dsu.usr_break(i)='1' then
          v.dsu.cpu_cmd(i) := CPUCMD_BREAK;
        elsif r.dsu.usr_wakeup(i)='1' then
          v.dsu.cpu_cmd(i) := CPUCMD_WAKEUP;
          v.dsu.usr_wakeup(i) := '0';
        elsif r.dsu.usr_start(i)='1' then
          v.dsu.cpu_cmd(i) := CPUCMD_START;
          v.dsu.usr_start(i) := '0';
        end if;
        if r.dsu.plstate(2*i+1 downto 2*i)=CPUSTATE_STOPPED then
          v.dsu.usr_break(i) := '0';
        end if;
      end if;
    end loop;

    -- Capture CPU state into pipeline register, update prevstate on changes
    v.dsu.statechg := (others => '0');
    for i in 0 to NCPU-1 loop
      v.dsu.plstate(2*i+1 downto 2*i) := dbgo(i).cpustate;
      if dbgo(i).cpustate /= r.dsu.plstate(2*i+1 downto 2*i) then
        v.dsu.statechg(i) := '1';
        v.dsu.prevstate(2*i+1 downto 2*i) := r.dsu.plstate(2*i+1 downto 2*i);
        v.dsu.forcedstop(i) := '0';
        if dbgo(i).cpustate=CPUSTATE_STOPPED and (r.dsu.blockusr(i)='1' or r.dsu.usr_break(i)='0') then
          v.dsu.forcedstop(i) := '1';
        end if;
      end if;
      v.dsu.plidle(i) := dbgo(i).idle;
    end loop;

    -- See if any CPU is breaking into STOPPED/ERRMODE and break related CPUs
    -- as setup via break matrix
    vcpubrk := (others => '0');
    for i in 0 to NCPU-1 loop
      if r.dsu.plstate(2*i)='1' and dbgo(i).cpustate(0)='0' then
        vcpubrk := vcpubrk or r.dsu.brkmat(i);
      end if;
    end loop;
    for i in 0 to NCPU-1 loop
      if vcpubrk(i)='1' then
        v.dsu.dbg_cmd(i) := CPUCMD_BREAK;
        v.dsu.blockusr(i) := '1';
      end if;
    end loop;

    if r.tstop='0' then
      v.dsu.timer := add(r.dsu.timer, 1);
    end if;

    ---------------------------------------------------------------------------
    -- CPU to CPU control interface
    ---------------------------------------------------------------------------

    veffclr := '0';

    for i in 0 to NCPU-1 loop
      if r.smp(i).ipiin='1' then
        odtoi(i).irqvec(to_integer(unsigned(r.smp(i).ipiirq))) := '1';
      end if;
    end loop;
    -- Forward SMP broadcast within configured SMP groups
    for i in 0 to NCPU-1 loop
      vgrphit := "000";
      for j in 0 to NCPU-1 loop
        if r.smpgroup(i)(j)='1' then
          vgrphit(2) := vgrphit(2) or r.smp(j).icfout;
          vgrphit(1) := vgrphit(1) or r.smp(j).tlbfout;
          vgrphit(0) := vgrphit(0) or r.smp(j).ipiout;
        end if;
      end loop;
      for j in 0 to NCPU-1 loop
        if r.smpgroup(i)(j)='1' then
          v.smp(j).icfin  := v.smp(j).icfin  or vgrphit(2);
          v.smp(j).tlbfin := v.smp(j).tlbfin or vgrphit(1);
          v.smp(j).ipiin  := v.smp(j).ipiin  or vgrphit(0);
        end if;
      end loop;
    end loop;

    -- Note registers as seen through the c2c interface from inside the CPUs
    -- are rotated modulo NCPU so for CPU #N, itself is shown as CPU 0, #N+1
    -- shown as CPU #1, etc.
    plstate2 := r.dsu.plstate & r.dsu.plstate;
    for i in 0 to NCPU-1 loop
      odbgi(i).c2c_miso := r.c2c_miso(i);
      vc2caddr := dbgo(i).c2c_mosi.addr(7 downto 0);
      vc2cahi2 := vc2caddr(7 downto 6);
      vc2calo6 := vc2caddr(5 downto 0);
      vc2cwr := dbgo(i).c2c_mosi.accwr;
      vc2cwd := dbgo(i).c2c_mosi.wrdata;
      vc2crd := (others => '0');
      v.c2c_miso(i).accrdy := '0';
      v.smp(i).ipiout := '0';
      v.smp(i).tlbfout := '0';
      v.smp(i).icfout := '0';
      if dbgo(i).c2c_mosi.accen='1' and r.c2c_miso(i).accrdy='0' and r.dsu.effctl_allstab='1' then
        case vc2cahi2 is
          when "00" =>
            case vc2calo6 is
              when "000000" => -- 0x00 Effective control matrix 31:0 (read only)
                for x in 0 to 31 loop
                  if x<NCPU then
                    vc2crd(x) := r.dsu.effctl(i)((i+x) mod NCPU);
                  end if;
                end loop;
              when "000001" => -- 0x04 Effective control matrix 63:32 (read only)
                for x in 0 to 31 loop
                  if x<NCPU then
                    vc2crd(x) := r.dsu.effctl(i)((i+x+32) mod NCPU);
                  end if;
                end loop;
              when "000010" => -- 0x08 Delegation matrix 31:0
                for x in 0 to 31 loop
                  if x < NCPU then
                    vc2crd(x) := r.dsu.delegmat(i)((i+x) mod NCPU);
                    if vc2cwr='1' then
                      v.dsu.delegmat(i)((i+x) mod NCPU) := vc2cwd(x);
                      veffclr := '1';
                    end if;
                  end if;
                end loop;
              when "000011" => -- 0x0C Delegation matrix 63:32
                for x in 0 to 31 loop
                  if x+32 < NCPU then
                    vc2crd(x) := r.dsu.delegmat(i)((i+x+32) mod NCPU);
                    if vc2cwr='1' then
                      v.dsu.delegmat(i)((i+x+32) mod NCPU) := vc2cwd(x);
                      veffclr := '1';
                    end if;
                  end if;
                end loop;
              when "000100" => -- 0x10 CPU states CPU 15:0
                vc2crd := getvec_zeropad(plstate2, 2*i+31, 2*i);
                --   Block CPU from checking states on CPUs it's not
                --     allowed to control
                for x in 0 to 15 loop
                  if r.dsu.effctl(i)((i+x) mod NCPU)='0' or x >= NCPU then
                    vc2crd(2*x+1 downto 2*x) := "00";
                  end if;
                end loop;
              when "000101" => -- 0x14 CPU states CPU 31:16
                vc2crd := getvec_zeropad(plstate2, 2*i+63, 2*i+32);
                for x in 0 to 15 loop
                  if r.dsu.effctl(i)((i+x+16) mod NCPU)='0' or x+16 >= NCPU then
                    vc2crd(2*x+1 downto 2*x) := "00";
                  end if;
                end loop;
              when "000110" => -- 0x18 CPU states CPU 47:32
                vc2crd := getvec_zeropad(plstate2, 2*i+95, 2*i+64);
                for x in 0 to 15 loop
                  if r.dsu.effctl(i)((i+x+32) mod NCPU)='0' or x+32 >= NCPU then
                    vc2crd(2*x+1 downto 2*x) := "00";
                  end if;
                end loop;
              when "000111" => -- 0x1C CPU states CPU 63:48
                vc2crd := getvec_zeropad(plstate2, 2*i+127, 2*i+96);
                for x in 0 to 15 loop
                  if r.dsu.effctl(i)((i+x+48) mod NCPU)='0' or x+48 >= NCPU then
                    vc2crd(2*x+1 downto 2*x) := "00";
                  end if;
                end loop;
              when "001000" => -- 0x20 CPU bootup request address
                vc2crd(31 downto 3) := r.bootreq(i).baddr(31 downto 3);
                if r.bootreq(i).bact='0' and vc2cwr='1' then
                  v.bootreq(i).baddr(31 downto 3) := vc2cwd(31 downto 3);
                end if;
              when "001001" => -- 0x24 CPU bootup control/status
                if vc2cwr='1' then
                  if vc2cwd(0)='1' and r.bootreq(i).ben='0' and r.bootreq(i).bact='0' then
                    v.bootreq(i).ben := '1';
                    v.bootreq(i).bdone := '0';
                    v.bootreq(i).bfail := '0';
                    v.bootreq(i).bcancel := '0';
                    v.bootreq(i).bcpu := unsigned(vc2cwd(8+log2x(ncpu)-1 downto 8)) + i;
                  end if;
                  if vc2cwd(4)='1' and r.bootreq(i).ben='1' and r.bootreq(i).bact='0' then
                    v.bootreq(i).ben := '0';
                    v.bootreq(i).bcancel := '1';
                  end  if;
                end if;
                vc2crd(4) := r.bootreq(i).bcancel;
                vc2crd(3) := r.bootreq(i).bfail;
                vc2crd(2) := r.bootreq(i).bdone;
                vc2crd(1) := r.bootreq(i).bact;
                vc2crd(0) := r.bootreq(i).ben;
              when "001010" => -- 0x28 legacy interface control
                if i=0 then
                  if vc2cwr='1' then
                    if vc2cwd(0)='1' then v.nolegacy:='1'; end if;
                  end if;
                  vc2crd(0) := r.nolegacy;
                end if;
              when "001100" =>          -- 0x30 SMP grouping matrix CPU 31:0
                for x in 0 to 31 loop
                  if x < NCPU then
                    vc2crd(x) := r.smpgroup(i)((i+x) mod NCPU);
                    if vc2cwr='1' then
                      v.smpgroup(i)((i+x) mod NCPU) := vc2cwd(x);
                    end if;
                  end if;
                end loop;
              when "001101" =>          -- 0x34 SMP grouping matrix CPU 63:32
                for x in 0 to 31 loop
                  if x+32 < NCPU then
                    vc2crd(x) := r.smpgroup(i)((i+x+32) mod NCPU);
                    if vc2cwr='1' then
                      v.smpgroup(i)((i+x+32) mod NCPU) := vc2cwd(x);
                    end if;
                  end if;
                end loop;
              when "001110" =>          -- 0x38 SMP configuration
                if vc2cwr='1' then
                  v.smp(i).ipiirq := vc2cwd(12 downto 8);
                  v.smp(i).icfen := vc2cwd(2);
                  v.smp(i).tlbfen := vc2cwd(1);
                  v.smp(i).ipien  := vc2cwd(0);
                end if;
                vc2crd(12 downto 8)  := r.smp(i).ipiirq;
                vc2crd(2) := r.smp(i).icfen;
                vc2crd(1) := r.smp(i).tlbfen;
                vc2crd(0) := r.smp(i).ipien;
              when "001111" =>          -- 0x3C SMP broadcast register
                if vc2cwr='1' then
                  v.smp(i).icfout := vc2cwd(2);
                  v.smp(i).tlbfout := vc2cwd(1);
                  v.smp(i).ipiout := vc2cwd(0);
                end if;
              when "010000" | "010010" => -- 0x40, 0x48 Read/set/clear start bit for CPU 31:0
                vregbits := (others => '0');
                for c in 0 to NCPU-1 loop
                  vregbits(c) := r.dsu.usr_start((c+i) mod NCPU);
                end loop;
                vc2crd := vregbits(31 downto 0);
                for c in 0 to 31 loop
                  if c < NCPU then
                    if vc2cwr='1' and vc2cwd(c)='1' and r.dsu.effctl(i)((i+c) mod NCPU)='1' then
                      if vc2caddr(1)='0' then
                        v.dsu.usr_start((i+c) mod NCPU) := '1';
                      else
                        v.dsu.usr_start((i+c) mod NCPU) := '0';
                      end if;
                    end if;
                  end if;
                end loop;
              when "010001"| "010011" => -- 0x44, 0x4C Read/set/clear start bit for CPU 63:32
                vregbits := (others => '0');
                for c in 0 to NCPU-1 loop
                  vregbits(c) := r.dsu.usr_start((c+i+32) mod NCPU);
                end loop;
                vc2crd := vregbits(31 downto 0);
                for c in 0 to 31 loop
                  if c+32 < NCPU then
                    if vc2cwr='1' and vc2cwd(c)='1' and r.dsu.effctl(i)((i+c+32) mod NCPU)='1' then
                      if vc2caddr(1)='0' then
                        v.dsu.usr_start((i+c+32) mod NCPU) := '1';
                      else
                        v.dsu.usr_start((i+c+32) mod NCPU) := '0';
                      end if;
                    end if;
                  end if;
                end loop;
              when "010100" | "010110" => -- 0x50, 0x58 Read/set/clear break bit for CPU 31:0
                vregbits := (others => '0');
                for c in 0 to NCPU-1 loop
                  vregbits(c) := r.dsu.usr_break((c+i) mod NCPU);
                end loop;
                vc2crd := vregbits(31 downto 0);
                for c in 0 to 31 loop
                  if c < NCPU then
                    if vc2cwr='1' and vc2cwd(c)='1' and r.dsu.effctl(i)((i+c) mod NCPU)='1' then
                      if vc2caddr(1)='0' then
                        v.dsu.usr_break((i+c) mod NCPU) := '1';
                      else
                        v.dsu.usr_break((i+c) mod NCPU) := '0';
                      end if;
                    end if;
                  end if;
                end loop;
              when "010101"| "010111" => -- 0x54, 0x5C Read/set/clear break bit for CPU 63:32
                vregbits := (others => '0');
                for c in 0 to NCPU-1 loop
                  vregbits(c) := r.dsu.usr_break((c+i+32) mod NCPU);
                end loop;
                vc2crd := vregbits(31 downto 0);
                for c in 0 to 31 loop
                  if c+32 < NCPU then
                    if vc2cwr='1' and vc2cwd(c)='1' and r.dsu.effctl(i)((i+c+32) mod NCPU)='1' then
                      if vc2caddr(1)='0' then
                        v.dsu.usr_break((i+c+32) mod NCPU) := '1';
                      else
                        v.dsu.usr_break((i+c+32) mod NCPU) := '0';
                      end if;
                    end if;
                  end if;
                end loop;
              when "011000" | "011010" => -- 0x60, 0x68 Read/set/clear wakeup bit for CPU 31:0
                vregbits := (others => '0');
                for c in 0 to NCPU-1 loop
                  vregbits(c) := r.dsu.usr_wakeup((c+i) mod NCPU);
                end loop;
                vc2crd := vregbits(31 downto 0);
                for c in 0 to 31 loop
                  if c < NCPU then
                    if vc2cwr='1' and vc2cwd(c)='1' and r.dsu.effctl(i)((i+c) mod NCPU)='1' then
                      if vc2caddr(1)='0' then
                        v.dsu.usr_wakeup((i+c) mod NCPU) := '1';
                      else
                        v.dsu.usr_wakeup((i+c) mod NCPU) := '0';
                      end if;
                    end if;
                  end if;
                end loop;
              when "011001"| "011011" => -- 0x64, 0x6C Read/set/clear wakeup bit for CPU 63:32
                vregbits := (others => '0');
                for c in 0 to NCPU-1 loop
                  vregbits(c) := r.dsu.usr_wakeup((c+i+32) mod NCPU);
                end loop;
                vc2crd := vregbits(31 downto 0);
                for c in 0 to 31 loop
                  if c+32 < NCPU then
                    if vc2cwr='1' and vc2cwd(c)='1' and r.dsu.effctl(i)((i+c+32) mod NCPU)='1' then
                      if vc2caddr(1)='0' then
                        v.dsu.usr_wakeup((i+c+32) mod NCPU) := '1';
                      else
                        v.dsu.usr_wakeup((i+c+32) mod NCPU) := '0';
                      end if;
                    end if;
                  end if;
                end loop;

              when others => null;
            end case;

          when "01" =>                  -- 0x100-0x1FC CPU boot word for CPU i..i+63
            for c in 0 to NCPU-1 loop
              if vc2calo6 = std_logic_vector(to_unsigned((c-i) mod NCPU, 6)) then
                -- note CPU is always allowed to change it's own data word
                if c=i or r.dsu.effctl(i)(c)='1' then
                  vc2crd := r.dsu.boot_word(c);
                  if vc2cwr='1' then
                    v.dsu.boot_word(c) := vc2cwd;
                  end if;
                end if;
              end if;
            end loop;

          when others => null;
        end case;
        v.c2c_miso(i).accrdy := '1';
        v.c2c_miso(i).rddata :=  vc2crd;
      end if;

      if r.dsu.effctl_allstab='1' then
        v.smpgroup(i) := v.smpgroup(i) and r.dsu.effctl(i);
      end if;
    end loop;

    -- Bootup via IRQ controller (legacy)
    v.dsu.pushpc := (others => '0');
    if r.nolegacy='0' then
      for i in 0 to NCPU-1 loop
        if itod(i).resume='1' then
          v.dsu.usr_start(i) := '1';
        end if;
        if itod(i).pwdsetaddr='1' and r.dsu.blockusr(i)='0' then
          v.dsu.pushpc(i) := '1';
          v.dsu.pcin := itod(i).pwdnewaddr;
        end if;
      end loop;
    end if;

    -- Generate effective control matrix
    if r.dsu.effctl_allstab='1' then
      v.dsu.effctl := r.dsu.effctl_new;
    end if;
    v.dsu.effctl_allstab := '1';
    for i in 0 to NCPU-1 loop
      if r.dsu.effctl_stab(i)='0' then
        v.dsu.effctl_allstab := '0';
      end if;
    end loop;
    for i in 0 to NCPU-1 loop
      -- Direct control
      v.dsu.effctl_new(i) := v.dsu.effctl_new(i) or r.dsu.ctlmat(i);
      -- Inherited control via delegation (possibly recursive)
      for c in i+1 to NCPU-1 loop       -- CPU we want to control
        for d in 0 to i loop            -- Delegating CPU
          vdelchk := '1';
          -- Check that CPU #d has permission to control CPU #c
          if r.dsu.effctl_new(d)(c)='0' then vdelchk := '0'; end if;
          -- Check that CPU #d has delegated to us
          if r.dsu.delegmat(d)(i)='0' then vdelchk := '0'; end if;
          -- Check that CPU #d has not delegated to another CPU in the range i+1..c
          for x in i+1 to c loop
            if r.dsu.delegmat(d)(x)='1' then vdelchk := '0'; end if;
          end loop;
          -- All OK?
          if vdelchk='1' then
            v.dsu.effctl_new(i)(c) := '1';
          end if;
        end loop;
      end loop;
      v.dsu.effctl_stab(i) := '0';
      if v.dsu.effctl_new(i)=r.dsu.effctl_new(i) then
        v.dsu.effctl_stab(i) := '1';
      end if;
    end loop;
    if r.dsu.effctl_clr='1' then
      v.dsu.effctl_new := (others => (others => '0'));
      v.dsu.effctl_stab := (others => '0');
      v.dsu.effctl_allstab := '0';
    end if;

    -- Boot request permissions check
    for i in 0 to NCPU-1 loop
      v.bootreq(i).maystart := '0';
      v.bootreq(i).permchk := '1';
      if r.bootreq(i).ben='1' then
        if r.dsu.blockusr(to_integer(r.bootreq(i).bcpu))='0' then
          v.bootreq(i).maystart := '1';
        end if;
        if r.dsu.effctl(i)(to_integer(r.bootreq(i).bcpu))='0' then
          v.bootreq(i).permchk := '0';
          v.bootreq(i).maystart := '0';
        end if;
        if r.bootreq(i).permchk='0' then
          v.bootreq(i).ben := '0';
          v.bootreq(i).bdone := '0';
          v.bootreq(i).bfail := '1';
          v.bootreq(i).bcancel := '0';
        end if;
      end if;
    end loop;

    ---------------------------------------------------------------------------
    -- Session management
    ---------------------------------------------------------------------------
    -- Sample CPU states into data buffer
    for i in 0 to NSESS-1 loop
      if r.sess(i).sampstate='1' then
        v.sess(i).dbuf(2*NCPU-1 downto 0) := r.dsu.plstate;
        for c in 0 to NCPU-1 loop
          v.sess(i).dbuf(128+c) := r.dsu.blockusr(c);
        end loop;
      end if;
      v.sess(i).sampstate := '0';
    end loop;
    -- Perform command on multiple CPUs atomically from data buffer
    -- This goes via an arbitration stage to avoid timing-heavy paths
    vsessbuf := (others => '0');
    if notx(std_logic_vector(r.selsess)) then
      vsessbuf := r.sess(to_integer(r.selsess)).dbuf;
    else
      setx(vsessbuf);
    end if;
    if r.sesscmd='1' then
      for i in 0 to NCPU-1 loop
        for b in 0 to 1 loop
          if vsessbuf(32+b+2*i)='1' then
            if vsessbuf(16*b+3)='1' then
              v.dsu.dbg_cmd(i) := vsessbuf(16*b+2 downto 16*b);
            end if;
            v.dsu.blockusr(i) := (v.dsu.blockusr(i) and not vsessbuf(16*b+4)) or vsessbuf(16*b+5);
          end if;
        end loop;
      end loop;
      v.sess(to_integer(r.selsess)).docmd := '0';
    end if;
    v.sesscmd := '0';
    v.selsess := (others => '0');
    for i in 0 to NSESS-1 loop
      if v.sess(i).docmd='1' then
        v.selsess := to_unsigned(i, log2x(nsess));
        v.sesscmd := '1';
      end if;
    end loop;

    -- Get which CPUs and resources have been allocated by any session
    vresall := (others => '0');
    vcpuall := (others => '0');
    for i in 0 to NSESS-1 loop
      if r.sess(i).claimed='1' then
        vresall := vresall or r.sess(i).claimres;
        vcpuall := vcpuall or r.sess(i).claimcpu;
      end if;
    end loop;
    -- Assign unallocated CPUs to unclaimed sessions so that the next
    -- session claimed gets all free resources.
    for i in 0 to NSESS-1 loop
      if r.sess(i).claimed='0' then
        v.sess(i).claimres := not vresall;
        v.sess(i).claimcpu := not vcpuall;
      end if;
    end loop;

    ---------------------------------------------------------------------------
    --Itrace Buffer
    ---------------------------------------------------------------------------

    --this is overwritten by dsu_reg_access
    for i in 0 to NCPU-1 loop
      v.it(i).trace_upd   := '0';
    end loop;
    
    --by default lane0 (old instruction resides on 383 downto 192)

    for i in 0 to NCPU-1 loop
      vit_pointer(i) := std_logic_vector(unsigned('0'&r.it(i).pointer)+1);
      vit_pointer_inc(i) := std_logic_vector(unsigned('0'&r.it(i).pointer)+2);
      oit_di(i).enable := "00";
      oit_di(i).write  := "00";
      oit_di(i).addr0  := (others=>'0');
      oit_di(i).addr1  := (others=>'0');
    end loop;

    for i in 0 to NCPU-1 loop
      v.it(i).sample0 := tpi(i).tdata;
      if r.it(i).set_pointer_inc = '1' then
        v.it(i).pointer_inc :=  vit_pointer(i)(log2(itentr)-1+log2(NCPU) downto 0);
        v.it(i).set_pointer_inc := '0';
      end if;

      if r.it(i).buf_read = '1' and r.it(i).buf_read2 = '0' and r.it(i).buf_ready = '0' then
        v.it(i).buf_read2 := '1';
        oit_di(i).enable := "11";
        oit_di(i).write  := "00";
        oit_di(i).addr0(log2(itentr/2)-1 downto 0) := r.it(i).buf_read_addr(log2(itentr)-1+5 downto 6);
        oit_di(i).addr1(log2(itentr/2)-1 downto 0) := r.it(i).buf_read_addr(log2(itentr)-1+5 downto 6);
      end if;

      if r.it(i).buf_read2 = '1' then
        for j in 0 to 11 loop
          if j = to_integer(unsigned(r.it(i).buf_read_addr(5 downto 2))) then
            v.it(i).buf_rdata := it_do(i).data((j+1)*32-1 downto j*32);
          end if;
        end loop;
        v.it(i).buf_read2 := '0';
        v.it(i).buf_ready := '1';
      end if;

      if r.it(i).buf_ready = '1' then
        v.it(i).buf_ready := '0';
        v.it(i).buf_read := '0';
      end if;

    end loop;

    for i in 0 to NCPU-1 loop
      if r.it(i).enable = '1' then
        if r.it(i).valid = "01" or r.it(i).valid = "10" then
          v.it(i).pointer := vit_pointer(i)(log2(itentr)-1+log2(NCPU) downto 0);
          v.it(i).pointer_inc := vit_pointer_inc(i)(log2(itentr)-1+log2(NCPU) downto 0);
        elsif r.it(i).valid = "11" then
          vit_pointer(i) := std_logic_vector(unsigned('0'&r.it(i).pointer)+2);
          vit_pointer_inc(i) := std_logic_vector(unsigned('0'&r.it(i).pointer)+3);
          v.it(i).pointer := vit_pointer(i)(log2(itentr)-1+log2(NCPU) downto 0);
          v.it(i).pointer_inc := vit_pointer_inc(i)(log2(itentr)-1+log2(NCPU) downto 0);
        end if;
      end if;
    end loop;

    for i in 0 to NCPU-1 loop
        v.it(i).valid := "00";
        if r.it(i).enable = '1' then
          if r.it(i).sample0(127) = '1' and r.it(i).sample0(319) = '1' then
            if v.it(i).pointer(0) = '0' then
              v.it(i).sample1 := r.it(i).sample0;
            else
              v.it(i).sample1(191 downto 0) := r.it(i).sample0(383 downto 192);
              v.it(i).sample1(383 downto 192) := r.it(i).sample0(191 downto 0);
            end if;
            v.it(i).valid := "11";
          elsif (r.it(i).sample0(127) xor r.it(i).sample0(319)) = '1' then
            if r.it(i).sample0(127) = '1' then
              v.it(i).sample1(383 downto 192) := r.it(i).sample0(191 downto 0);
              v.it(i).sample1(191 downto 0) := r.it(i).sample0(191 downto 0);
            else
              v.it(i).sample1(191 downto 0) := r.it(i).sample0(383 downto 192);
              v.it(i).sample1(383 downto 192) := r.it(i).sample0(383 downto 192);
            end if;

            if v.it(i).pointer(0) = '0' then
              v.it(i).valid := "10";
            else
              v.it(i).valid := "01";
            end if;
          end if;
        end if;
    end loop;

    for i in 0 to NCPU-1 loop
      if r.it(i).valid = "01" or r.it(i).valid = "10" then
        oit_di(i).addr0(log2(itentr/2)-1 downto 0) := r.it(i).pointer(log2(itentr)-1 downto 1);
        oit_di(i).addr1(log2(itentr/2)-1 downto 0) := r.it(i).pointer(log2(itentr)-1 downto 1);
        if r.it(i).pointer(0) = '0' then
          oit_di(i).enable(0) := '1';
          oit_di(i).write(0) := '1';
        else
          oit_di(i).enable(1) := '1';
          oit_di(i).write(1) := '1';
        end if;
      elsif r.it(i).valid = "11" then
        oit_di(i).addr0(log2(itentr/2)-1 downto 0) := r.it(i).pointer(log2(itentr)-1 downto 1);
        oit_di(i).addr1(log2(itentr/2)-1 downto 0) := r.it(i).pointer(log2(itentr)-1 downto 1);
        oit_di(i).enable := "11";
        oit_di(i).write := "11";
        if r.it(i).pointer(0) = '1' then
          oit_di(i).addr0(log2(itentr/2)-1 downto 0) := r.it(i).pointer_inc(log2(itentr)-1 downto 1);
        end if;
      end if;
      oit_di(i).data0 := r.it(i).sample1(383 downto 192);
      oit_di(i).data1 := r.it(i).sample1(191 downto 0);
    end loop;

    ---------------------------------------------------------------------------
    -- AHB trace buffer pipeline
    ---------------------------------------------------------------------------

    -- Stage 3 - act if watchpoint hit
    -- TODO
    -- Stage 2 - write into TB, evaluate watchpoint conditions
    otbi.addr(TBUFABITS-1 downto 0) := r.tr.aindex;
    otbi.data(127) := '0'; -- orv(bphit) or orv(wphit);
    otbi.data(96+ittbits-1 downto 96) := r.dsu.timer(ittbits-1 downto 0);
    otbi.data(94 downto 80) := (others => '0'); --ahbmipl.hirq(15 downto 1);
    otbi.data(79) := r.tr.s2hwrite;
    otbi.data(78 downto 77) := r.tr.s2htrans;
    otbi.data(76 downto 74) := r.tr.s2hsize;
    otbi.data(73 downto 71) := r.tr.s2hburst;
    otbi.data(70 downto 67) := r.tr.s2hmaster;
    otbi.data(66) := r.tr.s2hmastlock;
    otbi.data(65 downto 64) := r.tr.s2hresp;
    otbi.data(63 downto 32) := r.tr.s2data(31 downto 0);
    for x in 1 to 3 loop
      otbi.data(x*32+127 downto x*32+96) := r.tr.s2data((x*32 mod busw)+31 downto (x*32 mod busw));
    end loop;
    otbi.data(31 downto 0) := r.tr.s2haddr;
    if r.tr.s2htrans /= "00" then
      otbi.enable := '1';
      otbi.write := "11111111";
      v.tr.aindex := add(r.tr.aindex, 1);
    end if;
    -- Stage 1 - sample AHB access data phase
    v.tr.s2htrans := "00"; -- htrans used as "valid bit" in stage 2
    if cpusi.hready='1' then
      v.tr.s2htrans := r.tr.s1htrans;
    end if;
    v.tr.s2haddr := r.tr.s1haddr;
    v.tr.s2hwrite := r.tr.s1hwrite;
    v.tr.s2hsize :=  r.tr.s1hsize;
    v.tr.s2hburst := r.tr.s1hburst;
    v.tr.s2hmaster := r.tr.s1hmaster;
    v.tr.s2hmastlock := r.tr.s1hmastlock;
    v.tr.s2hresp := cpumi.hresp;
    if r.tr.s1hwrite='1' then
      v.tr.s2data := cpusi.hwdata(busw-1 downto 0);
    else
      v.tr.s2data := cpumi.hrdata(busw-1 downto 0);
    end if;
    -- Stage 0 - sample AHB access address phase
    if cpusi.hready='1' then
      v.tr.s1haddr := cpusi.haddr;
      v.tr.s1hwrite := cpusi.hwrite;
      v.tr.s1htrans := cpusi.htrans;
      v.tr.s1hsize := cpusi.hsize;
      v.tr.s1hburst := cpusi.hburst;
      v.tr.s1hmaster := cpusi.hmaster;
      v.tr.s1hmastlock := cpusi.hmastlock;
    end if;

    ---------------------------------------------------------------------------
    -- Console UART redirection
    ---------------------------------------------------------------------------
    ouartoe := uartoi;
    ouartii := uartie;

    if r.uart.outblock='1' then
      ouartoe.txd := '1';
      ouartii.ctsn := '0';
    end if;
    if r.uart.inblock='1' then
      ouartii.rxd := '1';
      ouartoe.rtsn := '0';
    end if;

    if r.uart.outflow='1' and (r.uart.captfull='1' or r.uart.captwp /= r.uart.captrp) then
      ouartii.ctsn := '1';
    end if;

    if uartoi.rtsn='0' or r.uart.inflow='0' then
      ouartii.rxd := ouartii.rxd and r.uart.insreg(0);
      if uartoi.rxtick='1' then
        if r.uart.insreg(9 downto 1)="000000000" then
          v.uart.insreg := (others => '1');
        else
          v.uart.insreg := '0' & r.uart.insreg(9 downto 1);
        end if;
      end if;
    end if;

    if r.uart.captsreg(0)='0' and r.uart.captsreg(9)='1' then
      v.uart.captsreg := (others => '1');
      if r.uart.captfull='0' then
        v.uart.captb(to_integer(r.uart.captwp)) := r.uart.captsreg(8 downto 1);
        v.uart.captwp := r.uart.captwp + 1;
        if v.uart.captwp=r.uart.captrp then
          -- Note: read code executed later in process may clear this on the
          -- same cycle
          v.uart.captfull := '1';
        end if;
      else
        v.uart.captoverrun := '1';
      end if;
    end if;
    if uartoi.txtick='1' then
      v.uart.captsreg := uartoi.txd & r.uart.captsreg(9 downto 1);
    end if;

    --------------------------------------------------------------------------
    -- Watchdog / Timer handling
    --------------------------------------------------------------------------

    otstop := '0';
    if dsuen='1' then
      otstop := r.tstop;
    end if;
    v.tstop := '1';
    for x in 0 to NCPU-1 loop
      if r.dsu.tstopcfg(x)='1' and dbgo(x).cpustate/=CPUSTATE_STOPPED then
        v.tstop := '0';
      end if;
    end loop;

    ---------------------------------------------------------------------------
    -- Main debug module FSM
    ---------------------------------------------------------------------------
    rawindex := conv_integer(r.mst_haddr(PROC_H downto PROC_L));
    if ncpu = 1 then index := 0; else
      if rawindex > ncpu then index := ncpu-1; else index := rawindex; end if;
    end if;
    hasel1 := r.mst_haddr(AREA_H downto AREA_L);
    hasel2 := r.mst_haddr(8 downto 2);
    hasel3 := r.mst_haddr(4 downto 2);

    itbuf_read := (others => '0');

    v.cpurstn := (others => '1');

    case r.s is

      when dmrstwait =>
        if r.ctr(3)='1' then
          v.cpurstn := (others => '0');
        end if;
        v.mst_hbusreq := '0';
        v.ctr := sub(r.ctr, 1);
        for i in 0 to NCPU-1 loop
          v.dsu.prevstate(2*i+1 downto 2*i) := CPUSTATE_STOPPED;
        end loop;
        if bretryen /= 0 then
          if r.ctr(3 downto 1)="001" then
            v.dsu.pushpc(0) := '1';
            v.dsu.pcin(31 downto 3) := bretin.addrlist(to_integer(unsigned(br.curent)))(31 downto 3);
            v.dsu.pcin(2) := not r.ctr(0);
          end if;
        end if;
        if r.ctr(3 downto 0)="0000" then
          v.s := dmidle;
          if dsubreak='0' then
            v.dsu.dbg_cmd(0) := CPUCMD_START;
          end if;
        end if;

      when dmidle =>
        v.ctr := (others => '1');
        v.mst_hbusreq := '0';
        v.mst_hsize := "010";
        v.mst_htrans := "00";
        v.dsu_htrans1 := '0';
        -- Handle requests from debug masters
        -- TODO round robin arbitration
        vfound := '0';
        for m in 0 to ndbgmst-1 loop
          if r.dbgmst(m).hready='0' then
            v.selmst := to_unsigned(m,v.selmst'length);
            vfound := '1';
          end if;
        end loop;
        if vfound='1' and dsuen='1' then
          if maskmatch(r.dbgmst(to_integer(v.selmst)).haddr(31 downto 20), dsuhaddr, dsuhmask)='1' then
            v.s := dmdsu1;
            v.dsu_htrans1 := '1';
          else
            v.s := dmsingle;
            v.mst_hbusreq := '1';
            v.mst_htrans := "10";
          end if;
        end if;
        if dsuen='0' then
          vfound := '0';
          v.hdata := x"DEAD1234";      -- simplify debugging
          for x in 0 to ndbgmst-1 loop
            v.dbgmst(x).hready := '1';
          end loop;
        end if;
        if notx(std_logic_vector(v.selmst)) then
          v.mst_hsize := r.dbgmst(to_integer(v.selmst)).hsize;
          v.mst_hwrite := r.dbgmst(to_integer(v.selmst)).hwrite;
          v.mst_haddr := r.dbgmst(to_integer(v.selmst)).haddr;
        else
          setx(v.mst_hsize);
          setx(v.mst_hwrite);
          setx(v.mst_haddr);
        end if;
        for x in 0 to ndbgmst-1 loop
          if std_logic_vector(v.selmst)=std_logic_vector(to_unsigned(x,v.selmst'length)) then
            v.hdata := ahbreadword(dbgmo(x).hwdata, r.dbgmst(x).haddr(4 downto 2));
            if r.dbgmst(x).hready='0' and r.dbgmst(x).hwrite='1' then
              v.dbgmst(x).hready := '1';
            end if;
          end if;
        end loop;
        -- TODO perform bursts properly rather than forward as single accesses
        -- v.mst_hburst0 := r.dbgmst(to_integer(v.selmst)).hburst0;

        -- Handle reboot requests from CPU-to-CPU interface
        vfound2 := '0';
        v.selboot := (others => '0');
        for i in 0 to ncpu-1 loop
          -- Note: look at v.cancel to avoid single-cycle race with cancellation
          if r.bootreq(i).maystart='1' and v.bootreq(i).bcancel='0' then
            vfound2 := '1';
            v.selboot := to_unsigned(i,log2x(ncpu));
          end if;
        end  loop;
        v.selbootcpu := r.bootreq(to_integer(v.selboot)).bcpu;
        if vfound2='1' and vfound='0' then
          v.s := dmbootreq1;
          v.bootreq(to_integer(v.selboot)).ben := '0';
          v.bootreq(to_integer(v.selboot)).bact := '1';
        end if;

      when dmsingle =>
        if r.mst_inacc='1' and cpumi.hready='1' then
          v.s := dmidle;
          if r.mst_hwrite='0' then
            v.dbgmst(to_integer(r.selmst)).hready := '1';
          end if;
        elsif r.mst_inacc='1' and cpumi.hready='0' and cpumi.hresp(1)='1' then
          v.mst_inacc := '0';
        elsif r.mst_inacc='1' then
          null; -- wait for hready=1
        elsif cpumi.hready='1' and r.mst_htrans(1)='1' and r.mst_granted='1' then
          v.mst_htrans := "00";
          -- v.mst_inacc:='1'; alredy set by general AHB logic
        else
          v.mst_htrans := "10";
        end if;
        v.mst_hbusreq := v.mst_htrans(1);

      when dmdsu1 =>

        v.ctr := sub(r.ctr, 1);

        hrdata := (others => '0');

        case hasel1 is

          when "000" =>  -- DSU registers
            dsu_reg_access(hasel2,index,index,r.mst_hwrite,hwdata,hrdata);
            v.s := dmdsu2;
            -- Rebuild effective permissions matrix after any write as control
            -- may have changed.
            if r.mst_hwrite='1' then
              veffclr := '1';
            end if;

          when "010"  =>  -- AHB tbuf
            if busw=32 then
              otbi.addr := r.mst_haddr(otbi.addr'length+3 downto 4);
            else
              otbi.addr := r.mst_haddr(otbi.addr'length+4 downto 5);
            end if;
            for x in 0 to otbi.data'length/32-1 loop
              otbi.data(x*32+31 downto x*32) := hwdata;
            end loop;
            if r.ctr(0)='0' then v.s := dmdsu2; end if;
            if TRACEN then
              if r.ctr(0)='1' then otbi.enable := '1'; end if;
              case hasel3 is --case r.tr.haddr(4 downto 2) is
                when "000" =>
                  hrdata := tbo.data(127 downto 96);
                  if r.mst_hwrite='1' and r.ctr(0)='1' then
                    otbi.write(3) := '1';
                  end if;
                when "001" =>
                  hrdata := tbo.data(95 downto 64);
                  if r.mst_hwrite='1' and r.ctr(0)='1' then
                    otbi.write(2) := '1';
                  end if;
                when "010" =>
                  hrdata := tbo.data(63 downto 32);
                  if r.mst_hwrite='1' and r.ctr(0)='1' then
                    otbi.write(1) := '1';
                  end if;
                when "011" =>
                  hrdata := tbo.data(31 downto 0);
                  if r.mst_hwrite='1' and r.ctr(0)='1' then
                    otbi.write(0) := '1';
                  end if;
                when "100" =>
                  if busw > 32 then
                    hrdata := tbo.data(159 downto 128);
                    if r.mst_hwrite='1' and r.ctr(0)='1' then
                      otbi.write(7) := '1';
                    end if;
                  else
                    hrdata := tbo.data(127 downto 96);
                    if r.mst_hwrite='1' and r.ctr(0)='1' then
                      otbi.write(3) := '1';
                    end if;
                  end if;
                when "101" =>
                  if busw > 32 then
                    if busw > 64 then
                      hrdata := tbo.data(223 downto 192);
                      if r.mst_hwrite='1' and r.ctr(0)='1' then
                        otbi.write(6) := '1';
                      end if;
                    else hrdata := zero32; end if;
                  else
                    hrdata := tbo.data(95 downto 64);
                    if r.mst_hwrite='1' and r.ctr(0)='1' then
                      otbi.write(2) := '1';
                    end if;
                  end if;
                when "110" =>
                  if busw > 32 then
                    if busw > 64 then
                      hrdata := tbo.data(191 downto 160);
                      if r.mst_hwrite='1' and r.ctr(0)='1' then
                        otbi.write(5) := '1';
                      end if;
                    else hrdata := zero32; end if;
                  else
                    hrdata := tbo.data(63 downto 32);
                    if r.mst_hwrite='1' and r.ctr(0)='1' then
                      otbi.write(1) := '1';
                    end if;
                  end if;
                when others =>
                  if busw > 32 then
                    hrdata := zero32;
                  else
                    hrdata := tbo.data(31 downto 0);
                    if r.mst_hwrite='1' and r.ctr(0)='1' then
                      otbi.write(0) := '1';
                    end if;
                  end if;
              end case;
            end if;

          when "001" =>                   --IU tbuf
            if r.ctr= (r.ctr'range => '1') then
              v.it(index).buf_read := '1';
              if r.it(index).buf_read = '0' then
                v.it(index).buf_read_addr := r.mst_haddr(log2(itentr)-1+5 downto 2)&"00";
              end if;
            end if;
            hrdata := r.it(index).buf_rdata;
            if r.it(index).buf_ready = '1' then
              v.s := dmdsu2;
            end if;

          when "011" | "100" | "110" | "101" | "111" =>  -- IU reg file,
            odbgi(index).mosi.accen := '1';
            hrdata := dbgo(index).miso.rddata;
            if dbgo(index).miso.accrdy='1' then
              v.s := dmdsu2;
            end if;
          when others =>
            v.s := dmdsu2;
        end case;

        if r.mst_hwrite='0' then
          v.hdata := hrdata;
        end if;

      when dmdsu2 =>
        vsessbusy := '0';
        for i in 0 to NSESS-1 loop
          if r.sess(i).docmd='1' then vsessbusy:='1'; end if;
        end loop;
        if vsessbusy='0' and dbgo(index).miso.accrdy='0' then
          if r.mst_hwrite='0' then
            v.dbgmst(to_integer(r.selmst)).hready := '1';
          end if;
          v.s := dmidle;
        end if;

      when dmbootreq1 =>
        v.ctr := sub(r.ctr, 1);
        -- Force selected CPU into stopped state and wait until stopped+idle
        v.dsu.cpu_cmd(to_integer(r.selbootcpu)) := CPUCMD_FORCESTOP;
        for b in 0 to 1 loop
          vregbits := (others => '0');
          for c in 0 to NCPU-1 loop
            vregbits(c) := r.dsu.plstate(2*c+b);
          end loop;
          vstate(b) := vregbits(to_integer(r.selbootcpu));
        end loop;
        if vstate="00" then
          v.dsu.cpu_cmd(to_integer(r.selbootcpu)) := CPUCMD_NONE;
          if r.dsu.plidle(to_integer(r.selbootcpu))='1' then
            v.s := dmbootreq2;
            v.ctr := (others => '1');
          end if;
        end if;

      when dmbootreq2 =>
        v.ctr := sub(r.ctr, 1);
        v.dsu.cpu_cmd(to_integer(r.selbootcpu)) := CPUCMD_NONE;
        -- Reset selected CPU
        if r.ctr(3)='1' then
          v.cpurstn(to_integer(r.selbootcpu)) := '0';
        end if;
        if r.ctr(3 downto 0)="0000" then
          v.s := dmbootreq3;
          v.ctr := (others => '1');
        end if;

      when dmbootreq3 =>
        v.ctr := sub(r.ctr, 1);
        v.dsu.cpu_cmd(to_integer(r.selbootcpu)) := CPUCMD_NONE;
        v.dsu.pcin(31 downto 3) := r.bootreq(to_integer(r.selboot)).baddr;
        v.dsu.pcin(2) := not r.ctr(0);
        -- ctr=11: Push PC
        -- ctr=10: Push nPC
        -- ctr=01: Start CPU, return
        v.dsu.pushpc := (others => '0');  -- Prevent interference from legacy i/f
        if r.ctr(1)='1' then
          v.dsu.pushpc(to_integer(r.selbootcpu)) := '1';
        else
          v.dsu.cpu_cmd(to_integer(r.selbootcpu)) := CPUCMD_START;
          v.bootreq(to_integer(r.selboot)).bact := '0';
          v.bootreq(to_integer(r.selboot)).bdone := '1';
          v.s := dmidle;
        end if;
    end case;

    -- Deadlock detect
    if r.ctr = (r.ctr'range => '0') then
      v.s := dmidle;
      for x in 0 to ndbgmst-1 loop
        v.dbgmst(x).hready := '1';
      end loop;
      v.deadlock_hit := '1';
      if r.deadlock_hit='0' then
        v.deadlock_addr := r.mst_haddr;
        v.deadlock_hwrite := r.mst_hwrite;
        v.deadlock_cpustate := r.dsu.plstate;
      else
        v.deadlock_multi := '1';
      end if;
    end if;

    -- Check if any state changes occured on the CPUs claimed by the session
    -- Note this must be done after the potential clear by the register read-out
    -- in order to avoid single-cycle window where event is lost.
    for i in 0 to NSESS-1 loop
      for c in 0 to NCPU-1 loop
        if r.dsu.statechg(c)='1' and r.sess(i).claimcpu(c)='1' then
          for s in 0 to 3 loop
            if r.dsu.plstate(2*c+1 downto 2*c)=std_logic_vector(to_unsigned(s,2)) then
              v.sess(i).statechg(s) := '1';
            end if;
          end loop;
        end if;
      end loop;
    end loop;

    -- Manage effctl_clr set by C2C interface or DSU register write
    v.dsu.effctl_clr := '0';
    if veffclr='1' then
      v.dsu.effctl_clr := '1';
      v.dsu.effctl_allstab := '0';
    end if;

    --instruction trace filtering outputs
    for i in 0 to NCPU-1 loop
      otco(i).trace_upd   := r.it(i).trace_upd;
      otco(i).addr_f      := r.it(i).addr_f;
      otco(i).addr_f_p    := r.it(i).addr_f_p;
      otco(i).inst_filter := r.it(i).inst_filter;
    end loop;

    ---------------------------------------------------------------------------
    -- Reset
    ---------------------------------------------------------------------------
    if ( GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 and
         GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all)=0 ) then
      if rstn='0' then
        v.cpurstn          := RRES.cpurstn;
        v.s                := RRES.s;
        v.ctr              := RRES.ctr;
        for m in 0 to ndbgmst-1 loop
          v.dbgmst(m).hready      := RRES.dbgmst(m).hready;
        end loop;
        v.dsu_htrans1      := RRES.dsu_htrans1;
        v.mst_htrans       := RRES.mst_htrans;
        v.dsu.bw           := RRES.dsu.bw;
        v.dsu.be           := RRES.dsu.be;
        v.dsu.bx           := RRES.dsu.bx;
        v.dsu.bz           := RRES.dsu.bz;
        v.dsu.bs           := RRES.dsu.bs;
        v.dsu.te           := RRES.dsu.te;
        v.dsu.dbg_cmd      := RRES.dsu.dbg_cmd;
        v.dsu.usr_wakeup   := RRES.dsu.usr_wakeup;
        v.dsu.usr_break    := RRES.dsu.usr_break;
        v.dsu.usr_start    := RRES.dsu.usr_start;
        v.dsu.boot_word    := RRES.dsu.boot_word;
        v.dsu.blockusr     := RRES.dsu.blockusr;
        v.dsu.brkmat       := RRES.dsu.brkmat;
        v.dsu.ctlmat       := RRES.dsu.ctlmat;
        v.dsu.delegmat     := RRES.dsu.delegmat;
        v.dsu.effctl_clr   := RRES.dsu.effctl_clr;
        v.dsu.tstopcfg     := RRES.dsu.tstopcfg;
        v.dsu.timer        := RRES.dsu.timer;
        for x in 0 to NSESS-1 loop
          v.sess(x).claimed       := RRES.sess(x).claimed;
          v.sess(x).pending       := RRES.sess(x).pending;
          v.sess(x).statechg      := RRES.sess(x).statechg;
          v.sess(x).docmd         := RRES.sess(x).docmd;
        end loop;
        for x in 0 to NCPU-1 loop
          v.bootreq(x).ben        := RRES.bootreq(x).ben;
          v.bootreq(x).bact       := RRES.bootreq(x).bact;
          v.bootreq(x).bdone      := RRES.bootreq(x).bdone;
          v.bootreq(x).bfail      := RRES.bootreq(x).bfail;
          v.bootreq(x).bcancel    := RRES.bootreq(x).bcancel;
        end loop;
        v.nolegacy         := RRES.nolegacy;
        v.smpgroup         := RRES.smpgroup;
        for x in 0 to NCPU-1 loop
          v.smp(x).ipien          := RRES.smp(x).ipien;
          v.smp(x).ipiirq         := RRES.smp(x).ipiirq;
          v.smp(x).tlbfen         := RRES.smp(x).tlbfen;
          v.smp(x).tlbfin         := RRES.smp(x).tlbfin;
          v.smp(x).icfen          := RRES.smp(x).icfen;
          v.smp(x).icfin          := RRES.smp(x).icfin;
        end loop;
        v.tr.ahbactive     := RRES.tr.ahbactive;
        v.tr.enable        := RRES.tr.enable;
        v.tr.tforce        := RRES.tr.tforce;
        v.tr.timeren       := RRES.tr.timeren;
        v.tr.dcnten        := RRES.tr.dcnten;
        v.tr.edbgmtf       := RRES.tr.edbgmtf;
        v.tr.aindex        := RRES.tr.aindex;
        for i in r.tr.tbreg'range loop
          v.tr.tbreg(i).read      := RRES.tr.tbreg(i).read;
          v.tr.tbreg(i).write     := RRES.tr.tbreg(i).write;
        end loop;
        v.tr.bphit         := RRES.tr.bphit;
        if AHBWATCH then
          for i in r.twr.reg'range loop
            v.twr.reg(i).en       := RRES.twr.reg(i).en;
            v.twr.reg(i).couple   := RRES.twr.reg(i).couple;
            v.twr.reg(i).inv      := RRES.twr.reg(i).inv;
          end loop;
        end if;
        for i in 0 to NCPU-1 loop
          v.it(i).trace_upd       := RRES.it(i).trace_upd;
          v.it(i).valid           := RRES.it(i).valid;
          v.it(i).pointer         := RRES.it(i).pointer;
          v.it(i).pointer_inc     := RRES.it(i).pointer_inc;
          v.it(i).buf_read        := RRES.it(i).buf_read;
          v.it(i).buf_read2       := RRES.it(i).buf_read2;
          v.it(i).buf_ready       := RRES.it(i).buf_ready;
          v.it(i).set_pointer_inc := RRES.it(i).set_pointer_inc;
          v.it(i).enable          := dsuen;
          v.it(i).addr_f          := RRES.it(i).addr_f;
          v.it(i).addr_f_p        := RRES.it(i).addr_f_p;
          v.it(i).inst_filter     := RRES.it(i).inst_filter;
        end loop;
        v.uart.captwp      := RRES.uart.captwp;
        v.uart.captrp      := RRES.uart.captrp;
        v.uart.captfull    := RRES.uart.captfull;
        v.uart.captoverrun := RRES.uart.captoverrun;
        v.uart.captsreg    := RRES.uart.captsreg;
        v.uart.insreg      := RRES.uart.insreg;
        v.uart.inoverrun   := RRES.uart.inoverrun;
        v.uart.outblock    := RRES.uart.outblock;
        v.uart.outflow     := RRES.uart.outflow;
        v.uart.inblock     := RRES.uart.inblock;
        v.uart.inflow      := RRES.uart.inflow;
        v.deadlock_hit     := RRES.deadlock_hit;
        v.deadlock_multi   := RRES.deadlock_multi;
      end if;
    end if;
    -- Constant registers
    for i in 0 to NCPU-1 loop
      v.dsu.ctlmat(i)(i) := '0';
    end loop;
    if ncpu < 2 then
      v.selboot := (others => '0');
    end if;
    if nsess < 2 then
      v.selsess := (others => '0');
    end if;
    -- Zero out unused parts of session buffers
    vsessmask := (others => '0');
    vsessmask(2*NCPU-1 downto 0) := (others => '1');
    vsessmask(128+NCPU-1 downto 128) := (others => '1');
    for b in 0 to 1 loop
      vsessmask(16*b+5 downto 16*b) := (others => '1');
      vsessmask(32+NCPU*2-1 downto 32) := (others => '1');
    end loop;
    for i in 0 to NSESS-1 loop
      v.sess(i).dbuf := v.sess(i).dbuf and vsessmask;
    end loop;
    -- Replicated registers
    for i in 0 to NCPU-1 loop
      v.dsu.timerrep(i) := v.dsu.timer;
    end loop;

    nr <= v;
    cpurstn <= r.cpurstn;
    dbgmi <= odbgmi;
    cpumo <= ocpumo;
    dbgi <= odbgi;
    dtoi <= odtoi;
    tbi <= otbi;
    tco <= otco;
    it_di <= oit_di;
    maskerrn <= r.dsu.be;
    uartoe <= ouartoe;
    uartii <= ouartii;
    tstop <= otstop;
    dbgtime <= r.dsu.timer;
    rstreqn <= r.rstreqn;
    bretout <= (curent => br.curent, bootctr => br.bootctr);
  end process;

  srstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 generate
    regs: process(clk)
    begin
      if rising_edge(clk) then
        r <= nr;
        if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rstn='0' then
          r <= RRES;
          for i in 0 to NCPU-1 loop
            r.it(i).enable <= dsuen;
          end loop;
        end if;
      end if;
      if ncpu < 2 then
        r.selboot <= (others => '0');
      end if;
      if nsess < 2 then
        r.selsess <= (others => '0');
      end if;
    end process;
  end generate srstregs;

  arstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)/=0 generate
    regs: process(clk,rstn)
    begin
      if rstn='0' then
        r <= RRES;
        for i in 0 to NCPU-1 loop
          r.it(i).enable <= dsuen;
        end loop;
      elsif rising_edge(clk) then
        r <= nr;
      end if;
      if ncpu < 2 then
        r.selboot <= (others => '0');
      end if;
      if nsess < 2 then
        r.selsess <= (others => '0');
      end if;
    end process;
  end generate arstregs;

  tb0 : if TRACEN generate
    atmem0 : tbufmem5 generic map (tech => memtech, tbuf => kbytes, dwidth => busw, proc => 0, testen => scantest)
      port map (clk, tbi, tbo, cpusi.testin
                );
-- pragma translate_off
    bootmsg : report_version
    generic map ("dsu5_" & tost(0) &
    ": LEON5 Debug support unit + AHB Trace Buffer, " & tost(kbytes) & " kbytes");
-- pragma translate_on
  end generate;

  itb0 : if ITRACEN generate
    mcpu:for i in 0 to NCPU-1 generate
      itmem0 : itbufmem5
        generic map( tech => memtech,
                     entry => itentr,
                     testen => scantest)
        port map(clk => clk,
                 di => it_di(i),
                 do => it_do(i),
                 testin => cpusi.testin
                 );
    end generate;
  end generate;

  bret0: if bretryen /= 0 generate
    -- For rstn we first use a async-fall, sync-rise
    -- reset synchronizer as a "pulse strecher" to guarantee
    -- that the reset pulse is long enough to capture, then
    -- we synchronize it over into the bretclk domain
    psrstnproc: process(bretclk,rstn)
    begin
      if rstn='0' then
        psrstn <= "000";
      elsif rising_edge(bretclk) then
        psrstn <= psrstn(1 downto 0) & '1';
      end if;
    end process;

    sreg_sysrstn: syncreg
      generic map (tech => fabtech, stages => 3)
      port map (clk => bretclk, d => psrstn(2), q => rstn_sync);

    bretcomb: process(br,bretrstn,rstn_sync,bretin)
      variable bv: bret_reg_type;
      variable vnextent, vent: std_logic_vector(2 downto 0);
    begin
      bv := br;
      bv.rstn_prev := rstn_sync;
      vnextent := (others => '0');
      for x in 0 to 7 loop
        vent := std_logic_vector(to_unsigned(x,3));
        for y in 7 downto 1 loop
          if bretin.addrvalid((x+y) mod 8)='1' then
            vent := std_logic_vector(to_unsigned((x+y) mod 8,3));
          end if;
        end loop;
        if br.curent=std_logic_vector(to_unsigned(x,3)) then
          vnextent := vent;
        end if;
      end loop;
      if br.rstn_prev='1' and rstn_sync='0' then
        bv.bootctr := add(br.bootctr,1);
        if br.bootctr="1111" then bv.bootctr := "1000"; end if;
        bv.curent := vnextent;
      end if;
      if ( GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 and
           GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all)=0 ) then
        if bretrstn='0' then
          bv.curent := BRRES.curent;
          bv.bootctr := BRRES.bootctr;
        end if;
      end if;
      nbr <= bv;
    end process;

    srstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 generate
      bretregs: process(bretclk)
      begin
        if rising_edge(bretclk) then
          br <= nbr;
          if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and bretrstn='0' then
            br <= BRRES;
          end if;
        end if;
      end process;
    end generate;

    arstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)/=0 generate
      bretregs: process(bretclk,bretrstn)
      begin
        if bretrstn='0' then
          br <= BRRES;
        elsif rising_edge(bretclk) then
          br <= nbr;
        end if;
      end process;
    end generate;
  end generate;

  nobret: if bretryen=0 generate
    psrstn <= "000";
    rstn_sync <= '0';
    br <= BRRES;
    nbr <= BRRES;
  end generate;

end;
