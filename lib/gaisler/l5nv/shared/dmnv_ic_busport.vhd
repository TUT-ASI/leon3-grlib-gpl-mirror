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

entity dmnv_ic_busport is
  generic (
    busid    : integer;
    abits    : integer;
    dbits    : integer;
    vdbits   : integer;
    burstlen : integer;
    lowd     : integer;
    pnpgen   : integer;
    pnpaddrhi: integer;
    pnpaddrlo: integer;
    pnpmpos  : integer;
    pnpnmst  : integer;
    pnpspos  : integer;
    pnpnslv  : integer
    );
  port (
    clk      : in  std_ulogic;
    rstn     : in  std_ulogic;
    -- AHB interface
    endian   : in  std_ulogic;
    hready   : in  std_ulogic;
    hbusreq  : out std_ulogic;
    hgrant   : in  std_ulogic;
    htrans   : out std_logic_vector(1 downto 0);
    haddr    : out std_logic_vector(abits-1 downto 0);
    hwrite   : out std_ulogic;
    hsize    : out std_logic_vector(2 downto 0);
    hburst0  : out std_ulogic;
    hresp    : in  std_logic_vector(1 downto 0);
    hwdata   : out std_logic_vector(vdbits-1 downto 0);
    hrdata   : in  std_logic_vector(vdbits-1 downto 0);
    -- Interface to interconnect
    icdb     : in  dmnv_ic_dma_bus_type;
    icbd     : out dmnv_ic_bus_dma_type;
    -- Signals for AMBA PnP patching
    mstpnp   : in  ahb_config_array(0 to pnpnmst-1);
    slvpnp   : in  ahb_config_array(0 to pnpnslv-1)
    );
end;

architecture rtl of dmnv_ic_busport is

  constant bursttop  : integer := 2+log2 (burstlen)-1;
  constant bursttopx : integer := 2+log2x(burstlen)-1;

  constant onev : std_logic_vector(31 downto 0) := (others => '1');

  type dm_ic_bif_state is (bsidle, bstfr1, bstfr2, bstfr3, bspartwr1);
  type dm_ic_bif_databuf is array(0 to burstlen-1) of std_logic_vector(31 downto 0);
  type dm_ic_bif_type is record
    bs      : dm_ic_bif_state;
    hbusreq : std_ulogic;
    htrans  : std_logic_vector(1 downto 0);
    haddr   : std_logic_vector(abits-1 downto 0);
    hwrite  : std_ulogic;
    hwdatald: std_logic_vector(dbits-1 downto 0);  -- Only used when lowd/=0
    hsize   : std_logic_vector(2 downto 0);
    hburst0 : std_ulogic;
    granted : std_ulogic;
    inacc   : std_ulogic;
    mstgnt  : std_ulogic;
    databuf : dm_ic_bif_databuf;
    wvalid  : std_logic_vector(0 to burstlen-1);
    inaccpw : std_ulogic;
    rddv    : std_ulogic;
    rdaddr  : std_logic_vector(5 downto 2);
  end record;
  constant RES_DM_IC_BIF : dm_ic_bif_type := (
    bs       => bsidle,
    hbusreq  => '0',
    htrans   => "00",
    haddr    => (others => '0'),
    hwrite   => '0',
    hwdatald => (others => '0'),
    hsize    => "000",
    hburst0  => '0',
    granted  => '0',
    inacc    => '0',
    mstgnt   => '0',
    databuf  => (others => (others => '0')),
    wvalid   => (others => '0'),
    inaccpw  => '0',
    rddv     => '0',
    rdaddr   => (others => '0')
    );

  function maskmatch(addrbits: std_logic_vector; haddr, hmask: integer) return std_ulogic is
    variable haddrv : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(haddr,12));
    variable hmaskv : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(hmask,12));
  begin
    if (addrbits and hmaskv) = (haddrv and hmaskv) then return '1'; else return '0'; end if;
  end;

  signal br,nbr: dm_ic_bif_type;

begin

  comb: process(br,rstn,
                endian,hready,hgrant,hresp,hrdata,
                icdb)
    variable bv      : dm_ic_bif_type;
    variable oicbd   : dmnv_ic_bus_dma_type;
    variable ohwdata : std_logic_vector(dbits-1 downto 0);
    variable vidx    : std_logic_vector(log2x(burstlen)-1 downto 0);
    variable vidxd   : std_logic_vector(log2x(burstlen)-1 downto 0);
    variable vidx2   : std_logic_vector(4 downto 2);
    variable vidx3   : std_logic_vector(5 downto 0);
    variable vcfg    : ahb_config_type;
    variable d32     : std_logic_vector(31 downto 0);
  begin
    bv := br;

    oicbd := dmnv_ic_bus_dma_none;
    oicbd.gnt := br.mstgnt;
    oicbd.rddv := br.rddv;
    oicbd.rdaddr := br.rdaddr;
    if endian='0' then
      oicbd.rddata := br.databuf(burstlen-1);
    else
      oicbd.rddata := br.databuf(0);
    end if;

    ohwdata := (others => '0');

    -- TODO add PnP for debug masters and debug module

    --------------------------------------------------------------------------
    -- Bus-side logic
    --------------------------------------------------------------------------
    if hready='1' then
      bv.inacc := br.granted and br.htrans(1);
      bv.granted := hgrant;
    end if;
    bv.rddv := '0';
    case br.bs is
      when bsidle =>
        bv.hbusreq := '0';
        bv.htrans := "00";
        bv.mstgnt := '0';
        bv.wvalid := (others => '0');
        if icdb.req(busid) /= '0' then
          bv.bs := bstfr1;
        end if;
        bv.haddr   := icdb.addr(abits-1 downto 0);
        bv.hwrite  := icdb.wr;
        bv.hsize   := '0' & icdb.size;
        bv.hburst0 := icdb.burst;
        bv.inaccpw := '0';
      when bstfr1 =>
        bv.hbusreq := '0';
        bv.htrans := "00";
        -- Transfer write data
        if icdb.wrdv='1' then
          vidx := icdb.wraddr(bursttopx downto 2);
          if endian='0' then
            vidxd := not vidx;
          else
            vidxd := vidx;
          end if;
          if burstlen=1 then
            vidx := (others => '0');
            vidxd := (others => '0');
          end if;
          bv.databuf(to_integer(unsigned(vidxd))) := icdb.wrdata;
          bv.wvalid(to_integer(unsigned(vidx))) := '1';
          if br.hburst0='0' then
            bv.databuf := (others => icdb.wrdata);
          end if;
        end if;
        -- For writes, raise grant to let master transfer write data
        -- For reads, we do the read first and then raise the grant
        bv.mstgnt := '0';
        if br.hwrite='1' then
          if icdb.req(busid)='0' then
            if br.hburst0='1' and br.wvalid /= (br.wvalid'range => '1') then
              -- Partial burst, handle in separate state
              bv.bs := bspartwr1;
              bv.haddr(bursttop downto 0) := (others => '0');
              bv.htrans(1) := br.wvalid(0);
              bv.hburst0 := '0';
            else
              bv.bs := bstfr2;
              bv.hbusreq := '1';
              bv.htrans := "10";
              if br.hburst0='1' then
                bv.haddr(bursttop downto 0) := (others => '0');
                bv.hsize := std_logic_vector(to_unsigned(log2(dbits/8), 3));
              end if;
            end if;
          else
            bv.mstgnt := '1';
          end if;
        else
          bv.bs := bstfr2;
          bv.hbusreq := '1';
          bv.htrans := "10";
          if br.hburst0='1' then
            bv.haddr(bursttop downto 0) := (others => '0');
            bv.hsize := std_logic_vector(to_unsigned(log2(dbits/8), 3));
          end if;
        end if;
        bv.inaccpw := '0';
      when bstfr2 =>
        bv.mstgnt := '0';
        -- Data handling
        if hready='1' and br.inacc='1' and hresp(1)='0' then
          -- For bursts, we use the data buffer as a shift register where
          -- hwdata goes out in the front and hrdata goes into the back.
          -- For big-endian, "front" refers to high indexes and "back" low
          -- indexes, and vice versa for little endian. This avoids having
          -- to add muxing logic on hwdata/hrdata to the AHB bus.
          -- For single access, we do an extra step to replicate the data
          -- everywhere in the buffer to allow the same muxing logic to be
          -- used in the dma master side
          if endian='0' then
            for x in 0 to burstlen-1 loop
              if x < (dbits/32) then
                bv.databuf(x) := hrdata(x*32+31 downto x*32);
              else
                bv.databuf(x) := br.databuf((x-(dbits/32)) mod burstlen);
              end if;
            end loop;
          else
            for x in 0 to burstlen-1 loop
              if x < (burstlen-(dbits/32)) then
                bv.databuf(x) := br.databuf((x+(dbits/32)) mod burstlen);
              else
                bv.databuf(x) := hrdata(((x+(dbits/32)-burstlen)*32+31 mod dbits) downto ((x+(dbits/32)-burstlen)*32 mod dbits));
              end if;
            end loop;
          end if;
        end if;
        -- Address/control handling
        if hready='1' and br.inacc='1' and hresp(1)='0' and br.htrans(1)='0' then
          -- All done!
          if br.hwrite='0' then
            bv.mstgnt := '1';
            bv.bs := bstfr3;
            bv.rdaddr := br.haddr(5 downto 2);
          else
            bv.bs := bsidle;
          end if;
        elsif hready='1' and br.inacc='1' and hresp(1)='1' then
          -- retry/split second phase
          bv.htrans := "10";
          bv.hbusreq := '1';
        elsif hready='0' and br.inacc='1' and hresp(1)='1' then
          -- retry/split first phase, back off from bus to restart access
          bv.htrans := "00";
          if br.hburst0 = '1' and burstlen>1 then
            bv.haddr(bursttopx downto log2(dbits/8)) :=
              std_logic_vector(unsigned(br.haddr(bursttopx downto log2(dbits/8)))-1);
          end if;
          bv.hbusreq := '1';
        elsif hready='1' and br.granted='1' and br.htrans(1)='1' then
          -- advance burst
          if br.hburst0 = '1' and burstlen>1 then
            bv.haddr(bursttopx downto log2(dbits/8)) :=
              std_logic_vector(unsigned(br.haddr(bursttopx downto log2(dbits/8)))+1);
          end if;
          bv.htrans := "11";
          if br.hburst0='0' or burstlen=1 or br.haddr(bursttopx downto log2(dbits/8))=onev(bursttopx downto log2(dbits/8)) then
            bv.htrans := "00";
          end if;
        end if;
        bv.inaccpw := '0';
        -- Patch in PnP info
        if pnpgen /= 0 then
          if br.hwrite='0' and
            maskmatch(br.haddr(31 downto 20), pnpaddrhi, 16#fff#)='1' and
            maskmatch(br.haddr(19 downto  8), pnpaddrlo, 16#ff0#)='1' then
            vidx3 := br.haddr(10 downto 5);
            if br.haddr(11)='0' then
              vidx3 := sub(vidx3, pnpmpos);
              if unsigned(vidx3) < pnpnmst then
                vcfg := mstpnp(to_integer(unsigned(vidx3)));
                d32 := vcfg(to_integer(unsigned(br.haddr(4 downto 2))));
                bv.databuf(0) := d32;
                bv.databuf(burstlen-(dbits/32)) := d32;
              end if;
            else
              vidx3 := sub(vidx3, pnpspos);
              if unsigned(vidx3) < pnpnslv then
                vcfg := slvpnp(to_integer(unsigned(vidx3)));
                d32 := vcfg(to_integer(unsigned(br.haddr(4 downto 2))));
                bv.databuf(0) := d32;
                bv.databuf(burstlen-(dbits/32)) := d32;
              end if;
            end if;
          end if;
        end if;
      when bstfr3 =>
        -- For read data bursts, we loop around the read data vector
        -- to transfer it 32 bits at a time over to the DMA side
        if br.rddv='1' then
          if br.hburst0='1' and burstlen>1 then
            bv.rdaddr(bursttopx downto 2) :=
              std_logic_vector(unsigned(br.rdaddr(bursttopx downto 2))+1);
          end if;
          for x in 0 to burstlen-1 loop
            if endian='0' then
              bv.databuf(x) := br.databuf((x-1) mod burstlen);
            else
              bv.databuf(x) := br.databuf((x+1) mod burstlen);
            end if;
          end loop;
        end if;
        bv.rddv := '1';
        -- For read, wait for request to go low so we know the read data
        -- has been consumed
        bv.mstgnt := '1';
        if icdb.req(busid)='0' then
          bv.mstgnt := '0';
          bv.bs := bsidle;
        end if;
        bv.inaccpw := '0';
        -- Replicate single-access read data across buffer
        if br.rddv='0' and burstlen>1 and br.hburst0='0' then
          for x in 0 to burstlen-1 loop
            if endian='0' then
              bv.databuf(x) := br.databuf(0);
            else
              bv.databuf(x) := br.databuf(burstlen-(dbits/32));
            end if;
          end loop;
        end if;
      when bspartwr1 =>
        -- Handle a partial write burst from a master
        -- This is done in a quite inefficient way, by "walking" through the
        -- wvalid mask and creating single 32-bit accesses for the ones that
        -- are set and idle transfers for the ones that are not set.
        -- Partial write burst, data phase
        if (hready='1' and br.inacc='1' and hresp(1)='0') or br.wvalid(0)='0' then
          bv.haddr(5 downto 2) :=
            std_logic_vector(unsigned(br.haddr(5 downto 2))+1);
          for x in 0 to burstlen-1 loop
            if x < burstlen-1 then
              bv.wvalid(x) := br.wvalid(x+1);
            else
              bv.wvalid(x) := '0';
            end if;
          end loop;
          if dbits=32 or (dbits=64 and br.haddr(2)='1') or (dbits=128 and br.haddr(3 downto 2)="11") then
            for x in 0 to burstlen-1 loop
              if endian='0' then
                if x >= (dbits/32) then
                  bv.databuf(x) := br.databuf((x-(dbits/32)) mod burstlen);
                end if;
              else
                if x < burstlen-(dbits/32) then
                  bv.databuf(x) := br.databuf((x+(dbits/32)) mod burstlen);
                end if;
              end if;
            end loop;
          end if;
          if br.wvalid=(br.wvalid'range => '0') then
            bv.bs := bsidle;
          end if;
          if bv.wvalid(0)='1' then
            bv.htrans(1) := '1';
            bv.hbusreq := '1';
          else
            bv.hbusreq := '0';
          end if;
        elsif hready='1' and br.inacc='1' then
          -- SPLIT/RETRY second phase
          bv.htrans(1) := '1';
          bv.hbusreq := '1';
        elsif hready='1' and br.htrans(1)='1' and br.granted='1' then
          bv.htrans(1) := '0';
          if burstlen > 1 then
            bv.hbusreq := br.wvalid(1 mod burstlen);
          else
            bv.hbusreq := '0';
          end if;
        elsif br.inacc='0' then
          bv.htrans(1) := '1';
          bv.hbusreq := '1';
        end if;
    end case;

    if lowd=0 or dbits=32 then
      -- Standard case, AHB muxing will always select the proper lane so
      -- no extra muxing is needed, databuf can be output directly
      for x in 0 to dbits/32-1 loop
        if endian='0' then
          ohwdata(x*32+31 downto x*32) := br.databuf(burstlen-(dbits/32)+x);
        else
          ohwdata(x*32+31 downto x*32) := br.databuf(x);
        end if;
      end loop;
      bv.hwdatald := (others => '0');
    else
      -- In order to support GRLIB's non-standard data muxing for wide buses
      -- (where data for 8/16/32-bit accesses are always on low 32 bits)
      -- we add a separate output register for hwdata
      ohwdata := br.hwdatald;

      for x in 0 to dbits/32-1 loop
        if endian='0' then
          bv.hwdatald(x*32+31 downto x*32) := bv.databuf(burstlen-(dbits/32)+x);
        else
          bv.hwdatald(x*32+31 downto x*32) := bv.databuf(x);
        end if;
      end loop;
      if bv.hsize(2)='0' and bv.hsize(1 downto 0)/="11" then
        -- Note that we do incremental bursts and haddr is always one step
        -- ahead of the hwdata and there is a "-1" to compensate for that.
        -- In the case we do a single-access this will be wrong but all
        -- parts of databuf will have the same data in that case so it will
        -- not matter.
        vidx2 := bv.haddr(4 downto 2);
        vidx2 := std_logic_vector(unsigned(vidx2)-1);
        if endian='0' then
          bv.hwdatald(31 downto 0) := ahbselectdatabe(ahbdrivedata(bv.hwdatald), vidx2, "010");
        else
          bv.hwdatald(31 downto 0) := ahbselectdatale(ahbdrivedata(bv.hwdatald), vidx2, "010");
        end if;
      end if;
    end if;

    nbr <= bv;
    hbusreq <= br.hbusreq;
    htrans <= br.htrans;
    haddr <= br.haddr;
    hwrite <= br.hwrite;
    hsize <= br.hsize;
    hburst0 <= br.hburst0;
    for x in 0 to vdbits/dbits-1 loop
      hwdata(x*dbits+dbits-1 downto x*dbits) <= ohwdata;
    end loop;
    icbd <= oicbd;
  end process;

  regs: process(clk)
  begin
    if rising_edge(clk) then
      br <= nbr;
      if rstn = '0' then
        br.bs      <= RES_DM_IC_BIF.bs;
        br.hbusreq <= RES_DM_IC_BIF.hbusreq;
        br.htrans  <= RES_DM_IC_BIF.htrans;
        br.mstgnt  <= RES_DM_IC_BIF.mstgnt;
      end if;
    end if;
  end process;
end;
