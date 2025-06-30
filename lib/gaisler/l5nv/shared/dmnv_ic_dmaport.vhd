
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.devices.all;
use grlib.stdlib.all;
use grlib.amba.all;
library gaisler;
use gaisler.l5nv_shared.all;

entity dmnv_ic_dmaport is
  generic (
    dmhaddr   : integer;
    dmhmask   : integer;
    burstlen  : integer
    );
  port (
    clk   : in  std_ulogic;
    rstn  : in  std_ulogic;
    -- Debug-link interface
    dmami : out ahb_mst_in_type;
    dmamo : in  ahb_mst_out_type;
    -- Interface to interconnect
    icdb  : out dmnv_ic_dma_bus_type;
    icbd  : in  dmnv_ic_bus_dma_type
    );
end;

architecture rtl of dmnv_ic_dmaport is

  constant bursttop  : integer := 2+log2 (burstlen)-1;
  constant bursttopx : integer := 2+log2x(burstlen)-1;

  constant onev : std_logic_vector(31 downto 0) := (others => '1');

  constant nbus : integer := 1+1 -- conventional + debug-module
                             ;
  constant CONV : integer := nbus-2;
  constant DM   : integer := nbus-1;
  constant addrw : integer := 32* (1
                             ) 
                             ;

  type dm_ic_dma_state is (dsidle, dsreq, dswtfr, dsrtfr);

  type dm_ic_dma_type is record
    ds         : dm_ic_dma_state;
    hready     : std_ulogic;
    htrans     : std_logic_vector(1 downto 0);
    haddr      : std_logic_vector(31 downto 0);
    hsize      : std_logic_vector(2 downto 0);
    hwrite     : std_ulogic;
    hburst0    : std_ulogic;
    mhdata     : std_logic_vector(31 downto 0);
    bifreq     : std_logic_vector(0 to nbus-1);
    bifaddr    : std_logic_vector(addrw-1 downto 0);
    bifwen     : std_ulogic;
    bifwaddr   : std_logic_vector(5 downto 2);
    phready    : std_ulogic;
  end record;

  constant RES_DM_IC_DMA : dm_ic_dma_type := (
    ds         => dsidle,
    hready     => '1',
    htrans     => "00",
    haddr      => (others => '0'),
    hsize      => "000",
    hwrite     => '0',
    hburst0    => '0',
    mhdata     => (others => '0'),
    bifreq     => (others => '0'),
    bifaddr    => (others => '0'),
    bifwen     => '0',
    bifwaddr   => (others => '0'),
    phready    => '0'
    );

  function maskmatch(addrbits: std_logic_vector; haddr, hmask: integer) return std_ulogic is
    variable haddrv : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(haddr,12));
    variable hmaskv : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(hmask,12));
  begin
    if (addrbits and hmaskv) = (haddrv and hmaskv) then return '1'; else return '0'; end if;
  end;

  function is_conv(addr : std_logic_vector) return boolean is
  begin
    return true;
  end function;

  function is_dm(addr: std_logic_vector; haddr, hmask: integer) return boolean is
  begin
    return maskmatch(addr, haddr, hmask) = '1';
  end function;

  signal dr, ndr: dm_ic_dma_type;

begin

  comb: process(dr,dmamo,icbd)
    variable dv       : dm_ic_dma_type;
    variable odmami   : ahb_mst_in_type;
    variable oicdb    : dmnv_ic_dma_bus_type;
  begin
    dv := dr;
    odmami := ahbm_in_none;
    odmami.hgrant := (others => '1');
    odmami.hready := dr.hready;
    odmami.hresp := "00";
    odmami.hrdata := ahbdrivedata(dr.mhdata);
    oicdb := dmnv_ic_dma_bus_none;
    oicdb.req(0 to nbus-1) := dr.bifreq;
    oicdb.addr(addrw-1 downto 0) := dr.bifaddr;
    oicdb.wr := dr.hwrite;
    oicdb.size := dr.hsize(1 downto 0);
    oicdb.burst := dr.hburst0;
    oicdb.wrdv := dr.bifwen;
    oicdb.wraddr := dr.bifwaddr;
    oicdb.wrdata := dr.mhdata;

    dv.phready := dr.hready;
    if dr.hready='1' then
      dv.htrans := dmamo.htrans;
      dv.haddr := dmamo.haddr;
      dv.hsize := dmamo.hsize;
      dv.hwrite := dmamo.hwrite;
      dv.hburst0 := dmamo.hburst(0);
      if dmamo.htrans(1) /= '0' then
        dv.hready := '0';
      end if;
      if dr.hwrite='1' then
        dv.mhdata := dmamo.hwdata(31 downto 0);
      end if;
    end if;
    if dr.phready='1' or dr.hready = '1' then
      if dr.hwrite='1' then
        dv.mhdata := dmamo.hwdata(31 downto 0);
      end if;
    end if;
    dv.bifwen := '0';
    case dr.ds is
      when dsidle => -- Default idle state
        dv.bifreq := (others => '0');
        -- Check that we are *not* granted in this state to make sure
        -- we don't get confused by a previous access that has not yet
        -- completed on the bus side
        if dr.hready='0' and icbd.gnt='0' then
          -- Translate address and go to request state
          dv.ds := dsreq;
          if is_dm(dr.haddr(31 downto 20), dmhaddr, dmhmask) then
            -- Debug-module area
            dv.bifreq(DM) := '1';
            dv.bifaddr := (others => '0');
            dv.bifaddr(31 downto 0) := dr.haddr(31 downto 0);
            dv.hburst0 := '0';  -- break down bursts to debug-module to single accesses
          else
            -- Conventional area
            dv.bifreq(CONV) := '1';
            dv.bifaddr := (others => '0');
            dv.bifaddr(31 downto 0) := dr.haddr(31 downto 0);
            dv.hburst0 := '0';  -- break down bursts to conv area to single accesses
          end if;
        end if;
      when dsreq => -- Request access to bus
        if icbd.gnt='1' or dr.bifreq=(dr.bifreq'range => '0') then
          if dr.hwrite='1' then
            dv.hready := '1';
            dv.ds := dswtfr;
            dv.bifwaddr := dr.bifaddr(5 downto 2);
          else
            dv.ds := dsrtfr;
          end if;
        end if;
      when dswtfr => -- Transfer write data
        -- Here we only manage the hready and bifwen signals, the copying
        -- from hwdata -> dr.mhdata is managed above and copying from
        -- dr.hwdata -> r.bif(s).databuf is managed inside bus-interface (stripe) FSM
        dv.bifwen := dr.hready and dr.htrans(1);
        if dr.hready='1' and dmamo.htrans="11" and burstlen>1 and dr.haddr(bursttopx downto 2)/=onev(bursttopx downto 2) and dr.hburst0='1' then
          dv.hready := '1';
        end if;
        if dr.bifwen='1' then
          dv.bifwaddr := std_logic_vector(unsigned(dr.bifwaddr)+1);
        end if;
        if (dr.hready='0' or dr.htrans="00") then
          dv.bifreq := (others => '0');
          dv.ds := dsidle;
        end if;
      when dsrtfr => -- Transfer read data
        if dr.hready='1' and (dmamo.htrans/="11" or dr.hburst0='0' or burstlen=1 or dr.haddr(bursttopx downto 2)=onev(bursttopx downto 2)) then
          dv.bifreq := (others => '0');
          dv.ds := dsidle;
        elsif dr.hready='1' and dmamo.htrans="11" and icbd.rddv='1' and icbd.rdaddr=add(dr.haddr(5 downto 2),1) then
          -- Note only valid for non-wrapping bursts
          dv.hready := '1';
          dv.mhdata := icbd.rddata;
        elsif dr.hready='0' then
          if icbd.rddv='1' and icbd.rdaddr=dr.haddr(5 downto 2) then
            dv.hready := '1';
            dv.mhdata := icbd.rddata;
          end if;
        end if;
    end case;

    ndr <= dv;
    dmami <= odmami;
    icdb <= oicdb;
  end process;

  regs: process(clk)
  begin
    if rising_edge(clk) then
      dr <= ndr;
      if rstn='0' then
        dr.ds     <= RES_DM_IC_DMA.ds;
        dr.hready <= RES_DM_IC_DMA.hready;
      end if;
    end if;
  end process;
end;
