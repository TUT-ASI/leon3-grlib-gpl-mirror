------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2010, Aeroflex Gaisler
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
----------------------------------------------------------------------------   
-- Entity:      ahbctrl
-- File:        ahbctrl.vhd
-- Author:      Marko Isomaki, Aeroflex Gaisler
-- Description: AMBA arbiter, decoder and multiplexer with plug&play support
------------------------------------------------------------------------------ 

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real;
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.at_pkg.all;
use grlib.devices.all;
use std.textio.all;


entity at_ahb_ctrl is
  generic (
    defmast     : integer := 0;		-- default master
    split       : integer := 0;		-- split support
    rrobin      : integer := 0;		-- round-robin arbitration
    timeout     : integer range 0 to 255 := 0;  -- HREADY timeout
    ioaddr      : ahb_addr_type := 16#fff#;  -- I/O area MSB address
    iomask      : ahb_addr_type := 16#fff#;  -- I/O area address mask
    cfgaddr     : ahb_addr_type := 16#ff0#;  -- config area MSB address
    cfgmask     : ahb_addr_type := 16#ff0#;  -- config area address mask
    nahbm       : integer range 1 to NAHBMST := NAHBMST; -- number of masters
    nahbs       : integer range 1 to NAHBSLV := NAHBSLV; -- number of slaves
    ioen        : integer range 0 to 15 := 1;    -- enable I/O area
    disirq      : integer range 0 to 1 := 0;     -- disable interrupt routing
    fixbrst     : integer range 0 to 1 := 0;     -- support fix-length bursts
    debug       : integer range 0 to 2 := 2;     -- report cores to console
    fpnpen      : integer range 0 to 1 := 0; -- full PnP configuration decoding
    icheck      : integer range 0 to 1 := 1;
    devid       : integer := 0;		     -- unique device ID
    enbusmon    : integer range 0 to 1 := 0; --enable bus monitor
    assertwarn  : integer range 0 to 1 := 0; --enable assertions for warnings 
    asserterr   : integer range 0 to 1 := 0; --enable assertions for errors
    hmstdisable : integer := 0; --disable master checks           
    hslvdisable : integer := 0; --disable slave checks
    arbdisable  : integer := 0; --disable arbiter checks
    mprio       : integer := 0; --master with highest priority
    mcheck      : integer := 1; --check memory map for intersects
    enebterm    : integer := 0; --enable early burst termination
    ebprob      : integer := 10; --probability of early bursttermination, lower value ->higher probability
    ccheck      : integer range 0 to 1 := 1  --perform sanity checks on pnp config
  );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    msti    : out ahb_mst_in_type;
    msto    : in  ahb_mst_out_vector;
    slvi    : out ahb_slv_in_type;
    slvo    : in  ahb_slv_out_vector;
    testen  : in  std_ulogic := '0';
    testrst : in  std_ulogic := '1';
    scanen  : in  std_ulogic := '0';
    testoen : in  std_ulogic := '1'
  );
end;

architecture rtl of at_ahb_ctrl is

constant nahbmx : integer := 2**log2(nahbm);
type nmstarr is array (1 to 3) of integer range 0 to nahbmx-1;
type nvalarr is array (1 to 3) of boolean;

type reg_type is record
  hmaster      : integer range 0 to nahbmx -1;
  hmasterd     : integer range 0 to nahbmx -1;
  hslave       : integer range 0 to nahbs-1;
  hmasterlock  : std_ulogic;
  hmasterlockd : std_ulogic;
  hready       : std_ulogic;
  defslv       : std_ulogic;
  htrans       : std_logic_vector(1 downto 0);
  haddr        : std_logic_vector(15 downto 2); 
  cfgsel       : std_ulogic;
  cfga11       : std_ulogic;
  hrdatam      : std_logic_vector(31 downto 0); 
  hrdatas      : std_logic_vector(31 downto 0);
  beat         : std_logic_vector(3 downto 0);
  defmst       : std_ulogic;
  ldefmst      : std_ulogic;
  lsplmst      : integer range 0 to nahbmx-1;
end record;

  constant primst : std_logic_vector(NAHBMST downto 0) := conv_std_logic_vector(mprio, NAHBMST+1);
  
-- Find next master:
--   * 2 arbitration policies: fixed priority or round-robin
--   * Fixed priority: priority is fixed, highest index has highest priority
--   * Round-robin: arbiter maintains circular queue of masters
--   * (master 0, master 1, ..., master (nahbmx-1)). First requesting master
--   * in the queue is granted access to the bus and moved to the end of the queue.  
--   * splitted masters are not granted
--   * bus is re-arbited when current owner does not request the bus,
--     or when it performs non-burst accesses
--   * fix length burst transfers will not be interrupted
--   * incremental bursts should assert hbusreq until last access
  
  procedure selmast(r      : in reg_type;
                  msto   : in ahb_mst_out_vector;
                  rsplit : in std_logic_vector(0 to nahbmx-1);
                  mast   : out integer range 0 to nahbmx-1;
                  defmst : out std_ulogic) is
   variable hpvec : std_logic_vector(nahbmx-1 downto 0);
   variable rrvec : std_logic_vector(2*nahbmx-1 downto 0);
   variable found : boolean;
   variable vmast   : integer;
  begin

    mast := r.hmaster; found := false;
    defmst := '0'; vmast := r.hmaster;

    for i in 0 to nahbmx-1 loop
      --masters which have received split are not granted
      if ((rsplit(i) = '0') or (split = 0)) then
        hpvec(i) := msto(i).hbusreq;
      end if;
    end loop;
    
    if nahbm = 1 then
      mast := 0;
    elsif rrobin = 0 then
      hpvec := (others => '0');
      --find the default master number
      for i in nahbmx-1 downto 0 loop
        if hpvec(i) = '1' then 
          mast := i; found := true; exit;
        end if;        
      end loop;
    else
      rrvec := hpvec & hpvec;
      for i in vmast+1 to 2*nahbmx-1 loop
        if rrvec(i) = '1' then
          if i < nahbmx then
            mast := i;
          else
            mast := i - nahbmx;
          end if;
          found := true; exit;
        end if;
      end loop;
      if mprio /= 0 then
        for i in 0 to nahbm-1 loop
          if (((rsplit(i) = '0') or (split = 0)) and (primst(i) = '1')) then 
	    if msto(i).hbusreq = '1' then mast := i; found := true; exit; end if;
          end if;
        end loop;
      end if;
    end if;

    if not found then
      mast := defmast;
      if split /= 0 then
        defmst := orv(rsplit);
      end if;
    end if;
  
  end;
                 
  constant MIMAX : integer := log2x(nahbmx) - 1;
  constant SIMAX : integer := log2x(nahbs) - 1;
  constant IOAREA : std_logic_vector(11 downto 0) := 
  	conv_std_logic_vector(ioaddr, 12);
  constant IOMSK  : std_logic_vector(11 downto 0) := 
	conv_std_logic_vector(iomask, 12);
  constant CFGAREA : std_logic_vector(11 downto 0) := 
	conv_std_logic_vector(cfgaddr, 12);
  constant CFGMSK  : std_logic_vector(11 downto 0) := 
	conv_std_logic_vector(cfgmask, 12);
  constant FULLPNP : boolean := (fpnpen /= 0);
  
  signal r, rin : reg_type;
  signal rsplit, rsplitin : std_logic_vector(0 to nahbmx-1);

  signal lmsti : ahb_mst_in_type;
  signal lslvi : ahb_slv_in_type;
  
begin

  comb : process(rst, msto, slvo, r, rsplit, testen, testrst, scanen, testoen)
  variable v : reg_type;
  variable nhmaster, hmaster : integer range 0 to nahbmx -1;
  variable hgrant  : std_logic_vector(0 to NAHBMST-1);   -- bus grant
  variable hsel    : std_logic_vector(0 to 31);   -- slave select
  variable hmbsel  : std_logic_vector(0 to NAHBAMR-1);
  variable nslave  : natural range 0 to 31;
  variable vsplit  : std_logic_vector(0 to nahbmx-1);
  variable bnslave : std_logic_vector(3 downto 0);
  variable area    : std_logic_vector(1 downto 0);
  variable hready  : std_ulogic;
  variable defslv  : std_ulogic;
  variable cfgsel  : std_ulogic;
  variable hcache  : std_ulogic;
  variable hresp   : std_logic_vector(1 downto 0);
  variable hrdata  : std_logic_vector(31 downto 0);
  variable haddr   : std_logic_vector(31 downto 0);
  variable hirq    : std_logic_vector(NAHBIRQ-1 downto 0);
  variable arb     : std_ulogic;
  variable hconfndx : integer range 0 to 7;
  variable vslvi   : ahb_slv_in_type;
  variable defmst   : std_ulogic;
  variable tmpv     : std_logic_vector(0 to nahbmx-1);
  variable tmp     : real;
  variable seed1   : positive := 262345;
  variable seed2   : positive := 23532;
  variable rand    : integer;
  begin

    v := r; hgrant := (others => '0'); defmst := '0';
    haddr := msto(r.hmaster).haddr;
    
    nhmaster := r.hmaster; 

    --determine if bus should be rearbitrated. This is done if the current
    --master is not performing a locked transfer and if not in the middle
    --of burst
    arb := '0';
    if (r.hmasterlock or r.ldefmst) = '0' then
      case msto(r.hmaster).htrans is
        when HTRANS_IDLE => arb := '1'; 
        when HTRANS_NONSEQ =>
          case msto(r.hmaster).hburst is
            when HBURST_SINGLE => arb := '1';
            when HBURST_INCR => arb := not msto(r.hmaster).hbusreq;
            when others =>
          end case;
        when HTRANS_SEQ =>
          case msto(r.hmaster).hburst is
            when HBURST_WRAP4  | HBURST_INCR4  => if (fixbrst = 1) and (r.beat(1 downto 0) = "11")   then arb := '1'; end if;
            when HBURST_WRAP8  | HBURST_INCR8  => if (fixbrst = 1) and (r.beat(2 downto 0) = "111")  then arb := '1'; end if;
            when HBURST_WRAP16 | HBURST_INCR16 => if (fixbrst = 1) and (r.beat(3 downto 0) = "1111") then arb := '1'; end if;
            when HBURST_INCR => arb := not msto(r.hmaster).hbusreq;
            when others =>
          end case;
        when others => arb := '0';
      end case;
      if enebterm = 1 then
        math_real.uniform(seed1, seed2, tmp);
        rand := integer(math_real.round(tmp*real(ebprob)));
        if rand = 0 then
          arb := '1';
        end if;
      end if;
    end if;

    if (split /= 0) then
      for i in 0 to nahbmx-1 loop
        tmpv(i) := (msto(i).htrans(1) or (msto(i).hbusreq)) and not rsplit(i) and not r.ldefmst;
      end loop;    
      if (r.defmst and orv(tmpv))  = '1' then arb := '1'; end if;
    end if;

    --rearbitrate bus with selmast. If not arbitrated one must
    --ensure that the dummy master is selected for locked splits. 
    if (arb = '1') then
      selmast(r, msto, rsplit, nhmaster, defmst);
    elsif (split /= 0) then
      defmst := r.defmst;
    end if;

    -- slave decoding

    hsel := (others => '0'); hmbsel := (others => '0');

    for i in 0 to nahbs-1 loop
      for j in NAHBIR to NAHBCFG-1 loop
        area := slvo(i).hconfig(j)(1 downto 0);
        case area is
	when "10" =>
          if ((ioen = 0) or ((IOAREA and IOMSK) /= (haddr(31 downto 20) and IOMSK))) and
             ((slvo(i).hconfig(j)(31 downto 20) and slvo(i).hconfig(j)(15 downto 4)) = 
              (haddr(31 downto 20) and slvo(i).hconfig(j)(15 downto 4))) and 
	      (slvo(i).hconfig(j)(15 downto 4) /= "000000000000")
          then hsel(i) := '1'; hmbsel(j-NAHBIR) := '1'; end if;
	when "11" =>
          if ((ioen /= 0) and ((IOAREA and IOMSK) = (haddr(31 downto 20) and IOMSK))) and
             ((slvo(i).hconfig(j)(31 downto 20) and slvo(i).hconfig(j)(15 downto 4)) = 
              (haddr(19 downto  8) and slvo(i).hconfig(j)(15 downto 4))) and 
	      (slvo(i).hconfig(j)(15 downto 4) /= "000000000000")
          then hsel(i) := '1'; hmbsel(j-NAHBIR) := '1'; end if;
	when others =>
        end case;
      end loop;
    end loop;

    if r.defmst = '1' then hsel := (others => '0'); end if;
    
    bnslave(0) := hsel(1) or hsel(3) or hsel(5) or hsel(7) or
                  hsel(9) or hsel(11) or hsel(13) or hsel(15);
    bnslave(1) := hsel(2) or hsel(3) or hsel(6) or hsel(7) or
                  hsel(10) or hsel(11) or hsel(14) or hsel(15);
    bnslave(2) := hsel(4) or hsel(5) or hsel(6) or hsel(7) or
                  hsel(12) or hsel(13) or hsel(14) or hsel(15);
    bnslave(3) := hsel(8) or hsel(9) or hsel(10) or hsel(11) or
                  hsel(12) or hsel(13) or hsel(14) or hsel(15);
    nslave := conv_integer(bnslave(SIMAX downto 0));

    if ((((IOAREA and IOMSK) = (haddr(31 downto 20) and IOMSK)) and (ioen /= 0))
      or ((IOAREA = haddr(31 downto 20)) and (ioen = 0))) and
       ((CFGAREA and CFGMSK) = (haddr(19 downto  8) and CFGMSK))
       and (cfgmask /= 0)
    then cfgsel := '1'; hsel := (others => '0');
    else cfgsel := '0'; end if;

    if (nslave = 0) and (hsel(0) = '0') and (cfgsel = '0') then defslv := '1';
    else defslv := '0'; end if;

    if r.defmst = '1' then
      cfgsel := '0'; defslv := '1';
    end if;
    
-- error response on undecoded area

    v.hready := '0'; 
    hready := slvo(r.hslave).hready; hresp := slvo(r.hslave).hresp;
    if r.defslv = '1' then
      -- default slave
      if (r.htrans = HTRANS_IDLE) or (r.htrans = HTRANS_BUSY) then
        hresp := HRESP_OKAY; hready := '1';
      else
	-- return two-cycle error in case of unimplemented slave access
	hresp := HRESP_ERROR; hready := r.hready; v.hready := not r.hready;
      end if;
    end if;

    hrdata := slvo(r.hslave).hrdata;

    if cfgmask /= 0 then
--      v.hrdatam := msto(conv_integer(r.haddr(MIMAX+5 downto 5))).hconfig(conv_integer(r.haddr(4 downto 2)));
--      if r.haddr(11 downto MIMAX+6) /= zero32(11 downto MIMAX+6) then v.hrdatam := (others => '0'); end if;

--       if (r.haddr(10 downto MIMAX+6) = zero32(10 downto MIMAX+6)) and (r.haddr(4 downto 2) = "000")
      if FULLPNP then hconfndx := conv_integer(r.haddr(4 downto 2)); else hconfndx := 0; end if; 
      if (r.haddr(10 downto MIMAX+6) = zero32(10 downto MIMAX+6)) and (FULLPNP or (r.haddr(4 downto 2) = "000"))
      then v.hrdatam := msto(conv_integer(r.haddr(MIMAX+5 downto 5))).hconfig(hconfndx);      
      else v.hrdatam := (others => '0'); end if;

--      v.hrdatas := slvo(conv_integer(r.haddr(SIMAX+5 downto 5))).hconfig(conv_integer(r.haddr(4 downto 2)));
--      if r.haddr(11 downto SIMAX+6) /= ('1' & zero32(10 downto SIMAX+6)) then v.hrdatas := (others => '0'); end if;

      --if (r.haddr(10 downto SIMAX+6) = zero32(10 downto SIMAX+6)) and
      if (r.haddr(10 downto SIMAX+6) = zero32(10 downto SIMAX+6)) and
        (FULLPNP or (r.haddr(4 downto 2) = "000") or (r.haddr(4) = '1'))
      then v.hrdatas := slvo(conv_integer(r.haddr(SIMAX+5 downto 5))).hconfig(conv_integer(r.haddr(4 downto 2)));
      else v.hrdatas := (others => '0'); end if;

      if r.haddr(10 downto 4) = "1111111" then
	 v.hrdatas(15 downto 0) := conv_std_logic_vector(LIBVHDL_BUILD, 16);
	 v.hrdatas(31 downto 16) := conv_std_logic_vector(devid, 16);
      end if;
      if r.cfgsel = '1' then
        hrdata := (others => '0'); 
        -- default slave
        if (r.htrans = HTRANS_IDLE) or (r.htrans = HTRANS_BUSY) then
          hresp := HRESP_OKAY; hready := '1';
        else
  	  -- return two-cycle read/write respons
 	  hresp := HRESP_OKAY; hready := r.hready; v.hready := not r.hready;
        end if;
        if r.cfga11 = '0' then hrdata := r.hrdatam;
        else hrdata := r.hrdatas; end if;
      end if;
    end if;

    --degrant all masters when split occurs for locked access
    if (r.hmasterlockd = '1') then
      if (hresp = HRESP_RETRY) or ((split /= 0) and (hresp = HRESP_SPLIT)) then
        nhmaster := r.hmaster;
      end if;
      if split /= 0 then
        if hresp = HRESP_SPLIT then
          v.ldefmst := '1'; defmst := '1';
          v.lsplmst := nhmaster;
        end if;
      end if;
    end if;

    if split /= 0 and r.ldefmst = '1' then
      if rsplit(r.lsplmst) = '0' then
        v.ldefmst := '0'; defmst := '0';
      end if;
    end if;

    if (split = 0) or (defmst = '0') then hgrant(nhmaster) := '1'; end if;

    -- latch active master and slave
    if hready = '1' then 
      v.hmaster := nhmaster; v.hmasterd := r.hmaster;
      v.hslave := nslave; v.defslv := defslv;
      v.hmasterlockd := r.hmasterlock;
      if (split = 0) or (r.defmst = '0') then v.htrans := msto(r.hmaster).htrans;
      else v.htrans := HTRANS_IDLE; end if;
      v.cfgsel := cfgsel;
      v.cfga11 := msto(r.hmaster).haddr(11);
      v.haddr := msto(r.hmaster).haddr(15 downto 2);
      if (msto(r.hmaster).htrans = HTRANS_NONSEQ) or (msto(r.hmaster).htrans = HTRANS_IDLE) then
        v.beat := "0001";
      elsif (msto(r.hmaster).htrans = HTRANS_SEQ) then
        if (fixbrst = 1) then v.beat := r.beat + 1; end if;
      end if;
      if (split /= 0) then v.defmst := defmst; end if;      
    end if;

    --assign new hmasterlock, v.hmaster is used because if hready
    --then master can have changed, and when not hready then the
    --previous master will still be selected
    v.hmasterlock := msto(v.hmaster).hlock or (r.hmasterlock and not hready);

    -- split support
    vsplit := (others => '0');
    if SPLIT /= 0 then
      vsplit := rsplit;
      if slvo(r.hslave).hresp = HRESP_SPLIT then vsplit(r.hmasterd) := '1'; end if;
      for i in 0 to nahbs-1 loop
        for j in 0 to nahbmx-1 loop
          vsplit(j) := vsplit(j) and not slvo(i).hsplit(j);
        end loop;
      end loop;
    end if;

    if r.cfgsel = '1' then hcache := '1'; else hcache := slvo(v.hslave).hcache; end if;
    
    -- interrupt merging
    hirq := (others => '0');
    if disirq = 0 then
      for i in 0 to nahbs-1 loop hirq := hirq or slvo(i).hirq; end loop;
      for i in 0 to nahbm-1 loop hirq := hirq or msto(i).hirq; end loop;
    end if;

    if (split = 0) or (r.defmst = '0') then
      vslvi.haddr      := haddr;
      vslvi.htrans     := msto(r.hmaster).htrans;
      vslvi.hwrite     := msto(r.hmaster).hwrite;
      vslvi.hsize      := msto(r.hmaster).hsize;
      vslvi.hburst     := msto(r.hmaster).hburst;
      vslvi.hready     := hready;
      vslvi.hwdata     := msto(r.hmasterd).hwdata;
      vslvi.hprot      := msto(r.hmaster).hprot;
--      vslvi.hmastlock  := msto(r.hmaster).hlock;
      vslvi.hmastlock  := r.hmasterlock;
      vslvi.hmaster    := conv_std_logic_vector(r.hmaster, 4);
      vslvi.hsel       := hsel(0 to NAHBSLV-1); 
      vslvi.hmbsel     := hmbsel; 
      vslvi.hcache     := hcache; 
      vslvi.hirq       := hirq;       
    else
      vslvi := ahbs_in_none;
      vslvi.hready := hready;
      vslvi.hwdata := msto(r.hmasterd).hwdata;
      vslvi.hirq   := hirq;
    end if;    
    vslvi.testen  := testen; 
    vslvi.testrst := testrst; 
    vslvi.scanen  := scanen and testen; 
    vslvi.testoen := testoen; 

    -- reset operation
    if (rst = '0') then
      v.hmaster := 0; v.hmasterlock := '0'; vsplit := (others => '0');
      v.htrans := HTRANS_IDLE;  v.defslv := '0'; -- v.beat := "0001";
      v.hslave := 0; v.cfgsel := '0'; v.defmst := '0';
      v.ldefmst := '0';
    end if;
    
    -- drive master inputs
    msti.hgrant  <= hgrant;
    msti.hready  <= hready;
    msti.hresp   <= hresp;
    msti.hrdata  <= hrdata;
    msti.hcache  <= hcache;
    msti.hirq    <= hirq; 
    msti.testen  <= testen; 
    msti.testrst <= testrst; 
    msti.scanen  <= scanen and testen; 
    msti.testoen <= testoen; 

    -- drive slave inputs
    slvi     <= vslvi;

-- pragma translate_off
    --drive internal signals to bus monitor
    lslvi         <= vslvi;

    lmsti.hgrant  <= hgrant;
    lmsti.hready  <= hready;
    lmsti.hresp   <= hresp;
    lmsti.hrdata  <= hrdata;
    lmsti.hcache  <= hcache;
    lmsti.hirq    <= hirq; 
-- pragma translate_on

    if split = 0 then v.ldefmst := '0'; v.lsplmst := 0; end if;
    
    rin <= v; rsplitin <= vsplit; 

  end process;


  reg0 : process(clk)
  begin
    if rising_edge(clk) then r <= rin; end if;
    if (split = 0) then r.defmst <= '0'; end if;
  end process;

  splitreg : if SPLIT /= 0 generate
    reg1 : process(clk)
    begin if rising_edge(clk) then rsplit <= rsplitin; end if; end process;
  end generate;

  nosplitreg : if SPLIT = 0 generate
    rsplit <= (others => '0');
  end generate;
  
-- pragma translate_off
--  diag : process
--  variable k : integer;
--  variable mask : std_logic_vector(11 downto 0);
--  variable iostart : std_logic_vector(11 downto 0) := IOAREA and IOMSK;
--  variable cfgstart : std_logic_vector(11 downto 0) := CFGAREA and CFGMSK;
--  begin
--    wait for 2 ns;
--    k := 0; mask := IOMSK;
--    while (k<12) and (mask(k) = '0') loop k := k+1; end loop; 
--    print("ahbctrl: AHB arbiter/multiplexer rev 1");
--    if ioen /= 0 then
--      print("ahbctrl: Common I/O area at " & tost(iostart) & "00000, " & tost(2**k) & " Mbyte");
--    else
--      print("ahbctrl: Common I/O area disabled");
--    end if;
--    if cfgmask /= 0 then
--      print("ahbctrl: Configuration area at " & tost(iostart & cfgstart) & "00, 4 kbyte");
--    else
--      print("ahbctrl: Configuration area disabled");
--    end if;
--    wait;
--  end process;

  mon0 : if enbusmon /= 0 generate 
    mon : ahbmon 
      generic map(
        asserterr   => asserterr,
        assertwarn  => assertwarn,
        hmstdisable => hmstdisable,
        hslvdisable => hslvdisable,
        arbdisable  => arbdisable,
        nahbm       => nahbm,
        nahbs       => nahbs)
      port map(
        rst         => rst,
        clk         => clk,
        ahbmi       => lmsti,
        ahbmo       => msto,
        ahbsi       => lslvi,
        ahbso       => slvo,
        err         => open);
  end generate;

  diag : process
  type ahbsbank_type is record
        start : std_logic_vector(31 downto 8);
        stop  : std_logic_vector(31 downto 8);
  end record;
  type ahbsbanks_type is array (0 to 3) of ahbsbank_type;
  type memmap_type is array (0 to nahbs-1) of ahbsbanks_type;
  variable k : integer;
  variable mask : std_logic_vector(11 downto 0);
  variable device : std_logic_vector(11 downto 0);
  variable devicei : integer;
  variable vendor : std_logic_vector( 7 downto 0);
  variable area : std_logic_vector( 1 downto 0);
  variable vendori : integer;
  variable iosize, tmp : integer;
  variable iounit : string(1 to 5) := " byte";
  variable memtype : string(1 to 9);
  variable iostart : std_logic_vector(11 downto 0) := IOAREA and IOMSK;
  variable cfgstart : std_logic_vector(11 downto 0) := CFGAREA and CFGMSK;
  variable L1 : line := new string'("");
  variable S1 : string(1 to 255);
  variable memmap : memmap_type;
  
  begin
    wait for 2 ns;
    if debug = 0 then wait; end if;
    if debug > 0 then
      k := 0; mask := IOMSK;
      while (k<12) and (mask(k) = '0') loop k := k+1; end loop; 
      print("ahbctrl: AHB arbiter/multiplexer rev 1");
      if ioen /= 0 then
        print("ahbctrl: Common I/O area at " & tost(iostart) & "00000, " & tost(2**k) & " Mbyte");
      else
        print("ahbctrl: Common I/O area disabled");
      end if;
      print("ahbctrl: AHB masters: " & tost(nahbm) & ", AHB slaves: " & tost(nahbs));
      if cfgmask /= 0 then
        print("ahbctrl: Configuration area at " & tost(iostart & cfgstart) & "00, 4 kbyte");
      else
        print("ahbctrl: Configuration area disabled");
      end if;
    end if;
    for i in 0 to nahbm-1 loop
      vendor := msto(i).hconfig(0)(31 downto 24); 
      vendori := conv_integer(vendor);
      if vendori /= 0 then
        if debug > 1 then
          device := msto(i).hconfig(0)(23 downto 12); 
          devicei := conv_integer(device);      
          print("ahbctrl: mst" & tost(i) & ": " & iptable(vendori).vendordesc &
                iptable(vendori).device_table(devicei));
        end if;
        for j in 1 to NAHBIR-1 loop 
          assert (msto(i).hconfig(j) = zx or FULLPNP or ccheck = 0)
            report "AHB slave " & tost(i) & " propagates non-zero user defined PnP data, " &
            "but AHBCTRL full PnP decoding has not been enabled"
            severity warning;
        end loop;
	assert (msto(i).hindex = i) or (icheck = 0)
	report "AHB master index error on master " & tost(i) &
          ". Detected index value " & tost(msto(i).hindex) severity failure;
      else
        for j in 0 to NAHBCFG-1 loop 
          assert (msto(i).hconfig(j) = zx or ccheck = 0)
            report "AHB master " & tost(i) & " appears to be disabled, " &
            "but the master config record is not driven to zero"
            severity warning;
        end loop;
      end if;
    end loop;
    if nahbm < NAHBMST then
      for i in nahbm to NAHBMST-1 loop 
        for j in 0 to NAHBCFG-1 loop 
          assert (msto(i).hconfig(j) = zx or ccheck = 0)
            report "AHB master " & tost(i) & " is outside the range of " &
            "decoded master indexes but the master config record is not driven to zero"
            severity warning;
        end loop;
      end loop;
    end if;
    for i in 0 to nahbs-1 loop
      vendor := slvo(i).hconfig(0)(31 downto 24); 
      vendori := conv_integer(vendor);
      if vendori /= 0 then
        if debug > 1 then
          device := slvo(i).hconfig(0)(23 downto 12); 
          devicei := conv_integer(device);      
          std.textio.write(L1, "ahbctrl: slv" & tost(i) & ": " & iptable(vendori).vendordesc &
                           iptable(vendori).device_table(devicei));
          std.textio.writeline(OUTPUT, L1);
        end if;
        for j in 1 to NAHBIR-1 loop 
          assert (slvo(i).hconfig(j) = zx or FULLPNP or ccheck = 0)
            report "AHB slave " & tost(i) & " propagates non-zero user defined PnP data, " &
            "but AHBCTRL full PnP decoding has not been enabled"
            severity warning;
        end loop;
        for j in NAHBIR to NAHBCFG-1 loop
          area := slvo(i).hconfig(j)(1 downto 0);
	  mask := slvo(i).hconfig(j)(15 downto 4);
          memmap(i)(j mod NAHBIR).start := (others => '0');
          memmap(i)(j mod NAHBIR).stop := (others => '0');
	  if (mask /= "000000000000") then
            case area is
	    when "01" =>
	    when "10" =>
	      k := 0;
              while (k<15) and (mask(k) = '0') loop k := k+1; end loop;
              if debug > 1 then
                std.textio.write(L1, "ahbctrl:       memory at " &
                                 tost( slvo(i).hconfig(j)(31 downto 20)) &
                                 "00000, size "& tost(2**k) & " Mbyte");
                if slvo(i).hconfig(j)(16) = '1' then 
                  std.textio.write(L1, string'(", cacheable"));
                end if;
                if slvo(i).hconfig(j)(17) = '1' then 
                  std.textio.write(L1, string'(", prefetch"));
                end if;
                std.textio.writeline(OUTPUT, L1);
              end if;
              memmap(i)(j mod NAHBIR).start(31 downto 20) := slvo(i).hconfig(j)(31 downto 20);
              memmap(i)(j mod NAHBIR).start(19 downto 8) := (others => '0');
              memmap(i)(j mod NAHBIR).stop := memmap(i)(j mod NAHBIR).start + 2**(k+12);
	    when "11" =>
              if ioen /= 0 then
	        k := 0;
                while (k<15) and (mask(k) = '0') loop k := k+1; end loop; 
                memmap(i)(j mod NAHBIR).start := iostart & (slvo(i).hconfig(j)(31 downto 20) and
                                                            slvo(i).hconfig(j)(15 downto 4));
                memmap(i)(j mod NAHBIR).stop := memmap(i)(j mod NAHBIR).start + 2**k;
                if debug > 1 then
                  iosize := 256 * 2**k; iounit(1) := ' ';
                  if (iosize > 1023) then
                    iosize := iosize/1024; iounit(1) := 'k';
                  end if;
                  print("ahbctrl:       I/O port at " & tost(iostart &
                        ((slvo(i).hconfig(j)(31 downto 20)) and slvo(i).hconfig(j)(15 downto 4))) &
                        "00, size "& tost(iosize) & iounit);
                end if;
	      end if;
            when others =>
            end case;
          end if;
        end loop;
	assert (slvo(i).hindex = i) or (icheck = 0)
	report "AHB slave index error on slave " & tost(i) &
          ". Detected index value " & tost(slvo(i).hindex) severity failure;
        if mcheck /= 0 then
          for j in 0 to i loop
            for k in memmap(i)'range loop
              for l in memmap(i)'range loop
                if memmap(i)(k).start /= memmap(i)(k).stop then
                  assert ((memmap(i)(k).start >= memmap(j)(l).stop) or
                          (memmap(i)(k).stop <= memmap(j)(l).start) or (i = j and k = l))
                    report "AHB slave " & tost(i) & " bank " & tost(k) & 
                    " intersects with AHB slave " & tost(j) & " bank " & tost(l)
                    severity failure;
                end if;
              end loop;
            end loop;
          end loop;
        end if;
      else
        for j in 0 to NAHBCFG-1 loop 
          assert (slvo(i).hconfig(j) = zx or ccheck = 0)
            report "AHB slave " & tost(i) & " appears to be disabled, " &
            "but the slave config record is not driven to zero"
            severity warning;
        end loop;
      end if;
    end loop;
    if nahbs < NAHBSLV then
      for i in nahbs to NAHBSLV-1 loop 
        for j in 0 to NAHBCFG-1 loop 
          assert (slvo(i).hconfig(j) = zx or ccheck = 0)
            report "AHB slave " & tost(i) & " is outside the range of " &
            "decoded slave indexes but the slave config record is not driven to zero"
            severity warning;
        end loop;
      end loop;
    end if;
    wait;
  end process;

-- pragma translate_on

end;

