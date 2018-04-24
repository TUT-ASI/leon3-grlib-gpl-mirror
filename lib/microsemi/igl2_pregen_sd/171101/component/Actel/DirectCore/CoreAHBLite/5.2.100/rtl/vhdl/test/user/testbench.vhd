-- ********************************************************************/
-- Actel Corporation Proprietary and Confidential
-- Copyright 2010 Actel Corporation.  All rights reserved.
--
-- ANY USE OR REDISTRIBUTION IN PART OR IN WHOLE MUST BE HANDLED IN
-- ACCORDANCE WITH THE ACTEL LICENSE AGREEMENT AND MUST BE APPROVED
-- IN ADVANCE IN WRITING.
--
-- Description:	CoreAHBLite - user testbench
--
-- Revision Information:
-- Date			Description
-- ----			-----------------------------------------
-- 10Feb10		Production Release Version 3.1
--
-- SVN Revision Information:
-- SVN $Revision: 22340 $
-- SVN $Date: 2014-04-11 17:29:35 +0100 (Fri, 11 Apr 2014) $
--
-- Resolved SARs
-- SAR      Date     Who   Description
--
-- Notes:
-- 1. best viewed with tabstops set to "4" (tabs used throughout file)
--
-- *********************************************************************/

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.coreparameters.all;
use work.components.all;
use work.bfm_package.all;


entity testbench is
generic (

SYSCLK_PERIOD       : integer := 10; -- 100MHz

-- the locations and names of these can be overridden at run time
MASTER0_VECTFILE    : string := "coreahblite_usertb_ahb_master0.vec";
MASTER1_VECTFILE    : string := "coreahblite_usertb_ahb_master1.vec";
MASTER2_VECTFILE    : string := "coreahblite_usertb_ahb_master2.vec";
MASTER3_VECTFILE    : string := "coreahblite_usertb_ahb_master3.vec";

-- propagation delay in ns
TPD                 : integer := 3
);
end entity testbench;

architecture testbench_arch of testbench is

-----------------------------------------------------------------------------
-- components
-----------------------------------------------------------------------------
-- from work.components ...


signal stopsim		: integer range 0 to 1 := 0;

signal SYSCLK		: std_logic;
signal SYSRSTN		: std_logic;

-- using HCLK & HRESETN from master 0 to connect to CoreAHBLite
signal HCLK			: std_logic;
signal HRESETN		: std_logic;

-- control remap signal from master 0 BFM
signal REMAP_M0		: std_logic;

-- GPIO for 2 master BFM's
signal GP_OUT_M0	: std_logic_vector(31 downto 0);
signal GP_OUT_M1	: std_logic_vector(31 downto 0);
-- GP_IN shared
signal GP_IN		: std_logic_vector(31 downto 0);

-- signals for testbench request/acknowledgement between masters
signal M0_REQ		: std_logic;
signal M0_ACK		: std_logic;
signal M1_REQ		: std_logic;
signal M1_ACK		: std_logic;

signal HREADY_M0               : std_logic;
signal HRESP_M0                : std_logic_vector(1 downto 0);
signal HRDATA_M0               : std_logic_vector(31 downto 0);
signal HTRANS_M0               : std_logic_vector(1 downto 0);
signal HSIZE_M0                : std_logic_vector(2 downto 0);
signal HWRITE_M0               : std_logic;
signal HMASTLOCK_M0            : std_logic;
signal HADDR_M0                : std_logic_vector(31 downto 0);
signal HWDATA_M0               : std_logic_vector(31 downto 0);
signal HBURST_M0               : std_logic_vector(2 downto 0);
signal HPROT_M0                : std_logic_vector(3 downto 0);

signal HREADY_M1               : std_logic;
signal HRESP_M1                : std_logic_vector(1 downto 0);
signal HRDATA_M1               : std_logic_vector(31 downto 0);
signal HTRANS_M1               : std_logic_vector(1 downto 0);
signal HSIZE_M1                : std_logic_vector(2 downto 0);
signal HWRITE_M1               : std_logic;
signal HMASTLOCK_M1            : std_logic;
signal HADDR_M1                : std_logic_vector(31 downto 0);
signal HWDATA_M1               : std_logic_vector(31 downto 0);
signal HBURST_M1               : std_logic_vector(2 downto 0);
signal HPROT_M1                : std_logic_vector(3 downto 0);

signal HREADY_M2               : std_logic;
signal HRESP_M2                : std_logic_vector(1 downto 0);
signal HRDATA_M2               : std_logic_vector(31 downto 0);
signal HTRANS_M2               : std_logic_vector(1 downto 0);
signal HSIZE_M2                : std_logic_vector(2 downto 0);
signal HWRITE_M2               : std_logic;
signal HMASTLOCK_M2            : std_logic;
signal HADDR_M2                : std_logic_vector(31 downto 0);
signal HWDATA_M2               : std_logic_vector(31 downto 0);
signal HBURST_M2               : std_logic_vector(2 downto 0);
signal HPROT_M2                : std_logic_vector(3 downto 0);

signal HREADY_M3               : std_logic;
signal HRESP_M3                : std_logic_vector(1 downto 0);
signal HRDATA_M3               : std_logic_vector(31 downto 0);
signal HTRANS_M3               : std_logic_vector(1 downto 0);
signal HSIZE_M3                : std_logic_vector(2 downto 0);
signal HWRITE_M3               : std_logic;
signal HMASTLOCK_M3            : std_logic;
signal HADDR_M3                : std_logic_vector(31 downto 0);
signal HWDATA_M3               : std_logic_vector(31 downto 0);
signal HBURST_M3               : std_logic_vector(2 downto 0);
signal HPROT_M3                : std_logic_vector(3 downto 0);

signal HWRITE_S0               : std_logic;
signal HSIZE_S0                : std_logic_vector(2 downto 0);
signal HTRANS_S0               : std_logic_vector(1 downto 0);
signal HWDATA_S0               : std_logic_vector(31 downto 0);
signal HREADYIN_S0             : std_logic;
signal HSEL_S0                 : std_logic;
signal HADDR_S0                : std_logic_vector(31 downto 0);
signal HRDATA_S0               : std_logic_vector(31 downto 0);
signal HRESP_S0                : std_logic_vector(1 downto 0);
signal HREADY_S0,HMASTLOCK_S0  : std_logic;
signal HBURST_S0               : std_logic_vector(2 downto 0);
signal HPROT_S0                : std_logic_vector(3 downto 0);

signal HWRITE_S1               : std_logic;
signal HSIZE_S1                : std_logic_vector(2 downto 0);
signal HTRANS_S1               : std_logic_vector(1 downto 0);
signal HWDATA_S1               : std_logic_vector(31 downto 0);
signal HREADYIN_S1             : std_logic;
signal HSEL_S1                 : std_logic;
signal HADDR_S1                : std_logic_vector(31 downto 0);
signal HRDATA_S1               : std_logic_vector(31 downto 0);
signal HRESP_S1                : std_logic_vector(1 downto 0);
signal HREADY_S1,HMASTLOCK_S1  : std_logic;
signal HBURST_S1               : std_logic_vector(2 downto 0);
signal HPROT_S1                : std_logic_vector(3 downto 0);

signal HWRITE_S2               : std_logic;
signal HSIZE_S2                : std_logic_vector(2 downto 0);
signal HTRANS_S2               : std_logic_vector(1 downto 0);
signal HWDATA_S2               : std_logic_vector(31 downto 0);
signal HREADYIN_S2             : std_logic;
signal HSEL_S2                 : std_logic;
signal HADDR_S2                : std_logic_vector(31 downto 0);
signal HRDATA_S2               : std_logic_vector(31 downto 0);
signal HRESP_S2                : std_logic_vector(1 downto 0);
signal HREADY_S2,HMASTLOCK_S2  : std_logic;
signal HBURST_S2               : std_logic_vector(2 downto 0);
signal HPROT_S2                : std_logic_vector(3 downto 0);

signal HWRITE_S3               : std_logic;
signal HSIZE_S3                : std_logic_vector(2 downto 0);
signal HTRANS_S3               : std_logic_vector(1 downto 0);
signal HWDATA_S3               : std_logic_vector(31 downto 0);
signal HREADYIN_S3             : std_logic;
signal HSEL_S3                 : std_logic;
signal HADDR_S3                : std_logic_vector(31 downto 0);
signal HRDATA_S3               : std_logic_vector(31 downto 0);
signal HRESP_S3                : std_logic_vector(1 downto 0);
signal HREADY_S3,HMASTLOCK_S3  : std_logic;
signal HBURST_S3               : std_logic_vector(2 downto 0);
signal HPROT_S3                : std_logic_vector(3 downto 0);

signal HWRITE_S4               : std_logic;
signal HSIZE_S4                : std_logic_vector(2 downto 0);
signal HTRANS_S4               : std_logic_vector(1 downto 0);
signal HWDATA_S4               : std_logic_vector(31 downto 0);
signal HREADYIN_S4             : std_logic;
signal HSEL_S4                 : std_logic;
signal HADDR_S4                : std_logic_vector(31 downto 0);
signal HRDATA_S4               : std_logic_vector(31 downto 0);
signal HRESP_S4                : std_logic_vector(1 downto 0);
signal HREADY_S4,HMASTLOCK_S4  : std_logic;
signal HBURST_S4               : std_logic_vector(2 downto 0);
signal HPROT_S4                : std_logic_vector(3 downto 0);

signal HWRITE_S5               : std_logic;
signal HSIZE_S5                : std_logic_vector(2 downto 0);
signal HTRANS_S5               : std_logic_vector(1 downto 0);
signal HWDATA_S5               : std_logic_vector(31 downto 0);
signal HREADYIN_S5             : std_logic;
signal HSEL_S5                 : std_logic;
signal HADDR_S5                : std_logic_vector(31 downto 0);
signal HRDATA_S5               : std_logic_vector(31 downto 0);
signal HRESP_S5                : std_logic_vector(1 downto 0);
signal HREADY_S5,HMASTLOCK_S5  : std_logic;
signal HBURST_S5               : std_logic_vector(2 downto 0);
signal HPROT_S5                : std_logic_vector(3 downto 0);

signal HWRITE_S6               : std_logic;
signal HSIZE_S6                : std_logic_vector(2 downto 0);
signal HTRANS_S6               : std_logic_vector(1 downto 0);
signal HWDATA_S6               : std_logic_vector(31 downto 0);
signal HREADYIN_S6             : std_logic;
signal HSEL_S6                 : std_logic;
signal HADDR_S6                : std_logic_vector(31 downto 0);
signal HRDATA_S6               : std_logic_vector(31 downto 0);
signal HRESP_S6                : std_logic_vector(1 downto 0);
signal HREADY_S6,HMASTLOCK_S6  : std_logic;
signal HBURST_S6               : std_logic_vector(2 downto 0);
signal HPROT_S6                : std_logic_vector(3 downto 0);

signal HWRITE_S7               : std_logic;
signal HSIZE_S7                : std_logic_vector(2 downto 0);
signal HTRANS_S7               : std_logic_vector(1 downto 0);
signal HWDATA_S7               : std_logic_vector(31 downto 0);
signal HREADYIN_S7             : std_logic;
signal HSEL_S7                 : std_logic;
signal HADDR_S7                : std_logic_vector(31 downto 0);
signal HRDATA_S7               : std_logic_vector(31 downto 0);
signal HRESP_S7                : std_logic_vector(1 downto 0);
signal HREADY_S7,HMASTLOCK_S7  : std_logic;
signal HBURST_S7               : std_logic_vector(2 downto 0);
signal HPROT_S7                : std_logic_vector(3 downto 0);

signal HWRITE_S8               : std_logic;
signal HSIZE_S8                : std_logic_vector(2 downto 0);
signal HTRANS_S8               : std_logic_vector(1 downto 0);
signal HWDATA_S8               : std_logic_vector(31 downto 0);
signal HREADYIN_S8             : std_logic;
signal HSEL_S8                 : std_logic;
signal HADDR_S8                : std_logic_vector(31 downto 0);
signal HRDATA_S8               : std_logic_vector(31 downto 0);
signal HRESP_S8                : std_logic_vector(1 downto 0);
signal HREADY_S8,HMASTLOCK_S8  : std_logic;
signal HBURST_S8               : std_logic_vector(2 downto 0);
signal HPROT_S8                : std_logic_vector(3 downto 0);

signal HWRITE_S9               : std_logic;
signal HSIZE_S9                : std_logic_vector(2 downto 0);
signal HTRANS_S9               : std_logic_vector(1 downto 0);
signal HWDATA_S9               : std_logic_vector(31 downto 0);
signal HREADYIN_S9             : std_logic;
signal HSEL_S9                 : std_logic;
signal HADDR_S9                : std_logic_vector(31 downto 0);
signal HRDATA_S9               : std_logic_vector(31 downto 0);
signal HRESP_S9                : std_logic_vector(1 downto 0);
signal HREADY_S9,HMASTLOCK_S9  : std_logic;
signal HBURST_S9               : std_logic_vector(2 downto 0);
signal HPROT_S9                : std_logic_vector(3 downto 0);

signal HWRITE_S10              : std_logic;
signal HSIZE_S10               : std_logic_vector(2 downto 0);
signal HTRANS_S10              : std_logic_vector(1 downto 0);
signal HWDATA_S10              : std_logic_vector(31 downto 0);
signal HREADYIN_S10            : std_logic;
signal HSEL_S10                : std_logic;
signal HADDR_S10               : std_logic_vector(31 downto 0);
signal HRDATA_S10              : std_logic_vector(31 downto 0);
signal HRESP_S10               : std_logic_vector(1 downto 0);
signal HREADY_S10,HMASTLOCK_S10: std_logic;
signal HBURST_S10              : std_logic_vector(2 downto 0);
signal HPROT_S10               : std_logic_vector(3 downto 0);

signal HWRITE_S11              : std_logic;
signal HSIZE_S11               : std_logic_vector(2 downto 0);
signal HTRANS_S11              : std_logic_vector(1 downto 0);
signal HWDATA_S11              : std_logic_vector(31 downto 0);
signal HREADYIN_S11            : std_logic;
signal HSEL_S11                : std_logic;
signal HADDR_S11               : std_logic_vector(31 downto 0);
signal HRDATA_S11              : std_logic_vector(31 downto 0);
signal HRESP_S11               : std_logic_vector(1 downto 0);
signal HREADY_S11,HMASTLOCK_S11: std_logic;
signal HBURST_S11              : std_logic_vector(2 downto 0);
signal HPROT_S11               : std_logic_vector(3 downto 0);

signal HWRITE_S12              : std_logic;
signal HSIZE_S12               : std_logic_vector(2 downto 0);
signal HTRANS_S12              : std_logic_vector(1 downto 0);
signal HWDATA_S12              : std_logic_vector(31 downto 0);
signal HREADYIN_S12            : std_logic;
signal HSEL_S12                : std_logic;
signal HADDR_S12               : std_logic_vector(31 downto 0);
signal HRDATA_S12              : std_logic_vector(31 downto 0);
signal HRESP_S12               : std_logic_vector(1 downto 0);
signal HREADY_S12,HMASTLOCK_S12: std_logic;
signal HBURST_S12              : std_logic_vector(2 downto 0);
signal HPROT_S12               : std_logic_vector(3 downto 0);

signal HWRITE_S13              : std_logic;
signal HSIZE_S13               : std_logic_vector(2 downto 0);
signal HTRANS_S13              : std_logic_vector(1 downto 0);
signal HWDATA_S13              : std_logic_vector(31 downto 0);
signal HREADYIN_S13            : std_logic;
signal HSEL_S13                : std_logic;
signal HADDR_S13               : std_logic_vector(31 downto 0);
signal HRDATA_S13              : std_logic_vector(31 downto 0);
signal HRESP_S13               : std_logic_vector(1 downto 0);
signal HREADY_S13,HMASTLOCK_S13: std_logic;
signal HBURST_S13              : std_logic_vector(2 downto 0);
signal HPROT_S13               : std_logic_vector(3 downto 0);

signal HWRITE_S14              : std_logic;
signal HSIZE_S14               : std_logic_vector(2 downto 0);
signal HTRANS_S14              : std_logic_vector(1 downto 0);
signal HWDATA_S14              : std_logic_vector(31 downto 0);
signal HREADYIN_S14            : std_logic;
signal HSEL_S14                : std_logic;
signal HADDR_S14               : std_logic_vector(31 downto 0);
signal HRDATA_S14              : std_logic_vector(31 downto 0);
signal HRESP_S14               : std_logic_vector(1 downto 0);
signal HREADY_S14,HMASTLOCK_S14: std_logic;
signal HBURST_S14              : std_logic_vector(2 downto 0);
signal HPROT_S14               : std_logic_vector(3 downto 0);

signal HWRITE_S15              : std_logic;
signal HSIZE_S15               : std_logic_vector(2 downto 0);
signal HTRANS_S15              : std_logic_vector(1 downto 0);
signal HWDATA_S15              : std_logic_vector(31 downto 0);
signal HREADYIN_S15            : std_logic;
signal HSEL_S15                : std_logic;
signal HADDR_S15               : std_logic_vector(31 downto 0);
signal HRDATA_S15              : std_logic_vector(31 downto 0);
signal HRESP_S15               : std_logic_vector(1 downto 0);
signal HREADY_S15,HMASTLOCK_S15: std_logic;
signal HBURST_S15              : std_logic_vector(2 downto 0);
signal HPROT_S15               : std_logic_vector(3 downto 0);

signal HWRITE_S16              : std_logic;
signal HSIZE_S16               : std_logic_vector(2 downto 0);
signal HTRANS_S16              : std_logic_vector(1 downto 0);
signal HWDATA_S16              : std_logic_vector(31 downto 0);
signal HREADYIN_S16            : std_logic;
signal HSEL_S16                : std_logic;
signal HADDR_S16               : std_logic_vector(31 downto 0);
signal HRDATA_S16              : std_logic_vector(31 downto 0);
signal HRESP_S16               : std_logic_vector(1 downto 0);
signal HREADY_S16,HMASTLOCK_S16: std_logic;
signal HBURST_S16              : std_logic_vector(2 downto 0);
signal HPROT_S16               : std_logic_vector(3 downto 0);

signal FINISHED_master0        : std_logic;
signal FINISHED_master1        : std_logic;
signal FINISHED_master2        : std_logic;
signal FINISHED_master3        : std_logic;

signal s0_write                : std_logic;
signal s1_write                : std_logic;
signal s2_write                : std_logic;
signal s3_write                : std_logic;
signal s4_write                : std_logic;
signal s5_write                : std_logic;
signal s6_write                : std_logic;
signal s7_write                : std_logic;
signal s8_write                : std_logic;
signal s9_write                : std_logic;
signal s10_write               : std_logic;
signal s11_write               : std_logic;
signal s12_write               : std_logic;
signal s13_write               : std_logic;
signal s14_write               : std_logic;
signal s15_write               : std_logic;
signal s16_write               : std_logic;

-- misc. signals
signal GND256:				std_logic_vector(255 downto 0)	:=(others=>'0');
signal GND15:				std_logic_vector(14 downto 0)	:=(others=>'0');
signal GND12:				std_logic_vector(11 downto 0)	:=(others=>'0');

begin

   -- Main simulation
   process
   begin
      SYSRSTN <= '0';

      -- Release system reset
      wait for (SYSCLK_PERIOD * 4)*1 ns;
      SYSRSTN <= '1';

      -- wait until all BFM's are finished
      while (
        not(
            (
                    (FINISHED_master0 = '1')
                and (FINISHED_master1 = '1')
                and (FINISHED_master2 = '1')
                and (FINISHED_master3 = '1')
            )
           )
      ) loop
	      wait on SYSCLK;
          wait for (TPD)*1 ns;
      end loop;
      wait for 1 ns;
      stopsim <= 1;
      wait;
   end process;

   -- tie-off unused inputs to DUT
   HBURST_M0      <= "000";
   HBURST_M1      <= "000";
   HBURST_M2      <= "000";
   HBURST_M3      <= "000";
   HPROT_M0       <= "0000";
   HPROT_M1       <= "0000";
   HPROT_M2       <= "0000";
   HPROT_M3       <= "0000";
   HRESP_S0(1)    <= '0';
   HRESP_S1(1)    <= '0';
   HRESP_S2(1)    <= '0';
   HRESP_S3(1)    <= '0';
   HRESP_S4(1)    <= '0';
   HRESP_S5(1)    <= '0';
   HRESP_S6(1)    <= '0';
   HRESP_S7(1)    <= '0';
   HRESP_S8(1)    <= '0';
   HRESP_S9(1)    <= '0';
   HRESP_S10(1)   <= '0';
   HRESP_S11(1)   <= '0';
   HRESP_S12(1)   <= '0';
   HRESP_S13(1)   <= '0';
   HRESP_S14(1)   <= '0';
   HRESP_S15(1)   <= '0';
   HRESP_S16(1)   <= '0';

   -- System clock
   process
   begin
     SYSCLK <= '0';
     wait for (SYSCLK_PERIOD / 2)*1 ns;
     SYSCLK <= '1';
     wait for (SYSCLK_PERIOD / 2)*1 ns;
     if (stopsim = 1) then
      wait;
    end if;
   end process;

-- Instantiate module to test
u_coreahblite : CoreAHBLite
generic map (
	FAMILY => FAMILY,
	MEMSPACE => MEMSPACE,
    HADDR_SHG_CFG => HADDR_SHG_CFG,
	SC_0  => SC_0 ,
	SC_1  => SC_1 ,
	SC_2  => SC_2 ,
	SC_3  => SC_3 ,
	SC_4  => SC_4 ,
	SC_5  => SC_5 ,
	SC_6  => SC_6 ,
	SC_7  => SC_7 ,
	SC_8  => SC_8 ,
	SC_9  => SC_9 ,
	SC_10 => SC_10,
	SC_11 => SC_11,
	SC_12 => SC_12,
	SC_13 => SC_13,
	SC_14 => SC_14,
	SC_15 => SC_15,
	M0_AHBSLOT0ENABLE  => M0_AHBSLOT0ENABLE,
	M0_AHBSLOT1ENABLE  => M0_AHBSLOT1ENABLE,
	M0_AHBSLOT2ENABLE  => M0_AHBSLOT2ENABLE,
	M0_AHBSLOT3ENABLE  => M0_AHBSLOT3ENABLE,
	M0_AHBSLOT4ENABLE  => M0_AHBSLOT4ENABLE,
	M0_AHBSLOT5ENABLE  => M0_AHBSLOT5ENABLE,
	M0_AHBSLOT6ENABLE  => M0_AHBSLOT6ENABLE,
	M0_AHBSLOT7ENABLE  => M0_AHBSLOT7ENABLE,
	M0_AHBSLOT8ENABLE  => M0_AHBSLOT8ENABLE,
	M0_AHBSLOT9ENABLE  => M0_AHBSLOT9ENABLE,
	M0_AHBSLOT10ENABLE => M0_AHBSLOT10ENABLE,
	M0_AHBSLOT11ENABLE => M0_AHBSLOT11ENABLE,
	M0_AHBSLOT12ENABLE => M0_AHBSLOT12ENABLE,
	M0_AHBSLOT13ENABLE => M0_AHBSLOT13ENABLE,
	M0_AHBSLOT14ENABLE => M0_AHBSLOT14ENABLE,
	M0_AHBSLOT15ENABLE => M0_AHBSLOT15ENABLE,
	M0_AHBSLOT16ENABLE => M0_AHBSLOT16ENABLE,
	M1_AHBSLOT0ENABLE  => M1_AHBSLOT0ENABLE,
	M1_AHBSLOT1ENABLE  => M1_AHBSLOT1ENABLE,
	M1_AHBSLOT2ENABLE  => M1_AHBSLOT2ENABLE,
	M1_AHBSLOT3ENABLE  => M1_AHBSLOT3ENABLE,
	M1_AHBSLOT4ENABLE  => M1_AHBSLOT4ENABLE,
	M1_AHBSLOT5ENABLE  => M1_AHBSLOT5ENABLE,
	M1_AHBSLOT6ENABLE  => M1_AHBSLOT6ENABLE,
	M1_AHBSLOT7ENABLE  => M1_AHBSLOT7ENABLE,
	M1_AHBSLOT8ENABLE  => M1_AHBSLOT8ENABLE,
	M1_AHBSLOT9ENABLE  => M1_AHBSLOT9ENABLE,
	M1_AHBSLOT10ENABLE => M1_AHBSLOT10ENABLE,
	M1_AHBSLOT11ENABLE => M1_AHBSLOT11ENABLE,
	M1_AHBSLOT12ENABLE => M1_AHBSLOT12ENABLE,
	M1_AHBSLOT13ENABLE => M1_AHBSLOT13ENABLE,
	M1_AHBSLOT14ENABLE => M1_AHBSLOT14ENABLE,
	M1_AHBSLOT15ENABLE => M1_AHBSLOT15ENABLE,
	M1_AHBSLOT16ENABLE => M1_AHBSLOT16ENABLE,
	M2_AHBSLOT0ENABLE  => M2_AHBSLOT0ENABLE,
	M2_AHBSLOT1ENABLE  => M2_AHBSLOT1ENABLE,
	M2_AHBSLOT2ENABLE  => M2_AHBSLOT2ENABLE,
	M2_AHBSLOT3ENABLE  => M2_AHBSLOT3ENABLE,
	M2_AHBSLOT4ENABLE  => M2_AHBSLOT4ENABLE,
	M2_AHBSLOT5ENABLE  => M2_AHBSLOT5ENABLE,
	M2_AHBSLOT6ENABLE  => M2_AHBSLOT6ENABLE,
	M2_AHBSLOT7ENABLE  => M2_AHBSLOT7ENABLE,
	M2_AHBSLOT8ENABLE  => M2_AHBSLOT8ENABLE,
	M2_AHBSLOT9ENABLE  => M2_AHBSLOT9ENABLE,
	M2_AHBSLOT10ENABLE => M2_AHBSLOT10ENABLE,
	M2_AHBSLOT11ENABLE => M2_AHBSLOT11ENABLE,
	M2_AHBSLOT12ENABLE => M2_AHBSLOT12ENABLE,
	M2_AHBSLOT13ENABLE => M2_AHBSLOT13ENABLE,
	M2_AHBSLOT14ENABLE => M2_AHBSLOT14ENABLE,
	M2_AHBSLOT15ENABLE => M2_AHBSLOT15ENABLE,
	M2_AHBSLOT16ENABLE => M2_AHBSLOT16ENABLE,
	M3_AHBSLOT0ENABLE  => M3_AHBSLOT0ENABLE,
	M3_AHBSLOT1ENABLE  => M3_AHBSLOT1ENABLE,
	M3_AHBSLOT2ENABLE  => M3_AHBSLOT2ENABLE,
	M3_AHBSLOT3ENABLE  => M3_AHBSLOT3ENABLE,
	M3_AHBSLOT4ENABLE  => M3_AHBSLOT4ENABLE,
	M3_AHBSLOT5ENABLE  => M3_AHBSLOT5ENABLE,
	M3_AHBSLOT6ENABLE  => M3_AHBSLOT6ENABLE,
	M3_AHBSLOT7ENABLE  => M3_AHBSLOT7ENABLE,
	M3_AHBSLOT8ENABLE  => M3_AHBSLOT8ENABLE,
	M3_AHBSLOT9ENABLE  => M3_AHBSLOT9ENABLE,
	M3_AHBSLOT10ENABLE => M3_AHBSLOT10ENABLE,
	M3_AHBSLOT11ENABLE => M3_AHBSLOT11ENABLE,
	M3_AHBSLOT12ENABLE => M3_AHBSLOT12ENABLE,
	M3_AHBSLOT13ENABLE => M3_AHBSLOT13ENABLE,
	M3_AHBSLOT14ENABLE => M3_AHBSLOT14ENABLE,
	M3_AHBSLOT15ENABLE => M3_AHBSLOT15ENABLE,
	M3_AHBSLOT16ENABLE => M3_AHBSLOT16ENABLE
)
port map (
	-- ResetController interface
	-- Inputs
	HCLK => HCLK,
	HRESETN => HRESETN,

	-- controls master 0 memory aliasing (swaps slots 0 and 1)
	REMAP_M0 => REMAP_M0,

	-- Mirrored master AHB-Lite interface to Master 0
	-- Inputs
	HADDR_M0 => HADDR_M0,
	HMASTLOCK_M0 => HMASTLOCK_M0,
	HSIZE_M0 => HSIZE_M0,
	HTRANS_M0 => HTRANS_M0,
	HWRITE_M0 => HWRITE_M0,
	HWDATA_M0 => HWDATA_M0,
	HBURST_M0 => HBURST_M0,
	HPROT_M0 => HPROT_M0,
	-- Outputs
	HRESP_M0 => HRESP_M0,
	HRDATA_M0 => HRDATA_M0,
	HREADY_M0 => HREADY_M0,

	-- Mirrored master AHB-Lite interface to Master 1
	-- Inputs
	HADDR_M1 => HADDR_M1,
	HMASTLOCK_M1 => HMASTLOCK_M1,
	HSIZE_M1 => HSIZE_M1,
	HTRANS_M1 => HTRANS_M1,
	HWRITE_M1 => HWRITE_M1,
	HWDATA_M1 => HWDATA_M1,
	HBURST_M1 => HBURST_M1,
	HPROT_M1 => HPROT_M1,
	-- Outputs
	HRESP_M1 => HRESP_M1,
	HRDATA_M1 => HRDATA_M1,
	HREADY_M1 => HREADY_M1,

	-- Mirrored master AHB-Lite interface to Master 2
	-- Inputs
	HADDR_M2 => HADDR_M2,
	HMASTLOCK_M2 => HMASTLOCK_M2,
	HSIZE_M2 => HSIZE_M2,
	HTRANS_M2 => HTRANS_M2,
	HWRITE_M2 => HWRITE_M2,
	HWDATA_M2 => HWDATA_M2,
	HBURST_M2 => HBURST_M2,
	HPROT_M2 => HPROT_M2,
	-- Outputs
	HRESP_M2 => HRESP_M2,
	HRDATA_M2 => HRDATA_M2,
	HREADY_M2 => HREADY_M2,

	-- Mirrored master AHB-Lite interface to Master 3
	-- Inputs
	HADDR_M3 => HADDR_M3,
	HMASTLOCK_M3 => HMASTLOCK_M3,
	HSIZE_M3 => HSIZE_M3,
	HTRANS_M3 => HTRANS_M3,
	HWRITE_M3 => HWRITE_M3,
	HWDATA_M3 => HWDATA_M3,
	HBURST_M3 => HBURST_M3,
	HPROT_M3 => HPROT_M3,
	-- Outputs
	HRESP_M3 => HRESP_M3,
	HRDATA_M3 => HRDATA_M3,
	HREADY_M3 => HREADY_M3,

	-- Mirrored slave AHB-Lite interface to Slave 0
	-- Inputs
	HRDATA_S0 => HRDATA_S0,
	HREADYOUT_S0 => HREADY_S0,
	HRESP_S0 => HRESP_S0,
	-- Outputs
	HSEL_S0 => HSEL_S0,
	HADDR_S0 => HADDR_S0,
	HSIZE_S0 => HSIZE_S0,
	HTRANS_S0 => HTRANS_S0,
	HWRITE_S0 => HWRITE_S0,
	HWDATA_S0 => HWDATA_S0,
	HREADY_S0 => HREADYIN_S0,
	HMASTLOCK_S0 => HMASTLOCK_S0,
	HBURST_S0 => HBURST_S0,
	HPROT_S0 => HPROT_S0,

	-- Mirrored slave AHB-Lite interface to Slave 1
	-- Inputs
	HRDATA_S1 => HRDATA_S1,
	HREADYOUT_S1 => HREADY_S1,
	HRESP_S1 => HRESP_S1,
	-- Outputs
	HSEL_S1 => HSEL_S1,
	HADDR_S1 => HADDR_S1,
	HSIZE_S1 => HSIZE_S1,
	HTRANS_S1 => HTRANS_S1,
	HWRITE_S1 => HWRITE_S1,
	HWDATA_S1 => HWDATA_S1,
	HREADY_S1 => HREADYIN_S1,
	HMASTLOCK_S1 => HMASTLOCK_S1,
	HBURST_S1 => HBURST_S1,
	HPROT_S1 => HPROT_S1,

	-- Mirrored slave AHB-Lite interface to Slave 2
	-- Inputs
	HRDATA_S2 => HRDATA_S2,
	HREADYOUT_S2 => HREADY_S2,
	HRESP_S2 => HRESP_S2,
	-- Outputs
	HSEL_S2 => HSEL_S2,
	HADDR_S2 => HADDR_S2,
	HSIZE_S2 => HSIZE_S2,
	HTRANS_S2 => HTRANS_S2,
	HWRITE_S2 => HWRITE_S2,
	HWDATA_S2 => HWDATA_S2,
	HREADY_S2 => HREADYIN_S2,
	HMASTLOCK_S2 => HMASTLOCK_S2,
	HBURST_S2 => HBURST_S2,
	HPROT_S2 => HPROT_S2,

	-- Mirrored slave AHB-Lite interface to Slave 3
	-- Inputs
	HRDATA_S3 => HRDATA_S3,
	HREADYOUT_S3 => HREADY_S3,
	HRESP_S3 => HRESP_S3,
	-- Output
	HSEL_S3 => HSEL_S3,
	HADDR_S3 => HADDR_S3,
	HSIZE_S3 => HSIZE_S3,
	HTRANS_S3 => HTRANS_S3,
	HWRITE_S3 => HWRITE_S3,
	HWDATA_S3 => HWDATA_S3,
	HREADY_S3 => HREADYIN_S3,
	HMASTLOCK_S3 => HMASTLOCK_S3,
	HBURST_S3 => HBURST_S3,
	HPROT_S3 => HPROT_S3,

	-- Mirrored slave AHB-Lite interface to Slave 4
	-- Inputs
	HRDATA_S4 => HRDATA_S4,
	HREADYOUT_S4 => HREADY_S4,
	HRESP_S4 => HRESP_S4,
	-- Output
	HSEL_S4 => HSEL_S4,
	HADDR_S4 => HADDR_S4,
	HSIZE_S4 => HSIZE_S4,
	HTRANS_S4 => HTRANS_S4,
	HWRITE_S4 => HWRITE_S4,
	HWDATA_S4 => HWDATA_S4,
	HREADY_S4 => HREADYIN_S4,
	HMASTLOCK_S4 => HMASTLOCK_S4,
	HBURST_S4 => HBURST_S4,
	HPROT_S4 => HPROT_S4,

	-- Mirrored slave AHB-Lite interface to Slave 5
	-- Inputs
	HRDATA_S5 => HRDATA_S5,
	HREADYOUT_S5 => HREADY_S5,
	HRESP_S5 => HRESP_S5,
	-- Output
	HSEL_S5 => HSEL_S5,
	HADDR_S5 => HADDR_S5,
	HSIZE_S5 => HSIZE_S5,
	HTRANS_S5 => HTRANS_S5,
	HWRITE_S5 => HWRITE_S5,
	HWDATA_S5 => HWDATA_S5,
	HREADY_S5 => HREADYIN_S5,
	HMASTLOCK_S5 => HMASTLOCK_S5,
	HBURST_S5 => HBURST_S5,
	HPROT_S5 => HPROT_S5,

	-- Mirrored slave AHB-Lite interface to Slave 6
	-- Inputs
	HRDATA_S6 => HRDATA_S6,
	HREADYOUT_S6 => HREADY_S6,
	HRESP_S6 => HRESP_S6,
	-- Output
	HSEL_S6 => HSEL_S6,
	HADDR_S6 => HADDR_S6,
	HSIZE_S6 => HSIZE_S6,
	HTRANS_S6 => HTRANS_S6,
	HWRITE_S6 => HWRITE_S6,
	HWDATA_S6 => HWDATA_S6,
	HREADY_S6 => HREADYIN_S6,
	HMASTLOCK_S6 => HMASTLOCK_S6,
	HBURST_S6 => HBURST_S6,
	HPROT_S6 => HPROT_S6,

	-- Mirrored slave AHB-Lite interface to Slave 7
	-- Inputs
	HRDATA_S7 => HRDATA_S7,
	HREADYOUT_S7 => HREADY_S7,
	HRESP_S7 => HRESP_S7,
	-- Output
	HSEL_S7 => HSEL_S7,
	HADDR_S7 => HADDR_S7,
	HSIZE_S7 => HSIZE_S7,
	HTRANS_S7 => HTRANS_S7,
	HWRITE_S7 => HWRITE_S7,
	HWDATA_S7 => HWDATA_S7,
	HREADY_S7 => HREADYIN_S7,
	HMASTLOCK_S7 => HMASTLOCK_S7,
	HBURST_S7 => HBURST_S7,
	HPROT_S7 => HPROT_S7,

	-- Mirrored slave AHB-Lite interface to Slave 8
	-- Inputs
	HRDATA_S8 => HRDATA_S8,
	HREADYOUT_S8 => HREADY_S8,
	HRESP_S8 => HRESP_S8,
	-- Output
	HSEL_S8 => HSEL_S8,
	HADDR_S8 => HADDR_S8,
	HSIZE_S8 => HSIZE_S8,
	HTRANS_S8 => HTRANS_S8,
	HWRITE_S8 => HWRITE_S8,
	HWDATA_S8 => HWDATA_S8,
	HREADY_S8 => HREADYIN_S8,
	HMASTLOCK_S8 => HMASTLOCK_S8,
	HBURST_S8 => HBURST_S8,
	HPROT_S8 => HPROT_S8,

	-- Mirrored slave AHB-Lite interface to Slave 9
	-- Inputs
	HRDATA_S9 => HRDATA_S9,
	HREADYOUT_S9 => HREADY_S9,
	HRESP_S9 => HRESP_S9,
	-- Output
	HSEL_S9 => HSEL_S9,
	HADDR_S9 => HADDR_S9,
	HSIZE_S9 => HSIZE_S9,
	HTRANS_S9 => HTRANS_S9,
	HWRITE_S9 => HWRITE_S9,
	HWDATA_S9 => HWDATA_S9,
	HREADY_S9 => HREADYIN_S9,
	HMASTLOCK_S9 => HMASTLOCK_S9,
	HBURST_S9 => HBURST_S9,
	HPROT_S9 => HPROT_S9,

	-- Mirrored slave AHB-Lite interface to Slave 10
	-- Inputs
	HRDATA_S10 => HRDATA_S10,
	HREADYOUT_S10 => HREADY_S10,
	HRESP_S10 => HRESP_S10,
	-- Output
	HSEL_S10 => HSEL_S10,
	HADDR_S10 => HADDR_S10,
	HSIZE_S10 => HSIZE_S10,
	HTRANS_S10 => HTRANS_S10,
	HWRITE_S10 => HWRITE_S10,
	HWDATA_S10 => HWDATA_S10,
	HREADY_S10 => HREADYIN_S10,
	HMASTLOCK_S10 => HMASTLOCK_S10,
	HBURST_S10 => HBURST_S10,
	HPROT_S10 => HPROT_S10,

	-- Mirrored slave AHB-Lite interface to Slave 11
	-- Inputs
	HRDATA_S11 => HRDATA_S11,
	HREADYOUT_S11 => HREADY_S11,
	HRESP_S11 => HRESP_S11,
	-- Output
	HSEL_S11 => HSEL_S11,
	HADDR_S11 => HADDR_S11,
	HSIZE_S11 => HSIZE_S11,
	HTRANS_S11 => HTRANS_S11,
	HWRITE_S11 => HWRITE_S11,
	HWDATA_S11 => HWDATA_S11,
	HREADY_S11 => HREADYIN_S11,
	HMASTLOCK_S11 => HMASTLOCK_S11,
	HBURST_S11 => HBURST_S11,
	HPROT_S11 => HPROT_S11,

	-- Mirrored slave AHB-Lite interface to Slave 12
	-- Inputs
	HRDATA_S12 => HRDATA_S12,
	HREADYOUT_S12 => HREADY_S12,
	HRESP_S12 => HRESP_S12,
	-- Output
	HSEL_S12 => HSEL_S12,
	HADDR_S12 => HADDR_S12,
	HSIZE_S12 => HSIZE_S12,
	HTRANS_S12 => HTRANS_S12,
	HWRITE_S12 => HWRITE_S12,
	HWDATA_S12 => HWDATA_S12,
	HREADY_S12 => HREADYIN_S12,
	HMASTLOCK_S12 => HMASTLOCK_S12,
	HBURST_S12 => HBURST_S12,
	HPROT_S12 => HPROT_S12,

	-- Mirrored slave AHB-Lite interface to Slave 13
	-- Inputs
	HRDATA_S13 => HRDATA_S13,
	HREADYOUT_S13 => HREADY_S13,
	HRESP_S13 => HRESP_S13,
	-- Output
	HSEL_S13 => HSEL_S13,
	HADDR_S13 => HADDR_S13,
	HSIZE_S13 => HSIZE_S13,
	HTRANS_S13 => HTRANS_S13,
	HWRITE_S13 => HWRITE_S13,
	HWDATA_S13 => HWDATA_S13,
	HREADY_S13 => HREADYIN_S13,
	HMASTLOCK_S13 => HMASTLOCK_S13,
	HBURST_S13 => HBURST_S13,
	HPROT_S13 => HPROT_S13,

	-- Mirrored slave AHB-Lite interface to Slave 14
	-- Inputs
	HRDATA_S14 => HRDATA_S14,
	HREADYOUT_S14 => HREADY_S14,
	HRESP_S14 => HRESP_S14,
	-- Output
	HSEL_S14 => HSEL_S14,
	HADDR_S14 => HADDR_S14,
	HSIZE_S14 => HSIZE_S14,
	HTRANS_S14 => HTRANS_S14,
	HWRITE_S14 => HWRITE_S14,
	HWDATA_S14 => HWDATA_S14,
	HREADY_S14 => HREADYIN_S14,
	HMASTLOCK_S14 => HMASTLOCK_S14,
	HBURST_S14 => HBURST_S14,
	HPROT_S14 => HPROT_S14,

	-- Mirrored slave AHB-Lite interface to Slave 15
	-- Inputs
	HRDATA_S15 => HRDATA_S15,
	HREADYOUT_S15 => HREADY_S15,
	HRESP_S15 => HRESP_S15,
	-- Output
	HSEL_S15 => HSEL_S15,
	HADDR_S15 => HADDR_S15,
	HSIZE_S15 => HSIZE_S15,
	HTRANS_S15 => HTRANS_S15,
	HWRITE_S15 => HWRITE_S15,
	HWDATA_S15 => HWDATA_S15,
	HREADY_S15 => HREADYIN_S15,
	HMASTLOCK_S15 => HMASTLOCK_S15,
	HBURST_S15 => HBURST_S15,
	HPROT_S15 => HPROT_S15,

	-- Mirrored slave AHB-Lite interface to Huge Slave
	-- Inputs
	HRDATA_S16 => HRDATA_S16,
	HREADYOUT_S16 => HREADY_S16,
	HRESP_S16 => HRESP_S16,
	-- Outputs
	HSEL_S16 => HSEL_S16,
	HADDR_S16 => HADDR_S16,
	HSIZE_S16 => HSIZE_S16,
	HTRANS_S16 => HTRANS_S16,
	HWRITE_S16 => HWRITE_S16,
	HWDATA_S16 => HWDATA_S16,
	HREADY_S16 => HREADYIN_S16,
	HMASTLOCK_S16 => HMASTLOCK_S16,
	HBURST_S16 => HBURST_S16,
	HPROT_S16 => HPROT_S16
);

-- BFM masters monitor various signals
GP_IN <=
	REMAP_M0 &           -- 31
	M1_ACK &             -- 30
	M1_REQ &             -- 29
	M0_ACK &             -- 28
	M0_REQ &             -- 27
    FINISHED_master3 &   -- 26
    FINISHED_master2 &   -- 25
    FINISHED_master1 &   -- 24
    FINISHED_master0 &   -- 23
	"000000" &           -- 22:17
    s16_write &          -- 16
    s15_write &          -- 15
    s14_write &          -- 14
    s13_write &          -- 13
    s12_write &          -- 12
    s11_write &          -- 11
    s10_write &          -- 10
    s9_write &           --  9
    s8_write &           --  8
    s7_write &           --  7
    s6_write &           --  6
    s5_write &           --  5
    s4_write &           --  4
    s3_write &           --  3
    s2_write &           --  2
    s1_write &           --  1
    s0_write;            --  0


-- Master 0 BFM
master0 : BFM_AHBL
generic map (
	VECTFILE    => MASTER0_VECTFILE,
	-- passing testbench parameters to BFM ARGVALUE* parameters
	ARGVALUE0   => FAMILY,
	ARGVALUE1   => MEMSPACE,
	ARGVALUE2   => HADDR_SHG_CFG,
	ARGVALUE3   => SC_0 ,
	ARGVALUE4   => SC_1 ,
	ARGVALUE5   => SC_2 ,
	ARGVALUE6   => SC_3 ,
	ARGVALUE7   => SC_4 ,
	ARGVALUE8   => SC_5 ,
	ARGVALUE9   => SC_6 ,
	ARGVALUE10  => SC_7 ,
	ARGVALUE11  => SC_8 ,
	ARGVALUE12  => SC_9 ,
	ARGVALUE13  => SC_10,
	ARGVALUE14  => SC_11,
	ARGVALUE15  => SC_12,
	ARGVALUE16  => SC_13,
	ARGVALUE17  => SC_14,
	ARGVALUE18  => SC_15,
	ARGVALUE19  => M0_AHBSLOT0ENABLE ,
	ARGVALUE20  => M0_AHBSLOT1ENABLE ,
	ARGVALUE21  => M0_AHBSLOT2ENABLE ,
	ARGVALUE22  => M0_AHBSLOT3ENABLE ,
	ARGVALUE23  => M0_AHBSLOT4ENABLE ,
	ARGVALUE24  => M0_AHBSLOT5ENABLE ,
	ARGVALUE25  => M0_AHBSLOT6ENABLE ,
	ARGVALUE26  => M0_AHBSLOT7ENABLE ,
	ARGVALUE27  => M0_AHBSLOT8ENABLE ,
	ARGVALUE28  => M0_AHBSLOT9ENABLE ,
	ARGVALUE29  => M0_AHBSLOT10ENABLE,
	ARGVALUE30  => M0_AHBSLOT11ENABLE,
	ARGVALUE31  => M0_AHBSLOT12ENABLE,
	ARGVALUE32  => M0_AHBSLOT13ENABLE,
	ARGVALUE33  => M0_AHBSLOT14ENABLE,
	ARGVALUE34  => M0_AHBSLOT15ENABLE,
	ARGVALUE35  => M0_AHBSLOT16ENABLE,
	ARGVALUE36  => M1_AHBSLOT0ENABLE ,
	ARGVALUE37  => M1_AHBSLOT1ENABLE ,
	ARGVALUE38  => M1_AHBSLOT2ENABLE ,
	ARGVALUE39  => M1_AHBSLOT3ENABLE ,
	ARGVALUE40  => M1_AHBSLOT4ENABLE ,
	ARGVALUE41  => M1_AHBSLOT5ENABLE ,
	ARGVALUE42  => M1_AHBSLOT6ENABLE ,
	ARGVALUE43  => M1_AHBSLOT7ENABLE ,
	ARGVALUE44  => M1_AHBSLOT8ENABLE ,
	ARGVALUE45  => M1_AHBSLOT9ENABLE ,
	ARGVALUE46  => M1_AHBSLOT10ENABLE,
	ARGVALUE47  => M1_AHBSLOT11ENABLE,
	ARGVALUE48  => M1_AHBSLOT12ENABLE,
	ARGVALUE49  => M1_AHBSLOT13ENABLE,
	ARGVALUE50  => M1_AHBSLOT14ENABLE,
	ARGVALUE51  => M1_AHBSLOT15ENABLE,
	ARGVALUE52  => M1_AHBSLOT16ENABLE,
	ARGVALUE53  => M2_AHBSLOT0ENABLE ,
	ARGVALUE54  => M2_AHBSLOT1ENABLE ,
	ARGVALUE55  => M2_AHBSLOT2ENABLE ,
	ARGVALUE56  => M2_AHBSLOT3ENABLE ,
	ARGVALUE57  => M2_AHBSLOT4ENABLE ,
	ARGVALUE58  => M2_AHBSLOT5ENABLE ,
	ARGVALUE59  => M2_AHBSLOT6ENABLE ,
	ARGVALUE60  => M2_AHBSLOT7ENABLE ,
	ARGVALUE61  => M2_AHBSLOT8ENABLE ,
	ARGVALUE62  => M2_AHBSLOT9ENABLE ,
	ARGVALUE63  => M2_AHBSLOT10ENABLE,
	ARGVALUE64  => M2_AHBSLOT11ENABLE,
	ARGVALUE65  => M2_AHBSLOT12ENABLE,
	ARGVALUE66  => M2_AHBSLOT13ENABLE,
	ARGVALUE67  => M2_AHBSLOT14ENABLE,
	ARGVALUE68  => M2_AHBSLOT15ENABLE,
	ARGVALUE69  => M2_AHBSLOT16ENABLE,
	ARGVALUE70  => M3_AHBSLOT0ENABLE ,
	ARGVALUE71  => M3_AHBSLOT1ENABLE ,
	ARGVALUE72  => M3_AHBSLOT2ENABLE ,
	ARGVALUE73  => M3_AHBSLOT3ENABLE ,
	ARGVALUE74  => M3_AHBSLOT4ENABLE ,
	ARGVALUE75  => M3_AHBSLOT5ENABLE ,
	ARGVALUE76  => M3_AHBSLOT6ENABLE ,
	ARGVALUE77  => M3_AHBSLOT7ENABLE ,
	ARGVALUE78  => M3_AHBSLOT8ENABLE ,
	ARGVALUE79  => M3_AHBSLOT9ENABLE ,
	ARGVALUE80  => M3_AHBSLOT10ENABLE,
	ARGVALUE81  => M3_AHBSLOT11ENABLE,
	ARGVALUE82  => M3_AHBSLOT12ENABLE,
	ARGVALUE83  => M3_AHBSLOT13ENABLE,
	ARGVALUE84  => M3_AHBSLOT14ENABLE,
	ARGVALUE85  => M3_AHBSLOT15ENABLE,
	ARGVALUE86  => M3_AHBSLOT16ENABLE
) port map (
	-- Inputs
	SYSCLK		=> SYSCLK,
	SYSRSTN		=> SYSRSTN,
	HREADY		=> HREADY_M0,
	HRESP		=> HRESP_M0(0),
	HRDATA		=> HRDATA_M0,
	-- Outputs
	HCLK		=> HCLK,
	HRESETN		=> HRESETN,
	HTRANS		=> HTRANS_M0,
	HBURST		=> open,
	HSEL		=> open,
	HPROT		=> open,
	HSIZE		=> HSIZE_M0,
	HWRITE		=> HWRITE_M0,
	HMASTLOCK	=> HMASTLOCK_M0,
	HADDR		=> HADDR_M0,
	HWDATA		=> HWDATA_M0,
	INTERRUPT	=> GND256,
	GP_OUT		=> GP_OUT_M0,
	GP_IN		=> GP_IN,
	EXT_WR		=> open,
	EXT_RD		=> open,
	EXT_ADDR	=> open,
	EXT_DATA	=> open,
	EXT_WAIT	=> '0',
	FINISHED	=> FINISHED_master0,
	FAILED		=> open
);

-- control remap signals from master 0 BFM
REMAP_M0	<= GP_OUT_M0(31);

-- signals for testbench request/acknowledgement between masters
M0_REQ		<= GP_OUT_M0(27);
M0_ACK		<= GP_OUT_M0(28);


-- Master 1 BFM
master1 : BFM_AHBL
generic map (
	VECTFILE    => MASTER1_VECTFILE,
	-- passing testbench parameters to BFM ARGVALUE* parameters
	ARGVALUE0   => FAMILY,
	ARGVALUE1   => MEMSPACE,
	ARGVALUE2   => HADDR_SHG_CFG,
	ARGVALUE3   => SC_0 ,
	ARGVALUE4   => SC_1 ,
	ARGVALUE5   => SC_2 ,
	ARGVALUE6   => SC_3 ,
	ARGVALUE7   => SC_4 ,
	ARGVALUE8   => SC_5 ,
	ARGVALUE9   => SC_6 ,
	ARGVALUE10  => SC_7 ,
	ARGVALUE11  => SC_8 ,
	ARGVALUE12  => SC_9 ,
	ARGVALUE13  => SC_10,
	ARGVALUE14  => SC_11,
	ARGVALUE15  => SC_12,
	ARGVALUE16  => SC_13,
	ARGVALUE17  => SC_14,
	ARGVALUE18  => SC_15,
	ARGVALUE19  => M0_AHBSLOT0ENABLE ,
	ARGVALUE20  => M0_AHBSLOT1ENABLE ,
	ARGVALUE21  => M0_AHBSLOT2ENABLE ,
	ARGVALUE22  => M0_AHBSLOT3ENABLE ,
	ARGVALUE23  => M0_AHBSLOT4ENABLE ,
	ARGVALUE24  => M0_AHBSLOT5ENABLE ,
	ARGVALUE25  => M0_AHBSLOT6ENABLE ,
	ARGVALUE26  => M0_AHBSLOT7ENABLE ,
	ARGVALUE27  => M0_AHBSLOT8ENABLE ,
	ARGVALUE28  => M0_AHBSLOT9ENABLE ,
	ARGVALUE29  => M0_AHBSLOT10ENABLE,
	ARGVALUE30  => M0_AHBSLOT11ENABLE,
	ARGVALUE31  => M0_AHBSLOT12ENABLE,
	ARGVALUE32  => M0_AHBSLOT13ENABLE,
	ARGVALUE33  => M0_AHBSLOT14ENABLE,
	ARGVALUE34  => M0_AHBSLOT15ENABLE,
	ARGVALUE35  => M0_AHBSLOT16ENABLE,
	ARGVALUE36  => M1_AHBSLOT0ENABLE ,
	ARGVALUE37  => M1_AHBSLOT1ENABLE ,
	ARGVALUE38  => M1_AHBSLOT2ENABLE ,
	ARGVALUE39  => M1_AHBSLOT3ENABLE ,
	ARGVALUE40  => M1_AHBSLOT4ENABLE ,
	ARGVALUE41  => M1_AHBSLOT5ENABLE ,
	ARGVALUE42  => M1_AHBSLOT6ENABLE ,
	ARGVALUE43  => M1_AHBSLOT7ENABLE ,
	ARGVALUE44  => M1_AHBSLOT8ENABLE ,
	ARGVALUE45  => M1_AHBSLOT9ENABLE ,
	ARGVALUE46  => M1_AHBSLOT10ENABLE,
	ARGVALUE47  => M1_AHBSLOT11ENABLE,
	ARGVALUE48  => M1_AHBSLOT12ENABLE,
	ARGVALUE49  => M1_AHBSLOT13ENABLE,
	ARGVALUE50  => M1_AHBSLOT14ENABLE,
	ARGVALUE51  => M1_AHBSLOT15ENABLE,
	ARGVALUE52  => M1_AHBSLOT16ENABLE,
	ARGVALUE53  => M2_AHBSLOT0ENABLE ,
	ARGVALUE54  => M2_AHBSLOT1ENABLE ,
	ARGVALUE55  => M2_AHBSLOT2ENABLE ,
	ARGVALUE56  => M2_AHBSLOT3ENABLE ,
	ARGVALUE57  => M2_AHBSLOT4ENABLE ,
	ARGVALUE58  => M2_AHBSLOT5ENABLE ,
	ARGVALUE59  => M2_AHBSLOT6ENABLE ,
	ARGVALUE60  => M2_AHBSLOT7ENABLE ,
	ARGVALUE61  => M2_AHBSLOT8ENABLE ,
	ARGVALUE62  => M2_AHBSLOT9ENABLE ,
	ARGVALUE63  => M2_AHBSLOT10ENABLE,
	ARGVALUE64  => M2_AHBSLOT11ENABLE,
	ARGVALUE65  => M2_AHBSLOT12ENABLE,
	ARGVALUE66  => M2_AHBSLOT13ENABLE,
	ARGVALUE67  => M2_AHBSLOT14ENABLE,
	ARGVALUE68  => M2_AHBSLOT15ENABLE,
	ARGVALUE69  => M2_AHBSLOT16ENABLE,
	ARGVALUE70  => M3_AHBSLOT0ENABLE ,
	ARGVALUE71  => M3_AHBSLOT1ENABLE ,
	ARGVALUE72  => M3_AHBSLOT2ENABLE ,
	ARGVALUE73  => M3_AHBSLOT3ENABLE ,
	ARGVALUE74  => M3_AHBSLOT4ENABLE ,
	ARGVALUE75  => M3_AHBSLOT5ENABLE ,
	ARGVALUE76  => M3_AHBSLOT6ENABLE ,
	ARGVALUE77  => M3_AHBSLOT7ENABLE ,
	ARGVALUE78  => M3_AHBSLOT8ENABLE ,
	ARGVALUE79  => M3_AHBSLOT9ENABLE ,
	ARGVALUE80  => M3_AHBSLOT10ENABLE,
	ARGVALUE81  => M3_AHBSLOT11ENABLE,
	ARGVALUE82  => M3_AHBSLOT12ENABLE,
	ARGVALUE83  => M3_AHBSLOT13ENABLE,
	ARGVALUE84  => M3_AHBSLOT14ENABLE,
	ARGVALUE85  => M3_AHBSLOT15ENABLE,
	ARGVALUE86  => M3_AHBSLOT16ENABLE
) port map (
	-- Inputs
	SYSCLK	=> SYSCLK,
	SYSRSTN	=> SYSRSTN,
	HREADY	=> HREADY_M1,
	HRESP	=> HRESP_M1(0),
	HRDATA	=> HRDATA_M1,
	-- Outputs
	-- using master 0 HCLK,HRESETN to drive slaves & DUT
	HCLK		=> open,
	HRESETN		=> open,
	HTRANS		=> HTRANS_M1,
	HBURST		=> open,
	HSEL		=> open,
	HPROT		=> open,
	HSIZE		=> HSIZE_M1,
	HWRITE		=> HWRITE_M1,
	HMASTLOCK	=> HMASTLOCK_M1,
	HADDR		=> HADDR_M1,
	HWDATA		=> HWDATA_M1,
	INTERRUPT	=> GND256,
	GP_OUT		=> GP_OUT_M1,
	GP_IN		=> GP_IN,
	EXT_WR		=> open,
	EXT_RD		=> open,
	EXT_ADDR	=> open,
	EXT_DATA	=> open,
	EXT_WAIT	=> '0',
	FINISHED	=> FINISHED_master1,
	FAILED		=> open
);

-- signals for testbench request/acknowledgement between masters
M1_REQ			<= GP_OUT_M1(29);
M1_ACK			<= GP_OUT_M1(30);


-- Master 2 BFM
master2 : BFM_AHBL
generic map (
	VECTFILE    => MASTER2_VECTFILE,
	-- passing testbench parameters to BFM ARGVALUE* parameters
	ARGVALUE0   => FAMILY,
	ARGVALUE1   => MEMSPACE,
	ARGVALUE2   => HADDR_SHG_CFG,
	ARGVALUE3   => SC_0 ,
	ARGVALUE4   => SC_1 ,
	ARGVALUE5   => SC_2 ,
	ARGVALUE6   => SC_3 ,
	ARGVALUE7   => SC_4 ,
	ARGVALUE8   => SC_5 ,
	ARGVALUE9   => SC_6 ,
	ARGVALUE10  => SC_7 ,
	ARGVALUE11  => SC_8 ,
	ARGVALUE12  => SC_9 ,
	ARGVALUE13  => SC_10,
	ARGVALUE14  => SC_11,
	ARGVALUE15  => SC_12,
	ARGVALUE16  => SC_13,
	ARGVALUE17  => SC_14,
	ARGVALUE18  => SC_15,
	ARGVALUE19  => M0_AHBSLOT0ENABLE ,
	ARGVALUE20  => M0_AHBSLOT1ENABLE ,
	ARGVALUE21  => M0_AHBSLOT2ENABLE ,
	ARGVALUE22  => M0_AHBSLOT3ENABLE ,
	ARGVALUE23  => M0_AHBSLOT4ENABLE ,
	ARGVALUE24  => M0_AHBSLOT5ENABLE ,
	ARGVALUE25  => M0_AHBSLOT6ENABLE ,
	ARGVALUE26  => M0_AHBSLOT7ENABLE ,
	ARGVALUE27  => M0_AHBSLOT8ENABLE ,
	ARGVALUE28  => M0_AHBSLOT9ENABLE ,
	ARGVALUE29  => M0_AHBSLOT10ENABLE,
	ARGVALUE30  => M0_AHBSLOT11ENABLE,
	ARGVALUE31  => M0_AHBSLOT12ENABLE,
	ARGVALUE32  => M0_AHBSLOT13ENABLE,
	ARGVALUE33  => M0_AHBSLOT14ENABLE,
	ARGVALUE34  => M0_AHBSLOT15ENABLE,
	ARGVALUE35  => M0_AHBSLOT16ENABLE,
	ARGVALUE36  => M1_AHBSLOT0ENABLE ,
	ARGVALUE37  => M1_AHBSLOT1ENABLE ,
	ARGVALUE38  => M1_AHBSLOT2ENABLE ,
	ARGVALUE39  => M1_AHBSLOT3ENABLE ,
	ARGVALUE40  => M1_AHBSLOT4ENABLE ,
	ARGVALUE41  => M1_AHBSLOT5ENABLE ,
	ARGVALUE42  => M1_AHBSLOT6ENABLE ,
	ARGVALUE43  => M1_AHBSLOT7ENABLE ,
	ARGVALUE44  => M1_AHBSLOT8ENABLE ,
	ARGVALUE45  => M1_AHBSLOT9ENABLE ,
	ARGVALUE46  => M1_AHBSLOT10ENABLE,
	ARGVALUE47  => M1_AHBSLOT11ENABLE,
	ARGVALUE48  => M1_AHBSLOT12ENABLE,
	ARGVALUE49  => M1_AHBSLOT13ENABLE,
	ARGVALUE50  => M1_AHBSLOT14ENABLE,
	ARGVALUE51  => M1_AHBSLOT15ENABLE,
	ARGVALUE52  => M1_AHBSLOT16ENABLE,
	ARGVALUE53  => M2_AHBSLOT0ENABLE ,
	ARGVALUE54  => M2_AHBSLOT1ENABLE ,
	ARGVALUE55  => M2_AHBSLOT2ENABLE ,
	ARGVALUE56  => M2_AHBSLOT3ENABLE ,
	ARGVALUE57  => M2_AHBSLOT4ENABLE ,
	ARGVALUE58  => M2_AHBSLOT5ENABLE ,
	ARGVALUE59  => M2_AHBSLOT6ENABLE ,
	ARGVALUE60  => M2_AHBSLOT7ENABLE ,
	ARGVALUE61  => M2_AHBSLOT8ENABLE ,
	ARGVALUE62  => M2_AHBSLOT9ENABLE ,
	ARGVALUE63  => M2_AHBSLOT10ENABLE,
	ARGVALUE64  => M2_AHBSLOT11ENABLE,
	ARGVALUE65  => M2_AHBSLOT12ENABLE,
	ARGVALUE66  => M2_AHBSLOT13ENABLE,
	ARGVALUE67  => M2_AHBSLOT14ENABLE,
	ARGVALUE68  => M2_AHBSLOT15ENABLE,
	ARGVALUE69  => M2_AHBSLOT16ENABLE,
	ARGVALUE70  => M3_AHBSLOT0ENABLE ,
	ARGVALUE71  => M3_AHBSLOT1ENABLE ,
	ARGVALUE72  => M3_AHBSLOT2ENABLE ,
	ARGVALUE73  => M3_AHBSLOT3ENABLE ,
	ARGVALUE74  => M3_AHBSLOT4ENABLE ,
	ARGVALUE75  => M3_AHBSLOT5ENABLE ,
	ARGVALUE76  => M3_AHBSLOT6ENABLE ,
	ARGVALUE77  => M3_AHBSLOT7ENABLE ,
	ARGVALUE78  => M3_AHBSLOT8ENABLE ,
	ARGVALUE79  => M3_AHBSLOT9ENABLE ,
	ARGVALUE80  => M3_AHBSLOT10ENABLE,
	ARGVALUE81  => M3_AHBSLOT11ENABLE,
	ARGVALUE82  => M3_AHBSLOT12ENABLE,
	ARGVALUE83  => M3_AHBSLOT13ENABLE,
	ARGVALUE84  => M3_AHBSLOT14ENABLE,
	ARGVALUE85  => M3_AHBSLOT15ENABLE,
	ARGVALUE86  => M3_AHBSLOT16ENABLE
) port map (
	-- Inputs
	SYSCLK	=> SYSCLK,
	SYSRSTN	=> SYSRSTN,
	HREADY	=> HREADY_M2,
	HRESP	=> HRESP_M2(0),
	HRDATA	=> HRDATA_M2,
	-- Outputs
	-- using master 0 HCLK,HRESETN to drive slaves & DUT
	HCLK		=> open,
	HRESETN		=> open,
	HTRANS		=> HTRANS_M2,
	HBURST		=> open,
	HSEL		=> open,
	HPROT		=> open,
	HSIZE		=> HSIZE_M2,
	HWRITE		=> HWRITE_M2,
	HMASTLOCK	=> HMASTLOCK_M2,
	HADDR		=> HADDR_M2,
	HWDATA		=> HWDATA_M2,
	INTERRUPT	=> GND256,
	GP_OUT		=> open,
	GP_IN		=> GP_IN,
	EXT_WR		=> open,
	EXT_RD		=> open,
	EXT_ADDR	=> open,
	EXT_DATA	=> open,
	EXT_WAIT	=> '0',
	FINISHED	=> FINISHED_master2,
	FAILED		=> open
);

-- Master 3 BFM
master3 : BFM_AHBL
generic map (
	VECTFILE    => MASTER3_VECTFILE,
	-- passing testbench parameters to BFM ARGVALUE* parameters
	ARGVALUE0   => FAMILY,
	ARGVALUE1   => MEMSPACE,
	ARGVALUE2   => HADDR_SHG_CFG,
	ARGVALUE3   => SC_0 ,
	ARGVALUE4   => SC_1 ,
	ARGVALUE5   => SC_2 ,
	ARGVALUE6   => SC_3 ,
	ARGVALUE7   => SC_4 ,
	ARGVALUE8   => SC_5 ,
	ARGVALUE9   => SC_6 ,
	ARGVALUE10  => SC_7 ,
	ARGVALUE11  => SC_8 ,
	ARGVALUE12  => SC_9 ,
	ARGVALUE13  => SC_10,
	ARGVALUE14  => SC_11,
	ARGVALUE15  => SC_12,
	ARGVALUE16  => SC_13,
	ARGVALUE17  => SC_14,
	ARGVALUE18  => SC_15,
	ARGVALUE19  => M0_AHBSLOT0ENABLE ,
	ARGVALUE20  => M0_AHBSLOT1ENABLE ,
	ARGVALUE21  => M0_AHBSLOT2ENABLE ,
	ARGVALUE22  => M0_AHBSLOT3ENABLE ,
	ARGVALUE23  => M0_AHBSLOT4ENABLE ,
	ARGVALUE24  => M0_AHBSLOT5ENABLE ,
	ARGVALUE25  => M0_AHBSLOT6ENABLE ,
	ARGVALUE26  => M0_AHBSLOT7ENABLE ,
	ARGVALUE27  => M0_AHBSLOT8ENABLE ,
	ARGVALUE28  => M0_AHBSLOT9ENABLE ,
	ARGVALUE29  => M0_AHBSLOT10ENABLE,
	ARGVALUE30  => M0_AHBSLOT11ENABLE,
	ARGVALUE31  => M0_AHBSLOT12ENABLE,
	ARGVALUE32  => M0_AHBSLOT13ENABLE,
	ARGVALUE33  => M0_AHBSLOT14ENABLE,
	ARGVALUE34  => M0_AHBSLOT15ENABLE,
	ARGVALUE35  => M0_AHBSLOT16ENABLE,
	ARGVALUE36  => M1_AHBSLOT0ENABLE ,
	ARGVALUE37  => M1_AHBSLOT1ENABLE ,
	ARGVALUE38  => M1_AHBSLOT2ENABLE ,
	ARGVALUE39  => M1_AHBSLOT3ENABLE ,
	ARGVALUE40  => M1_AHBSLOT4ENABLE ,
	ARGVALUE41  => M1_AHBSLOT5ENABLE ,
	ARGVALUE42  => M1_AHBSLOT6ENABLE ,
	ARGVALUE43  => M1_AHBSLOT7ENABLE ,
	ARGVALUE44  => M1_AHBSLOT8ENABLE ,
	ARGVALUE45  => M1_AHBSLOT9ENABLE ,
	ARGVALUE46  => M1_AHBSLOT10ENABLE,
	ARGVALUE47  => M1_AHBSLOT11ENABLE,
	ARGVALUE48  => M1_AHBSLOT12ENABLE,
	ARGVALUE49  => M1_AHBSLOT13ENABLE,
	ARGVALUE50  => M1_AHBSLOT14ENABLE,
	ARGVALUE51  => M1_AHBSLOT15ENABLE,
	ARGVALUE52  => M1_AHBSLOT16ENABLE,
	ARGVALUE53  => M2_AHBSLOT0ENABLE ,
	ARGVALUE54  => M2_AHBSLOT1ENABLE ,
	ARGVALUE55  => M2_AHBSLOT2ENABLE ,
	ARGVALUE56  => M2_AHBSLOT3ENABLE ,
	ARGVALUE57  => M2_AHBSLOT4ENABLE ,
	ARGVALUE58  => M2_AHBSLOT5ENABLE ,
	ARGVALUE59  => M2_AHBSLOT6ENABLE ,
	ARGVALUE60  => M2_AHBSLOT7ENABLE ,
	ARGVALUE61  => M2_AHBSLOT8ENABLE ,
	ARGVALUE62  => M2_AHBSLOT9ENABLE ,
	ARGVALUE63  => M2_AHBSLOT10ENABLE,
	ARGVALUE64  => M2_AHBSLOT11ENABLE,
	ARGVALUE65  => M2_AHBSLOT12ENABLE,
	ARGVALUE66  => M2_AHBSLOT13ENABLE,
	ARGVALUE67  => M2_AHBSLOT14ENABLE,
	ARGVALUE68  => M2_AHBSLOT15ENABLE,
	ARGVALUE69  => M2_AHBSLOT16ENABLE,
	ARGVALUE70  => M3_AHBSLOT0ENABLE ,
	ARGVALUE71  => M3_AHBSLOT1ENABLE ,
	ARGVALUE72  => M3_AHBSLOT2ENABLE ,
	ARGVALUE73  => M3_AHBSLOT3ENABLE ,
	ARGVALUE74  => M3_AHBSLOT4ENABLE ,
	ARGVALUE75  => M3_AHBSLOT5ENABLE ,
	ARGVALUE76  => M3_AHBSLOT6ENABLE ,
	ARGVALUE77  => M3_AHBSLOT7ENABLE ,
	ARGVALUE78  => M3_AHBSLOT8ENABLE ,
	ARGVALUE79  => M3_AHBSLOT9ENABLE ,
	ARGVALUE80  => M3_AHBSLOT10ENABLE,
	ARGVALUE81  => M3_AHBSLOT11ENABLE,
	ARGVALUE82  => M3_AHBSLOT12ENABLE,
	ARGVALUE83  => M3_AHBSLOT13ENABLE,
	ARGVALUE84  => M3_AHBSLOT14ENABLE,
	ARGVALUE85  => M3_AHBSLOT15ENABLE,
	ARGVALUE86  => M3_AHBSLOT16ENABLE
) port map (
	-- Inputs
	SYSCLK	=> SYSCLK,
	SYSRSTN	=> SYSRSTN,
	HREADY	=> HREADY_M3,
	HRESP	=> HRESP_M3(0),
	HRDATA	=> HRDATA_M3,
	-- Outputs
	-- using master 0 HCLK,HRESETN to drive slaves & DUT
	HCLK		=> open,
	HRESETN		=> open,
	HTRANS		=> HTRANS_M3,
	HBURST		=> open,
	HSEL		=> open,
	HPROT		=> open,
	HSIZE		=> HSIZE_M3,
	HWRITE		=> HWRITE_M3,
	HMASTLOCK	=> HMASTLOCK_M3,
	HADDR		=> HADDR_M3,
	HWDATA		=> HWDATA_M3,
	INTERRUPT	=> GND256,
	GP_OUT		=> open,
	GP_IN		=> GP_IN,
	EXT_WR		=> open,
	EXT_RD		=> open,
	EXT_ADDR	=> open,
	EXT_DATA	=> open,
	EXT_WAIT	=> '0',
	FINISHED	=> FINISHED_master3,
	FAILED		=> open
);


   slave0 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S0,
         hsize      => HSIZE_S0,
         htrans     => HTRANS_S0,
         hwdata     => HWDATA_S0,
         hreadyin   => HREADYIN_S0,
         hsel       => HSEL_S0,
         haddr      => HADDR_S0(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S0,
         hprot      => HPROT_S0,
         -- Output
         hrdata     => HRDATA_S0,
         hresp      => HRESP_S0(0),
         hreadyout  => HREADY_S0
      );



   slave1 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S1,
         hsize      => HSIZE_S1,
         htrans     => HTRANS_S1,
         hwdata     => HWDATA_S1,
         hreadyin   => HREADYIN_S1,
         hsel       => HSEL_S1,
         haddr      => HADDR_S1(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S1,
         hprot      => HPROT_S1,
         -- Output
         hrdata     => HRDATA_S1,
         hresp      => HRESP_S1(0),
         hreadyout  => HREADY_S1
      );



   slave2 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S2,
         hsize      => HSIZE_S2,
         htrans     => HTRANS_S2,
         hwdata     => HWDATA_S2,
         hreadyin   => HREADYIN_S2,
         hsel       => HSEL_S2,
         haddr      => HADDR_S2(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S2,
         hprot      => HPROT_S2,
         -- Output
         hrdata     => HRDATA_S2,
         hresp      => HRESP_S2(0),
         hreadyout  => HREADY_S2
      );



   slave3 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S3,
         hsize      => HSIZE_S3,
         htrans     => HTRANS_S3,
         hwdata     => HWDATA_S3,
         hreadyin   => HREADYIN_S3,
         hsel       => HSEL_S3,
         haddr      => HADDR_S3(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S3,
         hprot      => HPROT_S3,
         -- Output
         hrdata     => HRDATA_S3,
         hresp      => HRESP_S3(0),
         hreadyout  => HREADY_S3
      );



   slave4 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S4,
         hsize      => HSIZE_S4,
         htrans     => HTRANS_S4,
         hwdata     => HWDATA_S4,
         hreadyin   => HREADYIN_S4,
         hsel       => HSEL_S4,
         haddr      => HADDR_S4(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S4,
         hprot      => HPROT_S4,
         -- Output
         hrdata     => HRDATA_S4,
         hresp      => HRESP_S4(0),
         hreadyout  => HREADY_S4
      );



   slave5 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S5,
         hsize      => HSIZE_S5,
         htrans     => HTRANS_S5,
         hwdata     => HWDATA_S5,
         hreadyin   => HREADYIN_S5,
         hsel       => HSEL_S5,
         haddr      => HADDR_S5(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S5,
         hprot      => HPROT_S5,
         -- Output
         hrdata     => HRDATA_S5,
         hresp      => HRESP_S5(0),
         hreadyout  => HREADY_S5
      );



   slave6 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S6,
         hsize      => HSIZE_S6,
         htrans     => HTRANS_S6,
         hwdata     => HWDATA_S6,
         hreadyin   => HREADYIN_S6,
         hsel       => HSEL_S6,
         haddr      => HADDR_S6(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S6,
         hprot      => HPROT_S6,
         -- Output
         hrdata     => HRDATA_S6,
         hresp      => HRESP_S6(0),
         hreadyout  => HREADY_S6
      );



   slave7 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S7,
         hsize      => HSIZE_S7,
         htrans     => HTRANS_S7,
         hwdata     => HWDATA_S7,
         hreadyin   => HREADYIN_S7,
         hsel       => HSEL_S7,
         haddr      => HADDR_S7(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S7,
         hprot      => HPROT_S7,
         -- Output
         hrdata     => HRDATA_S7,
         hresp      => HRESP_S7(0),
         hreadyout  => HREADY_S7
      );



   slave8 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S8,
         hsize      => HSIZE_S8,
         htrans     => HTRANS_S8,
         hwdata     => HWDATA_S8,
         hreadyin   => HREADYIN_S8,
         hsel       => HSEL_S8,
         haddr      => HADDR_S8(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S8,
         hprot      => HPROT_S8,
         -- Output
         hrdata     => HRDATA_S8,
         hresp      => HRESP_S8(0),
         hreadyout  => HREADY_S8
      );



   slave9 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S9,
         hsize      => HSIZE_S9,
         htrans     => HTRANS_S9,
         hwdata     => HWDATA_S9,
         hreadyin   => HREADYIN_S9,
         hsel       => HSEL_S9,
         haddr      => HADDR_S9(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S9,
         hprot      => HPROT_S9,
         -- Output
         hrdata     => HRDATA_S9,
         hresp      => HRESP_S9(0),
         hreadyout  => HREADY_S9
      );



   slave10 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S10,
         hsize      => HSIZE_S10,
         htrans     => HTRANS_S10,
         hwdata     => HWDATA_S10,
         hreadyin   => HREADYIN_S10,
         hsel       => HSEL_S10,
         haddr      => HADDR_S10(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S10,
         hprot      => HPROT_S10,
         -- Output
         hrdata     => HRDATA_S10,
         hresp      => HRESP_S10(0),
         hreadyout  => HREADY_S10
      );



   slave11 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S11,
         hsize      => HSIZE_S11,
         htrans     => HTRANS_S11,
         hwdata     => HWDATA_S11,
         hreadyin   => HREADYIN_S11,
         hsel       => HSEL_S11,
         haddr      => HADDR_S11(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S11,
         hprot      => HPROT_S11,
         -- Output
         hrdata     => HRDATA_S11,
         hresp      => HRESP_S11(0),
         hreadyout  => HREADY_S11
      );



   slave12 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S12,
         hsize      => HSIZE_S12,
         htrans     => HTRANS_S12,
         hwdata     => HWDATA_S12,
         hreadyin   => HREADYIN_S12,
         hsel       => HSEL_S12,
         haddr      => HADDR_S12(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S12,
         hprot      => HPROT_S12,
         -- Output
         hrdata     => HRDATA_S12,
         hresp      => HRESP_S12(0),
         hreadyout  => HREADY_S12
      );



   slave13 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S13,
         hsize      => HSIZE_S13,
         htrans     => HTRANS_S13,
         hwdata     => HWDATA_S13,
         hreadyin   => HREADYIN_S13,
         hsel       => HSEL_S13,
         haddr      => HADDR_S13(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S13,
         hprot      => HPROT_S13,
         -- Output
         hrdata     => HRDATA_S13,
         hresp      => HRESP_S13(0),
         hreadyout  => HREADY_S13
      );



   slave14 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S14,
         hsize      => HSIZE_S14,
         htrans     => HTRANS_S14,
         hwdata     => HWDATA_S14,
         hreadyin   => HREADYIN_S14,
         hsel       => HSEL_S14,
         haddr      => HADDR_S14(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S14,
         hprot      => HPROT_S14,
         -- Output
         hrdata     => HRDATA_S14,
         hresp      => HRESP_S14(0),
         hreadyout  => HREADY_S14
      );



   slave15 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S15,
         hsize      => HSIZE_S15,
         htrans     => HTRANS_S15,
         hwdata     => HWDATA_S15,
         hreadyin   => HREADYIN_S15,
         hsel       => HSEL_S15,
         haddr      => HADDR_S15(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S15,
         hprot      => HPROT_S15,
         -- Output
         hrdata     => HRDATA_S15,
         hresp      => HRESP_S15(0),
         hreadyout  => HREADY_S15
      );


	-- may need to make this bigger for 'huge' slave
   slave16 : BFM_AHBSLAVE
      generic map (
         awidth    => 16,
         depth     => 65536,
         initfile  => " ",
         id        => 1,
         enfunc    => 0,
         tpd       => 5,
         debug     => 0
      )
      port map (
         -- MP7Bridge interface
         -- Inputs
         hclk       => HCLK,
         hresetn    => HRESETN,
         -- AhbFabric interface
         -- Inputs
         hwrite     => HWRITE_S16,
         hsize      => HSIZE_S16,
         htrans     => HTRANS_S16,
         hwdata     => HWDATA_S16,
         hreadyin   => HREADYIN_S16,
         hsel       => HSEL_S16,
         haddr      => HADDR_S16(15 downto 0),
         hmastlock  => '0',
         hburst     => HBURST_S16,
         hprot      => HPROT_S16,
         -- Output
         hrdata     => HRDATA_S16,
         hresp      => HRESP_S16(0),
         hreadyout  => HREADY_S16
      );

    -----------------------------------------------------------------------
    -- Detect writes to individual slots
    -----------------------------------------------------------------------
    process (HCLK, HRESETN)
    begin
        if (HRESETN = '0') then
            s0_write  <= '0';
            s1_write  <= '0';
            s2_write  <= '0';
            s3_write  <= '0';
            s4_write  <= '0';
            s5_write  <= '0';
            s6_write  <= '0';
            s7_write  <= '0';
            s8_write  <= '0';
            s9_write  <= '0';
            s10_write <= '0';
            s11_write <= '0';
            s12_write <= '0';
            s13_write <= '0';
            s14_write <= '0';
            s15_write <= '0';
            s16_write <= '0';
        elsif (HCLK'event and HCLK = '1') then
            -- Set write indication bits
            if (HSEL_S0  = '1' and HTRANS_S0(1)  = '1' and HWRITE_S0  = '1') then s0_write  <= '1'; end if;
            if (HSEL_S1  = '1' and HTRANS_S1(1)  = '1' and HWRITE_S1  = '1') then s1_write  <= '1'; end if;
            if (HSEL_S2  = '1' and HTRANS_S2(1)  = '1' and HWRITE_S2  = '1') then s2_write  <= '1'; end if;
            if (HSEL_S3  = '1' and HTRANS_S3(1)  = '1' and HWRITE_S3  = '1') then s3_write  <= '1'; end if;
            if (HSEL_S4  = '1' and HTRANS_S4(1)  = '1' and HWRITE_S4  = '1') then s4_write  <= '1'; end if;
            if (HSEL_S5  = '1' and HTRANS_S5(1)  = '1' and HWRITE_S5  = '1') then s5_write  <= '1'; end if;
            if (HSEL_S6  = '1' and HTRANS_S6(1)  = '1' and HWRITE_S6  = '1') then s6_write  <= '1'; end if;
            if (HSEL_S7  = '1' and HTRANS_S7(1)  = '1' and HWRITE_S7  = '1') then s7_write  <= '1'; end if;
            if (HSEL_S8  = '1' and HTRANS_S8(1)  = '1' and HWRITE_S8  = '1') then s8_write  <= '1'; end if;
            if (HSEL_S9  = '1' and HTRANS_S9(1)  = '1' and HWRITE_S9  = '1') then s9_write  <= '1'; end if;
            if (HSEL_S10 = '1' and HTRANS_S10(1) = '1' and HWRITE_S10 = '1') then s10_write <= '1'; end if;
            if (HSEL_S11 = '1' and HTRANS_S11(1) = '1' and HWRITE_S11 = '1') then s11_write <= '1'; end if;
            if (HSEL_S12 = '1' and HTRANS_S12(1) = '1' and HWRITE_S12 = '1') then s12_write <= '1'; end if;
            if (HSEL_S13 = '1' and HTRANS_S13(1) = '1' and HWRITE_S13 = '1') then s13_write <= '1'; end if;
            if (HSEL_S14 = '1' and HTRANS_S14(1) = '1' and HWRITE_S14 = '1') then s14_write <= '1'; end if;
            if (HSEL_S15 = '1' and HTRANS_S15(1) = '1' and HWRITE_S15 = '1') then s15_write <= '1'; end if;
            if (HSEL_S16 = '1' and HTRANS_S16(1) = '1' and HWRITE_S16 = '1') then s16_write <= '1'; end if;
            -- Clear write indication bits
            if (GP_OUT_M0(0)  = '1') then s0_write  <= '0'; end if;
            if (GP_OUT_M0(1)  = '1') then s1_write  <= '0'; end if;
            if (GP_OUT_M0(2)  = '1') then s2_write  <= '0'; end if;
            if (GP_OUT_M0(3)  = '1') then s3_write  <= '0'; end if;
            if (GP_OUT_M0(4)  = '1') then s4_write  <= '0'; end if;
            if (GP_OUT_M0(5)  = '1') then s5_write  <= '0'; end if;
            if (GP_OUT_M0(6)  = '1') then s6_write  <= '0'; end if;
            if (GP_OUT_M0(7)  = '1') then s7_write  <= '0'; end if;
            if (GP_OUT_M0(8)  = '1') then s8_write  <= '0'; end if;
            if (GP_OUT_M0(9)  = '1') then s9_write  <= '0'; end if;
            if (GP_OUT_M0(10) = '1') then s10_write <= '0'; end if;
            if (GP_OUT_M0(11) = '1') then s11_write <= '0'; end if;
            if (GP_OUT_M0(12) = '1') then s12_write <= '0'; end if;
            if (GP_OUT_M0(13) = '1') then s13_write <= '0'; end if;
            if (GP_OUT_M0(14) = '1') then s14_write <= '0'; end if;
            if (GP_OUT_M0(15) = '1') then s15_write <= '0'; end if;
            if (GP_OUT_M0(16) = '1') then s16_write <= '0'; end if;
        end if;
    end process;

end architecture testbench_arch;
