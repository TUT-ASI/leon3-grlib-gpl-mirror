------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library gaisler;
use gaisler.l2c_lite.all;
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;

library techmap;
use techmap.gencomp.all;

entity l2c_lite_mem is
    generic (
        hsindex  : integer := 0;
        tech     : integer := 0;
        waysize  : integer := 32;
        linesize : integer := 32;
        ways     : integer := 2;
        repl     : integer := 0);
    port (
        rstn  : in std_ulogic;
        clk   : in std_ulogic;
        ctrli : in cache_ctrli_type;
        ctrlo : out cache_ctrlo_type;
        ahbsi : in ahb_slv_in_type);

end entity l2c_lite_mem;

architecture rtl of l2c_lite_mem is

    constant addr_depth : integer := log2ext(waysize * (2 ** 10) / linesize);
    constant tag_len    : integer := 32 - addr_depth - log2ext(linesize);
    constant tag_dbits  : integer := tag_len + 2;

    -- RANGES -- 
    subtype TAG_R is natural range 31 downto addr_depth + log2ext(linesize);
    subtype TAG_DATA_R is natural range tag_dbits - 1 downto 2;
    subtype INDEX_R is natural range (addr_depth + log2ext(linesize) - 1) downto log2ext(linesize);
    subtype TAG_INDEX_R is natural range 31 downto log2ext(linesize);
    subtype OFFSET_R is natural range log2ext(linesize) - 1 downto 0;

    type pLRU_data_t is array (0 to 2 ** addr_depth) of std_logic_vector(0 to ways - 2);
    type tag_data_t is array (0 to ways - 1) of std_logic_vector(tag_dbits - 1 downto 0);
    type cache_data_t is array (0 to ways - 1) of std_logic_vector(linesize * 8 - 1 downto 0);

    type tag_match_ret_type is record
        index : integer range 0 to ways - 1;
        hit   : std_ulogic;
    end record;

    type reg_type is record
        pr_counter       : integer range 0 to ways;
        rep_index        : integer range 0 to ways - 1;
        tag_temp         : std_logic_vector(TAG_DATA_R);
        cache_w_seq      : std_ulogic;
        backend_buf      : std_logic_vector(linesize * 8 - 1 downto 0);
        backend_buf_addr : std_logic_vector(31 downto 0);
        hburst           : std_logic_vector(2 downto 0);
        htrans           : std_logic_vector(1 downto 0);
        hsize            : std_logic_vector(2 downto 0);
        hsel             : std_logic_vector(0 to NAHBSLV - 1);
        hwdata           : std_logic_vector(AHBDW - 1 downto 0);
        haddr            : std_logic_vector(31 downto 0);
        cache_data_in_frontend : std_logic_vector(linesize * 8 - 1 downto 0);
        pLRU_data              : pLRU_data_t;
        tag_match_ret : tag_match_ret_type;
        haddr_buffer : std_logic_vector(31 downto 0);
        hwrite_buffer : std_ulogic;
        hsize_buffer  : std_logic_vector(2 downto 0);
        tagstat : std_logic_vector(1 downto 0);
        evict : std_ulogic;
        frontend_buf : std_logic_vector(linesize * 8 - 1 downto 0);
        f_way_counter               : integer range 0 to ways;
        f_addr_counter              : integer range 0 to waysize * (2 ** 10) / linesize;
        f_index                     : integer range 0 to waysize * (2 ** 10) / linesize;
        f_addr                      : std_logic_vector(addr_depth - 1 downto 0);
        f_entry_delay, f_exit_delay : std_ulogic;
    end record;

    ----------------------- FUNCTIONS -------------------------------

    ---- FUNCTION DESCRIPTION:
    --          Compares incomming accesses tag and compares to what is present in the memory at that address index. If there is a match,
    --          and the valid bit is set to '1' we return the match index and a hit flag.
    function tag_match (tag_ways : tag_data_t; tag_request : std_logic_vector(tag_len - 1 downto 0)) return tag_match_ret_type is
        variable temp : tag_match_ret_type := (0, '0');
    begin
        for i in 0 to ways - 1 loop
            if tag_ways(i)(TAG_DATA_R) = tag_request and tag_ways(i)(VALID_BIT) = '1' then
                temp.index := i; -- HIT
                temp.hit   := '1';
                return(temp);
            end if;
        end loop;
        return(temp);
    end;

    ---- PROCEDURE DESCRIPTION:
    --          Updates the pLRU bits to indicate which was the most recent access.
procedure pLRU_update (variable pLRU_data : out pLRU_data_t;
    signal address                            : in std_logic_vector(addr_depth - 1 downto 0);
    variable hit_index                        : in integer range 0 to 63) is
    variable index                            : integer range 0 to ways - 1 := hit_index;
begin
    index := hit_index / 2 + (ways/2 - 1);
    if (hit_index rem 2) = 0 then
        pLRU_data(to_integer(unsigned(address)))(index) := '0';
    else
        pLRU_data(to_integer(unsigned(address)))(index) := '1';
    end if;
    for i in 1 to log2ext(ways - 1) loop
        if (index rem 2) = 0 then
            index                                           := index/2 - 1;
            pLRU_data(to_integer(unsigned(address)))(index) := '1';
        else
            index                                           := index/2;
            pLRU_data(to_integer(unsigned(address)))(index) := '0';
        end if;
    end loop;
end pLRU_update;

---- PROCEDURE DESCRIPTION:
--          Traverses the pLRU tree to find the "Least recently used" index.
procedure pLRU_evict(variable pLRU_data : in std_logic_vector(0 to ways - 2);
    variable output_index                   : out integer range 0 to ways - 1) is
    variable index                          : integer range 0 to ways - 1 := 0;
begin
    for i in 1 to log2ext(ways - 1) loop
        if pLRU_data(index) = '0' then
            index := 2 * index + 1 + 1;
        else
            index := 2 * index + 1;
        end if;
    end loop;
    if pLRU_data(index) = '0' then
        output_index := 2 * (index - (ways/2 - 1)) + 1;
    else
        output_index := 2 * (index - (ways/2 - 1));
    end if;
end pLRU_evict;

---- PROCEDURE DESCRIPTION:
--          Checks whether or not cache-line should be evicted. If it should be evicted the correct address and data is
--          forwarded to the backend interface together with an eviction flag.
procedure line_evict(signal tag_data : in tag_data_t;
    signal cache_data               : in cache_data_t;
    signal address                  : in std_logic_vector(32 - 1 downto 0);
    variable rep_index              : in integer range 0 to ways - 1;
    variable data_buffer            : out std_logic_vector(linesize * 8 - 1 downto 0);
    variable address_buffer         : out std_logic_vector(32 - 1 downto 0);
    variable evict_flag             : out std_ulogic) is
begin
    if (tag_data(rep_index)(VALID_BIT) and tag_data(rep_index)(DIRTY_BIT)) = '1' then
        data_buffer             := cache_data(rep_index);
        address_buffer          := (others => '0');
        address_buffer(TAG_R)   := tag_data(rep_index)(TAG_DATA_R);
        address_buffer(INDEX_R) := address(INDEX_R);
        evict_flag              := '1';
    end if;
end procedure;

constant init_r : reg_type := (pr_counter => 0,
    rep_index                                 => 0,
    tag_temp => (others => '0'),
    cache_w_seq                               => '0',
    backend_buf => (others => 'U'),
    backend_buf_addr => (others => '0'),
    hburst => (others => '0'),
    htrans => (others => '0'),
    hsel => (others => '0'),
    hsize => (others => '0'),
    hwdata => (others => '0'),
    haddr => (others => '0'),
    cache_data_in_frontend => (others => '0'),
    pLRU_data => (others => (others => '0')),
    tag_match_ret                             => (0, '0'),
    haddr_buffer => (others => '0'),
    hwrite_buffer                             => '0',
    hsize_buffer => (others => '0'),
    tagstat => (others => '0'),
    evict                                     => '0',
    frontend_buf => (others => '0'),
    f_way_counter                             => 0,
    f_addr_counter                            => 0,
    f_index                                   => 0,
    f_addr => (others => '0'),
    f_entry_delay                             => '1',
    f_exit_delay                              => '1');

---- SIGNALS ----
signal cachedataout : cache_data_t;
signal w_en         : std_logic_vector(0 to ways - 1);
signal r_en         : std_ulogic;

signal tagdatain     : std_logic_vector(tag_dbits - 1 downto 0);
signal c_hit, c_miss : std_ulogic;

signal rwaddr : std_logic_vector(addr_depth - 1 downto 0);

signal cachedatain : std_logic_vector(linesize * 8 - 1 downto 0);
signal tagdataout  : tag_data_t;

signal r   : reg_type;
signal rin : reg_type;

begin

ctrlo.backend_buf(linesize * 8 - 1 downto 0) <= r.backend_buf;
ctrlo.backend_buf_addr                       <= r.backend_buf_addr;

---- GENERATE SYNCRAM FOR TAG DATA ----
tag_ram_gen : for i in 0 to ways - 1 generate
    tag_ram : syncram_2p
    generic map(
        tech     => tech,
        abits    => addr_depth,
        dbits    => tag_dbits,
        sepclk   => 0,
        wrfst    => 1,
        testen   => 0,
        pipeline => 0)
    port map(
        rclk     => clk,
        renable  => r_en,
        raddress => rwaddr,
        dataout  => tagdataout(i),
        wclk     => clk,
        write    => w_en(i),
        waddress => rwaddr,
        datain   => tagdatain);
end generate;

---- GENERATE SYNCRAM FOR CACHE DATA ----
cache_ram_gen : for i in 0 to ways - 1 generate
    cache_ram : syncram_2p
    generic map(
        tech     => tech,
        abits    => addr_depth,
        dbits    => linesize * 8,
        sepclk   => 0,
        wrfst    => 1,
        testen   => 0,
        pipeline => 0)
    port map(
        rclk     => clk,
        renable  => r_en,
        raddress => rwaddr,
        dataout  => cachedataout(i),
        wclk     => clk,
        write    => w_en(i),
        waddress => rwaddr,
        datain   => cachedatain);
end generate;

comb : process (r, ahbsi, rstn, ctrli, tagdataout, cachedataout)
    variable v        : reg_type;
    variable counter  : integer range 0 to AHBDW/8;
    variable c_offset : integer range 0 to linesize-1;

begin
    ---- SAMPLE FRONTEND BUS ----
    v        := r;
    v.hburst := ahbsi.hburst;
    v.htrans := ahbsi.htrans;
    v.haddr  := ahbsi.haddr;
    v.hwdata := ahbsi.hwdata;
    v.hsize  := ahbsi.hsize;
    v.hsel   := ahbsi.hsel;
    ---- RESET ----
    r_en <= '0';
    w_en <= (others => '0');
    v.cache_w_seq := '0';
    v.tag_temp    := (others => '0');
    ctrlo.c_miss <= '0';
    ctrlo.c_hit  <= '0';
    ctrlo.f_done <= '0';

    case ctrli.cachectrl_s is
        when IDLE_S =>
            v.evict := '0';
            r_en <= '1';
            if (ctrli.seq_restart and r.hsel(hsindex) and r.htrans(1)) = '1' then

                v.haddr_buffer := r.haddr;
                v.hsize_buffer := r.hsize;

            elsif (ahbsi.hsel(hsindex) and ahbsi.htrans(1)) = '1' and bank_select(ahbsi.hmbsel and active_mem_banks) then

                r_en <= '1';
                v.hsize_buffer := v.hsize;
                v.haddr_buffer := ahbsi.haddr;

            end if;

        when READ_S =>

            v.tag_match_ret := tag_match(tagdataout, r.haddr_buffer(TAG_R));
            r_en <= '1';

            if v.tag_match_ret.hit = '0' then ---- CACHE MISS & BACKEND NOT BUSY ----
                if ctrli.backendw_s = IDLE_S then
                    ctrlo.c_miss <= '1';

                    if repl = 1 then ---- PLRU ----

                        pLRU_evict(v.pLRU_data(to_integer(unsigned(r.haddr_buffer(INDEX_R)))), v.rep_index);

                        v.tagstat(DIRTY_BIT) := '0';
                        v.tagstat(VALID_BIT) := '1';

                    else ---- P_RANDOM ----

                        v.rep_index          := r.pr_counter;
                        v.tagstat(DIRTY_BIT) := '0';
                        v.tagstat(VALID_BIT) := '1';

                    end if;

                    line_evict(tagdataout, cachedataout, r.haddr_buffer, v.rep_index, v.backend_buf, v.backend_buf_addr, v.evict);
                end if;

            else ---- CACHE HIT ----

                if repl = 1 then
                    pLRU_update(v.pLRU_data, r.haddr_buffer(INDEX_R), v.tag_match_ret.index);
                end if;

                r_en        <= '1';
                ctrlo.c_hit <= '1';
                v.frontend_buf := cachedataout(v.tag_match_ret.index);

            end if;

        when WRITE_S =>

            v.tag_match_ret := tag_match(tagdataout, r.haddr_buffer(TAG_R));
            r_en <= '1';

            if v.tag_match_ret.hit = '0' then
                if ctrli.backendw_s = IDLE_S then ---- CACHE MISS & BACKEND NOT BUSY ----
                    ctrlo.c_miss <= '1';

                    if repl = 1 then ---- PLRU ----

                        pLRU_evict(v.pLRU_data(to_integer(unsigned(r.haddr_buffer(INDEX_R)))), v.rep_index);
                        v.tagstat(DIRTY_BIT) := '0';
                        v.tagstat(VALID_BIT) := '1';

                    else ---- P_RANDOM ----
                        v.rep_index          := r.pr_counter;
                        v.tagstat(DIRTY_BIT) := '0';
                        v.tagstat(VALID_BIT) := '1';

                    end if;

                    line_evict(tagdataout, cachedataout, r.haddr_buffer, v.rep_index, v.backend_buf, v.backend_buf_addr, v.evict);

                end if;

            else ---- CACHE HIT ----

                if repl = 1 then
                    pLRU_update(v.pLRU_data, r.haddr_buffer(INDEX_R), v.tag_match_ret.index);
                end if;

                ctrlo.c_hit <= '1';
                v.tagstat(DIRTY_BIT) := '1';
                v.tagstat(VALID_BIT) := '1';

                if r.cache_w_seq = '1' then

                    w_en(v.tag_match_ret.index) <= '1';
                    r_en                        <= '0';

                else
                    v.cache_data_in_frontend := cachedataout(v.tag_match_ret.index);
                    v.tag_temp               := tagdataout(v.tag_match_ret.index)(TAG_DATA_R);

                    v.cache_w_seq := '1'; -- ONLY CHECKED IF WE STAY IN WRITE STATE.
                    r_en <= '1';

                end if;

                if endianess = 1 then
                    v.hwdata := reversedata(v.hwdata, 8);
                end if;

                counter  := 0;
                c_offset := to_integer(unsigned(r.haddr_buffer(OFFSET_R)));
                for i in 0 to linesize - 1 loop
                    if (i > (c_offset - 1)) and (i < (c_offset + size_vector_to_int(r.hsize_buffer))) then
                        v.cache_data_in_frontend(linesize * 8 - 8 * i - 1 downto linesize * 8 - 8 * (i + 1)) 
                        := v.hwdata(AHBDW - 8 * counter - 1 downto AHBDW - 8 * (counter + 1));
                        counter := counter + 1;
                    end if;
                end loop;

            end if;

        when W_INCR_S =>

            if endianess = 1 then
                v.hwdata := reversedata(v.hwdata, 8);
            end if;

            counter  := 0;
            c_offset := to_integer(unsigned(r.haddr(OFFSET_R)));
            for i in 0 to linesize - 1 loop
                if (i > (c_offset - 1)) and (i < (c_offset + size_vector_to_int(r.hsize_buffer))) then
                    v.cache_data_in_frontend(linesize * 8 - 8 * i - 1 downto linesize * 8 - 8 * (i + 1)) 
                    := v.hwdata(AHBDW - 8 * counter - 1 downto AHBDW - 8 * (counter + 1));
                    counter := counter + 1;
                end if;
            end loop;

            w_en(v.tag_match_ret.index) <= '1';
            v.tagstat(DIRTY_BIT) := '1';
            v.tagstat(VALID_BIT) := '1';

        when R_INCR_S =>
            r_en <= '1';

        when BACKEND_READ_S =>

            ---- ASSERTED WHEN FETCH IS FINISHED ----
            if ctrli.fetch_ready = '1' then
                w_en(r.rep_index) <= '1';
            end if;

        when FLUSH_S                        =>
            v.cache_data_in_frontend := (others => 'U');
            v.haddr_buffer(TAG_R)    := (others => 'U');

            v.f_index := v.f_addr_counter;
            if r.f_exit_delay = '1' then
                v.f_exit_delay := '0';

            elsif ctrli.backendw_s = IDLE_S then
                r_en <= '1';
                v.f_addr := conv_std_logic_vector(v.f_index, r.f_addr'length);
                if r.f_entry_delay = '0' then

                    if (tagdataout(v.f_way_counter)(VALID_BIT) and tagdataout(v.f_way_counter)(DIRTY_BIT)) = '1' then
                        v.backend_buf                := cachedataout(v.f_way_counter);
                        v.backend_buf_addr(TAG_R)    := tagdataout(v.f_way_counter)(TAG_DATA_R);
                        v.backend_buf_addr(INDEX_R)  := v.f_addr;
                        v.backend_buf_addr(OFFSET_R) := (others => '0');
                        v.evict                      := '1';
                        v.rep_index                  := v.f_way_counter;
                    else
                        w_en(v.f_way_counter) <= '1';
                        v.tagstat(VALID_BIT) := '0';
                        v.f_entry_delay      := '1';
                        v.f_exit_delay       := '1';
                    end if;

                    if v.f_way_counter + 1 = ways then
                        v.f_way_counter := 0;                              -- reset way counter 
                        if (v.f_addr_counter) = (2 ** addr_depth - 1) then -- ending flush
                            ctrlo.f_done <= '1';
                            v.f_addr_counter := 0;
                        else
                            v.f_addr_counter := r.f_addr_counter + 1; -- regular address incrementing
                        end if;
                    else
                        v.f_way_counter := r.f_way_counter + 1;
                    end if;
                else
                    v.f_entry_delay := '0';
                end if;
            end if;

            if ctrli.backendw_s = BACKEND_WRITE_S and v.evict = '1' then
                v.evict := '0';
                w_en(r.rep_index) <= '1';
                v.tagstat(1)    := '0';
                v.f_entry_delay := '1';
            end if;

        when others => null;
    end case;

    ---- CACHE INPUT MUX ----
    if ctrli.cachectrl_s = BACKEND_READ_S or ctrli.cachectrl_s = READ_S then
        cachedatain <= ctrli.cache_data_in_backend(linesize * 8 - 1 downto 0);
    else
        cachedatain <= v.cache_data_in_frontend;
    end if;

    ---- TAG DATA INPUT MUX ----
    if r.cache_w_seq = '1' then
        tagdatain(TAG_DATA_R) <= r.tag_temp;
    else
        tagdatain(TAG_DATA_R) <= r.haddr_buffer(TAG_R);
    end if;

    ---- TAG & DATA ADDRESS INPUT MUX ----
    if ctrli.cachectrl_s = FLUSH_S then
        rwaddr <= v.f_addr;
    else
        rwaddr <= v.haddr_buffer(INDEX_R);
    end if;

    ---- PSEUDO RANDOM COUNTER ----
    v.pr_counter := r.pr_counter + 1;
    if r.pr_counter = ways - 1 then
        v.pr_counter := 0;
    end if;

    ---- OUTPUTS ----
    tagdatain(1 downto 0)                         <= v.tagstat(1 downto 0);
    ctrlo.frontend_buf(linesize * 8 - 1 downto 0) <= v.frontend_buf;
    ctrlo.evict                                   <= v.evict;

    rin <= v;

end process;

---- ASYNC RESET ----
regs : process (clk, rstn)
begin
    if rstn = '0' then
        r <= init_r;
    elsif rising_edge(clk) then
        r <= rin;
    end if;
end process;

end architecture rtl;
