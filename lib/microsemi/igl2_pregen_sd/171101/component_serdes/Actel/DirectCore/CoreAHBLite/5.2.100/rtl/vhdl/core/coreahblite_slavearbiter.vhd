-- ********************************************************************/
-- Actel Corporation Proprietary and Confidential
-- Copyright 2013 Actel Corporation.  All rights reserved.
--
-- ANY USE OR REDISTRIBUTION IN PART OR IN WHOLE MUST BE HANDLED IN
-- ACCORDANCE WITH THE ACTEL LICENSE AGREEMENT AND MUST BE APPROVED
-- IN ADVANCE IN WRITING.
--
-- Description:	CoreAHBLite slave arbiter logic for
--				matrix (2 masters by 16 slaves)
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
entity COREAHBLITE_SLAVEARBITER is
    generic(SYNC_RESET    : integer := 0);
    port (
        HCLK              : in std_logic;
        HRESETN           : in std_logic;
        MADDRSEL          : in std_logic_vector(3 downto 0);
        ADDRPHEND         : in std_logic;
        M0GATEDHMASTLOCK  : in std_logic;
        M1GATEDHMASTLOCK  : in std_logic;
        M2GATEDHMASTLOCK  : in std_logic;
        M3GATEDHMASTLOCK  : in std_logic;
        MASTERADDRINPROG  : out std_logic_vector(3 downto 0)
    );
end entity COREAHBLITE_SLAVEARBITER;

architecture COREAHBLITE_SLAVEARBITER_arch of COREAHBLITE_SLAVEARBITER is

constant M0EXTEND           : std_logic_vector(3 downto 0) := "0000";
constant M0DONE             : std_logic_vector(3 downto 0) := "0001";
constant M0LOCK             : std_logic_vector(3 downto 0) := "0010";
constant M0LOCKEXTEND       : std_logic_vector(3 downto 0) := "0011";
constant M1EXTEND           : std_logic_vector(3 downto 0) := "0100";
constant M1DONE             : std_logic_vector(3 downto 0) := "0101";
constant M1LOCK             : std_logic_vector(3 downto 0) := "0110";
constant M1LOCKEXTEND       : std_logic_vector(3 downto 0) := "0111";
constant M2EXTEND           : std_logic_vector(3 downto 0) := "1000";
constant M2DONE             : std_logic_vector(3 downto 0) := "1001";
constant M2LOCK             : std_logic_vector(3 downto 0) := "1010";
constant M2LOCKEXTEND       : std_logic_vector(3 downto 0) := "1011";
constant M3EXTEND           : std_logic_vector(3 downto 0) := "1100";
constant M3DONE             : std_logic_vector(3 downto 0) := "1101";
constant M3LOCK             : std_logic_vector(3 downto 0) := "1110";
constant M3LOCKEXTEND       : std_logic_vector(3 downto 0) := "1111";

constant MASTER_0         : std_logic_vector(3 downto 0) := "0001";
constant MASTER_1         : std_logic_vector(3 downto 0) := "0010";
constant MASTER_2         : std_logic_vector(3 downto 0) := "0100";
constant MASTER_3         : std_logic_vector(3 downto 0) := "1000";
constant MASTER_NONE      : std_logic_vector(3 downto 0) := "0000";


    signal arbRegSMNextState    : std_logic_vector(3 downto 0);
    signal arbRegSMCurrentState : std_logic_vector(3 downto 0);
    signal aresetn                : std_logic;
    signal sresetn                : std_logic;

begin
    aresetn <= '1' WHEN (SYNC_RESET=1) ELSE HRESETN;
    sresetn <= HRESETN WHEN (SYNC_RESET=1) ELSE '1';
	
    process (arbRegSMCurrentState,
             MADDRSEL,
             ADDRPHEND,
             M0GATEDHMASTLOCK,
             M1GATEDHMASTLOCK,
             M2GATEDHMASTLOCK,
             M3GATEDHMASTLOCK)
    begin
        MASTERADDRINPROG <= MASTER_NONE;
        case arbRegSMCurrentState is
            when M3DONE =>
                if ((MADDRSEL(0)) = '1') then
                    if (M0GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M0LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_0;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M0DONE;
                        else
                            arbRegSMNextState <= M0EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(1)) = '1') then
                    if (M1GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M1LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_1;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M1DONE;
                        else
                            arbRegSMNextState <= M1EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(2)) = '1') then
                    if (M2GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M2LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_2;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M2DONE;
                        else
                            arbRegSMNextState <= M2EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(3)) = '1') then
                    if (M3GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M3LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_3;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M3DONE;
                        else
                            arbRegSMNextState <= M3EXTEND;
                        end if;
                    end if;
                else
                    arbRegSMNextState <= M3DONE;
                end if;
            when M2DONE =>
                if ((MADDRSEL(3)) = '1') then
                    if (M3GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M3LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_3;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M3DONE;
                        else
                            arbRegSMNextState <= M3EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(0)) = '1') then
                    if (M0GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M0LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_0;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M0DONE;
                        else
                            arbRegSMNextState <= M0EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(1)) = '1') then
                    if (M1GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M1LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_1;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M1DONE;
                        else
                            arbRegSMNextState <= M1EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(2)) = '1') then
                    if (M2GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M2LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_2;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M2DONE;
                        else
                            arbRegSMNextState <= M2EXTEND;
                        end if;
                    end if;
                else
                    arbRegSMNextState <= M2DONE;
                end if;
            when M1DONE =>
                if ((MADDRSEL(2)) = '1') then
                    if (M2GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M2LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_2;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M2DONE;
                        else
                            arbRegSMNextState <= M2EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(3)) = '1') then
                    if (M3GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M3LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_3;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M3DONE;
                        else
                            arbRegSMNextState <= M3EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(0)) = '1') then
                    if (M0GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M0LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_0;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M0DONE;
                        else
                            arbRegSMNextState <= M0EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(1)) = '1') then
                    if (M1GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M1LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_1;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M1DONE;
                        else
                            arbRegSMNextState <= M1EXTEND;
                        end if;
                    end if;
                else
                    arbRegSMNextState <= M1DONE;
                end if;
            when M0DONE =>
                if ((MADDRSEL(1)) = '1') then
                    if (M1GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M1LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_1;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M1DONE;
                        else
                            arbRegSMNextState <= M1EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(2)) = '1') then
                    if (M2GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M2LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_2;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M2DONE;
                        else
                            arbRegSMNextState <= M2EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(3)) = '1') then
                    if (M3GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M3LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_3;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M3DONE;
                        else
                            arbRegSMNextState <= M3EXTEND;
                        end if;
                    end if;
                elsif ((MADDRSEL(0)) = '1') then
                    if (M0GATEDHMASTLOCK = '1') then
                        arbRegSMNextState <= M0LOCK;
                    else
                        MASTERADDRINPROG <= MASTER_0;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M0DONE;
                        else
                            arbRegSMNextState <= M0EXTEND;
                        end if;
                    end if;
                else
                    arbRegSMNextState <= M0DONE;
                end if;
            when M0EXTEND =>
                MASTERADDRINPROG <= MASTER_0;
                if (ADDRPHEND = '1') then
                    arbRegSMNextState <= M0DONE;
                else
                    arbRegSMNextState <= M0EXTEND;
                end if;
            when M1EXTEND =>
                MASTERADDRINPROG <= MASTER_1;
                if (ADDRPHEND = '1') then
                    arbRegSMNextState <= M1DONE;
                else
                    arbRegSMNextState <= M1EXTEND;
                end if;
            when M2EXTEND =>
                MASTERADDRINPROG <= MASTER_2;
                if (ADDRPHEND = '1') then
                    arbRegSMNextState <= M2DONE;
                else
                    arbRegSMNextState <= M2EXTEND;
                end if;
            when M3EXTEND =>
                MASTERADDRINPROG <= MASTER_3;
                if (ADDRPHEND = '1') then
                    arbRegSMNextState <= M3DONE;
                else
                    arbRegSMNextState <= M3EXTEND;
                end if;
            when M0LOCK =>
                if (M0GATEDHMASTLOCK = '1') then
                    if ((MADDRSEL(0)) = '1') then
                        MASTERADDRINPROG <= MASTER_0;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M0LOCK;
                        else
                            arbRegSMNextState <= M0LOCKEXTEND;
                        end if;
                    else
                        arbRegSMNextState <= M0LOCK;
                    end if;
                else
                    arbRegSMNextState <= M0DONE;
                end if;
            when M0LOCKEXTEND =>
                MASTERADDRINPROG <= MASTER_0;
                if (ADDRPHEND = '1') then
                    arbRegSMNextState <= M0LOCK;
                else
                    arbRegSMNextState <= M0LOCKEXTEND;
                end if;
            when M1LOCK =>
                if (M1GATEDHMASTLOCK = '1') then
                    if ((MADDRSEL(1)) = '1') then
                        MASTERADDRINPROG <= MASTER_1;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M1LOCK;
                        else
                            arbRegSMNextState <= M1LOCKEXTEND;
                        end if;
                    else
                        arbRegSMNextState <= M1LOCK;
                    end if;
                else
                    arbRegSMNextState <= M1DONE;
                end if;
            when M1LOCKEXTEND =>
                MASTERADDRINPROG <= MASTER_1;
                if (ADDRPHEND = '1') then
                    arbRegSMNextState <= M1LOCK;
                else
                    arbRegSMNextState <= M1LOCKEXTEND;
                end if;
            when M2LOCK =>
                if (M2GATEDHMASTLOCK = '1') then
                    if ((MADDRSEL(2)) = '1') then
                        MASTERADDRINPROG <= MASTER_2;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M2LOCK;
                        else
                            arbRegSMNextState <= M2LOCKEXTEND;
                        end if;
                    else
                        arbRegSMNextState <= M2LOCK;
                    end if;
                else
                    arbRegSMNextState <= M2DONE;
                end if;
            when M2LOCKEXTEND =>
                MASTERADDRINPROG <= MASTER_2;
                if (ADDRPHEND = '1') then
                    arbRegSMNextState <= M2LOCK;
                else
                    arbRegSMNextState <= M2LOCKEXTEND;
                end if;
            when M3LOCK =>
                if (M3GATEDHMASTLOCK = '1') then
                    if ((MADDRSEL(3)) = '1') then
                        MASTERADDRINPROG <= MASTER_3;
                        if (ADDRPHEND = '1') then
                            arbRegSMNextState <= M3LOCK;
                        else
                            arbRegSMNextState <= M3LOCKEXTEND;
                        end if;
                    else
                        arbRegSMNextState <= M3LOCK;
                    end if;
                else
                    arbRegSMNextState <= M3DONE;
                end if;
            when M3LOCKEXTEND =>
                MASTERADDRINPROG <= MASTER_3;
                if (ADDRPHEND = '1') then
                    arbRegSMNextState <= M3LOCK;
                else
                    arbRegSMNextState <= M3LOCKEXTEND;
                end if;

            when others =>
                arbRegSMNextState <= M1DONE;
        end case;
    end process;

    process (HCLK, aresetn)
    begin
        if ((not(aresetn)) = '1') then
            arbRegSMCurrentState <= M3DONE;
        elsif (HCLK'event and HCLK = '1') then
            if ((not(sresetn)) = '1') then
                arbRegSMCurrentState <= M3DONE;
		    else
                arbRegSMCurrentState <= arbRegSMNextState;
            end if;
        end if;
    end process;


end architecture COREAHBLITE_SLAVEARBITER_arch;
