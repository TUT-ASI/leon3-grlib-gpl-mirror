-- ********************************************************************/
-- Actel Corporation Proprietary and Confidential
-- Copyright 2013 Actel Corporation.  All rights reserved.
--
-- ANY USE OR REDISTRIBUTION IN PART OR IN WHOLE MUST BE HANDLED IN
-- ACCORDANCE WITH THE ACTEL LICENSE AGREEMENT AND MUST BE APPROVED
-- IN ADVANCE IN WRITING.
--
-- Description:	CoreAHBLite slave stage logic for
--				matrix (4 masters by 16 slaves),
--				instantiates the following modules:
--				COREAHBLITE_SLAVEARBITER
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
entity COREAHBLITE_SLAVESTAGE is
    generic(SYNC_RESET      : integer := 0);
    port (
        HCLK                 : in std_logic;
        HRESETN              : in std_logic;
        HREADYOUT            : in std_logic;
        HRESP                : in std_logic;
        HSEL                 : out std_logic;
        HADDR                : out std_logic_vector(31 downto 0);
        HSIZE                : out std_logic_vector(2 downto 0);
        HTRANS               : out std_logic;
        HWRITE               : out std_logic;
        HWDATA               : out std_logic_vector(31 downto 0);
        HREADY_S             : out std_logic;
        HMASTLOCK            : out std_logic;
        MADDRSEL             : in std_logic_vector(3 downto 0);
        MDATASEL             : in std_logic_vector(3 downto 0);
        MPREVDATASLAVEREADY  : in std_logic_vector(3 downto 0);
        MADDRREADY           : out std_logic_vector(3 downto 0);
        MDATAREADY           : out std_logic_vector(3 downto 0);
        MHRESP               : out std_logic_vector(3 downto 0);
        M0GATEDHADDR         : in std_logic_vector(31 downto 0);
        M0GATEDHMASTLOCK     : in std_logic;
        M0GATEDHSIZE         : in std_logic_vector(2 downto 0);
        M0GATEDHTRANS        : in std_logic;
        M0GATEDHWRITE        : in std_logic;
        M1GATEDHADDR         : in std_logic_vector(31 downto 0);
        M1GATEDHMASTLOCK     : in std_logic;
        M1GATEDHSIZE         : in std_logic_vector(2 downto 0);
        M1GATEDHTRANS        : in std_logic;
        M1GATEDHWRITE        : in std_logic;
        M2GATEDHADDR         : in std_logic_vector(31 downto 0);
        M2GATEDHMASTLOCK     : in std_logic;
        M2GATEDHSIZE         : in std_logic_vector(2 downto 0);
        M2GATEDHTRANS        : in std_logic;
        M2GATEDHWRITE        : in std_logic;
        M3GATEDHADDR         : in std_logic_vector(31 downto 0);
        M3GATEDHMASTLOCK     : in std_logic;
        M3GATEDHSIZE         : in std_logic_vector(2 downto 0);
        M3GATEDHTRANS        : in std_logic;
        M3GATEDHWRITE        : in std_logic;
        HWDATA_M0            : in std_logic_vector(31 downto 0);
        HWDATA_M1            : in std_logic_vector(31 downto 0);
        HWDATA_M2            : in std_logic_vector(31 downto 0);
        HWDATA_M3            : in std_logic_vector(31 downto 0)
    );
end entity COREAHBLITE_SLAVESTAGE;

architecture trans of COREAHBLITE_SLAVESTAGE is


function or_v (
    v : std_logic_vector) return std_logic is
    variable sl : std_logic := '0';
begin
    for i in v'range loop
       sl := sl or v(i);
    end loop;
    return(sl);
end or_v;

constant TRN_IDLE       : std_logic := '0';
constant MASTER_NONE    : std_logic_vector(3 downto 0) := "0000";


    component COREAHBLITE_SLAVEARBITER is
	    generic(SYNC_RESET   : integer := 0);
        port (
            HCLK                 : in std_logic;
            HRESETN              : in std_logic;
            MADDRSEL             : in std_logic_vector(3 downto 0);
            ADDRPHEND            : in std_logic;
            M0GATEDHMASTLOCK     : in std_logic;
            M1GATEDHMASTLOCK     : in std_logic;
            M2GATEDHMASTLOCK     : in std_logic;
            M3GATEDHMASTLOCK     : in std_logic;
            MASTERADDRINPROG     : out std_logic_vector(3 downto 0)
        );
    end component;

    signal masterAddrInProg           : std_logic_vector(3 downto 0);
    signal masterDataInProg           : std_logic_vector(3 downto 0);
    signal addrPhMasterHREADY         : std_logic;
    signal addrPhMasterDataPhComplete : std_logic;
    signal preHTRANS                  : std_logic;

    -- Declare intermediate signals for referenced outputs
    signal HREADY_S_xhdl0             : std_logic;
    signal aresetn                : std_logic;
    signal sresetn                : std_logic;

begin
    aresetn <= '1' WHEN (SYNC_RESET=1) ELSE HRESETN;
    sresetn <= HRESETN WHEN (SYNC_RESET=1) ELSE '1';
    -- Drive referenced outputs
    HREADY_S <= HREADY_S_xhdl0;
    process (HCLK, aresetn)
    begin
        if ((not(aresetn)) = '1') then
            masterDataInProg <= MASTER_NONE;
        elsif (HCLK'event and HCLK = '1') then
            if ((not(sresetn)) = '1') then
                masterDataInProg <= MASTER_NONE;
		    else
                if (HREADY_S_xhdl0 = '1') then
                    masterDataInProg <= masterAddrInProg;
                end if;
            end if;
        end if;
    end process;



    slave_arbiter : COREAHBLITE_SLAVEARBITER
		generic map(SYNC_RESET => SYNC_RESET)
        port map (
            HCLK              => HCLK,
            HRESETN           => HRESETN,
            MADDRSEL          => MADDRSEL,
            ADDRPHEND         => HREADY_S_xhdl0,
            M0GATEDHMASTLOCK  => M0GATEDHMASTLOCK,
            M1GATEDHMASTLOCK  => M1GATEDHMASTLOCK,
            M2GATEDHMASTLOCK  => M2GATEDHMASTLOCK,
            M3GATEDHMASTLOCK  => M3GATEDHMASTLOCK,
            MASTERADDRINPROG  => masterAddrInProg
        );
    process (masterAddrInProg,
             M0GATEDHTRANS, M0GATEDHSIZE, M0GATEDHWRITE, M0GATEDHADDR, M0GATEDHMASTLOCK,
             M1GATEDHTRANS, M1GATEDHSIZE, M1GATEDHWRITE, M1GATEDHADDR, M1GATEDHMASTLOCK,
             M2GATEDHTRANS, M2GATEDHSIZE, M2GATEDHWRITE, M2GATEDHADDR, M2GATEDHMASTLOCK,
             M3GATEDHTRANS, M3GATEDHSIZE, M3GATEDHWRITE, M3GATEDHADDR, M3GATEDHMASTLOCK,
             MPREVDATASLAVEREADY)
    begin
        case masterAddrInProg is
            when "0001" =>
                HSEL <= '1';
                preHTRANS <= M0GATEDHTRANS;
                HSIZE <= M0GATEDHSIZE;
                HWRITE <= M0GATEDHWRITE;
                HADDR <= M0GATEDHADDR;
                HMASTLOCK <= M0GATEDHMASTLOCK;
                addrPhMasterHREADY <= MPREVDATASLAVEREADY(0);
            when "0010" =>
                HSEL <= '1';
                preHTRANS <= M1GATEDHTRANS;
                HSIZE <= M1GATEDHSIZE;
                HWRITE <= M1GATEDHWRITE;
                HADDR <= M1GATEDHADDR;
                HMASTLOCK <= M1GATEDHMASTLOCK;
                addrPhMasterHREADY <= MPREVDATASLAVEREADY(1);
            when "0100" =>
                HSEL <= '1';
                preHTRANS <= M2GATEDHTRANS;
                HSIZE <= M2GATEDHSIZE;
                HWRITE <= M2GATEDHWRITE;
                HADDR <= M2GATEDHADDR;
                HMASTLOCK <= M2GATEDHMASTLOCK;
                addrPhMasterHREADY <= MPREVDATASLAVEREADY(2);
            when "1000" =>
                HSEL <= '1';
                preHTRANS <= M3GATEDHTRANS;
                HSIZE <= M3GATEDHSIZE;
                HWRITE <= M3GATEDHWRITE;
                HADDR <= M3GATEDHADDR;
                HMASTLOCK <= M3GATEDHMASTLOCK;
                addrPhMasterHREADY <= MPREVDATASLAVEREADY(3);
            when others =>
                HSEL <= '0';
                preHTRANS <= TRN_IDLE;
                HSIZE <= "000";
                HWRITE <= '0';
                HADDR <= "00000000000000000000000000000000";
                HMASTLOCK <= '0';
                addrPhMasterHREADY <= '1';
        end case;
    end process;

    addrPhMasterDataPhComplete <= or_v((masterAddrInProg and MDATASEL));
    HTRANS <= preHTRANS and (addrPhMasterHREADY or addrPhMasterDataPhComplete);
    HREADY_S_xhdl0 <= HREADYOUT;
    process (masterDataInProg, HWDATA_M0, HWDATA_M1, HWDATA_M2, HWDATA_M3)
    begin
        case masterDataInProg is
            when "0001" =>
                HWDATA <= HWDATA_M0;
            when "0010" =>
                HWDATA <= HWDATA_M1;
            when "0100" =>
                HWDATA <= HWDATA_M2;
            when "1000" =>
                HWDATA <= HWDATA_M3;
            when others =>
                HWDATA <= "00000000000000000000000000000000";
        end case;
    end process;

    process (masterDataInProg, HRESP)
    begin
        MHRESP <= "0000";
        case masterDataInProg is
            when "0001" =>
                MHRESP(0) <= HRESP;
            when "0010" =>
                MHRESP(1) <= HRESP;
            when "0100" =>
                MHRESP(2) <= HRESP;
            when "1000" =>
                MHRESP(3) <= HRESP;
            when others =>
                MHRESP <= "0000";
        end case;
    end process;

    process (MADDRSEL, masterAddrInProg, HREADYOUT)
    begin
        if ((MADDRSEL(0) and not(masterAddrInProg(0))) = '1') then
            MADDRREADY(0) <= '0';
        elsif ((MADDRSEL(0) and masterAddrInProg(0)) = '1') then
            MADDRREADY(0) <= HREADYOUT;
        else
            MADDRREADY(0) <= '1';
        end if;
    end process;

    process (MADDRSEL, masterAddrInProg, HREADYOUT)
    begin
        if ((MADDRSEL(1) and not(masterAddrInProg(1))) = '1') then
            MADDRREADY(1) <= '0';
        elsif ((MADDRSEL(1) and masterAddrInProg(1)) = '1') then
            MADDRREADY(1) <= HREADYOUT;
        else
            MADDRREADY(1) <= '1';
        end if;
    end process;

    process (MADDRSEL, masterAddrInProg, HREADYOUT)
    begin
        if ((MADDRSEL(2) and not(masterAddrInProg(2))) = '1') then
            MADDRREADY(2) <= '0';
        elsif ((MADDRSEL(2) and masterAddrInProg(2)) = '1') then
            MADDRREADY(2) <= HREADYOUT;
        else
            MADDRREADY(2) <= '1';
        end if;
    end process;

    process (MADDRSEL, masterAddrInProg, HREADYOUT)
    begin
        if ((MADDRSEL(3) and not(masterAddrInProg(3))) = '1') then
            MADDRREADY(3) <= '0';
        elsif ((MADDRSEL(3) and masterAddrInProg(3)) = '1') then
            MADDRREADY(3) <= HREADYOUT;
        else
            MADDRREADY(3) <= '1';
        end if;
    end process;

    process (MDATASEL, masterDataInProg, HREADYOUT)
    begin
        if ((MDATASEL(0) and not(masterDataInProg(0))) = '1') then
            MDATAREADY(0) <= '0';
        elsif ((MDATASEL(0) and masterDataInProg(0)) = '1') then
            MDATAREADY(0) <= HREADYOUT;
        else
            MDATAREADY(0) <= '1';
        end if;
    end process;

    process (MDATASEL, masterDataInProg, HREADYOUT)
    begin
        if ((MDATASEL(1) and not(masterDataInProg(1))) = '1') then
            MDATAREADY(1) <= '0';
        elsif ((MDATASEL(1) and masterDataInProg(1)) = '1') then
            MDATAREADY(1) <= HREADYOUT;
        else
            MDATAREADY(1) <= '1';
        end if;
    end process;

    process (MDATASEL, masterDataInProg, HREADYOUT)
    begin
        if ((MDATASEL(2) and not(masterDataInProg(2))) = '1') then
            MDATAREADY(2) <= '0';
        elsif ((MDATASEL(2) and masterDataInProg(2)) = '1') then
            MDATAREADY(2) <= HREADYOUT;
        else
            MDATAREADY(2) <= '1';
        end if;
    end process;

    process (MDATASEL, masterDataInProg, HREADYOUT)
    begin
        if ((MDATASEL(3) and not(masterDataInProg(3))) = '1') then
            MDATAREADY(3) <= '0';
        elsif ((MDATASEL(3) and masterDataInProg(3)) = '1') then
            MDATAREADY(3) <= HREADYOUT;
        else
            MDATAREADY(3) <= '1';
        end if;
    end process;

end architecture trans;
