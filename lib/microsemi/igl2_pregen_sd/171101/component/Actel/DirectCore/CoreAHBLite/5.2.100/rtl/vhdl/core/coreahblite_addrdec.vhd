-- ********************************************************************/
-- Actel Corporation Proprietary and Confidential
-- Copyright 2010 Actel Corporation.  All rights reserved.
--
-- ANY USE OR REDISTRIBUTION IN PART OR IN WHOLE MUST BE HANDLED IN
-- ACCORDANCE WITH THE ACTEL LICENSE AGREEMENT AND MUST BE APPROVED
-- IN ADVANCE IN WRITING.
--
-- Description:	CoreAHBLite address decode logic
--				for master 0 and master 1
--
--
-- SVN Revision Information:
-- SVN $Revision: 22340 $
-- SVN $Date: 2014-04-11 17:29:35 +0100 (Fri, 11 Apr 2014) $
--
--
-- *********************************************************************/

-- ========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package coreahblite_support is
    function calc_msb_addr(x:integer) return integer;
end coreahblite_support;

package body coreahblite_support is
    function calc_msb_addr( x : integer ) return integer is
    begin
        if    x = 0 then return(31);
        elsif x = 1 then return(31);
        elsif x = 2 then return(27);
        elsif x = 3 then return(23);
        elsif x = 4 then return(19);
        elsif x = 5 then return(15);
        elsif x = 6 then return(11);
        else             return(31);
        end if;
    end calc_msb_addr;
end coreahblite_support;
-- ========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.coreahblite_support.all;

entity COREAHBLITE_ADDRDEC is
    generic (
        MEMSPACE         : integer range 0 to 6 := 0;
        HADDR_SHG_CFG    : integer range 0 to 1 := 1;
        M_AHBSLOTENABLE  : integer range 0 to (2**17)-1 := (2**17)-1;
        SC               : integer range 0 to (2**16)-1 := 0
    );
    port (
        ADDR             : in std_logic_vector(31 downto 0);
        REMAP            : in std_logic;
        ADDRDEC          : out std_logic_vector(16 downto 0);
        ABSOLUTEADDR     : out std_logic_vector(31 downto 0);
        RESERVEDDEC      : out std_logic
    );
end entity COREAHBLITE_ADDRDEC;

architecture COREAHBLITE_ADDRDEC_arch of COREAHBLITE_ADDRDEC is

constant SLAVE_0      : std_logic_vector(15 downto 0) := "0000000000000001";
constant SLAVE_1      : std_logic_vector(15 downto 0) := "0000000000000010";
constant SLAVE_2      : std_logic_vector(15 downto 0) := "0000000000000100";
constant SLAVE_3      : std_logic_vector(15 downto 0) := "0000000000001000";
constant SLAVE_4      : std_logic_vector(15 downto 0) := "0000000000010000";
constant SLAVE_5      : std_logic_vector(15 downto 0) := "0000000000100000";
constant SLAVE_6      : std_logic_vector(15 downto 0) := "0000000001000000";
constant SLAVE_7      : std_logic_vector(15 downto 0) := "0000000010000000";
constant SLAVE_8      : std_logic_vector(15 downto 0) := "0000000100000000";
constant SLAVE_9      : std_logic_vector(15 downto 0) := "0000001000000000";
constant SLAVE_10     : std_logic_vector(15 downto 0) := "0000010000000000";
constant SLAVE_11     : std_logic_vector(15 downto 0) := "0000100000000000";
constant SLAVE_12     : std_logic_vector(15 downto 0) := "0001000000000000";
constant SLAVE_13     : std_logic_vector(15 downto 0) := "0010000000000000";
constant SLAVE_14     : std_logic_vector(15 downto 0) := "0100000000000000";
constant SLAVE_15     : std_logic_vector(15 downto 0) := "1000000000000000";
constant NONE         : std_logic_vector(15 downto 0) := "0000000000000000";

constant SC_slv  : std_logic_vector(15 downto 0):=
    std_logic_vector(to_unsigned(SC,16));

constant MSB_ADDR     : integer := calc_msb_addr(MEMSPACE);

signal sdec_raw         : std_logic_vector(15 downto 0);
signal sdec             : std_logic_vector(15 downto 0);
signal s16dec           : std_logic;
signal absaddr          : std_logic_vector(31 downto 0);
signal ADDRDEC_pre      : std_logic_vector(16 downto 0);

signal slotdec          : std_logic_vector(3 downto 0);
signal m0_hugeslotdec   : std_logic;
signal m0_otherslotsdec : std_logic;


begin
    g_mem0_00 : if (MEMSPACE = 0) generate
    begin
        m0_hugeslotdec   <= '1' when (ADDR(31) = '1') else '0';
        m0_otherslotsdec <= '1' when (ADDR(30 downto 20) = "00000000000") else '0';
        slotdec <= ADDR(19 downto 16);
        process (ADDR, m0_hugeslotdec, m0_otherslotsdec, slotdec, REMAP)
        begin
            absaddr(31 downto 0) <= ADDR(31 downto 0);
            sdec_raw(15 downto 0) <= NONE;
            if (m0_hugeslotdec = '1') then
                if (HADDR_SHG_CFG = 0) then
                    absaddr(31) <= '0';
                else
                    absaddr(31) <= '1';
                end if;
            elsif (m0_otherslotsdec = '1') then
                case slotdec is
                    when "0000" =>
                        if (REMAP = '0') then
                            sdec_raw(15 downto 0) <= SLAVE_0;
                        else
                            absaddr(16) <= '1';
                            sdec_raw(15 downto 0) <= SLAVE_1;
                        end if;
                    when "0001" =>
                        if (REMAP = '0') then
                            sdec_raw(15 downto 0) <= SLAVE_1;
                        else
                            absaddr(16) <= '0';
                            sdec_raw(15 downto 0) <= SLAVE_0;
                        end if;
                    when "0010" => sdec_raw(15 downto 0) <= SLAVE_2;
                    when "0011" => sdec_raw(15 downto 0) <= SLAVE_3;
                    when "0100" => sdec_raw(15 downto 0) <= SLAVE_4;
                    when "0101" => sdec_raw(15 downto 0) <= SLAVE_5;
                    when "0110" => sdec_raw(15 downto 0) <= SLAVE_6;
                    when "0111" => sdec_raw(15 downto 0) <= SLAVE_7;
                    when "1000" => sdec_raw(15 downto 0) <= SLAVE_8;
                    when "1001" => sdec_raw(15 downto 0) <= SLAVE_9;
                    when "1010" => sdec_raw(15 downto 0) <= SLAVE_10;
                    when "1011" => sdec_raw(15 downto 0) <= SLAVE_11;
                    when "1100" => sdec_raw(15 downto 0) <= SLAVE_12;
                    when "1101" => sdec_raw(15 downto 0) <= SLAVE_13;
                    when "1110" => sdec_raw(15 downto 0) <= SLAVE_14;
                    when others => sdec_raw(15 downto 0) <= SLAVE_15;
                end case;
            end if;
        end process;

        sdec(15) <= sdec_raw(15);
        sdec(14) <= sdec_raw(14);
        sdec(13) <= sdec_raw(13);
        sdec(12) <= sdec_raw(12);
        sdec(11) <= sdec_raw(11);
        sdec(10) <= sdec_raw(10);
        sdec(9)  <= sdec_raw(9);
        sdec(8)  <= sdec_raw(8);
        sdec(7)  <= sdec_raw(7);
        sdec(6)  <= sdec_raw(6);
        sdec(5)  <= sdec_raw(5);
        sdec(4)  <= sdec_raw(4);
        sdec(3)  <= sdec_raw(3);
        sdec(2)  <= sdec_raw(2);
        sdec(1)  <= sdec_raw(1);
        sdec(0)  <= sdec_raw(0);

        s16dec <= m0_hugeslotdec;

        RESERVEDDEC <= '1' when m0_hugeslotdec='0' and m0_otherslotsdec='0'
                       else '0';
    end generate;

    g_mem1_00 : if (not(MEMSPACE = 0)) generate
    begin
        m0_hugeslotdec   <= '0';
        m0_otherslotsdec <= '0';
        slotdec <= ADDR(MSB_ADDR downto MSB_ADDR-3);
        process (ADDR, slotdec, REMAP)
        begin
            absaddr(31 downto 0) <= ADDR(31 downto 0);
            case slotdec is
                when "0000" =>
                    if (REMAP = '0') then
                        sdec_raw(15 downto 0) <= SLAVE_0;
                    else
                        absaddr(24) <= '1';
                        sdec_raw(15 downto 0) <= SLAVE_1;
                    end if;
                when "0001" =>
                    if (REMAP = '0') then
                        sdec_raw(15 downto 0) <= SLAVE_1;
                    else
                        absaddr(24) <= '0';
                        sdec_raw(15 downto 0) <= SLAVE_0;
                    end if;
                when "0010" => sdec_raw(15 downto 0) <= SLAVE_2;
                when "0011" => sdec_raw(15 downto 0) <= SLAVE_3;
                when "0100" => sdec_raw(15 downto 0) <= SLAVE_4;
                when "0101" => sdec_raw(15 downto 0) <= SLAVE_5;
                when "0110" => sdec_raw(15 downto 0) <= SLAVE_6;
                when "0111" => sdec_raw(15 downto 0) <= SLAVE_7;
                when "1000" => sdec_raw(15 downto 0) <= SLAVE_8;
                when "1001" => sdec_raw(15 downto 0) <= SLAVE_9;
                when "1010" => sdec_raw(15 downto 0) <= SLAVE_10;
                when "1011" => sdec_raw(15 downto 0) <= SLAVE_11;
                when "1100" => sdec_raw(15 downto 0) <= SLAVE_12;
                when "1101" => sdec_raw(15 downto 0) <= SLAVE_13;
                when "1110" => sdec_raw(15 downto 0) <= SLAVE_14;
                when others => sdec_raw(15 downto 0) <= SLAVE_15;
            end case;
        end process;

        sdec(15) <= sdec_raw(15) and not(SC_slv(15));
        sdec(14) <= sdec_raw(14) and not(SC_slv(14));
        sdec(13) <= sdec_raw(13) and not(SC_slv(13));
        sdec(12) <= sdec_raw(12) and not(SC_slv(12));
        sdec(11) <= sdec_raw(11) and not(SC_slv(11));
        sdec(10) <= sdec_raw(10) and not(SC_slv(10));
        sdec(9)  <= sdec_raw(9)  and not(SC_slv(9));
        sdec(8)  <= sdec_raw(8)  and not(SC_slv(8));
        sdec(7)  <= sdec_raw(7)  and not(SC_slv(7));
        sdec(6)  <= sdec_raw(6)  and not(SC_slv(6));
        sdec(5)  <= sdec_raw(5)  and not(SC_slv(5));
        sdec(4)  <= sdec_raw(4)  and not(SC_slv(4));
        sdec(3)  <= sdec_raw(3)  and not(SC_slv(3));
        sdec(2)  <= sdec_raw(2)  and not(SC_slv(2));
        sdec(1)  <= sdec_raw(1)  and not(SC_slv(1));
        sdec(0)  <= sdec_raw(0)  and not(SC_slv(0));

        s16dec <=    (sdec_raw(15) and SC_slv(15))
                  or (sdec_raw(14) and SC_slv(14))
                  or (sdec_raw(13) and SC_slv(13))
                  or (sdec_raw(12) and SC_slv(12))
                  or (sdec_raw(11) and SC_slv(11))
                  or (sdec_raw(10) and SC_slv(10))
                  or (sdec_raw(9)  and SC_slv(9) )
                  or (sdec_raw(8)  and SC_slv(8) )
                  or (sdec_raw(7)  and SC_slv(7) )
                  or (sdec_raw(6)  and SC_slv(6) )
                  or (sdec_raw(5)  and SC_slv(5) )
                  or (sdec_raw(4)  and SC_slv(4) )
                  or (sdec_raw(3)  and SC_slv(3) )
                  or (sdec_raw(2)  and SC_slv(2) )
                  or (sdec_raw(1)  and SC_slv(1) )
                  or (sdec_raw(0)  and SC_slv(0) );

        RESERVEDDEC <= '0';
    end generate;

    ADDRDEC_pre(16 downto 0) <= (s16dec & sdec(15 downto 0));
    ABSOLUTEADDR(31 downto 0) <= absaddr(31 downto 0);
    ADDRDEC(16 downto 0) <= ADDRDEC_pre(16 downto 0);

end architecture COREAHBLITE_ADDRDEC_arch;
