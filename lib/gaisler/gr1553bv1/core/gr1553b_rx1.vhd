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
-----------------------------------------------------------------------------
-- Entity:      gr1553b_rx1
-- File:        gr1553b_rx1.vhd
-- Author:      Magnus Hjorth - Aeroflex Gaisler
-- Description: GR1553B stage 1, detector (larger, two-bit version)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gr1553b_core.all;

library grlib;
use grlib.stdlib.notx;

entity gr1553b_rx1 is
  
  generic(
    -- Frequency of clk in MHz
    -- Clock must be even multiple of 2 MHz
    clk_freq_mhz: integer;
    -- For high clock frequencies, the input can be "downsampled"
    -- to reduce logic.
    -- This value can be any value up to (clk_freq_mhz/2)
    sample_freq_mhz: integer := 20;
    -- # of input sync registers to avoid metastability etc
    synclength: integer := 2;
    -- Amount of detected correlation to declare sync found
    sync_corr_min: integer range 1 to 100;
    -- Ditto for regular bits
    -- Note we have three times as much time to detect sync
    bit_corr_min: integer range 1 to 100;
    -- Set to 1 to get pipelined processing
    pipeline: integer range 0 to 1 := 1;
    syncrst: integer range 0 to 2
    );
  port (
    clk: in std_logic;
    rst: in std_logic;

    rxin_p: in std_logic;
    rxin_n: in std_logic;

    outs: out gr1553b_rx1_out
    );
end;

architecture rtl of gr1553b_rx1 is    

  function get_downsample(clk_freq, sample_freq, stepsize: integer) return integer is
    variable r: integer;
  begin
    r := sample_freq;
    loop
      if (clk_freq mod r)=0 then return clk_freq/r; end if;
      r := r + stepsize;
      if r > clk_freq then return 0; end if;
    end loop;
  end;

  constant downsample: integer := get_downsample(clk_freq_mhz,sample_freq_mhz,2);
  constant half_bittime: integer := clk_freq_mhz / (2*downsample);
  constant queue_length: integer := 6*half_bittime;

  constant q_be3_out: integer := half_bittime*6-1;
  constant q_be2_out: integer := half_bittime*5-1;
  constant q_be1_out: integer := half_bittime*4-1;
  constant q_ah1_out: integer := half_bittime*3-1;
  constant q_ah2_out: integer := half_bittime*2-1;
  constant q_ah3_out: integer := half_bittime*1-1;
  
  constant long_corr_thres: integer := int_divide_round(6*half_bittime*sync_corr_min,100);
  constant short_corr_thres: integer := int_divide_round(2*half_bittime*bit_corr_min,100);
    
  type queue_part_diff is record
    ahead_diff_p, ahead_diff_n: integer range -1 to +1;
    behind_diff_p, behind_diff_n: integer range -1 to +1;
    corr_diff: integer range -4 to +4;
  end record;

  function get_diff(inbit,outbit: std_logic) return integer is
  begin
    if inbit='1' and outbit/='1' then
      return 1;
    elsif inbit/='1' and outbit='1' then
      return -1;
    else
      return 0;
    end if;
  end;

  procedure update_corr(pd: in queue_part_diff;
                        int: in integer;
                        pd_out: out queue_part_diff;
                        int_out: out integer;
                        ahinp,ahinn,tp,tn,beoutp,beoutn: std_logic) is
    variable ahdp,ahdn,bedp,bedn: integer range -1 to +1;
    variable cd: integer range -4 to +4;
    variable io: integer;
  begin
    ahdp := get_diff(ahinp,tp);
    ahdn := get_diff(ahinn,tn);
    bedp := get_diff(tp,beoutp);
    bedn := get_diff(tn,beoutn);

    pd_out.ahead_diff_p := ahdp;
    pd_out.ahead_diff_n := ahdn;
    pd_out.behind_diff_p := bedp;
    pd_out.behind_diff_n := bedn;
   
    if pipeline=1 then
      cd:= pd.ahead_diff_p - pd.ahead_diff_n -
           pd.behind_diff_p + pd.behind_diff_n;
      io := int + pd.corr_diff;      
    else
      cd := +ahdp-ahdn-bedp+bedn;
      io := int + cd;      
    end if;

    pd_out.corr_diff := cd;
    int_out := io;    
  end;
  
  -- Data path: rxin_p/n => sync_p/n => ("11" protect) => queue_p/n

  type rx1_regs is record        
    sync_p,sync_n: std_logic_vector(synclength-1 downto 0);
    queue_p,queue_n: std_logic_vector(queue_length-1 downto 0);
    ds_count: integer range 0 to downsample-1;
    zcount: unsigned(7 downto 0);
    started: std_logic;
    
    long_diff: queue_part_diff;
    mid_diff: queue_part_diff;
    short_diff: queue_part_diff;
  
    long_corr_int: integer range -half_bittime*6 to +half_bittime*6;
    -- mid_corr_int: integer range -half_bittime*2 to +half_bittime*2 := 0;
    short_corr_int: integer range -half_bittime*2 to +half_bittime*2;

    -- This is used as a placeholder to track when the accumulator values above are
    -- "undefined" in simulation to avoid trigger over/underflow
    -- In real designs, the accumulators will be floating around until they are
    -- set to zero 256 clocks after reset (after 13 us at 20MHz)
    simdummy: std_logic;
  end record;

  constant r_rst: rx1_regs := (
    sync_p => (others => '0'), sync_n => (others => '0'),
    queue_p => (others => '0'), queue_n => (others => '0'),
    ds_count => 0,
    zcount => (others => '0'),
    started => '0',
    long_diff => (0,0,0,0,0), mid_diff => (0,0,0,0,0), short_diff => (0,0,0,0,0),
    long_corr_int => 0, short_corr_int => 0,
    simdummy => '0'               
    );
  
  signal r,nr: rx1_regs;
      
begin    
  
  comb: process(rxin_p,rxin_n,rst,r)
    variable v: rx1_regs;
    variable vo: gr1553b_rx1_out;
    
    variable use_sample: boolean;
    variable new_bit_p,new_bit_n: std_logic;   
    variable vcmd_sync_det: std_logic;
    variable vdata_sync_det: std_logic;
    variable vbit_det_p,vbit_det_n: std_logic;

    variable tmp: integer;
  begin
    -- Init vars
    v := r;
    use_sample := false;
    vcmd_sync_det := '0';
    vdata_sync_det := '0';
    vbit_det_n := '0';
    vbit_det_p := '0';
    tmp := 0;
        
    -- Downsample handling
    if r.ds_count=downsample-1 then
      v.ds_count := 0;
      use_sample := true;
    else
      v.ds_count := r.ds_count+1;
    end if;      

    v.sync_p := r.sync_p((synclength-2) downto 0) & rxin_p;
    v.sync_n := r.sync_n((synclength-2) downto 0) & rxin_n;

    new_bit_p := r.sync_p((synclength-1));
    new_bit_n := r.sync_n((synclength-1));

    -- Force zeros into the shift reg during startup
    if r.started='0' then
      new_bit_p := '0';
      new_bit_n := '0';
    end if;
    
    if use_sample then

      v.queue_p := r.queue_p((queue_length-2) downto 0) & new_bit_p;
      v.queue_n := r.queue_n((queue_length-2) downto 0) & new_bit_n;

      if notx(r.simdummy) then
        update_corr(r.long_diff, r.long_corr_int,
                    v.long_diff, v.long_corr_int,
                    new_bit_p, new_bit_n,
                    r.queue_p(q_ah1_out), r.queue_n(q_ah1_out),
                    r.queue_p(q_be3_out), r.queue_n(q_be3_out));
        update_corr(r.mid_diff, 0,
                    v.mid_diff, tmp,
                    r.queue_p(q_ah2_out), r.queue_n(q_ah2_out),
                    r.queue_p(q_ah1_out), r.queue_n(q_ah1_out),
                    r.queue_p(q_be1_out), r.queue_n(q_be1_out));
        update_corr(r.short_diff, r.short_corr_int,
                    v.short_diff, v.short_corr_int,
                    new_bit_p, new_bit_n,
                    r.queue_p(q_ah3_out),r.queue_n(q_ah3_out),
                    r.queue_p(q_ah2_out),r.queue_n(q_ah2_out));
      end if;

      -- Reset accumulators when zero count wraps
      if new_bit_p=new_bit_n and notx(std_logic_vector(r.zcount)) then
        v.zcount := r.zcount + 1;
        if r.zcount = "11111111" then
          
          -- For simulation, resetting the accumulators should never be needed,
          -- except on startup.
-- pragma translate_off
          assert r.started='0' or
            (r.long_diff=(others => 0) and r.long_corr_int=0 and
             r.mid_diff=(others => 0) and
             r.short_diff=(others => 0) and r.short_corr_int=0)
            report "Inconsistent state in simulation!" severity warning;
-- pragma translate_on
          
          v.long_diff := (others => 0);
          v.long_corr_int := 0;
          v.mid_diff := (others => 0);
          v.short_diff := (others => 0);
          v.short_corr_int := 0;
          v.simdummy := '0';
          v.started := '1';
        end if;
      else
        v.zcount := "00000000";
      end if;
      
    end if;
    
    -- Sync and bit detect
    if r.long_corr_int >= long_corr_thres and r.mid_diff.corr_diff < 0 then
      vdata_sync_det := '1';
    end if;
    if r.long_corr_int <= -long_corr_thres and r.mid_diff.corr_diff > 0 then
      vcmd_sync_det := '1';
    end if;
    if r.short_corr_int >= short_corr_thres then
      vbit_det_n := '1';
    end if;
    if r.short_corr_int <= -short_corr_thres then
      vbit_det_p := '1';
    end if;

    -- Reset
    if rst='0' and syncrst/=0 then
      v.started := '0';
      v.zcount := "00000000";
    end if;
    
    -- Assign signals
    vo := (vcmd_sync_det,vdata_sync_det,vbit_det_p,vbit_det_n);
    nr <= v;
    outs <= vo;
  end process;
  
  regs: process(clk,rst)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
    if rst='0' and syncrst=0 then
      r <= r_rst;
    end if;
  end process;

end;
