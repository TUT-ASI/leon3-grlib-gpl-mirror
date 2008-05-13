
library ieee;
use ieee.std_logic_1164.all;
library grlib, techmap;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
use techmap.gencomp.all;
use techmap.allddr.all;
use techmap.allclkgen.all;
library gaisler;
use gaisler.memctrl.all;
--use gaisler.leon3.all;
--use gaisler.uart.all;
use gaisler.misc.all;
--use gaisler.net.all;
--use gaisler.jtag.all;
--use gaisler.spacewire.all;

use gaisler.ahbtbp.all;

--library esa;
--use esa.memoryctrl.all;
use work.config.all;


entity leon3mp is
  generic (
    fabtech   : integer := CFG_FABTECH;
    memtech   : integer := CFG_MEMTECH;
    padtech   : integer := CFG_PADTECH;
    ddrbits   : integer := 64;
    mobile    : integer := 0;
    freq      : integer := 100000
  );
  port (
    sys_rst_in	: in  std_ulogic;
    sys_clk	: in  std_ulogic; 	-- 100 MHz main clock

    ddr_clk     : out std_logic;
    ddr_clkb    : out std_logic;
    ddr_clk_fb  : in std_logic;
    ddr_cke     : out std_logic;
    ddr_csb     : out std_logic;
    ddr_web     : out std_ulogic;                       -- ddr write enable
    ddr_rasb    : out std_ulogic;                       -- ddr ras
    ddr_casb    : out std_ulogic;                       -- ddr cas
    ddr_dm      : out std_logic_vector (ddrbits/8-1 downto 0);    -- ddr dm
    ddr_dqs     : inout std_logic_vector (ddrbits/8-1 downto 0);    -- ddr dqs
    ddr_ad      : out std_logic_vector (12 downto 0);   -- ddr address
    ddr_ba      : out std_logic_vector (1 downto 0);    -- ddr bank address
    ddr_dq      : inout std_logic_vector (ddrbits-1 downto 0); -- ddr data

    sa          : out std_logic_vector(14 downto 0);
    sd          : inout std_logic_vector(63 downto 0);
    sdclk       : out std_ulogic;
    sdcke       : out std_logic_vector (1 downto 0);    -- sdram clock enable
    sdcsn       : out std_logic_vector (1 downto 0);    -- sdram chip select
    sdwen       : out std_ulogic;                       -- sdram write enable
    sdrasn      : out std_ulogic;                       -- sdram ras
    sdcasn      : out std_ulogic;                       -- sdram cas
    sddqm       : out std_logic_vector (7 downto 0)     -- sdram dqm
   );
end;

architecture rtl of leon3mp is

constant maxahbm : integer := 1;

signal vcc, gnd   : std_logic_vector(4 downto 0);
signal sdi   : sdctrl_in_type;
signal sdo2  : sdctrl_out_type;
signal ddr_sdi     : sdctrl_in_type;
signal ddr_sdo     : sdctrl_out_type;

signal apbi  : apb_slv_in_type;
signal apbo  : apb_slv_out_vector := (others => apb_none);
signal ahbsi : ahb_slv_in_type;
signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
signal ahbmi : ahb_mst_in_type;
signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);

signal clkm, rstn, rstraw, srclkl : std_ulogic;

signal cgi   : clkgen_in_type;
signal cgo   : clkgen_out_type;
signal clklock, lock, lclk, clkml, rst, ndsuact : std_ulogic;
signal ddrclk, ddrrst : std_ulogic;

constant BOARD_FREQ : integer := freq; --125000;   -- input frequency in KHz
constant CPU_FREQ : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;  -- cpu frequency in KHz
constant IOAEN : integer := CFG_DDRSP;

signal ddrclkfb, ssrclkfb, ddr_clkl, ddr_clk90l, ddr_clknl, ddr_clk270l : std_ulogic;
signal ddr_clkv 	: std_logic_vector(2 downto 0);
signal ddr_clkbv	: std_logic_vector(2 downto 0);
signal ddr_ckev  	: std_logic_vector(1 downto 0);
signal ddr_csbv  	: std_logic_vector(1 downto 0);
signal ddr_adl      	: std_logic_vector (13 downto 0);

attribute syn_keep : boolean;
attribute syn_preserve : boolean;
attribute syn_keep of clkml : signal is true;
attribute syn_preserve of clkml : signal is true;
attribute keep : boolean;
attribute keep of lock : signal is true;
attribute keep of clkml : signal is true;
attribute keep of clkm : signal is true;

--pragma translate_off
signal ctrl     : ahbtb_ctrl_type;
--pragma translate_on

begin

----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------
  
  vcc <= (others => '1'); gnd <= (others => '0');
  cgi.pllctrl <= "00"; cgi.pllrst <= rstraw; cgi.pllref <= srclkl;

  clk_pad : clkpad generic map (tech => padtech, arch => 2) 
	port map (sys_clk, lclk); 

  sdclk_pad : outpad generic map (tech => padtech, slew => 1, strength => 24) 
	port map (sdclk, srclkl);

  clkgen0 : clkgen  		-- system clock generator
    generic map (CFG_FABTECH, CFG_CLKMUL, CFG_CLKDIV, 1, 0, 0, 0, 0, BOARD_FREQ, 0)
    port map (lclk, gnd(0), clkm, open, open, srclkl, open, cgi, cgo, open, open);

  resetn_pad : inpad generic map (tech => padtech) port map (sys_rst_in, rst); 
  rst0 : rstgen			-- reset generator
  port map (rst, clkm, clklock, rstn, rstraw);
  clklock <= lock and cgo.clklock;

----------------------------------------------------------------------
---  AHB CONTROLLER --------------------------------------------------
----------------------------------------------------------------------

  ahb0 : ahbctrl 		-- AHB arbiter/multiplexer
  generic map (defmast => CFG_DEFMST, split => CFG_SPLIT, 
	rrobin => CFG_RROBIN, ioaddr => CFG_AHBIO, devid => XILINX_ML401,
	ioen => IOAEN, nahbm => maxahbm, nahbs => 8)
  port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);

----------------------------------------------------------------------
---  Memory controllers ----------------------------------------------
----------------------------------------------------------------------

  ddrsp0 : if (CFG_DDRSP /= 0) generate 

    ddrc0 : ddrspa generic map ( fabtech => CFG_FABTECH*0, memtech => memtech, 
        hindex => 0, haddr => 16#400#, hmask => 16#F00#, ioaddr => 1, rskew => 250-50*(mobile/2), 
        pwron => CFG_DDRSP_INIT, MHz => BOARD_FREQ/1000, ahbfreq => CPU_FREQ/1000,
        col => CFG_DDRSP_COL, Mbyte => CFG_DDRSP_SIZE, ddrbits => ddrbits, mobile => mobile,
        confapi => 1, conf0 => 16#0000a0a0#, conf1 => 16#00060606#, regoutput => 0)
      port map (
        rst, rstn, lclk, clkm, lock, clkml, clkml, ahbsi, ahbso(0),
        ddr_clkv, ddr_clkbv, ddrclkfb, ddr_clk_fb, ddr_ckev, ddr_csbv, 
        ddr_web, ddr_rasb, ddr_casb, ddr_dm, ddr_dqs, ddr_adl, ddr_ba, ddr_dq);
        
        ddr_ad <= ddr_adl(12 downto 0);
        ddr_clk <= ddr_clkv(0); ddr_clkb <= ddr_clkbv(0);
        ddr_cke <= ddr_ckev(0); ddr_csb <= ddr_csbv(0);
    
  end generate;

  noddr :  if (CFG_DDRSP = 0) generate lock <= '1'; end generate;

  sd1 : if CFG_SDCTRL = 1 generate
    sdc : sdctrl generic map (hindex => 3, haddr => 16#600#, hmask => 16#F00#, 
        ioaddr => 2, fast => 0, pwron => 0, invclk => CFG_SDCTRL_INVCLK, 
        sdbits => 32 + 32*CFG_SDCTRL_SD64, mobile => mobile)
      port map (rstn, clkm, ahbsi, ahbso(3), sdi, sdo2);
    sa_pad : outpadv generic map (width => 15, tech => padtech) 
      port map (sa, sdo2.address);
    sd_pad : iopadv generic map (width => 32, tech => padtech) 
      port map (sd(31 downto 0), sdo2.data(31 downto 0), sdo2.bdrive, sdi.data(31 downto 0));
    sd2 : if CFG_SDCTRL_SD64 = 1 generate
      sd_pad2 : iopadv generic map (width => 32) 
         port map (sd(63 downto 32), sdo2.data(63 downto 32), sdo2.bdrive, sdi.data(63 downto 32));
    end generate;
    sdcke_pad : outpadv generic map (width =>2, tech => padtech) 
      port map (sdcke, sdo2.sdcke); 
    sdwen_pad : outpad generic map (tech => padtech) 
      port map (sdwen, sdo2.sdwen);
    sdcsn_pad : outpadv generic map (width =>2, tech => padtech) 
      port map (sdcsn, sdo2.sdcsn); 
    sdras_pad : outpad generic map (tech => padtech) 
      port map (sdrasn, sdo2.rasn);
    sdcas_pad : outpad generic map (tech => padtech) 
      port map (sdcasn, sdo2.casn);
    sddqm_pad : outpadv generic map (width =>8, tech => padtech) 
      port map (sddqm, sdo2.dqm(7 downto 0));
  end generate;

-----------------------------------------------------------------------
---  AHB DEBUG --------------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  -- AHB testbench master --
  ahbtbm0 : ahbtbm
  generic map(venid => 16#01#, devid => 16#040#, 
              hindex => 0)
  port map(rstn, clkm, ctrl.i, ctrl.o, ahbmi, 
           ahbmo(0));
  
  -- Testbench stimuli
  process
  variable F : boolean;
  variable vaddr, vdata : std_logic_vector(31 downto 0);
  variable vhtrans : std_logic_vector(1 downto 0);
  variable d : integer := 1;
  
  procedure MobileDDR(
    constant mem            : in std_logic_vector(31 downto 0);
    constant io             : in std_logic_vector(31 downto 0);
    constant ddrbits        : in integer;
    constant SelfRefresh    : in integer;
    constant PowerDown      : in integer;
    constant DeepPowerDown  : in integer;
    constant ClockStop      : in integer;
    constant StatusReadReg  : in integer;
    constant DS_TCSR_test   : in integer;
    constant CASLatencyTest : in integer;
    constant WriteOffsetTest: in integer) is
  begin
    print("**********************************************************");
    print("                    Mobile DDR");
    print("**********************************************************");
    if (SelfRefresh = 1) or (PowerDown = 1) or (DeepPowerDown = 1) or (ClockStop = 1) 
       or (StatusReadReg = 1) or (DS_TCSR_test = 1) or ( CASLatencyTest >= 2) then
      print("******  Power-Saving mode test  ******");

--      ahbread (io+ x"0000", x"D58083CF", "10", "10", '1', 1, true , ctrl); -- SRR
--      
--      ahbread (io+ x"0004", x"0001907D", "10", "10", '1', 1, true , ctrl); -- SRR
--      
--      ahbread (io+ x"0008", x"81F80000", "10", "10", '1', 1, true , ctrl); -- SRR
--      ahbwrite(io+ x"0008", x"C1F80000", "10", "10", '0', 1, true , ctrl); -- SR
--      ahbwrite(io+ x"0000", x"D59883CF", "10", "10", '0', 1, true , ctrl);
--      
--      ahbread (io+ x"0014", x"0000a0a0", "10", "10", '1', 1, true , ctrl); -- SRR
--      ahbwrite(io+ x"0014", x"0800a0a0", "10", "10", '0', 1, true , ctrl); -- SR
--      ahbread (io+ x"0014", x"0800a0a0", "10", "10", '1', 1, true , ctrl); -- SRR
--
--      ahbread (io+ x"0018", x"00060606", "10", "10", '1', 1, true , ctrl); -- SRR
--      ahbwrite(io+ x"0018", x"54060606", "10", "10", '1', 1, true , ctrl); -- SRR
--      ahbread (io+ x"0018", x"54060606", "10", "10", '1', 1, true , ctrl); -- SRR


      
      
      -- Write test data
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
    end if;

    if StatusReadReg = 1 then
      print("Read: Status Read Register");
      if ddrbits = 16 then
        ahbread (io+ x"0010", x"440f0000", "10", "10", '1', 1, true , ctrl); -- SRR
      else
        ahbread (io+ x"0010", x"440f440f", "10", "10", '1', 1, true , ctrl); -- SRR
      end if;
      ahbtbmidle(true, ctrl);
      
      -- dummy read
      ahbread (mem+x"0000", x"11223344", "10", "10", '0', 1, true , ctrl);
  
      print("Read: Status Read Register");
      if ddrbits = 16 then
        ahbread (io+ x"0010", x"440f0000", "10", "10", '1', 1, true , ctrl); -- SRR
      else
        ahbread (io+ x"0010", x"440f440f", "10", "10", '1', 1, true , ctrl); -- SRR
      end if;
      ahbtbmidle(true, ctrl);
      print("Read: Status Read Register");
      if ddrbits = 16 then
        ahbread (io+ x"0010", x"440f0000", "10", "10", '1', 1, true , ctrl); -- SRR
      else
        ahbread (io+ x"0010", x"440f440f", "10", "10", '1', 1, true , ctrl); -- SRR
      end if;
      ahbtbmidle(true, ctrl);
       
      -- dummy write (*** Simulation ERROR ***)
      --ahbwrite(mem+x"0000", x"12345678", "10", "10", '0', 1, true , ctrl);
      
      -- dummy read
      ahbread (mem+x"0000", x"11223344", "10", "10", '0', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
    end if;

    -- /SR -------------------------------------------------------------------
    if SelfRefresh = 1 then
      print("Enable: Self-Refresh(SR) mode (full array)");
      ahbwrite(io+ x"0008", x"81FA0000", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(false, ctrl); -- Write on first clock in SR mode
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      --ahbtbmidle(true, ctrl);
      --wait for 600 ns;
      
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '0', 1, true , ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      
      print("Enable: Self-Refresh(SR) mode (half array)");
      ahbwrite(io+ x"0008", x"81FA0001", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
   
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      
      print("Enable: Self-Refresh(SR) mode (One-quarter array)");
      ahbwrite(io+ x"0008", x"81FA0002", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
   
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      
      print("Enable: Self-Refresh(SR) mode (One-eighth array)");
      ahbwrite(io+ x"0008", x"81FA0005", "10", "10", '1', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
  
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      
      print("Enable: Self-Refresh(SR) mode (One-sixteenth array)");
      ahbwrite(io+ x"0008", x"81FA0006", "10", "10", '1', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
  
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      
      if StatusReadReg = 1 then
        print("Read: Status Read Register");
        if ddrbits = 16 then
          ahbread (io+ x"0010", x"440f0000", "10", "10", '1', 1, true , ctrl); -- SRR
        else
          ahbread (io+ x"0010", x"440f440f", "10", "10", '1', 1, true , ctrl); -- SRR
        end if;
        ahbtbmidle(true, ctrl);
      end if;
      
      print("Disable: Self-Refresh(SR) mode)");
      ahbwrite(io+ x"0008", x"81F80000", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
    end if;
    -- SR/ -------------------------------------------------------------------
    
    wait for 600 ns;
    
    -- /PD -------------------------------------------------------------------
    if PowerDown = 1 then
      print("Enable: Power-Down(PD) mode");
      ahbwrite(io+ x"0008", x"81F90000", "10", "10", '1', 1, true , ctrl); -- SR
      ahbtbmidle(false, ctrl); -- Read on first clock in PD mode
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      --ahbtbmidle(true, ctrl);
      --wait for 600 ns;
      
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      
      if StatusReadReg = 1 then
        print("Read: Status Read Register");
        if ddrbits = 16 then
          ahbread (io+ x"0010", x"440f0000", "10", "10", '1', 1, true , ctrl); -- SRR
        else
          ahbread (io+ x"0010", x"440f440f", "10", "10", '1', 1, true , ctrl); -- SRR
        end if;
        ahbtbmidle(true, ctrl);
      end if;
   
      wait for 600 ns;
      
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
  
      print("Disable: Power-Down(PD) mode)");
      ahbwrite(io+ x"0008", x"81F80000", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
    end if;
    -- PD/ -------------------------------------------------------------------
  
    -- /DPD ------------------------------------------------------------------
    if DeepPowerDown = 1 then
      print("Enable: Deep Power-Down(DPD) mode");
      ahbwrite(io+ x"0008", x"81FD0000", "10", "10", '1', 1, true , ctrl); -- DPD
      ahbtbmidle(false, ctrl); -- Write on first clock in DPD mode
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(true, ctrl);
      --wait for 600 ns;
   
      ahbwrite(mem+x"0000", x"00000000", "10", "10", '0', 1, true , ctrl);
      
      ahbwrite(mem+x"0000", x"00000000", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"00000000", "10", "11", '1', 1, true , ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbtbmidle(true, ctrl);
  
      --ahbwrite(io+ x"0000", x"a9818270", "10", "10", '1', 2, true , ctrl);
      --ahbtbmidle(true, ctrl);
      --ahbwrite(io+ x"0000", x"a9888270", "10", "10", '1', 2, true , ctrl);
      --ahbtbmidle(true, ctrl);
  
      print("Disable: Deep Power-Down(DPD) mode");
      ahbwrite(io+ x"0008", x"81F80000", "10", "10", '0', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      print("Wait for 200 us");
      wait for 200 ns; -- 200 us;
      print("Start Initialization");
      ahbwrite(io+ x"0000", x"D58183CF", "10", "10", '0', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      wait for 1000 ns;
      
      -- Write test data
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
    end if;  
    -- DPD/ ------------------------------------------------------------------
  
    -- /CS -------------------------------------------------------------------
    if ClockStop = 1 then
      print("Enable: Clock-Stop(CS) mode");
      ahbwrite(io+ x"0008", x"81FC0000", "10", "10", '0', 1, true , ctrl);
      ahbtbmidle(false, ctrl); -- Read on first clock in DPD mode
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      ahbtbmidle(false, ctrl);
      --ahbtbmidle(true, ctrl);
      --wait for 600 ns; 
  
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
  
      if StatusReadReg = 1 then
        print("Read: Status Read Register");
        if ddrbits = 16 then
          ahbread (io+ x"0010", x"440f0000", "10", "10", '1', 1, true , ctrl); -- SRR
        else
          ahbread (io+ x"0010", x"440f440f", "10", "10", '1', 1, true , ctrl); -- SRR
        end if;
        ahbtbmidle(true, ctrl);
      end if;
     
      wait for 600 ns;
      
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
  
      print("Disable: Clock-Stop(CS) mode");
      ahbwrite(io+ x"0008", x"81F80000", "10", "10", '0', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
  
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
    end if;
    -- CS/ -------------------------------------------------------------------
    
    if DS_TCSR_test = 1 then
      print("Test: Drive srtength Half)");
      ahbwrite(io+ x"0008", x"81F80020", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Drive srtength One-Quater)");
      ahbwrite(io+ x"0008", x"81F80040", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Drive srtength One-Eighth)");
      ahbwrite(io+ x"0008", x"81F80060", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Drive srtength Full)");
      ahbwrite(io+ x"0008", x"81F80000", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      
      print("Test: Temperature-Compensated SR [45C]");
      ahbwrite(io+ x"0008", x"81F80008", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Temperature-Compensated SR [15C]");
      ahbwrite(io+ x"0008", x"81F80010", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Temperature-Compensated SR [85C]");
      ahbwrite(io+ x"0008", x"81F80018", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Temperature-Compensated SR [70C]");
      ahbwrite(io+ x"0008", x"81F80000", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      
    end if;
    
    
    if (SelfRefresh = 1) or (PowerDown = 1) or (DeepPowerDown = 1) 
       or (ClockStop = 1) or (StatusReadReg = 1) then
      print("******  Power-Saving mode test done  ******");
    end if;
    
    if CASLatencyTest >= 2 then
      print("******  Read offset test  ******");
      
      if CASLatencyTest = 2 then
        print("Set CAS Latency = 2");
        ahbwrite(io+ x"0008", x"81F80000", "10", "10", '0', 1, true , ctrl);
      elsif CASLatencyTest = 3 then
        print("Set CAS Latency = 3");
        ahbwrite(io+ x"0008", x"C1F80000", "10", "10", '0', 1, true , ctrl);
      end if;
      ahbwrite(io+ x"0000", x"D59883CF", "10", "10", '0', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      
      -- Write test data
      ahbwrite(mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002c", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0038", x"1d1d1e1e", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"003c", x"1f1f2020", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0038", x"1d1d1e1e", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0038", x"1d1d1e1e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0038", x"1d1d1e1e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"003C", x"1f1f2020", "10", "11", '1', 1, true , ctrl);
      
      ahbtbmidle(true, ctrl);
      print("******  Read offset test done ******");
    end if;

    --if WriteOffsetTest = 1 then
    --  print("******  Write offset test  ******");
    --  ahbwrite(mem+x"0000", x"11223344", "10", "10", '0', 2, false, ctrl);
    --  ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001c", x"ccddeeff", "10", "11", '1', 2, true , ctrl);
    --  
    --  ahbwrite(mem+x"0004", x"11223344", "10", "10", '0', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"ccddeeff", "10", "11", '1', 2, true , ctrl);
    --  
    --  ahbwrite(mem+x"0008", x"11223344", "10", "10", '0', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"ccddeeff", "10", "11", '1', 2, true , ctrl);
    --  
    --  ahbwrite(mem+x"000C", x"11223344", "10", "10", '0', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"ccddeeff", "10", "11", '1', 2, true , ctrl);
    --  
    --  ahbwrite(mem+x"0010", x"11223344", "10", "10", '0', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"002C", x"ccddeeff", "10", "11", '1', 2, true , ctrl);
    --  
    --  ahbwrite(mem+x"0014", x"11223344", "10", "10", '0', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"002C", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"002C", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0030", x"ccddeeff", "10", "11", '1', 2, true , ctrl);
    --  
    --  ahbwrite(mem+x"0018", x"11223344", "10", "10", '0', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"002C", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"002C", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0030", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"002C", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0030", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0034", x"ccddeeff", "10", "11", '1', 2, true , ctrl);
    --  
    --  ahbwrite(mem+x"001C", x"11223344", "10", "10", '0', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"002C", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"002C", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0030", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"002C", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0030", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0034", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0028", x"ddeeff00", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"002C", x"00112233", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0030", x"44556677", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0034", x"8899aabb", "10", "11", '1', 2, false, ctrl);
    --  ahbwrite(mem+x"0038", x"ccddeeff", "10", "11", '1', 2, true , ctrl);
    --  ahbtbmidle(true, ctrl);
    --  print("******  Write offset test done  ******");
    --end if; 
    
    if WriteOffsetTest = 1 then
      print("******  Write offset test  ******");
      ahbwrite(mem+x"0000", x"afafafaf", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '0', 1, false, ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0000", x"afafafaf", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0004", x"11223344", "10", "10", '0', 1, false, ctrl);
      ahbread (mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0000", x"afafafaf", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0008", x"11223344", "10", "10", '0', 1, false, ctrl);
      ahbread (mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0000", x"afafafaf", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"000C", x"11223344", "10", "10", '0', 1, false, ctrl);
      ahbread (mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0000", x"afafafaf", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0010", x"11223344", "10", "10", '0', 1, false, ctrl);
      ahbread (mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0000", x"afafafaf", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0034", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0014", x"11223344", "10", "10", '0', 1, false, ctrl);
      ahbread (mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0000", x"afafafaf", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0034", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0038", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0018", x"11223344", "10", "10", '0', 1, false, ctrl);
      ahbread (mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0034", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0038", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"0000", x"afafafaf", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0034", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0038", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"003C", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbwrite(mem+x"001C", x"11223344", "10", "10", '0', 1, false, ctrl);
      ahbread (mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0034", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0038", x"afafafaf", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0034", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0038", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0038", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"003C", x"afafafaf", "10", "11", '1', 1, true , ctrl);
      
      ahbtbmidle(true, ctrl);
      print("******  Write offset test done  ******");
    end if; 
  end procedure;
  
  procedure MobileSD(
    constant mem            : in std_logic_vector(31 downto 0);
    constant io             : in std_logic_vector(31 downto 0);
    constant SelfRefresh    : in integer;
    constant PowerDown      : in integer;
    constant DeepPowerDown  : in integer;
    constant DS_TCSR_test   : in integer;
    constant CASLatencyTest : in integer) is
  begin
    print("**********************************************************");
    print("                     Mobile SD");
    print("**********************************************************");

    if (SelfRefresh = 1) or (PowerDown = 1) or (DeepPowerDown = 1) 
       or (DS_TCSR_test = 1) or CASLatencyTest >=2 then
      print("******  Init Mobile SDRAM  ******");
      ahbwrite(io+ x"0000", x"fc41045A", "10", "10", '0', 2, true , ctrl);
      ahbread (io+ x"0000", x"00000000", "10", "10", '1', 2, false, ctrl);
      ahbread (io+ x"0004", x"00000000", "10", "11", '1', 2, true , ctrl);
      ahbtbmidle(true, ctrl);

      print("******  Power-Saving mode test  ******");
      
      -- Write test data
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"11223344", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0034", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0038", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"003c", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0040", x"11223344", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0044", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0048", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"004c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0050", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0054", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0058", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"005c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11223344", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0038", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"003c", x"ccddeeff", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0040", x"11223344", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0044", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0048", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"004c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0050", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0054", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0058", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"005c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
    end if;
        
    wait for 600 ns;
    
    -- /SR -------------------------------------------------------------------
    if SelfRefresh = 1 then
      print("Enable: Self-Refresh(SR) mode (full array)");
      ahbwrite(io+ x"0004", x"c0920000", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(false, ctrl); -- Write on first clock in SR mode
      --ahbtbmidle(true, ctrl);
      --wait for 600 ns;
      
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '0', 1, true , ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      
      if mobile > 0 then
        print("Enable: Self-Refresh(SR) mode (half array)");
        ahbwrite(io+ x"0004", x"c0920001", "10", "10", '0', 1, true , ctrl); -- SR
        ahbtbmidle(true, ctrl);
        wait for 600 ns;
   
        ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
        ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
        ahbtbmidle(true, ctrl);
        
        print("Enable: Self-Refresh(SR) mode (One-quarter array)");
        ahbwrite(io+ x"0004", x"c0920002", "10", "10", '0', 1, true , ctrl); -- SR
        ahbtbmidle(true, ctrl);
        wait for 600 ns;
   
        ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
        ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
        ahbtbmidle(true, ctrl);
        
        print("Enable: Self-Refresh(SR) mode (One-eighth array)");
        ahbwrite(io+ x"0004", x"c0920005", "10", "10", '1', 1, true , ctrl); -- SR
        ahbtbmidle(true, ctrl);
        wait for 600 ns;
  
        ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
        ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
        ahbtbmidle(true, ctrl);
        
        print("Enable: Self-Refresh(SR) mode (One-sixteenth array)");
        ahbwrite(io+ x"0004", x"c0920006", "10", "10", '1', 1, true , ctrl); -- SR
        ahbtbmidle(true, ctrl);
        wait for 600 ns;
  
        ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
        ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
        ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
        ahbtbmidle(true, ctrl);
      end if;
      
      print("Disable: Self-Refresh(SR) mode)");
      ahbwrite(io+ x"0004", x"c0900000", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);

      -- dummy read (sim model don't exit SR until activate, not when cke => 1)
      ahbread (mem+x"0000", x"11223344", "10", "10", '0', 1, true , ctrl);
      ahbtbmidle(true, ctrl);

    end if;
    -- SR/ -------------------------------------------------------------------
    
    wait for 600 ns;
    
    -- /PD -------------------------------------------------------------------
    if PowerDown = 1 then
      print("Enable: Power-Down(PD) mode");
      ahbwrite(io+ x"0004", x"c0910000", "10", "10", '1', 1, true , ctrl); -- PD
      ahbtbmidle(false, ctrl); -- Read on first clock in PD mode
      --ahbtbmidle(true, ctrl);
      --wait for 600 ns;
      
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      
      wait for 600 ns;
      
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
  
      print("Disable: Power-Down(PD) mode)");
      ahbwrite(io+ x"0004", x"c0900000", "10", "10", '0', 1, true , ctrl); -- PD
      ahbtbmidle(true, ctrl);
    end if;
    -- PD/ -------------------------------------------------------------------
    
    wait for 600 ns;
    
    -- /DPD ------------------------------------------------------------------
    if DeepPowerDown = 1 then
      print("Enable: Deep Power-Down(DPD) mode");
      ahbwrite(io+ x"0004", x"c0950000", "10", "10", '1', 1, true , ctrl); -- DPD
      ahbtbmidle(false, ctrl); -- Read on first clock in DPD mode
      --ahbtbmidle(true, ctrl);
      --wait for 600 ns;
   
      ahbwrite(mem+x"0000", x"00000000", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"00000000", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"00000000", "10", "11", '1', 1, true , ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
  
      print("Disable: Deep Power-Down(DPD) mode");
      ahbwrite(io+ x"0004", x"c0900000", "10", "10", '0', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
      
      wait for 600 ns;
      
      -- Write test data
      ahbwrite(mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbread (mem+x"0000", x"11223344", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"55667788", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"99aabbcc", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000c", x"ddeeff00", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"00112233", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"44556677", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"8899aabb", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001c", x"ccddeeff", "10", "11", '1', 1, true , ctrl);
      ahbtbmidle(true, ctrl);
    end if;  
    -- DPD/ ------------------------------------------------------------------
    
    if DS_TCSR_test = 1 then
      print("Test: Drive srtength Half)");
      ahbwrite(io+ x"0004", x"c0900020", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Drive srtength One-Quater)");
      ahbwrite(io+ x"0004", x"c0900040", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Drive srtength One-Eighth)");
      ahbwrite(io+ x"0004", x"c0900060", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Drive srtength Full)");
      ahbwrite(io+ x"0004", x"c0900000", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      
      print("Test: Temperature-Compensated SR [45C]");
      ahbwrite(io+ x"0004", x"c0900008", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Temperature-Compensated SR [15C]");
      ahbwrite(io+ x"0004", x"c0900010", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Temperature-Compensated SR [85C]");
      ahbwrite(io+ x"0004", x"c0900018", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      print("Test: Temperature-Compensated SR [70C]");
      ahbwrite(io+ x"0004", x"c0900000", "10", "10", '0', 1, true , ctrl); -- SR
      ahbtbmidle(true, ctrl);
      wait for 600 ns;
      
    end if;
    
    if (SelfRefresh = 1) or (PowerDown = 1) or (DeepPowerDown = 1) 
       or ( DS_TCSR_test = 1) then
      print("******  Power-Saving mode test done  ******");
    end if;

    if CASLatencyTest >= 2 then
      wait for 2000 ns;
      print("******  Read offset test  ******");
    
      if CASLatencyTest = 2 then
        print("Set CAS Latency = 2");
        ahbwrite(io+ x"0000", x"f859045A", "10", "10", '0', 1, true , ctrl);
      elsif CASLatencyTest = 3 then
        print("Set CAS Latency = 3");
        ahbwrite(io+ x"0000", x"fc59045A", "10", "10", '0', 1, true , ctrl);
      end if;
      wait for 600 ns;
      
      -- Write test data
      ahbwrite(mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbwrite(mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"000c", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"001c", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"002c", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"0038", x"1d1d1e1e", "10", "11", '1', 1, false, ctrl);
      ahbwrite(mem+x"003c", x"1f1f2020", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0000", x"01010202", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0004", x"03030404", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0008", x"05050606", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"000C", x"07070808", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0010", x"09090a0a", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0014", x"0b0b0c0c", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0018", x"0d0d0e0e", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"001C", x"0f0f1010", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0038", x"1d1d1e1e", "10", "11", '1', 1, true , ctrl);
      
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0038", x"1d1d1e1e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0020", x"11111212", "10", "10", '1', 1, false, ctrl);
      ahbread (mem+x"0024", x"13131414", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0028", x"15151616", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"002C", x"17171818", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0030", x"19191a1a", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0034", x"1b1b1c1c", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"0038", x"1d1d1e1e", "10", "11", '1', 1, false, ctrl);
      ahbread (mem+x"003C", x"1f1f2020", "10", "11", '1', 1, true , ctrl);
      
      ahbtbmidle(true, ctrl);
      print("******  Read offset test done ******");
    end if;
  end procedure;
  begin
    -- AHB testbench master init
    ahbtbminit(ctrl);
    
    ----------------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    ----------------------------------------------------------------------------
    wait for 1800 ns;

    MobileDDR(
      mem            => x"40000000",
      io             => x"fff00100",
      ddrbits        => ddrbits,
      StatusReadReg  => 1,
      SelfRefresh    => 1,
      PowerDown      => 1,
      DeepPowerDown  => 1,
      ClockStop      => 1,
      DS_TCSR_test   => 1,
      CASLatencyTest => 3,
      WriteOffsetTest=> 1
    );
    
    MobileDDR(
      mem            => x"40000000",
      io             => x"fff00100",
      ddrbits        => ddrbits,
      StatusReadReg  => 0,
      SelfRefresh    => 0,
      PowerDown      => 0,
      DeepPowerDown  => 0,
      ClockStop      => 0,
      DS_TCSR_test   => 0,
      CASLatencyTest => 2,
      WriteOffsetTest=> 1
    );
    
    MobileSD(
      mem            => x"60000000",
      io             => x"fff00200",
      SelfRefresh    => 1,
      PowerDown      => 1,
      DeepPowerDown  => 1,
      DS_TCSR_test   => 1,
      CASLatencyTest => 3
    );

    ahbtbmidle(true, ctrl);
    ahbtbmdone(1, ctrl);

    wait;
  end process;

-- pragma translate_on

-----------------------------------------------------------------------
---  Drive unused bus elements  ---------------------------------------
-----------------------------------------------------------------------

--  nam1 : for i in (NCPU+CFG_AHB_UART+CFG_ETH+CFG_AHB_ETH+CFG_AHB_JTAG) to NAHBMST-1 generate
--    ahbmo(i) <= ahbm_none;
--  end generate;
--  nap0 : for i in 11 to NAPBSLV-1 generate apbo(i) <= apb_none; end generate;
--  nah0 : for i in 8 to NAHBSLV-1 generate ahbso(i) <= ahbs_none; end generate;

-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_version 
  generic map (
   msg1 => "Mobile DDR / Mobile SDRAM verification design",
   msg2 => "GRLIB Version " & tost(LIBVHDL_VERSION/1000) & "." & tost((LIBVHDL_VERSION mod 1000)/100)
      & "." & tost(LIBVHDL_VERSION mod 100) & ", build " & tost(LIBVHDL_BUILD),
   msg3 => "Target technology: " & tech_table(fabtech) & ",  memory library: " & tech_table(memtech),
   mdel => 1
  );
-- pragma translate_on
end;
