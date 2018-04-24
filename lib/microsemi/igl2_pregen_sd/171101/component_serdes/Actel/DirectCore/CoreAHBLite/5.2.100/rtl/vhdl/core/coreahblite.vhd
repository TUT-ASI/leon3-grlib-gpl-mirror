-- ********************************************************************/
-- Actel Corporation Proprietary and Confidential
-- Copyright 2010 Actel Corporation.  All rights reserved.
--
-- ANY USE OR REDISTRIBUTION IN PART OR IN WHOLE MUST BE HANDLED IN
-- ACCORDANCE WITH THE ACTEL LICENSE AGREEMENT AND MUST BE APPROVED
-- IN ADVANCE IN WRITING.
--
-- Description:	CoreAHBLite - multi-master (up to 2) AHBLite
--				bus interface.
--
--				Instantiates the following modules:
--				COREAHBLITE_MATRIX2X16
--
--
-- SVN Revision Information:
-- SVN $Revision: 23120 $
-- SVN $Date: 2014-07-17 15:26:23 +0100 (Thu, 17 Jul 2014) $
--
--
-- *********************************************************************/
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.coreahblite_pkg.all;

entity CoreAHBLite is
generic (
FAMILY					: integer range 0 to 99	:= 17;
MEMSPACE				: integer range 0 to 6	:= 0;
HADDR_SHG_CFG			: integer range 0 to 1	:= 1;
SC_0                    : integer range 0 to 1	:= 1;
SC_1                    : integer range 0 to 1	:= 0;
SC_2                    : integer range 0 to 1	:= 0;
SC_3                    : integer range 0 to 1	:= 0;
SC_4                    : integer range 0 to 1	:= 0;
SC_5                    : integer range 0 to 1	:= 0;
SC_6                    : integer range 0 to 1	:= 0;
SC_7                    : integer range 0 to 1	:= 0;
SC_8                    : integer range 0 to 1	:= 0;
SC_9                    : integer range 0 to 1	:= 0;
SC_10                   : integer range 0 to 1	:= 0;
SC_11                   : integer range 0 to 1	:= 0;
SC_12                   : integer range 0 to 1	:= 0;
SC_13                   : integer range 0 to 1	:= 0;
SC_14                   : integer range 0 to 1	:= 0;
SC_15                   : integer range 0 to 1	:= 0;
M0_AHBSLOT0ENABLE       : integer range 0 to 1	:= 1;
M0_AHBSLOT1ENABLE       : integer range 0 to 1	:= 0;
M0_AHBSLOT2ENABLE       : integer range 0 to 1	:= 0;
M0_AHBSLOT3ENABLE       : integer range 0 to 1	:= 0;
M0_AHBSLOT4ENABLE       : integer range 0 to 1	:= 0;
M0_AHBSLOT5ENABLE       : integer range 0 to 1	:= 0;
M0_AHBSLOT6ENABLE       : integer range 0 to 1	:= 0;
M0_AHBSLOT7ENABLE       : integer range 0 to 1	:= 0;
M0_AHBSLOT8ENABLE       : integer range 0 to 1	:= 0;
M0_AHBSLOT9ENABLE       : integer range 0 to 1	:= 0;
M0_AHBSLOT10ENABLE      : integer range 0 to 1	:= 0;
M0_AHBSLOT11ENABLE      : integer range 0 to 1	:= 0;
M0_AHBSLOT12ENABLE      : integer range 0 to 1	:= 0;
M0_AHBSLOT13ENABLE      : integer range 0 to 1	:= 0;
M0_AHBSLOT14ENABLE      : integer range 0 to 1	:= 0;
M0_AHBSLOT15ENABLE      : integer range 0 to 1	:= 0;
M0_AHBSLOT16ENABLE      : integer range 0 to 1	:= 0;
M1_AHBSLOT0ENABLE       : integer range 0 to 1	:= 0;
M1_AHBSLOT1ENABLE       : integer range 0 to 1	:= 1;
M1_AHBSLOT2ENABLE       : integer range 0 to 1	:= 0;
M1_AHBSLOT3ENABLE       : integer range 0 to 1	:= 0;
M1_AHBSLOT4ENABLE       : integer range 0 to 1	:= 0;
M1_AHBSLOT5ENABLE       : integer range 0 to 1	:= 0;
M1_AHBSLOT6ENABLE       : integer range 0 to 1	:= 0;
M1_AHBSLOT7ENABLE       : integer range 0 to 1	:= 0;
M1_AHBSLOT8ENABLE       : integer range 0 to 1	:= 0;
M1_AHBSLOT9ENABLE       : integer range 0 to 1	:= 0;
M1_AHBSLOT10ENABLE      : integer range 0 to 1	:= 0;
M1_AHBSLOT11ENABLE      : integer range 0 to 1	:= 0;
M1_AHBSLOT12ENABLE      : integer range 0 to 1	:= 0;
M1_AHBSLOT13ENABLE      : integer range 0 to 1	:= 0;
M1_AHBSLOT14ENABLE      : integer range 0 to 1	:= 0;
M1_AHBSLOT15ENABLE      : integer range 0 to 1	:= 0;
M1_AHBSLOT16ENABLE      : integer range 0 to 1	:= 0;
M2_AHBSLOT0ENABLE       : integer range 0 to 1	:= 1;
M2_AHBSLOT1ENABLE       : integer range 0 to 1	:= 0;
M2_AHBSLOT2ENABLE       : integer range 0 to 1	:= 0;
M2_AHBSLOT3ENABLE       : integer range 0 to 1	:= 0;
M2_AHBSLOT4ENABLE       : integer range 0 to 1	:= 0;
M2_AHBSLOT5ENABLE       : integer range 0 to 1	:= 0;
M2_AHBSLOT6ENABLE       : integer range 0 to 1	:= 0;
M2_AHBSLOT7ENABLE       : integer range 0 to 1	:= 0;
M2_AHBSLOT8ENABLE       : integer range 0 to 1	:= 0;
M2_AHBSLOT9ENABLE       : integer range 0 to 1	:= 0;
M2_AHBSLOT10ENABLE      : integer range 0 to 1	:= 0;
M2_AHBSLOT11ENABLE      : integer range 0 to 1	:= 0;
M2_AHBSLOT12ENABLE      : integer range 0 to 1	:= 0;
M2_AHBSLOT13ENABLE      : integer range 0 to 1	:= 0;
M2_AHBSLOT14ENABLE      : integer range 0 to 1	:= 0;
M2_AHBSLOT15ENABLE      : integer range 0 to 1	:= 0;
M2_AHBSLOT16ENABLE      : integer range 0 to 1	:= 0;
M3_AHBSLOT0ENABLE       : integer range 0 to 1	:= 0;
M3_AHBSLOT1ENABLE       : integer range 0 to 1	:= 1;
M3_AHBSLOT2ENABLE       : integer range 0 to 1	:= 0;
M3_AHBSLOT3ENABLE       : integer range 0 to 1	:= 0;
M3_AHBSLOT4ENABLE       : integer range 0 to 1	:= 0;
M3_AHBSLOT5ENABLE       : integer range 0 to 1	:= 0;
M3_AHBSLOT6ENABLE       : integer range 0 to 1	:= 0;
M3_AHBSLOT7ENABLE       : integer range 0 to 1	:= 0;
M3_AHBSLOT8ENABLE       : integer range 0 to 1	:= 0;
M3_AHBSLOT9ENABLE       : integer range 0 to 1	:= 0;
M3_AHBSLOT10ENABLE      : integer range 0 to 1	:= 0;
M3_AHBSLOT11ENABLE      : integer range 0 to 1	:= 0;
M3_AHBSLOT12ENABLE      : integer range 0 to 1	:= 0;
M3_AHBSLOT13ENABLE      : integer range 0 to 1	:= 0;
M3_AHBSLOT14ENABLE      : integer range 0 to 1	:= 0;
M3_AHBSLOT15ENABLE      : integer range 0 to 1	:= 0;
M3_AHBSLOT16ENABLE      : integer range 0 to 1	:= 0
);
port (
HCLK                : in std_logic;
HRESETN             : in std_logic;
REMAP_M0            : in std_logic;
HADDR_M0            : in std_logic_vector(31 downto 0);
HMASTLOCK_M0        : in std_logic;
HSIZE_M0            : in std_logic_vector(2 downto 0);
HTRANS_M0           : in std_logic_vector(1 downto 0);
HWRITE_M0           : in std_logic;
HWDATA_M0           : in std_logic_vector(31 downto 0);
HBURST_M0           : in std_logic_vector(2 downto 0);
HPROT_M0            : in std_logic_vector(3 downto 0);
HRESP_M0            : out std_logic_vector(1 downto 0);
HRDATA_M0           : out std_logic_vector(31 downto 0);
HREADY_M0           : out std_logic;
HADDR_M1            : in std_logic_vector(31 downto 0);
HMASTLOCK_M1        : in std_logic;
HSIZE_M1            : in std_logic_vector(2 downto 0);
HTRANS_M1           : in std_logic_vector(1 downto 0);
HWRITE_M1           : in std_logic;
HWDATA_M1           : in std_logic_vector(31 downto 0);
HBURST_M1           : in std_logic_vector(2 downto 0);
HPROT_M1            : in std_logic_vector(3 downto 0);
HRESP_M1            : out std_logic_vector(1 downto 0);
HRDATA_M1           : out std_logic_vector(31 downto 0);
HREADY_M1           : out std_logic;
HADDR_M2            : in std_logic_vector(31 downto 0);
HMASTLOCK_M2        : in std_logic;
HSIZE_M2            : in std_logic_vector(2 downto 0);
HTRANS_M2           : in std_logic_vector(1 downto 0);
HWRITE_M2           : in std_logic;
HWDATA_M2           : in std_logic_vector(31 downto 0);
HBURST_M2           : in std_logic_vector(2 downto 0);
HPROT_M2            : in std_logic_vector(3 downto 0);
HRESP_M2            : out std_logic_vector(1 downto 0);
HRDATA_M2           : out std_logic_vector(31 downto 0);
HREADY_M2           : out std_logic;
HADDR_M3            : in std_logic_vector(31 downto 0);
HMASTLOCK_M3        : in std_logic;
HSIZE_M3            : in std_logic_vector(2 downto 0);
HTRANS_M3           : in std_logic_vector(1 downto 0);
HWRITE_M3           : in std_logic;
HWDATA_M3           : in std_logic_vector(31 downto 0);
HBURST_M3           : in std_logic_vector(2 downto 0);
HPROT_M3            : in std_logic_vector(3 downto 0);
HRESP_M3            : out std_logic_vector(1 downto 0);
HRDATA_M3           : out std_logic_vector(31 downto 0);
HREADY_M3           : out std_logic;
HRDATA_S0           : in std_logic_vector(31 downto 0);
HREADYOUT_S0        : in std_logic;
HRESP_S0            : in std_logic_vector(1 downto 0);
HSEL_S0             : out std_logic;
HADDR_S0            : out std_logic_vector(31 downto 0);
HSIZE_S0            : out std_logic_vector(2 downto 0);
HTRANS_S0           : out std_logic_vector(1 downto 0);
HWRITE_S0           : out std_logic;
HWDATA_S0           : out std_logic_vector(31 downto 0);
HREADY_S0           : out std_logic;
HMASTLOCK_S0        : out std_logic;
HBURST_S0           : out std_logic_vector(2 downto 0);
HPROT_S0            : out std_logic_vector(3 downto 0);
HRDATA_S1           : in std_logic_vector(31 downto 0);
HREADYOUT_S1        : in std_logic;
HRESP_S1            : in std_logic_vector(1 downto 0);
HSEL_S1             : out std_logic;
HADDR_S1            : out std_logic_vector(31 downto 0);
HSIZE_S1            : out std_logic_vector(2 downto 0);
HTRANS_S1           : out std_logic_vector(1 downto 0);
HWRITE_S1           : out std_logic;
HWDATA_S1           : out std_logic_vector(31 downto 0);
HREADY_S1           : out std_logic;
HMASTLOCK_S1        : out std_logic;
HBURST_S1           : out std_logic_vector(2 downto 0);
HPROT_S1            : out std_logic_vector(3 downto 0);
HRDATA_S2           : in std_logic_vector(31 downto 0);
HREADYOUT_S2        : in std_logic;
HRESP_S2            : in std_logic_vector(1 downto 0);
HSEL_S2             : out std_logic;
HADDR_S2            : out std_logic_vector(31 downto 0);
HSIZE_S2            : out std_logic_vector(2 downto 0);
HTRANS_S2           : out std_logic_vector(1 downto 0);
HWRITE_S2           : out std_logic;
HWDATA_S2           : out std_logic_vector(31 downto 0);
HREADY_S2           : out std_logic;
HMASTLOCK_S2        : out std_logic;
HBURST_S2           : out std_logic_vector(2 downto 0);
HPROT_S2            : out std_logic_vector(3 downto 0);
HRDATA_S3           : in std_logic_vector(31 downto 0);
HREADYOUT_S3        : in std_logic;
HRESP_S3            : in std_logic_vector(1 downto 0);
HSEL_S3             : out std_logic;
HADDR_S3            : out std_logic_vector(31 downto 0);
HSIZE_S3            : out std_logic_vector(2 downto 0);
HTRANS_S3           : out std_logic_vector(1 downto 0);
HWRITE_S3           : out std_logic;
HWDATA_S3           : out std_logic_vector(31 downto 0);
HREADY_S3           : out std_logic;
HMASTLOCK_S3        : out std_logic;
HBURST_S3           : out std_logic_vector(2 downto 0);
HPROT_S3            : out std_logic_vector(3 downto 0);
HRDATA_S4           : in std_logic_vector(31 downto 0);
HREADYOUT_S4        : in std_logic;
HRESP_S4            : in std_logic_vector(1 downto 0);
HSEL_S4             : out std_logic;
HADDR_S4            : out std_logic_vector(31 downto 0);
HSIZE_S4            : out std_logic_vector(2 downto 0);
HTRANS_S4           : out std_logic_vector(1 downto 0);
HWRITE_S4           : out std_logic;
HWDATA_S4           : out std_logic_vector(31 downto 0);
HREADY_S4           : out std_logic;
HMASTLOCK_S4        : out std_logic;
HBURST_S4           : out std_logic_vector(2 downto 0);
HPROT_S4            : out std_logic_vector(3 downto 0);
HRDATA_S5           : in std_logic_vector(31 downto 0);
HREADYOUT_S5        : in std_logic;
HRESP_S5            : in std_logic_vector(1 downto 0);
HSEL_S5             : out std_logic;
HADDR_S5            : out std_logic_vector(31 downto 0);
HSIZE_S5            : out std_logic_vector(2 downto 0);
HTRANS_S5           : out std_logic_vector(1 downto 0);
HWRITE_S5           : out std_logic;
HWDATA_S5           : out std_logic_vector(31 downto 0);
HREADY_S5           : out std_logic;
HMASTLOCK_S5        : out std_logic;
HBURST_S5           : out std_logic_vector(2 downto 0);
HPROT_S5            : out std_logic_vector(3 downto 0);
HRDATA_S6           : in std_logic_vector(31 downto 0);
HREADYOUT_S6        : in std_logic;
HRESP_S6            : in std_logic_vector(1 downto 0);
HSEL_S6             : out std_logic;
HADDR_S6            : out std_logic_vector(31 downto 0);
HSIZE_S6            : out std_logic_vector(2 downto 0);
HTRANS_S6           : out std_logic_vector(1 downto 0);
HWRITE_S6           : out std_logic;
HWDATA_S6           : out std_logic_vector(31 downto 0);
HREADY_S6           : out std_logic;
HMASTLOCK_S6        : out std_logic;
HBURST_S6           : out std_logic_vector(2 downto 0);
HPROT_S6            : out std_logic_vector(3 downto 0);
HRDATA_S7           : in std_logic_vector(31 downto 0);
HREADYOUT_S7        : in std_logic;
HRESP_S7            : in std_logic_vector(1 downto 0);
HSEL_S7             : out std_logic;
HADDR_S7            : out std_logic_vector(31 downto 0);
HSIZE_S7            : out std_logic_vector(2 downto 0);
HTRANS_S7           : out std_logic_vector(1 downto 0);
HWRITE_S7           : out std_logic;
HWDATA_S7           : out std_logic_vector(31 downto 0);
HREADY_S7           : out std_logic;
HMASTLOCK_S7        : out std_logic;
HBURST_S7           : out std_logic_vector(2 downto 0);
HPROT_S7            : out std_logic_vector(3 downto 0);
HRDATA_S8           : in std_logic_vector(31 downto 0);
HREADYOUT_S8        : in std_logic;
HRESP_S8            : in std_logic_vector(1 downto 0);
HSEL_S8             : out std_logic;
HADDR_S8            : out std_logic_vector(31 downto 0);
HSIZE_S8            : out std_logic_vector(2 downto 0);
HTRANS_S8           : out std_logic_vector(1 downto 0);
HWRITE_S8           : out std_logic;
HWDATA_S8           : out std_logic_vector(31 downto 0);
HREADY_S8           : out std_logic;
HMASTLOCK_S8        : out std_logic;
HBURST_S8           : out std_logic_vector(2 downto 0);
HPROT_S8            : out std_logic_vector(3 downto 0);
HRDATA_S9           : in std_logic_vector(31 downto 0);
HREADYOUT_S9        : in std_logic;
HRESP_S9            : in std_logic_vector(1 downto 0);
HSEL_S9             : out std_logic;
HADDR_S9            : out std_logic_vector(31 downto 0);
HSIZE_S9            : out std_logic_vector(2 downto 0);
HTRANS_S9           : out std_logic_vector(1 downto 0);
HWRITE_S9           : out std_logic;
HWDATA_S9           : out std_logic_vector(31 downto 0);
HREADY_S9           : out std_logic;
HMASTLOCK_S9        : out std_logic;
HBURST_S9           : out std_logic_vector(2 downto 0);
HPROT_S9            : out std_logic_vector(3 downto 0);
HRDATA_S10          : in std_logic_vector(31 downto 0);
HREADYOUT_S10       : in std_logic;
HRESP_S10           : in std_logic_vector(1 downto 0);
HSEL_S10            : out std_logic;
HADDR_S10           : out std_logic_vector(31 downto 0);
HSIZE_S10           : out std_logic_vector(2 downto 0);
HTRANS_S10          : out std_logic_vector(1 downto 0);
HWRITE_S10          : out std_logic;
HWDATA_S10          : out std_logic_vector(31 downto 0);
HREADY_S10          : out std_logic;
HMASTLOCK_S10       : out std_logic;
HBURST_S10          : out std_logic_vector(2 downto 0);
HPROT_S10           : out std_logic_vector(3 downto 0);
HRDATA_S11          : in std_logic_vector(31 downto 0);
HREADYOUT_S11       : in std_logic;
HRESP_S11           : in std_logic_vector(1 downto 0);
HSEL_S11            : out std_logic;
HADDR_S11           : out std_logic_vector(31 downto 0);
HSIZE_S11           : out std_logic_vector(2 downto 0);
HTRANS_S11          : out std_logic_vector(1 downto 0);
HWRITE_S11          : out std_logic;
HWDATA_S11          : out std_logic_vector(31 downto 0);
HREADY_S11          : out std_logic;
HMASTLOCK_S11       : out std_logic;
HBURST_S11          : out std_logic_vector(2 downto 0);
HPROT_S11           : out std_logic_vector(3 downto 0);
HRDATA_S12          : in std_logic_vector(31 downto 0);
HREADYOUT_S12       : in std_logic;
HRESP_S12           : in std_logic_vector(1 downto 0);
HSEL_S12            : out std_logic;
HADDR_S12           : out std_logic_vector(31 downto 0);
HSIZE_S12           : out std_logic_vector(2 downto 0);
HTRANS_S12          : out std_logic_vector(1 downto 0);
HWRITE_S12          : out std_logic;
HWDATA_S12          : out std_logic_vector(31 downto 0);
HREADY_S12          : out std_logic;
HMASTLOCK_S12       : out std_logic;
HBURST_S12          : out std_logic_vector(2 downto 0);
HPROT_S12           : out std_logic_vector(3 downto 0);
HRDATA_S13          : in std_logic_vector(31 downto 0);
HREADYOUT_S13       : in std_logic;
HRESP_S13           : in std_logic_vector(1 downto 0);
HSEL_S13            : out std_logic;
HADDR_S13           : out std_logic_vector(31 downto 0);
HSIZE_S13           : out std_logic_vector(2 downto 0);
HTRANS_S13          : out std_logic_vector(1 downto 0);
HWRITE_S13          : out std_logic;
HWDATA_S13          : out std_logic_vector(31 downto 0);
HREADY_S13          : out std_logic;
HMASTLOCK_S13       : out std_logic;
HBURST_S13          : out std_logic_vector(2 downto 0);
HPROT_S13           : out std_logic_vector(3 downto 0);
HRDATA_S14          : in std_logic_vector(31 downto 0);
HREADYOUT_S14       : in std_logic;
HRESP_S14           : in std_logic_vector(1 downto 0);
HSEL_S14            : out std_logic;
HADDR_S14           : out std_logic_vector(31 downto 0);
HSIZE_S14           : out std_logic_vector(2 downto 0);
HTRANS_S14          : out std_logic_vector(1 downto 0);
HWRITE_S14          : out std_logic;
HWDATA_S14          : out std_logic_vector(31 downto 0);
HREADY_S14          : out std_logic;
HMASTLOCK_S14       : out std_logic;
HBURST_S14          : out std_logic_vector(2 downto 0);
HPROT_S14           : out std_logic_vector(3 downto 0);
HRDATA_S15          : in std_logic_vector(31 downto 0);
HREADYOUT_S15       : in std_logic;
HRESP_S15           : in std_logic_vector(1 downto 0);
HSEL_S15            : out std_logic;
HADDR_S15           : out std_logic_vector(31 downto 0);
HSIZE_S15           : out std_logic_vector(2 downto 0);
HTRANS_S15          : out std_logic_vector(1 downto 0);
HWRITE_S15          : out std_logic;
HWDATA_S15          : out std_logic_vector(31 downto 0);
HREADY_S15          : out std_logic;
HMASTLOCK_S15       : out std_logic;
HBURST_S15          : out std_logic_vector(2 downto 0);
HPROT_S15           : out std_logic_vector(3 downto 0);
HRDATA_S16          : in std_logic_vector(31 downto 0);
HREADYOUT_S16       : in std_logic;
HRESP_S16           : in std_logic_vector(1 downto 0);
HSEL_S16            : out std_logic;
HADDR_S16           : out std_logic_vector(31 downto 0);
HSIZE_S16           : out std_logic_vector(2 downto 0);
HTRANS_S16          : out std_logic_vector(1 downto 0);
HWRITE_S16          : out std_logic;
HWDATA_S16          : out std_logic_vector(31 downto 0);
HREADY_S16          : out std_logic;
HMASTLOCK_S16       : out std_logic;
HBURST_S16          : out std_logic_vector(2 downto 0);
HPROT_S16           : out std_logic_vector(3 downto 0)
);
end entity CoreAHBLite;

architecture CoreAHBLite_arch of CoreAHBLite is

constant SYNC_RESET : integer := SYNC_MODE_SEL(FAMILY);

constant M0_AHBSLOTENABLE    : integer :=
(M0_AHBSLOT16ENABLE * (2**16)) +
(M0_AHBSLOT15ENABLE * (2**15)) +
(M0_AHBSLOT14ENABLE * (2**14)) +
(M0_AHBSLOT13ENABLE * (2**13)) +
(M0_AHBSLOT12ENABLE * (2**12)) +
(M0_AHBSLOT11ENABLE * (2**11)) +
(M0_AHBSLOT10ENABLE * (2**10)) +
(M0_AHBSLOT9ENABLE  * (2**9))  +
(M0_AHBSLOT8ENABLE  * (2**8))  +
(M0_AHBSLOT7ENABLE  * (2**7))  +
(M0_AHBSLOT6ENABLE  * (2**6))  +
(M0_AHBSLOT5ENABLE  * (2**5))  +
(M0_AHBSLOT4ENABLE  * (2**4))  +
(M0_AHBSLOT3ENABLE  * (2**3))  +
(M0_AHBSLOT2ENABLE  * (2**2))  +
(M0_AHBSLOT1ENABLE  * (2**1))  +
(M0_AHBSLOT0ENABLE  * (2**0))  ;

constant M1_AHBSLOTENABLE    : integer :=
(M1_AHBSLOT16ENABLE * (2**16)) +
(M1_AHBSLOT15ENABLE * (2**15)) +
(M1_AHBSLOT14ENABLE * (2**14)) +
(M1_AHBSLOT13ENABLE * (2**13)) +
(M1_AHBSLOT12ENABLE * (2**12)) +
(M1_AHBSLOT11ENABLE * (2**11)) +
(M1_AHBSLOT10ENABLE * (2**10)) +
(M1_AHBSLOT9ENABLE  * (2**9))  +
(M1_AHBSLOT8ENABLE  * (2**8))  +
(M1_AHBSLOT7ENABLE  * (2**7))  +
(M1_AHBSLOT6ENABLE  * (2**6))  +
(M1_AHBSLOT5ENABLE  * (2**5))  +
(M1_AHBSLOT4ENABLE  * (2**4))  +
(M1_AHBSLOT3ENABLE  * (2**3))  +
(M1_AHBSLOT2ENABLE  * (2**2))  +
(M1_AHBSLOT1ENABLE  * (2**1))  +
(M1_AHBSLOT0ENABLE  * (2**0))  ;

constant M2_AHBSLOTENABLE    : integer :=
(M2_AHBSLOT16ENABLE * (2**16)) +
(M2_AHBSLOT15ENABLE * (2**15)) +
(M2_AHBSLOT14ENABLE * (2**14)) +
(M2_AHBSLOT13ENABLE * (2**13)) +
(M2_AHBSLOT12ENABLE * (2**12)) +
(M2_AHBSLOT11ENABLE * (2**11)) +
(M2_AHBSLOT10ENABLE * (2**10)) +
(M2_AHBSLOT9ENABLE  * (2**9))  +
(M2_AHBSLOT8ENABLE  * (2**8))  +
(M2_AHBSLOT7ENABLE  * (2**7))  +
(M2_AHBSLOT6ENABLE  * (2**6))  +
(M2_AHBSLOT5ENABLE  * (2**5))  +
(M2_AHBSLOT4ENABLE  * (2**4))  +
(M2_AHBSLOT3ENABLE  * (2**3))  +
(M2_AHBSLOT2ENABLE  * (2**2))  +
(M2_AHBSLOT1ENABLE  * (2**1))  +
(M2_AHBSLOT0ENABLE  * (2**0))  ;

constant M3_AHBSLOTENABLE    : integer :=
(M3_AHBSLOT16ENABLE * (2**16)) +
(M3_AHBSLOT15ENABLE * (2**15)) +
(M3_AHBSLOT14ENABLE * (2**14)) +
(M3_AHBSLOT13ENABLE * (2**13)) +
(M3_AHBSLOT12ENABLE * (2**12)) +
(M3_AHBSLOT11ENABLE * (2**11)) +
(M3_AHBSLOT10ENABLE * (2**10)) +
(M3_AHBSLOT9ENABLE  * (2**9))  +
(M3_AHBSLOT8ENABLE  * (2**8))  +
(M3_AHBSLOT7ENABLE  * (2**7))  +
(M3_AHBSLOT6ENABLE  * (2**6))  +
(M3_AHBSLOT5ENABLE  * (2**5))  +
(M3_AHBSLOT4ENABLE  * (2**4))  +
(M3_AHBSLOT3ENABLE  * (2**3))  +
(M3_AHBSLOT2ENABLE  * (2**2))  +
(M3_AHBSLOT1ENABLE  * (2**1))  +
(M3_AHBSLOT0ENABLE  * (2**0))  ;

constant SC : integer :=
(SC_15 * (2**15)) +
(SC_14 * (2**14)) +
(SC_13 * (2**13)) +
(SC_12 * (2**12)) +
(SC_11 * (2**11)) +
(SC_10 * (2**10)) +
(SC_9  * (2**9))  +
(SC_8  * (2**8))  +
(SC_7  * (2**7))  +
(SC_6  * (2**6))  +
(SC_5  * (2**5))  +
(SC_4  * (2**4))  +
(SC_3  * (2**3))  +
(SC_2  * (2**2))  +
(SC_1  * (2**1))  +
(SC_0  * (2**0))  ;


    component COREAHBLITE_MATRIX4X16 is
        generic (
            MEMSPACE          : integer range 0 to 6:= 0;
            HADDR_SHG_CFG     : integer range 0 to 1:= 0;
            M0_AHBSLOTENABLE  : integer range 0 to (2**17)-1:= (2**17)-1;
            M1_AHBSLOTENABLE  : integer range 0 to (2**17)-1:= (2**17)-1;
            M2_AHBSLOTENABLE  : integer range 0 to (2**17)-1:= (2**17)-1;
            M3_AHBSLOTENABLE  : integer range 0 to (2**17)-1:= (2**17)-1;
            SC                : integer range 0 to (2**16)-1:= 0;
			SYNC_RESET        : integer  := 0
        );
        port (
            HCLK                : in std_logic;
            HRESETN             : in std_logic;
            REMAP_M0            : in std_logic;
            HADDR_M0            : in std_logic_vector(31 downto 0);
            HMASTLOCK_M0        : in std_logic;
            HSIZE_M0            : in std_logic_vector(2 downto 0);
            HTRANS_M0           : in std_logic;
            HWRITE_M0           : in std_logic;
            HWDATA_M0           : in std_logic_vector(31 downto 0);
            HRESP_M0            : out std_logic;
            HRDATA_M0           : out std_logic_vector(31 downto 0);
            HREADY_M0           : out std_logic;
            HADDR_M1            : in std_logic_vector(31 downto 0);
            HMASTLOCK_M1        : in std_logic;
            HSIZE_M1            : in std_logic_vector(2 downto 0);
            HTRANS_M1           : in std_logic;
            HWRITE_M1           : in std_logic;
            HWDATA_M1           : in std_logic_vector(31 downto 0);
            HRESP_M1            : out std_logic;
            HRDATA_M1           : out std_logic_vector(31 downto 0);
            HREADY_M1           : out std_logic;
            HADDR_M2            : in std_logic_vector(31 downto 0);
            HMASTLOCK_M2        : in std_logic;
            HSIZE_M2            : in std_logic_vector(2 downto 0);
            HTRANS_M2           : in std_logic;
            HWRITE_M2           : in std_logic;
            HWDATA_M2           : in std_logic_vector(31 downto 0);
            HRESP_M2            : out std_logic;
            HRDATA_M2           : out std_logic_vector(31 downto 0);
            HREADY_M2           : out std_logic;
            HADDR_M3            : in std_logic_vector(31 downto 0);
            HMASTLOCK_M3        : in std_logic;
            HSIZE_M3            : in std_logic_vector(2 downto 0);
            HTRANS_M3           : in std_logic;
            HWRITE_M3           : in std_logic;
            HWDATA_M3           : in std_logic_vector(31 downto 0);
            HRESP_M3            : out std_logic;
            HRDATA_M3           : out std_logic_vector(31 downto 0);
            HREADY_M3           : out std_logic;
            HRDATA_S0           : in std_logic_vector(31 downto 0);
            HREADYOUT_S0        : in std_logic;
            HRESP_S0            : in std_logic;
            HSEL_S0             : out std_logic;
            HADDR_S0            : out std_logic_vector(31 downto 0);
            HSIZE_S0            : out std_logic_vector(2 downto 0);
            HTRANS_S0           : out std_logic;
            HWRITE_S0           : out std_logic;
            HWDATA_S0           : out std_logic_vector(31 downto 0);
            HREADY_S0           : out std_logic;
            HMASTLOCK_S0        : out std_logic;
            HRDATA_S1           : in std_logic_vector(31 downto 0);
            HREADYOUT_S1        : in std_logic;
            HRESP_S1            : in std_logic;
            HSEL_S1             : out std_logic;
            HADDR_S1            : out std_logic_vector(31 downto 0);
            HSIZE_S1            : out std_logic_vector(2 downto 0);
            HTRANS_S1           : out std_logic;
            HWRITE_S1           : out std_logic;
            HWDATA_S1           : out std_logic_vector(31 downto 0);
            HREADY_S1           : out std_logic;
            HMASTLOCK_S1        : out std_logic;
            HRDATA_S2           : in std_logic_vector(31 downto 0);
            HREADYOUT_S2        : in std_logic;
            HRESP_S2            : in std_logic;
            HSEL_S2             : out std_logic;
            HADDR_S2            : out std_logic_vector(31 downto 0);
            HSIZE_S2            : out std_logic_vector(2 downto 0);
            HTRANS_S2           : out std_logic;
            HWRITE_S2           : out std_logic;
            HWDATA_S2           : out std_logic_vector(31 downto 0);
            HREADY_S2           : out std_logic;
            HMASTLOCK_S2        : out std_logic;
            HRDATA_S3           : in std_logic_vector(31 downto 0);
            HREADYOUT_S3        : in std_logic;
            HRESP_S3            : in std_logic;
            HSEL_S3             : out std_logic;
            HADDR_S3            : out std_logic_vector(31 downto 0);
            HSIZE_S3            : out std_logic_vector(2 downto 0);
            HTRANS_S3           : out std_logic;
            HWRITE_S3           : out std_logic;
            HWDATA_S3           : out std_logic_vector(31 downto 0);
            HREADY_S3           : out std_logic;
            HMASTLOCK_S3        : out std_logic;
            HRDATA_S4           : in std_logic_vector(31 downto 0);
            HREADYOUT_S4        : in std_logic;
            HRESP_S4            : in std_logic;
            HSEL_S4             : out std_logic;
            HADDR_S4            : out std_logic_vector(31 downto 0);
            HSIZE_S4            : out std_logic_vector(2 downto 0);
            HTRANS_S4           : out std_logic;
            HWRITE_S4           : out std_logic;
            HWDATA_S4           : out std_logic_vector(31 downto 0);
            HREADY_S4           : out std_logic;
            HMASTLOCK_S4        : out std_logic;
            HRDATA_S5           : in std_logic_vector(31 downto 0);
            HREADYOUT_S5        : in std_logic;
            HRESP_S5            : in std_logic;
            HSEL_S5             : out std_logic;
            HADDR_S5            : out std_logic_vector(31 downto 0);
            HSIZE_S5            : out std_logic_vector(2 downto 0);
            HTRANS_S5           : out std_logic;
            HWRITE_S5           : out std_logic;
            HWDATA_S5           : out std_logic_vector(31 downto 0);
            HREADY_S5           : out std_logic;
            HMASTLOCK_S5        : out std_logic;
            HRDATA_S6           : in std_logic_vector(31 downto 0);
            HREADYOUT_S6        : in std_logic;
            HRESP_S6            : in std_logic;
            HSEL_S6             : out std_logic;
            HADDR_S6            : out std_logic_vector(31 downto 0);
            HSIZE_S6            : out std_logic_vector(2 downto 0);
            HTRANS_S6           : out std_logic;
            HWRITE_S6           : out std_logic;
            HWDATA_S6           : out std_logic_vector(31 downto 0);
            HREADY_S6           : out std_logic;
            HMASTLOCK_S6        : out std_logic;
            HRDATA_S7           : in std_logic_vector(31 downto 0);
            HREADYOUT_S7        : in std_logic;
            HRESP_S7            : in std_logic;
            HSEL_S7             : out std_logic;
            HADDR_S7            : out std_logic_vector(31 downto 0);
            HSIZE_S7            : out std_logic_vector(2 downto 0);
            HTRANS_S7           : out std_logic;
            HWRITE_S7           : out std_logic;
            HWDATA_S7           : out std_logic_vector(31 downto 0);
            HREADY_S7           : out std_logic;
            HMASTLOCK_S7        : out std_logic;
            HRDATA_S8           : in std_logic_vector(31 downto 0);
            HREADYOUT_S8        : in std_logic;
            HRESP_S8            : in std_logic;
            HSEL_S8             : out std_logic;
            HADDR_S8            : out std_logic_vector(31 downto 0);
            HSIZE_S8            : out std_logic_vector(2 downto 0);
            HTRANS_S8           : out std_logic;
            HWRITE_S8           : out std_logic;
            HWDATA_S8           : out std_logic_vector(31 downto 0);
            HREADY_S8           : out std_logic;
            HMASTLOCK_S8        : out std_logic;
            HRDATA_S9           : in std_logic_vector(31 downto 0);
            HREADYOUT_S9        : in std_logic;
            HRESP_S9            : in std_logic;
            HSEL_S9             : out std_logic;
            HADDR_S9            : out std_logic_vector(31 downto 0);
            HSIZE_S9            : out std_logic_vector(2 downto 0);
            HTRANS_S9           : out std_logic;
            HWRITE_S9           : out std_logic;
            HWDATA_S9           : out std_logic_vector(31 downto 0);
            HREADY_S9           : out std_logic;
            HMASTLOCK_S9        : out std_logic;
            HRDATA_S10          : in std_logic_vector(31 downto 0);
            HREADYOUT_S10       : in std_logic;
            HRESP_S10           : in std_logic;
            HSEL_S10            : out std_logic;
            HADDR_S10           : out std_logic_vector(31 downto 0);
            HSIZE_S10           : out std_logic_vector(2 downto 0);
            HTRANS_S10          : out std_logic;
            HWRITE_S10          : out std_logic;
            HWDATA_S10          : out std_logic_vector(31 downto 0);
            HREADY_S10          : out std_logic;
            HMASTLOCK_S10       : out std_logic;
            HRDATA_S11          : in std_logic_vector(31 downto 0);
            HREADYOUT_S11       : in std_logic;
            HRESP_S11           : in std_logic;
            HSEL_S11            : out std_logic;
            HADDR_S11           : out std_logic_vector(31 downto 0);
            HSIZE_S11           : out std_logic_vector(2 downto 0);
            HTRANS_S11          : out std_logic;
            HWRITE_S11          : out std_logic;
            HWDATA_S11          : out std_logic_vector(31 downto 0);
            HREADY_S11          : out std_logic;
            HMASTLOCK_S11       : out std_logic;
            HRDATA_S12          : in std_logic_vector(31 downto 0);
            HREADYOUT_S12       : in std_logic;
            HRESP_S12           : in std_logic;
            HSEL_S12            : out std_logic;
            HADDR_S12           : out std_logic_vector(31 downto 0);
            HSIZE_S12           : out std_logic_vector(2 downto 0);
            HTRANS_S12          : out std_logic;
            HWRITE_S12          : out std_logic;
            HWDATA_S12          : out std_logic_vector(31 downto 0);
            HREADY_S12          : out std_logic;
            HMASTLOCK_S12       : out std_logic;
            HRDATA_S13          : in std_logic_vector(31 downto 0);
            HREADYOUT_S13       : in std_logic;
            HRESP_S13           : in std_logic;
            HSEL_S13            : out std_logic;
            HADDR_S13           : out std_logic_vector(31 downto 0);
            HSIZE_S13           : out std_logic_vector(2 downto 0);
            HTRANS_S13          : out std_logic;
            HWRITE_S13          : out std_logic;
            HWDATA_S13          : out std_logic_vector(31 downto 0);
            HREADY_S13          : out std_logic;
            HMASTLOCK_S13       : out std_logic;
            HRDATA_S14          : in std_logic_vector(31 downto 0);
            HREADYOUT_S14       : in std_logic;
            HRESP_S14           : in std_logic;
            HSEL_S14            : out std_logic;
            HADDR_S14           : out std_logic_vector(31 downto 0);
            HSIZE_S14           : out std_logic_vector(2 downto 0);
            HTRANS_S14          : out std_logic;
            HWRITE_S14          : out std_logic;
            HWDATA_S14          : out std_logic_vector(31 downto 0);
            HREADY_S14          : out std_logic;
            HMASTLOCK_S14       : out std_logic;
            HRDATA_S15          : in std_logic_vector(31 downto 0);
            HREADYOUT_S15       : in std_logic;
            HRESP_S15           : in std_logic;
            HSEL_S15            : out std_logic;
            HADDR_S15           : out std_logic_vector(31 downto 0);
            HSIZE_S15           : out std_logic_vector(2 downto 0);
            HTRANS_S15          : out std_logic;
            HWRITE_S15          : out std_logic;
            HWDATA_S15          : out std_logic_vector(31 downto 0);
            HREADY_S15          : out std_logic;
            HMASTLOCK_S15       : out std_logic;
            HRDATA_S16          : in std_logic_vector(31 downto 0);
            HREADYOUT_S16       : in std_logic;
            HRESP_S16           : in std_logic;
            HSEL_S16            : out std_logic;
            HADDR_S16           : out std_logic_vector(31 downto 0);
            HSIZE_S16           : out std_logic_vector(2 downto 0);
            HTRANS_S16          : out std_logic;
            HWRITE_S16          : out std_logic;
            HWDATA_S16          : out std_logic_vector(31 downto 0);
            HREADY_S16          : out std_logic;
            HMASTLOCK_S16       : out std_logic
        );
    end component;
	
    -- Declare intermediate signals for referenced outputs
    signal HRESP_M0_xhdl54        : std_logic_vector(1 downto 0);
    signal HRDATA_M0_xhdl33       : std_logic_vector(31 downto 0);
    signal HREADY_M0_xhdl35       : std_logic;
    signal HRESP_M1_xhdl55        : std_logic_vector(1 downto 0);
    signal HRDATA_M1_xhdl34       : std_logic_vector(31 downto 0);
    signal HREADY_M1_xhdl36       : std_logic;
    signal HRESP_M2_xhdl54        : std_logic_vector(1 downto 0);
    signal HRDATA_M2_xhdl33       : std_logic_vector(31 downto 0);
    signal HREADY_M2_xhdl35       : std_logic;
    signal HRESP_M3_xhdl55        : std_logic_vector(1 downto 0);
    signal HRDATA_M3_xhdl34       : std_logic_vector(31 downto 0);
    signal HREADY_M3_xhdl36       : std_logic;
    signal HSEL_S0_xhdl56         : std_logic;
    signal HADDR_S0_xhdl0         : std_logic_vector(31 downto 0);
    signal HSIZE_S0_xhdl73        : std_logic_vector(2 downto 0);
    signal HTRANS_S0_xhdl90       : std_logic_vector(1 downto 0);
    signal HWRITE_S0_xhdl124      : std_logic;
    signal HWDATA_S0_xhdl107      : std_logic_vector(31 downto 0);
    signal HREADY_S0_xhdl37       : std_logic;
    signal HMASTLOCK_S0_xhdl16    : std_logic;
    signal HSEL_S1_xhdl57         : std_logic;
    signal HADDR_S1_xhdl1         : std_logic_vector(31 downto 0);
    signal HSIZE_S1_xhdl74        : std_logic_vector(2 downto 0);
    signal HTRANS_S1_xhdl91       : std_logic_vector(1 downto 0);
    signal HWRITE_S1_xhdl125      : std_logic;
    signal HWDATA_S1_xhdl108      : std_logic_vector(31 downto 0);
    signal HREADY_S1_xhdl38       : std_logic;
    signal HMASTLOCK_S1_xhdl17    : std_logic;
    signal HSEL_S2_xhdl64         : std_logic;
    signal HADDR_S2_xhdl8         : std_logic_vector(31 downto 0);
    signal HSIZE_S2_xhdl81        : std_logic_vector(2 downto 0);
    signal HTRANS_S2_xhdl98       : std_logic_vector(1 downto 0);
    signal HWRITE_S2_xhdl132      : std_logic;
    signal HWDATA_S2_xhdl115      : std_logic_vector(31 downto 0);
    signal HREADY_S2_xhdl45       : std_logic;
    signal HMASTLOCK_S2_xhdl24    : std_logic;
    signal HSEL_S3_xhdl65         : std_logic;
    signal HADDR_S3_xhdl9         : std_logic_vector(31 downto 0);
    signal HSIZE_S3_xhdl82        : std_logic_vector(2 downto 0);
    signal HTRANS_S3_xhdl99       : std_logic_vector(1 downto 0);
    signal HWRITE_S3_xhdl133      : std_logic;
    signal HWDATA_S3_xhdl116      : std_logic_vector(31 downto 0);
    signal HREADY_S3_xhdl46       : std_logic;
    signal HMASTLOCK_S3_xhdl25    : std_logic;
    signal HSEL_S4_xhdl66         : std_logic;
    signal HADDR_S4_xhdl10        : std_logic_vector(31 downto 0);
    signal HSIZE_S4_xhdl83        : std_logic_vector(2 downto 0);
    signal HTRANS_S4_xhdl100      : std_logic_vector(1 downto 0);
    signal HWRITE_S4_xhdl134      : std_logic;
    signal HWDATA_S4_xhdl117      : std_logic_vector(31 downto 0);
    signal HREADY_S4_xhdl47       : std_logic;
    signal HMASTLOCK_S4_xhdl26    : std_logic;
    signal HSEL_S5_xhdl67         : std_logic;
    signal HADDR_S5_xhdl11        : std_logic_vector(31 downto 0);
    signal HSIZE_S5_xhdl84        : std_logic_vector(2 downto 0);
    signal HTRANS_S5_xhdl101      : std_logic_vector(1 downto 0);
    signal HWRITE_S5_xhdl135      : std_logic;
    signal HWDATA_S5_xhdl118      : std_logic_vector(31 downto 0);
    signal HREADY_S5_xhdl48       : std_logic;
    signal HMASTLOCK_S5_xhdl27    : std_logic;
    signal HSEL_S6_xhdl68         : std_logic;
    signal HADDR_S6_xhdl12        : std_logic_vector(31 downto 0);
    signal HSIZE_S6_xhdl85        : std_logic_vector(2 downto 0);
    signal HTRANS_S6_xhdl102      : std_logic_vector(1 downto 0);
    signal HWRITE_S6_xhdl136      : std_logic;
    signal HWDATA_S6_xhdl119      : std_logic_vector(31 downto 0);
    signal HREADY_S6_xhdl49       : std_logic;
    signal HMASTLOCK_S6_xhdl28    : std_logic;
    signal HSEL_S7_xhdl69         : std_logic;
    signal HADDR_S7_xhdl13        : std_logic_vector(31 downto 0);
    signal HSIZE_S7_xhdl86        : std_logic_vector(2 downto 0);
    signal HTRANS_S7_xhdl103      : std_logic_vector(1 downto 0);
    signal HWRITE_S7_xhdl137      : std_logic;
    signal HWDATA_S7_xhdl120      : std_logic_vector(31 downto 0);
    signal HREADY_S7_xhdl50       : std_logic;
    signal HMASTLOCK_S7_xhdl29    : std_logic;
    signal HSEL_S8_xhdl70         : std_logic;
    signal HADDR_S8_xhdl14        : std_logic_vector(31 downto 0);
    signal HSIZE_S8_xhdl87        : std_logic_vector(2 downto 0);
    signal HTRANS_S8_xhdl104      : std_logic_vector(1 downto 0);
    signal HWRITE_S8_xhdl138      : std_logic;
    signal HWDATA_S8_xhdl121      : std_logic_vector(31 downto 0);
    signal HREADY_S8_xhdl51       : std_logic;
    signal HMASTLOCK_S8_xhdl30    : std_logic;
    signal HSEL_S9_xhdl71         : std_logic;
    signal HADDR_S9_xhdl15        : std_logic_vector(31 downto 0);
    signal HSIZE_S9_xhdl88        : std_logic_vector(2 downto 0);
    signal HTRANS_S9_xhdl105      : std_logic_vector(1 downto 0);
    signal HWRITE_S9_xhdl139      : std_logic;
    signal HWDATA_S9_xhdl122      : std_logic_vector(31 downto 0);
    signal HREADY_S9_xhdl52       : std_logic;
    signal HMASTLOCK_S9_xhdl31    : std_logic;
    signal HSEL_S10_xhdl58        : std_logic;
    signal HADDR_S10_xhdl2        : std_logic_vector(31 downto 0);
    signal HSIZE_S10_xhdl75       : std_logic_vector(2 downto 0);
    signal HTRANS_S10_xhdl92      : std_logic_vector(1 downto 0);
    signal HWRITE_S10_xhdl126     : std_logic;
    signal HWDATA_S10_xhdl109     : std_logic_vector(31 downto 0);
    signal HREADY_S10_xhdl39      : std_logic;
    signal HMASTLOCK_S10_xhdl18   : std_logic;
    signal HSEL_S11_xhdl59        : std_logic;
    signal HADDR_S11_xhdl3        : std_logic_vector(31 downto 0);
    signal HSIZE_S11_xhdl76       : std_logic_vector(2 downto 0);
    signal HTRANS_S11_xhdl93      : std_logic_vector(1 downto 0);
    signal HWRITE_S11_xhdl127     : std_logic;
    signal HWDATA_S11_xhdl110     : std_logic_vector(31 downto 0);
    signal HREADY_S11_xhdl40      : std_logic;
    signal HMASTLOCK_S11_xhdl19   : std_logic;
    signal HSEL_S12_xhdl60        : std_logic;
    signal HADDR_S12_xhdl4        : std_logic_vector(31 downto 0);
    signal HSIZE_S12_xhdl77       : std_logic_vector(2 downto 0);
    signal HTRANS_S12_xhdl94      : std_logic_vector(1 downto 0);
    signal HWRITE_S12_xhdl128     : std_logic;
    signal HWDATA_S12_xhdl111     : std_logic_vector(31 downto 0);
    signal HREADY_S12_xhdl41      : std_logic;
    signal HMASTLOCK_S12_xhdl20   : std_logic;
    signal HSEL_S13_xhdl61        : std_logic;
    signal HADDR_S13_xhdl5        : std_logic_vector(31 downto 0);
    signal HSIZE_S13_xhdl78       : std_logic_vector(2 downto 0);
    signal HTRANS_S13_xhdl95      : std_logic_vector(1 downto 0);
    signal HWRITE_S13_xhdl129     : std_logic;
    signal HWDATA_S13_xhdl112     : std_logic_vector(31 downto 0);
    signal HREADY_S13_xhdl42      : std_logic;
    signal HMASTLOCK_S13_xhdl21   : std_logic;
    signal HSEL_S14_xhdl62        : std_logic;
    signal HADDR_S14_xhdl6        : std_logic_vector(31 downto 0);
    signal HSIZE_S14_xhdl79       : std_logic_vector(2 downto 0);
    signal HTRANS_S14_xhdl96      : std_logic_vector(1 downto 0);
    signal HWRITE_S14_xhdl130     : std_logic;
    signal HWDATA_S14_xhdl113     : std_logic_vector(31 downto 0);
    signal HREADY_S14_xhdl43      : std_logic;
    signal HMASTLOCK_S14_xhdl22   : std_logic;
    signal HSEL_S15_xhdl63        : std_logic;
    signal HADDR_S15_xhdl7        : std_logic_vector(31 downto 0);
    signal HSIZE_S15_xhdl80       : std_logic_vector(2 downto 0);
    signal HTRANS_S15_xhdl97      : std_logic_vector(1 downto 0);
    signal HWRITE_S15_xhdl131     : std_logic;
    signal HWDATA_S15_xhdl114     : std_logic_vector(31 downto 0);
    signal HREADY_S15_xhdl44      : std_logic;
    signal HMASTLOCK_S15_xhdl23   : std_logic;
    signal HSEL_S16_xhdl72        : std_logic;
    signal HSIZE_S16_xhdl89       : std_logic_vector(2 downto 0);
    signal HTRANS_S16_xhdl106     : std_logic_vector(1 downto 0);
    signal HWRITE_S16_xhdl140     : std_logic;
    signal HWDATA_S16_xhdl123     : std_logic_vector(31 downto 0);
    signal HREADY_S16_xhdl53      : std_logic;
    signal HMASTLOCK_S16_xhdl32   : std_logic;
begin
    -- Drive referenced outputs
    HRESP_M0 <= HRESP_M0_xhdl54;
    HRDATA_M0 <= HRDATA_M0_xhdl33;
    HREADY_M0 <= HREADY_M0_xhdl35;
    HRESP_M1 <= HRESP_M1_xhdl55;
    HRDATA_M1 <= HRDATA_M1_xhdl34;
    HREADY_M1 <= HREADY_M1_xhdl36;
    HRESP_M2 <= HRESP_M2_xhdl54;
    HRDATA_M2 <= HRDATA_M2_xhdl33;
    HREADY_M2 <= HREADY_M2_xhdl35;
    HRESP_M3 <= HRESP_M3_xhdl55;
    HRDATA_M3 <= HRDATA_M3_xhdl34;
    HREADY_M3 <= HREADY_M3_xhdl36;
    HSEL_S0 <= HSEL_S0_xhdl56;
    HADDR_S0 <= HADDR_S0_xhdl0;
    HSIZE_S0 <= HSIZE_S0_xhdl73;
    HTRANS_S0 <= HTRANS_S0_xhdl90;
    HWRITE_S0 <= HWRITE_S0_xhdl124;
    HWDATA_S0 <= HWDATA_S0_xhdl107;
    HREADY_S0 <= HREADY_S0_xhdl37;
    HMASTLOCK_S0 <= HMASTLOCK_S0_xhdl16;
    HSEL_S1 <= HSEL_S1_xhdl57;
    HADDR_S1 <= HADDR_S1_xhdl1;
    HSIZE_S1 <= HSIZE_S1_xhdl74;
    HTRANS_S1 <= HTRANS_S1_xhdl91;
    HWRITE_S1 <= HWRITE_S1_xhdl125;
    HWDATA_S1 <= HWDATA_S1_xhdl108;
    HREADY_S1 <= HREADY_S1_xhdl38;
    HMASTLOCK_S1 <= HMASTLOCK_S1_xhdl17;
    HSEL_S2 <= HSEL_S2_xhdl64;
    HADDR_S2 <= HADDR_S2_xhdl8;
    HSIZE_S2 <= HSIZE_S2_xhdl81;
    HTRANS_S2 <= HTRANS_S2_xhdl98;
    HWRITE_S2 <= HWRITE_S2_xhdl132;
    HWDATA_S2 <= HWDATA_S2_xhdl115;
    HREADY_S2 <= HREADY_S2_xhdl45;
    HMASTLOCK_S2 <= HMASTLOCK_S2_xhdl24;
    HSEL_S3 <= HSEL_S3_xhdl65;
    HADDR_S3 <= HADDR_S3_xhdl9;
    HSIZE_S3 <= HSIZE_S3_xhdl82;
    HTRANS_S3 <= HTRANS_S3_xhdl99;
    HWRITE_S3 <= HWRITE_S3_xhdl133;
    HWDATA_S3 <= HWDATA_S3_xhdl116;
    HREADY_S3 <= HREADY_S3_xhdl46;
    HMASTLOCK_S3 <= HMASTLOCK_S3_xhdl25;
    HSEL_S4 <= HSEL_S4_xhdl66;
    HADDR_S4 <= HADDR_S4_xhdl10;
    HSIZE_S4 <= HSIZE_S4_xhdl83;
    HTRANS_S4 <= HTRANS_S4_xhdl100;
    HWRITE_S4 <= HWRITE_S4_xhdl134;
    HWDATA_S4 <= HWDATA_S4_xhdl117;
    HREADY_S4 <= HREADY_S4_xhdl47;
    HMASTLOCK_S4 <= HMASTLOCK_S4_xhdl26;
    HSEL_S5 <= HSEL_S5_xhdl67;
    HADDR_S5 <= HADDR_S5_xhdl11;
    HSIZE_S5 <= HSIZE_S5_xhdl84;
    HTRANS_S5 <= HTRANS_S5_xhdl101;
    HWRITE_S5 <= HWRITE_S5_xhdl135;
    HWDATA_S5 <= HWDATA_S5_xhdl118;
    HREADY_S5 <= HREADY_S5_xhdl48;
    HMASTLOCK_S5 <= HMASTLOCK_S5_xhdl27;
    HSEL_S6 <= HSEL_S6_xhdl68;
    HADDR_S6 <= HADDR_S6_xhdl12;
    HSIZE_S6 <= HSIZE_S6_xhdl85;
    HTRANS_S6 <= HTRANS_S6_xhdl102;
    HWRITE_S6 <= HWRITE_S6_xhdl136;
    HWDATA_S6 <= HWDATA_S6_xhdl119;
    HREADY_S6 <= HREADY_S6_xhdl49;
    HMASTLOCK_S6 <= HMASTLOCK_S6_xhdl28;
    HSEL_S7 <= HSEL_S7_xhdl69;
    HADDR_S7 <= HADDR_S7_xhdl13;
    HSIZE_S7 <= HSIZE_S7_xhdl86;
    HTRANS_S7 <= HTRANS_S7_xhdl103;
    HWRITE_S7 <= HWRITE_S7_xhdl137;
    HWDATA_S7 <= HWDATA_S7_xhdl120;
    HREADY_S7 <= HREADY_S7_xhdl50;
    HMASTLOCK_S7 <= HMASTLOCK_S7_xhdl29;
    HSEL_S8 <= HSEL_S8_xhdl70;
    HADDR_S8 <= HADDR_S8_xhdl14;
    HSIZE_S8 <= HSIZE_S8_xhdl87;
    HTRANS_S8 <= HTRANS_S8_xhdl104;
    HWRITE_S8 <= HWRITE_S8_xhdl138;
    HWDATA_S8 <= HWDATA_S8_xhdl121;
    HREADY_S8 <= HREADY_S8_xhdl51;
    HMASTLOCK_S8 <= HMASTLOCK_S8_xhdl30;
    HSEL_S9 <= HSEL_S9_xhdl71;
    HADDR_S9 <= HADDR_S9_xhdl15;
    HSIZE_S9 <= HSIZE_S9_xhdl88;
    HTRANS_S9 <= HTRANS_S9_xhdl105;
    HWRITE_S9 <= HWRITE_S9_xhdl139;
    HWDATA_S9 <= HWDATA_S9_xhdl122;
    HREADY_S9 <= HREADY_S9_xhdl52;
    HMASTLOCK_S9 <= HMASTLOCK_S9_xhdl31;
    HSEL_S10 <= HSEL_S10_xhdl58;
    HADDR_S10 <= HADDR_S10_xhdl2;
    HSIZE_S10 <= HSIZE_S10_xhdl75;
    HTRANS_S10 <= HTRANS_S10_xhdl92;
    HWRITE_S10 <= HWRITE_S10_xhdl126;
    HWDATA_S10 <= HWDATA_S10_xhdl109;
    HREADY_S10 <= HREADY_S10_xhdl39;
    HMASTLOCK_S10 <= HMASTLOCK_S10_xhdl18;
    HSEL_S11 <= HSEL_S11_xhdl59;
    HADDR_S11 <= HADDR_S11_xhdl3;
    HSIZE_S11 <= HSIZE_S11_xhdl76;
    HTRANS_S11 <= HTRANS_S11_xhdl93;
    HWRITE_S11 <= HWRITE_S11_xhdl127;
    HWDATA_S11 <= HWDATA_S11_xhdl110;
    HREADY_S11 <= HREADY_S11_xhdl40;
    HMASTLOCK_S11 <= HMASTLOCK_S11_xhdl19;
    HSEL_S12 <= HSEL_S12_xhdl60;
    HADDR_S12 <= HADDR_S12_xhdl4;
    HSIZE_S12 <= HSIZE_S12_xhdl77;
    HTRANS_S12 <= HTRANS_S12_xhdl94;
    HWRITE_S12 <= HWRITE_S12_xhdl128;
    HWDATA_S12 <= HWDATA_S12_xhdl111;
    HREADY_S12 <= HREADY_S12_xhdl41;
    HMASTLOCK_S12 <= HMASTLOCK_S12_xhdl20;
    HSEL_S13 <= HSEL_S13_xhdl61;
    HADDR_S13 <= HADDR_S13_xhdl5;
    HSIZE_S13 <= HSIZE_S13_xhdl78;
    HTRANS_S13 <= HTRANS_S13_xhdl95;
    HWRITE_S13 <= HWRITE_S13_xhdl129;
    HWDATA_S13 <= HWDATA_S13_xhdl112;
    HREADY_S13 <= HREADY_S13_xhdl42;
    HMASTLOCK_S13 <= HMASTLOCK_S13_xhdl21;
    HSEL_S14 <= HSEL_S14_xhdl62;
    HADDR_S14 <= HADDR_S14_xhdl6;
    HSIZE_S14 <= HSIZE_S14_xhdl79;
    HTRANS_S14 <= HTRANS_S14_xhdl96;
    HWRITE_S14 <= HWRITE_S14_xhdl130;
    HWDATA_S14 <= HWDATA_S14_xhdl113;
    HREADY_S14 <= HREADY_S14_xhdl43;
    HMASTLOCK_S14 <= HMASTLOCK_S14_xhdl22;
    HSEL_S15 <= HSEL_S15_xhdl63;
    HADDR_S15 <= HADDR_S15_xhdl7;
    HSIZE_S15 <= HSIZE_S15_xhdl80;
    HTRANS_S15 <= HTRANS_S15_xhdl97;
    HWRITE_S15 <= HWRITE_S15_xhdl131;
    HWDATA_S15 <= HWDATA_S15_xhdl114;
    HREADY_S15 <= HREADY_S15_xhdl44;
    HMASTLOCK_S15 <= HMASTLOCK_S15_xhdl23;
    HSEL_S16 <= HSEL_S16_xhdl72;
    HSIZE_S16 <= HSIZE_S16_xhdl89;
    HTRANS_S16 <= HTRANS_S16_xhdl106;
    HWRITE_S16 <= HWRITE_S16_xhdl140;
    HWDATA_S16 <= HWDATA_S16_xhdl123;
    HREADY_S16 <= HREADY_S16_xhdl53;
    HMASTLOCK_S16 <= HMASTLOCK_S16_xhdl32;
    HTRANS_S0_xhdl90(0) <= '0';
    HTRANS_S1_xhdl91(0) <= '0';
    HTRANS_S2_xhdl98(0) <= '0';
    HTRANS_S3_xhdl99(0) <= '0';
    HTRANS_S4_xhdl100(0) <= '0';
    HTRANS_S5_xhdl101(0) <= '0';
    HTRANS_S6_xhdl102(0) <= '0';
    HTRANS_S7_xhdl103(0) <= '0';
    HTRANS_S8_xhdl104(0) <= '0';
    HTRANS_S9_xhdl105(0) <= '0';
    HTRANS_S10_xhdl92(0) <= '0';
    HTRANS_S11_xhdl93(0) <= '0';
    HTRANS_S12_xhdl94(0) <= '0';
    HTRANS_S13_xhdl95(0) <= '0';
    HTRANS_S14_xhdl96(0) <= '0';
    HTRANS_S15_xhdl97(0) <= '0';
    HTRANS_S16_xhdl106(0) <= '0';
    HRESP_M0_xhdl54(1) <= '0';
    HRESP_M1_xhdl55(1) <= '0';
    HRESP_M2_xhdl54(1) <= '0';
    HRESP_M3_xhdl55(1) <= '0';
    HBURST_S0 <= "000";
    HBURST_S1 <= "000";
    HBURST_S2 <= "000";
    HBURST_S3 <= "000";
    HBURST_S4 <= "000";
    HBURST_S5 <= "000";
    HBURST_S6 <= "000";
    HBURST_S7 <= "000";
    HBURST_S8 <= "000";
    HBURST_S9 <= "000";
    HBURST_S10 <= "000";
    HBURST_S11 <= "000";
    HBURST_S12 <= "000";
    HBURST_S13 <= "000";
    HBURST_S14 <= "000";
    HBURST_S15 <= "000";
    HBURST_S16 <= "000";
    HPROT_S0 <= "0000";
    HPROT_S1 <= "0000";
    HPROT_S2 <= "0000";
    HPROT_S3 <= "0000";
    HPROT_S4 <= "0000";
    HPROT_S5 <= "0000";
    HPROT_S6 <= "0000";
    HPROT_S7 <= "0000";
    HPROT_S8 <= "0000";
    HPROT_S9 <= "0000";
    HPROT_S10 <= "0000";
    HPROT_S11 <= "0000";
    HPROT_S12 <= "0000";
    HPROT_S13 <= "0000";
    HPROT_S14 <= "0000";
    HPROT_S15 <= "0000";
    HPROT_S16 <= "0000";


    matrix4x16 : COREAHBLITE_MATRIX4X16
        generic map (
            MEMSPACE          => MEMSPACE,
            HADDR_SHG_CFG     => HADDR_SHG_CFG,
            M0_AHBSLOTENABLE  => M0_AHBSLOTENABLE,
            M1_AHBSLOTENABLE  => M1_AHBSLOTENABLE,
            M2_AHBSLOTENABLE  => M2_AHBSLOTENABLE,
            M3_AHBSLOTENABLE  => M3_AHBSLOTENABLE,
            SC                => SC,
			SYNC_RESET        => SYNC_RESET
        )
        port map (
            HCLK           => HCLK,
            HRESETN        => HRESETN,
            REMAP_M0       => REMAP_M0,
            HADDR_M0       => HADDR_M0,
            HMASTLOCK_M0   => HMASTLOCK_M0,
            HSIZE_M0       => HSIZE_M0,
            HTRANS_M0      => HTRANS_M0(1),
            HWRITE_M0      => HWRITE_M0,
            HWDATA_M0      => HWDATA_M0,
            HRESP_M0       => HRESP_M0_xhdl54(0),
            HRDATA_M0      => HRDATA_M0_xhdl33,
            HREADY_M0      => HREADY_M0_xhdl35,
            HADDR_M1       => HADDR_M1,
            HMASTLOCK_M1   => HMASTLOCK_M1,
            HSIZE_M1       => HSIZE_M1,
            HTRANS_M1      => HTRANS_M1(1),
            HWRITE_M1      => HWRITE_M1,
            HWDATA_M1      => HWDATA_M1,
            HRESP_M1       => HRESP_M1_xhdl55(0),
            HRDATA_M1      => HRDATA_M1_xhdl34,
            HREADY_M1      => HREADY_M1_xhdl36,
            HADDR_M2       => HADDR_M2,
            HMASTLOCK_M2   => HMASTLOCK_M2,
            HSIZE_M2       => HSIZE_M2,
            HTRANS_M2      => HTRANS_M2(1),
            HWRITE_M2      => HWRITE_M2,
            HWDATA_M2      => HWDATA_M2,
            HRESP_M2       => HRESP_M2_xhdl54(0),
            HRDATA_M2      => HRDATA_M2_xhdl33,
            HREADY_M2      => HREADY_M2_xhdl35,
            HADDR_M3       => HADDR_M3,
            HMASTLOCK_M3   => HMASTLOCK_M3,
            HSIZE_M3       => HSIZE_M3,
            HTRANS_M3      => HTRANS_M3(1),
            HWRITE_M3      => HWRITE_M3,
            HWDATA_M3      => HWDATA_M3,
            HRESP_M3       => HRESP_M3_xhdl55(0),
            HRDATA_M3      => HRDATA_M3_xhdl34,
            HREADY_M3      => HREADY_M3_xhdl36,
            HRDATA_S0      => HRDATA_S0,
            HREADYOUT_S0   => HREADYOUT_S0,
            HRESP_S0       => HRESP_S0(0),
            HSEL_S0        => HSEL_S0_xhdl56,
            HADDR_S0       => HADDR_S0_xhdl0,
            HSIZE_S0       => HSIZE_S0_xhdl73,
            HTRANS_S0      => HTRANS_S0_xhdl90(1),
            HWRITE_S0      => HWRITE_S0_xhdl124,
            HWDATA_S0      => HWDATA_S0_xhdl107,
            HREADY_S0      => HREADY_S0_xhdl37,
            HMASTLOCK_S0   => HMASTLOCK_S0_xhdl16,
            HRDATA_S1      => HRDATA_S1,
            HREADYOUT_S1   => HREADYOUT_S1,
            HRESP_S1       => HRESP_S1(0),
            HSEL_S1        => HSEL_S1_xhdl57,
            HADDR_S1       => HADDR_S1_xhdl1,
            HSIZE_S1       => HSIZE_S1_xhdl74,
            HTRANS_S1      => HTRANS_S1_xhdl91(1),
            HWRITE_S1      => HWRITE_S1_xhdl125,
            HWDATA_S1      => HWDATA_S1_xhdl108,
            HREADY_S1      => HREADY_S1_xhdl38,
            HMASTLOCK_S1   => HMASTLOCK_S1_xhdl17,
            HRDATA_S2      => HRDATA_S2,
            HREADYOUT_S2   => HREADYOUT_S2,
            HRESP_S2       => HRESP_S2(0),
            HSEL_S2        => HSEL_S2_xhdl64,
            HADDR_S2       => HADDR_S2_xhdl8,
            HSIZE_S2       => HSIZE_S2_xhdl81,
            HTRANS_S2      => HTRANS_S2_xhdl98(1),
            HWRITE_S2      => HWRITE_S2_xhdl132,
            HWDATA_S2      => HWDATA_S2_xhdl115,
            HREADY_S2      => HREADY_S2_xhdl45,
            HMASTLOCK_S2   => HMASTLOCK_S2_xhdl24,
            HRDATA_S3      => HRDATA_S3,
            HREADYOUT_S3   => HREADYOUT_S3,
            HRESP_S3       => HRESP_S3(0),
            HSEL_S3        => HSEL_S3_xhdl65,
            HADDR_S3       => HADDR_S3_xhdl9,
            HSIZE_S3       => HSIZE_S3_xhdl82,
            HTRANS_S3      => HTRANS_S3_xhdl99(1),
            HWRITE_S3      => HWRITE_S3_xhdl133,
            HWDATA_S3      => HWDATA_S3_xhdl116,
            HREADY_S3      => HREADY_S3_xhdl46,
            HMASTLOCK_S3   => HMASTLOCK_S3_xhdl25,
            HRDATA_S4      => HRDATA_S4,
            HREADYOUT_S4   => HREADYOUT_S4,
            HRESP_S4       => HRESP_S4(0),
            HSEL_S4        => HSEL_S4_xhdl66,
            HADDR_S4       => HADDR_S4_xhdl10,
            HSIZE_S4       => HSIZE_S4_xhdl83,
            HTRANS_S4      => HTRANS_S4_xhdl100(1),
            HWRITE_S4      => HWRITE_S4_xhdl134,
            HWDATA_S4      => HWDATA_S4_xhdl117,
            HREADY_S4      => HREADY_S4_xhdl47,
            HMASTLOCK_S4   => HMASTLOCK_S4_xhdl26,
            HRDATA_S5      => HRDATA_S5,
            HREADYOUT_S5   => HREADYOUT_S5,
            HRESP_S5       => HRESP_S5(0),
            HSEL_S5        => HSEL_S5_xhdl67,
            HADDR_S5       => HADDR_S5_xhdl11,
            HSIZE_S5       => HSIZE_S5_xhdl84,
            HTRANS_S5      => HTRANS_S5_xhdl101(1),
            HWRITE_S5      => HWRITE_S5_xhdl135,
            HWDATA_S5      => HWDATA_S5_xhdl118,
            HREADY_S5      => HREADY_S5_xhdl48,
            HMASTLOCK_S5   => HMASTLOCK_S5_xhdl27,
            HRDATA_S6      => HRDATA_S6,
            HREADYOUT_S6   => HREADYOUT_S6,
            HRESP_S6       => HRESP_S6(0),
            HSEL_S6        => HSEL_S6_xhdl68,
            HADDR_S6       => HADDR_S6_xhdl12,
            HSIZE_S6       => HSIZE_S6_xhdl85,
            HTRANS_S6      => HTRANS_S6_xhdl102(1),
            HWRITE_S6      => HWRITE_S6_xhdl136,
            HWDATA_S6      => HWDATA_S6_xhdl119,
            HREADY_S6      => HREADY_S6_xhdl49,
            HMASTLOCK_S6   => HMASTLOCK_S6_xhdl28,
            HRDATA_S7      => HRDATA_S7,
            HREADYOUT_S7   => HREADYOUT_S7,
            HRESP_S7       => HRESP_S7(0),
            HSEL_S7        => HSEL_S7_xhdl69,
            HADDR_S7       => HADDR_S7_xhdl13,
            HSIZE_S7       => HSIZE_S7_xhdl86,
            HTRANS_S7      => HTRANS_S7_xhdl103(1),
            HWRITE_S7      => HWRITE_S7_xhdl137,
            HWDATA_S7      => HWDATA_S7_xhdl120,
            HREADY_S7      => HREADY_S7_xhdl50,
            HMASTLOCK_S7   => HMASTLOCK_S7_xhdl29,
            HRDATA_S8      => HRDATA_S8,
            HREADYOUT_S8   => HREADYOUT_S8,
            HRESP_S8       => HRESP_S8(0),
            HSEL_S8        => HSEL_S8_xhdl70,
            HADDR_S8       => HADDR_S8_xhdl14,
            HSIZE_S8       => HSIZE_S8_xhdl87,
            HTRANS_S8      => HTRANS_S8_xhdl104(1),
            HWRITE_S8      => HWRITE_S8_xhdl138,
            HWDATA_S8      => HWDATA_S8_xhdl121,
            HREADY_S8      => HREADY_S8_xhdl51,
            HMASTLOCK_S8   => HMASTLOCK_S8_xhdl30,
            HRDATA_S9      => HRDATA_S9,
            HREADYOUT_S9   => HREADYOUT_S9,
            HRESP_S9       => HRESP_S9(0),
            HSEL_S9        => HSEL_S9_xhdl71,
            HADDR_S9       => HADDR_S9_xhdl15,
            HSIZE_S9       => HSIZE_S9_xhdl88,
            HTRANS_S9      => HTRANS_S9_xhdl105(1),
            HWRITE_S9      => HWRITE_S9_xhdl139,
            HWDATA_S9      => HWDATA_S9_xhdl122,
            HREADY_S9      => HREADY_S9_xhdl52,
            HMASTLOCK_S9   => HMASTLOCK_S9_xhdl31,
            HRDATA_S10     => HRDATA_S10,
            HREADYOUT_S10  => HREADYOUT_S10,
            HRESP_S10      => HRESP_S10(0),
            HSEL_S10       => HSEL_S10_xhdl58,
            HADDR_S10      => HADDR_S10_xhdl2,
            HSIZE_S10      => HSIZE_S10_xhdl75,
            HTRANS_S10     => HTRANS_S10_xhdl92(1),
            HWRITE_S10     => HWRITE_S10_xhdl126,
            HWDATA_S10     => HWDATA_S10_xhdl109,
            HREADY_S10     => HREADY_S10_xhdl39,
            HMASTLOCK_S10  => HMASTLOCK_S10_xhdl18,
            HRDATA_S11     => HRDATA_S11,
            HREADYOUT_S11  => HREADYOUT_S11,
            HRESP_S11      => HRESP_S11(0),
            HSEL_S11       => HSEL_S11_xhdl59,
            HADDR_S11      => HADDR_S11_xhdl3,
            HSIZE_S11      => HSIZE_S11_xhdl76,
            HTRANS_S11     => HTRANS_S11_xhdl93(1),
            HWRITE_S11     => HWRITE_S11_xhdl127,
            HWDATA_S11     => HWDATA_S11_xhdl110,
            HREADY_S11     => HREADY_S11_xhdl40,
            HMASTLOCK_S11  => HMASTLOCK_S11_xhdl19,
            HRDATA_S12     => HRDATA_S12,
            HREADYOUT_S12  => HREADYOUT_S12,
            HRESP_S12      => HRESP_S12(0),
            HSEL_S12       => HSEL_S12_xhdl60,
            HADDR_S12      => HADDR_S12_xhdl4,
            HSIZE_S12      => HSIZE_S12_xhdl77,
            HTRANS_S12     => HTRANS_S12_xhdl94(1),
            HWRITE_S12     => HWRITE_S12_xhdl128,
            HWDATA_S12     => HWDATA_S12_xhdl111,
            HREADY_S12     => HREADY_S12_xhdl41,
            HMASTLOCK_S12  => HMASTLOCK_S12_xhdl20,
            HRDATA_S13     => HRDATA_S13,
            HREADYOUT_S13  => HREADYOUT_S13,
            HRESP_S13      => HRESP_S13(0),
            HSEL_S13       => HSEL_S13_xhdl61,
            HADDR_S13      => HADDR_S13_xhdl5,
            HSIZE_S13      => HSIZE_S13_xhdl78,
            HTRANS_S13     => HTRANS_S13_xhdl95(1),
            HWRITE_S13     => HWRITE_S13_xhdl129,
            HWDATA_S13     => HWDATA_S13_xhdl112,
            HREADY_S13     => HREADY_S13_xhdl42,
            HMASTLOCK_S13  => HMASTLOCK_S13_xhdl21,
            HRDATA_S14     => HRDATA_S14,
            HREADYOUT_S14  => HREADYOUT_S14,
            HRESP_S14      => HRESP_S14(0),
            HSEL_S14       => HSEL_S14_xhdl62,
            HADDR_S14      => HADDR_S14_xhdl6,
            HSIZE_S14      => HSIZE_S14_xhdl79,
            HTRANS_S14     => HTRANS_S14_xhdl96(1),
            HWRITE_S14     => HWRITE_S14_xhdl130,
            HWDATA_S14     => HWDATA_S14_xhdl113,
            HREADY_S14     => HREADY_S14_xhdl43,
            HMASTLOCK_S14  => HMASTLOCK_S14_xhdl22,
            HRDATA_S15     => HRDATA_S15,
            HREADYOUT_S15  => HREADYOUT_S15,
            HRESP_S15      => HRESP_S15(0),
            HSEL_S15       => HSEL_S15_xhdl63,
            HADDR_S15      => HADDR_S15_xhdl7,
            HSIZE_S15      => HSIZE_S15_xhdl80,
            HTRANS_S15     => HTRANS_S15_xhdl97(1),
            HWRITE_S15     => HWRITE_S15_xhdl131,
            HWDATA_S15     => HWDATA_S15_xhdl114,
            HREADY_S15     => HREADY_S15_xhdl44,
            HMASTLOCK_S15  => HMASTLOCK_S15_xhdl23,
            HRDATA_S16     => HRDATA_S16,
            HREADYOUT_S16  => HREADYOUT_S16,
            HRESP_S16      => HRESP_S16(0),
            HSEL_S16       => HSEL_S16_xhdl72,
            HADDR_S16      => HADDR_S16,
            HSIZE_S16      => HSIZE_S16_xhdl89,
            HTRANS_S16     => HTRANS_S16_xhdl106(1),
            HWRITE_S16     => HWRITE_S16_xhdl140,
            HWDATA_S16     => HWDATA_S16_xhdl123,
            HREADY_S16     => HREADY_S16_xhdl53,
            HMASTLOCK_S16  => HMASTLOCK_S16_xhdl32
        );

end architecture CoreAHBLite_arch;
