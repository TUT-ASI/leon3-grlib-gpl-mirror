-- ********************************************************************/
-- Actel Corporation Proprietary and Confidential
-- Copyright 2010 Actel Corporation.  All rights reserved.
--
-- ANY USE OR REDISTRIBUTION IN PART OR IN WHOLE MUST BE HANDLED IN
-- ACCORDANCE WITH THE ACTEL LICENSE AGREEMENT AND MUST BE APPROVED
-- IN ADVANCE IN WRITING.
--
-- Description:	CoreAHBLite default slave state machine logic for
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
entity COREAHBLITE_DEFAULTSLAVESM is
    generic(SYNC_RESET      : integer := 0);
    port (
        HCLK               : in std_logic;
        HRESETN            : in std_logic;
        DEFSLAVEDATASEL    : in std_logic;
        DEFSLAVEDATAREADY  : out std_logic;
        HRESP_DEFAULT      : out std_logic
    );
end entity COREAHBLITE_DEFAULTSLAVESM;

architecture COREAHBLITE_DEFAULTSLAVESM_arch of COREAHBLITE_DEFAULTSLAVESM is

constant IDLE               :std_logic := '0';
constant HRESPEXTEND        :std_logic := '1';

signal defSlaveSMNextState    : std_logic;
signal defSlaveSMCurrentState : std_logic;
signal aresetn                : std_logic;
signal sresetn                : std_logic;

begin
aresetn <= '1' WHEN (SYNC_RESET=1) ELSE HRESETN;
sresetn <= HRESETN WHEN (SYNC_RESET=1) ELSE '1';

    process (defSlaveSMCurrentState, DEFSLAVEDATASEL)
    begin
        DEFSLAVEDATAREADY <= '1';
        HRESP_DEFAULT <= '0';
        case defSlaveSMCurrentState is
            when IDLE =>
                if (DEFSLAVEDATASEL = '1') then
                    DEFSLAVEDATAREADY <= '0';
                    HRESP_DEFAULT <= '1';
                    defSlaveSMNextState <= HRESPEXTEND;
                else
                    defSlaveSMNextState <= IDLE;
                end if;
            when HRESPEXTEND =>
                HRESP_DEFAULT <= '1';
                defSlaveSMNextState <= IDLE;
            when others =>
                defSlaveSMNextState <= IDLE;
        end case;
    end process;

    process (HCLK, aresetn)
    begin
        if ((not(aresetn)) = '1') then
            defSlaveSMCurrentState <= IDLE;
        elsif (HCLK'event and HCLK = '1') then
            if ((not(sresetn)) = '1') then
                defSlaveSMCurrentState <= IDLE;
            else
                defSlaveSMCurrentState <= defSlaveSMNextState;
            end if;
        end if;
    end process;


end architecture COREAHBLITE_DEFAULTSLAVESM_arch;
