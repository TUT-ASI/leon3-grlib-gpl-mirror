library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.leon5int.all;
library techmap;
use techmap.gencomp.all;

entity l5stat is
  generic (
    cnt_width : integer range 1 to 64 := 32;
    ncores    : integer range 1 to 8  := 1;
    ninpipe   : integer range 1 to 2  := 1;
    hindex   : integer := 0;
    ioaddr    : integer := 0);
  port (
    rstn      : in  std_ulogic;
    clk       : in  std_ulogic;
    perf      : in  leon5_perf_array;
    ahbsi     : in  ahb_slv_in_type;
    ahbso     : out ahb_slv_out_type
    );
end;

architecture rtl of l5stat is

  function is_cnt64(width : integer) return integer is
  begin
    if width < 33 then
      return 0;
    else
      return 1;
    end if;
  end;

  function msb_read(width : integer) return integer is
  begin
    if width < 33 then
      return width-1;
    else
      return 31;
    end if;
  end;

  function cnt_off(width : integer) return integer is
  begin
    if width < 17 then
      return 16;
    else
      return 32;
    end if;
  end;

  constant ncounters : integer range 1 to 16 := 15;
  constant counter_off : integer range 1 to 32 := cnt_off(ncounters);
  

  constant REVISION : integer := 0;
  constant iomask : integer := 16#fc0#;
  constant hconfig : ahb_config_type := (
    0      => ahb_device_reg (VENDOR_GAISLER, GAISLER_L5STAT, 0, 0, 0),
    5      => ahb_iobar(ioaddr,iomask),
    others => zero32);

  type counter_a is array (0 to counter_off*ncores) of std_logic_vector(cnt_width-1 downto 0);
  type hstate is (idle,delay1,delay2);


  type reg_type is record
    perf_pipe0   : leon5_perf_array;
    perf_pipe1   : leon5_perf_array;
    active       : std_logic_vector(ncores-1 downto 0);
    reset        : std_logic_vector(ncores-1 downto 0);
    counters     : counter_a;
    counter_rd64 : std_logic_vector(cnt_width-1 downto 0);
    hrdata       : std_logic_vector(31 downto 0);
    haddr        : std_logic_vector(31 downto 0);
    hwaddr       : std_logic_vector(31 downto 0);
    hwrite       : std_logic;
    hupdate      : std_logic;
    hupdate2     : std_logic;
    hready       : std_logic;
    hwdata       : std_logic_vector(31 downto 0);
    state        : hstate;
  end record;

  constant cnt64 : integer range 0 to 1 := is_cnt64(cnt_width);

signal r, rin : reg_type;
  
begin

  comb: process(clk,perf,ahbsi,rstn)
    variable v: reg_type;
    variable readdata : std_logic_vector(31 downto 0);
    variable perf_mux : leon5_perf_array;
    variable counter_rd64 : std_logic_vector(cnt_width-1 downto 0);
  begin
    v:= r;

    v.perf_pipe0 := (others=>(others=>'0'));
    for i in 0 to ncores-1 loop
      v.perf_pipe0(i) := perf(i);
    end loop;
    v.perf_pipe1 := r.perf_pipe0;
    if ninpipe /= 2 then
      v.perf_pipe1 := (others => (others=>'0'));
    end if;

    perf_mux := r.perf_pipe0;
    if ninpipe = 2 then
      perf_mux := r.perf_pipe1;
    end if;

    v.hupdate  := '0';
    v.hupdate2 := '0';
    case r.state is
      when idle =>
        v.hready := '1';
        if r.hupdate = '1' then
          v.hupdate2 := '1';
          v.hwdata   := ahbselectdatabe(ahbsi.hwdata,r.hwaddr(4 downto 2),"010")(31 downto 0);
        end if;
      when delay1 =>
        v.state  := delay2;
      when delay2 =>
        v.state := idle;
        v.hready := '1';
        v.hwaddr := r.haddr;
        if r.hwrite = '1' then
          v.hupdate := '1';
        end if;
      when others =>
        null;
    end case;

    if ahbsi.hsel(hindex) = '1' and ahbsi.hready = '1' then
      v.haddr  := ahbsi.haddr;
      v.hwrite := ahbsi.hwrite;
      v.hready := '0';
      v.state := delay1;
    end if;

    v.reset := (others=>'0');
    if r.hupdate2 = '1' then
      if r.hwaddr(13 downto 12) = "10" then
        --configuration
        if r.hwaddr(3 downto 0) = "0000" then
          for i in 0 to ncores-1 loop
            v.active(i) := r.hwdata(i);
          end loop;
        end if;
        if r.hwaddr(3 downto 0) = "0100" then
          for i in 0 to ncores-1 loop
            v.reset(i) := r.hwdata(i);
          end loop;
        end if;        
      end if;     
    end if;
    
    counter_rd64 := r.counters(0);
    for i in 0 to ncores-1 loop
      if notx(r.haddr) then
        if to_integer(unsigned(r.haddr(9 downto 7))) = i then
          counter_rd64 := r.counters(counter_off*i + to_integer(unsigned(r.haddr(5+is_cnt64(cnt_width) downto 3))));
        end if;
      else
        setx(counter_rd64);
      end if;
    end loop;

    if r.state = delay1 then
      v.counter_rd64 := counter_rd64;
    end if;

    if r.state = delay2 then
      v.hrdata(cnt_width-32*cnt64-1 downto 0) := r.counter_rd64(cnt_width-1 downto 32*cnt64);
      if r.haddr(2) = '1' then
        v.hrdata(msb_read(cnt_width) downto 0) := r.counter_rd64(msb_read(cnt_width) downto 0);
      end if;
    end if;
    

    for i in 0 to ncores-1 loop
      if r.active(i) = '1' then
        --index ->0 total number of cycles
        if perf_mux(i)(11) = '1' then
          v.counters(counter_off*i) := std_logic_vector(unsigned(r.counters(counter_off*i))+1);
        end if;
        --index ->1 number of insts
        --index ->2 number of single issue
        if (perf_mux(i)(0) = '1' and perf_mux(i)(1) = '0') or (perf_mux(i)(1) = '0' and perf_mux(i)(0) = '1') then
          v.counters(counter_off*i+1) := std_logic_vector(unsigned(r.counters(counter_off*i+1))+1);
          v.counters(counter_off*i+2) := std_logic_vector(unsigned(r.counters(counter_off*i+2))+1);
        elsif perf_mux(i)(0) = '1' and perf_mux(i)(1) = '1' then
          v.counters(counter_off*i+1) := std_logic_vector(unsigned(r.counters(counter_off*i+1))+2);
        end if;
        --index ->3 number of branches
        if (perf_mux(i)(2) = '1' and perf_mux(i)(0) = '1') or (perf_mux(i)(3) = '1' and perf_mux(i)(1) = '1') then
          v.counters(counter_off*i+3) := std_logic_vector(unsigned(r.counters(counter_off*i+3))+1);
          --index ->4 number of misspredict
          if perf_mux(i)(4) = '1' then
            v.counters(counter_off*i+4) := std_logic_vector(unsigned(r.counters(counter_off*i+4))+1);
          end if;
        end if;
        --index ->5 total number of cycles lost on cache miss and store buffer delays
        if perf_mux(i)(5) = '1' then
          v.counters(counter_off*i+5) := std_logic_vector(unsigned(r.counters(counter_off*i+5))+1);
        end if;
        --index ->6 number of cycles lost during branch missprediction
        if perf_mux(i)(6) = '1' then
          v.counters(counter_off*i+6) := std_logic_vector(unsigned(r.counters(counter_off*i+6))+1);
        end if;
        --index ->7 number of stores
        if perf_mux(i)(7) = '1' and perf_mux(i)(0) = '1' then
          v.counters(counter_off*i+7) := std_logic_vector(unsigned(r.counters(counter_off*i+7))+1);
        end if;
        --index ->8 number of loads
        if perf_mux(i)(8) = '1' and perf_mux(i)(0) = '1' then
          v.counters(counter_off*i+8) := std_logic_vector(unsigned(r.counters(counter_off*i+8))+1);
        end if;
        --index ->9 number of IC misses
        if perf_mux(i)(59) = '1' then
          v.counters(counter_off*i+9) := std_logic_vector(unsigned(r.counters(counter_off*i+9))+1);
        end if;
        --index ->10 number of ITLB misses
        if perf_mux(i)(60) = '1' then
          v.counters(counter_off*i+10) := std_logic_vector(unsigned(r.counters(counter_off*i+10))+1);
        end if;
        --index ->11 number of DC misses
        if perf_mux(i)(61) = '1' then
          v.counters(counter_off*i+11) := std_logic_vector(unsigned(r.counters(counter_off*i+11))+1);
        end if;
        --index ->12 number of DTLB misses
        if perf_mux(i)(62) = '1' then
          v.counters(counter_off*i+12) := std_logic_vector(unsigned(r.counters(counter_off*i+12))+1);
        end if;
        --index ->13 number of flushed
        if perf_mux(i)(63) = '1' then
          v.counters(counter_off*i+13) := std_logic_vector(unsigned(r.counters(counter_off*i+13))+1);
        end if;
        --index ->14 number of fp ops
        if (perf_mux(i)(9) = '1' and perf_mux(i)(0) = '1') or (perf_mux(i)(10) = '1' and perf_mux(i)(1) = '1') then
          v.counters(counter_off*i+14) := std_logic_vector(unsigned(r.counters(counter_off*i+14))+1);
        end if;
      end if;
    end loop;

    if ncounters < 16 then
      for i in 0 to ncores-1 loop
        for j in ncounters to 15 loop
          v.counters((counter_off*i)+j) := (others=>'0');
        end loop;
      end loop;
    end if;

    if ncounters > 16 and ncounters < 32 then
      for i in 0 to ncores-1 loop
        for j in ncounters to 32 loop
          v.counters((counter_off*i)+j) := (others=>'0');
        end loop;
      end loop;
    end if;
    
    for i in 0 to ncores-1 loop
      if r.reset(i) = '1' then
        for j in 0 to ncounters-1 loop
          v.counters((counter_off*i)+j) := (others=>'0');
        end loop;
      end if;
    end loop;
          
    if rstn = '0' then
      v.active   := (others => '0');
      v.reset    := (others => '0');
      v.hupdate  := '0';
      v.hupdate2 := '0';
      v.hwrite   := '0';
      v.hready   := '1';
      v.state    := idle;
    end if;

    rin <= v;

    ahbso.hready  <= r.hready;
    ahbso.hrdata  <= ahbdrivedata(r.hrdata);
    ahbso.hresp   <= "00";
    ahbso.hirq    <= (others=>'0');
    ahbso.hsplit  <= (others=>'0');
    ahbso.hconfig <= hconfig;
    ahbso.hindex  <= hindex;
    
 
  end process;


  reg : process (clk)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

  
end;
