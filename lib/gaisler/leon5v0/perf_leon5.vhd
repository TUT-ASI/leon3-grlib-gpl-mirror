library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;


entity perf_leon5 is
  generic (
    pindex   : integer := 0;
    paddr    : integer := 0;
    pmask    : integer := 16#fff#);
  port (
    rstn     : in  std_ulogic;
    clk     : in  std_ulogic;
    perf    : in  std_logic_vector(255 downto 0);
    apbi   : in  apb_slv_in_type;
    apbo   : out apb_slv_out_type
    );
end;


architecture rtl of perf_leon5 is

  constant REVISION : integer := 0;

  constant pconfig : apb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_GPREG, 0, REVISION, 0),
    1 => apb_iobar(paddr, pmask));

type counter_a is array (0 to 15) of std_logic_vector(63 downto 0);
  
type reg_type is record
  perf : std_logic_vector(255 downto 0);
  start_xpc : std_logic_vector(31 downto 0);
  stop_xpc : std_logic_vector(31 downto 0);
  active : std_logic;
  counters : counter_a;
end record;


signal r, rin : reg_type;
  

begin

  comb: process(clk,perf,apbi,rstn)
    variable v: reg_type;
    variable readdata : std_logic_vector(31 downto 0);
  begin
    v:= r;

    v.perf := perf;

    if (r.perf(31 downto 2) = r.start_xpc(31 downto 2)) and r.perf(0) = '1' then
      v.active := '1';
    end if;
    if (r.perf(63 downto 34) = r.start_xpc(31 downto 2)) and r.perf(32) = '1' then
      v.active := '1';
    end if;
    if (r.perf(31 downto 2) = r.stop_xpc(31 downto 2)) and r.perf(0) = '1' then
      v.active := '0';
    end if;
    if (r.perf(63 downto 34) = r.stop_xpc(31 downto 2)) and r.perf(32) = '1' then
      v.active := '0';
    end if;

    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
      if apbi.paddr(11) = '1' then
        case apbi.paddr(6 downto 2) is
          when "00000" =>
            v.start_xpc := apbi.pwdata;
          when "00001" =>
            v.stop_xpc := apbi.pwdata;
          when "00010" =>
            v.active := apbi.pwdata(0);
          when "00011" =>
            --reset counters
            for i in 0 to 15 loop
              v.counters(i) := (others=>'0');
            end loop;
          when others =>
            null;
        end case;
      end if;
    end if;

    
    readdata := r.counters(to_integer(unsigned(apbi.paddr(6 downto 3))))(63 downto 32);
    if apbi.paddr(2) = '1' then
      readdata := r.counters(to_integer(unsigned(apbi.paddr(6 downto 3))))(31 downto 0);
    end if;
    
    if apbi.paddr(11) = '1' then
      case apbi.paddr(6 downto 2) is
        when "00000" =>
          readdata := r.start_xpc;
        when "00001" =>
          readdata := r.stop_xpc;
        when "00010" =>
          readdata(0) := r.active;
        when others =>
          readdata := (others=>'X');
      end case;
    end if;


    if r.active = '1' then
      --index ->0 total number of cycles
      v.counters(0) := std_logic_vector(unsigned(r.counters(0))+1);
      --index ->1 number of insts
      --index ->2 number of single issue
      if (r.perf(64) = '1' and r.perf(65) = '0') or (r.perf(64) = '0' and r.perf(65) = '1') then
        v.counters(1) := std_logic_vector(unsigned(r.counters(1))+1);
        v.counters(2) := std_logic_vector(unsigned(r.counters(2))+1);
      elsif r.perf(64) = '1' and r.perf(65) = '1' then
        v.counters(1) := std_logic_vector(unsigned(r.counters(1))+2);
      end if;
      --index ->3 number of branches
      if (r.perf(66) = '1' and r.perf(64) = '1') or (r.perf(67) = '1' and r.perf(65) = '1') then
        v.counters(3) := std_logic_vector(unsigned(r.counters(3))+1);
        --index ->4 number of misspredict
        if r.perf(68) = '1' then
          v.counters(4) := std_logic_vector(unsigned(r.counters(4))+1);
        end if;
      end if;
      --index ->5 total number of cycles lost on cache miss and store buffer delays
      if r.perf(69) = '1' then
        v.counters(5) := std_logic_vector(unsigned(r.counters(5))+1);
      end if;
      --index ->6 number of cycles lost during branch missprediction
      if r.perf(70) = '1' then
        v.counters(6) := std_logic_vector(unsigned(r.counters(6))+1);
      end if;
      --index ->7 number of stores
      if r.perf(71) = '1' and r.perf(64) = '1' then
        v.counters(7) := std_logic_vector(unsigned(r.counters(7))+1);
      end if;
      --index ->8 number of loads
      if r.perf(72) = '1' and r.perf(64) = '1' then
        v.counters(8) := std_logic_vector(unsigned(r.counters(8))+1);
      end if;
      --index ->9 number of IC misses
      if r.perf(73) = '1' then
        v.counters(9) := std_logic_vector(unsigned(r.counters(9))+1);
      end if;
      --index ->10 number of ITLB misses
      if r.perf(74) = '1' then
        v.counters(10) := std_logic_vector(unsigned(r.counters(10))+1);
      end if;
      --index ->11 number of DC misses
      if r.perf(75) = '1' then
        v.counters(11) := std_logic_vector(unsigned(r.counters(11))+1);
      end if;
      --index ->12 number of DTLB misses
      if r.perf(76) = '1' then
        v.counters(12) := std_logic_vector(unsigned(r.counters(12))+1);
      end if;
      --index ->13 number of flushed
      if r.perf(77) = '1' then
        v.counters(13) := std_logic_vector(unsigned(r.counters(13))+1);
      end if;
      
    end if;

    if rstn = '0' then
      v.active := '0';
    end if;

    rin <= v;

    apbo.prdata <= readdata;
    apbo.pirq <= (others => '0');
    apbo.pindex <= pindex;
    apbo.pconfig <= pconfig;
 
  end process;


  reg : process (clk)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

  
end;
