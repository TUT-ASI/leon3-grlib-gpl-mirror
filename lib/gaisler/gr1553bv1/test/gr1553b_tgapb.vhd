------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
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
-------------------------------------------------------------------------------
-- GR1553B test signal generator with APB interface
-- Author: Magnus Hjorth, Aeroflex Gaisler
--
-------------------------------------------------------------------------------
-- Connects between gr1553b and 1553 transciever
-- In normal mode, passes signals straight through
-- In test mode, disconnects bus and connects test gen to gr1553b input
-- In external fault-injection mode, connects the test gen to the transceiver
--
-- Note: Fault-injection mode should only be built-in and used in test
-- equipment, since it introduces new failure modes to the bus system.
-------------------------------------------------------------------------------
-- APB regs:
-- 0x00: Config/Status
--   Read: 
--     Bit 31: Constant '1' (test gen present)
--     Bit 30: '1' if bit-bang transmitter present
--     Bit 27-24: Bit-bang transmit FIFO depth 2-log "1000"=256 words
--     Bit  8: Bit-bang ready for more data (check after every half-FIFO written)
--     Bit  7-4: Bit-bang clock scaler (0=50ns/sample, 1=100, ..., 15=800ns/sample)
--     Bit  3: Fault-injection mode enabled (generated words are sent onto bus) 
--     Bit  2: Word queue full
--     Bit  1: '1' if testgen transmitter active, '0' if idle
--     Bit  0: Test mode enabled
--   Write:
--     Bit 31-4: Don't care
--     Bit  7-4: Bit-bang clock scaler (0=50ns/sample, 1=100, ..., 15=800ns/sample)
--     Bit    3: Fault-injection mode enable
--     Bit  2-1: Don't care
--     Bit    0: Test mode enable
--
-- 0x04: Data out
--   Write:
--     Bit 27-18: Start time spec (us)
--       If queue is empty, set to start time delay relative to current time.
--       If last in queue is one discontinuous word, delay should be 0 for adding a
--       continous word or gap+20 for a discontinuous word. 
--       If last in queue are two or more back-to-back words, set delay to 0 for
--       adding another cont word or 37+gap for a discont. word.
--     Bit    17: Bus selection 0=A, 1=B
--     Bit    16: Word type (0=Data, 1=Command/status)
--     Bit  15-0: Word data bits
--
-- 0x08: Bit-bang data out
--   Write:
--     Bit 31-30: Bus A value #0 (P,N)
--     Bit 29-28: Bus A value #1
--     Bit 27-16: Bus A value #2...#7
--     Bit 15- 0: Bus B value #0...#7
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use work.gr1553b_pkg.all;
use work.gr1553b_core.all;

entity gr1553b_tgapb is
  generic(
    codec_clk_freq_mhz: integer;
    sameclk: integer range 0 to 1 := 0;
    -- APB config
    pindex : integer := 0;
    paddr: integer := 0;
    pmask : integer := 16#fff#;
    -- Should only be enabled for dedicated test HW, not for production
    -- RT:s/BC:s
    extmodeen: integer range 0 to 1 := 0;
    bitbangen: integer range 0 to 1 := 0;
    memtech:   integer
    );
  port(
    clk: in std_logic;
    rst: in std_logic;

    codec_clk: in std_logic;
    codec_rst: in std_logic;

    apbsi: in apb_slv_in_type;
    apbso: out apb_slv_out_type;

    txout_core: in gr1553b_txout_type;
    rxin_core: out gr1553b_rxin_type;

    txout_bus: out gr1553b_txout_type;
    rxin_bus: in gr1553b_rxin_type;

    testing: out std_logic
    );
end entity;

architecture rtl of gr1553b_tgapb is

  type word_queue_item is record
    dv: std_logic;
    delay: unsigned(9 downto 0);
    bussel: std_logic;
    w: gr1553b_word;
  end record;
  
  type word_queue is array (natural range <>) of word_queue_item;
  
  type testgen_regs is record
    wq: word_queue(0 to 7);
    testmode: std_logic;
    bussel: std_logic;
    extmode: std_logic;
    bbscaler: std_logic_vector(3 downto 0);
    bbstart: std_logic;
    bbdone_sync,bbdone: std_logic;
    waddr: std_logic_vector(7 downto 0);
  end record;

  signal r,nr: testgen_regs;

  type bitbang_regs is record
    bbdone: std_logic;
    bbstart_sync,bbstart: std_logic;
    raddr: std_logic_vector(7 downto 0);
    shreg: std_logic_vector(31 downto 0);
    shctr: std_logic_vector(2 downto 0);
    bbscaler: std_logic_vector(3 downto 0);
    bbscalecnt: std_logic_vector(3 downto 0);
  end record;

  signal bbr,bbnr: bitbang_regs;
  
  constant venid: integer := VENDOR_GAISLER;
  constant devid: integer := GAISLER_1553TST;
  constant version: integer := 0;
  constant cfgver: integer := 0;
  
  constant pconfig: apb_config_type := (
    0 => ahb_device_reg ( venid, devid, cfgver, version, 0 ),
    1 => apb_iobar(paddr, pmask )
    );

  signal seri: gr1553b_tx1_in;
  signal sero: gr1553b_tx1_out;
  signal biti_amba, biti_codec: gr1553b_tx2_in;
  signal bito_amba, bito_codec: gr1553b_tx2_out;
    
  signal test_txout_pos,test_txout_neg: std_logic;

  signal us_clear,us_tick: std_logic;

  signal bbfifo_rad,bbfifo_wad: std_logic_vector(7 downto 0);
  signal bbfifo_rd,bbfifo_wd: std_logic_vector(31 downto 0);
  signal bbfifo_wen: std_logic;
  signal bbtxAP, bbtxAN, bbtxBP, bbtxBN: std_logic;
  
begin

  -----------------------------------------------------------------------------
  -- 1553 Transmitter
  -- 
  txser0: gr1553b_tx1
    generic map (syncrst => 1)
    port map (
      clk => clk, rst => rst,
      seri => seri,
      sero => sero,
      biti => biti_amba,
      bito => bito_amba
      );
  syncgen: if sameclk = 0 generate
    txsync0: gr1553b_tx12sync
      generic map (syncrst => 1)
      port map (
        ser_clk => clk,
        ser_rst => rst,
        ser_biti => biti_amba,
        ser_bito => bito_amba,
        out_clk => codec_clk,
        out_rst => codec_rst,
        out_biti => biti_codec,
        out_bito => bito_codec
        );
  end generate;
  nsyncgen: if sameclk = 1 generate
    biti_codec <= biti_amba;
    bito_amba <= bito_codec;
  end generate;
  txout0: gr1553b_tx2
    generic map (clk_freq_mhz => codec_clk_freq_mhz, txreg => true, syncrst => 1)
    port map (
      clk => codec_clk,
      rst => codec_rst,
      biti => biti_codec,
      bito => bito_codec,
      txout_pos => test_txout_pos,
      txout_neg => test_txout_neg
      );

  -----------------------------------------------------------------------------
  -- Timer
  --
  tick0: gr1553b_mhztick
    generic map (timeclk_freq_mhz => codec_clk_freq_mhz, sameclk => sameclk, syncrst => 1)
    port map (
      clk => clk, rst => rst,
      restart => '0', clear => us_clear, tick => us_tick,
      timeclk => codec_clk, timerst => codec_rst
      );

  
  -----------------------------------------------------------------------------
  -- Bit-banger
  bbgen: if bitbangen=1 generate
    
    bbfifo: syncram_2p
      generic map (tech => memtech, abits => 8, dbits => 32, sepclk => 1)
      port map (rclk => codec_clk, renable => '1',
                raddress => bbfifo_rad, dataout => bbfifo_rd,
                wclk => clk, write => bbfifo_wen, waddress => bbfifo_wad,
                datain => bbfifo_wd);
    
    bbcomb: process(bbr,r,bbfifo_rd,codec_rst)
      variable v: bitbang_regs;
    begin
      v := bbr;
      
      v.bbscaler := r.bbscaler;         -- Clock-domain crossing
      v.bbstart_sync := r.bbstart;      -- Clock-domain crossing
      v.bbstart := bbr.bbstart_sync;
      
      if bbr.bbdone = bbr.raddr(7) then
        v.bbdone := bbr.bbstart;
        v.bbscalecnt := bbr.bbscaler;
      elsif bbr.bbscalecnt="0000" then
        v.bbscalecnt := bbr.bbscaler;
        v.shctr := std_logic_vector(unsigned(bbr.shctr)+1);
        v.shreg(31 downto 18) := bbr.shreg(29 downto 16);
        v.shreg(15 downto  2) := bbr.shreg(13 downto  0);
        if bbr.shctr="111" then
          v.shreg := bbfifo_rd;
          v.raddr := std_logic_vector(unsigned(bbr.raddr)+1);
        end if;
      else
        v.bbscalecnt := std_logic_vector(unsigned(bbr.bbscalecnt)-1);
      end if;
      
      if codec_rst='0' then
        v.bbdone := '0';
        v.raddr := (others => '0');
        v.shctr := "000";
        v.shreg(31) := '0';
        v.shreg(30) := '0';
        v.shreg(15) := '0';
        v.shreg(14) := '0';
      end if;

      bbtxap <= bbr.shreg(31);
      bbtxan <= bbr.shreg(30);
      bbtxbp <= bbr.shreg(15);
      bbtxbn <= bbr.shreg(14);
      bbfifo_rad <= bbr.raddr;
      bbnr <= v;
    end process;
    
    bbregs: process(codec_clk)
    begin
      if rising_edge(codec_clk) then
        bbr <= bbnr;
      end if;
    end process;
    
  end generate;

  nbbgen: if bitbangen=0 generate
    bbr <= ('0','0','0',x"00",x"00000000","000","0000","0000");
    bbnr <= ('0','0','0',x"00",x"00000000","000","0000","0000");
    bbfifo_rad <= (others => '0');
    bbfifo_rd <= (others => '0');
    bbtxap <= '0';
    bbtxan <= '0';
    bbtxbp <= '0';
    bbtxbn <= '0';
  end generate;
    
    
  -----------------------------------------------------------------------------
  -- 
  comb: process(r,bbr,rst,apbsi,txout_core,test_txout_pos,test_txout_neg,rxin_bus,sero,bito_amba,us_tick,
                bbtxap,bbtxan,bbtxbp,bbtxbn)
    variable v: testgen_regs;
    variable vseri: gr1553b_tx1_in;
    variable vtxout: gr1553b_txout_type;
    variable vrxin: gr1553b_rxin_type;
    variable vtxstart: std_logic;
    variable do_write: boolean;
    variable wrdata,rddata: std_logic_vector(31 downto 0);
    variable clear_queue: boolean;
    variable wt: gr1553b_word_type;
    variable queue_empty: std_logic;
    variable testoutAP,testoutAN,testoutBP,testoutBN: std_logic;
    variable vfifowen: std_logic;
  begin
    v := r;    
    vtxout := txout_core;
    vrxin := rxin_bus;
    vtxstart := '0';
    vfifowen := '0';
    clear_queue := false;

    testoutAP := bbtxap;
    testoutAN := bbtxan;
    testoutBP := bbtxbp;
    testoutBN := bbtxbn;

    -- Signal switching logic
    if r.bussel='1' then
      testoutBP := testoutBP or test_txout_pos;
      testoutBN := testoutBN or test_txout_neg;
    else
      testoutAP := testoutAP or test_txout_pos;
      testoutAN := testoutAN or test_txout_neg;
    end if;
    
    if r.testmode='1' then
      
      vtxout := (busA_txP => '0', busA_txN => '0', busA_txen => '0',
                 busB_txP => '0', busB_txN => '0', busB_txen => '0', busA_rxen => '0', busB_rxen => '0',
                 busA_txin => '1', busB_txin => '1');
      vrxin := (busA_rxP => testoutAP, busA_rxN => testoutAN, busB_rxP => testoutBP, busB_rxN => testoutBN);
      if r.bussel='1' then
        vrxin.busB_rxP := test_txout_pos;
        vrxin.busB_rxN := test_txout_neg;
      else
        vrxin.busA_rxP := test_txout_pos;
        vrxin.busA_rxN := test_txout_neg;
      end if;

    end if;

    if r.extmode='1' then
      vtxout := (busA_txP => testoutAP, busA_txN => testoutAN, busA_txen => '1',
                 busB_txP => testoutBP, busB_txN => testoutBN, busB_txen => '1',
                 busA_rxen => '1', busB_rxen => '1', busA_txin => '0', busB_txin => '0');
    end if;
    
    -- Manage queue
    if r.testmode='1' or r.extmode='1' then
      if r.wq(0).dv='1' then
        if r.wq(0).delay="0000000000" then
          if (sero.ready='1' and r.wq(0).bussel=r.bussel) or bito_amba.done='1' then
            vtxstart := '1';
            v.bussel := r.wq(0).bussel;
          end if;
          if us_tick='1' and r.wq(1).dv='1' and r.wq(1).delay /= "0000000000" then
            v.wq(1).delay := r.wq(1).delay - 1;
          end if;
        elsif us_tick='1' then
          v.wq(0).delay := r.wq(0).delay - 1;
        end if;
      end if;
      if sero.read_data='1' then
        v.wq(0) := v.wq(1);
        v.wq(1).dv := '0';
      end if;
      
      for i in 0 to r.wq'high-1 loop
        if r.wq(i).dv='0' then
          v.wq(i) := r.wq(i+1);
          v.wq(i+1).dv := '0';
        end if;
      end loop;
    end if;

    -- Bit-banging interface signaling
    v.bbdone_sync := bbr.bbdone;
    v.bbdone := r.bbdone_sync;
    if r.bbdone=r.bbstart then
      v.bbstart := r.waddr(7);
    end if;
    
    -- APB interface
    do_write := false;
    if apbsi.pwrite='1' and apbsi.penable='1' and apbsi.psel(pindex)='1' then
      do_write := true;
    end if;

    wrdata := apbsi.pwdata;
    rddata := (others => '0');    
    case apbsi.paddr(7 downto 2) is
      when "000000" =>
        rddata(31) := '1';
        if bitbangen=1 then rddata(30):='1'; end if;
        rddata(27 downto 24) := "1000";
        if bitbangen=1 and r.bbdone=r.bbstart then rddata(8):='1'; end if;
        rddata(7 downto 4) := r.bbscaler;
        rddata(3) := r.extmode;
        rddata(2) := r.wq(r.wq'high).dv;
        rddata(1) := r.wq(0).dv or not bito_amba.done;
        rddata(0) := r.testmode;
        if do_write then
          if bitbangen /= 0 then
            v.bbscaler := wrdata(7 downto 4);
          end if;
          if extmodeen /= 0 then
            v.extmode := wrdata(3);
          end if;
          v.testmode := wrdata(0);
          clear_queue := true;
        end if;
        
      when "000001" =>
        if do_write then
          v.wq(v.wq'high) := (
            dv => '1',
            delay => unsigned(wrdata(27 downto 18)),
            bussel => wrdata(17),
            w => (t => sl_to_wt(wrdata(16)),
                  data => wrdata(15 downto 0))
            );
        end if;

      when "000010" =>
        if do_write then
          vfifowen := '1';
          v.waddr := std_logic_vector(unsigned(r.waddr)+1);
        end if;
        
      when others =>
        null;
        
    end case;
      
    if rst='0' then
      v.testmode := '0';
      v.extmode := '0';
      v.waddr := "00000000";
      v.bbstart := '0';
      v.bbscaler := "1010";
      clear_queue := true;
    end if;

    if clear_queue then
      for i in v.wq'range loop
        v.wq(i).dv := '0';
      end loop;
      v.waddr(6 downto 0):="0000000";
    end if;

    vseri := (abort => '0', start => vtxstart, word => r.wq(0).w);
    
    nr <= v;
    testing <= r.testmode;
    txout_bus <= vtxout;
    rxin_core <= vrxin;
    seri <= vseri;
    us_clear <= not ((r.testmode or r.extmode) and r.wq(0).dv);
    bbfifo_wad <= r.waddr;
    bbfifo_wen <= vfifowen;
    bbfifo_wd  <= wrdata;
    apbso <= (prdata => rddata,
              pirq => (others => '0'),
              pconfig => pconfig,
              pindex => pindex);
  end process;
  
  regs: process(clk)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
  end process;
  
end;
