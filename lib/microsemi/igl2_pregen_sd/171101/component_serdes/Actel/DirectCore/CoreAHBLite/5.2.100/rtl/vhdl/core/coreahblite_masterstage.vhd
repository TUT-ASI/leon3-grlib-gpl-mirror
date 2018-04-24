-- ********************************************************************/
-- Actel Corporation Proprietary and Confidential
-- Copyright 2010 Actel Corporation.  All rights reserved.
--
-- ANY USE OR REDISTRIBUTION IN PART OR IN WHOLE MUST BE HANDLED IN
-- ACCORDANCE WITH THE ACTEL LICENSE AGREEMENT AND MUST BE APPROVED
-- IN ADVANCE IN WRITING.
--
-- Description:	CoreAHBLite master stage logic for
--				matrix (2 masters by 16 slaves),
--				instantiates the following modules:
--				COREAHBLITE_ADDRDEC, COREAHBLITE_DEFAULTSLAVESM
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
entity COREAHBLITE_MASTERSTAGE is
    generic (
        MEMSPACE            : integer range 0 to 6 := 0;
        HADDR_SHG_CFG       : integer range 0 to 1 := 1;
        SC                  : integer range 0 to (2**16)-1 := 0;
        M_AHBSLOTENABLE     : integer range 0 to (2**17)-1 := (2**17)-1;
		SYNC_RESET          : integer := 0
    );
    port (
        HCLK                : in std_logic;
        HRESETN             : in std_logic;
        HADDR               : in std_logic_vector(31 downto 0);
        HMASTLOCK           : in std_logic;
        HSIZE               : in std_logic_vector(2 downto 0);
        HTRANS              : in std_logic;
        HWRITE              : in std_logic;
        HRESP               : out std_logic;
        HRDATA              : out std_logic_vector(31 downto 0);
        HREADY_M            : out std_logic;
        REMAP               : in std_logic;
        SADDRREADY          : in std_logic_vector(16 downto 0);
        SDATAREADY          : in std_logic_vector(16 downto 0);
        SHRESP              : in std_logic_vector(16 downto 0);
        GATEDHADDR          : out std_logic_vector(31 downto 0);
        GATEDHMASTLOCK      : out std_logic;
        GATEDHSIZE          : out std_logic_vector(2 downto 0);
        GATEDHTRANS         : out std_logic;
        GATEDHWRITE         : out std_logic;
        SADDRSEL            : out std_logic_vector(16 downto 0);
        SDATASEL            : out std_logic_vector(16 downto 0);
        PREVDATASLAVEREADY  : out std_logic;
        HRDATA_S0           : in std_logic_vector(31 downto 0);
        HREADYOUT_S0        : in std_logic;
        HRDATA_S1           : in std_logic_vector(31 downto 0);
        HREADYOUT_S1        : in std_logic;
        HRDATA_S2           : in std_logic_vector(31 downto 0);
        HREADYOUT_S2        : in std_logic;
        HRDATA_S3           : in std_logic_vector(31 downto 0);
        HREADYOUT_S3        : in std_logic;
        HRDATA_S4           : in std_logic_vector(31 downto 0);
        HREADYOUT_S4        : in std_logic;
        HRDATA_S5           : in std_logic_vector(31 downto 0);
        HREADYOUT_S5        : in std_logic;
        HRDATA_S6           : in std_logic_vector(31 downto 0);
        HREADYOUT_S6        : in std_logic;
        HRDATA_S7           : in std_logic_vector(31 downto 0);
        HREADYOUT_S7        : in std_logic;
        HRDATA_S8           : in std_logic_vector(31 downto 0);
        HREADYOUT_S8        : in std_logic;
        HRDATA_S9           : in std_logic_vector(31 downto 0);
        HREADYOUT_S9        : in std_logic;
        HRDATA_S10          : in std_logic_vector(31 downto 0);
        HREADYOUT_S10       : in std_logic;
        HRDATA_S11          : in std_logic_vector(31 downto 0);
        HREADYOUT_S11       : in std_logic;
        HRDATA_S12          : in std_logic_vector(31 downto 0);
        HREADYOUT_S12       : in std_logic;
        HRDATA_S13          : in std_logic_vector(31 downto 0);
        HREADYOUT_S13       : in std_logic;
        HRDATA_S14          : in std_logic_vector(31 downto 0);
        HREADYOUT_S14       : in std_logic;
        HRDATA_S15          : in std_logic_vector(31 downto 0);
        HREADYOUT_S15       : in std_logic;
        HRDATA_S16          : in std_logic_vector(31 downto 0);
        HREADYOUT_S16       : in std_logic
    );
end entity COREAHBLITE_MASTERSTAGE;

architecture COREAHBLITE_MASTERSTAGE_arch of COREAHBLITE_MASTERSTAGE is


function or_v (
    v : std_logic_vector) return std_logic is
    variable sl : std_logic := '0';
begin
    for i in v'range loop
       sl := sl or v(i);
    end loop;
    return(sl);
end or_v;

constant IDLE                 : std_logic := '0';
constant REGISTERED           : std_logic := '1';
constant SLAVE_NONE           : std_logic_vector(16 downto 0):=(others=>'0');
constant CLIENT_NONE          : std_logic_vector(15 downto 0):=(others=>'0');

constant M_AHBSLOTENABLE_slv  : std_logic_vector(16 downto 0):=
	std_logic_vector(to_unsigned(M_AHBSLOTENABLE,17));

    component COREAHBLITE_ADDRDEC is
        generic (
            MEMSPACE         : integer range 0 to 6 := 0;
            HADDR_SHG_CFG    : integer range 0 to 1 := 0;
            M_AHBSLOTENABLE  : integer range 0 to (2**17)-1 := (2**17)-1;
            SC               : integer range 0 to (2**16)-1 := 0
        );
        port (
			ADDR                    : in  std_logic_vector(31 downto 0);
			REMAP                   : in  std_logic;
			ADDRDEC                 : out std_logic_vector(16 downto 0);
			ABSOLUTEADDR            : out std_logic_vector(31 downto 0);
            RESERVEDDEC             : out std_logic
        );
    end component;

    component COREAHBLITE_DEFAULTSLAVESM is
	    generic(SYNC_RESET : integer := 0);
        port (
            HCLK                : in std_logic;
            HRESETN             : in std_logic;
            DEFSLAVEDATASEL     : in std_logic;
            DEFSLAVEDATAREADY   : out std_logic;
            HRESP_DEFAULT       : out std_logic
        );
    end component;

    signal PREGATEDHADDR            : std_logic_vector(31 downto 0);
    signal masterRegAddrSel         : std_logic;
    signal d_masterRegAddrSel       : std_logic;
    signal masterAddrClockEnable    : std_logic;
    signal regHADDR                 : std_logic_vector(31 downto 0);
    signal regHMASTLOCK             : std_logic;
    signal regHSIZE                 : std_logic_vector(2 downto 0);
    signal regHTRANS                : std_logic;
    signal regHWRITE                : std_logic;
    signal addrRegSMCurrentState    : std_logic;
    signal addrRegSMNextState       : std_logic;
    signal sAddrDec                 : std_logic_vector(16 downto 0);
    signal SADDRSELInt              : std_logic_vector(16 downto 0);
    signal SDATASELInt              : std_logic_vector(16 downto 0);
    signal datasel_onehot           : std_logic_vector(16 downto 0);
    signal DEFSLAVEDATAREADY        : std_logic;
    signal HRESP_DEFAULT            : std_logic;
    signal DEFSLAVEDATASEL          : std_logic;
    signal DEFSLAVEDATASEL0         : std_logic;
    signal DEFSLAVEDATASEL1         : std_logic;
    signal DEFSLAVEDATASEL2         : std_logic;
    signal DEFSLAVEDATASEL3         : std_logic;
    signal DEFSLAVEDATASEL4         : std_logic;
    signal DEFSLAVEDATASEL5         : std_logic;
    signal DEFSLAVEDATASEL6         : std_logic;
    signal DEFSLAVEDATASEL7         : std_logic;
    signal DEFSLAVEDATASEL8         : std_logic;
    signal DEFSLAVEDATASEL9         : std_logic;
    signal DEFSLAVEDATASEL10        : std_logic;
    signal DEFSLAVEDATASEL11        : std_logic;
    signal DEFSLAVEDATASEL12        : std_logic;
    signal DEFSLAVEDATASEL13        : std_logic;
    signal DEFSLAVEDATASEL14        : std_logic;
    signal DEFSLAVEDATASEL15        : std_logic;
    signal DEFSLAVEDATASEL16        : std_logic;

    signal ReservedDecode           : std_logic;
    signal RESERVEDADDRSELInt       : std_logic;
    signal RESERVEDDATASELInt       : std_logic;

    signal HREADY_M_pre             : std_logic;

    -- Declare intermediate signals for referenced outputs
    signal HREADY_M_xhdl3           : std_logic;
    signal GATEDHADDR_xhdl0         : std_logic_vector(31 downto 0);
    signal GATEDHTRANS_xhdl1        : std_logic;
    signal GATEDHWRITE_xhdl2        : std_logic;
    signal PREVDATASLAVEREADY_xhdl4 : std_logic;
    signal aresetn                : std_logic;
    signal sresetn                : std_logic;

begin
    aresetn <= '1' WHEN (SYNC_RESET=1) ELSE HRESETN;
    sresetn <= HRESETN WHEN (SYNC_RESET=1) ELSE '1';
    -- Drive referenced outputs
    HREADY_M <= HREADY_M_pre;
    GATEDHADDR <= GATEDHADDR_xhdl0;
    GATEDHTRANS <= GATEDHTRANS_xhdl1;
    GATEDHWRITE <= GATEDHWRITE_xhdl2;
    PREVDATASLAVEREADY <= PREVDATASLAVEREADY_xhdl4;
    SADDRSEL <= SADDRSELInt(16 downto 0);
    SDATASEL <= SDATASELInt(16 downto 0);
    DEFSLAVEDATASEL0 <= (SDATASELInt(0) and (not(M_AHBSLOTENABLE_slv(0))));
    DEFSLAVEDATASEL1 <= (SDATASELInt(1) and (not(M_AHBSLOTENABLE_slv(1))));
    DEFSLAVEDATASEL2 <= (SDATASELInt(2) and (not(M_AHBSLOTENABLE_slv(2))));
    DEFSLAVEDATASEL3 <= (SDATASELInt(3) and (not(M_AHBSLOTENABLE_slv(3))));
    DEFSLAVEDATASEL4 <= (SDATASELInt(4) and (not(M_AHBSLOTENABLE_slv(4))));
    DEFSLAVEDATASEL5 <= (SDATASELInt(5) and (not(M_AHBSLOTENABLE_slv(5))));
    DEFSLAVEDATASEL6 <= (SDATASELInt(6) and (not(M_AHBSLOTENABLE_slv(6))));
    DEFSLAVEDATASEL7 <= (SDATASELInt(7) and (not(M_AHBSLOTENABLE_slv(7))));
    DEFSLAVEDATASEL8 <= (SDATASELInt(8) and (not(M_AHBSLOTENABLE_slv(8))));
    DEFSLAVEDATASEL9 <= (SDATASELInt(9) and (not(M_AHBSLOTENABLE_slv(9))));
    DEFSLAVEDATASEL10 <= (SDATASELInt(10) and (not(M_AHBSLOTENABLE_slv(10))));
    DEFSLAVEDATASEL11 <= (SDATASELInt(11) and (not(M_AHBSLOTENABLE_slv(11))));
    DEFSLAVEDATASEL12 <= (SDATASELInt(12) and (not(M_AHBSLOTENABLE_slv(12))));
    DEFSLAVEDATASEL13 <= (SDATASELInt(13) and (not(M_AHBSLOTENABLE_slv(13))));
    DEFSLAVEDATASEL14 <= (SDATASELInt(14) and (not(M_AHBSLOTENABLE_slv(14))));
    DEFSLAVEDATASEL15 <= (SDATASELInt(15) and (not(M_AHBSLOTENABLE_slv(15))));
    DEFSLAVEDATASEL16 <= (SDATASELInt(16) and (not(M_AHBSLOTENABLE_slv(16))));

    DEFSLAVEDATASEL	 <=	(
							DEFSLAVEDATASEL0   or DEFSLAVEDATASEL1   or
							DEFSLAVEDATASEL2   or DEFSLAVEDATASEL3   or
							DEFSLAVEDATASEL4   or DEFSLAVEDATASEL5   or
							DEFSLAVEDATASEL6   or DEFSLAVEDATASEL7   or
							DEFSLAVEDATASEL8   or DEFSLAVEDATASEL9   or
							DEFSLAVEDATASEL10  or DEFSLAVEDATASEL11  or
							DEFSLAVEDATASEL12  or DEFSLAVEDATASEL13  or
							DEFSLAVEDATASEL14  or DEFSLAVEDATASEL15  or
							DEFSLAVEDATASEL16
							or RESERVEDDATASELInt
						);

    process (HCLK, aresetn)
    begin
        if ((not(aresetn)) = '1') then
            regHADDR <= "00000000000000000000000000000000";
            regHMASTLOCK <= '0';
            regHSIZE <= "000";
            regHTRANS <= '0';
            regHWRITE <= '0';
        elsif (HCLK'event and HCLK = '1') then
            if ((not(sresetn)) = '1') then
                regHADDR <= "00000000000000000000000000000000";
                regHMASTLOCK <= '0';
                regHSIZE <= "000";
                regHTRANS <= '0';
                regHWRITE <= '0';
		    else
                if (masterAddrClockEnable = '1') then
                    regHADDR <= HADDR;
                    regHMASTLOCK <= HMASTLOCK;
                    regHSIZE <= HSIZE;
                    regHTRANS <= HTRANS;
                    regHWRITE <= HWRITE;
                end if;
            end if;
        end if;
    end process;

    process (masterRegAddrSel, HADDR, HMASTLOCK, HSIZE, HTRANS, HWRITE, regHADDR, regHMASTLOCK, regHSIZE, regHTRANS, regHWRITE)
    begin
        if (masterRegAddrSel = '0') then
            PREGATEDHADDR <= HADDR;
            GATEDHMASTLOCK <= HMASTLOCK;
            GATEDHSIZE <= HSIZE;
            GATEDHTRANS_xhdl1 <= HTRANS;
            GATEDHWRITE_xhdl2 <= HWRITE;
        else
            PREGATEDHADDR <= regHADDR;
            GATEDHMASTLOCK <= regHMASTLOCK;
            GATEDHSIZE <= regHSIZE;
            GATEDHTRANS_xhdl1 <= regHTRANS;
            GATEDHWRITE_xhdl2 <= regHWRITE;
        end if;
    end process;

    address_decode : COREAHBLITE_ADDRDEC
        generic map (
            MEMSPACE         => MEMSPACE,
            HADDR_SHG_CFG    => HADDR_SHG_CFG,
            M_AHBSLOTENABLE  => M_AHBSLOTENABLE,
            SC               => SC
        )
        port map (
            ADDR          => PREGATEDHADDR,
            REMAP         => REMAP,
            ADDRDEC       => sAddrDec(16 downto 0),
            ABSOLUTEADDR  => GATEDHADDR_xhdl0(31 downto 0),
            RESERVEDDEC   => ReservedDecode
        );

    process (GATEDHTRANS_xhdl1, sAddrDec, ReservedDecode)
    begin
        if (GATEDHTRANS_xhdl1 = '1') then
            SADDRSELInt <= sAddrDec;
            RESERVEDADDRSELInt <= ReservedDecode;
        else
            SADDRSELInt <= SLAVE_NONE;
            RESERVEDADDRSELInt <= '0';
        end if;
    end process;

    process (HCLK, aresetn)
    begin
        if ((not(aresetn)) = '1') then
            SDATASELInt <= SLAVE_NONE;
        elsif (HCLK'event and HCLK = '1') then
            if ((not(sresetn)) = '1') then
                SDATASELInt <= SLAVE_NONE;
		    else
                if (PREVDATASLAVEREADY_xhdl4 = '1') then
                    SDATASELInt <= SADDRSELInt;
                end if;
            end if;
        end if;
    end process;

    process (HCLK, aresetn)
    begin
        if ((not(aresetn)) = '1') then
            RESERVEDDATASELInt	<= '0';
        elsif (HCLK'event and HCLK = '1') then
            if ((not(sresetn)) = '1') then
                RESERVEDDATASELInt	<= '0';
		    else
                if (PREVDATASLAVEREADY_xhdl4 = '1') then
                    RESERVEDDATASELInt <= RESERVEDADDRSELInt;
                end if;
            end if;
        end if;
    end process;

    datasel_onehot <= SDATASELInt(16 downto 0);
    process (
        RESERVEDDATASELInt,
        DEFSLAVEDATAREADY,
        HRESP_DEFAULT,
        datasel_onehot,
        SDATAREADY,
        SHRESP,
        HRDATA_S0,  HREADYOUT_S0,
        HRDATA_S1,  HREADYOUT_S1,
        HRDATA_S2,  HREADYOUT_S2,
        HRDATA_S3,  HREADYOUT_S3,
        HRDATA_S4,  HREADYOUT_S4,
        HRDATA_S5,  HREADYOUT_S5,
        HRDATA_S6,  HREADYOUT_S6,
        HRDATA_S7,  HREADYOUT_S7,
        HRDATA_S8,  HREADYOUT_S8,
        HRDATA_S9,  HREADYOUT_S9,
        HRDATA_S10, HREADYOUT_S10,
        HRDATA_S11, HREADYOUT_S11,
        HRDATA_S12, HREADYOUT_S12,
        HRDATA_S13, HREADYOUT_S13,
        HRDATA_S14, HREADYOUT_S14,
        HRDATA_S15, HREADYOUT_S15,
        HRDATA_S16, HREADYOUT_S16
    )
    begin
        if (RESERVEDDATASELInt='1') then
            HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
            HRESP <= HRESP_DEFAULT;
            HRDATA <= "00000000000000000000000000000000";
            PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
        else
            case datasel_onehot is
                when "00000000000000001" =>
                    if ((M_AHBSLOTENABLE_slv(0)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(0);
                        HRESP <= SHRESP(0);
                        HRDATA <= HRDATA_S0;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S0;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000000000000010" =>
                    if ((M_AHBSLOTENABLE_slv(1)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(1);
                        HRESP <= SHRESP(1);
                        HRDATA <= HRDATA_S1;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S1;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000000000000100" =>
                    if ((M_AHBSLOTENABLE_slv(2)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(2);
                        HRESP <= SHRESP(2);
                        HRDATA <= HRDATA_S2;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S2;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000000000001000" =>
                    if ((M_AHBSLOTENABLE_slv(3)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(3);
                        HRESP <= SHRESP(3);
                        HRDATA <= HRDATA_S3;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S3;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000000000010000" =>
                    if ((M_AHBSLOTENABLE_slv(4)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(4);
                        HRESP <= SHRESP(4);
                        HRDATA <= HRDATA_S4;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S4;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000000000100000" =>
                    if ((M_AHBSLOTENABLE_slv(5)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(5);
                        HRESP <= SHRESP(5);
                        HRDATA <= HRDATA_S5;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S5;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000000001000000" =>
                    if ((M_AHBSLOTENABLE_slv(6)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(6);
                        HRESP <= SHRESP(6);
                        HRDATA <= HRDATA_S6;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S6;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000000010000000" =>
                    if ((M_AHBSLOTENABLE_slv(7)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(7);
                        HRESP <= SHRESP(7);
                        HRDATA <= HRDATA_S7;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S7;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000000100000000" =>
                    if ((M_AHBSLOTENABLE_slv(8)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(8);
                        HRESP <= SHRESP(8);
                        HRDATA <= HRDATA_S8;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S8;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000001000000000" =>
                    if ((M_AHBSLOTENABLE_slv(9)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(9);
                        HRESP <= SHRESP(9);
                        HRDATA <= HRDATA_S9;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S9;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000010000000000" =>
                    if ((M_AHBSLOTENABLE_slv(10)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(10);
                        HRESP <= SHRESP(10);
                        HRDATA <= HRDATA_S10;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S10;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00000100000000000" =>
                    if ((M_AHBSLOTENABLE_slv(11)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(11);
                        HRESP <= SHRESP(11);
                        HRDATA <= HRDATA_S11;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S11;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00001000000000000" =>
                    if ((M_AHBSLOTENABLE_slv(12)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(12);
                        HRESP <= SHRESP(12);
                        HRDATA <= HRDATA_S12;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S12;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00010000000000000" =>
                    if ((M_AHBSLOTENABLE_slv(13)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(13);
                        HRESP <= SHRESP(13);
                        HRDATA <= HRDATA_S13;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S13;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "00100000000000000" =>
                    if ((M_AHBSLOTENABLE_slv(14)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(14);
                        HRESP <= SHRESP(14);
                        HRDATA <= HRDATA_S14;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S14;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "01000000000000000" =>
                    if ((M_AHBSLOTENABLE_slv(15)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(15);
                        HRESP <= SHRESP(15);
                        HRDATA <= HRDATA_S15;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S15;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when "10000000000000000" =>
                    if ((M_AHBSLOTENABLE_slv(16)) = '1') then
                        HREADY_M_xhdl3 <= SDATAREADY(16);
                        HRESP <= SHRESP(16);
                        HRDATA <= HRDATA_S16;
                        PREVDATASLAVEREADY_xhdl4 <= HREADYOUT_S16;
                    else
                        HREADY_M_xhdl3 <= DEFSLAVEDATAREADY;
                        HRESP <= HRESP_DEFAULT;
                        HRDATA <= "00000000000000000000000000000000";
                        PREVDATASLAVEREADY_xhdl4 <= DEFSLAVEDATAREADY;
                    end if;
                when others =>
                    HREADY_M_xhdl3 <= '1';
                    HRESP <= '0';
                    HRDATA <= "00000000000000000000000000000000";
                    PREVDATASLAVEREADY_xhdl4 <= '1';
            end case;
        end if;
    end process;

    process (addrRegSMCurrentState, HTRANS, HREADY_M_xhdl3, sAddrDec, SADDRREADY)
    begin
        masterAddrClockEnable <= '0';
        d_masterRegAddrSel <= '0';
        case addrRegSMCurrentState is
            when IDLE =>
                if ((HTRANS and HREADY_M_xhdl3 and
                        ((sAddrDec(0)  and not(SADDRREADY(0)))  or
                         (sAddrDec(1)  and not(SADDRREADY(1)))  or
                         (sAddrDec(2)  and not(SADDRREADY(2)))  or
                         (sAddrDec(3)  and not(SADDRREADY(3)))  or
                         (sAddrDec(4)  and not(SADDRREADY(4)))  or
                         (sAddrDec(5)  and not(SADDRREADY(5)))  or
                         (sAddrDec(6)  and not(SADDRREADY(6)))  or
                         (sAddrDec(7)  and not(SADDRREADY(7)))  or
                         (sAddrDec(8)  and not(SADDRREADY(8)))  or
                         (sAddrDec(9)  and not(SADDRREADY(9)))  or
                         (sAddrDec(10) and not(SADDRREADY(10))) or
                         (sAddrDec(11) and not(SADDRREADY(11))) or
                         (sAddrDec(12) and not(SADDRREADY(12))) or
                         (sAddrDec(13) and not(SADDRREADY(13))) or
                         (sAddrDec(14) and not(SADDRREADY(14))) or
                         (sAddrDec(15) and not(SADDRREADY(15))) or
                         (sAddrDec(16) and not(SADDRREADY(16)))
                        )) = '1'
                ) then
                    masterAddrClockEnable <= '1';
                    d_masterRegAddrSel <= '1';
                    addrRegSMNextState <= REGISTERED;
                else
                    addrRegSMNextState <= IDLE;
                end if;
            when REGISTERED =>
                if ((
                         (sAddrDec(0)  and SADDRREADY(0))  or
                         (sAddrDec(1)  and SADDRREADY(1))  or
                         (sAddrDec(2)  and SADDRREADY(2))  or
                         (sAddrDec(3)  and SADDRREADY(3))  or
                         (sAddrDec(4)  and SADDRREADY(4))  or
                         (sAddrDec(5)  and SADDRREADY(5))  or
                         (sAddrDec(6)  and SADDRREADY(6))  or
                         (sAddrDec(7)  and SADDRREADY(7))  or
                         (sAddrDec(8)  and SADDRREADY(8))  or
                         (sAddrDec(9)  and SADDRREADY(9))  or
                         (sAddrDec(10) and SADDRREADY(10)) or
                         (sAddrDec(11) and SADDRREADY(11)) or
                         (sAddrDec(12) and SADDRREADY(12)) or
                         (sAddrDec(13) and SADDRREADY(13)) or
                         (sAddrDec(14) and SADDRREADY(14)) or
                         (sAddrDec(15) and SADDRREADY(15)) or
                         (sAddrDec(16) and SADDRREADY(16))) = '1'
                ) then
                    addrRegSMNextState <= IDLE;
                else
                    d_masterRegAddrSel <= '1';
                    addrRegSMNextState <= REGISTERED;
                end if;
            when others =>
                addrRegSMNextState <= IDLE;
        end case;
    end process;

    process (HCLK, aresetn)
    begin
        if ((not(aresetn)) = '1') then
            addrRegSMCurrentState <= IDLE;
            masterRegAddrSel <= '0';
        elsif (HCLK'event and HCLK = '1') then
            if ((not(sresetn)) = '1') then
                addrRegSMCurrentState <= IDLE;
                masterRegAddrSel <= '0';
		    else
                addrRegSMCurrentState <= addrRegSMNextState;
                masterRegAddrSel <= d_masterRegAddrSel;
            end if;
        end if;
    end process;

    default_slave_sm : COREAHBLITE_DEFAULTSLAVESM
	    generic map( SYNC_RESET => SYNC_RESET)
        port map (
            HCLK               => HCLK,
            HRESETN            => HRESETN,
            DEFSLAVEDATASEL    => DEFSLAVEDATASEL,
            DEFSLAVEDATAREADY  => DEFSLAVEDATAREADY,
            HRESP_DEFAULT      => HRESP_DEFAULT
        );

HREADY_M_pre <= HREADY_M_xhdl3;

end architecture COREAHBLITE_MASTERSTAGE_arch;
